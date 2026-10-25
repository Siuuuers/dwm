# Current board settlement — 25 October 2026

## Observable outcome

An ordinary completed Scene board saves `settled_inspection` atomically with its
reward and daily count. Loading that board preserves inspection and never pays
again. DesktopBoardState owns the fact; GameState commits it with the existing
round transaction. Current snapshots omit the retired `terminal_receipts` map entirely. Current
completion and departure no longer write historical terminal records; current
settlement queries use the fact.

Current Scene snapshots require the Boolean. Structural projection clones retain
the format without acquiring payment authority. Visibility and continuation
preserve the flag; replacement, dismissal, new board and day renewal clear it.
Legacy board snapshots and legacy completion history retain their existing contract.
No development-save migration is introduced.

This is one historical-consumer removal, not complete compact or ledger-free
restoration. Paid-start proofs, round retry receipts and reading history remain.
No performance measurement or speedup is claimed.

## Failures and qualification

Physical write refusal leaves reward and settlement unchanged. A committed but
unacknowledged checkpoint does not adopt live effects. Same-command and new-command
retries cannot reward a settled board twice. Missing/non-Boolean flags and a settled
nonterminal board are refused by the current owner.

Twelve independent Linux cloud/headless Godot 4.6.3 executions pass 200 cases and
2,161 testcase assertions. The three connected executions share one storage root
but have distinct OS process IDs: save unfinished board; fresh Load then finish
and save; fresh Load settled board then retry twice. Exact board/economy and source
bytes are checked. These are connected owner/storage checks, not desktop click
coverage. Existing rendered CI runs the same three-process journey.

Reports and source hashes are retained in `linux/`. Only final-shape passing runs are retained; earlier intermediate diagnostics are
excluded. Both canonical inventories and PowerShell
syntax checks pass. Independent production/caller review found no remaining
correctness issue after updating the Scene save fixture to the required format.
The full final Windows workflow passed. The existing rendered same-day Supportz
create/Load journey is also added to CI: it checks two real completions, retained
shop eligibility, historical retry refusal and a post-Load purchase. It requires
a display and is not counted among the headless results.

## First CI correction

Run 40155149867 on initial candidate
`708b711a3e7d6ad363adc225957fc6952e6f2347` exposed four failures in
`test_desktop_crash_recovery.gd`. The fixture calls legacy calendar
`start_new_run(route_id=main)` but allowed current bootstrap to create a strict
Scene board owner. Its legacy snapshot was correctly refused for missing the
current settlement field. The fixture now explicitly retains a real legacy board
owner before participant construction; no production check is relaxed and no
saved data is relabeled. An isolated baseline reproduced four failures; the fixed
six-case suite passes 218 testcase assertions. The full localization grouping also
passes 178 cases / 28,178 testcase assertions plus nine setup assertions.
This grouping overlaps retained tests and is
not added to the distinct diagnostic total. Both inventories were regenerated.
The current three-process settlement and rendered same-day Supportz journeys passed
on the initial runtime. The corrected candidate passed final whole-workflow qualification.

## Final Windows qualification

Candidate: `6b341e0cde34d57791a40c3fee5c66bc75ff85ce`.
Full passing workflow: https://github.com/Siuuuers/dwm/actions/runs/40156027730.

The retained subset passes 184 cases with 28,886 testcase assertions.
It includes the three-process board journey, round checkpoint transaction,
same-day Supportz create/Load, and the complete localization group.
The Supportz case assertion count depends on its generated board.
The three-process proof summary records distinct process IDs and saved settlement facts.
The complete assertions remain in the test sources and retained reports.

The restored board, eligible shop, and purchased shop screenshots were inspected.
Their controls and content are readable. Archive digests match GitHub metadata.
`windows/artifacts.json` identifies all four source archives. XML uses LF newlines.
The archived timing comparison was skipped because its old save shape is incompatible.
This is not a passing performance measurement.

## Known defect outside this change

A focused probe reproduced the next-day payment-history collision on master and this candidate.
See [the defect evidence](payment_collision/README.md).
The probe expects the incorrect refusal. Its 27 assertions are excluded from acceptance totals.
The next task replaces historical payment inference with explicit current payment status.
