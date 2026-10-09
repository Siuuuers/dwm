extends SceneTree

const MANAGER := preload("res://autoload/SaveManager.gd")
const PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const GS := preload("res://autoload/GameState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ISSUER_ROOT := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")
const ALLOCATION := preload("res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd")
const RUN := preload("res://scripts/application/restore/RunRestoreParticipant.gd")
const CONSEQUENCE := preload("res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd")
const BOARD := preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd")
const CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const PROFILE := preload("res://scripts/application/restore/ProfileRestoreParticipant.gd")
const LOCALE := preload("res://scripts/application/restore/LocalizationRestoreParticipant.gd")
const AUDIO := preload("res://scripts/application/restore/AudioRestoreParticipant.gd")
const ROUTE := preload("res://scripts/application/restore/RouteRestoreParticipant.gd")
const NARRATIVE := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd")
const SNAPSHOT_FIXTURE := preload("res://tests/support/BackupSnapshotFixture.gd")
const VIEW_PARTICIPANT := preload("res://scripts/application/restore/ScheduleViewRestoreParticipant.gd")
const VIEW_CONTROLLER := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const REMAPPER := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")
const SCENE_ROUTER := preload("res://autoload/SceneRouter.gd")
const DESKTOP_HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")

class ExternalOwners extends RefCounted:
	var route_applies := 0
	func get_profile_snapshot() -> Dictionary:
		return preload("res://scripts/profile/ProfileSchema.gd").make_defaults()
	func prepare_profile_document(candidate: Dictionary) -> Dictionary:
		return preload("res://scripts/profile/ProfileSchema.gd").validate(candidate)
	func prepare_legacy_profile_patch(_input: Dictionary, _metadata: Dictionary = {}) -> Dictionary:
		return {"ok": true, "value": preload("res://scripts/profile/ProfileSchema.gd").make_defaults()}
	func prepare_locale(locale: String) -> Dictionary:
		return {"ok": true, "value": {"canonical_locale_id": locale}}
	func prepare_semantic_restore(context: Dictionary, _preferences: Dictionary) -> Dictionary:
		if context.get("fixture_missing_track", false):
			return {"ok": false, "code": &"AUDIO_CONTENT_UNAVAILABLE"}
		return {"ok": true, "value": {"snapshot": context.duplicate(true)}}
	func prepare_route_restore(route: String, _context: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"route_ready_token": {"route_id": route, "layout_id": "fixture", "generation": 1}}}
	func apply_route_restore_silent(plan: Dictionary) -> Dictionary:
		route_applies += 1
		return {"ok": true, "value": {"route_ready_token": plan["route_ready_token"]}}
	func capture_restore_state() -> Dictionary:
		return {"ok": true, "value": {}}
	func apply_restore_silent(_plan: Dictionary) -> Dictionary:
		return {"ok": true}
	func rollback_restore_silent(_backup: Dictionary) -> Dictionary:
		return {"ok": true}
	func finalize_restore() -> Dictionary:
		return {"ok": true}

class FinalizeParticipant extends RefCounted:
	var name: String
	var log: Array
	func _init(participant_name: String, shared_log: Array) -> void:
		name = participant_name
		log = shared_log
	func prepare(_input: Dictionary) -> Dictionary:
		return {"ok": true, "value": {}}
	func capture() -> Dictionary:
		return {"ok": true, "value": {}}
	func apply_silent(_plan: Dictionary) -> Dictionary:
		return {"ok": true, "value": {}}
	func rollback_silent(_backup: Dictionary) -> Dictionary:
		log.append("rollback:" + name)
		return {"ok": true}
	func finalize() -> Dictionary:
		log.append("finalize:" + name)
		return {"ok": false, "code": &"fixture_narrative_finalize_failed"} if name == "narrative" else {"ok": true}

