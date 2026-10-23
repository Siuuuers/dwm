#!/usr/bin/env python3
"""Generate diagnostic-only owner timing overlay; never edit the input checkout.

Apply overlay only to the isolated diagnostic export staging tree. Set
DWM_TITLE_TIMING_PATH to an absolute JSONL path to enable collection.
"""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

PINNED = {'autoload/ApplicationBootstrap.gd': '5f30235eac3d1278a8923c43c5501330eb126d9a2df825b09be0c7588e71ea27', 'autoload/SceneRouter.gd': '105e5e8ce635a9ba804270e93c9fc844dca048141a50e2d84a1d1593683253aa', 'scripts/ui/EndingScene.gd': '8545f7f7b1a31e94d4a49b475ddac175aa3e37ed5816694b678e5382c6c51b5c', 'scripts/application/run/SaveManagerCheckpointPort.gd': '09210b048a1a4c06d70b27ead984eba3415df70caef32780f11b3346fedc6e0e'}
BASE_COMMIT = '81847d8b1560340a3a7769223cee0b46c6bdc0f9'
HELPER_PATH = 'scripts/diagnostics/TitleTiming.gd'
PRELOAD = 'const DWM_TITLE_TIMING := preload("res://scripts/diagnostics/TitleTiming.gd")\n'
HEADERS = {
    'autoload/ApplicationBootstrap.gd': 'extends Node\n',
    'autoload/SceneRouter.gd': 'extends Node\n',
    'scripts/ui/EndingScene.gd': 'extends Control\nclass_name EndingScene\n',
    'scripts/application/run/SaveManagerCheckpointPort.gd': 'class_name SaveManagerCheckpointPort\nextends RefCounted\n',
}
HELPER = '''extends RefCounted
# Diagnostic overlay only. No save payloads, recovery records or product state.
static var ending_depth: int = 0
static var sequence: int = 0
static var disabled: bool = false
const MAX_RECORDS: int = 256
const MAX_BYTES: int = 262144

static func enabled() -> bool:
	return not disabled and not OS.get_environment("DWM_TITLE_TIMING_PATH").is_empty()

static func emit_record(phase: String, edge: String, detail: Dictionary = {}) -> void:
	if not enabled(): return
	if sequence >= MAX_RECORDS:
		_fail("record bound reached")
		return
	var tick: int = Time.get_ticks_usec()
	var utc: float = Time.get_unix_time_from_system()
	var path: String = OS.get_environment("DWM_TITLE_TIMING_PATH")
	if not path.is_absolute_path():
		_fail("output path must be absolute")
		return
	var mode: int = FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ
	var file: FileAccess = FileAccess.open(path, mode)
	if file == null:
		_fail("open failed: " + str(FileAccess.get_open_error()))
		return
	sequence += 1
	var row: Dictionary = {"schema_version": 1, "source": "game", "phase": phase,
		"edge": edge, "ticks_usec": tick, "utc_unix": utc,
		"pid": OS.get_process_id(), "sequence": sequence, "detail": detail}
	var line: String = JSON.stringify(row) + "\\n"
	if file.get_length() + line.to_utf8_buffer().size() > MAX_BYTES:
		file.close()
		_fail("byte bound reached")
		return
	file.seek_end()
	file.store_string(line)
	file.flush()
	var error: int = file.get_error()
	file.close()
	if error != OK: _fail("append/flush failed: " + str(error))

static func result_detail(result: Dictionary) -> Dictionary:
	var value: Variant = result.get("value", {})
	return {"ok": result.get("ok", false), "code": str(result.get("code", "")),
		"committed": result.get("committed", false),
		"checkpoint_id": str(value.get("checkpoint_id", "")) if value is Dictionary else ""}

static func observe_menu(tree: SceneTree) -> Callable:
	if not enabled() or tree == null: return Callable()
	var observer: Callable = func() -> void:
		var menu: Node = tree.current_scene
		if menu == null or menu.scene_file_path != "res://scenes/menu/MenuScene.tscn":
			emit_record("menu_mount", "other_scene")
			return
		var menu_id: int = menu.get_instance_id()
		emit_record("menu_mount", "observed", {"instance_id": menu_id, "ready": menu.is_node_ready()})
		tree.process_frame.connect(func() -> void:
			var current: Node = tree.current_scene
			var same: bool = current != null and current.get_instance_id() == menu_id
			emit_record("menu_first_idle", "observed", {"same_menu": same,
				"meaning": "first process_frame after scene_changed; not control responsiveness"})
		, CONNECT_ONE_SHOT)
	tree.scene_changed.connect(observer, CONNECT_ONE_SHOT)
	return observer

static func _fail(reason: String) -> void:
	disabled = true
	push_warning("DWM_TITLE_TIMING_WRITE_FAILURE: " + reason)
'''

def once(text, anchor, replacement):
    if text.count(anchor) != 1:
        raise ValueError(f'expected one exact anchor: {anchor!r}')
    return text.replace(anchor, replacement, 1)


