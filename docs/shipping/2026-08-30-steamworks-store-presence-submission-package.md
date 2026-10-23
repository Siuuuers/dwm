---
id: release.steam.store_presence_submission_package
kind: operator_runbook
schema_version: 1
status: prepared_not_submission_ready
prepared_on: 2026-08-30
evidence_checked_on: 2026-08-30
steam_requirements_checked_on: 2026-08-30
repository_inventory_subject_commit: 62b4ddedae6f1ec4a13c40496e3a5ccb7a6e9054
repository_inventory_snapshot_utc: 2026-08-30T15:08:45Z
repository_inventory_worktree_clean: false
repository_inventory_status_entry_count: 134
repository_inventory_status_sha256: d3984619305540b0667edd3ddc135addae562faa3c17a2674a4d1ce951147300
independent_audit_status: passed
independent_audit_completed_on: 2026-08-30
governing_spec: docs/superpowers/specs/2026-08-30-steam-store-page-design.md
governing_spec_approval_commit: b5d2e765716973c7c431feab06686d36ac149a37
governing_content_revision: 084a801c88a5d0cd66e93c608c3bf341137fa392
copy_gate_status: locked_pending_evidence
store_review_submission_authorized: false
coming_soon_publication_authorized: false
publication_authorized: false
release_authorized: false
---

# Steamworks Store Presence Submission Package

## 1. Purpose and present verdict

This is the field-by-field operator package for assembling the approved Steam
Store Presence. It is not a software implementation plan, a Steam upload, a
Store-review request, a Coming Soon publication, or a release authorization.

The approved mystery-first page design and exact English copy are preserved.
The package itself is **not ready to enter, submit, or publish** because its
public title, metadata, release-candidate evidence, genuine gameplay media,
branding assets, audio proof, playtime proof, and owner authorizations do not
yet exist as one immutable package.

| Layer | Present state | Operational consequence |
|---|---|---|
| Release strategy | Approved: complete 1.0, not Early Access | Never select Early Access or write feedback-dependent completion promises |
| English wording | Exact wording locked, evidence pending | Preserve bytes; do not silently improve or shorten |
| Public title | Secret and not recorded here | Do not enter `DWM` or any placeholder |
| App/onboarding | Not evidenced in the repository | Treat account, app credit, App ID, and permissions as unknown |
| Store metadata | Mostly undecided | Do not invent developer, publisher, date, price, platform, language, feature, or survey values |
| Public graphics | Missing | No capsule, library, logo, icon, or About image may be uploaded |
| Gameplay media | Missing | Prototype studies and concept outputs are disqualified |
| Release candidate | Missing | No public gameplay or build-dependent wording is proved |
| Store-review authority | False | Do not click `Mark As Ready For Review` |
| Coming Soon authority | False | Do not click `Post as Coming Soon` or `Prepare for Publishing` |

Valve's live app checklist and every editor section marked `(*)` are the final
authority for mandatory fields. This runbook is a project-specific control
sheet, not a substitute for that live checklist.

## 2. Non-negotiable operating rules

1. **No public-title placeholder.** The internal Godot name `DWM` is not the
   product name. Wait until the owner provides and authorizes the cleared
   public title.
2. **No invented truth.** A design target, story document, draft catalog,
   placeholder timeline, code path, or prototype screenshot is not evidence
   that a customer will receive the feature.
3. **No accidental exposure.** Work only through saved, unpublished edits and
   Store Beta Mode until a separately authorized publication. Valve warns that
   publishing through the Publish tab moves all store data and assets to
   public servers, where hidden or unreleased material may still be scraped.
   As a stricter project stop, do not press `Prepare for Publishing` during
   private assembly.
4. **No authorization by implication.** Passing a checklist does not authorize
   Store review, Coming Soon publication, or release. Each action requires the
   owner's explicit approval of one exact manifest ID.
5. **No quiet copy repair.** A failed factual claim changes the package to
   `revision_required`. Revision or deletion returns to owner review.
6. **Mystery never overrides mandatory truth.** Content Survey, language,
   platform, accessibility, controller, anti-cheat, and system-requirement
   answers must describe the exact uploaded product.

## 3. Locked English fields

These payloads are exact future entry values after the evidence gate passes.
They are not authorization to enter or upload them now.

### 3.1 Product name

**Status:** `OWNER_WITHHELD`

There is deliberately no paste value. Do not use `DWM`, `Untitled`, a working
title, brackets, or any other temporary text. Valve restricts name changes
after pre-release review, so title entry waits for the cleared public name and
explicit disclosure approval.

### 3.2 Release presentation

**Value:** complete 1.0 full release

- Early Access: **not selected**
- Early Access questionnaire: **not used**
- Roadmap or invitation to help finish the game: **not used**
- Optional post-launch additions: not promised on the page

### 3.3 Short Description

Paste one plain-text paragraph with no leading or trailing whitespace:

> This romantic psychological-horror visual novel spans seven days in which Angela may answer messages, keep or miss appointments, and work through compact logic boards while events elsewhere do not wait.

Integrity record:

- characters, including spaces and punctuation: `202`
- encoding: UTF-8 without BOM
- terminal newline in comparison payload: none
- SHA-256:
  `d0a5d5eee0ffafc77abe79f4800c02b5136ba9fb5184611c7b6c078215fd3491`
- final field limit: the live Steamworks editor

### 3.4 About This Game

Copy segment A contains the first three visible blocks:

> During a seven-day university Open Week, messages arrive, appointments overlap, and ordinary records refuse to agree. Angela is present for only part of what happens.
>
> The week unfolds through messages, appointments, and compact Minesweeper-style logic boards. Angela may answer, revisit, attend, miss, or leave things alone.
>
> A romantic psychological-horror visual novel about attention, absence, and the danger of being understood too precisely.

Insert the publication-gated Single Echo image here. The instruction itself is
not visible text.

Copy segment B contains the remaining seven visible blocks:

