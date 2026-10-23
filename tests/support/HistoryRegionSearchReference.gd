extends "res://scripts/application/run/SaveManagerCheckpointPort.gd"
## Frozen pre-cursor control; only the method below differs from the current production port.
## Source and method are exact UTF-8/LF copies of SOURCE_COMMIT. The method hash includes its
## signature and one final LF, with trailing blank lines omitted. Do not modernize this control.

const SOURCE_COMMIT := "5c3368dbba14475a3749bd71df971bfed353699f"
const PORT_SOURCE_PATH := "scripts/application/run/SaveManagerCheckpointPort.gd"
const PORT_SOURCE_SHA256 := "72d400998c3bc6d9a3b4a7645bfd24a749e34a78eaa140ba73d1b23d6fc20310"
const METHOD_SHA256 := "470919ccd5ff929337c6a0c00185e9082772c97de7f5ce72a3b9e0209dff4617"


## Learn only previously missing history proofs from the full writer's completed durable output.
## Re-emission must occur verbatim in those exact bytes; the journal then checks the still-retained
## value before taking its private copy. A mismatch is only a cache miss, never a new save refusal.
func _remember_written_history(bundles: Array, document_text: String,
		profile: Dictionary = {}) -> void:
	if not profile.is_empty():
		profile["history_proof_entries"] = bundles.size()
		for field: String in ["history_proof_hits", "history_proof_misses", "history_proof_skipped",
				"history_proof_emit_failures", "history_proof_region_misses", "history_proof_learn_attempts",
				"history_proof_learn_successes", "history_proof_lookup_us", "history_proof_emit_us",
				"history_proof_region_us", "history_proof_remember_us"]:
			profile[field] = 0
	for value: Variant in bundles:
		# External documents may keep malformed fallback entries for later recovery diagnostics.
		# Whole-document acceptance does not promise that every historical entry is a snapshot.
		if value is not Dictionary or value.get("snapshot") is not Dictionary:
			_profile_count(profile, "history_proof_skipped")
			continue
		var bundle: Dictionary = value
		var checkpoint_id := str((bundle["snapshot"] as Dictionary).get("checkpoint_id", ""))
		var sub_tick := Time.get_ticks_usec() if not profile.is_empty() else 0
		var proven: bool = not _journal().get_retained_bundle_text(checkpoint_id).is_empty() \
				and not _journal().get_retained_bundle_document(checkpoint_id).is_empty()
		sub_tick = _profile_accumulate_phase(profile, "history_proof_lookup_us", sub_tick)
		if proven:
			_profile_count(profile, "history_proof_hits")
			continue
		_profile_count(profile, "history_proof_misses")
		var emitted: Dictionary = CANONICAL_JSON.stringify(bundle)
		sub_tick = _profile_accumulate_phase(profile, "history_proof_emit_us", sub_tick)
		if not emitted.get("ok", false):
			_profile_count(profile, "history_proof_emit_failures")
			continue
		var text := str(emitted["value"])
		var region_present := document_text.find(text) >= 0
		sub_tick = _profile_accumulate_phase(profile, "history_proof_region_us", sub_tick)
		if region_present:
			var learned: bool = _journal().remember_written_retained_bundle(checkpoint_id, text, bundle)
			_profile_accumulate_phase(profile, "history_proof_remember_us", sub_tick)
			_profile_count(profile, "history_proof_learn_attempts")
			if learned: _profile_count(profile, "history_proof_learn_successes")
		else:
			_profile_count(profile, "history_proof_region_misses")
