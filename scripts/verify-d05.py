"""Verify the D05 configuration contract without AWS calls or standalone plans."""

import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
STACK = ROOT / "stacks" / "network"


def execute(directory, *arguments):
    result = subprocess.run(
        ["terraform", f"-chdir={directory}", *arguments],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        timeout=60,
    )
    return result


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


# This guard intentionally expires when real connection logic is added. Review
# and replace it with resource-graph assertions before expanding the boundary.
for path in STACK.glob("*.tf"):
    require(not re.search(r'^\s*(resource|module|data|provider|import)\s+["{]',
                          path.read_text(encoding="utf-8"), re.MULTILINE),
            f"Unexpected executable infrastructure block in {path.name}")

test_source = (STACK / "tests" / "selection_unit_test.tftest.hcl").read_text(encoding="utf-8")
require(re.findall(r"command\s*=\s*(\w+)", test_source) == ["plan"] * 9,
        "Every native scenario must explicitly remain plan-only")

result = execute(STACK, "test", "-json", "-verbose", "-no-color")
require(result.returncode == 0, result.stdout + result.stderr)
events = [json.loads(line) for line in result.stdout.splitlines()]
plans = {event["@testrun"]: event["test_plan"] for event in events
         if event.get("type") == "test_plan"}
expected = {"cauca": "10.41.0.0/16", "huila": "10.42.0.0/16",
            "tolima": "10.43.0.0/16"}
for center, cidr in expected.items():
    plan = plans[center]
    selection = plan["output_changes"]["selected_center"]["after"]
    require(selection == {"key": center, "department": center,
                          "cidr_block": cidr, "environment": "pdn"},
            f"Unexpected selection: {selection}")
    require(not plan.get("resource_changes"), "Unexpected resource changes")
    print(f"PASS {center}: one selected object, {cidr}, zero resource changes")

summary = next(event["test_summary"] for event in events
               if event.get("type") == "test_summary")
require(summary["passed"] == 9 and summary["failed"] == 0, str(summary))
print("PASS native Terraform scenarios: 9 passed, 0 failed")

invalid = {
    "multi_center_list": ('environment = "pdn"\ncollection_center = [{ key = "cauca" }, { key = "huila" }, { key = "tolima" }]', "Invalid value for input variable"),
    "multi_center_keys": ('environment = "pdn"\ncollection_center = { key = ["cauca", "huila", "tolima"] }', "Invalid value for input variable"),
    "missing_center": ('environment = "pdn"', "No value for required variable"),
    "missing_environment": ('collection_center = { key = "cauca" }', "No value for required variable"),
    "missing_center_key": ('environment = "pdn"\ncollection_center = {}', "Invalid value for input variable"),
    "null_center": ('environment = "pdn"\ncollection_center = null', "Required variable not set"),
}
with tempfile.TemporaryDirectory(prefix="aroma-d05-") as temporary:
    directory = Path(temporary)
    for path in STACK.glob("*.tf"):
        (directory / path.name).write_text(path.read_text(encoding="utf-8"), encoding="utf-8")
    result = execute(directory, "init", "-backend=false", "-input=false", "-no-color")
    require(result.returncode == 0, result.stdout + result.stderr)
    tests = directory / "tests"
    tests.mkdir()
    for name, (variables, diagnostic) in invalid.items():
        fixture = tests / "invalid.tftest.hcl"
        fixture.write_text('run "reject" {\n  command = plan\n  variables {\n'
                           + variables + '\n  }\n}\n', encoding="utf-8")
        result = execute(directory, "test", "-json", "-no-color")
        events = [json.loads(line) for line in result.stdout.splitlines()]
        diagnostics = [event["diagnostic"] for event in events
                       if event.get("type") == "diagnostic"]
        require(result.returncode != 0 and any(
            item["severity"] == "error" and item["summary"] == diagnostic
            for item in diagnostics), name + ": " + result.stdout + result.stderr)
        print(f"PASS {name}: rejected ({diagnostic})")
    require(not list(directory.rglob("*.tfstate*")), "Unexpected local state")

print("BLOCKED missing operational connectivity input: no AWS connection module yet")
print("PASS contract boundary: zero infrastructure blocks, no state created by tests")
