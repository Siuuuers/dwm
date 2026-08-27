extends "res://addons/gut/test.gd"
## Frozen 61-to-8 Dialogic timeline migration inventory (Seven-Day Flow Plan 01 Task 1, dwm-oyo.2).
##
## Every number here was measured against the committed tree named by SOURCE_COMMIT, never copied
## from plan prose. The plan text names an earlier inventory commit and a label total of 91; both
## are stale. A later commit retired three ending.*.true labels and dropped a mis-pasted contact
## part, so the maintainer-approved source is the HEAD tree of codex/dwm-p2r13-resealed.
##
## The manifest is the record; this suite re-derives the same facts a second, independent way at
## runtime. It re-reads each .dtl off disk, extracts its own label list and timeline_id, and
## recomputes both SHA-256 and the Git blob id, so a defect in whatever produced the manifest
## cannot vouch for itself.
##
## Access idiom: Dictionary dot access does work in this project (verified), but a missing key
## raises "Invalid access to property or key" and aborts the test body. Every accessor below uses
## get()/[] so that RED reports a clean assertion failure instead of a script error.

const MANIFEST_PATH := "res://data/migrations/dialogic_61_to_8.json"
const SCHEMA_PATH := "res://schemas/manifests/dialogic-migration.schema.json"
const LEGACY_ROOT := "res://dialogic/timelines/en"

const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

## The committed tree this inventory was frozen from.
const SOURCE_COMMIT := "4551f7c51b01baa21de3a080978920e951b42d60"
## The commit that renamed the three ending.*.true labels out of the tree.
const RETIRING_COMMIT := "9114351031ffd874b7079e6df12da915c4d27808"

const ALLOWED_DISPOSITIONS := ["retained", "split", "retired"]

const EXPECTED_LEGACY_FILE_COUNT := 61
const EXPECTED_UID_COUNT := 61
const EXPECTED_TRACKED_TARGET_COUNT := 122
const EXPECTED_LABEL_COUNT := 89
const EXPECTED_SPLIT_COUNT := 27
const EXPECTED_RETAINED_COUNT := 34

## Spec section 12.1: English authoring consolidates to exactly these eight masters. Task 3 creates
## them, so this suite asserts the declared list and never that the files exist yet.
const MASTER_TIMELINES := [
	"res://dialogic/timelines/en/day_1.dtl",
	"res://dialogic/timelines/en/day_2.dtl",
	"res://dialogic/timelines/en/day_3.dtl",
	"res://dialogic/timelines/en/day_4.dtl",
	"res://dialogic/timelines/en/day_5.dtl",
	"res://dialogic/timelines/en/day_6.dtl",
	"res://dialogic/timelines/en/day_7.dtl",
	"res://dialogic/timelines/en/endings.dtl",
]

## Spec section 13.8: thirteen stable ending identities expand to exactly eighteen callable
## presentation entries.
const ENDING_PRESENTATION_ENTRIES := [
	"ending.priscilla.sweet",
	"ending.priscilla.dark",
	"ending.priscilla.observer.full",
	"ending.priscilla.observer.residue",
	"ending.lavinia.sweet",
	"ending.lavinia.dark",
	"ending.lavinia.observer.full",
	"ending.lavinia.observer.residue",
	"ending.sylvia.sweet",
	"ending.sylvia.dark",
	"ending.sylvia.special.full",
	"ending.sylvia.special.residue",
	"ending.priscilla_lavinia.sweet",
	"ending.priscilla_lavinia.dark",
	"ending.priscilla_lavinia.observer.full",
	"ending.priscilla_lavinia.observer.residue",
	"ending.alone.normal",
	"ending.alone.dark_mode",
]

## Spec sections 13.1-13.7: hospital.faint becomes one day-scoped entry per day.
const HOSPITAL_FAINT_ENTRIES := [
	"hospital.faint.day1",
	"hospital.faint.day2",
	"hospital.faint.day3",
	"hospital.faint.day4",
	"hospital.faint.day5",
	"hospital.faint.day6",
	"hospital.faint.day7",
]

## Read out of RETIRING_COMMIT's parent tree with git, never typed from memory.
const RETIRED_LABEL_IDS := [
	"ending.lavinia.true",
	"ending.priscilla.true",
	"ending.sylvia.true",
]

const TRANSFORMATION_IDS := [
	"contacts_split_into_ordinary_offer_followup",
	"hospital_faint_split_by_day",
	"endings_split_into_presentation_entries",
	"retired_ending_true_labels_rejected",
	"group_twofriends_retained_under_day_master",
]

const RECORD_KEYS := [
	"checkpoint_discriminator_required", "disposition", "labels", "path", "sha256",
	"source_blob_id", "timeline_id", "uid_path", "uid_sha256", "uid_source_blob_id",
]

const TRANSFORMATION_KEYS := [
	"kind", "label_roles", "note", "source_paths", "spec_sections", "target_entry_ids",
	"transformation_id",
]

const RETIRED_LABEL_KEYS := [
	"alias_to_observer", "disposition", "label_id", "reject_on_restore", "retired_by_commit",
]

