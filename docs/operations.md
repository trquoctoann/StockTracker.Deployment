# Platform operations

## Environment and secrets

Copy `.env.example` to `.env` and replace all placeholders. Do not commit `.env`. PostgreSQL and Keycloak bootstrap values only apply when their volumes are first initialized; changing the file does not rotate credentials in an existing volume.

Validate the resolved Compose model without printing secrets:

```bash
docker compose -f docker-compose.yml config --quiet
```

## Migration order

The API owns `public.alembic_version`; DataCollector owns `collector.alembic_version`. Run collector first to migrate legacy lab volumes that used the public version table:

```bash
docker compose -f docker-compose.yml run --rm datacollector alembic upgrade head
docker compose -f docker-compose.yml run --rm api alembic upgrade head
```

Never run application startup against a partially migrated database.

## Local lifecycle

```bash
docker compose -f docker-compose.yml up -d --wait --wait-timeout 240
docker compose -f docker-compose.yml ps
docker compose -f docker-compose.yml logs --tail=200 api api-worker datacollector
docker compose -f docker-compose.yml down
```

Use `docker compose down --volumes` only when intentionally discarding local state.

## Jenkins lab

`docker compose -f docker-compose.jenkins.yml up -d --build` starts a non-root Jenkins controller configured by JCasC and a separate privileged Docker daemon. Configure credentials named `git-credentials`, `dockerhub-credentials`, and the secret file `stocktracker-staging-env`.

The pipeline performs checkout, frozen sync, Ruff, formatting, Pyright, pip-audit, pytest, image build, data-foundation E2E, registry push, staging dependency startup, collector and API migrations, application rollout, readiness smoke checks, and rollback on failure. Production deployment is intentionally blocked until Kubernetes or another remote rollout target exists.

Staging uses only `docker-compose.yml`; it does not load the development override with source mounts and reload commands.

## Backup and restore

Start logical backup with:

```bash
docker compose -f docker-compose.yml --profile backup up -d postgres-backup
```

Each custom-format dump is checked by `pg_restore --list` and retained for `POSTGRES_BACKUP_RETENTION_DAYS`. Restore is destructive and requires `RESTORE_CONFIRM` to equal the target database name:

```bash
RESTORE_CONFIRM=stocktracker /scripts/restore.sh /backups/stocktracker-<timestamp>.dump
```

Test restores against a disposable database and compare critical table counts. Logical dumps do not provide PITR; production requires WAL archive, off-host encrypted storage, backup-age alerts, and scheduled restore drills.

## Troubleshooting order

1. Run `docker compose ps` and identify unhealthy or restarting services.
2. Read focused logs for the first failed dependency, not only the final application.
3. Check PostgreSQL migration versions in both schemas.
4. Inspect `/health/ready` payloads for the exact dependency failure.
5. Check RabbitMQ retry and dead-letter queues, Prometheus targets, and current alerts.
6. Preserve raw archive objects and run IDs before replay or cleanup.
7. Roll back application images without rolling back already applied migrations unless a tested database recovery plan explicitly requires it.

## Release evidence

Record test counts, dependency-audit outcome, image tags or digests, migration heads, E2E result, restore-drill date, and any unverified external provider behavior. Never describe a submitted command as a completed verification until its final exit status and outputs have been checked.
