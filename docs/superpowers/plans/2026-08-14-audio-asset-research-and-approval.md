# Audio Asset Research and Approval Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a reviewable, source-linked shortlist of existing human-created music, ambience, UI audio, and SFX that can legally and artistically serve every approved Acoustic Memory Atlas role without downloading or integrating assets.

**Architecture:** Research is role-first rather than library-first. Each ledger applies a fail-closed legal gate before artistic scoring, keeps preferred and fallback candidates separate, and feeds one final approval packet; rejected assets remain visible so later workers do not repeat unsafe searches. The approved design and classical-rights note are the normative inputs.

**Tech Stack:** Markdown evidence ledgers, primary/first-party web sources, Creative Commons legal deeds, creator and library terms, repository-local design authorities, `rg`, Git exact-path commits.

## Global Constraints

- Do not download, edit, import, or integrate audio during this plan.
- Do not compose, record, generate, synthesize, clone, or AI-generate audio.
- Use exact asset pages and first-party license/terms pages; search-result text is not evidence.
- Accept only CC0, CC BY, OGA-BY, or another exact creator-owned/game-compatible license that clearly permits commercial game use and necessary modification.
- Reject NC, ND, ShareAlike/copyleft under project policy, personal-use-only, unclear royalty-free, “no copyright,” social reuploads, Mixkit music, AI/GenAI, and conflicting metadata.
- Treat Mixkit SFX separately from prohibited Mixkit music.
- On Freesound, reject anything tagged or described as AI, GenAI, synthetic generation, or generated.
- For classical recordings, clear composition, edition/arrangement, performance, and exact recording/master separately.
- Human nonverbal vocal material requires affirmative human-recording provenance; absence of an AI tag is insufficient.
- Seek one preferred and one fallback per role, but record silence when no candidate deserves approval.
- Every essential auditory event retains its approved physical, visual, or natural textual equivalent.
- Retrieval date for this pass is 2026-08-14.

---

## File map

- Create: `docs/research/audio/README.md` — folder authority, shared status vocabulary, and candidate schema.
- Create: `docs/research/audio/2026-08-14-audio-role-register.md` — closed list of research roles and placement constraints.
- Create: `docs/research/audio/2026-08-14-music-candidate-ledger.md` — music candidates and music-specific rejections.
- Create: `docs/research/audio/2026-08-14-ambience-candidate-ledger.md` — room, exterior, transit, social, conservatory, and hospital ambience.
- Create: `docs/research/audio/2026-08-14-material-foley-candidate-ledger.md` — character materials, objects, body/floor, equipment, and threshold Foley.
- Create: `docs/research/audio/2026-08-14-ui-gameplay-candidate-ledger.md` — restrained interface and Minesweeper cues.
- Create: `docs/research/audio/2026-08-14-human-nonverbal-candidate-ledger.md` — human breath, humming, and choir-like textures or explicit silence decisions.
- Create: `docs/research/audio/2026-08-14-cross-ledger-rejection-log.md` — duplicate, systemic, and high-risk rejections.
- Create: `docs/research/audio/2026-08-14-attribution-draft.md` — exact required credits for finalists.
- Create: `docs/research/audio/2026-08-14-audio-approval-packet.md` — preferred/fallback placement matrix and unresolved decisions.

## Shared interfaces

Every candidate uses this exact heading and field order:

```markdown
### `<role_id>` — Candidate: <exact title>

- **Status:** `CANDIDATE` | `CONDITIONAL` | `REJECTED` | `LEGAL REVIEW` | `APPROVED FOR ACQUISITION REVIEW`
- **Creator / recorder / performers:** <exact credited identity>
- **Source page:** <direct asset or track URL>
- **Exact file identity:** <filename, movement, track number, or source-page file identity; “not exposed before download” when factual>
- **License:** <exact license name and version>
- **License page:** <direct deed, legal code, or creator terms URL>
- **Commercial game use:** Yes | No | Unclear
- **Modification:** Yes | No | Unclear
- **Attribution:** <exact requirement or “not legally required under CC0”>
- **Restrictions:** <redistribution, trademark, collection, account, territory, or other conditions>
- **Composition / arrangement / performance / master:** <classical only; otherwise “not applicable”>
- **Human / AI provenance:** <affirmative evidence, contrary evidence, or unresolved>
- **Proposed placement:** <approved surface, event, or cue family>
- **Permitted edit concept:** <trim/fade/loop/gain/EQ/narrowing, or “none”>
- **Loop and mono notes:** <page evidence and/or later-audition requirement>
- **Comfort and repetition risk:** <specific concern>
- **Why it fits or fails:** <concise artistic/legal judgment>
- **Retrieved:** 2026-08-14
```

A ledger may mark an item `APPROVED FOR ACQUISITION REVIEW`; only the final approval packet may nominate it as a preferred or fallback finalist. No research document authorizes acquisition.

---

### Task 1: Establish the closed role register and evidence schema

**Files:**
- Create: `docs/research/audio/README.md`
- Create: `docs/research/audio/2026-08-14-audio-role-register.md`
- Reference: `docs/superpowers/specs/2026-08-14-acoustic-memory-atlas-audio-design.md`
- Reference: `docs/research/2026-08-14-classical-music-recording-rights-and-free-sources.md`

**Interfaces:**
- Consumes: approved cue taxonomy, placement atlas, legal gate, and research-package counts.
- Produces: the exact candidate template above and these closed role prefixes: `music.`, `ambience.`, `foley.`, `ui.`, `gameplay.`, and `human_nonverbal.`.

- [ ] **Step 1: Write the folder authority**

Copy the shared candidate interface into `README.md`. Define statuses exactly as follows: `CANDIDATE` is unreviewed, `CONDITIONAL` has a named evidence gap, `REJECTED` cannot pass project policy, `LEGAL REVIEW` depends on territorial or rights-holder interpretation, and `APPROVED FOR ACQUISITION REVIEW` has complete research evidence but is not downloaded or integrated.

- [ ] **Step 2: Write the closed role register**

Register these exact roles:

```text
music.fragile_authorial
music.social_diegetic_classical
music.rehearsal_playback_classical
music.post_ending_memory
music.dream_noir_suspension
ambience.bedroom_night
ambience.university_day
ambience.university_late_empty
ambience.conservatory_rehearsal
ambience.campus_social
ambience.hospital_ordinary
ambience.sheltered_transit_rain
foley.paper_folder
foley.book_page_annotation
foley.clasp_small_mechanical
foley.keys_visible
foley.keyboard_instrument_control
foley.chair_ceramic_kettle
foley.fabric_floor_weight
foley.badge_zipper_packaging
foley.equipment_motor
foley.umbrella_luggage
foley.door_handled
foley.device_notification_physical
ui.accept
ui.cancel_back
ui.notification
ui.save_load_success
ui.rejection_error
gameplay.minesweeper_reveal
gameplay.minesweeper_mark
gameplay.minesweeper_result
human_nonverbal.breath
human_nonverbal.hum
human_nonverbal.choir_like
```

For each role, copy the approved placements and explicitly name whether silence is the preferred fallback.

- [ ] **Step 3: Verify role closure**

Run:

```powershell
rg -n "^(music|ambience|foley|ui|gameplay|human_nonverbal)\." docs/research/audio/2026-08-14-audio-role-register.md
```

Expected: every exact role above appears once; no route, affection, `true`, or ending identity appears in an ID.

- [ ] **Step 4: Commit the shared research contract**

```powershell
git add -- docs/research/audio/README.md docs/research/audio/2026-08-14-audio-role-register.md
git commit -m "docs: define audio asset research roles"
```

---

### Task 2: Curate music candidates

