# Cold Load and same-day Supportz continuation — 23 October 2026

## Approved product decisions

The user explicitly selected daily renewal at each registered authored story-day boundary and automatic abandonment of unfinished ordinary boards without refund. Renew two base rounds, daily earning allowance, finished-today count and daily Supportz eligibility; preserve branch-wide Supportz limits and claimed task rewards. Minesweeper remains optional. These answers supersede the pending choices in a-scene-apps-resume-20261023.md.

## Source reconciliation

The supplied handoff pinned PR42 e8ab9c99473a207e3a455a3fb1af1ceb05d182fb. Live PR47 had already advanced to a226f61115e739972df3ec7e7eca47a03b5bac13, incorporating composed Apps/Save/Shop fixes and scene-native ordinary completion/day renewal. Duplicate local experiments were stopped and not published. Master e8d48d6b only added Steam delivery workflow/documentation after 41592fcc; it did not resolve these gameplay paths.

PR49 is an isolated diagnostic follow-up targeting PR47. Source 60ffc7b5624bf414f8919d084b598dbd65cc4524, tree d8cf2b4dfb7c488ae3b11d91c7f4a546765b96ee, adds source-correct fixtures, complete cold-load timing and a same-day settled-board Load/retry/Supportz journey. Controller 0cf3a26a8c6538fdaaf2d4f75612b7d328f6118f pins that source. Do not merge diagnostic workflows into production.

## Prior failed evidence

Run39860579535/job120109935257 failed. Its original inner ZIP is 15,529,880 bytes, SHA256 fb204396d6f5690bcc51a27852b84fbda0eb15ae8b7a65c832df5cb554103b7e; artifact12460664828 transport SHA256 7ad3f845d5d2dae724554ecea45d72faa4211d5b137a3c8d25c9159d9a841728. All670 retained file hashes were independently verified. Preserve the original artifact at https://github.com/Siuuuers/dwm/actions/runs/39860579535/artifacts/12460664828.

JUnit, not green continue-on-error step labels, showed a round receipt fixture failure and a rendered registration-shape failure. Both inserted new Dictionary keys with dot syntax (StringName) where the JSON contracts require String. Corrected only those fixture keys; production strict validation is unchanged. Existing unit/physical passing scope remains bounded. Native generated registration and nine genuine editor-generated UID sidecars were retained from that artifact; no UIDs were invented.

## Current qualification

Run39868248878 failed (source60ffc7b5624bf414f8919d084b598dbd65cc4524). Artifact12464529022 contains original ZIP SHA256 665ca8275e5f238049a03ff6ffc53badbe628689ecc90a214ffe190e9c6499a2, 2,247,820 bytes. All695 retained hashes and ZIP CRC verified. Challenge25/282, Apps creator1/86 and same-day owners4/101 passed. Shop38/2858 had eight bounds assertions failing in one test. Apps loader1/16 failed rollback and malformed fatal diagnostics. Same-day creator1/248 reached two real clears and eligible Supportz, but manual Save rejected a live StringName outcome; no loader ran. Failed Load timings are diagnostic only, not performance acceptance.

Source7a476ab92dd4f0831adf1ac6ef80fc3918ffe739 (tree dc5e609e7b7efce68b4ec31f1aa7bb3d59833cac) fixes the manual Save producer boundary using existing JSON normalization, measures unwrapped Shop metadata height while retaining Japanese text/font/gap, and preserves original restore refusals if rollback also fails. It adds regression coverage and classifies nine existing GameState APIs. Native public inventory generation remains pending. Controller5d4cbdcf3ed71fccf05d3baa42fb0e83d16d3b91 pins that exact source. Run39869220394 failed. Artifact12465518075 contains original ZIP SHA256 ff1fc97d3e5c31d3f05439f0dd986eb6f35c51095367b85f578cd343d3296069, 2,506,736 bytes; all714 retained hashes and ZIP CRC verified. Restore diagnostics21/192, Shop38/2874, Apps creator1/86, same-day owners4/101 and Supportz creator1/312 passed. Both fresh loaders failed: continuation journal pre-write invokes the unadmitted Challenge owner's flush, refusing with scene_challenge_readmission_required; cold run compensation then rejects its empty run_id. The improved diagnostics preserved both causes. No Load or performance acceptance yet. Complete outer cold-load timing spans Backup prepare through readiness; owner profiles enable only in the fresh loader. The scene path does not emit the legacy standalone restore_commit scope: inspect backup_commit.restore_commit_us instead. Correct that diagnostic expectation without removing gameplay checks.


