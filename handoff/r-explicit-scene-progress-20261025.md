# Explicit scene progress — 25 October 2026

PR: https://github.com/Siuuuers/dwm/pull/87
Progress implementation: `2c436f241f51268cef59e9d7eddb83ef749340a3`.
Font isolation: `8ec14b37cc98b7a8810b136cdeeba711a77ac8ac`.
Current qualification candidate: `6964be088b01e37e5a8367ec1972caf849696c75`.
Current Windows run: https://github.com/Siuuuers/dwm/actions/runs/40135144954
The full final workflow passed. Check live PR metadata for the final merge revision.

Initial full run 40133148375 passed, but its choice screenshot and an unchanged
rerun both showed malformed UI glyphs. The story-font duplicate now clears its
inherited cache before fallback installation. Ten font/style tests with 10,526
assertions pass; the same Windows choice offer now renders readable controls, options and caption.
The final full workflow passed. The evidence-only successor changes no qualified
runtime, tests, inventories or workflow. A CPU glyph probe did not
reproduce the issue, so the precise engine-level cause remains unconfirmed.
Run 40134665601 stopped on stale inventory metadata before visual testing; the
corrected inventory is included in the current candidate.

## What changed

GameState owns `scene_choices[opportunity_id] = choice` and
`scene_challenge_outcomes[challenge_occurrence] = {challenge_id, outcome}`.
Current saves require them. Producing transactions persist facts alongside their
receipt and adopt them only after successful persistence. Reset, capture, silent
Scene installation, cold compensation and live backup restore these fields.
SceneHost directly checks choice presence instead of copying a full snapshot
and scanning every receipt during its periodic UI update.

Each outcome keeps its physical occurrence. The previous handoff's proposed
Challenge-ID scalar would have collapsed valid separate occurrences and changed
ambiguous recall semantics; that proposal is superseded. Missing remains distinct
from `never_started`. Existing five outcomes and authored choices are unchanged.

The current authenticated semantic traversal checks exact fact/receipt agreement.
This is transitional duplication, not completed compact persistence. No old-save
migration, new choice design, ending selector, performance claim or narrative
content was added. Existing receipt retry, recall, native admission and board
settlement still exist.

## Evidence scope

See [retained evidence](../evidence/phase_2r/explicit_scene_progress_20261025/README.md).
Linux diagnostics run in six separate processes: 41 cases, 606 testcase assertions,
three setup assertions. Do not combine SceneNewRunFixture and cold rollback in
one diagnostic process: their singleton registration ownership conflicts.
The added Windows suites reuse existing physical create/fresh-process Load tests.
Connected recall covers `never_started`; other outcome classifications have unit
coverage, not five separately rendered save/load journeys.

## Next bounded removal

Current recall can use explicit outcome facts. `closure_command_id` is confined
to SceneEventContract's recalled-result shape/resolver and its tests; downstream
GameState/admission uses `kind` and `target_id`. Remove that field, resolve current
recall from matching `scene_challenge_outcomes` entries, and preserve zero-match
missing / multiple-match ambiguous refusal. Keep the existing five target mappings.

Historical validation cannot resolve earlier recalls against today's entire map:
a valid earlier recall may precede a second closure of the same Challenge.
Temporarily retain its prior-counter filtering with the smaller result shape.
Test that historical ordering explicitly. This requires no new product decision.

## Full compact restoration remains outstanding

The target is fresh-process Load of a full caption and unfinished board with prior
choices/outcomes and non-default economy, then continuing and settling the board
without paying or rewarding twice. A caption-only reconstruction is insufficient.

`SoloReadingSession.configure_scene/begin_scene/admit_scene` can reconstruct a
native present caption, but the bridge's staging and GameState event context still
require admission receipts, occurrence, ordinal, predecessor and notification
facts. Preserve caption versus held-control distinction and gate input until
native confirmation. DesktopBoardState's paid-start and terminal receipts still
prove board settlement; replace these with explicit current payment/settlement
state before deleting history. Retain staged atomic restoration and rollback.

The user's preserve-current-choices decision remains in force. Day7's second
endpoint is still a separate content gap; do not invent it during save work.
