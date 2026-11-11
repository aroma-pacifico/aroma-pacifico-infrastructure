# Network stack (box D04, B04b)

Root stack of the network domain. It wires the reference module `modules/network` of [aroma-pacifico-terraform-modules](https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules), pinned by tag `v0.3.0` (PC-IAC-015), into one VPC per environment with eight tiers of subnets, route tables, network ACLs and VPC endpoints. The stack defines no resource of its own: `main.tf` is a single module call, `locals.tf` injects the governance values and `variables.tf` takes the per-environment values from `environments/<env>/<env>.tfvars.example`. The addressing comes from the [addressing plan](https://github.com/aroma-pacifico/aroma-pacifico-architecture/blob/main/docs/addressing-plan.md) (A07), sections 3 and 4.3.

```text
stacks/network/
|-- backend.tf, providers.tf, versions.tf   B01 scaffold (partial S3 backend, provider, pins)
|-- variables.tf                            governance variables plus the network inputs
|-- locals.tf                               governance tags, name prefix, per-center maps, reserved blocks
|-- main.tf                                 the module call
|-- outputs.tf                              outputs consumed by later stacks
|-- tests/network.tftest.hcl                offline plan-mode tests
`-- .terraform.lock.hcl                     scoped provider lock (PC-IAC-006)
```

## Inputs

| Variable | Type | Source | Meaning |
|---|---|---|---|
| `aws_region`, `environment`, `common_tags` | `string`, `string`, `map(string)` | tfvars | Governance inputs shared by every stack. `Client` and `Project` feed the names, so they must be lowercase alphanumeric. |
| `vpc_cidr_block` | `string` | tfvars | VPC block: `10.80.0.0/16` for `dev`, `10.81.0.0/16` for `qa`, `10.82.0.0/16` for `pdn`. A validation rejects any block that overlaps 10.41.0.0/16, 10.42.0.0/16 or 10.43.0.0/16. |
| `subnets` | `map(map(string))` | tfvars | CIDR block per tier and slot (`az1` to `az3`), section 4.3 of the addressing plan. |
| `collection_centers` | `map(object)` | tfvars | Reserved /16, firewall host and ground station host of each center. A validation requires the three reserved /16 blocks. |
| `collection_center_summary_cidr_block` | `string` | tfvars | `10.40.0.0/13`, the one route to every present and future center. |
| `transit_gateway_id` | `string` | tfvars | Transit gateway of the network account; null creates no center routes. Synthetic in the examples. |
| `data_store_ports` | `list(number)` | tfvars | Ports the application tier may reach in the data tier (CL-DAT-02). |
| `interface_endpoints` | `map(object)` | tfvars | Interface endpoints by short key (service suffix and tier). |
| `flow_logs` | `object` | security stack (B06b) | CloudWatch Logs destination and role; null disables the flow log. |
| `center_association` | `object` | tfvars or pipeline | Optional single-center association of pdn (B05). Null creates none. |
| `organization_id` | `string` | `TF_VAR_organization_id` | Organization admitted by the gateway endpoint policies. Never stored in a variable file. |

## Overlap guard

The case statement forbids any overlap with 10.41.0.0/16, 10.42.0.0/16 and 10.43.0.0/16. Three layers enforce it, and `tests/network.tftest.hcl` exercises them. The `vpc_cidr_block` validation of this stack rejects a VPC that intersects the reserved blocks, computed as integer ranges because Terraform 1.15 has no `cidrcontains`. The `collection_centers` validation requires those three blocks to be present, so the module checks always run against them. The module then rejects, in a precondition of the VPC, a VPC that overlaps any center, a summary that does not contain every center, and a subnet outside the VPC.

## Outputs

Only the outputs that later stacks need are exposed (PC-IAC-019 section 3.2).

| Output | Consumed by | Use |
|---|---|---|
| `vpc_id`, `vpc_cidr_block` | B07b, B09b | `vpc_id` of the firewall rules module; VPC block for security group rules. |
| `subnet_ids` | B09b | Subnets by tier and slot, for example `telemetry_ingress` and `application` for VPC-attached functions. |
| `subnet_cidr_blocks` | B07b | `application` blocks are the only sources of the data store security group (`application_cidr_blocks`). |
| `route_table_ids`, `network_acl_ids` | later routes and associations | One per tier. |
| `interface_endpoint_ids` | B07b | `execute-api` and `s3` endpoints that receive the endpoint policies (CL-APP-02, CL-DRN-02). |
| `endpoint_security_group_ids`, `gateway_endpoint_ids` | B06b | Endpoint security groups; gateway endpoint IDs for `aws:SourceVpce` conditions. |
| `availability_zone_ids` | B09b | Availability Zone ID behind each slot. |
| `transit_attachment_subnet_ids` | network account | Subnets for the transit gateway attachment, created outside this stack. |

A consuming stack reads these through `terraform_remote_state` only with the documented exception of PC-IAC-019 section 2.2 in its own README.

## Plan it against Floci

Credential-free plan per PC-IAC-028 (pinned image digest of AGENTS.md section 8). The stack declares an S3 backend, so the plan needs a state bucket inside the emulator. Run from the repository root; replace `qa` with `dev` or `pdn` as needed.

```bash
docker run -d --rm --name floci -p 4566:4566 \
  floci/floci@sha256:5ee85db604c4aa74ac76e07ea5cc83086f37bb472bf3dbb97e34019e48efae9c
export AWS_ENDPOINT_URL=http://localhost:4566 AWS_ACCESS_KEY_ID=test \
  AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1
export TF_VAR_organization_id=o-a1b2c3d4e5   # fictitious value, not an account
aws s3 mb s3://floci-plan-state
terraform -chdir=stacks/network init -input=false \
  -backend-config="bucket=floci-plan-state" -backend-config="key=network/terraform.tfstate" \
  -backend-config="region=us-east-1" -backend-config="use_path_style=true" \
  -backend-config="skip_credentials_validation=true" \
  -backend-config="skip_requesting_account_id=true" -backend-config="skip_metadata_api_check=true"
terraform -chdir=stacks/network plan -lock=false \
  -var-file=../../environments/qa/qa.tfvars.example
```

Each environment plans 163 resources to add, 0 to change and 0 to destroy. Nothing is applied: `terraform apply` and `terraform destroy` are never run.

## Single collection center association (B05, box D05)

`main.tf` also calls `modules/collection-center-association`, pinned by tag `v0.4.0` (PC-IAC-015), when `center_association` is set. The variable is null by default, so dev, qa and the plain pdn example plan exactly as before. One object selects one center (`cauca`, `huila` or `tolima`); its /16 is read from `collection_centers`, so the approved addressing block cannot be contradicted, and the module is instantiated from a one-key map, so at most one association exists per run. Other keys, including Buenaventura, fail validation. Permanent links exist only in pdn (ASM-121): any other `environment` fails validation.

The module receives the VPC of the `network` module directly (`vpc_id`, `vpc_cidr_block`, `transit_attachment_subnet_ids`) and two provider aliases, as PC-IAC-005 requires.

| Alias | Account | Owns |
|---|---|---|
| `principal` | Workload (VPC owner) | Transit Gateway VPC attachment |
| `network` | Hub | Customer gateway, VPN connection, prefix list, attachment accepter when the accounts differ |

Each alias asserts its account with `allowed_account_ids` and assumes an externally supplied plan role. No route, firewall rule, Transit Gateway or certificate is created here: `association_routing_references` exposes the attachment, VPN, customer gateway and prefix list references that B07 consumes. The hub account, Transit Gateway and ACM certificate are external references, and the Transit Gateway must be shared with the workload account (RAM) beforehand.

`tests/association.tftest.hcl` covers the three centers, the default without association, and the rejections (unknown center, Buenaventura, plan role outside its account, dev, qa). `emulator.tfvars` holds synthetic fixtures (all-zero account, placeholder references) for the pdn plan against Floci: with `environments/pdn/pdn.tfvars.example` it plans 167 resources, the 163 of the network plus the 4 of the association. The `Floci plan` workflow creates the two fictitious plan roles inside the emulator before it plans.

## Verification

```bash
terraform fmt -check -recursive
terraform -chdir=stacks/network init -backend=false
terraform -chdir=stacks/network validate
terraform -chdir=stacks/network test
```

## Open points

| Topic | Detail |
|---|---|
| Provider alias | The stack passes its default provider as `aws.project`. PC-IAC-005 asks for an `alias = "principal"` provider with `assume_role`; that change to `providers.tf` belongs with the remote state work (PR 3) and is not made here. |
| Client and Project | The examples use the placeholders `clnt` and `proj` until PD-070 is decided; with the `dev`, `qa` or `pdn` suffix the name prefix stays within the 16 characters of the module. |
| `cognito-idp` endpoint | Not confirmed as an interface endpoint service (PD-120, PD-200); kept because CL-APP-01 names it. |
| Data store port | `5432` is a placeholder until the data design (A13) selects the store. |
| Flow log | Disabled until the security stack (B06b) supplies the log group and role. |
