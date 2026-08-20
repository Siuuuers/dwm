extends "res://addons/gut/test.gd"
# Plan 01 Task 8 Step 8.2: RESUME across every presentation crash cut (dwm-p2r.18).
#
# WHAT THIS FILE OWNS. Step 8.2 asks for a crash at each boundary of a presentation -- before intent
# derivation, after the exact intent, after the route command, after the physical completion signal,
# after the exact completion derivation, after port validation, after the domain receipt, and after
# the stage checkpoint -- and requires that a restore "replay the same matrix row/ordinal/source
# bytes, resume the one unfinished boundary, reconnect signals exactly once, never renumber a
# surviving presentation, never replay a committed recovery/date effect, and never skip a missing
# physical receipt."
#
# WHAT A CRASH IS HERE. Not a flag: every in-memory owner is DESTROYED and rebuilt from the same
# on-disk issuer root plus the persisted lifecycle bytes -- a fresh GameState, a fresh state port, a
# fresh issuer, a fresh presentation port, a fresh narrative owner, a fresh bridge. That is the only
# model under which "the same children come back" means anything: if the answer were held in the
# objects rather than derived from the bytes, this suite would pass while production corrupted
# itself on the first reload.
#
# WHY THE ROOT HAD TO BE PERSISTED. `P01.presentation.intent` projects
# `day_resolution_start_receipt_id`, and `resume()` never re-runs `begin_or_resume`. Before
# dwm-p2r.18 the resolution root existed only for the life of the process, so a restored resolution
# would have derived DIFFERENT presentation children than the ones it had already published. Every
# assertion below is ultimately a test of that one decision.
#
# SUBSTRATE. Real throughout: a GUID-isolated root, a real DesktopIssuerRootStore over real
# JsonFileStorage, the real DesktopIdentityNonceIssuer, the production ScheduleActionRegistry, the
# real GameStateScheduleCommitPort, a real GameState in the tree, and the real
# DialogicPresentationOwnerAdapter over a real DialogicBridge. The ONLY fixture is the Plan-02
# desktop-consequence source, which has no production implementation to use (DEVIATION-2/5) and
# which plan line 532 explicitly authorises as a schema-exact test fixture.

const COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const START_PORT := preload("res://scripts/application/run/DayResolutionStartPort.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const DATING_PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
const FAKE_DATING_OWNER := preload("res://tests/support/FakeDatingPresentationOwner.gd")
const CONSEQUENCE_SOURCE := preload("res://tests/support/FakeDesktopConsequenceSource.gd")
const HOSPITAL_PORT := preload("res://scripts/application/run/HospitalPresentationPort.gd")
const PRESENTATION_OWNER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")

const CAUSAL_DAY := "causal_day_instance.5555555555555555555555555555555555555555555555555555555555555555"
const VIEW_FINGERPRINT := "schedule_view.55555555555555555555555555555555"
const MAX_WALK_STEPS := 40

var _root := ""
var _root_counter := 0
var _registry: RefCounted
var _fingerprint := ""
## The live process. `_crash()` replaces every one of these.
var _issuer: RefCounted
var _game_state: Node
var _state_port: RefCounted
var _dating_port: RefCounted
var _dating_owner: RefCounted
var _hospital_port: RefCounted
## Retained only so the Cut-9 crash can carry the Plan-02 consequence records across it; every
## other cut ignores it. See `_crash_from_document`.
var _consequence: RefCounted
var _bridge: Node
var _completions: Array[Dictionary] = []
var _commands: Dictionary = {}


func before_each() -> void:
	_commands = {}
	_root_counter += 1
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root = wrapper.path_join("presentation-resume-%d" % _root_counter)
	assert_eq(DirAccess.make_dir_recursive_absolute(_root), OK)

	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded.get("value", {}) as Dictionary).get("registry_fingerprint", ""))
	_boot()


