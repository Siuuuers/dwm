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
##
## Seven-Day Flow Plan 01 Task 7 (dwm-oyo.2, Rulings 14-A and 14-D) adds a SEMANTIC entry branch
## beside the legacy one, additive and self-gating. The legacy timeline_id path stays the DEFAULT;
## the semantic branch engages only for a checkpoint that declares entry_id, which nothing in the
## repository writes yet, so ApplicationBootstrap needs no change and the seam is dormant in
## practice until a producer lands. The semantic branch owns no resolution law of its own: it
## projects the durable six-field plan onto the bridge's five-key checkpoint and asks the bridge,
## the sole narrative seam (specification 12.4), so prepare and finalize share one refusal
## vocabulary and prepare can never accept what finalize would reject.

const SCHEMA := preload("res://scripts/narrative/NarrativeCheckpointSchema.gd")
const ENTRY_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const FROZEN_RUN := preload("res://scripts/narrative/FrozenRunContext.gd")

## Schema failures that mean "this bundle's content no longer exists" (recoverable) rather than
## "these bytes are malformed" (fail-closed).
const _CONTENT_CODES := [
	&"unregistered_event", &"illegal_successor", &"event_index_mismatch",
	&"event_kind_mismatch", &"semantic_id_mismatch", &"timeline_mismatch", &"fingerprint_mismatch",
]

## Task 7's plan block declares the prepared semantic plan contains ONLY these six, so this is an
## exact-key set and not a minimum.
const _SEMANTIC_PLAN_KEYS := ["content_version", "entry_id", "frozen_context",
	"manifest_fingerprint", "stage", "transaction_id"]
## The five the bridge accepts. manifest_fingerprint is a PREPARE-time compatibility field whose
## whole job is discharged before the checkpoint is projected, so widening the bridge's shipped
## five-key law to carry it would buy nothing.
const _RESUME_CHECKPOINT_KEYS := ["content_version", "entry_id", "frozen_context", "stage",
	"transaction_id"]
## Specification 12.4 and 14.4: a save never persists a physical path or an untrusted label, and a
## scene never inspects one. A checkpoint carrying any of these is malformed, not merely stale.
const _PHYSICAL_LOCATOR_KEYS := ["label", "path", "timeline_id", "timeline_path"]
## Bridge refusals meaning "this bundle's content no longer resolves" (recoverable) rather than
## "these bytes are malformed" (fail-closed) - the same discrimination _CONTENT_CODES makes for the
## legacy branch.
const _SEMANTIC_CONTENT_CODES := [
	&"entry_resolution_failed", &"ENTRY_MANIFEST_UNKNOWN_ENTRY", &"ENTRY_MANIFEST_RETIRED_ENTRY",
	&"entry_master_missing", &"entry_record_missing", &"entry_content_version_mismatch",
]
const _READING_CONTENT_CODES := [
	&"reading_catalogue_unavailable", &"reading_catalogue_mismatch", &"reading_line_unavailable",
	&"reading_line_content_mismatch", &"reading_line_ambiguous", &"reading_entry_mismatch",
]

## The shipped entry document's contract fingerprint, derived once per process. Neither
## load_default nor the canonical writer caches, and the document is 85 KB across 137 records, so a
## per-prepare derivation would re-read and re-serialize all of it on every restore attempt. This
## mirrors DialogicBridge's own static entry-document cache and its stated reason.
static var _document_fingerprint := ""

var _owner: Object = null
var _catalog: Object = null
## The ONE semantic plan apply_silent has staged and finalize has not yet consumed.
var _pending_semantic_plan: Dictionary = {}

