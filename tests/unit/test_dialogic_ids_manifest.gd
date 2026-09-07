extends "res://addons/gut/test.gd"
## Exact Dialogic ID registries (Seven-Day Flow Plan 01 Task 2, sub-commit 2B, dwm-oyo.2).
##
## WHAT THIS SUITE BINDS. data/manifests/dialogic_ids.json registers the eight closed blocks Task 2
## demands: the 13 stable ending ids of specification 13.8, the 11-value ending_form union of 12.3,
## the 18 ordinary reply ids of 12.8, the 18 authoritative reply line ids and 18 guaranteed Day-7
## fallback atom ids of the plan's own presentation table, the four full Priscilla-Lavinia
## observation atoms the same plan bullet names, the five 12.8 signal records with their exact
## payload field lists, the three retired labels Task 1 froze, and the four-value source-stage
## vocabulary. No identifier below was typed from memory: every block is also re-parsed off disk at
## runtime from the plan or the specification, so a defect in whatever generated the manifest cannot
## vouch for itself, and the transcribed constants and the parsed source must agree with each other
## AND with the shipped bytes.
##
## DEVIATION-3 RULING 2, REPLY ID SPELLING. The 18 reply ids use the specification 12.8 spelling
## reply.ordinary.<friend>.day<N>.<a|b|c>, NOT the plan table's reply.contact.ordinary.* column. The
## plan table stays authoritative for its other two columns - the reply LINE ids and the fallback
## ATOM ids - and test_the_shipped_reply_ids_are_the_spec_spelling_not_the_plan_table_spelling
## asserts the divergence explicitly so nobody later "fixes" the manifest towards the plan column.
##
## RULING B, A NAMESPACE IS A DECLARED HOME AND NEVER A STRING PREFIX. The plan's own mandated atom
## ids nest under neither owning entry: atom.echo.lavinia.day1.reply.a.fallback.day7 belongs to
## contact.ordinary.lavinia.day1, whose atom_namespace is atom.contact.ordinary.lavinia.day1, and
## atom.pair.day2.group.full belongs to dating.group.priscilla_lavinia.day2.post_challenge. Every
## one of the 22 registered atom ids therefore FAILS a prefix test against its owner's declared
## atom_namespace, which test_no_registered_atom_id_carries_its_owners_atom_namespace_as_a_prefix
## measures directly. validate_atom_id must resolve ownership from the declared owning entry.
##
## DEVIATION-4 RULING C, ATOMS DECLARE OWNER AND PRESENTATION SITES. Each atom record carries
## owning_entry_id and presented_in_entry_ids. The 18 fallback atoms are owned by the six ordinary
## entries, three apiece, and are presented in echo.fallback.day7; specification 11.1 makes that
## fallback the place the remaining pending echoes drain. The four pair atoms name the same
## dating.*.priscilla_lavinia.day<N>.post_challenge entry as both owner and presentation site.
## validate_atom_id accepts either relation and reports WHICH one matched.
##
## DEVIATION-4 RULING D, CLOSED FOUR-VALUE STAGE VOCABULARY, each snake-cased from a source phrase:
## awaiting_reply (12.8 "while awaiting reply"), current_entry (12.8 "in the current entry"),
## after_full_observation_atom (12.8 "after its full Perfect/Solved observation atom") and
## registered_dating_scene_action (12.5 "at its registered canonical dating-scene action").
##
## DEVIATION-4 RULING E, LINE IDS RESOLVE BY DECLARED HOME. validate_line_id reads owning_entry_id
## and enforces NO string shape. test_every_reply_line_id_begins_with_its_owners_line_namespace is a
## CHANGE DETECTOR ONLY, exactly the status sub-commit 2A gave its ROLE_COUNTS table: it measures
## what these 18 ids happen to look like today and is not a proof that any law requires it.
##
## DEVIATION-4 RULING G, ECHO IDS BIND ON THE ATOM RECORD. Each fallback atom carries echo_id,
## derived from the plan's own mandated atom id by stripping the atom. prefix and the .fallback.day7
## suffix, so echo.lavinia.day1.reply.a binds to atom.echo.lavinia.day1.reply.a.fallback.day7. The
## four pair atoms carry a null echo id. Specification 9.3's binding - one echo id to one stable
## presentation atom id - is enforced by validate_signal for message.echo.satisfy.
##
## THE SCHEMA/CODE SPLIT IS DELIBERATE (DEVIATION-3 Ruling 3). scripts/validation/JsonSchemaValidator
## .gd implements exactly ten keywords - type, const, enum, required, properties,
## additionalProperties, items, minItems, minLength, uniqueItems - and silently ignores every other
## keyword. So the published schema owns every CLOSED VOCABULARY and every SHAPE, and the code owns
## the cross-record and cross-registry laws no implemented keyword can express:
##
##   IDS_MANIFEST_COUNT_MISMATCH             a declared count that disagrees with its collection
##   IDS_MANIFEST_DUPLICATE_ID               one id registered twice inside a block
##   IDS_MANIFEST_UNKNOWN_OWNING_ENTRY       a declared owner absent from the 2A entries manifest
##   IDS_MANIFEST_UNKNOWN_PRESENTATION_ENTRY a declared presentation site absent from it
##   IDS_MANIFEST_ATOM_PARTITION_INVALID     an echo atom without an echo id, or a pair atom with one
##   IDS_MANIFEST_ECHO_BINDING_INVALID       an echo id that is not Ruling G's derivation
##   IDS_MANIFEST_ASSOCIATED_LINE_INVALID    an associated line id that is not a registered line
##   IDS_MANIFEST_SIGNAL_PAYLOAD_INVALID     a payload list missing its envelope or stored unsorted
##   IDS_MANIFEST_SIGNAL_STAGE_INVALID       a source stage outside the document's own vocabulary
##   IDS_MANIFEST_RETIRED_ID_INVALID         a retired label that does not reject on restore
##   IDS_MANIFEST_PAIR_WITNESS_MISMATCH      the pair.combination.witness / pair atom iff law
##   IDS_MANIFEST_ORDINARY_TRIPLE_MISMATCH   the three replies, lines and atoms apiece law
##   IDS_MANIFEST_BLOCK_SHAPE                a registry block that is not an array of records
##
## LAW ORDER IS LOAD BEARING, exactly as in sub-commit 2A. Block shape runs before the schema, so a
## block that is not an array is named rather than reported as a schema type error. Counts run
## before duplicates, because appending a duplicate record breaks BOTH; the duplicate law stays
## independently reachable by appending a duplicate AND raising the declared count to match, which
## is what the duplicate_id fixture does. Duplicates in turn run before the two tally laws, because
## a duplicated atom also breaks the three-apiece tally. Reordering these silently collapses laws
## into one another.
##
## test_the_schema_alone_catches_none_of_the_code_only_ids_laws proves executably that the published
## schema accepts a document breaking each one except IDS_MANIFEST_BLOCK_SHAPE, whose fixture the
## schema would also reject on type and which therefore exists only to name the failure ahead of a
## bare type error. A later agent cannot delete any of the others believing the schema covers it. The converse holds too and is equally deliberate: every closed
## vocabulary lives in the schema alone, because enum and additionalProperties really are enforced,
## and restating them in code would create a law no mutation could reach.
##
## THE S08 REMEDY IS CARRIED FORWARD. Sub-commit 2A lost a whole suite-green because minItems was
## deleted from a schema and every test still passed: the schema half of a defence-in-depth pair had
## no executable proof of its own. test_the_published_ids_schema_pins_its_own_literals therefore
## reads back EVERY literal this schema declares - each const, each enum, each minItems, each
## required list, each additionalProperties false and each uniqueItems - so no second S08 can hide
## behind a code law that happens to catch the same document.
##
## DEVIATION-5 CLOSES THE FOUR FIXTURE-REACHABLE SURVIVORS AND THE RECORD-IS-OBJECT LAW. The 85-site
## mutation campaign against this suite killed 80 sites and left five survivors. FOUR of them were
## second branches of laws whose first branch already had a fixture - a pair atom carrying an echo
## id, a retired label that is also a callable entry, a pair atom owned where pair.combination
## .witness is not granted, and a reply owned where message.reply.commit is not granted. The
## production docstring declared both halves of each; the suite exercised one; deleting the other
## changed no test. RULING H closes each with its own fixture below. Sibling branches of one law
## share a single failure code, so each of these tests asserts the branch's own MESSAGE as well -
## without that the sibling silently covers for the deleted branch and the mutant survives again.
##
## RULING J closes a sixth law the campaign enumerated no site for. validate_ids_document carries TWO
## IDS_MANIFEST_BLOCK_SHAPE laws - block-is-an-array and record-is-an-object - and only the first had
## a fixture, because the block_shape fixture sets a block to an empty dictionary and trips the array
## law first. Its schema half was equally uncovered: this test read items.additionalProperties and
## items.required but never items.type, and deleting items.type makes the node INVISIBLE to
## _collect_open_objects rather than flagged, while additionalProperties keeps working because
## JsonSchemaValidator keys it off the value being a Dictionary. Each half hid the other, which is
## the exact S08 shape. Both halves are now covered.
##
## RULING K pins the nine "type": "string" literals listed in STRING_TYPED_SCHEMA_PATHS. MEASURED
## against scripts/validation/JsonSchemaValidator.gd: line 39 applies minLength ONLY when the value
## is already a string, and lines 11-12 skip the type check entirely when type is absent. So
## deleting type from reply_id lets a NUMERIC reply_id through the schema entirely - no type check
## runs and the minLength beside it is skipped.
##
## WHAT THE CODE THEN DOES SPLITS THE NINE, and this ALSO CORRECTS RULING K, which named
## owning_entry_id as "the one exception". Measured, there are three exception categories, plus a
## fourth id that changes side with its own kind. FOUR are accepted: reply_id, line_id, label_id,
## and atom_id ON A PAIR ATOM. FIVE are caught but under the WRONG NAME - the three owning_entry_id
## fields as IDS_MANIFEST_UNKNOWN_OWNING_ENTRY, presented_in_entry_ids.items as
## IDS_MANIFEST_UNKNOWN_PRESENTATION_ENTRY, and allowed_source_stages.items as
## IDS_MANIFEST_SIGNAL_STAGE_INVALID. That is the nine. Note separately that atom_id ON AN ECHO
## ATOM is caught as IDS_MANIFEST_ECHO_BINDING_INVALID, because the echo id is derived from the
## atom id - the same literal is accepted or caught depending on the record it sits in, which is
## itself a reason to pin it rather than reason about it.
##
## THE FOUR ARE NOT ACCEPTED BECAUSE NOTHING READS THEM - line 523 str()-coerces every record id
## for the duplicate check and line 552 reads every line_id into the registered-lines index. They
## are accepted because no later law REJECTS the coerced value, which is a weaker and more fragile
## thing. For line_id it is outright contingent: all 22 shipped atoms carry associated_line_id
## null, so line 571 never fires; one atom binding a numeric line would make it
## IDS_MANIFEST_ASSOCIATED_LINE_INVALID instead. All nine are pinned either way, because a
## published schema literal is a law in its own right and a type error reported as an unknown
## owner is still a defence that silently changed shape. A census assertion beside the list fails
## if a tenth string-typed field is ever added without being pinned.
##
## RULING L KEEPS the keywords no mutation can kill and documents them AS unreachable in the schema's
## own description text. It named FOUR; a fresh read-only reviewer measured that only THREE qualify,
## and the correction is recorded here rather than quietly applied. The three that do are the type
## array on ending_ids, ending_form_union and source_stages: validate_ids_document refuses a block
## that is not an array at line 496, and the schema is not loaded until line 505 nor applied until
## line 508, so no document can ever reach them. They are correct, they cost nothing, they defend
## this schema if that code order is ever changed or that check removed, and NO campaign site is
## enumerated for any of them, exactly as Ruling L directs, so a later campaign cannot report them
## as false survivors.
##
## THE FOURTH, allowed_source_stages.items.minLength, IS NOT UNREACHABLE, and the ruling's stated
## reason for it was measurably wrong. IDS_MANIFEST_SIGNAL_STAGE_INVALID does NOT run before the
## schema: it is at line 592 and the schema is applied at line 508, EIGHTY-FOUR LINES EARLIER. An
## empty source stage is therefore refused BY THAT minLength, and deleting it changes the code
## from IDS_MANIFEST_SCHEMA_INVALID to IDS_MANIFEST_SIGNAL_STAGE_INVALID. It is a live law that
## merely had no fixture - the same shape as the four Ruling H survivors - so the DEVIATION-4
## CARRY-FORWARD binds and it is closed here the same way: the signal_stage row of
## EMPTY_IDENTIFIER_SITES is its fixture and S55 is its campaign site. The keyword itself is KEPT,
## which is what Ruling L directs; only the false claim about it is withdrawn.
##
## THAT DEPARTURE IS RECORDED, NOT SMUGGLED. Ruling L closes by directing that any site added for
## one of these four be recorded as expected-to-SURVIVE with the ruling cited, or omitted entirely.
## S55 is neither: it is expected to DIE, to this suite's signal_stage fixture. That is a departure
## from a binding ruling on a measured factual error in that ruling, and it awaits maintainer
## ratification on bead dwm-oyo.2. Nothing else in DEVIATION-5 is disturbed by it.
##
## C40 IS DEFERRED, NOT CLOSED, under Ruling I: the reject_on_restore condition inside
## _is_retired_label is unreachable from any fixture BY CONSTRUCTION, because _is_retired_label reads
## the registry from IDS_MANIFEST_PATH on disk rather than from an injected document and all three
## shipped retired records carry reject_on_restore true. Closing it needs a production seam and is
## bead dwm-oyo.2.1.
##
## KNOWN UNTESTED PATHS, recorded rather than hidden. IDS_MANIFEST_FILE_MISSING,
## IDS_MANIFEST_PARSE_FAILED, IDS_MANIFEST_SCHEMA_MISSING and IDS_MANIFEST_ENTRIES_UNAVAILABLE all
## need the manifest, the schema or the 2A entries manifest to be absent or corrupt on disk, which
## this suite does not do. They are KNOWINGLY UNCOVERED and their spelling is pinned by
## test_every_declared_ids_failure_code_exists_in_the_production_source so a rename cannot pass
## unnoticed.
##
## ACCESS IDIOM, inherited from the 2A suite. Dictionary dot access raises and aborts the test body
## on a missing key, so every accessor uses get()/[] and RED reports a clean assertion failure
## instead of a script error. Two parsed documents are compared through CanonicalJsonWriter, because
## this engine's Dictionary equality is not a deep comparison.

