# D02 / B02 technical evidence

Historical snapshot. See the [2026-11-10 refresh](d02-dependency-refresh.md)
for current permissions, dependencies and verification; older publication blockers
and test counts below describe the earlier session.

Owner: JR2. Refs aroma-pacifico/aroma-pacifico-roadmap#22. Status: PARTIAL; retain Draft PR status. Evidence rechecked on 2026-11-06 with Terraform 1.15.8 (windows_amd64). No AWS deployment occurred, no cloud resources were created and no terraform apply/destroy, state migration or force-unlock was executed. Remote AWS backend initialization is not verified.

## Implemented functionality

Commits `9df23d7` and `f63f144` add partial S3 backends to the network, security and workload roots, Terraform >=1.14.0, nine dev/qa/pdn templates, an offline preflight, ignore rules and operational documentation. No reusable child module declares a backend. The complete implementation is described in [the backend guide](remote-state.md); unresolved decisions are recorded in [the scoped register](decision-log.md).

ADR-003 supplies us-east-1, separate environment accounts/buckets/KMS keys and domain keys such as network/terraform.tfstate. Each state object is identified by bucket plus key. Templates require encrypt=true and use_lockfile=true; actual account, bucket and KMS values remain REQUIRED placeholders. The preflight rejects identity reuse, wrong domain keys, credential fields and disabled protection, then prints review-only initialization commands with separate environment/domain caches. It never executes those commands.

## Actual verification

The following commands were rerun from the infrastructure repository root. All positive checks exited zero. Git commands used per-command safe.directory and core.excludesFile settings for this repository; machine-specific paths are omitted here.

```text
terraform version
terraform fmt -check -recursive
python scripts/prepare-backend.py --templates
python .local/verify-backends.py
terraform -chdir=stacks/network init -backend=false -input=false -no-color
terraform -chdir=stacks/network validate -no-color
terraform -chdir=stacks/security init -backend=false -input=false -no-color
terraform -chdir=stacks/security validate -no-color
terraform -chdir=stacks/workload init -backend=false -input=false -no-color
terraform -chdir=stacks/workload validate -no-color
python .local/review-hygiene.py
git diff --check
git diff --cached --check
git diff main..HEAD --check
```

| Check | Observed result |
|---|---|
| Terraform formatting | Exit 0, no output. All nine template contents also pass terraform fmt -check - through stdin. |
| Environment preflight | PASS: 9 distinct state objects; dev/qa/pdn identities isolated. |
| Root initialization/validation | Three offline initializations succeeded; each validate printed: Success! The configuration is valid. |
| Synthetic boundary checks | Eleven rejection cases passed: encryption, locking, region, domain key, placeholder bucket, account list, KMS account, credential field, shared QA/PDN bucket, shared account and duplicate field. |
| Initialization rendering | Nine printed commands select matching environment/domain configuration and cache, default workspace and reconfigure without migration. No command was executed. |
| Secret/artifact hygiene | Basic changed-file secret-pattern checks and nine ignore-path examples passed; root provider lockfile and template remain eligible for tracking. This is not a dedicated secret scan. |
| Git whitespace | All three diff checks passed without output. |
| TFLint / Checkov / Trivy | SKIPPED: Get-Command tflint,checkov,trivy -ErrorAction SilentlyContinue found none installed. |

The .local helpers and raw logs are ignored local verification artifacts, not a committed CI suite. They were reviewed and executed; no ignored file was force-added. The tracked template preflight is independently reproducible. Existing implementation acceptance is PARTIAL for remote storage, environment isolation and locking, and PASS for no secrets added by the reviewed change. No real backend schema/reachability, IAM, KMS, bucket controls or concurrent locking test was performed.

## Security, limitations and next steps

Authentication follows the existing OIDC/temporary-credential design; no identity resources were created. Recommend exact-object state reads and lockfile read/write/delete for plan roles, separate environment IAM/KMS boundaries and state writes only for a future approved apply role. Sensitive output masking does not remove secrets from state. Versioning, TLS-deny policies, public-access blocking, SSE-KMS and deletion protections are specified as bootstrap prerequisites, not verified cloud controls.

B01 (aroma-pacifico/aroma-pacifico-roadmap#21) remains OPEN and blocking: integrate the root/provider/environment/pipeline baseline and choose the exact CI Terraform patch. A04 (aroma-pacifico/aroma-pacifico-roadmap#4) is closed. SR1/SR2 must reconcile ADR-003's self-hosted bootstrap-state text with this task's prohibition and approve independent bootstrap-state ownership. Actual environment identifiers and backend permissions are absent; PD-019 still needs a decision on permitted account-backed plan evidence. The complete D02 diagram remains unavailable in the inspected baseline.

After B01, resolve those decisions, supply verified configuration through B03, and establish the permitted B11/B13 evidence path. A future live phase requires explicit approval and canonical governance review; current plan-only rules remain intact. Never plan these empty roots against existing workload state, as missing declarations could propose deletions. Rollback is a reviewed code revert; it does not restore/migrate state. No plan was run, so no destroy/replacement proposal was assessed. Keep roadmap issue 22 open and the associated PR in Draft until the blockers and acceptance gaps are resolved.
