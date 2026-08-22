extends "res://addons/gut/test.gd"

const MIGRATIONS_PATH := "res://scripts/infrastructure/save/SaveMigrations.gd"
const FIXTURES := "res://tests/fixtures/saves/"

func _migrations_exist() -> bool:
	return ResourceLoader.exists(MIGRATIONS_PATH, "Script")

func _fixture(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name))

func test_save_migrations_exists() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")

func test_ending_id_migration_map_and_passthrough() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	assert_eq(m.migrate_ending_id("alone")["value"]["ending_id"], "ending.alone")
	assert_eq(m.migrate_ending_id("lavinia_priscilla")["value"]["ending_id"], "ending.priscilla_lavinia")
	assert_eq(m.migrate_ending_id("sylvia.special")["value"]["ending_id"], "ending.sylvia.special")
	assert_eq(m.migrate_ending_id("ending.alone")["value"]["ending_id"], "ending.alone",
		"canonical ids pass through unchanged")
	assert_false(m.migrate_ending_id("priscilla.platonic").get("ok", true), "unknown ids reject recoverably")

func test_pair_token_migration() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	assert_eq(m.migrate_pair_token("lavinia_priscilla")["value"]["token"], "priscilla_lavinia")
	assert_eq(m.migrate_pair_token("priscilla_lavinia")["value"]["token"], "priscilla_lavinia")
	assert_false(m.migrate_pair_token("angela_priscilla").get("ok", true))

func test_snapshot_v1_to_v2() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var document: Dictionary = _fixture("v1_minimal_slot.json")
	var v1_snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	# Strip the profile-owned legacy members the document migrator removes.
	v1_snapshot.erase("settings")
	v1_snapshot.erase("seen_endings")
	var migrated: Dictionary = m.migrate_snapshot_v1_to_v2(v1_snapshot)
	assert_true(migrated.get("ok", false), JSON.stringify(migrated))
	var snapshot: Dictionary = migrated["value"]["snapshot"]
	assert_eq(int(snapshot["schema_version"]), 2)
	assert_eq(snapshot["lifecycle"]["active_resolution_plan"], null, "plan moved into lifecycle")
	assert_true(snapshot["lifecycle"].has("ending_plan"))
	# dwm-p2r.8 Task 3 supersedes the older positive expectation: a receiptless snapshot may only
	# migrate when both applied-ID arrays are empty, so this positive fixture now carries none.
	assert_eq(snapshot["applied_effect_transaction_ids"], [], "ids renamed")
	assert_eq(snapshot["applied_variable_transaction_ids"], [], "variable ledger added")
	assert_eq(snapshot["command_receipts"], {}, "empty command ledger added")
	assert_eq(snapshot["active_app_id"], null, "active_app_id default added")
	assert_eq(snapshot["gameplay"]["narrative_variables"], {}, "narrative_variables default added")

## dwm-p2r.32 Task 6: v3 -> v4 is deliberately NOT a migration step. A v1 source still travels the
## real v1->v2->v3 historical chain internally (proving the legacy-member-stripping law still runs),
## but the whole operation now fails closed at the v3->v4 boundary rather than silently landing on a
## desktop-less "current" document -- there is no v4 without a real issuer-backed desktop member,
## and this module invents none.
func test_migrate_document_rejects_pre_v4_source_after_running_the_historical_chain() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var raw: Dictionary = _fixture("v1_minimal_slot.json")
	var before := raw.duplicate(true)
	var migrated: Dictionary = m.migrate_document(raw, {"kind": "slot", "slot_id": 1})
	assert_false(migrated.get("ok", true), "a pre-v4 source can never reach the current schema by migration")
	assert_eq(migrated["code"], &"unsupported_pre_amendment_desktop_schema")
	assert_eq(raw, before, "the rejected source is left completely unchanged")

func test_schema_dispatch_rejects_future_and_invalid() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	# v4 is the CURRENT snapshot version at the dwm-p2r.32 Task-6 boundary, so the unsupported-future
	# probe moves to 5. The fixture bytes are deliberately left untouched; only this probe advances.
	var future: Dictionary = _fixture("v2_future_schema.json")
	(future["current_snapshot"]["snapshot"] as Dictionary)["schema_version"] = 5
	var migrated: Dictionary = m.migrate_document(future, {"kind": "slot", "slot_id": 1})
	assert_false(migrated.get("ok", true), "schema_version 5 is unsupported")
	assert_eq(migrated["code"], &"unsupported_future_schema")

