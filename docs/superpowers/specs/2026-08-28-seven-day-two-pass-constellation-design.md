---
id: spec.seven_day_two_pass_constellation
kind: design_specification
schema_version: 1
conversational_design_status: approved
written_spec_status: approved
self_review_status: passed
implementation_requested: true
implementation_authorized: true
implementation_plan_path: "docs/superpowers/plans/2026-08-28-seven-day-constellation-documentation-reconciliation.md"
implementation_plan_status: approved
implementation_plan_sha256: "d0b0e1ce8e4bae1bb07f0553d905d074754d7f16b6e0899b6813fa6a56c441c2"
implementation_execution_mode: subagent_driven
implementation_approved_by: project_owner
implementation_authorization_state: approved
implementation_authorization_scope: seven_day_documentation_reconciliation_tasks_0_through_9_only
implementation_base_commit: 8642da2a7e404622dbb716d19a6bf49ded7cd852
implementation_plan_approved_on: 2026-08-28
implementation_authorized_on: 2026-08-28
implementation_commit_authorized: true
implementation_commit_approved_by: project_owner
implementation_commit_scope: exact_path_boundaries_in_approved_plan_only
implementation_commit_authorized_on: 2026-08-28
implementation_plan_created_on: 2026-08-28
created_on: 2026-08-28
written_spec_approved_on: 2026-08-28
verification_staging_clarified_on: 2026-08-28
scope: seven_day_narrative_documentation_reconciliation
---

# Seven-Day Two-Pass Constellation Design

## 1. Status and objective

This document records the approved method for developing the Day 1 through Day 7
main plot without prematurely making attractive scene ideas canonical. Its purpose
is to reconcile the existing narrative documents with the approved seven-day
mechanics, freeze the week-wide causal obligations, and then audition several
character-driven possibilities for each encounter before one premise is approved.

The chosen architecture is the **Two-Pass Constellation**:

1. **Pass One — Global skeleton:** record the complete plot-free week, including
   every fixed window, promotion valve, mystery obligation, fallback, absence,
   and cross-day debt.
2. **Pass Two — Candidate auditions:** work through one whole day at a time,
   generating two or three genuinely different causal universes for each open
   encounter and rejecting any universe that needs a character to stop being
   herself.

This specification records narrative-development architecture only. It does not
rewrite a story file, select the remaining date premises, write final dialogue,
change Dialogic or Godot code, or authorize implementation. The current story
files remain unchanged until the owner reviews this written specification and a
separate implementation plan is approved.

## 2. Governing authority and evidence classes

### 2.1 Authority ladder

For this bounded work, authority is:

1. [`2026-08-07-seven-day-dialogic-flow-design.md`](../../design/2026-08-07-seven-day-dialogic-flow-design.md)
   owns calendar mechanics, invitation availability, message and echo law,
   relationship-state mechanics, promotion valves, Hospital interruption,
   Priscilla–Lavinia encounter modes, Day 7 flow, and Dialogic structure.
2. [`01-core-story-bible.md`](../../../story/01-core-story-bible.md) is the sole
   narrative authority for character, relationship, atmosphere, hidden history,
   and intended audience-facing meaning wherever it does not conflict with a
   later explicit approval.
3. [`02-character-relationship-handbook.md`](../../../story/02-character-relationship-handbook.md)
   is derived performance and voice guidance. It may sharpen application of the
   Bible but cannot add or revise canon.
4. Later explicit narrative approvals may specialize an open premise without
   altering the mechanical authority above. The approved Room 2.17 causal design
   is the first such specialization governed by this workflow.
5. [`03-seven-day-production-map.md`](../../../story/03-seven-day-production-map.md)
   must become a derived, plot-neutral production template. Its present named
   cards are source material, not mechanical authority.
6. [`05-canon-amendments-2026-07-19.md`](../../../story/05-canon-amendments-2026-07-19.md)
   remains historical amendment evidence. It cannot silently overrule the August
   mechanical design.
