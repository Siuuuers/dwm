class_name DatingRehearsalOwner
extends RefCounted

## One detached production Dating owner, with no canonical completion connection or save writer.
## Signatures do not contain historical latent stats. Practice copies current hidden inputs and
## freezes the reached display fields; post outcomes are hypothetical, not historical restoration.
signal finished(receipt: Dictionary)

const ADMISSION := preload("res://scripts/domain/narrative/DatingRehearsalAdmission.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const GAME := preload("res://autoload/GameState.gd")
const PHYSICAL := preload("res://scripts/application/run/DatingPhysicalOwner.gd")
const GENERATION := preload("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd")
const NAMESPACE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const ROOT := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PROGRESSION := preload("res://scripts/domain/relationship/ProvisionalProgressionRules.gd")

## Volatile private namespace. It never holds or advances the canonical issuer root.
class PrivateIdentities extends RefCounted:
	var namespace_value: String
	var counter := 0
	func _init(value: String) -> void: namespace_value = value
	func issue(purpose: StringName) -> Dictionary:
		if str(purpose) not in ["transaction_id", "board_id", "placement_nonce", "debug_nonce", "explosion_nonce"]:
			return {"ok": false, "code": &"rehearsal_capability_denied"}
		counter += 1
		var receipt: Dictionary = ROOT._mint_receipt(namespace_value, counter, str(purpose), null)
		return {"ok": true, "value": {"token": receipt.token, "issuer_receipt": receipt.duplicate(true)},
			"receipt": receipt.duplicate(true)}

## The physical owner gets no reference to canonical Profile; all progression commands refuse.
class DeniedProfile extends RefCounted:
	func record_pair_form_witness(_form: String, _receipt: String) -> Dictionary:
		return {"ok": false, "code": &"rehearsal_capability_denied"}

var _profile: Object
var _source_game: Object
var _sandbox: Node
var _physical: RefCounted
var _identities: RefCounted
var _command: Dictionary = {}
var _source: Dictionary = {}
var _variables: Dictionary = {}
var _finished := false

func configure(profile: Object, canonical_game: Object) -> Dictionary:
	if not is_instance_valid(profile) or not is_instance_valid(canonical_game): return _fail("invalid_rehearsal_dependency")
	for method: String in ["get_reached_presentations", "has_completed_ending", "mark_line_visited", "is_line_visited"]:
		if not profile.has_method(method): return _fail("invalid_rehearsal_dependency")
	if not canonical_game.has_method("capture_run_snapshot_input"): return _fail("invalid_rehearsal_dependency")
	if _profile != null and [_profile, _source_game] != [profile, canonical_game]:
		return _fail("rehearsal_already_configured")
	_profile = profile
	_source_game = canonical_game
	return _ok({})

func begin(reached_record: Dictionary, dialogic_variables: Dictionary = {}) -> Dictionary:
	if _profile == null: return _fail("rehearsal_unconfigured")
	if not _command.is_empty(): return _fail("rehearsal_already_active")
	var reached: Dictionary = _profile.get_reached_presentations()
	if not reached.get("ok", false): return reached
	var admitted: Dictionary = ADMISSION.prepare(reached_record, reached.value.records, _profile.has_completed_ending())
	if not admitted.ok: return admitted
	if not JSON_WRITER.stringify(dialogic_variables).get("ok", false): return _fail("invalid_rehearsal_variables")
	var namespace_result: Dictionary = NAMESPACE.new().generate_namespace()
	if not namespace_result.ok: return namespace_result
	_identities = PrivateIdentities.new(namespace_result.value)
	var copied: Dictionary = _source_game.capture_run_snapshot_input().duplicate(true)
	_sandbox = GAME.new() # Constructor is pure; reset_game() would consume the global RNG.
	_sandbox._apply_gameplay_silent(copied.gameplay)
	_sandbox.dating_route_state = copied.dating.duplicate(true)
	_sandbox.contacts = copied.contacts.duplicate(true)
	_sandbox._narrative_variables = copied.gameplay.get("narrative_variables", {}).duplicate(true)
	_sandbox.route_context = {} # Never import canonical board, observer, branch or capability state.
	_sandbox._command_receipts = {}
	_sandbox._applied_effect_transaction_ids = []
	_sandbox._applied_variable_transaction_ids = []
	_source = admitted.value.duplicate(true)
	_variables = dialogic_variables.duplicate(true)
	var fields: Dictionary = _source.signature.fields
	if _source.context.kind == "solo":
		var friend_id: String = _source.context.participants[0]
		var relationship: Dictionary = _sandbox.dating_route_state.get(friend_id, {}).duplicate(true)
		relationship["relationship_state"] = fields.tier
		relationship["provisional_receipts"] = {}
		relationship["progression_event_ids"] = []
		_sandbox.dating_route_state[friend_id] = relationship
		_sandbox.friend_attitude[friend_id] = fields.attitude
	else:
		var pair: Dictionary = _sandbox.inter_friend_route_state.get("priscilla_lavinia", {}).duplicate(true)
		pair["frozen_form"] = fields.pair_form
		pair["provisional_receipts"] = {}
		_sandbox.inter_friend_route_state["priscilla_lavinia"] = pair
	var transaction: Dictionary = _identities.issue(&"transaction_id")
	var material := {"execution_mode": "rehearsal", "signature_id": _source.signature_id,
		"completion_transaction_id": transaction.value.token, "context": _source.context.duplicate(true)}
	var encoded: Dictionary = JSON_WRITER.stringify(material)
	_command = material.duplicate(true)
	_command["command_sha256"] = str(encoded.value).sha256_text()
	_physical = PHYSICAL.new()
	var configured: Dictionary = _physical.configure(_identities, _sandbox, DeniedProfile.new(), GENERATION.new())
	if not configured.ok:
		close()
		return configured
	var begun: Dictionary = _physical.begin_physical(_command)
	if not begun.ok:
		close()
		return begun
	_command["physical_token"] = begun.value.physical_token
	_finished = false
	return _ok({"presentation_command": _command.duplicate(true), "view": pull_physical(_command).value,
		"signature": _source.signature.duplicate(true)})

func pull_physical(command: Dictionary) -> Dictionary:
	if not _matches(command): return _fail("rehearsal_identity_mismatch")
	return _physical.pull_physical(str(_command.physical_token))

## Minimal practice entries are return-only or exact result routes into empty leaves.
## Prove the entire source route and selected leaf are empty; prose needs private playback.
## This path neither invokes canonical Dialogic nor grants a witnessed line/signature.
func begin_narrative_phase(command: Dictionary, _retry: bool = false) -> Dictionary:
	if not _matches(command): return _fail("rehearsal_identity_mismatch")
	var pulled := pull_physical(command)
	if not pulled.get("ok", false): return pulled
	var phase := str(pulled.value.phase)
	if phase not in ["pre_challenge", "post_challenge"]: return _fail("rehearsal_narrative_phase_unavailable")
	if command.context.kind == "twofriends_if_deferred" and phase == "post_challenge" \
			and pulled.value.outcome == "exploded":
		return _ok({"status": "completed", "reason": "pair_explosion_cutoff"})
	var entry_id := str(_source.signature.entry_id).trim_suffix(".pre_challenge") + "." + phase
	var located: Dictionary = preload("res://scripts/data/DialogicTimelineCatalog.gd").get_entry(entry_id, "en")
	if not located.get("ok", false): return located
	if preload("res://autoload/DialogicBridge.gd").is_return_only_entry(
			str(located.value.path), str(located.value.label)):
		return _ok({"status": "completed", "entry_id": entry_id, "reason": "empty_authored_entry"})
	if phase == "post_challenge" and _is_empty_result_route(
		FileAccess.get_file_as_string(str(located.value.path)), str(located.value.label), str(pulled.value.outcome)):
		return _ok({"status": "completed", "entry_id": entry_id,
			"reason": "empty_authored_result_route", "result_label": str(located.value.label) + "." + str(pulled.value.outcome)})
	return _fail("rehearsal_authored_playback_unavailable")


## A deliberately narrow proof, not a Dialogic interpreter. Only the complete
## approved result dispatch plus an empty selected leaf may be skipped privately.
static func _is_empty_result_route(source: String, label: String, outcome: String) -> bool:
	if label.is_empty() or outcome not in ["exploded", "perfect", "cleared"]: return false
	var bodies := {}
	var current_label := ""
	for raw_line: String in source.split("\n"):
		var line := raw_line.strip_edges(false, true)
		if line.strip_edges().is_empty() or line.strip_edges().begins_with("#"): continue
		if line.begins_with("label "):
			current_label = line.trim_prefix("label ")
			if bodies.has(current_label): return false
			bodies[current_label] = []
		elif not current_label.is_empty():
			bodies[current_label].append(line)
	var expected: Array[String] = [
		'if {Frozen.board_result} == "exploded":', "\tjump " + label + ".exploded",
		'elif {Frozen.board_result} == "perfect":', "\tjump " + label + ".perfect",
		'elif {Frozen.board_result} == "cleared":', "\tjump " + label + ".cleared", "return"]
	return bodies.get(label) == expected and bodies.get(label + "." + outcome) == ["return"]

func pull_narrative_phase(command: Dictionary) -> Dictionary:
	return begin_narrative_phase(command)

func dispatch_physical(command: Dictionary, action: String, index: int, revision: int) -> Dictionary:
	if not _matches(command): return _fail("rehearsal_identity_mismatch")
	var result: Dictionary = _physical.dispatch_physical(str(_command.physical_token), action, index, revision)
	if not result.get("ok", false): return result
	var current: Dictionary = _physical.pull_physical(str(_command.physical_token))
	if current.ok and current.value.phase == "completed" and not _finished:
		_finished = true
		finished.emit({"execution_mode": "rehearsal", "signature_id": _source.signature_id,
			"physical_token": _command.physical_token, "outcome": current.value.outcome})
	return result

## Scene compatibility does not provide a way to manufacture a terminal board.
func complete(_request: Dictionary) -> Dictionary:
	return _fail("rehearsal_capability_denied")

func capture_presentation(command: Dictionary) -> Dictionary:
	if not _matches(command): return _fail("rehearsal_identity_mismatch")
	var record: Dictionary = _sandbox.capture_dating_challenge_state().value
	var signature: Dictionary = _source.signature.duplicate(true)
	if record.phase in ["post_challenge", "completed"]:
		var fields: Dictionary = signature.fields.duplicate(true)
		if record.host == "canonical_solo":
			var friend_id: String = record.context.participants[0]
			var state: Dictionary = _sandbox.dating_route_state.get(friend_id, {})
			fields["tier"] = str(state.get("relationship_state", "friend"))
			fields["tone"] = "dark" if int(state.get("dark_points", 0)) >= PROGRESSION.DARK_TONE_THRESHOLD else "sweet"
			fields["attitude"] = str(_sandbox.friend_attitude.get(friend_id, ""))
			fields["promotion_result"] = fields.tier if fields.tier != _source.signature.fields.tier else "none"
		var projected: Dictionary = SIGNATURE.from_dating_post_challenge(record, fields)
		if not projected.ok: return projected
		signature = projected.value.signature
	elif record.phase != "pre_challenge":
		return _fail("rehearsal_presentation_unavailable")
	return _ok({"entry_id": signature.entry_id, "signature": signature,
		"context": record.context.duplicate(true), "variables": _variables.duplicate(true),
		"execution_mode": "rehearsal"})

func record_visited_line(command: Dictionary, line_id: String) -> Dictionary:
	var presentation: Dictionary = capture_presentation(command)
	if not presentation.ok: return presentation
	var entry: Dictionary = SIGNATURE.entry_record(presentation.value.entry_id).value
	if not line_id.begins_with(str(entry.line_namespace) + "."):
		return _fail("rehearsal_line_outside_presentation")
	# Called only by the physical line witness. Profile still validates the actual line registry.
	return _profile.mark_line_visited(line_id)

func is_line_visited(line_id: String) -> bool:
	return _profile != null and _profile.is_line_visited(line_id)

func apply_variables(command: Dictionary, variables: Dictionary) -> Dictionary:
	if not _matches(command): return _fail("rehearsal_identity_mismatch")
	if not JSON_WRITER.stringify(variables).get("ok", false): return _fail("invalid_rehearsal_variables")
	_variables = variables.duplicate(true)
	return _ok({})

func execute_command(_kind: String, _payload: Dictionary = {}) -> Dictionary:
	return _fail("rehearsal_capability_denied")

func close() -> Dictionary:
	_physical = null
	_identities = null
	if is_instance_valid(_sandbox): _sandbox.free()
	_sandbox = null
	_command = {}
	_source = {}
	_variables = {}
	_finished = false
	return _ok({})

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_sandbox): _sandbox.free()

func _matches(command: Dictionary) -> bool:
	return not _command.is_empty() and command == _command and is_instance_valid(_sandbox)

static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "value": value}

static func _fail(code: String) -> Dictionary:
	return {"ok": false, "code": StringName(code), "message": ""}