## The exact literal boundary code, plus proof it is reachable at every pre-v4 rung (not just v1):
## a v3-shaped source with no desktop member -- constructed directly, never migrated to -- rejects
## identically.
func test_v3_pre_desktop_source_rejects_unchanged() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var raw: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/saves/v3_pre_desktop.json"))
	var before := raw.duplicate(true)
	var migrated: Dictionary = m.migrate_document(raw, {"kind": "slot", "slot_id": 1})
	assert_false(migrated.get("ok", true))
	assert_eq(migrated["code"], &"unsupported_pre_amendment_desktop_schema")
	assert_eq(raw, before, "the rejected source is left completely unchanged")
	assert_eq(m.UNSUPPORTED_PRE_AMENDMENT_DESKTOP_SCHEMA, &"unsupported_pre_amendment_desktop_schema")

func test_migrate_document_rejects_bad_locator() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var raw: Dictionary = _fixture("v1_minimal_slot.json")
	assert_false(m.migrate_document(raw, {"kind": "slot", "slot_id": 8}).get("ok", true))
	assert_false(m.migrate_document(raw, {"kind": "quick", "slot_id": 1}).get("ok", true))

func test_legacy_day8_group_synchronized_recompute() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var snapshot: Dictionary = _fixture("day8_group_synchronized.json")
	var result: Dictionary = m.migrate_legacy_day8(snapshot, [])
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["ending_id"], "ending.priscilla.dark",
		"a synchronized group primary recomputes to the Angela pairing")
	assert_eq(result["value"]["epilogue_ending_id"], "ending.priscilla_lavinia")
	assert_eq(int(result["value"]["snapshot"]["lifecycle"]["day"]), 7, "no Day 8 survives")
	assert_eq(str(result["value"]["snapshot"]["lifecycle"]["state"]), "ENDING")

func test_legacy_day8_non_group_preserved_at_day7() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var result: Dictionary = m.migrate_legacy_day8(_fixture("day8_ending_non_group.json"), [])
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["ending_id"], "ending.sylvia.sweet", "valid non-group primary preserved")
	assert_eq(int(result["value"]["snapshot"]["lifecycle"]["day"]), 7)

## dwm-p2r.32 Task 6: every candidate fallback bundle is itself a pre-v4 legacy snapshot, and
## `_greatest_compatible_bundle()` runs each one through the same forward chain -- which now rejects
## unchanged at the v3->v4 boundary (test_v3_pre_desktop_source_rejects_unchanged proves the boundary
## itself). No legacy Day-7 bundle can therefore ever be selected as a Day-8 fallback any more; both
## scenarios this test used to prove a successful fallback for now correctly find none.
func test_legacy_day8_fallback_bundles_are_pre_v4_and_now_find_none() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var playing: Dictionary = _fixture("day8_playing_with_day7_journal.json")
	var result: Dictionary = m.migrate_legacy_day8(playing["snapshot"], playing["day7_bundles"])
	assert_false(result.get("ok", true), JSON.stringify(result))
	assert_eq(result["code"], &"no_day8_reconstruction")
	var invalid_group: Dictionary = _fixture("day8_group_invalid_with_day7_journal.json")
	var fallback: Dictionary = m.migrate_legacy_day8(invalid_group["snapshot"], invalid_group["day7_bundles"])
	assert_false(fallback.get("ok", true), JSON.stringify(fallback))
	assert_eq(fallback["code"], &"no_day8_reconstruction")

func test_legacy_day8_no_fallback_rejects() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var result: Dictionary = m.migrate_legacy_day8(_fixture("day8_no_fallback.json"), [])
	assert_false(result.get("ok", true), "no valid terminal and no fallback rejects")
	assert_eq(result["code"], &"no_day8_reconstruction")

