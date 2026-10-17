import json
import logging
import os

import pendulum
import requests
from airflow.decorators import dag, task
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.operators.bash import BashOperator


log = logging.getLogger(__name__)

AIRPORTS = {
    "KORD": "America/Chicago",
    "KMSP": "America/Chicago",
    "KATL": "America/New_York",
}
FMT = "%Y-%m-%dT%H:%M"
DBT = "cd /opt/airflow/dbt && /home/airflow/dbt_venv/bin/dbt"


@dag(
    dag_id="flight_ingest",
    schedule="0 */12 * * *",
    start_date=pendulum.datetime(2026, 10, 16, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    tags=["flights", "ingestion"],
)
def flight_ingest():
    @task(retries=3, retry_delay=pendulum.duration(minutes=2))
    def ingest(icao: str, data_interval_start=None, data_interval_end=None):
        tz = AIRPORTS[icao]
        start = data_interval_start.in_timezone(tz)  # API expects airport-local time
        end = data_interval_end.in_timezone(tz)

        host = os.environ["RAPIDAPI_HOST"]
        url = (
            f"https://{host}/flights/airports/icao/{icao}/"
            f"{start.strftime(FMT)}/{end.strftime(FMT)}"
        )
        params = {
            "direction": "Both", "withLeg": "true", "withCancelled": "true",
            "withCodeshared": "false", "withCargo": "false",
            "withPrivate": "false", "withLocation": "false",
        }
        headers = {
            "x-rapidapi-key": os.environ["RAPIDAPI_KEY"],
            "x-rapidapi-host": host,
        }

        resp = requests.get(url, params=params, headers=headers, timeout=60)
        resp.raise_for_status()
        payload = resp.json()

        log.info(
            "%s %s -> %s | departures=%d arrivals=%d | quota remaining=%s",
            icao, start, end,
            len(payload.get("departures", [])), len(payload.get("arrivals", [])),
            resp.headers.get("x-ratelimit-requests-remaining"),
        )

        hook = PostgresHook(postgres_conn_id="warehouse_pg")
        with hook.get_conn() as conn, conn.cursor() as cur:
            cur.execute(
                "DELETE FROM raw.flights_raw WHERE airport_icao = %s AND window_start = %s",
                (icao, start.strftime(FMT)),
            )
            cur.execute(
                """INSERT INTO raw.flights_raw (airport_icao, window_start, window_end, payload)
                   VALUES (%s, %s, %s, %s::jsonb)""",
                (icao, start.strftime(FMT), end.strftime(FMT), json.dumps(payload)),
            )

    ingested = ingest.expand(icao=list(AIRPORTS.keys()))
    dbt_seed = BashOperator(task_id="dbt_seed", bash_command=f"{DBT} seed")
    dbt_run = BashOperator(task_id="dbt_run", bash_command=f"{DBT} run")
    dbt_test = BashOperator(task_id="dbt_test", bash_command=f"{DBT} test")

    ingested >> dbt_seed >> dbt_run >> dbt_test


flight_ingest()
