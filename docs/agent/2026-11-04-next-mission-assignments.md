# Next mission assignments

Audit baseline: `8d43ed812269ad9d9b21a5f722c71c39f0c5feb8`.
Three delegated read-only audits are complete. The implementation sessions below are queued, not running.
Recheck current master and open PR ownership before starting. This record is a handoff, not a mandatory startup checklist.

| Mission | Session owner | Deliverable | Dependencies |
| --- | --- | --- | --- |
| Reconcile completed handoffs | Coordination/docs; audio owner reviews #187 | Accurate open-task status and preserved authoring guidance | Merged successors listed below |
| Verify dialogue-history retirement candidate | Runtime cleanup | Reachability and requirement evidence; conditional small cleanup PR | Resolve active transcript/history ownership before deletion |
| Audit public-surfaces checkout | CI checkout | Dependency manifest and measured baseline; conditional optimization PR | Establish complete inputs and worthwhile checkout cost |

## Coordination/docs session

Reconcile each original checklist item as completed with evidence or carry it into one clearly owned remaining task.

- [#183](https://github.com/Siuuuers/dwm/pull/183): inventory stability implemented by merged [#184](https://github.com/Siuuuers/dwm/pull/184). Mark superseded and close with the implementation link.
- [#185](https://github.com/Siuuuers/dwm/pull/185): reconcile against merged [#186](https://github.com/Siuuuers/dwm/pull/186), [#188](https://github.com/Siuuuers/dwm/pull/188), [#189](https://github.com/Siuuuers/dwm/pull/189), and [#190](https://github.com/Siuuuers/dwm/pull/190), then close completed scope and retain any outstanding item explicitly.
- [#187](https://github.com/Siuuuers/dwm/pull/187): native integration landed in [#208](https://github.com/Siuuuers/dwm/pull/208). Preserve useful authoring guidance; replace obsolete prototype/backend plans with remaining content work. Do not merge its old future-tense plan unchanged.

Limit changes to current handoff status, successor links, and documentation. Preserve historical evidence.
Production soundtrack replacement remains separate. Dummy-audio/export probes do not establish physical audibility, latency, or a complete normal player journey.
Acceptance: open descriptions reflect remaining work, useful guidance survives, and every original item has evidence or one owner.

## Runtime cleanup session

Candidate: `DatingScene.append_previous_dialogue_line`, `previous_dialogue_list`, and exclusively dependent `PreviousDialogueScroll/PreviousDialogueList` nodes.

The method creates a Label for a dialogue line. Indexed search found only its definition, but that is not sufficient deletion proof.
The recovered flow document still describes a current-and-previous-two dialogue stack and full log.

Before deleting:

1. Check direct and dynamic calls, reflective names, inheritance, serialized resources, scene instantiation, and relevant tests at implementation HEAD.
2. Identify the active caption/history owners and show how they satisfy the transcript/log requirement, or establish explicit retirement of this cohort.
3. Check layout and focus effects of removing even empty containers.
4. Record the original purpose and retirement proof in the established retired-functions document before deletion.

Keep DatingRoot, DialogueBox controls, narrative bridge/skip wiring, audio, saves, and previously completed cohorts outside scope.
If reachability or requirement ownership remains unclear, retain the code and report the blocker. Do not rename merely to produce a diff.
Acceptance: affected scene import/parse and existing dating/narrative/history checks pass; dating entry, dialogue/log behavior, and challenge presentation remain intact.
Use names that explain responsibility if a justified rename is needed. Make no performance claim from deletion alone.

Sources:
- [DatingScene script](https://github.com/Siuuuers/dwm/blob/8d43ed812269ad9d9b21a5f722c71c39f0c5feb8/scripts/ui/DatingScene.gd)
- [DatingScene resource](https://github.com/Siuuuers/dwm/blob/8d43ed812269ad9d9b21a5f722c71c39f0c5feb8/scenes/dating/DatingScene.tscn)
- [Recovered flow requirements](https://github.com/Siuuuers/dwm/blob/8d43ed812269ad9d9b21a5f722c71c39f0c5feb8/docs/design/recovered/FLOWS.md)

## CI checkout session

The `public-surfaces` job still uses unrestricted checkout. Audit that job alone before proposing sparse checkout.
Trace its complete dependency closure: fixture/schema census, isolated-runner diagnostics, inventory verification and failure-only regeneration, native-caption acceptance, public-surface tests, artifact collection, and historical Git needs.

Deliver a keep/exclude manifest with dependency evidence and one representative current full-checkout baseline.
Report checkout, import, and test durations separately, with run SHA and URL.
Do not copy another job's sparse pattern without proving this job's inputs.

Implement a narrow sparse-checkout change only if omitted files are unnecessary and checkout remains a material cost.
Acceptance for a candidate: retained-file byte equality, complete census/source/runtime inputs, preserved failure diagnostics and artifacts, relevant workflow regression checks, and isolated hosted acceptance.
Uncontrolled hosted timings are observations, not causal speedups.
If dependencies cannot be established or cost is immaterial, report no edit recommended.

Do not change inventory semantics, selector routing, suite batching, audio loading, or source-line diagnostics.
Line numbers used for diagnostics are distinct from unstable committed API identity.

Sources:
- [Pinned workflow](https://github.com/Siuuuers/dwm/blob/8d43ed812269ad9d9b21a5f722c71c39f0c5feb8/.github/workflows/windows-tests.yml)
- [Prior sparse checkout work #209](https://github.com/Siuuuers/dwm/pull/209), evidence for a different job only
- [Run 41722005072](https://github.com/Siuuuers/dwm/actions/runs/41722005072), public-surfaces skipped; not a baseline

## Reporting and boundaries

Each session reports its final commit, changed scope, focused commands and exit results, evidence links, and unresolved limits.
CI and runtime sessions may proceed independently; coordinate shared documentation edits with the docs owner.
No additional lint rule or TLA+ change is justified by these audits alone. If a behavior change becomes necessary, stop the cleanup scope and propose it separately with the relevant model implications.
This documentation-only handoff does not rerun or independently certify historical implementation test results.