const IDS_MANIFEST_PATH := "res://data/manifests/dialogic_ids.json"
const IDS_SCHEMA_PATH := "res://schemas/manifests/dialogic-ids.schema.json"
const ENTRIES_MANIFEST_PATH := "res://data/manifests/dialogic_entries.json"
const MIGRATION_PATH := "res://data/migrations/dialogic_61_to_8.json"
const SCRIPT_PATH := "res://scripts/narrative/DialogicEntryManifest.gd"
const SPEC_PATH := "res://docs/design/2026-08-07-seven-day-dialogic-flow-design.md"
const PLAN_PATH := "res://docs/superpowers/plans/2026-08-07-seven-day-flow-01-dialogic-contract-and-consolidation.md"

const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")

const EXPECTED_ENDING_ID_COUNT := 13
const EXPECTED_ENDING_FORM_COUNT := 11
const EXPECTED_REPLY_ID_COUNT := 18
const EXPECTED_REPLY_LINE_COUNT := 18
const EXPECTED_ATOM_COUNT := 22
const EXPECTED_ECHO_ATOM_COUNT := 18
const EXPECTED_PAIR_ATOM_COUNT := 4
const EXPECTED_SIGNAL_COUNT := 5
const EXPECTED_RETIRED_ID_COUNT := 3
const EXPECTED_SOURCE_STAGE_COUNT := 4
const EXPECTED_ORDINARY_ENTRY_COUNT := 6
const REPLIES_PER_ORDINARY_ENTRY := 3

## Specification 13.8, first column, in table row order.
const ENDING_IDS := [
	"ending.priscilla.sweet", "ending.priscilla.dark", "ending.priscilla.observer",
	"ending.lavinia.sweet", "ending.lavinia.dark", "ending.lavinia.observer",
	"ending.sylvia.sweet", "ending.sylvia.dark", "ending.sylvia.special",
	"ending.priscilla_lavinia.sweet", "ending.priscilla_lavinia.dark",
	"ending.priscilla_lavinia.observer", "ending.alone",
]

## Specification 12.3, in the order the closed union is written there.
const ENDING_FORM_UNION := [
	"derived_sweet", "derived_dark", "special_forced_dark", "deck_sweet", "deck_dark",
	"alone_normal", "alone_dark_mode", "observer_full", "observer_residue", "special_full",
	"special_residue",
]

## Specification 12.8, expanded from its own documented .b/.c shorthand, in bullet order.
const REPLY_IDS := [
	"reply.ordinary.lavinia.day1.a", "reply.ordinary.lavinia.day1.b",
	"reply.ordinary.lavinia.day1.c",
	"reply.ordinary.sylvia.day2.a", "reply.ordinary.sylvia.day2.b",
	"reply.ordinary.sylvia.day2.c",
	"reply.ordinary.priscilla.day3.a", "reply.ordinary.priscilla.day3.b",
	"reply.ordinary.priscilla.day3.c",
	"reply.ordinary.lavinia.day4.a", "reply.ordinary.lavinia.day4.b",
	"reply.ordinary.lavinia.day4.c",
	"reply.ordinary.priscilla.day5.a", "reply.ordinary.priscilla.day5.b",
	"reply.ordinary.priscilla.day5.c",
	"reply.ordinary.sylvia.day6.a", "reply.ordinary.sylvia.day6.b",
	"reply.ordinary.sylvia.day6.c",
]

## Specification 12.8, first column, in table row order.
const SIGNAL_IDS := [
	"message.reply.commit", "history.line.witness", "message.echo.satisfy",
	"observer.evidence.commit", "pair.combination.witness",
]

## DEVIATION-4 Ruling D, in the order the ruling writes them.
const SOURCE_STAGES := [
	"awaiting_reply", "current_entry", "after_full_observation_atom",
	"registered_dating_scene_action",
]

## DEVIATION-4 Ruling D's assignment, one stage per 12.8 signal.
const SIGNAL_STAGE_ASSIGNMENT := [
	["message.reply.commit", "awaiting_reply"],
	["history.line.witness", "current_entry"],
	["message.echo.satisfy", "current_entry"],
	["observer.evidence.commit", "registered_dating_scene_action"],
	["pair.combination.witness", "after_full_observation_atom"],
]

## Every distinct field name the five 12.8 payload rows use, sorted. The published schema closes
## payload_fields against exactly this vocabulary.
const PAYLOAD_FIELD_VOCABULARY := [
	"combination_id", "echo_id", "entry_id", "evidence_id", "line_id", "playback_token",
	"presentation_atom_id", "receipt_id", "reply_id", "witnessed_line_id",
]

## Every payload carries this envelope. 12.4 makes the playback token mandatory and 12.5 makes every
## command an idempotent receipt, so no registered payload may drop one.
const PAYLOAD_ENVELOPE := ["entry_id", "playback_token", "receipt_id"]

const ATOM_KINDS := ["echo_fallback", "pair_full_observation"]

## Specification 7.1 fixes exactly six ordinary replyable messages; the plan's presentation table
## names these six rows, in this order.
const ORDINARY_ENTRIES := [
	"contact.ordinary.lavinia.day1",
	"contact.ordinary.sylvia.day2",
	"contact.ordinary.priscilla.day3",
	"contact.ordinary.lavinia.day4",
	"contact.ordinary.priscilla.day5",
	"contact.ordinary.sylvia.day6",
]

const PAIR_POST_BOARD_ENTRIES := [
	"dating.group.priscilla_lavinia.day2.post_challenge",
	"dating.twofriends.priscilla_lavinia.day2.post_challenge",
	"dating.group.priscilla_lavinia.day6.post_challenge",
	"dating.twofriends.priscilla_lavinia.day6.post_challenge",
]

const ECHO_FALLBACK_ENTRY := "echo.fallback.day7"

## Task 1 froze these three in data/migrations/dialogic_61_to_8.json with reject_on_restore true and
## alias_to_observer false. They are re-read from that file at runtime rather than trusted here.
const RETIRED_LABEL_IDS := [
	"ending.lavinia.true", "ending.priscilla.true", "ending.sylvia.true",
]

const ATOM_ID_PREFIX := "atom."
const FALLBACK_SUFFIX := ".fallback.day7"

const TOP_LEVEL_KEYS := [
	"atom_count", "atoms", "ending_form_count", "ending_form_union", "ending_id_count",
	"ending_ids", "kind", "reply_id_count", "reply_ids", "reply_line_count", "reply_lines",
	"retired_id_count", "retired_ids", "schema_version", "signal_count", "signals",
	"source_stage_count", "source_stages",
]

const ATOM_KEYS := [
	"associated_line_id", "atom_id", "echo_id", "kind", "owning_entry_id",
	"presented_in_entry_ids",
]
const REPLY_ID_KEYS := ["owning_entry_id", "reply_id"]
const REPLY_LINE_KEYS := ["line_id", "owning_entry_id"]
const RETIRED_KEYS := ["label_id", "reject_on_restore"]
const SIGNAL_KEYS := ["allowed_source_stages", "payload_fields", "signal_id"]

## DEVIATION-5 Ruling K. Every "type": "string" this schema declares, by path.
## MEASURED against scripts/validation/JsonSchemaValidator.gd: minLength is applied ONLY when the
## value is already a string, so deleting one of these lets a NUMERIC identifier through the schema
## entirely - no type check runs and the minLength beside it is skipped. Four are then accepted
## by the code (reply_id, line_id, label_id, and a pair atom's atom_id) - not because nothing
## reads them, but because no later law REJECTS the str()-coerced value; the other five are caught
## by a later law but under the WRONG NAME, which is a defence that changed shape without anyone
## noticing. Ruling K itself named owning_entry_id as the only exception; measured, there are
## three. Each is a live law either way, so each is read back by
## test_the_published_ids_schema_pins_its_own_literals, which also counts them so a tenth cannot
## arrive unpinned.
const STRING_TYPED_SCHEMA_PATHS := [
	["properties", "reply_ids", "items", "properties", "reply_id"],
	["properties", "reply_ids", "items", "properties", "owning_entry_id"],
	["properties", "reply_lines", "items", "properties", "line_id"],
	["properties", "reply_lines", "items", "properties", "owning_entry_id"],
	["properties", "atoms", "items", "properties", "atom_id"],
	["properties", "atoms", "items", "properties", "owning_entry_id"],
	["properties", "atoms", "items", "properties", "presented_in_entry_ids", "items"],
	["properties", "signals", "items", "properties", "allowed_source_stages", "items"],
	["properties", "retired_ids", "items", "properties", "label_id"],
]

## The ten keywords scripts/validation/JsonSchemaValidator.gd actually implements, plus the two pure
## annotations that assert nothing. Anything else in a manifest schema is inert.
const IMPLEMENTED_KEYWORDS := [
	"type", "const", "enum", "required", "properties", "additionalProperties", "items",
	"minItems", "minLength", "uniqueItems",
]
const SCHEMA_ANNOTATIONS := ["$schema", "description"]

const CODE_DOCUMENT_SHAPE := &"IDS_MANIFEST_DOCUMENT_SHAPE"
const CODE_SCHEMA_INVALID := &"IDS_MANIFEST_SCHEMA_INVALID"
const CODE_COUNT_MISMATCH := &"IDS_MANIFEST_COUNT_MISMATCH"
const CODE_DUPLICATE_ID := &"IDS_MANIFEST_DUPLICATE_ID"
const CODE_UNKNOWN_OWNING_ENTRY := &"IDS_MANIFEST_UNKNOWN_OWNING_ENTRY"
const CODE_UNKNOWN_PRESENTATION_ENTRY := &"IDS_MANIFEST_UNKNOWN_PRESENTATION_ENTRY"
const CODE_ATOM_PARTITION_INVALID := &"IDS_MANIFEST_ATOM_PARTITION_INVALID"
const CODE_ECHO_BINDING_INVALID := &"IDS_MANIFEST_ECHO_BINDING_INVALID"
const CODE_ASSOCIATED_LINE_INVALID := &"IDS_MANIFEST_ASSOCIATED_LINE_INVALID"
const CODE_SIGNAL_PAYLOAD_INVALID := &"IDS_MANIFEST_SIGNAL_PAYLOAD_INVALID"
const CODE_SIGNAL_STAGE_INVALID := &"IDS_MANIFEST_SIGNAL_STAGE_INVALID"
const CODE_RETIRED_ID_INVALID := &"IDS_MANIFEST_RETIRED_ID_INVALID"
const CODE_PAIR_WITNESS_MISMATCH := &"IDS_MANIFEST_PAIR_WITNESS_MISMATCH"
const CODE_ORDINARY_TRIPLE_MISMATCH := &"IDS_MANIFEST_ORDINARY_TRIPLE_MISMATCH"
const CODE_BLOCK_SHAPE := &"IDS_MANIFEST_BLOCK_SHAPE"

## KNOWINGLY UNCOVERED: reaching these four needs a file to be absent or corrupt on disk.
const CODE_FILE_MISSING := &"IDS_MANIFEST_FILE_MISSING"
const CODE_PARSE_FAILED := &"IDS_MANIFEST_PARSE_FAILED"
const CODE_SCHEMA_MISSING := &"IDS_MANIFEST_SCHEMA_MISSING"
const CODE_ENTRIES_UNAVAILABLE := &"IDS_MANIFEST_ENTRIES_UNAVAILABLE"

const CODE_SIGNAL_UNKNOWN_ENTRY := &"SIGNAL_UNKNOWN_ENTRY"
const CODE_SIGNAL_ENTRY_MISMATCH := &"SIGNAL_ENTRY_MISMATCH"
const CODE_SIGNAL_UNKNOWN_SIGNAL := &"SIGNAL_UNKNOWN_SIGNAL"
const CODE_SIGNAL_NOT_GRANTED := &"SIGNAL_NOT_GRANTED"
const CODE_SIGNAL_STAGE_NOT_ALLOWED := &"SIGNAL_STAGE_NOT_ALLOWED"
const CODE_SIGNAL_PAYLOAD_FIELD_MISSING := &"SIGNAL_PAYLOAD_FIELD_MISSING"
const CODE_SIGNAL_PAYLOAD_FIELD_UNKNOWN := &"SIGNAL_PAYLOAD_FIELD_UNKNOWN"
const CODE_SIGNAL_REPLY_ID_INVALID := &"SIGNAL_REPLY_ID_INVALID"
const CODE_SIGNAL_ECHO_BINDING_INVALID := &"SIGNAL_ECHO_BINDING_INVALID"
const CODE_SIGNAL_OPAQUE_FIELD_INVALID := &"SIGNAL_OPAQUE_FIELD_INVALID"

