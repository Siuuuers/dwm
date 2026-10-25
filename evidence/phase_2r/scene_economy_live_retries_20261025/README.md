# Scene economy retries — 25 October 2026

## Required result

Save and Load retain purchases, balances, inventory, round rewards, counters and
settled-board state without retaining shop and ordinary-round retry receipts.
Live exact retries remain idempotent. A stale pre-Load command cannot debit or
reward the restored Run. A fresh completion request sees the settled board and
cannot grant its reward twice.

## Ownership and scope

`RunSnapshotSchema.build_scene` validates the complete live candidate first.
It then uses `project_player_command_receipts` to omit only
`scene_shop_purchase` and `scene_round_completion` from the player snapshot.
Live captures, rollback and current-session retry records retain their contract.
Initial-run admission still refuses extra receipts. Reader validation remains
unchanged; this increment adds no migration and rewrites no selected input bytes.

Checkpoint custody compares the persisted projection to the live input. Full
live-operation custody remains exact. Selected-source and target-entry checks
compare the projection on both sides, so an admitted earlier development save
with economic receipts is not stranded by their presence.

Money, inventory, reward counters and the settled board own the consequences.
The independent consequence ledger still owns Supportz eligibility. Story,
Challenge, admission and Contacts receipts remain until their active consumers
have direct replacement state. This is one completed slice of the receipt
replacement, not removal of the entire ledger. No performance gain is claimed.

## Failure and acceptance checks

- A failed physical write leaves live gameplay and disk state unchanged.
- An exact live retry cannot debit, reward or write twice.
- A changed live request is refused.
- An uncertain write acknowledgment prevents further gameplay mutation.
- Fresh Load retains the full caption, active Challenge, inventory and money.
- Pre-Load economic commands cannot act on the restored branch.
- Fresh completion of an already settled board does not reward or write.
- Supportz remains eligible after two base rounds and a same-day fresh Load.
- Ordinary next-day progression keeps its existing counters and eligibility.

Existing connected and transaction tests cover these behaviors. The PR records
cloud results for the final candidate. No local Godot execution qualifies it.
