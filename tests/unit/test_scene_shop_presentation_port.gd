extends "res://addons/gut/test.gd"

const PORT := preload("res://scripts/application/shop/ShopPresentationPort.gd")
const LEGACY_FIXTURES := preload("res://tests/unit/test_shop_presentation_port.gd")
const CATALOG := preload("res://scripts/data/DataCatalog.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

class SceneOwner extends RefCounted:
	var inventory: Dictionary = {}
	var gate: RefCounted
	var generation := 1
	var previews: Array = []
	var commits: Array = []
	var commit_ok := false
	var occurrence := "scene-a"
	var source_captures := 0

	func _init(value: RefCounted) -> void:
		gate = value

	func can_spend_money(_amount: int) -> bool:
		return true

	func can_spend_coins(_amount: int) -> bool:
		return true

	func get_mutation_gate_instance_id() -> int:
		return gate.get_instance_id()

	func capture_live_session() -> Dictionary:
		return {"ok": true, "value": {"generation": generation}}

	func validate_live_session(handle: Dictionary) -> Dictionary:
		var guarded: Dictionary = gate.guard_external(&"live_session")
		if not guarded.get("ok", false): return guarded
		return {"ok": handle == {"generation": generation}, "code": &"stale_live_session"}

	func capture_scene_shop_context() -> Dictionary:
		source_captures += 1
		return {"ok": true, "value": {"identity": {"generation": generation}, "scene_occurrence": occurrence}}

	func preview_scene_shop_purchase(source_id: String, quantity: int) -> Dictionary:
		previews.append([source_id, quantity])
		return {"ok": true, "value": {"eligible": true, "total": 45 * quantity}}

	func commit_scene_shop_purchase(source_id: String, quantity: int,
			transaction_id: String, issuer_receipt: Dictionary, source_context: Dictionary) -> Dictionary:
		commits.append([source_id, quantity, transaction_id, issuer_receipt.duplicate(true), source_context.duplicate(true)])
		if source_context.scene_occurrence != occurrence:
			return {"ok": false, "code": &"scene_shop_source_changed"}
		source_context.scene_occurrence = "mutated-by-owner"
		# Deliberately mutate the supplied receipt: the port must retain detached retry bytes.
		issuer_receipt["token"] = "mutated-by-owner"
		return {"ok": commit_ok, "code": &"ok" if commit_ok else &"checkpoint_write_failed"}


func test_scene_retry_keeps_issued_request_and_does_not_requote() -> void:
	var gate := GATE.new()
	var owner := SceneOwner.new(gate)
	var catalog := CATALOG.new()
	var issuer := LEGACY_FIXTURES.Issuer.new()
	var port := PORT.new()
	assert_true(port.configure_scene(owner, catalog, issuer, gate).ok)
	assert_false(port.purchase("bookend_keepsake", 1).ok)
	assert_true(port.has_pending_purchase())
	assert_eq(owner.previews, [["priscilla_gift", 1]])
	assert_eq(owner.commits[0][0], "priscilla_gift")
	assert_eq(issuer.next, 1)
	assert_eq(port.purchase("wine", 1).code, &"shop_purchase_pending")
	assert_eq(owner.commits.size(), 1)
	owner.commit_ok = true
	assert_true(port.purchase("bookend_keepsake", 1).ok)
	assert_eq(owner.commits[1], owner.commits[0])
	assert_eq(owner.previews.size(), 1)
	assert_eq(owner.source_captures, 1)
	assert_eq(issuer.next, 1)
	assert_false(port.has_pending_purchase())


func test_scene_pending_retry_cannot_cross_session() -> void:
	var gate := GATE.new()
	var owner := SceneOwner.new(gate)
	var catalog := CATALOG.new()
	var issuer := LEGACY_FIXTURES.Issuer.new()
	var port := PORT.new()
	assert_true(port.configure_scene(owner, catalog, issuer, gate).ok)
	assert_false(port.purchase("wine", 1).ok)
	owner.generation += 1
	assert_eq(port.purchase("wine", 1).code, &"stale_live_session")
	assert_eq(owner.commits.size(), 1)
	assert_eq(issuer.next, 1)
	assert_true(port.has_pending_purchase())


func test_scene_configuration_requires_shared_gate_and_cannot_switch_mode() -> void:
	var gate := GATE.new()
	var other_gate := GATE.new()
	var owner := SceneOwner.new(gate)
	var catalog := CATALOG.new()
	var issuer := LEGACY_FIXTURES.Issuer.new()
	var port := PORT.new()
	assert_eq(port.configure_scene(owner, catalog, issuer, other_gate).code, &"shop_mutation_gate_mismatch")
	assert_true(port.configure_scene(owner, catalog, issuer, gate).ok)
	assert_true(port.configure_scene(owner, catalog, issuer, gate).value.already_configured)
	assert_eq(port.configure_scene(owner, catalog, LEGACY_FIXTURES.Issuer.new(), gate).code,
		&"shop_presentation_port_already_configured")


func test_configured_legacy_port_rejects_scene_reconfiguration() -> void:
	var gate := GATE.new()
	var owner := SceneOwner.new(gate)
	var catalog := CATALOG.new()
	var issuer := LEGACY_FIXTURES.Issuer.new()
	var port := PORT.new()
	assert_true(port.configure(owner, catalog, LEGACY_FIXTURES.PurchaseParticipant.new(),
		LEGACY_FIXTURES.ConsequenceCoordinator.new(), LEGACY_FIXTURES.RoundCoordinator.new(),
		issuer, gate).ok)
	assert_eq(port.configure_scene(owner, catalog, issuer, gate).code,
		&"shop_presentation_port_already_configured")


func test_configured_scene_port_rejects_legacy_reconfiguration() -> void:
	var gate := GATE.new()
	var owner := SceneOwner.new(gate)
	var catalog := CATALOG.new()
	var issuer := LEGACY_FIXTURES.Issuer.new()
	var port := PORT.new()
	assert_true(port.configure_scene(owner, catalog, issuer, gate).ok)
	assert_eq(port.configure(owner, catalog, LEGACY_FIXTURES.PurchaseParticipant.new(),
		LEGACY_FIXTURES.ConsequenceCoordinator.new(), LEGACY_FIXTURES.RoundCoordinator.new(),
		issuer, gate).code, &"shop_presentation_port_already_configured")


func test_changed_source_releases_refused_pending_without_retargeting_it() -> void:
	var gate := GATE.new()
	var owner := SceneOwner.new(gate)
	var catalog := CATALOG.new()
	var issuer := LEGACY_FIXTURES.Issuer.new()
	var port := PORT.new()
	assert_true(port.configure_scene(owner, catalog, issuer, gate).ok)
	assert_false(port.purchase("wine", 1).ok)
	owner.occurrence = "scene-b"
	assert_eq(port.purchase("wine", 1).code, &"scene_shop_source_changed")
	assert_false(port.has_pending_purchase())
	assert_eq(owner.commits[1][4].scene_occurrence, "scene-a")
	assert_eq(issuer.next, 1)
	owner.commit_ok = true
	assert_true(port.purchase("wine", 1).ok)
	assert_eq(owner.commits[2][4].scene_occurrence, "scene-b")
	assert_eq(issuer.next, 2)
