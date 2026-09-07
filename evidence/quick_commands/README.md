# Quick command evidence

Final isolated suites pass 101 tests and 1,534 assertions. Native rendering passes
448 checks across 36 locale/size/status combinations, retaining 10 captures.
summary.json binds all nine authored source files to SHA-256 and Git blob hashes.
invocations.jsonl retains both failed attempts and passing final invocations.
Raw log hashes precede whitespace-only normalization for repository storage.

Initial failures included unsupported Control API calls, test variable shadowing,
incorrect Quick filename and locale fixtures, and a missing resume-frame fence.
The final runs contain no SCRIPT ERROR. Existing Unicode NUL diagnostics and
24 Dialogic fixture orphans per GUT run remain visible; this is not a leak audit.

Render fixtures use nine synthetic occupied records and exercise layout only.
Actual command tests use the real SaveManager, presentation port, shared desktop
confirmation and all eight production restore participants with isolated storage.
Screen-reader behavior and other desktop/narrative Quick contexts remain unverified.
See ../../docs/design/current-ui/desktop-quick-commands.md for remaining acceptance.
