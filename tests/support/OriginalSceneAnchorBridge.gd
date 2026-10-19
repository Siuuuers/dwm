extends "res://autoload/DialogicBridge.gd"
## Exact original scene5 validator from product8f59bcc7; differential oracle only.
func _validate_scene5_event_anchor(anchor: Dictionary, checkpoint: Dictionary) -> Dictionary:
	if not _exact_keys(anchor, ["session_id", "entry_id", "content_version", "catalogue_fingerprint", "publication_id", "line_id"]) \
			or typeof(anchor.get("content_version")) != TYPE_INT or anchor.content_version <= 0:
		return _command_failure(&"event_anchor_invalid")
	for key: String in ["session_id", "entry_id", "catalogue_fingerprint", "publication_id", "line_id"]:
		if typeof(anchor[key]) != TYPE_STRING or anchor[key].strip_edges().is_empty(): return _command_failure(&"event_anchor_invalid")
	var candidate := _READING_SESSION.new()
	var configured: Dictionary = candidate.configure_scene()
	if not configured.ok: return configured
	var restored: Dictionary = candidate.restore(checkpoint.reading_session, str(checkpoint.get("entry_id", "")))
	if not restored.ok: return restored
	if anchor.catalogue_fingerprint != candidate.fingerprint or not candidate.catalogue.has(anchor.entry_id) \
			or candidate.catalogue[anchor.entry_id].content_version != anchor.content_version:
		return _command_failure(&"event_anchor_catalogue_mismatch")
	var ledger: Dictionary = candidate.ledger.snapshot()
	# Anchor session_id is the logical occurrence; ledger session_token spans occurrences.
	var frame := NarrativeCaptionLedger.resolve_scene_frame(ledger.entry_contexts, anchor.session_id, anchor.entry_id)
	if not frame.ok: return _command_failure(&"event_anchor_invalid")
	for row: Dictionary in ledger.captions:
		if row.publication_id == anchor.publication_id and row.occurrence_id == anchor.session_id \
				and row.beat.owning_entry_id == anchor.entry_id and row.beat.line_id == anchor.line_id:
			return {"ok": true}
	return _command_failure(&"event_anchor_invalid")
