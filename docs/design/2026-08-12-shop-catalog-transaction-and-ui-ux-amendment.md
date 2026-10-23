---
id: spec.shop_catalog_transaction_ui_amendment
kind: design_amendment
schema_version: 1
amends: spec.desktop_minesweeper_shop_schedule_amendment
amends_path: "docs/design/2026-08-11-desktop-minesweeper-shop-schedule-amendment.md"
decision_status: accepted
conversational_design_status: approved
written_spec_status: approved
self_review_status: passed
self_reviewed_on: "2026-08-12"
written_spec_approved_on: "2026-08-12"
implementation_authorized: false
created_on: "2026-08-12"
engine_line: godot_4_6
verification_engine: 4.6.3-stable-mono
language: gdscript
scope: ["shop_catalog","shop_purchase_quantities","shop_keepsakes","shop_ui_ux","shop_accessibility","shop_projection_and_persistence"]
---

# Shop Catalog, Purchase Transaction, and UI/UX Amendment

## 1. Status and objective

This document records the conversationally approved Shop catalog, purchase,
keepsake, and UI/UX design discovered while preparing the game's future UI/UX,
visual-art, and music/audio manuals.

The user approved this exact written amendment on 2026-08-12. It is the accepted
product and design authority for its bounded scope, but it does not authorize
implementation. Requirements, Beads acceptance criteria, hash-bound plans,
schemas, tests, registries, scenes, and runtime code remain unchanged until
separately reconciled and explicitly authorized.

The Shop should feel like an ordinary old university application whose products
are materially specific but mechanically unexplained. It may conceal why an
object matters, how much branch stock remains, and which internal condition it
changes. It may not conceal the selected item, selected quantity, exact price,
currency spent, whether a command succeeded, or whether a technical failure
occurred.

### 1.1 Approved derived closures

To turn the approved direction into a closed, testable record, the written pass
proposed the following narrow defaults. Approval of this exact file accepted
them as product law within scope:

- Bandage Pack has catalog-unlimited stock and is bounded only by funds.
- Selecting another card resets its quantity to one; the cached session retains
  only the selected card's current quantity.
- Page changes focus the remembered card, or slot one on first visit.
- The double-click shortcut uses quantity one for a newly selected card and the
  current quantity for an already selected card; it is mouse-only at launch.
- Successful ordinary double-click purchase returns focus to its source card;
  successful Supportz purchase returns focus to Spa Coupon.
- Zero-affordable MAX remains disabled while the selector stays at one.
- The three keepsakes receive new semantic registry IDs, and batch effects use
  stable unit-major application order.
- Stat clamping may make bought units partly or wholly ineffective without a
  refund or explanatory warning.
- Keepsake ownership alone is canonical; scene transforms and other projection
  details are not save facts.

The closures now carry the same bounded authority as the conversationally
chosen catalog, transaction, and UI/UX law.

## 2. Authority and precedence

### 2.1 Authority spine

Within the six frontmatter scope topics, this amendment controls intended
behavior over conflicting recovered documents, prompt packets, proposed plans,
tests, DataCatalog rows, and current UI scaffolds.

It narrowly supplements and amends the accepted 2026-08-11 Desktop
Minesweeper, Shop, and Schedule amendment. That amendment retains authority for
Lucky Charm, Debug Key, Supportz, board capability timing, purchase-before-
condition ordering, condition-driven departure, and board fate except where
this document adds exact ordinary-catalog or Shop-presentation law.

The accepted 2026-08-07 Seven-Day Flow and Dialogic Structure design retains
authority for every unrelated relationship, Schedule, Hospital, Day 7, ending,
Gallery, and presentation-only rule.

Beads owns mutable work status, dependencies, and implementation evidence. A
manual or runtime scene cannot silently supersede this product law.

### 2.2 Current execution state

At the time of writing:

- runtime implementation is not authorized;
- the relevant reconciliation and implementation issues remain open;
- the current Shop scene is an unwired skeleton rather than a UI precedent;
- DataCatalog and its tests still contain obsolete gift and consumable rows;
- the accepted August plan suite is hash-bound and cannot be silently edited;
  and
- `docs/design` design amendments are not yet indexed by the current machine
  authority resolver or validated by the prompt-doc packet validator.

No validator-coverage or runtime-completion claim follows from this document.

## 3. Scope boundary

### 3.1 In scope

- The closed 18-item Shop catalog, exact ordering, currency, unit price,
  purchase cap, quantity policy, and immediate effect or keepsake grant.