7. Research notes, including
   [`2026-08-27-room-217-narrative-theory-check.md`](../../research/2026-08-27-room-217-narrative-theory-check.md),
   are craft lenses only. They cannot create canon.
8. The August design owns intended mechanics. Runtime code owns what physically
   exists, including any current drift. A conflict therefore produces a
   reconciliation finding; executable drift does not silently revise the approved
   design or create narrative truth.

Later approval must be recorded; it must not be inferred from an idea merely
appearing in an upstream-looking document.

### 2.2 Evidence classes

| Class | Current examples | Treatment |
|---|---|---|
| Mechanically fixed | Twelve solo windows; Day 2 and Day 6 pair protocol; third/fourth promotion valves; six ordinary messages; Day 7 flow | Preserve exactly unless a later mechanical design explicitly supersedes it |
| Narratively protected | Character and relationship canon; the four mystery anchors; Day 2 umbrella history and trigger; approved Room 2.17 causal design | May be expressed through different lawful scenes, but not casually discarded or contradicted |
| Audition material | Unapproved named Events 1–12 and 14; unapproved delivery premises surrounding fixed anchors | Preserve as candidates, not canon |
| Writer-facing reaction test | Illustrative dialogue and prose used to test rhythm or character response | Never becomes shipped dialogue merely because its premise is approved |
| Historical or craft evidence | Superseded amendments, recovered documents, theory comparisons | Consult for reasoning and provenance; do not grant authority |

The present Event 13 card and the later Room 2.17 approval require careful
separation. The old named card must be preserved verbatim with the other old Map
material. The later-approved Room 2.17 causal spine remains protected in the
Beatbook, although its exact dialogue, literal weekday, and undeveloped
Group/Missed adaptations remain provisional.

### 2.3 Physical-world correction rule

Author notes must separate witnessed physical fact, character inference, and
unresolved cause. A surprising event keeps at least one plausible mundane account
unless the fictional world has independently established a different law. Medical,
institutional, geographic, scheduling, and consent claims must survive a factual
check before approval. A character may be wrong; the private causal record may
not disguise an unsupported claim as fact.

## 3. Problem being solved

The approved August design deliberately left finished date premises and dialogue
out of scope. The current story documents nevertheless contain named event cards,
an obsolete Hate starting tier, and fewer leveling cards than the fixed promotion
law requires. Expanding those cards directly would accidentally make examples
canonical, hide calendar contradictions inside prose, and encourage locally
beautiful scenes that do not export the evidence later days need.

The workflow therefore has to achieve four things at once:

- preserve the approved mechanical lattice;
- let the characters' own wants and refusals determine each encounter;
- make every selected scene participate in a legible seven-day causal pattern;
- retain rejected possibilities without allowing them to leak back into canon.

## 4. Chosen architecture and alternatives

### 4.1 Chosen: Two-Pass Constellation

Pass One is intentionally plot-free. It proves that the week can carry every
required message, anchor, invitation, promotion, interruption, absence, and Day 7
debt before any new premise seduces the design.

Pass Two treats each day as a constellation rather than treating each date in
isolation. All of that day's encounter windows are auditioned together so that
their contrasts, shared evidence, private variants, and outgoing residues can be
judged as one causal unit. Only an explicitly approved survivor enters canon.

### 4.2 Alternatives not chosen

**Continue expanding the present Production Map.** This is fast locally, but the
Map currently mixes mechanics, examples, named plots, state variants, and
production instructions. Adding more detail would deepen the authority conflict.

**Write the entire Beatbook before selecting premises.** Close scene work can make
one attractive exchange feel inevitable. It is too expensive and too emotionally
committing for premises that may fail a later-day causality or calendar test.

**Generate every state combination as a separate plot universe.** This multiplies
content without producing meaningful alternatives. State, tone, attitude,
visibility, echo, and legibility should vary an approved premise in layers; they
should not replace causal design.

