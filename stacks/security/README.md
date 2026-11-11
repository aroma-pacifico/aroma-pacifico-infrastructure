# Security stack (box D06, B06b)

Root stack of the security domain. It wires the reference module `modules/security` of [aroma-pacifico-terraform-modules](https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules), pinned by tag `v0.5.0` (PC-IAC-015), into the eight customer-managed keys, the two Cognito user pools with their seven groups, the role of the revocation function and, on request, the secure transport bucket policy. The stack defines no resource of its own: `main.tf` is a single module call, `locals.tf` injects the governance values and turns role names into ARNs, and `variables.tf` takes the per-environment values from `environments/<env>/<env>.tfvars.example`.

```text
stacks/security/
|-- backend.tf, providers.tf, versions.tf   B01 scaffold (partial S3 backend, provider, pins)
|-- variables.tf                            governance variables plus the security inputs
|-- data.tf                                 caller identity, so no account identifier is stored
|-- locals.tf                               governance tags, name prefix, role names to ARNs
|-- main.tf                                 the module call
|-- outputs.tf                              outputs consumed by later stacks
|-- tests/security.tftest.hcl               offline plan-mode tests
`-- .terraform.lock.hcl                     scoped provider lock (PC-IAC-006)
```

## Inputs

| Variable | Type | Source | Meaning |
|---|---|---|---|
| `aws_region`, `environment`, `common_tags` | `string`, `string`, `map(string)` | tfvars | Governance inputs shared by every stack. `Client` and `Project` feed the names, so they must be lowercase alphanumeric. |
| `security_apply_role_names` | `list(string)` | tfvars | Roles that apply this stack. They administer every key and cannot use it (ASM-270), so the list must include the security apply role. |
| `break_glass_role_patterns` | `list(string)` | tfvars | Same value as the state-backend stack. The only principals allowed to schedule key deletion or disable a key. |
| `key_user_role_names` | `map(list(string))` | tfvars | Role names allowed to use each key, by data class. The roles come from other stacks and are named by convention (`<name_prefix>-rol-<function key>` in `modules/inference-functions`). `restricted` stays empty (ASM-165). |
| `protected_bucket_names` | `list(string)` | tfvars | Buckets for which the transport policy is rendered. Empty by default until the bucket owners fix the names. |
| `field_sms_configuration` | `object`, sensitive | `TF_VAR_field_sms_configuration` | SNS role and external ID for SMS codes (ASM-272). Null leaves email codes only. Never stored in a variable file. |

The account identifier is read from the caller identity at plan time and prefixed to the role names, so no variable file holds an account (PC-IAC-016).

## Outputs

Only the outputs that later stacks need are exposed (PC-IAC-019 section 3.2). A consuming stack reads these through `terraform_remote_state` only with the documented exception of PC-IAC-019 section 2.2 in its own README, or receives them as input variables.

| Output | Consumed by | Use |
|---|---|---|
| `kms_key_arns` | B09b (telemetry-ingestion), B07b (firewall-rules), B10 (inference-functions), B13 (farm) | Map by data class. Telemetry ingestion takes `telemetry` and `logs` (its `kms_key_arns` input), inference functions take `records`, `logs` and the classes their functions read or write, and the web ACL log destination of firewall rules takes `logs` once B07b adds logging (PC-IAC-020). |
| `field_user_pool_id`, `field_user_pool_arn`, `staff_user_pool_id`, `staff_user_pool_arn` | API authorizers | Identifiers of the two pools. |
| `cognito_group_names` | API authorizers | Group name of each role. |
| `revocation_role_arn`, `revocation_role_name` | revocation function | Role of the function that revokes device and user identities; the name lets its owner attach the basic execution policy. |
| `iot_rule_role_arn`, `iot_logging_role_arn` | B09b (telemetry-ingestion) | Inputs `rule_role_arn` and `logging_role_arn`. |
| `secure_transport_policy_statements_json` | bucket owners | Deny statements for plain HTTP and TLS below 1.2, or null. Each bucket owner merges it into its policy. |

`modules/firewall-rules` takes nothing from security except the optional `logs` key above, so no other output is added for B07b.

## IoT roles (module v0.5.0)

Tag `v0.5.0` adds the two roles of the telemetry ingestion: the role assumed by the telemetry topic rule and the role that IoT Core uses to write its logs. They are exposed as `iot_rule_role_arn` and `iot_logging_role_arn` and feed the `rule_role_arn` and `logging_role_arn` inputs of `modules/telemetry-ingestion` (B09b).

The `flow_logs` input of the network stack (destination and role) is not produced by the module either; it stays null until a module tag provides them.

## Plan it against Floci

Credential-free plan per PC-IAC-028, with the same pinned image as the network stack. Replace `qa` with `dev` or `pdn` as needed.

```bash
docker run -d --rm --name floci -p 4566:4566 \
  floci/floci@sha256:5ee85db604c4aa74ac76e07ea5cc83086f37bb472bf3dbb97e34019e48efae9c
export AWS_ENDPOINT_URL=http://localhost:4566 AWS_ACCESS_KEY_ID=test \
  AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1
aws s3 mb s3://floci-plan-state
terraform -chdir=stacks/security init -input=false \
  -backend-config="bucket=floci-plan-state" -backend-config="key=security/terraform.tfstate" \
  -backend-config="region=us-east-1" -backend-config="use_path_style=true" \
  -backend-config="skip_credentials_validation=true" \
  -backend-config="skip_requesting_account_id=true" -backend-config="skip_metadata_api_check=true"
terraform -chdir=stacks/security plan -lock=false \
  -var-file=../../environments/qa/qa.tfvars.example
```

Each environment plans 31 resources to add, 0 to change and 0 to destroy: 8 keys, 8 aliases, 2 user pools, 7 groups, and three roles (revocation, IoT rule, IoT logging) with one policy each, plus the policy documents read at apply time. Nothing is applied: `terraform apply` and `terraform destroy` are never run.

## Verification

```bash
terraform fmt -check -recursive
terraform -chdir=stacks/security init -backend=false
terraform -chdir=stacks/security validate
terraform -chdir=stacks/security test
```

## Open points

| Topic | Detail |
|---|---|
| Key user names | The examples use placeholder role names until the function keys of B10 are fixed. A real apply needs each named role to exist before the key policy that names it, which the apply order of the stacks must respect; this plan-only work does not apply. |
| Cross-account | The stack runs in one account. The state-backend `domain_access` plan and write roles remain the access control of the state. |
