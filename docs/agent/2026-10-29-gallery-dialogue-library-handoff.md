# Gallery dialogue library handoff

Date: 29 October 2026, Hong Kong.
Status: next implementation target; documentation only. Fixed placeholder approved; ready for implementation planning.
Reviewed master: `5a065a155b573d2a8502f2c9c84bb97547d7bba2`.

## Scope and settled owner decisions

Build a read-only dialogue library inside Gallery, reached from the title screen. Reuse the existing Gallery shell, localization, typography, focus and Return behavior. Do not create a replay mode or a second story execution path. Existing Gallery Records, Artwork, replay and rehearsal are separate features and must remain intact.

- Discoveries are Global/profile facts: loading an older save and starting another playthrough do not erase them.
- A passage is a named presentation checkpoint containing its variants.
- List only reached checkpoints. Within them show unlocked dialogue and masked unread variants.
- Include encountered self-talk alongside its paired caption in reading order, visually distinguished. Do not expose an unseen thought merely because its caption is known.
- Describe conditions through the actions/consequences of choices and Challenge results. Map authored labels to localized descriptions, not raw internal IDs.
- Show **all requirements**, including requirements the player has not encountered. This deliberate hint disclosure is approved; dialogue wording remains masked until read.
- Multiple prerequisites must all appear. Preserve actual AND/OR relationships: do not flatten alternatives into false conjunctions.
- Build/test with sample checkpoints; production checkpoint placement remains deferred. Do not insert demonstration passages into the shipped story or classify production prose without authoring approval.
- **Separate library reset**, selected October 29. New runs, old-save Load and ordinary read-history reset must not silently erase library discoveries. Provide a deliberate library-only reset through the existing reset conventions; it must not clear Skip read history, saves, Artwork or ending records.
- Treat this as an unshipped game. Do not add migration/version-history machinery for future dialogue rewrites. Reuse existing content identity rules where possible; this is not permission to reset player data or weaken existing validation.
- Browsing and inspecting conditions must not mark anything read, advance story, unlock variants, replay DTL or mutate run state. Explicit library reset is the sole intended library write action.

## Approved unread placeholder

Owner selected the fixed placeholder on October 29. Each unread entry uses the same compact, localized placeholder, independent of the hidden dialogue's length or wrapping. Do not render text-shaped bars or reserve space based on hidden text. “Unread dialogue” is suitable default UI copy; exact localization is an implementation detail.

Condition descriptions remain visible and accessible beneath the placeholder, showing all required choice actions/consequences and Challenge results. Hidden dialogue must not leak through accessibility names, tooltips, search or copy. Check that short and long unread source text produce the same placeholder treatment.

No further owner design answer is currently required for the sample-first implementation. Ask only if inspection reveals a material conflict with the settled behavior.

## Source-grounded implementation starting points

At the reviewed revision:
- `scripts/ui/GalleryScene.gd` already has Records and Artwork tabs plus retained replay/rehearsal owners. Its tab selection currently uses a boolean for Artwork. Extend only as needed for a third Dialogue tab; do not treat an old gallery design document as current implementation truth.
- `autoload/ProfileManager.gd` has visited-history and exact caption-variant witness signals and profile reset/restore notifications.
- `scripts/profile/CaptionWitnessLedger.gd` describes and validates exact registered beats using `scripts/narrative/NarrativeCaptionRegistry.gd`. An existing stable line ID alone is not necessarily an exact variant identity.
- [Named checkpoint implementation](../../handoff/as-named-checkpoint-implementation-20261027.md) records the existing presentation manifest maps and registered-entry bindings. Runtime checkpoint arrival is not the same as persistence of Global library discovery.
- [Current feature plan](2026-10-28-current-and-future-feature-plan.md) owns disposition and earlier decisions.

Read AGENTS.md, CLAUDE.md and relevant owners before editing. Read story guidance before any narrative authoring; synthetic test data does not authorize production prose.

Trace the actual accepted-visible reading publication path, variant witness owner and reset semantics before deciding storage. Reuse identities and the profile persistence boundary. Independent library reset requires independently clearable discovery membership: a pure live projection of an uncleared read ledger would immediately repopulate after reset. Use the smallest explicit profile-owned membership necessary, not a parallel save journal. After a library reset, new actual reading can rediscover entries; merely reopening the library cannot.

Checkpoint reach, exact line/variant read, and condition satisfaction are distinct facts. A satisfied condition does not prove a line was read. Existing read evidence should not be guessed into an unrecorded checkpoint arrival. For this unshipped/sample-first slice, do not fabricate historic discoveries or implement speculative backfill.

Use a small authored catalogue binding named checkpoint IDs, ordered variant/line identities, caption/self-talk relationships and condition label references. Prefer existing registration/compiler boundaries. Validate sample bindings there, not through repeated full-catalogue scans while scrolling. Conditions are authored descriptions of real branching rules, not a second evaluator that executes game choices. Show “unknown/unavailable condition” safely if needed during authoring; never invent a requirement from a label's spelling.

Recommended first presentation: Dialogue tab, reached checkpoint index, readable passage with paired thoughts and variant requirements. Preserve authored order. Do not add search, filtering, completion percentages, bookmarks, export, audio or playback without a new requirement.

## Implementation stages

1. Inspect existing Gallery/Profile/reading owners and reset behavior; apply the approved fixed placeholder.
2. Add the minimal sample catalogue and independently resettable Global library discovery using the accepted reading publication path.
3. Add read-only Gallery rendering and explicit library reset, preserving existing tabs and navigation.
4. Validate cloud persistence, input, accessibility and rendering; update this record with tested SHA, PR and accepted evidence. Production authoring is a later task.

## Acceptance

Run Godot and PowerShell only in GitHub Actions.

- Fresh profile: no unreached checkpoint title, unread dialogue text or phantom unlock.
- Reach a sample checkpoint and actually read one branch; its read caption/self-talk appear and other variants stay masked with all action/consequence requirements.
- Include combined earlier choice + Challenge requirement, alternatives, and a caption whose thought is not yet witnessed. Verify exact variant membership, not just same line ID.
- Restart the process, load an older save and begin another run: existing library discovery remains.
- Browsing, scrolling, opening/closing and viewing requirements leave run data, read marks, library membership and saves unchanged.
- Separate library reset clears only library discoveries and refreshes visible/cached views. Old read history does not instantly refill it. Re-reading can discover again. Existing Gallery/read-history resets remain correctly scoped.
- Gallery tabs, Return, keyboard/controller navigation, focus, large text, localization and screen-reader labels work. Unread content stays hidden in all UI/accessibility paths.
- Do not execute replay, trigger a Challenge, start a transition or write a gameplay save by opening the library. Keep relevant existing input/transition regression coverage.
- Sample catalogues stay out of production story registration. Demonstrate empty production catalogue behavior honestly; sample acceptance is not production authoring completion.

## CI efficiency guidance supplied by the owner

> Measure and reduce repository-download overhead, especially for the coverage-selection job.
> Group a few short, related suites so they share setup while keeping their test data isolated.
> Select narrower coverage for visual-only changes, retaining the relevant layout, input, transition and accessibility checks.
> Review unnecessary job dependencies so independent work can start earlier.

Measure checkout/download, setup, test and queue/wait costs separately before and after against comparable runs. Check what history/files coverage selection actually needs before narrowing its fetch. Do not break diff bases, required assets, submodules or export inputs to reduce bytes. Group only related short suites; use distinct temporary directories/profiles and reset mutable process state so setup sharing does not share discoveries or saves. Remove only dependencies without required artifacts or correctness ordering.

The initial library implementation changes persistence and discovery semantics: it is **not visual-only**. Retain Profile/reset, exact witness and Save/Load checks as well as relevant Gallery layout/input/accessibility/transition checks. Record reduced wall time and runner time honestly; fewer jobs or lines alone do not prove improvement. Keep workflow optimization scoped and separately reviewable.

## Separate cosmetic follow-up

The owner reports that the three Shop item decorations look too simple and do not sufficiently express the intended code-drawn design. Catalogue, ownership and purchase caps are implemented; aesthetic acceptance is reopened. Do not call the visual result final or silently redesign it in the library work. Future polish should compare the intended glass highlights, silk boundary thread and wax-sealed letter with current code and screenshots, then agree a concrete visual direction. Procedural code remains possible; external art is not automatically required.
