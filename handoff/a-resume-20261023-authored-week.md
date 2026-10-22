# Authored seven-day week handoff (2026-10-23 branch)

## Delivery

- Draft PR: https://github.com/Siuuuers/dwm/pull/43
- Source branch: `codex/seven-day-story-20261023`; base `codex/art-media-20261023`.
- Packaged source: `2146c4435041c2b4ccc467a526f7b127d3980a2f`.
- Windows export: https://github.com/Siuuuers/dwm/actions/runs/39843283227
- Binary delivery branch: `builds/windows-playable-20261023`, commit `1b98886628c3e042c5a7c5738ddb2912f27d7ae8`.
- Publication: https://github.com/Siuuuers/dwm/actions/runs/39843770556
- No source merge, Steam upload, or public release was performed.

## Accepted behavior and ownership

All seven uploaded drafts are preserved under `story/auditions/playable-week-20261023/` with receipts. Their generated production timelines are `dialogic/timelines/authored_week/Day1.dtl` through `Day7.dtl`. Use `tools/authoring/build_playable_week.py`, then native Godot registration; do not hand-edit generated captions or inventories. `DIFFERENCES.md` records narrative joins and user-approved adaptations.

Day2 offers Stay and Cruel; Continue defaults to Benchmark. Sylvia's Day3 temporarily joins the supplied Priscilla/Lavinia Day4. Later echo labels read earlier Challenge receipts from the current Run. Multi-choice UI uses the existing thought opportunity, durable receipt, and recovery owners; old single-choice calls still work.

Two labels bound each Challenge impulse caption. Computer admission completes the actual reveal and admits the playable session. Advancing closes the adjacent End without inventing a caption. GameState owns durable closure through its authenticated held-control commit seam; Bridge captures an empty control frontier only after native validation. Generic line-only event guards, save schemas and history ownership remain unchanged. Old saved bytes are retained, but this changed content fingerprint requires fresh test saves; no migration is claimed.

## Evidence and limits

See `evidence/phase_2r/authored_week_20261023/README.md`. Focused acceptance is complete: 10 tests / 276 assertions across authored bindings, legacy and multiple choices, rendered create/fresh-load pairs, and caption Challenge create/fresh-load. Four public API inventory generation/check processes pass. Native registration and normal-story validation pass. Accepted qualification is reused; do not rerun completed batches merely because documentation changed.

The graph has 92 segments and 1,666 captions. Nine registered Challenges represent seven encounters on a journey because Day3 and Day7 alternatives are exclusive. Original engineering fixtures remain for compatibility, including the runtime's seven-day order resource. Day-entry witness IDs and inherited art/music remain intact.

Windows validation covers packaged data hashes and isolated headless executable startup. The initial export attempt stopped before packaging because Godot imported retained evidence screenshots; `evidence/.gdignore` fixes that without changing gameplay. The next export passed package checks but generated nine DTL resource IDs; those exact native bytes were committed for reproducibility before the final package retry. No full week combination/rendered sweep, accessibility acceptance, performance improvement, installed Steam test, or release qualification is claimed. Generic CI triggered by branch pushes is separate from focused acceptance.

## Continue only for a concrete new task

Do not repeat accepted qualification or broaden the scope to old generic CI failures. Keep binary delivery separate from source. The workflow controller PR #30 is temporary cloud machinery, not a source merge target. Preserve evidence and compare branch heads before any future publication. Master was checked for relevant overlap; no related implementation was imported.
