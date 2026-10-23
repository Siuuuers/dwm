import collections,hashlib,json,pathlib,re,struct,subprocess,xml.etree.ElementTree as ET,zipfile,zlib
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--evidence-root',type=pathlib.Path,required=True)
parser.add_argument('--repository',type=pathlib.Path,required=True)
parser.add_argument('--artifact',type=pathlib.Path,required=True)
args=parser.parse_args()
root=args.evidence_root; out=root/'ci'; repo=args.repository
sha='a8d9838207db24a7837417eb895a5b1ed656262b'; tree='0b50482e5881c92511354dead9f1db629a8b7e28'
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def git(*args): return subprocess.check_output(['git','-C',str(repo),*args])
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
outer=args.artifact; inner=root/'original-evidence.zip'
assert digest(outer)=='25d61f68dbef89675fd40a5e81f3c15dd5edff14f8ec7b5731fffa451996683b'
for p in [outer,inner]:
 with zipfile.ZipFile(p) as z: assert z.testzip() is None
origin=read(out/'audit-origin.json'); assert origin['candidate']==sha and origin['tree']==tree and origin['run_id']=='39888007872'
assert git('rev-parse',sha+'^{tree}').decode().strip()==tree
manifest=read(out/'retained-hashes.json')
for name, record in manifest.items():
 p=root/name;assert p.stat().st_size==record['bytes'] and digest(p)==record['sha256'],name
with zipfile.ZipFile(inner) as z: assert set(z.namelist())==set(manifest)|{'ci/retained-hashes.json'}
source_matches=[]; generated=[]
for p in (out/'source').rglob('*'):
 if not p.is_file():continue
 rel=p.relative_to(out/'source').as_posix()
 exists=subprocess.run(['git','-C',str(repo),'cat-file','-e',sha+':'+rel],capture_output=True).returncode==0
 if exists:
  assert p.read_bytes()==git('show',sha+':'+rel),rel;source_matches.append(rel)
 else:
  assert p.suffix=='.uid',rel;generated.append(rel)
suites={'geometry':['tests/unit/test_witnessed_transport_rail.gd','tests/unit/test_minesweeper_view_controls.gd','tests/unit/test_gallery_typography.gd','tests/unit/test_font_styles.gd'],'fixture-scope':['tests/integration/test_application_bootstrap.gd','tests/integration/test_cold_run_rollback.gd','tests/integration/test_scene_controls_localization.gd'],'display':['tests/unit/test_witnessed_reading_rail.gd','tests/integration/test_witnessed_caption_runtime.gd'],'negative':['tests/integration/test_hospital_dating_adapter_negative_contract.gd'],'pause-load':['tests/integration/test_scene_pause_load.gd'],'pause-quick-load':['tests/integration/test_scene_pause_quick_load.gd'],'pause-write-refusal':['tests/integration/test_scene_pause_write_refusal.gd'],'story-localization':['tests/integration/test_story_localization.gd'],'current-title-create':['tests/integration/test_current_title_scene_create.gd'],'current-title-load':['tests/integration/test_current_title_scene_load.gd']}
def effective_tests(script):
 text=git('show',sha+':'+script).decode(); own=re.findall(r'^func (test_\w+)\(',text,re.M)
 inherited=re.search(r'^extends "res://(tests/[^"\n]+)"',text,re.M)
 if inherited: own.extend(n for n in effective_tests(inherited[1]) if n not in own)
 return own
reports=[]
for suite,scripts in suites.items():
 xml=ET.parse(out/(suite+'.xml')).getroot();rows=list(xml.iter('testcase'));wanted=[]
 for script in scripts:wanted.extend((script,n) for n in effective_tests(script))
 assert collections.Counter((r.attrib['classname'],r.attrib['name']) for r in rows)==collections.Counter(wanted),suite
 assert not any(list(xml.iter(t)) for t in ['failure','error','skipped']),suite
 assert all(r.attrib.get('status')=='pass' and int(r.attrib.get('assertions','0'))>0 for r in rows),suite
 reports.append({'suite':suite,'tests':len(rows),'assertions':sum(int(r.attrib['assertions']) for r in rows)})
assert sum(r['tests'] for r in reports)==135
processes={}
for suite,count in {'geometry':1,'fixture-scope':1,'display':1,'negative':1,'pause-load':1,'pause-quick-load':1,'pause-write-refusal':1,'story-localization':1,'current-title':2,'gallery-render':1}.items():
 events=[json.loads(x) for x in (out/(suite+'.jsonl')).read_text(encoding='utf-8-sig').splitlines() if x.strip()]
 assert len(events)==count and all(e['exit_code']==0 for e in events),(suite,events)
 processes[suite]=events
pair=processes['current-title'];assert pair[0]['test_root']==pair[1]['test_root'] and pair[0]['user_dir']==pair[1]['user_dir']
assert len({events[0]['test_root'] for events in processes.values()})==len(processes)
created=read(out/'current-title-scene-create-proof.json');loaded=read(out/'current-title-scene-load-proof.json')
for proof in [created,loaded]:
 assert proof['scope']=='current_shipped_title_authored_day1' and proof['entry_id']=='Day1' and proof['line_id']=='line.Day1.one'
 assert proof['ready_count']==1 and proof['visible_text'].strip()
 assert proof['reading']['reading_session']['entry_id']=='Day1' and proof['reading']['reading_session']['frontier']['line_id']=='line.Day1.one'
 assert re.fullmatch(r'[0-9a-f]{64}',proof['slot_sha256']) and re.fullmatch(r'[0-9a-f]{64}',proof['registration_sha256'])
