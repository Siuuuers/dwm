# Scene Challenge playable: forward-control review proposal

Status: **proposal for D review; no runtime activation or passing-test claim**.
Prepared against A product `63a70e37a6653b622f12336af0da75d13ad50bd6` for the
Director's 9 October 2026, 22:49 HKT review request. This document proposes the
exact missing result discriminator and a bounded forward durability seam. It
does not authorize widening production content, physical Start, Challenge End,
selected-absence admission, Contacts, or desktop composition.

## Observable outcome and ownership

From the actual visible caption immediately preceding a registered
`challenge.playable` marker, one acknowledged player command durably records
that marker and parks Reading5 at its control node. A fresh process loading the
result restores that same caption/control without executing the native marker,
republishing the caption, issuing a physical attempt, or creating Profile
progress. Repeating the admitted command returns the existing result.

GameState owns semantic admission and its existing command-receipt map;
SoloReadingSession owns Reading5 and traversal; DialogicBridge owns staging and
the live reading operation; DialogicRuntimeAdapter owns native source custody;
SaveManagerNarrativeCheckpointPort and the existing Run/Save/journal/storage
owners commit the complete checkpoint. No second Challenge ledger, marker
counter, saved capability, or mutable result cache is introduced.

## Exact playable result and command joins

Add exactly this result variant to `SceneEventContract.validate_scene_result`:

```gdscript
{
    "kind": "challenge_playable",
    "challenge_occurrence": H([envelope.source.scene_occurrence,
                               envelope.payload.challenge_id])
}
```

`H` is the existing canonical JSON SHA-256 helper, not string concatenation or
JSON with a different ordering policy. Both members are required, extra members
refuse, `kind` is the exact String above, and `challenge_occurrence` is a lowercase
64-character hexadecimal String equal to the rederived value. Accept it only
for a strictly inspected scene envelope with integer `schema_version=2` and
`kind="challenge.playable"`. It grants no board, attempt, result, target or End
permission. Its containing receipt already supplies the playable command ID;
duplicating that ID inside the result is unnecessary.

The existing exact receipt remains unchanged: `transaction_id`,
`request_fingerprint`, `kind`, `source_id`, `scene_event`. Its scene_event remains
schema2 with `semantic`, `registration_fingerprint`, `reading_anchor`, `result`.
The semantic envelope omits the live playback token. Rebuild the receipt through
`make_scene_receipt`, then validate the complete map through
`validate_scene_receipts`, including genuine issuer verification, committed
initial-admission proof, ordinal/predecessor chain and duplicate-marker refusal.

Admission must join all of the following, not merely compare a label:

1. The immutable installed registration and its canonical fingerprint; the
   actual compiled entry's content/program hashes and content version.
2. `source.entry_id` to the registered Challenge's entry; `event_id` to that
   Challenge's `playable_marker_id`; marker kind and exact payload to
   `{challenge_id}`. Existing `validate_bundle_structure` already checks the
   reciprocal Challenge/marker relationship and board-profile/target references.
3. The current admitted logical occurrence and its admission receipt to the
   envelope's source. Historical logical source identity is preserved after
   Load; current live destination identity/session grants execution custody.
4. The real predecessor caption publication and line to the marker's
   `after_line_id`, reading frame, occurrence and registration. The logical
   control index must resolve to that exact marker in the compiled programme.
5. The owner-issued command root/issuer receipt, the semantic canonical digest,
   and the next ordinal/predecessor derived from the complete current receipt
   ledger. Caller-supplied source, ordinal, hash or bundle is not authority.

Later physical-command derivation is fixed by this receipt, not implemented in
this milestone: `completion_transaction_id = receipt.transaction_id`,
`command_sha256 = receipt.request_fingerprint`, and context is exactly
`{kind:"scene_challenge", scene_occurrence, challenge_id, playable_command_id,
registration_sha256}` with values derived from its validated semantic source,
payload, containing command ID and registration fingerprint. Existing
`DatingAttemptLedger.semantic_slot` uses the same occurrence hash. The existing
`challenge_closed` validator must additionally require its referenced playable
receipt to have this result variant and matching derived occurrence; keep its
existing same-source, same-challenge, earlier-ordinal checks.

## Bounded forward source and destination