var failures := 0
var projection_events := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_finalization_failure_never_routes()
	_test_real_route_prepare()
	_test_desktop_restore()
	_test_run_bookkeeping_restore()
	var files := FILES.new()
	var storage := STORAGE.new("memory/backup", files)
	var manager: Node = MANAGER.new()
	_check(manager.initialize(storage).get("ok", false), "real storage owner initialize")
	_check(manager.configure_mutation_gate(GATE.new()).get("ok", false), "real mutation gate")
	var port := PORT.new()
	_check(port.configure(manager).get("ok", false), "port configure")
	port.projection_changed.connect(func() -> void: projection_events += 1)
	var before := files.snapshot_persisted()
	var grid := port.get_projection()
	_check(grid.get("ok", false) and grid["value"]["records"].size() == 9, "nine drawers")
	_check(files.snapshot_persisted() == before, "projection is read only")
	for index: int in range(9):
		var record: Dictionary = grid["value"]["records"][index]
		_check(record["locator"] == PORT.LOCATORS[index] and record["state"] == "empty", "exact empty locator")
		_check(not record["actions"]["save"] and not record["actions"]["load"] and not record["actions"]["delete"], "no stable save or empty actions")
	_seed(manager)
	var initial := port.prepare_action("save", "slot:1")
	_check(initial.get("ok", false), "prepare first save: " + JSON.stringify(initial))
	if not initial.get("ok", false):
		_finish(manager)
		return
	_check(not initial["value"]["confirmation_required"], "empty numbered direct")
	_check(files.snapshot_persisted() == before, "preparation creates no save")
	_check(port.commit_action(initial["value"]["token"]).get("ok", false), "real atomic save")
	var record: Dictionary = port.get_projection()["value"]["records"][2]
	_check(record["state"] == "occupied" and record["day"] == 1 and str(record["saved_time"]).length() == 5, "validated Day and frozen time")
	_check(record["family"] == "legacy_day", "admitted legacy family is explicit")
	var document: Dictionary = JSON.parse_string(storage.read_text("slot_1.json")["value"])
	_check(SCHEMA.validate(document).get("ok", false), "saved time binds instant and original offset")
	var invalid_time: Dictionary = document["saved_time"].duplicate(true)
	invalid_time["hhmm"] = "99:99"
	_check(not SCHEMA.validate_saved_time(invalid_time), "false time rejected")
	_check(not port.prepare_action("save", "autosave").get("ok", false), "autosave cannot be manually saved")
	_check(not port.prepare_action("save", "slot:01").get("ok", false), "aliases rejected")
	var overwrite := port.prepare_action("save", "slot:1")
	_check(overwrite.get("ok", false) and overwrite["value"]["confirmation_kind"] == "overwrite", "occupied numbered confirms")
	port.cancel_action(overwrite["value"]["token"])
	_check(not port.commit_action(overwrite["value"]["token"]).get("ok", false), "cancel token cannot commit")
	var stale := port.prepare_action("delete", "slot:1")
	_check(manager.save_latest_to_slot(1).get("ok", false), "other writer save")
	# Change a durable safe time fact even if the two commands ran within one second.
	var newer: Dictionary = JSON.parse_string(storage.read_text("slot_1.json")["value"])
	newer.erase("saved_time")
	_check(storage.write_atomic("slot_1.json", JSON.stringify(newer), manager._document_text_validator).get("ok", false), "legacy fixture replacement")
	var stale_result := port.commit_action(stale["value"]["token"])
	_check(not stale_result.get("ok", false) and stale_result.get("code") == &"stale_backup_target", "changed document invalidates confirmation")
	record = port.get_projection()["value"]["records"][2]
	_check(record["state"] == "occupied" and record["saved_time"] == null, "legacy missing time stays readable")
	var quick := port.prepare_action("save", "quick")
	_check(port.commit_action(quick["value"]["token"]).get("ok", false), "quick save")
	quick = port.prepare_action("save", "quick")
	_check(not quick["value"]["confirmation_required"], "readable quick direct replacement")
	port.cancel_action(quick["value"]["token"])
	manager.acquire_save_lock(&"scene_transition")
	_check(not port.prepare_action("save", "slot:2").get("ok", false), "locked save refused")
	_check(not manager._pending_deferred_save, "UI refusal never queues autosave")
	manager.release_save_lock(&"scene_transition")
	var source_stale := port.prepare_action("save", "slot:7")
	var next_snapshot: Dictionary = manager.get_latest_stable_checkpoint()["value"]["bundle"]["snapshot"].duplicate(true)
	next_snapshot["checkpoint_sequence"] = 2
	next_snapshot["checkpoint_id"] = str(next_snapshot["run_id"]) + ":2"
	var next_candidate: Dictionary = manager._journal.prepare_record(next_snapshot, &"day_start")
	_check(next_candidate.get("ok", false), "new stable revision fixture")
	manager._journal.commit_prepared(next_candidate["value"]["candidate"])
	var source_stale_result := port.commit_action(source_stale["value"]["token"])
	_check(source_stale_result.get("code") == &"stale_backup_source" and not storage.exists("slot_7.json"), "live stable revision drift prevents save")
	_test_unavailable(manager, port, files)
	_test_restore(manager, port)
	_test_title_cold_load(storage)
	_check(projection_events == 0, "projection events never interrupt synchronous commits")
	await process_frame
	_check(projection_events == 1, "settled owner changes coalesce into one projection event")
	manager.acquire_save_lock(&"restore")
	var locked: Array = port.get_projection()["value"]["records"]
	_check(not locked[2]["actions"]["load"] and not locked[2]["actions"]["delete"] and not locked[2]["actions"]["save"], "all live actions reflect owner lock")
	await process_frame
	_check(projection_events == 2, "live lock publishes capability change")
	manager.release_save_lock(&"restore")
	await process_frame
	_finish(manager)

