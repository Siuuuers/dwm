# Playable source integration — 2026-10-23

## Observable outcome

Bring the qualified playable template source together with current master without losing either the game implementation or consolidated story documents. Existing runtime owners remain unchanged. Success requires preserved source identity, preserved story identity, and truthful cloud CI results on the integration candidate.

## Exact inputs and composition

- Master: `41592fcc792aa615e47ee2ce2f05008ca195b311`.
- Playable source: `82d42d3524ac0cdcc90e7c7ae7f69298d5046bcc`.
- Source/evidence descendant integrated: `5eee8406f4c2c466ac05d03c489c7cdd1cbc1164` (`codex/art-media-20261023`).
- Clean two-parent merge tree before documentation repair: `81a2e63330fbf817ed08aafa3de0d31d21466935`.
- Repaired tree before this report: `6460f64a8323382f5534b8936f391ba814b004e3`.

Git's three-way merge has no conflicts. Runtime, scripts, autoload, tools, tests, assets, art/audio, project/export settings and canonical workflow match the source branch. The entire story subtree matches master. Restore master's exact CLAUDE.md because imported AGENTS.md links to it. It contains generic coding guidance; no old prompt, task-selector implementation, or validator is restored.

The binary delivery branch `builds/windows-playable-20261023` is independent and is not merged. PR30's diagnostic workflow is not imported. No code optimization, content replacement, save migration, engine change, or test-gate weakening is included.

## Verification and limits

Independent Git-object review confirms the component identities above. Existing story verifier's current-link mode passes 6 checks and 1,321 links after the CLAUDE.md restoration. The optional frozen editorial snapshot mode produces 32 passes and 7 failures in already-existing master story content. Those old excerpt/whole-file hash and phrase expectations are not changed or resealed. Both reports are retained; story equality with master establishes these are not new merge changes. Current-link success is not frozen-snapshot success.

Earlier art/media handoff qualifies 38 distinct targeted cases / 850 assertions across its accepted source runs. Run39825608353 qualifies package audit and headless startup, not an exported graphical seven-day journey. See `handoff/a-art-media-20261023.md` and `handoff/a-seven-files-20261023.md`. Do not repeat those accepted cases solely for a documentation merge.

The retained Windows automated workflow is the broad integration gate. Its 26 expanded jobs include Windows and Linux rendered jobs; all Godot/PowerShell execution stays in cloud. Existing broad failures remain unresolved until concrete results on this candidate establish otherwise. A gate failure means dependent jobs are skipped/unqualified. No whole-game, native exported journey, Steam approval, or release claim.

## PR disposition and next work

See adjacent independent PR map and divergent-proposal audit. Thirteen open PR heads are already ancestors of playable source; do not reapply them. Copied/evolved proposals need content disposition, not blind merges. PR30 is a controller. Keep historical branches and original evidence.

Publish this candidate as a draft PR to master and inspect its naturally triggered cloud CI. Preserve the first causal failure and fix only the demonstrated supported behavior or stale fixture contract; do not relabel missing coverage as passed. Merge to master only after required qualification. Reconcile incorporated/superseded drafts after source integration; no old PR is closed by this preparation.

User now authorizes work toward master integration, superseding historical blanket hold language for this task. This does not turn old targeted results into current broad acceptance. No additional user architecture choice was required for this conflict-free composition.
