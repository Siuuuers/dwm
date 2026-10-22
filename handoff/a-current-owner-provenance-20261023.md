# Current-owner provenance refresh

This is static evidence reconstruction, never runtime source loading or a migration. The prior qualified controller is commit `584a2b615c17d509be9d714cccddf2e2c799a883`, `.github/workflows/master-integration-restore.yml`; original evidence is retained under `evidence/phase_2r/master_integration_20261023/run39839181557/`. Its design names ephemeral `build_proposal.py` and `verify_layers.py`, which are absent from tracked history and the retained original archive. The replacement script reproduces the existing bounded inverse format transparently.

Reviewed current owner: `7d2db1fb05a5b298f9fc14b47cdf3a5b6f890e7e:autoload/GameState.gd`, normalized UTF-8 LF, 323311 bytes, SHA256 `fd26d735c2c5ffa62aefdb5ca56ddd08985da5f4534c327f5c7237acb286f3b9`.

Unchanged accepted owner: `23d8b3dfdd63948549af318917df5f4a84ac5120:autoload/GameState.gd`, 203638 bytes, SHA256 `6cbd8f935e2fb6c02db5e78cbafd915d5cd2971712d061c5d9e8f336bbea100f`.

The 21 ordered nonempty replacement spans remove 122698 bytes and restore 3025 historical bytes. Reconstruction equals the accepted Git bytes exactly. Only `_without_authenticated_scene_composition` changes: the source identity, finite spans, and comment. Every test body, historical control, downstream inverse and historical hash remains byte-for-byte unchanged. No historical fixture is refreshed. The script authenticates both Git inputs and the actual current owner before generating anything, and verifies the remainder of the test file against the reviewed source.

Reproduction from repository root, with both Git commits available:

```sh
python tools/testing/refresh_restore_owner_provenance.py --write --report /tmp/current-owner-provenance.json
python tools/testing/refresh_restore_owner_provenance.py
```

`--write` is explicit; default invocation only checks. A later GameState edit must trigger a deliberate new source review, not automatic hash replacement. Python difflib operates on normalized lines with one unchanged boundary line around each edit, merging overlaps; complete input/output hashes and exact reconstructed bytes are the authority.

Static generation and verification passed. Engine acceptance remains pending. The focused cloud template runs the original five restore and three live-rollback cases, requires both six-direction historical-control markers, source-derived exact census, positive assertions, clean import/process/log evidence and retained source hashes. Inventory regeneration is handled separately through `Invoke-PublicSurfaceValidation.ps1 -Regenerate -EmitPayloads`; canonical Windows checks remain check-only. Do not duplicate those jobs solely for this focused control qualification.
