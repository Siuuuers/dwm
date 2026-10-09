extends GutTest

const LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")

# Deliberately injected issuer for lifecycle unit isolation; this is not durable
# identity/Profile acceptance evidence.
class IssuerProbe extends RefCounted:
	var refuse := false
	func verify_issued(_receipt: Dictionary, _purpose: StringName) -> Dictionary:
		return {"ok": not refuse, "code": &"injected_issuer_refusal"}
	func validate_child(_provenance: Dictionary, _kind: StringName) -> Dictionary:
		return {"ok": false, "code": &"injected_child_refusal"}

func _scene() -> Dictionary:
	return {"run_id": "test.run", "branch_id": "test.branch", "desktop_timeline_generation": 1,
		"causal_day_instance": "test.day", "causal_day_instance_issuer_receipt": {
			"counter": 1, "namespace": "test", "numeric_value": 1, "purpose": "causal_day_instance",
			"receipt_id": "test.receipt", "token": "test.day"},
		"restore_provenance": null, "state": "PLAYING", "scene_assignment": {
			"ruleset_id": "scene.new_run.alternating.v1", "form": "sweet", "selection_kind": "initial_random",
			"rng_nonce": 0, "predecessor_run_id": null, "predecessor_assignment_sha256": null,
			"creation_transaction_id": "test.creation"}}

func test_scene_restore_keeps_exact_assignment_and_detached_state() -> void:
	var owner := LIFECYCLE.new()
	var issuer := IssuerProbe.new()
	assert_true(owner.configure_scene_issuer(issuer).ok)
	var source := _scene()
	var prepared := owner.prepare_restore(source)
	assert_true(prepared.ok)
	assert_true(owner.commit_restore(prepared.value.candidate).ok)
	source.scene_assignment.form = "dark"
	var captured := owner.to_dict()
	assert_eq(captured, _scene())
	captured.scene_assignment.form = "dark"
	assert_eq(owner.to_dict(), _scene())
	assert_false(owner.to_dict().has("day"))
	assert_false(owner.to_dict().has("dark_mode"))

func test_scene_refuses_legacy_extras_and_unissued_identity_without_mutation() -> void:
	var owner := LIFECYCLE.new()
	var issuer := IssuerProbe.new()
	assert_true(owner.configure_scene_issuer(issuer).ok)
	assert_true(owner.commit_restore(_scene()).ok)
	var before := owner.to_dict()
	var mixed := _scene()
	mixed["day"] = 1
	assert_false(owner.commit_restore(mixed).ok)
	assert_eq(owner.to_dict(), before)
	issuer.refuse = true
	assert_false(owner.commit_restore(_scene()).ok)
	assert_eq(owner.to_dict(), before)

func test_scene_refuses_form_nonce_mismatch_and_missing_issuer() -> void:
	var source := _scene()
	source.scene_assignment.form = "dark"
	assert_false(LIFECYCLE.validate_scene(source, IssuerProbe.new()).ok)
	assert_false(LIFECYCLE.validate_scene(_scene(), null).ok)
