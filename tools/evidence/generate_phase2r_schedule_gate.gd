extends SceneTree

## Generator for evidence/phase_2r/schedule/gate.json (Plan 01 Task 9 Steps 9.1-9.2, dwm-p2r.15).
##
## Runs via `-s`, so this file extends SceneTree and does its work in `_init()`. CONSEQUENCE FOR
## TESTS: load this file with DynamicScriptProbe.load_script() or `load()` and NEVER instantiate()
## -- instantiating constructs a SceneTree and executes the tool. The statics below are the real
## implementation and `_init()` is a thin shell over OS.get_cmdline_user_args().
##
## WHAT THE RECORD IS. One deterministic, source-bound description of the Phase-2R committed
## Schedule foundation at exactly one subject commit: every bound source read with
## `git cat-file blob <subject_commit>:<path>` (never HEAD, never the working tree), the canonical
## Plan-01 child-derivation matrix parsed out of the committed plan text and hashed byte-exactly
## per the plan's delimiter law, a `git grep` census of every production `derive_child` site, the
## v3 boundary re-validated from its own recorded commit, and four fresh GUT logs -- committed
## beside the record under evidence/phase_2r/logs/ so the seal re-verifies on a clean checkout --
## parsed for counts, executed suites, test names, and the observed provenance/publication
## vectors the gate test prints. No semantic fact is accepted from the caller: the CLI carries
## only the output path, the Beads snapshot path, the subject commit, and the optional --check.
##
## WHAT THE RED LOG PROVES, exactly. The bound RED is the gate suite run with the required-surface
## manifest restored to its pre-Task-9 bytes: one test red (the six unclassified Task-4 GameState
## seams), 33 already green. It is the RED of the manifest half of Step 9.1 and nothing more; the
## parser, vector and binding halves were RED-proven by production/plan mutations recorded on
## dwm-p2r.15, not by this log. A RED with a load failure is refused as invalid evidence.
##
## KNOWN LIMITS, stated rather than hidden. --check binds the Beads chain statuses at generation,
## so it is valid until dwm-p2r.15 closes and historical afterwards (like the .13 boundary);
## it also needs the quarantined feat/p2r7-strict-schedule-validation ref to resolve. Several
## members (ownership reservations, readiness) are attestations frozen by schema constants and
## cross-checked against the bound bootstrap-identity log's executed test names, not parsed facts.
## BEADS_CHAIN adds the discovered dwm-p2r.18 to the plan's chain because .15 depends on it.
## generated_surface hashes the co-generated game_state_surface.json from the working tree: it is
## a sibling generated artifact committed beside this record, not a source, so the plan's
## never-hash-working-tree law (which governs sources) is knowingly not applied to it.
##
## WHAT IT REFUSES TO CLAIM. Two matrix rows have no issuer-anchored production producer at this
## subject: `P01.day_resolution.stage` (DEVIATION-4 on dwm-p2r.14/.18: stage transaction ids are
## synthetic strings) and `P01.hospital.sylvia_witness` (the realized witness is a twelve-member
## fact record written by HospitalRules, not a derived child). They are recorded as `unrealized`
## with their deviation reference and carry no observed vector. Numeric instance ids are never
## serialized; the bootstrap probe is bound by its key set and owner classes only.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")
const _REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

const SCHEMA_VERSION := 1
const EVIDENCE_ID := "phase2r.schedule.gate.v1"
const OWNER_BEADS_ID := "dwm-p2r.15"
const SUBJECT_COMMIT_SUBJECT := "test(schedule): define the Phase-2R committed Schedule gate"
const EVIDENCE_COMMIT_SUBJECT := "test(schedule): seal the Phase-2R committed Schedule gate"
const OUTPUT_PATH := "res://evidence/phase_2r/schedule/gate.json"
const OUTPUT_RELATIVE := "evidence/phase_2r/schedule/gate.json"
const GATE_TEST_PATH := "res://tests/unit/tooling/test_phase2r_schedule_gate.gd"

const PLAN_PATH := "docs/superpowers/plans/2026-08-11-desktop-minesweeper-shop-schedule-01-phase2r-schedule-foundation.md"
const MATRIX_BEGIN_PAYLOAD := "PLAN01_CHILD_DERIVATION_MATRIX_V1_BEGIN"
const MATRIX_END_PAYLOAD := "PLAN01_CHILD_DERIVATION_MATRIX_V1_END"
const MATRIX_ROW_COUNT := 13

const V3_BOUNDARY_RECORD_PATH := "evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json"
const V3_BOUNDARY_OWNER := "dwm-p2r.13"
const V3_BOUNDARY_SUBJECT := "feat(save): persist canonical committed Schedule"
const REQUIRED_SURFACE_PATH := "evidence/phase_2r/runtime/game_state_required_surface.json"
const REGISTRY_MANIFEST_PATH := "data/manifests/schedule_actions.v1.json"
const REGISTRY_SCHEMA_PATH := "schemas/manifests/schedule-actions.schema.json"
const LEDGER_SCHEMA_PATH := "schemas/save/schedule-foundation-publication-ledger.schema.json"
const STRICT_BRANCH := "feat/p2r7-strict-schedule-validation"
const STRICT_BRANCH_MERGE_BASE_PREFIX := "49947e5"
const STRICT_BRANCH_TIP_PREFIX := "5e9ab64"
const LOG_DIRECTORY := "res://evidence/phase_2r/logs"
const LOG_RELATIVE_DIRECTORY := "evidence/phase_2r/logs"
const PUBLICATION_MARKER := "P2R15_OBSERVED_PUBLICATION:"
const GENERATED_SURFACE_PATH := "res://evidence/phase_2r/runtime/game_state_surface.json"
const GENERATED_SURFACE_RELATIVE := "evidence/phase_2r/runtime/game_state_surface.json"
const VECTOR_MARKER := "P2R15_OBSERVED_VECTOR:"
const FIXTURE_ROOTS := ["tests/fixtures/snapshots", "tests/fixtures/saves"]

## The Beads chain this plan names, in plan order, plus the discovered .18 that .15 also depends on.
const BEADS_CHAIN := [
	"dwm-p2r.12", "dwm-wks", "dwm-p2r.16", "dwm-p2r.13", "dwm-p2r.9", "dwm-p2r.14", "dwm-p2r.18",
	"dwm-p2r.15", "dwm-p2r.7",
]
const EXCLUSIONS := [
	"ScheduleView warnings or final Done composition", "final ending selection or playback",
	"new product behavior", "waived diagnostics", "unverified migration",
]
const DAY_1_6_STAGES := [
	"lock_day", "validate_schedule", "execute_schedule_actions", "commit_outcomes",
	"hospital_if_triggered", "execute_schedule_dates", "twofriends_if_deferred", "invitation_rollover",
	"increment_day", "reset_day_scope", "new_day_autosave", "unlock_day",
]
const DAY_7_STAGES := [
	"lock_day", "validate_schedule", "close_invitations_run_end", "validate_day7_provenance",
	"checkpoint_day7_provenance",
]
## Ending-composition stage names that still have contract/branch residue in the two Plan-01
## run ports but are reachable from NO stage array (DEVIATION-3 on dwm-p2r.14: Day 7 no longer
## enters ENDING). They are sealed as retired-dead rather than silently tolerated.
const RETIRED_ENDING_STAGES := ["resolve_ending_plan", "enter_ending", "ending_autosave"]
const REQUIREMENT_IDS := [
	"req.save.schedule_state", "req.save.schedule_migration", "req.schedule.validation",
	"req.schedule.done_commit", "req.schedule.day7_provenance", "req.test.schedule_foundation_gate",
]

## Every bound production source, by repository-relative path. Each is hashed and its declared
## surface (column-zero `signal`, `func`, `static func`, plus the `_init` constructor) recorded.
const SOURCE_PATHS := [
	"autoload/ApplicationBootstrap.gd",
	"autoload/DialogicBridge.gd",
	"autoload/GameState.gd",
	"scripts/application/desktop/DesktopIdentityNonceIssuer.gd",
	"scripts/application/narrative/DialogicPresentationOwnerAdapter.gd",
	"scripts/application/run/CausalDayAdvanceIdentityPort.gd",
	"scripts/application/run/DatingPresentationPort.gd",
	"scripts/application/run/DayResolutionCoordinator.gd",
	"scripts/application/run/DayResolutionStartPort.gd",
	"scripts/application/run/GameStateDayResolutionPort.gd",
	"scripts/application/run/HospitalPresentationPort.gd",
	"scripts/application/schedule/GameStateScheduleCommitPort.gd",
	"scripts/domain/contact/ContactInvitationState.gd",
	"scripts/domain/hospital/HospitalRules.gd",
	"scripts/domain/run/DayResolutionPlan.gd",
	"scripts/domain/run/RunSnapshotSchema.gd",
	"scripts/domain/schedule/Day7ScheduleProvenance.gd",
	"scripts/domain/schedule/ScheduleActionRegistry.gd",
	"scripts/domain/schedule/ScheduleRules.gd",
	"scripts/domain/schedule/ScheduleStateSchema.gd",
	"scripts/infrastructure/save/SaveDocumentSchema.gd",
	"scripts/infrastructure/save/SaveMigrations.gd",
	"scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd",
]

## Declared-surface entries that must be PRESENT in the named source, in the exact frozen form the
## surface parser emits (types stripped, parameter names kept, no spaces after commas).
const REQUIRED_SURFACE_ENTRIES := {
	"scripts/domain/schedule/ScheduleActionRegistry.gd": [
		"static func load_current()", "static func from_manifest(manifest)", "func fingerprint()",
		"func find_record(action_id)",
	],
	"scripts/domain/schedule/ScheduleRules.gd": [
		"static func validate_draft(day,entries,registry,expected_fingerprint,source_receipts)",
		"static func validate_draft_candidate(day,existing,candidate,registry,expected_fingerprint,source_receipts)",
		"static func validate_committed(committed_schedule,registry,source_receipts)",
		"static func build_route_plan(committed_schedule,registry)",
	],
	"scripts/domain/schedule/Day7ScheduleProvenance.gd": [
		"func configure(action_registry,identity_issuer)", "func validate_handoff(request)",
	],
	"scripts/application/schedule/GameStateScheduleCommitPort.gd": [
		"func _init(game_state,action_registry,identity_issuer,publication_ledger)",
		"func prepare_commit(request)", "func capture()", "func commit(candidate)",
		"func rollback(backup)", "func publish(publication)",
	],
	"scripts/application/run/DayResolutionStartPort.gd": [
		"func _init(state_port,action_registry,identity_issuer,publication_ledger)",
		"func prepare_from_committed_schedule(request)", "func capture()", "func commit(candidate)",
		"func rollback(backup)", "func publish(publication)",
	],
	"scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd": [
		"func configure(storage)", "func load()", "func record_before_emit(request)",
	],
	"scripts/application/run/CausalDayAdvanceIdentityPort.gd": [
		"func configure(identity_issuer)", "func prepare_advance(request)",
		"func commit_advance(candidate)",
	],
	"scripts/application/run/DayResolutionCoordinator.gd": [
		"func configure(state_port,checkpoint_port,mutation_gate)",
		"func configure_day_advance_identity_port(day_advance_identity_port)",
		"func configure_presentation_ports(hospital_port,dating_port)",
		"func verify_configuration(state_port,checkpoint_port,mutation_gate)", "func resume()",
	],
	"scripts/application/run/HospitalPresentationPort.gd": [
		"signal completion_ready(completion_result)", "signal completion_failed(failure)",
		"func configure(identity_issuer,physical_owner)", "func begin(request)",
		"func complete(request)",
	],
	"scripts/application/run/DatingPresentationPort.gd": [
		"signal completion_ready(completion_result)", "signal completion_failed(failure)",
		"func configure(identity_issuer,physical_owner)", "func begin(request)",
		"func complete(request)",
	],
	"scripts/application/narrative/DialogicPresentationOwnerAdapter.gd": [
		"signal physical_completion_ready(receipt)", "signal physical_completion_failed(failure)",
		"func begin_physical(command)", "func validate_physical_completion(request)",
	],
	"scripts/application/desktop/DesktopIdentityNonceIssuer.gd": [
		"func issue(purpose)", "func verify_issued(receipt,expected_purpose)",
		"func derive_child(request)", "func validate_child(provenance,expected_kind)",
	],
	"autoload/GameState.gd": [
		"signal committed_schedule_published(result)", "func capture_schedule_commit_state()",
		"func prepare_schedule_commit_candidate(committed,motivation_charged)",
		"func commit_schedule_commit_candidate(candidate)",
		"func rollback_schedule_commit_state(backup)", "func publish_schedule_commit(publication)",
		"func request_schedule_done(command_id)", "func resume_day_resolution()",
		"func begin_day_resolution_stage()",
		"func complete_day_resolution_stage(transaction_id,receipt)",
	],
	"autoload/ApplicationBootstrap.gd": ["func get_desktop_contract_state()"],
	"autoload/DialogicBridge.gd": ["signal timeline_finished(timeline_id,result)"],
}

## Symbols that must be ABSENT from the declared surface of the named source. A private
## (underscore-prefixed) definition is not a public declaration, so "absent" here also covers the
## plan's "absent/private" classification.
const ABSENT_SURFACE_SYMBOLS := {
	"scripts/application/run/DayResolutionCoordinator.gd": [
		"get_state_port", "resume_from_publication", "resume_publication",
	],
	"autoload/DialogicBridge.gd": ["finish_current_timeline"],
	"autoload/GameState.gd": [
		"validate_date_candidate", "clear_schedule_with_refund", "clear_schedule_without_refund",
		"add_schedule_action", "add_schedule_date_entry", "remove_schedule_entry",
		"choose_contact_option", "execute_schedule_entries",
	],
	"scripts/application/run/GameStateDayResolutionPort.gd": [
		"resume_from_publication", "resume_publication", "execute_schedule_entries",
	],
	"scripts/domain/run/DayResolutionPlan.gd": ["execute_schedule_entries"],
}

## Tokens that must not appear in the executable (comment-stripped) text of the named sources.
const FORBIDDEN_SOURCE_TOKENS := {
	"scripts/application/run/GameStateDayResolutionPort.gd": [
		"DatingEndingRules", "_SCHEDULE_ACTION_EFFECTS", "schedule_entries", "date_completed",
		"\"twofriends\"", "issue(&\"causal_day_instance\")",
	],
	"scripts/application/run/DayResolutionCoordinator.gd": [
		"DatingEndingRules", "schedule_entries", "issue(&\"causal_day_instance\")",
	],
	"scripts/application/run/DayResolutionStartPort.gd": [
		"DatingEndingRules", "schedule_entries", "begin_day_resolution(",
	],
	"scripts/application/schedule/GameStateScheduleCommitPort.gd": [
		"schedule_entries", "validate_date_candidate", "_SCHEDULE_ACTION_EFFECTS",
	],
	"scripts/domain/schedule/ScheduleStateSchema.gd": [
		"schedule_entries", "route_id", "effect_ids", "motivation_cost", "unlock_receipt_id",
		"date_completed",
	],
	"scripts/domain/schedule/Day7ScheduleProvenance.gd": [
		"DatingEndingRules", "date_completed", "ending_id", "dark_mode",
	],
	"scripts/domain/run/DayResolutionPlan.gd": ["schedule_entries"],
	"scripts/application/run/HospitalPresentationPort.gd": ["start_timeline", "GameState"],
	"scripts/application/run/DatingPresentationPort.gd": ["start_timeline", "GameState"],
	"scripts/domain/hospital/HospitalRules.gd": ["derive_child", "issue(", "GameState"],
}

