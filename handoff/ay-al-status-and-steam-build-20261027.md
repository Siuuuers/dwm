# Review of handoff al and current Steam build

Date: 2026-10-27, Hong Kong time.
Reviewed source: `4db5cff4576be4163b40ff383062a6cd0284042f`.
Historical plan: [al](al-trusted-load-accepted-history-next-20261027.md).
Current performance priority: [ax](ax-save-load-improvement-backlog-20261027.md).

## Result

The approved runtime features highlighted in al are complete or superseded.
Do not use its old pending labels as a new implementation queue.
Named checkpoint and overlay machinery is implemented. Production story bindings
remain intentionally unauthored. Performance investigations are deferred.

This review compares source, later handoffs and merged acceptance records.
It is not a new whole-game acceptance run.

## Item-by-item status

| Item in al | Current status | Evidence and next action |
| --- | --- | --- |
| Measure Load, longer History, refresh/projection work and observer overhead | Done | [PR 119](https://github.com/Siuuuers/dwm/pull/119), [am](am-trusted-capture-and-passage-20261027.md): 61 cloud jobs and 24 matched journeys. |
| Coalesce deferred caption refresh with a pending flag | Experiment closed; rejected | am records one refresh during Load and zero during ordinary advance. Complete Load did not improve. The flag and its candidate tests were removed. Do not reintroduce it as unfinished work. |
| Remove temporary-ledger reconstruction from trusted capture | Done | PR 119. Encounter synchronization and detached captures remain. |
| Measure first uncached passage and reuse existing compilation/day parsing | Done | [PR 120](https://github.com/Siuuuers/dwm/pull/120): 61 cloud jobs and 24 journeys. Later passage work is accepted too. No stutter-free guarantee is implied. |
| Stable IDs, shared configuration, read marks/Replay, bounded encountered History and exact board transfer | Done and preserved | al records PRs 104, 107 and 108. [aq](aq-trusted-reading-accepted-20261027.md) preserves History and board behavior while replacing missing-reference policy. |
| Trusted shipped story tables, direct Load, Settings Back, New Account and ordinary Load simplification | Done | al records accepted PRs 110 and 116–118. Do not restore retired initial Autosave, durable creation or ordinary Load-lock proposals. |
| General nonblocking error-and-skip for edited DTL | Superseded | [PR 128](https://github.com/Siuuuers/dwm/pull/128), aq: preserve valid saved dialogue IDs; use the authored default when resolving an invalid choice; show persistent error and Quit for required missing references. Do not implement the old general skip plan. |
| Deleted-line recovery-anchor or day-start rewind | Superseded and removed | PR 128 removes these rewinds. |
| Named checkpoints, ordered overlays, direct restoration and no-op show/remove | Engine and template done | [PR 133](https://github.com/Siuuuers/dwm/pull/133), [as](as-named-checkpoint-implementation-20261027.md): 66 cloud jobs and a 116-assertion named-presentation journey. |
| Production checkpoint locations and art/music/overlay bindings | Content authoring remains | The user selected reusable templates, not invented locations. The reviewed production manifest has zero checkpoint definitions, overlay labels and entry bindings. Use the [authoring template](../tests/fixtures/presentation/README.md) when locations are selected. |
| Optional Contacts after a content update | Out of scope | Explicit user decision recorded in al. Keep existing Contacts code and tests. |
| Separate automatic missing-dialogue-ID authoring command | Optional; no separate feature added | Dialogic already supplies an allocator. Preserve existing IDs and inspect current tooling before adding another command. |
| Further resource, registry, startup, History, Save and Load timing work | Deferred investigations | am, aq and as identify remaining hypotheses. ax gives unfinished player-facing functions priority. Resume only for a concrete need. |
| General production shutdown fix or Title prewarming | Not an outstanding approved feature | Accepted runs exited cleanly; that is not proof of a universal shutdown fix. Investigate a returning signature. Prewarming remains an optional proposal. |

## What remains to choose

No production named checkpoint locations were selected in this review.
Until authors add explicit bindings, current Scene story progress relies on manual
Save. The implemented checkpoint-only Autosave path runs at authored named arrivals;
ordinary reading does not create progress Autosaves.

Choose the next unfinished player-facing function from the wider feature backlog,
or choose story checkpoint placements if content authoring is the priority.
Do not infer that the whole game is complete from this scoped review.

## Steam upload result

Steam BuildID: **26245899**.
AppID: **5199120**. DepotID: **5199121**.
Runtime source: `4db5cff4576be4163b40ff383062a6cd0284042f`.
Executable: `game.exe`, with `game.pck`.

[Cloud run 40521206789](https://github.com/Siuuuers/dwm/actions/runs/40521206789)
passed fresh Windows export, package hashes, license/media checks, isolated
executable startup, SteamPipe preview and upload. Steam returned the BuildID above.
No Steam branch was set live. Installed-client testing is not established by this upload.

To install this version through Steam, select this BuildID on the intended test
branch and confirm that its Windows launch option is `game.exe`.
The upload uses existing repository secrets without publishing authentication data.
The one-time branch/message trigger is removed after success. The retained
manual workflow pins this source; a future upload needs a deliberate source update.

See [Steam upload record](../docs/steam/CLOUD_UPLOAD.md) for the retained procedure.
