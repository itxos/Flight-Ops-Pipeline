with flights as (
    select * from {{ ref('stg_flights') }}
),

airports as (
    select * from {{ ref('airports') }}
),

joined as (
    select
        f.*,
        a.timezone as airport_timezone,
        f.scheduled_at at time zone a.timezone as scheduled_local
    from flights f
    join airports a on a.icao = f.airport_icao
)

select
    flight_key,
    airport_icao,
    direction,
    flight_number,
    airline_iata,
    airline_name,
    aircraft_model,
    other_airport_icao,
    other_airport_name,
    other_country_code,
    status,
    scheduled_at,
    scheduled_local,
    scheduled_local::date                          as scheduled_date_local,
    extract(hour from scheduled_local)::int        as scheduled_hour_local,
    status in ('Canceled', 'CanceledUncertain')    as is_cancelled,
    round(extract(epoch from (coalesce(runway_at, revised_at) - scheduled_at)) / 60.0, 1)
                                                   as delay_minutes,
    coalesce(
        extract(epoch from (coalesce(runway_at, revised_at) - scheduled_at)) / 60.0 >= 15,
        false
    )                                              as is_delayed
from joined
