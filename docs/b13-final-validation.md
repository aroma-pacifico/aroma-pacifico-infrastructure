# B13 final validation: end-to-end plan and D01 to D13 evidence

Refs aroma-pacifico/aroma-pacifico-roadmap#33 (box D13). Plan-only: nothing is applied and no cloud resource exists.

This document closes the Infrastructure as Code epic. It shows that the root stacks generate an executable plan end to end, that no state file or secret is committed, how each diagram box D01 to D13 maps to code, tests and plan evidence, and how to repeat the run. Two wiring tasks are still open, B07b (firewall rules in `stacks/network`) and B09b (telemetry ingestion in `stacks/workload`). They are marked PENDING below and are not hidden: the rerun checklist in section 6 says what to do when they land.

## 1. End-to-end plan

`scripts/plan-all.sh` plans the four stacks in dependency order (`state-backend`, `network`, `security`, `workload`) against the pinned Floci emulator with the qa example variables, because qa is the environment whose plan is evaluated (ASM-051). The network stack gets a second plan with the pdn example plus `stacks/network/emulator.tfvars`, because the collection center link of box D05 exists only in pdn (ASM-121). For every plan it keeps the text, the plan JSON and the add, change, destroy and replace counts, and it writes one `summary.md` and `summary.json`. The CI job `end-to-end` in `.github/workflows/floci-plan.yml` runs the same script, publishes the summary to the job summary and keeps the output as the artifact `plan-all`.

A stack whose wiring is pending is planned with what exists and reported as PENDING. The script detects pending wiring from the stack files (it looks for the module source of the missing box), so the note disappears by itself when the wiring merges. A stack that does not plan is FAILED and makes the script exit with status 1.

Result of the local run on `main` at commit `0fdbb2a` (Terraform 1.15.8, Floci 2.4.0 from the pinned digest, test credentials, Docker on a workstation):

| Stack | Variables | Status | Add | Change | Destroy | Replace |
|---|---|---|---|---|---|---|
| state-backend | qa | PLANNED | 8 | 0 | 0 | 0 |
| network | qa | PENDING (B07b) | 163 | 0 | 0 | 0 |
| network | pdn example + emulator fixtures | PENDING (B07b) | 167 | 0 | 0 | 0 |
| security | qa | PLANNED | 31 | 0 | 0 | 0 |
| workload | qa | PENDING (B09b) | 44 | 0 | 0 | 0 |

The qa total is 246 resources to add, with 0 changes, 0 destroys and 0 replacements, which is expected for a plan against an empty emulator. The Monthly cost column of the summary reads "estimate unavailable" in the local run because no Infracost token exists on a workstation. In CI the same step uses the checksum-pinned Infracost CLI when `INFRACOST_CLI_TOKEN`, `INFRACOST_ORG` and `INFRACOST_METADATA_EGRESS_APPROVED` are configured, and otherwise prints the same sentence. No cost figure is claimed here, and the one published by the `Infracost cost impact` workflow stays the cost evidence of record (PC-IAC-027).

## 2. Secret and state validation

`scripts/validate-no-secrets.sh` runs three checks, and the CI job runs it after the plan with a full-history checkout and a checksum-pinned gitleaks 8.30.1.

| Check | Scope | Result of the run |
|---|---|---|
| Forbidden file names | Every path in every ref of the history: state files, plan files, `.envrc`, keys, credential CSV files, real `.tfvars` and `.tfbackend` files | SUCCESS: none. The one allowed exception is `stacks/network/emulator.tfvars`, synthetic Floci fixtures with the all-zero account. |
| gitleaks over history | All refs, 106 commits scanned | SUCCESS: no leaks found. |
| gitleaks over plan output | The plan text and plan JSON of the run above | SUCCESS: no leaks found. |

