# Read-only inventory acceptance

Baseline: `1e4c6f02ddd76454b5cf93c5808b90d16baed296`.

PR validation and strict manual validation now invoke each public inventory's
read-only check once. Only explicit workflow_dispatch with check_generated=false
runs generate followed by check. Both target checks, error-log checks, final
committed-output comparison and artifact retention remain. No coverage is removed.

## Measured reason

[PR #188 authoring job](https://github.com/Siuuuers/dwm/actions/runs/41683678600/job/126083973695)
spent 80.78 seconds generating and checking the two inventories. The generation
passes took approximately 25.38 seconds for GameState and 14.96 seconds for
SaveManager. Removing these duplicate scans represents about 40.3 seconds of
work on that runner; this is a historical estimate, not a measured after-result
or a promised reduction in total workflow wall time.

The same job took 495.31 seconds, including a 230.67-second checkout and an
approximately 22.98-second import. The separate coverage selector took 7.20
seconds, with about 5.16 seconds of sparse checkout. Do not optimize that small
checkout again without evidence. Full runtime checkouts and broad suite selection
remain separate future work requiring a dependency/behavior audit.

Cleanup PRs #186, #188 and #189 selected full validation. The default Windows
matrix has 67 suite entries plus other jobs. The jobs API's first page is not a
complete aggregate time measurement. This change neither suppresses those jobs
nor changes their dependencies.

## Regression coverage

The standard-library Python test executes the actual workflow shell using a
mock engine. It verifies PR and strict-dispatch checks, unchanged stale files on
failure, and explicit regeneration order. The scope job downloads and runs this
test, including when only the test changes. Existing coverage-selector tests and
actionlint validate integration. No new lint framework or dependency is added.
