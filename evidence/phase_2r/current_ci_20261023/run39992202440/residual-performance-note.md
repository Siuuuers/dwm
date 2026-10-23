# Residual authored Backup latency — existing trace review

Read-only analysis of `seed-native-success.zip`, SHA256 `c49053565e4b9430f2e9f0157eea9c1602898156de13df2837ca714235279670`; candidate run39988834004, source8ced88776993efecf3229b603dbd9671d7584549. No engine run, code change or new test. The accepted matched experiment improves this recorded workload, but large player-visible pauses remain.

## User-observable residuals

From original `terminal-pair.json`: boot60.130s, complete Load phase397.535s, complete Save phase246.436s. Title Backup opening49.361s; Load action to owner Ready294.228s; Load press-return347.373s; ending Backup opening59.768s; Save press-return184.838s. Slot selection and Continue are each under0.1s. Press-return includes the existing five frame waits. Ready and press-return overlap; do not add them. Load Ready precedes press-return by53.146s, an observable remainder whose cause is not established by these aggregate timestamps.

## Largest timed owner work

| Existing trace scope | Recorded elapsed | Recorded internal phases / limit |
|---|---:|---|
| Load `backup_commit`, slot_2.json |142.020s| `restore_commit_us`127.368s; reconcile14.605s. Result `scene_activation_pending` is an intermediate outcome in an ultimately passing native journey, not an overall Load failure. |
| `restore_transaction` |52.766s| Entire duration recorded as unphased. Its relationship to other scopes is nested; do not add it to the commit total. |
| Slowest `backup_inspection`, slot:3 |42.280s| admission20.900s; restore_prepare20.486s; parse0.836s; revision read0.012s. |
| Save `backup_prepare`, slot:3 |41.334s| capture20.844s; document_build20.375s. |
| Save `backup_commit`, slot_3.json |36.688s| write_atomic21.643s; source_recheck8.027s; journal_commit6.741s; serialize0.242s. `write_atomic` is an owner scope, not proof that physical disk I/O alone costs21.643s. |

The Load phase contains five slot:2 inspections of36.301,36.527,39.923,41.502,38.926seconds, interleaved with repeated autosave/slot:1 inspections. The Save phase has two slot:2 inspections36.313/35.507seconds and one slot:3 inspection42.280seconds. Repetition is established; redundancy or safe removal is not. The action preparation inspection nests within its enclosing action timer.

`DWM_SCENE_VALIDATION_PROFILE` explicitly labels inclusive nested timings. Load records316 receipt validations/221.748s,572 bundle validations/109.847s,316 physical proofs/63.187s, and88 snapshot validations. Save records246 receipt validations/166.882s,472 bundle validations/83.688s,246 physical proofs/47.055s, and56 snapshots. These totals overlap each other and the scopes above; they are not additive costs, exclusive percentages or guaranteed optimization savings. Repeated sequence71 validation during Load (29 snapshots) does not alone establish identical input/custody.

## Smallest justified next investigation

Use the already retained exact terminal source slot and native helper as the workload. First map each expensive slot:2 inspection to its actual UI/controller call, input revision and authority boundary; separately identify what the127.368s restore-commit scope encloses. The concrete candidate for review is repeated full inspection/projection around one Load action, because each observed pass costs roughly36–42s while selection itself is cheap. Remove work only after proving identical immutable inputs and an existing authoritative validation owner; do not introduce a broader cache or skip action freshness from these numbers alone.

If code inspection cannot resolve the caller mapping, add only scoped caller/phase attribution for one matched diagnostic, preserving source slot, helper, capture point and action guards. Evaluate a proposed change using the complete Load/Save operation and visible readiness, not a faster nested microphase. No speed guarantee follows; one recorded run per revision is not a distribution or cold/mixed performance claim.

## Original uninterrupted-week worst transitions

The retained original at `evidence/phase_2r/current_ci_20261023/run39973922887/original.zip` was inspected directly. Its SHA256 matches `d1d7d8c5c31d29f1b3ae22ad420101a7ec4f80b2d96f7aa9809df82b936c8a9d`. Source0493deb8bb7a5fc2f99c254db80b29ddf3dcf91a (tree d9f19fb73bc38a3ddd80d5c805c6f4c44f72910c), controller ee50e784adc6b8ec543ea59a271a67b610f3b976. The completed native journey observed836 captions and835 transition timings in2755.800s (45m55.8s), reached COMPLETED/GALLERY_RECORDED and exactly1 Gallery receipt. Thus uninterrupted coverage exists; the older caption805 interrupted attempt is superseded for this coverage question.

Largest recorded transitions, identified by destination caption:

| Destination caption | Elapsed |
|---|---:|
| `line.Day7.A.001` | 216.631s |
| `line.Day6.A.001` | 201.092s |
| `line.Day5.A.001` | 179.672s |
| `line.Day4.A.001` | 135.447s |
| `line.Day3.lavinia.result.A.001` | 118.802s |

These are complete observed transition durations, not attributed owner costs. Day6 has the largest recorded day total,562.104s; day totals cannot establish a per-caption average without their own counts. This original uninterrupted run predates the accepted seed optimization and the terminal pair uses a different source/workload. Its worst transition remains a useful exact reproduction target, not a measured post-optimization latency or evidence that the same phase causes the terminal-pair pause. Do not add these timings to the separate terminal Load/Save scopes above.
