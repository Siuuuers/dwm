# Audio Audition Intake Pass 1: Hybrid Physical-Core Design

**Date:** 2026-08-14

**Status:** Written design pending user review

**Parent authority:**
`docs/superpowers/specs/2026-08-14-acoustic-memory-atlas-audio-design.md`

**Research inputs:**

- `docs/research/audio/2026-08-14-audio-approval-packet.md`
- `docs/research/audio/2026-08-14-physical-core-license-reverification.md`

## 1. Decision

Pass 1 uses a hybrid audition intake:

1. acquire the exact Kenney `UI Audio` v1.0 CC0 archive;
2. acquire only official Freesound-generated previews for a preliminary cull;
3. clearly prevent any preview from becoming a game asset or final approval
   master;
4. ask the user to download exact Freesound originals while logged into their
   own account only for candidates that survive the preview cull; and
5. perform exact-file intake and audition before any asset can be nominated for
   use.

The assistant never asks for, receives, stores, or operates the user's
Freesound password, cookies, API key, OAuth token, or authorization code.

## 2. Scope

### 2.1 Eligible for this pass

| Role | Candidate | Preliminary source state |
|---|---|---|
| `ambience.bedroom_night` | visionear, Freesound 565535 | Preview-only until original is supplied |
| `ambience.university_day` | richwise, Freesound 474823 | Preview-only until original is supplied |
| `foley.paper_folder` | alec_mackay, Freesound 463682 | Preview-only until original is supplied |
| `foley.book_page_annotation` | parkersenk, Freesound 444479 | Preview-only until original is supplied |
| `foley.chair_ceramic_kettle` | Jamitch2, Freesound 344704 | Preview-only until original is supplied |
| `foley.keyboard_instrument_control` | EricsSoundschmiede, Freesound 457410 | Preview-only until original is supplied |
| `foley.door_handled` | Breviceps, Freesound 457042 | Preview-only until original is supplied |
| UI role pool | Kenney `UI Audio` v1.0 | Exact pack may be acquired; members remain unselected |

### 2.2 Stopped in this pass

- Kinoton, Freesound 670070, remains `REJECTED` because its asset-page CC0
  indication conflicts with creator-profile raw-file restrictions.
- Geoff-Bremner-Audio, Freesound 802495, remains `REJECTED` because its
  asset-page CC0 indication conflicts with the creator profile's CC BY 4.0
  statement.
- `ambience.hospital_ordinary` and `foley.umbrella_luggage` therefore resolve
  to their approved silent/physical fallback until a later replacement search.

### 2.3 Explicitly out of scope

- music, human nonverbal material, gameplay cues, and other ambience/Foley;
- composition, recording, synthesis, generation, cloning, or AI generation;
- final editing, loop construction, normalization, runtime export, or import;
- changes to `AudioManifest`, `AudioManager`, buses, scenes, or Godot resources;
- assigning a Kenney member to a semantic role before exact inventory and
  audition; and
- declaring any asset approved for use or shipment.

## 3. Storage boundary

Implementation creates two physically separate, ignored areas:

```text
source_audio/
└── batch-01/
    ├── exact-originals/
    └── user-drop/

.godot/
└── audio-audition-cache/
    └── batch-01/
        ├── downloads/
        ├── extracted/
        ├── analysis/
        └── audition-renders/
```

`source_audio/` is the preserved-source vault and must be added to the root
`.gitignore` before it is created. Exact originals are never overwritten.
`user-drop/` is where the user may place manually downloaded Freesound files
without renaming them. The intake process moves an accepted exact file into a
candidate-specific folder only after hashing and recording its original name.

`.godot/audio-audition-cache/` is disposable working material. It may contain
Freesound previews, a Kenney archive copy, safe extraction output, analysis
logs, and derived audition renders. Clearing `.godot` may delete it without
destroying preserved exact originals or committed evidence.

No audio binary is committed to Git during Pass 1. Committed Markdown and
machine-readable evidence contain paths relative to these roots, never
credentials or local account information.

## 4. Evidence and intake records

The pass produces one committed audition docket and one machine-readable
manifest. Each intake record contains:

- registered role or `unassigned_ui_pool`;
- exact candidate title and creator;
- source asset URL and direct license URL;
- Freesound ID or Kenney pack/version;
- acquisition kind: `official_preview`, `exact_pack`, or `exact_original`;
- original filename without normalization or invention;
- retrieval timestamp in ISO 8601 with timezone;
- final resolved download URL and its relationship to the first-party page;
- byte size, media type, container/codec, duration, sample rate, bit depth when
  exposed, and channel count/layout;
- SHA-256 of every downloaded archive or audio file;
- archive member path and member SHA-256 where applicable;
- legal status and evidence-ledger link;
- AI/GenAI evidence statement without treating silence as certification;
- analysis status, listening status, and decision state; and
- every derived render's parent hash and non-destructive recipe.

Freesound previews are labelled `PREVIEW_ONLY — NOT AN EXACT SOURCE MASTER` in
both human-readable and machine-readable records. A preview can produce only
`PREVIEW_REJECTED` or `ORIGINAL_REQUESTED`; it cannot produce approval.

## 5. Safe acquisition

### 5.1 Kenney archive

The exact `UI Audio` v1.0 pack is downloaded only from the official Kenney
asset page or a download URL reached from that page. Before extraction:

1. record source and license evidence;
2. hash the archive;
3. enumerate every archive member without extracting;
4. reject absolute paths, parent traversal, links, or unexpected executable
   content; and