- Atomic single and batch purchase behavior, exact quote validation,
  idempotency, recovery, and one post-purchase condition check.
- The branch-scoped Bookend, Metronome, and Pocket Calculator environmental
  keepsakes.
- The two-page catalog, inspector, card anatomy, selection, focus, paging,
  quantity, direct Buy, optional double-click confirmation, Supportz modal,
  success/refusal feedback, and trusted technical recovery boundary.
- Shop-specific behavior at 100%, 125%, and 150% text size.
- The boundary between cached Shop view state, canonical run state, and
  durable in-flight purchase recovery.
- Presentation/domain ownership and verification expectations for this scope.

### 3.2 Out of scope

- Gifting a Shop object to another character. Gifting is deferred future
  design and is not part of the initial Windows release.
- Changing the total amount of money or Minesweeper coins available in a run.
- Changing general Health, Pressure, Motivation, money, coin, condition, or
  Hospital formulas outside the exact item effects and transaction order here.
- Exact final localized prose for ordinary product descriptions.
- Final item sprite production, Angela-room socket coordinates, animation
  frames, music, or sound assets. The visual-art and audio manuals will own
  those implementation-facing details while preserving this law.
- Android delivery, portrait layout, or mobile lifecycle.
- Claiming 200% text support in the initial release. It remains a separately
  tracked future enhancement.
- Runtime implementation, migration, Beads mutation, or compatibility with
  unshipped skeleton saves.

## 4. Chosen design and rejected alternatives

### 4.1 Chosen design

The Shop is a fixed two-page catalog with nine logical cards per page and one
nonmodal item inspector. Card selection is view-only. Purchase happens only
through a distinct Buy action, the Supportz Yes action, or the Yes action in an
optional double-click confirmation.

Products reveal literal identity and exact price but not mechanical effect or
remaining branch cap. Batchable products expose an exact selected quantity and
total. The resulting interface is operationally truthful while leaving the
audience responsible for observing consequences over time.

### 4.2 Alternatives rejected

#### One direct-buy button on every card

Rejected because selection and purchase would become too easy to confuse,
especially with touch, keyboard focus, and dense 3-by-3 placement.

#### Quantity controls on every product

Rejected because a purchase cap does not imply batchability. Lucky Charm,
Debug Key, Supportz, the three keepsakes, and Spa Coupon have deliberately
single-unit grammar.

#### Showing effect summaries or exact remaining counts

Rejected because it turns exploration into a visible optimization table and
exposes hidden consequences. The Shop discloses current operational acceptance,
not the full reason or lifetime allowance behind it.

#### Miniature narrative scenes in product cards

Rejected because a background, hand, character mark, or contextual prop could
be mistaken for relationship evidence, provenance, or a route clue. The chosen
specimen-card treatment shows only the purchased object.

#### Confirmation before every Buy

Rejected because it adds repetitive ceremony. The visible inspector Buy path
is direct. Double-click confirmation is an optional pointer shortcut, not the
mandatory path.

## 5. Closed catalog and item taxonomy

### 5.1 Item kinds

The registry distinguishes these product kinds:

- `immediate_consumable`: applies its registered run effects inside the atomic
  purchase transaction and leaves no consumable inventory object.
- `board_capability`: grants a prospective saved-branch capability whose exact
  behavior remains governed by the August 11 amendment.
- `round_capacity`: Supportz, governed by its accepted day/branch eligibility
  and prospective capacity law.
- `environment_keepsake`: grants one saved run-scoped ownership ID and one
  inert environment projection, with no gameplay effect.

An item also has an explicit `quantity_policy` of `batchable`, `single`, or
`supportz_modal`. UI code cannot infer quantity behavior from the purchase cap.

### 5.2 Exact catalog

All ordinary caps in this table are per saved run branch. Loading an earlier
save may truthfully rewind them. `Unlimited` means the catalog contributes no
stock cap; affordability remains a finite quantity bound.

