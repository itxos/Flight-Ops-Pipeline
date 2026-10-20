.PHONY: up down build logs dbt-run dbt-test dbt-seed psql

up:
	docker compose up -d

down:
	docker compose down

build:
	docker compose build

logs:
	docker compose logs -f

dbt-seed:
	docker compose run --rm dbt seed

dbt-run:
	docker compose run --rm dbt run

dbt-test:
	docker compose run --rm dbt test

psql:
	docker exec -it flights-postgres psql -U warehouse -d flights
