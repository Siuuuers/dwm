# Lawful-Universe Design Atlas Presence Refinement

> **Archive notice — 2026-08-24:** Retired disposable HTML-prototype evidence.
> This document is non-authoritative and must not be executed or treated as a
> current requirement. See `README.md`.

**Status:** Written specification approved
**Written specification approved:** 2026-08-14
**Date:** 2026-08-14
**Parent:** `2026-08-13-lawful-universe-design-atlas-prototype.md`
**Artifact class:** Disposable visual-prototype refinement; non-authoritative
**Implementation authorization for the Godot game:** False

## 1. Purpose and boundary

Refine the existing Curated Living Atlas so its Shop, trusted prompts, Backup,
narrative composition, and persistent Angela panel express the approved game
more faithfully.

This document controls only the disposable HTML atlas. Accepted design
amendments under `docs/design/` remain the game authority. The atlas still
performs no canonical save, purchase, profile, narrative, Gallery, or run
mutation.

The work is one bounded precision pass. It does not add a Schedule, Pause, or
Minesweeper atlas module, final character art, story prose, or production Godot
implementation.

## 2. Chosen approach

Use a fixed layered presence stage with very small pointer-only parallax. This
approach preserves Angela as an independent authored character while making
the persistent left panel feel physically present.

Rejected alternatives:

- a completely static stage is accessible but loses the requested quiet
  camera-reveal quality; and
- edge-triggered panning makes the audience appear to control the camera and
  weakens Angela's autonomy.

## 3. Shop quantity strip

Batch quantity controls form one nonwrapping logical row in this exact order:

`MIN | - | quantity | + | MAX`

The value is noninteractive. MIN, minus, plus, and MAX retain their accepted
semantics and minimum 48-by-48 or 64-by-64 targets. The exact total and
`Buy xN` remain beneath the selector.

At Large Targets, the fixed inspector cannot contain four 64-pixel actions,
the value, and safe gaps simultaneously. The selector therefore remains one
row inside a local horizontal viewport. Keyboard or controller focus scrolls
the focused action fully into view. It never wraps, shrinks a target, or
changes the catalog/inspector topology.

## 4. Host-local trusted prompts

In-run computer-app confirmations and warnings are mounted inside the
computer-content safe region below the 64-pixel strip. They never cover the
480-pixel Angela panel. Angela and her room remain visible while all lower game
input is inert.

Title confirmations remain inside the title workfield. Narrative, Hospital,
Ending, History, and technical-recovery surfaces retain their own accepted
host layer and are not forced into a desktop computer.

Every trusted prompt keeps its existing behavior:

- Cancel or No receives initial focus where the action is destructive or
  replacing;
- focus is trapped;
- Back or Escape performs the accepted cancel action;
- background controls are inert and absent from assistive traversal; and
- dismissal restores the exact initiating control.

## 5. Centred witnessed scenes

Portraits and full-body tableau figures form one count-aware ensemble centred
on the 1280-pixel canvas. One participant is centred; two and three are
balanced around the same centre axis; four form one centred full group.

The portrait register and tableau use matching participant order and matching
track centres. Authored left-to-right order never changes when the speaker
changes. Speaker emphasis changes only frame treatment and expression.

The existing 104-pixel portrait register, 344-pixel baseline tableau, and
272-pixel caption/control deck remain unchanged.

## 6. Centred transparent caption deck

The protected lower caption deck and pinned 64-pixel transport rail remain in
their accepted regions. Captions do not float into or become interactive over
the tableau.

The visible caption stack is horizontally centred and bounded to approximately
42 to 44 characters. Both the card and its prose use centred alignment, as
approved. Current and prior cards share the same centre axis.

The deck and caption-card surfaces are visually transparent. Readability comes
from a restrained line-level paper backing behind the words rather than an
opaque rectangular panel. The normal backing is approximately 72 percent
opaque; High Contrast may raise it to approximately 94 percent. Focus outlines,
current/prior hierarchy, complete wrapping, and local vertical scrolling remain
fully visible.

## 7. Full-panel Angela art stage

The complete 480-by-720 Angela side is one clipped, non-scrollable art viewport.
Angela and the environment cover the whole panel behind HUD and self-talk.

The authored art is slightly oversized, targeting a minimum 496-by-736 visible
cover region for the 480-by-720 viewport. This overscan prevents any edge from
appearing during camera reveal. Art uses registered focal anchors and cover
cropping; it never stretches.

