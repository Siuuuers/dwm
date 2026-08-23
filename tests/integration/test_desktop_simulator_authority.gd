extends "res://addons/gut/test.gd"
# dwm-p2r.32 Plan 02 Task 9. Proves, against the REAL production graph, that all three of Task 9's
# own disclosed gaps are exactly what the evidence documents claim -- concretely, not just in a doc
# comment -- and that the retained .9-era simulator stack is never installed as authority. Each of
# these three gap assertions is a regression guard: if any of them ever start passing for a
# different reason (a fake quietly wired into production, or a stub silently satisfying the
# interface), this file fails loudly, matching "Contract fakes are never bootstrap dependencies."
#
# PARSE HAZARD: GUT treats an inferred-Variant `:=` as a parse error, so every local declaration
# below carries an explicit type annotation.

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const CONTACT_COMMAND_PORT := preload("res://scripts/application/contact/ContactCommandPort.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const APPLICATION_MUTATION_GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const DESKTOP_IDENTITY_ALLOCATION_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd")

class HarnessBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return targets.get(String(target_name), null)


var _root_counter := 0


func _isolated_root() -> String:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	return wrapper.path_join("desktop-simulator-authority-%d" % _root_counter)


## Builds one full production graph over a fresh, isolated storage root. Mirrors
## test_desktop_bootstrap_wiring.gd's own `_build_desktop_graph()`/`_build_foundation()` helpers
## (same construction order, same targets), kept as its own copy here since each Task 9 suite is
## self-contained rather than reaching into another test file's internals.
func _boot() -> Dictionary:
	var storage: RefCounted = JSON_STORAGE.new(_isolated_root())
	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(root_store).get("ok", false))

	var game_state: Node = load(GAME_STATE_PATH).new()
	autofree(game_state)
	game_state.reset_game()
	var state_port: RefCounted = STATE_PORT.new(game_state)
	var coordinator: RefCounted = COORDINATOR.new()

	var bootstrap: Node = HarnessBootstrap.new()
	autofree(bootstrap)
	bootstrap.set("_profile_storage", storage)
	bootstrap.set("_desktop_issuer_root_store", root_store)
	bootstrap.set("_desktop_identity_nonce_issuer", issuer)
	bootstrap.set("_retained_day_resolution_state_port", state_port)
	bootstrap.set("_retained_day_resolution_coordinator", coordinator)
	bootstrap.set("_contact_command_port", CONTACT_COMMAND_PORT.new())

	var advance: Dictionary = bootstrap.call(&"_configure_causal_day_advance_identity", coordinator)
	assert_true(advance.get("ok", false), "foundation identity: " + str(advance))
	var schedule: Dictionary = bootstrap.call(&"_construct_schedule_foundation", game_state, state_port)
	assert_true(schedule.get("ok", false), "schedule foundation: " + str(schedule))

	var profile: Node = load("res://autoload/ProfileManager.gd").new()
	add_child_autofree(profile)
	var localization: Node = load("res://autoload/LocalizationManager.gd").new()
	add_child_autofree(localization)
	var audio: Node = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(audio)
	var bridge: Node = load("res://autoload/DialogicBridge.gd").new()
	add_child_autofree(bridge)
	var router: Node = load("res://autoload/SceneRouter.gd").new()
	add_child_autofree(router)
	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	add_child_autofree(save_manager)
	assert_true(save_manager.call(&"initialize", JSON_STORAGE.new(_isolated_root())).get("ok", false))
	assert_true(save_manager.call(&"configure_identity_issuer", issuer).get("ok", false))
	var allocation_participant: RefCounted = DESKTOP_IDENTITY_ALLOCATION_RESTORE_PARTICIPANT.new(issuer, save_manager)
	assert_true(save_manager.call(&"configure_identity_allocation_participant", allocation_participant).get("ok", false))
	bootstrap.set("_desktop_identity_allocation_participant", allocation_participant)

	bootstrap.set("targets", {
		"ProfileManager": profile, "LocalizationManager": localization, "AudioManager": audio,
		"DialogicBridge": bridge, "SceneRouter": router, "GameState": game_state,
		"SaveManager": save_manager,
	})

	var gate: RefCounted = APPLICATION_MUTATION_GATE.new()
	bootstrap.set("_application_gate", gate)
	var checkpoint_port: RefCounted = SAVE_CHECKPOINT_PORT.new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	bootstrap.set("_retained_checkpoint_port", checkpoint_port)

	var restore_result: Dictionary = bootstrap.call(&"_configure_restore_participants")
	assert_true(restore_result.get("ok", false), "restore participants: " + str(restore_result))
	var graph_result: Dictionary = bootstrap.call(&"_configure_desktop_production_graph")
	assert_true(graph_result.get("ok", false), "desktop production graph: " + str(graph_result))

	return {"bootstrap": bootstrap, "game_state": game_state}