This first producer supports only the immediate caption-to-playable-control
edge. It refuses traversal through another caption, a jump, a different control,
an end marker, or completion. This matches the native adapter's current strict
control-predecessor proof; it does not claim arbitrary scene Next support.

Use `SoloReadingSession.prepare_scene_next` and validate the resulting existing
schema3 `ReadingTraversalOperation` against the installed programme. Require one
path edge, no traversed captions, destination kind `control`, null destination
caption, and the registered playable control index. Source/destination
projections are produced by `ReadingTraversalOperation.project`, not assembled
by changing an index in a dictionary. Reading5, traversal3, Run9 and Save9 do not
change shape. The only durable vocabulary extension is the exact playable
result above.

For this edge the complete ledger is byte-semantically unchanged, including
caption order, publication IDs, entry-context frames, session token and occurrence
IDs. Entry, occurrence, registration and frozen checkpoint header are unchanged.
The destination has boundary `control`, empty frontier, the validated control
index and the traversal's destination phase. Native playback remains at the
completed predecessor caption; a logical control is not a new caption.

Before any source checkpoint, hold the real caption with
`DialogicRuntimeAdapter.hold_scene_source(actual_session)` and retain its opaque
source token with `retain_scene_source(actual_session)`. The current code's
`validate_scene_source` rechecks session identity, ledger identity and snapshot,
native request/generation/event/execution generation, installed registration,
occurrence, exact reading snapshot and compiled caption/control adjacency.
Retain that token privately in Bridge; no public dictionary or saved hash can
replace it. Freeze live session, game-state capture, checkpoint, registration,
plan and command inputs before invoking callbacks, and recheck typed equality
and source custody after each callback and immediately before commit/adoption.

Persist the **source-phase** complete checkpoint first through the existing
scene checkpoint transaction with the unchanged receipt map. This is still a
Reading5 line checkpoint, so it requires no permissive control exception. Retain
its actual `{checkpoint_id,checkpoint_sequence,snapshot_sha256}` acknowledgement.
Keep the live source session unchanged while staging; the saved source may carry
the source-phase traversal operation while the live owner remains its validated
pre-operation source. Do not mutate the live session merely to make a candidate
pass the native custody check.

The **destination transaction** atomically commits both the exact destination
Reading5 checkpoint and the newly rebuilt playable receipt in the full Run9 /
Save9 document. Immediately before preparing it, require the current stable
checkpoint to match the retained source reference and complete source candidate;
any intervening save, Load or ownership change refuses. There must never be a
durable admitted playable receipt paired with the pre-marker source cursor, or
a newly produced destination cursor missing its playable receipt.

The process-local checkpoint seam must retain the exact source reference,
snapshot candidate, narrative destination, semantic command, traversal plan,
Bridge object and private capability identity. A proposed explicit method family
is `retain_scene_control(...)`, `commit_scene_control(...)`, and
`consume_scene_control_ack(...)` on the existing checkpoint adapter, bound once
to the actual Bridge validator. Names are proposed; custody and validation are
the review contract. Retention is not commit permission. Revalidate the exact
retained object/material under the same causal lease before preparation, after
callbacks, and before the real commit. A consumed capability cannot admit another
candidate or native installation. Reentrant calls, callback input mutation,
lease loss and owner replacement refuse.

Do not broaden `commit_scene_event` to accept every control dictionary. Keep its
existing line/legacy-marker behavior, with one explicit scene-control branch
that requires the bound private capability and exact retained candidate. Reuse
the current real checkpoint capture/prepare/commit/rollback and strict scene
input/candidate/reference validation. The new branch still invokes full Run9,
Save9, reading, receipt and issuer validation; a callback boolean cannot bypass
those validators.

## Native adoption and acknowledgement

Add a narrow adapter operation for installing the staged forward control after
the checkpoint acknowledgement is consumed by Bridge. It must validate the
retained original native source token and exact staged Reading5 projection,
including identical ledger/frame/occurrence and registered immediate edge,
before consuming the token. It then binds the candidate session/ledger while
keeping the same completed native predecessor caption held. This operation must
establish the actual retained control proof used by
`capture_scene_control_position(candidate_session)`; tests must not assign
`_scene_control_restore` or another private proof dictionary directly.

