# Save/Load caller attribution — 24 October 2026

[Run 40096860109](https://github.com/Siuuuers/dwm/actions/runs/40096860109) passes the two **current** native cases (112 + 101 = 213 assertions), with three process exits 0. Historical retained-input reports are excluded. Diagnostic runtime `f0a6285168f86a95cdb58f65c4299d174e52b1d3` is based on master `a5a7da03b9573ab2d751129de0063027dd2d2d50` and differs only by 49 instrumentation lines in three files. Recorded source hashes reproduce from Git, and recorded runtime hashes match them. Controller `755f595990e677fdd1d0048b798301469a28894c` uses checksum-pinned Godot 4.6.3 on Windows, rendered GL compatibility/Dummy audio. This is source-project attribution, not an optimization result or Steam acceptance.

The freshly written history-free slot is 448,631 bytes, SHA-256 `c22a4fc5408989e6cad8bffa682827b1f83c12c24260115e5e7f4e17d207fc07`. Its snapshot matches the creator proof. A distinct process restores the ending caption completely (native event DONE, visible ratio 1, not revealing). The measured Load scope is 48.661 s; input-to-Ready is 45.077 s. These diagnostic times include instrumentation and have no matched baseline.

## Eight complete snapshot validations

All eight retain checkpoint sequence 72, ENDING/PRIMARY_PENDING. The exact caller stacks and phase records are in `analysis.json`.

| Ordinal | Boundary | Inclusive seconds | Canonical input |
| --- | --- | ---: | --- |
| 0 | Selected Save9 admission through SaveMigrations | 3.663 | source |
| 1 | Route restore-context derivation | 3.669 | source |
| 2 | Narrative restore participant preparation | 3.642 | source |
| 3 | Continuation journal prepare_intent | 3.645 | source |
| 4 | Continuation journal commit_intent | 3.678 | source |
| 5 | Identity allocation source-context load | 3.772 | source |
| 6 | Remapped Run application | 3.793 | remapped |
| 7 | Checkpoint journal seed commit | 3.872 | source |

Ordinals 0–5 and 7 share snapshot canonical SHA-256 `86b6f0fa25b3bea371da64aade21fe04d775c74d8b46843fd5c52060ec348fe3`. Ordinal 6 instead has `54aa1c1e5acd86dbdb24796974361c2f233ec5b0a0c298d6960bbbb040e7c210`: SaveManager substitutes the remapped destination snapshot before GameState applies it. The journal later commits the saved source seed. All use registration hash `33be6b0a64cbad7105dcd397e10a5be0ff7b90e0fb27d8100380a2050a1eb33a`. Equal checkpoint numbers therefore do not mean equal inputs; equal canonical hashes still do not prove unchanged external state across callbacks.

Snapshot validations total **29.734 s**, including **1.179 s** explicitly recorded metadata overhead. Their phases are inclusive: pre-semantic 16.127 s, semantic 9.933 s, guard preparation 1.227 s and guard verification 1.184 s. Do not add the following nested detail to those totals:

| Nested phase across eight calls | Seconds |
| --- | ---: |
| Terminal reading validation | 8.334 |
| Semantic Frozen validation | 7.121 |
| Direct snapshot receipt validation | 4.316 |
| Semantic anchor validation | 1.254 |
| Source reading validation (inside terminal reading) | 1.138 |
| Semantic Profile assignment / attempt checks | 0.000096 / 0.000750 |

The enclosing scope also records 42 receipt validations (18.281 s), 50 bundle validations (6.371 s) and 42 physical proofs (4.884 s), all successful. These overlap the phases above. The near-zero final semantic attempt check does not mean physical Profile work is free: receipt admission performs its own physical creation proof earlier.

## Next bounded target

**Investigate the duplicate nonempty-terminal Frozen validation before the final semantic Profile/anchor checks.** `RunSnapshotSchema._validate_scene_reading` returns `FrozenRunContext.validate_reading_checkpoint` output. For the nonempty terminal checkpoint measured here, `GameState._prepare_scene_snapshot_semantics` immediately calls `FrozenRunContext.validate`, which executes the same terminal authority and checkpoint body. Between the first result and the second call, the existing path only hashes/copies arguments and reads/compares the already-selected registration; no owner callback intervenes. This is a narrower potential reuse interval than carrying a restored reading session across later Profile callbacks.

A candidate must bind the actual GameState/issuer/creation owner, consume only that call's fresh detached Frozen output, retain assignment/physical/anchor validation and mutation detection, and preserve fresh public semantic/Frozen entry points. Empty terminal checkpoints have a different path and must retain their existing fallback. No persistent cache or caller-supplied trust flag follows from this evidence. Retain or explicitly justify refusal ordering; test changed receipts, source history, physical Profile, owner replacement, input mutation and authenticated missing anchors.

The eight outer validations also cross participant, storage and identity-allocation boundaries. Their equal source hash does not justify deleting them wholesale. The earlier terminal source-session reuse hypothesis is a lower-priority target: its final anchor phase accounts for only 1.254 s and spans callbacks.

Existing coverage to extend: `tests/integration/authored_terminal_admission_checks.gd`, `tests/integration/test_scene_saved_event_anchor.gd`, and `tests/unit/test_scene_terminal_snapshot.gd`. These records select the next audit; they do not claim a candidate is implemented, qualified, faster, or ready to merge.

## Owner and refusal audit for that next candidate

Line references below use baseline `a5a7da03`, not the diagnostic's shifted lines.

The successful paths are structurally equivalent for a **nonempty Dictionary terminal checkpoint**: `FrozenRunContext.gd:44–61` and `:101–107` both run `_validate_scene_terminal`, then `_validate_reading_checkpoint_body`, then attach the terminal result's `scene_commands`. The `require_complete` argument does not affect the terminal branch. `RunSnapshotSchema.gd:972` returns the direct checkpoint result unchanged; `GameState.gd:4280` repeats the full API.

A reuse implementation must capture the relevant owner identities **before** the first qualifying Frozen call and recheck them immediately before consuming its output. The first call itself contains issuer/creation callbacks. Merely finding that current owners agree afterward could accept a different group that was installed during that call. Require the same actual GameState instance/script, schema issuer, creation SaveManager, GameState issuer/root SaveManager and Frozen binding; otherwise take the existing fresh path. The existing checks at `RunSnapshotSchema.gd:923–933` and `GameState.gd:4272–4274` are useful ingredients, not a complete retained-proof lifetime check by themselves.

The interval after the first result consists of success checks, canonical hashing/deep copying and already-selected registration lookup/equality (`RunSnapshotSchema.gd:885–911`, `GameState.gd:4268–4274`, `DialogicEntryManifest.gd:158–174`). The subsequent Profile calls (`GameState.gd:4290–4295`, `:5485` onward) are outside that interval and remain in place. Anchor validation should continue through the original bridge path; this proposal does not retain the earlier reading session across Profile callbacks.

Preserve refusal order: direct terminal receipts precede audio/reading; Frozen terminal authority precedes malformed current checkpoint; semantic issuer/registration checks precede consuming any retained output; Profile checks precede anchors; detached-argument mutation wins over semantic/anchor refusal (`RunSnapshotSchema.gd:914–919`). Empty-checkpoint behavior differs between the two Frozen APIs and must not use this equivalence.

Required added coverage includes owner replacement during the first validation (including a coordinated replacement of all otherwise-matching owners), standalone public-call freshness, empty-checkpoint fallback, detached returned commands, Profile callback bridge replacement, mutation precedence and authenticated absent/wrong-catalogue anchors. The existing terminal admission suite already tests changed physical Profile and fresh public entry. A retained proof is never a supplied Boolean or cross-operation cache. This owner-focused candidate remains **unimplemented and unqualified**.
