from pathlib import Path
import hashlib,json,difflib
p=Path(__file__).parent
base=(p.parent/'source-audit/scripts/domain/narrative/SceneEventContract.gd').read_text()
hbase=Path('/workspace/scratch/ba996ff67192/physical-proof-candidate/scripts/narrative/SceneValidationTiming.gd').read_text()
assert hashlib.sha256(base.encode()).hexdigest()=='5c57c53209c61e5ac4d983f3d954ea856012dbdee4a1afdee64b8d60da39b138'
const='const _VALIDATION_TIMING := preload("res://scripts/narrative/SceneValidationTiming.gd")\n'
s=base.replace('extends RefCounted\n','extends RefCounted\n'+const,1)
pairs=[]
for name,args,call,kind in [
 ('validate_bundle_structure','bundle: Variant','bundle','bundle_validation'),
 ('validate_scene_receipts','receipts: Dictionary, bundle: Dictionary, issuer: Object,\n\t\tcreation_owner: Object = null, contacts: Dictionary = {}','receipts, bundle, issuer, creation_owner, contacts','receipt_validation')]:
 head=f'static func {name}({args}) -> Dictionary:\n'
 assert s.count(head)==1
 wrapper=head+f'\tvar started_us: int = _VALIDATION_TIMING.start_sample()\n\tvar result: Dictionary = _{name}_observed_body({call})\n\t_VALIDATION_TIMING.finish_sample("{kind}", started_us, bool(result.get("ok", false)))\n\treturn result\n\nstatic func _{name}_observed_body({args}) -> Dictionary:\n'
 s=s.replace(head,wrapper,1);pairs.append((head,wrapper))
reconstructed=s.replace(const,'',1)
for head,wrapper in pairs:reconstructed=reconstructed.replace(wrapper,head,1)
assert reconstructed==base
needle='"physical_proof_failures": 0, "inclusive_nested": true'
assert hbase.count(needle)==1
h=hbase.replace(needle,'"physical_proof_failures": 0, "receipt_validation_calls": 0, "receipt_validation_us": 0,\n\t\t"receipt_validation_failures": 0, "bundle_validation_calls": 0, "bundle_validation_us": 0,\n\t\t"bundle_validation_failures": 0, "inclusive_nested": true')
files={'scripts/domain/narrative/SceneEventContract.gd':s,'scripts/narrative/SceneValidationTiming.gd':h}
rows=[];patch=''
for name,txt in files.items():
 f=p/name;f.parent.mkdir(parents=True,exist_ok=True);f.write_text(txt);b=f.read_bytes()
 rows.append(dict(path=name,bytes=len(b),sha256=hashlib.sha256(b).hexdigest(),blob=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()))
 old=base if name.endswith('SceneEventContract.gd') else hbase
 patch+=''.join(difflib.unified_diff(old.splitlines(True),txt.splitlines(True),fromfile='baseline/'+name,tofile='candidate/'+name))
(p/'manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
(p/'candidate.patch').write_text(patch)
(p/'transformation-verification.json').write_text(json.dumps({'original_contract_reconstructed_exactly':True,'parent':'5a506a9768287762b2a0e86f94d5eb0006562cc5','no_local_Godot_or_PowerShell':True},indent=2)+'\n')
print(json.dumps(rows,indent=2))
