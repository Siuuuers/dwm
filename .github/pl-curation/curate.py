#!/usr/bin/env python3
"""Owner-requested selective curation at PR3@3b553e1; no Git/network writes."""
from pathlib import Path
import hashlib,json,re,posixpath,sys,shutil
BASE='3b553e1a3d986fa0de3be4a529f895cba4d9acca'
ARCHIVE='62fd8bf3966e4df7e03bf52952c6905284845284'
PAIR='story/relationships/priscilla-lavinia/'
AUD=PAIR+'auditions/'
MAINT='story/maintenance/'
REL=PAIR+'relationship.md';INT=PAIR+'intimacy-and-ordinary-company.md';WEEK=PAIR+'seven-day-options.md'
DEV=AUD+'day-2-portrait-development.md';POR=AUD+'day-2-sweet-love-portrait.md'
DANCE=AUD+'day-6-sweet-love-dance.md';REF=AUD+'day-6-sweet-ambiguous-refusal.md';DARK=AUD+'day-6-dark-notebook.md'
HEAR=AUD+'2026-09-07-priscilla-lavinia-day-6-sweet-love-interrupted-hearing-audition.md'
def sha(b):return hashlib.sha256(b).hexdigest()
def head(t):
    stops=[m.start() for m in re.finditer(r'^<a id="(?:legacy-portrait-checkpoint|exchange-)|^<details>|^## Development ',t,re.M)]
    return t[:min(stops)].rstrip()+'\n' if stops else t

