# Checkpoint parsing and validation cost

2026-09-13; base `ac0c4f8da`; Godot 4.6.3 mono; `dwm-634.3` remains open.

Two small production changes reduce CPU work while keeping the same saves:

- `StrictJson` recognizes a complete ASCII string token with valid simple JSON
  escapes before using native decoding. Plain tokens use a substring. Numbers,
  duplicate keys, Unicode escapes, raw Unicode and all failed matches retain the
  existing parser and its diagnostics. The disjoint, possessive regex avoids
  backtracking over long escaped strings.
- `SaveManagerCheckpointPort.commit` validates a detached, text-type-normalized
  candidate after canonical emission succeeds. A successful result seeds the
  existing cache for exactly those emitted bytes. Invalid candidates still reach
  the original strict storage validator. No checkpoint, physical read, hash,
  write, flush, rename, final reread, recovery check or retention rule is removed.

The writer already proves scalar round trips and container composition. A new
root-type guard prevents a caller-edited array/scalar from reaching the typed
schema validator. Failures are not cached or returned early, preserving storage
refusal codes and canonical-error precedence. The proof is rebuilt at commit;
it does not trust the mutable candidate handed out by prepare.

Godot's [JSON documentation](https://docs.godotengine.org/en/4.6/classes/class_json.html)
describes its permissive parsing and numeric conversion. The optimization does
not replace the document parser with native JSON. The exact-version
[string decoder](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/json.cpp)
supports the simple escapes admitted by the token preflight.

## Measurements

The retained `baseline-autosave.json` is an actual isolated benchmark save,
456,379 bytes, SHA-256
`f2435ab5c2fbc0ef94a27540040878dac030b382614306ea6070c8b1215df542`.
Each microbenchmark runs five iterations on those exact bytes and checks that
canonical output remains identical. Medians:

| Operation | Before | After |
| --- | ---: | ---: |
| Strict parsing, fixed save | 189.24 ms | 158.96 ms |
| Current strict parsing + schema, fixed save | 164.11 + 31.64 ms | Direct detached-value validation: 45.01 ms |

Canonical emission remains about 71–73 ms; it is still required. The last row
compares both validation methods in the same final microbenchmark and also
checks type-sensitive result equality. A raw-Unicode regex extension was tested
and removed: all 16,357 string tokens in this save already qualified for the
ASCII path, and the broader range added no measured benefit (165.66 ms).

Corrected full-flow benchmark results, seconds:

| Player boundary | Base | Final |
| --- | ---: | ---: |
| App win to settled | 1.632–1.650 | 1.301–1.509 |
| App loss to settled | 1.496–1.542 | 1.189–1.418 |
| App New Board first reveal, synchronous | 0.778–0.798 | 0.555–0.632 |
| Dating first reveal, synchronous | 0.510–0.545 | 0.357–0.403 |
| Dating win to post-challenge | 0.721 | 0.559 |
| Dating loss to post-challenge | 0.656 | 0.468 |

These are small-sample observations, not frame-time guarantees. Each version has
two fresh isolated processes, one Dating win and one loss; both include an App
win and loss. Both versions ran headlessly with `DWM_CHECKPOINT_PROFILE=1`, on
the same machine. Seeds and save sizes vary. No OS click-to-paint measurement is
claimed. Desktop settlement still has a noticeable pause and needs further work.

The retained `observed-baseline-*` runs use the base production code with the
corrected measurement harness. The final harness adds outcome-match assertions;
the timing code is identical. Both baseline logs show the requested actual
outcomes. The old harness could label a flood-fill win as a routine reveal and
its `settled_after_us` measured only the tail after two frames. The corrected
harness observes the terminal board and adds action-start-to-settled
`end_to_end_us`; old fields remain available. Earlier exploratory logs are
retained but are not pooled with the table above.

## Verification and reproduction

`runs.jsonl` retains actual commands, isolated roots, times and exit codes.
All referenced run logs are kept in this directory. Every full-flow timing run
used the profiling environment variable above; correctness and native restore
runs did not. Timing itself has no pass/fail speed threshold.

The final focused suite passes 104 tests / 1,703 assertions, including the
1,177-value canonical compatibility corpus. Tests compare optimized and forced
strict validation for exact saved bytes, all physical FileOps, journal state,
StringName/typed-container/integer/float normalization, invalid candidates,
corruption, changed rereads, failpoints and retries. Unicode and malformed-token
diagnostics retain exact codepoint-based positions, including long strings.

Both Windows/OpenGL native journeys passed: actual New Account, Slot 1 Save,
Schedule Done, Autosave Load and earlier Slot 1 restoration (13.87 s); and the
seven-day witnessed reply/follow-up/failed echo checkpoint/Pause/Autosave Load/
fresh Next journey (22.12 s). They use real installed controls and public
commands, not seeded save state; they are not physical-input or accessibility
acceptance tests. No screenshots were requested by these runs.

After source freeze, both inventories regenerated with exit 0. Parsed public
contracts match the base, excluding call-site locations: 239 GameState and 74
SaveManager entries. Repository inventory/document gates pass 14 tests / 410
assertions, bringing final distinct totals to 118 tests / 2,113 assertions.
Earlier overlapping test runs are not added again. Existing Unicode diagnostics
and 24 outside-test Dialogic/GUT orphans remain visible in the logs.

Independent source reviews found no blocker after checking exact-text proof,
detachment, type normalization, malformed-input fallback and error precedence.
The final strengthened cached-value/type-sensitive comparison passed as part of
the 104-test run. Broader performance and release Beads remain open.

Run the fixed-file microbenchmark from the project root:

```powershell
& tools/testing/Invoke-IsolatedGodot.ps1 -SuiteId checkpoint-json-micro -LogName checkpoint-json-micro.log -GodotArgs @('-s','res://tests/manual/benchmark_checkpoint_json.gd','--','--document=res://evidence/checkpoint_json_fast_path/baseline-autosave.json')
```

The full-flow commands, including `--dating-ending=win|loss`, are recorded in
`runs.jsonl`. Public game/save interfaces and save schemas are unchanged. No
full-suite or complete-latency-resolution claim is made by this increment.
