"""Exercise archive validation without installing or redistributing Discord binaries."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / 'install-sdk.py'
PREFIX = 'discord_social_sdk/lib/release/discord_partner_sdk.xcframework/'

class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'scripts').mkdir()
        shutil.copyfile(SCRIPT, self.root / 'scripts/install-sdk.py')
        self.vendor = self.root / 'Vendor/discord_partner_sdk.xcframework'
        self.vendor.mkdir(parents=True)
        (self.vendor / 'previous').write_text('Keep on failure')

    def archive(self, name='Info.plist'):
        path = self.root / 'fixture.zip'
        with zipfile.ZipFile(path, 'w') as bundle:
            bundle.writestr(PREFIX + name, 'fixture data, not an SDK')
            bundle.writestr('discord_social_sdk/License-Notices.txt', 'Fixture notice')
        return path, hashlib.sha256(path.read_bytes()).hexdigest()

    def run_installer(self, path, digest):
        import sys
        return subprocess.run([sys.executable, str(self.root / 'scripts/install-sdk.py'), str(path), '--sha256', digest], capture_output=True, text=True)

    def test_bad_checksum_preserves_installed_files(self):
        path, _ = self.archive()
        result = self.run_installer(path, '0' * 64)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.vendor / 'previous').exists())
        self.assertFalse((self.vendor / 'Info.plist').exists())

    def test_path_traversal_is_rejected_before_replacement(self):
        path, digest = self.archive('../../outside')
        result = self.run_installer(path, digest)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.vendor / 'previous').exists())
        self.assertFalse((self.root / 'outside').exists())

    def test_valid_archive_replaces_old_files_and_preserves_notices(self):
        path, digest = self.archive()
        result = self.run_installer(path, digest)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.vendor / 'previous').exists())
        self.assertTrue((self.vendor / 'Info.plist').exists())
        self.assertEqual((self.root / 'Vendor/License-Notices.txt').read_text(), 'Fixture notice')
        self.assertIn(digest, (self.root / 'Vendor/SDK-PROVENANCE.txt').read_text())

if __name__ == '__main__':
    unittest.main()