| Page | Slot | Item ID | Audience name | Price | Branch cap | Quantity | Internal result per unit |
|---:|---:|---|---|---:|---:|---|---|
| 1 | 1 | `coffee` | Coffee | $20 | 9 | Batchable | Motivation +1 |
| 1 | 2 | `wine` | Wine | $55 | 3 | Batchable | Pressure -4; Health -1 |
| 1 | 3 | `pineapple_bun` | Pineapple Bun | $10 | 3 | Batchable | Health +1 |
| 1 | 4 | `bandage_pack` | Bandage Pack | $15 | Unlimited | Batchable | Health +1 |
| 1 | 5 | `quiet_tea` | Quiet Tea | $15 | 3 | Batchable | Pressure -1 |
| 1 | 6 | `soft_blanket` | Soft Blanket | $25 | 3 | Batchable | Pressure -2 |
| 1 | 7 | `weighted_plush` | Weighted Plush | $35 | 2 | Batchable | Pressure -3 |
| 1 | 8 | `spa_coupon` | Spa Coupon | $45 | 1 | Single | Pressure -4 |
| 1 | 9 | `supportz` | No visible name | $45 | August law | Supportz modal | One prospective app-round capacity |
| 2 | 1 | `healthy_meal` | Healthy Meal | $25 | 3 | Batchable | Health +2 |
| 2 | 2 | `protein_box` | Protein Box | $35 | 2 | Batchable | Health +3 |
| 2 | 3 | `pep_note` | Pep Note | $10 | 5 | Batchable | Motivation +1 |
| 2 | 4 | `premium_care` | Premium Care | 1 coin | 2 | Batchable | Pressure -4; Health +4 |
| 2 | 5 | `lucky_charm` | Lucky Charm | 1 coin | 1 | Single | Prospective Lucky capability |
| 2 | 6 | `debug_key` | Debug Key | 3 coins | 1 | Single | Prospective Debug capability |
| 2 | 7 | `bookend_keepsake` | Bookend | 3 coins | 1 | Single | Environment keepsake only |
| 2 | 8 | `metronome_keepsake` | Metronome | 3 coins | 1 | Single | Environment keepsake only |
| 2 | 9 | `pocket_calculator_keepsake` | Pocket Calculator | 3 coins | 1 | Single | Environment keepsake only |

### 5.3 Exact ordinary-item rules

Pineapple Bun and Quiet Tea are immediate restoratives. They do not enter an
inventory, attach to a date, become gifts, trigger dialogue, or survive as
consumable objects.

Coffee and Pep Note deliberately share Motivation +1 at unequal price and cap.
The cheaper five-unit Pep Note tier and the larger, more expensive Coffee
reserve are not an error and receive no explanatory comparison.

Stat clamping follows the authoritative run-stat boundaries. A unit whose
effect is partly or wholly lost at a clamp is still purchased and counted.
Quantity selection is not restricted by useful stat headroom, and no refund or
warning follows from wasted effect.

Wine may reduce Health while reducing Pressure. Its card and inspector do not
warn about that effect.

### 5.4 Keepsake law

Bookend, Metronome, and Pocket Calculator replace the obsolete friend-gift
products and IDs. Each purchase:

- spends three Minesweeper coins;
- increments that product's branch purchase count from zero to one;
- grants one unique saved environment-keepsake ID;
- adds no Health, Pressure, Motivation, relationship, invitation, Schedule,
  condition, Observer, fragment, ending, Gallery, or achievement effect; and
- still participates in the universal post-Shop condition check because that
  check follows the purchase action rather than an item's stat effect.

All three may coexist. They persist across day advance, rewind with the loaded
run snapshot, and clear on New Run. They are not profile or Gallery unlocks.

Their environment projections are inert and presentation-only. They cannot be
clicked, moved, gifted, consumed, duplicated, randomized, logged, or used as
evidence. The environment saves semantic ownership IDs, never Nodes, asset
paths, transforms, z-order, visibility, or socket coordinates.

The Shop uses only the generic visible names `Bookend`, `Metronome`, and
`Pocket Calculator`. It does not name a friend, donor, owner, relationship, or
provenance.

## 6. Atomic purchase transaction

### 6.1 Purchase request

A normal purchase request carries at least:

- immutable item ID;
- positive integer quantity;
- quote identity and registry/version fingerprint;
- quoted unit price, total, and currency;
- run, branch, logical-day, and relevant revision identity; and
- one external transaction identity used for idempotent retry.

The UI emits this request but does not validate or apply product effects.

### 6.2 Validation

At commit, the transaction owner revalidates the exact item, registry row,
quantity policy, positive quantity, full remaining cap, exact quote, total,
currency balance, run/branch/day context, effect or grant IDs, transaction
identity, and idempotency state.

A stale or conflicting request cannot auto-clamp, substitute another item,
partially buy, or spend against a revised quote.

### 6.3 Batch atomicity

