# Schedule Validation Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `ScheduleRules` the single source of truth for the schedule date rules by adding a pure `validate_date_candidate` and delegating GameState's `_can_add_date_entry` to it, correcting a latent validate-time bug in the process.

**Architecture:** A new pure static function `ScheduleRules.validate_date_candidate(existing, candidate, day)` encodes the three date rules (too-many, Day-4 Priscilla-first, duplicate-friend) over the loose live date shape. GameState's `_can_add_date_entry` delegates to it, passing `existing` = the schedule with the candidate excluded by identity (`is_same`). Behaviour is preserved at add-time and corrected at validate-time (a full, legal 2-date week no longer self-reports invalid).

**Tech Stack:** Godot 4.6.3, GDScript (strict typed), GUT test framework, `Invoke-IsolatedGodot.ps1` isolated test runner, `Invoke-ExactPathCommit.ps1` for commits.

## Global Constraints

- GDScript strict typing throughout; `ScheduleRules` functions are `static`.
- `ScheduleRules` is a pure `RefCounted`; it never reads GameState. Reach it from GameState via a `preload` const (a `class_name` global does not resolve in autoload scope).
- Loose entry shape is kept — no `slot_index`/`unlock_receipt_id`/persistence changes. Day-7 candidate validation and the full `validate_candidate` stay untouched (deferred to `.8` / dwm-7e6).
- `twofriends` is never routed through `ScheduleRules` (it stays an early `return true` bypass in `_can_add_date_entry`).
- Run every suite with `.\tools\testing\Invoke-IsolatedGodot.ps1`; never launch Godot directly.
- Commit with `.\tools\git\Invoke-ExactPathCommit.ps1` (obtain the head first via `git rev-parse HEAD`); keep commit messages quote-free.

---

### Task 1: Pure `ScheduleRules.validate_date_candidate`

**Files:**
- Modify: `scripts/domain/schedule/ScheduleRules.gd`
- Test: `tests/unit/test_schedule_rules_phase2r.gd`

**Interfaces:**
- Consumes: existing `ScheduleRules` helpers `max_dates_for_day(day)`, `_same_friend_set(left, right)`, `_fail(code, message)`, and the `DATE_TYPES` const.
- Produces: `static func validate_date_candidate(existing: Array, candidate: Dictionary, day: int) -> Dictionary` returning `{ok: true, code: &"ok"}` or `{ok: false, code}` where `code` is one of `&"not_a_date"`, `&"priscilla_first_slot_required"`, `&"duplicate_friend_date"`, `&"too_many_dates"`. Also `static func _friend_set(entry: Dictionary) -> Array`.

- [ ] **Step 1: Write the failing pure tests**

Append to `tests/unit/test_schedule_rules_phase2r.gd`:

```gdscript

# ---- validate_date_candidate: the loose-shape date rules (dwm-p2r.7 Task 4) ----
func _loose_solo(friend_id: String) -> Dictionary:
	return {"type": "solo", "friend_id": friend_id, "friend_ids": [friend_id]}

func _loose_group(a: String, b: String) -> Dictionary:
	return {"type": "group", "friend_ids": [a, b]}

func test_validate_date_candidate_accepts_a_distinct_friend() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_true(rules.validate_date_candidate([_loose_solo("priscilla")], _loose_solo("lavinia"), 3).get("ok", false),
		"a distinct-friend date is addable")

func test_validate_date_candidate_rejects_a_duplicate_friend() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([_loose_solo("priscilla")], _loose_solo("priscilla"), 3).get("code"),
		&"duplicate_friend_date")

func test_validate_date_candidate_rejects_a_duplicate_group_pair_any_order() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([_loose_group("priscilla", "lavinia")], _loose_group("lavinia", "priscilla"), 3).get("code"),
		&"duplicate_friend_date", "the same pair in any order is a duplicate")

func test_validate_date_candidate_enforces_the_two_date_max() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([_loose_solo("priscilla"), _loose_solo("lavinia")], _loose_solo("sylvia"), 3).get("code"),
		&"too_many_dates", "days 1-6 allow two dates")

func test_validate_date_candidate_day4_seats_priscilla_first() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([_loose_solo("lavinia")], _loose_solo("priscilla"), 4).get("code"),
		&"priscilla_first_slot_required", "Day 4 Priscilla cannot follow another entry")
	assert_true(rules.validate_date_candidate([], _loose_solo("priscilla"), 4).get("ok", false),
		"Priscilla first on an empty schedule is fine")

func test_validate_date_candidate_reads_a_minimal_friend_id_candidate() -> void:
	# GameState.can_add_schedule_action passes {type, friend_id} with no friend_ids.
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([_loose_solo("priscilla")], {"type": "solo", "friend_id": "priscilla"}, 3).get("code"),
		&"duplicate_friend_date", "a {type, friend_id} candidate still resolves its friend")

func test_validate_date_candidate_rejects_a_non_date_type() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([], {"type": "training"}, 3).get("code"), &"not_a_date")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'test_schedule_rules_phase2r' -LogName 'sched-t1-red' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_rules_phase2r.gd','-gexit')
```
Then read the tail of `.godot/phase2r_logs/sched-t1-red`.
Expected: FAIL — the seven new tests error/fail because `validate_date_candidate` does not exist yet (the pre-existing `test_schedule_rules_phase2r` tests still pass).

