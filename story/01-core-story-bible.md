# Core Story Bible

## Document Authority

This is the private, spoiler-complete narrative authority for DWM. It records what is true, what may vary, and what must remain unresolved. The Character & Relationship Handbook and Seven-Day Production Map are derived working views; the Public Project Profile is a spoiler-safe projection. If any derived document conflicts with this file, this file wins unless the disputed detail belongs to existing code.

Authority follows this order:

1. Later explicit approvals supersede earlier proposals and the original brief.
2. Existing code owns exact daily availability, UI appearance, replay and skip behavior, health counters, line identity, localization implementation, and save/load implementation.
3. This file owns narrative canon and intended audience-facing meaning.
4. Derived project documents may restate but may not revise this canon.
5. The original brief controls only decisions not superseded by later approval.
6. Research may correct physical-world terminology and plausibility, but it may not change approved fictional canon.

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
- **Length target:** Approximately two hours for a first clear and approximately five hours for full completion
- **Internal engine context:** Godot with Dialogic 2, mentioned only when useful to production

All four principal characters are adults.

**Public logline:**

> During a seven-day university open week in Hong Kong, astrophysics student Angela arranges meetings with three women whose private histories continue without her. As schedules, messages, and memories disagree, choosing where to be cannot determine what anyone wants.

## Experience Contract

Angela is the only affectable character, but she is not the centre of every relationship. The audience can shape her available expression and intended action, but cannot author her personality, anyone else’s desire, or consent. Choices have genuine local consequences while other people continue acting outside Angela’s attention.

Use **audience** for narrative analysis. Use **player** only for technical input, accessibility, or platform language.

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

- Angela supports astronomy demonstrations and late observation.
- Priscilla handles programme language, communications, and student organization.
- Lavinia rehearses and performs through the conservatory.
- Sylvia supports welfare, safety, scheduling, and visitor logistics within her limited volunteer role.

Dates and meetings occupy practical windows around these responsibilities. Their exact availability and slot ownership remain code-authoritative.

## Seven-Day Fixed Spine

- Priscilla is present from Day 1.
- Lavinia returns to Hong Kong on Day 2.
- On Days 1–6, Angela may attend up to two dates or scheduled actions with two different code-available women. Documentation does not assign the exact day or slot of the fourteen event premises.
- Day 7 contains one decisive schedule choice during the public culmination.
- A personal ending action appears only when the relevant relationship is at ambiguous or love. Ineligible actions do not appear as locks, silhouettes, or disabled alternatives.
- If Angela attends no Day 7 date and completes her final observation, she receives the Alone Ending. This is a deliberate choice, not a failed route.

Four evidence anchors are fixed to the calendar:

### Day 1 — Institutional Uncertainty

Lavinia’s name appears prematurely on an Open Week roster. It may reflect an old template, an ordinary clerical choice, a human alteration, or anticipation of her return. The selected event determines which facet Angela can examine.

### Day 2 — Priscilla’s Concealed Knowledge

Angela types but does not send `Lavinia is back`. Priscilla replies `I know` before the message is sent. The hidden shared apartment explains why Priscilla knows Lavinia is back; it does not explain the reply’s timing.

### Day 4 — Sylvia’s Preparation

A welfare incident slip already contains Lavinia’s name, the correct location, and the kind of help soon required. Sylvia calls it preparation. Different dates may reveal its timestamp, possible alteration, mismatch with Lavinia’s account, or only its passing presence.

### Day 6 — Audience Implication

An ordinary Open Week location check-in prompt appears on Angela’s phone. Confirming it creates one record; allowing it to expire creates another notice. Either response begins a plausible physical intervention whose moral effect varies with context. The false cursor belongs exclusively to Angela–Lavinia Observer language and is not a general explanation for this prompt.

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

## Mystery Fairness and Abnormality Budget

The evidence mystery is a three-source braid:

1. human interference;
2. mundane error or coincidence;
3. unresolved Observer Pressure.

It is locally fair and globally insoluble. Every incident has at least one plausible ordinary explanation; no single explanation accounts for the complete pattern. The hidden apartment can explain knowledge without explaining impossible timing. Sylvia’s preparation can explain readiness without proving the means or cause of later harm.

Normalized abnormality follows a strict budget:

- **Ordinary scene:** zero or one peripheral abnormality.
- **Relationship spotlight:** at most one relational intrusion.
- **Observer or pressure scene:** a brief intensification is permitted.

