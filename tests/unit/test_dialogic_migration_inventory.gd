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
## Legacy label to entry id: the contact and ending transformations carry per-(source_path, label)
## rows whose targets are exact entry ids transcribed from specification sections 13.1 through
## 13.8. The relation is many-to-one and one-to-many, so a single dotted role string cannot
## express it. Where the specification enumerates no entry the row is explicitly unmapped with a
## reason; no id is ever guessed, invented or aliased to a neighbour.
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

## Status tallies over every label-mapping row in the manifest. mapped plus unmapped is exactly
## the tree label total; a rejected row stands outside it because its label is not in the tree.
## The reconciliation invariant counts mapped and unmapped together, so without these two a row
## could flip status without moving any total.
const EXPECTED_MAPPED_ROW_COUNT := 70
const EXPECTED_UNMAPPED_ROW_COUNT := 19

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
	"disposition", "labels", "path", "sha256",
	"source_blob_id", "timeline_id", "uid_path", "uid_sha256", "uid_source_blob_id",
]

const TRANSFORMATION_KEYS := [
	"kind", "label_mappings", "note", "source_paths", "spec_sections", "target_entry_ids",
	"transformation_id",
]

const RETIRED_LABEL_KEYS := [
	"alias_to_observer", "disposition", "label_id", "reject_on_restore", "retired_by_commit",
]

const TIMELINE_MANIFEST_PATH := "res://data/manifests/timelines.json"
const CONTACTS_ROOT := "res://dialogic/timelines/en/contacts/"
const ENDING_ROOT := "res://dialogic/timelines/en/ending/"

const EXPECTED_MASTER_TIMELINE_COUNT := 8
const EXPECTED_RETIRED_LABEL_COUNT := 3
const EXPECTED_TRANSFORMATION_COUNT := 5

const ALLOWED_MAPPING_STATUSES := ["mapped", "unmapped", "rejected"]

const LABEL_MAPPING_KEYS := [
	"label", "reason", "source_path", "status", "target_entry_ids",
]

## A legacy label whose spelling diverges from the specification carries an explicit typed flag,
## so a consumer detects the rename programmatically instead of parsing the reason prose. The
## flag is present only where it is true, and a row that carries it always resolves.
const NON_CANONICAL_FLAG := "legacy_name_is_non_canonical"

const LABEL_MAPPING_KEYS_RENAMED := [
	"label", "legacy_name_is_non_canonical", "reason", "source_path", "status",
	"target_entry_ids",
]

## The bead that tracks correcting the legacy label spelling at physical cutover.
const RENAME_BEAD := "dwm-ihm"

## The exact (source_path, label) pairs whose legacy spelling is non-canonical, in manifest
## order. Nothing else in the manifest may carry the flag.
const NON_CANONICAL_RENAME_ROWS := [
	["res://dialogic/timelines/en/ending/lavinia.dtl", "ending.lavinia.observation"],
	["res://dialogic/timelines/en/ending/priscilla.dtl", "ending.priscilla.observation"],
]

