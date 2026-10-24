# Recall-local registration reuse and malformed prepare-request refusal

Continues [the continuation cache handoff](g-continuation-backup-cache-handoff-20261024.md). All Godot and PowerShell execution remained on Windows GitHub Actions; local work was source review, Git, evidence verification and packaging. The prior cache repair was already merged as PR #69 and was not repeated.

## Product outcomes and ownership

PR #70 fixes the separate `_intent_keys` follow-up: non-string prepare-request kinds now reach normal refusal before any storage access, rather than an incompatible Variant comparison. DesktopContinuationOperationJournal retains ownership. Six malformed types, each with/without selected_document, preserve submitted inputs and durable bytes. This is not a performance change.

PR #71 keeps the same recalled outcome and restored caption while doing less repeated registration work. SceneEventContract remains the owner. `resolve_scene_challenge_recall` still freshly inspects its public-entry event and bundle; each matching closure still passes its own envelope shape, marker binding, anchor, result, exact receipt and ambiguity checks. The fresh entry call's detached tables are reused only within the synchronous callback-free closure scan. No cross-call cache, new manager, public API, trust flag or saved field is introduced.

Do not extend this reuse to the enclosing receipt-validation call. Issuer and creation-owner callbacks occur before recall entry, and the fresh bundle check here remains the post-callback refusal boundary. The existing reason to retain route-context validation also remains valid.

## Attribution that selected the change