## Columns: path, timeline_id, disposition, labels in file order.
const FROZEN_INVENTORY := [
	["res://dialogic/timelines/en/contacts/lavinia_day1.dtl", "contact.lavinia.day1", "split", ["history", "daily_message"]],
	["res://dialogic/timelines/en/contacts/lavinia_day2.dtl", "contact.lavinia.day2", "split", ["daily_message", "offer", "first_open_priscilla", "first_open_lavinia", "second_open_priscilla", "second_open_lavinia"]],
	["res://dialogic/timelines/en/contacts/lavinia_day3.dtl", "contact.lavinia.day3", "split", ["daily_message", "offer", "nevermind", "missed_question"]],
	["res://dialogic/timelines/en/contacts/lavinia_day4.dtl", "contact.lavinia.day4", "split", ["daily_message", "nevermind", "missed_question"]],
	["res://dialogic/timelines/en/contacts/lavinia_day5.dtl", "contact.lavinia.day5", "split", ["daily_message", "offer"]],
	["res://dialogic/timelines/en/contacts/lavinia_day6.dtl", "contact.lavinia.day6", "split", ["daily_message", "offer", "nevermind", "missed_question", "first_open_priscilla", "first_open_lavinia", "second_open_priscilla", "second_open_lavinia"]],
	["res://dialogic/timelines/en/contacts/lavinia_day7.dtl", "contact.lavinia.day7", "split", ["daily_message", "offer", "nevermind", "missed_question"]],
	["res://dialogic/timelines/en/contacts/priscilla_day1.dtl", "contact.priscilla.day1", "split", ["history", "daily_message", "offer"]],
	["res://dialogic/timelines/en/contacts/priscilla_day2.dtl", "contact.priscilla.day2", "split", ["daily_message", "offer", "nevermind", "missed_question", "first_open_priscilla", "first_open_lavinia", "second_open_priscilla", "second_open_lavinia"]],
	["res://dialogic/timelines/en/contacts/priscilla_day3.dtl", "contact.priscilla.day3", "split", ["daily_message", "nevermind", "missed_question"]],
	["res://dialogic/timelines/en/contacts/priscilla_day4.dtl", "contact.priscilla.day4", "split", ["daily_message", "offer"]],
	["res://dialogic/timelines/en/contacts/priscilla_day5.dtl", "contact.priscilla.day5", "split", ["daily_message", "nevermind", "missed_question"]],
	["res://dialogic/timelines/en/contacts/priscilla_day6.dtl", "contact.priscilla.day6", "split", ["daily_message", "offer", "first_open_priscilla", "first_open_lavinia", "second_open_priscilla", "second_open_lavinia"]],
	["res://dialogic/timelines/en/contacts/priscilla_day7.dtl", "contact.priscilla.day7", "split", ["daily_message", "offer", "nevermind", "missed_question"]],
	["res://dialogic/timelines/en/contacts/sylvia_day1.dtl", "contact.sylvia.day1", "split", ["history", "daily_message", "offer"]],
	["res://dialogic/timelines/en/contacts/sylvia_day2.dtl", "contact.sylvia.day2", "split", ["daily_message", "nevermind", "missed_question"]],
	["res://dialogic/timelines/en/contacts/sylvia_day3.dtl", "contact.sylvia.day3", "split", ["daily_message", "offer"]],
	["res://dialogic/timelines/en/contacts/sylvia_day4.dtl", "contact.sylvia.day4", "split", ["daily_message", "offer", "nevermind", "missed_question"]],
	["res://dialogic/timelines/en/contacts/sylvia_day5.dtl", "contact.sylvia.day5", "split", ["daily_message", "offer", "nevermind", "missed_question"]],
	["res://dialogic/timelines/en/contacts/sylvia_day6.dtl", "contact.sylvia.day6", "split", ["daily_message", "nevermind", "missed_question"]],
	["res://dialogic/timelines/en/contacts/sylvia_day7.dtl", "contact.sylvia.day7", "split", ["daily_message"]],
	["res://dialogic/timelines/en/core/hospital_faint.dtl", "hospital.faint", "split", []],
	["res://dialogic/timelines/en/core/opening_day1.dtl", "opening.day1", "retained", []],
	["res://dialogic/timelines/en/core/tutorial_desktop_day1.dtl", "tutorial.desktop_day1", "retained", []],
	["res://dialogic/timelines/en/dating/group/priscilla_lavinia_day2_post_challenge.dtl", "dating.group.priscilla_lavinia.day2.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/group/priscilla_lavinia_day2_pre_challenge.dtl", "dating.group.priscilla_lavinia.day2.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/group/priscilla_lavinia_day6_post_challenge.dtl", "dating.group.priscilla_lavinia.day6.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/group/priscilla_lavinia_day6_pre_challenge.dtl", "dating.group.priscilla_lavinia.day6.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/lavinia_day2_post_challenge.dtl", "dating.solo.lavinia.day2.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/lavinia_day2_pre_challenge.dtl", "dating.solo.lavinia.day2.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/lavinia_day3_post_challenge.dtl", "dating.solo.lavinia.day3.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/lavinia_day3_pre_challenge.dtl", "dating.solo.lavinia.day3.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/lavinia_day5_post_challenge.dtl", "dating.solo.lavinia.day5.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/lavinia_day5_pre_challenge.dtl", "dating.solo.lavinia.day5.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/lavinia_day6_post_challenge.dtl", "dating.solo.lavinia.day6.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/lavinia_day6_pre_challenge.dtl", "dating.solo.lavinia.day6.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/priscilla_day1_post_challenge.dtl", "dating.solo.priscilla.day1.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/priscilla_day1_pre_challenge.dtl", "dating.solo.priscilla.day1.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/priscilla_day2_post_challenge.dtl", "dating.solo.priscilla.day2.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/priscilla_day2_pre_challenge.dtl", "dating.solo.priscilla.day2.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/priscilla_day4_post_challenge.dtl", "dating.solo.priscilla.day4.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/priscilla_day4_pre_challenge.dtl", "dating.solo.priscilla.day4.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/priscilla_day6_post_challenge.dtl", "dating.solo.priscilla.day6.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/priscilla_day6_pre_challenge.dtl", "dating.solo.priscilla.day6.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/sylvia_day1_post_challenge.dtl", "dating.solo.sylvia.day1.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/sylvia_day1_pre_challenge.dtl", "dating.solo.sylvia.day1.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/sylvia_day3_post_challenge.dtl", "dating.solo.sylvia.day3.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/sylvia_day3_pre_challenge.dtl", "dating.solo.sylvia.day3.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/sylvia_day4_post_challenge.dtl", "dating.solo.sylvia.day4.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/sylvia_day4_pre_challenge.dtl", "dating.solo.sylvia.day4.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/sylvia_day5_post_challenge.dtl", "dating.solo.sylvia.day5.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/solo/sylvia_day5_pre_challenge.dtl", "dating.solo.sylvia.day5.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/twofriends/priscilla_lavinia_day2_post_challenge.dtl", "dating.twofriends.priscilla_lavinia.day2.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/twofriends/priscilla_lavinia_day2_pre_challenge.dtl", "dating.twofriends.priscilla_lavinia.day2.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/twofriends/priscilla_lavinia_day6_post_challenge.dtl", "dating.twofriends.priscilla_lavinia.day6.post_challenge", "retained", []],
	["res://dialogic/timelines/en/dating/twofriends/priscilla_lavinia_day6_pre_challenge.dtl", "dating.twofriends.priscilla_lavinia.day6.pre_challenge", "retained", []],
	["res://dialogic/timelines/en/ending/alone.dtl", "ending.alone", "split", ["ending.alone"]],
	["res://dialogic/timelines/en/ending/lavinia.dtl", "ending.lavinia", "split", ["ending.lavinia.sweet", "ending.lavinia.dark", "ending.lavinia.observation"]],
	["res://dialogic/timelines/en/ending/priscilla.dtl", "ending.priscilla", "split", ["ending.priscilla.sweet", "ending.priscilla.dark", "ending.priscilla.observation"]],
	["res://dialogic/timelines/en/ending/priscilla_lavinia.dtl", "ending.priscilla_lavinia", "split", ["ending.priscilla_lavinia"]],
	["res://dialogic/timelines/en/ending/sylvia.dtl", "ending.sylvia", "split", ["ending.sylvia.sweet", "ending.sylvia.dark", "ending.sylvia.special"]],
]


