# Day7 aged Accept attribution

Updated 4 November 2026. Measured on `a043ea82cfef52e20ba69256a282cc2b653f8f8b` (`Siuuuers/dwm` master at measurement time). Runtime code under that commit is the registry-reuse baseline `b6ed7b7ccbe722405eca4652351ea031382e64b8` plus the prior handoff.

This record stores one local attribution. It does not change the game. The deletion named below was **not** applied.

## Question

After a long natural session, where does one ordinary Accept from the Day7 cue spend its time, and which single removal is the next candidate?

Visible outcome that must survive any later edit: the same full result caption and outcome, the same board, encountered history, and Save/Load behavior.

## How it was measured

One Godot 4.6.3 standard process, local Linux, Xvfb, Mesa llvmpipe. The process started at Title and walked the shipped route through `line.Day7.untouched.impulse.004`, saved slot 3, then advanced to `line.Day7.A.001` and `line.Day7.A.002`. Timers wrapped the playable, reading, ledger, and profile functions and were enabled only for those two captions. Nested times are inclusive. Exclusive time is the wrapper duration minus the wrapped children that fit inside it. Do not add inclusive rows.

The timers were a local overlay. They are not in this commit. A fresh Load of the saved slot was not used as the benchmark. Linux times are not Windows player times.

At the cue, before the timed Accept:

| Fact | Value |
| --- | ---: |
| Ledger captions | 800 |
| Live command receipts | 31 |
| Receipt UTF-8 bytes | 80365 |
| Run input UTF-8 bytes | 84341 |
| Slot SHA256 | `f831ce08debb091ed3fc2c35f1cbc37d1843467aa80f6d2d31c3d301562892d2` |
| Profile SHA256 before the result captions | `a45c0719e08426cdd561d7455019d5e76e76a38bae77cdacc87fb3471ae2bef1` |
| Profile SHA256 after the timed pair | `9a5fae72e97c1d0887071468f7a445004110045e745cd3f7c91d2575e06804c3` |

The final Profile hash matches the earlier matched-acceptance profile. The slot hash is from this new walk, not from the archived seed `6633123adc318e7e83815243dd5ea07e81aa05a91ba0fce667c5e2e052f959e9`. Live sizes match that earlier aged session (800 captions, 31 receipts, 80365 / 84341 bytes).

GUT reported `test_seed_naturally_reached_late_transition` as 7373/7374. The failed assert is three engine errors, `Parameter "synth" is null`, because `libspeechd.so.2` is absent on this machine. Both captions were recorded after that. It is not a story, board, or save failure.

## Wall time

| Caption | Elapsed |
| --- | ---: |
| `line.Day7.A.001` (the aged Accept) | 5707 ms |
| `line.Day7.A.002` (next ordinary caption) | 681 ms |

Inside the 5707 ms, `accept_scene_event` ran twice:

| Call | Start | Inclusive |
| --- | ---: | ---: |
| Playable accept (`_accept_scene_playable_event`) | 120 ms | 2722 ms |
| Finish accept | 3325 ms | 1591 ms |

Profile persistence for this Accept started after the Finish returned (one call, 357 ms). About one second of the 5707 ms sits outside the wrapped functions (input, drawing, and unwrapped work).

These match the shape of the earlier instrumented cloud sample (playable about 2716 ms, Finish about 1433 ms, profile about 411 ms). They are one local sample with timers installed, not a speedup claim.

## Phases inside the 5707 ms

Inclusive. Overlapping. Do not sum.

| Phase | Calls | Inclusive | Max |
| --- | ---: | ---: | ---: |
| `GameState.accept_scene_event` | 2 | 4313 ms | 2722 ms |
| `GameState._accept_scene_playable_event` | 1 | 2722 ms | 2722 ms |
| `DialogicBridge.commit_scene_playable` | 1 | 2222 ms | 2222 ms |
| `DialogicBridge._commit_scene_playable_owned` | 1 | 2217 ms | 2217 ms |
| `SceneEventContract._equal` | 66 | 775 ms | 116 ms |
| `SoloReadingSession._validate_scene_saved` | 5 | 656 ms | 215 ms |
| `ReadingTraversalOperation._same` | 205 | 640 ms | 51 ms |
| `DialogicBridge._scene_playable_current` | 5 | 551 ms | 118 ms |
| `SoloReadingSession._capture_scene` | 152 | 518 ms | 16 ms |
| `SoloReadingSession.capture` | 149 | 509 ms | 16 ms |
| `NarrativeCaptionLedger.snapshot` | 277 | 464 ms | 9 ms |
| `SoloReadingSession.restore` | 3 | 442 ms | 218 ms |
| `SoloReadingSession._validate_scene_base` | 8 | 429 ms | 94 ms |
| `SaveManagerNarrativeCheckpointPort.commit_scene_control` | 1 | 401 ms | 401 ms |
| `NarrativeCaptionLedger.restore_snapshot` | 9 | 364 ms | 70 ms |
| `NarrativeCaptionLedger._restore_scene_snapshot` | 9 | 364 ms | 70 ms |
| `ProfileManager._persist_candidate` | 1 | 357 ms | 357 ms |
| `GameState._prepare_scene_playable_event` | 1 | 333 ms | 333 ms |
| `GameState._validate_scene_playable_source` | 5 | 329 ms | 67 ms |
| `SaveManagerNarrativeCheckpointPort.retain_scene_control` | 1 | 312 ms | 312 ms |
| `GameState._scene_runtime_event_context` | 21 | 241 ms | 21 ms |
| `SaveManagerNarrativeCheckpointPort.consume_scene_control_ack` | 1 | 187 ms | 187 ms |
| `DialogicBridge._prepare_scene_reading_candidate` | 1 | 181 ms | 181 ms |
| `ReadingTraversalOperation.valid_scene_reading_shape` | 12 | 160 ms | 23 ms |
| `NarrativeCaptionLedger.publish_caption` | 7203 | 121 ms | 1 ms |
| `SoloReadingSession.prepare_scene_next` | 1 | 67 ms | 67 ms |
| `ReadingTraversalOperation.validate_scene_path` | 1 | 14 ms | 14 ms |
| `GameState.capture_run_snapshot_input` | 17 | 7 ms | 1 ms |

