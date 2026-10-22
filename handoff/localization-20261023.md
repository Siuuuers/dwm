# Localization session handoff — 2026-10-23

## Start here

Continue localization for Siuuuers/dwm on a new branch based on the current
codex/playable-master-integration-20261023 head. Read AGENTS.md and CLAUDE.md,
docs/japanese-korean-ui-draft.md, current PR #42 metadata and its handoff.
Inspect PR #43 before touching authored dialogue: its authored-week work has
not automatically become the integration branch's story.

The Steam upload session owns packaging, export configuration and SteamPipe.
Keep localization edits scoped to catalogs, localized UI and required fonts/tests;
coordinate changes to shared registration or runtime owners.

## Current facts to verify before editing

- Last observed integration source: 3b23d8fc6b2798340af0b688323be3eee99458f7.
- Five existing UI locales: English, Simplified Chinese, Traditional Chinese,
  Japanese and Korean. Japanese/Korean catalogs are drafts needing review.
- Existing guide reports 300 UI IDs in the earlier draft; recount current keys.
- Story/dialogue, correspondence and authored Gallery prose can fall back to English.
  Selectable UI languages do not prove a fully translated game.
- Contacts secondary-language display has a known unconnected preference.
- User-uploaded paintings and newly integrated Bach recordings must be preserved.
- Published build branch is a separate snapshot; consult its package-receipt.json.

## First observable outcome

Every supported UI screen shows the selected language with intact placeholders,
readable glyphs and working controls; changing locale preserves progress and preferences.

1. Audit current catalogs and visible hard-coded strings, especially Gallery,
   Pause, Title, Settings, Backup, Shop, Contacts and Challenge controls.
2. Reuse LocalizationManager/ProfileManager and stable message IDs.
3. Preserve observer framing. Do not introduce player-addressed "you" into prose
   where the original addresses an observer; retain necessary control instructions.
4. Check missing keys, placeholders, NFC and font coverage, then one focused cloud
   rendered pass for changed screens and representative enlarged text.
5. Preserve captions, stable event/line IDs, receipts, choices, save/recovery/history
   and English fallback. Translation must not change narrative semantics.
6. Before translating the authored seven-day story, confirm target languages and
   the authoritative PR #43 revision with the user. UI-first work can proceed.
7. Open a focused draft PR against the integration branch. Do not merge unrelated
   PRs, publish builds, or repeat completed game qualification.

## Copy into the new session

Continue Siuuuers/dwm localization. Read handoff/localization-20261023.md on
codex/playable-master-integration-20261023, then inspect current branch and PR
states. Start with a five-locale UI completeness and layout audit, fix bounded
gaps using existing localization owners, and use minimum meaningful cloud tests.
Preserve my art/music and all save/recovery/history guarantees. Coordinate with
the separate Steam upload session. Confirm language scope and the authoritative
authored-week revision before translating story dialogue.