For a batch quantity `q`, the transaction expands the product's registered
effect vector exactly `q` times in stable unit-major order, increments the
purchase count by `q`, and spends `unit_price * q` in one detached candidate.

The full candidate commits once or nothing commits. There is no per-unit input
window, partial fulfillment, per-unit receipt, or early Hospital after unit
`k`.

One submitted batch produces one durable Shop receipt and exactly one
post-purchase condition check against the final aggregate state.

### 6.4 Single purchases

Single products use the same atomic command and receipt with quantity exactly
one. Lucky Charm, Debug Key, and Supportz retain the additional accepted
prospective and eligibility rules from the August 11 amendment.

### 6.5 Command locking and replay

While one purchase command or its required condition check remains unresolved,
all further purchase, quantity, page, and card-purchase shortcuts are inert.
The command boundary is short-lived; it is not a lifetime Shop or board lock.

Rapid duplicate delivery of the same request returns the same receipt and
cannot spend or apply effects twice. Reuse of one transaction identity for a
conflicting request fails without mutation.

Crash after durable purchase commit but before condition resolution resumes
the existing forward transaction. It cannot refund, repeat the grant, or offer
the same purchase as uncommitted.

## 7. Condition and departure ordering

Every successful normal, batch, capability, Supportz, or zero-stat keepsake
purchase follows this order:

1. validate the complete request;
2. commit spend, purchase count, effects or grant, and receipt atomically;
3. evaluate the one authoritative post-Shop condition check;
4. if the check requires Hospital or a Day 7 destination, retain the entire
   purchase, discard a prepared desktop candidate or forfeit a started desktop
   board under accepted board-fate law, and route;
5. otherwise unlock the Shop and publish the refreshed projection.

No purchase success message may delay or outrank the condition-driven route.

## 8. Screen composition

### 8.1 App frame

Shop opens as one full phone-like app inside the computer pane. No other app is
visible beside it. The wide 1280-by-720 baseline retains the accepted outer
three-fifths Angela/environment to five-fifths computer composition; Shop owns
only the computer pane, approximately 800 logical pixels wide. The existing
shared system strip and Home/app-title grammar remain unchanged.

The Shop header contains only the localized app title and truthful current
money and Minesweeper-coin balances. Balances use tabular figures and never
animate through fictional intermediate values.

### 8.2 Catalog and inspector

Below the header, the wide Windows baseline allocates approximately three
fifths of usable width to the catalog and two fifths to the inspector, with one
ordinary fixed gutter between them.

The catalog renders exactly one 3-by-3 page at a time. Page order and slot
identity never sort, collapse, or move because of affordability, ownership,
selection, purchase, locale, or text size. Sold-out cards stay in their slot.

The inspector is nonmodal. Selecting a normal card replaces only its projected
content. Its upper information region may scroll vertically; its transaction
dock remains anchored at the bottom and never scrolls out of reach.

### 8.3 Paging

Page navigation uses explicit Previous and Next actions plus a truthful `1 / 2`
indicator. A page remembers its most recently selected slot for the cached Shop
session. First visit to a page selects slot one. Activating Previous or Next
moves focus to that remembered target card, or slot one on first visit.

Page navigation is not a purchase command and cannot change canonical run
state.

## 9. Specimen-card and inspector anatomy

### 9.1 Card geometry

At the 1280-by-720 baseline, a card targets approximately 144 by 156 logical
pixels inside the fixed grid. Containers may distribute a small remainder, but
every page shares identical card rectangles and spacing.

The whole card is one focus and pointer/touch target. A card contains:

1. an upper object-art well;
2. one localized generic product name;
3. exact unit price and currency; and
4. `Available` or `Sold out`.

It does not contain an effect summary, purchase count, remaining cap, stat
name, stat icon, friend mark, relationship text, mechanical category, rarity,
recommended quantity, or marketing claim.

### 9.2 Object art

The chosen style is an old specimen catalog:

- one literal 56-to-72-pixel pixel-art object isolated on exhausted paper-grey;
- soot-black functional ink and a limited old-campus-workstation palette;
- at most one restrained faded-dreamcore accent such as washed mint, bruised
  mauve, faded peach, or oxidized blue;
- integer-aligned hard edges and stable authored dithering; and
- no hands, character silhouette, narrative room, provenance, sparkle, aura,
  effect ray, heart, cross, meter, or animation that implies function.

Static paper or ink texture stays outside text, price, focus, and hit boundaries.

### 9.3 Card states

