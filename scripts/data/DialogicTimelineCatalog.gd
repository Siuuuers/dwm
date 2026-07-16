class_name DialogicTimelineCatalog
extends RefCounted
# Maps timeline IDs -> .dtl paths per locale (DIALOGIC.md §9). Do NOT execute timeline
# data; do NOT trust save data to choose paths. Invitation-part IDs resolve to the owning
# per-friend/day contact .dtl (the part is a label inside that file, never a standalone file).

const SUPPORTED_LOCALES := ["en", "zh_CN", "zh_HK"]
const DEFAULT_LOCALE := "en"
const TIMELINE_ROOT := "res://dialogic/timelines/"

const FRIENDS := ["priscilla", "lavinia", "sylvia"]
const SOLO_DATING_DAYS := {
	"priscilla": [1, 2, 4, 6],
	"lavinia": [2, 3, 5, 6],
	"sylvia": [1, 3, 4, 5],
}
const GROUP_DAYS := [2, 6]


static func get_supported_locales() -> Array[String]:
	var out: Array[String] = []
	out.assign(SUPPORTED_LOCALES)
	return out


static func get_required_timeline_ids() -> Array[String]:
	# One ID per backing .dtl file (61 total).
	var ids: Array[String] = []
	# Core (3)
	ids.append("opening.day1")
	ids.append("tutorial.desktop_day1")
	ids.append("hospital.faint")
	# Ending files (5)
	ids.append("ending.alone")
	ids.append("ending.priscilla")
	ids.append("ending.lavinia")
	ids.append("ending.sylvia")
	ids.append("ending.priscilla_lavinia")
	# Contacts (21)
	for friend in FRIENDS:
		for day in range(1, 8):
			ids.append("contact.%s.day%d" % [friend, day])
	# Solo dating (24)
	for friend in FRIENDS:
		for day in SOLO_DATING_DAYS[friend]:
			ids.append("dating.solo.%s.day%d.pre_challenge" % [friend, day])
			ids.append("dating.solo.%s.day%d.post_challenge" % [friend, day])
	# Group dating (4)
	for day in GROUP_DAYS:
		ids.append("dating.group.priscilla_lavinia.day%d.pre_challenge" % day)
		ids.append("dating.group.priscilla_lavinia.day%d.post_challenge" % day)
	# Twofriends (4)
	for day in GROUP_DAYS:
		ids.append("dating.twofriends.priscilla_lavinia.day%d.pre_challenge" % day)
		ids.append("dating.twofriends.priscilla_lavinia.day%d.post_challenge" % day)
	return ids


static func _relative_path(timeline_id: String) -> String:
	# Returns a path relative to the locale folder, or "" if the id is unknown.
	var parts := timeline_id.split(".")
	if parts.is_empty():
		return ""
	match parts[0]:
		"opening":
			return "core/opening_day1.dtl"
		"tutorial":
			return "core/tutorial_desktop_day1.dtl"
		"hospital":
			return "core/hospital_faint.dtl"
		"ending":
			if parts.size() >= 2:
				var token := parts[1]
				if token == "alone" or token == "priscilla_lavinia":
					return "ending/%s.dtl" % token
				if token in FRIENDS:
					return "ending/%s.dtl" % token
			return ""
		"contact":
			return _contact_path(parts)
		"dating":
			return _dating_path(parts)
	return ""


static func _contact_path(parts: PackedStringArray) -> String:
	# contact.<friend>.day<N>
	if parts.size() == 3 and parts[1] in FRIENDS:
		var day_token := parts[2]
		if day_token.begins_with("day"):
			return "contacts/%s_%s.dtl" % [parts[1], day_token]
	# contact.invitation.solo.<friend>.day<N>.<part> -> owning contact dtl
	if parts.size() >= 5 and parts[1] == "invitation" and parts[2] == "solo":
		var friend := parts[3]
		var day_token2 := parts[4]
		if friend in FRIENDS and day_token2.begins_with("day"):
			return "contacts/%s_%s.dtl" % [friend, day_token2]
	# contact.invitation.group.priscilla_lavinia.day<N>.<part> -> participant contact dtl
	if parts.size() >= 6 and parts[1] == "invitation" and parts[2] == "group":
		var day_token3 := parts[4]
		var part := parts[5]
		var participant := "priscilla"
		if "lavinia" in part:
			participant = "lavinia"
		elif "priscilla" in part:
			participant = "priscilla"
		if day_token3.begins_with("day"):
			return "contacts/%s_%s.dtl" % [participant, day_token3]
	return ""


static func _dating_path(parts: PackedStringArray) -> String:
	# dating.solo.<friend>.day<day>.<pre_challenge|post_challenge>
	if parts.size() == 5 and parts[1] == "solo" and parts[2] in FRIENDS:
		var day_token := parts[3]
		var phase := parts[4]
		if day_token.begins_with("day") and (phase == "pre_challenge" or phase == "post_challenge"):
			return "dating/solo/%s_%s_%s.dtl" % [parts[2], day_token, phase]
	# dating.group.priscilla_lavinia.day<N>.<phase>
	if parts.size() == 5 and parts[1] == "group":
		var day_token2 := parts[3]
		var phase2 := parts[4]
		if day_token2.begins_with("day") and (phase2 == "pre_challenge" or phase2 == "post_challenge"):
			return "dating/group/priscilla_lavinia_%s_%s.dtl" % [day_token2, phase2]
	# dating.twofriends.priscilla_lavinia.day<N>.<phase>
	if parts.size() == 5 and parts[1] == "twofriends":
		var day_token3 := parts[3]
		var phase3 := parts[4]
		if day_token3.begins_with("day") and (phase3 == "pre_challenge" or phase3 == "post_challenge"):
			return "dating/twofriends/priscilla_lavinia_%s_%s.dtl" % [day_token3, phase3]
	return ""


static func get_timeline_path(timeline_id: String, locale: String = "") -> String:
	var rel := _relative_path(timeline_id)
	if rel == "":
		return ""
	var loc := locale
	if loc == "" or not (loc in SUPPORTED_LOCALES):
		loc = DEFAULT_LOCALE
	return "%s%s/%s" % [TIMELINE_ROOT, loc, rel]


static func get_required_timeline_paths(locale: String = "en") -> Array[String]:
	var out: Array[String] = []
	for id in get_required_timeline_ids():
		var p := get_timeline_path(id, locale)
		if p != "" and not (p in out):
			out.append(p)
	return out


static func has_timeline_id(timeline_id: String) -> bool:
	return _relative_path(timeline_id) != ""


static func build_missing_timeline_report(locale: String = "en") -> Dictionary:
	var required := get_required_timeline_paths(locale)
	var existing: Array[String] = []
	var missing: Array[String] = []
	for path in required:
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			existing.append(path)
		else:
			missing.append(path)
	return {
		"locale": locale,
		"required_count": required.size(),
		"existing_count": existing.size(),
		"missing_count": missing.size(),
		"missing": missing,
	}
