from pathlib import Path
import json,hashlib,re,xml.etree.ElementTree as ET,datetime
root=Path(__file__).parent
prep_dirs=[d for d in root.iterdir() if d.is_dir() and (d/'preparation-origin.json').is_file()]
qualification_dirs=[d for d in root.iterdir() if d.is_dir() and (d/'ci/ending-load/selection.json').is_file()]
assert len(prep_dirs)==1 and len(qualification_dirs)==1, 'Exactly one extracted preparation and qualification artifact required'
p=prep_dirs[0];q=qualification_dirs[0];ci=q/'ci';packet=root.parent/'ending-equality-packet'
def read(f): return json.loads(f.read_text(encoding='utf-8-sig'))
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
def blob(f):
 b=f.read_bytes();return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
product='4278756add50ea27da8237106260a0efee606cda'
sources=read(packet/'source-manifest.json');assert len(sources)==14
count=0
for folder in ['import','restored','post-tests']:
 for f in (p/folder/'bytes').iterdir():
  assert sha(f)==f.name,(folder,f.name);count+=1
 baseline=read(p/folder/'before.json');assert baseline['head']==product
 for row in sources:
  assert baseline['head_entries'][row['path']]['oid']==row['blob']
  assert baseline['worktree'][row['path']]['sha256']==row['sha256']
  assert baseline['worktree'][row['path']]['git_blob']==row['blob']
  retained=p/folder/'bytes'/row['sha256']
  if retained.exists():assert blob(retained)==row['blob']
 changes=read(p/folder/'changes.json');assert changes['complete'] and changes['head']==changes['head_after']==product
 for change in changes['changes']:
  if change['index_changed']:assert change['path'] in ['.claude/skills/godot-prompter/1.10.0','.claude/skills/superpowers/6.1.1'] and change['index_before']['mode']=='160000' and change['index_after'] is None
  if change['worktree_changed']:assert folder=='import' and change['path']=='project.godot' and change['before']['sha256']=='5e8009d890f9e4359b24bb68a59fdec1bf56ef0a3ea94be06c3e43a6d2353053' and change['after']['sha256']=='6880d26a04484587a54c63e0a98072984b6adac7ac3e9d07e8d138e934428fdd'
for phase in ['before','import','restored','post-tests']:
 assert read(p/(phase+'-policy.json'))['passed']
 generated=read(p/('generated-'+phase+'.json'));assert not generated['rejected']
 assert {r['path']:(r['blob'],r['sha256']) for r in generated['observation_sources']}=={r['path']:(r['blob'],r['sha256']) for r in sources}
 if phase=='before':assert not generated['entries']
 else:
  for item in generated['entries']:
   if item['classification']=='focused_runtime_generated_uid':assert item['uid_comparisons_complete'] and not item['collisions'] and all(x['status']=='decoded' for x in item['uid_comparisons'])
  facts={r['path']:r['bytes']['sha256'] for r in generated['entries']}
  if phase=='import':import_facts=facts
  else:assert facts==import_facts
origin=read(p/'preparation-origin.json');assert origin['product']==product
assert origin['run_id']=='39776259056' and origin['source']=='b36f5b6773a754bc33a7e9b5c591316b622b426b' and origin['controller']=='2ea48725dce590adbd59b19b246fb1d59da88356'
assert sha(p/'prepare_caption.py')==origin['preparation_sha256'] and sha(p/'capture_import.py')==origin['capture_sha256']
assert (p/'prepare_caption.py').read_bytes()==(packet/'prepare_caption.py').read_bytes()
for row in read(p/'harness/manifest.json'):
 f=p/'harness'/Path(row['path']).name;assert sha(f)==row['sha256'] and blob(f)==row['blob'] and len(f.read_bytes())==row['bytes'];assert f.read_bytes()==(packet/f.name).read_bytes()
selection=read(ci/'ending-load/selection.json');assert selection['child_timeout_seconds']==240 and selection['source']==product and selection['expected_cases']==2
assert selection['runner_sha256']==sha(p/'harness/Invoke-EndingLoadBoundary-240.ps1') and selection['isolation_sha256']==sha(p/'harness/Invoke-IsolatedGodot.ps1')
result=read(ci/'ending-load/result.json');assert result['ok'] and result['child_exit']==0
assertions=[]
for plan in selection['tests']:
 suite=ET.parse(ci/'ending-load'/(plan['id']+'.xml')).getroot();cases=suite.findall('.//testcase');assert len(cases)==1
 case=cases[0];assert case.attrib['name']==plan['name'] and case.attrib['classname']==plan['path'] and case.attrib['status']=='pass';assert not suite.findall('.//failure') and not suite.findall('.//error') and not suite.findall('.//skipped');assertions.append(int(case.attrib['assertions']))
 log=(q/'phase2r_logs'/plan['log']).read_text();assert re.search(r'Godot Engine v4\.6\.3\.stable\.official\.',log);assert not re.search(r'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character',log);assert 'DWM_SCENE_VALIDATION_PROFILE ' not in log and 'DWM_CHECKPOINT_PROFILE ' not in log
