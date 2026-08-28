# Seven-Day Production Map

## Derived Authority and Entry Condition

This Map is a derived, plot-neutral production template. The August design
supplies mechanics; the Core Story Bible supplies narrative canon; and the
Character & Relationship Handbook supplies performance guidance. Those sources
outrank this Map whenever their authority applies.

A production card may be instantiated only from an explicitly `APPROVED` row in
the [Seven-Day Causal Matrix](07-seven-day-causal-matrix.md). The Map consumes
that approved record without changing it. Old, mutated, rejected, and reopened
premises belong in the [Plot Material Library](library/03-seven-day-plot-material-library.md),
where their provenance remains available without granting active authority.

An approved causal core whose placement remains unselected cannot instantiate a
card. It must first receive explicit approval in an exact matrix row.

## Day-Slot Record Schema

A slot record is an inspectable interface between upstream authority and a
future approved matrix record. It identifies obligations and lawful handling
without supplying a story premise.

<!-- BEGIN DAY SLOT SCHEMA -->
| Field | Production instruction |
| --- | --- |
| `Upstream slot identity` | Records the stable upstream identifier that locates the record without narrating content. |
| `Approved matrix record` | Links only to the explicitly `APPROVED` matrix record authorized to supply a premise. |
| `Mechanical reference` | Points to the controlling mechanical authority and its applicable obligation. |
| `Relationship function` | Records the approved record's relationship function plus bounded state and tone rendering inputs. |
| `Promotion obligation` | Records any upstream promotion obligation that the approved record must respect. |
| `Incoming causality` | Records the approved record's required incoming cause and lawful knowledge boundary. |
| `Delivery obligation` | Records the required delivery work, lawful visibility, evidence, and contextual echo input the approved record must carry. |
| `Guaranteed fallback` | Records the approved record's required fallback carrier when its primary rendering or evidence is unavailable. |
| `Outgoing causality` | Records the approved record's required exported consequence. |
| `Absence/interruption behavior` | Records the approved record's lawful absence and interruption handling. |
| `Abnormality allowance` | Records the approved record's permitted abnormality boundary, if any. |
| `Ending-day debt` | Records any approved record echo or debt owed to the closing convergence. |
| `Production status` | Records rendering status and the approved record's Beatbook link or return-to-matrix requirement. |
<!-- END DAY SLOT SCHEMA -->

## Approved Production-Card Schema

This schema is populated only after its linked matrix row is explicitly
`APPROVED`. Each instruction cell identifies what that row supplies; the card
may arrange the supplied information for production but may not revise its
premise, causality, authority, or status.

<!-- BEGIN PRODUCTION CARD SCHEMA -->
| Field | Production instruction |
| --- | --- |
| `Approval record` | The approved row supplies its explicit approval record and current lifecycle status. |
| `Matrix link` | The approved row supplies its stable matrix link as the card's sole premise source. |
| `Ordinary activity and setting` | The approved row supplies the authorized ordinary activity and setting boundary. |
| `Participants and visibility` | The approved row supplies the authorized participants and lawful visibility modes. |
| `Causal/action spine` | The approved row supplies the fixed causal and action spine that production must preserve. |
| `Smallest irreversible change` | The approved row supplies the smallest irreversible change that production must retain. |
| `Relationship pressure` | The approved row supplies the required relationship pressure and its boundaries. |
| `Choice/refusal/consent` | The approved row supplies the authorized choice, refusal, and consent boundaries. |
| `State insert input` | The approved row supplies the bounded input for a compact state insert. |
| `Tone action input` | The approved row supplies the bounded input for a tone action. |
| `Contextual echo input` | The approved row supplies the bounded input for a contextual echo. |
| `Evidence and fallback` | The approved row supplies concrete evidence and its guaranteed fallback carrier. |
| `Unresolved cause` | The approved row supplies the unresolved-cause boundary that production must not settle. |
| `Outgoing consequence` | The approved row supplies the required outgoing consequence and exported residue. |
| `Absence/interruption forms` | The approved row supplies lawful absence and interruption forms without creating additional causality. |
| `Beatbook disposition` | The approved row supplies the applicable Beatbook link or the reason expansion is not authorized. |
| `Final-authoring status` | The approved row supplies whether final authoring is authorized or must return for matrix review. |
<!-- END PRODUCTION CARD SCHEMA -->

## Production Rendering Contract

Production renders an approved card in five distinct layers: fixed causal
spine, compact state insert, tone action, contextual echo, and lawful
visibility. The causal spine remains fixed; inserts and echoes may express only
the bounded inputs supplied by the approved row. Visibility follows the row's
authorization and cannot be enlarged by production prose.

The production card is a rendering consumer, not a source of narrative canon or
mechanical law. It records approved information in usable form and does not fill
an unapproved field with a new premise.

## Change Lifecycle

When production reveals a conflict, omission, or need for change, return the
matter to the causal matrix for review. A correction that changes the approved
record must be resolved there before the card is rendered again.

Superseded, rejected, mutated, and reopened material is retained in the Plot
Material Library with its provenance and reason. Production prose must not
silently correct, replace, or promote a premise.

## Plot-Neutral Review Gate

Before use, confirm that the linked matrix record is explicitly `APPROVED`, that
the card copies rather than alters its supplied authority, and that every
rendering input has an approved source. Confirm that this Map contains schemas,
field definitions, and lifecycle instructions only: no premise content, named
people, placement, numbered record, scripted text, protected requirement, or
execution detail.

If any required information is absent, the card remains uninstantiated and the
question returns to the matrix or the Plot Material Library according to its
lifecycle state.
