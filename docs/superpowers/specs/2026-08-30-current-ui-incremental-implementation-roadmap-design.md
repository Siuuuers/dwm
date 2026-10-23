---
id: spec.current_ui.incremental_implementation_roadmap
kind: design_specification
schema_version: 1
conversational_design_status: approved
written_spec_status: approved
written_spec_approved_on: 2026-08-30
written_spec_approved_content_sha256: "6dd6565cbf1c59277c5ecb673b6e1f4d30b8cd48a8b069bac6a0b88c6a770b35"
self_review_status: passed
self_reviewed_on: 2026-08-30
implementation_requested: false
implementation_authorized: false
implementation_planning_requested: true
implementation_plan_path: "docs/superpowers/plans/2026-08-30-current-ui-00-authority-readiness.md"
implementation_plan_status: approved
implementation_plan_sha256: "801c521705c7cf12a17540faa1bff8ef522dcdf4c8eadaa5e1ccc82e292f8710"
created_on: 2026-08-30
scope: current_ui_incremental_implementation_roadmap_design
---

# Current-UI Incremental Implementation Roadmap Design

## 1. Status and objective

The owner approved the **rolling-wave roadmap** and **UI-00 Authority
Readiness** as its first conceptual child boundary on 2026-08-30. No exact
child-plan bytes or execution are approved. This specification records the
architecture for written review.

The objective is to turn the ten accepted current-UI dossiers—nine UI-family
dossiers plus the cross-family Global UI Grammar—into a safe, incremental
delivery program without writing speculative plans for work whose interfaces
are not yet observable. The program must:

1. cover every accepted dossier exactly and preserve its declared scope;
2. separate documentation authority, implementation planning, execution
   permission, mutable work status, and runtime proof;
3. establish the smallest reusable presentation foundation through a real
   vertical slice;
4. admit one bounded, testable child plan at a time from current evidence; and
5. finish with full current-v1 UI conformance only after every required external
   production-proof input exists; until then, retain an explicit open-proof
   ledger rather than infer parity.

This document is design authority for the roadmap shape only after the owner
approves these written bytes. It does not authorize an implementation plan,
Godot changes, authority cutover, registry mutation, source movement, archival,
Beads mutation, commit, or push.

## 2. Approved decisions

The roadmap carries these owner-approved decisions forward without reopening
their UI design:

- one umbrella roadmap covers the whole current-UI program;
- detailed child plans are authored just in time rather than all at once;
- UI-00 is the first child and performs authority readiness only;
- no old UI source moves or archives as part of UI-00 or roadmap authoring;
- the game exposes no player-choosable narrative choices; Minesweeper results
  supply the choice-like consequence;
- current-v1 Gallery contains no Rehearsal surface or scaffold;
- Observer mechanics, the future anomaly generator, avatar framing, the
  Distributed Transfer Field, audio/music visualization, and other registered
  future features remain outside this program unless separately reopened;
- Contacts remain portraitless and symbol-only;
- Angela is never pictured in canonical witnessed scenes;
- deeper story logic, relationship mechanics, schedule eligibility,
  Minesweeper domain rules, persistence ownership, and audio remain with their
  existing authorities; UI children implement only their player-facing
  projections; and
- immediate operations never fabricate `Saving…`, `Applied`, `Saved`, or other
  process evidence that did not occur.

The design remains grounded in factual presentation and interpretive restraint:
the interface shows evidence and operational truth without explaining what the
audience must conclude from it.

## 3. Current evidence and assumptions

### 3.1 Accepted design cohort

The exact accepted artifacts currently restored under
[`docs/design/current-ui/`](../../design/current-ui/README.md) are:

