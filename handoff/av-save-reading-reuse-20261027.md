# Save reading reuse and Quick Save completion

Date: 2026-10-27, Hong Kong time.
Previous record: [trusted live Save](au-trusted-live-save-implementation-20261027.md).
Implementation and final acceptance: [PR 136](https://github.com/Siuuuers/dwm/pull/136).
Read current master and PR results before more work.

## Observable outcome

Save the exact current reading and gameplay state. Load must not repeat consequences.
Reduce Save work without adding work to ordinary reading.

## Implemented candidate

- Return the session already restored by compact checkpoint expansion.
- Reuse that session in Run schema checks. Preserve raw reading5 restoration.
- Reuse the validated expanded checkpoint in New Run. Its initial ledger stays separate.
- Remove the presentation port's duplicate Quick Save capability preflight.
- Keep Quick Load refusal behavior and freshness checks across actual callbacks.

[Measured evidence](../evidence/phase_2r/save_reading_reuse_20261027/README.md) records
24 passing exported journeys. Longer-reading Save improved from 1019.64 ms to 943.02 ms
in four matched pairs. Scene validation calls fell from 12 to 8. Load was 0.8% slower.
Do not infer a Quick Save latency gain from this manual Save comparison.

## User decision for the next change

The user selected: "Saved" confirms that Quick Save completed. Show it for two visible
seconds. Do not repeatedly capture save state to check that message against later gameplay.
Keep screen ownership and visibility checks. Each successful Save gets a fresh two-second
notice. Failure notices and pending Quick Load confirmation retain their current checks.
This decision does not make a pending save token valid after a gameplay change.
The UI implementation is separate from PR 136. Check current master before applying it.

## Further source finding

Normal semantic validation still expands compact reading again through GameState and
FrozenRunContext. Completed-passage validation can also expand it. The schema now owns
an operation-local expanded checkpoint. A later measured change can pass it through the
existing production owner while retaining full independent public validation and custom
two-argument semantic delegates. Do not add a persistent cache or public trust Boolean.
Raw reading5 uses projection before semantic validation; do not replace that behavior
with direct substitution without checking its current consumers.

All game execution stays in the cloud. Keep named-checkpoint-only Autosave, manual Save,
Logout without saving, accepted content compatibility and persistent missing-ID errors.
Do not add injected failures, edited-file scenarios, mandatory interaction gates or
speculative external protection. No blocking product question remains.
