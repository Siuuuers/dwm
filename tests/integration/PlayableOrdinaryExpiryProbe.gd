extends RefCounted
## Full bootstrap + actual Contacts + Schedule + disk Autosave installation.
## No seeded Contacts state, reply receipt, clock jump or fake persistence owner.

const ORDINARY := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")


func run(tree: SceneTree, game: Node, desktop: Node) -> void:
	if not tree._check(game.day == 1, "expiry probe begins on actual Day 1"): return
	if not tree._check(desktop.open_app(&"contacts").get("ok", false), "open actual Contacts"): return
	await tree._frames()
	var app: Node = desktop.get("_cached_app_windows")[&"contacts"]
	app.contacts_panel.open_requested.emit("lavinia")
	await tree._frames()
	for choice_name: String in ["OrdinaryReplyA", "OrdinaryReplyB", "OrdinaryReplyC"]:
		var choice: Button = app.find_child(choice_name, true, false)
		if not tree._check(choice != null and choice.is_visible_in_tree() and not choice.disabled,
			"unanswered Day 1 choice visible: " + choice_name): return
	if not await tree._capture_screen("ordinary-expiry-day1-unanswered"): return
	# The ordinary is opened and seen, but no answer is selected or acknowledged.
	if not tree._check(game.contacts.messages.lavinia.is_empty() and game.get_pending_ordinary_echoes().is_empty(),
		"viewing an ordinary does not invent committed reply history or an echo"): return
	var contacts_before_expiry: Dictionary = game.contacts.duplicate(true)
	if not tree._check(desktop.return_home().get("ok", false), "Home with unanswered ordinary"): return
	if not await _save_slot1(tree, desktop): return
	if not tree._check(desktop.return_home().get("ok", false), "Home after pre-expiry Slot 1 Save"): return
	if not tree._check(desktop.open_app(&"schedule").get("ok", false), "open actual Schedule"): return
	await tree._frames()
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	for attempt: int in 5:
		var done: Dictionary = ports.commands.dispatch_done()
		if not tree._check(done.get("ok", false), "empty Done: " + JSON.stringify(done)): return
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: break
		var dismissed: Dictionary = ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss")
		if not tree._check(dismissed.get("ok", false), "dismiss optional-work warning"): return
	await tree._frames()
	if not tree._check(game.day == 2, "production Done crosses midnight"): return
	if not _check_expired(tree, game, contacts_before_expiry): return
	var contacts_before: Dictionary = game.contacts.duplicate(true)
	var expiry_receipt: Dictionary = _expiry_receipts(contacts_before)[0].duplicate(true)
	var session_before: Dictionary = game.capture_live_session().value.duplicate(true)
	var loaded: Dictionary = await _load_backup_record(tree, game, desktop, "autosave", session_before)
	if not loaded.get("ok", false): return
	desktop = loaded.desktop
	if not tree._check(game.contacts == contacts_before, "Load preserves exact saved Contacts facts"): return
	var restored_expiries: Array[Dictionary] = _expiry_receipts(game.contacts)
	if not tree._check(restored_expiries.size() == 1,
		"full Autosave Load retains exactly one expiry-bearing receipt"): return
	if not tree._check(restored_expiries[0] == expiry_receipt,
		"full Autosave Load preserves the exact immutable expiry-bearing day-end receipt"): return
	if not _check_expired(tree, game, contacts_before_expiry): return
	if not tree._check(desktop != null and desktop.open_app(&"contacts").get("ok", false), "restored Contacts opens"): return
	await tree._frames()
	app = desktop.get("_cached_app_windows")[&"contacts"]
	app.contacts_panel.open_requested.emit("lavinia")
	await tree._frames()
	if not tree._check(app.last_result.get("ok", false), "old ordinary's thread opens after Load"): return
	for choice_name: String in ["OrdinaryReplyA", "OrdinaryReplyB", "OrdinaryReplyC"]:
		var choice: Button = app.find_child(choice_name, true, false)
		if not tree._check(choice == null or not choice.is_visible_in_tree(), "expired ordinary has no visible choice after Load"): return
	if not await tree._capture_screen("ordinary-expiry-day2-restored"): return
	if not tree._check(desktop.return_home().get("ok", false), "Home before loading pre-expiry Slot 1"): return
	var day2_session: Dictionary = game.capture_live_session().value.duplicate(true)
	loaded = await _load_backup_record(tree, game, desktop, "slot:1", day2_session)
	if not loaded.get("ok", false): return
	desktop = loaded.desktop
	if not tree._check(game.day == 1 and game.contacts == contacts_before_expiry,
		"older Slot 1 restores the exact pre-expiry Day 1 Contacts state"): return
	if not tree._check(_expiry_receipts(game.contacts).is_empty(),
		"older Slot 1 has no future expiry overlay"): return
	var restored: Dictionary = ORDINARY.available(game.contacts, game.day, "lavinia")
	if not tree._check(restored.get("ok", false) and restored.value.get("choices", []).size() == 3,
		"older Slot 1 restores the unanswered Day 1 ordinary through its canonical query"): return
	if not tree._check(game.contacts.messages == contacts_before_expiry.messages
		and game.contacts.next_sequence == contacts_before_expiry.next_sequence
		and game.contacts.read_watermarks == contacts_before_expiry.read_watermarks
		and game.get_pending_ordinary_echoes().is_empty(),
		"older Load invents no message, sequence, watermark or echo effect"): return
	var restored_host: Dictionary = desktop.get("_host_state").get_state()
	if not tree._check(restored_host.get("active_app_id") == &"backup",
		"older Slot 1 truthfully restores its saved Backup app projection: " + JSON.stringify(restored_host)): return
	var home: Dictionary = desktop.return_home()
	if not tree._check(home.get("ok", false),
		"Home closes restored Backup before Contacts opens: " + JSON.stringify(home)): return
	if not tree._check(desktop.open_app(&"contacts").get("ok", false), "older Slot 1 restored Contacts opens"): return
	await tree._frames()
	app = desktop.get("_cached_app_windows")[&"contacts"]
	app.contacts_panel.open_requested.emit("lavinia")
	await tree._frames()
	for choice_name: String in ["OrdinaryReplyA", "OrdinaryReplyB", "OrdinaryReplyC"]:
		var choice: Button = app.find_child(choice_name, true, false)
		if not tree._check(choice != null and choice.is_visible_in_tree() and not choice.disabled,
			"older Slot 1 restores visible Day 1 choice: " + choice_name): return
	if not await tree._capture_screen("ordinary-expiry-earlier-slot-restored"): return
	print("PLAYABLE_ORDINARY_EXPIRY_PASS: actual New Account -> ignored Day 1 ordinary -> pre-expiry Slot 1 Save -> Schedule Done -> one invisible expiry on the existing receipt -> Day 2 Autosave Load -> older Slot 1 Load -> Day 1 ordinary restored without overlay")
	tree.quit(0)


