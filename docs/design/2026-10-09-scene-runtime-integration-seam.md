# Scene runtime integration: concrete seam, 9 October 2026

Status: A implementation contract for the Director12:34 allocation; **new format/proof boundary awaiting D review**. This is not runtime activation or acceptance. Base is immutable PR23 `4c6752829a412f82349fa546f0e022df7ff6e7ec` / tree `5ff524bbb5a515191d69789a36280ee62d7c15a3`. Story authority is PR25 `44dda79440392d14c95ea6ce4e94d579094f76e5`, including both October9 amendments. Do not import master wholesale.

A alone owns shared implementation on `codex/scene-runtime-integration-20261009`. G owns `codex/scene-absence-contacts-20261009`; F owns `codex/scene-retirement-20261009`. Preserve PR14/18/20/22/23 and their controllers. This document supplies a finite interface; it does not reopen accepted reviews.

## Observable outcome and failures

A selected complete save restores its own authored occurrence and Challenge state, including genuine never-started absence. Starting afterward may reuse the original immutable attempt entry, but cannot copy later preparation, layout, reveal, moves, result, Perfect or closure. Source-slot overwrite and fresh-process restart do not destroy the selected-source proof. Contacts use the same reading owner; caption/Log browsing remains read-only.

Before implementation, the failure points to cover are:

1. Selected document is missing, incompatible, malformed, wrong family/registration/occurrence, or has ambiguous checkpoint identity: refuse before continuation allocation and before participant mutation.
2. Intent write fails: no identity allocation or Load authority. Identity allocation succeeds but later persistence/apply fails: retain the existing forward-recovery operation; never issue replacement identity.
3. Any silent participant apply/finalization fails: rollback in reverse order under existing custody; no new live scene token or selected-absence permission escapes.
4. Final completion-journal write fails: no selected-absence Start authority; reconcile the same operation, never treat a merely prepared/applied operation as committed Load.
5. Source Slot/Quick/Autosave is overwritten after the selection: resolve the retained original document in the same continuation journal, never the replacement source.
6. Profile write fails: Start has no accepted branch progress. Profile succeeds but Run checkpoint fails: retry/restart adopts the exact destination branch/revision; never falls back to the original branch or resets revision1.
7. Callback mutates inputs, reenters, changes selected Load, steals lease, changes registration or live session: revalidate immediately before Profile commit and refuse. Confirmed Run commit followed by native adoption failure remains fatal with committed target preserved.
8. Duplicate playable/Start/end, a terminal attempt, a desktop-family receipt, forged Contact fact, nested Contact call or allocating exit during Contact: refuse/idempotently return the original result as prescribed by existing owners; no duplicate consequences/publication.
9. Earlier saved actual progress is distinct from selected absence. It uses the existing saved-prefix continuation path. Never pass an empty saved record to that path.

## 1. Strict candidate formats

Use explicit **Run9 / Save9** branches. Accepted Run8/Save8 implementations and history validators remain byte-accounted legacy code; no conversion of old player saves is introduced. Production scene loading admits only the complete supported scene format. An old unsupported save stays intact and follows existing explicit backup-consent policy.

### Run9

The exact top-level keys are:

```text
active_app_id, applied_effect_transaction_ids, applied_variable_transaction_ids,
audio_context, checkpoint_id, checkpoint_sequence, command_receipts, contacts,
content_version, desktop, gameplay, lifecycle, narrative_checkpoint, route_id,
run_id, scene, schema_version
```

`schema_version=9`; the normal scene host route is **`scene`** (technical host identity, not an authored story ID). No `dating`, `committed_schedule` or `schedule_view` member is synthesized. Desktop suspension uses the retained active-app/host contract; it does not change the canonical story host identity.

Exact `scene` keys:

```text
registration_sha256, active_occurrence_id, active_admission_receipt_id
```

