---
id: spec.steam_store_page.copy_and_capture_architecture
kind: design_specification
schema_version: 1
conversational_design_status: approved_core_store_page_design
written_spec_status: approved
written_spec_approved_on: 2026-08-30
written_spec_approved_revision: 084a801c88a5d0cd66e93c608c3bf341137fa392
self_review_status: passed
self_reviewed_on: 2026-08-30
copy_gate_status: locked_pending_evidence
short_description_sha256: d0a5d5eee0ffafc77abe79f4800c02b5136ba9fb5184611c7b6c078215fd3491
about_visible_text_sha256: 497ec25c05cf3051c47447904e012758a8889ab204691cd19cca385a847444bd
implementation_requested: false
implementation_authorized: false
store_review_submission_authorized: false
coming_soon_publication_authorized: false
publication_authorized: false
release_authorized: false
created_on: 2026-08-30
steam_requirements_checked_on: 2026-08-30
scope: steam_store_page_copy_and_capture_architecture
---

# Steam Store Page Copy and Capture Architecture

## 1. Status and objective

The owner approved the core page design on 2026-08-30: the direct-release
positioning, locked English copy, disclosure boundaries, Single Echo reuse,
and five-role screenshot architecture. This document preserves those choices
for written review. Its test thresholds, evidence-manifest rules, and release
gates are proposed safety controls introduced during self-review; they become
design authority only if the owner approves this exact written revision.

This document approves no Steam submission or publication, asset generation,
final screenshot, public title, price, trailer, tag set, language claim,
content-survey answer, or build release.

The objective is a mystery-first Steam page for the game's direct full release.
It must make the playable form and emotional pressure legible without turning
the page into a plot synopsis, character catalogue, route selector, feature
checklist, or decoding guide.

The page follows one governing editorial law:

> **Facts definite; emotional causes non-final.**

Copy approval does not establish that a claim or image exists in the game.
Every public element remains evidence-gated against an identified release
candidate.

## 2. Scope and authority

### 2.1 In scope

This specification fixes:

- the approved Short Description and About This Game copy;
- the page's disclosure and voice rules;
- the About-section image placement and reuse policy;
- the five-screenshot narrative and disclosure architecture;
- asset-authenticity, accessibility-text, and spoiler-audit rules;
- the direct-full-release presentation boundary; and
- the gates that must pass before the page or release becomes public.

### 2.2 Outside this specification

The following remain separate design or release tasks:

- the secret public title and its clearance;
- capsule art, logo treatment, and optional page background;
- trailer concept, edit, music, captions, and shot list;
- tags, price, public release date, platforms, and system requirements;
- exact supported-language rows and localized store copy;
- final content-survey answers;
- final screenshot source scenes for slots 2-5; and
- Steamworks data entry or publication.

An outside-scope item cannot satisfy a gate merely by existing. Its governing
artifact, final output, and evidence must receive the separate owner approval
required by sections 10-12.

The absence of an item from this specification grants no permission to invent
it. Narrative authority remains with the story Bible, approved causal records,
final authored dialogue, and verified runtime behavior. A reaction test,
library candidate, unselected premise, placeholder, or executable drift is not
public-source authority.

### 2.3 Current project evidence

The design is grounded in the following project authorities:

- [Core Story Bible](../../../story/01-core-story-bible.md);
- [Character and Relationship Handbook](../../../story/02-character-relationship-handbook.md);
- [Public Project Profile](../../../story/04-public-project-profile.md);
- [Seven-Day Scene Beatbook](../../../story/06-seven-day-scene-beatbook.md);
- [Seven-Day Causal Matrix](../../../story/07-seven-day-causal-matrix.md);
- [Seven-Day Flow and Dialogic Structure](../../design/2026-08-07-seven-day-dialogic-flow-design.md);
  and
- the accepted current-UI dossiers under
  [`docs/design/current-ui/`](../../design/current-ui/README.md).

The current design record does not yet prove a publishable store package. The
central seven-day specification separates conversational approval from
implementation and verification. The Causal Matrix has approved Day 1
placement while twelve of fourteen encounter windows remain `UNSELECTED`.
Exact final dialogue, staging, captures, and launch-build parity therefore
remain publication evidence rather than assumptions.

## 3. Release strategy

The product launches as a complete **1.0 full release**, not Early Access.