func _save_slot1(tree: SceneTree, desktop: Node) -> bool:
	if not tree._check(desktop.open_app(&"backup").get("ok", false),
		"open actual Backup for pre-expiry Slot 1 Save"): return false
	await tree._frames()
	var backup: Control = desktop.get("_cached_app_windows")[&"backup"]
	if not tree._check(backup != null and backup.is_visible_in_tree(), "real Backup Save surface opens"): return false
	if backup.active_mode != "save":
		backup.mode_buttons["save"].pressed.emit()
	backup.drawer_buttons["slot:1"].pressed.emit()
	await tree._frames()
	if not tree._check(not backup.action_buttons["save"].disabled, "pre-expiry Slot 1 Save is available"): return false
	backup.action_buttons["save"].pressed.emit()
	if is_instance_valid(backup.confirmation): backup.confirmation.confirm_button.pressed.emit()
	for frame: int in 180:
		await tree.process_frame
		if not bool(backup.get("_in_operation")) and backup.get("_status_key") == "saved": break
	return tree._check(not bool(backup.get("_in_operation")) and backup.get("_status_key") == "saved"
		and backup.last_result.get("ok", false),
		"public Backup command commits the pre-expiry Slot 1 snapshot: " + JSON.stringify(backup.last_result))


func _load_backup_record(tree: SceneTree, game: Node, desktop: Node,
		locator: String, prior_session: Dictionary) -> Dictionary:
	if not tree._check(desktop.open_app(&"backup").get("ok", false),
		"open actual Backup for %s Load" % locator): return {}
	await tree._frames()
	var backup: Control = desktop.get("_cached_app_windows")[&"backup"]
	if not tree._check(backup != null and backup.is_visible_in_tree(), "real Backup Load surface opens"): return {}
	if backup.active_mode != "load":
		backup.mode_buttons["load"].pressed.emit()
	backup.drawer_buttons[locator].pressed.emit()
	await tree._frames()
	if not tree._check(not backup.action_buttons["load"].disabled,
		"%s is available through the public Backup Load action" % locator): return {}
	backup.action_buttons["load"].pressed.emit()
	if not tree._check(is_instance_valid(backup.confirmation), "%s Load requires confirmation" % locator): return {}
	backup.confirmation.confirm_button.pressed.emit()
	var restored_desktop: Node = null
	for frame: int in 180:
		await tree.process_frame
		restored_desktop = tree.current_scene.find_child("ComputerDesktop", true, false) \
			if tree.current_scene != null else null
		if game.capture_live_session().value.active and game.capture_live_session().value != prior_session \
				and restored_desktop != null: break
	if not tree._check(game.capture_live_session().value.active
		and game.capture_live_session().value != prior_session and restored_desktop != null,
		"%s Load installs a fresh live desktop session" % locator): return {}
	return {"ok": true, "desktop": restored_desktop}