Do not stack arbitrary anomalies to manufacture surrealism. The atmosphere comes from consistent characters meeting evidence whose combined pattern will not settle.

## Character Canon Essentials

### Angela

Angela is 20, Hong Kong-born, and a second-year astrophysics student. Cantonese is her everyday language, academic English is fluent, and Putonghua is situational. Her emotional minimalism is temperament, not trauma shorthand. She uses absurd deductions, performance, and occasional physics or game language when those metaphors are genuinely precise. She willingly delegates choices but requires reality to remain independently inspectable. Her greatest danger is using uncertainty as moral shelter while enjoying another person’s controlling care.

### Priscilla

Priscilla is 20, Hong Kong-born, and an English literature student with institutional credibility. She speaks polished Cantonese and English, selecting public language for control of nuance. Care appears as management, correction, anticipation, and selective truth. She overreads language and patterns but is not a mind reader. Her love is genuine; its coexistence with acquisition and control makes it frightening.

### Lavinia

Lavinia is 22, Romanian, from a wealthy Bucharest family, and a conservatory ballet student. She is fluent in English, uses Romanian in private, and is developing Cantonese without comic incompetence. She treats powerful reaction as evidence of importance and may provoke attention rather than ask directly. Her professional discipline coexists with physical and emotional boldness. Her persistent load-related lower-limb pain is symptom-based canon; no exact diagnosis is fixed.

### Sylvia

Sylvia is 21 and a third-year statistics or decision-science student. She is an Open Week peer-welfare and safety volunteer with a current basic first-aid certificate. She may know public schedules, assigned rooms, check-in procedures, and incident workflow. She has no diagnostic authority, private-record access, or legitimate right to conduct a general physical examination. Unable to risk asking to be wanted, she arranges to be owed and translates desire into practical, medical, or moral necessity.

## Fixed Hidden Histories

These facts are private canon. The released game reveals them only through partial evidence, behavior, or approved fragments and endings.

### Angela–Priscilla Childhood Incident

At age twelve or thirteen, Angela was wrongly blamed for alteration or deletion of a group science project. Priscilla possessed suggestive but inconclusive evidence, fabricated one recovery record, and correctly identified the culprit. Angela believed the exonerating evidence was authentic. Priscilla then arranged the culprit’s private humiliation through truthful information, without charge or appeal. Her conclusion was right; her procedure was wrong. The incident taught Angela that Priscilla could make disputed reality legible and taught Priscilla that a true conclusion could justify control of the record.

### Priscilla–Lavinia First Recognition

At a bar gathering, Priscilla recognizes Lavinia before their formal introduction. Lavinia has already made a subtle refusal to a persistent pursuer, who continues anyway. Priscilla is also irritated by the disturbance and uses precise sarcasm to embarrass the pursuer into leaving. Lavinia is grateful. This recognition is fixed; the reason Priscilla knew Lavinia first is not separately established.

### Priscilla–Lavinia Shared Apartment

Lavinia’s family provides a private two-bedroom flat near campus. Priscilla obtained family permission to live there by presenting Lavinia as a respectable roommate and family connection. The arrangement became irregular cohabitation before England, with one bedroom each. Lavinia retained a key and did not expose Priscilla’s family deception after their fight. Priscilla kept Lavinia’s room prepared while maintaining the appearance that they still lived together. The game never directly confirms the apartment arrangement, and neither woman treats possession of the key as an agreed relationship label.

### Lavinia’s Company Attachment and Lower-Limb Conflict

Lavinia spent approximately four months in England on a **sponsored company attachment** arranged through the conservatory. She trained with the company, rehearsed selected repertoire, and was considered for future professional work.

Before departure, Lavinia authorized Priscilla to polish and submit institutional language, not to change its substance. Priscilla changed a minimized description into a factually defensible but maximally consequential account of persistent load-related lower-limb pain and its functional effect, then submitted it without Lavinia’s review. The revision prompted assessment and temporary modified participation, including reduced high-load material or adjusted rehearsal volume. Lavinia was later cleared to continue under an agreed plan; this did not prove her pain-free or uninjured. The exact site, cause, and diagnosis remain unfixed. Priscilla’s protective concern was legitimate; her expansion of limited permission and secured outcome were not.

### Sylvia’s Asymmetrical Familiarity

