# Lawful-Universe Design Atlas Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and browser-verify one disposable, dependency-free HTML design atlas covering every approved player-facing surface except dedicated Schedule, universal Pause, and Minesweeper demonstrations.

**Architecture:** One self-contained full HTML document provides a visibly non-diegetic atlas shell around one uniformly scaled 1280-by-720 game specimen. Immutable fixture data selects deterministic projections; module renderers own only demo-local state and semantic interaction, while presentation settings apply through host-aware tokens. All files remain in the gitignored visual-companion session and no Godot code, save data, profile data, or game authority changes.

**Tech Stack:** Semantic HTML5, CSS custom properties and Grid/Flexbox, vanilla JavaScript, visual-companion localhost server, PowerShell structural checks, isolated Chromium/Edge browser inspection.

## Global Constraints

- Normative source: `docs/superpowers/specs/2026-08-13-lawful-universe-design-atlas-prototype.md` plus its accepted `docs/design/` authorities.
- Prototype target: `.superpowers/brainstorm/2376-1786631199/content/lawful-universe-design-atlas-01.html`.
- Provisional lineup source: `.superpowers/brainstorm/2376-1786631199/content/character-lineup-study-01.png`; it appears only in Art Production.
- Single dependency-free full HTML document; no package, framework, network request, browser storage, service worker, or real game API.
- Exact logical game specimen: 1280 by 720; uniformly scaled and centred; never internally responsive.
- Dedicated Schedule, universal Pause, and Minesweeper modules are forbidden. Schedule and Minesweeper launcher tiles remain truthful normal-looking tiles.
- Curator/debug labels live outside the game specimen. No raw ID, fixture name, mechanic label, or prototype notice leaks into player-facing copy.
- Palette proof is host-aware: title uses pending next-run intent; in-run uses captured run configuration; production artwork is never recoloured.
- Text sizes 100/125/150, target sizes 48/64, Standard/High Contrast, Standard/Protan/Deutan/Tritan, Primary/Dual, and Standard/Reduced Motion are inspectable where applicable.
- Real controls use semantic HTML and visible keyboard focus; modal fixtures use native or equivalent dialog semantics, Cancel/No initial focus, focus trap, inert background, and exact source-focus restoration.
- Prose inside game specimens is visibly plausible layout copy but noncanonical; it must not disclose hidden mechanics or create new canon.
- No Godot source, resource, test, Beads record, localization catalogue, save schema, or accepted design document is changed by implementation.

---

### Task 1: Standalone Atlas Foundation and Structural Guard

**Files:**
- Create: `.superpowers/brainstorm/2376-1786631199/content/lawful-universe-design-atlas-01.html`
- Create: `.superpowers/brainstorm/2376-1786631199/state/atlas-structural-check.ps1`

**Interfaces:**
- Produces: `window.DesignAtlas`, `FIXTURES`, `MODULES`, `setModule(moduleId, fixtureId)`, `setPresentation(patch)`, `dispatch(intent, payload)`, `renderAtlas()`, and stable DOM IDs `atlas-nav`, `atlas-stage`, `game-canvas`, `specimen-tray`, `atlas-live-status`.
- Consumes: no runtime dependencies; the accepted specification only.

- [ ] **Step 1: Write the failing structural check**

Create a PowerShell check that loads the target HTML as raw text and fails unless it contains:

```powershell
$atlasPath = Join-Path $PSScriptRoot '..\content\lawful-universe-design-atlas-01.html'
$html = Get-Content -Raw -LiteralPath $atlasPath
$required = @(
  '<!doctype html>',
  'id="atlas-nav"',
  'id="atlas-stage"',
  'id="game-canvas"',
  'id="specimen-tray"',
  'DESIGN ATLAS — NON-SHIPPING PROTOTYPE',
  'window.DesignAtlas'
)
foreach ($needle in $required) {
  if (-not $html.Contains($needle)) { throw "Missing structural marker: $needle" }
}
if ($html -match '<script[^>]+src=' -or $html -match '<link[^>]+href=') {
  throw 'Atlas must not load external scripts or stylesheets.'
}
```

- [ ] **Step 2: Run the structural check and confirm RED**

Run:

```powershell
& '.superpowers/brainstorm/2376-1786631199/state/atlas-structural-check.ps1'
```

Expected: failure because the target HTML does not exist.

- [ ] **Step 3: Create the minimal full HTML document**

Build the document with:

- correct doctype, charset, viewport, title, and no external assets except the local lineup image used later;
- an outer `.atlas-shell` containing nav, stage, and specimen tray;
- a fixed-size `#game-canvas` transformed only by one computed uniform scale;
- a deterministic default state: Title/Fresh, 100, 48, Standard contrast/colour, Primary, Standard motion;
- module and presentation registries with no game-domain mutation verbs; and
- a resize handler using `ResizeObserver` that updates only the scale variable.

Use this state boundary:

```js
const DEFAULT_ATLAS_STATE = Object.freeze({
  module: 'title', fixture: 'fresh', text: 100, targets: 48,
  contrast: 'standard', colour: 'standard', language: 'primary',
  motion: 'standard', annotations: false, presentationMode: false
});
```

- [ ] **Step 4: Implement outer navigation and tray basics**

Add exact module groups and controls from the specification. Render module and fixture buttons with `aria-current`/`aria-pressed`; update URL hash using only allowlisted values; malformed hashes return to defaults. `Presentation mode` hides outer chrome but retains an inside-stage `Return to atlas controls` button whose only purpose is exiting the prototype mode.

- [ ] **Step 5: Run structural check and syntax smoke**

Run the structural PowerShell check. Then extract the inline JavaScript text with a short read-only PowerShell match and run it through the installed browser later; at this stage manually verify brace balance by loading the HTML through the visual-companion server.

Expected: structural check passes; page displays outer atlas and one empty 1280-by-720 specimen without console syntax errors.

### Task 2: Shared Visual System, Canvas Hosts, and Accessibility Primitives

**Files:**
- Modify: `.superpowers/brainstorm/2376-1786631199/content/lawful-universe-design-atlas-01.html`
- Modify: `.superpowers/brainstorm/2376-1786631199/state/atlas-structural-check.ps1`

**Interfaces:**
- Consumes: Task 1 `window.DesignAtlas` and DOM anchors.
- Produces: `renderTitleShell(content)`, `renderDesktopShell(content)`, `renderThreeBandHost(model)`, `openDemoDialog(model, sourceEl)`, `closeDemoDialog()`, `announce(message)`, `applyPresentationTokens()`, `prototypeFigure(characterId, variant)`, and shared CSS component classes.

- [ ] **Step 1: Extend structural checks for shared hosts**

Require marker strings for `renderTitleShell`, `renderDesktopShell`, `renderThreeBandHost`, `openDemoDialog`, `--logical-scale`, `--target-min`, `data-host-kind`, and `aria-label="Game design specimen"`. Reject strings associated with forbidden aesthetics: `scanline`, `glitch`, and external font URLs.

- [ ] **Step 2: Run RED**

Expected: missing shared-host marker failure.

- [ ] **Step 3: Implement provisional design tokens**

Define square geometry, one-pixel seams, institutional cream, soot, green-grey, faded blue, bruised lavender, rust, tabular figures, static dither on inactive planes, and clear double-boundary focus. Avoid glass blur, neon, rounded-card systems, moving grain, and global art filters.

Implement token tuples for contrast and four colour differentiation modes. High Contrast and colour modes change functional UI tokens only. Text size changes a `--text-scale` value; target size changes `--target-min` between 48px and 64px.

- [ ] **Step 4: Implement exact shared host geometry**

- Title: 320 ledger / 960 workfield, 64 workfield strip.
- Desktop: 480 Angela / 800 computer, 64 computer strip.
- Three-band: 104 portrait register / 344 tableau / 272 deck, with caption deck expanding upward at 125/150 while tableau never falls below 224.

Add optional annotation overlays outside normal focus order. Annotations name logical rectangles only when curator annotations are enabled.

- [ ] **Step 5: Implement figures and modal/focus primitives**

Create CSS-only third-person figure studies for Angela, Priscilla, Lavinia, and Sylvia based on approved silhouette direction, without final faces, hair details, complexion, or accent swatches. Implement modal source focus capture, Cancel/No first focus, Tab trap, background inertness, Escape/Back cancellation, and restoration.

- [ ] **Step 6: Run structural and manual keyboard smoke**

Expected: checks pass; Tab never enters hidden outer controls in presentation mode; focus outline is visible; modal opens, traps, and restores focus.

### Task 3: Title, Desktop, and Angela Workstation Modules

**Files:**
- Modify: `.superpowers/brainstorm/2376-1786631199/content/lawful-universe-design-atlas-01.html`
- Modify: `.superpowers/brainstorm/2376-1786631199/state/atlas-structural-check.ps1`

**Interfaces:**
- Consumes: shared title/desktop hosts and modal primitive.
- Produces: `renderTitleModule`, `renderDesktopModule`, exact Title/Desktop fixture catalogues, and safe launcher routing to included app modules.

- [ ] **Step 1: Add RED checks for workstation fixtures**

Require fixture IDs `fresh`, `entitled_off`, `entitled_on`, `login_hosted`, `settings_hosted`, `gallery_hosted`, `new_acc_confirm`, `shutdown_confirm`, `launcher_light`, `launcher_keepsakes`, `launcher_dark`, `condition_hud`, `self_talk`, `dark_refusal`, `contacts_toast`, `quick_saved`, and `logout_confirm`. Require all seven launcher labels and reject an eighth label.

- [ ] **Step 2: Implement Title fixtures**

Render exact ledger order and absence law. Fresh has New Acc focus and a truly blank workfield. Entitled fixtures insert Dark directly below New Acc. Hosted fixtures reuse later module renderers in embedded mode. New Acc and Shut Down confirmations use the shared modal.

Host-aware palette rule:

```js
function effectivePalette(moduleId, fixture) {
  if (fixture.host === 'title') return fixture.pendingDark ? 'dark' : 'light';
  if (fixture.host === 'run') return fixture.capturedDark ? 'dark' : 'light';
  return 'unaffected';
}
```

- [ ] **Step 3: Implement Angela panel and launcher fixtures**

Build exact 216/317/187 baseline regions; at larger text, functional HUD/self-talk takes space from the tableau. Render only visible Day, display-clamped Pressure, Health, Motivation, money, coins, and optional condition/penalty. Keepsakes are static and noninteractive. Self-talk supports ordinary single-language three-beat and Dual current-only presentation.

Render launcher row-major 4+3 with an empty nonfocusable eighth slot. Included apps route to their atlas modules. Minesweeper/Schedule activation leaves the canvas unchanged and writes an outer atlas live status that a dedicated demo already covers the surface.

- [ ] **Step 4: Implement toast/status/Logout fixture interactions**

Toast Go selects Contacts and X dismisses locally; it never steals focus automatically. Quick Saved is a quiet edge status. Logout is a Cancel-first modal. Confirmations and toasts remain within accepted safe regions.

- [ ] **Step 5: Verify workstation checks and focus**

Expected: exact geometry and order; no Dark row in Fresh; no content in blank title field; fresh launcher focus Minesweeper; one click on included app opens it; omitted app activation changes only outer live status.

### Task 4: Contacts and Shop Modules

**Files:**
- Modify: `.superpowers/brainstorm/2376-1786631199/content/lawful-universe-design-atlas-01.html`
- Modify: `.superpowers/brainstorm/2376-1786631199/state/atlas-structural-check.ps1`

**Interfaces:**
- Consumes: Desktop host, figures/art placeholders, dialogs, presentation tokens.
- Produces: `renderContactsModule`, `renderShopModule`, Contacts/Shop fixtures, and demo-local intents for thread selection, reply, page/card/quantity selection, and modal confirmation.

- [ ] **Step 1: Add RED checks for Contacts/Shop invariants**

Require exact roster and Contacts fixture IDs; exact Shop pages, quantity labels, Supportz state IDs, and `$45`. Reject `typing`, `composer`, `Send message`, `unread count`, and visible `Supportz` inside game-surface markup/data copy intended for the blank card.

- [ ] **Step 2: Implement Contacts**

Build fixed 31/69 split, bare list state, binary unread evidence, oldest-new divider, ordinary paper slips, inline A/B/C reply, linked P/L literal sender labels, withheld arrival, Day-2 same-minute beats, absolute midnight erasure, and Dual slip. Focus/hover never reads; deliberate activation does.

- [ ] **Step 3: Implement Shop catalogue and inspector**

Build exact two 3-by-3 pages inside 3/5 catalog and 2/5 inspector. Use literal CSS object marks for seventeen visible products. Implement page and selected-card state, batch quantity bounds, single/sold-out projection, refusal lines, and optional double-click confirmation.

- [ ] **Step 4: Implement Supportz and local purchase projection**

Keep page-one slot nine blank in both states. Eligible blank receives normal focus and the neutral assistive name only. Activation opens price-only `$45 / No / Yes`; Yes makes it inert and focuses Spa Coupon. Demo purchases alter only cloned local balances/stock and optional shell keepsake projection.

- [ ] **Step 5: Verify Contacts/Shop checks and interactions**

Expected: no modern chat artifacts; no Supportz identity leak; quantity controls remain 48/64; confirmations begin No; page/card positions remain stable at 100/125/150.

### Task 5: Backup and Settings Modules

**Files:**
- Modify: `.superpowers/brainstorm/2376-1786631199/content/lawful-universe-design-atlas-01.html`
- Modify: `.superpowers/brainstorm/2376-1786631199/state/atlas-structural-check.ps1`

**Interfaces:**
- Consumes: Title/Desktop host selection, modal primitives, presentation tokens.
- Produces: `renderBackupModule`, `renderSettingsModule`, embedded host modes, fixture catalogues, and safe local settings interactions.

- [ ] **Step 1: Add RED checks for exact cabinet and Settings rail**

Require nine drawer labels in exact order and seven Settings categories in exact order. Require `title_load_only`, fallback/unavailable/save/delete fixture IDs, and representative Settings control IDs. Reject `Dark Mode` inside Settings module markup.

- [ ] **Step 2: Implement Backup**

Build stable 3/5 cabinet and 2/5 inspector, semantic selection separate from focus, in-run Save/Load and title Load-only modes, record states, Autosave disabled Save reason, Cancel-first confirmations, static busy/success fixtures, and Delete retaining selected Empty drawer.

- [ ] **Step 3: Implement Settings rail and core pages**

Implement Language, Reading, Audio, Display, Controls, Accessibility, Records. Use one shared surface for title/run. Provide the required representative controls and immediate local projection. Samples are one-at-a-time; Test becomes Stop. TTS unavailable remains truthful.

- [ ] **Step 4: Implement accessibility specimen and reset/conflict modals**

Show permanent focus/selected/warning/unavailable specimen with non-colour evidence; Reduced Motion disables but remembers shake; colour differentiation and contrast affect functional tokens. Binding conflict and Records reset use source-restoring Cancel-first dialogs. Entire Profile Reset exists only in the title fixture.

- [ ] **Step 5: Verify Backup/Settings checks and embedded reuse**

Expected: title Log in and run Backup are one renderer with mode data; title/run Settings is one renderer; no Dark setting; keyboard category navigation and dialogs work; long labels locally scroll rather than changing topology.

### Task 6: Gallery/Rehearsal Archive Module

**Files:**
- Modify: `.superpowers/brainstorm/2376-1786631199/content/lawful-universe-design-atlas-01.html`
- Modify: `.superpowers/brainstorm/2376-1786631199/state/atlas-structural-check.ps1`

**Interfaces:**
- Consumes: Title host, local index/detail scroll, modal primitive.
- Produces: `renderArchiveModule`, archive fixtures, mode/index/detail selection, witnessed-version chooser, and archive-to-Narrative specimen route.

- [ ] **Step 1: Add RED checks for archive absence and geometry**

Require `empty_endings`, `archive_unlocked`, `ending_detail`, `versions`, `rehearsal_scenes`, `rehearsal_dates`, and `history_added`. Require mode/body widths 344 and 568 markers. Reject lock, percentage, denominator, search, and unseen placeholder strings from game copy.

- [ ] **Step 2: Implement empty/unlocked Endings**

