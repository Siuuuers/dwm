# Stable public API inventory handoff

Date: 2026-11-03
Repository: Siuuuers/dwm
Verified baseline: `246e3d2aea1f4dddeee3ddde4f3c1acad9f7a028` (merged PR #182).
Status: planning only; no implementation or engine verification is included in this handoff.

## Observable outcome

Deleting or adding comments and blank lines must not change the committed API
inventory when public declarations and actual caller-file dependencies stay
unchanged. Current file:line locations must remain available for diagnosis.

PublicSurfaceInventory owns scanning, classification and inventory construction.
The existing generator and validation entry points own generation and comparison.
Reuse those owners; do not add a parallel inventory system.

## Evidence and motivation

PR #182 removed three unused private helpers, clarified three local names and
removed explanatory comments in three source files. Its follow-up refreshed the
two public inventories. PR metadata records 363 new/relocated caller references,
with signatures, required contracts and dispositions unchanged. Do not assume
every reference delta was caused solely by shifted line numbers.

The current scanner in `tools/runtime/PublicSurfaceInventory.gd` constructs
`"%s:%d" % [display, line_index + 1]` and stores it in static or dynamic references.
`check_canonical_json` compares the whole canonical output byte for byte.
The scanner searches raw source lines; comments mentioning a symbol can therefore
be mistaken for references. The existing test explicitly expects a caller path
followed by a colon.

## Approved design

- Commit public symbols, kinds, signatures, dispositions, replacements, contract
  tests and required-symbol rules as before.
- Represent caller dependencies with sorted, unique repository-relative file
  paths, separately for static and dynamic references.
- Keep exact file:line occurrences in current diagnostic logs or an uncommitted
  CI artifact. Diagnostic locations must not affect canonical equality.
- Collect locations once where practical and derive the stable representation.
  Reuse an existing output channel instead of introducing a new reporting framework.
- Ignore comments without discarding executable strings used by dynamic calls or
  scene connections. Handle quoted hashes, escaped quotes and multiline strings
  correctly; do not use a naive split at the first hash.
- Preserve the existing scene-resource scan and required search roots. A caller
  in both static and dynamic categories remains represented in both.
- Preserve strict comparison of the stable canonical output. Do not make the
  checker accept arbitrary differences to suppress stale-output failures.

This deliberately tracks caller-file membership, not call counts or each
occurrence within a file. Adding a second occurrence in the same file need not
change the stable inventory. Removal of the last occurrence must remove the
dependency. This remains a textual dependency aid, not a complete call graph or
proof of safe deletion.

## Implementation scope

Inspect current master and open work before editing. Use a new branch from the
current merged baseline. Read repository instructions and relevant owner records.

Initial files to inspect and change only where needed:

- `tools/runtime/PublicSurfaceInventory.gd`
- `tools/runtime/generate_public_surface_inventory.gd`
- `tests/unit/tooling/test_public_surface_inventory.gd`
- `tools/testing/Invoke-PublicSurfaceValidation.ps1`
- `evidence/phase_2r/runtime/game_state_surface.json`
- `evidence/phase_2r/runtime/save_manager_surface.json`

Search all consumers of `call_sites`, `dynamic_references`, inventory serialization
and location parsing. Update affected fixtures and consumers in the same slice.
Keep existing field names if they remain understandable and avoid needless schema
churn. Preserve production-versus-test caller classification and dynamic-reference
retirement refusals.

Regenerate both committed inventories through the actual generator on the final
candidate in cloud CI. Review the changes before accepting them. Do not manually
edit line numbers or manufacture generated output.

## Focused acceptance

1. Inserting/removing blank lines or full-line/inline comments leaves stable
   inventory bytes unchanged, including comments containing a public symbol.
2. Executable quoted method names, quoted hashes, escaped quotes, multiline
   strings and scene references remain detected according to the supported scanner
   behavior. Comment handling must not remove real references.
3. Adding a caller file changes membership; removing its last occurrence removes
   membership. Duplicate occurrences do not duplicate file paths.
4. Static and dynamic categories remain distinct and deterministically sorted.
5. A public signature change is detected by canonical comparison or the existing
   required-signature rule where applicable. Missing required symbols and
   unclassified declarations still fail.
6. A removal disposition with production callers or unresolved dynamic references
   still fails; test-only classification remains correct.
7. Diagnostic output reports current, accurate file:line locations.
8. Two generations on the same candidate are byte-identical; read-only check mode
   does not rewrite files. Both regenerated inventories pass check mode.

Use the existing focused tooling tests, syntax/import checks, source lint and
inventory generation/check entry points. Run Godot in cloud CI under repository
policy. No new injection campaign, gameplay/rendered matrix, Windows export,
performance benchmark or TLA+ model run is needed for this tooling-only change
unless implementation unexpectedly touches the behavior those checks protect.
Report automatically selected CI separately; do not silently weaken existing gates.

## Exclusions and coordination

No game-flow changes, save changes, additional runtime deletions or renames,
repository-wide comment sweep, general coverage-selector redesign, permanent
call-site IDs, or new dependencies. Do not combine this with the next runtime
cleanup batch. TLA+ progression models remain unchanged.

One implementation session owns this tooling slice. This conversation remains
for planning and coordination. Finish this change before the next deletion/rename
batch so that subsequent cleanup uses the stable inventory contract.

## Starter prompt

Implement this handoff on current master after checking existing PRs and repository
instructions. Make the smallest complete change that keeps source locations useful
in diagnostics but excludes them from the committed API contract. Cover comment
handling and stable caller-file membership with focused tests, regenerate both
inventories with the real cloud generator, review the generated diff and open an
implementation PR. Report exact checks, skipped checks and limitations. Do not
treat this handoff PR as completed implementation.
