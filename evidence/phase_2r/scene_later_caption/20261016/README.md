# Later-caption semantic cursor and Save/Load

## Observable outcome and ownership

Real ordinary Accept must advance the scene's semantic cursor to the authenticated native caption. Save and a separate-process Load must preserve that exact caption/publication/occurrence, fully visible at Ready, without repeating consequences. SoloReadingSession owns semantic progression; DialogicRuntimeAdapter authenticates the native activation; DialogicBridge connects successful ordinary publication to that owner.

The source change follows registered jumps to the first caption and refuses controls, completion, skipped captions, invalid indices, foreign/superseded publications and jump cycles. It does not serialize native event position or typewriter position. Existing strict saved-frontier validation remains unchanged. Initial activation, planned Next and Load retain their existing prepublished/duplicate handling. Existing live review-return is unchanged.

## Baseline

Source base 5e4da996bdb896fb0db96641232595d78dd08cd9; test-only candidate 211ed40d11001297ccf947697ca65c23711448bb; controller54a64769bd6bea7e670ace1e133a1e0f966bebe8; cloud run38841080072.

Actual Viewport Accept reached line.scene.test.a.two, publication caption:2, text A loop., while scene_index remained0. Capture correctly refused reading_frontier_invalid. This independently reproduces the semantic defect.

The run had THREE assertion failures, not one: expected partial reveal, ratio below1, and invalid checkpoint. Its first timing callback was overwritten by Dialogic's subsequent speed reset; the corrected test uses Text.text_started after that reset. No Save or Load ran in the baseline. All17 retained manifest entries were independently hash-verified.

## Save law

The creator starts with a genuinely partial later caption. Existing Save completes that caption under suspension before persistence. The test records pre-Save native state and post-Save-entry full state separately; it does not claim to persist a partial reveal. Fresh Load must retain exact saved semantic identity and show the full caption at Ready.

## Validation status

Final scoped acceptance passed; see the final receipt below. Earlier attempts are retained as diagnostics, not counted as final passes.

## First corrected-source attempt

Run38841810715 / controller8cab80caef3490853b13489a169d5be198b5ebdd / candidate1b06d557a7874b5a872508aef686bd05b37cb25f. Frozen cloud tree613e9e00b4bbd54891948ef5180600f4905b03da.

Four suites passed31 tests/584 assertions. Rendered creator proved line.two/publication2/index1, capture success, actual reveal in progress, and physical Save with exact reading-session equality. Three newly added post-Save observer assertions failed because active-layer/current-line discovery excludes the deliberately hidden paused source. The retained event was DONE and ledger unchanged. Loader did not run. Fixed observer inspects the same retained native caption node and paused-admitted authored event; assertions remain intact. Runtime did not change.

All48 manifest entries verified. Independent canonical inventory audit found only new lexical test sites and Bridge+5, adapter+43, Session+26 line shifts; symbols, signatures, classifications, required contracts and dynamic references were unchanged.

## Subsequent composition notes

B PR39 head4ea170dc86e72964a85bb84dd96fcd43c89e748c delivers offline build(order,source,bindings) returning registration and first_target_id; not yet installed or cloud-qualified. Compose a schema3 source before immutable manifest consumers select caches; existing configure_scene_title_new_run consumes the first target. Its branch-preservation unit DTL is intentionally not a linear Day1 journey.

C PR40 headd45d12f52abc56c43f331d8ca1e83621265408c1 delivers the bounded ending interface packet. Ordinary completion currently rejects ending targets; durable lifecycle/schema/receipt joins are required before reusing existing ending playback and Title return. This reading change does not claim that connection.

## Functional acceptance before evidence-harness cleanup

Run38842344183 / controller62232389eb3b20cc7b89b65cc65b0089de630ccb / candidate d9cb28c695fb02c623ea77833d2bb72b481cd372. Cloud source4615316cc014716f10950b855dd6200766d3150e, treeffd53ccaf6e5af5aa6c4972cb9c8d528b5fa4402. All33 tests/691 assertions passed, including both rendered processes; exact census, zero test-log errors, process exits and clean frozen tree passed.