## Columns: contact file basename under CONTACTS_ROOT, legacy label in file order, and the exact
## target entry ids transcribed from specification sections 13.1 through 13.7. Every id below was
## grep-confirmed to appear verbatim in the specification. An empty list means the specification
## enumerates no entry for that (file, label) pair, which the manifest records with a reason rather
## than guessing, inventing or aliasing an id. The relation is deliberately not one-to-one: sixteen
## group-open labels converge onto eight entries, fifteen daily_message labels reach no entry
## because specification 7.1 fixes exactly six ordinary replyable messages, and a follow-up label
## sits one day later than the invitation window it closes.
const CONTACT_LABEL_MAPPINGS := [
	["lavinia_day1.dtl", "history", []],
	["lavinia_day1.dtl", "daily_message", ["contact.ordinary.lavinia.day1"]],
	["lavinia_day2.dtl", "daily_message", []],
	["lavinia_day2.dtl", "offer", ["contact.invitation.solo.lavinia.day2.offer"]],
	["lavinia_day2.dtl", "first_open_priscilla", ["contact.invitation.group.priscilla_lavinia.day2.first_open_priscilla"]],
	["lavinia_day2.dtl", "first_open_lavinia", ["contact.invitation.group.priscilla_lavinia.day2.first_open_lavinia"]],
	["lavinia_day2.dtl", "second_open_priscilla", ["contact.invitation.group.priscilla_lavinia.day2.second_open_priscilla"]],
	["lavinia_day2.dtl", "second_open_lavinia", ["contact.invitation.group.priscilla_lavinia.day2.second_open_lavinia"]],
	["lavinia_day3.dtl", "daily_message", []],
	["lavinia_day3.dtl", "offer", ["contact.invitation.solo.lavinia.day3.offer"]],
	["lavinia_day3.dtl", "nevermind", ["contact.invitation.solo.lavinia.day2.nevermind"]],
	["lavinia_day3.dtl", "missed_question", ["contact.invitation.solo.lavinia.day2.missed_question"]],
	["lavinia_day4.dtl", "daily_message", ["contact.ordinary.lavinia.day4"]],
	["lavinia_day4.dtl", "nevermind", ["contact.invitation.solo.lavinia.day3.nevermind"]],
	["lavinia_day4.dtl", "missed_question", ["contact.invitation.solo.lavinia.day3.missed_question"]],
	["lavinia_day5.dtl", "daily_message", []],
	["lavinia_day5.dtl", "offer", ["contact.invitation.solo.lavinia.day5.offer"]],
	["lavinia_day6.dtl", "daily_message", []],
	["lavinia_day6.dtl", "offer", ["contact.invitation.solo.lavinia.day6.offer"]],
	["lavinia_day6.dtl", "nevermind", ["contact.invitation.solo.lavinia.day5.nevermind"]],
	["lavinia_day6.dtl", "missed_question", ["contact.invitation.solo.lavinia.day5.missed_question"]],
	["lavinia_day6.dtl", "first_open_priscilla", ["contact.invitation.group.priscilla_lavinia.day6.first_open_priscilla"]],
	["lavinia_day6.dtl", "first_open_lavinia", ["contact.invitation.group.priscilla_lavinia.day6.first_open_lavinia"]],
	["lavinia_day6.dtl", "second_open_priscilla", ["contact.invitation.group.priscilla_lavinia.day6.second_open_priscilla"]],
	["lavinia_day6.dtl", "second_open_lavinia", ["contact.invitation.group.priscilla_lavinia.day6.second_open_lavinia"]],
	["lavinia_day7.dtl", "daily_message", []],
	["lavinia_day7.dtl", "offer", ["contact.invitation.ending.lavinia.day7.offer"]],
	["lavinia_day7.dtl", "nevermind", ["contact.invitation.solo.lavinia.day6.nevermind"]],
	["lavinia_day7.dtl", "missed_question", ["contact.invitation.solo.lavinia.day6.missed_question"]],
	["priscilla_day1.dtl", "history", []],
	["priscilla_day1.dtl", "daily_message", []],
	["priscilla_day1.dtl", "offer", ["contact.invitation.solo.priscilla.day1.offer"]],
	["priscilla_day2.dtl", "daily_message", []],
	["priscilla_day2.dtl", "offer", ["contact.invitation.solo.priscilla.day2.offer"]],
	["priscilla_day2.dtl", "nevermind", ["contact.invitation.solo.priscilla.day1.nevermind"]],
	["priscilla_day2.dtl", "missed_question", ["contact.invitation.solo.priscilla.day1.missed_question"]],
	["priscilla_day2.dtl", "first_open_priscilla", ["contact.invitation.group.priscilla_lavinia.day2.first_open_priscilla"]],
	["priscilla_day2.dtl", "first_open_lavinia", ["contact.invitation.group.priscilla_lavinia.day2.first_open_lavinia"]],
	["priscilla_day2.dtl", "second_open_priscilla", ["contact.invitation.group.priscilla_lavinia.day2.second_open_priscilla"]],
	["priscilla_day2.dtl", "second_open_lavinia", ["contact.invitation.group.priscilla_lavinia.day2.second_open_lavinia"]],
	["priscilla_day3.dtl", "daily_message", ["contact.ordinary.priscilla.day3"]],
	["priscilla_day3.dtl", "nevermind", ["contact.invitation.solo.priscilla.day2.nevermind"]],
	["priscilla_day3.dtl", "missed_question", ["contact.invitation.solo.priscilla.day2.missed_question"]],
	["priscilla_day4.dtl", "daily_message", []],
	["priscilla_day4.dtl", "offer", ["contact.invitation.solo.priscilla.day4.offer"]],
	["priscilla_day5.dtl", "daily_message", ["contact.ordinary.priscilla.day5"]],
	["priscilla_day5.dtl", "nevermind", ["contact.invitation.solo.priscilla.day4.nevermind"]],
	["priscilla_day5.dtl", "missed_question", ["contact.invitation.solo.priscilla.day4.missed_question"]],
	["priscilla_day6.dtl", "daily_message", []],
	["priscilla_day6.dtl", "offer", ["contact.invitation.solo.priscilla.day6.offer"]],
	["priscilla_day6.dtl", "first_open_priscilla", ["contact.invitation.group.priscilla_lavinia.day6.first_open_priscilla"]],
	["priscilla_day6.dtl", "first_open_lavinia", ["contact.invitation.group.priscilla_lavinia.day6.first_open_lavinia"]],
	["priscilla_day6.dtl", "second_open_priscilla", ["contact.invitation.group.priscilla_lavinia.day6.second_open_priscilla"]],
	["priscilla_day6.dtl", "second_open_lavinia", ["contact.invitation.group.priscilla_lavinia.day6.second_open_lavinia"]],
	["priscilla_day7.dtl", "daily_message", []],
	["priscilla_day7.dtl", "offer", ["contact.invitation.ending.priscilla.day7.offer"]],
	["priscilla_day7.dtl", "nevermind", ["contact.invitation.solo.priscilla.day6.nevermind"]],
	["priscilla_day7.dtl", "missed_question", ["contact.invitation.solo.priscilla.day6.missed_question"]],
	["sylvia_day1.dtl", "history", []],
	["sylvia_day1.dtl", "daily_message", []],
	["sylvia_day1.dtl", "offer", ["contact.invitation.solo.sylvia.day1.offer"]],
	["sylvia_day2.dtl", "daily_message", ["contact.ordinary.sylvia.day2"]],
	["sylvia_day2.dtl", "nevermind", ["contact.invitation.solo.sylvia.day1.nevermind"]],
	["sylvia_day2.dtl", "missed_question", ["contact.invitation.solo.sylvia.day1.missed_question"]],
	["sylvia_day3.dtl", "daily_message", []],
	["sylvia_day3.dtl", "offer", ["contact.invitation.solo.sylvia.day3.offer"]],
	["sylvia_day4.dtl", "daily_message", []],
	["sylvia_day4.dtl", "offer", ["contact.invitation.solo.sylvia.day4.offer"]],
	["sylvia_day4.dtl", "nevermind", ["contact.invitation.solo.sylvia.day3.nevermind"]],
	["sylvia_day4.dtl", "missed_question", ["contact.invitation.solo.sylvia.day3.missed_question"]],
	["sylvia_day5.dtl", "daily_message", []],
	["sylvia_day5.dtl", "offer", ["contact.invitation.solo.sylvia.day5.offer"]],
	["sylvia_day5.dtl", "nevermind", ["contact.invitation.solo.sylvia.day4.nevermind"]],
	["sylvia_day5.dtl", "missed_question", ["contact.invitation.solo.sylvia.day4.missed_question"]],
	["sylvia_day6.dtl", "daily_message", ["contact.ordinary.sylvia.day6"]],
	["sylvia_day6.dtl", "nevermind", ["contact.invitation.solo.sylvia.day5.nevermind"]],
	["sylvia_day6.dtl", "missed_question", ["contact.invitation.solo.sylvia.day5.missed_question"]],
	["sylvia_day7.dtl", "daily_message", []],
]

