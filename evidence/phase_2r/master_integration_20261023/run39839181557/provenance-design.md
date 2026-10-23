# PR9 finite provenance repair proposal

Proposal only. No product refs/index, runtime, frozen fixtures, behavioral probes, engine or PowerShell execution changed. Patch target is the integration test only. Source is candidate d1d8313cff343a46733c021ad9125d6c0702eeff.

## Recommendation and simplicity cost

Use the attached single-function finite inverse, before the existing Notes inverse. It maps the exact current inherited owner back to the exact accepted composition at 23d8b3dfdd63948549af318917df5f4a84ac5120 (`Compose accepted marker Notes HUD and pure progression foundation`). Then keep every existing Notes, marker, scene extension, frozen method, five isolation edits, and retired source seal unchanged.

There are 18 changed spans: 17 deletions and one replacement. They remove/replace 89,096 current UTF-8 bytes and restore only 84 historical bytes. Current owner is 292,650 bytes; accepted owner is 203,638 bytes. The helper is 1,980 bytes; the unified patch is 4,069 bytes. Inline fixed byte spans avoid an external manifest schema/parser or a 203KB historical copy. The complete input hash authenticates every retained and removed byte before offsets are used. Ordered bounds checks reject invalid spans, and complete output hash authenticates the reconstructed accepted owner. Offsets identify unique locations under the exact input identity; substring matching is unnecessary.

This is evidence reconstruction only. The resulting source is never loaded as executable runtime code. Both frozen controls still extend the actual CURRENT owner, and their bodies and all historical six-direction probes remain unchanged. Full input identity therefore continues to reject unknown inherited-owner drift. A historical snapshot plus current hash can also pin the inherited owner, but no longer demonstrates the existing reversible relationship to the historical foundation; relaxing that contract should be a separate decision. Historical-source-only authentication loses the inherited-current-owner guard entirely. A generalized accumulating inverse-history system is unnecessary here: this one finite layer is bounded to two reviewed owners and should be revisited deliberately when the current owner changes.

## Exact authentication chain (normalized UTF-8 LF)

| Source/layer | SHA256 |
|---|---|
| Current GameState from d1d8313 | c3b9949ba09bf1a47969afd73daf835645bb7b4eb494d91f19a6f7e222917c4d |
| Reconstructed GameState, byte-equal to Git 23d8b3df | 6cbd8f935e2fb6c02db5e78cbafd915d5cd2971712d061c5d9e8f336bbea100f |
| Existing seven Notes inverses | 264c91220e99977085838f24ced5f9a4ef95eb74f8c24609aebcbf98b63707db |
| Existing marker inverse | ce2fb9fc8c9821c8857641a377d0832fb1a862bafd86268c43226b24329ff2a8 |
| Existing 10,108-byte scene extension removed, foundation | 02ed11392633e9ded43609d93977adb0805870880add55b67c483d5d305694bc |
| Existing five isolation edits and retirement fragments reversed, byte-equal to Git 226d3da868784baacc6fc33f58823f95b5815a51 | 95073205c6016935a3fb6339f004129e0ac93cf8728e64f812a940891a27da5c |

Both Python scripts authenticate/reconstruct against Git bytes and exact existing constants. `build_proposal.py` generates the candidate and `static-validation.json`; `verify_layers.py` checks all seven Notes fragment identities/counts, marker identity/count, extension identity/size, and intermediate full hashes. These are static checks, not engine acceptance.

## Claim boundary and qualification

The five edits claim now explicitly refers to the reconstructed foundation. Current `capture_restore_state` has later scene-assignment behavior; this patch does not claim current runtime differs from the historical owner only by five edits. Preserving current actual-owner probes plus frozen controls provides the dynamic comparison; current scene behavior needs its own existing qualification.

Smallest safe qualification: first retain actual canonical failing evidence for the stale provenance contract. Apply the single test patch, run the canonical inventory generator because assertion inventory changes, then use the canonical cloud job. Confirm `test_run_restore_isolation` and `test_live_run_rollback_isolation` run with their unchanged six-direction controls and current-owner checks, with no skipped failures or weakened historic hashes. No runtime redesign is justified by the static provenance mismatch itself. Production Notes remains test-only/held.
