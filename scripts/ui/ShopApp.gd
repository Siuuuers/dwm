extends AppWindowBase
class_name ShopApp

## Shop app window: currency status, item grid, paging (FLOWS.md §9, PHASES.md 3B3).

@onready var currency_status_row: HBoxContainer = %CurrencyStatusRow
@onready var item_grid: GridContainer = %ItemGrid
@onready var page_row: HBoxContainer = %PageRow
@onready var status_label: Label = %StatusLabel
