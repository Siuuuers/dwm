# Frozen presentation context

Canonical presentation and historical replay have different fact sources. Neither
may reconstruct missing historical facts from current GameState or Profile.

Canonical entries use the 137 exact schemas in `dialogic_contexts.json`. Their
versioned Run caches retain facts at the existing causal boundary: Contacts
generation, Dating phase admission/result, Hospital request admission, or ending
admission/current step. Transport tokens remain separate from presentation data.
An attempt ID exists only after the automatic pre-to-board handoff. That internal
handoff does not add a Continue or Done popup.

Hospital's `sylvia_eligible` selects the physical presentation before a Schedule
Hospital witness exists. Its nullable witness ID never claims future completion.
Condition Hospital already has its actual closure witness. Pair encounters before
invitation rollover retain `pair_count_status=pending_rollover` with a null receipt;
the retained resolution plan must prove that pending boundary. Committed contexts
require the actual count receipt. Neither case mints a future receipt.

The restore validator reads saved facts only and runs before installation or
Profile reconciliation. Run snapshot and document v7 require complete applicable
caches and refuse older Run documents without repairing them. Profile v9 and its
append-only history are separate from that Run admission policy.

Prepared Condition owner candidates must retain the Dating cache for their own
admitted challenge. An earlier candidate does not inherit a later ending's admission
requirement; present historical caches and append-only rollover receipts are still
validated. A semantic checkpoint carrying either `entry_id` or `frozen_context`
must carry both. Empty and genuine generic physical-owner restart transports remain
valid. Recovery history keeps its existing policy: invalid fallback bundles are
diagnosed and skipped, never selected, repaired or installed.

Dialogic receives a detached, recursively read-only `Frozen` namespace before its
first event. Completion, failure and cancellation restore the prior variables.
Hospital and endings retain their existing physical completion owners. Ending
completion IDs use the already-admitted stable step playback ID, so restarting the
process cannot collide with another step's completion receipt.

## Historical replay

`FrozenReplayContext` uses the exact validated reached presentation signature from
Profile v9. Its schema is `replay_signature.<entry_id>.v1`, its source is explicitly
`reached_signature`, and its execution mode is `gallery_replay` or
`date_rehearsal`. The canonical context schema is not silently weakened for replay.
The projection contains the saved signature fields, immutable entry metadata, and
only aliases derivable from those fields, such as ending `stored_tone` from saved
`tone`. It carries no canonical run, attempt, effect, prerequisite or step identity.
It changes neither the existing native Gallery/date cards nor their authority.

The current signature schema is less complete than the design's §10.5 promise.
These missing selectors are distinct from inapplicable transaction identities:

| Historical role | Known signature facts | Missing potential prose selectors |
| --- | --- | --- |
| Ordinary message | Tier, tone, attitude, echo IDs; entry/day | Phase, selected reply and witnessed line |
| Hospital | Miss reason; entry/day | Qualifying cause, Sylvia eligibility/witness presentation, accepted/unfulfilled record facts |
| Pair challenge | Pair mode/form; post board result and Perfect reasons | Exact group action, inviter/opened/replied variation; stable deck details beyond form |
| Alone | Ending role/form | `alone_cause` |
| Solo ending | Tier, stored tone, attitude, echo IDs, miss reasons, ending role/form/residue | Evidence-derived inserts beyond the saved finite fields, if future prose distinguishes them |

Entry IDs already distinguish the named group-contact variations and follow-up
reasons. Their constants may be derived from that immutable entry, but unrecorded
facts cannot be inferred from a later group state. A saved empty list remains an
actual saved value; an absent selector remains absent. Old special-mine signature
fields are retained as historical data and grant no gameplay capability.

Current replay behavior is preserved. Future authored prose that needs a missing
selector requires an explicit reached-signature successor and a compatibility
policy consistent with the accepted owner decision below. Relabeling old records
cannot recover those facts. A successor must record
all prose-selecting fields when reached, preserve existing Profile chronology, and
define the legacy presentation available for old signatures. This work does not
invent a Profile migration or claim that the broader signature-design gap is closed.

### Accepted legacy Gallery policy — 2026-09-23

The owner accepted a clearly identified limited replay for an old Gallery record
when its saved facts support an honest limited presentation. That replay must use
only facts actually recorded, including derivations from immutable entry metadata
described above. It must not imply that it reproduces the exact original scene.
When the recorded facts cannot support such a presentation, retain the achievement
and mark exact replay unavailable. Missing selectors must never be guessed from
current state or filled with invented historical prose.

This is an accepted compatibility decision, not an implemented replay mode or a
new signature schema. Existing Profile records, append-only history and chronology
must be preserved. A future implementation must define the supported limited
presentations and their validation before changing runtime replay behavior; this
decision does not relax canonical Run admission or save-recovery rules.
