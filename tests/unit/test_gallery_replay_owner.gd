extends GutTest
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const PORT := preload("res://scripts/application/ending/DialogicEndingPlaybackPort.gd")
const REPLAY := preload("res://scripts/application/ending/GalleryReplayOwner.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")

class Runtime extends RefCounted:
	signal timeline_started_signal
	signal timeline_ended_signal
	signal event_handled_signal(resource)
	signal runtime_signal_event(argument)
	signal preference_reapply_requested
	signal playback_start_failed(failure: Dictionary)
	var starts: Array[Dictionary] = []
	var active := false
	func start_timeline(path: String, label: Variant = 0) -> Dictionary:
		starts.append({"path":path,"label":label})
		active = true
		return {"ok":true}
	func has_active_playback() -> bool: return active
	func halt_with_error(_result: Dictionary) -> Dictionary:
		active = false
		return {"ok":true}
	func finish() -> void:
		active = false
		timeline_ended_signal.emit()

class Reader extends RefCounted:
	var signature: Dictionary
	func capture(_ending: String, _context: Dictionary) -> Dictionary:
		return {"ok":true,"value":signature.duplicate(true)}

var profile: Node
var bridge: Node
var runtime: Runtime
var replay: RefCounted

func before_each() -> void:
	profile = preload("res://autoload/ProfileManager.gd").new()
	add_child_autofree(profile)
	var storage := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new("replay-memory", preload("res://tests/support/FakeFileOps.gd").new())
	assert_true(profile.initialize(storage).ok)
	runtime = Runtime.new()
	bridge = BRIDGE.new()
	add_child_autofree(bridge)
	assert_true(bridge.initialize(null,runtime).ok)
	replay = REPLAY.new()
	assert_true(replay.configure(profile,bridge).ok)

func _alone(form: String = "alone_normal") -> Dictionary:
	return {"entry_id":"ending.alone.normal" if form == "alone_normal" else "ending.alone.dark_mode",
		"schema_version":1,"fields":{"ending_role":"core","ending_form":form}}

func _record(signature: Dictionary) -> String:
	var recorded: Dictionary = profile.record_reached_presentation(signature)
	assert_true(recorded.get("ok",false),str(recorded))
	return str(recorded.get("value",{}).get("signature_id",""))

func test_canonical_completion_records_the_exact_label_then_gallery_has_no_canonical_effects() -> void:
	var reader := Reader.new()
	reader.signature = _alone("alone_dark_mode")
	var port := PORT.new()
	assert_true(port.initialize(bridge).ok)
	assert_true(port.configure_reached_presentations(profile,reader.capture).ok)
	watch_signals(port)
	var context := {"playback_id":"run:ending:0","transaction_id":"run:ending:0:complete","expected_stage":&"PRIMARY_PENDING","role":&"core"}
	var started: Dictionary = port.start_ending_id("ending.alone",context)
	assert_true(started.get("ok",false),str(started))
	if not started.get("ok",false): return
	assert_eq(runtime.starts.back().label,"ending.alone.dark_mode")
	assert_eq(profile.get_reached_presentations().value.records,[],"start alone is not physical completion")
	runtime.finish()
	assert_signal_emit_count(port,"playback_completed",1)
	var rows: Array = profile.get_reached_presentations().value.records
	assert_eq(rows.size(),1)
	if rows.is_empty(): return
	assert_eq(rows[0].signature,reader.signature)
	assert_true(profile.unlock_ending("ending.alone","fixture:discovery").ok)
	var before: Dictionary = profile.get_profile_snapshot()
	var old_counter: int = bridge._playback_counter
	assert_true(replay.begin(rows[0].signature_id).ok)
	assert_eq(runtime.starts.back().label,"ending.alone.dark_mode")
	runtime.runtime_signal_event.emit({"kind":"effect_transaction","transaction_id":"forbidden"})
	runtime.finish()
	assert_false(replay.is_playing())
	assert_eq(profile.get_profile_snapshot(),before)
	assert_eq(bridge._playback_counter,old_counter,"Gallery has its own process-local token sequence")
	assert_signal_emit_count(port,"playback_completed",1,"Gallery never enters canonical ending completion")

