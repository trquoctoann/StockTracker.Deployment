# Contributing

Follow [AGENTS.md](AGENTS.md) and read [operations](docs/operations.md) before modifying Compose, CI, migration ordering or backup behavior.

Changes must identify which manifest/daemon/environment they affect. Validate both the base and any affected merged configurations, using example configuration for shareable output. Keep API/collector settings and transport contracts synchronized with their owning repositories. Record actual checks and distinguish static validation from live deployment or recovery testing.

Use English ASCII text. Preserve Unix line endings for shell scripts. Document current behavior in this repository and put desired behavior in the [review backlog](docs/review.md) until implemented. Credentials belong in environment/credential stores, not source or logs.