## The four payload fields this phase has no registry for. playback_token is minted per entry by the
## bridge and receipt_id per command by the state owner, so 12.8 gives neither a vocabulary;
## evidence_id and combination_id await the approved content card the plan defers them to. All four
## are constrained to a non-empty string and to nothing stronger, which is deliberately weaker than
## a registry lookup and is recorded as such rather than dressed up as a closed law.
const OPAQUE_PAYLOAD_FIELDS := [
	"combination_id", "evidence_id", "playback_token", "receipt_id",
]

const CODE_LINE_ID_UNKNOWN_ENTRY := &"LINE_ID_UNKNOWN_ENTRY"
const CODE_LINE_ID_UNREGISTERED := &"LINE_ID_UNREGISTERED"
const CODE_LINE_ID_NOT_OWNED := &"LINE_ID_NOT_OWNED"

const CODE_ATOM_ID_UNKNOWN_ENTRY := &"ATOM_ID_UNKNOWN_ENTRY"
const CODE_ATOM_ID_UNREGISTERED := &"ATOM_ID_UNREGISTERED"
const CODE_ATOM_ID_NOT_PRESENTABLE := &"ATOM_ID_NOT_PRESENTABLE"

const CODE_RETIRED_ENTRY := &"ENTRY_MANIFEST_RETIRED_ENTRY"

const ALL_IDS_FAILURE_CODES := [
	CODE_DOCUMENT_SHAPE, CODE_SCHEMA_INVALID, CODE_COUNT_MISMATCH, CODE_DUPLICATE_ID,
	CODE_UNKNOWN_OWNING_ENTRY, CODE_UNKNOWN_PRESENTATION_ENTRY, CODE_ATOM_PARTITION_INVALID,
	CODE_ECHO_BINDING_INVALID, CODE_ASSOCIATED_LINE_INVALID, CODE_SIGNAL_PAYLOAD_INVALID,
	CODE_SIGNAL_STAGE_INVALID, CODE_RETIRED_ID_INVALID, CODE_PAIR_WITNESS_MISMATCH,
	CODE_ORDINARY_TRIPLE_MISMATCH, CODE_BLOCK_SHAPE, CODE_FILE_MISSING,
	CODE_PARSE_FAILED, CODE_SCHEMA_MISSING, CODE_ENTRIES_UNAVAILABLE,
	CODE_SIGNAL_UNKNOWN_ENTRY, CODE_SIGNAL_ENTRY_MISMATCH, CODE_SIGNAL_UNKNOWN_SIGNAL,
	CODE_SIGNAL_NOT_GRANTED, CODE_SIGNAL_STAGE_NOT_ALLOWED, CODE_SIGNAL_PAYLOAD_FIELD_MISSING,
	CODE_SIGNAL_PAYLOAD_FIELD_UNKNOWN, CODE_SIGNAL_REPLY_ID_INVALID,
	CODE_SIGNAL_ECHO_BINDING_INVALID, CODE_SIGNAL_OPAQUE_FIELD_INVALID,
	CODE_LINE_ID_UNKNOWN_ENTRY, CODE_LINE_ID_UNREGISTERED, CODE_LINE_ID_NOT_OWNED,
	CODE_ATOM_ID_UNKNOWN_ENTRY, CODE_ATOM_ID_UNREGISTERED, CODE_ATOM_ID_NOT_PRESENTABLE,
	CODE_RETIRED_ENTRY,
]

const SUB_COMMIT_2B_METHOD_NAMES := [
	"load_ids_default", "validate_ids_document", "validate_signal", "validate_line_id",
	"validate_atom_id",
]


# --------------------------------------------------------------------------------------------
# Loading helpers. Everything fails soft so RED is an assertion, never a script error.
# --------------------------------------------------------------------------------------------

func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	if not parsed.get("ok", false):
		return {}
	return parsed["value"]


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


func _document() -> Dictionary:
	return _parse(IDS_MANIFEST_PATH)


func _entries_document() -> Dictionary:
	return _parse(ENTRIES_MANIFEST_PATH)


func _block(name: String) -> Array:
	var value: Variant = _document().get(name, [])
	return value if value is Array else []


func _manifest_script() -> Script:
	var loaded: Dictionary = PROBE.load_script(SCRIPT_PATH)
	if not loaded.get("ok", false):
		return null
	return loaded["value"] as Script


func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	return str(emitted.get("value", "")) if emitted.get("ok", false) else ""


func _guard() -> bool:
	var document := _document()
	if document.is_empty() or _manifest_script() == null:
		assert_false(document.is_empty(),
			"expected RED: " + _parse_diagnostic(IDS_MANIFEST_PATH))
		assert_true(_manifest_script() != null, "expected RED: missing " + SCRIPT_PATH)
		return false
	return true


func _field(record: Variant, key: String) -> String:
	return str((record as Dictionary).get(key, "")) if record is Dictionary else ""


func _string_list(record: Variant, key: String) -> Array:
	if not (record is Dictionary):
		return []
	var value: Variant = (record as Dictionary).get(key, [])
	return value if value is Array else []


func _ids_of(block_name: String, key: String) -> Array:
	var out: Array = []
	for record: Variant in _block(block_name):
		out.append(_field(record, key))
	return out


func _atom_by_id(atom_id: String) -> Dictionary:
	for record: Variant in _block("atoms"):
		if record is Dictionary and _field(record, "atom_id") == atom_id:
			return record
	return {}


func _signal_by_id(signal_id: String) -> Dictionary:
	for record: Variant in _block("signals"):
		if record is Dictionary and _field(record, "signal_id") == signal_id:
			return record
	return {}


func _entry_record(entry_id: String) -> Dictionary:
	var entries: Variant = _entries_document().get("entries", [])
	if not (entries is Array):
		return {}
	for candidate: Variant in (entries as Array):
		if candidate is Dictionary and _field(candidate, "entry_id") == entry_id:
			return candidate
	return {}


# --------------------------------------------------------------------------------------------
# Second, independent derivation: re-parse the plan and the specification off disk.
# --------------------------------------------------------------------------------------------

func _text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


## The contents of every backtick-delimited span on one line, in order.
func _backticked(line: String) -> Array:
	var out: Array = []
	var pieces: PackedStringArray = line.split("`")
	for index in range(pieces.size()):
		if index % 2 == 1:
			out.append(str(pieces[index]).strip_edges())
	return out


func _table_cells(line: String) -> Array:
	if not line.strip_edges().begins_with("|"):
		return []
	var out: Array = []
	for cell: String in line.strip_edges().trim_prefix("|").trim_suffix("|").split("|"):
		out.append(cell.strip_edges())
	return out


func _section(text: String, start_marker: String, end_marker: String) -> String:
	var at := text.find(start_marker)
	if at < 0:
		return ""
	var rest := text.substr(at)
	var stop := rest.find(end_marker, start_marker.length())
	return rest if stop < 0 else rest.substr(0, stop)


## [[entry_id, plan_reply_ids, line_ids, atom_ids], ...] in plan Task 2 table row order.
func _plan_presentation_rows() -> Array:
	var out: Array = []
	for line: String in _section(_text(PLAN_PATH), "## Task 2", "## Task 3").split("\n"):
		var cells := _table_cells(line)
		if cells.size() != 4:
			continue
		var head := _backticked(str(cells[0]))
		if head.size() != 1 or not str(head[0]).begins_with("contact.ordinary."):
			continue
		out.append([
			str(head[0]), _backticked(str(cells[1])), _backticked(str(cells[2])),
			_backticked(str(cells[3])),
		])
	return out


## The four full Priscilla-Lavinia observation atoms the plan's own bullet names, in order.
func _plan_pair_atom_ids() -> Array:
	var out: Array = []
	for line: String in _section(_text(PLAN_PATH), "## Task 2", "## Task 3").split("\n"):
		if not line.contains("Also register exactly four"):
			continue
		for token: Variant in _backticked(line):
			if str(token).begins_with("atom.pair."):
				out.append(str(token))
	return out


## Specification 13.8, first column, in table row order.
func _spec_ending_ids() -> Array:
	var out: Array = []
	for line: String in _section(_text(SPEC_PATH), "### 13.8", "## 14").split("\n"):
		var cells := _table_cells(line)
		if cells.size() != 3:
			continue
		var head := _backticked(str(cells[0]))
		if head.size() != 1 or not str(head[0]).begins_with("ending."):
			continue
		out.append(str(head[0]))
	return out


## [[signal_id, payload_fields, valid_source_text], ...] in specification 12.8 table row order.
func _spec_signal_rows() -> Array:
	var out: Array = []
	for line: String in _section(_text(SPEC_PATH), "### 12.8", "## 13").split("\n"):
		var cells := _table_cells(line)
		if cells.size() != 3:
			continue
		var head := _backticked(str(cells[0]))
		if head.size() != 1 or str(head[0]).find(".") < 0:
			continue
		out.append([str(head[0]), _backticked(str(cells[1])), str(cells[2])])
	return out


## Specification 12.8's own .b/.c shorthand, expanded against the full id that opens each bullet.
func _spec_reply_ids() -> Array:
	var out: Array = []
	for line: String in _section(_text(SPEC_PATH), "### 12.8", "## 13").split("\n"):
		if not line.begins_with("- `reply.ordinary."):
			continue
		var tokens := _backticked(line)
		if tokens.is_empty():
			continue
		var first: String = str(tokens[0])
		if first.length() < 2:
			continue
		var base: String = first.left(first.length() - 2)
		for token: Variant in tokens:
			var piece: String = str(token)
			var shorthand: bool = piece.length() == 2 and piece.begins_with(".")
			out.append((base + piece) if shorthand else piece)
	return out


## Specification 12.3's closed ending_form union, read across the line break it is written over.
func _spec_ending_form_union() -> Array:
	var text := _text(SPEC_PATH)
	var marker := "is a closed union:"
	var at := text.find(marker)
	if at < 0:
		return []
	var rest := text.substr(at + marker.length())
	var open := rest.find("`")
	var close := rest.find("`", open + 1) if open >= 0 else -1
	if open < 0 or close < 0:
		return []
	var out: Array = []
	for piece: String in rest.substr(open + 1, close - open - 1).replace("\n", " ").split("|"):
		var trimmed := piece.strip_edges()
		if not trimmed.is_empty():
			out.append(trimmed)
	return out


## Task 1's frozen retired labels, read back out of the migration manifest.
func _migration_retired_labels() -> Array:
	var value: Variant = _parse(MIGRATION_PATH).get("retired_labels", [])
	return value if value is Array else []


# --------------------------------------------------------------------------------------------
# Document shape.
# --------------------------------------------------------------------------------------------

func test_the_ids_manifest_exists_and_parses_as_strict_json() -> void:
	assert_true(FileAccess.file_exists(IDS_MANIFEST_PATH),
		"expected RED: missing " + IDS_MANIFEST_PATH)
	assert_eq(_parse_diagnostic(IDS_MANIFEST_PATH), "",
		"StrictJson accepts the shipped registry")


func test_the_ids_manifest_top_level_is_exact_key() -> void:
	var document := _document()
	assert_false(document.is_empty(), "expected RED: " + _parse_diagnostic(IDS_MANIFEST_PATH))
	if document.is_empty():
		return
	var keys: Array = document.keys()
	keys.sort()
	assert_eq(keys, TOP_LEVEL_KEYS, "the registry declares exactly these eighteen top-level keys")
	assert_eq(document.get("schema_version"), 1, "schema_version is pinned at 1")
	assert_eq(document.get("kind"), "dialogic_ids", "kind names this registry")


func test_every_declared_count_equals_its_real_collection_length() -> void:
	var document := _document()
	assert_false(document.is_empty(), "expected RED: " + _parse_diagnostic(IDS_MANIFEST_PATH))
	if document.is_empty():
		return
	var rows: Array = [
		["ending_id_count", "ending_ids", EXPECTED_ENDING_ID_COUNT],
		["ending_form_count", "ending_form_union", EXPECTED_ENDING_FORM_COUNT],
		["reply_id_count", "reply_ids", EXPECTED_REPLY_ID_COUNT],
		["reply_line_count", "reply_lines", EXPECTED_REPLY_LINE_COUNT],
		["atom_count", "atoms", EXPECTED_ATOM_COUNT],
		["signal_count", "signals", EXPECTED_SIGNAL_COUNT],
		["retired_id_count", "retired_ids", EXPECTED_RETIRED_ID_COUNT],
		["source_stage_count", "source_stages", EXPECTED_SOURCE_STAGE_COUNT],
	]
	for row: Array in rows:
		var count_key: String = str(row[0])
		var block_key: String = str(row[1])
		assert_eq(document.get(count_key), row[2],
			"%s declares the figure this sub-commit registers" % count_key)
		assert_eq(_block(block_key).size(), row[2],
			"%s really holds that many records" % block_key)


