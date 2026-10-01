#!/usr/bin/env python3
"""Deterministic documentation migration. Historical tool payloads are data only.
Run against a disposable checkout first. This program never merges or pushes refs.
"""
from __future__ import annotations
import argparse, hashlib, json, posixpath, re, shutil, sys, difflib
from pathlib import Path
from urllib.parse import unquote, urlsplit
BASE = 'c8a67a221f45ab37ad318dfacc7c204d68590b7c'
UPLOAD_SHA = '9dd985c686b5a2b9c3f01184f738eef05d7db49d63afa3999213390e5406b8a6'
UPLOAD_BLOB = '9e20a006afc8cb094284f510766d8db78b122b75'
REPO_BLOB = '0b508f8f674a749ca9dbe7fce0d1885e635baf08'
OLD = 'docs/story-auditions/'
PAIR = 'story/relationships/priscilla-lavinia/'
AUD = PAIR+'auditions/'
MAINT = 'story/maintenance/'
ARCHIVE_BRANCH = 'archive/pl-narrative-sources-2026-10-01'
def sha(data: bytes)->str: return hashlib.sha256(data).hexdigest()
def blob(data: bytes)->str: return hashlib.sha1(f'blob {len(data)}\0'.encode()+data).hexdigest()
def slug(s:str)->str:
    s=re.sub(r'<[^>]*>', '',s).lower().strip()
    s=re.sub(r'[^\w\-\s]', '',s, flags=re.UNICODE)
    return s.replace(' ','-')
