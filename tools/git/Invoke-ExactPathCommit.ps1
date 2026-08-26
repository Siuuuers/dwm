[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$RequiredStatus,
    [System.Collections.IDictionary]$OptionalPresentStatus = @{},
    [string[]]$AllowedDirtyPaths = @(),
    [string[]]$WhitespaceExemptPaths = @(),
    [string[]]$RequiredAuthorityVariables = @(),
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ExpectedHead,
    [switch]$RequireRemainingDirtyExact,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Message
)

$ErrorActionPreference = 'Stop'

function Assert-RepoPath([string]$Path) {
    $badSegments = @($Path.Split('/') | Where-Object { $_ -in @('', '.', '..') })
    if ([string]::IsNullOrWhiteSpace($Path) -or [IO.Path]::IsPathRooted($Path) -or
        $Path.Contains('\') -or $Path -match '[*?\[\]]' -or $badSegments.Count -ne 0) {
        throw ('Non-literal repository path: ' + $Path)
    }
}

function Invoke-GitSafe([string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $combined = @(& git @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $stdout = @($combined | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
    $stderr = @($combined | Where-Object { $_ -is [Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
    return [pscustomobject]@{ ExitCode = $code; Stdout = $stdout; Stderr = $stderr }
}

function Invoke-GitQuiet([string[]]$Arguments, [string]$Label) {
    $result = Invoke-GitSafe $Arguments
    if ($result.ExitCode -notin @(0, 1)) { throw ($Label + ' failed with Git exit ' + $result.ExitCode) }
    return $result.ExitCode
}

function Test-Tracked([string]$Path) {
    $result = Invoke-GitSafe @('ls-files','--error-unmatch','--',$Path)
    if ($result.ExitCode -eq 0) { return $true }
    if ($result.ExitCode -eq 1) { return $false }
    throw ('Unable to inspect tracked path: ' + $Path)
}

function ConvertTo-StatusMap([string[]]$Lines, [string]$Label) {
    $map = [ordered]@{}
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = @($line -split "`t", -1)
        if ($parts.Count -ne 2 -or $parts[0] -notin @('A','M','D')) {
            throw ($Label + ' has malformed/rename/copy/type/unmerged status: ' + $line)
        }
        Assert-RepoPath $parts[1]
        if ($map.Contains($parts[1])) { throw ($Label + ' repeats path: ' + $parts[1]) }
        $map[$parts[1]] = $parts[0]
    }
    return $map
}

function ConvertTo-RawModeMap([string[]]$Lines, [string]$Label) {
    $map = [ordered]@{}
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch '^:([0-7]{6}) ([0-7]{6}) ([0-9a-f]+) ([0-9a-f]+) ([A-Z][0-9]*)\t(.+)$') {
            throw ($Label + ' has malformed raw record: ' + $line)
        }
        $oldMode = $Matches[1]
        $newMode = $Matches[2]
        $status = $Matches[5]
        $path = $Matches[6]
        Assert-RepoPath $path
        if ($status -notin @('A','M','D') -or $map.Contains($path)) {
            throw ($Label + ' has rename/copy/type/unmerged/duplicate raw record: ' + $line)
        }
        $map[$path] = [ordered]@{status=$status;old_mode=$oldMode;new_mode=$newMode}
    }
    return $map
}

function Assert-ExactMap([System.Collections.IDictionary]$Actual, [System.Collections.IDictionary]$Expected, [string]$Label) {
    if ($Actual.Count -ne $Expected.Count) {
        throw ($Label + ' path cardinality differs: actual=' + $Actual.Count + ' expected=' + $Expected.Count)
    }
    foreach ($path in $Expected.Keys) {
        if (-not $Actual.Contains($path) -or [string]$Actual[$path] -cne [string]$Expected[$path]) {
            throw ($Label + ' expected ' + $Expected[$path] + "`t" + $path)
        }
    }
}

function Assert-ExactRawModes([System.Collections.IDictionary]$Actual, [System.Collections.IDictionary]$Expected, [string]$Label) {
    if ($Actual.Count -ne $Expected.Count) { throw ($Label + ' raw path cardinality differs.') }
    foreach ($path in $Expected.Keys) {
        if (-not $Actual.Contains($path)) { throw ($Label + ' raw record missing: ' + $path) }
        $status = [string]$Expected[$path]
        $record = $Actual[$path]
        $expectedOld = if ($status -eq 'A') { '000000' } else { '100644' }
        $expectedNew = if ($status -eq 'D') { '000000' } else { '100644' }
        if ([string]$record.status -cne $status -or [string]$record.old_mode -cne $expectedOld -or [string]$record.new_mode -cne $expectedNew) {
            throw ($Label + ' expected regular-blob modes ' + $expectedOld + ' -> ' + $expectedNew + ' for ' + $status + "`t" + $path)
        }
    }
}

if ([Environment]::GetEnvironmentVariable('DWM_COMMIT_AUTHORIZED') -cne '1') {
    throw 'Explicit commit authority is required.'
}
foreach ($name in $RequiredAuthorityVariables) {
    if ($name -notmatch '^DWM_[A-Z0-9_]+_AUTHORIZED$' -or
        [Environment]::GetEnvironmentVariable($name) -cne '1') {
        throw ('Missing exact extra authority: ' + $name)
    }
}

$indexCode = Invoke-GitQuiet @('diff','--cached','--quiet') 'Initial index inspection'
if ($indexCode -eq 1) { throw 'Staged index is not empty.' }

$parentResult = Invoke-GitSafe @('rev-parse','--verify','HEAD^{commit}')
$parent = [string]::Join('', @($parentResult.Stdout)).Trim()
if ($parentResult.ExitCode -ne 0 -or -not $parent) { throw 'Cannot resolve current HEAD.' }
if ($parent -cne $ExpectedHead) { throw 'HEAD differs from the required parent boundary.' }

$expected = [ordered]@{}
foreach ($pathObject in $RequiredStatus.Keys) {
    $path = [string]$pathObject
    $status = [string]$RequiredStatus[$pathObject]
    Assert-RepoPath $path
    if ($status -notin @('A','M','D') -or $expected.Contains($path)) { throw ('Invalid required status: ' + $path) }
    $tracked = Test-Tracked $path
    if ($status -eq 'A' -and ($tracked -or -not (Test-Path -LiteralPath $path -PathType Leaf))) { throw ('Required A path is not a present untracked file: ' + $path) }
    if ($status -eq 'M' -and (-not $tracked -or -not (Test-Path -LiteralPath $path -PathType Leaf))) { throw ('Required M path is not a present tracked file: ' + $path) }
    if ($status -eq 'D' -and (-not $tracked -or (Test-Path -LiteralPath $path))) { throw ('Required D path is not an absent tracked file: ' + $path) }
    $expected[$path] = $status
}

foreach ($pathObject in $OptionalPresentStatus.Keys) {
    $path = [string]$pathObject
    $status = [string]$OptionalPresentStatus[$pathObject]
    Assert-RepoPath $path
    if (-not $path.EndsWith('.uid') -or $status -cne 'A' -or $expected.Contains($path)) { throw ('Invalid optional UID contract: ' + $path) }
    $tracked = Test-Tracked $path
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        if ($tracked) { throw ('Optional A UID is already tracked: ' + $path) }
        $expected[$path] = 'A'
    } elseif ($tracked) {
        throw ('Optional UID is tracked but absent: ' + $path)
    }
}

foreach ($path in $AllowedDirtyPaths) {
    Assert-RepoPath $path
    if ($expected.Contains($path)) { throw ('Allowed-dirty path overlaps commit set: ' + $path) }
}

$whitespaceExempt = [ordered]@{}
foreach ($path in $WhitespaceExemptPaths) {
    Assert-RepoPath $path
    if ($whitespaceExempt.Contains($path)) { throw ('Duplicate whitespace-exempt path: ' + $path) }
    if (-not $expected.Contains($path)) { throw ('Whitespace-exempt path is not in the commit set: ' + $path) }
    if ($path -cnotmatch '^evidence/phase_2r/(logs|closeout/logs)/[^/]+\.log$') {
        throw ('Whitespace exemption is restricted to immutable Phase 2R logs: ' + $path)
    }
    $whitespaceExempt[$path] = $true
}

foreach ($path in $RequiredStatus.Keys) {
    $addResult = Invoke-GitSafe @('add','-A','--',([string]$path))
    if ($addResult.ExitCode -ne 0) { throw ('Failed to stage required path: ' + $path) }
}
foreach ($path in $OptionalPresentStatus.Keys) {
    if ($expected.Contains([string]$path)) {
        $addResult = Invoke-GitSafe @('add','--',([string]$path))
        if ($addResult.ExitCode -ne 0) { throw ('Failed to stage optional UID: ' + $path) }
    }
}

$nonemptyCode = Invoke-GitQuiet @('diff','--cached','--quiet') 'Staged index inspection'
if ($nonemptyCode -eq 0) { throw 'Refusing an empty commit.' }
$stagedResult = Invoke-GitSafe @('-c','core.quotepath=false','diff','--cached','--name-status','--no-renames')
if ($stagedResult.ExitCode -ne 0) { throw 'Unable to inspect staged statuses.' }
$stagedLines = @($stagedResult.Stdout)
$stagedMap = ConvertTo-StatusMap $stagedLines 'Staged index'
Assert-ExactMap $stagedMap $expected 'Staged index'
$stagedRawResult = Invoke-GitSafe @('-c','core.quotepath=false','diff','--cached','--raw','--no-abbrev','--no-renames')
if ($stagedRawResult.ExitCode -ne 0) { throw 'Unable to inspect staged raw modes.' }
$stagedRawLines = @($stagedRawResult.Stdout)
$stagedRawMap = ConvertTo-RawModeMap $stagedRawLines 'Staged index'
Assert-ExactRawModes $stagedRawMap $expected 'Staged index'
$expectedPaths = @($expected.Keys)
$partialResult = Invoke-GitSafe (@('diff','--name-only','--') + $expectedPaths)
if ($partialResult.ExitCode -ne 0) { throw 'Unable to inspect partial staging.' }
$partiallyStaged = @($partialResult.Stdout)
if (@($partiallyStaged | Where-Object { $_ }).Count -ne 0) { throw 'Required path has unstaged/partial content.' }
$checkPaths = @($expected.Keys | Where-Object { -not $whitespaceExempt.Contains([string]$_) })
if ($checkPaths.Count -gt 0) {
    $checkResult = Invoke-GitSafe (@('diff','--cached','--check','--') + $checkPaths)
    if ($checkResult.ExitCode -ne 0) { throw 'Staged diff check failed.' }
}

if ($RequireRemainingDirtyExact) {
    $dirtyResult = Invoke-GitSafe @('diff','--name-only')
    $untrackedResult = Invoke-GitSafe @('ls-files','--others','--exclude-standard')
    if ($dirtyResult.ExitCode -ne 0 -or $untrackedResult.ExitCode -ne 0) { throw 'Unable to inspect remaining worktree paths.' }
    $remaining = @(@($dirtyResult.Stdout) + @($untrackedResult.Stdout) | Where-Object { $_ } | Sort-Object -Unique)
    $allowed = @($AllowedDirtyPaths | Sort-Object -Unique)
    if ([string]::Join("`n", $remaining) -cne [string]::Join("`n", $allowed)) {
        throw 'Remaining worktree paths differ from the exact allowed-dirty set.'
    }
}

$commitResult = Invoke-GitSafe @('commit','-m',$Message)
if ($commitResult.ExitCode -ne 0) { throw 'git commit failed.' }
$headResult = Invoke-GitSafe @('rev-parse','--verify','HEAD^{commit}')
$head = [string]::Join('', @($headResult.Stdout)).Trim()
if ($headResult.ExitCode -ne 0) { throw 'Unable to resolve committed HEAD.' }
$parentResult = Invoke-GitSafe @('rev-list','--parents','-n','1',$head)
$parentLine = [string]::Join(' ', @($parentResult.Stdout)).Trim() -split ' '
if ($parentResult.ExitCode -ne 0 -or $parentLine.Count -ne 2 -or $parentLine[1] -cne $parent) {
    throw 'Committed boundary is not the sole direct child of the expected parent.'
}
$committedResult = Invoke-GitSafe @('-c','core.quotepath=false','diff-tree','--no-commit-id','-r','--name-status','--no-renames',$head)
if ($committedResult.ExitCode -ne 0) { throw 'Unable to inspect committed statuses.' }
$committedLines = @($committedResult.Stdout)
$committedMap = ConvertTo-StatusMap $committedLines 'Committed boundary'
Assert-ExactMap $committedMap $expected 'Committed boundary'
$committedRawResult = Invoke-GitSafe @('-c','core.quotepath=false','diff-tree','--no-commit-id','-r','--raw','--no-abbrev','--no-renames',$head)
if ($committedRawResult.ExitCode -ne 0) { throw 'Unable to inspect committed raw modes.' }
$committedRawLines = @($committedRawResult.Stdout)
$committedRawMap = ConvertTo-RawModeMap $committedRawLines 'Committed boundary'
Assert-ExactRawModes $committedRawMap $expected 'Committed boundary'
Write-Output ('EXACT_PATH_COMMIT: PASS ' + $head)
