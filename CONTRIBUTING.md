# Contributing

Use conventional commits and keep each commit focused on one operational or architectural concern.

Every Compose, Jenkins, configuration, script, dashboard, alert, or runbook change requires a documentation impact review. Update the matching file in `docs/` in the same commit. Keep all source, comments, configuration, test data, commit messages, and documentation in English.

Validate Compose, static project checks, dependency audits, application tests, image builds, and isolated E2E before pushing deployment changes. Never commit credentials, claim production readiness from a local-only test, or enable production deployment without an explicit remote rollout and recovery design.
