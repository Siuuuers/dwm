# Trusted live Save: remove repeated reading validation

Date: 2026-10-27, Hong Kong time.
Status: approved direction; runtime changes are not implemented by this record.
Previous record: [named checkpoints](as-named-checkpoint-implementation-20261027.md).

## Observable outcome

Manual Save stores the exact current reading position and gameplay state.
Load restores that state without repeating its consequences.
Reduce repeated capture, validation and reconstruction in the complete Save operation.
Do not move that cost onto ordinary reading.

Existing live owners remain the source of truth. SaveManager owns save preparation
and storage. The reading owner owns the current position and encountered History.
Do not introduce a second continuously synchronized copy of the game state.

## Latest user decisions

- Remove full `SoloReadingSession._validate_scene_saved` validation from the
  trusted live Save path. Trace indirect callers as well as direct callers.
- Do not delete the function globally without checking its consumers. Actual
  restoration and scene installation also use it. Some callers adopt the ledger
  it returns. Separate required construction from redundant admission work.
- Defer a separate prepared-save cache, background JSON preparation and temporary
  draft-file writes. This supersedes the earlier preference to prepare a draft in
  memory. First simplify on-demand Save and measure it again.
- Keep exact-current-state saving. Do not silently save an older prepared state.
  If preparation is reconsidered later, relevant state changes must invalidate or
  refresh it. A freshness check is different from full structural validation.
- Options and Challenges are optional and can be bypassed. The system responds to
  option-button or Challenge-result signals. Do not use the internal term
  "held control" to invent a mandatory completion gate. This is the user's
  intended behavior, not evidence that every current caller has been audited.
- A required missing dialogue ID uses the existing persistent error with Quit
  available. Keep the accepted compatibility and invalid-choice/default-route
  decisions in [aq](aq-trusted-reading-accepted-20261027.md). Do not reopen them,
  add a global content scan, or restore error-and-skip or rewind behavior.
- Keep named-checkpoint-only Autosave, manual Save, and Logout without saving.
  Do not add new injected failure or edited-file test scenarios for this work.
  Existing regression coverage remains. All game execution stays in the cloud.

## Accepted baseline and measured evidence

[PR 133](https://github.com/Siuuuers/dwm/pull/133) merged as
`06ef87219933e032c56a1255fc453058df582572`.
Its tree is `d0dd90fa4fdf377fa45622e918ad919999b18b54`.
The tested candidate was `8c449800ae66335e5a699c71e240367d23b9779f` with the same tree.
[Final regression](https://github.com/Siuuuers/dwm/actions/runs/40479567321)
passed all 66 executed jobs. One historical comparison was skipped.

[Final matched comparison](https://github.com/Siuuuers/dwm/actions/runs/40479567287)
passed. Four counterbalanced pairs on one Windows runner measured these medians:

| Complete operation or response | Baseline ms | Candidate ms |
| --- | ---: | ---: |
| Passage first correct drawing | 949.25 | 386.72 |
| Passage usable | 962.21 | 400.64 |
| Load first correct drawing | 403.99 | 396.65 |
| Long-history manual Save | 1269.70 | 1312.53 |

The large gain is passage drawing, not Load. Passage drawing improved in all four
pairs. Manual Save slowed in all four pairs. Earlier matched evidence in
[the retained report](../evidence/phase_2r/named_checkpoint_autosave_20261027/README.md)
showed the same direction: 63.8% faster passage drawing and 2.0% slower Save.
The final run showed 59.3% faster passage drawing and 3.4% slower Save.
Compare variants within each run. Do not compare absolute times across runners.

Final artifact: [12721969233](https://github.com/Siuuuers/dwm/actions/runs/40479567287/artifacts/12721969233).
Verified ZIP SHA-256:
`59c39c59771447fa1267fb01f237ac6c4711af48a9a24536e8c2900d482d54f5`.
The artifact contains per-journey observations and manual Save profiles.

Each of the four candidate manual Save profiles recorded:

- 40 calls to `SoloReadingSession._validate_scene_saved`, totaling 409-465 ms.
- One slot storage operation, including its checks, taking 80-90 ms.
- One pending issuer-root write taking 1.6-1.9 ms.

The manual Save scope starts before opening Backup/live capture and ends after
commit. It is not only JSON writing or physical-button-to-painted-confirmation
latency. The observer boundary is in `tools/testing/named_checkpoint_comparison.py`.
Phase spans can overlap. Do not sum nested spans or attribute the unexplained
remainder to disk. The label "long-history" does not prove History length is the
main cause. The 40 calls are measured; their complete caller distribution and
whether their inputs are identical are not yet established.

## Source findings

`SaveManager.get_backup_save_capability()` can call `_capture_backup_inputs()`.
Thus an interface availability query can perform a full capture.
`BackupPresentationPort.get_projection()` requests this capability.
Preparation and commit also capture inputs; commit checks source freshness.
`ProductionPauseController._capture_scene_reading_backup_inputs()` captures the
reading checkpoint before and after the other producer inputs.
Trace these paths before assigning a count to any one caller.

`SoloReadingSession._validate_scene_saved()` checks the reading boundary and calls
`_validate_scene_base()`. That function restores a temporary caption ledger.
If a pending operation exists, validation can also check its other endpoint.
Ledger restoration calls `NarrativeCaptionLedger.initialize()`, which validates
the registry and rebuilds three indexes:

- `_registered`: beat ID to frozen caption record.
- `_by_line`: line ID to the same frozen caption record.
- `_registered_entries`: entry-ID membership.

These indexes have different uses. They are not three full copies of the story.
Prefer reuse of admitted immutable registration through its existing owner;
keep each session's mutable encountered History separate. Measure initialization
before choosing a broader change. Do not add a new manager or public trusted flag.

## Next implementation sequence

1. Read current master and check for newer work before editing.
2. Attribute the 40 validations to their callers using the existing observation
   harness. Identify repeated captures and which callers need a constructed ledger.
3. Make Save availability cheap. Remove repeated full validation/reconstruction
   from trusted live capture. Reuse one coherent captured candidate where ownership
   permits. Keep the minimum source-consistency check required across real callbacks.
4. Serialize and write the current candidate through the existing storage owner.
   Do not replace this work with a continuously refreshed save draft.
5. Measure complete Save, ordinary captions, passage transition and Load against
   current master on the same cloud runner. Report regressions as well as gains.

Before editing, list concrete mistakes to avoid: an older caption saved as current,
mixed gameplay and reading state, duplicated consequences after Load, loss of a
required returned ledger, or new mandatory interaction gates.
Use normal connected Save/Load journeys and existing regression coverage.
Do not add speculative races, a new validation framework, or injected failures.
Keep compatibility and persistent missing-ID error handling intact.

No blocking product question remains. Implementation details need source evidence,
not a new interview. This is a useful new-session boundary: the previous runtime
change is merged, and the next task is a separate Save simplification and matched
measurement. The plan itself makes no new performance claim.
