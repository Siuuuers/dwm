extends "res://addons/gut/test.gd"

const REPLIES := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

var _issuer: RefCounted

func before_each() -> void:
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(FAKE_ROOT.new("31".repeat(32), 1)).ok)

func _choose(state: Dictionary, day: int, choice: String = "a", locale: String = "en") -> Dictionary:
	var reply_id := "reply.ordinary.%s.day%d.%s" % [REPLIES.DAYS[day], day, choice]
	var row: Dictionary = REPLIES.reply_definition(reply_id, locale)
	assert_true(row.get("ok", false), str(row))
	if not row.get("ok", false): return row
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	var line := {"view_token": issued.value.token, "line_id": row.value.line_id, "text": row.value.text}
	return CONTACTS.prepare_reply_ordinary(state, day, reply_id, locale,
		issued.value.token, issued.receipt, line, _issuer)

func _present(state: Dictionary, pending: Dictionary) -> Dictionary:
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	var receipt := {"entry_id": "echo.fallback.day7", "view_token": issued.value.token,
		"echo_id": pending.echo_id, "presentation_atom_id": pending.presentation_atom_id}
	return CONTACTS.prepare_satisfy_ordinary_echo(state, pending.echo_id, pending.presentation_atom_id,
		issued.value.token, issued.receipt, receipt, _issuer)

func test_all_six_days_offer_three_registered_neutral_choices_and_unanswered_expire_without_state() -> void:
	var state := CONTACTS.make_defaults()
	var before := state.duplicate(true)
	var reply_ids := {}
	for day: int in range(1, 7):
		var available: Dictionary = REPLIES.available(state, day, REPLIES.DAYS[day])
		assert_true(available.ok, str(available))
		if not available.ok: return
		assert_eq(available.value.choices.size(), 3)
		for row: Dictionary in available.value.choices:
			reply_ids[row.reply_id] = true
			assert_true(str(row.line_id).ends_with(".reply." + str(row.reply_id).get_slice(".", 4)))
			assert_true(str(row.presentation_atom_id).ends_with(".fallback.day7"))
			assert_eq(row.day, day)
	assert_eq(reply_ids.size(), 18)
	assert_eq(REPLIES.available(state, 7, "sylvia").value, {})
	assert_eq(REPLIES.available(state, 2, "lavinia").value, {})
	assert_eq(state, before, "queries and midnight expiry create no tombstone or history")
	assert_eq(REPLIES.pending_echoes_oldest_first(state), [])

func test_one_witness_owns_three_history_rows_and_exact_retry_does_not_duplicate() -> void:
	var original := CONTACTS.make_defaults()
	var chosen := _choose(original, 1, "b")
	assert_true(chosen.ok, str(chosen))
	if not chosen.ok: return
	var candidate: Dictionary = chosen.value.candidate
	assert_eq(original, CONTACTS.make_defaults())
	assert_eq(candidate.messages.lavinia.size(), 3)
	assert_eq(candidate.next_sequence, 4)
	assert_eq(candidate.read_watermarks.lavinia, 3)
	assert_true(CONTACTS.validate_state(candidate).ok)
	assert_eq(REPLIES.available(candidate, 1, "lavinia").value, {})
	var receipt: Dictionary = chosen.receipt
	var replay: Dictionary = CONTACTS.prepare_reply_ordinary(candidate, 1, receipt.reply_id, receipt.locale,
		receipt.transaction_id, receipt.command_issuer_receipt, receipt.rendered_line, _issuer)
	assert_true(replay.ok, str(replay))
	assert_eq(replay.value.candidate, candidate)
	assert_eq(replay.value.message_batch, [])
	assert_false(_choose(candidate, 1, "c").ok)
	assert_eq(REPLIES.pending_echoes_oldest_first(candidate).size(), 1)

func test_registered_line_full_literal_and_actual_issued_root_are_required() -> void:
	var state := CONTACTS.make_defaults()
	var row: Dictionary = REPLIES.reply_definition("reply.ordinary.lavinia.day1.a").value
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	var line := {"view_token": issued.value.token, "line_id": row.line_id, "text": row.text}
	var forged := line.duplicate(true)
	forged.text = "A different visible choice."
	assert_false(CONTACTS.prepare_reply_ordinary(state, 1, row.reply_id, "en", issued.value.token, issued.receipt, forged, _issuer).ok)
	forged = line.duplicate(true)
	forged.line_id = "line.contact.ordinary.lavinia.day1.reply.b"
	assert_false(CONTACTS.prepare_reply_ordinary(state, 1, row.reply_id, "en", issued.value.token, issued.receipt, forged, _issuer).ok)
	assert_false(CONTACTS.prepare_reply_ordinary(state, 2, row.reply_id, "en", issued.value.token, issued.receipt, line, _issuer).ok)
	var foreign: RefCounted = ISSUER.new()
	assert_true(foreign.configure(FAKE_ROOT.new("32".repeat(32), 1)).ok)
	assert_false(CONTACTS.prepare_reply_ordinary(state, 1, row.reply_id, "en", issued.value.token, issued.receipt, line, foreign).ok)
	assert_eq(state, CONTACTS.make_defaults())