## The 13 stable matrix rows: which production source realizes each (by its exact role literal),
## or the recorded deviation when no issuer-anchored producer exists at this subject.
const ROW_REALIZATIONS := {
	"P01.contact_source.solo": {"role": "contact_source.solo",
		"producers": ["scripts/domain/contact/ContactInvitationState.gd"]},
	"P01.contact_source.group": {"role": "contact_source.group",
		"producers": ["scripts/domain/contact/ContactInvitationState.gd"]},
	"P01.schedule.entry": {"role": "schedule.entry",
		"producers": ["scripts/application/schedule/GameStateScheduleCommitPort.gd"]},
	"P01.schedule.commit": {"role": "schedule.commit",
		"producers": ["scripts/application/schedule/GameStateScheduleCommitPort.gd"]},
	"P01.schedule.empty_done": {"role": "schedule.empty_done",
		"producers": ["scripts/application/schedule/GameStateScheduleCommitPort.gd"]},
	"P01.schedule.day7_provenance": {"role": "schedule.day7_provenance",
		"producers": ["scripts/domain/schedule/Day7ScheduleProvenance.gd"]},
	"P01.day_resolution.start": {"role": "day_resolution.start",
		"producers": ["scripts/application/run/DayResolutionStartPort.gd"]},
	"P01.day_resolution.stage": {"role": "day_resolution.stage", "producers": [],
		"deviation": "DEVIATION-4 (dwm-p2r.14 Task 8 checkpoint 1, 2026-08-18; reaffirmed at the dwm-p2r.18 close 2026-08-21): DayResolutionPlan persists synthetic stage/substage transaction ids, so no P01.day_resolution.stage child is derived in production"},
	"P01.hospital.resolution": {"role": "hospital.resolution",
		"producers": ["scripts/application/run/GameStateDayResolutionPort.gd"]},
	"P01.hospital.miss": {"role": "hospital.miss",
		"producers": ["scripts/application/run/GameStateDayResolutionPort.gd"]},
	"P01.hospital.sylvia_witness": {"role": "hospital.sylvia_witness", "producers": [],
		"deviation": "dwm-p2r.14 Task 7 checkpoints 4-6 (2026-08-18): HospitalRules writes a twelve-member witness fact record into contacts.sylvia_hospital_witness_receipts keyed by the Hospital stage transaction; it carries no issuer-derived receipt_id/receipt_provenance, so no P01.hospital.sylvia_witness child is derived in production"},
	"P01.presentation.intent": {"role": "presentation.intent",
		"producers": ["scripts/application/run/GameStateDayResolutionPort.gd"]},
	"P01.presentation.completion": {"role": "presentation.completion",
		"producers": ["scripts/application/run/GameStateDayResolutionPort.gd"],
		"validators": ["scripts/application/run/HospitalPresentationPort.gd",
			"scripts/application/run/DatingPresentationPort.gd"]},
}

## The fresh logs the record binds, by fixed log name under LOG_DIRECTORY (tracked; committed in
## the Step-9.7 evidence commit). `expect` is red (the gate suite with the manifest at its
## pre-Task-9 bytes: exactly the manifest-classification test fails, no load failure) or green
## (every requested suite executed, nothing failed, no load failure). All GREENs run at the subject
## commit before generation; the Step-9.3 21-suite log runs AFTER generation and is therefore
## recorded on the bead, not bound here.
const COMMAND_BINDINGS := [
	{"suite_id": "phase2r_schedule_gate_red", "log_name": "p2r15-schedule-gate-red.log",
		"expect": "red", "suites": ["res://tests/unit/tooling/test_phase2r_schedule_gate.gd"]},
	{"suite_id": "phase2r_schedule_gate_green", "log_name": "p2r15-schedule-gate-green.log",
		"expect": "green", "suites": ["res://tests/unit/tooling/test_phase2r_schedule_gate.gd"]},
	{"suite_id": "phase2r_schedule_foundation_green",
		"log_name": "p2r15-schedule-foundation-green.log", "expect": "green",
		"suites": [
			"res://tests/unit/test_schedule_action_registry.gd",
			"res://tests/unit/tooling/test_schedule_action_manifest.gd",
			"res://tests/unit/test_schedule_strict_validation.gd",
			"res://tests/unit/test_schedule_source_receipts.gd",
			"res://tests/unit/test_schedule_state_schema.gd",
			"res://tests/unit/test_schedule_foundation_publication_ledger.gd",
			"res://tests/unit/test_game_state_schedule_commit_port.gd",
			"res://tests/unit/test_day_resolution_start_port.gd",
			"res://tests/unit/test_day7_schedule_provenance.gd",
			"res://tests/unit/test_hospital_rules.gd",
			"res://tests/unit/test_run_snapshot_schema.gd",
			"res://tests/unit/test_save_migrations.gd",
			"res://tests/integration/test_schedule_publication_restart.gd",
			"res://tests/integration/test_schedule_foundation_bootstrap_wiring.gd",
			"res://tests/integration/test_committed_schedule_day_resolution.gd",
			"res://tests/integration/test_committed_schedule_effect_order.gd",
			"res://tests/scenario/test_hospital_invitation_closures.gd",
			"res://tests/scenario/test_hospital_twofriends_order.gd",
			"res://tests/scenario/test_day7_schedule_provenance.gd",
			"res://tests/unit/tooling/test_public_surface_inventory.gd",
		]},
	{"suite_id": "phase2r_bootstrap_identity_green",
		"log_name": "p2r15-bootstrap-identity-green.log", "expect": "green",
		"suites": [
			"res://tests/integration/test_desktop_bootstrap_wiring.gd",
			"res://tests/integration/test_schedule_foundation_bootstrap_wiring.gd",
			"res://tests/integration/test_schedule_presentation_bootstrap_wiring.gd",
		]},
]

## The two bootstrap-wiring tests whose names must appear in the bound bootstrap-identity log for
## the readiness attestation to stand.
const READINESS_ATTESTING_TESTS := [
	"test_the_probe_reports_hospital_ready_and_dating_deliberately_not_ready",
	"test_the_probe_reports_the_presentation_producer_as_deliberately_not_ready",
]
## Frozen publication vectors the gate test observes over the real ledger and ports.
const PUBLICATION_BINDINGS := [
	{"owner": "ledger", "kind": "schedule_commit", "first_delivery_sequence": [true, false],
		"signal": "", "signal_counts": [], "conflict_code": "publication_record_conflict"},
	{"owner": "ledger", "kind": "day_resolution_start", "first_delivery_sequence": [true, false],
		"signal": "", "signal_counts": [], "conflict_code": "publication_record_conflict"},
	{"owner": "schedule_commit_port", "kind": "schedule_commit", "first_delivery_sequence": [true, false],
		"signal": "committed_schedule_published", "signal_counts": [1, 1],
		"conflict_code": "schedule_publication_conflict"},
	{"owner": "day_resolution_start_port", "kind": "day_resolution_start", "first_delivery_sequence": [true, false],
		"signal": "save_relevant_state_changed", "signal_counts": [1, 1],
		"conflict_code": "day_resolution_start_publication_conflict"},
]
const BOOTSTRAP_PROBE_KEYS := [
	"root_store_instance_id", "issuer_instance_id", "contact_command_port_instance_id",
	"schedule_registry_instance_id", "publication_ledger_instance_id",
	"schedule_port_instance_id", "day_resolution_start_port_instance_id",
	"provenance_owner_instance_id", "day_resolution_state_port_instance_id",
	"day_resolution_coordinator_instance_id", "causal_day_advance_identity_port_instance_id",
	"presentation_owner_adapter_instance_id", "hospital_presentation_port_instance_id",
	"dating_presentation_port_instance_id", "hospital_presentation_ready",
	"dating_presentation_ready", "presentation_producer_ready",
]
## Owner class per retained-object probe key (the class bound at that seam, never its instance id).
const BOOTSTRAP_PROBE_OWNERS := {
	"root_store_instance_id": "scripts/infrastructure/identity/DesktopIssuerRootStore.gd",
	"issuer_instance_id": "scripts/application/desktop/DesktopIdentityNonceIssuer.gd",
	"contact_command_port_instance_id": "scripts/application/contact/ContactCommandPort.gd",
	"schedule_registry_instance_id": "scripts/domain/schedule/ScheduleActionRegistry.gd",
	"publication_ledger_instance_id": "scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd",
	"schedule_port_instance_id": "scripts/application/schedule/GameStateScheduleCommitPort.gd",
	"day_resolution_start_port_instance_id": "scripts/application/run/DayResolutionStartPort.gd",
	"provenance_owner_instance_id": "scripts/domain/schedule/Day7ScheduleProvenance.gd",
	"day_resolution_state_port_instance_id": "scripts/application/run/GameStateDayResolutionPort.gd",
	"day_resolution_coordinator_instance_id": "scripts/application/run/DayResolutionCoordinator.gd",
	"causal_day_advance_identity_port_instance_id": "scripts/application/run/CausalDayAdvanceIdentityPort.gd",
	"presentation_owner_adapter_instance_id": "scripts/application/narrative/DialogicPresentationOwnerAdapter.gd",
	"hospital_presentation_port_instance_id": "scripts/application/run/HospitalPresentationPort.gd",
	"dating_presentation_port_instance_id": "scripts/application/run/DatingPresentationPort.gd",
}

const COMMITTED_ENTRY_KEYS := [
	"action_id", "action_kind", "commit_transaction_id", "day", "participants",
	"schedule_entry_id", "schedule_entry_provenance", "slot_index", "source_receipt_id", "state",
]
const COMMITTED_AGGREGATE_KEYS := [
	"commit_receipt", "day", "entries", "registry_fingerprint", "schema_version",
]
const CALLER_OWNED_ENTRY_FIELDS := ["route_id", "effect_ids", "motivation_cost"]

const RECORD_KEYS := [
	"beads_chain", "bootstrap_probe", "commands", "current_versions", "dating_presentation",
	"day7_provenance", "day_advance_identity", "day_resolution_stages", "derivation_matrix",
	"derive_child_census", "evidence_id", "exclusions", "fixtures", "generated_surface",
	"observed_publications", "observed_vectors", "owner_beads_id",
	"plan01_child_derivation_matrix_sha256", "plan_path", "plan_sha256", "publication_ledger",
	"registry", "required_surface", "requirement_ids", "schedule_state_schema", "schema_version",
	"source_bindings", "strict_branch", "subject_commit", "subject_commit_subject", "sylvia_witness",
	"symbol_classifications", "v3_boundary",
]

const _VALUED_FLAGS := ["output", "beads-snapshot", "subject-commit"]


# =================================================================================================
# CLI contract
# =================================================================================================

## Accepts exactly --output=, --beads-snapshot=, --subject-commit= and the optional bare --check.
## Any other token, a duplicate, a blank value, or a missing required flag is rejected.
static func parse_arguments(args: PackedStringArray) -> Dictionary:
	var values: Dictionary = {}
	var check: bool = false
	for raw_argument: String in args:
		var argument: String = String(raw_argument)
		if argument == "--check":
			if check:
				return _fail(&"duplicate_generator_argument", "--check is supplied twice", {})
			check = true
			continue
		var split_at: int = argument.find("=")
		if not argument.begins_with("--") or split_at < 0:
			return _fail(&"unknown_generator_argument", "the argument is not part of the contract",
				{"argument": argument})
		var flag: String = argument.substr(2, split_at - 2)
		if not (flag in _VALUED_FLAGS):
			return _fail(&"unknown_generator_argument", "the flag is not part of the contract",
				{"flag": flag})
		if values.has(flag):
			return _fail(&"duplicate_generator_argument", "a flag is supplied twice", {"flag": flag})
		var value: String = argument.substr(split_at + 1)
		if value.is_empty():
			return _fail(&"blank_generator_argument", "a flag value is never blank", {"flag": flag})
		values[flag] = value
	for required: String in _VALUED_FLAGS:
		if not values.has(required):
			return _fail(&"missing_generator_argument", "a required flag is absent",
				{"flag": required})
	return _ok({
		"output": str(values["output"]),
		"beads_snapshot": str(values["beads-snapshot"]),
		"subject_commit": str(values["subject-commit"]),
		"check": check,
	})


# =================================================================================================
# Pure parsers
# =================================================================================================

## Declared surface of a GDScript source: column-zero `signal`, `func`, and `static func` lines,
## excluding underscore-prefixed names EXCEPT the `_init` constructor (the plan binds the exact
## four-dependency constructors). Parameter types and defaults are stripped; names are kept and
## joined with a bare comma. A parameter list that wraps across lines is joined before parsing.
## Returns value={entries:Array[String], preimage:String, sha256:String}.
static func parse_declared_surface(source_text: String) -> Dictionary:
	var entries: Array[String] = []
	var lines: PackedStringArray = source_text.split("\n")
	var index: int = 0
	while index < lines.size():
		var line: String = lines[index]
		index += 1
		var kind: String = ""
		var rest: String = ""
		if line.begins_with("signal "):
			kind = "signal"
			rest = line.substr(7)
		elif line.begins_with("static func "):
			kind = "static func"
			rest = line.substr(12)
		elif line.begins_with("func "):
			kind = "func"
			rest = line.substr(5)
		else:
			continue
		var open_at: int = rest.find("(")
		if open_at < 0:
			if kind == "signal":
				var bare_name: String = rest.strip_edges().trim_suffix(":").strip_edges()
				if not bare_name.begins_with("_"):
					entries.append("%s %s()" % [kind, bare_name])
			continue
		var name: String = rest.substr(0, open_at).strip_edges()
		if name.begins_with("_") and name != "_init":
			continue
		var joined: String = rest
		while _paren_depth(joined) > 0 and index < lines.size():
			joined += " " + lines[index].strip_edges()
			index += 1
		var close_at: int = _matching_close(joined, open_at)
		if close_at < 0:
			continue
		var parameter_text: String = joined.substr(open_at + 1, close_at - open_at - 1)
		var names: PackedStringArray = PackedStringArray()
		for parameter: String in _split_parameters(parameter_text):
			var trimmed: String = parameter.strip_edges()
			if trimmed.is_empty():
				continue
			var cut: int = trimmed.length()
			var colon_at: int = trimmed.find(":")
			if colon_at >= 0:
				cut = colon_at
			var equals_at: int = trimmed.find("=")
			if equals_at >= 0 and equals_at < cut:
				cut = equals_at
			names.append(trimmed.substr(0, cut).strip_edges())
		entries.append("%s %s(%s)" % [kind, name, ",".join(names)])
	var preimage: String = ""
	for entry: String in entries:
		preimage += entry + "\n"
	return _ok({"entries": entries, "preimage": preimage, "sha256": _digest(preimage)})


## Strips `#` comments (outside string literals) so token scans see executable text only.
static func strip_comments(source_text: String) -> String:
	var output: PackedStringArray = PackedStringArray()
	for line: String in source_text.split("\n"):
		var in_string: String = ""
		var cut: int = line.length()
		var position: int = 0
		while position < line.length():
			var character: String = line[position]
			if in_string.is_empty():
				if character == "\"" or character == "'":
					in_string = character
				elif character == "#":
					cut = position
					break
			elif character == "\\":
				position += 1
			elif character == in_string:
				in_string = ""
			position += 1
		output.append(line.substr(0, cut))
	return "\n".join(output)


## Selects the exact matrix blob bytes per the plan's construction: each delimiter is the UTF-8 of
## "<!-- " + payload + " -->", occurs exactly once, BEGIN precedes END, and the blob is every byte
## strictly after the LF ending the BEGIN delimiter through the LF immediately before the END
## delimiter. Nothing is decoded, normalized, or BOM-adjusted. Returns value={bytes, sha256}.
static func extract_matrix_blob(plan_bytes: PackedByteArray) -> Dictionary:
	var begin_delimiter: PackedByteArray = ("<!-- %s -->" % MATRIX_BEGIN_PAYLOAD).to_utf8_buffer()
	var end_delimiter: PackedByteArray = ("<!-- %s -->" % MATRIX_END_PAYLOAD).to_utf8_buffer()
	var begin_hits: Array[int] = _find_all(plan_bytes, begin_delimiter)
	var end_hits: Array[int] = _find_all(plan_bytes, end_delimiter)
	if begin_hits.size() != 1:
		return _fail(&"matrix_begin_delimiter_count", "the BEGIN delimiter must occur exactly once",
			{"count": begin_hits.size()})
	if end_hits.size() != 1:
		return _fail(&"matrix_end_delimiter_count", "the END delimiter must occur exactly once",
			{"count": end_hits.size()})
	var begin_end: int = begin_hits[0] + begin_delimiter.size()
	var end_start: int = end_hits[0]
	if end_start <= begin_hits[0]:
		return _fail(&"matrix_delimiter_order", "BEGIN must precede END", {})
	# The LF that ends the BEGIN delimiter line must be immediately adjacent (a lone CR before it is
	# tolerated so a CRLF plan is neither normalized nor rejected); trailing text on that line would
	# otherwise be silently excluded from the hashed blob.
	var lf_after_begin: int = -1
	if begin_end < plan_bytes.size() and plan_bytes[begin_end] == 0x0a:
		lf_after_begin = begin_end
	elif begin_end + 1 < plan_bytes.size() and plan_bytes[begin_end] == 0x0d and plan_bytes[begin_end + 1] == 0x0a:
		lf_after_begin = begin_end + 1
	if lf_after_begin < 0 or lf_after_begin >= end_start:
		return _fail(&"matrix_begin_line_unterminated", "the BEGIN delimiter line must end in LF immediately after the delimiter", {})
	if end_start < 1 or plan_bytes[end_start - 1] != 0x0a:
		return _fail(&"matrix_end_line_not_preceded_by_lf",
			"the END delimiter must be preceded by LF", {})
	var blob: PackedByteArray = plan_bytes.slice(lf_after_begin + 1, end_start)
	return _ok({"bytes": blob, "sha256": _digest_bytes(blob)})


