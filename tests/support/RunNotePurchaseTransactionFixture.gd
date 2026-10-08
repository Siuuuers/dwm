extends RefCounted
## Real final Bootstrap graph and native filesystem. Only catalogue CONTENT is synthetic.
## Fresh real participant/coordinator are configured once over Bootstrap's real shared
## owners. The production retained graph stays idle; configured identities are never replaced.
const NOTES := preload("res://tests/support/RunNotePurchaseFixture.gd")
const PROJECTION := preload("res://scripts/ui/notes/NotesCatalogProjection.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const PRESENTATION := preload("res://scripts/application/shop/ShopPresentationPort.gd")

class TestCatalog extends RefCounted:
	var delegate := preload("res://scripts/data/DataCatalog.gd").new()
	var overrides: Dictionary = {}
	func get_shop_items() -> Array: return delegate.get_shop_items()
	func get_shop_item(item_id: String) -> Dictionary:
		if overrides.has(item_id): return overrides[item_id].duplicate(true)
		if item_id in ["crystal_stutters", "inked_silk_string", "letter_with_wax_seal"]:
			return {"id": item_id, "currency": "money", "price": 45,
				"max_purchases": 3, "effect_ids": []}
		return delegate.get_shop_item(item_id)

class CaptureFault extends RefCounted:
	var target: Callable
	var failures := 0
	var calls := 0
	var armed := false
	func capture(candidate: Dictionary) -> Dictionary:
		calls += 1
		if armed and failures == 0:
			failures += 1
			return {"ok": false, "code": &"TEST_completion_capture_refused"}
		return target.call(candidate)

var tree: SceneTree
var game: Node
var saves: Node
var bootstrap: Node
var participant: RefCounted
var state_port: RefCounted
var coordinator: RefCounted
var issuer: RefCounted
var presentation: RefCounted
var catalog: RefCounted
var original_completion: Callable
var fault: RefCounted

func initialize(owner_tree: SceneTree, start_run: bool = true) -> Dictionary:
	tree = owner_tree
	if OS.get_environment("DWM_TEST_ROOT").is_empty():
		return {"ok": false, "code": "isolated_test_root_required"}
	for frame: int in 12: await tree.process_frame
	bootstrap = tree.root.get_node("ApplicationBootstrap")
	if not bootstrap.get_startup_state().get("ready", false):
		return {"ok": false, "code": "final_bootstrap_required", "details": bootstrap.get_startup_state()}
	game = tree.root.get_node("GameState")
	saves = tree.root.get_node("SaveManager")
	var retained: RefCounted = bootstrap.get("_retained_minesweeper_shop_purchase_participant")
	var retained_coordinator: RefCounted = bootstrap.get("_retained_desktop_consequence_coordinator")
	state_port = bootstrap.get("_retained_game_state_minesweeper_shop_port")
	issuer = bootstrap.get("_desktop_identity_nonce_issuer")
	var source: Callable = retained.get("_source_checkpoint_capture")
	original_completion = retained_coordinator.get("_completion_checkpoint_capture")
	if not source.is_valid() or not original_completion.is_valid():
		return {"ok": false, "code": "real_source_and_completion_callbacks_required"}
	catalog = TestCatalog.new()
	var configured: Dictionary = state_port.configure_note_catalogue(NOTES.catalogue())
	if not configured.get("ok", false): return configured
	participant = preload("res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd").new()
	configured = participant.configure_publication_ledger(retained.get("_publication_ledger"))
	if not configured.get("ok", false): return configured
	configured = participant.configure(state_port, retained.get("_consequence_state_port"),
		retained.get("_checkpoint_port"), retained.get("_registry"), issuer, retained.get("_mutation_gate"))
	if not configured.get("ok", false): return configured
	configured = participant.configure_catalog(catalog, source)
	if not configured.get("ok", false): return configured
	coordinator = preload("res://scripts/application/desktop/DesktopConsequenceCoordinator.gd").new()
	configured = coordinator.configure(retained_coordinator.get("_state_port"),
		retained_coordinator.get("_causal_sequence_port"), retained_coordinator.get("_board_fate_port"),
		retained_coordinator.get("_checkpoint_port"), retained_coordinator.get("_mutation_gate"))
	if not configured.get("ok", false): return configured
	configured = coordinator.configure_action_source_ports(bootstrap.get("_retained_minesweeper_round_coordinator_app"), participant)
	if not configured.get("ok", false): return configured
	configured = coordinator.configure_identity_issuer(issuer)
	if not configured.get("ok", false): return configured
	configured = coordinator.configure_condition_departure_ports(retained_coordinator.get("_condition_policy_port"), retained_coordinator.get("_schedule_view_port"))
	if not configured.get("ok", false): return configured
	configured = coordinator.configure_notification_consumer(retained_coordinator.get("_notification_consumer"), retained_coordinator.get("_notification_publisher"))
	if not configured.get("ok", false): return configured
	fault = CaptureFault.new()
	fault.target = original_completion
	configured = coordinator.configure_completion_checkpoint_capture(Callable(fault, "capture"))
	if not configured.get("ok", false): return configured
	if start_run: return await new_run()
	return {"ok": true}

func new_run() -> Dictionary:
	var result: Dictionary = saves.start_new_run({"route_id": "main", "dialogic_checkpoint": {},
		"active_app_id": null, "audio_context": {}, "content_version": 1})
	if not result.get("ok", false): return result
	for frame: int in 24: await tree.process_frame
	return bind_presentation()

func bind_presentation() -> Dictionary:
	presentation = PRESENTATION.new()
	return presentation.configure(game, catalog, participant, coordinator,
		bootstrap.get("_retained_minesweeper_round_coordinator_app"), issuer,
		bootstrap.get("_application_gate"))

func save_to(target: String) -> Dictionary:
	var prepared: Dictionary = saves.prepare_backup_action("save", target)
	if not prepared.get("ok", false): return prepared
	return saves.commit_backup_action(prepared.value.token)

func load_from(target: String) -> Dictionary:
	var prepared: Dictionary = saves.prepare_backup_action("load", target)
	if not prepared.get("ok", false): return prepared
	var committed: Dictionary = saves.commit_backup_action(prepared.value.token)
	if not committed.get("ok", false): return committed
	for frame: int in 24: await tree.process_frame
	return bind_presentation()

func disk_text(path: String = "autosave.json") -> String:
	var storage: RefCounted = saves.get("_storage")
	return FileAccess.get_file_as_string(storage.describe_root().path_join(path))

func disk_snapshot(path: String = "autosave.json") -> Dictionary:
	var parsed: Dictionary = STRICT.parse_object(disk_text(path))
	if not parsed.get("ok", false): return parsed
	var checked: Dictionary = DOCUMENT.validate(parsed.value)
	if not checked.get("ok", false): return checked
	return {"ok": true, "value": checked.value.candidate.current_snapshot.snapshot}

func witness() -> Dictionary:
	return {"run": game.capture_run_snapshot_input().duplicate(true),
		"profile": tree.root.get_node("ProfileManager").get_profile_snapshot().duplicate(true),
		"reading": tree.root.get_node("DialogicBridge").capture_reading_checkpoint(false).duplicate(true)}

func projection() -> Dictionary:
	return PROJECTION.project(game.shop_purchase_counts, NOTES.catalogue())

func request_for(item_id: String) -> Dictionary:
	var issued: Dictionary = issuer.issue(&"transaction_id")
	if not issued.get("ok", false): return issued
	var quote: Dictionary = participant.quote(item_id, issued.value.token, issued.value.issuer_receipt)
	if not quote.get("ok", false): return quote
	var state: Dictionary = bootstrap.get("_desktop_consequence_state").capture().value.state
	return {"ok": true, "value": {"transaction_id": issued.value.token,
		"transaction_issuer_receipt": issued.value.issuer_receipt, "item_id": item_id,
		"quote_id": quote.value.quote_id, "expected_run_revision": state.run_revision,
		"expected_causal_day_instance": state.causal_day_instance}}

func arm_completion_fault() -> void:
	fault.armed = true

func dispose() -> void:
	# No shared owner replacement or manually released transaction custody.
	pass