## What dominates

Exclusive leaves, largest first:

| Leaf | Calls | Exclusive |
| --- | ---: | ---: |
| `SceneEventContract._equal` | 66 | 775 ms |
| `ReadingTraversalOperation._same` | 205 | 640 ms |
| Unwrapped body of `_commit_scene_playable_owned` | 1 | 517 ms |
| Unwrapped body of `accept_scene_event` | 2 | 506 ms |
| `NarrativeCaptionLedger.snapshot` | 277 | 464 ms |
| `ProfileManager._persist_candidate` | 1 | 357 ms |
| Unwrapped body of `commit_scene_control` | 1 | 262 ms |
| `SoloReadingSession._capture_scene` beyond its snapshot | 152 | 248 ms |
| `NarrativeCaptionLedger._restore_scene_snapshot` beyond `publish_caption` | 9 | 242 ms |
| `NarrativeCaptionLedger.publish_caption` | 7203 | 121 ms |

The Run snapshot is not the pause. `capture_run_snapshot_input` was 17 calls and 6.5 ms, against an 84,341-byte input.

The age cost is the live 800-caption ledger:

- `_equal` hashes both sides. The largest single call was 116 ms, under `_accept_scene_playable_event`, comparing checkpoints. Ten calls under `_validate_scene_playable_source` took 306 ms.
- `_same` is deep equality. 205 calls, 640 ms exclusive.
- `snapshot` copied the ledger 277 times, 464 ms exclusive. 152 of the captures sit on `_capture_scene`.
- `restore_snapshot` ran 9 times and `_restore_scene_snapshot` republished the caption rows: 7203 `publish_caption` calls, 121 ms inside publish and 364 ms for the restore itself. Eight of those restores were reached through `_validate_scene_base` / `_validate_scene_saved` (320 ms). One was `prepare_scene_next` (44 ms).

`_validate_scene_saved` was 656 ms inclusive for 5 calls. `_validate_scene_base` was 429 ms inclusive for 8 calls. The frontier, entry, and registration checks sit above `restore_snapshot` in `_validate_scene_base`. The per-caption `publish_caption` loop is the re-admission under those checks.

The following caption, `line.Day7.A.002`, was 681 ms. Profile persistence was 376 ms of that. It did not rebuild the ledger (`publish_caption` once, 0.1 ms; no `restore_snapshot`).

## Deletion candidate (not applied)

Remove the live re-admission in `SoloReadingSession._validate_scene_base`: the `restore_snapshot` call that runs `publish_caption` once per caption. Keep the frontier and registration checks already above that call.

That is the repeated work on this Accept: 8 of the 9 full ledger rebuilds, inside a function whose caller already holds this session's captured ledger.

Do not change these in that edit:

- `SceneEventContract._equal`. It is the larger exclusive leaf (775 ms), and on this run it is the custody compare across retain, commit, and acknowledgement. This sample does not show it guarding only an outdated choice or a failed save.
- `ProfileManager._persist_candidate`. It is a real profile publication (357 ms on this Accept, 376 ms on the next caption). The written profile hash matches the known acceptance hash.

`prepare_scene_next` still has its own `restore_snapshot` (one call, 44 ms). It is outside `_validate_scene_base` and was not the candidate.

Stale-choice rejection and failed-save rejection did not appear as their own phase in this Accept.

## Checks before any edit

Owner of the candidate: `SoloReadingSession._validate_scene_base`, reached by `_validate_scene_saved` and `restore`. Focused suites that already call that path include `tests/integration/test_scene_day_reading.gd`, `tests/unit/test_scene_content_recovery.gd`, `tests/unit/test_scene_control_continuation.gd`, and `tests/unit/test_scene_player_position.gd`. Read the bodies first. `test_scene_restore_still_refuses_invalid_opposite_endpoint_without_installing` requires a forged beat on the opposite endpoint to fail restore without installing a prefix. A removal that only drops `publish_caption` still has to keep that refusal if the shape and registration checks above the rebuild do not already provide it.

No production file was changed for this measurement. No TLA+ model was added.
