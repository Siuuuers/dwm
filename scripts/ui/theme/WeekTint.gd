extends RefCounted
## Week tint: the room ages from the shipped Day 1 tuple (tint 0.0) toward a colder Day 7
## endpoint (tint 1.0). Amendment 2026-09-12, Section 5 (corrected: shipped = Day 1).
## Room roles only. Hue never rotates: only OK-HSL lightness and saturation move.
## High contrast keeps zero amplitude; CVD presets move lightness only.
## Callers evaluate this only at boundaries (login, day advance, return, Load); it never animates.

const CURVE := {1: 0.0, 2: 0.08, 3: 0.20, 4: 0.38, 5: 0.58, 6: 0.80, 7: 1.0}
const ROOM_ROLES: Array[String] = ["habitat", "face", "paper", "structure", "secondary_ink", "inward_preview"]
## Cold endpoint deltas at tint 1.0: role -> [lightness_delta, saturation_delta] in OK HSL.
const COLD_DELTAS := {
	"habitat": [-0.035, -0.015],
	"face": [-0.05, -0.012],
	"paper": [-0.05, -0.025],
	"structure": [0.0, -0.016],
	"secondary_ink": [-0.01, 0.0],
	"inward_preview": [-0.01, 0.0],
}


static func tint_for_day(day: int) -> float:
	if day <= 1:
		return 0.0
	if day >= 7:
		return 1.0
	return float(CURVE[day])


static func apply(roles: Dictionary, tint: float, high_contrast: bool = false, colour_preset: String = "standard") -> Dictionary:
	var result := roles.duplicate()
	if high_contrast or tint <= 0.0:
		return result
	var amount := clampf(tint, 0.0, 1.0)
	var lightness_only := colour_preset != "standard"
	for role: String in ROOM_ROLES:
		if not result.has(role) or not result[role] is Color:
			continue
		var deltas: Array = COLD_DELTAS[role]
		var lightness_delta := float(deltas[0]) * amount
		var saturation_delta := 0.0 if lightness_only else float(deltas[1]) * amount
		if is_zero_approx(lightness_delta) and is_zero_approx(saturation_delta):
			continue
		var source: Color = result[role]
		var lightness := clampf(source.ok_hsl_l + lightness_delta, 0.0, 1.0)
		var saturation := clampf(source.ok_hsl_s + saturation_delta, 0.0, 1.0)
		result[role] = Color.from_ok_hsl(source.ok_hsl_h, saturation, lightness, source.a)
	return result