**Discard all existing named material and start blank.** This would lose useful
ideas, approval history, and evidence of earlier reasoning. The correct treatment
is provenance-preserving demotion to a noncanonical library.

## 5. Document ownership after reconciliation

| Artifact | Owns | Must not own |
|---|---|---|
| August 7 design | Mechanical and Dialogic law | Finished plot or dialogue |
| `story/01-core-story-bible.md` | Narrative canon, hidden history, experience contract, protected anchors | Candidate premises presented as settled canon; conflicting mechanical summaries |
| `story/02-character-relationship-handbook.md` | Character and relationship behavior, voice, knowledge, consent, control signatures | Calendar availability or newly invented plot facts |
| `story/03-seven-day-production-map.md` | Plot-neutral production card and slot template | Named mystery anchors, named date premises, character-specific scene beats, mechanics |
| `story/library/03-seven-day-plot-material-library.md` | Verbatim old Map material and later rejected/mutated candidates, each clearly noncanonical | Active canon or production instructions |
| `story/07-seven-day-causal-matrix.md` | Compact records of explicitly approved premises and their cross-day obligations | Unapproved candidates, final dialogue, broad craft essays, duplicated mechanics |
| `story/06-seven-day-scene-beatbook.md` | Detailed execution for approved load-bearing scenes; clearly labeled reaction tests | New encounter windows, silent canon changes, final DTL by implication |
| Research notes | Source-grounded craft checks | Narrative or mechanical authority |

No additional general writing manual is needed. The story bible and handbook own
stable writing principles; this specification owns the new selection workflow;
the Production Map supplies the reusable card form.

### 5.1 Provenance-safe reconciliation order

The later implementation plan must preserve this order:

1. Copy the then-current named contents of `story/03` verbatim into
   `story/library/03-seven-day-plot-material-library.md` before rewriting the Map.
2. Mark the copied material as noncanonical audition history without silently
   correcting its language or mechanics.
3. Add bounded mechanical supersession notices to `story/01` and `story/02`:
   every solo friend begins at Friend, Hate is not an active tier, and promotion
   uses only the fixed third/fourth valves. Preserve character and relationship
   prose. Any still-useful Hate behavior must be reclassified as hostility or
   resistance in performance guidance, not retained as a reachable tier.
4. Add the narrow narrative-scope notice to `story/01`. It must preserve the four
   fixed anchors, Day 2 umbrella material, character canon, and later-approved
   Room 2.17 design while identifying unapproved named premises as audition
   material.
5. Rewrite `story/03` as a genuinely plot-neutral template.
6. Create `story/07` with the fixed constellation and only approved narrative
   placements.
7. Repair `story/06` authority links so it depends on the August mechanical design,
   the bibles, and an approved `story/07` row—not on a named card in `story/03`.
   Room 2.17 is the bounded temporary exception: preserve it as
   `APPROVED CAUSAL CORE — PLACEMENT UNSELECTED` until Day 2 versus Day 6 receives
   explicit approval. It may not be treated as a scheduled production scene or
   linked to a fabricated matrix row while unplaced.
8. Add supersession notices where historical mechanical summaries conflict, but
   retain their reasoning as historical evidence.

No user-authored dirty work may be overwritten or normalized as a side effect of
this reconciliation. Every moved item retains its source and status.

## 6. Pass One: the fixed seven-day constellation

The table below is an obligation lattice, not a plot outline. A protected anchor
fixes the fact that must be available to the audience; it does not preselect the
date premise that carries it.

