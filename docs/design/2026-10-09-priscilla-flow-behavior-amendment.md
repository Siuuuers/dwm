# Priscilla chapter flow: intended-behavior amendment

**Date:** 2026-10-09  
**Status:** approved directional changes plus explicitly marked recommendations and open implementation decisions.  
**Scope:** documentation only; no code, schema, test, workflow or PR #1 change is authorized or certified by this file.

## Authority

Read the [approved narrative amendment](../../story/09-priscilla-foundation-amendment.md) with the affected [September behavior record](2026-09-02-relationship-progression-runtime-behavior-record.md) and [August Dialogic flow](2026-08-07-seven-day-dialogic-flow-design.md). This is a scoped later amendment of those intended-behavior owners, not an assertion that the runtime implements it. Unaffected behavior remains with the existing owners.

The older universal Angela-absent explosion cutoff (September Section 2.2.1) and mandatory frozen four-form requirement (Section 2.3) do not govern the new chapter flow. Their historic tests and records keep their original scope; they are not evidence that this pivot passes tests.

## 1. Separate selection responsibilities

Start narrative play directly in Day 1 DTL. Dating/schedule allocation, Angela attendance, old solo/pair activation and Angela-specific ending invitations must not gate the new story. Ordinary device functions are not deleted merely because their former narrative obligations retire.

Select the larger Sweet/Dark ending form at genuinely new-run creation. Do not select a partner there. The old mandatory `ambiguous_sweet`, `ambiguous_dark`, `love_sweet`, `love_dark` combination contract is superseded. Replacement identifiers, draw/witnessing policy and any necessary old-save disposition remain OPEN; this is not permission to build a compatibility framework without a demonstrated need.

A single later optional self-talk choice selects the sustained storyline: Yes leads to Priscilla-Sylvia; ignoring leads to Priscilla-Lavinia. The other woman can still appear. A normal thought choice is neither a Challenge nor a Perfect. Local outcomes do not reroll the ending form or replace the selected storyline through competing affection totals.

Ambiguous/Love is not a separate compulsory axis. Any retained numerical relationship state has only its explicitly approved purpose; it does not manufacture desire, consent, truth, observer knowledge or an ending circumstance.

## 2. Optional thought presentation

Show one proposed thought/action and one Yes control. The default alternative need not be displayed. Passing the authored opportunity follows the default and removes the control; no mandatory No or confirmation menu is selected.

RECOMMENDATION: tie expiry to script progress rather than elapsed reading time. Make the important fork's immediate action intelligible, without presenting an affection leaderboard or promising a selected chapter/line. Auto, keyboard ordering, replay and stale-input handling require bounded review against the actual presentation owners.

## 3. Challenge opportunity

The DTL start label makes the optional Challenge available; the end label closes its opportunity. The story has a valid continuation when the player does not start it.

Opening the panel pauses DTL. Closing resumes DTL and preserves an unfinished board so it can be resumed within the same opportunity. Closing alone does not commit the unfinished outcome. Resolve the result at the end label and select its subsequent authored continuation.

| State at resolution | Story consequence |
|---|---|
| Never started | Priscilla follows her ordinary choice in the actual circumstances. |
| Started, unfinished | She chooses not to take the relevant action. The fictional action need not have begun. |
| Lost | Scene-specific Dark conduct/consequence; not an automatic visibility cutoff. |
| Won, not Perfect | Scene-specific Sweet continuation. |
| Perfect | Successful continuation plus first recognition or further awareness development. |

Where the runtime uses `Perfect`, `Solved` and `Exploded`, preserve their distinct terminal identities until a separately approved reconciliation changes them. This amendment does not redefine scoring. Perfect and ordinary success may share appropriate action text without sharing awareness consequences.

Preserve particular facts later passages consume, not a global personality/tone meter or an exhaustive version of the remaining week for every result. Compatible local branches can converge; irreversible consequences cannot be erased to obtain convergence. Withdrawal cannot retroactively undo an already completed act.

## 4. Awareness and the ending boundary

Only the first Perfect enables recognition. Once aware, Priscilla can recognize subsequent completed interventions, including ordinary wins and losses. An unfinished attempt supplies no new recognized effect and does not erase existing awareness. Further Perfects may deepen her understanding. Exact counts, opportunity identities and awareness passages remain OPEN; earlier illustrative thresholds are not constants to implement.