- Hover changes the paper tone by one quiet step and never selects the card.
- Selection uses a persistent charcoal double inset frame.
- Keyboard/controller focus adds a distinct pale-and-charcoal outer ring.
- Press reverses the old workstation bevel within the input-feedback budget
  without scaling, shifting, bouncing, or changing the layout rectangle.
- Sold out retains readable art and copy and remains selectable for inspection;
  purchase controls are absent.
- Supportz uses the same physical card shell at page one, slot nine, but has no
  visible art, name, price, availability, hint, or decorative irregularity.

Selection, focus, hover, pressed, availability, and sold-out states cannot rely
on color alone.

### 9.4 Inspector

The inspector enlarges the same literal object to approximately 112-to-128
pixels, followed by its generic localized name, one neutral literal product
description, exact unit price, and current `Available` or `Sold out` state.

Descriptions may state ordinary physical form, such as a sealed vending cup,
but cannot promise energy, comfort, safety, healing, encouragement, luck,
debugging, affection, ownership, or any downstream result.

The transaction dock reserves a stable vertical region so switching between a
batchable and single product does not move the primary Buy action unexpectedly.
Only actual controls enter focus navigation.

## 10. Selection and purchase interaction

### 10.1 Selection

One pointer click, touch activation, keyboard confirm, or gamepad confirm on a
normal card selects it and updates the inspector. It does not purchase.

Hover never changes selection or focus. Selecting a different card resets the
new card's local quantity to one. Same-day hiding and reopening preserves only
the currently selected card's current quantity.

### 10.2 Batch quantity controls

Batchable products show this logical row:

`MIN  -  quantity  +  MAX`

The quantity value and enabled/disabled state are truthful and visible.

- MIN sets quantity to one when at least one unit is currently affordable; at a
  zero legal maximum it is disabled and is a no-op.
- Minus subtracts one without going below one.
- Plus adds one without exceeding the current projected legal maximum.
- MAX sets the greatest currently purchasable quantity under both Angela's
  current currency and the concealed remaining branch stock.
- MIN and MAX set quantity only; they never submit a purchase.
- The row also shows the exact computed total and one `Buy xN` action.

The current legal maximum does not consider useful stat headroom. It does not
say whether money, coins, or hidden stock produced the bound. Its visible number
may let an attentive audience infer current stock, which is accepted discovery.

If no unit is currently affordable, MAX is disabled and quantity remains one.
The direct Buy attempt may then return `Insufficient funds`. For unlimited
Bandage Pack stock, MAX is bounded only by current affordability.

MIN, Minus, Plus, and MAX have distinct text or glyph labels, at least 48-by-48
logical-pixel hit regions, and at least eight logical pixels between adjacent
hit regions.

### 10.3 Single products

Spa Coupon and the three keepsakes show one direct Buy action with quantity one.
They have no quantity row and no invisible or disabled quantity controls.

Lucky Charm and Debug Key retain their accepted direct Buy behavior: quantity
one, no quantity selector, no confirmation dialog, no sell/consume action, and
no mechanical effect explanation.

### 10.4 Direct Buy

Inspector Buy submits the exact selected item and displayed quantity directly.
It does not open a normal confirmation dialog.

After successful purchase, batch quantity resets to one. If the product remains
available and no route occurs, focus stays on Buy. If it becomes sold out, Buy
disappears and focus returns to the selected card. A condition-driven route
owns focus instead of either rule.

### 10.5 Optional double-click confirmation

A platform-recognized primary-button double-click on an available normal card
is an optional mouse shortcut. It never purchases immediately.

The first click selects the card. If it was newly selected, quantity is one. If
it was already the selected batchable card, the confirmation uses its current
quantity.

The confirmation contains only:

- localized generic item name;
- exact quantity when relevant;
- exact total and currency; and
- No and Yes actions.

Initial focus is No. No, Back, or Close mutates nothing and returns focus to the
originating card. Yes sends the same atomic purchase command as inspector Buy.
Success returns focus to the originating card if no route occurs.

This shortcut excludes sold-out or inert cards, Lucky Charm, Debug Key, and
Supportz. Lucky and Debug preserve their accepted no-confirmation Buy path.
Supportz preserves its own price-only modal.

A touch double-tap, repeated keyboard confirm, or repeated gamepad confirm is
not mapped to this shortcut in the initial Windows release. All devices retain
the complete inspector selection and Buy path; the shortcut adds no exclusive
functionality.

