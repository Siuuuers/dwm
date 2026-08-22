class_name SaveManagerDesktopBoardPort
extends RefCounted

## Production durable first-Reveal checkpoint adapter (Plan 02 Task 6, dwm-p2r.32, Phase D, brief
## Steps 6.10-6.12). Delivered under this renamed path per the controller's coexistence ruling
## (mirroring GameStateDesktopBoardPort.gd's own precedent): the brief's own prose still says
## `SaveManagerMinesweeperPort.gd` in Steps 6.10-6.12, but that name is owned by the retained
## `scripts/application/minesweeper/SaveManagerMinesweeperPort.gd` (dwm-p2r.9 Plan 06 Task 2),
## load-bearing .9-era production law this file never touches or reads.
##
## Mirrors SaveManagerMinesweeperPort.gd's structure exactly -- delegates checkpoint preview/
## capture/prepare/commit/rollback to the ONE real SaveManagerCheckpointPort, reimplements no
## schema/journal/filename/save-capability law of its own -- but `prepare_checkpoint()` accepts ONLY
## a DesktopFirstRevealSnapshotComposer-produced detached post-commit v4 `snapshot_input`: it
## structurally rejects a desktop-less (pre-v4) input, a desktop member missing either sub-key, or a
## desktop member carrying an extra key, before ever reaching preview or disk intent. Every v4
## schema/document-version law itself is enforced by the ONE place that already owns it --
## RunSnapshotSchema.build(), invoked inside SaveManagerCheckpointPort.prepare() -- so a caller
## cannot supply or override schema_version/document_version at all; there is no such input field to
## mismatch.

const CHECKPOINT_METHODS: Array[String] = ["preview_checkpoint_id", "capture", "prepare", "commit", "rollback"]
const _DESKTOP_KEYS: Array[String] = ["board", "consequence"]

var _checkpoint_port: Object = null


func _init(checkpoint_port: Object = null) -> void:
	_checkpoint_port = checkpoint_port


func configure(checkpoint_port: Object) -> Dictionary:
	if checkpoint_port == null:
		return _fail(&"invalid_desktop_board_save_port", "a checkpoint port is required")
	for method in CHECKPOINT_METHODS:
		if not checkpoint_port.has_method(method):
			return _fail(&"invalid_desktop_board_save_port", "checkpoint port is missing " + method)
	if _checkpoint_port != null and _checkpoint_port != checkpoint_port:
		return _fail(&"desktop_board_save_port_already_configured", "another checkpoint port is configured")
	_checkpoint_port = checkpoint_port
	return {"ok": true, "code": &"ok", "value": {"checkpoint_port_instance_id": _checkpoint_port.get_instance_id()}, "receipt": {}}


func capture() -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	return _checkpoint_port.call(&"capture")


func preview_checkpoint_id(run_id: String) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	return _checkpoint_port.call(&"preview_checkpoint_id", run_id)


## `post_commit_snapshot_input` must be exactly what DesktopFirstRevealSnapshotComposer.compose()
## produced (its `value.snapshot_input`): a full v4 `snapshot_input` whose `desktop` member carries
## exactly `{board, consequence}` -- the SAME shape GameState.capture_run_snapshot_input() itself
## returns, which carries no `active_app_id`/`audio_context`/`content_version`/`dialogic_checkpoint`/
## `route_id` (those are orthogonal to Minesweeper state, owned by SceneRouter/AudioManager/
## DialogicBridge, and supplied by the DAY-RESOLUTION checkpoint path's own injected providers --
## see GameStateDayResolutionPort.configure_checkpoint_providers()). DESIGN CHOICE, not literally
## frozen by the brief (documented per this task's own established precedent): this narrow
## "pre_board" checkpoint's sole job is proving MINESWEEPER state is durable before a round is
## consumed, so it stamps safe, neutral defaults for those five orthogonal fields rather than
## threading a whole second provider-injection seam through MinesweeperRoundCoordinator for them;
## the next real autosave (day resolution, logout, ...) always carries their genuine values.
func prepare_checkpoint(post_commit_snapshot_input: Dictionary, checkpoint_kind: StringName,
		disk_write: Dictionary) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	var desktop_error := _validate_desktop_shape(post_commit_snapshot_input)
	if not desktop_error.is_empty():
		return _fail(&"invalid_post_commit_snapshot_input", desktop_error)
	var checkpoint_inputs := {
		"active_app_id": null, "audio_context": {}, "content_version": 1,
		"dialogic_checkpoint": {}, "route_id": "main",
		"snapshot_input": post_commit_snapshot_input,
	}
	return _checkpoint_port.call(&"prepare", checkpoint_inputs, checkpoint_kind, disk_write)


func commit_checkpoint(candidate: Dictionary) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	return _checkpoint_port.call(&"commit", candidate)


func rollback(backup: Dictionary) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	var payload: Variant = backup.get("backup", backup)
	return _checkpoint_port.call(&"rollback", payload if typeof(payload) == TYPE_DICTIONARY else backup)


## Structural desktop-member law only (brief Step 6.10): a desktop-less input (schema 3 or earlier),
## an extra desktop key, or a board-only desktop value all reject here, before preview or disk
## intent. Per-field v4 content validity is DesktopConsequenceState.validate()/DesktopBoardState.
## prepare_restore()'s job, exercised downstream once RunSnapshotSchema.build() runs.
static func _validate_desktop_shape(snapshot_input: Dictionary) -> String:
	if typeof(snapshot_input.get("desktop")) != TYPE_DICTIONARY:
		return "snapshot_input.desktop is required (schema 3 or earlier is not a legal first-Reveal checkpoint source)"
	var desktop: Dictionary = snapshot_input["desktop"]
	var keys: Array = desktop.keys()
	keys.sort()
	var expected := _DESKTOP_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return "snapshot_input.desktop must carry exactly {board,consequence}, saw: " + str(keys)
	if typeof(desktop["board"]) != TYPE_DICTIONARY or typeof(desktop["consequence"]) != TYPE_DICTIONARY:
		return "snapshot_input.desktop.board and .consequence must both be objects"
	return ""


func _readiness() -> Dictionary:
	if _checkpoint_port == null:
		return _fail(&"desktop_board_save_port_not_configured", "")
	return {}


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}, "receipt": {}}
