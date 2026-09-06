extends RefCounted
## Only optional artwork is resolved here. Source admission remains external.

const ART_ID := "schedule.neutral_ticket.v1"
const COMPACT_PATH := "res://assets/ui/schedule/neutral-ticket-compact.svg"
const FOLIO_PATH := "res://assets/ui/schedule/neutral-ticket-folio.svg"

static func resolve(action_registry: Object, action_id: String, expected_fingerprint: String) -> Dictionary:
	if action_registry == null or not action_registry.has_method("lookup"):
		return {"ok": false, "code": "schedule_art_registry_unavailable"}
	var registered: Dictionary = action_registry.lookup(action_id, expected_fingerprint)
	if not registered.get("ok", false): return {"ok": false, "code": "schedule_art_action_unregistered"}
	if not ResourceLoader.exists(COMPACT_PATH) or not ResourceLoader.exists(FOLIO_PATH):
		return {"ok": false, "code": "schedule_art_integrity_failed"}
	var compact := load(COMPACT_PATH) as Texture2D
	var folio := load(FOLIO_PATH) as Texture2D
	if compact == null or folio == null or compact.get_size() != Vector2(24, 24) or folio.get_size() != Vector2(64, 64):
		return {"ok": false, "code": "schedule_art_integrity_failed"}
	return {"ok": true, "code": "", "value": {"art_id": ART_ID, "compact": compact, "folio": folio}}
