"""Validate backend files offline; print, but never execute, future PowerShell init."""

import argparse
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
STACKS = ("network", "security", "workload")
ENVIRONMENTS = ("dev", "qa", "pdn")
FIELDS = {"bucket", "key", "region", "encrypt", "use_lockfile", "kms_key_id", "allowed_account_ids"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_config(path):
    config = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = re.fullmatch(r"\s*(\w+)\s*=\s*(.+?)\s*", line)
        require(match is not None, f"{path}: expected a literal key = value")
        name, value = match.groups()
        require(name in FIELDS and name not in config, f"{path}: unexpected or duplicate field {name}")
        config[name] = json.loads(value)
    require(config.keys() == FIELDS, f"{path}: missing required backend fields")
    return config


def validate(config_root, templates):
    identities = {}
    objects = set()
    for environment in ENVIRONMENTS:
        for stack in STACKS:
            suffix = ".example" if templates else ""
            path = config_root / stack / "backends" / f"{environment}.s3.tfbackend{suffix}"
            config = read_config(path)
            require(config["key"] == f"{stack}/terraform.tfstate", f"{path}: wrong domain key")
            require(config["region"] == "us-east-1", f"{path}: wrong architecture region")
            require(config["encrypt"] is True and config["use_lockfile"] is True,
                    f"{path}: encryption and locking must stay enabled")
            if templates:
                marker = f"REQUIRED_{environment.upper()}"
                require(config["bucket"] == f"{marker}_STATE_BUCKET", f"{path}: wrong bucket marker")
                require(config["kms_key_id"] == f"{marker}_STATE_KMS_KEY_ARN", f"{path}: wrong KMS marker")
                require(config["allowed_account_ids"] == [f"{marker}_ACCOUNT_ID"], f"{path}: wrong account marker")
            else:
                require(isinstance(config["bucket"], str) and
                        re.fullmatch(r"[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]", config["bucket"]),
                        f"{path}: supply the verified bucket name")
                accounts = config["allowed_account_ids"]
                require(isinstance(accounts, list) and len(accounts) == 1 and
                        isinstance(accounts[0], str) and re.fullmatch(r"\d{12}", accounts[0]),
                        f"{path}: supply exactly one verified account ID")
                require(isinstance(config["kms_key_id"], str) and re.fullmatch(
                    rf"arn:aws:kms:us-east-1:{accounts[0]}:key/[a-f0-9-]{{36}}", config["kms_key_id"]),
                    f"{path}: supply the same account's regional KMS key ARN")
            identity = (config["bucket"], tuple(config["allowed_account_ids"]), config["kms_key_id"])
            require(environment not in identities or identities[environment] == identity,
                    f"{path}: domains must use the same environment backend identity")
            identities[environment] = identity
            state_object = (config["bucket"], config["key"])
            require(state_object not in objects, f"{path}: state object collision")
            objects.add(state_object)
    for field in range(3):
        require(len({identity[field] for identity in identities.values()}) == len(ENVIRONMENTS),
                "Environments must have different buckets, accounts and KMS keys")
    print(f"PASS: {len(objects)} distinct state objects; dev/qa/pdn identities isolated")


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--templates", action="store_true", help="check examples only; cannot print init")
    parser.add_argument("--config-root", type=Path, default=ROOT / "stacks")
    parser.add_argument("--environment", choices=ENVIRONMENTS)
    parser.add_argument("--stack", choices=STACKS)
    args = parser.parse_args()
    require(bool(args.environment) == bool(args.stack), "Select both --environment and --stack")
    require(not args.templates or not args.environment, "Templates cannot initialize a backend")
    validate(args.config_root.resolve(), args.templates)
    if args.environment:
        config = args.config_root.resolve() / args.stack / "backends" / f"{args.environment}.s3.tfbackend"
        print("REVIEW ONLY: cloud prerequisites and policy approval are still required.")
        print("$env:TF_WORKSPACE = 'default'")
        print(f"$env:TF_DATA_DIR = {quote(ROOT / '.terraform-data' / args.environment / args.stack)}")
        print(f"terraform -chdir={quote(ROOT / 'stacks' / args.stack)} init -input=false "
              f"-reconfigure -backend-config={quote(config)}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, TypeError) as error:
        raise SystemExit(f"ERROR: {error}") from error