func test_migrate_retired_true_ending_ids() -> void:
	var m: Script = load("res://scripts/infrastructure/save/SaveMigrations.gd")
	assert_eq(m.migrate_ending_id("priscilla.true")["value"]["ending_id"], "ending.priscilla.observation")
	assert_eq(m.migrate_ending_id("ending.lavinia.true")["value"]["ending_id"], "ending.lavinia.observation")
	assert_eq(m.migrate_ending_id("sylvia.true")["value"]["ending_id"], "ending.sylvia.special")
	assert_eq(m.migrate_ending_id("ending.sylvia.true")["value"]["ending_id"], "ending.sylvia.special")


# ---- dwm-p2r.8 (Plan-05 Task 3): receiptless nonempty applied-ID arrays are unmigratable ----
# This failure is STRUCTURAL: migration must never discard ids, invent fingerprints or receipts,
# or weaken partition equality, and it does not trigger an earlier-bundle fallback.

func test_snapshot_migration_fails_for_receiptless_applied_ids() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var document: Dictionary = _fixture("v1_unreceipted_applied_ids.json")
	var v1_snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	v1_snapshot.erase("settings")
	v1_snapshot.erase("seen_endings")
	var before := v1_snapshot.duplicate(true)
	var migrated: Dictionary = m.migrate_snapshot_v1_to_v2(v1_snapshot)
	assert_false(migrated.get("ok", false), "a receiptless applied-ID set cannot migrate")
	assert_eq(str(migrated.get("code")), "unmigratable_command_receipts", "typed structural failure")
	assert_eq(v1_snapshot, before, "the rejected input is never modified")


func test_document_migration_fails_for_receiptless_applied_ids() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var raw: Dictionary = _fixture("v1_unreceipted_applied_ids.json")
	var before := raw.duplicate(true)
	var migrated: Dictionary = m.migrate_document(raw, {"kind": "slot", "slot_id": 1})
	assert_false(migrated.get("ok", false), "whole-document migration fails too")
	assert_eq(raw, before, "the rejected document is never modified")


func test_migration_adds_empty_ledger_only_when_both_arrays_are_empty() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var document: Dictionary = _fixture("v1_minimal_slot.json")
	var v1_snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	v1_snapshot.erase("settings")
	v1_snapshot.erase("seen_endings")
	var migrated: Dictionary = m.migrate_snapshot_v1_to_v2(v1_snapshot)
	assert_true(migrated.get("ok", false), JSON.stringify(migrated))
	assert_eq(migrated["value"]["snapshot"]["command_receipts"], {}, "empty ledger added, nothing invented")


# ---- dwm-p2r.13 Task 5: v2 -> v3 committed-Schedule migration ----
# The v1 -> v2 step must stamp a LITERAL 2 and hand off to a real v2 -> v3 step. Substituting the
# current schema constant into the old step would silently label v2 bytes as v3.

const SNAPSHOT_FIXTURES := "res://tests/fixtures/snapshots/"

func _snapshot_fixture(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT_FIXTURES + name))

## The exact aggregate v2_empty_legacy_schedule.json must migrate to. Its day is the fixture's own
## saved lifecycle day, so a fixture that changed day would fail loudly here rather than silently.
const CANONICAL_EMPTY_AGGREGATE := {
	"schema_version": 1,
	"day": 2,
	"registry_fingerprint": null,
	"entries": [],
	"commit_receipt": null,
}

func test_v1_to_v2_stamps_a_literal_two_not_the_current_constant() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var schema: Script = load("res://scripts/domain/run/RunSnapshotSchema.gd")
	assert_eq(int(schema.SCHEMA_VERSION), 4, "precondition: the current snapshot version is 4")
	var document: Dictionary = _fixture("v1_minimal_slot.json")
	var v1_snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	v1_snapshot.erase("settings")
	v1_snapshot.erase("seen_endings")
	var migrated: Dictionary = m.migrate_snapshot_v1_to_v2(v1_snapshot)
	assert_true(migrated.get("ok", false), JSON.stringify(migrated))
	assert_eq(int(migrated["value"]["snapshot"]["schema_version"]), 2,
		"the v1 -> v2 step emits a v2-shaped dict, never the current constant")