## Parses the matrix table rows out of the blob text. Each table row starts with "| `P01." and
## carries five cells: row id / production child, parent, child kind, ordinal law, source list.
## Source paths are the first argument of every `P("path",...)` token in cell order.
static func parse_matrix_rows(blob_text: String) -> Dictionary:
	var rows: Array[Dictionary] = []
	var seen: Dictionary = {}
	var path_pattern: RegEx = RegEx.create_from_string("P\\(\"([a-z0-9_]+)\",")
	for raw_line: String in blob_text.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.begins_with("| `P01."):
			continue
		var cells: PackedStringArray = line.split("|")
		if cells.size() != 7:
			return _fail(&"matrix_row_shape", "a matrix row must carry exactly five cells",
				{"line": line})
		var head: String = cells[1].strip_edges()
		var first_tick: int = head.find("`")
		var second_tick: int = head.find("`", first_tick + 1)
		if first_tick < 0 or second_tick < 0:
			return _fail(&"matrix_row_id_unparsable", "a row id must be backticked", {"line": line})
		var row_id: String = head.substr(first_tick + 1, second_tick - first_tick - 1)
		var slash_at: int = head.find("/", second_tick)
		var production_child: String = head.substr(slash_at + 1).strip_edges() if slash_at >= 0 else ""
		var kind_cell: String = cells[3].strip_edges()
		var child_kind: String = kind_cell.trim_prefix("`").trim_suffix("`")
		if child_kind.is_empty() or child_kind.find("`") >= 0:
			return _fail(&"matrix_row_kind_unparsable", "a child kind must be one backticked token",
				{"line": line})
		var paths: Array[String] = []
		for match: RegExMatch in path_pattern.search_all(cells[5]):
			var path: String = match.get_string(1)
			if path in paths:
				return _fail(&"matrix_row_duplicate_path", "a row names one path twice",
					{"row_id": row_id, "path": path})
			paths.append(path)
		if paths.is_empty():
			return _fail(&"matrix_row_without_sources", "a row must name at least one source path",
				{"row_id": row_id})
		if seen.has(row_id):
			return _fail(&"matrix_row_duplicate_id", "a row id occurs twice", {"row_id": row_id})
		seen[row_id] = true
		rows.append({
			"row_id": row_id,
			"production_child": production_child,
			"parent": cells[2].strip_edges().replace("`", ""),
			"child_kind": child_kind,
			"ordinal_law": cells[4].strip_edges().replace("`", ""),
			"source_paths": paths,
		})
	if rows.size() != MATRIX_ROW_COUNT:
		return _fail(&"matrix_row_count", "the matrix must carry exactly thirteen rows",
			{"count": rows.size()})
	return _ok({"rows": rows})


## Parses a GUT log: the run-summary counts, every executed suite (an exact bare res:// path line,
## the discriminator tools/testing/Invoke-IsolatedGodot.ps1 relies on), any "Failed to load script"
## line, and every observed-vector line the gate test printed.
static func parse_gut_log(log_text: String) -> Dictionary:
	var counts: Dictionary = {"scripts": 0, "tests": 0, "passing": 0, "failing": 0, "asserts": 0,
		"asserts_total": 0, "pending": 0}
	var executed: Array = []
	var vectors: Array = []
	var publications: Array = []
	var test_names: Array = []
	var load_failures: int = 0
	var summary_seen: bool = false
	for raw_line: String in log_text.split("\n"):
		var line: String = raw_line.trim_suffix("\r")
		if line == "= Run Summary":
			summary_seen = true
		if line.begins_with("res://tests/") and line.ends_with(".gd") and line.find(" ") < 0:
			if not (line in executed):
				executed.append(line)
		elif line.find("Failed to load script") >= 0:
			load_failures += 1
		elif line.begins_with(VECTOR_MARKER):
			var parsed: Dictionary = _STRICT_JSON.parse_object(line.substr(VECTOR_MARKER.length()))
			if not parsed.get("ok", false):
				return _fail(&"observed_vector_unparsable", "an observed-vector line is not strict JSON",
					{"line": line})
			vectors.append(parsed.get("value", {}) as Dictionary)
		elif line.begins_with(PUBLICATION_MARKER):
			var parsed_publication: Dictionary = _STRICT_JSON.parse_object(line.substr(PUBLICATION_MARKER.length()))
			if not parsed_publication.get("ok", false):
				return _fail(&"observed_publication_unparsable", "an observed-publication line is not strict JSON",
					{"line": line})
			publications.append(parsed_publication.get("value", {}) as Dictionary)
		elif line.begins_with("* test_"):
			test_names.append(line.substr(2))
		elif summary_seen:
			_read_count(line, "Scripts", "scripts", counts)
			_read_count(line, "Tests", "tests", counts)
			_read_count(line, "Passing Tests", "passing", counts)
			_read_count(line, "Failing Tests", "failing", counts)
			_read_count(line, "Risky/Pending", "pending", counts)
			_read_count(line, "Asserts", "asserts", counts)
	counts["executed_suites"] = executed
	counts["vectors"] = vectors
	counts["publications"] = publications
	counts["test_names"] = test_names
	counts["load_failures"] = load_failures
	counts["summary_present"] = summary_seen
	return _ok(counts)


## Reads `const NAME: Array[String] = [ ... ]` or `const NAME := [ ... ]` string-array constants.
static func parse_string_array_constant(source_text: String, name: String) -> Dictionary:
	var pattern: RegEx = RegEx.create_from_string(
		"(?ms)^const %s(?:\\s*:\\s*Array\\[String\\])?\\s*:?=\\s*\\[(.*?)\\]" % name)
	var found: RegExMatch = pattern.search(source_text)
	if found == null:
		return _fail(&"constant_missing", "the string-array constant is absent", {"name": name})
	var values: Array[String] = []
	var literal: RegEx = RegEx.create_from_string("\"([^\"]*)\"")
	for match: RegExMatch in literal.search_all(found.get_string(1)):
		values.append(match.get_string(1))
	return _ok({"values": values})


## Reads `const NAME := <int>` / `const NAME: int = <int>`.
static func parse_int_constant(source_text: String, name: String) -> Dictionary:
	var pattern: RegEx = RegEx.create_from_string("(?m)^const %s(?:\\s*:\\s*int)?\\s*:?=\\s*(-?[0-9]+)\\s*$" % name)
	var found: RegExMatch = pattern.search(source_text)
	if found == null:
		return _fail(&"constant_missing", "the int constant is absent", {"name": name})
	return _ok({"value": int(found.get_string(1))})


## Reads `const NAME := "text"` / `const NAME := &"text"`.
static func parse_string_constant(source_text: String, name: String) -> Dictionary:
	var pattern: RegEx = RegEx.create_from_string("(?m)^const %s(?:\\s*:\\s*(?:String|StringName))?\\s*:?=\\s*&?\"([^\"]*)\"\\s*$" % name)
	var found: RegExMatch = pattern.search(source_text)
	if found == null:
		return _fail(&"constant_missing", "the string constant is absent", {"name": name})
	return _ok({"value": found.get_string(1)})


## Reads the quoted keys of the dictionary literal returned by `get_desktop_contract_state()`.
static func parse_probe_keys(source_text: String) -> Dictionary:
	var start: int = source_text.find("func get_desktop_contract_state() -> Dictionary:")
	if start < 0:
		return _fail(&"probe_missing", "get_desktop_contract_state() is absent", {})
	var body_end: int = source_text.find("\n\n\n", start)
	var body: String = source_text.substr(start, (body_end - start) if body_end > start else -1)
	var keys: Array[String] = []
	var key_pattern: RegEx = RegEx.create_from_string("(?m)^\\t\\t\"([a-z0-9_]+)\":")
	for match: RegExMatch in key_pattern.search_all(body):
		keys.append(match.get_string(1))
	return _ok({"keys": keys})


## Classifies every `derive_child` occurrence in committed production text: the issuer's own
## definition, a capability string inside a method list / has_method check, a literal
## `.call(&"derive_child"` call site, a producer's private `_derive_child(` wrapper around that
## one literal call, or a documentation comment. Anything else is dynamic and unattributable,
## and is reported as such. Each hit may carry `previous` (the preceding source line), so a call
## wrapped across lines -- `.call(` then `&"derive_child", ...` -- is dynamic, never capability;
## `call_deferred(`, `callv(`, `Callable(` and `rpc(` are dynamic on sight; a StringName literal
## `&"derive_child"` is only ever a literal call or dynamic; a plain `"derive_child"` string is
## capability only inside an Array literal, a `has_method(` check, or the issuer's own
## `_require_configured(` guard.
static func classify_derive_child_hits(hits: Array) -> Dictionary:
	var definition: Array = []
	var call_sites: Array = []
	var wrappers: Array = []
	var capability: Array = []
	var comments: Array = []
	var dynamic: Array = []
	for hit: Dictionary in hits:
		var text: String = str(hit["text"])
		var stripped: String = text.strip_edges()
		var site: Dictionary = {"path": str(hit["path"]), "line": int(hit["line"])}
		var previous: String = strip_comments(str(hit.get("previous", "")))
		var code: String = strip_comments(text)
		var previous_opens_call: bool = previous.find("call(") >= 0 or previous.find("callv(") >= 0 \
			or previous.find("call_deferred(") >= 0 or previous.find("Callable(") >= 0 or previous.find("rpc(") >= 0
		var dynamic_trigger: bool = code.find("callv(") >= 0 or code.find("call_deferred(") >= 0 \
			or code.find("Callable(") >= 0 or code.find("rpc(") >= 0
		if stripped.begins_with("#"):
			comments.append(site)
		elif stripped.begins_with("func derive_child("):
			definition.append(site)
		elif dynamic_trigger or previous_opens_call:
			dynamic.append(site)
		elif code.find("call(&\"derive_child\"") >= 0:
			call_sites.append(site)
		elif code.find("&\"derive_child\"") >= 0:
			dynamic.append(site)
		elif code.find("_derive_child(") >= 0 and code.find("call(") < 0:
			wrappers.append(site)
		elif code.find("\"derive_child\"") >= 0 and code.find("call(") < 0 \
				and (code.find("has_method(") >= 0 or code.find("_require_configured(") >= 0 or code.find("[") >= 0 or code.find("]") >= 0 \
					or (stripped.begins_with("\"") and (stripped.ends_with(",") or stripped.ends_with("]")))):
			capability.append(site)
		else:
			dynamic.append(site)
	return _ok({"definition": definition, "call_sites": call_sites, "wrappers": wrappers,
		"capability": capability, "comments": comments, "dynamic": dynamic})


## Walks a parsed fixture document and validates every `committed_schedule` member it carries:
## exact aggregate keys, and every entry carrying exactly the ten committed-entry keys with none of
## the caller-owned route/effects/cost fields. Returns value={aggregates:int, entries:int}.
static func audit_fixture_committed_schedules(document: Variant) -> Dictionary:
	var totals: Dictionary = {"aggregates": 0, "entries": 0}
	var failure: Dictionary = _audit_value(document, "$", totals)
	if not failure.is_empty():
		return failure
	return _ok(totals)


# =================================================================================================
# Record construction
# =================================================================================================

## Builds the record from exactly the subject commit tree, the Beads snapshot, and the fresh logs.
static func build_record(subject_commit: String, beads_snapshot_path: String) -> Dictionary:
	if not _is_commit_id(subject_commit):
		return _fail(&"subject_commit_invalid", "subject_commit must be forty lowercase hex characters",
			{"subject_commit": subject_commit})
	var proof: Dictionary = _prove_commit(subject_commit, SUBJECT_COMMIT_SUBJECT, &"subject")
	if not proof.get("ok", false):
		return proof
	var record: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"evidence_id": EVIDENCE_ID,
		"owner_beads_id": OWNER_BEADS_ID,
		"subject_commit": subject_commit,
		"subject_commit_subject": SUBJECT_COMMIT_SUBJECT,
	}
	var sources: Dictionary = {}
	var bindings: Array[Dictionary] = []
	for path: String in SOURCE_PATHS:
		var source: Dictionary = _source_at_commit(subject_commit, path)
		if not source.get("ok", false):
			return source
		var text: String = str((source["value"] as Dictionary)["text"])
		sources[path] = text
		var surface: Dictionary = parse_declared_surface(text)
		bindings.append({
			"path": path,
			"sha256": _digest_bytes((source["value"] as Dictionary)["bytes"]),
			"declared_surface": (surface["value"] as Dictionary)["entries"],
			"declared_surface_sha256": str((surface["value"] as Dictionary)["sha256"]),
		})
	record["source_bindings"] = bindings
	var classifications: Dictionary = _classify_symbols(bindings)
	if not classifications.get("ok", false):
		return classifications
	record["symbol_classifications"] = (classifications["value"] as Dictionary)["records"]
	var forbidden: Dictionary = _check_forbidden_tokens(sources)
	if not forbidden.get("ok", false):
		return forbidden
	var plan: Dictionary = _blob_bytes_at_commit(subject_commit, PLAN_PATH)
	if not plan.get("ok", false):
		return plan
	var plan_bytes: PackedByteArray = (plan["value"] as Dictionary)["bytes"]
	record["plan_path"] = PLAN_PATH
	record["plan_sha256"] = _digest_bytes(plan_bytes)
	var blob: Dictionary = extract_matrix_blob(plan_bytes)
	if not blob.get("ok", false):
		return blob
	record["plan01_child_derivation_matrix_sha256"] = str((blob["value"] as Dictionary)["sha256"])
	var rows: Dictionary = parse_matrix_rows(
		((blob["value"] as Dictionary)["bytes"] as PackedByteArray).get_string_from_utf8())
	if not rows.get("ok", false):
		return rows
	var matrix: Dictionary = _bind_matrix_rows((rows["value"] as Dictionary)["rows"], sources)
	if not matrix.get("ok", false):
		return matrix
	var unrealized_absent: Dictionary = _prove_unrealized_roles_absent(subject_commit)
	if not unrealized_absent.get("ok", false):
		return unrealized_absent
	record["derivation_matrix"] = matrix["value"]
	var census: Dictionary = _derive_child_census(subject_commit, sources)
	if not census.get("ok", false):
		return census
	record["derive_child_census"] = census["value"]
	var registry: Dictionary = _bind_registry(subject_commit)
	if not registry.get("ok", false):
		return registry
	record["registry"] = registry["value"]
	var state_schema: Dictionary = _bind_state_schema(sources)
	if not state_schema.get("ok", false):
		return state_schema
	record["schedule_state_schema"] = state_schema["value"]
	var ledger: Dictionary = _bind_ledger(subject_commit, sources)
	if not ledger.get("ok", false):
		return ledger
	record["publication_ledger"] = ledger["value"]
	var advance: Dictionary = _bind_day_advance(sources)
	if not advance.get("ok", false):
		return advance
	record["day_advance_identity"] = advance["value"]
	var stages: Dictionary = _bind_day_resolution_stages(sources)
	if not stages.get("ok", false):
		return stages
	record["day_resolution_stages"] = stages["value"]
	var boundary: Dictionary = _bind_v3_boundary(subject_commit, sources)
	if not boundary.get("ok", false):
		return boundary
	record["v3_boundary"] = boundary["value"]
	var versions: Dictionary = _bind_current_versions(sources)
	if not versions.get("ok", false):
		return versions
	record["current_versions"] = versions["value"]
	var strict: Dictionary = _bind_strict_branch(subject_commit)
	if not strict.get("ok", false):
		return strict
	record["strict_branch"] = strict["value"]
	var witness: Dictionary = _bind_sylvia_witness(sources)
	if not witness.get("ok", false):
		return witness
	record["sylvia_witness"] = witness["value"]
	var day7: Dictionary = _bind_day7_provenance(sources)
	if not day7.get("ok", false):
		return day7
	record["day7_provenance"] = day7["value"]
	record["dating_presentation"] = {
		"production_owner": "reserved:dwm-oyo.4",
		"ready_in_phase_2r": false,
		"unconfigured_code": "dating_physical_owner_unconfigured",
	}
	var dating_text: String = str(sources["scripts/application/run/DatingPresentationPort.gd"])
	if dating_text.find("dating_physical_owner_unconfigured") < 0:
		return _fail(&"dating_unconfigured_code_missing",
			"DatingPresentationPort must fail closed with dating_physical_owner_unconfigured", {})
	var required_surface: Dictionary = _bind_required_surface(subject_commit)
	if not required_surface.get("ok", false):
		return required_surface
	record["required_surface"] = required_surface["value"]
	var fixtures: Dictionary = _bind_fixtures(subject_commit)
	if not fixtures.get("ok", false):
		return fixtures
	record["fixtures"] = fixtures["value"]
	var beads: Dictionary = _bind_beads(beads_snapshot_path)
	if not beads.get("ok", false):
		return beads
	record["beads_chain"] = (beads["value"] as Dictionary)["chain"]
	record["requirement_ids"] = (beads["value"] as Dictionary)["requirement_ids"]
	record["exclusions"] = (beads["value"] as Dictionary)["exclusions"]
	var commands: Dictionary = _bind_commands()
	if not commands.get("ok", false):
		return commands
	record["commands"] = (commands["value"] as Dictionary)["commands"]
	var vectors: Dictionary = _bind_observed_vectors(
		(commands["value"] as Dictionary)["green_vectors"], record["derivation_matrix"])
	if not vectors.get("ok", false):
		return vectors
	record["observed_vectors"] = vectors["value"]
	var publications: Dictionary = _bind_observed_publications(
		(commands["value"] as Dictionary)["green_publications"])
	if not publications.get("ok", false):
		return publications
	record["observed_publications"] = publications["value"]
	var probe: Dictionary = _bind_bootstrap_probe(sources,
		(commands["value"] as Dictionary)["bootstrap_test_names"])
	if not probe.get("ok", false):
		return probe
	record["bootstrap_probe"] = probe["value"]
	var generated_surface: Dictionary = _bind_generated_surface()
	if not generated_surface.get("ok", false):
		return generated_surface
	record["generated_surface"] = generated_surface["value"]
	var valid: Dictionary = validate_record(record)
	if not valid.get("ok", false):
		return valid
	return _ok({"record": record})