- Pre-release testing is private testing, not a saleable unfinished release.
- The launch build must be complete and worth its price on launch day.
- Optional post-launch additions may be made when useful, but the page promises
  no roadmap, future feature, or feedback-dependent completion.
- Early Access branding, questionnaire copy, crowdfunding language, and
  invitations to help finish the game are prohibited.

## 4. Positioning and voice

### 4.1 Public promise

The page promises a compact romantic psychological-horror visual novel in
which attention is limited, offscreen events can have consequences, and logic
play occurs inside relationship encounters. It promises uncertainty of
interpretation, not random causality or a final master solution.

### 4.2 Voice rules

- Mystery comes from exact relations among ordinary facts, not vague ominous
  adjectives.
- Romance appears before horror; danger remains inside care, timing, distance,
  absence, and changed circumstances.
- The page shows what can be experienced and withholds the explanation that
  would join those experiences.
- The prose stays plain, intimate, restrained, and free of self-praise.
- Robbe-Grillet and *La Jalousie* remain private compositional disciplines:
  observable surfaces, altered recurrence, and non-final motive. The page does
  not imitate their sentence texture or name-drop an influence.
- The exact genre phrase is **romantic psychological-horror visual novel**.
- **Minesweeper-style** appears exactly once across the public copy.
- The copy uses no second-person marketing.
- The page does not advertise absent features. In particular, it does not call
  out the absence of recorded character voice acting.

### 4.3 Disclosure exclusions

Public copy and assets must not disclose or imply:

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

Mandatory platform and content disclosures outrank mystery preservation. This
section limits creative marketing copy; it never permits an inaccurate Steam
survey, rating, language, or mature-content answer.

## 5. Locked public copy

### 5.1 Short Description

The Short Description is one plain-text paragraph:

> This romantic psychological-horror visual novel spans seven days in which Angela may answer messages, keep or miss appointments, and work through compact logic boards while events elsewhere do not wait.

The string contains 202 characters including spaces and punctuation. Valve's
public documentation describes the field only as `a few hundred characters`;
the live Steamworks editor is the final limit authority at entry time.

### 5.2 About This Game

The public sequence is exact:

> During a seven-day university Open Week, messages arrive, appointments overlap, and ordinary records refuse to agree. Angela is present for only part of what happens.
>
> The week unfolds through messages, appointments, and compact Minesweeper-style logic boards. Angela may answer, revisit, attend, miss, or leave things alone.
>
> A romantic psychological-horror visual novel about attention, absence, and the danger of being understood too precisely.

Insert the one publication-gated About image slot described in section 6.2.
It receives no visible caption.

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

### 5.3 Copy integrity

- `Events continue elsewhere.` remains deleted from the About opening; the
  Short Description and second law already carry that relation.
- The second law uses `can`, not an absolute assertion that every offscreen
  event creates public evidence.
- The carrier inventory of messages, objects, records, and changed
  circumstances remains deleted; it would turn the carousel into an
  illustrated clue guide.
- The earlier interface sentence remains deleted; together with `revisit` and
  the screenshot sequence it would cast too clear a shadow of hidden
  comparison behavior.
- The two-hour sentence is copy-approved but not publishable until section
  9.1 passes.
- The atmosphere sentence is copy-approved but not publishable until section
  9.2 passes.
- Failure of a claim gate does not authorize silent editing. It changes the
  copy state to `revision_required`; revised wording or deletion returns to
  owner review before this specification can again become publication-ready.

The copy state machine is explicit:

- `locked_pending_evidence` is the current state for owner-approved wording
  whose release-candidate claim tests have not all been run; it blocks every
  submission or publication gate without treating the wording as disproved;
- a failed claim test, or a package nominated for Store review while a factual
  clause remains unproved, sets `revision_required`;
- an owner-approved revision or deletion returns to
  `locked_pending_evidence`; and
- complete passing claim evidence sets `verified_for_manifest` with the
  concrete manifest ID recorded beside it; that state expires under section
  9.4 whenever the manifest is invalidated.

### 5.4 Canonical copy fingerprints

The independent copy comparator is SHA-256 over UTF-8 without a byte-order
mark or terminal newline. Do not apply Unicode normalization.

- The Short Description payload is the one visible line in section 5.1. Its
  SHA-256 is
  `d0a5d5eee0ffafc77abe79f4800c02b5136ba9fb5184611c7b6c078215fd3491`.
