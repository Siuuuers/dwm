# Core Story Bible

## Document Authority

This is the private, spoiler-complete narrative authority for DWM. It records what is true, what may vary, and what must remain unresolved. This Bible remains the sole narrative authority. The Character & Relationship Handbook is derived character and performance guidance; the [Narrative Style Manual](08-narrative-style-manual.md) is derived cross-scene presentation and drafting guidance; the Seven-Day Production Map is a plot-neutral production rendering; the Public Project Profile is a spoiler-safe projection. Runtime code owns physically implemented behavior and may expose drift, but it never silently revises narrative canon or intended audience-facing meaning.

Authority follows this order:

1. Later explicit approvals supersede earlier proposals and the original brief.
2. The August 7 seven-day design owns baseline intended mechanics and Dialogic flow as amended by later explicit approvals and the recorded future-behavior boundary.
3. Runtime code owns physically implemented behavior, including its availability, UI, replay and skip behavior, health counters, line identity, localization, and save/load implementation. Compare it with the August design to identify drift; do not promote implementation drift into intended law without approval.
4. This file is the sole narrative authority for character, relationship, atmosphere, hidden history, and intended audience-facing meaning.
5. The Seven-Day Causal Matrix owns fixed obligations and approved placements.
6. The Character & Relationship Handbook and Narrative Style Manual are derived; the Seven-Day Production Map is plot-neutral; and the Seven-Day Scene Beatbook expands approved load-bearing scenes. None may revise the authority above.
7. The Plot Material Library and July canon amendments preserve provenance, not active authority.
8. The original brief controls only decisions not superseded by later approval.
9. Research may correct physical-world terminology and plausibility, but it may not change approved fictional canon.

**Mechanical supersession notice (2026-08-07).** Where this file's ending or
mechanics wording conflicts with the approved bounded specification
`docs/design/2026-08-07-seven-day-dialogic-flow-design.md`, that specification
supersedes the conflicting mechanical detail. This notice changes no character,
relationship, voice, atmosphere, or narrative canon, which this file continues
to own.

Use approved first names only. Do not invent surnames. Production notes may describe staging, but they are not released narration. This authority does not create exact schedules, variables, thresholds, UI styling, replay logic, or other implementation facts that belong to code.

## Project Identity

- **Public genre:** Adult psychological-horror visual novel and relationship mystery
- **Setting:** East Harbour University and its affiliated East Harbour Conservatory of Performing Arts, on a fictional dense hillside campus near Kowloon, Hong Kong
- **Season:** Late October or early November
- **Length guidance:** The former two-hour first-clear figure applies only as a soft target for plot content and may be exceeded when the material earns it. It is not a canon, compatibility, or hard production limit; no current five-hour full-completion limit is fixed here.
- **Internal engine context:** Godot with Dialogic 2, mentioned only when useful to production

All four principal characters are adults.

**Public logline:**

> During a seven-day university open week in Hong Kong, astrophysics student Angela arranges meetings with three women whose private histories continue without her. As schedules, messages, and memories disagree, choosing where to be cannot determine what anyone wants.

## Experience Contract

Angela is the only affectable character, but she is not the centre of every relationship. The audience can shape her available expression and intended action, but cannot author her personality, anyone else’s desire, or consent. Choices have genuine local consequences while other people continue acting outside Angela’s attention.

Use **audience** for narrative analysis. Use **player** only for technical input, accessibility, or platform language.

### Audience-Visible Scene Boundary

Audience-visible plot appears through exactly three current narrative surface classes: messages, dating scenes, and endings. Dating scenes include Angela-attended solo or scheduled encounters, Angela-attended Group encounters, and explicitly authorized Priscilla–Lavinia private counterparts. Hospital may become the setting or variant of an encounter or ending; it is not a fourth class. Ending preludes, cores, later relationship layers, postscripts, and Observer codas remain inside the ending surface.

No standalone cutaway follows Priscilla, Lavinia, or Sylvia outside those surfaces. The Day 2 umbrella history occurs offscreen within the fiction and may be inferred only through lawful carriers inside messages, dating scenes, and endings; neither the event itself nor an explanatory reconstruction is shown.

Friends continue acting outside Angela's attention. Those actions may exist as private causality and may later enter an authorized scene through an object, record, message, changed circumstance, or dialogue. Hidden detail earns canon only when it changes visible behavior, supplies necessary causality, or prevents contradiction; otherwise omit it.

## Dramatic Questions

- **Angela:** When does refusing to act become choosing?
- **Lavinia:** Can attention prove love when it must be provoked?
- **Priscilla:** Does understanding grant authority over another person’s choices?
- **Sylvia:** When does help become a method for arranging permanent debt?

These are writer-facing questions, not arguments the characters announce.

## Canon Vocabulary

Use a category only where ambiguity could otherwise be mistaken for a contradiction, and apply it at the smallest useful scope.

- **FIXED FACT:** True in every playthrough.
- **MODAL EVENT:** One truthful possibility among mutually exclusive versions.
- **REACTION TEST:** Guidance for how a character would react; it did not necessarily happen and is not shipped dialogue unless separately promoted to canon.
- **UNRESOLVED CAUSE:** The event or evidence is real, but its author or mechanism is unconfirmed.

No reaction test becomes hidden history by repetition. No unresolved cause receives a private answer unless a later approved canon change explicitly supplies one.

## East Harbour University and Conservatory

East Harbour University and the East Harbour Conservatory of Performing Arts share a fictional urban campus near Kowloon. The site is dense and vertical: stacked buildings, covered walkways, stairs beside lifts, retaining walls, short steep streets, and rail-plus-minibus access. It evokes Hong Kong circulation without copying one real institution or claiming that every building connects underground.

The conservatory is institutionally affiliated with the university. Angela studies astrophysics at the university; Priscilla studies English literature; Lavinia studies ballet through the conservatory; Sylvia studies statistics or decision science at the university. Ordinary academic and conservatory work continues during the story.

## Open Week Structure

“Open Week” is East Harbour’s name for the seven-day production period, not seven full public open days. Preparation, limited departmental activities, rehearsals, tours, appointments, and visitor-facing sessions culminate in a single major Saturday Information Day—the week’s one-day public culmination. Classes, rehearsals, shifts, and assigned duties continue throughout.

Open Week does not manufacture attraction to justify a seven-day progression. Neutral institutional duties place existing familiarity, desire, curiosity, investment, receptivity, care, and control methods into a shared timetable. Experience may expose or test them, and repeated character-authored decisions may deepen or transform an attachment. A schedule, state progression, tone classification, board result, or Observer Pressure cannot perform that transformation by itself. Records, expectations, attendance, absence, and practical consequences make postponement harder and previously deniable conduct more difficult to isolate. Observer Pressure may amplify clustering or urgency, but it cannot originate desire, consent, obligation, or decision. Day 7 culminates accumulated pressure; it is not sudden love, a compulsory confession, an official label, or the end of the characters’ lives.

- Angela supports astronomy demonstrations and late observation.
- Priscilla handles programme language, communications, and student organization.
- Lavinia rehearses and performs through the conservatory.
- Sylvia supports welfare, safety, scheduling, and visitor logistics within her limited volunteer role.

Dates and meetings occupy practical windows around these responsibilities. The August 7 design fixes the intended twelve solo and two conditional pair windows. Runtime decides what is physically implemented and is checked against that design for drift; implementation availability never silently becomes intended law.

## Seven-Day Fixed Spine

- Priscilla is present from Day 1.
- Lavinia returns to Hong Kong on Day 2.
- On Days 1–6, Angela may attend up to two dates or scheduled actions with two different women in the intended windows. The Seven-Day Causal Matrix owns approved placements; this Bible does not reproduce the calendar.
- Day 7 contains one decisive schedule choice during the public culmination.
- A personal ending action appears only when the relevant relationship is at ambiguous or love. Ineligible actions do not appear as locks, silhouettes, or disabled alternatives.
- If Angela attends no Day 7 date and completes her final observation, she receives the Alone Ending. This is a deliberate choice, not a failed route.

