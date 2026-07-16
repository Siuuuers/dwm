extends Node
# LocalizationManager (CONTRACTS §5): owns language lookup + locale switching.
# Supported locales: en, zh_CN, zh_HK. Current locale is stored ONLY in
# GameState.settings["language"]. Missing keys return "[missing:key]" and push_warning once.
# set_locale() delegates the write to GameState.set_language() and stores it nowhere else.

signal locale_changed(locale: String)

const _SUPPORTED := {
	"en": "English",
	"zh_CN": "简体中文",
	"zh_HK": "繁體中文",
}

const _DEFAULT_LOCALE := "en"

# Keys already warned-about, so we push_warning at most once per missing key.
var _warned_missing: Dictionary = {}

# locale -> { key -> string }. "en" is authoritative and holds every key.
# zh_CN / zh_HK hold translations where provided; anything absent falls back to en.
var _tables: Dictionary = {}


func _ready() -> void:
	_build_tables()


func _build_tables() -> void:
	var en := {
		# App labels (CONTENT §1)
		"app.minesweeper": "minesweeper",
		"app.contacts": "contacts",
		"app.shop": "shop",
		"app.schedule": "schedule",
		"app.settings": "settings",
		"app.logout": "logout",
		"app.backup": "backup",
		# Minesweeper HUD (CONTENT §2)
		"hud.minesweeper_rounds": "Minesweeper: {remaining}/{max}",
		# Generic buttons
		"button.close": "Close",
		"button.go": "Go",
		"button.yes": "Yes",
		"button.buy": "Buy",
		# Shop quantity / sold-out
		"shop.quantity": "Quantity",
		"shop.quantity.value": "Qty: {quantity}",
		"shop.quantity.minus": "Less",
		"shop.quantity.plus": "More",
		"shop.buy_quantity": "Buy x{quantity}",
		"shop.sold_out": "Sold out",
		"shop.cannot_afford_quantity": "Angela cannot afford that quantity.",
		"shop.secret_supportz.accessible_name": "Secret Supportz buy area",
		# Minesweeper new-message notification
		"desktop.notification.new_message_title": "New message",
		"desktop.notification.new_message_from_friend": "Angela received a new message from {friend_name}.",
		# Schedule warning alert
		"schedule.alert.minesweeper_needed.title": "Minesweeper unfinished",
		"schedule.alert.minesweeper_needed.body": "There is Minesweeper need to Finish.",
		"schedule.alert.minesweeper_needed.detail": "Angela still has Minesweeper rounds or an unfinished board. Go to Minesweeper? The current sequence bar will be cleared.",
		# Dating dialogue log
		"dating.dialogue_log.title": "Dialogue Log",
		# Audio settings
		"settings.sfx_volume": "SFX volume",
		"settings.ambience_volume": "Ambience volume",
		"settings.mute_audio_on_focus_loss": "Mute audio when window is inactive",
		# Audio track labels
		"audio.missing_track": "Missing audio: {track_id}",
		"audio.now_playing": "Now playing: {track}",
		# Gallery
		"gallery.title": "Gallery",
		# Logout confirmation
		"logout.confirm": "Are you sure you want to log out?",
		# Menu buttons
		"menu.new_account": "New Acc",
		"menu.login": "Log in",
		"menu.gallery": "Gallery",
		"menu.setting": "Setting",
		"menu.shutdown": "Shut down",
	}
	# Gallery ending titles (one per ending id).
	var ending_ids := [
		"alone", "priscilla_lavinia",
		"priscilla.sweet", "priscilla.dark", "priscilla.true",
		"lavinia.sweet", "lavinia.dark", "lavinia.true",
		"sylvia.sweet", "sylvia.dark", "sylvia.true", "sylvia.special",
	]
	for eid in ending_ids:
		en["gallery.ending.%s.title" % eid] = "Ending: %s" % eid.capitalize()

	var zh_cn := {
		"app.minesweeper": "扫雷", "app.contacts": "联系册", "app.shop": "商店",
		"app.schedule": "日程", "app.settings": "设定", "app.logout": "登出", "app.backup": "备份",
		"hud.minesweeper_rounds": "扫雷：{remaining}/{max}",
		"button.close": "关闭", "button.go": "前往", "button.yes": "是", "button.buy": "购买",
		"shop.quantity": "数量", "shop.quantity.minus": "减少", "shop.quantity.plus": "增加",
		"shop.sold_out": "售罄",
		"shop.secret_supportz.accessible_name": "Supportz 隐藏购买区域",
		"desktop.notification.new_message_title": "新消息",
		"schedule.alert.minesweeper_needed.title": "扫雷还没有完成",
		"schedule.alert.minesweeper_needed.body": "还有扫雷需要完成。",
		"dating.dialogue_log.title": "对话记录",
		"settings.sfx_volume": "音效音量", "settings.ambience_volume": "环境音量",
		"settings.mute_audio_on_focus_loss": "窗口未激活时静音",
		"gallery.title": "画廊",
	}
	var zh_hk := {
		"app.minesweeper": "掃雷", "app.contacts": "聯絡簿", "app.shop": "店鋪",
		"app.schedule": "日程", "app.settings": "設定", "app.logout": "登出", "app.backup": "備份",
		"hud.minesweeper_rounds": "掃雷：{remaining}/{max}",
		"button.close": "關閉", "button.go": "前往", "button.yes": "係", "button.buy": "購買",
		"shop.quantity": "數量", "shop.quantity.minus": "減少", "shop.quantity.plus": "增加",
		"shop.sold_out": "售罄",
		"shop.secret_supportz.accessible_name": "Supportz 隱藏購買區域",
		"desktop.notification.new_message_title": "新訊息",
		"schedule.alert.minesweeper_needed.title": "掃雷仲未完成",
		"schedule.alert.minesweeper_needed.body": "仲有掃雷要完成。",
		"dating.dialogue_log.title": "對話記錄",
		"settings.sfx_volume": "音效音量", "settings.ambience_volume": "環境音量",
		"settings.mute_audio_on_focus_loss": "視窗未啟用時靜音",
		"gallery.title": "圖鑑",
	}
	_tables = {"en": en, "zh_CN": zh_cn, "zh_HK": zh_hk}


