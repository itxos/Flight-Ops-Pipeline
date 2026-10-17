with raw as (
    select airport_icao, ingested_at, payload
    from {{ source('raw', 'flights_raw') }}
),

exploded as (
    select airport_icao, ingested_at, 'departure' as direction, f.value as flight
    from raw, jsonb_array_elements(raw.payload -> 'departures') as f
    union all
    select airport_icao, ingested_at, 'arrival' as direction, f.value as flight
    from raw, jsonb_array_elements(raw.payload -> 'arrivals') as f
),

-- local_leg = the airport we queried; remote_leg = the other end of the flight
legs as (
    select
        airport_icao,
        direction,
        ingested_at,
        flight,
        case direction when 'departure' then flight -> 'departure' else flight -> 'arrival' end as local_leg,
        case direction when 'departure' then flight -> 'arrival' else flight -> 'departure' end as remote_leg
    from exploded
),

parsed as (
    select
        md5(concat_ws('|', airport_icao, direction, flight ->> 'number',
            local_leg -> 'scheduledTime' ->> 'utc')) as flight_key,
        airport_icao,
        direction,
        flight ->> 'number'                              as flight_number,
        flight ->> 'callSign'                            as call_sign,
        flight ->> 'status'                              as status,
        coalesce((flight ->> 'isCargo')::boolean, false) as is_cargo,
        flight -> 'airline' ->> 'iata'                   as airline_iata,
        flight -> 'airline' ->> 'name'                   as airline_name,
        flight -> 'aircraft' ->> 'model'                 as aircraft_model,
        flight -> 'aircraft' ->> 'reg'                   as aircraft_reg,
        remote_leg -> 'airport' ->> 'icao'               as other_airport_icao,
        remote_leg -> 'airport' ->> 'iata'               as other_airport_iata,
        remote_leg -> 'airport' ->> 'name'               as other_airport_name,
        remote_leg -> 'airport' ->> 'countryCode'        as other_country_code,
        (local_leg -> 'scheduledTime' ->> 'utc')::timestamptz as scheduled_at,
        (local_leg -> 'revisedTime'   ->> 'utc')::timestamptz as revised_at,
        (local_leg -> 'runwayTime'    ->> 'utc')::timestamptz as runway_at,
        local_leg ->> 'terminal'                         as terminal,
        ingested_at
    from legs
)

select distinct on (flight_key) *
from parsed
order by flight_key, ingested_at desc
