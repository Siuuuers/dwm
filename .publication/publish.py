import concurrent.futures, gzip, hashlib, io, json, os
from pathlib import Path
import subprocess, tarfile

def run(*args, **kwargs):
    return subprocess.check_output(args, **kwargs)

seed = Path(__file__).resolve().parent
root = Path(os.environ['RUNNER_TEMP']) / 'hold-final'
base = 'c8303aa4cf076946f870089e7e408e5e1bddca87'
run('git', 'worktree', 'add', '--detach', str(root), base)
run('git', 'apply', str(seed/'records.patch'), cwd=root)
payload = {}
raw = b''.join(p.read_bytes() for p in sorted(seed.glob('records.part*')))
assert hashlib.sha256(raw).hexdigest()=='b674fa8e3fbedd79b39af7a1e53842bf5d036d88f381fbd41a8b3818eca7c2cb'
with tarfile.open(fileobj=io.BytesIO(raw), mode='r:gz') as tar:
    for m in tar.getmembers():
        assert m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts
        payload[m.name] = tar.extractfile(m).read()
artifacts = json.loads(payload['api-artifacts.json'])
inventory = json.loads(payload['artifact-inventory.json'])
def download(a):
    expected = next(r for r in artifacts if r['id']==a['id'])
    raw = run('gh','api',f"repos/Siuuuers/dwm/actions/artifacts/{a['id']}/zip")
    assert len(raw)==a['bytes']==expected['size_in_bytes']
    assert hashlib.sha256(raw).hexdigest()==a['sha256']==expected['digest'][7:]
    return a['path'],raw
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for path, raw in pool.map(download,inventory): payload[path]=raw
for row in json.loads(payload['payload-inventory.json']):
    raw=payload[row['path']]
    assert len(raw)==row['bytes'] and hashlib.sha256(raw).hexdigest()==row['sha256']
out=root/'evidence/phase_2r/timed_hold_2026_10_03/broad1'
manifest=json.loads((out/'package-manifest.json').read_text())
archive=io.BytesIO()
with gzip.GzipFile(filename='broad1-evidence.tar',mode='wb',fileobj=archive,compresslevel=6,mtime=1791005179) as gz:
    with tarfile.open(fileobj=gz,mode='w') as tar:
        for name,raw in sorted(payload.items()):
            m=tarfile.TarInfo(name);m.size=len(raw);m.mode=0o644;m.mtime=0
            tar.addfile(m,io.BytesIO(raw))
raw=archive.getvalue()
assert len(raw)==manifest['archive']['bytes']
assert hashlib.sha256(raw).hexdigest()==manifest['archive']['sha256']
for part in manifest['parts']:
    piece=raw[part['offset']:part['offset']+part['bytes']]
    assert hashlib.sha256(piece).hexdigest()==part['sha256']
    (out/part['file']).write_bytes(piece)
print(run('python3',str(out/'verify_package.py'),cwd=root).decode())
run('git','add','--all',cwd=root)
tree=run('git','write-tree',cwd=root).decode().strip()
assert tree=='4b25f8fa4ab31aa0c048e1f27dba157f59bcf4b2',tree
commit=run('git','commit-tree',tree,'-p',os.environ['GITHUB_SHA'],'-m',
           'Accept audited captionless timed hold and preserve exact cloud evidence',cwd=root).decode().strip()
run('git','push','origin',commit+':refs/heads/codex/timed-hold-publication-20261003',cwd=root)
print(json.dumps({'verified_tree':tree,'commit':commit,'original_artifact_zips':len(inventory),'engine_executed':False}))
