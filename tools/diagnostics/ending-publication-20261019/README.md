# Ending accessibility publication: separately built native diagnostic

## Observable outcome and owner

Determine whether the reconstructed prepared AccessKit graph at a natural window
update contains the current ending caption's actual parent-child path from that
window's root, including ancestors retained from earlier complete updates.
The existing `AccessibilityDriverAccessKit` owns those nodes and edges. The
observer reads its completed native nodes immediately before their ordinary
ownership transfer into an update; the game, save owners and UIA driver retain
their existing behavior.

Success for this investigation means a reproducible, source- and process-bound
answer of **connected** or **missing** for the prepared graph. It is not a passing
gameplay journey. Invalid, incomplete or mismatched evidence remains **unknown**.
The raw original player outcomes remain authoritative and unmodified.

This is an explicitly separate diagnostic executable. It is not the previously
tested official executable and will not establish official-engine acceptance.

## Frozen inputs

- Game source: `81847d8b1560340a3a7769223cee0b46c6bdc0f9`, tree
  `4581a9f12d63684836c722f72cffd533491f3c06`, the completed corrected ordering
  experiment. Its original ending gate failed. No game source or harness is
  changed by this diagnostic tool branch.
- Reused artifact: `12146662424`, from [run 39155624496](https://github.com/Siuuuers/dwm/actions/runs/39155624496).
  The inner original ZIP is 99,457,801 bytes, SHA256
  `7c3053d2073fc3caee98dc5c038e720d5e860952375039d0db054dcd14812eb8`.
- The original PCK remains byte-identical: 66,433,104 bytes, SHA256
  `1bbe3794a2febb54960929984556421e04df621f0e21a095f71ea25603147d26`.
  Existing notices remain byte-identical; the diagnostic engine's LICENSE and
  COPYRIGHT notices are added. Packaging does not rerun export/import or claim a
  new pack audit. The prior audit is identified as reused evidence.
- Separately compiled public Godot source:
  `35e80b3a8822a9df9be390814b62f44c0a9c69e8`, tree
  `499fa231ee5d21878988a4a9cb881749def3946d`. Standard release template, Windows
  x86_64, MSVC, static C++ runtime, D3D12/Forward+ and ANGLE enabled, no LTO,
  optional Agility/PIX disabled. The full arguments and actual toolchain are
  retained by the build receipt.
- Expected diagnostic banner:
  `4.6.3.stable.dwm_publication_probe_v1.35e80b3a8`.
  The original banner was `4.6.3.stable.official.7d41c59c4`; its complete source
  identity remains unresolved. The provenance directory retains that limitation
  and the primary source/asset observations. Do not infer source identity from
  a matching release label.

The isolated tools branch adds files only below
`tools/diagnostics/ending-publication-20261019/`. The PR30 controller pins its
commit and tree, checks the original game tree and exact unchanged harness
bytes, and snapshots every new tool file. PR36 remains draft and unmerged.

## What can fail, and what the evidence means

| Observed result | Permitted conclusion |
| --- | --- |
| Build, package or clean Capability/Create gate fails | Native graph experiment was not reached; preserve that failure before attempting a correction. |
| Diagnostic Load does not reproduce the same ending timeout, in-budget zero queries and responsive original window | This executable did not reproduce the original observation boundary; do not transfer a graph conclusion to the original failure. |
| Source/PCK/EXE/archive, process, HWND, caption RID/node, or clock-origin binding fails | Evidence does not establish a common observation; binding remains false. |
| Initial graph or complete required deltas are absent; sequence, topology, limits or stream integrity fail | Graph is unknown. A fabricated missing edge must never be inferred from an incomplete capture. |
| A complete replay lacks the current caption RID under the bound root | The captured prepared graph is missing that caption at those observations. This locates an omission before adapter handoff on this diagnostic executable. |
| A complete replay connects the current caption to the root | Retain the actual ordered parent path, labels, roles, hidden flags and source-update provenance. Root reachability alone does not prove native UIA exposure, visibility, adapter receipt or a successful player action. |
| Stream ends without a footer after forced cleanup | Only a validated complete prefix can be described; final and continuous state remain unknown. |

The same-failure requirement also preserves the original forced-cleanup result:
Load player exit `-1`, driver exit `1`, no clean player exit. A successful offline
reader never converts those values into a passing native journey. The controller
has a separate final gate that fails when an original player gate fails.

## Native observation and replay

`native-probe/PROTOCOL.md` is the full protocol and limitation owner.
`native-probe/source-pins.json` binds its exact baseline/candidate files and
patch. The two engine files have additive probe changes only; the original RID
allocation/free, child pushes, ownership-transfer calls and queue clearing are
preserved. The probe adds no game state, accessibility refresh or observer RID.

The environment variable `GODOT_ACCESSKIT_PUBLICATION_TRACE_PATH` is read once
when the existing driver is constructed. Its absolute path contains literal
`{pid}`. Capability and Create use the same diagnostic native executable with
the probe disabled. Load starts with the probe enabled so the initial root and
all subsequent natural updates can be reconstructed, including retained
ancestors. Updates copy actual C API child arrays after both ordinary and owned
children have been appended. They do not infer edges from Godot node parents.

The independent Python reader in `replay/read_trace.py` applies whole-node
replacements, keeps surviving ancestors, and prunes detached subtrees using the
retained AccessKit consumer semantics. It handles same-update reparenting, large
uint64 identifiers without floating-point conversion, window close/reopen and
initial graph epochs. Unsupported grafts, dangling children, multiple parents,
cycles and orphan replacement nodes are rejected. Each reported parent edge
identifies the update and record that supplied it.

`bind_trace.py` checks the independent replay against original primary streams.
It requires the same executable/package across modes, source snapshots matching
both the build and tool pins, the Load PID and original HWND, a live visible
unwithdrawn current Caption/Canvas, and the existing caption callback's RID,
node identity, intended button role and exact text. The actual native target
label and role are reported separately; role 18 is `ACCESSKIT_ROLE_BUTTON` in
the retained C header. Trailing label whitespace is compared using the original
driver's intended trimming behavior while preserving the raw label.

Caption snapshot ticks and Unix timestamps must be consistent with the closest
bracketing validated native timestamp pairs. An explicit 2,000-microsecond
serialization consistency tolerance accommodates the GDScript floating-point
Unix-seconds representation. This check rejects incompatible clock origins; it
does not attest clock precision, expand a timeout or prove a delivery deadline.
Callback/snapshot/text-completion tick order is checked, and at least one selected
prepared observation must follow the recorded ending text completion.

Selected captures lie between the original wait-start and logged wait-end UTC.
That is the **original failure-observation interval**, not independent evidence
of admission before the strict 30.000-second Stopwatch deadline. The unchanged
driver starts its Stopwatch before recording wait-start and records wait-end
after sampling elapsed time. The original end was 30.0222674 seconds. The binder
retains both original events and each capture's margin to the logged cutoff.
The separate zero-query selector requires its original elapsed completion to be
strictly below 30 seconds.

The native record's capture end precedes serialization, file write, flush and
factory return. These records describe prepared state, not adapter acceptance or
retained adapter memory. Synchronous copying and logging may change timing.
Copied-node time and prior-row write cost are observations with the exclusions
stated in the protocol; they are not negligible-cost or performance claims.
Flush is requested, but durable storage is not certified.

## Execution and checks

Godot, PowerShell parsing/tests, MSVC compilation, package smoke and the native
journey execute only on the cloud Windows runner. Local checks are limited to
Python and static source inspection. Synthetic Python fixtures are explicitly
labeled; they are not native-engine or UIA evidence. Independent caller,
protocol, reader and fixture reviews precede one coherent candidate check.

The original game recovery/receipt diagnostics are complete and are not rerun.
The reused PCK is smoke-tested once with the new native executable in an
isolated profile. The original Capability, Create and Load scripts then run
unchanged with `ProjectDefault`, `Always` accessibility and `Dummy` audio.
The original 30-second action, 480-second journey and 10-minute outer mode
ceilings remain intact. Native compilation has a separate 100-minute ceiling;
the entire build-and-observation job has a 150-minute ceiling.

No save/recovery/history code changes, authentication shortcuts, checkpoint
removal, cross-call cache, gameplay feature, new manager, timeout expansion,
forced accessibility update or repeat hierarchy-query campaign is included.
The measured reconstruction candidate and unsuccessful root-order experiment remain
isolated. This run does not promote either into PR36's product runtime.

## Evidence custody

The controller retains the final native template and build receipt before
packaging, excluding compilation intermediates. It separately retains the exact
derived executable package. Dependency metadata is captured before and after
download; published digests are verified where available. The older ANGLE asset
has no published digest, so its byte hash is recorded as observed, not described
as upstream verified. The static AccessKit SDK header must match the exact
reviewed header.

Original native results/events/stdout/stderr, capture files, complete source
snapshots, package/build receipts and independent replay reports are sealed with
a SHA256 manifest before the complete-evidence artifact upload. A compressed
copy is also emitted in bounded log chunks for durable repository retention.
If the 16-MiB compressed log limit is exceeded, the separately uploaded complete
artifact still includes its manifest and final status. Actions artifacts have
seven-day retention; the run handoff must retain their IDs, hashes and expiry.

Internal reviewers provide source/evidence checks. They are not external
Coordinator C, whose review remains separate. Reconcile PR30/36 comments and
protected heads again before publication. No merge or product acceptance is
implied by a successful diagnostic binding.
