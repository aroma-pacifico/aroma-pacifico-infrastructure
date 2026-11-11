# aroma-pacifico-infrastructure

Terraform root stack of the Aroma Pacífico pattern environment: remote state, per-environment variables, secrets handling and plan-only CI/CD

Part of the Aroma Pacífico pilot, the 2026 update of the coffee traceability pilot for Cauca, Huila and Tolima. Work is tracked in [aroma-pacifico-roadmap](https://github.com/aroma-pacifico/aroma-pacifico-roadmap) and on the [Aroma Pacífico Pilot board](https://github.com/orgs/aroma-pacifico/projects/1).

## What lives here

This repository holds the Terraform root stacks of the pattern environment for the Aroma Pacífico pilot. D02 supplies partial S3 backend declarations with native S3 locking and environment templates; no backend has been deployed or verified in AWS. Provider wiring, workload modules and plan-only CI/CD remain dependent on the roadmap tasks below. Distributed AI agent rules and standards are synchronized here from the canonical `aroma-pacifico-ai-agents` repository.

## Remote state (D02)

Read [the backend guide](docs/remote-state.md) for prerequisites, offline checks,
IAM boundaries, bootstrap blockers and future initialization. Terraform >= 1.14.0
and Python >= 3.10 are required for the supplied offline checks.
See [D02 technical evidence](docs/d02-technical-evidence.md) for actual checks and remaining limitations.

```text
stacks/
|-- network/   (backend.tf, versions.tf, backends/*.s3.tfbackend.example)
|-- security/  (backend.tf, versions.tf, backends/*.s3.tfbackend.example)
|-- workload/  (backend.tf, versions.tf, backends/*.s3.tfbackend.example)
`-- state-backend/ (README, backends/*.example, inactive root-template/*.example)
scripts/prepare-backend.py
scripts/verify-backends.py
scripts/backend-routing.py
scripts/launcher-contract.json
scripts/test-backend-routing.py
scripts/verify-bootstrap.py
docs/remote-state.md
docs/b02-implementation-evidence.md
docs/d02-technical-evidence.md
docs/decision-log.md
docs/troubleshooting-log.md
```

These are backend-only root scaffolds in the ADR-003 paths, not executable
workload stacks. B01 (aroma-pacifico/aroma-pacifico-roadmap#21) is still open. No AWS provider or provider lockfile
is needed by these declarations: S3 backends are built into Terraform.

## Tasks delivered here

- [B01](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/21)
- [B02](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/22)
- [B03](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/23)
- [B11](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/31)
- [B12](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/32)
- [B13](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/33)

## Latest verification refresh

See [B02 dependency refresh](docs/d02-dependency-refresh.md) for the
2026-11-10 audit, current permissions, executed checks and remaining blockers.

The subsequent [B02 implementation evidence](docs/b02-implementation-evidence.md)
supersedes that snapshot for resource-module, bootstrap and launcher-routing
coverage. There are now twelve backend templates, including the fourth
`stacks/state-backend` domain with an inactive release template. Read the
[backend guide](docs/remote-state.md) for the fail-closed environment checkout
convention. No remote backend has been deployed or tested against AWS.