## Columns: ending file basename under ENDING_ROOT, legacy label in file order, and the callable
## entry ids of its specification 13.8 row.
##
## RETIRING_COMMIT renamed the three retired ending.*.true labels in a single pass, but not
## consistently: sylvia took special, which is the specification word and resolves cleanly, while
## lavinia and priscilla took observation, which 13.8 never uses as an ending identity. Those two
## occupy the same structural slot as ending.sylvia.special, so they resolve to the observer rows
## of 13.8 and carry NON_CANONICAL_FLAG. The undifferentiated ending.priscilla_lavinia label
## names none of its three ending ids, so it reaches nothing and is not guessed at.
const ENDING_LABEL_MAPPINGS := [
	["alone.dtl", "ending.alone", ["ending.alone.normal", "ending.alone.dark_mode"]],
	["lavinia.dtl", "ending.lavinia.sweet", ["ending.lavinia.sweet"]],
	["lavinia.dtl", "ending.lavinia.dark", ["ending.lavinia.dark"]],
	["lavinia.dtl", "ending.lavinia.observation",
		["ending.lavinia.observer.full", "ending.lavinia.observer.residue"]],
	["priscilla.dtl", "ending.priscilla.sweet", ["ending.priscilla.sweet"]],
	["priscilla.dtl", "ending.priscilla.dark", ["ending.priscilla.dark"]],
	["priscilla.dtl", "ending.priscilla.observation",
		["ending.priscilla.observer.full", "ending.priscilla.observer.residue"]],
	["priscilla_lavinia.dtl", "ending.priscilla_lavinia", []],
	["sylvia.dtl", "ending.sylvia.sweet", ["ending.sylvia.sweet"]],
	["sylvia.dtl", "ending.sylvia.dark", ["ending.sylvia.dark"]],
	["sylvia.dtl", "ending.sylvia.special", ["ending.sylvia.special.full", "ending.sylvia.special.residue"]],
]

## Ten of the eleven ending rows resolve; only the undifferentiated pairing label does not.
const EXPECTED_ENDING_MAPPED_COUNT := 10
const EXPECTED_ENDING_UNMAPPED_COUNT := 1

