# Original cloud evidence

Both Windows runs succeeded. `inspection.json` records original archive digests, CRC verification and XML results. `audit-origin.json` records tested product and controller identities.

- Backup: run39958419154/original.zip; SHA-256 `07023003f446ff83a108cf94a97ff6123c0556c23c2abacbf7de771f97737bc7`.
- Current CI: concatenate run39960111488/original.zip.part0 through part3 in numerical order. Reconstructed size 12637156 bytes; SHA-256 `56d6a5634d3b10eb37c85389a8c5510657c80c7d74f32bd25493ec8cb57093d7`.

Portable reconstruction, run from this directory:

```python
from pathlib import Path
import hashlib, zipfile
p = Path('run39960111488')
b = b''.join((p / f'original.zip.part{i}').read_bytes() for i in range(4))
assert len(b) == 12637156
assert hashlib.sha256(b).hexdigest() == '56d6a5634d3b10eb37c85389a8c5510657c80c7d74f32bd25493ec8cb57093d7'
(p / 'original.zip').write_bytes(b)
with zipfile.ZipFile(p / 'original.zip') as z:
    assert z.testzip() is None
```

The Backup baseline XML deliberately contains one failed test: it demonstrates the retention regression on the old source. The cloud workflow checks that only expected retention assertions fail. All candidate cases passed. See the qualified handoff for scope and unresolved master acceptance.
