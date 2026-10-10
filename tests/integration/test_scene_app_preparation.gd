extends GutTest
## Presentation-only proof over explicitly injected application ports, not gameplay/Save acceptance.
const F := preload("res://tests/support/SceneAppPreparationFixture.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
var viewport: SubViewport
var locale: RefCounted
var profile: RefCounted
var _orphan_baseline: Array[int] = []

func before_each() -> void:
	_orphan_baseline = Node.get_orphan_node_ids()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	# This fixture owns viewport teardown; do not also register it with GUT.
	add_child(viewport)
	locale = F.MINES.LocaleFixture.new()
	profile = F.MINES.ProfileFixture.new()
	profile.values = {"preferences.accessibility.text_size": 100, "preferences.accessibility.large_targets": false}

# Inspect identities, not count deltas: freeing an older orphan cannot hide a new one.
# Never free enumerated orphans here. Only the fixture viewport is ours to release.
func _new_orphan_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for node_id: int in Node.get_orphan_node_ids():
		if node_id in _orphan_baseline: continue
		var orphan := instance_from_id(node_id) as Node
		if not is_instance_valid(orphan): continue
		var cursor: Node = orphan
		var queued_ancestor := 0
		while cursor != null:
			if cursor.is_queued_for_deletion():
				queued_ancestor = cursor.get_instance_id()
				break
			cursor = cursor.get_parent()
		snapshot[node_id] = {"name": str(orphan.name), "class": orphan.get_class(),
			"queued_ancestor": queued_ancestor}
	return snapshot

func _settle_ui_deletions() -> void:
	# Two frame boundaries allow the deletion queue and exit-tree deferred work.
	# This is a bounded UI-node check, not arbitrary timer or RefCounted leak proof.
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	var before_release := _new_orphan_snapshot()
	if is_instance_valid(viewport): viewport.queue_free()
	await _settle_ui_deletions()
	var after_settle := _new_orphan_snapshot()
	print("SCENE_APP_TEARDOWN " + JSON.stringify({"before_root_release": before_release,
		"after_two_frames": after_settle}))
	assert_false(is_instance_valid(viewport), "The fixture viewport must be released")
	assert_true(after_settle.is_empty(), "New orphan nodes survive UI teardown: " + str(after_settle))

func test_teardown_probe_distinguishes_queued_children_from_unqueued_survivor() -> void:
	# Deliberate negative control: the observer must report, not clean, this node.
	var survivor := Node.new()
	survivor.name = "DeliberatelyUnqueuedProbe"
	var survivor_id := survivor.get_instance_id()
	var queued_root := Node.new()
	queued_root.name = "QueuedProbeRoot"
	var queued_child := Node.new()
	queued_root.add_child(queued_child)
	var root_id := queued_root.get_instance_id()
	var child_id := queued_child.get_instance_id()
	queued_root.queue_free()
	var before := _new_orphan_snapshot()
	assert_true(before.has(survivor_id), "The debug orphan API must observe the negative control")
	assert_eq(before.get(survivor_id, {}).get("queued_ancestor", -1), 0)
	assert_eq(before.get(root_id, {}).get("queued_ancestor", -1), root_id)
	assert_eq(before.get(child_id, {}).get("queued_ancestor", -1), root_id)
	await _settle_ui_deletions()
	var after := _new_orphan_snapshot()
	assert_true(is_instance_valid(survivor), "Waiting and observation must not destroy an unqueued node")
	assert_true(after.has(survivor_id), "A persistent orphan remains a failing condition")
	assert_false(is_instance_valid(queued_root))
	assert_false(is_instance_valid(queued_child))
	assert_false(after.has(root_id))
	assert_false(after.has(child_id))
	# Explicitly dispose only this test's sentinel, after proving detection.
	survivor.free()

func mount_app(path: String, spy: Script = null) -> Control:
	var app: Control = load(path).instantiate()
	if spy != null: app.set_script(spy)
	app.hide()
	viewport.add_child(app)
	return app

func test_contacts_scene_refresh_reopen_and_preference_reflow() -> void:
	var app := mount_app("res://scenes/apps/ContactListApp.tscn", F.ContactSpy)
	var port := F.CONTACTS.FakePort.new()
	assert_true(app.configure_scene_presentation(port, locale, profile).ok)
	app.show_window()
	profile.change("preferences.accessibility.text_size", 150)
	profile.change("preferences.accessibility.high_contrast", true)
	locale.change("zh-HK")
	assert_true(app.refresh_view().ok)
	assert_null(app._day)
	assert_true(app.contacts_panel._scene_presentation)
	assert_eq(app.contacts_panel.font_size, 36)
	app.hide()
	app.show_window()
	assert_eq(app.calendar_calls, 0)
	var before: Theme = app.contacts_panel.theme
	assert_false(app.configure_scene_presentation(port, locale, profile, &"invalid").ok)
	assert_same(app.contacts_panel.theme, before)
	assert_false(app.configure_presentation(port, locale, profile).ok)
	assert_true(app._scene_presentation)
	assert_true(port.opens.is_empty())

func test_mines_scene_refresh_resize_information_and_reopen() -> void:
	var app := mount_app("res://scenes/apps/MinesweeperApp.tscn", F.MinesSpy)
	var port := F.board_port(app)
	assert_true(app.configure_scene_presentation(port, locale, profile).ok)
	assert_true(app.prepare_show_window().ok)
	app.show_window()
	profile.change("preferences.accessibility.font_style", "readable")
	locale.change("zh-HK")
	assert_true(app.refresh_view().ok)
	app.set_desktop_height(720)
	assert_true(app.panel._scene_presentation)
	assert_true(app.panel.worksheet._scene_presentation)
	assert_true(app.panel.worksheet.grid._scene_presentation)
	assert_null(app.panel._day)
	app.panel.worksheet.open_rules()
	assert_not_null(app.panel.worksheet.information_sheet)
	if app.panel.worksheet.information_sheet != null:
		assert_true(app.panel.worksheet.information_sheet._scene_presentation)
		locale.change("en")
		assert_true(app.panel.worksheet.information_sheet._scene_presentation)
	assert_true(app.prepare_return_home().ok)
	app.hide_window()
	assert_true(app.prepare_show_window().ok)
	app.show_window()
	assert_eq(app.calendar_calls, 0)
	var before: Theme = app.panel.register.theme
	assert_false(app.configure_scene_presentation(port, locale, profile, null, &"invalid").ok)
	assert_same(app.panel.register.theme, before)
	assert_false(app.configure_presentation(port, locale, profile).ok)
	assert_true(port.commands.is_empty())

func test_shop_scene_catalog_refresh_reflow_preserves_port_and_cards() -> void:
	var app := mount_app("res://scenes/apps/ShopApp.tscn", F.ShopSpy)
	var port := F.catalog_port()
	assert_true(app.configure_scene_catalog(port, locale, profile).ok)
	assert_true(app.prepare_show_window().ok)
	app.show_window()
	profile.change("preferences.accessibility.text_size", 125)
	profile.change("preferences.accessibility.high_contrast", true)
	locale.change("zh-HK")
	assert_true(app.refresh_view().ok)
	assert_null(app._day)
	assert_false(app.cards.is_empty())
	for card: Control in app.cards.values(): assert_true(card._scene_presentation)
	app.hide()
	assert_true(app.prepare_show_window().ok)
	app.show_window()
	assert_eq(app.calendar_calls, 0)
	var before: Theme = app.theme
	assert_false(app.configure_scene_catalog(port, locale, profile, &"invalid").ok)
	assert_same(app.theme, before)
	assert_false(app.configure_catalog(port, locale, profile).ok)
	assert_true(port.purchase_calls.is_empty())

func test_settings_scene_presentation_uses_real_content_and_preferences() -> void:
	var owner := PROFILE.new()
	add_child_autofree(owner)
	assert_true(owner.initialize(STORAGE.new("scene-app-profile", FILES.new())).ok)
	var localization := LOCALIZATION.new()
	add_child_autofree(localization)
	assert_true(localization.initialize(owner).ok)
	var app: Control = load("res://scenes/apps/SettingsApp.tscn").instantiate()
	app.get_node("SettingsContent").configure_services({"profile": owner, "localization": localization,
		"input": null, "audio": null, "volume": null, "tts": null,
		"profile_reset_admission": func() -> bool: return true})
	app.get_node("LocalePresentationRoot").set("_localization", localization)
	assert_true(app.configure_scene_run_presentation(&"after_hours").ok)
	app.hide()
	viewport.add_child(app)
	assert_true(app.get_desktop_ready_result().ok)
	app.show_window()
	app.settings_content.apply_text_size(150, true)
	assert_true(app.settings_content._scene_presentation)
	assert_null(app.settings_content._run_day)
	var before: Theme = app.settings_content.theme
	assert_false(app.configure_scene_run_presentation(&"invalid").ok)
	assert_same(app.settings_content.theme, before)
	assert_false(app.configure_run_presentation(&"after_hours", 1).ok)
	app.hide()
	app.show_window()
	assert_null(app.settings_content._presentation_day)

# Backup's real port requires A's accepted family projection on the composed source.
# Only the lower inspection/storage owner and host wiring are fixtures; views are real.
func backup_fixture(title: bool = false, before_mount: bool = false) -> Dictionary:
	var host := F.BackupHost.new()
	host.size = Vector2(1280, 720)
	viewport.add_child(host)
	var app: Control = load("res://scenes/apps/BackupApp.tscn").instantiate()
	app.set_script(F.BackupSpy)
	app.hide()
	if title: app.configure_title_login()
	var owner := F.backup_owner()
	var port := F.BackupPortProbe.new()
	assert_true(port.configure(owner, "title" if title else "in_run").ok)
	if before_mount: assert_true(app.configure_scene_backup(port, locale, profile).ok)
	host.add_child(app)
	app.set_confirmation_host(host)
	return {"app": app, "owner": owner, "port": port, "host": host}

func backup_snapshot(app: Control) -> Dictionary:
	return {"theme": app.theme, "port": app._port, "locale": app._localization,
		"profile": app._profile, "visible": app.visible, "records": app._records.duplicate(true),
		"info": app._info_text.text, "status": app.status_label.text, "mode": app.active_mode,
		"selected": app.selected_locator, "pending": app._pending_token,
		"confirmation": app.confirmation, "ready": app.get_desktop_ready_result(),
		"last_result": app.last_result.duplicate(true), "revision": app._measure_revision}

func assert_backup_unchanged(app: Control, prior: Dictionary) -> void:
	assert_same(app.theme, prior.theme)
	assert_eq(backup_snapshot(app), prior)

func test_backup_scene_records_keep_explicit_families_and_fallback_times() -> void:
	var f := backup_fixture()
	var app: Control = f.app
	assert_true(app.configure_scene_backup(f.port, locale, profile).ok)
	assert_eq(f.port.reads, 1, "Configuration adopts its single validated snapshot")
	assert_false(app.visible)
	assert_true(app.get_desktop_ready_result().ok)
	assert_null(app._day)
	assert_eq(app.drawer_buttons.autosave.state_label.text, "09:10")
	assert_eq(app.drawer_buttons.quick.state_label.text, "Day 2 · 11:05")
	assert_eq(app.drawer_buttons["slot:1"].state_label.text, "13:57")
	assert_eq(app.drawer_buttons["slot:5"].state_label.text, "12:34")
	assert_eq(app.drawer_buttons["slot:6"].state_label.text, "Empty")
	assert_eq(app._info_text.text, "Slot 1\n\n13:57\n\n" + app._t("fallback") + "\n\n--:--")
	app.show_window()
	app._set_mode("load")
	app._select_drawer("slot:2")
	assert_true(app._info_text.text.contains("Day 6 · 14:30"))
	assert_true(app._info_text.text.contains("Day 3 · --:--"))
	app._select_drawer("slot:3")
	assert_true(app._info_text.text.contains(app._t("load_unavailable")))
	assert_true(app.action_buttons.load.disabled)
	assert_false(app.action_buttons.delete.disabled)
	app._select_drawer("slot:4")
	assert_true(app._info_text.text.contains(app._t("unreadable")))
	app._select_drawer("slot:7")
	assert_true(app._info_text.text.contains(app._t("no_compatible")))
	assert_false(app._info_text.text.contains("Day"))
	app._set_mode("save")
	assert_false(app.action_buttons.save.disabled, "Only A's explicit permission enables replacement")
	assert_true(app._info_text.text.contains(app._t("replaceable")))
	assert_true(f.owner.prepared.is_empty())
	assert_true(f.owner.committed.is_empty())
	assert_eq(app.calendar_calls, 0)
	var legacy := backup_fixture()
	assert_true(legacy.app.configure_backup(legacy.port, locale, profile, &"after_hours", 2).ok)
	assert_eq(legacy.app.drawer_buttons.quick.state_label.text, "Day 2 · 11:05")
	assert_eq(legacy.app.drawer_buttons.autosave.state_label.text, "09:10")

func test_backup_scene_invalid_setup_is_nonmutating_and_valid_rebind_detaches_old_sources() -> void:
	var f := backup_fixture()
	var app: Control = f.app
	var initial := backup_snapshot(app)
	assert_eq(app.configure_scene_backup(null).code, &"invalid_backup_port")
	assert_backup_unchanged(app, initial)
	assert_true(app.configure_scene_backup(f.port, locale, profile).ok)
	var prior := backup_snapshot(app)
	assert_false(app.configure_scene_backup(f.port, locale, profile, &"invalid").ok)
	assert_backup_unchanged(app, prior)
	assert_false(app.configure_scene_backup(f.port, RefCounted.new(), profile).ok)
	assert_backup_unchanged(app, prior)
	assert_false(app.configure_scene_backup(f.port, locale, RefCounted.new()).ok)
	assert_backup_unchanged(app, prior)
	var valid: Dictionary = f.port.get_projection()
	var missing := valid.duplicate(true)
	missing.value.records[2].erase("family")
	var wrong_count := valid.duplicate(true)
	wrong_count.value.records.pop_back()
	var wrong_locator := valid.duplicate(true)
	wrong_locator.value.records[2].locator = "quick"
	var wrong_family := valid.duplicate(true)
	wrong_family.value.records[2].family = "guessed"
	var false_day := valid.duplicate(true)
	false_day.value.records[2].day = 1
	var false_time := valid.duplicate(true)
	false_time.value.records[2].load_saved_time = "13:57"
	var wrong_permission := valid.duplicate(true)
	wrong_permission.value.records[2].actions.load = 1
	var private_field := valid.duplicate(true)
	private_field.value.records[2].token = "must-not-enter-view"
	for invalid in [missing, wrong_count, wrong_locator, wrong_family, false_day, false_time,
			wrong_permission, private_field, {"ok": true, "value": []}, {"ok": false}]:
		f.port.projection_override = invalid
		assert_eq(app.configure_scene_backup(f.port, locale, profile).code, &"invalid_backup_projection")
		assert_backup_unchanged(app, prior)
	f.port.projection_override = {}
	var replacement := F.BackupPortProbe.new()
	var replacement_owner := F.backup_owner()
	var replacement_locale := F.MINES.LocaleFixture.new()
	assert_true(replacement.configure(replacement_owner).ok)
	assert_true(app.configure_scene_backup(replacement, replacement_locale, profile).ok)
	assert_eq(replacement.reads, 1)
	assert_false(f.port.is_connected("projection_changed", app.refresh_view))
	assert_false(locale.is_connected("locale_changed", app._on_locale_changed))
	f.port.projection_changed.emit()
	locale.change("zh-HK")
	assert_eq(replacement.reads, 1, "Detached sources cannot refresh the new owner")
	assert_eq(app._locale, "en")
	assert_false(app.visible)

func test_backup_scene_prepared_fallback_confirmation_preserves_pending_custody() -> void:
	var f := backup_fixture()
	var app: Control = f.app
	assert_true(app.configure_scene_backup(f.port, locale, profile).ok)
	app.show_window()
	app._set_mode("load")
	# Current record stays scene/13:57; only prepared selected-bundle fields change.
	for family in ["scene", "legacy_day", null]:
		f.port.prepared_patch = {"load_family": family, "load_day": 4 if family == "legacy_day" else null}
		app.action_buttons.load.pressed.emit()
		assert_not_null(app.confirmation)
		if app.confirmation == null: return
		var sheet: Control = app.confirmation
		var expected_time := "Day 4 · --:--" if family == "legacy_day" else "--:--"
		assert_eq(sheet.request.body, app._t("fallback") + "\n" + expected_time + "\n\n" + app._t("replace_progress"))
		assert_false(sheet.request.body.contains("13:57"))
		assert_eq(sheet.confirm_button.risk, "danger")
		assert_eq(app.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
		var token: String = app._pending_token
		var prior := backup_snapshot(app)
		var other := F.BackupPortProbe.new()
		assert_eq(app.configure_scene_backup(other, locale, profile).code, &"backup_busy")
		assert_backup_unchanged(app, prior)
		assert_eq(other.reads, 0)
		assert_true(f.owner.committed.is_empty())
		sheet.cancel_button.pressed.emit()
		await get_tree().process_frame
		assert_null(app._pending_token)
		assert_true(f.owner.pending.is_empty())
		assert_eq(f.owner.cancelled.back(), token)
		assert_eq(f.owner.cancelled.count(token), 1)
	assert_true(f.owner.committed.is_empty())
	# A nonfallback Load also describes the selected bundle, not the display row.
	f.port.prepared_patch = {"fallback": false, "load_family": "scene", "load_day": null, "load_saved_time": "08:42"}
	app.action_buttons.load.pressed.emit()
	assert_not_null(app.confirmation)
	if app.confirmation == null: return
	assert_true(app.confirmation.request.body.contains("08:42"))
	assert_false(app.confirmation.request.body.contains("13:57"))
	app.confirmation.cancel_button.pressed.emit()
	await get_tree().process_frame

func test_backup_scene_title_fallback_uses_real_neutral_confirmation() -> void:
	var f := backup_fixture(true, true)
	var app: Control = f.app
	app.show_window()
	app._select_drawer("slot:1")
	app.action_buttons.load.pressed.emit()
	assert_not_null(app.confirmation)
	if app.confirmation == null: return
	assert_eq(app._confirmation_kind, "fallback")
	assert_eq(app.confirmation.request.body, app._t("fallback") + "\n--:--")
	assert_eq(app.confirmation.confirm_button.risk, "neutral")
	app.confirmation.cancel_button.pressed.emit()
	await get_tree().process_frame
	assert_true(f.owner.committed.is_empty())
	assert_true(app.mode_buttons.is_empty())

func test_backup_scene_action_refusal_retry_and_malformed_preparation_never_bypass_port() -> void:
	var f := backup_fixture()
	var app: Control = f.app
	assert_true(app.configure_scene_backup(f.port, locale, profile).ok)
	app.show_window()
	f.owner.commit_result = {"ok": false, "code": &"fixture_write_refused"}
	app.action_buttons.save.pressed.emit()
	assert_not_null(app.confirmation)
	if app.confirmation == null: return
	assert_eq(app._confirmation_kind, "overwrite")
	assert_eq(app.confirmation.request.body, "13:57")
	var refused_token: String = app._pending_token
	app.confirmation.confirm_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(f.owner.committed, [refused_token])
	assert_true(app._recovering)
	assert_null(app._pending_token)
	assert_true(app.action_buttons.has("retry"))
	f.port.prepared_patch = {"family": "invalid"}
	app.action_buttons.retry.pressed.emit()
	assert_eq(app.last_result.code, &"invalid_backup_projection")
	assert_null(app.confirmation)
	assert_eq(f.owner.committed.size(), 1)
	assert_eq(f.owner.cancelled.back(), f.owner.prepared.back().token)
	assert_true(f.owner.pending.is_empty())
	f.port.prepared_patch = {}
	f.owner.save_enabled = false
	app.action_buttons.retry.pressed.emit()
	assert_eq(f.owner.committed.size(), 1)
	assert_false(app.action_buttons.has("retry"))
	app.action_buttons.cancel.pressed.emit()
	assert_true(app.action_buttons.save.disabled)
	f.owner.save_enabled = true
	f.owner.commit_result = {"ok": true}
	f.port.projection_changed.emit()
	app.action_buttons.save.pressed.emit()
	assert_not_null(app.confirmation)
	if app.confirmation == null: return
	var accepted_token: String = app._pending_token
	assert_ne(accepted_token, refused_token)
	app.confirmation.confirm_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(f.owner.committed, [refused_token, accepted_token])
	assert_false(app._recovering)
	assert_eq(app.status_label.text, "Saved")
	assert_false(f.port.commit_action(accepted_token).ok, "The real port does not accept a spent token")
	assert_eq(f.owner.committed.size(), 2)
	app._set_mode("load")
	app.action_buttons.delete.pressed.emit()
	assert_not_null(app.confirmation)
	if app.confirmation == null: return
	assert_eq(app.confirmation.request.body, "13:57\n\n" + app._t("delete_body"))
	assert_eq(app.confirmation.confirm_button.risk, "destructive")
	app.confirmation.cancel_button.pressed.emit()
	await get_tree().process_frame
	assert_true(f.owner.pending.is_empty())

func test_backup_scene_preferences_reopen_and_legacy_guards_keep_dayless_theme() -> void:
	var f := backup_fixture(false, true)
	var app: Control = f.app
	app.show_window()
	app._set_mode("load")
	app.action_buttons.load.pressed.emit()
	assert_not_null(app.confirmation)
	if app.confirmation == null: return
	var frozen: Theme = app.theme
	profile.change("preferences.accessibility.text_size", 150)
	profile.change("preferences.accessibility.high_contrast", true)
	profile.change("preferences.accessibility.font_style", "readable")
	locale.change("zh-HK")
	assert_same(app.theme, frozen, "Pending consent keeps its current presentation")
	assert_true(app._pending_presentation)
	app.confirmation.cancel_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(app._locale, "zh-HK")
	assert_eq(app._percent, 150)
	assert_eq(app._font_style, "readable")
	var expected: Theme = F.BACKUP_THEME.build_scene("zh-HK", 150, &"after_hours", true, "standard", "readable")
	for role in ["habitat", "paper", "paper_ink"]:
		assert_eq(app.theme.get_color(role, "Backup"), expected.get_color(role, "Backup"))
	app.hide_window()
	app.show_window()
	assert_true(app.refresh_view().ok)
	assert_true(app._scene_presentation)
	assert_null(app._day)
	assert_eq(app.active_mode, "load")
	assert_eq(app.selected_locator, "slot:1")
	assert_eq(app.calendar_calls, 0)
	var prior := backup_snapshot(app)
	assert_false(app.configure_backup(f.port, locale, profile).ok)
	assert_backup_unchanged(app, prior)
	assert_false(app.configure_run_presentation(&"after_hours", 1).ok)
	assert_backup_unchanged(app, prior)
