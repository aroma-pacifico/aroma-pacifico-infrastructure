# Troubleshooting log

## B02 resource and launcher refresh (2026-11-10)

The managed launcher overwrites TF_DATA_DIR using only the absolute root path.
It creates/checks operational registrations before selecting validation mode.
Repository preflight now requires dedicated environment checkouts and verifies
the effective route without executing the launcher. Real offline checks used
a checksum-identical isolated launcher copy with disposable registrations;
shared launcher files/caches/registrations were not modified.

Initial provider installation failed because the separate plugin cache had no
AWS 6.0.0 package. Retrying with an existing read-only provider directory and
the retained root lock succeeded. A local mirror is not registry authentication.
Initial policy expression validation exposed heterogeneous tuple inference;
normalizing the conditional statements through JSON fixed it. Negative tests
were adjusted for Terraform's dependent-validation short circuit, preserving
the intended rejection. An inactive single-line backend block failed formatting;
it was expanded and all twenty inactive HCL examples were formatted. The final
suite passed every functional check. Trivy exits 1 for missing S3 access logging;
the approved destination is an unresolved dependency and is not fabricated.

Windows subprocess calls also required executable paths resolved against the
intended working directory. No failed attempt contacted a live AWS backend.

## D02 discovery and offline verification (2026-11-06)

**Context and symptom:** Git refused the user-owned repositories as dubious
ownership in the sandbox; its global ignore file was also unreadable. GitHub
reads failed with a sandbox socket restriction. The first `gh --jq` query lost
quoting through Windows argument parsing. PDF extraction first failed because
the temporary reader package was inaccessible in the sandbox, then because the
default terminal encoding could not represent PDF ligatures.

**Root cause:** Different sandbox/user identities, restricted network access,
Windows native argument quoting and CP1252 stdout; none was a Terraform failure.

**Resolution:** Use per-command `git -c safe.directory=<exact-repository>` and
`-c core.excludesFile=<repository>/.gitignore`, without changing global trust.
Read GitHub with reviewed network escalation and structured JSON without jq.
Read the installed temporary PDF package with escalation and `python -X utf8`.

**Preventive architecture:** Keep backend validation offline and use structured
configuration with explicit environment/account checks. No Terraform backend
request, deployment or state migration was needed to resolve these local issues.
