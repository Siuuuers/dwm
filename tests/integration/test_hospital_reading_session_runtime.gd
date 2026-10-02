extends "res://addons/gut/test.gd"
## Real mounted Dialogic -> Bridge -> retained Hospital physical adapter.
## Catalogue prose and command provenance are explicit fixtures. This suite proves
## the native family/owner seam, not receipt-proven Contacts/Schedule ingress or
## independent saved-Run authority; the separate connected/persistence proofs own those.

const RUNTIME_ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const PHYSICAL_OWNER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const HOSPITAL_PORT := preload("res://scripts/application/run/HospitalPresentationPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const CATALOG := preload("res://tests/support/HospitalReadingTimelineCatalog.gd")
const HOSPITAL_FIXTURE := preload("res://tests/support/HospitalReadingFixture.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const HOSPITAL_FROZEN := preload("res://scripts/narrative/HospitalFrozenContext.gd")
const SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const IDS := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const LAYER := preload("res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const SOLO_DOCUMENT := "res://tests/fixtures/dialogic/solo_reading_rail_catalogue.json"
const SOLO_ENTRY := "dating.solo.priscilla.day1.pre_challenge"
const HOSPITAL_ENTRY := "hospital.faint.day3"
const HANDLE := {"generation": 1, "handle_id": "hospital-native-pause", "holder": &"hospital_fixture", "reason": &"universal_pause"}

class Checkpoints extends RefCounted:
	var completions: Array[Dictionary] = []
	func commit_current_boundary(_checkpoint: Dictionary) -> Dictionary: return {"ok": true}
	func preview_checkpoint_id(_checkpoint: Dictionary) -> Dictionary: return {"ok": true}
	func capture() -> Dictionary: return {"ok": true}
	func prepare_candidate(_checkpoint: Dictionary) -> Dictionary: return {"ok": true}
	func commit(_candidate: Dictionary) -> Dictionary: return {"ok": true}
	func rollback(_backup: Dictionary) -> Dictionary: return {"ok": true}
	func complete_entry(intent: Dictionary) -> Dictionary:
		completions.append(intent.duplicate(true))
		return {"ok": true}

class SpeechRecorder extends Node:
	signal speech_completed(token: int, outcome: StringName)
	var requests: Array[Dictionary] = []
	var active_source := ""
	func request_speech(copy: String, locale: String, rate: StringName, source: String) -> Dictionary:
		requests.append({"text": copy, "locale": locale, "rate": rate, "source": source})
		active_source = source
		return {"ok": true, "value": {"token": requests.size()}}
	func stop_source(source: String, _reason: StringName) -> Dictionary:
		if source == active_source: active_source = ""
		return {"ok": true}
	func is_speaking(source: String = "") -> bool:
		return not active_source.is_empty() and (source.is_empty() or source == active_source)

var _runtime: DialogicGameHandler
var _adapter: DialogicRuntimeAdapter
var _bridge: Node
var _owner: RefCounted
var _profile: Node
var _gate: ApplicationMutationGate
var _port: Checkpoints
var _speech: SpeechRecorder
var _viewport: SubViewport
var _solo_document: Dictionary
var _original_runtime: Node
var _original_runtime_index := 0
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _style_directory: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _profile_before: Dictionary = {}
var _publications: Array[Dictionary] = []
var _restored: Array[Dictionary] = []
var _native_text: Array[String] = []
var _physical_receipts: Array[Dictionary] = []
var _physical_failures: Array[Dictionary] = []
var _native_starts := 0
var _native_ends := 0

func before_each() -> void:
	_publications.clear()
	_restored.clear()
	_native_text.clear()
	_physical_receipts.clear()
	_physical_failures.clear()
	_native_starts = 0
	_native_ends = 0
	_settings.clear()
	_profile_before = get_node("/root/ProfileManager").get_profile_snapshot().duplicate(true)
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(SOLO_DOCUMENT))
	assert_true(parsed.ok, str(parsed))
	_solo_document = parsed.value
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info", {})
	_style_directory = DialogicStylesUtil.style_directory.duplicate(true)
	_original_runtime = get_node("/root/Dialogic")
	_original_runtime_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_original_layout_parent = _original_layout.get_parent()
		_original_layout_index = _original_layout.get_index()
		_original_layout_parent.remove_child(_original_layout)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.remove_child(_original_runtime)
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		_settings[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	_runtime = DialogicGameHandler.new()
	_runtime.name = "Dialogic"
	get_tree().root.add_child(_runtime)
	_runtime.History.save_visited_history_on_save = false
	_runtime.History.save_visited_history_on_autosave = false
	_runtime.Text.text_started.connect(func(info: Dictionary) -> void: _native_text.append(str(info.text)))
	_runtime.timeline_started.connect(func() -> void: _native_starts += 1)
	_runtime.timeline_ended.connect(func() -> void: _native_ends += 1)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	add_child(_viewport)
	_gate = GATE.new()
	_profile = PROFILE.new()
	add_child(_profile)
	assert_true(_profile.configure_mutation_gate(_gate).ok)
	var ids := IDS.load_ids_default()
	assert_true(ids.ok, str(ids))
	assert_true(_profile.configure_line_registry(ids.value).ok)
	var wrapper := OS.get_environment("DWM_TEST_ROOT").strip_edges()
	assert_false(wrapper.is_empty(), "cloud wrapper supplies the isolated test root")
	assert_true(_profile.initialize(STORAGE.new(wrapper.path_join("hospital-native"), FILES.new())).ok)
	assert_true(_profile.set_preference(&"preferences.reading.read_aloud_enabled", true).ok)
	_speech = SpeechRecorder.new()
	add_child(_speech)
	_port = Checkpoints.new()
	_new_bridge()

func _new_bridge() -> void:
	_adapter = RUNTIME_ADAPTER.new()
	assert_true(_adapter.bind_runtime(_runtime).ok)
	_adapter.caption_publication_recorded.connect(func(result: Dictionary) -> void:
		_publications.append(result.duplicate(true)))
	_adapter.reading_frontier_restored.connect(func(result: Dictionary) -> void:
		_restored.append(result.duplicate(true)))
	_bridge = BRIDGE.new()
	add_child(_bridge)
	assert_true(_bridge.initialize(CATALOG, _adapter).ok)
	assert_true(_bridge.configure_mutation_gate(_gate).ok)
	assert_true(_bridge.configure_skip_context(_profile, &"read_only").ok)
	assert_true(_bridge.configure_narrative_checkpoint_port(_port).ok)
	assert_true(_bridge.configure_playback_completion_port(_port).ok)
	assert_true(_bridge.configure_reading_catalogue(_solo_document).ok)
	assert_true(_bridge.configure_reading_catalogue(HOSPITAL_FIXTURE.catalogue()).ok)
	_owner = PHYSICAL_OWNER.new()
	assert_true(_owner.configure_frozen_hospital_contexts().ok)
	assert_true(_owner.configure(_bridge).ok)
	_owner.physical_completion_ready.connect(func(receipt: Dictionary) -> void:
		_physical_receipts.append(receipt.duplicate(true)))
	_owner.physical_completion_failed.connect(func(failure: Dictionary) -> void:
		_physical_failures.append(failure.duplicate(true)))

func after_each() -> void:
	# Exercise real cancellation on unfinished tests too; do not synthesize a
	# text-finished signal to hide an abandoned event-owned reveal wait.
	if is_instance_valid(_bridge) and not _bridge._active_entry.is_empty():
		_bridge.abort_current_entry(&"fixture_teardown")
	assert_eq(get_node("/root/ProfileManager").get_profile_snapshot(), _profile_before,
		"native family tests never mutate the real Profile")
	if is_instance_valid(_bridge): _bridge.free()
	_owner = null
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	if is_instance_valid(_runtime):
		_runtime.paused = false
		await _runtime.clear()
		var remaining: Node = _runtime.Styles.get_layout_node()
		if is_instance_valid(remaining) and not _viewport.is_ancestor_of(remaining): remaining.queue_free()
	_viewport.queue_free()
	await get_tree().process_frame
	if is_instance_valid(_runtime): _runtime.free()
	_adapter = null
	_profile.free()
	_speech.free()
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_runtime_index)
	if is_instance_valid(_original_layout) and is_instance_valid(_original_layout_parent):
		_original_layout_parent.add_child(_original_layout)
		_original_layout_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	for key: String in _settings:
		ProjectSettings.set_setting(key, _settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null

func _settle() -> void:
	for frame: int in 6: await get_tree().process_frame

func _caption() -> Node:
	var layout: Node = _runtime.Styles.get_layout_node()
	if layout != null:
		for layer: Node in layout.get_layers():
			if layer.get_script() == LAYER: return layer
	return null

func _mount() -> bool:
	var layout: Node = _runtime.Styles.get_layout_node()
	if layout == null: layout = _runtime.Styles.load_style(STYLE, _viewport)
	assert_not_null(layout)
	if layout == null: return false
	await _settle()
	assert_same(layout.get_parent(), _viewport)
	var caption := _caption()
	assert_not_null(caption)
	if caption == null: return false
	assert_true(caption.configure_reading_transport(_profile, _bridge))
	assert_true(caption.configure_speech(_profile, _bridge, _speech))
	return true

func _command(suffix: String = "one") -> Dictionary:
	# Structurally valid canonical command for the native boundary only. The
	# connected Schedule-Done proof supplies independent receipt ancestry.
	var frozen := FROZEN.build(HOSPITAL_ENTRY, {"entry_id": HOSPITAL_ENTRY, "entry_role": "hospital",
		"day": 3, "qualifying_cause": "schedule_done", "accepted_record_ids": ["fixture:sylvia-source"],
		"unfulfilled_record_ids": ["fixture:sylvia-source"], "sylvia_eligible": true,
		"sylvia_witness_receipt_id": null})
	assert_true(frozen.ok, str(frozen))
	var request := {"resolution_id": "fixture:hospital-resolution:" + suffix,
		"resolution_issuer_receipt": {"receipt_id": "fixture:hospital-root:" + suffix},
		"stage_id": "stage.hospital", "substage_id": "intent.hospital",
		"route_id": "hospital", "timeline_id": "hospital.faint",
		"context": {"kind": "hospital", "day": 3, "source_entry_ids": ["fixture:schedule-sylvia"],
			"miss_receipt_ids": [], "presentation": frozen.value},
		"completion_transaction_id": "fixture:hospital-native:" + suffix,
		"completion_transaction_provenance": {"child_id": "fixture:hospital-native:" + suffix}}
	assert_true(HOSPITAL_FROZEN.validate_request(request).ok)
	var hashed := SCHEMA.canonical_sha256(request)
	assert_true(hashed.ok, str(hashed))
	request["command_sha256"] = hashed.value.sha256
	return request

func _canonical(command: Dictionary) -> Dictionary:
	var value := command.duplicate(true)
	value["physical_token"] = PHYSICAL_OWNER.derive_token(command.completion_transaction_id, command.command_sha256)
	return value

func _issued_request(issuer: RefCounted) -> Dictionary:
	# The cached-port regression uses the real root/child issuer. Catalogue prose,
	# Schedule source ids and the stage string remain explicit noncanon fixtures.
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(issued.ok, str(issued))
	if not issued.ok: return {}
	var request := _command("cached-port")
	request.erase("command_sha256")
	request.resolution_issuer_receipt = issued.value.issuer_receipt.duplicate(true)
	var fields := {"role": "presentation.completion", "resolution_id": request.resolution_id,
		"stage_id": request.stage_id, "substage_id": request.substage_id, "route_id": request.route_id,
		"timeline_id": request.timeline_id, "context_sha256": SCHEMA.canonical_sha256(request.context).value.sha256}
	var tokens: Array = []
	for key: String in fields:
		tokens.append(key + "=" + str(SCHEMA.canonical_json(fields[key]).value.text))
	tokens.sort()
	var derived: Dictionary = issuer.derive_child({"parent_receipt_id": request.resolution_issuer_receipt.receipt_id,
		"child_kind": HOSPITAL_PORT.COMPLETION_CHILD_KIND, "ordinal": 0, "source_ids": tokens})
	assert_true(derived.ok, str(derived))
	if not derived.ok: return {}
	request.completion_transaction_id = derived.value.child_id
	request.completion_transaction_provenance = derived.value.provenance.duplicate(true)
	return request

func _start_hospital(command: Dictionary) -> bool:
	if not await _mount(): return false
	var begun: Dictionary = _owner.begin_physical(command)
	assert_true(begun.ok, str(begun))
	if not begun.ok: return false
	assert_eq(begun.value.physical_token, _canonical(command).physical_token)
	await _settle()
	return true

func _start_solo(suffix: String) -> bool:
	if not await _mount(): return false
	var completion := "fixture:solo-native:" + suffix
	var begun: Dictionary = _bridge.begin_reading_session({"timeline_id": SOLO_ENTRY,
		"completion_transaction_id": completion, "context": {"kind": "solo"}})
	assert_true(begun.ok, str(begun))
	if not begun.ok: return false
	var fields := {"entry_id": SOLO_ENTRY, "entry_role": "solo_pre_challenge", "day": 1,
		"friend_id": "priscilla", "tier": "friend", "tone": "sweet", "attitude": "",
		"run_id": "fixture:solo-run", "branch_id": "fixture:solo-branch",
		"challenge_slot": "dating.solo.priscilla.day1", "phase": "pre_challenge",
		"due_echoes": [], "attempt_residue_id": null}
	var frozen := FROZEN.build(SOLO_ENTRY, fields)
	assert_true(frozen.ok, str(frozen))
	var context := {"expected_stage": "pre_challenge", "role": "dating_phase",
		"transaction_id": completion + ":pre_challenge", "playback_id": "fixture:solo-physical:" + suffix,
		"presentation": frozen.value}
	var started: Dictionary = _bridge.start_entry(SOLO_ENTRY, context)
	assert_true(started.ok, str(started))
	await _settle()
	return started.ok

func _advance() -> bool:
	var completed := _adapter.complete_reading_frontier()
	assert_true(completed.ok, str(completed))
	if not completed.ok: return false
	var advanced := _adapter.advance_one_event()
	assert_true(advanced.ok, str(advanced))
	await _settle()
	return advanced.ok

func _line_ids() -> Array[String]:
	var result: Array[String] = []
	if not _bridge.has_reading_session(): return result
	for row: Dictionary in _bridge._reading_session.ledger.snapshot().captions:
		result.append(str(row.beat.line_id))
	return result

func _assert_hospital_caption(ordinal: int) -> void:
	var lines: Array = HOSPITAL_FIXTURE.catalogue().entries[0].lines
	var caption := _caption()
	assert_not_null(caption)
	if caption == null: return
	assert_eq(caption.caption_text.get_parsed_text(), lines[ordinal].text)
	var captured := _adapter.capture_reading_frontier()
	assert_true(captured.ok, str(captured))
	if captured.ok: assert_eq(captured.value.line_id, lines[ordinal].line_id)
	assert_eq(_bridge.get_current_scene_art(), {"entry_id": HOSPITAL_ENTRY, "show_portraits": true})
	assert_true(_bridge.can_capture_hospital_reading_checkpoint(_bridge._hospital_reading_command))

func test_native_hospital_replaces_retained_prior_ledger_and_completes_exact_owner_once() -> void:
	if not await _start_solo("before"): return
	var active_solo: Dictionary = _bridge._active_entry.duplicate(true)
	var solo_history: Dictionary = _bridge._reading_session.ledger.snapshot()
	var foreign_begin: Dictionary = _bridge.begin_hospital_reading(_canonical(_command("foreign-active")))
	assert_false(foreign_begin.ok)
	assert_eq(foreign_begin.code, &"narrative_playback_active")
	assert_eq(_bridge._active_entry, active_solo, "refused Hospital admission preserves the active Solo owner")
	assert_eq(_bridge._reading_session.ledger.snapshot(), solo_history)
	if not await _advance(): return
	if not await _advance(): return
	var prior: Dictionary = _bridge._reading_session.ledger.snapshot()
	assert_eq(_line_ids(), ["fixture.solo.pre.a", "fixture.solo.pre.b"])
	assert_eq(_port.completions.size(), 1)
	# Deliberately retain a completed prior ledger at this shared-owner seam.
	# The connected route separately observes lawful prior Solo retirement.
	var command := _command()
	if not await _start_hospital(command): return
	_assert_hospital_caption(0)
	assert_ne(_bridge._reading_session.ledger.snapshot().session_token, prior.session_token)
	assert_eq(_line_ids(), ["fixture.hospital.a"], "Hospital History starts from its actual first publication only")
	if not await _advance(): return
	_assert_hospital_caption(1)
	assert_eq(_line_ids(), ["fixture.hospital.a", "fixture.hospital.b"])
	assert_eq(_physical_receipts, [])
	assert_eq(_port.completions.size(), 1, "Hospital never uses the Dating completion port")
	if not await _advance(): return
	assert_eq(_native_starts, 2)
	assert_eq(_native_ends, 2, "both completion boundaries came from actual native return events")
	assert_eq(_physical_receipts.size(), 1)
	if _physical_receipts.size() != 1: return
	assert_true(_owner.validate_physical_completion({"presentation_command": _canonical(command),
		"physical_completion_receipt": _physical_receipts[0]}).ok)
	assert_eq(_physical_receipts[0].completion_transaction_id, command.completion_transaction_id)
	assert_eq(_physical_failures, [])
	_runtime.timeline_ended.emit() # Negative duplicate after the real native end; not a finisher.
	assert_eq(_physical_receipts.size(), 1)
	assert_eq(_port.completions.size(), 1)
	assert_eq(_bridge._reading_session.boundary, "between_entries")
	assert_true(_bridge.retire_completed_hospital_reading(_canonical(command)).ok)
	assert_false(_bridge.has_reading_session())
	# A new ordinary Solo family is healthy; calendar progression is the driver's scope.
	if not await _start_solo("after"): return
	assert_eq(_line_ids(), ["fixture.solo.pre.a"])
	if not await _advance(): return
	if not await _advance(): return
	assert_eq(_port.completions.size(), 2)
	assert_eq(_physical_receipts.size(), 1)

func test_ordinary_and_foreign_semantic_signals_cannot_complete_live_hospital() -> void:
	var command := _command()
	if not await _start_hospital(command): return
	var before: Dictionary = _bridge._reading_session.ledger.snapshot()
	_bridge.timeline_finished.emit("hospital.faint", {"fixture": "unowned ordinary signal"})
	_bridge.hospital_reading_finished.emit(_canonical(_command("foreign")), {"fixture": "foreign command"})
	assert_eq(_physical_receipts, [])
	assert_eq(_bridge._reading_session.ledger.snapshot(), before)
	assert_true(_owner.capture_pause_source().ok)
	if not await _advance(): return
	if not await _advance(): return
	assert_eq(_native_ends, 1)
	assert_eq(_physical_receipts.size(), 1, "the matching real native end remains admissible")

func test_abandoned_partial_hospital_retires_owner_and_old_command_cannot_complete_fresh_entry() -> void:
	var abandoned := _command("abandoned")
	if not await _start_hospital(abandoned): return
	assert_false(_adapter.is_current_line_complete(), "the retired source is a real partial reveal")
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	var lease := _gate.acquire(&"session_abandonment")
	assert_true(lease.ok, str(lease))
	if not lease.ok: return
	var retired: Dictionary = _bridge.retire_suspended_source(HANDLE)
	assert_true(retired.ok, str(retired))
	assert_true(_gate.release(&"session_abandonment", lease.value.token).ok)
	await _settle()
	assert_false(_bridge.has_reading_session())
	assert_false(_owner.capture_pause_source().ok)
	assert_eq(_physical_receipts, [])
	assert_eq(_physical_failures, [], "abandonment neither completes nor fails the old coordinator")
	_runtime.timeline_ended.emit() # Late native callback with no remaining owned entry.
	assert_eq(_physical_receipts, [])
	var fresh := _command("fresh")
	if not await _start_hospital(fresh): return
	_bridge.hospital_reading_finished.emit(_canonical(abandoned), {"fixture": "late old command"})
	assert_eq(_physical_receipts, [])
	assert_eq(_line_ids(), ["fixture.hospital.a"])
	if not await _advance(): return
	if not await _advance(): return
	assert_eq(_physical_receipts.size(), 1)
	if _physical_receipts.size() == 1:
		assert_eq(_physical_receipts[0].completion_transaction_id, fresh.completion_transaction_id)

func test_staged_restore_adopts_retained_command_and_publishes_only_saved_b_without_speech() -> void:
	var command := _command()
	if not await _start_hospital(command): return
	if not await _advance(): return
	_assert_hospital_caption(1)
	var saved: Dictionary = _bridge.capture_reading_checkpoint(true)
	assert_true(saved.ok, str(saved))
	if not saved.ok: return
	assert_eq(saved.value.reading_session.schema_version, 3)
	assert_eq(saved.value.reading_session.family, "hospital")
	assert_eq(saved.value.reading_session.frontier.line_id, "fixture.hospital.b")
	var history: Dictionary = _bridge.get_reading_history()
	var profile_before: Dictionary = _profile.get_profile_snapshot()
	assert_eq(_native_ends, 0, "explicit Save completion finishes B without advancing Hospital")
	assert_eq(_physical_receipts, [])
	assert_true(_bridge.abort_current_entry(&"fixture_process_retired").ok)
	await _settle()
	_bridge.free()
	_owner = null
	_adapter = null
	_new_bridge()
	_native_text.clear()
	_publications.clear()
	_restored.clear()
	_speech.requests.clear()
	var starts_before := _native_starts
	var staged: Dictionary = _bridge.stage_reading_restore(saved.value)
	assert_true(staged.ok, str(staged))
	if not staged.ok: return
	var adopted: Dictionary = _owner.begin_physical(command)
	assert_true(adopted.ok, str(adopted))
	if not adopted.ok: return
	assert_eq(_native_starts, starts_before, "route reconstruction retains custody without starting A")
	assert_eq(_native_text, [])
	assert_eq(_physical_receipts, [])
	assert_true(_bridge.is_reading_restore_staged())
	if not await _mount(): return
	var resumed: Dictionary = _bridge.resume_entry(saved.value)
	assert_true(resumed.ok, str(resumed))
	if not resumed.ok: return
	await _settle()
	_assert_hospital_caption(1)
	assert_eq(_native_starts, starts_before + 1)
	assert_eq(_native_text, [HOSPITAL_FIXTURE.catalogue().entries[0].lines[1].text])
	assert_eq(_restored.size(), 1)
	assert_true(_adapter.is_current_line_complete())
	assert_eq(_line_ids(), ["fixture.hospital.a", "fixture.hospital.b"])
	assert_eq(_bridge.get_reading_history(), history)
	assert_eq(_bridge.capture_reading_checkpoint(false), saved)
	assert_eq(_profile.get_profile_snapshot(), profile_before)
	assert_eq(_speech.requests, [], "restored B is visible without speaking it again")
	assert_eq(_physical_receipts, [])
	assert_eq(_publications.size(), 1)
	if _publications.size() == 1:
		assert_true(_publications[0].ok, str(_publications[0]))
		if _publications[0].ok: assert_true(_publications[0].value.get("duplicate", false))
	if not await _advance(): return
	assert_eq(_physical_receipts.size(), 1)
	assert_eq(_port.completions, [], "restored Hospital native end uses only its retained physical owner")

func test_same_process_cached_port_readopts_saved_b_and_completes_restored_occurrence_once() -> void:
	var root_store := ROOT_STORE.new()
	var wrapper := OS.get_environment("DWM_TEST_ROOT").strip_edges()
	assert_true(root_store.configure(STORAGE.new(wrapper.path_join("hospital-native-issuer"), FILES.new()),
		NAMESPACE_SOURCE.new()).ok)
	assert_true(root_store.load_or_create().ok)
	var issuer := ISSUER.new()
	assert_true(issuer.configure(root_store).ok)
	var port := HOSPITAL_PORT.new()
	assert_true(port.configure_frozen_hospital_contexts().ok)
	assert_true(port.configure(issuer, _owner).ok)
	var completions: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	port.completion_ready.connect(func(result: Dictionary) -> void: completions.append(result.duplicate(true)))
	port.completion_failed.connect(func(result: Dictionary) -> void: failures.append(result.duplicate(true)))
	var request := _issued_request(issuer)
	if request.is_empty() or not await _mount(): return
	var begun: Dictionary = port.begin(request)
	assert_true(begun.ok, str(begun))
	if not begun.ok: return
	var command: Dictionary = begun.value.presentation_command
	await _settle()
	_assert_hospital_caption(0)
	if not await _advance(): return
	var saved: Dictionary = _bridge.capture_reading_checkpoint(true)
	assert_true(saved.ok, str(saved))
	if not saved.ok: return
	if not await _advance(): return
	assert_eq(completions.size(), 1)
	assert_eq(_physical_receipts.size(), 1)
	assert_eq(_native_ends, 1)
	assert_true(port.begin(request).ok)
	assert_eq(_native_starts, 1, "an ordinary cached begin cannot replay a completed command")
	assert_eq(completions.size(), 1)
	assert_true(_bridge.retire_completed_hospital_reading(command).ok)
	assert_true(_bridge.stage_reading_restore(saved.value).ok)
	_native_text.clear()
	_speech.requests.clear()
	if not await _mount(): return
	var resumed: Dictionary = _bridge.resume_entry(saved.value)
	assert_true(resumed.ok, str(resumed))
	if not resumed.ok: return
	await _settle()
	assert_eq(_bridge.get_current_scene_art(), {"entry_id": HOSPITAL_ENTRY, "show_portraits": true},
		"restored art projects the validated frozen Hospital frame before physical adoption")
	assert_true(_bridge.is_hospital_reading_restore_for(command))
	assert_eq(completions.size(), 1, "restoring B cannot dispatch the old cached completion")
	var adopted: Dictionary = port.begin(request)
	assert_true(adopted.ok, str(adopted))
	if not adopted.ok: return
	assert_eq(adopted.value.presentation_command, command)
	_assert_hospital_caption(1)
	assert_false(_bridge.is_hospital_reading_restore_for(command), "cached begin consumes the exact adoption certificate")
	assert_eq(_native_starts, 2, "adoption does not start an additional native timeline")
	assert_eq(_native_text, [HOSPITAL_FIXTURE.catalogue().entries[0].lines[1].text])
	assert_eq(_line_ids(), ["fixture.hospital.a", "fixture.hospital.b"])
	assert_eq(_speech.requests, [])
	assert_eq(completions.size(), 1)
	assert_eq(_physical_receipts.size(), 1)
	if not await _advance(): return
	assert_eq(_native_ends, 2)
	assert_eq(_physical_receipts.size(), 2)
	assert_eq(completions.size(), 2, "fresh ordinary input settles this restored occurrence exactly once")
	if completions.size() == 2:
		assert_eq(completions[1].receipt.receipt_id, request.completion_transaction_id)
	assert_eq(failures, [])
	assert_eq(_port.completions, [])
	assert_true(port.begin(request).ok)
	_runtime.timeline_ended.emit() # Negative duplicate after the restored native return.
	assert_eq(_native_starts, 2)
	assert_eq(completions.size(), 2)
	assert_eq(_physical_receipts.size(), 2)
