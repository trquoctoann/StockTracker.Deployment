# Review evidence and reproduction guide

Date: 2026-09-05. This page preserves the initial local-probe evidence. The subsequent [Docker runtime review](runtime-validation.md) supersedes its original infrastructure limitations. The table below is not itself a set of passing regression tests. Inputs were synthetic. Application implementations were not changed.

| Probe | Observed result | How to repeat |
| --- | --- | --- |
| A01 | Outer SessionTransaction remains active after nested TransactionManager exit | Create AsyncSession; begin outer transaction; enter/exit real TransactionManager; inspect in_transaction and outer.is_active. Then use PostgreSQL to test the actual auth-read/write request path |
| A02 | Synthetic password is present in both console and JSON renderings | Construct CreateUserCommand; render event with command=that object through console_renderer and json_renderer; search for the synthetic value |
| A03 | SELECT DISTINCT ON (user.id) count(user.id), no GROUP BY | Apply SQLExecutor filter helper to select(func.count(UserModel.id)) using UserFilterParameter(eq={"user_role.tenant_id":1}); compile with PostgreSQL dialect |
| A04 | ValueError: too many values to unpack (expected 3) | Call SQLExecutor.bulk_delete with the same related filter and a mock session; failure happens before SQL execution |
| A05 | AttributeError: user_role.tenant_id | Build UserPaginationParameter(order_by="user_role.tenant_id"), then build_order_by_clauses(UserModel) |
| A06 | Read key ends in bars:60; delete key ends in bars | Compare get_price_history_bars_cache_key(1,"1D",60) with the two-argument call |
| A07 | ValidationError for limit=101 | Construct StockPriceHistoryPaginationParameter(limit=101,order_by="-time") |
| A08 | username/password/email/first_name/last_name all required | Inspect UserUpdateRequest.model_fields and is_required() |
| A09 | Eight lowercase letters accepted | Validate AccountUpdatePasswordRequest(new_password="abcdefgh") |
| A10 | Principal returned without version check | Put a ContextPrincipal with stale versions on Request.state; call get_authenticated_principal |
| A13 | Service returns id=None; response mapper raises ValidationError | Use a repository double that returns model_copy(update={"id":101}) without mutating input; call shareholder sync, then real SchemaMapper.entity_to_response |
| C01 | Two equal-field trade rows have equal natural keys | Transform a two-row DataFrame without provider IDs through MarketDataPandasProcessor.transform_intraday |
| C02 | Loaded frame attrs={} and ID prefix changes kbs to vnstock | Capture KBS frame with in-memory S3 put/get inside PipelineRunContext; load/check checksum; transform original and loaded frames |
| C04 | No last-success metric sample after first failure | Observe a failed run in new HttpMetrics; render and check samples, excluding HELP/TYPE lines |
| D01 | Both 127.0.0.1 and missing host_ip for PostgreSQL | Run default merged Compose config with example env; inspect service port objects |

## Safe local inspection commands

From each Python repository, the existing environment was used without dependency upgrades:

```sh
python -m pytest -q -p no:cacheprovider
python -m ruff check .
python -m ruff format --check .
python -m pyright
```

Here python means that repository's .venv interpreter, not an arbitrary system interpreter. Tests install synthetic environment defaults through their conftest. Standalone API probes imported tests.conftest before application imports to avoid real configuration dependencies. SQL compilation used sqlalchemy.dialects.postgresql; transaction-state inspection used real AsyncSession with no database bound. This verifies the implementation boundary but does not substitute for the real PostgreSQL regression criteria in the findings.

Compose static checks, from Deployment:

```sh
docker compose --env-file .env.example -f docker-compose.yml config --quiet
docker compose --env-file .env.example config --format json
```

The second command renders example settings; avoid publishing equivalent output for a real secret-bearing environment. These statements describe the initial source-only review. Subsequent Docker execution and its concrete failures are recorded in [runtime validation](runtime-validation.md); do not use this historical limitation as the current validation status.
