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
|   `-- workflows/          pr conventions, CI gates, Floci plan and Infracost; the CD workflow (B12) is added here
|-- .terraform-version      exact Terraform patch used by local runs and CI
|-- docs/
|   |-- case/               case statement, the sole source of requirements
|   `-- diagram-boxes.md    map of diagram boxes D01 to D13 to this repository
|-- environments/
|   |-- dev/                per-environment variable examples (B03)
|   |-- qa/
|   `-- pdn/
|-- release-notes/          filled release notes, one file per release
|-- stacks/
|   |-- state-backend/      state bucket and key per environment, backend examples (B02, box D02)
|   |-- network/            network domain (B04, box D04)
|   |-- security/           security domain (B06, box D06)
|   `-- workload/           farm, ingestion and inference function (B08 to B10)
`-- standards/              distributed engineering standards
```

Each stack is a Terraform root module with `versions.tf`, `backend.tf`, `providers.tf` and `variables.tf`, and a committed `.terraform.lock.hcl`. The S3 backend is declared empty and is configured at `terraform init` time from the backend file of the target environment. The environments are `dev`, `qa` and `pdn`.

## Remote state and plans: what each person needs

This project is plan-only, so the state is always empty and there is no shared state. Nobody needs a running backend, a bucket, an AWS account or a local Floci to work here.

The remote state backend is code. Every stack declares `backend "s3" {}` with partial configuration, and `stacks/<stack>/backends/<env>.s3.tfbackend.example` holds example values for `dev`, `qa` and `pdn`: separate state key per domain, encryption with the environment key and native S3 locking (`use_lockfile = true`). The real `.tfbackend` files are git-ignored, so no bucket name or account identifier is committed. `stacks/state-backend` creates the bucket and key of each environment by consuming the `state-backend` module at the git tag `v0.3.0` (PC-IAC-015); it reads the account from the caller identity at plan time. Validate the backend code without any backend:

```bash
terraform -chdir=stacks/state-backend init -backend=false
terraform -chdir=stacks/state-backend validate
terraform -chdir=stacks/state-backend test
```

`terraform plan` runs in CI against an ephemeral Floci container (PC-IAC-028) that the workflow starts inside each run and discards afterwards. Today `.github/workflows/floci-plan.yml` does this for the four stacks with the `qa` example variables; the full plan pipeline (the saved plan and review summary) belongs to [B11](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/31), which is still open. The `aroma-pacifico-terraform-modules` CI already plans its samples against Floci.

Running Floci locally is optional and only previews a plan before pushing. From the repository root:

```bash
docker run -d --rm --name floci -p 4566:4566 floci/floci@sha256:5ee85db604c4aa74ac76e07ea5cc83086f37bb472bf3dbb97e34019e48efae9c
export AWS_ENDPOINT_URL=http://localhost:4566 AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1
terraform -chdir=stacks/state-backend init -backend=false && terraform -chdir=stacks/state-backend plan -lock=false -var-file=../../environments/qa/qa.tfvars.example
```

Never expose a Floci instance from a personal machine to the team or to CI: it has no authentication, and a disposable container per run gives the same plan. Stop the local one with `docker stop floci`.

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

## CI pipeline

The continuous integration pipeline validates and exercises every root stack on every pull request targeting `main` and on pushes to `main` (trunk-based development, PC-IAC-027, PC-IAC-028).

The pipeline comprises two automated workflows:

1. **Infrastructure CI** (`.github/workflows/infrastructure-ci.yml`):
   - **Secret scan**: inspects all variable, backend, and environment example files with `scripts/check-env-secrets.sh` to ensure no credentials, tokens, or account numbers are committed.
   - **Validation gates**: runs `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`, `tflint` against the AWS ruleset, Trivy security configuration scan, and `terraform test` (where tests exist) across all root stacks in `stacks/*`.
   - **Speculative plan against Floci**: executes a speculative `terraform plan -out` across each root stack using the pinned Floci AWS emulator (`floci/floci@sha256:5ee85db604c4aa74ac76e07ea5cc83086f37bb472bf3dbb97e34019e48efae9c`). Exercises remote state initialization against an emulator S3 state bucket with `use_path_style = true` and native S3 state locking (`use_lockfile = true`), publishes the plan outcome to the GitHub Actions job summary, and preserves the plan artifact for review. Operates with zero cloud credentials and strict plan-only discipline (`terraform apply` and `terraform destroy` are strictly forbidden).
2. **Infracost cost impact** (`.github/workflows/infracost.yml`):
   - Calculates baseline, proposed, and monthly cost delta across each root stack using Infracost CLI v2 with the non-sensitive QA example variables (`environments/qa/qa.tfvars.example`).
   - Requires zero cloud credentials, authenticating solely with the organization token secret `INFRACOST_CLI_TOKEN` and repository variables `INFRACOST_ORG` and `INFRACOST_METADATA_EGRESS_APPROVED`.
   - Degrades gracefully to report "estimate unavailable" when credentials or egress approval are absent, without claiming false zero-cost figures.

## Terraform version

CI and local runs use Terraform 1.15.8, the patch release recorded in `.terraform-version` (ADR-003 asks B01 to record one exact patch at or above the `>= 1.14.0` floor). Provider locks include hashes for Linux, macOS and Windows so that CI on Linux and local runs on other systems resolve the same provider build.

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