## Schema plus imperative law. The schema freezes member sets and constants; the law checks what
## a member-set schema cannot express (lowercase digests, exact forty-character commit ids, row
## count, one vector per realized row and none per unrealized row, green/red log verdicts).
static func validate_record(record: Dictionary) -> Dictionary:
	var by_schema: Dictionary = validate_record_schema(record)
	if not by_schema.get("ok", false):
		return by_schema
	return validate_record_law(record)


static func validate_record_schema(record: Dictionary) -> Dictionary:
	var judged: Dictionary = _SCHEMA_VALIDATOR.validate(record, record_schema())
	if not judged.get("ok", false):
		return _fail(&"record_schema_rejected", str(judged.get("message", "")),
			{"errors": judged.get("errors", [])})
	return _ok({})


static func validate_record_law(record: Dictionary) -> Dictionary:
	var keys: Array = record.keys()
	keys.sort()
	if keys != RECORD_KEYS:
		return _fail(&"record_member_set_invalid", "the record member set is not exact",
			{"expected": RECORD_KEYS, "actual": keys})
	if not _is_commit_id(str(record["subject_commit"])):
		return _fail(&"record_commit_invalid", "subject_commit must be forty lowercase hex characters", {})
	for field: String in ["plan_sha256", "plan01_child_derivation_matrix_sha256"]:
		if not _is_sha256(str(record[field])):
			return _fail(&"record_digest_invalid", "a digest is not lowercase SHA-256", {"field": field})
	for binding: Dictionary in (record["source_bindings"] as Array):
		if not _is_sha256(str(binding["sha256"])) or not _is_sha256(str(binding["declared_surface_sha256"])):
			return _fail(&"record_digest_invalid", "a source digest is not lowercase SHA-256",
				{"path": str(binding["path"])})
	var digest_fields: Array = [
		["registry", "manifest_sha256"], ["registry", "schema_sha256"], ["registry", "registry_fingerprint"],
		["publication_ledger", "schema_sha256"], ["v3_boundary", "record_sha256"],
		["required_surface", "sha256"], ["generated_surface", "sha256"],
	]
	for field_path: Array in digest_fields:
		if not _is_sha256(str((record[field_path[0]] as Dictionary)[field_path[1]])):
			return _fail(&"record_digest_invalid", "a digest is not lowercase SHA-256",
				{"field": "%s.%s" % [str(field_path[0]), str(field_path[1])]})
	for fixture: Dictionary in (record["fixtures"] as Array):
		if not _is_sha256(str(fixture["sha256"])):
			return _fail(&"record_digest_invalid", "a fixture digest is not lowercase SHA-256", {"path": str(fixture["path"])})
	var bound_paths: Array = []
	for binding: Dictionary in (record["source_bindings"] as Array):
		bound_paths.append(str(binding["path"]))
	if bound_paths != SOURCE_PATHS:
		return _fail(&"record_source_paths_invalid", "the bound source paths are not the frozen set", {})
	var matrix: Dictionary = record["derivation_matrix"]
	var rows: Array = matrix["rows"]
	if rows.size() != MATRIX_ROW_COUNT or int(matrix["row_count"]) != MATRIX_ROW_COUNT:
		return _fail(&"record_matrix_row_count", "the matrix must carry exactly thirteen rows", {})
	var realized: Array[String] = []
	var order: Array = matrix["derivation_order"]
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		var row_id: String = str(row["row_id"])
		if str(order[index]) != row_id:
			return _fail(&"record_matrix_order_invalid", "derivation_order must list the rows in matrix order", {})
		if not ROW_REALIZATIONS.has(row_id):
			return _fail(&"record_matrix_row_unknown", "a matrix row id is not one of the thirteen", {"row_id": row_id})
		var realization: Dictionary = ROW_REALIZATIONS[row_id]
		var expected_realized: bool = not (realization["producers"] as Array).is_empty()
		if str(row["realization"]) != ("realized" if expected_realized else "unrealized"):
			return _fail(&"record_matrix_realization_invalid", "a row realization differs from the frozen map", {"row_id": row_id})
		if str(row["role"]) != str(realization["role"]):
			return _fail(&"record_matrix_role_invalid", "a row role differs from the frozen map", {"row_id": row_id})
		if Array(row["producers"]) != Array(realization["producers"]) \
				or Array(row["validators"]) != Array(realization.get("validators", [])):
			return _fail(&"record_matrix_producers_invalid", "a row's producers or validators differ from the frozen map", {"row_id": row_id})
		if not ("role" in (row["source_paths"] as Array)):
			return _fail(&"record_matrix_role_path_missing", "every row projects a role token", {"row_id": row_id})
		if expected_realized:
			realized.append(row_id)
	var vectors: Array = record["observed_vectors"]
	var vector_rows: Array[String] = []
	for vector: Dictionary in vectors:
		vector_rows.append(str(vector["row_id"]))
	if vector_rows != realized:
		return _fail(&"record_vectors_incomplete", "exactly one observed vector per realized row, in matrix order",
			{"expected": realized, "actual": vector_rows})
	for vector: Dictionary in vectors:
		var row: Dictionary = _row_by_id(rows, str(vector["row_id"]))
		if str(vector["child_kind"]) != str(row["child_kind"]):
			return _fail(&"record_vector_kind_invalid", "an observed vector's child kind differs from its row", {"row_id": str(vector["row_id"])})
		var observed_paths: Array[String] = []
		for token: String in (vector["source_ids"] as Array):
			var cut: int = token.find("=")
			if cut <= 0:
				return _fail(&"record_vector_token_invalid", "a source token is not path=J(value)", {"token": token})
			observed_paths.append(token.substr(0, cut))
		var expected_paths: Array[String] = []
		for path: String in (row["source_paths"] as Array):
			expected_paths.append(path)
		observed_paths.sort()
		expected_paths.sort()
		if observed_paths != expected_paths:
			return _fail(&"record_vector_paths_invalid", "an observed vector does not project its row's exact paths",
				{"row_id": str(vector["row_id"]), "expected": expected_paths, "actual": observed_paths})
		var sorted_tokens: Array = (vector["source_ids"] as Array).duplicate()
		sorted_tokens.sort()
		if sorted_tokens != (vector["source_ids"] as Array):
			return _fail(&"record_vector_order_invalid", "an observed vector's tokens are not strictly sorted", {"row_id": str(vector["row_id"])})
		if int(vector["ordinal"]) < 0:
			return _fail(&"record_vector_ordinal_invalid", "an ordinal is negative", {"row_id": str(vector["row_id"])})
		if str(row["ordinal_law"]).begins_with("0 ") and int(vector["ordinal"]) != 0:
			return _fail(&"record_vector_ordinal_invalid", "a fixed-ordinal row observed a nonzero ordinal", {"row_id": str(vector["row_id"])})
	# Sibling rows under one root share one observed parent: the resolution-root rows, and the
	# entry/commit pair under one Schedule transaction.
	var parent_groups: Array = [
		["P01.day_resolution.start", "P01.hospital.resolution", "P01.hospital.miss", "P01.presentation.intent", "P01.presentation.completion"],
		["P01.schedule.entry", "P01.schedule.commit"],
	]
	for group: Array in parent_groups:
		var shared: String = ""
		for vector: Dictionary in vectors:
			if not (str(vector["row_id"]) in group):
				continue
			if shared.is_empty():
				shared = str(vector["parent_receipt_id"])
			elif str(vector["parent_receipt_id"]) != shared:
				return _fail(&"record_vector_parent_invalid", "sibling rows under one root observed different parents", {"row_id": str(vector["row_id"])})
	var census: Dictionary = record["derive_child_census"]
	if not (census["dynamic"] as Array).is_empty():
		return _fail(&"record_census_dynamic_call_site", "a derive_child site is dynamic or unattributable", {"sites": census["dynamic"]})
	if (census["definition"] as Array).size() != 1:
		return _fail(&"record_census_definition_count", "derive_child must be defined exactly once", {})
	for site: Dictionary in (census["call_sites"] as Array) + (census["wrappers"] as Array):
		if not (str(site["path"]) in _all_producer_paths()):
			return _fail(&"record_census_unattributed_call_site", "a derive_child call site is not attributed to a matrix row", {"site": site})
	for command: Dictionary in (record["commands"] as Array):
		if not _is_sha256(str(command["log_sha256"])):
			return _fail(&"record_digest_invalid", "a log digest is not lowercase SHA-256", {"suite_id": str(command["suite_id"])})
		var bound_suites: Array = []
		for binding: Dictionary in COMMAND_BINDINGS:
			if str(binding["suite_id"]) == str(command["suite_id"]):
				bound_suites = binding["suites"]
		if bound_suites.is_empty() or Array(command["suites"]) != bound_suites \
				or str(command["log_path"]) != LOG_RELATIVE_DIRECTORY + "/" + str(command["log_name"]):
			return _fail(&"record_command_binding_invalid", "a command's suites or log path differ from the frozen binding", {"suite_id": str(command["suite_id"])})
		var verdict: String = str(command["expect"])
		if verdict == "green":
			if int(command["failing"]) != 0 or int(command["tests"]) <= 0 \
					or int(command["passing"]) != int(command["tests"]) or int(command["load_failures"]) != 0:
				return _fail(&"record_command_not_green", "a green command did not pass cleanly", {"suite_id": str(command["suite_id"])})
			var executed: Array = command["executed_suites"]
			for suite: String in (command["suites"] as Array):
				if not (suite in executed):
					return _fail(&"record_command_suite_not_executed", "a requested suite never executed", {"suite": suite})
		else:
			if int(command["failing"]) <= 0 or int(command["load_failures"]) != 0:
				return _fail(&"record_command_not_red", "the RED command must fail by assertion, never by a load failure", {"suite_id": str(command["suite_id"])})
	var publications: Array = record["observed_publications"]
	if publications.size() != PUBLICATION_BINDINGS.size():
		return _fail(&"record_publications_incomplete", "one observed publication vector per frozen binding", {})
	for index: int in range(publications.size()):
		var observed: Dictionary = publications[index]
		var expected_publication: Dictionary = PUBLICATION_BINDINGS[index]
		for key: String in expected_publication:
			if observed.get(key) != expected_publication[key]:
				return _fail(&"record_publication_invalid", "an observed publication vector differs from its frozen binding",
					{"owner": str(observed.get("owner", "")), "member": key})
	var stages: Dictionary = record["day_resolution_stages"]
	if Array(stages["day_1_6"]) != DAY_1_6_STAGES or Array(stages["day_7"]) != DAY_7_STAGES:
		return _fail(&"record_stage_arrays_invalid", "the frozen stage arrays differ", {})
	for retired: String in RETIRED_ENDING_STAGES:
		if retired in (stages["day_1_6"] as Array) or retired in (stages["day_7"] as Array):
			return _fail(&"record_ending_stage_reachable", "a retired ending stage is reachable from a stage array", {"stage": retired})
	if bool(stages["ending_stages_reachable"]):
		return _fail(&"record_ending_stage_reachable", "the record claims a reachable ending stage", {})
	var boundary: Dictionary = record["v3_boundary"]
	if not _is_commit_id(str(boundary["boundary_commit"])):
		return _fail(&"record_commit_invalid", "the v3 boundary commit is not forty lowercase hex characters", {})
	if int(boundary["run_snapshot_schema_version"]) != 3 or int(boundary["save_document_version"]) != 3:
		return _fail(&"record_v3_versions_invalid", "the recorded boundary must be schema/document v3", {})
	var versions: Dictionary = record["current_versions"]
	if int(versions["run_snapshot_schema_version"]) < 3 or int(versions["save_document_version"]) < 3:
		return _fail(&"record_current_versions_invalid", "the subject must not regress below v3", {})
	if not bool(versions["committed_schedule_keys_preserved"]):
		return _fail(&"record_committed_schedule_not_preserved", "committed_schedule keys must be preserved", {})
	var probe: Dictionary = record["bootstrap_probe"]
	if Array(probe["keys"]) != BOOTSTRAP_PROBE_KEYS:
		return _fail(&"record_probe_keys_invalid", "the bootstrap probe key set is not the frozen set", {})
	for key: String in (probe["keys"] as Array):
		if key.ends_with("_instance_id") and typeof(probe["owner_classes"].get(key)) != TYPE_STRING:
			return _fail(&"record_probe_owner_missing", "a retained-object probe key has no owner class", {"key": key})
	var schedule_schema: Dictionary = record["schedule_state_schema"]
	var entry_keys: Array = (schedule_schema["entry_keys"] as Array).duplicate()
	entry_keys.sort()
	for field: String in CALLER_OWNED_ENTRY_FIELDS:
		if field in entry_keys:
			return _fail(&"record_entry_keys_caller_owned", "a caller-owned field entered the committed entry", {"field": field})
	if entry_keys != COMMITTED_ENTRY_KEYS:
		return _fail(&"record_entry_keys_invalid", "the committed-entry key set is not the frozen ten", {})
	if Array(record["exclusions"]) != EXCLUSIONS:
		return _fail(&"record_exclusions_invalid", "the exclusions are not the frozen set", {})
	return _ok({})