- The About visible-text payload is the ten visible prose blocks in section
  5.2, in order, joined by exactly two LF bytes. Remove the Markdown quote
  prefix and the three bold delimiters; exclude the editorial image-insertion
  sentence and the image itself. Its SHA-256 is
  `497ec25c05cf3051c47447904e012758a8889ab204691cd19cca385a847444bd`.

The structural comparator separately requires the one image after block 3 and
before block 4, with blocks 4, 6, and 8 as the only bold headings. No other
block, caption, leading/trailing whitespace, or formatting substitution is
permitted.

## 6. Page architecture and About image

### 6.1 Quiet Descent

The About section descends through:

1. observable disturbance;
2. playable form;
3. emotional proposition;
4. one ordinary intimate image;
5. three quiet laws; and
6. a factual coda.

It uses no feature-bullet catalogue, character cards, route table, relationship
statistics, ending counter, or sales-call ending.

### 6.2 Single Echo

The screenshot carousel will own five publication-approved source masters.
Only carousel source master 1 is reused in About, after the three opening
paragraphs and before the three laws. There is no second embedded image.

- Reuse identity means the same depicted frame, composition, and visible
  content—not necessarily byte identity after Steam transcoding. Prefer the
  same uploaded file. If technical resizing, compression, or format conversion
  is required, record both hashes and the derivative's parent-master hash.
- Do not create an alternate frame, content crop, recolour, composite, blur,
  retouch, or promotional overlay.
- A technical derivative receives the same visual and disclosure audit as its
  source master.
- Do not place explanatory copy about the bottle, water, preference, Sylvia,
  preparation, or harm beside the image.
- Leave sufficient visual space before the laws so they do not read as a
  diagnosis of the pictured gesture.
- If the final approved frame visibly matches the intended staging, its locked
  internal literal description is:

  > Two hands pause over a sealed bottle on a table.

- Verify that text against the final uploaded frame and every localization. If
  the frame differs, the revised literal description requires owner approval;
  image approval never authorizes an inaccurate alternative representation.
  This is production and accessibility documentation, not a claim that the
  current Steam About editor exposes public image-alt text. Publish it only if
  the live platform supplies an appropriate accessibility field.

The image has no public title. `The Interrupted Gesture` is an internal capture
role, not a caption or accessibility label.

## 7. Five-screenshot architecture

The internal architecture is **The Evidence Wake**. The name and all five slot
names remain private. The public carousel contains screenshots without
interpretive captions.

Its sequence grammar is:

> **contact -> play -> speech -> absence -> residue**

The images are separate examples of the game's grammar. They must not look like
consecutive scenes, incompatible branches presented as one story, or a compact
plot synopsis.

### 7.1 Slot 1: The Interrupted Gesture

**Function:** tactile romance with unease contained inside an ordinary pause.

**Safest grounding:** the approved Day 1 `Both Temperatures` premise. The
candidate frame shows an ordinary sealed bottle, a placing hand not fully
withdrawn, and Angela's hand paused before contact.

**Conditional boundary:** the exact two-hand staging is not yet final authored
or shipped fact. Use it only if final staging and the release build genuinely
contain it.

**Exclude:** revealing dialogue, the two-bottle offset, preference language,
an opened or consumed bottle, badge, welfare kit, medical imagery, blocked
movement, gripping, distress, outcome, or overt horror styling.

### 7.2 Slot 2: The Held Conversation

**Function:** prove that compact logic play belongs inside a relationship
encounter rather than in a detached minigame.

Show a genuine, playable, nonterminal board over the frozen witnessed scene.
The underlying encounter must differ from slot 1.

**Exclude:** terminal results, score, efficiency, special cells, hidden mines,
relationship outcomes, statistics, special-cursor behavior, Capture/Compare,
save/replay rules, Observer grammar, or a private Priscilla-Lavinia board.

The internal literal description is `A compact logic board overlays an ongoing
conversation.` It is not public alt text unless a future Steam surface that
supports accessibility text uses this image and the final frame verifies the
description.

The function is locked; the exact encounter, board, and source frame are
intentionally unselected until an approved, final-build candidate passes
section 8.

### 7.3 Slot 3: A Sentence Left Uncorrected

**Function:** show character voice through one restrained correction, refusal,
or incomplete agreement in an ordinary interaction.

The final frame must use approved final dialogue and natural shipped framing.
It may show an expressive face or restrained body response.