| Day | Ordinary message | Solo invitation windows in fixed round order | Pair window | Promotion valve after attended challenge | Protected anchor or residue duty |
|---:|---|---|---|---|---|
| 1 | Lavinia | R1 Priscilla; R2 Sylvia | None | None | Institutional uncertainty: Lavinia's name appears prematurely on an Open Week roster. Export concrete roster residue. |
| 2 | Sylvia | R1 Priscilla; R2 Lavinia | Conditional P–L activation at R3 | None | Priscilla's concealed knowledge: Angela does not send `Lavinia is back`, yet receives `I know`. Preserve the separately triggered, non-counting umbrella pickup and its later residue when unseen. |
| 3 | Priscilla | R1 Lavinia; R2 Sylvia | None | None | Deliberate negative space: receive and transform prior residue without inventing a new fixed anomaly. Export a necessary ordinary consequence or record `NONE — NEGATIVE SPACE`. |
| 4 | Lavinia | R1 Priscilla; R2 Sylvia | None | Priscilla Friend→Ambiguous; Sylvia Friend→Ambiguous | Sylvia's preparation: the welfare slip is already prefilled with Lavinia's name, correct location, and the kind of help soon required. |
| 5 | Priscilla | R1 Lavinia; R2 Sylvia | None | Lavinia Friend→Ambiguous; Sylvia Ambiguous→Love | Deliberate negative space: pressure or complicate existing evidence without adding a compulsory mystery. Export a necessary consequence or record `NONE — NEGATIVE SPACE`. |
| 6 | Sylvia | R1 Priscilla; R2 Lavinia | Conditional P–L activation at R3 | Priscilla Ambiguous→Love; Lavinia Ambiguous→Love | Audience implication: the ordinary location prompt's confirmation or expiry record begins a plausible physical intervention. |
| 7 | None | No ordinary dating challenge; boardless ending invitations unlock R1 Priscilla, R2 Lavinia, R3 Sylvia | No new pair invitation; resolve any qualified P–L ending layer | None | Due Day 6 follow-ups → unavoidable echo fallback → ending invitations and any pre-Done faint branch → one selected solo destination or Alone → any qualified solo Observer → any qualified P–L ending → any qualified P–L Observer. Exact eligibility and incompatibility law remain upstream. |

On Days 2 and 6, R3 attempts pair activation exactly once. It can succeed only
while both same-day solo offers remain available and unread; all acceptance,
Hospital, visibility, counter, and board consequences remain governed by the
August pair protocol. On Day 7, a qualifying faint before Done follows the
upstream precedence: Dark-mode Alone when enabled; otherwise Sylvia Special then
Sylvia Dark if Sylvia's invitation was already read; otherwise Hospital-flavored
normal Alone. Day 7 creates no missed-date record or Day 8 follow-up.

All three friends begin at **Friend**, not Hate. Affection supplies eligibility;
only the exact third and fourth invitation slots act as ordinary promotion valves.
A missed, unread, prevented, or Hospital-superseded valve does not move. Sylvia's
separately approved Hospital witness is the sole exception already defined by the
August design.

### 6.1 Encounter-window record

Pass One creates one record for each of the twelve solo invitation windows and
the two conditional P–L windows. Each record contains:

- mechanical identity and exact day;
- relationship function without a selected premise;
- promotion role, if any;
- incoming causality that a later premise must be able to receive;
- delivery obligation, including any anchor or echo it may carry;
- guaranteed fallback carrier when the encounter is missed, prevented, hidden,
  or superseded;
- outgoing causality required by a later day;
- absence version describing what still occurs without Angela or without the
  encounter;
- abnormality allowance: none, optional, or protected;
- Day 7 debt, if any;
- selection status. Every Pass One record begins `UNSELECTED`; Pass Two applies
  the complete lifecycle defined in section 9.

The Day record also identifies at least one necessary exported residue. If the
absence of a new residue is itself deliberate, it says exactly
`NONE — NEGATIVE SPACE`; an empty cell is not a design decision.

### 6.2 Pass One freeze gate

Pass One is frozen only when all of the following are true:

- all twelve solo and both pair windows appear exactly once;
- the four protected anchors remain lawfully deliverable across legal schedules,
  zero-date days, alternate selections, and Hospital paths;
- every selected ordinary-message reply has at least one contextual echo
  opportunity and an unavoidable Day 7 fallback;
- promotion can occur only at the exact third and fourth invitation slots;
- every day exports one necessary residue or the explicit negative-space marker;
- no unattended or hidden event gives Angela knowledge she did not witness or
  receive through lawful residue;