## 11. Supportz exception

Supportz remains governed by the exact accepted August 11 eligibility, quote,
day cap, branch cap, prospective capacity, and receipt law.

Page one, slot nine is a fixed, non-overlapping, completely blank card shell.

- Ineligible: inert, absent from focus navigation, and unavailable to pointer
  or touch activation.
- Eligible: still visibly blank, but joins normal navigation with the ordinary
  focus outline and neutral assistive identity `Blank shop card`.
- Activation opens only the Supportz price modal, never the inspector or normal
  double-click confirmation.

The modal contains only `$45`, No, and Yes. It has a neutral dialog identity,
sets initial focus to No, traps focus, makes the Shop background inert, and maps
Back or Close to No.

No, Back, or Close returns focus to the blank card. Yes revalidates and submits
the one-unit Supportz purchase. After success the slot becomes inert; if no
condition route occurs, focus moves deterministically to page one, slot eight,
Spa Coupon, because the originating slot is no longer focusable.

Supportz success has no name reveal, effect explanation, discovery receipt,
history entry, celebration, or generic success text.

## 12. Feedback and technical truth

### 12.1 Successful purchase

A normal success has no toast, receipt screen, `Purchase saved` message,
history entry, effect summary, or celebratory animation.

Truthful refreshed balances, card availability, quantity bounds, qualitative
condition presentation, and an environment keepsake appearing are sufficient
feedback. Supportz, Lucky Charm, and Debug Key remain even quieter under their
accepted hidden-capability law.

### 12.2 Expected refusal

An expected refusal commits nothing and uses exactly one terse inline message
near the transaction dock:

- `Insufficient funds`; or
- `Unavailable`.

The same literal fact is exposed to assistive access. Refusal does not open a
technical recovery plate, steal focus, recommend another item, expose a cap,
or identify the hidden reason for unavailability.

Changing selection or quantity clears stale refusal copy. A stale quote or
projection refreshes the card and quantity bounds without partial purchase.

### 12.3 Technical failure

A technical failure is never Shop fiction, a horror anomaly, a fake OS fault,
or an ordinary availability refusal. It uses the game's trustworthy technical
recovery surface and accurately distinguishes safe, pending, and durably
committed progress.

Retry resumes or replays the same idempotent transaction. It cannot create a
new transaction, double-spend, refund a committed purchase, or suppress a
required condition route. Development diagnostics may expose machine-readable
detail in development evidence, but public recovery copy remains truthful and
nonfictional.

## 13. Focus, input, and accessibility

### 13.1 Focus graph

Cards are one row-major 3-by-3 focus grid. Arrow and D-pad movement follows
visible rows and columns without wrapping into a purchase. Moving right from
the third column enters the inspector's first actionable control; moving left
from the inspector returns to the selected card.

Moving down from the bottom row reaches explicit page actions. Page activation
moves focus to the target page's remembered card as defined in section 8.3.

Tab order follows the same truthful visual hierarchy. Modal focus never escapes
to the grid or app chrome until dismissal.

### 13.2 Input parity

Pointer, touchscreen, keyboard, gamepad, and assistive activation all support
card selection, page navigation, quantity editing, direct Buy, modal Yes/No,
Back, and Home through visible or standard semantic actions.

Double-click confirmation is permitted as an optional pointer accelerator only
because every function it reaches already has the complete visible path.

No item, including Supportz, depends on hover. No card contains a focus-only
mechanical explanation unavailable to pointer or touch users.

### 13.3 Assistive parity

Assistive names expose only facts also available visually: generic product
name, exact price/currency, Available or Sold out, selected quantity, exact
total, selected state, and relevant control identity.

They do not reveal effect, cap, remaining stock, relationship association,
keepsake mapping, Supportz identity/effect, Lucky/Debug mechanics, or a hidden
reason for unavailability.

The design defines semantic targets and verification requirements but makes no
public claim about a particular screen reader until that exact Windows/Godot
combination passes evidence.

## 14. Text size and localization

Initial Windows release supports Shop text-size presets 100%, 125%, and 150%,
with 100% default. Changing the preset applies presentation immediately without
changing selection, quantity, purchase state, balances, or transaction state.

All three sizes preserve the same macro topology:

- catalog remains left and inspector right;
- each page remains a 3-by-3 grid;
- page and slot order remain identical;
- transaction controls remain in the bottom inspector dock; and
- Supportz remains page one, slot nine.

