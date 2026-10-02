from pathlib import Path
import hashlib,json,re,subprocess,xml.etree.ElementTree as ET,zipfile
ROOT=Path('/workspace/scratch/e169b180163f');REPO=ROOT/'dwm';FOLDER=ROOT/'settings-focus2-public';META=json.loads((ROOT/'settings-focus2-public-artifact.json').read_text())
BASE='5a581fc89121864aead5202e01d6a82423b1b52d';SOURCE='63b59b67a169a34a17f0f5ec4c15b98a55c6ff2b';PRIOR_GENERATOR='e6d445343c292342310359faa898aabd2959f4db'
def git(commit,path):return subprocess.check_output(['git','-C',str(REPO),'show',commit+':'+path])
def ident(raw):return {'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
def contract(document):return [{k:v for k,v in row.items() if k!='call_sites'} for row in document['records']]
allowed={'tests/integration/verify_reading_rail_journey.gd','tests/unit/test_production_pause_controller.gd','scripts/ui/pause/PauseQuickCommands.gd','scripts/ui/pause/PauseSurface.gd','scripts/ui/SettingsContent.gd','scripts/ui/SettingsResetConfirmation.gd'}
def deltas(before,after,before_source):
 results=[]
 for kind,a,b in [('call_sites',{r['symbol']:r['call_sites']for r in before['records']},{r['symbol']:r['call_sites']for r in after['records']}),('dynamic_references',before['dynamic_references'],after['dynamic_references'])]:
  for symbol in sorted(a.keys()|b.keys()):
   old=a.get(symbol,[]);new=b.get(symbol,[])
   if old==new:continue
   row={'kind':kind,'symbol':symbol,'added':[],'removed':[]}
   for direction,sites,revision in [('added',[s for s in new if s not in old],SOURCE),('removed',[s for s in old if s not in new],before_source)]:
    for site in sites:
     file,line=site.rsplit(':',1);assert file in allowed,(kind,symbol,site)
     text=git(revision,file).decode().splitlines()[int(line)-1]
     assert re.search(r'(?<![A-Za-z0-9_])'+re.escape(symbol)+r'(?![A-Za-z0-9_])',text),(kind,symbol,site,text)
     row[direction].append({'site':site,'source_line':text,'source_commit':revision})
   results.append(row)
 return results
archive=Path(META['local_zip']);rawzip=archive.read_bytes();assert len(rawzip)==META['size_in_bytes'];assert 'sha256:'+hashlib.sha256(rawzip).hexdigest()==META['digest'];assert META['workflow_run']['id']==36965784091
with zipfile.ZipFile(archive) as zipped:
 xmlraw=(FOLDER/'ci/public_surfaces.xml').read_bytes();assert zipped.read('ci/public_surfaces.xml')==xmlraw
 xt=ET.fromstring(xmlraw);cases=[c for s in xt.findall('testsuite')for c in s.findall('testcase')];assert len(cases)==11 and all(c.get('status')=='pass'for c in cases)
 report={'schema_version':1,'audit_pass':False,'scope':'Focused generated-inventory byte, declaration and reference review/adoption; not whole-gate or broad acceptance.','run_id':36965784091,'workflow_head':META['workflow_run']['head_sha'],'generator_source':SOURCE,'accepted_baseline':BASE,'candidate_inventory_generator_source':PRIOR_GENERATOR,'artifact':{'id':META['id'],'name':META['name'],**ident(rawzip)},'public_gut':{'cases':11,'all_passed':True,'xml':ident(xmlraw)},'inventories':{},'adopted_paths':[],'reference_semantics':'Scanner is lexical and includes comments. Before baseline means accepted5a inventories; current candidate carries exact Focus1/e6 generated inventories; after means raw Focus2/63 generated inventories.'}
 prepared=[]
 for stem,count in [('game_state',236),('save_manager',74)]:
  file=stem+'_surface.json';path='evidence/phase_2r/runtime/'+file
  base_raw=git(BASE,path);candidate_raw=git(SOURCE,path);new_raw=(FOLDER/'ci/public-surfaces'/file).read_bytes()
  assert (REPO/path).read_bytes()==candidate_raw
  assert candidate_raw==(ROOT/'settings-focus1-public/ci/public-surfaces'/file).read_bytes()
  assert zipped.read('ci/public-surfaces/'+file)==new_raw
  before=json.loads(base_raw);candidate=json.loads(candidate_raw);after=json.loads(new_raw)
  assert all(d['ok'] is True and d['errors']==[] and len(d['records'])==count for d in [before,candidate,after])
  assert contract(before)==contract(candidate)==contract(after)
  top=lambda d:{k:v for k,v in d.items()if k not in ['records','dynamic_references']}
  assert top(before)==top(candidate)==top(after)
  report['inventories'][stem]={'record_count':count,'declarations_required_and_top_level_maps_unchanged':True,'accepted_baseline':ident(base_raw),'current_candidate':ident(candidate_raw),'focus2_generated':ident(new_raw),'current_candidate_equals_focus1_generated':True,'baseline_to_generated_deltas':deltas(before,after,BASE),'candidate_to_generated_deltas':deltas(candidate,after,PRIOR_GENERATOR)}
  prepared.append((path,new_raw))
unchanged={}
for path in ['autoload/GameState.gd','autoload/SaveManager.gd','tools/runtime/PublicSurfaceInventory.gd','evidence/phase_2r/runtime/game_state_required_surface.json','evidence/phase_2r/runtime/save_manager_required_surface.json']:
 raw=git(BASE,path);assert raw==git(SOURCE,path);unchanged[path]=ident(raw)
report['unchanged_owner_scanner_required_maps']=unchanged
for path,raw in prepared:
 (REPO/path).write_bytes(raw);assert (REPO/path).read_bytes()==raw;report['adopted_paths'].append(path)
report['audit_pass']=True
(ROOT/'settings-focus2-public-inventory-review.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'audit_pass':True,'source':SOURCE,'adopted_paths':report['adopted_paths'],'contracts':[236,74],'public_gut_cases':len(cases),'baseline_deltas':{k:len(v['baseline_to_generated_deltas'])for k,v in report['inventories'].items()},'candidate_deltas':{k:len(v['candidate_to_generated_deltas'])for k,v in report['inventories'].items()}},indent=2))
