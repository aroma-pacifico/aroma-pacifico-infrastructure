#!/usr/bin/env bash
# End-to-end speculative plan of the pattern environment (B13, box D13).
#
# Plans the four root stacks in dependency order (state-backend, network,
# security, workload) against the Floci AWS emulator with the example variable
# files (PC-IAC-028), and collects one summary per stack: resources to add,
# change and destroy. When Infracost credentials are present it also collects
# the monthly cost per stack (PC-IAC-027); otherwise it says "estimate
# unavailable" and never prints a placeholder figure.
#
# Plan-only: this script never runs apply or destroy and creates nothing outside
# the emulator. A stack whose wiring is still pending is planned with what exists
# today and reported as PENDING, not as FAILED. Pending is detected from the
# stack files, so the note disappears by itself when the wiring merges.
#
# Usage: scripts/plan-all.sh [--out DIR] [--env qa]
#   --out DIR   output directory (default: plan-all-output)
#   --env NAME  example variable file to plan, dev, qa or pdn (default: qa)
#
# Requires: terraform, aws CLI, jq, and a running Floci on $AWS_ENDPOINT_URL
# (default http://localhost:4566). Optional: infracost with
# INFRACOST_CLI_AUTHENTICATION_TOKEN and INFRACOST_ORG.
#
# Exit status: 0 when every stack produced a plan, 1 when any stack failed.
set -euo pipefail

out="plan-all-output"
env_name="qa"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --out) out="$2"; shift 2 ;;
    --env) env_name="$2"; shift 2 ;;
    -h | --help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown argument $1" >&2; exit 2 ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# Fixed emulator values of PC-IAC-028. They are not credentials.
export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export TF_IN_AUTOMATION=true
# Fictitious value so stacks wired to modules/network can plan; it is not an account.
export TF_VAR_organization_id="${TF_VAR_organization_id:-o-a1b2c3d4e5}"

stacks=(state-backend network security workload)
var_file="../../environments/${env_name}/${env_name}.tfvars.example"
state_bucket="floci-plan-all-state"

[ -f "environments/${env_name}/${env_name}.tfvars.example" ] || {
  echo "ERROR: environments/${env_name}/${env_name}.tfvars.example not found" >&2
  exit 2
}
for tool in terraform aws jq; do
  command -v "$tool" > /dev/null || { echo "ERROR: $tool is required" >&2; exit 2; }
done

mkdir -p "$out"
out="$(cd "$out" && pwd)"
rm -f "$out"/*.txt "$out"/*.json "$out"/*.md "$out"/*.tfplan

# Wiring that a stack still lacks, one line per missing module. Each check looks
# for the module source in the stack files, so it clears when the wiring lands.
pending_notes() {
  local stack="$1" files
  files=("stacks/$stack"/*.tf)
  has() { grep -qE "modules/$1\?ref=" "${files[@]}" 2> /dev/null; }
  case "$stack" in
    network) has firewall-rules || echo "B07b: firewall rules module (D07) not wired in this stack yet" ;;
    security) has security || echo "B06b: security module (D06) not wired in this stack yet" ;;
    workload)
      has farm || echo "B08b: farm module (D08) not wired in this stack yet"
      has telemetry-ingestion || echo "B09b: telemetry ingestion module (D09) not wired in this stack yet"
      ;;
  esac
}

# Counts of a plan JSON: replacements count as one add and one destroy, like the
# "Plan:" line of terraform.
counts() {
  jq -c '[.resource_changes[]? | .change.actions] as $a | {
    add: ([$a[] | select(index("create"))] | length),
    change: ([$a[] | select(. == ["update"])] | length),
    destroy: ([$a[] | select(index("delete"))] | length),
    replace: ([$a[] | select(index("create") and index("delete"))] | length),
    total: ($a | length)
  }' "$1"
}

# The emulator enforces IAM, so the fictitious plan roles named by a stack's
# emulator.tfvars are created inside it. No real role or account is involved.
create_plan_roles() {
  local file="stacks/$1/emulator.tfvars" trust arn
  [ -f "$file" ] || return 0
  trust='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"*"},"Action":"sts:AssumeRole"}]}'
  grep -oE 'arn:aws:iam::[0-9]{12}:role/[A-Za-z0-9_-]+' "$file" | sort -u | while read -r arn; do
    aws iam create-role --role-name "${arn##*/}" --assume-role-policy-document "$trust" > /dev/null 2>&1 || true
  done
}

# plan_one STACK LABEL [extra -var-file arguments...]
# Writes $out/plan-STACK-LABEL.{txt,json}; prints the counts JSON; returns 1 on failure.
plan_one() {
  local stack="$1" label="$2"
  shift 2
  local base="$out/plan-$stack-$label"
  terraform -chdir="stacks/$stack" init -reconfigure -input=false -no-color \
    -backend-config="bucket=$state_bucket" \
    -backend-config="key=$stack/terraform.tfstate" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="use_path_style=true" \
    -backend-config="skip_credentials_validation=true" \
    -backend-config="skip_requesting_account_id=true" \
    -backend-config="skip_metadata_api_check=true" > "$base.init.txt" 2>&1 || return 1
  terraform -chdir="stacks/$stack" plan -lock=false -input=false -no-color \
    -out="$base.tfplan" "$@" > "$base.txt" 2>&1 || return 1
  terraform -chdir="stacks/$stack" show -json "$base.tfplan" > "$base.json" 2> /dev/null || return 1
  rm -f "$base.tfplan" "$base.init.txt"
  counts "$base.json"
}