func test_v2_to_v3_migrates_empty_legacy_schedule_to_the_canonical_empty_aggregate() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var v2 := _snapshot_fixture("v2_empty_legacy_schedule.json")
	var migrated: Dictionary = m.migrate_snapshot_v2_to_v3(v2)
	assert_true(migrated.get("ok", false), JSON.stringify(migrated))
	var snapshot: Dictionary = migrated["value"]["snapshot"]
	assert_eq(int(snapshot["schema_version"]), 3, "the v2 -> v3 step stamps 3")
	assert_eq(snapshot["committed_schedule"], CANONICAL_EMPTY_AGGREGATE,
		"an empty legacy Schedule becomes the canonical empty aggregate at the saved day")
	assert_false(snapshot.has("schedule"), "the legacy top-level array is removed")
	assert_false((snapshot["gameplay"] as Dictionary).has("schedule_entries"),
		"the legacy gameplay field is removed")

func test_v2_to_v3_takes_the_day_from_the_validated_lifecycle() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var v2 := _snapshot_fixture("v2_empty_legacy_schedule.json")
	(v2["lifecycle"] as Dictionary)["day"] = 6
	var migrated: Dictionary = m.migrate_snapshot_v2_to_v3(v2)
	assert_true(migrated.get("ok", false), JSON.stringify(migrated))
	assert_eq(int(migrated["value"]["snapshot"]["committed_schedule"]["day"]), 6,
		"saved_day is the already-validated v2 active-run day, not a constant")

func test_v2_to_v3_rejects_nonempty_top_level_schedule() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var v2 := _snapshot_fixture("v2_nonempty_top_level_schedule.json")
	var before := v2.duplicate(true)
	var migrated: Dictionary = m.migrate_snapshot_v2_to_v3(v2)
	assert_false(migrated.get("ok", true), "a nonempty pre-amendment Schedule fails closed")
	assert_eq(str(migrated.get("code")), "unmigratable_legacy_schedule", "typed structural failure")
	assert_eq(v2, before, "the rejected input is never modified")

func test_v2_to_v3_rejects_nonempty_gameplay_schedule_entries() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var v2 := _snapshot_fixture("v2_nonempty_gameplay_schedule_entries.json")
	var before := v2.duplicate(true)
	var migrated: Dictionary = m.migrate_snapshot_v2_to_v3(v2)
	assert_false(migrated.get("ok", true), "the second legacy representation fails closed too")
	assert_eq(str(migrated.get("code")), "unmigratable_legacy_schedule", "typed structural failure")
	assert_eq(v2, before, "the rejected input is never modified")

func test_v2_to_v3_rejects_malformed_legacy_representations() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	for malformed: Variant in [{}, "", 0, [[]]]:
		var v2 := _snapshot_fixture("v2_empty_legacy_schedule.json")
		v2["schedule"] = malformed
		var migrated: Dictionary = m.migrate_snapshot_v2_to_v3(v2)
		assert_false(migrated.get("ok", true),
			"a malformed legacy schedule fails closed: " + JSON.stringify(malformed))
		assert_eq(str(migrated.get("code")), "unmigratable_legacy_schedule",
			"malformed legacy Schedule uses the same typed code")
	var entries_malformed := _snapshot_fixture("v2_empty_legacy_schedule.json")
	(entries_malformed["gameplay"] as Dictionary)["schedule_entries"] = {}
	assert_eq(str(m.migrate_snapshot_v2_to_v3(entries_malformed).get("code")),
		"unmigratable_legacy_schedule", "a malformed gameplay field fails closed")

func test_v2_to_v3_never_invents_a_source_receipt_for_an_accepted_invitation() -> void:
	# Migration may not manufacture the ancestry Task 3 requires. A legacy Contacts state that has
	# already accepted an invitation cannot produce an authenticated source receipt, so it fails
	# closed rather than inventing one.
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var v2 := _snapshot_fixture("v2_empty_legacy_schedule.json")
	v2["contacts"] = {
		"messages": {"priscilla": [], "lavinia": [], "sylvia": []},
		"read_watermarks": {"priscilla": 0, "lavinia": 0, "sylvia": 0},
		"solo_actions": {"solo:priscilla:day3": {"state": "ACCEPTED"}},
		"group_action": {"state": "INACTIVE"},
		"transaction_receipts": {},
		"next_sequence": 1,
	}
	var migrated: Dictionary = m.migrate_snapshot_v2_to_v3(v2)
	assert_false(migrated.get("ok", true), "an accepted legacy invitation cannot migrate")
	assert_eq(str(migrated.get("code")), "unmigratable_legacy_schedule",
		"the same typed code covers invented-ancestry refusal")

