---
id: spec.phase_2r.foundation_repair
kind: design_specification
schema_version: 1
conversational_design_status: approved
written_spec_status: approved
self_review_status: passed
implementation_authorized: true
implementation_plan_approved_on: 2026-07-18
implementation_execution_mode: inline
implementation_evidence: []
verification_evidence: []
active_phase: phase_2r
created_on: 2026-07-17
written_spec_approved_on: 2026-07-17
beads_issue: dwm-0r0
engine_line: godot_4_6
verification_engine: "4.6.3-stable-mono"
dialogic_version: "2.0-Alpha-19 (Godot 4.4+)"
language: gdscript
---

# Phase 2R Foundation Repair

## 1. Objective

Phase 2R MUST establish a contradiction-free, testable foundation before Phase 3 begins.

The target player run is Day 1 through Day 7 followed by ending playback and a return to Menu. Day 8 MUST NOT be a valid current gameplay, persistence, content, or routing state. Day 8 MAY appear only in baseline evidence, legacy migration input, and negative tests that prove rejection or migration.

Phase 2R covers:

- Documentation authority and demand-loaded agent context.
- Durable Beads tracking and removal of ineffective repository CodeGraph integration.
- Runtime ownership and GameState decomposition.
- Day 1 through Day 7 lifecycle repair.
- Safe, synchronized narrative checkpoints and profile persistence.
- Contact, invitation, schedule, Hospital, dating, and ending behavior.
- Dialogic authority, effect safety, read history, and skipping.
- Phase 3 handoff contracts for desktop app composition and the deterministic Minesweeper result simulator.
- Audio, preferences, and custom JSON localization.
- Isolated behavioral tests and a blocking evidence gate.

Phase 2R MUST NOT:

- Invent narrative prose.
- Pretend placeholder timelines are final content.
- Implement the real Minesweeper board.
- Wire the player-facing deterministic Minesweeper simulator; Phase 3 owns that work.
- Introduce C#.
- Uninstall CodeGraph globally.
- Convert custom localization files to Godot TranslationServer resources.
- Begin Phase 3 before the Phase 2R evidence gate passes.

## 2. Evidence Baseline

The following observations describe the repository before Phase 2R implementation:

- GameState.gd is approximately 1,596 lines and owns unrelated run, profile, invitation, schedule, dating, ending, settings, and audio concerns.
- The game currently routes to an effectively empty desktop because major Phase 3 UI scenes are not wired.
- The current run model can reach Day 8.
- Ending playback does not run the optional group epilogue.
- Gallery IDs, pair IDs, and ending IDs are inconsistent.
- Save routing, pending dating state, Hospital deferral, migration defaults, and nested type validation contain correctness defects.
- Dialogic is the intended narrative engine, but the Dialogic smoke test is an unconditional pass.
- Sixty-one English Dialogic timeline files exist; twenty-four contain ninety-one TODO markers.
- GUT currently reports eighty-eight passing tests and 299 assertions, while also reporting orphan and unfreed-node diagnostics.
- The current smoke suite reports 28 passing checks while retaining 26 resources.
- Existing save tests can touch real user save slots.
- The current smoke suite instantiates scenes off-tree, so ready callbacks, signal connections, focus, and navigation are not exercised.
- CodeGraph indexes repository tooling but no project GDScript or Godot scenes.
- LocalizationManager hardcodes 50 en keys and 25 direct keys in each of zh_CN and zh_HK; only English Dialogic timelines exist.
- LocalizedText is an inert stub, and the current Settings language selectors are neither populated nor wired.
- project.godot targets Godot 4.6 and contains a malformed duplicate BOM-style config_version entry.

Passing counts in this section are evidence of the current harness only. They MUST NOT be interpreted as proof that the described game flow is implemented.

The first Phase 2R child MUST generate a baseline evidence artifact containing the capture commands, worktree identity and dirty status, exact engine and addon versions, counts, and diagnostics. Until that artifact exists, the observations above are discovery evidence rather than verification evidence.

## 3. Authority Model

Authority is deliberately divided:

| Concern | Authoritative source |
|---|---|
| Intended and future behavior | Approved requirement packets |
| Current implemented behavior, including defects | Runtime code |
| Verification evidence | Executed tests and validators |
| Execution status and task dependencies | Beads |
| File paths, counts, and aggregate views | Generated inventories |

If two authorities disagree, the agent MUST report drift and link it to Beads work. The agent MUST NOT silently select one source as universal truth.

Approved specification does not imply implemented behavior. Implemented code does not imply verified behavior. A passing test does not imply coverage unless it is linked to the corresponding approved requirement.

## 4. Documentation Architecture

### 4.1 Active structure

This dated file is a pre-migration umbrella design authority, not a domain requirement packet. The frontmatter-to-body requirement bijection defined below applies to the bounded packets produced from this design. This file MUST NOT enter normal implementation context after those packets replace it.

The intended active structure is:

    Prompt.md
    prompt_docs/
      phases/
      requirements/
      decisions/
      schemas/
      INDEX.md

Prompt.md MUST remain a minimal entry contract containing:

- Documentation schema version.
- Authority boundaries.
- Active phase.
- Exact context-loading procedure.
- Validation and generated-index commands.

INDEX.md MUST be generated-only.

### 4.2 Domain packets

Each bounded domain packet is a Markdown file with YAML frontmatter.

Frontmatter exclusively owns:

- Packet and requirement identities.
- Specification lifecycle.
- Semantic requirement dependencies.
- Implementation evidence links.
- Verification evidence links.
- Beads issue links.

The Markdown body exclusively owns:

- Behavioral meaning.
- Invariants.
- State transitions.
- Error behavior.
- Acceptance criteria.

Each frontmatter requirement record MUST have exactly one matching Markdown rule section. A normative body section without a registered requirement ID is invalid. A registered requirement without a matching body section is invalid.

Normative bodies MUST use explicit terms such as MUST, MUST NOT, MAY, and exact state tables. Approved requirements MUST contain no TODO, TBD, unresolved branch, or conversational history.

### 4.3 Status separation

Frontmatter specification_status is one of:

- proposed
- approved
- deferred
- retired

Beads alone owns work status:

- open
- in_progress
- blocked
- closed

Frontmatter decision_status is one of:

- resolved
- decision_required

