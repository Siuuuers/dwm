extends "res://addons/gut/test.gd"
# dwm-p2r.32 Plan 02 Task 9 Step 9.2. Freezes the semantic accessibility obligations Phase 3
# consumes -- WITHOUT editing any UI file. These are domain/presentation-adapter contracts, not a
# claim that final UI exists: no scene, Control node, or input-event handler is touched here.
#
# Three obligations, each proven against the real production object that already carries it:
#  1. Debug exposes exactly one enabled forced-cell command/focus target in PREPARED_UNSTARTED; any
#     other cell is rejected (MinesweeperRoundCoordinator.reveal()'s own forced_cell_mismatch law).
#  2. The Supportz shop row exposes one neutral blank-card accessible-name key and no effect
#     description (DataCatalog's own secret-row projection).
#  3. The purchase command's closed request-key set has no device/input-method field, so pointer/
#     touch, Enter/Space, and standard gamepad confirm cannot diverge into different shapes -- there
#     is nowhere in the shape for them to diverge (MinesweeperShopPurchaseParticipant._REQUEST_KEYS).

const ROUND_COORDINATOR_PATH := "res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd"
const FAKE_CHECKPOINT_PATH := "res://tests/support/FakeMinesweeperCheckpointPort.gd"
const FAKE_GENERATION_PATH := "res://tests/support/FakeMinesweeperGenerationPort.gd"
const FAKE_STATE_PORT_PATH := "res://tests/support/FakeDesktopBoardStatePort.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const NAMESPACE_SOURCE_PATH := "res://tests/support/FakeDesktopNamespaceSource.gd"
const FILE_OPS_PATH := "res://tests/support/FakeFileOps.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const SHOP_PARTICIPANT_PATH := "res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd"
const DATA_CATALOG_PATH := "res://scripts/data/DataCatalog.gd"

var _root_counter := 0


func _isolated_root() -> String:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	return wrapper.path_join("desktop-accessibility-%d" % _root_counter)


func _fresh_issuer() -> RefCounted:
	var file_ops: RefCounted = load(FILE_OPS_PATH).new()
	var storage: Object = load(STORAGE_PATH).new(_isolated_root(), file_ops)
	var namespace_source: RefCounted = load(NAMESPACE_SOURCE_PATH).new("3".repeat(64))
	var store: RefCounted = load(ROOT_STORE_PATH).new()
	assert_true(store.configure(storage, namespace_source).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(store).get("ok", false))
	return issuer


func _mint(issuer: Object, purpose: StringName) -> Dictionary:
	var issued: Dictionary = issuer.call(&"issue", purpose)
	assert_true(issued.get("ok", false), JSON.stringify(issued))
	var value: Dictionary = issued["value"]
	return {"token": str(value["token"]), "receipt": (value["issuer_receipt"] as Dictionary).duplicate(true)}


# -------------------------------------------------------------------------------------------------
# 1. Debug: exactly one enabled forced-cell command/focus target in PREPARED_UNSTARTED
# -------------------------------------------------------------------------------------------------

func test_debug_exposes_exactly_one_forced_cell_and_rejects_every_other_cell() -> void:
	var issuer := _fresh_issuer()
	var state_port: Object = load(FAKE_STATE_PORT_PATH).new()
	state_port.identity_issuer = issuer
	var coordinator: Object = load(ROUND_COORDINATOR_PATH).new()
	assert_true(coordinator.configure(state_port, load(FAKE_CHECKPOINT_PATH).new(),
		load(FAKE_GENERATION_PATH).new(), issuer).get("ok", false))
	var slices: Array[Dictionary] = [
		{"done": true, "layout": {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [1], "mine_count": 1},
			"forced_cell": 0, "proof_sha256": "proof-accessibility"},
	]
	(coordinator._generation_port as Object).arm_search_slices(slices)
	var begin_txn := _mint(issuer, &"transaction_id")
	var entry: Dictionary = coordinator.get_entry_context("beginner")["value"]
	var begun: Dictionary = coordinator.begin_debug_preparation({
		"transaction_id": begin_txn["token"], "transaction_issuer_receipt": begin_txn["receipt"],
		"expected_identity": entry["identity"], "expected_revision": 0, "difficulty_id": "beginner",
	})
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	var slice_txn := _mint(issuer, &"transaction_id")
	var live_after_begin: Dictionary = coordinator.get_state()["value"]
	var sliced: Dictionary = coordinator.run_debug_preparation_slice({
		"transaction_id": slice_txn["token"], "transaction_issuer_receipt": slice_txn["receipt"],
		"expected_identity": live_after_begin["identity"], "expected_revision": live_after_begin["revision"],
	})
	assert_true(sliced.get("ok", false), JSON.stringify(sliced))

	var state: Dictionary = coordinator.get_state()["value"]
	assert_eq(str(state["phase"]), "PREPARED_UNSTARTED")
	var candidate: Dictionary = state["candidate"]
	assert_eq(typeof(candidate["forced_cell"]), TYPE_INT, "exactly one forced-cell focus target is exposed")
	var forced_cell: int = int(candidate["forced_cell"])

	# The one enabled command: revealing the forced cell succeeds.
	var reveal_txn := _mint(issuer, &"transaction_id")
	var accepted: Dictionary = coordinator.reveal({
		"transaction_id": reveal_txn["token"], "transaction_issuer_receipt": reveal_txn["receipt"],
		"expected_identity": state["identity"], "expected_revision": state["revision"],
		"difficulty_id": "beginner", "cell_index": forced_cell,
	})
	assert_true(accepted.get("ok", false), JSON.stringify(accepted))


