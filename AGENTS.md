# Deployment agent instructions

Read [.agents/skills/stocktracker-deployment/SKILL.md](.agents/skills/stocktracker-deployment/SKILL.md), [architecture](docs/architecture.md), [operations](docs/operations.md) and relevant [findings](docs/review.md) for deployment/configuration work.

## Conventions

- Keep API, DataCollector and Deployment as sibling checkouts. Build contexts point to application repositories; Dockerfiles live here. API-worker reuses the API image. Application logic/migrations belong to the application repositories.
- Use Compose v2 and explicit -f file selections. Base manifests, implicit development overrides, E2E overrides and Jenkins Compose have different behavior. Verify effective port/network/volume/environment values after merge, not just YAML syntax.
- Preserve explicit intended host interfaces. Keep credentials in environment/credential stores and document only example configuration. Do not publish resolved real Compose environments in logs.
- Application variable names are translated explicitly from Deployment-prefixed variables. For newly configurable settings, update the owning Settings, its example file and this repository's environment mapping together.
- Keep HTTP and consumer processes separate in the base deployment. Consumer readiness must describe worker behavior; TCP reachability of dependencies alone is not proof. Do not claim full ingestion based on collector run completion.
- Migrate both owners explicitly before application rollout. Collector version table is collector.alembic_version; API uses its own default-schema history. Account for old image compatibility before relying on image-only rollback.
- Preserve unique COMPOSE_PROJECT_NAME isolation for temporary stacks. The foundation smoke removes volumes; use only a verified disposable project. Existing backup/restore scripts do not establish complete identity/application recovery.
- Shell scripts use Unix line endings and error handling consistent with their actual shell. Use quoted arguments. This repository has no standalone Python dependency manifest; do not invent uv commands that assume one.
- Keep English ASCII project text. Use focused structured YAML/JSON edits and maintain source/runbook consistency. Do not label unconfigured production, alert notifications or recovery as implemented.

## Checks

```sh
python scripts/check_english_content.py
docker compose --env-file .env.example -f docker-compose.yml config --quiet
docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.override.yml config --quiet
docker compose --env-file .env.example -f docker-compose.yml -f tests/e2e/data-foundation.override.yml config --quiet
```

Also inspect changed effective configuration values. Validate JSON syntax and shell syntax for changed files. When available and relevant, run Prometheus/Alertmanager checks and an isolated container smoke. Do not run destructive smoke cleanup against an existing environment or report a runtime test when only config rendering ran.

Report image/config/schema compatibility, checks executed, and outstanding limitations. Documentation-only work needs content/link/source validation. Production rollout, registry publication and operator notification must stay within the user's authorized task.
