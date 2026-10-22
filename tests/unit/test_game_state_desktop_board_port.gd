extends "res://addons/gut/test.gd"
## Mint-law coverage for GameStateDesktopBoardPort.prepare_spec() (dwm-634.1, first-Reveal cost
## slice). The four spec identities mint through the issuer's DEFERRED seam, so a first Reveal
## rewrites the issuer root once -- inside the pre-board checkpoint's own before-write flush --
## instead of once per mint.
##
## SUBSTRATE. The real GameState autoload script and the real DesktopIdentityNonceIssuer over
## FakeDesktopIssuerRootStore, mirroring test_game_state_desktop_condition_context_port.gd's own
## established wiring. Nothing here reaches storage: the fake root store records the calls.
##
## SCOPE HONESTY. This suite proves only WHICH issuance seam prepare_spec() takes and that the spec
## it returns still carries four ledger-verifiable identities. The rest of the port's Task-5/6
## contract stays owned by tests/integration/test_minesweeper_first_reveal_transaction.gd.

const PORT := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"

const IDENTITY_CONTEXT := {
	"run_id": "run-board-port", "branch_id": "branch-board-port",
	"desktop_timeline_generation": 0, "causal_day_instance": "causal-day-board-port",
}

## The four identities prepare_spec() mints, each paired with the spec token member and the spec
## receipt-id member it lands in.
const SPEC_MINTS: Array = [
	["board_id", "board_token", "board_token_receipt_id"],
	["placement_nonce", "placement_nonce", "placement_nonce_receipt_id"],
	["debug_nonce", "debug_nonce", "debug_nonce_receipt_id"],
	["explosion_nonce", "explosion_nonce", "explosion_nonce_receipt_id"],
]


## An issuer from before the deferred seam existed: it exposes `issue` and nothing else, so the
## port's has_method() fallback is the only thing that can keep it working.
class DurableOnlyIssuer:
	var root: Object = null

	func _init(root_store: Object) -> void:
		root = root_store

	func issue(purpose: StringName) -> Dictionary:
		return root.issue(purpose)


var _root_store: FAKE_ROOT_STORE
var _issuer: ISSUER
var _game_state: Node = null
var _port: Object = null


func before_each() -> void:
	_root_store = FAKE_ROOT_STORE.new("77".repeat(32), 1)
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(_root_store).get("ok", false))
	_game_state = load(GAME_STATE_PATH).new()
	autofree(_game_state)
	_game_state.reset_game()
	_port = PORT.new()
	assert_true(_port.configure(_game_state, _issuer, IDENTITY_CONTEXT).get("ok", false))


## Minted straight off the fake's ledger helper rather than through `issue()`, so building the
## request logs no issuance of its own and the counts below are prepare_spec()'s alone.
func _transaction_receipt(store: FAKE_ROOT_STORE) -> Dictionary:
	return store.mint(&"transaction_id").duplicate(true)


func test_prepare_spec_mints_its_four_identities_deferred() -> void:
	var receipt := _transaction_receipt(_root_store)
	var prepared: Dictionary = _port.prepare_spec("beginner", str(receipt["token"]), receipt)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return
	assert_eq(_root_store.calls_to(&"issue_deferred").size(), 4,
		"board_id, placement_nonce, debug_nonce and explosion_nonce all mint in memory")
	assert_eq(_root_store.calls_to(&"issue").size(), 0,
		"no spec identity rewrites the issuer root on its own")
	var deferred_purposes: Array = []
	for entry: Dictionary in _root_store.calls_to(&"issue_deferred"):
		deferred_purposes.append(str(entry["argument"]))
	assert_eq(deferred_purposes, ["board_id", "placement_nonce", "debug_nonce", "explosion_nonce"],
		"the mint order is unchanged")
	var spec: Dictionary = (prepared["value"] as Dictionary)["spec"]
	for mint_spec: Array in SPEC_MINTS:
		var purpose := StringName(str(mint_spec[0]))
		var token_key := str(mint_spec[1])
		var receipt_key := str(mint_spec[2])
		assert_true(spec.has(token_key), "the spec still carries " + token_key)
		var recorded_value: Variant = _root_store.receipts.get(str(spec.get(receipt_key, "")))
		assert_true(recorded_value is Dictionary, "the deferred receipt reached the ledger: " + receipt_key)
		if not recorded_value is Dictionary:
			continue
		var recorded: Dictionary = (recorded_value as Dictionary).duplicate(true)
		assert_eq(str(recorded.get("token", "")), str(spec.get(token_key, "")),
			"the spec carries the token that deferred receipt minted: " + token_key)
		assert_true(_issuer.verify_issued(recorded, purpose).get("ok", false),
			"a deferred receipt verifies at once: " + token_key)