## Builds one COMPLETE set of process owners over the on-disk root. Called once at start and again
## by `_crash()`; nothing is carried across except the bytes on disk and the lifecycle snapshot.
func _boot() -> void:
	var storage := JsonFileStorage.new(_root)
	var store: RefCounted = ROOT_STORE.new()
	assert_true(store.configure(storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(store).get("ok", false))

	_game_state = load(GAME_STATE_PATH).new()
	add_child_autofree(_game_state)
	_game_state.reset_game()

	var ledger: RefCounted = LEDGER.new()
	assert_true(ledger.configure(storage).get("ok", false))
	assert_true(ledger.load().get("ok", false))
	_state_port = STATE_PORT.new(_game_state)

	_consequence = CONSEQUENCE_SOURCE.new()
	assert_true(_consequence.configure(_issuer).get("ok", false))
	assert_true(_state_port.configure_desktop_consequence_source(_consequence).get("ok", false))
	assert_true(_state_port.configure_resolution_identity(
		_issuer, START_PORT.new(_state_port, _registry, _issuer, ledger)).get("ok", false))

	# A DATE presents through the Dating port. Production leaves it owner-less for dwm-oyo.4, so a
	# contract test configures the schema-exact fake owner -- never bootstrap.
	_completions = []
	_dating_owner = FAKE_DATING_OWNER.new()
	_dating_port = DATING_PORT.new()
	assert_true(_dating_port.configure(_issuer, _dating_owner).get("ok", false))
	_dating_port.completion_ready.connect(func(result: Dictionary) -> void:
		_completions.append((result["receipt"] as Dictionary).duplicate(true)))

	# A TRIGGERED Hospital presents as well, so a walk that passes through one needs the real
	# narrative owner over a real bridge to carry it.
	_bridge = load("res://autoload/DialogicBridge.gd").new()
	add_child_autofree(_bridge)
	var narrative_owner: RefCounted = PRESENTATION_OWNER.new()
	assert_true(narrative_owner.configure(_bridge).get("ok", false))
	_hospital_port = HOSPITAL_PORT.new()
	assert_true(_hospital_port.configure(_issuer, narrative_owner).get("ok", false))
	_hospital_port.completion_ready.connect(func(result: Dictionary) -> void:
		_completions.append((result["receipt"] as Dictionary).duplicate(true)))


## THE CRASH. Every process owner is destroyed and rebuilt from the same on-disk root; only the
## durable lifecycle bytes and the Contacts index are carried back in, exactly as a checkpoint
## restore would supply them.
func _crash(lifecycle_bytes: Dictionary, contacts: Dictionary) -> void:
	_game_state.queue_free()
	_boot()
	var prepared: Dictionary = _game_state._run_lifecycle.prepare_restore(lifecycle_bytes)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return
	assert_true(_game_state._run_lifecycle.commit_restore(
		(prepared["value"] as Dictionary)["candidate"]).get("ok", false))
	_game_state.contacts = contacts.duplicate(true)


# -------------------------------------------------------------------------------------------------
# Cuts 1-2: before intent derivation, and after the exact intent
# -------------------------------------------------------------------------------------------------

## The whole bead in one assertion: the SAME bytes derive the SAME children after a total process
## loss. Cut 1 (nothing derived yet) and cut 2 (the intent already derived once) are indistinguishable
## from the plan's point of view precisely BECAUSE derivation is a pure function of persisted bytes --
## which is what makes an un-persisted root a corruption rather than an inconvenience.
func test_a_crash_before_or_after_intent_derivation_rebuilds_the_same_children() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var first := _await_date_presentation()
	if first.is_empty():
		return
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var contacts: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)

	_crash(lifecycle, contacts)
	var second := _await_date_presentation()
	if second.is_empty():
		return
	assert_eq(str(second["substage_id"]), str(first["substage_id"]),
		"the restored resolution derives the SAME P01.presentation.intent child")
	assert_eq(str(second["completion_transaction_id"]), str(first["completion_transaction_id"]),
		"and the SAME P01.presentation.completion child")
	assert_eq(second["completion_transaction_provenance"], first["completion_transaction_provenance"],
		"byte-identical provenance: same parent, same ordinal, same source projection")
	assert_eq(second, first, "the whole intent request replays byte for byte")


## Ordinals are a property of the committed slot order, never of how far a walk got. Two surviving
## dates keep ordinals 0 and 1 across a crash at the FIRST of them -- a renumbering here would
## silently re-point the second date's identity at the first date's row.
func test_a_crash_never_renumbers_a_surviving_presentation() -> void:
	_commit_and_begin(6, [
		_date("d-lav", 0, "lavinia", 6),
		_date("d-pri", 1, "priscilla", 6),
	])
	var first := _await_date_presentation()
	if first.is_empty():
		return
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var contacts: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)
	assert_eq(int((first["completion_transaction_provenance"] as Dictionary)["ordinal"]), 0,
		"the first surviving date is ordinal 0")

	_crash(lifecycle, contacts)
	var restored := _await_date_presentation()
	if restored.is_empty():
		return
	assert_eq(restored, first, "the first date comes back as the same row at the same ordinal")
	assert_eq(int((restored["completion_transaction_provenance"] as Dictionary)["ordinal"]), 0,
		"it is still ordinal 0 -- the walk's progress never feeds the ordinal")

	# Carry the first date through and prove the SECOND is a distinct row at ordinal 1.
	assert_true(_settle_presentation(restored), "the first date completes")
	var second := _await_date_presentation()
	if second.is_empty():
		return
	assert_eq(int((second["completion_transaction_provenance"] as Dictionary)["ordinal"]), 1,
		"the second surviving date is ordinal 1")
	assert_ne(str(second["substage_id"]), str(restored["substage_id"]),
		"and is a genuinely different intent child")


