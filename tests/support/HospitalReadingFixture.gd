extends RefCounted
## Explicit noncanonical prose only. Canonical commands, frozen facts and physical
## completion must come from the real owners in connected runtime fixtures.

static func catalogue(day: int = 3) -> Dictionary:
	return {"kind": "hospital_reading_catalogue", "schema_version": 1, "entries": [{
		"entry_id": "hospital.faint.day%d" % day, "content_version": 1, "lines": [
			{"beat_id": "fixture.hospital.a", "line_id": "fixture.hospital.a",
				"revision": "fixture-hospital-v1",
				"text": "This first noncanonical Hospital fixture caption marks a fresh reading session."},
			{"beat_id": "fixture.hospital.b", "line_id": "fixture.hospital.b",
				"revision": "fixture-hospital-v1",
				"text": "This second noncanonical Hospital fixture caption deliberately leaves enough text to observe a partial reveal, open Pause, cancel without changing the line, and explicitly save its current stable point."},
		]}]}
