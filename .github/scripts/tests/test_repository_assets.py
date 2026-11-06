import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('assets', Path(__file__).parents[1] / 'repository_assets.py')
assets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assets)


class RepositoryAssetsTests(unittest.TestCase):
    def test_stable_retention_uses_publication_order(self):
        releases = [
            {'tag_name': 'old', 'published_at': '2025-01-01'},
            {'tag_name': 'preview', 'published_at': '2026-03-01', 'prerelease': True},
            {'tag_name': 'draft', 'published_at': '2026-03-02', 'draft': True},
            {'tag_name': 'new', 'published_at': '2026-02-01'},
        ]
        self.assertEqual([r['tag_name'] for r in assets.select_releases(releases, '1')], ['new'])

    def test_invalid_retention_is_rejected(self):
        for limit in ['0', '-1', '101', '1.5', 'all', '01', '1\n2']:
            with self.subTest(limit=limit), self.assertRaises(ValueError):
                assets.select_releases([{}], limit)

    def test_empty_stable_history_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'No published stable'):
            assets.select_releases([{'prerelease': True}], 5)

    def test_native_apk_filename(self):
        self.assertEqual(assets.classify('xmrf_1.3.3-r1_noarch.apk'),
                         ('apk', Path('apk/noarch/xmrf-1.3.3-r1.apk')))

    def test_only_expected_architecture_independent_assets(self):
        expected = {'xmrf_1.3.3-1_all.deb': 'deb',
                    'xmrf-1.3.3-1.noarch.rpm': 'rpm',
                    'xmrf-1.3.3-1-any.pkg.tar.zst': 'arch'}
        for name, kind in expected.items():
            self.assertEqual(assets.classify(name)[0], kind)
        for name in ['../xmrf_1.3.3_all.deb', 'xmrf.exe', 'xmrf_1.3.3_amd64.deb',
                     'other-1.3.3-1-any.pkg.tar.zst', 'xmrf_1.3.3_all.deb/evil']:
            self.assertIsNone(assets.classify(name))

    def test_github_digest_is_checked_before_signing(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / 'package'; file.write_bytes(b'original')
            digest = 'sha256:' + hashlib.sha256(b'original').hexdigest()
            assets.verify_digest(file, digest)
            file.write_bytes(b'altered')
            with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
                assets.verify_digest(file, digest)
            with self.assertRaisesRegex(ValueError, 'Unsupported asset digest'):
                assets.verify_digest(file, 'md5:1234')
            assets.verify_digest(file, None)  # Legacy release compatibility.

    def test_newest_release_must_have_all_formats(self):
        release = {'tag_name': 'v1.0.0', 'assets': [{'name': 'xmrf_1.0.0_all.deb'}]}
        with tempfile.TemporaryDirectory() as tmp, \
             patch.dict(os.environ, {'GITHUB_REPOSITORY': 'owner/repo', 'REPO_SIZE': '5'}), \
             patch('sys.argv', ['assets', str(Path(tmp) / 'site')]), \
             patch.object(assets.subprocess, 'check_output', return_value=json.dumps([[release]]).encode()):
            with self.assertRaisesRegex(ValueError, 'publish a four-format release first'):
                assets.main()

    def test_older_two_format_release_is_retained_and_apk_renamed(self):
        names = ['xmrf_1.3.3-1_all.deb', 'xmrf-1.3.3-1.noarch.rpm',
                 'xmrf_1.3.3-r1_noarch.apk', 'xmrf-1.3.3-1-any.pkg.tar.zst']
        new = {'tag_name': 'v1.3.3', 'published_at': '2026-02-01',
               'assets': [{'id': i, 'name': name} for i, name in enumerate(names, 1)]}
        old = {'tag_name': 'v1.3.2', 'published_at': '2026-01-01',
               'assets': [{'id': 5, 'name': 'xmrf_1.3.2_all.deb'},
                          {'id': 6, 'name': 'xmrf-1.3.2-1.noarch.rpm'}]}
        with tempfile.TemporaryDirectory() as tmp, \
             patch.dict(os.environ, {'GITHUB_REPOSITORY': 'owner/repo', 'REPO_SIZE': '5'}), \
             patch('sys.argv', ['assets', str(Path(tmp) / 'site')]), \
             patch.object(assets.subprocess, 'check_output', return_value=json.dumps([[old, new]]).encode()), \
             patch.object(assets.subprocess, 'run') as download:
            download.side_effect = lambda *args, **kw: kw['stdout'].write(b'package')
            assets.main()
            site = Path(tmp) / 'site'
            self.assertTrue((site / 'apk/noarch/xmrf-1.3.3-r1.apk').exists())
            self.assertTrue((site / 'deb/pool/main/xmrf_1.3.2_all.deb').exists())
            self.assertEqual(len(json.loads((site / 'releases.json').read_text())), 2)
            self.assertEqual(download.call_count, 6)


if __name__ == '__main__':
    unittest.main()
