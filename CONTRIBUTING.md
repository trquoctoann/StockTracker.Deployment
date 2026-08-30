# Contributing

Use conventional commits and keep each commit focused on one operational or architectural concern.

Every Compose, Jenkins, configuration, script, dashboard, alert, or runbook change requires a documentation impact review. Update the matching file in `docs/` in the same commit. Keep all source, comments, configuration, test data, commit messages, and documentation in English.

Validate Compose, static project checks, dependency audits, application tests, image builds, and isolated E2E before pushing deployment changes. Never commit credentials, claim production readiness from a local-only test, or enable production deployment without an explicit remote rollout and recovery design.

## Documentation ownership

| Document | Update when |
|---|---|
| `README.md` | Local startup, verification commands, endpoints, or document links change |
| `docs/architecture.md` | A service, dependency, network, protocol, or security boundary changes |
| `docs/data-foundation.md` | Data lifecycle, storage, queue, replay, or recovery semantics change |
| `docs/operations.md` | A Compose service, variable, command, pipeline stage, backup, or runbook changes |
| `docs/certification-roadmap.md` | A certification version, milestone, implementation scope, or evidence requirement changes |

Documentation is maintained as code. If a platform change has no documentation impact, record that conclusion in the commit or pull request description.
