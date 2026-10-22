#!/usr/bin/env python3
"""Offline archive/provenance verification; executes Python analysis only."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent
ARCHIVES = {
    'native-evidence.zip': 'd0158510fdbd04052d8d1ce21687ece9c9a081f15c9d87a0c01a2f0b4a7f1cb6',
    'sdk.zip': 'fd87e19427ec4aa81634473a2ca54319cb088cbb69c9516f9a1e5a51d0db25aa',
}
TOOL = Path('tools/diagnostics/ending-publication-20261019')


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def require(ok, message):
    if not ok:
        raise ValueError(message)


def safe(name):
    path = PurePosixPath(name)
    require(bool(name) and not path.is_absolute() and '..' not in path.parts
            and '\\' not in name and ':' not in name, 'Unsafe archive/manifest path: ' + name)
    return path


def main():
    report = {'schema_version': 1, 'verification_ok': False,
        'official_acceptance_established': False,
        'scope': 'Retained byte integrity and reproducible offline analysis only; no native execution.',
        'archives': {}, 'retained_hashes': {'verified': [], 'unavailable': [], 'mismatched': []},
        'errors': []}
    try:
        sources = json.loads((ROOT/'offline-source-sha256.json').read_text())
        for name, expected in sources.items():
            safe(name)
            require(digest(ROOT/name) == expected, 'Offline source/reference hash mismatch: ' + name)
        report['offline_source_hashes_verified'] = len(sources)
        with tempfile.TemporaryDirectory(prefix='dwm-consumer-verify-') as temporary:
            work = Path(temporary)
            for name, expected in ARCHIVES.items():
                archive = ROOT/name
                require(digest(archive) == expected, 'Archive SHA256 mismatch: ' + name)
                destination = work/Path(name).stem
                with zipfile.ZipFile(archive) as z:
                    names = z.namelist()
                    require(len(names) == len(set(names)), 'Duplicate ZIP path: ' + name)
                    for member in z.infolist():
                        safe(member.filename)
                        require(not stat.S_ISLNK(member.external_attr >> 16), 'ZIP symlink: ' + member.filename)
                    require(z.testzip() is None, 'ZIP CRC failure: ' + name)
                    z.extractall(destination)
                report['archives'][name] = {'sha256': expected, 'entries': len(names), 'safe_paths': True, 'crc_ok': True}
            original = work/'native-evidence'
            manifest = json.loads((original/'retained-hashes.json').read_bytes())
            for name, expected in manifest.items():
                safe(name)
                relative = name.removeprefix('ci/')
                selected = original/relative
                location = 'native-evidence.zip'
                if not selected.is_file() and relative.startswith('consumer-sdk/'):
                    selected = work/'sdk'/relative.removeprefix('consumer-sdk/')
                    location = 'sdk.zip'
                if not selected.is_file():
                    report['retained_hashes']['unavailable'].append(name)
                    continue
                actual = {'sha256': digest(selected), 'bytes': selected.stat().st_size}
                target = 'verified' if actual == expected else 'mismatched'
                report['retained_hashes'][target].append({'path': name, 'archive': location, **actual})
            require(not report['retained_hashes']['mismatched'], 'Retained manifest bytes differ')
            report['retained_hashes']['total_entries'] = len(manifest)
            report['retained_hashes']['all_entries_available'] = not report['retained_hashes']['unavailable']
            # Keep original extraction intact. The correction runs on a disposable copy.
            corrected = work/'offline-copy'
            shutil.copytree(original, corrected)
            binder = ROOT/'offline-source'/TOOL/'consumer_analysis/bind_consumer.py'
            executed = subprocess.run([sys.executable, str(binder), '--evidence', str(corrected),
                '--allow-pre-banner-analysis'], capture_output=True, text=True, timeout=120)
            report['binder'] = {'exit_code': executed.returncode, 'stdout': executed.stdout, 'stderr': executed.stderr}
            require(executed.returncode == 0, 'Corrected binder failed')
            reproduced = json.loads((corrected/'consumer-binding-offline-correction.json').read_text())
            retained = json.loads((ROOT/'consumer-binding-offline-correction.json').read_text())
            require(reproduced == retained, 'Reproduced report differs logically from retained report')
            require(reproduced['binding_ok'] is True and reproduced['official_acceptance_established'] is False,
                'Unexpected corrected binder qualification')
            report['binder'].update(logically_matches_retained=True,
                selected_observations=len(reproduced['selected_observations']),
                original_report_unchanged=digest(original/'consumer-binding.json') == digest(corrected/'consumer-binding.json'))
            require(report['binder']['original_report_unchanged'], 'Original binder report changed')
            test = subprocess.run([sys.executable, str(binder.with_name('test_consumer.py')), '-v'],
                capture_output=True, text=True, timeout=120)
            (ROOT/'synthetic-tests.log').write_text(test.stdout+test.stderr, encoding='utf-8')
            report['synthetic_tests'] = {'exit_code': test.returncode, 'log': 'synthetic-tests.log',
                'log_sha256': digest(ROOT/'synthetic-tests.log'), 'native_execution': False}
            require(test.returncode == 0, 'Synthetic tests failed')
            report['verification_ok'] = True
    except Exception as error:
        report['errors'].append(type(error).__name__ + ': ' + str(error))
    (ROOT/'verification.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'verification_ok': report['verification_ok'], 'errors': report['errors'],
        'verified_manifest_entries': len(report['retained_hashes']['verified']),
        'unavailable_manifest_entries': len(report['retained_hashes']['unavailable'])}))
    return 0 if report['verification_ok'] else 2


if __name__ == '__main__':
    raise SystemExit(main())