These are references, not another occurrence/history ledger. Resolve them against the complete installed registration bundle and immutable scene receipts. Active occurrence is not the multi-occurrence reading session token. Reading schema5, its frame and the selected active admission must agree.

Exact scene `lifecycle` keys for the released generic fixture-backed PLAYING boundary:

```text
run_id, branch_id, desktop_timeline_generation, causal_day_instance,
causal_day_instance_issuer_receipt, restore_provenance, state, scene_assignment
```

`state=PLAYING`. `scene_assignment` is exactly G's seven-member `scene.new_run.alternating.v1` receipt; there is no duplicate saved form field. Load preserves the receipt unchanged. Existing causal/desktop ancestry keeps its genuine issuer-defined identity, even where historical field names contain “day”; it imposes no numeric day, seven-day cap, Schedule or automatic reset. Existing exact restore-provenance and issuer/remap validation remains, with explicit scene-family handling. This is not permission to discard original historical identities.

**Director 14:08 HKT resolves the selection policy.** First successfully created new run randomly assigns `sweet` or `dark`; each later successful new run receives the opposite, persistently across abandonment/restart. Refused/cancelled creation and same-operation retry do not consume or reroll; old Load never changes the sequence. A owns joint NewRun/schema/bootstrap; G supplies the existing Profile-owner delta. Extend the existing `pair_deck_draws` owner with an exact discriminated receipt, not a competing counter/store or the unrelated UI `captured_dark` preference. Proposed new receipt is `{ruleset_id,form,selection_kind,rng_nonce,predecessor_run_id,predecessor_assignment_sha256,creation_transaction_id}`, ruleset `scene.new_run.alternating.v1`, forms `sweet`/`dark`. Initial nonce is controlled, predecessor fields null; alternate nonce null, predecessor authenticated. Commit only with durable run creation, never a standalone precommit draw. Preserve old receipt shapes. Existing legacy suffixes establish tone but ledger insertion order does not establish successful creation chronology; inspect retained creation proof before selecting any legacy sequence seed. This receipt is a dependency contract, not implemented activation. Production authored content remains separately selected; no invented production IDs or partner.

Exact scene `gameplay` keys (all required; neither a permissive subset nor arbitrary extras):

```text
affection, coins, friend_attitude, friends, inter_friend_affection, inventory,
minesweeper_app_rounds_finished_today, minesweeper_money_earned_today,
minesweeper_rng_seed, minesweeper_round_floor, minesweeper_rounds_left,
minesweeper_selected_difficulty, minesweeper_task_rewards_claimed, money,
narrative_variables, penalty_points_today, penalty_points_total, route_context,
shop_purchase_counts, stats, story_flags
```

Retained fields use their existing owner validation and ranges, not generic primitive-only acceptance. Existing affection/story-effect facts remain only for their approved purposes; none choose a partner or create a compulsory relationship tier. `stats` is exactly `{pressure:int}`, 0..12, new-run default3; money and coins remain separate. Retired Health/Motivation and all calendar/invitation/Hospital/pending Dating members reject before mutation. Current scene `chat_state` is removed because the canonical Contacts bag owns messages/read/reply state.

Desktop counter names containing “today” retain existing accounting/ancestry; no scene boundary silently resets or charges them. Scene Challenge does not use the desktop round/payment contract. Notes retain three 45money single-unit purchases and count-derived cap3. Inventory/capability and legitimate pressure Shop effects survive.

`route_context` is a strict discriminated shape owned by the existing physical/attempt contract. The only scene keys are `active_dating_challenge`, `dating_active_attempt_ref`, `dating_canonical_heads`; absent fields or empty containers mean no referenced value, never a fabricated valid record. A populated active record requires its matching reference; populated heads each validate as real retained references. No unrelated host/date/Schedule keys pass. G's existing v4 validator remains the sole physical-record shape owner.

The captured input before RunSnapshotSchema.build is exactly:

```text
lifecycle, gameplay, contacts, desktop, scene,
applied_effect_transaction_ids, applied_variable_transaction_ids, command_receipts
```

