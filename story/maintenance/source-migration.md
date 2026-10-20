# Story consolidation and selective curation

## Narrative-document relocation, 2026-10-20

**Owner request:** consolidate plot, character, craft and other narrative documents from `docs/` and other locations into `story/`, while preparing the requested PR merge. This receipt records the folder work; current merge identity and status come from GitHub.

**Verified baseline:** [7813de0](https://github.com/Siuuuers/dwm/commit/7813de047f5e69b24ea0a84d6857d683f2f0c290). The migration retains **24 complete records** and **one complete narrative-only catalog section** inside `story/`. Exact source Git blobs and SHA-256 values are recorded in the existing [manifest](source-migration.json). The earlier receipts below retain their dated scope.

### What moved

| Original path | Complete story destination |
|---|---|
| `docs/design/2026-09-02-narrative-constitution-ablation-pass-01.md` | [design/reviews/2026-09-02-narrative-constitution-ablation-pass-01.md](../design/reviews/2026-09-02-narrative-constitution-ablation-pass-01.md) |
| `docs/design/2026-09-02-narrative-constitution-working-decision-ledger.md` | [design/2026-09-02-narrative-constitution-working-decision-ledger.md](../design/2026-09-02-narrative-constitution-working-decision-ledger.md) |
| `docs/design/2026-09-02-relationship-progression-runtime-behavior-record.md` | [design/2026-09-02-relationship-progression-runtime-behavior-record.md](../design/2026-09-02-relationship-progression-runtime-behavior-record.md) |
| `docs/design/2026-09-03-priscilla-lavinia-packed-room-ablation.md` | [design/reviews/2026-09-03-priscilla-lavinia-packed-room-ablation.md](../design/reviews/2026-09-03-priscilla-lavinia-packed-room-ablation.md) |
| `docs/design/2026-09-03-sylvia-causation-immediate-ablation.md` | [design/reviews/2026-09-03-sylvia-causation-immediate-ablation.md](../design/reviews/2026-09-03-sylvia-causation-immediate-ablation.md) |
| `docs/design/2026-09-06-angela-absent-pair-explosion-visibility-reconciliation.md` | [design/reviews/2026-09-06-angela-absent-pair-explosion-visibility-reconciliation.md](../design/reviews/2026-09-06-angela-absent-pair-explosion-visibility-reconciliation.md) |
| `docs/design/2026-09-06-narrative-style-manual-sections-1-4-audit.md` | [design/reviews/2026-09-06-narrative-style-manual-sections-1-4-audit.md](../design/reviews/2026-09-06-narrative-style-manual-sections-1-4-audit.md) |
| `docs/design/2026-09-06-narrative-style-manual-sections-12-13-audit.md` | [design/reviews/2026-09-06-narrative-style-manual-sections-12-13-audit.md](../design/reviews/2026-09-06-narrative-style-manual-sections-12-13-audit.md) |
| `docs/design/2026-09-06-narrative-style-manual-sections-5-8-audit.md` | [design/reviews/2026-09-06-narrative-style-manual-sections-5-8-audit.md](../design/reviews/2026-09-06-narrative-style-manual-sections-5-8-audit.md) |
| `docs/design/2026-09-06-narrative-style-manual-sections-9-11-audit.md` | [design/reviews/2026-09-06-narrative-style-manual-sections-9-11-audit.md](../design/reviews/2026-09-06-narrative-style-manual-sections-9-11-audit.md) |
| `docs/design/2026-09-06-post-manual-canon-reconciliation.md` | [design/reviews/2026-09-06-post-manual-canon-reconciliation.md](../design/reviews/2026-09-06-post-manual-canon-reconciliation.md) |
| `docs/design/2026-09-06-priscilla-lavinia-working-event-documentary-audit.md` | [design/reviews/2026-09-06-priscilla-lavinia-working-event-documentary-audit.md](../design/reviews/2026-09-06-priscilla-lavinia-working-event-documentary-audit.md) |
| `docs/design/session-addendum-2026-07-18.md` | [design/session-addendum-2026-07-18.md](../design/session-addendum-2026-07-18.md) |
| `docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md` | [design/2026-08-28-seven-day-two-pass-constellation-design.md](../design/2026-08-28-seven-day-two-pass-constellation-design.md) |
| `docs/superpowers/plans/2026-08-28-seven-day-constellation-documentation-reconciliation.md` | [design/plans/2026-08-28-seven-day-constellation-documentation-reconciliation.md](../design/plans/2026-08-28-seven-day-constellation-documentation-reconciliation.md) |
| `docs/superpowers/specs/2026-08-29-dialogue-led-perceptual-canon-reconciliation-design.md` | [design/2026-08-29-dialogue-led-perceptual-canon-reconciliation-design.md](../design/2026-08-29-dialogue-led-perceptual-canon-reconciliation-design.md) |
| `docs/superpowers/plans/2026-08-29-dialogue-led-perceptual-canon-reconciliation.md` | [design/plans/2026-08-29-dialogue-led-perceptual-canon-reconciliation.md](../design/plans/2026-08-29-dialogue-led-perceptual-canon-reconciliation.md) |
| `docs/research/2026-08-27-room-217-narrative-theory-check.md` | [research/2026-08-27-room-217-narrative-theory-check.md](../research/2026-08-27-room-217-narrative-theory-check.md) |
| `docs/research/2026-08-30-day-2-hong-kong-arrival-weather-and-campus-plausibility.md` | [research/2026-08-30-day-2-hong-kong-arrival-weather-and-campus-plausibility.md](../research/2026-08-30-day-2-hong-kong-arrival-weather-and-campus-plausibility.md) |
| `docs/research/2026-08-30-la-jalousie-steam-store-voice-check.md` | [research/2026-08-30-la-jalousie-steam-store-voice-check.md](../research/2026-08-30-la-jalousie-steam-store-voice-check.md) |
| `docs/research/2026-08-30-room-217-operator-run-sheet-and-cue-pass-plausibility.md` | [research/2026-08-30-room-217-operator-run-sheet-and-cue-pass-plausibility.md](../research/2026-08-30-room-217-operator-run-sheet-and-cue-pass-plausibility.md) |
| `docs/research/2026-08-31-seven-day-candidate-physical-institutional-plausibility.md` | [research/2026-08-31-seven-day-candidate-physical-institutional-plausibility.md](../research/2026-08-31-seven-day-candidate-physical-institutional-plausibility.md) |
| `docs/research/2026-09-06-la-jalousie-unmarked-focal-presence-vn-adaptation.md` | [research/2026-09-06-la-jalousie-unmarked-focal-presence-vn-adaptation.md](../research/2026-09-06-la-jalousie-unmarked-focal-presence-vn-adaptation.md) |
| `dialogic fx.md` | [authoring/dialogic-syntax-reference.md](../authoring/dialogic-syntax-reference.md) |

The full §6 label mapping, namespace distinction, missed-group message rule and English sample copy from `docs/design/recovered/CONTENT.md` now live in [the recovered invitation reference](../library/recovered-group-invitation-copy.md). Its historical calendar and wording status remain visible. The external technical catalog retains the section heading and a forwarding link; its other sections are unchanged.

### Reading and preservation rules

The [design index](../design/README.md) and [research index](../research/README.md) supply task-based routes. The current Bible, Handbook, Style Manual, foundation and scene owners remain the starting point for current work. The constitution ledger keeps mixed confirmed/recommended/open status; the Packed Room supersession stays visible; dated reviews preserve their actual scope and limitations. The September unmarked-perception research retains its bounded accepted application under later viewpoint amendments.

The complete moved bodies are retained. Changes within them are limited to navigation, relative review-source pointers and a dated reading note. Original source URLs remain pinned to the path and revision that existed then. Historical approval dates and hashes still describe their original transaction, not the relocated bytes or a new implementation authorization. The old paths contain forwarding notes with the original heading bookmarks, so existing links continue to reach the relevant sections.

Current story links point directly to their new owners. The source records were moved rather than copied into a second active Bible. No day manuscript prose, selected event, character fact, cause, ending, runtime file or protected archive branch is changed by this relocation. The raw-history and P–L bar/residue/residence holds remain open.

### Why some records remain outside story

The [engineering boundary map](../design/README.md#story-facing-engineering-boundary) makes the remaining technical and platform owners discoverable from `story/`. The registered August 7 flow specification has literal registry/validator/test dependencies; typed requirement packets are discovered under `prompt_docs/`. SupportZ, recovered API/flow/asset contracts and implementation plans retain engineering responsibilities. Platform copy and submission packages keep their own approval and release gates. The narrative-only catalog section was extracted without moving these technical owners.

No `tests/templates/scene_sequence/AUTHOR_GUIDE.md` exists in the source tree at7813de0; a guide on another branch keeps that separate scope. The relocated legacy syntax examples do not become a new current label contract, and the retired eight-master generator is not an authoring step.

### Verification scope

The bounded checks cover exact pre-move source identity; full-body and extracted-section retention; original heading bookmarks; rebased relative Markdown links and review-source metadata; current entry points; and the identified technical path dependencies. Exact content readback and fresh PR metadata are required for publication reporting. The older verifier's `--snapshot` mode describes a prior curation freeze and is not rerun as a restriction on this authorized move.

The existing scene prose is unchanged; this is not a new whole-day or whole-week performance review. External sources, performed timing, runtime behavior, the entire technical documentation suite and missing historical conversations were **NOT RUN / not newly audited**. Source classification and navigation checks do not close those separate tasks.

## Current story consolidation, 2026-10-20

**Owner request:** update Day 3 with the accepted Sylvia notice manner, integrate useful conversation and audition development into the bibles, and make `story/` a clearer working home. Existing permission covers editing and publication in PR #41; this request does not ask for a merge.

**Verified source baseline:** [f1df045](https://github.com/Siuuuers/dwm/commit/f1df045a840a79ef9c728f46a03ecce7877f96c9). The consolidation uses the visible conversation, current owners and relevant passages in retained development/design records. All 47 fetched source files were checked against the baseline Git tree. Fetch coverage is not a claim that every historical paragraph or missing raw chat was audited.

### Disposition of the current material

| Material | Current home | What changed and what retains its scope |
|---|---|---|
| Durable character and relationship direction | [Bible](../01-core-story-bible.md), [Handbook](../02-character-relationship-handbook.md), [P–L relationship](../relationships/priscilla-lavinia/relationship.md) | Integrated Sylvia's occasional notices and current performance/knowledge guidance. Existing Priscilla judgment, Lavinia and Sylvia triangle facts keep their approval boundaries. The exact transferred Handbook pair block is retained. |
| Reusable craft from the conversation and auditions | [Style Manual](../08-narrative-style-manual.md) | Integrated field placement, flexible grammatical person, participant attention, useful props/habits, changed recurrence and bounded intensity review into existing sections. A local preference is not a new universal scene quota. |
| Current narrative and intended flow | [Foundation09](../09-priscilla-foundation-amendment.md) | Current flow semantics and implementation handoff are consolidated here. First/later awareness, A–E meaning, unavailable-board accounting and the P–L ending exception retain their approved scope. The older explicit hidden-at-start direction is integrated with exact provenance. |
| Former external current-flow document | [Compatibility entry](../../docs/design/2026-10-09-priscilla-flow-behavior-amendment.md) | Retains original headings/anchors and points to09. [The full previous contract](https://github.com/Siuuuers/dwm/blob/f1df045a840a79ef9c728f46a03ecce7877f96c9/docs/design/2026-10-09-priscilla-flow-behavior-amendment.md) remains in Git. Unaffected technical owners remain where they are. |
| Current reading routes | [Story home](../README.md), [audition index](../auditions/README.md), [pair home](../relationships/priscilla-lavinia/README.md) | Replace repeated chronological restart prose with task routes, source ownership and current/retained scope. Keep existing paths. |
| Week checkpoints and open possibilities | [Working map](../auditions/priscilla-seven-day-working-plot.md) | Curate status, actual carry, distinct climax/motive/anomaly candidates and source limits. Preserve earlier full checkpoints at f1df045 and their old heading bookmarks. |
| Day 3 | [Current manuscript](../auditions/day-3-sylvia-fork-working-draft.md) | The audience change is “What have you written?” → “Another notice?” A private note keeps the earlier coffee example and later discrepancies unselected; counts adjust by two words. The two authored/one reachable fork architecture is unchanged. |
| Earlier production/map records | [03](../03-seven-day-production-map.md), [05](../05-canon-amendments-2026-07-19.md), [06](../06-seven-day-scene-beatbook.md), [07](../07-seven-day-causal-matrix.md) | Add current-foundation reading boundaries; preserve the schema, dated records, compatible protected facts and approval scopes. No new placement is selected. |
| Existing day manuscripts, distinct retained auditions and source archives | Their existing owners and Git versions | No Day 1/2 prose change or new archive hierarchy is needed. Historical variants are not concatenated into current events. The protected archive branch remains. |

The reading routes now give current narrative work a home inside `story/`. They do not attempt to move every engineering record, duplicate every audition into a bible or reproduce raw conversations. The existing [manifest](source-migration.json) records this operation alongside the earlier curation; no additional rules ledger is created.

### Exact predecessors and compatibility

| Prior working document | Exact pre-consolidation version |
|---|---|
| Story entry | [f1df045 story/README](https://github.com/Siuuuers/dwm/blob/f1df045a840a79ef9c728f46a03ecce7877f96c9/story/README.md) |
| Pair entry | [f1df045 pair/README](https://github.com/Siuuuers/dwm/blob/f1df045a840a79ef9c728f46a03ecce7877f96c9/story/relationships/priscilla-lavinia/README.md) |
| Week checkpoint | [f1df045 complete checkpoint](https://github.com/Siuuuers/dwm/blob/f1df045a840a79ef9c728f46a03ecce7877f96c9/story/auditions/priscilla-seven-day-working-plot.md) |
| Audition index | [f1df045 audition index](https://github.com/Siuuuers/dwm/blob/f1df045a840a79ef9c728f46a03ecce7877f96c9/story/auditions/README.md) |
| Day 3 | [f1df045 full reading and review](https://github.com/Siuuuers/dwm/blob/f1df045a840a79ef9c728f46a03ecce7877f96c9/story/auditions/day-3-sylvia-fork-working-draft.md) |

Old headings removed from the three long entry/checkpoint files remain explicit historical bookmarks in collapsible source tables. An old subsection bookmark leads to its containing original section. This preserves a route to the dated claim without pretending the new current paragraph is the source of that older decision. Existing headings in the audition index and external flow entry remain available.

### Review and remaining limits

The bounded review compares current character, flow and style owners with the useful conversation/checkpoint decisions, then checks the changed Day 3 opening, author note and fork entrances. The original Sections 1–5 audience body is unchanged except for the two-word substitution. The former full-family review remains attributed to its own inspected revision; it is not recertified as a new performance study.

The normal consolidation verifier checks current relative links against the verified repository tree. The older `--snapshot` option validates its historical curation freeze, not an obligation to keep every later-authorized paragraph unchanged. Publication requires an exact content readback of the changed files and branch/PR metadata; the source prose itself cannot assert success.

The remaining Day 1–2 intakes, full Day 3/week, ending joins, sustained Sylvia plot and complete DTL remain open. Missing earlier raw history, the remembered unrecovered openings and the protected bar/residue/residence questions are not reconstructed by this curation. No audience, performed timing, social-media, medical, runtime or complete historical audit is claimed.

## Retained 2026-10-01 curation receipt

The receipt below describes the earlier operation. Its named approvals, publication
plans and validation claims retain that historical scope.

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
