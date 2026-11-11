"""Stage inactive root templates for mock-only development verification; never initialize S3."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / 'stacks/state-backend/root-template'

def execute(directory, *arguments):
    result = subprocess.run(['terraform', f'-chdir={directory}', *arguments], capture_output=True,
                            text=True, encoding='utf-8', errors='replace', timeout=120)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--module-root', type=Path, required=True, help='reviewed local state-backend module, test composition only')
    args = parser.parse_args()
    module = args.module_root.resolve()
    required = {'aws_kms_key', 'aws_kms_alias', 'aws_s3_bucket', 'aws_s3_bucket_ownership_controls',
                'aws_s3_bucket_public_access_block', 'aws_s3_bucket_versioning',
                'aws_s3_bucket_server_side_encryption_configuration', 'aws_s3_bucket_policy'}
    scratch = ROOT / '.local'
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='bootstrap-mock-', dir=scratch) as temporary:
        directory = Path(temporary)
        (directory / 'module').mkdir()
        for path in module.glob('*.tf'):
            shutil.copyfile(path, directory / 'module' / path.name)
        for path in TEMPLATE.glob('*.tf.example'):
            if path.name == 'backend.tf.example':
                continue
            text = path.read_text(encoding='utf-8')
            if path.name == 'main.tf.example':
                source = 'git::https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules.git//modules/state-backend?ref=REQUIRED_REVIEWED_RELEASE'
                if text.count(source) != 1:
                    raise RuntimeError('Inactive source/release gate changed; review before staging')
                text = text.replace(source, './module')
            (directory / path.name.removesuffix('.example')).write_text(text, encoding='utf-8')
        for path in directory.glob('*.tf'):
            if re.search(r'backend\s+"', path.read_text()):
                raise RuntimeError('Bootstrap fixture must not initialize its own backend')
        (directory / 'tests').mkdir()
        shutil.copyfile(module / 'sample/tests/bootstrap_unit_test.tftest.hcl', directory / 'tests/bootstrap_unit_test.tftest.hcl')
        shutil.copyfile(module / 'sample/.terraform.lock.hcl', directory / '.terraform.lock.hcl')
        options = ['init', '-backend=false', '-input=false', '-lockfile=readonly', '-no-color']
        if os.environ.get('B02_PROVIDER_MIRROR'):
            options.append('-plugin-dir=' + os.environ['B02_PROVIDER_MIRROR'])
        execute(directory, *options)
        print('PASS private root: backend-disabled initialization')
        print(execute(directory, 'validate', '-no-color').strip())
        execute(directory, 'fmt', '-check', '-recursive')
        output = execute(directory, 'test', '-json', '-verbose', '-no-color')
        events = [json.loads(line) for line in output.splitlines()]
        summary = next(e['test_summary'] for e in events if e.get('type') == 'test_summary')
        if summary['passed'] != 2 or summary['failed']:
            raise RuntimeError(str(summary))
        plan = next(e['test_plan'] for e in events if e.get('type') == 'test_plan')
        changes = plan['resource_changes']
        if Counter(c['type'] for c in changes) != Counter({kind: 1 for kind in required}) or not all(c['change']['actions'] == ['create'] for c in changes):
            raise RuntimeError('Unexpected bootstrap graph')
        if list(directory.rglob('*.tfstate*')):
            raise RuntimeError('Unexpected fixture state')
        print('PASS private root: two native scenarios; one environment, eight mocked creates, zero destroys/replacements')
        print('PASS source substitution is restricted to a temporary development fixture; inactive release template unchanged')
        print('BLOCKED production root: real reviewed SemVer release, B01/B03/B06 and bootstrap authorization are absent')

if __name__ == '__main__':
    main()
