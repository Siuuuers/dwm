extends "res://addons/gut/test.gd"
# Localization unit tests (prompt_docs/requirements/localization.md).

func after_each() -> void:
	LocalizationManager.set_locale("en")


func test_default_locale_valid() -> void:
	var loc := LocalizationManager.get_locale()
	assert_true(loc in ["en", "zh_CN", "zh_HK"])


func test_set_supported_locales() -> void:
	assert_true(LocalizationManager.set_locale("en"))
	assert_eq(LocalizationManager.get_locale(), "en")
	assert_true(LocalizationManager.set_locale("zh_CN"))
	assert_eq(LocalizationManager.get_locale(), "zh_CN")
	assert_true(LocalizationManager.set_locale("zh_HK"))
	assert_eq(LocalizationManager.get_locale(), "zh_HK")


func test_unsupported_locale_rejected() -> void:
	assert_false(LocalizationManager.set_locale("fr"), "unsupported locale rejected")


func test_missing_key_returns_marker() -> void:
	assert_eq(LocalizationManager.t("this.key.does.not.exist"), "[missing:this.key.does.not.exist]")


func test_param_replacement() -> void:
	var s := LocalizationManager.t("hud.minesweeper_rounds", {"remaining": 1, "max": 2})
	assert_eq(s, "Minesweeper: 1/2")


func test_newer_keys_exist() -> void:
	var keys := [
		"hud.minesweeper_rounds",
		"desktop.notification.new_message_from_friend",
		"desktop.notification.new_message_title",
		"schedule.alert.minesweeper_needed.title",
		"schedule.alert.minesweeper_needed.body",
		"schedule.alert.minesweeper_needed.detail",
		"shop.buy_quantity",
		"shop.quantity.value",
		"shop.sold_out",
		"shop.secret_supportz.accessible_name",
	]
	for k in keys:
		assert_true(LocalizationManager.has_key(k), "key exists: %s" % k)
		assert_ne(LocalizationManager.t(k), "[missing:%s]" % k, "key resolves: %s" % k)


func test_notification_param() -> void:
	var s := LocalizationManager.t("desktop.notification.new_message_from_friend", {"friend_name": "Priscilla"})
	assert_true(s.find("Priscilla") >= 0, "friend name substituted")


func test_zh_translation_present() -> void:
	LocalizationManager.set_locale("zh_CN")
	assert_eq(LocalizationManager.t("app.minesweeper"), "扫雷")