Implementation and verification fields are arrays of evidence links, not manually asserted completion labels. Generated reports resolve those links and record the latest executed result.

Semantic requirement dependencies belong in frontmatter. Work-order dependencies belong in Beads.

### 4.4 Demand-loaded context

An implementation agent MUST load context in this order:

1. Read minimal Prompt.md.
2. Run bd prime.
3. Select and inspect the active Beads issue.
4. Load the active phase packet.
5. Load only requirement packets referenced by the issue.
6. Load transitive semantic dependencies.
7. Use generated INDEX.md only for lookup.

Future phases and unrelated domains MUST be excluded from default reading.

### 4.5 Unresolved decisions

An unresolved choice MUST be a structured decision_required record containing:

- Known evidence.
- Scope.
- Affected requirements.
- Blocking relationships.
- Recommended next investigation.

Dependent implementation MUST remain blocked. An agent MAY investigate and recommend an answer but MUST NOT invent one.

### 4.6 Legacy retirement

Every legacy section MUST receive one disposition:

- migrated
- retired
- rejected_as_incorrect

All repository references MUST be updated and validated before deletion. A generated disposition report MUST prove complete coverage but MUST remain outside normal agent context.

Superseded documentation MUST be deleted rather than retained as redirect stubs or an active archive. Git history is the archive.

## 5. Runtime Ownership and Module Seams

### 5.1 Sole owners

| State or behavior | Sole owner |
|---|---|
| Current run and gameplay variables | GameState facade and internal run modules |
| Gallery, preferences, visited text, and input mappings | ProfileManager |
| Dialogic playhead | Dialogic through DialogicBridge |
| Live tracks, players, buses, and fades | AudioManager |
| Disk serialization and slot operations | SaveManager |
| Scene navigation execution | SceneRouter |
| Visual presentation | Active scenes and UI nodes |

### 5.2 GameState facade

GameState MUST remain the stable public facade where the current interface is correct. It MUST delegate to GDScript RefCounted modules:

- RunLifecycle
- ContactInvitationState
- ScheduleRules
- DatingEndingRules
- RunSnapshotSchema

Before extraction, Phase 2R MUST generate a public-symbol and call-site inventory for GameState. Every public symbol receives exactly one disposition: retain, replace, deprecate, or remove. retain requires a passing contract test; replace or deprecate requires an explicit compatibility seam and caller migration; remove requires zero validated consumers. The phrase "where the current interface is correct" means only symbols with a retain disposition and passing evidence.

These modules MUST:

- Expose small interfaces.
- Accept dependencies instead of discovering them globally.
- Return explicit results.
- Contain no scene-tree or UI knowledge.
- Be testable through the same interface used by callers.

### 5.3 Supporting managers

ProfileManager owns persisted profile values. AudioManager, InputManager, AccessibilityManager, and LocalizationManager apply the relevant committed values without becoming duplicate owners.

DialogicBridge is the only validated narrative seam. Dialogue boxes, choices, logs, portraits, and chat bubbles are presentation only.

EffectResolver accepts only registered effect IDs and invokes domain commands atomically with stable transaction IDs.

SceneRouter executes registered semantic routes but MUST NOT decide game outcomes.

SaveManager performs I/O but MUST NOT own or reinterpret gameplay state.

### 5.4 Commands and notifications

Commands use direct method calls. Typed signals describe committed changes after mutation.

UI listeners MAY render state and send player commands. They MUST NOT mutate domain state from notification callbacks.

Load MUST emit one run_restored notification. It MUST NOT replay historical mutation signals.

A universal EventBus MUST NOT be introduced.

## 6. Run Lifecycle

### 6.1 Persisted state machine

RunLifecycle has three persisted states:

    PLAYING -> ENDING -> COMPLETED

day MUST be an integer from 1 through 7.

Only RunLifecycle may increment day. A completed ending routes to Menu.

### 6.2 Days 1 through 6

Schedule Done MUST create or resume one persisted, idempotent DayResolutionPlan. The plan contains:

- A stable resolution_id.
- source_day.
- Ordered stage records with stage_id, transaction_id, route_id or null, and state.
- A stage state from pending, active, or completed.

The plan MUST checkpoint after every completed stage. Loading resumes the first incomplete stage. Repeated Done commands and duplicate completion signals reuse the same resolution_id and MUST NOT duplicate effects.

For Days 1 through 6, the ordered stages are:

1. Lock day-changing interaction.
2. Validate the complete schedule.
3. Execute entries by ascending schedule slot_index; duplicate slot indexes are invalid.
4. Commit date outcomes and non-date effects.
5. Resolve fainting and Hospital first.
6. Play deferred missed-group twofriends after Hospital.
7. Resolve invitation rollover and append next-day messages.
8. Increment day exactly once.
9. Reset day-scoped UI and cached desktop apps.
10. Create the new-day checkpoint and disk autosave.
11. Unlock the next day.

The increment stage is the only stage that may change day, and it may complete at most once. A route stage may cross scenes or timelines; its completion receipt MUST be committed before the next stage begins.

Rollover messages are committed with target_day = source_day + 1 before the increment stage and remain invisible until day equals target_day. They begin unread. A repeated rollover stage reuses its transaction IDs and MUST NOT append duplicates.

Each schedule entry expands into its own substage identified by source_day, slot_index, and entry_id. Each route segment and committed entry effect has its own stable transaction receipt. Resume skips completed substages and begins at the first incomplete substage; it MUST NOT replay an earlier entry.

### 6.3 Day 7

Schedule Done on Day 7 MUST:

1. Execute already scheduled content.
2. Execute only the terminal stage allowlist defined below.
3. Close unresolved invitation actions as RESOLVED_RUN_END without generating rollover, judge, missed_question, busy, nevermind, twofriends, or other next-day content.
4. Keep day equal to 7.
5. Resolve an EndingPlan.
6. Transition PLAYING to ENDING.

Real-time fainting remains active. If Angela faints during Day 7 play or scheduled content, Hospital MUST occur first and ending resolution MUST follow with day equal to 7. No missed-group twofriends stage is introduced on Day 7.

Day 7 uses the same persisted, idempotent DayResolutionPlan and per-entry substage mechanics as Days 1 through 6. After scheduled content, its complete terminal stage allowlist and order is: hospital_if_triggered, close_invitations_run_end, resolve_ending_plan, enter_ending, ending_autosave. ending_autosave commits the ENDING checkpoint to disk before primary playback starts. No other post-schedule stage ID is valid on Day 7; in particular, penalty, danger, sequela, invitation_rollover, next_day_messages, twofriends, increment_day, and new_day_autosave are forbidden.

### 6.4 Schedule interface

Schedule validation MUST distinguish:

- Whether a candidate can be added.
- Whether an existing schedule is internally valid.

An existing entry MUST NOT invalidate itself as a duplicate or capacity violation.

Schedule commands return:

- Acceptance or rejection code.
- Rejection reason.
- Committed non-date effects.
- Date outcome IDs.
- Ordered route_plan entries.
- Resulting checkpoint ID.

The current ambiguous executed boolean MUST be removed. Callers MUST consume the explicit acceptance code, outcome IDs, route_plan, and checkpoint ID instead.

## 7. Hospital, Dating, and Endings

On Days 1 through 6, if fainting and a missed accepted group date occur in the same resolution, playback order MUST be:

    Hospital -> twofriends -> one day advancement

### 7.1 Ending selection

DatingEndingRules resolves the primary only after Day 7 scheduled content and any Hospital stage have committed. Its primary precedence is:

1. ending.sylvia.special when hospital_skipped_sylvia_solo_count is at least 2.
2. The completed Day 7 candidate friend's ending path.
3. ending.alone.

A completed Day 7 candidate MUST be exactly one Priscilla, Lavinia, or Sylvia solo ending-date outcome that was unlocked, scheduled, and successfully completed. A date prevented by fainting is not a completed candidate. More than one candidate or an unknown friend ID is invalid.

For candidate friend f:

- ending.f.true requires true_path_count at least 4 and affection tier love.
- ending.f.dark requires dark_points at least 2 when the true rule does not match.
- ending.f.sweet requires dark_points at most 1 when neither earlier rule matches.

The epilogue is resolved independently. missed_group_date_counts[priscilla_lavinia] at least 2 sets epilogue_id to ending.priscilla_lavinia; otherwise epilogue_id is null. A qualifying group epilogue MUST NOT alter primary precedence.

### 7.2 Ending playback

EndingPlan contains:

    primary_id
    epilogue_id or null
    playback_stage

primary_id MUST be one of the eleven non-group canonical ending IDs. epilogue_id MUST be null or ending.priscilla_lavinia. The group ending is an optional epilogue and MUST NOT replace Angela's primary ending.

Playback order MUST be:

    primary timeline
    optional ending.priscilla_lavinia epilogue
    idempotent permanent gallery recording
    ENDING -> COMPLETED
    Menu

The canonical ending IDs are:

- ending.alone
- ending.priscilla.sweet
- ending.priscilla.dark
- ending.priscilla.true
- ending.lavinia.sweet
- ending.lavinia.dark
- ending.lavinia.true
- ending.sylvia.sweet
- ending.sylvia.dark
- ending.sylvia.true
- ending.sylvia.special
- ending.priscilla_lavinia

Unknown ending IDs MUST be rejected. Legacy unprefixed IDs MUST migrate. The legacy lavinia_priscilla pair MUST migrate to priscilla_lavinia without double-counting.

Gallery recording MUST unlock primary_id and, when non-null, epilogue_id as two independent idempotent transactions before COMPLETED. Replaying an EndingPlan MUST NOT duplicate either unlock.

playback_stage is PRIMARY_PENDING, PRIMARY_COMPLETED, EPILOGUE_COMPLETED, or GALLERY_RECORDED. The run checkpoints each transition and resumes the first incomplete stage after load. When epilogue_id is null, PRIMARY_COMPLETED transitions directly to GALLERY_RECORDED.

## 8. Contact and Invitation State

Chat history and actionable invitation state are separate.

History is append-only. Superseding or resolving an invitation MUST NOT delete generated messages.

Each contact stores a read watermark over append-only message sequence numbers. Opening a contact advances only that contact's watermark through its latest visible message. It MUST NOT answer an invitation. reply_required remains independent.

Every next-day message is appended unread. Resolving an offer closes its reply action while retaining all history.

Read-only queries MUST NOT mutate state or emit signals.

### 8.1 Solo invitation resolution

Solo action state is AVAILABLE, ACCEPTED, RESOLVED_UNANSWERED, RESOLVED_ATTENDED, RESOLVED_MISSED, SUPERSEDED, or RESOLVED_RUN_END. Each solo action stores its offer_message_id and transaction_id. solo reply_required is true only in AVAILABLE. The first reply transitions AVAILABLE to ACCEPTED and makes the solo date addable to Schedule. Repeated replies are idempotent.

| Day-end condition | Required result |
|---|---|
| Never opened and unanswered | Retain offer history; append ordinary nevermind next day |
| Opened and unanswered | Retain offer history; append the same nevermind next day |
| Replied and attended | Resolve date normally |
| Replied and not attended | Append missed_question next day |

Solo invitations MUST NOT produce busy, judge, or twofriends.

On Days 1 through 6, an unanswered solo offer transitions to RESOLVED_UNANSWERED after its nevermind is appended. An accepted attended offer transitions to RESOLVED_ATTENDED. An accepted unattended offer transitions to RESOLVED_MISSED after missed_question is appended. Day 7 instead uses RESOLVED_RUN_END without a next-day message.

### 8.2 Group activation

On Days 2 and 6, the group offer becomes available on the atomic round-count transition from two completed rounds to three only if, for each of Priscilla and Lavinia, the current solo action is AVAILABLE, has zero replies, and references an offer_message_id from that action's transaction_id whose sequence is greater than that contact's read watermark. This is the complete eligibility predicate.

Activation atomically supersedes both solo offers. Existing history remains; superseded actions become unavailable and stop independent rollover.

Group action state is INACTIVE, AVAILABLE_UNOPENED, REPLY_REQUIRED, ACCEPTED, RESOLVED_UNANSWERED, RESOLVED_ATTENDED, RESOLVED_MISSED, or RESOLVED_RUN_END. It stores fixed participant_ids, inviter_id or null, opened_ids, replied_ids, history_generated, and a stable transaction_id.

The group offer initially enters AVAILABLE_UNOPENED with no inviter_id. No group-offer text is generated until a participating contact is opened.

Opening either participant first MUST:

