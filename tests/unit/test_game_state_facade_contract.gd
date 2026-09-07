extends "res://addons/gut/test.gd"

const GAME_STATE_PATH := "res://autoload/GameState.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const CHECKPOINT_PATH := "res://tests/support/FakeCheckpointPort.gd"
const SURFACE_PATH := "res://evidence/phase_2r/runtime/game_state_surface.json"
const DAY_ADVANCE_IDENTITY_PORT := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
const IDENTITY_ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ISSUER_ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const CRYPTO_NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const _CONTACT_INVITATION_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")

## One real issuer over this suite's sandbox root, built the way ApplicationBootstrap builds the
## production one. DWM_TEST_ROOT is supplied by tools/testing/Invoke-IsolatedGodot.ps1.
func _sandbox_identity_issuer() -> RefCounted:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	var root: String = wrapper.path_join("facade-contract-identity")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	var root_store: RefCounted = ISSUER_ROOT_STORE.new()
	assert_true(root_store.configure(STORAGE.new(root), CRYPTO_NAMESPACE_SOURCE.new()).get("ok", false),
		"root store configured")
	assert_true(root_store.load_or_create().get("ok", false), "root store initialized")
	var issuer: RefCounted = IDENTITY_ISSUER.new()
	assert_true(issuer.configure(root_store).get("ok", false), "issuer configured")
	return issuer

func _fresh_game_state() -> Node:
	var game_state: Node = load(GAME_STATE_PATH).new()
	game_state.reset_game()
	autofree(game_state)
	return game_state

func test_configure_mutation_gate_matrix_without_side_effects() -> void:
	var game_state := _fresh_game_state()
	var emissions: Array[Dictionary] = []
	var gate: RefCounted = load(GATE_PATH).new()
	gate.capability_changed.connect(func(capability: Dictionary) -> void: emissions.append(capability))
	assert_eq(game_state.configure_mutation_gate(null).get("code"), &"invalid_mutation_gate")
	assert_eq(game_state.configure_mutation_gate(RefCounted.new()).get("code"), &"invalid_mutation_gate")
	var configured: Dictionary = game_state.configure_mutation_gate(gate)
	assert_true(configured["ok"], JSON.stringify(configured))
	assert_eq(configured["value"]["gate_instance_id"], gate.get_instance_id())
	assert_eq(configured["value"]["already_configured"], false)
	assert_eq(configured["receipt"], {})
	var repeat: Dictionary = game_state.configure_mutation_gate(gate)
	assert_true(repeat["ok"], "identical instance is idempotent")
	assert_eq(repeat["value"]["already_configured"], true)
	assert_eq(game_state.configure_mutation_gate(load(GATE_PATH).new()).get("code"),
		&"mutation_gate_already_configured", "replacement rejects")
	assert_eq(emissions.size(), 0, "configuration performs no signal emission")
	assert_false(gate.is_active(), "configuration never mutates the gate")
	assert_eq(game_state.day, 1, "configuration never mutates run state")

func test_day_is_read_only_compatibility() -> void:
	var game_state := _fresh_game_state()
	assert_eq(game_state.day, 1, "day reads from the lifecycle")
	game_state._lifecycle_set_playing_day(5)
	assert_eq(game_state.day, 5, "day changes only through lifecycle commands")
	assert_true(FileAccess.file_exists(SURFACE_PATH), "surface inventory must exist")
	if not FileAccess.file_exists(SURFACE_PATH):
		return
	var parsed := StrictJson.parse_object(FileAccess.get_file_as_string(SURFACE_PATH))
	assert_true(parsed.get("ok", false))
	var day_record: Dictionary = {}
	for record: Dictionary in parsed["value"]["records"]:
		if str(record.get("symbol", "")) == "day":
			day_record = record
	assert_eq(str(day_record.get("disposition", "")), "replace",
		"the inventory reports every direct day-assignment caller for migration")
	assert_true(str(day_record.get("contract_test", "")).length() > 0)

