# Current Challenge recall from saved facts — 25 October 2026

## Outcome and scope

GameState passes `scene_challenge_outcomes` to current Challenge recall. Recall
selects the same authored target for each of the five outcomes, without reading
closure receipts or newer Profile attempts. It does not close a board or repeat
rewards. Missing is distinct from `never_started`; two matching occurrences stay
ambiguous even when their outcomes agree.

Recalled results contain exactly `{kind, outcome, target_id}`. No production
consumer needs `closure_command_id`, so the field is removed. Current-build-only
saves intentionally reject the previous result shape without migration.

Historical validation remains temporarily: an earlier recall must ignore a
closure issued later or at the same counter. Its private chronological join runs
only after the enclosing validator reconstructs and authenticates every command.
The obsolete generic/selected wrappers, repeated closure reconstruction, and
selection flag are removed. Public ledger admission retains shape, anchor,
registration, issuer and result-consistency checks.

This removes one runtime history consumer and a saved field. It is not complete
ledger-free Load: event admission, reading anchors, and board settlement retain
historical dependencies. No performance measurement or speedup is claimed.

## Diagnostic qualification

Four independent Linux cloud/headless Godot 4.6.3 processes pass 34 cases / 500
testcase assertions, plus three fixture setup assertions. The regular CI grouping
of five-outcome and recall tests also passes 13 cases / 170 assertions; this is
repeat coverage, not another 13 distinct cases. Reports and source hashes are in
`linux/`. PowerShell runner syntax and scoped whitespace checks pass.

Two-closure chronology is tested as a pure private join on constructed valid
receipts; it is not a complete issuer-backed two-closure journey. Connected
rendered create/fresh-process Load checks current recall, no reward/Profile
reapplication, and public ledger refusal of forged outcome/target, missing
closure, malformed anchor/version and changed registration. Rendered Windows
qualification for these suites passes. The connected fixture covers `never_started`;
all five branch mappings have unit coverage.

## Windows evidence

Candidate `cfd54e5d47cb515d27cf94c64e739e8b87176906` runs in
https://github.com/Siuuuers/dwm/actions/runs/40154201762. The retained Windows
subset passes 15 cases / 352 assertions: five-outcome plus recall units and the
connected create/fresh-process Load pair. All three retained screenshots were
visually inspected: caption and controls are readable, and the restored selected
caption matches the pre-Load selected caption. Archive SHA-256 digests match
GitHub metadata in `windows/artifacts.json`; XML newlines are normalized to LF.

The full workflow passed. The archived matched startup/Load lane is
intentionally skipped for incompatible old save shape and is not a measured result.