func _init(owner: Object, catalog: Object = null) -> void:
	_owner = owner
	_catalog = catalog if catalog != null else preload("res://scripts/data/DialogicTimelineCatalog.gd")

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("narrative_checkpoint")) != TYPE_DICTIONARY:
		return _fail(&"invalid_narrative_input", "narrative participant requires a narrative_checkpoint")
	if typeof(input.get("content_version")) != TYPE_INT:
		return _fail(&"invalid_narrative_input", "narrative participant requires a content_version")
	var checkpoint: Dictionary = input["narrative_checkpoint"]
	# This discriminator must precede both older branches. Removing entry_id from
	# a reading checkpoint must never downgrade it to an empty legacy playhead.
	if checkpoint.has("reading_session"):
		return _prepare_reading(checkpoint, input.get("snapshot"))
	# Ruling 14-D. The discriminator is tested BEFORE the playhead, because a semantic checkpoint
	# carries no timeline_id, line_id or marker_id and the empty-playhead passthrough would otherwise
	# swallow it. Legacy stays the default: only a declared entry_id opts in.
	if checkpoint.has("entry_id"):
		return _prepare_semantic(checkpoint)
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
	var pause_pending: bool = _owner.has_method("is_pause_restore_pending") and _owner.is_pause_restore_pending()
	if plan.has("reading_session"):
		if not pause_pending and _owner.has_active_playback():
			return _fail(&"narrative_playback_active", "a narrative playback is standing; the reading restore cannot be staged")
		# Install only the prepared session helper before the route publishes. Native
		# playback and static caption projection remain behind transaction finalize.
		var staged: Dictionary = _owner.stage_reading_restore(_projected(plan))
		if not staged.get("ok", false): return staged
	if pause_pending:
		return _owner.stage_pause_restore(_projected(plan) if plan.has("entry_id") else plan,
			plan.has("entry_id"))
	if plan.has("entry_id"):
		# Ruling 15-B. A standing playback is the ONE precondition prepare deliberately does not test,
		# because activity is a transient runtime state rather than a property of the save. It is
		# refused HERE, in the last hook before SaveManager commits its checkpoint journal, so the
		# refusal lands on the recoverable side of that commit instead of forcing a rollback past it.
		if _owner.has_active_playback():
			return _fail(&"narrative_playback_active",
				"a narrative playback is standing; the semantic restore cannot be staged")
		# A semantic plan is STORED, never applied: nothing starts until the whole restore
		# transaction has succeeded and finalize runs (plan Task 7; specification 14.3).
		_pending_semantic_plan = _projected(plan)
		return {"ok": true, "code": &"ok"}
	return _owner.apply_restore_silent(plan)

func capture() -> Dictionary:
	return _owner.capture_restore_state()

func rollback_silent(backup: Dictionary) -> Dictionary:
	# A rolled-back restore must never resume the entry, so the ATTEMPT cancels the staged plan,
	# mirroring the bridge's own _pending_resume_token cancellation. Cancelling before the owner is
	# consulted is deliberate: a malformed backup is a FAILED rollback, and a failed rollback must
	# not leave a live resume staged behind it.
	_pending_semantic_plan = {}
	return _owner.rollback_restore_silent(backup)

func finalize() -> Dictionary:
	if _owner.has_method("is_pause_restore_pending") and _owner.is_pause_restore_pending():
		return _owner.finalize_pause_restore()
	if _pending_semantic_plan.is_empty():
		return _owner.finalize_restore()
	# One shot: the staged resume is consumed here, so a second finalize can never replay it. The
	# bridge mints a fresh process-local playback token while the DURABLE transaction id is retained.
	var checkpoint: Dictionary = _pending_semantic_plan
	_pending_semantic_plan = {}
	return _owner.resume_entry(checkpoint)

## Ruling 14-D's semantic branch. It validates compatibility and starts nothing: every resolution
## question is asked of the bridge, so this file holds no second copy of the entry-resolution law.
func _prepare_semantic(checkpoint: Dictionary) -> Dictionary:
	# Scene admission requires the complete receipt-bearing Run and reading5.
	# A stripped six-field scene frame cannot use the historical resume seam.
	if FROZEN_RUN._is_scene_checkpoint(checkpoint):
		return _fail(&"invalid_narrative_checkpoint", "scene_owner_validation_unavailable")
	for key: String in _PHYSICAL_LOCATOR_KEYS:
		if checkpoint.has(key):
			return _fail(&"invalid_narrative_checkpoint",
				"a semantic entry checkpoint may not carry the physical locator " + key)
	if not _exact_keys(checkpoint, _SEMANTIC_PLAN_KEYS):
		return _fail(&"invalid_narrative_checkpoint",
			"semantic checkpoint keys must be exactly " + str(_SEMANTIC_PLAN_KEYS))
	# Specification 14.4: a malformed or corrupt save is REJECTED, never faulted on and never
	# relabelled merely incompatible. This is the trust boundary where untrusted save bytes enter the
	# semantic seam, and the bridge type-checks only frozen_context. Two concrete hazards close here.
	# A non-String or non-int primitive would reach str()/int() on a Variant that has no such
	# conversion. And a NON-POSITIVE content_version would forge _begin_entry_playback's own
	# fresh-start sentinel: expected_version below zero disables the record revalidation outright, so
	# a bundle that is incompatible by construction would validate and play.
	for key: String in ["entry_id", "manifest_fingerprint", "stage", "transaction_id"]:
		if typeof(checkpoint[key]) != TYPE_STRING or str(checkpoint[key]).is_empty():
			return _fail(&"invalid_narrative_checkpoint",
				"a semantic entry checkpoint requires a nonempty String " + key)
	# frozen_context deliberately has NO guard here: _check_resume_checkpoint already refuses a
	# non-Dictionary with invalid_playback_context, which maps to this same code, and nothing indexes
	# into it before that check runs. A second copy would be a law no mutation could falsify.
	if typeof(checkpoint["content_version"]) != TYPE_INT or int(checkpoint["content_version"]) <= 0:
		return _fail(&"invalid_narrative_checkpoint",
			"a semantic entry checkpoint requires a positive int content_version")
	var live := _entry_document_fingerprint()
	if live.is_empty():
		return _content_unavailable("the shipped entry document is unavailable or unfingerprintable")
	if str(checkpoint["manifest_fingerprint"]) != live:
		# Specification 14.4's contract fingerprint: a breaking semantic change is RECOVERABLE, so
		# SaveManager may fall back to an earlier whole bundle instead of failing the restore.
		return _content_unavailable("entry manifest fingerprint drifted")
	var validated: Dictionary = _owner.validate_resume_checkpoint(_projected(checkpoint))
	if not validated.get("ok", false):
		if validated.get("code") in _SEMANTIC_CONTENT_CODES:
			# Specification 12.4: the bridge's own message may BE a physical master path -
			# entry_master_missing carries it verbatim - so the participant names the SEMANTIC entry and
			# the refusal code instead of forwarding a locator to its caller. The fail-closed branch
			# below may forward its message: none of the codes reaching it carries a locator.
			return _content_unavailable("%s is unmappable: %s"
				% [str(checkpoint["entry_id"]), String(validated.get("code", &""))])
		return _fail(&"invalid_narrative_checkpoint", str(validated.get("message", "")))
	var plan := {}
	for key: String in _SEMANTIC_PLAN_KEYS:
		plan[key] = checkpoint[key]
	plan["frozen_context"] = (checkpoint["frozen_context"] as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"narrative_plan": plan}}

