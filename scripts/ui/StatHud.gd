extends PanelContainer
class_name StatHud

## Left-panel stat display; updates on GameState signals (prompt_docs/requirements/runtime_ownership.md).

@onready var _day_label: Label = %DayLabel
@onready var _pressure_meter: BoxMeter = %PressureMeter
@onready var _health_meter: BoxMeter = %HealthMeter
@onready var _motivation_meter: BoxMeter = %MotivationMeter
@onready var _money_row: Label = %MoneyRow
@onready var _minesweeper_round_row: Label = %MinesweeperRoundRow
@onready var _coin_row: Label = %CoinRow
@onready var _condition_display: Label = %ConditionDisplay
@onready var _penalty_label: Label = %PenaltyLabel

func _ready() -> void:
	_connect_game_state()
	refresh_all()
	if has_node("/root/LocalizationManager"):
		var loc := get_node("/root/LocalizationManager")
		if not loc.locale_changed.is_connected(_on_locale_changed):
			loc.locale_changed.connect(_on_locale_changed)

func _on_locale_changed(_locale: String) -> void:
	_refresh_minesweeper_row()

func _connect_game_state() -> void:
	if not has_node("/root/GameState"):
		return
	var gs := get_node("/root/GameState")
	if not gs.stat_changed.is_connected(_on_stat_changed):
		gs.stat_changed.connect(_on_stat_changed)
	if not gs.money_changed.is_connected(_on_money_changed):
		gs.money_changed.connect(_on_money_changed)
	if not gs.coins_changed.is_connected(_on_coins_changed):
		gs.coins_changed.connect(_on_coins_changed)
	if not gs.day_changed.is_connected(_on_day_changed):
		gs.day_changed.connect(_on_day_changed)
	if not gs.minesweeper_rounds_changed.is_connected(_on_minesweeper_rounds_changed):
		gs.minesweeper_rounds_changed.connect(_on_minesweeper_rounds_changed)
	if not gs.condition_effect_resolved.is_connected(_on_condition_effect_resolved):
		gs.condition_effect_resolved.connect(_on_condition_effect_resolved)

func refresh_all() -> void:
	if not has_node("/root/GameState"):
		return
	var gs := get_node("/root/GameState")
	if is_instance_valid(_day_label):
		_day_label.text = str(gs.day)
	if is_instance_valid(_pressure_meter):
		_pressure_meter.set_meter(gs.get_stat_display_value(gs.STAT_PRESSURE), gs.get_stat_display_max(gs.STAT_PRESSURE))
	if is_instance_valid(_health_meter):
		_health_meter.set_meter(gs.get_stat_display_value(gs.STAT_HEALTH), gs.get_stat_display_max(gs.STAT_HEALTH))
	if is_instance_valid(_motivation_meter):
		_motivation_meter.set_meter(gs.get_stat_display_value(gs.STAT_MOTIVATION), gs.get_stat_display_max(gs.STAT_MOTIVATION))
	if is_instance_valid(_money_row):
		_money_row.text = str(gs.money)
	if is_instance_valid(_coin_row):
		_coin_row.text = str(gs.coins)
	_refresh_minesweeper_row()

func _refresh_minesweeper_row() -> void:
	if not is_instance_valid(_minesweeper_round_row) or not has_node("/root/GameState") or not has_node("/root/LocalizationManager"):
		return
	var gs := get_node("/root/GameState")
	var loc := get_node("/root/LocalizationManager")
	_minesweeper_round_row.text = loc.t("hud.minesweeper_rounds", {
		"remaining": gs.get_minesweeper_display_rounds_left(),
		"max": gs.get_minesweeper_display_rounds_max(),
	})
	var profile := get_node_or_null("/root/ProfileManager")
	var high_contrast := bool(profile.get_preference(&"preferences.accessibility.high_contrast", false)) if profile != null else false
	if gs.get_minesweeper_display_rounds_left() > 0 and not high_contrast:
		_minesweeper_round_row.add_theme_color_override("font_color", Color(0.85, 0.25, 0.25))
	else:
		_minesweeper_round_row.remove_theme_color_override("font_color")

func _on_stat_changed(_stat_id: String, _value: int, _min_value: int, _max_value: int) -> void:
	refresh_all()

func _on_money_changed(value: int) -> void:
	if is_instance_valid(_money_row):
		_money_row.text = str(value)

func _on_coins_changed(value: int) -> void:
	if is_instance_valid(_coin_row):
		_coin_row.text = str(value)

func _on_day_changed(day: int) -> void:
	if is_instance_valid(_day_label):
		_day_label.text = str(day)

func _on_minesweeper_rounds_changed(_rounds_left: int, _max_rounds: int) -> void:
	_refresh_minesweeper_row()

func _on_condition_effect_resolved(result: Dictionary) -> void:
	if is_instance_valid(_condition_display):
		_condition_display.text = String(result.get("condition", ""))
