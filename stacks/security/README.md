# Security stack (boxes D06 and D07, B06b and B07b)

Root stack of the security domain. It wires the reference module `modules/security` of [aroma-pacifico-terraform-modules](https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules), pinned by tag `v0.5.0` (PC-IAC-015), into the eight customer-managed keys, the two Cognito user pools with their seven groups, the role of the revocation function and, on request, the secure transport bucket policy. A second module call, `firewall_rules.tf`, wires `modules/firewall-rules` at tag `v0.5.0` into the permanent cloud firewall rules (B07b, see below). The stack defines no resource of its own: `main.tf` and `firewall_rules.tf` are module calls, `locals.tf` injects the governance values and turns role names into ARNs, and `variables.tf` takes the per-environment values from `environments/<env>/<env>.tfvars.example`.

```text
stacks/security/
|-- backend.tf, providers.tf, versions.tf   B01 scaffold (partial S3 backend, provider, pins)
|-- variables.tf                            governance variables plus the security inputs
|-- data.tf                                 caller identity, so no account identifier is stored
|-- locals.tf                               governance tags, name prefix, role names to ARNs
|-- main.tf                                 the security module call
|-- firewall_rules.tf                       the firewall rules module call (B07b)
|-- outputs.tf                              outputs consumed by later stacks
|-- tests/security.tftest.hcl               offline plan-mode tests of the security module wiring
|-- tests/firewall_rules.tftest.hcl         offline plan-mode tests of the firewall rules wiring
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
| `vpc_id` | `string` | tfvars | `vpc_id` output of `stacks/network` (synthetic fixture in the examples). |
| `application_subnet_cidr_blocks` | `map(string)` | tfvars | `subnet_cidr_blocks["application"]` output of `stacks/network`: the only sources of the data store group (CL-DAT-02). Must be subnet blocks, never the whole internet. |
| `interface_endpoint_ids` | `map(string)` | tfvars | `interface_endpoint_ids` output of `stacks/network`; the keys `exapi` and `s3` receive the endpoint policies (CL-APP-02, CL-DRN-02). |
| `collection_centers` | `map(object)` | tfvars | Same name and value as the network stack: the three reserved /16 blocks and the firewall and ground station hosts. The other zone blocks derive from the /16. |
| `data_store_ports` | `list(number)` | tfvars | Same name and value as the network stack (CL-DAT-02); `5432` is a placeholder until the data design (A13). |
| `platform_api_ids` | `list(string)` | tfvars | IDs of the private REST APIs that the execute-api endpoint policy admits (CL-APP-02). Placeholder fixtures until the API exists. |
| `drone_object_bucket_name` | `string` | tfvars | Drone object bucket that the S3 endpoint policy admits (CL-DRN-02). Placeholder fixture until the bucket exists. |

The account identifier is read from the caller identity at plan time and prefixed to the role names, so no variable file holds an account (PC-IAC-016).

## Outputs

Only the outputs that later stacks need are exposed (PC-IAC-019 section 3.2). A consuming stack reads these through `terraform_remote_state` only with the documented exception of PC-IAC-019 section 2.2 in its own README, or receives them as input variables.

| Output | Consumed by | Use |
|---|---|---|
| `kms_key_arns` | B09b (telemetry-ingestion), B10 (inference-functions), B13 (farm) | Map by data class. Telemetry ingestion takes `telemetry` and `logs` (its `kms_key_arns` input), inference functions take `records`, `logs` and the classes their functions read or write. The web ACL log destination of firewall rules would take `logs` (PC-IAC-020), but the module has no logging input yet. |
| `field_user_pool_id`, `field_user_pool_arn`, `staff_user_pool_id`, `staff_user_pool_arn` | API authorizers | Identifiers of the two pools. |
| `cognito_group_names` | API authorizers | Group name of each role. |
| `revocation_role_arn`, `revocation_role_name` | revocation function | Role of the function that revokes device and user identities; the name lets its owner attach the basic execution policy. |
| `iot_rule_role_arn`, `iot_logging_role_arn` | B09b (telemetry-ingestion) | Inputs `rule_role_arn` and `logging_role_arn`. |
| `secure_transport_policy_statements_json` | bucket owners | Deny statements for plain HTTP and TLS below 1.2, or null. Each bucket owner merges it into its policy. |
| `security_group_ids` | owners of the session host, the Resolver inbound endpoint and the data store | Keys `session_host`, `resolver`, `data_store`; there is no `load_balancer` key (PD-051). |
| `web_acl_arns` | CloudFront distribution of the public lookup, application API front door | Keys `lookup` and `api`. |
| `prefix_list_ids` | stacks that add security group rules | The five center lists `cc_device_mgmt`, `cc_firewalls`, `cc_ground_stations`, `cc_logistics`, `cc_staff`. |
| `rule_catalog`, `temporary_rule_ids` | release notes, pre-production audit (PD-125) | Every rule with validity and audit flag; the temporary map is empty (ASM-128). |
| `web_acl_settings` | plan review, audit | Scope, rate limits and allowed paths in force (ASM-129, ASM-155, ASM-300). |

`modules/firewall-rules` v0.5.0 has no logging input, so it takes nothing from the `logs` key yet.

## Firewall rules (B07a module, B07b wiring)

B07a is `modules/firewall-rules` of the modules repository (the same code in tags `v0.3.0` to `v0.5.0`). B07b is the call in `firewall_rules.tf`, pinned to `v0.5.0` like the security module. It plans the five collection center prefix lists, three security groups (management session host, Resolver inbound endpoint, data store), two interface endpoint policies and two web ACLs, and nothing else: no load balancer group, no temporary rule, no `0.0.0.0/0`. Attaching the groups and the web ACLs belongs to the stacks that own the hosts and front doors.

### Why this stack hosts it

The documents do not name the stack, so the placement follows the rules. PC-IAC-022 section 3.2 lists `aws_security_group`, `aws_network_acl` and `aws_wafv2_web_acl` as security-domain resources, and ADR-003 says that security groups belong to the security stack. The network stack keeps the VPC, subnets, routes, network ACLs and endpoints, and the module consumes its outputs the way PC-IAC-022 section 5.2 asks (network feeds security). The module needs from the network stack only `vpc_id`, the `application` subnet blocks and two interface endpoint IDs, and from the security stack at most the `logs` key. Both stacks could host it, because the prefix lists and endpoint policies are network-flavored and ASM-200 places all of D07 in one box; security is chosen by the binding rule and as the tie-break. This is a decision for the human lead.

One consequence to watch: ASM-293 will later feed a flow log destination and role from this stack into the network stack, and this stack already reads `vpc_id` from the network. There is no resource cycle, but the pipeline would plan network, then security, then network again when flow logs are enabled.

### Values and where they come from

| Input of the module | Value | Source |
|---|---|---|
| `api_rate_limit` | 1000 requests per source IP in 5 minutes | ASM-300 |
| `lookup_rate_limit`, `lookup_rate_scope_path` | 100 on `/s/` | ASM-155, sack and trip 7.3 |
| `lookup_allowed_path_prefixes` | `/assets/`, `/s/` (the module adds `/`) | ASM-129, sack and trip 7.3 |
| `waf_scope` | `CLOUDFRONT` | sack and trip 7.1 (public lookup front door) |
| `collection_centers` | firewall and ground station hosts from the network variable; staff (zones 1, 2), logistics (3), guests (4, 5) and device management (`.0/27`, `.32/28`, `.48/31` of zone 10) derived from the /16 | firewall policy 5.1, collection center network 3.1 |
| `enable_cloudfront_origin_rule` | `false` | PD-051 closed: CloudFront, no load balancer (sack and trip 7.2) |
| `temporary_rules` | `{}` | ASM-128: temporary rules are production changes with their own release note |
| `vpc_id`, `application_cidr_blocks`, `api_endpoint.endpoint_id`, `drone_object_endpoint.endpoint_id` | input variables mirroring the network outputs | PC-IAC-019 |
| `api_endpoint.resource_arns`, `drone_object_endpoint.bucket_arn` | built from `platform_api_ids`, `drone_object_bucket_name`, the Region and the caller account | not stated by the documents; placeholders |

Every rule keeps its audit flag in the `rule_catalog` output and as the `AuditBeforeProduction` tag (PD-125); the pre-production audit itself cannot run under the plan-only delivery.

### Open points of the firewall wiring

| Topic | Detail |
|---|---|
| WAF scope of the API | The module takes one `waf_scope` for both web ACLs. The lookup needs `CLOUDFRONT`; the application API front door is an API Gateway custom domain (security and identity, TLS policies), which takes a `REGIONAL` web ACL. The API ACL is therefore planned at the CloudFront scope until the module accepts a scope per ACL. |
| Web ACL logging | The module has no logging input, so the `logs` key is not used (documented exception to PC-IAC-020 in the module). |
| Placeholders | `platform_api_ids`, `drone_object_bucket_name` and the network identifiers are synthetic fixtures; the API IDs and bucket name need an assumption entry in the decision log. |
| Zone layout | The zone blocks derive from the /16 by the layout of the collection center network. A different layout for a center needs a variable, not a different formula. |

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

Each environment plans 50 resources to add, 0 to change and 0 to destroy: the 31 of the security module (8 keys, 8 aliases, 2 user pools, 7 groups, and three roles with one policy each, plus the policy documents read at apply time) and the 19 of the firewall rules (5 prefix lists, 3 security groups, 2 session host egress rules, 2 Resolver ingress rules, 3 data store ingress rules, 2 endpoint policies and 2 web ACLs). Nothing is applied: `terraform apply` and `terraform destroy` are never run.

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