func _snapshot() -> Dictionary:
	var fixture: Dictionary = SNAPSHOT_FIXTURE.make_snapshot()
	_check(fixture.get("ok", false), "current canonical fixture validates: " + JSON.stringify(fixture))
	return fixture.get("value", {}).get("candidate", {})

func _schedule_view_participant(issuer: RefCounted) -> RefCounted:
	var loaded: Dictionary = REGISTRY.load_current()
	_check(loaded.get("ok", false), "current schedule registry: " + JSON.stringify(loaded))
	var registry: RefCounted = loaded["value"]["registry"]
	var controller := VIEW_CONTROLLER.new()
	var configured: Dictionary = controller.configure(registry, RULES, registry.fingerprint())
	_check(configured.get("ok", false), "real schedule controller: " + JSON.stringify(configured))
	return VIEW_PARTICIPANT.new(controller, registry, issuer, REMAPPER)

func _seed(manager: Node) -> void:
	var snapshot := _snapshot()
	if snapshot.is_empty(): return
	manager._journal.reset(snapshot["run_id"])
	var prepared: Dictionary = manager._journal.prepare_record(snapshot, &"day_start")
	_check(prepared.get("ok", false), "real canonical fixture accepted: " + JSON.stringify(prepared))
	if prepared.get("ok", false):
		_check(manager._journal.commit_prepared(prepared["value"]["candidate"]).get("ok", false), "stable journal fixture")