func test_the_ids_manifest_is_stored_byte_canonically() -> void:
	var document := _document()
	assert_false(document.is_empty(), "expected RED: " + _parse_diagnostic(IDS_MANIFEST_PATH))
	if document.is_empty():
		return
	var canonical := _canonical(document)
	assert_false(canonical.is_empty(), "the document round-trips through CanonicalJsonWriter")
	if canonical.is_empty():
		return
	assert_eq(FileAccess.get_file_as_string(IDS_MANIFEST_PATH), canonical + "\n",
		"the file holds one canonical sorted-key line and a single trailing newline")


# --------------------------------------------------------------------------------------------
# Block content, transcribed here and re-parsed off disk, three-way.
# --------------------------------------------------------------------------------------------

func test_the_thirteen_ending_ids_are_the_specification_table_read_at_runtime() -> void:
	var parsed := _spec_ending_ids()
	assert_eq(parsed.size(), EXPECTED_ENDING_ID_COUNT,
		"the 13.8 table still declares thirteen semantic ending identities")
	assert_eq(parsed, ENDING_IDS, "and they are the thirteen transcribed above, in table order")
	assert_eq(_block("ending_ids"), ENDING_IDS, "the registry ships exactly them, in that order")


func test_the_thirteen_ending_ids_are_the_distinct_ending_ids_of_the_entries_manifest() -> void:
	var entries: Variant = _entries_document().get("entries", [])
	assert_true(entries is Array, "expected RED: " + _parse_diagnostic(ENTRIES_MANIFEST_PATH))
	if not (entries is Array):
		return
	var seen: Array = []
	for record: Variant in (entries as Array):
		if not (record is Dictionary):
			continue
		var ending_id: Variant = (record as Dictionary).get("ending_id")
		if ending_id == null or seen.has(str(ending_id)):
			continue
		seen.append(str(ending_id))
	seen.sort()
	var registered: Array = _block("ending_ids").duplicate()
	registered.sort()
	assert_eq(registered, seen,
		"every registered ending identity is presented by a 2A entry and no other identity is")


func test_the_ending_form_union_is_the_twelve_three_closed_union_read_at_runtime() -> void:
	var parsed := _spec_ending_form_union()
	assert_eq(parsed.size(), EXPECTED_ENDING_FORM_COUNT,
		"specification 12.3 still writes an eleven-value closed union")
	assert_eq(parsed, ENDING_FORM_UNION, "and it is the union transcribed above, in written order")
	assert_eq(_block("ending_form_union"), ENDING_FORM_UNION, "the registry ships exactly it")


func test_the_shipped_reply_ids_are_the_spec_spelling_not_the_plan_table_spelling() -> void:
	var parsed := _spec_reply_ids()
	assert_eq(parsed.size(), EXPECTED_REPLY_ID_COUNT,
		"specification 12.8 still names eighteen stable ordinary reply ids")
	assert_eq(parsed, REPLY_IDS, "and they expand to the eighteen transcribed above")
	assert_eq(_ids_of("reply_ids", "reply_id"), REPLY_IDS,
		"DEVIATION-3 Ruling 2: the registry ships the 12.8 spelling")
	var plan_column: Array = []
	for row: Array in _plan_presentation_rows():
		for token: Variant in row[1]:
			plan_column.append(str(token))
	assert_eq(plan_column.size(), EXPECTED_REPLY_ID_COUNT,
		"the plan table still carries its own eighteen-id reply column")
	for candidate: Variant in plan_column:
		assert_true(str(candidate).begins_with("reply.contact.ordinary."),
			"the plan column really does use the reply.contact.ordinary spelling")
		assert_false(REPLY_IDS.has(str(candidate)),
			"%s: Ruling 2 rejects the plan spelling, so it must not be shipped" % str(candidate))


func test_the_eighteen_reply_line_ids_are_the_plan_table_column_read_at_runtime() -> void:
	var rows := _plan_presentation_rows()
	assert_eq(rows.size(), EXPECTED_ORDINARY_ENTRY_COUNT,
		"the plan presentation table still has its six ordinary rows")
	if rows.size() != EXPECTED_ORDINARY_ENTRY_COUNT:
		return
	var expected_ids: Array = []
	var expected_owners: Array = []
	for row: Array in rows:
		assert_eq((row[2] as Array).size(), REPLIES_PER_ORDINARY_ENTRY,
			"%s owns exactly three authoritative reply line ids" % str(row[0]))
		for token: Variant in row[2]:
			expected_ids.append(str(token))
			expected_owners.append(str(row[0]))
	assert_eq(_ids_of("reply_lines", "line_id"), expected_ids,
		"the registry ships the plan's own line id column, in table order")
	assert_eq(_ids_of("reply_lines", "owning_entry_id"), expected_owners,
		"and declares the row's ordinary entry as each line's home")


func test_the_eighteen_fallback_atom_ids_are_the_plan_table_column_read_at_runtime() -> void:
	var rows := _plan_presentation_rows()
	assert_eq(rows.size(), EXPECTED_ORDINARY_ENTRY_COUNT,
		"the plan presentation table still has its six ordinary rows")
	if rows.size() != EXPECTED_ORDINARY_ENTRY_COUNT:
		return
	var expected_ids: Array = []
	var expected_owners: Array = []
	for row: Array in rows:
		assert_eq((row[3] as Array).size(), REPLIES_PER_ORDINARY_ENTRY,
			"%s owns exactly three guaranteed Day-7 fallback atom ids" % str(row[0]))
		for token: Variant in row[3]:
			expected_ids.append(str(token))
			expected_owners.append(str(row[0]))
	var shipped_ids: Array = []
	var shipped_owners: Array = []
	for record: Variant in _block("atoms"):
		if _field(record, "kind") != "echo_fallback":
			continue
		shipped_ids.append(_field(record, "atom_id"))
		shipped_owners.append(_field(record, "owning_entry_id"))
	assert_eq(shipped_ids, expected_ids,
		"the registry ships the plan's own fallback atom column, in table order")
	assert_eq(shipped_owners, expected_owners,
		"DEVIATION-4 Ruling C: the ordinary entry of the row owns its three fallback atoms")


func test_the_four_pair_atoms_are_the_four_the_plan_bullet_names() -> void:
	var parsed := _plan_pair_atom_ids()
	assert_eq(parsed.size(), EXPECTED_PAIR_ATOM_COUNT,
		"the plan still registers exactly four full observation atoms")
	var shipped_ids: Array = []
	var shipped_owners: Array = []
	for record: Variant in _block("atoms"):
		if _field(record, "kind") != "pair_full_observation":
			continue
		shipped_ids.append(_field(record, "atom_id"))
		shipped_owners.append(_field(record, "owning_entry_id"))
	assert_eq(shipped_ids, parsed, "the registry ships exactly those four, in the plan's order")
	assert_eq(shipped_owners, PAIR_POST_BOARD_ENTRIES,
		"each is owned by its own canonical visible Priscilla-Lavinia post-board entry")
	for record: Variant in _block("atoms"):
		if _field(record, "kind") != "pair_full_observation":
			continue
		assert_eq(_string_list(record, "presented_in_entry_ids"),
			[_field(record, "owning_entry_id")],
			"Ruling C: a pair atom is presented in the same entry that owns it")


func test_every_fallback_atom_is_presented_only_in_the_day_seven_fallback_entry() -> void:
	var seen := 0
	for record: Variant in _block("atoms"):
		if _field(record, "kind") != "echo_fallback":
			continue
		seen += 1
		assert_eq(_string_list(record, "presented_in_entry_ids"), [ECHO_FALLBACK_ENTRY],
			"%s: 11.1 drains the remaining pending echoes in the Day 7 fallback"
			% _field(record, "atom_id"))
	assert_eq(seen, EXPECTED_ECHO_ATOM_COUNT, "there are eighteen such atoms")


func test_the_echo_id_is_the_ruled_derivation_of_its_atom_id() -> void:
	var echo_ids: Array = []
	for record: Variant in _block("atoms"):
		var atom_id := _field(record, "atom_id")
		var kind := _field(record, "kind")
		var echo_id: Variant = (record as Dictionary).get("echo_id") if record is Dictionary else null
		if kind == "pair_full_observation":
			assert_eq(echo_id, null, "%s: Ruling G gives a pair atom no echo id" % atom_id)
			continue
		assert_true(atom_id.begins_with(ATOM_ID_PREFIX),
			"%s: a fallback atom id opens with the atom. prefix" % atom_id)
		assert_true(atom_id.ends_with(FALLBACK_SUFFIX),
			"%s: a fallback atom id closes with the .fallback.day7 suffix" % atom_id)
		var derived: String = atom_id.trim_prefix(ATOM_ID_PREFIX).trim_suffix(FALLBACK_SUFFIX)
		assert_eq(str(echo_id), derived,
			"%s: Ruling G derives the echo id from the plan's own atom id" % atom_id)
		assert_false(echo_ids.has(derived), "%s: one echo id binds one atom" % derived)
		echo_ids.append(derived)
	assert_eq(echo_ids.size(), EXPECTED_ECHO_ATOM_COUNT, "eighteen echo ids are bound")


func test_the_five_signal_records_are_the_twelve_eight_rows_read_at_runtime() -> void:
	var rows := _spec_signal_rows()
	assert_eq(rows.size(), EXPECTED_SIGNAL_COUNT,
		"specification 12.8 still allows exactly five command kinds")
	if rows.size() != EXPECTED_SIGNAL_COUNT:
		return
	var parsed_ids: Array = []
	for row: Array in rows:
		parsed_ids.append(str(row[0]))
	assert_eq(parsed_ids, SIGNAL_IDS, "and they are the five transcribed above, in table order")
	assert_eq(_ids_of("signals", "signal_id"), SIGNAL_IDS, "the registry ships exactly them")
	for row: Array in rows:
		var signal_id: String = str(row[0])
		var expected: Array = []
		for token: Variant in row[1]:
			expected.append(str(token))
		expected.sort()
		var record := _signal_by_id(signal_id)
		assert_eq(_string_list(record, "payload_fields"), expected,
			"%s: the registry ships the 12.8 payload list, stored sorted" % signal_id)
		for field_name: Variant in expected:
			assert_true(PAYLOAD_FIELD_VOCABULARY.has(str(field_name)),
				"%s: %s is inside the closed payload vocabulary" % [signal_id, str(field_name)])


func test_every_signal_declares_its_ruled_source_stage() -> void:
	for row: Array in SIGNAL_STAGE_ASSIGNMENT:
		var signal_id: String = str(row[0])
		var record := _signal_by_id(signal_id)
		assert_false(record.is_empty(), "%s is a registered signal" % signal_id)
		assert_eq(_string_list(record, "allowed_source_stages"), [str(row[1])],
			"DEVIATION-4 Ruling D assigns %s exactly this stage" % signal_id)


func test_the_stage_vocabulary_is_the_four_ruled_values() -> void:
	assert_eq(_block("source_stages"), SOURCE_STAGES,
		"the registry ships the four-value stage vocabulary, in the ruling's order")
	for row: Array in SIGNAL_STAGE_ASSIGNMENT:
		assert_true(SOURCE_STAGES.has(str(row[1])),
			"%s draws its stage from the declared vocabulary" % str(row[0]))


func test_the_three_retired_ids_carry_task_ones_reject_on_restore() -> void:
	var frozen := _migration_retired_labels()
	assert_eq(frozen.size(), EXPECTED_RETIRED_ID_COUNT,
		"Task 1 still freezes exactly three retired labels")
	var expected_ids: Array = []
	for record: Variant in frozen:
		expected_ids.append(_field(record, "label_id"))
		assert_eq((record as Dictionary).get("reject_on_restore"), true,
			"%s: Task 1 rejects it on restore" % _field(record, "label_id"))
	assert_eq(expected_ids, RETIRED_LABEL_IDS, "and they are the three transcribed above")
	assert_eq(_ids_of("retired_ids", "label_id"), RETIRED_LABEL_IDS,
		"the registry carries the same three, in the same order")
	for record: Variant in _block("retired_ids"):
		assert_eq((record as Dictionary).get("reject_on_restore"), true,
			"%s: the carried flag is Task 1's, not a weaker one" % _field(record, "label_id"))


# --------------------------------------------------------------------------------------------
# Cross-registry invariants against the 2A entries manifest.
# --------------------------------------------------------------------------------------------

func test_every_declared_owning_and_presentation_entry_resolves_in_the_entries_manifest() -> void:
	var script := _manifest_script()
	if script == null or _entries_document().is_empty():
		assert_true(script != null, "expected RED: missing " + SCRIPT_PATH)
		assert_false(_entries_document().is_empty(), "expected RED: entries manifest unreadable")
		return
	var entries_document := _entries_document()
	var rows: Array = [
		["reply_ids", "owning_entry_id"], ["reply_lines", "owning_entry_id"],
		["atoms", "owning_entry_id"],
	]
	var checked := 0
	for row: Array in rows:
		for record: Variant in _block(str(row[0])):
			var owner := _field(record, str(row[1]))
			var resolved: Dictionary = script.call(
				&"resolve_entry", entries_document, owner, "en")
			assert_true(resolved.get("ok", false),
				"%s: the declared owner %s resolves in the 2A manifest" % [str(row[0]), owner])
			checked += 1
	for record: Variant in _block("atoms"):
		for site: Variant in _string_list(record, "presented_in_entry_ids"):
			var resolved_site: Dictionary = script.call(
				&"resolve_entry", entries_document, str(site), "en")
			assert_true(resolved_site.get("ok", false),
				"%s: the presentation site %s resolves in the 2A manifest"
				% [_field(record, "atom_id"), str(site)])
			checked += 1
	assert_eq(checked, 80,
		"eighteen replies, eighteen lines, twenty-two owners and twenty-two sites were resolved")


