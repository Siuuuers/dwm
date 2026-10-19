"""Custody boundary and failure tests using tiny synthetic retained packages."""
import contextlib
import io
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
import zipfile
import package_timing as p


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.evidence = self.root / 'evidence'
        (self.evidence / 'native-diagnostic').mkdir(parents=True)
        (self.evidence / 'native-build').mkdir()
        old = self.root / 'old'
        (old / 'licenses').mkdir(parents=True)
        (old / 'DWM.exe').write_bytes(b'retained exe')
        (old / 'DWM.pck').write_bytes(b'retained pck')
        (old / 'licenses/license.txt').write_bytes(b'notice')
        sdk = {'ok': True, 'iterator_variant': 'Corrected', 'iterator_sha256': p.CORRECTED_ITERATOR,
               'library': {'sha256': 'a'*64}, 'tests_exit_code': 0, 'build_exit_code': 0,
               'query_tests_exit_code': 0, 'probe_kind': 'query_and_consumer'}
        sdk_path = self.evidence / 'native-build/consumer-sdk-receipt.json'
        p.write(sdk_path, sdk)
        build = {'ok': True, 'target': 'template_release', 'architecture': 'x86_64',
                 'source_commit': '35e80b3a8822a9df9be390814b62f44c0a9c69e8', 'build_name': 'dwm_query_probe_v1',
                 'iterator_variant': 'Corrected', 'iterator_sha256': p.CORRECTED_ITERATOR,
                 'consumer_sdk_receipt_sha256': p.digest(sdk_path), 'consumer_sdk_library_sha256': 'a'*64,
                 'template': p.identity(old / 'DWM.exe')}
        bp = self.evidence / 'native-build/build-receipt.json'
        p.write(bp, build)
        p.write(old / 'diagnostic-origin.json', {'game_commit': p.GAME_COMMIT, 'native_build': build,
                                              'native_build_receipt_sha256': p.digest(bp)})
        validation = {'ok': True, 'diagnostic': True, 'commit': p.GAME_COMMIT,
                      'engine_banner': '4.6.3.stable.dwm_query_probe_v1.35e80b3a8', 'files': p.manifest(old)}
        p.write(old / 'validation.json', validation)
        self.archive = self.root / p.ARCHIVE_NAME
        with zipfile.ZipFile(self.archive, 'w') as z:
            for name in p.census(old):
                z.write(old / name, name)
        validation['archive'] = dict(file=p.ARCHIVE_NAME, **p.identity(self.archive))
        p.write(self.evidence / 'native-diagnostic/validation.json', validation)
        self.pck = self.root / 'new.pck'
        self.pck.write_bytes(b'instrumented')
        self.source_manifest = self.root / 'source.json'
        p.write(self.source_manifest, {'base_commit': p.GAME_COMMIT, 'diagnostic': True,
                                      'files': [{'path': 'game.gd', 'before_sha256': None, 'after_sha256': 'b'*64}],
                                      'fresh_pck': p.identity(self.pck)})
        self.out = self.root / 'out'
        self.args = SimpleNamespace(original=self.archive, evidence=self.evidence, pck=self.pck,
                                    source_manifest=self.source_manifest, output=self.out)
        self.smoke = self.root / 'smoke.json'

    def prepare(self):
        with contextlib.redirect_stdout(io.StringIO()):
            p.prepare(self.args)

    def finish(self, **changes):
        smoke = {'ok': True, 'version': '4.6.3.stable.dwm_query_probe_v1.35e80b3a8', 'exit_code': 0,
                 'timed_out': False, 'isolated_profile_created': True,
                 'executable_sha256': p.digest(self.out / 'package/DWM.exe'),
                 'pck_sha256': p.digest(self.out / 'package/DWM.pck')}
        smoke.update(changes)
        p.write(self.smoke, smoke)
        with contextlib.redirect_stdout(io.StringIO()):
            p.finish(SimpleNamespace(output=self.out, smoke_result=self.smoke))

    def test_roundtrip_preserves_exe_notices_and_input(self):
        before = p.identity(self.archive)
        self.prepare()
        self.finish()
        self.assertEqual(before, p.identity(self.archive))
        result = p.read(self.out / 'validation.json')
        self.assertTrue(result['diagnostic'])
        self.assertFalse(result['pack_custody']['audit_reexecuted'])
        self.assertNotIn('pack_audit', result)
        self.assertEqual((self.out / 'package/DWM.exe').read_bytes(), b'retained exe')
        self.assertEqual((self.out / 'package/licenses/license.txt').read_bytes(), b'notice')
        extracted = self.root / 'check'
        p.extract(self.out / p.ARCHIVE_NAME, extracted)
        p.check_manifest(extracted, result['files'], ['validation.json'])

    def test_reject_changed_inner_archive(self):
        with self.archive.open('ab') as f:
            f.write(b'altered')
        with self.assertRaisesRegex(ValueError, 'digest/size'):
            self.prepare()

    def test_reject_changed_sdk_receipt(self):
        sdk = self.evidence / 'native-build/consumer-sdk-receipt.json'
        data = p.read(sdk)
        data['iterator_variant'] = 'Baseline'
        p.write(sdk, data)
        with self.assertRaisesRegex(ValueError, 'SDK linkage'):
            self.prepare()

    def test_reject_wrong_export(self):
        self.pck.write_bytes(b'wrong')
        with self.assertRaisesRegex(ValueError, 'Fresh PCK'):
            self.prepare()

    def test_reject_smoke_for_old_pack(self):
        self.prepare()
        with self.assertRaisesRegex(ValueError, 'fresh EXE/PCK'):
            self.finish(pck_sha256='c'*64)
        self.assertFalse((self.out / p.ARCHIVE_NAME).exists())

    def test_reject_timeout(self):
        self.prepare()
        with self.assertRaisesRegex(ValueError, 'smoke failed'):
            self.finish(timed_out=True)

    def test_reject_package_mutation_during_smoke(self):
        self.prepare()
        (self.out / 'package/licenses/license.txt').write_bytes(b'modified')
        with self.assertRaisesRegex(ValueError, 'bytes mismatch'):
            self.finish()

    def test_reject_unlisted_file(self):
        self.prepare()
        (self.out / 'package/extra.dll').write_bytes(b'new')
        with self.assertRaisesRegex(ValueError, 'census'):
            self.finish()

    def test_unsafe_and_colliding_archives(self):
        for names in [['../escape'], ['DWM.exe', 'dwm.EXE'], ['x\\y'], ['CON.txt']]:
            with self.subTest(names=names):
                evil = self.root / 'evil.zip'
                with zipfile.ZipFile(evil, 'w') as z:
                    for name in names:
                        z.writestr(name, 'bad')
                with self.assertRaises(ValueError):
                    p.extract(evil, self.root / 'evil-output')


if __name__ == '__main__':
    unittest.main()
