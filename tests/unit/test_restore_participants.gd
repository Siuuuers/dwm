extends "res://addons/gut/test.gd"

const RUN_PATH := "res://scripts/application/restore/RunRestoreParticipant.gd"
const PROFILE_PATH := "res://scripts/application/restore/ProfileRestoreParticipant.gd"
const LOCALIZATION_PATH := "res://scripts/application/restore/LocalizationRestoreParticipant.gd"
const AUDIO_PATH := "res://scripts/application/restore/AudioRestoreParticipant.gd"
const ROUTE_PATH := "res://scripts/application/restore/RouteRestoreParticipant.gd"
const NARRATIVE_PATH := "res://scripts/application/restore/NarrativeRestoreParticipant.gd"
const CALL_LOG_PATH := "res://tests/support/RestoreCallLog.gd"

# Fake owner port implementing every owner-side method the six participants call.
class FakeOwner extends RefCounted:
	var log: RefCounted
	var id: String
	var fail_at: StringName = &""
	var received_pair_witnessed_forms: Variant = null
	func _init(owner_id: String, call_log: RefCounted) -> void:
		id = owner_id
		log = call_log
	func _r(method: String) -> void:
		log.record(id, method)
	func _guard(method: String) -> Dictionary:
		if fail_at == StringName(method):
			return {"ok": false, "code": &"forced_owner_failure", "message": method}
		return {}
	func prepare_new_run_snapshot_input(run_id: String, branch_id: String, desktop_timeline_generation: int,
			causal_day_instance: String, causal_day_instance_issuer_receipt: Dictionary, dark_mode: bool,
			pair_witnessed_forms: Variant = null) -> Dictionary:
		_r("prepare_new_run_snapshot_input")
		received_pair_witnessed_forms = pair_witnessed_forms
		var g := _guard("prepare_new_run_snapshot_input")
		if not g.is_empty(): return g
		return {"ok": true, "value": {"snapshot_input": {"lifecycle": {
			"run_id": run_id, "dark_mode": dark_mode, "day": 1, "branch_id": branch_id,
			"desktop_timeline_generation": desktop_timeline_generation,
			"causal_day_instance": causal_day_instance,
			"causal_day_instance_issuer_receipt": causal_day_instance_issuer_receipt,
		}}}}
	func get_profile_snapshot() -> Dictionary:
		return preload("res://scripts/profile/ProfileSchema.gd").make_defaults()
	func prepare_profile_document(candidate: Dictionary) -> Dictionary:
		_r("prepare_profile_document")
		var guarded := _guard("prepare_profile_document")
		if not guarded.is_empty(): return guarded
		return preload("res://scripts/profile/ProfileSchema.gd").validate(candidate)
	func prepare_legacy_profile_patch(_legacy: Dictionary, _mappings: Dictionary = {}) -> Dictionary:
		_r("prepare_legacy_profile_patch")
		var g := _guard("prepare_legacy_profile_patch")
		if not g.is_empty(): return g
		return {"ok": true, "value": preload("res://scripts/profile/ProfileSchema.gd").make_defaults()}
	func prepare_locale(locale_id: String, _font_style: String = "pixel", _text_size: int = 100) -> Dictionary:
		_r("prepare_locale")
		var g := _guard("prepare_locale")
		if not g.is_empty(): return g
		return {"ok": true, "value": {"canonical_locale_id": locale_id}}
	func prepare_semantic_restore(context: Dictionary, _profile: Dictionary) -> Dictionary:
		_r("prepare_semantic_restore")
		var g := _guard("prepare_semantic_restore")
		if not g.is_empty(): return g
		return {"ok": true, "value": {"snapshot": context.duplicate(true)}}
	func prepare_route_restore(route_id: String, _context: Dictionary) -> Dictionary:
		_r("prepare_route_restore")
		var g := _guard("prepare_route_restore")
		if not g.is_empty(): return g
		return {"ok": true, "value": {"route_ready_token": {"route_id": route_id, "layout_id": "main_layout", "generation": 1}}}
	func apply_route_restore_silent(plan: Dictionary) -> Dictionary:
		_r("apply_route_restore_silent")
		var g := _guard("apply_route_restore_silent")
		if not g.is_empty(): return g
		return {"ok": true, "value": {"route_ready_token": plan.get("route_ready_token", {"route_id": "main", "layout_id": "main_layout", "generation": 1})}}
	func capture_restore_state() -> Dictionary:
		_r("capture_restore_state")
		return {"ok": true, "value": {"backup": id}}
	func apply_restore_silent(_plan: Dictionary) -> Dictionary:
		_r("apply_restore_silent")
		var g := _guard("apply_restore_silent")
		if not g.is_empty(): return g
		return {"ok": true}
	func rollback_restore_silent(_backup: Dictionary) -> Dictionary:
		_r("rollback_restore_silent")
		return {"ok": true}
	func finalize_restore() -> Dictionary:
		_r("finalize_restore")
		return {"ok": true}

func _log() -> RefCounted:
	return load(CALL_LOG_PATH).new()

func _all_exist() -> bool:
	for path: String in [RUN_PATH, PROFILE_PATH, LOCALIZATION_PATH, AUDIO_PATH, ROUTE_PATH, NARRATIVE_PATH, CALL_LOG_PATH]:
		if not ResourceLoader.exists(path, "Script"):
			return false
	return true

func test_all_participant_scripts_exist() -> void:
	assert_true(_all_exist(), "all six restore participants + call log must exist")

