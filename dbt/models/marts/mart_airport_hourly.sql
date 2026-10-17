select
    airport_icao,
    direction,
    scheduled_hour_local                       as hour_of_day,
    count(*)                                   as flights,
    round(avg(delay_minutes), 1)               as avg_delay_minutes,
    round(100.0 * count(*) filter (where is_delayed)
        / nullif(count(*) filter (where is_completed), 0), 1) as pct_delayed
from {{ ref('fct_flights') }}
group by 1, 2, 3
