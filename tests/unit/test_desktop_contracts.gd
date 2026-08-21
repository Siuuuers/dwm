extends "res://addons/gut/test.gd"

# Task 2 registry/host/identity contract suite (Plan 02 Task 2, dwm-p2r.32.1).
#
# CONCERN (full detail in .superpowers/sdd/task-2-report.md): DesktopAppRegistry.gd and
# DesktopAppHostState.gd were delivered under the closed dwm-p2r.9 bead with their own suites
# (test_desktop_app_registry.gd, test_desktop_app_host_state.gd) and this task is scoped to
# read-not-edit them. Their actual public surface diverges from the interfaces this brief
# declares:
#   * DesktopAppRegistry's four methods are INSTANCE methods (call via .new()), not the
#     `static func` the brief declares -- the verbatim `DesktopAppRegistry.get_ids()` call does
#     not compile against it. Adapted below to instantiate first, exactly like the existing
#     suite already does.
#   * DesktopAppHostState has no `go_home(current_day, board_phase)` method and no `board_phase`
#     parameter anywhere -- open_app()/change_day() take no board_phase. It has `close_app()`
#     instead of `go_home()`, returning `hide_app_id`/`show_app_id`/`focus_target`, not a
#     `commands` array with `kind=suspend_board|hide_app|resume_board|discard_candidate|
#     forfeit_board`. None of this brief's board-phase-driven command derivation exists in the
#     frozen class. Since it is out of scope to edit, the verbatim
#     `test_home_suspends_a_started_board_without_eviction()` example cannot be delivered:
#     GDScript's static type checker treats a call to a nonexistent method as a compile error,
#     which would fail this entire suite to parse/load (forbidden by the RED evidence law). The
#     host section below instead exercises the host's actual surface.
#
# Overlap with the existing per-class suites is intentional (downstream gates name suites by
# exact path).

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")

const REGISTRY := preload("res://scripts/domain/desktop/DesktopAppRegistry.gd")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const IDENTITY := preload("res://scripts/domain/desktop/DesktopIdentity.gd")

const VALID_IDENTITY := {
	"run_id": "run-1",
	"branch_id": "branch-1",
	"desktop_timeline_generation": 0,
	"causal_day_instance": "day-1",
	"app_round_ordinal": 1,
}


func _registry() -> RefCounted:
	return REGISTRY.new()


func _host() -> RefCounted:
	return HOST.new()


# ---- Step 2.2 parse proof ----

func test_identity_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script("res://scripts/domain/desktop/DesktopIdentity.gd")
	assert_true(loaded.get("ok", false), "DesktopIdentity.gd must load")


# ---- Registry: closed seven-app set (adapted from the brief's verbatim example -- see header) ----

func test_registry_is_the_closed_seven_app_set() -> void:
	assert_eq(_registry().get_ids(), [
		&"minesweeper", &"contacts", &"schedule", &"shop",
		&"backup", &"settings", &"logout",
	])


func test_registry_get_record_rejects_unknown_app() -> void:
	var rec: Dictionary = _registry().get_record(&"not_a_real_app")
	assert_false(rec.get("ok", true), "unknown app id rejects")
	assert_eq(rec.get("code"), &"unknown_app_id")


func test_registry_validate_all_passes_for_the_frozen_set() -> void:
	var result: Dictionary = _registry().validate_all()
	assert_true(result.get("ok", false), JSON.stringify(result))


# ---- Host: actual surface (open_app/close_app/change_day/get_state/capture/prepare_restore) ----

func test_host_unknown_app_rejects() -> void:
	var h := _host()
	h.reset(1)
	var opened: Dictionary = h.open_app(&"does_not_exist", 1)
	assert_false(opened.get("ok", true), "unknown app id rejects")
	assert_eq(opened.get("code"), &"unknown_app_id")


func test_host_change_day_rejects_invalid_days() -> void:
	var h := _host()
	h.reset(3)
	assert_false(h.change_day(0).get("ok", true), "day zero rejects")
	assert_false(h.change_day(-1).get("ok", true), "negative day rejects")
	assert_false(h.change_day(3).get("ok", true), "unchanged day rejects")
	assert_false(h.change_day(2).get("ok", true), "backward day rejects")