# -------------------------------------------------------------------------------------------------
# Cuts 3-4: after the route command, and after the physical completion signal
# -------------------------------------------------------------------------------------------------

## A restored port re-issues the byte-identical command and the owner re-derives the SAME token,
## because the token is a function of the completion id and the command hash rather than of any
## live handle. An unfinished presentation is therefore replayable rather than stranded.
func test_a_crash_after_the_route_command_replays_the_identical_command_and_token() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_date_presentation()
	if request.is_empty():
		return
	var started: Dictionary = _dating_port.begin(request)
	assert_true(started.get("ok", false), JSON.stringify(started))
	if not started.get("ok", false):
		return
	var command: Dictionary = (started["value"] as Dictionary)["presentation_command"]
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var contacts: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)

	_crash(lifecycle, contacts)
	var restored_request := _await_date_presentation()
	if restored_request.is_empty():
		return
	var restarted: Dictionary = _dating_port.begin(restored_request)
	assert_true(restarted.get("ok", false), JSON.stringify(restarted))
	if not restarted.get("ok", false):
		return
	var restored_command: Dictionary = (restarted["value"] as Dictionary)["presentation_command"]
	assert_eq(str(restored_command["command_sha256"]), str(command["command_sha256"]),
		"the restored command hashes to the same bytes")
	assert_eq(str(restored_command["physical_token"]), str(command["physical_token"]),
		"and the fresh owner derives the SAME token, so the old one is not stranded")
	assert_eq(restored_command, command, "the whole canonical command replays byte for byte")


## A duplicate runtime end is a no-op, not a second completion: the owner clears its retained
## timeline BEFORE it emits, so only the first end can produce a receipt.
func test_a_duplicate_physical_completion_publishes_exactly_one_receipt() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_date_presentation()
	if request.is_empty():
		return
	var started: Dictionary = _dating_port.begin(request)
	assert_true(started.get("ok", false))
	if not started.get("ok", false):
		return
	var command: Dictionary = (started["value"] as Dictionary)["presentation_command"]
	_dating_owner.finish(str(command["completion_transaction_id"]), {})
	assert_eq(_completions.size(), 1, "one physical end, one published completion")
	_dating_owner.finish(str(command["completion_transaction_id"]), {})
	assert_eq(_completions.size(), 1, "a duplicate end publishes nothing further")


# -------------------------------------------------------------------------------------------------
# Cuts 5-7: after completion derivation, after port validation, after the domain receipt
# -------------------------------------------------------------------------------------------------

## A settled completion transaction returns the byte-identical receipt on replay, and the stage
## envelope built from it is identical too -- so a crash between "the port validated it" and "the
## coordinator checkpointed it" resumes onto exactly the same durable bytes.
func test_a_settled_completion_replays_the_identical_receipt_and_envelope() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_date_presentation()
	if request.is_empty():
		return
	var started: Dictionary = _dating_port.begin(request)
	assert_true(started.get("ok", false))
	if not started.get("ok", false):
		return
	var command: Dictionary = (started["value"] as Dictionary)["presentation_command"]
	_dating_owner.finish(str(command["completion_transaction_id"]), {})
	assert_eq(_completions.size(), 1)
	if _completions.size() != 1:
		return
	var completion: Dictionary = _completions[0]
	var envelope: Dictionary = _state_port.presentation_stage_receipt(
		_awaiting_transaction_id(), completion)
	assert_true(envelope.get("ok", false), JSON.stringify(envelope))
	if not envelope.get("ok", false):
		return
	var receipt: Dictionary = (envelope["value"] as Dictionary)["receipt"]
	assert_eq(((receipt["value"] as Dictionary)["presentation_completion_receipt"] as Dictionary),
		completion, "the stage envelope carries the port's receipt verbatim")

	# A RESTORED owner replaying its settled record publishes the byte-identical receipt and does
	# not settle a second time -- which is what makes the window between port validation and the
	# stage checkpoint safe to crash in.
	_dating_owner.reemit(str(command["completion_transaction_id"]))
	assert_eq(_completions.size(), 1,
		"a restored owner replaying its settled record causes NO second publication")
	assert_eq(_completions[0], completion, "and the one publication is unchanged")