func test_discovery_is_not_permission_for_an_unreached_signature() -> void:
	var identity := _record(_alone())
	assert_eq(replay.begin(identity).get("code"),&"ending_not_discovered")
	assert_true(profile.unlock_ending("ending.alone","fixture:discovery").ok)
	var unseen: Dictionary = SIGNATURE.validate(_alone("alone_dark_mode"))
	assert_eq(replay.begin(unseen.value.signature_id).get("code"),&"presentation_not_reached")
	assert_eq(runtime.starts,[])
	assert_true(replay.begin(identity).ok)
	assert_true(replay.close().ok)

func test_return_cancels_only_its_token_and_a_late_old_completion_cannot_close_replay() -> void:
	var identity := _record(_alone())
	assert_true(profile.unlock_ending("ending.alone","fixture:discovery").ok)
	var before: Dictionary = profile.get_profile_snapshot()
	var first: Dictionary = replay.begin(identity)
	assert_true(first.ok)
	assert_true(replay.close().ok)
	assert_false(bridge.has_active_playback())
	assert_true(replay.begin(identity).ok)
	bridge.reached_replay_finished.emit({"signature_id":identity,"playback_token":first.receipt.playback_token,"outcome":"completed","code":""})
	assert_true(replay.is_playing(),"late old completion cannot release the new token")
	runtime.finish()
	assert_false(replay.is_playing())
	assert_eq(profile.get_profile_snapshot(),before)

func test_gallery_exceptional_variants_are_full_and_pair_alone_reject_solo_fields() -> void:
	var solo := {"tier":"ambiguous","tone":"sweet","attitude":"neutral","echo_ids":[],"miss_reasons":[],"ending_role":"observer_coda","ending_form":"observer_full","residue":false}
	var full := {"entry_id":"ending.priscilla.observer.full","schema_version":1,"fields":solo}
	var residue := full.duplicate(true)
	residue.entry_id = "ending.priscilla.observer.residue"
	residue.fields.ending_form = "observer_residue"
	residue.fields.residue = true
	var full_id := _record(full)
	var residue_id := _record(residue)
	var discovered: Dictionary = profile.unlock_ending("ending.priscilla.observation","fixture:observer")
	assert_true(discovered.get("ok",false),str(discovered))
	if not discovered.get("ok",false): return
	var variants: Dictionary = replay.get_variants("ending.priscilla.observer")
	assert_true(variants.get("ok",false),str(variants))
	if not variants.get("ok",false): return
	assert_eq(variants.value.records.size(),1)
	assert_eq(variants.value.records[0].signature_id,full_id)
	assert_eq(replay.begin(residue_id).get("code"),&"gallery_requires_full_presentation")
	var alone := _alone()
	alone.fields.tier = "friend"
	assert_false(SIGNATURE.validate(alone).ok)
	var pair := {"entry_id":"ending.priscilla_lavinia.sweet","schema_version":1,"fields":{"pair_form":"love_sweet","ending_role":"pair_coda","ending_form":"deck_sweet","residue":false}}
	assert_true(SIGNATURE.validate(pair).ok)
	pair.fields.attitude = "neutral"
	assert_false(SIGNATURE.validate(pair).ok)

func test_public_record_titles_preserve_chinese_characters() -> void:
	var catalog := preload("res://scripts/ui/gallery/GalleryRecordCatalog.gd")
	assert_eq(catalog.TITLES.size(),13)
	for identity: String in catalog.TITLES:
		var caption: String = catalog.title(identity,"zh_CN")
		assert_false(caption.is_empty())
		assert_false(caption.contains("?"),"UTF-8 title must not be shell replacement characters")
		assert_ne(caption,catalog.title(identity,"en"))

