# Contacts consolidated working-copy changes — 2026-09-05

This is a useful design consolidation in the isolated Contacts build worktree,
not a new specification workflow or a claim of exact acceptance. Root source,
registries, Beads, source archives, and runtime files were not changed.

Starting source: `C:/Users/glori/Documents/dwm/docs/design/current-ui/contacts.md`,
65,286 bytes, SHA-256
`3acb1d404733fe892d46328cb897294d7580a9a60df479ebee02880bdd563cc8`.

Changes in [contacts.md](contacts.md):

- Frontmatter and opening note identify a September 5 working copy derived from
  the amended root. The old August 25 acceptance belongs to historical bytes;
  no exact approval of this new file is claimed.
- Sections 1.2–1.3 and 17 label the old source fingerprints, inbound inventory,
  and source-range tables as historical reference. Fingerprint rows and both
  complete B/V mapping tables are retained byte-for-byte.
- Sections 9–12 remove the retired Day-2 pair from the Unread entity table,
  dedicated marker, persistence stages, and transaction/reordering requirements.
  Explicit absence replaces those requirements. The existing Day-2 clock-bleed
  eligibility exclusion is retained; it does not create a missing pair record.
- Sections 14, 16, and 17 replace pair History retention, visual/assistive order,
  stage-recovery proof, and marker-placement conflict resolution with absence
  across visible, assistive, timestamp, notification, Unread, transcript,
  History, receipt, save/load, and recovery surfaces. Ordinary return scenes,
  real Day-2 correspondence, and linked-offer semantics remain intact.
- Section 5 adopts Focus-study candidate C as the current working recommendation:
  48-native-pixel row pitch, unchanged 116×40 semantic body, and one clear
  background pixel before Focus. The eight rectangles match the study's exact
  candidate-C coordinates; all 44-pixel row formulas are removed. Header and
  pane geometry remain unchanged.
- Sections 4–6 replace bitmap baseline formulas with shaped font metrics and
  visible-ink fit in the 32-native-equivalent name measure. At most two lines
  remain allowed; clipping/truncation is a failure rather than a solution.
- Sections 4, 13, and 16 distinguish smooth lettering at the actual display
  scale from hard pixel chrome. Contrast checks use foreground/background
  pairs and rendered legibility rather than demanding binary glyph edge pixels.
  The [companion working design](working-design.md) owns the font baseline
  recommendation; this copy does not independently choose a new default.

Reference study:
`C:/Users/glori/Documents/dwm/temp-artifacts/contacts-proof-prototype/FOCUS-FINDINGS.md`,
“Exact proposed change.” Candidate C was tested against 44/46/48 alternatives;
the study is evidence for this recommendation, not historical exact acceptance.

Verification: reviewed the source-to-copy differences; scanned all remaining
Day-2/pre-echo/continuation references and old row/baseline formulas; confirmed
the root SHA-256 is unchanged and historical fingerprint/B/V mapping tables
are identical. These are document consistency checks, not a new engine or
visual acceptance claim. Unresolved broader layout, localization, and input
proof remains described in the working design.