## Plan 02 Task 6 (dwm-p2r.32): branch_id/desktop_timeline_generation/causal_day_instance/receipt
## arrive already durably allocated in production; this test supplies a self-consistent placeholder.
func _new_run_receipt(token: String) -> Dictionary:
	return {"receipt_id": "issuer_receipt.fixture-" + token, "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": token, "numeric_value": null}

func test_prepare_new_run_snapshot_input_is_pure() -> void:
	var game_state := _fresh_game_state()
	game_state._lifecycle_set_playing_day(4)
	game_state.money = 55
	var live_before: Dictionary = game_state.to_save_dict()
	var receipt := _new_run_receipt("causal-day-b")
	assert_false(game_state.prepare_new_run_snapshot_input("", "branch-b", 0, "causal-day-b", receipt, false).get("ok", true),
		"empty run id rejects")
	assert_false(game_state.prepare_new_run_snapshot_input("run-local", "branch-b", 0, "causal-day-b", receipt, false).get("ok", true),
		"reused run id rejects")
	var prepared: Dictionary = game_state.prepare_new_run_snapshot_input("run-b", "branch-b", 0, "causal-day-b", receipt, false)
	assert_true(prepared["ok"], JSON.stringify(prepared))
	var snapshot_input: Dictionary = prepared["value"]["snapshot_input"]
	assert_eq(snapshot_input["lifecycle"], {
		"run_id": "run-b", "dark_mode": false, "day": 1, "state": "PLAYING",
		"active_resolution_plan": null, "ending_plan": null,
		"branch_id": "branch-b", "desktop_timeline_generation": 0,
		"causal_day_instance": "causal-day-b", "causal_day_instance_issuer_receipt": receipt,
		"restore_provenance": null,
	})
	assert_eq(snapshot_input["desktop"]["board"]["phase"], "NONE", "a fresh run has no board yet")
	assert_eq(snapshot_input["desktop"]["consequence"]["pending"], null, "a fresh run has no pending consequence")
	# Shape matches RunSnapshotSchema.build: gameplay bag plus own contacts/schedule/dating/ledgers.
	assert_eq(int(snapshot_input["gameplay"]["money"]), 0, "detached defaults are the reset values")
	assert_eq(snapshot_input["gameplay"]["narrative_variables"], {}, "gameplay carries the narrative bag")
	# Fresh run carries a valid empty stateless contacts bag (dwm-p2r.6), not a bare {}.
	assert_eq(int(snapshot_input["contacts"]["next_sequence"]), 1, "fresh run has default contacts bag")
	assert_eq((snapshot_input["contacts"]["messages"]["priscilla"] as Array).size(), 0, "no invitations yet")
	assert_eq(snapshot_input["committed_schedule"], {
		"schema_version": 1, "day": 1, "registry_fingerprint": null,
		"entries": [], "commit_receipt": null,
	}, "fresh run carries the canonical empty aggregate with no registry fingerprint")
	assert_eq(snapshot_input["dating"], {}, "fresh run has empty dating")
	assert_eq(snapshot_input["applied_effect_transaction_ids"], [], "empty run-scoped ledgers")
	assert_eq(snapshot_input["applied_variable_transaction_ids"], [], "empty run-scoped ledgers")
	assert_false(snapshot_input["gameplay"].has("day"), "day lives in the lifecycle, not the gameplay bag")
	assert_eq(game_state.to_save_dict(), live_before, "live run state is untouched")
	assert_eq(game_state.day, 4, "live day is untouched")