func test_v2_to_v3_rejects_an_invitation_accepted_earlier_and_since_resolved() -> void:
	# Acceptance is DURABLE and the state moves on: prepare_resolve_day_end carries an accepted
	# invitation into RESOLVED_ATTENDED / RESOLVED_MISSED / RESOLVED_RUN_END. A check that matched
	# only the literal "ACCEPTED" would pass every save taken after the day the invitation resolved,
	# which is the common case. The durable markers are reply_transaction_id and replied_ids.
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	for resolved_state: String in ["RESOLVED_ATTENDED", "RESOLVED_MISSED", "RESOLVED_RUN_END"]:
		var v2 := _snapshot_fixture("v2_empty_legacy_schedule.json")
		v2["contacts"] = {
			"messages": {"priscilla": [], "lavinia": [], "sylvia": []},
			"read_watermarks": {"priscilla": 0, "lavinia": 0, "sylvia": 0},
			"solo_actions": {"solo:priscilla:day1": {"state": resolved_state}},
			"group_action": {"state": "INACTIVE"},
			"transaction_receipts": {},
			"next_sequence": 1,
		}
		assert_eq(str(m.migrate_snapshot_v2_to_v3(v2).get("code")), "unmigratable_legacy_schedule",
			"a resolved-but-once-accepted solo fails closed: " + resolved_state)

	# The durable marker alone is enough, even with an unrecognised state string.
	var by_marker := _snapshot_fixture("v2_empty_legacy_schedule.json")
	by_marker["contacts"] = {
		"messages": {"priscilla": [], "lavinia": [], "sylvia": []},
		"read_watermarks": {"priscilla": 0, "lavinia": 0, "sylvia": 0},
		"solo_actions": {"solo:priscilla:day1": {"state": "SOMETHING_ELSE",
			"reply_transaction_id": "tx-accepted"}},
		"group_action": {"state": "INACTIVE"},
		"transaction_receipts": {},
		"next_sequence": 1,
	}
	assert_eq(str(m.migrate_snapshot_v2_to_v3(by_marker).get("code")), "unmigratable_legacy_schedule",
		"a durable solo reply_transaction_id alone fails closed")

	var group_replied := _snapshot_fixture("v2_empty_legacy_schedule.json")
	group_replied["contacts"] = {
		"messages": {"priscilla": [], "lavinia": [], "sylvia": []},
		"read_watermarks": {"priscilla": 0, "lavinia": 0, "sylvia": 0},
		"solo_actions": {},
		"group_action": {"state": "REPLY_REQUIRED", "replied_ids": ["priscilla"]},
		"transaction_receipts": {},
		"next_sequence": 1,
	}
	assert_eq(str(m.migrate_snapshot_v2_to_v3(group_replied).get("code")),
		"unmigratable_legacy_schedule", "a group with durable replies fails closed")


func test_v2_to_v3_never_fabricates_a_contacts_section() -> void:
	# Inventing a two-key stub would turn a previously-REJECTED document into an accepted one
	# carrying a bag ContactInvitationState.validate_state would refuse.
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)

	var absent := _snapshot_fixture("v2_empty_legacy_schedule.json")
	absent.erase("contacts")
	assert_false(m.migrate_snapshot_v2_to_v3(absent).get("ok", true),
		"an absent contacts member is never invented")

	for malformed: Variant in [[], "", 0]:
		var v2 := _snapshot_fixture("v2_empty_legacy_schedule.json")
		v2["contacts"] = malformed
		var migrated: Dictionary = m.migrate_snapshot_v2_to_v3(v2)
		assert_false(migrated.get("ok", true),
			"a malformed contacts member is never replaced: " + JSON.stringify(malformed))


