class_name MinesweeperShopPurchaseParticipant
extends RefCounted

const _NOTE_RULES := preload("res://scripts/domain/shop/RunNotePurchaseRules.gd")

## Shop purchase participant (Plan 02 Task 7, dwm-p2r.32.7, req.shop.capabilities,
## req.desktop.cross_app_actions, req.minesweeper.safety_capabilities), amendment SS8 and 12.6.
##
## Transacts Lucky Charm / Debug Key / Supportz purchases prospectively and exactly once. Task
## boundary discipline (controller ruling): this participant's public result for a purchase is
## PENDING, never audience success. `prepare_purchase()` validates everything, acquires/retains the
## shared `causal_transaction` mutation-gate lease, and durably checkpoints the source-only
## unpromoted action candidate while live economy/board/sequence/outboxes stay byte-equal -- only
## `DesktopConsequenceState`'s own `pending` record changes. Task 8 alone freezes downstream
## participants at the distinct `action_prepared` checkpoint, repeats the causal admission CAS, and
## forward-commits. `commit(candidate)` therefore rejects unless the gate lease is active AND the
## matching pending transaction has already reached `sequence_committed` -- only then does it apply
## the real economy delta (spend currency, grant capability, or decrement the Supportz floor).
##
## COOPERATION WITH TASK 6 (sixth addendum): `DesktopConsequenceState.prepare_action_handoff()`
## creates the pending record already at stage `action_prepared` -- Task 6's own documented
## collapse of the frozen contract's two-stage `action_checkpointed -> action_prepared` pre-admission
## span into one stage. This participant does not fight that: "action_checkpointed" in the brief's
## prose is read as "the durable, unpromoted state `prepare_action_handoff()` + a checkpoint already
## produce", not a second DesktopConsequenceState stage string this task invents.
##
## quote()'s `quote_id` and the action receipt's `action_id` are both registered CHILD_KINDS members
## (`shop_quote`, `desktop_action`) -- no CHILD_KINDS extension was needed. `commit_receipt_id`/
## `commit_receipt_provenance` reuse `action_id`/`action_id_provenance` byte-for-byte (own documented
## design choice, see class doc below on `_build_action_receipt()`): Plan 02's own frozen production
## derivation table (plan02-frozen-contracts.md lines 491-499) is explicitly "the one authoritative
## production derivation table" and has no row for a distinct commit-receipt identity, so minting a
## second one would be "an unlisted semantic convention" the table's own law forbids.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _CAPABILITY_RULES := preload("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")
const _ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")

const _GATE_OWNER := &"causal_transaction"
const _ACTION_KIND := "shop_purchase"

const _REQUEST_KEYS: Array[String] = [
	"transaction_id", "transaction_issuer_receipt", "item_id", "quote_id",
	"expected_run_revision", "expected_causal_day_instance",
]
const _CAPABILITY_ITEM_IDS: Array[String] = ["lucky_charm", "debug_key"]
const _SUPPORTZ_ITEM_ID := "supportz"

const _STATE_PORT_METHODS: Array[String] = [
	"guard_external", "capture", "prepare_purchase", "commit", "rollback", "publish",
]
const _CONSEQUENCE_STATE_PORT_METHODS: Array[String] = [
	"capture", "prepare_action_handoff", "prepare_restore", "commit",
	"prepare_record_supportz_purchase", "supportz_eligibility_state",
]
const _CHECKPOINT_PORT_METHODS: Array[String] = [
	"prepare_consequence_checkpoint", "commit_consequence_checkpoint",
]

var _state_port: Object = null
var _consequence_state_port: Object = null
var _checkpoint_port: Object = null
var _registry: Script = null
var _identity_issuer: Object = null
var _mutation_gate: ApplicationMutationGate = null
var _publication_ledger: Object = null

## Keyed by transaction_id; the sole in-memory idempotency ledger for prepare_purchase(). Consulted
## FIRST, but never the sole source of truth -- see prepare_purchase()'s own live-state recognition
## branch for the "fresh participant instance after a crash" case, where this ledger is empty but
## DesktopConsequenceState's durable pending record survives.
var _transactions: Dictionary = {}
var _committed_transactions: Dictionary = {}
## Task 8 (dwm-p2r.32) addition: a separate idempotency ledger for the recovery-boundary
## commit_recovery_action(), so it never collides with commit()'s own pre-Task-8 transaction identity.
var _recovery_committed: Dictionary = {}
var _gate_token := ""
var _catalog: Object
var _source_checkpoint_capture: Callable


# -------------------------------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------------------------------

func configure_publication_ledger(publication_ledger: Object) -> Dictionary:
	if publication_ledger == null or not publication_ledger.has_method("record_before_emit"):
		return _fail(&"invalid_publication_ledger", "publication_ledger must expose record_before_emit", {})
	if _publication_ledger != null:
		if _publication_ledger == publication_ledger:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"publication_ledger_already_configured", "a different publication ledger is already bound", {})
	_publication_ledger = publication_ledger
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


