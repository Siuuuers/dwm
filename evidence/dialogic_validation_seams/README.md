# Current scene validation — 2026-09-13

Evidence for `dwm-oyo.2.1` and `dwm-oyo.2.2` under the owner's per-scene DTL design.

`resolve_entry` accepts an optional retired-ID registry. Existing three-argument
callers still read the shipped registry; explicit empty, unmatched, or non-rejecting
records remain unresolved with the unknown-entry diagnostic. A matching rejecting
record yields the retired-entry diagnostic. No save migration or registry law changed.

The read-only CLI retains real manifest loading and validation, then delegates its
scene loop to a callable static decision. Tests can now prove per-file validation,
failure status, continued checking after one failure, and scene-path restrictions
without constructing SceneTree or writing timelines. An unterminated final label
reports its own line rather than the number of lines in the file. Executable
hazards are rejected; comments remain inert.

Verification:

- `clean-red-20260913.log`: five expected failures before the scene decision seam
  and diagnostic fix (20 tests, 15 passed).
- `verified-20260913.log`: **186/186 tests, 8,071 assertions**, six relevant suites.
  This includes entry/ID contracts, scene structure, migration inventory, and the
  tests that protect retirement of the historical gate writers.
- `real-cli-20260913.log`: **64 scenes / 137 semantic entries**, exit 0.
- `mutants.json` and the named logs: **13 current-source mutants killed, none
  invalid**. Each isolated run selects its intended test and must fail by assertion,
  not parsing or setup. Production bytes were restored after every mutation, before
  the final normal tests and actual CLI run. `runs.jsonl` records commands and exits.

The broader entry/ID run initially exposed 12 stale fixture failures. Tests now pin
the current signature-schema field, the two named Observer-bearing entries, and
24 shipped atoms (including two Observer atoms). The schema's independent minimum
of 22 remains unchanged. Duplicate-ID fixtures reach the duplicate law instead of
failing an outdated count first. These repairs changed tests, not published schemas,
manifests, runtime validation policy, or story content.

The old external campaigns restore obsolete source and recreate deleted masters.
They were not run. These are fresh equivalents of C40/C04/C05 plus current diagnostic,
classifier and path checks; they do not recertify the historical campaigns. G11 and
eight-master/count/annotation obligations remain superseded. Historical sealed
artifacts remain unchanged. Godot 4.6.3 ran with isolated test data; logs retain the
existing 24 Dialogic orphans and CLI NUL diagnostics.
