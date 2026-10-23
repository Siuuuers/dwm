[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root 'tools\beads\Export-BeadsSnapshot.ps1'
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw 'EXPORT_BEADS_SNAPSHOT_MISSING' }
$scratch = Join-Path $root ('.godot\phase2r_tests\' + [guid]::NewGuid().ToString('D'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
try {
    $fake = Join-Path $scratch 'bd.cmd'
    [IO.File]::WriteAllText($fake, '@echo [{"id":"one","id":"duplicate"}]', [Text.Encoding]::ASCII)
    $output = Join-Path $scratch 'snapshot.json'
    $failed = $false; $text = @()
    try { $text = @(& $script -OutputPath $output -BdCommand $fake 2>&1) }
    catch { $failed = $true; $text += $_.Exception.Message }
    if (-not $failed -or -not ([string]::Join("`n", $text)).Contains('JSON_DUPLICATE_MEMBER')) {
        throw 'EXPORT_BEADS_DUPLICATE_NOT_REJECTED'
    }
    if (Test-Path -LiteralPath $output) { throw 'EXPORT_BEADS_INVALID_OUTPUT_CREATED' }
} finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
Write-Output 'EXPORT_BEADS_FIXTURE: PASS'
