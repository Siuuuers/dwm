extends "res://addons/gut/test.gd"
# The ONE narrative physical-presentation owner (Plan 01 Task 8, dwm-p2r.14).
#
# WHAT THIS FILE OWNS. That a physical completion can come from exactly one place: the Dialogic
# runtime's own end-of-timeline signal, observed through the bridge. Before Task 8 the bridge
# exposed a public `finish_current_timeline()` and any caller could announce a completion that never
# happened. This suite proves the adapter cannot be talked into one.
#
# SUBSTRATE. A real DialogicBridge node in the tree over the project's real Dialogic runtime, so the
# timeline genuinely starts and genuinely ends through the runtime seam rather than through a test
# shortcut. Starts are counted through the bridge's own `timeline_started` signal -- the seam the
# production adapter actually drives. Nothing here calls a "finish" method, because none exists any
# more.

const ADAPTER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const BRIDGE_PATH := "res://autoload/DialogicBridge.gd"
const RUNTIME_ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")

const TIMELINE_ID := "hospital.faint"
const OTHER_TIMELINE_ID := "contact.ordinary.lavinia.day1"

var _bridge: Node
var _adapter: RefCounted
var _runtime: DialogicGameHandler
var _runtime_adapter: RefCounted
var _original_runtime: Node
var _original_runtime_index := 0
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _style_directory: Dictionary = {}
var _native_starts := 0
var _native_ends := 0
var _ready_receipts: Array = []
var _failures: Array = []
var _started_timelines: Array = []
var _fixture_layouts: Array[Node] = []
var _fixture_text_nodes: Array[Node] = []
var _baseline_text_nodes: Array[Node] = []
var _baseline_text_ids: Array[int] = []
var _tearing_down := false


func before_each() -> void:
	# A preceding suite may have entered DialogicTimeline.clean(), whose native end_timeline()
	# continuation resumes one frame later. Keep the shared autoload attached for that continuation
	# and for the queued layout cleanup before this fixture snapshots and detaches it.
	await get_tree().process_frame
	await get_tree().process_frame
	_fixture_layouts.clear()
	_fixture_text_nodes.clear()
	_tearing_down = false
	_baseline_text_nodes.assign(get_tree().get_nodes_in_group("dialogic_dialog_text"))
	_baseline_text_ids = _node_identities(_baseline_text_nodes)
	_ready_receipts = []
	_failures = []
	_started_timelines = []
	_native_starts = 0
	_native_ends = 0
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
	_settings = {}
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		_settings[key] = {
			"exists": ProjectSettings.has_setting(key),
			"value": ProjectSettings.get_setting(key),
		}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	_runtime = DialogicGameHandler.new()
	_runtime.name = "Dialogic"
	get_tree().root.add_child(_runtime)
	_runtime.Styles.style_changed.connect(_record_fixture_style)
	_runtime.History.simple_history_enabled = true
	_runtime.History.save_visited_history_on_save = false
	_runtime.History.save_visited_history_on_autosave = false
	_runtime.timeline_started.connect(func() -> void: _native_starts += 1)
	_runtime.timeline_ended.connect(func() -> void: _native_ends += 1)
	_runtime_adapter = RUNTIME_ADAPTER.new()
	assert_true(_runtime_adapter.bind_runtime(_runtime).get("ok", false))
	_bridge = load(BRIDGE_PATH).new()
	_bridge.name = "TestDialogicBridge"
	add_child(_bridge)
	assert_true(_bridge.initialize(null, _runtime_adapter).get("ok", false))
	_bridge.timeline_started.connect(func(timeline_id: String, _path: String) -> void:
		_started_timelines.append(timeline_id))
	_adapter = ADAPTER.new()
	assert_true(_adapter.configure(_bridge).get("ok", false))
	_adapter.physical_completion_ready.connect(func(receipt: Dictionary) -> void:
		_ready_receipts.append(receipt.duplicate(true)))
	_adapter.physical_completion_failed.connect(func(failure: Dictionary) -> void:
		_failures.append(failure.duplicate(true)))


