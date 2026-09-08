# Docker runtime validation

Date: 2026-09-05. Reviewed source: API `353c531`, DataCollector `c157150`, Deployment `b76224e`. Docker Engine 27.4.0; Compose 2.31.0; application images built from the checked-in frozen lockfiles with Python 3.12.14. This is a diagnostic report, not a statement that the product passes integration testing.

The finalized run used disposable project `stocktracker-review-20260905-b1`. An earlier exploratory run used the suffix `a1`. Both projects and their volumes were removed. The pre-existing stocktracker-alertmanager and stocktracker-s3mock containers remained running. No registry push, staging/production deployment or mutation of existing application data was performed. Locally built review images remain available for another run.

## Result and evidence

The original suite passed: API **326 tests**, collector **141 tests**. Fresh migrations, dependency startup, M2M catalog persistence, collector control-store/archive operations and a limited database restore worked. Real integration tests also reproduced substantial defects hidden by the existing fake-based tests. There are now **29 open review findings**, including four newly identified failures: A16, A17, D06 and D07.

Final static checks also passed: application Ruff lint/format and Pyright, all three English-content checks, all three project skill validators, Compose base/development/review rendering, PowerShell parsing, restore shell syntax and Git whitespace checks. At the time of the review, all five temporary Python diagnostic scripts passed formatting and the API Ruff rules with the CLI print-output rule excluded. The then-current 311 local links across 28 Markdown documents resolved; links were checked again after the cleanup.