func test_echoes_drain_oldest_first_only_from_exact_registered_actual_presentation_and_retry() -> void:
	var state := CONTACTS.make_defaults()
	for day: int in range(1, 7):
		var chosen := _choose(state, day)
		assert_true(chosen.ok, str(chosen))
		if not chosen.ok: return
		state = chosen.value.candidate
	var pending := REPLIES.pending_echoes_oldest_first(state)
	assert_eq(pending.size(), 6)
	assert_false(_present(state, pending[1]).ok)
	for day: int in range(1, 7):
		pending = REPLIES.pending_echoes_oldest_first(state)
		assert_eq(pending[0].day, day)
		var presented := _present(state, pending[0])
		assert_true(presented.ok, str(presented))
		if not presented.ok: return
		state = presented.value.candidate
		var receipt: Dictionary = presented.receipt
		var retry: Dictionary = CONTACTS.prepare_satisfy_ordinary_echo(state, receipt.echo_id,
			receipt.presentation_atom_id, receipt.transaction_id, receipt.command_issuer_receipt,
			receipt.presentation_receipt, _issuer)
		assert_true(retry.ok, str(retry))
		assert_eq(retry.value.candidate, state)
	assert_eq(REPLIES.pending_echoes_oldest_first(state), [])
	assert_eq(state.transaction_receipts.size(), 12)
	assert_eq(state.next_sequence, 19, "echoes add no new message/relationship effects")
	assert_true(CONTACTS.validate_state(state).ok)

func test_saved_tampering_or_orphan_history_is_refused_without_legacy_schema_expansion() -> void:
	assert_true(REPLIES.validate_state({}).ok)
	var prepared := _choose(CONTACTS.make_defaults(), 1)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var state: Dictionary = prepared.value.candidate
	for field: String in ["reply_id", "echo_id", "plain_text_snapshot", "witnessed_line_id"]:
		var changed := state.duplicate(true)
		changed.transaction_receipts[prepared.receipt.transaction_id][field] = "altered"
		assert_false(REPLIES.validate_state(changed).ok, field)
	var changed := state.duplicate(true)
	changed.messages.lavinia[1].sequence = 99
	assert_false(REPLIES.validate_state(changed).ok)
	changed = state.duplicate(true)
	changed.transaction_receipts = {}
	assert_false(REPLIES.validate_state(changed).ok)
	changed = state.duplicate(true)
	changed.messages = []
	assert_false(REPLIES.validate_state(changed).ok, "malformed saved index returns refusal, never dereferences an array")
	changed = state.duplicate(true)
	changed.messages.lavinia.append(changed.messages.lavinia[0].duplicate(true))
	assert_false(REPLIES.validate_state(changed).ok)

func test_snapshots_escape_markup_normalize_newlines_and_limit_utf8_bytes() -> void:
	assert_eq(REPLIES.safe_snapshot("[b]<x>&\r\nline").value, "&#91;b&#93;&lt;x&gt;&amp;\nline")
	assert_false(REPLIES.safe_snapshot("tab\tcontrol").ok)
	assert_false(REPLIES.safe_snapshot("x".repeat(513)).ok)
	assert_true(REPLIES.safe_snapshot("x".repeat(512)).ok)
	for locale: String in REPLIES.LOCALES:
		var row: Dictionary = REPLIES.reply_definition("reply.ordinary.lavinia.day1.a", locale)
		assert_true(row.ok)
		assert_false(str(row.value.text).contains("?"), "translated literal contains real text")
		assert_true(REPLIES.safe_snapshot(row.value.text).ok)

func test_normal_save_json_numeric_normalization_preserves_exact_receipts_history_and_pending() -> void:
	var chosen := _choose(CONTACTS.make_defaults(), 1)
	assert_true(chosen.ok, str(chosen))
	if not chosen.ok: return
	var state: Dictionary = chosen.value.candidate
	var encoded := JSON.stringify(state)
	var parsed: Dictionary = JSON.parse_string(encoded)
	# The real RunSnapshot admission normalizes integral JSON numbers before Contact validation.
	var schema: Script = load("res://scripts/domain/run/RunSnapshotSchema.gd")
	var normalized: Dictionary = schema._normalize_integral_floats(parsed)
	assert_eq(normalized, state)
	assert_true(REPLIES.validate_state(normalized).ok)
	assert_true(CONTACTS.validate_state(normalized).ok)
	assert_eq(REPLIES.pending_echoes_oldest_first(normalized), REPLIES.pending_echoes_oldest_first(state))
