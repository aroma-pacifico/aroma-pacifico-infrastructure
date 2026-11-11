"""Read-only preflight and isolated fake-native dispatcher tests; no shared cache writes."""
import hashlib
import importlib.util
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

routing = load('backend_routing', ROOT / 'scripts/backend-routing.py')
backend = load('prepare_backend', ROOT / 'scripts/prepare-backend.py')

class RoutingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='aroma-b02-routing-')
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name).resolve()
        self.home = self.base / 'launcher'
        (self.home / 'bin').mkdir(parents=True)
        (self.home / 'bin/terraform.exe').write_bytes(b'fake-native-is-never-executed')
        (self.home / 'dispatcher.py').write_text('# isolated fingerprint fixture\n', encoding='utf-8')
        (self.home / 'settings.json').write_text(json.dumps({'workspace': str(self.base), 'native': 'FAKE_NATIVE'}), encoding='utf-8')
        self.contract = {key: hashlib.sha256((self.home / name).read_bytes()).hexdigest()
                         for name, key in [('dispatcher.py', 'dispatcher_sha256'), ('bin/terraform.exe', 'shim_sha256'), ('settings.json', 'settings_sha256')]}
        self.root = self.base / 'environments/qa/stacks/network'
        self.root.mkdir(parents=True)
        self.target = routing.effective_directory(self.home, self.root)
        self.target.mkdir(parents=True)
        (self.target / 'autodev-root.json').write_text(json.dumps({'normalized_root': routing.normalized(self.root)}), encoding='utf-8')
        self.config = dict(bucket='fixture-qa-state', key='network/terraform.tfstate', region='us-east-1',
                           encrypt=True, use_lockfile=True, kms_key_id='fixture-key', allowed_account_ids=[format(0, '012d')])

    def inspect(self, **kwargs):
        return routing.inspect_route(self.home, self.root, self.contract,
                                     resolved_executable=self.home / 'bin/terraform.exe', **kwargs)

    def test_route_inspection_writes_nothing(self):
        before = {str(p): p.read_bytes() for p in self.base.rglob('*') if p.is_file()}
        self.assertEqual(self.inspect(), self.target)
        self.assertEqual(before, {str(p): p.read_bytes() for p in self.base.rglob('*') if p.is_file()})

    def test_dedicated_environment_roots_and_contexts_are_distinct(self):
        paths = [routing.effective_directory(self.home, self.base / 'environments' / env / 'stacks' / domain, context)
                 for env in routing.ENVIRONMENTS for domain in backend.STACKS for context in ['operational', 'validation']]
        self.assertEqual(len(set(paths)), 24)

    def test_same_root_cannot_gain_environment_isolation_from_tf_data_dir(self):
        self.assertEqual(routing.effective_directory(self.home, self.root), self.target)
        for env in routing.ENVIRONMENTS:
            with self.subTest(env=env), self.assertRaisesRegex(ValueError, 'TF_DATA_DIR'):
                routing.verify_context(self.target, self.config, {'TF_DATA_DIR': str(self.base / env)})

    def test_missing_registration_is_rejected_without_creation(self):
        (self.target / 'autodev-root.json').unlink()
        with self.assertRaisesRegex(ValueError, 'registration is missing'):
            self.inspect()
        self.assertFalse((self.target / 'autodev-root.json').exists())

    def test_mismatched_registration_is_rejected(self):
        (self.target / 'autodev-root.json').write_text('{"normalized_root":"other"}')
        with self.assertRaisesRegex(ValueError, 'registration mismatch'):
            self.inspect()

    def test_changed_launcher_is_rejected(self):
        (self.home / 'dispatcher.py').write_text('# changed')
        with self.assertRaisesRegex(ValueError, 'contract changed'):
            self.inspect()

    def test_wrong_executable_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'reviewed launcher'):
            routing.inspect_route(self.home, self.root, self.contract, resolved_executable=self.base / 'native.exe')

    def test_wrong_workspace_and_cli_overrides_are_rejected(self):
        for variables in [{'TF_WORKSPACE': 'qa'}, {'TF_CLI_ARGS_init': '-backend-config=wrong'}, {'AUTODEV_TF_CONTEXT': 'validation'}]:
            with self.subTest(variables=variables), self.assertRaises(ValueError):
                routing.verify_context(self.target, self.config, variables)

    def test_cached_workspace_is_rejected(self):
        (self.target / 'environment').write_text('qa')
        with self.assertRaisesRegex(ValueError, 'Cached workspace'):
            routing.verify_context(self.target, self.config, {})

    def test_backend_metadata_match_and_mismatch(self):
        path = self.target / 'terraform.tfstate'
        path.write_text(json.dumps({'backend': {'type': 's3', 'config': self.config}}))
        routing.verify_context(self.target, self.config, {})
        for field in ['bucket', 'key', 'kms_key_id', 'allowed_account_ids', 'use_lockfile']:
            changed = dict(self.config, **{field: 'wrong'})
            path.write_text(json.dumps({'backend': {'type': 's3', 'config': changed}}))
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'backend tuple differs'):
                routing.verify_context(self.target, self.config, {})

    def test_validation_rejects_backend_metadata(self):
        target = routing.effective_directory(self.home, self.root, 'validation')
        target.mkdir(parents=True)
        (target / 'terraform.tfstate').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'Validation cache'):
            self.inspect(context='validation')

    def test_environment_checkout_mismatch_is_rejected_before_git(self):
        with self.assertRaisesRegex(ValueError, 'dedicated'):
            routing.verify_checkout(self.base / 'environments/qa', 'pdn', ROOT)

    def test_own_checkout_and_commit_are_required(self):
        checkout = self.base / 'environments/qa'
        def fake_run(arguments, cwd, **kwargs):
            output = str(checkout) if '--show-toplevel' in arguments else ('fixture-origin' if 'remote' in arguments else ('old' if cwd == checkout else 'new'))
            return subprocess.CompletedProcess(arguments, 0, output, '')
        with patch.object(routing.subprocess, 'run', side_effect=fake_run), self.assertRaisesRegex(ValueError, 'commit differs'):
            routing.verify_checkout(checkout, 'qa', ROOT)

    def test_real_dispatcher_with_fake_native(self):
        # Execute an unchanged dispatcher copy with a subprocess interceptor, never a real native executable.
        source_home = Path(os.environ.get('LOCALAPPDATA', '')) / 'AutoDev/Terraform'
        source = (source_home / 'dispatcher.py').read_bytes()
        approved = json.loads((ROOT / 'scripts/launcher-contract.json').read_text(encoding='utf-8-sig'))
        self.assertEqual(hashlib.sha256(source).hexdigest(), approved['dispatcher_sha256'])
        (self.home / 'dispatcher.py').write_bytes(source)
        observed = []
        def fake_native(arguments, env):
            self.assertEqual(arguments[0], 'FAKE_NATIVE')
            observed.append((env['TF_DATA_DIR'], env['TF_PLUGIN_CACHE_DIR']))
            return 0
        for environment in routing.ENVIRONMENTS:
            for context in ['operational', 'validation']:
                root = self.base / 'environments' / environment / 'stacks/network'
                root.mkdir(parents=True, exist_ok=True)
                with patch.object(sys, 'argv', ['terraform', '-chdir=' + str(root), 'init', '-backend=false']), patch.dict(os.environ, {'AUTODEV_TF_CONTEXT': context, 'TF_DATA_DIR': str(self.base / 'ignored-input')}), patch('subprocess.call', side_effect=fake_native):
                    with self.assertRaises(SystemExit) as caught:
                        runpy.run_path(str(self.home / 'dispatcher.py'), run_name='__main__')
                    self.assertEqual(caught.exception.code, 0)
                    self.assertEqual(Path(observed[-1][0]), routing.effective_directory(self.home, root, context))
        self.assertEqual(len({item[0] for item in observed}), 6)

    def bound_cli(self, expected_account):
        checkout = self.base / 'environments/qa'
        control = self.base / 'control'
        (control / 'scripts').mkdir(parents=True)
        shutil.copyfile(ROOT / 'scripts/backend-routing.py', control / 'scripts/backend-routing.py')
        (control / 'scripts/launcher-contract.json').write_text(json.dumps(self.contract))
        for index, environment in enumerate(backend.ENVIRONMENTS):
            for domain in backend.STACKS:
                account = format(index, '012d')
                values = dict(bucket=f'fixture-{environment}-state', key=f'{domain}/terraform.tfstate',
                              region='us-east-1', encrypt=True, use_lockfile=True,
                              kms_key_id=f'arn:aws:kms:us-east-1:{account}:key/00000000-0000-0000-0000-{account}',
                              allowed_account_ids=[account])
                path = checkout / 'stacks' / domain / 'backends' / f'{environment}.s3.tfbackend'
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('\n'.join(f'{key} = {json.dumps(value)}' for key, value in values.items()))
        def fake_git(arguments, **kwargs):
            if '--show-toplevel' in arguments:
                output = str(checkout)
            elif '--porcelain' in arguments:
                output = ''
            elif 'remote' in arguments:
                output = 'fixture-origin'
            else:
                output = 'fixture-commit'
            return subprocess.CompletedProcess(arguments, 0, output, '')
        arguments = ['prepare-backend', '--environment', 'qa', '--stack', 'network',
                     '--checkout-root', str(checkout), '--expected-account-id', expected_account,
                     '--launcher-home', str(self.home)]
        stream = io.StringIO()
        with patch.object(backend, 'ROOT', control), patch.object(sys, 'argv', arguments), patch('subprocess.run', side_effect=fake_git), patch('shutil.which', return_value=str(self.home / 'bin/terraform.exe')), patch.dict(os.environ, {'AUTODEV_TF_CONTEXT': 'operational', 'TF_WORKSPACE': 'default', 'TF_DATA_DIR': ''}), redirect_stdout(stream):
            backend.main()
        return stream.getvalue()

    def test_bound_cli_renders_proven_effective_destination(self):
        output = self.bound_cli(format(1, '012d'))
        self.assertIn(str(self.target), output)
        self.assertIn('effective cache agree', output)
        self.assertIn('TF_WORKSPACE', output)
        self.assertNotIn('.terraform-data', output)
        self.assertNotIn('-migrate-state', output)

    def test_wrong_expected_account_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Expected account'):
            self.bound_cli(format(9, '012d'))

if __name__ == '__main__':
    unittest.main(verbosity=2)