aws s3 mb "s3://$state_bucket" > /dev/null 2>&1 || true

results="$out/results.ndjson"
: > "$results"
failed=0

for stack in "${stacks[@]}"; do
  create_plan_roles "$stack"
  notes="$(pending_notes "$stack" | paste -sd ';' - | sed 's/;/; /g')"

  runs=("$env_name|-var-file=$var_file")
  # Permanent center links exist only in pdn (ASM-121), so a stack with
  # emulator fixtures gets a second plan: the pdn example plus those fixtures.
  if [ -f "stacks/$stack/emulator.tfvars" ]; then
    runs+=("pdn-fixtures|-var-file=../../environments/pdn/pdn.tfvars.example|-var-file=emulator.tfvars")
  fi

  for run in "${runs[@]}"; do
    IFS='|' read -r -a parts <<< "$run"
    label="${parts[0]}"
    args=("${parts[@]:1}")
    echo "== plan $stack ($label)"
    if summary="$(plan_one "$stack" "$label" "${args[@]}")"; then
      status="PLANNED"
      [ -n "$notes" ] && status="PENDING"
    else
      status="FAILED"
      summary='{"add":0,"change":0,"destroy":0,"replace":0,"total":0}'
      failed=1
      echo "ERROR: plan of $stack ($label) failed; last lines follow" >&2
      tail -n 15 "$out/plan-$stack-$label.txt" >&2 || tail -n 15 "$out/plan-$stack-$label.init.txt" >&2 || true
    fi
    jq -cn --arg stack "$stack" --arg label "$label" --arg status "$status" \
      --arg notes "$notes" --argjson counts "$summary" \
      '{stack: $stack, variables: $label, status: $status, pending: $notes} + $counts' >> "$results"
  done
done

# Cost per stack. Infracost needs a token and the approved metadata egress; any
# missing piece yields "estimate unavailable", never a made-up number.
cost_json="$out/infracost.json"
cost_state="unavailable"
if command -v infracost > /dev/null \
  && [ -n "${INFRACOST_CLI_AUTHENTICATION_TOKEN:-}" ] \
  && [ -n "${INFRACOST_ORG:-}" ] \
  && [ "${INFRACOST_METADATA_EGRESS_APPROVED:-}" = "true" ]; then
  if infracost scan . --org "$INFRACOST_ORG" --currency USD --json --no-color \
    --access-token-use-cache=false > "$cost_json" 2> "$out/infracost.err"; then
    cost_state="available"
  fi
fi

{
  echo "### End-to-end plan of the pattern environment (Floci emulator)"
  echo
  echo "Variables: \`environments/$env_name/$env_name.tfvars.example\`. Stacks are planned in dependency order. Nothing was applied and no cloud resource exists."
  echo
  echo "| Stack | Variables | Status | Add | Change | Destroy | Replace | Monthly cost (USD) |"
  echo "|---|---|---|---|---|---|---|---|"
  jq -r '[.stack, .variables, .status, .add, .change, .destroy, .replace] | @tsv' "$results" | while IFS=$'\t' read -r s v st a c d r; do
    cost="estimate unavailable"
    if [ "$cost_state" = "available" ] && [ "$v" = "$env_name" ]; then
      cost="$(jq -r --arg p "stacks/$s" '[.projects[]? | select((.name // .project_name // "") == $p)
        | (.breakdown.totalMonthlyCost // .totalMonthlyCost // empty)] | first // "estimate unavailable"' "$cost_json")"
    fi
    echo "| $s | $v | $st | $a | $c | $d | $r | $cost |"
  done
  echo
  total_add="$(jq -s '[.[] | select(.variables != "pdn-fixtures") | .add] | add' "$results")"
  total_destroy="$(jq -s '[.[] | select(.variables != "pdn-fixtures") | .destroy] | add' "$results")"
  echo "Totals for $env_name: $total_add to add, $total_destroy to destroy."
  echo
  if jq -e 'select(.pending != "")' "$results" > /dev/null; then
    echo "Pending wiring (planned with what exists today, not a failure):"
    echo
    jq -r 'select(.pending != "" and .variables != "pdn-fixtures") | "- \(.stack): \(.pending)"' "$results"
    echo
  fi
  if [ "$cost_state" != "available" ]; then
    echo "Infracost: estimate unavailable (token, organization or metadata egress approval not configured, or the scan failed). No figure is claimed."
  else
    echo "Infracost: totals taken from \`infracost scan\` of the authored configuration."
  fi
} > "$out/summary.md"

jq -s --arg env "$env_name" --arg cost "$cost_state" '{environment: $env, infracost: $cost, stacks: .}' "$results" > "$out/summary.json"
rm -f "$results"

cat "$out/summary.md"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "$out/summary.md" >> "$GITHUB_STEP_SUMMARY"
fi

exit "$failed"
