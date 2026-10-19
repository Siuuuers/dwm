# Actual query diagnostic — implementation qualification

External C6262529467 review consumed. Concrete isolated implementation began at8ddb722e50a18d6abbfa6c016c0af9bff38d0f4f, over9b6653436e5989e9bf096360f7e7045c20f4578b. Frozen game/PCK and original30s/480s gates remain unchanged. New diagnostic identity is dwm_query_probe_v1. Product runtime has not been changed by this evidence packet.

## Retained preflight failures

Run39221220266 failed the final synthetic provider-exception test before SDK/engine execution. Its15 consumer and17 query Python tests passed; PowerShell parsing passed. The test required the C# getter marker to propagate as its message, but did not retain the actual exception pair.

Test-only source df86fb610f383d8de5fd546005d0cc48b3ae3f68 retained those exact inputs. Run39221542193 again failed the same assertion, preserving12 preceding successful synthetic cases and both original error/read sequences. Both observer-off and observer-on cases have identical RuntimeException, exact FQID InvokeMethodOnNull,Microsoft.PowerShell.Commands.WhereObjectCommand, message "You cannot call a method on a null-valued expression.", eight provider reads through name, cleared observation scope and zero completed enumeration events. PowerShell exposes the failed getter as null before TrimEnd; the expected C# marker was wrong. This is a test expectation defect, not evidence of changed runtime behavior.

Corrected test-only source36f7424d1d7cbe7b037ff4dafd6e4f147561bd2e asserts exact observed type/FQID/message and provider sequence plus on/off equivalence and existing cleanup. It retains the diagnostic receipt on failure. No runtime observer was changed to make this test pass. Controller e3dcd57b1e604a01d6fb4ef37e05c0f7d2d081d8 starts run39221835797. Results remain pending at this checkpoint; do not count test source as executed proof.

Original failed attempt archives are retained with preflight-attempts.json. SHA256, safe/unique paths, CRC and all128/129 respective manifest entries independently verified. attempt2-test-diagnostics.json is the decoded original receipt. Neither preflight ran SDK/engine/game, and neither is a native acceptance result. Original failures and diagnostic-only limits remain explicit.

## Third preflight and qualified SDK

Run39221835797 passed both readers, action equivalence, unchanged deadlines and the seven consumer tests. Query tests compiled: seven passed; the remaining test had already matched the independent baseline predicate sequence and selected identity before failing a hardcoded count (actual4, expected2). Source39108bee5ee31199cfb0ae8949e21ab1610fb5ac changes only this test expectation and its source hash. It now checks count against the independent baseline. Runtime observation is unchanged. Original third-attempt archive is retained, with every manifest file verified.

Run39222305066/controller6c7d7baf53c48a8883d5eede5a3ebe050c284374 passed focused checks and the patched SDK build. Native compilation/journey is pending; this is diagnostic qualification, not gameplay acceptance. Do not launch a duplicate run.

Independent SDK review of run39222305066 artifact12172023303: ZIP2,548,839 bytes/41 entries, SHA2564eab47f65ddd12f0fba7f41ceef9478c9fc7c376a8064d86d27c2d0d6ad57690, CRC clean. Seven consumer and eight query tests passed; SDK build exit0. Verified library11,602,094 bytes/SHA256e13e64dd7811505b904e9f1a8969935a045362cf4cfb851fb31311b8b7ee5650, header, lock/metadata and every probe source against the reviewed candidate. Commit39108bee is test-only. No SDK blocker. Engine compilation remains active; inspect original Load failure/exit/cleanup and query coverage before drawing any gameplay conclusion.

## Completed native query result — replacement A

Run [39222305066](https://github.com/Siuuuers/dwm/actions/runs/39222305066), job117960238191, completed **failure**. The source39108bee/controller6c7d7baf pins above remain exact. SDK and engine compilation, packaging, Capability and Create completed successfully. Original Load failed `UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending.`, player exit-1, driver exit1, forced cleanup. The collection step's normalized success is not a Load pass. Final acceptance correctly failed. No duplicate dispatch or runtime edit was made during this reconciliation.

Retained original Actions artifacts:
- `native-evidence.zip`: artifact12174571177, 2,731,820 bytes, SHA25658cb672232da472155de0322ffa024d42f0fd2ee30b6c64e51e2a79b45de32a9.
- `native-sdk.zip`: artifact12172023303, 2,548,839 bytes, SHA2564eab47f65ddd12f0fba7f41ceef9478c9fc7c376a8064d86d27c2d0d6ad57690.

The evidence ZIP has349 entries, including retained-hashes.json. All349 manifest payloads are available and hash/size matching:348 in the evidence ZIP and the static SDK library in the SDK ZIP. Both archive CRC checks pass. Original reports are unchanged. The native EXE/PCK are bound by retained receipts; this reconciliation does not independently rehash the separately published executable package. Diagnostic Load explicitly declares diagnostic_only:true; Capability/Create ordinary-release wording must still be interpreted with their diagnostic-native process/package receipts.

The original binder reports binding_ok:true, official_acceptance_established:false. Seventeen interval-selected committed snapshots seq1436–1452 contain the caption and connected parent chain. Query evidence contains149 observed Navigate calls (94 return a selected node), none selecting/evaluating the caption. Two complete harness enumerations each contain23 descendants: four visible/enabled Pause controls with nonmatching names, nineteen rejected by Visible before later properties were queried. Neither batch accepts an action. Their intervals are29.4033701–29.511932 and29.7378699–29.8011086 seconds; the original wait ends30.0399827 seconds. Native PID4152/HWND0x90058/adapter1/epoch1 are recorded. The absent footer limits conclusions to observed prefixes; ordinals and local RIDs are not shared request/UIA identities.

Independent review narrows the next boundary: terminal NextSibling requests71/145 evaluate DialogicLayout_WitnessedCaption then unnamed/art branches but do not evaluate the caption-layer path. This does not establish why. Before another native campaign, inspect the existing iterator source and define a bounded same-query observation of ordered child links, reciprocal parents and actual traversal skip/termination at this boundary. Reuse existing artifacts for source analysis. Do not repeat identical committed-state/root-order campaigns, extend deadlines, or promote the isolated engine/order experiments. No product correction is justified yet.

See independent-review.md for source semantics and observation limits. All Godot/PowerShell/Rust execution remains cloud-only; this continuation uses Python retained-evidence analysis. Official exported ending/durable Gallery/Title/normal Load-exit remains open. B's separately qualified12/177 fixture result stays closed. Master0c8b2384 and integration3ae6d913 remain unchanged; PR36 stays draft/unmerged.
