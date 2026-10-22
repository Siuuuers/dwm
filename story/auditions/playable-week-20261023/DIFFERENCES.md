# Playable adaptation differences — 2026-10-23

The original day Markdown files remain byte-exact. This document records the
user-approved playable adaptation. Focused cloud qualification is linked below.

## Owner decisions

- Day2 D: multiple options. No selection defaults to **Benchmark**; Stay and
  Cruel are selectable alternatives. This supersedes the manuscript's Stay default.
- Sylvia's Day3 branch temporarily joins the supplied Priscilla–Lavinia Day4
  continuation. The build does not claim a separate completed Sylvia week/ending.
- Use earlier Challenge closure receipts through echo labels for conditional
  later text. Never use future Profile history to rewrite a restored Run.
- Extend ordinary thought presentation to multiple labeled options and a default
  selected by advancing. Existing single Yes/default encounters remain supported.
- Keep two Challenge labels around the one impulse caption. Opening Computer on
  that caption admits the board; advancing closes the opportunity and selects
  the result without inserting a fabricated intermediate caption.

## Text and routing adaptations

- Day4 lines26/345: neutral flower description avoids asserting Day3 Lavinia's damaged bouquet after the Sylvia fork or another outcome.
- Day5 lines126–162: cheek-injury exchange is reachable only through Day2 lost; other outcomes echo directly to the shared folder scene.
- Day5 Perfect: split line222 around the recognition passage so page-turning precedes finishing the folder.
- Day5 unfinished: append the existing invitation from line190 after departure preparation, ensuring the Day6 invitation reference has an authored source.
- Day5 D-Note/D-Arch: continue with lines279–281 (work completion and invitation), omitting D-Default's incompatible opening actions.
- Day6 Yes: add a minimal notebook handover before the shared scene; Day6 unfinished references the notebook on her lap rather than an unshown move to the table.
- Day6 unfinished: replace the separate-chairs closing with an equivalent distance-neutral line because the earlier Yes already moved Priscilla beside the sofa.
- Day7: clipboard Yes/default use distinct challenge scene paths; no persistent flag or duplicate history owner.
- Day7 lost: echo Day1's Challenge receipt; include the Monday recording confession only for Day1 lost, and clipboard confession only for clipboard Yes.
- Day7 lost/default clipboard: Board option and destination describe the untouched sheet rather than inventing a crossed-out entry.
- Perfect passages expand their specified C continuation; editorial cut/selection instructions are not audience text.

- Day1's “A voice message.” and Day2's Challenge cue move after their remaining
  common sentences so each cue is the final shared caption before result routing.
- Day1 Perfect uses the explicit phone-face-down insertion anchor; its stale
  reference to “Your part” is not copied from a different outcome.
- Day2 Stay/Cruel receive explicit button prompts in the adaptation module.
- Markdown headings, author orientation, control directions and reading macros
  are excluded from audience captions. Emphasis becomes plain text; crossed-out
  notebook words use Unicode strikethrough rather than losing the correction.
- Colon escaping preserves prose and notebook P:/L: quotations as text, without
  creating dynamic Dialogic characters. Source day/line provenance is retained.

## Authoring and delivery

`tools/authoring/build_playable_week.py` plus its two day modules derives seven
files under `dialogic/timelines/authored_week/` and explicit scene bindings in
`data/manifests/authored_week_source.json`. Run the Python builder after adapting
source mappings. Godot's `AuthoredWeekRegistration.gd` compiles and validates the
result; `ExportSevenDayRegistration.gd` writes the installed native registration.
Do not invent or hand-edit its hashes.

The original engineering day fixtures remain available for accepted regression
evidence. New scenes inherit each day's art and music, and preserve day-entry
witness IDs used by Gallery. The generated graph has 92 segments and 1,666
captions across all alternatives; nine registered Challenges represent seven
reachable encounters because Day3 and Day7 have mutually exclusive branches.

Old save files remain untouched. The changed content fingerprint does not imply
an old-save migration. Qualification uses fresh isolated profiles. Source changes
require a new Windows export before the binary delivery branch can contain them.

## Verification status

Python preparation and graph checks pass: every registered scene is reachable,
all destinations exist, no cycles/dead ends occur, and every path ends at the
shared registered ending. Native compilation and normal-story registration pass.
Focused cloud qualification passes 10 tests / 276 assertions across content,
choice refusal/retry/default/restore, and caption Challenge creation/fresh restore.
Four public API inventory generation/check processes also pass. Accepted results
are reused, not repeatedly qualified. Full evidence, failures and scope limits:
[evidence report](../../../evidence/phase_2r/authored_week_20261023/README.md).

Windows package export follows this qualified source. This is not an old-save
migration or a full combination/release qualification.
