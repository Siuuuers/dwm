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

## Qualification in progress

Controller: `codex/terminal-admission-controller-20261023`, commit
`1ea1607eab1dbcb9c625b9752bd77af310e26c12`.
Run: https://github.com/Siuuuers/dwm/actions/runs/39940374828

Run39940270641 was intentionally superseded during import: review caught that the
Save helper does not handle occupied-slot overwrite confirmation. The corrected
paired helper saves to empty slot3 and preserves slots1/2. No product bug was inferred.

The corrected run passed import, generic terminal lifecycle and genuine selected
terminal authority steps. Baseline Load/Save also passed. At this draft's writing, candidate native ending/
NewGame is active; candidate journey and exact-source export are not yet accepted.

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
