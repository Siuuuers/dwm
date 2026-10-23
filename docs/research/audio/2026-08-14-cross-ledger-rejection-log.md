# Cross-Ledger Audio Legal Audit and Rejection Log

**Date:** 2026-08-14

**Status:** Research convergence gate passed; zero assets approved or acquired

This audit covers the music, ambience, material/Foley, UI/gameplay, and human
nonverbal ledgers. It is a conservative production record, not legal advice.
Every survivor remains `CONDITIONAL` because no asset was downloaded and no
exact-file checksum, embedded metadata, listening, mono, comfort, or repetition
test exists. The audit therefore authorizes only a shortlist for user review.

## Ledger inventory

| Ledger | Registered roles | Conditional asset entries | Rejected asset entries | Explicit silence/design decisions |
|---|---:|---:|---:|---:|
| Music | 5 | 10 | 9 summarized rejections | 1 authored-silence fallback in prose |
| Ambience | 7 | 11 | 6 | 2 |
| Material/Foley | 12 | 11 | 5 summarized rejections | 1 |
| UI/gameplay | 8 | 8 pack-member selections pending | 3 pack/source rejections | Silence fallback for all 8 |
| Human nonverbal | 3 | 3 | 3 | 3 |

The shared role register contains 35 roles, and every role has at least one
conditional prospect or an explicit silence/visual-only closure.

## Surviving source-family audit

### PeriTune music

- Exact creator track pages and the creator's terms identify Sei Mutsuki /
  PeriTune and the selected pre-March-2026 catalogue as CC BY 4.0.
- Commercial games, adult works, and adaptation are stated as permitted; CC BY
  attribution, license link, and change notice remain mandatory.
- Content ID registration and stand-alone redistribution remain prohibited by
  the creator's terms.
- Exact archive member names and checksums are not yet captured, and the site
  does not provide an explicit track-by-track no-generative-AI certification.
- Result: all seven PeriTune prospects remain `CONDITIONAL`.

### Kimiko Ishizaka Bach recordings

- The exact Wikimedia Commons Ogg pages identify J. S. Bach as composer,
  Kimiko Ishizaka as pianist, the 2015 recording project, and CC0 1.0 for the
  exact masters.
- The creator album description supports the Open Well-Tempered Clavier
  provenance, while Bandcamp's album license field points to CC BY 4.0.
- The two grants both permit commercial adaptation, but the project will
  conservatively attribute as if CC BY 4.0 applies and will use only the exact
  Commons masters.
- A modern edition/arrangement check and acquired-file match still remain.
- Result: both Bach prospects remain `CONDITIONAL`; no other Bach performance
  inherits their clearance.

### Tri-Tachyon on OpenGameArt

- The creator-uploaded exact asset page identifies `Last 31.mp3`, the named
  composer/sound designer, and CC BY 4.0.
- Commercial adaptation is permitted with attribution, license link, and a
  change notice.
- Lossless availability, exact checksum, and listening tests remain unresolved.
- Result: `Last 31` remains `CONDITIONAL`.

### Freesound ambience, Foley, and human recordings

- Every surviving row cites an exact Freesound asset page displaying CC0 1.0
  or, for one hospital ambience, CC BY 4.0.
- No NC, ND, ShareAlike, AI-tagged, GenAI-described, or unclear-license asset
  survives. Field/Foley pages supply an object, action, recorder, microphone,
  room, or comparable physical provenance; human nonverbal rows require a
  creator's affirmative self-recording statement.
- Freesound requires login for many downloads and intermittently gates pages.
  The exact source page, displayed license, original file, metadata, and
  checksum must be captured together during any later authorized acquisition.
- Result: exact assets remain `CONDITIONAL`; the human choir-like role selects
  silence because performer/text/processing evidence did not converge.

### Kenney UI families

- Official `UI Audio` and `Interface Sounds` pages identify Kenney, pack version
  1.0, file counts, audio category, and CC0.
