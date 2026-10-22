from pathlib import Path
import argparse, importlib.util
import json,hashlib,re,xml.etree.ElementTree as ET,datetime
if not __debug__:
 raise RuntimeError('Run without Python -O: assertion gates are required')
parser=argparse.ArgumentParser(description='Offline custody, durable-state and restored-profile review; no engine execution.')
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--run-id', required=True)
parser.add_argument('--controller', required=True)
parser.add_argument('--packet', type=Path, required=True, help='Reviewed terminal packet with packet-summary, source-manifest and harness files')
parser.add_argument('--unit-sources', type=Path, action='append', required=True, help='Root containing exact source test paths; repeat for disjoint roots')
parser.add_argument('--checker', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args=parser.parse_args()
assert re.fullmatch(r'[0-9]+',args.run_id) and re.fullmatch(r'[0-9a-f]{40}',args.controller)
root=args.root
args.output.mkdir(parents=True, exist_ok=True)
assert not (args.output/'independent-review-facts.json').exists(), 'Use a fresh review output directory; do not retain stale acceptance'
spec=importlib.util.spec_from_file_location('restored_profiles',args.checker)
checker=importlib.util.module_from_spec(spec);spec.loader.exec_module(checker)
prep_dirs=[d for d in root.iterdir() if d.is_dir() and (d/'preparation-origin.json').is_file()]
qualification_dirs=[d for d in root.iterdir() if d.is_dir() and (d/'ci/ending-load/selection.json').is_file()]
assert len(prep_dirs)==1 and len(qualification_dirs)==1, 'Exactly one extracted preparation and qualification artifact required'
p=prep_dirs[0];q=qualification_dirs[0];ci=q/'ci';packet=args.packet
loader_log=(q/'phase2r_logs/ending-load-load.log').read_text(encoding='utf-8-sig')
# Keep raw payload strings even when later custody or metric gates reject the run.
(args.output/'raw-profile-payloads.json').write_text(json.dumps(checker.extract_raw(loader_log),indent=2)+'\n')
def read(f): return json.loads(f.read_text(encoding='utf-8-sig'))
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
def blob(f):
 b=f.read_bytes();return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
summary=read(packet/'packet-summary.json')
product=summary['product'];assets=summary['assets']
assert re.fullmatch(r'[0-9a-f]{40}',product) and re.fullmatch(r'[0-9a-f]{40}',assets), 'Publish reviewed source/assets pins before acceptance'
sources=read(packet/'source-manifest.json');assert len(sources)==summary['source_pins']==15
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
assert origin['run_id']==args.run_id and origin['source']==assets and origin['controller']==args.controller
assert sha(p/'prepare_caption.py')==origin['preparation_sha256']==summary['preparation']['sha256'] and sha(p/'capture_import.py')==origin['capture_sha256']=='a04a8560ea2ac7e8ff77d6bb3e3ffe8d1404193f5e1de2a71676332403fe7379'
assert sha(p/'harness/manifest.json')==sha(packet/'manifest.json')
assert (p/'prepare_caption.py').read_bytes()==(packet/'prepare_caption.py').read_bytes()
for row in read(p/'harness/manifest.json'):
 f=p/'harness'/Path(row['path']).name;assert sha(f)==row['sha256'] and blob(f)==row['blob'] and len(f.read_bytes())==row['bytes'];assert f.read_bytes()==(packet/f.name).read_bytes()
selection=read(ci/'ending-load/selection.json');assert selection['child_timeout_seconds']==240 and selection['source']==product and selection['expected_cases']==2
assert selection['runner_sha256']==sha(p/'harness/Invoke-EndingLoadBoundary-240.ps1') and selection['isolation_sha256']==sha(p/'harness/Invoke-IsolatedGodot.ps1')
result=read(ci/'ending-load/result.json');assert result['ok'] and result['child_exit']==0
assert selection['rendered'] is True and selection['accessibility']=='always' and selection['external_uia_consumer'] is False
expected=[('create','tests/integration/test_scene_seven_day_connected_create.gd','test_normal_title_new_game_reaches_day4_and_saves_exact_caption'),('load','tests/integration/test_scene_seven_day_witness_load.gd','test_fresh_load_witness_save_back_reaches_ending_and_preserves_completion')]
assert [(t['id'],t['path'],t['name']) for t in selection['tests']]==expected
pins={r['path']:r for r in sources}
for plan in selection['tests']:
 assert plan['test_blob']==pins[plan['path']]['blob'] and plan['test_sha256']==pins[plan['path']]['sha256']
 assert plan['log']=='ending-load-'+plan['id']+'.log'
assert result['source']==product and result['error'] is None
assert [(x['id'],x['assertions']) for x in result['completed']]==[('create',102),('load',234)]
assertions=[]
for plan in selection['tests']:
 suite=ET.parse(ci/'ending-load'/(plan['id']+'.xml')).getroot();cases=suite.findall('.//testcase');assert len(cases)==1
 case=cases[0];assert case.attrib['name']==plan['name'] and case.attrib['classname']==plan['path'] and case.attrib['status']=='pass';assert not suite.findall('.//failure') and not suite.findall('.//error') and not suite.findall('.//skipped');assertions.append(int(case.attrib['assertions']))
 log=(q/'phase2r_logs'/plan['log']).read_text();assert re.search(r'Godot Engine v4\.6\.3\.stable\.official\.',log);assert not re.search(r'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character',log);assert 'DWM_CHECKPOINT_PROFILE ' not in log
 if plan['id']=='create':assert 'DWM_SCENE_VALIDATION_PROFILE' not in log
assert assertions==[102,234], assertions
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
elapsed=[(datetime.datetime.fromisoformat(x['ended_at_utc'])-datetime.datetime.fromisoformat(x['started_at_utc'])).total_seconds() for x in isolation]
assert all(0 <= seconds < 240 for seconds in elapsed), elapsed
unit_folder=ci/'scene-contract-regression'
unit_selection=read(unit_folder/'selection.json')
unit_paths=['tests/unit/test_scene_event_contract.gd','tests/unit/test_scene_receipt_validation.gd','tests/unit/test_scene_terminal_lifecycle.gd']
assert unit_selection['source']==product and unit_selection['scripts']==summary['unit_scripts']==unit_paths
assert unit_selection['rendered'] is False and unit_selection['child_timeout_seconds']==120 and unit_selection['distinct_isolated_children'] is True
assert unit_selection['runner_sha256']==sha(p/'harness/Invoke-SceneContractRegression.ps1') and unit_selection['isolation_sha256']==sha(p/'harness/Invoke-IsolatedGodot.ps1')
assert unit_selection['console_sha256']==selection['console_sha256']
unit_source_paths=unit_paths+['scripts/domain/narrative/SceneEventContract.gd','scripts/narrative/SceneValidationTiming.gd']
assert unit_selection['sources']==[{'path':name,'blob':pins[name]['blob'],'sha256':pins[name]['sha256']} for name in unit_source_paths]
unit_totals=[];unit_results=[];unit_roots=[]
for name,case_count in zip(unit_paths,[28,10,7]):
 source_files=[directory/name for directory in args.unit_sources if (directory/name).is_file()]
 assert len(source_files)==1, ('Exactly one source copy required',name)
 source_file=source_files[0]
 assert sha(source_file)==pins[name]['sha256'] and blob(source_file)==pins[name]['blob']
 expected_names=re.findall(r'^func (test_\w+)\(',source_file.read_text(encoding='utf-8'),re.M)
 assert len(expected_names)==len(set(expected_names))==case_count
 suite_id=Path(name).stem;folder=unit_folder/suite_id
 tree=ET.parse(folder/'boundary.xml').getroot();suites=tree.findall('.//testsuite');cases=tree.findall('.//testcase')
 assert len(suites)==1 and suites[0].attrib['name']==name and len(cases)==case_count
 assert sorted(c.attrib['name'] for c in cases)==sorted(expected_names)
 assert not tree.findall('.//failure') and not tree.findall('.//error') and not tree.findall('.//skipped')
 assert all(c.attrib['status']=='pass' and c.attrib['classname']==name and re.fullmatch(r'[0-9]+',c.attrib['assertions']) and int(c.attrib['assertions'])>0 for c in cases)
 total=sum(int(c.attrib['assertions']) for c in cases)
 result=read(unit_folder/(suite_id+'-result.json'));unit_results.append(result)
 assert result['source']==product and result['script']==name and result['ok'] is True and result['child_exit']==0 and result['error'] is None
 assert result['cases']==case_count and result['assertions']==total
 assert sorted(result['expected_names'])==sorted(result['actual_names'])==sorted(expected_names)
 assert read(folder/'expected-names.json')==expected_names
 iso=[json.loads(line) for line in (folder/'isolation.jsonl').read_text().splitlines()]
 assert len(iso)==1 and iso[0]['exit_code']==0 and iso[0]['suite_id']=='contract-'+suite_id
 assert '-gtest=res://'+name in iso[0]['argv']
 seconds=(datetime.datetime.fromisoformat(iso[0]['ended_at_utc'])-datetime.datetime.fromisoformat(iso[0]['started_at_utc'])).total_seconds()
 assert 0 <= seconds < 120
 unit_roots.append(iso[0]['user_dir'])
 unit_log=(q/'phase2r_logs'/('contract-'+suite_id+'.log')).read_text(encoding='utf-8-sig')
 assert re.search(r'Godot Engine v4\.6\.3\.stable\.official\.',unit_log)
 assert not re.search(r'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character|DWM_SCENE_VALIDATION_PROFILE|DWM_CHECKPOINT_PROFILE',unit_log)
 unit_totals.append({'script':name,'cases':case_count,'assertions':total,'child_wall_seconds':seconds})
assert len(set(unit_roots))==3 and isolation[0]['user_dir'] not in unit_roots
assert read(unit_folder/'results.json')==unit_results
facts={'unit_totals':unit_totals,'byte_hashes':count,'source_pins':len(sources),'assertions':assertions,'child_wall_seconds':elapsed,'timings':times,'phase_marks':len(marks),'creator_pid':creator['process_id'],'loader_pid':loader['loader_process_id']}
# This file records only these gates; aggregate acceptance is still pending here.
(args.output/'custody-durable-facts.json').write_text(json.dumps(facts,indent=2)+'\n')
metrics=checker.validate_log(loader_log,loader['loader_process_id'])
facts['aggregate_metrics']=metrics
facts['status']='passed'
facts['run_id']=args.run_id
facts['controller']=args.controller
facts['product']=product
facts['assets']=assets
facts['total_cases']=sum(row['cases'] for row in unit_totals)+2
facts['total_assertions']=sum(row['assertions'] for row in unit_totals)+sum(assertions)
(args.output/'independent-review-facts.json').write_text(json.dumps(facts,indent=2)+'\n')
print(json.dumps(facts,indent=2))
