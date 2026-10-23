# True-Observation Postscript Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the orphaned `.true` endings into true-observation postscript ids (`ending.{priscilla,lavinia}.observation`), retire `sylvia.true`, migrate legacy unlocks, and add the pure conjunctive gate resolver.

**Architecture:** `.true` → `.observation` is a data rename across the ending-id lists (`DatingEndingRules`, `ProfileSchema`, `GalleryScene`) plus the migration maps (`SaveMigrations`, `ProfileMigration`), guarded by the immutable localization fingerprint (which we leave untouched — we ADD `.observation` titles, keep the frozen `.true` titles). The gate is a pure `DatingEndingRules.resolve_postscript`.

**Tech Stack:** Godot 4.6.3 GDScript (strict typed), GUT, `Invoke-IsolatedGodot.ps1`, `Invoke-ExactPathCommit.ps1`.

## Global Constraints

- Postscript ids: `ending.priscilla.observation`, `ending.lavinia.observation`. `ending.sylvia.true` retired; legacy `sylvia.true` migrates to `ending.sylvia.special`.
- Postscript ids are canonical but NOT primaries (in `CANONICAL_ENDING_IDS`, not `VALID_PRIMARY_IDS`).
- The immutable localization fingerprint (`evidence/phase_2r/localization/legacy_subset_fingerprint.json`) is NEVER edited; the frozen `.true` title records stay in the catalog.
- Priscilla–Lavinia postscript and audio-track rename are OUT of scope (deferred to the playback pass).
- Run suites via `Invoke-IsolatedGodot.ps1`; commit via `Invoke-ExactPathCommit.ps1` (get head with `git rev-parse HEAD`); commit messages quote-free.

---

### Task 1: DatingEndingRules — postscript ids + pure gate resolver

**Files:**
- Modify: `scripts/domain/ending/DatingEndingRules.gd`
- Test: `tests/unit/test_dating_ending_rules.gd`

**Interfaces:**
- Consumes: existing `_keys_match(value, expected)` helper.
- Produces: `const POSTSCRIPT_IDS: Array[String]`; `CANONICAL_ENDING_IDS` with `.observation` (no `.true`); `static func resolve_postscript(input: Dictionary) -> Dictionary` returning `{ok: true, code: &"ok", value: {unlocked_ids: Array}}` or `{ok: false, code: &"invalid_postscript_input", message}`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_dating_ending_rules.gd`:

```gdscript

# ---- True-observation postscript (story/05 sec 1/3) ----
func _postscript_input(p_board: bool, p_obs: bool, l_board: bool, l_obs: bool) -> Dictionary:
	return {
		"priscilla": {"board_mastery": p_board, "observer_behaviour": p_obs},
		"lavinia": {"board_mastery": l_board, "observer_behaviour": l_obs},
	}

func test_postscript_ids_are_canonical_but_not_primary() -> void:
	var rules: Script = load(RULES_PATH)
	for pid: String in ["ending.priscilla.observation", "ending.lavinia.observation"]:
		assert_true(pid in rules.POSTSCRIPT_IDS, pid + " is a postscript")
		assert_true(pid in rules.CANONICAL_ENDING_IDS, pid + " is canonical")
		assert_false(pid in rules.VALID_PRIMARY_IDS, pid + " is never a primary")
	assert_false("ending.priscilla.true" in rules.CANONICAL_ENDING_IDS, "retired .true is gone")
	assert_false("ending.sylvia.true" in rules.CANONICAL_ENDING_IDS, "sylvia.true is retired")

func test_resolve_postscript_requires_both_halves() -> void:
	var rules: Script = load(RULES_PATH)
	assert_eq(rules.resolve_postscript(_postscript_input(true, true, false, false))["value"]["unlocked_ids"],
		["ending.priscilla.observation"], "priscilla with both halves unlocks; lavinia with neither does not")
	assert_eq(rules.resolve_postscript(_postscript_input(true, false, false, true))["value"]["unlocked_ids"],
		[], "either half alone never qualifies")
	assert_eq(rules.resolve_postscript(_postscript_input(true, true, true, true))["value"]["unlocked_ids"],
		["ending.lavinia.observation", "ending.priscilla.observation"], "both pairings, sorted")