- no scene progresses merely because nobody attended it unless the authority
  explicitly defines an offscreen counterpart;
- no single anomaly solves the global mystery or proves a supernatural cause;
- no candidate-specific task, prop, shock, dialogue exchange, or scene solution
  has leaked into the plot-free skeleton.

## 7. Pass Two: day-sized candidate auditions

Pass Two proceeds Day 1 through Day 7. It completes the full constellation for
one day before moving to the next; it does not finish one friend's entire route in
isolation. Days 1–6 audition encounter premises. Day 7 has no open dating window:
its pass is a convergence audit of follow-ups, echoes, already-authorized ending
content, Alone, and eligible postscript layers. Day 7 may audition how a fixed
payoff is delivered, but it cannot invent a date, challenge, promotion, or new
ending identity.

For each open encounter window, create two or three candidates that differ in
causal premise—not merely in room, prop, phrasing, or outcome skin. At least one
candidate must work with no abnormal event at all. A window may remain
`UNSELECTED` if every candidate fails.

### 7.1 Candidate anatomy

Each candidate records:

- the ordinary task that would exist without Angela;
- what each present character wants now;
- what each character fears or refuses;
- the control method each character uses;
- the disturbance that makes the ordinary task unstable;
- the smallest irreversible change by the end of the encounter;
- physical evidence left behind;
- what remains unresolved;
- the necessary later consequence;
- what happens if Angela or the entire encounter is absent;
- why this premise belongs to this exact mechanical window rather than any other.

The candidate must be expressible within the authorized visible-scene boundary.
Priscilla–Lavinia private counterparts may be visible under their approved pair
protocol. The separately authorized Day 2 umbrella pickup remains the sole
additional friend-without-Angela micro-scene; there are no otherwise free-standing
friend scenes. An offscreen fact may be designed privately when causality requires
it, but it does not become a scene.

### 7.2 Character-faithfulness gates

| Gate | Question |
|---|---|
| Volition | Would the character initiate or continue this without the author's need for a clue? |
| Knowledge | How could she physically know each fact she uses at this moment? |
| Control signature | Is she seeking certainty or influence in her own established way rather than borrowing another character's method? |
| Refusal and consent | What can she decline, redirect, accept partially, or leave without the plot preventing her? |
| Consequence | What becomes troublesome enough that ignoring it now costs something later? |
| Autonomy | Does each friend retain a life, task, and motive not organized around Angela? |
| Dialogue-only communicability | Can the essential relationship action and evidence survive dialogue-led presentation with only sparse, precise perceptual narration? |
| Author greed | Is the scene asking a character to perform a beautiful idea that she herself would not choose? |

The verdict vocabulary is deliberately qualitative:

- `SURVIVES` — character-faithful, lawful, causally useful, and distinct;
- `MUTATE` — contains a viable causal heart but fails one or more gates;
- `REJECT` — depends on character betrayal, unlawful knowledge, decorative
  abnormality, repetition, or a consequence the week does not need.

There is no numeric score. False precision would conceal the judgment that needs
discussion.

### 7.3 Theory lenses are diagnostics, not recipes

- **McKee:** What value actually turns, and is the turn caused by a character's
  choice under pressure rather than by authorial delivery?
- **Robbe-Grillet:** What material arrangement, repeated observation, or spatial
  correction gives the audience evidence without dictating its meaning?
- **Barthes:** Does the scene leave more than one supportable reading after the
  author's preferred explanation is removed?
- **Fisher:** Can the disturbing element arrive through ordinary institutional or
  domestic procedure, accepted as daily reality rather than announced as horror?

These references never override character autonomy, physical plausibility, or
the project's resistance to symbolic decoding. Room 2.17 is an exemplar of
character-specific spatial negotiation, not a template requiring every scene to
move an object, use an elliptical correction, or imitate *La Jalousie*.

### 7.4 Grilling and selection rhythm