| Family | Stable ID | Accepted canonical-text SHA-256 |
|---|---|---|
| Global UI Grammar | `canon.current_ui.global_ui_grammar` | `4c2dba5908c854e6972df608ef45c9bbe31654d3bc81ba18f22259a720cabecf` |
| Contacts | `canon.current_ui.contacts` | `4739b83c1260a9c9c48b90bc2ad92fc6a163a88fe10262914e7ef0e90f9395bb` |
| Shared Shell | `canon.current_ui.shared_shell` | `232af85acee85bb69b58cdff1c42cb755ab0d821b90866ca2f6c026126824d71` |
| Gallery | `canon.current_ui.gallery` | `7fbc858566a6d9317f857e94bdf5f6ca889188d8b0132dab86585c25e1f04c11` |
| Witnessed Scene | `canon.current_ui.witnessed_scene` | `7b3ce28e0732e54c3227bf978bacd3e45a947f0393913784cfd34dfbc07f30b4` |
| Shop | `canon.current_ui.shop` | `6c10286dcc90fae48f4a50fbb83860c35ad97c0d02692b2c0af42e83ba69641e` |
| Backup | `canon.current_ui.backup` | `1da253e262d996234208e2c95a1096a518ff1a19d02b8a1b85f185f9350da78d` |
| Settings | `canon.current_ui.settings` | `f8877f892aee62a3d5f3ba5618def2fe5b751508aa4a7e5da11d1c8459b1fa51` |
| Schedule | `canon.current_ui.schedule` | `7183b9323908e9b10eab5d9192dfc567f5fe1d10b170c1c5eb53e23679539180` |
| Minesweeper | `canon.current_ui.minesweeper` | `20c4319ded61b8ce7474c5ad84414c3a7b46f3fc9bf567c6491a041271ec6430` |

Every dossier is accepted exact writing, but its frontmatter still declares
`implementation_authorized: false` and a nonbinding authority effect until
repointing and machine discovery. UI-00 must prove durable versioned custody;
physical presence and a matching digest alone are recovery evidence, not
implementation permission.

### 3.2 Tooling and requirement drift

The current resolver in
[`AgentWorkflowAuthorityResolver.gd`](../../../tools/docs/AgentWorkflowAuthorityResolver.gd)
recognizes Beads issues, requirement IDs, specification IDs, decision IDs, and
approved plan paths. It does not recognize `canon.current_ui.*` dossier IDs.
The generated requirement index covers `prompt_docs/`, while specification
projection covers `docs/superpowers/specs/`.

The initial audit found four confirmed requirement conflicts. The old
reply-based invitation model in
[`contacts_invitations.md`](../../../prompt_docs/requirements/contacts_invitations.md).
Accepted Contacts instead makes opening an eligible solo thread the acceptance
event and gives a linked group one shared acceptance. The accepted
[`Backup dossier`](../../design/current-ui/backup.md) also records stale
`req.save.minesweeper_lock` in
[`persistence.md`](../../../prompt_docs/requirements/persistence.md), plus
`req.minesweeper.round_contract` and `req.desktop.logout` in
[`desktop_minesweeper_handoff.md`](../../../prompt_docs/requirements/desktop_minesweeper_handoff.md).
UI-00 reconciles these four known contradictions and no unrelated requirement
prose.
Every later child repeats a scoped dossier-to-packet conflict audit at admission;
this initial list is not a claim that later-family audits can find nothing else.

### 3.3 Runtime readiness

The current Godot 4.6 project already has useful seams:

- `ProfileManager` owns validated preferences;
- `GameState` and application ports expose domain state without requiring UI
  ownership transfer;
- `AppWindowBase` provides hide/reopen and focus behavior;
- `LocalePresentationRoot` and `LocalizedBinding` provide transactional locale,
  font, direction, and text-binding behavior;
- `SettingsPanelController` already adapts UI controls to profile and locale
  ownership; and
- isolated GUT execution and SubViewport menu tests provide a starting proof
  harness.

The presentation layer remains incomplete: no accepted project-wide theme or
token resource exists, display/stretch policy is not explicit, the desktop host
lacks a complete application registry, accessibility presentation is largely
metadata-only, and most family scenes remain skeletal or contradict their
accepted dossiers. These are roadmap inputs, not permission to repair them.

### 3.4 Assumptions

This design assumes:

