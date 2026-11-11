# D02 implementation decision register

Date: 2026-11-06. Owner: JR2. Refs aroma-pacifico/aroma-pacifico-roadmap#22.
This scoped register records blockers for review; it does not replace or amend
the architecture repository's canonical `docs/decision-log.md` or accepted ADRs.
No new account, bucket name, role, retention period or deployment approval is assumed.

| ID | Status | Decision or dependency requiring follow-up |
|---|---|---|
| PD-B02-001 | Resource code and offline composition implemented; execution blocked | ADR-003 and A20/ASM-213 assign the state bucket/key to B02 in stacks/state-backend and design self-hosted state after migration. The reusable eight-resource module, inactive private release template and mock-only root composition now exist. A real reviewed module release, B01/B03/B06 contracts and an authorized bootstrap/migration procedure remain absent. No migration is allowed in this task. |
| PD-B02-002 | Open | B01 (aroma-pacifico/aroma-pacifico-roadmap#21) remains open; it must complete root/provider/environment/CI baseline, choose the exact Terraform CI patch >= 1.14.0 and integrate these backend-only domain scaffolds. No provider patch is guessed here. |
| PD-B02-003 | Open | Backend owner must supply verified distinct environment account IDs, bucket names, state CMK ARNs and evidence of versioning, TLS enforcement, public-access blocks, recovery protections and IAM. |
| PD-B02-004 | Open | A19's D02 diagram source/export is absent locally and in the remote diagrams main tree. Architecture section 14 maps D02 to B02, but visual conformance remains unverified. |
| PD-B02-005 | Repository mitigation implemented; tooling integration blocked | The approved launcher ignores incoming TF_DATA_DIR and hashes only root path. Require dedicated environments/<environment> checkouts, reviewed launcher fingerprints, pre-existing matching registrations and cached backend checks. Shared launcher/registrations remain unchanged. Maintainer registration and end-to-end verification are still needed. |
| PD-B02-006 | Open integration contract | B06/platform owner must provide the approved S3 audit/access-logging destination and permissions; the resource module does not invent an audit bucket. Trivy AWS-0089 remains visible. |

A04 (aroma-pacifico/aroma-pacifico-roadmap#4) is closed and ADR-003 accepted. Its environment/domain isolation, KMS,
native locking and `us-east-1` choices are reused. The architecture's PD-019 is
still open: decide real plan evidence with pre-existing human-provisioned backend
versus mocked plan-mode tests. ASM-051 permits the executable account plan only
for `qa`; no production account plan is requested or run.

Future live creation and deployment require a separately approved phase and a
canonical governance amendment reviewed in `aroma-pacifico-ai-agents`, followed
by normal rule synchronization. This task does not authorize or perform that
amendment. Transfer these blocker references into the master register through
the architecture owner's normal review; unrelated repositories remain unchanged.
