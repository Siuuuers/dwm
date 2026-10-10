# Scene initial admission: proposed finite contract

Status: **cleared for implementation by D6078194122; implementation candidate awaiting cloud evidence**. The initial creation path is explicitly configured; production host/content activation remains withheld. This document does not report passing tests or authorize a merge. It addresses the initial NewRun admission dependency only. Existing schema2 admission receipts and their canonical bytes remain unchanged.

## Observable outcome and current blocker

A genuinely new scene run should retain one creation transaction, one allocated identity, one assigned form and its actual initial reading checkpoint before publication. An interruption must finish those same materials without redrawing, allocating again or manufacturing a previous checkpoint.

Current `SaveManager._prepare_new_run_decision_from_sources` prepares the allocation and complete Autosave before committing the continuation intent or allocation. `NewRunMaterials._validate_autosave` then invokes ordinary `SaveDocumentSchema.validate`. Current scene admission requires both a committed allocation and a source checkpoint. These requirements cannot describe the first checkpoint: its snapshot cannot contain a receipt that hashes that same snapshot, and its allocation is still a prepared candidate.

The proposed solution is an explicit initial-admission variant plus separate candidate and committed validation entry points. It is not a nullable source-checkpoint exception or a general validation bypass.

## Exact initial receipt variant

Use the existing outer command-receipt family with these exact members:

```text
{
  transaction_id,
  request_fingerprint,
  kind: "scene_admission",
  source_id,
  scene_admission
}
```

`transaction_id`, `source_id`, the command-receipt map key and `result.occurrence_id` all equal the existing NewRun creation transaction token. Do not issue a second admission root or add an allocator. The creation root is already issued by the existing identity owner before allocation preparation.

The initial `scene_admission` object has exactly:

```text
{
  schema_version: 3,
  registration_fingerprint,
  source_identity,
  issuer_receipt,
  allocation_candidate_sha256,
  scene_assignment_sha256,
  provenance,
  result
}
```

All digests are lowercase 64-character SHA256 strings over `CanonicalJsonWriter` output. `registration_fingerprint` binds the complete installed registration bundle. `allocation_candidate_sha256` binds the complete existing allocator candidate. `scene_assignment_sha256` binds the exact G-owned assignment receipt, including form, creation identity, initial nonce or predecessor, and its existing provenance. It does not hash Profile's entire outgoing document.

`source_identity` is exactly the five-member scene identity:

```text
{
  run_id,
  branch_id,
  desktop_timeline_generation,
  causal_day_instance,
  causal_day_instance_issuer_receipt
}
```

Its values are projected from the same allocation candidate. `issuer_receipt` is that candidate's `request.transaction_issuer_receipt`, with the existing exact issuer receipt shape. Both references must agree with the retained operation's creation transaction.

The initial result has exactly:

```text
{
  kind: "scene_initial_admitted",
  occurrence_id,
  entry_id,
  target_id
}
```

The target must be an installed registered target of kind `scene`; its registered entry supplies `entry_id`. The owning NewRun producer selects the actual initial target and freezes it in the intent. No production target, story text or form-to-target mapping is invented by this document. Initial results have no `source_checkpoint`, `trigger_command_id` or `return_to` members. Later schema2 admissions retain all of their existing members and obligations.

## Canonical fingerprint and child provenance

The request fingerprint is SHA256 of the exact canonical object:

```text
{
  schema_version: 3,
  kind: "scene_initial_admission",
  registration_fingerprint,
  source_identity,
  issuer_receipt,
  allocation_candidate_sha256,
  scene_assignment_sha256,
  target_id
}
```

The result is reconstructed from this request and registered target; it is not an independent claim. The request deliberately contains no snapshot hash, outgoing Autosave hash or continuation-operation fingerprint. Those outer objects subsequently bind this receipt, so no hash depends on itself.

Use `DesktopIdentityNonceIssuer.derive_child` with the existing exact request shape:

```text
{
  parent_receipt_id: issuer_receipt.receipt_id,
  child_kind: "continuation_operation",
  ordinal: 0,
  source_ids: [
    "request_fingerprint=" + canonical(request_fingerprint),
    "role=" + canonical("scene.initial_admission")
  ]
}
```