1. the ten accepted hashes above remain immutable;
2. any changed accepted dossier requires a new review rather than silent repair;
3. the existing domain and persistence owners remain in place unless a later
   separately approved design says otherwise;
4. native-pixel, locale, accessibility-tuple, and final-asset evidence may
   remain open at an early child gate, but no later conformance claim may pretend
   that missing proof exists; and
5. plan authoring and plan execution remain separate approvals.

If any assumption is false when a child is admitted, that child stops for a
bounded design or authority correction. The roadmap is not silently widened.

## 4. Chosen planning architecture

Three structures were evaluated:

1. **One mega-plan.** It appears complete but couples ten accepted dossiers,
   governance migration, shared infrastructure, and final evidence into one
   brittle hash-bound artifact. Early discoveries would stale later tasks.
2. **One roadmap plus every family plan immediately.** This improves local
   readability but still guesses later interfaces before the presentation
   kernel, Shared Shell, and proof harness exist.
3. **One roadmap plus just-in-time bounded child plans.** The roadmap freezes
   only stable dependencies and gates. Each child is written from the runtime
   and evidence that actually exist when its prerequisites pass.

The third structure is selected. It is the smallest architecture that gives
complete program coverage without false precision.

## 5. Authority and status separation

The program uses two independent lanes.

```text
Design-authority lane
accepted design bytes
    -> approved roadmap specification
    -> approved UI-00 plan and exact UI-00 execution permission
    -> machine discovery
    -> consumer census and scoped requirement reconciliation
    -> per-family consumer repoint and cutover gates
    -> current design authority
    -> optional later archival transaction

Runtime-delivery lane
discoverable accepted target + still-current living authorities
    -> owner-approved slice-scoped implementation-target admission
    -> approved hash-bound child plan
    -> exact execution permission
    -> isolated implementation and focused verification
    -> family cutover before maintained player-facing integration
    -> evidence tied to one tested subject
    -> Beads closure
```

The lanes meet only when an implementation-target admission cites exact design
sources and when a later cutover consumes exact runtime evidence. Neither lane
silently advances the other. Each arrow is a separate gate:

- design acceptance does not authorize implementation;
- discovery does not perform cutover;
- an implementation-target admission does not make its successor generally
  current or repoint another consumer;
- a plan does not grant execution permission;
- passing tests do not approve a design or close a Beads issue;
- a commit does not prove complete conformance; and
- runtime parity does not authorize source movement.

A **slice-scoped implementation-target admission** is the single bounded bridge
that prevents circularity. It is the ordinary child design specification that
binds the child's plan; the program does not create a second admission registry
or authority subsystem. The admission specification has one stable ID, exact
canonical-text hash, and owner-approval record. Its bytes must name:

- one implementation slice;
- every accepted successor dossier ID, hash, and clause range it targets;
- every still-current predecessor and retained deeper authority for that slice;
- an explicit resolution for every touched conflict;
- the plan-authoring scope authorized by approval of the written admission;
- the exact production exposure boundary that must remain unchanged while the
  slice is pre-cutover; and
- the rule that the work stays isolated and non-player-facing until the required
  family cutover and integration gate pass.

Admission approval authorizes target selection and plan authoring only. After
exact plan bytes exist, a separate owner lifecycle transaction may add the
approved plan path/hash, execution mode and permission, test/evidence scope, and
commit permission to the child specification. Those fields remain independent;
neither admission approval nor plan approval grants runtime mutation by itself.

The admission never changes a dossier's general authority effect, transfers a
deeper owner, moves a source, or satisfies a cutover/archive gate. Runtime output
produced under it is labelled pre-cutover successor-conformance evidence.

The **production exposure boundary** is the exact existing scene, resource,
registry, application route, or main-scene path whose mutation would make the
successor slice reachable through the maintained game flow. Every runtime child
names that path set and proves it unchanged during isolated pre-cutover work.
New components may be exercised through dedicated fixtures or unrouted scenes.
Only after the required documentation cutover may a separately named integration
task change the exposure boundary and rerun the focused and integration evidence.

