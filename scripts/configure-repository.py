#!/usr/bin/env python3
"""Apply GitHub repository settings. Does not commit, push, or create a branch."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--repo', default='aizuproject/AIZU')
parser.add_argument('--apply', action='store_true', help='Required to change remote settings')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
rules = json.loads((root / '.github/rulesets/main.json').read_text())
if not args.apply:
    print('Dry run. Would enable issues, security reporting/scanning, squash merges, and PR rules.')
    print('Empty repository: rules stay disabled until the first main commit. No git push is performed.')
    raise SystemExit(0)

def api(path, method='GET', body=None):
    command = ['gh', 'api', f'repos/{args.repo}/{path}'.rstrip('/'), '--method', method]
    if body is not None:
        command += ['--input', '-']
    result = subprocess.run(command, input=json.dumps(body) if body is not None else None, text=True, capture_output=True, check=True)
    return json.loads(result.stdout) if result.stdout.strip() else None

api('', 'PATCH', {
    'has_issues': True, 'has_wiki': False,
    'allow_merge_commit': False, 'allow_rebase_merge': False, 'allow_squash_merge': True,
    'delete_branch_on_merge': True, 'allow_update_branch': True,
    'security_and_analysis': {
        'secret_scanning': {'status': 'enabled'},
        'secret_scanning_push_protection': {'status': 'enabled'}
    }
})
for path in ['private-vulnerability-reporting', 'vulnerability-alerts', 'automated-security-fixes']:
    api(path, 'PUT')
try:
    api('branches/main')
    has_main = True
except subprocess.CalledProcessError as error:
    if 'HTTP 404' not in error.stderr:
        raise
    has_main = False
if not has_main:
    rules['enforcement'] = 'disabled'
existing = next((r for r in api('rulesets') if r['name'] == rules['name']), None)
path = f'rulesets/{existing["id"]}' if existing else 'rulesets'
result = api(path, 'PUT' if existing else 'POST', rules)
print(json.dumps({'repository': args.repo, 'mainExists': has_main,
                  'rulesetID': result['id'], 'enforcement': result['enforcement'],
                  'nextStep': 'Review before pushing. Re-run this script immediately after the first main push.' if not has_main else 'All main updates must use a PR and pass required checks.'}, indent=2))
