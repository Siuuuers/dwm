class_name SaveMigrations
extends RefCounted

## Explicit, declarative save migrations
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).
## Migrations fill only declared schema defaults; they never read the current
## run, profile, route, locale, audio, or journal.

const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const DATING_ENDING_RULES := preload("res://scripts/domain/ending/DatingEndingRules.gd")
const SCHEDULE_STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

## Frozen per-step version literals. A migration step must NEVER read the current schema constant:
## substituting it into an old step silently relabels old bytes as the newest version and skips
## every step in between. Each literal advances only when that step's own shape changes.
const V2_SCHEMA_VERSION := 2
const V3_SCHEMA_VERSION := 3
const V4_SCHEMA_VERSION := 4
const UNMIGRATABLE_LEGACY_SCHEDULE := &"unmigratable_legacy_schedule"
## v3 -> v4 (Plan 02 Task 6, dwm-p2r.32) is deliberately NOT a migration step: no v1/v2/v3 source
## carries a `desktop` member, and this module never invents identity, issuer provenance, layout,
## capability, cost, receipt, sequence, recovery, or outbox state to synthesize one. Every pre-v4
## source rejects unchanged with this code; only a literal v4 input (constructed directly by New Run
## over a durably committed issuer allocation, never through this chain) ever reaches the current
## schema.
const UNSUPPORTED_PRE_AMENDMENT_DESKTOP_SCHEMA := &"unsupported_pre_amendment_desktop_schema"
## Acceptance is durable: an accepted invitation resolves into one of the RESOLVED_* states rather
## than reverting, so every state in this lineage still implies an acceptance whose source ancestry
## a migration cannot reconstruct.
const LEGACY_ACCEPTED_STATES: Array[String] = [
	"ACCEPTED", "RESOLVED_ATTENDED", "RESOLVED_MISSED", "RESOLVED_RUN_END",
]

const ENDING_ID_MAP := {
	"alone": "ending.alone",
	"priscilla.sweet": "ending.priscilla.sweet",
	"priscilla.dark": "ending.priscilla.dark",
	"priscilla.true": "ending.priscilla.observation",
	"ending.priscilla.true": "ending.priscilla.observation",
	"lavinia.sweet": "ending.lavinia.sweet",
	"lavinia.dark": "ending.lavinia.dark",
	"lavinia.true": "ending.lavinia.observation",
	"ending.lavinia.true": "ending.lavinia.observation",
	"sylvia.sweet": "ending.sylvia.sweet",
	"sylvia.dark": "ending.sylvia.dark",
	"sylvia.true": "ending.sylvia.special",
	"ending.sylvia.true": "ending.sylvia.special",
	"sylvia.special": "ending.sylvia.special",
	"priscilla_lavinia": "ending.priscilla_lavinia",
	"lavinia_priscilla": "ending.priscilla_lavinia",
}

# ---- Ending-id and pair-token migration ----

static func migrate_ending_id(ending_id: String) -> Dictionary:
	if DATING_ENDING_RULES.is_canonical_ending(ending_id):
		return {"ok": true, "code": &"ok", "value": {"ending_id": ending_id}}
	if ENDING_ID_MAP.has(ending_id):
		return {"ok": true, "code": &"ok", "value": {"ending_id": str(ENDING_ID_MAP[ending_id])}}
	return {"ok": false, "code": &"unknown_ending_id", "message": ending_id}

static func migrate_pair_token(token: String) -> Dictionary:
	if token == "lavinia_priscilla":
		return {"ok": true, "code": &"ok", "value": {"token": "priscilla_lavinia"}}
	if token == "priscilla_lavinia":
		return {"ok": true, "code": &"ok", "value": {"token": "priscilla_lavinia"}}
	return {"ok": false, "code": &"unknown_pair_token", "message": token}

# ---- Snapshot v1 -> v2 ----

