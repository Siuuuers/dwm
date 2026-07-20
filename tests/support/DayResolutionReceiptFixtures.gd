class_name DayResolutionReceiptFixtures
extends RefCounted

## Deterministic owner receipts for lifecycle tests
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 2).

static func for_stage(stage_id: String, source_day: int) -> Dictionary:
	match stage_id:
		"lock_day":
			return {"value": {"locked": true}}
		"validate_schedule":
			return {"value": {"valid": true}}
		"execute_schedule_entries":
			return {"value": {"executed": true}}
		"commit_outcomes":
			return {"value": {"committed": true}}
		"hospital_if_triggered":
			return {"value": {"hospital": false}}
		"twofriends_if_deferred":
			return {"value": {"deferred": false}}
		"invitation_rollover":
			return {"value": {"target_day": source_day + 1}}
		"increment_day":
			return {"value": {"day": source_day + 1}}
		"reset_day_scope":
			return {"value": {"reset": true}}
		"new_day_autosave":
			return {"value": {"autosave": "queued"}}
		"unlock_day":
			return {"value": {"locked": false}}
		"close_invitations_run_end":
			return {"value": {"closed": true}}
		"resolve_ending_plan":
			return {"value": {"ending_plan": ending_plan()}}
		"enter_ending":
			return {"value": {"ending_plan": ending_plan()}}
		"ending_autosave":
			return {"value": {"autosave": "queued"}}
	return {"value": {"stage_id": stage_id}}

static func for_substage(substage_id: String) -> Dictionary:
	return {"value": {"substage_id": substage_id, "executed": true}}

static func ending_plan() -> Dictionary:
	return {
		"ending_id": "ending.alone",
		"epilogue_ending_id": "",
		"source_day": 7,
		"playback_stage": "PRIMARY_PENDING",
		"playback_receipts": {},
	}

static func playback_receipt(expected_stage: String) -> Dictionary:
	return {"value": {"played": expected_stage}}