func after_each() -> void:
	var starts_before_cleanup := _native_starts
	_tearing_down = true
	if is_instance_valid(_bridge):
		_bridge.free()
	# Several tests deliberately finish before layout.ready. clear() alone cannot
	# cancel that admitted native start: it could start during teardown and create
	# a replacement layout after Styles' current layout was selected for deletion.
	if is_instance_valid(_runtime_adapter):
		_runtime_adapter.halt_with_error({"ok": false, "code": &"fixture_teardown"})
	for text_node: Node in _fixture_text_nodes:
		if is_instance_valid(text_node): text_node.set_process(false)
	if is_instance_valid(_runtime):
		_runtime.paused = false
		await _runtime.clear()
		# Keep the fixture runtime attached for native timeline.clean()'s one-frame
		# continuation and for queued layout mounts/deletions before restoring it.
		await get_tree().process_frame
		await get_tree().process_frame
	assert_eq(_native_starts, starts_before_cleanup,
		"teardown cancels pending native starts before their layouts become ready")
	for layout: Node in _fixture_layouts:
		if is_instance_valid(layout): layout.free()
	for text_node: Node in _fixture_text_nodes:
		var survived := is_instance_valid(text_node)
		assert_false(survived, "fixture caption survived its exact layout: " + _node_diagnostic(text_node))
		if survived: text_node.free()
	_fixture_layouts.clear()
	_fixture_text_nodes.clear()
	if is_instance_valid(_runtime):
		_runtime.free()
	_adapter = null
	_runtime_adapter = null
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_runtime_index)
	if is_instance_valid(_original_layout):
		if is_instance_valid(_original_layout_parent):
			_original_layout_parent.add_child(_original_layout)
			_original_layout_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	var restored_text_nodes: Array[Node] = []
	restored_text_nodes.assign(get_tree().get_nodes_in_group("dialogic_dialog_text"))
	assert_eq(_node_identities(restored_text_nodes), _baseline_text_ids,
		"caption group must return to its exact pre-fixture owners; actual=" + _nodes_diagnostic(restored_text_nodes)
		+ " baseline=" + _nodes_diagnostic(_baseline_text_nodes))
	_baseline_text_nodes.clear()
	_baseline_text_ids.clear()
	for key: String in _settings:
		ProjectSettings.set_setting(key,
			_settings[key].value if _settings[key].exists else null)
	if _had_persistent:
		Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else:
		Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null


func _record_fixture_style(_info: Dictionary) -> void:
	# Styles publishes the exact new root before its deferred add_child. Retain
	# every root, including a retry's replacement, instead of relying on metadata
	# that can already have changed or disappeared when teardown begins.
	var layout: Node = _runtime.Styles.get_layout_node()
	if not is_instance_valid(layout): return
	if not _fixture_layouts.has(layout): _fixture_layouts.append(layout)
	_record_fixture_caption_nodes(layout)
	if not layout.is_node_ready():
		var record := _record_fixture_caption_nodes.bind(layout)
		if not layout.ready.is_connected(record):
			layout.ready.connect(record, CONNECT_ONE_SHOT)


func _record_fixture_caption_nodes(layout: Node) -> void:
	for node: Node in layout.find_children("*", "", true, false):
		if node.is_in_group("dialogic_dialog_text"):
			if not _fixture_text_nodes.has(node): _fixture_text_nodes.append(node)
			if _tearing_down: node.set_process(false)


func _node_diagnostic(node: Variant) -> String:
	if not is_instance_valid(node): return "<freed>"
	return JSON.stringify({"id": node.get_instance_id(), "name": str(node.name),
		"path": str(node.get_path()) if node.is_inside_tree() else "<detached>"})


func _nodes_diagnostic(nodes: Array[Node]) -> String:
	var rows: Array[String] = []
	for node: Node in nodes: rows.append(_node_diagnostic(node))
	return "[" + ", ".join(rows) + "]"


func _node_identities(nodes: Array[Node]) -> Array[int]:
	var ids: Array[int] = []
	for node: Node in nodes:
		if is_instance_valid(node): ids.append(node.get_instance_id())
	ids.sort()
	return ids


# -------------------------------------------------------------------------------------------------
# configure
# -------------------------------------------------------------------------------------------------

