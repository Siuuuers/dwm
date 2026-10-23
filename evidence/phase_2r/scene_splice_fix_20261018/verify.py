import base64, hashlib, io, json, pathlib, re, sys, zipfile, xml.etree.ElementTree as ET
source=pathlib.Path(sys.argv[1]); out=pathlib.Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
if source.suffix=='.zip':
 raw=source.read_bytes();receipt={'bytes':3017358,'sha256':'c252c20ac31060426673326155da93def6a4298cb570d8e1edc7445bb752f004'}
else:
 log=source.read_text()
 receipt=json.loads(re.search(r'DWM_EVIDENCE_BEGIN (\{[^\r\n]+\})',log)[1])
 raw=base64.b64decode(''.join(re.findall(r'DWM_EVIDENCE_CHUNK ([A-Za-z0-9+/=]+)',log)),validate=True)
assert len(raw)==receipt['bytes'] and hashlib.sha256(raw).hexdigest()==receipt['sha256']
(out/'39132455733-evidence.zip').write_bytes(raw)
z=zipfile.ZipFile(io.BytesIO(raw));assert len(z.namelist())==len(set(z.namelist()))
def doc(path):return json.loads(z.read(path).decode('utf-8-sig'))
manifest=doc('ci/retained-hashes.json');assert set(z.namelist())==set(manifest)|{'ci/retained-hashes.json'}
for path,entry in manifest.items():
 data=z.read(path);assert len(data)==entry['bytes'] and hashlib.sha256(data).hexdigest()==entry['sha256'],path
origin=doc('ci/audit-origin.json')
assert origin['candidate']=='75aecb404cba8c2531cb5b944fd8ae75f2990347'
assert origin['tree']=='adffc2682d6ecf5fb1b6d35ee7595672123c3b74'
assert origin['controller']=='75b9fd18e8090c805f5050916e59b37d8160378a'
pins={}
for path in z.namelist():
 if path.startswith('ci/source/'):
  data=z.read(path);pins[path.removeprefix('ci/source/')]=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
assert pins['scripts/application/run/SaveManagerCheckpointPort.gd']=='9306b21bd1e92e1c81c25a709c89470b4e2d8179'
assert pins['tests/integration/test_scene_saved_event_anchor.gd']=='0c104ca0edb62f07baa5092af0f487e335e48fd3'
assert pins['tools/testing/Invoke-ExportedGameplay.ps1']=='3f715a4e503de5427175b2b819640c4dc221c504'
assert pins['autoload/GameState.gd']=='c015a954089738ccc4a805e351b51e0c4294210b'
assert pins['autoload/DialogicBridge.gd']=='6542701617c214f5de9486e7558da03c3c2b6787'
outcomes={};profiles={}
for prefix in ['baseline','exported']:
 for mode in ['capability','create','load']:
  folder=f'ci/{prefix}-{mode}/'
  if folder+'result.json' not in z.namelist():continue
  result=doc(folder+'result.json')
  for item in doc(folder+'manifest.json'):
   data=z.read(folder+item['file']);assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256']
  expected='193691f9dfa06aed698274cd1ce7346cee77857a' if prefix=='baseline' else origin['candidate']
  assert result['source_commit']==expected
  expected_hash='4291ba8bcc07a1077a4cea4f5b99f20c5352c5dbe15885a1523dd2b77922f237' if prefix=='baseline' else doc('ci/windows-export/validation.json')['archive']['sha256']
  assert result['archive_sha256']==expected_hash
  outcomes[f'{prefix}-{mode}']={k:result.get(k) for k in ['ok','failure','elapsed_seconds','exit_code','clean_player_exit','forced_cleanup','checkpoint_profile','archive_sha256']}
  if mode=='load':
   assert result['checkpoint_profile']
   records=[]
   for line in z.read(folder+'game.stdout.log').decode('utf-8-sig',errors='replace').splitlines():
    for marker in ['DWM_SAVE_LOAD_PROFILE ','DWM_CHECKPOINT_PROFILE ']:
     if marker in line:records.append(dict(prefix=marker.strip(),**json.loads(line.split(marker,1)[1])))
   profiles[prefix]=records
xml={}
for name in ['splice-baseline','scene-splice','checkpoint-port']:
 path=f'ci/{name}.xml'
 if path not in z.namelist():continue
 root=ET.fromstring(z.read(path));cases=list(root.iter('testcase'))
 xml[name]={'testcases':len(cases),'failures':[c.attrib.get('name') for c in cases if c.find('failure') is not None],'errors':len(list(root.iter('error'))),'skipped':len(list(root.iter('skipped'))),'assertions':sum(int(c.attrib.get('assertions',0)) for c in cases)}
report=dict(archive=receipt,origin=origin,verified_members=len(manifest),source_pins=pins,outcomes=outcomes,xml=xml,profiles=profiles)
(out/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['profiles','source_pins']},indent=2))
