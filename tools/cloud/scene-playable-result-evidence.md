# A: scene playable result contract, bounded cloud proof

This is a contract-only implementation checkpoint, not acceptance of the full
caption-to-playable forward producer. It follows D's cleared design in PR #1
comment 6084858528 and `docs/design/2026-10-09-scene-playable-forward-review.md`.
The design document's older proposal status is superseded by D's later approval.

## Exact source and cloud execution

- Product source: `09addba8b544e21753846f2002880a7826b85f31`.
- Source tree: `b8508742f46c7fb7deb5e576e6d5c6490ee352ec`.
- Single parent: `a991b5256d88275debae051a61a7ee23494c868e`.
- Test controller: `eaf2229d24f408ad2152a1423d5139d8058c1d36`.
- Actual test event: `548cf752d0c0fb407e79bf27556b4ff48272c139`.
- [Completed cloud run 37979744715, attempt 1](https://github.com/Siuuuers/dwm/actions/runs/37979744715).
- [Completed successful job 113986915428](https://github.com/Siuuuers/dwm/actions/runs/37979744715/job/113986915428).
- Windows 2022, Godot `4.6.3.stable.official.7d41c59c4`, standard GDScript.
- Engine archive SHA256: `e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90`.
- Engine console SHA256: `63b3b2208819714c9677fbfdd8217c5b7dee8ecf5f383502e826bc9e2227ff5a`.

Exactly two product paths changed: `scripts/domain/narrative/SceneEventContract.gd`
(8 insertions, 1 deletion) and `tests/unit/test_scene_event_contract.gd`
(129 insertions). No new manager, ledger, saved capability, save schema, runtime
Start/End handling, Profile mutation, or production workflow change.

The added exact result is `{kind:"challenge_playable", challenge_occurrence:H}`,
where H is the existing canonical JSON SHA256 of `[scene_occurrence, challenge_id]`.
It accepts only the inspected schema2 registered playable envelope, requires both
members, refuses extra members/types and wrong/nonlowercase hashes. The closure
ledger join additionally requires that exact playable result and occurrence,
retaining the existing same-source/challenge and earlier-ordinal checks.

## What ran and what it proves

The existing contract script's 18 tests plus 7 new tests ran: **25 testcases,
264 assertions, 0 failures, 0 errors, 0 skips, no strict import/test script errors**.
Declared test names match JUnit exactly. Tests cover the structural result,
malformed/extra fields, registration/kind/version/payload joins, independent fixed
hash vector, occurrence derivation, unchanged semantic receipt under token
replacement, exact anchor checks and detached inputs/outputs. Existing legacy
contract and structural closure tests remain present.

These tests use structural TEST fixtures. They do not authenticate a real issued
scene admission, prove current native token custody, execute the complete
receipt-ledger closure join, commit a Run9/Save9 destination, or demonstrate a
rendered/fresh-process playable journey. Token replacement is semantic identity
proof only; live authentication remains the application port's responsibility.

The current GameState runtime producer still refuses `challenge.playable` with
`scene_event_owner_unavailable`. This partial result vocabulary does not enable
that marker through the existing notification/transition persistence path.

## Original artifact retained verbatim

`original-scene-playable-result-37979744715-1.zip` is the original GitHub artifact,
not a rebuilt log package. Artifact ID **11640677076**, **8,099,152 bytes**, SHA256
`243aea0cedaf357140d70c73dfa4813f6f9bd632bad485d4129b5bf7f2ecdfc4`.
It retains import and test logs, original JUnit, isolation JSONL, source/engine/
publication receipts, exact source patch, source-inspection ZIP and hash manifest.
All **10 manifest-listed members** were rehashed against original lengths and
SHA256 values. The manifest is the eleventh member and does not hash itself.
The downloaded archive was independently checked by the coordinator's static
archive/XML inspection and this cloud retention job. This is not an independent
D source review or another game test run.

`retention-verification.json` reports preservation checks only. Its run adds no
engine execution, test cases, runtime acceptance or benchmark evidence. Original
cloud results retain their original source/controller/run identities.

## Resume A without repeating completed work

A's PR #27 product branch was fast-forwarded, with expected-head protection,
from `a991b525` to this exact tested source. PR #1 remains the draft umbrella;
no PR was merged and master was not changed. C's desktop/app-registry paths,
F's deletion fence and Beads status were not changed. Do not close the full
playable milestone from this contract result.

The next coherent implementation remains the approved genuine immediate-caption
producer: hold and privately retain authentic native source; stage Reading5 via
ReadingTraversalOperation; persist the complete source checkpoint; atomically
commit the exact destination checkpoint with its playable receipt through the
existing owners; consume acknowledgment and adopt held native control without
marker execution; then verify same-file fresh-process Load, idempotence and
source-write/destination-write/post-commit-adoption failures. No shortcut through
a permissive control guard, copied parked dictionary or synthetic native proof.

Finish compatible source/caller audits before the final finite acceptance gate.
D's independent review of this incremental diff is not claimed here. C app
composition/execution, Challenge physical Start/End, selected absence, Contacts,
production/rendered acceptance and release remain separate work. No local Godot
or PowerShell run, no subagent execution and no broader accepted-lane rerun.