> **Intention is not authority.**
>
> Angela’s replies and attendance alter what follows. They do not settle what anyone else wants.
>
> **What happens elsewhere can leave evidence.**
>
> Angela may know it only through what remains.
>
> **An answer may return in another form.**
>
> A reply can recur as a quotation, an action, a physical detail, or a changed silence.
>
> An initial passage through the week takes approximately two hours. Ordinary sounds and silence shape the atmosphere.

Structural assembly:

- place exactly one approved About image after block 3 and before block 4;
- use the same depicted frame, composition, and visible content as screenshot
  master 1;
- give it no visible caption or public title;
- make blocks 4, 6, and 8 the only bold blocks;
- add no bullets, feature catalogue, external link, sales call, second image,
  or explanatory text;
- preserve exactly two LF bytes between visible-text blocks in the comparator.

Visible-text integrity record:

- encoding: UTF-8 without BOM
- terminal newline in comparison payload: none
- SHA-256:
  `497ec25c05cf3051c47447904e012758a8889ab204691cd19cca385a847444bd`

Do not paste the Markdown quote markers, segment labels, or editorial insertion
instruction into Steam. The future manifest validator must reconstruct the ten
rendered visible blocks, remove only the three bold delimiters, join blocks
with exactly two LF bytes, and compare this fingerprint and the image position.

Manual reconstruction from this Markdown remains a stop condition. Before
entry, generate and validate immutable companion payloads inside the draft
manifest workspace:

- `payloads/en/short-description.txt` with the exact plain text;
- `payloads/en/about-visible.txt` with the ten exact visible blocks;
- `payloads/en/about-structure.json` with block order, the three bold block
  IDs, the image insertion point, source-master hash, derivative hash, and alt
  text; and
- an editor-compatible entry payload or export for the exact live Steam editor
  revision.

The comparator must reject a byte, formatting, block-order, image-position, or
alt-text mismatch before any operator enters the copy.

**Operational correction from current Valve documentation:** Steam's
About-image editor supports optional alt text, including localized alt text.
This project treats accurate alt text as an accessibility requirement. If the
final frame genuinely matches it, enter:

> Two hands pause over a sealed bottle on a table.

If the final frame differs, do not approximate. Return the literal description
to owner review.

### 3.5 Copy boundary

The public page does not disclose or imply:

- a city, country, or similarly identifying geographic anchor;
- Angela's major;
- character-gender framing or the label `adult` as marketing copy;
- character biographies, archetypes, route pitches, or `choose whom to meet`;
- relationship labels, scores, statistics, ending counts, completion counts,
  or checklist framing;
- the hidden pair, Hospital trajectory, Observer rules, Capture/Compare,
  save/reload law, special mine, or ending gates;
- a final motive, moral diagnosis, plot solution, or global causal answer;
- future features or an implied incomplete launch build; or
- interface language that teaches the audience how to detect a hidden
  comparison.

The page also does not call attention to the absence of recorded character
voice acting. This is a voice rule, not permission to misstate Full Audio.

Mandatory Steam disclosures are factual metadata rather than marketing prose
and remain complete even when the creative copy withholds those details.

## 4. Basic Info and discoverability worksheet

`BLOCKED` and `UNRECORDED` are internal statuses, never public field values.

| Steam surface | Package value/state | Requirement class | Evidence or decision needed |
|---|---|---|---|
| App/product name | `OWNER_WITHHELD` | Live checklist; project gate | Cleared title plus explicit disclosure approval |
| Developer | `UNRECORDED` | Live checklist | Exact public legal or trade name |
| Publisher | `UNRECORDED` | Live checklist | Exact public name; may equal developer only if owner says so |
| Franchise | `UNRECORDED` | Optional | Leave absent unless a real approved franchise exists |
| Product website/social links | `UNRECORDED` | Optional | Use dedicated fields, never About copy |
| Release mode | Complete 1.0 | Project gate | Governing design approved |
| Early Access | No | Conditional setting; project gate | Do not select the Early Access path |
| Public release-date display | `UNRECORDED` | Required display choice | Owner selects exact date, month/year, quarter/year, year, or Coming Soon |
| Exact internal intended date | `UNRECORDED` | Valve required | Required separately from public display; do not guess |
| Paid/free state | `UNRECORDED` | Commercial setup | Owner decision |
| Base price and currencies | `UNRECORDED` | Conditional if paid | Owner decision and Steam pricing approval |
| Public package name | `UNRECORDED` | Conditional if paid | Must match intended storefront presentation |
| Primary genre | `UNRECORDED` | Live checklist | Separate owner-approved discovery decision |
| Secondary genre | `UNRECORDED` | Live checklist | Separate owner-approved discovery decision |
| Categories/features | `BLOCKED` | Optional/conditional | Separate owner approval plus release-candidate verification |
| Accessibility declarations | `BLOCKED` | Optional/conditional | Check only tested shipping features |
| Controller support | `BLOCKED` | Optional/conditional | Declare only tested devices and behavior |
| Anti-cheat declaration | `BLOCKED` | Live question | Reconcile exact build and editor wording |
| Steam Cloud | `BLOCKED` | Optional | No current release-candidate evidence; existing design records it as out of scope |
| Achievements, stats, cards, workshop, remote play | `BLOCKED` | Optional/conditional | No current approved, implemented, tested evidence |
| Supported OS | `BLOCKED` | Valve required | Export, install, launch, and functional test per advertised OS |
| System requirements | `BLOCKED` | Valve required for advertised OS | Measure the actual release candidate; do not invent a generic PC |

### 4.1 Tags

**State:** `UNRECORDED`

No tag shortlist belongs in this operator package until the owner approves a
separate discovery decision. Steam requires at least five tags before launch
and recommends up to twenty; the Tag Wizard is the entry tool. It requires
`Edit App Metadata` and `Publish App Changes to Steam` permissions. Tags are
not a documented Valve prerequisite to normal Store review, but this project
freezes final tags before Store review so the complete public mosaic can be
audited.

