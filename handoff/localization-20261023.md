# Localization session handoff — 2026-10-23

## Authored-week follow-up (2026-10-23)

The owner has now explicitly selected PR #43's DTL and authorized its required
runtime support on `codex/playable-master-integration-20261023`. The earlier
confirmation hold below is resolved. The authoritative English source is PR #43
commit `e2d1cd5c3500d2178fcbc483495010a1922d3f0f`; its 92 authored segments and
1,666 captions are imported unchanged. Current paintings and 65,107 ms Bach
recordings are retained; obsolete PR #43 audio metadata is not imported.

The four story catalogs contain 1,682 entries each: 1,666 captions and 16 choice
labels. Languages are Hong Kong standard written Traditional Chinese, Simplified
Chinese, Japanese and Korean; character names stay in Latin script. Translation
is presentation-only, including live language switching, retained captions,
History and choices. Missing/stale keys fall back to canonical English. The
English DTL, registration, receipts and saved ledgers remain canonical.

The prior UI pass completed 311 message keys in every locale (75 formerly English
Chinese messages translated per Chinese locale). Bundled font fallbacks cover
all story characters at 100/125/150 percent in Pixel and Readable styles. Explicit
presentation-only strike markup preserves the crossed-out Day 6 clue in CJK.
Catalog integrity and native font coverage pass; translation drafts have not
received independent native-editor review.

This story replaces template content, so begin a fresh run. Catalog changes
alone do not change content fingerprints. See `localization/story/README.md`
and `evidence/phase_2r/authored_week_localization_20261023` for implementation and
bounded checks. No Windows export, Steam upload or broad qualification is claimed.
The Steam session continues to own packaging.

## Final bounded native verification

Godot 4.6.3 passed 24 focused test executions / 481 assertions: nine authored-week,
choice and caption-Challenge checks; fourteen compiler/registration regression
checks; and one actual rendered production-story journey with 93 assertions.
That journey switches all five locales, preserves checkpoints/receipts, verifies
History and glyph coverage, advances in Korean, and saves/loads line.Day1.002 via
the production Pause/Backup owner with exact restored text and unchanged save SHA.
Eight unobscured 150% caption/font screenshots are retained in the native evidence.

A narrow exact-source compiler cache removes repeated full-day parsing, and the
recursively frozen registration fingerprint is computed once. Cache regressions
prove changed/malformed/deleted files and changed marker arguments are not reused;
returned values are detached. Physical source checks and storage invariants remain.
Final cloud timings: new run 11.512 s, production save 17.066 s, load 59.370 s.
These software-rendered cloud timings are not Windows performance qualification.

Actual user-data was isolated under /tmp after workspace-backed runs unexpectedly
reintroduced deleted transaction markers; synchronization is the suspected cause. The final run uses the existing injected
unavailable-speech capability because this cloud lacks libspeechd; native TTS is
not qualified. Earlier diagnostic/harness failures remain as evidence, separately
from the final clean exit-0 log and XML. No further test expansion was performed.

## Earlier session instructions (historical)

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
