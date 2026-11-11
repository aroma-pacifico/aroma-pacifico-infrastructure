# B02 remote Terraform state

Refs aroma-pacifico/aroma-pacifico-roadmap#22. Owner: JR2. IMPLEMENTED and
VERIFIED OFFLINE are code/evidence labels, not deployment claims. All four
issue criteria remain PARTIAL except secret hygiene, which passes within the
reviewed tracked-code scope. No real AWS plan, bootstrap or migration was run.

## Architecture and resource boundary

Accepted ADR-003 selects one S3 bucket and customer-managed KMS key per account
and environment, with native S3 locking. ASM-213 assigns their implementation to
B02. The reusable child is `modules/state-backend` in the Terraform modules
repository. The private [bootstrap composition](../stacks/state-backend/README.md)
is an inactive release template. Network, security and workload remain separate
backend-only scaffolds until B01 supplies their resource compositions.

| Backend field | Required contract |
|---|---|
| bucket | Distinct owner-verified environment bucket; root-built naming |
| key | `<domain>/terraform.tfstate`, domain network/security/workload/state-backend |
| region | us-east-1, ADR-001 primary Region |
| encrypt | true |
| kms_key_id | Same-account, same-Region customer-managed state key ARN |
| use_lockfile | true; no DynamoDB table |
| allowed_account_ids | Exactly the selected verified environment account |

There are twelve `.example` templates: three environments by four domains.
Placeholders cannot initialize a backend. Full state identity is bucket plus
key; domain keys remain identical across distinct environment buckets. Only
the default Terraform workspace is supported. Environments must never share
accounts, buckets, KMS keys or an effective initialization directory.

## S3 and KMS security

The child defines eight AWS resources: bucket, ownership controls, public-access
block, versioning, encryption, bucket policy, KMS key and alias. It enforces all
four public-access controls, BucketOwnerEnforced, SSE-KMS, versioning,
force_destroy=false and bucket/key prevent_destroy. There is no ACL, object
expiry, replication or lifecycle rule deleting state versions. KMS rotates every
365 days and retains the ASM-097 30-day deletion waiting period. Lockout safety
is retained. These resource properties are VERIFIED OFFLINE only.

Bucket policy denies insecure transport, unknown principals, wrong explicitly
requested encryption/key, and state deletion. Omitting encryption headers uses
the bucket CMK default; explicitly requesting aws:kms without its key is denied.
Exact per-domain plan roles read state and read/write/delete the adjacent
`.tflock`. Only separately configured writers may write state. Writers are an
optional typed boundary, not deployment authorization. Empty writer sets deny
state writes. Cross-domain state and lock access is explicitly restricted.

KMS policy names approved same-account IAM roles, with separate administrators,
configuration readers and data roles. It creates no roles and grants no root
delegation, wildcard administrator, default decrypt-to-admin, disable-key or
key-deletion action. Data operations require the exact account, S3 service and
state/lock object encryption context. Bucket Keys are disabled because their
bucket-scoped encryption context would invalidate that domain boundary. Key
policy Resource="*" means this specific key; restrictive S3 Deny statements use
wildcards, while Allow statements name roles/resources.

B06 must supply real principals and equally narrow identity policies. ListBucket
prefix grants alone do not override broader identity grants. The key creator
must be covered by the approved administration policy; alias creation also needs
IAM authorization. Real policy evaluation, lock permissions, AWS backend list
requests and key-lockout checks REQUIRE AWS verification. Audit/access logging
integration is BLOCKED BY DEPENDENCY: no approved destination was supplied.
Trivy's missing-access-logging finding is retained, not suppressed.

## Bootstrap without a circular backend

1. Review and release the resource module under a real SemVer tag. B01/B03/B06
   supply root/provider, environment/account and role contracts respectively.
2. Review the inactive root template. Its module URL contains an unmistakably
   non-release placeholder; do not activate it until an actual tag is available.
3. First bootstrap cannot use the bucket it will create. The initial composition
   excludes backend.tf.example. This task uses only a disposable mocked plan
   fixture, never shared local state or cloud creation.
4. Any future bootstrap execution, handling of its initial state and migration
   into `state-backend/terraform.tfstate` REQUIRE APPROVAL and a permitted
   governance phase. The current plan-only constitution prohibits execution.
5. After creation and independent security verification, consumer roots may
   initialize their approved buckets under a separately authorized handoff.

The preflight deliberately rejects state-backend initialization, including a
future self-hosted case. It cannot establish that bootstrap and migration have
already happened. A separately reviewed procedure must authorize that transition.
Never initialize an empty consumer scaffold against an existing workload state:
an empty resource graph could propose deleting resources owned by that state.

## Launcher routing and environment isolation

The approved AutoDev launcher replaces incoming TF_DATA_DIR. Its dispatcher
hashes the normalized absolute root path, not environment identity; the first
24 SHA-256 characters select `data/<id>` or `validation-data/<id>`. Setting a
different environment variable on one root therefore does not isolate caches.
It also checks/creates operational registrations before choosing validation.
No shared launcher file, operational registration or existing cache was changed.

