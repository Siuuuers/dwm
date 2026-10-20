"""Read-only verification of original run39476916285 ZIPs; writes derived JSON only."""
from pathlib import Path, PurePosixPath
import hashlib, io, json, struct, zipfile
ROOT=Path(__file__).resolve().parent
sha=lambda b: hashlib.sha256(b).hexdigest()
def read(z,n): return json.loads(z.read(n).decode('utf-8-sig'))
def safe(z):
    names=z.namelist()
    assert len(names)==len(set(names))
    for n in names:
        p=PurePosixPath(n)
        assert not p.is_absolute() and '..' not in p.parts and '\\' not in n and ':' not in n
        assert not z.getinfo(n).is_dir()
    assert z.testzip() is None
    return names
archives={}
for name,digest,size,manifest in [
 ('preparation-original.zip','a8ebef5ad64a4871e7e157825fb48fe9574d0695c6434f8dd52f043f2f74b863',8706715,'evidence-file-hashes.json'),
 ('delivery-original.zip','6215edef73970eb26429bd07d1394bded900a0ebe77462f2d565050fe8585327',101071775,'delivery/evidence-manifest.json')]:
    data=(ROOT/name).read_bytes(); assert len(data)==size and sha(data)==digest
    z=zipfile.ZipFile(io.BytesIO(data)); names=safe(z); files=read(z,manifest)['files']
    assert len(files)==len({f['path'].replace('\\','/') for f in files})
    assert set(names)=={f['path'].replace('\\','/') for f in files}|{manifest}
    for f in files:
        b=z.read(f['path'].replace('\\','/')); assert len(b)==f['bytes'] and sha(b)==f['sha256']
    archives[name]={'sha256':digest,'bytes':size,'members':len(names),'manifest_payloads_verified':len(files)}
p=zipfile.ZipFile(ROOT/'preparation-original.zip'); d=zipfile.ZipFile(ROOT/'delivery-original.zip')
validation=read(d,'windows-export/validation.json'); package_raw=d.read('windows-export/DWM-windows-x86_64-validation.zip')
assert sha(package_raw)==validation['archive']['sha256'] and len(package_raw)==validation['archive']['bytes']
package=zipfile.ZipFile(io.BytesIO(package_raw)); names=safe(package)
assert set(names)=={f['path'] for f in validation['files']}|{'validation.json'}
assert read(package,'validation.json')['files']==validation['files']
for f in validation['files']:
    b=package.read(f['path']); assert len(b)==f['bytes'] and sha(b)==f['sha256']
pck=package.read('DWM.pck'); magic,version,major,minor,patch,flags,base,directory=struct.unpack_from('<6I2Q',pck)
assert (magic,version,major,minor,patch,flags)==(0x43504447,3,4,6,3,2)
assert 112<=base<=directory<=len(pck)-4
count=struct.unpack_from('<I',pck,directory)[0]; off=directory+4; paths=set(); cache=None
for _ in range(count):
    size=struct.unpack_from('<I',pck,off)[0];off+=4
    assert 0<size and off+size+36<=len(pck)
    path=pck[off:off+size].rstrip(b'\0').decode();off+=size
    assert path not in paths;paths.add(path)
    start,length,md5,eflags=struct.unpack_from('<QQ16sI',pck,off);off+=36;start+=base
    assert eflags==0 and base<=start<=directory and start+length<=directory
    b=pck[start:start+length];assert hashlib.md5(b).digest()==md5
    if path=='.godot/uid_cache.bin':cache=b
assert cache is not None
cache_count=struct.unpack_from('<I',cache)[0];off=4;records=[]
for _ in range(cache_count):
    uid,size=struct.unpack_from('<QI',cache,off);off+=12
    records.append({'uid':str(uid),'path':cache[off:off+size].decode()});off+=size
