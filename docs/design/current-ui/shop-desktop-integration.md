# Shop in the shared desktop

The developed Shop plate now shares the current desktop shell. Its 17 ordinary
cards, inspector, quantity dock and paging retain the canonical 18-position order,
including the structurally blank ninth position. The screen remains read-only:
quantity is presentation state, and no Buy or Supportz command is bound.

This slice adapts selected Shop source/tests from the clean pinned checkpoint
26de279be5f6490ff453db359b1964ec10596962 onto a495b453bef25afba9438330a592e19e84cf8246.
It retains the active branch's shared application owners; it is not a branch merge.

The explicit catalog provider exposes get_catalog(locale), returning a CommandResult
whose successful value is an array of 17 ordinary public records, and emits
catalog_changed when its snapshot changes. The strict existing projection validates
prices, currencies, batchability, legal maxima, names and paired texture dimensions,
keeps accepted order and removes private fields. Texture dimensions prove only fit,
not provenance. Supplied art remains an immutable owner resource reference.

Shared desktop setup validates the provider, locale/Profile owners, host and day
before retaining them, refuses replacements, reuses the cached app on Home/reopen,
and reconciles a prebound restored Shop route. Invalid restored projection remains
visibly unresolved. Missing catalog ownership keeps the Shop route unavailable.

Preference-only reflow preserves valid presentation state and quantity. A changed
catalog publication resets quantity against its new maximum; identical snapshots
are a no-op. Passive locale requery preserves quantity when non-copy facts match. Hidden or covered views
must not steal focus or rewrite the shared Home navigation. Direct invalid screen
configuration preserves the prior valid view; an authoritative provider failure
enters the existing localized unavailable presentation.

## Remaining production dependencies

DataCatalog still contains three character-gift IDs where the accepted Shop uses
bookend_keepsake, metronome_keepsake and pocket_calculator_keepsake. This change
introduces no silent ID aliases. The full public names/art/stock/maximum projection
and atomic purchase interface remain absent. The existing Minesweeper purchase
participant covers only a subset, and quote preparation retains transaction state;
it is not used as an availability poll.

ShopCopy's translations and transparent test textures remain explicitly labeled
fixtures. They do not supply production asset provenance, localized owner copy or
purchase entitlement. Existing licensed fonts and both Standard palette definitions
are retained; the shared host does not infer a Dark entitlement. Full purchase,
recovery, save/restore, remaining palettes and platform accessibility acceptance
remain on dwm-eei.7 and the all-family goal.

Validation: 114 tests / 2896 assertions, 386 native layout checks across 18
locale/text-size/target-size tuples, and four additional Standard palette captures.
Named viewport observation is retired on exit; deferred work rejects outgoing views,
and an unfinished card measurement resumes when the same view is remounted.
Independent review found no material blocker after teardown/remount corrections.

See [the evidence summary](../../../evidence/shop_desktop/summary.json) for final
source hashes, tests and native captures. Other dirty worktrees and player data are
preserved. This checkpoint includes no merge or push.
