extends "res://scripts/application/run/SaveManagerCheckpointPort.gd"
## Frozen accepted pre-document-proof control. Both variants inherit the current port's remaining
## methods and use the same current public raw-proof schema path. Only commit and splice behavior
## differ. The ignored fourth splice argument makes the accepted method signature compatible;
## the driver reverses that one signature edit before verifying the historical method hash.
## Do not modernize these methods. The provenance guard binds the actual accepted Git blobs.

const SOURCE_COMMIT := "226d3da868784baacc6fc33f58823f95b5815a51"
const PORT_SOURCE_PATH := "scripts/application/run/SaveManagerCheckpointPort.gd"
const SCHEMA_SOURCE_PATH := "scripts/infrastructure/save/SaveDocumentSchema.gd"
const PORT_SOURCE_SHA256 := "bac00cb4df7573a6c670bbab1593e77f6ca8d0dd31b3cd7dade6d50616fd04bc"
const SCHEMA_SOURCE_SHA256 := "1676d41225675acf4e3c154c60e38c2bd831417047266d5a9f00e4466bd448b2"
const COMMIT_METHOD_SHA256 := "c8a1d78923cee29d2af4b6520e34d3d131d83ead92b170e8f907f8454132ed58"
const SPLICE_METHOD_SHA256 := "2d35e02daecdb6fc77cb7058132a76b7301825115f6db29750e3de81145b6d9c"
const VALIDATE_METHOD_SHA256 := "f5836a5a142eab40679a4b4f76dbff9bd2dc0c1ee92dc18874db350c6526ef61"


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
	var written_history: Array = []
	var written_document_text := ""
	if candidate.get("autosave_document") != null:
		var autosave_document: Variant = candidate["autosave_document"]
		var document_text := ""
		# The journal-owned bundles whose committed texts the splice writes, in written order.
		var proven_journal: Array = []
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
					proven_journal)
				spliced = not document_text.is_empty()
		tick = _profile_phase(profile, "stringify_us", tick)
		if document_text.is_empty():
			# A partial splice proves nothing about the bytes the whole-document writer emits below.
			proven_journal.clear()
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
				checked = SAVE_DOCUMENT_SCHEMA.validate_outgoing(normalized, proven_journal, profile)
			else:
				checked = SAVE_DOCUMENT_SCHEMA.validate(normalized, profile)
			sub_tick = _profile_phase(profile, "outgoing_validate_us", sub_tick)
			if not profile.is_empty(): profile["outgoing_validation_ok"] = bool(checked.get("ok", false))
			if checked.get("ok", false):
				validated_texts[outgoing_text] = {"ok": true, "code": &"ok", "value": checked["value"]["candidate"]}
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
			(candidate["autosave_document"] as Dictionary)["current_snapshot"])
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


func _splice_autosave_text(document: Dictionary, current_text: String,
		proven_journal: Array = [], _proven_documents: Array = []) -> String:
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
