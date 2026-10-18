extends "res://addons/gut/test.gd"

class RevisionPort extends FakePort:
	signal projection_changed()
	var revision := 0
	var queued := false
	var invalidate_on_read := false
	var fail_read := false
	func get_projection_change_revision() -> int:
		return revision
	func invalidate() -> void:
		revision += 1
		if not queued:
			queued = true
			call_deferred("_publish")
	func _publish() -> void:
		queued = false
		projection_changed.emit()
	func get_projection() -> Dictionary:
		var result := super.get_projection()
		if invalidate_on_read:
			invalidate_on_read = false
			invalidate()
		return {"ok": false, "code": &"unavailable"} if fail_read else result
	func commit_action(value: String) -> Dictionary:
		var result := super.commit_action(value)
		if result.get("ok", false):
			invalidate()
		return result

class UnversionedPort extends FakePort:
	signal projection_changed()

func test_save_refresh_consumes_only_its_views_queued_notification() -> void:
	var port := RevisionPort.new()
	var app: BackupApp = load("res://scenes/apps/BackupApp.tscn").instantiate()
	var other: BackupApp = load("res://scenes/apps/BackupApp.tscn").instantiate()
	add_child_autofree(app)
	add_child_autofree(other)
	assert_true(app.configure_backup(port).ok)
	assert_true(other.configure_backup(port).ok)
	var publications := [0]
	port.projection_changed.connect(func(): publications[0] += 1)
	var before := port.projections
	port.token = "save"
	app._pending_token = "save"
	app._source_action = "save"
	await app._commit_pending()
	assert_eq(port.commits, 1)
	assert_eq(port.projections, before + 1, "successful Save reads immediately")
	assert_eq(app.status_label.text, "Saved")
	await get_tree().process_frame
	assert_eq(publications[0], 1, "other subscribers still receive the notification")
	assert_eq(port.projections, before + 2, "only the stale second view reads")
	assert_eq(app.status_label.text, "Saved")
	assert_true(app.refresh_view().ok)
	assert_eq(port.projections, before + 3, "explicit refresh always inspects")

func test_projection_changes_during_and_after_read_are_not_acknowledged_early() -> void:
	var port := RevisionPort.new()
	var app: BackupApp = load("res://scenes/apps/BackupApp.tscn").instantiate()
	add_child_autofree(app)
	assert_true(app.configure_backup(port).ok)
	port.invalidate()
	port.invalidate_on_read = true
	var before := port.projections
	assert_true(app.refresh_view().ok)
	await get_tree().process_frame
	assert_eq(port.projections, before + 2, "invalidation during read needs another projection")
	before = port.projections
	assert_true(app.refresh_view().ok)
	port.invalidate()
	await get_tree().process_frame
	assert_eq(port.projections, before + 2, "post-read invalidation must reach the view")

func test_failed_projection_and_equal_revision_replacement_do_not_skip_refresh() -> void:
	var port := RevisionPort.new()
	var app: BackupApp = load("res://scenes/apps/BackupApp.tscn").instantiate()
	add_child_autofree(app)
	assert_true(app.configure_backup(port).ok)
	port.invalidate()
	assert_true(app.refresh_view().ok)
	port.fail_read = true
	assert_false(app.refresh_view().ok)
	var before := port.projections
	port.fail_read = false
	await get_tree().process_frame
	assert_eq(port.projections, before + 1, "invalid view retries despite equal revision")
	var replacement := RevisionPort.new()
	replacement.revision = port.revision
	assert_true(app.configure_backup(replacement).ok)
	assert_eq(replacement.projections, 1, "new port is adopted even at equal revision")

func test_getterless_port_keeps_signal_refresh() -> void:
	var port := UnversionedPort.new()
	var app: BackupApp = load("res://scenes/apps/BackupApp.tscn").instantiate()
	add_child_autofree(app)
	assert_true(app.configure_backup(port).ok)
	var before := port.projections
	port.projection_changed.emit()
	assert_eq(port.projections, before + 1)