assert off==len(cache)
allowance=read(p,'final-generated-allowance.json');assert allowance['passed'] and not allowance['errors']
assert allowance['archive_sha256']==sha(package_raw) and allowance['pck_sha256']==sha(pck)
assert allowance['cache_bytes']['sha256']==sha(cache) and p.read('final/'+allowance['cache_bytes']['file'])==cache
before={x['path']:x for x in read(p,'generated-import.json')['entries']};after={x['path']:x for x in read(p,'generated-final.json')['entries']}
assert all(k in after and after[k]['bytes']['sha256']==v['bytes']['sha256'] for k,v in before.items())
assert set(after)-set(before)=={a['path'] for a in allowance['additions']}
for a in allowance['additions']:
    b=p.read('final/'+a['bytes']['file']);assert sha(b)==a['bytes']['sha256'] and len(b)==a['bytes']['size']
    assert a['path'] not in paths and a['source'] not in paths
    matches=[r for r in records if r['uid']==a['uid'] or r['path']=='res://'+a['source']]
    assert matches==a['packaged_cache_records']
    assert all(r['uid']==a['uid'] and r['path']=='res://'+a['source'] for r in matches)
receipts={phase:read(d,'exported-'+phase+'/result.json') for phase in ('capability','create','load')}
for phase,r in receipts.items():
    assert r['archive_sha256']==sha(package_raw) and r['pck_sha256']==sha(pck)
    assert r['executable_sha256']==sha(package.read('DWM.exe'))
assert receipts['capability']['ok'] and receipts['create']['ok'] and not receipts['load']['ok']
for phase in ('capability','create'):
    r=receipts[phase];assert r['clean_player_exit'] and not r['forced_cleanup'] and r['exit_code']==0
assert receipts['load']['failure']=='UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending.'
assert receipts['load']['forced_cleanup'] and not receipts['load']['clean_player_exit']
source=d.read('exported-create/source-slot-1.json');restored=d.read('exported-load/restored-slot-2.json')
assert source==d.read('exported-load/failure-saves-slot_1.json')
assert restored==d.read('exported-load/failure-saves-slot_2.json')
for row in read(d,'exported-load/failure-save-observations.json'):
    assert row['status']=='copied'; b=d.read('exported-load/'+row['file']);assert len(b)==row['bytes'] and sha(b)==row['sha256']
auto=read(d,'exported-load/failure-saves-autosave.json')['current_snapshot']['snapshot'];profile=read(d,'exported-load/failure-profile.json')
for phase in ('capability','create','load'):
    for e in read(d,'exported-'+phase+'/events.json'):
        if e['kind']=='capture': assert sha(d.read('exported-'+phase+'/'+e['data']['file']))==e['data']['sha256']
report={'run':39476916285,'job':118815142853,'archives':archives,'package_archive':validation['archive'],
 'package_manifest_payloads_verified':len(validation['files']),'package_members':len(names),'pck_payloads_verified':len(paths),'uid_cache_records':len(records),
 'pack_audit':validation['pack_audit'],'headless_smoke':validation['smoke'],
 'preparation_phases':read(p,'phase-summary.json'),'generated_before_count':len(before),'generated_final_count':len(after),
 'prior_generated_bytes_unchanged':True,'allowance':allowance,
 'final_tracked_change_count':read(p,'final/changes.json')['worktree_changed_count'],
 'final_index_change_count':read(p,'final/changes.json')['index_changed_count'],
 'native_outcomes':read(d,'delivery/phase-summary.json')['outcomes'],
 'native_receipts':{k:{x:r.get(x) for x in ('ok','failure','clean_player_exit','forced_cleanup','exit_code','elapsed_seconds','step_timeout_seconds')} for k,r in receipts.items()},
 'saved_state':{'source_slot1_unchanged_at_failure':True,'restored_slot2_unchanged_at_failure':True,
  'autosave_checkpoint_sequence':auto['checkpoint_sequence'],'autosave_lifecycle_state':auto['lifecycle']['state'],
  'ending_playback_stage':auto['lifecycle']['ending_plan']['playback_stage'],
  'ending_playback_receipts':auto['lifecycle']['ending_plan']['playback_receipts'],
  'gallery_unlocks':profile['gallery_unlocks'],'gallery_transaction_receipts':profile['gallery_transaction_receipts']},
 'native_probe':read(d,'exported-load/failure-native-window.json'),
 'limitation':'Read-only internal evidence audit. Load failed at ending-caption UIA wait, forced cleanup; terminal Load skipped. Ending completion/Gallery/Title/terminal Load/normal Load-process exit unproved. No performance or external C acceptance.'}
(ROOT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ('allowance','native_probe')},indent=2))
# Safe selective review extraction; originals unchanged.
for name in d.namelist():
    if name.endswith(('.json','.log','.png')) and not name.startswith('windows-export/'):
        dest=ROOT/'extracted'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(d.read(name))
