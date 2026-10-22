from pathlib import Path
import hashlib, json
src=Path('/workspace/scratch/ba996ff67192/run39745466691/source-audit-inputs/SaveDocumentSchema.gd').read_text()
assert hashlib.sha256(src.encode()).hexdigest()=='9d8864e32e4fa8cead3422452cbd3edd1c3eaada1b352ff987d9d27ed1299c7e'
s=src
changes=[]
def replace(a,b):
 global s
 assert s.count(a)==1,(a,s.count(a))
 s=s.replace(a,b)
 changes.append((a,b))
replace('"recovery_journal": (_proven_entries(proven_journal) if proven\n\t\t\telse RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(journal)),','"recovery_journal": (_profile_compose_build_journal(journal, proven_journal, proven, profile)),')
replace('\t\t\tvar proof_error := _scene_proof_error(journal, proven_journal)','\t\t\tvar proof_tick := Time.get_ticks_usec() if not profile.is_empty() else 0\n\t\t\tvar proof_error := _scene_proof_error(journal, proven_journal)\n\t\t\t_profile_phase(profile, "document_schema_proof_equality_us", proof_tick)')
replace('_scene_journal_error(document.current_snapshot, document.recovery_journal)','_profile_scene_journal_error(document.current_snapshot, document.recovery_journal, profile, "document_schema")')
replace('\t\t\tvar proof_error := _scene_proof_error(candidate.recovery_journal, proven_journal)','\t\t\tvar proof_tick := Time.get_ticks_usec() if not profile.is_empty() else 0\n\t\t\tvar proof_error := _scene_proof_error(candidate.recovery_journal, proven_journal)\n\t\t\t_profile_phase(profile, "outgoing_schema_proof_equality_us", proof_tick)')
replace('\t\tvar composed: Array = []','\t\tvar composition_tick := Time.get_ticks_usec() if not profile.is_empty() else 0\n\t\tvar composed: Array = []')
replace('\t\tcandidate["recovery_journal"] = composed','\t\tcandidate["recovery_journal"] = composed\n\t\t_profile_phase(profile, "outgoing_schema_journal_composition_us", composition_tick)')
replace('_scene_journal_error(candidate.current_snapshot, composed)','_profile_scene_journal_error(candidate.current_snapshot, composed, profile, "outgoing_schema")')
# Ordinary/non-proven validation remains untouched. The core's extra arguments have disabled defaults.
replace('static func _scene_journal_error(current: Dictionary, journal: Array) -> String:', 'static func _scene_journal_error(current: Dictionary, journal: Array,\n\t\tprofile: Dictionary = {}, phase: String = "") -> String:')
replace('\t\tvar checked := _validate_bundle(raw)','\t\tvar checked := _profile_validate_scene_journal_bundle(raw, profile, phase)')
helpers='''## Opt-in nested observations only: none of these values enter a save candidate.
## A missing return produces no completed timing. Parent and child durations are not additive.
static func _profile_compose_build_journal(journal: Array, proofs: Array, proven: bool,
		profile: Dictionary) -> Array:
	var started := Time.get_ticks_usec() if not profile.is_empty() else 0
	var composed: Array = (_proven_entries(proofs) if proven
		else RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(journal))
	_profile_phase(profile, "document_schema_journal_composition_us", started)
	return composed

static func _profile_scene_journal_error(current: Dictionary, journal: Array,
		profile: Dictionary, phase: String) -> String:
	if profile.is_empty(): return _scene_journal_error(current, journal)
	profile[phase + "_journal_inclusive_nested"] = true
	profile[phase + "_journal_entries"] = []
	profile[phase + "_journal_bundle_us"] = 0
	profile[phase + "_journal_input_count"] = journal.size()
	profile[phase + "_journal_current"] = _profile_bundle_labels(current)
	var started := Time.get_ticks_usec()
	var error := _scene_journal_error(current, journal, profile, phase)
	var elapsed := Time.get_ticks_usec() - started
	profile[phase + "_scene_journal_us"] = elapsed
	# Residual includes cross-entry checks, labels and diagnostic bookkeeping, not only checks.
	profile[phase + "_journal_checks_and_observation_us"] = elapsed - int(profile[phase + "_journal_bundle_us"])
	profile[phase + "_scene_journal_ok"] = error.is_empty()
	return error

static func _profile_validate_scene_journal_bundle(raw: Dictionary,
		profile: Dictionary, phase: String) -> Dictionary:
	if profile.is_empty(): return _validate_bundle(raw)
	var started := Time.get_ticks_usec()
	var checked := _validate_bundle(raw)
	var elapsed := Time.get_ticks_usec() - started
	var records: Array = profile[phase + "_journal_entries"]
	var record := _profile_bundle_labels(raw)
	record["ordinal"] = records.size()
	record["elapsed_us"] = elapsed
	record["ok"] = bool(checked.get("ok", false))
	records.append(record)
	profile[phase + "_journal_bundle_us"] = int(profile[phase + "_journal_bundle_us"]) + elapsed
	return checked

static func _profile_bundle_labels(raw: Dictionary) -> Dictionary:
	var record := {}
	# Read only existing scalars, defensively; no normalization, copy, hash or owner call.
	var snapshot: Variant = raw.get("snapshot")
	if snapshot is Dictionary:
		if typeof(snapshot.get("checkpoint_sequence")) == TYPE_INT:
			record["checkpoint_sequence"] = snapshot.checkpoint_sequence
		var lifecycle: Variant = snapshot.get("lifecycle")
		if lifecycle is Dictionary:
			var state: Variant = lifecycle.get("state")
			if typeof(state) in [TYPE_STRING, TYPE_STRING_NAME] and String(state) in RUN_SNAPSHOT_SCHEMA.LIFECYCLE_STATES:
				record["lifecycle_state"] = String(state)
			var ending_plan: Variant = lifecycle.get("ending_plan")
			if ending_plan is Dictionary:
				var stage: Variant = ending_plan.get("playback_stage")
				if typeof(stage) in [TYPE_STRING, TYPE_STRING_NAME] and String(stage) in RUN_SNAPSHOT_SCHEMA.PLAYBACK_SEQUENCE:
					record["playback_stage"] = String(stage)
	return record

'''
needle='## These subphases are nested inside the checkpoint port\'s inclusive schema timers.\n'
replace(needle,helpers+needle)
out=Path('/workspace/scratch/62aa7fb5632e/candidate/scripts/infrastructure/save/SaveDocumentSchema.gd');out.write_text(s)
# Remove exactly the recorded observation transformations, in reverse order.
restored=s
for a,b in reversed(changes):
 assert restored.count(b)==1
 restored=restored.replace(b,a)
assert restored==src
Path('/workspace/scratch/62aa7fb5632e/candidate/transformation-verification.json').write_text(json.dumps({'baseline_sha256':hashlib.sha256(src.encode()).hexdigest(),'candidate_sha256':hashlib.sha256(s.encode()).hexdigest(),'reversible_transformations':len(changes),'exact_baseline_reconstruction':True},indent=2)+'\n')