static func migrate_snapshot_v1_to_v2(snapshot: Dictionary) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return _fail(&"invalid_snapshot", "snapshot must be an object")
	var v2 := RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(snapshot.duplicate(true)) as Dictionary

	# Move legacy top-level lifecycle members into `lifecycle`.
	var lifecycle: Dictionary = v2.get("lifecycle", {}) if typeof(v2.get("lifecycle")) == TYPE_DICTIONARY else {}
	if v2.has("active_day_resolution_plan"):
		lifecycle["active_resolution_plan"] = v2["active_day_resolution_plan"]
		v2.erase("active_day_resolution_plan")
	elif not lifecycle.has("active_resolution_plan"):
		lifecycle["active_resolution_plan"] = null
	if v2.has("ending_plan") and not lifecycle.has("ending_plan"):
		lifecycle["ending_plan"] = v2["ending_plan"]
		v2.erase("ending_plan")
	elif not lifecycle.has("ending_plan"):
		lifecycle["ending_plan"] = null
	# A legacy save caught MID-RESOLUTION carries a plan minted before the resolution root existed
	# (dwm-p2r.18). Faithful migration adds the members it genuinely had: the Done command was the
	# resolution id, and no root or start receipt was ever minted for it. Fabricating a root here
	# would claim an ancestry no issuer ever anchored.
	if typeof(lifecycle.get("active_resolution_plan")) == TYPE_DICTIONARY:
		var plan: Dictionary = lifecycle["active_resolution_plan"]
		if not plan.has("command_id"):
			plan["command_id"] = str(plan.get("resolution_id", ""))
		for absent_member: String in ["resolution_issuer_receipt", "day_resolution_start_receipt"]:
			if not plan.has(absent_member):
				plan[absent_member] = null
		lifecycle["active_resolution_plan"] = plan
	v2["lifecycle"] = lifecycle

	# Rename applied_transaction_ids -> applied_effect_transaction_ids; add variable ledger.
	if v2.has("applied_transaction_ids"):
		v2["applied_effect_transaction_ids"] = v2["applied_transaction_ids"]
		v2.erase("applied_transaction_ids")
	elif not v2.has("applied_effect_transaction_ids"):
		v2["applied_effect_transaction_ids"] = []
	if not v2.has("applied_variable_transaction_ids"):
		v2["applied_variable_transaction_ids"] = []

	# Mandatory effect/variable command ledger (dwm-p2r.8, Plan-05 Task 3). A legacy snapshot may
	# migrate to an empty map ONLY when both applied-ID arrays are empty: migration never invents a
	# receipt for an already-applied transaction, so a nonempty array without receipts fails closed.
	if not v2.has("command_receipts"):
		var applied_effects: Variant = v2.get("applied_effect_transaction_ids", [])
		var applied_variables: Variant = v2.get("applied_variable_transaction_ids", [])
		var effects_empty := typeof(applied_effects) == TYPE_ARRAY and (applied_effects as Array).is_empty()
		var variables_empty := typeof(applied_variables) == TYPE_ARRAY and (applied_variables as Array).is_empty()
		if not (effects_empty and variables_empty):
			return {"ok": false, "code": &"unmigratable_command_receipts",
				"message": "a snapshot with applied transaction ids cannot migrate without its command receipts"}
		v2["command_receipts"] = {}

	# Declared v2 defaults.
	if not v2.has("active_app_id"):
		v2["active_app_id"] = null
	var gameplay: Dictionary = v2.get("gameplay", {}) if typeof(v2.get("gameplay")) == TYPE_DICTIONARY else {}
	if not gameplay.has("narrative_variables"):
		gameplay["narrative_variables"] = {}
	v2["gameplay"] = gameplay
	# LITERAL 2. Reading RUN_SNAPSHOT_SCHEMA.SCHEMA_VERSION here would stamp whatever the newest
	# version happens to be onto v2-shaped bytes, and the v2 -> v3 step would then never run.
	v2["schema_version"] = V2_SCHEMA_VERSION

	# For the same reason this step cannot end by calling the CURRENT validator: once the current
	# schema requires v3, validating here would reject a perfectly correct v2 intermediate. This
	# step emits a v2-shaped dict and hands off to migrate_snapshot_v2_to_v3.
	return {"ok": true, "code": &"ok", "value": {"snapshot": v2}}