MOVED = {
 '2026-08-30-angela-lavinia-day-2-focus-audition-design.md': 'story/auditions/2026-08-30-angela-lavinia-day-2-focus-audition-design.md',
 '2026-08-30-room-217-group-adaptation-audition-record.md': 'story/auditions/2026-08-30-room-217-group-adaptation-audition-record.md',
 '2026-08-31-seven-day-owner-review-constellation-audition.md': 'story/auditions/2026-08-31-seven-day-owner-review-constellation-audition.md',
 '2026-09-06-priscilla-lavinia-day-2-day-6-working-event-record.md': AUD+'2026-09-06-priscilla-lavinia-day-2-day-6-working-event-record.md',
 '2026-09-06-priscilla-lavinia-day-2-four-form-causal-spine-audition.md': AUD+'2026-09-06-priscilla-lavinia-day-2-four-form-causal-spine-audition.md',
 '2026-09-06-priscilla-lavinia-day-6-sweet-imagined-refusal-audition.md': AUD+'2026-09-06-priscilla-lavinia-day-6-sweet-imagined-refusal-audition.md',
 '2026-09-07-priscilla-lavinia-day-6-sweet-love-interrupted-hearing-audition.md': AUD+'2026-09-07-priscilla-lavinia-day-6-sweet-love-interrupted-hearing-audition.md',
 '2026-09-12-day-1-priscilla-lavinia-retrospective-reflex-audition.md': AUD+'2026-09-12-day-1-priscilla-lavinia-retrospective-reflex-audition.md',
 '2026-09-26-priscilla-lavinia-day-2-portrait-dark-love-read-through.md': AUD+'2026-09-26-priscilla-lavinia-day-2-portrait-dark-love-read-through.md',
}
WORKING = OLD+'2026-09-26-priscilla-lavinia-portrait-and-intimacy-working-record.md'
SECONDARY = OLD+'2026-09-27-priscilla-lavinia-session-conversation-archive.md'
REL = PAIR+'relationship.md'
INTIMACY = PAIR+'intimacy-and-ordinary-company.md'
WEEK = PAIR+'seven-day-options.md'
DEV2 = AUD+'day-2-portrait-development.md'
PORTRAIT = AUD+'day-2-sweet-love-portrait.md'
DANCE = AUD+'day-6-sweet-love-dance.md'
REFUSAL = AUD+'day-6-sweet-ambiguous-refusal.md'
DARK = AUD+'day-6-dark-notebook.md'
HEARING = MOVED['2026-09-07-priscilla-lavinia-day-6-sweet-love-interrupted-hearing-audition.md']
MIGRATION = MAINT+'source-migration.md'
CURATION = {
1:(WEEK,'Initial attraction, information channels, and the seven-day proposal','The six questions and conditional trace model remain exploration. The proposed flashes of moral remorse are corrected in E02; this initial opinion must not override that correction.'),
2:(REL,'The amendment: explicit correction and its narrow scope','The owner rejects moral remorse for the disclosure intervention, not the capacity to recognize every other wrong. Affection and protective concern remain genuine.'),
3:(INTIMACY,'Reciprocal affection and three unplaced interaction tests','Holding a hand, watching a bad film, and a mutually welcomed kiss are possibilities, not selected prior events or a seven-day checklist.'),
4:(INTIMACY,'Ordinary public/private company, impulse, embarrassment and regret','The recalled unwanted-kiss audit is not recovered by this source. Preserve the direct-reading/lunch test and the four distinct impulsive possibilities without choosing their occurrence.'),
5:(INTIMACY,'Before an agreed partnership, and after an initial kiss','Physical familiarity and shared expectations are separate. A later welcome does not authorize an earlier violation or every future encounter.'),
6:(INTIMACY,'A first-kiss proposal and possible later partnership','The pre-England kiss and post-Day-7 commitment are assistant proposals. Preserve the complete tests and meanings, not an invented history or guaranteed future.'),
7:(INTIMACY,'Passion, sensuality, sex and the meaning of a partnership','The owner asks about the characters beyond the week. Personal self-disclosure unrelated to the fiction is omitted from the active question excerpt; the exact original remains archived. Educational statements remain attributed historical commentary, not fresh research.'),
8:(WEEK,'The seven-day scope correction','Capacity is not occurrence. Do not fill free calendar space or the past with intimate milestones merely because the possibilities are attractive.'),
9:(DEV2,'Inherited bar and hearing: the baseline before the critique','This earlier reading includes nap/glass/tears/hand-rise and the poster test. Later revision does not erase its provenance; it is not the current common opening.'),
10:(DEV2,'The owner challenges posed behavior and thin dialogue','The review reopens specific causal/rendering weaknesses. It does not globally ban crying, shared drinks, violence, trivial conversation or absurdity.'),
11:(WEEK,'Compare whole encounters: bar versus Room 2.17','Room 2.17 as the next Day-2 leader is an earlier recommendation; E13 changes the proposed two-window arrangement. Its protected core and actual placement remain separate.'),
12:(WEEK,'Occurrence, first Group, and eligible Room 2.17 placement','A first witnessed Group is not the first occurring pair meeting. Offscreen and prevented events remain distinct.'),
13:(WEEK,'Tea or standalone Room 2.17; Day-6-only ending proposal','Owner-originated proposal: tea after an occurring Day 2, standalone Room 2.17 otherwise, possible ending after Day 6 alone. This is not generic at-least-one eligibility, nor implemented mechanics.'),
14:(DEV2,'The complete hat/haircut/house bar alternative','Retain its ordinary enthusiasm, personal disclosure and explicit refusal as an earlier alternative, not unseen material appended to the portrait.'),
15:(DEV2,'A physical book and the initial portrait premise','The book is an independent interest with a selective defense, not automatically a prepared apology. Established-lovers inside the invented novel are revised locally in E26. No pre-England strike is selected here.'),
16:(DEV2,'Restore the personal question; optional whispered play','This narrows the earlier replace-the-interrogation recommendation. The original question and origin-facing grievance may survive. A whisper is optional and cannot hide the decisive cause, promise or refusal.'),
17:(DEV2,'That explains it; trust rather than only affection','Read-it-first exposes an expectation of review, not a new explicit promise. Do not make the benign biography correction look like the unauthorized disclosure.'),
18:(DEV2,'Dark-only biography and four-form foundations','This is local material allocation and a proposed family, not Sweet-truth/Dark-lie or four finished scripts. Finite accepted company remains genuine.'),
19:(DEV2,'Complete Dark–Love portrait read-through and unresolved strike','The full read-through also has its retained standalone document. The strike transition and bodily residue are not declared solved; later novel changes do not silently rewrite this historical version.'),
20:(MIGRATION,'Historical request to save the discussion and PR #2 capture','Past write payloads and status claims are evidence, not current execution instructions. Their content identities and earlier Bible differences are separately accounted for.'),
21:(MIGRATION,'Historical recommendation to merge that earlier checkpoint','This explains that earlier decision only. It is not permission to merge PR #3 or evidence of present checks.'),
22:(MIGRATION,'Historical merge request and reported result','The source records a request and response about PR #2. No fresh runtime/reviewer evidence is inferred from the report.'),
23:(PORTRAIT,'Complete Sweet–Love portrait with the first coat passage','Already transferred exactly in v2. Its later patches remain separate rather than a falsely recovered final composite.'),
24:(PORTRAIT,'Trim coat machinery and premature explanation','Already transferred exactly. Preserve the different rhythms and ordinary pleasure; E25 narrows the earlier house-joke criticism.'),
25:(PORTRAIT,'Priscilla starts the coat; restore the house joke','Already transferred exactly. Priscilla contributes; Lavinia becomes genuinely curious. Remove the duration explanation, not the house joke itself.'),
26:(PORTRAIT,'The fictional sitter becomes an invited friend','Already transferred exactly. This changes the invented novel, not the pair’s past. Wanting company is a reason to ask, not a guarantee of acceptance.'),
27:(HEARING,'Full hearing, completed knock and curtain-call test','This is an additional unselected dialogue test beside the retained hearing contract. The toast wording, curtain-call conversation and scene duration remain open.'),
28:(DANCE,'More initiative: introduce a separate dance candidate','The dance competes with, rather than decorates, Interrupted Hearing. No requirement to collect knock, replays, dance and kiss into one scene.'),
29:(DANCE,'Reciprocal participation and changed accompaniment','An earlier fuller dance includes an attention test and position commentary. E30 removes that local scaffolding; no general prohibition on those behaviors follows.'),
30:(DANCE,'Reciprocal interests without a rigid intellectual/physical split','Remove the memory test and surplus explanations. Lavinia’s profession does not obligate a lesson or establish every kind of dance mastery.'),
31:(DANCE,'Assembled dance before the indirect invitation','Later E32 changes the invitation only; do not treat this earlier version as a separate selected history.'),
32:(DANCE,'Replace Dance with me, leave the rest','The owner specifically requests an action-completed invitation. This does not grant automatic touch or change all other beats.'),
33:(DANCE,'Assembled indirect invitation','This version precedes the familiar-feet exchange; retain its revision relationship without adding another intimate milestone.'),
34:(DANCE,'Still watching your feet; a modest improvement','Still suggests earlier observation, without a date, place, lesson or relationship label. Greater ease is not professional mastery of an unnamed social dance.'),
35:(DANCE,'Assembled familiar dance and resumed listening','Current assembled alternative in this discussion. The visit continues; no kiss or overnight stay is inferred.'),
36:(REFUSAL,'Introduce the saved imagined refusal as a different facet','The minimal replay/refusal candidate stays a separate baseline. Do not append it after the dance or make Ambiguous a lesser quantity of affection.'),
37:(REFUSAL,'Clinginess, curiosity and the ordinary tea return','Sounding each other out is a possible undercurrent, not a compulsory concealed test. A performed answer is not a verified forecast.'),
38:(REFUSAL,'First role reversal and playful tea forfeit','Earlier generic imitation and penalty for not coming. Retain the reciprocal play; E39 makes its distortions more particular.'),
39:(REFUSAL,'Two different caricatures and an unwanted added sentence','The narrow much correction and excessive graciousness do different work. For adding that last sentence replaces the prior charge; the forfeit remains willingly accepted.'),
40:(REFUSAL,'Knowing something real, not the whole heart','The owner enjoys imperfect recognition. The assistant corrects the inference of complete mutual knowledge without removing genuine affection.'),
41:(REFUSAL,'Full visit and the first tea-making aftermath','The role-play survives. The accidental strong first pot is superseded by the deliberate preference developed in E42–44.'),
42:(REFUSAL,'Tea experience versus personal preference','Earlier lesson wording is new background, not established expertise. Following a preference need not be sacrifice or repentance. Caffeine remains a possibility, not a chosen mechanism.'),
43:(REFUSAL,'Lavinia volunteers that she tried Priscilla’s way','This replaces teacher-like showed-you correction; it implies a known method without dating or fixing a lesson.'),
44:(REFUSAL,'Add now without certifying two meanings','Changed preference is expressed. Separation resonance and caffeine motive are optional readings, not guaranteed causes or a hidden strategy.'),
45:(DARK,'Private staged-departure experiment from a Group idea','Retain the original Group provenance and the missing private transition. This later experiment is not the earlier justified departure after harm.'),
46:(DARK,'The counter-audition actually ends the visit','No secret pursuit/return repairs it. E47 challenges its thinness and clean irony; it is not the current notebook ending.'),
47:(DARK,'A troubling success at the cost of a minute alone','The owner asks for richer entanglement. The pressure/hand-holding version is an alternative later challenged for generic fighting, not a permanent rule.'),
48:(DARK,'Active courtship with a deliberately false apology','The specific lie is an assistant proposal, not newly fixed conduct or genuine repentance. E49 rejects its expository center.'),
49:(DARK,'Present privacy violation instead of an apology interview','The first page-reading candidate gives the danger a concrete act. The perfect private lever and overly analytical permission line remain review questions.'),
50:(DARK,'Kept notes, remembered remarks and humming','The owner welcomes a richer notebook. This ending still repeats much in Dark; the later visible-chat correction and current kept-note passage take precedence. No London location or complete mind-reading is established.'),
}
DOC_INTROS = {
 INTIMACY: '''# Priscilla–Lavinia — ordinary company, intimacy, and partnership

**Status:** character-development possibilities and `REACTION TEST` material, not selected intimate history. [Established pair guidance](relationship.md#established-pair-guidance) and the [Bible](../../01-core-story-bible.md) govern actual history. The first kiss, recurring physical affection, sexual intimacy and any later partnership remain unplaced unless a separate owning decision selects them.

## Working distinctions

The source exploration asks why they want an ordinary hour together, not only why they provoke each other. Either may initiate or receive welcome affection. Priscilla can enjoy being wanted without needing to be useful; Lavinia can enjoy another person without turning every response into a test. These are proposed readings, not diagnoses or a requirement that every encounter demonstrate the same pattern.

A physical act, its personal meaning, and an agreement about future conduct are different questions. Embarrassment can concern being readable without being regret for the affection; regret needs an object. A relationship label does not establish consent, exclusivity, perfect mutual understanding or permanence. Their capacities do not schedule a sequence of milestones within seven days. The [time-horizon correction](seven-day-options.md#exchange-08) retains that limit.

The welcome-kiss possibilities and recalled unwanted-kiss question remain different events. Later attraction or affection cannot supply permission for an earlier act. The exact earlier unwanted-kiss audit is still not recovered merely by migrating this export. Priscilla’s no-remorse clarification concerns the disclosure intervention, not every possible violation.

## Preserved pleasures and open choices

The complete source tests below retain the bad film, the deliberately offered hand, the lunch reading, the bracelet-clasp possibility, impulsive good news or eagerness, and the proposed first kiss followed by continuing conversation. They preserve why the gestures interested the discussion, rather than promoting them as a shared past. Neither professional discipline nor a polished public manner establishes an intimate role or skill.

The principal open choice is not a maximum permitted intensity: it is which actual encounter, timing, initiative and consequences the story selects. Possible post-Day-7 commitment cannot replace a present Day-7 outcome. No additional playable day, new private meeting, shared home, key or overnight entitlement is created here.

''',
 WEEK: '''# Priscilla–Lavinia — early contact and seven-day options

**Status:** owner-originated proposals, comparisons and unresolved dependencies. This document owns the detailed conversation about the possible middle-week thread and conditional Day 6. It is not the calendar authority or a runtime specification. Read the [Matrix](../../07-seven-day-causal-matrix.md) and [future-behavior record](../../../docs/design/2026-09-02-relationship-progression-runtime-behavior-record.md) for their current status.

## Current leading proposal, not implemented behavior

When Day 2 actually occurs, an occurring Day 6 can continue that history through tea appropriate to its form. When Day 2 does not occur, the proposed Day 6 is the distinct Room 2.17 collaboration. The owner also proposes possible pair-ending eligibility after Day 6 alone. This does not authorize a generic at-least-one predicate, a new Day-2-only path, or changed Angela invitation suppression.

Offscreen occurrence and nonoccurrence are not interchangeable. Missing Angela’s Group is not erasing the pair’s meeting; a prevented event cannot supply a later memory. The proposed Day 3 trace requires creation, receipt and recognition before a Day 4 reaction. An unattended solo does not manufacture a compensating private date. Angela retains her own purposes rather than becoming a transferable jealousy prop.

The earlier recommendation to favor Room 2.17 on Day 2 is retained below as a superseded comparison direction, not a current placement. The task, usable third version, optional second folder, and personally arranged future return retain their existing protected scope. A Day-6 placement must fit the work and the ending without inventing another window. Missing the bar removes that event, not the pair’s established history.

## Open questions preserved

The exact first-recognition information channel; what Priscilla meant by amusement or toy; the trace object and its custody; Angela’s awareness; which private approach actually occurs; truthful evidence of physical residue; and the Day-7 action remain distinct questions. Proposed clues must not reconstruct the entire protected umbrella history. Complete source availability is not completion of the earlier historical bar/residue audit or approval of a seven-day family.

''',
 DEV2: '''# Day 2 — from the bar baseline to the portrait family

**Status:** development and comparison, not a new combined event. Read the [retained four-form baseline](2026-09-06-priscilla-lavinia-day-2-four-form-causal-spine-audition.md), [Dark–Love portrait](2026-09-26-priscilla-lavinia-day-2-portrait-dark-love-read-through.md), and [Sweet–Love portrait and coat](day-2-sweet-love-portrait.md) as distinct versions with their own status.

## Current orientation

The portrait begins with something Priscilla genuinely enjoys and Lavinia helps make interesting. Its selective defense can lead into a personal question without the invented novel becoming a miniature medical history or a prepared apology. The ordinary accepted stay must be inhabited, not represented by a crumb and a closing line alone.

The owner’s critique reopened the shared glass’s overchoreography, the immediate cause of tears, a compulsory threatened slap across Sweet and Dark, and dialogue that functioned as filler beneath a mechanism. It did not ban those acts everywhere or require maximum absurdity. The later portrait proposal retains the original question and origin-facing grievance after the assistant initially proposed replacing too much. The trust-facing read-it-first line and the benign biography occasion must not be conflated.

## Changes that must not collapse into one history

The hat/haircut/house novel is an earlier complete Sweet–Love alternative. The portrait’s established-lover premise is later revised toward an invited friend within the invented novel. Dark-only six-word allocation is a local proposed distribution, not different past biographies or Sweet-truth/Dark-lying. A later half-hour request and a finite bill-limited acceptance have different causes and consequences. No past strike is added to every form merely to explain the current tension.

The latest Dark portrait keeps the strike transition under review. Refusing the later touch or leaving after harm is not itself the Dark wrongdoing. The hurt is genuine; a subsequently chosen exposure does not make the injury a performance or make the women even. No lingering symptom, diagnostic fact, or Day-6 cheek sequence is selected here.

## Next integration

Use the actual surviving scene and its later local revisions. Do not assemble a greatest-hits encounter containing every nap, glass, book, whisper, house joke, coat, strike and kiss. The source trail below preserves exactly why alternatives were proposed or challenged, while the active scene files remain the readable entry points.

''',
}
def trimmed_span(lines:list[str],a:int,b:int)->tuple[int,int,str]:
    while a<b and not lines[a].strip():a+=1
    while b>a and not lines[b-1].strip():b-=1
    if b>a and lines[b-1].strip()=='---':
        b-=1
        while b>a and not lines[b-1].strip():b-=1
    return a,b,''.join(lines[a:b]).rstrip('\r\n')
