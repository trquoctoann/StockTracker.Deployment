# Data foundation

## Durable pipeline flow

1. A schedule or `/run/*` request creates a run ID.
2. DataCollector holds a local lock and a PostgreSQL advisory lock keyed by pipeline name.
3. The run and heartbeat are stored in `collector.pipeline_runs`.
4. Each unit of work is stored in `collector.pipeline_steps` as running, completed, failed, or skipped.
5. Valid provider responses are wrapped with source, parameters, schema version, operation, run ID, and capture time; compressed with gzip; stored in S3 or S3Mock; and recorded in `collector.raw_objects` with SHA-256.
6. The collector transforms the response and sends it to an authenticated REST endpoint or RabbitMQ.
7. A watermark advances only after the sink confirms success. Empty results use an explicit empty state; failures preserve the previous cursor.
8. Runs finish as completed, failed, cancelled, or abandoned. Startup recovers stale running records as abandoned.

## Resume and replay

Submit `{"resume_from":"<run-id>"}` to the same pipeline endpoint. The new run records completed parent steps as skipped and executes the remaining steps.

`RawArchive.load` verifies the expected checksum before reconstructing JSON, pandas Series, or pandas table data. Replay is intentionally explicit. A sink must remain idempotent because the system can repeat work after a process stops between sink confirmation and step persistence.

## RabbitMQ retry model

Transient consumer failures are published to `<queue>.retry.<delay-ms>.<index>`. The retry queue TTL dead-letters the message to the original routing key. The `x-retry-count` header increments on each attempt. Permanent input errors and exhausted transient failures go to `<queue>.dead`. A routing failure requeues the original message.

## Observability

Prometheus collects request metrics, pipeline run counts, duration, latest success time, database and Redis health, and RabbitMQ queue statistics. Alert rules cover target loss, queue backlog, dead-letter messages, pipeline failure, and stale pipeline success. Alloy forwards structured container logs to Loki, and Grafana provisions metrics and log data sources.

The local Alertmanager receiver keeps alerts in its interface. Staging and production require an actual notification receiver such as email, Slack, PagerDuty, or a controlled webhook.

## Local verification

```bash
sh scripts/smoke-data-foundation.sh
```

The script uses an isolated project name and unpublishes application and dependency ports. On failure it prints focused service logs before removing all E2E containers, networks, and volumes.

## Boundaries

S3Mock is local-only. The default archive and Loki storage are single-host volumes. Logical backup is not PITR. APScheduler does not persist future schedules. RabbitMQ has no collector-side outbox. These constraints are explicit inputs to later AWS, Terraform, and Kubernetes milestones.
