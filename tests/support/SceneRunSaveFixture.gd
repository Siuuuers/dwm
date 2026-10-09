extends RefCounted
## Bounded full Run9/Save9 semantic fixture. Actual FileOps, issuer allocation,
## Profile assignment persistence/reload, installed B2/DTL, reading and GameState.
## ONLY the initial admission's prior checkpoint reference is injected. This does
## not prove production NewRun creation, connected SaveManager Load, or native activation.
const RUN := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const CONTACT_FIXTURE := preload("res://tests/support/SceneContactFixture.gd")
const READING_FIXTURE := preload("res://tests/support/SceneDayReadingFixture.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const PRESENTATION := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const GAME := preload("res://autoload/GameState.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ROOT := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const NAMESPACE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://scripts/infrastructure/storage/FileOps.gd")
const TEMP := preload("res://tests/support/TemporaryStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const ENTRY := "scene.test.b"

var tree: SceneTree
var game: Node
var profile: Node
var bridge: Node
var old_profile: Node
var old_profile_index := 0
var storage: RefCounted
var issuer: RefCounted
var root: RefCounted
var gate: RefCounted
var bundle: Dictionary = {}
var identity: Dictionary = {}
var admission: Dictionary = {}
var event: Dictionary = {}
var anchor: Dictionary = {}
var snapshot: Dictionary = {}
var document: Dictionary = {}
var setup_complete := false

func setup(scene_tree: SceneTree) -> Dictionary:
	tree = scene_tree
	var selected: Dictionary = CONTACT_FIXTURE.install_registration()
	if not selected.ok: return selected
	bundle = MANIFEST.scene_registration().value
	var temporary: Dictionary = TEMP.create("scene_full_save_anchor")
	if not temporary.ok: return temporary
	storage = STORAGE.new(temporary.value, FILES.new())
	root = ROOT.new()
	var result: Dictionary = root.configure(storage, NAMESPACE.new("da".repeat(32)))
	if not result.ok: return result
	result = root.load_or_create()
	if not result.ok: return result
	issuer = ISSUER.new()
	result = issuer.configure(root)
	if not result.ok: return result
	var transaction: Dictionary = issuer.issue(&"transaction_id")
	if not transaction.ok: return transaction
	var allocation: Dictionary = issuer.prepare_continuation_allocation({"kind": "new_run",
		"transaction_id": transaction.value.token, "transaction_issuer_receipt": transaction.value.issuer_receipt,
		"existing_run_id": null, "source_desktop_timeline_generation": null, "remap_source_transaction_ids": []})
	if not allocation.ok: return allocation
	result = issuer.commit_continuation_allocation(allocation.value)
	if not result.ok: return result
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt"]:
		identity[key] = result.value[key]

	# Exercise G's actual revision-aware Profile material persistence under the
	# existing NewRun gate; reload the canonical Profile from those exact bytes.
	# This is not a completed joint Autosave/Profile creation transaction.
	gate = GATE.new()
	var writer: Node = PROFILE.new()
	result = writer.initialize(storage)
	if not result.ok:
		writer.free()
		return result
	result = writer.configure_new_run_storage(storage)
	if result.ok: result = writer.configure_mutation_gate(gate)
	if not result.ok:
		writer.free()
		return result
	var material: Dictionary = writer.prepare_scene_new_run_consumption(writer.get_profile_revision(),
		identity.run_id, transaction.value.token, 0)
	if not material.ok:
		writer.free()
		return material
	var lease: Dictionary = gate.acquire(&"new_run")
	if not lease.ok:
		writer.free()
		return lease
	result = writer.persist_new_run_consumption(material.value)
	if result.ok: result = writer.prove_new_run_consumption(material.value)
	var released: Dictionary = gate.release(&"new_run", lease.value.token)
	writer.free()
	if not result.ok: return result
	if not released.ok: return released
	profile = PROFILE.new()
	result = profile.initialize(storage)
	if not result.ok: return result
	var retained: Dictionary = profile.get_pair_deck_draw(identity.run_id)
	if not retained.ok or retained.value != material.value.scene_assignment.receipt:
		return {"ok": false, "code": &"TEST.profile_reload_mismatch"}
	old_profile = tree.root.get_node("ProfileManager")
	old_profile_index = old_profile.get_index()
	tree.root.remove_child(old_profile)
	profile.name = "ProfileManager"
	tree.root.add_child(profile)
	game = GAME.new()
	game.name = "SceneRunSaveFixtureGame"
	tree.root.add_child(game)
	bridge = BRIDGE.new()
	result = game.configure_mutation_gate(gate)
	if result.ok: result = game.configure_identity_issuer(issuer)
	if result.ok: result = game.configure_scene_runtime_validation()
	if result.ok: result = game.configure_scene_event_owner(bridge)
	if result.ok: result = RUN.configure_scene_validation(issuer, game)
	if not result.ok: return result

	var admission_root: Dictionary = issuer.issue(&"transaction_id")
	if not admission_root.ok: return admission_root
	var injected_source := {"checkpoint_id": "TEST.injected.prior.boundary", "checkpoint_sequence": 1,
		"snapshot_sha256": "a".repeat(64)}
	result = CONTRACT.make_scene_admission(identity, admission_root.value.issuer_receipt,
		"target_b", injected_source, null, null, bundle, issuer)
	if not result.ok: return result
	admission = result.value
	var occurrence: String = admission.transaction_id
	var frozen: Dictionary = PRESENTATION.build(ENTRY, {"entry_id": ENTRY, "entry_role": "scene",
		"occurrence_id": occurrence, "admission_receipt_id": occurrence})
	if not frozen.ok: return frozen
	var frame := {"expected_stage": "scene", "playback_id": occurrence, "role": "scene",
		"transaction_id": occurrence, "presentation": frozen.value}
	var reading: RefCounted = SESSION.new()
	result = reading.configure_scene()
	if result.ok: result = reading.begin_scene("TEST.full.save.session")
	if result.ok: result = reading.admit_scene(ENTRY, frame)
	if not result.ok: return result
	var publication: Dictionary = reading.ledger.allocate_publication("TEST.full.save.session", ENTRY, occurrence)
	if not publication.ok: return publication
	result = reading.ledger.publish_line("TEST.full.save.session", publication.value, ENTRY,
		"line.scene.test.b.one", occurrence)
	if not result.ok: return result
	result = READING_FIXTURE.advance_detached(reading)
	if not result.ok: return result
	var frontier: Dictionary = READING_FIXTURE.frontier(reading)
	var captured: Dictionary = reading.capture(frontier)
	if not captured.ok: return captured
	var checkpoint := {"content_version": 1, "entry_id": ENTRY, "frozen_context": frame,
		"manifest_fingerprint": MANIFEST.scene_registration_fingerprint(), "stage": "scene",
		"transaction_id": occurrence, "reading_session": captured.value}
	anchor = {"session_id": occurrence, "entry_id": ENTRY, "content_version": 1,
		"catalogue_fingerprint": MANIFEST.scene_registration_fingerprint(),
		"publication_id": frontier.publication_id, "line_id": frontier.line_id}
	var command: Dictionary = issuer.issue(&"transaction_id")
	if not command.ok: return command
	event = {"schema_version": 2, "source": {"run_id": identity.run_id, "branch_id": identity.branch_id,
		"causal_day_instance": identity.causal_day_instance, "scene_occurrence": occurrence,
		"entry_id": ENTRY, "content_version": 1}, "event_id": "scene.test.b.end", "ordinal": 0,
		"predecessor": "", "kind": "scene.transition", "payload": {"target_id": "target_a"},
		"command_id": command.value.token, "issuer_receipt": command.value.issuer_receipt,
		"playback_token": "TEST.detached.semantic.receipt"}
	var receipt: Dictionary = rebuild_event(anchor)
	if not receipt.ok: return receipt
	var lifecycle: Dictionary = identity.duplicate(true)
	lifecycle.merge({"restore_provenance": null, "state": "PLAYING", "scene_assignment": retained.value})
	var gameplay := {"affection": {}, "coins": 0, "friend_attitude": {}, "friends": {},
		"inter_friend_affection": {}, "inventory": {}, "minesweeper_app_rounds_finished_today": 0,
		"minesweeper_money_earned_today": 0, "minesweeper_rng_seed": 0, "minesweeper_round_floor": 0,
		"minesweeper_rounds_left": 2, "minesweeper_selected_difficulty": "beginner",
		"minesweeper_task_rewards_claimed": {}, "money": 0, "narrative_variables": {},
		"penalty_points_today": 0, "penalty_points_total": 0, "route_context": {},
		"shop_purchase_counts": {}, "stats": {"pressure": 3}, "story_flags": {}}
	for friend: String in CONTACTS.FRIEND_IDS:
		gameplay.affection[friend] = 0
		gameplay.friend_attitude[friend] = "neutral"
	var input := {"lifecycle": lifecycle, "gameplay": gameplay, "contacts": CONTACTS.make_scene_defaults(),
		"desktop": game._empty_desktop_snapshot(identity.causal_day_instance, identity.causal_day_instance_issuer_receipt),
		"scene": {"registration_sha256": MANIFEST.scene_registration_fingerprint(),
			"active_occurrence_id": occurrence, "active_admission_receipt_id": occurrence},
		"applied_effect_transaction_ids": [], "applied_variable_transaction_ids": [],
		"command_receipts": {admission.transaction_id: admission, event.command_id: receipt.value}}
	result = RUN.build_scene(input, checkpoint, "scene", null, {}, 1, 2)
	if not result.ok: return result
	snapshot = result.value.snapshot
	result = SAVE.build(&"autosave", null, &"automatic", {"checkpoint_kind": "safe_marker", "snapshot": snapshot}, [])
	if not result.ok: return result
	document = result.value
	result = SAVE.validate(document)
	if not result.ok: return result
	# Serialize and reread this exact admitted Save9 using real filesystem owners.
	# This validates document storage, not SaveManager continuation recovery.
	var encoded: Dictionary = WRITER.stringify(document)
	if not encoded.ok: return encoded
	result = storage.write_atomic("scene-anchor.json", encoded.value, _validate_document_text)
	if not result.ok: return result
	var reread: Dictionary = storage.read_text("scene-anchor.json")
	if not reread.ok: return reread
	var parsed: Dictionary = PARSER.parse_object(reread.value)
	if not parsed.ok: return parsed
	result = SAVE.validate(parsed.value)
	if not result.ok: return result
	setup_complete = true
	return {"ok": true}

func rebuild_event(candidate_anchor: Dictionary) -> Dictionary:
	var request: Dictionary = CONTRACT.scene_completion_request(event, candidate_anchor, bundle)
	if not request.ok: return request
	var child: Dictionary = issuer.derive_child(request.value)
	if not child.ok: return child
	var target: Dictionary = {}
	for row: Dictionary in bundle.targets:
		if row.target_id == "target_a": target = row.target.duplicate(true)
	return CONTRACT.make_scene_receipt(event, candidate_anchor, {"kind": "scene_transition_accepted",
		"source_scene_occurrence": event.source.scene_occurrence, "target_id": "target_a", "target": target,
		"resolution_receipt": {"receipt_id": child.value.child_id, "provenance": child.value.provenance}}, bundle)

func with_receipt(receipt: Dictionary) -> Dictionary:
	var result: Dictionary = snapshot.duplicate(true)
	result.command_receipts[event.command_id] = receipt.duplicate(true)
	return result

func document_for(candidate: Dictionary) -> Dictionary:
	var result: Dictionary = document.duplicate(true)
	result.current_snapshot.snapshot = candidate.duplicate(true)
	return result

func observed_state() -> Dictionary:
	return {"game": game.capture_restore_state(), "profile": profile.get_profile_snapshot(),
		"profile_revision": profile.get_profile_revision(), "root": root.capture()}

func _validate_document_text(text: String) -> Dictionary:
	var parsed: Dictionary = PARSER.parse_object(text)
	return SAVE.validate(parsed.value) if parsed.ok else parsed

func close() -> void:
	if is_instance_valid(game): game.free()
	if is_instance_valid(bridge): bridge.free()
	if is_instance_valid(profile): profile.free()
	if is_instance_valid(old_profile) and old_profile.get_parent() == null:
		tree.root.add_child(old_profile)
		tree.root.move_child(old_profile, old_profile_index)
