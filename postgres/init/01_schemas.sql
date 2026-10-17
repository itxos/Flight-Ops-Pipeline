SELECT 'CREATE DATABASE airflow' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'airflow')\gexec
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS marts;

CREATE TABLE IF NOT EXISTS raw.flights_raw (
    id             BIGSERIAL PRIMARY KEY,
    airport_icao   TEXT        NOT NULL,
    window_start   TIMESTAMP   NOT NULL,   -- airport-local time
    window_end     TIMESTAMP   NOT NULL,
    payload        JSONB       NOT NULL,   -- full API response
    ingested_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_flights_raw_airport_window
    ON raw.flights_raw (airport_icao, window_start);
SELECT 'CREATE DATABASE metabase' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metabase')\gexec
