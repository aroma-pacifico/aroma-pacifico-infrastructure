#!/usr/bin/env bash
# Fail when a variable or backend file under environments/ looks like it holds
# a secret (B03, PC-IAC-016). Checks tracked example files and any local copy.
# Usage: scripts/check-env-secrets.sh [directory]   (default: environments)
set -euo pipefail

dir="${1:-environments}"
status=0

# Assignments whose key name suggests a secret value.
key_pattern='^[[:space:]]*[A-Za-z0-9_]*(password|passwd|secret|token|api_key|apikey|private_key|access_key|credential)[A-Za-z0-9_]*[[:space:]]*='
# Known credential shapes: AWS access key IDs, private key blocks, 12-digit account IDs.
value_pattern='AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|(^|[^0-9])[0-9]{12}([^0-9]|$)'

while IFS= read -r -d '' file; do
  # Ignore comment-only lines so guidance text can name the forbidden words.
  body="$(grep -vE '^[[:space:]]*(#|//)' "$file" || true)"
  # The all-zero account is the fixed synthetic value of the Floci emulator
  # (PC-IAC-028): it names no account, so it is not reported.
  body="$(sed -E 's/(^|[^0-9])0{12}([^0-9]|$)/\1\2/g' <<<"$body")"
  if grep -qiE "$key_pattern" <<<"$body"; then
    echo "ERROR: $file assigns a secret-looking key" >&2
    status=1
  fi
  if grep -qE "$value_pattern" <<<"$body"; then
    echo "ERROR: $file contains a credential, key block or account identifier" >&2
    status=1
  fi
done < <(find "$dir" -type f \( -name '*.tfvars' -o -name '*.tfvars.json' -o -name '*.tfbackend' -o -name '*.example' \) -print0)

if [ "$status" -eq 0 ]; then
  echo "SUCCESS: no secret-looking content under $dir"
fi
exit "$status"
