class_name OrdinaryReplyEchoState
extends RefCounted

## Six virtual unanswered messages; only a witnessed chosen reply becomes history.
## Pending echoes are derived from the two existing Contacts receipt kinds, never a second index.
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const ROOT := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const CALENDAR := preload("res://scripts/domain/contact/SevenDayCalendar.gd")
# Compatibility alias for callers that enumerate the ordinary-message calendar.
const DAYS := CALENDAR.ORDINARY_BY_DAY
const MESSAGE_KINDS := ["ordinary_incoming", "ordinary_reply", "ordinary_response"]
const RECEIPT_KINDS := ["ordinary_reply", "ordinary_echo_presented"]
const REPLY_KEYS := ["command_issuer_receipt", "content_version", "day", "echo_id", "entry_id", "friend_id", "kind", "locale", "message_ids", "message_sequences", "plain_text_snapshot", "presentation_atom_id", "rendered_line", "reply_id", "transaction_id", "witnessed_line_id"]
const ECHO_KEYS := ["command_issuer_receipt", "echo_id", "kind", "presentation_atom_id", "presentation_receipt", "reply_transaction_id", "transaction_id"]
const PROOF_KEYS := ["counter", "namespace", "numeric_value", "purpose", "receipt_id", "token"]
const LOCALES := ["en", "zh-CN", "zh-HK"]
# Provisional functional copy. Keep versioned historical literals when later prose replaces v1.
const COPY := {
	"en": {
		"incoming": "A small thought for today. Would you like to talk?",
		"choices": [
			"Tell me more.",
			"I'll keep that in mind.",
			"Let's talk another time."
		],
		"responses": [
			"Of course. I'm glad you asked.",
			"Thank you for listening.",
			"All right. We can talk another time."
		]
	},
	"zh-CN": {
		"incoming": "今天有一点小心事。想聊聊吗？",
		"choices": [
			"多告诉我一些吧。",
			"我会记在心里的。",
			"我们改天再聊吧。"
		],
		"responses": [
			"好呀，很高兴你愿意听。",
			"谢谢你听我说。",
			"好的，我们改天再聊。"
		]
	},
	"zh-HK": {
		"incoming": "今日有一點小心事。想聊聊嗎？",
		"choices": [
			"多告訴我一些吧。",
			"我會記在心裏的。",
			"我們改日再聊吧。"
		],
		"responses": [
			"好呀，很高興你願意聽。",
			"謝謝你聽我說。",
			"好的，我們改日再聊。"
		]
	}
}
static var _definitions: Dictionary = {}

static func reply_definition(reply_id: String, locale: String = "en") -> Dictionary:
	if locale not in LOCALES: return _fail("ordinary_locale_unavailable")
	var loaded := _load_registry()
	if not loaded.ok: return loaded
	if not _definitions.has(reply_id): return _fail("ordinary_reply_unregistered")
	var result: Dictionary = _definitions[reply_id].duplicate(true)
	var ordinal: int = result.choice_ordinal
	result.erase("choice_ordinal")
	result["locale"] = locale
	result["text"] = str(COPY[locale].choices[ordinal])
	result["incoming_text"] = str(COPY[locale].incoming)
	result["response_text"] = str(COPY[locale].responses[ordinal])
	return _ok(result)

static func available(state: Dictionary, day: int, friend_id: String, locale: String = "en") -> Dictionary:
	var expected_friend := CALENDAR.ordinary_friend(day)
	if expected_friend.is_empty() or expected_friend != friend_id: return _ok({})
	var loaded := _load_registry()
	if not loaded.ok: return loaded
	var choices: Array = []
	for id: String in _definitions:
		if _definitions[id].day != day: continue
		var definition := reply_definition(id, locale)
		if not definition.ok: return definition
		for receipt: Variant in state.get("transaction_receipts", {}).values():
			if receipt is Dictionary and receipt.get("kind") == "ordinary_reply" and receipt.get("entry_id") == definition.value.entry_id:
				return _ok({})
		choices.append(definition.value)
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.reply_id < b.reply_id)
	if choices.size() != 3: return _fail("ordinary_registry_incomplete")
	return _ok({"entry_id": choices[0].entry_id, "friend_id": friend_id, "day": day,
		"incoming_text": choices[0].incoming_text, "choices": choices})

