# aroma-pacifico-infrastructure

Terraform root stack of the Aroma Pacífico pattern environment: remote state, per-environment variables, secrets handling and plan-only CI/CD

Part of the Aroma Pacífico pilot, the 2026 update of the coffee traceability pilot for Cauca, Huila and Tolima. Work is tracked in [aroma-pacifico-roadmap](https://github.com/aroma-pacifico/aroma-pacifico-roadmap) and on the [Aroma Pacífico Pilot board](https://github.com/orgs/aroma-pacifico/projects/1).

## What lives here

This private repository holds the Terraform root stacks of the pattern environment, one per domain, together with the per-environment variable and backend files and the plan-only GitHub Actions workflows. Reusable modules are not defined here: the stacks consume them by SemVer git tag from [aroma-pacifico-terraform-modules](https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules) (ADR-003). State lives in one encrypted, versioned S3 bucket per environment with native S3 locking (`use_lockfile`), so no DynamoDB lock table exists. The design needs no stored secret: CI reaches AWS through GitHub OIDC federation, and the variable and backend files hold names only. Distributed AI agent rules and standards are synchronized here from the canonical `aroma-pacifico-ai-agents` repository and are never edited in this copy.

This repository is plan-only: nothing here may run `terraform apply` or `terraform destroy`, or create a live resource (AGENTS.md section 4).

## Repository layout

```text
aroma-pacifico-infrastructure/
|-- .github/
|   `-- workflows/          pr-conventions.yml now; CI (B11) and CD (B12) workflows are added here
|-- .terraform-version      exact Terraform patch used by local runs and CI
|-- docs/
|   |-- case/               case statement, the sole source of requirements
|   `-- diagram-boxes.md    map of diagram boxes D01 to D13 to this repository
|-- environments/
|   |-- dev/                per-environment variable and backend files (B02, B03)
|   |-- qa/
|   `-- pdn/
|-- release-notes/          filled release notes, one file per release
|-- stacks/
|   |-- state-backend/      bootstrap of the state buckets (B02, box D02)
|   |-- network/            network domain (B04, box D04)
|   |-- security/           security domain (B06, box D06)
|   `-- workload/           farm, ingestion and inference function (B08 to B10)
`-- standards/              distributed engineering standards
```

Each stack is a Terraform root module with `versions.tf`, `backend.tf`, `providers.tf` and `variables.tf`, and a committed `.terraform.lock.hcl`. The S3 backend is declared empty and is configured at `terraform init` time from the backend file of the target environment. The environments are `dev`, `qa` and `pdn`.

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Terraform | 1.15.8, pinned in `.terraform-version` | The stacks require `>= 1.14.0`; CI and local runs use the exact patch recorded here. |
| Git | Any recent release | Branches follow `<type>/<issue-number>-<slug>`; commits follow Conventional Commits. |
| GitHub CLI | Any recent release | Needed to open pull requests. |

No cloud credentials are needed for the commands below. They use `-backend=false` and run offline once the provider is downloaded.

## Base commands

Run from the repository root.

```bash
# Format check across every stack
terraform fmt -check -recursive

# Validate one stack without touching state
terraform -chdir=stacks/network init -backend=false
terraform -chdir=stacks/network validate
```

Repeat the `init` and `validate` pair for `state-backend`, `security` and `workload`. A real `terraform plan` needs the backend file of an environment and plan-only credentials, and is produced by the CI pipeline (B11), never by `apply`.

## Terraform version

CI and local runs use Terraform 1.15.8, the patch release recorded in `.terraform-version` (ADR-003 asks B01 to record one exact patch at or above the `>= 1.14.0` floor). Provider locks include hashes for Linux, macOS and Windows so that CI on Linux and local runs on other systems resolve the same provider build.

## Collection center association (B05, box D05)

`stacks/network` also composes the single collection center association: one approved center (`cauca`, `huila` or `tolima`) per run, linked to the pdn environment through the `collection-center-association` module, which is consumed by git tag from the modules repository. The root owns the approved departmental catalog, the two plan-role providers and the B07 routing outputs. See [docs/b05-final-delivery.md](docs/b05-final-delivery.md) and [stacks/network/README.md](stacks/network/README.md).

## Diagram boxes

The structure references boxes D01 to D13 of the complete architecture diagram. See [docs/diagram-boxes.md](docs/diagram-boxes.md) for the box to task to path map.

## Branch protection

The `main` branch must be protected and reached only through pull requests. Branch protection and rulesets on a private repository require a GitHub Pro or Team plan, so this setting is a manual step for the organization lead and is not configured by the code in this repository.

## Tasks delivered here

- [B01](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/21)
- [B02](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/22)
- [B03](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/23)
- [B11](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/31)
- [B12](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/32)
- [B13](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/33)