F's DesktopFirstRevealSnapshotComposer must use that exact scene base set. Its scene game-state candidate is exactly {transaction_id,rounds_left,starts_today}; remove the Motivation member and write. Preserve typed equality/whole-candidate validation discipline, not the retired field set. Historical legacy candidate/receipt shapes stay explicitly discriminated; do not fill legacy keys or loosen validation. Narrative checkpoint, route, app, audio, content version and checkpoint sequence remain builder arguments.

### Save9

Keep exact envelope `{schema_version,kind,slot_id,save_reason,current_snapshot,recovery_journal}`, plus the existing explicitly validated optional `saved_time`. Bundle remains exactly `{checkpoint_kind,snapshot}`. Each current and recovery bundle is Run9; duplicate checkpoint IDs, mixed Run8/9 or incompatible registered content refuse. Current and journal proof/splice paths obey the same family agreement; trusted proof object reuse never excuses a wrong version or mismatched bundle. No unchecked primitive-only scene journal.

RunSnapshotSchema.build_scene(snapshot_input,dialogic_checkpoint,route_id,active_app_id,audio_context,content_version,checkpoint_sequence) and validate_scene(snapshot,bundle) are the explicit scene producer/admission entry points, with those same existing builder argument types. Existing build dispatches only after the actual scene route/family owner admits the scene input; no inference from one optional key. validate(snapshot) dispatches by exact schema_version then requires the installed scene registration for Run9. GameState capture/prepare/install are paired with that admission. SaveDocumentSchema.build/_validate_document/_validate_bundle/_validate_journal are paired, including proven-journal emission. No current version constant flips independently.

## 2. Durable selected-source owner

The existing `desktop-continuation-operations.json` is the only durable continuation store. Add a **journal5 scene operation variant**, `kind=scene_restore`, whose exact fields are the existing restore operation fields plus **`selected_document`** and **`activation_state`**. The issuer allocation request remains `kind=restore`; this does not invent a new allocation family.

Retain exact old `new_run`/`restore` operation shapes and historical bytes; do not add null fields or reseal them. Journal reader/writer must explicitly distinguish the old schema4 envelope and new schema5 envelope. A schema5 envelope may retain old exact operation variants. Appending the first scene operation preserves all existing canonical operation bytes and receipts; this is an explicit continuation-envelope extension, not player-save migration. Corrupt/unknown historical variants refuse unchanged. The journal's participant-order dispatch also becomes family-specific (below).

`selected_document` is the actual fully validated Save9 document used by _prepare_restore_document_profiled, including legitimate recovery fallback. Retain it in the prepared **private** scene material and write it into intent before allocation. Never accept a caller replacement of the prepared document. The public restore material stays owner-retained/digest-checked under existing prepared-restore custody.

Do not store both a bundle and a second seed authority. Locate exactly one selected bundle using existing `source_locator`; verify:

- bundle canonical hash == `source_locator.bundle_id`;
- selected snapshot canonical hash == `source_locator.document_sha256` (keep its existing meaning);
- snapshot checkpoint ID == locator checkpoint ID;
- complete document/selected snapshot passes Run9/Save9 and actual installed registration/participant admission.

Scene intent fingerprint is:

```text
H({kind:"scene_restore", transaction_id, source_locator, selected_document})
```

Document bytes/semantic canonical value are immutable on every forward operation transition. SaveManager scene recovery derives the exact selected bundle and `CheckpointJournal.prepare_seed(selected_document,selected_bundle)` again; require seed.current equal the exact selected bundle. Never re-search a changed slot, borrow a different fallback, fabricate a document around a bundle, or discard prior checkpoint seed obligations.

Existing lifecycle.restore_provenance.restore_transaction_id points to this durable operation. Saves after selected Load retain that provenance, so source overwrite does not erase the original proof. Another selected Load creates its own operation with its actually selected document and destination; original operations stay historical.

### A-owned callable contract

