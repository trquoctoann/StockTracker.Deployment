# StockTracker Deployment

This repository defines the local and single-host staging platform for StockTracker. It includes Docker Compose, Jenkins, PostgreSQL, Redis, RabbitMQ, Keycloak, S3Mock, Prometheus, Alertmanager, Grafana, Loki, Alloy, exporters, migrations, backup scripts, and isolated end-to-end verification.

## Start the local lab

1. Copy `.env.example` to `.env` and replace every `CHANGE_ME_*` value. Keycloak client secrets must match the realm import during the first volume initialization.
2. Validate configuration with `docker compose -f docker-compose.yml config --quiet`.
3. Run collector migrations first, then API migrations:

   ```bash
   docker compose -f docker-compose.yml run --rm datacollector alembic upgrade head
   docker compose -f docker-compose.yml run --rm api alembic upgrade head
   ```

4. Start and wait for the stack:

   ```bash
   docker compose -f docker-compose.yml up -d --wait --wait-timeout 240
   ```

5. Open Grafana at `http://localhost:3001`, Prometheus at `http://localhost:9091`, and Alertmanager at `http://localhost:9093`. Published ports bind to loopback only.

## Verify the data foundation

The E2E script creates an isolated Compose project, runs both migration chains, starts API, worker, collector, and monitoring services, validates readiness, checks advisory locking, raw archive replay, watermarks, and Prometheus or Alertmanager configuration, then removes its containers and volumes.

```bash
sh scripts/smoke-data-foundation.sh
```

Before committing a deployment change, also validate the English-only policy and resolved Compose model:

```bash
python3 scripts/check_english_content.py
docker compose --env-file .env.example -f docker-compose.yml config --quiet
```

## Documentation

- [Platform architecture and review](docs/architecture.md)
- [Data foundation](docs/data-foundation.md)
- [Operations, CI/CD, backup, and recovery](docs/operations.md)
- [Certification implementation roadmap](docs/certification-roadmap.md)
- [Documentation maintenance policy](docs/README.md)
- [Contribution rules](CONTRIBUTING.md)

This Compose platform is a learning and single-host staging environment. Production requires cloud or cluster infrastructure, TLS, managed secrets, managed storage, PITR, immutable signed images, and measured capacity.