## The distinct entry ids the contact labels actually reach. Specification sections 13.1 through
## 13.7 enumerate further contact entries that no legacy label produces; those belong to Task 2
## and are deliberately not claimed here.
const CONTACT_TARGET_ENTRY_IDS := [
	"contact.invitation.ending.lavinia.day7.offer",
	"contact.invitation.ending.priscilla.day7.offer",
	"contact.invitation.group.priscilla_lavinia.day2.first_open_lavinia",
	"contact.invitation.group.priscilla_lavinia.day2.first_open_priscilla",
	"contact.invitation.group.priscilla_lavinia.day2.second_open_lavinia",
	"contact.invitation.group.priscilla_lavinia.day2.second_open_priscilla",
	"contact.invitation.group.priscilla_lavinia.day6.first_open_lavinia",
	"contact.invitation.group.priscilla_lavinia.day6.first_open_priscilla",
	"contact.invitation.group.priscilla_lavinia.day6.second_open_lavinia",
	"contact.invitation.group.priscilla_lavinia.day6.second_open_priscilla",
	"contact.invitation.solo.lavinia.day2.missed_question",
	"contact.invitation.solo.lavinia.day2.nevermind",
	"contact.invitation.solo.lavinia.day2.offer",
	"contact.invitation.solo.lavinia.day3.missed_question",
	"contact.invitation.solo.lavinia.day3.nevermind",
	"contact.invitation.solo.lavinia.day3.offer",
	"contact.invitation.solo.lavinia.day5.missed_question",
	"contact.invitation.solo.lavinia.day5.nevermind",
	"contact.invitation.solo.lavinia.day5.offer",
	"contact.invitation.solo.lavinia.day6.missed_question",
	"contact.invitation.solo.lavinia.day6.nevermind",
	"contact.invitation.solo.lavinia.day6.offer",
	"contact.invitation.solo.priscilla.day1.missed_question",
	"contact.invitation.solo.priscilla.day1.nevermind",
	"contact.invitation.solo.priscilla.day1.offer",
	"contact.invitation.solo.priscilla.day2.missed_question",
	"contact.invitation.solo.priscilla.day2.nevermind",
	"contact.invitation.solo.priscilla.day2.offer",
	"contact.invitation.solo.priscilla.day4.missed_question",
	"contact.invitation.solo.priscilla.day4.nevermind",
	"contact.invitation.solo.priscilla.day4.offer",
	"contact.invitation.solo.priscilla.day6.missed_question",
	"contact.invitation.solo.priscilla.day6.nevermind",
	"contact.invitation.solo.priscilla.day6.offer",
	"contact.invitation.solo.sylvia.day1.missed_question",
	"contact.invitation.solo.sylvia.day1.nevermind",
	"contact.invitation.solo.sylvia.day1.offer",
	"contact.invitation.solo.sylvia.day3.missed_question",
	"contact.invitation.solo.sylvia.day3.nevermind",
	"contact.invitation.solo.sylvia.day3.offer",
	"contact.invitation.solo.sylvia.day4.missed_question",
	"contact.invitation.solo.sylvia.day4.nevermind",
	"contact.invitation.solo.sylvia.day4.offer",
	"contact.invitation.solo.sylvia.day5.missed_question",
	"contact.invitation.solo.sylvia.day5.nevermind",
	"contact.invitation.solo.sylvia.day5.offer",
	"contact.ordinary.lavinia.day1",
	"contact.ordinary.lavinia.day4",
	"contact.ordinary.priscilla.day3",
	"contact.ordinary.priscilla.day5",
	"contact.ordinary.sylvia.day2",
	"contact.ordinary.sylvia.day6",
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


## Minor 7: _parse() collapses missing and unparseable into {}. This reports which it was, and
## where, so a future JSON break names a code, line and column instead of a bare parse failure.
func _parse_diagnostic(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "%s: file does not exist" % path
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	if parsed.get("ok", false):
		return ""
	return "%s: StrictJson rejected the document, code %s at line %s column %s: %s" % [
		path, str(parsed.get("code", "")), str(parsed.get("line", "")),
		str(parsed.get("column", "")), str(parsed.get("message", "")),
	]


func _load_migration_manifest() -> Dictionary:
	return _parse(MANIFEST_PATH)


func _label_mapping_rows(transformation_id: String) -> Array:
	var rows: Variant = _transformation(transformation_id).get("label_mappings", [])
	return rows if rows is Array else []


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
	assert_true(parsed.get("ok", false),
		"the manifest must parse under StrictJson: " + _parse_diagnostic(MANIFEST_PATH))


func test_the_manifest_top_level_is_exact_key_and_names_its_true_source() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(), "expected RED: manifest absent or unparseable")
	if manifest.is_empty():
		return
	var keys: Array = manifest.keys()
	keys.sort()
	assert_eq(keys, [
		"ambiguous_checkpoint_disposition", "cutover_status", "kind", "legacy_file_count",
		"legacy_files", "legacy_label_count", "master_timeline_count", "master_timelines",
		"retired_label_count", "retired_labels", "schema_version", "source_branch",
		"source_commit", "tracked_target_count", "transformation_count", "transformations",
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
	assert_eq(found.size(), EXPECTED_TRACKED_TARGET_COUNT,
		"the tree under the legacy root holds exactly the %d tracked targets and nothing else" %
		EXPECTED_TRACKED_TARGET_COUNT)
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


func test_contact_labels_map_to_exact_spec_entry_ids() -> void:
	var transformation := _transformation("contacts_split_into_ordinary_offer_followup")
	assert_false(transformation.is_empty(), "expected RED: the contact transformation is absent")
	if transformation.is_empty():
		return
	assert_eq(transformation.get("kind"), "split", "generic contact files are split")
	var sources: Array = transformation.get("source_paths", [])
	assert_eq(sources.size(), 21, "every contact source is listed")
	for path: Variant in sources:
		assert_true(str(path).begins_with(CONTACTS_ROOT), "%s: is a contact source" % str(path))
	var rows: Array = transformation.get("label_mappings", [])
	assert_eq(rows.size(), CONTACT_LABEL_MAPPINGS.size(),
		"expected RED: one row per contact label occurrence, %d in all" % CONTACT_LABEL_MAPPINGS.size())
	if rows.size() != CONTACT_LABEL_MAPPINGS.size():
		return
	for index in range(CONTACT_LABEL_MAPPINGS.size()):
		var expected: Array = CONTACT_LABEL_MAPPINGS[index]
		var row: Dictionary = rows[index]
		var expected_targets: Array = expected[2]
		var where: String = "%s/%s" % [str(expected[0]), str(expected[1])]
		assert_eq(row.get("source_path"), CONTACTS_ROOT + str(expected[0]),
			"%s: mapping row %d source" % [where, index])
		assert_eq(row.get("label"), expected[1], "%s: mapping row %d label" % [where, index])
		assert_eq(row.get("target_entry_ids"), expected_targets,
			"%s: the exact specification 13.1-13.7 entry ids" % where)
		assert_eq(row.get("status"), "unmapped" if expected_targets.is_empty() else "mapped",
			"%s: status states in data whether the specification enumerates an entry" % where)
	assert_eq(transformation.get("target_entry_ids"), CONTACT_TARGET_ENTRY_IDS,
		"the contact transformation reaches exactly the entries its legacy labels name")


func test_the_day_seven_offer_gap_and_the_follow_up_day_shift_are_recorded() -> void:
	var rows := _label_mapping_rows("contacts_split_into_ordinary_offer_followup")
	assert_false(rows.is_empty(), "expected RED: the contact mapping is absent")
	if rows.is_empty():
		return
	var by_key: Dictionary = {}
	for row: Dictionary in rows:
		by_key["%s|%s" % [str(row.get("source_path", "")), str(row.get("label", ""))]] = row
	var shifted: Dictionary = by_key.get(CONTACTS_ROOT + "lavinia_day3.dtl|nevermind", {})
	assert_eq(shifted.get("target_entry_ids"), ["contact.invitation.solo.lavinia.day2.nevermind"],
		"a Day-3 file closes the Day-2 invitation window, so the locator shifts one day back")
	assert_eq(by_key.get(CONTACTS_ROOT + "priscilla_day7.dtl|offer", {}).get("target_entry_ids"),
		["contact.invitation.ending.priscilla.day7.offer"],
		"a Day-7 offer is an ending invitation, not a solo invitation window")
	assert_eq(by_key.get(CONTACTS_ROOT + "lavinia_day7.dtl|offer", {}).get("target_entry_ids"),
		["contact.invitation.ending.lavinia.day7.offer"],
		"a Day-7 offer is an ending invitation, not a solo invitation window")
	assert_false(by_key.has(CONTACTS_ROOT + "sylvia_day7.dtl|offer"),
		"sylvia_day7.dtl carries no offer label at all")
	var targets: Array = _transformation("contacts_split_into_ordinary_offer_followup").get(
		"target_entry_ids", [])
	assert_false(targets.has("contact.invitation.ending.sylvia.day7.offer"),
		"an entry with no legacy label behind it is never claimed as a transformation target")


func test_ending_labels_map_to_the_specification_thirteen_eight_rows() -> void:
	var transformation := _transformation("endings_split_into_presentation_entries")
	assert_false(transformation.is_empty(), "expected RED: the ending transformation is absent")
	if transformation.is_empty():
		return
	var rows: Array = transformation.get("label_mappings", [])
	assert_eq(rows.size(), ENDING_LABEL_MAPPINGS.size(),
		"expected RED: one row per ending label occurrence, %d in all" % ENDING_LABEL_MAPPINGS.size())
	if rows.size() != ENDING_LABEL_MAPPINGS.size():
		return
	for index in range(ENDING_LABEL_MAPPINGS.size()):
		var expected: Array = ENDING_LABEL_MAPPINGS[index]
		var row: Dictionary = rows[index]
		var expected_targets: Array = expected[2]
		var where: String = "%s/%s" % [str(expected[0]), str(expected[1])]
		assert_eq(row.get("source_path"), ENDING_ROOT + str(expected[0]),
			"%s: mapping row %d source" % [where, index])
		assert_eq(row.get("label"), expected[1], "%s: mapping row %d label" % [where, index])
		assert_eq(row.get("target_entry_ids"), expected_targets,
			"%s: the exact specification 13.8 callable entry ids" % where)
		assert_eq(row.get("status"), "unmapped" if expected_targets.is_empty() else "mapped",
			"%s: status states in data whether 13.8 enumerates a row for this label" % where)
	var mapped := 0
	var unmapped := 0
	for row: Dictionary in rows:
		if str(row.get("status", "")) == "mapped":
			mapped += 1
		elif str(row.get("status", "")) == "unmapped":
			unmapped += 1
	assert_eq(mapped, EXPECTED_ENDING_MAPPED_COUNT,
		"the ending transformation resolves exactly %d rows" % EXPECTED_ENDING_MAPPED_COUNT)
	assert_eq(unmapped, EXPECTED_ENDING_UNMAPPED_COUNT,
		"only the undifferentiated ending.priscilla_lavinia label reaches nothing")


func test_every_legacy_label_occurrence_is_accounted_for_exactly_once() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(),
		"expected RED: manifest absent or unparseable: " + _parse_diagnostic(MANIFEST_PATH))
	if manifest.is_empty():
		return
	var outstanding: Dictionary = {}
	var occurrences := 0
	for record: Dictionary in _legacy_files():
		for label: Variant in record.get("labels", []):
			var key: String = "%s|%s" % [str(record.get("path", "")), str(label)]
			assert_false(outstanding.has(key),
				"%s: a label occurrence is unique within its file" % key)
			outstanding[key] = true
			occurrences += 1
	assert_eq(occurrences, EXPECTED_LABEL_COUNT,
		"the inventory holds exactly %d label occurrences" % EXPECTED_LABEL_COUNT)
	assert_eq(manifest.get("legacy_label_count"), occurrences,
		"legacy_label_count equals the number of recorded label occurrences")
	var seen: Dictionary = {}
	var accounted := 0
	var rejected := 0
	var mapped := 0
	var unmapped := 0
	for transformation: Dictionary in manifest.get("transformations", []):
		for row: Dictionary in transformation.get("label_mappings", []):
			var key: String = "%s|%s" % [str(row.get("source_path", "")), str(row.get("label", ""))]
			if str(row.get("status", "")) == "rejected":
				rejected += 1
				assert_true(RETIRED_LABEL_IDS.has(str(row.get("label", ""))),
					"%s: only a retired label may carry the rejected status" % key)
				assert_false(outstanding.has(key),
					"%s: a rejected label is absent from the tree inventory" % key)
				continue
			assert_true(outstanding.has(key),
				"%s: every mapping row names a real label occurrence" % key)
			assert_false(seen.has(key), "%s: no label occurrence is mapped twice" % key)
			seen[key] = true
			accounted += 1
			if str(row.get("status", "")) == "mapped":
				mapped += 1
			else:
				unmapped += 1
	assert_eq(accounted, occurrences,
		"every one of the %d label occurrences is mapped or explicitly unmapped, exactly once" %
		EXPECTED_LABEL_COUNT)
	assert_eq(rejected, EXPECTED_RETIRED_LABEL_COUNT, "one rejected row per retired label")
	assert_eq(mapped, EXPECTED_MAPPED_ROW_COUNT,
		"exactly %d label occurrences resolve to at least one entry id" % EXPECTED_MAPPED_ROW_COUNT)
	assert_eq(unmapped, EXPECTED_UNMAPPED_ROW_COUNT,
		"exactly %d label occurrences are explicitly unmapped" % EXPECTED_UNMAPPED_ROW_COUNT)
	assert_eq(mapped + unmapped, EXPECTED_LABEL_COUNT,
		"the mapped and unmapped tallies partition every tree label occurrence")
	var unaccounted: Array = []
	for key: Variant in outstanding:
		if not seen.has(key):
			unaccounted.append(str(key))
	unaccounted.sort()
	assert_eq(unaccounted, [], "no label occurrence is left out of the transformation mappings")


func test_every_label_mapping_row_is_well_formed() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(),
		"expected RED: manifest absent or unparseable: " + _parse_diagnostic(MANIFEST_PATH))
	if manifest.is_empty():
		return
	var known_paths: Array = []
	for record: Dictionary in _legacy_files():
		known_paths.append(str(record.get("path", "")))
	var rows_seen := 0
	for transformation: Dictionary in manifest.get("transformations", []):
		var declared: Array = transformation.get("target_entry_ids", [])
		for row: Dictionary in transformation.get("label_mappings", []):
			rows_seen += 1
			var source_path: String = str(row.get("source_path", ""))
			var keys: Array = row.keys()
			keys.sort()
			var renamed: bool = keys.has(NON_CANONICAL_FLAG)
			assert_eq(keys, LABEL_MAPPING_KEYS_RENAMED if renamed else LABEL_MAPPING_KEYS,
				"%s: exact label-mapping row keys" % source_path)
			if renamed:
				assert_eq(typeof(row.get(NON_CANONICAL_FLAG)), TYPE_BOOL,
					"%s: the non-canonical spelling flag is a real boolean" % source_path)
				assert_true(bool(row.get(NON_CANONICAL_FLAG)),
					"%s: the flag is recorded only where it is true" % source_path)
			var status: String = str(row.get("status", ""))
			assert_has(ALLOWED_MAPPING_STATUSES, status,
				"%s: status is a closed enum member, never a bare magic string" % source_path)
			assert_true(known_paths.has(source_path),
				"%s: every mapping row names an inventoried legacy file" % source_path)
			var row_targets: Array = row.get("target_entry_ids", [])
			var reason: String = str(row.get("reason", ""))
			if status == "mapped":
				assert_false(row_targets.is_empty(),
					"%s: a mapped row carries at least one entry id" % source_path)
				if renamed:
					assert_false(reason.is_empty(),
						"%s: a renamed row states the divergence in the data" % source_path)
				else:
					assert_true(reason.is_empty(),
						"%s: a mapped row needs no reason" % source_path)
			else:
				assert_true(row_targets.is_empty(),
					"%s: a %s row resolves to no entry id at all" % [source_path, status])
				assert_false(reason.is_empty(),
					"%s: a %s row states why in the data, not in prose" % [source_path, status])
			for target: Variant in row_targets:
				assert_true(declared.has(target),
					"%s: a row target is declared by its own transformation" % str(target))
				assert_false(RETIRED_LABEL_IDS.has(target),
					"%s: no retired label is resurrected as an entry id" % str(target))
	assert_eq(rows_seen, EXPECTED_LABEL_COUNT + EXPECTED_RETIRED_LABEL_COUNT,
		"%d tree label occurrences plus %d rejected retired labels" %
		[EXPECTED_LABEL_COUNT, EXPECTED_RETIRED_LABEL_COUNT])


func test_an_empty_target_list_means_a_retired_transformation_and_nothing_else() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(),
		"expected RED: manifest absent or unparseable: " + _parse_diagnostic(MANIFEST_PATH))
	if manifest.is_empty():
		return
	var transformations: Array = manifest.get("transformations", [])
	assert_eq(transformations.size(), EXPECTED_TRANSFORMATION_COUNT,
		"expected RED: no transformations to inspect")
	if transformations.size() != EXPECTED_TRANSFORMATION_COUNT:
		return
	for transformation: Dictionary in transformations:
		var id: String = str(transformation.get("transformation_id", ""))
		var targets: Array = transformation.get("target_entry_ids", [])
		assert_eq(targets.is_empty(), str(transformation.get("kind", "")) == "retired",
			"%s: an empty target list means retired, and never a deferral" % id)