Final tags and ordering require owner approval and release-candidate truth. Do
not add tags that reveal or overstate gender, dating-simulation structure,
meaningful-choice scope, ending count, route architecture, sexual content, or
an unimplemented feature.

### 4.2 Platform and system-requirement rule

The current `project.godot` declares Godot feature level 4.6, Forward Plus,
and a Windows D3D12 development setting. That does not identify the eventual
release engine binary or establish a supported OS. There is no
`export_presets.cfg`, exported executable, package, installer, depot, minimum
hardware test, or OS launch matrix.

For every eventually advertised OS, all of these must agree:

- Store Basic Info;
- Steamworks supported-OS settings;
- depots, packages, and default branch;
- public system requirements; and
- a tested build that installs and starts on that OS, as Valve requires; and
- under this project's stricter QA, a build that also saves, loads, and
  completes the advertised experience on that OS.

Leave Minimum and Recommended values unset until measured from the release
candidate and reconciled with the live starred fields.

### 4.3 Language matrix

Do not translate a partial catalog into a whole-game support claim.

| Language | Interface | Subtitles | Full Audio | Present evidence | Store action |
|---|---:|---:|---:|---|---|
| English | Provisional | Provisional | No claim | 119 UI messages and 61 English development timelines; no release candidate | Do not select until final coverage and build test |
| Simplified Chinese | No | No | No | 25 draft UI messages, English fallback, no Chinese narrative timelines | Leave unselected |
| Traditional Chinese | No | No | No | 25 draft UI messages, English fallback, no Chinese narrative timelines | Leave unselected |

The existing localization evidence records 117 English messages while the
current catalog contains 119, so that receipt is stale. `zh_CN` and `zh_HK`
are both marked `draft` while currently selectable in the project manifest;
that mismatch must not reach a release build. Interface, Subtitles, and Full
Audio are independent Steam cells. As a conservative project interpretation,
sound effects or optional text-to-speech do not establish Full Audio; reconcile
the final selection with the live editor's wording and tested shipping support.

## 5. Required graphical and media package

There are presently zero Steam-publication-ready assets. The stock Godot icon
is the only project-owned tracked media outside third-party addons:

- file: `icon.svg`
- dimensions: 128x128
- SHA-256:
  `6c80384360a5b269d1054bfb27241258154e2cc8167c522016fdc1820e84e0f8`
- disposition: **reject as public branding**

Prototype and browser studies under `.superpowers/` are not legal gameplay
captures. Bundled Dialogic example typing sounds are third-party examples and
are not approved project assets. Because no export preset or packaged-build
inventory exists, their actual exclusion from a future build remains unproved
until the PCK/depot contents audit passes.

### 5.1 Asset inventory

| Asset | Current Valve size/form | Required by | Present state |
|---|---|---|---|
| Header Capsule | 920x430 | Valve | Missing |
| Small Capsule | 462x174 | Valve | Missing |
| Main Capsule | 1232x706 | Valve | Missing |
| Vertical Capsule | 748x896 | Valve | Missing |
| Gameplay screenshots | At least 5; 16:9; minimum 1920x1080 | Valve; project uses exactly 5 | Missing |
| Shortcut icon | 256x256 or 512x512 ICO/PNG | Valve | Missing |
| App icon | 184x184 JPG | Valve | Missing |
| Library Capsule | 600x900 | Valve | Missing |
| Library Header | 920x430 | Valve | Missing |
| Library Hero | 3840x1240 PNG; no text | Valve | Missing |
| Library Logo | transparent PNG, 1280 wide and/or 720 high | Valve | Missing |
| About image | Each under 5 MB; combined embedded screenshots/GIFs under 15 MB | Approved page design; Valve limits | Missing |
| Trailer | Up to 1920x1080; encoded before release | Project requires before Store review; Valve requires by release | Missing |
| Trailer poster/thumbnail override | Actual 1920x1080 frame from trailer | Optional | Missing |
| Page Background | 1438x810 | Optional | Missing; audit Steam's last-screenshot derivative if omitted |

The live asset checklist and current templates govern if any documented
requirement changes. Base capsules contain only approved art and the readable
public title/logo, plus an official subtitle only if separately approved. They
contain no quotes, awards, sale language, reviews, URLs, or unrelated text.
If macOS is eventually advertised, this project requires an approved ICNS icon
to avoid Valve's permitted default-Steam-icon fallback; treat it as a
conditional branding requirement, not a Valve submission blocker.

For any additional animated About asset, recheck the live accepted formats and
duration cap; current Valve documentation permits PNG, JPG, GIF, WEBP, MP4, or
WEBM and caps animated media at 12 seconds. The approved page currently uses
only one still image.

### 5.2 Exactly-five screenshot package

Every master must come from a legal release-build play state. Record build,
commit, OS, resolution, semantic scene ID, legal branch setup, final text/UI
ID, board seed and phase when applicable, timestamp, and untouched hash.

| Order | Private role | What the frame proves | Principal exclusions |
|---:|---|---|---|
| 1 | The Interrupted Gesture | Ordinary tactile romance with unease in a pause | No harm outcome, medical cue, welfare material, distress, or preference explanation |
| 2 | The Held Conversation | A genuine nonterminal compact logic board inside a different relationship encounter | No terminal result, score, special cell, hidden rule, statistics, or bottle residue |
| 3 | A Sentence Left Uncorrected | Restrained final dialogue and character response | No comparison UI, biography, private history, outcome wording, or draft prose |
| 4 | A Message Without Coordinates | A normal final Contacts exchange or changed silence | No geography, major, travel schedule, invitation menu, route roster, or protected draft |
| 5 | The Room Still in Use | Mundane consequence or recent activity, not a highlighted clue | No hospital, fainting, ending, hidden pair, key prop, welfare slip, or Day 7 disclosure |

Public screenshots have no interpretive captions. They must look like separate
examples of the game grammar, not one continuous plot synopsis. No blur,
repaint, object removal, composite, promotional overlay, debug control,
Rehearsal mode, AI reconstruction, concept art, or deceptive crop is allowed.

Where genuinely suitable, mark at least four screenshots `suitable for all
ages` so Steam can use them in more placements. Never mislabel mature imagery
to satisfy that target.

### 5.3 Single Echo About image

The About image is the exact screenshot-1 master whenever the editor accepts
the same file. A technical resize, compression, or format conversion is
allowed only when necessary and must record:

- parent master path and SHA-256;
- derivative path and SHA-256;
- conversion tool and exact command/settings;
- confirmation that content, crop, colour, and composition did not change;
- the same spoiler and accessibility audit as the master.

No alternate crop, recolour, composite, blur, retouch, or promotional overlay
qualifies as reuse.

### 5.4 Trailer

Valve describes a gameplay trailer as ideal for Coming Soon and requires a
fully encoded trailer before release. This project deliberately requires the
trailer before Store-review submission so the whole public mosaic can be
audited together.

The trailer remains a separate creative decision. Until it is approved, the
runbook fixes only these controls:

- footage comes from the identified release candidate;
- claims and UI match the public metadata;
- no protected plot, relationship, location, gender framing, hidden mechanic,
  or false continuity is disclosed;
- any custom poster or thumbnail is an actual frame from that trailer;
- music, sound, fonts, art, and footage have source and license evidence;
- captions and any language variant are reviewed independently;
- Steam-generated poster, thumbnail, transcodes, and microtrailer surfaces are
  included in the final preview audit.

### 5.5 Mosaic and cold-reader acceptance

For each supplied Store locale, review every master alone and exactly 26
non-singleton screenshot combinations: ten pairs, ten triples, five
quadruples, and the complete set. Review every non-screenshot surface alone,
then review the assembled Steam Beta preview with final ordering, trailers,
posters, thumbnails, microtrailer material, capsules, About image, tags,
metadata, and the selected or Steam-generated background.

The complete cold-reader protocol in section 8.3 of the governing Store design
is normative without exception. In operational summary:

- freeze at least eight adults fluent in each page language, recruitment
  window, qualification and exclusion rules, stopping rule, and coding
  codebook before exposure;
- participants must not have read private project documents or played a
  development build, and one person sees only one locale;
- retain anyone who sees the page; a missing answer is a failed recognition;
- ask exactly:
  1. `What kind of game is this?`
  2. `What does the player appear to do?`
  3. `What seems to happen in the story?`
  4. `What facts, causes, relationships, or hidden systems does the page
     appear to reveal?`
- use two independent fluent coders and a third fluent adjudicator;
- pass only when at least 75 percent and no fewer than six participants each
  identify the genre, seven-day structure, at least two of messages,
  appointments, dialogue, or compact logic play, and the high-level limit on
  Angela's presence or control;
- no participant may state a protected conclusion as likely or definite;
- across the cohort, at most one participant may speculate about any protected
  conclusion without treating it as supported; and
- no two participants may share an additional specific inference about a
  non-public fact, cause, chronology, relationship, hidden system, or false
  feature.

Retain the exact locale, copy and asset hashes, Steam preview revision, raw
answers, codebook, independent coding, adjudication, and owner/spoiler-authority
approval.

## 6. Content Survey worksheet

Do not answer from memory, genre convention, or the word `adult`. Audit the
exact uploaded build, including content that is present but normally
inaccessible. Complete all live General, Mature, and Generative AI sections
before either Store or build review.

### 6.1 Internal mature-content audit prompts

The story authority permits the following non-graphic material. These are
investigation prompts, **not pre-filled Steam answers**:

- coercive dialogue;
- stalking and privacy invasion;
- unwanted kissing and controlling touch;
- non-graphic biting and small amounts of blood;
- crime and severe danger;
- fainting or loss of consciousness;
- hospital or treatment-room imagery;
- manipulation and a deliberately created physical crisis;
- aftermath implying irreversible harm.

The story boundary prohibits torture, gore spectacle, explicit sexual assault,
an actionable fainting method, and sexual or intimate contact while a person
is unconscious. Absence from the design boundary does not prove absence from
the final build; the release-candidate audit is decisive. No ending confirms
death in the current story authority; severe injury, disappearance, or death
may remain an interpretation. Treat that distinction as an audit prompt, not a
prefilled survey answer.

For each live question, store:

- exact question revision and selected answer;
- build ID and depot manifest audited;
- scene/file references supporting the answer;
- spoiler-safe public warning text, where Steam requests it;
- reviewer and owner approval;
- whether a later build change invalidates the answer.

If `Adult Only Sexual Content` is selected, Valve's exceptional path requires
both the completed Store Page and Product Build to be submitted for review
before Valve reviews and marks the Store Page ready. Do not infer this
selection merely from psychological horror, romance, coercion, or the
project's private `adult` descriptor.

### 6.2 Generative AI

Inventory final player-consumed content and live generation against the exact
questions shown by Steamworks:

- pre-generated AI-assisted content that ships to and is consumed by players;
- live-generated content and its guardrails.

Internal productivity use is not automatically a shipped-content declaration.
Conversely, a final player-visible asset cannot be omitted merely because it
began as a study. The `.superpowers/brainstorm` images are currently
disqualified and must not be uploaded or shipped. Record sources, licenses,
model/tool provenance where applicable, edits, and final-file hashes for every
asset that survives into the release candidate.

## 7. Public-claim evidence matrix

The exact English copy is `locked_pending_evidence`. Every row currently blocks
Store-review submission under the approved project policy. Claim IDs bind each
factual phrase to its exact copy source: `SD` is Short Description and
`A1`-`A10` are the About blocks in section 3.4.

