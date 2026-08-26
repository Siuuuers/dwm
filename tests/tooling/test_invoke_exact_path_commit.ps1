[CmdletBinding()]
param(
    [ValidateSet('ExpectMissing','Verify')]
    [string]$Mode = 'Verify'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$helper = Join-Path $repositoryRoot 'tools\git\Invoke-ExactPathCommit.ps1'

if ($Mode -eq 'ExpectMissing') {
    if (Test-Path -LiteralPath $helper) { throw 'EXACT_PATH_COMMIT_UNEXPECTEDLY_PRESENT' }
    Write-Output 'EXACT_PATH_COMMIT_MISSING: PASS'
    exit 0
}
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) { throw 'EXACT_PATH_COMMIT_MISSING' }

$scratchParent = Join-Path $repositoryRoot '.godot\phase2r_tests'
[void][IO.Directory]::CreateDirectory($scratchParent)
$scratchRoot = Join-Path $scratchParent ([guid]::NewGuid().ToString('D').ToLowerInvariant())
[void][IO.Directory]::CreateDirectory($scratchRoot)
$powershell = (Get-Process -Id $PID).Path

function Quote-Literal {
    param([AllowEmptyString()][string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Write-Utf8File {
    param([string]$Path, [string]$Text)
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

function Invoke-Git {
    param([string]$Repository, [string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git -C $Repository @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($code -ne 0) { throw "FIXTURE_GIT: git $($Arguments -join ' ')`n$($output -join "`n")" }
    return @($output | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
}

function New-FixtureRepository {
    $path = Join-Path $scratchRoot ([guid]::NewGuid().ToString('D').ToLowerInvariant())
    [void][IO.Directory]::CreateDirectory($path)
    [void](Invoke-Git $path @('init','-q'))
    [void](Invoke-Git $path @('config','user.name','Phase2R Fixture'))
    [void](Invoke-Git $path @('config','user.email','phase2r-fixture@example.invalid'))
    Write-Utf8File (Join-Path $path 'modify.txt') "before`n"
    Write-Utf8File (Join-Path $path 'delete.txt') "delete`n"
    Write-Utf8File (Join-Path $path 'source.txt') "copy-source`n"
    Write-Utf8File (Join-Path $path 'unchanged.txt') "unchanged`n"
    [void](Invoke-Git $path @('add','--','modify.txt','delete.txt','source.txt','unchanged.txt'))
    [void](Invoke-Git $path @('commit','-q','-m','fixture base'))
    return $path
}

function Get-Head {
    param([string]$Repository)
    return [string](@(Invoke-Git $Repository @('rev-parse','HEAD'))[0]).Trim()
}

function ConvertTo-MapLiteral {
    param([System.Collections.IDictionary]$Map)
    $pairs = @($Map.Keys | ForEach-Object { (Quote-Literal ([string]$_)) + '=' + (Quote-Literal ([string]$Map[$_])) })
    return '[ordered]@{' + ($pairs -join ';') + '}'
}

function ConvertTo-ArrayLiteral {
    param([string[]]$Values)
    return '@(' + (@($Values | ForEach-Object { Quote-Literal ([string]$_) }) -join ',') + ')'
}

function Invoke-CommitFixture {
    param(
        [string]$Repository,
        [System.Collections.IDictionary]$Required,
        [System.Collections.IDictionary]$Optional = ([ordered]@{}),
        [string[]]$Allowed = @(),
        [string[]]$WhitespaceExempt = @(),
        [string[]]$ExtraAuthorities = @(),
        [ValidateSet('Valid','Missing','Empty','Wrong')][string]$ExpectedHeadMode = 'Valid',
        [bool]$AuthorizeCommit = $true,
        [bool]$AuthorizeExtra = $true,
        [bool]$RequireRemainingDirtyExact = $false,
        [string]$Prelude = ''
    )
    $head = Get-Head $Repository
    $expectedArgument = switch ($ExpectedHeadMode) {
        'Missing' { '' }
        'Empty' { " -ExpectedHead ''" }
        'Wrong' { " -ExpectedHead '0000000000000000000000000000000000000000'" }
        default { ' -ExpectedHead ' + (Quote-Literal $head) }
    }
    $environment = "`$env:DWM_COMMIT_AUTHORIZED=" + $(if ($AuthorizeCommit) { "'1'" } else { '$null' }) + ';'
    foreach ($name in $ExtraAuthorities) {
        $environment += "`$env:$name=" + $(if ($AuthorizeExtra) { "'1'" } else { '$null' }) + ';'
    }
    $switch = if ($RequireRemainingDirtyExact) { ' -RequireRemainingDirtyExact' } else { '' }
    $command = "Set-Location $(Quote-Literal $Repository); $environment $Prelude & $(Quote-Literal $helper)" +
        ' -RequiredStatus (' + (ConvertTo-MapLiteral $Required) + ')' +
        ' -OptionalPresentStatus (' + (ConvertTo-MapLiteral $Optional) + ')' +
        ' -AllowedDirtyPaths ' + (ConvertTo-ArrayLiteral $Allowed) +
        ' -WhitespaceExemptPaths ' + (ConvertTo-ArrayLiteral $WhitespaceExempt) +
        ' -RequiredAuthorityVariables ' + (ConvertTo-ArrayLiteral $ExtraAuthorities) +
        $expectedArgument + $switch + " -Message 'fixture commit'; if (`$?) { exit `$LASTEXITCODE }; if (`$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }; exit 1"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $powershell
    $start.Arguments = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'FIXTURE_CHILD_START' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        Output = ($stdoutTask.GetAwaiter().GetResult() + "`n" + $stderrTask.GetAwaiter().GetResult()).Trim()
    }
}

function Assert-Success {
    param($Result, [string]$Label)
    if ($Result.ExitCode -ne 0 -or -not $Result.Output.Contains('EXACT_PATH_COMMIT: PASS')) {
        throw "${Label}: expected success, exit=$($Result.ExitCode)`n$($Result.Output)"
    }
}

function Assert-Rejected {
    param($Result, [string]$Pattern, [string]$Label)
    if ($Result.ExitCode -eq 0 -or -not $Result.Output.Contains($Pattern)) {
        throw "${Label}: expected rejection '$Pattern', exit=$($Result.ExitCode)`n$($Result.Output)"
    }
}

try {
    $repo = New-FixtureRepository
    Write-Utf8File (Join-Path $repo 'add.txt') "add`n"
    Write-Utf8File (Join-Path $repo 'modify.txt') "after`n"
    Remove-Item -LiteralPath (Join-Path $repo 'delete.txt')
    Write-Utf8File (Join-Path $repo 'generated.uid') "uid`n"
    Write-Utf8File (Join-Path $repo 'allowed.tmp') "dirty`n"
    $before = Get-Head $repo
    $result = Invoke-CommitFixture $repo ([ordered]@{'add.txt'='A';'modify.txt'='M';'delete.txt'='D'}) ([ordered]@{'generated.uid'='A'}) @('allowed.tmp') @() @() Valid $true $true $true
    Assert-Success $result 'required-and-optional-present'
    $parentLine = [string](@(Invoke-Git $repo @('rev-list','--parents','-n','1','HEAD'))[0])
    $parents = @($parentLine -split ' ')
    if ($parents.Count -ne 2 -or $parents[1] -cne $before) { throw 'DIRECT_CHILD_ANCESTRY' }
    $remaining = @(Invoke-Git $repo @('status','--porcelain'))
    if ($remaining.Count -ne 1 -or $remaining[0] -notmatch 'allowed\.tmp$') { throw 'EXACT_ALLOWED_DIRTY_REMAINDER' }

    $repo = New-FixtureRepository
    Write-Utf8File (Join-Path $repo 'modify.txt') "optional-absent`n"
    Assert-Success (Invoke-CommitFixture $repo ([ordered]@{'modify.txt'='M'}) ([ordered]@{'generated.uid'='A'})) 'optional-absent'

    $repo = New-FixtureRepository
    Write-Utf8File (Join-Path $repo 'add.txt') "x`n"
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'add.txt'='A'}) -AuthorizeCommit $false) 'Explicit commit authority is required.' 'missing-authority'
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'add.txt'='A'}) -ExtraAuthorities @('DWM_ARCHIVE_DELETION_AUTHORIZED') -AuthorizeExtra $false) 'Missing exact extra authority' 'missing-extra-authority'
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'add.txt'='A'}) -ExtraAuthorities @('NOT_ALLOWED') -AuthorizeExtra $true) 'Missing exact extra authority' 'malformed-extra-authority'

    foreach ($headMode in @('Missing','Empty','Wrong')) {
        $repo = New-FixtureRepository
        Write-Utf8File (Join-Path $repo 'add.txt') "x`n"
        $pattern = if ($headMode -eq 'Wrong') { 'HEAD differs from the required parent boundary.' } else { 'ExpectedHead' }
        Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'add.txt'='A'}) -ExpectedHeadMode $headMode) $pattern "expected-head-$headMode"
    }

    $repo = New-FixtureRepository
    Write-Utf8File (Join-Path $repo 'unrelated.txt') "staged`n"
    [void](Invoke-Git $repo @('add','--','unrelated.txt'))
    Write-Utf8File (Join-Path $repo 'add.txt') "x`n"
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'add.txt'='A'})) 'Staged index is not empty.' 'dirty-index'

    $repo = New-FixtureRepository
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'missing.txt'='A'})) 'Required A path is not a present untracked file' 'missing-addition'
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'missing.txt'='M'})) 'Required M path is not a present tracked file' 'missing-modification'
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'delete.txt'='D'})) 'Required D path is not an absent tracked file' 'present-deletion'
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'../escape.txt'='A'})) 'Non-literal repository path' 'malformed-path'

    $repo = New-FixtureRepository
    Write-Utf8File (Join-Path $repo 'modify.txt') "after`n"
    Write-Utf8File (Join-Path $repo 'extra.txt') "extra`n"
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'modify.txt'='M'}) -RequireRemainingDirtyExact $true) 'Remaining worktree paths differ from the exact allowed-dirty set.' 'extra-dirty-path'

    $repo = New-FixtureRepository
    [void][IO.Directory]::CreateDirectory((Join-Path $repo 'evidence\phase_2r\logs'))
    Write-Utf8File (Join-Path $repo 'evidence\phase_2r\logs\captured.log') "captured trailing whitespace `n"
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'evidence/phase_2r/logs/captured.log'='A'})) 'Staged diff check failed.' 'immutable-log-needs-explicit-exemption'

    $repo = New-FixtureRepository
    [void][IO.Directory]::CreateDirectory((Join-Path $repo 'evidence\phase_2r\logs'))
    Write-Utf8File (Join-Path $repo 'evidence\phase_2r\logs\captured.log') "captured trailing whitespace `n"
    Assert-Success (Invoke-CommitFixture $repo ([ordered]@{'evidence/phase_2r/logs/captured.log'='A'}) -WhitespaceExempt @('evidence/phase_2r/logs/captured.log')) 'explicit-immutable-log-whitespace-exemption'

    $repo = New-FixtureRepository
    Write-Utf8File (Join-Path $repo 'source.gd') "var unsafe = true `n"
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'source.gd'='A'}) -WhitespaceExempt @('source.gd')) 'Whitespace exemption is restricted to immutable Phase 2R logs' 'source-whitespace-exemption-forbidden'

    $repo = New-FixtureRepository
    Write-Utf8File (Join-Path $repo 'add.txt') "x`n"
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'add.txt'='A'}) -WhitespaceExempt @('evidence/phase_2r/logs/not-staged.log')) 'Whitespace-exempt path is not in the commit set' 'unstaged-whitespace-exemption-forbidden'

    $repo = New-FixtureRepository
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'modify.txt'='M'})) 'Refusing an empty commit.' 'empty-commit'

    $repo = New-FixtureRepository
    $same = [IO.File]::ReadAllText((Join-Path $repo 'delete.txt'))
    Remove-Item -LiteralPath (Join-Path $repo 'delete.txt')
    Write-Utf8File (Join-Path $repo 'renamed.txt') $same
    Assert-Success (Invoke-CommitFixture $repo ([ordered]@{'delete.txt'='D';'renamed.txt'='A'})) 'declared-rename-pair-commits-as-literal-statuses'

    $repo = New-FixtureRepository
    Write-Utf8File (Join-Path $repo 'copied.txt') ([IO.File]::ReadAllText((Join-Path $repo 'source.txt')))
    Assert-Success (Invoke-CommitFixture $repo ([ordered]@{'copied.txt'='A'})) 'content-copy-commits-as-a-literal-add'

    $repo = New-FixtureRepository
    Write-Utf8File (Join-Path $repo 'modify.txt') "hook-failure`n"
    $hook = Join-Path $repo '.git\hooks\pre-commit'
    Write-Utf8File $hook "#!/bin/sh`nexit 1`n"
    Assert-Rejected (Invoke-CommitFixture $repo ([ordered]@{'modify.txt'='M'})) 'git commit failed.' 'failed-commit'

    Write-Output 'EXACT_PATH_COMMIT_BEHAVIOR: PASS'
} finally {
    if (Test-Path -LiteralPath $scratchRoot) {
        $root = [IO.Path]::GetFullPath($scratchParent).TrimEnd('\','/')
        $target = [IO.Path]::GetFullPath($scratchRoot)
        if (-not $target.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'FIXTURE_CLEANUP_CONTAINMENT'
        }
        foreach ($item in @(Get-Item -Force $scratchRoot) + @(Get-ChildItem -Force -Recurse $scratchRoot)) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'FIXTURE_CLEANUP_REPARSE' }
        }
        Remove-Item -LiteralPath $scratchRoot -Recurse -Force
    }
}
