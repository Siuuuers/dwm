[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$BdCommand = 'bd'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object Text.UTF8Encoding($false)

function Get-CanonicalPath {
    param([string]$Path)
    return [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
}
function Test-StrictDescendant {
    param([string]$Root, [string]$Candidate)
    $rootFull = Get-CanonicalPath $Root; $candidateFull = Get-CanonicalPath $Candidate
    return $candidateFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}
function Assert-NonReparseChain {
    param([string]$Root, [string]$Candidate, [switch]$Strict)
    $rootFull = Get-CanonicalPath $Root; $candidateFull = Get-CanonicalPath $Candidate
    if (-not ($candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or (Test-StrictDescendant $rootFull $candidateFull)) -or
        ($Strict -and $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase))) { throw 'BEADS_SNAPSHOT_PATH_OUTSIDE_REPOSITORY' }
    $relative = $candidateFull.Substring($rootFull.Length).TrimStart('\','/'); $cursor = $rootFull
    foreach ($part in @('') + @(if ($relative) { $relative -split '[\/]' } else { @() })) {
        if ($part) { $cursor = Join-Path $cursor $part }
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -Force -LiteralPath $cursor
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "BEADS_SNAPSHOT_REPARSE: $cursor" }
        }
    }
    return $candidateFull
}

$repositoryRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'project.godot') -PathType Leaf)) { throw 'BEADS_SNAPSHOT_REPOSITORY_INVALID' }
$reader = Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot 'tools\testing\Read-StrictJson.ps1') -Strict
. $reader
$outputFull = Assert-NonReparseChain $repositoryRoot $(if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $repositoryRoot $OutputPath }) -Strict
$parent = Split-Path -Parent $outputFull
[void](Assert-NonReparseChain $repositoryRoot $parent -Strict)
[IO.Directory]::CreateDirectory($parent) | Out-Null
[void](Assert-NonReparseChain $repositoryRoot $parent -Strict)

$stdoutLines = @(& $BdCommand list --status all --json --readonly)
$bdExit = $LASTEXITCODE
if ($bdExit -ne 0) { throw "BD_LIST_ALL_FAILED: exit=$bdExit" }
$json = [string]::Join([Environment]::NewLine, $stdoutLines).Trim()
if ($json.Length -lt 2 -or $json[0] -cne '[' -or $json[$json.Length - 1] -cne ']') { throw 'BD_LIST_ALL_TOP_LEVEL_ARRAY_REQUIRED' }
$parsedRecords = ConvertFrom-Phase2RStrictJson -Json $json -Label 'bd list --status all --json --readonly'
$records = @($parsedRecords)
if ($records.Count -eq 0) { throw 'BD_LIST_ALL_EMPTY' }
foreach ($record in $records) {
    $hasId = $null -ne $record -and (
        ($record -is [Collections.IDictionary] -and $record.Contains('id')) -or
        ($record -is [psobject] -and $null -ne $record.PSObject.Properties['id'])
    )
    if (-not $hasId) { throw 'BD_LIST_ALL_RECORD_INVALID' }
}

$temporary = $outputFull + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
[void](Assert-NonReparseChain $repositoryRoot $temporary -Strict)
$replacementBackup = $outputFull + '.' + [guid]::NewGuid().ToString('N') + '.bak'
[void](Assert-NonReparseChain $repositoryRoot $replacementBackup -Strict)
try {
    [IO.File]::WriteAllBytes($temporary, $utf8NoBom.GetBytes($json + "`n"))
    if (Test-Path -LiteralPath $outputFull -PathType Leaf) { [IO.File]::Replace($temporary, $outputFull, $replacementBackup) }
    else { [IO.File]::Move($temporary, $outputFull) }
} finally {
    if (Test-Path -LiteralPath $temporary -PathType Leaf) { [IO.File]::Delete($temporary) }
    if (Test-Path -LiteralPath $replacementBackup -PathType Leaf) { [IO.File]::Delete($replacementBackup) }
}
[void](Assert-NonReparseChain $repositoryRoot $outputFull -Strict)
$written = (New-Object Text.UTF8Encoding($false, $true)).GetString([IO.File]::ReadAllBytes($outputFull)).Trim()
[void](ConvertFrom-Phase2RStrictJson -Json $written -Label $outputFull)
Write-Output ("BEADS_SNAPSHOT: PASS records={0}" -f $records.Count)