1. Assign that participant as presentation-only inviter_id.
2. Atomically generate paired group-offer history for both contacts.
3. Select first and second opening variants.
4. Add the participant to opened_ids and transition AVAILABLE_UNOPENED to REPLY_REQUIRED.
5. Mark the opened contact read while the other participant's generated message remains unread.

inviter_id affects only message presentation and group-date image positioning. Angela MAY reply to either participant first.

Opening the second participant reuses the existing group transaction, does not reassign inviter_id, and does not append duplicate history. It adds that participant to opened_ids and advances only that contact's read watermark through the already generated second-opening variant.

The first unique reply adds the participant to replied_ids, transitions REPLY_REQUIRED to ACCEPTED, and makes the group date addable to Schedule. A second participant may still reply before resolution; that reply only adds the second ID. Repeated replies are idempotent.

A participant's reply action is enabled only when group state is REPLY_REQUIRED or ACCEPTED and that participant is absent from replied_ids. Group reply_required is true while either participant remains replyable. Schedule addability is true when replied_ids contains at least one participant and the group state is ACCEPTED.

### 8.3 Group resolution

| Day-end condition | Required result |
|---|---|
| Neither contact opened and zero replies | Generate no group-offer history; append unread busy to both next day |
| At least one contact opened and zero replies | Retain group-offer history; append ordinary nevermind to both next day |
| One reply and date attended | Use unreplied participant's judgmental date variation; append judge from that participant next day |
| Both replied and date attended | Use normal group-date variation; append no judge |
| One or two replies and date not attended | Increment missed-group count, play twofriends, and append missed_question to both next day |

A group date prevented by fainting counts as not attended. Hospital plays before twofriends.

The table applies to Days 1 through 6. Each branch atomically transitions the action to RESOLVED_UNANSWERED, RESOLVED_ATTENDED, or RESOLVED_MISSED and closes further replies. Day 7 uses RESOLVED_RUN_END and generates none of the table's next-day consequences.

The message types remain distinct:

- busy: untouched group opportunity.
- nevermind: visible or opened offer left unanswered.
- judge: attended after replying to one participant.
- missed_question: accepted offer not attended.

There is one reusable nevermind type. Resolution branches are mutually exclusive.

Every appended message and invitation effect MUST use a stable transaction ID to prevent duplicates after load or repeated completion signals.

## 9. Save, Restore, and Profile Persistence

### 9.1 Files

Persistence is divided into:

- profile.json for permanent global profile data.
- Schema-versioned JSON slot files containing the current run snapshot and its recovery journal.

New Game and slot load MUST NOT clear or replace the profile.

Profile data includes:

- Gallery unlocks.
- Global visited line IDs.
- Language.
- Volumes and mute settings.
- Accessibility preferences.
- Input mappings.
- Auto and skip settings.

### 9.2 NarrativeSnapshot

Each run save contains a primitive-only, allowlisted NarrativeSnapshot:

- Stable run_id.
- Lifecycle and Day 1 through Day 7 state.
- Stable scene and narrative checkpoint IDs plus checkpoint_sequence.
- Active DayResolutionPlan or null.
- Validated gameplay variables.
- Contact, invitation, schedule, dating, and ending state.
- Semantic Dialogic checkpoint state.
- Applied effect transaction IDs.
- Semantic audio context.
- Schema and content compatibility versions.

No Node, Resource, Callable, arbitrary resource path, or serialized executable object is allowed.

Canonical saves MUST remain JSON. store_var and get_var with object loading MUST NOT be used for canonical player saves.

### 9.3 Stable checkpoints

An in-memory checkpoint is committed after:

- Every fully committed dialogue line.
- Player choice.
- Variable or effect transaction.
- Safe marker.
- Scene transition.

Manual and quick saves write the latest stable checkpoint. A save request during transition is deferred until the next stable commit.

Every checkpoint bundle has a monotonically increasing checkpoint_sequence scoped to its run.

Each disk slot stores:

- current_snapshot: the latest stable checkpoint selected for that save.
- recovery_journal: ordered immutable earlier checkpoint bundles.

The journal permanently retains semantic anchors created at day start, timeline start and completion, choice, variable or effect transaction, safe marker, scene transition, pre-board, post-result, and DayResolutionPlan stage completion. It also retains the 32 greatest checkpoint_sequence line-only bundles earlier than current_snapshot; RECOVERY_LINE_HISTORY_LIMIT is 32. After a successful atomic slot write, older non-anchor line-only bundles are pruned. Semantic anchors remain until the slot is replaced or deleted.

Manual, quick, auto, and logout saves atomically write current_snapshot and recovery_journal together. Journal bundles use the same primitive allowlist and schema validation as current_snapshot. Migration validates and migrates each retained bundle independently; an invalid journal candidate is excluded with a diagnostic and MUST NOT contaminate another bundle.

### 9.4 Minesweeper save behavior

Before entering a board:

- Commit a stable checkpoint.
- Write a disk autosave.

While a board is active:

- Disable all save controls and shortcuts.
- Do not show a quick-save recommendation.
- Do not show an unavailable message, toast, or dialog.
- Ignore save input without queuing a deferred save request.

After the result commits:

- Commit a post-result in-memory checkpoint.
- Re-enable saving.

### 9.5 Restore transaction

Restore preparation order is:

    read
    parse
    migrate
    validate
    construct detached run candidate
    construct registered route plan
    construct validated Dialogic restore plan

Live state MUST remain untouched unless preparation succeeds. After preparation, restore MUST acquire a restore lock and commit the run candidate, route, and Dialogic plan as one operation. Any application failure MUST restore the captured pre-load state and emit no mutation or run_restored signal. Success emits exactly one run_restored signal.

Missing fields use schema defaults. They MUST NOT inherit stale values from the current session.

### 9.6 Irreversible application-fatal mutation fence

ApplicationBootstrap MUST construct and inject exactly one ApplicationMutationGate. Only restore and new_run are acquire owners; fatal is a separate irreversible latch, not a third owner and not a second gate. The common gate interface includes `latch_fatal(failure)` and `is_fatal_latched()` in addition to acquire, release, external guard, active-owner inspection, and internal-owner inspection.