## The published schema, held inline so the subject commit stays at exactly its three paths. The
## gate test asserts this schema independently of the law, in both directions.
static func record_schema() -> Dictionary:
	var sha256: Dictionary = {"type": "string", "minLength": 64}
	var commit: Dictionary = {"type": "string", "minLength": 40}
	var string_array: Dictionary = {"type": "array", "items": {"type": "string"}}
	var site: Dictionary = {"type": "object", "required": ["path", "line"], "additionalProperties": false,
		"properties": {"path": {"type": "string", "minLength": 1}, "line": {"type": "integer"}}}
	var site_array: Dictionary = {"type": "array", "items": site}
	return {
		"type": "object",
		"additionalProperties": false,
		"required": RECORD_KEYS.duplicate(),
		"properties": {
			"schema_version": {"const": SCHEMA_VERSION},
			"evidence_id": {"const": EVIDENCE_ID},
			"owner_beads_id": {"const": OWNER_BEADS_ID},
			"subject_commit": commit,
			"subject_commit_subject": {"const": SUBJECT_COMMIT_SUBJECT},
			"requirement_ids": {"type": "array", "items": {"type": "string", "minLength": 1}, "uniqueItems": true},
			"exclusions": string_array,
			"beads_chain": {"type": "array", "items": {"type": "object", "additionalProperties": false,
				"required": ["id", "status", "depends_on"],
				"properties": {"id": {"type": "string", "minLength": 1},
					"status": {"type": "string", "enum": ["open", "in_progress", "closed", "blocked"]},
					"depends_on": string_array}}},
			"plan_path": {"const": PLAN_PATH},
			"plan_sha256": sha256,
			"plan01_child_derivation_matrix_sha256": sha256,
			"derivation_matrix": {"type": "object", "additionalProperties": false,
				"required": ["row_count", "derivation_order", "rows"],
				"properties": {"row_count": {"const": MATRIX_ROW_COUNT}, "derivation_order": string_array,
					"rows": {"type": "array", "items": {"type": "object", "additionalProperties": false,
						"required": ["row_id", "production_child", "parent", "child_kind", "ordinal_law",
							"source_paths", "role", "realization", "producers", "validators", "deviation"],
						"properties": {"row_id": {"type": "string", "minLength": 1},
							"production_child": {"type": "string"}, "parent": {"type": "string", "minLength": 1},
							"child_kind": {"type": "string", "minLength": 1},
							"ordinal_law": {"type": "string", "minLength": 1},
							"source_paths": string_array, "role": {"type": "string", "minLength": 1},
							"realization": {"type": "string", "enum": ["realized", "unrealized"]},
							"producers": string_array, "validators": string_array,
							"deviation": {"type": "string"}}}}}},
			"derive_child_census": {"type": "object", "additionalProperties": false,
				"required": ["definition", "call_sites", "wrappers", "capability", "comments", "dynamic"],
				"properties": {"definition": site_array, "call_sites": site_array, "wrappers": site_array,
					"capability": site_array, "comments": site_array, "dynamic": site_array}},
			"observed_vectors": {"type": "array", "items": {"type": "object", "additionalProperties": false,
				"required": ["row_id", "child_kind", "ordinal", "parent_receipt_id", "child_id", "source_ids"],
				"properties": {"row_id": {"type": "string", "minLength": 1},
					"child_kind": {"type": "string", "minLength": 1}, "ordinal": {"type": "integer"},
					"parent_receipt_id": {"type": "string", "minLength": 1},
					"child_id": {"type": "string", "minLength": 1}, "source_ids": string_array}}},
			"source_bindings": {"type": "array", "items": {"type": "object", "additionalProperties": false,
				"required": ["path", "sha256", "declared_surface", "declared_surface_sha256"],
				"properties": {"path": {"type": "string", "minLength": 1}, "sha256": sha256,
					"declared_surface": string_array, "declared_surface_sha256": sha256}}},
			"symbol_classifications": {"type": "array", "items": {"type": "object", "additionalProperties": false,
				"required": ["path", "symbol", "classification"],
				"properties": {"path": {"type": "string", "minLength": 1},
					"symbol": {"type": "string", "minLength": 1},
					"classification": {"type": "string", "enum": ["present", "absent"]}}}},
			"registry": {"type": "object", "additionalProperties": false,
				"required": ["manifest_path", "manifest_sha256", "schema_path", "schema_sha256",
					"registry_fingerprint", "registry_version", "record_count"],
				"properties": {"manifest_path": {"const": REGISTRY_MANIFEST_PATH}, "manifest_sha256": sha256,
					"schema_path": {"const": REGISTRY_SCHEMA_PATH}, "schema_sha256": sha256,
					"registry_fingerprint": sha256, "registry_version": {"const": 1},
					"record_count": {"const": 20}}},
			"schedule_state_schema": {"type": "object", "additionalProperties": false,
				"required": ["path", "aggregate_keys", "entry_keys", "commit_receipt_keys"],
				"properties": {"path": {"const": "scripts/domain/schedule/ScheduleStateSchema.gd"},
					"aggregate_keys": string_array, "entry_keys": string_array, "commit_receipt_keys": string_array}},
			"publication_ledger": {"type": "object", "additionalProperties": false,
				"required": ["path", "schema_path", "schema_sha256", "fixed_path", "kinds", "conflict_codes",
					"first_delivery_field", "record_keys"],
				"properties": {"path": {"const": "scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd"},
					"schema_path": {"const": LEDGER_SCHEMA_PATH}, "schema_sha256": sha256,
					"fixed_path": {"const": "schedule-foundation-publications.json"}, "kinds": string_array,
					"conflict_codes": {"type": "object", "additionalProperties": false,
						"required": ["ledger", "schedule_commit", "day_resolution_start"],
						"properties": {"ledger": {"const": "publication_record_conflict"},
							"schedule_commit": {"const": "schedule_publication_conflict"},
							"day_resolution_start": {"const": "day_resolution_start_publication_conflict"}}},
					"first_delivery_field": {"const": "first_delivery"}, "record_keys": string_array}},
			"day_advance_identity": {"type": "object", "additionalProperties": false,
				"required": ["path", "request_keys", "receipt_keys", "resolution_kinds", "allocation_key_format",
					"raw_causal_day_issue_in_plan01"],
				"properties": {"path": {"const": "scripts/application/run/CausalDayAdvanceIdentityPort.gd"},
					"request_keys": string_array, "receipt_keys": string_array, "resolution_kinds": string_array,
					"allocation_key_format": {"const": "resolution_kind:source_resolution_receipt_id"},
					"raw_causal_day_issue_in_plan01": {"const": false}}},
			"bootstrap_probe": {"type": "object", "additionalProperties": false,
				"required": ["path", "keys", "owner_classes", "readiness", "readiness_attested_by_tests",
					"instance_ids_serialized"],
				"properties": {"path": {"const": "autoload/ApplicationBootstrap.gd"}, "keys": string_array,
					"owner_classes": _owner_classes_schema(),
					"readiness_attested_by_tests": string_array,
					"readiness": {"type": "object", "additionalProperties": false,
						"required": ["hospital_presentation_ready", "dating_presentation_ready", "presentation_producer_ready"],
						"properties": {"hospital_presentation_ready": {"const": true},
							"dating_presentation_ready": {"const": false},
							"presentation_producer_ready": {"const": false}}},
					"instance_ids_serialized": {"const": false}}},
			"v3_boundary": {"type": "object", "additionalProperties": false,
				"required": ["record_path", "record_sha256", "owner_beads_id", "boundary_commit", "boundary_subject",
					"run_snapshot_schema_version", "save_document_version", "sources_revalidated_at_boundary",
					"sources_changed_since_boundary", "migration_rejection_code"],
				"properties": {"record_path": {"const": V3_BOUNDARY_RECORD_PATH}, "record_sha256": sha256,
					"owner_beads_id": {"const": V3_BOUNDARY_OWNER}, "boundary_commit": commit,
					"boundary_subject": {"const": V3_BOUNDARY_SUBJECT},
					"run_snapshot_schema_version": {"type": "integer"}, "save_document_version": {"type": "integer"},
					"sources_revalidated_at_boundary": {"const": true},
					"sources_changed_since_boundary": string_array,
					"migration_rejection_code": {"const": "unmigratable_legacy_schedule"}}},
			"current_versions": {"type": "object", "additionalProperties": false,
				"required": ["run_snapshot_schema_version", "save_document_version", "committed_schedule_keys_preserved"],
				"properties": {"run_snapshot_schema_version": {"type": "integer"},
					"save_document_version": {"type": "integer"},
					"committed_schedule_keys_preserved": {"type": "boolean"}}},
			"strict_branch": {"type": "object", "additionalProperties": false,
				"required": ["branch", "merge_base", "tip", "disposition"],
				"properties": {"branch": {"const": STRICT_BRANCH}, "merge_base": commit, "tip": commit,
					"disposition": {"const": "quarantined_evidence_only"}}},
			"sylvia_witness": {"type": "object", "additionalProperties": false,
				"required": ["owner_path", "kind", "resolution_kind", "contacts_index", "consequence",
					"care_followup_entry_id_format", "plan_care_followup_entry_id_format", "application_owner",
					"applied_flag_present", "issuer_anchored", "deviation"],
				"properties": {"owner_path": {"const": "scripts/domain/hospital/HospitalRules.gd"},
					"care_followup_entry_id_format": {"const": "care.sylvia.day<source_day+1>"},
					"plan_care_followup_entry_id_format": {"const": "contact.hospital_care.sylvia.day<source_day+1>"},
					"kind": {"const": "sylvia_hospital_witness"}, "resolution_kind": {"const": "schedule_done"},
					"contacts_index": {"const": "sylvia_hospital_witness_receipts"},
					"consequence": {"type": "object", "additionalProperties": false,
						"required": ["affection_delta", "dark_delta", "attitude", "tier_transition"],
						"properties": {"affection_delta": {"const": 2}, "dark_delta": {"const": 1},
							"attitude": {"const": "fixated"}, "tier_transition": {"const": "advance_one_or_stay_love"}}},
					"application_owner": {"const": "dwm-oyo.4"}, "applied_flag_present": {"const": false},
					"issuer_anchored": {"const": false}, "deviation": {"type": "string", "minLength": 1}}},
			"day7_provenance": {"type": "object", "additionalProperties": false,
				"required": ["path", "child_kind", "day", "causes", "terminal_intent_owner", "final_plan_owner",
					"ending_plan_in_plan01_composition"],
				"properties": {"path": {"const": "scripts/domain/schedule/Day7ScheduleProvenance.gd"},
					"child_kind": {"const": "day7_schedule_provenance"}, "day": {"const": 7},
					"causes": string_array, "terminal_intent_owner": {"const": "dwm-oyo.3"},
					"final_plan_owner": {"const": "dwm-oyo.6"},
					"ending_plan_in_plan01_composition": {"const": false}}},
			"dating_presentation": {"type": "object", "additionalProperties": false,
				"required": ["production_owner", "ready_in_phase_2r", "unconfigured_code"],
				"properties": {"production_owner": {"const": "reserved:dwm-oyo.4"},
					"ready_in_phase_2r": {"const": false},
					"unconfigured_code": {"const": "dating_physical_owner_unconfigured"}}},
			"required_surface": {"type": "object", "additionalProperties": false,
				"required": ["path", "sha256", "task4_seams_classified"],
				"properties": {"path": {"const": REQUIRED_SURFACE_PATH}, "sha256": sha256,
					"task4_seams_classified": string_array}},
			"fixtures": {"type": "array", "items": {"type": "object", "additionalProperties": false,
				"required": ["path", "sha256", "committed_schedule_aggregates", "committed_schedule_entries"],
				"properties": {"path": {"type": "string", "minLength": 1}, "sha256": sha256,
					"committed_schedule_aggregates": {"type": "integer"},
					"committed_schedule_entries": {"type": "integer"}}}},
			"commands": {"type": "array", "items": {"type": "object", "additionalProperties": false,
				"required": ["suite_id", "log_name", "log_path", "log_sha256", "expect", "suites",
					"executed_suites", "scripts", "tests", "passing", "failing", "pending", "asserts",
					"asserts_total", "load_failures"],
				"properties": {"suite_id": {"type": "string", "minLength": 1}, "log_name": {"type": "string", "minLength": 1},
					"log_path": {"type": "string", "minLength": 1}, "log_sha256": sha256,
					"expect": {"type": "string", "enum": ["red", "green"]}, "suites": string_array,
					"executed_suites": string_array, "scripts": {"type": "integer"}, "tests": {"type": "integer"},
					"passing": {"type": "integer"}, "failing": {"type": "integer"}, "pending": {"type": "integer"},
					"asserts": {"type": "integer"}, "asserts_total": {"type": "integer"},
					"load_failures": {"type": "integer"}}}},
			"observed_publications": {"type": "array", "items": {"type": "object", "additionalProperties": false,
				"required": ["owner", "kind", "first_delivery_sequence", "signal", "signal_counts", "conflict_code"],
				"properties": {"owner": {"type": "string", "enum": ["ledger", "schedule_commit_port", "day_resolution_start_port"]},
					"kind": {"type": "string", "enum": ["schedule_commit", "day_resolution_start"]},
					"first_delivery_sequence": {"type": "array", "items": {"type": "boolean"}},
					"signal": {"type": "string"}, "signal_counts": {"type": "array", "items": {"type": "integer"}},
					"conflict_code": {"type": "string", "minLength": 1}}}},
			"day_resolution_stages": {"type": "object", "additionalProperties": false,
				"required": ["path", "day_1_6", "day_7", "retired_ending_stages",
					"retired_ending_residue_in", "default_ending_plan_residue_in", "ending_stages_reachable", "deviation"],
				"properties": {"path": {"const": "scripts/domain/run/DayResolutionPlan.gd"},
					"day_1_6": string_array, "day_7": string_array, "retired_ending_stages": string_array,
					"retired_ending_residue_in": string_array, "default_ending_plan_residue_in": string_array,
					"ending_stages_reachable": {"const": false}, "deviation": {"type": "string", "minLength": 1}}},
			"generated_surface": {"type": "object", "additionalProperties": false,
				"required": ["path", "sha256"],
				"properties": {"path": {"const": GENERATED_SURFACE_RELATIVE}, "sha256": sha256}},
		},
	}


## The fourteen retained-object probe keys each bound to their owner class, closed against unknown
## keys so a renamed seam cannot hide.
static func _owner_classes_schema() -> Dictionary:
	var properties: Dictionary = {}
	var required: Array = []
	for key: String in BOOTSTRAP_PROBE_OWNERS:
		properties[key] = {"const": str(BOOTSTRAP_PROBE_OWNERS[key])}
		required.append(key)
	required.sort()
	return {"type": "object", "additionalProperties": false, "required": required, "properties": properties}


static func canonical_bytes(record: Dictionary) -> Dictionary:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(record)
	if not emitted.get("ok", false):
		return _fail(&"record_not_canonical", "the record does not serialize canonically",
			{"code": str(emitted.get("code", &""))})
	return _ok({"bytes": (str(emitted["value"]) + "\n").to_utf8_buffer()})


# =================================================================================================
# Binding helpers (each reads only the subject commit tree, the snapshot, or the fresh logs)
# =================================================================================================

static func _classify_symbols(bindings: Array[Dictionary]) -> Dictionary:
	var records: Array[Dictionary] = []
	for binding: Dictionary in bindings:
		var path: String = str(binding["path"])
		var entries: Array = binding["declared_surface"]
		for required: String in (REQUIRED_SURFACE_ENTRIES.get(path, []) as Array):
			if not (required in entries):
				return _fail(&"required_surface_entry_missing", "a frozen declared-surface entry is absent",
					{"path": path, "entry": required})
			records.append({"path": path, "symbol": required, "classification": "present"})
		for symbol: String in (ABSENT_SURFACE_SYMBOLS.get(path, []) as Array):
			for entry: String in entries:
				var entry_name: String = entry.substr(entry.rfind(" ") + 1)
				entry_name = entry_name.substr(0, entry_name.find("("))
				if entry_name == symbol:
					return _fail(&"absent_surface_symbol_present", "a retired or foreign symbol is declared",
						{"path": path, "symbol": symbol})
			records.append({"path": path, "symbol": symbol, "classification": "absent"})
	return _ok({"records": records})


static func _check_forbidden_tokens(sources: Dictionary) -> Dictionary:
	for path: String in FORBIDDEN_SOURCE_TOKENS:
		var code: String = strip_comments(str(sources[path]))
		for token: String in (FORBIDDEN_SOURCE_TOKENS[path] as Array):
			if code.find(token) >= 0:
				return _fail(&"forbidden_token_present", "a forbidden token appears in executable source",
					{"path": path, "token": token})
	return _ok({})


static func _bind_matrix_rows(rows: Array, sources: Dictionary) -> Dictionary:
	var bound: Array[Dictionary] = []
	var order: Array[String] = []
	for raw_row: Dictionary in rows:
		var row: Dictionary = raw_row.duplicate(true)
		var row_id: String = str(row["row_id"])
		if not ROW_REALIZATIONS.has(row_id):
			return _fail(&"matrix_row_unknown", "the plan names a row this generator does not know",
				{"row_id": row_id})
		var realization: Dictionary = ROW_REALIZATIONS[row_id]
		var role: String = str(realization["role"])
		var producers: Array = realization["producers"]
		var literal: String = "\"%s\"" % role
		for producer: String in producers:
			if strip_comments(str(sources[producer])).find(literal) < 0:
				return _fail(&"matrix_producer_role_missing", "an attributed producer does not carry its role literal",
					{"row_id": row_id, "producer": producer})
		if producers.is_empty():
			for path: String in sources:
				if strip_comments(str(sources[path])).find(literal) >= 0:
					return _fail(&"matrix_unrealized_row_realized", "an unrealized row's role literal appeared in production",
						{"row_id": row_id, "path": path})
		var validators: Array = realization.get("validators", [])
		for validator: String in validators:
			if strip_comments(str(sources[validator])).find(literal) < 0:
				return _fail(&"matrix_validator_role_missing", "an attributed validator does not carry its role literal",
					{"row_id": row_id, "validator": validator})
		row["role"] = role
		row["realization"] = "realized" if not producers.is_empty() else "unrealized"
		row["producers"] = producers.duplicate()
		row["validators"] = validators.duplicate()
		row["deviation"] = str(realization.get("deviation", ""))
		bound.append(row)
		order.append(row_id)
	return _ok({"row_count": bound.size(), "derivation_order": order, "rows": bound})