def parse_upload(data:bytes):
    text=data.decode('utf-8'); lines=text.splitlines(keepends=True)
    starts=[i for i,l in enumerate(lines) if re.match(r'^## Me😸 \d+:',l)]
    assert len(starts)==50
    units=[]; payloads=[]; turns=[]
    for n,a in enumerate(starts,1):
        b=starts[n] if n<len(starts) else len(lines)
        assert int(re.search(r'Me😸 (\d+):',lines[a]).group(1))==n
        marks=[i for i in range(a,b) if lines[i].strip()=='**You❤:**']
        assert marks
        aa,bb,body=trimmed_span(lines,a+1,marks[0])
        units.append({'id':f'upload-e{n:02d}-author','exchange':n,'role':'Author','a':aa,'b':bb,'text':body,'source_path':OLD+'Our_PL.md','source_kind':'upload'})
        part=0
        for k,c in enumerate(marks):
            d=marks[k+1] if k+1<len(marks) else b
            aa,bb,body=trimmed_span(lines,c+1,d)
            try: obj=json.loads(body)
            except ValueError:
                part+=1
                units.append({'id':f'upload-e{n:02d}-assistant-{part}','exchange':n,'role':'Assistant proposal/commentary','a':aa,'b':bb,'text':body,'source_path':OLD+'Our_PL.md','source_kind':'upload'})
            else:payloads.append({'exchange':n,'a':aa,'b':bb,'object':obj,'text':body})
        turns.append({'exchange':n,'start_line':a+1,'end_line':b,'sha256':sha(''.join(lines[a:b]).encode())})
    return units,payloads,turns

