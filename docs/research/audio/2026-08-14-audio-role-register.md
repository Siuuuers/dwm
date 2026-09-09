# Audio Role Register

**Date:** 2026-08-14

**Status:** Closed research scope for the first asset pass

This register converts the accepted placement atlas into exact research roles.
It does not promise that every role will receive an asset. A weak, unsafe, or
redundant result resolves to authored silence.

Adding a role requires a later design decision. Researchers may not create
route-, affection-, `true`-, character-theme-, or ending-theme IDs.

## Music

| Role | Family and source law | Primary placement | Silence policy |
|---|---|---|---|
| `music.fragile_authorial` | Sourceless authorial music island; fragile solo or small ensemble | Rare suspension, threshold, or fragment where the plan explicitly permits authorial sound | Silence preferred when music would tell the audience what to believe |
| `music.social_diegetic_classical` | Visible social playback source; human performance with four-layer classical clearance | After the Music | Room/social ambience replaces it when no exact recording fits |
| `music.rehearsal_playback_classical` | Visible rehearsal device; human performance with four-layer classical clearance | Three Versions of the Sky | Paper, controls, and room resonance remain complete without it |
| `music.post_ending_memory` | Authorial profile-memory island; deterministic and already-completed facts only | Post-ending title or approved rare desktop residue | The altered room bed is the preferred fallback |
| `music.dream_noir_suspension` | Sourceless authorial island; quiet chamber/electroacoustic, never a truth cue | A rare approved dreamlike/noir suspension, not routine route scoring | Silence is selected when the candidate becomes cinematic, grand, or symbolic |

## Ambience

| Role | Family and source law | Primary placement | Silence policy |
|---|---|---|---|
| `ambience.bedroom_night` | Institutional/domestic air with no speech or branded exterior cue | Bedroom and desktop at night | Room-held silence may replace it |
| `ambience.university_day` | Maintained university room with restrained distant activity | Ordinary Days 1–7 campus work | Activity Foley may stand without a continuous bed |
| `ambience.university_late_empty` | Emptier version of the same material world | No Task Left and late preparation | Room-held silence is often preferred |
| `ambience.conservatory_rehearsal` | Rehearsal-space air without intelligible instruction or baked performance | Borrowed Gravity, Three Versions of the Sky, After the Run-Through | Floor, fabric, and controls can carry the scene alone |
| `ambience.campus_social` | Restrained gathering with no intelligible foreground conversation | After the Music | Quiet room texture replaces crowd detail when speech contamination remains |
| `ambience.hospital_ordinary` | Ordinary care environment without alarm melodrama, private speech, or diagnosis | Exactly on Time hospital variant and Sylvia Special ceiling image | Air, fabric, and chair alone remain valid |
| `ambience.sheltered_transit_rain` | Light sheltered rain/transit threshold without branded chime or announcement | Day 2 return, Umbrella Pickup, exterior thresholds | Luggage and umbrella Foley can replace it |

## Material and character Foley

| Role | Material/source law | Primary placement | Silence policy |
|---|---|---|---|
| `foley.paper_folder` | Visible paper/folder at declared distance and room | Programme Table, Project Folder, Contingency | Visible handling remains complete without emphasis |
| `foley.book_page_annotation` | Visible book, page, pencil/annotation action | Borrowed Book | No replacement sound required |
| `foley.clasp_small_mechanical` | Visible restrained clasp or small closure | Priscilla material signature, final packed task | May be omitted to create deterministic absence |
| `foley.keys_visible` | Visible handled key only; never an offscreen presence claim | After the Run-Through, Someone Else's Kitchen, Persistence | No key sound without a visible key |
| `foley.keyboard_instrument_control` | Visible keyboard, switch, telescope, instrument, or playback control | Angela material signature, Returned Seat, astronomy work | Equipment bed or visible motion is sufficient |
| `foley.chair_ceramic_kettle` | Visible chair/cup/kettle action; dry and ordinary | Quiet Table, Caretaker's Break, closing reception | Room texture may carry the scene |
| `foley.fabric_floor_weight` | Visible fabric, shoe, floor contact, or weight transfer | Borrowed Gravity, Before It Hurts, Stage Door | Never add breath or impact to exaggerate touch/pain |
| `foley.badge_zipper_packaging` | Visible badge, kit, zipper, packet, or sealed supply | Exactly on Time, Caretaker's Break, Contingency, Sylvia Special | Physical object remains visible if sound is absent |
| `foley.equipment_motor` | Visible ordinary motor/tracking/equipment movement | Angela astronomy work and Alone | Night room tone is the fallback |
| `foley.umbrella_luggage` | Visible umbrella latch, handle, bag, or luggage movement | Day 2 return and Umbrella Pickup | Transit texture or visible action suffices |
| `foley.door_handled` | Visible door action with material, distance, space, and interruption declared | Campus, hospital, and threshold transitions | No offscreen door used to imply a character |
| `foley.device_notification_physical` | Visible device cue shared by ordinary notifications | Day 2 message order and Day 6 location prompt | The visual timestamp/record remains complete |

## UI and gameplay

| Role | Semantic law | Primary placement | Silence policy |
|---|---|---|---|
| `ui.accept` | One restrained cue for one accepted command | Ordinary buttons and confirmations | Visual state change is sufficient |
| `ui.cancel_back` | Related but distinguishable restrained cue | Back, Cancel, close | Visual/focus restoration is sufficient |
| `ui.notification` | Neutral legitimate-system cue; no importance coding | Contacts and ordinary notifications | Toast/badge remains complete |
| `ui.save_load_success` | Trustworthy mechanical confirmation; no magical flourish | Save and Load completion | Status text remains complete |
| `ui.rejection_error` | Low-intensity factual rejection; no alarm or punishment | Invalid/unavailable command | Visible reason remains complete |
| `gameplay.minesweeper_reveal` | One dry cue per accepted reveal command, not per flood cell | Minesweeper | Board state is sufficient |
| `gameplay.minesweeper_mark` | Dry mark/unmark feedback with repetition tolerance | Minesweeper | Flag state is sufficient |
| `gameplay.minesweeper_result` | Restrained board-result identity with no reward fanfare or horror sting | Minesweeper completion/failure | Result surface is sufficient |

## Human nonverbal

| Role | Provenance and content law | Primary placement | Silence policy |
|---|---|---|---|
| `human_nonverbal.breath` | Affirmatively human, non-explicit, non-character, non-distress breath | Rare authorial texture only; never an offscreen person | Silence strongly preferred unless provenance and ambiguity are exceptional |
| `human_nonverbal.hum` | Affirmatively human, non-lyrical, no identifiable character voice | Rare music island or witnessed diegetic source | Silence preferred when it suggests an absent singer |
| `human_nonverbal.choir_like` | Affirmatively human ensemble/performer; no lyrics or synthetic choir | Rare authorial post-ending or dreamlike suspension | Silence preferred when licensing, words, or human provenance are unclear |

## Closure count

The first pass contains exactly:

- 5 music roles;
- 7 ambience roles;
- 12 material/Foley roles;
- 5 UI roles;
- 3 gameplay roles; and
- 3 human nonverbal roles.

Total: 35 roles. Each closes with one preferred prospect, one fallback
prospect, or an explicit silence decision after the legal convergence audit.
