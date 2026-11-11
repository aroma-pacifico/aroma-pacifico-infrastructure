# D02 remote state

Owner: JR2. Scope: partial progress on aroma-pacifico/aroma-pacifico-roadmap#22 (B02, 6 h estimate). This is code-level preparation, not a working cloud backend. The [decision register](decision-log.md) tracks unresolved prerequisites.

## Architecture and configuration

ADR-003 in the architecture repository selects domain roots `stacks/network`, `stacks/security` and `stacks/workload`. Each contains `backend.tf` with an empty `terraform { backend "s3" {} }` declaration and `versions.tf` with `required_version = ">= 1.14.0"` (PC-IAC-006). The backend is built into Terraform; AWS provider constraints and committed provider lockfiles belong to B01 when it adds provider consumers. These scaffolds manage no resources or input secrets.

| Field | Reason |
|---|---|
| `bucket` | One verified bucket in each environment's account; placeholders are intentionally unusable. |
| `key` | ADR-003's exact domain path: `network/terraform.tfstate`, `security/terraform.tfstate` or `workload/terraform.tfstate`. |
| `region` | `us-east-1`, established by ADR-001 and the landing-zone design. |
| `encrypt = true` | PC-IAC-008 requires server-side state encryption. |
| `kms_key_id` | Environment-owned customer-managed state key, as ADR-003 and ASM-097 require. |
| `use_lockfile = true` | Native S3 concurrency locking; compatible with the architecture's Terraform floor. |
| `allowed_account_ids` | Fail initialization when the backend caller uses an unintended account. |

`dev`, `qa` (test) and `pdn` (production) each have a separate template per stack. A state object's full identity is **bucket plus key**. Keys intentionally remain the accepted domain paths; the distinct bucket, account, IAM boundary and local backend cache identify the environment. Do not substitute a single shared bucket or use workspaces to represent these environments. Use only the default workspace. The preflight rejects duplicate objects and repeated accounts/buckets/KMS keys across environments, including accidental reuse of production configuration.

## Offline validation and future initialization

From the repository root, run `python scripts/prepare-backend.py --templates`,
`python scripts/verify-backends.py`, `terraform fmt -check -recursive`, and, for
each domain root, `terraform -chdir=stacks/network init -backend=false -input=false`
followed by `terraform -chdir=stacks/network validate` (replace `network` for the
other two). The tracked verifier tests synthetic configuration and rejects
unsafe or incomplete inputs; it only inspects printed initialization commands.
Offline validation never proves bucket reachability, permissions or security.

After the blockers are resolved, copy each `.example` file to the same path without `.example`. Replace only the REQUIRED identifiers with owner-verified values, consistent across domains. Real backend files are ignored by Git and must contain no credentials. The supplied literal-file format deliberately excludes custom endpoints, insecure TLS options, profiles and arbitrary HCL expressions.

`python scripts/prepare-backend.py --environment qa --stack network` validates all nine concrete files, then prints PowerShell commands for review; it executes none. `--config-root` can select an external directory with the same domain/backends layout. The printed commands set `TF_WORKSPACE=default` and an absolute, environment-and-domain-specific `TF_DATA_DIR` under ignored `.terraform-data/`, then request `init -input=false -reconfigure -backend-config=<absolute-file>`. Use a fresh working directory/cache, verify the tuple and identity, and never add backend overrides or migration flags. Existing state requires a separately approved migration procedure; reconfigure is not migration. Do not run a plan of these empty scaffolds against an existing workload state: it could propose deletes.

Future `init` loads backend settings and modules/providers and contacts S3; it does not create the bucket. A normal future `plan` reads state and AWS resources, acquires/releases a `.tflock`, and proposes changes. Future `apply` executes the approved plan and writes new state while holding the lock. Apply is prohibited throughout the academic phase. Never use `-lock=false` or force-unlock to bypass a lock error. Even a remote plan writes lock objects, so it is not strictly non-mutating; PD-019 must settle the permitted evidence approach first.

## Bootstrap contract (not provisioned)

Local launcher prerequisite (2026-11-10): the installed managed Terraform launcher
overrides incoming TF_DATA_DIR with an operational cache derived only from the
root path. The preflight verifies printed environment/domain strings, not this
effective routing. Before any future live init, the tooling owner must verify
separate effective environment caches and the selected backend tuple under the
approved launcher. Do not bypass it or alter operational backend metadata to
manufacture isolation evidence. Current checks use its validation context only.

