# DIALOGIC — Dialogic 2 requirement, .dtl manifest, and DTL syntax

Documents the Dialogic 2 dependency, the `.dtl` timeline manifest, and DTL syntax.

---

# 1. Required dependency: Dialogic 2
Dialogic 2 is a **required** addon.
- Narrative systems MUST use Dialogic 2 `.dtl` timelines: opening, tutorial, contacts, dating, hospital, ending.
- Contact messages and invitation messages MUST use Dialogic 2 timelines.
- Non-narrative UI (ShopApp, BackupApp, SettingsApp, ScheduleApp, MinesweeperApp) may use normal Godot `Control` scenes.
- If Dialogic 2 is missing, implementation/testing that requires it is **blocked**; report exactly: `Dialogic 2 addon file does not exist.` Do not claim the phase passed.
- Detection: safe file checks `addons/dialogic/plugin.cfg`, `addons/dialogic/`; runtime `get_node_or_null("/root/Dialogic")`. Must report the missing dependency; must not crash.
- State Charts remains optional (plain GDScript fallback). GUT remains optional.

---

# 2. DialogicBridge
`res://autoload/DialogicBridge.gd` (`extend Node`) owns all direct Dialogic interaction. The API contract, allowed marker style, and full safety rules are authoritative in `CONTRACTS.md §10` — do not duplicate them here. Scenes must not duplicate Dialogic detection. Gameplay state changes stay in scene scripts via safe `GameState` methods or `EffectResolver` with known effect IDs.

---

# 3. Required folder root and locale folders
Root: `res://dialogic/timelines/`. Locale folders: `en`, `zh_CN`, `zh_HK`. At minimum every required timeline ID must exist in `res://dialogic/timelines/en/`. If `zh_CN`/`zh_HK` timelines are missing, `DialogicBridge` may fall back to English and write a TODO in `ResultReport.md`; missing translations must not be falsely reported as complete.

Naming: lower snake case, predictable folders, no spaces in filenames.

---

# 4. Scene-to-timeline ownership
- **OpeningScene** starts `opening.day1` (`res://dialogic/timelines/{locale}/core/opening_day1.dtl`). After finish → `GameState.mark_opening_seen()` + `SceneRouter.goto_main()`. Do NOT call `mark_opening_seen()` from DTL.
- **TutorialOverlay** starts `tutorial.desktop_day1` (`.../core/tutorial_desktop_day1.dtl`). After finish → `GameState.mark_tutorial_seen()` + free. Do NOT call from DTL.
- **HospitalScene** starts `hospital.faint` (`.../core/hospital_faint.dtl`). After finish/Continue → `GameState.apply_hospital_recovery_and_advance_day()`. Do NOT call from DTL.
- **EndingScene** selects one ending timeline by ending ID (§8). Dialogic files only display ending dialogue.
- **ContactListApp** owns contact selection UI + safe `GameState` calls; Dialogic owns displayed message/invitation/missed-question text.
- **DatingScene** uses Dialogic for pre/post-challenge dialogue and twofriends scenes; the challenge overlay itself is a Godot `Control` overlay (no `.dtl`).

---

# 5. Contact message timelines
Each friend has a contact timeline Day 1 through Day 7:
- Priscilla: `contact.priscilla.day1`..`contact.priscilla.day7` → `res://dialogic/timelines/{locale}/contacts/priscilla_day{N}.dtl`
- Lavinia: same pattern, `lavinia_day{N}.dtl`
- Sylvia: same pattern, `sylvia_day{N}.dtl`

Each Day 1 file includes **history/backstory** messages (e.g. `contact.history.priscilla` lives inside `contact.priscilla.day1`). History appears before a Minesweeper round. The current-day date-unlocking message requires a finished Minesweeper app round; opening a contact before that exists MUST NOT create a schedule date.

Each daily contact timeline should contain: history (Day 1), daily message text, any pre-choice presentation, post-Minesweeper message text if unlocked.

