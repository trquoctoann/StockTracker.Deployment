#!/usr/bin/env sh
set -eu

project_name="${COMPOSE_PROJECT_NAME:-stocktracker-data-foundation-e2e}"

compose() {
    docker compose \
        -p "$project_name" \
        --env-file .env.example \
        -f docker-compose.yml \
        -f tests/e2e/data-foundation.override.yml \
        "$@"
}

cleanup() {
    compose down --volumes --remove-orphans
}
trap cleanup EXIT

compose config --quiet
compose up -d --wait --wait-timeout 180 postgres s3mock alertmanager prometheus
compose run --rm --no-deps datacollector alembic upgrade head
compose run --rm --no-deps datacollector python -c "exec(open('/tmp/smoke-data-foundation.py').read())"
compose exec -T alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml
