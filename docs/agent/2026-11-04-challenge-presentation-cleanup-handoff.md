# Challenge presentation cleanup handoff

Date: 2026-11-04
Repository: Siuuuers/dwm
Status: queued audit and implementation mission; no runtime changes made here.
Prerequisite: implement and merge the stable API inventory mission described in
PR #183 before publishing runtime deletions or renames. Merging its documentation
alone does not satisfy this prerequisite.

## Observable outcome

The current challenge still opens, accepts board input, completes once and returns
to the correct story continuation. Remove only presentation code and assets proven
unreachable from supported game journeys. Record each removed component's former
purpose under docs/retired-features before deleting it.

## Initial observations, not deletion approval

Current master reads confirm these candidates:

| Candidate | Former or apparent purpose | Remaining proof |
|---|---|---|
| scripts/ui/MinesweeperChallengeOverlay.gd and scenes/dating/MinesweeperChallengeOverlay.tscn | Placeholder challenge panel; emits a dating result dictionary containing path, affection_delta, dark_point and entered_true_path. | A scene references the script and tests/smoke_load_scenes.gd loads the scene. Establish whether any production route, dynamic loader, UID or exported resource reaches it. A test reference is not itself proof of production use or obsolescence. |
| DatingScene._refresh_terminal_choice | Sets terminal-choice contact release and focus state. | Initial source search finds only the declaration. Audit dynamic and inherited calls and the retained polling/input paths. |
| DatingScene._acknowledge_pre_challenge_draw and _acknowledge_post_challenge_draw | Acknowledge rendered challenge-boundary presentation through a port, with private rehearsal/practice handling. | Initial source search finds only declarations. Establish the current reach/history owner and supported replay/practice paths before removing helpers or related state. |
| DatingScene._build_observer | Builds prior-line observation UI with capture/compare controls. | Initial source search finds only the declaration. Review current requirements, UI creation paths, callbacks and supporting fields before classifying the implementation as retired. |

The observations were made after PR #182 merged. Recheck current master and open
PRs before editing. The initial local reference search was not a complete UID or
resource reachability proof.

## Execution

1. Pin current master and inspect applicable repository instructions and approved
   challenge-presentation requirements. Identify any competing edit owner.
2. Audit the candidate script, scene, UID sidecars, resource references, preload/load
   calls, string-based calls, signals, subclasses, fixtures and supported entry
   points. Follow dependencies transitively; an isolated text search is insufficient.
3. Classify each candidate as used, proven unused, or unresolved. Keep unresolved
   candidates. Ask only if an actual player-facing feature decision blocks removal.
4. For proven unused code, append a Markdown retirement record with former purpose,
   exact baseline revision, reachability evidence and retained replacement path.
5. Remove the smallest complete unused group, including newly orphaned callbacks,
   fields, private copy and sidecars where proven exclusive to that group. Update a
   smoke-test entry only if its scene is actually retired.
6. Improve ambiguous names only in retained code being reviewed. Preserve public
   signatures, serialized keys and dynamic names unless all consumers are migrated
   intentionally. Do not rename accurate names merely for consistency.
7. Remove explanatory comments from the touched first-party code, preserving legal
   notices and executable directives. Keep necessary rationale in the retirement
   record or existing design records.
8. Run focused checks and open a separate implementation PR with the exact outcome,
   evidence and exclusions.

Start with the smallest proven group; this handoff does not require removing every
candidate. Do not expand into a rewrite of DatingScene or the challenge state machine.

## Verification

- Record before/after references for each deletion, including dynamic and resource
  references. Historical logs and archived source are not executable callers.
- Verify retained executable tokens for comment-only edits and consistently mapped
  identifiers for pure local renames. These checks do not establish unreachability.
- Run affected syntax/import and scene-load checks using existing cloud entry points.
- If retained challenge presentation or input paths change, run the relevant connected
  challenge-open, completion and story-return journey. Include replay/practice only
  when their shared path is touched.
- Regenerate/check public inventories using the merged stable inventory tooling when
  dependencies change. Do not manually invent generated output.
- Use TLA+ only if modeled progression rules change. This mission intends no such
  change. No new formal model is required for deleting unreachable presentation code.
- Skip unrelated shop, audio, full localization/layout matrices and performance
  comparisons unless the final diff affects their protected behavior. Report actual
  automatic CI selection separately. Do not weaken gates to hide a failure.

Success requires unchanged supported player behavior, retirement documentation for
every deletion and no broken script, resource, scene or test references. Fewer lines
are a maintainability result; claim no runtime speedup without measurement.

## Coordination and exclusions

This conversation owns planning. A separate implementation session owns this slice.
The stable-inventory worker owns inventory tooling and its active branch; do not edit
those files concurrently. Read-only investigation may proceed while that work runs.
Begin runtime edits from its merged result.

Exclude new features, save-format changes, historical evidence rewriting, speculative
hardening, repository-wide renaming and unrelated comment cleanup. Do not remove the
active ChallengeOverlayHost merely because the similarly named placeholder is unused.

## Starter prompt

Read this handoff, verify that the stable inventory implementation associated with
PR #183 has merged, and inspect current master plus open work. Audit the named
challenge-presentation candidates. Document and remove only the smallest proven
unused group, clarify retained names where useful, run focused cloud checks and
open an implementation PR. If the prerequisite is still in progress, complete the
read-only audit and report findings without runtime edits. Preserve current challenge
and story behavior and distinguish proven findings from unresolved candidates.
