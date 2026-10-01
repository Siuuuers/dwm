# Relationship Progression and Ending Evaluation Runtime Behavior Record

**Date:** 2026-09-02  
**Last updated:** 2026-09-26  
**Status:** Reconciled future-behavior boundary; provisional P–L plot material isolated  
**Document kind:** Code-change inventory and required behavior; **not** an
implementation plan, task list, specification, or authorization to edit code

## 1. Purpose and authority

This document preserves the code consequences of decisions made while writing
the Narrative Constitution, so plot and style work can continue without losing
known runtime debt.

It records:

- which existing code surfaces are expected to change later;
- what behavior the changed runtime must guarantee; and
- which details must remain unresolved until the plot and
  [Narrative Style Manual](../../story/08-narrative-style-manual.md) decide them.

It does not select exact classes, interfaces, schemas, implementation order,
migration steps, or test commands. It does not authorize implementation.

Current story meaning is owned by the
[Core Story Bible](../../story/01-core-story-bible.md),
[Character & Relationship Handbook](../../story/02-character-relationship-handbook.md),
and [Narrative Style Manual](../../story/08-narrative-style-manual.md). The
[Narrative Constitution Working Decision Ledger](2026-09-02-narrative-constitution-working-decision-ledger.md)
preserves decision evidence and open auditions; traceability there does not
promote a candidate into required runtime behavior. If this record and a later
approved narrative authority disagree, the later authority wins and this record
must be reconciled before code work begins.

## 2. Confirmed future behavior

### 2.1 Naming and meaning

- The existing internal and save-facing token `affection` may remain to avoid a
  vocabulary-only rewrite.
- Its canonical design meaning is **relational momentum**: the degree to which
  a relationship has become mutually consequential enough to permit deeper
  material.
- It is hidden and does not measure love, desire, consent, virtue,
  compatibility, truth, or moral quality.
- If relationship state is later reorganized for another substantive reason,
  the token may be renamed once within that bounded change. This unshipped game
  requires no compatibility bridge merely to preserve an old name.
- Relational momentum never directly selects a hidden event, grants character
  knowledge, or awards Observer evidence.

### 2.2 Challenge interpretation

- A completed dating board supplies a frozen nondiegetic terminal fact. It
  does not supply trusted relationship deltas or select dialogue directly.
- Code-owned scene response resolution interprets the terminal fact in the
  context of the exact scene.
- The same structural board result may produce different conduct and dialogue
  in different scenes.
- Multiple terminal results may converge on one response only when their
  fictional conduct and downstream consequences genuinely match.
- A scene may register zero or one optional Frozen Impulse Atom window. Frozen
  attempt context selects once among a small set of scene-authored candidates,
  and the selected atom is stored in the frozen response plan before
  presentation.
- Reload, replay, or Dialogic resumption cannot redraw the atom. No runtime
  surface procedurally generates its prose or action.
- A plot-changing burst is not stored as a cosmetic atom. If alternatives
  change reusable canon or progression inputs, they require distinct persisted
  consequence-plan variants resolved before relationship progression.
- UI and Dialogic presentation never decide or directly mutate relational
  momentum, durable relationship state, ending eligibility, character
  knowledge, or Observer evidence.

#### 2.2.1 Angela-absent visible pair explosion boundary

- In every visible Priscilla–Lavinia pair-board presentation in which Angela
  is absent, `Exploded` ends the audience-visible dating scene immediately
  after the terminal result. No post-challenge dialogue, action, reaction,
  reassurance, or closing gesture is presented.
- The cutoff governs access, not fictional causality. It does not establish
  that the pair stop interacting, that an offered question goes unanswered in
  fiction, or that either woman refuses, withdraws, becomes hostile, or changes
  the frozen pair form.
- If an approved scene requires unseen conduct or durable residue after the
  cutoff, its response plan must author and persist those facts explicitly.
  The absence of visible continuation grants no conduct, character knowledge,
  audience evidence, progression input, or residue by inference.
- Pre-challenge material followed by `Exploded` does not mark the frozen pair
  combination witnessed. The existing profile witnessed-credit rule remains
  distinct from whether some earlier part of the encounter was visible.
- `Perfect` and `Solved` proceed to the scene's applicable post-challenge
  presentation. They may share narrative conduct, dialogue, and fictional
  consequences when those genuinely match, but their terminal facts remain
  distinct: `Perfect` retains its separate mastery evidence and `Solved` does
  not acquire it. No extra narrative difference is required merely to
  compensate for the explosion cutoff.
- This bounded rule does not decide the presentation of an Angela-attended
  Group explosion. That surface retains its scene-local response obligation.

Source and supersession boundaries are recorded in the
[Angela-absent pair explosion reconciliation](2026-09-06-angela-absent-pair-explosion-visibility-reconciliation.md).