func test_every_collection_declares_its_own_exact_length() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(),
		"expected RED: manifest absent or unparseable: " + _parse_diagnostic(MANIFEST_PATH))
	if manifest.is_empty():
		return
	var pairs: Array = [
		["legacy_file_count", "legacy_files", EXPECTED_LEGACY_FILE_COUNT],
		["master_timeline_count", "master_timelines", EXPECTED_MASTER_TIMELINE_COUNT],
		["retired_label_count", "retired_labels", EXPECTED_RETIRED_LABEL_COUNT],
		["transformation_count", "transformations", EXPECTED_TRANSFORMATION_COUNT],
	]
	for pair: Array in pairs:
		var count_key: String = str(pair[0])
		var collection_key: String = str(pair[1])
		var collection: Array = manifest.get(collection_key, [])
		assert_eq(typeof(manifest.get(count_key)), TYPE_INT, "%s is an int" % count_key)
		assert_eq(manifest.get(count_key), pair[2], "%s is the frozen exact length" % count_key)
		assert_eq(manifest.get(count_key), collection.size(),
			"%s equals the real length of %s" % [count_key, collection_key])


func test_the_frozen_inventory_agrees_with_the_existing_timeline_manifest() -> void:
	var timelines := _parse(TIMELINE_MANIFEST_PATH)
	assert_false(timelines.is_empty(),
		"the existing timeline manifest must load: " + _parse_diagnostic(TIMELINE_MANIFEST_PATH))
	var legacy_files := _legacy_files()
	assert_eq(legacy_files.size(), EXPECTED_LEGACY_FILE_COUNT, "expected RED: no records to bind")
	if timelines.is_empty() or legacy_files.size() != EXPECTED_LEGACY_FILE_COUNT:
		return
	var records: Array = timelines.get("records", [])
	assert_eq(records.size(), EXPECTED_LEGACY_FILE_COUNT,
		"the timeline manifest inventories the same %d files" % EXPECTED_LEGACY_FILE_COUNT)
	var by_path: Dictionary = {}
	for record: Dictionary in records:
		by_path["res://" + str(record.get("path", ""))] = record
	var total := 0
	for record: Dictionary in legacy_files:
		var path: String = str(record.get("path", ""))
		assert_true(by_path.has(path), "%s: is inventoried by the timeline manifest too" % path)
		if not by_path.has(path):
			continue
		var other: Dictionary = by_path[path]
		assert_eq(str(other.get("id", "")), str(record.get("timeline_id", "")),
			"%s: the two manifests agree on the timeline id" % path)
		assert_eq(other.get("labels"), record.get("labels"),
			"%s: the two manifests agree on the label list" % path)
		assert_eq(str(other.get("content_fingerprint", "")),
			"sha256:" + str(record.get("sha256", "")),
			"%s: the two manifests agree on the content digest" % path)
		var other_labels: Array = other.get("labels", [])
		total += other_labels.size()
	assert_eq(total, EXPECTED_LABEL_COUNT,
		"the timeline manifest independently totals the same %d labels" % EXPECTED_LABEL_COUNT)


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
	var rows: Array = transformation.get("label_mappings", [])
	assert_eq(rows.size(), RETIRED_LABEL_IDS.size(), "one mapping row per retired label")
	if rows.size() != RETIRED_LABEL_IDS.size():
		return
	var ids: Array = []
	for row: Dictionary in rows:
		ids.append(str(row.get("label", "")))
		assert_eq(row.get("status"), "rejected",
			"a retired label is rejected, never aliased to Observer")
		assert_eq(row.get("target_entry_ids"), [],
			"a rejected label resolves to no entry id at all")
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


