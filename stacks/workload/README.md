# Workload stack (boxes D08 to D10, B08b to B10b)

Root stack of the workload domain: the inference functions (box D10), the farms (box D08) and the telemetry ingestion (box D09). It wires reference modules of [aroma-pacifico-terraform-modules](https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules), each pinned by SemVer tag (PC-IAC-015). The stack defines no resource of its own. Each component has its own file with one module call, so the three components can be wired in parallel without touching each other's file; `locals.tf` injects the governance values and `variables.tf` takes the per-environment values from `environments/<env>/<env>.tfvars.example`.

```text
stacks/workload/
|-- backend.tf, providers.tf, versions.tf   B01 scaffold (partial S3 backend, provider, pins)
|-- variables.tf                            governance variables plus the component inputs
|-- locals.tf                               governance tags, name prefix, function definitions
|-- inference_functions.tf                  modules/inference-functions call (B10b, box D10)
|-- farm.tf                                 modules/farm call, one per enrolled farm (B08b, box D08)
|-- telemetry_ingestion.tf                  modules/telemetry-ingestion call (B09b, box D09)
|-- outputs.tf                              outputs consumed by other stacks and modules
|-- tests/                                  offline plan-mode tests, one file per component
|-- fixtures/                               synthetic public CSRs of the example farm
`-- .terraform.lock.hcl                     scoped provider lock (PC-IAC-006)
```

The three calls reference each other only through `locals.tf`, as described in [Telemetry ingestion (B09b, box D09)](#telemetry-ingestion-b09b-box-d09).

## Inference functions (B10b, box D10)

`inference_functions.tf` calls `modules/inference-functions` at `v0.4.0`, the latest tag that contains it. `locals.tf` defines the four functions of the design: the confirmation (`confrm`), verification (`verify`) and estimation (`estim`) drone functions, which share one shape and the module defaults of ASM-281, and the telemetry threshold function (`thresh`) with its own sizing (ASM-162). Each function gets its queue, dead-letter queue, event source mapping, role and log group from the module.

## Farms (B08b, box D08)

`farm.tf` calls `modules/farm` at `v0.4.0` once per entry of `farms`. Each farm gets the IoT thing and certificate of its crop and drying nodes, and attaches the device policy of the ingestion contract to both certificates. The node names are `<client>-<project>-<environment>-<farm key>-crop` and `-drying`; the farm key has at most 4 characters so that the prefix stays within the 21 characters the module accepts. The certificates are created from public CSRs read from files; private keys never leave the devices. The examples enroll one synthetic farm with the CSRs of `fixtures/` (ASM-422).

## Inputs

| Variable | Type | Source | Meaning |
|---|---|---|---|
| `aws_region`, `environment`, `common_tags` | `string`, `string`, `map(string)` | tfvars | Governance inputs shared by every stack. `Client` and `Project` feed the names, so they must be lowercase alphanumeric. |
| `inference_model_id` | `string` | tfvars | Foundation model of every function: Amazon Nova Pro in `us-east-1` (ASM-160, ASM-179). |
| `inference_function_packages` | `map(object)` | tfvars or pipeline | Package path and optional digest per function. The examples hold placeholder paths (ASM-421); `terraform plan` does not read the file. |
| `kms_key_arns` | `map(string)` | `stacks/security` (B06b) | The `kms_key_arns` output of the security stack. The functions use the `telemetry`, `objects`, `records` and `logs` classes; the ingestion module takes `telemetry` and `logs`. |
| `permissions_boundary_arn` | `string` | `stacks/security` (B06b) | Optional boundary of every function role; null attaches none. |
| `inference_targets` | `object` | tfvars | Alert table and topic, drone event rule pattern, drone object pattern, mission table and threshold table. No stack creates them yet, so the examples hold fixtures (ASM-420). |
| `farms` | `map(object)` | tfvars or provisioning | Enrolled farms: opaque farm identifier and the crop and drying CSR paths. One synthetic farm in the examples (ASM-422). |
| `iot_rule_role_arn`, `iot_logging_role_arn` | `string` | `stacks/security` (B06b) | The `iot_rule_role_arn` and `iot_logging_role_arn` outputs of the security stack: the role the topic rule assumes and the role IoT Core uses to write its logs. Fixtures in the examples. |
| `telemetry_topic_namespace` | `string` | tfvars | Topic levels above the thing name; a node publishes only to `<namespace>/<thing name>`. No default: the design does not fix the scheme. The examples hold the synthetic `fixture/<env>/telemetry`. |
| `telemetry_tls_security_policy` | `string` | tfvars | Predefined IoT Core security policy with a TLS 1.2 minimum. No default: PD-100 is open and the design names a policy only as an example. The examples hold `IoTSecurityPolicy_TLS13_1_2_2022_10`. |

Cross-stack values arrive as input variables with fixture values in the examples (ASM-420). The fixtures use the all-zero emulator account, so the plan works against Floci with empty state.

## Outputs

Only the outputs that other stacks and modules need are exposed (PC-IAC-019 section 3.2).

| Output | Consumed by | Use |
|---|---|---|
| `threshold_queue_url` | `telemetry_ingestion.tf` | Same value as the `queue_urls` entry of `thresh` that the module receives: the topic rule sends each reading there (ASM-161). |
| `queue_urls` | replay tooling | Trigger queue URL of each function. |
| `queue_arns` | B06b | Send permission of the telemetry rule role on the threshold queue. |
| `key_user_arns` | B06b | `key_user_arns` input of the security module, so the key policies name the function roles. |
| `inference_function_names`, `dead_letter_queue_names` | observability | Function and dead-letter queue alarms. |
| `farm_node_names`, `farm_telemetry_topics` | node provisioning | MQTT client identifier and publish topic of each node. |
| `farm_certificate_arns` | revocation | Certificate of each node, for revocation; no key material. |
| `telemetry_table_arn`, `telemetry_table_name` | summaries, dashboards | Telemetry table of the ingestion module. |
| `topic_rule_arn`, `topic_rule_name` | security, observability | The only sender allowed on the threshold queue; rule metrics. |
| `error_queue_arn`, `error_queue_name` | replay tooling, observability | Rule error queue, for the replay of failed readings and the alarm on its first message. |
| `domain_configuration_name` | audit | IoT Core domain configuration that carries the TLS policy (rows CL-TEL-01 and CL-TEL-02). |
| `iot_endpoint` | node provisioning | Data endpoint hostname the nodes connect to. |
| `iot_log_group_name` | observability | `AWSIotLogsV2` log group, for the filters on its ERROR entries. |

## Telemetry ingestion (B09b, box D09)

`telemetry_ingestion.tf` calls `modules/telemetry-ingestion` at `v0.4.0`, the tag of its neighbours (the module is identical in `v0.5.0`). It creates the IoT Core data endpoint with its TLS policy, the device policy, the topic rule, the telemetry table, the rule error queue and the IoT Core log group.

| Module input | Value |
|---|---|
| `client`, `project`, `environment`, `name_prefix`, `additional_tags` | `local.client`, `local.project`, `var.environment`, `local.name_prefix`, `local.common_tags`. |
| `kms_key_arns` | `var.kms_key_arns` (classes `telemetry` and `logs`). |
| `rule_role_arn`, `logging_role_arn` | `var.iot_rule_role_arn`, `var.iot_logging_role_arn`, the outputs of `stacks/security`. |
| `threshold_queue_url` | `module.inference_functions.queue_urls["thresh"]`. |
| `topic_namespace`, `tls_security_policy` | `var.telemetry_topic_namespace`, `var.telemetry_tls_security_policy`: inputs without default. |
| `retention_days` | `5 * 365 + 1` days (`local.telemetry_retention_days`): the case statement keeps readings 5 years, the module counts from the receive time (ASM-311), and the extra day covers a leap day. |
| `log_retention_days` | `local.log_retention_days` (365 days, observability design). |
| `providers` | `{ aws.project = aws }`. |

In the opposite direction `locals.tf` reads three module outputs: `telemetry_table_arn` and `topic_rule_arn` feed the threshold function (read permission and queue sender `iot.amazonaws.com`), and `ingestion` is the contract of every farm. The module builds `topic_rule_arn` from the rule name and the telemetry table does not depend on the queue, so the two calls form no cycle (`terraform validate` passes). The placeholder variables `telemetry_references` and `farm_ingestion` of B10b and B08b no longer exist.

### What the security stack must provide

The names of the table, the queues and the rule are the ones the security module scopes its two IoT roles to (`<prefix>-ddb-tel`, `<prefix>-iot-dlq`, `<prefix>-sqs-thresh`, `<prefix>_iot_rul`). `modules/security` at `v0.5.0` adds the rule role to the `telemetry` and `records` key users by itself, so `key_user_role_names` must not repeat it; the logging role needs no key grant because the `logs` key admits the log service.

### Exceptions to the binding rules

| Rule | Exception | Reason |
|---|---|---|
| PC-IAC-003 | The topic rule is `clnt_proj_<env>_iot_rul` and the log group is `AWSIotLogsV2`. | Inherited from the module: IoT rule names allow no hyphen and IoT Core writes to a log group of that fixed name. |

### Open points

The topic namespace and the TLS policy name are inputs with synthetic fixtures until the decision log fixes them (PD-100). A plan-mode test reads only the outputs of a module call, so the role pass-through into the topic rule and the logging options is shown by the plan JSON of the pull request, not by an assertion.

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

Each environment plans 52 resources to add, 0 to change and 0 to destroy: nine per inference function, eight for the example farm and eight for the telemetry ingestion. Nothing is applied: `terraform apply` and `terraform destroy` are never run.