The repository-side mitigation requires dedicated clean Git checkouts at
`.../environments/dev`, `.../environments/qa`, `.../environments/pdn`. Each must
match the reviewed control checkout's commit and origin. Domain root paths now
contribute both environment and domain to the effective destination. Do not
represent environments with workspaces or switch backend tuples on one root.

`prepare-backend.py` verifies all twelve concrete configurations, the separately
supplied expected account, a checkout-local backend file, tracked launcher/shim/
settings fingerprints, resolved executable, managed workspace, existing matching
registration, default workspace, cached backend tuple and inherited CLI arguments.
It rejects mismatches and creates no registrations. Any incoming TF_DATA_DIR must
already match the computed effective route. It prints review-only commands after
those checks; it does not initialize a backend or authenticate an account.

After all external prerequisites and explicit live-init approval, the review-only
interface is:

```text
python scripts/prepare-backend.py --environment qa --stack network --checkout-root <dedicated-environments/qa-checkout> --expected-account-id <verified-account>
```

Concrete files are ignored by Git. `--config-root` must stay inside the selected
checkout's stacks directory. Do not add credentials, profiles, custom endpoints,
extra backend overrides, migration flags or -lock=false. Missing registrations
require the tooling maintainer's approved provisioning process. Changing the
launcher requires renewed fingerprint review; do not just replace the hashes.

This is a fail-closed review aid, not a security sandbox around direct CLI use.
A user can bypass it, and checking then executing is not atomic. Full operational
isolation remains PARTIAL pending maintainer-owned registrations and real backend
verification. No launcher diagnostic command was used to manufacture evidence.

## Reproducible offline verification

Use Python >=3.10 and Terraform >=1.14 through the approved launcher. Before
running it in any new root, confirm its registration behavior. For this refresh,
a checksum-identical isolated copy of the approved shim/dispatcher/settings was
used with temporary launcher caches. This preserves launcher behavior without
touching shared operational registrations. No native Terraform bypass was used.
The existing AWS 6.0.0 package was a read-only installation mirror; recorded lock
checksums were retained. Local mirror installation is not a fresh registry
signature-verification claim.

```text
python scripts/prepare-backend.py --templates
python scripts/verify-backends.py
python scripts/test-backend-routing.py
python scripts/verify-bootstrap.py --module-root <reviewed-state-backend-child>
terraform fmt -check -recursive
terraform -chdir=stacks/network init -backend=false -input=false
terraform -chdir=stacks/network validate
```

Repeat the last two checks for security/workload. The state-backend directory is
intentionally inactive; verify-bootstrap.py copies its reviewed release template
to an ignored temporary development root, omits the backend and substitutes only
the module source. It initializes backend=false, validates and runs two native
mock-provider plan scenarios. It never alters the production source placeholder.
Routing tests run the unchanged dispatcher with fake native execution and
temporary registrations, proving destinations without touching real caches.
See [implementation evidence](b02-implementation-evidence.md) for actual results,
tool versions, negative scenarios, scanner findings and unavailable checks.

## External contracts and operational handoff

| Dependency | Required deliverable | Status |
|---|---|---|
| B01 #21 | Real root/provider baseline, exact CI Terraform version, module consumption | BLOCKED BY DEPENDENCY |
| B03 #23 | Verified per-environment accounts, names, configuration | BLOCKED BY DEPENDENCY |
| B06 #26 | Admin/configuration/plan identities, IAM policies, audit destination | BLOCKED BY DEPENDENCY |
| B13 #33 / module maintainers | Reviewed real SemVer release, protected CI/evidence | BLOCKED BY DEPENDENCY |
| Architecture PD-019 | Permitted real plan/lock evidence in plan-only phase | REQUIRES APPROVAL |
| Tooling maintainer | Dedicated approved registrations, reviewed launcher lifecycle | BLOCKED BY DEPENDENCY |
| AWS access owner | Authorized QA identity and existing verified backend | REQUIRES AWS |

Backend credentials and provider assume_role are separate: provider wiring never
authenticates the built-in backend. Use approved temporary identities only. A
remote plan normally writes/deletes lock objects, so agree PD-019 before calling
it read-only. Credentials alone do not authorize bootstrap, migration or deploy.

## State exposure, rollback and recovery

State can contain sensitive resource metadata and values even when outputs are
sensitive. Encrypting at rest does not restrict an authorized reader. Never
commit raw state, backend caches, saved plans, actual identities or credentials.
Use ignored .local for evidence, review staging and maintain narrow S3/KMS IAM.
Versioning protects history; it cannot recover a deleted key or bucket.

Current rollback is a code revert through review, with no cloud action. If ever
deployed, removing a resource block can bypass prevent_destroy; independent IAM,
SCPs, audit and a reviewed recovery procedure remain essential. Do not roll back
encryption by scheduling key deletion or disabling versioning. Recovery must
verify environment, lineage/serial and object version under explicit approval.
No recovery, state mutation or cloud deployment was performed.

References: [ADR-003](https://github.com/aroma-pacifico/aroma-pacifico-architecture/blob/main/docs/adr/adr-003-iac-tool-remote-state-and-pattern-module.md),
[B02](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/22),
[S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3),
[AWS SSE-KMS](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html).
