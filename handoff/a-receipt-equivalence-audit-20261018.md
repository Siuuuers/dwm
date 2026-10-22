# Receipt-authentication equivalence audit — 18 October 2026 UTC

Decision: retain all existing authentication calls. Direct deletion or passing a caller-supplied validated ledger is not justified by the current contracts. No runtime candidate was produced in this audit; no new cloud run or performance improvement is claimed.

## Scope and evidence

Director instruction: PR30 comment6252085070. Product source reviewed at4fefa967978c61a8726b7450265cecfacd318550; diagnostic source b1ec16613d3450f48e49a50ef739df517360c3d8. SceneEventContract and FrozenRunContext are byte-identical between product and diagnostic source; the Run/GameState diagnostic differences add opt-in timing without consolidating authority.

Retained run39142114567 established receipt authentication as an expensive boundary: outer authentication11.200384s and semantic authentication11.188358s across12 checkpoint records. Frozen-context time11.584263s includes another authentication plus its own checks. The inner operations below have not yet been timed separately. Percentages from the previous report are shares of measured historical validation, not whole-transition time.

An independent read-only agent reviewed the same call boundaries and reached the same decision. This is an internal source audit; it is not a claim that external Coordinator C has completed review of this audit or the latest cloud run.

## Input, authority and policy map

| Boundary | Input and registration | Authority | Independent obligation |
| --- | --- | --- | --- |
| RunSnapshotSchema.validate_scene | Normalized candidate receipts/contacts; caller bundle compared with installed registration | Run static issuer and configured creation owner | Reject structurally or authentically invalid Run before audio/reading and semantic-owner work |
| GameState.validate_scene_snapshot_semantics | Detached candidate and bundle copies; rechecks installed registration | GameState identity issuer and actual /root/SaveManager | Authenticate through live owners, verify Profile assignment and physical references, then join receipts to retained reading anchors |
| FrozenRunContext.validate_reading_checkpoint | Detached snapshot receipts/contacts; independently obtained installed registration | Frozen static issuer and configured creation owner | Validate reading envelope and admission identity, then derive the exact retained frames from authenticated admissions |

On the ordinary successful production path, receipt and contact values agree and Bootstrap aligns the authorities. This is not an unconditional API guarantee. Run and Frozen maintain separate static bindings, allow an initially null creation owner, and reject conflicting replacements. Existing fixtures deliberately exercise configurations without a creation owner. GameState obtains the live SaveManager by node path at the time of its call. Equality of input values does not prove equality or continued availability of those owners.

The policy is also more than pure dictionary validation. SceneEventContract._validate_committed_initial_admission checks the concrete SaveManager script and calls capture_committed_scene_creation. That method:

1. Requires configured issuer and Profile authority.
2. Finds the retained creation operation and requires scene_new_run, completed journal stage and acknowledged activation.
3. Checks the issuer root's exact allocation against the retained materials.
4. Obtains the Profile owner's assignment proof.
5. Parses the retained initial Autosave text and extracts its initial receipt.

The contract then validates the admission candidate, compares the receipt with that retained initial receipt, and checks the current issuer allocation again. Each invocation can report owner availability or proof failure; its result is not just a hash of the caller's receipt bytes.

## Refusal order that must remain observable

1. Run initial type/history checks, installed registration, structural owner validation and outer receipt authentication.
2. Run audio and reading checks.
3. Detached semantic callback: GameState registration and receipt authentication.
4. Profile assignment and physical-reference checks.
5. Frozen reading envelope, receipt authentication, admission/frame derivation.
6. GameState reading-anchor joins for authenticated event receipts.
7. Run checks that the detached snapshot and bundle were not mutated, before accepting the semantic result.

Deleting a later call can suppress its authority failure. Moving a later check earlier can change the reported first refusal when multiple conditions are invalid. Passing a success Boolean or ledger dictionary into an independently callable validator would create an authority bypass unless the receiving owner independently establishes exact scope and provenance.

A safe shared result is possible in principle, but would require an owner-created scope binding exact bytes, issuer/creation-owner identities and policy, plus proof that relevant owner state stays stable during use. The present API provides no such capability. Adding one across these three owners would be a larger architecture change than this evidence currently warrants.

## Terminal path is distinct

FrozenRunContext.validate routes a scene-origin ending through _validate_scene_terminal. That authenticates terminal admission and reconstructs a detached source snapshot before invoking validate_reading_checkpoint on the retained source. validate_reading_checkpoint can itself enter terminal validation first. These calls have distinct admission and source-reading obligations. Do not generalize the ordinary three-call count to ending or remove terminal checks as duplicates.

## Smallest next measurement

Keep all public validators and authority calls. Add opt-in diagnostic timings inside the existing canonical SceneEventContract.validate_scene_receipts owner, separating:

- Receipt JSON/bundle validation.
- Initial committed-admission proof work, including SaveManager capture; if that dominates, split journal lookup, issuer/Profile verification and retained-text parse at their existing owner boundaries.
- Other admission validation.
- Ordinary event reconstruction and issuer/child checks.
- Final occurrence, continuity, contact and cross-receipt passes.

Use disjoint counters at this level; nested capture counters must remain inside initial-admission time. Accumulate once per primary Load stream and retain counts to distinguish per-call cost from repeated invocation volume. No global cache, new manager or bypass parameter is needed for this measurement.

Source inspection also finds repeated pure bundle validation inside make_scene_receipt, inspect_scene, validate_scene_result and scene_completion_request. This is a candidate to measure, not a demonstrated dominant subcall or an approved optimization. Durable proof reads could instead dominate.

## Tests required before any eventual runtime candidate

Preserve standalone public validator behavior, including malformed receipts, changed registration, absent/different creation authority, unacknowledged creation, Profile/issuer proof refusal, forged history and detached-input nonmutation. Multi-fault cases must keep refusal precedence. Terminal source-reading obligations need separate coverage if a candidate touches them.

A candidate must then pass focused cloud Godot tests and a matched complete-operation comparison using the same driver and unchanged deadline. Retain failed attempts, clean-exit evidence and timing scope. Current Day7 timeout and older ending-control exposure remain open; no timing assertion alone qualifies the exported journey.

Product remains draft/unmerged. No runtime/test changes, cloud dispatch, master/integration change or release in this audit.