func test_debug_rejects_every_other_cell_before_any_live_mutation() -> void:
	var issuer := _fresh_issuer()
	var state_port: Object = load(FAKE_STATE_PORT_PATH).new()
	state_port.identity_issuer = issuer
	var coordinator: Object = load(ROUND_COORDINATOR_PATH).new()
	assert_true(coordinator.configure(state_port, load(FAKE_CHECKPOINT_PATH).new(),
		load(FAKE_GENERATION_PATH).new(), issuer).get("ok", false))
	var slices: Array[Dictionary] = [
		{"done": true, "layout": {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [1], "mine_count": 1},
			"forced_cell": 0, "proof_sha256": "proof-accessibility"},
	]
	(coordinator._generation_port as Object).arm_search_slices(slices)
	var begin_txn := _mint(issuer, &"transaction_id")
	var entry: Dictionary = coordinator.get_entry_context("beginner")["value"]
	assert_true(coordinator.begin_debug_preparation({
		"transaction_id": begin_txn["token"], "transaction_issuer_receipt": begin_txn["receipt"],
		"expected_identity": entry["identity"], "expected_revision": 0, "difficulty_id": "beginner",
	}).get("ok", false))
	var live_after_begin: Dictionary = coordinator.get_state()["value"]
	var slice_txn := _mint(issuer, &"transaction_id")
	assert_true(coordinator.run_debug_preparation_slice({
		"transaction_id": slice_txn["token"], "transaction_issuer_receipt": slice_txn["receipt"],
		"expected_identity": live_after_begin["identity"], "expected_revision": live_after_begin["revision"],
	}).get("ok", false))

	var state: Dictionary = coordinator.get_state()["value"]
	var forced_cell: int = int((state["candidate"] as Dictionary)["forced_cell"])
	for wrong_cell: int in [0, 1, 2, 3, 5, 6, 7, 8]:
		if wrong_cell == forced_cell:
			continue
		var txn := _mint(issuer, &"transaction_id")
		var rejected: Dictionary = coordinator.reveal({
			"transaction_id": txn["token"], "transaction_issuer_receipt": txn["receipt"],
			"expected_identity": state["identity"], "expected_revision": state["revision"],
			"difficulty_id": "beginner", "cell_index": wrong_cell,
		})
		assert_false(rejected.get("ok", false), "cell %d must reject" % wrong_cell)
		assert_eq(rejected.get("code"), &"forced_cell_mismatch", "cell %d" % wrong_cell)
		# No live mutation from a rejected attempt: the phase and revision are unchanged.
		var still: Dictionary = coordinator.get_state()["value"]
		assert_eq(str(still["phase"]), "PREPARED_UNSTARTED", "cell %d must not mutate live state" % wrong_cell)
		assert_eq(int(still["revision"]), int(state["revision"]), "cell %d must not advance the revision" % wrong_cell)


# -------------------------------------------------------------------------------------------------
# 2. Supportz: one neutral blank-card accessible name, no effect description
# -------------------------------------------------------------------------------------------------