| Claim ID / source | Public claim | Required observation or authority | Present truth |
|---|---|---|---|
| C01 / SD, A3 | Romantic psychological-horror visual novel | Shipped product form and content truthfully support the exact genre phrase | No release candidate |
| C02 / SD, A1 | The experience spans seven days | A legal run reaches and distinguishes all seven days | No complete final-flow receipt |
| C03 / A1 | University Open Week | Final build and approved canon use this setting without adding a public location | No immutable build proof |
| C04 / A1 | Messages arrive | Final legal play exhibits message arrivals | No immutable build proof |
| C05 / A1 | Appointments overlap | Final legal schedule exhibits a genuine overlap | No immutable build proof |
| C06 / A1 | Ordinary records refuse to agree | Final legal play exhibits the advertised disagreement | No immutable build proof |
| C07 / A1 | Angela is present for only part of what happens | Final legal play establishes limited witnessed presence and lawful offscreen continuation | No immutable build proof |
| C08 / SD, A2 | Angela may answer messages or leave things alone | Both states occur lawfully; answered messages produce approved echo/downstream presentation, while ignored messages follow approved no-history/no-echo expiry | No immutable build proof |
| C09 / SD, A2 | Angela may keep, attend, or miss appointments | Legal schedules exhibit every advertised state in its exact authored meaning | No immutable build proof |
| C10 / SD, A2 | Angela works through compact logic boards | A genuine playable nonterminal board occurs within an encounter | Code/design does not prove shipped behavior |
| C11 / SD | Events elsewhere do not wait | Offscreen continuation produces valid later state while Angela is elsewhere | No immutable build proof |
| C12 / A2 | The boards are Minesweeper-style | Final board interaction truthfully supports that familiar comparison without hidden-rule disclosure | No immutable build proof |
| C13 / A2 | Angela may revisit | Shipped UI exposes the exact ordinary revisit behavior implied | No immutable build proof |
| C14 / A3 | Attention, absence, and dangerously precise understanding are the emotional proposition | Final canon/build and cold-reader result support the proposition without implying a solved motive | No final-build or preview evidence |
| C15 / A5 | Replies and attendance alter what follows but do not settle another person's wants | Reproducible downstream difference exists and the page does not promise motive resolution | No immutable build proof |
| C16 / A6-A7 | What happens elsewhere can leave evidence known through what remains | A legal consequence appears without teaching the hidden system | No immutable build proof |
| C17 / A8-A9 | An answer can recur as quotation, action, physical detail, or changed silence | At least one final, lawful recurrence supports every publicly listed carrier class or the wording is revised | No immutable build proof |
| C18 / A10 | Initial passage approximately two hours | Blind release-candidate cohort passes section 7.1 | No empirical playtime runs |
| C19 / A10 | Ordinary sounds and silence shape atmosphere | Approved mix and blind audio cohort pass section 7.2 | Zero approved/downloaded project audio assets |

For every row, the final receipt records build, source commit, OS, setup, exact
expected observation, actual result, evidence path, reviewer, and hash. A
failed row triggers truthful copy revision or deletion; it never becomes a
future-feature disclaimer.

### 7.1 Two-hour sentence gate

Section 9.1 of the governing Store design is normative without exception. Use
at least eight blind first-time players on one legal release candidate. They
must not have seen the duration claim or been told the two-hour hypothesis.
Before recruitment, freeze cohort size, recruitment window, coverage, timing,
whole-run exclusions, and stopping rule.

The timing protocol:

- starts when the player confirms a new game;
- ends at the first stable post-ending screen or return to the main menu;
- excludes only participant-reported or observer-confirmed away-from-game
  pauses longer than 60 seconds;
- counts ordinary reading, deciding, solving, and lack of input as playtime;
- prohibits skipping unseen text while allowing ordinary reading speed and
  chosen accessibility settings;
- records assistance settings, branch setup, board outcomes, and excluded idle
  time for every run;
- covers at least three legal appointment-attendance profiles and at least two
  board-outcome profiles; and
- permits no single profile to supply more than half of the included runs
  within either coverage category.

A run may be excluded only for withdrawal before build launch or an external
interruption or hardware failure unrelated to the product. A post-launch
product-related stop, crash, softlock, or corrupted state fails the candidate.
Retain every attempt and disposition; do not replace or select runs after
seeing results.

The claim passes only when:

- median playtime is 105-135 minutes; and
- at least 75 percent of included runs are 90-150 minutes.

Developer familiarity, skipped dialogue, a partial build, design estimate, or
completionist timing cannot support the claim.

### 7.2 Atmosphere sentence gate

Section 9.2 of the governing Store design is normative without exception.
First integrate approved, licensed audio and intentional silence. Freeze the
cohort, exact package, hardware coverage, whole-session exclusions, and
stopping rule before recruitment. Test the opening, a contacts or appointment
interval, at least two middle-day witnessed scenes, one board transition, one
intentionally quiet interval, and one ending.

A timestamped cue-and-mix log identifies every ordinary sound and intentional
quiet interval in the package. At least five blind participants play with the
intended default mix and receive no explanation of the audio design. Ask
exactly:

> What contributed to the atmosphere?

Pass only when at least 80 percent and no fewer than four participants
identify both ordinary sound and intentional silence, or explicitly identify
their atmospheric relation. A reproducible missing, broken, painfully
imbalanced, or narratively contradictory cue fails the test. The owner or
designated audio reviewer approves the final cue-and-mix log.

For every attempt, retain build, OS, output device, audio settings, session,
raw answer, defect result, and disposition. Use the same exclusion boundary as
section 7.1. Run separate technical passes on every advertised OS and on
headphones and speakers when both are supported.

Every shipped audio asset also needs source and license evidence, exact-file
approval, edit and attribution records where required, comfort and repetition
testing, and verification with accessibility read-aloud behavior.
Plot-important audio needs a visual equivalent. Reconcile `Full Audio` with the
live Steam definition; do not infer it from sound effects or optional
text-to-speech.