func test_resolve_postscript_rejects_malformed_input() -> void:
	var rules: Script = load(RULES_PATH)
	assert_false(rules.resolve_postscript({"priscilla": {"board_mastery": true, "observer_behaviour": true}}).get("ok", true),
		"both pairing keys are required")
	assert_false(rules.resolve_postscript(_postscript_input(true, true, true, true) if false else {
		"priscilla": {"board_mastery": "yes", "observer_behaviour": true},
		"lavinia": {"board_mastery": true, "observer_behaviour": true},
	}).get("ok", true), "signals must be booleans")
```

- [ ] **Step 2: Run to verify failure**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'test_dating_ending_rules' -LogName 'ps-t1-red' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_dating_ending_rules.gd','-gexit')
```
Expected: FAIL — `POSTSCRIPT_IDS`/`resolve_postscript` do not exist, and `.true` is still in `CANONICAL_ENDING_IDS`.

- [ ] **Step 3: Swap the id lists and add the resolver**

In `scripts/domain/ending/DatingEndingRules.gd`, in `CANONICAL_ENDING_IDS`, replace the line
`	"ending.sylvia.sweet", "ending.sylvia.dark", "ending.sylvia.true",` and the two `.true` occurrences so the constant reads exactly:

```gdscript
const CANONICAL_ENDING_IDS: Array[String] = [
	"ending.alone",
	"ending.priscilla.sweet", "ending.priscilla.dark", "ending.priscilla.observation",
	"ending.lavinia.sweet", "ending.lavinia.dark", "ending.lavinia.observation",
	"ending.sylvia.sweet", "ending.sylvia.dark",
	"ending.sylvia.special", "ending.priscilla_lavinia",
]
const POSTSCRIPT_IDS: Array[String] = ["ending.lavinia.observation", "ending.priscilla.observation"]
```

Then add the resolver (place it after `resolve_epilogue`):

```gdscript

## Conjunctive true-observation postscript gate (story/05 sec 1/3): per pairing, the observation
## postscript unlocks iff board mastery AND observer behaviour. Sylvia is Special-only (never here);
## the Priscilla-Lavinia postscript is deferred. Pure; never mutates the input.
static func resolve_postscript(input: Dictionary) -> Dictionary:
	if not _keys_match(input, ["lavinia", "priscilla"]):
		return {"ok": false, "code": &"invalid_postscript_input", "message": "keys must be exactly [lavinia, priscilla]"}
	var unlocked: Array[String] = []
	for friend: String in ["lavinia", "priscilla"]:
		var pairing: Variant = input[friend]
		if typeof(pairing) != TYPE_DICTIONARY or not _keys_match(pairing, ["board_mastery", "observer_behaviour"]):
			return {"ok": false, "code": &"invalid_postscript_input", "message": friend + " needs board_mastery and observer_behaviour"}
		if typeof(pairing["board_mastery"]) != TYPE_BOOL or typeof(pairing["observer_behaviour"]) != TYPE_BOOL:
			return {"ok": false, "code": &"invalid_postscript_input", "message": friend + " signals must be booleans"}
		if pairing["board_mastery"] and pairing["observer_behaviour"]:
			unlocked.append("ending.%s.observation" % friend)
	unlocked.sort()
	return {"ok": true, "code": &"ok", "value": {"unlocked_ids": unlocked}}
```

- [ ] **Step 4: Run to verify pass**

Run the same command as Step 2 (LogName `ps-t1-green`). Expected: PASS — the new tests pass. NOTE: pre-existing tests in this suite that referenced `ending.*.true` as canonical will now fail; if any do, they are asserting the retired ids and must be updated to `.observation` (or removed if they asserted `.true` validity) as part of this step, then re-run to green.

- [ ] **Step 5: Commit**

```powershell
$head = git rev-parse HEAD
.\tools\git\Invoke-ExactPathCommit.ps1 -ExpectedHead $head -RequiredStatus @{ 'scripts/domain/ending/DatingEndingRules.gd' = 'M'; 'tests/unit/test_dating_ending_rules.gd' = 'M' } -Message 'feat(endings): register observation postscript ids and add resolve_postscript gate (dwm-p2r.7)'
```

---

### Task 2: ProfileSchema + GalleryScene id lists

