extends GutTest

const PORT := preload("res://scripts/application/minesweeper/SaveManagerDesktopBoardPort.gd")
const BOARD := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const BOARD_RESTORE := preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd")
const AUDIO_RESTORE := preload("res://scripts/application/restore/AudioRestoreParticipant.gd")
const AUDIO_FIXTURE := preload("res://tests/unit/test_audio_manager.gd")
const TERMINAL_FIXTURE := preload("res://tests/unit/test_desktop_terminal_inspection.gd")
const PROFILE := preload("res://scripts/profile/ProfileSchema.gd")
const COMPOSER := preload("res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd")
const CONSEQUENCE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")

class CheckpointRecorder extends RefCounted:
	var preparations := 0
	var captured_inputs: Dictionary = {}
	var disk: Dictionary = {}
	func capture() -> Dictionary: return {"ok": true, "value": {"backup": {"revision": 0}}}
	func preview_checkpoint_id(_run: String) -> Dictionary: return {"ok": true, "value": {"checkpoint_id": "audio-checkpoint"}}
	func prepare(inputs: Dictionary, _kind: StringName, _intent: Dictionary) -> Dictionary:
		preparations += 1
		captured_inputs = inputs.duplicate(true)
		var snapshot: Dictionary = inputs.snapshot_input.duplicate(true)
		snapshot["audio_context"] = inputs.audio_context.duplicate(true)
		return {"ok": true, "value": {"candidate": {"journal_candidate": {}, "checkpoint_id": "audio-checkpoint",
			"autosave_document": {"current_snapshot": {"snapshot": snapshot}}, "storage_backup": null}}}
	func commit(candidate: Dictionary) -> Dictionary:
		disk = candidate.autosave_document.current_snapshot.snapshot.duplicate(true)
		return {"ok": true}
	func rollback(_backup: Dictionary) -> Dictionary: return {"ok": true}

class InvalidCapture extends RefCounted:
	var value: Variant = {}
	func capture() -> Variant: return value

func _audio() -> Node:
	var fixture: Node = autofree(AUDIO_FIXTURE.new())
	fixture.gut = gut
	fixture.before_each()
	assert_true(fixture._manager.initialize(fixture._profile).ok)
	return fixture

func _snapshot_input() -> Dictionary:
	return {"desktop": {"board": BOARD.new().capture(), "consequence": {}}}

func _prepare(port: RefCounted) -> Dictionary:
	return port.prepare_checkpoint(_snapshot_input(), &"safe_marker", {"kind": &"autosave", "reason": &"automatic"})

func test_missing_or_invalid_semantic_capture_refuses_before_checkpoint_preparation() -> void:
	var checkpoint := CheckpointRecorder.new()
	var port := PORT.new(checkpoint)
	assert_eq(_prepare(port).code, &"audio_context_capture_unavailable")
	assert_eq(checkpoint.preparations, 0)
	var invalid := InvalidCapture.new()
	assert_true(port.configure_audio_context_capture(Callable(invalid, &"capture")).ok)
	for value: Variant in [null, {}, {"music_context_id": "menu"},
			{"music_context_id": "", "music_context": {"unexpected": true}, "ambience_context_id": "", "ambience_context": {}}]:
		invalid.value = value
		assert_eq(_prepare(port).code, &"invalid_audio_snapshot")
	assert_eq(checkpoint.preparations, 0)

func test_capture_binding_is_idempotent_and_prepared_audio_is_exact_and_detached() -> void:
	var audio := _audio()
	assert_true(audio._manager.set_music_context("menu").ok)
	assert_true(audio._manager.set_ambience_context("hospital").ok)
	var checkpoint := CheckpointRecorder.new()
	var port := PORT.new(checkpoint)
	var capture := Callable(audio._manager, &"get_semantic_audio_context")
	assert_true(port.configure_audio_context_capture(capture).ok)
	assert_true(port.configure_audio_context_capture(capture).value.already_configured)
	var other := InvalidCapture.new()
	assert_eq(port.configure_audio_context_capture(Callable(other, &"capture")).code, &"audio_context_capture_already_configured")
	var expected: Dictionary = audio._manager.get_semantic_audio_context()
	var prepared := _prepare(port)
	assert_true(prepared.ok, str(prepared))
	assert_eq(checkpoint.captured_inputs.audio_context, expected)
	assert_eq(checkpoint.captured_inputs.audio_context.keys().size(), 4)
	assert_true(audio._manager.set_music_context("ending", {"ending_id": "ending.priscilla.observation"}).ok)
	assert_eq(checkpoint.captured_inputs.audio_context, expected, "saved candidate is detached from later live changes")
	assert_true(_prepare(port).ok)
	assert_eq(checkpoint.captured_inputs.audio_context, audio._manager.get_semantic_audio_context())

