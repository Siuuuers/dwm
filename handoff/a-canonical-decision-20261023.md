# Canonical validation decision — 2026-10-23

## Outcome and scope

Source-only decision brief; no runtime edits, Godot/PowerShell execution, diagnostic dispatch, export retry, merge or promotion. Lead review plus independent canonical-owner review agree: do not add another micro-optimization merely to continue.

Authoritative candidate: c787ff11e177973a7919972de3bcd630e51e6d82. SceneEventContract SHA256 7aa86be14dd8bd435f2a77d35e3b403b628c3c707b3c64944ad99f3d7e0509ff. CanonicalJsonWriter read at that exact revision. Existing audits in ending_validation_audit, ending_equality_reuse and ending_restored_profile remain applicable; previously qualified admission/equality/terminal reuse is already present.

Live reconciliation: master41592fcc792aa615e47ee2ce2f05008ca195b311; PR36c8358870d3ece92d5f8cc7ba65aefe34a746be5c; integration3ae6d9138fb53c388380c78550cf6082eafc0ea3; PR30 controller4e6a1c805ff19726bea9b18cee5f40d0a04fadee. No newer master fix supersedes this task.

## Existing evidence, not new qualification

GitHub job119909684717 for run39803289039 is completed/success, including focused unit and restored rendered journey steps. Latest handoff retains47tests918assertions, five clean exits, exact Day4 restore/witness Save/Back, six remaining captions, durable COMPLETED/GALLERY_RECORDED, Title/freshDay1 and source/witness/history guarantees. Original archives were not re-downloaded or re-qualified.

Latest recorded complete Accept48.976581s; bundle4424calls24.652005s inclusive. The baseline51.664227s comparison is one instrumented pair and does not establish causal/general speedup. Nested categories overlap. Approximately49s remains a responsiveness problem.

GeneralCI39803289755 separately fails public API inventory verification (job119909687445 step10); downstream jobs are mostly skipped, and retained-history aggregation fails its missing-producer requirement. This is not broad green or a newly diagnosed gameplay regression.

## Obligations that cannot simply be deleted

SceneEventContract._json_data rejects non-JSON types, nonfinite floats, non-String keys and depth beyond128 before header validation. The writer deliberately accepts some StringName inputs; its checks do not replace this contract.

DialogicEntryManifest remains the versioned header and Contacts/audio association owner.

Four nested stringify calls occur in fixed order before programme/table validation and own scene_bundle_nested_invalid. Final stringify follows structural checks and owns scene_bundle_invalid plus exact whole-bundle fingerprint. Moving or deleting these changes failure precedence.

CanonicalJsonWriter's native eligibility depth64 selects a fast path; it is not a global acceptance cap. Checked emission preserves scalar encoding, normalization, float round-trip and structural-error order. Do not add a new depth64 rejection.

## One concrete conservative alternative, considered and deferred

A writer-owned invocation-local composition context could retain the four successful nested encodings. At the current final encode location, run the existing whole-root native-eligibility traversal unchanged. If it passes and root keys are printable ASCII Strings, sort root keys, emit identical canonical key bytes and punctuation, splice those four internally produced encodings, and encode the other members. Otherwise call existing stringify(bundle) unchanged.

Equivalence obligations:
- Exact root bytes and SHA256, ordering, escaping, integer representation and Unicode behavior.
- All four earlier nested failures stay at their current positions; structural checks retain order; final failures remain final.
- Root depth eligibility is recomputed at its original depth. No inference from standalone nested depth eligibility.
- Full-root native success implies each earlier subtree was eligible at depth0; fallback paths remain unchanged.
- Context cannot accept caller-supplied trusted JSON; it binds one root within one synchronous callback-free segment.
- No mutation, await, owner callback, cross-call reuse, durable trusted state or retained cache; discard on every exit. Caller audit must prove the lifetime.
- General writer behavior remains unchanged outside this bounded path.

Why defer: this still repeats the entire native eligibility traversal and only removes native re-encoding of four fields. Current aggregate evidence does not isolate that cost. A new context API/composition path/equivalence suite would add complexity for unproven value. No new instrumentation framework or unchanged cloud replay is justified for this idea now.

## Architecture decision requiring owner direction

Recommended next scope: design (not yet implement) immutable installed-registration ownership with explicit revision replacement. Goal: reduce repeated pure registration work while preserving live issuer verification, physical/history proof, all three recovery checkpoints, and exact saved fingerprints.

A concrete design must answer:
1. Which existing owner captures/detaches a registration revision and prevents mutation? Avoid a second competing registry.
2. Which install/reload/content-replacement operation advances its generation, and which consumers can currently mutate raw dictionaries?
3. What happens if replacement occurs across an issuer callback or between recovery phases? Prior observations cannot automatically authorize the next boundary.
4. How do existing public dictionary APIs retain fresh validation, first refusal and malformed-input behavior? A new immutable internal representation must not turn untrusted persisted input into trusted authority.
5. What exact evidence proves old saves/history reproduce the same canonical bytes and completion receipts, and new revisions cannot borrow prior validation?

These are unsolved design obligations, not an implemented safe cache or a promised speedup. Do not silently change mutation/refusal semantics or recovery boundaries.

Alternative: retain the current mutable/fresh-validation architecture and explicitly defer responsiveness while proceeding to exported Windows/CI closure. This does not call49s acceptable or resolved, and it is not release acceptance.

The user should choose whether broader registration ownership redesign is in scope now. The existing handoff expressly reserves callback-spanning reuse and recovery/trust changes for architecture decisions. No new session is needed; source context is ready.

## Resume

After direction, either prepare one concrete owner/caller/invalidation design for review before implementation, or retain latency as an open defect and resume existing exported/CI closure with its pinned evidence and deadlines. Never rerun accepted qualification, extend a deadline, remove a checkpoint, trust persisted validation, or resurrect the withdrawn ending-style patch as a shortcut.