- [ ] **Step 3: Implement `validate_date_candidate` and `_friend_set`**

In `scripts/domain/schedule/ScheduleRules.gd`, immediately after the `validate_candidate` function (before `static func _same_friend_set`), insert:

```gdscript

## Pure add-time validation of one date candidate against the OTHER entries already scheduled
## (the caller excludes the candidate from `existing`). Loose date shape: `type` in DATE_TYPES;
## friends from `friend_ids`, or `friend_id` for the minimal {type, friend_id} candidate GameState
## builds. Returns a specific reason code so a Done warning can render a helpful message.
## twofriends is never routed here.
static func validate_date_candidate(existing: Array, candidate: Dictionary, day: int) -> Dictionary:
	var candidate_type := str(candidate.get("type", ""))
	if candidate_type not in DATE_TYPES:
		return _fail(&"not_a_date", "validate_date_candidate handles only " + str(DATE_TYPES))
	var candidate_friends := _friend_set(candidate)
	# Day 4 seats Priscilla first: a solo Priscilla date cannot follow another entry.
	if day == 4 and candidate_type == "solo" and "priscilla" in candidate_friends and not existing.is_empty():
		return _fail(&"priscilla_first_slot_required", "Day 4 seats Priscilla first")
	# One date per friend (solo) / per pair (group) each day; then the daily date cap.
	var date_count: int = 0
	for entry: Dictionary in existing:
		if str(entry.get("type", "")) not in DATE_TYPES:
			continue
		date_count += 1
		if str(entry.get("type", "")) == candidate_type and _same_friend_set(_friend_set(entry), candidate_friends):
			return _fail(&"duplicate_friend_date", str(candidate_friends))
	if date_count >= max_dates_for_day(day):
		return _fail(&"too_many_dates", "day %d allows %d date(s)" % [day, max_dates_for_day(day)])
	return {"ok": true, "code": &"ok"}

static func _friend_set(entry: Dictionary) -> Array:
	var ids: Array = entry.get("friend_ids", [])
	if not ids.is_empty():
		return ids
	var single := str(entry.get("friend_id", ""))
	return [single] if not single.is_empty() else []
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'test_schedule_rules_phase2r' -LogName 'sched-t1-green' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_rules_phase2r.gd','-gexit')
```
Expected: PASS — "All tests passed!" with the seven new tests and every pre-existing test green.

- [ ] **Step 5: Commit**

```powershell
$head = git rev-parse HEAD
.\tools\git\Invoke-ExactPathCommit.ps1 -ExpectedHead $head -RequiredStatus @{ 'scripts/domain/schedule/ScheduleRules.gd' = 'M'; 'tests/unit/test_schedule_rules_phase2r.gd' = 'M' } -Message 'feat(schedule): add pure ScheduleRules.validate_date_candidate (dwm-p2r.7 Task 4)'
```