## Confirmed restore fixes under qualification

Source7d2db1fb05a5b298f9fc14b47cdf3a5b6f890e7e (tree d27d996a4cfe021220a8c25813b1b036c6a9bfaf), controller5c77ba3121d852979d386dfb6b91013fa66f5bee:

- DatingPhysicalOwner allows an unchanged unadmitted scene record to do no work during the active restore lease. It still refuses pending routine/checkpoint work, fatal custody, and out-of-restore readmission. Three new regressions compare owner history, Run and Profile bytes and preserve later retry.
- GameState compensates the exact process-local constructor lifecycle through RunLifecycle, separate from strict saved-run validation. Three new regressions cover legacy and scene installation, exact empty restoration, retries, identity-owner preservation, malformed and stale backups.
- Focused run39870246181 executes the new rollback suite, full Challenge suite, ordinary round owners and Apps/Supportz rendered creator/fresh-loader pairs. Passing Shop and diagnostic-projector suites were not repeated.
- Native inventory preparation run39870246257 regenerates/checks the two outputs and existing tooling contracts. No release acceptance until its original evidence is reviewed and generated outputs adopted.


## Successful Load baseline and same-day remap finding

Run39870246181 (source7d2db1fb) passed Apps create1/86 and fresh-load1/39, recovery/Challenge31/391, same-day owners4/101 and Supportz creator1/352. Original ZIP2,584,869 bytes SHA256 0d8ce19661f0ca5cda8e2cb7cc03ff4bc97aba7f92d590993629f96e6c8a7e40, artifact12465687926; all719 retained hashes and CRC verified. Successful cold Load measured6,539,283 microseconds (prepare1,736,784, commit4,197,160, readiness605,339) in one Windows CI sample, not an improvement comparison. The asynchronous commit returns scene_activation_pending with ok=false; final readiness and loader proof establish success, so the profiling gate follows this actual protocol.

Supportz loader failed four assertions: terminal receipt keys were deliberately remapped, while its oracle wrongly expected old keys; current-day eligibility tokens incorrectly remained old after causal-day identity allocation, hiding Supportz. Source103f7ad2e8c7acaf110abcd37232741de15fe811 (tree36c7200f9fd69d61bdd8eee1825ce1b881243708) rebases only scene current-day eligibility rows/last-purchase token. Older days, branch counts and immutable command receipts remain unchanged. Tests cover repeated Load and preserving a consumed daily purchase; the rendered oracle checks every terminal key against the committed issuer allocation and retains exact values.

Native inventories were generated/checked in run39870246257 (artifact12465848157):11/352 plus clean native generate/check/import processes. Original ZIP489190 bytes SHA256176d2b4026d12ad9552b8b981b93e1eb0bd98967f8901d93d70d13e0c3c984e0,36 hashes verified. Exact outputs adopted in103f7ad, along with genuine cloud cold-rollback UID and reproducible finite provenance refresh. See a-current-owner-provenance-20261023.md.

Controllerfe3d7614777f364010cb97c9ac94c075e181de7f starts focused run39871056223, historical-control run39871056351, and canonical Windows run39871056249. All require evidence review before acceptance. Master rechecked atd2062f8d9807f7f06935f86065640ff14a5400d6: only Steam workflow/docs advanced, not gameplay; preserve them during integration.


## Accepted bounded evidence and integration candidate