## Invitation parts are EMBEDDED labels (authoritative)
`offer`, `nevermind`, `missed_question`, and group parts (`first_open_*`, `second_open_*`, `need_reply_priscilla_first`, `offer`, `missed_question_*`) are **`label` segments INSIDE** the per-friend/day contact `.dtl`. They are NOT standalone files. Do not use standalone invitation files; contact invitation parts are embedded `label` segments. `DialogicTimelineCatalog.get_timeline_path("contact.invitation.solo.{friend}.day{N}.{part}")` MUST return the daily contact dtl path, never a standalone file. `ContactListApp` starts `contact.{friend}.day{N}` via `DialogicBridge` and jumps to `label {part}`.

## Nevermind / missed_question appearance days
The numbers below are the **APPEARANCE day** (day the message is shown) = day after the corresponding solo invitation day (see `CONTENT.md §4` for the full table). **Day 7 solo invitations are ending-only candidates** (§8) and generate NO nevermind/missed_question timeline, because there is no Day 8 to miss it on.

For each appearance day, the daily contact dtl contains `label nevermind` and `label missed_question` segments. Example: `contact.invitation.solo.priscilla.day1.nevermind` is the `label nevermind` segment inside `res://dialogic/timelines/{locale}/contacts/priscilla_day2.dtl` (the nevermind for the Day 1 invitation appears on Day 2).

Follow-up label selection (which of `nevermind` / solo `missed_question` / group `missed_question_<participant>` to jump to) is owned by `CONTRACTS.md §2` (Follow-up label selection), driven by `GameState.get_missed_invitation_for_friend(friend_id, D+1)`. A stood-up GROUP participant jumps to the group `missed_question_<participant>` label (`§6` group parts) via a `source == "group"` record; a stood-up SOLO invite jumps to `missed_question` via a `source == "solo"` record.

## Group invitation parts (embedded)
For Day 2 and Day 6, group parts are `label` segments inside the daily contact `.dtl` of BOTH participants. `DialogicTimelineCatalog.get_timeline_path("contact.invitation.group.priscilla_lavinia.day{day}.{part}")` returns the daily contact dtl path of the relevant participant (e.g. `contacts/lavinia_day2.dtl` for `first_open_lavinia`, `contacts/priscilla_day2.dtl` for `first_open_priscilla`), never a standalone file. See `CONTENT.md §6` for the canonical label→meaning mapping (naming caution: participant-based, not open-order).

Required group text (Day 2 & Day 6): the UNIFIED key scheme `invitation.group.priscilla_lavinia.day{N}.{inviter}.{part}` and its EN sample text are authoritative in `CONTENT.md §6`. Do not duplicate the keys here.

---

# 6. Dating, group, and twofriends timelines
DatingScene uses Dialogic for dialogue before/after the placeholder Minesweeper challenge (challenge overlay is a Godot `Control`, no `.dtl`).

Solo dating days: Priscilla 1,2,4,6; Lavinia 2,3,5,6; Sylvia 1,3,4,5. Each has `pre_challenge` + `post_challenge`:
- IDs: `dating.solo.{friend}.day{day}.pre_challenge` / `.post_challenge`
- Paths: `res://dialogic/timelines/{locale}/dating/solo/{friend}_day{day}_pre_challenge.dtl` / `_post_challenge.dtl`

Group dating days: Day 2 & Day 6 (Priscilla + Lavinia):
- IDs: `dating.group.priscilla_lavinia.day2.pre_challenge` / `.post_challenge` and `...day6...`
- Paths: `res://dialogic/timelines/{locale}/dating/group/priscilla_lavinia_day2_pre_challenge.dtl` etc.

Twofriends missed-group days: Day 2 & Day 6 (Priscilla + Lavinia missed):
- IDs: `dating.twofriends.priscilla_lavinia.day2.pre_challenge` / `.post_challenge` and `...day6...`
- Paths: `res://dialogic/timelines/{locale}/dating/twofriends/priscilla_lavinia_day2_pre_challenge.dtl` etc.

