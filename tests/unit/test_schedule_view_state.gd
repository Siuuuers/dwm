extends "res://addons/gut/test.gd"

const VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const CAUSAL_DAY := "causal_day_instance.1111111111111111111111111111111111111111111111111111111111111111"
const ENVELOPE_SUCCESS_KEYS: Array = ["code", "ok", "receipt", "value"]
const VIEW_KEYS: Array = [
	"causal_day_instance", "condition_departure_receipts", "consumed_warning_receipts",
	"date_entry_seen", "day", "entries", "pending_warning",
]

func _code(result: Dictionary) -> String:
	return str(result.get("code", ""))


func _keys_of(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


func test_make_empty_returns_the_exact_seven_key_empty_view() -> void:
	var made: Dictionary = VIEW_STATE.make_empty(3, CAUSAL_DAY)
	assert_true(made.get("ok", false), str(made))
	assert_eq(_keys_of(made), ENVELOPE_SUCCESS_KEYS, "the master success envelope")
	var value: Dictionary = made.get("value", {})
	assert_eq(_keys_of(value), ["view"], "the success value is exactly {view}")
	var view: Dictionary = value.get("view", {})
	assert_eq(_keys_of(view), VIEW_KEYS, "the view is exactly the seven-key shape")
	assert_eq(int(view.get("day", -1)), 3, "day")
	assert_eq(str(view.get("causal_day_instance", "")), CAUSAL_DAY, "causal day instance")
	assert_eq((view.get("entries", ["x"]) as Array).size(), 0, "entries start empty")
	assert_eq(view.get("date_entry_seen", true), false, "date_entry_seen starts false")
	assert_null(view.get("pending_warning", "x"), "pending_warning starts null")
	assert_eq((view.get("consumed_warning_receipts", {"x": 1}) as Dictionary).size(), 0,
		"consumed_warning_receipts starts empty")
	assert_eq((view.get("condition_departure_receipts", {"x": 1}) as Dictionary).size(), 0,
		"condition_departure_receipts starts empty")


func test_make_empty_rejects_days_zero_and_eight() -> void:
	assert_eq(_code(VIEW_STATE.make_empty(0, CAUSAL_DAY)), "invalid_day", "day zero refused")
	assert_eq(_code(VIEW_STATE.make_empty(8, CAUSAL_DAY)), "invalid_day", "day eight refused")


func test_make_empty_rejects_a_blank_causal_day_instance() -> void:
	assert_eq(_code(VIEW_STATE.make_empty(3, "")), "invalid_causal_day_instance",
		"a blank causal day instance is refused")