func test_post_load_capture_uses_applied_semantic_context_without_publishing_audio() -> void:
	var audio := _audio()
	assert_true(audio._manager.set_music_context("menu").ok)
	var expected := {"music_context_id": "ending", "music_context": {"ending_id": "ending.priscilla.observation"},
		"ambience_context_id": "hospital", "ambience_context": {}}
	var profile: Dictionary = PROFILE.make_defaults()
	var plan: Dictionary = audio._manager.prepare_semantic_restore(expected, profile)
	assert_true(plan.ok, str(plan))
	assert_true(audio._manager.apply_restore_silent(plan.value).ok)
	var operations: int = audio._port.operations.size()
	var checkpoint := CheckpointRecorder.new()
	var port := PORT.new(checkpoint)
	assert_true(port.configure_audio_context_capture(Callable(audio._manager, &"get_semantic_audio_context")).ok)
	assert_true(_prepare(port).ok)
	assert_eq(checkpoint.captured_inputs.audio_context, expected)
	assert_eq(audio._port.operations.size(), operations, "saving captures semantics without playback or publication")

func test_dismissal_checkpoint_keeps_audio_accepted_by_cold_real_audio_and_board_participants() -> void:
	var helper: Node = autofree(TERMINAL_FIXTURE.new())
	helper.gut = gut
	var setup: Dictionary = helper._paid()
	var fixture: Node = setup.fixture
	helper._settled(fixture)
	var audio := _audio()
	assert_true(audio._manager.set_music_context("menu").ok)
	assert_true(audio._manager.set_ambience_context("hospital").ok)
	var expected: Dictionary = audio._manager.get_semantic_audio_context()
	var checkpoint := CheckpointRecorder.new()
	var port := PORT.new(checkpoint)
	assert_true(port.configure_audio_context_capture(Callable(audio._manager, &"get_semantic_audio_context")).ok)
	assert_true(fixture.coordinator.configure_durable_checkpoint(port, COMPOSER, CONSEQUENCE.new()).ok)
	var dismissed: Dictionary = fixture.coordinator.replace_board(fixture._request("beginner"))
	assert_true(dismissed.ok, str(dismissed))
	if not dismissed.ok: return
	assert_eq(checkpoint.disk.desktop.board.phase, "NONE")
	assert_eq(checkpoint.disk.audio_context, expected)
	var parsed: Dictionary = BOARD._inspection_normalize(JSON.parse_string(JSON.stringify(checkpoint.disk)))
	var cold_audio := _audio()
	var audio_participant := AUDIO_RESTORE.new(cold_audio._manager)
	var audio_plan: Dictionary = audio_participant.prepare({"preferences": PROFILE.make_defaults().preferences,
		"audio_context": parsed.audio_context})
	assert_true(audio_plan.ok, str(audio_plan))
	if not audio_plan.ok: return
	assert_true(audio_participant.apply_silent(audio_plan.value.audio_plan).ok)
	assert_eq(cold_audio._manager.get_semantic_audio_context(), expected)
	var board := BOARD.new()
	var board_participant := BOARD_RESTORE.new(board)
	var board_plan: Dictionary = board_participant.prepare({"state": parsed.desktop.board})
	assert_true(board_plan.ok, str(board_plan))
	assert_true(board_participant.apply_silent(board_plan.value.board_plan).ok)
	assert_eq(board.capture().phase, "NONE")
	assert_false(board.has_settled_inspection())