func test_configure_is_idempotent_for_the_same_bridge_and_refuses_a_replacement() -> void:
	var replayed: Dictionary = _adapter.configure(_bridge)
	assert_true(replayed.get("ok", false), "identical replay is idempotent")
	assert_true(bool(replayed["value"]["already_configured"]))
	assert_eq(int(replayed["value"]["bridge_instance_id"]), _bridge.get_instance_id())

	var other: Node = load(BRIDGE_PATH).new()
	add_child_autofree(other)
	var replaced: Dictionary = _adapter.configure(other)
	assert_false(replaced.get("ok", true), "a configured owner never adopts a replacement bridge")
	assert_eq(replaced.get("code"), &"narrative_owner_already_configured")


func test_an_unconfigured_owner_starts_nothing_and_validates_nothing() -> void:
	var fresh: RefCounted = ADAPTER.new()
	assert_eq(fresh.begin_physical(_command()).get("code"), &"narrative_owner_unconfigured")
	assert_eq(fresh.validate_physical_completion({
		"presentation_command": _command(), "physical_completion_receipt": {},
	}).get("code"), &"narrative_owner_unconfigured")


func test_an_incomplete_bridge_contract_is_refused() -> void:
	var fresh: RefCounted = ADAPTER.new()
	assert_eq(fresh.configure(null).get("code"), &"invalid_narrative_bridge")
	assert_eq(fresh.configure(RefCounted.new()).get("code"), &"invalid_narrative_bridge")


func test_the_owner_declares_the_narrative_kind_only() -> void:
	assert_eq(_adapter.owner_kind(), "narrative",
		"the Dating port accepts only dating_challenge, so these can never be swapped")


# -------------------------------------------------------------------------------------------------
# begin_physical
# -------------------------------------------------------------------------------------------------

func test_begin_physical_starts_the_timeline_and_returns_the_derived_token() -> void:
	var command := _command()
	var begun: Dictionary = _adapter.begin_physical(command)
	assert_true(begun.get("ok", false), str(begun))
	assert_eq(str(begun["value"]["command_sha256"]), str(command["command_sha256"]))
	assert_eq(str(begun["value"]["physical_token"]),
		ADAPTER.derive_token(str(command["completion_transaction_id"]),
			str(command["command_sha256"])),
		"the token is DERIVED from the completion id plus command hash, never minted")
	assert_eq(begun["receipt"], {}, "begin_physical carries no receipt")
	assert_eq(_started_timelines, [TIMELINE_ID], "the timeline really started, exactly once")


func test_an_exact_replay_returns_the_identical_token_without_restarting_the_timeline() -> void:
	var command := _command()
	var first: Dictionary = _adapter.begin_physical(command)
	var second: Dictionary = _adapter.begin_physical(command.duplicate(true))
	assert_true(second.get("ok", false), str(second))
	assert_eq(str(second["value"]["physical_token"]), str(first["value"]["physical_token"]))
	assert_eq(_started_timelines, [TIMELINE_ID],
		"an unfinished restore replays the same command WITHOUT replaying the narrative")


func test_the_same_completion_id_with_changed_bytes_is_a_command_conflict() -> void:
	var command := _command()
	assert_true(_adapter.begin_physical(command).get("ok", false))
	var drifted := command.duplicate(true)
	drifted["command_sha256"] = "f".repeat(64)
	var conflicted: Dictionary = _adapter.begin_physical(drifted)
	assert_false(conflicted.get("ok", true))
	assert_eq(conflicted.get("code"), &"presentation_command_conflict")


func test_the_command_member_set_is_exact() -> void:
	var base := _command()
	var extra := base.duplicate(true)
	extra["ending_id"] = "ending.alone"
	assert_eq(_adapter.begin_physical(extra).get("code"), &"invalid_presentation_command",
		"a caller cannot smuggle an ending id through the physical owner")
	var missing := base.duplicate(true)
	missing.erase("timeline_id")
	assert_eq(_adapter.begin_physical(missing).get("code"), &"invalid_presentation_command")


func test_an_unregistered_timeline_never_starts_a_presentation() -> void:
	var command := _command()
	command["timeline_id"] = "not.a.registered.timeline"
	command["command_sha256"] = "a".repeat(64)
	var begun: Dictionary = _adapter.begin_physical(command)
	assert_false(begun.get("ok", true), str(begun))
	assert_eq(begun.get("code"), &"narrative_presentation_unavailable")
	assert_true(_started_timelines.is_empty(), "nothing physically started")


# -------------------------------------------------------------------------------------------------
# the trusted completion path
# -------------------------------------------------------------------------------------------------