func test_real_port_counts_each_invalidation_while_publication_is_queued() -> void:
	var port := BackupPresentationPort.new()
	var publications := [0]
	port.projection_changed.connect(func(): publications[0] += 1)
	var before := port.get_projection_change_revision()
	port._queue_projection_changed()
	port._queue_projection_changed()
	assert_eq(port.get_projection_change_revision(), before + 2)
	assert_eq(publications[0], 0)
	await get_tree().process_frame
	assert_eq(publications[0], 1)


const BACKUP_THEME := preload("res://scripts/ui/backup/BackupTheme.gd")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const LOCATORS := ["autosave", "quick", "slot:1", "slot:2", "slot:3", "slot:4", "slot:5", "slot:6", "slot:7"]

class FakeProfile extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	var preferences := {
		"preferences.accessibility.text_size": 100,
		"preferences.accessibility.high_contrast": false,
		"preferences.accessibility.colour_differentiation": "standard",
	}
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return preferences.get(String(path), fallback)
	func change(path: StringName, value: Variant) -> void:
		preferences[String(path)] = value
		preference_changed.emit(path, value)

class FakePort extends RefCounted:
	var projections := 0
	var preparations := 0
	var commits := 0
	var cancellations := 0
	var token := ""
	var quick_record: Dictionary = {}
	func get_projection() -> Dictionary:
		projections += 1
		var records := []
		for locator: String in LOCATORS:
			records.append({"locator": locator, "state": "occupied", "day": 1,
				"saved_time": "09:00", "actions": {"save": true, "load": true, "delete": true}})
		records[1].merge(quick_record,true)
		return {"ok": true, "value": {"records": records}}
	func prepare_action(_action: String, _locator: String) -> Dictionary:
		preparations += 1
		token = "prepared-%d" % preparations
		return {"ok": true, "value": {"token": token, "confirmation_required": true,
			"confirmation_kind": "overwrite", "record": {"state": "occupied", "day": 1, "saved_time": "09:00"}}}
	func commit_action(value: String) -> Dictionary:
		if value != token:
			return {"ok": false, "code": &"stale"}
		commits += 1
		token = ""
		return {"ok": true}
	func cancel_action(_value: String) -> void:
		cancellations += 1
		token = ""

class FakeConfirmation extends Control:
	var accepted: Callable
	var cancelled: Callable
	func _finish(confirm: bool) -> void:
		if confirm:
			accepted.call()
		else:
			cancelled.call()
		queue_free()

class FakeConfirmationHost extends Control:
	func present_confirmation(_request: Dictionary, accepted: Callable, cancelled: Callable) -> Dictionary:
		var sheet := FakeConfirmation.new()
		sheet.accepted = accepted
		sheet.cancelled = cancelled
		add_child(sheet)
		return {"ok": true, "value": {"confirmation": sheet}}

func test_unavailable_inspector_never_offers_a_nonexistent_compatible_fallback() -> void:
	var app: BackupApp = load("res://scenes/apps/BackupApp.tscn").instantiate()
	add_child_autofree(app)
	var port := FakePort.new()
	assert_true(app.configure_backup(port).get("ok", false))
	app._set_mode("load")
	app._select_drawer("quick")
	for locale: String in ["en", "zh-CN", "zh-HK", "ja", "ko"]:
		app._locale = locale
		for reason: String in ["no_compatible_checkpoint", "restore_unavailable"]:
			port.quick_record = {"state": "unavailable", "reason": reason, "fallback": false,
				"actions": {"save": true, "load": false, "delete": true}}
			assert_true(app.refresh_view().get("ok", false))
			var copy_key := "no_compatible" if reason == "no_compatible_checkpoint" else "load_unavailable"
			assert_true(app._info_text.text.contains(BackupApp.COPY[locale][copy_key]))
			assert_false(app._info_text.text.contains(BackupApp.COPY[locale]["fallback"]))
			assert_false(app._info_text.text.contains(BackupApp.COPY[locale]["unreadable"]), "readable metadata with failed restore is not unreadable bytes")
			assert_true(app.action_buttons["load"].disabled)
		port.quick_record = {"state": "occupied", "reason": "", "fallback": true,
			"load_day": 1, "load_saved_time": null,
			"actions": {"save": true, "load": true, "delete": true}}
		assert_true(app.refresh_view().get("ok", false))
		assert_true(app._info_text.text.contains(BackupApp.COPY[locale]["fallback"]))
		assert_false(app.action_buttons["load"].disabled)
	assert_eq(port.preparations,0,"inspection neither prepares consent nor mutates a save")
	assert_eq(port.commits,0)

