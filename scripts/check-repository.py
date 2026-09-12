#!/usr/bin/env python3
"""Offline checks for release metadata, localization, local links and public files."""
from pathlib import Path
import json
import re
import subprocess
import sys
from urllib.parse import unquote

root = Path(__file__).resolve().parent.parent
errors = []
def check(condition, message):
    if not condition:
        errors.append(message)

files = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
for name in filter(None, files):
    p = root / name
    check(not name.startswith(('artifacts/', 'Research/', 'design/', 'AIZU.xcodeproj/', 'Vendor/discord_partner_sdk.xcframework/')), f'Private/generated file: {name}')
    check(name != 'Config/Local.xcconfig', 'Local configuration must not be committed')
    check(p.stat().st_size < 8 * 1024 * 1024, f'File exceeds 8 MiB: {name}')
    if p.suffix in {'.png', '.gif', '.jpg', '.jpeg'}:
        continue
    content = p.read_text(errors='replace')
    check(not re.search(r'/' + r'Users/[^/\s]+/', content), f'Personal machine path: {name}')
    check(not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,}', content), f'Possible credential: {name}')

spec = (root / 'project.yml').read_text()
version = (root / 'VERSION').read_text().strip()
check(re.fullmatch(r'\d+\.\d+\.\d+(?:-[a-z]+\.\d+)?', version) is not None, 'Invalid VERSION')
check(f"MARKETING_VERSION: '{version.split('-')[0]}'" in spec, 'Bundle version differs from VERSION')
check('DISCORD_APPLICATION_ID = 0' in (root / 'Config/App.xcconfig').read_text(), 'Public config must use application ID 0')
translations = {}
for code in ['ko', 'en', 'ja', 'zh-Hans']:
    table = {}
    for line in (root / f'iPadPresence/Resources/{code}.lproj/Localizable.strings').read_text().splitlines():
        if not line.strip() or line.startswith('//'):
            continue
        match = re.fullmatch(r'("(?:\\.|[^"\\])*")\s*=\s*("(?:\\.|[^"\\])*");', line)
        check(match is not None, f'Invalid localization syntax: {code}')
        if match:
            key, value = map(json.loads, match.groups())
            check(key not in table, f'Duplicate localization key: {code}/{key}')
            table[key] = value
            slots = lambda s: sorted(re.findall(r'%[@d]|\$\{[^}]+\}', s))
            check(slots(key) == slots(value), f'Format arguments differ: {code}/{key}')
    translations[code] = table
for code, table in translations.items():
    check(table.keys() == translations['ko'].keys(), f'Missing localization keys: {code}')
for name in filter(lambda n: n.endswith('.md'), files):
    p = root / name
    for target in re.findall(r'!?\[[^\]]*\]\(([^\s)]+)(?:\s+"[^"]*")?\)', p.read_text()):
        if target.startswith(('https:', 'http:', '#', 'mailto:')):
            continue
        destination = unquote(target.split('#')[0])
        check((p.parent / destination).exists(), f'Broken local link: {name} -> {target}')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print(f'Repository checks passed; {len(translations["ko"])} localization keys in four languages.')
