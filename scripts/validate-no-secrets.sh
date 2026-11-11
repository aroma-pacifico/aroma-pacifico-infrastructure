#!/usr/bin/env bash
# Secret and state validation for the whole repository (B13, PC-IAC-016).
#
# 1. No state, plan, key or credential file was ever committed: every path in
#    the full history of every ref is checked against forbidden name patterns.
# 2. gitleaks scans the full git history of every ref.
# 3. gitleaks scans the plan JSON and text produced by scripts/plan-all.sh.
#
# Usage: scripts/validate-no-secrets.sh [plan-output-dir]
#   plan-output-dir  default plan-all-output; skipped when it does not exist.
# Requires gitleaks on PATH (CI installs a checksum-pinned release).
# Exit status: 0 clean, 1 finding.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
plan_dir="${1:-plan-all-output}"
status=0

command -v gitleaks > /dev/null || { echo "ERROR: gitleaks is required" >&2; exit 2; }

echo "== forbidden file names in the full history"
# Example files (*.example) are allowed; real variable, backend, state and key files are not.
forbidden='(^|/)(terraform\.tfstate(\.backup)?|[^/]*\.tfstate(\.[^/]*)?|[^/]*\.tfplan|tfplan|[^/]*\.plan(\.json)?|\.envrc|\.env(\.[^/]*)?|[^/]*\.pem|[^/]*\.key|[^/]*(credentials|accessKeys)[^/]*\.csv|[^/]*\.auto\.tfvars|[^/]*\.tfvars(\.json)?|[^/]*\.tfbackend)$'
# stacks/<stack>/emulator.tfvars is the one allowed exception: synthetic Floci
# fixtures with the all-zero account (PC-IAC-028), checked by check-env-secrets.sh.
hits="$(git log --all --pretty=format: --name-only | sort -u | grep -E "$forbidden" | grep -vE '^stacks/[a-z-]+/emulator\.tfvars$' || true)"
if [ -n "$hits" ]; then
  echo "ERROR: forbidden file names appear in history:" >&2
  echo "$hits" >&2
  status=1
else
  echo "SUCCESS: no state, plan, key, credential or real variable file in history"
fi

echo "== gitleaks over the full history"
if gitleaks git . --no-banner --redact --log-opts="--all"; then
  echo "SUCCESS: gitleaks found no leak in history"
else
  status=1
fi

echo "== gitleaks over the plan output"
if [ -d "$plan_dir" ]; then
  if gitleaks dir "$plan_dir" --no-banner --redact; then
    echo "SUCCESS: gitleaks found no leak in $plan_dir"
  else
    status=1
  fi
else
  echo "SKIPPED: $plan_dir does not exist (run scripts/plan-all.sh first)"
fi

exit "$status"