func test_request_schedule_done_delegates_through_production_port() -> void:
	var game_state := _fresh_game_state()
	assert_eq(game_state.request_schedule_done("done:day-1").get("code"),
		&"day_resolution_unconfigured", "unconfigured facade rejects")
	var gate: RefCounted = load(GATE_PATH).new()
	assert_true(game_state.configure_mutation_gate(gate)["ok"])
	var calls: Array[String] = []
	var checkpoint: RefCounted = load(CHECKPOINT_PATH).new(calls)
	checkpoint.seed_empty("run-local")
	# Bootstrap-owned construction, GameState-owned installation (Plan 01 Task 6 Step 6.5,
	# dwm-p2r.13). The facade no longer builds its own coordinator or state port, so this test wires
	# them the way ApplicationBootstrap does and hands them in as direct arguments.
	var state_port: RefCounted = load("res://scripts/application/run/GameStateDayResolutionPort.gd").new(game_state)
	var coordinator: RefCounted = load("res://scripts/application/run/DayResolutionCoordinator.gd").new()
	assert_true(coordinator.configure(state_port, checkpoint, gate)["ok"])
	# The separate Task-7 seam (Plan 01 Step 7.3a, dwm-p2r.14): since d5a0f3e9 a Days 1-6 walk
	# cannot pass increment_day without the one shared root-atomic CausalDayAdvanceIdentityPort, so
	# this contract wires it exactly as ApplicationBootstrap._configure_causal_day_advance_identity
	# does -- a real issuer over a GUID-isolated sandbox root, never user://.
	var day_advance_port: RefCounted = DAY_ADVANCE_IDENTITY_PORT.new()
	assert_true(day_advance_port.configure(_sandbox_identity_issuer()).get("ok", false),
		"advance identity port bound to a real issuer")
	assert_true(coordinator.configure_day_advance_identity_port(day_advance_port).get("ok", false),
		"advance identity port injected through the separate seam")
	assert_eq(game_state._install_day_resolution_runtime(state_port, coordinator, checkpoint, gate),
		{"ok": true, "code": &"ok", "value": {"installed": true}, "receipt": {}},
		"the install seam returns only the exact primitive envelope")
	var day_signals: Array[int] = []
	game_state.day_changed.connect(func(new_day: int) -> void: day_signals.append(new_day))
	var result: Dictionary = game_state.request_schedule_done("done:day-1")
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["code"], &"plan_complete")
	assert_eq(game_state.day, 2, "the production Schedule Done path advanced the day once")
	assert_true(day_signals.size() > 0, "publications emit committed state through declared signals")
	var resumed: Dictionary = game_state.resume_day_resolution()
	assert_true(resumed.get("ok", false), "resume exposes coordinator results")
	assert_eq(resumed["code"], &"plan_complete")

const TASK4_SCHEDULE_SEAMS: Array[String] = [
	"capture_schedule_commit_state", "prepare_schedule_commit_candidate",
	"commit_schedule_commit_candidate", "rollback_schedule_commit_state",
	"publish_schedule_commit",
]