func test_prepare_spec_falls_back_to_issue_when_the_issuer_has_no_deferred_seam() -> void:
	var legacy_root: FAKE_ROOT_STORE = FAKE_ROOT_STORE.new("88".repeat(32), 1)
	var legacy_issuer := DurableOnlyIssuer.new(legacy_root)
	assert_false(legacy_issuer.has_method("issue_deferred"),
		"the fallback is unreachable unless this double really lacks the deferred seam")
	var legacy_port: Object = PORT.new()
	assert_true(legacy_port.configure(_game_state, legacy_issuer, IDENTITY_CONTEXT).get("ok", false))
	var receipt := _transaction_receipt(legacy_root)
	var prepared: Dictionary = legacy_port.prepare_spec("beginner", str(receipt["token"]), receipt)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_eq(legacy_root.calls_to(&"issue").size(), 4,
		"an issuer without the deferred seam keeps the durable path")
	assert_eq(legacy_root.calls_to(&"issue_deferred").size(), 0,
		"and nothing invents a seam the issuer never offered")



func test_first_reveal_charges_round_only_and_rollback_preserves_pressure() -> void:
	_game_state.stats = {"pressure": 3}
	var before: Dictionary = _port.capture()
	assert_true(before.ok)
	assert_true(before.value.eligible, "no Motivation stat is required")
	assert_false(before.value.has("motivation"))
	assert_false(before.value.has("health"))
	var root := _transaction_receipt(_root_store)
	# This is the producer's detached board projection, not a rendered gameplay claim.
	var projection := {
		"identity": {"run_id": IDENTITY_CONTEXT.run_id, "branch_id": IDENTITY_CONTEXT.branch_id,
			"desktop_timeline_generation": 0, "causal_day_instance": IDENTITY_CONTEXT.causal_day_instance,
			"app_round_ordinal": 1},
		"difficulty_id": "beginner", "cell_index": 0,
		"board": {"width": 9, "height": 9, "mine_indices": [80], "mine_count": 1, "revision": 0},
		"proof_sha256": null,
	}
	var prepared: Dictionary = _port.prepare_first_reveal(projection, str(root.token), root, "checkpoint-first")
	assert_true(prepared.ok, JSON.stringify(prepared))
	if not prepared.ok: return
	assert_false(prepared.value.receipt.has("motivation_before"))
	assert_false(prepared.value.receipt.has("motivation_after"))
	assert_eq(prepared.value.receipt.rounds_after, prepared.value.receipt.rounds_before - 1)
	assert_eq(_game_state.minesweeper_rounds_left, before.value.rounds_left, "preparation is silent")
	assert_true(_port.commit(prepared.value.run_candidate).ok)
	assert_eq(_game_state.minesweeper_rounds_left, before.value.rounds_left - 1)
	assert_eq(_game_state.stats, {"pressure": 3})
	assert_true(_port.rollback(before.value.backup).ok)
	assert_eq(_game_state.minesweeper_rounds_left, before.value.rounds_left)
	assert_eq(_game_state.stats, {"pressure": 3})


func test_retired_candidate_refuses_before_any_board_owner_mutation() -> void:
	_game_state.stats = {"pressure": 3}
	for stat_id: String in ["motivation", "health"]:
		var before: Dictionary = _port.capture()
		var selected: String = _game_state.minesweeper_selected_difficulty
		var candidate := {"selected_difficulty": "expert", "rounds_left": 0, "starts_today": {}}
		candidate[stat_id] = 1
		var result: Dictionary = _port.commit(candidate)
		assert_false(result.ok)
		assert_eq(_game_state.minesweeper_selected_difficulty, selected)
		assert_eq(_port.capture(), before)
		assert_false(_port.rollback(candidate).ok)
		assert_eq(_port.capture(), before)
		assert_eq(_game_state.stats, {"pressure": 3})


func test_retirement_keeps_desktop_capacity_fences() -> void:
	_game_state.stats = {"pressure": 3}
	_game_state.minesweeper_rounds_left = _game_state.minesweeper_round_floor
	var captured: Dictionary = _port.capture()
	assert_true(captured.ok)
	assert_false(captured.value.eligible)
	var root := _transaction_receipt(_root_store)
	var result: Dictionary = _port.prepare_first_reveal({}, str(root.token), root, "checkpoint-refused")
	assert_false(result.ok)
	assert_eq(result.code, &"insufficient_capacity")
	assert_eq(_port.capture(), captured)


func test_shop_owner_refuses_retired_items_before_detached_or_live_mutation() -> void:
	var shop_port: RefCounted = preload("res://scripts/application/shop/GameStateMinesweeperShopPort.gd").new()
	assert_true(shop_port.configure(_game_state, IDENTITY_CONTEXT).ok)
	_game_state.stats = {"pressure": 3}
	var original: Dictionary = _game_state.to_save_dict().duplicate(true)
	var contacts: Dictionary = _game_state.contacts.duplicate(true)
	for item_id: String in ["coffee", "pep_note", "bandage_pack", "healthy_meal", "protein_box"]:
		# A forged retained ordinary candidate cannot bypass the presentation/catalogue guard.
		var changed: Dictionary = original.duplicate(true)
		changed.money = -30
		var candidate := {"item_id": item_id, "ordinary_gameplay": changed,
			"ordinary_contacts": {}, "currency": "money", "price": 1}
		assert_eq(shop_port.commit(candidate).code, &"retired_shop_item")
		assert_eq(shop_port._prepare_ordinary({"item_id": item_id}, {}, "retired-transaction").code,
			&"retired_shop_item")
		assert_eq(_game_state.to_save_dict(), original)
		assert_eq(_game_state.contacts, contacts)