func test_only_the_two_renamed_ending_labels_are_flagged_non_canonical() -> void:
	var manifest := _load_migration_manifest()
	assert_false(manifest.is_empty(),
		"expected RED: manifest absent or unparseable: " + _parse_diagnostic(MANIFEST_PATH))
	if manifest.is_empty():
		return
	var flagged: Array = []
	var by_key: Dictionary = {}
	for transformation: Dictionary in manifest.get("transformations", []):
		for row: Dictionary in transformation.get("label_mappings", []):
			var pair: Array = [str(row.get("source_path", "")), str(row.get("label", ""))]
			by_key["%s|%s" % pair] = row
			if row.has(NON_CANONICAL_FLAG):
				flagged.append(pair)
	assert_eq(flagged, NON_CANONICAL_RENAME_ROWS,
		"expected RED: exactly the two observation labels carry the non-canonical spelling flag")
	for pair: Array in NON_CANONICAL_RENAME_ROWS:
		var row: Dictionary = by_key.get("%s|%s" % pair, {})
		var reason: String = str(row.get("reason", ""))
		assert_eq(row.get("status"), "mapped", "%s: a renamed label resolves" % str(pair[1]))
		assert_true(reason.contains(RENAME_BEAD),
			"%s: the reason cites the bead that tracks the cutover rename" % str(pair[1]))
		assert_true(reason.contains("observer"),
			"%s: the reason names the specification 13.8 identity" % str(pair[1]))