**Files:**
- Modify: `scripts/profile/ProfileSchema.gd`
- Modify: `scripts/ui/GalleryScene.gd`
- Test: `tests/unit/test_profile_manager.gd`

**Interfaces:**
- Consumes: `DatingEndingRules.CANONICAL_ENDING_IDS` from Task 1 (for parity).
- Produces: `ProfileSchema.ENDING_IDS` and `GalleryScene.ALL_ENDING_IDS` with `.observation` (no `.true`).

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_profile_manager.gd`:

```gdscript
func test_profile_schema_registers_observation_not_true() -> void:
	var schema: Script = load("res://scripts/profile/ProfileSchema.gd")
	assert_true("ending.priscilla.observation" in schema.ENDING_IDS)
	assert_true("ending.lavinia.observation" in schema.ENDING_IDS)
	assert_false("ending.priscilla.true" in schema.ENDING_IDS, "retired .true is gone")
	assert_false("ending.sylvia.true" in schema.ENDING_IDS, "sylvia.true is retired")
```

- [ ] **Step 2: Run to verify failure**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'test_profile_manager' -LogName 'ps-t2-red' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_profile_manager.gd','-gexit')
```
Expected: FAIL — `.true` still present, `.observation` absent.

- [ ] **Step 3: Swap the id lists**

In `scripts/profile/ProfileSchema.gd`, replace the `ENDING_IDS` const body so it reads exactly:

```gdscript
const ENDING_IDS := [
	"ending.alone", "ending.priscilla.sweet", "ending.priscilla.dark", "ending.priscilla.observation",
	"ending.lavinia.sweet", "ending.lavinia.dark", "ending.lavinia.observation",
	"ending.sylvia.sweet", "ending.sylvia.dark", "ending.sylvia.special",
]
```

In `scripts/ui/GalleryScene.gd`, replace the `ALL_ENDING_IDS` const body so it reads exactly:

```gdscript
const ALL_ENDING_IDS := [
	"alone",
	"priscilla.sweet", "priscilla.dark", "priscilla.observation",
	"lavinia.sweet", "lavinia.dark", "lavinia.observation",
	"sylvia.sweet", "sylvia.dark", "sylvia.special",
	"priscilla_lavinia",
]
```

(Note: `GalleryScene` previously omitted `sylvia.special`; adding it fixes a gap while removing the retired `.true` tiles.)

- [ ] **Step 4: Run to verify pass**

Run the same command as Step 2 (LogName `ps-t2-green`). Expected: PASS — the new test passes; pre-existing profile tests that referenced `.true` as a valid ending must be updated to `.observation` and re-run to green.

- [ ] **Step 5: Commit**

```powershell
$head = git rev-parse HEAD
.\tools\git\Invoke-ExactPathCommit.ps1 -ExpectedHead $head -RequiredStatus @{ 'scripts/profile/ProfileSchema.gd' = 'M'; 'scripts/ui/GalleryScene.gd' = 'M'; 'tests/unit/test_profile_manager.gd' = 'M' } -Message 'feat(profile): register observation postscript ids in profile schema and gallery (dwm-p2r.7)'
```

---

### Task 3: SaveMigrations — legacy `.true` ending-id mapping

**Files:**
- Modify: `scripts/infrastructure/save/SaveMigrations.gd`
- Test: `tests/unit/test_save_migrations.gd`

**Interfaces:**
- Produces: `ENDING_ID_MAP` remapping the retired short and full `.true` tokens to `.observation` / `special`; `migrate_ending_id` unchanged in shape.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_save_migrations.gd`:

```gdscript
func test_migrate_retired_true_ending_ids() -> void:
	var m: Script = load("res://scripts/infrastructure/save/SaveMigrations.gd")
	assert_eq(m.migrate_ending_id("priscilla.true")["value"]["ending_id"], "ending.priscilla.observation")
	assert_eq(m.migrate_ending_id("ending.lavinia.true")["value"]["ending_id"], "ending.lavinia.observation")
	assert_eq(m.migrate_ending_id("sylvia.true")["value"]["ending_id"], "ending.sylvia.special")
	assert_eq(m.migrate_ending_id("ending.sylvia.true")["value"]["ending_id"], "ending.sylvia.special")
