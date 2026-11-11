# Reuse caption registration across scene sessions

## Outcome and owner

New Game and checkpoint Load reuse the validated authored caption indexes. Each
session still owns its token, frozen context, admitted frames, publications and
publication serial. The existing selected-bundle scene configuration owns the
registration lifetime. There is no new global cache or saved-data schema.

Baseline: d0dc49e6bcd759ba9956d9149b377225b32e529c (PR #270).
Candidate runtime/tests/workflow: 8cdd35942341f4e97b296e5e35c053efa65a04ef.

## Investigation before editing

The prior trace measured 19–23 ms per ledger initialization. Trace callers through
begin_scene, scene restore, compact checkpoint expansion and configuration forks.
Registry writes occur only during initialization and restoration adoption. The
registry validator already detaches the document. Session frames and history must
not enter the shared registration, and a failed restore must not adopt partial
state. An arbitrary mutable registry must still be validated on ordinary calls.

prepare_registration now validates once and freezes the three detached indexes.
The configured scene passes this registration to new ledgers and to the temporary
restore candidate. Ordinary callers omit it and retain full registry validation.
Live forks share only these newly immutable maps; their mutable history remains
separate. No reliance on shallow read-only flags, fake session tokens or cache keys.

## Matched Linux measurements

Godot 4.6.3 standard, headless source project. B/C/C/B, separate fresh users,
sequential engines, no source instrumentation in comparisons. New Game starts two
seconds after mandatory runtime readiness. The probe checks exact opening text,
visibility, completed reveal, native completion, presentation acknowledgment and
unblocked input, then opens Computer and verifies the caption remains unchanged.

| Operation | Baseline | Candidate |
| --- | --- | --- |
| New Game to usable caption, ms | 515.788 / 502.494 | 398.616 / 351.528 |
| Median, ms | 509.141 | 375.072 |
| Title first observed, ms | 4459.192 / 3817.800 | 4248.732 / 4032.594 |
| Runtime ready, ms | 6850.887 / 5802.409 | 6197.907 / 5976.337 |
| Immediate Computer, ms | 23.929 / 23.427 | 26.277 / 23.400 |
| First Load to usable caption, ms | 245.099 / 258.409 | 225.752 / 239.611 |
| Repeated Load median, ms | 205.853 | 161.866 |

New Game median improved 134.069 ms (26.3%). This small host sample is not a
Windows performance guarantee. Startup ranges overlap; no startup gain claimed.
One baseline New Game process emitted an ObjectDB shutdown warning; all four
exited 0 without errors. Candidate diagnostic: one registration preparation
18.997 ms, then seven initializations 6–31 microseconds. Diagnostic timing is
separate from the matched uninstrumented measurement.

Load uses the existing authored checkpoint benchmark: one creator, then four
fresh loader processes with identical isolated seed bytes restored before each.
Each loader checks first Title Load plus three in-game Loads. Repeats are
correlated, not independent samples. Timers include confirmation where required;
expected checkpoint expansion is outside the timer. First preparation therefore
is not part of that Load timer. New Game measurements cover preparation as part
of the complete action. No display presentation timing is available headless.

## Focused acceptance

Five suites, separate processes: 52 tests / 1293 test-body assertions in JUnit
(1296 including fixture assertions in GUT summaries) passed.
- Caption ledger: 21 / 252.
- Scene compiler cache: 17 / 586.
- Initial candidate: 6 / 60.
- Joint New Game: 1 / 41.
- Native activation runtime: 7 / 354.

Added checks cover detached nested source values, shared immutable indexes,
separate tokens/frames/publications, restored publication serial, configuration
forks and replacement registration identity. Existing atomic restore checks pass.
Native activation fixture emits its missing self-talk localization warning;
no test errors. Authored Load creator plus four loaders: 5 tests / 4320 assertions,
all logs error/warning-free. Read-only independent caller/ownership review passed.
GameState/SaveManager public API inventories are unaffected. No new lint rule:
these ownership assertions express the invariant more accurately than text lint.

Windows run [43005978203](https://github.com/Siuuuers/dwm/actions/runs/43005978203)
passed on the candidate source SHA above: export, packaged data audit, opening,
Computer, Save and exact fresh-process Load. All three player processes exited 0
normally, no forced cleanup, and no player warnings/errors. Saved/restored opening
screenshots reviewed: exact caption and matching artwork visible, no clipping.

Create launch-to-title observation was 7489.895 ms; early New Game to observed
caption 3723.014 ms; selected Load to observed restored caption 620.190 ms. These
UIA upper bounds include polling/provider waits and are not matched speedups.
No Windows speedup claim: this runner's startup observations differ materially
from prior runs. Forward+/D3D12 Microsoft Basic Render Driver, Dummy audio,
accessibility Always. This is not physical-GPU/audio qualification.
Artifact 13848182854 SHA256:
7c744c44718b482254fb0c62479a7e7559336152c592b565a864a5f64710f35c.
Export ZIP SHA256:
ae5e530f87298cf9e3f57c1857ac1135558bba2c2eba4dc462c85166afca2a84.

## Evidence and reproduction

See tools/player_latency/evidence/2026-11-11-caption-registry-reuse. Logs and JUnit
are gzip-compressed; sha256.json covers retained evidence. Use an imported checkout
with godot on PATH and baseline commit available. Copy compare.py, compare_load.py,
attribute.py and observe.gd.txt (renamed observe.gd) into .godot/ci/registry-reuse.
Run comparison scripts from the repository root, separately, with fresh owned
output/user directories. They temporarily replace the two runtime files and
restore candidate bytes in finally. Do not run concurrent engines or editors.
compare_load.py reuses the existing checkpoint benchmark and retains its seed
locally; no player data is committed. attribute.py is a separate diagnostic.

Skipped: unrelated suites, rendering/font matrix, new injection tests, save-schema
changes and speculative hardening. Windows smoke covers opening, Computer, Save
and exact fresh-process Load for the candidate runtime.

## Next measured investigation

A separate candidate-only phase trace found snapshot input 49.029 ms and initial
reading setup 51.827 ms. Snapshot build was 4.498 ms, all restore plans 6.246 ms,
and transaction dispatch until its pending return 10.190 ms. These spans do not
cover later asynchronous activation. Retain the trace as a lead, not a matched
speedup claim. Break down the first two before choosing further surgery.
