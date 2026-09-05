# Backup UI verification

Run `python tools/backup_ui/verify.py` for the actual Backup/Desktop scene suite,
or add `--probe` for the bundled-font fit comparison. Each run uses a disposable
headless Godot project with no configured game autoloads and isolated APPDATA/
LOCALAPPDATA. The operation owner is a test double; production Backup and shared
confirmation UI are not replaced.

The suite exercises fixed drawer identities/order and geometry, the Save/Load
roving mode group, drawer selection without record operations, action presence,
host confirmations, Cancel-first focus, modal custody, stale preparation,
failure/retry, pinned status/actions, genuine information overflow, multilingual
font presets, Home/Back, cached reopening, day eviction, and restored Backup.
Regression cases cover failed projection, unavailable re-entry, deferred layout
under a modal, and cancellation before eviction restores the lower launcher.
Hidden cached Backup projection signals must preserve shared Home routes and
launcher focus. Recovery owns foreground input and loses Retry when refreshed
capability no longer permits re-entry.
Cached reopening must reread changed owner metadata rather than retaining stale
projection authority. Real persistence transactions are verified separately by
the backup-operations suite.

## Measured typography decision

The fixed drawer target is 144x176 logical pixels, with a 136x168 paper face and
128px text measure. Full identity plus state and a 6px gap cannot fit at a uniform
36px text size: the font probe measured up to 204px in English and 280px in the
draft Chinese cases, exceeding the 168px paper height.

The working design therefore gives cabinet and inspector-dock action text a fixed
role of 20/25/30px at 100/125/150%, while inspector, mode and confirmation text
retain 24/30/36px. This is an explicit
design change, not dynamic shrinking, truncation, or a claim that the old uniform
master passed. The compact role's maximum measured identity/state heights were:

| Locale | 100% | 125% | 150% |
|---|---:|---:|---:|
| English | 60 | 111 | 129 |
| Simplified Chinese | 99 | 120 | 141 |
| Traditional Chinese | 99 | 120 | 141 |

Mode/actions use fixed 64px large targets with at most 4px vertical padding.
The tallest measured 36px Chinese mode glyph line was 53px, so 53+8 fits 64;
the former 48px target could not contain it.
The dock's `Overwrite` label fits a 128px measure in one 40px line at font30;
font36 needs two lines measuring99px even at a136px measure. The compact dock
role preserves the full verb and target geometry. Native Button text is empty;
the visible Caption and accessible name agree, avoiding duplicate minimum-size
calculation. Caption layout must update independently of the drawing callback.

Probe labels are draft typography inputs, not approval of localized wording.
Portable evidence is saved in `tools/backup_ui/evidence/font-probe/` and `ui/`.
Receipts hash the copied bytes actually tested. The sole allowed engine error
is the exact Windows root-certificate diagnostic, which remains in the log.

These checks prove headless geometry and interaction within the tested scope;
they do not establish GPU raster quality, real save/load durability, or installation
in another checkout.