### 2.3 Priscilla–Lavinia frozen run form

- Each genuinely new playthrough receives exactly one frozen combination:
  `ambiguous_sweet`, `ambiguous_dark`, `love_sweet`, or `love_dark`.
- The combination is selected at run creation from the currently eligible
  profile-aware pool. Until all four have actually been witnessed, the eligible
  pool excludes witnessed combinations.
- A hidden selection does not mark a combination witnessed. Only presentation
  of a counted Priscilla–Lavinia event or their ending under that combination
  creates the profile witnessed receipt.
- Save, Load, Rehearsal, branch replacement, pair-board results, Angela's
  presence or absence, and all in-run conduct preserve the original combination.
- Pair-board resolution may commit scene-authored conduct and concrete residue,
  but it cannot change the frozen state or tone.
- A qualifying pair ending reads the frozen combination. Accumulated conduct
  may affect eligibility or concrete presentation only as later approved by the
  plot; it does not derive a replacement combination.
- A qualifying pair ending presents one of four registered, substantive
  quadrant resolutions of one shared ending situation and carrier. The full
  frozen combination therefore remains available to the frozen presentation
  context: the state axis controls approved Ambiguous/Love mutual-legibility
  variation, while the tone axis controls which approved character-specific
  facet becomes decisive visible conduct. Sweet does not mechanically mean
  interruption and Totally Dark does not mechanically require mutual
  reinforcement. A Dark form must carry an authored, character-specific fact
  identifying what concrete protected interest desire makes expendable; a
  generic severity level cannot supply that meaning. No quadrant may be
  synthesized from palette, diction, or a generic tone insert at presentation
  time.
- This behavior does not require four top-level ending IDs. One identity plus
  registered form context, two tone identities plus state-specific content,
  four combined identities, or another validated representation may be chosen
  later. Whatever representation is selected must preserve all four authored
  resolutions, deterministic replay, and Gallery/witness receipts without
  treating storage shape as relationship ontology.
- After all four combinations have first been witnessed, every later genuinely
  new playthrough draws freely from all four. The unseen-first exclusion is not
  restarted as a recurring no-repeat cycle.

### 2.3.1 Priscilla–Lavinia scene dispatch — plot-dependent hold

The working ledger preserves a detailed candidate in which Day 2 and Day 6 own
distinct pair continuities, a Dark Day 2 confrontation may leave a healing-cheek
residue, and later Angela-facing carriers may establish first recognition. That
candidate is **not confirmed future behavior**. The owner requires its complete
Bible/Handbook/Style-Manual audit to use the raw chronological conversation,
not a summary, before any bar event, strike, injury, touch, continuity split,
residue, or knowledge receipt can enter forward canon or a code requirement.

