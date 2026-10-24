# Explicit Scene progress — 25 October 2026

## Outcome and ownership

GameState stores resolved opportunities as `scene_choices[opportunity_id] = choice`.
It stores completed Challenge occurrences as
`scene_challenge_outcomes[challenge_occurrence] = {challenge_id, outcome}`.
The existing result supplies each value. Missing is distinct from `never_started`.
Separate occurrences of one Challenge are preserved; there is no last-write-wins
reinterpretation of ambiguous recall.

The detached save candidate carries facts and receipts together. Live adoption
follows successful persistence and existing source/lease checks. Current saves
require these maps; older development saves are deliberately unsupported.
Restore, reset, cold compensation and live backup preserve their ownership and
copy boundaries. SceneHost reads choice presence directly instead of copying
all current state and scanning command history every UI refresh.

This is groundwork for compact restoration, not a ledger-free save format.
Existing recall provenance, transition retry, board settlement and native
reading admission still use historical receipts. The existing authenticated
semantic traversal checks facts against receipts until those consumers are
replaced. No performance measurement or speedup is claimed.

## Diagnostic qualification

Six independent Linux cloud/headless Godot 4.6.3 processes passed 41 cases with
606 testcase assertions, plus three fixture setup assertions. Retained JUnit
reports and source hashes are under `linux/`.

Coverage includes schema shapes, missing versus never-started, distinct Challenge
occurrences, receipt/fact mismatch refusal, cold rollback, detached live backups,
registered choice semantics, and all five outcome classifications. An initial
combined diagnostic run mixed incompatible registration fixtures; it is
superseded by these isolated runs. Its new live-backup test also incorrectly
expected silence from an existing notifying API; that assertion was removed,
without changing production notification behavior.

## Font rendering correction

The choice offer showed malformed UI glyphs on two Windows runs of unchanged
candidate `2c436f241f51268cef59e9d7eddb83ef749340a3`, although behavior tests passed.
A retained earlier fixture screenshot was clean. Story text duplicated a warmed
UI FontFile. The new story face now clears its inherited cache before fallback
installation, preserving font data/settings and leaving the primary UI face alone.
This happens once per cached story face, not during each UI refresh.

Ten headless font/style cases with 10,526 testcase assertions pass; source hash
and JUnit are under `linux/`. Together with the progress checks, retained Linux
coverage is 51 cases / 11,132 testcase assertions, plus three setup assertions.
A CPU glyph-raster probe did not reproduce the corruption. The precise engine
cause remains unconfirmed; the matched Windows choice screenshot establishes
that the observed symptom is resolved with this change. Official method contract:
https://docs.godotengine.org/en/4.6/classes/class_fontfile.html#class-fontfile-method-clear-cache

## Windows qualification

Final qualification candidate: `6964be088b01e37e5a8367ec1972caf849696c75`.
Final workflow: https://github.com/Siuuuers/dwm/actions/runs/40135144954
The full final workflow completed successfully. Its rendered choice create/Load,
recall, schema/Backup, terminal fixture and broader regressions passed. The choice
offer and restored captions have readable controls and text. The archived incompatible startup/Load measurement is
intentionally skipped; no passing measurement or speedup is claimed.

The initial full workflow 40133148375 passed, but its offer screenshot and the
unchanged targeted rerun reproduced malformed control glyphs. Their evidence is
retained as diagnostics, not clean visual acceptance. Run 40134665601 stopped on
a stale inventory reference line before gameplay/visual qualification; corrected
inventory metadata is included in the final candidate.

The retained initial Windows subset contains 28 passing cases / 954 testcase
assertions: multiple-thought create/Load (2/96), Challenge recall create/Load
(2/174), current schema/Backup (21/330), and short terminal create/Load/terminal
(3/354). The unchanged choice rerun adds two diagnostic cases / 96 assertions.
The final-run subset also contains 28 cases / 954 assertions, retained separately
by artifact ID and source revision. The evidence-only successor does not change
the qualified runtime, tests, inventories or workflow.
Connected recall covers `never_started`; all five classifications have unit
coverage, not five separately rendered save/load journeys.

`windows-artifacts.json` pins revision, run, artifact IDs and original archive
digests. Each download is checked against its digest. `windows/` retains JUnit
reports and reviewed screenshots, with a member/hash index. Reports normalize
CRLF to LF; screenshot bytes remain unchanged. Before/after images are preserved.
