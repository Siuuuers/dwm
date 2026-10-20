"""Verify retained original cloud archive without running Godot or PowerShell."""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import struct
import zipfile

root = Path(__file__).resolve().parent
parts = sorted(root.glob('original.zip.part[0-9][0-9]'))
assert len(parts) == 13
data = b''.join(p.read_bytes() for p in parts)
digest = hashlib.sha256(data).hexdigest()
assert len(data) == 8818887
assert digest == '61f5eda1ce4b4ec7ecca5eda0764d6d0d2d9993892a40bdadcb921449770c5ee'
with zipfile.ZipFile(io.BytesIO(data)) as archive:
    names = archive.namelist()
    assert len(names) == len(set(names)) == 101
    assert archive.testzip() is None
    assert all(not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts for n in names)
    members = {n: {'bytes': len(archive.read(n)), 'sha256': hashlib.sha256(archive.read(n)).hexdigest()} for n in names}
    d = json.loads(archive.read('measurements.json'))
    provenance = json.loads(archive.read('provenance.json'))
    assert provenance == {'source': '7aee979d5d7e66d66169800f0cb619a3a259a1e8',
        'tree': 'f37214d64c0b4d9103c0c04b43c83fe041334b26',
        'controller': 'aab45ec60b5e92b6fa9d9cf5f808eb4ebafb1cb2',
        'workflow': '26fe33caabc7397499f9606347211a91245a11a1',
        'event': '26fe33caabc7397499f9606347211a91245a11a1', 'run_id': '39393228524', 'attempt': '1'}
    assert d['ok'] is True and not d['failures'] and d['checks'] == 542
    projected = {f'status-{font}-{locale}-{size}-{status}.png'
        for font in ('pixel', 'readable') for locale in ('en', 'zh_CN', 'zh_HK', 'ja', 'ko')
        for size in (100, 125, 150) for status in ('added', 'failed', 'uncertain')}
    actual = {n + '.png' for n in ('first-visible', 'second-visible-not-collectable', 'restarted-visible', 'failed-real', 'uncertain-real')}
    assert len(d['samples']) == 95 and {s['file'] for s in d['samples']} == projected | actual
    assert {n for n in names if n.endswith('.png')} == projected | actual
    for name in projected | actual:
        png = archive.read(name)
        assert png[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', png[16:24]) == (1280, 720)
    setup = d['setup_results']
    assert len(setup) == 23
    for receipt in setup:
        if receipt['stage'] == 'startup': assert receipt['result']['ready'] is True
        elif 'result' in receipt: assert receipt['result']['ok'] is True
    versions = next(r for r in setup if r['stage'] == 'version_selection')
    assert len(set(versions['versions'])) == 2 and versions['selected'] in versions['versions']
    context = next(r['context'] for r in setup if r['stage'] == 'return_context')
    assert context['record'] == 'ending.alone' and context['signature'] == versions['selected']
    assert context['index'] > 0 and context['paper'] > 0
    assert {r['attempt'] for r in d['publications']} == {1, 2, 3, 4, 5}
    for attempt in range(1, 6):
        first = next(r for r in d['publications'] if r['attempt'] == attempt and r['line_id'] == 'fixture.ending.first')
        assert first['publication']['ok'] is True and first['collected_line_ids'] == []
    for sample in d['samples']:
        if 'collection' in sample:
            assert sample['collection']['ok'] is True and sample['profile_and_run_unchanged'] is True
            assert [c['line_id'] for c in sample['collection']['value']['captions']] == ['fixture.ending.first']
    for phase in ('import', 'render'):
        assert json.loads(archive.read(phase + '-process.json'))['exit_code'] == 0
        log = archive.read(phase + '.log').decode('utf-8-sig')
        assert not re.search(r'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character|leaked', log, re.I)
    report = {'archive_bytes': len(data), 'archive_sha256': digest, 'provenance': provenance,
        'checks': d['checks'], 'samples': 95, 'setup_receipts': 23, 'attempts': 5,
        'process_exits': [0, 0], 'members': members,
        'parts': {p.name: {'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in parts}}
    (root / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
print('VERIFIED original archive: 101 members, 542 checks, 95 samples, 23 setup receipts, 5 attempts, exits 0/0')