Machine-readable observations from the clean run are retained in [runtime-observations.json](runtime-observations.json). They contain structured observations and synthetic identifiers, not bearer tokens, administrator credentials, provider row contents or full application logs. The original findings and correction criteria remain in the [review index](review.md#finding-index).

## Isolation and diagnostic fixtures

The review combined the base manifest with the existing E2E port reset and a temporary review override. It used example credentials, a unique Compose project and independent containers/networks/volumes. No service publishes a host port. Scheduling is disabled. Worker retry delay is shortened from 30000 ms to 500 ms, retaining the configured maximum of three retries. API HTTP and the worker run as separate processes from the same locally built image.

The following changes occur only inside the disposable stack and are logged explicitly. None is a production fix:

1. A human user is created in Keycloak. The imported stocktracker.api client initially produces a token without sub. The harness attaches the available basic scope so subsequent human-auth tests can proceed (D06).
2. The initially empty application user/role/permission tables receive a test-only administrator fixture with all current permission codes (A14).
3. Valid market messages are first tested against the unmodified migration schema and fail. Only after recording those failures does the harness create the missing enum types and align two empty market columns for downstream cache/upsert/retry experiments (A17). This fixture does not handle legacy values and must never be copied into a migration.
4. Baseline account writes fail because the configured administrator authenticates in the wrong realm. A test-only target-realm administrator with management rights is added so profile/password consistency can be observed (D07).

Success after one of these fixtures proves only the downstream behavior under that fixture. In particular, there is no passing stock-market ingestion path from the unmodified checked-in migrations.

## Database and API observations

| Check | Observed result | Interpretation |
| --- | --- | --- |
| Fresh collector/API upgrades | Heads 202608300001 / 20260829000001 | Both migration histories execute, independently |
| Fresh application bootstrap | 0 users, 0 roles, 0 permissions | A14 confirmed; imported M2M roles are not application administration |
| M2M stock sync | First response created=1; repeat skipped=1; row present in separate DB connection | Catalog persistence and repeat handling work |
| Anonymous / malformed bearer | 401 / 500 | A16 confirmed |
| M2M calling an admin stock read | 401 | M2M ingestion role does not grant admin context access |
| Human login with original import | Token lacks sub; API returns 401 | D06 confirmed despite a successful token grant |
| Human context exchange after fixtures | 200 | Real identity verification and context issuance work under the documented fixture |
| Stock create with cold auth cache | HTTP 201, zero committed rows | A01 confirmed |
| Same kind of create with warm cache | HTTP 201, one committed row | Persistence depends on prior authorization reads |
| Five company sync endpoints | Each first create returns 500 with one committed row; identical repeat returns 200 | A13 confirmed for shareholders/officers/affiliations/events/news |
| User related filter | user_role.id.eq=1 returns 500 | A03 executed against real PostgreSQL |
| Related-field ordering | order_by=user_role.tenant_id returns 500 | A05 confirmed |
| Bars limit=101 | 500 | A07 confirmed before enum workaround |
| Unknown permission ID 999999 | 500, SQL role version rolls back to 1 | A15 confirmed |
| Cache after that rollback | Redis role version=2, DB version=1, old context gets 401 | A11 uncommitted-cache publication confirmed; clearing test Redis restores access |
| Baseline account profile write | 500 | D07 confirmed |
| Profile after test admin provisioning | 200; Keycloak firstName=ChangedReview, DB first_name=Review | A01/A12 cross-system divergence confirmed |
| Password change to eight lowercase letters | 204 after admin fixture | A09 confirmed; policy differs from creation validation |
| User create logging | 201; synthetic password found in actual API container logs | A02 confirmed in deployed JSON logging mode |
| Profile-only user PUT | 422 | A08 credential-shaped update requirement confirmed |
| Revoked context after DB version increment and Redis flush | Protected stocks route 401; own account route 200 | A10 confirmed; no cross-user access was asserted |

The separate-session queries run after the HTTP response. They distinguish response serialization failure after commit from a successful response followed by rollback. No fix was applied to transaction ownership, response mapping, auth caching or credential logging.

## RabbitMQ and market persistence

| Phase | Observed result |
| --- | --- |
| Baseline valid candle | Zero rows; missing priceinterval PostgreSQL type; DLQ after three retries |
| Baseline valid trade | Zero rows; missing matchtype PostgreSQL type; DLQ after three retries |
| After test-only enum alignment | Candle insert persists; repeated natural key updates close from 110 to 115 with one row |
| Cached bars after that upsert | HTTP still returns close=110 while DB contains 115 (A06) |
| Trade repeat after enum alignment | One row remains; volume changes from 10 to 20 |
| Malformed JSON | Goes directly to candle DLQ without a retry-count header |
| Two identical trade keys in one batch | Entire new batch remains unpersisted; DLQ after three retries (C01 downstream failure) |

These broker tests use real AMQP publication, the actual worker, real SQL and acknowledgements/dead-letter queues. Synthetic test payloads follow the documented envelopes. The provider smoke below separately checks real source extraction/normalization/archive; it does not establish a complete live-provider-to-API pipeline.

## Collector state, archive and provider

The existing foundation smoke passed against PostgreSQL and S3Mock: advisory-lock collision rejection, run/step completion, watermark write and archive round-trip. Additional real-store checks produced:

| Check | Observation |
| --- | --- |
| Resume through two failures | First step runs on attempts 0 and 2, although it completed on attempt 0; statuses failed/failed/completed (C03) |
| DataFrame archive | Values survive S3 round-trip; attrs becomes empty while separate metadata still says KBS (C02) |
| Incorrect archive checksum | Rejected with ArchiveError |
| Cancellation | Durable status becomes cancelled; a subsequent lock acquisition succeeds |
| Stale recovery before threshold | Zero rows recovered |
| Controlled heartbeat aging beyond threshold | Row stays running until recover_stale_runs is explicitly called; then becomes abandoned (C05 boundary probe) |
| Operator job lookup | Anonymous 401; pipeline_operator M2M reaches missing-job 404; ordinary human token 401 |

C05 used direct timestamp aging to exercise the store boundary and the code's one-time startup recovery rule. A real crash during provider execution, lease-loss race and timed quick-restart drill were not run. The operator test used job lookup; it did not launch all-stock company/market jobs.

Five bounded logical vnstock calls succeeded in the finalized run. Industries use VCI; the other sampled operations use configured KBS. Successful responses were archived in the disposable S3Mock bucket:

| Operation | Sample | Result |
| --- | --- | --- |
| industries_icb | Catalog | 177 rows |
| symbols_by_exchange | Catalog | 3416 rows |
| company_overview | FPT | 1 row; CompanyProfileSync normalization succeeds |
| quote_history | FPT, 2026-08-24 through 2026-08-28 | 5 rows; 5 normalized candle records |
| quote_intraday | FPT, one configured recent page | 100 rows; 100 normalized records; page-cap warning emitted |

These samples are not coverage guarantees. The trade page cap remains a truncation warning; no claim is made about complete daily trades, live price freshness, financial units or corporate-action adjustments. No all-stock provider crawl was performed. The archival provider run catches per-operation failures for reporting, so a completed diagnostic run alone is not proof that each call succeeded; inspect each observation.

## Monitoring and recovery

Prometheus configuration and all five alert rules pass promtool validation. Alertmanager configuration passes amtool validation. All six scrape targets reported up. This does not demonstrate correct alert behavior:

- The real RabbitMQ scrape exposed rabbitmq_queue_messages_ready=2 with no queue label. The deployed DLQ selector returned an empty vector despite the two dead-letter messages (D03).
- The untouched collector HTTP process had no last-success samples, and the stale expression returned an empty vector (C04). Diagnostic jobs executed in separate processes do not populate the HTTP process's in-memory metrics.
- The worker process received SIGSTOP for 20 seconds. Its health checks remained healthy and the published candle was absent from PostgreSQL. After SIGCONT the row appeared (D04).
- Grafana health returned 200 and its database status was ok. Loki's first readiness probe in the clean run returned 503 with its 15-second ingester-readiness delay, although log query returned 200 with a matching stream. A later probe in the exploratory stack returned 200/ready. Compose's Loki configuration check is not equivalent to HTTP readiness.
- Logs were queryable through Loki with the isolated project's labels. No alert notification delivery was tested; the supplied receiver has no external integration.

The real postgres-backup service created a custom-format dump. The actual restore.sh rejected a wrong RESTORE_CONFIRM, then restored into the distinct stocktracker_review_restore database. Source/restored counts matched for user (2), stock (2), company_shareholder (1), stock_price_history (2), stock_intraday (1) and collector.pipeline_runs (8). Both Alembic versions matched. The restored database contained zero Keycloak user_entity tables, consistent with the missing separate identity backup (D02).

This is a limited logical database restore, not a full disaster-recovery drill. It does not verify off-host storage, RPO/RTO, Keycloak recovery, raw-object restoration, point-in-time recovery, production volume recovery or application login against the restored database. The dump was taken after the explicitly documented diagnostic enum fixture.

## Retained review results

On 2026-09-06, the temporary diagnostic runner, Python/shell probes and review-only Compose override were removed at the user's request. This report and runtime-observations.json retain the final evidence, including the isolation settings and fixture limitations above. The original project smoke tests and operational scripts remain in their owning repositories.

Future fixes need focused regression tests against checked-in migrations and realm imports. Require correct baseline behavior without the diagnostic workarounds described above.

## Remaining validation boundaries

No registry publication, Jenkins credential-dependent pipeline, staging rollback or production rollout was attempted. Development wildcard bindings were confirmed by Compose rendering, without deliberately exposing databases on the host. Full company/index pipelines, broker outage recovery, delayed consumer reconciliation, simultaneous revocation races, TLS/browser authorization-code login, performance/soak tests and complete financial business-rule acceptance remain unverified. Source-level findings A04 and the unexercised branches of other findings remain open with their original evidence.
