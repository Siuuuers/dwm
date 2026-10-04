"""Reconstruct the hash-verified evidence ZIPs from bounded transport parts."""
import argparse
import hashlib
import json
import lzma
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent
manifest = json.loads((root / 'archive-delivery.json').read_text())
for archive in manifest['archives']:
    chunks = []
    for part in archive['parts']:
        data = (root / part['path']).read_bytes()
        assert len(data) == part['bytes']
        assert hashlib.sha256(data).hexdigest() == part['sha256']
        chunks.append(data)
    encoded = b''.join(chunks)
    assert hashlib.sha256(encoded).hexdigest() == archive['encoded_sha256']
    raw = lzma.decompress(encoded)
    assert len(raw) == archive['bytes']
    assert hashlib.sha256(raw).hexdigest() == archive['sha256']
    destination = args.output / archive['path']
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        assert destination.read_bytes() == raw, f'Refusing to replace {destination}'
    else:
        destination.write_bytes(raw)
    print(f'Verified {destination}')
