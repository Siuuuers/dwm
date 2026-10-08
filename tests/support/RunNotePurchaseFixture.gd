extends RefCounted

## Synthetic engineering fixture only. None of these IDs/texts register content.
const ITEMS := ["crystal_stutters", "inked_silk_string", "letter_with_wax_seal"]

static func catalogue() -> Dictionary:
	var result: Dictionary = {}
	for item: String in ITEMS:
		var notes: Array = []
		for ordinal: int in range(1, 4):
			notes.append({"id": "TEST.%s.%d" % [item, ordinal],
				"text": "TEST ONLY: synthetic %s note %d." % [item, ordinal]})
		result[item] = notes
	return result

static func counts() -> Dictionary:
	return {"crystal_stutters": 0, "inked_silk_string": 0,
		"letter_with_wax_seal": 0, "supportz": 8, "lucky_charm": 1}
