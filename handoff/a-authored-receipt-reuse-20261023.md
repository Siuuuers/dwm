# Authored transition receipt reuse — 23 October 2026

Continue cloud-only Godot and PowerShell. Read AGENTS.md and CLAUDE.md. User requests minimal verification, smooth ordinary play, and a usable handoff. No design question currently blocks work. No merge, master/PR51 alteration, or Steam upload.

## Ownership and source

- Product: `codex/authored-week-followup-20261023`.
- Runtime/test candidate: `b996ea473a7058a4ed65f1a787dc66f7d778f979`, tree `8d6e288b1327634d09d9cc8bb248e15bae679575`.
- PR50 is the diagnostic controller. PR30 is historical. Do not merge controller workflows into product.
- Master checked at `d2062f8d9807f7f06935f86065640ff14a5400d6`; it does not contain SceneEventContract. PR50 base remains `328edfe082c84bd9f6ca0a9d45e6603e0902695c` (PR51 integration). Neither changed here.

## Measured problem and smallest change

Baseline [39895040994](https://github.com/Siuuuers/dwm/actions/runs/39895040994), source e6b3adf/tree9f007fab, passed 1 rendered test / 371 assertions and clean process exit. Outer artifact SHA256 matched GitHub, both ZIP CRCs passed, and all 54 retained member hashes matched. Native 992x558 screenshot inspected: artwork and caption visible. Original ZIPs and inspection are retained under `evidence/phase_2r/authored_followup_20261023/run39895040994_profile`.

Thirty ordinary transitions took 292–353 ms (median 319 ms); the first photograph branch took 52,765 ms. Its 16 snapshot validations occupied 45.236 s; 173 bundle validations occupied 32.385 s inclusive. Receipt/bundle/snapshot timing scopes overlap: never add their totals. Separate memory projections took 26.980 and 34.755 ms, outside the transition measurement. This evidence does not support caption-memory surgery as the first fix.

SceneEventContract now shares detached, checked structural registration tables only inside one synchronous receipt-validation call for event reconstruction and v2 admission reconstruction. Public entries still validate fresh inputs. Identity, issuer, child provenance, and receipt comparison checks remain. The v3 initial committed-admission proof, terminal and challenge-recall paths remain unchanged. No global cache, saved-data schema change, new manager, or caller-controlled trusted flag.

Two focused receipt tests cover warm-call registration/issuer changes, bundle-first refusal, output alias mutation, and subsequent receipt tampering. Existing contract and receipt cases remain in the cloud lane. Native authored_week_profile.gd.uid was adopted from verified baseline cloud import.

## Comparison

[39896652757](https://github.com/Siuuuers/dwm/actions/runs/39896652757) succeeded on the pinned candidate, controller `5b8bcf0095dfeb38daf4694f49efe2b666307f89`: 40 unit cases / 439 assertions plus 1 rendered case / 371 assertions = 41 tests / 810 assertions; two clean process exits. Outer artifact matched GitHub digest, both ZIP CRCs passed, and all 59 retained members rehashed. Native screenshot inspected with artwork and expected caption visible. Original archives and inspection are retained under `evidence/phase_2r/authored_followup_20261023/run39896652757_receipts`.

The identical first photograph transition took **25,363 ms**, versus baseline **52,765 ms**. Bundle validations fell **173 → 117**; receipt and physical proof calls remained **55 each**, and snapshot validations remained **16**. Ordinary caption median was 208 ms versus 319 ms. Unchanged ordinary-caption timings also differed between hosted runs, so the entire 51.9% elapsed reduction must not be attributed solely to code. The call-count reduction is deterministic evidence of eliminated work. Transition is still far too slow for smooth play.

All public validation/forgery/mutation tests passed. Independent reviews covered runtime caller boundaries, test bodies, identical comparison operation, and both evidence archives. No repeated artwork suite or full-week run was launched.

## Remaining scope

Prior artwork proof remains accepted within its scope; do not repeat it. Prior full authored journey [39888749357](https://github.com/Siuuuers/dwm/actions/runs/39888749357) remains a failure: creator timeout 1800 s, 290 captions checked, fresh Load/replay never ran. Its genuine final autosave may support a bounded late-history probe. Do not fabricate ledger data or blindly increase deadlines.

Next, trace the remaining 117 bundle validations and 16 snapshot validations at the same marker boundary. Their inclusive times are 12.906 s and 21.030 s respectively; receipt validation is 13.451 s inclusive. Keep public saved-data/issuer boundaries, and seek call-local repeated work before caching or deleting checks. The v3 initial creation proof still crosses the existing SaveManager owner and was deliberately not changed. Then complete the remaining default authored journey (Day4 Save, fresh Load, ending, fresh ending replay), followed by final-source export. An early-history profile is not late-history, full-week, Save/Load, export, or release acceptance. Earlier export predates the artwork fix.

The original authored-profile.yml automatic PR trigger was retired at `426f14633271778446054b7fff6dac84870aeeb6`. The comparison trigger was retired to workflow_dispatch at `5a22ae2ac7292501cc2295499b0b52f224885751` after collection. Both diagnostics are manual; cumulative PR path filters must remain disabled before unrelated controller updates.
