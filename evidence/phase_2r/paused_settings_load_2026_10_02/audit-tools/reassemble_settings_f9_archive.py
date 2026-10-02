"""Reassemble and verify one immutable multipart evidence archive."""
from pathlib import Path
import argparse, hashlib, json

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('manifest',type=Path); p.add_argument('--output',type=Path,required=True)
a=p.parse_args(); m=json.loads(a.manifest.read_text()); chunks=[]
for record in m['parts']:
    name=record['file']
    if Path(name).name!=name or '\\' in name: raise ValueError('Unsafe part name')
    raw=(a.manifest.parent/name).read_bytes()
    if len(raw)!=record['bytes'] or hashlib.sha256(raw).hexdigest()!=record['sha256']: raise ValueError('Part identity mismatch: '+name)
    chunks.append(raw)
raw=b''.join(chunks)
if len(raw)!=m['bytes'] or hashlib.sha256(raw).hexdigest()!=m['sha256']: raise ValueError('Archive identity mismatch')
if a.output.exists() and a.output.read_bytes()!=raw: raise ValueError('Refusing to replace a differing output')
a.output.parent.mkdir(parents=True,exist_ok=True); a.output.write_bytes(raw)
print(json.dumps({'archive':str(a.output),'bytes':len(raw),'sha256':m['sha256'],'verified':True}))