func test_the_six_ordinary_entries_own_three_replies_three_lines_and_three_atoms_apiece() -> void:
	for entry_id: Variant in ORDINARY_ENTRIES:
		var replies := 0
		var lines := 0
		var atoms := 0
		for record: Variant in _block("reply_ids"):
			if _field(record, "owning_entry_id") == str(entry_id):
				replies += 1
		for record: Variant in _block("reply_lines"):
			if _field(record, "owning_entry_id") == str(entry_id):
				lines += 1
		for record: Variant in _block("atoms"):
			if _field(record, "owning_entry_id") == str(entry_id):
				atoms += 1
		assert_eq(replies, REPLIES_PER_ORDINARY_ENTRY, "%s owns three reply ids" % str(entry_id))
		assert_eq(lines, REPLIES_PER_ORDINARY_ENTRY, "%s owns three reply line ids" % str(entry_id))
		assert_eq(atoms, REPLIES_PER_ORDINARY_ENTRY, "%s owns three fallback atoms" % str(entry_id))


func test_pair_combination_witness_is_granted_exactly_where_a_pair_atom_is_owned() -> void:
	var entries: Variant = _entries_document().get("entries", [])
	assert_true(entries is Array, "expected RED: " + _parse_diagnostic(ENTRIES_MANIFEST_PATH))
	if not (entries is Array):
		return
	for record: Variant in (entries as Array):
		if not (record is Dictionary):
			continue
		var entry_id := _field(record, "entry_id")
		var grants: bool = _string_list(record, "allowed_signals").has("pair.combination.witness")
		var owned := 0
		for atom: Variant in _block("atoms"):
			if (_field(atom, "kind") == "pair_full_observation"
					and _field(atom, "owning_entry_id") == entry_id):
				owned += 1
		if grants:
			assert_eq(owned, 1, "%s grants the witness, so it owns exactly one pair atom" % entry_id)
		else:
			assert_eq(owned, 0, "%s owns no pair atom, so it must not grant the witness" % entry_id)


## DEVIATION-4 Ruling E CHANGE DETECTOR, NOT A SPECIFICATION PROOF. This measures what the plan's
## eighteen line ids happen to look like beside their owner's declared line_namespace today. Nothing
## in validate_line_id may derive ownership from this shape; the ruling forbids it.
func test_every_reply_line_id_begins_with_its_owners_line_namespace() -> void:
	var checked := 0
	for record: Variant in _block("reply_lines"):
		var owner := _field(record, "owning_entry_id")
		var namespace_field := _field(_entry_record(owner), "line_namespace")
		assert_false(namespace_field.is_empty(), "%s declares a line namespace" % owner)
		assert_true(_field(record, "line_id").begins_with(namespace_field),
			"MEASURED: %s sits under %s" % [_field(record, "line_id"), namespace_field])
		checked += 1
	assert_eq(checked, EXPECTED_REPLY_LINE_COUNT,
		"all eighteen were measured, so an empty registry cannot pass this vacuously")


## RULING B REGRESSION. Every registered atom id fails a prefix test against its owner's declared
## atom_namespace, so any implementation that required one would reject all twenty-two.
func test_no_registered_atom_id_carries_its_owners_atom_namespace_as_a_prefix() -> void:
	var checked := 0
	for record: Variant in _block("atoms"):
		var owner := _field(record, "owning_entry_id")
		var namespace_field := _field(_entry_record(owner), "atom_namespace")
		assert_false(namespace_field.is_empty(), "%s declares an atom namespace" % owner)
		assert_false(_field(record, "atom_id").begins_with(namespace_field),
			"%s deliberately nests outside %s" % [_field(record, "atom_id"), namespace_field])
		checked += 1
	assert_eq(checked, EXPECTED_ATOM_COUNT, "all twenty-two were measured")


func test_no_registered_id_uses_a_wildcard_or_shorthand_family() -> void:
	var blocks: Array = [
		["ending_ids", ""], ["ending_form_union", ""], ["source_stages", ""],
		["reply_ids", "reply_id"], ["reply_lines", "line_id"], ["atoms", "atom_id"],
		["signals", "signal_id"], ["retired_ids", "label_id"],
	]
	var checked := 0
	for block: Array in blocks:
		for record: Variant in _block(str(block[0])):
			var text: String = str(record) if str(block[1]).is_empty() else _field(record, str(block[1]))
			assert_false(text.is_empty(), "%s: every registered id is non-empty" % str(block[0]))
			for illegal: String in ["*", "|", "{", "}", "?", " "]:
				assert_false(text.contains(illegal),
					"%s: %s must not appear in a closed id" % [text, illegal])
			checked += 1
	assert_eq(checked, 94, "the eight blocks hold ninety-four registered strings between them")


# --------------------------------------------------------------------------------------------
# Published schema: what it really enforces.
# --------------------------------------------------------------------------------------------

func _schema() -> Dictionary:
	return _parse(IDS_SCHEMA_PATH)


func _schema_property(path: Array) -> Dictionary:
	var node: Variant = _schema()
	for step: Variant in path:
		if not (node is Dictionary):
			return {}
		node = (node as Dictionary).get(str(step), {})
	return node if node is Dictionary else {}


func test_the_published_ids_schema_accepts_the_manifest() -> void:
	var schema := _schema()
	var document := _document()
	if schema.is_empty() or document.is_empty():
		assert_false(schema.is_empty(), "expected RED: " + _parse_diagnostic(IDS_SCHEMA_PATH))
		assert_false(document.is_empty(), "expected RED: " + _parse_diagnostic(IDS_MANIFEST_PATH))
		return
	var result: Dictionary = JsonSchemaValidator.validate(document, schema)
	assert_true(result.get("ok", false),
		"the published schema accepts the shipped registry: " + str(result.get("message", "")))


func test_the_ids_schema_closes_every_object_level() -> void:
	var schema := _schema()
	assert_false(schema.is_empty(), "expected RED: " + _parse_diagnostic(IDS_SCHEMA_PATH))
	if schema.is_empty():
		return
	assert_eq(schema.get("$schema"), "https://json-schema.org/draft/2020-12/schema",
		"draft 2020-12, as every other manifest schema in this repository")
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


func test_the_ids_schema_uses_only_keywords_the_validator_implements() -> void:
	var schema := _schema()
	assert_false(schema.is_empty(), "expected RED: " + _parse_diagnostic(IDS_SCHEMA_PATH))
	if schema.is_empty():
		return
	var inert: Array = []
	_collect_inert_keywords(schema, "$", inert)
	assert_eq(inert, [],
		"DEVIATION-3 Ruling 3 forbids an inert keyword; JsonSchemaValidator ignores it silently")


func _collect_inert_keywords(node: Variant, path: String, found: Array) -> void:
	if not (node is Dictionary):
		return
	var object: Dictionary = node
	for key: Variant in object:
		var keyword: String = str(key)
		if not IMPLEMENTED_KEYWORDS.has(keyword) and not SCHEMA_ANNOTATIONS.has(keyword):
			found.append("%s.%s" % [path, keyword])
	var properties: Variant = object.get("properties")
	if properties is Dictionary:
		for name: Variant in (properties as Dictionary):
			_collect_inert_keywords((properties as Dictionary)[name],
				"%s.properties.%s" % [path, str(name)], found)
	if object.has("items"):
		_collect_inert_keywords(object["items"], path + ".items", found)


## THE S08 REMEDY. Every literal the schema declares is read back here, so deleting any one of them
## fails a test even where a code law happens to reject the same document.
func test_the_published_ids_schema_pins_its_own_literals() -> void:
	var schema := _schema()
	assert_false(schema.is_empty(), "expected RED: " + _parse_diagnostic(IDS_SCHEMA_PATH))
	if schema.is_empty():
		return
	var top_required: Array = schema.get("required", [])
	top_required.sort()
	assert_eq(top_required, TOP_LEVEL_KEYS, "the schema requires exactly the eighteen top keys")
	assert_eq(schema.get("additionalProperties"), false, "the top level is closed")
	assert_eq(_schema_property(["properties", "schema_version"]).get("const"), 1,
		"schema_version is pinned")
	assert_eq(_schema_property(["properties", "kind"]).get("const"), "dialogic_ids",
		"kind is pinned")

	var ending_ids := _schema_property(["properties", "ending_ids"])
	assert_eq(ending_ids.get("minItems"), EXPECTED_ENDING_ID_COUNT, "the ending id floor is thirteen")
	assert_eq(ending_ids.get("uniqueItems"), true, "the ending id list is a set")
	assert_eq((ending_ids.get("items", {}) as Dictionary).get("enum"), ENDING_IDS,
		"the ending id vocabulary is closed at the thirteen 13.8 identities")

	var forms := _schema_property(["properties", "ending_form_union"])
	assert_eq(forms.get("minItems"), EXPECTED_ENDING_FORM_COUNT, "the ending form floor is eleven")
	assert_eq(forms.get("uniqueItems"), true, "the ending form list is a set")
	assert_eq((forms.get("items", {}) as Dictionary).get("enum"), ENDING_FORM_UNION,
		"the ending form vocabulary is closed at the 12.3 union")

	var stages := _schema_property(["properties", "source_stages"])
	assert_eq(stages.get("minItems"), EXPECTED_SOURCE_STAGE_COUNT, "the stage floor is four")
	assert_eq(stages.get("uniqueItems"), true, "the stage list is a set")
	assert_eq((stages.get("items", {}) as Dictionary).get("enum"), SOURCE_STAGES,
		"the stage vocabulary is closed at Ruling D's four values")

	var count_rows: Array = [
		["ending_id_count"], ["ending_form_count"], ["reply_id_count"], ["reply_line_count"],
		["atom_count"], ["signal_count"], ["retired_id_count"], ["source_stage_count"],
	]
	for row: Array in count_rows:
		assert_eq(_schema_property(["properties", str(row[0])]).get("type"), "integer",
			"%s is declared an integer and cross-checked in code, never pinned by const" % str(row[0]))
		assert_false(_schema_property(["properties", str(row[0])]).has("const"),
			"%s: a const here would make IDS_MANIFEST_COUNT_MISMATCH unreachable" % str(row[0]))

	var record_rows: Array = [
		["reply_ids", REPLY_ID_KEYS, EXPECTED_REPLY_ID_COUNT],
		["reply_lines", REPLY_LINE_KEYS, EXPECTED_REPLY_LINE_COUNT],
		["atoms", ATOM_KEYS, EXPECTED_ATOM_COUNT],
		["signals", SIGNAL_KEYS, EXPECTED_SIGNAL_COUNT],
		["retired_ids", RETIRED_KEYS, EXPECTED_RETIRED_ID_COUNT],
	]
	for row: Array in record_rows:
		var block := _schema_property(["properties", str(row[0])])
		assert_eq(block.get("type"), "array", "%s is an array" % str(row[0]))
		assert_eq(block.get("minItems"), row[2], "%s declares its exact floor" % str(row[0]))
		var items := _schema_property(["properties", str(row[0]), "items"])
		assert_eq(items.get("type"), "object",
			("%s: Ruling J, a record is an object; deleting items.type hides the node"
				+ " from _collect_open_objects instead of flagging it") % str(row[0]))
		assert_eq(items.get("additionalProperties"), false, "%s records are closed" % str(row[0]))
		var required: Array = items.get("required", [])
		required.sort()
		assert_eq(required, row[1], "%s records require exactly their keys" % str(row[0]))

	var atom_items := _schema_property(["properties", "atoms", "items", "properties"])
	assert_eq((atom_items.get("kind", {}) as Dictionary).get("enum"), ATOM_KINDS,
		"the atom kind vocabulary is closed at two values")
	var sites: Dictionary = atom_items.get("presented_in_entry_ids", {})
	assert_eq(sites.get("minItems"), 1, "an atom declares at least one presentation site")
	assert_eq(sites.get("uniqueItems"), true, "the presentation site list is a set")

	var signal_items := _schema_property(["properties", "signals", "items", "properties"])
	assert_eq((signal_items.get("signal_id", {}) as Dictionary).get("enum"), SIGNAL_IDS,
		"the signal vocabulary is closed at the five 12.8 ids")
	var payload: Dictionary = signal_items.get("payload_fields", {})
	assert_eq(payload.get("minItems"), 4, "the smallest 12.8 payload carries four fields")
	assert_eq(payload.get("uniqueItems"), true, "a payload names each field once")
	assert_eq((payload.get("items", {}) as Dictionary).get("enum"), PAYLOAD_FIELD_VOCABULARY,
		"the payload field vocabulary is closed at the ten names 12.8 uses")
	var allowed: Dictionary = signal_items.get("allowed_source_stages", {})
	assert_eq(allowed.get("minItems"), 1, "a signal declares at least one legal source stage")
	assert_eq(allowed.get("uniqueItems"), true, "the stage list is a set")

	var retired_items := _schema_property(["properties", "retired_ids", "items", "properties"])
	assert_eq((retired_items.get("reject_on_restore", {}) as Dictionary).get("type"), "boolean",
		"reject_on_restore is a boolean carried through from Task 1")

	# DEVIATION-5 Ruling K. Nine live string types, and a census so a tenth cannot arrive unpinned.
	for path: Array in STRING_TYPED_SCHEMA_PATHS:
		assert_eq(_schema_property(path).get("type"), "string",
			"%s is declared a string, or the minLength beside it never runs" % str(path))
	var string_typed: Array = []
	_collect_string_typed(schema, "$", string_typed)
	assert_eq(string_typed.size(), STRING_TYPED_SCHEMA_PATHS.size(),
		"every string-typed field this schema declares is pinned above: " + str(string_typed))