**Exclude:** plot-bearing proof fields, duplicated or changed versions of a
line, comparison/history UI, biography, private history, relationship label,
outcome wording, or reaction-test prose.

The function is locked; the exact source scene is intentionally unselected
until an approved, final-build candidate passes section 8.

### 7.4 Slot 4: A Message Without Coordinates

**Function:** prove that messages and withholding matter through one compact
exchange or changed silence.

Use the normal Contacts presentation and final shipped wording.

**Exclude:** city, country, university name, major, travel history, arrival or
return schedule, attachment, timestamp chain, invitation menu, schedule state,
route roster, or an unsent draft from a protected sequence.

The function is locked; the exact source scene is intentionally unselected
until an approved, final-build candidate passes section 8.

### 7.5 Slot 5: The Room Still in Use

**Function:** end on continued life through one mundane consequence: an object
slightly displaced, a task still active, or a space altered by recent action.
It is residue, not a highlighted clue.

**Exclude:** Hospital, fainting, endings, Gallery, Day 7 destination, hidden
pairing, private-offscreen knowledge, cursor irregularity, welfare slip,
check-in prompt, key, umbrella, cup, coat, prepared chair, or paired folder.

The function is locked; the exact source scene is intentionally unselected
until an approved, final-build candidate passes section 8.

## 8. Capture provenance and mosaic review

### 8.1 Per-capture provenance

Each master screenshot must record:

- release-candidate build and source commit;
- operating system and resolution;
- semantic scene or entry identifier;
- legal run/day/slot and branch setup;
- final visible dialogue or UI identifier;
- board phase and seed when a board is visible;
- capture timestamp; and
- untouched master-file hash, plus parent and derivative hashes for any
  technically converted About upload.

The source must be a legal release-build play state. Debug controls, Rehearsal,
mock interfaces, concept art, AI reconstructions, staged false screenshots,
pre-rendered marketing stills, and composited scenes are prohibited.

If hiding a datum requires blur, repainting, object removal, UI suppression, or
a misleading crop, reject the frame and capture another legal state.

### 8.2 Whole-page mosaic review

Review each screenshot alone and all 26 non-singleton combinations of the five
masters: ten pairs, ten triples, five quadruples, and the complete set. A
manifest-driven review sheet makes this reproducible: it presents the exact,
hash-verified masters in carousel order without crop or annotation, alongside
unchanged renderings of the copy and every non-screenshot public surface. Save
the sheet-template version and all generated sheets as evidence for each
locale. Review every non-screenshot public asset alone as well.

The complete five-shot assembled audit then uses Steam's actual preview, not a
local approximation. It includes media ordering; the first two valid trailers
before screenshots; trailer posters, thumbnails, and microtrailer material;
and the final page background. If no custom background is supplied and Steam
derives one from the last screenshot, audit the generated result and its
repetition of that master. The optional background and trailer designs remain
outside this specification, but their public effects are inside the
publication gate.

Reject any standalone element that discloses a protected conclusion. Also
reject the package if a combination supports one that no single element
states, including:

- the bottle contains or causes harm;
- Sylvia prepares or causes Angela's collapse;
- Priscilla and Lavinia cohabit or form the concealed autonomous pair;
- dialogue can be captured and compared across runs;
- the premature-record chronology is solved;
- a hidden score, tier, special mine, anti-reload law, or ending gate exists;
- the city, Angela's major, character genders, or invitation architecture can
  be reconstructed; or
- five genuine but incompatible frames appear to form one canonical story.

Because slot 1 uses the bottle grammar, no later public asset may combine it
with Hospital imagery, welfare materials, prepared medical or institutional
records, bodily harm, or another Sylvia-preparation escalation. Slot 2 must use
a different encounter and contain no bottle residue.

The intended inference envelope is:

> A seven-day romantic psychological-horror visual novel in which messages,
> missed presence, dialogue, and compact logic boards have consequences that
> Angela cannot fully control.

Genre, duration structure, playable forms, and limited attention are the
minimum core. The sentence is not permission for an additional specific fact,
cause, chronology, relationship, or hidden system outside approved public
copy.

### 8.3 Cold-reader protocol

Every supplied store-page locale receives its own documented blind
comprehension test against that locale's final Steam preview. An unchanged
English fallback is covered by the English test; any selected localized public
copy requires a separate cohort. Do not expose one participant to multiple
locale variants.

