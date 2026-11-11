"""Offline D02 verification evidence; synthetic identities never contact AWS."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("backend", root / "scripts/prepare-backend.py")
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)
baseline = {}
for index, environment in enumerate(backend.ENVIRONMENTS, 1):
    account = str(index) * 12
    for stack in backend.STACKS:
        baseline[(environment, stack)] = {
            "bucket": f"synthetic-offline-{environment}-state",
            "key": f"{stack}/terraform.tfstate", "region": "us-east-1",
            "encrypt": True, "use_lockfile": True,
            "kms_key_id": f"arn:aws:kms:us-east-1:{account}:key/00000000-0000-0000-0000-00000000000{index}",
            "allowed_account_ids": [account],
        }

with tempfile.TemporaryDirectory(prefix="aroma-b02-offline-") as directory:
    fixture_root = Path(directory).resolve()

    def write(configs):
        for (environment, stack), config in configs.items():
            path = fixture_root / stack / "backends" / f"{environment}.s3.tfbackend"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("\n".join(f"{key} = {json.dumps(value)}" for key, value in config.items()) + "\n", encoding="utf-8")

    def rejected(label, change):
        configs = copy.deepcopy(baseline)
        change(configs)
        write(configs)
        try:
            backend.validate(fixture_root, False)
        except (ValueError, TypeError):
            print(f"PASS: rejects {label}")
        else:
            raise AssertionError(f"Accepted {label}")

    write(baseline)
    backend.validate(fixture_root, False)
    print("PASS: accepts consistent synthetic concrete configurations")
    for field, value in [("encrypt", False), ("use_lockfile", False), ("region", "us-west-2"),
                         ("key", "workload/terraform.tfstate"), ("bucket", "REQUIRED_QA_STATE_BUCKET"),
                         ("allowed_account_ids", []), ("kms_key_id", baseline[("pdn", "network")]["kms_key_id"]),
                         ("access_key", "forbidden-fixture-field")]:
        rejected(field, lambda configs, field=field, value=value: configs[("qa", "network")].update({field: value}))

    def collide(configs):
        for stack in backend.STACKS:
            configs[("qa", stack)]["bucket"] = configs[("pdn", stack)]["bucket"]
    rejected("shared qa/pdn bucket", collide)

    def same_account(configs):
        for stack in backend.STACKS:
            configs[("qa", stack)]["allowed_account_ids"] = configs[("pdn", stack)]["allowed_account_ids"]
            configs[("qa", stack)]["kms_key_id"] = configs[("pdn", stack)]["kms_key_id"]
    rejected("shared qa/pdn account", same_account)
    rejected("missing encryption field", lambda configs: configs[("qa", "network")].pop("encrypt"))
    rejected("missing KMS field", lambda configs: configs[("qa", "network")].pop("kms_key_id"))
    rejected("missing locking field", lambda configs: configs[("qa", "network")].pop("use_lockfile"))
    write(baseline)
    target = fixture_root / "network/backends/qa.s3.tfbackend"
    target.write_text(target.read_text(encoding="utf-8") + 'bucket = "duplicate"\n', encoding="utf-8")
    try:
        backend.validate(fixture_root, False)
    except ValueError:
        print("PASS: rejects duplicate fields")
    else:
        raise AssertionError("Accepted duplicate field")
    write(baseline)
    for environment in backend.ENVIRONMENTS:
        for stack in backend.STACKS:
            result = subprocess.run([sys.executable, str(root / "scripts/prepare-backend.py"),
                                     "--config-root", str(fixture_root), "--environment", environment,
                                     "--stack", stack], capture_output=True, text=True)
            assert result.returncode != 0, result.stdout
            expected = 'Bootstrap cannot initialize' if stack == 'state-backend' else 'Operational review requires'
            assert expected in result.stderr, result.stderr
            assert 'terraform -chdir=' not in result.stdout
    print("PASS: twelve unbound environment/domain requests fail closed; bootstrap never prints self-init")

    for arguments, diagnostic in [
        (["--environment", "qa"], "Select both"),
        (["--templates", "--environment", "qa", "--stack", "network"], "Templates cannot initialize"),
    ]:
        result = subprocess.run([sys.executable, str(root / "scripts/prepare-backend.py"),
                                 *arguments], capture_output=True, text=True)
        assert result.returncode != 0 and diagnostic in result.stderr, result.stdout + result.stderr
        print(f"PASS: rejects invalid CLI combination ({diagnostic})")

for template in (root / "stacks").glob("*/backends/*.example"):
    result = subprocess.run(["terraform", "fmt", "-check", "-"], input=template.read_text(encoding="utf-8"),
                            capture_output=True, text=True)
    assert result.returncode == 0, (template, result.stdout, result.stderr)
print("PASS: terraform fmt -check - accepts all twelve backend templates through stdin")
assert backend.quote("a'b") == "'a''b'"
print("PASS: PowerShell quote escaping")
