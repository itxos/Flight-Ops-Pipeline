select
    airport_icao,
    scheduled_date_local                       as flight_date,
    airline_iata,
    airline_name,
    count(*)                                   as flights,
    count(*) filter (where is_cancelled)       as cancelled_flights,
    count(*) filter (where is_delayed)         as delayed_flights,
    round(avg(delay_minutes), 1)               as avg_delay_minutes,
    round(100.0 * count(*) filter (where is_delayed)
        / nullif(count(*) filter (where is_completed), 0), 1) as pct_delayed
from {{ ref('fct_flights') }}
where airline_iata is not null
group by 1, 2, 3, 4
