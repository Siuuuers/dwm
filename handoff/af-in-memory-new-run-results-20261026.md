# AF: New Acc merged; next measured ablation

Date: 2026-10-26 (Hong Kong). PR [#111](https://github.com/Siuuuers/dwm/pull/111) merged into master `0a15de6724ab6256953d0643eab74c6b8cb23807`. Tested candidate `e286838c106c1dd716ceacb89a5e4554f4b1b4d2` has the identical tree. Check current master/open PRs before new work.

Read AGENTS.md, CLAUDE.md and relevant owners. The approved foundation remains `docs/retired-features/new-run-assignment/README.md` and the scoped story amendment. Its runtime status prose predates this completed verification; this handoff and current PR metadata establish implementation/merge status.

## Completed outcome

New Acc initializes at the canonical authored start in memory, with fresh mutable gameplay, no initial Autosave, no assignment draw, no preference consumption and no durable creation recovery operation. Previous saves and Profile/global progress survive. Real later Save and old-format Load work. Scene Logout stays unsaved: the owner's explicit answer supersedes the earlier handoff sentence saying it should save. Do not reopen that design question.

Retain the exact approved confirmation: “The beginning is still here. Shall we enter again?” Five locales updated; buttons/layout unchanged. No new template manager or alternate start map. SaveManager coordinates, GameState owns defaults, manifest owns start selection, Profile owns settings/global progress.

Runtime-family detection no longer uses scene_assignment. Old Run9 field is ignored then omitted in new saves. Local Challenge/choice variations remain. Identity allocation remains because board/day/save/restore paths actually use it. Compatibility recovery helpers were not exhaustively retired.

## Accepted evidence

[Windows](https://github.com/Siuuuers/dwm/actions/runs/40307319429): 61 passed, one intentional skip. [Comparison](https://github.com/Siuuuers/dwm/actions/runs/40307319301): 24 processes, 64 screenshot hashes, strict ObjectDB/resource/script gate passed. See [full result record](../evidence/phase_2r/in_memory_new_run_20261026/README.md).

Matched medians: fresh New Acc 4.400001→1.6408945 s; retained 4.461479→1.6911495 s; Load 2.3285135→2.3726565 s. New Acc is about 62–63% faster in this batch. Load's small difference lies within overlapping observed ranges; no Load improvement is claimed. Do not compare absolute timings across different runners. Median largest New Acc frame gap is still about 1.5–1.6 s.

## Lessons to retain

The first full green comparison was manually rejected for candidate-only coroutine warnings. A five-line polling loop held Title awaiting SaveManager after route replacement destroyed Title. It was deleted: existing route/narrative signals complete activation, and Menu's source-lifetime check prevents post-detach recovery UI. Do not reintroduce a Title wait across its own destruction.

An earlier baseline shutdown error involved looping Ogg playback. The harness now releases audio only after timed caption and save assertions, verifies stopped/null players, waits 100 ms plus one frame, then quits. This is not a production audio-shutdown fix. Keep matched verbose logging and the strict leak/error gate; do not suppress logs or accept a green run without review. Failed diagnostics are retained in the evidence branch.

## Next investigation: one ablation at a time

No next product edit is underway. Two read-only findings are candidates, not measured gains:

1. Scene `prepare_new_run_action` still captures/hashes the live replacement baseline and retains its revision, although the scene commit path no longer compares that revision. Consent only uses whether live state is present. Trace the actual presence owner and remove unused hashing if normal confirmation behavior stays identical. Do not change the legacy path without its caller review.
2. The in-memory New Run still prepares/applies/finalizes an unchanged Profile participant. This causes copies, validation, revision increment and profile_restored consumers to reapply mappings/window state. A separate ablation could pass through existing Profile only for memory_new_run. Verify custom bindings, window mode, locale/font, audio, read history and unlocks; preserve required participant ordering and real Load behavior.

Repeated snapshot validation is another measured cost (two candidate fresh validations around 139 ms and 133 ms, inclusive), but keep it separate from Profile and live-baseline changes. Do not sum nested counters or remove boundary checks without tracing their ownership.

Start with one observable outcome and a reproducible pause. Audit compatible callers/tests before final acceptance, then compare the entire player action against merged master. No general rewrite or speculative abstraction is authorized by a performance hypothesis alone.

## Standing authorization and workflow

Cloud-only Godot/Windows execution; local source/static/Python work is allowed. The user authorizes direct PR merges and parallel agents with clear responsibilities. One coordinator owns integration, publication and shared files. Trust shipped content; defer external manual-tampering expansion. Ask only when a real unresolved design answer would change architecture or block work. Keep ordinary Save/Load correct and preserve global preferences/progress. Do not silently add speculative robustness.

A fresh session is useful at this completed milestone: implementation, acceptance, matched measurements and merge are finished, and the next ablation can begin from one narrow outcome. Use this handoff rather than repeating the earlier design interview. Raw evidence belongs on its separate branch, not master.
