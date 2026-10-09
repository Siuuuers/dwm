extends RefCounted
## Real FileOps, allocation issuer, Profile, GameState/Run adapter and SaveManager.
## Narrative candidate prepare is actual; route/native activation, board, audio
## and localization are explicit protocol diagnostics;
## this fixture does not claim rendered activation or a fresh OS-process Load.
const SAVE := preload("res://autoload/SaveManager.gd")
const GAME := preload("res://autoload/GameState.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const RUN := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const RUN_PARTICIPANT := preload("res://scripts/application/restore/RunRestoreParticipant.gd")
const NARRATIVE_PARTICIPANT := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd")
const PROFILE_PARTICIPANT := preload("res://scripts/application/restore/ProfileRestoreParticipant.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const ROOT := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const NAMESPACE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://scripts/infrastructure/storage/FileOps.gd")
const TEMP := preload("res://tests/support/TemporaryStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const REGISTRATION := preload("res://tests/support/SceneContactFixture.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")

class DiagnosticParticipant:
	extends RefCounted
	signal scene_activation_confirmed(operation_id: String)
	signal scene_activation_failed(operation_id: String, result: Dictionary)
	var plan_key := ""
	var confirmed := ""
	var started := ""
	var publications := 0
	var applies := 0
	var narrative_preparer: RefCounted
	func _init(key: String) -> void: plan_key = key
	func prepare(input: Dictionary) -> Dictionary:
		return {"ok": true, "value": {plan_key: input.duplicate(true)}}
	func prepare_scene_new_run(snapshot: Dictionary, allocation: Dictionary, profile_material: Dictionary,
			bundle: Dictionary, issuer: Object, creation_owner: Object) -> Dictionary:
		if narrative_preparer == null: return {"ok": false, "code": &"TEST.narrative_preparer_missing"}
		return narrative_preparer.prepare_scene_new_run(snapshot, allocation, profile_material, bundle, issuer, creation_owner)
	func capture() -> Dictionary: return {"ok": true, "value": {}}
	func apply_silent(_plan: Dictionary) -> Dictionary:
		applies += 1
		return {"ok": true, "value": {"route_ready_token": {"generation": 1}}}
	func rollback_silent(_backup: Dictionary) -> Dictionary: return {"ok": true}
	func finalize() -> Dictionary: return {"ok": true}
	func begin_scene_publication_hold(_operation: String) -> Dictionary: return {"ok": true}
	func cancel_scene_publication_hold(_operation: String) -> Dictionary: return {"ok": true}
	func begin_scene_activation(operation: String) -> Dictionary:
		started = operation
		return {"ok": true}
	func validate_scene_activation(operation: String) -> Dictionary:
		return {"ok": operation == confirmed and operation == started and not operation.is_empty()}
	func publish_scene_activation(operation: String) -> Dictionary:
		if not validate_scene_activation(operation).ok: return {"ok": false}
		publications += 1
		return {"ok": true}
	func confirm() -> void:
		confirmed = started
		scene_activation_confirmed.emit(started)

var tree: SceneTree
var storage: RefCounted
var issuer: RefCounted
var root: RefCounted
var gate: RefCounted
var manager: Node
var game: Node
var profile: Node
var bridge: Node
var participants: Dictionary = {}
var original_owners: Dictionary = {}

func setup(scene_tree: SceneTree) -> Dictionary:
	tree = scene_tree
	var checked: Dictionary = REGISTRATION.install_registration()
	if not checked.ok: return checked
	var temporary: Dictionary = TEMP.create("scene_joint_new_run")
	if not temporary.ok: return temporary
	storage = STORAGE.new(temporary.value, FILES.new())
	root = ROOT.new()
	checked = root.configure(storage, NAMESPACE.new("db".repeat(32)))
	if checked.ok: checked = root.load_or_create()
	if not checked.ok: return checked
	issuer = ISSUER.new()
	checked = issuer.configure(root)
	if not checked.ok: return checked
	gate = GATE.new()
	profile = PROFILE.new()
	checked = profile.initialize(storage)
	if checked.ok: checked = profile.configure_new_run_storage(storage)
	if checked.ok: checked = profile.configure_mutation_gate(gate)
	if not checked.ok: return checked
	manager = SAVE.new()
	_replace_owner("ProfileManager", profile)
	_replace_owner("SaveManager", manager)
	game = GAME.new()
	game.name = "SceneNewRunFixtureGame"
	tree.root.add_child(game)
	bridge = BRIDGE.new()
	bridge.name = "SceneNewRunFixtureBridge"
	tree.root.add_child(bridge)
	checked = game.configure_mutation_gate(gate)
	if checked.ok: checked = game.configure_identity_issuer(issuer)
	if checked.ok: checked = game.configure_scene_runtime_validation()
	if checked.ok: checked = game.configure_scene_event_owner(bridge)
	if checked.ok: checked = manager.initialize(storage)
	if checked.ok: checked = manager.configure_identity_issuer(issuer)
	if checked.ok: checked = manager.configure_mutation_gate(gate)
	if checked.ok: checked = manager.configure_new_run_profile_owner(profile)
	if not checked.ok: return checked
	participants = {"run": RUN_PARTICIPANT.new(game), "profile": PROFILE_PARTICIPANT.new(profile)}
	var keys := {"desktop_consequence": "consequence_plan", "desktop_board": "board_plan",
		"localization": "localization_plan", "audio": "audio_plan", "route": "route_plan", "narrative": "narrative_plan"}
	for key: String in keys:
		participants[key] = DiagnosticParticipant.new(keys[key])
	participants.narrative.narrative_preparer = NARRATIVE_PARTICIPANT.new(bridge)
	checked = manager.configure_scene_restore_participants(participants)
	if checked.ok: checked = manager.configure_scene_new_run(bridge)
	if checked.ok: checked = RUN.configure_scene_validation(issuer, game, manager)
	return checked

func start(nonce: int = 0) -> Dictionary:
	return manager.start_scene_new_run("target_b", {"audio_context": {}, "content_version": 1, "route_id": "scene"}, nonce)

func confirm_activation() -> void:
	participants.route.confirm()
	participants.narrative.confirm()

func reopen_journal() -> Dictionary:
	var reopened: RefCounted = JOURNAL.new()
	var checked: Dictionary = reopened.configure(storage, manager)
	if not checked.ok: return checked
	checked = reopened.configure_scene_new_run_validation(preload("res://scripts/narrative/DialogicEntryManifest.gd").scene_registration().value, issuer)
	if not checked.ok: return checked
	return {"ok": true, "value": reopened}

func read_autosave() -> Dictionary:
	var read: Dictionary = storage.read_text("autosave.json")
	return PARSER.parse_object(read.value) if read.ok else read

func reload_profile() -> Dictionary:
	var reopened: Node = PROFILE.new()
	var checked: Dictionary = reopened.initialize(storage)
	if checked.ok: checked = {"ok": true, "value": reopened.get_profile_snapshot()}
	reopened.free()
	return checked

func _replace_owner(name: String, owner: Node) -> void:
	var original: Node = tree.root.get_node(name)
	original_owners[name] = {"node": original, "index": original.get_index()}
	tree.root.remove_child(original)
	owner.name = name
	tree.root.add_child(owner)

func close() -> void:
	for owner: Node in [game, bridge, manager, profile]:
		if is_instance_valid(owner): owner.free()
	for name: String in ["ProfileManager", "SaveManager"]:
		if not original_owners.has(name): continue
		var original: Node = original_owners[name].node
		if is_instance_valid(original) and original.get_parent() == null:
			tree.root.add_child(original)
			tree.root.move_child(original, mini(original_owners[name].index, tree.root.get_child_count() - 1))