`scripts/check-env-secrets.sh` keeps scanning the variable, backend and example files on every pull request. The state of the stacks lives only in the remote S3 backend (PC-IAC-008); `.gitignore` excludes `*.tfstate`, `*.tfplan`, `*.plan.json` and the output directory `plan-all-output/`, and the check above confirms that no such file ever entered the history. The plan JSON is a short-lived artifact (three days) and is never committed.

## 3. Evidence D01 to D13

The module column gives the module and the git tag that the stack consumes (PC-IAC-015). The plan count is the number of managed resources the module adds in the qa plan of section 1, except where noted. The PR column lists merged pull requests of this repository (`I#`) and of `aroma-pacifico-terraform-modules` (`M#`). Counts of tests are the `terraform test` runs of the stack.

| Box | Task | Module and tag | Stack and file | Test | Plan resources | Merged PR | Status |
|---|---|---|---|---|---|---|---|
| D01 | B01 | none (repository layout) | `stacks/`, `environments/`, `.github/` | not applicable | not applicable | I#5 | DONE |
| D02 | B02 | `state-backend` v0.3.0 | `stacks/state-backend/main.tf` | `tests/state_backend_unit_test.tftest.hcl`, 3 passed | 8 | M#4, I#3 | DONE |
| D03 | B03 | none (variables) | `environments/<env>/*.tfvars.example`, `stacks/*/backends/*.example` | `scripts/check-env-secrets.sh` in CI | not applicable | I#6, I#16 | DONE |
| D04 | B04 | `network` v0.3.0 | `stacks/network/main.tf` | `tests/network.tftest.hcl`, 5 of 16 passed | 163 | M#6 to M#11, I#13 | DONE |
| D05 | B05 | `collection-center-association` v0.4.0 | `stacks/network/main.tf` (module `association`) | `tests/association.tftest.hcl`, 11 of 16 passed | 4 (pdn plan with fixtures) | M#21, I#4 | DONE |
| D06 | B06 | `security` v0.5.0 | `stacks/security/main.tf` | `tests/security.tftest.hcl`, 8 passed | 31 | M#12, M#25, I#22 | DONE |
| D07 | B07 | `firewall-rules` v0.3.0 (module merged) | not wired yet (`stacks/network` and `stacks/security`) | module tests in the modules repository | 0 in the stacks | M#20 | PENDING B07b |
| D08 | B08 | `farm` v0.4.0 | `stacks/workload/farm.tf` | `tests/farm.tftest.hcl`, 4 of the 8 workload runs passed | 8 | M#3, I#21 | DONE |
| D09 | B09 | `telemetry-ingestion` v0.4.0 (module merged) | not wired yet (`stacks/workload`, file `telemetry_ingestion.tf`) | module tests in the modules repository | 0 in the stacks | M#22 to M#24 | PENDING B09b |
| D10 | B10 | `inference-functions` v0.4.0 | `stacks/workload/inference_functions.tf` | `tests/inference_functions.tftest.hcl`, 4 of the 8 workload runs passed | 36 | M#14, I#20 | DONE |
| D11 | B11 | none (CI) | `.github/workflows/infrastructure-ci.yml`, `floci-plan.yml`, `infracost.yml`, `pr-conventions.yml` | the workflows run on every pull request | the plan job of section 1 | I#9 to I#12 | DONE |
| D12 | B12 | none (CD) | `.github/workflows/cd-promotion.yml`, `cd-plan.yml`, `docs/cd-pipeline.md` | not applicable (plan-only approval gate) | not applicable | I#14, I#19, I#23, I#24 | DONE |
| D13 | B13 | none (validation) | `scripts/plan-all.sh`, `scripts/validate-no-secrets.sh`, this document | the `end-to-end` job | 246 (qa total) | this pull request | PARTIAL until B07b and B09b are rerun (section 6) |

The workload row of the plan table (44) is the sum of D08 (8 resources) and D10 (36 resources). The network qa count (163) is all D04; D07 adds its resources to this stack once B07b lands. The roadmap issues of D07 and D09 (B07 and B09) stay open until their wiring merges, which is consistent with the PENDING status.

