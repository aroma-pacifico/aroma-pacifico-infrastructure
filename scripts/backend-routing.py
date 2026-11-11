"""Read-only routing proof for the reviewed launcher; never execute it or write registrations."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ENVIRONMENTS = ('dev', 'qa', 'pdn')

def require(condition, message):
    if not condition:
        raise ValueError(message)

def normalized(path):
    return os.path.normcase(str(Path(path).resolve())).lower()

def effective_directory(home, root, context='operational'):
    require(context in {'operational', 'validation'}, 'Unsupported launcher context')
    identifier = hashlib.sha256(normalized(root).encode('utf-8')).hexdigest()[:24]
    return Path(home).resolve() / ('validation-data' if context == 'validation' else 'data') / identifier

def verify_checkout(checkout, environment, control_root):
    checkout = Path(checkout).resolve()
    require(checkout.name == environment and checkout.parent.name == 'environments',
            'Use a dedicated .../environments/<environment> checkout; a shared root is forbidden')
    def git(*args, cwd=checkout):
        result = subprocess.run(['git', *args], cwd=cwd, capture_output=True, text=True,
                                env=dict(os.environ, GIT_OPTIONAL_LOCKS='0'), timeout=30)
        require(result.returncode == 0, 'Cannot verify the checkout Git identity')
        return result.stdout.strip()
    require(Path(git('rev-parse', '--show-toplevel')).resolve() == checkout, 'Directory is not its own Git checkout')
    require(git('rev-parse', 'HEAD') == git('rev-parse', 'HEAD', cwd=control_root), 'Checkout commit differs from the reviewed control checkout')
    require(git('remote', 'get-url', 'origin') == git('remote', 'get-url', 'origin', cwd=control_root), 'Checkout origin differs from the control repository')
    require(not git('status', '--porcelain'), 'Operational checkout must have no tracked or untracked edits')
    return checkout

def inspect_route(home, root, contract, context='operational', resolved_executable=None):
    home, root = Path(home).resolve(), Path(root).resolve()
    require(root.is_dir(), 'Selected domain root does not exist')
    for name, field in [('dispatcher.py', 'dispatcher_sha256'), ('bin/terraform.exe', 'shim_sha256'), ('settings.json', 'settings_sha256')]:
        require(hashlib.sha256((home / name).read_bytes()).hexdigest() == contract[field],
                'Launcher contract changed; maintainer review is required')
    executable = resolved_executable or shutil.which('terraform')
    require(executable is not None and Path(executable).resolve() == home / 'bin/terraform.exe',
            'Terraform does not resolve to the reviewed launcher')
    settings = json.loads((home / 'settings.json').read_text(encoding='utf-8-sig'))
    require(root.is_relative_to(Path(settings['workspace']).resolve()), 'Root is outside the managed launcher workspace')
    target = effective_directory(home, root, context)
    registration = effective_directory(home, root) / 'autodev-root.json'
    require(registration.is_file(), 'Maintainer-approved operational registration is missing; preflight creates none')
    metadata = json.loads(registration.read_text(encoding='utf-8-sig'))
    require(metadata.get('normalized_root') == normalized(root), 'Operational root registration mismatch')
    if context == 'validation':
        require(not (target / 'terraform.tfstate').exists() and not (target / 'terraform.tfstate.backup').exists(),
                'Validation cache contains backend metadata')
    return target

def verify_context(target, config, environment_variables=None):
    values = os.environ if environment_variables is None else environment_variables
    require(values.get('AUTODEV_TF_CONTEXT', 'operational') in {'', 'operational'}, 'Operational review cannot use validation routing')
    require(values.get('TF_WORKSPACE', 'default') == 'default', 'Only the default workspace is approved')
    require(not any(value for key, value in values.items() if key.startswith('TF_CLI_ARGS')),
            'Inherited TF_CLI_ARGS overrides are forbidden')
    incoming = values.get('TF_DATA_DIR')
    require(not incoming or normalized(incoming) == normalized(target), 'Requested TF_DATA_DIR differs from the effective launcher destination')
    workspace = Path(target) / 'environment'
    require(not workspace.exists() or workspace.read_text(encoding='utf-8').strip() == 'default', 'Cached workspace is not default')
    metadata_path = Path(target) / 'terraform.tfstate'
    if metadata_path.exists():
        metadata = json.loads(metadata_path.read_text(encoding='utf-8-sig'))
        require(metadata.get('backend', {}).get('type') == 's3', 'Cached backend is not the expected S3 backend')
        cached = metadata['backend'].get('config', {})
        require(all(cached.get(key) == value for key, value in config.items()), 'Cached backend tuple differs; do not reconfigure or migrate it automatically')
