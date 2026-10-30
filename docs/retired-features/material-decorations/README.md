# Retired material decorations

All three decorations and their purchases are retired: Crystal Stutters
(`crystal_stutters`), Inked Silk String (`inked_silk_string`), and Letter with Wax
Seal (`letter_with_wax_seal`). This supersedes the material-decoration handoff.

## Preserved implementation

`source/` preserves exact source snapshots from commit
`a821def04109c99e3a9be0f248992b0785bdcbbe` (PR #165), including the material
renderer, computer/art/transport integrations, Shop catalogue/copy/art, effect
registration, and former unit/rendered purchase journeys. Files end in `.gd.txt`
so Godot cannot import them as live scripts. `source-sha256.json` records their
original SHA-256 hashes. The complete original revision remains in Git history.
These snapshots are historical references, not an alternate enabled feature.

## Runtime disposition

- Remove crystal cracks, silk edging and purchased paper from every surface.
- Remove all three offers, localized descriptions, item art, and effect registrations.
- Reject direct purchase attempts through the current Shop owner without mutation.
- Preserve the five ordinary products and the secret Supportz slot, interaction
  improvements, typography, layout, focus and disabled-state styling.
- Preserve legacy inventory and historical receipt data as inert save data. No
  refunds, destructive migration, or feature toggle is introduced. New runs do
  not inherit the inventory. Compatibility-only Notes purchase-count identifiers
  remain accepted by the existing schema; they do not enable these Shop offers.

## Verification

The retained `shop_cosmetic_journey` suite name now tests retirement: seed legacy
ownership, assert unchanged sampled pixels and absent cards, reject direct
purchases, save through the real owner, load in a fresh process, and start a new
run without modifying the prior save. Unit tests cover the reduced catalogue,
retired art/copy, purchase rejection and unchanged layout/focus/control styles.
Godot/rendered verification runs in GitHub Actions per repository policy.