for key in ['registration_sha256','visible_text','reading','gameplay','scene','command_receipts','profile','slot_sha256','source_run','user_dir']:assert loaded[key]==created[key],key
assert loaded['creator_process_id']==created['process_id'] and loaded['process_id']!=created['process_id']
assert loaded['source_branch']==created['source_branch'] and loaded['destination_branch']!=created['source_branch']
assert created['visible_text']==json.loads(git('show',sha+':localization/story/en.json'))['line.Day1.one']
pngs=[]
for path in root.rglob('*.png'):
 data=path.read_bytes(); assert len(data)>1000 and data[:8]==b'\x89PNG\r\n\x1a\n';cursor=8;chunks=[];compressed=b'';dimensions=None
 while cursor<len(data):
  length=struct.unpack('>I',data[cursor:cursor+4])[0];kind=data[cursor+4:cursor+8];payload=data[cursor+8:cursor+8+length];crc=struct.unpack('>I',data[cursor+8+length:cursor+12+length])[0]
  assert zlib.crc32(kind+payload)&0xffffffff==crc,str(path);chunks.append(kind)
  if kind==b'IHDR':dimensions=struct.unpack('>II',payload[:8]); assert dimensions[0]>0 and dimensions[1]>0
  if kind==b'IDAT':compressed+=payload
  cursor+=12+length
 assert chunks[0]==b'IHDR' and chunks[-1]==b'IEND' and cursor==len(data) and zlib.decompress(compressed)
 pngs.append({'path':path.relative_to(root).as_posix(),'dimensions':dimensions,'bytes':len(data)})
for label in ['menu','day1','computer','save','loaded-day1','loaded-computer']:
 proof=loaded if label.startswith('loaded-') else created
 assert len(proof['window_size'])==2 and all(0<n<=limit for n,limit in zip(proof['window_size'],[1280,720]))
 assert struct.unpack('>II',(out/('computer-current-title-'+label+'.png')).read_bytes()[16:24])==tuple(proof['window_size'])
gallery=out/'gallery-caption-collection'; m=read(gallery/'measurements.json')
assert m['ok'] is True and not m['failures'] and m['checks']==726
expected={'status-%s-%s-%d-%s.png'%(style,locale,percent,status) for style in ['pixel','readable'] for locale in ['en','zh_CN','zh_HK','ja','ko'] for percent in [100,125,150] for status in ['added','failed','uncertain']}
expected.update(['first-visible.png','second-visible-not-collectable.png','restarted-visible.png','failed-real.png','uncertain-real.png'])
assert len(m['samples'])==95 and collections.Counter(s['file'] for s in m['samples'])==collections.Counter(expected)
assert {p.name for p in gallery.glob('*.png')}==expected
assert 'GALLERY_CAPTION_COLLECTION_RENDER_VERIFIED captures=95' in (root/'phase2r_logs/gallery-render.log').read_text(encoding='utf-8-sig')
assert read(out/'import-process.json')['exit_code']==0
for p in (root/'phase2r_logs').glob('*.log'):assert not re.search(r'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character',p.read_text(encoding='utf-8-sig')),str(p)
assert set((out/'final-status.txt').read_text().splitlines())=={'D  .claude/skills/godot-prompter/1.10.0','D  .claude/skills/superpowers/6.1.1'}
report={'run_id':39888007872,'original_workflow_conclusion':'failure','offline_validation':'pass for retained bounded evidence with corrected framebuffer assumption; does not rewrite cloud conclusion','source':sha,'tree':tree,'origin':origin,'outer_sha256':digest(outer),'inner_sha256':digest(inner),'zip_crc':'pass outer and inner','retained_members_verified':len(manifest),'source_files_matched_to_pinned_git':len(source_matches),'generated_uid_files':generated,'reports':reports,'test_count':sum(r['tests'] for r in reports),'assertion_count':sum(r['assertions'] for r in reports),'test_and_render_process_count':sum(map(len,processes.values())),'processes':processes,'import_exit_code':0,'gallery_captures':95,'gallery_checks':726,'png_count':len(pngs),'png_dimensions_census':dict(collections.Counter('%dx%d'%tuple(p['dimensions']) for p in pngs)),'pngs':pngs,'title_create_process':created['process_id'],'title_load_process':loaded['process_id'],'title_native_window':created['window_size'],'title_logical_viewport':created['viewport_size'],'known_gate_defect':'Gallery check_png default assumed 1280x720. All 95 original Gallery PNGs are 992x558, as are 6 title and8 story/glyph captures. Gallery script saves root.get_texture().get_image() directly, with no resize; it records logical control geometry but not native window dimensions.','limitations':['Original cloud run remains failed; offline corrected evidence validation is distinct.','Gallery native framebuffer size comes from original PNG IHDR, not an explicit Gallery window-size measurement.','Title proofs independently record native992x558/logical1280x720, but belong to different processes.','No screenshots altered; visual review is separate and pending parent.','Only135 current bounded cases; not full canonical integration or all routes.','Gallery replay is explicitly fixture-only, not authored-production content admission.']}
assets=read(out/'omitted-assets.json')
for record in assets:
 b=git('show',sha+':'+record['path']); assert len(b)==record['bytes'] and hashlib.sha256(b).hexdigest()==record['sha256'],record['path']
report['omitted_asset_hashes_verified_to_pinned_git']=len(assets)
report['missing_retained_sources']=read(out/'missing-retained-sources.json')
assert report['missing_retained_sources']==[]
(root/'inspection.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['test_count','assertion_count','retained_members_verified','source_files_matched_to_pinned_git','test_and_render_process_count','gallery_captures','gallery_checks','png_dimensions_census','generated_uid_files']},indent=2))