---

### Task 2: Characterize GameState's current date-validation

**Files:**
- Test: `tests/unit/test_schedule_rules.gd`

**Interfaces:**
- Consumes: `GameState.build_date_entry_from_unlock(friend_id)`, `GameState._can_add_date_entry(entry)`, `GameState.validate_schedule()`, `GameState.schedule_entries`. `before_each` already calls `GameState.reset_game()` (day resets to 1; the daily date cap is 2).
- Produces: three characterization tests pinning current behaviour, including the latent full-week bug that Task 3 corrects.

- [ ] **Step 1: Write the characterization tests (they pass against current code)**

Append to `tests/unit/test_schedule_rules.gd`:

```gdscript

# ---- Date-path characterization (dwm-p2r.7 Task 4): pins CURRENT behaviour before delegation ----
func test_char_add_time_duplicate_and_distinct_friend() -> void:
	GameState.schedule_entries = [GameState.build_date_entry_from_unlock("priscilla")]
	assert_false(GameState._can_add_date_entry(GameState.build_date_entry_from_unlock("priscilla")),
		"a second date for the same friend is not addable")
	assert_true(GameState._can_add_date_entry(GameState.build_date_entry_from_unlock("lavinia")),
		"a date for a distinct friend is addable")

func test_char_three_dates_exceed_the_day_allowance() -> void:
	GameState.schedule_entries = [
		GameState.build_date_entry_from_unlock("priscilla"),
		GameState.build_date_entry_from_unlock("lavinia"),
		GameState.build_date_entry_from_unlock("sylvia"),
	]
	assert_eq(GameState.validate_schedule(), {"ok": false, "reason": "too_many_dates"},
		"three dates exceed the day-1 allowance")

func test_char_full_two_date_week_currently_self_reports_invalid() -> void:
	# LATENT BUG documented: the add-time guard, reused at validate-time, double-counts, so a full,
	# legal 2-date week self-reports invalid_date. Task 3's delegation corrects this to valid.
	GameState.schedule_entries = [
		GameState.build_date_entry_from_unlock("priscilla"),
		GameState.build_date_entry_from_unlock("lavinia"),
	]
	assert_eq(GameState.validate_schedule(), {"ok": false, "reason": "invalid_date"},
		"pre-delegation: a full valid 2-date week self-reports invalid_date")
```

- [ ] **Step 2: Run the suite to verify the characterization passes**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'test_schedule_rules' -LogName 'sched-t2' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_rules.gd','-gexit')
```
Expected: PASS — "All tests passed!" The three new tests pass, documenting current behaviour (including `invalid_date` for a full 2-date week).

- [ ] **Step 3: Commit**

```powershell
$head = git rev-parse HEAD
.\tools\git\Invoke-ExactPathCommit.ps1 -ExpectedHead $head -RequiredStatus @{ 'tests/unit/test_schedule_rules.gd' = 'M' } -Message 'test(schedule): characterize the date-validation path incl the latent full-week bug (dwm-p2r.7 Task 4)'
```

---

### Task 3: Delegate `_can_add_date_entry` and correct the bug

**Files:**
- Modify: `autoload/GameState.gd`
- Test: `tests/unit/test_schedule_rules.gd`

**Interfaces:**
- Consumes: `ScheduleRules.validate_date_candidate(existing, candidate, day)` from Task 1; the `GameState.day` property; the global `is_same(a, b)` identity check.
- Produces: a `_SCHEDULE_RULES` preload const and a `_can_add_date_entry` that delegates. No signature change (`_can_add_date_entry(entry: Dictionary, silent: bool = false) -> bool`).

- [ ] **Step 1: Update the characterization to the corrected behaviour (write the failing assertion first)**

In `tests/unit/test_schedule_rules.gd`, replace the whole `test_char_full_two_date_week_currently_self_reports_invalid` function with:

```gdscript
func test_full_two_date_week_is_valid_after_delegation() -> void:
	# Corrected by the ScheduleRules delegation: the add-time guard no longer double-counts at
	# validate-time, so a full, legal 2-date week validates.
	GameState.schedule_entries = [
		GameState.build_date_entry_from_unlock("priscilla"),
		GameState.build_date_entry_from_unlock("lavinia"),
	]
	assert_eq(GameState.validate_schedule(), {"ok": true, "reason": "valid"},
		"post-delegation: a full valid 2-date week validates")
