"""Validate backend files offline; print, but never execute, future PowerShell init."""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
STACKS = ("network", "security", "workload", "state-backend")
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
                require(isinstance(config["bucket"], str) and len(config["bucket"]) <= 28 and
                        re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)+", config["bucket"]) and f"-{environment}-" in config["bucket"],
                        f"{path}: supply the verified bucket name")
                accounts = config["allowed_account_ids"]
                require(isinstance(accounts, list) and len(accounts) == 1 and
                        isinstance(accounts[0], str) and re.fullmatch(r"\d{12}", accounts[0]),
                        f"{path}: supply exactly one verified account ID")
                require(isinstance(config["kms_key_id"], str) and re.fullmatch(
                    rf"arn:aws:kms:us-east-1:{accounts[0]}:key/[a-f0-9]{{8}}-[a-f0-9]{{4}}-[a-f0-9]{{4}}-[a-f0-9]{{4}}-[a-f0-9]{{12}}", config["kms_key_id"]),
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
    parser.add_argument("--config-root", type=Path)
    parser.add_argument("--environment", choices=ENVIRONMENTS)
    parser.add_argument("--stack", choices=STACKS)
    parser.add_argument("--checkout-root", type=Path, help="dedicated .../environments/<environment> Git checkout")
    parser.add_argument("--expected-account-id", help="independently verified B03 environment account, never credentials")
    parser.add_argument("--launcher-home", type=Path, default=Path(os.environ.get('LOCALAPPDATA', '')) / 'AutoDev/Terraform')
    args = parser.parse_args()
    require(bool(args.environment) == bool(args.stack), "Select both --environment and --stack")
    require(not args.templates or not args.environment, "Templates cannot initialize a backend")
    require(args.stack != 'state-backend', 'Bootstrap cannot initialize against its own absent bucket; use the offline composition and approved handoff')
    config_root = (args.config_root or (args.checkout_root / 'stacks' if args.checkout_root else ROOT / 'stacks')).resolve()
    validate(config_root, args.templates)
    if args.environment:
        require(args.checkout_root is not None and args.expected_account_id is not None,
                'Operational review requires --checkout-root and --expected-account-id')
        config = config_root / args.stack / "backends" / f"{args.environment}.s3.tfbackend"
        selected = read_config(config)
        require(selected['allowed_account_ids'] == [args.expected_account_id], 'Expected account does not match the selected backend')
        sys.dont_write_bytecode = True
        spec = importlib.util.spec_from_file_location('backend_routing', ROOT / 'scripts/backend-routing.py')
        routing = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(routing)
        checkout = routing.verify_checkout(args.checkout_root, args.environment, ROOT)
        require(config.is_relative_to(checkout / 'stacks'), 'Concrete backend configuration must belong to the selected checkout')
        domain_root = checkout / 'stacks' / args.stack
        contract = json.loads((ROOT / 'scripts/launcher-contract.json').read_text(encoding='utf-8-sig'))
        destination = routing.inspect_route(args.launcher_home, domain_root, contract)
        destinations = [routing.effective_directory(args.launcher_home, checkout.parent / environment / 'stacks' / args.stack) for environment in ENVIRONMENTS]
        require(len(set(destinations)) == len(ENVIRONMENTS), 'Environment routes collide')
        routing.verify_context(destination, selected)
        print("REVIEW ONLY: cloud prerequisites and policy approval are still required.")
        print('PASS: reviewed launcher contract, dedicated checkout, backend tuple and effective cache agree')
        print("$env:TF_WORKSPACE = 'default'")
        print(f"$env:TF_DATA_DIR = {quote(destination)}")
        print(f"terraform -chdir={quote(domain_root)} init -input=false "
              f"-reconfigure -backend-config={quote(config)}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, TypeError) as error:
        raise SystemExit(f"ERROR: {error}") from error
