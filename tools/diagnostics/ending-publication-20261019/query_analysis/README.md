# Query observation analysis

Run `python -m unittest discover -s tools/diagnostics/ending-publication-20261019/query_analysis -p test_query.py` for the synthetic contract and provenance tests. Run `python tools/diagnostics/ending-publication-20261019/query_analysis/bind_query.py --evidence EVIDENCE_DIRECTORY` once against a retained evidence directory. It creates `query-binding.json` exclusively, preserving any original result.

The binder first runs the consumer provenance checks with the old correction switch disabled. This candidate requires the distinct `dwm_query_probe_v1` engine name, the query SDK qualification receipt, current retained analysis/harness source bytes, and the expanded native source manifest. It preserves original capability/create/load results and never marks official acceptance.

Separate `query-trace/*.jsonl` streams require process-global unique requests, per-stream emission order, bounded counts/labels/bytes, stable composite generation/root identity, and original PID/HWND. Concurrent completion order need not follow request order. Only captures wholly inside the logged ending wait and after the current caption registration snapshot are associated with that caption. Native IDs remain `(TreeId, local RID)`; no UIA RuntimeId is fabricated. Native request IDs and harness query ordinals are not cross-process join keys.

The harness reader validates collection size versus evaluated/retained/omitted counts, exact short-circuit nulls, and accepted counts. Truncated names never justify an exact-name rejection claim. A visibility result does not identify its internal failed term. Harness event timestamps and existing query durations remain interval evidence, not a new deadline-admission rule.

A valid empty or incomplete query prefix, missing stream/footer, explicit drops, omitted predicates, or truncated labels is a coverage limitation, never proof of caption absence or clipping. Positive selected identities mean only that the observed provider callback returned that identity. Pre-arm and pre-resolution calls, recursive filter internals and client delivery remain uncaptured. Missing files or zero selected observations do not turn the original journey failure into a pass.

The synthetic tests exercise ordering, generation/process/source corruption, caps, short circuits, missing coverage and preservation of failed native outcomes. They are not native Godot/Rust/PowerShell execution.
