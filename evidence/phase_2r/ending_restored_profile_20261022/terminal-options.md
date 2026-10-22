# Terminal constructor reuse: read-only feasibility audit

Inspected equality candidate SceneEventContract SHA256 `67c2c23286de1fb1318b6c68473701367114a2e9b01c2301e0ef6d1bccd98851` while cloud run39776259056 is pending. Current unchanged GameState was fetched at product3f3621bd074d47c6e76d5e5b000a12ada08f142b, blob `ca7fccac2344c9d59b21e101d5ac8930540681e3`. No runtime implementation, test execution, cloud dispatch or remote mutation was made for this audit.

## Finding and recommendation

There is one more defensible call-local reuse: make_scene_terminal_admission validates the bundle, then calls make_scene_receipt, which validates the same unchanged bundle again before any issuer callback. A successful terminal constructor currently performs two bundle validations; an extraction can reduce this to one. This removes precisely one complete validation/index/fingerprint computation per successful constructor invocation, including constructor invocations used by full terminal reconstruction. It does not remove any ledger validation, live issuer call or later public validation. Failure paths that exit before nested receipt construction save nothing.

This is feasible without changing architecture, but is materially wider than the scalar equality change: ordinary event context and receipt wrappers also need extraction. My recommendation after the equality result is one purposeful restored-route diagnostic using the existing aggregate observers before implementing this next candidate. We have no restored per-terminal frequency/cost attribution, so source duplication alone cannot establish meaningful elapsed benefit. Aggregate bundle cost is an upper bound on the opportunity, not terminal-specific evidence. If remaining bundle cost is negligible, stop this surgery. If bundle cost remains material, the bounded extraction below is the next safe candidate; use the already-required restored comparison to measure it. Do not build new instrumentation merely to count this helper.

## Exact refusal order to preserve

The terminal constructor currently checks, in this order:

1. Exact issuer script binding (`scene_receipt_issuer_unbound`).
2. Full fresh bundle validation, returning its original error.
3. Requested target existence, then ending kind and ending.alone.normal entry.
4. Trigger scene_event and its semantic/reading_anchor/result dictionaries.
5. Copy semantic, set terminal.validation playback token; then nested receipt reconstruction checks event version, shape, fresh bundle, marker registration/binding, anchor, result, completion request and completion match, returning the first original failure.
6. Exact trigger receipt reproduction, accepted-transition kind, target and source occurrence/admission relationship.
7. Run/branch/causal source identity consistency.
8. Live transaction proof, live completion child proof, root counter order.
9. Detached terminal record construction and fingerprint, live child derivation, then full terminal shape/live authority checks.

The redundant nested bundle result must already be successful because no input mutation or external callback occurs since step2. Only that successful computation can disappear. In contrast, public inspect_scene, scene_completion_request, make_scene_receipt and validate_scene_result currently reject event version/shape BEFORE invalid bundle data. Moving their bundle validation ahead of shape would change first refusal. Terminal deliberately has the opposite outer order; neither API ordering may be normalized to the other.

## Smallest clean shared-owner extraction surface

Avoid optional trusted inputs or flags on public entrypoints. Three contiguous body extractions give a straightforward proof:

- A private versioned-shape helper owns the existing version guard followed by _inspect_scene_shape. The latter alone is insufficient: it does not perform the version guard.
- A private binding helper owns the unchanged _inspect_scene_context tail after successful shaped and registered results: membership, bound marker matching, registration fingerprint and detached programme entry, context return.
- A private receipt-from-context helper owns the unchanged make_scene_receipt tail after successful context: anchor/result/completion checks and detached receipt return.

Public _inspect_scene_context calls versioned-shape, fresh validate_bundle_structure, binding in exactly the original order. Public make_scene_receipt still calls that fresh context wrapper before the receipt helper. Terminal, only at its old make_scene_receipt site, calls versioned-shape, binding with its existing registered result, then the receipt helper, propagating each failure unchanged. This avoids duplicating the version/shape guard or retaining a cross-call trusted context. Helper names are implementation choices; this is a feasibility design, not an implemented candidate.