The selective reset reopened the former three calendar evidence anchors. Their
compact forms remain below as historical plot reference, not forward canon;
the new plot must explicitly retain, replace, or reject each one. Lavinia's
ordinary Day 2 return remains a separately retained continuity and does not
become a replacement mystery anchor.

### Day 1 — Institutional Uncertainty

**REOPENED PLOT REFERENCE.** The former premise placed Lavinia’s name prematurely on an Open Week roster. It allowed an old template, ordinary clerical choice, human alteration, or anticipation of her return; a replacement plot may not assume the roster or any of those readings without explicit approval.

### Day 2 — Ordinary Return, Not a Separate Anchor

Lavinia returns to Hong Kong because the agreed period of her sponsored company
attachment has ordinarily concluded. If the new plot explicitly retains the
former premature roster, her return may make that inclusion current without
explaining why the name appeared early; the return does not require the roster
to survive. Day 2 adds no automatic dedicated message pair, pre-echo, timing
contradiction, or replacement anomaly. Priscilla–Lavinia residence and access
history remains under its explicit migration hold and cannot be used to
manufacture a Day 2 mystery.

### Day 4 — Sylvia’s Preparation

**REOPENED PLOT REFERENCE.** The former premise used a welfare incident slip already containing Lavinia’s name, the correct location, and the kind of help soon required. Its fields, timing, alteration possibilities, and carrier are not forward facts until explicitly retained.

### Day 6 — Audience Implication

**REOPENED PLOT REFERENCE.** The former premise placed an ordinary Open Week location check-in prompt on Angela’s phone, with confirmation and expiry records beginning a plausible intervention. The prompt, records, intervention, and carrier are not forward facts until explicitly retained. The false cursor remains exclusive to Angela–Lavinia Observer language and can never become a general causal explanation.

## Physical-Reality Rules

- Late October or early November is active teaching term. The characters still have classes, rehearsals, shifts, and Open Week duties.
- Conditions are warm-to-mild and humid, with aggressive indoor air-conditioning and cooler late-night rooftops. A Day 2 shower is ordinary; continuous heavy rain all week is not.
- Hong Kong International Airport and its rail access are covered, so Lavinia’s request for a long umbrella may be practical for the onward journey or emotionally significant as a familiar domestic object.
- Kowloon-to-airport travel requires credible terminal, baggage, waiting, rail, and onward-transit time. Priscilla cannot appear at arrivals immediately after being called.
- Public urban observation emphasizes the Moon, seasonally visible bright planets, bright stars or double stars, telescope operation, and light-pollution measurement. Do not promise dense star fields, Milky Way detail, or faint deep-sky targets from the campus.
- Astronomy activity has an indoor or weather-safe fallback such as telescope demonstration, archived or remote imagery, or a light-pollution exercise.
- An observed faint is not an instant diagnosis. Continuing unconsciousness, injury, exertional onset, or incomplete recovery warrants qualified help. A first aider may provide immediate assistance within training but may not diagnose or decide ongoing care.
- All extraordinary effects remain physically possible at the local level. No scene uses impossibility as a shortcut around consent, responsibility, or evidence.

## Observer Pressure

**Observer Pressure** is the writer-facing term. **Love God** is an internal production nickname. Neither is a confirmed entity, public character, or canonical supernatural explanation.

Observer Pressure may:

- increase plausible collisions;
- amplify existing attraction or emotional intensity;
- create physically possible coincidences, timing failures, and interface irregularities;
- make an ordinary causal chain nearly impossible in combination.

It may not create consent, define desire, force a decision, or answer the mystery. Characters do not recognize it as an entity. They treat anomalies as practical inconveniences unless credible danger demands a stronger response.

## Mystery Fairness and Functional Abnormality

The evidence mystery is a three-source braid:

1. human interference;
2. mundane error or coincidence;
3. unresolved Observer Pressure.

It is locally fair and globally uncertified. Every incident needs an
ordinary-compatible causal account, while attentive cross-route synthesis may
make one account better supported without certifying the complete pattern. The
hidden apartment can explain knowledge without accounting for the complete
pattern. Sylvia's preparation can explain readiness without proving the means
or cause of later harm.

