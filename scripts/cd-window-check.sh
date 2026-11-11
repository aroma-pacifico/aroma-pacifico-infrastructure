#!/usr/bin/env bash
# Harvest-week change window check for the production promotion (B12).
#
# Design source: ADR-003 and automation-and-pipelines.md section 4.4. Production
# changes are refused between 05:00 and 18:00 Colombia time (ASM-007) on a
# harvest-week day (ASM-055). Which days are harvest-week days is supplied by the
# Federation and kept as pipeline configuration, not in code (ASM-008): this
# script reads them from HARVEST_WEEK_DATES, a comma separated list of ISO dates
# (YYYY-MM-DD). No calendar value is invented here.
#
# Environment:
#   HARVEST_WEEK_DATES  Comma separated harvest-week days. Empty means not configured.
#   INCIDENT_REFERENCE  Incident reference that overrides the window (optional).
#   WINDOW_NOW          Test hook: "YYYY-MM-DD HH" in Colombia time instead of the clock.
#
# Prints one status line: allowed, calendar-not-configured, incident-override or
# blocked. Exits 1 only for blocked. Writes window_status to GITHUB_OUTPUT when set.
set -euo pipefail

calendar="$(printf '%s' "${HARVEST_WEEK_DATES:-}" | tr -d '[:space:]')"
incident="${INCIDENT_REFERENCE:-}"

if [ -n "${WINDOW_NOW:-}" ]; then
  today="${WINDOW_NOW% *}"
  hour="${WINDOW_NOW#* }"
else
  today="$(TZ=America/Bogota date +%F)"
  hour="$(TZ=America/Bogota date +%H)"
fi
hour=$((10#$hour))

if [ -z "$calendar" ]; then
  status="calendar-not-configured"
  echo "WARNING: HARVEST_WEEK_DATES is not configured, so the harvest-week window cannot be evaluated."
elif ! printf '%s' "$calendar" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}(,[0-9]{4}-[0-9]{2}-[0-9]{2})*$'; then
  echo "ERROR: HARVEST_WEEK_DATES must be a comma separated list of YYYY-MM-DD dates."
  status="blocked"
elif printf '%s' ",$calendar," | grep -q ",$today," && [ "$hour" -ge 5 ] && [ "$hour" -lt 18 ]; then
  if [ -n "$incident" ]; then
    status="incident-override"
  else
    status="blocked"
    echo "ERROR: $today is a harvest-week day and the time is inside 05:00-18:00 Colombia time."
  fi
else
  status="allowed"
fi

echo "window_status=$status (Colombia date $today, hour $hour)"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  printf 'window_status=%s\n' "$status" >> "$GITHUB_OUTPUT"
fi
[ "$status" != "blocked" ]