For each candidate set, the collaborator presents the evidence and names an honest
preferred survivor before learning the owner's preference. This protects the
comparison from agreeable hindsight. Architecture-changing uncertainties are
asked one at a time; independent character questions may be batched. The owner may
approve none.

The discussion continually asks whether the characters are acting as themselves
or whether the authors' appetite for delicious absurdity is making them perform.
Absurdity is permitted to be short, memorable, shocking, ridiculous, or cruel;
it is not permitted to erase motive and consequence.

## 8. Aesthetic and abnormality law

The world presents abnormality with the same practical attention it gives ordinary
inconvenience. A character may notice an impossible-looking detail and still care
more about the person who has become troublesome, the task that must be finished,
or the arrangement she can control. Normalized response does not mean obliviousness.

The preferred scene surface is dialogue-led. Sparse narration may register an
object, line of sight, repetition, or observation, and may be inseparable from a
character's perception without being announced as interior monologue. It should
not translate every visual fact, explain the horror, or guarantee accessibility
at this plot-design stage. A later accessibility layer may add optional description
without requiring the base scene to over-explain its evidence.

Every candidate must observe these limits:

- show behavior and consequence before explanation;
- keep sweetness genuinely attractive and danger genuinely nearby;
- prefer normalized procedure to cinematic threat signals;
- let some evidence be missable;
- use no graphic brutality merely to raise intensity;
- avoid sentimental reconciliation, ornate symbolism, coy feyness, melodramatic
  declarations, and dialogue written as a decoding key;
- do not treat randomness as freedom from causality;
- do not make a character care about an anomaly merely because the audience does.

## 9. Canon promotion and reopening

Candidate status follows this exact progression:

`UNSELECTED → AUDITIONING → SELECTED FOR APPROVAL → APPROVED`

`SURVIVES` is an audition verdict, not a canon state. A survivor becomes
`SELECTED FOR APPROVAL` when it is the recommended constellation member. It
becomes `APPROVED` only after the owner explicitly approves that premise. The
approved compact causal record then enters `story/07`; rejected and mutated
universes remain in the noncanonical library.

Premise approval fixes only the facts explicitly recorded in the causal matrix.
It does not canonize every draft line, prop adjective, staging sentence, theory
interpretation, or possible state insert discussed during the audition.

An approved row becomes `REOPENED` when later work exposes any of these conflicts:

- calendar, invitation, promotion, Hospital, pair-mode, or ending law;
- character motive, knowledge, autonomy, voice, refusal, or consent;
- repetition that flattens the week's scenes into one authorial device;
- missing incoming or outgoing causality;
- a physical or institutional claim that fails verification;
- an approved later scene that cannot coexist with it.

Reopening never silently rewrites history. The superseded version moves to the
noncanonical library with its former status and reason. Because the game has not
shipped, narrative backward compatibility is unnecessary; provenance remains
necessary.

## 10. Approved causal-matrix record

`story/07-seven-day-causal-matrix.md` begins with the Pass One constellation and
contains only explicitly approved narrative premises. Each approved row records:

- stable encounter/window ID and day;
- approval status and approval record;
- compact premise and ordinary task;
- participating characters and visibility modes;
- incoming cause and lawful knowledge;
- smallest irreversible change;
- concrete evidence and guaranteed fallback carrier;
- outgoing consequence and Day 7 debt;
- absence, missed, Hospital, private, or prevented behavior as applicable;
- allowed abnormality and unresolved cause;
- promotion or anchor obligation, if any;
- Beatbook link when the scene has earned expansion.

The matrix does not duplicate exact dialogue, full state branches, or craft
analysis. Its job is to make cross-day causality inspectable at a glance.

### 10.1 Pair-mode disposition

Each Day 2 or Day 6 pair row records the exact mode disposition below. It does
not invent a sixth outcome for opened-but-unanswered; that is a presentation
subvariant of Private-visible under the upstream protocol.