func _collect_string_typed(node: Variant, path: String, found: Array) -> void:
	if not (node is Dictionary):
		return
	var object: Dictionary = node
	if str(object.get("type", "")) == "string":
		found.append(path)
	var properties: Variant = object.get("properties")
	if properties is Dictionary:
		for name: Variant in (properties as Dictionary):
			_collect_string_typed((properties as Dictionary)[name],
				"%s.%s" % [path, str(name)], found)
	if object.has("items"):
		_collect_string_typed(object["items"], path + ".items", found)


const EMPTY_IDENTIFIER_SITES := [
	"reply_id", "reply_owner", "line_id", "line_owner", "atom_id", "atom_owner",
	"atom_site", "retired_label", "signal_stage",
]


func test_the_ids_schema_rejects_every_empty_identifier() -> void:
	var schema := _schema()
	var document := _document()
	if schema.is_empty() or document.is_empty():
		assert_false(schema.is_empty(), "expected RED: " + _parse_diagnostic(IDS_SCHEMA_PATH))
		assert_false(document.is_empty(), "expected RED: " + _parse_diagnostic(IDS_MANIFEST_PATH))
		return
	for site: String in EMPTY_IDENTIFIER_SITES:
		var mutated: Dictionary = document.duplicate(true)
		match site:
			"reply_id":
				((mutated["reply_ids"] as Array)[0] as Dictionary)["reply_id"] = ""
			"reply_owner":
				((mutated["reply_ids"] as Array)[0] as Dictionary)["owning_entry_id"] = ""
			"line_id":
				((mutated["reply_lines"] as Array)[0] as Dictionary)["line_id"] = ""
			"line_owner":
				((mutated["reply_lines"] as Array)[0] as Dictionary)["owning_entry_id"] = ""
			"atom_id":
				((mutated["atoms"] as Array)[0] as Dictionary)["atom_id"] = ""
			"atom_owner":
				((mutated["atoms"] as Array)[0] as Dictionary)["owning_entry_id"] = ""
			"atom_site":
				((mutated["atoms"] as Array)[0] as Dictionary)["presented_in_entry_ids"] = [""]
			"retired_label":
				((mutated["retired_ids"] as Array)[0] as Dictionary)["label_id"] = ""
			"signal_stage":
				# The reviewer MEASURED that this one is reachable after all: the schema runs at
				# DialogicEntryManifest.gd:508 and IDS_MANIFEST_SIGNAL_STAGE_INVALID only at 592, so
				# allowed_source_stages.items.minLength refuses an empty stage FIRST and deleting it
				# changes the observed failure code. It is a live law, so it gets a fixture.
				((mutated["signals"] as Array)[0] as Dictionary)["allowed_source_stages"] = [""]
		assert_false(JsonSchemaValidator.validate(mutated, schema).get("ok", true),
			"%s: an empty identifier is rejected by the published schema" % site)


func test_the_ids_schema_rejects_every_unknown_vocabulary_value() -> void:
	var schema := _schema()
	var document := _document()
	if schema.is_empty() or document.is_empty():
		assert_false(schema.is_empty(), "expected RED: " + _parse_diagnostic(IDS_SCHEMA_PATH))
		assert_false(document.is_empty(), "expected RED: " + _parse_diagnostic(IDS_MANIFEST_PATH))
		return
	var sites: Array = [
		"ending_id", "ending_form", "source_stage", "atom_kind", "signal_id", "payload_field",
		"top_level_key", "record_key",
	]
	for site: String in sites:
		var mutated: Dictionary = document.duplicate(true)
		match site:
			"ending_id":
				(mutated["ending_ids"] as Array)[0] = "ending.priscilla.true"
			"ending_form":
				(mutated["ending_form_union"] as Array)[0] = "derived_ambiguous"
			"source_stage":
				(mutated["source_stages"] as Array)[0] = "any_time"
			"atom_kind":
				((mutated["atoms"] as Array)[0] as Dictionary)["kind"] = "dialogue"
			"signal_id":
				((mutated["signals"] as Array)[0] as Dictionary)["signal_id"] = "message.reply.undo"
			"payload_field":
				((mutated["signals"] as Array)[0] as Dictionary)["payload_fields"] = [
					"entry_id", "playback_token", "receipt_id", "relationship_delta",
				]
			"top_level_key":
				mutated["notes"] = "free text"
			"record_key":
				((mutated["atoms"] as Array)[0] as Dictionary)["stage"] = "current_entry"
		assert_false(JsonSchemaValidator.validate(mutated, schema).get("ok", true),
			"%s: the published schema owns this closed vocabulary" % site)


# --------------------------------------------------------------------------------------------
# Mutation builders for the code-only laws. Each returns a fresh deep copy.
# --------------------------------------------------------------------------------------------

func _mutate(site: String) -> Dictionary:
	var mutated: Dictionary = _document().duplicate(true)
	var atoms: Array = mutated.get("atoms", [])
	var signals: Array = mutated.get("signals", [])
	match site:
		"count_mismatch":
			atoms.append({
				"associated_line_id": null,
				"atom_id": "atom.echo.lavinia.day1.reply.a.fallback.day7",
				"echo_id": "echo.lavinia.day1.reply.a",
				"kind": "echo_fallback",
				"owning_entry_id": "contact.ordinary.lavinia.day1",
				"presented_in_entry_ids": [ECHO_FALLBACK_ENTRY],
			})
		"duplicate_id":
			atoms.append((atoms[0] as Dictionary).duplicate(true))
			mutated["atom_count"] = EXPECTED_ATOM_COUNT + 1
		"unknown_owning_entry":
			(atoms[0] as Dictionary)["owning_entry_id"] = "contact.ordinary.lavinia.day8"
		"unknown_presentation_entry":
			(atoms[0] as Dictionary)["presented_in_entry_ids"] = ["echo.fallback.day8"]
		"atom_partition":
			(atoms[0] as Dictionary)["echo_id"] = null
		"echo_binding":
			(atoms[0] as Dictionary)["echo_id"] = "echo.lavinia.day1.reply.c"
		"associated_line":
			(atoms[0] as Dictionary)["associated_line_id"] = "line.contact.ordinary.lavinia.day1.opening"
		"signal_payload_missing_envelope":
			var without_entry := _signal_index(signals, "history.line.witness")
			without_entry["payload_fields"] = [
				"evidence_id", "line_id", "playback_token", "receipt_id",
			]
		"signal_payload_unsorted":
			var reversed_payload := _signal_index(signals, "history.line.witness")
			reversed_payload["payload_fields"] = [
				"receipt_id", "playback_token", "line_id", "entry_id",
			]
		"signal_stage":
			var bad_stage := _signal_index(signals, "history.line.witness")
			bad_stage["allowed_source_stages"] = ["whenever_convenient"]
		"retired_id":
			((mutated["retired_ids"] as Array)[0] as Dictionary)["reject_on_restore"] = false
		"pair_witness":
			for record: Variant in atoms:
				if _field(record, "atom_id") == "atom.pair.day2.twofriends.full":
					(record as Dictionary)["owning_entry_id"] = PAIR_POST_BOARD_ENTRIES[0]
		"ordinary_triple":
			for record: Variant in (mutated["reply_ids"] as Array):
				if _field(record, "reply_id") == "reply.ordinary.lavinia.day1.c":
					(record as Dictionary)["owning_entry_id"] = ORDINARY_ENTRIES[1]
		"atom_partition_pair":
			# DEVIATION-5 Ruling H, the elif half: a pair atom that DOES bind an echo id.
			for record: Variant in atoms:
				if _field(record, "atom_id") == "atom.pair.day2.group.full":
					(record as Dictionary)["echo_id"] = "echo.pair.day2.group"
		"retired_label_is_callable":
			# DEVIATION-5 Ruling H: a retired label that is ALSO a live callable entry.
			((mutated["retired_ids"] as Array)[0] as Dictionary)["label_id"] = ORDINARY_ENTRIES[0]
		"pair_witness_ungranted":
			# DEVIATION-5 Ruling H, the not-granted direction: an ordinary entry, which never holds
			# pair.combination.witness, is made the owner of a pair atom. The four real pair owners
			# keep exactly one apiece, so the granted direction stays satisfied and only this one
			# branch can refuse the document.
			for record: Variant in atoms:
				if _field(record, "atom_id") == "atom.echo.lavinia.day1.reply.a.fallback.day7":
					(record as Dictionary)["kind"] = "pair_full_observation"
					(record as Dictionary)["echo_id"] = null
		"ordinary_triple_ungranted":
			# DEVIATION-5 Ruling H, the first ORDINARY_TRIPLE loop: a reply owned by a registered
			# entry that does not grant message.reply.commit. The existing ordinary_triple fixture
			# moves the record to ANOTHER ordinary entry, so only the later tally loop ever fires.
			for record: Variant in (mutated["reply_ids"] as Array):
				if _field(record, "reply_id") == "reply.ordinary.lavinia.day1.c":
					(record as Dictionary)["owning_entry_id"] = ECHO_FALLBACK_ENTRY
		"block_shape":
			mutated["atoms"] = {}
		"record_shape":
			# DEVIATION-5 Ruling J: a WELL-FORMED array block whose member is not a record. The
			# block_shape fixture above trips the block-is-an-array law first and can never reach
			# this second IDS_MANIFEST_BLOCK_SHAPE law.
			(mutated["atoms"] as Array)[0] = "atom.echo.lavinia.day1.reply.a.fallback.day7"
	return mutated


func _signal_index(signals: Array, signal_id: String) -> Dictionary:
	for record: Variant in signals:
		if record is Dictionary and _field(record, "signal_id") == signal_id:
			return record
	return {}


## Each row is a code-only law: the published schema accepts the document, and only the named code
## law refuses it. This is the executable proof that no schema keyword covers any of them.
const CODE_ONLY_LAW_SITES := [
	["count_mismatch", "IDS_MANIFEST_COUNT_MISMATCH"],
	["duplicate_id", "IDS_MANIFEST_DUPLICATE_ID"],
	["unknown_owning_entry", "IDS_MANIFEST_UNKNOWN_OWNING_ENTRY"],
	["unknown_presentation_entry", "IDS_MANIFEST_UNKNOWN_PRESENTATION_ENTRY"],
	["atom_partition", "IDS_MANIFEST_ATOM_PARTITION_INVALID"],
	["echo_binding", "IDS_MANIFEST_ECHO_BINDING_INVALID"],
	["associated_line", "IDS_MANIFEST_ASSOCIATED_LINE_INVALID"],
	["signal_payload_missing_envelope", "IDS_MANIFEST_SIGNAL_PAYLOAD_INVALID"],
	["signal_payload_unsorted", "IDS_MANIFEST_SIGNAL_PAYLOAD_INVALID"],
	["signal_stage", "IDS_MANIFEST_SIGNAL_STAGE_INVALID"],
	["retired_id", "IDS_MANIFEST_RETIRED_ID_INVALID"],
	["pair_witness", "IDS_MANIFEST_PAIR_WITNESS_MISMATCH"],
	["ordinary_triple", "IDS_MANIFEST_ORDINARY_TRIPLE_MISMATCH"],
	["atom_partition_pair", "IDS_MANIFEST_ATOM_PARTITION_INVALID"],
	["retired_label_is_callable", "IDS_MANIFEST_RETIRED_ID_INVALID"],
	["pair_witness_ungranted", "IDS_MANIFEST_PAIR_WITNESS_MISMATCH"],
	["ordinary_triple_ungranted", "IDS_MANIFEST_ORDINARY_TRIPLE_MISMATCH"],
]


func test_the_schema_alone_catches_none_of_the_code_only_ids_laws() -> void:
	var schema := _schema()
	if schema.is_empty() or not _guard():
		assert_false(schema.is_empty(), "expected RED: " + _parse_diagnostic(IDS_SCHEMA_PATH))
		return
	var script := _manifest_script()
	for row: Array in CODE_ONLY_LAW_SITES:
		var site: String = str(row[0])
		var mutated := _mutate(site)
		assert_true(JsonSchemaValidator.validate(mutated, schema).get("ok", false),
			"%s: the published schema alone accepts it, which is why a code law exists" % site)
		var result: Dictionary = script.call(&"validate_ids_document", mutated)
		assert_false(result.get("ok", true), "%s: the code law rejects it" % site)
		assert_eq(str(result.get("code", "")), str(row[1]), "%s: with its own named code" % site)


# --------------------------------------------------------------------------------------------
# load_ids_default and validate_ids_document.
# --------------------------------------------------------------------------------------------

func test_the_manifest_script_declares_the_sub_commit_2b_methods() -> void:
	var script := _manifest_script()
	assert_true(script != null, "expected RED: missing " + SCRIPT_PATH)
	if script == null:
		return
	var names: Array = []
	for method: Dictionary in script.get_script_method_list():
		names.append(str(method.get("name", "")))
	for declared: String in SUB_COMMIT_2B_METHOD_NAMES:
		assert_true(names.has(declared), "%s is implemented by sub-commit 2B" % declared)


