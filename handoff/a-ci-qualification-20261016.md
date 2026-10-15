# Coordinator A — CI qualification, 16 October 2026

This continuation follows Director6195929638. It does not change product design,
live Beads, master, or integration. PR36 remains draft until its integration
checks are satisfied. B's later-caption diagnosis is received; PR37 remains
prepared content, not an installed playable partner fork. C retains the separate
remaining-work reconciliation lane.

## Completed correction: future save-version fixtures

Observable outcome: a version newer than every supported save envelope is refused
with the documented future-version code, without changing input data or refusal
precedence. SaveDocumentSchema and SaveMigrations remain the sole validation
owners. Runtime behavior needed no correction for this failure.

The old tests used version9 as unsupported, although Save9 is already supported.
A Save9 envelope containing legacy Run8 data therefore correctly reports a shape
error. Both test files and both validators are byte-identical between integration
3ae6d9138fb53c388380c78550cf6082eafc0ea3 and prior PR36 head84a0c966.
That is source comparison, not a baseline engine execution.

Exactly four future-version assignments and one comment were corrected in:
- tests/unit/test_save_migrations.gd
- tests/unit/test_save_document_schema.gd

The probes now use SCENE_DOCUMENT_VERSION + 1. Expected error codes, ordering,
source/locator immutability and no-repair checks are unchanged. The explicit
Save8/Run9 mismatch test remains unchanged. No historical fixture, saved data,
production validator, recovery guard or immutable provenance seal was altered.
Independent review approved this exact diff before acceptance.

