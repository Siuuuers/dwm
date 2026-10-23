extends RefCounted

## Schema-exact stand-in for the Plan-02 desktop-consequence records a Schedule-Done resolution
## CONSUMES but does not own (dwm-p2r.18, DEVIATION-5).
##
## WHY THIS EXISTS. `P01.day_resolution.start` binds a board-fate receipt and `P01.hospital
## .resolution` projects a condition receipt. Both are produced by Plan 02's desktop consequence
## layer -- `DesktopBoardFatePort` and `DesktopConditionPolicyPort` -- and `dwm-p2r.9` delivered
## neither (DEVIATION-2). Plan 01 line 1303 forbids this plan from implementing desktop board fate,
## so production leaves the seam unconfigured and only tests supply these bytes. The plan authorises
## exactly that: "Tests use a schema-exact fixture until Plan 02 exists."
##
## WHAT MAKES IT HONEST. Every receipt id here is minted through a REAL issuer, so the ancestry
## Plan 01 binds is genuinely anchored rather than a fabricated String that happens to be nonblank.
## The member sets are the full Plan-02 shapes, so when the real ports land, a shape drift shows up
## as a test failure rather than passing quietly because Plan 01 only ever read `receipt_id`.
##
## NEVER A BOOTSTRAP DEPENDENCY. `ApplicationBootstrap` must not construct or configure this; the
## whole point of the seam is that production fails closed until Plan 02 fills it.

## Exact Plan-02 board-fate receipt members (sorted), per plan line 532.
const BOARD_FATE_KEYS: Array[String] = [
	"board_identity", "board_revision", "causal_day_instance", "command_id",
	"command_issuer_receipt", "fate", "receipt_id", "receipt_provenance",
	"source_action_commit_receipt_id", "source_action_commit_receipt_provenance",
]

var _issuer: Object = null
## Minted once per causal day, so a replayed resolution binds the SAME board fate and condition
## rather than a fresh one -- which is what the real ports will do.
var _board_fate: Dictionary = {}
var _condition: Dictionary = {}


func configure(identity_issuer: Object) -> Dictionary:
	if identity_issuer == null or not identity_issuer.has_method("issue"):
		return {"ok": false, "code": &"invalid_identity_issuer", "message": "", "details": {}}
	_issuer = identity_issuer
	return {"ok": true, "code": &"ok", "value": {"configured": true}, "receipt": {}}


func resolve_board_fate_receipt(request: Dictionary) -> Dictionary:
	var causal_day_instance := str(request.get("causal_day_instance", ""))
	if _board_fate.has(causal_day_instance):
		return _ok({"board_fate_receipt": (_board_fate[causal_day_instance] as Dictionary).duplicate(true)})
	var minted := _mint()
	if not minted.get("ok", false):
		return minted
	var value: Dictionary = minted["value"]
	var receipt := {
		"receipt_id": str(value["receipt_id"]),
		"receipt_provenance": (value["issuer_receipt"] as Dictionary).duplicate(true),
		"command_id": str(value["token"]),
		"command_issuer_receipt": (value["issuer_receipt"] as Dictionary).duplicate(true),
		"board_identity": "board.desktop.minesweeper",
		"board_revision": 1,
		"causal_day_instance": causal_day_instance,
		"fate": "retained",
		# EXACTLY null on the Schedule-Done consumer path (plan line 532); non-null action ancestry
		# belongs only to Plan 02's condition-driven projected-fate path.
		"source_action_commit_receipt_id": null,
		"source_action_commit_receipt_provenance": null,
	}
	var keys: Array = receipt.keys()
	keys.sort()
	if keys != BOARD_FATE_KEYS:
		return {"ok": false, "code": &"invalid_board_fate_receipt",
			"message": "the fixture drifted from the Plan-02 member set", "details": {}}
	_board_fate[causal_day_instance] = receipt
	return _ok({"board_fate_receipt": receipt.duplicate(true)})


func resolve_condition_receipt(request: Dictionary) -> Dictionary:
	var causal_day_instance := str(request.get("causal_day_instance", ""))
	if _condition.has(causal_day_instance):
		return _ok({"condition_receipt": (_condition[causal_day_instance] as Dictionary).duplicate(true)})
	var minted := _mint()
	if not minted.get("ok", false):
		return minted
	var value: Dictionary = minted["value"]
	# Plan 01 projects ONLY `receipt_id` from this record; the rest is carried so the fixture keeps
	# the shape Plan 02 will actually hand over.
	var receipt := {
		"receipt_id": str(value["receipt_id"]),
		"receipt_provenance": (value["issuer_receipt"] as Dictionary).duplicate(true),
		"causal_day_instance": causal_day_instance,
		"day": int(request.get("source_day", 0)),
		"decision": "hospital_day",
		"trigger": "motivation_exhausted",
		"danger": true,
		"condition_after": {},
		"source_receipt_ids": [],
		"sylvia_read_receipt_id": null,
	}
	_condition[causal_day_instance] = receipt
	return _ok({"condition_receipt": receipt.duplicate(true)})


func _mint() -> Dictionary:
	if _issuer == null:
		return {"ok": false, "code": &"desktop_consequence_source_unconfigured", "message": "",
			"details": {}}
	var issued: Variant = _issuer.call(&"issue", &"transaction_id")
	if typeof(issued) != TYPE_DICTIONARY or not (issued as Dictionary).get("ok", false):
		return issued if typeof(issued) == TYPE_DICTIONARY else {
			"ok": false, "code": &"desktop_consequence_identity_unavailable", "message": "",
			"details": {}}
	var value: Dictionary = (issued as Dictionary)["value"]
	var issuer_receipt: Dictionary = value["issuer_receipt"]
	return {"ok": true, "code": &"ok", "value": {
		"receipt_id": str(issuer_receipt["receipt_id"]),
		"token": str(value["token"]),
		"issuer_receipt": issuer_receipt,
	}}


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}
