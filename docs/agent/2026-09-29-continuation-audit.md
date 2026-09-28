---
schema_version: 1
document_id: continuation_audit_2026_09_29
document_role: navigation_only
execution_authority: false
status_authority: false
behavior_authority: false
verification_authority: false
inspected_source: "8cd17c2d5cb5eea2cb223ef1af92d47170ff1f78"
---

# Continuation readiness audit — 29 September 2026 (Hong Kong)

This read-only audit identifies remaining work at source
`8cd17c2d5cb5eea2cb223ef1af92d47170ff1f78`. It changes no Beads status,
requirement, accepted decision, ownership, or execution permission. The source
binding identifies inspected code, not a new runtime acceptance result. No Godot
or PowerShell execution was performed for this audit. Consult the
[current handoff](2026-09-23-next-session-handoff.md) for executed cloud evidence
and follow the [agent workflow](AGENT_WORKFLOW.md) before selecting work.

The inspected [Beads snapshot](../../.beads/issues.jsonl) contains **23 unfinished
records: 11 in progress, five open, six deferred, one blocked**. These include
parents and overlapping acceptance obligations, not 23 independent defects.
The statuses below are literal observations at the inspected source; refresh
Beads before acting. Deferred work remains deferred unless selected through the
current workflow.

## Readiness map

Categories describe the next dependency, not tracker status: **A** bounded
engineering candidate; **B** author/design input; **C** external or native
evidence; **D** other unfinished work. An A classification is not implementation
authority, and multiple categories can apply to one record.

| ID | Observed status | Category | Remaining boundary and next action |
|---|---|---|---|
| `dwm-634.3` | `in_progress` | A | Finish the current matched checkpoint experiment; preserve exact bytes, validation, history and custody. Select later experiments from measured phase costs. |
| `dwm-634` | `in_progress` | A/D/C | Consume `.3` and test growing seven-day histories. Broad latency acceptance additionally needs reference hardware and responsiveness targets. |
| `dwm-sx8` | `in_progress` | A | Cloud-reproduce nested capture/apply/rollback isolation risks with real GameState; fix only demonstrated failures and map exact behavioral tests. Inventory reproduction alone is insufficient. |
| `dwm-eei.2` | `deferred` | A/C | Reproduce indeterminate Profile persistence through real Settings, then explicitly establish Profile reconciliation ownership before composing trusted recovery. Audio samples and native output acceptance remain separate. |
| `dwm-eei.5` | `in_progress` | A/D | Preserve working two-device rebinding, Swap/reset and Desktop/Dating Quick paths. Complete `run_witnessed` Quick admission/status/custody against canonical frontier owners. |
| `dwm-vky.14` | `in_progress` | A/D/B | Extend the accepted internal ledger through real semantic-session ownership and durable reconstruction, then Witnessed Save and exact-variant Next. Production registration remains author-dependent. |
| `dwm-eei.11` | `deferred` | D | Consume the same semantic owner's saved sequence for retained-caption restore, locale reprojection and ending continuity; do not create another History store. |
| `dwm-eei.10` | `deferred` | D/B/C | Existing live style/caption rendering is present. Reconcile remaining canonical-data, authored-content and assistive gates instead of rebuilding the historical missing-style description. |
| `dwm-eei` | `deferred` | D | Aggregate retained child scopes and shared accessibility/content acceptance; do not reconstruct working apps or controllers. |
| `dwm-vky` | `in_progress` | A/B | Tint and Steady Interface are implemented. Specify old-run compatibility for Drift receipts, implement deterministic draw/validation, then safe-boundary projection. Admit only fully specified cards. |
| `dwm-7wj` | `in_progress` | A/B/C | Replace the version dropdown with the approved visible register using existing chronology. Final exact-version cues are author input; native ScrollPattern remains separate. |
| `dwm-n3h.2` | `open` | B | Prepare a scene-family selector matrix, then define the exact signature successor. The legacy limited/unavailable replay policy is already settled. |
| `dwm-n3h` | `in_progress` | D | Canonical context child `.1` is accepted. Do not redo its schemas/producers; remaining closure depends on `.2` and complete authored replay contracts. |
| `dwm-nqn` | `open` | B/A | Supply the immutable neutral-ID audio plan/cue/anchor catalogue, then coordinate successor snapshot/document/journal/restore composition. Failed-Load physical compensation `.1` is already closed. |
| `dwm-oyo.5` | `in_progress` | D | Consume the recorded `dwm-nqn` dependency; reconcile the old plan against Profile9/Run7 and later scope decisions before completing ledger/replay acceptance. Pair-deck wiring and private Practice already exist. |
| `dwm-oyo.6` | `in_progress` | D/B | Retain implemented Day7/ending paths; finish acceptance for both terminal sources, exact receipts and downstream Gallery/replay contracts after `.5`. |
| `dwm-oyo.7` | `open` | D/C | After upstream acceptance, verify the full release matrix on one identified subject. Focused CI, rendered journeys and exported startup are bounded evidence. |
| `dwm-oyo` | `open` | D | Aggregate accepted child results; another green focused run cannot close the seven-day umbrella. |
| `dwm-eob` | `deferred` | B | Obtain representative authored translated DTL before choosing the narrative translation adapter. UI translations do not supply narrative translations. |
| `dwm-5ht` | `deferred` | D/B | After canonical History and representative translations, implement the already-settled caption/History bilingual scope. Keep secondary controls hidden until rendering works. |
| `dwm-hsi` | `in_progress` | C | Collect a matching real save-failure phase/code and adjacent evidence. Existing injected Retry/rollback proof does not identify the original cause. |
| `dwm-eei.17` | `open` | C | Capture diagnostics during a matching native renderer stall. Clean repetitions do not establish a repair. |
| `dwm-wuk` | `blocked` | C | Recheck upstream when selected, then prove truthful Windows ScrollPattern operations on real overflowing content. The last retained upstream check is September 21; this audit made no new upstream check. |

