#!/usr/bin/env python3
"""Install the iOS XCFramework from a separately obtained official Discord archive."""
import argparse
import hashlib
from pathlib import Path
import shutil
import stat
import tempfile
import zipfile

TESTED_SHA256 = 'd784097504685953849cc2842561d8a8013326fe0b8df65a1de63ddefde62045'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
parser.add_argument('--sha256', default=TESTED_SHA256, help='Expected archive digest; defaults to the tested 1.10.19337 archive')
args = parser.parse_args()
archive = args.archive.expanduser().resolve()
with archive.open('rb') as source:
    digest = hashlib.sha256()
    for block in iter(lambda: source.read(1024 * 1024), b''):
        digest.update(block)
sha = digest.hexdigest()
if sha != args.sha256.lower():
    raise SystemExit('Archive checksum does not match. Verify its origin and version before proceeding.')
root = Path(__file__).resolve().parent.parent
vendor = root / 'Vendor'
vendor.mkdir(exist_ok=True)
prefix = 'discord_social_sdk/lib/release/discord_partner_sdk.xcframework/'
destination = vendor / 'discord_partner_sdk.xcframework'
with zipfile.ZipFile(archive) as sdk, tempfile.TemporaryDirectory(dir=vendor) as directory:
    files = [entry for entry in sdk.infolist() if entry.filename.startswith(prefix) and not entry.is_dir()]
    if not files or sum(entry.file_size for entry in files) > 512 * 1024 * 1024:
        raise SystemExit('Missing or oversized iOS XCFramework.')
    staged = Path(directory) / 'framework'
    staged.mkdir()
    for entry in files:
        relative = Path(entry.filename.removeprefix(prefix))
        if '..' in relative.parts or relative.is_absolute() or stat.S_ISLNK(entry.external_attr >> 16):
            raise SystemExit('Unsafe archive entry.')
        output = staged / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        with sdk.open(entry) as source, output.open('wb') as target:
            shutil.copyfileobj(source, target)
    notices = sdk.read('discord_social_sdk/License-Notices.txt')
    backup = Path(directory) / 'previous'
    if destination.exists():
        destination.rename(backup)
    try:
        staged.rename(destination)
    except OSError:
        if backup.exists():
            backup.rename(destination)
        raise
    (vendor / 'License-Notices.txt').write_bytes(notices)
    (vendor / 'SDK-PROVENANCE.txt').write_text(
        f'Source: Discord Developer Portal, official C++ SDK download\nArchive: {archive.name}\nSHA-256: {sha}\n'
        'Installed: release iOS XCFramework. Krisp not installed separately.\n')
print(f'Installed {len(files)} framework files. Regenerate the project with scripts/generate.sh.')