# ---- Snapshot v2 -> v3 (committed Schedule; Plan 01 Task 5, dwm-p2r.13) ----

## Replaces the two legacy Schedule representations with the canonical committed aggregate.
##
## Empty legacy state migrates to the canonical EMPTY aggregate at the saved day, carrying a NULL
## registry fingerprint forever: this step never loads, names or adopts the current registry, so an
## old save can never be silently relabelled as agreeing with today's action manifest. Only a later
## logical-day initialization may replace the null empty aggregate with a current-fingerprint one.
##
## Nonempty or malformed legacy state fails closed with `unmigratable_legacy_schedule`. Migration
## invents no source receipt, no witness receipt, no fingerprint and no ancestry, and it neither
## reads nor writes the external publication ledger.
static func migrate_snapshot_v2_to_v3(snapshot: Dictionary) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return _fail(&"invalid_snapshot", "snapshot must be an object")
	var v3 := RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(snapshot.duplicate(true)) as Dictionary

	# saved_day is the already-validated v2 active-run day. It is read from the saved lifecycle and
	# is never guessed, defaulted, or taken from a clock.
	var lifecycle: Variant = v3.get("lifecycle")
	if typeof(lifecycle) != TYPE_DICTIONARY:
		return _fail(&"invalid_snapshot", "snapshot.lifecycle is required")
	var saved_day_value: Variant = (lifecycle as Dictionary).get("day")
	if typeof(saved_day_value) != TYPE_INT \
			or int(saved_day_value) < SCHEDULE_STATE_SCHEMA.FIRST_DAY \
			or int(saved_day_value) > SCHEDULE_STATE_SCHEMA.LAST_DAY:
		return _fail(&"invalid_snapshot", "the v2 active-run day must be an integer 1..7")
	var saved_day := int(saved_day_value)

	var legacy_error := _legacy_schedule_error(v3)
	if legacy_error != "":
		return _fail(UNMIGRATABLE_LEGACY_SCHEDULE, legacy_error)

	v3.erase("schedule")
	var gameplay: Dictionary = v3.get("gameplay", {}) \
		if typeof(v3.get("gameplay")) == TYPE_DICTIONARY else {}
	gameplay.erase("schedule_entries")
	v3["gameplay"] = gameplay

	var empty: Dictionary = SCHEDULE_STATE_SCHEMA.empty_aggregate(saved_day, null)
	if not empty.get("ok", false):
		return empty
	v3["committed_schedule"] = (empty["value"] as Dictionary)["committed_schedule"]
	# Only an EXISTING Contacts object gains the two indexes; an absent or malformed one is rejected
	# directly below rather than silently invented (dwm-p2r.32 Task 6: this narrow local check
	# replaces the removed final RUN_SNAPSHOT_SCHEMA.validate() call, which can no longer run at this
	# intermediate v3 rung -- see the literal-3 note below).
	if typeof(v3.get("contacts")) == TYPE_DICTIONARY:
		v3["contacts"] = _contacts_with_source_indexes(v3["contacts"])
	else:
		return _fail(&"invalid_snapshot", "contacts must be an object")
	v3["schema_version"] = V3_SCHEMA_VERSION

	# LITERAL 3, matching migrate_snapshot_v1_to_v2's own precedent (dwm-p2r.32 Task 6): this step
	# emits a v3-shaped dict and hands off. It must NEVER validate against RUN_SNAPSHOT_SCHEMA.validate()
	# here -- that now requires the CURRENT (v4) schema, and v3 is an intermediate rung the v3->v4
	# boundary deliberately refuses to bridge (see UNSUPPORTED_PRE_AMENDMENT_DESKTOP_SCHEMA). Doing so
	# would make this isolated historical step spuriously fail after any future schema bump.
	return {"ok": true, "code": &"ok", "value": {"snapshot": v3}}


