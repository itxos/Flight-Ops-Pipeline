with flights as (
    select * from {{ ref('stg_flights') }}
),

airports as (
    select * from {{ ref('airports') }}
),

joined as (
    select
        f.*,
        f.scheduled_at at time zone a.timezone         as scheduled_local,
        f.status in ('Departed', 'Arrived')            as is_completed,
        f.status in ('Canceled', 'CanceledUncertain')  as is_cancelled
    from flights f
    join airports a on a.icao = f.airport_icao
),

with_delay as (
    select
        *,
        case when is_completed then
            round(extract(epoch from (coalesce(revised_at, runway_at) - scheduled_at)) / 60.0, 1)
        end as delay_minutes
    from joined
)

select
    flight_key, airport_icao, direction, flight_number,
    airline_iata, airline_name, aircraft_model,
    other_airport_icao, other_airport_name, other_country_code,
    status, scheduled_at, scheduled_local,
    scheduled_local::date                     as scheduled_date_local,
    extract(hour from scheduled_local)::int   as scheduled_hour_local,
    is_completed,
    is_cancelled,
    delay_minutes,
    coalesce(delay_minutes >= 15, false)      as is_delayed
from with_delay