def preserve(root:Path, manifest:dict, unit:dict, dest:str, label:str, archive_commit:str, source_ref:str|None=None):
    text=unit['text']; rendered=text
    transform='strip-outer-linebreaks'
    if unit['id']=='upload-e07-author':
        key='And also I would like to ask'
        assert key in text
        rendered=text[text.index(key):]
        transform='omit-unrelated-personal-context-before-fiction-question'
    max_ticks=max((len(m.group()) for m in re.finditer(r'`+',rendered)),default=0)
    fence='`'*max(4,max_ticks+1)
    ref=source_ref or (archive_commit if unit['source_kind']=='upload' else BASE)
    link=f"https://github.com/Siuuuers/dwm/blob/{ref}/{unit['source_path']}#L{unit['a']+1}-L{unit['b']}"
    uid=unit['id']; target=root/dest;target.parent.mkdir(parents=True,exist_ok=True)
    block=(f'\n<details>\n<summary>{label}</summary>\n\n'
      f'[{unit["role"]}; source lines {unit["a"]+1}–{unit["b"]}]({link}). '
      'Quoted historical evidence, not current instructions, new verification or approval.\n\n'
      f'<!-- BEGIN SOURCE {uid} -->\n{fence}text\n{rendered}\n{fence}\n<!-- END SOURCE {uid} -->\n\n</details>\n')
    with target.open('a',encoding='utf-8') as f:f.write(block)
    manifest['content_units'].append({k:unit[k] for k in ['id','source_kind','source_path','role','a','b']}|{
      'source_ref':ref,'source_sha256':sha(text.encode()),'destination':dest,'rendered_sha256':sha(rendered.encode()),
      'transform':transform,'fence':fence,'disposition':'PRESERVED_IN_TOPIC_OWNER'})

def all_sections(text:str,pattern=r'^## (\d+)\. '):
    ls=text.splitlines(keepends=True); ss=[i for i,l in enumerate(ls) if re.match(pattern,l)]
    if not ss or ss[0]!=0:ss.insert(0,0)
    return [(a,ss[j+1] if j+1<len(ss) else len(ls),''.join(ls[a:ss[j+1] if j+1<len(ss) else len(ls)]).rstrip('\r\n')) for j,a in enumerate(ss)]

def markdown_chunks(text:str)->list[str]:
    parts=[]; current=[]; mark=None; length=0
    for line in text.splitlines(keepends=True):
        if mark is None:
            m=re.match(r'^ {0,3}(`{3,}|~{3,})',line)
            if m:
                parts.append(''.join(current));current=[line];mark=m.group(1)[0];length=len(m.group(1))
            else:current.append(line)
        else:
            current.append(line)
            if re.match(r'^ {0,3}'+re.escape(mark)+'{'+str(length)+r',}\s*$',line):
                parts.append(''.join(current));current=[];mark=None
    parts.append(''.join(current))
    return parts

def transform_links(text:str, old_path:str,new_path:str, path_map:dict, anchor_map:dict, archive_commit:str)->str:
    chunks=markdown_chunks(text)
    def fix_link(m):
        u=m.group(2); title=''
        if ' "' in u:u,title=u.split(' "',1);title=' "'+title
        wrapped=u.startswith('<') and u.endswith('>')
        if wrapped:u=u[1:-1]
        if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:',u) or u.startswith('//') or u.startswith('#'):return m.group(0)
        url,sep,anchor=u.partition('#')
        if not url:return m.group(0)
        old_res=posixpath.normpath(posixpath.join(posixpath.dirname(old_path),unquote(url)))
        dest=path_map.get(old_res,old_res)
        if old_res==WORKING and anchor in anchor_map:
            dest,anchor=anchor_map[anchor];sep='#'
        if old_res in [OLD+'Our_PL.md',SECONDARY]:
            ref=archive_commit if old_res==OLD+'Our_PL.md' else BASE
            out=f'https://github.com/Siuuuers/dwm/blob/{ref}/{old_res}'
        else:out=posixpath.relpath(dest,posixpath.dirname(new_path))
        if sep:out+='#'+anchor
        if wrapped:out='<'+out+'>'
        return m.group(1)+out+title+m.group(3)
    for i,c in enumerate(chunks):
        if i % 2:continue
        c=re.sub(r'(\[[^\]\n]*\]\()([^\n)]+)(\))',fix_link,c)
        for a,b in sorted(path_map.items(),key=lambda kv:-len(kv[0])):
            c=c.replace('`'+a+'`','`'+b+'`')
        chunks[i]=c
    return ''.join(chunks)

def build(root:Path, upload:bytes, archive_commit:str):
    assert sha(upload)==UPLOAD_SHA and blob(upload)==UPLOAD_BLOB
    original={p.relative_to(root).as_posix():p.read_bytes() for p in root.rglob('*') if p.is_file() and '.git' not in p.parts}
    assert blob(original[OLD+'Our_PL.md'])==REPO_BLOB
    oldfiles={p:b for p,b in original.items() if p.startswith(OLD)}
    assert len(oldfiles)==13
    manifest={'schema_version':4,'repository':'Siuuuers/dwm','source_commit':BASE,'uploaded_source_commit':archive_commit,
      'retained_archive_branch':ARCHIVE_BRANCH,'source_retirement_allowed':False,'documentation_consolidation_complete':False,
      'narrative_approval_changed':False,'full_pre_export_bar_residue_audit_closed':False,
      'snapshots':{'repository':{'path':OLD+'Our_PL.md','bytes':len(original[OLD+'Our_PL.md']),'git_blob':REPO_BLOB,'sha256':sha(original[OLD+'Our_PL.md'])},
      'upload':{'path':OLD+'Our_PL.md','bytes':len(upload),'git_blob':UPLOAD_BLOB,'sha256':UPLOAD_SHA}},
      'source_files':[{'path':p,'bytes':len(b),'git_blob':blob(b),'sha256':sha(b)} for p,b in sorted(oldfiles.items())],
      'content_units':[],'file_moves':[],'embedded_payloads':[],'historical_tool_calls':[], 'editorial_limits':[
       'Content preservation and documented disposition are not narrative approval or proof of artistic superiority.',
       'Later visible-chat corrections remain in current scene bodies; export E50 does not overwrite them.',
       'Earlier bar/residue and kiss-source gaps remain narrative evidence holds, not an excuse to keep duplicate active containers.',
       'Original and uploaded transcript differ only in opening greeting/workflow request and final newline; both exact byte identities are retained.'
      ]}
    units,payloads,turns=parse_upload(upload);manifest['exchanges']=turns
    hp='story/02-character-relationship-handbook.md';ht=original[hp].decode()
    start=ht.index('## Priscilla–Lavinia\n'); end=ht.index('\n## Priscilla–Sylvia',start)
    pair=ht[start:end]
    (root/hp).write_text(ht[:start]+'## Priscilla–Lavinia\n\nThe pair-specific guidance has moved unchanged to the\n[Priscilla–Lavinia relationship owner](relationships/priscilla-lavinia/relationship.md#established-pair-guidance).\nIts examples and unresolved residence/history hold retain their original scope.\nIndividual character dossiers and the other relationships remain in this Handbook.\n'+ht[end:],encoding='utf-8')
    rel=original[REL].decode()
    rel=re.sub(r'^\*\*Role:.*?\n','**Role:** owner of the pair-specific guidance transferred unchanged from the Handbook, followed by clearly separated working development. The Bible still owns fixed history; individual dossiers remain in the Handbook.\n',rel,count=1,flags=re.M)
    rel=rel.replace('**Current owner of established pair guidance:** the Handbook\'s Priscilla–Lavinia section; it has not yet been extracted.','**Pair guidance owner:** this document’s established-guidance section, transferred without a change of meaning.')
    rel=rel.replace('These pointers are deliberately not a second complete transcription of the Bible or Handbook. Future extraction needs an explicit ownership edit and a backpointer in the old owner. A local working description does not override either source.','The Bible continues to govern narrative truth, and the Handbook continues to govern individual dossiers. The transferred pair section below has the same scope it had in the Handbook. Its examples are not selected events. Current working navigation follows the checkout; source evidence is version-specific.')
    rel=re.sub(r'\n## 9\. Uploaded-source recovery links \(v2\).*','',rel,flags=re.S)
    rel=rel.replace('This build does not invent the unread continuation of the older record\'s Section 5.3 or settle which act they regret. Preserve the question until its full source context is reconciled.','The complete earlier Section 5.3 is now preserved in the intimacy owner below. It offers different possible impulses and objects of regret; it does not select an event or settle either woman’s response to an unpermitted act.')
    rel=rel.replace('**Outstanding:** full source review beyond the reread range and the complete earlier unwanted-kiss audit.','**Outstanding:** the exact earlier unwanted-kiss audit and selection of any concrete intimate history. The supplied export’s corresponding discussion is now preserved, without pretending it contains an earlier missing record.')
    rel=rel.replace('Complete missing-source reconciliation and ownership extraction remain explicitly pending in the migration manifest.','The supplied-source migration is documented in the migration manifest. Older missing-history and narrative-selection holds remain distinct from that completed document transfer.')
    pos=rel.index('\n## 1.')
    rel=rel[:pos]+'\n## Established pair guidance\n\nThis is the former Handbook pair section, unchanged. Its residence/history migration hold is **not** the documentation-folder migration and is not closed by it.\n\n<!-- BEGIN TRANSFERRED HANDBOOK PAIR -->\n'+pair+'\n<!-- END TRANSFERRED HANDBOOK PAIR -->\n'+rel[pos:]
    (root/REL).write_text(rel,encoding='utf-8')
    manifest['handbook_transfer']={'source':hp,'source_blob':blob(original[hp]),'destination':REL,'section_sha256':sha(pair.encode()),'prefix_sha256':sha(ht[:start].encode()),'suffix_sha256':sha(ht[end:].encode())}
    for path,text in DOC_INTROS.items():(root/path).write_text(text,encoding='utf-8')
    path_map={OLD+a:b for a,b in MOVED.items()}
    path_map.update({WORKING:REL,OLD+'README.md':'story/auditions/README.md',OLD+'Our_PL.md':MAINT+'source-migration.md',SECONDARY:MAINT+'source-migration.md'})
    for fn,dest in MOVED.items():
        src=OLD+fn;p=root/dest;p.parent.mkdir(parents=True,exist_ok=True)
        text=original[src].decode();p.write_text(text,encoding='utf-8')
        manifest['file_moves'].append({'source':src,'destination':dest,'source_blob':blob(original[src]),'content_change':'link-rebasing-only; current-context banner added separately'})
    (root/MIGRATION).write_text('''# Narrative workspace consolidation — coverage and provenance

**Scope:** documentation consolidation, not canon promotion, final DTL, a completed seven-day plot or closure of the earlier bar/residue audit. Current writing starts in [the story index](../README.md) and [the P–L working home](../relationships/priscilla-lavinia/README.md).

## What the migration preserves

All fifty numbered exchanges have a destination for their author contribution and substantive assistant prose. The exact primary discussion is kept below the appropriate current topic or scene, with source ranges, attribution, local disposition and later corrections. Historical tool requests are not executed. Embedded document contents are either identical to an accounted-for owner or preserved as a precise historical difference. Greetings and historical operational claims confer no approval. The one unrelated personal-context prefix in E07 is omitted from active text; the original remains in the retained archive.

Nine distinct coherent auditions are relocated with their text intact except for repaired live references and an explicit current-context note. The thematic portrait/intimacy checkpoint is distributed by section. The older mixed reconstruction/transcript is distributed into the same topics and labeled secondary; it never outranks the primary chronological source. The old workspace index becomes the current authority/navigation contract rather than a permanent redirect. No raw transcript folder is created.

## Exact source retention

The original directory is retained at source commit `'''+BASE+'''`. The exact uploaded transcript is retained at `'''+archive_commit+'''` on `'''+ARCHIVE_BRANCH+'''`; that snapshot descends from the original and does not change the main working branch. Both source byte identities and every destination are recorded in [the manifest](source-migration.json).

The source-export artifact was a transfer mechanism, not the archive. Its expiration cannot remove the retained Git snapshots. Do not delete the archive branch as though it were a merged feature branch. No retention can protect against a repository owner deliberately deleting the repository or rewriting every retaining reference.

## Difference between the two transcript copies

A complete comparison found only the opening greeting/workflow request and the final newline differ. Story discussion is unchanged. The uploaded copy has 50 numbered exchanges and 10,834 physical lines; the repository copy has 10,832. Uploaded line ranges must not be applied to the older blob. The uploaded source ends before the later duplicate-much correction, latest notebook assembly and documentation/cadence discussion; those later visible-chat decisions are preserved in the existing current documents.

## Completion does not settle the fiction

The old folder can be retired once its contents and original evidence have been accounted for. A kiss, cheek symptom, scene winner, form placement, Room 2.17 dispatch or ending predicate may remain explicitly unselected in its new owner. The special earlier historical evidence hold is preserved as a narrative prerequisite, not confused with missing bytes in this supplied export.

## Verification scope

The executable [verification script](verify_consolidation.py) checks source identities, every extracted unit, existing exact E23–26 transfers, moved-file transformations, the unchanged Handbook section, embedded differences, active relative links, protected current passages, and the absence of tracked legacy-directory paths. Its results are integrity/preservation evidence, not independent literary review or gameplay tests. Runtime, audio, physical staging and whole-family approval are **NOT RUN**.

## Earlier checkpoint decisions

The earlier additive publication was deliberately incomplete, and a subsequent owner clarification changed the finish line to full consolidation and deletion of the old active directory before merge review. The four-substantive-exchange cadence applies to new conversation checkpoints, not archive-processing batch size. The completed-work receipt and current PR status must be read separately from the historical save/merge conversations below.

''',encoding='utf-8')
    working_routes={0:MIGRATION,1:MIGRATION,2:REL,3:REL,4:INTIMACY,5:INTIMACY,6:WEEK,7:DEV2,8:DEV2,9:DEV2,10:WEEK,11:DEV2,12:MIGRATION}
    anchor_map={};checkpoint_rows=[]
    for idx,(a,b,text) in enumerate(all_sections(original[WORKING].decode())):
        match=re.match(r'^## (\d+)\.',text); num=int(match.group(1)) if match else 0
        dest=working_routes[num]; uid=f'portrait-checkpoint-{num:02d}'
        title=text.splitlines()[0]; anchor=f'legacy-portrait-checkpoint-{num:02d}'
        with (root/dest).open('a',encoding='utf-8') as f:f.write(f'\n<a id="{anchor}"></a>\n')
        preserve(root,manifest,{'id':uid,'role':'Retained working-record section','a':a,'b':b,'text':text,'source_path':WORKING,'source_kind':'repository'},dest,title,archive_commit)
        checkpoint_rows.append((num,title,dest,anchor))
        for l in text.splitlines():
            if l.startswith('#'):anchor_map[slug(re.sub(r'^#+\s*','',l))]=(dest,anchor)
    with (root/REL).open('a',encoding='utf-8') as f:
        f.write('\n<a id="legacy-checkpoint-map"></a>\n## Retired portrait/intimacy checkpoint — ownership map\n\nThe former thematic record is distributed below; its exact sections are preserved, not a new set of approvals.\n\n| Section | Current owner |\n|---|---|\n')
        for _,title,dest,anchor in checkpoint_rows:
            f.write(f'| {title.lstrip("# ")} | [Retained section]({posixpath.relpath(dest,posixpath.dirname(REL))}#{anchor}) |\n')
    inverse={v:k for k,v in path_map.items() if k in [OLD+x for x in MOVED]}
    for p in sorted(root.rglob('*.md')):
        relpath=p.relative_to(root).as_posix()
        if relpath.startswith(OLD):continue
        oldpath=inverse.get(relpath,relpath)
        t=p.read_text();new=transform_links(t,oldpath,relpath,path_map,anchor_map,archive_commit)
        if new!=t:p.write_text(new,encoding='utf-8')
    for fn,dest in MOVED.items():
        p=root/dest;t=p.read_text()
        note=('> **2026-10-01 workspace consolidation:** this complete retained audition has moved; '
          'its existing status, local approvals, proposed conduct and open narrative holds are unchanged. '
          'Older workspace-retirement instructions are superseded only organizationally by the completed migration. '
          f'Read the [current working entry]({posixpath.relpath(("story/auditions/README.md" if dest.startswith("story/auditions/") else PAIR+"README.md"),posixpath.dirname(dest))}) '
          'before continuing a newer candidate. No scene is approved by relocation.\n\n')
        p.write_text(note+t+'\n<!-- END RELOCATED ORIGINAL '+blob(original[OLD+fn])+' -->\n',encoding='utf-8')
    for n in range(1,51):
        dest,title,decision=CURATION[n]
        if 23<=n<=26:
            for u in [x for x in units if x['exchange']==n]:
                marker=f'OUR-PL-E{n}-'+('AUTHOR' if u['role']=='Author' else 'ASSISTANT')
                t=(root/dest).read_text(); m=re.search(r'<!-- EXACT '+re.escape(marker)+r' START -->\n(`+)text\n(.*?)\n\1\n<!-- EXACT '+re.escape(marker)+r' END -->',t,re.S)
                assert m and m.group(2)==u['text'],u['id']
                manifest['content_units'].append({k:u[k] for k in ['id','source_kind','source_path','role','a','b']}|{'source_ref':archive_commit,'source_sha256':sha(u['text'].encode()),'destination':dest,'rendered_sha256':sha(u['text'].encode()),'transform':'strip-outer-linebreaks','existing_marker':marker,'disposition':'PRESERVED_EXISTING_EXACT_V2_TRANSFER'})
            continue
        with (root/dest).open('a',encoding='utf-8') as f:f.write(f'\n<a id="exchange-{n:02d}"></a>\n## Development {n:02d} — {title}\n\n**Disposition:** {decision}\n')
        for u in [x for x in units if x['exchange']==n]:preserve(root,manifest,u,dest,u['role']+' — '+title,archive_commit)
    st=original[SECONDARY].decode(); sl=st.splitlines(keepends=True)
    boundaries=[i for i,l in enumerate(sl) if re.match(r'^# Part ',l) or re.match(r'^## (?:\d+\.|Turn \d+)',l) or l.startswith('# End of archive') or l.startswith('### Sweet–')]
    if boundaries[0]!=0:boundaries.insert(0,0)
    for k,a in enumerate(boundaries):
        b=boundaries[k+1] if k+1<len(boundaries) else len(sl);text=''.join(sl[a:b]).rstrip('\r\n')
        first=text.splitlines()[0]; dest=MIGRATION
        if first.startswith('### Sweet–Love Interrupted'):dest=HEARING
        elif first.startswith('### Sweet–Ambiguous'):dest=REFUSAL
        elif first.startswith('### Sweet–Love dance'):dest=DANCE
        m=re.match(r'^## (\d+)\.',first)
        if m:
            num=int(m.group(1));dest={1:MIGRATION,2:REL,3:REL,4:WEEK,5:INTIMACY,6:WEEK,7:DEV2,8:DEV2,9:PORTRAIT,10:DANCE}[num]
        m=re.match(r'^## Turn (\d+)',first)
        if m:
            num=int(m.group(1));dest=REFUSAL if num<=3 else (DARK if num<=9 else MIGRATION)
        uid=f'secondary-{k:02d}'
        preserve(root,manifest,{'id':uid,'role':'Secondary archive (reconstructed/normalized, not an independent approval)','a':a,'b':b,'text':text,'source_path':SECONDARY,'source_kind':'repository'},dest,'Secondary record — '+first.lstrip('# '),archive_commit)
    rt=original[OLD+'README.md'].decode()
    preserve(root,manifest,{'id':'legacy-index-contract','role':'Retired workspace contract','a':0,'b':len(rt.splitlines()),'text':rt.rstrip('\r\n'),'source_path':OLD+'README.md','source_kind':'repository'},MIGRATION,'Original audition index and its former lifecycle',archive_commit)
    for pay in payloads:
        obj=pay['object'];args=obj.get('args',obj)
        record={'exchange':pay['exchange'],'start_line':pay['a']+1,'end_line':pay['b'],'sha256':sha(pay['text'].encode()),'disposition':'OPERATIONAL_SOURCE_ONLY; not executed'}
        if isinstance(args.get('content'),str):
            path=args.get('path');data=args['content'].encode();h=blob(data)
            item={'exchange':pay['exchange'],'source_line':pay['a']+1,'target_path':path,'git_blob':h,'bytes':len(data)}
            if path in original and original[path]==data:item.update(disposition='EXACT_DUPLICATE_OF_ACCOUNTED_OWNER',owner=path_map.get(path,path))
            else:
                assert path=='story/01-core-story-bible.md',path
                delta=''.join(difflib.unified_diff(original[path].decode().splitlines(keepends=True),args['content'].splitlines(keepends=True),fromfile=f'current-source/{path}',tofile=f'historical-{h}/{path}'))
                anchor='embedded-'+h[:12]
                with (root/MIGRATION).open('a',encoding='utf-8') as f:
                    f.write(f'\n<a id="{anchor}"></a>\n### Historical Bible candidate {h[:12]}\n\nThis is a superseded text difference in an old tool payload, not an edit applied by this migration. The source baseline remains unchanged except for navigation.\n\n<!-- BEGIN EMBEDDED {h} -->\n````diff\n'+delta+'````\n<!-- END EMBEDDED '+h+' -->\n')
                item.update(disposition='REVERSIBLE_HISTORICAL_DIFF',owner=MIGRATION,anchor=anchor,diff_sha256=sha(delta.encode()),base_blob=blob(original[path]))
            manifest['embedded_payloads'].append(item);record['disposition']='CONTENT_ACCOUNTED_SEPARATELY'
        if isinstance(args.get('body'),str) and len(args['body'])>80:
            u={'id':f'old-pr-body-{pay["a"]+1}','role':'Historical PR description, not current scope','a':pay['a'],'b':pay['b'],'text':args['body'],'source_path':OLD+'Our_PL.md','source_kind':'upload'}
            preserve(root,manifest,u,MIGRATION,'Historical PR #2 publication description',archive_commit)
            manifest['content_units'][-1]['transform']='json-body-field'
            record['disposition']='CONTENT_ACCOUNTED_SEPARATELY'
        manifest['historical_tool_calls'].append(record)
    assert len(manifest['embedded_payloads'])==8
    manifest['path_map']=path_map
    manifest['working_record_anchor_map']=anchor_map
    manifest['protected_current_documents']={p:{'before_sha256':sha(original[p]),'scope':'Existing current passage before Development/secondary evidence; metadata and live links may change, not its dialogue'} for p in [PORTRAIT,DANCE,REFUSAL,DARK]}
    return original,manifest,units,payloads,path_map,anchor_map
