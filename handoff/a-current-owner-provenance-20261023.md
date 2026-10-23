# Current-owner provenance refresh

## Superseded current verification

The current suite authenticates the four frozen override method bodies and verifies
that both controls inherit the current GameState. The unchanged mutation probes
exercise all six historical alias directions and current capture/apply/rollback
isolation. Whole-file reconstruction is no longer a current gate: unrelated
GameState changes invalidated that pin in run39970090322 while 247 other persistence
cases passed. The obsolete refresh tool is removed; its exact historical version
and the reconstruction below remain available at commit
`f29c5482f0a5e80d89e9ad3ec8566e7a761848db`. This simplification still requires cloud
qualification; the earlier accepted results below retain their original scope.

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

Static generation and verification passed. Cloud acceptance is recorded below. The focused cloud template runs the original five restore and three live-rollback cases, requires both six-direction historical-control markers, source-derived exact census, positive assertions, clean import/process/log evidence and retained source hashes. Inventory regeneration is handled separately through `Invoke-PublicSurfaceValidation.ps1 -Regenerate -EmitPayloads`; canonical Windows checks remain check-only. Do not duplicate those jobs solely for this focused control qualification.


## Accepted cloud controls

Run39871056351/job120145312655 used source103f7ad2e8c7acaf110abcd37232741de15fe811, tree36c7200f9fd69d61bdd8eee1825ce1b881243708, controllerfe3d7614777f364010cb97c9ac94c075e181de7f. All8 original tests passed with1408 assertions, no skips/errors/failures, both exact six-direction control markers once, and clean import/test exit0. The21-span static reconstruction passed inside the cloud gate. This accepts the bounded provenance/control refresh; it does not certify the full canonical suite or exact integration export.

Artifact12465718507 transport233815 bytes, SHA25661097f9764d74c00817365e6ec7cf425eeb91c9c33a86e1c321bd6274a40e51a. Retained original archive236638 bytes, SHA25653b6620a321f015baba7c70b8adb236cc83f2057eb3b05df4d9c64906aaec42e. ZIP CRC and all24 manifest member sizes/hashes were independently verified. The [evidence index](../evidence/phase_2r/cold_load_supportz_20261023/README.md) links the untouched archive and gate.