GameState is the single scene semantic authority configured into DatingPhysicalOwner. SaveManager owns durable selected-document/continuation lookup. Existing live-session and causal lease custody remains private.

```gdscript
# SaveManager: no caller-provided source document or live identity.
capture_committed_scene_restore(restore_transaction_id: String) -> Dictionary
load_restore_context(restore_transaction_id: String, locator: Dictionary) -> Dictionary

# GameState: additions to the actual scene authority object.
prepare_selected_scene_absence(command: Dictionary, bundle: Dictionary) -> Dictionary
validate_selected_scene_absence(admission: Dictionary, command: Dictionary,
    bundle: Dictionary, lease: String) -> Dictionary
```

`capture_committed_scene_restore` returns detached exact `{operation,selected_bundle}` only for a fully **completed** durable scene_restore operation, with verified source hashes/allocation/remap receipts. A prepared/allocated/participants_applied operation is not permission. `load_restore_context` is the identity-allocation/reconstruction source-loader extension; it can read the matching earlier operation stage during recovery but grants no Start permission. It returns the same validated snapshot/context contract the current locator loader supplies.

GameState.prepare returns `{ok:true,value:admission}` with exact admission members:

```text
restore_transaction_id, source_locator, source_identity, destination_identity,
allocation_receipt_id, remap_receipt_id, transaction_remap_sha256, challenge_key
```

`challenge_key` is exactly `{run_id,scene_occurrence,challenge_id,playable_command_id,registration_sha256}`. Source/destination identity use the accepted five-member scene execution identity, with real issuer/remap validation; do not confuse logical occurrence identity with live destination authority.

All admission values are comparison material, **not capability by themselves**. GameState retains the actual current live-session handle internally and rederives admission from SaveManager, scene event/reading owner and actual installed bundle. Validate before Start preparation and again under the active lease immediately before Profile commit. Forged copied dictionaries, stale Load/session, changed callback inputs, foreign registration/occurrence and reentry refuse.

Absence requires the exact admitted playable occurrence/reading anchor and no matching physical record, active reference, canonical head or consumed end in the selected source. Resolve all matching receipts, not just the live active pointer. A save before occurrence allocation cannot acquire lineage through label equality. Source and destination linkage must match the committed continuation remap/provenance.

### G-owned consumption

G adds explicit `start_from_absence`, never overloads `continue(saved_record)` with `{}`. Within existing Profile/ledger preparation, selection is exactly:

```text
{mode:"start_from_absence", admission,
 attempt_id, generation, entry_sha256}
```

G derives the last three members from the actual existing Profile entry, not A or caller data. Configure the existing Profile scene path with a one-time bound validator callback:

```gdscript
ProfileManager.configure_scene_absence_validator(validator: Callable) -> Dictionary
# Callback arguments: admission, command, bundle, lease; delegates to GameState.validate_selected_scene_absence.
```

At preparation and immediately before real Profile commit, re-read first-attempt identity/immutable entry and exact destination-branch progress, then revalidate A's admission. Existing destination progress wins as same-operation recovery; never recreate revision1. Validate callback arity4 and retained object/candidate identity; callback mutation and reentry refuse.

Before Start, no record/attempt reference/Profile branch is created. On Start, build the deterministic initial v4 record from the **original immutable** context/host/spec/token; original pressure/capabilities/nonces may differ from selected current values. No future generator frontier/certified layout/first-cell/actions/result/Perfect/closure is copied. New branch begins revision1 only if absent. If Profile has no original attempt, existing fresh issuance remains, with commit-time first-entry recheck. Preserve Profile → source Run checkpoint → proof → closure ordering.

## 3. Contacts interface to G

The single scene Contacts bag is exactly:

```text
{schema_version:2,messages,read_watermarks,transaction_receipts,next_sequence}
```

