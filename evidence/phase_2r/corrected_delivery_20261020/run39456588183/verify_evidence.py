import gzip
import hashlib
import io
import json
from pathlib import Path
import struct
import zipfile

ROOT = Path(__file__).parent
sha = lambda b: hashlib.sha256(b).hexdigest()
read_json = lambda z, n: json.loads(z.read(n).decode('utf-8-sig'))
archives = {}
for name, expected, manifest in [
    ('preparation-original.zip', '2fb26f5e4524115d1ee131f2c3f6f131c152214b579cc08e40f8f0676fb18090', 'evidence-file-hashes.json'),
    ('delivery-original.zip', 'db3ffefd94c8c5873134608045213849d2ce469e63d00736f800bcd16f7cf08a', 'delivery/evidence-manifest.json')]:
    data = (ROOT / name).read_bytes()
    assert sha(data) == expected
    z = zipfile.ZipFile(io.BytesIO(data))
    assert z.testzip() is None
    files = read_json(z, manifest)['files']
    assert len(z.namelist()) == len(set(z.namelist()))
    assert set(z.namelist()) == {f['path'].replace('\\', '/') for f in files} | {manifest}
    for f in files:
        b = z.read(f['path'].replace('\\', '/'))
        assert len(b) == f['bytes'] and sha(b) == f['sha256']
    archives[name] = {'sha256': expected, 'bytes': len(data), 'manifest_payloads_verified': len(files), 'members': len(z.namelist())}

p = zipfile.ZipFile(ROOT / 'preparation-original.zip')
d = zipfile.ZipFile(ROOT / 'delivery-original.zip')
previous = {x['path']: x for x in read_json(p, 'generated-import.json')['entries']}
final = {x['path']: x for x in read_json(p, 'generated-final.json')['entries']}
assert all(final[k]['bytes']['sha256'] == v['bytes']['sha256'] for k, v in previous.items())
added = []
for path in sorted(final.keys() - previous.keys()):
    entry = final[path]
    data = p.read('final/' + entry['bytes']['file'])
    assert len(data) == entry['bytes']['size'] and sha(data) == entry['bytes']['sha256']
    added.append({'path': path, 'source': entry['source'], 'source_blob': entry['source_blob'],
                  'text': data.decode(), 'bytes': len(data), 'sha256': sha(data), 'classification': entry['classification']})
validation = read_json(d, 'windows-export/validation.json')
package_bytes = d.read('windows-export/DWM-windows-x86_64-validation.zip')
assert sha(package_bytes) == validation['archive']['sha256']
assert len(package_bytes) == validation['archive']['bytes']
package = zipfile.ZipFile(io.BytesIO(package_bytes))
assert package.testzip() is None
for entry in validation['files']:
    b = package.read(entry['path'])
    assert len(b) == entry['bytes'] and sha(b) == entry['sha256']
pck = package.read('DWM.pck')
directory = json.loads(gzip.decompress((ROOT / 'pck-directory.json.gz').read_bytes()))
for entry in directory['entries']:
    b = pck[entry['offset']:entry['offset'] + entry['size']]
    assert len(b) == entry['size'] and hashlib.md5(b).hexdigest() == entry['md5']
paths = {e['path'] for e in directory['entries']}
uid_entry = next(e for e in directory['entries'] if e['path'] == '.godot/uid_cache.bin')
cache = pck[uid_entry['offset']:uid_entry['offset'] + uid_entry['size']]
# Godot 4.6.3 core/io/resource_uid.cpp ResourceUID::load_from_cache:
# u32 count, repeated u64 ID + u32 UTF-8 byte length + path bytes.
count = struct.unpack_from('<I', cache)[0]
offset, cache_entries = 4, []
for _ in range(count):
    uid, size = struct.unpack_from('<QI', cache, offset)
    offset += 12
    path = cache[offset:offset + size].decode()
    offset += size
    cache_entries.append({'uid': str(uid), 'path': path})
assert offset == len(cache)
for entry in added:
    entry['source_is_pack_entry'] = entry['source'] in paths
    entry['sidecar_is_pack_entry'] = entry['path'] in paths
    entry['uid_cache_records'] = [c for c in cache_entries if c['path'] == 'res://' + entry['source']]
result = {'run': 39456588183, 'job': 118744955669, 'archives': archives,
          'first_failed_step': 'Always verify preparation after exporter before native phases',
          'failure': read_json(p, 'final-failure.json'), 'phase_summary': read_json(p, 'phase-summary.json'),
          'import_generated_count': len(previous), 'final_generated_count': len(final),
          'previous_generated_bytes_unchanged': True, 'generated_additions': added,
          'final_tracked_change_count': read_json(p, 'final/changes.json')['worktree_changed_count'],
          'final_index_change_count': read_json(p, 'final/changes.json')['index_changed_count'],
          'package_archive': validation['archive'], 'package_members_verified': len(validation['files']),
          'smoke': validation['smoke'], 'pack_audit': validation['pack_audit'],
          'pck_entries_md5_verified': len(paths), 'uid_cache_records': count,
          'test_pack_entries': sorted(x for x in paths if x.startswith('tests/')),
          'limitation': 'UID-cache references are packaged metadata; absence of resource entries does not prove no runtime influence or permit acceptance. No native journey ran.'}
(ROOT / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
(ROOT / 'job.log.gz').write_bytes(gzip.compress((ROOT / 'job.log').read_bytes(), mtime=0))
print(json.dumps(result, indent=2))