func test_public_gallery_selects_only_reached_versions_and_return_cancels_its_playback() -> void:
	_record(_alone())
	_record(_alone("alone_dark_mode"))
	assert_true(profile.unlock_ending("ending.alone","fixture:discovery").ok)
	var home := Button.new()
	add_child_autofree(home)
	var gallery: Control = preload("res://scenes/menu/GalleryScene.tscn").instantiate()
	assert_true(gallery.configure_title_host(home,null,profile).ok)
	assert_true(gallery.configure_replay(bridge).ok)
	add_child_autofree(gallery)
	gallery.open_in_title_host()
	assert_eq(gallery.get_node("%EndingTileGrid").get_child_count(),1)
	assert_eq(gallery.get_node("%EndingTileGrid").get_child(0).text,"A Quiet Morning")
	assert_eq(gallery._version_selector.item_count,2)
	assert_true(gallery._version_selector.visible)
	assert_false(gallery.get_node("%ReplayButton").disabled)
	var before: Dictionary = profile.get_profile_snapshot()
	gallery._version_selector.item_selected.emit(1)
	var entry_id: String = gallery._versions[1].signature.entry_id
	gallery.get_node("%ReplayButton").pressed.emit()
	assert_eq(runtime.starts.back().label,entry_id)
	assert_true(gallery.get_node("%ReplayButton").disabled)
	assert_true(gallery.close_for_title_host())
	assert_false(bridge.has_active_playback())
	assert_false(gallery.visible)
	assert_eq(profile.get_profile_snapshot(),before)

func test_deferred_start_failure_releases_gallery_without_canonical_failure_and_can_retry() -> void:
	var identity := _record(_alone())
	assert_true(profile.unlock_ending("ending.alone","fixture:discovery").ok)
	watch_signals(bridge)
	watch_signals(replay)
	var before: Dictionary = profile.get_profile_snapshot()
	assert_true(replay.begin(identity).ok)
	runtime.active = false
	runtime.playback_start_failed.emit({"ok":false,"code":&"fixture_deferred_start_failure"})
	assert_false(replay.is_playing())
	assert_false(bridge.has_active_playback())
	assert_signal_emit_count(replay,"playback_finished",1)
	assert_signal_emit_count(bridge,"timeline_failed",0,"a replay failure cannot enter canonical recovery")
	assert_true(replay.begin(identity).ok)
	runtime.finish()
	assert_eq(profile.get_profile_snapshot(),before)


func _date(post: bool = false, pair: bool = false) -> Dictionary:
	var fields := {"pair_mode":"group", "pair_form":"love_sweet"} if pair else {
		"tier":"ambiguous", "tone":"sweet", "attitude":"neutral", "echo_ids":[]}
	if post:
		fields.merge({"board_result":"perfect", "perfect_reasons":["no_flag"]})
		if not pair: fields.merge({"relationship_outcome":"dark", "special_mine_phase":"detonated", "promotion_result":"none"})
	return {"entry_id": ("dating.group.priscilla_lavinia.day2." if pair else "dating.solo.lavinia.day2.") + ("post_challenge" if post else "pre_challenge"),
		"schema_version":1, "fields":fields}

func test_nonending_replay_requires_milestone_and_exact_reached_signature() -> void:
	var signature := _date()
	var identity := _record(signature)
	assert_eq(replay.get_reached_entry_variants().value.records, [])
	assert_eq(replay.begin(identity).get("code"), &"reached_replay_locked")
	assert_true(profile.unlock_ending("ending.alone", "fixture:discovery").ok)
	var variants: Dictionary = replay.get_reached_entry_variants(signature.entry_id)
	assert_eq(variants.value.records, [{"signature_id":identity, "signature":signature}])
	variants.value.records[0].signature.fields.tone = "dark"
	assert_eq(replay.get_reached_entry_variants(signature.entry_id).value.records[0].signature, signature)
	var unseen := signature.duplicate(true)
	unseen.fields.tone = "dark"
	assert_eq(replay.begin(SIGNATURE.validate(unseen).value.signature_id).get("code"), &"presentation_not_reached")
	assert_eq(runtime.starts, [])

