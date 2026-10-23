class_name SevenDayCalendar
extends RefCounted

## Fixed Contacts generation calendar. All queries are pure and return detached arrays.
const ORDINARY_BY_DAY := {
	1: "lavinia",
	2: "sylvia",
	3: "priscilla",
	4: "lavinia",
	5: "priscilla",
	6: "sylvia",
}

const SOLO_ORDER_BY_DAY := {
	1: ["priscilla", "sylvia"],
	2: ["priscilla", "lavinia"],
	3: ["lavinia", "sylvia"],
	4: ["priscilla", "sylvia"],
	5: ["lavinia", "sylvia"],
	6: ["priscilla", "lavinia"],
}

const GROUP_DAYS: Array[int] = [2, 6]
# Existing Day 7 relationship-tier delivery is distinct from the Days 1–6 dating calendar.
const DAY7_ENDING_ORDER: Array[String] = ["priscilla", "lavinia", "sylvia"]


static func ordinary_friend(day: int) -> String:
	return str(ORDINARY_BY_DAY.get(day, ""))


static func solo_order(day: int) -> Array[String]:
	var out: Array[String] = []
	if SOLO_ORDER_BY_DAY.has(day):
		out.assign(SOLO_ORDER_BY_DAY[day])
	return out


static func contact_round_order(day: int) -> Array[String]:
	if day == 7:
		return DAY7_ENDING_ORDER.duplicate()
	return solo_order(day)


static func solo_days_for(friend_id: String) -> Array[int]:
	var out: Array[int] = []
	for day_value: Variant in SOLO_ORDER_BY_DAY:
		var day := int(day_value)
		if friend_id in SOLO_ORDER_BY_DAY[day]:
			out.append(day)
	out.sort()
	return out


static func is_solo_day(friend_id: String, day: int) -> bool:
	return friend_id in solo_order(day)


static func is_group_day(day: int) -> bool:
	return day in GROUP_DAYS


static func group_days() -> Array[int]:
	return GROUP_DAYS.duplicate()