A fatal failure has exactly `source`, `phase`, `code`, and primitive-only detached `details`. Invalid input MUST NOT latch. The first valid failure is retained permanently and disables mutation/input exactly once; an identical repeat is idempotent; a different valid repeat returns APPLICATION_FATAL_CONFLICT and preserves the first failure. Latching MUST NOT create, replace, or clear an acquire owner/token. After latching, acquire, release, and every guarded public mutation return APPLICATION_FATAL before other validation; no internal owner remains authorized; InputManager remains blocked for the rest of the process. There is no unlatch API.

Every rollback or recovery failure that cannot prove a consistent live state MUST call this shared latch before returning. Restore, new-run, day-resolution/checkpoint, and Minesweeper paths MUST delegate to the injected gate and MUST NOT invent a subsystem-local fatal Boolean or second mutation gate.

Malformed nested types, out-of-range days, unknown IDs, arbitrary paths, and unsupported future schemas MUST fail safely.

If content removes a saved checkpoint, recovery MUST select from the persisted recovery_journal the compatible bundle with the greatest checkpoint_sequence less than current_snapshot's sequence. Compatibility requires the complete gameplay state, route ID, timeline ID, marker ID, schema version, and content version to validate together. Fields from different checkpoints MUST NOT be combined. It MUST NOT rewind only the narrative pointer while retaining later gameplay variables.

The restored line appears fully revealed. Presentation animation and semantic audio restart. Literal tween position, audio sample position, and partially revealed character count are not preserved.

### 9.7 Migration

Incremental migrations MUST cover:

- Legacy Day 8 saves.
- Reversed pair IDs.
- Unprefixed ending IDs.
- Profile data formerly stored inside run state.
- Older snapshot schema versions.

Canonical ending IDs pass through unchanged. The only accepted legacy ending-ID mappings are:

| Legacy ID | Canonical ID |
|---|---|
| alone | ending.alone |
| priscilla.sweet | ending.priscilla.sweet |
| priscilla.dark | ending.priscilla.dark |
| priscilla.true | ending.priscilla.true |
| lavinia.sweet | ending.lavinia.sweet |
| lavinia.dark | ending.lavinia.dark |
| lavinia.true | ending.lavinia.true |
| sylvia.sweet | ending.sylvia.sweet |
| sylvia.dark | ending.sylvia.dark |
| sylvia.true | ending.sylvia.true |
| sylvia.special | ending.sylvia.special |
| priscilla_lavinia | ending.priscilla_lavinia |
| lavinia_priscilla | ending.priscilla_lavinia |

Any other ending ID is rejected recoverably. In pair-valued fields and structured invitation keys, the legacy pair token lavinia_priscilla maps to priscilla_lavinia. Migration MUST apply that token mapping to missed-group counts, inter-friend state, invitation state, route context, and gallery data without merging counts twice or duplicating history.

Legacy Day 8 migration uses this deterministic table:

| Legacy evidence | Migration result |
|---|---|
| Legacy group ending used as primary plus sufficient synchronized Day 7 ending inputs | Recompute a non-group primary through DatingEndingRules, set ending.priscilla_lavinia as epilogue, set day to 7, and preserve ENDING or COMPLETED |
| Valid completed or ending lifecycle plus a valid non-group canonical or migratable primary | Set day to 7 and preserve the mapped ENDING or COMPLETED lifecycle and plan |
| PLAYING on Day 8 plus at least one compatible Day 7 checkpoint bundle | Restore the compatible Day 7 bundle with greatest checkpoint_sequence |
| Legacy group primary without sufficient synchronized inputs, or any invalid plan, plus a compatible Day 7 bundle | Restore the compatible Day 7 bundle with greatest checkpoint_sequence |
| No valid ending plan and no compatible Day 7 bundle | Reject the slot recoverably without mutating live state |

Migration MUST NOT treat ending.priscilla_lavinia as a valid new primary and MUST NOT invent a replacement primary. Migrating historical gallery data preserves only physically recorded unlocks; reconstructed ending state does not grant an unseen gallery unlock.

Writes MUST use a temporary file, validation, atomic replacement, and a recoverable previous backup.

Tests MUST receive an injected temporary storage adapter and MUST NOT touch production user save paths.

## 10. Dialogic and Narrative Effects

Dialogic is the sole narrative playhead.

Execution is:

    Dialogic event
    DialogicBridge validation
    EffectResolver whitelist
    domain command
    transaction receipt
    stable checkpoint
    narrative resume

DialogicBridge validates timeline IDs, markers, effects, variables, and ending IDs against exact manifests. A broad filename-pattern match is insufficient.

Unknown narrative IDs MUST be rejected before state mutation.

Effect transactions MUST be idempotent.

Dialogue boxes, choice panels, history panels, portraits, and chat bubbles render Dialogic state. They MUST NOT own another timeline index or write gameplay variables directly.

### 10.1 Read history and skip

ProfileManager stores globally visited stable line IDs across slots and new games. Visible dialogue logs remain run-specific.

skip_mode is:

- read_only by default.
- all_text when explicitly selected.

Skip always reveals the current line immediately.

For read_only, eligibility is evaluated before a newly revealed line is marked visited. If the current line was unread, it becomes visible and visited, then automatic advancement stops.

For all_text, advancement may continue through unread lines.

Every line passed by skip becomes visited.

Skip MUST stop at:

- Choices.
- Gameplay-effect transactions.
- Stable markers.
- Scene transitions.
- Minesweeper entry.
- Validation errors.

Skip stops before consuming a listed boundary event. It MUST NOT execute the boundary's choice, effect, marker, route, or Minesweeper-entry command.

Settings MUST expose exactly read_only and all_text, persist the selected skip_mode through ProfileManager, apply changes immediately, and default a missing or invalid persisted value to read_only. New Game MUST NOT reset skip_mode.

### 10.2 Timeline content status

Every timeline has one content status:

- placeholder
- draft
- approved
- final

Phase 3 MAY integrate placeholders. Placeholders MUST NOT pass a narrative-complete or release gate.

Timeline status is stored in the exact timeline manifest. A timeline containing a TODO marker MUST initially be placeholder. A timeline without a TODO marker and without explicit approval evidence MUST initially be draft. Only explicit approval evidence may assign approved or final.

Phase 2R validates structure, IDs, markers, branches, effects, and transitions. It MUST NOT invent dialogue prose.

## 11. Phase 3 Desktop and Minesweeper Contract

Phase 2R defines and contract-tests this section's registered IDs, interfaces, save-lock semantics, and deterministic fixtures. Phase 3 owns player-facing scene composition and simulator wiring. Phase 6 owns the real board adapter.