func test_all_authored_tuples_and_days_keep_contrast_and_protected_roles() -> void:
	var roles := ["habitat", "face", "paper", "paper_ink", "ink", "structure",
		"filed", "focus", "paper_focus", "danger", "destructive"]
	var protected := ["paper_ink", "ink", "filed", "focus", "paper_focus", "danger", "destructive"]
	for palette: StringName in [&"after_hours", &"midnight"]:
		for high_contrast: bool in [false, true]:
			for preset: String in ["standard", "protan", "deutan", "tritan"]:
				var authored: Dictionary = PALETTES.resolve(palette, high_contrast, preset)
				for day: int in range(1, 8):
					var backup: Theme = BACKUP_THEME.build("en", 100, palette, day, high_contrast, preset)
					var desktop: Theme = DESKTOP_THEME.build("en", 100, palette,
						WEEK_TINT.tint_for_day(day), high_contrast, preset)
					assert_not_null(backup)
					assert_eq(backup.get_color_list("Backup").size(), 11)
					var expected: Dictionary = WEEK_TINT.apply(authored,
						WEEK_TINT.tint_for_day(day), high_contrast, preset)
					for role: String in roles:
						assert_eq(backup.get_color(role, "Backup"), expected[role],
							"%s/%s/%s/day%d/%s" % [palette, high_contrast, preset, day, role])
						if day == 1 or high_contrast or role in protected:
							assert_eq(backup.get_color(role, "Backup"), authored[role])
					for role: String in ["habitat", "face", "ink", "structure", "focus"]:
						assert_eq(backup.get_color(role, "Backup"), desktop.get_color(role, "Desktop"))
					assert_gt(_contrast(backup.get_color("paper_ink", "Backup"), backup.get_color("paper", "Backup")), 4.5)
					assert_gt(_contrast(backup.get_color("ink", "Backup"), backup.get_color("face", "Backup")), 4.5)
	assert_null(BACKUP_THEME.build("en", 100, &"unknown"))
	assert_null(BACKUP_THEME.build("en", 100, &"after_hours", 0))
	assert_null(BACKUP_THEME.build("en", 100, &"after_hours", 8))
	assert_null(BACKUP_THEME.build("en", 100, &"after_hours", 1, false, "unknown"))

