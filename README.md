# StockTracker.Deployment

Docker Compose, application Dockerfiles, Jenkins CI, infrastructure configuration, monitoring, and PostgreSQL backup scripts for StockTracker. Source baseline: `b76224e`, documentation rebuilt 2026-09-05.

Keep the three repositories as siblings:

```text
StockTracker/
  StockTracker.API/
  StockTracker.DataCollector/
  StockTracker.Deployment/
```

| Document | Purpose |
| --- | --- |
| [Architecture and system flow](docs/architecture.md) | End-to-end data path, services, CI and ownership |
| [Operations](docs/operations.md) | Explicit startup/migrations, monitoring, recovery, CI |
| [Cross-repository review](docs/review.md) | All 29 open findings, evidence boundaries and fix order |
| [Review evidence](docs/review-evidence.md) | Local reproductions and validation results |
| [Docker runtime validation](docs/runtime-validation.md) | Final live observations, diagnostic fixtures and restore boundaries |
| [Agent instructions](AGENTS.md) | Deployment conventions and checks |

Validate the base configuration without starting services:

```sh
docker compose --env-file .env.example -f docker-compose.yml config --quiet
```

Follow [operations](docs/operations.md) for startup; migrations are explicit. The base manifest is a local lab with single-instance services. The default development override currently adds wildcard infrastructure bindings [D01](docs/review.md#d01), so the documented base commands always specify `-f docker-compose.yml`. No production deployment path is implemented in Jenkins.
