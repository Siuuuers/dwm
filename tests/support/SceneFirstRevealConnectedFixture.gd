extends "res://tests/support/ScenePlayableFixture.gd"
## Real Profile, generation, physical owner, GameState, native Bridge and Save owners.
## Parent supplies TEST-authored content and diagnostic ancillary restore participants.
const PHYSICAL := preload("res://scripts/application/run/DatingPhysicalOwner.gd")
const GENERATION := preload("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd")
const ATTEMPTS := preload("res://scripts/profile/DatingAttemptLedger.gd")
class ProfileWriteRefusal extends WriteRefusal:
	var refuse_profile := false
	var profile_refusals := 0
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if refuse_profile and path.replace("\\", "/").ends_with("/profile.json.next"):
			refuse_profile = false
			profile_refusals += 1
			return {"ok": false, "code": &"TEST.profile_write_refused", "message": path}
		return super.write_bytes(path, bytes)
var physical: RefCounted
var challenge_command: Dictionary = {}
var challenge_token := ""

func setup_connected(scene_tree: SceneTree) -> Dictionary:
	var checked: Dictionary = await setup_playable(scene_tree)
	if not checked.ok: return checked
	files = ProfileWriteRefusal.new()
	storage._file_ops = files
	checked = game.configure_scene_challenge_runtime()
	if not checked.ok: return checked
	physical = PHYSICAL.new()
	checked = physical.configure(issuer, game, profile, GENERATION.new())
	if checked.ok: checked = physical.configure_attempt_history(gate)
	if checked.ok: checked = game.configure_dating_restore_reconciler(Callable(physical, "reconcile_restore_silent"))
	return checked

func admit_challenge() -> Dictionary:
	var captured: Dictionary = game.capture_scene_challenge_command()
	if not captured.get("ok", false): return captured
	var bound: Dictionary = physical.configure_scene_challenges(captured.value.bundle, game)
	if not bound.get("ok", false): return bound
	challenge_command = captured.value.command.duplicate(true)
	var begun: Dictionary = physical.begin_physical(challenge_command)
	if begun.get("ok", false): challenge_token = begun.value.physical_token
	return begun

func reveal() -> Dictionary:
	return physical.dispatch_scene_panel_action(challenge_token, "reveal", 323, 0)

func panel() -> Dictionary:
	return physical.pull_scene_panel(challenge_token)

func challenge_record() -> Dictionary:
	return game.capture_dating_challenge_state().value

func challenge_attempt(branch: String = "") -> Dictionary:
	var identity: Dictionary = game.capture_run_snapshot_input().lifecycle
	return profile.get_dating_attempt(identity.run_id, ATTEMPTS.semantic_slot(challenge_command.context), "", branch)

func close_restart() -> void:
	await super.close_restart()
	physical = null