# Plan 01 Task 4 (dwm-p2r.13): these five seams are facade DELEGATION only. They cover current
# motivation, the canonical committed_schedule and the narrow precondition fingerprint; they are not
# a second validator, and GameStateScheduleCommitPort keeps the public transaction interface.
func test_schedule_commit_seams_are_narrow_reversible_and_silent() -> void:
	var game_state := _fresh_game_state()
	var absent: Array[String] = []
	for seam: String in TASK4_SCHEDULE_SEAMS:
		if not game_state.has_method(seam):
			absent.append(seam)
	assert_eq(absent, [] as Array[String], "the narrow committed-Schedule seams must exist")
	if not absent.is_empty():
		return
	var emissions: Array[String] = []
	for entry: Dictionary in game_state.get_script().get_script_signal_list():
		var signal_name := str(entry.get("name", ""))
		if (entry.get("args", []) as Array).size() == 0:
			game_state.connect(signal_name, func() -> void: emissions.append(signal_name))
		elif (entry.get("args", []) as Array).size() == 1:
			game_state.connect(signal_name, func(_a) -> void: emissions.append(signal_name))

	var captured: Dictionary = game_state.capture_schedule_commit_state()
	assert_true(captured["ok"], JSON.stringify(captured))
	var captured_keys: Array = (captured["value"] as Dictionary).keys()
	captured_keys.sort()
	assert_eq(captured_keys, ["before_fingerprint", "committed_schedule", "motivation"],
		"the capture seam is exactly narrow")
	var aggregate: Dictionary = captured["value"]["committed_schedule"]
	assert_eq(aggregate, {
		"schema_version": 1, "day": 1, "registry_fingerprint": null,
		"entries": [], "commit_receipt": null,
	}, "an uninitialized owner exposes the canonical empty aggregate for its day")
	assert_eq(int(captured["value"]["motivation"]), 7)

	var prepared: Dictionary = game_state.prepare_schedule_commit_candidate(aggregate, 2)
	assert_true(prepared["ok"], JSON.stringify(prepared))
	assert_eq(int(prepared["value"]["candidate"]["motivation"]), 5, "the candidate carries the charge")
	assert_eq(game_state.get_stat("motivation"), 7, "prepare applies nothing")
	assert_false(game_state.prepare_schedule_commit_candidate(aggregate, 8).get("ok", true),
		"the owner refuses a charge it cannot pay")
	assert_false(game_state.prepare_schedule_commit_candidate(aggregate, -1).get("ok", true))
	assert_false(game_state.prepare_schedule_commit_candidate({}, 0).get("ok", true),
		"the seam validates the canonical aggregate it is handed")
	assert_eq(emissions, [] as Array[String], "capture and prepare are silent")

	var committed: Dictionary = game_state.commit_schedule_commit_candidate(prepared["value"]["candidate"])
	assert_true(committed["ok"], JSON.stringify(committed))
	assert_eq(game_state.get_stat("motivation"), 5, "commit changes motivation")
	assert_eq(game_state.capture_schedule_commit_state()["value"]["committed_schedule"], aggregate)
	assert_eq(emissions, [] as Array[String], "commit installs the candidate silently")
	assert_false(game_state.commit_schedule_commit_candidate(prepared["value"]["candidate"]).get("ok", true),
		"a candidate prepared against a stale precondition fingerprint is refused")

	var restored: Dictionary = game_state.rollback_schedule_commit_state({
		"motivation": 7, "committed_schedule": aggregate,
	})
	assert_true(restored["ok"], JSON.stringify(restored))
	assert_eq(restored["value"], {"restored": true})
	assert_eq(game_state.get_stat("motivation"), 7, "rollback restores exactly the backup")
	assert_eq(emissions, [] as Array[String], "rollback is silent")
	assert_false(game_state.rollback_schedule_commit_state({"motivation": 7}).get("ok", true),
		"the backup member set is exact")

	assert_false(game_state.publish_schedule_commit({
		"committed_schedule": aggregate, "schedule_commit_receipt": null,
	}).get("ok", true), "a publication without its commit receipt is refused")
	assert_false(game_state.publish_schedule_commit({
		"committed_schedule": {"schema_version": 1, "day": 2, "registry_fingerprint": null,
			"entries": [], "commit_receipt": null},
		"schedule_commit_receipt": {},
	}).get("ok", true), "a publication the owner does not hold is refused")
	assert_eq(emissions, [] as Array[String], "a refused publication emits nothing")

func test_day7_terminal_via_facade_never_creates_day8() -> void:
	var game_state := _fresh_game_state()
	game_state._lifecycle_set_playing_day(7)
	var resolved: Dictionary = game_state.resolve_day7_ending()
	assert_true(resolved.get("ok", false), JSON.stringify(resolved))
	assert_eq(game_state.day, 7, "no Day 8 exists on any runtime path")
	assert_eq(game_state._run_lifecycle.get_state(), &"ENDING")
	var legacy_eight: Dictionary = {"day": 8, "route_context": {"ending_id": "ending.alone", "epilogue_ending_id": ""}}
	var applied: Dictionary = game_state.apply_save_dict(legacy_eight)
	assert_true(applied.get("ok", false))
	assert_eq(game_state.day, 7, "a legacy Day-8 sentinel migrates to the Day-7 terminal")
	assert_eq(game_state._run_lifecycle.get_state(), &"ENDING")


# ---- Task 3 (Amendment Plan 03, dwm-oyo.3): the read-only Schedule-warning capture ----

const WARNING_STATE_KEYS: Array = [
	"accepted_date_action_ids", "base_opportunity_remaining", "branch_id",
	"causal_day_instance", "day", "desktop_timeline_generation",
	"eligible_unread_date_message_ids", "motivation", "next_app_round_ordinal", "run_id",
]