An implementation proof should reverse these extractions to recover the equality baseline byte for byte, account separately for the replaced terminal call, and compare the complete affected bodies. Do not move any later terminal callback or combine reconstruction with ledger validation.

## Mutations and boundaries

Bundle validation returns tables.duplicate(true), so registered tables do not alias the caller bundle. Before the redundant call, terminal only reads these tables and the trigger and makes a deep semantic copy; playback_token is written solely into that copy. Shape inspection deep-copies semantic and erases playback_token from its own copy. Context binding mutates only the new shape result and deep-copies the programme entry. Result/completion helpers read their arguments and construct local projections; canonical encoding has no owner callback. Anchor and result are deep-copied into the rebuilt receipt. There is no await or reentrant external call in this segment.

The first real callback is issuer.verify_issued AFTER exact receipt reconstruction and source checks. Keep all subsequent verify_issued, validate_child, derive_child and validate_scene_terminal_admission_shape work intact. No tables from before the outer full validator's callbacks should be supplied to this constructor.

GameState._admit_scene_ending_owned freshly selects registration, issues a root before the constructor, and stores the returned admission in a retry operation only after success. It then independently calls validate_scene_terminal_admission, captures restore state, enters ending and invokes the ending checkpoint writer; failure rolls back or reports uncertain commit. No caller mutation can interleave with the synchronous pure segment described here. Retry-plan state, independent validation, checkpoint writing and rollback must remain untouched. Full validate_scene_terminal_admission itself performs shape/live proof and ledger validation before reconstructing through make_scene_terminal_admission; preserve that public reconstruction's fresh bundle check.

## Existing meaningful coverage and gap

Read authoritative unchanged test bodies at product3f3621bd:

- test_scene_terminal_lifecycle.gd, blob `64be622a49ca0d089787d410c107da652ee25680`: five tests, with setup constructing a genuine terminal transition receipt and terminal admission using the real issuer fixture, then full terminal validation. Covers authenticated roundtrip, trigger/source/target tampering and ordinary-admission refusal, physical completion/Gallery ordering, duplicate delivery, and transaction/session fencing.
- test_scene_terminal_snapshot.gd, blob `a80d7265b63a47595c052f6cc573479cecf4cec3`: two tests covering missing source history and restore identity remapping with preserved terminal plan/reading.
- test_scene_terminal_presentation.gd, blob `997937e818986e2455088fb42ea518243299f5c0`: six tests covering registered neutral presentation, illegal role/target/steps, detachment, insufficient projection authority, restore reservation and terminal/gameplay separation.

The first suite directly exercises constructor success and authenticated reconstruction. Snapshot/presentation suites protect downstream behavior but do not establish malformed constructor precedence. The current 38 contract/receipt tests do not directly cover this terminal constructor either. The restored rendered E2E protects the connected successful journey and durable recovery/history obligations, not malformed API first refusal.

If selected, preserve all existing test bodies and include terminal lifecycle qualification. Add only a meaningful public regression for mixed-invalid constructor inputs (bundle refusal before malformed trigger/event; event refusal before anchor/result when bundle is valid), plus a second-call changed-bundle refusal/fingerprint assertion if not naturally covered in the same scenario. Ordinary make_scene_receipt must still refuse malformed event before malformed bundle. Do not add tests that merely count helper calls or mirror the extraction.

## Where a real decision begins

Safe simplification is not exhausted: this terminal-local extraction remains possible. After it, the audited bundle body has no equally obvious removable obligation. Nested encodings own earlier failure precedence; final encoding owns the exact fingerprint; type/depth checks and header validation have distinct responsibilities. Reusing validation across issuer/creation-owner callbacks, history journals, mutation guards or recovery checkpoints would alter trust/consistency guarantees and requires an explicit design decision. A canonical-writer API for reusing encoded subdocuments also requires owner-level design and failure/depth/encoding equivalence evidence. A large aggregate timing alone does not authorize either change. Prefer the evidence from existing observers before asking the user to choose an architecture.