func test_load_ids_default_returns_the_shipped_registry() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var result: Dictionary = script.call(&"load_ids_default")
	assert_true(result.get("ok", false),
		"load_ids_default succeeds: " + str(result.get("message", "")))
	if not result.get("ok", false):
		return
	assert_eq(_canonical(result.get("value")), _canonical(_document()),
		"and returns exactly the bytes on disk")


func test_validate_ids_document_accepts_the_shipped_registry() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var result: Dictionary = script.call(&"validate_ids_document", _document())
	assert_true(result.get("ok", false),
		"the shipped registry passes every law: " + str(result.get("message", "")))


func _reject_ids(mutated: Dictionary, code: StringName, why: String) -> void:
	var script := _manifest_script()
	if script == null:
		assert_true(false, "expected RED: missing " + SCRIPT_PATH)
		return
	var result: Dictionary = script.call(&"validate_ids_document", mutated)
	assert_false(result.get("ok", true), why)
	assert_eq(result.get("code"), code, why + " (named code)")


func test_validate_ids_document_rejects_a_non_document() -> void:
	if not _guard():
		return
	_reject_ids({}, CODE_DOCUMENT_SHAPE, "a document with no registry blocks is rejected")


func test_validate_ids_document_rejects_a_block_that_is_not_an_array() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("block_shape"), CODE_BLOCK_SHAPE,
		"a registry block that is not an array is named before the schema reports a type error")


func test_validate_ids_document_rejects_a_document_the_schema_refuses() -> void:
	if not _guard():
		return
	var mutated: Dictionary = _document().duplicate(true)
	mutated["kind"] = "dialogic_identifiers"
	_reject_ids(mutated, CODE_SCHEMA_INVALID, "the published schema is run first and owns kind")


func test_validate_ids_document_rejects_a_count_that_disagrees_with_its_block() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("count_mismatch"), CODE_COUNT_MISMATCH,
		"a declared count that no longer matches its collection is rejected")


func test_validate_ids_document_rejects_a_duplicate_registered_id() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("duplicate_id"), CODE_DUPLICATE_ID,
		"one id registered twice inside a block is rejected")


func test_validate_ids_document_rejects_an_unknown_owning_entry() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("unknown_owning_entry"), CODE_UNKNOWN_OWNING_ENTRY,
		"a declared home absent from the 2A entries manifest is rejected")


func test_validate_ids_document_rejects_an_unknown_presentation_entry() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("unknown_presentation_entry"), CODE_UNKNOWN_PRESENTATION_ENTRY,
		"a declared presentation site absent from the 2A entries manifest is rejected")


func test_validate_ids_document_rejects_a_broken_atom_partition() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("atom_partition"), CODE_ATOM_PARTITION_INVALID,
		"an echo atom without an echo id is rejected")


func test_validate_ids_document_rejects_an_echo_id_that_is_not_the_ruled_derivation() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("echo_binding"), CODE_ECHO_BINDING_INVALID,
		"Ruling G binds one echo id to one atom id, derived from that atom id")


func test_validate_ids_document_rejects_an_unregistered_associated_line() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("associated_line"), CODE_ASSOCIATED_LINE_INVALID,
		"an associated line id that is not a registered line is rejected")


func test_validate_ids_document_rejects_a_payload_missing_its_envelope() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("signal_payload_missing_envelope"), CODE_SIGNAL_PAYLOAD_INVALID,
		"12.4 and 12.5 make entry_id, playback_token and receipt_id mandatory on every payload")


func test_validate_ids_document_rejects_an_unsorted_payload_list() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("signal_payload_unsorted"), CODE_SIGNAL_PAYLOAD_INVALID,
		"payload_fields is stored sorted, so equal payloads cannot differ in bytes")


func test_validate_ids_document_rejects_a_stage_outside_the_declared_vocabulary() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("signal_stage"), CODE_SIGNAL_STAGE_INVALID,
		"a source stage must be drawn from the registry's own four-value vocabulary")


func test_validate_ids_document_rejects_a_retired_id_that_does_not_reject_on_restore() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("retired_id"), CODE_RETIRED_ID_INVALID,
		"a registered retired label that accepts a restore would silently alias a dead ending")


func test_validate_ids_document_rejects_a_broken_pair_witness_iff() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("pair_witness"), CODE_PAIR_WITNESS_MISMATCH,
		"an entry grants pair.combination.witness exactly when it owns one pair atom")


func test_validate_ids_document_rejects_a_broken_ordinary_triple() -> void:
	if not _guard():
		return
	_reject_ids(_mutate("ordinary_triple"), CODE_ORDINARY_TRIPLE_MISMATCH,
		"each of the six ordinary entries owns three replies, three lines and three atoms")


## DEVIATION-5 Rulings H and J. Sibling branches of one law share a single failure code, so a
## test that asserts the code alone still passes when the branch it targets is deleted and the
## sibling refuses the same document. Each fixture below therefore asserts the branch's OWN
## message fragment as well, which is what makes the mutant die to a NAMED test.
func _reject_ids_naming(
		mutated: Dictionary, code: StringName, fragment: String, why: String) -> void:
	var script := _manifest_script()
	if script == null:
		assert_true(false, "expected RED: missing " + SCRIPT_PATH)
		return
	var result: Dictionary = script.call(&"validate_ids_document", mutated)
	assert_false(result.get("ok", true), why)
	assert_eq(result.get("code"), code, why + " (named code)")
	assert_true(str(result.get("message", "")).contains(fragment),
		"%s (this branch's own message, not a sibling's): %s"
			% [why, str(result.get("message", ""))])


func test_validate_ids_document_rejects_a_pair_atom_that_binds_an_echo_id() -> void:
	if not _guard():
		return
	_reject_ids_naming(_mutate("atom_partition_pair"), CODE_ATOM_PARTITION_INVALID,
		"binds no echo id",
		"a pair observation atom binds no echo id, so carrying one breaks the partition")


func test_validate_ids_document_rejects_a_retired_label_that_is_also_a_callable_entry() -> void:
	if not _guard():
		return
	_reject_ids_naming(_mutate("retired_label_is_callable"), CODE_RETIRED_ID_INVALID,
		"may not also be a callable entry",
		"a label cannot be refused on restore and callable as a live entry at the same time")


func test_validate_ids_document_rejects_a_pair_atom_owned_without_the_witness_grant() -> void:
	if not _guard():
		return
	_reject_ids_naming(_mutate("pair_witness_ungranted"), CODE_PAIR_WITNESS_MISMATCH,
		"may not witness a combination",
		"the iff runs both ways: owning a pair atom without the grant is refused too")


func test_validate_ids_document_rejects_a_reply_owned_without_the_reply_grant() -> void:
	if not _guard():
		return
	_reject_ids_naming(_mutate("ordinary_triple_ungranted"), CODE_ORDINARY_TRIPLE_MISMATCH,
		"owns a reply presentation but may not commit a reply",
		"an owner outside the six ordinary entries is refused before any tally is counted")


func test_validate_ids_document_rejects_a_record_that_is_not_an_object() -> void:
	if not _guard():
		return
	_reject_ids_naming(_mutate("record_shape"), CODE_BLOCK_SHAPE,
		"record is an object",
		"a well-formed array block whose member is not a record is named, not left to the schema")


# --------------------------------------------------------------------------------------------
# validate_line_id. DEVIATION-4 Ruling E: resolution is by declared home, never by string shape.
# --------------------------------------------------------------------------------------------

func _entries() -> Dictionary:
	return _entries_document()


func test_validate_line_id_accepts_a_registered_line_for_its_declared_owner() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var checked := 0
	for record: Variant in _block("reply_lines"):
		var line_id := _field(record, "line_id")
		var owner := _field(record, "owning_entry_id")
		var result: Dictionary = script.call(&"validate_line_id", _entries(), owner, line_id)
		assert_true(result.get("ok", false),
			"%s resolves for its declared home %s: %s"
			% [line_id, owner, str(result.get("message", ""))])
		if not result.get("ok", false):
			continue
		assert_eq((result["value"] as Dictionary).get("line_id"), line_id,
			"the success value names the line")
		assert_eq((result["value"] as Dictionary).get("owning_entry_id"), owner,
			"and the declared home it resolved through")
		checked += 1
	assert_eq(checked, EXPECTED_REPLY_LINE_COUNT,
		"all eighteen resolved, so an empty registry cannot pass this vacuously")


func test_validate_line_id_refuses_an_unregistered_line_id() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var result: Dictionary = script.call(&"validate_line_id", _entries(), ORDINARY_ENTRIES[0],
		"line.contact.ordinary.lavinia.day1.reply.d")
	assert_false(result.get("ok", true), "a line id nobody registered fails closed")
	assert_eq(result.get("code"), CODE_LINE_ID_UNREGISTERED, "with its own named code")


## RULING E, THE POINT OF THE RULE. This id carries the owner's line_namespace as a prefix and is
## still refused, because membership is registration and never string shape.
func test_validate_line_id_refuses_a_well_shaped_but_unregistered_line_id() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var namespace_field := _field(_entry_record(ORDINARY_ENTRIES[0]), "line_namespace")
	var candidate := namespace_field + ".reply.z"
	assert_false(_ids_of("reply_lines", "line_id").has(candidate), "the fixture is unregistered")
	var result: Dictionary = script.call(&"validate_line_id", _entries(), ORDINARY_ENTRIES[0],
		candidate)
	assert_false(result.get("ok", true), "a well-shaped stranger is still refused")
	assert_eq(result.get("code"), CODE_LINE_ID_UNREGISTERED, "with its own named code")


func test_validate_line_id_refuses_a_registered_line_asked_for_another_entry() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var line_id := _field((_block("reply_lines") as Array)[0], "line_id")
	var result: Dictionary = script.call(&"validate_line_id", _entries(), ORDINARY_ENTRIES[1],
		line_id)
	assert_false(result.get("ok", true), "a line belongs to exactly one declared home")
	assert_eq(result.get("code"), CODE_LINE_ID_NOT_OWNED, "with its own named code")


func test_validate_line_id_refuses_an_unknown_entry() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var line_id := _field((_block("reply_lines") as Array)[0], "line_id")
	var result: Dictionary = script.call(&"validate_line_id", _entries(),
		"contact.ordinary.lavinia.day8", line_id)
	assert_false(result.get("ok", true), "an unregistered entry cannot own anything")
	assert_eq(result.get("code"), CODE_LINE_ID_UNKNOWN_ENTRY, "with its own named code")


# --------------------------------------------------------------------------------------------
# validate_atom_id. DEVIATION-4 Ruling C: owner OR presentation site, and the success value says
# which. RULING B: no string prefix may ever be required.
# --------------------------------------------------------------------------------------------

func test_validate_atom_id_accepts_every_registered_atom_for_its_declared_owner() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var checked := 0
	for record: Variant in _block("atoms"):
		var atom_id := _field(record, "atom_id")
		var owner := _field(record, "owning_entry_id")
		var result: Dictionary = script.call(&"validate_atom_id", _entries(), owner, atom_id)
		assert_true(result.get("ok", false),
			"%s resolves for its declared owner %s: %s"
			% [atom_id, owner, str(result.get("message", ""))])
		if not result.get("ok", false):
			continue
		assert_eq((result["value"] as Dictionary).get("match"), "owner",
			"%s: the success value reports the owner relation" % atom_id)
		assert_eq((result["value"] as Dictionary).get("kind"), _field(record, "kind"),
			"%s: and carries the registered kind" % atom_id)
		checked += 1
	assert_eq(checked, EXPECTED_ATOM_COUNT, "all twenty-two resolved through their declared home")


func test_validate_atom_id_accepts_a_fallback_atom_at_its_presentation_site() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var checked := 0
	for record: Variant in _block("atoms"):
		if _field(record, "kind") != "echo_fallback":
			continue
		var atom_id := _field(record, "atom_id")
		var result: Dictionary = script.call(&"validate_atom_id", _entries(),
			ECHO_FALLBACK_ENTRY, atom_id)
		assert_true(result.get("ok", false),
			"%s is presentable in the Day 7 fallback: %s"
			% [atom_id, str(result.get("message", ""))])
		if not result.get("ok", false):
			continue
		assert_eq((result["value"] as Dictionary).get("match"), "presentation_site",
			"%s: the success value reports the presentation relation" % atom_id)
		checked += 1
	assert_eq(checked, EXPECTED_ECHO_ATOM_COUNT, "all eighteen resolved at the fallback")


func test_validate_atom_id_refuses_an_entry_that_neither_owns_nor_presents_it() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var result: Dictionary = script.call(&"validate_atom_id", _entries(), ORDINARY_ENTRIES[1],
		"atom.echo.lavinia.day1.reply.a.fallback.day7")
	assert_false(result.get("ok", true), "a third entry has no claim on the atom")
	assert_eq(result.get("code"), CODE_ATOM_ID_NOT_PRESENTABLE, "with its own named code")


func test_validate_atom_id_refuses_an_unregistered_atom_id() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var result: Dictionary = script.call(&"validate_atom_id", _entries(), ECHO_FALLBACK_ENTRY,
		"atom.echo.lavinia.day1.reply.d.fallback.day7")
	assert_false(result.get("ok", true), "an atom nobody registered fails closed")
	assert_eq(result.get("code"), CODE_ATOM_ID_UNREGISTERED, "with its own named code")


