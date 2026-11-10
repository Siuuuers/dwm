# DWM working guide

## Execute

- Check `master` and concurrent work. State one outcome; read only relevant code,
  callers and design records.
- Make the smallest complete change using existing owners. Update affected callers,
  tests, configuration and inventories. Before retirement, trace direct/dynamic
  callers and saved-data obligations; record purpose in `docs/retired-features/`.
- Run focused checks; broaden only for affected behavior or dependencies. Verify
  tests execute with positive assertions. Report revision, results and omissions.
  Measure before claiming speedups.
- Continue authorized work without reconfirmation. Ask about unresolved behavior,
  scope or data decisions; continue independent work while waiting. Avoid
  speculative features, abstractions, hardening and injection campaigns.

## Read the relevant owner

- Runtime: relevant `docs/design/` records; Scene, History and Save/Load start at
  the [current scene contract](docs/design/2026-10-25-current-scene-state.md).
- Story, characters or dialogue, wherever the file lives: read
  [story guidance](story/AGENTS.md) and the [story home](story/README.md).
  For Priscilla–Lavinia, also read the [pair guide](story/relationships/priscilla-lavinia/AGENTS.md)
  and [working home](story/relationships/priscilla-lavinia/README.md).
- Before applying legacy cast, dating, viewpoint, route, Challenge or ending rules,
  read the [current foundation and intended flow](story/09-priscilla-foundation-amendment.md).
  It overrides only named conflicts.

## Preserve scope

Latest explicit user decisions govern task scope; old publication restrictions
do not require renewed approval within authorized work. Preserve approved behavior, data-loss handling,
accessibility and unrelated work. Never delete protected archives as feature-branch
cleanup. Verify implementation in current code and merge status in PR metadata.