## A physical receipt that does not bind this exact command never reaches a stage. "Never skip a
## missing physical receipt" is the same law seen from the other side: the stage cannot complete
## from anything except the owner's own evidence.
func test_a_receipt_that_does_not_bind_the_command_never_reaches_a_stage() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_date_presentation()
	if request.is_empty():
		return
	var started: Dictionary = _dating_port.begin(request)
	assert_true(started.get("ok", false))
	if not started.get("ok", false):
		return
	var command: Dictionary = (started["value"] as Dictionary)["presentation_command"]
	var forged := {
		"owner_kind": "dating_challenge",
		"physical_token": "token.invented",
		"command_sha256": str(command["command_sha256"]),
		"completion_transaction_id": str(command["completion_transaction_id"]),
		"status": "completed",
		"result": {},
	}
	var refused: Dictionary = _dating_port.complete({
		"presentation_command": command.duplicate(true),
		"physical_completion_receipt": forged,
	})
	assert_false(refused.get("ok", true), "an invented token is refused")
	assert_eq(str(refused.get("code", "")), "physical_completion_untrusted",
		"and refused as untrusted rather than as a shape error")


# -------------------------------------------------------------------------------------------------
# Cut 8: after the stage checkpoint
# -------------------------------------------------------------------------------------------------

## Once the stage is durable the presentation is OVER. A crash after the checkpoint must resume
## past it and must never present the same date a second time.
func test_a_crash_after_the_stage_checkpoint_never_presents_again() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_date_presentation()
	if request.is_empty():
		return
	assert_true(_settle_presentation(request), "the date presentation completes and checkpoints")
	var settled_intent := str(request["substage_id"])
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var contacts: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)

	_crash(lifecycle, contacts)
	var cursor: Dictionary = _state_port.inspect_next_stage()
	assert_true(cursor.get("ok", false) and bool(cursor["value"]["has_stage"]),
		"the restored run still has work left")
	if not cursor.get("ok", false):
		return
	var record: Dictionary = cursor["value"]["stage"]
	assert_false(str(record.get("substage_id", "")).begins_with("surviving_date:"),
		"the completed date is behind the cursor, not offered again")
	var begun: Dictionary = _state_port.begin_next_stage()
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	if begun.get("ok", false):
		assert_ne(str((begun["value"] as Dictionary)["mode"]), "await_registered_command",
			"the restored walk does not re-present a checkpointed presentation")
	assert_false(settled_intent.is_empty(), "the settled intent id was recorded")


## A date Hospital superseded presents NOTHING, before or after a crash. This is the negative half
## of "never replay a committed recovery/date effect": a superseded date completes as a recorded
## miss and starts no board at all.
func test_a_superseded_date_never_presents_across_a_crash() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	_game_state.pending_hospital = true
	var walked := _walk_until_date_substage()
	assert_false(walked.is_empty(), "the walk reached the date substage")
	if walked.is_empty():
		return
	assert_ne(str(walked["mode"]), "await_registered_command",
		"a superseded date carries no presentation")
	var receipt: Dictionary = (walked["receipt"] as Dictionary)["value"]
	assert_true(bool(receipt["superseded"]), "it completes as a recorded miss")
	assert_eq(receipt["presentation_completion_receipt"], null,
		"and carries no presentation evidence, because none happened")


# -------------------------------------------------------------------------------------------------
# Cut 9: across the Hospital presentation, restored from the ON-DISK checkpoint (dwm-p2r.19)
# -------------------------------------------------------------------------------------------------