First diagnostic run [40075861349](https://github.com/Siuuuers/dwm/actions/runs/40075861349), source `b8f853d18fc32ef4e4b951a1b0f7dfaf0871cf22`, measured 42 receipt validations / 32.563223 s, including 30.675097 s in registered receipt work and 6.131164 s in committed initial admission. Initial-material validation was only 0.612652 s (1.88% of receipt time). Its duplicate Profile serialization was therefore not selected for surgery.

Deeper run [40076476864](https://github.com/Siuuuers/dwm/actions/runs/40076476864), source `0ba1587982690564cbdfe0d42e005d883f3022e0`, measured 42 recall calls / 16.095709 s within 29.384618 s receipt validation (54.78%). Bundle validation was 92 calls / 17.494189 s across the scope. Receipt reconstruction was 1,487 calls / 0.481142 s; other admission validation was 1,092 calls / 3.298317 s. Equality was 45,146 calls / 4.586471 s. These are inclusive nested totals, not additive exclusive costs. Equality's false counter includes normal comparisons, not necessarily refused validations. Creation phase probes are adjacent work intervals, not exclusive function stopwatches, and their hardcoded `ok=true` samples do not establish validation success.

Both diagnostics pass two current native cases / 213 assertions / three clean process exits, with exact slot bytes and complete visible restored caption. Historical input cases are excluded. Differences between the two diagnostic runs are not performance evidence.

## Focused and connected qualification

Guard: [40075859440](https://github.com/Siuuuers/dwm/actions/runs/40075859440) passes 46 cases / 3,411 assertions, including 61 assertions in the new malformed-kind regression. [40076271294](https://github.com/Siuuuers/dwm/actions/runs/40076271294) regenerates and checks both public inventories and repeats the same passing focused census. [40076584748](https://github.com/Siuuuers/dwm/actions/runs/40076584748) checks committed inventories without regeneration and passes 11 drift/read-only cases / 352 assertions. All relevant process exits are zero. The 15 refreshed inventory references are line positions only, including drift from earlier commits; no API or required contract changed.

The original PR #70 run [40075910962](https://github.com/Siuuuers/dwm/actions/runs/40075910962) remains failed in its stale-inventory job. Its matched startup/Load job passed both 112-assertion variants. Downstream release jobs in that original run were skipped; later corrections do not relabel its failure.

Recall candidate `8a701902b387190f1f0965785b970d011a4c88db` is exercised by controller `5d2373e02ad44d4e5dbf80f6425369fe2ceb6737`, which differs only by its workflow. [40077022792](https://github.com/Siuuuers/dwm/actions/runs/40077022792) passes 48 focused cases / 537 assertions. Three new cases cover fresh changed-bundle refusal, seven closure-tampering forms and mixed-invalid precedence. The existing tests cover all five outcomes and input/result detachment.

The native recall lane passes exactly two named cases: create 81 assertions and distinct-process Load 47, with two clean exits. Its three retained captures show the pre-recall caption and matching original/restored selected captions. This uses synthetic authored registration with actual native owners and storage; the native example is never_started, not all five rendered outcomes. The focused lane also regenerates/checks inventories; the resulting 21 caller references are location-only changes.

## Matched complete-operation result

The comparison lane of run 40077022792 uses baseline `5c12b1f35d175582490adace0bc04e3c67bfb138` and candidate controller `5d2373e02ad44d4e5dbf80f6425369fe2ceb6737` on one Windows runner, baseline first. Exact separate worktrees share identical measurement helpers, retained input and checksum-pinned Godot 4.6.3. Only SceneEventContract differs in runtime. Both variants pass two current cases / 213 assertions / three clean exits, for four current cases / 426 assertions / six exits. Saved slot bytes remain exact within each journey; generated identities need not match between variants.

| Complete observation | Baseline | Candidate | Reduction |
| --- | ---: | ---: | ---: |
| Fresh-process Load press to Ready | 57.302625 s | 47.670913 s | 16.81% |
| Retained-input Load press to Ready | 92.922745 s | 77.034223 s | 17.10% |
| Save press to return | 56.690037 s | 43.285473 s | 23.65% |
| Complete helper journey | 387.826435 s | 334.154667 s | 13.84% |

In the fresh_save_load scope, bundle validations fall from 92 to 50, while receipt and physical-proof calls remain 42 each. Scope-wide bundle time is 18.943974 → 10.048277 s; receipt-validation time is 31.021736 → 22.010275 s. These totals overlap; do not add their savings. Final restored captions are complete/readable and the baseline/candidate captures are byte-identical (SHA-256 `518dc6bccd41ef7ef77da8963cb6ba7216de4b48a2f8f81b892262dd25e4502a`). This is one baseline-first pair, not a latency distribution or guarantee for other histories/hardware.

All three candidate qualification jobs passed. The separate broader master run [40076834736](https://github.com/Siuuuers/dwm/actions/runs/40076834736) passed 29 jobs with one skipped job, including exported Windows startup, on the merged guard source `5c12b1f3`. It precedes the recall optimization and must not be presented as a full release suite on PR #71's final runtime. This batch did not run an uninterrupted authored week or upload to Steam.

## Next task and handoff boundary

This is a useful fresh-session boundary: both concrete repairs are qualified, and the next investigation concerns remaining work rather than re-proving either repair. No product-design answer is required. Load is improved, but the measured 47.67-second fresh Load is still far from smooth; do not call the performance problem solved.

Start with the retained candidate fresh-save-load.log from the matched comparison. Its remaining 50 bundle validations total 10.048277 s across the scope; receipt validations total 22.010275 s. These totals overlap and are not additive. Attribute work within SceneEventContract.validate_bundle_structure (JSON-domain checks, nested serialization, table/marker validation and fingerprint serialization) before selecting another change. Preserve fresh public-entry bundle admission and post-callback refusal boundaries. Exact same-call pure computations are the first candidate class; a global cache, caller trust flag or deleted validation is not authorized merely by these totals.

Other retained observations are restore preparation 9.574811 s, synchronous restore transaction 14.832855 s and enclosing backup commit 30.011611 s. These overlap other scope totals; do not add them. `scene_activation_pending` is the normal synchronous handoff, not native Load failure. The full final log is available if deeper attribution changes the priority.

Do not rerun the completed journal-cache or recall comparisons to rediscover their conclusions. Use a new matched complete-operation comparison only for a concrete next runtime candidate. At qualification time, historical draft PRs #14, #30 and #50 were untouched; their later administrative disposition is recorded below. Their diagnostic workflow overrides do not belong in master.

## Retained evidence

[Guard results](../evidence/phase_2r/intent_kind_20261024/results.json), [broader guard-master workflow status](../evidence/phase_2r/intent_kind_20261024/master-workflow.json), [first attribution](../evidence/phase_2r/receipt_attribution_20261024/first-results.json), [deep attribution](../evidence/phase_2r/receipt_attribution_20261024/deep-results.json), and [recall qualification/comparison](../evidence/phase_2r/recall_local_proof_20261024/results.json) retain exact source/artifact provenance. Their adjacent ZIPs retain current logs, reports, process records and selected native captures; attribution patches are retained separately. Every archive was size/SHA-256/CRC verified, and every retained member matches its original bytes. Manifests record all original members and retention/omission. Source and evidence reviews were independent; historical input reports are excluded from current passing counts.

The final publication adds only generated inventories, documentation and evidence to the qualified product runtime. Diagnostic and qualification workflow edits remain on their separate controller branches.

## Post-handoff Steam upload and old PR disposition

At the user's subsequent request, merged runtime `14648617b55a4c67bef7b7cc0d23461f0502f23c` was exported and uploaded to Steam AppID **5199120**, DepotID **5199121**, as **BuildID 26179529**. [Run 40078754096](https://github.com/Siuuuers/dwm/actions/runs/40078754096) passed both Windows export job120827683532 and Steam job120828660955. Controller `570a1a480a066f6d7c7cd4387b08d69fbbb37f9c` pins the runtime independently of the workflow event. It remains on its separate controller branch; do not push incidental changes there because each push triggers upload.

The unsigned x86_64 export passed isolated headless startup (240 iterations), 137 packaged runtime-data checks, and exact package file-list/hash validation before and after artifact transfer. SteamPipe preview produced a nonempty manifest; upload returned the BuildID above. **No Steam branch was set live.** This does not add graphical exported-gameplay, screen-reader, full-week or release acceptance. [Exact package receipt](../evidence/phase_2r/steam_recall_20261024/package-receipt.json) and [upload provenance](../evidence/phase_2r/steam_recall_20261024/results.json) retain the identities.

The existing Steam workflow on master still pins an older build. This upload used the separate exact-source controller; do not dispatch the old master workflow expecting this version.

Following comparison with master14648617, PRs [#14](https://github.com/Siuuuers/dwm/pull/14), [#30](https://github.com/Siuuuers/dwm/pull/30), and [#50](https://github.com/Siuuuers/dwm/pull/50) were closed as incorporated/superseded, with explanations prepended to their descriptions. Their branches and evidence remain preserved. #14's entire head is already a master ancestor; #30 has only one diagnostic workflow left; #50 has eight diagnostic workflow additions, two workflow overrides and a verifier tied to an old substrate. Its product15a44213 is already in master. Merging #50 would remove normal PR/master-push CI triggers and replace the current historical lane. Closing these PRs does not merge those overrides or broaden historical acceptance.
