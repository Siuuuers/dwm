extends PanelContainer
class_name ShopItemBox

## Single purchasable item row/card (FLOWS.md §9, CONTENT.md §7).

@onready var item_image: TextureRect = %ItemImage
@onready var name_label: Label = %NameLabel
@onready var price_label: Label = %PriceLabel
@onready var effect_summary_label: Label = %EffectSummaryLabel
@onready var purchase_count_label: Label = %PurchaseCountLabel
@onready var quantity_row: HBoxContainer = %QuantityRow
@onready var quantity_minus_button: Button = %QuantityMinusButton
@onready var quantity_label: Label = %QuantityLabel
@onready var quantity_plus_button: Button = %QuantityPlusButton
@onready var buy_button: Button = %BuyButton
@onready var sold_out_label: Label = %SoldOutLabel
@onready var secret_buy_button: Button = %SecretBuyButton

var item_id: String = ""
var quantity: int = 1
