extends "res://addons/gut/test.gd"
## Real production gate/issuer; fake root + retained owner. NON-CRASH proof only.
const FIXTURE := preload("res://tests/support/SceneEventFixture.gd")
const PORT := preload("res://scripts/application/narrative/SceneEventCommandPort.gd")

func test_exact_duplicate_and_new_port_apply_once_even_after_frontier_moves() -> void:
	var fixture: RefCounted = FIXTURE.new()
	var port: RefCounted = fixture.make_port()
	var first: Dictionary = port.dispatch(fixture.event_at(0))
	assert_true(first.ok)
	assert_true(port.dispatch(fixture.event_at(1)).ok)
	var state: Dictionary = fixture.observable_state()
	fixture.playback_token = "TEST.playback.2"
	port = fixture.make_port()
	assert_eq(port.dispatch(fixture.event_at(0)), first)
	assert_eq(fixture.observable_state(), state)
	assert_false(fixture.gate.is_active())

func test_changed_duplicate_conflicts_without_another_effect() -> void:
	var fixture: RefCounted = FIXTURE.new()
	var port: RefCounted = fixture.make_port()
	assert_true(port.dispatch(fixture.event_at(0)).ok)
	var changed: Dictionary = fixture.event_at(0)
	changed.payload.scene_id = "TEST.altered"
	var state: Dictionary = fixture.observable_state()
	assert_eq(fixture.make_port().dispatch(changed).code, &"event_conflict")
	assert_eq(fixture.observable_state(), state)

func test_uncertain_recreated_port_cannot_repeat_effect_or_advance() -> void:
	var fixture: RefCounted = FIXTURE.new()
	fixture.uncertain_next = true
	var port: RefCounted = fixture.make_port()
	assert_eq(port.dispatch(fixture.event_at(0)).code, &"event_uncertain")
	assert_eq(fixture.effect_calls, 1)
	assert_eq(fixture.next_ordinal, 0)
	assert_eq(fixture.publications.size(), 0)
	var state: Dictionary = fixture.observable_state()
	fixture.playback_token = "TEST.playback.2"
	port = fixture.make_port()
	assert_eq(port.dispatch(fixture.event_at(0)).code, &"event_uncertain")
	assert_eq(port.dispatch(fixture.event_at(1)).code, &"event_pending_custody")
	var changed: Dictionary = fixture.event_at(0)
	changed.payload.scene_id = "TEST.altered"
	assert_eq(port.dispatch(changed).code, &"event_conflict")
	assert_eq(fixture.observable_state(), state)
	fixture.resolve_committed()
	state = fixture.observable_state()
	assert_true(fixture.make_port().dispatch(fixture.event_at(0)).ok)
	assert_eq(fixture.observable_state(), state)
	assert_eq(fixture.effect_calls, 1)
	assert_eq(fixture.next_ordinal, 1)
	assert_eq(fixture.publications, ["TEST.A"])
	assert_eq(fixture.make_port().dispatch(changed).code, &"event_conflict")

func test_ordered_subordinate_publications_and_no_trigger_no_line() -> void:
	for with_talk: bool in [true, false]:
		var fixture: RefCounted = FIXTURE.new(with_talk)
		var port: RefCounted = fixture.make_port()
		assert_eq(fixture.publications.size(), 0)
		for index in range(fixture.events.size()): assert_true(port.dispatch(fixture.event_at(index)).ok)
		assert_eq(fixture.publications, ["TEST.A", "TEST.selftalk.A", "TEST.B"] if with_talk else ["TEST.A", "TEST.B"])
		assert_eq(fixture.next_ordinal, fixture.events.size())
		assert_eq(fixture.effect_calls, fixture.events.size())

