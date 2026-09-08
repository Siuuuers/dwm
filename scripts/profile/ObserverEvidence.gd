extends RefCounted

## Receipts prove the finite provisional presentation grammar, never board mastery.
## The admitted physical owner proves rendering and window custody before writing here.
const RULES := preload("res://scripts/domain/relationship/ProvisionalProgressionRules.gd")
const COMMON := ["comparison_key", "entry_id", "kind", "line_id", "playback_token", "presentation_atom_id", "receipt_id", "run_id"]

static func validate(ledger: Variant) -> Dictionary:
	if not ledger is Dictionary: return _fail("Observer evidence must be an object")
	for id: Variant in ledger:
		if not id is String or not ledger[id] is Dictionary: return _fail("Invalid receipt identity")
		var receipt: Dictionary = ledger[id]
		var checked := validate_receipt(receipt)
		if not checked.ok: return checked
		if id != receipt.receipt_id: return _fail("Receipt key mismatch")
		if receipt.kind == "verification":
			var source: Variant = ledger.get(receipt.capture_receipt_id)
			if not source is Dictionary or source.get("kind") != "capture" \
					or source.run_id == receipt.run_id or source.comparison_key != receipt.comparison_key:
				return _fail("Verification requires a matching capture from another run")
	return {"ok": true, "value": ledger.duplicate(true)}

static func validate_receipt(receipt: Dictionary) -> Dictionary:
	var kind: String = str(receipt.get("kind", ""))
	if kind not in ["capture", "verification", "restraint"]: return _fail("Unknown Observer grammar")
	var keys: Array = COMMON.duplicate()
	if kind == "capture": keys.append("text_variant")
	elif kind == "verification": keys.append("capture_receipt_id")
	else: keys.append_array(["duration_ms", "intervened", "window_id"])
	keys.sort()
	var actual: Array = receipt.keys()
	actual.sort()
	if keys != actual: return _fail("Unexpected Observer receipt fields")
	for key: String in COMMON:
		if not receipt[key] is String or (receipt[key].is_empty() and key != "comparison_key"):
			return _fail("Observer receipt identities must be Strings")
	var scope := "lavinia" if kind == "restraint" else "priscilla"
	var atom: Dictionary = RULES.OBSERVER_ATOMS[scope]
	for key: String in ["entry_id", "line_id", "presentation_atom_id", "comparison_key"]:
		if receipt[key] != atom[key]: return _fail("Observer source is not registered")
	if kind == "capture" and receipt.text_variant != "original": return _fail("Unknown captured line variant")
	if kind == "verification" and (not receipt.capture_receipt_id is String or receipt.capture_receipt_id.is_empty()):
		return _fail("Verification requires a capture receipt")
	if kind == "restraint":
		if not receipt.window_id is String or receipt.window_id.is_empty() \
				or typeof(receipt.duration_ms) != TYPE_INT or receipt.duration_ms != RULES.OBSERVER_WITHHOLDING_MS \
				or typeof(receipt.intervened) != TYPE_BOOL or receipt.intervened:
			return _fail("Restraint requires its completed unintervened window")
	return {"ok": true, "value": receipt.duplicate(true)}

static func prepare(ledger: Dictionary, receipt: Dictionary) -> Dictionary:
	var checked := validate_receipt(receipt)
	if not checked.ok: return checked
	var id: String = receipt.receipt_id
	if ledger.has(id):
		if ledger[id] != receipt: return _fail("Observer receipt conflict")
		return {"ok": true, "value": ledger.duplicate(true), "already_recorded": true}
	var candidate := ledger.duplicate(true)
	candidate[id] = receipt.duplicate(true)
	var valid := validate(candidate)
	if not valid.ok: return valid
	valid["already_recorded"] = false
	return valid

static func evidence(ledger: Dictionary) -> Dictionary:
	var result := {"priscilla": false, "lavinia": false}
	for receipt: Dictionary in ledger.values():
		if receipt.kind == "verification": result["priscilla"] = true
		elif receipt.kind == "restraint": result["lavinia"] = true
	return result

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "code": &"invalid_observer_evidence", "message": message}