**Files:**
- Create: `docs/research/audio/2026-08-14-music-candidate-ledger.md`
- Reference: `docs/research/audio/README.md`
- Reference: `docs/research/2026-08-14-classical-music-recording-rights-and-free-sources.md`

**Interfaces:**
- Consumes: the five `music.` roles and the four-layer classical-rights gate.
- Produces: up to ten surviving preferred/fallback prospects plus named rejections; silence remains valid.

- [ ] **Step 1: Search creator-first sources**

Search PeriTune and similar creator-owned libraries, individual OpenGameArt CC0/CC BY assets, purpose-built CC0 classical projects, and exact creator pages. Do not use Mixkit music. Open every source and license page.

- [ ] **Step 2: Record legal evidence before fit**

Complete every legal field in the shared interface. Mark incomplete classical layers `CONDITIONAL`, `LEGAL REVIEW`, or `REJECTED`; do not score their artistic fit as if cleared.

- [ ] **Step 3: Record placement and editability**

For each survivor, name one approved placement, whether it is diegetic or authorial, and whether trim, fade, looping, or a quieter horizontal variant is permitted.

- [ ] **Step 4: Close each role**

Give every music role a preferred prospect, fallback prospect, or explicit silence decision. Never fill a role with a weak or legally incomplete asset merely to reach ten.

- [ ] **Step 5: Verify and commit**

```powershell
rg -n "Source page|License page|Commercial game use|Modification|Human / AI provenance|Status" docs/research/audio/2026-08-14-music-candidate-ledger.md
git diff --check -- docs/research/audio/2026-08-14-music-candidate-ledger.md
git add -- docs/research/audio/2026-08-14-music-candidate-ledger.md
git commit -m "docs: curate audio music candidates"
```

---

### Task 3: Curate ambience candidates

**Files:**
- Create: `docs/research/audio/2026-08-14-ambience-candidate-ledger.md`

**Interfaces:**
- Consumes: seven `ambience.` roles.
- Produces: source-linked room/exterior candidates with no embedded narrative speech, branded chime, or uneditable musical material.

- [ ] **Step 1: Search professional and field-recorded sources**

Prioritize Sonniss GDC, Kenney CC0, individual Freesound CC0/CC BY field recordings, Mixkit SFX, and OpenGameArt. Use ZapSplat or Pixabay only after exact-condition review.

- [ ] **Step 2: Reject identity leakage**

Reject audible announcements, intelligible conversations, branded transit signatures, conspicuous sirens, medical alarms used as shorthand, and location claims unsupported by the recorder.

- [ ] **Step 3: Record technical audition needs**

For every survivor, record duration, obvious loop seam risk, speech contamination, stereo width, low-frequency rumble, and whether a mono fold-down must be auditioned later.

- [ ] **Step 4: Close all roles and commit**

```powershell
git diff --check -- docs/research/audio/2026-08-14-ambience-candidate-ledger.md
git add -- docs/research/audio/2026-08-14-ambience-candidate-ledger.md
git commit -m "docs: curate audio ambience candidates"
```

---

### Task 4: Curate material and character Foley

**Files:**
- Create: `docs/research/audio/2026-08-14-material-foley-candidate-ledger.md`

**Interfaces:**
- Consumes: twelve `foley.` roles and the character material vocabularies.
- Produces: dry, source-visible candidates that can recur without becoming character leitmotifs.

- [ ] **Step 1: Search by material and action**

Search exact actions rather than emotions: paper alignment, small clasp, handled key, chair taking weight, badge clip, kit zipper, fabric shift, equipment motor, umbrella latch, luggage movement, and restrained door handling.

- [ ] **Step 2: Enforce source visibility**

Record the object, action, likely distance, and room character. Reject Foley whose dramatic processing implies a source or space absent from the approved scenes.

- [ ] **Step 3: Enforce restraint**

Reject horror booms, cinematic impacts, exaggerated wet body sounds, eroticized breath, cartoon Foley, and effects whose tail cannot be separated from baked music.