func test_validate_atom_id_refuses_an_unknown_entry() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var result: Dictionary = script.call(&"validate_atom_id", _entries(), "echo.fallback.day8",
		"atom.echo.lavinia.day1.reply.a.fallback.day7")
	assert_false(result.get("ok", true), "an unregistered entry cannot present anything")
	assert_eq(result.get("code"), CODE_ATOM_ID_UNKNOWN_ENTRY, "with its own named code")


# --------------------------------------------------------------------------------------------
# validate_signal. It composes the laws above; it does not restate them.
# --------------------------------------------------------------------------------------------

func _payload(signal_id: String, overrides: Dictionary) -> Dictionary:
	var base: Dictionary = {
		"entry_id": ORDINARY_ENTRIES[0],
		"playback_token": "playback-0001",
		"receipt_id": "receipt-0001",
	}
	match signal_id:
		"message.reply.commit":
			base["reply_id"] = "reply.ordinary.lavinia.day1.a"
			base["witnessed_line_id"] = "line.contact.ordinary.lavinia.day1.reply.a"
		"history.line.witness":
			base["line_id"] = "line.contact.ordinary.lavinia.day1.reply.a"
		"message.echo.satisfy":
			base["entry_id"] = ECHO_FALLBACK_ENTRY
			base["echo_id"] = "echo.lavinia.day1.reply.a"
			base["presentation_atom_id"] = "atom.echo.lavinia.day1.reply.a.fallback.day7"
		"observer.evidence.commit":
			base["evidence_id"] = "evidence.priscilla.day5.gesture"
			base["presentation_atom_id"] = "atom.pair.day2.group.full"
		"pair.combination.witness":
			base["entry_id"] = PAIR_POST_BOARD_ENTRIES[0]
			base["combination_id"] = "combination.priscilla_lavinia.perfect"
			base["presentation_atom_id"] = "atom.pair.day2.group.full"
	for key: Variant in overrides:
		if overrides[key] == null:
			base.erase(str(key))
		else:
			base[str(key)] = overrides[key]
	return base


func _call_signal(signal_id: String, stage: StringName, overrides: Dictionary) -> Dictionary:
	var script := _manifest_script()
	if script == null:
		return {}
	var payload := _payload(signal_id, overrides)
	return script.call(&"validate_signal", _entries(), str(payload.get("entry_id", "")), stage,
		signal_id, payload)


func test_validate_signal_accepts_every_signal_a_production_entry_really_grants() -> void:
	if not _guard():
		return
	var rows: Array = [
		["message.reply.commit", &"awaiting_reply"],
		["history.line.witness", &"current_entry"],
		["message.echo.satisfy", &"current_entry"],
		["pair.combination.witness", &"after_full_observation_atom"],
	]
	for row: Array in rows:
		var result := _call_signal(str(row[0]), row[1], {})
		assert_true(result.get("ok", false),
			"%s is accepted at %s: %s"
			% [str(row[0]), str(row[1]), str(result.get("message", ""))])
		if not result.get("ok", false):
			continue
		assert_eq((result["value"] as Dictionary).get("signal_id"), str(row[0]),
			"the success value names the signal")
		assert_eq((result["value"] as Dictionary).get("stage"), str(row[1]),
			"and the source stage it was accepted at")


## The plan holds production Observer evidence capabilities absent until an approved content card
## supplies an exact source entry and atom, so no registered entry grants this signal and every
## emission is refused by name.
func test_validate_signal_refuses_observer_evidence_from_every_registered_entry() -> void:
	if not _guard():
		return
	var entries: Variant = _entries_document().get("entries", [])
	if not (entries is Array):
		return
	var script := _manifest_script()
	var refused := 0
	for record: Variant in (entries as Array):
		var entry_id := _field(record, "entry_id")
		var payload := _payload("observer.evidence.commit", {"entry_id": entry_id})
		var result: Dictionary = script.call(&"validate_signal", _entries(), entry_id,
			&"registered_dating_scene_action", "observer.evidence.commit", payload)
		assert_false(result.get("ok", true), "%s may not commit Observer evidence" % entry_id)
		assert_eq(result.get("code"), CODE_SIGNAL_NOT_GRANTED, "%s: by name" % entry_id)
		refused += 1
	assert_eq(refused, 137, "all one hundred and thirty-seven entries were asked and refused")


func test_validate_signal_refuses_a_payload_that_names_another_entry() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var payload := _payload("history.line.witness", {"entry_id": ORDINARY_ENTRIES[1]})
	var result: Dictionary = script.call(&"validate_signal", _entries(), ORDINARY_ENTRIES[0],
		&"current_entry", "history.line.witness", payload)
	assert_false(result.get("ok", true), "the payload may not name a different entry")
	assert_eq(result.get("code"), CODE_SIGNAL_ENTRY_MISMATCH, "with its own named code")


func test_validate_signal_refuses_an_unknown_signal_id() -> void:
	if not _guard():
		return
	var result := _call_signal("message.reply.undo", &"awaiting_reply", {})
	assert_false(result.get("ok", true), "an unregistered signal id fails closed")
	assert_eq(result.get("code"), CODE_SIGNAL_UNKNOWN_SIGNAL, "with its own named code")


func test_validate_signal_refuses_an_unknown_entry() -> void:
	if not _guard():
		return
	var result := _call_signal("history.line.witness", &"current_entry",
		{"entry_id": "contact.ordinary.lavinia.day8"})
	assert_false(result.get("ok", true), "an unregistered entry emits nothing")
	assert_eq(result.get("code"), CODE_SIGNAL_UNKNOWN_ENTRY, "with its own named code")


func test_validate_signal_refuses_a_signal_the_entry_does_not_grant() -> void:
	if not _guard():
		return
	var result := _call_signal("message.reply.commit", &"awaiting_reply",
		{"entry_id": ECHO_FALLBACK_ENTRY})
	assert_false(result.get("ok", true), "the Day 7 fallback commits no ordinary reply")
	assert_eq(result.get("code"), CODE_SIGNAL_NOT_GRANTED, "with its own named code")


func test_validate_signal_refuses_a_stage_the_signal_does_not_allow() -> void:
	if not _guard():
		return
	var result := _call_signal("message.reply.commit", &"current_entry", {})
	assert_false(result.get("ok", true), "12.8 commits an ordinary reply only while awaiting one")
	assert_eq(result.get("code"), CODE_SIGNAL_STAGE_NOT_ALLOWED, "with its own named code")


func test_validate_signal_refuses_a_stage_outside_the_declared_vocabulary() -> void:
	if not _guard():
		return
	var result := _call_signal("history.line.witness", &"whenever_convenient", {})
	assert_false(result.get("ok", true), "a stage nobody declared is refused")
	assert_eq(result.get("code"), CODE_SIGNAL_STAGE_NOT_ALLOWED, "with its own named code")


func test_validate_signal_refuses_a_missing_payload_field() -> void:
	if not _guard():
		return
	var result := _call_signal("history.line.witness", &"current_entry", {"receipt_id": null})
	assert_false(result.get("ok", true), "12.8 payloads reject a missing field")
	assert_eq(result.get("code"), CODE_SIGNAL_PAYLOAD_FIELD_MISSING, "with its own named code")


func test_validate_signal_refuses_an_extra_payload_field() -> void:
	if not _guard():
		return
	var result := _call_signal("history.line.witness", &"current_entry",
		{"relationship_delta": 3})
	assert_false(result.get("ok", true), "12.8 payloads reject an extra field")
	assert_eq(result.get("code"), CODE_SIGNAL_PAYLOAD_FIELD_UNKNOWN,
		"with a code distinguishable from a missing one")


func test_validate_signal_refuses_a_reply_id_owned_by_another_entry() -> void:
	if not _guard():
		return
	var result := _call_signal("message.reply.commit", &"awaiting_reply",
		{"reply_id": "reply.ordinary.sylvia.day2.a"})
	assert_false(result.get("ok", true), "a reply belongs to exactly one ordinary entry")
	assert_eq(result.get("code"), CODE_SIGNAL_REPLY_ID_INVALID, "with its own named code")


func test_validate_signal_refuses_an_unregistered_reply_id() -> void:
	if not _guard():
		return
	var result := _call_signal("message.reply.commit", &"awaiting_reply",
		{"reply_id": "reply.ordinary.lavinia.day1.d"})
	assert_false(result.get("ok", true), "an unregistered reply fails closed")
	assert_eq(result.get("code"), CODE_SIGNAL_REPLY_ID_INVALID, "with its own named code")


func test_validate_signal_refuses_an_echo_id_that_is_not_the_registered_partner() -> void:
	if not _guard():
		return
	var result := _call_signal("message.echo.satisfy", &"current_entry",
		{"echo_id": "echo.lavinia.day1.reply.b"})
	assert_false(result.get("ok", true), "9.3 binds one echo id to one presentation atom")
	assert_eq(result.get("code"), CODE_SIGNAL_ECHO_BINDING_INVALID, "with its own named code")


func test_validate_signal_delegates_a_bad_line_id_to_validate_line_id() -> void:
	if not _guard():
		return
	var result := _call_signal("history.line.witness", &"current_entry",
		{"line_id": "line.contact.ordinary.lavinia.day1.reply.z"})
	assert_false(result.get("ok", true), "an unregistered witnessed line fails closed")
	assert_eq(result.get("code"), CODE_LINE_ID_UNREGISTERED,
		"and reports the delegated code rather than inventing a second one")


func test_validate_signal_delegates_a_bad_witnessed_line_id_to_validate_line_id() -> void:
	if not _guard():
		return
	var result := _call_signal("message.reply.commit", &"awaiting_reply",
		{"witnessed_line_id": "line.contact.ordinary.sylvia.day2.reply.a"})
	assert_false(result.get("ok", true), "a reply witnesses a line of its own entry")
	assert_eq(result.get("code"), CODE_LINE_ID_NOT_OWNED, "delegated by name")


func test_validate_signal_delegates_a_bad_atom_id_to_validate_atom_id() -> void:
	if not _guard():
		return
	var result := _call_signal("message.echo.satisfy", &"current_entry",
		{"presentation_atom_id": "atom.pair.day2.group.full"})
	assert_false(result.get("ok", true), "a pair atom is not presentable in the Day 7 fallback")
	assert_eq(result.get("code"), CODE_ATOM_ID_NOT_PRESENTABLE, "delegated by name")


## 12.8 gives playback_token and receipt_id no vocabulary at all: the bridge mints one token per
## entry and the state owner mints one receipt per command, both at runtime. evidence_id and
## combination_id have no approved content card yet. This suite therefore asserts only what the
## contract can honestly promise for all four, a non-empty string, and says so rather than
## pretending to a registry lookup that does not exist. The observer.evidence.commit case cannot be
## reached at all, because no registered entry grants that signal, so evidence_id is UNCOVERED here.
func test_validate_signal_refuses_an_empty_opaque_payload_field() -> void:
	if not _guard():
		return
	var rows: Array = [
		["history.line.witness", &"current_entry", "playback_token"],
		["history.line.witness", &"current_entry", "receipt_id"],
		["pair.combination.witness", &"after_full_observation_atom", "combination_id"],
	]
	for row: Array in rows:
		var field_name: String = str(row[2])
		assert_true(OPAQUE_PAYLOAD_FIELDS.has(field_name),
			"%s is one of the four fields with no registry in this phase" % field_name)
		var result := _call_signal(str(row[0]), row[1], {field_name: ""})
		assert_false(result.get("ok", true), "%s: an empty opaque field is refused" % field_name)
		assert_eq(result.get("code"), CODE_SIGNAL_OPAQUE_FIELD_INVALID,
			"%s: by name" % field_name)


# --------------------------------------------------------------------------------------------
# resolve_entry: the one 2A behaviour change this sub-commit makes.
# --------------------------------------------------------------------------------------------

func test_resolve_entry_refuses_each_retired_label_by_its_own_name() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	for label_id: Variant in RETIRED_LABEL_IDS:
		var result: Dictionary = script.call(&"resolve_entry", _entries(), str(label_id), "en")
		assert_false(result.get("ok", true), "%s was retired and starts nothing" % str(label_id))
		assert_eq(result.get("code"), CODE_RETIRED_ENTRY,
			"%s: a legacy label from a save is refused by name, not as a generic stranger"
			% str(label_id))


func test_resolve_entry_still_refuses_an_unregistered_entry_generically() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var result: Dictionary = script.call(&"resolve_entry", _entries(),
		"ending.priscilla.mythical", "en")
	assert_false(result.get("ok", true), "an entry nobody registered fails closed")
	assert_eq(result.get("code"), &"ENTRY_MANIFEST_UNKNOWN_ENTRY",
		"and the retired code is reserved for the three labels Task 1 froze")


func test_no_retired_label_is_also_a_registered_entry() -> void:
	if not _guard():
		return
	for label_id: Variant in RETIRED_LABEL_IDS:
		assert_true(_entry_record(str(label_id)).is_empty(),
			"%s: a retired label may never reappear as a callable entry" % str(label_id))


func test_every_declared_ids_failure_code_exists_in_the_production_source() -> void:
	assert_true(FileAccess.file_exists(SCRIPT_PATH), "expected RED: missing " + SCRIPT_PATH)
	if not FileAccess.file_exists(SCRIPT_PATH):
		return
	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	for code: StringName in ALL_IDS_FAILURE_CODES:
		assert_true(source.contains("&\"" + str(code) + "\""),
			"%s: the production source still declares this exact failure code" % str(code))
