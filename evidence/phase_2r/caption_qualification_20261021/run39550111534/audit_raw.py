"""Independent read-only audit of retained raw preparation artifact."""
from pathlib import Path,PurePosixPath
import ast,hashlib,json,re,zipfile
ROOT=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
blob=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
raw=(ROOT/'original.zip').read_bytes()
assert len(raw)==3366537 and sha(raw)=='453acfe7a6a602d697b124f73d385021cd5ec3c4b315cca8d8985c3811830905'
with zipfile.ZipFile(ROOT/'original.zip') as z:
 names=z.namelist();assert len(names)==len(set(names))==86 and z.testzip() is None
 for name in names:
  p=PurePosixPath(name);assert not p.is_absolute() and '..' not in p.parts and '\\' not in name and ':' not in name
  assert (ROOT/'extracted'/name).read_bytes()==z.read(name)
 def read(name):return json.loads(z.read(name).decode('utf-8-sig'))
 origin=read('preparation-origin.json');before=read('import/before.json');changes=read('import/changes.json');generated=read('generated-import.json')
 assert sha(z.read('prepare_caption.py'))==origin['preparation_sha256']
 assert sha(z.read('capture_import.py'))==origin['capture_sha256']
 constants={n.targets[0].id:ast.literal_eval(n.value) for n in ast.parse(z.read('prepare_caption.py').decode()).body if isinstance(n,ast.Assign) and isinstance(n.targets[0],ast.Name) and isinstance(n.value,ast.Constant)}
 assert constants['PRODUCT']==origin['product']==changes['head']==changes['head_after']=='b2cb75a792790f7bf396073b1586026fa1e20482'
 assert changes['complete'] and changes['active_path'] is None
 assert len(before['head_entries'])==13422 and set(before['head_entries'])==set(before['index_entries'])
 for path,entry in before['head_entries'].items():
  assert entry['oid']==before['index_entries'][path]['oid'] and entry['mode']==before['index_entries'][path]['mode']
  if entry['mode']!='160000':assert before['worktree'][path]['git_blob']==entry['oid']
 byte_names=[n for n in names if n.startswith('import/bytes/')]
 for name in byte_names:assert sha(z.read(name))==PurePosixPath(name).name
 locators=[]
 def check_locations(obj):
  if isinstance(obj,dict):
   if 'file' in obj and str(obj['file']).startswith('bytes/'):
    data=z.read('import/'+obj['file']);assert sha(data)==obj['sha256'] and len(data)==obj['size'] and blob(data)==obj['git_blob'];locators.append(obj['file'])
   for value in obj.values():check_locations(value)
  elif isinstance(obj,list):
   for value in obj:check_locations(value)
 check_locations(changes);check_locations(generated)
 assert changes['worktree_changed_count']==1 and changes['index_changed_count']==2
 assert {c['path'] for c in changes['changes'] if c['worktree_changed']}=={'project.godot'}
 settings=next(c for c in changes['changes'] if c['path']=='project.godot')
 assert settings['before']['sha256']==constants['PROJECT'] and settings['after']['sha256']==constants['IMPORTED_PROJECT']
 assert {c['path'] for c in changes['changes'] if c['index_changed']}=={'.claude/skills/godot-prompter/1.10.0','.claude/skills/superpowers/6.1.1'}
 for c in changes['changes']:
  if c['index_changed']:assert c['index_before']['mode']=='160000' and c['index_after'] is None
 assert read('generated-before.json')['entries']==[]
 runtime=next(e for e in generated['entries'] if e['path']==constants['RUNTIME_UID'])
 assert runtime['source_blob']==constants['RUNTIME_SOURCE_BLOB']==before['head_entries'][runtime['source']]['oid']
 b=z.read('import/'+runtime['bytes']['file']);assert b.decode().strip()==runtime['uid_text']
 assert re.fullmatch(rb'uid://[a-y0-8]{1,13}\r?\n?',b)
 uid=0
 for c in runtime['uid_text'][6:]:uid=uid*34+'abcdefghijklmnopqrstuvwxy012345678'.index(c)
 assert str(uid)==runtime['uid'] and uid<=0x7fffffffffffffff
 assert runtime['failure']=='INVALID_GENERATED_UID' and 'uid_comparisons' not in runtime
 assert read('import-process.json')['exit_code']==0 and read('import-filter.json')['passed']
 audit={'run':39550111534,'attempt':1,'job':119057122431,'original_sha256':sha(raw),'original_bytes':len(raw),
  'safe_unique_zip_members_crc_and_extracted_bytes_verified':len(names),
  'original_file_manifest_present':False,'manifest_limitation':'No aggregate file-hash manifest is present in this raw artifact. Archive hash, ZIP CRC, extracted-byte equality, content-addressed bytes and embedded locators verified; do not claim a manifest census.',
  'content_addressed_byte_files_verified':len(byte_names),'byte_locator_occurrences_verified':len(locators),
  'origin':origin,'baseline_tracked_paths_verified':len(before['head_entries']),
  'raw_changed_paths':['project.godot'],'raw_change_is_exact_allowed_settings_pair':True,
  'allowed_gitlink_index_removals':2,'generated_entries':len(generated['entries']),
  'runtime_uid':runtime,'first_failure':read('after-failure.json'),
  'classification':'Import exit0 and error filter passed. New Continue UID decoded successfully and pinned owner passed; INVALID_GENERATED_UID occurred later during comparison of another sidecar. No uid_comparisons or offending peer path retained; this artifact alone does not identify the peer or establish collision.',
  'downstream':'No settings-restore, focused tests, rendering or native qualification evidence in this raw archive. No runtime result or acceptance.'}
 (ROOT/'audit.json').write_text(json.dumps(audit,indent=2)+'\n')
 print(json.dumps(audit,indent=2))
