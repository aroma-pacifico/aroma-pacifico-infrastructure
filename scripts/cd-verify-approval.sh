#!/usr/bin/env bash
# Second step of the production approval (B12, ASM-172, PD-020).
#
# GitHub Free does not offer required reviewers on an Environment of a private
# repository, so the approval is a second, separate run of the CD promotion
# workflow. The first run (promotion mode) ends after the review and publishes
# the plan digest. The approver then dispatches the workflow again with
# approve_run_id and approve_digest, and this script decides whether that
# approval is valid. Nothing is applied or deployed: the project is plan-only.
#
# The approval is valid only when ALL of these hold:
#   1. the triggering actor is listed in PDN_APPROVERS (roles SR1 or SR2);
#   2. the approver is not the requester of the reviewed run;
#   3. the reviewed run is a successful dispatch of CD promotion on main for the
#      same commit as this run, so main has not moved since the review;
#   4. approve_digest equals the SHA-256 digest recomputed from the plan manifest
#      artifact of the reviewed run;
#   5. the change window check passes with the release note and incident
#      reference stored by the reviewed run;
#   6. approve_run_id is numeric and approve_digest is 64 hex characters.
#
# Environment (all required unless a default is shown):
#   GH_TOKEN, GITHUB_REPOSITORY, GITHUB_SHA, GITHUB_RUN_ID   GitHub runner values
#   ACTOR               Login that triggered this run (github.triggering_actor)
#   PDN_APPROVERS       Comma separated logins allowed to approve (may be empty)
#   APPROVE_RUN_ID      Run ID of the reviewed run
#   APPROVE_DIGEST      Plan digest shown by the reviewed run
#   HARVEST_WEEK_DATES  Read by cd-window-check.sh (optional)
#   GITHUB_SERVER_URL   Default https://github.com
#   OUT_DIR             Where approval-record-pdn.json is written (default .)
#   PYTHON              Python interpreter for JSON (default python3)
#
# Exits 0 when the approval is valid, 1 with an ::error:: line otherwise.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
py="${PYTHON:-python3}"
server="${GITHUB_SERVER_URL:-https://github.com}"
out_dir="${OUT_DIR:-.}"
fail() { echo "::error::Approval refused: $*"; exit 1; }

: "${GITHUB_REPOSITORY:?}" "${GITHUB_SHA:?}" "${GITHUB_RUN_ID:?}"
actor="${ACTOR:-}"
run_id="${APPROVE_RUN_ID:-}"
digest_in="${APPROVE_DIGEST:-}"

# 6. Validate the inputs before any use.
printf '%s' "$run_id" | grep -qE '^[1-9][0-9]{0,17}$' || fail "approve_run_id must be the numeric ID of the reviewed run."
printf '%s' "$digest_in" | grep -qE '^[0-9a-fA-F]{64}$' || fail "approve_digest must be 64 hexadecimal characters."
[ "$run_id" != "$GITHUB_RUN_ID" ] || fail "approve_run_id must be the review run, not this approval run."
[ -n "$actor" ] || fail "the triggering actor is unknown."
digest_in="$(printf '%s' "$digest_in" | tr 'A-F' 'a-f')"

# 1. The approver must be listed in PDN_APPROVERS.
if [ -z "$(printf '%s' "${PDN_APPROVERS:-}" | tr -d '[:space:]')" ]; then
  fail "the repository variable PDN_APPROVERS is empty or not set, so nobody can approve production."
fi
actor_lc="$(printf '%s' "$actor" | tr 'A-Z' 'a-z')"
if ! printf '%s' "$PDN_APPROVERS" | tr ',' '\n' | tr -d '[:blank:]' | tr 'A-Z' 'a-z' | grep -Fxq -- "$actor_lc"; then
  fail "$actor is not listed in PDN_APPROVERS (roles SR1 or SR2, ASM-172)."
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 3. The reviewed run: right workflow, event, result, branch and commit.
gh api "repos/$GITHUB_REPOSITORY/actions/runs/$run_id" > "$work/run.json" 2>/dev/null \
  || fail "run $run_id was not found in $GITHUB_REPOSITORY."
facts="$(RUN_JSON="$work/run.json" "$py" -I -c '
import json, os, sys
r = json.load(open(os.environ["RUN_JSON"]))
repo = os.environ["GITHUB_REPOSITORY"].lower()
want = {"name": "CD promotion", "event": "workflow_dispatch", "status": "completed",
        "conclusion": "success", "head_branch": "main", "head_sha": os.environ["GITHUB_SHA"]}
errs = ["%s is %r, expected %r" % (k, r.get(k), v) for k, v in want.items() if r.get(k) != v]
for key in ("repository", "head_repository"):
    name = ((r.get(key) or {}).get("full_name") or "").lower()
    if name != repo:
        errs.append("%s is %r, expected %r" % (key, name, repo))
if errs:
    print("; ".join(errs), file=sys.stderr)
    sys.exit(1)
login = lambda k: ((r.get(k) or {}).get("login") or "")
print(login("actor") + "\t" + login("triggering_actor"))
')" || fail "run $run_id is not an acceptable review: see the reasons above, and note that main must still be at the reviewed commit."
IFS=$'\t' read -r run_actor run_trigger <<< "$facts"