func _prepare_reading(checkpoint: Dictionary, snapshot: Variant) -> Dictionary:
	var keys := _SEMANTIC_PLAN_KEYS.duplicate()
	keys.append("reading_session")
	if not _exact_keys(checkpoint, keys):
		return _fail(&"invalid_narrative_checkpoint", "reading checkpoint requires its versioned semantic envelope")
	if not snapshot is Dictionary or snapshot.get("narrative_checkpoint") != checkpoint:
		return _fail(&"invalid_narrative_input", "reading restoration requires the complete matching saved Run")
	# All retained frames are independently admitted against the saved physical
	# owner, not against the checkpoint's own copy of those same frames. Invalid
	# saved bytes stay fail-closed even when a content fingerprint is also stale.
	var frozen := FROZEN_RUN.validate(snapshot, true) if FROZEN_RUN._is_scene_checkpoint(checkpoint) \
		else FROZEN_RUN.validate_reading_checkpoint(checkpoint, snapshot)
	if not frozen.get("ok", false):
		return _fail(&"invalid_narrative_checkpoint", str(frozen.get("code", "")))
	# Reuse the existing entry compatibility law without widening the old exact
	# reader. A six-field reader still refuses a seven-field reading checkpoint.
	var semantic := checkpoint.duplicate(true)
	semantic.erase("reading_session")
	var base := _prepare_semantic(semantic)
	if not base.get("ok", false): return base
	if not _owner.has_method("validate_reading_checkpoint") or not _owner.has_method("stage_reading_restore"):
		return _content_unavailable("the reading catalogue is unavailable")
	var checked: Dictionary = _owner.validate_reading_checkpoint(checkpoint, frozen.value.entry_contexts)
	if not checked.get("ok", false):
		if checked.get("code") in _READING_CONTENT_CODES or checked.get("code") in _SEMANTIC_CONTENT_CODES:
			return _content_unavailable("the saved reading catalogue is unavailable or incompatible")
		return _fail(&"invalid_narrative_checkpoint", str(checked.get("code", "")))
	return {"ok": true, "code": &"ok", "value": {"narrative_plan": checkpoint.duplicate(true)}}

## The six-field durable plan projected onto the bridge's shipped five-key checkpoint. get() rather
## than an indexed read, so a caller-authored plan missing a field is refused by the bridge's own
## exact-key law instead of crashing here.
static func _projected(source: Dictionary) -> Dictionary:
	if source.has("reading_session"):
		var reading := {}
		for key: String in _SEMANTIC_PLAN_KEYS:
			reading[key] = source.get(key)
		reading["reading_session"] = source.get("reading_session")
		return reading.duplicate(true)
	var projected := {}
	for key: String in _RESUME_CHECKPOINT_KEYS:
		projected[key] = source.get(key)
	return projected

## Ruling 15-A: the SHIPPED document producer is reused, never a second definition of the same
## value. fingerprint() answers "" for a document it cannot canonicalize, and that empty answer is
## never cached, so a transient failure cannot poison the process.
static func _entry_document_fingerprint() -> String:
	if not _document_fingerprint.is_empty():
		return _document_fingerprint
	var loaded: Dictionary = ENTRY_MANIFEST.load_default()
	if not loaded.get("ok", false):
		return ""
	_document_fingerprint = str(ENTRY_MANIFEST.fingerprint(loaded["value"]))
	return _document_fingerprint

static func _exact_keys(target: Dictionary, keys: Array) -> bool:
	if target.size() != keys.size():
		return false
	for key in keys:
		if not target.has(key):
			return false
	return true

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