Until that audit closes, the runtime contract retains only the independently
confirmed pair-window, count, visibility, knowledge-scope, and frozen-form laws.
It must not queue a missed story scene, invent prior conduct, or persist any
plot-specific pair residue merely because Day 2 or Day 6 counted. The candidate
details remain inspectable in the
[working decision ledger](2026-09-02-narrative-constitution-working-decision-ledger.md#78-core-ending-closure-and-interpretive-openness).

The later [conditional Day 6 and one-meeting ending proposal](#2026-09-26-conditional-day-6-and-one-meeting-ending-proposal)
is recorded below for preservation only. It does not release this hold or make
an older injury-dependent check a fact of the new portrait audition.

### 2.4 Relationship-progression evaluation

- Relationship progression is a real code-owned event and is not retired.
- It runs only at a small, explicit list of scene-authored progression windows;
  it does not run automatically after every date.
- The exact window list belongs to the approved seven-day plot and remains
  deliberately undecided here.
- At an approved attended window, progression is evaluated only after every
  material response variant and all of its progression inputs are frozen and
  committed, and before post-challenge presentation begins.
- A presentation-only atom cannot change progression. A variation that changes
  a progression input must be resolved as a distinct consequence-plan variant
  before evaluation.
- One window may advance the durable relationship state only as allowed by the
  eventual Constitution and never more than once for the same committed event.
- A missed, unread, prevented, or Hospital-superseded window neither evaluates
  nor relocates itself unless the Constitution later approves an explicit,
  named exception.
- The evaluation result is persisted independently of whether any special
  dialogue reacts to it.
- Reloading, replaying, or resuming presentation cannot apply the evaluation a
  second time.

### 2.5 Durable relationship state

- Ending eligibility reads an already-evaluated durable relationship state;
  it is not inferred afresh from the current `affection` number.
- If the Constitution retains ordered states such as
  `Friend -> Ambiguous -> Love`, state does not regress merely because later
  relational momentum decreases.
- Durable state does not manufacture attraction, romance, consent, motive, or
  personality. It controls only the specifically approved narrative access and
  eligibility.
- A deeper or hidden scene uses its own registered eligibility predicate. That
  predicate may read durable relationship state together with exact schedule,
  attendance, condition, frozen pair-form, conduct, stance, carryover, or
  knowledge facts; neither momentum nor durable state is a universal key.
- Character knowledge and Observer evidence commit only from the exact
  presented carrier and to the correct scope. Merely becoming eligible for a
  scene, or having high momentum when it begins, grants neither.

### 2.6 Ending evaluation and playback

- Ending evaluation remains code-owned even when no Dialogic event depicts it.
- Day 7 evaluates an immutable snapshot of the approved relationship state,
  invitation/schedule facts, and other required receipts.
- The evaluation freezes one ending plan before the run enters ending mode.
- Entering ending mode consumes that frozen plan; it does not choose or
  reinterpret an ending.
- Dialogic receives the frozen ending identity and presentation context only.
  It neither checks eligibility nor mutates the plan.
- Reloading ending presentation cannot change eligibility, select a different
  ending, or repeat relationship progression.

### 2.7 Deterministic ending inputs

- Ending selection remains a deterministic calculation over a small set of
  values and exact receipts. Removing calculated state is not a design goal.
- Relational momentum may contribute to an approved readiness or invitation
  predicate. It does not by itself select the destination, ending tone,
  Priscilla–Lavinia layer, Sylvia Special, or Observer coda.
- The audience's committed Day 7 destination selects exactly one eligible
  personal core family: Priscilla, Lavinia, or Sylvia. A valid commitment is
  never replaced merely because another character has greater relational
  momentum. If no personal destination is committed, the core is Alone.
- A separate route-local accumulated value selects the approved substantive
  Sweet or Dark form inside the chosen personal family. Each form must own a
  materially different ending action, boundary, cost, or distribution of
  access; it is not merely a palette or wording variant. That value describes
  ending form or tone, not virtue, love, truth, consent, or human worth. Its
  exact inputs and threshold remain subject to the completed plot.
- Personal family plus Sweet/Dark form occupies exactly one core slot. The
  eventual code may store one combined identity or separate family/form fields;
  this record fixes semantics rather than representation.
- Before the ending plan is evaluated and committed, registered message and
  Minesweeper consequences, accumulated route-local state, and the Day 7
  destination remain effective inputs. Restoring a save from before those
  inputs are committed may lawfully produce a different ending plan. Only the
  same already-committed plan is resume-stable; this is idempotency, not a
  profile-wide or playthrough-wide route lock.
- Special and Observer results depend on their registered event/evidence facts,
  not on a sufficiently large general-purpose score.

### 2.8 Ordered ending composition

- The intended ending sequence is already a narrative design commitment even
  though the checked runtime does not yet implement it.
- Before playback, the resolver normally freezes one semantic sequence in this
  order: **one core ending -> optional Priscilla–Lavinia coda -> optional
  Observer coda**.
- Sylvia Special is the sole approved prefix exception. When it qualifies, the
  sequence begins **Sylvia Special -> Sylvia Dark**, followed by the optional
  Priscilla–Lavinia and Observer layers when independently possible. Sylvia
  Dark remains the core; Special is an additional preceding ending identity.
- A frozen plan therefore contains one through four ending identities. The
  four-step maximum is **Sylvia Special -> Sylvia Dark -> Priscilla–Lavinia ->
  Observer**.
- The Priscilla–Lavinia coda and Observer coda have independent predicates.
  Either may be absent. A later layer never retroactively changes or replaces
  the resolved core.
- A later Observer coda may receive the already frozen Priscilla–Lavinia form
  and its settled material outcome when physically coherent presentation
  requires form-aware staging. Selecting such a registered staging variant is
  part of the frozen ending plan; it cannot newly qualify the coda, alter its
  semantic identity, reroll the pair form, or reinterpret a preceding layer.
  The exact carrier and staging classes remain open to the ending-family audit
  and the required residence/bar/residue audit; no move, key, bedroom, tenancy,
  or residence-restoration action is implied here. Exact storage and dispatch
  representation also remains open.
- "When possible" means that the required evidence is present and the layers
  are causally compatible. The resolver must reject an impossible combination
  rather than manufacture missing encounters or evidence.
- A qualifying Priscilla–Lavinia coda reads their already-frozen run form. It
  does not calculate or change that form during ending resolution.
- At most one Observer coda follows the latest applicable relationship layer.
  Sylvia has the preceding Special identity rather than a personal Observer;
  when Sylvia Dark or Alone is the core, an Observer coda can occur only
  through an independently qualified Priscilla–Lavinia layer.
- The eventual code may represent this as an ordered step list, a core with
  prefix/coda lists, or another validated structure. This record fixes behavior
  and order, not the field names or container type.

### 2.9 Hospital and Sylvia Special

- Hospitalization remains governed only by the approved joint condition:
  pressure crosses its maximum boundary **and** health crosses its minimum
  boundary. The two game values are abstractions, not real medical measures.
- On Days 1–6, viewing an eligible Sylvia solo invitation creates its automatic
  reply and commits that encounter under the approved invitation flow. If a
  qualifying Hospital event supersedes that exact committed encounter, the
  resolver freezes a Hospital-set variant of the same dating scene. Calendar
  eligibility, an unread invitation, or general Sylvia availability is not
  enough.
- A Days 1–6 Hospital event with no such committed Sylvia encounter performs no
  narrative presentation. It applies the fixed recovery values, consumes the
  Hospital condition, settles affected schedule state, advances the causal
  flow, and persists one idempotent receipt without automatically creating
  relationship, knowledge, evidence, or story rewards.
- The Sylvia Hospital variant substitutes for the committed date; it is not an
  additional encounter. Its presentation begins only after qualified care has
  stabilized Angela, and it cannot determine or improve the recovery result.
- Both Days 1–6 branches use identical recovery semantics. Presentation must not
  make Sylvia the cause, provider, or condition of Angela's clinical recovery.
- Hospital encounters before the terminal Day 7 event may enrich Sylvia
  Special's presentation with established access, preparation, objects,
  wording, or other lawful residue.
- Previous Hospital encounters do not accumulate toward, independently unlock,
  or automatically force Sylvia Special. In particular, the future behavior
  must not use a count of Hospital-skipped Sylvia dates as the Special gate.
- A qualifying Day 7 Hospital event adds Sylvia Special and forces Sylvia Dark
  as the immediately following core only if Sylvia's eligible invitation was
  already read before the triggering action and before the ending commitment.
- The same qualifying Day 7 Hospital event without that established Sylvia
  access selects the Hospital presentation of the Alone core.
- Sylvia Special does not replace Sylvia Dark. The required order is **Sylvia
  Special -> Sylvia Dark**. This deliberately mirrors the principle that an
  Observer identity adds to rather than confiscates its visible ending, while
  placing Sylvia's additional identity before rather than after her core.
- Special forces the Sylvia Dark presentation even when the stored route-local
  tone would ordinarily select Sylvia Sweet. This is a frozen presentation
  override, not a mutation of the accumulated tone value.
- A qualified Priscilla–Lavinia coda and then its qualified Observer coda may
  follow Sylvia Dark under the independent ordered-layer rules above.
- Hospital access never awards relational momentum, romance, or consent merely
  by occurring.

## 3. Known runtime drift and affected code surfaces

This is an inventory, not an implementation sequence.

| Current surface | Current drift | Required future behavior |
|---|---|---|
| [`scripts/ui/MinesweeperChallengeOverlay.gd`](../../scripts/ui/MinesweeperChallengeOverlay.gd) | The placeholder result contains caller-authored `affection_delta`, `dark_point`, and `entered_true_path` values. | Emit only trusted board/session facts needed by code-owned scene interpretation. |
| [`autoload/GameState.gd`](../../autoload/GameState.gd) — `apply_dating_challenge_result()` | Applies raw relationship fields supplied by the caller. | Receive or commit an already-resolved scene consequence without letting presentation define relationship meaning. |
| [`autoload/GameState.gd`](../../autoload/GameState.gd) — `inter_friend_affection`, `inter_friend_route_state`, and pair-result handling | In the checked checkout, these surfaces expose mutable affection/dark deltas and no discoverable frozen four-state owner. The owner reports that the mechanism is already built; its integration location is therefore unverified here, not presumed absent from every version. | Preserve one run-start selection from `ambiguous_sweet`, `ambiguous_dark`, `love_sweet`, and `love_dark` that no in-run result can mutate, separately from mutable pair conduct or later-approved residue. |
| P–L plot-dependent dispatch, contact-flavor envelopes, injury residue, and Angela-knowledge receipt (exact integration surfaces unverified) | Detailed candidates exist in the working ledger, but the residence/bar/residue audit has not yet re-read the raw chronological conversation or promoted an exact event and carrier chain. | **HOLD:** implement no bar, strike, injury, touch, Day 2/Day 6 continuity split, residue, or recognition receipt from this record. Re-enter this inventory only after explicit plot approval records the exact retained behavior. |
| [`autoload/GameState.gd`](../../autoload/GameState.gd) — `get_affection_tier()` | Recomputes `hatred / just_friend / ambiguous / love` continuously from the scalar and permits implicit promotion or regression. | Persist the result of explicit progression windows and query that durable state. |
| [`autoload/GameState.gd`](../../autoload/GameState.gd) — Day 7 unlock/candidate checks | Several paths independently query the dynamically derived tier. | Use one already-evaluated eligibility truth consistently. |
| [`autoload/GameState.gd`](../../autoload/GameState.gd) — `resolve_day7_ending()` | Selects an ending, mutates route context, enters ending state, and emits signals in one legacy operation. It can also make the Priscilla–Lavinia result the primary rather than a later layer. | Separate frozen ending-plan evaluation from entering and presenting that plan. Always resolve one core; append Priscilla–Lavinia only as an independently qualified coda. |
| [`autoload/GameState.gd`](../../autoload/GameState.gd) — Hospital predicate | Hospital currently depends on carried sequela plus pressure **or** health crossing its boundary. | Permit Hospital only under the owner-confirmed joint pressure **and** health condition; settle exact operators and any sequela role before implementation. |
| [`autoload/GameState.gd`](../../autoload/GameState.gd) — Hospital schedule resolution and recovery | The legacy path gives Hospital precedence, counts skipped Sylvia solos, clears pending schedule state, restores fixed values, advances the day, and persists through one Hospital route. Those coupled operations do not distinguish a code-only recovery from a committed Sylvia dating variant. | Resolve one idempotent Hospital transaction. On Days 1–6, route a previously committed Sylvia solo into its Hospital-set variant; otherwise apply recovery and lifecycle settlement without a narrative scene. Recovery values and clinical causation remain identical in both branches. |
| [`scripts/application/run/GameStateDayResolutionPort.gd`](../../scripts/application/run/GameStateDayResolutionPort.gd) — `hospital_if_triggered` receipt | The Phase-2R placeholder currently returns `required: false` for every run, so the transaction shell cannot express either approved Days 1–6 branch or the Day 7 Hospital result. | Consume an authoritative Hospital resolution and persist its once-only branch receipt before presentation. The receipt must distinguish code-only settlement, a committed Sylvia dating variant, and an ending-owned Day 7 result without letting the presentation layer recompute eligibility. Exact field names remain open. |
| [`scripts/ui/HospitalScene.gd`](../../scripts/ui/HospitalScene.gd), [`scripts/ui/DatingScene.gd`](../../scripts/ui/DatingScene.gd), and their Dialogic timelines | Hospital and dating are separate presentation hosts; Hospital starts a placeholder timeline, while dating has no Hospital context variant. | Do not expose Hospital as a fourth narrative surface. Days 1–6 either present no narrative scene or present the frozen Hospital context through the committed Sylvia dating encounter. Day 7 remains ending-owned. |
| [`autoload/GameState.gd`](../../autoload/GameState.gd) — `hospital_skipped_sylvia_solo_count` and `should_route_sylvia_special_ending()` | Two Hospital-skipped Sylvia solo dates force Special with highest precedence, even without a qualifying Day 7 Hospital event or a read Sylvia invitation. Special then stands alone as the primary. | Retire the accumulated-skip gate. Earlier Hospital facts may enrich presentation only; the approved Day 7 Hospital plus prior eligible-invitation-read fact freezes `Sylvia Special -> Sylvia Dark` before any qualified codas. |
| [`scripts/domain/ending/DatingEndingRules.gd`](../../scripts/domain/ending/DatingEndingRules.gd) | Pure ending-selection functions exist, but the intended production path does not consistently use one authoritative rule set. The current plan carries only a primary and one Priscilla–Lavinia epilogue; Observer resolution is detached from playback composition, and Sylvia Special is treated as a standalone primary. | Remain or become the single code-owned source of ending-plan evaluation. Freeze the approved optional Sylvia Special prefix, core, optional Priscilla–Lavinia coda, and optional Observer coda in order. |
| [`scripts/application/run/GameStateDayResolutionPort.gd`](../../scripts/application/run/GameStateDayResolutionPort.gd) — `resolve_ending_plan` | The stage currently supplies a default plan from pre-existing route context rather than performing the approved evaluation. | Freeze the authoritative evaluated plan before `enter_ending`. |
| [`scripts/domain/run/RunLifecycle.gd`](../../scripts/domain/run/RunLifecycle.gd), [`scripts/domain/run/RunSnapshotSchema.gd`](../../scripts/domain/run/RunSnapshotSchema.gd), and save capture/restore surfaces | The ending lifecycle validates a fixed primary-plus-one-epilogue shape and fixed playback stages. The broader snapshot also carries raw affection and mutable inter-friend state but no verified authoritative integration of the newly approved discrete solo progression result or frozen pair form. | Persist and resume every frozen ending layer exactly once, while preserving the minimal durable solo state, pair combination, and idempotency evidence the final relationship law requires. |
| [`scripts/profile/ProfileSchema.gd`](../../scripts/profile/ProfileSchema.gd) and profile persistence | The profile has Gallery and visited-line state but no four-combination witnessed set. | Persist only presentation-backed pair-combination witnessed receipts; a hidden run draw must not enter the set. |
| Ending playback and Gallery recording | The current host records a primary and at most one epilogue. Existing Observer IDs are not part of the frozen playback plan. | Play, resume, and record each compatible frozen layer in order without recomputing any predicate during presentation. |
| Relationship, Hospital, and ending tests | Existing coverage largely follows the legacy scalar-derived, Hospital-OR, accumulated-Sylvia-skip, and two-slot ending flows. | Verify the behavioral guarantees in section 4 after the remaining plot predicates are known. |

## 4. Behavioral checks required of the eventual code

### 4.1 Confirmed checks

The eventual implementation must make all of these statements true:

1. Resolving the same frozen board terminal fact for the same scene and saved
   context cannot choose a different response after reload.
2. The same structural board result may lawfully select different responses in
   two different scenes.
3. Replaying one committed challenge cannot duplicate momentum, progression,
   knowledge, carryover, or Observer evidence.
4. Completing a non-window date cannot silently promote relationship state.
5. One approved progression window cannot promote twice.
6. Missing or being prevented from attending a window cannot move the
   evaluation to another date without an explicit Constitution rule.
7. A later decrease in relational momentum cannot silently reverse a durable
   promotion if the ordered-state model survives the plot redesign.
8. Day 7 invitation and ending eligibility cannot disagree because different
   callers recalculated relationship state differently.
9. Ending playback cannot choose, repair, or mutate its own eligibility.
10. An unknown scene mapping or unsupported terminal fact fails visibly to the
    development diagnostics; it never falls back to invented canon.
11. A Frozen Impulse Atom is selected once per registered window and remains
    identical across save, reload, replay, and presentation resumption.
12. Two candidate atoms cannot share a cosmetic variation slot when they
    produce different knowledge, consent, objects, momentum, carryover,
    Observer evidence, progression, or ending eligibility.
13. Every genuinely new playthrough receives exactly one valid
    Priscilla–Lavinia state/tone combination at run creation.
14. Before all four combinations have been witnessed, a new run cannot select a
    combination already carrying a profile witnessed receipt.
15. Selecting a combination without presenting a counted pair event or pair
    ending cannot mark it witnessed.
16. Save, reload, rehearsal, or a replacement branch cannot reroll the current
    run's combination.
17. No pair-board outcome or pair residue can mutate the frozen combination.
18. After all four profile-witnessed receipts exist, a later new run may select
    any of the four combinations; discovery exclusion does not begin another
    cycle.
19. Changing relational momentum without completing an approved progression
    window cannot by itself unlock a scene, reveal a fact, or grant evidence.
20. A hidden scene becoming eligible cannot grant its possible character
    knowledge or Observer evidence unless the exact registered carrier is
    actually presented to the relevant witness.
21. Every frozen ending plan contains zero or one Sylvia Special prefix,
    exactly one core, zero or one Priscilla–Lavinia coda, and zero or one
    Observer coda, in that order. Special may occur only directly before the
    Sylvia Dark core.
22. A qualified Priscilla–Lavinia layer cannot replace the personal or Alone
    core, and an Observer coda cannot replace either preceding layer.
23. Save, reload, or presentation resumption cannot reorder, duplicate, omit,
    or newly qualify a frozen ending layer.
24. Gallery recording reflects only layers whose playback completion receipts
    are durable; merely qualifying a later layer does not mark it witnessed.
25. Crossing only the pressure boundary or only the health boundary cannot
    route Angela to Hospital.
26. An earlier Hospital encounter can alter registered Sylvia Special
    presentation context but cannot satisfy the Special gate by itself or by
    accumulating skipped Sylvia dates.
27. A qualifying Day 7 Hospital event after Sylvia's eligible invitation was
    read freezes Sylvia Special followed immediately by the Sylvia Dark core,
    regardless of the stored route-local tone. The override cannot mutate that
    stored tone.
28. A qualifying Day 7 Hospital event without the required Sylvia invitation
    fact selects the Hospital presentation of Alone.
29. Hospitalization never directly adds relational momentum or creates a
    consent fact.
30. On Days 1–6, a Hospital event without an already committed Sylvia solo
    encounter performs recovery and lifecycle settlement exactly once and opens
    no narrative scene.
31. Viewing the eligible Sylvia invitation, producing its automatic reply, and
    committing the exact encounter may qualify its Hospital-set dating variant;
    mere eligibility or an unread invitation cannot.
32. Presenting a Sylvia Hospital variant consumes the same committed encounter
    it replaces and cannot create an additional date or duplicate attendance.
33. Code-only recovery and Sylvia-variant recovery produce the same clinical
    state and cannot differ because of a Dialogic branch or presentation result.
34. Saving, reloading, or resuming either Hospital branch cannot duplicate
    recovery, schedule settlement, presentation, or its durable receipt.
35. A committed personal destination freezes exactly one Priscilla, Lavinia, or
    Sylvia core family and exactly one Sweet or Dark form inside that family;
    the form cannot create a second core or consume a coda slot.
36. Saving, loading, or resuming the same post-commit ending state cannot reroll
    or reinterpret its frozen personal family or form. Restoring a pre-commit
    state and changing an authorized message, Minesweeper, accumulated-state, or
    destination input may lawfully freeze another plan.
37. Every personal Sweet or Dark core reaches its irreversible final act only
    while Angela is conscious, responsive, and knowingly performs or permits
    that act. If `Sylvia Special` presents incapacity, the following
    `Sylvia Dark` core cannot treat that incapacity as permission.

### 4.2 Dormant P–L candidate checks

Items 38–48 below preserve the exact candidate's intended safety properties for
future audit. They are **not implementation requirements, approved plot facts,
or permission to infer the event**. If the raw-conversation audit rejects or
changes the candidate, revise or delete these checks before code planning.

38. Preventing the Day 2 Priscilla–Lavinia meeting cannot queue its bar-return
    scene for Day 6 or create any strike, healing, touch, or pair residue from
    that absent encounter.
39. A counted Private-offscreen Day 2 meeting may commit only its approved
    causal residue without a visible board, transcript, or audience-knowledge
    receipt; Day 6 may read that durable fact without pretending the audience
    witnessed its cause.
40. An occurring Day 6 meeting deterministically selects its residue-bearing
    continuity when Day 2 counted and its distinct standalone continuity when
    Day 2 did not count. Save, reload, and presentation resumption cannot swap
    those continuities.
41. Only an occurring Dark Day 2 can create the healing-cheek residue; Sweet or
    Prevented Day 2 cannot accidentally enable any mark-dependent line.
42. Angela's first-recognition receipt is committed only by the earliest
    actually presented post-Day-2 Priscilla solo through Day 6—currently Day 4
    then Day 6—or, if no eligible solo was presented and the pair meeting occurs,
    the attended Group opening of the Day 6 tea. Day 6 solo and Group carriers
    cannot coexist in the same continuity.
43. Private-offscreen Day 2 may persist injury residue without persisting
    Angela knowledge or an audience-witness receipt. An audience-only pair tail
    likewise grants no Angela knowledge.
44. Save, reload, replay, or a later eligible carrier cannot duplicate first
    recognition after Angela's knowledge receipt has been committed.
45. In an eligible Priscilla solo, board entry or terminal result cannot occur
    early enough to gate or reinterpret the invariant pre-challenge recognition
    receipt; only later presentation consequences may read both facts.
46. A Group pair presentation cannot become the complete Missed or
    Private-visible Two-friends presentation plus an Angela-exclusive prelude.
47. Group and Angela-absent visible envelopes may converge on the same fixed
    window-level hinge or durable residue, but each retains substantive lawful
    material the other does not present; neither is marked as the complete or
    uniquely truthful version.
48. Save, reload, resume, or board-result dispatch cannot swap contact-flavor
    envelopes, discard the Group passage boundary, or grant Angela knowledge
    from the pair-bound portion after her departure.

## 5. Decisions deliberately deferred to plot and the Narrative Style Manual

Do not infer any of the following from the current runtime or noncanonical Day
1–7 material:

- the exact progression-window scenes;
- the exact relational-momentum deltas or thresholds;
- whether the final state vocabulary remains
  `Friend -> Ambiguous -> Love`;
- each scene's terminal-result-to-response mapping;
- which scenes contain an optional Frozen Impulse Atom window and the exact
  authored candidates available there;
- which conduct, stance, knowledge, carryover, or Observer facts deserve
  persistence;
- whether a Hospital-set Sylvia variant inherits an approved progression window
  from the committed encounter it replaces or suppresses that window; Hospital
  access alone can never supply the progression input;
- the exact Day 7 invitation predicates;
- each personal Sweet/Dark form's exact action and presentation, the Alone-core
  architecture, route-local tone inputs and thresholds, Priscilla–Lavinia
  eligibility predicate, and Observer evidence predicates;
- the exact presentation variations supplied by previous Hospital encounters
  to Sylvia Special;
- the exact dialogue, nonclinical gestures, response-family mapping, and
  scene-local consequences inside a Sylvia Hospital dating variant;
- the exact persisted ending-plan data shape and playback-stage vocabulary;
- the exact pair-ending eligibility and residue-dependent presentation rules;
- whether any Day 2/Day 6 bar confrontation, strike, injury, touch, continuity
  split, residue, or first-recognition carrier survives the required raw-
  conversation audit;
- the exact P–L Observer carrier and form-aware staging, with no current
  assumption of a move, key, bedroom, tenancy, or restored residence;
- exact module names, function names, data shapes, or file layout.

Those decisions are outputs of the plot and
[Narrative Style Manual](../../story/08-narrative-style-manual.md). Only after
they are approved should this behavior record be reconciled into a technical
design or implementation plan.

## 6. Explicit non-actions

- No gameplay code is changed by this record.
- No existing save is migrated.
- No Dialogic timeline is added or altered.
- No old Bible or audition becomes authoritative through citation here.
- No implementation work is scheduled or authorized.

<a id="2026-09-26-conditional-day-6-and-one-meeting-ending-proposal"></a>
## 7. 2026-09-26 conditional Day 6 and one-meeting ending proposal

**Status: OWNER-ORIGINATED PROPOSAL, RETAINED FOR PLOT COMPARISON. NOT IMPLEMENTED.**
The owner asked to preserve this possible change in the separate story PR.
This is not a verified recovery of the older one-meeting rule they remembered,
a completed mechanical approval, an `APPROVED` Matrix row, or release of 2.3.1.
The underlying discussion and narrative alternatives are captured in the
[portrait and intimacy working record](../../story/relationships/priscilla-lavinia/relationship.md).

### Proposed dispatch and eligibility scope

| Actual Day 2 pair occurrence | Actual Day 6 pair occurrence | Proposed Day 6 content | Proposed P-L ending effect |
|---|---|---|---|
| Occurred and counted | Occurs | Tea continuation authored for the actual Day 2 conduct and frozen form | Existing two-meeting history can qualify, subject to its approved ending conditions. |
| Did not occur | Occurs | Distinct standalone Room 2.17 collaboration, not delayed playback of the bar | This Day-6-only history can also qualify once its own required ending facts are authored and approved. |
| Occurred | Does not occur | No Day 6 pair event | No new Day-2-only eligibility is proposed. |
| Did not occur | Does not occur | No pair event | No new eligibility is proposed. |

`Private-offscreen`, `Private-visible`, attended Group, and `Missed` Group can
still be occurring/counting histories under the current mode rules. Missing
Angela or missing audience access does not select the standalone history.
`Prevented` supplies no Day 2 bar event. A cutoff does not manufacture absence.
The fixed umbrella history never supplies pair count or ending eligibility.

Do not implement this as generic `pair_count >= 1`: that would also change the
Day-2-only case, which the owner did not propose. Do not invent flag names,
thresholds, schema fields, classes, or migration behavior from this table.
Room 2.17's Group/private versions must remain the selected collaboration's
corresponding surfaces rather than unrelated premises chosen by visibility.

### Current baseline and explicit reconciliation debt

The current Matrix and Bible still retain the two-count pair-ending baseline.
This section records an alternative to evaluate, not a silent amendment of that
baseline. Section 4.2 item 40 already preserved a dormant distinct-standalone
Day 6 idea; it did not previously select Room 2.17 or a one-meeting ending.
The exact old approval recalled by the owner has not been recovered.

Before promotion, reconcile the owning mechanical design, the Matrix, and the
Bible's derived ending wording in the same approved change. In particular,
recheck the old claim that Priscilla/Lavinia solo Observer evidence cannot
coexist with a P-L ending: that proof uses two counted windows and cannot be
silently reused for a new Day-6-only route. No Observer compatibility is granted
or prohibited by this note alone.

The separate double-R3 rule suppressing Priscilla's and Lavinia's personal
Day 7 invitations is not changed here. A new one-meeting eligible path can
therefore expose different combinations of ending layers. The final plot must
make those combinations coherent or select an explicit incompatibility; it must
not silently confiscate Angela's options or replace her personal core.
Frozen form, scene occurrence, count, audience witness, Angela's knowledge,
mastery, profile receipts, and ending eligibility remain separate. No hidden
intimacy, injury, or reconciliation is supplied merely because a meeting counts.

### Fictional and presentation debts

- Establish why necessary Room 2.17 work belongs on Day 6 and what happens to
  the corresponding work in tea histories; a hidden count cannot make an
  ordinary institutional obligation vanish.
- Reconcile Room 2.17's protected Love future-return function with Day 7
  without inventing another encounter window or automatic Day 8 scene.
- Author tea after different occurring Day 2 forms rather than copying the
  Sweet-Love mood after Dark. The portrait read-through establishes no
  continuing mark or healing duration.
- Give each ending-eligible history its own necessary decisions and evidence.
  The Room history cannot remember the bar; the two-meeting history must retain
  the significance of its additional encounter.
- Preserve one shared ending situation with the required four substantive
  form resolutions where earned; history-sensitive setup must not manufacture
  missing promises, permissions, or hidden agreement.
- Check reload/replay determinism only after the actual approved content and
  predicates are selected. No tests have been run for this proposal.

The 2026-09-26 capture did not inspect implementation bodies or re-audit all
historical drift rows in Section 3. Those rows retain their earlier inspection
scope; PR #1's current runtime is not being described anew by this docs change.
No code, save schema, manifest, workflow, runtime test, or PR #1 file is changed.