No solo/group action, Schedule source or Hospital receipt member in this family. Legacy family stays separately strict. Preserve canonical friend-index, global sequence, watermark, command replay and issuer laws. Current authored Contact message/read/reply facts are committed receipts, not another saved facts table.

Reuse G-owned ContactCommandPort, ContactsPresentationPort, ContactInvitationState and only required OrdinaryReplyEchoState scene branches. A owns GameState delegates and real checkpoint wiring.

```gdscript
# Existing external command/delegate names remain.
ContactCommandPort.configure(game_state: Object, identity_issuer: Object) -> Dictionary
GameState.preview_open_contact(friend_id: String, command_id: String,
    command_issuer_receipt: Dictionary) -> Dictionary
GameState.open_contact(friend_id: String, command_id: String,
    command_issuer_receipt: Dictionary) -> Dictionary
GameState.configure_contact_checkpoint_writer(writer: Callable) -> Dictionary # arity0 unchanged

# New scene semantic seams, with G's pure validation delegated by A.
GameState.capture_scene_contact_context() -> Dictionary
GameState.resolve_scene_contact_facts(source_fact_ids: Array) -> Dictionary
ContactInvitationState.validate_scene_facts(state: Dictionary, source_fact_ids: Array,
    registration_sha256: String, identity_issuer: Object) -> Dictionary
```

The command context is exactly `{identity,scene_occurrence,registration_sha256,contacts_sha256}`, derived from the real live owner and retained once per command; the lease/session fence is private. Replace calendar preflight with exact context comparison. Existing ordinary-reply prepare/render-ack/commit ordering and issuer admission remains; do not award a reply fact merely because text was requested.

**Authored fact binding:** `B.contacts.source_fact_ids` are opaque authored fact IDs, not arbitrary issued transaction IDs or guessed label meanings. G's scene command receipts add exact `source_fact_ids` (sorted, unique) and `registration_sha256`; each fact must be derived from an installed message/read/reply definition, linked to the real command/message and acknowledged operation. G must publish the exact definition/message/operation-specific result member sets before adding them to its implementation; this is G's existing Contacts-domain authority, not A inventing production text/IDs. A's bundle admission must bind that definition digest before a Contact entry can execute. Until the exact registered definition is installed, unresolved facts refuse. No `Dictionary` catch-all, synthetic success or independent mutable fact cache is permitted.

This separates the stable A/G API from G's concrete domain row definition without pretending the accepted four-field B.contacts already contains message/reply definitions. G publishes any additional required path before editing; A owns complete bundle/schema admission and will compose its exact definition digest rather than an implicit mutable registry.

Resolver returns `{ok:true,value:{receipts:[...]}}` in sorted source_fact_id order after scanning the full canonical transaction_receipts bag. Missing, multiply owned, mismatched registration, unissued or unacknowledged fact refuses. Caller cannot supply a receipt subset.

A's Bridge uses the existing staged target/ack producer for genuine `contact.enter` after computer Close at the registered safe boundary. Preserve exact return_to `{scene_occurrence,admission_receipt_id,entry_id,target_id,source_checkpoint}`; return result remains `{kind:"contact_returned",contact_admission_receipt_id,target_id,parent_occurrence_id}`. Derive outstanding call from accepted enter/return receipts. No nested call or allocating scene/ending exit while outstanding. Retain parent Challenge/occurrence. Return uses current live scene execution identity/lease after Load, not stale parent execution authority.

G's SaveManagerNarrativeCheckpointPort change admits route provider raw string `"scene"` only with Run9 scene input and actual scene authority. The exact lower checkpoint input remains `{active_app_id,audio_context,content_version,dialogic_checkpoint,route_id,snapshot_input}`. Existing `commit_scene_event(snapshot_input,checkpoint)` and acknowledged staged-target flow remain. No route string alone certifies content or custody.

## 4. Restore and shared method allocation

Prepare the entire selected bundle with all owners before any silent mutation. Scene participant order is exactly:

```text
run, desktop_consequence, desktop_board, profile, localization, audio, route, narrative
```

