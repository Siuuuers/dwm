# Snapshot semantic validation qualification — PR83

Runtime/tests `13b6853a6f66b92022a589489bf5f0187c18d1e3` and inventory successor `0ccaaed82bb0f896e998118ee8b5db5d2a25a7e3` have identical runtime, test and measurement-tool bytes. Baseline: `a7a9707dae17b648c09e70a139e1c37d4a7a4d37`.

Accepted current correctness coverage: **168 cases / 2,117 testcase assertions**, with no current-case failures or skips. Fourteen focused suites provide 165 cases / 1,759 assertions; genuine terminal validation adds 1 / 190; rendered recall Save/fresh-process Load adds 2 / 168. Matched comparisons separately add **8 executions / 852 assertions**. Instrumented baseline diagnosis separately adds 2 / 213. Historical fixture XML and assertions outside testcases are excluded.

| Operation | Baseline-first: baseline → candidate | Candidate-first: baseline → candidate |
| --- | --- | --- |
| Save press-return | 24.759 → 21.690 s (-12.39%) | 25.660 → 22.207 s (-13.46%) |
| Retained-slot Load Ready | 57.811 → 51.387 s (-11.11%) | 59.732 → 51.840 s (-13.21%) |
| Fresh-slot Load Ready | 33.513 → 30.852 s (-7.94%) | 33.919 → 30.670 s (-9.58%) |

All four semantic Ready payloads match exactly. Twelve comparison screenshots map to two byte-identical state images across variants and orders; both images were visually reviewed. Three recall images were also reviewed. Captions are complete with no observed clipping. See [visual review](visual-review.json).

These are two ordered Windows source-project/software-rendered comparisons, not a latency distribution, universal guarantee, or installed Steam performance claim. No Steam upload occurred.

## Evidence and source pins

- Baseline diagnostic: [40118441660](https://github.com/Siuuuers/dwm/actions/runs/40118441660), controller `bcee4693c6a2c5f801138fd2f68fd12a64fa1aca`.
- Behavior and matched comparisons: [40118557868](https://github.com/Siuuuers/dwm/actions/runs/40118557868), controller `de0113da3641aa24a0d6e0f4d76d5f2e94c6a9db`.
- Committed inventory: [40118687135](https://github.com/Siuuuers/dwm/actions/runs/40118687135), controller `710824b4afc22cb1d841a888b4b83f524b8c9378`.

The initial inventory lane failed because caller line references moved. Only those references were refreshed; APIs, dispositions and required contracts did not change. The subsequent read-only inventory run passed and both returned JSON files byte-match the committed files. The failed initial lane is preserved and excluded from accepted coverage; the overall initial workflow is not described as entirely green.

All 26 recorded candidate source hashes match Git, and the executable matches pinned Godot 4.6.3. Eight original artifact ZIPs were verified against metadata SHA256, byte sizes and ZIP CRCs. `manifest.json` maps every original artifact member to its exact bytes in `exact-evidence.zip`; original ZIP container bytes are not retained. `original-artifacts.json` preserves the original metadata. `current-case-census.json` identifies accepted XML cases. `review_evidence.py` reproduces mechanical checks from the original archives; `visual-review.json` records the subsequent visual review.

Controller patches are retained as evidence only and must not merge as executable game workflows. Export presets exclude this evidence directory. [Production review](production-review.md) explains the removed injected-mutation obligation and retained ordinary gameplay checks. [Diagnostic detail](diagnostic-summary.json) explains why root-copy optimization was not selected.