Names wrap without ellipsis where the supported locale requires it. At 150%,
card artwork may contract toward 56 pixels and the inspector artwork may
contract toward 112 pixels. The inspector's upper information region may
scroll vertically. Controls, prices, availability, and full essential text may
not clip, overlap, disappear, or shrink below the selected text preset.

The Shop does not claim initial-release 200% text support. Deferring it does not
change the 48-by-48 logical-pixel minimum interactive target.

Literal descriptions and names follow the registered locale fallback chain.
The fallback must not replace an effect-free description with effect-revealing
copy.

## 15. View cache, save, load, and branch behavior

### 15.1 Cached view state

During one same-day cached Shop instance, Home/app switching may preserve:

- current page;
- each page's remembered selected slot;
- current selected card;
- current selected card's quantity;
- catalog and inspector scroll positions; and
- last meaningful focus target.

This is presentation state. It cannot affect purchase eligibility or canonical

The cached Shop view resets at logical-day change. The next opening starts on
page one with Coffee selected, quantity one, and focus on Coffee.

### 15.2 Canonical saved state

Run persistence owns balances, stats, purchase counts, capabilities,
environment-keepsake ownership IDs, Supportz day/branch facts, and any durable
in-flight transaction or condition handoff.

It does not save the open Shop page, selected card, quantity selector, scroll,
focus, hover, pressed state, refusal line, or open modal.

An explicit Load rebuilds the Shop from validated canonical state at page one,
Coffee selected, quantity one, and focus on Coffee. New Run does the same after
clearing prior run Shop state. Same-run loading of an earlier snapshot truthfully
rewinds branch caps, balances, keepsakes, and card availability according to
the selected continuation law.

## 16. Component and authority ownership

The player-facing Shop is a projection-only adapter. A recommended scene
boundary contains:

- a Shop screen orchestrator that delegates but owns no economy law;
- a catalog/page projection;
- a selected-item inspector projection;
- a quantity selector that edits only local positive-integer view state;
- an ordinary purchase-confirmation modal;
- the specialized Supportz modal;
- an inline refusal presenter; and
- a trusted technical-recovery handoff.

Components signal semantic intent upward. They do not call GameState mutation,
query mutable inventory after command creation, infer caps from card state, or
apply effects sideways to sibling UI.

The immutable registry owns catalog facts and quantity policy. The reusable
Shop transaction coordinator owns validation, atomic spend/effects/grants,
receipts, idempotency, recovery, and the condition handoff. The player-facing
composition owner consumes those ports and projects detached state.

Godot implementation should use root Theme inheritance, Container-driven
layout, explicit non-linear focus neighbors, and stable Control rectangles.
It should not use per-card `_process`, animated shaders, random grain, or
presentation-derived business state.

## 17. Exact supersession and retained law

### 17.1 Newly controlling decisions

This amendment supersedes or retires, within scope:

- the August 11 out-of-scope exclusion for ordinary Shop redesign;
- runtime/recovered friend-gift IDs, gift flags, GiftPicker assumptions, and
  gift inventory effects;
- runtime/recovered Pineapple Bun and Quiet Tea inventory effects;
- the scaffold's effect-summary and purchase-count labels;
- any all-items quantity assumption;
- the scaffold's hidden `Secret Supportz buy area` accessible identity;
- fixed current DataCatalog rows where they differ from section 5;
- UI-authored purchase/effect/cap facts;
- any per-unit condition check inside one submitted batch; and
- any interpretation that double-click directly spends currency without a
  second explicit Yes action.

### 17.2 Retained law

This document does not change:

- Lucky Charm, Debug Key, or Supportz prices and accepted capability effects;
- their prospective-only application to future board candidates/capacity;
- Lucky and Debug stacking;
- Supportz's two-completion eligibility, once-per-day limit, three-per-branch
  limit, and hidden presentation;
- exact board persistence and board-fate rules;
- purchase-before-condition ordering;
- Hospital or Day 7 route priority after a committed purchase;
- hidden-stat, hidden-extra, relationship, Observer, ending, or Gallery law;
  or
- the prohibition on fictionalizing technical failure.

## 18. Reconciliation path before implementation

After the user approves this written artifact, authority reconciliation must:

1. reconcile the currently executing `dwm-0hi` authority task before widening
   or replacing any of its exact scope, plan hashes, metadata, or evidence;
2. register the `design_amendment` kind and `docs/design` path with the machine
   authority resolver and validator before claiming machine discoverability;
