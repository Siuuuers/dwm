---
id: note.canonical_spoken_scene_agency_disposition
kind: design_disposition
schema_version: 1
decision_status: accepted
owner_choice: no_player_selectable_narrative_choices
owner_choice_on: "2026-08-21"
current_direction: minesweeper_result_driven_scene_branching
conversational_design_status: approved_owner_correction
conversationally_approved_on: "2026-08-21"
written_spec_status: pending_owner_review
implementation_requested: false
implementation_authorized: false
created_on: "2026-08-21"
audience: private_spoiler_complete
scope: ["canonical_spoken_scene_no_inline_choices","narrative_choice_state_retirement","minesweeper_result_handoff","external_application_operation_exclusion"]
related_authorities: ["spec.haunted_instrumentarium_ui_manual_foundation_decisions","spec.narrative_scene_host_dating_hospital_challenge_ui_ux_amendment","spec.title_art_placement_bottom_up_scene_caption_rhythm_amendment","spec.ordered_ending_host_universal_pause_ui_ux_amendment","spec.settings_preferences_ui_ux_amendment"]
---

# Canonical Spoken-Scene Agency Disposition

## 1. Accepted correction

The project owner confirmed on 2026-08-21 that the game contains no
player-selectable narrative choices. Apparent narrative branching during a
Dating scene comes from the durably committed Minesweeper result, not from a
dialogue-option surface or a player-selected result.

This disposition strengthens the existing no-inline-scene-choice law in the
Haunted Instrumentarium UI Manual foundation. It retires the latent choice
state and interaction machinery that later or older scene-host documents still
described despite that law. It does not change story content, result mapping,
route facts, or Minesweeper mechanics, and it authorizes no implementation.

## 2. Canonical witnessed-scene boundary

Canonical authored scene playback includes Dating, visible
Priscilla-Lavinia, Hospital, ordered-ending scenes, and Gallery or Rehearsal
projections of those same witnessed states.

Those hosts publish no:

- response list or dialogue option;
- moral prompt, route selector, or default answer;
- player-authored Angela line;
- disabled, locked, hidden, silhouetted, or counted alternative;
- narrative addressee chip, identity colour, or choice icon; or
- prompt inviting the audience to select a Minesweeper result or its
  consequence.

Scenes consume already committed Contacts, Schedule, route, ending-plan, and
Minesweeper-result facts. They may vary lawful dialogue and staging from those
facts, but the witnessed-scene UI never asks the audience to choose the same
fact again.

## 3. Retired narrative-choice machinery

Within the scoped hosts, the following concepts are retired rather than merely
hidden:

- `UNRESOLVED_CHOICE` and any equivalent scene-host phase;
- narrative choice IDs, commands, receipts, blocks, and public choice sets;
- choice layout, scrolling, focus targets, navigation, and return-focus state;
- choice-specific transport stops, Back precedence, modal restoration, and
  failure paths;
- committed or open narrative-choice save fields and restore branches;
- choice lists, roles, addressee metadata, and announcements in assistive
  projection; and
- choice-specific localization, colour, motion, verification, and compatibility
  branches.

A legacy internal record called a choice cannot become player input by name.
If retained content or scaffolding still encodes a conditional continuation as
a choice, it must be reconciled to its actual app-owned or result-owned fact
before the witnessed host can consume it. No legacy choice mode or hidden
compatibility surface is authorized.

Removing choices does not collapse the Room-Owned Aperture, caption region, or
control rail. Capacity once reserved for an inline choice surface remains
ordinary caption wrapping, localization, and text-size reserve.

## 4. Minesweeper is agency, not a result picker

The player chooses lawful Minesweeper operations. The board engine derives and
durably commits the board-result receipt. The coordinator consumes that board
truth, commits and applies the registered consequence in its accepted order,
and freezes the validated post-scene context. The narrative host owns neither
raw board-result interpretation nor consequence mutation. The audience never
selects `Exploded`, `Solved`, `Perfect`, or a relationship consequence from a
narrative menu.

At the accepted challenge boundary:

1. the settled witnessed scene freezes under the board takeover;
2. captions and the narrative control rail withdraw;
3. the board exclusively owns input and focus;
4. the board engine commits one exact terminal/result receipt;
5. the coordinator commits and applies the registered consequence;
6. the coordinator freezes the validated post-result continuation context; and
7. the narrative host publishes that exact witnessed state without an intervening
   result selector, result card, relationship summary, reward report, or extra
   confirmation.

The accepted non-Perfect solo terminal operations—operational `Continue` and
activation of the visible marked special mine—remain board commands. They are
not dialogue replies, narrative choice IDs, History entries, or player-selected
relationship results. Perfect, explosion, pair-board results, and other
automatic terminal paths retain their accepted board laws.

## 5. Resulting witnessed-host interaction

- The protected caption region contains the accepted bottom-up caption stack
  above the pinned six-control rail and no reserved choice row.
- Normal Accept completes reveal or, on a later released activation, advances
  one ordinary beat. It never selects a default answer or invokes a terminal
  board operation.
- Initial and restored narrative focus belongs to the current caption or the
  accepted control rail. No narrative choice focus token exists.
- Auto, Skip, and Next retain their accepted marker, effect, challenge,
  completion, modal, recovery, and failure barriers; they have no choice
  barrier to encounter.
- History remains a record of witnessed caption and presentation atoms. It is
  not an input log and creates no `choice made` entry for board operations or
  results.
- Save and restore retain the exact witnessed state, challenge snapshot, and
  committed result/effect/completion facts their existing owners require. They
  persist no open or committed narrative-choice state.
- Assistive reading order proceeds through the public scene facts, current and
  retained captions, and rail. During a challenge, the board's semantic tree
  replaces narrative controls; no narrative choice list or addressee role is
  exposed.

## 6. Explicit exclusions

This disposition does not remove or rename legitimate operations outside
authored scene playback, including:

- Contacts reply operations and invitation availability;
- Schedule drafting and Day-7 destination selection;
- Shop purchases;
- Settings controls;
- Backup, overwrite, delete, reset, or other confirmations;
- Minesweeper cells, flags, modes, pause commands, and accepted terminal board
  operations; or
- ordinary menus, focus movement, and application commands.

Those are operational or domain interactions, not player-authored spoken-scene
responses. Their accepted authorities continue to govern them.

## 7. Precedence and reconciliation

This disposition controls narrative-choice projection and state over
conflicting choice clauses in:

- the Narrative Scene Host, Dating, Hospital, and Challenge amendment;
- the Title Art Placement and Bottom-Up Scene Caption Rhythm amendment;
- the Ordered Ending Host amendment;
- the Settings amendment's retained unresolved-choice transport barrier; and
- the Room-Owned Aperture v1 design.

The older documents remain historical authority for their unrelated laws.
Their caption rhythm, transport, challenge, History, save/load, focus,
accessibility, and recovery requirements remain binding after removal of only
the narrative-choice branches. The Room-Owned Aperture specification has been
surgically corrected to stop re-retaining those branches.

## 8. Deliberately unchanged

This disposition does not decide or alter:

- dialogue, `.dtl` content, event order, calendar placement, or character
  behavior;
- which Minesweeper result maps to which canonical continuation;
- relationship thresholds, route rules, ending identities, or consequences;
- board topology, generation, scoring, terminal mechanics, or result receipts;
- witnessed-scene art, caption material, typography, palette, sound, or motion;
  or
- Godot scenes, resources, scripts, tests, manifests, migrations, or runtime
  compatibility behavior.

Any content record that cannot be projected without reintroducing a narrative
choice blocks later implementation reconciliation; the UI may not invent an
answer or silently select one.

## 9. Reopening rule

Reintroducing a player-selectable spoken-scene response, hidden narrative
choice state, or result-selection surface requires a new explicit owner
decision that supersedes this disposition and the foundation's no-inline-choice
law. Until then, Minesweeper-result-driven continuation is the sole canonical
in-scene branching grammar.
