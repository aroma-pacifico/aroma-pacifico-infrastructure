# aroma-pacifico-infrastructure

Terraform root stack of the Aroma Pacífico pattern environment: remote state, per-environment variables, secrets handling and plan-only CI/CD

Part of the Aroma Pacífico pilot, the 2026 update of the coffee traceability pilot for Cauca, Huila and Tolima. Work is tracked in [aroma-pacifico-roadmap](https://github.com/aroma-pacifico/aroma-pacifico-roadmap) and on the [Aroma Pacífico Pilot board](https://github.com/orgs/aroma-pacifico/projects/1).

## What lives here

This repository holds the Terraform root stacks of the pattern environment. Provider configuration, S3 remote state with native locking, environment configuration and plan-only CI/CD are roadmap deliverables, not completed infrastructure. Distributed rules and standards come from `aroma-pacifico-ai-agents`.

## Single-center selection (D05, partial)

The [network root guide](stacks/network/README.md) documents the validated
single-center configuration. AWS connectivity resources and the executable
account plan remain blocked by B04 and the integration prerequisites.
See [D05 technical evidence](docs/d05-technical-evidence.md) for actual test
results and remaining acceptance gaps, and the
[troubleshooting log](docs/troubleshooting-log.md) for verification setup.

```text
stacks/network/
|-- README.md
|-- locals.tf
|-- outputs.tf
|-- variables.tf
|-- versions.tf
`-- tests/selection_unit_test.tftest.hcl
scripts/verify-d05.py
docs/d05-technical-evidence.md
docs/troubleshooting-log.md
```

## Tasks delivered here

- [B01](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/21)
- [B02](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/22)
- [B03](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/23)
- [B05](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/25), root configuration only
- [B11](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/31)
- [B12](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/32)
- [B13](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/33)