## 8. Frozen submission manifest

One immutable manifest binds the Store package to its evidence. It must contain
at least:

### 8.0 Sealing and data-classification rules

No machine-readable manifest, schema, template, or validator exists today, so
manifest sealing is itself a Store-review blocker. When that separate evidence
artifact is authorized, use this convention:

The following evidence-package paths are logical paths inside the approved
restricted evidence store; they are not instructions to place embargoed bytes
in this broader-access repository:

- draft workspace:
  `evidence/steam/store_presence/drafts/<work-id>/`;
- sealed archive:
  `evidence/steam/store_presence/manifests/<manifest-id>/`;
- manifest:
  `manifest.json` encoded as canonical UTF-8 without BOM;
- required schema:
  `schemas/evidence/steam-store-presence-manifest.schema.json`;
- required validator:
  a repository-reviewed tool that validates schema, paths, SHA-256 values,
  copy fingerprints, authority separation, and sealed immutability.

The future validator defines one deterministic canonical JSON representation.
Compute a body SHA-256 without the `manifest_id` and `seal` fields, then use
`steam-store-presence-<UTC timestamp>-<first 12 body-hash characters>` as the
manifest ID. Add the ID and full body hash to the seal, validate, and never
modify that sealed directory. Corrections begin as a copy-on-write draft that
names its predecessor; seal a successor only after its final bytes and audits
pass. Preserve every predecessor.

This naming contract does not authorize implementing the schema or tooling.
Their absence remains explicit until that separate work is requested and
verified.

The repository stores no Steam password, session cookie, API key, token, bank
or tax record, identity document, NDA/agreement copy, personal signature, or
other credential/restricted personal data. The manifest holds only opaque
references to restricted evidence plus non-sensitive hashes or attestations.
App ID, role names, timestamps, and approval-state references may be recorded
when policy permits; the actual owner approval remains in its authorized
restricted system.

The secret title, unreleased media, spoiler-bearing evidence, price, intended
date, private previews, and embargoed commercial metadata are also restricted
until the owner authorizes their disclosure. Store their bytes only in an
approved access-controlled evidence location. A broader-access Git repository
contains opaque references and hashes, not the embargoed bytes. The sealed
manifest records the storage classification and authorized audience for every
referenced artifact.

The seal covers the complete evidence archive, not merely `manifest.json`:

- inventory every regular file by normalized relative path, byte length, and
  SHA-256;
- reject an unlisted, missing, duplicate, or case-colliding path;
- reject symlinks, junctions, and other links/reparse points;
- sort the inventory by ordinal relative path and hash its canonical UTF-8
  representation to produce a sealed tree digest; and
- emit a separate immutable `validation-receipt.json` containing manifest
  hash, tree digest, validator name/version/hash, schema version, UTC time, and
  pass/fail result.

### 8.1 Account and authority

- Steam partner and App ID;
- operator role/reference and relevant permissions, without credentials or
  sensitive identity material;
- onboarding/app-fee state;
- Store-review, Coming Soon, and release authorizations as separate records;
- authorization timestamp, exact manifest ID, and restricted approval
  reference; and
- validation-receipt hash bound by the same authorization.

### 8.2 Public metadata

- public title and clearance/disclosure approval;
- developer, publisher, franchise, links;
- release strategy and Early Access state;
- exact internal intended date and public display mode;
- paid/free state, package name, proposed price and currency table;
- genres, ordered tags, categories, and Steam features;
- OS declarations and system requirements;
- accessibility, controller, anti-cheat, DRM, and online-feature declarations;
- language cells by Interface, Subtitles, and Full Audio, with each locale's
  source catalog/version, required-content count, intentional-fallback
  allowlist, and tested OS/font/glyph/input/overflow/subtitle/audio coverage;
- all three Content Survey answers.

### 8.3 Public bytes and surfaces

- exact copy and localization bytes with hashes;
- every capsule, icon, library asset, screenshot, About derivative, trailer,
  poster, thumbnail, and optional background with hash and public order;
- every asset's source, rights/license, edits, and attribution requirement;
- Steam Beta preview revision and screenshots of every visible surface;
- Steam-generated background, crop, transcode, poster, thumbnail, and
  microtrailer outputs;
- per-locale preview and cold-reader evidence.

### 8.4 Build binding

- a clean source commit with clean index, worktree, and submodules; dirty
  release sources fail closed rather than relying on a disposition note;
- Godot and addon versions;
- export preset and release build ID;
- platform artifact, depot, and checksum records;
- exported PCK/depot file inventory proving whether addon examples, prototype
  files, tests, research, development evidence, and other non-product material
  are excluded or truthfully covered by Store metadata and the Content Survey;
- proof that the release project no longer points to the stock Godot
  `icon.svg`;
- install/launch/functional test matrix;
- claim, playtime, audio, localization, content, performance, accessibility,
  save/load, and stability evidence;
- exact command, result count, artifact location, and reviewer for each gate.

Any mutation to a bound value requires a copy-on-write successor, new seal, and
new manifest ID. It invalidates affected downstream audits and owner
authorization; a sealed predecessor is never edited or deleted.

## 9. Steamworks operator sequence

These are operational phases, not software implementation tasks.

### Phase A: account and app prerequisites

1. Confirm whether onboarding is already complete. If not, the authorized
   person completes Valve's NDA/distribution agreement, legal identity, bank,
   tax, and identity verification. Valve says tax verification typically takes
   2-7 business days.
2. An Administrator pays the Steam Direct app credit if needed, and the same
   Steam account that paid activates it. The current fee is USD 100 or regional
   equivalent per product. For a partner's first few titles, Valve also
   imposes a 30-day wait from fee payment before release.
3. Record App ID and operator permissions without credentials. `Edit App
   Marketing Data` permits Store-page editing and publishing; `Edit Store
   Localization Data` alone cannot publish. Posting Coming Soon or releasing
   requires both `Publish app changes to Steam` and `Manage pricing and
   discounts`. Pricing also requires membership in the payee partner.
   Legal/financial Actual Authority remains separate.
