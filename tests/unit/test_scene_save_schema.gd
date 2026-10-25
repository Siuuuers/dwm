extends "res://addons/gut/test.gd"

const RUN := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const MIGRATIONS := preload("res://scripts/infrastructure/save/SaveMigrations.gd")

# These are wire-boundary unit checks, not substitutes for real owner-backed
# Run9 admission. Full integration supplies the actual issuer, Profile and B2.
func test_scene_versions_do_not_replace_or_migrate_legacy_versions() -> void:
	assert_eq(RUN.SCHEMA_VERSION, 8)
	assert_eq(SAVE.DOCUMENT_VERSION, 8)
	assert_eq(RUN.SCENE_SCHEMA_VERSION, 9)
	assert_eq(SAVE.SCENE_DOCUMENT_VERSION, 9)
	var locator := {"kind": "quick", "slot_id": null}
	assert_eq(MIGRATIONS.migrate_document({"schema_version": 7}, locator).code,
		&"unsupported_run_configuration_schema")
	assert_eq(MIGRATIONS.migrate_document({"schema_version": 10}, locator).code,
		&"unsupported_future_schema")
	var malformed := {"schema_version": 9}
	assert_false(MIGRATIONS.migrate_document(malformed, locator).ok)
	assert_eq(malformed, {"schema_version": 9}, "validation must not synthesize missing Run9 owners")

func test_scene_recovery_cannot_enter_legacy_document_via_proof_family() -> void:
	assert_eq(SAVE._journal_family_error(8, [{"snapshot": {"schema_version": 8}}]), "")
	assert_ne(SAVE._journal_family_error(8, [{"snapshot": {"schema_version": 9}}]), "")
	assert_ne(SAVE._journal_family_error(8, [{"snapshot": {"schema_version": 9.0}}]), "")
	var raw := [{"checkpoint_kind": "line", "snapshot": {"checkpoint_id": "run:1"}}]
	assert_eq(SAVE._scene_proof_error(raw, raw.duplicate(true)), "")
	var substituted := raw.duplicate(true)
	substituted[0].snapshot.checkpoint_id = "run:2"
	assert_ne(SAVE._scene_proof_error(raw, substituted), "")
	assert_ne(SAVE._scene_proof_error(raw, []), "")

func test_scene_admissions_do_not_claim_effect_or_variable_application() -> void:
	var receipt := {"kind": "scene_admission"}
	assert_eq(RUN._validate_receipt_partition({"admit": receipt}, [], []), "")
	assert_ne(RUN._validate_receipt_partition({"admit": receipt}, ["admit"], []), "")
	assert_ne(RUN._validate_receipt_partition({"admit": receipt}, [], ["admit"]), "")
	var effect := {"kind": "effect_transaction"}
	assert_eq(RUN._validate_receipt_partition({"admit": receipt, "effect": effect}, ["effect"], []), "")
	assert_ne(RUN._validate_receipt_partition({"admit": receipt, "effect": effect}, [], []), "")

func test_new_scene_builder_never_fills_calendar_or_missing_owner_defaults() -> void:
	var incomplete := {"lifecycle": {"run_id": "run:scene"}}
	var before := incomplete.duplicate(true)
	var result := RUN.build_scene(incomplete, {}, "scene", null, {}, 1, 0)
	assert_false(result.ok)
	assert_eq(result.code, &"invalid_snapshot_input")
	assert_eq(incomplete, before)
	assert_false(incomplete.has("dating"))
	assert_false(incomplete.has("committed_schedule"))

func test_current_scene_gameplay_omits_retired_relationship_fields_and_requires_progress() -> void:
	var game := preload("res://autoload/GameState.gd")
	var gameplay: Dictionary = game.make_scene_new_run_gameplay()
	assert_eq(RUN._validate_scene_gameplay(gameplay), "")
	for key: String in ["affection", "friend_attitude", "friends", "inter_friend_affection"]:
		assert_false(gameplay.has(key), "new scene state omits " + key)
		var previous_shape := gameplay.duplicate(true)
		previous_shape[key] = {}
		assert_ne(RUN._validate_scene_gameplay(previous_shape), "",
			"previous-build fields are refused instead of silently migrated: " + key)
	for key: String in ["coins", "inventory", "money", "minesweeper_task_rewards_claimed",
			"minesweeper_rounds_left", "shop_purchase_counts", "stats", "story_flags",
			"scene_choices", "scene_challenge_outcomes"]:
		var incomplete := gameplay.duplicate(true)
		incomplete.erase(key)
		assert_ne(RUN._validate_scene_gameplay(incomplete), "", "required progress remains: " + key)