def curate(root:Path):
    before={p.relative_to(root).as_posix():p.read_bytes() for p in root.rglob('*') if p.is_file() and '.git' not in p.parts}
    original=json.loads(before[MAINT+'source-migration.json'])
    assert original['schema_version']==4 and len(original['content_units'])==153
    units={u['id']:u for u in original['content_units']}; extracted={}; excerpts=[]
    for uid,u in units.items():
        t=before[u['destination']].decode()
        if 'existing_marker' in u:a='<!-- EXACT '+u['existing_marker']+' START -->';z='<!-- EXACT '+u['existing_marker']+' END -->'
        else:a='<!-- BEGIN SOURCE '+uid+' -->';z='<!-- END SOURCE '+uid+' -->'
        q=t.split(a,1)[1].split(z,1)[0].strip('\n'); f,body=q.split('\n',1);f=f.removesuffix('text');assert body.endswith('\n'+f)
        extracted[uid]=body[:-len('\n'+f)]
        assert sha(extracted[uid].encode())==u['rendered_sha256']
    def write(p,t):(root/p).write_text(t.rstrip()+'\n',encoding='utf-8')
    def src(uid):
        u=units[uid];return f'https://github.com/Siuuuers/dwm/blob/{u["source_ref"]}/{u["source_path"]}#L{u["a"]+1}-L{u["b"]}'
    def excerpt(uid,start,end,title,note,dest):
        t=extracted[uid];a=t.index(start) if start else 0;z=t.index(end,a) if end else len(t)
        text=t[a:z].strip('\n');u=units[uid];n=len(excerpts)+1;mark='curated-'+str(n).zfill(2)
        excerpts.append({'id':mark,'source_unit':uid,'source_url':src(uid),'source_unit_sha256':u['rendered_sha256'],'destination':dest,'sha256':sha(text.encode()),'selection_reason':note,'start_text':start,'end_text':end})
        return f'\n## {title}\n\n{note}\n\n[Source passage]({src(uid)}). **REACTION TEST / UNSELECTED**; retained for comparison, not a new event or approval.\n\n<details>\n<summary>Read the retained passage</summary>\n\n<!-- BEGIN CURATED {mark} -->\n{text}\n<!-- END CURATED {mark} -->\n\n</details>\n'
    def history_note(p,description):
        return f'\n## Sources and curation\n\n{description} Exact surrounding exchanges and former commentary remain in the [pre-curation record](https://github.com/Siuuuers/dwm/blob/{BASE}/{p}) and the [original-source map]({posixpath.relpath(MAINT+"our-pl-upload-recovery.md",posixpath.dirname(p))}). The working document keeps what helps a writing decision, not a complete transcript. Older missing-history and narrative-selection holds remain open.\n'
    # Preserve current scenes and their already focused explanation; discard repeated raw responses.
    for p in [DANCE,REF,DARK]:
        t=head(before[p].decode())
        t=re.sub(r'\n## Provenance and coverage\n.*','',t,flags=re.S) if p!=DARK else re.sub(r'\n## 8\. Scope, source, and later possibilities\n.*','',t,flags=re.S)
        write(p,t)
    # Preserve the exact shared-history owner, not duplicate its topic notes everywhere.
    t=head(before[REL].decode())
    t=re.sub(r'\n## 4\. Ordinary public and private life\n.*?(?=\n## 6\.)','\n## 4. Ordinary company, intimacy and partnership\n\nThe [intimacy and ordinary-company owner](intimacy-and-ordinary-company.md) holds the useful questions, proposed private meanings, and selected voice tests. They remain unplaced; no intimate history is selected by collecting them.\n',t,flags=re.S)
    t=re.sub(r'\n## 7\. Seven-day questions still open\n.*','\n## 7. Seven-day questions\n\nUse [early contact and seven-day options](seven-day-options.md) for the conditional middle-week thread, standalone Room 2.17 and ending dependencies. A present omission does not create an unseen date or settle a protected historical cause.\n',t,flags=re.S)
    t=t.replace('[working record, Section 2.1](relationship.md#legacy-checkpoint-map)','[owner clarification](#2-the-correction-that-must-not-drift)')
    t=t.replace('individual dossiers remain there too','[individual dossiers remain in the Handbook](../../02-character-relationship-handbook.md)')
    t=t.replace('[portrait/intimacy record, Sections 2–5](relationship.md#legacy-checkpoint-map)','[ordinary company and intimacy](intimacy-and-ordinary-company.md)')
    t=t.replace('The transferred pair section below','The transferred pair section above')
    t=t.replace('and what the latest full raw conversation further qualifies','and the specific information actually shared')
    t+='''
## A change of conduct can carry different meanings

**Retained assistant possibility, not a fixed inner monologue:** Lavinia might experience a newly bounded offer as recognition of why the earlier intervention hurt. Priscilla might experience the same act as a more effective way to retain closeness. The concession can be real and limited without becoming moral repentance or proving that all kindness is a deception. A later choice could test the mismatch; no particular follow-up is scheduled here.

The owner explicitly rejected the earlier proposed flashes of remorse **about the amendment**. That correction does not decide how Priscilla evaluates every other act. Lavinia’s accusation that she was only entertainment can identify a real hurt without becoming the narrator’s entire account of their beginning. Borrowed information may aid an approach; it does not supply their subsequent shared enjoyment or omniscience.

<a id="legacy-checkpoint-map"></a>
## Earlier checkpoint: current topic owners

The former portrait/intimacy checkpoint is now represented by its useful content rather than duplicate section transcripts. Its [exact earlier text](https://github.com/Siuuuers/dwm/blob/c8a67a221f45ab37ad318dfacc7c204d68590b7c/docs/story-auditions/2026-09-26-priscilla-lavinia-portrait-and-intimacy-working-record.md) remains evidence, not a new authority.

| Earlier section | Useful current destination |
|---|---|
| Corrections and attraction, §§2–3 | This relationship owner |
| Ordinary life, intimacy and partnership, §§4–5 | [Intimacy and ordinary company](intimacy-and-ordinary-company.md) |
| Middle week and Day 6/ending, §§6,10 | [Seven-day options](seven-day-options.md) |
| Bar revision and portrait family, §§7–9,11 | [Day 2 development](auditions/day-2-portrait-development.md) and the separate current scene records |
| Former navigation, capture and review reporting, §§0–1,12 | [Archival provenance](../../maintenance/source-migration.md); no repeated working prose |
'''
    write(REL,t+history_note(REL,'The established Handbook pair section above is byte-for-byte unchanged. The scoped correction and the differing-improvement reading derive from export E02; ordinary pleasure and fallible interpretation recur throughout E01–07.'))
    # Intimacy: a substantive reusable foundation, not six full analytical answers.
    t=head(before[INT].decode()).replace('The complete source tests below retain','The selected source tests below retain').replace('seven-day-options.md#exchange-08','seven-day-options.md#time-horizons')
    t+='''
## What each may enjoy, and what may make her hesitate

**Assistant proposals accepted for exploration, not settled private motives.** Priscilla may enjoy receiving affection before proving useful, Lavinia’s initiative, and not needing the perfect reply. Initiating a kiss could be easier than waiting to learn whether Lavinia will want another meeting. Her hesitation might concern being wanted for herself rather than merely for the reaction she can supply. A meaningful encounter can tempt her to infer a larger claim than the two actually agreed.

Lavinia may enjoy Priscilla making personal desire direct instead of presenting another intervention. She can also initiate; she is not merely waiting to be pursued convincingly. A potential concern is being intensely wanted in private and treated as inconsequential afterward. Continuing interest in her conversation or following through on a plan may matter independently of another physical encounter. These possibilities are not permanent sexual roles or a requirement to be insecure afterward.

The owner asked what they could welcome before agreeing they were partners. The retained answer gives neither a fixed physical ceiling based on a label. Passionate kissing or consensual sexual intimacy can be possible without being selected history; kissing need not escalate, and an evening without either can still be treasured. Attraction, present willingness, personal meaning and future agreement are separate questions. The broader educational explanation is archived rather than repeated as a writing manual.

## Ordinary life and reciprocal competence

Public warmth need not be false; private interaction need not reveal a uniquely authentic self. They can eat, walk, hear about each other’s work, or be pleased to meet without every action becoming a clue for Angela. In a separately admitted visit, they can do different things, interrupt and resume conversation, or let quiet remain ordinary. An unsuccessful joke or difference in taste need not become another dispute over authority.

Keep Priscilla’s enthusiasm and Lavinia’s curiosity about it. Do not make Priscilla competent at every practical task and Lavinia competent only at producing an emotional response. New local skills, objects or hobbies need authorship rather than inference from their professions. A bracelet-clasp task followed by Lavinia keeping the hand is an **unplaced possibility**: the task and the later contact are different choices.

## Impulse, embarrassment and regret

| Unplaced possibility | What might become visible | What it does not establish |
|---|---|---|
| Lavinia shares good news with Priscilla first | A personally chosen priority | A promise of exclusivity |
| Priscilla accepts an invitation too quickly to supply a practical reason | Desire preceding her explanation | Remorse for the disclosure intervention |
| Either initiates a clearly welcomed kiss earlier than intended | An impulse that is still a choice | An accident or permission for later acts |
| An affectionate public remark sounds more personal than expected | Desire becomes observable | Shame about the other woman or regret for the affection itself |

Lavinia need not retract every plain wish as a joke. Priscilla can stop adding an unnecessary explanation. **Regret needs an object:** timing, emotional exposure, an outcome, hurting someone, and judging an act wrong are different. The exact unwanted-kiss audit remains unavailable; these warm possibilities do not replace or sanitize it.

## First kiss, recurrence, and partnership

The suggested pre-England first kiss remains an **assistant historical proposal**, not recovered fact. Its appeal is ordinary enthusiasm becoming reciprocal closeness, then the conversation continuing. Priscilla might remember being chosen without being needed; Lavinia might remember Priscilla losing her sentence or her own wish not to minimize what happened. Different memories remain possibilities, not certified recollections.

Recurrence could make the awkward question change: from whether to initiate, to whether to greet that way again, to what the continuing closeness means. Yesterday’s welcome does not answer today’s wishes. Some later kisses may be pleasantly ordinary; their value need not increase with intensity. A later welcome following a violation is a new choice, not retrospective permission or vindication of Priscilla’s interpretation.

The possible partnership scene asks for a place in each other’s future rather than a threshold of kisses. The name, continuity, exclusivity, public acknowledgment and concrete obligations are separately authored matters. A declaration can be sincere while the amendment remains disputed. A post-Day-7 relationship is one possible continuation, not a promised happy ending or a substitute for Day 7’s own consequence.
'''
    write(INT,t)
    sel=[
      ('upload-e03-assistant-1','### A. Ordinary company that does not need to prove anything','The useful part is not a hidden symbol.','An unimpressive film, enjoyable company','Keep their shared ridiculous patience, not a clue or a permanent film preference.'),
      ('upload-e03-assistant-1','### B. Lavinia gives affection without disguising it','Here Lavinia is neither bait nor reward.','An offered hand and an unfinished story','This lets Lavinia initiate affection and continue the conversation instead of making contact its climax.'),
      ('upload-e04-assistant-1','> “I don’t know whether this is good anymore,”','The point is not that Lavinia supplies','Listening to what Priscilla made','Lavinia’s interest extends beyond a useful service or a perfect critique.'),
      ('upload-e06-assistant-1','> Lavinia had asked about the book','What I like here is','A possible first kiss, then more conversation','This is the unselected pre-England proposal, retained because its ordinary continuation matters. It does not establish a first kiss.'),
      ('upload-e06-assistant-1','> “I want us to be together,”','The meaningful event is','A possible later explicit relationship','Retain the short reciprocal answer and pleasant awkwardness; the event and its timing remain unselected.')]
    for uid,a,z,title,note in sel:
        with (root/INT).open('a') as f:f.write(excerpt(uid,a,z,title,note,INT))
    with (root/INT).open('a') as f:f.write(history_note(INT,'E03–07 and the earlier thematic checkpoint supply these interpretations and tests. The author’s E08 correction keeps capability, pre-week history, seven-day occurrence and later possibilities separate.'))
    # Week-wide questions and actual dependencies.
    t=head(before[WEEK].decode())+'''
<a id="time-horizons"></a>
## Three horizons and a conditional middle-week thread

The owner’s E08 correction distinguishes established pre-week history, events selected during Days 1–7, and hypothetical later continuations. Capacity does not create an appointment. A possible first kiss cannot be placed in the past merely because the week has no room. Day 7 needs a concrete present consequence, not a promise that the satisfying event happens afterward.

| Proposed window | Owner-originated possibility | What still needs authorship |
|---|---|---|
| Day 1 Priscilla solo | Interest in Angela’s current knowledge of Lavinia, with an initially Angela-directed jealousy reading | Information channel and a scene valuable to Angela and Priscilla independently; compare the retained no-name reflex rather than stacking clues |
| Day 2 solos | Wet shoulder, unusual animation, interrupted recollection or an oblique reply | Actual timing and custody; an observer sees behavior, not a verified reminiscence; the combined clues cannot reconstruct the protected umbrella journey |
| Day 3 Lavinia solo | Make an enjoyable Angela encounter conspicuous to Priscilla | A specific recognizable trace, its custody, and Angela’s own awareness and purpose |
| Day 4 Priscilla solo | Jealousy expressed through overprecise attention or distraction | Actual receipt and recognition of the trace before a reaction; not a universal sarcastic mood |
| Day 5 Lavinia solo | Changed appetite for testing after a separately authored approach | Actual contact and willingness; exhaustion or relaxation proves neither sex nor permission |
| Day 6 solos | Bounded facets of the disclosure grievance | Present purpose in each encounter; not two perfectly complementary explanatory files |
| Day 7 | A choice about continued contact, refusal, or commitment | A definite action and consequence compatible with the history actually experienced |

**Minimal carrier test, not a runtime rule:** with Day 3 as the only way to create a trace and Day 4 as the only way to deliver it, both are required for trace-triggered jealousy. Day 3 alone creates but does not deliver it; Day 4 alone cannot deliver what was never created; neither supplies no such thread. An independent carrier is another proposal to author, not compensation for a missed solo. Angela is not a transferable token.

## Why Room 2.17 remains a different opportunity

The collaboration has its own protected causal core: real required work, a usable third version neither woman would make alone, the optional second folder, and the personally arranged return in the Love form. The critique of the bar briefly led the assistant to favor Room 2.17 on Day 2. E12–13 corrected that focus toward the owner’s conditional Day 6 proposal, not a queued first Group or a bar scene delayed until it can be seen.

| Actual history | Proposed Day 6 | Eligibility scope being explored |
|---|---|---|
| Day 2 occurred, including private-offscreen or Missed Group | Tea appropriate to that occurrence | Existing two-meeting history |
| Day 2 did not occur; Day 6 occurs | Standalone Room 2.17, across its Group/private presentations | A new Day-6-only pair-ending possibility |
| Day 2 only | No Day 6 pair encounter | No newly proposed Day-2-only qualification |
| Neither | Neither pair event | No new qualification |

This is **not** the generic change `pair_count >= 1`. The proposal does not silently alter double-activation suppression of Angela’s invitations, profile witness/mastery receipts or the frozen pair form. The current Matrix and future-behavior record retain their own status.

Room 2.17’s work must make sense late in the week and cannot simply vanish in the tea history. Its future-return action must fit Day 7 without inventing another window or treating a promised visit as completed. An ending may use one shared situation with history-sensitive setup; each eligible history must actually supply the decisions it depends on. The one-meeting version cannot borrow the bar’s stay, harm or memories.

## Questions whose answers still change the plot

The earlier interview asked whether to add a middle-week thread or replace the bar/tea structure; what concrete Day-7 change to seek; whether “toy” is a fully conscious original plan or an insufficient self-description; what Priscilla recognizes about authorization; what the “forceful” approach actually is; and how aware Angela is of a jealousy provocation. E02 gave a narrow correction on the amendment and accepted directions for exploration, not every scene detail.

Keep the physical approach, information chain, exact first-recognition cause and ending act open until selected. The notebook does not answer those questions by existing. Greater harm does not automatically mean stronger devotion, and a local iteration cannot finish the whole week’s access and coexistence review.
'''
    write(WEEK,t+history_note(WEEK,'E01, E08 and E11–13 supply the competing directions, corrections and dependencies. The former checklist of source-processing steps is archived; the narrative questions remain here.'))
    # Day 2: selected rich rationale and a complete genuinely different scene.
    t=head(before[DEV].decode())+'''
## Decisions and functions worth retaining

| Item | Direction and reason | Status or limit |
|---|---|---|
| Nap/shared glass | Earlier intimate texture; a lighter glass rendering removes the demonstration-like emphasis | Omitted in the new portrait reading, not globally rejected or proof of shared sleeping arrangements |
| Tears and raised hand | History supports hurt but does not earn the precise timing. Sweet need not pass through an almost-slap | Removal changes Dark’s dependent aftermath; no symptom may survive without its cause |
| “I was glad you came” | Gives Lavinia a personal risk before continued withholding | A consequential alternative disclosure, not neutral connective wording |
| Physical book | Priscilla reads because she wants to; Lavinia helps make the discussion enjoyable | Not automatically a prepared apology, permanent genre preference or new sexual history |
| “That explains it” | Answers an audible justification while possibly reaching beyond the book | No obligatory “Explains what?” / “Nothing,” complete diagnosis or ominous signal |
| “I thought you’d let me read it first” | Reveals injured trust; “You could have let me…” is the sharper alternative | Expectation, not an invented prior promise; keep separate from the benign biography correction |
| “Why did you keep finding reasons to come to me?” | Turns from a fictional person’s desire to Priscilla’s own | Retained after the assistant had proposed replacing too much of the original interrogation |
| Six-word biography | A true occasion is not an adequate account of repeated personal approaches | Proposed local Dark allocation, not different histories or Sweet-truth/Dark-lie |
| “You should have left me alone” | A backward-looking grievance within a genuine attachment | Not automatically “go now,” and not covert permission to stay; the next invitation has its own act |
| Whisper | Optional private pleasure and curiosity in a public bar | Cannot conceal the crucial refusal, promise, apology or cause of later anger; no need to insert it |
| House and coat | Keep the absurd commission and Priscilla’s ordinary enthusiasm | Their detailed local changes belong in [Sweet–Love](day-2-sweet-love-portrait.md), not another duplicate account |

Lavinia can resent how readily enjoyment returns without merely pretending to be angry. “You made me attached” can be her accusation without erasing her curiosity and participation. Priscilla can be affected by the admission of importance without accepting that the amendment was wrong. The invented portrait supplies a resemblance in reasoning, not documentary proof of her motives or of a prior assault.

## Four-form foundation, not four finished scenes

| Form | Proposed decisive conduct | Consequence that cannot be borrowed by another history |
|---|---|---|
| Sweet–Ambiguous | No compulsory threat; company continues without an extension request | Continued time without an agreed request; the old farther-chair gesture needs its cause re-earned |
| Sweet–Love | The personal answer remains withheld; Lavinia requests more company and Priscilla genuinely accepts | A fulfilled interval, not an immediate ceremonial yes or forgiveness |
| Dark–Ambiguous | In the strike-bearing candidate, harm, refused follow-up touch and actual departure | No accepted stay and no purchased personal confession |
| Dark–Love | The same harmed encounter contains an explicit request and genuine finite acceptance | “Until the bill comes,” then departure; paid-order staging must make the wait freely chosen |

These are local uses of the axes, not their universal definitions. The room, service model, timing, strike transition, fine-motor disturbance, chosen visibility, Group involvement and board access require their existing review. The harm need not be fake because its later visibility is chosen; leaving and refusing contact are not themselves the sinister acts. The interior line about wanting a facial response should be tested by removal, not rescued by making Priscilla cruel enough to make violence seem compulsory.

## Retained pressure and presentation alternatives

The earlier proposal “I was glad you came” makes a different disclosure from “I thought you’d let me read it first.” A partial personal answer would differ from “I’d rather not”: it changes mutual knowledge, not just rhythm. Neither is selected merely by being a smoother transition.

The original novel opening disclosed completion very early; the later portrait discovers it during shared reading. The early question “Would you have told her?” / “Before she agreed?” / “Then she might have gone” was judged a more exposed position-taking turn. Its usefulness and its cost remain available without storing another nearly identical full portrait here.

The hat/haircut version below is different enough to retain as a complete comparison: enthusiasm, deliberate withholding and voluntarily resumed company. It is not a future chapter inside the portrait novel. New scene production still needs the whole family and week, not only this local alternative.
'''
    write(DEV,t)
    with (root/DEV).open('a') as f:
        f.write(excerpt('upload-e14-assistant-1','Priscilla is explaining the book she is reading.','## 3. What this version is trying to accomplish','Earlier complete alternative: the hat, the haircut, and another half-hour','Its independent comic subject and the resumed telling test ordinary company after an explicit refusal. Retain the complete alternate action, not all of its repeated analysis.',DEV))
        f.write(excerpt('upload-e10-assistant-1','> Priscilla’s fingers are still around the stem','That is enough for a first test.','Small rendering alternative: the glass','This tests lighter situated observation. It is not a replacement already approved for the current portrait.',DEV))
        f.write(history_note(DEV,'E09–19 supply the baseline, local objections, complete hat alternative and portrait development. E23–26 is separately curated in the Sweet–Love owner. The older family record and Dark–Love read-through remain distinct coherent sources.'))
    # Portrait: keep the scene, not all four entire assistant responses.
    t=head(before[POR].decode())
    t=t.split('\n## 4. Exact development evidence')[0]
    t=t.replace('physical lines 5280–6365. The four source exchanges were read contiguously in this recovery pass.','physical lines 5280–6365. The four exchanges were previously recovered together; this curation keeps their useful passages and local reasons.')
    t=t.replace('The next writing task is a bounded integration and comparison of those proposals','The next writing task is a bounded integration and comparison of those proposals')
    write(POR,t)
    with (root/POR).open('a') as f:
        f.write(excerpt('upload-e23-assistant-1','Priscilla is reading when Lavinia reaches the table.','## Where the desire becomes more revealing','Complete earlier Sweet–Love read-through','Preserve the whole visit for comparison. The following coat and fictional-sitter revisions are later proposals, not silently applied edits to this passage.',POR))
        f.write(excerpt('upload-e25-assistant-1','> **Priscilla:** I nearly bought a coat.','There is no necessary emotional revelation at the end.','Later coat test: interest in a particular disappointment','Priscilla starts the subject. Lavinia’s questions become curiosity about what Priscilla wanted, while a disagreement in taste can remain small.',POR))
        f.write(excerpt('upload-e26-assistant-1','> **Priscilla:** She has a friend staying with her.','The later reply still has its uncomfortable force.','Later novel test: an invited friend, not a settled partner','This changes the invented novel, not P–L’s established history. It preserves the house joke without the duration explanation and leaves the concealed-completion discovery work to do.',POR))
        f.write('\n**Earlier coat alternative:** E24 begins with “The coat fitted beautifully. I kept trying the pockets.” and ends with the disagreement over the high collar. The later E25 passage above makes Priscilla’s initiative and Lavinia’s growing interest clearer; it does not declare E24’s wording unusable elsewhere. Both exact source versions remain linked in Git.\n')
        f.write(history_note(POR,'The revision map keeps the narrowing of the house-joke objection, the different reasons for the coat conversation, and the change of fictional sitter. No integrated replacement or completed family is claimed.'))
    # Distinct Dark outcomes remain readable; repetitive precursor scenes are summarized already.
    with (root/DARK).open('a') as f:
        f.write(excerpt('upload-e46-assistant-1','Priscilla takes her bag from beside the chair.','## 1. What Priscilla is trying to obtain','Alternate outcome: the visit really ends','The owner found this too short and clean beside Sweet. Keep its actual departure as a materially different possibility, not the current conclusion or an automatic moral punishment.',DARK))
        f.write(excerpt('upload-e48-assistant-1','*Writer-side distinction for this audition:','## 5. What makes this darker than an ordinary reconciliation','Alternate approach: longing and performed repentance','The specific moral claim is knowingly false in this proposal, while the desire is genuine. The owner objected to the expository interrogation; preservation does not make the lie fixed conduct.',DARK))
        f.write('''
## Continuations still available, not scheduled

The notebook might make Lavinia more selective about future sharing; Priscilla might overestimate how much the invitation restored; a later encounter might expose a misread private instruction. These are assistant possibilities, not Day 7 facts. Each requires its own cause and actual occurrence. The latest kept-note scene remains an unselected proposal and does not select any cheek touch or continuing injury.
''')
        f.write(history_note(DARK,'E45–50 supplies the sequence of objections and alternatives; the later visible-chat correction removes the duplicate Sweet performance and motivates the current kept-note opening. The archived secondary reconstruction does not supersede that later correction.'))
    # The original hearing is unchanged; retain only its additional assembled voice test.
    t=before[HEAR].decode();token=re.search(r'<!-- END RELOCATED ORIGINAL [0-9a-f]+ -->',t).group(0);t=t[:t.index(token)+len(token)]
    write(HEAR,t+'\n\n## Later voice-test direction\n\nThe owner challenged dialogue that merely fills time under the listening mechanism. The curtain-call experiment lets Priscilla move from correction into furnishing Lavinia’s absurd idea. It remains a replaceable conversation, not an actual past performance. The hearing’s precise replay and uninterrupted-speech obligations remain those of the retained record above.\n')
    with (root/HEAR).open('a') as f:
        f.write(excerpt('upload-e27-assistant-1','*The arrival cue and door arrangement','## 4. What I would preserve in this version','Assembled curtain-call test','Retain the complete enacted interval; the dance is a competing encounter, not something to append to this one. Audio length, door geometry and exact wording remain untested.',HEAR))
        f.write(history_note(HEAR,'The pre-existing coherent hearing record is preserved. Only its added raw response and secondary retelling have been reduced to their distinct scene and useful context.'))
    for p in [DANCE,REF]:
        with (root/p).open('a') as f:f.write(history_note(p,'The assembled current passage and its local revision notes are unchanged. Repeated earlier assemblies and paraphrases remain available through the archive, not reproduced beside the current scene.'))
    # Resolve all old section navigation deliberately after redistribution.
    target_routes={0:(MAINT+'source-migration.md','provenance'),1:(MAINT+'source-migration.md','provenance'),2:(REL,'2-the-correction-that-must-not-drift'),3:(REL,'3-why-the-company-is-worth-wanting'),4:(INT,'ordinary-life-and-reciprocal-competence'),5:(INT,'first-kiss-recurrence-and-partnership'),6:(WEEK,'three-horizons-and-a-conditional-middle-week-thread'),7:(DEV,'decisions-and-functions-worth-retaining'),8:(DEV,'decisions-and-functions-worth-retaining'),9:(DEV,'four-form-foundation-not-four-finished-scenes'),10:(WEEK,'why-room-217-remains-a-different-opportunity'),11:(DEV,'next-integration'),12:(MAINT+'source-migration.md','provenance')}
    # Compact receipts; previous exact-transfer audit and its checker stay reproducible at BASE.
    migration='''# Story consolidation and selective curation

The legacy audition directory has been consolidated into `story/`. The later owner clarification changed the retention goal from reproducing every exchange to keeping material useful for writing. This curation leaves current scene prose, established pair guidance and distinct older auditions intact; it removes conversational duplication and administrative history from the active documents.

## What remains useful in the working tree

Keep current passages, consequential author corrections, meaningful questions, reasons for local revisions, distinctive alternative scenes, and conditional continuations. Condense overlapping explanation. A pleasurable small moment can be useful without supplying a clue or saved variable. General praise, repeated status reports, historical tool commands and duplicate summaries belong in Git, not another active transcript folder.

## Provenance

| Snapshot | Retained location and use |
|---|---|
| Original 13-file directory | `c8a67a221f45ab37ad318dfacc7c204d68590b7c` |
| Exact supplied upload | `62fd8bf3966e4df7e03bf52952c6905284845284` on `archive/pl-narrative-sources-2026-10-01` |
| Complete pre-curation transfer and 153-unit map | `3b553e1a3d986fa0de3be4a529f895cba4d9acca` |
| Present selection of useful material | [Topic/source map](our-pl-upload-recovery.md) and [curation manifest](source-migration.json) |

The two raw transcript snapshots differ only in the opening greeting/workflow request and final newline, not story discussion. Uploaded source ranges belong to the upload, not the older blob. The earlier secondary archive contains reconstruction/normalization and cannot overrule the primary conversation. Do not remove the retained archive branch as a merged feature branch. The proposed ordinary merge commit preserves the pre-curation record in master’s ancestry as well.

[Original upload](https://github.com/Siuuuers/dwm/blob/62fd8bf3966e4df7e03bf52952c6905284845284/docs/story-auditions/Our_PL.md) · [Earlier exact-transfer manifest](https://github.com/Siuuuers/dwm/blob/3b553e1a3d986fa0de3be4a529f895cba4d9acca/story/maintenance/source-migration.json) · [Earlier verifier](https://github.com/Siuuuers/dwm/blob/3b553e1a3d986fa0de3be4a529f895cba4d9acca/story/maintenance/verify_consolidation.py).

## Deliberate dispositions

Nine coherent older auditions retain their original meaningful bodies; the hearing keeps its additional curtain-call scene but not the whole accompanying response. The established Handbook pair section remains unchanged in its new owner. The current dance, refusal and notebook are unchanged. The earlier Sweet–Love portrait is retained as a whole passage followed by separate later coat and fictional-sitter tests, not a falsely recovered composite.

The old thematic checkpoint’s unique questions and constraints are represented in relationship, intimacy, week and Day 2 notes. Repeated secondary retellings are archived. Historical PR #2 conversation, tool payload copies, obsolete navigation and the three reversible Bible-difference exhibits are archive-only: current Bible history is not changed by removing those exhibits. The old source directory and a replacement `story/sources/` directory remain absent.

## Verification and limits

The current checker validates active navigation and, when given `--snapshot`, the exact curated excerpts and protected dialogue against the pre-curation source map. It does not require every old paragraph to survive future authorized revisions. Historical transfer checks belong to their historical revision; their 451-pass result is not a fresh literary review or a permanent writing constraint.

The curation review checks attribution, local rejection scope, available alternatives and retained ordinary pleasure. No new scene, intimate milestone, bodily residue, residence fact, calendar placement or runtime behavior is selected. The earlier missing bar/residue and kiss-source questions, full scene-family approval, physical/audio staging and runtime tests remain **NOT RUN/open** as applicable. Documentation readiness does not close those narrative holds.

## Latest instruction and checkpoint

The owner clarified that “all 50 exchanges” was a question about processing, not a request for complete active transcription, then authorized this curation followed by merging PR #3 if its checks pass. The four-substantive-exchange cadence remains, now explicitly about useful development rather than copying exchanges. This document describes the reviewed candidate; the PR and publication receipt establish whether a push and merge actually succeeded.
'''
    write(MAINT+'source-migration.md',migration)
    recovery='''# Where the useful conversation now lives

The supplied `Our_PL.md` contains 50 numbered exchanges. All were available for the earlier preservation transfer; **availability does not require active reproduction**. This map replaces the exchange-by-exchange transcript replicas with the topics used for writing. Exact originals and the complete pre-curation map remain in [Git provenance](source-migration.md#provenance).

| Source discussion | Current use |
|---|---|
| E01–02: attraction, information and the no-remorse correction | [Relationship](../relationships/priscilla-lavinia/relationship.md); [week options](../relationships/priscilla-lavinia/seven-day-options.md) |
| E03–07: ordinary life, intimate possibilities, impulse and partnership | [Intimacy and ordinary company](../relationships/priscilla-lavinia/intimacy-and-ordinary-company.md): curated meanings, open questions and five short tests |
| E08, E11–13: time horizons, Room 2.17 and conditional ending | [Seven-day options](../relationships/priscilla-lavinia/seven-day-options.md) |
| E09–10, E14–19: bar critique, portrait and four forms | [Day 2 development](../relationships/priscilla-lavinia/auditions/day-2-portrait-development.md): local decisions, full hat alternative and lighter glass test; the Dark portrait has its own retained read-through |
| E20–22: historical save/PR/merge reports | Archive-only administrative evidence; no current execution instruction |
| E23–26: portrait/coat and the fictional guest | [Sweet–Love portrait](../relationships/priscilla-lavinia/auditions/day-2-sweet-love-portrait.md): complete earlier scene, later distinct fragments and revision reasons |
| E27–35: hearing versus dance, indirect invitation and prior familiarity | [Hearing](../relationships/priscilla-lavinia/auditions/2026-09-07-priscilla-lavinia-day-6-sweet-love-interrupted-hearing-audition.md) and [dance](../relationships/priscilla-lavinia/auditions/day-6-sweet-love-dance.md), kept separate |
| E36–44: imagined refusal, more specific acting and tea | [Refusal](../relationships/priscilla-lavinia/auditions/day-6-sweet-ambiguous-refusal.md): current full scene and exact local revision notes, not each repeated assembly |
| E45–50 and later visible-chat correction | [Notebook](../relationships/priscilla-lavinia/auditions/day-6-dark-notebook.md): current proposal, meaningful alternate outcomes, reasons and unresolved follow-up |

The export’s endpoint predates the later objection to repeating Sweet’s “much” in Dark. That correction and the latest notebook opening remain in force at their actual scope. The older secondary reconstruction supplies provenance, not an independent approval or a replacement for missing pre-export conversations.

The raw upload is 1,115,494 bytes / 10,834 lines, SHA-256 `9dd985c686b5a2b9c3f01184f738eef05d7db49d63afa3999213390e5406b8a6`, blob `9e20a006afc8cb094284f510766d8db78b122b75`. Its source remains complete in Git. No source must be copied back into the active tree merely to re-examine a doubtful local decision.
'''
    write(MAINT+'our-pl-upload-recovery.md',recovery)
    # Existing indexes become truthful about selective, rather than transcript, retention.
    for p in ['story/README.md',PAIR+'README.md','story/auditions/README.md',PAIR+'AGENTS.md']:
        t=before[p].decode()
        t=t.replace('Exact historical excerpts are folded below the topic they explain;','Selected passages and focused development notes sit beside the topic they explain;')
        t=t.replace('All 50 exchanges of the supplied export have attributed prose destinations.','The supplied conversation has been reviewed for preservation and then selectively curated; not all 50 exchanges need active reproduction.')
        t=t.replace('all 50 exported exchanges\' substantive author/assistant prose,\nincluding E23–26\'s previously verified exact capture; all 13 legacy-directory\nfiles; meaningful historical write payloads; and the later chat decisions already\nin the current Day 6 passages.','useful ideas from the supplied export, selected exact scenes, local reasons\nand alternatives; the nine distinct retained auditions; the unchanged pair guidance;\nand later chat corrections. Full responses and administrative copies remain in Git,\nnot in the working documents.')
        t=t.replace('The former portrait/intimacy checkpoint is [mapped into its topic owners]','The useful portrait/intimacy checkpoint material is [mapped into its topic owners]')
        t=t.replace('50 supplied exchanges accounted for; earlier absent sources not invented','useful topic selection from the supplied source; earlier absent sources not invented')
        t=t.replace('Current scene text comes\nbefore historical development; preserve questions, stated reasons and meaningful\nalternatives without creating a file or journal entry per turn.','Current scene text comes\nbefore focused development; preserve useful questions, stated reasons and meaningful\nalternatives without reproducing full exchanges or creating a file per turn.')
        t=t.replace('Its exact contract and all source dispositions\nremain in [migration provenance]','Its exact former contract remains in retained Git history linked from\n[migration provenance]')
        write(p,t)
    p='story/AGENTS.md';t=before[p].decode();needle='Read the current owning section, combine overlapping edits, and make the smallest\ncomplete update.'
    addition='''Capture useful development, not the exchanges themselves. Keep exact current
passages and distinctive alternatives where their wording matters; condense
repeated reasoning into its actual question, reason, scope and remaining choice.
Leave greetings, operational history, duplicate responses and obsolete reporting
in the retained archive. Useful includes ordinary pleasure, humor and character
specificity, not only plot mechanics. Complete transcripts belong in working
documents only when their exact surrounding context is genuinely needed. A
historical preservation check is not a permanent requirement to keep every copied
paragraph; intentional curation records its scope without promoting proposals.

'''
    assert needle in t;t=t.replace(needle,addition+needle,1);write(p,t)
    # Repair links to the curated summaries instead of leaving empty historical anchors.
    for p in root.rglob('*.md'):
        rel=p.relative_to(root).as_posix();t=p.read_text();out=[];mark=None
        for line in t.splitlines(keepends=True):
            f=re.match(r'^\s*(`{3,}|~{3,})',line)
            if f:
                if mark is None:mark=f.group(1)[0]
                elif f.group(1)[0]==mark:mark=None
            if mark is None:
                def fix(m):
                    path,frag=m.group(1).split('#',1)
                    n=int(frag.removeprefix('legacy-portrait-checkpoint-'));dest,anchor=target_routes[n]
                    return ']('+posixpath.relpath(dest,posixpath.dirname(rel))+'#'+anchor+')'
                line=re.sub(r'\]\(([^)\n]*#legacy-portrait-checkpoint-\d+)\)',fix,line)
                if '](seven-day-options.md#exchange-08)' in line:line=line.replace('](seven-day-options.md#exchange-08)','](seven-day-options.md#time-horizons)')
            out.append(line)
        if ''.join(out)!=t:p.write_text(''.join(out))
    manifest={
      'schema_version':5,'purpose':'Selective working-document curation, not a permanent transcript-replication contract',
      'pre_curation_commit':BASE,'pre_curation_manifest':f'https://github.com/Siuuuers/dwm/blob/{BASE}/story/maintenance/source-migration.json',
      'raw_archive_commit':ARCHIVE,'retained_archive_branch':'archive/pl-narrative-sources-2026-10-01',
      'source_directory_retired':True,'narrative_status_changed':False,'runtime_changed':False,
      'selected_excerpts':excerpts,
      'source_file_dispositions':[{k:u[k] for k in ['path','git_blob','sha256','disposition','current_destination']} for u in original['source_files']],
      'source_snapshot_identities':original['snapshots'],
      'archived_only_categories':['greetings/general praise','repeated explanatory responses and superseded near-identical assemblies','secondary reconstructions duplicating primary-source topics','historical tool calls and PR operations','former verification/navigation/status reporting','historical embedded Bible differences'],
      'protected_blocks':[],
      'limits':['Earlier missing bar/residue/kiss evidence remains open','No newly selected intimate history, physical residue, placement or mechanics','No independent literary, audio, medical or runtime test'],
    }
    for p in [DANCE,REF,DARK]:
        pat=r'(?s)(## (?:1\. )?Current assembled passage\n)(.*?)(?=\n## )';q=re.search(pat,before[p].decode());assert q
        manifest['protected_blocks'].append({'path':p,'kind':'current_scene','sha256':sha(q.group(2).encode())})
    q=before[REL].decode().split('<!-- BEGIN TRANSFERRED HANDBOOK PAIR -->\n',1)[1].split('\n<!-- END TRANSFERRED HANDBOOK PAIR -->',1)[0]
    manifest['protected_blocks'].append({'path':REL,'kind':'handbook_pair','sha256':sha(q.encode())})
    manifest['retained_auditions']=[{'path':u['destination'],'sha256':sha(before[u['destination']])} for u in original['file_moves'] if u['destination']!=HEAR]
    token=re.search(r'<!-- END RELOCATED ORIGINAL [0-9a-f]+ -->',before[HEAR].decode()).group(0)
    pref=before[HEAR].decode().split(token,1)[0]+token
    manifest['protected_blocks'].append({'path':HEAR,'kind':'hearing_original','sha256':sha(pref.encode()),'end_marker':token})
    # Whole older-source files may have only purposeful anchor updates; record separately for review.
    changed={p:sha((root/p).read_bytes()) for p,v in before.items() if (root/p).exists() and (root/p).read_bytes()!=v}
    manifest['curated_paths']=sorted(changed)
    manifest['reviewed_markdown_paths']=sorted(set(p for p in changed if p.endswith('.md')) | {u['destination'] for u in original['file_moves']} | {'AGENTS.md','story/02-character-relationship-handbook.md'})
    write(MAINT+'source-migration.json',json.dumps(manifest,ensure_ascii=False,indent=2))
    return manifest

if __name__=='__main__':curate(Path(sys.argv[1]))