Remove schedule_view only in scene operation family; preserve historical nine-participant operations/order for their admitted recovery. Identity allocation remains the existing preceding transaction, not a tenth mutable participant. Rollback traverses applied participants in reverse; restores scene references/command bookkeeping, physical custody, live-session handle and checkpoint journal. Native adoption/publication waits for successful committed continuation; no future marker executes on source Load.

Concrete A pairs:
- RunSnapshotSchema.build/validate/_validate_lifecycle/_validate_command_receipts/derive_route_restore_context with RunLifecycle.to_dict/prepare_restore/commit_restore/prepare_continuation_remap.
- SaveDocumentSchema.build/_validate_document/_validate_bundle/_validate_journal plus proven-journal binding; SaveMigrations dispatch refuses unsupported old format without conversion.
- GameState.prepare_new_run_snapshot_input/capture_run_snapshot_input, scene_event_registration/context/acceptance/validation, _prepare_restore_bookkeeping/_apply_run_snapshot_silent/apply_restore_silent and rollback. Complete schema2 scene receipt/result/issuer validation, separate legacy family, retained effect/variable partition equality.
- FrozenRunContext.validate_reading_checkpoint validates the complete selected Run and each historical/current frame against immutable registration, actual receipt/issuer/result. Deriving frames alone is not authority.
- DialogicBridge.validate_reading_checkpoint plus NarrativeRestoreParticipant._prepare_reading/_prepare_semantic: no stripped-scene bypass. Installed native programme and registered positions agree before silent install.
- ApplicationBootstrap configures one actual checkpoint adapter, actual staging/source/context/physical authority, real restore participants and real scene host. RouteRestoreParticipant.prepare consumes authenticated Run9 scene references, not numeric day or Schedule. No fake host success.
- SaveManager prepared selected document, completion fence and reconstruction; DesktopContinuationOperationJournal family/schema extension; DesktopIdentityAllocationRestoreParticipant source-loader extension. These are the exact additional dependency paths needed by the durable proof.
- DesktopContinuationRemapper scene branch is G-owned; A composes it. It remaps live execution/command keys while preserving historical receipt/preimage bytes and scene logical occurrence/return references. No imported calendar graph.
- A composes F's shared GameState/Bootstrap/schema/launcher/registry/public-surface/isolation delta. No parallel edits of shared files.

No production wiring switches until Run/Save producers, validators, restoration, native/physical owners and composed F/G deltas agree. No temporary Schedule. Retain the real Save8 refusal regression until the complete scene format is admitted; supersede its expected version only in the explicitly new scene-success tests.

## 5. Required connected evidence

Use real filesystem Save/Profile and actual restore/native owners for positive lanes, including Slot, Quick and Autosave selecting current and valid recovery candidates. Prove selected absence after source overwrite and another save/restart before Start; actual saved earlier prefix; Profile-success/Run-failure fresh process; failed Load rollback; duplicate/end/terminal and cross-family negatives; actual Contact call/return with no nested exit and retained parent Challenge; no post-Load effects/publication replay. Preserve original source history bytes and all retired-input atomicity/Notes/payment/isolation negatives.

Injected failure diagnostics must be labeled and cannot substitute for successful real persistence. Run source reviews before one coherent connected candidate; focused diagnostics only for actual uncertainties. All Godot/PowerShell in GitHub Actions. Original artifacts, failures, nonzero XML, source/engine pins and clean-source gates retained. Distinguish log assertions from XML testcase assertions. Later B persistence and C rendered review, then canonical gates; no whole-game acceptance or merge permission.

## Immediate handoffs

- G can implement the explicit absence API/selection and scene Contacts bag/context/resolver contract. Publish exact domain definition/receipt rows and any additional path before edits; compose against A's eventual complete registration binding, never guessed mutable data.
- F can use the exact scene captured-input/gameplay/stat sets above for dependent composers. Keep all disjoint retirement work and hand shared changes to A.
- D reviews only the new format, durable selected-document proof, completion/live-session fence and finite domain binding interfaces. Prior PR23 acceptance remains closed.
- Director settled NewRun form policy at 14:08 HKT. Its exact joint durable implementation and authored production content remain pending; do not ask the product question again.



