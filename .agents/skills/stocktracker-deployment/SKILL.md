---
name: stocktracker-deployment
description: Maintain StockTracker Docker Compose, images, Jenkins CI, monitoring and recovery configuration with explicit environment, schema and runtime validation boundaries.
---

# StockTracker deployment development

Read [AGENTS.md](../../../AGENTS.md), [architecture](../../../docs/architecture.md), [operations](../../../docs/operations.md) and [review](../../../docs/review.md). Determine which file set and Docker daemon the requested change targets before editing.

## Implementation workflow

For Compose changes, inspect the base plus affected development/E2E overrides. Render with example values and verify actual ports, interfaces, volume paths, environment variables and dependencies. Ports are merged by identity, so a wildcard binding may be added alongside a loopback binding. Hostnames valid inside containers may be invalid for browser token issuers.

For application settings, inspect the owning Python Settings and translate the intended value explicitly through Compose. A .env interpolation variable is not automatically a container variable. Keep API/collector exchange/routing/envelope contracts aligned, and keep API-worker on the intended API image/source during development.

For CI, trace checkout -> checks -> image builds -> smoke -> registry push -> rollout. DEPLOY=false does not currently disable image pushing. The bundled staging daemon is Docker-in-Docker; production deployment is unimplemented. Do not change these meanings without documenting the resulting behavior.

For migrations/rollback, inspect both independent Alembic histories. Plan schema compatibility before recreating applications. Retagging an older image does not reverse a schema migration. For backup changes, include the separate identity database and prove restoration in an isolated environment rather than checking dump readability alone.

For monitoring, inspect the actual metric labels and process that emits them. Worker dependency sockets are not consumer health. RabbitMQ aggregated metrics do not satisfy per-queue DLQ selectors; collector freshness must handle no successes and restarts. A receiver definition without an integration does not send notifications.

## Validation and scope

Run the AGENTS.md static checks plus tests appropriate to changed behavior. Foundation smoke removes test volumes: verify a dedicated project identity and daemon before running it. Document whether validation was static rendering, real container execution, complete ingestion, or an actual recovery drill. Do not silently upgrade a passing static check into operational certification.

Update the owning runbook and relevant open finding. Keep credentials and external publication outside generated artifacts; perform external mutations only within the user's request.

## Runtime review fixtures

The completed Docker review demonstrated open defects using temporary admin bootstrap, Keycloak scope/admin setup and market enum DDL in disposable containers. The temporary scripts were removed; the final report records these fixture limitations. Never copy those fixture changes into production or call downstream fixture-assisted success a passing baseline regression. For a fix, rerun the affected flow from checked-in migrations/imports without its workaround. Python Enum fields must agree with real PostgreSQL types and stored labels; successful Alembic upgrade alone does not prove that agreement.
