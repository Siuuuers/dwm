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
	if not tree._check(desktop.return_home().get("ok", false), "Home with unanswered ordinary"): return
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
	if not _check_expired(tree, game): return
	var contacts_before: Dictionary = game.contacts.duplicate(true)
	var session_before: Dictionary = game.capture_live_session().value.duplicate(true)
	var saves: Node = tree.root.get_node("SaveManager")
	var prepared: Dictionary = saves.prepare_restore_autosave()
	if not tree._check(prepared.get("ok", false), "real Day 2 disk Autosave prepares: " + JSON.stringify(prepared)): return
	var loaded: Dictionary = saves.commit_prepared_restore(prepared.value.prepared)
	if not tree._check(loaded.get("ok", false), "real Autosave installs all restore participants: " + JSON.stringify(loaded)): return
	await tree._frames()
	if not tree._check(game.day == 2 and game.capture_live_session().value.active
			and game.capture_live_session().value != session_before, "Load activates a fresh Day 2 session"): return
	if not tree._check(game.contacts == contacts_before, "Load preserves exact saved Contacts facts"): return
	if not _check_expired(tree, game): return
	desktop = tree.current_scene.find_child("ComputerDesktop", true, false)
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
	print("PLAYABLE_ORDINARY_EXPIRY_PASS: actual New Account -> viewed but unanswered ordinary -> Schedule Done -> Day 2 disk Autosave -> full Load -> no late reply/history/echo; new Day 2 ordinary available")
	tree.quit(0)


func _check_expired(tree: SceneTree, game: Node) -> bool:
	var old: Dictionary = ORDINARY.available(game.contacts, game.day, "lavinia")
	if not tree._check(old.get("ok", false) and old.value.is_empty(), "no old Day 1 ordinary menu"): return false
	if not tree._check(game.contacts.messages.lavinia.is_empty(), "no ignored-message player history"): return false
	if not tree._check(game.get_pending_ordinary_echoes().is_empty(), "no unwitnessed echo"): return false
	for receipt: Dictionary in game.contacts.transaction_receipts.values():
		if not tree._check(receipt.kind not in ORDINARY.RECEIPT_KINDS, "no invented reply or echo receipt"): return false
	var late: Dictionary = ORDINARY.prepare_reply(game.contacts, game.day, "reply.ordinary.lavinia.day1.a",
		"en", "late-day1-attempt", {}, {})
	if not tree._check(not late.ok and str(late.code) == "ordinary_reply_wrong_day", "old semantic choice is expired"): return false
	var current: Dictionary = ORDINARY.available(game.contacts, game.day, "sylvia")
	return tree._check(current.get("ok", false) and current.value.get("choices", []).size() == 3,
		"new Day 2 ordinary keeps all three choices")
