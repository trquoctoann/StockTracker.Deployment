# Cross-repository technical review

Date: 2026-09-05. Baselines: API `353c531`, DataCollector `c157150`, Deployment `b76224e`. All repositories were clean at review start (collector Git emitted an inaccessible pytest-cache warning). Application runtime source, migrations and base configuration were not changed. Temporary diagnostic scripts and overrides were removed after the review; final reports and observations are retained. Documentation was replaced and agent guidance added. Findings remain open.

## Assessment

The system has a clear module structure and useful unit/HTTP tests, but the supplied flows are not yet reliable enough to infer correctness from green tests or healthy containers. Live testing found that fresh migrations block market persistence and the imported human identity/admin configuration blocks account flows. Prioritize those blockers together with API transaction ownership, company response persistence, credential logging and authorization consistency.

The API owns canonical tables, collector owns operational state/archive, and Deployment owns packaging/operations. There is no frontend or trading/portfolio business engine in these repositories.

## Validation actually performed

The source review was followed by a Docker-enabled review on 2026-09-05. Application implementations, production manifests and migrations remain unchanged. The temporary diagnostic runner and overrides were removed on 2026-09-06; final results and limitations remain in [runtime validation](runtime-validation.md).

| Check | Result | Boundary |
| --- | --- | --- |
| API pytest | 326 passed in 24.52s | Existing unit/fake HTTP suite |
| Collector pytest | 141 passed in 14.91s | Existing deterministic suite |
| Ruff, formatting, Pyright | Passed again in both application repositories | Application code unchanged |
| Fresh API and collector migrations | Passed | Does not imply ORM compatibility: A17 fails afterward |
| Real PostgreSQL/Redis/Keycloak/API | Executed; several defects reproduced | Test-only admin/bootstrap fixtures documented |
| Broker processing | Baseline valid messages reach DLQ | Downstream upsert/retry tested after temporary enum alignment |
| Control store, archive and provider samples | Executed | Does not certify full-market coverage or source financial units |
| Prometheus/Alertmanager/Grafana/Loki | Config and live endpoint checks executed | Worker/DLQ/freshness detection defects remain |
| Backup/restore | Isolated application/collector restore executed | Separate Keycloak database absent; no complete recovery certification |

The first review's Docker-unavailable note is historical. Docker 27.4.0 and Compose 2.31.0 were accessible outside the sandbox during the runtime review. No production project was targeted.

API [A01-A17](../../StockTracker.API/docs/review.md), collector [C01-C05](../../StockTracker.DataCollector/docs/review.md), and deployment D01-D07 contain 29 open findings: 11 P1, 17 P2 and 1 P3. New live findings are A16, A17, D06 and D07. Initial local observations remain in [review evidence](review-evidence.md).

## Deployment findings

P1: high-impact flow/security/recovery issue. P2: normal-priority correctness. P3: latent low-impact utility problem. Severity depends on the documented trigger. Configuration findings below are not claims about an uninspected production environment.

<a id="d01"></a>
## D01 [P1] Default development overrides add wildcard infrastructure port bindings

