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

const TIMELINE_ID := "hospital.faint"
const OTHER_TIMELINE_ID := "opening.day1"

var _bridge: Node
var _adapter: RefCounted
var _ready_receipts: Array = []
var _failures: Array = []
var _started_timelines: Array = []


func before_each() -> void:
	_ready_receipts = []
	_failures = []
	_started_timelines = []
	_bridge = load(BRIDGE_PATH).new()
	_bridge.name = "TestDialogicBridge"
	add_child_autofree(_bridge)
	_bridge.timeline_started.connect(func(timeline_id: String, _path: String) -> void:
		_started_timelines.append(timeline_id))
	_adapter = ADAPTER.new()
	assert_true(_adapter.configure(_bridge).get("ok", false))
	_adapter.physical_completion_ready.connect(func(receipt: Dictionary) -> void:
		_ready_receipts.append(receipt.duplicate(true)))
	_adapter.physical_completion_failed.connect(func(failure: Dictionary) -> void:
		_failures.append(failure.duplicate(true)))


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
	_end_runtime_timeline()

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
	_end_runtime_timeline()
	_end_runtime_timeline()
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
	_end_runtime_timeline()
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
	_end_runtime_timeline()
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
	_end_runtime_timeline()
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

## Ends the timeline through the RUNTIME seam, which is the only path Task 8 leaves open.
func _end_runtime_timeline() -> void:
	_bridge.call(&"_on_runtime_timeline_ended")


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