## Strongest independent engineering candidates

**Settings indeterminate recovery.**
[ProfileManager](../../autoload/ProfileManager.gd) emits `profile_write_failed`
for persistence failures and blocks Profile mutations after fatal or
indeterminate persistence. No
production consumer of that signal was found. The current
[SettingsPanelController](../../scripts/ui/SettingsPanelController.gd) renders
generic failure and does not project the Profile block. The accepted
[Settings amendment §20](../design/2026-08-12-settings-preferences-ui-ux-amendment.md#20-technical-truth-failure-and-recovery)
requires trusted recovery until storage reconciliation proves the winner.
Start with a cloud regression through real Profile and Settings owners. Existing
recovery presentation and custody mechanisms may be reusable, but a ready-made
Profile reconciliation owner was not found: Profile exposes no clear/reconcile
command, and startup recovery is specific to New Run/bootstrap. Audio/window
compensation can latch the shared fatal mutation gate, but Profile's persistence
failure does not. Explicitly establish the reconciliation owner before wiring a
Retry or Cancel UI; do not treat a generic modal or an irreversible fatal latch
as proof of reconciliation. This is a source-backed composition gap, not evidence
of corrupted saves. The previously omitted Settings-audio and
shared-tint suites are already registered in
[Invoke-CloudTests.ps1](../../tools/testing/Invoke-CloudTests.ps1).

A concrete first cloud regression can extend the real-owner
[Settings fixture](../../tests/scene/test_settings_audio_live.gd), adapting the
[storage regression](../../tests/unit/test_json_file_storage.gd) for a valid
`next_validated` transaction whose declared new candidate bytes are missing.
Keep the old Profile intact, submit high-contrast through the actual controller,
and observe real `indeterminate_commit` reconciliation. Assert unchanged Profile
and revision, one failure signal, no preference publication and preserved physical
artifacts. Then assert conflicting controls are disabled, recovery retains
presentation custody, and a second preference refuses without more storage
operations. This proposed composition test has not run; existing injected storage
tests alone do not establish its result.

**Restore isolation.**
[RunRestoreParticipant](../../scripts/application/restore/RunRestoreParticipant.gd)
delegates capture directly to [GameState](../../autoload/GameState.gd).
`capture_restore_state()` uses `to_save_dict()`, whose shallow container copies
retain mutable nested gameplay references. `_apply_gameplay_silent()` likewise
uses shallow copies. For example, reset state already contains mutable nested
per-friend `dating_route_state` dictionaries; primitive-only data does not make
those containers immutable.

Cloud tests should first prove whether editing a returned nested backup changes
the owner, whether later live mutation changes the backup, and whether a prepared
plan or rollback backup can mutate installed state after success. Use a separately
deep-copied expected baseline so aliasing cannot change the test oracle too.
Preserve capture failure, malformed-input refusal, stale-session refusal and
silence until finalization under the
[persistence requirements](../../prompt_docs/requirements/persistence.md).

This is a static contract risk, **not demonstrated player-facing restore
corruption**. [SaveManager](../../autoload/SaveManager.gd) deep-copies participant
plans before apply, and inspected Contacts/Dating operations generally replace
detached candidates. Reproduce the exact owner boundary in cloud before a bounded
fix; keep it separate from the current checkpoint benchmark.

## Settled decisions and stale descriptions

- The [owner UI updates](../design/current-ui/owner-ui-updates-2026-09-21.md)
  already settle future bilingual scope: captions and History, one semantic
  entry, Primary-only Read Aloud; menus remain single-language. Implementation
  remains deferred.
- [Legacy Gallery policy](../architecture/frozen-presentation-context.md#accepted-legacy-gallery-policy--2026-09-23)
  permits honest limited replay from recorded facts, otherwise retaining the
  achievement while exact replay is unavailable. Missing history is never guessed.
- [Witnessed Scene §9](../design/current-ui/witnessed-scene.md#9-ordinary-history)
  explicitly distinguishes ordinary Next-crossed witnessed lines from Hospital
  and ordered-ending History, which admits only captions actually published.
  This is a consumer-specific constraint, not a new owner question.
- Noncanonical test dialogue is authorized. Production prose, translated
  narrative and final version cues remain owner inputs. Dating challenge
  transitions do not regain Continue/Done controls or special mines.
- [ApplicationBootstrap](../../autoload/ApplicationBootstrap.gd) already wires
  `PairDeckDrawPort`; [GalleryScene](../../scripts/ui/GalleryScene.gd) already
  supplies private Practice. Its visible version selector still uses an
  `OptionButton` and numbered version labels.
- Minesweeper tint (`dwm-vky.16`), Steady Interface (`dwm-vky.12`), Gallery
  chronology (`dwm-7wj.1`), canonical frozen contexts (`dwm-n3h.1`) and exact
  failed-Load audio compensation (`dwm-nqn.1`) have bounded accepted closures.
  Stale parent descriptions do not authorize redoing them.
- The [audio design §§7, 9 and 22](../superpowers/specs/2026-08-14-acoustic-memory-atlas-audio-design.md)
  already distinguishes exact physical Pause resumption from authored Load
  anchors. [AudioManager](../../autoload/AudioManager.gd) still persists the
  four-key semantic context and reports audio samples unavailable. Do not
  mistake compensation or TTS completion for the full audio-plan implementation.
- Cloud headless tests do not establish native Windows graphics, physical
  input-to-paint latency, speech/listening quality or assistive ScrollPattern
  acceptance. Preserve those evidence limits without treating them as blockers
  to every independent engineering increment.

## Replay selector review material for `dwm-n3h.2`

This six-family comparison supports later author review; it proposes no schema or
new story branches. The [approved contract §§10.5 and 12.3](../design/2026-08-07-seven-day-dialogic-flow-design.md#123-frozen-presentation-context)
requires recording every fact that changes presented lines or actions. Compare
the current [signature role fields](../../scripts/domain/narrative/PresentationSignature.gd),
[137 canonical entry schemas](../../data/manifests/dialogic_contexts.json) and
[replay projection](../../scripts/narrative/FrozenReplayContext.gd). An absent
canonical field is not automatically an absent *presentation selector*:
transaction provenance is inapplicable to replay, and immutable entry constants
or deterministic aliases need no invented historical value.

| Scene family | Already recorded or derivable | Canonical facts not directly represented in signature v1 | Remaining author-contract boundary |
|---|---|---|---|
| Contacts: ordinary, solo offers, consequences and echoes | Tier/tone/attitude and echo IDs where applicable; consequence miss reason. Entry identity distinguishes named follow-up reasons, friend/day and offer kind. Current registered fallback echo IDs each identify one atom. | Ordinary `phase`, `selected_reply_id`, `witnessed_line_id` are absent. Consequences retain closure and witnessed-Hospital facts, plus source provenance. | Ordinary reply/phase preservation is already required, not a new policy choice. Declare any further consequence wording/staging distinctions beyond the saved reason/entry. [Producer](../../scripts/narrative/ContactsFrozenContext.gd), [echo registry](../../data/manifests/dialogic_ids.json). |
| Solo Dating, pre/post | Tier/tone/attitude/echo IDs; post board result, relationship outcome, Perfect reasons and promotion result. Entry fixes phase, friend, day and challenge slot. | Six window entries retain a structured progression result; no independent missing selector was demonstrated. Its `evaluated` flag needs a redundancy/reachability audit before branching on it. Current residue is null and Dating echoes are empty. | No new owner decision identified for current selectors. Additional authored distinctions require evidence that they vary independently of saved facts. No new residue branch or restored special-mine mechanic is authorized. [Producer](../../scripts/application/run/DatingPhysicalOwner.gd). |
| Group Contacts and pair Dating | Pair mode/form; pair post board result/Perfect reasons. Contact entry names encode their named variation. Post full/truncated observation and witness capability are derivable from board result. | Exact group action, inviter, target/opened/replied variation; pair-count status/outcome/counts/visibility. Stable-deck extras currently establish draw provenance, not an independent declared prose selector. | Identify which group/count facts change presentation beyond the named entry/form. Draw nonce, fingerprint and transaction IDs are proof; do not copy the whole receipt into identity. [Contact producer](../../scripts/narrative/ContactsFrozenContext.gd), [draw schema](../../scripts/domain/relationship/PairDeckDraw.gd). |
| Hospital | Entry/day and `miss_reason`. | `qualifying_cause`, Sylvia eligibility/witness presentation and accepted/unfulfilled record facts. Eligibility can precede a witness; it must not be replaced with an invented completion. | Define the finite presentation distinctions drawn from those admitted facts. Record semantic selectors when reached, not raw causal IDs as a substitute for authored meaning. [Producer](../../scripts/narrative/HospitalFrozenContext.gd). |
| Solo/pair ending steps | Role/form/residue; solo tier/tone/attitude/echo IDs/miss reasons; pair form. Stored tone, playback mode, pair deck tone and stable combination are already derivable aliases. | Canonical evidence/pair-count/prerequisite receipt identities are intentionally absent. Current ending echoes are empty. | Supply finite evidence-derived insert selectors **if** authored wording/staging distinguishes evidence beyond saved fields. Receipt provenance alone does not establish such an insert. [Producer](../../scripts/narrative/EndingFrozenContext.gd). |
| Alone | Entry, ending role/form and derived playback mode; normal/dark mode is already distinguished. | `alone_cause` (`empty_done` or `hospital_faint`) is absent. | This discriminator is already specified; no owner choice is needed to recognize the gap. Authored cause-specific presentation remains input. [Producer](../../scripts/narrative/EndingFrozenContext.gd). |

The [existing replay tests](../../tests/unit/test_frozen_replay_context.gd) explicitly
preserve missing ordinary/Alone fields and reject invented canonical authority.
This matrix does not change the accepted limited/unavailable legacy replay policy
or authorize filling old records from current Run state. Before a successor is
implemented, an author-reviewed per-entry selector catalogue should distinguish
required known discriminators from any additional authored inserts; final prose
is not required merely to review that catalogue.

## Future owner inputs, not questions for this increment

No owner question is needed to finish the current matched checkpoint work.
Prepare concrete review material before asking about these later boundaries:

1. **Replay signature:** which additional scene-family facts change authored
   wording or staging beyond the already-required discriminators? Use the matrix
   above to review pair variation and Hospital/ending evidence inserts without
   reopening ordinary reply or Alone-cause requirements.
2. **Drift compatibility:** how should a run created before Drift continue?
   Present a concrete proposal, such as keeping Drift absent for that existing
   run versus requiring a new run. The
   [Drift amendment §§6.8 and 13](../design/2026-09-12-instrumentarium-drift-deck-all-input-and-week-tint-amendment.md)
   requires compatibility to be specified before adding the receipt; earlier
   permission concerning an old save does not decide every future migration.
3. **Latency acceptance:** which reference Windows hardware and maximum delays
   define acceptable first reveal, save, settlement and Login responsiveness?
   Relative matched improvements can proceed before that release target exists.

Audio catalogue/anchor content, final Drift card selectors and three-locale copy,
and representative narrative translations remain later author inputs. They do
not reopen the already-settled policies above or justify invented production
content merely to close a record.
