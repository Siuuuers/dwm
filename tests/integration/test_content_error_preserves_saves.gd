extends "res://addons/gut/test.gd"
## Real checkpoint decoding, storage, SaveManager and application error fence.
## Native Load activation and OS Quit require a separate exported-game journey.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const SCOPE := preload("res://tests/support/SceneValidationScope.gd")

class ContentErrorBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	func _ready() -> void:
		pass

var _fixture: RefCounted
var _scope: RefCounted
var _bootstrap: Node
var _original_bootstrap: Node
var _original_index := 0
var _ready_fixture := false
var _previous_pause := false

func before_each() -> void:
	_previous_pause = get_tree().paused
	_scope = SCOPE.new()
	_scope.install(true)
	_fixture = FIXTURE.new()
	var setup: Dictionary = _fixture.setup(get_tree())
	assert_true(setup.ok, str(setup))
	_ready_fixture = setup.ok
	if not _ready_fixture: return
	_original_bootstrap = get_tree().root.get_node("ApplicationBootstrap")
	_original_index = _original_bootstrap.get_index()
	get_tree().root.remove_child(_original_bootstrap)
	_bootstrap = ContentErrorBootstrap.new()
	_bootstrap.name = "ApplicationBootstrap"
	_bootstrap._application_gate = _fixture.gate
	get_tree().root.add_child(_bootstrap)

func after_each() -> void:
	get_tree().paused = _previous_pause
	if is_instance_valid(_bootstrap): _bootstrap.free()
	if _fixture != null: _fixture.close()
	if is_instance_valid(_original_bootstrap):
		get_tree().root.add_child(_original_bootstrap)
		get_tree().root.move_child(_original_bootstrap, _original_index)
	if _scope != null: _scope.restore()

func test_missing_saved_id_cannot_overwrite_existing_slot_quicksave_or_autosave() -> void:
	if not _ready_fixture: return
	var started: Dictionary = _fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	_fixture.confirm_activation()
	assert_true(_fixture.manager.save_latest_to_slot(2).ok)
	assert_true(_fixture.manager.quick_save_latest().ok)
	assert_true(_fixture.manager.autosave_latest().ok)
	var required := ["slot_2.json", "quicksave.json", "autosave.json"]
	var paths: Array = required + ["desktop-issuer-root.json", "desktop-continuation-operations.json", "profile.json"]
	var before := {}
	for path: String in paths:
		var existed: bool = _fixture.storage.exists(path)
		before[path] = {"exists": existed}
		if path in required: assert_true(existed, "required saved file exists: " + path)
		if not existed: continue
		var read: Dictionary = _fixture.storage.read_text(path)
		assert_true(read.ok, str(read))
		if not read.ok: return
		before[path]["text"] = read.value
	var stable: Dictionary = _fixture.manager.get_latest_stable_checkpoint()
	var document: Dictionary = _fixture.read_autosave().value
	var checkpoint: Dictionary = document.current_snapshot.snapshot.narrative_checkpoint.duplicate(true)
	checkpoint.reading_session.position_id = "line.missing.saved"
	checkpoint.reading_session.captions[0].line_id = "line.missing.saved"
	# Exercise the same compact expansion used by native restoration. The
	# detached bad position must never become the journal's stable checkpoint.
	var failed: Dictionary = SESSION.expand_player_checkpoint(checkpoint)
	assert_eq(failed.get("code"), &"reading_content_error", str(failed))
	if failed.get("code") != &"reading_content_error": return
	assert_eq(_fixture.manager._content_result(failed), failed)
	assert_true(_fixture.gate.is_fatal_latched())
	assert_false(_fixture.manager.get_save_capability().enabled)
	assert_eq(_fixture.manager.save_latest_to_slot(2).get("code"), &"APPLICATION_FATAL")
	assert_eq(_fixture.manager.quick_save_latest().get("code"), &"APPLICATION_FATAL")
	assert_eq(_fixture.manager.autosave_latest().get("code"), &"APPLICATION_FATAL")
	assert_eq(_fixture.manager.get_latest_stable_checkpoint(), stable)
	for path: String in paths:
		assert_eq(_fixture.storage.exists(path), before[path].exists, "failure preserves file presence: " + path)
		if before[path].exists:
			assert_eq(_fixture.storage.read_text(path).value, before[path].text, "failure preserves exact saved bytes: " + path)
	var confirmation: Control = _bootstrap.get_node("ContentError/ContentErrorConfirmation")
	assert_string_contains(confirmation.request.body, "line.missing.saved")
	get_tree().paused = _previous_pause