Angela recognizes Sylvia’s name, volunteer role, and status as an occasional acquaintance. Sylvia has studied Angela far more closely than this relationship justifies. Schedule access and observation explain much, but not her exact timing or private knowledge. Any unauthorized use of check-in or incident information is a boundary violation, not a privilege of peer welfare. Sylvia has no past-fragment deck and no Observer Ending.

## Relationship State and Tone

Relationship state progresses in one direction:

`hate → friend → ambiguous → love`

- A relationship-leveling event advances only one tier.
- No intimate leveling opportunity occurs from hate. A non-intimate qualifying event may advance hate to friend.
- Friend receives a restrained version of an intimate leveling opportunity and may advance to ambiguous.
- Ambiguous receives a fuller mutual version and may advance to love.
- Love receives a deeper variation without another tier.
- A fragment never advances state.

Personal Day 7 endings are eligible only at ambiguous or love. An ineligible action is absent rather than visibly locked.

The existing code-owned tone state selects **Sweet** or **Dark** and remains stable for the relevant outcome. A fragment does not create or change tone.

- **Sweet:** One destructive pattern is interrupted and one concrete boundary is honored. Nobody is cured and no relationship is labeled.
- **Totally Dark:** Both participants knowingly reinforce a dangerous pattern because it satisfies something genuine. Harm remains real; attachment does not make it harmless.

State controls what mutuality is available; tone controls the visible ending variation. Neither authorizes another person’s desire or consent.

## Event Architecture

There are fourteen event premises: four Angela–Priscilla dates, four Angela–Lavinia dates, four Angela–Sylvia dates, and two counted Priscilla–Lavinia encounters. Exact schedule availability remains code-owned.

Every production card derives from the same compact model:

`fixed spine + short relationship insert + one tone action + contextual echo`

Each card identifies the ordinary activity and setting, characters present and absence version, fixed dialogue/action spine, relationship pressure, state insert, tone action, and mystery clue, fragment eligibility, and later echo. Do not write complete branch-permutation scripts.

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

### Day 2 Non-Counting Micro-Scene — The Umbrella Pickup

When Angela is occupied elsewhere during the relevant arrival window, the audience directly sees a short cutaway. Still estranged after the disclosure-form fight, Lavinia asks Priscilla to bring the long umbrella to arrivals despite being indoors. Priscilla comes, takes the heavier bag without permission, and receives the umbrella request as an indirect demand for presence. If the cutaway is not shown, later object and dialogue residue confirms that the pickup occurred. It never increments the pair counter or marks a pair state/tone combination seen.

## Priscilla–Lavinia Four-State Deck

Priscilla and Lavinia’s fixed shared history means they begin every playthrough at ambiguous or love. Each new playthrough draws one complete state/tone combination:

1. ambiguous + sweet;
2. ambiguous + dark;
3. love + sweet;
4. love + dark.

Until all four have been witnessed, the draw selects an unseen combination. The draw stays stable for the entire playthrough, and reload never rerolls it. A combination becomes seen only when the audience actually witnesses a counted Priscilla–Lavinia event or their ending under that combination. A hidden draw alone does not count. The Day 2 umbrella pickup never counts.

## Unowned Past Fragments

Past fragments never label whose memory or chronology they represent. A relevant physical trigger creates eligibility. At most one fragment may appear in a playthrough, and a playthrough may contain none. Among eligible fragments, unseen material is preferred.

The pool contains five fragments:

1. **The Project Folder:** The Angela–Priscilla childhood evidence incident.
2. **Before the Introduction:** Priscilla recognizes Lavinia at the bar first.
3. **Someone Else’s Kitchen:** Ordinary cohabitation without naming the apartment or its residents.
4. **The Revised Form:** The lower-limb disclosure conflict without a diagnosis.
5. **Four Months Away:** An emotionally deniable Angela–Lavinia exchange during England.

Fragments provide evidence and characterization only. They never gate or assign relationship state, tone, or ending eligibility. They remain in normal history where the existing implementation supports them. There is no separate memory gallery.

## Ending Architecture

The internal catalogue contains thirteen authored ending identities. This is a catalogue count, not thirteen mutually exclusive terminal paths: Observer and Special identities are postscripts following visible Sweet or Totally Dark scenes.

When multiple results qualify, use this exact four-layer order:

1. Angela’s visible relationship ending or the Alone Ending;
2. the Angela pairing’s Observer postscript or Sylvia’s Special postscript, if qualified;
3. the Priscilla–Lavinia visible counter-ending, if both counted encounters completed;
4. the Priscilla–Lavinia Observer postscript, if qualified.

