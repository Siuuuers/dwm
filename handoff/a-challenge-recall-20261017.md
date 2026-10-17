# Coordinator A: five-result End dispatch and later recall

Integration note for B/C; test fixture contract, not production prose or an authoring guide.

## Qualification status

**Bounded cloud qualification complete.** Final run161 passed **13 cases / 480 assertions / 7 clean process exits**, including native create/load **2 / 128** and inventory validation **11 / 352**. All Godot/PowerShell execution used cloud Windows and Godot4.6.3 standard.

- Latest candidate source: `7f0e5ca0703257b0b1b4689ad5b3e7f082b3add4`
- Final tested source tree: `bb3c89f3c73a4f180e70acae250f2ae5e93153a8`.
- Final run: [39052548944](https://github.com/Siuuuers/dwm/actions/runs/39052548944), job `117453896358`; controller `dd2dcfd9fc8fa5a905e9313ccacf3e1dc9e1353f`, workflow blob `cb6e69246a87563e0321a038454531aa2830a613`.
- Run158 (`39051925174`, job `117452085701`): 6 physical five-outcome cases / 88 assertions and 22 legacy cases / 251 assertions passed. Its grouped process exited1 because the separate new recall fixture still declared 3 entries instead of12; the original overall failure remains a failure. These are verified passing subsets, not a clean-process claim for that run.
- Run159 (`39052131064`, job `117452683771`): corrected pure-recall process exited0; creator failed. Evidence packaging then failed on absolute Windows paths. Original job log retained; no testcase acceptance is derived from that incomplete artifact.
- Run160 (`39052328437`, job `117453250171`): 5 recall unit cases / 70 assertions, clean unit exit0. Creator reproduced a caption timeout at `.start.one`: first Accept admits Playable while holding the caption, whereas the new test incorrectly expected `.start.two`. Source test now performs the separate physical departure, as the previously accepted optional-challenge journey does. Product runtime unchanged by both fixture corrections.

Original archives are in `evidence/phase_2r/challenge_recall_20261017/`; all three original ZIPs and their manifest members independently rehashed; run159 retains its original job log because its packaging failed. Exact source-derived XML census, retained source bytes, final inventory payloads and process mappings verified in `verification.json`. No local Godot or PowerShell execution.

Bounded verified coverage: synthetic receipt selection for all five outcomes; real physical-owner End dispatch for all five outcomes; native never-started journey with a fresh-process Load and later recall. Synthetic checks do not authenticate persistence, and this scope does not qualify all five outcomes through native fresh Load, production story content, or broad CI.

The 35 distinct behavior cases contain 537 assertions across the explicitly scoped subsets above; inventory adds 11 / 352. This is not a claim that the earlier overall failed runs passed. No already passing physical/legacy suite was repeated. The final product update carries the exact two inventory payloads generated and checked in run161. Runtime bytes are identical across all these runs; follow-ups corrected only test metadata/input sequence and evidence packaging.

Three retained 992×558 English pixel-font captures show the full source caption and recalled target before/after fresh Load. No wider layout or exported-gameplay claim. Keep draft/unmerged; integration/master unchanged. External B owns the reusable template/one practical guide, and C owns its finite coverage/example review. This note supplies their concrete binding dependency without duplicating their guide.

## Exact bindings

The fixture presentation order is a–e below. JSON object key order does not select outcomes. A new five-result challenge supplies exactly these five keys; every target must be registered.

| Pointer | Display meaning | `challenges[].targets` key | Fixture End target | Fixture recall target |
| --- | --- | --- | --- | --- |
| a | NotStarted | `never_started` | `echo_a_day1` | `recall_a_day1` |
| b | Unfinished | `unfinished` | `echo_b_day1` | `recall_b_day1` |
| c | Win, non-Perfect | `won` | `echo_c_day1` | `recall_c_day1` |
| d | Lose | `lost` | `echo_d_day1` | `recall_d_day1` |
| e | Perfect | `perfect` | `echo_e_day1` | `recall_e_day1` |

The opportunity Start uses `challenge.playable`, and End uses `challenge.end`; both carry payload `{"challenge_id":"TEST.recall.challenge"}`. Start makes the opportunity available; the public Computer panel's first Reveal starts its attempt. Viewing the panel does not start it, and pre-Reveal flag actions are currently refused. The challenge row binds the playable and End marker IDs, board profile, and the outcome-to-target map. Perfect is a closure projection of a won board with canonical Perfect reasons; physical record state remains `won`.

Both markers use the same registration shape as the recall example below: explicit `marker_id`, DTL `label`, `after_line_id`, `kind`, and `payload`. The authored caption before Start/End owns the boundary. Computer opening holds caption/Auto; closing alone does not advance or resolve. Existing seven-day, partner and ending templates remain in place; this fixture is not a replacement story skeleton.

Later recall is an explicitly registered marker. This example matches `tests/support/SceneChallengeRecallFixture.gd` and `tests/fixtures/dialogic/scene_challenge_recall.dtl`:

```json
{
  "marker_id": "scene.test.recall.later.recall",
  "label": "scene.test.recall.later.recall",
  "after_line_id": "line.scene.test.recall.later.one",
  "kind": "challenge.recall",
  "payload": {
    "challenge_id": "TEST.recall.challenge",
    "never_started_target_id": "recall_a_day1",
    "unfinished_target_id": "recall_b_day1",
    "won_target_id": "recall_c_day1",
    "lost_target_id": "recall_d_day1",
    "perfect_target_id": "recall_e_day1"
  }
}
```

The entry must allow `challenge.recall`; the IDs registry declares payload fields in this exact array order: `challenge_id`, `never_started_target_id`, `unfinished_target_id`, `won_target_id`, `lost_target_id`, `perfect_target_id`. Programme hashes come from the compiled fixture. Each recall target must be a registered `scene` target; for example `recall_a_day1` points to entry/label `scene.test.recall_a_day1`, with that entry's content version and programme hash.

Targets may converge when several outcomes use the same passage. Neither a–e nor `_day1` has runtime meaning: there is no inferred label naming, current-day lookup, or requirement to write five distinct passages.

## Ownership and saved-result rules

- Existing owners remain authoritative: `DatingPhysicalOwner` classifies End, `GameState` checkpoints/adopts scene receipts, and `SceneEventContract`/`DialogicEntryManifest` validate bindings. No new manager or reward path.
- Recall reads a uniquely prior `challenge_closed` receipt for the represented challenge ID in the same saved Run. Its issuer counter must precede the recall command. Missing or ambiguous closures fail; neither means NotStarted. Give represented challenges distinct IDs when they are distinct story facts.
- Recall returns `challenge_recalled` with `closure_command_id`, `outcome`, and `target_id`. It does not close the board again, consult newer Profile progress, or reapply effects/rewards. Selected Load recalls only retained Run evidence.
- Legacy exact four-target bundles remain accepted unchanged. Their Perfect boards retain historical `won` dispatch. This does not migrate fingerprints or rewrite existing receipts; replacing registration bytes is not automatic save compatibility.
- Recall requires the authenticated pending marker and uses existing target admission/retry handling. Recall is not admitted as a contact-child exit.

Relevant qualification files: `tests/unit/test_scene_challenge_recall.gd`, `tests/unit/test_scene_five_outcomes.gd`, and `tests/integration/scene_challenge_recall_child.gd` with its create/load wrappers.