## D6074955676 completion and activation correction

For the new scene_restore variant only, `activation_state` is null before COMPLETED, `pending` atomically with the durable APPLIED→COMPLETED write, and `acknowledged` after actual native frontier, mounted route and current live session confirmation. It is outside the immutable intent fingerprint. Historical operation shapes remain exact.

1. Hold restore save lock and mutation/input custody; prepare and apply reversible participants silently. Do not resume native playback or publish readiness.
2. Persist COMPLETED+pending as one durable write. Definite refusal rolls back reversible state and retains the same operation/identity for retry; uncertain outcome re-reads while fenced.
3. Activate the committed target under custody. Queued route change or finalize return alone is insufficient: require genuine native frontier and mounted-route acknowledgement.
4. SaveManager privately calls `acknowledge_scene_activation(transaction_id,request_fingerprint)` only after those confirmations; durably acknowledge before releasing custody/publishing ready or admitting Start.
5. Failure after committed pending retains the committed target and identity, stays fenced, and never compensates or allocates again.

`list_incomplete`, `reconcile_startup` and SaveManager `_resume_operation` must include precisely completed scene_restore/pending records. Reconstruct process-local participants/checkpoint seed from retained `selected_document` through `load_restore_context(transaction_id,locator)`, bypass historical receipt advancement/allocation, and resume activation. Normalize scene_restore custody owner to restore because existing save lock checks that name. Block new continuation while pending; conflicting multiple pending records fail closed. Do not replay all historical completed operations or choose an arbitrary latest operation.

Required connected evidence: completion refusal/uncertainty; crash before completion, after pending commit and after physical activation before acknowledgement; native/route/ack-write refusal; source-slot overwrite; many acknowledged historical operations plus one pending. Assert no premature publication/Start, duplicate consequence or replacement identity. This is the corrected implementation contract, not a claim these paths already passed.

### 9 October implementation candidate: bounded status

The successor implements explicit Run9/Save9 validation, lifecycle assignment retention,
retained-document journal5 recovery, mounted-route/native-line activation and the separate
pending-activation startup state. F45dc2df's 23 paths and G b29005cc's four new paths are
composed exactly. Shared reconciliation extends the scene remapper to lifecycle8,
preserves the assignment receipt and checks route family before a legacy physical day lookup.

`SceneEventContract.make_scene_admission` uses the existing issued transaction root and
five-member scene identity. Its canonical request contains exactly schema_version=2,
kind=scene_admission, source_identity, registration_fingerprint, issuer_receipt, target_id,
source_checkpoint, trigger_command_id and return_to. Its continuation_operation child is
ordinal0 under that root receipt, with sorted canonical request_fingerprint and
role=scene.admission projections. The existing exact scene_admitted result remains the
reading reference. Validators rederive issuer/allocation/child and command lineage.
Transition and notification producers use the actual checkpoint/staging owners.

This candidate does **not** enable production scene gameplay. The first scene NewRun
admission lacks a genuine prior scene checkpoint: referring to the first saved snapshot
from its own admission would create a circular hash dependency. No fabricated seed or
precommit Profile-assignment exception is admitted. Challenge playable/end and Contact
entry/return producers remain unavailable. Control/between-entry native restores refuse
before mutation. The production desktop still has calendar presentation dependencies,
so Bootstrap does not configure its scene host. These are remaining implementation work,
not passing filesystem, rendered-journey or whole-runtime evidence.

New tests distinguish journal/transport/injected-owner diagnostics from actual mounted
native frontier restoration. Full positive Save9 filesystem and fresh-process recovery
remain required. Existing accepted B2 and PR23 results are not rerun for continuity.