func test_the_retired_true_labels_are_untouched_by_the_observer_rename() -> void:
	var rows := _label_mapping_rows("retired_ending_true_labels_rejected")
	assert_eq(rows.size(), EXPECTED_RETIRED_LABEL_COUNT, "expected RED: the retired rows are absent")
	if rows.size() != EXPECTED_RETIRED_LABEL_COUNT:
		return
	for row: Dictionary in rows:
		var label: String = str(row.get("label", ""))
		assert_true(RETIRED_LABEL_IDS.has(label), "%s: is a retired ending.*.true label" % label)
		assert_eq(row.get("status"), "rejected", "%s: stays rejected" % label)
		assert_eq(row.get("target_entry_ids"), [],
			"%s: is never aliased to an Observer entry" % label)
		assert_false(row.has(NON_CANONICAL_FLAG),
			"%s: a label retired out of the tree is not a renamed live label" % label)


func test_the_schema_types_the_non_canonical_spelling_flag() -> void:
	var schema := _parse(SCHEMA_PATH)
	var manifest := _load_migration_manifest()
	if schema.is_empty() or manifest.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		return
	var accepted: Dictionary = manifest.duplicate(true)
	var accepted_rows: Array = (accepted["transformations"][0] as Dictionary)["label_mappings"]
	(accepted_rows[0] as Dictionary)[NON_CANONICAL_FLAG] = true
	assert_true(JsonSchemaValidator.validate(accepted, schema).get("ok", false),
		"expected RED: the schema declares the non-canonical spelling flag")
	var refused: Dictionary = manifest.duplicate(true)
	var refused_rows: Array = (refused["transformations"][0] as Dictionary)["label_mappings"]
	(refused_rows[0] as Dictionary)[NON_CANONICAL_FLAG] = "yes"
	assert_false(JsonSchemaValidator.validate(refused, schema).get("ok", true),
		"the flag is a real boolean, never any non-empty value")