func test_the_runtime_end_signal_produces_exactly_one_trusted_completion() -> void:
	var command := _command()
	assert_true(_adapter.begin_physical(command).get("ok", false))
	await _end_runtime_timeline()

	assert_eq(_ready_receipts.size(), 1, "exactly one completion is emitted")
	var receipt: Dictionary = _ready_receipts[0]
	var keys: Array = receipt.keys()
	keys.sort()
	assert_eq(keys, ADAPTER.RECEIPT_KEYS, "the owner receipt member set is exact")
	assert_eq(str(receipt["owner_kind"]), "narrative")
	assert_eq(str(receipt["status"]), "completed")
	assert_eq(str(receipt["completion_transaction_id"]),
		str(command["completion_transaction_id"]))
	assert_eq(str(receipt["command_sha256"]), str(command["command_sha256"]))
	assert_true(_failures.is_empty(), "no failure accompanies a clean completion")


func test_a_duplicate_runtime_end_signal_emits_no_second_completion() -> void:
	assert_true(_adapter.begin_physical(_command()).get("ok", false))
	await _end_runtime_timeline()
	_runtime.timeline_ended.emit()
	assert_eq(_native_ends, 2, "the duplicate entered through the runtime's native signal seam")
	assert_eq(_ready_receipts.size(), 1,
		"the bridge clears its retained timeline before emitting, so a repeat is a no-op")


func test_a_foreign_timeline_completion_is_ignored() -> void:
	# Other systems legitimately run timelines. One ending while a presentation is in flight must
	# not be mistaken for that presentation finishing.
	assert_true(_adapter.begin_physical(_command()).get("ok", false))
	_bridge.timeline_finished.emit(OTHER_TIMELINE_ID, {"timeline_id": OTHER_TIMELINE_ID})
	assert_true(_ready_receipts.is_empty(), "a timeline this owner did not start is ignored")


func test_no_public_bridge_method_can_forge_a_completion() -> void:
	# Task 8 removes the caller-forgeable finisher outright. If it ever comes back, this fails.
	assert_false(_bridge.has_method("finish_current_timeline"),
		"the caller-forgeable finish_current_timeline() is gone")
	assert_true(_adapter.begin_physical(_command()).get("ok", false))
	assert_true(_ready_receipts.is_empty(), "starting alone completes nothing")


# -------------------------------------------------------------------------------------------------
# validate_physical_completion
# -------------------------------------------------------------------------------------------------

func test_the_emitted_receipt_validates_and_a_drifted_one_does_not() -> void:
	var command := _command()
	assert_true(_adapter.begin_physical(command).get("ok", false))
	await _end_runtime_timeline()
	var emitted: Dictionary = _ready_receipts[0]

	assert_true(_adapter.validate_physical_completion({
		"presentation_command": _canonical(command),
		"physical_completion_receipt": emitted.duplicate(true),
	}).get("ok", false), "the record this owner actually emitted validates")

	for field: String in ["owner_kind", "physical_token", "command_sha256",
			"completion_transaction_id", "status"]:
		var drifted: Dictionary = emitted.duplicate(true)
		drifted[field] = "drifted"
		var result: Dictionary = _adapter.validate_physical_completion({
			"presentation_command": _canonical(command),
			"physical_completion_receipt": drifted,
		})
		assert_false(result.get("ok", true), field + " drift must be refused")
		assert_eq(result.get("code"), &"physical_completion_untrusted", field)


func test_a_scene_authored_result_is_refused() -> void:
	# The single most important refusal: a scene cannot decide what physically happened.
	var command := _command()
	assert_true(_adapter.begin_physical(command).get("ok", false))
	await _end_runtime_timeline()
	var forged: Dictionary = (_ready_receipts[0] as Dictionary).duplicate(true)
	forged["result"] = {"outcome": "attended", "affection_delta": 99}
	var result: Dictionary = _adapter.validate_physical_completion({
		"presentation_command": _canonical(command),
		"physical_completion_receipt": forged,
	})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"physical_completion_untrusted")