For each locale, before recruitment, freeze an exact cohort size of at least
eight, the recruitment window, qualification and session-exclusion rules,
stopping rule, and coding codebook. Participants are adults fluent in the page
language for that locale who have not read private project documents and have
not played a development build. Exclude a session only if the person withdraws
before seeing the page or an external display failure prevents page exposure.
Once a person sees the page, retain the session and count every missing answer
as a failed recognition; do not extend enrollment after results are known.

Each participant views the page independently, without an explanatory
introduction, and answers the same open questions:

1. What kind of game is this?
2. What does the player appear to do?
3. What seems to happen in the story?
4. What facts, causes, relationships, or hidden systems does the page appear to
   reveal?

The questions and frozen codebook receive owner-approved, meaning-equivalent
localization. The codebook defines acceptable genre synonyms, the four
activity classes, each required inference component, and protected or
otherwise non-public specifics. Two fluent reviewers independently code the
responses against the inference envelope and section 8.2. A third fluent
reviewer adjudicates disagreement. The localized page passes when:

- at least 75 percent, and no fewer than six participants, each identify the
  genre, the seven-day structure, at least two of messages, appointments,
  dialogue, or compact logic play, and the high-level limit on Angela's
  presence or control;
- no participant states a protected conclusion as likely or definite;
- across the entire cohort, at most one participant makes any spontaneous
  protected-conclusion speculation without treating it as supported; and
- no two participants share any additional specific inference about a
  non-public fact, cause, chronology, relationship, hidden system, or false
  feature.

Failure returns the affected copy or asset package to design review. The
locale, copy hash, raw answers, coding, reviewer decisions, preview revision,
and asset hashes become part of the publication evidence. The owner or
designated spoiler authority signs each locale's final coding and
protected-conclusion assessment.

## 9. Claim verification

### 9.1 Playtime

Publish the two-hour sentence only after at least eight blind first-time
players complete a legal initial passage through the release candidate. They
must not have seen the duration claim or been told the two-hour hypothesis.
Before recruitment or testing begins, freeze the cohort size, coverage target,
and a timing protocol that:

- starts when the player confirms a new game and ends at the first stable
  post-ending screen or return to the main menu;
- records and excludes only participant-reported or observer-confirmed
  away-from-game pauses longer than 60 seconds; lack of input while reading,
  deciding, or solving remains play time;
- prohibits skipping unseen text while allowing each participant's ordinary
  reading speed and chosen accessibility settings;
- records assistance settings, branch setup, board outcomes, and excluded
  idle time for every run; and
- covers at least three distinct legal appointment-attendance profiles and at
  least two distinct board-outcome profiles, with no single profile supplying
  more than half of the included runs within either category.

Freeze whole-run exclusion rules in the same protocol. A run may be excluded
only for withdrawal before build launch or an external interruption or
hardware failure unrelated to the build. A participant who stops after launch
for a product-related reason, or a crash, softlock, corrupted state, or other
product failure, fails the candidate instead of disappearing from timing data.
Retain every attempt and its disposition; do not select favorable runs after
results are visible.

The claim passes when the median across the entire included cohort is 105-135
minutes and at least 75 percent of included runs fall between 90 and 150
minutes. Developer familiarity, skipped dialogue, partial builds, design
estimates, or completionist timing cannot support the claim. A failed test
changes the copy state to `revision_required`; a truthful measured range or
deletion must return to owner review. Do not publish the five-hour completion
target, route/ending counts, or completion percentages.

### 9.2 Audio

Publish `Ordinary sounds and silence shape the atmosphere.` only after the
release-candidate mix demonstrably uses approved ordinary sound and intentional
silence across representative play. The test package must include the opening,
one contacts or appointment interval, at least two middle-day witnessed scenes,
one board transition, one intentionally quiet interval, and one ending.

Before recruitment, freeze the cohort size, exact package, hardware coverage,
and whole-session exclusion rules. Retain every attempt and disposition; use
the same exclusion boundary as section 9.1 and prohibit post-result selection.
A cue-and-mix log identifies, with timestamps, both the approved ordinary
sounds and the intentional quiet intervals present in the tested build.

At least five blind participants play that package with the intended default
mix, without an explanation of the audio design, then answer the unprompted
question `What contributed to the atmosphere?` The claim passes when at least
80 percent, and no fewer than four, identify both ordinary sound and
intentional silence, or explicitly identify the atmospheric relation between
them. Any reproducible missing, broken, painfully imbalanced, or narratively
contradictory audio fails the test. The owner or designated audio reviewer must
also approve the final cue-and-mix log. A failed test changes the copy state to
`revision_required`; revised wording or deletion must return to owner review.