## Both legacy representations must be absent or exactly empty. A surviving entry, a non-array, or
## an already-accepted invitation whose source ancestry cannot be reconstructed all fail closed
## rather than being reshaped into something that merely looks authenticated.
static func _legacy_schedule_error(snapshot: Dictionary) -> String:
	if snapshot.has("schedule"):
		var legacy: Variant = snapshot["schedule"]
		if typeof(legacy) != TYPE_ARRAY:
			return "the legacy top-level schedule must be an array"
		if not (legacy as Array).is_empty():
			return "a nonempty pre-amendment Schedule cannot migrate"
	var gameplay: Variant = snapshot.get("gameplay")
	if typeof(gameplay) == TYPE_DICTIONARY and (gameplay as Dictionary).has("schedule_entries"):
		var entries: Variant = (gameplay as Dictionary)["schedule_entries"]
		if typeof(entries) != TYPE_ARRAY:
			return "the legacy gameplay.schedule_entries must be an array"
		if not (entries as Array).is_empty():
			return "a nonempty pre-amendment gameplay Schedule cannot migrate"
	return _legacy_invitation_error(snapshot.get("contacts"))


## A pre-amendment Contacts state that has ever ACCEPTED an invitation would need an authenticated
## source receipt this step cannot produce, so it fails closed. A state that already carries the
## source index is post-amendment and is left to normal validation.
##
## Acceptance is DURABLE, and the state moves on: `prepare_resolve_day_end` carries an accepted solo
## or group into RESOLVED_ATTENDED / RESOLVED_MISSED / RESOLVED_RUN_END. Matching only the literal
## "ACCEPTED" would therefore miss every save taken after the day the invitation resolved -- which
## is the common case, not an edge case. The reliable markers are the durable ones the domain module
## itself writes on acceptance: a solo's `reply_transaction_id`, and a group's `replied_ids`.
static func _legacy_invitation_error(contacts: Variant) -> String:
	if typeof(contacts) != TYPE_DICTIONARY:
		return ""
	var state: Dictionary = contacts
	if state.has("schedule_source_receipts"):
		return ""
	var solo: Variant = state.get("solo_actions")
	if typeof(solo) == TYPE_DICTIONARY:
		for action_id: Variant in (solo as Dictionary):
			var record: Variant = (solo as Dictionary)[action_id]
			if typeof(record) != TYPE_DICTIONARY:
				continue
			var solo_record: Dictionary = record
			if solo_record.get("reply_transaction_id") != null \
					or str(solo_record.get("state", "")) in LEGACY_ACCEPTED_STATES:
				return "an accepted legacy invitation has no reconstructable source ancestry"
	var group: Variant = state.get("group_action")
	if typeof(group) == TYPE_DICTIONARY:
		var group_record: Dictionary = group
		var replied: Variant = group_record.get("replied_ids")
		var has_replies := typeof(replied) == TYPE_ARRAY and not (replied as Array).is_empty()
		if has_replies or str(group_record.get("state", "")) in LEGACY_ACCEPTED_STATES:
			return "an accepted legacy group invitation has no reconstructable source ancestry"
	return ""


## Adds exactly the two empty amendment indexes to an EXISTING Contacts bag, and nothing else. Every
## pre-existing member survives byte-identically and no receipt is ever invented.
##
## This never fabricates a Contacts section: a snapshot whose `contacts` member is absent or is not
## an object is left exactly as it was, so the current schema rejects it as it always did. Inventing
## a two-key stub here would turn a previously-rejected document into an accepted one carrying a bag
## that ContactInvitationState.validate_state would refuse.
static func _contacts_with_source_indexes(contacts: Dictionary) -> Dictionary:
	var state: Dictionary = contacts.duplicate(true)
	if not state.has("schedule_source_receipts"):
		state["schedule_source_receipts"] = {}
	if not state.has("sylvia_hospital_witness_receipts"):
		state["sylvia_hospital_witness_receipts"] = {}
	return state