Knowledge, attitude and capability are separate. The women do not receive each other's private knowledge automatically. No mandatory observer romance or independent awareness meter for every woman is selected.

All Perfect is not an unconditional Deicide or Quit trigger. It cannot switch the relationship, automatically cancel Sweet closure, or require an observer epilogue. Any special response requires its authored predicate and established fictional means. A possible observer passage follows a complete human ending and must not undo it.

For a selected forced-exit event, record the required state/results before exiting. No real fault, reload punishment, cross-save awakening or save/load-horror subsystem is required. Existing ordinary persistence responsibilities remain in force.

## 5. Recommended implementation invariants

These are engineering recommendations for later review, not selected APIs or a claim of passing tests:

- One logical resolution owner per opportunity; dependent facts are applied once, not again on panel closure, resumption or redisplay.
- A completed result survives panel closure. Reopening the same attempt is not a new attempt. Confirm the already intended one-attempt policy against the active runtime before implementation.
- Distinguish panel inspection from actually starting play. First meaningful board input is the recommended boundary, not a newly approved rule.
- Thought-choice expiry follows the authored opportunity. Replay/history displays cannot activate live choices. Review Auto and keyboard/input ordering explicitly.
- Both relationship storylines remain reachable with zero Challenges. The fork does not require a hidden affection quota or a Perfect.
- Loading preserves the selected ending form and the route/state of that save. Returning to a pre-fork save can allow the other branch; presentation alone does not award a fresh Perfect.
- Count distinct resolved opportunities for awareness. For any future all-Perfect predicate, define the required set explicitly: shared plus selected-route opportunities, not inaccessible alternate-route boards or merely the boards the player happened to finish.
- No premature finale because all boards encountered so far are Perfect. A special ending still has an authored ending condition.
- Reuse existing DTL, state, persistence and panel owners. This file selects no service, class, variable schema, save migration or automatic repair architecture.

## 6. Acceptance cases for future implementation

These are acceptance specifications, NOT executed game tests.

| Case | Expected boundary |
|---|---|
| New run | Starts the chapter narrative without a dating/schedule prerequisite; ending form and partner selection remain distinct. |
| Ignore important thought | Default P-L continuation; route is not selected by a hidden score. |
| Select its Yes | P-S continuation, including in a zero-Challenge run. |
| Ordinary optional thought | No automatic Challenge start, Perfect, or observer recognition. |
| Ignore Challenge | DTL reaches its authored ordinary continuation; no required Play/Skip interruption. |
| Open/close unfinished | Pause/resume and suspension, not immediate withdrawal. |
| Resume before end | Continues the same unresolved opportunity; no duplicate consequence. |
| Opportunity ends unresolved | Chooses not to do the relevant action; does not erase already performed acts. |
| Lose | Authored later Dark continuation, not the retired global explosion cutoff. |
| Ordinary win before any Perfect | Sweet local continuation without identifying the observer. |
| First Perfect | Recognition becomes available at the opportunity's authored resolution, not before its cause. |
| Later ordinary completed result | Can be recognized without pretending it was another Perfect. |
| Later unfinished | No newly recognized interference; previous knowledge remains. |
| Local tone differs from ending form | Preserve concrete consequences; do not reroll the whole form or erase the scene. |
| Reopen, replay, load | No duplicate result, route commitment, awareness credit or unintended live input. |
| All Perfect | May still end with Lavinia/Sylvia and no observer confrontation. |
| Selected forced exit | Required results recorded first; the exit is not a new crash-recovery or save/load-horror system. |

## 7. Open decisions and inspection limits

OPEN: precise attempt-start boundary; terminal/scoring and attempt-identity reconciliation; route/opportunity IDs and authored labels; replacement ending-form selection/witnessing policy; awareness thresholds; Auto/replay/input handling; device ownership and Contacts migration; exact epilogue conditions; and any justified save-format changes.

The dialogue/plot fork, childhood rewrite, full week and concrete endings remain with the narrative owners. Documentation publication does not settle them.

Baseline inspection is against `master` at `d35b8f878128663b4e27675fc6fdb11c234143eb`, not a whole-code audit of PR #1. Runtime, Godot, cloud behavior, accessibility, performance, exhaustive reachability and independent narrative review are NOT RUN by this amendment. Existing evidence remains historical evidence of its recorded source and scope.
