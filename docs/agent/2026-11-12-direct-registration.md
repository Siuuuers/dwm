# Direct shipped registration tables

Base: 4cd4d25efbc88977b3b3011034bd7c28e232b50f (PR #283).
Outcome: initialize shipped lookup tables without re-encoding or revalidating
build-checked registration. Retain the existing save/content fingerprint exactly.

## Investigation and retained responsibilities

The registration fingerprint is used by RunSnapshotSchema content normalization,
FrozenRunContext, reading-session binding and Scene admission. Calls to
scene_registration_fingerprint return the cached string; they do not rehash it.
Removing that identity would alter content-update and Save/Load decisions.
Programme/content and caption identities have separate consumers and are not
retired by this change. The shared CanonicalJsonWriter remains unchanged.

Before editing, a Linux Godot probe encoded the shipped parsed bundle three times
and compared it to the existing file text excluding its one final newline.
The bytes and SHA256 matched exactly. Encoding took 48.351–52.132 ms; direct text
hashing took 2.878–10.289 ms. This isolated comparison is diagnostic, not a complete
startup speed claim. Earlier attributed encoding spans are not added to these
measurements; they came from different runs.

## Smallest complete change

Startup retains the registration text already read for decoding and hashes it once.
The existing DialogicEntryManifest owner detaches the bundle, constructs the five
lookup indexes and marker bindings directly, attaches the generated passage data,
and freezes owned tables. Index rows reference the owned bundle, not caller data.
No new file format, runtime cache owner, manager or dependency is introduced.

Full structural validation and canonical re-encoding are retired from shipped
startup. Debug fixture configuration retains full authored and structural checks.
The generic validator still serves independent caller-owned bundles. One retained
registration hash supports existing save/content identity; live lookups use the
prepared immutable tables.

Both exporters structurally validate before writing. Normal export validation and
the exact-PCK audit require exact canonical text plus one newline and compare its
raw-text hash with the validator fingerprint. Full authored and passage checks
remain. This matters because authored validation is not a strict superset of
structural checks (for example their minimum mine-count rules differ).

Failure scope: wrong direct indexes/marker bindings, changed identity from text
formatting, freezing caller-owned data, stale generated output, and baseline saves
failing candidate Load. No hypothetical external-content recovery was added.

## Verification

Seven focused tests passed with 387 positive assertions: ownership/direct-table
parity (21), validator table detachment (8), canonical fingerprint behavior (36),
direct Load (46), passage display (5), baseline bilingual play/save (231), and
fresh-process candidate Load (40). The ownership check also uses the existing
profiler to assert zero structural-validation calls during shipped startup.
It compares all direct tables/marker bindings and the fingerprint with the generic
validator, verifies frozen owned tables, and verifies caller data remains mutable.
No additional regex lint or new profiling infrastructure was added.

Six uninstrumented fresh-user journeys used B,C,C,B,C,B. All reached the exact
fully revealed opening caption, opened Computer without changing it, and returned
all 22 passage captions. Four separate instrumented startup probes used B,C,C,B:

| Observation | Baseline | Candidate |
| --- | --- | --- |
| Registration selection | 137.436 / 139.862 ms | 30.338 / 33.328 ms |
| Title-ready median, three samples | 3.906407 s | 3.333694 s |
| Runtime-ready median, three samples | 5.942498 s | 5.405445 s |
| Launch to complete caption median, three samples | 6.241479 s | 5.747927 s |
| First passage lookup range | 0.103–0.165 ms | 0.115–0.150 ms |

The registration cost reduction is clear. Whole caption-readiness ranges overlap,
and differences between their medians exceed the measured removed span: do not
attribute the entire roughly half-second difference to this change. These are
Linux source-project control-readiness observations, not rendered first-paint,
input-to-photon, tail-latency or Windows guarantees. All matched logs were clean.

Normal generation remains byte-identical for every existing generated output;
export validation passes. Terminal generation and independent passage derivation
pass and original files restore. The initial pre-write check rejected builder
StringName keys, which canonical encoding intentionally normalizes. The corrected
check validates the encoded/decoded output before writing; failed diagnostic and
corrected logs are retained. Runtime code did not change during this correction.
Independent owner/build review found no remaining blocker; git diff --check passes.

Skipped Windows export, rendered E2E, broad gameplay/coverage matrices, full
completed-save latency measurement and new injection campaigns. The exact-PCK
script was reviewed, not run as a Windows export here. No gameplay, save format,
shared serializer or public API changed.

## Reproduction

Evidence: tools/player_latency/evidence/2026-11-12-direct-registration. Copy scripts
to .godot/ci/direct-registration, renaming *.gd.txt to *.gd. Use imported Godot
4.6.3 source checkout; one engine at a time. Run checks.py, early.py, configure.py,
cross_load.py and generators.py sequentially. The comparison scripts switch the
runtime sources between base and candidate and restore original bytes in finally.
Generation also restores generated files. Raw logs/XML are compressed and hashed;
user save directories are not committed. probe.gd is the pre-edit encoding/hash
comparison and can run with DWM_TEST_ROOT under .godot/phase2r_tests.