func test_scene_progress_distinguishes_no_closure_from_never_started_and_keeps_occurrences() -> void:
	var gameplay: Dictionary = preload("res://autoload/GameState.gd").make_scene_new_run_gameplay()
	assert_eq(gameplay.scene_choices, {})
	assert_eq(gameplay.scene_challenge_outcomes, {}, "no completed Challenge is not never_started")
	gameplay.scene_choices = {"Day2.threshold": "stay", "Day2.food": "pass", "Day1.photo": "yes"}
	var first := "a".repeat(64)
	var second := "b".repeat(64)
	gameplay.scene_challenge_outcomes = {
		first: {"challenge_id": "Day1.challenge", "outcome": "never_started"},
		second: {"challenge_id": "Day1.challenge", "outcome": "perfect"}}
	var before := gameplay.duplicate(true)
	assert_eq(RUN._validate_scene_gameplay(gameplay), "", "separate occurrences retain separate outcomes")
	assert_eq(gameplay, before, "shape validation does not collapse or synthesize progress")

func test_scene_progress_refuses_malformed_required_facts() -> void:
	var initial: Dictionary = preload("res://autoload/GameState.gd").make_scene_new_run_gameplay()
	for invalid: Variant in [null, [], {"": "pass"}, {"Day1.photo": ""}, {"Day1.photo": false}]:
		var gameplay := initial.duplicate(true)
		gameplay.scene_choices = invalid
		assert_ne(RUN._validate_scene_gameplay(gameplay), "", "invalid choice fact: " + str(invalid))
	var occurrence := "a".repeat(64)
	for invalid: Variant in [null, [], {"bad-occurrence": {"challenge_id": "Day1.challenge", "outcome": "won"}},
			{occurrence: {"challenge_id": "", "outcome": "won"}},
			{occurrence: {"challenge_id": "Day1.challenge", "outcome": "missing"}},
			{occurrence: {"challenge_id": "Day1.challenge"}},
			{occurrence: {"challenge_id": "Day1.challenge", "outcome": "won", "receipt": "extra"}}]:
		var gameplay := initial.duplicate(true)
		gameplay.scene_challenge_outcomes = invalid
		assert_ne(RUN._validate_scene_gameplay(gameplay), "", "invalid outcome fact: " + str(invalid))

func test_retired_story_facts_survive_without_claiming_a_physical_attempt() -> void:
	var occurrence := "a".repeat(64)
	var outcomes := {occurrence: {"challenge_id": "retired.challenge", "outcome": "unfinished", "physical_slot": ""}}
	assert_eq(RUN._validate_scene_progress({"retired.thought": "retired.option"}, outcomes), "")
	outcomes[occurrence].physical_slot = "scene.challenge." + "b".repeat(64)
	assert_eq(RUN._validate_scene_progress({}, outcomes), "", "story occurrence can own a different retained physical attempt")
	outcomes[occurrence].outcome = "never_started"
	assert_ne(RUN._validate_scene_progress({}, outcomes), "", "never started cannot consume an attempt")
	outcomes[occurrence].outcome = "won"
	for malformed: Variant in [null, 1, "scene.challenge.invalid", "dating." + "b".repeat(64)]:
		outcomes[occurrence].physical_slot = malformed
		assert_ne(RUN._validate_scene_progress({}, outcomes), "")

func test_scene_content_normalization_does_not_fill_missing_owners() -> void:
	for source: Dictionary in [{"schema_version": 9},
			{"schema_version": 9, "scene": {}, "gameplay": {}, "narrative_checkpoint": {}}]:
		var before := source.duplicate(true)
		assert_false(RUN.normalize_scene_content(source).ok)
		assert_eq(source, before)

func test_legacy_reading_day_metadata_is_explicit_and_does_not_guess_unknown_entries() -> void:
	assert_eq(RUN.READING6_STORY_DAYS.get("Day3.lavinia"), 3)
	assert_eq(RUN.READING6_STORY_DAYS.get("ending.alone.normal"), 7)
	assert_false(RUN.READING6_STORY_DAYS.has("Day3.invented"))
