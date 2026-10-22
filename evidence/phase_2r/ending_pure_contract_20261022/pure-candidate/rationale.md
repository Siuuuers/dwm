# Call-local bundle computation candidate

Base: observed product `32c4521c533685a411cb059916a3f86c48e20799`, with receipt/bundle timing wrappers retained unchanged.

The candidate changes only `SceneEventContract.gd`. Each public entrypoint (`inspect_scene`, `make_scene_receipt`, `validate_scene_result`, `scene_completion_request`) obtains a fresh private `_inspect_scene_context`. That function performs the original version/shape/full-bundle/registered-marker checks in their original order. Its successful context contains the original public inspection result and the existing detached computed bundle tables. The public `inspect_scene` returns only the original inspection dictionary, not the internal context.

The receipt builder uses those tables for its immediate anchor, result and completion projections. Extracted private result/completion helpers keep their original checks, projections and return dictionaries. There is no cache, saved trust flag, new manager, stored authority, or context reuse across public calls. No `await` or callback is introduced; these accepted primitive-input paths only read their inputs. Ledger traversal, live issuer/Profile/SaveManager calls, public receipt authentication and recovery checkpoints are unchanged.

For valid transition receipt construction, full bundle computation reduces from six calls to one. Direct completion/result calls reduce from two to one. These are source-derived counts, not a performance claim. The same observation wrappers remain available for a matched complete-Accept comparison.

First refusal order remains envelope version/shape, bundle/marker binding, then entrypoint-specific checks. In receipt construction, malformed anchor still precedes result validation; result validation still precedes completion-child comparison. The omitted work previously repeated the same pure inspection/bundle computations on unchanged inputs. Public entrypoints never accept caller-supplied computed tables.

No public result keys are added. Original semantic/programme-entry copies remain detached. The receipt's anchor and result copies remain detached. Helpers only read the context and do not export it. A caller invoking an underscore helper directly can request pure projections but cannot gain issuer, save or durable admission authority; public callers continue to use the four validating entrypoints.

Required qualification: independent diff/caller review; existing contract and receipt suites plus targeted malformed-input precedence/fresh-public-validation tests; existing rendered ending/durable/readback gates; paired complete-operation timings with identical observation settings. Cloud-only Godot/PowerShell remains mandatory. Static transformation checks are not a runtime pass.