Empty Endings has one quiet factual record and no Rehearsal tab/node. Unlocked state has exact mode order, discovered-only chronology, selected record desk, optional collapsing media, one authored nonmechanical sentence, conditional witnessed versions, and Replay.

- [ ] **Step 3: Implement Rehearsal projections**

Render Scenes/Full Dates only when nonempty, meaningful facets without counts/empty choices, exact record detail, and Begin Rehearsal. Begin a Scene by routing to Narrative archive-replay fixture. Full Date produces an outer atlas note pointing to the separate Minesweeper demo and leaves the archive canvas truthful.

- [ ] **Step 4: Implement return status and focus restoration**

Return from a specimen restores the exact archive card/action. `New dialogue added to History` is quiet status only; no counter or progress.

- [ ] **Step 5: Verify archive absence, focus, and text scaling**

Expected: unseen content creates no DOM/focus/scroll footprint; mode and registrar geometry remain fixed; selected/focused states differ; 150% uses local scroll.

### Task 7: Narrative, Hospital, and Ending Modules

**Files:**
- Modify: `.superpowers/brainstorm/2376-1786631199/content/lawful-universe-design-atlas-01.html`
- Modify: `.superpowers/brainstorm/2376-1786631199/state/atlas-structural-check.ps1`

**Interfaces:**
- Consumes: three-band host, provisional figures, dialogs, archive return route.
- Produces: `renderNarrativeModule`, `renderHospitalModule`, `renderEndingModule`, transport demo-local state, History sheet, choice projection, reveal/Accept behavior, and ending fixture transitions.

- [ ] **Step 1: Add RED checks for three-band and rail laws**

Require exact rail order `History`, `Skip`, `Auto`, `Save`, `Load`, `Next`; two-/multi-person/nonverbal/dual/choice/history/replay fixtures; Hospital boardless fixture; Ending ordinary/hold/seam/closing/matte/title fixtures. Reject `Credits`, `Ending achieved`, `Continue`, offscreen speaker labels, and challenge-board markup in these modules.

- [ ] **Step 2: Implement Narrative physical staging**

Render exact present participants in both portrait register and tableau, stable left/centre/right authored marks, active-speaker frame cues, nonverbal no-speaker state, single current+two prior caption cards, Dual current-only card, and third-person Angela.

- [ ] **Step 3: Implement transport and History specimens**

Normal Accept completes a partial reveal, then advances on the next activation. Inline choices suspend transport. Auto/Skip/Next are mutually exclusive local projection. Next advances only within fixture witnessed beats and stops at a boundary. History is a full-canvas inspect-only sheet with source focus restoration. Archive replay removes Save/Load controls rather than disabling them.

- [ ] **Step 4: Implement Hospital**

Reuse identical three-band renderer and rail in a boardless treatment-room fixture. Use ordinary university welfare/treatment props and no diagnosis, nurse coding, board cavity, or countdown.

- [ ] **Step 5: Implement Ending sequence fixtures**

Reuse three-band renderer. Provide ordinary beat, later ordered step with continuous History, inert final-shot hold, wordless automatic seam, closing image, textless matte, and exact title landing. Controls are absent/inert as specified; no credits/title/badge/summary/Continue.

- [ ] **Step 6: Verify three-band geometry, presence parity, and transport**

Expected: every speaker is physically present; speaker changes do not shuffle; caption deck expands upward; one Accept equals one semantic action; archive replay lacks Save/Load; Hospital lacks board; Ending sequence never shows forbidden completion UI.

### Task 8: Art Production Module and Atlas Completion Pass

**Files:**
- Modify: `.superpowers/brainstorm/2376-1786631199/content/lawful-universe-design-atlas-01.html`
- Modify: `.superpowers/brainstorm/2376-1786631199/state/atlas-structural-check.ps1`

**Interfaces:**
- Consumes: local lineup PNG and accepted art placement guide.
- Produces: `renderArtProductionModule`, placement diagram, final module coverage guard, and complete atlas HTML.

- [ ] **Step 1: Add RED checks for art boundary and complete module set**