```

- [ ] **Step 2: Run to verify failure**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'test_save_migrations' -LogName 'ps-t3-red' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_save_migrations.gd','-gexit')
```
Expected: FAIL — the map still points `.true` to `.true`.

- [ ] **Step 3: Update the map**

In `scripts/infrastructure/save/SaveMigrations.gd`, edit `ENDING_ID_MAP`: change the three `.true` values, and add full-form retired keys, so the relevant entries read:

```gdscript
	"priscilla.true": "ending.priscilla.observation",
	"ending.priscilla.true": "ending.priscilla.observation",
	"lavinia.true": "ending.lavinia.observation",
	"ending.lavinia.true": "ending.lavinia.observation",
	"sylvia.true": "ending.sylvia.special",
	"ending.sylvia.true": "ending.sylvia.special",
```

(Keep the existing `alone`/`sweet`/`dark`/`special`/`priscilla_lavinia`/`lavinia_priscilla` entries unchanged.)

- [ ] **Step 4: Run to verify pass**

Run the same command as Step 2 (LogName `ps-t3-green`). Expected: PASS — new tests pass; any pre-existing test asserting `.true` mapping must be updated and re-run to green.

- [ ] **Step 5: Commit**

```powershell
$head = git rev-parse HEAD
.\tools\git\Invoke-ExactPathCommit.ps1 -ExpectedHead $head -RequiredStatus @{ 'scripts/infrastructure/save/SaveMigrations.gd' = 'M'; 'tests/unit/test_save_migrations.gd' = 'M' } -Message 'feat(save): migrate retired .true ending ids to observation/special (dwm-p2r.7)'
```

---

### Task 4: ProfileMigration — remap retired gallery unlocks

**Files:**
- Modify: `scripts/profile/ProfileMigration.gd`
- Test: `tests/unit/test_profile_manager.gd`

**Interfaces:**
- Consumes: `SCHEMA.ENDING_IDS` (updated in Task 2).
- Produces: `prepare_document` remaps retired `.true` ids inside `gallery_unlocks` (union, idempotent) before validating; the legacy `seen_endings` `ending_map` (in `prepare_legacy_patch`) gains the same three retired mappings.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_profile_manager.gd`:

```gdscript
func test_profile_document_remaps_retired_true_gallery_unlocks() -> void:
	var migration: Script = load("res://scripts/profile/ProfileMigration.gd")
	var schema: Script = load("res://scripts/profile/ProfileSchema.gd")
	var raw: Dictionary = schema.make_defaults()
	raw["gallery_unlocks"] = ["ending.priscilla.true", "ending.sylvia.true", "ending.sylvia.special"]
	var result: Dictionary = migration.prepare_document(raw)
	assert_true(result.get("ok", false), str(result))
	var unlocks: Array = result["value"]["gallery_unlocks"]
	assert_true("ending.priscilla.observation" in unlocks, "priscilla.true remapped")
	assert_true("ending.sylvia.special" in unlocks, "sylvia.true remapped to special")
	assert_eq(unlocks.count("ending.sylvia.special"), 1, "special is unioned once, not duplicated")
	assert_false("ending.priscilla.true" in unlocks, "no retired id remains")
```

- [ ] **Step 2: Run to verify failure**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'test_profile_manager' -LogName 'ps-t4-red' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_profile_manager.gd','-gexit')
```
Expected: FAIL — `prepare_document` currently rejects the retired ids (validate fails, no remap).

- [ ] **Step 3: Add the retired-gallery remap**

In `scripts/profile/ProfileMigration.gd`, add a helper and call it at the top of `prepare_document` (before the first `SCHEMA.validate`):

```gdscript
const _RETIRED_ENDING_MAP := {
	"ending.priscilla.true": "ending.priscilla.observation",
	"ending.lavinia.true": "ending.lavinia.observation",
	"ending.sylvia.true": "ending.sylvia.special",
}

static func _remap_retired_gallery_unlocks(document: Dictionary) -> void:
	var unlocks: Variant = document.get("gallery_unlocks")
	if typeof(unlocks) != TYPE_ARRAY:
		return
	var remapped: Array = []
	for entry: Variant in unlocks:
		var id := str(_RETIRED_ENDING_MAP.get(entry, entry))
		if id not in remapped:
			remapped.append(id)
	remapped.sort()
	document["gallery_unlocks"] = remapped
```