### 11.1 Desktop app host

ComputerDesktop is a composition root with:

- An icon grid.
- One DesktopAppHost.
- A closed registry from stable app IDs to approved scenes and focus targets.

Saved data may contain an app ID. It MUST NOT contain an arbitrary scene path.

Only one app is visible:

1. Opening lazily instantiates it once.
2. Switching hides the previous app.
3. Focus transfers into the active app.
4. Closing hides it and returns focus to its icon.
5. Hidden app instances remain cached only for the current day.
6. Day transition destroys the cache.
7. Persistent data remains in domain modules.

ApplicationBootstrap is the only day-change consumer for desktop state. It connects to the committed GameState.day_changed signal exactly once, calls DesktopAppHostState.change_day(new_day) exactly once, and dispatches that method's one immutable eviction command through exactly one registered Phase-3 desktop-eviction port. Phase 3 registers and consumes that port; it MUST NOT connect a second desktop day-change handler or call change_day directly.

Plan 05 has already configured one SaveManagerNarrativeCheckpointPort around the one real SaveManagerCheckpointPort and six stable provider Callables. Its Bootstrap-owned active_app_id Callable returns JSON null before the desktop host exists. When Plan 06 constructs the one DesktopAppHostState, Bootstrap MUST update only the private host slot read by that existing Callable; it MUST NOT replace the Callable, narrative adapter, real checkpoint port, or the adapter identities retained by DialogicBridge and GameState. The direct checkpoint provider and narrative Callable therefore read the same Bootstrap-owned host rather than creating a second desktop-state authority.

There is no overlapping draggable-window or z-order system.

Contacts, Schedule, Shop, Backup, Settings, and Logout remain presentation modules over their owning facades.

Logout Yes writes the latest stable checkpoint when one exists and returns to Menu without completing the run. If no stable checkpoint exists, it returns to Menu without writing a slot. Logout No restores desktop focus.

Dates, Hospital, and endings use registered semantic routes.

### 11.2 Phase 3 Minesweeper simulator

Phase 3 implements the real round interface with an explicitly labeled deterministic result simulator.

Flow:

1. Select an approved difficulty.
2. Start through the real round interface.
3. Commit the pre-board checkpoint and disk autosave.
4. Lock saving.
5. Select a predefined result fixture.
6. Call the same complete_round interface used by the future board.
7. Apply real rewards, counters, health, messages, fainting, and invitation activation.
8. Commit the post-result checkpoint.
9. Unlock saving.

The simulator MUST NOT generate a fake random board or mutate domain state directly.

Phase 6 replaces only the simulator adapter. Domain effects, tests, and the round interface remain.

Before the Phase-3 handoff issue closes, both desktop_contract.json and minesweeper_contract.json MUST be canonical checked-in artifacts backed by strict duplicate-rejecting schemas, deterministic generators, validators, source-byte bindings, binding-mutation tests, and immutable isolated command records. Fresh regeneration MUST be byte-equal to each checked-in artifact. The desktop artifact binds registry/host/persistence/day-eviction ownership plus the stable narrative-provider identity handoff; the Minesweeper artifact binds ports, fatal-latch delegation, transaction phases, save-lock behavior, and fixtures.

## 12. Audio and Preferences

AudioManager exclusively owns:

- Live AudioStreamPlayer nodes.
- Music and ambience selection.
- Buses and mute state.
- Crossfades and active tweens.
- SFX playback.
- Semantic audio-context resolution.

GameState audio_state MUST be removed.

Callers request registered semantic audio context IDs. They MUST NOT submit resource paths.

Run snapshots save semantic music and ambience context only. They MUST NOT save streams, player objects, tweens, timestamps, or bus objects.

Loading resolves and restarts semantic audio context.

ProfileManager owns linear volume and mute preferences in the inclusive range 0.0 through 1.0. AudioManager clamps committed values to that range, treats values at or below the constant VOLUME_SILENCE_THRESHOLD = 0.0001 as silent, and converts larger values to bus decibels. Explicit mute remains authoritative regardless of volume.

InputManager, AccessibilityManager, LocalizationManager, Dialogic presentation, and AudioManager apply their relevant profile preferences.

New Game MUST NOT clear preferences.

Explicit, separately confirmed operations handle:

- Preference reset.
- Visited-history reset.
- Gallery reset.
- Entire-profile reset.

## 13. Custom JSON Localization

The runtime localization pipeline MUST NOT call, configure, register project content with, or depend on TranslationServer. Project UI uses the custom JSON pipeline defined here. Narrative localization also MUST NOT use TranslationServer, but its custom file adapter remains deferred under Section 19.

### 13.1 Runtime files

The initial runtime structure is:

    localization/
      manifest.json
      fonts/
      ui/
        en.json
        zh_CN.json
        zh_HK.json

manifest.json is schema-versioned and records:

- Source locale ID.
- Explicit locale alias map.
- Canonical locale ID.
- Native display name.
- Fallback locale.
- Release status from source, draft, or release.
- Whether the locale is selectable.
- UI file.
- Font profile.
- Layout direction.

The JSON shapes are:

    manifest.json = {
      "schema_version": 1,
      "source_locale": "en",
      "aliases": [{"input": "zh_hk", "locale": "zh_HK"}],
      "font_profiles": [FontProfileRecord, ...],
      "locales": [LocaleRecord, ...]
    }

    FontProfileRecord = {
      "id": String,
      "font_files": [String, ...],
      "fallback_profile": String or null
    }

    LocaleRecord = {
      "id": String,
      "native_name": String,
      "fallback_locale": String or null,
      "release_status": "source" | "draft" | "release",
      "selectable": bool,
      "ui_file": String,
      "font_profile": String,
      "layout_direction": "ltr" | "rtl"
    }

    locale file = {
      "schema_version": 1,
      "locale": String,
      "messages": [{"id": String, "text": String}, ...]
    }

Manifest paths MUST be relative descendants of localization/, MUST resolve through registered manifest records, and MUST reject absolute paths, schemes, parent traversal, and fallback cycles.

font_profile is a semantic FontProfileRecord ID, never a path. font_files are manifest-registered relative descendants of localization/fonts/. A profile with an empty font_files array uses the project's default font. Font-profile fallback chains MUST be acyclic.

