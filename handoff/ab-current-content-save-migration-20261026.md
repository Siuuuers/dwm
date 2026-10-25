# Current-content save migration — 26 October 2026

## Status and outcome

The coordinated migration is implemented on `codex/current-content-save-migration-20261026` and awaiting cloud
qualification. Static review and diff checks pass; this is **not yet runtime acceptance or a merge claim**.
The candidate adds player reading schema 7, admission-time normalization of current and journal snapshots, bounded
encountered History, and separate story binding for retained physical Challenges. Document and Run versions remain 9.
Ten rendered create/load/reload cases cover content edits, fallback, History, board resumption/transfer, resolved
unfinished Challenges, and completed passages with appended/deleted final text. Focused owner and boundary tests
complement those journeys. Godot execution remains cloud-only.
Ordinary completed passages additionally retain `lifecycle.completed_registration_sha256`. This preserves the
content version against which completion occurred, while same-content completion still requires the final passage
caption. Legacy completed saves acquire their original registration hash only when content admission rebases them.

Read [the accepted reading/startup decisions](aa-reading-startup-simplification-20261026.md) first. [PR #104](https://github.com/Siuuuers/dwm/pull/104) contains the independent prepared-configuration, authoring-identity and
Replay work, merged as `8b8e73929801a9527872b1485a289a1ffca6e5a8`. Its exact candidate passed cloud run
[40223513652](https://github.com/Siuuuers/dwm/actions/runs/40223513652): 50 successful jobs and one separate measurement skip.
A slow-runner preliminary user-directory proof timed out before tests; the single-job retry passed on unchanged code.
Check current `master` and open PRs before editing to avoid repeating ongoing migration work. Existing timing evidence is linked from `aa`.

First observable outcome: Load displays current story content at the intact saved line, or the specified fallback, while
preserving the selected run's gameplay and exact physical board. Revised History wording does not create global read
marks. No content update automatically resets a run.

## Confirmed behavior

- A dialogue ID identifies a story moment, not its wording or ordinal. Keep existing IDs on wording edits. Never reuse a
  deleted ID for another moment.
- Text revision is separate from identity. Read status is shared across languages and uses the canonical story revision.
  Unchanged text stays read.
- If the saved line remains valid for the saved route, resume there. New text ahead appears through normal continuation.
  Insertions before an intact saved line do not force replay.
- If the line was deleted or its anchor is invalid for the route, use the one saved latest recovery checkpoint. If that
  checkpoint was deleted, use that day's start. Entire-day deletion will not occur; it is outside supported authoring
  changes. Do not add another reset/recovery mechanism for it.
- Major checkpoints are day starts and the first caption reached after a resolved choice or Challenge. Update the anchor
  when that caption is reached, not merely when the preceding operation begins. Not every entry label is a checkpoint.
- History contains the previous two checkpoint sections and the current section, through the reading position, on the
  actual route. Show current wording for encountered IDs; omit deleted IDs and never backfill new unseen lines. Do not
  duplicate boundary captions or mark text read through History.
- Current schema-6 player reading saves retain only one current caption. They cannot prove every earlier encounter after
  edits. Preserve their provable caption and build bounded History as reading continues; do not invent an old encounter
  list or retain old full DTL versions.
- Saved choices, results, money, inventory, pressure, penalties, daily limits and other required gameplay values remain
  authoritative. Do not replace them with revised defaults or perform retroactive prerequisite adjustments.
- Re-encountering an unresolved Challenge resumes the same physical state. A Challenge with a recorded result stays
  unavailable and follows that result.
- If an update removes Challenge A before its story result is recorded, carry its exact saved state to the next eligible
  unresolved different Challenge B. This includes a terminal board. The eventual story result belongs to B. Keep a carried
  board suspended if no eligible Challenge has yet been reached; do not discard it.

## ID generation finding

Bundled Dialogic already persists `#id:` tags. `DialogicUtil.get_next_translation_id()` allocates hexadecimal values from a
project counter; the editor CSV collection assigns only missing IDs. The [official workflow](https://docs.dialogic.pro/translation.html)
confirms those tags. Do not enable native CSV playback merely to allocate IDs: this game uses JSON catalogs. No additional
runtime plugin is needed. Preserve all existing IDs; generate once for a genuinely new beat and keep duplicate validation.
A counter needs coordination across parallel authoring branches. If a separate cloud authoring command is added, Python's
standard-library `uuid.uuid4()` is an available independent allocator. Encoding a line number or hashing prose is not a
substitute for stable identity. Automatic missing-ID authoring has not been added by PR #104.

## Correct Challenge terminology

There is no player-facing Finish button in the current Scene Challenge panel.
`ApplicationBootstrap._scene_challenge_published()` detects a terminal board and defers `_complete_scene_challenge()`,
which closes the computer and invokes `GameState.continue_completed_scene_challenge()`. Ordinary caption advancement can
resolve a never-started or unfinished Challenge through the internal `challenge.end` event. Some test descriptions call
that event “Finish”; this does not describe a visible button. Preserve automatic terminal continuation.

Physical state and recorded story outcome are different facts. In particular, `record.state == "in_progress"` can remain
after the player leaves the cue and the story records `"unfinished"`. Check saved outcomes first. Such a resolved attempt
must not reopen or transfer. Conversely, a terminal physical record can exist before its automatic story-result
transaction completes, and the owner explicitly permits that unclosed record to transfer.

## Baseline owners and entry points before this migration

| Owner | Relevant responsibility |
|---|---|
| [SaveManager](../autoload/SaveManager.gd), `_prepare_restore()` | Read exact selected bytes, check selected revision and player format, call migration, then prepare the restore transaction. |
| [SaveMigrations](../scripts/infrastructure/save/SaveMigrations.gd), `migrate_document()` | External save admission. It currently calls full current-content validation immediately, before content-position recovery can occur. |
| [SaveDocumentSchema](../scripts/infrastructure/save/SaveDocumentSchema.gd), `validate()` | Validate document/current-bundle/recovery-journal envelopes; preserve document identity and selected save semantics. |
| [RunSnapshotSchema](../scripts/domain/run/RunSnapshotSchema.gd), `validate_current_scene()`, `_validate_scene_reading()`, `_validate_scene_progress()` | Current Run9 shape, current Scene/read joins and gameplay facts. Historical choices/results currently require current registration membership. |
| [SoloReadingSession](../scripts/narrative/SoloReadingSession.gd), `project_player_checkpoint()`, `expand_player_checkpoint()`, `restore_player()` | Project schema 5 live reading to schema 6 player position and expand it. Schema 6 requires registration equality, one caption and a resolvable position; it has no recovery anchor or bounded encounters. |
| [FrozenRunContext](../scripts/narrative/FrozenRunContext.gd), `derive_current_scene_frames()`, `_validate_scene_envelope()` | Join live reading, Scene occurrence and current registration after migration. |
| [DialogicBridge](../autoload/DialogicBridge.gd), `_prepare_scene_reading_candidate()` | Stage native current-content playback. Its own registration check also exists; changing only `restore_player()` is insufficient. |
| [SceneReadingHistory](../scripts/narrative/SceneReadingHistory.gd), `project()` | Current display projection reconstructs the day from choices/results. It has no encountered-ID filter or three-section bound. |
| [GameState](../autoload/GameState.gd), `_advance_scene_registered_marker()` | Dispatch controls. Duplicate command receipts currently live only in the current session; they do not prevent post-fallback repetition. |
| GameState, `_current_scene_challenge_command()`, `commit_scene_challenge_closure()` | Derive current physical command and save the story result/destination. Current closure keys combine occurrence and Challenge ID. |
| GameState, `_prepare_scene_day_renewal()` | Renew counters, advance day identity and discard the ordinary board at a real day transition. Do not repeat it during recovery traversal. |
| [DatingPhysicalOwner](../scripts/application/run/DatingPhysicalOwner.gd), `_scene_authorize()`, `_begin_scene()`, `_close_scene_locked()` | Admit/resume the retained physical attempt, preserve its selected prefix and classify closure. Current narrative destination is derived from physical context. |
| [DatingAttemptLedger](../scripts/profile/DatingAttemptLedger.gd), `semantic_slot()`, `_entry()`, `_valid_scene_record()` | Profile attempt identity, frozen entry/context/spec, materialization proof and branch progress. |
| [DatingChallengeEnvelope](../scripts/application/run/DatingChallengeEnvelope.gd), `_scene_advances()` | Validate exact physical evolution; rejects changes to context, spec and physical command identity. |
| [ApplicationBootstrap](../autoload/ApplicationBootstrap.gd), `open_scene_computer()`, `_scene_challenge_published()`, `_complete_scene_challenge()` | Mount the current Challenge panel and automatically continue terminal boards. |

## Smallest coherent implementation direction

The following records the agreed direction used for this implementation. Acceptance status is stated above.

1. **Own content normalization at save admission.** Validate external shape and required saved facts once. Resolve the
   selected reading position against current content before full current-content validation. Return a detached candidate
   for existing restore owners. Keep internal live joins strict after normalization. Do not implement compatibility by
   removing isolated hash comparisons or by rewriting the selected save before restore succeeds.

2. **Add only the required reading state.** Extend player reading with one recovery anchor and bounded encounter sections.
   Keep the current line and text revision distinct. For schema 6, retain the known caption; if its line is gone and no
   recovery anchor exists, use day start. Keep ordinary caption, held-control and between-entry save boundaries meaningful
   during expansion. Use current compiled DTL as the semantic source, not a second story engine.

3. **Separate current story binding from physical attempt identity.** Existing Challenge context includes whole-story
   `registration_sha256`; context and spec are frozen into the Profile slot, entry receipt, command hash and envelope.
   Renaming that context from A to B would invalidate physical history. Preserve the physical record and exact Profile
   reference. Let the Run own which current story Challenge consumes that record. A prose edit must not require a new
   board or new rules. An active physical board can stay suspended while the reading cursor is at an earlier fallback
   checkpoint.

4. **Use saved outcomes and choices to avoid repeated controls.** Automatically follow resolved choices/Challenges on
   fallback. Existing outcome rows retain an opaque hash key plus Challenge ID/result; the original earlier occurrence
   cannot be recovered from the hash. Do not invent it. Preserve retired saved facts instead of requiring every historical
   ID to remain currently authored. Record the specific physical-attempt/result association needed to prevent a
   transferred record from being consumed again. Use existing outcome ownership, not a general receipt ledger. Keep day
   renewal and existing gameplay effects out of already-resolved recovery traversal.

5. **Commit through the existing transaction.** Current story binding, outcome and destination checkpoint must be saved
   together. Preserve the selected physical prefix across Load branch allocation. Never substitute newer Profile progress.
   Transfer itself does not change economy/counters, regenerate a layout or recompute capabilities from today's inventory.
   Keep frozen saved pressure/penalty inputs, spec, preparation state, flags, reveals and terminal state. Continue using
   existing write-failure/retry ownership.

6. **Integrate History and native restore, then qualify one candidate.** Make History and caption scrolling consume the
   same bounded encountered data. Review Contacts return frames and completed-passage saves at the same migration
   boundary; their registration joins also exist. Do not silently reactivate a completed run when its final caption
   changes. Complete compatible caller and test audits before final cloud acceptance runs.

Do not broaden this batch into arbitrary pre-Run9 schema conversion, a new recovery UI, full DTL-version retention, new
managers, or removal of the new-run intent journal. Those do not follow from these content-update requirements.

## Essential failure and regression cases

- Wording changes and insertions before/after an intact saved line: same visible moment, current wording, no forced
  rewind, unchanged gameplay.
- Deleted line; deleted latest checkpoint; schema-6 save with no checkpoint: apply the defined fallback and preserve the
  route. Day start remains authored.
- Held Challenge-control saves and ordinary caption saves both expand into valid native playback without repeated
  publications or controls.
- Bounded History rolls across three sections with one copy of each boundary; no inserted unseen lines; deleted IDs
  omitted; revised History text adds no global read marks. Legacy History initially contains only provable encounters.
- Resolved choice and every Challenge outcome survive fallback. In particular, a resolved `unfinished` outcome does not
  reopen its `in_progress` board.
- Same unresolved Challenge resumes the selected exact board after wording change or fallback, including flags,
  preparation and physical attempt reference.
- Deleted A transfers to B with an active board and, separately, a terminal board. B receives the result; no new board,
  manual Finish button or duplicate automatic continuation appears. A resolved destination is not consumed again.
- A carried board remains intact before any eligible destination is reached. Fresh-process Load preserves the suspended or
  bound state.
- Failed binding write and failed closure/destination write preserve recoverable prior state; retry commits once.
  Profile-ahead recovery does not substitute a later prefix for the selected save.
- Transfer/fallback does not change money, inventory, pressure, penalties or daily limits, repeat day renewal, or
  duplicate any result/effect.
- Contacts return and completed passage restore retain their required behavior. Existing Gallery Replay may grow global
  read status but not active gameplay.
- Independent sessions still share only immutable content; mutable cursor, encounter history and gameplay remain separate.

Run Godot and rendered Windows journeys in cloud CI only. Local static checks are allowed. Use fresh-process create/load
cases, rendered cue/board/History journeys and strict shutdown-error checks. Report actual validation separately from
matched performance measurements; a simpler schema alone is not a speedup.

## Separate performance finding

The retained candidate reports show reading configuration reduced to 109–115 ms in retained New Acc and 29–33 ms in
Load. Remaining inclusive costs concentrate in transaction/snapshot validation: New Acc decision preparation 4.56–4.71 s,
resume transaction 5.98–6.18 s; Load's seven snapshot validations total 3.90–4.28 s, including 3.04–3.33 s pre-semantic work.
These overlap with structural-bundle validation and must not be added to parent timings. New Acc snapshot-detail records
are empty, so unexplained time is not established disk I/O. The next bounded performance experiment can trace reuse of
already admitted immutable registration tables through `RunSnapshotSchema.validate_current_scene()` and
`SceneEventContract.validate_bundle_structure()`, including observed-body copies/equality. Keep external admission and
foreign-bundle rejection. This is a measured investigation direction, not implemented optimization or permission to remove
validation broadly. Current button-to-caption evidence does not establish lazy-day preparation as the next stall fix.
