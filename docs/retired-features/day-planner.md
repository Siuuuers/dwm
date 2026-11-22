# Desktop day planner

Retired on 22 November 2026. The seven-day story advances through authored scene entries. The Computer offers five apps. Earlier planner code and its tests are available at commit `2c3b208`.

The planner controller let players fill daily action slots and confirm warnings. Its downstream guard and publication ledger checked planner commits. The catalog projection exposed actions as UI resources. The retirement removes those paths, their dedicated checks, the unused calendar icon, and planner-specific translations. The unused GameState scheduling commands, warning queries and publication signals were removed with their contract tests. The historical schedule gate no longer runs as a New Game check.

Saved state still carries information shared by Contacts, hospital and dating recovery, and rollback. The empty schedule view retains its persisted shape. Five unused day-resolution getters were removed; the stored receipts and schedule remain available through the existing serializer. Older evidence records remain tied to the revision that produced them.