[`AGENT_WORKFLOW.md`](../../agent/AGENT_WORKFLOW.md) and
[`authority_context.md`](../../../prompt_docs/requirements/authority_context.md)
keep mutable execution status in Beads. Therefore the roadmap contains no
mutable “current phase,” checkbox ledger, or duplicated issue status. Beads
owns what is open, active, blocked, and closed; the roadmap owns only the stable
dependency and admission contract.

## 6. Artifact model

The program creates only the artifacts needed for the next truthful action:

1. **This design specification is the static umbrella roadmap.** It defines the
   stable work-package graph, family coverage, admission gates, common proof
   contract, and child-plan template without mutable status.
2. **One next child plan** is authored when its entry evidence exists. Initially
   this is UI-00 Authority Readiness.
3. **One child design specification acting as the slice-scoped
   implementation-target admission** accompanies each later runtime child. The
   existing specification/plan resolver handles it; it is not a general
   temporary-authority system.
4. **Later child plans** are authored at their wave gates. Empty plan stubs,
   speculative file lists, and copied dossier prose are forbidden.
5. **Beads issues** own live status and dependency readiness after separately
   authorized registration.
6. **Executed evidence** records the exact commit or worktree subject, commands,
   results, and remaining gaps after separately authorized implementation.

No additional dependency database, UI status registry, architecture
encyclopedia, or per-family copy of the accepted canon is introduced.

## 7. Two graphs, not one

### 7.1 Runtime delivery graph

The convenient build order is:

```text
UI-00 Authority Readiness
    -> Settings-proving presentation kernel
    -> Settings core/proving slice
    -> Shared Shell + Settings host parity
        -> Contacts
        -> Backup
        -> Shop
        -> Schedule
        -> Gallery index/inspection -----+
        -> Minesweeper board + desktop --> Witnessed Scene
                                          |
                                          +-> Gallery replay completion
    -> Full current-v1 UI conformance when external proof inputs exist
```

This graph records true implementation dependencies only:

- Settings is the first family because its existing profile, localization,
  reset, host, and test seams provide the highest proof per changed file.
- The first presentation kernel is scoped to Settings. It does not roll a new
  theme across every family before one consumer proves the contract.
- UI-01 and UI-02 are two roadmap milestones inside one bounded
  Settings-proving child plan and one admission that cites both exact dossiers;
  they are not two independently exposed partial products.
- Full Shared Shell follows the Settings proof. The first slice may verify the
  desktop Settings wrapper standalone; it does not invent the missing desktop
  launcher as hidden Settings work.
- Settings family completion is not claimed until Shared Shell proves the same
  logical surface in Title, Desktop, and Pause host contexts and the applicable
  Settings/Shell authority cutover permits maintained player-facing integration.
- Contacts, Backup, Shop, and Gallery index/inspection are low-coupling leaves
  after the Shell contract is real. They remain separate children.
- Schedule is not downstream of Contacts presentation. It consumes stable
  invitation, eligibility, and schedule-command ports and may be planned
  independently after the Shell contract exists.
- One reusable Minesweeper board/session presenter serves desktop and witnessed
  challenge composition without moving board-domain ownership into UI.
- Gallery replay completes only after the witnessed playback host and return
  custody are real. Gallery's index and record inspection may be proven earlier.

The graph expresses possible parallelism, not automatic permission to execute
multiple issues. The default workflow still selects one bounded Beads issue.

### 7.2 Documentation cutover graph

Documentation cutover is deliberately not inferred from runtime order.

- Shared Shell, Settings, Contacts, Gallery, Backup, and Shop contain handoffs
  that require their family cutover before or atomically with the eventual
  Global UI Grammar cutover. UI-00 must verify the exact inbound census before
  freezing that transaction.
- Schedule, Witnessed Scene, and Minesweeper may cut over independently when
  their own gates pass; they do not create a reason to make Global UI Grammar a
  behavioral super-authority.