Exactly one LocaleRecord MUST have release_status source; its id MUST equal source_locale and its fallback_locale MUST be null. Every other fallback chain MUST terminate at source_locale. Locale IDs, alias inputs, font-profile IDs, and message IDs MUST be unique, and each locale file's locale value MUST equal its LocaleRecord id. The loader MUST reject duplicate JSON object member names before materialization. Phase 2R MUST provide and execute JSON Schema and semantic validation for every file shape.

Locale input is resolved by exact canonical ID, then by the explicit alias records. Unregistered inputs are rejected. The initial aliases include zh_hk to zh_HK.

### 13.2 Extraction

The current hardcoded LocalizationManager tables MUST be extracted exactly: 50 en source keys and 25 direct keys in each Chinese locale before additional literal scene text is cataloged.

Before the embedded tables are deleted, an extraction equivalence test MUST compare every key and exact string value in all three extracted catalogs against the current tables. Counts alone are insufficient.

English is the source catalog. Existing zh_CN and zh_HK values are preserved. Missing Chinese entries fall back to English and are reported as incomplete.

Generated ending titles MUST be materialized as ordinary translatable keys.

Placeholder sets such as {quantity} and {friend_name} MUST match the source catalog exactly.

en is the source locale. zh_CN and zh_HK remain selectable draft locales with explicit English fallback until coverage validation passes. A draft locale MUST be visibly identified as incomplete and MUST NOT be falsely presented as complete.

### 13.3 LocalizationManager

LocalizationManager becomes a coordinator and JSON loader. It MUST:

- Load and validate manifest.json.
- Load locale files through registered safe paths.
- Expose selectable locale records.
- Read and write the preference through ProfileManager.
- Resolve explicit fallback without cycles.
- Format validated named parameters.
- Emit one post-commit locale_changed signal.
- Resolve the locale's validated font and layout profile for presentation roots.

It MUST NOT embed translated text tables in GDScript.

Lookup checks the requested locale, then follows registered fallback_locale links until the source locale. A missing source key returns [missing:key] and emits at most one warning per key. Every translated message MUST have exactly the source message's named placeholder set. Runtime parameters MUST exactly match that set; mismatch returns [format_error:key] and emits at most one warning per key.

Locale switching is atomic: load and validate the candidate locale, fallback chain, and font profile; prepare presentation state; apply successfully; commit the ProfileManager preference; then emit locale_changed. Any failure preserves the previous locale, presentation, and persisted preference and emits no locale_changed signal.

LocalizedBinding is the single automatic UI text binding component. It stores target_path, a target_property from text, placeholder_text, tooltip_text, or accessibility_name, a localization key, and named parameters. It validates its target, property, and key and refreshes on ready, committed parameter change, and locale_changed. Dynamic presenters MAY call LocalizationManager directly.

The existing LocalizedText stub receives a replace disposition. Every scene consumer MUST migrate to LocalizedBinding before LocalizedText is removed.

Each top-level localized scene uses one LocalePresentationRoot. It resolves the selected semantic font profile through LocalizationManager and applies registered fonts and layout_direction through inherited Control theme and layout properties. It MUST NOT walk the scene tree. Recursive tree traversal and method-name guessing MUST be removed.

Settings MUST populate its language selector from selectable manifest records and display draft status. Adding a UI locale MUST require only a manifest record, a locale JSON file, and referenced font profile; it MUST NOT require a GDScript edit.

### 13.4 Narrative localization

Only English narrative files currently exist. The project MUST NOT claim zh_CN or zh_HK narrative coverage.

Narrative localization remains a separate decision_required record until representative external localized narrative files are present.

Phase 2R MAY validate the English timeline structure and UI locale files. It MUST NOT invent a narrative file adapter without physical source and translated examples.

## 14. Testing and Evidence

The project keeps GUT and remains GDScript-only.

### 14.1 Test layers

- Pure domain tests for RefCounted modules.
- Facade integration tests for atomic mutation and typed signals.
- On-tree scene tests for ready callbacks, signals, focus, and navigation.
- Adapter contract tests for storage, localization, and Minesweeper.
- Consequential scenario tests for Days 1 through 7.

Scenario coverage MUST include:

- No Day 8.
- Hospital before twofriends.
- Every solo and group invitation branch.
- Primary ending plus optional epilogue.
- Save migration and earlier-checkpoint fallback.
- Both skip modes.
- Localization extraction, fallback, alias, and placeholder validation.
- Minesweeper round-interface, save-lock, and domain-effect contract tests using deterministic non-player fixtures.

### 14.2 Isolation

Tests use unique temporary save and profile roots.

Global state is rebuilt from fresh defaults per test.

Nodes are added on-tree and automatically freed.

Random outcomes and wall-clock behavior are replaced with deterministic fixtures.

The Dialogic smoke stub MUST be replaced by:

- Exact manifest validation.
- A real fixture timeline.
- A line.
- A choice.
- A marker.
- An effect transaction.
- Completion.
- Restore.

### 14.3 Phase 2R gate

Phase 3 remains blocked until:

- Every active, Phase-2R-blocking approved requirement has valid verification evidence.
- All GUT tests pass.
- Required Phase 2R scenes parse and instantiate on-tree.
- Project-owned orphan nodes, unfreed children, leaked resources, and unexpected errors equal zero.
- No unconditional-pass stub remains.
- Tests prove production save paths are unreachable.
- Documentation, localization, timeline, ending, audio, and snapshot validators pass.
- A generated report records commands, engine and addon versions, counts, diagnostics, and requirement IDs.
- The tested subject commit contains the two tracked Beads journals with children .1 through .9 closed, .10 in_progress, and the epic open. The evidence-seal child changes no Beads path; the optional closure child changes exactly those same two journals to close .10 and the epic.
- Build-validator and closure-validator output use two immutable completed log files. No validator hashes bytes that are still being appended, and the evidence seal binds all completed subject and validator logs.

Third-party diagnostics require an explicit machine-readable exception with reason and expiry.

Phase 2R verification is pinned to the Godot 4.6 line and uses installed Godot 4.6.3 for the initial evidence run.

The malformed duplicate config_version entry in project.godot MUST be removed and guarded by a configuration test.

## 15. Beads and Tooling

Beads is the durable execution system.

The duplicate My first issue placeholders are deleted.