4. Do not create or rename the app with `DWM`. Wait for the cleared public
   title.

### Phase B: private Store assembly

1. Open `Edit Store Page` only after the public title may be disclosed to
   Steam.
2. Complete the live `Your Store Presence` checklist and every `(*)` field.
3. Save edits without publishing.
4. Use `Preview changes in store` / Store Beta Mode.
5. Never press `Prepare for Publishing` during assembly.
6. If the title will be paid, reconcile the public purchase-package name and
   proposed pricing from the app landing page. Always reconcile the exact
   internal intended release date separately from its public display.
7. Treat this runbook's field list as supplemental; capture any new live
   required field into the manifest before continuing.

### Phase C: evidence freeze

1. Export or record every exact field value and file.
2. Hash all public and build artifacts.
3. Generate the claim matrix, screenshot provenance, rights ledger, language
   matrix, survey audit, and preview captures.
4. Audit every public asset alone and exactly 26 non-singleton screenshot
   combinations per locale, then the actual assembled Steam Beta preview.
5. Run the complete section 5.5 cold-reader protocol for every public locale.
6. Build a draft manifest, validate all bytes and evidence, then seal and
   assign its immutable ID. Do not name or mutate a supposedly final manifest
   while corrections remain.
7. Confirm `STORE_REVIEW_SUBMISSION_READY = true` for that exact sealed
   manifest.

### Phase D: Store review

1. Show the owner the exact Steam Beta preview and manifest.
2. Obtain explicit authorization naming that manifest ID.
3. Only then click `Mark As Ready For Review`.
4. Record submission time and Valve feedback.
5. Valve says Store review usually takes 3-5 business days and recommends
   submitting at least 7 business days before the desired public date.
6. Any correction creates a new manifest and requires the affected re-audits
   and a fresh owner authorization under project policy.
7. In Valve's ordinary sequence, submit Store Presence before submitting the
   product build for review. The Adult Only Sexual Content exception remains
   the joint path in section 6.1.

### Phase E: Coming Soon

1. Confirm Valve approved the current Store Presence/store page. In the
   ordinary path, a Coming Soon page does not require prior build approval.
2. Re-open and inspect the actual approved preview.
3. Obtain a separate owner authorization for Coming Soon publication naming
   the exact manifest ID.
4. Only then click `Post as Coming Soon`.
5. Record the public timestamp, timezone, public URL, and screenshots.
6. Keep the page public for at least two weeks before release. The project
   records 14 full days as its auditable minimum.
7. Treat the public date as locked inside the final 14-day window; contact
   Valve rather than assuming it can still be moved.

### Phase F: later full release

Coming Soon publication does not authorize release. Full release later
requires:

- completion of any applicable first-few-title 30-day Steam Direct wait;
- at least two public Coming Soon weeks, recorded as 14 full project days;
- at least five approved launch tags;
- both required posting permissions;
- Valve approval of both Store Presence and the near-final build;
- all advertised features working and the build starting on every advertised
  OS;
- a fully encoded trailer;
- reconciled Store and build checklists, survey, language, OS, feature,
  price/date/package, and depot state;
- a separate owner authorization for the exact release manifest; and
- the authorized operator's manual `Release App` / `Publish Now` action.

Valve says build review usually takes 3-5 business days and recommends allowing
at least 7 business days. Approval never releases the product automatically.

## 10. Stop conditions

Stop immediately and do not submit or publish if any of the following is true:

- the title is absent, uncleared, inconsistent, or represented by `DWM`;
- the copy or About structure differs from the currently governing
  owner-approved revision and its fingerprints;
- the two-hour or atmosphere coda lacks passing evidence, unless an updated
  owner-approved copy revision deletes or truthfully replaces it and records
  new fingerprints;
- a screenshot is not genuine release-build gameplay;
- a public asset lacks rights, provenance, or final owner approval;
- a capsule/logo is unreadable or contains unauthorized text;
- the About image is not the exact approved screenshot-1 composition;
- a screenshot, trailer, capsule, tag, or background enables a protected
  inference alone or in combination;
- language cells exceed tested whole-product coverage;
- Chinese drafts remain player-selectable in a purported final build;
- survey answers are not reconciled to every uploaded depot;
- exported package contents have not been audited for addon examples,
  prototypes, tests, research, or other unintended material;
- the release project still points to the stock Godot `icon.svg`;
- OS fields, depots, requirements, and launch tests disagree;
- a feature/category/tag is not present at launch;
- the live checklist contains an unrecorded mandatory field;
- the Steam preview or generated derivative is absent from the audit;
- the package changed after its manifest was authorized;
- any external-action authorization is absent or does not name the exact
  manifest ID.

## 11. Correction and recovery

Before publication:

1. stop at saved/unpublished edits;
2. record the defect and affected fields/assets;
3. correct the authoritative source or Steam configuration, as applicable;
4. create a copy-on-write draft successor that names the prior manifest;
5. rerun directly affected claim, rights, localization, mosaic, preview, and
   owner reviews;
6. seal the successor and assign its final ID only after corrected bytes,
   hashes, and audits stabilize;
7. obtain fresh owner authorization naming that successor manifest before
   review submission.

After Coming Soon publication:

1. preserve evidence of the live defect and discovery time;
2. assess customer, legal, spoiler, accessibility, and metadata impact;
3. prepare and audit the smallest truthful copy-on-write successor;
4. seal it and obtain owner authorization naming its exact manifest ID;
5. apply the internal manifest re-audit in every case, then determine whether
   Steam Support is required; Valve generally does not require re-review for
   ordinary updates after approval;
6. complete any Valve review or Steam Support instruction that is required;
   do not publish the corrected package while that external prerequisite is
   pending;
