extends "res://addons/gut/test.gd"
const FIXTURE := preload("res://tests/support/SceneMultipleThoughtFixture.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const IDENTITY := preload("res://tests/support/SceneTransitionIdentityFixture.gd")

func _marker(bundle: Dictionary) -> Dictionary:
	for row: Dictionary in bundle.scene_programme.entries:
		if row.entry_id == "scene.test.partner.shared": return row.markers[0]
	return {}

func test_options_validate_all_targets_and_reject_ambiguous_or_forged_choices() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok, str(built))
	if not built.ok: return
	assert_true(FIXTURE.PARTNER.MANIFEST.validate_scene_registration(built.value).ok)
	assert_true(CONTRACT.validate_bundle_structure(built.value).ok)
	for mutation: String in ["empty", "duplicate", "reserved", "missing_target", "default_target", "empty_text"]:
		var bad: Dictionary = built.value.duplicate(true)
		var marker := _marker(bad)
		match mutation:
			"empty": marker.payload.options = []
			"duplicate": marker.payload.options[1].choice_id = "first"
			"reserved": marker.payload.options[0].choice_id = "pass"
			"missing_target": marker.payload.options[0].target_id = "missing"
			"default_target": marker.payload.options[0].target_id = marker.payload.pass_target_id
			"empty_text": marker.payload.options[0].text = "   "
		assert_false(CONTRACT.validate_bundle_structure(bad).ok, mutation)
		assert_false(FIXTURE.PARTNER.MANIFEST.validate_scene_registration(bad).ok, mutation)

func test_each_choice_and_default_receipt_authenticates_the_registered_offer() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok, str(built))
	if not built.ok: return
	var identity: RefCounted = IDENTITY.new()
	assert_true(identity.setup().ok)
	var event: Dictionary = identity.event.duplicate(true)
	event.source.entry_id = "scene.test.partner.shared"
	event.event_id = "scene.test.partner.expiry"
	var anchor: Dictionary = identity.anchor.duplicate(true)
	anchor.entry_id = event.source.entry_id
	anchor.line_id = "line.scene.test.partner.shared.offer"
	var targets := {"first": "partner.sylvia", "second": "partner.lavinia", "pass": "partner.benchmark"}
	for choice: String in targets:
		event.kind = "thought.options" if choice == "pass" else "thought.select"
		event.payload = _marker(built.value).payload.duplicate(true)
		if choice != "pass": event.payload["choice_id"] = choice
		var result := {"kind": "thought_resolved", "opportunity_id": "TEST.partner", "choice": choice, "target_id": targets[choice]}
		assert_true(CONTRACT.make_scene_receipt(event, anchor, result, built.value).ok, choice)
		var wrong := result.duplicate(true)
		wrong.target_id = "partner.shared"
		assert_false(CONTRACT.make_scene_receipt(event, anchor, wrong, built.value).ok)
		var spoof := event.duplicate(true)
		spoof.payload.options[0].text = "Unregistered offer"
		assert_false(CONTRACT.inspect_scene(spoof, built.value).ok)
		spoof = event.duplicate(true)
		spoof.kind = "thought.select"
		spoof.payload["choice_id"] = "missing"
		assert_false(CONTRACT.inspect_scene(spoof, built.value).ok)
		var old := anchor.duplicate(true)
		old.line_id = "line.scene.test.partner.shared.before"
		assert_false(CONTRACT.make_scene_receipt(event, old, result, built.value).ok)
