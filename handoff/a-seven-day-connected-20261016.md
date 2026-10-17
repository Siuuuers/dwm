# Connected seven-day story — Coordinator A handoff

Status: bounded milestone accepted on 16 October 2026. Draft/unmerged; no release.

## Result

Normal Title New Game now traverses fourteen replaceable TEST captions (Day1.one through Day7.two), enters the registered neutral ending, completes through the existing Gallery owner, returns to Title, and starts fresh Day1. A Day4.two Save loads fully revealed in a separate process without advancing its frontier or rewinding current history. A real ending Save loads in a third process after the previous process already completed that run; it restores the exact caption and completes without a duplicate Gallery transaction.

This is TEST content, not finished narrative. Day1.1 is still only a generic helper-test example. Optional Challenges remain optional.

## Source and acceptance evidence

- Product source: `6eaa6a94a01aea23655774b0608613f46961036d`.
- Exact tested and published tree: `604a5d96f9eedc7466e7f64f6085928fbac63402`.
- Candidate before generated identities: `f8f2ffe6eefbffe264a1dfa1cff55ac37af427b8`.
- Cloud-local frozen commit: `571d68cf9a50726a93054100360f0b8de8376f0b` (same tree; different commit identity).
- Controller: `a4ba76bb994df2be887c7878f062e6899d3c2f48`; workflow blob `e5d6dde748d76657a12d22797d4f7669f8efd4b1`.
- [Successful cloud run141](https://github.com/Siuuuers/dwm/actions/runs/38867983987), job116865121803.
- Windows2022; Godot4.6.3 standard GDScript, version4.6.3.stable.official.7d41c59c4. Engine archive SHA256 `e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90`.
- Original ZIP: `evidence/phase_2r/seven_day_connected_20261016/run141-original.zip`, 2863793 bytes, SHA256 `31e1945c437a82fb0dbbed37ba6444714386ca244397ab4592bd89da36ad9e64`.

| Lane | Tests | Assertions |
| --- | ---: | ---: |
| Terminal lifecycle | 5 | 120 |
| Terminal presentation | 6 | 30 |
| Terminal snapshot | 2 | 10 |
| Sequence authoring | 6 | 68 |
| Seven-day templates | 3 | 67 |
| Rendered creator | 1 | 95 |
| Rendered Day4 loader and completion | 1 | 162 |
| Rendered ending loader and repeat completion | 1 | 71 |
| Total | 25 | 623 |

Independent verification rehashed the original ZIP and all136 manifest members; checked exact source-derived XML test names, passing status, positive assertion counts, no failure/error/skip elements or runtime script-error lines; checked three exit0 children, shared isolated disk, separate logs, ordered execution and distinct process IDs5972/7040/4240. Cloud source was clean after testing. Publishing all32 generated UID/export/surface files reproduced the exact cloud tree. The retained screenshots were inspected for the fully revealed restored ending and completed Title. Source-derived census for unchanged test_scene_sequence_authoring.gd was read from the pinned candidate.

## Owners and fixes

The existing scene registration and receipt issuer authenticate final transition admission. RunLifecycle owns the scene ending plan/cursor; ordinary Run9 scene lifecycle shape is unchanged. Source admission/checkpoint references remain historical while Load remaps the live branch. No legacy numeric day or eligibility cache is invented.

SaveManager and the existing checkpoint port retain durable save/recovery ownership. Pause captures producer inputs; strict validation runs after complete Run9 composition, before token issuance and again at commit. Definite checkpoint refusal retains the pending command; committed uncertainty fails closed.

DialogicBridge retires source playback only after generation-qualified native cleanup. GameState checks admission and live session before routing, waits for shared transaction release, and rejects stale callbacks. Terminal restore uses its retained operation's physical-occupancy check while public callers still see the unconfirmed reservation as busy. EndingScene adopts the restored reader only after publication custody releases.

SceneRouter uses terminal scene metadata only for mounting. It no longer merges that metadata into gameplay.route_context, preserving saved gameplay and allowing strict completion checkpoints. Profile remains the append-only history/Gallery owner; restored ending completion reuses the existing Gallery transaction.

## Diagnostic attempts

Earlier failed attempts are diagnoses, not accepted test totals. Run131 exposed native cleanup ordering;132–134 exposed ending Save validation of incomplete producer inputs;135 exposed restore blocking on its own reservation;136 exposed a Boolean inference compile error;137 exposed route-context contamination and completion refusal. Run138 was superseded by the concrete route fix. Run139 failed before engine execution because shallow checkout omitted the pinned base; controller depth became32. Run140 passed earlier lanes but its terminal helper did not compile because a diagnostic assertion used the wrong arity. The final candidate corrects that assertion; controller now compiles all three rendered children before the long journey. Run141 alone supplies the25/623 acceptance above.

## Limits and next coordinator

Preserve earlier accepted optional-Challenge, Contacts, first-Reveal and authoring reports as separate evidence; do not sum overlapping runs. Broader CI remains unresolved. This milestone does not qualify every interruption point, all legacy paths, board restoration, arbitrary story content, performance or the whole game. No performance improvement is claimed.

PR36 is the product draft; PR30 is a workflow-only controller and must not merge into product. Integration remains `3ae6d9138fb53c388380c78550cf6082eafc0ea3`; master remains `0c8b2384415d71bd3de4ff7408640bbf60b63740`.

Next work should start from this accepted source/evidence head and choose one concrete remaining broader-CI failure or player-facing milestone. Do not rerun this completed journey without a relevant code change. Review master/integration before new work. Continue cloud-only Godot/PowerShell execution.

The local execution service became unavailable during this session; later source edits and generated identities are canonical in GitHub. Do not overwrite them from an older local index.