Bridge adopts its staged reading session and GameState adopts the exact committed
receipt map only within this acknowledged operation. The logical/native control
capture, full reading checkpoint and receipt lookup must all match the committed
destination before returning success. A native marker signal, label execution,
new caption publication or new physical attempt is forbidden during adoption.
The current `dispatch_scene_event_acknowledged` pauses then resumes native
playback and is therefore not sufficient by itself for this permanently held
control destination. Use an owned handoff under the existing causal lease with
the explicit retained source/destination custody above.

## Failure, retry and compatibility rules

| Point | Required behavior |
|---|---|
| Source admission/hold/preparation refusal | No receipt or physical/Profile mutation; no destination capability escapes. |
| Source persistence failure | Existing storage rollback/recovery semantics apply; no destination commit or adoption. |
| Source persisted, destination not committed | Native source remains held. Retry revalidates/reacquires current custody and stable source; fresh process restores the saved source. No playable authority exists yet. |
| Destination definitely fails and rollback succeeds | Retain the same source and staged command for in-process retry; do not adopt the destination. |
| Commit acknowledgement uncertain or rollback fails | Preserve existing fatal/forward-recovery custody and report committed uncertainty. Do not claim absence or issue replacement progress. |
| Destination durable, adoption/acknowledgement fails | Latch fatal custody with the committed destination intact. Fresh Load restores that destination; do not roll it back because native adoption failed. |
| Duplicate committed command | Same command/digest resolves exact retained result. Different digest refuses. Never allocate a second receipt, attempt or publication. |
| Restart before destination commit | The durable source traversal grants only source restoration. Since traversal3 stores no event command, a new uncommitted event root may be issued after revalidation; abandoned issuer roots confer no admission and never consume a physical attempt. |
| Restart after destination commit | Resolve the committed playable receipt and held control. Do not issue another event root or replay the marker to rebuild authority. |

Keep existing legacy receipt/result formats and Run8/Save8 behavior unchanged.
Previously unsupported/malformed playable result shapes still refuse; this is
not player-save migration. Reject foreign bundle/hash, wrong Challenge/marker,
wrong occurrence/publication, unissued root, occupied ordinal, duplicate marker,
changed programme, stale session/lease/capability, copied control candidate,
extra/missing result members, numeric/type coercions and a receipt from another
Run. Existing authentic control restores remain supported independently; this
proposal adds no blanket requirement retroactively invalidating every parked
control. For the new forward producer, its checkpoint and receipt are committed
and validated together, and later playable authority requires both joins.

## Review evidence and finite acceptance gate

Current code observations, not executed-test claims:

- `SceneEventContract.inspect_scene` and bundle validation already authenticate
  schema2 marker/entry/Challenge joins. `validate_scene_result` currently lacks
  any playable result although closure validation references playable semantics.
- `SoloReadingSession.prepare_scene_next` and traversal schema3 already produce
  a strict line-to-control plan. There is no separate SceneRuntimeState owner.
- `SaveManagerNarrativeCheckpointPort.commit_scene_event` currently rejects a
  Reading5 control checkpoint; `_commit_reading_next_autosave` currently accepts
  only route `dating`. Neither may be used as an unreviewed scene bypass.
- Adapter `hold_scene_source`, `retain_scene_source`, `validate_scene_source`,
  `_scene_source_boundary` and `_scene_control_predecessor` provide real native
  proof. `capture_scene_control_position` currently proves restored control only.
- `test_scene_native_activation_runtime.gd` demonstrates actual native control
  restoration, but its detached source construction is not a forward producer.

After D approves this exact proposal, the finite cloud-only gate is: actual
native caption -> issued playable envelope -> complete source/destination
checkpoints -> native held-control acknowledgement -> fresh-process selected
Load of those exact files. Check registration/issuer/receipt joins, unchanged
caption history, no physical record/reference/head/Profile branch, exact loaded
occurrence/control, no marker execution, duplicate idempotence, and targeted
source-write, destination-write and post-commit adoption failures. Include
forged/stale capability and mismatched receipt/cursor negatives. Retain original
logs, source/tree/controller/run identities and hashes. No local Godot or
PowerShell runs are part of this proposal.

Passing this gate establishes playable admission only. Real physical Start,
Profile-ahead recovery, selected-source overwrite/absence, End/closure and
production/rendered composition remain separate explicit milestones.