Then, inside `prepare_document`, immediately after `var detached := raw.duplicate(true)`, insert:

```gdscript
	_remap_retired_gallery_unlocks(detached)
```

Also, in `prepare_legacy_patch`, extend the `ending_map` so it reads:

```gdscript
	var ending_map := {
		"alone": "ending.alone", "lavinia_priscilla": "ending.priscilla_lavinia",
		"ending.priscilla.true": "ending.priscilla.observation",
		"ending.lavinia.true": "ending.lavinia.observation",
		"ending.sylvia.true": "ending.sylvia.special",
	}
```

- [ ] **Step 4: Run to verify pass**

Run the same command as Step 2 (LogName `ps-t4-green`). Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
$head = git rev-parse HEAD
.\tools\git\Invoke-ExactPathCommit.ps1 -ExpectedHead $head -RequiredStatus @{ 'scripts/profile/ProfileMigration.gd' = 'M'; 'tests/unit/test_profile_manager.gd' = 'M' } -Message 'feat(profile): remap retired .true gallery unlocks to observation/special on load (dwm-p2r.7)'
```

---

### Task 5: Localization titles + full blast-radius

**Files:**
- Modify: `localization/ui/en.json`
- Test: `tests/unit/test_localization_extraction.gd` (must stay green, unchanged)

**Interfaces:**
- Produces: `gallery.ending.priscilla.observation.title` and `gallery.ending.lavinia.observation.title` message records in the English catalog. The frozen `.true` records remain; the fingerprint is untouched.

- [ ] **Step 1: Add the two observation title records**

In `localization/ui/en.json`, add two message objects to the `messages` array (order does not affect validity — the schema keys by id). Insert immediately after the existing `{"id":"gallery.ending.lavinia.true.title","text":"Ending: Lavinia.true"}` object:

```json
,{"id":"gallery.ending.lavinia.observation.title","text":"Ending: Lavinia (Observation)"}
```

and immediately after the existing `{"id":"gallery.ending.priscilla.true.title","text":"Ending: Priscilla.true"}` object:

```json
,{"id":"gallery.ending.priscilla.observation.title","text":"Ending: Priscilla (Observation)"}
```

- [ ] **Step 2: Verify the localization suite stays green**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'test_localization_extraction' -LogName 'ps-t5' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_localization_extraction.gd','-gexit')
```
Expected: PASS — the immutable fingerprint records still resolve (frozen `.true` titles remain), the bundle validates with the two additive records, and the fingerprint file is untouched.

- [ ] **Step 3: Full blast-radius regression run**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ps-blast' -LogName 'ps-blast' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_dating_ending_rules.gd,res://tests/unit/test_dating_ending_rules_migration.gd,res://tests/unit/test_profile_manager.gd,res://tests/unit/test_save_migrations.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_game_state.gd','-gexit')
```
Expected: PASS — "All tests passed!" across endings, profile, migration, snapshot, and game_state. Fix any test that still asserts a retired `.true` id (update to `.observation`/`special`) and re-run to green before committing.

- [ ] **Step 4: Commit**

```powershell
$head = git rev-parse HEAD
.\tools\git\Invoke-ExactPathCommit.ps1 -ExpectedHead $head -RequiredStatus @{ 'localization/ui/en.json' = 'M' } -Message 'feat(localization): add observation postscript gallery titles (dwm-p2r.7)'
```

---

## Notes for the implementer

- **Immutable fingerprint:** never edit `legacy_subset_fingerprint.json` or remove the frozen `.true` title records — the additive `.observation` titles keep `test_localization_extraction` green.
- **Retired-id test sweep:** removing `.true` from the id lists will break any pre-existing test that asserted `.true` was canonical/valid/migratable. Those assertions are now wrong; update them to `.observation` (or `special` for sylvia). The blast-radius run in Task 5 is the safety net.
- **Deferred (do NOT touch):** `AudioManifest` `.true` tracks, the Priscilla–Lavinia postscript, postscript playback in the ending sequence, and wiring real board-mastery/observer signals — all later (`.8` / mechanics) work.
```