isolation=[json.loads(x) for x in (ci/'ending-load/isolation.jsonl').read_text().splitlines()];assert len(isolation)==2 and all(x['exit_code']==0 for x in isolation);assert isolation[0]['user_dir']==isolation[1]['user_dir']
creator=read(ci/'scene-seven-day-create-proof.json');loader=read(ci/'scene-seven-day-load-proof.json');witness=read(ci/'scene-seven-day-witness-proof.json');auto=read(ci/'scene-seven-day-completed-autosave.json');profile=read(ci/'scene-seven-day-completed-profile.json')
assert creator['process_id']==loader['creator_process_id']!=loader['loader_process_id']==witness['process_id']
assert creator['slot_sha256']==loader['preserved_slot_sha256']==witness['source_slot_sha256']
assert witness['checkpoint']==creator['checkpoint'] and witness['profile']==creator['profile']
for key in ['narrative_checkpoint','gameplay','scene','command_receipts','applied_effect_transaction_ids','applied_variable_transaction_ids']:assert witness['snapshot'][key]==creator['snapshot'][key]
assert auto['current_snapshot']['snapshot']['lifecycle']==loader['completed_lifecycle'];life=loader['completed_lifecycle'];assert life['state']=='COMPLETED' and life['ending_plan']['next_step_index']==1 and life['ending_plan']['playback_stage']=='GALLERY_RECORDED'
assert profile==loader['completed_profile'];rid='ending:'+creator['source_run']+':gallery:ending.alone';assert profile['gallery_transaction_receipts'][rid]=={'ending_id':'ending.alone','unlocked':True};assert len(profile['gallery_transaction_receipts'])==len(creator['profile']['gallery_transaction_receipts'])+1
fresh=loader['fresh_lifecycle'];assert fresh['state']=='PLAYING' and 'ending_plan' not in fresh and fresh['run_id']!=creator['source_run'] and fresh['branch_id']!=life['branch_id'];assert loader['ready_count']==2
assert loader['creator_lines']==creator['observed_lines']==['line.Day%d.%s'%(day,half) for day in range(1,5) for half in ['one','two']]
assert loader['loader_lines']==['line.Day%d.%s'%(day,half) for day in range(5,8) for half in ['one','two']]+['line.ending.alone.normal.one','line.Day1.one']
for row in read(ci/'scene-seven-day-completed-files.json').values():assert sha(ci/row['file'].split('/')[-1])==row['sha256']
ending=read(ci/'scene-seven-day-witness-ending.json');assert ending['ending_ready'] and ending['ending_layout'] and not ending['clock_visible'] and not ending['prior_layout_in_tree'] and ending['layout_id']!=ending['prior_layout_id'];assert ending['capture']['source']=='Godot viewport, not desktop' and ending['capture']['sha256']==sha(ci/'computer-seven-day-witness-ending.png')
log=(q/'phase2r_logs/ending-load-load.log').read_text();marks=[(int(pid),int(t),label) for pid,t,label in re.findall(r'ENDING_LOAD_PHASE pid=(\d+) ticks_usec=(\d+) phase=(\S+)',log)];assert all(pid==loader['loader_process_id'] for pid,t,l in marks);assert all(marks[i][1]<=marks[i+1][1] for i in range(len(marks)-1));by={l:t for pid,t,l in marks}
pairs={'loader_to_witness':('loader.begin','witness_save.begin'),'witness_save_back':('witness_save.begin','witness_save.return'),'remaining_walk':('remaining_walk.begin','remaining_walk.return'),'ending_entry_readiness':('ending_entry.begin','ending_readiness.return'),'ending_evidence':('ending_evidence.begin','ending_evidence.return'),'ending_accept':('ending_completion.begin','ending_completion.accept_return'),'title_after_accept':('ending_completion.accept_return','title.ready'),'completion_checks':('title.ready','completion_checks.return'),'fresh_day1':('completion_checks.return','fresh_day1.ready')};times={name:(by[b]-by[a])/1e6 for name,(a,b) in pairs.items()}
for i in range(1,4):times['writer_'+str(i)]=(by[f'ending_writer.{i}.return']-by[f'ending_writer.{i}.begin'])/1e6
unit_totals=[]
for name in ['test_scene_event_contract','test_scene_receipt_validation']:
 folder=ci/'scene-contract-regression'/name
 tree=ET.parse(folder/'boundary.xml').getroot();cases=tree.findall('.//testcase')
 expected=re.findall(r'^func (test_\w+)\(', (root.parent/'ending-admission-tests/tests/unit'/(name+'.gd')).read_text(),re.M)
 assert [c.attrib['name'] for c in cases]==expected and len(set(expected))==len(expected)
 assert all(c.attrib['status']=='pass' for c in cases) and not tree.findall('.//failure') and not tree.findall('.//error') and not tree.findall('.//skipped')
 result=read(ci/'scene-contract-regression'/(name+'-result.json'));assert result['source']==product and result['ok'] and result['child_exit']==0
 iso=[json.loads(l) for l in (folder/'isolation.jsonl').read_text().splitlines()];assert len(iso)==1 and iso[0]['exit_code']==0
 log=(q/'phase2r_logs'/('contract-'+name+'.log')).read_text();assert not re.search(r'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character',log)
 unit_totals.append({'cases':len(cases),'assertions':sum(int(c.attrib['assertions']) for c in cases)})
assert unit_totals==[{'cases':28,'assertions':292},{'cases':10,'assertions':121}]
print('Unit checks:',unit_totals)
elapsed=[(datetime.datetime.fromisoformat(x['ended_at_utc'])-datetime.datetime.fromisoformat(x['started_at_utc'])).total_seconds() for x in isolation]
print(json.dumps({'unit_totals':unit_totals,'byte_hashes':count,'source_pins':len(sources),'assertions':assertions,'child_wall_seconds':elapsed,'timings':times,'phase_marks':len(marks),'creator_pid':creator['process_id'],'loader_pid':loader['loader_process_id']},indent=2))
(root/'independent-review-facts.json').write_text(json.dumps({'unit_totals':unit_totals,'byte_hashes':count,'source_pins':len(sources),'assertions':assertions,'child_wall_seconds':elapsed,'timings':times,'phase_marks':len(marks)},indent=2)+'\n')
