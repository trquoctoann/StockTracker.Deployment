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
    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        compose ps || true
        compose logs --no-color --tail=200 api api-worker datacollector postgres s3mock || true
    fi
    compose down --volumes --remove-orphans
    trap - EXIT
    exit "$exit_code"
}
trap cleanup EXIT

compose config --quiet
compose up -d --wait --wait-timeout 240 postgres redis rabbitmq keycloak s3mock alertmanager
compose run --rm --no-deps datacollector alembic upgrade head
compose run --rm --no-deps api alembic upgrade head
compose up -d --wait --wait-timeout 240 api api-worker datacollector prometheus
compose exec -T api python -c "import json, urllib.request; payload=json.load(urllib.request.urlopen('http://localhost:8000/health/ready')); assert all(payload['checks'][name] == 'ok' for name in ('database', 'redis', 'rabbitmq'))"
compose exec -T datacollector python -c "import json, urllib.request; payload=json.load(urllib.request.urlopen('http://localhost:8001/health/ready')); assert all(payload['checks'][name] == 'ok' for name in ('http_client', 'control_database', 'raw_archive'))"
compose run --rm --no-deps datacollector python -c "exec(open('/tmp/smoke-data-foundation.py').read())"
MSYS_NO_PATHCONV=1
export MSYS_NO_PATHCONV
compose exec -T alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml
