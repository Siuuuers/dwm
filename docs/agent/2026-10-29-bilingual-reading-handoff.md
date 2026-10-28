# Bilingual reading system handoff

Date: 29 October 2026, Hong Kong.
Status: next development target; owner interview completed for scope and live layout. This handoff changes documentation only.
Reviewed master: `9d2a62c907723ee2ca8af901d458d352adb1e848`.

## Purpose and owner decisions

Implement simultaneous Primary + Secondary dialogue using the player's existing language selections. **Do not hard-code an English/Chinese pair or add a second preference system.** The owner specifically recalled the existing language implementation and wants it reused.

October 29 interview:
- Include live captions, self-talk, dialogue choices, History and unlocked Gallery library text.
- Menus and other interface text remain single-language. Preserve the existing Primary/UI relationship; no separate UI-language selector is requested.
- Live captions show **only the current pair**, Primary above Secondary. Earlier captions remain accessible through existing scrollback/History. Single-language mode keeps its accepted behavior.
- Bilingual self-talk shows **the latest thought pair**, Primary above Secondary. Older thoughts remain in the panel's scrollback. Keep the latest pair when the next caption has no attached thought; replace on a new thought or explicit clear.
- This deliberately replaces the self-talk three-rendered-row history window in dual mode, not in single-language mode. Do not clip a translation merely to force both languages into three rows.
- If Secondary translation is missing, show Primary alone. No duplicate Primary row, invented translation or per-line unavailable notice.
- Retain Primary-only Read Aloud. Do not speak Secondary automatically.
- Current DTL is replaceable draft content. Build a usable authoring/rendering system; no fixed production wording or speculative legacy migration is required.

The owner did not commission translating the entire draft or select a fixed first language pair. Use clearly labeled synthetic multilingual fixtures to prove behavior across the registered locale system, and audit available authored narrative translations. UI catalogue coverage is not evidence of narrative coverage. Do not report complete story translation when only fixtures work.

## Existing foundations and current gap

Read AGENTS.md, CLAUDE.md and applicable technical records before implementation. Read story guidance before translating or rewriting production prose.

Inspected source:
- `scripts/settings/SettingsPreferenceRegistry.gd` already registers `preferences.language.primary_locale_id`, `secondary_locale_id` and `dual_enabled`.
- `scripts/ui/SettingsPanelController.gd` handles language selections, disables Secondary when dual mode is off, and routes Primary changes through LocalizationManager. Preserve its language tuple/swap semantics.
- `scripts/profile/ProfileSchema.gd` requires different Primary/Secondary locales when multiple locales exist. Reuse canonical locale IDs and aliases; do not create duplicate spellings as separate languages.
- `autoload/LocalizationManager.gd` owns UI locale, fonts, root publication and preference changes. Its current preference callback concerns Primary/font/text size; inspect how Secondary and dual changes must reach the reading surfaces.
- `scripts/ui/witnessed/WitnessedCaptionLayer.gd` currently configures one locale and requests speech using the published Primary text and content locale. Preferences existing does not establish simultaneous bilingual rendering.
- `autoload/DialogicBridge.gd` owns reading publication/content locale and existing custody. Trace it with the native DTL compiler and caption registry.
- `scripts/narrative/NarrativeCaptionRegistry.gd` and `scripts/profile/CaptionWitnessLedger.gd` own exact beat identity and witnessing. Do not append translated strings as independent story beats.
- `scripts/ui/gallery/DialogueLibrary.gd` currently accepts a single locale and consumes `scripts/narrative/DialogueLibraryCatalogue.gd`. It must render unlocked prose in both selected languages without weakening its unread projection.
- [Earlier accepted scope](../design/current-ui/owner-ui-updates-2026-09-21.md) covered captions and History. This new interview extends that scope to self-talk, dialogue choices and library dialogue. Earlier Primary-only speech and single-language menus remain.

