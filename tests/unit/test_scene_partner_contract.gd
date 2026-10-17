extends "res://addons/gut/test.gd"
const FIXTURE := preload("res://tests/support/ScenePartnerForkFixture.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const IDENTITY := preload("res://tests/support/SceneTransitionIdentityFixture.gd")

func test_binding_requires_two_registered_scene_targets_and_unique_opportunity() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok, str(built))
	if not built.ok: return
	assert_true(FIXTURE.MANIFEST.validate_scene_registration(built.value).ok)
	assert_true(CONTRACT.validate_bundle_structure(built.value).ok)
	for mutation: String in ["missing", "same", "accept", "wrong_line"]:
		var bad: Dictionary = built.value.duplicate(true)
		var marker: Dictionary = bad.scene_programme.entries[1].markers[0]
		match mutation:
			"missing": marker.payload.yes_target_id = "missing"
			"same": marker.payload.yes_target_id = marker.payload.pass_target_id
			"accept": marker.kind = "thought.accept"
			"wrong_line": marker.after_line_id = "line.scene.test.partner.shared.before"
		var structural: Dictionary = CONTRACT.validate_bundle_structure(bad)
		var full: Dictionary = FIXTURE.MANIFEST.validate_scene_registration(bad)
		assert_false(structural.ok and full.ok, mutation)

func test_yes_and_pass_are_bound_to_authored_payload_and_exact_anchor() -> void:
	var built: Dictionary = FIXTURE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	var fixture: RefCounted = IDENTITY.new()
	var setup: Dictionary = fixture.setup()
	assert_true(setup.ok, str(setup))
	if not setup.ok: return
	var event: Dictionary = fixture.event.duplicate(true)
	event.source.entry_id = "scene.test.partner.shared"
	event.event_id = "scene.test.partner.expiry"
	event.payload = built.value.scene_programme.entries[1].markers[0].payload.duplicate(true)
	var anchor: Dictionary = fixture.anchor.duplicate(true)
	anchor.entry_id = event.source.entry_id
	anchor.line_id = "line.scene.test.partner.shared.offer"
	for accepted: bool in [true, false]:
		event.kind = "thought.accept" if accepted else "thought.pass"
		var result := {"kind": "thought_resolved", "opportunity_id": "TEST.partner", "choice": "yes" if accepted else "pass",
			"target_id": "partner.sylvia" if accepted else "partner.lavinia"}
		var receipt: Dictionary = CONTRACT.make_scene_receipt(event, anchor, result, built.value)
		assert_true(receipt.ok, str(receipt))
		var wrong := result.duplicate(true)
		wrong.target_id = "partner.lavinia" if accepted else "partner.sylvia"
		assert_false(CONTRACT.make_scene_receipt(event, anchor, wrong, built.value).ok)
		var old := anchor.duplicate(true)
		old.line_id = "line.scene.test.partner.shared.before"
		assert_false(CONTRACT.make_scene_receipt(event, old, result, built.value).ok)
		var spoof := event.duplicate(true)
		spoof.payload.yes_target_id = "partner.lavinia"
		assert_false(CONTRACT.inspect_scene(spoof, built.value).ok)