## Public census entry point: every `derive_child` occurrence in autoload/ and scripts/ at the
## named commit, classified. The gate test runs it against HEAD; the record binds the subject.
static func derive_child_census(subject_commit: String) -> Dictionary:
	return _derive_child_census(subject_commit, {})


static func _derive_child_census(subject_commit: String, _sources: Dictionary) -> Dictionary:
	# -B1 carries the preceding line as context (`path-line-text`), which the classifier needs to
	# see a call wrapped across lines. Match lines are `path:line:text`.
	var grep: Dictionary = _git_to_file(PackedStringArray([
		"grep", "-n", "-B1", "-e", "derive_child", subject_commit, "--", "autoload", "scripts",
	]))
	if not grep.get("ok", false):
		return _fail(&"census_grep_failed", "git grep over the subject tree failed", {})
	var hits: Array = []
	var prefix: String = subject_commit + ":"
	var previous_context: Dictionary = {}
	for raw_line: String in str((grep["value"] as Dictionary)["text"]).split("\n"):
		var line: String = raw_line.trim_suffix("\r")
		if not line.begins_with(prefix):
			previous_context = {}
			continue
		var remainder: String = line.substr(prefix.length())
		var hit_match: RegExMatch = RegEx.create_from_string("^([^:]+\\.gd):([0-9]+):(.*)$").search(remainder)
		var context_match: RegExMatch = RegEx.create_from_string("^([^:]+\\.gd)-([0-9]+)-(.*)$").search(remainder)
		if hit_match == null and context_match != null:
			previous_context = {"path": context_match.get_string(1), "line": int(context_match.get_string(2)),
				"text": context_match.get_string(3)}
			continue
		if hit_match == null:
			continue
		var hit: Dictionary = {
			"path": hit_match.get_string(1),
			"line": int(hit_match.get_string(2)),
			"text": hit_match.get_string(3),
		}
		if not previous_context.is_empty() and str(previous_context["path"]) == str(hit["path"]) \
				and int(previous_context["line"]) == int(hit["line"]) - 1:
			hit["previous"] = str(previous_context["text"])
		hits.append(hit)
		previous_context = {"path": hit["path"], "line": hit["line"], "text": hit["text"]}
	if hits.is_empty():
		return _fail(&"census_empty", "no derive_child site was found in the subject tree", {})
	return classify_derive_child_hits(hits)


## An unrealized row's role literal must be absent from the EXECUTABLE text of EVERY committed
## production source, not only the bound ones. The grep runs unquoted (OS.execute drops literal
## quote characters) and every hit line is comment-stripped and tested for the quoted literal
## here, so a doc comment that names the row does not count as a producer. `git grep` exits 1 when
## nothing matches at all, which is absence.
static func _prove_unrealized_roles_absent(subject_commit: String) -> Dictionary:
	for row_id: String in ROW_REALIZATIONS:
		var realization: Dictionary = ROW_REALIZATIONS[row_id]
		if not (realization["producers"] as Array).is_empty():
			continue
		var role: String = str(realization["role"])
		var grep: Dictionary = _git_to_file(PackedStringArray([
			"grep", "-n", "-F", "-e", role, subject_commit, "--", "autoload", "scripts",
		]), [0, 1])
		if not grep.get("ok", false):
			return _fail(&"census_grep_failed", "git grep over the subject tree failed", {"row_id": row_id})
		var literal: String = "\"%s\"" % role
		for raw_line: String in str((grep["value"] as Dictionary)["text"]).split("\n"):
			var line: String = raw_line.trim_suffix("\r")
			var second_colon: int = line.find(":", line.find(":") + 1)
			var third_colon: int = line.find(":", second_colon + 1)
			if third_colon < 0:
				continue
			if strip_comments(line.substr(third_colon + 1)).find(literal) >= 0:
				return _fail(&"matrix_unrealized_row_realized", "an unrealized row's role literal appeared in production",
					{"row_id": row_id, "line": line})
	return _ok({})


static func _bind_registry(subject_commit: String) -> Dictionary:
	var manifest: Dictionary = _blob_bytes_at_commit(subject_commit, REGISTRY_MANIFEST_PATH)
	if not manifest.get("ok", false):
		return manifest
	var schema: Dictionary = _blob_bytes_at_commit(subject_commit, REGISTRY_SCHEMA_PATH)
	if not schema.get("ok", false):
		return schema
	var manifest_bytes: PackedByteArray = (manifest["value"] as Dictionary)["bytes"]
	var parsed: Dictionary = _STRICT_JSON.parse_object(manifest_bytes.get_string_from_utf8())
	if not parsed.get("ok", false):
		return _fail(&"registry_manifest_unparsable", "the committed registry manifest is not strict JSON", {})
	var loaded: Dictionary = _REGISTRY.from_manifest(parsed["value"] as Dictionary)
	if not loaded.get("ok", false):
		return _fail(&"registry_manifest_rejected", "the committed registry manifest fails the production validator",
			{"code": str(loaded.get("code", &""))})
	var value: Dictionary = loaded["value"]
	var document: Dictionary = parsed["value"]
	return _ok({
		"manifest_path": REGISTRY_MANIFEST_PATH,
		"manifest_sha256": _digest_bytes(manifest_bytes),
		"schema_path": REGISTRY_SCHEMA_PATH,
		"schema_sha256": _digest_bytes((schema["value"] as Dictionary)["bytes"]),
		"registry_fingerprint": str(value["registry_fingerprint"]),
		"registry_version": int(document.get("registry_version", 0)),
		"record_count": (document.get("records", []) as Array).size(),
	})


static func _bind_state_schema(sources: Dictionary) -> Dictionary:
	var text: String = str(sources["scripts/domain/schedule/ScheduleStateSchema.gd"])
	var aggregate: Dictionary = parse_string_array_constant(text, "AGGREGATE_KEYS")
	var entry: Dictionary = parse_string_array_constant(text, "ENTRY_KEYS")
	var receipt: Dictionary = parse_string_array_constant(text, "COMMIT_RECEIPT_KEYS")
	for parsed: Dictionary in [aggregate, entry, receipt]:
		if not parsed.get("ok", false):
			return parsed
	return _ok({
		"path": "scripts/domain/schedule/ScheduleStateSchema.gd",
		"aggregate_keys": (aggregate["value"] as Dictionary)["values"],
		"entry_keys": (entry["value"] as Dictionary)["values"],
		"commit_receipt_keys": (receipt["value"] as Dictionary)["values"],
	})


static func _bind_ledger(subject_commit: String, sources: Dictionary) -> Dictionary:
	var schema: Dictionary = _blob_bytes_at_commit(subject_commit, LEDGER_SCHEMA_PATH)
	if not schema.get("ok", false):
		return schema
	var text: String = strip_comments(str(sources["scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd"]))
	var fixed: Dictionary = parse_string_constant(text, "FIXED_PATH")
	if not fixed.get("ok", false):
		return fixed
	for code: String in ["publication_record_conflict", "first_delivery"]:
		if text.find(code) < 0:
			return _fail(&"ledger_code_missing", "the ledger source lacks a frozen code or field", {"code": code})
	var commit_text: String = strip_comments(str(sources["scripts/application/schedule/GameStateScheduleCommitPort.gd"]))
	if commit_text.find("schedule_publication_conflict") < 0:
		return _fail(&"ledger_code_missing", "the commit port lacks schedule_publication_conflict", {})
	var start_text: String = strip_comments(str(sources["scripts/application/run/DayResolutionStartPort.gd"]))
	if start_text.find("day_resolution_start_publication_conflict") < 0:
		return _fail(&"ledger_code_missing", "the start port lacks day_resolution_start_publication_conflict", {})
	var kinds: Array[String] = []
	for kind: String in ["schedule_commit", "day_resolution_start"]:
		if text.find("\"%s\"" % kind) < 0:
			return _fail(&"ledger_kind_missing", "the ledger source lacks a publication kind", {"kind": kind})
		kinds.append(kind)
	var record_keys: Array[String] = []
	for key: String in ["key", "kind", "semantic_receipt", "publication", "publication_sha256"]:
		if text.find("\"%s\"" % key) < 0:
			return _fail(&"ledger_record_key_missing", "the ledger source lacks a record key", {"key": key})
		record_keys.append(key)
	return _ok({
		"path": "scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd",
		"schema_path": LEDGER_SCHEMA_PATH,
		"schema_sha256": _digest_bytes((schema["value"] as Dictionary)["bytes"]),
		"fixed_path": str((fixed["value"] as Dictionary)["value"]),
		"kinds": kinds,
		"conflict_codes": {
			"ledger": "publication_record_conflict",
			"schedule_commit": "schedule_publication_conflict",
			"day_resolution_start": "day_resolution_start_publication_conflict",
		},
		"first_delivery_field": "first_delivery",
		"record_keys": record_keys,
	})


static func _bind_day_advance(sources: Dictionary) -> Dictionary:
	var text: String = str(sources["scripts/application/run/CausalDayAdvanceIdentityPort.gd"])
	var request: Dictionary = parse_string_array_constant(text, "REQUEST_KEYS")
	var receipt: Dictionary = parse_string_array_constant(text, "RECEIPT_KEYS")
	var kinds: Dictionary = parse_string_array_constant(text, "ALLOWED_RESOLUTION_KIND")
	for parsed: Dictionary in [request, receipt, kinds]:
		if not parsed.get("ok", false):
			return parsed
	if strip_comments(text).find("\"%s:%s\" % [resolution_kind, source_resolution_receipt_id]") < 0:
		return _fail(&"day_advance_key_builder_missing", "the allocation key builder resolution_kind:source_resolution_receipt_id is absent", {})
	for path: String in ["scripts/application/run/DayResolutionCoordinator.gd",
			"scripts/application/run/GameStateDayResolutionPort.gd", "autoload/GameState.gd"]:
		if strip_comments(str(sources[path])).find("issue(&\"causal_day_instance\")") >= 0:
			return _fail(&"raw_causal_day_issue_present", "a Plan-01 owner issues a causal day directly", {"path": path})
	return _ok({
		"path": "scripts/application/run/CausalDayAdvanceIdentityPort.gd",
		"request_keys": (request["value"] as Dictionary)["values"],
		"receipt_keys": (receipt["value"] as Dictionary)["values"],
		"resolution_kinds": (kinds["value"] as Dictionary)["values"],
		"allocation_key_format": "resolution_kind:source_resolution_receipt_id",
		"raw_causal_day_issue_in_plan01": false,
	})


static func _bind_bootstrap_probe(sources: Dictionary, bootstrap_test_names: Array) -> Dictionary:
	var text: String = str(sources["autoload/ApplicationBootstrap.gd"])
	var keys: Dictionary = parse_probe_keys(text)
	if not keys.get("ok", false):
		return keys
	for attesting: String in READINESS_ATTESTING_TESTS:
		if not (attesting in bootstrap_test_names):
			return _fail(&"readiness_attestation_missing", "the bound bootstrap-identity log did not run a readiness test",
				{"test": attesting})
	var owners: Dictionary = {}
	for key: String in BOOTSTRAP_PROBE_OWNERS:
		owners[key] = str(BOOTSTRAP_PROBE_OWNERS[key])
	return _ok({
		"path": "autoload/ApplicationBootstrap.gd",
		"keys": (keys["value"] as Dictionary)["keys"],
		"owner_classes": owners,
		"readiness": {
			"hospital_presentation_ready": true,
			"dating_presentation_ready": false,
			"presentation_producer_ready": false,
		},
		"readiness_attested_by_tests": READINESS_ATTESTING_TESTS.duplicate(),
		"instance_ids_serialized": false,
	})


## The frozen stage arrays parsed from DayResolutionPlan, plus the retired ending-composition
## residue the two Plan-01 run ports still carry, sealed as unreachable: reachability is decided by
## the stage arrays alone, which this binding requires to contain none of the retired names.
static func _bind_day_resolution_stages(sources: Dictionary) -> Dictionary:
	var plan_text: String = str(sources["scripts/domain/run/DayResolutionPlan.gd"])
	var day_1_6: Dictionary = parse_string_array_constant(plan_text, "DAY_1_6_STAGES")
	var day_7: Dictionary = parse_string_array_constant(plan_text, "DAY_7_STAGES")
	if not day_1_6.get("ok", false) or not day_7.get("ok", false):
		return _fail(&"stage_arrays_missing", "DayResolutionPlan stage arrays are absent", {})
	var arrays: Array = [(day_1_6["value"] as Dictionary)["values"], (day_7["value"] as Dictionary)["values"]]
	for retired: String in RETIRED_ENDING_STAGES:
		for stage_array: Array in arrays:
			if retired in stage_array:
				return _fail(&"ending_stage_reachable", "a retired ending stage is in a frozen stage array", {"stage": retired})
	var residue_in: Array = []
	var default_plan_in: Array = []
	for path: String in ["scripts/application/run/DayResolutionCoordinator.gd", "scripts/application/run/GameStateDayResolutionPort.gd"]:
		var code: String = strip_comments(str(sources[path]))
		for retired: String in RETIRED_ENDING_STAGES:
			if code.find("\"%s\"" % retired) >= 0 and not (path in residue_in):
				residue_in.append(path)
		if code.find("_default_ending_plan") >= 0 or code.find("\"ending.alone\"") >= 0:
			default_plan_in.append(path)
	return _ok({
		"path": "scripts/domain/run/DayResolutionPlan.gd",
		"day_1_6": arrays[0],
		"day_7": arrays[1],
		"retired_ending_stages": RETIRED_ENDING_STAGES.duplicate(),
		"retired_ending_residue_in": residue_in,
		"default_ending_plan_residue_in": default_plan_in,
		"ending_stages_reachable": false,
		"deviation": "DEVIATION-3, recorded in the dwm-p2r.14 bead comment of 2026-08-18 03:11 (Task 7 checkpoint 1; bead comments are not part of the exported snapshot): a Day-7 resolution driven through DayResolutionPlan's stage arrays ends at checkpoint_day7_provenance and never enters ENDING; the resolve_ending_plan / enter_ending / ending_autosave stage contracts and the _default_ending_plan() fallback (ending.alone) remain as dead residue in the coordinator and state port, reachable from no stage array, and are retired-dead rather than Plan-01 composition. GameState's retained interim advance_day_or_end / resolve_day7_ending path is the unchanged 11-ID interim ending foundation outside Plan 01 and is not sealed here",
	})


## The co-generated GameState surface inventory, hashed from the working tree because it is a
## generated artifact committed beside this record in the same evidence commit (never a source).
static func _bind_generated_surface() -> Dictionary:
	if not FileAccess.file_exists(GENERATED_SURFACE_PATH):
		return _fail(&"generated_surface_missing", "the co-generated surface inventory is absent", {})
	return _ok({"path": GENERATED_SURFACE_RELATIVE,
		"sha256": _digest_bytes(FileAccess.get_file_as_bytes(GENERATED_SURFACE_PATH))})