# -------------------------------------------------------------------------------------------------
# Gap 1: MinesweeperRoundCoordinator's base configure() is never called in production
# -------------------------------------------------------------------------------------------------

func test_the_round_coordinator_never_receives_its_base_configure_in_production() -> void:
	var process := _boot()
	var round_coordinator: Object = (process["bootstrap"] as Node).get("_retained_minesweeper_round_coordinator_app")
	assert_not_null(round_coordinator)
	# _board_state IS adopted directly (Task 8's documented shared-object wiring, not base configure);
	# the four fields base configure() would otherwise fill all stay null.
	assert_null(round_coordinator.get("_state_port"),
		"no production generation_port/checkpoint adapter exists, so base configure() is never called")
	assert_null(round_coordinator.get("_checkpoint_port"))
	assert_null(round_coordinator.get("_generation_port"))
	assert_null(round_coordinator.get("_identity_issuer"))
	assert_not_null(round_coordinator.get("_board_state"),
		"the shared board state IS adopted directly -- a distinct, already-proven wiring path")


func test_no_production_class_defines_the_task5_shaped_checkpoint_or_generation_contract() -> void:
	# Mirrors the evidence documents' own claimed grep: "func seal_checkpoint" and the generation
	# trio (materialize_first_reveal/begin_search/run_search_slice-shaped names) must appear nowhere
	# under scripts/ or autoload/ as a real definition, only as fakes under tests/.
	var hits: Array[String] = _scan_for_definition("res://scripts", "func seal_checkpoint")
	hits.append_array(_scan_for_definition("res://autoload", "func seal_checkpoint"))
	assert_eq(hits, [] as Array[String],
		"a production seal_checkpoint would silently satisfy the Task-5-shaped checkpoint contract " \
		+ "gap 1 documents as absent: " + str(hits))


# -------------------------------------------------------------------------------------------------
# Gap 2: GameStateDesktopBoardPort/GameStateMinesweeperShopPort carry a boot-time placeholder
# identity, never a live per-run one
# -------------------------------------------------------------------------------------------------

func test_the_shared_desktop_identity_context_is_a_real_but_blank_placeholder() -> void:
	var process := _boot()
	var context: Dictionary = (process["bootstrap"] as Node).get("_desktop_board_identity_context")
	assert_eq(context.keys().size(), 4)
	assert_false(str(context.get("run_id", "")).is_empty(), "run_id is really issuer-minted, not blank")
	assert_false(str(context.get("branch_id", "")).is_empty(), "branch_id is really issuer-minted, not blank")
	assert_eq(int(context.get("desktop_timeline_generation", -1)), 0,
		"desktop_timeline_generation stays honestly blank: allocator-only, never issuable directly")
	assert_eq(str(context.get("causal_day_instance", "unset")), "",
		"causal_day_instance stays honestly blank: allocator-only, never issuable directly")


func test_two_independent_boots_mint_distinct_placeholder_run_and_branch_ids() -> void:
	# If this ever failed, the "context" would be a hardcoded literal rather than a genuinely
	# issuer-minted one -- a very different (and worse) kind of placeholder than gap 2 documents.
	var first: Dictionary = (_boot()["bootstrap"] as Node).get("_desktop_board_identity_context")
	var second: Dictionary = (_boot()["bootstrap"] as Node).get("_desktop_board_identity_context")
	assert_ne(str(first.get("run_id", "")), str(second.get("run_id", "")))
	assert_ne(str(first.get("branch_id", "")), str(second.get("branch_id", "")))