static func prepare_reply(state: Dictionary, day: int, reply_id: String, locale: String,
		command_id: String, issuer_receipt: Dictionary, rendered_line: Dictionary) -> Dictionary:
	var definition := reply_definition(reply_id, locale)
	if not definition.ok: return definition
	var row: Dictionary = definition.value
	if row.day != day: return _fail("ordinary_reply_wrong_day")
	if not _valid_proof(command_id, issuer_receipt): return _fail("ordinary_command_unverified")
	var expected := {"view_token": command_id, "line_id": row.line_id, "text": row.text}
	if rendered_line != expected: return _fail("ordinary_line_not_witnessed")
	var prior: Variant = state.get("transaction_receipts", {}).get(command_id)
	if prior != null:
		if not prior is Dictionary or prior.get("kind") != "ordinary_reply" or prior.get("reply_id") != reply_id \
				or prior.get("locale") != locale or prior.get("command_issuer_receipt") != issuer_receipt or prior.get("rendered_line") != rendered_line:
			return _fail("ordinary_reply_conflict")
		var validated := validate_state(state)
		return _candidate(state.duplicate(true), [], prior.duplicate(true)) if validated.ok else validated
	var choices := available(state, day, row.friend_id, locale)
	if not choices.ok: return choices
	if choices.value.is_empty(): return _fail("ordinary_reply_already_chosen")
	var safe := safe_snapshot(row.text)
	if not safe.ok: return safe
	var candidate: Dictionary = state.duplicate(true)
	var sequence: int = int(candidate.next_sequence)
	var sequences: Array = [sequence, sequence + 1, sequence + 2]
	var receipt := {"kind": "ordinary_reply", "transaction_id": command_id,
		"command_issuer_receipt": issuer_receipt.duplicate(true), "day": day,
		"friend_id": row.friend_id, "entry_id": row.entry_id, "reply_id": reply_id,
		"witnessed_line_id": row.line_id, "content_version": row.content_version, "locale": locale,
		"plain_text_snapshot": safe.value, "echo_id": row.echo_id,
		"presentation_atom_id": row.presentation_atom_id, "rendered_line": rendered_line.duplicate(true),
		"message_ids": row.message_ids.duplicate(), "message_sequences": sequences}
	var batch: Array = []
	for index: int in range(3):
		var message := {"message_id": row.message_ids[index], "type": MESSAGE_KINDS[index],
			"variant": "default", "visibility": "visible", "target_day": day,
			"sequence": sequences[index], "transaction_id": command_id + ":message:" + str(index),
			"parameters": {"reply_transaction_id": command_id}}
		candidate.messages[row.friend_id].append(message)
		batch.append(message.duplicate(true))
	candidate.next_sequence = sequence + 3
	candidate.read_watermarks[row.friend_id] = sequence + 2
	candidate.transaction_receipts[command_id] = receipt
	var valid := validate_state(candidate)
	return _candidate(candidate, batch, receipt.duplicate(true)) if valid.ok else valid

static func pending_echoes_oldest_first(state: Dictionary) -> Array[Dictionary]:
	var satisfied := {}
	for receipt: Variant in state.get("transaction_receipts", {}).values():
		if receipt is Dictionary and receipt.get("kind") == "ordinary_echo_presented":
			satisfied[receipt.get("echo_id", "")] = true
	var pending: Array[Dictionary] = []
	for receipt: Variant in state.get("transaction_receipts", {}).values():
		if not receipt is Dictionary or receipt.get("kind") != "ordinary_reply" or satisfied.has(receipt.get("echo_id")): continue
		var row := {"reply_transaction_id": receipt.transaction_id}
		for key: String in ["day", "friend_id", "entry_id", "reply_id", "echo_id", "presentation_atom_id", "witnessed_line_id", "plain_text_snapshot", "content_version", "locale"]:
			row[key] = receipt[key]
		pending.append(row)
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.day) < int(b.day))
	return pending.duplicate(true)