func configure(state_port: Object, consequence_state_port: Object, checkpoint_port: Object,
		registry: Script, identity_issuer: Object, mutation_gate: ApplicationMutationGate) -> Dictionary:
	if state_port == null or not _has_all_methods(state_port, _STATE_PORT_METHODS):
		return _fail(&"invalid_state_port", "an exact state-port capability is required", {})
	if consequence_state_port == null or not _has_all_methods(consequence_state_port, _CONSEQUENCE_STATE_PORT_METHODS):
		return _fail(&"invalid_consequence_state_port", "an exact consequence-state-port capability is required", {})
	if checkpoint_port == null or not _has_all_methods(checkpoint_port, _CHECKPOINT_PORT_METHODS):
		return _fail(&"invalid_checkpoint_port", "an exact checkpoint-port capability is required", {})
	if registry == null or not registry.has_method("get_record"):
		return _fail(&"invalid_registry", "registry must expose get_record", {})
	if identity_issuer == null or not identity_issuer.has_method("derive_child") \
			or not identity_issuer.has_method("verify_issued"):
		return _fail(&"invalid_identity_issuer", "an exact identity-issuer capability is required", {})
	if mutation_gate == null:
		return _fail(&"invalid_mutation_gate", "mutation_gate is required", {})
	if _publication_ledger == null:
		return _fail(&"publication_ledger_not_configured", "configure_publication_ledger() is required before configure()", {})
	if _state_port != null or _consequence_state_port != null or _checkpoint_port != null \
			or _registry != null or _identity_issuer != null or _mutation_gate != null:
		if _state_port != state_port or _consequence_state_port != consequence_state_port \
				or _checkpoint_port != checkpoint_port or _registry != registry \
				or _identity_issuer != identity_issuer or _mutation_gate != mutation_gate:
			return _fail(&"participant_already_configured", "a configured participant never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_state_port = state_port
	_consequence_state_port = consequence_state_port
	_checkpoint_port = checkpoint_port
	_registry = registry
	_identity_issuer = identity_issuer
	_mutation_gate = mutation_gate
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


# -------------------------------------------------------------------------------------------------
# quote() -- pure apart from retaining idempotency truth in the participant candidate.
# -------------------------------------------------------------------------------------------------

## `quote_id` is child kind `shop_quote` anchored to the full transaction receipt. Idempotent on an
## identical (item_id, transaction_id) replay; a second, different item under the SAME transaction
## conflicts (brief line 51's "a second item under the same transaction conflicts" applies at
## `prepare_purchase()` too, but is caught here first since quote() is where the retained record is
## first written).
func configure_catalog(catalog: Object, capture_inputs: Callable) -> Dictionary:
	if catalog == null or not catalog.has_method("get_shop_item") or not capture_inputs.is_valid():
		return _fail(&"invalid_shop_catalog_capture", "", {})
	if _catalog != null and (_catalog != catalog or _source_checkpoint_capture != capture_inputs):
		return _fail(&"shop_catalog_already_configured", "", {})
	_catalog = catalog
	_source_checkpoint_capture = capture_inputs
	return {"ok": true}


func _get_item_record(item_id: String, quantity: int) -> Dictionary:
	if item_id in _CAPABILITY_ITEM_IDS or item_id == _SUPPORTZ_ITEM_ID:
		if quantity != 1: return _fail(&"shop_quantity_exceeds_batch_cap", "", {})
		return _registry.call(&"get_record", item_id)
	if _catalog == null: return _fail(&"unregistered_shop_item", "", {})
	var item: Dictionary = _catalog.get_shop_item(item_id)
	if item.is_empty(): return _fail(&"unregistered_shop_item", "", {})
	if item_id in _NOTE_RULES.ITEM_IDS:
		if quantity != 1: return _fail(&"invalid_quantity", "", {})
		if typeof(item.get("currency")) != TYPE_STRING or item.currency != "money" \
				or typeof(item.get("price")) != TYPE_INT or item.price != 45 \
				or typeof(item.get("max_purchases")) != TYPE_INT or item.max_purchases != 3 \
				or not item.get("effect_ids") is Array or not item.effect_ids.is_empty():
			return _fail(&"invalid_note_shop_record", "", {})
	var maximum := maxi(1, int(item.get("max_purchases", 0)))
	if quantity < 1 or quantity > maximum:
		return _fail(&"shop_quantity_exceeds_batch_cap", "", {})
	return {"ok": true, "value": {"record": {
		"item_id": item_id, "currency": str(item.currency), "price": int(item.price) * quantity,
		"effect_ids": item.effect_ids.duplicate(true), "quantity": quantity,
		"max_purchases": int(item.get("max_purchases", 0)),
	}}}


func quote(item_id: String, transaction_id: String, transaction_issuer_receipt: Dictionary, quantity: int = 1) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var verified := _verify_transaction(transaction_id, transaction_issuer_receipt)
	if not verified.get("ok", false):
		return verified
	var fetched: Dictionary = _get_item_record(item_id, quantity)
	if not fetched.get("ok", false):
		return fetched
	var record: Dictionary = (fetched["value"] as Dictionary)["record"]
	var registry_version := str(_registry.get_script_constant_map().get("REGISTRY_VERSION", ""))
	var request_fingerprint := _canonical_sha256({
		"item_id": item_id, "transaction_id": transaction_id,
		"currency": str(record["currency"]), "price": int(record["price"]),
		"registry_version": registry_version,
	})

	if _transactions.has(transaction_id):
		var recorded: Dictionary = _transactions[transaction_id]
		if recorded.has("quote") and str((recorded["quote"] as Dictionary)["item_id"]) != item_id:
			return _fail(&"shop_quote_second_item_conflict",
				"a different item was already quoted under this transaction", {})
		if recorded.has("quote"):
			if str(recorded.quote.request_fingerprint) != request_fingerprint:
				return _fail(&"shop_quote_quantity_conflict", "", {})
			return {"ok": true, "code": &"ok", "value": (recorded["quote"] as Dictionary).duplicate(true),
				"receipt": (recorded["quote"] as Dictionary).duplicate(true)}

	var derived: Dictionary = _identity_issuer.call(&"derive_child", {
		"child_kind": "shop_quote", "ordinal": 0,
		"parent_receipt_id": str(transaction_issuer_receipt.get("receipt_id", "")),
		"source_ids": [request_fingerprint],
	})
	if not derived.get("ok", false):
		return derived
	var derived_value: Dictionary = derived["value"]
	var quote_record := {
		"quote_id": str(derived_value["child_id"]),
		"quote_id_provenance": (derived_value["provenance"] as Dictionary).duplicate(true),
		"transaction_id": transaction_id, "transaction_issuer_receipt": transaction_issuer_receipt.duplicate(true),
		"item_id": item_id, "currency": str(record["currency"]), "price": int(record["price"]),
		"registry_version": registry_version, "request_fingerprint": request_fingerprint,
	}
	var entry: Dictionary = _transactions.get(transaction_id, {}) as Dictionary
	if quantity != 1: quote_record["quantity"] = quantity
	entry["quote"] = quote_record.duplicate(true)
	_transactions[transaction_id] = entry
	return {"ok": true, "code": &"ok", "value": quote_record.duplicate(true), "receipt": quote_record.duplicate(true)}


# -------------------------------------------------------------------------------------------------
# prepare_purchase() -- validates everything, acquires/retains the causal_transaction lease, and
# durably checkpoints the unpromoted pending action. Public result is PENDING, never audience
# success (Task-7 boundary ruling).
# -------------------------------------------------------------------------------------------------

func prepare_purchase(request: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var shape := _exact_keys(request, _REQUEST_KEYS, &"shop_purchase_request_invalid")
	if not shape.get("ok", false):
		return shape
	var transaction_id := str(request["transaction_id"])
	var request_fingerprint := _canonical_sha256(request)

	# 1. Own in-memory ledger: exact replay or conflict for an already-prepared transaction.
	var entry: Dictionary = _transactions.get(transaction_id, {}) as Dictionary
	if entry.has("prepare_result"):
		if str(entry.get("prepare_request_fingerprint", "")) == request_fingerprint:
			return (entry["prepare_result"] as Dictionary).duplicate(true)
		return _fail(&"transaction_conflict", "this transaction was already prepared with different bytes", {})

	# 2. Recognize a durable pending transaction that survived a participant restart even though
	#    this in-memory ledger is empty (DesktopConsequenceState's own record is the durable truth).
	var consequence_captured: Dictionary = _consequence_state_port.call(&"capture")
	if not consequence_captured.get("ok", false):
		return consequence_captured
	var live_state: Dictionary = (consequence_captured["value"] as Dictionary)["state"]
	var live_pending: Variant = live_state.get("pending")
	if live_pending != null:
		var pending: Dictionary = live_pending
		if str(pending.get("transaction_id", "")) == transaction_id and str(pending.get("source_kind", "")) == _ACTION_KIND:
			var recovered := _recognize_live_pending(pending, request_fingerprint, transaction_id)
			if not recovered.get("ok", false):
				return recovered
			return (recovered["value"] as Dictionary)["result"]
		return _fail(&"shop_purchase_requires_no_other_pending_transaction",
			"another desktop causal transaction is already pending", {})

	var verified := _verify_transaction(transaction_id, request["transaction_issuer_receipt"])
	if not verified.get("ok", false):
		return verified

	var item_id := str(request["item_id"])
	var fetched: Dictionary = _get_item_record(item_id, int(entry.get("quote", {}).get("quantity", 1)))
	if not fetched.get("ok", false):
		return fetched
	var item: Dictionary = (fetched["value"] as Dictionary)["record"]

	if not entry.has("quote") or str((entry["quote"] as Dictionary)["quote_id"]) != str(request["quote_id"]):
		return _fail(&"shop_quote_not_found", "prepare_purchase requires its own retained byte-exact quote", {})
	var quote_record: Dictionary = entry["quote"]
	if str(quote_record["transaction_id"]) != transaction_id or str(quote_record["item_id"]) != item_id:
		return _fail(&"shop_quote_transaction_mismatch", "the retained quote does not match this request", {})
	var registry_version := str(_registry.get_script_constant_map().get("REGISTRY_VERSION", ""))
	if str(quote_record["currency"]) != str(item["currency"]) or int(quote_record["price"]) != int(item["price"]) \
			or str(quote_record["registry_version"]) != registry_version:
		return _fail(&"shop_quote_registry_record_changed", "the registry record no longer matches the retained quote", {})

	if int(request["expected_run_revision"]) != int(live_state["run_revision"]):
		return _fail(&"stale_run_revision", "expected_run_revision no longer matches the live consequence state", {})
	if str(request["expected_causal_day_instance"]) != str(live_state["causal_day_instance"]):
		return _fail(&"stale_causal_day_instance",
			"expected_causal_day_instance no longer matches the live consequence state", {})

	var state_facts: Dictionary = _state_port.call(&"capture")
	if not state_facts.get("ok", false):
		return state_facts
	var facts: Dictionary = state_facts["value"]

	if item_id == _SUPPORTZ_ITEM_ID:
		var eligibility_checked := _validate_supportz_eligibility(
			str(live_state["causal_day_instance"]), transaction_id, facts)
		if not eligibility_checked.get("ok", false):
			return eligibility_checked

	var economy_prepared: Dictionary = _state_port.call(&"prepare_purchase", item, quote_record, transaction_id,
		request["transaction_issuer_receipt"])
	if not economy_prepared.get("ok", false):
		return economy_prepared
	var economy_value: Dictionary = economy_prepared["value"]
	var economy_candidate: Dictionary = economy_value["candidate"]

	var built_receipt := _build_action_receipt(transaction_id, request["transaction_issuer_receipt"],
		quote_record, facts, economy_value.get("condition_after", {}))
	if not built_receipt.get("ok", false):
		return built_receipt
	var receipt: Dictionary = (built_receipt["value"] as Dictionary)["receipt"]
	var action_candidate_sha256: String = (built_receipt["value"] as Dictionary)["action_candidate_sha256"]

	var acquired_fresh := false
	if not _mutation_gate.is_internal_owner_active(_GATE_OWNER):
		var acquired: Dictionary = _mutation_gate.acquire(_GATE_OWNER)
		if not acquired.get("ok", false):
			return _fail(&"causal_transaction_lease_unavailable",
				"the shared causal_transaction lease is held by another transaction", {})
		_gate_token = str((acquired["value"] as Dictionary)["token"])
		acquired_fresh = true

	if _source_checkpoint_capture.is_valid():
		var inputs: Dictionary = _source_checkpoint_capture.call(live_state.duplicate(true))
		if not inputs.get("ok", false):
			if acquired_fresh: release_recovery_lease()
			return inputs
		var prepared_source: Dictionary = _checkpoint_port.prepare(inputs.value.checkpoint_inputs,
			&"safe_marker", {"kind": &"autosave", "reason": &"automatic"})
		if not prepared_source.get("ok", false):
			if acquired_fresh: release_recovery_lease()
			return prepared_source
		var saved_source: Dictionary = _checkpoint_port.commit(prepared_source.value.candidate)
		if not saved_source.get("ok", false):
			if acquired_fresh: release_recovery_lease()
			return saved_source
		var source_snapshot: Dictionary = prepared_source.value.candidate.autosave_document.current_snapshot.snapshot
		economy_candidate["source_checkpoint"] = {"checkpoint_id": source_snapshot.checkpoint_id,
			"snapshot_sha256": _canonical_sha256(source_snapshot)}

	# `participant_snapshot_ids` is a free-form Dictionary (no exact-key law on it) -- reused here to
	# carry exactly what a restarted participant needs to recognize and resume this purchase from
	# DesktopConsequenceState's own durable pending record alone, with no other in-memory state.
	var recovery_payload := {
		"source_kind": _ACTION_KIND, "action_receipt": receipt.duplicate(true),
		"run_revision_before": int(live_state["run_revision"]),
		"participant_snapshot_ids": {
			"request_fingerprint": request_fingerprint, "item_id": item_id,
			"currency": str(quote_record["currency"]), "price": int(quote_record["price"]),
			"economy_candidate": economy_candidate.duplicate(true),
		},
	}
	var action_receipt_for_handoff := receipt.duplicate(true)
	action_receipt_for_handoff["source_kind"] = receipt["action_kind"]
	var handoff_prepared: Dictionary = _consequence_state_port.call(&"prepare_action_handoff",
		action_receipt_for_handoff, int(live_state["run_revision"]), recovery_payload)
	if not handoff_prepared.get("ok", false):
		if acquired_fresh: release_recovery_lease()
		return handoff_prepared
	var handoff_candidate: Dictionary = (handoff_prepared["value"] as Dictionary)["candidate"]


	# `kind` is a free-form descriptive operation label -- this codebase's own established
	# convention (DesktopConsequenceState.prepare_recovery_advance()'s own headers use
	# "consequence_advance"/"consequence_cleanup", never an echo of `stage`), not a value validated
	# against any closed vocabulary. `operation_ordinal=0` matches the frozen table's
	# `action_checkpointed=0`: this is the FIRST checkpoint ever written for this newly pending
	# transaction, and no earlier Task-6 code path checkpoints the pre-admission pending record at
	# all (first-Reveal never opens one), so there is no established ordinal to defer to here.
	var checkpoint_header := {
		"kind": &"shop_purchase_action_checkpoint", "operation_ordinal": 0, "run_id": str(facts["run_id"]),
		"source_ids": [transaction_id], "stage": "action_prepared", "transaction_id": transaction_id,
	}
	var checkpoint_prepared: Dictionary = _checkpoint_port.call(&"prepare_consequence_checkpoint",
		checkpoint_header, handoff_candidate["state_after"])
	if not checkpoint_prepared.get("ok", false):
		if acquired_fresh:
			_mutation_gate.release(_GATE_OWNER, _gate_token)
			_gate_token = ""
		return checkpoint_prepared
	var checkpoint_value: Dictionary = checkpoint_prepared["value"]
	var checkpoint_committed: Dictionary = _checkpoint_port.call(&"commit_consequence_checkpoint",
		checkpoint_value["candidate"], checkpoint_value["checkpoint_receipt"])
	if not checkpoint_committed.get("ok", false):
		if acquired_fresh:
			_mutation_gate.release(_GATE_OWNER, _gate_token)
			_gate_token = ""
		return checkpoint_committed

	# The disk checkpoint is now durable. From here forward this participant never rewinds on
	# failure (mirrors DesktopCausalSequencePort's own CRITICAL-1 discipline): a live-adopt failure
	# past this point is a genuine anomaly, returned as-is with the gate left retained.
	var consequence_committed: Dictionary = _consequence_state_port.call(&"commit", handoff_candidate)
	if not consequence_committed.get("ok", false):
		return consequence_committed

	var result := {"ok": true, "code": &"shop_purchase_action_checkpointed", "value": {
		"action_receipt": receipt.duplicate(true), "candidate": {"transaction_id": transaction_id},
		"action_candidate": economy_candidate.duplicate(true),
		"prepared_checkpoint_receipt": (checkpoint_value["checkpoint_receipt"] as Dictionary).duplicate(true),
	}, "receipt": {}}
	entry["prepare_request_fingerprint"] = request_fingerprint
	entry["prepare_result"] = result.duplicate(true)
	entry["economy_candidate"] = economy_candidate.duplicate(true)
	entry["economy_backup"] = (economy_value["backup"] as Dictionary).duplicate(true)
	entry["action_receipt"] = receipt.duplicate(true)
	entry["action_candidate_sha256"] = action_candidate_sha256
	entry["item_id"] = item_id
	entry["causal_day_instance"] = str(live_state["causal_day_instance"])
	_transactions[transaction_id] = entry
	return result.duplicate(true)


func capture() -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var state_captured: Dictionary = _state_port.call(&"capture")
	if not state_captured.get("ok", false):
		return state_captured
	var consequence_captured: Dictionary = _consequence_state_port.call(&"capture")
	if not consequence_captured.get("ok", false):
		return consequence_captured
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"state_backup": ((state_captured["value"] as Dictionary)["backup"] as Dictionary).duplicate(true),
		"consequence_state": ((consequence_captured["value"] as Dictionary)["state"] as Dictionary).duplicate(true),
	}}, "receipt": {}}