## 4. Implemented scope

The repository holds the four root stacks of the pattern environment, each with a partial S3 backend, provider configuration, governance tags through `default_tags` and per-environment example variables for dev, qa and pdn. The stacks consume eight reference modules by git tag, of which six are wired today (state backend, network, collection center association, security, farm and inference functions) and two are merged in the modules repository but not wired yet (firewall rules and telemetry ingestion). The pipelines cover pull request gates (format, validate, tflint, Trivy, `terraform test`, secret scan), a Floci plan of every stack, an Infracost estimate, an end-to-end plan with the secret validation of this task, and a CD promotion pipeline across dev, qa and pdn with a two-step production approval that approves a reviewed plan.

## 5. Exclusions

| Exclusion | Reason |
|---|---|
| No `terraform apply` or `terraform destroy`, anywhere | The project stops at `terraform plan` as confirmed by the faculty advisor (AGENTS.md sections 1 and 4). The production approval approves a plan, it does not apply it (`docs/cd-pipeline.md`). |
| A single pattern environment, not a fleet | The pilot defines one pattern environment with the dev, qa and pdn variable sets, and one collection center per run (B05). Three centers and Buenaventura infrastructure are out of scope. |
| No hardware | The ground station, the edge devices and the sensors are outside Terraform. The code covers cloud resources only. |
| Floci rather than real AWS | The faculty advisor accepted the emulator as the plan target in lieu of an AWS account (PC-IAC-028). A plan against the emulator proves the graph and the provider schema; it does not prove IAM policy outcomes, service quotas or regional availability in a real account. |
| No saved qa account plan | The reviewed plan against a real account waits for an account and PD-019. |
| No cost claim without a token | Infracost figures are published only when the token and the egress approval exist, and the text says "estimate unavailable" otherwise. |

## 6. Rerun checklist for B07b and B09b

When the wiring of the firewall rules (B07b, `stacks/network`) and of telemetry ingestion (B09b, `stacks/workload/telemetry_ingestion.tf`) is merged: run `scripts/plan-all.sh` again and confirm that the PENDING notes are gone and that the network and workload statuses read PLANNED, update the D07 and D09 rows of section 3 with the module tag, the stack file, the test, the plan count and the merged pull request, run `scripts/validate-no-secrets.sh plan-all-output` again, and then tick the four acceptance criteria of roadmap issue 33. Nothing in this document is to be edited to claim a result that the run does not show.

## 7. How to run it

### Locally with Docker

Requirements: Docker, Terraform at the version in `.terraform-version`, the AWS CLI, `jq`, and gitleaks for the secret validation.

```bash
docker run -d --rm --name floci -p 4566:4566 \
  floci/floci@sha256:5ee85db604c4aa74ac76e07ea5cc83086f37bb472bf3dbb97e34019e48efae9c
export AWS_ENDPOINT_URL=http://localhost:4566 AWS_ACCESS_KEY_ID=test \
  AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1
bash scripts/plan-all.sh                       # writes plan-all-output/summary.md
bash scripts/validate-no-secrets.sh plan-all-output
docker stop floci
```

The first run downloads the providers and the modules by git tag, and a full run takes about three minutes on a workstation. `--env dev|qa|pdn` selects another example variable file. Never expose a Floci instance from a personal machine; the container has no authentication.

### In CI

The `end-to-end` job of `Floci plan` starts on every pull request to `main`, on every push to `main` and on manual dispatch. It starts the pinned Floci image as a service container, plans the stacks through `scripts/plan-all.sh`, writes the table of section 1 to the job summary, runs `scripts/validate-no-secrets.sh` over the full history and the plan JSON, and uploads the `plan-all` artifact. Setting the secret `INFRACOST_CLI_TOKEN` and the variables `INFRACOST_ORG` and `INFRACOST_METADATA_EGRESS_APPROVED=true` turns the cost column on.