static func prepare_echo_presented(state: Dictionary, echo_id: String, atom_id: String,
		command_id: String, issuer_receipt: Dictionary, presentation_receipt: Dictionary) -> Dictionary:
	if not _valid_proof(command_id, issuer_receipt): return _fail("ordinary_command_unverified")
	var expected := {"entry_id": "echo.fallback.day7", "view_token": command_id,
		"echo_id": echo_id, "presentation_atom_id": atom_id}
	if presentation_receipt != expected: return _fail("ordinary_echo_not_presented")
	var prior: Variant = state.get("transaction_receipts", {}).get(command_id)
	if prior != null:
		if not prior is Dictionary or prior.get("kind") != "ordinary_echo_presented" \
				or prior.get("echo_id") != echo_id or prior.get("presentation_atom_id") != atom_id \
				or prior.get("command_issuer_receipt") != issuer_receipt or prior.get("presentation_receipt") != expected:
			return _fail("ordinary_echo_receipt_conflict")
		var validated := validate_state(state)
		return _candidate(state.duplicate(true), [], prior.duplicate(true)) if validated.ok else validated
	var pending := pending_echoes_oldest_first(state)
	if pending.is_empty() or pending[0].echo_id != echo_id or pending[0].presentation_atom_id != atom_id:
		return _fail("ordinary_echo_out_of_order")
	var receipt := {"kind": "ordinary_echo_presented", "transaction_id": command_id,
		"command_issuer_receipt": issuer_receipt.duplicate(true), "echo_id": echo_id,
		"presentation_atom_id": atom_id, "reply_transaction_id": pending[0].reply_transaction_id,
		"presentation_receipt": expected}
	var candidate := state.duplicate(true)
	candidate.transaction_receipts[command_id] = receipt
	var valid := validate_state(candidate)
	return _candidate(candidate, [], receipt.duplicate(true)) if valid.ok else valid

static func validate_receipt(receipt: Dictionary) -> Dictionary:
	var kind: String = str(receipt.get("kind", ""))
	if kind == "ordinary_reply":
		if not _exact(receipt, REPLY_KEYS): return _fail("invalid_ordinary_reply_receipt")
		var definition := reply_definition(str(receipt.reply_id), str(receipt.locale))
		if not definition.ok: return definition
		var row: Dictionary = definition.value
		var safe := safe_snapshot(row.text)
		if not safe.ok: return safe
		for key: String in ["day", "friend_id", "entry_id", "reply_id", "content_version", "locale", "echo_id", "presentation_atom_id", "message_ids"]:
			if typeof(receipt[key]) != typeof(row[key]) or receipt[key] != row[key]: return _fail("invalid_ordinary_reply_binding")
		if receipt.witnessed_line_id != row.line_id or receipt.plain_text_snapshot != safe.value \
				or receipt.rendered_line != {"view_token": receipt.transaction_id, "line_id": row.line_id, "text": row.text}:
			return _fail("invalid_ordinary_reply_binding")
		if not receipt.message_sequences is Array or receipt.message_sequences.size() != 3: return _fail("invalid_ordinary_reply_sequences")
		for index: int in range(3):
			if typeof(receipt.message_sequences[index]) != TYPE_INT or int(receipt.message_sequences[index]) < 1 \
					or int(receipt.message_sequences[index]) != int(receipt.message_sequences[0]) + index:
				return _fail("invalid_ordinary_reply_sequences")
	elif kind == "ordinary_echo_presented":
		if not _exact(receipt, ECHO_KEYS): return _fail("invalid_ordinary_echo_receipt")
		if not receipt.reply_transaction_id is String or receipt.reply_transaction_id.is_empty() \
				or not receipt.echo_id is String or not receipt.presentation_atom_id is String:
			return _fail("invalid_ordinary_echo_binding")
		if receipt.presentation_receipt != {"entry_id": "echo.fallback.day7", "view_token": receipt.transaction_id,
			"echo_id": receipt.echo_id, "presentation_atom_id": receipt.presentation_atom_id}:
			return _fail("invalid_ordinary_echo_binding")
	else: return _fail("invalid_ordinary_receipt_kind")
	if not receipt.transaction_id is String or not receipt.command_issuer_receipt is Dictionary \
			or not _valid_proof(receipt.transaction_id, receipt.command_issuer_receipt):
		return _fail("ordinary_command_unverified")
	return _ok({})

