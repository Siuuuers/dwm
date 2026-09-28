class_name SaveManagerCheckpointPort
extends RefCounted

## Production checkpoint port bridging DayResolutionCoordinator to
## SaveManager's CheckpointJournal and isolated storage
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 6).

const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")
const DESKTOP_CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")

## Consequence stage checkpoints are transient same-process retry state. Source-action and completed
## post-result Autosaves remain the cross-process recovery boundaries; legacy sidecars are never read,
## reconciled, rewritten, or removed.
const GATE_METHODS: Array[String] = [
	"acquire", "release", "guard_external", "is_active", "get_active_owner",
	"is_internal_owner_active", "latch_fatal", "is_fatal_latched",
]
const CHECKPOINT_INPUT_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint",
	"route_id", "snapshot_input",
]
const DISK_WRITES := [
	{"kind": &"none", "reason": &"stage"},
	{"kind": &"autosave", "reason": &"day_start"},
	{"kind": &"autosave", "reason": &"ending"},
	# The Minesweeper pre-board autosave must be durable BEFORE a round is consumed or the save
	# lock acquired (dwm-p2r.9 Plan 06 Task 2). Both layers beneath this port already carry the
	# vocabulary -- CheckpointJournal.SEMANTIC_KINDS lists "pre_board" and
	# SaveDocumentSchema.AUTOSAVE_REASONS lists "pre_board" -- so only this enumeration was
	# missing the pairing. Reusing "day_start" instead would mislabel the durable document.
	{"kind": &"autosave", "reason": &"pre_board"},
	{"kind": &"autosave", "reason": &"automatic"},
]
const AUTOSAVE_RELATIVE_PATH := "autosave.json"
# Envelope placeholders for the spliced autosave bundles. The leading/trailing C0 control keeps a
# sentinel off the canonical writer's native-encoder path, and no saved string can collide with a
# token's position because the envelope carries nothing but these sentinels and fixed keys.
const SPLICE_SENTINEL_CURRENT := "\u0001dwm-splice-current\u0001"
const SPLICE_SENTINEL_JOURNAL := "\u0001dwm-splice-journal-%d\u0001"

var _gate: Object = null
var _save_manager: Object = null
var _desktop_context_provider: Object = null
# Diagnostic counters only; never included in a candidate or persisted document.
var _profile_text_validator_calls := 0
var _profile_text_validator_us := 0
# One synchronous prepare/commit may reuse validation of its physically read preimage.
# Neither caller candidates nor later actions can seed this private exact-text proof.
var _prepared_text_validations: Dictionary = {}
var _prepared_validation_checkpoint := ""
var _prepared_validation_frame := -1
# dwm-634.2: texts validated during a commit whose reread matched and whose journal committed,
# keyed by exact text. Validation is a pure function of the text, so a proven text stays proven
# until a capability change, a reconfiguration or a rollback forgets it. Bounded to the last three
# texts, normally the current, previous and older backup documents.
const PROVEN_DOCUMENT_LIMIT := 3
var _proven_document_validations: Dictionary = {}
var _proven_document_order: Array[String] = []
# Recovery checkpoints protect retries only while the current player action is executing. Source
# and completed post-result Autosaves retain the last fully saved player action; after a crash, the
# interrupted action may replay once.
var _transient_consequence_document := {"records": {}, "abandoned": {}}
# Detached transient records issued by prepare_consequence_checkpoint(). Unchanged records reuse
# this proof; cold records must reproduce exactly through the same side-effect-free builder.
var _issued_transient_records: Dictionary = {}
var _issued_transient_order: Array[String] = []



func configure_desktop_context_provider(provider: Object) -> Dictionary:
	_clear_prepared_text_validation()
	# One Bootstrap-owned DesktopAppHostState supplies the persisted active_app_id. A second
	# direct configuration with the same object is idempotent; a different object is rejected.
	if provider == null or not provider.has_method("capture_persistent_state"):
		return _fail(&"invalid_desktop_context_provider", "provider must expose capture_persistent_state")
	if _desktop_context_provider != null:
		if provider == _desktop_context_provider:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"desktop_provider_already_configured", "a desktop context provider is already configured")
	_desktop_context_provider = provider
	return {"ok": true, "code": &"ok",
		"value": {"provider_instance_id": _desktop_context_provider.get_instance_id()}, "receipt": {}}

func _init(save_manager: Object = null) -> void:
	_save_manager = save_manager

func configure_fatal_latch(gate: Object) -> Dictionary:
	_clear_prepared_text_validation()
	_forget_proven_documents()
	if gate == null or not gate.has_signal("capability_changed") or not _has_all_methods(gate):
		return {"ok": false, "code": &"invalid_mutation_gate", "message": "gate contract incomplete"}
	if _gate != null:
		if gate == _gate:
			return {"ok": true, "code": &"ok",
				"value": {"gate_instance_id": _gate.get_instance_id(), "already_configured": true},
				"receipt": {}}
		return {"ok": false, "code": &"mutation_gate_already_configured", "message": ""}
	_gate = gate
	if _gate.has_signal("transaction_released"):
		_gate.connect("transaction_released", _clear_prepared_text_validation)
	_gate.connect("capability_changed", _on_validation_capability_changed)
	return {"ok": true, "code": &"ok",
		"value": {"gate_instance_id": _gate.get_instance_id(), "already_configured": false},
		"receipt": {}}

func preview_checkpoint_id(run_id: String) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if run_id.is_empty():
		return _fail(&"invalid_run_id", "run_id must be nonempty")
	var peeked: Dictionary = _journal().peek_next_sequence(run_id)
	if not peeked.get("ok", false):
		return peeked
	return {"ok": true, "code": &"ok",
		"value": {"checkpoint_id": "%s:%d" % [run_id, int(peeked["value"]["checkpoint_sequence"])]},
		"receipt": {}}

func capture() -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var captured: Dictionary = _journal().capture_state()
	return {"ok": true, "code": &"ok", "value": {"backup": captured["value"]["backup"]}}