**Day-7 note:** there is intentionally **NO** `dating.solo.*.day7.pre_challenge` / `.post_challenge` file. A Day-7 solo date is an **ending-only candidate** that routes to `EndingScene` via `ending.*` timelines (`resolve_day7_ending()`), NOT to `DatingScene`. Do not create `dating.solo.*.day7.dtl`.

---

# 7. Ending timelines
`EndingScene` selects one ending timeline by ending ID. Required IDs:
```
ending.alone
ending.priscilla.sweet
ending.priscilla.dark
ending.priscilla.true
ending.lavinia.sweet
ending.lavinia.dark
ending.lavinia.true
ending.sylvia.sweet
ending.sylvia.dark
ending.sylvia.true
ending.sylvia.special
ending.priscilla_lavinia
```
Required paths (4 endings per friend — sweet/dark/true/special — live inside one dtl; `ending.sylvia.special` is an additional label inside `sylvia.dtl`, so it adds no new file):
```
res://dialogic/timelines/{locale}/ending/alone.dtl
res://dialogic/timelines/{locale}/ending/priscilla.dtl
res://dialogic/timelines/{locale}/ending/lavinia.dtl
res://dialogic/timelines/{locale}/ending/sylvia.dtl
res://dialogic/timelines/{locale}/ending/priscilla_lavinia.dtl
```

**Ending ID resolution:** authoritative in `CONTRACTS.md §2` (Day-7 ending contracts). This file does not restate the precedence — read `CONTRACTS.md §2`.

---

# 8. Required English timeline count
```
Core:      3   (opening, tutorial, hospital)
Endings:   5   (alone, priscilla, lavinia, sylvia, priscilla_lavinia) — `ending.sylvia.special` is an extra label inside `sylvia.dtl`, so it adds no new file.
Contact:   21  (3 friends × 7 days, invitation parts embedded as labels)
Solo dating:   3 friends × 4 days × 2 = 24
Group dating:  2 days × 2 parts = 4
Twofriends:    2 days × 2 parts = 4
-------------------------------------------
Minimum total English .dtl files: 61
```
Invitation parts (offer, nevermind, missed_question, group parts) are embedded labels inside the 21 contact files and are NOT counted as separate files, so the contact total stays 21 and overall total is 61.

---

# 9. DialogicTimelineCatalog
`res://scripts/data/DialogicTimelineCatalog.gd` (`class_name DialogicTimelineCatalog`, `extends RefCounted`). Do not execute timeline data; do not call arbitrary methods from timeline IDs; do not trust save data to choose paths; validate timeline IDs through this catalog. Methods: `get_supported_locales()`, `get_required_timeline_ids()`, `get_timeline_path(timeline_id, locale="")`, `get_required_timeline_paths(locale="en")`, `has_timeline_id(timeline_id)`, `build_missing_timeline_report(locale="en")`. For invitation-part IDs, `get_timeline_path` returns the per-friend/day contact `.dtl` path; the part is a `label` inside that file, never standalone.

---

# 10. Testing and ResultReport
Future smoke test `res://tests/smoke_dialogic_timelines.gd` validates required English timeline paths, requires `.dtl`, reports missing, exits 0 only if all exist, exits 1 if any missing; must not claim success if Dialogic 2 is missing (`Dialogic 2 addon file does not exist.`). `ResultReport.md` must include Dialogic 2 detected/missing, timeline required/existing/missing counts + paths, translated status (zh_CN/zh_HK), and timeline safety (no arbitrary do/call, no direct GameState calls from DTL, no unsafe markers).

---

# 11. Art policy (placeholders only — no art generation)
There is NO automated art-generation step in this project. Missing art is resolved entirely by `SafeImage` placeholder overlays at runtime (category, id, path, file name, expected size, status). Runtime game code MUST NOT depend on any external image service or art-generation tool. To add real art later, a human simply drops a correctly named PNG at the expected path listed in `CONTENT.md §11` (the authoritative art catalog; `ArtManifest.gd` is currently a stub and does NOT yet provide those paths). Anything absent stays a placeholder and never crashes. The single art authority for narrative-adjacent assets is `CONTENT.md §11`.