func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	if not parsed.get("ok", false):
		return {}
	return parsed["value"]


func _load_migration_manifest() -> Dictionary:
	return _parse(MANIFEST_PATH)


func _legacy_files() -> Array:
	var files: Variant = _load_migration_manifest().get("legacy_files", [])
	return files if files is Array else []


func _hex_digest(bytes: PackedByteArray, kind: int) -> String:
	var context := HashingContext.new()
	context.start(kind)
	context.update(bytes)
	return context.finish().hex_encode()


## A Git blob id is SHA-1 over the literal header "blob <length>\0" then the content.
func _git_blob_id(bytes: PackedByteArray) -> String:
	var framed := ("blob %d" % bytes.size()).to_utf8_buffer()
	framed.append(0)
	framed.append_array(bytes)
	return _hex_digest(framed, HashingContext.HASH_SHA1)


## Independent second derivation: parse the .dtl off disk rather than trusting the manifest.
func _labels_on_disk(path: String) -> Array:
	var labels: Array = []
	if not FileAccess.file_exists(path):
		return labels
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("label "):
			labels.append(line.substr(6).strip_edges())
	return labels


func _timeline_id_on_disk(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("# timeline_id: "):
			return line.substr(15).strip_edges()
	return ""


func _walk(directory: String, found: Array) -> void:
	var handle := DirAccess.open(directory)
	if handle == null:
		return
	handle.list_dir_begin()
	var entry := handle.get_next()
	while entry != "":
		var child := directory.path_join(entry)
		if handle.current_is_dir():
			_walk(child, found)
		else:
			found.append(child)
		entry = handle.get_next()
	handle.list_dir_end()


func _is_hex(text: String, length: int) -> bool:
	if text.length() != length:
		return false
	for index in range(text.length()):
		if not "0123456789abcdef".contains(text[index]):
			return false
	return true


func _transformation(transformation_id: String) -> Dictionary:
	var transformations: Variant = _load_migration_manifest().get("transformations", [])
	if not (transformations is Array):
		return {}
	for entry: Variant in transformations:
		if entry is Dictionary:
			var record: Dictionary = entry
			if str(record.get("transformation_id", "")) == transformation_id:
				return record
	return {}


# --------------------------------------------------------------------------------------------
# The plan's own assertion, kept intact.
# --------------------------------------------------------------------------------------------

func test_every_legacy_timeline_has_one_checked_disposition() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(), "expected RED: %s absent or unparseable" % MANIFEST_PATH)
	if manifest.is_empty():
		return
	var legacy_files: Array = manifest.get("legacy_files", [])
	assert_eq(legacy_files.size(), EXPECTED_LEGACY_FILE_COUNT,
		"the frozen inventory holds exactly %d legacy files" % EXPECTED_LEGACY_FILE_COUNT)
	for record: Dictionary in legacy_files:
		var path: String = str(record.get("path", ""))
		assert_has(ALLOWED_DISPOSITIONS, record.get("disposition"),
			"%s: disposition is a legal member" % path)
		assert_false(str(record.get("source_blob_id", "")).is_empty(),
			"%s: source_blob_id is recorded" % path)
		if str(manifest.get("cutover_status", "")) == "legacy_present":
			assert_true(FileAccess.file_exists(path), "%s: legacy file is still present" % path)
			assert_eq(FileAccess.get_sha256(path), str(record.get("sha256", "")),
				"%s: on-disk SHA-256 equals the recorded digest" % path)
		else:
			# Unreachable while the Global Constraint pins the 61 legacy files in place through
			# Plan 05. Kept deliberately: Plan 06 flips cutover_status and arms this branch.
			assert_false(FileAccess.file_exists(path), "%s: legacy file is retired" % path)