func test_a_completion_that_never_happened_cannot_be_validated() -> void:
	var command := _command()
	assert_true(_adapter.begin_physical(command).get("ok", false))
	var fabricated := {
		"owner_kind": "narrative",
		"physical_token": ADAPTER.derive_token(str(command["completion_transaction_id"]),
			str(command["command_sha256"])),
		"command_sha256": str(command["command_sha256"]),
		"completion_transaction_id": str(command["completion_transaction_id"]),
		"status": "completed",
		"result": {},
	}
	var result: Dictionary = _adapter.validate_physical_completion({
		"presentation_command": _canonical(command),
		"physical_completion_receipt": fabricated,
	})
	assert_false(result.get("ok", true),
		"a perfectly SHAPED receipt for a timeline that never ended is still untrusted")
	assert_eq(result.get("code"), &"physical_completion_untrusted")


func test_a_receipt_from_another_command_is_refused() -> void:
	var first := _command()
	assert_true(_adapter.begin_physical(first).get("ok", false))
	await _end_runtime_timeline()
	var emitted: Dictionary = _ready_receipts[0]

	var second := _command("completion.other", "b".repeat(64))
	var result: Dictionary = _adapter.validate_physical_completion({
		"presentation_command": _canonical(second),
		"physical_completion_receipt": emitted.duplicate(true),
	})
	assert_false(result.get("ok", true), "one command's completion cannot settle another")
	assert_eq(result.get("code"), &"physical_completion_untrusted")


func test_the_validate_request_and_receipt_member_sets_are_exact() -> void:
	var command := _command()
	assert_eq(_adapter.validate_physical_completion({
		"presentation_command": _canonical(command),
	}).get("code"), &"invalid_completion_request")
	assert_eq(_adapter.validate_physical_completion({
		"presentation_command": _canonical(command),
		"physical_completion_receipt": {},
		"extra": 1,
	}).get("code"), &"invalid_completion_request")
	assert_eq(_adapter.validate_physical_completion({
		"presentation_command": _canonical(command),
		"physical_completion_receipt": {"owner_kind": "narrative"},
	}).get("code"), &"physical_completion_untrusted")
	# The canonical command must carry the token THIS owner derives, not one a caller picked.
	var forged_token := _canonical(command)
	forged_token["physical_token"] = "narrative_presentation.forged"
	assert_eq(_adapter.validate_physical_completion({
		"presentation_command": forged_token,
		"physical_completion_receipt": {},
	}).get("code"), &"physical_completion_untrusted")
	# And it must be the CANONICAL command: the pre-token command is not what complete() validates.
	assert_eq(_adapter.validate_physical_completion({
		"presentation_command": command,
		"physical_completion_receipt": {},
	}).get("code"), &"invalid_presentation_command")


# -------------------------------------------------------------------------------------------------
# helpers
# -------------------------------------------------------------------------------------------------

## Waits for the shipped return-only Hospital timeline to reach Dialogic's own natural end. The
## native signal count proves this completion came from the isolated runtime, not a bridge callback.
func _end_runtime_timeline() -> void:
	for attempt in 100:
		if _native_ends > 0:
			break
		await get_tree().create_timer(0.02).timeout
	assert_eq(_native_starts, 1, "the shipped Hospital timeline physically started exactly once")
	assert_eq(_native_ends, 1, "the shipped return-only Hospital timeline naturally ended exactly once")


## The canonical command: begin_physical()'s command plus the token this owner derived for it. This
## is what the port hands validate_physical_completion(), so the tests hand it the same shape.
func _canonical(command: Dictionary) -> Dictionary:
	var canonical := command.duplicate(true)
	canonical["physical_token"] = ADAPTER.derive_token(
		str(command["completion_transaction_id"]), str(command["command_sha256"]))
	return canonical


func _command(completion_id: String = "completion.hospital.day3",
		sha256: String = "c".repeat(64)) -> Dictionary:
	return {
		"resolution_id": "resolution.day3",
		"resolution_issuer_receipt": {"receipt_id": "root.day3"},
		"stage_id": "stage.hospital",
		"substage_id": "intent.hospital",
		"route_id": "hospital",
		"timeline_id": TIMELINE_ID,
		"context": {"kind": "hospital", "day": 3, "source_entry_ids": [], "miss_receipt_ids": []},
		"completion_transaction_id": completion_id,
		"completion_transaction_provenance": {"child_id": completion_id},
		"command_sha256": sha256,
	}


