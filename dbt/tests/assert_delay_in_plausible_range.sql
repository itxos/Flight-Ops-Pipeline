{{ config(severity='warn') }}

select flight_key, delay_minutes
from {{ ref('fct_flights') }}
where delay_minutes < -180 or delay_minutes > 1440