# -------------------------------------------------------------------------------------------------
# commit() -- the Task-7 boundary's forward commit. Rejects unless the gate lease is active AND the
# matching pending transaction has already reached sequence_committed.
# -------------------------------------------------------------------------------------------------

func commit(candidate: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var transaction_id := str(candidate.get("transaction_id", ""))
	if transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_candidate", "candidate.transaction_id is required", {})
	if not _mutation_gate.is_internal_owner_active(_GATE_OWNER):
		return _fail(&"causal_transaction_lease_required", "commit requires the active causal_transaction lease", {})

	if _committed_transactions.has(transaction_id):
		var recorded: Dictionary = _committed_transactions[transaction_id]
		if recorded["candidate"] == candidate:
			return (recorded["result"] as Dictionary).duplicate(true)
		return _fail(&"transaction_conflict", "this transaction was already committed with different bytes", {})

	var consequence_captured: Dictionary = _consequence_state_port.call(&"capture")
	if not consequence_captured.get("ok", false):
		return consequence_captured
	var live_state: Dictionary = (consequence_captured["value"] as Dictionary)["state"]
	var live_pending: Variant = live_state.get("pending")
	if live_pending == null or str((live_pending as Dictionary).get("transaction_id", "")) != transaction_id \
			or str((live_pending as Dictionary).get("source_kind", "")) != _ACTION_KIND \
			or str((live_pending as Dictionary).get("stage", "")) != "sequence_committed":
		return _fail(&"shop_purchase_commit_requires_sequence_committed",
			"commit requires the matching pending transaction to already be sequence_committed", {})

	if not _transactions.has(transaction_id):
		return _fail(&"shop_purchase_commit_unknown_transaction",
			"commit requires a transaction this participant itself prepared", {})
	var entry: Dictionary = _transactions[transaction_id]

	var economy_committed: Dictionary = _state_port.call(&"commit", entry["economy_candidate"])
	if not economy_committed.get("ok", false):
		return economy_committed

	if str(entry["item_id"]) == _SUPPORTZ_ITEM_ID:
		var recorded_purchase: Dictionary = _consequence_state_port.call(&"prepare_record_supportz_purchase",
			transaction_id, str(entry["causal_day_instance"]))
		if not recorded_purchase.get("ok", false):
			return recorded_purchase
		var ledger_committed: Dictionary = _consequence_state_port.call(&"commit",
			(recorded_purchase["value"] as Dictionary)["candidate"])
		if not ledger_committed.get("ok", false):
			return ledger_committed

	var result := {"ok": true, "code": &"ok", "value": {
		"action_receipt": (entry["action_receipt"] as Dictionary).duplicate(true),
	}, "receipt": {}}
	_committed_transactions[transaction_id] = {"candidate": candidate.duplicate(true), "result": result.duplicate(true)}
	return result.duplicate(true)


func rollback(backup: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if typeof(backup.get("state_backup")) != TYPE_DICTIONARY or typeof(backup.get("consequence_state")) != TYPE_DICTIONARY:
		return _fail(&"invalid_backup", "backup.state_backup and backup.consequence_state are required", {})
	var state_restored: Dictionary = _state_port.call(&"rollback", backup["state_backup"])
	if not state_restored.get("ok", false):
		return state_restored
	var consequence_prepared: Dictionary = _consequence_state_port.call(&"prepare_restore", backup["consequence_state"])
	if not consequence_prepared.get("ok", false):
		return consequence_prepared
	var consequence_committed: Dictionary = _consequence_state_port.call(&"commit",
		(consequence_prepared["value"] as Dictionary)["candidate"])
	if not consequence_committed.get("ok", false):
		return consequence_committed
	var restored_state: Dictionary = (consequence_committed["value"] as Dictionary)["state"]
	if restored_state.get("pending") == null and _gate_token != "":
		_mutation_gate.release(_GATE_OWNER, _gate_token)
		_gate_token = ""
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


## Records the at-most-once external observation of this action through the configured publication
## ledger's shared `action_source` kind (frozen contract line 337: the SAME kind
## MinesweeperRoundCoordinator will eventually use for round-completion actions, keyed by
## `action_receipt.commit_receipt_id`), then releases the causal_transaction lease -- the Task-7
## boundary's "release only after publication/abandonment" (rollback() is the abandonment path).
func publish(publication: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var keys: Array = publication.keys()
	keys.sort()
	if keys != ["action_receipt"]:
		return _fail(&"invalid_publication", "publication must carry exactly action_receipt", {})
	var receipt: Dictionary = publication["action_receipt"]
	var validated := _ACTION_RECEIPT.validate(receipt)
	if not validated.get("ok", false):
		return validated
	var transaction_id := str(receipt.get("transaction_id", ""))
	var action_candidate_sha256 := ""
	if _transactions.has(transaction_id):
		action_candidate_sha256 = str((_transactions[transaction_id] as Dictionary).get("action_candidate_sha256", ""))
	var ledger_publication := {"action_candidate_sha256": action_candidate_sha256, "action_receipt": receipt.duplicate(true)}
	var recorded: Dictionary = _publication_ledger.call(&"record_before_emit", {
		"kind": "action_source", "semantic_receipt": receipt.duplicate(true),
		"publication": ledger_publication, "publication_sha256": _canonical_sha256(ledger_publication),
	})
	if not recorded.get("ok", false):
		return recorded
	if _gate_token != "":
		_mutation_gate.release(_GATE_OWNER, _gate_token)
		_gate_token = ""
	return {"ok": true, "code": &"ok", "value": {"published": true}, "receipt": {}}


# -------------------------------------------------------------------------------------------------
# Task 8 (dwm-p2r.32) additions: the frozen three-method action-source recovery surface consumed by
# DesktopConsequenceCoordinator. `action_candidate` here is the SELF-SUFFICIENT economy candidate
# `GameStateMinesweeperShopPort.prepare_purchase()` already builds (`{transaction_id,item_id,
# currency,price,grant_inventory_item_id}`). `prepare_purchase()` returns that exact detached value
# together with its ordinal-0 checkpoint receipt so the production presentation facade can hand the
# already-prepared transaction to `DesktopConsequenceCoordinator.accept_prepared_action()` without
# reconstructing either value, exactly like `MinesweeperRoundCoordinator.complete_round()` does.
# A genuinely reconstructed participant (empty `_transactions`) needs no recognition step here: the
# pair (action_candidate, action_receipt) is already everything `commit_recovery_action()` needs,
# independent of any process-local ledger.
# -------------------------------------------------------------------------------------------------

func validate_recovery_action(action_candidate: Dictionary, action_receipt: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var validated := _ACTION_RECEIPT.validate(action_receipt)
	if not validated.get("ok", false):
		return validated
	var receipt: Dictionary = (validated["value"] as Dictionary)["receipt"]
	if str(receipt["action_kind"]) != _ACTION_KIND:
		return _fail(&"action_receipt_source_kind_mismatch", "", {})
	if str(action_candidate.get("transaction_id", "")) != str(receipt["transaction_id"]):
		return _fail(&"invalid_action_candidate", "action_candidate.transaction_id must match action_receipt", {})
	if action_candidate.get("item_id", "") in _NOTE_RULES.ITEM_IDS:
		var checked: Dictionary = _state_port.call(&"validate_note_candidate", action_candidate)
		if not checked.get("ok", false): return checked
		if action_candidate.ordinary_source_gameplay.get("day") != receipt.get("day"):
			return _fail(&"invalid_note_shop_candidate", "source day does not match action receipt", {})
	var action_candidate_sha256 := _action_candidate_sha256_from_receipt(receipt)
	return {"ok": true, "code": &"ok", "value": {"publication": {
		"action_candidate_sha256": action_candidate_sha256, "action_receipt": receipt.duplicate(true),
	}}, "receipt": {}}


## The source's sole live commit for this recovery boundary: applies the real economy delta (spend
## currency, grant capability, decrement the Supportz floor) through the SAME `GameStateMinesweeperShopPort
## .commit()`/`DesktopConsequenceState.prepare_record_supportz_purchase()` calls the pre-Task-8 `commit()`
## already uses, but against its OWN ledger (`_recovery_committed`) so this new surface never collides
## with `commit()`'s own pre-Task-8 transaction identity/replay law.
func commit_recovery_action(action_candidate: Dictionary, action_receipt: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var validated := _ACTION_RECEIPT.validate(action_receipt)
	if not validated.get("ok", false):
		return validated
	var receipt: Dictionary = (validated["value"] as Dictionary)["receipt"]
	if str(receipt["action_kind"]) != _ACTION_KIND:
		return _fail(&"action_receipt_source_kind_mismatch", "", {})
	var transaction_id := str(receipt["transaction_id"])
	if str(action_candidate.get("transaction_id", "")) != transaction_id:
		return _fail(&"invalid_action_candidate", "action_candidate.transaction_id must match action_receipt", {})

	if action_candidate.get("item_id", "") in _NOTE_RULES.ITEM_IDS:
		var checked: Dictionary = _state_port.call(&"validate_note_candidate", action_candidate)
		if not checked.get("ok", false): return checked
		if action_candidate.ordinary_source_gameplay.get("day") != receipt.get("day"):
			return _fail(&"invalid_note_shop_candidate", "source day does not match action receipt", {})

	if _recovery_committed.has(transaction_id):
		var recorded: Dictionary = _recovery_committed[transaction_id]
		if recorded["action_candidate"] == action_candidate and recorded["action_receipt"] == receipt:
			return (recorded["result"] as Dictionary).duplicate(true)
		return _fail(&"action_receipt_conflict", "this transaction was already committed with different bytes", {})

	if not _mutation_gate.is_internal_owner_active(_GATE_OWNER):
		return _fail(&"causal_transaction_lease_required", "commit_recovery_action requires the active causal_transaction lease", {})

	var economy_committed: Dictionary = _state_port.call(&"commit", action_candidate)
	if not economy_committed.get("ok", false):
		return economy_committed

	if str(action_candidate.get("item_id", "")) == _SUPPORTZ_ITEM_ID:
		var recorded_purchase: Dictionary = _consequence_state_port.call(&"prepare_record_supportz_purchase",
			transaction_id, str(receipt["causal_day_instance"]))
		if not recorded_purchase.get("ok", false):
			return recorded_purchase
		var ledger_committed: Dictionary = _consequence_state_port.call(&"commit",
			(recorded_purchase["value"] as Dictionary)["candidate"])
		if not ledger_committed.get("ok", false):
			return ledger_committed

	var result := {"ok": true, "code": &"ok", "value": {"action_receipt": receipt.duplicate(true)}, "receipt": receipt.duplicate(true)}
	_recovery_committed[transaction_id] = {
		"action_candidate": action_candidate.duplicate(true), "action_receipt": receipt.duplicate(true), "result": result.duplicate(true),
	}
	return result


## The source's sole audience boundary for this recovery path: records the at-most-once external
## observation through the SAME shared `action_source` publication-ledger kind and key convention
## `publish()` already established (Ruling B).
##
## dwm-p2r.35.7 remediation (finding 3): this method used to release the retained `causal_transaction`
## lease here, immediately after recording -- but this is callback index 1 of up to 3 in
## DesktopConsequenceCoordinator's own departure publication plan (causal_sequence, action_source,
## optional board_fate), so releasing here left board-fate publish and terminal cleanup running
## UNLEASED, contradicting `DesktopBoardFatePort`'s own class-doc argument that its one known
## candidate-hash-collision limitation "is not reachable in production" BECAUSE the coordinator holds
## the lease across one departure's whole prepare-to-publish span. The release now happens only in
## `release_recovery_lease()`, which the coordinator calls after terminal cleanup succeeds.
func publish_recovery_action(publication: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var keys: Array = publication.keys()
	keys.sort()
	if keys != ["action_candidate_sha256", "action_receipt"]:
		return _fail(&"invalid_publication", "publication must carry exactly action_candidate_sha256 and action_receipt", {})
	var receipt: Dictionary = publication["action_receipt"]
	var validated := _ACTION_RECEIPT.validate(receipt)
	if not validated.get("ok", false):
		return validated
	receipt = (validated["value"] as Dictionary)["receipt"]
	var ledger_publication := {
		"action_candidate_sha256": str(publication["action_candidate_sha256"]), "action_receipt": receipt.duplicate(true),
	}
	var recorded: Dictionary = _publication_ledger.call(&"record_before_emit", {
		"kind": "action_source", "semantic_receipt": receipt.duplicate(true),
		"publication": ledger_publication, "publication_sha256": _canonical_sha256(ledger_publication),
	})
	if not recorded.get("ok", false):
		return recorded
	if bool(recorded.get("value", {}).get("first_delivery", false)):
		var candidate: Dictionary = _recovery_committed.get(str(receipt.transaction_id), {}).get("action_candidate", {})
		if candidate.has("ordinary_gameplay"):
			var published: Dictionary = _state_port.publish(ledger_publication)
			if not published.get("ok", false): return published

	return {"ok": true, "code": &"ok", "value": {"published": true}, "receipt": receipt.duplicate(true)}


## dwm-p2r.35.7 remediation (finding 3): the fourth frozen recovery-method addition, called by
## DesktopConsequenceCoordinator._resume_forward() only AFTER terminal cleanup succeeds -- see that
## method's own doc comment for why the release moved out of publish_recovery_action(). Idempotent
## no-op when no token is held (a resume_pending()-driven forward recovery in a fresh process never
## acquired one in the first place, since this participant -- not the coordinator -- is the actual
## lease holder).
func release_recovery_lease() -> Dictionary:
	if _gate_token != "":
		_mutation_gate.release(_GATE_OWNER, _gate_token)
		_gate_token = ""
	return {"ok": true, "code": &"ok", "value": {"released": true}, "receipt": {}}


# -------------------------------------------------------------------------------------------------
# Internal helpers
# -------------------------------------------------------------------------------------------------

## A durably pending purchase recognized after a participant restart: this in-memory ledger is
## empty, but DesktopConsequenceState's own record -- the durable truth -- survived. The gate lease
## is re-established here too, since a restarted process retains no in-memory token either. The
## economy candidate is deterministically REBUILT (never re-fetched from state_port/registry) from
## exactly the same free-form `participant_snapshot_ids` this participant itself wrote at prepare
## time -- item_id/currency/price fully determine it, per prepare_purchase()'s own candidate shape.
func _recognize_live_pending(pending: Dictionary, request_fingerprint: String, transaction_id: String) -> Dictionary:
	var recovery_payload: Dictionary = pending.get("recovery_payload", {})
	var snapshot_ids: Dictionary = recovery_payload.get("participant_snapshot_ids", {})
	if str(snapshot_ids.get("request_fingerprint", "")) != request_fingerprint:
		return _fail(&"transaction_conflict",
			"the durable pending transaction does not match this request's bytes", {})
	var recovered_receipt: Dictionary = recovery_payload.get("action_receipt", {})
	var item_id := str(snapshot_ids.get("item_id", ""))
	if not _mutation_gate.is_internal_owner_active(_GATE_OWNER):
		var acquired: Dictionary = _mutation_gate.acquire(_GATE_OWNER)
		if not acquired.get("ok", false):
			return _fail(&"causal_transaction_lease_unavailable",
				"the shared causal_transaction lease is held by another transaction", {})
		_gate_token = str((acquired["value"] as Dictionary)["token"])
	var economy_candidate := {
		"transaction_id": transaction_id, "item_id": item_id, "currency": str(snapshot_ids.get("currency", "")),
		"price": int(snapshot_ids.get("price", 0)),
		"grant_inventory_item_id": item_id if item_id in _CAPABILITY_ITEM_IDS else "",
	}
	if snapshot_ids.get("economy_candidate") is Dictionary:
		economy_candidate = snapshot_ids.economy_candidate.duplicate(true)
	var result := {"ok": true, "code": &"shop_purchase_action_checkpointed", "value": {
		"action_receipt": (recovered_receipt as Dictionary).duplicate(true),
		"candidate": {"transaction_id": transaction_id},
		"action_candidate": economy_candidate.duplicate(true),
		# A fresh-process source-checkpoint recovery is owned by DesktopConsequenceCoordinator.resume_pending;
		# it has no in-memory handle to the checkpoint-port receipt used by live admission.
		"prepared_checkpoint_receipt": {},
	}, "receipt": {}}
	var entry: Dictionary = _transactions.get(transaction_id, {}) as Dictionary
	entry["prepare_request_fingerprint"] = request_fingerprint
	entry["prepare_result"] = result.duplicate(true)
	entry["action_receipt"] = (recovered_receipt as Dictionary).duplicate(true)
	entry["action_candidate_sha256"] = _action_candidate_sha256_from_receipt(recovered_receipt)
	entry["economy_candidate"] = economy_candidate
	entry["item_id"] = item_id
	entry["causal_day_instance"] = str(recovered_receipt.get("causal_day_instance", ""))
	_transactions[transaction_id] = entry
	return {"ok": true, "value": {"result": result.duplicate(true)}}


## Reverses _build_action_receipt()'s own addition of the four identity fields, reproducing
## H(action_candidate) purely from an already-produced receipt -- used only by the restart-recovery
## path above, which has no other route back to this hash.
func _action_candidate_sha256_from_receipt(receipt: Dictionary) -> String:
	var action_candidate: Dictionary = receipt.duplicate(true)
	for identity_field: String in ["action_id", "action_id_provenance", "commit_receipt_id", "commit_receipt_provenance"]:
		action_candidate.erase(identity_field)
	return _canonical_sha256(action_candidate)


func _validate_supportz_eligibility(causal_day_instance: String, transaction_id: String, facts: Dictionary) -> Dictionary:
	var eligibility_state: Dictionary = _consequence_state_port.call(&"supportz_eligibility_state", causal_day_instance)
	if not eligibility_state.get("ok", false):
		return eligibility_state
	var state: Dictionary = (eligibility_state["value"] as Dictionary)["state"]
	var eligible := _CAPABILITY_RULES.supportz_eligible(state)
	if not eligible.get("ok", false):
		return eligible
	if not bool((eligible["value"] as Dictionary)["eligible"]):
		return _fail(&"supportz_not_eligible", "supportz purchase eligibility requirements are not met", {})
	var effect := _CAPABILITY_RULES.prepare_supportz_effect(state, causal_day_instance, transaction_id)
	if not effect.get("ok", false):
		return effect
	var effect_value: Dictionary = effect["value"]
	if int(facts["minesweeper_round_floor"]) != int(effect_value["previous_round_floor"]):
		return _fail(&"supportz_floor_sequence_conflict",
			"the live round floor no longer matches the branch's Supportz purchase count", {})
	return {"ok": true}


## `commit_receipt_id`/`commit_receipt_provenance` reuse `action_id`/`action_id_provenance`
## byte-for-byte (see the class doc's own note on why: Plan 02's frozen production derivation table
## has no distinct row for a second commit-identity, and inventing one would be exactly the
## "unlisted semantic convention" that table's own law forbids).
func _build_action_receipt(transaction_id: String, transaction_issuer_receipt: Dictionary,
		quote_record: Dictionary, facts: Dictionary, condition_after: Dictionary = {}) -> Dictionary:
	var condition := {
		"health": int(facts["health"]), "pressure": int(facts["pressure"]),
		"carried_sequela": bool(facts["carried_sequela"]),
	}
	var action_candidate := {
		"schema_version": 1, "action_kind": _ACTION_KIND, "run_id": str(facts["run_id"]),
		"branch_id": str(facts["branch_id"]), "desktop_timeline_generation": int(facts["desktop_timeline_generation"]),
		"causal_day_instance": str(facts["causal_day_instance"]), "day": int(facts["day"]),
		"transaction_id": transaction_id, "transaction_issuer_receipt": transaction_issuer_receipt.duplicate(true),
		"source_commit_receipt_id": str(quote_record["quote_id"]),
		"source_commit_receipt_provenance": (quote_record["quote_id_provenance"] as Dictionary).duplicate(true),
		"condition_before": condition.duplicate(true),
		"condition_after": condition.duplicate(true) if condition_after.is_empty() else condition_after.duplicate(true),
		"unlock_receipt_ids": [],
	}
	var action_candidate_sha256 := _canonical_sha256(action_candidate)
	var derived: Dictionary = _identity_issuer.call(&"derive_child", {
		"child_kind": "desktop_action", "ordinal": 0,
		"parent_receipt_id": str(transaction_issuer_receipt.get("receipt_id", "")),
		"source_ids": _sorted_unique([_ACTION_KIND, str(quote_record["quote_id"]), action_candidate_sha256]),
	})
	if not derived.get("ok", false):
		return derived
	var derived_value: Dictionary = derived["value"]
	var action_id := str(derived_value["child_id"])
	var action_id_provenance: Dictionary = (derived_value["provenance"] as Dictionary).duplicate(true)
	var receipt := action_candidate.duplicate(true)
	receipt["action_id"] = action_id
	receipt["action_id_provenance"] = action_id_provenance
	receipt["commit_receipt_id"] = action_id
	receipt["commit_receipt_provenance"] = action_id_provenance.duplicate(true)
	var validated := _ACTION_RECEIPT.validate(receipt)
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "value": {
		"receipt": (validated["value"] as Dictionary)["receipt"], "action_candidate_sha256": action_candidate_sha256,
	}}


func _verify_transaction(transaction_id: String, transaction_issuer_receipt: Dictionary) -> Dictionary:
	if typeof(transaction_issuer_receipt) != TYPE_DICTIONARY:
		return _fail(&"invalid_transaction_issuer_receipt", "", {})
	var verified: Dictionary = _identity_issuer.call(&"verify_issued", transaction_issuer_receipt, &"transaction_id")
	if not verified.get("ok", false):
		return verified
	var receipt: Dictionary = (verified["value"] as Dictionary)["receipt"]
	if str(receipt.get("token", "")) != transaction_id:
		return _fail(&"transaction_id_receipt_mismatch", "", {})
	return {"ok": true}


func _sorted_unique(values: Array) -> Array[String]:
	var seen: Dictionary = {}
	for value: Variant in values:
		seen[str(value)] = true
	var out: Array[String] = []
	out.assign(seen.keys())
	out.sort()
	return out


func _require_configured() -> Dictionary:
	if _state_port == null or _consequence_state_port == null or _checkpoint_port == null \
			or _registry == null or _identity_issuer == null or _mutation_gate == null:
		return _fail(&"participant_not_configured", "MinesweeperShopPurchaseParticipant.configure() was never called", {})
	return {"ok": true}


static func _has_all_methods(target: Object, methods: Array[String]) -> bool:
	for method: String in methods:
		if not target.has_method(method):
			return false
	return true


func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()


func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