The evidence records build, OS, output device, audio settings, session, raw
answer, and defect result for every participant. Separate technical passes
cover every listed operating system and both intended headphone and speaker
output when both are supported.

Every shipped asset needs source and license evidence, exact-file approval,
edit and attribution records where required, comfort and repetition testing,
and verification alongside accessibility read-aloud behavior. Plot-important
audio retains a visual equivalent. As a conservative project policy, do not
mark Steam `Full Audio` merely because the build has sound effects or optional
text-to-speech; resolve the field from the live editor's definition and tested
shipping voice support.

### 9.3 Claim-to-build matrix

Before submission, map every factual public clause to reproducible
release-candidate proof, including:

- seven playable days;
- messages and answering or leaving them alone;
- appointments and keeping, attending, or missing them;
- revisiting;
- compact logic boards inside encounters;
- offscreen continuation and lawful residue;
- recurring replies in other observable forms;
- disagreeing ordinary records; and
- the promised initial duration and atmospheric soundscape.

For each claim, record build, OS, setup, expected observation, and result. While
testing is genuinely pending, an unproved claim keeps
`locked_pending_evidence` and blocks all readiness gates. A failed claim, or an
unproved claim in a package nominated for Store review, sets
`revision_required` and returns the affected copy to owner review for truthful
revision or deletion. Do not add a future-feature footnote or silently edit
locked copy.

### 9.4 Immutable manifests and change invalidation

Every readiness decision evaluates one immutable, uniquely identified evidence
manifest. The store-package portion records:

- exact Unicode copy and localization bytes plus hashes;
- public title, clearance record, tags, language-support cells, system
  requirements, survey answers, displayed release-date state, and price state;
- every capsule, icon, library asset, screenshot master and derivative, About
  image, trailer transcode, poster, thumbnail, and their hashes and order;
- the Steamworks preview revision and captures of selected or generated visible
  surfaces, including background and microtrailer material; and
- the governing owner-approved artifacts for every outside-scope item.

The build portion records the source commit, release build ID, depot manifests,
engine and addon versions, exported platform artifacts and hashes, test
commands, result counts, claim evidence, and evidence-artifact locations.

Any change to copy, localization, metadata, asset bytes or order, tags, survey
answers, language cells, platform fields, build, Steam transcode, or generated
surface invalidates the directly affected evidence and every downstream gate
or authorization. Re-run the affected claim, provenance, mosaic, localization,
preview, and owner reviews against a new manifest. Apparent equivalence is not
an exemption; a recorded technical derivative follows section 6.2.

Passing a gate never grants external-action authority by itself. The owner must
separately authorize the exact manifest ID for Store review submission, Coming
Soon publication, and final release. Each authorization expires when its
manifest is invalidated.

## 10. STORE_REVIEW_SUBMISSION_READY gate

Every item below must pass before marking Store Presence ready for Valve
review. This gate does not authorize or expose a public Coming Soon page:

This is deliberately stricter than Valve's minimum path. Because the approved
copy makes build-dependent claims and the visual design permits only genuine,
final-authority captures, it favors evidentiary integrity over an earlier
wishlist runway. Approving this written specification approves that tradeoff;
an earlier Coming Soon strategy would require separately approved copy,
capture, and gate revisions rather than placeholder evidence.

1. **Release mode:** the page describes a complete direct 1.0 release and
   contains no Early Access or feedback-dependent-completion language.
2. **Public title:** the title has completed the chosen clearance process, the
   owner has approved it and explicitly authorized its disclosure, and
   Steamworks, metadata, capsules, trailer, and localized surfaces agree. Do
   not submit the internal name `DWM` or invent a temporary title.
3. **Outside-scope artifacts:** capsules, trailer, tags, localized copy,
   language matrix, survey answers, displayed release-date state, platforms,
   and system requirements each have their required owner-approved artifact
   and final evidence.
4. **Canon and authorship:** every visible line, prop, gesture, room, message,
   and UI label has approved canon, final authored wording, approved staging,
   and implementation in the identified release candidate.
5. **Copy proof:** every public clause passes section 9.3, and the copy state is
   `verified_for_manifest` for this exact submitted manifest ID.