func test_host_open_app_duplicate_same_day_is_a_noop_reopen() -> void:
	var h := _host()
	h.reset(1)
	h.open_app(&"minesweeper", 1)
	h.open_app(&"contacts", 1)
	var reopen: Dictionary = h.open_app(&"minesweeper", 1)
	assert_false(reopen["instantiate"], "already-cached same-day app does not reinstantiate")
	assert_eq(reopen["show_app_id"], &"minesweeper")


func test_host_minesweeper_resume_after_switch() -> void:
	var h := _host()
	h.reset(1)
	h.open_app(&"minesweeper", 1)
	h.open_app(&"contacts", 1)
	var resumed: Dictionary = h.open_app(&"minesweeper", 1)
	assert_true(resumed.get("ok", false))
	assert_false(resumed["instantiate"], "resuming a cached board does not reinstantiate")
	assert_eq(resumed["hide_app_id"], &"contacts")
	assert_eq(resumed["show_app_id"], &"minesweeper")


func test_host_same_day_switching_reports_the_previously_active_app() -> void:
	var h := _host()
	h.reset(2)
	h.open_app(&"shop", 2)
	var switched: Dictionary = h.open_app(&"settings", 2)
	assert_eq(switched["hide_app_id"], &"shop")
	assert_eq(switched["show_app_id"], &"settings")


func test_host_capture_persistent_state_never_carries_cached_app_ids() -> void:
	var h := _host()
	h.reset(1)
	h.open_app(&"minesweeper", 1)
	h.open_app(&"contacts", 1)
	var captured: Dictionary = h.capture_persistent_state()
	assert_eq(captured.keys(), ["active_app_id"], "capture_persistent_state carries exactly active_app_id")
	assert_false(captured.has("cached_app_ids"), "cached app identities are runtime-only and never serialize")


func test_host_get_state_returns_a_detached_copy() -> void:
	var h := _host()
	h.reset(1)
	h.open_app(&"minesweeper", 1)
	var state_a: Dictionary = h.get_state()
	state_a["cached_app_ids"].append(&"tampered")
	var state_b: Dictionary = h.get_state()
	assert_false(state_b["cached_app_ids"].has(&"tampered"), "get_state() returns a detached copy")


# ---- Identity: validate/fingerprint/remap ----

func test_identity_validate_accepts_the_frozen_shape() -> void:
	var result: Dictionary = IDENTITY.validate(VALID_IDENTITY)
	assert_true(result.get("ok", false), JSON.stringify(result))


func test_identity_validate_rejects_extra_key() -> void:
	var bad: Dictionary = VALID_IDENTITY.duplicate(true)
	bad["extra_field"] = "nope"
	assert_false(IDENTITY.validate(bad).get("ok", true))


func test_identity_validate_rejects_missing_key() -> void:
	for key: String in VALID_IDENTITY.keys():
		var bad: Dictionary = VALID_IDENTITY.duplicate(true)
		bad.erase(key)
		assert_false(IDENTITY.validate(bad).get("ok", true), "missing %s must reject" % key)


func test_identity_validate_rejects_blank_strings() -> void:
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		for blank: String in ["", "   "]:
			var bad: Dictionary = VALID_IDENTITY.duplicate(true)
			bad[key] = blank
			assert_false(IDENTITY.validate(bad).get("ok", true), "blank %s must reject" % key)


func test_identity_validate_rejects_non_string_string_fields() -> void:
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		var bad: Dictionary = VALID_IDENTITY.duplicate(true)
		bad[key] = 123
		assert_false(IDENTITY.validate(bad).get("ok", true), "non-string %s must reject" % key)


func test_identity_validate_rejects_non_integral_generation() -> void:
	for bad_value: Variant in ["0", 1.5, true]:
		var bad: Dictionary = VALID_IDENTITY.duplicate(true)
		bad["desktop_timeline_generation"] = bad_value
		assert_false(IDENTITY.validate(bad).get("ok", true), "non-integral generation must reject")


func test_identity_validate_rejects_negative_generation() -> void:
	var bad: Dictionary = VALID_IDENTITY.duplicate(true)
	bad["desktop_timeline_generation"] = -1
	assert_false(IDENTITY.validate(bad).get("ok", true))


