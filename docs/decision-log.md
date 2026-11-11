# D02 implementation decision register

Date: 2026-11-06. Owner: JR2. Refs aroma-pacifico/aroma-pacifico-roadmap#22.
This scoped register records blockers for review; it does not replace or amend
the architecture repository's canonical `docs/decision-log.md` or accepted ADRs.
No new account, bucket name, role, retention period or deployment approval is assumed.

| ID | Status | Decision or dependency requiring follow-up |
|---|---|---|
| PD-B02-001 | Superseded by merged design; implementation incomplete | ADR-003 and A20/ASM-213 assign the state bucket/key to B02 in stacks/state-backend and design self-hosted state after migration. Independent external state is not an approved requirement. Reusable resource code, bootstrap-root wiring, a real module release and an authorized execution procedure are absent; no migration is allowed in this task. |
| PD-B02-002 | Open | B01 (aroma-pacifico/aroma-pacifico-roadmap#21) remains open; it must complete root/provider/environment/CI baseline, choose the exact Terraform CI patch >= 1.14.0 and integrate these backend-only domain scaffolds. No provider patch is guessed here. |
| PD-B02-003 | Open | Backend owner must supply verified distinct environment account IDs, bucket names, state CMK ARNs and evidence of versioning, TLS enforcement, public-access blocks, recovery protections and IAM. |
| PD-B02-004 | Open | A19's D02 diagram source/export is absent locally and in the remote diagrams main tree. Architecture section 14 maps D02 to B02, but visual conformance remains unverified. |

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
