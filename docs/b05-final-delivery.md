# B05 delivery evidence: single collection center association (box D05)

Refs aroma-pacifico/aroma-pacifico-roadmap#25. Plan-only: nothing is applied and no cloud resource exists.

## What the root does

`stacks/network` calls the `collection-center-association` module of the public modules repository, consumed by git tag (PC-IAC-015), and injects two provider aliases: `principal` for the workload account and `network` for the hub account (PC-IAC-005). Each asserts its account with `allowed_account_ids` and assumes an externally supplied plan role. The root keeps the approved departmental catalog and exposes the references B07 needs; it creates no route, firewall rule, Transit Gateway or certificate.

| Resource | Provider | Count |
|---|---|---:|
| `aws_ec2_transit_gateway_vpc_attachment.environment` | workload | 1 |
| `aws_ec2_transit_gateway_vpc_attachment_accepter.environment` | hub | 1 when the accounts differ, else 0 |
| `aws_customer_gateway.center` | hub | 1 |
| `aws_vpn_connection.center` | hub | 1 (two tunnels, IKEv2, static routes) |
| `aws_ec2_managed_prefix_list.center` | hub | 1 (the selected /16 only) |

## Acceptance criteria

| Criterion | Status | Evidence |
|---|---|---|
| One collection center per run | PASS | `collection_center` is a single object keyed `cauca`, `huila` or `tolima`; a list or another key fails validation. |
| Respects the department addressing block | PASS | The catalog maps Cauca to `10.41.0.0/16`, Huila to `10.42.0.0/16` and Tolima to `10.43.0.0/16`; an asserted department or CIDR that differs is rejected and the module rejects an overlap with the VPC range. |
| No 3 centers and no Buenaventura infrastructure | PASS | No iteration over the catalog; `buenaventura` is rejected; one prefix list entry. |
| The plan exposes the cloud-to-center link | PASS | Emulator plan below; outputs `routing_references` and `selected_center`. |

## Verification

Run from the repository root with Terraform 1.15.8 and TFLint 0.66.0.

```text
terraform fmt -check -recursive stacks/*            exit 0
terraform -chdir=stacks/network init -backend=false  exit 0
terraform -chdir=stacks/network validate             Success! The configuration is valid.
terraform -chdir=stacks/network test                 Success! 11 passed, 0 failed.
tflint --chdir=stacks/network (CI config)            exit 0
trivy config --severity HIGH,CRITICAL stacks/network 0 misconfigurations
bash scripts/check-env-secrets.sh environments       SUCCESS
```

The 11 mocked runs cover the three centers and these rejections: unknown center, Buenaventura, wrong department, wrong CIDR, dev, qa, and a plan role outside its account.

### Emulator plan (PC-IAC-028)

With the pinned Floci image, `AWS_ENDPOINT_URL=http://localhost:4566`, test credentials, the empty S3 backend initialized against a bucket created in the emulator, and `-var-file` for the qa example followed by `stacks/network/emulator.tfvars`:

```text
module.association.aws_customer_gateway.center will be created
module.association.aws_ec2_managed_prefix_list.center will be created
module.association.aws_ec2_transit_gateway_vpc_attachment.environment will be created
module.association.aws_vpn_connection.center will be created
Plan: 4 to add, 0 to change, 0 to destroy.
```

The emulator has one account, so the fixtures place both owners in it and the accepter is omitted (4 resources). The cross-account graph with the accepter (5 resources) is covered by the mocked native tests, where the hub account differs. The prefix list entry is `10.41.0.0/16`, the same range as the VPN `local_ipv4_network_cidr`; no update, destroy or replacement appears.

## Limits

The fixtures are synthetic: the all-zero account and the placeholder VPC, Transit Gateway and certificate references name no real resource. The `network` input has the shape of the B04 outputs and is wired to them when the B04 root is composed. RAM sharing of the Transit Gateway, the hub certificate and the B07 routes are external contracts. Permanent links exist only in pdn (ASM-121); the plan in CI uses fixtures that override the qa example for that reason, and the saved qa account plan of ASM-051 is not part of this delivery.
