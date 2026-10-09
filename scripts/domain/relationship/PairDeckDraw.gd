class_name PairDeckDraw
extends RefCounted

## A receipt proves the exact unseen-first pool and rejection-sampled choice.
## Randomness is supplied by the application; validation consumes no RNG.
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const FORMS: Array[String] = ["ambiguous_dark", "ambiguous_sweet", "love_dark", "love_sweet"]
const RULESET_ID := "pair.deck.2026-09-08.v1"
const SCENE_RULESET_ID := "scene.new_run.alternating.v1"
const SCENE_FORMS := ["sweet", "dark"]
const SCENE_KEYS := ["creation_transaction_id", "form", "predecessor_assignment_sha256", "predecessor_run_id", "rng_nonce", "ruleset_id", "selection_kind"]
const NONCE_RANGE := 4294967296
const KEYS: Array[String] = ["form", "rng_nonce", "ruleset_id", "selection_kind",
	"witness_fingerprint", "witnessed_forms"]

static func build_draw(witnessed_forms: Array, rng_nonce: int) -> Dictionary:
	var normalized := _witnesses(witnessed_forms)
	if not normalized.ok: return normalized
	var witnessed: Array = normalized.value
	var pool: Array[String] = []
	for form: String in FORMS:
		if form not in witnessed: pool.append(form)
	if pool.is_empty(): pool = FORMS.duplicate()
	if rng_nonce < 0 or rng_nonce >= NONCE_RANGE: return _fail(&"invalid_pair_draw_nonce")
	# Reject the incomplete bucket rather than biasing the three-form pool with modulo.
	if rng_nonce >= NONCE_RANGE - NONCE_RANGE % pool.size():
		return _fail(&"pair_draw_nonce_rejected")
	return _ok({"selection_kind": "draw", "form": pool[rng_nonce % pool.size()],
		"witnessed_forms": witnessed, "witness_fingerprint": _fingerprint(witnessed),
		"rng_nonce": rng_nonce, "ruleset_id": RULESET_ID})

static func build_legacy(form: String) -> Dictionary:
	if form not in FORMS: return _fail(&"invalid_pair_draw_form")
	# Historical selection inputs were not recorded. This marker preserves only the
	# established form and does not invent a witnessed set or past random draw.
	return _ok({"selection_kind": "legacy_established", "form": form,
		"witnessed_forms": [], "witness_fingerprint": _fingerprint([]),
		"rng_nonce": null, "ruleset_id": RULESET_ID})

static func validate(receipt: Variant) -> Dictionary:
	if not receipt is Dictionary: return _fail(&"invalid_pair_draw_receipt")
	if typeof(receipt.get("ruleset_id")) == TYPE_STRING and receipt.ruleset_id == SCENE_RULESET_ID: return validate_scene(receipt)
	var keys: Array = receipt.keys()
	keys.sort()
	if keys != KEYS: return _fail(&"invalid_pair_draw_receipt")
	for field: String in ["form", "ruleset_id", "selection_kind", "witness_fingerprint"]:
		if not receipt[field] is String: return _fail(&"invalid_pair_draw_receipt")
	if receipt.ruleset_id != RULESET_ID or not receipt.witnessed_forms is Array:
		return _fail(&"invalid_pair_draw_receipt")
	var expected: Dictionary
	if receipt.selection_kind == "draw":
		if typeof(receipt.rng_nonce) != TYPE_INT: return _fail(&"invalid_pair_draw_nonce")
		expected = build_draw(receipt.witnessed_forms, receipt.rng_nonce)
	elif receipt.selection_kind == "legacy_established":
		expected = build_legacy(receipt.form)
	else: return _fail(&"invalid_pair_draw_receipt")
	if not expected.ok: return expected
	if expected.value != receipt: return _fail(&"pair_draw_receipt_conflict")
	return _ok(receipt.duplicate(true))

static func _witnesses(forms: Array) -> Dictionary:
	var sorted: Array[String] = []
	for form: Variant in forms:
		if not form is String or form not in FORMS: return _fail(&"invalid_pair_draw_witnesses")
		if form not in sorted: sorted.append(form)
	sorted.sort()
	return _ok(sorted)

static func _fingerprint(forms: Array) -> String:
	return str(CANON.stringify(forms).value).sha256_text()

static func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}

## New policy uses the same immutable per-run ledger. Its chronology is the
## structurally validated predecessor chain, never Dictionary order or a counter.
## The joint New Run owner authenticates issuer identities and successful creation.
static func validate_scene(receipt: Variant) -> Dictionary:
	if not receipt is Dictionary or not _scene_keys(receipt, SCENE_KEYS): return _fail(&"invalid_scene_assignment")
	for key: String in ["ruleset_id", "form", "selection_kind", "creation_transaction_id"]:
		if not _scene_id(receipt[key]): return _fail(&"invalid_scene_assignment")
	if receipt.ruleset_id != SCENE_RULESET_ID or receipt.form not in SCENE_FORMS: return _fail(&"invalid_scene_assignment")
	if receipt.selection_kind == "initial_random":
		if not _scene_nonce(receipt.rng_nonce) or receipt.predecessor_run_id != null \
				or receipt.predecessor_assignment_sha256 != null: return _fail(&"invalid_scene_assignment")
		if receipt.form != SCENE_FORMS[receipt.rng_nonce % 2]: return _fail(&"scene_assignment_choice_conflict")
	elif receipt.selection_kind == "alternate":
		if receipt.rng_nonce != null or not _scene_id(receipt.predecessor_run_id) \
				or not _scene_hash(receipt.predecessor_assignment_sha256): return _fail(&"invalid_scene_assignment")
	else: return _fail(&"invalid_scene_assignment")
	return _ok(receipt.duplicate(true))

