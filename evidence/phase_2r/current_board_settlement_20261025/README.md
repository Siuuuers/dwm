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

Eleven independent Linux cloud/headless Godot 4.6.3 executions pass 194 cases and
1,943 testcase assertions. The three connected executions share one storage root
but have distinct OS process IDs: save unfinished board; fresh Load then finish
and save; fresh Load settled board then retry twice. Exact board/economy and source
bytes are checked. These are connected owner/storage checks, not desktop click
coverage. Existing rendered CI runs the same three-process journey.

Reports and source hashes are retained in `linux/`. Only final-shape passing runs are retained; earlier intermediate diagnostics are
excluded. Both canonical inventories and PowerShell
syntax checks pass. Independent production/caller review found no remaining
correctness issue after updating the Scene save fixture to the required format.
Windows qualification is pending. The existing rendered same-day Supportz
create/Load journey is also added to CI: it checks two real completions, retained
shop eligibility, historical retry refusal and a post-Load purchase. It requires
a display and is not counted among the headless results.
