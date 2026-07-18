extends Node
# LocalizationManager (CONTRACTS §5): owns language lookup + locale switching.
# Supported locales: en, zh_CN, zh_HK. ProfileManager owns the committed locale.
# Missing keys return "[missing:key]" and push_warning once.

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
var _profile: Node
var _mutation_gate: Object


func _ready() -> void:
	pass

func configure_mutation_gate(gate: Object) -> Dictionary:
	return _configure_gate(gate)

func initialize(profile: Node) -> Dictionary:
	if profile == null or not profile.has_method("get_preference") or not profile.has_method("prepare_locale_preference"):
		return {"ok": false, "code": &"invalid_profile_manager"}
	_profile = profile
	_build_tables()
	return {"ok": true}


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
	if _profile != null:
		var loc: String = str(_profile.get_preference(&"preferences.language", _DEFAULT_LOCALE))
		if _SUPPORTED.has(loc):
			return loc
	return _DEFAULT_LOCALE


func set_locale(locale: String) -> bool:
	if not _SUPPORTED.has(locale):
		push_warning("LocalizationManager: unsupported locale '%s' rejected." % locale)
		return false
	if _profile == null: return false
	var prepared: Dictionary = _profile.prepare_locale_preference(locale)
	if not prepared.get("ok", false): return false
	var committed: Dictionary = _profile.commit_prepared_profile(prepared["value"], true)
	if not committed.get("ok", false): return false
	var publication_id: String = committed["value"]["publication_id"]
	emit_signal("locale_changed", locale)
	return _profile.publish_deferred_profile_signals(publication_id).get("ok", false)


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

func _configure_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"): return {"ok": false, "code": &"invalid_mutation_gate", "details": {}, "receipt": {}}
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method): return {"ok": false, "code": &"invalid_mutation_gate", "details": {}, "receipt": {}}
	if _mutation_gate != null and _mutation_gate.get_instance_id() != gate.get_instance_id(): return {"ok": false, "code": &"mutation_gate_already_configured", "details": {}, "receipt": {}}
	var already := _mutation_gate != null
	_mutation_gate = gate
	return {"ok": true, "code": &"ok", "value": {"gate_instance_id": gate.get_instance_id(), "already_configured": already}, "receipt": {}}


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
