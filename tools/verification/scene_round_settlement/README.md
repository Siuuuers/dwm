# Scene Minesweeper settlement

A terminal board applies its reward once on the current timeline. Settlement advances its revision. A request for the same visible, settled board returns `already_applied` at its current or immediately preceding revision. Immediately after settlement this includes the original terminal request. Later changes in board revision move the acknowledgement window forward. An earlier board, an older revision, or a future revision is refused. The reply depends only on the current board and the request. This rule also applies after Load.

## Scope

The model covers two consecutive boards within one active run and one save slot. Each board starts at its terminal revision. The model represents a complete board identity by a round number and uses revisions 2 and 3 for the terminal and settled positions. A grant counts one settlement with its calculated reward, independent of difficulty, outcome, daily cap or amount. The transaction gate holds other settlement and Save operations until the active request finishes.

| Model action | Game behavior |
| --- | --- |
| Prepare, Refuse, Adopt | Validate the terminal board and expected revision. Successful adoption advances the board and gameplay together. A refused preparation leaves them unchanged. Ordinary settlement leaves the save slot alone. |
| Save | A successful Save9 write persists a matching board and gameplay. A failed write leaves the prior slot available. |
| Load | Reopening selects the last saved board and gameplay and drops an unfinished request. Restoring a save made before settlement also rewinds the corresponding grant. |
| NextRound | A subsequent board reaches its own terminal revision. Retrying the first board now encounters a different identity. |

TLC checks that each saved or live board has exactly the expected count of grants, that a settled board acknowledges both valid revisions, and that stale requests are refused. Under continued valid retries and opportunities to adopt, an eligible round cannot remain unpaid forever. The finite model assumes ordinary in-memory settlement is isolated and a successful slot write is atomic. The native transaction test exercises the gameplay amounts, scene checkpoint, and compact saved bytes. [Godot transaction test](../../../tests/integration/test_scene_round_checkpoint_transaction.gd)

## Check the revision rule

The second configuration accepts only the board's current revision. TLC finds a counterexample immediately after the first successful adoption. The original request still carries revision 2, and the same board is now settled at revision 3. An exact-current-revision check would incorrectly refuse that retry.

Run from the repository root with the pinned TLC 1.8.0 jar and checksum from the [story progression instructions](../story_progression/README.md#reproduce). The temporary directory holds the checker state and expected counterexample.

```sh
model_dir=$(mktemp -d)
cp tools/verification/scene_round_settlement/*.tla tools/verification/scene_round_settlement/*.cfg "$model_dir/"
cd "$model_dir"
java -cp /tmp/tla2tools.jar tlc2.TLC -workers 1 SceneRoundSettlement
java -cp /tmp/tla2tools.jar tlc2.TLC -workers 1 -config ExactRevisionOnly.cfg SceneRoundSettlement
```

The first command completed with 14 distinct states, 39 generated states and depth 7. The second exited 12 with the expected `RetryAcknowledged` counterexample at depth 3.