func test_capture_schedule_warning_state_is_narrow_read_only_and_exact() -> void:
	var game_state := _fresh_game_state()
	var live_before: Dictionary = game_state.to_save_dict()
	var captured: Dictionary = game_state.capture_schedule_warning_state()
	assert_true(captured.get("ok", false), JSON.stringify(captured))
	var envelope_keys: Array = captured.keys()
	envelope_keys.sort()
	assert_eq(envelope_keys, ["code", "ok", "receipt", "value"], "the master envelope")
	assert_eq(captured.get("receipt", {"x": 1}), {}, "a read issues no receipt")
	var value_keys: Array = (captured.get("value", {}) as Dictionary).keys()
	assert_eq(value_keys, ["state"], "the value is exactly {state}")
	var state: Dictionary = (captured.get("value", {}) as Dictionary).get("state", {})
	var state_keys: Array = state.keys()
	state_keys.sort()
	assert_eq(state_keys, WARNING_STATE_KEYS, "the exact ten-member warning state")
	assert_eq(int(state.get("day", -1)), game_state.day, "day is the lifecycle's")
	assert_eq(int(state.get("motivation", -1)), 7, "motivation is the canonical stat")
	assert_eq(state.get("eligible_unread_date_message_ids", ["x"]), [],
		"a fresh run has no unread date-enabling message")
	assert_eq(state.get("accepted_date_action_ids", ["x"]), [],
		"a fresh run has no acceptance")
	var ordinal: Variant = state.get("next_app_round_ordinal", -1)
	assert_true(ordinal == null or (typeof(ordinal) == TYPE_INT
		and int(ordinal) >= 1 and int(ordinal) <= 5),
		"next_app_round_ordinal is 1..5 or null, null only after exhaustion")
	assert_true(typeof(state.get("base_opportunity_remaining", "x")) == TYPE_BOOL,
		"base_opportunity_remaining is a strict bool")
	assert_eq(game_state.to_save_dict(), live_before, "the capture mutates nothing")


func test_capture_schedule_warning_state_facts_are_day_scoped_and_detached() -> void:
	var game_state := _fresh_game_state()
	var offered_b: Dictionary = _CONTACT_INVITATION_STATE.prepare_offer_solo(
		game_state.contacts, "sylvia", 1, "msg:s1", "tx:offer:s1")
	assert_true(offered_b.get("ok", false), JSON.stringify(offered_b))
	game_state.contacts = (offered_b.get("value", {}) as Dictionary).get("candidate", {})
	var offered_a: Dictionary = _CONTACT_INVITATION_STATE.prepare_offer_solo(
		game_state.contacts, "priscilla", 1, "msg:p1", "tx:offer:p1")
	assert_true(offered_a.get("ok", false), JSON.stringify(offered_a))
	game_state.contacts = (offered_a.get("value", {}) as Dictionary).get("candidate", {})
	var offered_far: Dictionary = _CONTACT_INVITATION_STATE.prepare_offer_solo(
		game_state.contacts, "lavinia", 2, "msg:l2", "tx:offer:l2")
	assert_true(offered_far.get("ok", false), JSON.stringify(offered_far))
	game_state.contacts = (offered_far.get("value", {}) as Dictionary).get("candidate", {})
	var captured: Dictionary = game_state.capture_schedule_warning_state()
	assert_true(captured.get("ok", false), JSON.stringify(captured))
	var state: Dictionary = (captured.get("value", {}) as Dictionary).get("state", {})
	assert_eq(state.get("eligible_unread_date_message_ids", []), ["msg:p1", "msg:s1"],
		"unread current-day offers, sorted and unique; another day's offer is excluded")
	(state.get("eligible_unread_date_message_ids", []) as Array).clear()
	var recaptured: Dictionary = game_state.capture_schedule_warning_state()
	assert_eq(((recaptured.get("value", {}) as Dictionary).get("state", {})
		as Dictionary).get("eligible_unread_date_message_ids", []), ["msg:p1", "msg:s1"],
		"the returned arrays are detached canonical facts")