# --------------------------------------------------------------------------------------------
# Manifest shape and provenance.
# --------------------------------------------------------------------------------------------

func test_the_manifest_file_exists_and_parses_as_strict_json() -> void:
	assert_true(FileAccess.file_exists(MANIFEST_PATH), "expected RED: missing " + MANIFEST_PATH)
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(parsed.get("ok", false), "the manifest must parse under StrictJson")


func test_the_manifest_top_level_is_exact_key_and_names_its_true_source() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(), "expected RED: manifest absent or unparseable")
	if manifest.is_empty():
		return
	var keys: Array = manifest.keys()
	keys.sort()
	assert_eq(keys, [
		"ambiguous_checkpoint_disposition", "cutover_status", "kind", "legacy_files",
		"legacy_label_count", "master_timelines", "retired_labels", "schema_version",
		"source_branch", "source_commit", "tracked_target_count", "transformations",
	], "the top level is exact-key")
	assert_eq(manifest.get("schema_version"), 1, "schema_version is exactly 1")
	assert_eq(typeof(manifest.get("schema_version")), TYPE_INT, "schema_version is an int")
	assert_eq(manifest.get("kind"), "dialogic_migration", "kind is dialogic_migration")
	assert_eq(manifest.get("source_commit"), SOURCE_COMMIT,
		"the manifest records the tree it was actually built from")
	assert_eq(manifest.get("source_branch"), "codex/dwm-p2r13-resealed", "source branch")
	assert_eq(manifest.get("cutover_status"), "legacy_present",
		"the legacy files are retained until Plan 06")
	assert_eq(manifest.get("tracked_target_count"), EXPECTED_TRACKED_TARGET_COUNT,
		"61 DTL plus 61 adjacent UID files were verified byte-equal to their source blobs")
	assert_eq(typeof(manifest.get("tracked_target_count")), TYPE_INT,
		"tracked_target_count is an int")
	assert_eq(manifest.get("legacy_label_count"), EXPECTED_LABEL_COUNT,
		"the measured label total at SOURCE_COMMIT")
	assert_eq(typeof(manifest.get("legacy_label_count")), TYPE_INT,
		"legacy_label_count is an int")
	assert_eq(manifest.get("ambiguous_checkpoint_disposition"), "incompatible",
		"an ambiguous saved checkpoint is never mapped to a guessed label")


func test_the_eight_masters_are_declared_exactly() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(), "expected RED: manifest absent or unparseable")
	if manifest.is_empty():
		return
	assert_eq(manifest.get("master_timelines"), MASTER_TIMELINES,
		"spec 12.1 names exactly eight physical masters, in order")


# --------------------------------------------------------------------------------------------
# The 61 legacy records, field by field, against a second on-disk derivation.
# --------------------------------------------------------------------------------------------

