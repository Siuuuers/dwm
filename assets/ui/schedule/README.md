# Neutral Schedule specimen ticket

These are two independently specified vector masters authored by Codex in this
repository for the accepted Schedule optional-art fallback. No third-party art,
reference image, character identity or story symbol was copied.

- Compact: 24x24 native pixels, `neutral-ticket-compact.svg`.
- Folio: 64x64 native pixels, `neutral-ticket-folio.svg`.

Both show the same upright blank ticket with a clipped upper-right corner. Each
uses its own integer, axis-aligned stepped contour. The folio geometry is not a
runtime enlargement of the compact version. There are no letters, counts, icons,
initials, serials, wear, warning marks or interpretive decorations.

The two fixed colors are Deep Navy `#151b25` and Worn Cream `#c3baa3`; all remaining
pixels are transparent. Godot imports each master once at its declared native
dimensions, with alpha-border recoloring and mipmaps disabled. The future screen
must use the game's fixed two-logical-pixels-per-native-pixel mapping, with no
text-size/theme/selection-dependent transform, tint or filtering.

This is registered as `schedule.neutral_ticket.v1` by ScheduleArtRegistry. It is
only an optional art fallback for an action registered by the authoritative
Schedule action registry. It supplies no name, eligibility, invitation, receipt,
availability or route facts. Missing/corrupt fallback resources must fail rather
than instantiate a broken-image placeholder.
