extends RefCounted

## Current test input built from the historical prepared-board seed. This is not
## a migration path: the v5 file remains unchanged for compatibility tests.
const SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const VIEW := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const PREPARED_BOARD_SEED := "res://tests/fixtures/saves/v5_desktop_prepared.json"

static func make_snapshot() -> Dictionary:
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREPARED_BOARD_SEED))
	snapshot["schema_version"] = SCHEMA.SCHEMA_VERSION
	snapshot["contacts"] = preload("res://scripts/domain/contact/ContactInvitationState.gd").make_defaults()
	snapshot["gameplay"]["money"] = 0
	snapshot["lifecycle"]["active_condition_hospital_plan"] = null
	snapshot["lifecycle"]["condition_hospital_history"] = {}
	snapshot["lifecycle"]["terminal_intent_handoff"] = null
	var view: Dictionary = VIEW.make_empty(int(snapshot["lifecycle"]["day"]),
		str(snapshot["lifecycle"]["causal_day_instance"]))
	if not view.get("ok", false):
		return view
	snapshot["schedule_view"] = view["value"]["view"]
	return SCHEMA.validate(snapshot)