Phase 2R is represented by an epic with bounded child issues for:

1. Documentation schema and context bootstrap.
2. Repository CodeGraph removal.
3. Profile, localization, and audio ownership.
4. GameState decomposition and lifecycle.
5. Snapshots and storage.
6. Contacts and invitations.
7. Schedule, Hospital, dating, and endings.
8. Dialogic, effects, history, and skipping.
9. Phase 3 handoff contracts for desktop composition and the Minesweeper simulator.
10. Integration and the evidence gate.

Each child records:

- Requirement IDs.
- Scope and exclusions.
- Dependencies.
- Acceptance criteria.
- Verification commands.
- Evidence links.

Minimum Beads CLI sequence is:

    bd prime
    bd ready --json
    bd show <issue-id> --json
    bd update <issue-id> --claim
    bd close <issue-id> --reason "<evidence-backed reason>"

Angle-bracket tokens are required operator substitutions, not literal arguments. After claim and before close, the agent MUST load only the requirements referenced by the issue, implement its scope, and run its recorded verification commands. The close command is permitted only after every acceptance criterion has linked passing evidence.

Human decisions use Beads blockers. Markdown TODO files MUST NOT become the work source of truth.

## 16. CodeGraph Removal

Repository CodeGraph integration MUST be removed because it does not index project GDScript or Godot scene relationships and therefore provides no unique project value.

Removal includes:

- Delete repository .codegraph data and configuration.
- Remove CodeGraph-first instructions.
- Remove active CodeGraph references from Prompt and phase documentation.
- Verify zero active project consumer remains.

The global CodeGraph installation MUST remain untouched.

Replacement capabilities are:

- Beads for durable work status.
- Requirement IDs and generated indexes for context.
- Exact manifests for timelines, routes, audio, endings, and locales.
- Godot-aware behavioral tests.
- Direct rg inspection.

Repository CodeGraph removal requires the first, second, and final replacement capabilities above to be operational and validated: Beads issue lookup, requirement-ID/generated-index context lookup, and a verified rg inspection workflow. Exact domain manifests and Godot behavioral tests are later improvements and are not prerequisites for removing an index that contains no project GDScript or scenes.

## 17. Execution Strategy

Each bounded child issue follows:

    migrate requirements
    add a failing behavioral test
    repair implementation
    run focused verification
    run required broader verification
    attach evidence
    delete superseded material
    close Beads issue

The verified replacement for each removed artifact or instruction MUST exist before that specific destructive removal.

Recommended implementation order:

1. Capture baseline and preserve user-owned worktree changes.
2. Establish documentation schema, validators, context loading, and generated index.
3. Remove repository CodeGraph integration.
4. Establish ProfileManager, custom localization, and audio ownership.
5. Extract GameState run modules and repair lifecycle.
6. Implement safe snapshots, migrations, and isolated storage.
7. Implement invitation, schedule, Hospital, dating, and ending rules.
8. Repair DialogicBridge, effects, history, and skip behavior.
9. Define and contract-test the Phase 3 desktop registry, round interface, save lock, and deterministic fixtures; do not wire the player-facing simulator.
10. Run scenario integration and the full Phase 2R evidence gate.
11. Run the final disposition and reference audit, then delete any fully migrated validated residue.

Existing dirty worktree changes are user-owned. Implementation MUST preserve unrelated edits and MUST NOT rewrite modified skill directories.

## 18. Alternatives Rejected

### Patch current prose and GameState in place

Rejected because authority, ownership, and drift would remain ambiguous.

### Rewrite all documentation before runtime repair

Rejected because approved docs would describe unimplemented behavior for an extended interval.

### Repair all runtime behavior before documentation

Rejected because contradictory instructions would remain active during implementation.

### Canonical store_var saves

Rejected because canonical player saves require a primitive allowlist, explicit migration, and no object-loading risk.

### Universal EventBus

Rejected because typed owner signals and direct commands provide clearer ownership.

### Duplicate localized Dialogic trees without evidence

Rejected for Phase 2R because only English narrative files are physically present and no representative external narrative translation format has been provided.

### TranslationServer content pipeline

Rejected because the user requires custom already-localized files and approved a custom JSON locale pipeline.

### Fake random Minesweeper board

Rejected because it would disguise unfinished Phase 6 gameplay and create a throwaway interface.

### Retain CodeGraph repository integration

Rejected because the index contains no project GDScript or Godot scene graph.

## 19. Deferred Decisions

### decision.localization.narrative_file_adapter

- decision_status: decision_required.
- Known evidence: 61 English Dialogic timeline files exist; no zh_CN or zh_HK timeline or representative external localized narrative file is present.
- Scope: the adapter and schema for importing future non-English Dialogic narrative files.
- Affected requirements: narrative locale import, narrative fallback, translated-timeline validation, and narrative coverage reporting.
- Blocking relationship: blocks narrative translation import only. It is explicitly excluded from the Phase 2R evidence gate and does not block English structural integration or custom UI JSON extraction.
- Recommended investigation: obtain at least one representative source-language narrative file and its matching translated file, then compare identifiers, branches, markers, effects, interpolation, and encoding before proposing an adapter.

The decision MUST NOT be marked resolved without that physical file pair and recorded comparison evidence.

## 20. Written-Spec Review Gate

This file records the approved conversational design and received explicit written-spec approval on 2026-07-17.

Completed gate evidence:

1. The specification passed self-review for placeholders, contradiction, scope, and ambiguity.
2. The user reviewed and explicitly approved this written file.

Completed implementation gate evidence:

1. The dated master plan and six bounded child plans were written and passed structural, syntax, link, dependency, ownership, fatal-recovery, and cross-interface audits.
2. On 2026-07-18, the user explicitly requested execution of Phase 2R after plan completion.

Phase 2R implementation is therefore authorized in dependency order. Execution uses Inline mode unless the user later explicitly requests delegation. This authorization permits task-scoped runtime, test, scene, active-document, localization, configuration, evidence, and ordinary Beads execution updates described by the approved plans. It does not grant Git commit/push/history authority, archive/legacy deletion authority, evidence-seal authority, post-seal Beads-closure authority, or authority over preserved user-owned dirty paths; each remains behind its separately named gate. Repository CodeGraph removal may occur only at its Plan-01 prerequisite boundary and under the user's earlier exact repository-removal authorization; the global installation remains forbidden.