- Minesweeper additionally retains a cutover gate on
  `note.minesweeper_maintained_survey_worksheet_standard_palette_and_state_disposition`
  at
  `docs/design/2026-08-23-minesweeper-maintained-survey-worksheet-standard-palette-and-state-disposition.md`,
  current recorded SHA-256
  `b8a7f62f0202c82ac2114a9fedf171d7c5fc5fc5e33ce4cc9d8d49721a95027c`.
  Separate owner approval of those exact bytes gates Minesweeper documentation
  cutover and source movement; it does not automatically gate a separately
  authorized pre-cutover implementation slice. A slice still stops wherever it
  needs an unsettled tuple, asset, or copy decision.
- Mixed and partially imported deeper authorities remain living at their
  current paths.
- Source movement and archival are excluded from this roadmap. If desired
  later, they receive their own custody design, plan, approval, and verification.

## 8. Stable work-package ledger

| ID | Family or gate | Stable outcome | True entry dependency | Explicit exclusion |
|---|---|---|---|---|
| UI-00 | Authority Readiness | Exact dossiers become resolvable planning inputs; confirmed consumer and requirement conflicts are reconciled | accepted bytes and owner approval of this written spec/plan lifecycle | runtime, cutover by implication, source movement, archival |
| UI-01 | Global UI Grammar | Minimal tokens/theme, scaling, focus, locale, and accessibility hooks are proven through a Settings-scoped consumer | UI-00, an approved slice admission, and an approved child plan | Global authority cutover, all-family rollout, final art production, app behavior ownership |
| UI-02 | Settings | One logical Settings core works in menu and standalone desktop wrappers with truthful persistence/failure behavior; family completion waits for UI-03 host parity | UI-01 under the same admitted proving slice and child plan | complete Desktop/Pause parity, desktop launcher, unrelated profile/schema redesign |
| UI-03 | Shared Shell | Title, Desktop, and Pause hosts share routing, focus, modal, cache, HUD, and Quick-edge contracts; Settings host parity is proven | UI-02 and its own approved slice admission/plan | app internals, save implementation, story/mechanics |
| UI-04 | Contacts | Portraitless register, witness/read lifecycle, and accepted invitation projection | UI-03 and corrected Contacts requirements | portraits, choosable replies, relationship ownership |
| UI-05 | Backup | Archive-cabinet save/load projection and Backup-owned F5/F9 public results projected by Shared Shell | UI-03, reconciled save-lock requirements, and stable SaveManager ports | save-schema redesign, invented progress states |
| UI-06 | Shop | Catalog and transaction projection with single shell currency placement | UI-03 and stable catalog/transaction ports | economy ownership, app-local currency duplicate |
| UI-07 | Gallery | Endings-only index/inspection first; replay and return custody after Witnessed Scene | UI-03, then UI-10 for replay completion | Rehearsal surface or scaffold, profile/archive ownership |
| UI-08 | Minesweeper | Reusable board/session presenter, desktop surface, and challenge-facing contract | UI-03, reconciled round/save-lock requirements, stable board ports, and a slice admission that preserves the pending visual Standard | generator/session/persistence ownership, narrative choices |
| UI-09 | Schedule | Docket projection, eligible-only rows, warnings, and exact bare-paper empty state | UI-03 and stable invitation/eligibility/schedule-command port contracts | Contacts presenter completion; eligibility, relationship, Hospital, or day-resolution ownership |
| UI-10 | Witnessed Scene | Ordinary, Hospital, ending, and challenge hosts share one lawful witnessed composition | UI-03 and UI-08 presenter contract | Angela art, public speaker identity, story/ending ownership |
| UI-11 | Full current-v1 UI conformance | All nine families and Global UI Grammar satisfy their required proof without mixed old/new consumers | UI-01 through UI-10 complete and integrated; required external tuples, copy, fonts, locales, assets, native/composited proof, and family cutovers available | inferred parity, hidden deferral closure, release claim without evidence |

The IDs are roadmap labels, not Beads IDs, phase status, or execution authority.
Each of the nine UI families and the cross-family Global UI Grammar appears once
in the owning column. Gallery has two truthful delivery milestones inside its
single owning row.

## 9. UI-00 Authority Readiness boundary

UI-00 is documentation and tooling readiness only. It prepares both lanes in
Section 5 but performs neither a general family cutover nor runtime work.

### 9.1 Entry evidence

Before UI-00 execution, its plan must require:

- exact UTF-8/LF bytes and accepted hashes for all ten dossiers and the README;
- a collision-free path and ID census;
- an inventory of current inbound path/ID consumers and retained deeper owners;
- current worktree and base-commit evidence;
- no overlapping mutation in any named path; and
- separate approval of the exact UI-00 plan and execution boundary.

### 9.2 Intended work

The UI-00 child plan may design bounded tasks to:

1. add fail-closed discovery for accepted current-UI dossier IDs and exact
   digests through one new `canonical_ui_id` resolver link kind, without a
   second general registry system;
2. test rejection of an unknown ID, duplicate ID, altered digest, invalid UTF-8,
   unaccepted status, and unsafe path;
3. amend the authority-context packet and resolver contract so a
   `canonical_ui_id` target, an ordinary approved child specification acting as
   its slice admission, and eventual repointed authority remain distinguishable
   from retained deeper requirement ownership;
4. reconcile the confirmed Contacts opening-as-acceptance and linked-group
   acceptance conflict, plus stale `req.save.minesweeper_lock`,
   `req.minesweeper.round_contract`, and `req.desktop.logout` clauses;
5. define and test the smallest slice-admission record described in Section 5;
6. produce the exact per-family consumer-repoint and retained-provenance census;
7. preserve every reviewed plan's bytes and digest; and
8. record the named Minesweeper visual-Standard approval as a cutover gate rather
   than silently promoting it.

Discovery and cutover must remain separate operations. UI-00 may make an
accepted dossier queryable without claiming that every family consumer has
already cut over.

### 9.3 Exit evidence

UI-00 is complete only when:

- all ten accepted IDs resolve uniquely to their exact bytes and hashes;
- negative resolver and validator tests fail closed;
- generated indexes and link validation are deterministic and current;
- the authority-context rule describes the new UI authority without weakening
  status separation;
- all four currently confirmed stale requirement areas agree with their accepted
  Contacts, Backup, Shared Shell, and Minesweeper semantics;
- a slice admission resolves exact target/predecessor conflicts without changing
  general dossier authority or granting execution by implication;
- every inbound reference is classified for future repoint or labelled retained
  provenance;
- no accepted dossier or existing hash-bound plan changed silently; and
- no runtime, source movement, archival, commit, or broader requirement rewrite
  is claimed unless separately authorized.

## 10. First runtime proving slice

After UI-00, the owner separately reviews a Settings-scoped implementation-target
admission and runtime plan. The first runtime child then uses Settings to prove
the minimum shared presentation contract in isolation. Its later implementation
plan should decompose the work into observable RED-to-GREEN steps:

1. characterize the existing Settings, menu focus, accessibility, profile-reset,
   and smoke baselines;
2. add failing accepted-Settings contract tests for structure, geometry, focus,
   persistence projection, locale behavior, failure truth, and accessibility;
3. add only the Global UI Grammar primitives required by this slice;
4. replace duplicated skeletal/dynamic composition with one explicit logical
   Settings component while retaining `ProfileManager` and existing adapters as
   owners;
5. integrate the menu host and prove close/Escape/reopen focus restoration;
6. apply real text scale, contrast, focus, target-size, and reduced-motion
   presentation rather than metadata alone;
7. prove standalone desktop-wrapper parity without adding the desktop launcher;
   this remains a core/proving slice, not complete Title/Desktop/Pause parity;
   and
8. run focused, regression, smoke, and deterministic SubViewport evidence.

This is a proving slice, not permission to roll the foundation into another
family or expose a partially migrated surface as the maintained player-facing
implementation. Shared Shell later proves complete Settings host parity. Each
later child consumes the proven contract and extends it only where its accepted
dossier requires.

## 11. Just-in-time child-plan contract

A child plan may be written only when its entry evidence is observable. Each
plan must contain:

- one bounded authority-readiness or player-facing outcome;
- the exact accepted dossier ID, path, and hash;
- retained deeper authority IDs and the scopes they continue to own;
- for a runtime child, the exact owner-approved slice admission and its conflict
  resolutions;
- current base commit and relevant worktree assumptions;
- prerequisite evidence, including the exact upstream interface consumed;
- files and interfaces in scope, with any uncertain path made a stop condition
  rather than a guess;
- the exact production exposure boundary, its pre-cutover unchanged check, and
  the cutover plus rerun evidence required before integration;
- explicit non-goals and deferred features;
- a RED test or characterization step before behavior mutation;
- the smallest implementation steps that make the named evidence pass;
- focused, regression, integration, visual, accessibility, and persistence
  checks proportionate to the slice;
- failure, rollback, and safe-stop behavior;
- the exact Beads issue, or an explicit registration prerequisite, required for
  live execution status; and
- separate fields for plan approval, execution permission, commit permission,
  and evidence.

Every changed path must trace to the child's one outcome or one consumed
interface. Each task owns one atomic behavior or interface transition and splits
when it cannot be reviewed and verified independently; raw file count does not
define surgicality.

After owner approval, the specification records the child plan's canonical-text
SHA-256. Any semantic plan edit invalidates that approval and requires a newly
reviewed digest. Newline-only checkout conversion does not.

## 12. Error handling and stop conditions

The program fails closed. A child stops before mutation when:

- an accepted ID is missing, duplicated, altered, unapproved, or unresolved;
- an inbound consumer or retained deeper owner is ambiguous;
- its approved plan hash does not match current bytes;
- the selected Beads issue is absent, ambiguous, blocked, or not the authorized
  issue;
- exact execution permission is missing before runtime mutation;
- the worktree overlaps the child's named paths unexpectedly;
- a required upstream interface or proof artifact does not exist;
- a baseline failure overlaps the subject, a consumed interface, or a required
  regression gate;
- a required locale, accessibility tuple, asset, or copy decision would need to
  be invented; or
- the intended change would create a deferred UI scaffold or transfer domain
  ownership into presentation code.

An unrelated baseline failure is fingerprinted against the pre-change result and
left untouched; it cannot be hidden or claimed fixed. The response to a real
stop is the smallest owning correction. The child does not silently fall back
to an older design, expand scope, weaken a test, fabricate a placeholder state,
or repair unrelated code.

Commit permission is checked only before staging or committing. If execution is
authorized but commit is not, verified changes remain uncommitted and are
reported honestly; they are not treated as an implementation failure.

## 13. Verification architecture

Every child records an evidence-applicability matrix with one of
`required`, `not applicable` plus a reason, or `deferred blocker` for each layer:

1. **Authority evidence — always required:** stable ID, digest, retained owner,
   admission where applicable, plan hash, Beads, and permission checks.
2. **Focused behavior evidence — always required for runtime:** one failing
   contract test followed by the smallest passing implementation.
3. **Regression evidence — always required for runtime:** existing tests for the
   owners and interfaces the child touches.
4. **Scene evidence — applicability-gated:** instantiate/free, routing, focus,
   modal custody, and cache/reopen behavior.
5. **Visual and accessibility evidence — applicability-gated:** deterministic
   1280×720 geometry, 100/125/150-percent text, approved real locales,
   keyboard/controller focus, non-colour state communication, approved
   high-contrast/CVD tuples, and reduced-motion behavior.
6. **Persistence evidence — applicability-gated:** save/load/reopen/reset
   equivalence for every state the family projects, without moving storage
   ownership into UI.
7. **Cross-family evidence — final/integration children:** shared collisions,
   focus/modal precedence, shell ownership, route handoffs, and absence of mixed
   old/new consumers.

Use the isolated Godot runner under `tools/testing/` with unique suite and log
names. Evidence must identify the tested subject. A narrow focused pass cannot
support a broad whole-UI claim.