## The single forward chain every snapshot travels, whatever its entry version. Each step emits its
## own shape and hands off; only the final step validates against the current schema.
static func _migrate_snapshot_to_current(snapshot: Dictionary, version: int,
		receipts: Array[Dictionary]) -> Dictionary:
	var working := snapshot
	var current_version := version
	if current_version < V2_SCHEMA_VERSION:
		var to_v2 := migrate_snapshot_v1_to_v2(working)
		if not to_v2.get("ok", false):
			return to_v2
		receipts.append({"migration": "snapshot_v1_to_v2"})
		working = to_v2["value"]["snapshot"]
		current_version = V2_SCHEMA_VERSION
	if current_version < V3_SCHEMA_VERSION:
		var to_v3 := migrate_snapshot_v2_to_v3(working)
		if not to_v3.get("ok", false):
			return to_v3
		receipts.append({"migration": "snapshot_v2_to_v3"})
		working = to_v3["value"]["snapshot"]
		current_version = V3_SCHEMA_VERSION
	if current_version < V4_SCHEMA_VERSION:
		# v3 -> v4 is not a migration step (see UNSUPPORTED_PRE_AMENDMENT_DESKTOP_SCHEMA above): no
		# v1/v2/v3 source carries a desktop member, and none is ever invented here.
		return _fail(UNSUPPORTED_PRE_AMENDMENT_DESKTOP_SCHEMA,
			"a pre-amendment save has no desktop member and cannot be migrated to v4")
	var validated: Dictionary = RUN_SNAPSHOT_SCHEMA.validate(working)
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": {"snapshot": validated["value"]["candidate"]}}

# ---- Legacy Day-8 reconstruction ----

static func migrate_legacy_day8(snapshot: Dictionary, compatible_day7_bundles: Array) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY or typeof(snapshot.get("lifecycle")) != TYPE_DICTIONARY:
		return _fail(&"invalid_snapshot", "snapshot.lifecycle is required")
	var lifecycle: Dictionary = snapshot["lifecycle"]
	if int(lifecycle.get("day", 0)) != 8:
		return _fail(&"not_legacy_day8", "migrate_legacy_day8 expects a Day-8 sentinel")
	var state := str(lifecycle.get("state", ""))
	var ending_plan: Variant = lifecycle.get("ending_plan")

	# Row 1/2: a resolvable ENDING/COMPLETED sentinel with an ending plan.
	if state in ["ENDING", "COMPLETED"] and typeof(ending_plan) == TYPE_DICTIONARY:
		var primary := str((ending_plan as Dictionary).get("ending_id", ""))
		var synchronized: Variant = snapshot.get("synchronized_day7_inputs")
		if primary == "ending.priscilla_lavinia" and typeof(synchronized) == TYPE_DICTIONARY:
			# Row 1: recompute a non-group primary with the group ending as epilogue.
			var recomputed := DATING_ENDING_RULES.recompute_synchronized_primary(synchronized)
			if not recomputed.get("ok", false):
				return recomputed
			return _rebuild_terminal(snapshot, recomputed["value"]["ending_id"],
				recomputed["value"]["epilogue_ending_id"])
		if primary != "ending.priscilla_lavinia" and DATING_ENDING_RULES.is_canonical_ending(primary):
			# Row 2: preserve a valid non-group terminal, pinned to Day 7.
			return _rebuild_terminal(snapshot, primary,
				str((ending_plan as Dictionary).get("epilogue_ending_id", "")))

	# Rows 3/4: fall back to the greatest compatible Day-7 whole bundle.
	var best := _greatest_compatible_bundle(compatible_day7_bundles)
	if not best.is_empty():
		return {"ok": true, "code": &"ok", "value": {
			"resolution": "day7_bundle_fallback",
			"bundle": best,
		}}

	# Row 5: nothing valid and no fallback.
	return _fail(&"no_day8_reconstruction", "no valid terminal and no compatible Day-7 bundle")

