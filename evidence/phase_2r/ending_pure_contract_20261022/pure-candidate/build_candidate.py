from pathlib import Path
import hashlib,json,difflib
p=Path(__file__).parent
base=(p.parent/'ledger-candidate/scripts/domain/narrative/SceneEventContract.gd').read_text()
s=base
old='static func inspect_scene(envelope: Variant, bundle: Variant) -> Dictionary:\n'
new='''static func inspect_scene(envelope: Variant, bundle: Variant) -> Dictionary:
	var context := _inspect_scene_context(envelope, bundle)
	return context.inspection if context.ok else context

## Call-local computed material only. Public entrypoints always inspect fresh inputs.
## No issuer, Profile, saved-data or cross-call validation authority is retained here.
static func _inspect_scene_context(envelope: Variant, bundle: Variant) -> Dictionary:
'''
assert s.count(old)==1;s=s.replace(old,new,1)
start=s.index('static func _inspect_scene_context(');end=s.index('static func validate_target(',start)
segment=s[start:end];assert segment.count('\treturn shaped\n')==1
segment=segment.replace('\treturn shaped\n','\treturn {"ok": true, "inspection": shaped, "registered": registered}\n',1);s=s[:start]+segment+s[end:]
old='''static func scene_completion_request(envelope: Dictionary, anchor: Dictionary, bundle: Dictionary) -> Dictionary:
	var checked := inspect_scene(envelope, bundle)
	if not checked.ok: return checked
	if envelope.kind != "scene.transition" or not _valid_anchor(anchor, envelope.source): return _fail(&"scene_completion_source_invalid")
	var registered := validate_bundle_structure(bundle)
'''
new='''static func scene_completion_request(envelope: Dictionary, anchor: Dictionary, bundle: Dictionary) -> Dictionary:
	var context := _inspect_scene_context(envelope, bundle)
	if not context.ok: return context
	return _scene_completion_request_inspected(envelope, anchor, context.inspection, context.registered)

static func _scene_completion_request_inspected(envelope: Dictionary, anchor: Dictionary,
		checked: Dictionary, registered: Dictionary) -> Dictionary:
	if envelope.kind != "scene.transition" or not _valid_anchor(anchor, envelope.source): return _fail(&"scene_completion_source_invalid")
'''
assert s.count(old)==1;s=s.replace(old,new,1)
old='''static func make_scene_receipt(envelope: Dictionary, anchor: Dictionary, result: Dictionary, bundle: Dictionary) -> Dictionary:
	var checked := inspect_scene(envelope, bundle)
	if not checked.ok: return checked
	if not _valid_anchor(anchor, envelope.source): return _fail(&"event_anchor_invalid")
	var registered := validate_bundle_structure(bundle)
'''
new='''static func make_scene_receipt(envelope: Dictionary, anchor: Dictionary, result: Dictionary, bundle: Dictionary) -> Dictionary:
	var context := _inspect_scene_context(envelope, bundle)
	if not context.ok: return context
	var checked: Dictionary = context.inspection
	var registered: Dictionary = context.registered
	if not _valid_anchor(anchor, envelope.source): return _fail(&"event_anchor_invalid")
'''
assert s.count(old)==1;s=s.replace(old,new,1)
start=s.index('static func make_scene_receipt(');end=s.index('static func validate_scene_result(',start)
segment=s[start:end].replace('validate_scene_result(envelope, result, bundle)','_validate_scene_result_inspected(envelope, result, registered)').replace('scene_completion_request(envelope, anchor, bundle)','_scene_completion_request_inspected(envelope, anchor, checked, registered)')
s=s[:start]+segment+s[end:]
old='''static func validate_scene_result(envelope: Dictionary, result: Variant, bundle: Dictionary) -> Dictionary:
	var checked := inspect_scene(envelope, bundle)
	if not checked.ok: return checked
	if not _json_data(result) or not result is Dictionary or typeof(result.get("kind")) != TYPE_STRING: return _fail(&"scene_result_invalid")
	var registered := validate_bundle_structure(bundle)
'''
new='''static func validate_scene_result(envelope: Dictionary, result: Variant, bundle: Dictionary) -> Dictionary:
	var context := _inspect_scene_context(envelope, bundle)
	if not context.ok: return context
	return _validate_scene_result_inspected(envelope, result, context.registered)

static func _validate_scene_result_inspected(envelope: Dictionary, result: Variant,
		registered: Dictionary) -> Dictionary:
	if not _json_data(result) or not result is Dictionary or typeof(result.get("kind")) != TYPE_STRING: return _fail(&"scene_result_invalid")
'''
assert s.count(old)==1;s=s.replace(old,new,1)
name='scripts/domain/narrative/SceneEventContract.gd'
(p/name).write_text(s)
rows=[]
for path in [name]:
 b=(p/path).read_bytes();rows.append(dict(path=path,bytes=len(b),sha256=hashlib.sha256(b).hexdigest(),blob=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()))
(p/'manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
(p/'candidate.patch').write_text(''.join(difflib.unified_diff(base.splitlines(True),s.splitlines(True),fromfile='baseline/'+name,tofile='candidate/'+name)))
print(json.dumps(rows,indent=2))
