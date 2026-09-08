# Deployment operations

Run commands from StockTracker.Deployment with sibling API/collector checkouts. Docker with Compose v2 and a working daemon is required. Shell scripts require a Unix shell (for example WSL/Git Bash on Windows). Validate Docker access with docker version before claiming runtime tests.

## Configuration and startup

Copy `.env.example` to `.env` only if absent. Set credentials and connection strings for the intended environment. Keep imported Keycloak client settings aligned with API/collector settings. Do not display a real resolved Compose config in shared logs because it contains credentials.

These commands explicitly select the base manifest and avoid the implicit development override:

```sh
docker compose --env-file .env -f docker-compose.yml config --quiet
docker compose --env-file .env -f docker-compose.yml build api datacollector
docker compose --env-file .env -f docker-compose.yml up -d --wait postgres redis rabbitmq keycloak s3mock
docker compose --env-file .env -f docker-compose.yml run --rm --no-deps datacollector alembic upgrade head
docker compose --env-file .env -f docker-compose.yml run --rm --no-deps api alembic upgrade head
docker compose --env-file .env -f docker-compose.yml up -d --no-build --wait api api-worker datacollector
docker compose --env-file .env -f docker-compose.yml up -d alertmanager prometheus postgres-exporter redis-exporter loki alloy grafana
```

Migration commands mutate the configured database; check the target and backup needs before executing. On an existing instance, use forward-compatible migrations and an application rollout plan. API-worker uses the API image built in the second command. Fresh migration success does not provide a first application administrator [A14](../../StockTracker.API/docs/review.md#a14).

The exact minimum Compose version for custom YAML tags must be verified with the installed CLI. The E2E override uses !reset. Base parsing alone does not verify that merge path.

## Development mode

The optional docker-compose.override.yml bind-mounts app source for API HTTP and collector, enables reload, and changes logging. Plain docker compose includes it automatically. It also introduces [wildcard port bindings](review.md#d01). Inspect the final merged ports before using this mode on a networked host.

api-worker is not source-mounted by that override. Rebuild API and recreate both api/api-worker for worker changes; otherwise HTTP and consumer behavior can differ during development.

Deployment-prefixed variables are explicitly translated into application variable names by Compose. A new variable in .env is not automatically available inside a service. Cron hour/minute and fixed history ranges are currently missing from that translation [D05](review.md#d05).

## Health and validation

| Endpoint/check | What it proves | What it does not prove |
| --- | --- | --- |
| API /health/live | Process responds | Schema/data/auth correctness |
| API /health/ready | Database connection and enabled Redis/broker checks | Current migrations, worker subscriptions, data freshness |
| Collector /health/ready | HTTP client initialized; enabled control DB/archive reachable | Provider/API/Keycloak/RabbitMQ business flow |
| Worker Compose health | Dependency TCP ports respond | Consumer readiness/progress |
| Loki Compose check | Configuration validates | Live ingestion/query readiness |
| Keycloak Compose check | TCP listener responds | Realm imported, token flow ready |

Static validation with example values:

```sh
docker compose --env-file .env.example -f docker-compose.yml config --quiet
docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.override.yml config --quiet
docker compose --env-file .env.example -f docker-compose.yml -f tests/e2e/data-foundation.override.yml config --quiet
python scripts/check_english_content.py
```

For Python use an available Python 3.12 interpreter; Deployment has no Python package/dependency manifest. Syntax validation does not prove that overlapping host bindings can start.

The supplied `sh scripts/smoke-data-foundation.sh` starts an isolated test stack, applies migrations, checks dependency readiness, executes the control-store/archive smoke, and validates Prometheus/Alertmanager configuration. It expects built application images. The script unconditionally removes that test project's volumes in cleanup. Only run it with a dedicated COMPOSE_PROJECT_NAME that cannot identify an existing environment. Do not point it at real data.

The smoke tests advisory locks, run/step state, watermark and archive round-trip. It does not cover the full authenticated API/broker ingestion or restore pipeline. A subsequent Docker-enabled review ran migrations, real API/auth/broker diagnostics, collector state/archive checks, monitoring and an isolated restore. See [runtime validation](runtime-validation.md). Baseline failures remain open; downstream tests with temporary schema/identity fixtures are explicitly labeled.

## Observability

Base UI endpoints are localhost:3000 (Grafana), 9091 (Prometheus), 9093 (Alertmanager), 15672 (RabbitMQ management), 8080 (Keycloak) and 12345 (Alloy). Credentials come from the configured environment/import, not this document.

Inspect API/collector/worker logs separately. A healthy collector or completed job does not establish consumer success. Check queue depth, dead letters and persisted rows. Existing RabbitMQ DLQ rules need per-queue series [D03](review.md#d03). Pipeline freshness can be absent after restart [C04](../../StockTracker.DataCollector/docs/review.md#c04). Alertmanager currently has no external receiver, so a rule firing does not mean someone was notified.

## Backup and restore

The backup service is disabled unless its profile is selected:

```sh
docker compose --env-file .env -f docker-compose.yml --profile backup up -d postgres-backup
```

It immediately creates an application-database custom-format dump, validates the archive list, applies configured retention (default 14 days), sleeps for the interval (default 86400 seconds) and repeats. Archive-list validation checks readability, not restorability or application consistency.

`scripts/postgres/restore.sh` accepts one dump path and requires RESTORE_CONFIRM to equal PGDATABASE. It uses pg_restore --clean --if-exists --no-owner and changes the target database. Choose an isolated recovery database, stop writers to the target, verify the selected dump, and configure PGHOST/PGUSER/PGPASSWORD/PGDATABASE explicitly before invoking it. Do not copy a production target into a casual test command.

The supplied backup excludes the separate Keycloak database and shares the host with primary data. Preserve identity/application state, required roles/configuration, and raw archive objects in a complete recovery plan [D02](review.md#d02). The review executed a disposable database restore drill with guard and selected table-count checks. That evidence does not establish complete identity/archive recovery, point-in-time recovery, or declared RPO/RTO.

Stopping with `docker compose --env-file .env -f docker-compose.yml down` retains named volumes. Adding --volumes destroys persistent data; reserve it for a verified disposable test project.

## CI and deployment

The optional Jenkins stack is defined in docker-compose.jenkins.yml. Configure JENKINS_ADMIN_PASSWORD and inspect privileged Docker-in-Docker use before starting it. The shared workspace mount allows the daemon to resolve pipeline bind mounts.

Required Jenkins credentials are git-credentials, dockerhub-credentials, and stocktracker-staging-env (secret file). CASC provisions Jenkins login/security; it does not provision these credentials or automatically create a build job. Configure a Pipeline from SCM using jenkins/Jenkinsfile.

Parameters: BRANCH chooses API/collector branch; ENVIRONMENT selects staging/production; SKIP_TESTS skips lint/tests; DEPLOY toggles rollout. Images still build, run the foundation smoke and push when DEPLOY=false. Production is explicitly unimplemented.

The bundled daemon target is Docker-in-Docker. A staging rollout there is not a rollout to an external server. Confirm daemon context and host accessibility. Rollback restores previous application images only; database upgrades are not reversed. Use additive migrations and test backward compatibility, or define a reviewed data restoration procedure before destructive schema changes.

## Review results

The final Docker observations and limitations are retained in [runtime validation](runtime-validation.md). Temporary review scripts and overrides were removed after the review; the original foundation smoke and backup/restore scripts remain available. Future regression tests must verify the affected baseline flow without diagnostic workarounds.