func test_source_registration_token_order_and_issuer_refuse_without_mutation() -> void:
	var fixture: RefCounted = FIXTURE.new()
	var port: RefCounted = fixture.make_port()
	var candidates: Array[Dictionary] = []
	var bad: Dictionary = fixture.event_at(0)
	bad.source.branch_id = "TEST.wrong"
	candidates.append(bad)
	bad = fixture.event_at(0)
	bad.playback_token = "TEST.stale"
	candidates.append(bad)
	candidates.append(fixture.event_at(1))
	bad = fixture.event_at(0)
	bad.event_id = "TEST.unregistered"
	candidates.append(bad)
	bad = fixture.event_at(0)
	bad.issuer_receipt.counter += 1
	candidates.append(bad)
	bad = fixture.event_at(0)
	bad.predecessor = "TEST.wrong"
	candidates.append(bad)
	# A fresh authentic root token cannot purchase a second occurrence identity.
	bad = fixture.event_at(0)
	var issued: Dictionary = fixture.issuer.issue(&"transaction_id")
	bad.command_id = issued.value.token
	bad.issuer_receipt = issued.value.issuer_receipt
	candidates.append(bad)
	var state: Dictionary = fixture.observable_state()
	for candidate: Dictionary in candidates:
		assert_false(port.dispatch(candidate).ok)
		assert_eq(fixture.observable_state(), state)
		assert_false(fixture.gate.is_active())

func test_suspended_computer_replay_and_real_gate_owners_refuse() -> void:
	for flag: String in ["suspended", "computer_held", "mode"]:
		var fixture: RefCounted = FIXTURE.new()
		fixture.set(flag, "rehearsal" if flag == "mode" else true)
		var state: Dictionary = fixture.observable_state()
		assert_eq(fixture.make_port().dispatch(fixture.event_at(0)).code, &"event_presentation_held")
		assert_eq(fixture.observable_state(), state)
		assert_false(fixture.gate.is_active())
	for holder: StringName in [&"restore", &"new_run", &"causal_transaction", &"session_abandonment"]:
		var fixture: RefCounted = FIXTURE.new()
		var held: Dictionary = fixture.gate.acquire(holder)
		var state: Dictionary = fixture.observable_state()
		assert_eq(fixture.make_port().dispatch(fixture.event_at(0)).code, &"TRANSACTION_ACTIVE")
		assert_eq(fixture.observable_state(), state)
		assert_true(fixture.gate.is_lease_active(holder, held.value.token))
		assert_true(fixture.gate.release(holder, held.value.token).ok)

func test_fatal_gate_blocks_even_previously_committed_duplicate() -> void:
	var fixture: RefCounted = FIXTURE.new()
	var port: RefCounted = fixture.make_port()
	assert_true(port.dispatch(fixture.event_at(0)).ok)
	assert_true(fixture.gate.latch_fatal({"source": "TEST", "phase": "commit", "code": "TEST.failure", "details": {}}).ok)
	var state: Dictionary = fixture.observable_state()
	assert_eq(port.dispatch(fixture.event_at(0)).code, &"APPLICATION_FATAL")
	assert_eq(fixture.observable_state(), state)

func test_proven_refusal_can_retry_without_prior_effect_and_outputs_are_detached() -> void:
	var fixture: RefCounted = FIXTURE.new()
	fixture.refuse_next = true
	var port: RefCounted = fixture.make_port()
	var state: Dictionary = fixture.observable_state()
	assert_false(port.dispatch(fixture.event_at(0)).ok)
	assert_eq(fixture.observable_state(), state)
	var outcome: Dictionary = port.dispatch(fixture.event_at(0))
	assert_true(outcome.ok)
	outcome.value.event_id = "TEST.corrupted.result"
	assert_eq(port.dispatch(fixture.event_at(0)).value.event_id, "TEST.event.0")
	assert_eq(fixture.effect_calls, 1)

func test_unconfigured_and_rebinding_ports_fail_closed() -> void:
	var port: RefCounted = PORT.new()
	var fixture: RefCounted = FIXTURE.new()
	assert_eq(port.dispatch(fixture.event_at(0)).code, &"event_port_unconfigured")
	assert_false(port.configure(fixture, RefCounted.new(), fixture.issuer).ok)
	assert_true(port.configure(fixture, fixture.gate, fixture.issuer).ok)
	assert_false(port.configure(fixture, fixture.gate, fixture.issuer).ok)