- [ ] **Step 4: Close all roles and commit**

```powershell
git diff --check -- docs/research/audio/2026-08-14-material-foley-candidate-ledger.md
git add -- docs/research/audio/2026-08-14-material-foley-candidate-ledger.md
git commit -m "docs: curate material foley candidates"
```

---

### Task 5: Curate UI and Minesweeper candidates

**Files:**
- Create: `docs/research/audio/2026-08-14-ui-gameplay-candidate-ledger.md`

**Interfaces:**
- Consumes: five `ui.` and three `gameplay.` roles.
- Produces: a coherent low-intensity command family governed by the SFX setting.

- [ ] **Step 1: Search coherent small cue families**

Prefer one creator pack or materially compatible small set so accept, cancel, notification, save/load, rejection, reveal, mark, and result do not sound like unrelated games.

- [ ] **Step 2: Apply semantic limits**

Reject reward fanfares, loud error buzzers, alarm notifications, slot-machine language, per-cell flood sounds, and cues whose pitch or loudness reveals route importance.

- [ ] **Step 3: Record repetition risk**

Flag transient sharpness, duration, tonal fatigue, rapid-repeat behavior, and whether one accepted command can remain one primary sound.

- [ ] **Step 4: Close all roles and commit**

```powershell
git diff --check -- docs/research/audio/2026-08-14-ui-gameplay-candidate-ledger.md
git add -- docs/research/audio/2026-08-14-ui-gameplay-candidate-ledger.md
git commit -m "docs: curate UI and gameplay audio candidates"
```

---

### Task 6: Curate human nonverbal material

**Files:**
- Create: `docs/research/audio/2026-08-14-human-nonverbal-candidate-ledger.md`

**Interfaces:**
- Consumes: three `human_nonverbal.` roles.
- Produces: only affirmatively human, non-lyrical, non-explicit candidates or explicit silence decisions.

- [ ] **Step 1: Require affirmative provenance**

Accept only a page that credibly identifies a human performer/recordist and exact license. “No AI tag” alone does not pass.

- [ ] **Step 2: Apply content boundaries**

Reject words, lyrics, character-like speech, eroticized breathing, distress that implies an offscreen person, cloned or synthetic voices, and choir libraries whose redistribution terms are unclear.

- [ ] **Step 3: Prefer silence when uncertain**

Record silence as the selected recommendation for any role lacking both legal certainty and non-narrative fit.

- [ ] **Step 4: Verify and commit**

```powershell
git diff --check -- docs/research/audio/2026-08-14-human-nonverbal-candidate-ledger.md
git add -- docs/research/audio/2026-08-14-human-nonverbal-candidate-ledger.md
git commit -m "docs: curate human nonverbal audio candidates"
```

---

### Task 7: Perform the cross-ledger legal audit

**Files:**
- Create: `docs/research/audio/2026-08-14-cross-ledger-rejection-log.md`
- Modify: all five candidate ledgers only when the audit changes a status.

**Interfaces:**
- Consumes: every candidate and cited license.
- Produces: one deduplicated fail-closed decision per source/asset and a record of systemic rejection reasons.

- [ ] **Step 1: Reopen every surviving source and license page**

Confirm creator identity, exact file identity, commercial permission, modification permission, attribution, AI evidence, and absence of conflicting metadata. Record link failure as a named evidence gap.

- [ ] **Step 2: Audit classical layers independently**

For each classical candidate, independently restate composition, arrangement/edition, performance, and recording/master evidence. A blank layer prevents acquisition approval.

- [ ] **Step 3: Deduplicate and reject systemic traps**

Record repeated reuploads, contradictory album/track metadata, library-wide claims incorrectly applied to individual files, and territory-only public-domain claims.

- [ ] **Step 4: Verify no forbidden approval survived**

Run:

```powershell
rg -n "CC BY-NC|CC BY-ND|CC BY-SA|NonCommercial|NoDerivatives|ShareAlike|Mixkit.*music|GenAI|AI-generated|all rights reserved" docs/research/audio
```

