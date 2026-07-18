class_name ShopItemData
extends Resource
# Stub skeleton. See prompt_docs/INDEX.md.
@export var id: String = ""
@export var display_name: String = ""
@export var localization_key: String = ""
@export var description: String = ""
@export var description_key: String = ""
@export var price: int = 0
@export var currency: String = "money"
@export var effect_ids: Array[String] = []
@export var max_purchases: int = 0
@export var icon_text: String = ""
@export var image_path: String = ""
@export var is_gift: bool = false
@export var is_special_gift: bool = false
@export var is_visible_in_shop: bool = true
@export var is_secret_buy_button: bool = false
@export var secret_accessibility_label_key: String = ""
