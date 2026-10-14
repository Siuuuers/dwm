---
document_role: coordinator_handoff
execution_authority: false
behavior_authority: false
verification_authority: false
---

# A — accepted bounded scene audio interface

15 October 2026, Hong Kong. Engineering interface release under Director
6176804775, implementing the settled TEST slice from6176060458 and B's proposal
67defeec2. This fixes implementation choices; it is not runtime acceptance.
Base: b32cab3ec7d283100195e4053a962ab470d854b1. B may start audio-owned
implementation against this record without waiting for Contacts.

## Observable outcome and custody

A registered TEST scene admission freezes one semantic audio selection in its
own checkpoint before playback changes. Forward admission starts at zero;
fresh Load starts at the registered one-second anchor. Computer open/close does
not invoke audio suspension, selection or activation. Native scene readiness
does not activate audio. The canonical registration owns definitions;
GameState/Save own admission and durable linkage; AudioManifest resolves;
AudioManager owns playback and detached semantic capture.

## Exact registration contract

New registration envelope version3 is version2's exact fields plus
`audio_catalogue`. Version1/2 shapes and hashes remain unchanged.
Version3 retains `contact_definitions`; it does not redefine Contacts.
No production registration is upgraded by this TEST implementation.

Catalogue exact shape:

```json
{
  "kind": "scene_audio_catalogue",
  "schema_version": 1,
  "assets": [
    {"asset_id": "TEST.audio.asset.01", "path": "res://tests/fixtures/audio/scene_test_bed.tres",
     "sha256": "<lowercase SHA256 of the source resource bytes>", "duration_ms": 4000}
  ],
  "plans": [
    {"plan_id": "TEST.audio.01", "revision": 1, "variant_id": "base",
     "ambience_asset_id": "TEST.audio.asset.01", "entrance_ms": 0,
     "load_anchor_id": "load.01", "load_anchor_ms": 1000,
     "authorial": true, "essential": false, "missing_media": "silence",
     "music": null, "cues": []}
  ],
  "bindings": [
    {"entry_id": "<each registered entry in lexical order>", "plan_id": null}
  ]
}
```

The example binding is a shape illustration, not a literal entry.
Every registered entry has exactly one binding; only scene.test.b binds
TEST.audio.01; other TEST entries explicitly bind null (silence).
No implicit inheritance across admissions. Bindings, assets and plans are
sorted unique by their ID. Reject unknown keys, references and duplicate IDs.
Integers must be integers, revision/duration positive, and positions in
[0,duration_ms). Plan schema1 is deliberately limited to this authorial,
nonessential, fixed-base ambience subset: exact true/false/silence/null/empty
values above, no music/cue layer or inferred physical source. No random choice.

Paths must be shipped res://tests/fixtures/audio/ resources, without traversal.
The declared source-byte digest binds the immutable asset definition. Catalogue
validation is pure shape/reference validation; it does not require media to
exist. Playback preparation checks an existing resource's digest and stream
type/duration before mutation. Missing media follows the authored silence
fallback with factual diagnostics; a present wrong-digest resource is rejected,
not silently treated as the registered asset.

Use existing CanonicalJsonWriter SHA256 over the WHOLE registration as
registration_sha256; this includes catalogue, binding and declared asset hash.
Do not introduce a second saved catalogue fingerprint or mutable registry.

## Exact durable subdocument and versions

For version3 only, Run9's existing audio_context contains:

```json
{
  "kind": "scene_audio",
  "schema_version": 1,
  "registration_sha256": "<canonical whole-registration digest>",
  "admission_receipt_id": "<active admitted scene receipt>",
  "selection": {
    "plan_id": "TEST.audio.01", "plan_revision": 1,
    "variant_id": "base", "anchor_id": "load.01"
  }
}
```

Selection is null for an explicit silent binding. All outer/selection keys are
exact. No paths, streams, preferences, playheads, time offsets or fades are saved.
The admission receipt identifies the entry; A verifies it equals the current
admission in the validated scene ledger, then checks that entry's binding.
B validates the plan identity and fingerprint; a nonempty receipt string alone
does not confer admission authority.

Keep Run9/Save9/journal envelopes unchanged: their audio member is an existing
delegated Dictionary, with this new protocol explicitly tagged/versioned.
Preserve the old exact four-key audio context for legacy and registration1/2;
never normalize old retained checkpoint bytes or reinterpret old fields.
A adds version-aware delegated validation and admission/binding checks.
Older software refuses unsupported registration3; no forward-reader promise.

Important compatibility limit: retaining registration1/2 readers does NOT make
old registration2 saves load under changed registration3. Existing full
registration/content fingerprint requirements remain; there is no implicit
cross-registration migration or journal hash rewrite.

## Exact B-facing API

All result dictionaries use existing ok/code/value failure conventions;
returned mutable values are detached. No new configuration registry.

AudioManifest static methods (pure; no owner access or playback):
- validate_scene_catalogue(catalogue: Variant, entry_ids: Array) -> Dictionary
  returns {ok:true,value:<detached catalogue>} after exact coverage validation.
- make_scene_context(registration: Dictionary, entry_id: String,
  admission_receipt_id: String) -> Dictionary
  computes canonical full-registration digest and returns the exact context.
