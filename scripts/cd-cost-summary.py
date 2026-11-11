#!/usr/bin/env python3
"""Render the Infracost before, after and delta table of one environment (B12).

PC-IAC-027: publish previous monthly cost, new monthly cost and the delta (value
and percentage), one row per root stack. When an estimate cannot be produced the
output says "estimate unavailable" and never contains a placeholder figure.

Usage:
  cd-cost-summary.py --environment pdn --base-json b.json --head-json h.json \
      --base-sha abc --head-sha def --out cost-pdn.md
  cd-cost-summary.py --environment pdn --unavailable "reason" --out cost-pdn.md

Standard library only. The JSON shapes accepted are the ones the B11 branches
parse: projects[].breakdown.totalMonthlyCost, projects[].totalMonthlyCost, or the
sum of resource cost components.
"""
import argparse
import json
import os
from decimal import Decimal, InvalidOperation


def load(path):
    if not path or not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as handle:
            doc = json.load(handle)
    except (OSError, ValueError):
        return None
    return doc if isinstance(doc, dict) else None


def to_decimal(value):
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError):
        return None


def project_total(project):
    breakdown = project.get("breakdown")
    if isinstance(breakdown, dict) and breakdown.get("totalMonthlyCost") is not None:
        return to_decimal(breakdown["totalMonthlyCost"])
    if project.get("totalMonthlyCost") is not None:
        return to_decimal(project["totalMonthlyCost"])
    if "resources" not in project:
        return None
    total = Decimal("0")
    for resource in project["resources"]:
        parts = list(resource.get("cost_components", []))
        for sub in resource.get("subresources", []):
            parts.extend(sub.get("cost_components", []))
        for part in parts:
            value = to_decimal(part.get("total_monthly_cost")) if part.get("total_monthly_cost") is not None else None
            if value is not None:
                total += value
    return total


def costs(doc):
    result = {}
    for project in doc.get("projects", []):
        name = project.get("name") or project.get("project_name") or "unknown"
        result[name] = project_total(project)
    return result


def money(value):
    return f"${value:,.2f}"


def signed(value):
    if value > 0:
        return f"+{money(value)}"
    if value < 0:
        return f"-{money(abs(value))}"
    return money(value)


def unavailable(environment, reason):
    return (
        f"### Cost estimate of {environment}: estimate unavailable\n\n"
        f"{reason}\n\n"
        "No cost figure and no zero-cost delta is claimed.\n"
    )


def table(environment, base, head, base_sha, head_sha):
    lines = [
        f"### Cost estimate of {environment} (Infracost CLI v2, USD per month)",
        "",
        f"Before `{base_sha[:7]}`, after `{head_sha[:7]}`. Supported resources only; "
        "no cloud credentials were used.",
        "",
        "| Stack | Before | After | Delta | Delta % |",
        "|---|---:|---:|---:|---:|",
    ]
    total_before = total_after = Decimal("0")
    for name in sorted(set(base) | set(head)):
        before, after = base.get(name), head.get(name)
        if name in base and before is None or name in head and after is None:
            lines.append(f"| `{name}` | estimate unavailable | estimate unavailable | n/a | n/a |")
            continue
        before = before if before is not None else Decimal("0")
        after = after if after is not None else Decimal("0")
        total_before += before
        total_after += after
        pct = f"{(after - before) / before * 100:+.1f}%" if before else "n/a"
        lines.append(f"| `{name}` | {money(before)} | {money(after)} | {signed(after - before)} | {pct} |")
    pct = f"{(total_after - total_before) / total_before * 100:+.1f}%" if total_before else "n/a"
    lines.append(
        f"| **Total** | **{money(total_before)}** | **{money(total_after)}** | "
        f"**{signed(total_after - total_before)}** | **{pct}** |"
    )
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--environment", required=True)
    parser.add_argument("--base-json")
    parser.add_argument("--head-json")
    parser.add_argument("--base-sha", default="unknown")
    parser.add_argument("--head-sha", default="unknown")
    parser.add_argument("--unavailable")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    if args.unavailable:
        text = unavailable(args.environment, args.unavailable)
    else:
        base_doc, head_doc = load(args.base_json), load(args.head_json)
        if base_doc is None or head_doc is None:
            text = unavailable(args.environment, "The Infracost scan did not return usable data for the before or the after revision.")
        else:
            text = table(args.environment, costs(base_doc), costs(head_doc), args.base_sha, args.head_sha)
    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(text)
    print(text)


if __name__ == "__main__":
    main()
