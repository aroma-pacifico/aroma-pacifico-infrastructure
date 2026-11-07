# Troubleshooting log

## D05 local verification context (2026-11-07)

**Context and symptom:** `gh auth status` returned invalid authentication and
Git refused repository ownership under the sandbox Windows account. TFLint,
Checkov and Trivy were initially absent. PowerShell release queries failed with
an unexpected connection receive error in the sandbox.

**Root cause:** The sandbox identity has a separate keyring and owns none of
the user's repositories. Tool availability and network behavior differ between
the sandbox and the authenticated Windows user.

**Resolution applied:** Repeated GitHub/Git access and failed release queries
with approved execution as the authenticated user. No credentials or global
safe-directory settings were changed. Local tool binaries are downloaded from
official releases and checked against their published SHA-256 checksums.
An initial Python package installation produced no progress and was stopped;
retrying with bounded network timeouts installed the PDF/HCL readers locally.
PowerShell-to-gh jq quoting errors were corrected by selecting JSON fields in
PowerShell, and a console encoding error by rendering source excerpts as ASCII.

**Preventive architecture:** Keep verification aids under ignored `.local/`,
use structured JSON with bounded output for evidence, and distinguish absent
tools from executed checks. The tracked D05 verifier uses only Python's
standard library and Terraform, with explicit plan-only fixtures and timeouts.

## D05 security scan fixture

**Context and symptom:** Trivy warned that required variables were absent.
A follow-up command failed because Python inline-code quoting prevented the
local fixture from being written, and the scanner reported a missing file.

**Root cause:** Static configuration scanning needs variable values; Windows
PowerShell argument quoting altered embedded Python string literals.

**Resolution applied:** Wrote the ignored fixture directly and reran Trivy to
a new report path. The final scan exited 0 with 51 successes and zero failures,
without the missing-variable warning.

**Preventive architecture:** Use files for structured multiline inputs and
gate report consumption on command success. An older report is not evidence
for a later failed invocation.

## D05 GitHub publication permissions

**Context and symptom:** The authorized feature-branch push failed with HTTP
403, `Write access to repository not granted`, despite successful CLI login.

**Root cause:** GitHub reports `pull: true` and `push: false` for the authenticated
account on the infrastructure repository.

**Resolution applied:** Preserved the commits locally and prepared the Draft
PR body. Published the authorized progress comment and sanitized evidence on
roadmap issue #25, which remained open. No PR was created.

**Preventive architecture:** Verify repository write access before publication;
valid authentication alone does not establish push permission. A maintainer must
restore access or publish the reviewed commits through the normal PR workflow.