The stage contains separable decorative layers:

- background environment: at most plus or minus 8 logical pixels horizontally
  and plus or minus 4 vertically;
- midground room objects: at most plus or minus 5 horizontally and plus or
  minus 3 vertically; and
- Angela: at most plus or minus 3 horizontally and plus or minus 2 vertically.

Layers move opposite the pointer, creating a tiny camera reveal rather than
Angela tracking or addressing the audience. HUD, self-talk, keepsake meaning,
focus, and hit regions never move.

## 8. Pointer and motion law

Parallax is decorative and admitted only for a fine pointer while it is inside
the Angela panel. It uses restrained smoothing of about 140 milliseconds.

The art returns to its neutral authored centre over about 180 milliseconds
when the pointer leaves Angela's panel, a trusted modal owns input, the window
loses focus, or the document becomes hidden. A fresh pointer movement is
required before tracking resumes.

Touch, keyboard, controller, and pen input without hover use the neutral centred
composition. Reduced Motion disables only this parallax and keeps the layers
centred; authored pose, expression, content, and scene changes still occur.

There is no pointer capture, device tilt, scrolling, focus target, assistive
node, saved offset, gameplay consequence, or narrative-scene parallax.

## 9. Transparent HUD and self-talk overlays

HUD and self-talk are transparent functional overlays above the full-panel art.
The visible headings `RUN STATUS` and `ANGELA` are removed. Their semantic
accessible region names remain available without becoming visible labels.

The HUD remains pinned at the top and retains every approved audience-safe
label, value, maximum, condition, and penalty. A non-rectangular tonal wash may
fade from approximately 65 percent at the top to transparent by the lower HUD
edge; High Contrast may use approximately 92 percent. No opaque panel boundary
returns.

Self-talk is anchored to the bottom, uses a transparent container, and grows
upward for text enlargement. Its current content remains in view. Only
functional self-talk text may use local vertical overflow as a last resort;
the art stage itself never scrolls.

## 10. Dual-language projection

The user's correction retains Secondary-language projection in these exact
surfaces:

- current Narrative, Hospital, and Ending caption cards;
- the corresponding scene History projection;
- Contacts message slips; and
- Angela self-talk.

Dual Language does not duplicate HUD labels, app chrome, Shop copy, Backup
metadata, Gallery record copy, or ordinary app instructions. Primary and
Secondary remain one semantic card or slip, and Primary-only TTS law is
unchanged.

## 11. Compact Backup controls

Backup's Save and Load mode controls occupy a compact intrinsic-height row
beside or directly beneath the heading. They never stretch vertically into the
cabinet track.

Inspector Save, Load, Delete, and Return actions are content-sized, aligned to
the action edge, and approximately 96 logical pixels wide where the label fits.
Every action retains its selected 48/64-pixel minimum target and existing
focus, confirmation, mode, and restore behavior.

## 12. Verification

The disposable atlas verification must prove:

1. quantity controls share one y-axis and remain reachable at 48/64 targets;
2. computer-app prompts remain inside the computer safe region and never cover
   Angela;
3. title and full-canvas host prompts retain their correct owners;
4. one-, two-, three-, and four-person portrait/tableau unions share the canvas
   centre and preserve identical order;
5. caption cards and centred text remain readable at 100/125/150 percent,
   Primary/Dual, Standard/High Contrast, and all colour presets;
6. HUD and self-talk are transparent in Light and Dark, and neither visible
   heading exists;
7. Contacts, self-talk, and current scene captions retain correct Dual content;
8. self-talk is bottom-anchored and the Angela art viewport has no scrollbar;
9. fine-pointer motion stays within every amplitude bound and affects only art
   layers;
10. pointer leave, modal ownership, blur, and visibility loss recenter the art;
11. Reduced Motion and non-pointer input keep zero parallax while authored art
    changes remain available;
12. Backup mode and inspector actions remain compact but satisfy target minima;
13. every affected modal still traps focus and restores its exact source; and
14. real Chrome reports no console error, warning, unexpected external request,
    clipping, outer horizontal overflow, or inaccessible hidden content.

## 13. Implementation boundary

Implementation may change only the portable atlas HTML, its structural guard,
browser verifier, evidence captures, and local prototype reports. It must not
change Godot scenes, scripts, accepted design amendments, Beads state, runtime
assets, saves, or production localization.