### Angela–Priscilla — Attend the Closing Reception

1. **Sweet:** Priscilla begins to answer for Angela, stops, and supports Angela’s imperfect wording.
2. **Totally Dark:** Priscilla answers increasingly personal questions; Angela knowingly confirms and adopts Priscilla’s phrasing.
3. **Observer:** Capture/Compare verifies two incompatible lines. Angela can recite both; Priscilla asks which she believes. Verification proves contradiction, not cause.

### Angela–Lavinia — Wait by the Stage Door

4. **Sweet:** Angela refuses a jealousy test, states why she came, and Lavinia directly asks Angela to stay or leave with her.
5. **Totally Dark:** Lavinia creates a physical crisis to provoke restraint; Angela knowingly rewards the test with the demanded intensity.
6. **Observer:** The audience restrains the false cursor and prevents an environmental excuse from returning Angela. Lavinia must call and ask in her own words.

### Angela–Sylvia — Collect What Was Found

7. **Sweet:** Sylvia returns every object and permits Angela to choose one bounded form of help.
8. **Totally Dark:** Angela knowingly returns the prepared bag and permits Sylvia to manage her routine and messages.
9. **Special:** Angela must select an eligible Sylvia destination, complete its visible Sweet or Totally Dark ending, and meet the code-owned health-neglect condition. The postscript follows the visible scene; health neglect alone is insufficient.

**FIXED FACT — Sylvia’s intent:** Sylvia intends that Angela lose consciousness and prepares to control what follows.

**UNRESOLVED CAUSE — means and immediate physical cause:** The means, immediate physical cause, and degree of Observer Pressure remain unproved and unauthored. Reordered present-tense flashes show Sylvia’s badge turned down, Angela withdrawing from unnecessary touch, the prefilled slip, an interrupted objection, and the treatment-room ceiling. Angela wakes beside an unsent draft: `I’m with Sylvia. Don’t come.` Nothing proves who typed it.

### Priscilla–Lavinia — Counter-Ending After Two Counted Encounters

**Destination/trigger:** This is not an Angela-selected Day 7 destination. Both counted encounters must complete, whether witnessed in group or private versions. Offered but prevented windows do not count; the umbrella pickup does not count.

10. **Sweet:** Priscilla admits arranging the car; Lavinia admits needing it and directly asks Priscilla to come.
11. **Totally Dark:** Lavinia admits prolonging distress to provoke intervention; Priscilla reveals prearranged control. Both treat manipulation as proof of irreplaceability.
12. **Observer:** After all four state/tone combinations have actually been witnessed, Priscilla returns a familiar key that Lavinia says was already returned. An identical key is visible. Lavinia gives one back; neither decides which is real.

### Alone — Complete the Final Observation

13. **Alone:** Angela deliberately chooses no Day 7 date and completes her work. The ending is neither a punishment nor a failed route. A qualified Priscilla–Lavinia ending may still follow, confirming that other lives continue beyond Angela.

## Ending Gallery Behavior

Sweet, Totally Dark, Observer, and Special are internal production categories. Audience-facing entries receive evocative titles only after discovery. Unseen entries are completely invisible: no silhouette, question mark, lock, or completion percentage.

Each full Observer or Special postscript plays once per global profile. Later matching endings restore the normal conclusion with small randomized residue. The full postscript remains replayable through history. Gallery and replay presentation beyond these audience-visible requirements remains code-owned.

## Observer Languages

Observer behavior can accrue from the first playthrough, but not every Observer ending can be completed on the first playthrough. Each pairing has a separate grammar.

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

Sylvia’s Special postscript is not an Observer language or Observer route. Its eligibility remains the selected Sylvia ending plus the code-owned health condition.

## Anti-Optimization

Reload does not calculate a subjective “worst outcome.” It resists optimization by changing evidence and legibility while preserving the outcome spine. Authored forms are limited to:

1. untouched evidence;
2. altered or removed evidence;
3. causal residue after the evidence disappears.

A character may remember an erased detail while another denies or misremembers it. These changes do not multiply complete scene branches, reroll the stable pair deck, or answer an unresolved cause.

## Dialogue-Only Writing Contract

The released game contains no narrator, thought boxes, invisible explanatory prose, or personalized narration. It may tell the story through:

- spoken dialogue;
- audible self-talk or muttering;
- messages, schedules, voice-note text, and institutional documents;
- visible actions, objects, and body language;
- interface behavior and diegetic sound.

