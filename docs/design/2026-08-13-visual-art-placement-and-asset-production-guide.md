---
id: guide.visual_art_placement_and_asset_production
kind: production_guide
schema_version: 1
decision_status: accepted
conversational_design_status: approved
written_spec_status: approved
self_review_status: passed
self_reviewed_on: "2026-08-13"
written_spec_approved_on: "2026-08-13"
implementation_authorized: false
created_on: "2026-08-13"
engine_line: godot_4_6
verification_engine: 4.6.3-stable-mono
language: gdscript
scope: [visual_source_files, runtime_art_exports, semantic_art_manifests, character_art_consumers, environment_and_prop_consumers, crop_and_focal_rules, missing_art_policy, production_order]
---

# Visual-Art Placement and Asset-Production Guide

> **Owner decision, 2026-09-09: initial portrait scope:** Use one fixed portrait
> per solo scene and two fixed portraits per group or twofriends scene. Keep
> each selected image unchanged through that scene; expression, pose, attitude,
> relationship-tier, and challenge-result variants are not prerequisites.
> This bounded first implementation supersedes the larger portrait roster and
> expression-kit requirements below, including automatically adding Angela's
> portrait. It changes displayed art, not physical attendance, lawful character
> knowledge, scene branches, or the original scene-oriented DTL arrangement.
> Further portrait variations remain deferred; they require a later scoped
> decision and must not expand the current task.


## 1. Purpose and status

This guide tells the artist where an image will be used before the image is
painted. It maps editable source art to checked runtime exports, semantic asset
records, and final player-facing surfaces.

It records the approved visual foundation and first quartet silhouette
direction. It does not authorize runtime implementation, finalize character
heritage or faces, or create a scene-by-scene shot list. Exact art assets remain
subject to later visual approval.

The core production rule is:

> Paint one canonical source, export validated surface variants, and let every
> presenter request a semantic asset ID. Never duplicate an uncontrolled crop
> into each app.

## 2. Do not fit artwork to the current scaffolds

The checked-out project contains no production `res://art/` tree. The current
`ArtManifest` and `SafeImage` are no-op stubs. Most approved hosts are not yet
physically composed, and merely copying a PNG into the repository will not make
it appear.

The following legacy assumptions are not production contracts:

- `*_portrait.png`, `*_dating.png`, and `*_tiny.png` path inference;
- one monolithic `AngelaImage`;
- three generic left/centre/right dating zones;
- the 32-pixel Contacts and Schedule image placeholders;
- the four-column eleven-ending Gallery scaffold;
- standalone Hospital and Ending label/button scenes; and
- full-screen Opening, tutorial, menu, or generic dating illustrations.

Artwork should target the semantic placement map in this guide, not those
placeholder nodes or filenames.

## 3. Source, export, manifest, presenter

Art travels through four layers.

1. **Editable source** — layered Krita, PSD, or equivalent working files,
   turnarounds, model sheets, palettes, and uncropped compositions. These never
   load at runtime.
2. **Runtime export** — checked PNG or SVG assets under `res://art/`, with no
   localized words or transient presenter state baked into the pixels. Hover,
   focus, selection, disabled treatment, and Dark/accessibility palette values
   remain functional presentation. Explicitly declared semantic game-state
   glyphs—such as Flag, mine, explosion, incorrect flag, and the post-clear
   marked mine—are allowed because the visible state is the asset's purpose.
3. **Semantic manifest** — a validated record maps an asset ID to a path, size,
   pivot, named crop, focal region, requirement level, and fallback policy.
4. **Presenter** — the Shell, Contacts, Schedule, Narrative Host, Archive, Shop,
   or Minesweeper surface asks for the semantic ID and projects it into its
   owned region.

No presenter guesses a path from a character name, takes a runtime screenshot,
or invents an anonymous crop.

## 4. Recommended repository locations

The following is the target organization. Creating these directories is later
implementation work.