static func validate_ledger(ledger: Variant) -> Dictionary:
	if not ledger is Dictionary: return _fail(&"invalid_pair_draw_ledger")
	var scenes := {}
	var transactions := {}
	var legacy_count := 0
	for run_id: Variant in ledger:
		if not _scene_id(run_id): return _fail(&"invalid_pair_draw_ledger")
		var checked: Dictionary = validate(ledger[run_id])
		if not checked.ok: return checked
		if checked.value.ruleset_id != SCENE_RULESET_ID:
			legacy_count += 1
			continue
		var receipt: Dictionary = checked.value
		if transactions.has(receipt.creation_transaction_id): return _fail(&"scene_assignment_transaction_reused")
		transactions[receipt.creation_transaction_id] = run_id
		scenes[run_id] = receipt
	if scenes.is_empty(): return _ok({"tail_run_id": "", "scene_count": 0, "legacy_count": legacy_count})
	var root := ""
	var successors := {}
	for run_id: String in scenes:
		var receipt: Dictionary = scenes[run_id]
		if receipt.selection_kind == "initial_random":
			if not root.is_empty(): return _fail(&"scene_assignment_multiple_roots")
			root = run_id
			continue
		var previous: String = receipt.predecessor_run_id
		if not scenes.has(previous) or previous == run_id or successors.has(previous): return _fail(&"scene_assignment_lineage_conflict")
		var encoded: Dictionary = CANON.stringify(scenes[previous])
		if not encoded.ok or str(encoded.value).sha256_text() != receipt.predecessor_assignment_sha256 \
				or receipt.form == scenes[previous].form: return _fail(&"scene_assignment_predecessor_conflict")
		successors[previous] = run_id
	if root.is_empty(): return _fail(&"scene_assignment_cycle")
	var visited := {}
	var cursor: String = root
	while true:
		if visited.has(cursor): return _fail(&"scene_assignment_cycle")
		visited[cursor] = true
		if not successors.has(cursor): break
		cursor = successors[cursor]
	if visited.size() != scenes.size(): return _fail(&"scene_assignment_disconnected")
	return _ok({"tail_run_id": cursor, "scene_count": scenes.size(), "legacy_count": legacy_count})

## Empty ledger permits only structural initial selection. The application must
## also prove no successful legacy predecessor exists outside this delayed ledger.
static func prepare_scene_assignment(ledger: Dictionary, run_id: String, creation_transaction_id: String,
		rng_nonce: Variant = null) -> Dictionary:
	if not _scene_id(run_id) or not _scene_id(creation_transaction_id) \
			or (rng_nonce != null and not _scene_nonce(rng_nonce)): return _fail(&"invalid_scene_assignment_request")
	var checked: Dictionary = validate_ledger(ledger)
	if not checked.ok: return checked
	if ledger.has(run_id):
		var retained: Dictionary = ledger[run_id]
		if retained.ruleset_id != SCENE_RULESET_ID or retained.creation_transaction_id != creation_transaction_id:
			return _fail(&"scene_assignment_run_conflict")
		if retained.selection_kind == "alternate" and rng_nonce != null: return _fail(&"invalid_scene_assignment_nonce")
		# A controlled replacement nonce cannot reroll an already accepted first run.
		return _ok(retained.duplicate(true))
	for receipt: Dictionary in ledger.values():
		if receipt.ruleset_id == SCENE_RULESET_ID and receipt.creation_transaction_id == creation_transaction_id:
			return _fail(&"scene_assignment_transaction_reused")
	var predecessor: String = checked.value.tail_run_id
	if predecessor.is_empty():
		if checked.value.legacy_count > 0: return _fail(&"scene_assignment_legacy_boundary_required")
		if not _scene_nonce(rng_nonce): return _fail(&"invalid_scene_assignment_nonce")
		return _ok({"ruleset_id": SCENE_RULESET_ID, "form": SCENE_FORMS[rng_nonce % 2],
			"selection_kind": "initial_random", "rng_nonce": rng_nonce, "predecessor_run_id": null,
			"predecessor_assignment_sha256": null, "creation_transaction_id": creation_transaction_id})
	if rng_nonce != null: return _fail(&"invalid_scene_assignment_nonce")
	var previous: Dictionary = ledger[predecessor]
	var encoded: Dictionary = CANON.stringify(previous)
	if not encoded.ok: return encoded
	return _ok({"ruleset_id": SCENE_RULESET_ID, "form": "dark" if previous.form == "sweet" else "sweet",
		"selection_kind": "alternate", "rng_nonce": null, "predecessor_run_id": predecessor,
		"predecessor_assignment_sha256": str(encoded.value).sha256_text(), "creation_transaction_id": creation_transaction_id})

static func _scene_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key: Variant in value:
		if typeof(key) != TYPE_STRING or key not in expected: return false
	return true

static func _scene_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.strip_edges().is_empty()

static func _scene_nonce(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value < NONCE_RANGE

static func _scene_hash(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for character: String in value:
		if character not in "0123456789abcdef": return false
	return true