The two strings are lexically sorted, unique projections. `canonical` means `CanonicalJsonWriter.stringify(value).value`: strings include their JSON quotation marks. In particular the second projection is literally `role="scene.initial_admission"`. No newline is appended to a projection or fingerprint preimage.

The existing issuer derives the child with its unchanged domain/preimage:

```text
desktop_child_v1\n<namespace>\n<parent counter>\n<parent receipt ID>\n<child kind>\n<ordinal>\n<canonical source_ids array>
```

The generated ID remains `continuation_operation.` followed by that preimage's SHA256. Store the returned exact provenance object `{schema_version:1,parent_receipt_id,child_kind,ordinal,source_ids,child_id}`. Recompute the full request and projections before calling `validate_child`; generic child validation alone does not prove the intended role. No issuer method, child-kind union or historical child preimage changes are proposed.

## Candidate validation is not committed authority

Proposed explicit interfaces:

```text
SceneEventContract.prepare_scene_initial_admission(
  allocation_candidate: Dictionary, profile_material: Dictionary,
  target_id: String, bundle: Dictionary, issuer: Object) -> Dictionary

SceneEventContract.validate_scene_initial_admission_candidate(
  receipt: Dictionary, allocation_candidate: Dictionary,
  profile_material: Dictionary, bundle: Dictionary, issuer: Object) -> Dictionary

SaveDocumentSchema.validate_scene_new_run_candidate(
  document: Dictionary, allocation_candidate: Dictionary,
  profile_material: Dictionary, bundle: Dictionary, issuer: Object) -> Dictionary
```

The preparation result is `{ok:true,value:receipt}`. The two validation entry points fail closed and return detached validated values using their owners' normal result conventions. None grants a live session, publication, Start permission or a committed-Load claim.

Candidate admission must:

1. Verify the actual already-issued creation transaction receipt through the existing issuer.
2. Reproduce the entire allocation with `issuer.prepare_continuation_allocation(allocation_candidate.request)` and compare exact types and canonical bytes. Require `kind=new_run`, null existing-run/source-generation inputs and an empty remap set. This proves a prepared candidate; it must not pretend its future causal receipt is already in the committed root.
3. Invoke G's strict `validate_scene_new_run_material(profile_material)`. Bind its assignment run and creation transaction to the allocator candidate and root. Preserve the exact assignment receipt, nonce/predecessor and frozen before/candidate Profile material. Do not substitute current Profile state, skip its checks, or derive another draw during validation.
4. Validate full installed registration/target, exact initial receipt and initial reading/frame. Validate complete initial Run9/Save9 shape, initial gameplay constraints, sequence `1`, the allocation identity and lifecycle assignment against those same materials. Do not merely validate JSON primitives.

`NewRunMaterials._validate_autosave` uses the dedicated candidate entry point for this initial scene variant. It retains strict outgoing canonical bytes/hash, saved time, Autosave discriminator and empty initial recovery journal checks. Ordinary Save9 validation remains the committed-state path. There is no public `skip_validation`, caller trust Boolean or permissive Profile callback.

Committed admission must prove that the same full allocation is now in the existing root, the matching creation operation is durably committed, and the retained assignment has actual matching Profile proof. GameState resolves creation authority through SaveManager's existing continuation owner; a copied receipt, an issued root alone or Profile bytes alone is insufficient. A suggested owner query is `capture_committed_scene_creation(creation_transaction_id)`, returning detached operation/allocation/assignment proof only after the creation's required completion and activation fences. Earlier operation stages remain accessible only to recovery, not ordinary selected Load or Start admission.

Complete receipt validation exposes the initial result for Frozen frame derivation only after the relevant candidate or committed authority path has succeeded. Frozen derives the same occurrence/admission frame IDs but explicitly recognizes `scene_initial_admitted` without attempting a source-checkpoint check. Runtime source and live-session checks remain mandatory.

## Existing owner ordering and journal delta

