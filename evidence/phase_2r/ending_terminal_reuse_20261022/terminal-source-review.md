# Independent source review — terminal-local bundle reuse

PASS for source/caller semantics; cloud parsing, focused regressions and restored complete-operation qualification remain pending. No engine/PowerShell execution, shared candidate edit or remote mutation was performed by this review.

Baseline SceneEventContract SHA256 `67c2c23286de1fb1318b6c68473701367114a2e9b01c2301e0ef6d1bccd98851` matches accepted equality product4278756add50ea27da8237106260a0efee606cda. Candidate SHA256 is `7aa86be14dd8bd435f2a77d35e3b403b628c3c707b3c64944ad99f3d7e0509ff`.

I independently reconstructed the entire original file from the candidate: remove the three new private helpers, restore the two extracted public/context wrappers, and replace the sole terminal reconstruction call sequence with the old make_scene_receipt call. The result is byte-exact baseline. I separately compared the extracted binding and receipt tails byte for byte and read their complete bodies and supporting shape/result/completion helpers. The change is limited to three existing function bodies and three extracted helpers; fifty other function bodies remain unchanged.

## First refusal and freshness

Public inspect_scene, scene_completion_request, make_scene_receipt and validate_scene_result still route through _inspect_scene_context. The original version guard runs first, then shape validation, then a fresh complete bundle validation, then unchanged registration binding. Invalid event/version continues to win over a simultaneously invalid bundle. Public signatures and returned errors/data are unchanged; no optional trusted context or cross-call cache was added.

The terminal constructor retains its deliberately different order: exact issuer script check; fresh full bundle validation; registered target/ending constraints; trigger/event dictionary checks; version/shape; binding; anchor/result/completion checks; exact receipt and source checks; live issuer validation. Only the repeated successful bundle validation formerly inside make_scene_receipt is removed. Bundle invalidity still precedes malformed event for this constructor; event invalidity still precedes anchor/result errors after a valid bundle. The version guard is retained explicitly through the new helper rather than accidentally relying on _inspect_scene_shape alone.

The initial validated tables are detached by tables.duplicate(true). Prior to reuse, terminal reads them and makes a deep copy of event semantic; playback_token is assigned only to that copy. Shape inspection duplicates semantic; binding modifies only its new shape result and duplicates the programme entry; receipt construction duplicates anchor/result. No callback, await, external read or input mutation occurs in this segment. The same registered values and fingerprint therefore substitute for the duplicate successful computation without sharing new authority or mutable saved state.

## Authority and caller boundaries

The first live issuer callback remains after receipt reproduction and source checks. verify_issued, validate_child, derive_child, terminal shape/live proof and the public full-terminal validator are unchanged. Full-terminal validation still checks shape/live authority and the entire ledger before calling the constructor, which performs its own fresh bundle validation. Reuse never crosses those callbacks or a public entry.

I fetched current GameState at the accepted product and confirmed blob `ca7fccac2344c9d59b21e101d5ac8930540681e3`. _admit_scene_ending_owned still freshly selects registration and issues the root, calls this constructor, stores retry material only after success, independently validates the resulting terminal admission, captures rollback state, enters the ending and invokes the existing checkpoint writer. Uncertain-commit refusal, rollback and retry operation clearing remain untouched. The candidate does not change any caller, ledger, save format, checkpoint count or recovery boundary.

## Required acceptance

The measured restored profile establishes that aggregate bundle work remains material; it does not isolate this constructor's share or promise elapsed benefit. This change saves precisely one full validation per successful constructor that reaches the replaced site. Qualification must retain current contract/receipt tests and terminal lifecycle tests, meaningful mixed-invalid first-refusal and fresh changed-bundle regressions, and the same rendered creator/loader journey, profiling, deadlines and durable/history gates. Do not substitute invocation-count tests for those behavior checks or claim performance from the source diff alone.

No source-level blocker or architectural decision remains for this narrow candidate.

## Focused test review

PASS static review of terminal lifecycle test SHA256 `82f996cee273ab38a69f8e54d5eaaba64699f80f883170e0e8e4b60627cd46fc`. The original12,094-byte body (Git blob64be622a49ca0d089787d410c107da652ee25680) is an exact prefix, preserving all five existing tests. Two tests plus a public-constructor helper were appended. Each asserted first-refusal code was checked against current runtime order: issuer, bundle, missing/wrong-kind target, malformed trigger, version/shape, anchor and result. Ordinary receipt version/shape refusal still precedes bad bundle. The second test confirms detached returned input material, successful reconstruction, changed valid bundle fingerprint producing scene_completion_mismatch, invalid next-call bundle rejection and successful return to original bundle. Inputs/durable trigger remain checked unchanged. Explicit Dictionary locals avoid inferred Variant locals on these paths. No tests merely count helper invocations. GDScript parsing and runtime results remain pending cloud qualification.