func _test_run_bookkeeping_restore() -> void:
	var state: Node = GS.new()
	state.reset_game()
	var empty := _snapshot()
	if empty.is_empty():
		state.free()
		return
	var saved := empty.duplicate(true)
	saved["gameplay"]["money"] = 12
	for pair: Array in [["z-effect", "effect_transaction"], ["z-variable", "variable_transaction"]]:
		saved["command_receipts"][pair[0]] = {"transaction_id": pair[0], "kind": pair[1],
			"source_id": "fixture", "request_fingerprint": "a".repeat(64)}
	saved["applied_effect_transaction_ids"] = ["z-effect"]
	saved["applied_variable_transaction_ids"] = ["z-variable"]
	_check(state.apply_restore_silent({"snapshot": saved}).get("ok", false), "canonical receipt fixture applies")
	_check(state.capture_run_snapshot_input()["command_receipts"] == saved["command_receipts"], "snapshot installs saved command receipts")
	# Use the owner's recorder to reproduce insertion order that differs from disk sorting.
	state._record_transaction_receipt("a-live", "b".repeat(64), &"effect_transaction", "fixture", state._applied_effect_transaction_ids)
	var before: Dictionary = state.capture_run_snapshot_input().duplicate(true)
	var backup: Dictionary = state.capture_restore_state()["value"]["backup"]
	_check(backup.get("command_receipts", {}) == before["command_receipts"], "rollback capture includes command receipts")
	_check(backup["gameplay"].has("narrative_variables"), "rollback capture includes narrative variables")
	# Existing stale variables must be removed by a saved empty narrative bag.
	state._narrative_variables = {"stale_legacy_fixture": "discard"}
	_check(state.apply_restore_silent({"snapshot": empty}).get("ok", false), "saved empty bookkeeping applies")
	var cleared: Dictionary = state.capture_run_snapshot_input()
	_check(cleared["command_receipts"].is_empty() and cleared["applied_effect_transaction_ids"].is_empty() and cleared["applied_variable_transaction_ids"].is_empty(), "snapshot clears all unsaved transaction bookkeeping")
	_check(cleared["gameplay"]["narrative_variables"].is_empty(), "snapshot clears stale narrative variables")
	_check(state.rollback_restore_silent(backup).get("ok", false), "real rollback accepts live insertion order")
	_check(state.capture_run_snapshot_input() == before, "rollback exactly restores receipts, ID ordering and narrative state")
	if backup.has("command_receipts"):
		backup["command_receipts"].clear()
	_check(state.capture_run_snapshot_input() == before, "rollback detaches caller-owned maps")
	var invalid_cases: Array = []
	var bad := saved.duplicate(true)
	bad["command_receipts"] = {}
	invalid_cases.append(bad)
	bad = saved.duplicate(true)
	bad["applied_effect_transaction_ids"] = "invalid"
	invalid_cases.append(bad)
	bad = saved.duplicate(true)
	bad["gameplay"]["narrative_variables"] = {"unregistered_fixture": 1}
	invalid_cases.append(bad)
	bad = saved.duplicate(true)
	bad["gameplay"]["narrative_variables"] = []
	invalid_cases.append(bad)
	bad = saved.duplicate(true)
	bad["command_receipts"]["z-effect"]["source_id"] = NAN
	invalid_cases.append(bad)
	for invalid: Dictionary in invalid_cases:
		_check(not state.apply_restore_silent({"snapshot": invalid}).get("ok", true), "invalid snapshot bookkeeping rejects")
		_check(state.capture_run_snapshot_input() == before, "invalid snapshot cannot partially mutate")
		# Rollback requires a captured session lifetime, then validates the same bad bookkeeping.
		var invalid_backup: Dictionary = state.capture_restore_state()["value"]["backup"]
		for key: String in ["gameplay", "command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
			invalid_backup[key] = invalid[key]
		var rejected: Dictionary = state.rollback_restore_silent(invalid_backup)
		_check(not rejected.get("ok", true) and rejected.get("code") != &"stale_run_backup", "invalid rollback bookkeeping rejects within the current session: " + JSON.stringify(rejected))
		_check(state.capture_run_snapshot_input() == before, "invalid rollback cannot partially mutate")
	var legacy := {"lifecycle": before["lifecycle"], "gameplay": {"money": state.money}}
	_check(state.apply_restore_silent({"snapshot": legacy}).get("ok", false), "legacy partial direct-owner plan stays accepted")
	_check(state.capture_run_snapshot_input() == before, "omitted legacy bookkeeping preserves current values")
	state.free()

func _test_finalization_failure_never_routes() -> void:
	var manager: Node = MANAGER.new()
	manager.configure_mutation_gate(GATE.new())
	var calls: Array = []
	var participants := {}
	var plans := {}
	for name: String in ["run", "desktop_consequence", "desktop_board", "schedule_view", "profile", "localization", "audio", "route", "narrative"]:
		participants[name] = FinalizeParticipant.new(name, calls)
		plans[name] = {}
	var configured: Dictionary = manager.configure_restore_participants(participants)
	_check(configured.get("ok", false), "finalization fixture uses actual owner transaction: " + JSON.stringify(configured))
	var result: Dictionary = manager.commit_prepared_restore({"participant_plans": plans, "route_id": "main", "checkpoint_id": "fixture:1"})
	_check(not result.get("ok", false) and result.get("code") == &"fixture_narrative_finalize_failed", "narrative finalization failure reaches caller: " + JSON.stringify(result))
	_check(calls.has("finalize:narrative") and not calls.has("finalize:route"), "failed narrative never dispatches physical route finalization")
	_check(calls.has("rollback:route") and not manager.is_save_locked(), "failed finalization rolls back and releases save custody")
	manager.free()

func _test_real_route_prepare() -> void:
	var router: Node = SCENE_ROUTER.new()
	root.add_child(router)
	var before: Dictionary = router.capture_restore_state()
	var prepared: Dictionary = router.prepare_route_restore("main", {})
	var again: Dictionary = router.prepare_route_restore("main", {})
	_check(before == router.capture_restore_state() and prepared == again, "actual route prepare is pure and stable")
	var applied: Dictionary = router.apply_route_restore_silent(prepared["value"])
	_check(applied.get("ok", false) and applied["value"]["route_ready_token"] == prepared["value"]["route_ready_token"], "actual apply preserves prepared narrative token")
	_check(not router.apply_route_restore_silent(again["value"]).get("ok", false), "actual route rejects stale generation")
	_check(router.rollback_restore_silent(before["value"]).get("ok", false) and router.capture_restore_state() == before, "route rollback restores generation")
	router.free()

func _test_desktop_restore() -> void:
	var host := DESKTOP_HOST.new()
	host.reset(3)
	host.open_app(&"contacts", 3)
	host.open_app(&"settings", 3)
	var before: Dictionary = host.get_state().duplicate(true)
	var prepared: Dictionary = host.prepare_restore("backup", 1)
	_check(prepared.get("ok", false) and host.get_state() == before, "desktop restore preparation preserves live day/selection/cache")
	if not host.has_method("commit_restore"):
		_check(false, "desktop owner exposes explicit restore commit")
		return
	var router: Node = SCENE_ROUTER.new()
	root.add_child(router)
	var participant := ROUTE.new(router)
	_check(participant.configure_desktop_host(host).get("ok", false), "route injects real desktop host")
	var route_before: Dictionary = participant.capture()["value"]
	var routed: Dictionary = participant.prepare({"route_id": "main", "route_context": {"active_app_id": "backup", "day": 1}})
	_check(routed.get("ok", false) and routed["value"]["route_plan"].has("desktop"), "saved desktop nested in retained route plan")
	_check(host.get_state() == before and participant.capture()["value"] == route_before, "participant preparation stays pure")
	var applied: Dictionary = participant.apply_silent(routed["value"]["route_plan"])
	_check(applied.get("ok", false), "route transaction applies desktop candidate")
	_check(host.get_state()["active_app_id"] == &"backup" and host.get_state()["current_day"] == 1 and host.get_state()["cached_app_ids"].is_empty(), "restore installs saved day/app with empty view cache")
	_check(participant.rollback_silent(route_before).get("ok", false) and host.get_state() == before, "rollback exactly restores prior desktop cache/selection/day")
	var cancelled: Dictionary = participant.prepare({"route_id": "main", "route_context": {"active_app_id": null, "day": 2}})
	cancelled.clear()
	_check(host.get_state() == before, "discarding prepared restore leaves live desktop exact")
	_check(router.apply_route_restore_silent(routed["value"]["route_plan"]).get("ok", false), "intervening route consumes generation")
	var route_after: Dictionary = router.capture_restore_state()
	_check(not participant.apply_silent(routed["value"]["route_plan"]).get("ok", false), "stale route apply fails")
	_check(host.get_state() == before and router.capture_restore_state() == route_after, "failed route leaves host and route exact")
	router.rollback_restore_silent(route_before)
	var invalid := before.duplicate(true)
	invalid["current_day"] = 0
	_check(not host.commit_restore(invalid).get("ok", false) and host.get_state() == before, "invalid host candidate cannot partially mutate")
	router.free()

func _test_unavailable(manager: Node, port: RefCounted, files: RefCounted) -> void:
	files._persisted["memory/backup/slot_2.json"] = "broken json".to_utf8_buffer()
	files._persisted["memory/backup/slot_3.json"] = '{"schema_version":999}'.to_utf8_buffer()
	var records: Array = port.get_projection()["value"]["records"]
	_check(records[3]["state"] == "unavailable" and records[3]["actions"]["delete"] and records[3]["actions"]["save"], "corrupt remains replaceable/deletable")
	_check(records[4]["reason"] == "newer_version" and not records[4]["actions"]["load"], "future is not playable")
	var deletion: Dictionary = port.prepare_action("delete", "slot:2")
	_check(deletion.get("ok", false) and deletion["value"]["confirmation_required"], "corrupt delete confirms")
	_check(port.commit_action(deletion["value"]["token"]).get("ok", false), "corrupt owner delete")
	var overwrite: Dictionary = port.prepare_action("save", "slot:3")
	_check(overwrite.get("ok", false) and overwrite["value"]["confirmation_kind"] == "overwrite", "future overwrite confirms")
	_check(port.commit_action(overwrite["value"]["token"]).get("ok", false), "future overwrite becomes validated save")
	_check(manager.inspect_backup("slot:3")["value"]["state"] == "occupied", "replacement metadata real")

func _test_restore(manager: Node, port: RefCounted) -> void:
	var state: Node = GS.new()
	state.reset_game()
	_check(state.configure_mutation_gate(manager._mutation_gate).get("ok", false), "restore GameState shares transaction custody")
	var external := ExternalOwners.new()
	var issuer := ISSUER.new()
	var issuer_root := ISSUER_ROOT.new()
	_check(issuer_root.configure(STORAGE.new("memory/issuer", FILES.new()), NAMESPACE.new("66".repeat(32))).get("ok", false), "real external issuer root")
	_check(issuer_root.load_or_create().get("ok", false), "real root initialize")
	_check(issuer.configure(issuer_root).get("ok", false), "real restore issuer")
	_check(manager.configure_identity_issuer(issuer).get("ok", false), "owner issuer")
	_check(manager.configure_identity_allocation_participant(ALLOCATION.new(issuer, manager)).get("ok", false), "real allocation participant")
	var desktop_host := DESKTOP_HOST.new()
	desktop_host.reset(3)
	desktop_host.open_app(&"settings", 3)
	var route_participant := ROUTE.new(external)
	_check(route_participant.configure_desktop_host(desktop_host).get("ok", false), "real SaveManager route participant host configured")
	_check(manager.configure_restore_participants({"run": RUN.new(state), "desktop_consequence": CONSEQUENCE.new(CONSEQUENCE_STATE.new()),
		"desktop_board": BOARD.new(BOARD_STATE.new()), "schedule_view": _schedule_view_participant(issuer),
		"profile": PROFILE.new(external), "localization": LOCALE.new(external),
		"audio": AUDIO.new(external), "route": route_participant, "narrative": NARRATIVE.new(external)}).get("ok", false), "actual restore participant stack")
	manager._journal.reset("different-live-run")
	var earlier := _snapshot()
	if earlier.is_empty():
		state.free()
		return
	earlier["active_app_id"] = "contacts"
	var newer := earlier.duplicate(true)
	newer["checkpoint_sequence"] = 2
	newer["checkpoint_id"] = str(newer["run_id"]) + ":2"
	newer["audio_context"] = {"fixture_missing_track": true}
	var fallback_document := SCHEMA.build(&"slot", 4, &"manual", {"checkpoint_kind": "day_start", "snapshot": newer},
		[{"checkpoint_kind": "day_start", "snapshot": earlier}])
	_check(fallback_document.get("ok", false), "whole fallback fixture")
	_check(manager._storage.write_atomic("slot_4.json", JSON.stringify(fallback_document["value"]), manager._document_text_validator).get("ok", false), "fallback file fixture")
	var fallback_record: Dictionary = port.get_projection()["value"]["records"][5]
	_check(fallback_record["fallback"] and fallback_record["actions"]["load"] and fallback_record["load_day"] == 1 and fallback_record["load_saved_time"] == null, "typed current incompatibility selects whole earlier bundle with unknown time")
	_check(fallback_record["family"] == "legacy_day" and fallback_record["load_family"] == "legacy_day", "fallback preserves explicit admitted and selected families")
	var fallback_action: Dictionary = port.prepare_action("load", "slot:4")
	_check(fallback_action.get("ok", false) and fallback_action["value"]["confirmation_kind"] == "replace_progress_fallback", "one combined fallback confirmation")
	var fallback_committed: Dictionary = port.commit_action(fallback_action["value"]["token"])
	_check(fallback_committed.get("ok", false), "whole earlier checkpoint actually restores: " + JSON.stringify(fallback_committed))
	_check(external.route_applies == 1, "fallback routes once")
	_check(desktop_host.get_state()["active_app_id"] == &"contacts" and desktop_host.get_state()["current_day"] == 1 and desktop_host.get_state()["cached_app_ids"].is_empty(), "actual SaveManager carries saved active app and day through route context")
	manager._journal.reset("second-live-run")
	var restore: Dictionary = port.prepare_action("load", "slot:1")
	_check(restore.get("ok", false), "whole owner restore preparation: " + JSON.stringify(restore))
	if restore.get("ok", false):
		_check(restore["value"]["confirmation_kind"] == "replace_progress", "in-run load confirms")
		_check(external.route_applies == 1, "prepare never routes")
		var committed: Dictionary = port.commit_action(restore["value"]["token"])
		_check(committed.get("ok", false), "actual owner restore: " + JSON.stringify(committed))
		_check(external.route_applies == 2, "restore owner routes once")
		_check(desktop_host.get_state()["active_app_id"] == null, "restoring launcher clears prior active app")
	var current_save: Dictionary = port.prepare_action("save", "slot:5")
	_check(current_save.get("ok", false), "save the current restored journal through the real Backup port")
	if current_save.get("ok", false):
		_check(port.commit_action(current_save["value"]["token"]).get("ok", false), "current checkpoint actually saved")
		var saved_money: int = state.money
		var saved_journal: Dictionary = manager._journal.capture_state()["value"]["backup"]
		for attempt: int in range(2):
			_check(state.change_money(5) and state.money == saved_money + 5, "owner changes unsaved live progress")
			_check(manager._journal.capture_state()["value"]["backup"] == saved_journal, "live mutation does not advance saved journal")
			var same_checkpoint: Dictionary = port.prepare_action("load", "slot:5")
			_check(same_checkpoint.get("ok", false), "current checkpoint load prepares again")
			if same_checkpoint.get("ok", false):
				var loaded: Dictionary = port.commit_action(same_checkpoint["value"]["token"])
				_check(loaded.get("ok", false), "restore current checkpoint attempt %d: %s" % [attempt, JSON.stringify(loaded)])
				_check(state.money == saved_money, "current checkpoint restores live money")
				_check(manager._journal.capture_state()["value"]["backup"] == saved_journal, "restore installs the exact saved journal")
				_check(not port.commit_action(same_checkpoint["value"]["token"]).get("ok", false), "consumed UI restore token still rejects replay")
	state.free()

func _test_title_cold_load(storage: RefCounted) -> void:
	# A fresh owner with no seeded journal reopens the persisted in-memory files.
	# The two-process harness separately proves actual process/disk reconstruction.
	var manager: Node = MANAGER.new()
	manager.initialize(storage)
	manager.configure_mutation_gate(GATE.new())
	var state: Node = GS.new()
	state.reset_game()
	_check(state.configure_mutation_gate(manager._mutation_gate).get("ok", false), "cold GameState shares transaction custody")
	var external := ExternalOwners.new()
	var issuer := ISSUER.new()
	var issuer_root := ISSUER_ROOT.new()
	issuer_root.configure(STORAGE.new("memory/title-issuer", FILES.new()), NAMESPACE.new("77".repeat(32)))
	issuer_root.load_or_create()
	issuer.configure(issuer_root)
	manager.configure_identity_issuer(issuer)
	manager.configure_identity_allocation_participant(ALLOCATION.new(issuer, manager))
	var route := ROUTE.new(external)
	route.configure_desktop_host(DESKTOP_HOST.new())
	_check(manager.configure_restore_participants({"run": RUN.new(state), "desktop_consequence": CONSEQUENCE.new(CONSEQUENCE_STATE.new()),
		"desktop_board": BOARD.new(BOARD_STATE.new()), "schedule_view": _schedule_view_participant(issuer),
		"profile": PROFILE.new(external), "localization": LOCALE.new(external),
		"audio": AUDIO.new(external), "route": route, "narrative": NARRATIVE.new(external)}).get("ok", false), "cold owner restore stack configured")
	var port := PORT.new()
	_check(not port.configure(manager, "unknown").get("ok", true), "unrecognized Backup context rejects")
	_check(port.configure(manager, "title").get("ok", false), "title port configures")
	_check(not port.configure(manager).get("ok", true), "title context cannot switch under pending actions")
	_check(not manager.get_latest_stable_checkpoint().get("ok", true), "cold owner has no live stable checkpoint")
	var projection: Dictionary = port.get_projection()["value"]
	_check(not projection["save_capability"]["enabled"], "title has no save capability")
	for record: Dictionary in projection["records"]:
		_check(not record["actions"]["save"], "title never advertises Save")
	_check(projection["records"][2]["actions"]["load"], "cold title can load persisted slot without a live checkpoint")
	var before: Dictionary = state.capture_run_snapshot_input()
	var load_current := port.prepare_action("load", "slot:1")
	_check(load_current.get("ok", false) and not load_current["value"]["confirmation_required"], "title normal Load is direct after preparation")
	_check(state.capture_run_snapshot_input() == before and external.route_applies == 0, "title preparation never mutates or routes")
	_check(port.commit_action(load_current["value"]["token"]).get("ok", false), "cold title Load commits through actual owner")
	_check(manager.get_latest_stable_checkpoint().get("ok", false) and external.route_applies == 1, "cold Load seeds journal and applies route once")
	_check(not port.prepare_action("save", "slot:6").get("ok", true), "title refuses Save even once a stable checkpoint exists")
	var fallback := port.prepare_action("load", "slot:4")
	_check(fallback.get("ok", false) and fallback["value"]["confirmation_required"] and fallback["value"]["confirmation_kind"] == "fallback", "title fallback has disclosure-only confirmation")
	port.cancel_action(fallback["value"]["token"])
	_check(not port.commit_action(fallback["value"]["token"]).get("ok", true), "title fallback cancellation consumes admission")
	var deletion := port.prepare_action("delete", "slot:4")
	_check(deletion.get("ok", false) and deletion["value"]["confirmation_kind"] == "delete", "title Delete retains confirmation")
	port.cancel_action(deletion["value"]["token"])
	_check(external.route_applies == 1, "cancelled title operations never route")
	state.free()
	manager.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", message)

func _finish(manager: Node) -> void:
	manager.free()
	print("BACKUP_OPERATIONS_PASS" if failures == 0 else "BACKUP_OPERATIONS_FAIL %d" % failures)
	quit(0 if failures == 0 else 1)
