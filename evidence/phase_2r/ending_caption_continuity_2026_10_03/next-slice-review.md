# Read-only next-slice review: ending Auto continuity

This is planning, not accepted Auto behavior. Reviewed against runtime source
`2f236aa7099ca2aec51401bc936e3cb0179e5526` by the independent caption reviewer.

Approved disposition: `docs/design/2026-08-22-hospital-ordered-ending-current-v1-ui-disposition.md`
section 4.5. Observable outcome: Auto visibly On survives a durable nonfinal
ordered-ending seam; the old timer retires with its source, and the successor
gets its own complete reveal and full delay. Skip stays Off and prior input/Next
activation cannot reach the successor.

Use the existing owners: Profile `preferences.reading.auto_enabled` for enabled
state, `WitnessedAutoController` for transient frontier/generation/delay,
`WitnessedCaptionLayer` for reveal/foreground/speech admission and rail display,
and `DialogicBridge` for exact acknowledged/witnessed source validation and native
advance. Ending completion owners retain durability and Retry decisions. Current
handoff code already retires timers without changing the enabled preference;
observe it before making changes. No additional state owner is indicated.

Boundary requiring careful scope: `_auto_line_context()` admits only the next
event classified as `text`. Return, End and Jump share `scene_transition`; never
broadly admit that category to make an ending Return automatic. Prove Auto stays
enabled across a manually reached seam separately from Auto driving terminal
completion. Before adding the latter, identify its approved behavioral clause and
require exact terminal-event/ending ownership proof. No new architecture choice
was found by this review.

Failure coverage should include stale timer/callback advancing the successor,
inherited remaining delay, visible Off during settlement, actionable held rail,
durability failure and Retry, held contact, Pause/History/speech admission,
cancellation/foreign playback and Save/Load preference or speech replay. Preserve
generic Auto non-text boundary restrictions.
