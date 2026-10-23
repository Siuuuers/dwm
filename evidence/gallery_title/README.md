# Gallery title integration evidence

Current branch starts at a28f29cf7. Registrar presentation is adapted from pinned
26de279; no branch merge or replay owner is included.

- Final combined suite: 65 tests, 5,212 assertions, seven suites, native exit 0.
- Existing title shell: 337 checks, exit 0.
- Native Gallery: 18 locale/size/Standard-palette tuples, 19 PNGs, exit 0.
- Independent review addressed shared Return navigation, pointer exit/scroll
  cancellation, awaited Settings cleanup and source focus after transition.

The rendering fixture explicitly supplies canonical discovery IDs through an
in-memory Profile projection. It does not prove player entitlement, public
record metadata or replay readiness. Rows honestly remain unavailable. Missing
Chinese title-ledger translations retain English fallback; full localization,
other accessibility palettes and OS assistive acceptance remain open.

`logs/` and `title_shell_initial_failure/` preserve the initial failed attempts.
`summary.json` binds tested source bytes and Git-filtered blobs, and records
protected worktree status. `measurements.json` contains bounds and native input
assertions; `renders/` contains the actual PNGs. Player data was not used.