func _expiry_receipts(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in state.transaction_receipts.values():
		if raw is Dictionary and raw.has("ordinary_expired_entry_id"):
			result.append(raw)
	return result


func _check_expired(tree: SceneTree, game: Node, before: Dictionary) -> bool:
	var expiries: Array[Dictionary] = _expiry_receipts(game.contacts)
	var day1_closures: Array[Dictionary] = []
	for raw: Variant in game.contacts.transaction_receipts.values():
		if raw is Dictionary and raw.get("kind") == "resolve_day_end" and raw.get("day") == 1:
			day1_closures.append(raw)
	if not tree._check(day1_closures.size() == 1 and expiries.size() == 1
		and expiries[0] == day1_closures[0] and expiries[0].get("kind") == "resolve_day_end"
		and expiries[0].get("day") == 1
		and expiries[0].get("ordinary_expired_entry_id") == "contact.ordinary.lavinia.day1",
		"exactly one existing Day 1 day-end receipt owns the optional ordinary expiry fact"): return false
	var old: Dictionary = ORDINARY.available(game.contacts, 1, "lavinia")
	if not tree._check(old.get("ok", false) and old.value.is_empty(), "expiry blocks generation even when queried for the original Day 1"): return false
	if not tree._check(game.contacts.messages == before.messages, "expiry adds no ignored-message player history"): return false
	if not tree._check(game.contacts.next_sequence == before.next_sequence
		and game.contacts.read_watermarks == before.read_watermarks,
		"expiry allocates no sequence and changes no read watermark"): return false
	if not tree._check(game.get_pending_ordinary_echoes().is_empty(), "no unwitnessed echo"): return false
	for receipt: Dictionary in game.contacts.transaction_receipts.values():
		if not tree._check(receipt.kind not in ORDINARY.RECEIPT_KINDS, "no invented reply or echo receipt"): return false
	var late: Dictionary = ORDINARY.prepare_reply(game.contacts, game.day, "reply.ordinary.lavinia.day1.a",
		"en", "late-day1-attempt", {}, {})
	if not tree._check(not late.ok and str(late.code) == "ordinary_reply_wrong_day", "old semantic choice is expired"): return false
	var current: Dictionary = ORDINARY.available(game.contacts, game.day, "sylvia")
	return tree._check(current.get("ok", false) and current.value.get("choices", []).size() == 3,
		"new Day 2 ordinary keeps all three choices")