func test_the_inventory_holds_exactly_the_frozen_sixty_one_records() -> void:
	var legacy_files := _legacy_files()
	assert_eq(legacy_files.size(), FROZEN_INVENTORY.size(),
		"expected RED: the frozen inventory has exactly %d records" % FROZEN_INVENTORY.size())
	if legacy_files.size() != FROZEN_INVENTORY.size():
		return
	for index in range(FROZEN_INVENTORY.size()):
		var expected: Array = FROZEN_INVENTORY[index]
		var record: Dictionary = legacy_files[index]
		var path: String = str(expected[0])
		var keys: Array = record.keys()
		keys.sort()
		assert_eq(keys, RECORD_KEYS, "%s: exact record keys" % path)
		assert_eq(record.get("path"), expected[0], "record %d: path" % index)
		assert_eq(record.get("timeline_id"), expected[1], "%s: timeline_id" % path)
		assert_eq(record.get("disposition"), expected[2], "%s: disposition" % path)
		assert_eq(record.get("labels"), expected[3], "%s: labels, in file order" % path)
		assert_eq(record.get("uid_path"), expected[0] + ".uid", "%s: adjacent UID path" % path)
		assert_eq(record.get("checkpoint_discriminator_required"), expected[2] == "split",
			"%s: a split source cannot resolve an undiscriminated checkpoint" % path)


func test_records_are_ordered_by_path_and_unique() -> void:
	var legacy_files := _legacy_files()
	assert_false(legacy_files.is_empty(), "expected RED: no records to order")
	if legacy_files.is_empty():
		return
	var paths: Array = []
	for record: Dictionary in legacy_files:
		paths.append(str(record.get("path", "")))
	var sorted_paths: Array = paths.duplicate()
	sorted_paths.sort()
	assert_eq(paths, sorted_paths, "records are stored in lexicographic path order")
	var seen: Array = []
	for path: Variant in paths:
		assert_false(seen.has(path), "%s: path appears exactly once" % str(path))
		seen.append(path)


func test_every_recorded_digest_matches_the_bytes_on_disk() -> void:
	var legacy_files := _legacy_files()
	assert_eq(legacy_files.size(), EXPECTED_LEGACY_FILE_COUNT, "expected RED: no records to hash")
	if legacy_files.size() != EXPECTED_LEGACY_FILE_COUNT:
		return
	for record: Dictionary in legacy_files:
		var path: String = str(record.get("path", ""))
		var uid_path: String = str(record.get("uid_path", ""))
		assert_true(FileAccess.file_exists(path), "%s: present" % path)
		assert_true(FileAccess.file_exists(uid_path), "%s: present" % uid_path)
		if not (FileAccess.file_exists(path) and FileAccess.file_exists(uid_path)):
			continue
		var bytes := FileAccess.get_file_as_bytes(path)
		var uid_bytes := FileAccess.get_file_as_bytes(uid_path)
		assert_eq(_hex_digest(bytes, HashingContext.HASH_SHA256), str(record.get("sha256", "")),
			"%s: recomputed SHA-256 equals the recorded digest" % path)
		assert_eq(_git_blob_id(bytes), str(record.get("source_blob_id", "")),
			"%s: recomputed Git blob id equals the recorded blob id" % path)
		assert_eq(_hex_digest(uid_bytes, HashingContext.HASH_SHA256),
			str(record.get("uid_sha256", "")),
			"%s: recomputed SHA-256 equals the recorded digest" % uid_path)
		assert_eq(_git_blob_id(uid_bytes), str(record.get("uid_source_blob_id", "")),
			"%s: recomputed Git blob id equals the recorded blob id" % uid_path)


func test_blob_ids_and_digests_are_well_formed_hex() -> void:
	var legacy_files := _legacy_files()
	assert_false(legacy_files.is_empty(), "expected RED: no records to inspect")
	if legacy_files.is_empty():
		return
	for record: Dictionary in legacy_files:
		var path: String = str(record.get("path", ""))
		assert_true(_is_hex(str(record.get("source_blob_id", "")), 40),
			"%s: a Git blob id is 40 lowercase hex digits" % path)
		assert_true(_is_hex(str(record.get("uid_source_blob_id", "")), 40),
			"%s: a Git blob id is 40 lowercase hex digits" % (path + ".uid"))
		assert_true(_is_hex(str(record.get("sha256", "")), 64),
			"%s: a SHA-256 digest is 64 lowercase hex digits" % path)
		assert_true(_is_hex(str(record.get("uid_sha256", "")), 64),
			"%s: a SHA-256 digest is 64 lowercase hex digits" % (path + ".uid"))


func test_every_label_and_placeholder_block_is_accounted_for() -> void:
	var legacy_files := _legacy_files()
	assert_eq(legacy_files.size(), EXPECTED_LEGACY_FILE_COUNT, "expected RED: no records to read")
	if legacy_files.size() != EXPECTED_LEGACY_FILE_COUNT:
		return
	var total := 0
	for record: Dictionary in legacy_files:
		var path: String = str(record.get("path", ""))
		var recorded: Array = record.get("labels", [])
		assert_eq(recorded, _labels_on_disk(path),
			"%s: recorded labels equal the labels parsed off disk" % path)
		assert_eq(str(record.get("timeline_id", "")), _timeline_id_on_disk(path),
			"%s: recorded timeline_id equals the placeholder-comment block on disk" % path)
		assert_false(str(record.get("timeline_id", "")).is_empty(),
			"%s: every legacy source declares a timeline_id" % path)
		total += recorded.size()
	assert_eq(total, EXPECTED_LABEL_COUNT, "every legacy label at SOURCE_COMMIT is accounted for")


