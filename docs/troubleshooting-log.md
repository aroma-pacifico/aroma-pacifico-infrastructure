# Troubleshooting log

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