| Mode | Pair meeting counts | Visible pair scene | Pair board |
|---|---:|---:|---:|
| Group | Yes | Yes | Yes |
| Missed | Yes | Yes | Yes |
| Private-visible | Yes | Yes | Yes |
| Private-offscreen | Yes | No | No |
| Prevented | No | No | No |

The row must additionally state the applicable offer/acceptance condition,
Hospital flavor, witnessed-combination eligibility, and residue boundary. A
visible board's Perfect/Solved/Exploded result may vary legibility; it does not
rewrite the selected causal premise. Private-offscreen grants neither a board nor
witnessed-combination credit. Prevented cannot imply that the meeting occurred.

## 11. Beatbook expansion threshold

An approved premise earns detailed Beatbook treatment only when at least one of
the following is true:

- it carries one of the four fixed mystery anchors;
- it contains a third- or fourth-window promotion;
- it is a counted Priscilla–Lavinia encounter;
- it directly earns a Day 7 payoff or required echo fallback;
- it involves Hospital, consent, medical, institutional, or difficult knowledge
  boundaries;
- its Group, Missed, Private-visible, Private-offscreen, or Prevented forms have
  materially different causal work.

Ordinary connective scenes remain compact matrix rows. Detail is earned by risk
and causality, not by affection for a scene.

Every illustrative exchange in the Beatbook remains labeled `REACTION TEST`
until final Dialogic authorship separately approves exact wording. A reaction test
may establish that a premise is playable; it is not a promise to ship its lines.

### 11.1 Room 2.17 protected causal core

The current approved Room 2.17 material survives reconciliation with these
boundaries:

- Its placement remains unselected between the two lawful pair windows, Day 2 and
  Day 6. Preserve the causal design without inventing an exact-day matrix row.
  Before production authorship, the placement must return through audition and
  receive explicit approval.
- Its detailed chair/folder/`will` execution is approved for the neutral
  Private-visible Priscilla–Lavinia encounter, not for a solo date or a standalone
  Sylvia scene. The same ordinary work and resulting third version may be tested
  as a shared causal spine for Group and Missed, but their Angela-presence, guilt,
  and Hospital-pressure adaptations remain unapproved. Private-offscreen inherits
  only the lawful meeting result and counter without displaying this execution;
  Prevented contains no meeting.
- Room 2.17 is an ordinary Open Week preparation room, not an uncanny entity.
- Priscilla prepares a stable chair for Lavinia. Lavinia accepts the chair but
  decides what it will face.
- Priscilla asks whether the chair is comfortable. Lavinia answers through the
  change she made rather than through gratitude or rejection.
- Priscilla moves the working folder into Lavinia's chosen line of sight instead
  of restoring the chair.
- Lavinia's `will` correction begins as real, unusually picky irritation at
  Priscilla's habitual certainty. Priscilla finds the wording defensible but makes
  Lavinia's choice usable by identifying the other occurrences. The exchange ends
  after that small beat.
- They produce a usable third version neither would have made alone. This is a
  working truce, not forgiveness, reconciliation, a label, or a relationship
  level-up.
- The same real, non-urgent second folder supplies the tone hinge: Sweet Priscilla
  permits it to wait; Totally Dark Priscilla offers continuation without lying
  about urgency, and Lavinia knowingly chooses to stay.
- In Love state, Lavinia chooses a future return and its practical boundary.
  Priscilla asks rather than presumes. The literal reference weekday remains
  provisional pending August-authorized placement and calendar validation plus
  explicit premise approval. Runtime may be inspected only for implementation
  drift and cannot select, amend, or approve placement.
- Sylvia's routine offscreen occupancy mark is optional causal seed only. It gets
  no independent scene, no ominous emphasis, and no emotional role in this
  encounter. Remove it if no later approved contradiction needs it.
- Exact reaction-test dialogue is writer-facing and not final DTL.

## 12. Verification matrix