func test_no_retired_ending_label_survives_in_the_tree_inventory() -> void:
	var legacy_files := _legacy_files()
	assert_false(legacy_files.is_empty(), "expected RED: no records to inspect")
	if legacy_files.is_empty():
		return
	for record: Dictionary in legacy_files:
		for label: Variant in record.get("labels", []):
			assert_false(RETIRED_LABEL_IDS.has(label),
				"%s: legacy_files is pure tree truth and holds no retired label" %
				str(record.get("path", "")))


func test_the_legacy_tree_on_disk_is_exactly_sixty_one_pairs() -> void:
	var found: Array = []
	_walk(LEGACY_ROOT, found)
	var dtl: Array = []
	var uid: Array = []
	for entry: Variant in found:
		var path: String = str(entry)
		if path.ends_with(".dtl"):
			dtl.append(path)
		elif path.ends_with(".dtl.uid"):
			uid.append(path)
	assert_eq(dtl.size(), EXPECTED_LEGACY_FILE_COUNT, "the tree still holds 61 legacy .dtl files")
	assert_eq(uid.size(), EXPECTED_UID_COUNT, "the tree still holds 61 adjacent .dtl.uid files")
	for path: Variant in dtl:
		assert_true(uid.has(str(path) + ".uid"), "%s: has an adjacent UID file" % str(path))


func test_dispositions_split_twenty_seven_and_retain_thirty_four() -> void:
	var legacy_files := _legacy_files()
	assert_eq(legacy_files.size(), EXPECTED_LEGACY_FILE_COUNT, "expected RED: no records to count")
	if legacy_files.size() != EXPECTED_LEGACY_FILE_COUNT:
		return
	var split := 0
	var retained := 0
	var retired := 0
	for record: Dictionary in legacy_files:
		match str(record.get("disposition", "")):
			"split":
				split += 1
			"retained":
				retained += 1
			"retired":
				retired += 1
	assert_eq(split, EXPECTED_SPLIT_COUNT, "21 contact plus hospital.faint plus 5 ending sources")
	assert_eq(retained, EXPECTED_RETAINED_COUNT,
		"the remaining sources keep a 1:1 semantic identity")
	assert_eq(retired, 0, "no legacy file is retired in this phase; only three labels were")


# --------------------------------------------------------------------------------------------
# Retired labels: recorded, rejected, and never aliased to Observer.
# --------------------------------------------------------------------------------------------

func test_the_three_retired_ending_labels_are_rejected_not_aliased() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(), "expected RED: manifest absent or unparseable")
	if manifest.is_empty():
		return
	var retired: Array = manifest.get("retired_labels", [])
	assert_eq(retired.size(), RETIRED_LABEL_IDS.size(),
		"exactly three ending.*.true labels were retired")
	if retired.size() != RETIRED_LABEL_IDS.size():
		return
	var ids: Array = []
	for record: Dictionary in retired:
		var keys: Array = record.keys()
		keys.sort()
		assert_eq(keys, RETIRED_LABEL_KEYS, "exact retired-label record keys")
		ids.append(str(record.get("label_id", "")))
		assert_eq(record.get("disposition"), "retired",
			"a retired label carries the retired disposition")
		assert_eq(record.get("retired_by_commit"), RETIRING_COMMIT,
			"each retired label names the commit that retired it")
		assert_true(bool(record.get("reject_on_restore")),
			"a restore that names a retired label must be rejected")
		assert_false(bool(record.get("alias_to_observer")),
			"a retired label is never aliased to an Observer entry")
	assert_eq(ids, RETIRED_LABEL_IDS, "the exact retired label ids, in order")


# --------------------------------------------------------------------------------------------
# The five ordered transformations.
# --------------------------------------------------------------------------------------------

func test_exactly_the_five_named_transformations_are_declared() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(), "expected RED: manifest absent or unparseable")
	if manifest.is_empty():
		return
	var transformations: Array = manifest.get("transformations", [])
	assert_eq(transformations.size(), TRANSFORMATION_IDS.size(),
		"the task names exactly five transformations")
	if transformations.size() != TRANSFORMATION_IDS.size():
		return
	var ids: Array = []
	for record: Dictionary in transformations:
		var keys: Array = record.keys()
		keys.sort()
		assert_eq(keys, TRANSFORMATION_KEYS, "exact transformation record keys")
		assert_has(ALLOWED_DISPOSITIONS, record.get("kind"), "kind is a legal disposition member")
		assert_false(str(record.get("note", "")).is_empty(),
			"every transformation states its intent")
		var sections: Array = record.get("spec_sections", [])
		assert_false(sections.is_empty(),
			"every transformation cites the spec sections that authorise it")
		ids.append(str(record.get("transformation_id", "")))
	assert_eq(ids, TRANSFORMATION_IDS, "the exact transformation ids, in order")