func test_run_participant_prepare_and_delegation() -> void:
	if not _all_exist(): return
	var log := _log()
	var owner := FakeOwner.new("run", log)
	var participant: RefCounted = load(RUN_PATH).new(owner)
	var prepared: Dictionary = participant.prepare({"snapshot": {"run_id": "r"}})
	assert_true(prepared["ok"])
	assert_eq(prepared["value"]["run_plan"]["snapshot"], {"run_id": "r"})
	assert_false(participant.prepare({}).get("ok", true), "missing snapshot rejects")
	var receipt := {"receipt_id": "issuer_receipt.fixture-causal-day-b", "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": "causal-day-b", "numeric_value": null}
	var new_run: Dictionary = participant.prepare_new_run("run-b", "branch-b", 0, "causal-day-b", receipt, true)
	assert_true(new_run["ok"], JSON.stringify(new_run))
	assert_eq(new_run["value"]["snapshot_input"]["lifecycle"]["run_id"], "run-b")
	assert_eq(new_run["value"]["snapshot_input"]["lifecycle"]["dark_mode"], true)
	assert_eq(owner.received_pair_witnessed_forms, [], "Omitted public argument forwards the participant default.")
	var witnessed_forms := ["ambiguous_dark", "love_sweet"]
	var witnessed_run: Dictionary = participant.prepare_new_run("run-c", "branch-c", 0, "causal-day-b", receipt, true, witnessed_forms)
	assert_true(witnessed_run["ok"], JSON.stringify(witnessed_run))
	assert_eq(owner.received_pair_witnessed_forms, witnessed_forms, "Previously witnessed pair forms reach the new-run owner unchanged.")
	assert_true(participant.capture()["ok"])
	assert_true(participant.apply_silent({})["ok"])
	assert_true(participant.rollback_silent({})["ok"])
	assert_true(participant.finalize()["ok"])
	assert_eq(log.for_participant("run"), [
		"prepare_new_run_snapshot_input", "prepare_new_run_snapshot_input", "capture_restore_state",
		"apply_restore_silent", "rollback_restore_silent", "finalize_restore",
	])

func test_profile_participant_prepares_legacy_patch_and_derives_locale() -> void:
	if not _all_exist(): return
	var owner := FakeOwner.new("profile", _log())
	var participant: RefCounted = load(PROFILE_PATH).new(owner)
	var prepared: Dictionary = participant.prepare({"legacy_profile_patch_input":
		{"legacy_run_state": {}, "legacy_input_mappings": {}}})
	assert_true(prepared["ok"], JSON.stringify(prepared))
	assert_eq(prepared["value"]["locale_id"], "en", "locale derives from the prepared profile language")
	assert_false(participant.prepare({}).get("ok", true))

func test_localization_and_audio_participants() -> void:
	if not _all_exist(): return
	var loc: RefCounted = load(LOCALIZATION_PATH).new(FakeOwner.new("loc", _log()))
	assert_true(loc.prepare({"locale_id": "en"})["ok"])
	assert_false(loc.prepare({"locale_id": ""}).get("ok", true), "empty locale rejects")
	var audio: RefCounted = load(AUDIO_PATH).new(FakeOwner.new("audio", _log()))
	assert_true(audio.prepare({"preferences": {"audio": {}}, "audio_context": {"music_context_id": "menu"}})["ok"])
	assert_false(audio.prepare({"preferences": {}}).get("ok", true), "missing audio_context rejects")

func test_route_participant_returns_ready_token() -> void:
	if not _all_exist(): return
	var participant: RefCounted = load(ROUTE_PATH).new(FakeOwner.new("route", _log()))
	var prepared: Dictionary = participant.prepare({"route_id": "main", "route_context": {}})
	assert_true(prepared["ok"], JSON.stringify(prepared))
	var applied: Dictionary = participant.apply_silent({"route_ready_token": {"route_id": "main", "layout_id": "main_layout", "generation": 1}})
	assert_true(applied["ok"])
	assert_eq(applied["value"]["route_ready_token"]["layout_id"], "main_layout",
		"apply returns the route-ready token narrative validates")

func test_narrative_participant_unavailable_for_nonempty_playhead() -> void:
	if not _all_exist(): return
	var participant: RefCounted = load(NARRATIVE_PATH).new(FakeOwner.new("narrative", _log()))
	# Empty checkpoint is testable and succeeds at .5.
	var empty: Dictionary = participant.prepare({"narrative_checkpoint": {}, "content_version": 1})
	assert_true(empty["ok"], JSON.stringify(empty))
	# A nonempty playhead is recoverably unavailable until Plan 05 manifests exist.
	var nonempty: Dictionary = participant.prepare({
		"narrative_checkpoint": {"timeline_id": "priscilla_day1"}, "content_version": 1})
	assert_false(nonempty.get("ok", true))
	assert_eq(nonempty["code"], &"NARRATIVE_CONTENT_UNAVAILABLE")
	# apply requires the route-ready token and cannot run early.
	assert_false(participant.apply_silent({}).get("ok", true), "narrative apply needs the route token")
	assert_true(participant.apply_silent({"route_ready_token": {"route_id": "main", "layout_id": "m", "generation": 1}})["ok"])

func test_participant_owner_failures_propagate() -> void:
	if not _all_exist(): return
	var owner := FakeOwner.new("run", _log())
	owner.fail_at = &"apply_restore_silent"
	var participant: RefCounted = load(RUN_PATH).new(owner)
	assert_false(participant.apply_silent({}).get("ok", true), "owner apply failure propagates")
	assert_eq(participant.apply_silent({})["code"], &"forced_owner_failure")