Verification is staged by the Two-Pass architecture. The bounded documentation
reconciliation and Pass One freeze must produce fresh evidence for every
plot-free row below, including window count, initial state, promotion, anchor
carriers, messages, pair modes, Day 7 order, causal agency, reality/care
boundaries, presentation status, documentation, and contradiction removal.

Rows that require an **approved premise** or an **auditioned candidate** cannot be
honestly passed while every window is `UNSELECTED`. During Pass One, perceptible
change is `NOT EXERCISED — NO APPROVED PREMISE`, and the requirement that an
ordinary candidate be considered for every window is
`DEFERRED TO PASS TWO`. Pass One must instead prove that no candidate-specific
content leaked into the skeleton and that an anomaly-free candidate remains
lawfully possible for every window. These staged statuses permit the approved
plot-free obligation lattice to freeze under section 6.2; they do not permit the
seven-day plot or the complete matrix below to be declared finished. Pass Two
must close both candidate-dependent rows before full plot completion.

| Axis | Required proof |
|---|---|
| Window count | Exactly twelve solo windows and two conditional P–L windows, on the approved days |
| Initial state | Priscilla, Lavinia, and Sylvia each begin at Friend; no Hate variant remains in active production guidance |
| Promotion | Third and fourth valves occur only at Priscilla 4/6, Lavinia 5/6, Sylvia 4/5 and obey attendance/Hospital law |
| Anchors | Day 1 roster, Day 2 premature reply, Day 4 prefilled slip, and Day 6 location prompt survive zero-date, alternate, Hospital, and pair paths |
| Messages | Six ordinary messages appear on Days 1–6; each selected reply has contextual echo opportunity and Day 7 fallback; Day 7 has none |
| Pair modes | Group, Missed, Private-visible, Private-offscreen, and Prevented remain distinct and grant only their authorized visibility, board, and counter effects |
| Day 7 order | Due follow-ups and echo fallback precede boardless Priscilla/Lavinia/Sylvia rounds; faint precedence, selected destination or Alone, solo postscript, P–L ending, and P–L postscript obey the upstream ordered plan |
| Causal agency | No unattended scene grants knowledge or progress that its absence rules forbid |
| Perceptible change | Every approved premise creates a smallest irreversible change and exports needed residue, or the day explicitly owns negative space |
| Reality and care | Knowledge, consent, medical, institutional, geographic, scheduling, and physical claims are checked and fact/inference are distinguished |
| Abnormality | At least one ordinary candidate was considered per window; no anomaly solves the mystery; no device repeats until it becomes an authorial signature |
| Presentation | Essential relationship action survives dialogue-led presentation; prose and reaction-test status are explicit |
| Documentation | Authority links resolve; old named material is preserved verbatim; active canon, audition material, and historical evidence are unmistakably labeled |
| Contradictions | No active story document claims the old Hate start, movable leveling opportunity, or `story/03` mechanical authority |

## 13. First creative slice after reconciliation

After the owner approves this written specification and a separate implementation
plan completes the documentation reconciliation, the first creative slice is the
**full Day 1 constellation**:

- the Lavinia ordinary-message obligation and possible echo carriers;
- the Priscilla solo window;
- the Sylvia solo window;
- the premature-roster anchor and its fallback;
- the day's outgoing residue and absence cases.

Pass Two will generate parallel universes for those Day 1 windows, grill them as a
set, and recommend a survivor for each before asking for canon approval. It will
not begin by expanding Event 14, by writing all seven days at once, or by turning
Room 2.17 into the pattern every other scene must imitate.

## 14. Approval and implementation boundary

The conversational architecture, this written specification, and the exact
documentation-reconciliation implementation-plan digest are approved. On
2026-08-28, the project owner selected Subagent-Driven execution. The frontmatter
approval transaction authorizes only Tasks 0 through 9, their exact-path commits,
and their bounded documentation-reconciliation scope.

This authorization does not select a Day 1 candidate, place Room 2.17, write final
dialogue, or permit runtime and Dialogic implementation. Creative Pass Two begins
only after the authorized plan is complete and the plot-free Pass One lattice is
verified.