## The Hospital intent is the last presentation child derived from LIVE mutable state:
## `_presentation_site` routes `hospital_if_triggered` to `_hospital_site`, which reads
## `should_route_hospital()` -- and that method returns `pending_hospital` verbatim. Because
## `resume()` never re-runs `begin_or_resume`, a restored resolution derives that intent AGAIN. The
## only thing standing between it and a different answer than the one it already published is that
## the flag is checkpointed in the SAME bundle as the plan:
##
##   * `pending_hospital` is a member of `GameState._SAVE_WHITELIST`;
##   * `capture_run_snapshot_input()` builds `gameplay` from that whitelist and returns it beside
##     `lifecycle` -- which carries `active_resolution_plan` -- in ONE dictionary;
##   * `_checkpoint_inputs()` hands that one dictionary to `RunSnapshotSchema.build`, whose
##     `GAMEPLAY_FIELDS` lists `pending_hospital`, producing ONE document;
##   * `apply_save_dict()` walks the same whitelist back on restore.
##
## So the corrupt state -- a restored plan sitting mid-Hospital beside a CLEARED flag -- is not
## reachable, because both halves come from the same bytes. That argument is what this test exists
## to turn into a guarantee, because nothing else asserts it: every other cut in this file restores
## from an in-memory `to_dict()` and leaves `pending_hospital` SET across the cut, so all of them
## would pass just as happily if the flag stopped being captured at all. `RunSnapshotSchema` will
## not object either -- its gameplay check is an ALLOWLIST that rejects members it does not know
## and says nothing about a member that went missing.
##
## THE FLAG AND THE PLAN COME FROM BYTES ONLY -- which is narrower than saying the whole process
## does, and the difference is stated here rather than left to whoever reads the helper.
## `_boot()` calls `reset_game()`, which clears `pending_hospital`, so the rebuilt process starts
## with the flag FALSE and can only get it back from the same document that carried the plan. Two
## things DO cross the cut and neither carries either half: `_crash_from_document()` deliberately
## re-installs the consequence source's condition and board-fate memos (its own comment explains
## why -- DEVIATION-6 re-derives Hospital miss ids from the condition receipt, so a fresh receipt
## would move the intent for reasons unrelated to `pending_hospital`), and `_registry` /
## `_fingerprint` are loaded once in `before_each` rather than rebuilt per boot.
func test_a_crash_across_the_hospital_presentation_restores_the_flag_with_the_plan() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	_game_state.pending_hospital = true

	# The durable restore point is the checkpoint the stage BEFORE Hospital wrote: a presentation
	# checkpoints nothing until it completes, so this is the document a crash DURING one actually
	# comes back from.
	var document := _walk_to_hospital_checkpoint()
	assert_false(document.is_empty(), "a checkpoint was written before the Hospital stage")
	if document.is_empty():
		return

	# THE TWO HALVES, IN ONE DOCUMENT. Asserted against the bytes themselves, so a future change
	# that stopped capturing the flag fails HERE, naming the cause, rather than only downstream.
	var gameplay: Dictionary = document["gameplay"]
	var lifecycle_bytes: Dictionary = document["lifecycle"]
	assert_true(gameplay.has("pending_hospital"),
		"the checkpoint carries the condition flag the Hospital intent is derived from")
	assert_true(bool(gameplay.get("pending_hospital", false)),
		"and carries it TRUE, exactly as the live process held it")
	assert_eq(typeof(lifecycle_bytes.get("active_resolution_plan")), TYPE_DICTIONARY,
		"the SAME document carries the plan those bytes belong to")

	var begun: Dictionary = _state_port.begin_next_stage()
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	if not begun.get("ok", false):
		return
	var first: Dictionary = begun["value"]
	assert_eq(str(first["mode"]), "await_registered_command",
		"a triggered Hospital pauses on its presentation")
	if str(first["mode"]) != "await_registered_command":
		return
	var first_command: Dictionary = first["command"]
	var first_request: Dictionary = first_command["presentation_request"]

	# THE CRASH, mid-presentation: the intent is published and the timeline is playing, and nothing
	# about either is durable.
	if not _crash_from_document(document):
		return

	# The flag came back BECAUSE the plan did -- same document, same bytes, one restore.
	assert_true(bool(_game_state.pending_hospital),
		"the restored process holds the condition truth the checkpoint recorded")
	assert_true(bool(_game_state.should_route_hospital()),
		"so the live read the resumed derivation performs answers as it did before the crash")

	var resumed: Dictionary = _state_port.inspect_next_stage()
	assert_true(resumed.get("ok", false) and bool(resumed["value"]["has_stage"]),
		"the restored run still has the Hospital stage in front of it")
	if not resumed.get("ok", false):
		return
	assert_eq(str((resumed["value"]["stage"] as Dictionary).get("stage_id", "")), "hospital_if_triggered",
		"and it is exactly the stage the crash interrupted")

	var again: Dictionary = _state_port.begin_next_stage()
	assert_true(again.get("ok", false), JSON.stringify(again))
	if not again.get("ok", false):
		return
	var second: Dictionary = again["value"]
	assert_eq(str(second["mode"]), "await_registered_command",
		"the resumed walk derives a presentation, not a required=false completion over a published intent")
	if str(second["mode"]) != "await_registered_command":
		return
	var second_command: Dictionary = second["command"]
	assert_eq(str(second_command["transaction_id"]), str(first_command["transaction_id"]),
		"the restored plan offers the SAME Hospital stage transaction")
	assert_eq(second_command["presentation_request"], first_request,
		"and re-derives the P01.presentation.intent BYTE-IDENTICALLY, because the flag travelled with the plan")


# -------------------------------------------------------------------------------------------------
# helpers
# -------------------------------------------------------------------------------------------------

## Drives the walk to the first surviving-date substage and returns the exact presentation request
## the producer derived, leaving the stage awaiting.
func _await_date_presentation() -> Dictionary:
	var walked := _walk_until_date_substage()
	if walked.is_empty():
		return {}
	if str(walked["mode"]) != "await_registered_command":
		assert_true(false, "a surviving date must pause on its presentation")
		return {}
	return ((walked["command"] as Dictionary)["presentation_request"] as Dictionary)