## This narrow validator ignores existing legacy Contact fields, but never ignores our rows.
static func validate_state(state: Dictionary) -> Dictionary:
	var ledger: Variant = state.get("transaction_receipts", {})
	if not ledger is Dictionary: return _fail("invalid_ordinary_receipt_index")
	var chosen := {}
	var echoes := {}
	var claimed := {}
	for key: Variant in ledger:
		var receipt: Variant = ledger[key]
		if not receipt is Dictionary or receipt.get("kind") not in RECEIPT_KINDS: continue
		if not key is String or receipt.get("transaction_id") != key: return _fail("invalid_ordinary_receipt_identity")
		var valid := validate_receipt(receipt)
		if not valid.ok: return valid
		if receipt.kind == "ordinary_reply":
			if chosen.has(receipt.entry_id): return _fail("ordinary_reply_duplicate")
			chosen[receipt.entry_id] = true
			var message_index: Variant = state.get("messages", {})
			if not message_index is Dictionary: return _fail("invalid_ordinary_messages")
			var messages: Variant = message_index.get(receipt.friend_id, [])
			if not messages is Array: return _fail("invalid_ordinary_messages")
			for index: int in range(3):
				var expected := {"message_id": receipt.message_ids[index], "type": MESSAGE_KINDS[index],
					"variant": "default", "visibility": "visible", "target_day": receipt.day,
					"sequence": receipt.message_sequences[index], "transaction_id": key + ":message:" + str(index),
					"parameters": {"reply_transaction_id": key}}
				var count := 0
				for message: Variant in messages:
					if message == expected: count += 1
				if count != 1: return _fail("ordinary_history_unowned")
				claimed[expected.transaction_id] = expected
		else:
			var source: Variant = ledger.get(receipt.reply_transaction_id)
			if not source is Dictionary or source.get("kind") != "ordinary_reply" \
					or source.get("echo_id") != receipt.echo_id or source.get("presentation_atom_id") != receipt.presentation_atom_id:
				return _fail("ordinary_echo_source_absent")
			if echoes.has(receipt.echo_id): return _fail("ordinary_echo_duplicate")
			echoes[receipt.echo_id] = true
	var ordered_replies: Array = []
	for receipt: Variant in ledger.values():
		if receipt is Dictionary and receipt.get("kind") == "ordinary_reply": ordered_replies.append(receipt)
	ordered_replies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.day) < int(b.day))
	var awaiting := false
	for reply: Dictionary in ordered_replies:
		if not echoes.has(reply.echo_id): awaiting = true
		elif awaiting: return _fail("ordinary_echo_out_of_order")
	var message_index: Variant = state.get("messages", {})
	if not message_index is Dictionary:
		return _ok({}) if ordered_replies.is_empty() else _fail("invalid_ordinary_messages")
	for messages: Variant in message_index.values():
		if not messages is Array: continue
		for message: Variant in messages:
			if message is Dictionary and message.get("type") in MESSAGE_KINDS:
				if claimed.get(message.get("transaction_id")) != message: return _fail("ordinary_history_unowned")
	return _ok({})

static func resolve_history_message(state: Dictionary, message: Dictionary, locale: String) -> Dictionary:
	var source: Variant = state.get("transaction_receipts", {}).get(message.get("parameters", {}).get("reply_transaction_id"))
	if not source is Dictionary or source.get("kind") != "ordinary_reply": return _fail("ordinary_history_unowned")
	var checked := validate_receipt(source)
	if not checked.ok: return checked
	var row := reply_definition(source.reply_id, locale)
	if not row.ok: return row
	var index: int = MESSAGE_KINDS.find(str(message.get("type", "")))
	if index < 0 or source.message_ids[index] != message.get("message_id"): return _fail("ordinary_history_unowned")
	var text: String = [row.value.incoming_text, row.value.text, row.value.response_text][index]
	# The chosen primary-language witness remains the exact original versioned literal.
	if index == 1 and locale == source.locale: text = str(source.rendered_line.text)
	return _ok({"id": message.message_id, "outgoing": index == 1, "text": text})

