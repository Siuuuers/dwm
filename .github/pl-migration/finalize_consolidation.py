"""Final navigation and safe retirement, after byte-coverage checks."""
from pathlib import Path
import json, re, posixpath, shutil
import build_consolidation as b
ARCHIVE='62fd8bf3966e4df7e03bf52952c6905284845284'
ROOT_GUIDE='''# DWM repository working routes

For implementation, build and test work, read [CLAUDE.md](CLAUDE.md) and the
applicable technical design records. This router does not replace those rules.

For narrative, character, dialogue, or story-documentation work, read
[story/AGENTS.md](story/AGENTS.md) and [story/README.md](story/README.md), even when a
linked technical or historical record lives elsewhere. For Priscilla–Lavinia work,
also read [the local guide](story/relationships/priscilla-lavinia/AGENTS.md) and
[working home](story/relationships/priscilla-lavinia/README.md).

Read the target and its relevant dependencies, not every source on every task.
Current owners use checkout-relative links; historical evidence uses exact Git
revisions. Moving or saving material does not approve canon, placement, mechanics,
commit/push/merge, or deletion outside the authorized task. Raw source snapshots
are retained on the documented archive branch; do not delete it as a feature branch.
'''
STORY_INDEX='''# Story workspace

**Narrative working home.** The legacy audition directory has been consolidated
here. This directory includes current narrative authorities, retained auditions,
and attributed development evidence; its location is not a canon stamp.

| Question | Start here |
|---|---|
| Fixed fictional truth and history | [Core Story Bible](01-core-story-bible.md) |
| Individual characters and other relationships | [Character & Relationship Handbook](02-character-relationship-handbook.md) |
| Priscilla–Lavinia relationship and current candidates | [P–L working home](relationships/priscilla-lavinia/README.md) |
| Shared, other-pair and whole-week auditions | [Audition index](auditions/README.md) |
| Windows, occurrence and selection | [Seven-Day Causal Matrix](07-seven-day-causal-matrix.md) |
| Approved scene expansion | [Scene Beatbook](06-seven-day-scene-beatbook.md) |
| Style, perception and review | [Narrative Style Manual](08-narrative-style-manual.md) |
| Authoring and four-exchange capture | [Narrative guide](AGENTS.md) |
| Source provenance and preservation checks | [Migration receipt](maintenance/source-migration.md) |

The existing lifecycle remains `UNSELECTED → AUDITIONING → SELECTED FOR APPROVAL →
APPROVED`, with `REOPENED` where applicable. Retained designs, local preferences,
reaction tests and audition verdicts are not interchangeable with approval of
history, complete scenes, placement or runtime behavior. Room 2.17 keeps its
bounded approved-but-unplaced core; its adaptations and placement remain distinct.

## How to work without rereading the entire archive

Open the requested current passage, then its development notes when a decision
needs review. Exact historical excerpts are folded below the topic they explain;
questions, stated reasons, alternative versions and unresolved continuations have
not been discarded. They are evidence to interpret, not live instructions.

Fixed history remains in the Bible. The Handbook retains individual dossiers;
its P–L pair section is transferred unchanged into the pair's relationship owner,
with a backpointer at the old heading. Technical behavior records remain under
`docs/design/`; their live story links are repaired, not their mechanics rewritten.

## Consolidation checkpoint — 2026-10-01

All 50 exchanges of the supplied export have attributed prose destinations.
Nine distinct auditions are relocated, the thematic checkpoint and secondary
archive are distributed by topic, and the old source directory is absent from
this working tree. Both exact transcript snapshots remain retrievable in retained
Git history. See [the exchange map](maintenance/our-pl-upload-recovery.md) for
coverage and [the verification program](maintenance/verify_consolidation.py) for
reproducible integrity checks.

This is a documentation checkpoint on PR #3, not a claim that `master` has already
changed or that the whole story passed review. No scene winner, new intimate
history, injury, calendar placement or code behavior is selected by migration.
Earlier missing bar/residue evidence remains an explicit narrative hold.
'''
PAIR_INDEX='''# Priscilla–Lavinia — working home

**Status:** consolidated relationship workspace, not a second Bible or a completed
seven-day plot. Start with the current question; unfold development evidence only
when it matters to the task. Scene candidates remain `UNSELECTED` / `REACTION TEST`.

| Work | Owner | Boundary |
|---|---|---|
| Established pair guidance and attraction | [Relationship](relationship.md) | Handbook pair section transferred unchanged; Bible still owns history |
| Ordinary company, intimacy and possible partnership | [Intimacy and ordinary company](intimacy-and-ordinary-company.md) | Unplaced exploration, not a newly selected sexual history |
| Early contact, jealousy carriers, Day 6 and ending options | [Seven-day options](seven-day-options.md) | Proposals are distinct from current Matrix and runtime rules |
| Day 2 bar-to-portrait development | [Development](auditions/day-2-portrait-development.md) | Whole alternatives, local revisions and unresolved transitions |
| Day 2 Sweet–Love | [Portrait and coat](auditions/day-2-sweet-love-portrait.md) | Complete earlier reading plus separate later refinements; no false composite |
| Day 2 Dark–Love | [Retained portrait read-through](auditions/2026-09-26-priscilla-lavinia-day-2-portrait-dark-love-read-through.md) | Strike transition, physical staging and family review remain open |
| Day 6 Sweet–Love dance | [Another way to listen](auditions/day-6-sweet-love-dance.md) | Indirect invitation, familiar teasing, continued company |
| Day 6 Sweet–Ambiguous | [Imagined refusal and tea](auditions/day-6-sweet-ambiguous-refusal.md) | Reciprocal imitation; Sweet keeps the “much” exchange |
| Day 6 Dark–Love | [The kept page](auditions/day-6-dark-notebook.md) | Current notebook proposal, selective sharing, intrusion and open aftermath |
| Source coverage and originals | [Exchange map](../../maintenance/our-pl-upload-recovery.md) | 50 supplied exchanges accounted for; earlier absent sources not invented |

## Retained alternatives and baseline functions

The [early Day 2 / Day 6 event record](auditions/2026-09-06-priscilla-lavinia-day-2-day-6-working-event-record.md),
[four-form baseline](auditions/2026-09-06-priscilla-lavinia-day-2-four-form-causal-spine-audition.md),
[shorter imagined-refusal record](auditions/2026-09-06-priscilla-lavinia-day-6-sweet-imagined-refusal-audition.md),
and [Interrupted Hearing](auditions/2026-09-07-priscilla-lavinia-day-6-sweet-love-interrupted-hearing-audition.md)
retain their exact local status and distinct constructions. The dance did not
silently replace the hearing. Earlier Dark departure and false-repentance
experiments are preserved in the notebook's development history, not appended to
its current encounter. The [Day 1 retrospective reflex](auditions/2026-09-12-day-1-priscilla-lavinia-retrospective-reflex-audition.md)
remains available independently of Day 6.

The former portrait/intimacy checkpoint is [mapped into its topic owners](relationship.md#legacy-checkpoint-map).
The [shared audition index](../../auditions/README.md) owns Angela–Lavinia, Room 2.17
Group and whole-week material. Angela is not absorbed into this private bond.

## The next narrative decisions are still narrative decisions

Day 2 is not a completed four-form family. Integrating its Sweet–Love refinements,
earning or replacing the Dark strike, and treating the Ambiguous and Group forms
remain separate work. Day 6 must inherit what actually occurred, not whatever the
audience happened to see. The notebook's motivation and consequence need a complete
encounter review, not another automatic romantic milestone.

Read the [Matrix](../../07-seven-day-causal-matrix.md) for current placement and the
[future-behavior record](../../../docs/design/2026-09-02-relationship-progression-runtime-behavior-record.md#2026-09-26-conditional-day-6-and-one-meeting-ending-proposal)
for the conditional tea/Room 2.17 and Day-6-only ending proposal. Neither mechanics
nor invitation suppression changes merely because the proposal is preserved.

## Capture checkpoint — 2026-10-01

**Coverage:** all 50 exported exchanges' substantive author/assistant prose,
including E23–26's previously verified exact capture; all 13 legacy-directory
files; meaningful historical write payloads; and the later chat decisions already
in the current Day 6 passages. **Destination:** PR #3's documentation branch,
subject to the publication receipt. Count subsequent substantive exchanges from
the verified checkpoint; four is a normal capture cadence, not a processing cap.

**Not settled:** original-source gaps predating this export, scene selection,
physical/medical staging, audio/performance, full-family or whole-week approval,
runtime behavior, and merge into master. Current narrative prose is preserved;
this migration does not supply new kisses, remorse, residence rights or injuries.

**Archive:** the exact originals are linked in [migration provenance](../../maintenance/source-migration.md).
The old active directory is retired, not replaced by a second transcript folder.
Historical citations and commands inside quoted evidence remain historical.
'''
PAIR_GUIDE='''# Priscilla–Lavinia working route

Read the [general narrative guide](../../AGENTS.md), this folder's
[entry point](README.md), and the requested owning passage. This local guide
narrows navigation; it does not add a new personality rule or select an event.

Recover the day, actual incoming occurrence, variant, viewpoint and current
candidate before continuing a scene. Dance, imagined refusal and notebook are
alternatives, not consecutive parts of one date. Use their development sections
to recover a local choice. The relationship owner holds the exact transferred
Handbook pair section; the Bible and individual dossiers keep their authority.

Use the normal four-substantive-exchange checkpoint. Current scene text comes
before historical development; preserve questions, stated reasons and meaningful
alternatives without creating a file or journal entry per turn. The compact
capture status is in README.md. Saving a proposal is not approval of it.

Exact originals live at the retained Git revisions in the provenance map. Read
them when the current topic leaves an evidence question unresolved, not before
every small revision. The completed document migration does not close older
missing-history or narrative-selection holds. No push or merge permission is
inferred from the existence of these instructions.
'''
AUD_INDEX='''# Auditions — shared and whole-week work

**Status:** noncanonical working material with each record's existing qualifications.
The workspace moved; its designs did not become canon by changing paths.

| Scope | Retained record |
|---|---|
| Angela–Lavinia Day 2 | [Focus audition](2026-08-30-angela-lavinia-day-2-focus-audition-design.md) |
| Room 2.17, including Group participation | [Adaptation record](2026-08-30-room-217-group-adaptation-audition-record.md) |
| Full seven-day comparison | [Owner-review constellation](2026-08-31-seven-day-owner-review-constellation-audition.md) |
| Priscilla–Lavinia current and retained candidates | [Pair working home](../relationships/priscilla-lavinia/README.md) |

## Authority and disposition

An owner-approved audition design is retained for comparison; it is not selected
placement, canon, final DTL or implementation authorization. A coherent recommended
candidate is not an owner decision. Reaction tests remain writer-facing until
explicitly promoted under the existing process.

Whole-day or whole-constellation review tests coexistence, absence, knowledge,
mechanics, physical law and cross-day residue. Ordinary promotion requires explicit
owner approval and an `APPROVED` [Matrix](../07-seven-day-causal-matrix.md) row before
[Beatbook](../06-seven-day-scene-beatbook.md) expansion. Room 2.17's existing approved-
but-unplaced core is the bounded exception, not permission to place or expand it.
The [Bible](../01-core-story-bible.md) remains narrative authority for durable truth.

Preserve the reasons for a revision or rejection in the record that owns it.
A shared record must not become private material plus an Angela bonus. Keep
actual occurrence distinct from access, and changed narrative hypotheses distinct
from implemented behavior. A missing scene cannot be recreated merely to deliver
an expected clue.

The former temporary-workspace policy is organizationally superseded by the
owner-requested consolidation. Its exact contract and all source dispositions
remain in [migration provenance](../maintenance/source-migration.md). No new code,
assets, localization, stable line IDs or scene selection are authorized by this
index. Unresolved narrative questions stay unresolved in their new documents.
'''

def live_transform(text, fn):
    return ''.join(fn(c) if i%2==0 else c for i,c in enumerate(b.markdown_chunks(text)))

def finalize(root:Path,original:dict,manifest:dict, archive_commit:str):
    assert archive_commit==ARCHIVE
    for path,text in {'AGENTS.md':ROOT_GUIDE,'story/README.md':STORY_INDEX,
      b.PAIR+'README.md':PAIR_INDEX,b.PAIR+'AGENTS.md':PAIR_GUIDE,'story/auditions/README.md':AUD_INDEX}.items():
        p=root/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8')
    p=root/'story/AGENTS.md';t=p.read_text()
    t=t.replace('existing canon and audition owners remain authoritative pending migration','pair guidance is delegated explicitly; canon and selection status remain distinct')
    t=t.replace('`story/02-character-relationship-handbook.md` |','`story/02-character-relationship-handbook.md`; P–L pair guidance in `story/relationships/priscilla-lavinia/relationship.md` |',1)
    t=t.replace('The Production Map is derived;', 'Current auditions live under `story/`; raw originals are retained at the exact Git\nrevisions in `story/maintenance/source-migration.md`. Relocation and extraction do\nnot change approval scope. Current owners use checkout-relative links; historical\nevidence uses version-specific links.\n\nThe Production Map is derived;',1)
    p.write_text(t)
    p=root/b.PORTRAIT;t=p.read_text()
    for n in range(23,27):t=t.replace(f'<details>\n<summary>Exchange {n}',f'<a id="exchange-{n:02d}"></a>\n<details>\n<summary>Exchange {n}',1)
    t=t.replace('It does not replace the Bible, the Handbook, the dated four-form baseline, or the separate Dark–Love read-through.','It does not replace the Bible, individual Handbook dossiers, the retained four-form baseline, or the separate Dark–Love read-through.')
    t=t.replace('The source upload is not byte-identical to the Git blob recorded by the previous package.','The two exact snapshots differ only in the opening greeting/workflow request and final newline; their story discussion matches.')
    t=t.replace('The full uploaded source remains intact outside this overlay; source retirement is still blocked.','The full uploaded source remains retrievable in the retained Git archive; the active transcript container is retired after preservation checks.')
    t=t.replace('**NOT RUN:** integration as a new final scene, full-family comparison, full 50-exchange content reconciliation, all-13-file migration, live Git verification, remote writes, physical staging, audio, or runtime tests.','The whole supplied-source preservation map is in the migration receipt. **NOT RUN:** integration as a new final scene, full-family review, earlier missing-history closure, physical staging, audio, or runtime tests.')
    p.write_text(t)
    replacements={
      b.DANCE:[('Exact original archive alignment and complete chronological review remain pending. No repository scene or final DTL was changed.','Exact source exchanges are now preserved below and mapped in the migration receipt. The earlier missing-history and narrative-selection holds remain. No final DTL was selected.')],
      b.REFUSAL:[('The full `Our_PL.md` has not been extracted. Earlier superseded versions remain to be mapped completely before source retirement. No source is deleted by this document.','All supplied exchanges now have exact prose destinations below or in their topic owner. The original transcript is retained in Git; current scene selection and older missing-source questions remain open.')],
      b.DARK:[('The original archives, intermediate exact passages, and chronological approval contexts remain to be fully mapped before deletion. This bounded development history preserves distinctive visible alternatives and their reasons without pretending to be that entire audit.','The supplied archives and intermediate passages are now mapped and preserved below or in their topic owners. This documents their development without closing an earlier missing-source audit or promoting their approval scope.')]
    }
    for path,pairs in replacements.items():
        p=root/path;t=p.read_text()
        for old,new in pairs:
            assert old in t,(path,old)
            t=live_transform(t,lambda c,o=old,n=new:c.replace(o,n))
        p.write_text(t)
    p=root/b.REL;t=p.read_text();a=t.index('## 1.');z=t.index('\n## 2.',a)
    lead=t[a:z]
    def remap_snapshot(m):
        old=m.group(1);frag=m.group(2) or ''
        dest=manifest['path_map'].get(old,old)
        if old==b.WORKING:return posixpath.relpath(b.REL,posixpath.dirname(b.REL))+'#legacy-checkpoint-map'
        return posixpath.relpath(dest,posixpath.dirname(b.REL))+frag
    lead=re.sub(r'https://github\.com/Siuuuers/dwm/blob/[0-9a-f]{40}/([^\s)#]+)(#[^\s)]*)?',remap_snapshot,lead)
    lead=lead.replace('[Handbook, Priscilla–Lavinia section](../../02-character-relationship-handbook.md#priscillalavinia)','[Established pair guidance](#established-pair-guidance)')
    t=t[:a]+lead+t[z:];p.write_text(t)
    for path,links in {
      b.DANCE:[('Retained hearing',b.HEARING)],
      b.REFUSAL:[('Retained shorter refusal',b.MOVED['2026-09-06-priscilla-lavinia-day-6-sweet-imagined-refusal-audition.md'])],
      b.DARK:[('Retained earlier event record',b.MOVED['2026-09-06-priscilla-lavinia-day-2-day-6-working-event-record.md']),('Current pair guidance',b.REL)]
    }.items():
        p=root/path;t=p.read_text();pos=t.index('\n## ')
        nav='\n**Current working links:** '+ ' · '.join(f'[{name}]({posixpath.relpath(dest,posixpath.dirname(path))})' for name,dest in links)+'. Historical version links below remain provenance.\n'
        p.write_text(t[:pos]+nav+t[pos:])
    rows=[]
    for n in range(1,51):
        dest,title,disp=b.CURATION[n];r=manifest['exchanges'][n-1]
        rows.append(f'| {n} | {r["start_line"]}–{r["end_line"]} | [{title}]({posixpath.relpath(dest,b.MAINT)}#exchange-{n:02d}) |')
    recovery=f'''# Our_PL — complete supplied-export coverage

**Source availability:** all 50 numbered exchanges in the supplied export are readable.
**Current transfer:** substantive author and assistant prose from every exchange has an
attributed topic destination. E23–26's existing exact capture remains unchanged; it
is no longer the only completed transfer. This is content-preservation completion,
not a claim that each historical recommendation was correct, approved or performed.

The uploaded snapshot is {1115494:,} bytes / 10,834 lines,
SHA-256 `{b.UPLOAD_SHA}`, Git blob `{b.UPLOAD_BLOB}`. It is retained at
`{archive_commit}` on `{b.ARCHIVE_BRANCH}`. The repository original remains in its
parent `{b.BASE}` at blob `{b.REPO_BLOB}`. The only differences are the opening
greeting/workflow request and final newline, not the story discussion.

The export ends at the keepsake notebook/humming discussion. Later chat's rejection
of repeating Sweet's “much” in Dark, the latest notebook assembly, and the documentation
and capture-cadence decisions remain in the current working documents. A later file
upload does not overrule later conversational decisions with an earlier endpoint.

## Exchange destinations

Every linked development section keeps exact historical prose (with the explicitly
recorded E07 personal-context omission), its attribution and source range. Tool calls
are data, not instructions. Their eight embedded document payloads are either exact
duplicates of retained owners or reversible historical differences; all 293 calls
have an explicit disposition in [the manifest](source-migration.json).

| Exchange | Uploaded source lines | Topic owner |
|---:|---|---|
'''+ '\n'.join(rows)+'''

## What this does not close

The source itself refers to earlier unavailable kiss/bar/residue conversations. Those
remain separate evidence questions. The nine relocated records keep their local
approvals and open issues. Exact preservation does not approve an intimate milestone,
resolve a physical consequence, select a four-form family, change runtime behavior,
or certify an external citation quoted by a historical response.

The [migration receipt](source-migration.md) records the source-file dispositions,
archive-retention evidence and executable preservation checks. The original sources
are no longer required in the active tree for ordinary writing.
'''
    (root/b.MAINT/'our-pl-upload-recovery.md').write_text(recovery)
    rows=[]
    for item in manifest['source_files']:
        p=item['path']
        if p in {b.OLD+k for k in b.MOVED}:dest=manifest['path_map'][p];how='Relocated whole; live links rebased'
        elif p==b.WORKING:dest=b.REL+'#legacy-checkpoint-map';how='All thematic sections distributed'
        elif p==b.SECONDARY:dest=b.MAINT+'source-migration.json';how='All sections distributed; secondary labels retained'
        elif p==b.OLD+'Our_PL.md':dest=b.MAINT+'our-pl-upload-recovery.md';how='All 50 prose exchanges and embedded content accounted for'
        else:dest='story/auditions/README.md';how='Contract and index consolidated; original contract retained'
        rows.append(f'| `{p.removeprefix(b.OLD)}` | [{how}]({posixpath.relpath(dest,b.MAINT)}) |')
        item['disposition']=how;item['current_destination']=dest;item['source_retirement_allowed']=True
    p=root/b.MIGRATION;t=p.read_text();pos=t.index('\n## Earlier checkpoint decisions')
    t=t[:pos]+'''\n## Source-file disposition

All 13 tracked source paths are accounted for. No old-directory redirect or raw-source
replacement folder remains. Distinct auditions stay coherent; overlapping thematic
records have one topic map. Historical old-path URLs are evidence, not active routes.

| Original file | Preserved destination/disposition |
|---|---|
'''+ '\n'.join(rows)+'''\n
## Technical limits and publication

A temporary read-only export first hit an unrelated malformed submodule during
checkout, then an incorrect assumed root README path. Both failures were visible;
neither was repaired by changing game/submodule files. A pinned plain-Git source
export succeeded. The exact source snapshots were then retained on the archive
branch and checked by hash. Temporary export/migration helpers are removed before
final PR review; their historical runs are not narrative or runtime validation.

The normal checkpoint is four substantive exchanges, with earlier capture for a
substantial build. This migration is such a build. No automatic merge follows.
The reproducible integrity report states the exact checked tree and any remaining
limits; the full plot, medical staging and independent artistic review are NOT RUN.
'''+t[pos:]
    p.write_text(t)
    p=root/'docs/design/2026-09-06-angela-absent-pair-explosion-visibility-reconciliation.md'
    t=p.read_text().replace('#10-current-revision--a-brief-post-clear-local-burst','#10-superseded-short-burst-proposal');p.write_text(t)
    p=root/'story/library/03-seven-day-plot-material-library.md'
    t=p.read_text().replace('](06-seven-day-scene-beatbook.md)','](../06-seven-day-scene-beatbook.md)');p.write_text(t)
    manifest['documentation_consolidation_complete']=True
    manifest['source_retirement_allowed']=True
    manifest['retention_verified_against']='archive branch and exact blob checks; see PR source-archive run'
    manifest['scope']='All supplied source prose preserved/routed; no claim of full pre-export historical or artistic audit'
    manifest['file_disposition_complete']=len(rows)==13
    for moved in manifest['file_moves']:moved['destination_sha256']=b.sha((root/moved['destination']).read_bytes())
    manifest['root_guide_added']=True
    manifest['existing_scene_prose_changed']=False
    return manifest
