extends AppWindowBase
class_name ShopApp

## Shop app window: currency status, item grid, paging (prompt_docs/INDEX.md).

@onready var currency_status_row: HBoxContainer = %CurrencyStatusRow
@onready var item_grid: GridContainer = %ItemGrid
@onready var page_row: HBoxContainer = %PageRow
@onready var status_label: Label = %StatusLabel

# --- Phase 3B3 signal spine ---
# ShopApp LISTENS to GameState broadcasts so the UI reflects state changes it did
# not itself cause (e.g. a purchase's effect_ids changing money, a daily reset).
# Buy/quantity/Supportz ACTIONS are a later 3B3 pass; this pass wires reactions only.
# House style (see AppWindowBase.gd): guard every connect with is_connected(),
# existence-check autoloads so missing systems never crash (Prompt.md stability rules).

func _ready() -> void:
	super()  # AppWindowBase wires hide button + locale refresh; must not be lost.
	if has_node("/root/GameState"):
		var gs := get_node("/root/GameState")
		if not gs.money_changed.is_connected(_on_currency_changed):
			gs.money_changed.connect(_on_currency_changed)
		if not gs.coins_changed.is_connected(_on_currency_changed):
			gs.coins_changed.connect(_on_currency_changed)
		if not gs.inventory_changed.is_connected(_on_inventory_changed):
			gs.inventory_changed.connect(_on_inventory_changed)
		if not gs.daily_state_reset.is_connected(_on_daily_state_reset):
			gs.daily_state_reset.connect(_on_daily_state_reset)
	_refresh_currency_status()

# money_changed(value:int) and coins_changed(value:int) share this handler; both
# only need to trigger a currency-row redraw. Param name kept generic on purpose.
func _on_currency_changed(_value: int) -> void:
	_refresh_currency_status()

func _on_inventory_changed() -> void:
	# Buying/using items changes affordability + sold-out state; item grid refresh
	# is implemented in the buy-flow pass. Spine: hook exists, no-op for now.
	pass

func _on_daily_state_reset() -> void:
	# New day: currency and item availability may change. Full rebuild lands with
	# the buy-flow pass; spine refreshes the currency row it already owns.
	_refresh_currency_status()

func _refresh_currency_status() -> void:
	# Placeholder redraw target for the currency row. The full money/coin display
	# (localized, high-contrast, icon+text per accessibility rules) is built in the
	# buy-flow pass; this spine confirms the signal path fires end-to-end.
	if not is_instance_valid(status_label):
		return
