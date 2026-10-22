from pathlib import Path
import hashlib,json,subprocess,zipfile,re
ROOT=Path('/workspace/scratch/e169b180163f'); REPO=ROOT/'dwm'; META=json.loads((ROOT/'settings-focus1-public-artifact.json').read_text()); FOLDER=ROOT/'settings-focus1-public'
SOURCE='e6d445343c292342310359faa898aabd2959f4db'; BASE='5a581fc89121864aead5202e01d6a82423b1b52d'
def git(commit,path): return subprocess.check_output(['git','-C',str(REPO),'show',commit+':'+path])
def identity(data): return {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
archive=Path(META['local_zip']);rawzip=archive.read_bytes();assert len(rawzip)==META['size_in_bytes'];assert 'sha256:'+hashlib.sha256(rawzip).hexdigest()==META['digest']
allowed={'tests/integration/verify_reading_rail_journey.gd','tests/unit/test_production_pause_controller.gd','scripts/ui/pause/PauseQuickCommands.gd','scripts/ui/pause/PauseSurface.gd','scripts/ui/SettingsContent.gd','scripts/ui/SettingsResetConfirmation.gd'}
report={'audit_pass':False,'scope':'Byte/declaration/reference review of generated focused inventories only; not completed whole-gate acceptance','run_id':36964699167,'source':SOURCE,'baseline':BASE,'archive':{'id':META['id'],**identity(rawzip)},'scanner_scope':'Lexical source references include comments; declarations and required contract maps are checked independently.','inventories':{},'adopted_paths':[]}
prepared=[]
for stem,count in [('game_state',236),('save_manager',74)]:
 path='evidence/phase_2r/runtime/'+stem+'_surface.json';oldraw=git(BASE,path);assert git(SOURCE,path)==oldraw;assert(REPO/path).read_bytes()==oldraw
 newraw=(FOLDER/'ci/public-surfaces'/Path(path).name).read_bytes()
 with zipfile.ZipFile(archive) as z: assert z.read('ci/public-surfaces/'+Path(path).name)==newraw
 old=json.loads(oldraw);new=json.loads(newraw);assert new['ok']is True and new['errors']==[]
 assert len(old['records'])==len(new['records'])==count
 assert [{k:v for k,v in r.items() if k!='call_sites'}for r in old['records']]==[{k:v for k,v in r.items() if k!='call_sites'}for r in new['records']]
 assert {k:v for k,v in old.items() if k not in ('records','dynamic_references')}=={k:v for k,v in new.items() if k not in ('records','dynamic_references')}
 diffs=[]
 for kind,a,b in [('call_sites',{r['symbol']:r['call_sites']for r in old['records']},{r['symbol']:r['call_sites']for r in new['records']}),('dynamic_references',old['dynamic_references'],new['dynamic_references'])]:
  for symbol in sorted(a.keys()|b.keys()):
   before=a.get(symbol,[]);after=b.get(symbol,[])
   if before==after:continue
   delta={'kind':kind,'symbol':symbol,'added':[],'removed':[]}
   for direction,sites,commit in [('added',[s for s in after if s not in before],SOURCE),('removed',[s for s in before if s not in after],BASE)]:
    for site in sites:
     file,line=site.rsplit(':',1);assert file in allowed,(stem,kind,symbol,site)
     source_line=git(commit,file).decode().splitlines()[int(line)-1]
     assert re.search(r'(?<![A-Za-z0-9_])'+re.escape(symbol)+r'(?![A-Za-z0-9_])',source_line),(symbol,site,source_line)
     delta[direction].append({'site':site,'source_line':source_line})
   diffs.append(delta)
 report['inventories'][stem]={'record_count':count,'declarations_unchanged':True,'required_maps_unchanged':True,'baseline':identity(oldraw),'generated':identity(newraw),'reference_deltas':diffs}
 prepared.append((path,newraw))
for p in ['autoload/GameState.gd','autoload/SaveManager.gd','tools/runtime/PublicSurfaceInventory.gd','evidence/phase_2r/runtime/game_state_required_surface.json','evidence/phase_2r/runtime/save_manager_required_surface.json']: assert git(BASE,p)==git(SOURCE,p),p
report['owner_scanner_required_maps_unchanged']=True
for path,data in prepared:
 (REPO/path).write_bytes(data);assert(REPO/path).read_bytes()==data
 report['adopted_paths'].append(path)
report['audit_pass']=True
(ROOT/'settings-focus1-public-inventory-review.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'audit_pass':True,'adopted':report['adopted_paths'],'deltas':{k:len(v['reference_deltas'])for k,v in report['inventories'].items()}},indent=2))