3. update `docs/design/README.md`, whose recovered-reference wording no longer
   describes the accepted authority ladder;
4. translate the closed catalog, batch transaction, keepsake, and presentation
   laws into prompt-doc requirement/decision packets with exact ownership;
5. regenerate the prompt-doc index and verify requirement/Beads metadata
   parity;
6. establish the amended immutable Shop registry authority, then reconcile
   `dwm-p2r.16` so DataCatalog projection and handoff consume it without owning
   or duplicating catalog facts;
7. reconcile `dwm-p2r.9` for reusable registry, quote, purchase, receipt,
   persistence, recovery, and consequence contracts;
8. reconcile `dwm-oyo.3` for the player-facing Shop scene, fixed catalog,
   inspector, modals, focus, feedback, and production composition;
9. add release evidence to `dwm-oyo.7` without inventing new mechanics;
10. revise affected hash-bound plans only through a separately reviewed plan
    amendment/rebinding process; and
11. leave runtime implementation unauthorized until explicit authority is
    granted after reconciliation.

No existing Beads issue is closed or claimed merely because this document is
approved.

## 19. Verification matrix

### 19.1 Catalog and projection

- Exactly 18 unique registry rows and exactly two stable nine-slot pages.
- Page/slot order remains byte-stable across locale, affordability, ownership,
  load, and text-size changes.
- Registry/domain parity verifies every item's exact price, cap, quantity
  policy, and registered effect/grant in section 5.
- The player-facing projection exposes only the approved generic name, exact
  price, current availability, and applicable quantity interaction.
- Effects, remaining caps, and friend association are absent from visible and
  assistive Shop copy.
- Supportz remains blank in every visual state.

### 19.2 Purchase transaction

- Quantity bounds, MIN, Minus, Plus, MAX, total, and Buy are exact.
- MAX tests money-bound, coin-bound, stock-bound, equal-bound, zero-affordable,
  and unlimited-Bandage cases.
- Batch success applies exactly `q` effects/counts with one spend, one receipt,
  and one condition check.
- Affordability, cap, quote, registry, branch/day, stale-state, rapid duplicate,
  conflicting-replay, and crash-stage failures never partially mutate.
- Clamp waste receives no refund and no explanatory warning.
- Every committed purchase survives a condition-driven departure.

### 19.3 Keepsakes

- Each costs three coins, caps at one, and grants only its saved environment ID.
- All three coexist, survive day advance, rewind under Load, and clear on New
  Run.
- No relationship, fragment, evidence, dialogue, ending, Gallery, or interactive
  environment consumer can read a keepsake as a gameplay fact.
- Missing art cannot corrupt ownership or save restore.

### 19.4 Interaction and focus

- Mouse, touchscreen, keyboard, gamepad, and assistive activation complete the
  visible select-quantity-Buy path.
- One click never buys; double-click never buys before explicit Yes.
- Double-click scope, q-one/new-selection behavior, and current-q behavior pass.
- Lucky, Debug, Supportz, sold-out, and inert cards reject the ordinary
  double-click shortcut correctly.
- Both modals trap focus, default to No, restore deterministic focus, and make
  background purchase controls inert.
- Sold-out cards never move or disappear.

### 19.5 Layout and text

- 100%, 125%, and 150% preserve catalog/inspector topology, page order, card
  order, Supportz slot, and reachable transaction dock.
- Long supported translations wrap without clipping or covering prices,
  availability, focus, or controls.
- Every interactive target remains at least 48 by 48 logical pixels with
  adequate separation.
- Focus, selection, hover, pressed, and sold-out states remain distinguishable
  without color or motion.
- Reduced-motion presentation has no loss of information or input.

### 19.6 Save and recovery

- Same-day cache preserves only the approved transient view fields.
- Save/Load persists canonical Shop facts and durable transactions but never an
  open modal or presentation cursor.
- Load reconstructs page one, Coffee, quantity one, and canonical availability.
- Technical recovery distinguishes safe, pending, and committed states and
  resumes one idempotent forward transaction.

## 20. Acceptance and next manuals

This exact written artifact was approved on 2026-08-12 and is the bounded Shop
authority consumed by later manual and reconciliation work.

The future UI/UX manual should cite rather than duplicate the transaction and
catalog law here. Its next application section may design Contacts. The future
visual-art manual will define final sprites, room sockets, and palette tokens
without adding mechanical clues. The future music/audio manual will preserve
the rule that Shop and keepsake meaning is never carried by required audio.