7. publish through Steam's normal update path and verify the public result;
8. record the corrected public revision and timestamp;
9. contact Steam Support for a material defect that cannot be safely corrected
   through the normal editor, affects locked release timing, changes a locked
   Content Survey answer or reviewed name, or when Valve directs it.

Never expose a secret title or asset merely to test whether rollback is
possible.

## 12. Exact inputs still needed from the owner

These are requested only when the corresponding package work is real; the
secret title does not need to be disclosed merely to keep designing.

- cleared public title and permission to disclose it to Steam;
- exact developer and publisher display names;
- paid/free decision, price, and public package name;
- exact intended release date plus public display precision;
- final advertised OS set and owner-approved system requirements;
- approved genres, ordered tags, categories, and feature selections;
- English-only versus localized Store-page decision;
- exact supported-language rows by Interface, Subtitles, and Full Audio, plus
  any approved localized Store copy;
- accessibility, controller, anti-cheat, DRM, and online-feature declarations;
- approved public branding system and every final asset;
- approved trailer concept, final edit, captions, poster/thumbnail decision,
  and media order;
- rights, license, edit, attribution, and provenance package;
- final Content Survey review and mature-warning wording;
- explicit manifest-bound authorizations for Store review, Coming Soon, and
  release, each given separately.

## 13. Present blockers from repository evidence

This section is a **non-gating live inventory**, not release evidence. It was
audited against the source commit recorded in frontmatter while the worktree
was dirty. Regenerate it from a nominated clean release-candidate commit and
store the commands, normalized status digest, UTC timestamp, results, and
reviewer receipt in the future sealed manifest.

The frontmatter status receipt used exactly
`git status --porcelain=v1 --untracked-files=all`. It preserved Git's emitted
order, joined the 134 output records with LF, added no terminal newline,
encoded UTF-8 without BOM, and hashed those bytes with SHA-256. The raw output
was not retained, so the receipt remains informational and cannot qualify as a
release gate.

The current inventory also used `git rev-parse HEAD`, tracked and no-ignore
media/export/build sweeps, current localization catalog counts, Dialogic
timeline/status evidence, the audio approval packet, and the installed Godot
version check. It presently finds:

- no `export_presets.cfg`;
- no exported executable, PCK, archive, installer, SteamPipe VDF, depot, or
  release-build checksum;
- no immutable Steam release manifest;
- no public title or game version;
- no Steam-ready capsule, library, icon, screenshot, About, or trailer asset;
- no approved project audio asset or final mix;
- no empirical playtime cohort;
- partial draft Chinese UI and no Chinese narrative timelines;
- stale localization evidence;
- 61 development English timelines, including draft and placeholder inventory,
  rather than a proven final legal flow;
- twelve of fourteen later encounter premises still unselected in the
  governing causal record;
- no supported-OS or system-requirement evidence.

Therefore:

- `STORE_REVIEW_SUBMISSION_READY = false`
- `COMING_SOON_PUBLICATION_READY = false`
- `FULL_RELEASE_READY = false`

This is a healthy stop, not a failure of the page design. It prevents a
beautiful but unverifiable page from becoming a public promise.

## 14. Definition of Store-review ready

Store Presence becomes ready for owner authorization only when:

- the live Steam checklist is complete;
- the exact public title and metadata are approved;
- every asset is present, rights-cleared, hash-recorded, and previewed;
- five genuine final-authority screenshots and the Single Echo image pass;
- trailer and all generated media surfaces pass the project audit;
- every factual copy clause passes against the release candidate;
- playtime and audio claims pass or owner-approved truthful revisions replace
  them;
- every language, OS, feature, accessibility, controller, anti-cheat, and
  Content Survey declaration matches the exact uploaded product;
- the whole page passes spoiler and cold-reader review;
- one immutable manifest binds everything;
- the owner explicitly authorizes Store review for that manifest ID.

## 15. Official Valve references

Requirements were refreshed on 2026-08-30. Recheck them against the live
editor immediately before entry:

- [Onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding?language=english)
- [Steam Direct Fee](https://partner.steamgames.com/doc/gettingstarted/appfee?language=english)
- [Users and Permissions](https://partner.steamgames.com/doc/gettingstarted/managing_users?language=english)
- [Store Page, Building and Editing](https://partner.steamgames.com/doc/store/page?language=english)
- [Written Description](https://partner.steamgames.com/doc/store/page/description?l=english)
- [Extra Asset Management](https://partner.steamgames.com/doc/store/page/assets?l=english)
- [Graphical Asset Overview](https://partner.steamgames.com/doc/store/assets?l=english)
- [Store Graphical Assets](https://partner.steamgames.com/doc/store/assets/standard?l=english)
- [Library Assets](https://partner.steamgames.com/doc/store/assets/libraryassets?l=english)
- [Community and Client Icons](https://partner.steamgames.com/doc/store/assets/community?l=english)
- [Graphical Asset Rules](https://partner.steamgames.com/doc/store/assets/rules?l=english)
- [Trailers](https://partner.steamgames.com/doc/store/trailer?l=english)
- [Localization and Languages](https://partner.steamgames.com/doc/store/localization?l=english)
- [Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey?language=english)
- [Platforms](https://partner.steamgames.com/doc/store/application/platforms?language=english)
- [Pricing](https://partner.steamgames.com/doc/store/pricing?language=english)
- [Release Dates](https://partner.steamgames.com/doc/store/release_dates?language=english)
- [Changing Your Game's Name](https://partner.steamgames.com/doc/store/editing/name?language=english)
- [Steam Tags](https://partner.steamgames.com/doc/store/tags?language=english)
- [Review Process](https://partner.steamgames.com/doc/store/review_process?l=english)
- [Coming Soon](https://partner.steamgames.com/doc/store/coming_soon?language=english)
- [Release Process](https://partner.steamgames.com/doc/store/releasing?l=english)
- [Release Options](https://partner.steamgames.com/doc/store/types?language=english)