func test_live_preferences_and_day_change_keep_prepared_confirmation() -> void:
	var app: BackupApp = load("res://scenes/apps/BackupApp.tscn").instantiate()
	add_child_autofree(app)
	var port := FakePort.new()
	var profile := FakeProfile.new()
	var host := FakeConfirmationHost.new()
	add_child_autofree(host)
	app.set_confirmation_host(host)
	var default_theme: Theme = app.theme
	assert_false(app.configure_backup(port, null, profile, &"unknown", 1).get("ok", false))
	assert_false(app.configure_backup(port, null, profile, &"after_hours", 8).get("ok", false))
	assert_eq(app.theme, default_theme, "invalid initial context does not replace the visible theme")
	assert_eq(port.projections, 0, "invalid initial context never binds the owner")
	assert_true(app.configure_backup(port, null, profile).get("ok", false))
	app._select_drawer("slot:2")
	app._status_key = "saved"
	app._refresh_presentation()
	var initial_projections := port.projections
	var initial_focus: Button = app.drawer_buttons["slot:2"]
	initial_focus.grab_focus()
	profile.change(&"preferences.accessibility.high_contrast", true)
	profile.change(&"preferences.accessibility.colour_differentiation", "protan")
	profile.change(&"preferences.accessibility.text_size", 125)
	assert_eq(port.projections, initial_projections, "appearance changes do not query the owner")
	assert_eq(port.preparations, 0)
	assert_eq(port.commits, 0)
	assert_eq(port.cancellations, 0)
	assert_eq(app.active_mode, "save")
	assert_eq(app.selected_locator, "slot:2")
	assert_eq(app.status_label.text, "Saved")
	assert_true(initial_focus.has_focus())
	assert_eq(app.theme.get_color("paper", "Backup"),
		PALETTES.resolve(&"after_hours", true, "protan")["paper"])
	assert_eq(app.drawer_buttons["slot:2"].identity_label.get_theme_font_size("font_size"), 30)
	app.action_buttons["save"].grab_focus()
	profile.change(&"preferences.accessibility.colour_differentiation", "deutan")
	profile.change(&"preferences.accessibility.colour_differentiation", "protan")
	assert_true(app.action_buttons["save"].has_focus(), "rapid appearance changes retain the semantic action focus")
	var stable_theme: Theme = app.theme
	assert_true(app.configure_run_presentation(&"after_hours", 1).get("ok", false))
	assert_eq(app.theme, stable_theme, "unchanged run context does not reflow the app")
	assert_eq(port.projections, initial_projections)
	app.action_buttons["save"].pressed.emit()
	assert_eq(port.preparations, 1)
	assert_true(is_instance_valid(app.confirmation))
	var modal_theme: Theme = app.theme
	var modal_token := port.token
	profile.change(&"preferences.accessibility.colour_differentiation", "deutan")
	assert_true(app.configure_run_presentation(&"midnight", 7).get("ok", false))
	assert_true(app.configure_run_presentation(&"midnight", 7).get("ok", false))
	assert_eq(app.theme, modal_theme, "modal presentation waits for consent boundary")
	assert_eq(port.projections, initial_projections)
	assert_eq(port.token, modal_token)
	assert_eq(port.cancellations, 0)
	assert_false(app.configure_run_presentation(&"unknown", 4).get("ok", false))
	assert_false(app.configure_run_presentation(&"after_hours", 8).get("ok", false))
	assert_eq(app._run_palette, &"midnight", "invalid context leaves accepted context intact")
	app.confirmation._finish(true)
	await get_tree().process_frame
	assert_eq(port.commits, 1, "prepared token still commits after deferred appearance")
	assert_eq(port.cancellations, 0)
	assert_eq(app.theme.get_color("paper", "Backup"),
		PALETTES.resolve(&"midnight", true, "deutan")["paper"])
	assert_eq(app.theme.get_color("face", "Backup"),
		PALETTES.resolve(&"midnight", true, "deutan")["face"])
	assert_eq(app.selected_locator, "slot:2")
	assert_eq(app.status_label.text, "Saved")
	var after_commit_projections := port.projections
	app.action_buttons["save"].pressed.emit()
	assert_eq(port.preparations, 2)
	var before_cancel: Theme = app.theme
	assert_true(app.configure_run_presentation(&"after_hours", 3).get("ok", false))
	profile.change(&"preferences.accessibility.high_contrast", false)
	assert_eq(app.theme, before_cancel)
	app.confirmation._finish(false)
	assert_eq(port.cancellations, 1, "cancel releases only the second prepared token")
	assert_eq(port.commits, 1)
	assert_eq(port.projections, after_commit_projections,
		"deferred appearance at cancel boundary does not query records")
	assert_eq(app.theme.get_color("face", "Backup"),
		WEEK_TINT.apply(PALETTES.resolve(&"after_hours", false, "deutan"),
			WEEK_TINT.tint_for_day(3), false, "deutan")["face"])
	assert_eq(app.selected_locator, "slot:2")
	assert_eq(app.status_label.text, "Saved")

