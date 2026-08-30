# Deployment documentation

| Document | Purpose | Update when |
|---|---|---|
| [architecture.md](architecture.md) | Current platform, service boundaries, completed remediation, and production limits | A service, dependency, network, protocol, or security boundary changes |
| [data-foundation.md](data-foundation.md) | Durable collector state, raw archive, replay, messaging, and observability | Data lifecycle, storage, queue, or recovery semantics change |
| [operations.md](operations.md) | Local startup, CI/CD, migration order, backup, recovery, and troubleshooting | A Compose service, environment variable, command, pipeline stage, or runbook changes |
| [certification-roadmap.md](certification-roadmap.md) | Project work mapped to SAA-C03, Terraform Associate, CKAD, and AWS MLA | Certification version, scope, milestone, or completion evidence changes |

Documentation is maintained as code. Behavior, configuration, architecture, and operational changes update the matching document in the same commit. All project content is written in English.
