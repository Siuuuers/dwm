# Native Windows caption Normal Accept — 4 October 2026

Source `761e2e42a2266e51eb396e3ae0916598fba20eff`; actual PR merge
`e21892b49107cd13c6be77f1afe87bb568135118`.
[Run 145](https://github.com/Siuuuers/dwm/actions/runs/37173880983):
26/26 jobs; 2,601 primary cases, zero failures/errors/skips.

The native Windows probe exposed a text-only accessibility leaf with no Invoke
pattern. Named actionable caption roots now retain the rich-text children and
delegate to existing Normal Accept. Two actual UIA invokes prove reveal-only,
then one advancement with the successor still revealing. Three PNGs were inspected.

Read `receipt.json` for scope and diagnostics. `test-evidence.tar.gz` retains
13 primary XML reports, the full reading log, raw native trees/invocations/runtime
states/PNGs, and the Run143 inventory and Run144 native discovery diagnostics.
`archive-manifest.json` hashes every member; `primary-artifacts.json` binds all
downloaded primary ZIPs to the same source/run.

This is synthetic mounted-fixture OS invocation proof. Full screen-reader
navigation, native review-current return-to-live and production routes remain
separate. No save, History, recovery, consequence or completion owner changed.
All 23 unfinished Beads keep statuses/dependencies; no live Dolt synchronization.
The records-only descendant is not independently engine-tested.