Source6f837d85e35dcd803d3328531798ce24e302d66f, complete tree
b7fd26ea718e0777594289e963a0cece00ede36e, passed
[cloud run38766739347](https://github.com/Siuuuers/dwm/actions/runs/38766739347),
job116531805522, controllerb429cd75073f749c0d277b2ccddd283ad4f3ffa3.
Cloud freeze8aa463feccb1631a877a0bb7966ed8e9c39b437a has that same tree.

**33 tests / 613 assertions**: migration12/341; document-schema21/272.
Godot4.6.3 standard and PowerShell ran on Windows Actions only. No local engine
or PowerShell execution. Exact source-derived census, positive assertion counts,
zero failures/errors/skips, strict logs, child exit0, public surface validation,
and clean executed source all passed. Both changed source files matched retained
executed bytes. Coordinator independently repeated census/log/exit/hash checks.

[Original ZIP](../evidence/ci_qualification_2026_10_16/schema-cloud.zip):
165282 bytes, SHA256 ea59f92e353c5a3db6749de514d6fde8959c62f4795f3adbeb8ce19392f726fd.
All22 manifest members independently rehashed. See
[verification](../evidence/ci_qualification_2026_10_16/schema-verification.json).
These results are separate from the earlier77/1868 optional-Challenge acceptance;
no repeat or combined whole-project score is claimed.

## Wider CI disposition

Original run38725742391 ended with9 successful,11 failed,2 cancelled and1 skipped
jobs. Earlier snapshots showing pending jobs are historical. This correction and
its focused success do not relabel that run or establish its full persistence or
new-account suite green.

The read-only audits are retained in
[persistence/new-account review](../evidence/ci_qualification_2026_10_16/persistence-review.md)
and [remaining-suites review](../evidence/ci_qualification_2026_10_16/remaining-suites-review.md).
They distinguish source comparison from execution and identify exact next checks.

- The historical Notes provenance reconstruction already lacks fragments3,5,7
  in baseline and candidate (counts1,1,0,1,0,1,0). It needs a deliberate authenticated
  provenance rebase; changing stored hashes would not establish correctness.
  Later whole-GameState hash qualification remains unresolved.
- Bootstrap identity tests create unmounted GameState graphs and repeatedly bind
  a process-wide scene issuer. The earliest tree lookup and issuer conflicts have
  baseline source causes; runtime identity guards must remain.
- Issuer call-site and resolution-kind censuses need explicit current owner/role
  coverage. Merely raising a count would weaken their purpose.
- Legacy health effects and routing assertions conflict with current source.
  Do not invent global effects solely to make historical journeys pass.
- Localization has310 registered IDs, including the two Computer controls, while
  its coverage fixture still expects308. Retain complete per-ID/placeholder checks
  when correcting that expectation.
- Shop/rendered desktop fixtures still use retired IDs, old card counts and a
  numeric index against a dictionary. UI text audit failures require narrow
  localization/audit corrections, not a broad whitelist.
- Day7 performance baseline derivation expects3 admission anchors but current and
  baseline contain2. Re-establish complete-operation equivalence before changing
  this benchmark derivation. No performance comparison completed.
- Hospital and Settings cancellations are not passes. No acceptance claim for
  their uncompleted checks.

The first-Reveal diagnosis is recorded separately below. No source equality alone
is used to classify its runtime causality.

## First-Reveal diagnostic: explicit evidence boundary

Candidate run38767402196/job116534090092 used source6f837d85 (runtime identical
to PR36's accepted optional implementation) plus exactly two observation-only
instrumented files: MinesweeperPresentationPort and the existing click-latency
benchmark. The benchmark stops after its first real Reveal. No product runtime
patch from this diagnostic is included in PR36.

Controller260e78dc79a1b7a7c50852ff31e5d620ebf63bca. Instrumented cloud
freeze4fe56b2d34294ee903508d8f4d9655363b25ef93, tree
77d510ac29db4f428898ab684c39256b66eb42cc. Actual child exit1 and job FAILURE
are retained. This is a failed real first-Reveal observation, not acceptance or
a valid performance measurement. The fresh isolated profile completed New Account,
the registered zh-CN reply and expert-board presentation before Reveal.

The identity mint succeeds. The underlying coordinator returns
`invalid_base_snapshot_input`, with legacy `committed_schedule` and `dating` keys
instead of the required `scene` key. The public panel then reports its generic
`minesweeper_panel_command_refused`. DesktopFirstRevealSnapshotComposer currently
accepts only the exact scene input and pressure-only stats; the legacy producer
GameStateDesktopBoardPort supplies capture_run_snapshot_input from the legacy run.
Both composer and port are byte-identical to integration3ae6d913. These source
facts alone do not substitute for the paired baseline execution below.

[Original candidate ZIP](../evidence/ci_qualification_2026_10_16/first-reveal-candidate.zip):
35098 bytes; SHA25676aae14b294860b728196fb93c7e8d8f8ffe6733bc25e91d33867aa3f7fae779.
All10 manifest members rehashed; both instrumented sources match the exact declared
observations; frozen execution ended with clean source. Only synthetic isolated
test data is present. No generated diagnostic change is promoted to product.

The paired baseline job116534090132 was still in checkout after several minutes.
It was superseded by an identical-probe baseline-only controller using shallow
checkout; candidate execution was not repeated. A cancelled/incomplete old leg
provides no baseline runtime conclusion.

## Completed baseline comparison

[Baseline-only run38768219279](https://github.com/Siuuuers/dwm/actions/runs/38768219279),
job116537280236, controller3a0bdf5d13cdea9f66717c3b16a1d6158a825aa6,
executed integration3ae6d913 with the same two instrumented source files, byte-exact
to the candidate probes. Cloud freeze6ed3b65253f4c366e1c014ec3cf21b453b758527,
tree7b7d28b52a9598f80577425cf2f65e6b4b61c6e7. It returned the identical underlying
`invalid_base_snapshot_input` object and public refusal, with actual child exit1
and job FAILURE. Both diagnostic executions retained clean frozen source and no
script errors. This establishes this specific first-Reveal failure predates PR36;
it does not establish that every failure in all six broad journeys has that cause.

[Original baseline ZIP](../evidence/ci_qualification_2026_10_16/first-reveal-baseline.zip):
35077 bytes; SHA25618e360053633ae81816a34d574f5d0aee2e4687e71778c34e4221e7ba962c019.
All10 manifest members independently rehashed. [Paired verification](../evidence/ci_qualification_2026_10_16/first-reveal-comparison.json)
retains both source trees, original scopes, exit codes and exact refusal objects.
This is diagnostic evidence on instrumented sources, not an unmodified full-suite
baseline run and not a passing performance or gameplay result.

## Recorded direction for the next runtime correction

The approved October9 scene-runtime seam already requires exact scene inputs,
pressure-only stats and no revived calendar/Hospital fields. No new product
architecture interview is needed to decide this family boundary. Preserve the
strict composer; do not admit a mixed legacy/scene snapshot to hide the refusal.

The focused next runtime lane is registered TEST scene NewRun -> retained desktop
first Reveal -> durable accounting checkpoint -> recovery, through existing owners.
SaveManagerDesktopBoardPort currently still supplies route_id=main and an empty
narrative checkpoint; genuine scene context must come from authorized existing
providers, not fabricated scene fields. The old benchmark's unregistered NewAcc
setup is also not a scene producer. That correction and its connected proof are
not implemented or accepted by this report. It must preserve optional Challenge
acceptance and the explicit no-production-story-selection boundary.

Later-caption progression remains B's separate diagnosed gameplay gap, followed by
PR37's prepared partner-fork runtime dependency. No broader merge qualification,
whole-game pass, live Beads closure, master merge or release is claimed here.
