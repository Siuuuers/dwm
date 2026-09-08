class_name PairDeckDraw
extends RefCounted

## A receipt proves the exact unseen-first pool and rejection-sampled choice.
## Randomness is supplied by the application; validation consumes no RNG.
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const FORMS: Array[String] = ["ambiguous_dark", "ambiguous_sweet", "love_dark", "love_sweet"]
const RULESET_ID := "pair.deck.2026-09-08.v1"
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
