import base64,collections,hashlib,json,pathlib,re,sys,xml.etree.ElementTree as ET,zipfile
prefix='original';root=pathlib.Path.cwd()
import urllib.request
original=urllib.request.urlopen('https://raw.githubusercontent.com/Siuuuers/dwm/7e68a0d64da49f596a176238a0e28de9250c9617/evidence/phase_2r/clock_layout_20261016/final-original.zip').read()
(root/'original.b64').write_text(base64.b64encode(original).decode(),encoding='utf-8')
(root/'original-meta.json').write_text('{"bytes":743552,"sha256":"09ee7b6cfaaeb7e881a4e30d7f5b8f8addeae2aee9f2dbba150983f35740a4a9"}',encoding='utf-8')
raw=base64.b64decode((root/(prefix+'.b64')).read_text());meta=json.loads((root/(prefix+'-meta.json')).read_text())
assert len(raw)==meta['bytes'] and hashlib.sha256(raw).hexdigest()==meta['sha256']
zip_path=root/(prefix+'.zip');zip_path.write_bytes(raw)
with zipfile.ZipFile(zip_path) as z:
 m=json.loads(z.read('ci/retained-hashes.json'))
 for p,v in m.items():
  b=z.read(p);assert len(b)==v['bytes'] and hashlib.sha256(b).hexdigest()==v['sha256'],p
 result={'zip':meta,'manifest_members':len(m),'origin':json.loads(z.read('ci/audit-origin.json')),'suites':[]}
 for lane,script,select in [('transport','tests/unit/test_witnessed_transport_rail.gd',''),('clock-rendered','tests/integration/test_scene_clock_layout.gd',''),('caption-clear','tests/integration/test_witnessed_caption_runtime.gd','test_clear_holds_empty_without_finishing_a_hidden_incomplete_reveal'),('dating-scroll','tests/integration/test_dating_caption_style.gd','test_long_dating_caption_stays_centered_and_scrollable_with_both_scrollbar_sizes')]:
  expected=[n for n in re.findall(r'^func (test_\w+)\(',z.read('ci/source/'+script).decode(),re.M) if select in n]
  doc=ET.fromstring(z.read('ci/'+lane+'.xml'));cases=list(doc.iter('testcase'))
  assert collections.Counter((r.attrib['classname'],r.attrib['name']) for r in cases)==collections.Counter((script,n) for n in expected),lane
  assert not any(list(doc.iter(t)) for t in ['failure','error','skipped']),lane
  assert all(c.attrib.get('status')=='pass' and int(c.attrib['assertions'])>0 for c in cases),lane
  log=z.read('phase2r_logs/'+lane+'.log').decode('utf-8-sig');assert not re.search(r'SCRIPT ERROR:|ERROR:',log),lane
  children=[json.loads(s) for s in z.read('ci/'+lane+'.jsonl').decode('utf-8-sig').splitlines() if s.strip()]
  assert len(children)==1 and children[0]['exit_code']==0,lane
  result['suites'].append({'lane':lane,'tests':len(cases),'assertions':sum(int(c.attrib['assertions']) for c in cases)})
 clock_log=z.read('phase2r_logs/routine-clock.log').decode('utf-8-sig')
 assert 'ROUTINE_CLOCK_PASS' in clock_log and not re.search(r'SCRIPT ERROR:|ERROR:',clock_log)
 assert json.loads(z.read('ci/routine-clock.jsonl').decode('utf-8-sig').strip())['exit_code']==0
 title=json.loads(z.read('ci/title-shell/result.json'));assert title['passed']
 result['title_shell_summaries']=title['test_summaries']
 result['routine_clock']='passed with exit 0'
 result['tests']=sum(x['tests'] for x in result['suites']);result['assertions']=sum(x['assertions'] for x in result['suites'])
 assert result['tests']==15
 result['status']=z.read('ci/final-status.txt').decode()
 result['captures']=[p for p in z.namelist() if p.endswith('.png')]
 assert len(result['captures'])==3,result['captures']
 z.extractall(root/prefix)
 (root/(prefix+'-verified.json')).write_text(json.dumps(result,indent=2))
 print(json.dumps(result,indent=2))

for path in result['captures']:
 assert path.startswith('ci/computer-clock-')
with zipfile.ZipFile(zip_path) as z:
 origin=json.loads(z.read('ci/audit-origin.json'))
 assert origin['candidate']=='f67a17fb4f6aed3ed25c0c5194a51f5c6bc59133' and origin['tree']=='a7d65ecf14a0a0c437ed318ecdc9ae8f2133ee57'
 sources=[p for p in z.namelist() if p.startswith('ci/source/')]
 assert len(sources)==12
 for p in sources:
  remote=urllib.request.urlopen('https://raw.githubusercontent.com/Siuuuers/dwm/f67a17fb4f6aed3ed25c0c5194a51f5c6bc59133/'+p.removeprefix('ci/source/')).read()
  assert remote==z.read(p),p
result['source_files_verified']=len(sources)
result['verified_original_run']=38908745202
result['scope']='verification only; no engine or PowerShell tests repeated'
(root/'verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('CLOCK_EVIDENCE_VERIFIED '+json.dumps(result))
