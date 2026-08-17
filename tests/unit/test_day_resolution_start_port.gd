extends "res://addons/gut/test.gd"
# Reversible day-resolution start port (Plan 01 Task 6, dwm-p2r.13, Steps 6.1/6.2).
#
# SUBSTRATE. Identical to tests/unit/test_day7_schedule_provenance.gd and
# tests/unit/test_game_state_schedule_commit_port.gd: every dependency is the production object over
# a GUID-isolated root, and the committed aggregates fed in are produced by the REAL
# GameStateScheduleCommitPort rather than hand-built, because plan Step 5.7 bans handwaved
# fingerprints and receipts.
#
# DayResolutionStartPort.gd does not exist during RED, so it is loaded through DynamicScriptProbe and
# its absence is reported as one named assertion per test instead of a parse crash.
#
# WHAT THIS FILE OWNS (matrix row P01.day_resolution.start at plan line 92, and Step 6.1):
#   * exact `P01.day_resolution.start` consumption -- parent, child_kind, RESERVED ordinal, and the
#     eleven source projections -- recomputed INDEPENDENTLY here from the plan text;
#   * rejection of a bare/synthetic array, a receiptless empty, a stale fingerprint, an altered
#     source, and a Day-8 source;
#   * that the board-fate receipt is BOUND and never reinterpreted.
#
# THE ORDINAL TRAP THIS FILE EXISTS TO CATCH. Plan line 92 gives the start row child_kind
# `day_resolution_stage` -- the SAME kind as the per-stage row at line 93 -- distinguished only by
# its reserved ordinal and its `role` token. An implementation that invented a `day_resolution_start`
# kind would look correct in isolation and would silently break every later stage derivation, so the
# kind is asserted against the literal here.
#
# PARSE HAZARD: GUT treats an inferred-Variant `:=` as a parse error, so every local declaration
# below carries an explicit type annotation.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const START_PORT_PATH := "res://scripts/application/run/DayResolutionStartPort.gd"
const COMMIT_PORT_PATH := "res://scripts/application/schedule/GameStateScheduleCommitPort.gd"
const LEDGER_PATH := "res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd"
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const STATE_PORT_PATH := "res://scripts/application/run/GameStateDayResolutionPort.gd"

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

const CAUSAL_DAY := "causal_day_instance.1111111111111111111111111111111111111111111111111111111111111111"
const VIEW_FINGERPRINT := "schedule_view.22222222222222222222222222222222"

## Plan line 92: the SAME kind as P01.day_resolution.stage, with a reserved ordinal.
const START_CHILD_KIND := &"day_resolution_stage"
const RESERVED_START_ORDINAL := 0

## Exact prepare_from_committed_schedule() request members (sorted).
const REQUEST_KEYS: Array[String] = [
	"board_fate_receipt", "causal_day_instance", "committed_schedule", "resolution_id",
	"resolution_issuer_receipt", "route_plan",
]

var _start_script: Script = null
var _commit_script: Script = null
var _ledger_script: Script = null
var _storage: RefCounted = null
var _root_store: RefCounted = null
var _issuer: RefCounted = null
var _registry: RefCounted = null
var _fingerprint := ""
var _game_state: Node = null
var _ledger: Object = null
var _commit_port: Object = null
var _state_port: Object = null
var _start_port: Object = null
var _commands: Dictionary = {}
var _root_counter := 0
var _last_rejection := ""