func test_failure_observer_can_immediately_retry_without_reusing_the_retired_layout() -> void:
	var command := _command()
	_runtime.paused = true
	var first: Dictionary = _adapter.begin_physical(command)
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false): return
	var old_layout: Node = _runtime.Styles.get_layout_node()
	assert_not_null(old_layout)
	if old_layout == null: return
	assert_false(old_layout.is_node_ready())
	assert_eq(_native_starts, 0)
	var queued_start := Callable()
	var located: Dictionary = DialogicTimelineCatalog.get_path_for_id(TIMELINE_ID)
	assert_true(located.get("ok", false))
	for connection: Dictionary in old_layout.ready.get_connections():
		var callback: Callable = connection.callable
		if callback.get_object() != _runtime or callback.get_method() != &"start_timeline": continue
		var arguments: Array = callback.get_bound_arguments()
		if arguments.size() >= 2 and str(arguments[0]) == str(located.value.path) and arguments[1] == "":
			queued_start = callback
			break
	assert_true(queued_start.is_valid(), "target the real admitted ready callback including its native request identity")
	if not queued_start.is_valid(): return
	var retries: Array[Dictionary] = []
	var replacement_layouts: Array[Node] = []
	_adapter.physical_completion_failed.connect(func(_failure: Dictionary):
		if not retries.is_empty(): return
		assert_eq(_native_starts, 0)
		assert_true(_ready_receipts.is_empty())
		# Synchronous retry is essential: no frame or deferred deletion may occur
		# between the failure notification and this new admission.
		var retry: Dictionary = _adapter.begin_physical(command)
		retries.append(retry)
		assert_true(retry.get("ok", false), str(retry))
		var replacement: Node = _runtime.Styles.get_layout_node()
		replacement_layouts.append(replacement)
		assert_not_null(replacement)
		assert_ne(replacement, old_layout, "retry must not adopt the failed layout awaiting deferred deletion"))
	old_layout.ready.disconnect(queued_start)
	for frame in 8: await get_tree().process_frame
	assert_eq(retries.size(), 1)
	assert_eq(_failures.size(), 1)
	assert_false(is_instance_valid(old_layout), "failed layout is actually freed after mounting")
	assert_eq(_native_starts, 1, "only the immediate retry physically starts")
	assert_eq(_native_ends, 0, "retry remains paused before its first event")
	assert_true(_bridge.has_active_playback())
	if replacement_layouts.is_empty(): return
	assert_true(is_instance_valid(replacement_layouts[0]), "the retry layout survives the old layout's deferred deletion")
	assert_eq(_runtime.Styles.get_layout_node(), replacement_layouts[0])
	if not retries.is_empty() and retries[0].get("ok", false):
		assert_eq(retries[0].value.physical_token, first.value.physical_token)
	_runtime.paused = false
	await _end_runtime_timeline()
	assert_eq(_ready_receipts.size(), 1, "the retried command has exactly one real natural completion")
	assert_eq(_failures.size(), 1)
	if not _ready_receipts.is_empty():
		assert_eq(_ready_receipts[0].physical_token, first.value.physical_token)
	assert_false(_bridge.has_active_playback())


func test_ordinary_faint_uses_native_playback_and_one_exact_completion() -> void:
	var command := _command()
	var begun: Dictionary = _adapter.begin_physical(command)
	assert_true(begun.ok, str(begun))
	if not begun.ok: return
	assert_true(_bridge.has_active_playback(), "ordinary fainting owns shared DTL playback")
	assert_true(_ready_receipts.is_empty(), "admission alone cannot complete Hospital")
	await _end_runtime_timeline()
	assert_eq(_ready_receipts.size(), 1)
	if _ready_receipts.size() != 1: return
	var receipt: Dictionary = _ready_receipts[0]
	assert_false(receipt.result.has("notice_acknowledged"))
	assert_true(_adapter.validate_physical_completion({"presentation_command": _canonical(command),
		"physical_completion_receipt": receipt}).ok)
	var forged := _canonical(command)
	forged.physical_token += ".foreign"
	assert_false(_adapter.validate_physical_completion({"presentation_command": forged,
		"physical_completion_receipt": receipt}).ok)
	assert_true(_adapter.begin_physical(command).ok, "settled admission reuses its exact command")
	_runtime.timeline_ended.emit()
	assert_eq(_native_starts, 1)
	assert_eq(_ready_receipts.size(), 1, "duplicate native end cannot repeat completion")
