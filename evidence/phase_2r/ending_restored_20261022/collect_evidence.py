from pathlib import Path
import hashlib, json, urllib.request, zipfile

root = Path(__file__).parent / 'run39762896961'
root.mkdir(exist_ok=True)
downloads = json.loads((root.parent / 'downloads.json').read_text())
parts = []
for row in downloads:
    archive = root / (str(row['id']) + '.zip')
    urllib.request.urlretrieve(row['url'], archive)
    data = archive.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    assert digest == row['digest'].removeprefix('sha256:'), (archive, digest)
    target = root / str(row['id'])
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for member in z.infolist():
            resolved = (target / member.filename).resolve()
            assert resolved.is_relative_to(target.resolve())
        z.extractall(target)
    chunks = []
    for i, start in enumerate(range(0, len(data), 512 * 1024)):
        chunk = data[start:start + 512 * 1024]
        path = archive.with_name(archive.name + '.part%03d' % i)
        path.write_bytes(chunk)
        chunks.append({'file': path.name, 'bytes': len(chunk), 'sha256': hashlib.sha256(chunk).hexdigest(), 'blob': hashlib.sha1(b'blob ' + str(len(chunk)).encode() + b'\0' + chunk).hexdigest()})
    parts.append({'id': row['id'], 'name': row['name'], 'file': archive.name, 'bytes': len(data), 'sha256': digest, 'parts': chunks})
(root / 'parts.json').write_text(json.dumps(parts, indent=2) + '\n')
print(json.dumps([{'id': r['id'], 'bytes': r['bytes'], 'sha256': r['sha256'], 'parts': len(r['parts'])} for r in parts]))