func prepare(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary:
	_clear_prepared_text_validation()
	# Permanent env-gated prepare-side profile (dwm-634.3): one boolean per phase while unset,
	# the same gate, helpers and output line as commit()'s `save_checkpoint` record.
	var profile := {}
	var tick := 0
	if OS.get_environment("DWM_CHECKPOINT_PROFILE") == "1":
		_profile_text_validator_calls = 0
		_profile_text_validator_us = 0
		tick = Time.get_ticks_usec()
		profile = {"scope": "save_checkpoint_prepare", "checkpoint_kind": str(checkpoint_kind),
			"autosave": str(disk_write.get("kind", "")) == "autosave", "_started_us": tick,
			"diagnostics_version": 2}
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var keys: Array = checkpoint_inputs.keys()
	keys.sort()
	var expected := CHECKPOINT_INPUT_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return _fail(&"invalid_checkpoint_inputs", "unexpected input keys: " + str(keys))
	if disk_write not in DISK_WRITES:
		return _fail(&"invalid_disk_write", str(disk_write))
	var snapshot_input: Variant = checkpoint_inputs["snapshot_input"]
	if typeof(snapshot_input) != TYPE_DICTIONARY \
			or typeof((snapshot_input as Dictionary).get("lifecycle")) != TYPE_DICTIONARY:
		return _fail(&"invalid_checkpoint_inputs", "snapshot_input.lifecycle is required")
	var run_id := str((snapshot_input["lifecycle"] as Dictionary).get("run_id", ""))
	var peeked: Dictionary = _journal().peek_next_sequence(run_id)
	if not peeked.get("ok", false):
		return peeked
	# When configured, the desktop host is the sole source of the persisted active_app_id;
	# the caller-supplied value is ignored (dwm-p2r.9 Plan 02 Task 1).
	var active_app_id: Variant = checkpoint_inputs["active_app_id"]
	if _desktop_context_provider != null:
		active_app_id = _desktop_context_provider.capture_persistent_state().get("active_app_id", null)
	# T4-AF.18 / T4-AJ.C item 49: the live ScheduleView is checkpointed from the one restore
	# participant SaveManager already holds; absent participant, today's behaviour is unchanged;
	# no open day fails closed. A day-advance checkpoint's lifecycle NAMES the next day before
	# the live ScheduleViewController has opened it. GameStateDayResolutionPort._checkpoint_inputs
	# already resolves this same shape for committed_schedule -- a day the owner has not entered
	# gets its canonical empty aggregate -- so the RECORDED day, not the live day, is what gets
	# checkpointed. Mirroring ScheduleViewController.open_day()'s day-boundary law, the +1 day
	# derives a fresh empty view with the append-only condition_departure_receipts ledger carried
	# over. ANY forward gap derives -- the live controller is adopted to the new day only by
	# Task 5 / Task 7 work after each checkpoint, so in continuous play it can lag by several days
	# (RULING T4-AK, review P C1) -- while a recorded day BEHIND the captured view is left to
	# RunSnapshotSchema.build()'s own day binding to refuse.
	if not (snapshot_input as Dictionary).has("schedule_view") and _restore_participants().has("schedule_view"):
		var captured: Dictionary = _restore_participants()["schedule_view"].capture()
		if not captured.get("ok", false):
			return captured
		var backup: Variant = (captured.get("value", {}) as Dictionary).get("backup")
		if typeof(backup) != TYPE_DICTIONARY:
			return _fail(&"invalid_checkpoint_inputs", "schedule_view: no open day to checkpoint")
		var lifecycle: Dictionary = snapshot_input["lifecycle"]
		var recorded_day: int = int(lifecycle.get("day", 0))
		var backup_day: int = int((backup as Dictionary).get("day", 0))
		var merged_view: Dictionary = (backup as Dictionary).duplicate(true)
		if recorded_day > backup_day:
			var made: Dictionary = VIEW_STATE.make_empty(
				recorded_day, str(lifecycle.get("causal_day_instance", "")))
			if not made.get("ok", false):
				return made
			var derived_view: Dictionary = (made["value"] as Dictionary)["view"]
			var ledger: Variant = (backup as Dictionary).get("condition_departure_receipts")
			if typeof(ledger) != TYPE_DICTIONARY:
				return _fail(&"invalid_checkpoint_inputs",
					"schedule_view: captured view carries no departure ledger")
			derived_view["condition_departure_receipts"] = (ledger as Dictionary).duplicate(true)
			merged_view = derived_view
		snapshot_input = (snapshot_input as Dictionary).duplicate(true)
		snapshot_input["schedule_view"] = merged_view
	# The final captured view may be an uncommitted draft. Bind its retained live registry
	# on the detached checkpoint only; strict saved-document validation remains unchanged.
	var view_participant: Object = _restore_participants().get("schedule_view")
	if is_instance_valid(view_participant) and view_participant.has_method("compose_live_checkpoint_input"):
		snapshot_input = view_participant.compose_live_checkpoint_input(snapshot_input)
	tick = _profile_phase(profile, "view_capture_us", tick)
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(
		snapshot_input, checkpoint_inputs["dialogic_checkpoint"],
		str(checkpoint_inputs["route_id"]), active_app_id,
		checkpoint_inputs["audio_context"], int(checkpoint_inputs["content_version"]),
		int(peeked["value"]["checkpoint_sequence"]))
	tick = _profile_phase(profile, "run_snapshot_build_us", tick)
	if not built.get("ok", false):
		return _profile_result(profile, built)
	# `RunSnapshotSchema.build()` returns the candidate its own `validate()` produced, so the journal is
	# handed that exact object as the proof it was already validated (identity, not a flag).
	var prepared_record: Dictionary = _journal().prepare_record(built["value"]["snapshot"], checkpoint_kind,
		built["value"]["snapshot"])
	tick = _profile_phase(profile, "journal_prepare_us", tick)
	if not prepared_record.get("ok", false):
		return _profile_result(profile, prepared_record)
	var journal_candidate: Dictionary = prepared_record["value"]["candidate"]
	var checkpoint_id := str(built["value"]["snapshot"]["checkpoint_id"])
	var candidate := {
		"journal_candidate": journal_candidate,
		"checkpoint_id": checkpoint_id,
		"autosave_document": null,
		"storage_backup": null,
	}
	var validated_texts := {}
	if str(disk_write["kind"]) == "autosave":
		var reason := str(disk_write["reason"])
		var projected_earlier: Array = journal_candidate["earlier"]
		# Every proven earlier bundle was validated, normalized and byte-proven by a completed
		# durable write, and the journal still holds the bundle those proven bytes describe. Hand
		# those back as `build()`'s per-entry proofs so it does not re-walk the whole retained
		# history (~150 KB per bundle) a second time per save. A bundle the journal remembers no
		# document for -- new memory-only history, a journal seeded from disk, restored, reset, or a commit
		# refused the memory because the outgoing bundle had been edited -- leaves the WHOLE journal
		# unproven: a partial proof set says nothing about any entry, exactly like the splice.
		var proven_journal: Array = []
		var sub_tick := Time.get_ticks_usec() if not profile.is_empty() else 0
		if not profile.is_empty():
			profile["document_proof_entries"] = projected_earlier.size()
			profile["document_proof_hits"] = 0
			profile["document_proof_misses"] = 0
		for entry: Variant in projected_earlier:
			var proof: Dictionary = _journal().get_retained_bundle_document(
				str(((entry as Dictionary)["snapshot"] as Dictionary)["checkpoint_id"]))
			if proof.is_empty():
				_profile_count(profile, "document_proof_misses")
				proven_journal.clear()
				break
			_profile_count(profile, "document_proof_hits")
			proven_journal.append(proof)
		sub_tick = _profile_phase(profile, "document_proof_lookup_us", sub_tick)
		var document: Dictionary = SAVE_DOCUMENT_SCHEMA.build(
			&"autosave", null, StringName(reason), journal_candidate["current"], projected_earlier,
			{}, proven_journal, profile)
		_profile_phase(profile, "document_schema_build_us", sub_tick)
		tick = _profile_phase(profile, "document_build_us", tick)
		if not document.get("ok", false):
			return _profile_result(profile, document)
		candidate["autosave_document"] = document["value"]
		var backup := _capture_storage_backup(AUTOSAVE_RELATIVE_PATH, validated_texts)
		tick = _profile_phase(profile, "backup_us", tick)
		if not backup.get("ok", false):
			return _profile_result(profile, backup)
		candidate["storage_backup"] = backup["value"]["descriptor"]
	_prepared_text_validations = validated_texts
	_prepared_validation_checkpoint = checkpoint_id
	_prepared_validation_frame = Engine.get_process_frames()
	return _profile_result(profile, {"ok": true, "code": &"ok",
		"value": {"candidate": candidate, "checkpoint_id": checkpoint_id}})

func commit(candidate: Dictionary) -> Dictionary:
	var validated_texts := _take_prepared_text_validation(candidate)
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if typeof(candidate.get("journal_candidate")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "candidate was not issued by this port")
	var profile := {}
	var tick := 0
	if OS.get_environment("DWM_CHECKPOINT_PROFILE") == "1":
		tick = Time.get_ticks_usec()
		var history: Variant = candidate["journal_candidate"].get("earlier")
		profile = {"scope": "save_checkpoint", "checkpoint_id": str(candidate.get("checkpoint_id", "")),
			"autosave": candidate.get("autosave_document") != null,
			"history_bundles": history.size() if history is Array else -1, "_started_us": tick,
			"diagnostics_version": 2}
	var proven_current_text := ""
	var proven_current_document: Dictionary = {}
	var written_history: Array = []
	var written_document_text := ""
	if candidate.get("autosave_document") != null:
		var autosave_document: Variant = candidate["autosave_document"]
		var document_text := ""
		# The journal-owned bundles whose committed texts the splice writes, in written order.
		var proven_journal: Array = []
		var proven_documents: Array = []
		var spliced := false
		# Only the NEW current bundle is canonicalised here; the earlier bundles are byte-identical
		# copies of what their own commits already wrote and proved. A non-object outgoing value
		# takes the whole-document path below exactly as before.
		if typeof(autosave_document) == TYPE_DICTIONARY \
				and typeof((autosave_document as Dictionary).get("current_snapshot")) == TYPE_DICTIONARY:
			var current_emitted: Dictionary = CANONICAL_JSON.stringify(
				(autosave_document as Dictionary)["current_snapshot"])
			if current_emitted.get("ok", false):
				proven_current_text = str(current_emitted["value"])
				document_text = _splice_autosave_text(autosave_document as Dictionary, proven_current_text,
					proven_journal, proven_documents)
				spliced = not document_text.is_empty()
		tick = _profile_phase(profile, "stringify_us", tick)
		if document_text.is_empty():
			# A partial splice proves nothing about the bytes the whole-document writer emits below.
			proven_journal.clear()
			proven_documents.clear()
			# Some earlier bundle has no remembered text (a journal seeded from disk, restored or
			# reset): the whole-document writer remains the authority for these bytes, and this
			# bundle's own text is only reusable later if it appears verbatim in them.
			var canonical: Dictionary = CANONICAL_JSON.stringify(autosave_document)
			if not canonical.get("ok", false):
				return _profile_result(profile, _fail(&"canonical_serialization_failed", ""))
			document_text = str(canonical["value"])
			if proven_current_text != "" and document_text.find(proven_current_text) < 0:
				proven_current_text = ""
		tick = _profile_phase(profile, "splice_us", tick)
		if not profile.is_empty():
			profile["document_bytes"] = document_text.to_utf8_buffer().size() + 1
			profile["journal_spliced"] = spliced
			tick = Time.get_ticks_usec()
		var outgoing_text := document_text + "\n"
		# Canonical emission proves the text round-trips exactly. Validate this detached
		# value now (the caller may have edited it since prepare), preserving JSON's
		# StringName conversion. Only successful proof can seed this exact-text cache.
		var sub_tick := Time.get_ticks_usec() if not profile.is_empty() else 0
		var normalized: Variant = _normalize_outgoing_document(candidate["autosave_document"], spliced)
		sub_tick = _profile_phase(profile, "outgoing_normalize_us", sub_tick)
		if normalized is Dictionary:
			# On the splice path the journal entries in these bytes came from the journal's remembered
			# texts, not from this document, so the lease for them is composed from the bundles those
			# texts belong to. Every other path validates the outgoing document verbatim, as before.
			var checked := {}
			if spliced:
				checked = SAVE_DOCUMENT_SCHEMA._validate_outgoing_document_proofs(
					normalized, proven_journal, proven_documents, profile)
			else:
				checked = SAVE_DOCUMENT_SCHEMA.validate(normalized, profile)
			sub_tick = _profile_phase(profile, "outgoing_validate_us", sub_tick)
			if not profile.is_empty(): profile["outgoing_validation_ok"] = bool(checked.get("ok", false))
			if checked.get("ok", false):
				validated_texts[outgoing_text] = {"ok": true, "code": &"ok", "value": checked["value"]["candidate"]}
				var checked_current: Dictionary = checked["value"]["candidate"]["current_snapshot"]
				# Equal JSON-shaped values may differ in container types, but a numeric change
				# cannot authorize a document proof for the original emitted text.
				if CANONICAL_JSON._deep_same(normalized["current_snapshot"], checked_current):
					proven_current_document = checked_current
				if not spliced:
					# Capture a detached copy of the normalized history the full writer emitted.
					# It grants no reusable proof until all durability steps succeed.
					written_history = (normalized["recovery_journal"] as Array).duplicate(true)
					written_document_text = document_text
			_profile_phase(profile, "outgoing_history_capture_us", sub_tick)
		# Failed proof and all unknown physical bytes retain the original strict parser
		# and storage refusal path. Physical writes, hashes and final reread are unchanged.
		tick = _profile_phase(profile, "outgoing_schema_us", tick)
		# dwm-634.3: neither storage nor the reread below reads the value of these validations, so
		# both are answered by the witness, which copies no already-proven candidate.
		var witness := _witness_document_text_validator.bind(validated_texts)
		var written: Dictionary = _storage().write_atomic(
			AUTOSAVE_RELATIVE_PATH, outgoing_text, witness)
		tick = _profile_phase(profile, "write_atomic_us", tick)
		if not written.get("ok", false):
			return _profile_result(profile, written)
		var re_read: Dictionary = _storage().read_text(AUTOSAVE_RELATIVE_PATH)
		tick = _profile_phase(profile, "reread_us", tick)
		if not re_read.get("ok", false):
			return _profile_result(profile, re_read)
		var reread_text := str(re_read["value"])
		var validated: Dictionary = witness.call(reread_text)
		var valid: bool = reread_text == outgoing_text and validated.get("ok", false)
		tick = _profile_phase(profile, "reread_validate_us", tick)
		if not valid:
			return _profile_result(profile, _fail(&"reread_mismatch", AUTOSAVE_RELATIVE_PATH))
	var committed: Dictionary = _journal().commit_prepared(candidate["journal_candidate"])
	tick = _profile_phase(profile, "journal_us", tick)
	if not committed.get("ok", false):
		return _profile_result(profile, committed)
	# The reread above proved these exact bytes on disk, so the journal may reuse this bundle's region
	# for as long as it keeps the bundle as its own retained private duplicate -- but only while that
	# text still DESCRIBES the bundle the journal just retained. `SaveDocumentSchema.build()` composes
	# the document's current bundle as its own object (`RunSnapshotSchema.validate()`'s fresh
	# candidate), so a caller may edit the outgoing bundle in place between prepare and commit: those
	# edited bytes are written and accepted, which is the law, while `commit_prepared()` retains the
	# UNEDITED candidate under the same id. Remembering the edited text would hand the next splice
	# bytes for a bundle the journal does not hold, and that save composes its lease from the retained
	# bundle, so lease and bytes would diverge. Identity cannot answer this -- the edit is in place --
	# so compare deeply, JOURNAL side first: `_deep_same()` folds StringName into String on its LEFT
	# operand only, and a retained candidate keeps the engine text (a desktop pending stage, an
	# active_app_id) that `build()` converted for the document; it also refuses TYPE_INT against
	# TYPE_FLOAT, so a widened number counts as a difference. Godot's own `==` cannot be used here: it
	# does not recurse into nested containers (hence `Dictionary.recursive_equal()`), and these two
	# bundles never share their nested `snapshot`. When they differ nothing is remembered and the next
	# save falls back to the whole-document writer, which is always correct. The document bundle
	# remembered beside the text rides the same gate for the same reason: the next save composes its
	# journal entry for this id from that object, so bytes an edit produced must seed neither.
	var proof_tick := Time.get_ticks_usec() if not profile.is_empty() else 0
	var current_matches := proven_current_text != "" and CANONICAL_JSON._deep_same(
			(candidate["journal_candidate"] as Dictionary)["current"],
			(candidate["autosave_document"] as Dictionary)["current_snapshot"])
	proof_tick = _profile_phase(profile, "journal_current_compare_us", proof_tick)
	if not profile.is_empty():
		profile["journal_current_proof_available"] = proven_current_text != ""
		profile["journal_current_proof_matches"] = current_matches
		profile["journal_current_learn_attempts"] = 0
		profile["journal_current_learn_successes"] = 0
	if current_matches:
		var learned: bool = _journal().remember_committed_bundle_text(
			str(committed["value"]["checkpoint_id"]), proven_current_text,
			proven_current_document)
		_profile_count(profile, "journal_current_learn_attempts")
		if learned: _profile_count(profile, "journal_current_learn_successes")
	proof_tick = _profile_phase(profile, "journal_current_remember_us", proof_tick)
	_remember_written_history(written_history, written_document_text, profile)
	_profile_phase(profile, "journal_history_learning_us", proof_tick)
	tick = _profile_phase(profile, "journal_proof_us", tick)
	_remember_proven_documents(validated_texts)
	_profile_phase(profile, "document_proof_remember_us", tick)
	return _profile_result(profile, {"ok": true, "code": &"ok",
		"value": {"checkpoint_id": str(committed["value"]["checkpoint_id"])}})


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
	# The full writer emits these bundles in order. Continue after the last matched region so
	# newly learned history does not repeatedly scan the preceding retained document. A helper
	# caller may supply reordered or repeated entries, so a miss still checks the whole text.
	var region_cursor := 0
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
		var region_at := document_text.find(text, region_cursor)
		if region_at < 0 and region_cursor > 0:
			region_at = document_text.find(text)
		var region_present := region_at >= 0
		if region_present:
			region_cursor = region_at + text.length()
		sub_tick = _profile_accumulate_phase(profile, "history_proof_region_us", sub_tick)
		if region_present:
			var learned: bool = _journal().remember_written_retained_bundle(checkpoint_id, text, bundle)
			_profile_accumulate_phase(profile, "history_proof_remember_us", sub_tick)
			_profile_count(profile, "history_proof_learn_attempts")
			if learned: _profile_count(profile, "history_proof_learn_successes")
		else:
			_profile_count(profile, "history_proof_region_misses")


## Composes the outgoing autosave text from the new current bundle's canonical text plus the
## journal-remembered canonical text of every earlier bundle, splicing them into one tiny
## canonicalised envelope. The envelope substitutes a C0-prefixed sentinel string for each spliced
## bundle; because its only string values are those sentinels and the document's own fixed
## discriminators, every sentinel token appears in the envelope text exactly once at a known offset.
## Splicing therefore works by offset, never by text replacement, so a bundle whose own text carries
## a sentinel token cannot displace anything. Returns "" when the bytes cannot be composed this way
## -- a missing remembered text, or an envelope that does not carry each token exactly once -- and
## the caller then stringifies the whole document instead.
## `proven_journal` is filled, in written order, with the journal's own bundle for each entry whose
## remembered text this splice writes -- the only in-memory objects that describe these bytes.
## `proven_documents` collects the normalized document proofs under those same ids/text lifetimes;
## an empty entry preserves the raw-proof fallback. Neither output is trusted on a failed splice.
func _splice_autosave_text(document: Dictionary, current_text: String,
		proven_journal: Array = [], proven_documents: Array = []) -> String:
	var earlier: Variant = document.get("recovery_journal")
	if typeof(earlier) != TYPE_ARRAY:
		return ""
	var replacements: Array = [[SPLICE_SENTINEL_CURRENT, current_text]]
	var sentinels: Array = []
	for index: int in range((earlier as Array).size()):
		var bundle: Variant = (earlier as Array)[index]
		if typeof(bundle) != TYPE_DICTIONARY \
				or typeof((bundle as Dictionary).get("snapshot")) != TYPE_DICTIONARY:
			return ""
		var checkpoint_id := str(((bundle as Dictionary)["snapshot"] as Dictionary).get("checkpoint_id", ""))
		var remembered: String = _journal().get_retained_bundle_text(checkpoint_id)
		if remembered.is_empty():
			return ""
		var retained: Dictionary = _journal().get_retained_bundle(checkpoint_id)
		if retained.is_empty():
			return ""
		proven_journal.append(retained)
		proven_documents.append(_journal().get_retained_bundle_document(checkpoint_id))
		var sentinel: String = SPLICE_SENTINEL_JOURNAL % index
		sentinels.append(sentinel)
		replacements.append([sentinel, remembered])
	var envelope := document.duplicate()
	envelope["current_snapshot"] = SPLICE_SENTINEL_CURRENT
	envelope["recovery_journal"] = sentinels
	var emitted: Dictionary = CANONICAL_JSON.stringify(envelope)
	if not emitted.get("ok", false):
		return ""
	var envelope_text := str(emitted["value"])
	var spans: Array = []
	for replacement: Array in replacements:
		var token_emitted: Dictionary = CANONICAL_JSON.stringify(replacement[0])
		if not token_emitted.get("ok", false):
			return ""
		var token := str(token_emitted["value"])
		var at := envelope_text.find(token)
		if at < 0 or envelope_text.find(token, at + 1) >= 0:
			return ""
		spans.append([at, at + token.length(), str(replacement[1])])
	spans.sort_custom(func(left: Array, right: Array) -> bool: return int(left[0]) < int(right[0]))
	var parts := PackedStringArray()
	var cursor := 0
	for span: Array in spans:
		parts.append(envelope_text.substr(cursor, int(span[0]) - cursor))
		parts.append(str(span[2]))
		cursor = int(span[1])
	parts.append(envelope_text.substr(cursor))
	return "".join(parts)


static func _profile_phase(profile: Dictionary, phase: String, started_us: int) -> int:
	if profile.is_empty(): return 0
	var now := Time.get_ticks_usec()
	profile[phase] = now - started_us
	return now

## Sum disjoint calls inside a loop; these remain nested in the inclusive journal proof timer.
static func _profile_accumulate_phase(profile: Dictionary, phase: String, started_us: int) -> int:
	if profile.is_empty(): return 0
	var now := Time.get_ticks_usec()
	profile[phase] = int(profile.get(phase, 0)) + now - started_us
	return now


static func _profile_count(profile: Dictionary, field: String) -> void:
	if not profile.is_empty(): profile[field] = int(profile.get(field, 0)) + 1


func _profile_result(profile: Dictionary, result: Dictionary) -> Dictionary:
	if not profile.is_empty():
		profile["elapsed_us"] = Time.get_ticks_usec() - int(profile["_started_us"])
		profile.erase("_started_us")
		profile["ok"] = bool(result.get("ok", false))
		profile["text_validator_calls_since_prepare"] = _profile_text_validator_calls
		profile["text_validator_us_since_prepare"] = _profile_text_validator_us
		if not profile["ok"]: profile["code"] = str(result.get("code", ""))
		print("DWM_CHECKPOINT_PROFILE " + JSON.stringify(profile))
	return result

func rollback(backup: Dictionary) -> Dictionary:
	_clear_prepared_text_validation()
	_forget_proven_documents()
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var attempts: Array = []
	var journal_backup: Variant = backup.get("journal_backup", backup)
	var journal_restored: Dictionary = _journal().restore_state(journal_backup)
	attempts.append({"owner_id": "checkpoint_journal", "operation": "restore_state", "result": journal_restored})
	var storage_descriptor: Variant = backup.get("storage_backup")
	var storage_ok := true
	if typeof(storage_descriptor) == TYPE_DICTIONARY:
		var descriptor := storage_descriptor as Dictionary
		var relative_path := str(descriptor.get("relative_path", AUTOSAVE_RELATIVE_PATH))
		var storage_result: Dictionary
		# dwm-634.3: rollback reads nothing but `ok` from either result, so the witness answers
		# both. `_forget_proven_documents()` above left nothing proven, so its only hit is the
		# restored text this call itself validates and seeds.
		var witness := _witness_document_text_validator.bind({})
		if bool(descriptor.get("existed", false)):
			storage_result = _storage().write_atomic(
				relative_path, str(descriptor.get("validated_text", "")), witness)
		else:
			# A failed final reread may have invalidated the lease after a first save
			# became durable. Validate that artifact before restoring prior absence.
			storage_result = _storage().reconcile(relative_path, witness)
			if storage_result.get("ok", false):
				storage_result = _storage().remove(relative_path)
		attempts.append({"owner_id": "save_storage", "operation": "rollback", "result": storage_result})
		storage_ok = storage_result.get("ok", false)
	if journal_restored.get("ok", false) and storage_ok:
		return {"ok": true, "code": &"ok"}
	return _fatal_rollback("rollback", str((journal_backup as Dictionary).get("run_id", "")), attempts)

## Builds the canonical stage record and receipt without mutating transient or durable state.
func prepare_consequence_checkpoint(checkpoint_header: Dictionary, stage_candidate: Dictionary,
		proven_recovery_payload_sha256: String = "") -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var prepared := _build_consequence_checkpoint(checkpoint_header, stage_candidate,
		proven_recovery_payload_sha256)
	if not prepared.get("ok", false):
		return prepared
	var value: Dictionary = prepared["value"]
	_remember_issued_transient_record(str(value["checkpoint_receipt"]["receipt_id"]), value["candidate"]["document"])
	return prepared


## One pure construction path for new checkpoints and cold-record self-consistency checks.
## `proven_recovery_payload_sha256` is only ever supplied by a live caller that derived it over these
## exact payload bytes in this frame; the cold/evicted re-derivation callers below deliberately pass
## nothing, so a record read back from disk is still proven in full.
static func _build_consequence_checkpoint(checkpoint_header: Dictionary, stage_candidate: Dictionary,
		proven_recovery_payload_sha256: String = "") -> Dictionary:
	var preimage: Dictionary = DESKTOP_CONSEQUENCE_STATE.checkpoint_content_preimage(checkpoint_header,
		stage_candidate, proven_recovery_payload_sha256)
	if not preimage.get("ok", false):
		return preimage
	var preimage_value: Dictionary = (preimage["value"] as Dictionary)["preimage"]
	var normalized_header: Dictionary = preimage_value["header"]
	var pairing := DESKTOP_CONSEQUENCE_STATE.validate_checkpoint_ordinal_stage(
		int(normalized_header["operation_ordinal"]), str(normalized_header["stage"]))
	if not pairing.get("ok", false):
		return pairing
	var canonical: Dictionary = CANONICAL_JSON.stringify(preimage_value)
	if not canonical.get("ok", false):
		return _fail(&"canonical_serialization_failed", "consequence checkpoint preimage is not canonicalizable")
	# The writer just proved this fully validated state is JSON-representable. Normalize only the
	# StringName subtype that JSON does not preserve; keep integer/float provenance exact.
	var normalized_preimage: Variant = _normalize_json_string_types(preimage_value)
	normalized_header = (normalized_preimage as Dictionary)["header"]
	var content_sha256 := str(canonical["value"]).sha256_text()
	var checkpoint_receipt := {
		"receipt_id": "consequence_checkpoint." + content_sha256,
		"header": normalized_header.duplicate(true),
		"content_sha256": content_sha256,
	}
	# CONFINEMENT: with the normalizer preserving identity this may now BE
	# `preimage_value["stage_candidate"]`, which `checkpoint_content_preimage()` obtained from
	# `_validate_for_preimage()` -- i.e. the `state.duplicate(true)` that validation already detached
	# from the caller's tree, held by nothing else once this function returns. `canonical` above was
	# taken before this line, so `content_sha256` still proves the unattached bytes. The mutation
	# therefore stays inside this port's own private tree, exactly as when a fresh copy was allocated.
	var receipt_attached_candidate: Dictionary = (normalized_preimage as Dictionary)["stage_candidate"]
	var pending: Variant = receipt_attached_candidate.get("pending")
	if typeof(pending) == TYPE_DICTIONARY:
		var pending_dict: Dictionary = pending
		if str(pending_dict.get("stage", "")) not in ["action_prepared", "prepared_checkpointed"]:
			pending_dict["checkpoint_receipt"] = checkpoint_receipt.duplicate(true)
			if pending_dict.get("admission_checkpoint_receipt") == null:
				pending_dict["admission_checkpoint_receipt"] = checkpoint_receipt.duplicate(true)
			receipt_attached_candidate["pending"] = pending_dict
	var key := str(checkpoint_header.get("transaction_id", "")) + ":" + str(normalized_header["operation_ordinal"])
	var record := {
		"key": key,
		"header": (normalized_preimage as Dictionary)["header"],
		"stage_candidate": receipt_attached_candidate,
		"checkpoint_receipt": checkpoint_receipt,
	}
	return {"ok": true, "code": &"ok", "value": {
		"candidate": {"document": record},
		"checkpoint_receipt": checkpoint_receipt,
	}}

## Retains one stage in memory. Identical occupied-slot retries replay; changed bytes conflict.
func commit_consequence_checkpoint(checkpoint_candidate: Dictionary, checkpoint_receipt: Dictionary) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if typeof(checkpoint_candidate.get("document")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "candidate was not issued by prepare_consequence_checkpoint")
	var record: Dictionary = checkpoint_candidate["document"]
	if record.get("checkpoint_receipt") != checkpoint_receipt:
		return _fail(&"checkpoint_receipt_mismatch", "checkpoint_receipt does not match the prepared candidate")
	var receipt_id := str(checkpoint_receipt.get("receipt_id", ""))
	var validated: Dictionary
	if (_issued_transient_records.has(receipt_id)
			and record == (_issued_transient_records[receipt_id] as Dictionary)):
		validated = {"ok": true, "code": &"ok", "value": record.duplicate(true), "canonical_text": ""}
		_touch_issued_transient_record(receipt_id)
	else:
		validated = _validate_transient_consequence_record(record)
		if not validated.get("ok", false):
			return validated
		# Normalization permits StringName aliases, but cannot authorize changed bytes
		# against a record we still own, even after its independent reconstruction succeeds.
		if (_issued_transient_records.has(receipt_id)
				and not CANONICAL_JSON._deep_same(_issued_transient_records[receipt_id], validated["value"])):
			return _fail(&"invalid_candidate", "checkpoint record differs from the issued candidate")
	var normalized: Dictionary = validated["value"]
	var key: String = normalized["key"]
	var records: Dictionary = _transient_consequence_document["records"]
	if records.has(key):
		var existing: Dictionary = records[key]
		var candidate_text := str(validated["canonical_text"])
		if candidate_text.is_empty():
			candidate_text = _canonical_text(normalized)
		if candidate_text == _canonical_text(existing):
			return {"ok": true, "code": &"ok", "value": {"checkpoint_receipt": checkpoint_receipt}}
		return _fail(&"consequence_checkpoint_conflict",
			"a different checkpoint is already retained at " + key)
	records[key] = normalized
	return {"ok": true, "code": &"ok", "value": {"checkpoint_receipt": checkpoint_receipt}}

## Marks an unpromoted transient transaction abandoned without creating another stage record.
func abandon_pending_consequence_checkpoint(transaction_id: String) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_transaction_id", "transaction_id must be nonempty")
	var abandoned: Dictionary = _transient_consequence_document["abandoned"]
	if bool(abandoned.get(transaction_id, false)):
		return {"ok": true, "code": &"ok", "value": {"abandoned": true, "already_abandoned": true}}
	var records: Dictionary = _transient_consequence_document["records"]
	var latest_ordinal := -1
	var latest_stage := ""
	for record_key: String in records.keys():
		var record: Dictionary = records[record_key]
		var header: Dictionary = record["header"]
		if str(header["transaction_id"]) != transaction_id:
			continue
		var ordinal := int(header["operation_ordinal"])
		if ordinal > latest_ordinal:
			latest_ordinal = ordinal
			latest_stage = str(header["stage"])
	if latest_ordinal < 0:
		return _fail(&"consequence_checkpoint_not_found", "no retained checkpoint exists for " + transaction_id)
	if latest_stage not in ["action_prepared", "prepared_checkpointed"]:
		return _fail(&"consequence_checkpoint_not_pre_admission", "abandonment requires an unpromoted pre-admission checkpoint")
	abandoned[transaction_id] = true
	return {"ok": true, "code": &"ok", "value": {"abandoned": true, "already_abandoned": false}}

## Clears retry state only at an explicit successful session boundary.
func clear_transient_consequence_checkpoints() -> Dictionary:
	var records_cleared := (_transient_consequence_document["records"] as Dictionary).size()
	var abandoned_cleared := (_transient_consequence_document["abandoned"] as Dictionary).size()
	_transient_consequence_document = {"records": {}, "abandoned": {}}
	_issued_transient_records = {}
	_issued_transient_order = []
	return {"ok": true, "code": &"ok", "value": {
		"records_cleared": records_cleared, "abandoned_cleared": abandoned_cleared}}


func read_pending_consequence_checkpoint() -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var records: Dictionary = _transient_consequence_document["records"]
	var abandoned: Dictionary = _transient_consequence_document["abandoned"]
	var latest_by_transaction: Dictionary = {}
	for record_key: String in records.keys():
		var record: Dictionary = records[record_key]
		var header: Dictionary = record["header"]
		var transaction_id := str(header["transaction_id"])
		var ordinal := int(header["operation_ordinal"])
		if not latest_by_transaction.has(transaction_id) \
				or ordinal > int((latest_by_transaction[transaction_id]["header"] as Dictionary)["operation_ordinal"]):
			latest_by_transaction[transaction_id] = record
	var pending_transaction_ids: Array[String] = []
	for transaction_id: String in latest_by_transaction.keys():
		if bool(abandoned.get(transaction_id, false)):
			continue
		var record: Dictionary = latest_by_transaction[transaction_id]
		if (record["stage_candidate"] as Dictionary).get("pending") != null:
			pending_transaction_ids.append(transaction_id)
	if pending_transaction_ids.is_empty():
		return {"ok": true, "code": &"ok", "value": {"found": false}}
	if pending_transaction_ids.size() > 1:
		return _fail(&"consequence_checkpoint_multiple_pending_transactions",
			"more than one transaction_id has an unresolved transient checkpoint: " + str(pending_transaction_ids))
	var chosen: String = pending_transaction_ids[0]
	return {"ok": true, "code": &"ok", "value": {
		"found": true,
		"stage_candidate": ((latest_by_transaction[chosen] as Dictionary)["stage_candidate"] as Dictionary).duplicate(true),
	}}

static func _normalize_outgoing_document(value: Variant, spliced: bool) -> Variant:
	# A successful splice writes journal-owned, byte-proven bundles, not this document's journal.
	# validate_outgoing() replaces it with those exact proofs. Normalize only the envelope/current
	# bundle that it will actually read; the empty Array preserves its existing container check.
	# Cold/missing-proof paths still normalize and validate the entire caller document unchanged.
	if spliced and value is Dictionary and value.get("recovery_journal") is Array:
		var envelope: Dictionary = value.duplicate()
		envelope["recovery_journal"] = []
		return _normalize_json_string_types(envelope)
	return _normalize_json_string_types(value)


## Converts every StringName (key or value) to String and returns everything else untouched. A
## container with no converted descendant is returned AS IS rather than rebuilt: only the path that
## actually contains a conversion is allocated anew. A consequence preimage carries StringNames only
## in its header and pending stage, so the whole recovery_payload subtree -- the expensive part --
## is now passed through by reference.
static func _normalize_json_string_types(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY:
			var source_array: Array = value
			var normalized_array: Variant = null
			for index: int in source_array.size():
				var item: Variant = source_array[index]
				var normalized_item: Variant = _normalize_json_string_types(item)
				if normalized_array == null and not is_same(normalized_item, item):
					normalized_array = []
					for prior: int in index:
						normalized_array.append(source_array[prior])
				if normalized_array != null: normalized_array.append(normalized_item)
			return source_array if normalized_array == null else normalized_array
		TYPE_DICTIONARY:
			var source_dictionary: Dictionary = value
			var normalized_dictionary: Variant = null
			var visited := 0
			for raw_key: Variant in source_dictionary:
				var key: Variant = String(raw_key) if typeof(raw_key) == TYPE_STRING_NAME else raw_key
				var member: Variant = source_dictionary[raw_key]
				var normalized_member: Variant = _normalize_json_string_types(member)
				if normalized_dictionary == null and (not is_same(key, raw_key) or not is_same(normalized_member, member)):
					normalized_dictionary = {}
					var copied := 0
					for prior_key: Variant in source_dictionary:
						if copied == visited: break
						normalized_dictionary[prior_key] = source_dictionary[prior_key]
						copied += 1
				if normalized_dictionary != null: normalized_dictionary[key] = normalized_member
				visited += 1
			return source_dictionary if normalized_dictionary == null else normalized_dictionary
		_:
			return value


func _remember_issued_transient_record(receipt_id: String, record: Dictionary) -> void:
	_issued_transient_records[receipt_id] = record.duplicate(true)
	_touch_issued_transient_record(receipt_id)
	while _issued_transient_order.size() > 8:
		_issued_transient_records.erase(_issued_transient_order.pop_front())


func _touch_issued_transient_record(receipt_id: String) -> void:
	_issued_transient_order.erase(receipt_id)
	_issued_transient_order.append(receipt_id)


func _canonical_text(value: Variant) -> String:
	var canonical: Dictionary = CANONICAL_JSON.stringify(value)
	if not canonical.get("ok", false):
		return ""
	return str(canonical["value"])

func _validate_transient_consequence_record(record: Dictionary) -> Dictionary:
	var canonical: Dictionary = CANONICAL_JSON.stringify(record)
	if not canonical.get("ok", false):
		return _fail(&"invalid_candidate", "checkpoint record is not canonicalizable")
	var parsed: Dictionary = STRICT_JSON.parse_object(str(canonical["value"]))
	if not parsed.get("ok", false) or typeof(parsed.get("value")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "checkpoint record failed canonical round-trip validation")
	var normalized: Dictionary = parsed["value"]
	var keys: Array = normalized.keys()
	keys.sort()
	if keys != ["checkpoint_receipt", "header", "key", "stage_candidate"]:
		return _fail(&"invalid_candidate", "checkpoint record has unexpected keys")
	if typeof(normalized["key"]) != TYPE_STRING or str(normalized["key"]).strip_edges().is_empty():
		return _fail(&"invalid_candidate", "checkpoint record key must be a nonblank string")
	if typeof(normalized["header"]) != TYPE_DICTIONARY \
			or typeof(normalized["stage_candidate"]) != TYPE_DICTIONARY \
			or typeof(normalized["checkpoint_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "checkpoint record fields have invalid types")
	var header: Dictionary = normalized["header"]
	if str(normalized["key"]) != str(header.get("transaction_id", "")) + ":" + str(header.get("operation_ordinal", "")):
		return _fail(&"invalid_candidate", "checkpoint record key does not match its header")
	var state_check: Dictionary = DESKTOP_CONSEQUENCE_STATE.validate(normalized["stage_candidate"])
	if not state_check.get("ok", false):
		return _fail(&"invalid_candidate", "checkpoint record contains an invalid consequence state")
	# Validation already detached this tree. Undo only the initial admission attachment;
	# repeated admission preparation and later stages retain their older admission receipt.
	var rebuild_state: Dictionary = state_check["value"]["state"]
	var pending: Variant = rebuild_state["pending"]
	if typeof(pending) == TYPE_DICTIONARY and str(pending["stage"]) == "sequence_committed" \
			and pending["admission_checkpoint_receipt"] == normalized["checkpoint_receipt"]:
		pending["admission_checkpoint_receipt"] = null
		pending["checkpoint_receipt"] = null
	var rebuilt := _build_consequence_checkpoint(header, rebuild_state)
	if not rebuilt.get("ok", false) or not CANONICAL_JSON._deep_same(
			rebuilt["value"]["candidate"]["document"], normalized):
		return _fail(&"invalid_candidate", "checkpoint record does not reproduce its prepared content")
	return {"ok": true, "code": &"ok", "value": normalized,
		"canonical_text": str(canonical["value"])}

func _fatal_rollback(phase: String, run_id: String, raw_diagnostics: Array) -> Dictionary:
	var already_retained := false
	for diagnostic: Dictionary in raw_diagnostics:
		if str((diagnostic.get("result", {}) as Dictionary).get("code", "")) == "APPLICATION_FATAL":
			already_retained = true
	if not already_retained and not _gate.is_fatal_latched():
		var projected: Dictionary = PROJECTOR.project_failure(
			"save_checkpoint", phase, "fatal_rollback_failed",
			{"run_id": run_id, "relative_path": AUTOSAVE_RELATIVE_PATH},
			raw_diagnostics)
		var candidate: Dictionary = PROJECTOR.get_invariant_fallback()
		if projected.get("ok", false):
			var failure: Dictionary = projected["value"]["failure"]
			if PROJECTOR.validate_failure(failure).get("ok", false):
				candidate = failure
		_gate.latch_fatal(candidate)
	return _gate.guard_external(&"save_checkpoint_recovery")

func _capture_storage_backup(relative_path: String, validated_texts: Dictionary) -> Dictionary:
	var existed: bool = _storage().exists(relative_path)
	var descriptor := {
		"relative_path": relative_path,
		"existed": existed,
		"validated_text": null,
		"sha256": null,
	}
	if existed:
		var read: Dictionary = _storage().read_text(relative_path)
		if not read.get("ok", false):
			if str(read.get("code", "")) == "reconcile_required":
				# A failed read invalidates the storage lease before any checkpoint is committed.
				# Revalidate durable evidence so an explicit retry can read it again.
				# This attempt still fails; corrupt or ambiguous artifacts remain refused.
				# Only its refusal is read, so the witness answers it (dwm-634.3).
				var reconciled: Dictionary = _storage().reconcile(
					relative_path, _witness_document_text_validator.bind(validated_texts))
				if not reconciled.get("ok", false):
					return reconciled
			return read
		var text := str(read["value"])
		var validation := _cached_document_text_proof(text, validated_texts)
		if not validation.get("ok", false):
			return validation
		descriptor["validated_text"] = text
		descriptor["sha256"] = text.sha256_text()
	return {"ok": true, "code": &"ok", "value": {"descriptor": descriptor}}

func _clear_prepared_text_validation() -> void:
	_prepared_text_validations = {}
	_prepared_validation_checkpoint = ""
	_prepared_validation_frame = -1

func _on_validation_capability_changed(_capability: Dictionary) -> void:
	_clear_prepared_text_validation()
	_forget_proven_documents()

func _forget_proven_documents() -> void:
	_proven_document_validations = {}
	_proven_document_order = []

## Only texts validated during a commit whose reread matched and whose journal committed.
func _remember_proven_documents(validated_texts: Dictionary) -> void:
	for text: String in validated_texts.keys():
		if _proven_document_validations.has(text): continue
		_proven_document_validations[text] = (validated_texts[text] as Dictionary).duplicate(true)
		_proven_document_order.append(text)
		while _proven_document_order.size() > PROVEN_DOCUMENT_LIMIT:
			_proven_document_validations.erase(_proven_document_order.pop_front())

func _take_prepared_text_validation(candidate: Dictionary) -> Dictionary:
	var cache := {}
	if _prepared_validation_frame == Engine.get_process_frames() \
			and str(candidate.get("checkpoint_id", "")) == _prepared_validation_checkpoint:
		cache = _prepared_text_validations
	# Consume before any failure, external callback or I/O; retries always start fresh.
	_clear_prepared_text_validation()
	return cache

func _cached_document_text_validator(text: String, cache: Dictionary) -> Dictionary:
	if cache.has(text):
		return (cache[text] as Dictionary).duplicate(true)
	if _proven_document_validations.has(text):
		return (_proven_document_validations[text] as Dictionary).duplicate(true)
	var result := _document_text_validator(text)
	if result.get("ok", false):
		cache[text] = result.duplicate(true)
	return result

## The same question as `_cached_document_text_validator()` -- is this exact text a valid document? --
## for the one caller that reads nothing but `ok`. A proven text answers without copying the 450 KB
## candidate; refusals are returned verbatim, because `_capture_storage_backup()` returns them to its
## own caller. A cold miss still seeds `cache[text]` with the WHOLE validation: that seed is what lets
## `write_atomic()`'s reconcile answer from the cache instead of parsing the existing document again.
func _cached_document_text_proof(text: String, cache: Dictionary) -> Dictionary:
	if cache.has(text) or _proven_document_validations.has(text):
		return {"ok": true, "code": &"ok"}
	var result := _document_text_validator(text)
	if not result.get("ok", false):
		return result
	# Nothing else holds `result`: this method never hands the value out, so the cache may own it.
	cache[text] = result
	return {"ok": true, "code": &"ok"}

## dwm-634.3: the same question again -- is this exact text a valid document? -- for the storage
## calls whose returned value this port discards. Storage only asks whether the value is a
## Dictionary (`_classify_document()`), so a proven text is witnessed with an empty one instead of
## the 450 KB candidate, which `_classify_document()`, `reconcile()` and `write_atomic()` would each
## deep-copy again. A cold miss behaves exactly like `_cached_document_text_validator()`: the FULL
## validation is returned, so every refusal and its order are unchanged, and a success seeds the
## cache so the same call's later classifications answer from it.
func _witness_document_text_validator(text: String, cache: Dictionary) -> Dictionary:
	if cache.has(text) or _proven_document_validations.has(text):
		return {"ok": true, "code": &"ok", "value": {}}
	var result := _document_text_validator(text)
	if result.get("ok", false):
		cache[text] = result.duplicate(true)
	return result

func _document_text_validator(text: String) -> Dictionary:
	if OS.get_environment("DWM_CHECKPOINT_PROFILE") != "1":
		return _validate_document_text(text)
	var started_us := Time.get_ticks_usec()
	var result := _validate_document_text(text)
	_profile_text_validator_calls += 1
	_profile_text_validator_us += Time.get_ticks_usec() - started_us
	return result


func _validate_document_text(text: String) -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return {"ok": false, "code": &"invalid_json", "message": "strict parse failed"}
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": validated["value"]["candidate"]}

func _readiness() -> Dictionary:
	if _gate == null:
		return _fail(&"fatal_latch_not_configured", "")
	if _gate.is_fatal_latched():
		return _gate.guard_external(&"save_checkpoint_recovery")
	if _save_manager == null or _journal() == null or _storage() == null:
		return _fail(&"not_initialized", "SaveManagerCheckpointPort requires an initialized SaveManager")
	return {}

func _journal() -> RefCounted:
	return _save_manager._journal if _save_manager != null else null

func _storage() -> RefCounted:
	return _save_manager._storage if _save_manager != null else null

func _restore_participants() -> Dictionary:
	return _save_manager._restore_participants if _save_manager != null else {}

static func _has_all_methods(target: Object) -> bool:
	for method: String in GATE_METHODS:
		if not target.has_method(method):
			return false
	return true

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