Expected: every hit is inside a rejection, restriction, or policy explanation; none is an acquisition-approved candidate.

- [ ] **Step 5: Commit the audit**

```powershell
git add -- docs/research/audio/2026-08-14-cross-ledger-rejection-log.md docs/research/audio/*candidate-ledger.md
git commit -m "docs: audit audio candidate licensing"
```

---

### Task 8: Build the audition and placement decision

**Files:**
- Create: `docs/research/audio/2026-08-14-audio-approval-packet.md`

**Interfaces:**
- Consumes: legally surviving candidates and the approved placement atlas.
- Produces: one preferred, one fallback, or silence for every role; no acquisition authorization.

- [ ] **Step 1: Score only legally surviving candidates**

Use a five-point scale for physical credibility, emotional fit, restraint,
editability, loop suitability, mono risk, repetition fatigue, spoiler risk, and
source reliability. Legal status is a gate, not a score.

- [ ] **Step 2: Map finalists to exact placements**

Name the approved surface/event, cue taxonomy, diegetic or authorial status,
entry/exit concept, non-audio equivalent, and any anomaly-salience cost.

- [ ] **Step 3: Enforce palette restraint**

Reject a finalist set that creates continuous score, thirteen ending themes,
character leitmotifs, or more than the approved recurring families. Silence is
selected wherever it creates the stronger and safer scene.

- [ ] **Step 4: Record the acquisition review table**

Use exactly these columns:

```text
Role | Preferred | Fallback | Silence acceptable | Legal status | Placement | Required edit | Attribution | Open issue
```

- [ ] **Step 5: Commit the placement decision**

```powershell
git diff --check -- docs/research/audio/2026-08-14-audio-approval-packet.md
git add -- docs/research/audio/2026-08-14-audio-approval-packet.md
git commit -m "docs: assemble audio acquisition review"
```

---

### Task 9: Draft attribution and run the final research gate

**Files:**
- Create: `docs/research/audio/2026-08-14-attribution-draft.md`
- Verify: every file under `docs/research/audio/`

**Interfaces:**
- Consumes: preferred and fallback finalists.
- Produces: exact future `THIRD_PARTY_NOTICES` text and a clean research handoff.

- [ ] **Step 1: Write exact credits**

For every preferred and fallback candidate, write `Title / Author or Performer / Source / License`, a direct license link, and a change-notice template where required. Do not credit rejected items as shipped assets.

- [ ] **Step 2: Run completeness scans**

```powershell
rg -L "Source page" docs/research/audio/*candidate-ledger.md
rg -L "License page" docs/research/audio/*candidate-ledger.md
rg -L "Human / AI provenance" docs/research/audio/*candidate-ledger.md
rg -n "T[B]D|T[O]DO|probably safe|assumed free|no copyright music" docs/research/audio
git diff --check -- docs/research/audio
```

Expected: the first three commands return no ledger paths, the forbidden-phrase scan has no candidate claim, and `git diff --check` is clean.

- [ ] **Step 3: Review against the design specification**

Confirm every registered role has a preferred, fallback, or explicit silence result; every selected candidate has a complete legal record; no important placement depends on hearing or stereo; and no file has been downloaded.

- [ ] **Step 4: Commit the attribution handoff**

```powershell
git add -- docs/research/audio/2026-08-14-attribution-draft.md
git commit -m "docs: draft audio asset attribution"
```

## Execution handoff

Execute Tasks 1–9 in order. Music, ambience, Foley, UI/gameplay, and human
nonverbal searches may run in parallel only after Task 1 commits the shared
schema and closed role register. Task 7 is the mandatory legal convergence
gate; Task 8 cannot nominate a finalist before it passes. Acquisition,
listening from downloaded masters, editing, Godot import, and runtime code begin
only after the user reviews the Task 8 approval packet.