UI-11 cannot pass while a dossier-required tuple, copy, font, locale, final
asset, native-pixel, or composited-contrast proof remains unavailable. These
inputs may be produced by separate owners, but their absence remains a visible
program blocker rather than an exemption. UI-11 records an exact open-proof
ledger until every required item is supplied and verified.

## 14. Parallelism and integration policy

The dependency graph permits later independent work, but execution remains
serial by default through one selected Beads issue. Parallel execution requires
separate authorization, disjoint worktrees, disjoint production/test paths, and
independent evidence roots.

Shared theme/token, localization-root, AppWindowBase, Shell, resolver, and
common-test-harness changes are serialized. Family presenter work may run in
parallel only after the consumed shared interface is verified and frozen for
that wave. Conflicting edits are not reconciled by silently choosing one branch.

## 15. Existing plans and specifications

The new roadmap references existing artifacts according to their actual scope:

- the Phase 2R plans remain deeper implementation/API history and requirement
  evidence where current authorities retain them;
- the 2026-08-07 Seven-Day Flow roadmap and children remain proposed,
  hash-bound, and non-executable; this roadmap does not edit or execute them;
- [`2026-08-14-title-art-and-bottom-up-caption-components.md`](../plans/2026-08-14-title-art-and-bottom-up-caption-components.md)
  remains narrow title/caption implementation provenance and is not absorbed;
- [`2026-08-21-room-owned-aperture-v1-design.md`](2026-08-21-room-owned-aperture-v1-design.md)
  remains pending exact written review and cannot authorize Witnessed Scene
  runtime work; and
- the Acoustic Memory Atlas remains outside this UI program because it is audio
  work.

No existing reviewed plan is amended in place. If a later child needs to change
one, it receives a separately reviewed amendment and new hash binding.

## 16. Non-goals

This roadmap does not:

- implement the game or any UI;
- approve or execute final art, font, motion, audio, voice, TTS, music
  visualization, or accessibility-certification production; required outputs
  from those separate owners still gate UI-11 where a dossier demands them;
- reopen settled visual or player-facing behavior;
- design Rehearsal, Observer mechanics, anomaly generation, avatar frames, or
  the Distributed Transfer Field;
- write story content, DTL dialogue, ending logic, relationship rules, schedule
  eligibility, or Minesweeper mechanics;
- move, copy, or archive superseded sources;
- create mutable status outside Beads;
- promise all later child-plan file lists before their entry evidence exists; or
- authorize a commit, push, release, or runtime mutation.

## 17. Acceptance criteria for this design

The written design is ready for owner review when:

- all nine UI families and the cross-family Global UI Grammar appear exactly
  once in the owning ledger column;
- accepted hashes match the current ledger;
- runtime ordering and documentation cutover ordering are distinct;
- UI-00 has exact entry, work, exit, and non-goal boundaries;
- the first runtime slice is Settings with a Settings-scoped foundation and is
  labelled core/proving until Shared Shell completes host parity;
- every later family has a stable outcome and true dependency;
- Gallery's two milestones do not introduce Rehearsal;
- Minesweeper's named visual-Standard gate is scoped to cutover/movement rather
  than silently treated as exact-byte approval;
- status remains in Beads;
- child plans are just in time, hash-bound after approval, and separately
  authorized for execution;
- source movement and archival remain excluded;
- no drafting placeholder, unresolved alternative, or inferred implementation
  claim remains; and
- all local Markdown links resolve.

## 18. Transition after written-spec approval

After the owner approves these written bytes, the only next skill is
`superpowers:writing-plans`. This specification already is the static umbrella
roadmap, so that skill will produce only the first detailed child plan,
UI-00 Authority Readiness. Creating a second roadmap file would duplicate the
stable graph and invite drift.

It will not pre-create the later family plans. After UI-00 is executed and its
evidence is current, the next planning cycle writes the Settings-scoped
implementation-target admission and proving child from the then-observable
interfaces.

The brainstorming workflow normally commits an approved design document. The
owner's present authorization explicitly excludes commit, so this specification
remains uncommitted unless separate commit permission is granted.
