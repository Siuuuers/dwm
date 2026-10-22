# SceneEventContract audit after restored ending qualification

Scope: source-only audit of product `3f3621bd074d47c6e76d5e5b000a12ada08f142b`. No runtime edits, cloud run, or remote mutation made. Current contract local SHA256 `e4b6562355bf5e58a575a272c228be557102b08f65ad9ab35dbe4a0c754253fc` matches the current source-custody pin, Git blob `d410ec384b41c8af00993b1c94e85bb9f2c25ca7`. Current GameState caller was read from GitHub, blob `ca7fccac2344c9d59b21e101d5ac8930540681e3`.

## Recommendation

One small additional candidate is justified for review: reuse the already-computed bundle tables **only inside make_scene_admission**, between its full bundle validation and its immediate pure result-shape check. Do not widen this to a ledger-wide context/cache.

Current sequence in make_scene_admission:

1. Validate issuer script and identity shape.
2. Verify transaction issuer receipt, causal issuer receipt, and live allocation identity proof.
3. Fully validate/index/fingerprint bundle into local `registered`.
4. Check target presence/kind and construct a detached result.
5. Call `validate_scene_admission(result, bundle)`, which fully validates/indexes/fingerprints that unchanged bundle again before pure result checks.
6. Construct request/fingerprint, derive child through the real issuer, return receipt.

Between steps3 and5 there is no issuer/SaveManager/Profile callback, no await, and no input mutation: only target reads, a checkpoint deep copy, and detached return context. The second bundle computation is pure redundancy. Suggested extraction: leave the public validate_scene_admission's full validation as-is, then delegate its unchanged post-bundle body to a private `_validate_scene_admission_registered(result, checked)` helper. Have make_scene_admission invoke that helper with its immediately preceding local `registered` value. The post-bundle check order, failures, copies, request encoding and issuer calls must remain exact.

This removes one bundle computation per valid version2 admission construction/reconstruction. It introduces no cache, stored trust bit, public context argument, manager, or durable schema change. Public validate_scene_admission and make_scene_admission continue fresh validation on every entry.

## Why this differs from the previous optimization

Prior accepted call-local reuse covered event inspect/result/completion projections. It did not change admission construction. Current `_validate_scene_admission_receipt` performs one public result validation, then public make_scene_admission performs two bundle validations: three total per version2 admission. The proposed candidate changes that to two, retaining the earlier public result validation and the later fresh bundle validation after live issuer/allocation calls.

The outer validate_scene_receipts already has a `registered` result, but it crosses real `issuer.verify_issued`, `issuer.validate_child`, `issuer.capture_root`, creation-owner capture, and other authority checks while walking the ledger. Reusing that result through those boundaries is a materially broader change and is not recommended. Similarly, do not reuse the prevalidation tables from `_validate_scene_admission_receipt` across make_scene_admission's live verification calls. Preserve callback order and first refusal even if these calls appear repetitive.

GameState's existing admission caller issues the transaction identity, calls make_scene_admission with the current registration and live issuer, and consumes the resulting immutable receipt before presentation. No caller change is needed. Historical receipt reconstruction uses the same public entrypoint and would gain the same pure-work reduction while retaining authority checks.

## Evidence and source-derived work counts

Restored run39762896961 ending Accept took **59.347270s**. Its three nested writers took17.118577/20.044663/21.980125s. This run intentionally has no aggregate profile, so no measured proportion can be assigned to admission bundle work.

The accepted short-route optimization run39759857757 has9 aggregate scope records, totaling724 bundle validations/4.294682s,188 receipt validations/9.523689s, and188 physical proofs/1.559744s. These totals overlap; they are not additive. That short route starts directly at Day7 and has no intervening version2 day admissions, so it is not a useful performance comparison for this candidate.

The retained restored completed autosave contains the following concrete receipt cardinalities:

| Snapshot | State | Initial admission v3 | Admission v2 | Scene events | Full bundle checks per valid validate_scene_receipts body, current → candidate |
|---|---|---:|---:|---:|---:|
|8, manual Day4 save|PLAYING|1|3|3|14 → 11|
|9, restored witness save|PLAYING|1|3|3|14 → 11|
|18, epilogue played|ENDING|1|6|7|27 → 21|
|19, Gallery recorded|ENDING|1|6|7|27 → 21|
|20, completed|COMPLETED|1|6|7|27 → 21|

Counts follow the valid normal-route body: one outer bundle validation + one initial-admission reconstruction + three per version2 admission + one per scene-event reconstruction. They exclude external terminal-admission checks, other callers and other ledger passes; they are not total whole-Accept counts. Saving6/27 bundle computations at a terminal ledger pass is not a predicted22% wall-time improvement. The historical journal makes each saved version2 admission relevant repeatedly, but the actual elapsed benefit remains unknown.

## Minimum meaningful qualification if selected

- Independent exact-body/caller review: public fresh validation retained; no moved live call or refusal; private helper only receives a just-computed local result across no callback.
- Existing contract and receipt unit suites cover scene-admission shapes, checkpoint type refusal, engine-string rejection, actual issuer proof and exact reconstruction. Add a focused test for public fresh bundle validation after a successful call, and malformed result+bundle refusal precedence at public boundaries. Assert unchanged input data and exact reconstructed receipt; avoid a broad framework or implementation-mirroring test.
- One changed-candidate restored journey with the existing phase observations, fixtures,240-second child ceiling and15/20/5-second guards provides the directly relevant complete-operation comparison to39762896961, alongside durable/readback/history gates. Do not rerun the short route merely to measure a path with no version2 admissions. Keep the current aggregate flags off for matching observation settings unless a separate concrete question requires profiling.

This is a reviewable candidate recommendation, not proof of speedup. If the sibling snapshot audit identifies a larger equally narrow safe change, select one coherent candidate rather than overlapping exploratory runs. Retain all three ending recovery boundaries and all live/physical proof traversals.
