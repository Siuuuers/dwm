# Narrative design and decision records

Start with the [current Priscilla foundation and flow](../09-priscilla-foundation-amendment.md), the relevant [Bible](../01-core-story-bible.md), [Handbook](../02-character-relationship-handbook.md) or [Style Manual](../08-narrative-style-manual.md), and the scene being written. This directory keeps the decisions, alternatives and review evidence that support those owners.

These records moved into `story/` on 2026-10-20. Each retains its original approval, proposal, reopening and review scope. An older instruction remains subject to later explicit decisions. The move does not restore Angela, the previous calendar, four compulsory forms or the old explosion-access cutoff to the current chapter.

## Decisions and authoring method

| Record | Use and boundary |
|---|---|
| [Narrative Constitution working decision ledger](2026-09-02-narrative-constitution-working-decision-ledger.md) | Recover an earlier decision and its rationale. Owner-confirmed, recommended, open and superseded entries remain distinct; this is not a second current Bible. |
| [Relationship progression and future behavior](2026-09-02-relationship-progression-runtime-behavior-record.md) | Preserve compatible intended behavior and known implementation debt. Reconcile named conflicts against the current foundation before code work. The unselected September 26 proposal remains a proposal. |
| [Two-Pass Constellation](2026-08-28-seven-day-two-pass-constellation-design.md) | The approved method for a whole-week obligation framework followed by meaningful scene auditions. Apply it to the current chapter; its old calendar examples do not fix the new week. |
| [Dialogue-led perceptual reconciliation](2026-08-29-dialogue-led-perceptual-canon-reconciliation-design.md) | Recover the approval and reasoning for sparse character-bound perception. Current sole-Priscilla viewpoint and self-talk rules are in the foundation and Style Manual. |
| [July 18 design-session addendum](session-addendum-2026-07-18.md) | Retained early story and meta-horror concepts, with their original exploratory and confirmed scopes. Later amendments supersede conflicting mechanisms and casting. |

## Earlier reviews

Read a review when its particular decision or omission matters. A completed documentary or craft review does not approve every example it discusses, certify the whole story, or close an explicitly open history audit.

| Review | What to preserve when using it |
|---|---|
| [Constitution ablation](reviews/2026-09-02-narrative-constitution-ablation-pass-01.md) | The distinctions and scoped repairs that survived the recorded removal test. |
| [P–L Packed Room ablation](reviews/2026-09-03-priscilla-lavinia-packed-room-ablation.md) | Its explicit supersession by access without residence; the room/move-out carrier is not approved history. |
| [Sylvia causation ablation](reviews/2026-09-03-sylvia-causation-immediate-ablation.md) | The historical Angela-collapse question and its bounded decision. Do not invent a corresponding Priscilla incident. |
| [Style §§1–4](reviews/2026-09-06-narrative-style-manual-sections-1-4-audit.md), [§§5–8](reviews/2026-09-06-narrative-style-manual-sections-5-8-audit.md), [§§9–11](reviews/2026-09-06-narrative-style-manual-sections-9-11-audit.md), [§§12–13](reviews/2026-09-06-narrative-style-manual-sections-12-13-audit.md) | The actual inspected sections, repairs and same-context review limitations. |
| [Post-manual reconciliation](reviews/2026-09-06-post-manual-canon-reconciliation.md) | Its bounded repairs and deliberately open migrations. |
| [P–L working-event documentary audit](reviews/2026-09-06-priscilla-lavinia-working-event-documentary-audit.md) | The difference between a retained fresh audition and historical or whole-event approval. |
| [Angela-absent explosion visibility receipt](reviews/2026-09-06-angela-absent-pair-explosion-visibility-reconciliation.md) | Evidence of the earlier cutoff correction. The current foundation supersedes that cutoff for the Priscilla chapter. |

## Historical documentation plans

The [August 28 constellation reconciliation plan](plans/2026-08-28-seven-day-constellation-documentation-reconciliation.md) and [August 29 perceptual reconciliation plan](plans/2026-08-29-dialogue-led-perceptual-canon-reconciliation.md) record the bounded documentation work that produced earlier revisions. Their old execution instructions, exact paths, branch restrictions and approval hashes belong to those transactions. They are available as evidence; they are not a new work queue or permission to rerun the plans.

## Story-facing engineering boundary

The current story-facing rules are available inside `story/`: foundation09 owns chapter flow, the later Yes/default relationship thought, private thoughts, local Challenge results, awareness and ending scope. The Bible and Style Manual own meaning and presentation; this directory preserves compatible future behavior and decision evidence.

Some documents remain with engineering because their actual responsibility is an API, validator, save format, UI implementation or release procedure. This map makes them discoverable from `story/` when that work is needed.

| Need | Current story entry | Technical or platform record |
|---|---|---|
| Chapter sequence, presentation fields and Challenge continuations | [Foundation and intended flow](../09-priscilla-foundation-amendment.md) | [August 7 baseline flow contract](../../docs/design/2026-08-07-seven-day-dialogic-flow-design.md), only where compatible with later decisions |
| Scene-file authoring and illustrative syntax | [Legacy syntax reference](../authoring/dialogic-syntax-reference.md); use the current foundation for field/result meaning | [Recovered Dialogic contract](../../docs/design/recovered/DIALOGIC.md) and [manual preview guide](../../tests/manual/dialogic_preview/README.md), under their own recorded scope |
| Relationship response, evidence, replay and ending evaluation | [Future-behavior record](2026-09-02-relationship-progression-runtime-behavior-record.md) | [Requirement packets](../../prompt_docs/INDEX.md) and their linked implementation owners |
| Earlier group-invitation wording and label meaning | [Retained full narrative section](../library/recovered-group-invitation-copy.md) | [Recovered catalog](../../docs/design/recovered/CONTENT.md) keeps the data, asset and engine references |
| SupportZ eligibility, receipts and save/load remapping | Current foundation first; the older mechanism is not a new chapter requirement | [SupportZ mechanism amendment](../../docs/design/2026-08-30-supportz-audience-priority-three-truth-mechanism-amendment.md) |
| Public presentation and platform submission | [Public project profile](../04-public-project-profile.md) and [literary copy research](../research/2026-08-30-la-jalousie-steam-store-voice-check.md) | [Locked Steam copy design](../../docs/superpowers/specs/2026-08-30-steam-store-page-design.md) and [submission package](../../docs/shipping/2026-08-30-steamworks-store-presence-submission-package.md), with their dated approval/publication gates |

The August 7 source is registered by the documentation authority tooling and read by a dedicated test. Its engineering path stays in place. Moving story records does not demonstrate that any intended behavior is implemented, validate old runtime descriptions as current, or authorize platform publication.

The current tree at the migration source revision does not contain `tests/templates/scene_sequence/AUTHOR_GUIDE.md`; references to that guide on another branch retain their stated branch scope. The retained syntax examples do not supply a replacement approved label contract. Complete DTL production still follows the whole-week plot gate.

See [the relocation receipt](../maintenance/source-migration.md#narrative-document-relocation-2026-10-20) for the exact source revision, all destinations and verification limits.