# Artifacts of the reviewed run: the plan manifest and the review context.
gh run download "$run_id" -R "$GITHUB_REPOSITORY" -n plan-pdn -D "$work/plan-pdn" >/dev/null 2>&1 \
  || fail "could not download the artifact plan-pdn of run $run_id (missing or expired after 7 days)."
gh run download "$run_id" -R "$GITHUB_REPOSITORY" -n review-context-pdn -D "$work/context" >/dev/null 2>&1 \
  || fail "could not download the artifact review-context-pdn of run $run_id (missing or expired after 7 days)."
ctx() {
  "$py" -I -c 'import json, sys
v = json.load(open(sys.argv[1])).get(sys.argv[2], "")
print(v if isinstance(v, str) else "")' "$work/context/review-context.json" "$1" 2>/dev/null || true
}

# 4. The digest is recomputed from the manifest, never taken from the input alone.
(cd "$work/plan-pdn" && sha256sum --check --strict SHA256SUMS >/dev/null 2>&1) \
  || fail "the plan files of run $run_id do not match their SHA256SUMS manifest."
digest="$(sha256sum "$work/plan-pdn/SHA256SUMS" | cut -d' ' -f1)"
[ "$digest" = "$digest_in" ] || fail "approve_digest does not match the plan digest recomputed from run $run_id."

requester="$(ctx requester)"
note="$(ctx release_note_url)"
incident="$(ctx incident_reference)"
[ -n "$requester" ] || fail "the review context of run $run_id has no requester."
[ "$(ctx promote_to)" = pdn ] || fail "run $run_id did not review a promotion to pdn."
[ "$(ctx commit)" = "$GITHUB_SHA" ] || fail "the review context commit differs from this commit."
[ "$(ctx plan_digest)" = "$digest" ] || fail "the review context digest differs from the recomputed digest."

# 2. Four eyes: the approver is neither the requester nor the actor of the review run.
for who in "$requester" "$run_actor" "$run_trigger"; do
  [ -n "$who" ] || continue
  [ "$(printf '%s' "$who" | tr 'A-Z' 'a-z')" != "$actor_lc" ] \
    || fail "$actor requested run $run_id and cannot approve it (ASM-172 asks for a different person)."
done

# 5. Change window re-check at approval time, with the stored note and incident.
if [ -z "$incident" ]; then
  case "$note" in https://*) ;; *) fail "the review run has neither an https release note nor an incident reference." ;; esac
fi
window_rc=0
GITHUB_OUTPUT="$work/window.out" INCIDENT_REFERENCE="$incident" bash "$here/cd-window-check.sh" || window_rc=$?
[ "$window_rc" -eq 0 ] || fail "the change window is blocked (see above); an incident reference on the review run overrides it."
window="$(grep '^window_status=' "$work/window.out" | tail -1 | cut -d= -f2)"

# Approved: write the record and the job summary. Nothing is applied.
mkdir -p "$out_dir"
export REQUESTER="$requester" APPROVER="$actor" NOTE="$note" INCIDENT="$incident" DIGEST="$digest" WINDOW="$window"
export REVIEW_URL="$server/$GITHUB_REPOSITORY/actions/runs/$run_id"
export APPROVAL_URL="$server/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
export CHECKED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)" RECORD="$out_dir/approval-record-pdn.json" SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
"$py" -I -c '
import json, os
e = os.environ
clean = lambda s: s.replace("|", "/").replace("\r", " ").replace("\n", " ")
rec = {"result": "approved", "nothing_applied": True, "requester": e["REQUESTER"], "approver": e["APPROVER"],
       "review_run": e["REVIEW_URL"], "approval_run": e["APPROVAL_URL"], "commit": e["GITHUB_SHA"],
       "plan_digest": e["DIGEST"], "release_note": e["NOTE"], "incident_reference": e["INCIDENT"],
       "window_status": e["WINDOW"], "approval_checked_at_utc": e["CHECKED_AT"]}
json.dump(rec, open(e["RECORD"], "w"), indent=2)
rows = [("Requester", e["REQUESTER"]), ("Approver", e["APPROVER"]), ("Review run", e["REVIEW_URL"]),
        ("Approval run", e["APPROVAL_URL"]), ("Commit", "`%s`" % e["GITHUB_SHA"]),
        ("Plan digest", "`%s`" % e["DIGEST"]), ("Release note", clean(e["NOTE"]) or "none"),
        ("Incident reference", clean(e["INCIDENT"]) or "none"), ("Change window", e["WINDOW"]),
        ("Approval checked at (UTC)", e["CHECKED_AT"])]
with open(e["SUMMARY"], "a") as s:
    s.write("## Production approval record (plan-only, nothing applied)\n\n| Item | Value |\n|---|---|\n")
    s.writelines("| %s | %s |\n" % row for row in rows)
    s.write("\nThe approver is listed in PDN_APPROVERS, differs from the requester, and the digest above was "
            "recomputed from the plan of the review run. Nothing was applied or deployed.\n")
'
echo "Approval valid: $actor approved the plan digest $digest of run $run_id."
