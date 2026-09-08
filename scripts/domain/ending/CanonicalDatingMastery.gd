extends RefCounted
## Current loaded slot heads are the membership authority (design section 10.4).
## Profile history supplies proof for those exact heads; it is never scanned or unioned.
const ATTEMPTS := preload("res://scripts/profile/DatingAttemptLedger.gd")
const WINDOWS := {"priscilla": [1, 2, 4, 6], "lavinia": [2, 3, 5, 6],
	"priscilla_lavinia": [2, 6]}

static func slots_for(scope: String) -> Array[String]:
	var slots: Array[String] = []
	for day: int in WINDOWS.get(scope, []):
		slots.append("dating.pair.priscilla_lavinia.day%d" % day if scope == "priscilla_lavinia"
			else "dating.solo.%s.day%d" % [scope, day])
	return slots

static func required_slots() -> Array[String]:
	var slots: Array[String] = []
	for scope: String in WINDOWS:
		slots.append_array(slots_for(scope))
	return slots

## selected_attempts is keyed by semantic slot and obtained with all four Profile lookup
## arguments. A missing/invalid proof makes only that scope ineligible; it never fills a gap
## from another attempt, branch or week. No relationship tone or Observer behavior is inferred.
static func evaluate(run_id: String, heads: Dictionary, selected_attempts: Dictionary) -> Dictionary:
	var mastery := {"priscilla": false, "lavinia": false, "priscilla_lavinia": false}
	if run_id.strip_edges().is_empty(): return mastery
	for scope: String in WINDOWS:
		var complete := true
		for slot: String in slots_for(scope):
			if not _perfect_head(run_id, slot, heads.get(slot), selected_attempts.get(slot)):
				complete = false
				break
		mastery[scope] = complete
	return mastery

static func _perfect_head(run_id: String, slot: String, raw_head: Variant, raw_attempt: Variant) -> bool:
	if not raw_head is Dictionary or not raw_attempt is Dictionary: return false
	var head: Dictionary = raw_head
	var keys: Array = head.keys()
	keys.sort()
	if keys != ["attempt_id", "branch_id"]: return false
	for key: String in ["attempt_id", "branch_id"]:
		if not head[key] is String or head[key].strip_edges().is_empty(): return false
	var attempt: Dictionary = raw_attempt
	if attempt.get("run_id") != run_id or attempt.get("slot_id") != slot \
			or attempt.get("attempt_id") != head.attempt_id or attempt.get("branch_id") != head.branch_id:
		return false
	# Reuse the existing board/entry/materialization/effect/completion contract. In particular,
	# a claimed Perfect outcome cannot replace an actual cleared board and terminal receipt.
	if not ATTEMPTS.validate_attempt(attempt).get("ok", false): return false
	return attempt.record.phase == "completed" and attempt.completion_receipt != null \
		and attempt.record.outcome == "perfect" and attempt.clear_receipt != null \
		and attempt.clear_receipt.outcome == "perfect"