func get_supported_locales() -> Dictionary:
	return _SUPPORTED.duplicate()


func get_locale() -> String:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.settings is Dictionary and gs.settings.has("language"):
		var loc: String = str(gs.settings["language"])
		if _SUPPORTED.has(loc):
			return loc
	return _DEFAULT_LOCALE


func set_locale(locale: String) -> bool:
	if not _SUPPORTED.has(locale):
		push_warning("LocalizationManager: unsupported locale '%s' rejected." % locale)
		return false
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("set_language"):
		gs.set_language(locale)
	emit_signal("locale_changed", locale)
	return true


func has_key(key: String) -> bool:
	var loc := get_locale()
	if _tables.has(loc) and (_tables[loc] as Dictionary).has(key):
		return true
	return (_tables["en"] as Dictionary).has(key)


func t(key: String, params: Dictionary = {}) -> String:
	var text: Variant = _lookup(key)
	if text == null:
		if not _warned_missing.has(key):
			_warned_missing[key] = true
			push_warning("LocalizationManager: missing key '%s'." % key)
		return "[missing:%s]" % key
	return _substitute(str(text), params)


func _lookup(key: String) -> Variant:
	var loc := get_locale()
	if _tables.has(loc) and (_tables[loc] as Dictionary).has(key):
		return (_tables[loc] as Dictionary)[key]
	var en: Dictionary = _tables["en"]
	if en.has(key):
		return en[key]
	return null


func _substitute(text: String, params: Dictionary) -> String:
	var out := text
	for k in params.keys():
		out = out.replace("{%s}" % str(k), str(params[k]))
	return out


func refresh_tree(root: Node) -> void:
	# Refresh any LocalizedText helper nodes; safe no-op for plain trees.
	if root == null:
		return
	if root.has_method("refresh_localized_text"):
		root.call("refresh_localized_text")
	for child in root.get_children():
		if child is Node:
			refresh_tree(child)