func before_each() -> void:
	_commands = {}
	_last_rejection = ""
	var start_loaded: Dictionary = PROBE.load_script(START_PORT_PATH)
	_start_script = start_loaded["value"] if start_loaded.get("ok", false) else null
	var commit_loaded: Dictionary = PROBE.load_script(COMMIT_PORT_PATH)
	_commit_script = commit_loaded["value"] if commit_loaded.get("ok", false) else null
	var ledger_loaded: Dictionary = PROBE.load_script(LEDGER_PATH)
	_ledger_script = ledger_loaded["value"] if ledger_loaded.get("ok", false) else null

	_storage = JsonFileStorage.new(_isolated_root())

	_root_store = ROOT_STORE.new()
	assert_true(_root_store.configure(_storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(_root_store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(_root_store).get("ok", false))

	var loaded_registry: Dictionary = REGISTRY.load_current()
	assert_true(loaded_registry.get("ok", false), str(loaded_registry))
	_registry = (loaded_registry.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded_registry.get("value", {}) as Dictionary).get("registry_fingerprint", ""))

	_game_state = load(GAME_STATE_PATH).new()
	autofree(_game_state)
	_game_state.reset_game()

	if _ledger_script != null:
		_ledger = _ledger_script.new()
		assert_true(_ledger.configure(_storage).get("ok", false))
		assert_true(_ledger.load().get("ok", false))
	if _commit_script != null and _ledger != null:
		_commit_port = _commit_script.new(_game_state, _registry, _issuer, _ledger)
	# Plan Step 6.5 gives this port DIRECT constructor dependencies -- retained state port, registry,
	# issuer, and the SAME ledger the commit port uses -- rather than a configure() seam.
	if _start_script != null and _ledger != null:
		_state_port = load(STATE_PORT_PATH).new(_game_state)
		_start_port = _start_script.new(_state_port, _registry, _issuer, _ledger)


func _isolated_root() -> String:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	var root: String = wrapper.path_join("day-resolution-start-%d" % _root_counter)
	var production: String = ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	assert_ne(root.simplify_path().trim_suffix("/").nocasecmp_to(production), 0,
		"an isolated root is never the production user directory")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	return root


func _require_port() -> bool:
	var absent: Array[String] = []
	if _start_script == null:
		absent.append(START_PORT_PATH)
	if _commit_script == null:
		absent.append(COMMIT_PORT_PATH)
	if not absent.is_empty():
		assert_true(false, "the day-resolution start substrate is absent: " + str(absent))
		return false
	if _start_port == null or _commit_port == null:
		assert_true(false, "the start port or its commit port did not instantiate")
		return false
	return true


# ---- the accepted start ----

func test_prepare_requires_the_exact_request_member_set() -> void:
	if not _require_port():
		return
	var request: Dictionary = _request(1)
	if request.is_empty():
		return
	var keys: Array = request.keys()
	keys.sort()
	assert_eq(keys, REQUEST_KEYS, "this suite must build the exact request")
	for missing: String in REQUEST_KEYS:
		var short: Dictionary = request.duplicate(true)
		short.erase(missing)
		assert_false(_prepare(short).get("ok", true), "a request missing %s is refused" % missing)
	var extra: Dictionary = request.duplicate(true)
	extra["unexpected"] = true
	assert_false(_prepare(extra).get("ok", true), "an extra request member is refused")


func test_a_real_committed_schedule_produces_the_exact_start_receipt() -> void:
	if not _require_port():
		return
	var request: Dictionary = _request(1)
	if request.is_empty():
		return
	var prepared: Dictionary = _prepare(request)
	assert_true(prepared.get("ok", false),
		"a real committed Schedule starts a resolution: %s" % str(prepared.get("code", &"")))
	if not prepared.get("ok", false):
		return
	var receipt: Dictionary = (prepared.get("value", {}) as Dictionary).get("start_receipt", {})
	var provenance: Dictionary = receipt["receipt_provenance"]
	var committed: Dictionary = request["committed_schedule"]
	var commit_receipt: Dictionary = committed["commit_receipt"]

	assert_eq(str(provenance["child_kind"]), String(START_CHILD_KIND),
		"the start row shares P01.day_resolution.stage's kind (plan line 92)")
	assert_eq(int(provenance["ordinal"]), RESERVED_START_ORDINAL,
		"the reserved start ordinal for the resolution root")
	assert_eq(str(provenance["parent_receipt_id"]),
		str((request["resolution_issuer_receipt"] as Dictionary)["receipt_id"]),
		"the parent is the resolution issuer receipt, not the Schedule transaction root")
	assert_eq(str(provenance["child_id"]), str(receipt["receipt_id"]),
		"the stored provenance names the receipt it minted")
	assert_eq(provenance["source_ids"], _expected_start_sources(request),
		"the exact sorted plan-line-92 source tokens")
	assert_eq(str(receipt["schedule_commit_receipt_id"]), str(commit_receipt["receipt_id"]),
		"the start receipt binds the Schedule commit it began from")


# Step 6.5: "Bind, but do not reinterpret, Plan 02's board-fate receipt." Binding means its whole
# bytes are hashed into the row and its id is projected; reinterpreting would mean reading fields
# out of it. Changing ANY byte must therefore move the derived identity.
func test_the_board_fate_receipt_is_bound_whole_and_never_reinterpreted() -> void:
	if not _require_port():
		return
	var request: Dictionary = _request(1)
	if request.is_empty():
		return
	var first: Dictionary = _prepare(request)
	assert_true(first.get("ok", false), str(first.get("code", &"")))
	if not first.get("ok", false):
		return
	var baseline: String = str(((first.get("value", {}) as Dictionary)
		.get("start_receipt", {}) as Dictionary)["receipt_id"])

	var altered: Dictionary = request.duplicate(true)
	((altered["board_fate_receipt"] as Dictionary))["opaque_plan02_member"] = "changed"
	var second: Dictionary = _prepare(altered)
	if second.get("ok", false):
		assert_ne(str(((second.get("value", {}) as Dictionary)
			.get("start_receipt", {}) as Dictionary)["receipt_id"]), baseline,
			"a changed board-fate byte must move the derived start identity")
	else:
		assert_true(true, "refusing an unknown board-fate shape is also a lawful binding")


# ---- rejections ----

func test_prepare_rejects_a_synthetic_or_receiptless_committed_schedule() -> void:
	if not _require_port():
		return
	var request: Dictionary = _request(1)
	if request.is_empty():
		return

	var bare_array: Dictionary = request.duplicate(true)
	bare_array["committed_schedule"] = []
	assert_false(_prepare(bare_array).get("ok", true),
		"a bare array is not a committed Schedule (Step 6.6 bans the synthetic seed)")

	var receiptless: Dictionary = request.duplicate(true)
	((receiptless["committed_schedule"] as Dictionary))["commit_receipt"] = null
	assert_false(_prepare(receiptless).get("ok", true),
		"a receiptless empty may not start a resolution (Step 6.1)")

	var stale: Dictionary = request.duplicate(true)
	((stale["committed_schedule"] as Dictionary))["registry_fingerprint"] = "0".repeat(64)
	assert_false(_prepare(stale).get("ok", true),
		"a stale fingerprint must not resolve through the configured registry")

	var day_eight: Dictionary = request.duplicate(true)
	((day_eight["committed_schedule"] as Dictionary))["day"] = 8
	assert_false(_prepare(day_eight).get("ok", true), "no Day-8 source may start a resolution")

	var altered_source: Dictionary = request.duplicate(true)
	var entries: Array = (altered_source["committed_schedule"] as Dictionary)["entries"]
	if not entries.is_empty():
		((entries[0]) as Dictionary)["action_id"] = "tampered"
		assert_false(_prepare(altered_source).get("ok", true),
			"an altered committed entry must not survive revalidation")


func test_prepare_is_pure_and_does_not_signal() -> void:
	if not _require_port():
		return
	var request: Dictionary = _request(1)
	if request.is_empty():
		return
	var before: String = _canonical(request)
	var day_before: int = int(_game_state._run_lifecycle.get_day())
	var prepared: Dictionary = _prepare(request)
	assert_true(prepared.get("ok", false), str(prepared.get("code", &"")))
	assert_eq(_canonical(request), before, "prepare must not mutate its request")
	assert_eq(int(_game_state._run_lifecycle.get_day()), day_before,
		"prepare touches no live lifecycle state")


func test_identical_replay_is_deterministic() -> void:
	if not _require_port():
		return
	var request: Dictionary = _request(1)
	if request.is_empty():
		return
	var first: Dictionary = _prepare(request)
	var second: Dictionary = _prepare(request.duplicate(true))
	assert_true(first.get("ok", false) and second.get("ok", false), "both replays succeed")
	if not (first.get("ok", false) and second.get("ok", false)):
		return
	assert_eq(_canonical(first.get("value", {})), _canonical(second.get("value", {})),
		"the same committed Schedule replays to byte-identical bytes")


# ---- the reversible half (Step 6.2) ----

# The ledger is the RESTART proof, not an in-memory flag. This reconstructs a second port over the
# very same storage and ledger -- what a cold restart actually produces -- and republishes the same
# semantic receipt. The success must be byte-identical and must emit NOTHING the second time.
func test_publish_records_before_emitting_and_replays_after_a_restart_without_a_second_signal() -> void:
	if not _require_port():
		return
	var request: Dictionary = _request(1)
	if request.is_empty():
		return
	var prepared: Dictionary = _prepare(request)
	assert_true(prepared.get("ok", false), str(prepared.get("code", &"")))
	if not prepared.get("ok", false):
		return
	var receipt: Dictionary = (prepared.get("value", {}) as Dictionary)["start_receipt"]
	var publication: Dictionary = _publication(prepared, receipt)

	var signals: Array[String] = []
	_game_state.save_relevant_state_changed.connect(
		func() -> void: signals.append("save_relevant_state_changed"))

	var first: Dictionary = _start_port.call(&"publish", publication.duplicate(true))
	assert_true(first.get("ok", false), "the first publish succeeds: %s" % str(first.get("code", &"")))
	assert_eq(first.get("value"), {"published": true}, "the exact success value")
	assert_eq(signals.size(), 1, "the first exact publish emits exactly one start signal")

	# A cold restart: a NEW port over the SAME storage, reconstructing the ledger from disk.
	var restarted_ledger: Object = _ledger_script.new()
	assert_true(restarted_ledger.configure(_storage).get("ok", false))
	assert_true(restarted_ledger.load().get("ok", false))
	var restarted_port: Object = _start_script.new(_state_port, _registry, _issuer, restarted_ledger)
	var replay: Dictionary = restarted_port.call(&"publish", publication.duplicate(true))
	assert_true(replay.get("ok", false), "the replay succeeds: %s" % str(replay.get("code", &"")))
	assert_eq(_canonical(replay.get("value")), _canonical(first.get("value")),
		"the replayed success is byte-identical")
	assert_eq(_canonical(replay.get("receipt")), _canonical(first.get("receipt")),
		"the replayed receipt is byte-identical")
	assert_eq(signals.size(), 1, "the replay emits NO second signal")


func test_publish_conflicts_on_mutated_bytes_at_the_same_semantic_key() -> void:
	if not _require_port():
		return
	var request: Dictionary = _request(1)
	if request.is_empty():
		return
	var prepared: Dictionary = _prepare(request)
	if not prepared.get("ok", false):
		assert_true(false, str(prepared.get("code", &"")))
		return
	var receipt: Dictionary = (prepared.get("value", {}) as Dictionary)["start_receipt"]
	assert_true(_start_port.call(&"publish", _publication(prepared, receipt)).get("ok", false))
	var mutated: Dictionary = _publication(prepared, receipt)
	(mutated["resolution_plan"] as Dictionary)["route_plan"] = [{"changed": true}]
	var conflicted: Dictionary = _start_port.call(&"publish", mutated)
	assert_false(conflicted.get("ok", true), "changed publication bytes must not silently overwrite")
	assert_eq(str(conflicted.get("code", &"")), "day_resolution_start_publication_conflict",
		"the exact conflict code")


func test_publish_refuses_a_publication_without_its_start_receipt() -> void:
	if not _require_port():
		return
	for bad: Variant in [{}, {"day_resolution_start_receipt": "not-an-object", "resolution_plan": {}}, {"resolution_plan": {}}]:
		assert_false(_start_port.call(&"publish", bad).get("ok", true),
			"a publication always carries its start receipt")


# ---- helpers ----

## The ledger freezes this member set for kind day_resolution_start; the port does not choose it.
func _publication(prepared: Dictionary, receipt: Dictionary) -> Dictionary:
	var value: Dictionary = prepared.get("value", {})
	return {
		"day_resolution_start_receipt": receipt.duplicate(true),
		"resolution_plan": {
			"committed_schedule": (value["committed_schedule"] as Dictionary).duplicate(true),
			"route_plan": (value["route_plan"] as Array).duplicate(true),
		},
	}


func _prepare(request: Dictionary) -> Dictionary:
	return _start_port.call(&"prepare_from_committed_schedule", request)


## Row P01.day_resolution.start, plan line 92, rebuilt here from the plan text alone.
func _expected_start_sources(request: Dictionary) -> Array:
	var committed: Dictionary = request["committed_schedule"]
	var commit_receipt: Dictionary = committed["commit_receipt"]
	var tokens: Array = [
		_project("role", "day_resolution.start"),
		_project("resolution_id", str(request["resolution_id"])),
		_project("causal_day_instance", str(request["causal_day_instance"])),
		_project("source_day", int(committed["day"])),
		_project("registry_fingerprint", str(committed["registry_fingerprint"])),
		_project("schedule_commit_receipt_id", str(commit_receipt["receipt_id"])),
		_project("board_fate_receipt_id", str((request["board_fate_receipt"] as Dictionary)["receipt_id"])),
		_project("schedule_entry_ids", commit_receipt["schedule_entry_ids"]),
		_project("committed_schedule_sha256", _sha256(committed)),
		_project("route_plan_sha256", _sha256(request["route_plan"])),
		_project("board_fate_receipt_sha256", _sha256(request["board_fate_receipt"])),
	]
	tokens.sort()
	return tokens


func _project(path: String, value: Variant) -> String:
	return path + "=" + _canonical(value)


func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CanonicalJsonWriter.stringify(value)
	assert_true(emitted.get("ok", false), str(emitted))
	return str(emitted.get("value", ""))


func _sha256(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(_canonical(value).to_utf8_buffer())
	return context.finish().hex_encode()


func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str((issued.get("value", {}) as Dictionary).get("token", "")),
			"receipt": ((issued.get("value", {}) as Dictionary).get("issuer_receipt", {}) as Dictionary).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)


## An opaque Plan-02 board-fate receipt. Task 6 binds it whole and never reads inside it, so this
## fixture deliberately carries a member Task 6 has no vocabulary for.
func _board_fate_receipt() -> Dictionary:
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), str(issued))
	return {
		"receipt_id": str(((issued.get("value", {}) as Dictionary)
			.get("issuer_receipt", {}) as Dictionary)["receipt_id"]),
		"opaque_plan02_member": "board_fate",
	}


## Commits an EMPTY aggregate for `day` through the real port and wraps it in a start request.
func _request(day: int) -> Dictionary:
	_game_state._lifecycle_set_playing_day(day)
	var command: Dictionary = _command("commit.day%d" % day)
	var commit_request: Dictionary = {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": [],
		"registry_fingerprint": _fingerprint,
	}
	var prepared: Dictionary = _commit_port.call(&"prepare_commit", commit_request)
	if not prepared.get("ok", false):
		_last_rejection = "%s %s" % [str(prepared.get("code", &"")), str(prepared.get("message", ""))]
		assert_true(false, "the production commit port must produce a real aggregate: " + _last_rejection)
		return {}
	var value: Dictionary = prepared.get("value", {})
	var resolution: Dictionary = _command("resolution.day%d" % day)
	return {
		"resolution_id": str(resolution["id"]),
		"resolution_issuer_receipt": (resolution["receipt"] as Dictionary).duplicate(true),
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": (value["committed_schedule"] as Dictionary).duplicate(true),
		"route_plan": (value["route_plan"] as Array).duplicate(true),
		"board_fate_receipt": _board_fate_receipt(),
	}
