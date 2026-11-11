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
|   `-- workflows/          pr conventions, CI gates, Floci plan and Infracost; CD (B12) cd-promotion.yml and cd-plan.yml
|-- .terraform-version      exact Terraform patch used by local runs and CI
|-- docs/
|   |-- case/               case statement, the sole source of requirements
|   |-- b13-final-validation.md  end-to-end plan, secret validation and D01 to D13 evidence (B13)
|   |-- cd-pipeline.md      CD promotion runbook: approval, evidence, notice, rollback (B12)
|   `-- diagram-boxes.md    map of diagram boxes D01 to D13 to this repository
|-- environments/
|   |-- dev/                per-environment variable examples (B03)
|   |-- qa/
|   `-- pdn/
|-- release-notes/          filled release notes, one file per release
|-- stacks/
|   |-- state-backend/      state bucket and key per environment, backend examples (B02, box D02)
|   |-- network/            network domain (B04, box D04)
|   |-- security/           security domain: keys, pools, firewall rules (B06, B07, boxes D06, D07)
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

The continuous integration pipeline validates and exercises every root stack on every pull request targeting `main` and on pushes to `main` (trunk-based development, PC-IAC-027, PC-IAC-028). It is split into three workflows that run in parallel, none of which uses real cloud credentials or runs `terraform apply` or `terraform destroy`.

`Infrastructure CI` (`.github/workflows/infrastructure-ci.yml`) scans variable, backend and example files for secrets with `scripts/check-env-secrets.sh`, then runs, for each stack in `stacks/*`, `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`, `tflint` with the AWS ruleset, a Trivy configuration scan and `terraform test` where a `tests` directory exists.

`Floci plan` (`.github/workflows/floci-plan.yml`) runs a speculative `terraform plan` of each root stack against the Floci AWS emulator, pinned by image digest. It creates a throwaway state bucket in the emulator, initializes the S3 backend with path style, plans with the qa example variables, writes the plan summary to the job summary and keeps the plan text as a three-day artifact. The emulator uses the fixed test keys of PC-IAC-028, never real credentials.

`Infracost cost impact` (`.github/workflows/infracost.yml`) estimates the monthly cost before, after and as a delta for each root stack with Infracost CLI v2 and the non-sensitive qa example variables. It authenticates only with the organization token secret `INFRACOST_CLI_TOKEN` and the repository variables `INFRACOST_ORG` and `INFRACOST_METADATA_EGRESS_APPROVED`, and it reports "estimate unavailable" when they are missing instead of claiming a zero cost.

The job `end-to-end` of `Floci plan` runs `scripts/plan-all.sh`, which plans the four stacks in dependency order and writes one summary and one artifact, then `scripts/validate-no-secrets.sh`, which checks the full history and the plan JSON with a pinned gitleaks. See [docs/b13-final-validation.md](docs/b13-final-validation.md).

Promotion across environments is a separate pipeline, `CD promotion` (`.github/workflows/cd-promotion.yml`).

## Terraform version

CI and local runs use Terraform 1.15.8, the patch release recorded in `.terraform-version` (ADR-003 asks B01 to record one exact patch at or above the `>= 1.14.0` floor). Provider locks include hashes for Linux, macOS and Windows so that CI on Linux and local runs on other systems resolve the same provider build.

## Collection center association (B05, box D05)

`stacks/network` can also compose one collection center association (`cauca`, `huila` or `tolima`) for the pdn environment through the `collection-center-association` module, consumed by git tag. See [docs/b05-final-delivery.md](docs/b05-final-delivery.md) and [stacks/network/README.md](stacks/network/README.md).

## CD promotion

Promotion `dev`, `qa`, `pdn` with a two-step production approval (a requester dispatches the review run, a different approver listed in the variable `PDN_APPROVERS` dispatches the approval run against the plan digest), the plan and Infracost cost delta shown to the approver, and the evidence of who requested and approved is described in [docs/cd-pipeline.md](docs/cd-pipeline.md). The pipeline is plan-only: the approval gate approves a reviewed plan and nothing is applied. On the GitHub Free plan the gate is verifiable evidence, not a technical barrier (section 1 of the runbook).

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