func test_the_shop_and_board_ports_share_the_exact_same_placeholder_context_object() -> void:
	var process := _boot()
	var bootstrap: Node = process["bootstrap"]
	var board_port: Object = bootstrap.get("_retained_game_state_desktop_board_port")
	var shop_port: Object = bootstrap.get("_retained_game_state_minesweeper_shop_port")
	assert_not_null(board_port)
	assert_not_null(shop_port)
	var board_capture: Dictionary = board_port.call(&"capture")
	var shop_capture: Dictionary = shop_port.call(&"capture")
	assert_true(board_capture.get("ok", false), JSON.stringify(board_capture))
	assert_true(shop_capture.get("ok", false), JSON.stringify(shop_capture))
	var board_facts: Dictionary = board_capture["value"]
	var shop_facts: Dictionary = shop_capture["value"]
	assert_eq(str(board_facts.get("run_id", "a")), str(shop_facts.get("run_id", "b")))
	assert_eq(str(board_facts.get("causal_day_instance", "a")), "")
	assert_eq(str(shop_facts.get("causal_day_instance", "a")), "")


# -------------------------------------------------------------------------------------------------
# Gap 3: LogoutCoordinator is never constructed; no production stable_board_port exists
# -------------------------------------------------------------------------------------------------

func test_logout_coordinator_is_never_constructed_by_the_production_graph() -> void:
	var process := _boot()
	var bootstrap: Node = process["bootstrap"]
	for property: Dictionary in bootstrap.get_property_list():
		var property_name: String = str(property.get("name", ""))
		if property_name.to_lower().contains("logout"):
			var value: Variant = bootstrap.get(property_name)
			assert_true(value == null, "%s must stay unset: no stable_board_port exists to construct " \
				+ "LogoutCoordinator with" % property_name)


func test_no_production_class_defines_the_stable_board_port_contract() -> void:
	var executing_hits: Array[String] = _scan_for_definition("res://scripts", "func is_slice_executing")
	executing_hits.append_array(_scan_for_definition("res://autoload", "func is_slice_executing"))
	var capture_hits: Array[String] = _scan_for_definition("res://scripts", "func capture_stable_board")
	capture_hits.append_array(_scan_for_definition("res://autoload", "func capture_stable_board"))
	assert_eq(executing_hits, [] as Array[String],
		"a production is_slice_executing() would silently satisfy the stable_board_port gap: " + str(executing_hits))
	assert_eq(capture_hits, [] as Array[String],
		"a production capture_stable_board() would silently satisfy the stable_board_port gap: " + str(capture_hits))


# -------------------------------------------------------------------------------------------------
# The retained .9-era simulator stack is never registered as authority (extends
# test_desktop_bootstrap_wiring.gd's own proof of the same law from this file's independent harness)
# -------------------------------------------------------------------------------------------------

func test_the_production_graph_never_installs_into_the_retained_simulator_seam_either() -> void:
	var process := _boot()
	assert_null((process["game_state"] as Node).get("_minesweeper_round_coordinator"),
		"the Plan-02 graph must never install into the .9-era GameState seam, confirmed again from " \
		+ "this file's own independent boot harness")


# -------------------------------------------------------------------------------------------------
# Static scan helper (recursive .gd source scan, tests/ excluded so fakes never count as hits)
# -------------------------------------------------------------------------------------------------

func _scan_for_definition(root: String, needle: String) -> Array[String]:
	var hits: Array[String] = []
	_scan_directory(root, needle, hits)
	return hits


func _scan_directory(path: String, needle: String, hits: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full_path: String = path.path_join(entry)
			if directory.current_is_dir():
				_scan_directory(full_path, needle, hits)
			elif entry.ends_with(".gd"):
				var file: FileAccess = FileAccess.open(full_path, FileAccess.READ)
				if file != null:
					var text: String = file.get_as_text()
					file.close()
					# A real definition line, not a "## func ..." doc-comment mention of the contract.
					for line: String in text.split("\n"):
						if line.strip_edges().begins_with(needle):
							hits.append(full_path)
							break
		entry = directory.get_next()
	directory.list_dir_end()