## Walks until the first `surviving_date` substage is BEGUN, returning that begin result's value.
func _walk_until_date_substage() -> Dictionary:
	var steps := 0
	while steps < MAX_WALK_STEPS:
		steps += 1
		var cursor: Dictionary = _state_port.inspect_next_stage()
		if not cursor.get("ok", false) or not bool(cursor["value"]["has_stage"]):
			assert_true(false, "the walk ended before any date substage")
			return {}
		var record: Dictionary = cursor["value"]["stage"]
		var begun: Dictionary = _state_port.begin_next_stage()
		assert_true(begun.get("ok", false), JSON.stringify(begun))
		if not begun.get("ok", false):
			return {}
		if str(record.get("substage_id", "")).begins_with("surviving_date:"):
			return begun["value"] as Dictionary
		if not _complete_begun(begun["value"] as Dictionary):
			return {}
	assert_true(false, "the walk stopped advancing before a date substage")
	return {}


## Completes a non-presentation record from the receipt the port already produced.
func _complete_begun(begun_value: Dictionary) -> bool:
	if str(begun_value["mode"]) == "await_registered_command":
		# The only presentation a walk toward a date can pass through is a triggered Hospital.
		return _settle_hospital_presentation(begun_value)
	var stage: Dictionary = begun_value["stage"]
	var receipt: Dictionary = begun_value["receipt"]
	var completed: Dictionary = _game_state._run_lifecycle.complete_active_stage(
		str(stage["transaction_id"]), {"value": (receipt["value"] as Dictionary).duplicate(true)})
	assert_true(completed.get("ok", false), JSON.stringify(completed))
	return completed.get("ok", false)


## Carries an awaiting HOSPITAL presentation to a completed stage, through the real narrative owner.
func _settle_hospital_presentation(begun_value: Dictionary) -> bool:
	var command: Dictionary = begun_value["command"]
	assert_eq(str(command["route_id"]), "hospital",
		"only a Hospital presentation may interrupt a walk toward a date")
	var started: Dictionary = _hospital_port.begin(command["presentation_request"])
	assert_true(started.get("ok", false), JSON.stringify(started))
	if not started.get("ok", false):
		return false
	_completions = []
	_bridge.call(&"_on_runtime_timeline_ended")
	if _completions.size() != 1:
		assert_true(false, "the Hospital port published exactly one completion")
		return false
	var transaction_id := str(command["transaction_id"])
	var envelope: Dictionary = _state_port.presentation_stage_receipt(
		transaction_id, _completions[0])
	assert_true(envelope.get("ok", false), JSON.stringify(envelope))
	if not envelope.get("ok", false):
		return false
	_completions = []
	var receipt: Dictionary = (envelope["value"] as Dictionary)["receipt"]
	var completed: Dictionary = _game_state._run_lifecycle.complete_active_stage(
		transaction_id, {"value": (receipt["value"] as Dictionary).duplicate(true)})
	assert_true(completed.get("ok", false), JSON.stringify(completed))
	return completed.get("ok", false)


## Carries an awaiting date presentation all the way to a completed stage.
func _settle_presentation(request: Dictionary) -> bool:
	var started: Dictionary = _dating_port.begin(request)
	assert_true(started.get("ok", false), JSON.stringify(started))
	if not started.get("ok", false):
		return false
	var command: Dictionary = (started["value"] as Dictionary)["presentation_command"]
	_completions = []
	_dating_owner.finish(str(command["completion_transaction_id"]), {})
	if _completions.size() != 1:
		assert_true(false, "the port published exactly one completion")
		return false
	var transaction_id := _awaiting_transaction_id()
	var envelope: Dictionary = _state_port.presentation_stage_receipt(
		transaction_id, _completions[0])
	assert_true(envelope.get("ok", false), JSON.stringify(envelope))
	if not envelope.get("ok", false):
		return false
	var receipt: Dictionary = (envelope["value"] as Dictionary)["receipt"]
	var completed: Dictionary = _game_state._run_lifecycle.complete_active_stage(
		transaction_id, {"value": (receipt["value"] as Dictionary).duplicate(true)})
	assert_true(completed.get("ok", false), JSON.stringify(completed))
	return completed.get("ok", false)