```

- [ ] **Step 2: Run the suite to verify the new assertion fails**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'test_schedule_rules' -LogName 'sched-t3-red' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_rules.gd','-gexit')
```
Expected: FAIL — `test_full_two_date_week_is_valid_after_delegation` fails because current code still returns `{"ok": false, "reason": "invalid_date"}`.

- [ ] **Step 3: Add the ScheduleRules preload to GameState**

In `autoload/GameState.gd`, next to the existing preload consts (near `const _DATING_ENDING_RULES := preload(...)`), add:

```gdscript
const _SCHEDULE_RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
```

- [ ] **Step 4: Delegate `_can_add_date_entry`**

In `autoload/GameState.gd`, replace the entire body of `_can_add_date_entry` with the delegation. The new function reads:

```gdscript
func _can_add_date_entry(entry: Dictionary, silent: bool = false) -> bool:
	# twofriends is a deferred route produced by day-end resolution, never validated here.
	if entry.get("type", "") == "twofriends":
		return true
	# ScheduleRules owns the solo/group date rules. `existing` is the schedule with THIS entry
	# excluded by identity, so a scheduled entry never invalidates itself (add-time: the candidate
	# is not yet in the schedule, so nothing is excluded).
	var existing: Array = []
	for e in schedule_entries:
		if not is_same(e, entry):
			existing.append(e)
	return _SCHEDULE_RULES.validate_date_candidate(existing, entry, day).get("ok", false)
```

- [ ] **Step 5: Run the schedule suite to verify green**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'test_schedule_rules' -LogName 'sched-t3-green' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_rules.gd,res://tests/unit/test_schedule_rules_phase2r.gd','-gexit')
```
Expected: PASS — "All tests passed!" The corrected full-week test now passes; the add-time and too-many characterizations still pass; the action-path char net (`test_validate_schedule_reason_codes`, `test_can_add_schedule_action_reason_codes`) still passes.

- [ ] **Step 6: Run the blast-radius clusters to verify no regressions**

Run:
```powershell
.\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'sched-blast' -LogName 'sched-t3-blast' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_game_state.gd,res://tests/unit/test_game_state_facade_contract.gd','-gexit')
```
Expected: PASS — "All tests passed!" No regression in GameState scheduling or the facade contract.

- [ ] **Step 7: Commit**

```powershell
$head = git rev-parse HEAD
.\tools\git\Invoke-ExactPathCommit.ps1 -ExpectedHead $head -RequiredStatus @{ 'autoload/GameState.gd' = 'M'; 'tests/unit/test_schedule_rules.gd' = 'M' } -Message 'refactor(schedule): delegate _can_add_date_entry to ScheduleRules.validate_date_candidate and correct the full-week bug (dwm-p2r.7 Task 4)'
```

---

## Notes for the implementer

- **Why `is_same`:** Godot 4 `Dictionary ==` is content comparison, so filtering `schedule_entries` by `e != entry` would wrongly drop a content-duplicate. `is_same(e, entry)` is reference identity — it excludes only the actual candidate instance.
- **twofriends and the date count:** `validate_date_candidate` counts only `DATE_TYPES` (solo/group) for `too_many_dates`. Live `get_scheduled_date_count()` also counts `twofriends`, but twofriends entries are created at day-end resolution and never coexist with scheduling-phase dates, so the counts match in every reachable scheduling state.
- **Deferred (do NOT touch here):** strict entry shape, `slot_index`/`unlock_receipt_id`, `RunSnapshotSchema`/`SaveMigrations`, Day-7 candidate validation, the full `validate_candidate`, and the `ScheduleApp` Done-flow UI. These belong to the `.8` save integration (dwm-7e6) and the future `ScheduleApp` task.