static func safe_snapshot(text: String) -> Dictionary:
	var normalized := text.replace("\r\n", "\n").replace("\r", "\n")
	if normalized.is_empty(): return _fail("ordinary_snapshot_empty")
	for index: int in range(normalized.length()):
		var code: int = normalized.unicode_at(index)
		if (code < 32 and code != 10) or code == 127: return _fail("ordinary_snapshot_control")
	var escaped := normalized.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("[", "&#91;").replace("]", "&#93;")
	if escaped.to_utf8_buffer().size() > 512: return _fail("ordinary_snapshot_too_long")
	return {"ok": true, "value": escaped}

static func _load_registry() -> Dictionary:
	if not _definitions.is_empty(): return _ok({})
	var loaded: Dictionary = MANIFEST.load_ids_default()
	if not loaded.get("ok", false): return loaded
	var registry_check: Dictionary = MANIFEST.validate_ids_document(loaded.value)
	if not registry_check.ok: return registry_check
	var built := {}
	var counts := {}
	for reply: Dictionary in loaded.value.reply_ids:
		var entry: Dictionary = SIGNATURE.entry_record(str(reply.owning_entry_id))
		if not entry.ok or entry.value.role != "ordinary_message": return _fail("ordinary_registry_invalid")
		var day: int = int(entry.value.day)
		var friend_id: String = str(reply.owning_entry_id).get_slice(".", 2)
		if CALENDAR.ordinary_friend(day) != friend_id: return _fail("ordinary_registry_invalid")
		var choice: String = str(reply.reply_id).get_slice(".", 4)
		var ordinal: int = ["a", "b", "c"].find(choice)
		if ordinal < 0: return _fail("ordinary_registry_invalid")
		var line_id := ""
		var atom: Dictionary = {}
		for line: Dictionary in loaded.value.reply_lines:
			if line.owning_entry_id == reply.owning_entry_id and str(line.line_id).ends_with(".reply." + choice):
				if not line_id.is_empty(): return _fail("ordinary_registry_invalid")
				line_id = line.line_id
		for candidate: Dictionary in loaded.value.atoms:
			if candidate.owning_entry_id == reply.owning_entry_id and candidate.kind == "echo_fallback" \
					and str(candidate.atom_id).ends_with(".reply." + choice + ".fallback.day7"):
				if not atom.is_empty(): return _fail("ordinary_registry_invalid")
				atom = candidate
		if line_id.is_empty() or atom.is_empty(): return _fail("ordinary_registry_incomplete")
		built[reply.reply_id] = {"entry_id": reply.owning_entry_id, "friend_id": friend_id, "day": day,
			"reply_id": reply.reply_id, "line_id": line_id, "echo_id": atom.echo_id,
			"presentation_atom_id": atom.atom_id, "choice_ordinal": ordinal,
			"content_version": int(entry.value.content_version),
			"message_ids": [reply.owning_entry_id, line_id, str(reply.owning_entry_id) + ".response." + choice]}
		counts[day] = int(counts.get(day, 0)) + 1
	if built.size() != 18 or counts.size() != 6: return _fail("ordinary_registry_incomplete")
	for count: int in counts.values():
		if count != 3: return _fail("ordinary_registry_incomplete")
	_definitions = built
	return _ok({})

static func _valid_proof(command_id: String, proof: Dictionary) -> bool:
	if command_id.is_empty() or not _exact(proof, PROOF_KEYS) or proof.get("purpose") != "transaction_id" \
			or proof.get("token") != command_id or not proof.get("namespace") is String \
			or typeof(proof.get("counter")) != TYPE_INT or int(proof.counter) < 1: return false
	if str(proof.namespace).length() != 64: return false
	for character: String in str(proof.namespace):
		if character not in "0123456789abcdef": return false
	return proof == ROOT._mint_receipt(proof.namespace, proof.counter, "transaction_id", null)

static func _exact(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key: String in keys:
		if not value.has(key): return false
	return true

static func _candidate(state: Dictionary, batch: Array, receipt: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"candidate": state, "message_batch": batch}, "receipt": receipt}

static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}

static func _fail(code: String) -> Dictionary:
	return {"ok": false, "code": StringName(code), "message": ""}
