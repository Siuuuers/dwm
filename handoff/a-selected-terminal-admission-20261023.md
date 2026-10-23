# Selected terminal admission — 23 October 2026

Continue cloud-only Windows / Godot 4.6.3 standard. Read AGENTS.md and CLAUDE.md.
User requests autonomous work, minimal meaningful verification, and smooth flow.
Do not merge diagnostic controller changes into product, change master/PR51, or upload Steam.

## Sources and scope

Previous accepted boundary: `handoff/a-authored-late-continuation-20261023.md` at
`15a442132325ca897fa5f473a01b48daa3f78fc2`. Its late recovery/replay and exact-source
export passed run39929612232. The earlier uninterrupted full-week run remains failed.

Candidate branch: `codex/selected-terminal-admission-20261023`.
Runtime commit: `22415748662b377725cc2c617b8cd26b8d561832`.
Candidate including focused test: `97c28899f0913d14dc80644f3ab56b1354ec87c7`,
tree `042f5c98cdcfb3060e063b227ccda503146ac3ba`.

The three-file runtime change adds selected terminal admission using manifest-owned
immutable structural tables. Fresh receipt, issuer, creation-owner, physical Profile,
source/trigger, hash/order and reconstructed-record checks remain. Generic arbitrary
bundle APIs retain their validation order. Only RunSnapshotSchema terminal reading
and FrozenRunContext terminal admission switch callers. No saved schema, checkpoint
policy, cross-call proof cache, or GameState ending creation change.

Independent runtime/test review found no blocker. The genuine-root test compares
generic/selected results and two fewer structural validations with unchanged receipt
and physical proof counts; it rejects later altered receipts, issuer, record, owner,
arbitrary bundle and physical Profile. Profile bytes restore immediately and in
cleanup. The changed trigger hash test fails at the record fingerprint gate; it is
record-tamper coverage, not an independent trigger-hash-join test.

## First qualification passed

Controller: `codex/terminal-admission-controller-20261023`, commit
`1ea1607eab1dbcb9c625b9752bd77af310e26c12`.
Run: https://github.com/Siuuuers/dwm/actions/runs/39940374828

Run39940270641 was intentionally superseded during import: review caught that the
Save helper does not handle occupied-slot overwrite confirmation. The corrected
paired helper saves to empty slot3 and preserves slots1/2. No product bug was inferred.

Run39940374828 passed all seven generic lifecycle tests, genuine selected authority
(76 assertions), baseline Load/Save (112 assertions), candidate Load/Save/ending/NewGame
(342 assertions), and exact-source Windows export with isolated headless startup.
Original journey artifact and inspection are retained under
`evidence/phase_2r/terminal_admission_20261023/run39940374828/`.
The compact export evidence preserves original logs, validation, build hashes and
origin; it omits the 110MB build archive. Export scope is not graphical release acceptance.
Broad matched Load:659.310s to592.007s; Save:574.619s to504.624s. Structural calls
Load1186 to848, Save1175 to835; receipt/physical counts470 and447 stayed unchanged.
These are one-pair broad harness timings, not exact UI latency. Three native
screenshots were inspected: ending restore, completed title, fresh Day1.

Baseline uses the prior runtime from15a44213; candidate uses97c28899. Both use the
same diagnostic helper and isolated byte-identical copies of the committed genuine
post-replay40-file root (SHA256
`82251bc333baaccdc4c1de38fb175f72b411466b8c4583d41e8fc7fc09edc029`). Slot2 is the
ending source; autosave is fresh Day1. Proof.user_dir is relocated in memory only.
Only three runtime files are swapped for baseline; candidate runtime is restored
and checked before its measurement. Each process retains the1800-second deadline.

Read completed JUnit/process results, terminal-comparison.json and native screenshots
before acceptance. Fewer structural calls alone do not prove wall-time improvement.
The candidate completion is replay from a genuine ending save, not a full-week pass.

## Second isolated candidate and qualification

FrozenRunContext.validate() authenticates `_validate_scene_terminal`, then calls
public validate_reading_checkpoint(), which authenticates it again. Each terminal
pass also validates the retained source checkpoint and receipts. A private shared
checkpoint body could remove the duplicate within that one call while public
checkpoint validation stays fresh. This is implemented in the second isolated candidate; it is not yet qualified.
Existing Save/completion profiles show substantial inclusive receipt validation
time; they do not isolate the exact benefit. Do not add overlapping scope times.

Master was checked atd2062f8d; it does not contain the selected terminal API.
No merge or Steam upload occurred.

Second candidate: `codex/terminal-once-candidate-20261023`, commit
`5360c82e386698d6779f7b4cc63df3a07b9c0fe6`, tree
`801046ea4284d9afb21b76b023d0aad3377d8725`. Five runtime lines added/one replaced
in FrozenRunContext; public checkpoint API stays fresh. Between terminal
authentication and the private body are only Dictionary reads/type checks, no
callback/await/mutation. Independent runtime/test review passed. Added focused
full/direct equal nonzero proof-count, source/receipt/Profile freshness, empty
checkpoint and terminal-first error-order checks.

Second controller: `codex/terminal-once-controller-20261023`, commit
`ad5b810954e267c9a764aa94ecba6d995bcc09fd`.
Run: https://github.com/Siuuuers/dwm/actions/runs/39943584240
Baseline runtime97c28899, candidate5360c82e on the same runner. Candidate measured
Load2/Save3 is separate from fresh-process Load3/replay/NewGame; each native child
keeps1800seconds. Generic lifecycle suite is not repeated. Controller-only
pair-next.gd adds scalar UI press-return timings and Load-action-to-Ready signal
timing without new waits/validation/screenshots. These still include existing
input-frame waits and must not be called exact rendered latency. Broad parent
Load/Save timings include test-only capture/assertion work.

Second controller retains full baseline/candidate user roots as ZIPs with one hash
each, plus compact logs/JUnit/screenshots/results, including on failure. Do not
reconstruct save authority from diagnostic snapshot JSON. First controller lacks
root retention. Both push triggers must be retired after qualification. No new
product adoption has happened yet.

## Corrected second controller

Run39943584240 failed in controller discovery: pair-next.gd overrode the inherited
test name, and GUT collected both method descriptors. The first actual Load/Save
passed, then duplicate startup failed with mutation_gate_already_configured. Do
not accept its corrupt four-phase result as a qualified comparison.
The controller-only correction removes the wrapper, checks GUT method discovery
without instantiating services in seed.gd, and lowers passing-assertion verbosity
from2 to1 for both variants. Candidate runtime is unchanged.
Corrected controller4b6a1450698d04ab39836b620a327e0bd91594fb;
run https://github.com/Siuuuers/dwm/actions/runs/39946595362 .
It has passed discovery, focused authority and baseline; candidate Load/Save and
fresh-process replay are active. Final comparison and export remain pending.

First controller's push trigger retired at2fbe7eae1b2d4639175f4f035a436beb9caab73a.
Second trigger remains active until qualification completes. Product adoption
is still pending; master/PR51 remain untouched.