Source: [docker-compose.override.yml:33](../docker-compose.override.yml#L33), [docker-compose.yml:20](../docker-compose.yml#L20).

Evidence: Rendered docker compose --env-file .env.example config. PostgreSQL has both a host_ip=127.0.0.1 binding and a second binding with no host_ip; Redis and RabbitMQ override ports follow the same pattern. Plain docker compose automatically includes this override file.

Impact: Local development unintentionally attempts to publish database/cache/broker ports on all interfaces; overlapping bindings may also conflict. The base manifest's loopback restriction is not preserved by the default merged configuration.

Recommended correction: Keep development bindings explicitly on loopback and use verified Compose replacement/reset semantics where needed. Validate the merged default file set, not only docker-compose.yml.

Regression criterion: Inspect final bindings for PostgreSQL/Redis/RabbitMQ and start the stack in a disposable environment; all intended host ports must bind only to the declared interface.

<a id="d02"></a>
## D02 [P1] Database backup omits the separate Keycloak database

Source: [docker-compose.yml:252](../docker-compose.yml#L252), [scripts/postgres/backup.sh:8](../scripts/postgres/backup.sh#L8), [config/postgres/init-scripts/01-init-databases.sh:17](../config/postgres/init-scripts/01-init-databases.sh#L17).

Evidence: The backup service runs pg_dump for POSTGRES_DB only. Initialization creates a separate KEYCLOAK_DB_NAME database, but no backup job covers it. Dumps live in another volume on the same Docker host. The profile is opt-in.

Live validation: The actual backup script produced an archive that restore.sh restored into an isolated database. Selected application/collector table counts and migration heads matched; the restored database contained no Keycloak user_entity table. See [restore boundary](runtime-validation.md#monitoring-and-recovery).

Impact: Restoring the application dump cannot restore identity credentials/sessions/configuration needed by user UUIDs. Host/storage loss can also remove both primary data and local backup volume. This is not a complete system recovery mechanism.

Recommended correction: Back up identity and application databases plus required role/configuration state, retain archive data, and define independent/off-host storage and restoration order. Make recovery objectives explicit.

Regression criterion: Restore all required state into an isolated stack and verify a real identity login, context switching, and existing application data. pg_restore --list alone does not establish recovery.

<a id="d03"></a>
## D03 [P2] Dead-letter alert depends on queue labels the scrape configuration does not request

Source: [config/prometheus/alerts.yml:18](../config/prometheus/alerts.yml#L18), [config/prometheus/prometheus.yml:26](../config/prometheus/prometheus.yml#L26), [config/rabbitmq/enabled_plugins:1](../config/rabbitmq/enabled_plugins#L1).

Evidence: The alert selects queue=~".*\\.dead", while the RabbitMQ job uses the default /metrics path and there is no return_per_object_metrics configuration. RabbitMQ documents this endpoint as aggregated by default; the later live scrape confirmed an aggregated rabbitmq_queue_messages_ready value of 2 without queue labels. Prometheus returned an empty vector for the deployed DLQ selector while both dead-letter queues contained messages.

Impact: The DLQ-specific selector can match no series, so dead letters remain invisible to the declared alert.

Recommended correction: Scrape the required per-queue metric family/endpoint and align metric names/labels with the rule; then verify with a real dead-letter message. See [RabbitMQ endpoint documentation](https://www.rabbitmq.com/docs/prometheus#prometheus-endpoints-metrics).

Regression criterion: Create a .dead queue with a message, confirm the scraped series has queue/vhost labels, and verify the rule fires after its configured duration.

<a id="d04"></a>
## D04 [P2] Worker health only tests unrelated TCP listeners

Source: [docker-compose.yml:228](../docker-compose.yml#L228).

Evidence: The api-worker healthcheck launches a separate process opening TCP sockets to PostgreSQL/Redis/RabbitMQ. It does not inspect worker subscriptions, AMQP authentication, heartbeat or processing progress.

Live validation: The isolated worker received SIGSTOP for 20 seconds; Docker health stayed healthy while a new candle was unpersisted. After SIGCONT the row appeared.

Impact: A stuck or disconnected consumer process can appear healthy while dependencies still listen. compose --wait cannot prove consumer readiness, and no worker target is separately scraped.

Recommended correction: Expose/check worker-owned readiness and liveness, including successful subscription state or a bounded processing heartbeat. Keep dependency connectivity checks distinct.

Regression criterion: Break worker consumption while leaving dependency TCP ports open. Worker readiness must fail or an explicit no-consumer/progress alert must trigger.

<a id="d05"></a>
## D05 [P2] Collector schedule and explicit history settings are not forwarded by Compose

Source: [docker-compose.yml:324](../docker-compose.yml#L324), [docker-compose.yml:330](../docker-compose.yml#L330).

Evidence: Settings provides listing/company/market cron hour/minute and explicit history start/end. Compose forwards enable/timezone/lookback but no variables for those cron fields or explicit start/end. An entry in Deployment .env is only interpolation input; it is not automatically passed into the container.

Impact: Operators cannot change those schedules/windows by setting the corresponding prefixed deployment variables alone; the container silently uses application defaults.

Recommended correction: Expose the supported operational settings explicitly in Compose and .env.example, or document a maintained override mechanism. Keep naming aligned with Settings.

Regression criterion: Set nondefault cron times and a fixed history range, inspect the rendered service environment, and assert the container Settings sees the intended values.

<a id="d06"></a>
## D06 [P1] Imported human client tokens lack the subject required by the API

Source: [realm-export.json](../config/keycloak/realm-export.json), [API identity codec](../../StockTracker.API/app/common/auth/identity_token_codec.py).

Evidence: With the unmodified import on Keycloak 26.6, a real user password grant for stocktracker.api returned a token with the expected issuer and azp, but no sub. GET /api/accounts returned 401. Attaching the available basic client scope to that client only in the disposable fixture added sub and allowed downstream authentication. M2M data ingestion already worked.

Impact: Successful Keycloak login does not produce a human token the API accepts, even after application bootstrap.

Recommended correction: Make the imported client scopes/subject mapping explicit for the pinned Keycloak version, then verify authorization-code and password-grant tokens where those flows are supported. Do not weaken the API's required subject validation.

Regression criterion: From a fresh import, obtain a real human access token with sub and complete account lookup/context exchange without manually modifying client scopes.

<a id="d07"></a>
## D07 [P1] Example identity-administration credentials target the wrong realm

Source: [.env.example](../.env.example), [identity provider construction](../../StockTracker.API/app/modules/user/infrastructure/external/keycloak_identity_provider.py).

Evidence: Compose configures the bootstrap admin credentials for API identity administration. Keycloak bootstraps that account in master, but KeycloakIdentityProvider sets both realm_name and user_realm_name to stocktracker. Profile and password writes returned 500 against the baseline realm. The review uses an explicitly labeled target-realm administrator fixture to reach subsequent consistency checks.

Impact: The example stack cannot perform identity-backed user/account mutations as configured.

Recommended correction: Configure the administrator's authentication realm independently, or provision a deliberately restricted target-realm service account with the required management permissions. Keep credentials and provisioning explicit.

Regression criterion: From fresh maintained configuration, create an identity, update its profile/password and remove it through the API; verify both Keycloak and committed application state without a diagnostic admin fixture.

## Coverage and deployment limitations

- `tests/e2e/smoke_data_foundation.py` tests advisory locking, a completed collector step, watermark and JSON archive round-trip. It does not call authenticated stock/company sync, publish a market payload, assert consumer database writes, exercise retry/DLQ or restore backups. Calling it a complete ingestion E2E test would be inaccurate. The completed runtime review extended coverage, with its fixtures and remaining limits recorded in [runtime validation](runtime-validation.md).
- API readiness can pass against an unmigrated database because SELECT 1 succeeds. Local startup must run both migration histories explicitly.
- Prometheus DataPipelineStale depends on in-memory last-success data [C04](../../StockTracker.DataCollector/docs/review.md#c04). Alertmanager's receiver has no notification integration, so alerts can appear in its UI without reaching an operator.
- Jenkins production deployment intentionally errors. Staging targets the configured Docker daemon (the bundled Jenkins setup points at Docker-in-Docker), not a configured remote production host. Host access through nested loopback-bound ports needs live verification.
- Staging rollback retags application images; it does not revert database migrations. Schema compatibility and a restore strategy are required for destructive/incompatible migrations.
- The development override mounts/reloads API HTTP code but does not mount/reload api-worker. Rebuild/recreate the worker when testing consumer changes.
- Keycloak host/browser token issuer versus internal keycloak:8080 issuer requires a consistent configuration; a host login is not covered by the M2M lab path.
- Shared host volumes, single instances, S3Mock, example credentials and disabled external notifications define a local lab, not a high-availability production design.

## Fix order and acceptance

1. Align market schema/model enums A17 and fix identity import/admin blockers D06/D07. Fix A01/A13 and test HTTP writes/response IDs through real repositories; stop password logging A02 and restrict merged ports D01.
2. Establish first-admin provisioning A14, identity repair A12 and commit-safe authorization versions A11.
3. Fix user filter/sort execution, bars/cache contracts, update/password/revocation behavior and invalid permission references.
4. Make trade identity/replay/resume/recovery explicit (C01-C05), then prove broker-to-database delivery and visibility of failed ingestion.
5. Finish backup/restore coverage, queue/freshness/worker alerts, exposed operational settings, and an actual deployment/rollback exercise.

## Unresolved business decisions

There is no supplied accepted specification to prove all financial business rules. Confirm tenant access, canonical price/percentage units, monetary precision, corporate-action adjustment policy, trading-calendar/coverage expectations, legitimate empty-snapshot semantics, and historical retention. Defaults such as a rolling 30-day candle window and one recent-trades page are implemented choices, not evidence that they meet the product requirement.

## Documentation replacement

All original README.md, CONTRIBUTING.md and docs Markdown files in the three repositories were rewritten or removed. Old certification-roadmap.md, data-foundation.md and vnstock-compatibility.md are removed; their replacement is the source-based architecture/contracts/operations/review set. Licenses, migrations, source docstrings and third-party research/cache material are not obsolete project design documents and were preserved.

## Finding index

| ID | Priority | Finding |
| --- | --- | --- |
| [A01](../../StockTracker.API/docs/review.md#a01) | P1 | HTTP writes can release a savepoint without committing the request transaction |
| [A02](../../StockTracker.API/docs/review.md#a02) | P1 | User request logging exposes plaintext passwords |
| [A03](../../StockTracker.API/docs/review.md#a03) | P2 | Joined user filters produce invalid count and ordered-page SQL |
| [A04](../../StockTracker.API/docs/review.md#a04) | P3 | Shared bulk_delete unpacks the wrong join tuple shape |
| [A05](../../StockTracker.API/docs/review.md#a05) | P2 | User sorting advertises relation fields the executor cannot resolve |
| [A06](../../StockTracker.API/docs/review.md#a06) | P2 | Candle invalidation deletes a key that readers never populate |
| [A07](../../StockTracker.API/docs/review.md#a07) | P2 | Bars endpoint accepts 500 rows but its internal model caps requests at 100 |
| [A08](../../StockTracker.API/docs/review.md#a08) | P2 | User update requires credential fields that the service ignores |
| [A09](../../StockTracker.API/docs/review.md#a09) | P2 | Account password changes bypass the strength rule used at user creation |
| [A10](../../StockTracker.API/docs/review.md#a10) | P2 | Account actions accept context tokens without version revocation checks |
| [A11](../../StockTracker.API/docs/review.md#a11) | P1 | Authorization cache values can be published or repopulated before commit |
| [A12](../../StockTracker.API/docs/review.md#a12) | P1 | Keycloak mutations have no recovery for local transaction failure |
| [A13](../../StockTracker.API/docs/review.md#a13) | P1 | Five company sync services discard generated IDs and fail response validation |
| [A14](../../StockTracker.API/docs/review.md#a14) | P1 | Fresh deployments cannot bootstrap application administration through supported code |
| [A15](../../StockTracker.API/docs/review.md#a15) | P2 | Role permission assignment passes unresolved IDs into foreign-key inserts |
| [C01](../../StockTracker.DataCollector/docs/review.md#c01) | P2 | Repeated trade identities can poison a whole upsert batch |
| [C02](../../StockTracker.DataCollector/docs/review.md#c02) | P2 | Raw load loses DataFrame source context needed for equivalent replay |
| [C03](../../StockTracker.DataCollector/docs/review.md#c03) | P2 | A second resume reruns steps that were skipped on the first resume |
| [C04](../../StockTracker.DataCollector/docs/review.md#c04) | P2 | Freshness metrics disappear on restart or before any success |
| [C05](../../StockTracker.DataCollector/docs/review.md#c05) | P2 | Quick restart can strand interrupted runs in running status |
| [D01](#d01) | P1 | Default development overrides add wildcard infrastructure port bindings |
| [D02](#d02) | P1 | Database backup omits the separate Keycloak database |
| [D03](#d03) | P2 | Dead-letter alert depends on queue labels the scrape configuration does not request |
| [D04](#d04) | P2 | Worker health only tests unrelated TCP listeners |
| [D05](#d05) | P2 | Collector schedule and explicit history settings are not forwarded by Compose |
| [A16](../../StockTracker.API/docs/review.md#a16) | P2 | Malformed identity bearer tokens become internal server errors |
| [A17](../../StockTracker.API/docs/review.md#a17) | P1 | Market ORM enum types do not match the migrated PostgreSQL schema |
| [D06](#d06) | P1 | Imported human client tokens lack the subject required by the API |
| [D07](#d07) | P1 | Example identity-administration credentials target the wrong realm |
