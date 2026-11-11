# B05 delivery evidence: single collection center association (box D05)

Refs aroma-pacifico/aroma-pacifico-roadmap#25. Plan-only: nothing is applied and no cloud resource exists.

## What the root does

`stacks/network` calls the `collection-center-association` module of the public modules repository at tag `v0.4.0` (PC-IAC-015) when `center_association` is set, and injects two provider aliases: `principal` for the workload account and `network` for the hub account (PC-IAC-005). Each asserts its account with `allowed_account_ids` and assumes an externally supplied plan role. The VPC comes from the `network` module of the same stack (B04b). The root creates no route, firewall rule, Transit Gateway or certificate; it exposes `association_routing_references` for B07.

| Resource | Provider | Count |
|---|---|---|
| `aws_ec2_transit_gateway_vpc_attachment.environment` | workload | 1 |
| `aws_ec2_transit_gateway_vpc_attachment_accepter.environment` | hub | 1 when the accounts differ, else 0 |
| `aws_customer_gateway.center` | hub | 1 |
| `aws_vpn_connection.center` | hub | 1 (two tunnels, IKEv2, static routes) |
| `aws_ec2_managed_prefix_list.center` | hub | 1 (the selected /16 only) |

## Acceptance criteria

| Criterion | Status | Evidence |
|---|---|---|
| One collection center per run | PASS | `center_association.collection_center_key` is one string, `cauca`, `huila` or `tolima`; another key fails validation and the module is instantiated from a one-key map. |
| Respects the department addressing block | PASS | The /16 is read from `collection_centers` (Cauca `10.41.0.0/16`, Huila `10.42.0.0/16`, Tolima `10.43.0.0/16`, which the stack already requires), so it cannot be contradicted; the module rejects an overlap with the VPC range. |
| No 3 centers and no Buenaventura infrastructure | PASS | No iteration over the catalog; `buenaventura` is rejected; one prefix list entry. |
| The plan exposes the cloud-to-center link | PASS | Emulator plan below; outputs `routing_references` and `selected_center`. |

## Verification

Run from the repository root with Terraform 1.15.8 and TFLint 0.66.0.

```text
terraform fmt -check -recursive stacks/*            exit 0
terraform -chdir=stacks/network init -backend=false  exit 0
terraform -chdir=stacks/network validate             Success! The configuration is valid.
terraform -chdir=stacks/network test                 Success! 16 passed, 0 failed.
tflint --chdir=stacks/network (CI config)            exit 0
trivy config --severity HIGH,CRITICAL stacks/network 0 misconfigurations
bash scripts/check-env-secrets.sh environments       SUCCESS
```

The 16 runs are the 5 B04b tests and 11 association runs: the three centers, no association by default, and the rejections of an unknown center, Buenaventura, a plan role outside its account, dev and qa.

### Emulator plan (PC-IAC-028)

With the pinned Floci image, `AWS_ENDPOINT_URL=http://localhost:4566`, test credentials, a state bucket created in the emulator and the two fictitious plan roles created in it:

```text
qa example                     Plan: 163 to add, 0 to change, 0 to destroy.
pdn example + emulator.tfvars  Plan: 167 to add, 0 to change, 0 to destroy.
  module.association["cauca"].aws_customer_gateway.center
  module.association["cauca"].aws_ec2_managed_prefix_list.center
  module.association["cauca"].aws_ec2_transit_gateway_vpc_attachment.environment
  module.association["cauca"].aws_vpn_connection.center
```

The emulator has one account, so the fixtures place both owners in it and the accepter is omitted (4 association resources). The cross-account graph with the accepter (5) is covered by the mocked native tests. The VPN has `local_ipv4_network_cidr = 10.41.0.0/16` (Cauca) and `remote_ipv4_network_cidr = 10.82.0.0/16` (the pdn VPC); no update, destroy or replacement appears.

## Limits

The fixtures are synthetic: the all-zero account and the placeholder VPC, Transit Gateway and certificate references name no real resource. The VPC reference is wired to the B04b module outputs, so in the emulator it is a planned VPC rather than an existing one. RAM sharing of the Transit Gateway, the hub certificate and the B07 routes are external contracts. Permanent links exist only in pdn (ASM-121); the plan in CI uses fixtures that override the qa example for that reason, and the saved qa account plan of ASM-051 is not part of this delivery.
