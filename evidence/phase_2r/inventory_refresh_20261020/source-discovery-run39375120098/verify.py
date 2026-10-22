import hashlib
import io
import json
import re
import sys
import zipfile
from pathlib import Path

archive = Path(sys.argv[1])
expected_digest = sys.argv[2].removeprefix('sha256:')
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
assert digest == expected_digest, 'Original artifact digest mismatch'
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    names = z.namelist()
    assert len(names) == len(set(names)), 'Duplicate archive members'
    assert all(not n.startswith('/') and '..' not in n.split('/') for n in names)
    manifest = [{'path': n, 'bytes': z.getinfo(n).file_size, 'sha256': hashlib.sha256(z.read(n)).hexdigest()} for n in names if not n.endswith('/')]
    def read(suffix):
        matches = [n for n in names if n == suffix or n.endswith('/' + suffix)]
        assert len(matches) == 1, (suffix, matches)
        return z.read(matches[0])
    def text(suffix):
        return read(suffix).decode('utf-8-sig')
    def obj(suffix):
        return json.loads(text(suffix))
    origin = obj('discovery/origin.json')
    assert origin['source'] == 'e55254dbbafbbfe90f0adc9098e9ca2b79c14708'
    assert origin['tree'] == 'e166e051cc5a19c5996f6d70d5c6f0005c5d4be7'
    assert origin['controller'] == 'cd494d3463b117720b7b5755007fbc5f952bfea8'
    assert origin['fresh_cache'] is True
    for name in ['import-process.json', 'probe-process.json', 'post-export-probe-process.json']:
        assert obj('discovery/' + name)['exit_code'] == 0
    canonical = {'EndingScene': 'res://scripts/ui/EndingScene.gd', 'SaveManagerCheckpointPort': 'res://scripts/application/run/SaveManagerCheckpointPort.gd'}
    maps = {}
    for name in ['import-global_script_class_cache.cfg', 'global_script_class_cache.cfg', 'post-export-global_script_class_cache.cfg']:
        value = text('discovery/' + name)
        assert 'res://evidence/phase_2r/title_timing_20261019/source/' not in value
        blocks = re.findall(r'\{(.*?)\}', value, re.S)
        found = {}
        for klass, path in canonical.items():
            rows = [b for b in blocks if re.search(r'"class"\s*:\s*&?"' + klass + '"', b)]
            assert len(rows) == 1, (name, klass, len(rows))
            assert re.search(r'"path"\s*:\s*"' + re.escape(path) + '"', rows[0]), (name, klass)
            found[klass] = path
        maps[name] = found
    error_pattern = re.compile(r'SCRIPT ERROR:|^\s*ERROR:|STARTUP_FAILED|Unicode parsing error|Unexpected NUL character', re.M)
    log_names = ['import.log', 'discovery/probe.log', 'discovery/post-export-probe.log']
    log_names += ['windows-export/' + n for n in ['version.console.log', 'export.console.log', 'export.log', 'smoke.console.log', 'smoke.log', 'pack-audit.console.log', 'pack-audit.log']]
    for name in log_names:
        assert not error_pattern.search(text(name)), name
    for name in ['discovery/probe.log', 'discovery/post-export-probe.log']:
        assert 'DISCOVERY_AND_RAW_EVIDENCE_VERIFIED count=20' in text(name)
    report = obj('windows-export/validation.json')
    assert report['ok'] is True and report['smoke']['ok'] is True and report['pack_audit']['ok'] is True
    assert report['commit'] == origin['source'] and report['ci_event_commit'] == origin['event']
    assert report['smoke']['isolated_profile_created'] is True
    count = report['runtime_data_files_verified']
    assert count > 0 and count == report['pack_audit']['runtime_data_files_verified']
    assert 'WINDOWS_PACK_DATA_VERIFIED count=' + str(count) in text('windows-export/pack-audit.log')
    assert report['templates_sha256'] == '3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8'
    package_bytes = read('windows-export/DWM-windows-x86_64-validation.zip')
    package_digest = hashlib.sha256(package_bytes).hexdigest()
    assert package_digest == report['archive']['sha256'] and len(package_bytes) == report['archive']['bytes']
    assert text('windows-export/SHA256SUMS.txt').split()[0] == package_digest
    with zipfile.ZipFile(io.BytesIO(package_bytes)) as package:
        assert package.testzip() is None
        package_names = package.namelist()
        assert len(package_names) == len(set(package_names))
        for entry in report['files']:
            data = package.read(entry['path'])
            assert len(data) == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
        expected = {row['path'] for row in report['files']} | {'validation.json'}
        assert set(n for n in package_names if not n.endswith('/')) == expected
        assert {'DWM.exe','DWM.pck','licenses/Godot/LICENSE.txt','licenses/Godot/THIRD-PARTY-NOTICES.json'} <= expected
        inner = json.loads(package.read('validation.json').decode('utf-8-sig'))
        assert inner == {k:v for k,v in report.items() if k != 'archive'}
    result = {'ok': True, 'original_artifact': {'sha256': digest, 'bytes': archive.stat().st_size}, 'origin': origin, 'canonical_maps': maps, 'raw_evidence_records_each_probe': 20, 'explicit_zero_exit_receipts': 3, 'strict_logs_checked': log_names, 'runtime_data_files_verified': count, 'package': report['archive'], 'package_files': report['files'], 'manifest': manifest, 'limitations': ['Unchanged helper enforces subprocess success exits but does not retain separate successful exit receipts for every subprocess.', 'No rendered ending, Title, normal Load clean exit, performance or release acceptance.']}
Path(sys.argv[3]).write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k:result[k] for k in ['ok','original_artifact','runtime_data_files_verified','package']}))