func test_v2_to_v3_adds_only_the_two_empty_contacts_indexes() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var v2 := _snapshot_fixture("v2_empty_legacy_schedule.json")
	var legacy_contacts := {
		"messages": {"priscilla": [], "lavinia": [], "sylvia": []},
		"read_watermarks": {"priscilla": 0, "lavinia": 0, "sylvia": 0},
		"solo_actions": {},
		"group_action": {"state": "INACTIVE"},
		"transaction_receipts": {},
		"next_sequence": 1,
	}
	v2["contacts"] = legacy_contacts.duplicate(true)
	var migrated: Dictionary = m.migrate_snapshot_v2_to_v3(v2)
	assert_true(migrated.get("ok", false), JSON.stringify(migrated))
	var contacts: Dictionary = migrated["value"]["snapshot"]["contacts"]
	assert_eq(contacts["schedule_source_receipts"], {}, "an empty source index is added")
	assert_eq(contacts["sylvia_hospital_witness_receipts"], {}, "an empty witness index is added")
	for key: Variant in legacy_contacts:
		assert_eq(contacts[str(key)], legacy_contacts[key],
			"every pre-existing Contacts member survives unchanged: " + str(key))
	assert_eq((contacts.keys() as Array).size(), (legacy_contacts.keys() as Array).size() + 2,
		"exactly two members are added and nothing else")

func test_v2_to_v3_never_adopts_the_current_registry_fingerprint() -> void:
	# Step 5.3. A migrated aggregate carries a null fingerprint forever; only a later logical-day
	# initialization may adopt a current one. Proven twice: by behaviour and by source inspection.
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var v2 := _snapshot_fixture("v2_empty_legacy_schedule.json")
	var migrated: Dictionary = m.migrate_snapshot_v2_to_v3(v2)
	assert_true(migrated.get("ok", false), JSON.stringify(migrated))
	assert_eq(migrated["value"]["snapshot"]["committed_schedule"]["registry_fingerprint"], null,
		"a migrated old save never carries a registry fingerprint")
	var source := FileAccess.get_file_as_string(MIGRATIONS_PATH)
	assert_false(source.is_empty(), "the migration source is readable")
	assert_false(source.contains("load_current"),
		"migration must never stamp an old save with the current registry")
	assert_false(source.contains("ScheduleActionRegistry"),
		"migration does not reference the registry at all")

## dwm-p2r.32 Task 6: a v1 source can no longer reach a "current" document by migration at all (see
## test_migrate_document_rejects_pre_v4_source_after_running_the_historical_chain above). The
## isolated v1->v2->v3 step functions this test used to prove through migrate_document() are still
## proven directly, at their own layer, by test_snapshot_v1_to_v2 and
## test_v2_to_v3_migrates_empty_legacy_schedule_to_the_canonical_empty_aggregate.
func test_v1_snapshot_still_travels_the_real_v1_to_v3_chain_before_the_v4_rejection() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var document: Dictionary = _fixture("v1_minimal_slot.json")
	var v1_snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	v1_snapshot.erase("settings")
	v1_snapshot.erase("seen_endings")
	var to_v2: Dictionary = m.migrate_snapshot_v1_to_v2(v1_snapshot)
	assert_true(to_v2.get("ok", false), JSON.stringify(to_v2))
	var to_v3: Dictionary = m.migrate_snapshot_v2_to_v3(to_v2["value"]["snapshot"])
	assert_true(to_v3.get("ok", false), JSON.stringify(to_v3))
	var v3_snapshot: Dictionary = to_v3["value"]["snapshot"]
	assert_eq(int(v3_snapshot["schema_version"]), 3, "the real chain still reaches v3 by itself")
	assert_true(v3_snapshot.has("committed_schedule"), "the v3 member is present")
	assert_false(v3_snapshot.has("schedule"), "the legacy member is gone")
	assert_false(v3_snapshot.has("desktop"), "no v1/v2/v3 step ever invents a desktop member")

func test_migration_never_touches_the_external_publication_ledger() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var source := FileAccess.get_file_as_string(MIGRATIONS_PATH)
	assert_false(source.is_empty(), "the migration source is readable")
	for forbidden: String in [
		"ScheduleFoundationPublicationLedger",
		"schedule-foundation-publications",
		"schedule_foundation_publications",
	]:
		assert_false(source.contains(forbidden),
			"migration never creates, imports, clears, rewrites or version-tags the external "
			+ "publication ledger: " + forbidden)
