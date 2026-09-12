# Visited-line admission — 2026-09-13

Current evidence for `dwm-idz`. The existing profile bootstrap stage now validates
the shipped entry and ID documents and configures ProfileManager before initialization
can emit `profile_restored`. The allowed set contains 18 reply lines plus the two
Observer associated lines. Configuration stays immutable and idempotent.

`mark_line_visited` refuses uninitialized, unconfigured, and unregistered writes.
This also fixes an empty-profile indexing error after configuration but before
initialization. Loaded historical IDs remain readable; resets, profile schema,
dialogue content, and Skip transport are unchanged. Test fixtures explicitly
configure their own permitted IDs instead of relying on permissive admission.

Verification:

- `live-red-20260913.log` reproduces the production startup hole: a
  `profile_restored` observer could write an arbitrary ID.
- `unit-red-20260913.log`: seven expected failing cases, including the actual
  configured-before-initialization indexing error.
- `verified-20260913.log`: **153/153 tests, 4,483 assertions**, 12 suites covering
  registries, profile, bootstrap, resets, Settings, and the existing Skip/rehearsal
  seams. The final two-suite rerun covers the last test-only callback cleanup.
- The live FINAL harness proves refusal during `profile_restored`, successful
  persisted writes for a reply and both Observer lines, and an unregistered-ID
  refusal that leaves memory, revision, and disk unchanged. The existing project
  localization startup harness also passes.
- `mutants.json`: **three mutants killed, zero invalid**. Removing the writer
  admission call, startup binding, or Observer indexing each fails the actual
  FINAL harness. Exact source bytes were restored after each run.
- `timing-20260913.log`: three observations of the additional startup validation
  and configuration, **129.1–130.5 ms** on this machine. Configuration itself takes
  0.2–0.4 ms; validation is performed at startup, never per visited write or click.
  The small timing probe is included for reproduction; these are measurements,
  not a cross-machine performance guarantee.

Two adjacent test defects matched the earlier full-run baseline. The recovery
fixture omitted its retained mutation gate and now provides it while pinning
registry-before-profile ordering. The dialogue preference test now presses real
Continue when installed art creates a hold, waits for actual first-event and
natural-completion signals, and yields before teardown. It preserves exact label,
preference ordering, completion receipts, and no-profile-write assertions. Its
global event callback is disconnected on every exit. These are test repairs,
not changes to production playback or artwork.

Godot 4.6.3 runs use isolated data. Final logs retain the existing 24 Dialogic
orphans and NUL diagnostics. `runs.jsonl` includes the initial failures and the
intermediate teardown-error run rather than hiding them. Historical sealed
artifacts remain untouched. This closes the writer defect independently of
`dwm-3an`; production Skip and exact-variant History are still unfinished. The
existing ID validator's global line membership check is not proof of exact
Observer atom/owner binding.
