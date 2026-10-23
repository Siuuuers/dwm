extends "res://addons/gut/test.gd"
## Callback-level transport regression. The host supplies the installed handler's
## current event/custody queries; real text events perform their native cleanup.
## No test assigns the event execution generation or adapter activation counter.
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const FIXTURE := preload("res://tests/support/SceneDayReadingFixture.gd")

class NativeHost extends Node:
	var current_timeline := DialogicTimeline.new()
	var current_timeline_events: Array = []
	var current_event_idx := 0
	var current_state := DialogicGameHandler.States.IDLE
	var paused := false
	var generation := 17
	var ending := false
	func get_timeline_generation() -> int: return generation
	func is_ending_timeline() -> bool: return ending

func before_all() -> void:
	assert_true(FIXTURE.configure().ok)

func _rig() -> Dictionary:
	var created := FIXTURE.create_session()
	assert_true(created.ok)
	var session: RefCounted = created.value
	assert_true(session.admit_scene(FIXTURE.A, FIXTURE.frame(FIXTURE.A, "visit:activation")).ok)
	var event := DialogicTextEvent.new()
	event._load_from_string("A loop. #id:line.scene.test.a.two")
	event.dialogic = get_node("/root/Dialogic")
	var host := NativeHost.new()
	add_child_autofree(host)
	host.current_timeline_events = [event]
	var adapter := ADAPTER.new()
	adapter._dialogic = host
	adapter._bound = true
	adapter._qualified_runtime = true
	adapter._activity_phase = "live"
	adapter._request_id = "request:activation"
	adapter._caption_request = "request:activation"
	adapter._runtime_generation = host.generation
	adapter._caption_generation = host.generation
	adapter._requested_path = host.current_timeline.resource_path
	adapter._caption_ledger = session.ledger
	adapter._caption_token = FIXTURE.TOKEN
	adapter._caption_entry = FIXTURE.A
	adapter._scene_caption_occurrence = "visit:activation"
	return {"adapter": adapter, "host": host, "event": event, "ledger": session.ledger}

func _publish(rig: Dictionary) -> void:
	rig.adapter._on_caption_about_to_show({})
	rig.adapter._on_caption_text_started({})

func test_native_cleanup_then_same_event_loop_publishes_fresh_occurrence() -> void:
	var rig := _rig()
	_publish(rig)
	var first: Dictionary = rig.ledger.snapshot().captions[0]
	_publish(rig) # Duplicate about/text callbacks in the same native activation.
	assert_eq(rig.ledger.snapshot().captions.size(), 1)
	# GameHandler.handle_event cleans the departing event before a Jump and
	# later executes this same resource. Exercise that installed cleanup law.
	rig.event._clear_state()
	assert_false(rig.adapter.can_capture_reading_frontier())
	rig.adapter._on_caption_text_started({}) # Missing new about callback refuses.
	assert_eq(rig.ledger.snapshot().captions.size(), 1)
	_publish(rig)
	var rows: Array = rig.ledger.snapshot().captions
	assert_eq(rows.size(), 2)
	assert_ne(rows[1].publication_id, first.publication_id)
	assert_eq(rows[1].beat, first.beat)
	assert_eq(rows[1].occurrence_id, first.occurrence_id)
	_publish(rig)
	assert_eq(rig.ledger.snapshot().captions.size(), 2)

func test_restored_frontier_reuses_publication_then_later_loop_is_fresh() -> void:
	var rig := _rig()
	_publish(rig)
	var frontier: Dictionary = rig.adapter.capture_reading_frontier().value
	rig.event._clear_state()
	rig.adapter._caption_restore_frontier = frontier.duplicate(true)
	rig.event.state = DialogicTextEvent.States.DONE
	_publish(rig)
	await get_tree().process_frame # Real deferred restore completion clears frontier.
	assert_eq(rig.ledger.snapshot().captions.size(), 1)
	assert_true(rig.adapter.capture_reading_frontier().ok)
	assert_eq(rig.adapter.capture_reading_frontier().value, frontier)
	_publish(rig)
	assert_eq(rig.ledger.snapshot().captions.size(), 1)
	rig.event._clear_state()
	_publish(rig)
	assert_eq(rig.ledger.snapshot().captions.size(), 2)

func test_request_generation_and_retirement_fences_stale_callbacks() -> void:
	var rig := _rig()
	_publish(rig)
	var saved: Dictionary = rig.ledger.snapshot()
	rig.host.generation += 1
	rig.event._clear_state()
	_publish(rig)
	assert_eq(rig.ledger.snapshot(), saved)
	rig.host.generation -= 1
	rig.adapter._request_id = "request:replacement"
	_publish(rig)
	assert_eq(rig.ledger.snapshot(), saved)
	rig.adapter._retire_caption_binding()
	_publish(rig)
	assert_eq(rig.ledger.snapshot(), saved)