func test_contact_sources_split_into_ordinary_offer_and_followup_roles() -> void:
	var transformation := _transformation("contacts_split_into_ordinary_offer_followup")
	assert_false(transformation.is_empty(), "expected RED: the contact transformation is absent")
	if transformation.is_empty():
		return
	assert_eq(transformation.get("kind"), "split", "generic contact files are split")
	var sources: Array = transformation.get("source_paths", [])
	assert_eq(sources.size(), 21, "every contact source is listed")
	for path: Variant in sources:
		assert_true(str(path).begins_with("res://dialogic/timelines/en/contacts/"),
			"%s: is a contact source" % str(path))
	var roles: Dictionary = {}
	for entry: Dictionary in transformation.get("label_roles", []):
		roles[str(entry.get("label", ""))] = str(entry.get("entry_role", ""))
	assert_eq(roles.get("daily_message"), "contact.ordinary", "ordinary entry role")
	assert_eq(roles.get("offer"), "contact.invitation.solo.offer", "offer entry role")
	assert_eq(roles.get("nevermind"), "contact.invitation.solo.nevermind", "follow-up entry role")
	assert_eq(roles.get("missed_question"), "contact.invitation.solo.missed_question",
		"follow-up entry role")
	assert_eq(roles.get("first_open_priscilla"),
		"contact.invitation.group.first_open_priscilla", "group invitation part")
	assert_eq(roles.get("first_open_lavinia"),
		"contact.invitation.group.first_open_lavinia", "group invitation part")
	assert_eq(roles.get("second_open_priscilla"),
		"contact.invitation.group.second_open_priscilla", "group invitation part")
	assert_eq(roles.get("second_open_lavinia"),
		"contact.invitation.group.second_open_lavinia", "group invitation part")
	assert_eq(roles.get("history"), "unmapped",
		"spec 13.1-13.7 enumerates no history entry; it is recorded, never guessed")
	var every_contact_label: Array = []
	for record: Dictionary in _legacy_files():
		if str(record.get("path", "")).begins_with("res://dialogic/timelines/en/contacts/"):
			for label: Variant in record.get("labels", []):
				if not every_contact_label.has(label):
					every_contact_label.append(label)
	for label: Variant in every_contact_label:
		assert_true(roles.has(label), "%s: every contact label has a declared role" % str(label))


func test_hospital_faint_splits_into_day_one_through_day_seven() -> void:
	var transformation := _transformation("hospital_faint_split_by_day")
	assert_false(transformation.is_empty(), "expected RED: the hospital transformation is absent")
	if transformation.is_empty():
		return
	assert_eq(transformation.get("kind"), "split", "hospital.faint is split")
	assert_eq(transformation.get("source_paths"),
		["res://dialogic/timelines/en/core/hospital_faint.dtl"], "exactly one source")
	assert_eq(transformation.get("target_entry_ids"), HOSPITAL_FAINT_ENTRIES,
		"hospital.faint.day1 through hospital.faint.day7")


func test_five_ending_sources_split_into_the_eighteen_presentation_entries() -> void:
	var transformation := _transformation("endings_split_into_presentation_entries")
	assert_false(transformation.is_empty(), "expected RED: the ending transformation is absent")
	if transformation.is_empty():
		return
	assert_eq(transformation.get("kind"), "split", "the five old ending files are split")
	var sources: Array = transformation.get("source_paths", [])
	assert_eq(sources.size(), 5, "five old ending files")
	for path: Variant in sources:
		assert_true(str(path).begins_with("res://dialogic/timelines/en/ending/"),
			"%s: is an ending source" % str(path))
	var targets: Array = transformation.get("target_entry_ids", [])
	assert_eq(targets.size(), 18, "spec 13.8 approves exactly eighteen presentation entries")
	assert_eq(targets, ENDING_PRESENTATION_ENTRIES, "the exact approved presentation entries")
	for target: Variant in targets:
		assert_false(RETIRED_LABEL_IDS.has(target),
			"%s: no retired label is resurrected as a presentation entry" % str(target))


func test_group_and_twofriends_day_two_and_six_files_are_retained() -> void:
	var transformation := _transformation("group_twofriends_retained_under_day_master")
	assert_false(transformation.is_empty(), "expected RED: the retention transformation is absent")
	if transformation.is_empty():
		return
	assert_eq(transformation.get("kind"), "retained", "these files keep their semantic identity")
	var sources: Array = transformation.get("source_paths", [])
	assert_eq(sources.size(), 8, "four group plus four twofriends sources")
	var targets: Array = transformation.get("target_entry_ids", [])
	assert_eq(targets.size(), 8, "one semantic entry per retained source")
	if sources.size() != 8 or targets.size() != 8:
		return
	var by_path: Dictionary = {}
	for record: Dictionary in _legacy_files():
		by_path[str(record.get("path", ""))] = record
	for index in range(sources.size()):
		var path: String = str(sources[index])
		assert_true(path.contains("/dating/group/") or path.contains("/dating/twofriends/"),
			"%s: is a group or twofriends source" % path)
		assert_true(path.contains("day2") or path.contains("day6"),
			"%s: is a Day 2 or Day 6 source" % path)
		var record: Dictionary = by_path.get(path, {})
		assert_eq(record.get("disposition"), "retained", "%s: recorded as retained" % path)
		assert_eq(str(targets[index]), str(record.get("timeline_id", "")),
			"%s: retained under its own semantic entry id" % path)


