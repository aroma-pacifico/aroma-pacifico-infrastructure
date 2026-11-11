# State-backend bootstrap composition

Refs aroma-pacifico/aroma-pacifico-roadmap#22. ASM-213 assigns the bucket and
state CMK to B02. Resource implementation lives in the reusable state-backend
child module, not this private root. One composition represents one environment.

## IMPLEMENTED / VERIFIED OFFLINE

root-template/ holds a complete provider/variable/locals/module/output composition
as inactive .tf.example files. It binds the provider account, assumes an explicitly
supplied role, injects aws.project from aws.principal, constructs governance names
in locals and exposes future encrypted/locked settings for all four domains.
The module source contains REQUIRED_REVIEWED_RELEASE, not a fabricated tag or an
unpublished branch. There are no active empty-root .tf files to plan accidentally.

scripts/verify-bootstrap.py stages these exact templates into an ignored temporary
development fixture, substitutes only the local child source, omits backend.tf.example,
and runs backend-disabled init, validate, fmt and native mock plan tests. It checks
one eight-resource graph and rejects a missing state-backend domain. No shared local
state or cloud account is created. This local source is never production wiring.

## Bootstrap sequence / REQUIRES APPROVAL

The backend bucket cannot be used before it exists. Accordingly, the initial
offline composition contains no S3 backend. The steady-state backend template
must not be included during initial resource planning. Its future key is
state-backend/terraform.tfstate in that environment's verified bucket.

ADR-003 describes eventual self-hosted state after migration. It does not grant
permission to run bootstrap apply, use shared local state, invent a second backend,
or migrate state here. SR1/SR2 must settle PD-019 and the initial execution/state
custody procedure. Human provisioning, any state transfer and activation of this
root require separate authorization consistent with the plan-only constitution.
No executable migration or deployment helper is supplied.

## BLOCKED BY DEPENDENCY / REQUIRES AWS

A maintainer must review/release the module and choose its real SemVer tag before
root activation. B01 supplies the accepted root/provider/CI baseline; B03 supplies
verified environment/account/Region/naming/tag configuration; B06 supplies approved
key administrators, configuration readers, per-domain plan/write role references
and their least-privilege IAM policies. No role, account or bucket value is invented.

The current role is for plan/review. Future key creation must use an approved
administrator covered by the key policy; the provider lockout safety check stays
enabled. Backend authentication remains separate from provider assume_role.
The module's context labels and outputs do not verify actual AWS ownership.

After prerequisites, verify the target account, backend controls, effective root
route and default workspace. Do not plan consumer-only scaffolds against existing
workload state. Operational S3 initialization, lock behavior, KMS/IAM authorization
and backend request-prefix compatibility remain unverified without AWS.

```text
state-backend/
|-- README.md
|-- backends/ (dev, qa, pdn templates; state-backend/terraform.tfstate)
`-- root-template/ (inactive .tf.example composition; steady-state backend separated)
```

A code revert is the current rollback. It neither rolls back cloud resources nor
restores state. Bucket/key protection and old-version retention are not a tested
recovery procedure; policy changes and deletion require independent review.
