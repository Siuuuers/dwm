param(
    [switch]$Regenerate,
    [switch]$EmitPayloads
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/public-surfaces'
$runner = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
New-Item -ItemType Directory -Force -Path $output | Out-Null

# These unused APIs were retired after caller and authority review. Search the complete CI
# checkout, including the facade itself: the normal inventory excludes internal
# references and stops looking for a symbol once its declaration is removed.
# tools/ is intentionally outside the production inventory's four search roots.
$retired = @(
    'get_affection_tier'
    'is_contact_choice_selected'
    'get_contact_choices'
    'can_respond_to_invitation'
    'can_buy_supportz'
    'has_unread_friend_messages'
    'prepare_run_candidate'
    'commit_run_candidate'
    'get_minesweeper_safety_level'
    'should_warn_minesweeper_before_schedule_done'
)
$searchRoots = @('autoload', 'scripts', 'scenes', 'tests')
$pattern = '\b(?:' + (($retired | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b'
$retiredReferences = @()
$sourceCount = 0
foreach ($root in $searchRoots) {
    $absoluteRoot = Join-Path $repositoryRoot $root
    if (-not (Test-Path -LiteralPath $absoluteRoot -PathType Container)) {
        throw "Required whole-tree search root is missing: $root"
    }
    $files = @(Get-ChildItem -LiteralPath $absoluteRoot -File -Recurse |
        Where-Object { $_.Extension -in @('.gd', '.tscn') } | Sort-Object FullName)
    if ($files.Count -eq 0) { throw "Required whole-tree search root is empty: $root" }
    $sourceCount += $files.Count
    foreach ($file in $files) {
        foreach ($match in @(Select-String -LiteralPath $file.FullName -Pattern $pattern -CaseSensitive)) {
            $retiredReferences += [ordered]@{
                path = [IO.Path]::GetRelativePath($repositoryRoot, $file.FullName).Replace('\', '/')
                line = $match.LineNumber
                symbol = $match.Matches[0].Value
            }
        }
    }
}
$audit = [ordered]@{
    checkout_ref = (& git -C $repositoryRoot rev-parse HEAD)
    retired_symbols = $retired
    search_roots = $searchRoots
    source_files = $sourceCount
    references = $retiredReferences
}
if ($LASTEXITCODE -ne 0) { throw 'Unable to identify the checked-out commit.' }
$audit | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'retirement-audit.json') -Encoding utf8
if ($retiredReferences.Count -ne 0) {
    $retiredReferences | ConvertTo-Json -Depth 4 | Write-Host
    throw 'Retired GameState API declarations or references remain in the complete checkout.'
}
Write-Host "PUBLIC_SURFACE_RETIRED_APIS_VERIFIED: $($retired.Count) symbols; $sourceCount source files; zero remaining references."

function Invoke-SurfaceInventory {
    param([string]$Target, [bool]$Check)
    $mode = if ($Check) { 'check' } else { 'generate' }
    $scriptName = if ($Target -eq 'game_state') { 'GameState' } else { 'SaveManager' }
    $logName = "cloud-public-surface-$Target-$mode.log"
    $arguments = @(
        '-s', 'res://tools/runtime/generate_public_surface_inventory.gd', '--'
        "--script=res://autoload/$scriptName.gd"
        "--required=res://evidence/phase_2r/runtime/${Target}_required_surface.json"
        "--output=res://evidence/phase_2r/runtime/${Target}_surface.json"
    )
    foreach ($root in $searchRoots) { $arguments += "--search-root=res://$root" }
    if ($Check) { $arguments += '--check' }
    & $runner -SuiteId "cloud-public-surface-$Target-$mode" -LogName $logName `
        -EvidenceLogPath ".godot/ci/public-surfaces/$Target-$mode.jsonl" -GodotArgs $arguments | Out-Null
    $result = $LASTEXITCODE
    $log = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
    if ($result -ne 0) {
        if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Write-Host }
        throw "Public surface $Target $mode failed with exit $result."
    }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet) {
        throw "Public surface $Target $mode reported script or Unicode errors."
    }
    $markers = @(Get-Content -LiteralPath $log | Where-Object { $_ -ceq 'SURFACE_INVENTORY: PASS' })
    if ($markers.Count -ne 1) { throw "Public surface $Target $mode did not report one pass marker." }
}

function Write-SurfacePayload {
    param([string]$RelativePath)
    $absolutePath = Join-Path $repositoryRoot $RelativePath
    $bytes = [IO.File]::ReadAllBytes($absolutePath)
    $sha256 = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $stream = [IO.MemoryStream]::new()
    $gzip = [IO.Compression.GZipStream]::new($stream, [IO.Compression.CompressionLevel]::Optimal, $true)
    try { $gzip.Write($bytes, 0, $bytes.Length) } finally { $gzip.Dispose() }
    $compressed = $stream.ToArray()
    $stream.Dispose()
    $base64 = [Convert]::ToBase64String($compressed)
    $chunkSize = 2048
    $parts = [int][Math]::Ceiling($base64.Length / [double]$chunkSize)
    $metadata = [ordered]@{
        path = $RelativePath
        encoding = 'gzip+base64'
        sha256 = $sha256
        bytes = $bytes.Length
        compressed_bytes = $compressed.Length
        parts = $parts
    }
    Write-Host ('DWM_PUBLIC_SURFACE_PAYLOAD_BEGIN ' + ($metadata | ConvertTo-Json -Compress))
    for ($index = 0; $index -lt $parts; $index++) {
        $offset = $index * $chunkSize
        $chunk = [ordered]@{
            path = $RelativePath
            index = $index
            data = $base64.Substring($offset, [Math]::Min($chunkSize, $base64.Length - $offset))
        }
        Write-Host ('DWM_PUBLIC_SURFACE_PAYLOAD_CHUNK ' + ($chunk | ConvertTo-Json -Compress))
    }
    Write-Host ('DWM_PUBLIC_SURFACE_PAYLOAD_END ' + ($metadata | ConvertTo-Json -Compress))
}

foreach ($target in @('game_state', 'save_manager')) {
    if ($Regenerate) { Invoke-SurfaceInventory -Target $target -Check $false }
    Invoke-SurfaceInventory -Target $target -Check $true
    $relativePath = "evidence/phase_2r/runtime/${target}_surface.json"
    Copy-Item -LiteralPath (Join-Path $repositoryRoot $relativePath) -Destination (Join-Path $output "${target}_surface.json")
    if ($EmitPayloads) { Write-SurfacePayload -RelativePath $relativePath }
}
Write-Host 'PUBLIC_SURFACE_VALIDATION_VERIFIED: both complete-tree inventories reproduce canonical bytes.'
