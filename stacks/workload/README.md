# Workload stack (boxes D08 to D10, B08b to B10b)

Root stack of the workload domain: the inference functions (box D10), the farms (box D08) and the telemetry ingestion (box D09). It wires reference modules of [aroma-pacifico-terraform-modules](https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules), each pinned by SemVer tag (PC-IAC-015). The stack defines no resource of its own. Each component has its own file with one module call, so the three components can be wired in parallel without touching each other's file; `locals.tf` injects the governance values and `variables.tf` takes the per-environment values from `environments/<env>/<env>.tfvars.example`.

```text
stacks/workload/
|-- backend.tf, providers.tf, versions.tf   B01 scaffold (partial S3 backend, provider, pins)
|-- variables.tf                            governance variables plus the component inputs
|-- locals.tf                               governance tags, name prefix, function definitions
|-- inference_functions.tf                  modules/inference-functions call (B10b, box D10)
|-- outputs.tf                              outputs consumed by other stacks and modules
|-- tests/inference_functions.tftest.hcl    offline plan-mode tests
`-- .terraform.lock.hcl                     scoped provider lock (PC-IAC-006)
```

The telemetry ingestion (B09b) goes in its own `telemetry_ingestion.tf`, as described in [Wiring telemetry ingestion (B09b)](#wiring-telemetry-ingestion-b09b).

## Inference functions (B10b, box D10)

`inference_functions.tf` calls `modules/inference-functions` at `v0.4.0`, the latest tag that contains it. `locals.tf` defines the four functions of the design: the confirmation (`confrm`), verification (`verify`) and estimation (`estim`) drone functions, which share one shape and the module defaults of ASM-281, and the telemetry threshold function (`thresh`) with its own sizing (ASM-162). Each function gets its queue, dead-letter queue, event source mapping, role and log group from the module.

## Inputs

| Variable | Type | Source | Meaning |
|---|---|---|---|
| `aws_region`, `environment`, `common_tags` | `string`, `string`, `map(string)` | tfvars | Governance inputs shared by every stack. `Client` and `Project` feed the names, so they must be lowercase alphanumeric. |
| `inference_model_id` | `string` | tfvars | Foundation model of every function: Amazon Nova Pro in `us-east-1` (ASM-160, ASM-179). |
| `inference_function_packages` | `map(object)` | tfvars or pipeline | Package path and optional digest per function. The examples hold placeholder paths (ASM-421); `terraform plan` does not read the file. |
| `kms_key_arns` | `map(string)` | `stacks/security` (B06b) | The `kms_key_arns` output of the security stack. The functions use the `telemetry`, `objects`, `records` and `logs` classes. |
| `permissions_boundary_arn` | `string` | `stacks/security` (B06b) | Optional boundary of every function role; null attaches none. |
| `inference_targets` | `object` | tfvars | Alert table and topic, drone event rule pattern, drone object pattern, mission table and threshold table. No stack creates them yet, so the examples hold fixtures (ASM-420). |
| `telemetry_references` | `object` | B09b | Telemetry table and topic rule of the telemetry ingestion. Temporary: B09b replaces it with module outputs. |

Cross-stack values arrive as input variables with fixture values in the examples (ASM-420). The fixtures use the all-zero emulator account, so the plan works against Floci with empty state.

## Outputs

Only the outputs that other stacks and modules need are exposed (PC-IAC-019 section 3.2).

| Output | Consumed by | Use |
|---|---|---|
| `threshold_queue_url` | B09b | `threshold_queue_url` input of `modules/telemetry-ingestion`: the topic rule sends each reading there (ASM-161). |
| `queue_urls` | B09b, replay tooling | Trigger queue URL of each function. |
| `queue_arns` | B06b | Send permission of the telemetry rule role on the threshold queue. |
| `key_user_arns` | B06b | `key_user_arns` input of the security module, so the key policies name the function roles. |
| `inference_function_names`, `dead_letter_queue_names` | observability | Function and dead-letter queue alarms. |

## Wiring telemetry ingestion (B09b)

B09b adds `telemetry_ingestion.tf` with one call to `modules/telemetry-ingestion` (pinned to `v0.4.0` or later) and touches the shared files only as listed here.

| Module input of `telemetry-ingestion` | Value to pass |
|---|---|
| `threshold_queue_url` | `module.inference_functions.queue_urls["thresh"]` (the same value as the `threshold_queue_url` output). |
| `kms_key_arns` | `var.kms_key_arns`, already declared; it must also contain the `telemetry` and `logs` classes, which the examples do. |
| `client`, `project`, `environment`, `name_prefix`, `additional_tags` | `local.client`, `local.project`, `var.environment`, `local.name_prefix`, `local.common_tags`. |
| `log_retention_days` | `local.log_retention_days`. |
| `providers` | `{ aws.project = aws }`. |
| `rule_role_arn`, `tls_security_policy` and the other inputs | New variables, alphabetical in the B09b block of `variables.tf`, with fixture values in the three tfvars examples. `rule_role_arn` comes from `stacks/security`. |

In the opposite direction, the threshold function needs two values from the ingestion module. Today they come from `var.telemetry_references`. B09b changes two lines of `locals.tf`:

```hcl
telemetry_table_arn = module.telemetry_ingestion.telemetry_table_arn
telemetry_rule_arn  = module.telemetry_ingestion.topic_rule_arn
```

and then deletes the `telemetry_references` variable and its block in the three tfvars examples and in `tests/inference_functions.tftest.hcl`. There is no dependency cycle: `topic_rule_arn` is built from the rule name, and the telemetry table does not depend on the queue. B09b adds its own outputs to `outputs.tf` and its own `tests/telemetry_ingestion.tftest.hcl`.

## Plan it against Floci

Credential-free plan per PC-IAC-028 (pinned image digest of AGENTS.md section 8). The stack declares an S3 backend, so the plan needs a state bucket inside the emulator. Run from the repository root; replace `qa` with `dev` or `pdn` as needed.

```bash
docker run -d --rm --name floci -p 4566:4566 \
  floci/floci@sha256:5ee85db604c4aa74ac76e07ea5cc83086f37bb472bf3dbb97e34019e48efae9c
export AWS_ENDPOINT_URL=http://localhost:4566 AWS_ACCESS_KEY_ID=test \
  AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1
aws s3 mb s3://floci-plan-state
terraform -chdir=stacks/workload init -input=false \
  -backend-config="bucket=floci-plan-state" -backend-config="key=workload/terraform.tfstate" \
  -backend-config="region=us-east-1" -backend-config="use_path_style=true" \
  -backend-config="skip_credentials_validation=true" \
  -backend-config="skip_requesting_account_id=true" -backend-config="skip_metadata_api_check=true"
terraform -chdir=stacks/workload plan -lock=false \
  -var-file=../../environments/qa/qa.tfvars.example
```

Each environment plans 36 resources to add, 0 to change and 0 to destroy: nine per function. Nothing is applied: `terraform apply` and `terraform destroy` are never run.
