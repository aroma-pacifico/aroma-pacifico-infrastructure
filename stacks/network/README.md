# Network root and single-center association

This root hosts the network domain (box D04, B04) and the association of the pdn environment with exactly one collection center (box D05, B05).

## Single-center association

`main.tf` calls the `collection-center-association` module from the public modules repository, pinned by git tag (PC-IAC-015). One run selects one center through `collection_center`; `locals.tf` holds the approved catalog (Cauca `10.41.0.0/16`, Huila `10.42.0.0/16`, Tolima `10.43.0.0/16`). A different key, a mismatched department or a mismatched CIDR is rejected, and no input accepts a list of centers, so the other centers and Buenaventura are never planned. Permanent links target pdn only (ASM-121); dev and qa are rejected.

The module is injected with two providers, as PC-IAC-005 requires:

| Alias | Account | Owns |
|---|---|---|
| `principal` | Workload (VPC owner) | Transit Gateway VPC attachment |
| `network` | Hub | Customer gateway, VPN connection, prefix list, attachment accepter when the accounts differ |

Both providers assume an externally supplied plan role and assert their account with `allowed_account_ids`. No route, firewall rule, Transit Gateway, certificate or secret is created here: `routing_references` exposes the attachment, VPN, customer gateway and prefix list references that B07 consumes. The `network` input has the shape of the B04 outputs (`vpc_id`, `vpc_cidr_block`, `transit_attachment_subnet_ids`).

## Verification

```bash
terraform -chdir=stacks/network init -backend=false -input=false
terraform -chdir=stacks/network validate
terraform -chdir=stacks/network test
```

`terraform test` runs offline with mocked providers: three valid centers and eight rejection cases. A speculative plan against the Floci emulator (PC-IAC-028) loads `emulator.tfvars`, whose fixtures are synthetic (all-zero accounts, placeholder references) and override the pdn-only inputs of the qa example. The `Floci plan` workflow creates the two fictitious plan roles inside the emulator before it plans. Nothing is applied.