- Kenney's official support page confirms commercial project use and no
  attribution requirement, while reserving the Kenney logo.
- Individual filenames, technical metadata, creation notes, and previews are
  not exposed without downloading the archives.
- Result: both packs are legal discovery leads, but every role-level member
  remains `CONDITIONAL` until an authorized archive inventory and audition.

### Authored silence and visual-only fallback

- Silence and visual state changes contain no third-party asset and require no
  attribution.
- They do not authorize hiding an essential event; every essential cue retains
  its physical, visual, or natural textual equivalent.
- Result: silence remains available at every role and is already the preferred
  research decision for campus-social ambience, conservatory ambience when an
  empty source is required, and all human nonverbal roles.

## Deduplicated rejection log

| Rejected class or source | Gate | Decision |
|---|---|---|
| Mixkit stock music | Platform permission | `REJECTED`: official music guidance does not permit video-game use; this does not reject Mixkit SFX generally. |
| CC BY-NC / Attribution-NonCommercial assets | Commercial permission | `REJECTED`: examples include the searched button click and plastic-package recording. |
| CC BY-ND / NoDerivatives assets | Modification permission | `REJECTED`: trimming, fades, gain, loop work, and conversion cannot be guaranteed. |
| CC BY-SA / ShareAlike or other copyleft assets | Project policy | `REJECTED`: project policy excludes downstream share-alike ambiguity. |
| “No copyright,” royalty-free without exact terms, social reuploads, YouTube mirrors | Source and license evidence | `REJECTED`: neither exact ownership nor commercial adaptation is verifiable. |
| Generic public-domain classical downloads | Rights layers | `REJECTED`: composition age does not clear edition/arrangement, performance, or master. |
| Kimiko Ishizaka, *The Art of the Fugue* collection | Conflicting metadata and modern contribution | `REJECTED pending clarification`: album/track rights conflict and the final fugue contains a modern completion. |
| AI/GenAI audio, Freesound generated tags/descriptions, synthesized or cloned voices | Provenance | `REJECTED`: the project uses no AI-generated audio; the Freesound synthesized birthday choir is a documented example. |
| Unknown choir performers/text or unverified performance rights | Human/underlying rights | `REJECTED`: recorder-level CC0 alone does not prove every performer/text layer is cleared. |
| Unidentified crowd/clinical speech, patient moaning, television, announcements | Privacy, narrative source, and comfort | `REJECTED`: recordings invent people, diagnosis, crisis, or dialogue absent from the scene. |
| Baked music, choir, beeps, sci-fi telemetry, cinematic impacts | Editability and source visibility | `REJECTED`: the desired physical action cannot be separated cleanly from authored context. |
| Generic metal click used as a clasp | Physical truth | `REJECTED`: the searched sound was a piezo recording of a struck railing, not a clasp action. |
| Thunderstorm rain for a passing sheltered shower | Comfort and tone | `REJECTED`: thunder and roof impact produce cinematic weather emphasis and loudness contrast. |
| Kenney Digital Audio and Casino Audio for UI/Minesweeper | Semantic family | `REJECTED`: space/laser and casino/reward language conflict with neutral literary UI. |
| Grand choral, battle, gothic-waltz, music-box, or obvious “ominous” scoring | Artistic restraint | `REJECTED` when the track instructs horror/romance rather than leaving interpretation open. |

## Scan results

The 2026-08-14 repository scan found forbidden-license/provenance terms only in
policy text, rejection records, or explicit statements that a candidate has no
such tag. It found no unfinished-marker or informal-safety claim in any
candidate entry. Markdown whitespace checks passed.

## Gate decision

The research package may proceed to a **conditional audition-priority packet**.
It may not label any audio asset `APPROVED FOR ACQUISITION REVIEW`, authorize a
download, or begin Godot integration. Those actions require the user's next
decision and a same-session capture of the exact source/license evidence.