1. Under existing creation custody, issue the one creation transaction root and prepare its allocation without committing it.
2. Prepare G's joint assignment using that allocated run ID and creation root. Freeze any first-assignment randomness once.
3. Build schema3 admission, silent initial reading/frame and complete Run9 snapshot. Validate the complete initial candidate; serialize its canonical Autosave.
4. Retain the existing complete NewRun material `{allocation_candidate,autosave,profile}` in the existing durable continuation intent. The admission is inside the retained snapshot; no new store or independently mutable assignment counter is added.
5. Commit the same allocation, persist/prove the same Autosave and prove→persist→prove the same Profile material using the existing ordered target receipts. Retries use the retained bytes and receipt, never a later Profile tail or a freshly selected target.
6. Revalidate committed target proofs, apply participants silently and use the scene completion/activation fence. No native publication or input readiness before the required durable decision and actual activation acknowledgements.

The owning creation/recovery path prepares those silent participants through the explicit initial-candidate validation path plus its retained intent and freshly reproved target receipts. It must not call the ordinary completed-creation authority query to prepare the operation that will establish completion. This separate owner path is required both before the first durable intent and during reconstruction after interruption; it never exposes a publicly admitted live run. Ordinary selected Load uses the committed path only.

The current journal still admits only the legacy NewRun context (`main` and captured `dark_mode`) and nine-participant order. It therefore needs an explicit journal5 scene-NewRun variant. Preferred discriminator: `kind=scene_new_run`, with the existing exact NewRun operation members plus `activation_state`; the allocator request remains `kind=new_run`. The operation request fingerprint uses `kind=scene_new_run` and retains the existing `{kind,transaction_id,initial_context,new_run_materials}` preimage structure. Its initial context is the existing proposed scene five-member context `{active_app_id,audio_context,content_version,dialogic_checkpoint,route_id}` with `route_id=scene`.

This variant retains the existing identity/Autosave/Profile target order and scene eight-participant order. `activation_state` is null before COMPLETED, atomically pending with durable COMPLETED, and acknowledged only after actual native frontier, mounted route and current live-session success. Historical schema4 NewRun members, context, order, receipts and bytes remain unchanged. Envelope promotion must not reseal historical operations.

The pending completed scene-NewRun operation must remain reachable through the same incomplete scan/reconcile/resume machinery as pending scene restores. Acknowledged historical creations are not replayed on every boot. Conflicting pending operations refuse. Uncertain writes require physical reread while fenced; failed reread is not evidence of refusal. Postcommit activation failure retains the target, assignment and identity with fatal custody, not compensation or another allocation.

## Bounded future evidence

These are required future tests, not completed results:

- Both controlled initial forms and exact retained assignment reuse after cancellation/refusal/retry; no extra successful-creation turn spent.
- Wrong creation root, candidate digest, assignment receipt/form, run identity, registration, target or child projection refuses even when individual fields are well formed.
- Schema2 with missing/null source checkpoint still refuses; schema3 with source/trigger/return extras refuses. Unsupported version and integer/float substitutions refuse.
- Candidate validation succeeds before allocation commit through exact allocator reproduction; ordinary committed validation still refuses that same prepared-only material.
- Missing/altered Profile material or unproven persisted Profile never becomes success through the candidate path. Profile-success/later-failure recovery reuses the frozen receipt once.
- Initial Autosave contains a genuine reading/frame and no invented previous checkpoint. A second initial root for one run, wrong occurrence frame or preexisting effects/attempts/history in an initial candidate refuses.
- Interrupt on both sides of intent, allocation, Autosave, Profile, completion and activation acknowledgement; reconstruct from original retained materials with no redraw, new identity, duplicate effect or premature publication/Start.
- Physical reread after a promoted-but-reported-failed write distinguishes pending committed state from a definite refusal. Multiple pending creations/restores fail closed; old acknowledged creations are not replayed.
- Real filesystem Save/Profile, mounted native route and actual reading owners establish the positive connected path. Synthetic semantic fixtures may diagnose individual failures but cannot certify that path.

The initial target/content producer and all paired schema/owner changes remain implementation dependencies. No fake positive Save9 fixture, fabricated checkpoint or claim of approval is introduced here.
