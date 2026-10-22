# Independent retained-evidence review

Reviewed the retained query binding, query trace, consumer snapshots, exported-load events/result, and diagnostic source. No Godot/PowerShell execution, dispatch, or runtime changes were performed for this review.

## Observed failure

The ending wait expired with no accepted UIA action. Native responsiveness checks consumed most of the original 30-second interval; the first action enumeration began around 29.38 seconds. Both complete harness batches contained 23 descendants: four visible, enabled Pause controls (Continue, Backup, Settings, Return to Title) rejected by exact name, and 19 descendants rejected by `Visible`. The ending Invoke gate was not reached.

The binding contains 149 interval-selected Navigate observations, not 149 successful node selections. Of these, 94 selected a node; none selected or evaluated the ending caption. No observed query record was truncated.

Consumer snapshots contain caption RID `108855946117271`, label `TEST Seven-day ending.`, Button role, and an `Include` filter observation, together with its parent chain through a ScrollView and WitnessedCaptionLayer. This is applied consumer state, not proof of UIA client delivery.

Terminal NextSibling requests **71** and **145** visit `DialogicLayout_WitnessedCaption` RID `108624017883151` with `ExcludeNode`, traverse unnamed/art subtrees, and return no selected node. Neither evaluates WitnessedCaptionLayer, its ScrollView, or the caption. This narrows the investigation to the traversal boundary without establishing an exclusion cause.

## Source semantics

The candidate `consumer-probe/candidate/node.rs` retains the baseline directional iterators. Its wrappers call the original filter once, record the decision, and return that decision unchanged. Navigate returns the original Result. Sink emission occurs after releasing the tree read guard.

The harness `Observe-EndingAction` copies already evaluated values; the visibility → enabled → exact name → Invoke short-circuit sequence remains intact. Null gate fields mean not evaluated, not false.

These observations support semantic preservation of selection, not timing neutrality. Additional allocation, label copying, clock reads, and synchronous sink locking/writes can perturb timing.

## Smallest next discriminator

Within the same Navigate tree-read snapshot, capture bounded ordered children and reciprocal parent links at the layout boundary, together with the actual traversal skip/termination decision. Distinguish a caption-layer branch missing from the traversed child list from a branch skipped by iterator logic or internal filtering. More caption-name/Invoke reads or a longer timeout would not answer this question.

No runtime behavior fix is justified by this evidence alone.

## Limits

The query stream has no closing footer and covers armed, resolver-entered callbacks only. Harness ordinals and native request IDs are not shared. Parent-chain snapshots alone do not establish reciprocal child membership at query time. The evidence does not establish continuous absence, client delivery, a save-state fault, or official-build acceptance.