Focused run39871056223 on source103f7ad passed all13 cases/749 assertions: same-day owners4/101, remap5/92, Apps creator1/86 and fresh-loader1/39, Supportz creator1/362 and fresh-loader1/69. Its original archive is2,709,390 bytes, SHA256 f28b8e0f0b8b3cef0c89df81f48334db30fb362b284a4ec8009c4eae8adc374f, artifact12467135657; all724 retained hashes and CRC verified. The real two-round creator, fresh loader, remapped terminal receipt replay and Supportz purchase now pass. Cold Load's complete observed duration is7,457,889 microseconds (prepare1,922,384, commit4,761,283, readiness774,222). This is one Windows sample, not a matched optimization result; no performance surgery is accepted.

Historical-control run39871056351 on the same source passed8 original tests/1408 assertions with both six-direction markers exactly once and zero skips/errors/failures. Its original archive is236,638 bytes, SHA25653b6620a321f015baba7c70b8adb236cc83f2057eb3b05df4d9c64906aaec42e; all24 retained hashes and CRC verified. The full finite owner inverse and every historical control remain authenticated. See [current-owner provenance](a-current-owner-provenance-20261023.md) and the [evidence index](../evidence/phase_2r/cold_load_supportz_20261023/README.md).

Integration source5 is4b554dbbf39c6532b7f38f5c20ae482c8b77752a. Its only non-controller change after103f7ad is the ordinary-day rendered fixture, blobc237bf94d9e1c666d6b878e1b462700b4c55cf57. The fixture follows the actual UI flow rather than changing product policy; its corrected story-day qualification passed as recorded below. Product source remains the qualified103f7ad composition.

The isolated integration branch is based on PR42 e8ab9c99, adopts source5 non-controller content, excludes six added diagnostic workflows, and preserves baseline PR42 workflows plus exact masterd2062f8d Steam workflow/documentation. Fresh native inventory outputs, evidence and these handoffs are deliberate integration-only additions. The existing Invoke-CloudTests.ps1 also adds nine qualified regression paths across persistence, minesweeper, shop and desktop suites so their automatic coverage survives removal of diagnostic workflows; existing cases are retained, all paths exist, and no suite has duplicate paths. This tools-only caller list is outside the four public-inventory scan roots. The earlier dirty integration checkout is not used.

**Pending acceptance:** full canonical Windows suite and exact integration Windows export. Earlier failed or partial results remain evidence, not acceptance. No merge, release, Steam upload or exact integration Windows artifact is certified by these bounded runs. Finish independent audit and pending checks before expanding validation or integration publication.


## Accepted authored day policy

Run39872404497 on source4b554dbbf39c6532b7f38f5c20ae482c8b77752a passed37 tests/971 assertions: day owners33/509, physical ordering2/71, ordinary creator1/347 and fresh loader1/44. All four processes exited0, with exact source-derived census and clean logs. The journey proves daily renewal and automatic abandonment of the unfinished ordinary board without refund, then fresh-process restoration. Eight screenshots were retained and inspected, including renewed2/2 board, ineligible Supportz tile after fresh Load, and purchased Shop state. Source corrects the fixture's UI sequence only; no production rule was weakened.

Artifact12467102430 retains original archive2076087 bytes SHA25693a03a4bcfee961b4598f502ab70ccef76c546a07342b378877803f0462f4a49. All699 member hashes and CRC were verified; transport/API and original job-announced digests matched. [Retained evidence](../evidence/phase_2r/cold_load_supportz_20261023/run39872404497/verification.json).


## Accepted final native inventories

Run39872404513/job120149743076 on source4b554dbbf39c6532b7f38f5c20ae482c8b77752a passed11 tests/352 assertions and six clean import/generate/check/test exits. Both native outputs were adopted exactly into the integration tree; their four scan roots match the qualified source. Artifact12466723226 original archive492595 bytes, SHA256edcdf9afec2f3a9f2e9e6018d9f663ff424a34662be2f94d2eb1215c0bb632b9; all36 manifest member hashes and CRC verified. [Retained gate](../evidence/phase_2r/cold_load_supportz_20261023/run39872404513/inventory-preparation-gate.json).

The preceding source103 inventory run39871784869 is retained as superseded evidence, and failed day-fixture run39871784992 remains retained separately. The current accepted day/inventory pair is39872404497/39872404513. Remaining acceptance is the full canonical Windows run and exact integration export; no additional gameplay design question blocks this integration candidate.
