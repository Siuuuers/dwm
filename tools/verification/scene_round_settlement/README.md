# Scene Minesweeper settlement

A terminal round applies its reward once on the current timeline. An exact retry in the same session returns the original receipt. A separate Save records the settled board and resulting gameplay together. Loading that save clears session receipts. A fresh completion request at the restored board's current revision returns “already settled” and leaves gameplay alone.

## Scope

The model covers two consecutive rounds, three issued transaction tokens, one active run and one save slot. Each round begins at its terminal revision. The relative revision advances from 0 to 1 upon settlement. One grant counts a settlement including its computed reward, independent of difficulty, outcome, daily cap or amount. The guard serializes settlement with Save. An explicit successful save writes one complete compact record. A reopen can happen before or after that write. Restoring an earlier save rewinds the board and gameplay together.

| Model action | Game behavior |
| --- | --- |
| Prepare, Refuse, Adopt | GameState checks the issued command, board, revision and ordinal. The narrative checkpoint port validates live publication. On success the game adopts the settled board, gameplay and receipt under its transaction lease. Ordinary completion leaves the save slot alone. |
| Save | RunSnapshotSchema.build_scene projects the board and gameplay into Save9 and omits command receipts. |
| Load | GameState restores the selected saved Run. Its command receipt map starts empty for compact Save9. Loading while a request is pending models closing and reopening the game. |
| NextRound | A subsequent board reaches its own terminal revision. The earlier live receipt remains available until Load. |

The checker verifies the count of grants against each board's round and settlement flag, exact live replay and rejection of a conflicting revision, and acknowledgement of an already settled compact save. The retry property assumes continued valid requests and opportunities for a successful adoption. Under those assumptions the same eligible round cannot stay unpaid forever. Native checks cover real reward amounts, persistence bytes and callback behavior. [Godot transaction test](../../../tests/integration/test_scene_round_checkpoint_transaction.gd)

## Receipt ablation

The board-only configuration checks the same transition graph with the receipt lookup removed from a retry query. TLC finds the sequence **prepare round 1 → adopt → reach round 2 → query the original round 1 request**. The current board answers “source changed”. The live command table returns the original round 1 receipt. This counterexample concerns the reply during a live session. Compact saves already use the board's settled flag to prevent another payout after Load.

## Run TLC

Use the pinned TLC 1.8.0 jar and checksum from the [story progression instructions](../story_progression/README.md#reproduce). Run from the repository root. The temporary directory holds checker output, including the expected counterexample trace.

```sh
model_dir=$(mktemp -d)
cp tools/verification/scene_round_settlement/*.tla tools/verification/scene_round_settlement/*.cfg "$model_dir/"
cd "$model_dir"
java -cp /tmp/tla2tools.jar tlc2.TLC -workers 1 SceneRoundSettlement
java -cp /tmp/tla2tools.jar tlc2.TLC -workers 1 -config BoardOnly.cfg SceneRoundSettlement
```

The first command completed with 80 distinct states, 222 generated states and depth 9. The second exited 12 with the expected BoardOnlyReplay violation at depth 4.
