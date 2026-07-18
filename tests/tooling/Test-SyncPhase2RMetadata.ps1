[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root 'tools\beads\Sync-Phase2RMetadata.ps1'
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw 'SYNC_PHASE2R_METADATA_MISSING' }
$scratch = Join-Path $root ('.godot\phase2r_tests\' + [guid]::NewGuid().ToString('D'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
try {
    $manifest = Join-Path $scratch 'duplicate.json'
    [IO.File]::WriteAllText($manifest, '{"schema_version":1,"schema_version":1,"spec_id":"x","child_contracts":[],"deferred_decision_contract":{}}', (New-Object Text.UTF8Encoding($false)))
    $fake = Join-Path $scratch 'bd.cmd'
    [IO.File]::WriteAllText($fake, '@echo FAKE_BD_MUST_NOT_RUN 1>&2 & @exit /b 99', [Text.Encoding]::ASCII)
    $failed = $false; $text = @()
    try { $text = @(& $script -ManifestPath $manifest -SnapshotPath (Join-Path $scratch 'snapshot.json') -BdCommand $fake 2>&1) }
    catch { $failed = $true; $text += $_.Exception.Message }
    if (-not $failed -or -not ([string]::Join("`n", $text)).Contains('JSON_DUPLICATE_MEMBER')) {
        throw 'SYNC_PHASE2R_DUPLICATE_NOT_REJECTED'
    }
    if ([string]::Join("`n", $text).Contains('FAKE_BD_MUST_NOT_RUN')) { throw 'SYNC_PHASE2R_CALLED_BD_BEFORE_VALIDATION' }
} finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
Write-Output 'SYNC_PHASE2R_FIXTURE: PASS'
