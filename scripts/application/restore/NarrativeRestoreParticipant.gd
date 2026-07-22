class_name NarrativeRestoreParticipant
extends RefCounted

## Restore participant wrapping DialogicBridge's semantic checkpoint
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).
##
## Phase 2R scope: exact timeline manifests do not exist yet, so prepare()
## returns recoverable NARRATIVE_CONTENT_UNAVAILABLE for every NONEMPTY playhead.
## Empty / no-playhead checkpoints and the participant transaction are fully
## testable. Plan 05 (.8) upgrades THIS class to the manifest-aware
## implementation without a second provider or configuration seam.

var _owner: Object = null

func _init(owner: Object) -> void:
	_owner = owner

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("narrative_checkpoint")) != TYPE_DICTIONARY:
		return _fail(&"invalid_narrative_input", "narrative participant requires a narrative_checkpoint")
	if typeof(input.get("content_version")) != TYPE_INT:
		return _fail(&"invalid_narrative_input", "narrative participant requires a content_version")
	var checkpoint: Dictionary = input["narrative_checkpoint"]
	if _has_nonempty_playhead(checkpoint):
		# Recoverable content incompatibility: the private SaveManager helper maps
		# this to BUNDLE_CONTENT_INCOMPATIBLE and tries an earlier whole bundle.
		return {"ok": false, "code": &"NARRATIVE_CONTENT_UNAVAILABLE",
			"message": "exact timeline manifests arrive with Plan 05",
			"details": {"cause": {"reason": "manifest_unavailable"}}}
	return {"ok": true, "code": &"ok", "value": {"narrative_plan": {"narrative_checkpoint": checkpoint.duplicate(true)}}}

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

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
