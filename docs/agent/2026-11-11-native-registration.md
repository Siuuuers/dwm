# Decode bundled story registration with the native Variant parser

Base: 29d8ff273e560e668bc7e6ca5d08e0ce4619bba7 (PR #281).
Outcome: remove scripted decoding cost before title while preserving registration
values, integer types, canonical fingerprints and old-save loading.

## Smallest change and its boundary

DialogicEntryManifest._select_startup_fixture uses str_to_var for its two bundled
registration paths. It checks the Variant root is a Dictionary before passing it
to existing configuration. Fixture restrictions, cached failures, structure
validation, freezing and fingerprints remain unchanged. The small story-start
order file and all player-save decoding still use StrictJson.

The generated registration is JSON syntax compatible with Godot's Variant parser.
This is a bounded authored-format shortcut, not a replacement JSON implementation.
The source comment states the limit. Godot documents str_to_var as Variant text
decoding: https://docs.godotengine.org/en/4.6/classes/class_@globalscope.html#class-globalscope-method-str-to-var
No resource format, generated file, dependency, cache or serialization layer was
added. ExportSevenDayRegistration continues to use CanonicalJsonWriter.

Before editing, inspect both files, generator output, startup callers and save
identity consumers. Relevant failures are numeric type changes, altered string
escapes, changed registration fingerprints and old-save admission failure.
Independent read-only review found no owner/caller blocker. It identified missing
escaped-string coverage in the current data; the permanent test now covers it.

## Decoder evidence

One Linux Godot 4.6.3 process, retained file text, three strict/native comparisons
per file. Every recursive value and type matches; whole canonical encodings match.
There are 19173 visited values in the shipped registration and 257 in the fixture
per comparison. Counts in the raw probe accumulate across comparisons.

| File | Strict decoder | Native decoder |
| --- | --- | --- |
| Shipped registration | 202.471 / 225.778 / 204.418 ms | 11.910 / 19.130 / 18.273 ms |
| Debug registration fixture | 6.792 / 6.054 / 6.470 ms | 0.181 / 0.206 / 0.186 ms |

Shipped canonical SHA256 remains
b781c82f35fff2dadfd0384d19195436e2cf398c52ab278ba9ef6f3d16c63817.
Fixture canonical SHA256 remains
72d5625588259c36e33ea81d343d6742cc34fa20b5e6d291d5fdff14edabc37c.

Permanent tests in test_dialogic_entry_manifest compare both files with StrictJson
using the existing recursive typed comparator and canonical hashes. A separate
CanonicalJsonWriter roundtrip covers authored quotes, backslashes, newline/tab,
Chinese/emoji, integers, fractional/exponent numbers, booleans and nulls.

## Whole-operation observations

Fresh user folders; same imported Linux source checkout; sequential engines.
Six startup runs use B,C,C,B,C,B; four immediate-title-click journeys use B,C,C,B.
No instrumentation in these runs. Ready-control observations are not rendered
first-paint or input-to-photon measurements.

| Observation | Baseline | Candidate |
| --- | --- | --- |
| Title-ready median, three samples | 3.814204 s | 3.721947 s |
| Runtime-ready median, three samples | 5.835605 s | 5.739954 s |
| Launch to usable caption, two samples | 5.942440 / 5.989489 s | 5.608963 / 6.223078 s |

The decoder-only reduction is clear. Whole-operation ranges overlap; one candidate
caption observation is later. This small noisy sample does not establish a fixed
player-visible saving or a tail-latency guarantee. All four journeys reached the
exact fully revealed opening caption, acknowledged/native-complete/input-unblocked,
then opened Computer without changing the caption. One baseline startup logged
an ObjectDB shutdown warning; the other startup and early-click runs were clean.

## Focused acceptance and reproduction

Six tests, 330 positive assertions, no errors or warnings in final focused logs:

- Decoder parity and authored-value roundtrip: two tests, eight assertions.
- Existing shipped default loading: one test, five assertions.
- Direct Load with real storage/identity/current settings: one test, 46 assertions.
- Old-decoder bilingual play/save: one test, 231 assertions.
- Fresh process using native decoder loads that save: one test, 40 assertions.
  Existing checks include file hashes, Profile preferences, witnesses and library.

The initial harness mistakenly put DWM_TEST_ROOT outside .godot/phase2r_tests,
triggering normal staged startup during unit tests and teardown/missing-owner
errors. Correct the harness root, then rerun all focused checks. Both attempts
are retained; only the corrected run is acceptance evidence. No production fix
was made for this harness mistake.

Evidence: tools/player_latency/evidence/2026-11-11-native-registration. Copy scripts
to .godot/ci/native-registration and rename *.gd.txt to *.gd. Run probe.py for
decoder comparison, checks.py for focused tests, compare.py and early.py for
matched journeys, and cross_load.py for old-create/native-load. Use fresh user
folders and one engine at a time. Scripts that switch source/config restore bytes
in finally. cross_load.py deliberately shares storage between its two processes.

Skipped Windows export, raster tests, full historical manifest mutation suites,
new injection campaigns and lint additions. There is no layout or new public API
change. No generalized parser replacement or speculative hardening was added.
The remaining roughly 210–231 ms registration configuration/validation span from
PR #281 is a separate possible investigation; it was not removed here.