static func _rebuild_terminal(snapshot: Dictionary, ending_id: String, epilogue_ending_id: String) -> Dictionary:
	var rebuilt := snapshot.duplicate(true)
	rebuilt.erase("synchronized_day7_inputs")
	var lifecycle: Dictionary = rebuilt["lifecycle"]
	lifecycle["day"] = 7
	lifecycle["state"] = "ENDING"
	lifecycle["active_resolution_plan"] = null
	lifecycle["ending_plan"] = {
		"ending_id": ending_id,
		"epilogue_ending_id": epilogue_ending_id,
		"source_day": 7,
		"playback_stage": "PRIMARY_PENDING",
		"playback_receipts": {},
	}
	rebuilt["lifecycle"] = lifecycle
	return {"ok": true, "code": &"ok", "value": {
		"resolution": "terminal_recomputed",
		"snapshot": rebuilt,
		"ending_id": ending_id,
		"epilogue_ending_id": epilogue_ending_id,
	}}

static func _greatest_compatible_bundle(bundles: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_sequence := -1
	for bundle: Variant in bundles:
		if typeof(bundle) != TYPE_DICTIONARY or typeof((bundle as Dictionary).get("snapshot")) != TYPE_DICTIONARY:
			continue
		# A legacy Day-8 reconstruction is by definition fed legacy bundles, so each candidate
		# travels the same forward chain before it is judged. This never accepts an old shape under
		# a current tag: the chain's final step is the current validator.
		var dispatched := _dispatch_schema(bundle["snapshot"])
		if not dispatched.get("ok", false):
			continue
		var discarded_receipts: Array[Dictionary] = []
		var validated := _migrate_snapshot_to_current(
			bundle["snapshot"], int(dispatched["value"]["schema_version"]), discarded_receipts)
		if not validated.get("ok", false):
			continue
		var candidate: Dictionary = validated["value"].get("snapshot",
			validated["value"].get("candidate"))
		if int(candidate["lifecycle"]["day"]) < 1 or int(candidate["lifecycle"]["day"]) > 7:
			continue
		var sequence := int(candidate["checkpoint_sequence"])
		if sequence > best_sequence:
			best_sequence = sequence
			best = {"checkpoint_kind": str((bundle as Dictionary).get("checkpoint_kind", "")), "snapshot": candidate}
	return best

# ---- Whole-document migration ----

static func migrate_document(raw: Dictionary, expected_locator: Dictionary) -> Dictionary:
	var locator_error := _validate_expected_locator(expected_locator)
	if locator_error != "":
		return _fail(&"invalid_expected_locator", locator_error)
	if typeof(raw.get("current_snapshot")) != TYPE_DICTIONARY \
			or typeof((raw["current_snapshot"] as Dictionary).get("snapshot")) != TYPE_DICTIONARY:
		return _fail(&"invalid_document", "document lacks current_snapshot.snapshot")

	var migration_receipts: Array[Dictionary] = []
	var legacy_run_state := {}
	var legacy_input_mappings := {}

	var migrated_current := _migrate_bundle_snapshot(
		raw["current_snapshot"], migration_receipts, legacy_run_state, legacy_input_mappings)
	if not migrated_current.get("ok", false):
		return migrated_current

	var migrated_journal: Array = []
	for entry: Variant in raw.get("recovery_journal", []):
		if typeof(entry) != TYPE_DICTIONARY:
			return _fail(&"invalid_document", "recovery_journal entries must be objects")
		var migrated_entry := _migrate_bundle_snapshot(entry, migration_receipts, {}, {})
		if not migrated_entry.get("ok", false):
			return migrated_entry
		migrated_journal.append(migrated_entry["value"]["bundle"])

	var document := {
		# LITERAL 4, matching migrate_snapshot_v1_to_v2's own literal-version precedent (dwm-p2r.32
		# Task 6): every current_snapshot/recovery_journal bundle above already had to reach v4 (the
		# v3->v4 boundary rejects unchanged otherwise), so the document itself is always v4 here too.
		"schema_version": V4_SCHEMA_VERSION,
		"kind": str(expected_locator["kind"]),
		"slot_id": expected_locator["slot_id"],
		"save_reason": str(raw.get("save_reason", "")),
		"current_snapshot": migrated_current["value"]["bundle"],
		"recovery_journal": migrated_journal,
	}
	return {"ok": true, "code": &"ok", "value": {
		"document": document,
		"legacy_profile_patch_input": {
			"legacy_run_state": legacy_run_state,
			"legacy_input_mappings": legacy_input_mappings,
		},
		"migration_receipts": migration_receipts,
	}}

static func _migrate_bundle_snapshot(
		bundle: Dictionary,
		receipts: Array[Dictionary],
		legacy_run_state: Dictionary,
		legacy_input_mappings: Dictionary
) -> Dictionary:
	var snapshot: Variant = bundle.get("snapshot")
	if typeof(snapshot) != TYPE_DICTIONARY:
		return _fail(&"invalid_bundle", "bundle.snapshot must be an object")
	var version_dispatch := _dispatch_schema(snapshot)
	if not version_dispatch.get("ok", false):
		return version_dispatch
	# Strip legacy profile-owned members into the profile patch input.
	var working := (snapshot as Dictionary).duplicate(true)
	for legacy_key: String in ["settings", "audio_state", "seen_endings"]:
		if working.has(legacy_key):
			legacy_run_state[legacy_key] = working[legacy_key]
			working.erase(legacy_key)
			receipts.append({"migration": "strip_legacy_profile_member", "member": legacy_key})
	if working.has("visited_lines"):
		legacy_run_state["visited_lines"] = working["visited_lines"]
		working.erase("visited_lines")
		receipts.append({"migration": "strip_legacy_profile_member", "member": "visited_lines"})
	if working.has("input_mappings"):
		var mappings: Variant = working["input_mappings"]
		if typeof(mappings) == TYPE_DICTIONARY:
			for action: Variant in (mappings as Dictionary):
				legacy_input_mappings[str(action)] = (mappings as Dictionary)[action]
		working.erase("input_mappings")
		receipts.append({"migration": "strip_legacy_input_mappings"})

	var result := _migrate_snapshot_to_current(
		working, int(version_dispatch["value"]["schema_version"]), receipts)
	if not result.get("ok", false):
		return result
	var migrated_snapshot: Dictionary = result["value"].get("snapshot", result["value"].get("candidate"))
	return {"ok": true, "code": &"ok", "value": {"bundle": {
		"checkpoint_kind": str(bundle.get("checkpoint_kind", "")),
		"snapshot": migrated_snapshot,
	}}}

static func _dispatch_schema(snapshot: Dictionary) -> Dictionary:
	if not snapshot.has("schema_version"):
		return {"ok": true, "code": &"ok", "value": {"schema_version": 1}}
	var raw_version: Variant = snapshot["schema_version"]
	if typeof(raw_version) == TYPE_FLOAT:
		if not is_finite(raw_version) or raw_version != floorf(raw_version):
			return _fail(&"invalid_schema_version", "schema_version must be integral")
		raw_version = int(raw_version)
	if typeof(raw_version) != TYPE_INT:
		return _fail(&"invalid_schema_version", "schema_version must be a number")
	var version := int(raw_version)
	if version < 1:
		return _fail(&"unsupported_legacy_schema", str(version))
	if version > V4_SCHEMA_VERSION:
		return _fail(&"unsupported_future_schema", str(version))
	return {"ok": true, "code": &"ok", "value": {"schema_version": version}}

static func _validate_expected_locator(locator: Dictionary) -> String:
	var keys: Array = locator.keys()
	keys.sort()
	if keys != ["kind", "slot_id"]:
		return "expected_locator must have exactly kind and slot_id"
	match str(locator["kind"]):
		"slot":
			if typeof(locator["slot_id"]) != TYPE_INT or int(locator["slot_id"]) < 1 or int(locator["slot_id"]) > 7:
				return "slot expected_locator needs slot_id 1..7"
		"quick", "autosave":
			if locator["slot_id"] != null:
				return str(locator["kind"]) + " expected_locator needs a null slot_id"
		_:
			return "unknown expected_locator kind: " + str(locator["kind"])
	return ""

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