Normalized abnormality has no numerical per-scene quota. Every foregrounded
weird, eerie, or absurd element must perform a distinct practical,
evidential, or relational function under the
[Narrative Style Manual's functional tests](08-narrative-style-manual.md#6-the-weird-the-eerie-and-socially-exact-absurdity).
Several may coexist when their functions do not duplicate one another, bury
the characters' actions, or make the material causal sequence unreadable.

`Normalized` means that characters address the local fact without announcing a
horror category. It does not mean nonreaction, causality-free randomness, or
unsafe continuation. Credible danger still receives proportionate practical
or qualified help.

## Character Canon Essentials

### Angela

Angela is 20, Hong Kong-born, and a second-year astrophysics student. Cantonese is her everyday language, academic English is fluent, and Putonghua is situational. Her emotional minimalism is temperament, not trauma shorthand. She loves astronomy and strategy games with disproportionate intensity; she is skilled at resource management and often lucky, but neither advantage transfers cleanly into relationships or moral responsibility. Her deadpan is partly performed: she invents elaborate, intentionally ridiculous deductions to amuse, annoy, or destabilize, and uses physics or game language only when the metaphor is genuinely precise. Once someone enters her inner circle, she accepts strange requests she would dismiss as unnecessary side content from anyone else. She has no prior romantic experience and is drawn to attentive care. She willingly delegates choices but requires reality to remain independently inspectable. Her greatest danger is using uncertainty as moral shelter while enjoying another person’s controlling care.

Recognition is not classification. Angela may accurately notice an abnormality, flirtation, control, or preparation—including a controlling gesture or prepared arrangement—and still decline to classify, investigate, or answer it when doing so would create an obligation she prefers to postpone. Normalization is selective priority, not perceptual failure. Ignoring what she noticed remains a consequential character choice. A person, task, threatened result, or loss of inspectability may become more troublesome to Angela than the impossible-looking detail itself. `Troublesome` remains a writer-facing threshold, not a required catchphrase or supernatural alarm.

### Priscilla

Priscilla is 20, Hong Kong-born, and an English literature student with institutional credibility. She speaks polished Cantonese and English, selecting public language for control of nuance. Care appears as management, correction, anticipation, and selective truth; her attention inventory includes preferences, walking pace, silence patterns, stress tells, familiar routes, and habits. She overreads language and patterns but is not a mind reader, and desire makes her most likely to overfit or use the right lever at the wrong moment precisely when accuracy matters most. Her deepest fear is not dramatic abandonment but informed independence: someone becoming completely capable of leaving and calmly preferring an imperfect life outside her management. Her love is genuine; its coexistence with acquisition and control makes it frightening.

### Lavinia

Lavinia is 22, Romanian, from a wealthy Bucharest family, and a conservatory ballet student. She is fluent in English, uses Romanian in private, and is developing Cantonese without comic incompetence. She treats powerful reaction as evidence of importance and may provoke attention rather than ask directly. Her parents’ generous freedom and material support do not always feel like precise attunement; she may administer tests other people do not know exist and associate resistance with attention. Her professional discipline coexists with physical and emotional boldness. Her persistent load-related lower-limb pain is symptom-based canon; no exact diagnosis is fixed.

### Sylvia

Sylvia is 21 and a third-year statistics or decision-science student. She is an Open Week peer-welfare and safety volunteer with a current basic first-aid certificate. She may know public schedules, assigned rooms, check-in procedures, and incident workflow. She has no diagnostic authority, private-record access, or legitimate right to conduct a general physical examination. Unable to risk asking to be wanted, she arranges to be owed and translates personal or erotic desire into practical, medical, or moral necessity. In her darker private logic, each successful rescue should narrow Angela’s alternatives until Sylvia appears to be the only reliable person, gratitude becomes permanent debt, and compliance feels like reasonable repayment. Her prudishness governs how she explains desire, not whether desire exists; no explanatory label creates consent.

## Fixed Hidden Histories

These facts are private canon. The released game reveals them only through partial evidence, behavior, or approved fragments and endings.

### Angela–Priscilla Childhood Incident

At age twelve or thirteen, Angela was wrongly blamed for alteration or deletion of a group science project. Priscilla possessed suggestive but inconclusive evidence, fabricated one recovery record, and correctly identified the culprit. Angela believed the exonerating evidence was authentic. Priscilla then arranged the culprit’s private humiliation through truthful information, without charge or appeal. Her conclusion was right; her procedure was wrong. The incident taught Angela that Priscilla could make disputed reality legible and taught Priscilla that a true conclusion could justify control of the record.

Angela initially withdrew rather than perform innocence for adults who already preferred the easier account. Priscilla began investigating because an incorrect version of events offended her sense of order, not because she consciously understood the act as devotion. The incident trained both sides of their later pattern: Angela learned that Priscilla could spare her the labor of making reality believed, while Priscilla learned that controlling the record could make a true conclusion socially real. Being correct in this first case never makes the method safe; it trains Priscilla to confuse confidence with proof and leaves her capable of privately sentencing the wrong person in another case.

### Priscilla–Sylvia Sisters

Priscilla and Sylvia are sisters, and Angela has known both since childhood. Knowing Sylvia as Priscilla’s sister never produced equal intimacy: Angela’s relationship with Sylvia remains that of a long-standing occasional acquaintance, while Sylvia has had more opportunity and inclination to observe Angela than Angela recognized. The sisterhood is an ordinary family fact to Angela and the sisters and should reach the audience incidentally rather than as a conspiratorial reveal. It creates no romance, route, state deck, or ending between the sisters and grants no automatic access to the other’s records, rooms, messages, desires, or hidden intentions.

Their control methods share a family resemblance without establishing a shared formative cause. Priscilla makes desire defensible through wording, records, and social authorship; Sylvia makes it defensible through preparation, risk, access, and care debt. Each may recognize the other’s overreach more readily than her own. They do not coordinate hidden intentions, and Sylvia’s fixed harmful intent toward Angela belongs to Sylvia alone.

### Angela–Lavinia University Friendship

Angela and Lavinia first met through an astronomy class and became university friends there. Their later astronomy encounters resume an existing ordinary intimacy rather than manufacturing a first bond.

### Priscilla–Lavinia First Recognition

At a bar gathering, Priscilla recognizes Lavinia before their formal introduction. Lavinia has already made a subtle refusal to a persistent pursuer, who continues anyway. Priscilla is also irritated by the disturbance and uses precise sarcasm to embarrass the pursuer into leaving. Lavinia is grateful. Priscilla already experiences Lavinia as fascinating and threatening, while Lavinia does not initially recognize the danger in Priscilla’s attention. This recognition and asymmetry are fixed; the reason Priscilla knew Lavinia first is not separately established.

Before the company attachment, their conduct became openly flirtatious and near-romantic without acquiring an agreed label. Their immediate fluency on Lavinia’s return therefore belongs neither to strangers beginning an attraction nor to confirmed lovers resuming one.

### Priscilla–Lavinia Shared Apartment

**SUPERSEDED FOR FORWARD USE — CANON MIGRATION OPEN:** This subsection preserves
the former cohabitation premise as inspectable history; it is not current
residence authority. The later owner-confirmed working premise makes Lavinia
the sole resident of the family-provided flat, places Priscilla elsewhere, and
grants Priscilla no bedroom, tenancy, or resident status there. Repeated
separately admitted crossings may create domestic fluency and bounded traces
without becoming cohabitation or a relationship label. Exact access, object,
key, bar, and residue facts must await the required raw chronological
conversation audit before this subsection is replaced.

Lavinia’s family provides a private two-bedroom flat near campus. Priscilla obtained family permission to live there by presenting Lavinia as a respectable roommate and family connection. Lavinia knowingly joined the deception and initially found it amusing. The arrangement became irregular cohabitation before England, with one bedroom each. After their fight, Lavinia could expose Priscilla’s lie to Priscilla’s parents with one message and chooses not to; that silence is one of her embarrassing proofs of care. She retains a key.

While Lavinia is in England, Priscilla maintains the appearance that they still live together. During video calls with her parents, she carefully frames a second cup, Lavinia’s coat, or another domestic residue. When asked for photographs, she may reuse an older image without falsely stating when it was taken, and she occasionally refers to something “we” purchased. She sustains the misunderstanding through selective truth rather than an easily disproved claim.

Sylvia is sometimes present on the family side of these calls. Their parents accept the surface because each displayed object and statement is individually plausible, not because they are foolish or uncaring. Sylvia recognizes that Priscilla is constructing evidence of continuity rather than merely showing the flat. Across multiple calls, she correctly infers a rupture between Priscilla and Lavinia, but she does not learn its cause, the disclosure-form conflict, either woman’s private interpretation, or any agreed relationship label. She does not tell their parents. Whether Priscilla knows that Sylvia has inferred the rupture remains unresolved.

Priscilla keeps Lavinia’s bedroom prepared and insists that preserving it is necessary for the cover story. Whether she enters it to clean, inspect, remember, or search remains unresolved. The game never directly confirms the apartment arrangement, and neither woman treats possession of the key as an agreed relationship label.

### Lavinia’s Company Attachment and Lower-Limb Conflict

Lavinia spent approximately four months in England on a **sponsored company attachment** arranged through the conservatory. She trained with the company, rehearsed selected repertoire, and was considered for future professional work. Distance did not turn her into a penitent lover waiting to return: she did not settle on missing one particular person and reconsidered whether she had been entirely right, but she did not become repentant or forgive Priscilla’s overreach.

Before departure, Lavinia authorized Priscilla to polish and submit institutional language, not to change its substance. Priscilla changed a minimized description into a factually defensible but maximally consequential account of persistent load-related lower-limb pain and its functional effect, then submitted it without Lavinia’s review. The revision prompted assessment and temporary modified participation, including reduced high-load material or adjusted rehearsal volume. Lavinia was later cleared to continue under an agreed plan; this did not prove her pain-free or uninjured. The exact site, cause, and diagnosis remain unfixed.

Priscilla acted from two true motives at once. She genuinely feared that continued training could turn Lavinia’s condition into lasting injury, and she also welcomed any legitimate institutional consequence that might delay Lavinia’s departure. She selected the defensible wording most likely to make assessment mandatory and thereby create a credible risk of delay, then ensured the consequence occurred before Lavinia could object. Had protection been her only aim, she could have confronted Lavinia, refused to submit the minimized account, or insisted upon assessment openly; secrecy converted legitimate care into control. Lavinia was legitimately violated and professionally frightened, but also affected by Priscilla noticing what she had tried not to admit. Being moved by the care never reduces the violation. Lavinia ultimately left, so the intervention failed to keep her in Hong Kong but contaminated the departure psychologically. The writing must never settle whether Priscilla wanted someone to stop the injury or stop Lavinia from leaving.

**Owner clarification recorded 2026-09-26: Priscilla's judgment of this intervention.** Priscilla does not regard her unauthorized substantive amendment and submission as an act she ought not to have committed. She knows what she changed and can understand Lavinia's objection without accepting that the intervention was wrong. Her dissatisfaction concerns how imperfectly she secured the outcome and retained Lavinia's closeness; she may adapt her manner and conduct to Lavinia's wishes without revising that judgment. Genuine affection and protective concern remain present, and neither cancels the violation. Do not recast tactical adaptation, tenderness, acknowledgment of hurt, or regret about the resulting distance as moral remorse for the amendment. This clarification concerns this intervention, not a universal inability to recognize wrongdoing or a predetermined judgment of another act.

This records the owner's explicit correction, not the promotion of a new scene. It supersedes remorse-based interpretations of the amendment in derived guidance and older bar auditions, including the old shame formulation to that extent only. It does not change the event's medical particulars, grant prior physical or sexual intimacy, resolve residence history, select a Day 2/Day 6 encounter, or change an ending rule. The [bounded working record](../docs/story-auditions/2026-09-26-priscilla-lavinia-portrait-and-intimacy-working-record.md#21-priscillas-judgment-of-the-disclosure-intervention) preserves the correction's scope separately from unplaced relationship and intimacy exploration.

### Sylvia’s Asymmetrical Familiarity

Angela has known Sylvia since childhood as Priscilla’s sister but still knows her personally only as an occasional acquaintance and recognizes her current volunteer role. Shared family context may explain Sylvia’s early awareness of Angela’s name and limited old habits; it does not justify the depth of her present study. Public schedule access and observation explain much, but not her exact timing or private knowledge. Sisterhood grants no access to current messages, private records, medical information, rooms, or consent, and any unauthorized use of check-in or incident information remains a boundary violation rather than a privilege of family or peer welfare. Sylvia has no past-fragment deck and no Observer Ending.

## Relationship State and Tone

Relationship state progresses in one direction:

`Friend → Ambiguous → Love`

Friend names the starting degree of reciprocal enactment available in Angela’s route. It does not mean the absence of attraction, flirtation, long history or familiarity, dangerous comfort, or one-sided investment. State measures mutual legibility and consequence, not romantic availability: the internal `Love` label does not by itself establish romantic desire or reciprocity. Progression changes what may become mutually legible and consequential; it does not manufacture desire or personality.

The three Angela pairings remain deliberately unequal on Day 1:

- **Angela–Priscilla:** Correction, verification, and selective delegation form a familiar, relationally charged rhythm. Long practice supplies neither automatic romantic reciprocity nor blanket permission and does not contradict Angela’s lack of prior romantic experience.
- **Angela–Lavinia:** Their existing astronomy friendship already permits natural, knowingly understood teasing and flirtation. Lavinia does not habitually retain a prepared “only joking” escape in a charged exchange: she means the flirtation as flirtation, not as a promise to pursue romance. Angela may recognize the register without knowing Lavinia’s whole private desire or owing reciprocity.
- **Angela–Sylvia:** The baseline is asymmetric. Sylvia is already personally and erotically invested. Angela brings childhood recognition, occasional familiarity, and possible receptivity to useful care rather than established reciprocal romantic intent.

- Priscilla, Lavinia, and Sylvia each begin at Friend in Angela's relationship state.
- Hate is not a reachable tier; hostility, refusal, and resistance remain character-specific attitudes that can occur at any tier.
- The internal `affection` value means relational momentum: it may contribute to an approved readiness predicate but never measures or manufactures love, desire, consent, virtue, compatibility, or truth.
- Relationship progression remains a real code-owned event at a small explicit list of scene-authored windows. The exact forward window list and predicates are reopened until the approved seven-day plot earns them; the former Priscilla Day 4/6, Lavinia Day 5/6, and Sylvia Day 4/5 schedule is legacy provenance rather than a current plot constraint.
- An approved window may move at most one tier only after its complete attended consequence and inputs are frozen and committed.
- Unread, missed, prevented, and Hospital-superseded opportunities do not evaluate or silently relocate. Whether a committed Sylvia Hospital dating variant inherits an approved window remains open; Hospital access alone cannot supply progression.
- Friend receives restrained mutuality, Ambiguous receives fuller mutuality, and Love receives deeper specificity without another tier. Romantic desire or behavior may become legible in any approved scene or ending when character-authored conduct earns it; the tier neither proves nor forbids romance.
- A fragment never advances state.

Personal Day 7 endings are eligible only at ambiguous or love. For Priscilla and Lavinia, that tier gate is necessary but not sufficient: if R3 activation succeeded on both Day 2 and Day 6 in the active continuation, neither individual invitation is generated. This audience-priority fact remains separate from pair count and Angela's knowledge. An ineligible or suppressed action is absent rather than visibly locked; no substitute, gap, warning, or explanation appears.

The August design owns baseline state and tone mechanics as amended by later explicit approvals, while runtime is inspected for drift. A fragment does not create or change tone.

- **Sweet:** The decisive conduct foregrounds tender, playful, ordinary, or less-dangerous facets of the characters involved. Dark capacities remain part of the same personalities and may exert pressure through implication, impulse, or near-action; Sweet neither deletes them nor requires a named destructive pattern to be interrupted, a boundary lesson, or a prescribed cost. Desire may remain obsessive or costly, but the character's darkest instrument does not become the decisive means by which she tries to secure the attachment. Sweet is a complete relational consequence, not failed or withheld romance.
- **Totally Dark:** A character-specific darker facet becomes observable chosen conduct with concrete consequence because desired love or attachment makes one concrete limit, value, truth, safety, freedom, relationship, or other protected interest expendable. The exact expendable interest must be identifiable in the plot. The label neither creates that capacity nor certifies it as the character's truest self, and it does not require every participant to knowingly reinforce the same pattern. Harm remains real; attachment does not make it harmless. `Stop at nothing` is emotional shorthand, not a literal world law or escalation quota.

State controls what mutuality is available; tone controls which character facets govern the visible ending variation. Tone is not mood, kindness, health, virtue, or a moral rank. State never grants consent, rewrites desire, or erases refusal. Tone does not act inside the fiction or authorize another person's desire or consent: it records and selects the consequence of character decisions. Sweet and Totally Dark must differ through substantive conduct and consequence rather than palette, diction, or cruelty alone.

No state, tone, event, or ending applies an official relationship label. Dialogue and visible behavior may support “couple,” “lovers,” “friends,” or something unclassifiable, but the released text never settles the question for the audience.

### Asymmetric but Romantically Open Geometry

Priscilla and Lavinia retain unmatched shared history and the strongest autonomous gravity between them. That asymmetry does not categorically forbid either woman from romantically desiring Angela in any continuation; Sweet and Dark do not govern romantic eligibility. An exact scene may make desire or romantic behavior clear while leaving the relationship's final category unsettled; it may also remain charged without becoming romantic. Angela's attendance never displaces the older bond, and attention directed toward her never proves reciprocity.

An Angela solo encounter may make Priscilla or Lavinia's attention conspicuous to the other woman, and a particular act may be intended to provoke jealousy. That motive cannot explain every encounter. Each woman must also have a self-sufficient want concerning Angela, so Angela remains a person in both relationships rather than a prop passed between them.

No state, tone, counter, board result, audience observation, or Observer Pressure switches desire on. Sweet may contain honest romantic desire or behavior without an official label, exclusivity promise, or route-certified ownership. Totally Dark is not a romance reveal or a higher truth: it permits a character-specific darker facet to become the decisive chosen method and produce a concrete consequence. Repeated conduct may intensify or reorganize an attachment, but any romantic meaning must arise from the characters' history and actions rather than from the form label.

- **Priscilla:** One available darker pattern turns the satisfaction of being an indispensable interpreter into a need to remain the person who can state, arrange, and socially stabilize what Angela means. It operates through language, interpretation, records, access, scheduling, and authorship of shared social reality—not generic possessiveness or Lavinia's demand for reaction. It is a character-specific possibility, not a compulsory transformation.
- **Lavinia:** One available darker pattern turns a desired reaction into the response she must provoke again, until intensity becomes personal necessity rather than momentary proof. It operates through provocation, embodied tests, and demanded response—not generic stalking or Priscilla's authorship of outcomes. It is a character-specific possibility, not a compulsory transformation.
- **Angela:** When an Angela-facing Dark consequence relies on her participation, the scene must make Angela's knowing performance or permission legible because delegation, intensity, relief, or the experiment itself satisfies her. Recognition does not make the pattern safe. Prior participation never grants blanket consent to later control, testing, touch, exclusivity, or harm, and Dark does not require both participants to use matching dangerous instruments.

An Angela pairing—Sweet or Dark—does not erase or subordinate the Priscilla–Lavinia bond, establish a triad, promise exclusivity, or retroactively convert earlier scenes into concealed romance. Angela may become necessary without becoming the centre of either woman's history.

## Event Architecture

Date is production shorthand for an Angela-attended solo encounter, not a diegetic promise that either woman considers it romantic. A selected premise may surface as deliberate, practical, obligatory, or incidental, but apparent coincidence cannot bypass the August-owned invitation, scheduling, attendance, Hospital, or absence law.

Group remains the authorized Angela–Priscilla–Lavinia presentation of a Priscilla–Lavinia pair window. Its private counterparts remain Priscilla and Lavinia without Angela. This clarification creates no triad route or additional surface.

The mechanically fixed architecture contains twelve solo invitation windows and two conditional Priscilla–Lavinia windows. That count fixes windows, not premises. Named Events 1–12 and 14 below are noncanonical audition material preserved in the library, and the former Event 13 Production Map card is likewise noncanonical. Room 2.17 is a separate `APPROVED CAUSAL CORE — PLACEMENT UNSELECTED`: its causal design remains protected, but Day 2 versus Day 6 has not been selected. The former three mystery anchors are reopened; only the separately retained Day 2 ordinary return and umbrella history, character canon, and hidden histories survive regardless of which new premises are later approved. An exact production card may arise only from an `APPROVED` Causal Matrix row.

The production boundary is the Two-Pass Constellation. Pass One records the plot-free global skeleton: fixed encounter windows, candidate or reopened progression-window status, anchor and residue obligations, absence and fallback behavior, and cross-day debt. Pass Two auditions whole-day causal constellations. For ordinary audition survivors, explicit approval and an `APPROVED` Causal Matrix row are required before the Beatbook may expand that row's approved causal facts. The already approved, placement-unselected Room 2.17 causal core is the sole bounded current Beatbook exception. That exception preserves only its existing approved causal and execution boundary: its exact Day 2 versus Day 6 placement and any unapproved adaptations must return through audition and explicit approval. Neither a retained library card nor current runtime behavior promotes a premise into canon.

### Noncanonical Audition-History Catalogue

Everything through the end marker below is a bounded catalogue of earlier premise summaries and arc notes. The names, numbering, activities, clue carriers, and arc descriptions are preserved for audition history only; they do not define the active fourteen-window plot, select a weekday, or authorize production.

<!-- BEGIN NONCANONICAL AUDITION-HISTORY CATALOGUE -->

### Angela–Priscilla Premises

1. **The Programme Table:** Open Week preparation reveals the premature roster entry; Priscilla calmly instructs Angela to leave it unchanged.
2. **The Borrowed Book:** In a used bookshop, Priscilla studies how Angela annotates something Angela selected for herself.
3. **The Public Question:** Priscilla approaches the boundary between preparing Angela and speaking for her; the scene supplies Capture/Compare material.
4. **No Task Left:** Angela asks Priscilla to remain after utility ends. Presence without management supplies the one-tier leveling opportunity.

The arc moves from institutional control through private interpretation and social authorship to presence without utility.

### Angela–Lavinia Premises

5. **The Returned Seat:** Lavinia resumes her former place in the evening astronomy setting; the unsent-message anomaly surrounds their reunion.
6. **Borrowed Gravity:** A conservatory movement activity uses touch, bodily trust, and Angela’s deadpan humor.
7. **After the Music:** A campus social setting allows Lavinia to test attention or jealousy.
8. **Before It Hurts:** Angela notices discomfort before Lavinia manufactures a crisis. Offered care and Lavinia’s voluntary acceptance supply the one-tier leveling opportunity.

The arc moves from return through embodied play and provocation to attention without provocation.

### Angela–Sylvia Premises

9. **Exactly on Time:** Sylvia appears with precisely what Angela needs; an earlier faint activates the hospital-arrival variant.
10. **A Quiet Table:** Sylvia already knows Angela’s likely order, schedule, and preferred route.
11. **The Caretaker’s Break:** Angela notices Sylvia neglecting her own food and rest. Reciprocal care supplies the one-tier leveling opportunity.
12. **Contingency:** Welfare preparation exposes the incident slip and check-in system. A high code-owned health-neglect state introduces concealed, non-actionable preparation for the Special postscript.

The arc moves from timely help through studied familiarity and genuine reciprocity to manufactured necessity.

### Priscilla–Lavinia Counted Premises

13. **Three Versions of the Sky:** Programme language, astronomical material, and performance presentation force public collaboration.
14. **After the Run-Through:** Rehearsal aftermath, transport, pain, and a familiar key bring concealed history close to the surface.

Each counted event has an Angela-attended group version and an audience-observed private version. Increment the pair counter only when the encounter actually occurs in either version. If Angela separately occupies Priscilla or Lavinia during that window, they do not meet and the counter does not advance.

<!-- END NONCANONICAL AUDITION-HISTORY CATALOGUE -->

### Day 2 Offscreen Umbrella History

The umbrella history is one fixed offscreen event outside the fourteen-window
audition catalogue and pair counter. During Lavinia's Day 2 arrival in Hong
Kong, after landing and while she is still completing arrival formalities or
waiting for baggage, she privately asks Priscilla to bring the long umbrella.
Priscilla is not already waiting at the airport. She chooses to travel there,
meets Lavinia in the public arrivals area only after baggage collection and
customs, and travels onward with her. The umbrella remains closed throughout
the covered terminal, Airport Express platform, and train; any practical use
belongs to a later exposed part of the onward journey.

Lavinia's practical request is genuine, as is her deniable wish for Priscilla's
presence. Priscilla answers by coming and by exceeding the requested help, so
care and control coexist. Neither woman calls the meeting a reconciliation,
and it does not erase their unresolved conflict. Exact sending time, weather,
route, waiting duration, private wording, and over-helping gesture remain open.

The released game never depicts or directly recaps the event. Bounded in-game
facets may establish an umbrella's presence, custody, condition, changed
location, recognition, or familiar shorthand inside a message, dating scene,
or ending, but even their union must leave the event's date, airport location,
initiator, sequence, motive, and relationship meaning unconfirmed. The main
plot remains intelligible if a player overlooks the inference. The history
never grants relationship state, tone, pair count, board credit, Observer
evidence, witnessed-combination credit, route access, or ending eligibility.

## Priscilla–Lavinia Four-State Deck

Priscilla and Lavinia’s fixed shared history means they begin every playthrough at ambiguous or love. Each new playthrough draws one complete state/tone combination:

1. ambiguous + sweet;
2. ambiguous + dark;
3. love + sweet;
4. love + dark.

Until all four have been witnessed, the draw selects an unseen combination. The draw stays stable for the entire playthrough, and reload never rerolls it. A combination becomes seen only when the audience actually witnesses a counted Priscilla–Lavinia event or their ending under that combination. A hidden draw alone does not count. The Day 2 umbrella history never counts.

## Unowned Past Fragments

Past fragments never label whose memory or chronology they represent. A relevant physical trigger creates eligibility. At most one fragment may appear in a playthrough, and a playthrough may contain none. Among eligible fragments, unseen material is preferred.

The pool contains five fragments:

1. **The Project Folder:** The Angela–Priscilla childhood evidence incident.
2. **Before the Introduction:** Priscilla recognizes Lavinia at the bar first.
3. **Someone Else’s Kitchen:** Domestic fluency in a private kitchen without naming its residents or asserting cohabitation; the exact history remains subject to the residence migration.
4. **The Revised Form:** The lower-limb disclosure conflict without a diagnosis.
5. **Four Months Away:** An emotionally deniable Angela–Lavinia exchange during England.

Fragments provide evidence and characterization only. They never gate or assign relationship state, tone, or ending eligibility. They remain in normal history where the existing implementation supports them. There is no separate memory gallery.

## Ending Architecture

**FORWARD-PLOT STATUS:** The composition and evaluation laws in this section
remain the current mechanical/narrative boundary unless a later approved plot
reopens them. The named destinations and exact action summaries below are
inherited audition material, not approved forward plot canon, until each ending
family receives its complete audit and explicit approval. Their presence
preserves a testable scaffold; it does not settle the final carrier, dialogue,
romantic configuration, or consequence.

The internal catalogue contains thirteen authored ending identities. This is a catalogue count, not thirteen mutually exclusive terminal paths: Observer identities are postscripts, while Sylvia Special is a prelude to a forced Sylvia Totally Dark ending.

Day 7 first presents any due Day 6 follow-ups, then drains the unavoidable echo fallback before any boardless ending invitation round or faint-capable action becomes available. Before the Priscilla and Lavinia rounds generate their invitations, the active continuation's Day 2 and Day 6 R3-activation receipts are evaluated. Two successful activations suppress both individual invitations before generation; pair count and Angela knowledge remain separate. Eligible invitations then unlock in fixed rounds—Priscilla, Lavinia, Sylvia—subject to that filter and the ordinary tier gates; Sylvia remains independent of it. Ineligible invitations are absent. Reading an eligible invitation makes that destination available; Done commits at most one selected solo destination, or Alone when none is selected. Day 7 creates no dating board.

For a normally selected solo destination, stored dark 0 or 1 selects Sweet and stored dark 2 through 4 selects Totally Dark. The ordered ending plan is frozen before playback. Subject to the pre-Done faint precedence below, it resolves in this order:

1. one selected solo destination or Alone;
2. a qualifying solo Observer postscript after its matching Sweet ending;
3. a qualifying Priscilla–Lavinia visible ending after the solo layer;
4. the Priscilla–Lavinia Observer postscript after its matching Sweet ending when independently eligible.

A solo Observer is evidence-qualified aftermath, never a selectable destination. A Priscilla or Lavinia solo Observer and a counted P–L ending cannot coexist in one run because their attendance evidence is mechanically incompatible: solo Perfect mastery occupies a Day 2 or Day 6 window whose corresponding P–L encounter would have to count.

A qualifying Priscilla–Lavinia ending may follow an Angela–Priscilla or Angela–Lavinia Totally Dark solo ending. This does not revoke the Angela pairing's already authored attachment or create a triad. It confirms that even a catastrophic Angela-facing consequence did not displace Priscilla and Lavinia's older, mutually structuring bond.

Sylvia Special uses an abnormal two-step plan. Its sole trigger is a qualifying pre-Done faint after Sylvia’s eligible invitation has already been read; it plays first and then forces Sylvia Totally Dark, regardless of her stored dark count. If Dark mode is enabled, however, Dark-mode Alone has faint precedence over Sylvia Special. Otherwise a qualifying faint without a previously read eligible Sylvia invitation resolves through Hospital-flavored normal Alone. A Day 7 faint creates no missed-date record and zero Day 8 follow-up.

### Angela–Priscilla — Attend the Closing Reception

1. **Sweet:** Priscilla begins to answer for Angela, stops, and supports Angela’s imperfect wording. Their bond is intimate; the action may make romantic desire legible or leave its final category unsettled, but Sweet does not decide it.
2. **Totally Dark:** Priscilla answers increasingly personal questions; Angela knowingly confirms and adopts Priscilla’s phrasing. Their accumulated authorship and dependency become intimate and possessive: Priscilla needs Angela's self-description to pass through her, and Angela knowingly permits the attachment's dangerous method. Any romantic meaning must be earned by their conduct rather than switched on by Dark.
3. **Observer:** Capture/Compare verifies two incompatible lines. Angela can recite both; Priscilla asks which she believes. Verification proves contradiction, not cause.

### Angela–Lavinia — Wait by the Stage Door

4. **Sweet:** Angela refuses a jealousy test, states why she came, and Lavinia directly asks Angela to stay or leave with her. Their bond is intimate; the action may make romantic desire legible or leave its final category unsettled, but Sweet does not decide it.
5. **Totally Dark:** Lavinia creates a physical crisis to provoke restraint; Angela knowingly rewards the test with the demanded intensity. Their accumulated provocation and response become intimate and possessive: Lavinia can no longer treat Angela's intensity as merely useful evidence, and Angela knowingly permits the attachment's dangerous method. Any romantic meaning must be earned by their conduct rather than switched on by Dark.
6. **Observer:** The audience restrains the false cursor and prevents an environmental excuse from returning Angela. Lavinia must call and ask in her own words.

### Angela–Sylvia — Collect What Was Found

7. **Sweet:** Sylvia returns every object and permits Angela to choose one bounded form of help.
8. **Totally Dark:** Angela knowingly returns the prepared bag and permits Sylvia to manage her routine and messages.
9. **Special:** A qualifying pre-Done faint after Sylvia’s eligible invitation has been read begins this prelude. It is followed by the forced-form Sylvia Totally Dark scene; it is not selected as a destination and does not require a prior Sylvia ending.

**FIXED FACT — Sylvia’s intent:** Sylvia intends that Angela lose consciousness and prepares to control what follows.

**UNRESOLVED CAUSE — means and immediate physical cause:** The means, immediate physical cause, and degree of Observer Pressure remain unproved and unauthored. Reordered present-tense flashes show Sylvia’s badge turned down, Angela withdrawing from unnecessary touch, the prefilled slip, an interrupted objection, and the treatment-room ceiling. The sequence settles directly into Angela waking and the next authored visible action or spoken line. It contains no phone emphasis, Contacts draft, missing-message cue, replacement text, or unknown typist.

### Priscilla–Lavinia — Counter-Ending After Two Counted Encounters

The exact vehicle, access, key, and residence actions in the three inherited
summaries below are audition material only. They cannot become forward facts
until the required raw-conversation residence/bar/residue audit retains or
replaces them.

**Destination/trigger:** This is not an Angela-selected Day 7 destination. Both counted encounters must complete, whether witnessed in group or private versions. Offered but prevented windows do not count; the umbrella history does not count.

10. **Sweet:** Priscilla admits arranging the car; Lavinia admits needing it and directly asks Priscilla to come.
11. **Totally Dark:** Lavinia admits prolonging distress to provoke intervention; Priscilla reveals prearranged control. Both treat manipulation as proof of irreplaceability.
12. **Observer:** After all four state/tone combinations have actually been witnessed, Priscilla returns a familiar key that Lavinia says was already returned. An identical key is visible. Lavinia gives one back; neither decides which is real.

### Alone — Complete the Final Observation

13. **Alone:** Angela deliberately chooses no Day 7 date and completes her work. The ending is neither a punishment nor a failed route. A qualified Priscilla–Lavinia ending may still follow, confirming that other lives continue beyond Angela.

## Ending Gallery Behavior

Sweet, Totally Dark, Observer, and Special are internal production categories. Audience-facing entries receive evocative titles only after discovery. Unseen entries are completely invisible: no silhouette, question mark, lock, or completion percentage.

Observer and Special are exceptional identities with one full-once policy. The first profile discovery of each exceptional identity always plays in full. After any such discovery, the hidden setting `Replay discovered exceptional scenes in full` becomes available and defaults Off. On a later qualification, Off uses a short residue under the same semantic identity, while On uses the full entry; a newly discovered exceptional identity remains full regardless of the setting. The setting value and any selected residue variant are frozen into the ordered ending plan so reload cannot change or reroll them. Gallery replay of a discovered exceptional identity is always full.

## Observer Languages

Observer behavior can accrue from the first playthrough, but not every Observer ending can be completed on the first playthrough. Each pairing has a separate grammar.

Only Verification and Restraint may receive diegetic discovery hints from Angela, because only those Observer languages directly involve her. These hints may occur inside the relevant Angela–Priscilla or Angela–Lavinia dating scene only. They must sound like natural audible self-talk: independent replication, competing measurements, or reproducibility may hint at Verification; response inhibition, restraint, or the ethics of intervening may hint at Restraint. Angela never names `CAPTURE`, `COMPARE`, the cursor, the audience, or Observer Pressure, and every hint must remain plausible even when the hidden behavior is not discovered. Persistence receives no Angela tutorial or equivalent hint hierarchy.

### Verification — Angela–Priscilla

- `CAPTURE` appears only while hovering a designated history line.
- A fresh playthrough’s counterpart creates an unnatural blank.
- `COMPARE` overlays stored and current text.
- Reloading the same scene does not satisfy fresh-run verification.
- The result proves that the lines conflict; it does not identify who or what caused the conflict.

### Restraint — Angela–Lavinia

- Lavinia’s words and body disagree.
- A silent in-game false cursor drifts toward a physically plausible intervention.
- The audience has enough time to resist; this is not a reflex test.
- Successful restraint leaves the decision to Lavinia.
- Lavinia never knows about the cursor or Observer Pressure.

### Persistence — Priscilla–Lavinia

- The behavior accrues from the first playthrough without a tutorial hierarchy.
- The unseen-first state draw makes multiple playthroughs necessary in practice.
- All four state/tone combinations must be actually witnessed before the Observer postscript qualifies.

Sylvia Special is not an Observer language or Observer route. It is a prelude triggered only by a qualifying pre-Done faint after Sylvia’s eligible invitation has been read, and it is followed by forced-form Sylvia Totally Dark.

## Anti-Optimization

Reload does not calculate a subjective “worst outcome.” It resists optimization by changing evidence and legibility while preserving the outcome spine. Authored forms are limited to:

1. untouched evidence;
2. altered or removed evidence;
3. causal residue after the evidence disappears.

A character may remember an erased detail while another denies or misremembers it. These changes do not multiply complete scene branches, reroll the stable pair deck, or answer an unresolved cause.

## Incidental Cast Economy

No individuated speaking extra exists merely to carry exposition, logistics, causality, or interpretation. Routine institutional labor may remain ambient or become known through records, objects, queues, rooms, schedules, messages, and changed circumstances.

This economy rule does not deny that a university contains other people. Already established parents, the childhood culprit, the bar pursuer, visitors, and physically necessary qualified help remain bounded to their existing or physically required roles. None receives a new subplot, name, or interpretive authority by convenience.

## Character Agency and Author Greed

Before a premise or beat may survive, its author must answer:

1. Would this character initiate or continue the action without the author’s need for a clue, symbol, romance beat, or shock?
2. Could she physically know every fact she uses?
3. Is she using her own established control signature rather than borrowing another woman’s method?
4. What may she refuse, redirect, accept partially, ignore, or leave?
5. What consequence makes continued non-action costly?
6. Does each woman retain a task and motive not organized around Angela?
7. Is a beautiful idea making the character perform for the author?

A dossier constrains a performance but does not exhaust a person or reduce every act to one wound. A failed gate requires mutation or rejection; elegance cannot excuse character betrayal.

## Interpretive, Mechanical, and Physical Restraint

Material facts remain exact while their emotional or global causal meaning may stay unsettled. Show behavior and consequence before explanation. Keep sweetness genuinely attractive and danger genuinely nearby. Prefer normalized procedure to cinematic threat signals. Avoid graphic brutality used only to raise intensity, sentimental reconciliation, ornate symbolic decoding, coy feyness, melodramatic declarations, dialogue written as a solution key, and causality-free randomness.

Craft references are diagnostics, not recipes or styles the characters must imitate. Mechanics are neither explained nor praised by characters. State, tone, progression windows, Observer rules, and other mechanics organize availability and consequence without settling desire or interpretation.

A plot-bearing medical, astronomical, geographic, technological, scheduling, or institutional claim must be verified before premise approval. Until verified, it remains a candidate or fallible character inference rather than private world fact. Failed verification reopens or revises the premise. Knowledge required for a character-faithful action needs an established lawful channel and explicit approval; it cannot be smuggled into dialogue.

## Dialogue-Led Perceptual Writing Contract

Dialogue remains the dramatic engine. Visible action, diegetic text, objects, and sound remain primary evidence. Sparse perceptual prose may register an exact object, bodily sensation, position, line of sight, repetition, replacement, omission, or immediate judgment when that fact becomes salient to one eligible consciousness.

Anchor binding is epistemic, not grammatical. Before drafting a continuous passage, the private writer-facing scene record declares one eligible anchor; the released text need not name her, and withheld audience attribution never makes the production anchor unknown. Once a passage declares or inherits that anchor, prose need not repeatedly attribute perception with `Angela saw`, `Lavinia noticed`, or an equivalent tag. Objective-seeming surface sentences remain bound to that consciousness and may state only what she can consciously and physically perceive. An unqualified absence statement is lawful only when the anchor can consciously and physically perceive the full scope it claims; it proves only that the stated carrier is absent from that perceptual field, not that an unseen, emotional, causal, or interpretive connection is absent. In writer-facing shorthand: **anchor-bound does not mean anchor-tagged**.

The operational craft tests and the bounded Day 6 Group authorization for
unmarked focal presence are maintained in the
[Narrative Style Manual](08-narrative-style-manual.md#42-unmarked-focal-presence).
They may conceal audience-facing attribution but may not loosen this Bible's
anchor eligibility, physical-access, or passage-stability laws.

An eligible anchor may speak whenever her own task, pressure, or temperament earns speech; perceptual restraint does not require muteness. Her dialogue may supply a bounded fact, question, correction, refusal, or characterful observation. It may not be inserted merely to translate deliberately unclaimed meaning. **Silence is optional; unexplained meaning is essential.**

The game has no narrator identity, omniscient or explanatory narration, unrestricted private-thought transcription, invisible stage directions, or prose that grants hidden knowledge. Perceptual prose may be subjective without announcing itself as an interior-monologue box. An immediate judgment is not permission to transcribe unrestricted private thought, and the prose may withhold the reason an observation matters. It may not diagnose emotion, state another person’s motive, reveal a fact the declared anchor did not perceive, explain symbolism, identify an unresolved cause, dictate interpretation, or head-hop.

Every authorized audience-visible surface uses these exact anchor rules:

- An Angela-attended solo or group scene, Angela-owned ending or postscript, or Hospital passage may use Angela-bound prose only while Angela is conscious and can physically perceive the stated fact.
- An authorized audience-visible Priscilla–Lavinia surface—including a private counterpart, pair ending, or postscript—may declare Priscilla or Lavinia as its anchor. Group presentation with Angela present defaults to Angela. The offscreen umbrella history creates no passage and therefore no anchor.
- An unowned past fragment has no character-bound prose because assigning an anchor would assign memory ownership. It retains dialogue, action, objects, sound, and other already authorized external presentation.
- Gallery and Rehearsal replay inherit the source passage’s anchor and cannot add one. No UI or archive surface becomes a new consciousness.
- When no eligible character is conscious and perceiving, there is no character-bound perceptual prose. This includes an Angela-owned passage while Angela is unresponsive unless another viewpoint has been separately approved.
- Separately presented visual or audio evidence may exceed what the anchor notices only through its already authorized external channel. It cannot be restated as perceptual prose or become character knowledge.
- The active anchor remains stable through a continuous passage. Unmarked head-hopping is forbidden.
- A private-offscreen event supplies no prose, scene, board, or private knowledge merely because a private-visible counterpart exists elsewhere.
- No perceptual anchor creates a new audience-visible surface or makes another character playable.

Missing, unseen, or unreceived evidence proves only the absence of that carrier for the relevant audience or character unless an authorized system separately records more. It does not prove that an event did or did not occur, identify authorship, or settle an unresolved cause.

Not every visual or audio fact receives prose; some evidence may remain subtle or missable. The base prose is not required to restate every visual fact for TTS. Any later optional description or accessibility layer requires its own design and may not force the base prose to explain the mystery.

Production descriptions remain private staging instructions unless explicitly authored and separately approved as audience-visible perceptual prose. Reaction tests and complete scenes do not become final DTL by proximity.

## Visual Direction

- Use layered 2D backgrounds and sprites.
- Use object and hand overlays for narratively important actions.
- Keep pose changes restrained and reserve a small number of brief CG fragments for high-value evidence or bodily moments.
- Rare first-person perspective seizures are short and non-interactive. They do not make another character playable.
- Visuals show consequences, distance, objects, and consent-relevant movement without explanatory captions.
- Dreamlike abnormality remains normalized rather than announced through spectacle.

## Sound Direction

Sound supplies evidence rather than explaining emotion.

- **Angela:** equipment hums, motors, restrained keys, and controls.
- **Priscilla:** precise paper, ceramic, clasps, footsteps, and controlled doors.
- **Lavinia:** breath, fabric tension, floor contact, rehearsal resonance, and meaningful stillness.
- **Sylvia:** badge clip, kit zipper, packaging, kettle, and chair placement before need is understood.

Observer Pressure has no supernatural theme. Ordinary sounds may occur in the wrong order. Music is sparse, and no horror sting announces the correct interpretation. Every important audio fact has a visual equivalent.

## Language, Subtitle, History, and TTS Rules

The characters’ language use follows their established backgrounds: Cantonese carries local everyday intimacy for Angela and Priscilla; English is a credible academic and shared language; Putonghua is situational rather than an automatic private language; Romanian belongs to Lavinia’s private and familial life. Developing Cantonese never makes Lavinia comic or incompetentence. Authentic colloquial Cantonese uses Traditional Chinese characters and appropriate particles when shown as the native original.

The two subtitle modes preserve these meanings:

**Single display language**

- An ordinary line appears in the selected display language.
- A diegetic native-language line shows the native original first and the selected translation second.

**Dual display languages**

- The primary display language appears first.
- The secondary display language appears second.
- For a diegetic native-language line, the native original is omitted from the dialogue box and retained in history.

No language tag restores information the audience chose not to display. There is no recorded character voice acting. The intended TTS contract is: live dialogue reads the first display language; history replay of a native-language line reads the original and then the first display translation. Runtime drift must be recorded for reconciliation rather than treated as narrative canon.

## Content Boundaries

Allowed in non-graphic form: coercive dialogue, stalking, privacy invasion, unwanted kissing, controlling touch, non-graphic biting, small blood, crime, severe danger, and aftermath implying irreversible harm.

Never depict torture, gore spectacle, explicit sexual assault, a reproducible fainting method, sexual contact while unconscious, or a false claim that intimate contact is medically required for fainting. Do not name a substance, dose, pressure technique, breathing maneuver, deprivation schedule, or physiological trick that could make Sylvia’s intent actionable.

While Angela is conscious and responsive, Sylvia may rationalize an intimate or sexual action as a practical check, protective adjustment, medical precaution, or moral duty so that she need not name it as desire. The work must not validate that framing, and those labels never create consent. A conscious and responsive adult retains the right to understand and refuse touch. While Angela is unresponsive, only genuine emergency care within first-aid scope is defensible; there is no sexualized or intimate contact. Sylvia’s badge, volunteer role, and first-aid certificate confer no diagnostic or private medical authority.

No ending confirms death. Severe injury, disappearance, or death may remain an interpretation supported by non-graphic evidence. There is no triad route in approved canon, no visible statistics requirement, and no newly invented Observer mechanic.

There is no in-game content-warning system. Accurate storefront classification and legally or platform-required disclosures belong to release metadata, not narrative UI.

## Public/Private Spoiler Boundary

The public profile may state that characters continue making private choices and forming relationships outside Angela’s presence, that the interface remembers how the audience observes, hesitates, revisits, and persists, and that Sylvia's timing is difficult to explain. Public copy presents the work as psychological horror and relationship mystery. It may imply charged intimacy through concrete behavior, but it must not classify the game as romance or a dating simulator, describe any character as romanceable, or promise romantic reciprocity. Suggestive wording may support audience inference; it may not state a false feature guarantee.

The public profile must not reveal:

- Priscilla and Lavinia’s private residence/access history or identify them as the autonomous hidden pairing;
- relationship-state logic, the four-state deck, or ending gates;
- Capture/Compare, false-cursor restraint, persistence requirements, anti-reload behavior, or other Observer instructions;
- Sylvia’s intended loss-of-consciousness outcome or Special eligibility;
- the internal ending count;
- Observer Pressure’s internal “Love God” nickname;
- the exact romantic configuration or reciprocity of any ending or relationship;
- any claim that a named character is romanceable, that romantic reciprocity is guaranteed, or that a relationship is canonically romantic or exclusive.

Public character descriptions may carry one unsettling trait each without revealing a crime, causal answer, or hidden history. Creative references remain internal unless a later creator statement deliberately names them.

## Canon Maintenance Rules

1. Resolve conflicts by the authority order in this file; do not silently merge incompatible versions.
2. Treat the August design as baseline intended mechanical law subject to later explicit approvals and recorded supersessions. Inspect the runtime to record what physically exists and identify drift as a reconciliation finding; neither current runtime behavior nor the Production Map may silently amend the approved design or narrative canon.
3. Use the four canon categories only when ambiguity matters and never use a label to disguise indecision.
4. Preserve Friend starts, at-most-one-tier movement at each later approved progression window, and ambiguous/love ending eligibility unless the approved plot reopens them. Keep progression code-owned; do not restore the legacy third/fourth schedule or invent replacement windows before plot approval. Derive Sweet or Totally Dark ending form from the approved ending-form law and freeze it into the ordered ending plan. Preserve asymmetric but romantically open Angela pairings, Priscilla–Lavinia's dominant gravity, and the unchanged non-romantic sibling and Lavinia–Sylvia boundaries. Never describe a state, statistic, audience input, board result, Observer force, or tone category as manufacturing or forbidding desire.
5. Promote a premise only through owner approval recorded as an `APPROVED` Causal Matrix row. Library retention, Map wording, Beatbook detail, or executable presence is not approval.
6. For ordinary audition survivors, expand in the Beatbook only the approved causal facts of an `APPROVED` Causal Matrix row. The already approved, placement-unselected Room 2.17 causal core is the sole bounded current exception, preserving only its existing approved causal and execution boundary; its exact Day 2 versus Day 6 placement and any unapproved adaptations must return through audition and explicit approval. Writer-facing reaction tests do not become shipped dialogue or broader canon by proximity.
7. Reopen an approved premise when later work exposes a mechanical, character, causal, coexistence, or verified physical-world conflict. Preserve the superseded version, its former status, source, date, and reason in the noncanonical library; provenance-safe reopening never silently rewrites history.
8. Never let a fragment set state, tone, or ending eligibility.
9. Keep the three Observer languages separate and keep Sylvia Special distinct from them.
10. Preserve every unresolved cause: contradiction may be proved, but mechanism and author remain unconfirmed where specified.
11. Maintain the ordered ending plan, including Sylvia Special before forced Sylvia Totally Dark, the solo/Pair evidence incompatibility, and the actual two-encounter Priscilla–Lavinia trigger.
12. Apply physical-world corrections without rewriting approved fictional relationships, later-approved mystery anchors, or the umbrella history.
13. Audit safety language for accidental diagnosis, medical authority, actionable harm, unconscious sexual contact, and confirmed death.
14. Audit public material against the private boundary before release.
15. Do not add a triad route, public ending count, in-game warning system, visible statistics, full scene scripts, surnames, or a new Observer mechanic without a later explicit canon approval.