func test_the_retired_label_transformation_points_at_the_retired_block() -> void:
	var transformation := _transformation("retired_ending_true_labels_rejected")
	assert_false(transformation.is_empty(), "expected RED: the retirement transformation is absent")
	if transformation.is_empty():
		return
	assert_eq(transformation.get("kind"), "retired",
		"the labels are retired, neither split nor retained")
	assert_eq(transformation.get("target_entry_ids"), [],
		"a retired label resolves to no entry at all")
	var roles: Array = transformation.get("label_roles", [])
	assert_eq(roles.size(), RETIRED_LABEL_IDS.size(), "one role row per retired label")
	if roles.size() != RETIRED_LABEL_IDS.size():
		return
	var ids: Array = []
	for entry: Dictionary in roles:
		ids.append(str(entry.get("label", "")))
		assert_eq(entry.get("entry_role"), "rejected",
			"a retired label is rejected, never aliased to Observer")
	assert_eq(ids, RETIRED_LABEL_IDS, "the exact retired label ids")


func test_every_split_source_belongs_to_exactly_one_split_transformation() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(), "expected RED: manifest absent or unparseable")
	if manifest.is_empty():
		return
	var known: Array = []
	var split_sources: Array = []
	for record: Dictionary in _legacy_files():
		known.append(str(record.get("path", "")))
		if str(record.get("disposition", "")) == "split":
			split_sources.append(str(record.get("path", "")))
	var claimed: Array = []
	for transformation: Dictionary in manifest.get("transformations", []):
		for path: Variant in transformation.get("source_paths", []):
			assert_true(known.has(str(path)),
				"%s: every transformation source is an inventoried legacy file" % str(path))
			if str(transformation.get("kind", "")) != "split":
				continue
			assert_false(claimed.has(str(path)),
				"%s: claimed by exactly one split transformation" % str(path))
			claimed.append(str(path))
	claimed.sort()
	split_sources.sort()
	assert_eq(claimed, split_sources,
		"the split transformations cover exactly the split-disposition sources")


# --------------------------------------------------------------------------------------------
# Published schema.
# --------------------------------------------------------------------------------------------

func test_the_published_schema_accepts_the_manifest() -> void:
	assert_true(FileAccess.file_exists(SCHEMA_PATH), "expected RED: missing " + SCHEMA_PATH)
	var schema := _parse(SCHEMA_PATH)
	var manifest := _load_migration_manifest()
	if schema.is_empty() or manifest.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		assert_false(manifest.is_empty(), "expected RED: manifest absent or unparseable")
		return
	var result: Dictionary = JsonSchemaValidator.validate(manifest, schema)
	assert_true(result.get("ok", false),
		"the published schema accepts the frozen manifest: " + str(result.get("message", "")))


func test_the_schema_closes_every_object_level() -> void:
	var schema := _parse(SCHEMA_PATH)
	assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
	if schema.is_empty():
		return
	assert_eq(schema.get("$schema"), "https://json-schema.org/draft/2020-12/schema",
		"draft 2020-12, as every other manifest schema in this repo")
	var open_objects: Array = []
	_collect_open_objects(schema, "$", open_objects)
	assert_eq(open_objects, [], "every object level sets additionalProperties false")


func _collect_open_objects(node: Variant, path: String, found: Array) -> void:
	if node is Array:
		var items: Array = node
		for index in range(items.size()):
			_collect_open_objects(items[index], "%s[%d]" % [path, index], found)
		return
	if not (node is Dictionary):
		return
	var object: Dictionary = node
	if str(object.get("type", "")) == "object" and object.get("additionalProperties", true) != false:
		found.append(path)
	for key: Variant in object:
		_collect_open_objects(object[key], "%s.%s" % [path, str(key)], found)


func test_the_schema_rejects_an_illegal_disposition() -> void:
	var schema := _parse(SCHEMA_PATH)
	var manifest := _load_migration_manifest()
	if schema.is_empty() or manifest.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		return
	var mutated: Dictionary = manifest.duplicate(true)
	var records: Array = mutated["legacy_files"]
	(records[0] as Dictionary)["disposition"] = "archived"
	var result: Dictionary = JsonSchemaValidator.validate(mutated, schema)
	assert_false(result.get("ok", true), "a disposition outside the closed vocabulary is rejected")


func test_the_schema_rejects_an_unknown_property() -> void:
	var schema := _parse(SCHEMA_PATH)
	var manifest := _load_migration_manifest()
	if schema.is_empty() or manifest.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		return
	var mutated: Dictionary = manifest.duplicate(true)
	var records: Array = mutated["legacy_files"]
	(records[0] as Dictionary)["unexpected"] = true
	var result: Dictionary = JsonSchemaValidator.validate(mutated, schema)
	assert_false(result.get("ok", true), "an unknown record property is rejected")