```text
art_source/                         # editor-only; protect with .gdignore
  model_sheets/
    quartet/
    angela/
    priscilla/
    lavinia/
    sylvia/
  characters/
  environments/
  narrative/
  ui/
  archive/

art/                                # res://art/ runtime exports only
  characters/
    angela/
      portraits/
      bodies/<wardrobe_id>/
      overlays/
      shell/
    priscilla/
      portraits/
      bodies/<wardrobe_id>/
      overlays/
    lavinia/
      portraits/
      bodies/<wardrobe_id>/
      overlays/
    sylvia/
      portraits/
      bodies/<wardrobe_id>/
      overlays/
  environments/<location_id>/
    depth/
    variants/
    objects/
  narrative/
    close_ins/<entry_id>/
    cgs/<entry_id>/
  shell/
    angela_alcove/
    keepsakes/
  ui/
    launcher/
    materials/
    backup/fingerprints/
  shop/items/
  schedule/folios/
  schedule/fallback/
  minesweeper/marks/
  archive/
    endings/<record_id>/
    scenes/<record_id>/
    full_dates/<record_id>/
```

Editable sources must not sit inside runtime folders. Godot should import only
the checked exports, not large layered documents or unused studies.

## 5. Character master kit

Each woman receives one canonical production kit:

- shared-scale neutral lineup reference;
- front, three-quarter, side, and back turnaround;
- purpose-drawn close portrait master;
- the six approved portrait functions: `base`, `attentive`, `pleased`,
  `guarded`, `strained`, and `exposed`;
- roughly four reusable posture functions, performed in her own body grammar;
- campus foundation wardrobe plus approved weather and role layers;
- hands, recurring objects, and consent-bearing action studies; and
- grayscale and small-crop readability proofs.

The four-pose/six-expression kit is a production baseline, not a hard ceiling.
An exact bodily action may require a bespoke atom. There are no Sweet, Dark,
Observer, Special, relationship-tier, or ending variants of a character model.

Model sheets and turnarounds are production reference only. They never appear
on the logged-out title or become Gallery rewards.

## 6. Character-art placement map

| Asset | Runtime placement | Reuse or bespoke | Key rule |
|---|---|---|---|
| Angela alcove body | Shell Angela tableau, `x=0..480`, baseline `y=216..533` | Dedicated shell poses derived from Angela's canonical model | Layer alcove, keepsakes, body, then hand/object atom; do not use one flattened `AngelaImage`. |
| Close portrait | Narrative and Ending portrait register, `(0,0,1280,104)` | Reusable canonical expression set | Purpose-drawn close portrait, not a blind body crop. Speaker emphasis belongs to the UI frame. |
| Full/three-quarter body | Narrative and Ending tableau, baseline `(0,104,1280,344)` | Reusable body/pose export placed by each shot | Shot manifest owns anchor, scale, z-order, wardrobe, and expression. Speaker changes never shuffle bodies. |
| Hand, prop, partial body | Narrative and Ending tableau | Generic when truly reusable; otherwise bespoke | Exact evidence and consent-bearing movement must remain readable. |
| Close-in or CG fragment | Temporarily replaces or overlays only the middle tableau | Shot-specific | Portrait register and caption deck remain. No first-person Angela framing. |
| Contacts row portrait | Contacts left friend row | Named derivative of neutral base portrait | Priscilla, Lavinia, and Sylvia only; no per-message avatars. |
| Contacts thread portrait | Open-thread header | Second named derivative of the same neutral portrait master | Never changes by mood, route, relationship, or unread state. |
| Schedule personal folio | Available, filled Docket, and Focused Folio | One interface-specific folio master with named compact/focused exports | Known person or participant art only; never a face crop pretending to be scene art. |
| Gallery or Rehearsal media | First optional block of the right Record Desk | Curated crop from an approved witnessed shot or bespoke object mark | Only after discovery/reach; never a runtime screenshot or unseen silhouette. |
| Ending portrait/body | Shared Narrative Host during ordered ending playback | Reuse canonical character kit | Ending-specific blocking, objects, and closing shot may be bespoke; never recolour a model to classify an ending. |
| Hospital portrait/body | Shared Narrative Host Hospital preset | Reuse canonical kit plus Hospital-specific props/shots | No nurse costume is inferred for Sylvia; participant manifest controls who is physically present. |

### 6.1 Where Angela does not appear

Angela has no Contacts friend-row portrait and no outgoing-message avatar. She
does not become title key art. A discovered archive still may contain her only
when the witnessed composition itself contains her.

### 6.2 Where Priscilla, Lavinia, and Sylvia recur

Their canonical face models support Contacts crops, Schedule folio masters,
narrative portraits and bodies, ending playback, and eligible archive media.
These are coordinated outputs, not copies of one small PNG.

## 7. Exact player-facing regions

### 7.1 Shell Angela panel

- Complete Angela panel: `(0,0,480,720)`.
- Quiet HUD: `(0,0,480,216)`.
- Baseline alcove tableau: `(0,216,480,317)`.
- Self-talk dock: `(0,533,480,187)`.

At 125% and 150% text, functional HUD and self-talk may consume tableau height.
The art must have a registered focal anchor around Angela's face, hands, and
active object. Do not assume the baseline 317-pixel height is always visible.

### 7.2 Narrative, Hospital, and ordered Endings

At 100% text:

- portrait register: `(0,0,1280,104)`;
- tableau: `(0,104,1280,344)`; and
- caption deck: `(0,448,1280,272)`.

At 125% or 150%, the tableau may shrink to 224 logical pixels. Every shot must
declare a large-text focal crop that keeps the essential physical action within
that band. A blind centre crop is forbidden.

Portrait-card widths vary with the manifest's one-, two-, three-, or four-person
layout and are not yet numerically fixed. Keep portrait masters large and
layered until those widths are sealed.

### 7.3 Contacts

Contacts uses the computer's `800 x 656` app body. Its master/detail split is
248 logical pixels for the left list and 552 for the thread. The accepted design
does not yet fix portrait dimensions.

Working recommendation, not product law:

- 64 x 64 logical row crop exported at 128 x 128; and
- 80 x 80 logical header crop exported at 160 x 160.

The portrait never carries unread, selected, or speaker state.

### 7.4 Schedule

Schedule's inner working rect is `(496,80,768,624)`: a 250-pixel Available
ledger, 12-pixel seam, and 506-pixel Docket. Optional art may appear in source,
overview, and Focused Folio projections, but exact art rectangles are not yet
fixed and art yields to complete text at larger presets.

Keep flexible masters. A provisional 128 x 128 compact export is safe for
testing, but the final Focused Folio export must wait for its art slot to be
visually sealed.

### 7.5 Gallery and Rehearsal

The title-hosted archive owns a 568-pixel-wide Record Desk. Optional media comes
first and collapses completely when absent. Its final aspect ratio and height
are not sealed.

Prepare art-only crops without captions or portrait-register UI. A provisional
maximum 1072-pixel-wide export supports a likely two-times presentation width,
but final media crops remain authored variants rather than automatic cover
crops.

## 8. Non-character placement map

| Family | Final use | Notes |
|---|---|---|
| Alcove environment layers | Behind Angela in the persistent shell tableau | Non-geographic work alcove; no residence claim. |
| Bookend, Metronome, Pocket Calculator | Three fixed alcove keepsake sockets | In-world renders are separate from Shop card renders. |
| Seven launcher icons | Minesweeper, Contacts, Schedule, Shop, Backup, Settings, Log out | Literal institutional icon family; no icon font. |
| Environment depth kits | Narrative/Hospital/Ending tableau | Back, middle, foreground, occupancy, weather/time, and evidence layers. |
| Shop object art | Shop card and inspector | Seventeen visible objects; Supportz has no object art, and its blank catalog card/inspector exposes no name or price. Its accepted `$45` confirmation price remains functional modal text, never artwork. |
| Schedule action folios | Training, Working, Rest | Object/action art, not character portraits; no effects or costs baked in. |
| Backup fingerprints | Autosave, Quick, and Slots 1–7 | Decorative logical-drawer identity only; never save state or age. |
| Minesweeper marks | Covered, revealed numbers, flag, mine, exploded/incorrect/marked terminal states | Crisp functional marks. No smile face, faux Windows skin, or image-based New Board. |
| Archive object marks | Optional discovered record media | No undiscovered placeholders or counts. |

## 9. Negative placement list

Do not produce art for any of the following:

- a title-screen cast lineup, logo hero, or Angela splash in the empty workfield;
- Opening or tutorial scenes;
- dedicated Pause poses or Pause illustrations—the overlay freezes the current
  source image;
- per-message Contacts avatars;
- Dark, Sweet, Observer, Special, affection, tier, or danger costume variants;
- global Dark/contrast/colour-vision recolours of character or background art;
- a generic ending title card, ending badge, quote card, credits image, or Return
  illustration;
- a Supportz Shop image;
- a Minesweeper smile face, seven-segment timer, or nostalgic Windows clone;
- unseen Gallery silhouettes, locks, question marks, or collectible line art;
- clinician or nurse coding for Sylvia;
- a permanent brace, cane, or anatomically specific injury marker for Lavinia;
  or
- apartment-key couple coding or matched Priscilla–Lavinia outfits that expose
  their concealed history.

## 10. Semantic manifest contract

Every non-narrative art record should declare at least:

```text
asset_id
kind
path
native_pixel_size
logical_reference_size
pivot_or_baseline
named_crops
focal_rects_by_text_preset
required_or_optional
fallback_asset_id_or_omit_policy
palette_policy = artwork_unaltered | semantic_token_remappable
```

Example IDs:

```text
character.portrait.angela.base
character.portrait.priscilla.guarded
character.body.lavinia.open_week.receiving
character.overlay.sylvia.volunteer_kit_offer
shell.alcove.background.base
shell.keepsake.metronome
schedule.folio.action.training
schedule.folio.date.priscilla_lavinia
archive.ending.<record_id>.media
```

Narrative shots use a stricter closed presentation manifest:

```text
shot_id
background_asset_id
participant_records[
  character_id,
  body_asset_id,
  authored_anchor,
  z_order,
  portrait_expression_id
]
portrait_layout_id
tableau_crop_by_text_preset
object_close_in_or_cg_atoms
motion_policy
accessible_visual_description_id
```

Scenes consume detached presentation records. They do not infer art from
dialogue text, speaker identity, filenames, or relationship state.

`artwork_unaltered` applies to characters, backgrounds, props, keepsakes,
folios, Shop objects, and archive media. `semantic_token_remappable` applies
only to functional masks or glyphs whose accepted meaning must remain visible
under Dark, High Contrast, and colour-vision presets, including Minesweeper
state marks. A remappable asset carries semantic shape/state identity; it is not
a precoloured illustration that the presenter guesses how to transform.

## 11. Missing-art behavior

Fallback depends on the consumer:

- optional portrait expression -> that woman's declared base portrait;
- required narrative base portrait, body, shot layout, or background -> trusted
  technical failure before projection, never another woman or an anonymous
  speaker silhouette;
- Contacts row and thread-header portraits -> required identity art; a declared
  identity-safe neutral portrait may substitute only when it is the same woman's
  validated model, otherwise the Contacts surface enters trusted technical
  failure rather than showing a wrong or anonymous person;
- all seventeen visible Shop object renders -> required literal object art; a
  declared same-item neutral render may substitute, otherwise Shop enters
  trusted technical failure rather than showing a wrong item or an empty card;
- Minesweeper state marks -> required functional resources; missing covered,
  number, Flag, mine, exploded, incorrect-flag, or marked-mine evidence blocks
  that board projection through trusted technical failure rather than omitting
  or substituting an ambiguous state;
- optional Schedule art -> neutral registered paper/object mark while the
  mandatory localized name remains;
- optional Gallery/Rehearsal media -> omit the media block;
- missing shell tableau art -> safe inert fallback while functional HUD remains;
- missing owned keepsake art -> its stable generic silhouette; and
- missing decorative UI texture -> functional plain surface, never fake
  corruption.

Missing art never changes canon, mechanics, focus, save state, or eligibility.

## 12. Working export recommendations

These are engineering recommendations, not yet accepted visual law:

- author layered sources larger than their runtime exports;
- export painted character and environment art at two times logical scale;
- narrative tableau/background target: 2560 x 688 for the baseline 1280 x 344
  band, with an authored essential-action focal region fitting inside 2560 x
  448 for large text;
- shell alcove baseline target: 960 x 634, with Angela and the alcove background
  on separate layers;
- close portrait masters: at least 1024 x 1024 before purpose-exporting surface
  crops;
- UI icons and pixel-hinted functional marks: lossless, mipmaps off, nearest
  filtering;
- painted sprites and environments: lossless transparent PNG where practical,
  alpha-border correction, linear filtering, and generally no mipmaps on the
  fixed 2D canvas; and
- commit import settings, never `.godot/imported`.

### 12.1 Shop placement

Each visible Shop card is approximately `144 x 156` logical pixels and gives its
literal object render a 56-to-72-logical-pixel presentation range. The inspector
uses a larger 112-to-128-logical-pixel render. At 150% text, art may yield only
toward the lower bound: 56 in the card and 112 in the inspector. The object
stays recognizable without relying on its colour, and the same item identity
drives both checked exports or named crops.

Supportz remains absent from the visible object-art set. Exactly seventeen
player-visible Shop items require art under the accepted initial catalog.

### 12.2 Minesweeper placement

Every functional cell mark must fit and remain legible in both fixed cell sizes:
`48 x 48` logical pixels ordinarily and `64 x 64` with Large Targets. Desktop
Minesweeper lives in the `800 x 656` computer app body. Narrative challenges
project inside the foreground plane `(160,32,960,656)` while the surrounding
scene remains visible.

Cell planes and marks are semantic functional art. They expose visible board
state through shape, glyph, line, and accessible naming rather than colour
alone. There is no preterminal special-mine appearance; the distinct marked
mine exists only after the governing terminal choice law exposes it.

Localized text, focus frames, active-speaker cues, Dark state, and accessibility
tokens never become part of the artwork pixels.

## 13. What can be drawn now

### Safe to begin

1. Approved quartet lineup refinement.
2. Turnarounds and grayscale silhouette proofs.
3. Neutral face-shape and hairstyle explorations after heritage approval.
4. Base portrait-expression studies.
5. Campus foundation wardrobes and practical role/weather layers.
6. Angela alcove concept and safe focal studies.
7. Bookend, Metronome, and Pocket Calculator object studies.
8. Seven launcher-icon thumbnails.
9. Institutional paper, ink, dither, registration, and glass material swatches.
10. One pilot environment kit and one pilot narrative shot composition.

### Wait for exact content or layout

- scene-specific hand/action atoms;
- CG fragments and ending closing images;
- Archive still selection;
- complete environment inventory;
- final Schedule Focused Folio crop;
- exact portrait-register exports for one-, two-, three-, and four-person layouts;
  and
- every asset whose meaning depends on final prose or witnessed staging.

### Never treat as final yet

- exact faces, complexions, and heritage-specific features before explicit
  character identity approval;
- anonymous AI-generated faces as canonical identity;
- current scaffold dimensions or filenames; and
- art derived from stale eleven-ending IDs, retired gifts, Opening, or tutorial.

## 14. Recommended production order

1. Approve heritage, faces, hair, complexion range, and shared scale lineup.
2. Complete four base portrait/body kits and turnarounds.
3. Produce Angela's shell alcove, base shell pose, keepsakes, and launcher icons.
4. Build one complete pilot Narrative Host shot kit to prove portrait, body,
   environment, crop, focal, and fallback contracts.
5. Produce Contacts portrait derivatives and the shared UI material family.
6. Produce Shop object art and Schedule source-folio art.
7. Expand reusable environments and narrative atoms alongside approved prose.
8. Produce rare CG fragments, ending closing shots, and optional Archive media
   only after their semantic content is frozen.

## 15. Current implementation seams

The later authorized implementation must replace or reconcile:

- `scripts/data/ArtManifest.gd` — empty art registry stub;
- `scripts/ui/SafeImage.gd` — empty fallback/reporting stub;
- `scripts/data/DataCatalog.gd` — obsolete inferred `portrait/dating/tiny`, Shop,
  Schedule, and Minesweeper art paths;
- `scenes/main/MainGameScene.tscn` — monolithic `AngelaImage` and retired tutorial
  host;
- `scenes/dating/DatingScene.tscn` — background plus three placeholder zones;
- `scenes/shared/ContactBox.tscn` — incomplete row portrait only;
- `scenes/shared/ScheduleEntryBox.tscn` — obsolete 32-pixel entry icon;
- `scenes/menu/GalleryScene.tscn` — obsolete grid without Record Desk media;
- `scenes/hospital/HospitalScene.tscn` and `scenes/ending/EndingScene.tscn` —
  obsolete standalone scaffolds; and
- the absence of the approved reusable `NarrativeSceneHost` and closed shot
  manifest.

The future runtime should split generic app/shell art from the stricter closed
narrative presentation manifest. Every host remains a presenter; it never owns
character identity or source artwork.

## 16. Acceptance checklist for each asset

Before an export enters a runtime manifest, verify:

- semantic asset ID and consuming surface are named;
- character identity matches the approved model sheet;
- grayscale silhouette remains readable at the smallest intended crop;
- pivot, baseline, named crops, and focal regions are declared;
- the 100%, 125%, and 150% text compositions preserve essential action;
- the asset contains no localized text or undeclared transient presenter state;
  declared semantic game-state glyphs are allowed under Section 3;
- it exposes no hidden mechanic, relationship tier, route, ending, or danger;
- immutable artwork pixels remain unchanged under Dark and accessibility
  palette modes, while declared functional semantic masks remap through the
  accepted UI-token system;
- missing-art behavior is declared and truthful; and
- the source file remains editable while the runtime export is deterministic.
