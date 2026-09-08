class_name PairDeckDrawPort
extends RefCounted

## One Profile-owned run draw, shared by ordinary and condition-Hospital resolution.
## Profile may safely lead Run after a failed checkpoint; it must never be rolled back.
const DRAW := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const PAIR := "priscilla_lavinia"
var _game: Object
var _profile: Object
var _gate: Object
var _condition_owner: Object
var _nonce_source := Callable()
var _rng := RandomNumberGenerator.new()

func configure(game_state: Object, profile: Object, gate: Object,
		condition_owner: Object, nonce_source: Callable = Callable()) -> Dictionary:
	if game_state == null or not game_state.has_method("capture_dating_challenge_state"):
		return _fail(&"pair_deck_game_state_unavailable")
	if profile == null: return _fail(&"pair_deck_profile_unavailable")
	for method: String in ["get_pair_deck_draw", "get_pair_form_witnesses",
			"prepare_pair_deck_draw", "commit_pair_deck_draw", "get_dating_attempt", "get_profile_snapshot"]:
		if not profile.has_method(method): return _fail(&"pair_deck_profile_unavailable")
	if gate == null or not gate.has_method("is_lease_active"):
		return _fail(&"pair_deck_gate_unavailable")
	if condition_owner == null or not condition_owner.has_method("has_owned_causal_lease"):
		return _fail(&"pair_deck_condition_custody_unavailable")
	if _game != null:
		return _ok({}) if _game == game_state and _profile == profile and _gate == gate \
			and _condition_owner == condition_owner and _nonce_source == nonce_source \
			else _fail(&"pair_deck_already_configured")
	_game = game_state
	_profile = profile
	_gate = gate
	_condition_owner = condition_owner
	_nonce_source = nonce_source
	_rng.randomize()
	return _ok({})

func prepare_schedule(install_for_presentation: bool = false) -> Dictionary:
	if _gate == null: return _fail(&"pair_deck_unconfigured")
	# Never borrow another same-kind causal transaction.
	var acquired: Dictionary = _gate.acquire(&"causal_transaction")
	if not acquired.get("ok", false): return acquired
	var result := _prepare_owned()
	if result.get("ok", false) and install_for_presentation:
		_game.inter_friend_route_state[PAIR] = result.value.pair_state.duplicate(true)
	var released: Dictionary = _gate.release(&"causal_transaction", str(acquired.value.token))
	return result if released.get("ok", false) else released

func prepare_condition(install_for_presentation: bool = false) -> Dictionary:
	if _condition_owner == null or not bool(_condition_owner.has_owned_causal_lease(_gate)):
		return _fail(&"pair_deck_condition_custody_required")
	var result := _prepare_owned()
	if result.get("ok", false) and install_for_presentation:
		_game.inter_friend_route_state[PAIR] = result.value.pair_state.duplicate(true)
	return result

func _prepare_owned() -> Dictionary:
	var run_id: String = str(_game._run_lifecycle.to_dict().run_id)
	if run_id.is_empty(): return _fail(&"pair_deck_run_unavailable")
	var checked: Dictionary = CONTACTS.validate_state(_game.contacts)
	if not checked.get("ok", false): return checked
	var pair: Dictionary = _game.inter_friend_route_state.get(PAIR, {}).duplicate(true)
	var existing: Dictionary = _profile.get_pair_deck_draw(run_id)
	if not existing.get("ok", false): return existing
	var saved: Variant = pair.get("pair_deck_draw")
	if saved != null:
		var verified := DRAW.validate(saved)
		if not verified.ok: return verified
		if str(pair.get("frozen_form", "")) != str(saved.form):
			return _fail(&"pair_deck_saved_receipt_conflict")
	var legacy := _established_form(pair, existing.value == null)
	if not legacy.ok: return legacy
	var receipt: Dictionary
	if existing.value != null:
		var validated := DRAW.validate(existing.value)
		if not validated.ok: return validated
		receipt = validated.value
		if saved != null and saved != receipt: return _fail(&"pair_deck_saved_receipt_conflict")
	elif saved != null:
		# A deliberate full Profile reset may leave a saved run behind. Preserve its
		# exact prior draw rather than pretending its first meeting has not happened.
		receipt = saved.duplicate(true)
	elif not str(legacy.value).is_empty():
		receipt = DRAW.build_legacy(str(legacy.value)).value
	else:
		var witnessed: Dictionary = _profile.get_pair_form_witnesses()
		if not witnessed.get("ok", false): return witnessed
		var drawn := _draw(witnessed.value)
		if not drawn.ok: return drawn
		receipt = drawn.value
	if not str(legacy.value).is_empty() and str(legacy.value) != str(receipt.form):
		return _fail(&"pair_deck_established_form_conflict")
	if existing.value == null:
		var prepared: Dictionary = _profile.prepare_pair_deck_draw(run_id, receipt)
		if not prepared.get("ok", false): return prepared
		var committed: Dictionary = _profile.commit_pair_deck_draw(prepared.value)
		if not committed.get("ok", false): return committed
		var durable: Dictionary = _profile.get_pair_deck_draw(run_id)
		if not durable.get("ok", false): return durable
		if durable.value != receipt: return _fail(&"pair_deck_commit_mismatch")
	pair["frozen_form"] = str(receipt.form)
	pair["form_ruleset_id"] = str(receipt.ruleset_id)
	pair["form_selection_source"] = "profile_run_draw"
	pair["pair_deck_draw"] = receipt.duplicate(true)
	return _ok({"pair_state": pair, "draw_receipt": receipt.duplicate(true)})

