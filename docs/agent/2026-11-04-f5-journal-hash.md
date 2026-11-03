# Avoid duplicate stable-bundle hashing for captured saves

Measured baseline: `372c6f807e81addaa250743613a2d48dc8464c87`.
[Raw paired results](../../evidence/performance/f5-journal-hash-2026-11-04/comparison.json)
contain all 12 samples, source hashes before/after every process, log hashes,
starting Git tree, summaries and individual pair deltas. Logs remain temporary;
their complete `DWM_F5_LATENCY` records are preserved in the JSON.

## Change and boundary

A captured Save already binds its inputs and journal backup to hashes. Previously
it also hashed the earlier stable bundle during preparation and again at commit.
The candidate omits that additional stable-bundle check only when the prepared
action has a `journal_candidate`. Captured inputs and journal backup are still
rechecked. Saves without a capture provider retain the stable-bundle hash/check.
Target revision, consent consumption, quick-condition checks, document validation,
atomic write and post-write journal commit are unchanged.

Error precedence changes: if recapturing inputs fails while the prior stable bundle
has also changed, the captured path now returns that capture error before it can
report `stale_backup_source` through journal comparison. Neither case permits a
write. This report records the difference rather than claiming identical errors.

## Matched result

Six pairs ran sequentially on one Linux X11 llvmpipe runner: three first-save and
three fourth-save pairs. Each process had fresh storage. Pair order was baseline /
candidate, candidate / baseline, baseline / candidate within each case. Profiling
was disabled; no other engine jobs ran during the measurement window.

| Median, milliseconds | Baseline | Candidate |
| --- | ---: | ---: |
| First Save: input dispatch | 47.557 | 42.476 |
| First Save: completed rendered frame | 76.611 | 68.968 |
| Fourth Save: input dispatch | 50.339 | 42.433 |
| Fourth Save: completed rendered frame | 74.279 | 64.886 |

All six pairs improved dispatch and completed-frame time. Median paired frame
improvement was 7.643 ms for first Save and 8.558 ms for fourth Save. First-save
frame ranges were 65.349–109.300 ms baseline and 63.234–74.272 ms candidate;
fourth-save ranges were 66.749–74.991 ms and 58.191–65.883 ms. One first-save
baseline sample was much slower; its 35.028 ms improvement is not typical.

The maximum process-frame-gap metric improved in five pairs and regressed by
2.192 ms in one fourth-save pair, despite that pair's completed-frame improvement
of 8.558 ms. Do not claim every timing metric improved. Three pairs per case do
not establish tail latency or predict a fixed speedup on other hardware. The
whole-operation difference includes scheduling and I/O noise; it is not a direct
measurement of the isolated hashing cost.

All 12 samples passed durable-save and unchanged-reading/gameplay assertions:
25 per first-save sample, 28 per fourth-save sample, 318 total. All retained six
capture callbacks. This is a small source-check reduction, not fewer captures.

## Reproduction and provenance

Only `autoload/SaveManager.gd` was swapped. Each process checked its exact SHA256
before and after execution and required the tracked diff against baseline to be
empty or contain only that file. The benchmark and BackupPresentationPort hashes
were also unchanged before/after each sample. The candidate file was restored at
the end; no temporary baseline source remains in the working tree.

For pair indices 0–2, run `fresh` then `repeated`; reverse variant order at index 1.
Copy the selected source version into SaveManager, then use a unique label:

```bash
export DWM_F5_CASE=fresh DWM_F5_PROFILE=0 LIBGL_ALWAYS_SOFTWARE=1
label=fresh-pair-0-baseline
export DWM_TEST_ROOT="$PWD/.godot/phase2r_tests/save-comparison/$label/test-root"
export XDG_DATA_HOME="/tmp/dwm-save-comparison/$label/data"
export APPDATA="/tmp/dwm-save-comparison/$label/appdata"
export LOCALAPPDATA="/tmp/dwm-save-comparison/$label/local"
/tmp/dwm-tools/bin/xvfb-run -a -s '-screen 0 1920x1080x24' \
  /tmp/dwm-tools/Godot_v4.6.3-stable_linux.x86_64 --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --audio-driver Dummy -s res://addons/gut/gut_cmdln.gd -gconfig= \
  -gtest=res://tests/manual/benchmark_f5_save_latency.gd -gexit -glog=1
```

The local Xvfb wrapper starts a fresh virtual display. These environment tools
are not new repository dependencies. The fixture is a short test-authored scene
and empty host; fourth Save is at the same reading position, not longer history.
This is not Windows, physical-display latency or a full authored-week workload.
Missing libspeechd, unsupported VSync, and exit ObjectDB/resource warnings occurred
in both variants. Accepted runs had no script errors. No faults were armed.

The earlier unpaired baseline report's assertion counts are corrected alongside
this report: 25 first-save / 28 fourth-save, 159 total for its six samples. Its
timings are not mixed into this matched comparison.