def wrap(text, signature, args, phase, *, scope=False, gated=False, detail='{}'):
    name = signature.split('func ', 1)[1].split('(', 1)[0]
    private = '_dwm_timing_original_' + name.lstrip('_')
    is_void = signature.endswith('-> void:')
    lines = [signature]
    if gated:
        lines += ['\tif DWM_TITLE_TIMING.ending_depth == 0:', f'\t\treturn {private}({args})']
    if scope:
        lines += ['\tDWM_TITLE_TIMING.ending_depth += 1']
    lines += [f'\tDWM_TITLE_TIMING.emit_record("{phase}", "entry", {detail})']
    lines += [f'\t{private}({args})' if is_void else f'\tvar timing_result: Dictionary = {private}({args})']
    result = '{}' if is_void else 'DWM_TITLE_TIMING.result_detail(timing_result)'
    lines += [f'\tDWM_TITLE_TIMING.emit_record("{phase}", "return", {result})']
    if scope:
        lines += ['\tDWM_TITLE_TIMING.ending_depth -= 1']
    if not is_void:
        lines += ['\treturn timing_result']
    lines += ['', '', signature.replace('func ' + name + '(', 'func ' + private + '(')]
    return once(text, signature, '\n'.join(lines))


def transform(sources):
    changed = {}
    for path, original in sources.items():
        text = original
        if path.endswith('ApplicationBootstrap.gd'):
            text = wrap(text, 'func _commit_ending_checkpoint() -> Dictionary:', '', 'ending_checkpoint', scope=True)
        elif path.endswith('EndingScene.gd'):
            text = wrap(text, 'func on_ending_playback_completed(completion: Dictionary) -> void:', 'completion', 'ending_completion', detail='{"expected_stage": str((_pending_ending_command.get("playback_context", {}) as Dictionary).get("expected_stage", ""))}')
        elif path.endswith('SaveManagerCheckpointPort.gd'):
            text = wrap(text, 'func prepare(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary:', 'checkpoint_inputs, checkpoint_kind, disk_write', 'ending_checkpoint_prepare', gated=True, detail='{"checkpoint_kind": str(checkpoint_kind)}')
            text = wrap(text, 'func commit(candidate: Dictionary) -> Dictionary:', 'candidate', 'ending_checkpoint_commit', gated=True, detail='{"checkpoint_id": str(candidate.get("checkpoint_id", ""))}')
        elif path.endswith('SceneRouter.gd'):
            text = once(text, 'func goto_menu() -> void:\n\t_change_to("menu")', '''func goto_menu() -> void:
	DWM_TITLE_TIMING.emit_record("goto_menu", "entry")
	var timing_observer: Callable = DWM_TITLE_TIMING.observe_menu(get_tree())
	var timing_result: Dictionary = _change_to("menu")
	if not timing_result.get("ok", false) and timing_observer.is_valid() and get_tree().scene_changed.is_connected(timing_observer):
		get_tree().scene_changed.disconnect(timing_observer)
	DWM_TITLE_TIMING.emit_record("goto_menu", "return", DWM_TITLE_TIMING.result_detail(timing_result))''')
        else:
            raise ValueError('unexpected source: ' + path)
        # Keep the complete pinned class header ahead of every class-body member.
        header = HEADERS[path]
        if not text.startswith(header):
            raise ValueError('class header mismatch: ' + path)
        changed[path] = header + '\n' + PRELOAD + text[len(header):]
    changed[HELPER_PATH] = HELPER
    return changed


def digest(data):
    return hashlib.sha256(data).hexdigest()


def generate(root, output):
    root, output = Path(root).resolve(), Path(output).resolve()
    if output == root or root in output.parents:
        raise ValueError('output must be outside source checkout')
    if output.exists():
        raise ValueError('output must not exist')
    sources = {}
    for path, expected in PINNED.items():
        raw = (root / path).read_bytes()
        if digest(raw) != expected:
            raise ValueError('input hash mismatch: ' + path)
        sources[path] = raw.decode('utf-8')
    if (root / HELPER_PATH).exists():
        raise ValueError('helper path already exists')
    changed = transform(sources)  # Validate every anchor before any output write.
    inventory, diff = [], []
    for path, text in changed.items():
        before = sources.get(path, '')
        diff.extend(difflib.unified_diff(before.splitlines(True), text.splitlines(True),
                    fromfile='a/' + path if path in sources else '/dev/null', tofile='b/' + path))
        inventory.append({'path': path, 'input_sha256': PINNED.get(path),
                          'output_sha256': digest(text.encode()), 'before_sha256': PINNED.get(path),
                          'after_sha256': digest(text.encode()), 'bytes': len(text.encode())})
    output.mkdir(parents=True)
    for path, text in changed.items():
        target = output / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(text.encode())
    (output / 'timing.patch').write_text(''.join(diff))
    (output / 'timing-inventory.json').write_text(json.dumps({
        'schema_version': 1, 'diagnostic_only': True, 'diagnostic': True,
        'base_commit': BASE_COMMIT,
        'files': inventory, 'patch_sha256': digest(''.join(diff).encode())}, indent=2) + '\n')
    return inventory

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    generate(args.root, args.output)
