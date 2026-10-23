[CmdletBinding()]
param()

# Proves the Phase 2R preservation claim as what it actually is: a HISTORICAL statement that the
# preserved documents were untouched BY the migration, across a finite, closed interval.
#
# test_legacy_disposition.gd deliberately does not read the preserved files' current bytes or
# current existence. Doing so turned "unchanged during Phase 2R" into "unchangeable forever", and a
# later author edit to CLAUDE.md broke a historical gate it could not logically falsify. The
# interval proof lives here instead, where git can actually see history (plan-author ruling,
# 2026-08-10).

$ErrorActionPreference = 'Stop'

$capture = '825ebdf2abdcdd35e28d8f868ee397fd89faf8a6'
$completion = '6d304eaca306868187a80c7566a050f3f2da3498'
$preserved = @('CLAUDE.md', 'dialogic fx.md')

# The verified historical blobs at both ends of the interval. Pinning these means the proof still
# holds even if the interval commits are ever rewritten or relocated.
$expectedBlobs = [ordered]@{
    'CLAUDE.md'      = 'b3430792c1f13aadb7ca37c5968018823f97a8bc'
    'dialogic fx.md' = '924edba1b46a86c1efd09925b3544ecb41c56fad'
}

git merge-base --is-ancestor $capture $completion
if ($LASTEXITCODE -ne 0) { throw 'PRESERVATION_BOUNDARY_ANCESTRY' }

git diff --quiet $capture $completion -- @preserved
if ($LASTEXITCODE -ne 0) { throw 'PRESERVED_FILE_CHANGED_DURING_PHASE2R' }

foreach ($path in $preserved) {
    foreach ($boundary in @($capture, $completion)) {
        $blob = (git rev-parse ("{0}:{1}" -f $boundary, $path)).Trim()
        if ($LASTEXITCODE -ne 0) { throw ('PRESERVED_FILE_MISSING_AT_BOUNDARY: ' + $path) }
        if ($blob -cne $expectedBlobs[$path]) {
            throw ('PRESERVED_BLOB_MISMATCH: {0} at {1} is {2}' -f $path, $boundary, $blob)
        }
    }
}

Write-Output ('PHASE2R_PRESERVATION_BOUNDARY: PASS interval={0}..{1} files={2}' -f
    $capture.Substring(0, 8), $completion.Substring(0, 8), $preserved.Count)
