# Network root: D05 selection contract

Refs aroma-pacifico/aroma-pacifico-roadmap#25. Status: partial, blocked by B04.
This root currently validates configuration only. It declares no AWS resources,
providers, child modules, backend or credentials. It is not an executable
cloud-to-center connection. B01/B02/B03/B04 own the missing root foundations;
the existing local B02 branch is not included in this branch.

## Inputs and output

| Input | Type | Required | Behavior |
|---|---|---|---|
| `collection_center` | Object with `key` and optional `department`, `cidr_block` strings | Yes | Selects one center. Optional fields assert consistency; they never override the catalog. |
| `environment` | String | Yes | Only `pdn` is accepted for permanent association, per ASM-121. |

`selected_center` returns one object with `key`, `department`, `cidr_block`
and `environment`. The minimal configuration is:

```hcl
environment       = "pdn"
collection_center = { key = "cauca" }
```

The catalog follows A11 section 2 and A07 section 2: `cauca` resolves to
`10.41.0.0/16`, `huila` to `10.42.0.0/16`, `tolima` to `10.43.0.0/16`.
The keys identify departmental patterns; no municipality or physical site name
is invented. For imported configuration, optional assertions catch mismatches:

```hcl
collection_center = {
  key        = "tolima"
  department = "tolima"
  cidr_block = "10.43.0.0/16"
}
```

The three catalog entries are inert configuration. One direct lookup produces
one object; there is no iteration, resource multiplicity or fallback center.
Unknown keys, Buenaventura, inconsistent assertions, collections instead of one
object, and missing required inputs are rejected. Buenaventura is a transporter
app flow without Federation equipment (A10 section 10), never a fourth center.
Terraform object conversion can discard unknown attributes: this interface is
not a general schema validator for arbitrary extra fields.

## Offline verification

Use Terraform >= 1.14.0. All native test runs explicitly use `command = plan`.
These commands require no AWS identity and create no resources or state:

```text
terraform fmt -check -recursive
terraform -chdir=stacks/network init -backend=false -input=false
terraform -chdir=stacks/network validate
terraform -chdir=stacks/network test
```

The `pdn` value is configuration tested offline, not a production account plan.
There is no provider dependency to pin or lock yet. Do not use an empty-resource
plan as evidence that the D05 connectivity acceptance criterion is complete.

## Integration after B04

Reusable AWS resources belong in `aroma-pacifico-terraform-modules`, not this
root. After B04 exposes its actual interface, D05 can consume the VPC, transit
subnets and hub references; use narrow root data lookups/SSM contracts, never
`terraform_remote_state`. Implement the single-center VPN/customer gateway,
attachment and prefix-list resources according to ASM-120 and ASM-200. The
customer gateway uses a supplied private certificate, not an invented WAN IP
or a preshared key. Certificate lifecycle and cross-account ownership still
need concrete inputs and review. Routing policy remains with B07/D07.

Root governance must supply deterministic names and mandatory tags, including
`CollectionCenter` and `CostCenter = collection-centers` (PD-072). Preserve
environment/domain remote state isolation. A permanent `dev` link is prohibited;
the temporary `qa` logistics acceptance exception requires separate, explicit
firewall approval and removal, not a relaxation of this input validation.

No module release tag exists. Do not invent a version, use a branch ref, or
commit a local module source in the root. Future module tests may use the
permitted `sample/` local source for offline verification; production composition
must wait for a reviewed versioned release. No new architecture decision is
made by this selection contract.
