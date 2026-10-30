# Retired material decorations

The rendering functions for Crystal Stutters (`crystal_stutters`), Inked Silk
String (`inked_silk_string`), and Letter with Wax Seal (`letter_with_wax_seal`)
remain retired. Following the owner's clarification, all three are purchasable
again for $45 each, once per run, and add only to inventory. PR #166's purchase
retirement is superseded; its rendering retirement remains in force.

## Preserved implementation

`source/` preserves exact source snapshots from commit
`a821def04109c99e3a9be0f248992b0785bdcbbe` (PR #165), including the material
renderer, computer/art/transport integrations, Shop catalogue/copy/art, effect
registration, and former unit/rendered purchase journeys. Files end in `.gd.txt`
so Godot cannot import them as live scripts. `source-sha256.json` records their
original SHA-256 hashes. These snapshots are unchanged historical references.

## Current runtime disposition

- No crystal cracks, silk edging or purchased paper on any surface.
- Three $45 offers grant ordinary inventory only; no stat, Notes or visual effect.
- Existing owned inventory remains owned and prevents duplicate purchases.
  Save/load preserves it; a new run starts with its own inventory. No refund,
  destructive migration or toggle is introduced.
- Public order: Crystal Stutters, Inked Silk String, Letter with Wax Seal,
  Metronome, Pocket Calculator, Bookend, Lucky Charm, Debug Key. The secret
  Supportz slot remains last. Capability and currency rules are unchanged.
- Lucky Charm uses the pre–PR #1 Weighted Plush tile; Debug Key uses Bandage Pack.
  At `9e43b52c9884ccd59e82245d2168c3113ee4d037`, the optional PNGs were absent:
  ShopPresentationPort generated ID-derived coloured tiles with one-pixel borders.
  The owner chose these exact historical tiles rather than newly drawn icons.
- Balances share a full-width tinted header; cards paginate beneath it. The
  redundant inspector price beside availability is removed. Card prices and
  purchase totals remain exact and localized.

## Verification

`shop_cosmetic_journey` purchases all three through the real owner, checks one
$45 debit apiece and unchanged sampled desktop pixels, saves, loads in a fresh
process, rejects duplicate purchases, and checks new-run availability without
modifying the prior save. Catalogue, art provenance, focus and 100/125/150% layout
checks cover the restored offers. Godot/rendered verification runs in GitHub
Actions per repository policy; check the current PR for execution results.