func test_identity_validate_rejects_ordinal_outside_1_to_5() -> void:
	for bad_ordinal: Variant in [0, 6, -1, 1.5, "1"]:
		var bad: Dictionary = VALID_IDENTITY.duplicate(true)
		bad["app_round_ordinal"] = bad_ordinal
		assert_false(IDENTITY.validate(bad).get("ok", true), "ordinal %s must reject" % str(bad_ordinal))


func test_identity_validate_accepts_every_ordinal_in_range() -> void:
	for ordinal: int in [1, 2, 3, 4, 5]:
		var candidate: Dictionary = VALID_IDENTITY.duplicate(true)
		candidate["app_round_ordinal"] = ordinal
		assert_true(IDENTITY.validate(candidate).get("ok", false), "ordinal %d must accept" % ordinal)


func test_identity_fingerprint_is_stable_and_lowercase_hex() -> void:
	var a: Dictionary = IDENTITY.fingerprint(VALID_IDENTITY)
	var b: Dictionary = IDENTITY.fingerprint(VALID_IDENTITY.duplicate(true))
	assert_true(a.get("ok", false), JSON.stringify(a))
	assert_eq(a["value"]["fingerprint"], b["value"]["fingerprint"], "same identity content fingerprints identically")
	var hex: String = a["value"]["fingerprint"]
	assert_eq(hex.length(), 64, "sha256 hex digest is 64 characters")
	assert_eq(hex, hex.to_lower(), "fingerprint is lowercase")


func test_identity_fingerprint_changes_when_a_field_changes() -> void:
	var a: Dictionary = IDENTITY.fingerprint(VALID_IDENTITY)
	var other: Dictionary = VALID_IDENTITY.duplicate(true)
	other["app_round_ordinal"] = 2
	var b: Dictionary = IDENTITY.fingerprint(other)
	assert_ne(a["value"]["fingerprint"], b["value"]["fingerprint"])


func test_identity_fingerprint_rejects_a_malformed_identity() -> void:
	var bad: Dictionary = VALID_IDENTITY.duplicate(true)
	bad.erase("run_id")
	assert_false(IDENTITY.fingerprint(bad).get("ok", true))


func test_identity_remap_replaces_exactly_branch_generation_and_day() -> void:
	var remapped: Dictionary = IDENTITY.remap(VALID_IDENTITY, "branch-2", 3, "day-9")
	assert_true(remapped.get("ok", false), JSON.stringify(remapped))
	var value: Dictionary = remapped["value"]["identity"]
	assert_eq(value["run_id"], "run-1", "run_id and app_round_ordinal are carried, not replaced")
	assert_eq(value["app_round_ordinal"], 1)
	assert_eq(value["branch_id"], "branch-2")
	assert_eq(value["desktop_timeline_generation"], 3)
	assert_eq(value["causal_day_instance"], "day-9")


func test_identity_remap_rejects_blank_replacement_fields() -> void:
	assert_false(IDENTITY.remap(VALID_IDENTITY, "", 3, "day-9").get("ok", true), "blank branch_id rejects")
	assert_false(IDENTITY.remap(VALID_IDENTITY, "branch-2", 3, "").get("ok", true), "blank causal_day_instance rejects")


func test_identity_remap_rejects_negative_generation() -> void:
	assert_false(IDENTITY.remap(VALID_IDENTITY, "branch-2", -1, "day-9").get("ok", true))


func test_identity_remap_rejects_a_malformed_source_identity() -> void:
	var bad: Dictionary = VALID_IDENTITY.duplicate(true)
	bad["app_round_ordinal"] = 9
	assert_false(IDENTITY.remap(bad, "branch-2", 3, "day-9").get("ok", true))


func test_identity_validate_and_remap_never_mutate_the_caller_dictionary() -> void:
	var source: Dictionary = VALID_IDENTITY.duplicate(true)
	var validated: Dictionary = IDENTITY.validate(source)
	validated["value"]["identity"]["run_id"] = "tampered"
	assert_eq(source["run_id"], "run-1", "validate() result is detached from the input")

	var remapped: Dictionary = IDENTITY.remap(source, "branch-2", 3, "day-9")
	remapped["value"]["identity"]["branch_id"] = "tampered"
	assert_eq(source["branch_id"], "branch-1", "remap() never mutates the source identity")
	assert_eq(IDENTITY.remap(source, "branch-2", 3, "day-9")["value"]["identity"]["branch_id"], "branch-2",
		"a fresh remap() call is unaffected by tampering with a previous result")
