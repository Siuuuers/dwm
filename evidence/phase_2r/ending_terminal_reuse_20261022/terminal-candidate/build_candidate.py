"""Reproducible pure-text extraction; no engine or PowerShell execution."""
from pathlib import Path
import hashlib
import json
import difflib
import re
import sys

root = Path(__file__).parent
source = Path(sys.argv[1])
baseline = source.read_text()
assert hashlib.sha256(source.read_bytes()).hexdigest() == '67c2c23286de1fb1318b6c68473701367114a2e9b01c2301e0ef6d1bccd98851'

def body(name, text):
    match = re.search(r'^static func ' + name + r'\(.*?(?=^static func |\Z)', text, re.M | re.S)
    assert match, name
    return match.group()

old_context = body('_inspect_scene_context', baseline)
shape_guard, binding = old_context.split('\tvar entries: Dictionary = registered.value.entries', 1)
binding = '\tvar entries: Dictionary = registered.value.entries' + binding
version_guard = shape_guard.split('\n', 1)[1].split('\tvar shaped := _inspect_scene_shape(envelope)\n')[0]
shape_helper = ('static func _inspect_scene_versioned_shape(envelope: Variant) -> Dictionary:\n'
                + version_guard + '\treturn _inspect_scene_shape(envelope)\n\n')
new_context = '''static func _inspect_scene_context(envelope: Variant, bundle: Variant) -> Dictionary:
	var shaped := _inspect_scene_versioned_shape(envelope)
	if not shaped.ok: return shaped
	var registered := validate_bundle_structure(bundle)
	if not registered.ok: return registered
	return _bind_scene_context(envelope, shaped, registered)

'''
binding_helper = ('static func _bind_scene_context(envelope: Variant, shaped: Dictionary, registered: Dictionary) -> Dictionary:\n' + binding)

old_receipt = body('make_scene_receipt', baseline)
receipt_prefix, receipt_tail = old_receipt.split('\tvar checked: Dictionary = context.inspection', 1)
receipt_tail = '\tvar checked: Dictionary = context.inspection' + receipt_tail
new_receipt = receipt_prefix + '\treturn _make_scene_receipt_from_context(envelope, anchor, result, context)\n\n'
receipt_helper = ('static func _make_scene_receipt_from_context(envelope: Dictionary, anchor: Dictionary,\n'
                  '\t\tresult: Dictionary, context: Dictionary) -> Dictionary:\n' + receipt_tail)
old_terminal_call = '\tvar rebuilt := make_scene_receipt(envelope, event.reading_anchor, event.result, bundle)\n'
new_terminal_call = '''	var shaped := _inspect_scene_versioned_shape(envelope)
	if not shaped.ok: return shaped
	var context := _bind_scene_context(envelope, shaped, registered)
	if not context.ok: return context
	var rebuilt := _make_scene_receipt_from_context(envelope, event.reading_anchor, event.result, context)
'''
assert baseline.count(old_terminal_call) == 1
candidate = baseline.replace(old_context, new_context + shape_helper + binding_helper, 1)
candidate = candidate.replace(old_receipt, new_receipt + receipt_helper, 1)
candidate = candidate.replace(old_terminal_call, new_terminal_call, 1)

# Reverse all three extractions plus the one terminal call replacement.
restored = candidate.replace(new_context + shape_helper + binding_helper, old_context, 1)
restored = restored.replace(new_receipt + receipt_helper, old_receipt, 1)
restored = restored.replace(new_terminal_call, old_terminal_call, 1)
assert restored.encode() == source.read_bytes()
names = re.findall(r'^static func (\w+)\(', baseline, re.M)
changed = ['_inspect_scene_context', 'make_scene_receipt', 'make_scene_terminal_admission']
unchanged = [name for name in names if name not in changed]
assert all(body(name, baseline) == body(name, candidate) for name in unchanged)
assert body('make_scene_terminal_admission', candidate).replace(new_terminal_call, old_terminal_call) == body('make_scene_terminal_admission', baseline)
assert binding_helper.split(' -> Dictionary:\n', 1)[1] == binding
assert receipt_helper.split(' -> Dictionary:\n', 1)[1] == receipt_tail
assert shape_helper.split(' -> Dictionary:\n', 1)[1] == version_guard + '\treturn _inspect_scene_shape(envelope)\n\n'

data = candidate.encode()
target = root / 'scripts/domain/narrative/SceneEventContract.gd'
target.write_bytes(data)
sha = hashlib.sha256(data).hexdigest()
blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
(root / 'candidate.patch').write_text(''.join(difflib.unified_diff(baseline.splitlines(True), candidate.splitlines(True), fromfile='baseline/SceneEventContract.gd', tofile='candidate/SceneEventContract.gd')))
(root / 'manifest.json').write_text(json.dumps([{'path': 'scripts/domain/narrative/SceneEventContract.gd', 'bytes': len(data), 'sha256': sha, 'blob': blob}], indent=2) + '\n')
(root / 'transformation-proof.json').write_text(json.dumps({
    'baseline_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'candidate_sha256': sha,
    'exact_original_reconstruction': True, 'changed_existing_functions': changed,
    'unchanged_existing_function_count': len(unchanged),
    'unchanged_existing_functions': unchanged,
    'new_helpers': ['_inspect_scene_versioned_shape', '_bind_scene_context', '_make_scene_receipt_from_context'],
    'binding_tail_byte_identical': True, 'receipt_tail_byte_identical': True,
    'version_guard_byte_identical': True, 'terminal_only_call_site_changed': True,
    'engine_validation': 'not run; independent review and cloud qualification pending'
}, indent=2) + '\n')
print(json.dumps({'sha256': sha, 'bytes': len(data), 'unchanged_existing_functions': len(unchanged)}))
