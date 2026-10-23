import base64,collections,hashlib,json,pathlib,re,subprocess,zipfile,xml.etree.ElementTree as ET
root=pathlib.Path(__file__).resolve().parent
archive=root/'qualification.zip'
with zipfile.ZipFile(archive) as z:
 assert not z.testzip()
 assert len(z.namelist())==len(set(z.namelist()))
 for n in z.namelist():
  p=pathlib.PurePosixPath(n);assert not p.is_absolute() and '..' not in p.parts and '\\' not in n
 z.extractall(root/'extracted')
r=root/'extracted';m=json.loads((r/'ci/retained-hashes.json').read_text())
for p,v in m.items():
 data=(r/p).read_bytes();assert len(data)==v['bytes'] and hashlib.sha256(data).hexdigest()==v['sha256'],p
assert set(m)|{'ci/retained-hashes.json'}==set(z.namelist())
origin=json.loads((r/'ci/audit-origin.json').read_text(encoding='utf-8-sig'));assert origin['candidate']=='49807a69e6c9b491224813fe317c3859f4a0c11a'
assert origin['tree']=='c7d83eedae64c67fabbde16b87bd3e902947bc08'
assert origin['controller']=='f5ad950df315d6ae954950a899922dc8c9afba13'
script='tests/unit/tooling/test_public_surface_inventory.gd'
expected=re.findall(r'^func (test_\w+)\(', (r/'ci/source'/script).read_text(),re.M)
t=ET.parse(r/'ci/public_surfaces.xml');rows=t.findall('.//testcase')
assert collections.Counter((x.get('classname'),x.get('name')) for x in rows)==collections.Counter((script,n) for n in expected)
assert not any(t.findall('.//'+x) for x in ['failure','error','skipped'])
assert all(x.get('status')=='pass' and int(x.get('assertions'))>0 for x in rows)
receipts=[]
for p in (r/'ci').rglob('*.jsonl'):
 for l in p.read_text(encoding='utf-8-sig').splitlines():
  if l.strip():
   d=json.loads(l);assert d['exit_code']==0;receipts.append(d)
assert len(receipts)==5 and len({x['test_root'] for x in receipts})==5
for p in (r/'phase2r_logs').glob('*.log'):
 assert not re.search('SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character',p.read_text(encoding='utf-8-sig')),p
source={}
for p in (r/'ci/source').rglob('*'):
 if p.is_file():
  b=p.read_bytes();rel=p.relative_to(r/'ci/source').as_posix();source[rel]=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
report={'archive_bytes':archive.stat().st_size,'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'manifest_members':len(m),'zip_members':len(z.namelist()),'tests':len(rows),'assertions':sum(int(x.get('assertions')) for x in rows),'clean_exits':len(receipts),'origin':origin,'source_git_blobs':source}
(root/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