The bucket and KMS key must exist **before** backend-enabled initialization.
No existing backend resources or identities have been verified. The merged
100-hour plan (`docs/iac-plan-100h.md`, ASM-213, architecture PR #38) explicitly
assigns the state bucket and state KMS key to B02 in `stacks/state-backend`.
ADR-003 designs migration of that stack's state into its own bucket. This
supersedes the earlier local register's assumption that independent external
bootstrap-state ownership was mandatory; no such alternative is approved.
The resource module, bootstrap root and released module interface are still
missing. B01 has not delivered its root/provider/environment baseline. This
branch supplies only the three consumer backend scaffolds, not the complete
B02 resource graph. PD-019 still governs plan evidence. No bootstrap, local
shared state, migration or cloud initialization is performed; a future execution
procedure requires separate authorization within the plan-only constitution.

The independently approved bootstrap must specify one bucket per environment in its workload account, versioning enabled, all four S3 Block Public Access settings, BucketOwnerEnforced ownership, default SSE-KMS with that environment's state CMK, and a bucket-policy deny for non-TLS requests (`aws:SecureTransport=false`). Deny uploads that request another encryption algorithm or another key, and deny unexpected principals. AWS SDK HTTPS defaults are not a substitute for this policy. Use `force_destroy=false` and `lifecycle { prevent_destroy = true }`; protect the KMS key from destruction, enable annual rotation and retain the ASM-097 30-day key-deletion waiting period. Do not expire historical state versions before an owner approves retention. Enable the landing-zone audit integration. None of these bucket-side protections is created by `encrypt` or verified by `validate`.

## Authentication and least privilege

CI should use the existing **design** for GitHub OIDC into an environment plan role; no OIDC provider, role or Terraform workflow exists in this checkout. Restrict trust to the infrastructure repository and approved subjects, with `aud=sts.amazonaws.com`; production deployment trust must use the protected `pdn` environment subject. Never grant cloud credentials to untrusted PR code. Use IAM Identity Center/SSO temporary credentials locally through the AWS credential chain, without putting profiles or access keys in backend files. Backend identity and AWS provider identity are configured separately; provider `assume_role` does not authenticate the backend. B01/B03/B11 own that wiring.

| Permission | Scope for a plan role in one environment/domain |
|---|---|
| `s3:ListBucket` | Only that environment's bucket ARN, with a prefix condition allowing only the selected domain state/lock paths; verify actual list requests. |
| `s3:GetObject` | Exact `arn:aws:s3:::<verified-bucket>/<domain>/terraform.tfstate`. |
| `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` | Exact adjacent `terraform.tfstate.tflock` object; no wildcard state deletion. |
| `kms:Decrypt` | Exact environment state-key ARN, for state and lock reads. |
| `kms:GenerateDataKey`, `kms:Encrypt` | Exact key for encrypted lock writes; scope via S3 service and encryption context where verified. |

Keep matching KMS key-policy grants; IAM alone is insufficient. Backend KMS permission requirements must be verified against the selected Terraform version. If S3 Bucket Keys are enabled, the KMS encryption context can be bucket-scoped, so enforce domain isolation through S3 IAM too. A future apply role additionally needs `s3:PutObject` on the exact state object; plan roles must not have it. Normal operations need no state `DeleteObject`, bucket administration or KMS administration. Put recovery/version access in a separate audited human role. No QA principal may access the PDN bucket/key. These are recommendations, not deployed policies, and cannot compensate for absent bucket policies or SCPs.

## Secrets, recovery and alternatives

`sensitive = true` masks output; it does **not** remove plaintext values from state. Use IAM instead of passwords; where supported use ephemeral reads and write-only provider arguments. Ordinary secret-manager data sources can persist secret values. State, backend caches and plans still require restricted access. Git ignores state/locks, caches, concrete backend files, tfvars and common saved plan names. Never save a sensitive plan under an arbitrary unignored filename; use ignored `.local/` for local artifacts and review staging before every commit.

To recover later, stop concurrent writers, have an authorized operator inspect the state lineage/serial and S3 version history, select the correct environment and domain, preserve the current version, and restore only under explicit approval. Versioning cannot recover data if the bucket or KMS key is lost. `prevent_destroy` only protects Terraform operations while the resource declaration remains; IAM, SCPs, key protection and audit remain necessary. Reverting this code does not migrate or restore state. No recovery, migration or unlock was performed here.

Native locking avoids a DynamoDB table and its policies/costs. A shared bucket weakens the accepted account boundary; workspaces can select the wrong state; local shared state violates PC-IAC-008; HCP Terraform violates the S3 standard. Future resources incur S3 storage/version/request, customer-managed KMS key/API and audit costs. No cost figure is asserted and no resources were created.

Primary references: [HashiCorp S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3), [Terraform init](https://developer.hashicorp.com/terraform/cli/commands/init), [AWS SSE-KMS](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html).