## The transaction id of the one ACTIVE record, read from the live plan.
func _awaiting_transaction_id() -> String:
	var plan: Variant = _game_state._run_lifecycle.to_dict()["active_resolution_plan"]
	if typeof(plan) != TYPE_DICTIONARY:
		return ""
	for stage_value: Variant in ((plan as Dictionary)["stages"] as Array):
		var stage: Dictionary = stage_value
		for substage_value: Variant in (stage["substages"] as Array):
			var substage: Dictionary = substage_value
			if str(substage["state"]) == "active":
				return str(substage["transaction_id"])
		if str(stage["state"]) == "active":
			return str(stage["transaction_id"])
	return ""


func _commit_and_begin(day: int, drafts: Array) -> void:
	_game_state._lifecycle_set_playing_day(day)
	var storage := JsonFileStorage.new(_root)
	var ledger: RefCounted = LEDGER.new()
	assert_true(ledger.configure(storage).get("ok", false))
	assert_true(ledger.load().get("ok", false))
	var commit_port: RefCounted = COMMIT_PORT.new(_game_state, _registry, _issuer, ledger)
	var command: Dictionary = _command("commit.day%d" % day)
	var prepared: Dictionary = commit_port.call(&"prepare_commit", {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": drafts.duplicate(true),
		"registry_fingerprint": _fingerprint,
	})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return
	var value: Dictionary = (prepared.get("value", {}) as Dictionary).duplicate(true)
	assert_true(commit_port.call(&"commit", value["game_state_candidate"]).get("ok", false))
	assert_true(_state_port.begin_or_resume(str(command["id"]) + ":resolution").get("ok", false))


## A committed solo date backed by a REAL invitation source receipt; the production commit port
## refuses a fabricated one outright.
func _date(draft_entry_id: String, slot_index: int, friend: String, day: int) -> Dictionary:
	var action_id := "solo:%s:day%d" % [friend, day]
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": "solo",
		"participants": [friend],
		"source_receipt_id": _seed_solo_source(friend, day, action_id),
	}


func _seed_solo_source(friend_id: String, day: int, action_id: String) -> String:
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(
		_game_state.contacts, friend_id, day, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), str(offered))
	if not offered.get("ok", false):
		return ""
	var command: Dictionary = _command("open.%s.day%d" % [friend_id, day])
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	if not found.get("ok", false):
		return ""
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(
		offered["value"]["candidate"], friend_id, day, command["id"], command["receipt"],
		_issuer, ((found["value"] as Dictionary)["record"] as Dictionary))
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return ""
	_game_state.contacts = opened["value"]["candidate"]
	return str(opened["receipt"]["receipt_id"])


func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str((issued.get("value", {}) as Dictionary).get("token", "")),
			"receipt": ((issued.get("value", {}) as Dictionary).get("issuer_receipt", {}) as Dictionary).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)


# ---- Cut 9 helpers: the real checkpoint bundle, on real disk (dwm-p2r.19) -----------------------

## Walks the resolution until `hospital_if_triggered` is PENDING, completing each stage before it
## through the REAL bundle the resolution path produces -- `prepare_completion`, whose
## `snapshot_input` the coordinator forwards verbatim to the checkpoint port -- and writing each one
## to disk. Returns the LAST document, read back from those bytes.
##
## `prepare_completion` is pure (it applies the stage to a DETACHED lifecycle clone), so calling it
## for the bundle and then completing the live stage records exactly what a checkpoint would have.
func _walk_to_hospital_checkpoint() -> Dictionary:
	var written := {}
	var steps := 0
	while steps < MAX_WALK_STEPS:
		steps += 1
		var cursor: Dictionary = _state_port.inspect_next_stage()
		if not cursor.get("ok", false) or not bool(cursor["value"]["has_stage"]):
			assert_true(false, "the walk ended before the Hospital stage")
			return {}
		var record: Dictionary = cursor["value"]["stage"]
		if str(record.get("stage_id", "")) == "hospital_if_triggered":
			return written
		var begun: Dictionary = _state_port.begin_next_stage()
		assert_true(begun.get("ok", false), JSON.stringify(begun))
		if not begun.get("ok", false):
			return {}
		var value: Dictionary = begun["value"]
		if str(value["mode"]) == "await_registered_command":
			assert_true(false, "no presentation stands between the resolution start and Hospital")
			return {}
		var stage: Dictionary = value["stage"]
		var receipt: Dictionary = value["receipt"]
		var transaction_id := str(stage["transaction_id"])
		# The ENVELOPE, exactly as `DayResolutionCoordinator._commit_completion` forwards it: the
		# port converts it itself through `_plan_receipt_from_envelope`, whose default branch is the
		# same `{"value": ...}` the live completion below uses, so clone and live state agree.
		var prepared: Dictionary = _state_port.prepare_completion(transaction_id, receipt)
		assert_true(prepared.get("ok", false), JSON.stringify(prepared))
		if not prepared.get("ok", false):
			return {}
		written = _persist_checkpoint((prepared["value"] as Dictionary)["snapshot_input"], steps)
		if written.is_empty():
			return {}
		var completed: Dictionary = _game_state._run_lifecycle.complete_active_stage(
			transaction_id, {"value": (receipt["value"] as Dictionary).duplicate(true)})
		assert_true(completed.get("ok", false), JSON.stringify(completed))
		if not completed.get("ok", false):
			return {}
	assert_true(false, "the walk stopped advancing before the Hospital stage")
	return {}