5. extract only into the candidate's cache folder.

All audio members are inventoried. No member becomes `ui.accept`,
`ui.cancel_back`, `ui.notification`, `ui.save_load_success`, or
`ui.rejection_error` merely because of its filename.

### 5.2 Freesound previews

Official preview URLs must be exposed by the exact Freesound asset page or its
first-party API response. The downloaded preview is kept unchanged and hashed.
It is never copied to `source_audio/`, `audio/`, or a Godot import path.

Previews exist only to reject obvious mismatches before asking the user to
perform seven account-gated original downloads. If source identity, license,
redirect provenance, or media type is unclear, that candidate stops.

### 5.3 Exact Freesound originals

After the preliminary cull, the docket provides direct source-page links and a
short list of requested originals. The user logs into Freesound themselves,
downloads from those pages, and places the unchanged files in `user-drop/`.
The assistant does not automate or observe login.

An original advances only when its filename and technical identity reconcile
with the source page and its SHA-256 is recorded. A mismatch stops the
candidate; it is never repaired by renaming or transcoding.

## 6. Non-destructive analysis

`ffprobe` records technical identity. `ffmpeg` may calculate statistics from an
unchanged input, including:

- sample peak, RMS and integrated loudness observations;
- channel layout and duration;
- DC offset, clipping indicators, silence distribution, and crest behavior;
- broad spectral/resonance observations; and
- mono fold-down behavior and potential cancellation.

Statistics are screening evidence, not a medical safety guarantee and not a
substitute for listening. A metric may flag a candidate for review, but it may
not certify comfort, emotional fit, physical credibility, or absence of
fatigue.

## 7. Audition renders and listening order

The unchanged download is preserved. Derived audition renders may use only:

- attenuation, never amplification;
- clean start/end fades needed to prevent playback clicks;
- mono fold-down for the required mono-first pass; and
- a documented repeat montage for short UI candidates.

No compression, limiting, EQ, pitch shift, time stretch, noise removal, loop
construction, or creative edit is allowed in the preliminary cull. Those
processes could disguise the exact candidate's behavior.

Playback never starts automatically. The docket presents neutral blind IDs
without role, romance, route, ending, importance, or preferred/fallback labels.
The order is deterministic but does not group “important” sounds together.

Listening occurs in this order:

1. mono, at an ordinary comfortable device level;
2. stereo on headphones for width, cancellation, and discomfort;
3. ordinary speakers;
4. repeated UI playback for fatigue; and
5. exact-original scene/TTS testing only after the preliminary survivor is
   manually acquired.

The listener can stop immediately. No candidate is retained merely because it
is legally usable.

## 8. Decision rules

### 8.1 Immediate rejection

Reject on any of the following:

- source/license identity no longer reconciles;
- AI/GenAI evidence or conflicting provenance appears;
- speech, branded cue, private conversation, or an undeclared performed work is
  audible;
- a loud attack, jump-scare contour, painful resonance, or unacceptable fatigue
  appears at ordinary listening level;
- the sound invents an unseen person, object, room, action, or choreography;
- mono materially removes or changes the sound's meaning;
- the cue signals reward, error, romance, route, ending, or importance beyond
  its visible action; or
- the physical source does not match the visible object and space.

### 8.2 Preliminary survival

A Freesound preview survivor becomes `ORIGINAL_REQUESTED`, not approved. A
Kenney member survivor becomes `EXACT_MEMBER_AUDITION_PENDING`, not assigned.
Silence remains preferred whenever a candidate is merely adequate.

### 8.3 Final Pass 1 boundary

Pass 1 ends with exact-file preferred/fallback/reject recommendations for the
physical-core roles it could actually verify. It does not import, register, or
ship those files. Runtime work requires a later implementation plan and must
first reconcile the obsolete route-, mood-, ending-, and stinger-oriented
audio manifest identified by the parent design.

## 9. Failure behavior

- Network, redirect, or download failure leaves the candidate pending; it does
  not trigger a mirror or reupload search.
- An inaccessible Freesound original remains `ORIGINAL_REQUESTED` or resolves
  to silence; a preview is never promoted in its place.
- An archive with unsafe paths or unexpected executable content is not
  extracted.
- An analysis-tool failure records `ANALYSIS_INCOMPLETE`; it does not invent a
  score.
- A missing Godot executable does not block standalone intake analysis, but it
  blocks in-engine TTS ducking and scene verification.
- Hospital ambience and umbrella Foley remain silent/physical until a later
  research pass finds legally clean replacements.

## 10. Verification

Before the pass is complete:

- quarantine roots are ignored by Git and runtime audio paths contain no new
  files;
- every acquired file has a SHA-256 and exact parent-source record;
- every archive member is extracted without traversal or executable content;
- every preview is mechanically barred from approval and runtime export;
- every decision has a listening note or an explicit `UNHEARD` state;
- mono-first ordering and neutral blind IDs are preserved;
- no candidate receives a numeric artistic score without actual listening;
- no account secret appears in files, logs, commands, Git, or reports;
- `AudioManifest`, `AudioManager`, and Godot scenes remain unchanged; and
- documentation validation and `git diff --check` pass.

## 11. Approval record

The user selected the hybrid cull on 2026-08-14 after reviewing three options:
hybrid preview cull, all-exact-original intake, and replacement-only research.
The written specification still requires user review before implementation.
