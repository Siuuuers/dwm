# Retired challenge draw acknowledgement helpers

Baseline: `8eeac7ceee26f787136689f76b45a83e54f7ac1a` (2026-11-04).

Remove DatingScene's `_acknowledge_pre_challenge_draw`,
`_acknowledge_post_challenge_draw`, `_on_challenge_status_drawn`, six exclusive
pre/post draw/attempt/reached flags, two draw connections, and four exclusive
inline translations of the old acknowledgement error.

The helpers formerly recorded a pre/post boundary after a placeholder title or
status draw, with private Rehearsal/Practice handling. Neither acknowledgement
helper has a caller. The connected draw callbacks only set flags read by the
unused helpers. No resource, dynamic invocation, subclass, signal or remaining
test consumes the removed methods/fields. The retired capability probe was the
last external private-field consumer; PR #189 removed it.

Current progression runs `_process` -> `_pump_narrative_phase` -> the presentation
port's begin/pull narrative methods -> DatingNarrativePlayback natural completion.
Retain that path unchanged. Retain application/physical-owner acknowledgement
interfaces and their existing history tests; this is only scene-local cleanup.
Keep title/status nodes, text, error handling, input and all saved state intact.
Exact original source remains at the baseline revision.

## Verification scope

Check reference closure and byte equivalence of all remaining DatingScene source
after precisely the listed deletions. Run the existing challenge-controls scene
suite, remaining scene smoke and both public API inventory checks. No new tests,
lint, framework, save schema or dependency are needed. Broad story, localization,
shop/audio, TLA+, export and performance checks are excluded for this deletion.
Actual results are recorded in the implementation PR; no speedup is claimed.