func _established_form(pair: Dictionary, inspect_legacy_history: bool) -> Dictionary:
	var reached: bool = int(pair.get("date_count", 0)) > 0 or bool(pair.get("ending_eligible", false))
	for operation: Dictionary in _game.contacts.transaction_receipts.values():
		var window: Variant = operation.get("pl_window")
		if operation.get("kind") == "resolve_day_end" and int(operation.get("day", 0)) in [2, 6] \
				and window is Dictionary and bool(window.get("counts", false)):
			reached = true
	var physical: Dictionary = _game.capture_dating_challenge_state()
	if not physical.get("ok", false): return physical
	var record: Dictionary = physical.value
	var established: String = str(pair.get("frozen_form", "")) if reached else ""
	if record.get("host") == "canonical_pair":
		var portrayed: String = str(record.get("pair_form", ""))
		if portrayed not in DRAW.FORMS: return _fail(&"pair_deck_legacy_form_invalid")
		if not established.is_empty() and established != portrayed:
			return _fail(&"pair_deck_established_form_conflict")
		established = portrayed
		reached = true
	if inspect_legacy_history:
		# First-lock history is appropriate only for this immutable run-wide form. It
		# lets a selected pre-pair save retain a form the original run already reached;
		# it is never used to infer current-branch board mastery or relationship facts.
		var run_id: String = str(_game._run_lifecycle.to_dict().run_id)
		for day: int in [2, 6]:
			var prior: Dictionary = _profile.get_dating_attempt(run_id, "dating.pair.priscilla_lavinia.day%d" % day)
			if not prior.get("ok", false): return prior
			if prior.value.is_empty(): continue
			var portrayed: String = str(prior.value.record.get("pair_form", ""))
			if portrayed not in DRAW.FORMS: return _fail(&"pair_deck_legacy_form_invalid")
			if not established.is_empty() and established != portrayed:
				return _fail(&"pair_deck_established_form_conflict")
			established = portrayed
			reached = true
		# Offscreen meetings can reach the visible pair ending without any pair board.
		# Its two atomically stored Profile receipts prove the exact source run/form,
		# even when the selected save precedes both meetings. Clear Gallery keeps them.
		var profile: Dictionary = _profile.get_profile_snapshot()
		var prefix: String = "ending:%s:pair-form:" % run_id
		for witness_id: String in profile.pair_form_witness_receipts:
			if not witness_id.begins_with(prefix): continue
			var portrayed: String = str(profile.pair_form_witness_receipts[witness_id])
			if portrayed not in DRAW.FORMS or witness_id != prefix + portrayed:
				return _fail(&"pair_deck_legacy_ending_source_invalid")
			var ending_id: String = "ending.priscilla_lavinia." + ("dark" if portrayed.ends_with("_dark") else "sweet")
			var completion: Variant = profile.gallery_transaction_receipts.get("ending:%s:gallery:%s" % [run_id, ending_id])
			if not completion is Dictionary or completion.get("ending_id") != ending_id:
				return _fail(&"pair_deck_legacy_ending_source_invalid")
			if not established.is_empty() and established != portrayed:
				return _fail(&"pair_deck_established_form_conflict")
			established = portrayed
			reached = true
	if not reached: return _ok("")
	if established not in DRAW.FORMS: return _fail(&"pair_deck_legacy_form_unavailable")
	return _ok(established)

func _draw(witnessed: Array) -> Dictionary:
	# Probability of rejection is at most 1/2^32; the cap fails closed if an injected
	# source is broken rather than spinning forever. This is independent of run IDs.
	for _attempt: int in range(32):
		var nonce: Variant = _nonce_source.call() if _nonce_source.is_valid() else _rng.randi()
		if typeof(nonce) != TYPE_INT: return _fail(&"invalid_pair_draw_nonce")
		var result := DRAW.build_draw(witnessed, nonce)
		if result.get("ok", false) or result.code != &"pair_draw_nonce_rejected": return result
	return _fail(&"pair_draw_random_source_exhausted")

static func is_counted(window: Variant) -> bool:
	return window is Dictionary and bool(window.get("counts", false))

static func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}
static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