- resolve_scene_context(context: Dictionary, registration: Dictionary) -> Dictionary
  validates exact context/catalogue identity and returns
  {snapshot:<context>, record:<asset+plan record or null>,
   entrance_seconds:<float>, load_seconds:<float>}.
  Null record uses both positions0.0. This validates a selection, not receipt
  authority; A performs receipt-to-entry binding validation.

AudioManager:
- prepare_scene_admission(context: Dictionary) -> Dictionary
  reads the already-selected immutable registration from
  DialogicEntryManifest.scene_registration(), resolves/loads without playback
  mutation, and returns a transient prepared plan. Use runtime script lookup if
  necessary to avoid a preload cycle. Never accept registration from a save.
- apply_scene_admission(plan: Dictionary) -> Dictionary
  validates its prepared semantic input against the installed registration,
  adopts at entrance_seconds after A's durable commit, and is idempotent for
  the identical complete context (including receipt). Compensate partial
  physical failure using existing capture/rollback; propagate fatal if recovery
  fails. A treats a post-durable failure as fatal/recovery-required, not rollback
  of the committed narrative. Do not silently swallow refusal.
- get_semantic_audio_context() -> Dictionary retains its existing signature and
  returns the active detached old or new context.
- prepare_semantic_restore(snapshot: Dictionary, prepared_profile: Dictionary)
  and apply_restore_silent/rollback_restore_silent/finalize_restore keep their
  existing signatures. Tagged context resolves against installed registration;
  restore always uses load_seconds, never entrance/current playhead. Existing
  physical compensation capsules must cover the new semantics and streams.
  No separate saved mirror of selection in GameState or Profile.

AudioPlaybackPort:
- play(player_id: StringName, from_position: float = 0.0) -> Dictionary.
  Preserve old one-argument callers and reject invalid/nonfinite positions.
  Only AudioManifest-resolved positions reach this API in the scene journey.
  Update affected fake ports with the compatible default argument.

Prepared plan contents are B's internal transient representation, not saved
schema. A retains the plan returned by prepare_scene_admission and passes it
unchanged to apply_scene_admission. No engine objects enter checkpoints.

## A-owned hooks and ordering

A reserves DialogicEntryManifest, GameState, SaveManager,
SaveManagerNarrativeCheckpointPort, RunSnapshotSchema, AudioRestoreParticipant,
ApplicationBootstrap, DialogicBridge, shared TEST registration and connected
journey composition, and ContactInvitationState's registration-version gate.
B does not edit these.

1. Manifest v3 delegates catalogue validation to AudioManifest; the canonical
   startup registration remains the only source. A supplies the registration
   fixture and validated active-admission linkage. Both RunSnapshotSchema
   validate_scene and validate_scene_new_run_candidate require the v3 context
   and exact active admission/binding. ContactInvitationState's current exact
   bundle-version2 gate must admit3 with the same contact_definitions semantics.
2. GameState._admit_scene_target_owned freezes make_scene_context's result and
   prepare_scene_admission's plan in its authenticated _scene_entry_operation.
   SaveManager.begin_scene_new_run does the corresponding initial preparation.
3. SaveManagerNarrativeCheckpointPort._commit_scene_event_autosave uses the
   frozen target context ONLY under validated staged-entry custody. It currently
   reads live AudioManager and would otherwise save the previous scene's audio.
   Do not inject an extra key into snapshot_input (its exact shape forbids it).
   A supplies the narrow authenticated staged-entry capture to the existing
   separate audio_context builder argument; ordinary checkpoints use live audio.
4. Commit the target checkpoint, then apply_scene_admission, then activate native
   narrative/captions. No physical audio starts before commit. Retries reuse
   the frozen selection. Repeated readiness does not call this forward hook.
5. Load validates the saved receipt/binding through RunSnapshotSchema, then uses
   the existing AudioRestoreParticipant with preferences plus audio_context.
   Its prepare/capture/apply/rollback/finalize protocol remains; no new saved
   restore-input shape or player readiness hook is needed.

These shared hooks are A's next implementation work, not already installed.
B can implement pure owners and dedicated owner tests now. A composes the
connected real Save/fresh-process Load journey once B's candidate is ready.

## Reservations, acceptance and limits

B is released to claim autoload/AudioManager.gd,
scripts/data/AudioManifest.gd, scripts/audio/AudioPlaybackPort.gd,
tests/fixtures/audio/scene_test_bed.tres and README.md, dedicated audio
tests/fixtures, and specifically necessary fake playback ports (list paths).
A retains shared files above, controller, inventories, integration publication
and handoff/report.md. External C retains scene-control presentation.

Meaningful checks: wrong registration/selection refuses without mutation;
old contexts retain behavior; admission checkpoint stores TARGET audio; failed
pre-commit does not start it; forward0 versus Load1s is observable; fresh Load
and scene readiness do not restart; computer interaction advances playback;
missing media is explicit silence; affected rollback tests still pass.
Use cloud Godot4.6.3 standard/PowerShell. No whole-game rerun or expanded device
matrix. A/separate reviewer reviews B; B does not self-certify independence.

No runtime accepted, cloud run dispatched, Beads closed, master merge or release
by this interface document. Contacts remains the existing TEST.fact.read
engineering journey; no production reply/story/device decision is implied.