Gallery implementation and replaceable authoring are merged in PRs [#149](https://github.com/Siuuuers/dwm/pull/149) and [#150](https://github.com/Siuuuers/dwm/pull/150). The [library handoff](2026-10-29-gallery-dialogue-library-handoff.md) records accepted cloud runs and the manifest/compiler authoring loop. Checkpoint titles, entry selectors and conditions are authored; prose and pairing are generated from DTL. Preserve that source ownership. The production library catalogue remains unpopulated until authoring supplies bindings.

## Minimal architecture

Use one story execution, one logical caption/choice identity and one reading progression. Resolve the selected languages as presentation of that identity. Do not execute a translated DTL timeline in parallel, match translated rows by array position, or duplicate choices/gameplay effects.

Before choosing a translation adapter, inspect native Dialogic translation facilities, compiler output, existing content-localization interfaces and actual authored translation assets. Choose the smallest adapter that preserves stable line, exact variant, choice and self-talk identities. Reuse an existing adequate owner rather than building a competing localization framework. A missing search result is not proof that no adapter exists.

Prefer translations keyed to existing semantic identity and canonical locale, with speaker/markup/placeholders preserved. Author/export validation should catch missing references, mismatched placeholders and incompatible branch/choice bindings. Resolve text from generated/loaded data; no per-caption source-file scans, runtime compiler, network translation or automatic machine-translation service.

Recommended identity behavior: reading a story variant unlocks that same variant independent of display language. Rendering another translation does not create a second encounter, read mark or library discovery. Preserve current exact-variant distinctions and audit existing witness coupling before changing any registry fields. Translation prose must not silently become a different story branch.

Use existing Profile preferences, not slot-local language copies. Loading an older run should render its semantic position using current preferences, without replaying entry commands. Language changes reproject the current accepted content and encountered history; they must not mutate run progression or library membership.

## Presentation and interaction contract

- One current caption pair is one semantic reading unit. One Advance reveals/advances it under existing input rules; no extra press for Secondary.
- Latest thought pair is attached to its existing caption and appears in the same reading step. No separate thought advancement.
- Each bilingual choice remains one focusable/actionable option, two text presentations of one choice ID. Preserve the existing thought-choice row and scrolling behavior.
- History retains one entry per original event and pairs its available translations. Locale changes must not append or duplicate entries.
- Library masks both translations of an unread variant with the existing fixed placeholder. Do not resolve or expose unread prose to accessibility/tooltip/copy surfaces. Conditions, passage headings, tabs and “Self-talk” labels are interface metadata and remain in the selected single UI language; the story dialogue itself is bilingual.
- Current-pair-only applies to live views, not deletion of older reading history. Panel scrollback can show an earlier pair without changing the live frontier.
- Typography must use the correct locale/font shaping for each text. Primary/Secondary styling may differ through existing theme roles, but both must remain legible at supported text sizes. Do not shrink below the player's selected accessibility size to force fitting.
- Keep the accepted bottom caption placement and Save-attached computer tag/bar geometry. Grow the current caption pair upward or use an appropriate bounded text viewport when necessary; do not overlap controls or discard translation content.
- Self-talk overflow must remain readable via its existing scrolling surface. Switching between live/latest and review must not advance story. Single-language three-row behavior remains intact.
- Both language presentations participate in the existing caption dissolve together. Keep interface controls stable and preserve transition input retirement.
- Computer/Settings holds both presentations. Switching language while held must resume the same semantic beat, not leak an input or replay a branch.

Recommended reveal policy, to verify against the current owner: share one reveal completion gate, show both texts concurrently, and start Auto's existing delay only when both are fully revealed. Advance-to-reveal completes both. Do not introduce independent Auto timers or require Secondary speech. Keep existing reduced-motion/instant-text behavior and Skip's required stops.

Recommended missing-Primary policy: reuse the established narrative source fallback, accurately tagging the actual displayed content locale for font/TTS. Do not borrow an unrelated UI string or label fallback text as a translation it is not. If both projections resolve to the same fallback, show it only once. Audit the current narrative fallback before coding; if none exists, specify and document a source-text fallback rather than inventing prose. Secondary missing behavior above is owner-selected.

## Authoring and delivery boundary

Document how to add/change a translated line, choice and thought using the chosen adapter; how identities stay paired; and how cloud export rebuilds runtime/History/library projections. Replacing draft DTL must not require maintaining a second manually copied library catalogue of prose.

First prove synthetic translated samples covering supported writing systems and swapped Primary/Secondary roles. This is engineering coverage, not approval of production translations. Audit real content availability and report it separately. Do not remove language choices simply because a sample covers only two languages.

No cosmetic Shop redesign, production checkpoint placement, unrelated save rewrite or additional menus belongs to this scope.

## Cloud acceptance

All Godot/PowerShell execution stays in GitHub Actions. Reuse existing reading, Settings, Gallery, native compiler, rendering and input suites.

1. Preference tuple: dual on/off, changing either locale, swapping, restart persistence and same-locale prevention. Verify actual rendering, not only stored values.
2. Native reading: correct pairing with different word order/length/wrapping, repeated identical prose with different IDs, variant branches, self-talk and choices. One choice activation and one progression event.
3. Live geometry: current caption pair only; latest thought pair retention/clear; older paired scrollback; single-language behavior restored on toggle. Test all supported text sizes, relevant font families, large targets and representative locale combinations.
4. Timing/input: both texts reveal under one gate; Advance, Auto, Skip, computer hold, Settings return and pixel dissolve preserve existing custody. Reconfiguration mid-reveal does not duplicate speech/history or advance.
5. Persistence: Save/Load restores the same beat and choices using current language preferences, without duplicate witnesses or new library discovery. New runs/old saves preserve Global library membership.
6. History/library: encountered-only paired text, exact variant isolation, separate library reset, unread placeholder with no translation leak, all conditions still visible in UI language, no gameplay writes from browsing.
7. Missing translations: Secondary absent yields Primary only; missing Primary follows documented source fallback; no duplicated fallback row. No false complete-translation claims.
8. Accessibility: correct reading order and locale metadata, one choice focus stop, Primary-only Read Aloud, no hidden Secondary speech, keyboard/controller navigation and no clipped text/control overlap. Inspect rendered screenshots, including long samples and library pages.
9. Authoring/export: stable identity joins, updated text after cloud export/fresh process, stale generated output detected by existing checks; no runtime source scan.
10. Retain applicable public contracts, inventories and Windows exported-startup checks. Record exact candidate SHA, accepted run and source/screenshot evidence.

## CI turnaround

Carry forward the owner's guidance:
> Measure and reduce repository-download overhead, especially for the coverage-selection job.
> Group a few short, related suites so they share setup while keeping their test data isolated.
> Select narrower coverage for visual-only changes, retaining the relevant layout, input, transition and accessibility checks.
> Review unnecessary job dependencies so independent work can start earlier.

PR #149 already introduced blobless sparse coverage-selection checkout; preserve and measure the current baseline rather than repeating that work blindly. Keep suite profiles/temp data isolated when sharing setup. The initial bilingual feature changes content projection and reading semantics: it is not visual-only. Retain relevant identity, persistence, compiler, Profile, input and speech coverage alongside layout/accessibility/transition checks. Record measured checkout/setup/test/wait durations; do not infer speedup from fewer jobs alone.

## Next session sequence

Inspect existing translation/content owners and real translation availability; choose the minimal stable-identity adapter. Implement preference-driven projection, then live pairs and choices, then History/library integration. Verify cloud behavior and screenshots before marking complete. Update the feature plan and this handoff with exact evidence and remaining translation coverage. No further owner interview is required for the choices settled above; ask only if source inspection reveals a material design conflict.