func _contrast(a: Color, b: Color) -> float:
	var light := maxf(a.srgb_to_linear().get_luminance(), b.srgb_to_linear().get_luminance())
	var dark := minf(a.srgb_to_linear().get_luminance(), b.srgb_to_linear().get_luminance())
	return (light + 0.05) / (dark + 0.05)

func test_font_style_change_keeps_backup_selection_and_owner_idle() -> void:
	var app: BackupApp = load("res://scenes/apps/BackupApp.tscn").instantiate()
	add_child_autofree(app)
	var port := FakePort.new()
	var profile := FakeProfile.new()
	assert_true(app.configure_backup(port,null,profile).ok)
	app._select_drawer("slot:2")
	app.drawer_buttons["slot:2"].grab_focus()
	var projections := port.projections
	var typography := preload("res://scripts/ui/UiTypography.gd")
	for style: String in ["readable","pixel"]:
		profile.change(&"preferences.accessibility.font_style",style)
		assert_same(app.theme.default_font,typography.font("en",100,style))
		assert_eq(app.selected_locator,"slot:2")
		assert_true(app.drawer_buttons["slot:2"].has_focus())
		assert_eq(port.projections,projections)
		assert_eq(port.preparations,0)
		assert_eq(port.commits,0)
		await get_tree().process_frame

class TransitionPort extends FakePort:
	var app: BackupApp
	var detach_on_commit := true
	var result := {"ok": false, "code": &"scene_activation_pending", "recovery_required": true}
	func prepare_action(action: String, locator: String) -> Dictionary:
		var prepared := super.prepare_action(action, locator)
		prepared.value.confirmation_required = false
		prepared.value.confirmation_kind = "none"
		return prepared
	func commit_action(value: String) -> Dictionary:
		if value != token:
			return {"ok": false, "code": &"stale"}
		commits += 1
		token = ""
		if detach_on_commit:
			app.get_parent().remove_child(app)
		return result.duplicate(true)


func test_pending_load_does_not_rebuild_or_focus_detached_backup_actions() -> void:
	var app: BackupApp = load("res://scenes/apps/BackupApp.tscn").instantiate()
	add_child_autofree(app)
	var port := TransitionPort.new()
	port.app = app
	assert_true(app.configure_backup(port).ok)
	app._set_mode("load")
	await get_tree().process_frame
	var action: Button = app.action_buttons.load
	var projections := port.projections
	action.pressed.emit()
	assert_false(app.is_inside_tree(), "activation detached the outgoing view")
	assert_eq(port.preparations, 1)
	assert_eq(port.commits, 1)
	assert_eq(port.cancellations, 0, "consumed token is not cancelled during tree exit")
	assert_eq(app.last_result, port.result, "pending activation remains pending")
	assert_false(app._in_operation)
	assert_false(app._recovering, "detached view cannot offer a retry")
	assert_eq(port.projections, projections, "outgoing view cannot query a replacement projection")
	assert_same(app.action_buttons.load, action)
	assert_false(action.is_queued_for_deletion(), "pressed control is not rebuilt by the failure path")
	assert_false(app.action_buttons.has("cancel"))
	assert_false(app.action_buttons.has("retry"))


func test_attached_load_refusal_still_presents_recovery_actions() -> void:
	var app: BackupApp = load("res://scenes/apps/BackupApp.tscn").instantiate()
	add_child_autofree(app)
	var port := TransitionPort.new()
	port.app = app
	port.detach_on_commit = false
	port.result = {"ok": false, "code": &"write_refused"}
	assert_true(app.configure_backup(port).ok)
	app._set_mode("load")
	await get_tree().process_frame
	app.action_buttons.load.pressed.emit()
	assert_true(app.is_inside_tree())
	assert_eq(port.commits, 1)
	assert_eq(app.last_result, port.result)
	assert_true(app._recovering)
	assert_true(app.action_buttons.has("cancel"))
	assert_true(app.action_buttons.has("retry"))
	assert_false(app.action_buttons.retry.disabled)
	assert_true(app.action_buttons.cancel.has_focus())
