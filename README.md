# Aroma Pacifico infrastructure

This private repository contains thin roots and non-secret environment configuration. Reusable resources belong in [modules](https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules). Canonical governance is synchronized from ai-agents and never edited here.

Reviewed main now includes B01's four roots and provider locks, B03's dev/qa/pdn examples and environment-secret checker. This branch completes its assigned plan-only composition. The complete state bootstrap template is staged by `scripts/verify-bootstrap.py`. One mocked invocation plans eight S3/KMS resources and four domain outputs. Twelve backend examples cover dev/qa/pdn and network/security/workload/state-backend. The first-bucket fixture excludes S3; the future steady-state backend is separate. Routing preflight requires distinct environment checkouts and never changes the shared launcher.

```text
stacks/
|-- state-backend/   B02 bootstrap and future shared backend domain
|-- network/         B04/B05 composition boundary
|-- security/        B06 domain scaffold
`-- workload/        B08-B10 domain scaffold
environments/        dev, qa, pdn B03 examples
docs/                case, diagram mapping and story evidence
scripts/             scoped offline verification and environment secret checker
release-notes/       delivery documentation
standards/           synchronized governance
```

Terraform 1.15.8 is pinned in `.terraform-version`; core floor is 1.14.0. B01 root locks select AWS 6.72.0. Complete local story fixtures pin AWS 6.0.0. Both meet the reusable module minimum; their separate locks are preserved.

```text
terraform fmt -check -recursive
terraform -chdir=stacks/network init -backend=false -input=false
terraform -chdir=stacks/network validate
```

Run through the approved launcher in isolated validation context without AWS credentials. Empty scaffold validation is not resource-plan evidence; use the complete story verifier. All resource evidence is **OFFLINE MOCKED TERRAFORM PLAN**. Shared work is represented by partial encrypted S3 backends with native lockfiles; none is initialized. Local sources are confined to disposable fixtures. Shared consumption awaits genuine reviewed releases and owner inputs.

No account plan, deployment, state mutation, migration, unlock or merge is performed. See [final evidence](docs/b02-final-delivery.md), [diagram boxes](docs/diagram-boxes.md), [AGENTS.md](AGENTS.md), [Contributing](CONTRIBUTING.md) and [standards](standards/terraform-iac-best-practices.md). Main protection and acceptance remain lead/reviewer actions.
