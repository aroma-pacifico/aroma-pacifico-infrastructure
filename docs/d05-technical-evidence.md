# D05 / B05 technical evidence

Date: 2026-11-07. Owner: JR2. Status: partial; Draft PR required.
Refs [aroma-pacifico/aroma-pacifico-roadmap#25](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/25).
No cloud deployment, standalone account plan, state migration or state mutation was performed.

## Governance and sources

The canonical constitution in `aroma-pacifico-ai-agents/AGENTS.md` and the
repository-local `AGENTS.md` were read. All seven distributed copies have SHA-256
`21BB66D8A28C2668D15FF617406B797D9316F3BC045A0F01905681FF39DDE229`.
The canonical skill catalog contains `git-agent`, `doc-agent`, and `diagram-agent`.
The first two apply here; the diagram skill was reviewed but no drawing is edited.
No Terraform-specific installed skill or Terraform MCP schema tool was available.

Applicable standards reviewed: `terraform-iac-best-practices.md`, the purposes
and compliance requirements of PC-IAC-001 through PC-IAC-026, `git-workflow.md`,
`documentation.md`, relevant `diagrams.md` requirements, and both Terraform
repositories' `CONTRIBUTING.md`. The resulting controls are typed and validated
inputs, root configuration separate from reusable resource logic, no secrets,
no guessed identifiers, no unversioned module consumption, plan-only tests,
English artifacts, atomic Conventional Commits and cross-repository issue references.
Resource naming, tagging, providers, lockfiles and backend integration remain
requirements for the resource implementation, not completed controls here.

The nine-page case statement was extracted locally with pypdf 7.0.0 and reviewed.
It specifies one center per department, the reserved addressing table, no
Federation infrastructure at Buenaventura, and code for one environment pattern.
Only approved departmental identifiers are used; no municipality is invented.

Architecture revision: `aroma-pacifico-architecture` main
`3f704edde46c433bee0284d58838c23310e089a0`, also confirmed through GitHub.
The following documents supply the design; their existing Proposed metadata
is not changed or treated as a new approval by this implementation.

| Source in architecture repository | Relevant content |
|---|---|
| `docs/adr/adr-001-primary-and-second-cloud.md` | AWS, `us-east-1`, separate environment accounts and VPCs |
| `docs/adr/adr-003-iac-tool-remote-state-and-pattern-module.md` | Thin domain roots, reusable modules, SemVer tags, remote state, plan-only testing |
| `docs/addressing-plan.md`, sections 2 to 4 | Department /16s; dev `10.80.0.0/16`, qa `10.81.0.0/16`, pdn `10.82.0.0/16`; transit tier |
| `docs/collection-center-network.md`, sections 2, 3 and 6 to 10 | Exact center keys, repeated /24 zones, segmentation and WAN behavior |
| `docs/connectivity.md`, sections 9 and 10 | IPsec WAN and backup; Buenaventura is only a transporter application event |
| `docs/firewall-policy.md`, sections 5.1 and 5.2 | Transit Gateway, static routing, certificate customer gateway, prefix lists, environment isolation |
| `docs/landing-zone.md`, section 5.1 | CollectionCenter tag and CostCenter value |
| `docs/architecture.md`, sections 10 and 14; `docs/decision-log.md` | D05 boundary, ASM-051, ASM-120, ASM-121, ASM-200, PD-019, PD-072, PD-120 and PD-122 |

Local and remote diagram inventories contain only the three A13 data-path
Draw.io sources and exports. No D05 or complete-architecture drawing is present.
The D05 box mapping in architecture section 14 is available; visual agreement
with a D05 drawing remains unverified. No diagram or teammate's story is changed.

## GitHub issue and dependency findings

`gh auth status` succeeded using the existing Windows keyring account. The
sandbox account initially returned invalid authentication; running as the
authenticated Windows user resolved it without changing credentials.

| Issue | Exact title | Owner and status | Implementation and dependency conclusion |
|---|---|---|---|
| #25, B05 | [B05] Code the association between the environment and a collection center | JR2; assigned cajire05; Open; 6 h | Exact match to the supplied objective, dependencies, D05 label and four acceptance criteria; no scope discrepancy |
| #24, B04 | [B04] Code the network module for the pattern environment | JR1; assigned kvjc; Open; 10 h | Blocked by B02/B03/A07. No implementation PR was found in issue timeline or either Terraform repository; modules main has governance only. Incomplete and blocks resource integration. |
| #11, A11 | [A11] Design the collection center network pattern | JR1 / SR1; no GitHub assignee; Closed | [Architecture PR #23](https://github.com/aroma-pacifico/aroma-pacifico-architecture/pull/23), merged 2026-11-04. Design dependency delivered; operational inputs remain separate prerequisites. |

B04's objective is the network module for approved addressing. Its acceptance
criteria require seven minimum subnet roles, distinct environment CIDRs,
reusable routing/association outputs, and a plan without overlap with the
three departmental /16s. Those outputs do not exist yet.

A11's objective is one reusable LAN/Wi-Fi pattern for the three centers.
Its acceptance criteria cover a repeated departmental pattern, VLAN/SSID zone
segmentation and guest isolation, reception/code-printing workstations, and
100 Mbps symmetric WAN capacity at 2 Mbps down / 0.5 Mbps up per active client.
The merged document addresses these in sections 2, 3/6, 5 and 7/8 respectively.
Issue checkbox text remains unchecked despite Closed status; implementation
evidence is the merged document, not an assertion that its boxes were updated.

Related merged architecture PRs are #16 (addressing), #21 (connectivity), #27
(firewall), #8 (ADR-001), #10 (ADR-003), and #37 (consolidated architecture).
Neither B04 nor A11 was modified. The module repository's remote tags API
returned `[]`; no release version is assumed.

## Implemented boundary and acceptance status

Only this private infrastructure repository changes. The public modules
repository receives no departmental data or speculative resource definitions.
There is no reusable resource logic yet, so introducing a child module solely
to wrap this project catalog would add an unnecessary abstraction.

| Criterion from B05 | Actual result |
|---|---|
| The code parameterizes the association with a single collection center per run. | Selection portion verified: one required object, one exact key lookup. Actual resource association remains pending. |
| The association respects the addressing block of the corresponding department. | Configuration mapping and conflicting-assertion rejection verified. Resource-level addressing remains pending. |
| The module does not instantiate the 3 centers or any infrastructure in Buenaventura. | Current root has zero infrastructure declarations and zero test resource changes. No connection module exists yet; its future resource graph is not verified. |
| The plan exposes the resources or connections needed for the cloud-to-collection-center link. | Blocked. The only output is configuration, explicitly labeled as such. No real connection or executable account plan is claimed. |

`collection_center` has one required string key and optional department/CIDR
assertions. Missing assertions mean derive from the selected catalog entry;
they never trigger selection of another department. Supplied assertions must
match exactly. `environment` is required and only accepts `pdn` for the
permanent association (ASM-121). These are configuration inputs, not AWS IDs.

| Key | Department | Derived CIDR |
|---|---|---|
| cauca | Cauca | 10.41.0.0/16 |
| huila | Huila | 10.42.0.0/16 |
| tolima | Tolima | 10.43.0.0/16 |

The immutable catalog is not an environment-varying module payload. One direct
lookup produces `selected_center`; no `for_each`, `count`, resource, data source
or child module instantiates catalog entries. Invalid keys produce null only
while Terraform reports the validation error, never a fallback selection.
Terraform object conversion can discard unknown attributes; this is not a
general rejection mechanism for arbitrary extra configuration fields.

## Executed verification

Terraform v1.15.8 on windows_amd64. Python 3.13. Provider-free init needs no AWS
credentials, provider download, provider lockfile or backend. Only native
`terraform test` uses plan operations; every run explicitly declares `command = plan`.

```text
terraform fmt -check -recursive
Exit 0; no output.
terraform -chdir=stacks/network init -backend=false -input=false -no-color
Terraform has been successfully initialized!
terraform -chdir=stacks/network validate -no-color
Success! The configuration is valid.
terraform -chdir=stacks/network test -no-color
Success! 9 passed, 0 failed.
python scripts/verify-d05.py
PASS cauca: one selected object, 10.41.0.0/16, zero resource changes
PASS huila: one selected object, 10.42.0.0/16, zero resource changes
PASS tolima: one selected object, 10.43.0.0/16, zero resource changes
PASS native Terraform scenarios: 9 passed, 0 failed
PASS multi_center_list: rejected (Invalid value for input variable)
PASS multi_center_keys: rejected (Invalid value for input variable)
PASS missing_center: rejected (No value for required variable)
PASS missing_environment: rejected (No value for required variable)
PASS missing_center_key: rejected (Invalid value for input variable)
PASS null_center: rejected (Required variable not set)
BLOCKED missing operational connectivity input: no AWS connection module yet
PASS contract boundary: zero infrastructure blocks, no state created by tests
.local/d05-bin/tflint.exe --chdir=stacks/network --format=compact
Exit 0; no findings. TFLint v0.65.0.
```

The Python verifier reads native JSON plan events, checks exact output equality
for all three centers and absence of resource changes, then runs six invalid
fixtures in an isolated temporary directory. It requires error exit status AND
the expected Terraform diagnostic. A separate python-hcl2 8.1.4 parse verified
all five HCL files and absence of infrastructure blocks. Parser packages and
downloaded tools remain ignored local verification aids, not project dependencies.

| Requested scenario | Executed evidence and limit |
|---|---|
| Cauca, Huila, Tolima | Three native plan-mode tests and JSON event checks; one selected object each, correct /16, no resources or other center instances |
| Unknown identifier | Native expected validation failure |
| Incorrect department | Cauca key with Huila assertion rejected |
| Incorrect department CIDR | Cauca key with Huila /16 assertion rejected |
| Missing mandatory connectivity input | Blocked: operational connection inputs/module do not exist. Missing selection/environment/key rejection tests do not substitute for this scenario. |
| Implicit multi-center deployment | Three-center object list and list-valued key rejected by Terraform types |
| Buenaventura infrastructure | Buenaventura key rejected; parsed root has no infrastructure declarations; all valid test plans have zero resource changes |
| Environment isolation | Native dev and qa rejection tests; no implicit temporary acceptance route |

Trivy v0.76.2 was downloaded from the official release, like TFLint, and its
published SHA-256 checksum verified. The final scan used this ignored local
fixture: `environment = "pdn"`, `collection_center = { key = "cauca" }`.

```text
.local/d05-bin/trivy.exe config --cache-dir .local/d05-trivy-cache --disable-telemetry --misconfig-scanners terraform --tf-vars .local/d05-scan.tfvars --exit-code 1 --format json --output .local/d05-trivy-final.json --timeout 45s stacks/network
Exit 0. Detected config files: 1. MisconfSummary: Successes 51, Failures 0.
git diff --check
Exit 0; no output.
python .local/d05-hygiene.py
PASS hygiene: 11 files, 5 relative links, zero emoji or credential-pattern matches, zero state files
```

An initial scan without variables returned exit 0 with a missing-input warning.
A follow-up failed because shell quoting prevented its fixture from being
written; that failed invocation's existing report was not used as new evidence.
After writing the fixture directly, the final scan above returned exit 0
without the missing-input warning. Checkov was unavailable; Trivy satisfies
the alternative scanner requirement. These 51 scanner checks concern a root
with no resources; they do not establish security of the unimplemented VPN.

## Remaining integration and future plan

ASM-200 assigns D05 the Transit Gateway VPC attachment, VPN connections,
customer gateways and prefix lists. B04 owns VPC/subnet/endpoint foundations;
B07 owns Transit Gateway routing policy and firewall rules. The approved
pattern is one selected departmental firewall over IPsec/IKEv2, two tunnels,
static routes, certificate-based customer gateway, network-account hub and
environment transit subnets. No BGP relationship or public customer IP is invented.
The [AWS customer gateway documentation](https://docs.aws.amazon.com/vpn/latest/s2svpn/cgw-options.html)
was checked: certificate authentication requires a supplied private certificate;
an IP is not required for the certificate-authenticated public VPN option.
This focused check does not close B04's broader PD-120 feature review.

Missing integration inputs are actual B04 outputs, agreed hub ownership and
cross-account/provider wiring, certificate reference/lifecycle, root naming/tag
values from B01/B03, a released reusable module, and verified B02 remote backend
and plan identity. PD-072 and PD-122 remain open. No cloud identifiers, private
keys, endpoint addresses or preshared keys are committed.

ASM-051 limits executable account evidence to `qa`; ASM-121 prohibits permanent
qa center connectivity. B07 and the design owner must reconcile the explicitly
temporary logistics acceptance path before any connected qa plan. Do not remove
the permanent-link validation just to make the qa plan run. PD-019 still needs
the approved executable-plan evidence model. The pdn test values here never
target an account. B05 remains incomplete after this PR.

Once B01/B02/B03/B04 and the QA exception are integrated and the evidence model
is approved, the account-plan procedure will be:

```text
terraform -chdir=stacks/network init -backend-config=backends/qa.s3.tfbackend
terraform -chdir=stacks/network plan -input=false -var-file=qa.tfvars -out=qa.tfplan
```

These are future commands, not executed commands. The backend/variable files
and temporary-acceptance interface must first be supplied by their owners.
The expected resource families above come from architecture, not plan output.
No resource creates, destroys or replacements are inferred for a future plan.
No apply, destroy, force-unlock or state migration is part of this task.

## Review and rollback

Review the [root guide](../stacks/network/README.md) and
[verifier](../scripts/verify-d05.py). Reverting these commits removes only the
configuration contract and documentation; no cloud rollback exists to perform.
The PR exceeds the approximate 400-line target because reproducible evidence
and negative tests are included in the requested independent review package.
The D02 feature branch and all other repositories remain untouched.

## Publication blocker

The authorized push of `feat/25-single-center-association` failed with HTTP 403:
`Write access to repository not granted.` No PR was created. GitHub's repository
API confirms that the authenticated `cajire05` account has `pull: true` and
`push: false` on infrastructure and roadmap. This is a repository permission
blocker despite valid CLI authentication. No fork, alternate identity, main
push or permission change was attempted.

The verified implementation remains on the local feature branch. A Draft PR
body using the repository template is prepared under ignored
`.local/d05-pr-body.md`. Publication requires repository write access for this
account or an authorized maintainer publishing these reviewed commits. The
story must remain open, and any resulting PR must remain Draft while the
resource association and cloud-link plan acceptance criteria are incomplete.

The authorized [B05 progress comment and sanitized evidence snapshot](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/25#issuecomment-6713583133)
were published successfully. This is the available remote evidence link; the
repository document and implementation commits remain local pending push access.