## Re-validates the recorded v3 boundary from ITS OWN commit: the record blob comes from the
## subject tree, the three source digests are re-read at the recorded boundary commit, and the
## version constants are parsed from those boundary blobs rather than from the current tree.
static func _bind_v3_boundary(subject_commit: String, sources: Dictionary) -> Dictionary:
	var record_blob: Dictionary = _blob_bytes_at_commit(subject_commit, V3_BOUNDARY_RECORD_PATH)
	if not record_blob.get("ok", false):
		return record_blob
	var bytes: PackedByteArray = (record_blob["value"] as Dictionary)["bytes"]
	var parsed: Dictionary = _STRICT_JSON.parse_object(bytes.get_string_from_utf8())
	if not parsed.get("ok", false):
		return _fail(&"v3_boundary_unparsable", "the recorded v3 boundary is not strict JSON", {})
	var boundary: Dictionary = parsed["value"]
	var boundary_commit: String = str(boundary.get("boundary_commit", ""))
	if str(boundary.get("owner_beads_id", "")) != V3_BOUNDARY_OWNER \
			or str(boundary.get("boundary_subject", "")) != V3_BOUNDARY_SUBJECT:
		return _fail(&"v3_boundary_owner_invalid", "the recorded v3 boundary owner or subject differs", {})
	var proof: Dictionary = _prove_commit(boundary_commit, V3_BOUNDARY_SUBJECT, &"v3_boundary")
	if not proof.get("ok", false):
		return proof
	var ancestry: Dictionary = _git(PackedStringArray(["merge-base", "--is-ancestor", boundary_commit, subject_commit]))
	if not ancestry.get("ok", false):
		return _fail(&"v3_boundary_not_ancestor", "the v3 boundary is not an ancestor of the subject", {})
	var versions: Dictionary = {}
	for pair: Array in [["run_snapshot_schema", "SCHEMA_VERSION"], ["save_document_schema", "DOCUMENT_VERSION"], ["migration", ""]]:
		var path: String = str(boundary.get(str(pair[0]) + "_path", ""))
		var source: Dictionary = _blob_bytes_at_commit(boundary_commit, path)
		if not source.get("ok", false):
			return source
		var raw: PackedByteArray = (source["value"] as Dictionary)["bytes"]
		if _digest_bytes(raw) != str(boundary.get(str(pair[0]) + "_sha256", "")):
			return _fail(&"v3_boundary_source_hash_mismatch", "a v3 boundary source digest differs at its own commit",
				{"path": path})
		if not str(pair[1]).is_empty():
			var constant: Dictionary = parse_int_constant(raw.get_string_from_utf8(), str(pair[1]))
			if not constant.get("ok", false):
				return constant
			versions[str(pair[0])] = int((constant["value"] as Dictionary)["value"])
	var migration_text: String = strip_comments(str(sources["scripts/infrastructure/save/SaveMigrations.gd"]))
	if migration_text.find("unmigratable_legacy_schedule") < 0:
		return _fail(&"migration_rejection_code_missing", "SaveMigrations lacks unmigratable_legacy_schedule", {})
	var changed: Array = []
	for pair: Array in [["run_snapshot_schema", ""], ["save_document_schema", ""], ["migration", ""]]:
		var path: String = str(boundary.get(str(pair[0]) + "_path", ""))
		if sources.has(path) and _digest(str(sources[path])) != str(boundary.get(str(pair[0]) + "_sha256", "")):
			changed.append(path)
	return _ok({
		"record_path": V3_BOUNDARY_RECORD_PATH,
		"record_sha256": _digest_bytes(bytes),
		"owner_beads_id": V3_BOUNDARY_OWNER,
		"boundary_commit": boundary_commit,
		"boundary_subject": V3_BOUNDARY_SUBJECT,
		"run_snapshot_schema_version": int(versions["run_snapshot_schema"]),
		"save_document_version": int(versions["save_document_schema"]),
		"sources_revalidated_at_boundary": true,
		"sources_changed_since_boundary": changed,
		"migration_rejection_code": "unmigratable_legacy_schedule",
	})


static func _bind_current_versions(sources: Dictionary) -> Dictionary:
	var snapshot: Dictionary = parse_int_constant(str(sources["scripts/domain/run/RunSnapshotSchema.gd"]), "SCHEMA_VERSION")
	var document: Dictionary = parse_int_constant(str(sources["scripts/infrastructure/save/SaveDocumentSchema.gd"]), "DOCUMENT_VERSION")
	for parsed: Dictionary in [snapshot, document]:
		if not parsed.get("ok", false):
			return parsed
	var state_text: String = str(sources["scripts/domain/schedule/ScheduleStateSchema.gd"])
	var aggregate: Dictionary = parse_string_array_constant(state_text, "AGGREGATE_KEYS")
	var entry: Dictionary = parse_string_array_constant(state_text, "ENTRY_KEYS")
	if not aggregate.get("ok", false) or not entry.get("ok", false):
		return _fail(&"state_schema_keys_missing", "ScheduleStateSchema key constants are absent", {})
	var aggregate_keys: Array = ((aggregate["value"] as Dictionary)["values"] as Array).duplicate()
	var entry_keys: Array = ((entry["value"] as Dictionary)["values"] as Array).duplicate()
	aggregate_keys.sort()
	entry_keys.sort()
	return _ok({
		"run_snapshot_schema_version": int((snapshot["value"] as Dictionary)["value"]),
		"save_document_version": int((document["value"] as Dictionary)["value"]),
		"committed_schedule_keys_preserved": aggregate_keys == COMMITTED_AGGREGATE_KEYS and entry_keys == COMMITTED_ENTRY_KEYS,
	})


static func _bind_strict_branch(subject_commit: String) -> Dictionary:
	var tip: Dictionary = _git(PackedStringArray(["rev-parse", "--verify", STRICT_BRANCH + "^{commit}"]))
	if not tip.get("ok", false):
		return _fail(&"strict_branch_missing", "the quarantined strict branch cannot be resolved", {})
	var tip_id: String = str(tip["output"]).strip_edges().substr(0, 40)
	var base: Dictionary = _git(PackedStringArray(["merge-base", subject_commit, tip_id]))
	if not base.get("ok", false):
		return _fail(&"strict_branch_merge_base_missing", "the strict branch has no merge base with the subject", {})
	var base_id: String = str(base["output"]).strip_edges().substr(0, 40)
	if not tip_id.begins_with(STRICT_BRANCH_TIP_PREFIX) or not base_id.begins_with(STRICT_BRANCH_MERGE_BASE_PREFIX):
		return _fail(&"strict_branch_drift", "the strict branch tip or merge base differs from the recorded quarantine",
			{"tip": tip_id, "merge_base": base_id})
	var integrated: Dictionary = _git(PackedStringArray(["merge-base", "--is-ancestor", tip_id, subject_commit]))
	if integrated.get("ok", false):
		return _fail(&"strict_branch_integrated", "the quarantined strict branch was merged into the subject", {})
	return _ok({"branch": STRICT_BRANCH, "merge_base": base_id, "tip": tip_id,
		"disposition": "quarantined_evidence_only"})


static func _bind_sylvia_witness(sources: Dictionary) -> Dictionary:
	var text: String = str(sources["scripts/domain/hospital/HospitalRules.gd"])
	var kind: Dictionary = parse_string_constant(text, "WITNESS_KIND")
	var resolution_kind: Dictionary = parse_string_constant(text, "WITNESS_RESOLUTION_KIND")
	var affection: Dictionary = parse_int_constant(text, "WITNESS_AFFECTION_DELTA")
	var dark: Dictionary = parse_int_constant(text, "WITNESS_DARK_DELTA")
	var attitude: Dictionary = parse_string_constant(text, "WITNESS_ATTITUDE")
	var tier: Dictionary = parse_string_constant(text, "WITNESS_TIER_TRANSITION")
	for parsed: Dictionary in [kind, resolution_kind, affection, dark, attitude, tier]:
		if not parsed.get("ok", false):
			return parsed
	if strip_comments(text).find("\"care.%s.day%d\" % [WITNESS_FRIEND_ID, care_day]") < 0:
		return _fail(&"witness_care_entry_format_missing", "HospitalRules does not build care.<friend>.day<N> care entry ids", {})
	var contacts: String = strip_comments(str(sources["scripts/domain/contact/ContactInvitationState.gd"]))
	if contacts.find("sylvia_hospital_witness_receipts") < 0:
		return _fail(&"witness_index_missing", "the Contacts handoff index is absent", {})
	if contacts.find("\"applied\"") >= 0:
		return _fail(&"witness_applied_flag_present", "Plan 01 must not add an applied flag to the witness", {})
	return _ok({
		"owner_path": "scripts/domain/hospital/HospitalRules.gd",
		"kind": str((kind["value"] as Dictionary)["value"]),
		"resolution_kind": str((resolution_kind["value"] as Dictionary)["value"]),
		"contacts_index": "sylvia_hospital_witness_receipts",
		"consequence": {
			"affection_delta": int((affection["value"] as Dictionary)["value"]),
			"dark_delta": int((dark["value"] as Dictionary)["value"]),
			"attitude": str((attitude["value"] as Dictionary)["value"]),
			"tier_transition": str((tier["value"] as Dictionary)["value"]),
		},
		"care_followup_entry_id_format": "care.sylvia.day<source_day+1>",
		"plan_care_followup_entry_id_format": "contact.hospital_care.sylvia.day<source_day+1>",
		"application_owner": "dwm-oyo.4",
		"applied_flag_present": false,
		"issuer_anchored": false,
		"deviation": str((ROW_REALIZATIONS["P01.hospital.sylvia_witness"] as Dictionary)["deviation"])
			+ "; the realized care_followup_entry_id is care.sylvia.day<N+1> where the plan text says contact.hospital_care.sylvia.day<N+1> -- an unrecorded cross-plan drift surfaced by the 2026-08-21 seal review and left for dwm-oyo.4's owner to settle",
	})


static func _bind_day7_provenance(sources: Dictionary) -> Dictionary:
	var text: String = str(sources["scripts/domain/schedule/Day7ScheduleProvenance.gd"])
	var kind: Dictionary = parse_string_constant(text, "CHILD_KIND")
	var day: Dictionary = parse_int_constant(text, "DAY")
	var empty: Dictionary = parse_string_constant(text, "CAUSE_EMPTY_DONE")
	var solo: Dictionary = parse_string_constant(text, "CAUSE_SCHEDULED_SOLO")
	for parsed: Dictionary in [kind, day, empty, solo]:
		if not parsed.get("ok", false):
			return parsed
	return _ok({
		"path": "scripts/domain/schedule/Day7ScheduleProvenance.gd",
		"child_kind": str((kind["value"] as Dictionary)["value"]),
		"day": int((day["value"] as Dictionary)["value"]),
		"causes": [str((empty["value"] as Dictionary)["value"]), str((solo["value"] as Dictionary)["value"])],
		"terminal_intent_owner": "dwm-oyo.3",
		"final_plan_owner": "dwm-oyo.6",
		"ending_plan_in_plan01_composition": false,
	})


static func _bind_required_surface(subject_commit: String) -> Dictionary:
	var blob: Dictionary = _blob_bytes_at_commit(subject_commit, REQUIRED_SURFACE_PATH)
	if not blob.get("ok", false):
		return blob
	var bytes: PackedByteArray = (blob["value"] as Dictionary)["bytes"]
	var parsed: Dictionary = _STRICT_JSON.parse_object(bytes.get_string_from_utf8())
	if not parsed.get("ok", false):
		return _fail(&"required_surface_unparsable", "the committed required-surface manifest is not strict JSON", {})
	var seams: Array[String] = [
		"capture_schedule_commit_state", "prepare_schedule_commit_candidate",
		"commit_schedule_commit_candidate", "rollback_schedule_commit_state", "publish_schedule_commit",
		"committed_schedule_published",
	]
	var classified: Array[String] = []
	for entry: Variant in ((parsed["value"] as Dictionary).get("symbols", []) as Array):
		var symbol: Dictionary = entry
		if str(symbol.get("symbol", "")) in seams and str(symbol.get("availability", "")) == "current" \
				and str(symbol.get("disposition", "")) == "retain":
			classified.append(str(symbol["symbol"]))
	for seam: String in seams:
		if not (seam in classified):
			return _fail(&"required_surface_seam_unclassified", "a Task-4 GameState seam is not classified current/retain",
				{"symbol": seam})
	return _ok({"path": REQUIRED_SURFACE_PATH, "sha256": _digest_bytes(bytes), "task4_seams_classified": seams})


static func _bind_fixtures(subject_commit: String) -> Dictionary:
	var listing: Dictionary = _git_to_file(PackedStringArray(
		["ls-tree", "-r", "--name-only", subject_commit, "--"] + FIXTURE_ROOTS))
	if not listing.get("ok", false):
		return _fail(&"fixture_listing_failed", "git ls-tree over the fixture roots failed", {})
	var records: Array[Dictionary] = []
	for raw_line: String in str((listing["value"] as Dictionary)["text"]).split("\n"):
		var path: String = raw_line.trim_suffix("\r").strip_edges()
		if path.is_empty() or not path.ends_with(".json"):
			continue
		var blob: Dictionary = _blob_bytes_at_commit(subject_commit, path)
		if not blob.get("ok", false):
			return blob
		var bytes: PackedByteArray = (blob["value"] as Dictionary)["bytes"]
		var parsed: Dictionary = _STRICT_JSON._parse_value_document(bytes.get_string_from_utf8())
		if not parsed.get("ok", false):
			return _fail(&"fixture_unparsable", "a checked-in fixture is not strict JSON", {"path": path})
		var audited: Dictionary = audit_fixture_committed_schedules(parsed["value"])
		if not audited.get("ok", false):
			return _fail(str(audited.get("code", &"fixture_entry_invalid")), str(audited.get("message", "")),
				{"path": path, "details": audited.get("details", {})})
		records.append({
			"path": path,
			"sha256": _digest_bytes(bytes),
			"committed_schedule_aggregates": int((audited["value"] as Dictionary)["aggregates"]),
			"committed_schedule_entries": int((audited["value"] as Dictionary)["entries"]),
		})
	if records.is_empty():
		return _fail(&"fixtures_missing", "no checked-in snapshot or save fixture was found", {})
	return _ok(records)


static func _bind_beads(beads_snapshot_path: String) -> Dictionary:
	if not FileAccess.file_exists(beads_snapshot_path):
		return _fail(&"beads_snapshot_missing", "the Beads snapshot is absent", {"path": beads_snapshot_path})
	var parsed: Dictionary = _STRICT_JSON._parse_value_document(FileAccess.get_file_as_string(beads_snapshot_path))
	if not parsed.get("ok", false) or typeof(parsed.get("value")) != TYPE_ARRAY:
		return _fail(&"beads_snapshot_unparsable", "the Beads snapshot is not a strict JSON array", {})
	var by_id: Dictionary = {}
	for entry: Variant in (parsed["value"] as Array):
		if typeof(entry) == TYPE_DICTIONARY:
			by_id[str((entry as Dictionary).get("id", ""))] = entry
	var chain: Array[Dictionary] = []
	for id: String in BEADS_CHAIN:
		if not by_id.has(id):
			return _fail(&"beads_chain_member_missing", "a chain bead is absent from the snapshot", {"id": id})
		var issue: Dictionary = by_id[id]
		var depends_on: Array[String] = []
		for dependency: Variant in (issue.get("dependencies", []) as Array):
			var record: Dictionary = dependency
			if str(record.get("type", "")) == "blocks":
				depends_on.append(str(record.get("depends_on_id", "")))
		depends_on.sort()
		chain.append({"id": id, "status": str(issue.get("status", "")), "depends_on": depends_on})
	var owner: Dictionary = by_id[OWNER_BEADS_ID]
	var metadata: Dictionary = (owner.get("metadata", {}) as Dictionary).get("phase2r", {})
	var requirement_ids: Array = (metadata.get("requirement_ids", []) as Array).duplicate()
	if requirement_ids != REQUIREMENT_IDS:
		return _fail(&"beads_requirement_ids_drift", "dwm-p2r.15 requirement ids differ from the frozen set",
			{"actual": requirement_ids})
	if (metadata.get("exclusions", []) as Array) != EXCLUSIONS:
		return _fail(&"beads_exclusions_drift", "dwm-p2r.15 exclusions differ from the frozen set", {})
	if str(owner.get("status", "")) == "closed":
		return _fail(&"beads_owner_already_closed", "dwm-p2r.15 must still be open when its evidence is generated", {})
	if str((by_id["dwm-p2r.7"] as Dictionary).get("status", "")) == "closed":
		return _fail(&"beads_parent_feature_closed", "dwm-p2r.7 is judged separately and must not be closed here", {})
	for id: String in ["dwm-p2r.12", "dwm-wks", "dwm-p2r.16", "dwm-p2r.13", "dwm-p2r.9", "dwm-p2r.14", "dwm-p2r.18"]:
		if str((by_id[id] as Dictionary).get("status", "")) != "closed":
			return _fail(&"beads_predecessor_open", "a predecessor bead is not closed", {"id": id})
	return _ok({"chain": chain, "requirement_ids": requirement_ids,
		"exclusions": (metadata.get("exclusions", []) as Array).duplicate()})


