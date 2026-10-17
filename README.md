# Flight Operations Pipeline

An end-to-end ELT pipeline that ingests live flight data for three major US hubs (ORD, MSP, ATL) from the AeroDataBox API, models it with dbt, and serves delay and cancellation analytics through a Metabase dashboard. Everything runs in Docker Compose on a self-hosted Proxmox VM.

![Dashboard](docs/dashboard.png)

## Stack

| Layer | Tool |
|---|---|
| Orchestration | Apache Airflow 2.10 (LocalExecutor) |
| Warehouse | PostgreSQL 16 |
| Transformation and testing | dbt-postgres 1.9 |
| BI | Metabase |
| Infrastructure | Docker Compose on a Proxmox VM (Ubuntu 24.04) |

## Architecture

See [docs/architecture.md](docs/architecture.md) for the full diagram.

In short: Airflow calls the API every 12 hours (one call per airport), stores the untouched JSON in `raw`, then runs dbt to parse it into `staging` and build the `marts` that Metabase reads.
