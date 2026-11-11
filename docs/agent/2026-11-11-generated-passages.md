# Generate passage display data before runtime

Base: d8b70b84c3c51932af4ae67887f207cf6077f7b8, merged PR #282.
Outcome: select shipped registration without compiling a later passage, and keep
first Gallery passage lookup fast. DialogicEntryManifest remains the runtime owner.
The user selected build-owned authored passage checks during this investigation.

## Investigation before editing

Three fresh Linux Godot 4.6.3 startup probes separated the remaining setup cost:

| Span | Range, ms |
| --- | --- |
| JSON domain and header | 18.529–19.615 |
| Four nested canonical encodings | 56.726–72.091 |
| Structure and indexes | 7.555–7.910 |
| Remaining canonical encodings | 14.014–26.922 |
| Passage inspection | 87.769–95.810 |
| Table copy and hash | 3.868–6.146 |
| Freeze and bundle copy | 10.684–11.778 |

These are instrumented subspans, not input-to-photon measurements. The canonical
writer already reused nested encodings; selected immutable bundles already reused
prepared tables. Removing copies would break caller isolation. No such removal
was made. The largest specific avoidable operation compiled the later Day 7
passage during startup.

A deletion-only experiment removed passage inspection from structure validation.
Six early-click journeys passed, but first Gallery passage lookup moved from
0.565–0.601 ms to 25.168–25.897 ms. Reject that candidate: it moved compilation
rather than eliminating it. The evidence includes this experiment separately.

## Final implementation and ownership

The existing authoring exporter derives `data/manifests/scene_passages.json`
from validated compiled dialogue. It contains the existing passage records and
22 shipped captions, not another authored source. Normal generation, validation,
deterministic-output checks and exact-PCK validation cover the new file.
The terminal fixture also generates, backs up and restores both related manifests.

Shipped startup decodes the generated catalogue and checks its root/records shape.
DialogicEntryManifest detaches and freezes those records with its existing tables.
ScenePassageCatalog.inspect returns detached prepared records for that exact
selected bundle. Independent bundles and debug fixture configuration still use
authored compilation. Full authoring validation still checks passage pairing,
linearity, native range and caption agreement. The exporter and packed audit
compare generated values against freshly derived records from a detached bundle.

The discarded startup passage check is retired from structure validation. No
new manager, cache owner, dependency, save schema or story identity was introduced.
Registration bytes and canonical fingerprint stay unchanged. Player-save validation
and persistence handling remain intact; completed-save validation uses the same
prepared catalogue lookup when operating on the selected registration.

Relevant failures checked: stale generated records, caller mutation of returned
captions, unintentional startup/Gallery compilation, changed fingerprint, and
baseline-save loading. Build/package checks own authored/generated consistency.

## Matched observations

One engine at a time, fresh user directories, same imported Linux source checkout.
Uninstrumented journeys used B,C,C,B,C,B. Every run reached the exact complete
opening caption, opened Computer without changing it, then looked up all 22
passage captions. Gallery lookup measures the catalogue call, not rendered UI.

| Observation | Baseline | Candidate |
| --- | --- | --- |
| Registration selection, two separate instrumented samples | 225.562 / 249.629 ms | 148.812 / 152.093 ms |
| First passage lookup, three samples | 0.551–0.718 ms | 0.111–0.136 ms |
| Title-ready median, three samples | 3.552616 s | 3.590082 s |
| Runtime-ready median, three samples | 5.800411 s | 5.634689 s |
| Launch to complete caption median, three samples | 6.167368 s | 5.980091 s |

The isolated registration reduction is clear in these samples. Title readiness did
not improve; whole-operation ranges overlap. Do not promise a fixed launch saving,
tail-latency benefit, Windows timing or rendered first-paint improvement. One
baseline in each comparison emitted an ObjectDB shutdown warning; candidate logs
were clean. No unrelated shutdown change was attempted.

## Focused acceptance

- Seven GUT tests, 378 positive assertions: build/runtime ownership and generated
  parity (12), table detachment (8), canonical identity (36), direct Load (46),
  passage display (5), baseline bilingual play/save (231), fresh candidate Load (40).
- Six matched immediate New Game / caption / Computer / passage-lookup journeys.
- Normal export is byte-identical to committed outputs; fresh export validation
  passes. Terminal export matches independent derivation, then originals restore.
- 47 Python coverage-selector tests pass. Independent caller/build review found
  no remaining blocker. `git diff --check` passes.

Skipped Windows export, rendered E2E (no display server in this environment), a
complete completed-save Load timing run, broad gameplay matrices, new injection
campaigns and lint additions. The completed-save path's shared catalogue lookup
is covered; its full latency is not measured. Exact-PCK guard code was reviewed,
not executed as a Windows export in this session. Source import's GUT update
checker could not contact its version service; acceptance engine logs were clean.

## Reproduction and remaining lead

Evidence: tools/player_latency/evidence/2026-11-11-generated-passages. Copy its
root scripts into .godot/ci/registration-cost; rename *.gd.txt to *.gd. Run checks.py,
early.py, cross_load.py, configure.py and generators.py sequentially. The latter
scripts temporarily switch sources or generated files and restore bytes in finally.
Run profile.py only in the baseline checkout: it instruments the old passage loop.
The deletion-only files retain the rejected candidate's measurements; they are not
final acceptance. Raw logs/XML are gzipped and checksummed; user save directories
are not committed. Scripts assume Godot 4.6.3 and an already imported checkout.

The remaining measured registration work is primarily canonical encoding. A future
pass should inspect its existing contracts before changing it: the shared writer
also owns saved-data identity. No blanket removal of encoding or validation is
justified by this result. Continue in the same session if further work is requested;
there is no architectural blocker requiring a new session.
