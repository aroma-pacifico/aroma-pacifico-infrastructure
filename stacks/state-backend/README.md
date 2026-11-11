# state-backend stack (B02, box D02)

Creates the encrypted, versioned state bucket and the customer-managed key of one environment by consuming the `state-backend` module of `aroma-pacifico-terraform-modules` at a git tag (PC-IAC-015, currently `v0.3.0`). The environment comes from `-var-file=../../environments/<env>/<env>.tfvars`; its state is separate from the other environments by bucket, key and name.

- The role inputs are names. The account identifier is read from the caller identity at plan time, so none is committed. The names in the examples are placeholders until B06 provides the real identities.
- `backend.tf` declares an empty S3 backend. `backends/<env>.s3.tfbackend.example` shows the partial configuration of each environment, with an own state key per domain and native locking (`use_lockfile`). The first apply of this stack would need a bootstrap that is outside the plan-only scope.
- `tests/state_backend_unit_test.tftest.hcl` checks the plan with a mocked provider: `terraform -chdir=stacks/state-backend test`.
