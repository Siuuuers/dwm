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
