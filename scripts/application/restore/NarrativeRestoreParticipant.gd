class_name NarrativeRestoreParticipant
extends RefCounted

## Restore participant wrapping DialogicBridge's semantic checkpoint
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7,
## upgraded to the manifest-aware implementation by Plan 05 Task 2 / dwm-p2r.8).
##
## prepare() is pure: it validates the complete semantic checkpoint against the CURRENT catalog
## record, fingerprint, event, and post-event successor without mutating anything. It returns the
## typed recoverable NARRATIVE_CONTENT_UNAVAILABLE only when a structurally valid bundle references
## removed/unavailable content or an earlier fingerprint; malformed primitive/schema data keeps the
## Plan-03 fail-closed codes so SaveManager rejects instead of silently walking to an older bundle.

const SCHEMA := preload("res://scripts/narrative/NarrativeCheckpointSchema.gd")

## Schema failures that mean "this bundle's content no longer exists" (recoverable) rather than
## "these bytes are malformed" (fail-closed).
const _CONTENT_CODES := [
	&"unregistered_event", &"illegal_successor", &"event_index_mismatch",
	&"event_kind_mismatch", &"semantic_id_mismatch", &"timeline_mismatch", &"fingerprint_mismatch",
]

var _owner: Object = null
var _catalog: Object = null

func _init(owner: Object, catalog: Object = null) -> void:
	_owner = owner
	_catalog = catalog if catalog != null else preload("res://scripts/data/DialogicTimelineCatalog.gd")

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("narrative_checkpoint")) != TYPE_DICTIONARY:
		return _fail(&"invalid_narrative_input", "narrative participant requires a narrative_checkpoint")
	if typeof(input.get("content_version")) != TYPE_INT:
		return _fail(&"invalid_narrative_input", "narrative participant requires a content_version")
	var checkpoint: Dictionary = input["narrative_checkpoint"]
	if not _has_nonempty_playhead(checkpoint):
		return {"ok": true, "code": &"ok", "value": {"narrative_plan": {"narrative_checkpoint": checkpoint.duplicate(true)}}}
	var timeline_id := str(checkpoint.get("timeline_id", ""))
	var resolved: Dictionary = _catalog.get_record(timeline_id)
	if not resolved.get("ok", false):
		return _content_unavailable("unknown timeline: " + timeline_id)
	var record: Dictionary = resolved["value"]
	if str(record.get("content_fingerprint", "")) != str(checkpoint.get("content_fingerprint", "")):
		return _content_unavailable("content fingerprint drifted for " + timeline_id)
	var validated: Dictionary = SCHEMA.validate(checkpoint, record)
	if not validated.get("ok", false):
		if validated.get("code") in _CONTENT_CODES:
			return _content_unavailable(str(validated.get("message", "")))
		return _fail(&"invalid_narrative_checkpoint", str(validated.get("message", "")))
	var post_event: Dictionary = checkpoint["post_event"]
	var plan := {
		"narrative_checkpoint": checkpoint.duplicate(true),
		"position": str(post_event["position"]),
		"resume_event_index": post_event.get("event_index"),
		"timeline_id": timeline_id,
		"timeline_path": _catalog.get_timeline_path(timeline_id, "en"),
	}
	return {"ok": true, "code": &"ok", "value": {"narrative_plan": plan}}

func apply_silent(plan: Dictionary) -> Dictionary:
	# Rejects a missing route-ready token and therefore cannot run early.
	if typeof(plan.get("route_ready_token")) != TYPE_DICTIONARY:
		return _fail(&"missing_route_ready_token", "narrative apply requires the route-ready token")
	return _owner.apply_restore_silent(plan)

func capture() -> Dictionary:
	return _owner.capture_restore_state()

func rollback_silent(backup: Dictionary) -> Dictionary:
	return _owner.rollback_restore_silent(backup)

func finalize() -> Dictionary:
	return _owner.finalize_restore()

static func _has_nonempty_playhead(checkpoint: Dictionary) -> bool:
	if checkpoint.is_empty():
		return false
	for key: String in ["timeline_id", "line_id", "marker_id"]:
		if str(checkpoint.get(key, "")) != "":
			return true
	return false

static func _content_unavailable(message: String) -> Dictionary:
	# Recoverable content incompatibility: the private SaveManager helper maps this to
	# BUNDLE_CONTENT_INCOMPATIBLE and tries an earlier whole bundle.
	return {"ok": false, "code": &"NARRATIVE_CONTENT_UNAVAILABLE", "message": message,
		"details": {"cause": {"reason": "content_unavailable"}}}

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
