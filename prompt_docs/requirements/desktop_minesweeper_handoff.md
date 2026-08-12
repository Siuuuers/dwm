---
id: req_packet.desktop_minesweeper_handoff
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.9","dwm-p2r.16","dwm-oyo.3"]
requirements:
  - {"id":"req.desktop.registry","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.desktop.host","depends_on":["req.desktop.registry"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.desktop.cross_app_actions","depends_on":["req.desktop.host","req.save.desktop_board_continuity"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.desktop.logout","depends_on":["req.desktop.cross_app_actions"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.minesweeper.board_lifecycle","depends_on":["req.save.desktop_board_continuity"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.minesweeper.round_contract","depends_on":["req.minesweeper.board_lifecycle"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.minesweeper.safety_capabilities","depends_on":["req.minesweeper.board_lifecycle"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.minesweeper.rng_isolation","depends_on":["req.minesweeper.safety_capabilities"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.shop.capabilities","depends_on":["req.desktop.cross_app_actions","req.minesweeper.safety_capabilities"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.minesweeper.causal_departure","depends_on":["req.minesweeper.board_lifecycle"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.minesweeper.phase_boundary","depends_on":["req.minesweeper.round_contract","req.minesweeper.causal_departure","req.shop.capabilities"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.desktop_minesweeper_handoff

## Rule req.desktop.registry

The desktop app registry MUST contain exactly minesweeper, contacts, schedule, shop, backup, settings, and logout.

## Rule req.desktop.host

The desktop host contract MUST model one visible cached app with deterministic focus and navigation outputs; Phase 3 MUST own player-facing composition.

## Rule req.desktop.cross_app_actions

Home or app switching MUST preserve an exact prepared candidate and MUST suspend, not finish or forfeit, an active board. Contacts, Schedule editing, Shop purchases, and Settings changes MAY commit while the board is suspended. Manual Save, quick Save, and Logout serialize the latest stable state; selected Load or new-run replacement replaces it without importing a forfeit into the selected branch. Later board completion MUST apply typed deltas to then-current live state and MUST NOT restore a pre-board whole-run snapshot.

## Rule req.desktop.logout

Logout MUST remain available with a prepared or started board. Yes MUST atomically write the exact stable live run to the normal logout/autosave document and route to title only after persistence succeeds; failure MUST keep the run live and offer a truthful retry or cancel path. Numbered manual slots remain untouched.

## Rule req.minesweeper.round_contract

The desktop Minesweeper round MUST start only when the first semantic Reveal command successfully commits. That one idempotent transaction MUST validate and materialize or adopt the exact board, record the first cell and proof, consume exactly one round and one motivation, apply the signed-round decrement, commit the revealed result and stable checkpoint, and publish afterward. Any pre-commit failure charges nothing. Flags, chords, and other commands cannot start a board; a duplicate accepted first-Reveal command returns its original receipt.

## Rule req.minesweeper.board_lifecycle

The desktop board MUST use the closed phases `NONE`, `PREPARING`, `PREPARED_UNSTARTED`, `ACTIVE_VISIBLE`, `ACTIVE_SUSPENDED`, and `SETTLING`. Debug preparation may persist a cost-free certified candidate before first Reveal; Default and Lucky materialize only at first Reveal. Every frozen input, command revision, stable preparation frontier, cell, mine, proof, terminal result, settlement, discard, and forfeit field required for exact restore MUST be domain data rather than live Node state.

Run, branch, desktop-generation, causal-day, board, transaction, and nonce roots MUST come from one injected production issuer with a persisted namespace/counter and root-receipt ledger. A deterministic child identity is legal only when the same issuer derives and validates it from a ledger-verified issued parent transaction, a closed child kind, an ordinal, and sorted canonical source IDs. Standalone hashes, caller-provided identity strings, time, process-global randomness, and scene-instance identity MUST NOT mint canonical identities.

## Rule req.minesweeper.safety_capabilities

The closed Default, Lucky Charm, and Debug Key capability combinations MUST follow the accepted amendment's first-cell, hidden-extra-mine, forced-cell, deterministic priority, and no-guess certification laws. No capability may silently weaken mine totals, eligibility, or verifier truth; an unsatisfied generation or proof request MUST fail without cost or state mutation.

## Rule req.minesweeper.rng_isolation

Board generation, hidden explosion assignment, Shop randomness, presentation randomness, and unrelated run randomness MUST use isolated deterministic streams with persisted semantic seeds or nonces. Retry, restore, app switching, or an unrelated random draw MUST NOT perturb another stream.

Debug forced-cell selection and no-guess search MUST use a persisted Debug stream identity, nonce, and state that are distinct from placement generation and hidden explosion assignment. Drawing or retrying in one stream MUST NOT advance, reconstruct, or bias either of the others.

## Rule req.shop.capabilities

The Shop MUST expose the closed Supportz, Lucky Charm, and Debug Key capability laws from the accepted amendment. Purchases MUST be exactly once, affordability-checked, and prospective: they cannot mutate a frozen prepared candidate or active board. A purchase whose committed effects cause a condition-driven departure MUST compose with prepared discard or started forfeit and the exact destination in one recoverable causal transaction.

## Rule req.minesweeper.causal_departure

Leaving the causal day MUST silently discard a PREPARING or PREPARED_UNSTARTED candidate without cost, result, reward, or forfeit, and MUST silently forfeit an ACTIVE_VISIBLE or ACTIVE_SUSPENDED board while retaining its consumed round and motivation. A forfeit grants no result, reward, relationship/contact progression, unlock, or notification. The operation MUST be idempotent, checkpointed, and composable as one participant in Schedule Done or condition-driven departure.

One persisted run-local causal sequence and final run-revision compare-and-swap MUST order board settlement, Shop purchase consequences, Schedule Done, and every condition-driven route. Its durable state MUST include the committed sequence/revision, exact accepted-action receipts, a source-kind-valid pending-transaction transition graph, and destination/notification outboxes. The shared mutation gate MUST hold the causal transaction from admission through commit or recovery so another desktop mutation cannot invalidate the prepared revision between compare-and-swap and participant adoption. No subsystem may maintain a parallel counter, allocate order from signal timing, mutate another participant before winning admission, or publish a destination before the combined checkpoint commits.

## Rule req.minesweeper.phase_boundary

Phase 2R `.9` MUST provide the real pure board lifecycle, generator/verifier, persistence contracts, Shop capabilities, and discard/forfeit transaction port without owning player-facing Schedule or desktop composition. Later phases MUST consume those ports and may replace presentation adapters, but MUST NOT duplicate or reinterpret the domain law.
