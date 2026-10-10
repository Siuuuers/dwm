extends "res://addons/gut/test.gd"
## Real filesystem/issuer/Profile/Run/Save owners. Activation and ancillary
## restore participants are diagnostic; no rendered or production UI claim.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
var fixture: RefCounted
var fixture_ready := false

func before_all() -> void:
	fixture = FIXTURE.new()
	var setup: Dictionary = fixture.setup(get_tree())
	assert_true(setup.get("ok", false), str(setup))
	if not setup.get("ok", false): return
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	fixture_ready = fixture.manager.capture_committed_scene_creation(started.transaction_id).get("ok", false)
	assert_true(fixture_ready)

func after_all() -> void:
	if fixture != null: fixture.close()

func test_admitted_scene_inspection_and_cancelled_consent_preserve_physical_and_live_state() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var before: Dictionary = _observed()
	var inspected: Dictionary = fixture.manager.inspect_backup("autosave")
	assert_true(inspected.get("ok", false), str(inspected))
	if not inspected.get("ok", false): return
	var record: Dictionary = inspected.value
	assert_eq(record.state, "occupied")
	assert_eq(record.family, "scene")
	assert_eq(record.load_family, "scene")
	assert_null(record.day)
	assert_null(record.load_day)
	assert_true(record.loadable)
	assert_false(record.fallback)
	assert_eq(record.revision, fixture.storage.inspect_revision("autosave.json").value.revision)
	var document: Dictionary = fixture.read_autosave().value
	assert_eq(record.saved_time, document.saved_time.hhmm)
	assert_eq(record.load_saved_time, record.saved_time)
	assert_false(record.has("prepared_restore"))
	var port := PORT.new()
	assert_true(port.configure(fixture.manager, "title").ok)
	var projection: Dictionary = port.get_projection()
	assert_true(projection.ok, str(projection))
	var shown: Dictionary = projection.value.records[0]
	assert_eq(shown.family, "scene")
	assert_eq(shown.load_family, "scene")
	assert_null(shown.day)
	assert_null(shown.load_day)
	assert_true(shown.actions.load)
	assert_false(shown.actions.save)
	for key: String in ["revision", "prepared_restore", "snapshot", "scene_preparation_token"]:
		assert_false(shown.has(key), "private custody stays with SaveManager")
	var empty: Dictionary = projection.value.records[1]
	assert_eq(empty.state, "empty")
	assert_null(empty.family)
	assert_null(empty.load_family)
	var consent: Dictionary = port.prepare_action("load", "autosave")
	assert_true(consent.ok, str(consent))
	if not consent.ok: return
	assert_eq(consent.value.record, shown)
	assert_false(consent.value.confirmation_required, "title nonfallback Load policy is unchanged")
	port.cancel_action(consent.value.token)
	assert_eq(port.commit_action(consent.value.token).get("code"), &"stale_backup_action")
	assert_true(fixture.manager._backup_actions.is_empty())
	assert_eq(_observed(), before, "inspection/prepare/cancel does not write, allocate or publish")

func test_unadmitted_scene_shaped_bytes_have_no_family_or_load_permission() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	# Deliberate corrupt-file diagnostic; never used as a positive scene source.
	var raw := '{"schema_version":9,"kind":"slot","slot_id":7}'
	var written: Dictionary = fixture.storage.write_atomic("slot_7.json", raw,
		func(_text: String) -> Dictionary: return {"ok": true, "value": {}})
	assert_true(written.ok, str(written))
	if not written.ok: return
	var before: Dictionary = fixture.storage.inspect_revision("slot_7.json")
	var inspected: Dictionary = fixture.manager.inspect_backup("slot:7")
	assert_true(inspected.ok)
	assert_eq(inspected.value.state, "unavailable")
	assert_eq(inspected.value.reason, "unreadable", "supported schema number is not a future version or admission")
	assert_null(inspected.value.family)
	assert_null(inspected.value.load_family)
	assert_null(inspected.value.day)
	assert_false(inspected.value.loadable)
	assert_eq(fixture.manager.prepare_backup_action("load", "slot:7").get("code"), &"backup_load_unavailable")
	assert_eq(fixture.storage.inspect_revision("slot_7.json"), before)
	assert_true(fixture.manager._backup_actions.is_empty())

func _observed() -> Dictionary:
	return {"autosave": fixture.storage.read_text("autosave.json"),
		"profile": fixture.storage.read_text("profile.json"), "root": fixture.issuer.capture_root(),
		"game": fixture.game.capture_restore_state(), "profile_state": fixture.profile.get_profile_snapshot(),
		"profile_revision": fixture.profile.get_profile_revision(), "journal": fixture.manager._journal.capture_state(),
		"route_publications": fixture.participants.route.publications,
		"narrative_publications": fixture.participants.narrative.publications}