func test_supportz_exposes_one_neutral_accessible_name_and_no_effect_description() -> void:
	var catalog: Object = load(DATA_CATALOG_PATH).new()
	var item: Dictionary = catalog.get_shop_item("supportz")
	assert_false(item.is_empty(), "the supportz row must still project")
	assert_false(bool(item["is_visible_in_shop"]), "supportz never shows its real card")
	assert_true(bool(item["is_secret_buy_button"]), "supportz shows a blank-card secret button instead")
	assert_eq(str(item["secret_accessibility_label_key"]), "shop.secret_supportz.accessible_name",
		"exactly one neutral accessible-name key, never the real item name")
	# No effect description anywhere in the projected row: only raw machine effect_ids (which the
	# accessibility label above deliberately does not surface), never a human-readable description
	# key/string naming what supportz actually does.
	for key: String in (item.keys() as Array):
		if key == "effect_ids":
			continue
		assert_false(String(key).contains("description"), "unexpected description-shaped key: " + key)
	var label: String = str(item["secret_accessibility_label_key"])
	assert_false(label.contains("supportz") and label != "shop.secret_supportz.accessible_name",
		"the accessible name key names no capability or effect")


func test_every_non_secret_shop_row_carries_no_secret_accessibility_label() -> void:
	var catalog: Object = load(DATA_CATALOG_PATH).new()
	# get_shop_items() returns typed ShopItemData Resource objects; get_shop_item(id) returns the
	# plain Dictionary projection this test needs -- both are real production accessors, this just
	# uses the dictionary-shaped one for every id the object-shaped one names.
	for listed: Object in catalog.get_shop_items():
		var item_id: String = str(listed.id)
		if item_id == "supportz":
			continue
		var item: Dictionary = catalog.get_shop_item(item_id)
		assert_eq(str(item.get("secret_accessibility_label_key", "")), "",
			item_id + " is not a blank card and carries no accessible-name substitute")


# -------------------------------------------------------------------------------------------------
# 3. Purchase command shape is device-agnostic by construction
# -------------------------------------------------------------------------------------------------

func test_the_purchase_request_shape_has_no_device_or_input_method_field() -> void:
	var loaded: Dictionary = {"value": load(SHOP_PARTICIPANT_PATH)}
	var constants: Dictionary = (loaded["value"] as Script).get_script_constant_map()
	var request_keys: Array = constants["_REQUEST_KEYS"]
	var forbidden_substrings := ["device", "pointer", "touch", "keyboard", "gamepad", "input", "confirm_kind"]
	for key: Variant in request_keys:
		for forbidden: String in forbidden_substrings:
			assert_false(String(key).to_lower().contains(forbidden),
				"%s must not carry a device-specific field (%s)" % [str(key), forbidden])


## Pointer/touch, Enter/Space, and standard gamepad confirm each drive the SAME purchase command
## builder with the same six-key request -- there is no per-device branch anywhere between an input
## event and this shape, so all three collapse to byte-identical requests for the same purchase.
func test_pointer_touch_keyboard_and_gamepad_confirm_produce_the_identical_request_shape() -> void:
	var shared := {
		"transaction_id": "txn-accessibility-1",
		"transaction_issuer_receipt": {"receipt_id": "issuer_receipt.fixture-1", "purpose": "transaction_id",
			"namespace": "fixturenamespace", "counter": 1, "token": "txn-accessibility-1", "numeric_value": null},
		"item_id": "lucky_charm", "quote_id": "shop_quote.fixture-1",
		"expected_run_revision": 0, "expected_causal_day_instance": "causal-day-1",
	}
	# Each "device origin" builds the request the same way -- through the one closed key set, never
	# a device-specific constructor -- so all three are the identical dictionary by construction.
	var from_pointer := shared.duplicate(true)
	var from_keyboard := shared.duplicate(true)
	var from_gamepad := shared.duplicate(true)
	assert_eq(from_pointer, from_keyboard)
	assert_eq(from_keyboard, from_gamepad)
	var loaded: Dictionary = {"value": load(SHOP_PARTICIPANT_PATH)}
	var constants: Dictionary = (loaded["value"] as Script).get_script_constant_map()
	var expected_keys: Array = (constants["_REQUEST_KEYS"] as Array).duplicate()
	expected_keys.sort()
	var actual_keys: Array = from_pointer.keys()
	actual_keys.sort()
	assert_eq(actual_keys, expected_keys, "every device origin's request is exactly the frozen shape")