Production descriptions in private documents are staging instructions, not in-game prose. Complete scenes are not part of project documentation. Short illustrative dialogue must be labeled `REACTION TEST` unless it is explicitly an approved ending synopsis line.

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

The characters’ language use follows their established backgrounds: Cantonese carries local everyday intimacy for Angela and Priscilla; English is a credible academic and shared language; Putonghua is situational rather than an automatic private language; Romanian belongs to Lavinia’s private and familial life. Developing Cantonese never makes Lavinia comic or incompetent. Authentic colloquial Cantonese uses Traditional Chinese characters and appropriate particles when shown as the native original.

The two subtitle modes preserve these meanings:

**Single display language**

- An ordinary line appears in the selected display language.
- A diegetic native-language line shows the native original first and the selected translation second.

**Dual display languages**

- The primary display language appears first.
- The secondary display language appears second.
- For a diegetic native-language line, the native original is omitted from the dialogue box and retained in history.

No language tag restores information the audience chose not to display. There is no recorded character voice acting. Existing TTS behavior remains code-authoritative: live dialogue reads the first display language; history replay of a native-language line reads the original and then the first display translation.

## Content Boundaries

Allowed in non-graphic form: coercive dialogue, stalking, privacy invasion, unwanted kissing, controlling touch, non-graphic biting, small blood, crime, severe danger, and aftermath implying irreversible harm.

Never depict torture, gore spectacle, explicit sexual assault, a reproducible fainting method, sexual contact while unconscious, or a false claim that intimate contact is medically required for fainting. Do not name a substance, dose, pressure technique, breathing maneuver, deprivation schedule, or physiological trick that could make Sylvia’s intent actionable.

Sylvia may rationalize an act as practical, protective, or medical, but the work must not validate that framing. A conscious and responsive adult retains the right to understand and refuse touch. While Angela is unresponsive, only genuine emergency care within first-aid scope is defensible; there is no sexualized or intimate contact. Sylvia’s badge, volunteer role, and first-aid certificate confer no diagnostic or private medical authority.

No ending confirms death. Severe injury, disappearance, or death may remain an interpretation supported by non-graphic evidence. There is no triad route in approved canon, no visible statistics requirement, and no newly invented Observer mechanic.

There is no in-game content-warning system. Accurate storefront classification and legally or platform-required disclosures belong to release metadata, not narrative UI.

## Public/Private Spoiler Boundary

The public profile may state that characters continue making private choices and forming relationships outside Angela’s presence, that the interface remembers how the audience observes, hesitates, revisits, and persists, and that Sylvia is a full romanceable character whose timing is difficult to explain.

The public profile must not reveal:

- Priscilla and Lavinia’s shared apartment or identify them as the autonomous hidden pairing;
- relationship-state logic, the four-state deck, or ending gates;
- Capture/Compare, false-cursor restraint, persistence requirements, anti-reload behavior, or other Observer instructions;
- Sylvia’s intended loss-of-consciousness outcome or Special eligibility;
- the internal ending count;
- Observer Pressure’s internal “Love God” nickname;
- any claim that a relationship is canonically romantic or exclusive.

Public character descriptions may carry one unsettling trait each without revealing a crime, causal answer, or hidden history. Creative references remain internal unless a later creator statement deliberately names them.

## Canon Maintenance Rules

1. Resolve conflicts by the authority order in this file; do not silently merge incompatible versions.
2. Keep code-owned details code-owned. Narrative documentation may state intended meaning but may not invent an implementation.
3. Use the four canon categories only when ambiguity matters and never use a label to disguise indecision.
4. Preserve one-tier relationship progression, ambiguous/love ending eligibility, and code-owned tone selection.
5. Never let a fragment set state, tone, or ending eligibility.
6. Keep the three Observer languages separate and keep Sylvia’s Special distinct from them.
7. Preserve every unresolved cause: contradiction may be proved, but mechanism and author remain unconfirmed where specified.
8. Maintain the exact four-layer ending order and the actual two-encounter Priscilla–Lavinia trigger.
9. Apply physical-world corrections without rewriting approved fictional relationships, mystery anchors, or the umbrella history.
10. Audit safety language for accidental diagnosis, medical authority, actionable harm, unconscious sexual contact, and confirmed death.
11. Audit public material against the private boundary before release.
12. Do not add a triad route, public ending count, in-game warning system, visible statistics, full scene scripts, surnames, or a new Observer mechanic without a later explicit canon approval.