6. **Screenshot set:** five genuine masters pass sections 7 and 8.
7. **Single Echo:** only the exact approved slot-1 master repeats in About; no
   second embedded image or visual/content variant exists. A tracked technical
   derivative permitted by section 6.2 is not a second composition.
8. **Timing and audio:** sections 9.1 and 9.2 pass. If either fails, the revised
   coda or deletion has received owner approval and the replacement has passed
   all applicable copy and claim gates.
9. **Localization:** Interface, Subtitles, and Full Audio are declared
   independently by support category and only from tested shipping behavior.
   For every declared cell, the manifest identifies the source catalog and
   version, required-content count, approved intentional-fallback allowlist,
   and build coverage. No required string or audio asset is missing outside
   that allowlist. Font, glyph, input, overflow, fallback, subtitle, and audio
   behavior pass on every listed OS. Embedded Cantonese or Romanian does not
   create a whole-game language claim.
10. **Steam package:** every asset required by the live checklist is complete,
    not only the four store capsules and five screenshots. All three Content
    Survey sections are complete and accurate: general content; mature content,
    including inaccessible adult material in uploaded builds; and AI-assisted
    pre-generated content shipped to and consumed by players plus any
    live-generated content and its guardrails.
11. **Whole-page audit:** the copy, captures, capsules, trailer, tags, every
    localization, the actual Steam preview, and each selected or
    Steam-generated visible surface pass the mosaic review together.
12. **Submission authority:** after seeing that exact preview and manifest, the
    owner explicitly authorizes its Store review submission by manifest ID.

If the live Content Survey selects `Adult Only Sexual Content`, follow Valve's
conditional path: both a completed store page and completed build must be
submitted for review before Valve will mark the store page ready for release.

Current project evidence does not satisfy this gate. In particular, exact
later-day screenshot sources, final dialogue and staging, screenshot masters,
release-candidate playtime evidence, approved audio masters, complete language
support, title clearance and disclosure approval, capsules, trailer, the exact
manifest, and submission authority remain unverified or outside this
specification.

## 11. COMING_SOON_PUBLICATION_READY gate

After Valve approves Store Presence, every item below must pass before clicking
`Post as Coming Soon`:

- Valve's approval applies to the submitted manifest, and any subsequent edit
  has completed its required invalidation work and any required re-review;
- the actual approved Steam preview, generated background, media order,
  trailer-derived surfaces, localization, and platform metadata still match
  the audited manifest;
- the owner has reviewed that exact public package and explicitly authorized
  Coming Soon publication by manifest ID; and
- the planned public timing has a record owner, timezone, and correction plus
  Steam Support contact procedure for a material page defect.

Record Steam's actual Coming Soon publication timestamp. Passing Store review
does not grant publication authority, and written-spec approval cannot satisfy
this gate.

## 12. FULL_RELEASE_READY gate

The direct 1.0 release additionally requires:

- a mostly final, stable, feature-complete build containing every advertised
  feature and starting correctly on every listed operating system;
- complete Store Presence and build/configuration checklists, both reviewed and
  approved by Valve;
- the required fully encoded trailer, with every shot passing the same
  provenance and mosaic audit;
- the recorded Steam Coming Soon timestamp proving at least 14 full days of
  public availability before release;
- every required project test, dialogue/manifest check, and prescribed full-run
  smoke named in the immutable release manifest passing, with the exact command,
  engine/addon versions, build hash, result counts, and evidence location; and
- a final reconciliation of survey answers, language matrix, OS list, tags,
  copy, images, trailer, price, date, platform fields, and build.

The release lock occurs only after the final build upload and reconciliation.
The owner then reviews and explicitly authorizes the exact locked release
manifest. Any later mutation breaks the lock, invalidates the affected gates,
and requires a new authorization before the release action.

## 13. Steam technical constraints

These constraints were verified against Valve's official documentation on
2026-08-30 and must be rechecked before submission:

- Supply at least five actual-gameplay screenshots, each 16:9 and at least
  1920x1080. Do not use concept art, pre-rendered cinematic stills, awards,
  marketing copy, or written product descriptions in screenshot slots. Review
  every screenshot age-suitability flag truthfully; where the content genuinely
  qualifies, identify at least four as suitable for all ages.