static func _bind_commands() -> Dictionary:
	var commands: Array[Dictionary] = []
	var green_vectors: Array = []
	var green_publications: Array = []
	var bootstrap_test_names: Array = []
	for binding: Dictionary in COMMAND_BINDINGS:
		var log_path: String = LOG_DIRECTORY.path_join(str(binding["log_name"]))
		if not FileAccess.file_exists(log_path):
			return _fail(&"command_log_missing", "a bound fresh log is absent", {"log": log_path})
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(log_path)
		var parsed: Dictionary = parse_gut_log(bytes.get_string_from_utf8())
		if not parsed.get("ok", false):
			return parsed
		var summary: Dictionary = parsed["value"]
		if not bool(summary["summary_present"]) and str(binding["expect"]) == "green":
			return _fail(&"command_log_without_summary", "a green log carries no GUT run summary", {"log": log_path})
		if str(binding["suite_id"]) == "phase2r_schedule_gate_green":
			green_vectors = summary["vectors"]
			green_publications = summary["publications"]
		if str(binding["suite_id"]) == "phase2r_bootstrap_identity_green":
			bootstrap_test_names = summary["test_names"]
		commands.append({
			"suite_id": str(binding["suite_id"]),
			"log_name": str(binding["log_name"]),
			"log_path": LOG_RELATIVE_DIRECTORY + "/" + str(binding["log_name"]),
			"log_sha256": _digest_bytes(bytes),
			"expect": str(binding["expect"]),
			"suites": (binding["suites"] as Array).duplicate(),
			"executed_suites": summary["executed_suites"],
			"scripts": int(summary["scripts"]),
			"tests": int(summary["tests"]),
			"passing": int(summary["passing"]),
			"failing": int(summary["failing"]),
			"pending": int(summary["pending"]),
			"asserts": int(summary["asserts"]),
			"asserts_total": int(summary["asserts_total"]),
			"load_failures": int(summary["load_failures"]),
		})
	return _ok({"commands": commands, "green_vectors": green_vectors,
		"green_publications": green_publications, "bootstrap_test_names": bootstrap_test_names})


## The publication vectors the gate test printed, bound in frozen order by (owner, kind).
static func _bind_observed_publications(raw_publications: Array) -> Dictionary:
	var by_key: Dictionary = {}
	for raw: Variant in raw_publications:
		var publication: Dictionary = raw
		var key: String = "%s/%s" % [str(publication.get("owner", "")), str(publication.get("kind", ""))]
		if by_key.has(key):
			if _CANONICAL_JSON.stringify(by_key[key]) != _CANONICAL_JSON.stringify(publication):
				return _fail(&"observed_publication_conflict", "the green log carries two different publication vectors for one owner/kind", {"key": key})
			continue
		by_key[key] = publication
	var publications: Array[Dictionary] = []
	for binding: Dictionary in PUBLICATION_BINDINGS:
		var key: String = "%s/%s" % [str(binding["owner"]), str(binding["kind"])]
		if not by_key.has(key):
			return _fail(&"observed_publication_missing", "the green log carries no publication vector for a frozen binding", {"key": key})
		var observed: Dictionary = by_key[key]
		var keys: Array = observed.keys()
		keys.sort()
		if keys != ["conflict_code", "first_delivery_sequence", "kind", "owner", "signal", "signal_counts"]:
			return _fail(&"observed_publication_shape", "a publication vector does not carry the exact six members", {"key": key})
		publications.append({
			"owner": str(observed["owner"]),
			"kind": str(observed["kind"]),
			"first_delivery_sequence": (observed["first_delivery_sequence"] as Array).duplicate(),
			"signal": str(observed["signal"]),
			"signal_counts": (observed["signal_counts"] as Array).duplicate(),
			"conflict_code": str(observed["conflict_code"]),
		})
	return _ok(publications)


static func _bind_observed_vectors(raw_vectors: Array, matrix: Dictionary) -> Dictionary:
	var by_row: Dictionary = {}
	for raw: Variant in raw_vectors:
		var vector: Dictionary = raw
		var row_id: String = str(vector.get("row_id", ""))
		if by_row.has(row_id):
			if _CANONICAL_JSON.stringify(by_row[row_id]) != _CANONICAL_JSON.stringify(vector):
				return _fail(&"observed_vector_conflict", "the green log carries two different vectors for one row", {"row_id": row_id})
			continue
		by_row[row_id] = vector
	var vectors: Array[Dictionary] = []
	for row: Dictionary in (matrix["rows"] as Array):
		var row_id: String = str(row["row_id"])
		if str(row["realization"]) != "realized":
			if by_row.has(row_id):
				return _fail(&"observed_vector_for_unrealized_row", "an unrealized row reported a vector", {"row_id": row_id})
			continue
		if not by_row.has(row_id):
			return _fail(&"observed_vector_missing", "the green log carries no vector for a realized row", {"row_id": row_id})
		var vector: Dictionary = by_row[row_id]
		var keys: Array = vector.keys()
		keys.sort()
		if keys != ["child_id", "child_kind", "ordinal", "parent_receipt_id", "row_id", "source_ids"]:
			return _fail(&"observed_vector_shape", "an observed vector does not carry the exact six members", {"row_id": row_id})
		vectors.append({
			"row_id": row_id,
			"child_kind": str(vector["child_kind"]),
			"ordinal": int(vector["ordinal"]),
			"parent_receipt_id": str(vector["parent_receipt_id"]),
			"child_id": str(vector["child_id"]),
			"source_ids": (vector["source_ids"] as Array).duplicate(),
		})
	return _ok(vectors)


# =================================================================================================
# Small helpers
# =================================================================================================

static func _audit_value(value: Variant, path: String, totals: Dictionary) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		var object: Dictionary = value
		for key: Variant in object:
			var member: Variant = object[key]
			if str(key) == "committed_schedule" and typeof(member) == TYPE_DICTIONARY:
				var aggregate: Dictionary = member
				var aggregate_keys: Array = aggregate.keys()
				aggregate_keys.sort()
				if not aggregate_keys.is_empty() and aggregate_keys != COMMITTED_AGGREGATE_KEYS:
					return _fail(&"fixture_aggregate_keys_invalid", "a fixture committed_schedule is not the exact aggregate", {"path": path})
				totals["aggregates"] = int(totals["aggregates"]) + 1
				for entry: Variant in (aggregate.get("entries", []) as Array):
					if typeof(entry) != TYPE_DICTIONARY:
						return _fail(&"fixture_entry_invalid", "a fixture committed entry is not an object", {"path": path})
					var entry_keys: Array = (entry as Dictionary).keys()
					entry_keys.sort()
					if entry_keys != COMMITTED_ENTRY_KEYS:
						return _fail(&"fixture_entry_keys_invalid", "a fixture committed entry does not carry the exact ten keys", {"path": path})
					for field: String in CALLER_OWNED_ENTRY_FIELDS:
						if (entry as Dictionary).has(field):
							return _fail(&"fixture_entry_caller_owned", "a fixture committed entry carries a caller-owned field", {"path": path, "field": field})
					totals["entries"] = int(totals["entries"]) + 1
			var failure: Dictionary = _audit_value(member, path + "." + str(key), totals)
			if not failure.is_empty():
				return failure
	elif typeof(value) == TYPE_ARRAY:
		var index: int = 0
		for item: Variant in (value as Array):
			var failure: Dictionary = _audit_value(item, "%s[%d]" % [path, index], totals)
			if not failure.is_empty():
				return failure
			index += 1
	return {}


static func _all_producer_paths() -> Array[String]:
	var paths: Array[String] = []
	for row_id: String in ROW_REALIZATIONS:
		for producer: String in ((ROW_REALIZATIONS[row_id] as Dictionary)["producers"] as Array):
			if not (producer in paths):
				paths.append(producer)
	return paths


static func _row_by_id(rows: Array, row_id: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row["row_id"]) == row_id:
			return row
	return {}


static func _read_count(line: String, label: String, key: String, counts: Dictionary) -> void:
	if not line.begins_with(label):
		return
	var remainder: String = line.substr(label.length())
	if remainder.is_empty() or remainder[0] != " ":
		return
	var trimmed: String = remainder.strip_edges()
	if trimmed.is_valid_int():
		counts[key] = int(trimmed)
		if key == "asserts":
			counts["asserts_total"] = int(trimmed)
	elif key == "asserts" and trimmed.find("/") > 0:
		# GUT prints `Asserts passed/total` when any assertion failed.
		var passed: String = trimmed.substr(0, trimmed.find("/"))
		var total: String = trimmed.substr(trimmed.find("/") + 1)
		if passed.is_valid_int() and total.is_valid_int():
			counts["asserts"] = int(passed)
			counts["asserts_total"] = int(total)


static func _paren_depth(text: String) -> int:
	var depth: int = 0
	var in_string: String = ""
	for character: String in text:
		if not in_string.is_empty():
			if character == in_string:
				in_string = ""
			continue
		if character == "\"" or character == "'":
			in_string = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
	return depth


static func _matching_close(text: String, open_at: int) -> int:
	var depth: int = 0
	var in_string: String = ""
	for position: int in range(open_at, text.length()):
		var character: String = text[position]
		if not in_string.is_empty():
			if character == in_string:
				in_string = ""
			continue
		if character == "\"" or character == "'":
			in_string = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
			if depth == 0:
				return position
	return -1


## Splits a parameter list on top-level commas only, so `Array[String]` defaults and nested
## brackets do not split a single parameter in two.
static func _split_parameters(text: String) -> Array[String]:
	var parameters: Array[String] = []
	var depth: int = 0
	var current: String = ""
	var in_string: String = ""
	for character: String in text:
		if not in_string.is_empty():
			current += character
			if character == in_string:
				in_string = ""
			continue
		if character == "\"" or character == "'":
			in_string = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif character == "," and depth == 0:
			parameters.append(current)
			current = ""
			continue
		current += character
	parameters.append(current)
	return parameters


static func _find_all(haystack: PackedByteArray, needle: PackedByteArray) -> Array[int]:
	var hits: Array[int] = []
	if needle.is_empty() or haystack.size() < needle.size():
		return hits
	var limit: int = haystack.size() - needle.size()
	var offset: int = 0
	while offset <= limit:
		var matched: bool = true
		for index: int in range(needle.size()):
			if haystack[offset + index] != needle[index]:
				matched = false
				break
		if matched:
			hits.append(offset)
			offset += needle.size()
		else:
			offset += 1
	return hits


static func _digest(text: String) -> String:
	return _digest_bytes(text.to_utf8_buffer())


static func _digest_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for byte: int in value.to_utf8_buffer():
		if not (byte >= 48 and byte <= 57) and not (byte >= 97 and byte <= 102):
			return false
	return true


static func _is_commit_id(value: String) -> bool:
	return value.length() == 40 and _is_sha256(value + "0".repeat(24))


static func _repository_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")


static func _git(arguments: PackedStringArray) -> Dictionary:
	var repository: String = _repository_root()
	var full: PackedStringArray = PackedStringArray(["-c", "safe.directory=%s" % repository, "-C", repository])
	full.append_array(arguments)
	var output: Array = []
	var exit_code: int = OS.execute("git", full, output, true)
	return {"ok": exit_code == 0, "exit_code": exit_code, "output": "".join(PackedStringArray(output))}


## Runs git with stdout redirected to a process-local scratch file and returns the exact bytes.
## OS.execute() cannot reproduce multi-line or trailing-newline output faithfully; a file can.
static func _git_to_file(arguments: PackedStringArray, allowed_exit_codes: Array = [0]) -> Dictionary:
	var repository: String = _repository_root()
	var scratch: String = OS.get_user_data_dir().path_join("p2r15-git-%d-%s.tmp" % [
		OS.get_process_id(), _digest(" ".join(arguments)).substr(0, 12)])
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var quoted: PackedStringArray = PackedStringArray()
	for argument: String in arguments:
		quoted.append("\"%s\"" % argument if argument.find(" ") >= 0 or argument.find("^") >= 0 else argument)
	var redirect: String = "git -c safe.directory=\"%s\" -C \"%s\" %s > \"%s\"" % [
		repository, repository, " ".join(quoted), scratch]
	var output: Array = []
	var shell: String = "cmd.exe" if OS.get_name() == "Windows" else "sh"
	var flag: String = "/c" if OS.get_name() == "Windows" else "-c"
	var exit_code: int = OS.execute(shell, PackedStringArray([flag, redirect]), output, true)
	if not (exit_code in allowed_exit_codes) or not FileAccess.file_exists(scratch):
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(scratch)
		return _fail(&"git_command_failed", "a git command failed", {"arguments": arguments, "exit_code": exit_code})
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(scratch)
	DirAccess.remove_absolute(scratch)
	return _ok({"bytes": raw, "text": raw.get_string_from_utf8()})


static func _prove_commit(commit: String, expected_subject: String, label: StringName) -> Dictionary:
	if not _is_commit_id(commit):
		return _fail(StringName(str(label) + "_commit_invalid"), "a commit id is not forty lowercase hex characters",
			{"commit": commit})
	var subject: Dictionary = _git(PackedStringArray(["show", "-s", "--format=%s", commit]))
	if not subject.get("ok", false):
		return _fail(StringName(str(label) + "_commit_missing"), "the named commit cannot be read", {"commit": commit})
	if str(subject["output"]).strip_edges() != expected_subject:
		return _fail(StringName(str(label) + "_subject_mismatch"), "the named commit subject differs",
			{"actual": str(subject["output"]).strip_edges()})
	var ancestry: Dictionary = _git(PackedStringArray(["merge-base", "--is-ancestor", commit, "HEAD"]))
	if not ancestry.get("ok", false):
		return _fail(StringName(str(label) + "_commit_not_ancestor"), "the named commit is not an ancestor of HEAD",
			{"commit": commit})
	return _ok({"commit": commit})


static func _source_at_commit(commit: String, path: String) -> Dictionary:
	var bytes: Dictionary = _blob_bytes_at_commit(commit, path)
	if not bytes.get("ok", false):
		return bytes
	var raw: PackedByteArray = (bytes["value"] as Dictionary)["bytes"]
	return _ok({"text": raw.get_string_from_utf8(), "bytes": raw})


static func _blob_bytes_at_commit(commit: String, path: String) -> Dictionary:
	var read: Dictionary = _git_to_file(PackedStringArray(["cat-file", "blob", "%s:%s" % [commit, path]]))
	if not read.get("ok", false):
		return _fail(&"source_missing_at_commit", "a bound path is absent from the named commit",
			{"commit": commit, "path": path})
	return _ok({"bytes": (read["value"] as Dictionary)["bytes"]})


static func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}


# =================================================================================================
# CLI shell
# =================================================================================================

func _init() -> void:
	var parsed: Dictionary = parse_arguments(OS.get_cmdline_user_args())
	if not parsed.get("ok", false):
		printerr("SCHEDULE_GATE_ARGUMENTS_REJECTED: %s: %s" % [str(parsed.get("code", &"")), str(parsed.get("message", ""))])
		quit(1)
		return
	var arguments: Dictionary = parsed["value"]
	if str(arguments["output"]) != OUTPUT_PATH:
		printerr("SCHEDULE_GATE_OUTPUT_REJECTED: output is not the frozen path")
		quit(1)
		return
	var built: Dictionary = build_record(str(arguments["subject_commit"]), str(arguments["beads_snapshot"]))
	if not built.get("ok", false):
		printerr("SCHEDULE_GATE_BUILD_REJECTED: %s: %s %s" % [str(built.get("code", &"")),
			str(built.get("message", "")), JSON.stringify(built.get("details", {}))])
		quit(1)
		return
	var record: Dictionary = (built["value"] as Dictionary)["record"]
	var canonical: Dictionary = canonical_bytes(record)
	if not canonical.get("ok", false):
		printerr("SCHEDULE_GATE_SERIALIZATION_REJECTED: %s" % str(canonical.get("code", &"")))
		quit(1)
		return
	var expected: PackedByteArray = (canonical["value"] as Dictionary)["bytes"]
	if bool(arguments["check"]):
		if not FileAccess.file_exists(OUTPUT_PATH) or FileAccess.get_file_as_bytes(OUTPUT_PATH) != expected:
			printerr("SCHEDULE_GATE_CHECK_FAILED: output bytes differ")
			quit(1)
			return
		print("SCHEDULE_GATE_OK: check")
		quit(0)
		return
	var absolute: String = ProjectSettings.globalize_path(OUTPUT_PATH)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		printerr("SCHEDULE_GATE_WRITE_FAILED: cannot create output directory")
		quit(1)
		return
	var scratch: String = "%s.partial-%d" % [absolute, OS.get_process_id()]
	var file: FileAccess = FileAccess.open(scratch, FileAccess.WRITE)
	if file == null:
		printerr("SCHEDULE_GATE_WRITE_FAILED: cannot open output")
		quit(1)
		return
	file.store_buffer(expected)
	file.flush()
	file.close()
	if FileAccess.get_file_as_bytes(scratch) != expected or DirAccess.rename_absolute(scratch, absolute) != OK:
		DirAccess.remove_absolute(scratch)
		printerr("SCHEDULE_GATE_WRITE_FAILED: staged bytes differ or cannot be promoted")
		quit(1)
		return
	print("SCHEDULE_GATE_OK: write")
	quit(0)