Overall workflow remained red: evidence fallback packaging could not resolve base5e4da996 in its depth4 checkout. Artifact upload succeeded; downloaded artifact12021956173 SHA25677be912345755d33b58c7a986051fe19a662c3c85c7f95d53f697000962d6d95 matches GitHub's recorded digest. Visual inspection found the GUT overlay covering part of the loaded-caption screenshot. The next candidate changes only the screenshot helper to hide that overlay; the controller uses depth16 and verifies base availability before tests. Runtime stays unchanged. The follow-up is justified by evidence packaging and visual obstruction, not another runtime defect.


## Final scoped acceptance

- Qualified source: `7b1aec4d4e93aeb32089f7f4ee569f94ea94aa4a` (parent PR36 `5e4da996bdb896fb0db96641232595d78dd08cd9`).
- Exact tested/source tree: `5cdbf16aa6f3e17bdf111aa1f2044a6ae0f7b93f`.
- Cloud source identity: `f5e27e4ae988a2ea7180ff893ecd9937782c1d69`; same tree, reconstructed with actual generated UID/inventory bytes.
- Submitted candidate: `150bd58598ffa8ebefb4ed621a348e5ca12cccd8`.
- Controller: `412afd6996024df0ece72a257485c08f40db6cc9`.
- [Cloud run38842926843](https://github.com/Siuuuers/dwm/actions/runs/38842926843): SUCCESS, including exact census/source gate and evidence retention.
- Godot4.6.3 standard, Windows PowerShell; all engine/test execution cloud-only.

| Suite | Passed tests | Assertions |
| --- | ---: | ---: |
| Publication cursor | 10 | 86 |
| Native activation | 3 | 22 |
| Restore protocol | 5 | 140 |
| Native reading frontier | 13 | 336 |
| Rendered Save creator | 1 | 48 |
| Fresh-process Load | 1 | 59 |
| Total | 33 | 691 |

No skipped tests in this bounded census. All child exits0; no test-log errors; source stayed clean through acceptance. Actual rendered Accept reaches index1/publication2; Save preserves it, fresh Load shows it fully at Ready without another allocation or consequence, and subsequent Accept loops once to publication3. Duplicate callbacks do not republish. Original slot, autosave and Profile hashes are checked across Load. Board representation is unchanged; this reading journey creates no board.

All54 manifest entries in the final retained archive verify. Three screenshots were inspected: partial source retains prior history while the current caption is revealing; Load visibly shows A loop.; continuation shows one prior A loop. plus the fresh A loop. GUT overlay is absent.

## Durable evidence

Archives are siblings of this report:

| Archive | SHA256 |
| --- | --- |
| baseline-38841080072.zip | 5104ad805b4e0ac07d7d7014f47a36e866faa80138f0da83b19c5efbf85e8578 |
| attempt-38841810715.zip | 730c5d27cbbe2a786f4d5e667de465f85beac9986a4046432c66944c8f01199a |
| functional-38842344183.zip | 77be912345755d33b58c7a986051fe19a662c3c85c7f95d53f697000962d6d95 |
| accepted-38842926843.zip | ed42535472e34802fad47e92f9b044a1d5377c94d8bc2546502c6e72ddb20675 |

## Limits and next owner

This qualifies ordinary Accept, semantic cursor/refusal rules, native publication identity, Save and fresh-process Load. It does not certify whole-game performance, the Auto player journey, broad required CI, the editable sequence installation or the ending connection. PR36 remains draft and unmerged; master unchanged at0c8b2384415d71bd3de4ff7408640bbf60b63740. No save-format migration, board rewrite or first-reveal redo.

A next composes B PR39's explicit ordered authoring with normal Title/Day1 selection, then implements C PR40's authenticated ending lifecycle/save connection and qualifies the connected journey. Preserve PR37 partner-fork preparation. Claims and source receipts must be refreshed before shared edits.
