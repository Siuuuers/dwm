# Bounded Title-stall proposal — no new execution authorized here

Observable next outcome: distinguish time spent completing the game-owned ending transition from time spent acquiring an already-ready Title through native accessibility. Existing EndingScene/GameState/checkpoint owners retain their authority. Success evidence would be one correlated phase timeline within the unchanged original 30-second control wait, with PID/HWND and retained failure snapshots.

## Existing evidence

Corrected records the finish-ending invocation at 2026-10-19T11:49:57.7921554Z, then New Acc times out in window acquisition after 30.1034485 seconds. The harness logs invoke before calling Invoke(); it does not timestamp its return. The failure-window probe reports PID536/HWND458978 hung and unresponsive; a fresh UIA client stalls at from-handle. C's later Title screenshot at 11:50:55 cannot establish in-deadline readiness.

`title_analysis.py` reproducibly extracts the final six stdout checkpoint records (lines122–127): prepare/commit pairs 8.120995/8.138641, 9.606288/9.849113, 10.612373/10.612030 seconds for checkpoints18/19/20. Their outer elapsed durations total56.939440 seconds. Nested profile submetrics are not added. These records lack UTC stamps: the numerical proximity to the later screenshot is a hypothesis, not proof of interval overlap or causality.

The failure-time autosave is checkpoint18, lifecycle ENDING, playback_stage EPILOGUE_PLAYED. The retained Profile ending.alone consequence is distinct from a durable COMPLETED run snapshot. Later stdout says checkpoints19/20 succeeded, but no later completed autosave capture or clean Load exit establishes completed-journey acceptance.

## Source ownership and inference

Inspected frozen game81847d8b1560340a3a7769223cee0b46c6bdc0f9 (hashes in title-source-hashes.json): EndingScene.on_ending_playback_completed synchronously completes a stage then resume_ending drains record_gallery/complete_run. GameState._commit_ending_playback_completion synchronously calls its existing checkpoint writer before returning the route. ApplicationBootstrap._commit_ending_checkpoint calls prepare then commit serially; SaveManagerCheckpointPort times these as separate scopes. EndingScene requests Title only after the tail returns menu.

This makes synchronous checkpoint work a concrete leading hypothesis. The retained window failure alone cannot distinguish that hypothesis from accessibility acquisition after menu readiness. It does not justify deleting checkpoints, validation, copies, recovery guards, or history authentication.

## Smallest proposed discriminator

If Director authorizes a later diagnostic, add bounded, opt-in phase records at the existing ending-completion entry/return, each ending checkpoint prepare/commit entry/return, goto_menu entry, and the first idle frame after the menu is mounted. Record monotonic time plus UTC anchor, PID, stage and checkpoint identity, and success/failure. Add only an invoke-return timestamp to the existing harness event sequence; reuse its existing PID/HWND/window wait observations. Do not add broad tree enumeration or new provider reads.

If the original deadline expires before game transition completion, target that measured phase. If menu-ready/idle is recorded before the deadline while the same window acquisition still fails, investigate accessibility/window publication. Missing records, write failures or identity mismatch stay inconclusive. Instrumentation overhead must be qualified; preserve original 30s/480s limits and original failure outcome. Before implementation, check existing markers to avoid duplicate ownership. No performance surgery is selected yet.

Stop at this proposal for C/Director review. No runtime/controller change, native campaign, timeout widening, custom-engine promotion, merge or release belongs to this assignment.