Require the local lineup path, `Faces / hair / accents — next refinement`, source/export/manifest/presenter labels, and every exact module ID. Reject use of the lineup path inside any game-surface renderer fixture data.

- [ ] **Step 2: Implement Quartet Study**

Show the approved lineup plate with the old outfit-warning language removed. Label relative silhouettes/outfits approved and faces/hair/complexion/heritage/accent swatches next. This plate replaces the game stage as an explicitly curator-owned production surface.

- [ ] **Step 3: Implement Placement Map**

Show source master → checked export → semantic manifest → presenter, followed by safe usage cards for Angela shell, portraits, bodies, Contacts, Schedule folios, Gallery/Rehearsal, Hospital/Endings, and negative placements. Mentioning Schedule here is an art-consumer reference, not a dedicated Schedule UI module.

- [ ] **Step 4: Implement reset, hash, error, and presentation-mode completion**

Reset clones the current fixture default. Hash parsing is allowlisted and resilient. Unknown renderers preserve the last valid specimen and show an outer curator error. Presentation mode is reversible and keyboard accessible.

- [ ] **Step 5: Run complete structural check**

Expected: all module/fixture/forbidden-string/asset-boundary checks pass.

### Task 9: Real-Browser Verification and Evidence

**Files:**
- Verify: `.superpowers/brainstorm/2376-1786631199/content/lawful-universe-design-atlas-01.html`
- Modify: `.superpowers/brainstorm/2376-1786631199/state/atlas-structural-check.ps1`
- Create: `.superpowers/brainstorm/2376-1786631199/state/atlas-verification.md`
- Create: screenshots under `.superpowers/brainstorm/2376-1786631199/state/atlas-evidence/`

**Interfaces:**
- Consumes: completed atlas and active visual-companion server URL.
- Produces: browser evidence matrix, screenshots, clean-console result, keyboard/a11y observations, and final demo URL.

- [ ] **Step 1: Verify server and atlas response**

Read `.superpowers/brainstorm/2376-1786631199/state/server-info`, confirm no `server-stopped`, request the keyed URL, and require HTTP 200. If stopped, restart the same project/session through the visual-companion script so the port remains stable.

- [ ] **Step 2: Inspect default page in isolated browser**

At 1920×1080, verify Title/Fresh, blank workfield, New Acc focus, correct atlas/game landmark separation, no console errors/warnings, and no external requests.

- [ ] **Step 3: Exercise every module and representative fixture**

Capture screenshots for Title, Desktop, Contacts, Shop, Backup, Settings, Gallery/Rehearsal, two-person Narrative, multi-person Narrative, Hospital, Ending final hold/landing, Quartet Study, and Placement Map. Record module/fixture name, viewport, presentation tuple, and observation in `atlas-verification.md`.

- [ ] **Step 4: Exercise cross-cutting presentation matrix**

At minimum test:

- 100/48/Primary/Standard on every module;
- 150/64/Dual/High Contrast on Contacts, Settings, Archive, Narrative;
- captured Dark only on Desktop/app specimens;
- pending Dark only on Entitled — On Title;
- Protan/Deutan/Tritan on representative functional-state specimens; and
- Reduced Motion on Narrative/Ending transition specimens.

Assert no macro reflow, clipping, horizontal text scroll, art recolour, or colour-only state.

- [ ] **Step 5: Exercise input and modal behavior**

Keyboard-navigate atlas and specimen; test an ordinary modal, Backup confirmation, Settings conflict, and Supportz modal. Confirm Cancel/No initial focus, focus trap, inert background, Escape cancellation, and exact source restoration. Confirm presentation mode can be exited without pointer.

- [ ] **Step 6: Exercise viewport matrix**

Verify 1440×900, 1280×720, and one non-16:9 browser window in addition to 1920×1080. Confirm uniform game-canvas scaling and no internal topology reflow.

- [ ] **Step 7: Final checks and handoff**

Run structural checks one last time. Record SHA-256, HTTP status, console result, screenshot list, known prototype-only limitations, and the exact keyed localhost URL. Confirm `git status` shows no implementation change outside the approved spec/plan and gitignored `.superpowers` prototype evidence.

Expected: all evidence passes; user can inspect the full atlas from one live browser link.