func test_reached_date_renders_its_actual_phase_and_only_drawn_acknowledgment_finishes() -> void:
	var signature := _date()
	var identity := _record(signature)
	assert_true(profile.unlock_ending("ending.alone", "fixture:discovery").ok)
	var before: Dictionary = profile.get_profile_snapshot()
	var started: Dictionary = replay.begin(identity)
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return
	assert_eq(runtime.starts, [], "empty DTL return cannot substitute for the actually displayed date")
	assert_eq(bridge._reached_replay.signature, signature)
	var card: Dictionary = bridge._reached_replay.card.duplicate(true)
	assert_eq(card.body, "Ready to begin.")
	assert_string_contains(card.title, "Lavinia")
	assert_string_contains(card.title, "2")
	assert_false(card.title.contains("dating."))
	assert_eq(bridge._acknowledge_reached_date_card(card.receipt).get("code"), &"replay_presentation_not_drawn")
	assert_eq(bridge.acknowledge_signal("history.line.witness", {}).get("code"), &"rehearsal_commit_denied")
	assert_eq(bridge.request_skip_step().get("code"), &"rehearsal_commit_denied")
	assert_true(bridge.has_active_playback())
	var surface: Node = bridge._reached_replay.surface
	surface._current_body.draw.emit() # Unit-test render acknowledgement; the GPU journey supplies real draw.
	surface._next.pressed.emit()
	assert_false(replay.is_playing())
	assert_false(bridge.has_active_playback())
	assert_eq(profile.get_profile_snapshot(), before)

func test_pair_post_replay_is_readonly_and_old_card_cannot_finish_replacement() -> void:
	var identity := _record(_date(true, true))
	assert_true(profile.unlock_ending("ending.alone", "fixture:discovery").ok)
	var before: Dictionary = profile.get_profile_snapshot()
	assert_true(replay.begin(identity).ok)
	var old: Dictionary = bridge._reached_replay.card.receipt.duplicate(true)
	assert_eq(bridge._reached_replay.card.body, "Challenge complete.")
	assert_string_contains(bridge._reached_replay.card.title, "Priscilla & Lavinia")
	assert_true(replay.close().ok)
	assert_true(replay.begin(identity).ok)
	assert_ne(bridge._reached_replay.card.receipt.view_token, old.view_token)
	assert_eq(bridge._acknowledge_reached_date_card(old).get("code"), &"replay_identity_mismatch")
	bridge._on_reached_date_card_acknowledged(old, {"ok":true})
	assert_true(replay.is_playing())
	runtime.finish()
	assert_true(replay.is_playing(), "an unrelated timeline return cannot complete this native card")
	assert_true(replay.close().ok)
	assert_eq(profile.get_profile_snapshot(), before)

func test_public_gallery_includes_reached_date_stages_without_new_ending_discoveries() -> void:
	_record(_alone())
	var date_id := _record(_date())
	_record(_date(true))
	assert_true(profile.unlock_ending("ending.alone", "fixture:discovery").ok)
	var home := Button.new()
	add_child_autofree(home)
	var gallery: Control = preload("res://scenes/menu/GalleryScene.tscn").instantiate()
	assert_true(gallery.configure_title_host(home, null, profile).ok)
	assert_true(gallery.configure_replay(bridge).ok)
	add_child_autofree(gallery)
	gallery.open_in_title_host()
	var selected: Button
	for tile: Button in gallery.get_node("%EndingTileGrid").get_children():
		assert_false(tile.text.contains("dating."))
		assert_false(tile.text.contains("signature"))
		if tile.get_meta(&"gallery_record_id") == "dating.solo.lavinia.day2.pre_challenge": selected = tile
	assert_not_null(selected)
	if selected == null: return
	selected.pressed.emit()
	assert_eq(gallery._versions[0].signature_id, date_id)
	gallery.get_node("%ReplayButton").pressed.emit()
	assert_true(bridge._reached_replay.has("surface"))
	assert_true(gallery.close_for_title_host())
	assert_false(bridge.has_active_playback())
	assert_eq(profile.get_gallery_discovery_snapshot().value.ending_ids, ["ending.alone"])