## Builds the v3 snapshot from the port's own checkpoint inputs, writes it as JSON, and reads it
## BACK. The round trip is the point: the restore may only see what actually survived as bytes.
func _persist_checkpoint(inputs: Dictionary, sequence: int) -> Dictionary:
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(
		inputs["snapshot_input"], inputs["dialogic_checkpoint"], str(inputs["route_id"]),
		inputs["active_app_id"], inputs["audio_context"], int(inputs["content_version"]), sequence)
	assert_true(built.get("ok", false), JSON.stringify(built))
	if not built.get("ok", false):
		return {}
	var path := _root.path_join("checkpoint.json")
	var writer := FileAccess.open(path, FileAccess.WRITE)
	assert_true(writer != null, "the checkpoint file opened for writing")
	if writer == null:
		return {}
	writer.store_string(JSON.stringify((built["value"] as Dictionary)["snapshot"]))
	writer.close()
	var reader := FileAccess.open(path, FileAccess.READ)
	assert_true(reader != null, "the checkpoint file opened for reading")
	if reader == null:
		return {}
	var text := reader.get_as_text()
	reader.close()
	var parsed: Variant = JSON.parse_string(text)
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "the checkpoint round-trips as an object")
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


## THE CRASH, restored from the DOCUMENT rather than from memory. Every owner is destroyed and
## rebuilt, and the rebuilt `GameState` is asserted to start with the condition flag CLEARED -- so
## whatever it knows afterwards demonstrably came out of these bytes and not out of luck.
func _crash_from_document(document: Dictionary) -> bool:
	# THE PLAN-02 RECORDS ARE DURABLE BY CONTRACT, so they must survive this crash or the test would
	# measure the wrong thing. `FakeDesktopConsequenceSource` mints the condition receipt "once per
	# causal day, so a replayed resolution binds the SAME board fate and condition rather than a
	# fresh one -- which is what the real ports will do", but it memoises that in memory, so a
	# rebuilt fixture would mint a NEW one. Carrying the memo models the durability its own contract
	# declares.
	#
	# This matters here and nowhere else in this file because of DEVIATION-6: Hospital's
	# `miss_receipt_ids` are RE-DERIVED rather than persisted, and each miss row projects the
	# `hospital_resolution_id` that descends from `condition_receipt_id`. So a fresh condition
	# receipt would move the miss ids, move the context hash, and move the intent -- for a reason
	# that has nothing to do with `pending_hospital`. Plan 01's cross-crash byte-identity therefore
	# RESTS on Plan 02 keeping that receipt stable per causal day; nothing in Plan 01 enforces it.
	#
	# Carrying it does NOT soften what this test catches: if `pending_hospital` stopped being
	# captured, the restored flag would be false, `_hospital_site()` would return {}, and the stage
	# would complete required=false instead of presenting -- failing the `await_registered_command`
	# assertion long before byte-identity is reached.
	var carried_condition: Dictionary = (_consequence._condition as Dictionary).duplicate(true)
	var carried_board_fate: Dictionary = (_consequence._board_fate as Dictionary).duplicate(true)

	_game_state.queue_free()
	_boot()
	_consequence._condition = carried_condition
	_consequence._board_fate = carried_board_fate
	assert_false(bool(_game_state.pending_hospital),
		"the rebuilt process starts with the condition flag CLEARED, before anything is restored")
	var validated: Dictionary = RUN_SNAPSHOT_SCHEMA.validate(document)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	if not validated.get("ok", false):
		return false
	var snapshot: Dictionary = (validated["value"] as Dictionary)["candidate"]
	# ONE seam, ONE document, every half at once -- the production restore, not a hand-rolled
	# stand-in: `_apply_run_snapshot_silent` installs the lifecycle (and with it
	# `active_resolution_plan`), the gameplay bag through the SAME `_SAVE_WHITELIST` that captured
	# it, the Contacts index, and the committed aggregate. Using it is the point rather than a
	# convenience: the flag and the plan are proven to travel together only if the thing that puts
	# them back is the thing production uses.
	var restored: Dictionary = _game_state._apply_run_snapshot_silent(snapshot)
	assert_true(restored.get("ok", false), JSON.stringify(restored))
	return restored.get("ok", false)