- The four required store capsules are Header 920x430, Small 462x174, Main
  1232x706, and Vertical 748x896. They must remain suitable for a PG-13 audience.
  Valve permits the game name and an official subtitle; this project uses only
  the approved title/logo unless a subtitle treatment receives separate
  approval. These four are only the store-capsule subset: also supply every
  shortcut/app icon and Library capsule, hero, logo, header, or other asset
  required by the live checklist.
- Keep the Short Description plain text and within the live editor's limit.
- Each About image remains below 5 MB; keep combined embedded screenshots and
  GIFs below 15 MB. Textless imagery avoids localization duplication.
- Descriptions and images contain no external links, implied URLs, QR codes,
  fake Steam buy/wishlist interface, or advertisements for other products.
- Declare actual in-game Interface, Subtitles, and Full Audio support
  independently for each language.
- A custom trailer poster or thumbnail must be an actual 1920x1080 frame from
  that trailer.
- Complete all three Content Survey sections. General and mature answers must
  match the uploaded product, including inaccessible adult material where
  Valve requires it. The generative-AI section covers AI-assisted pre-generated
  content that ships to and is consumed by players and any live-generated
  content and guardrails; answer the live questions exactly rather than treating
  unrelated productivity-only tools as shipped content.
- In the ordinary path, submit Store Presence for review before submitting the
  build for review. After Valve approval, the owner separately posts it as
  Coming Soon. `Adult Only Sexual Content` invokes the conditional joint-review
  path in section 10. Both Store Presence and the build need approval before
  release, and Coming Soon must remain public for the required minimum period.
- This project deliberately requires a trailer before Store review submission
  so the assembled page can be audited. Valve describes a trailer as ideally
  present for Coming Soon and requires a fully encoded trailer for release.

Official sources:

- [Store Graphical Assets](https://partner.steamgames.com/doc/store/assets/standard?l=english)
- [Graphical Asset Overview](https://partner.steamgames.com/doc/store/assets?l=english)
- [Graphical Asset Rules](https://partner.steamgames.com/doc/store/assets/rules?l=english)
- [Written Description](https://partner.steamgames.com/doc/store/page/description?l=english)
- [Extra Asset Management](https://partner.steamgames.com/doc/store/page/assets?l=english)
- [Localization and Languages](https://partner.steamgames.com/doc/store/localization?l=english)
- [Review Process](https://partner.steamgames.com/doc/store/review_process?l=english)
- [Release Process](https://partner.steamgames.com/doc/store/releasing?l=english)
- [Trailers](https://partner.steamgames.com/doc/store/trailer?l=english)
- [Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey?language=english)
- [Coming Soon](https://partner.steamgames.com/doc/store/coming_soon?language=english)

## 14. Rejected alternatives

- **Early Access:** rejected in favor of a complete direct release and private
  testing.
- **Seven unique public images:** rejected because two extra About-only frames
  increase disclosure and authorization burden.
- **Two exact About repeats:** rejected because the owner preferred less reuse.
- **Cropped or altered repeats:** rejected because they magnify details and can
  imply a framing that never exists during play.
- **Text-only About:** rejected as too austere; Single Echo preserves one
  emotional anchor.
- **Feature bullets:** rejected because they turn the page into a checklist.
- **Character cards or route pitches:** rejected because they pre-classify
  relationships and encourage route shopping.
- **Interface hint sentence:** removed because the complete page made the
  hidden comparison grammar too recoverable.
- **Voice-acting absence disclosure:** removed because it spends scarce copy on
  an absent, non-distinctive feature.
- **Full-completion duration:** rejected because it encourages checklist play.
- **Public interpretive screenshot names:** rejected because they label how the
  audience should read each frame.

## 15. Written-spec acceptance criteria

This written design is ready for owner review when:

- the canonical Short Description and About payloads reproduce both section
  5.4 hashes and its image/heading structure;
- every conditional statement has an explicit verification or owner-reviewed
  revision/deletion path;
- no placeholder, invented title, exact unapproved screenshot source, or
  future-feature promise appears;
- copy architecture and capture architecture agree;
- the public/private label boundary is explicit;
- the Steam requirements are sourced and dated; and
- proposed verification controls are distinguished from the conversationally
  approved core design;
- Store review submission, Coming Soon publication, and final release are
  distinct owner-authorized transitions tied to immutable manifests; and
- approval of the specification cannot be mistaken for implementation or any
  external-action authorization.

Owner review applies to the exact committed revision named in the review
handoff. Any later content change returns the written specification to review.
