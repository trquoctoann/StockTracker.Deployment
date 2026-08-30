# Certification implementation roadmap

The project is prepared as a practical lab for AWS Solutions Architect Associate SAA-C03, HashiCorp Terraform Associate 004, CNCF CKAD, and AWS Certified Machine Learning Engineer Associate. The milestones add only capabilities that support a real operating requirement.

## Foundation before certificate work

Complete and preserve the current baseline: deterministic tests, dependency audit, isolated Docker E2E, durable pipeline state, raw archive, idempotent ingestion, retry and dead-letter behavior, readiness, metrics, logs, alerts, and backup or restore procedures. The remaining pre-cloud work is a measured load baseline, data-quality reporting, and a deliberate source-to-broker outbox decision.

## SAA-C03 milestone

Implement a documented AWS target architecture with VPC, public and private subnets, route tables, security groups, load balancing, Route 53, ACM, IAM roles, ECR, S3, RDS PostgreSQL, ElastiCache, a broker choice, Secrets Manager, KMS, CloudWatch, backup, budgets, and cost tags.

Start with ECS or EC2 if the learning objective is AWS architecture. Use EKS later with the CKAD milestone. Required evidence includes an HA and DR diagram, RPO and RTO, restore drill, failure-mode analysis, least-privilege IAM review, and monthly cost estimate.

The SAA-C03 domains are secure architectures, resilient architectures, high-performing architectures, and cost-optimized architectures. Use the [official exam guide](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03.html) as the scope source.

## Terraform Associate 004 milestone

Create a separate infrastructure repository or a clearly isolated `terraform/` root with version constraints, provider lockfile, remote encrypted state, state locking, modules, variables, outputs, validation, locals, data sources, imports, moved blocks, and plan review.

Build reusable network, security, data, application, and observability modules. Add `fmt`, `validate`, lint, security scan, and plan stages. Demonstrate create, change, import, drift detection, state recovery, and destroy in a budget-controlled lab. Terraform Associate 004 targets Terraform 1.12; track the [official study guide](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-study-004).

## CKAD milestone

Run locally on kind or k3d before paying for EKS. Add Namespace, Deployment, Service, Ingress, ConfigMap, Secret, probes, resource requests and limits, security contexts, service accounts, RBAC, NetworkPolicy, PodDisruptionBudget, persistent storage where appropriate, Jobs for migrations, and CronJobs for collection.

API and worker must scale independently. The collector schedule must use `concurrencyPolicy: Forbid`; failed pods must not receive traffic; rollout and rollback must be practiced. Add debugging exercises for scheduling, DNS, service selectors, configuration, probes, permissions, resources, and logs. Follow the current [CKAD domains](https://www.cncf.io/training/certification/ckad/).

## AWS Machine Learning Engineer Associate milestone

Use archived source data to build raw, curated, feature, training, registry, and batch-inference stages. Split train, validation, and test data by time to prevent future leakage. Begin with anomaly detection or a simple volatility baseline rather than a complex price predictor.

Implement data and model versioning, reproducible processing and training, SageMaker Pipelines, experiments, Model Registry, batch inference, feature and prediction storage, quality checks, drift monitoring, approval, deployment, and rollback. Compare every model with a transparent baseline and document that outputs are educational, not trading advice.

AWS announced MLA-C02 beta registration for 2026-09-01 and the final English MLA-C01 exam date as 2026-09-28. Confirm the active version before booking through the [official certification page](https://aws.amazon.com/certification/certified-machine-learning-engineer-associate/) and [AWS update](https://aws.amazon.com/blogs/training-and-certification/updates-to-aws-certified-machine-learning-engineer-associate-mla-c02/).

## Recommended order

1. Finish load and data-quality baseline.
2. Study SAA-C03 while designing the AWS target and threat or cost model.
3. Implement the target with Terraform while preparing for Associate 004.
4. Learn CKAD locally and then deploy the same manifests to EKS only if the cost is justified.
5. Build the ML lifecycle after raw data retention, data quality, and cloud storage are stable.

Each milestone is complete only when the environment is reproducible, failure and recovery are demonstrated, evidence is documented, and recurring cloud cost is understood.
