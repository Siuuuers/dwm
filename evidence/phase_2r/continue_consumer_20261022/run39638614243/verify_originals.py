"""Verify retained original ZIP bytes without engine or PowerShell execution."""
from pathlib import Path
import hashlib
import io
import json
import zipfile
root = Path(__file__).resolve().parent
artifacts = {a['name'] + '.zip': a for a in json.loads((root / 'artifacts.json').read_text())['artifacts']}
for archive in json.loads((root / 'originals/parts.json').read_text()):
    chunks = []
    for part in archive['parts']:
        data = (root / part['path']).read_bytes()
        assert len(data) == part['size']
        assert hashlib.sha256(data).hexdigest() == part['sha256']
        assert hashlib.sha1(('blob ' + str(len(data)) + '\0').encode() + data).hexdigest() == part['git_blob']
        chunks.append(data)
    data = b''.join(chunks)
    actual = artifacts[archive['file']]
    assert len(data) == archive['size'] == actual['size_in_bytes']
    assert 'sha256:' + hashlib.sha256(data).hexdigest() == actual['digest']
    assert hashlib.sha256(data).hexdigest() == archive['sha256']
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        assert len(z.namelist()) == archive['members']
        assert z.testzip() is None
        assert all(not p.startswith('/') and '..' not in Path(p).parts for p in z.namelist())
    print(archive['file'], 'verified')
