param(
    [Parameter(Mandatory = $true)]
    [string]$SuiteId,

    [Parameter(Mandatory = $true)]
    [string]$LogName,

    [Parameter(Mandatory = $true)]
    [string[]]$GodotArgs,

    [string]$EvidenceLogPath,

    # Existing long-running evidence callers retain their own watchdogs unless
    # they opt in. Cloud focused suites set a limit below their step timeout.
    [ValidateRange(0, 86400)]
    [int]$TimeoutSeconds = 0,

    [switch]$KeepRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Test-StrictDescendant {
    param([string]$Root, [string]$Candidate)
    $rootFull = Get-CanonicalPath $Root
    $candidateFull = Get-CanonicalPath $Candidate
    return $candidateFull.StartsWith(
        $rootFull + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )
}

function Assert-ContainedNonReparseChain {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Candidate,
        [switch]$RequireStrictDescendant
    )
    $rootFull = Get-CanonicalPath $Root
    $candidateFull = Get-CanonicalPath $Candidate
    $inside = $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or
        (Test-StrictDescendant -Root $rootFull -Candidate $candidateFull)
    if (-not $inside -or ($RequireStrictDescendant -and $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase))) {
        throw "PATH_CONTAINMENT: '$candidateFull' is outside '$rootFull'."
    }
    $relative = $candidateFull.Substring($rootFull.Length).TrimStart('\','/')
    $cursor = $rootFull
    $parts = if ($relative.Length -eq 0) { @() } else { @($relative -split '[\\/]') }
    foreach ($part in @('') + $parts) {
        if ($part.Length -ne 0) { $cursor = Join-Path $cursor $part }
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -Force -LiteralPath $cursor
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "PATH_REPARSE_POINT: '$cursor'."
            }
        }
    }
    return $candidateFull
}

function New-VerifiedDirectory {
    param([string]$RepositoryRoot, [string]$Path)
    [void](Assert-ContainedNonReparseChain -Root $RepositoryRoot -Candidate $Path)
    [void][IO.Directory]::CreateDirectory((Get-CanonicalPath $Path))
    [void](Assert-ContainedNonReparseChain -Root $RepositoryRoot -Candidate $Path)
}

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes += 1; continue }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($slashes * 2) + 1)) + '"')
            $slashes = 0
            continue
        }
        if ($slashes -ne 0) { [void]$builder.Append('\' * $slashes); $slashes = 0 }
        [void]$builder.Append($character)
    }
    if ($slashes -ne 0) { [void]$builder.Append('\' * ($slashes * 2)) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-GodotChild {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$AppData,
        [string]$LocalAppData,
        [string]$DwmTestRoot,
        [int]$TimeoutSeconds,
        [string]$TimeoutLogPath
    )
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Executable
    $start.Arguments = [string]::Join(' ', @($Arguments | ForEach-Object { ConvertTo-NativeArgument ([string]$_) }))
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.EnvironmentVariables['APPDATA'] = $AppData
    $start.EnvironmentVariables['LOCALAPPDATA'] = $LocalAppData
    $start.EnvironmentVariables['DWM_TEST_ROOT'] = $DwmTestRoot
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw 'GODOT_START_FAILED' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $waitMilliseconds = if ($TimeoutSeconds -eq 0) { -1 } else { $TimeoutSeconds * 1000 }
        $timedOut = -not $process.WaitForExit($waitMilliseconds)
        if ($timedOut) {
            [Console]::Error.WriteLine("GODOT_CHILD_TIMEOUT: exceeded $TimeoutSeconds seconds; terminating child process tree $($process.Id).")
            $process.Kill($true)
            if (-not $process.WaitForExit(10000)) { throw 'GODOT_CHILD_TERMINATION_TIMEOUT' }
        }
        # Descendants can inherit pipe handles. Do not let draining their output
        # replace the bounded child wait with another unbounded wait.
        if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdoutTask, $stderrTask), 10000)) {
            throw 'GODOT_CHILD_OUTPUT_DRAIN_TIMEOUT'
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($timedOut) {
            $diagnostic = "GODOT_CHILD_TIMEOUT: exceeded $TimeoutSeconds seconds.`n$stdout`n$stderr"
            [IO.File]::WriteAllText($TimeoutLogPath, $diagnostic, (New-Object Text.UTF8Encoding($false)))
            [Console]::Error.WriteLine("GODOT_TIMEOUT_OUTPUT: $TimeoutLogPath")
        }
        $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
        return [pscustomobject]@{ ExitCode = $exitCode; Stdout = $stdout; Stderr = $stderr }
    } finally {
        $process.Dispose()
    }
}

function Assert-TreeHasNoReparsePoints {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { return }
    foreach ($item in @(Get-Item -Force -LiteralPath $Root) + @(Get-ChildItem -Force -Recurse -LiteralPath $Root)) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "CLEANUP_REPARSE_POINT: '$($item.FullName)'."
        }
    }
}

function Add-JsonLineExclusive {
    param([string]$Path, [string]$JsonLine)
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($JsonLine + "`n")
    for ($attempt = 1; $attempt -le 50; $attempt += 1) {
        $stream = $null
        try {
            $stream = New-Object IO.FileStream($Path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            [void]$stream.Seek(0, [IO.SeekOrigin]::End)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush($true)
            return
        } catch [IO.IOException] {
            if ($attempt -eq 50) { throw 'EVIDENCE_LOCK_TIMEOUT' }
            Start-Sleep -Milliseconds 100
        } finally {
            if ($null -ne $stream) { $stream.Dispose() }
        }
    }
}

function Get-RequestedSuitePath {
    param([string[]]$Arguments)
    $paths = @()
    foreach ($argument in $Arguments) {
        $text = [string]$argument
        if ($text -notmatch '^(?i)-gtest=') { continue }
        foreach ($entry in ($text.Substring('-gtest='.Length) -split ',')) {
            $trimmed = $entry.Trim()
            if ($trimmed.Length -ne 0) { $paths += $trimmed }
        }
    }
    return @($paths | Sort-Object -Unique)
}

function Get-SuiteExecutionFailure {
    param([string]$LogPath, [string[]]$RequestedPaths)
    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) { return @('SUITE_LOG_MISSING') }
    $lines = @(Get-Content -LiteralPath $LogPath)
    $failures = @()
    foreach ($path in $RequestedPaths) {
        if (@($lines | Where-Object { $_.Trim() -ceq $path }).Count -eq 0) {
            $failures += ('SUITE_NOT_EXECUTED: ' + $path)
        }
    }
    foreach ($line in $lines) {
        if ($line.Contains('ERROR: Failed to load script')) { $failures += ('SCRIPT_LOAD_FAILED: ' + $line.Trim()) }
    }
    return @($failures | Sort-Object -Unique)
}

$repositoryRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$projectPath = Join-Path $repositoryRoot 'project.godot'
$phaseTestsRoot = Join-Path $repositoryRoot '.godot\phase2r_tests'
$guidRoot = Join-Path $phaseTestsRoot ([guid]::NewGuid().ToString('D').ToLowerInvariant())
$recordJson = $null
$resultCode = 124
$phase = 'isolation'

try {
    if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) { throw 'PROJECT_ROOT_INVALID' }
    if ([string]::IsNullOrWhiteSpace($SuiteId)) { throw 'SUITE_ID_EMPTY' }
    if ([string]::IsNullOrWhiteSpace($LogName) -or [IO.Path]::GetFileName($LogName) -cne $LogName) { throw 'LOG_NAME_INVALID' }
    foreach ($argument in $GodotArgs) {
        if ([string]$argument -match '^(?i)--(?:path|headless|log-file)(?:=|$)') { throw "FORBIDDEN_GODOT_ARG: $argument" }
    }
    if ([string]::IsNullOrWhiteSpace($env:APPDATA)) { throw 'PARENT_APPDATA_MISSING' }
    $productionUserDir = Get-CanonicalPath (Join-Path $env:APPDATA 'Godot\app_userdata\dwm')
    $godotExecutable = if ([string]::IsNullOrWhiteSpace($env:GODOT_CONSOLE_PATH)) {
        'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe'
    } else { [string]$env:GODOT_CONSOLE_PATH }
    $godotExecutable = Get-CanonicalPath $godotExecutable
    if (-not (Test-Path -LiteralPath $godotExecutable -PathType Leaf)) { throw "GODOT_CONSOLE_MISSING: $godotExecutable" }

    [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $repositoryRoot)
    $dotGodot = Join-Path $repositoryRoot '.godot'
    $logsRoot = Join-Path $dotGodot 'phase2r_logs'
    foreach ($directory in @($dotGodot, $logsRoot, $phaseTestsRoot, $guidRoot)) {
        New-VerifiedDirectory -RepositoryRoot $repositoryRoot -Path $directory
    }
    $childAppData = Join-Path $guidRoot 'appdata'
    $childLocalAppData = Join-Path $guidRoot 'localappdata'
    $childDwmRoot = Join-Path $guidRoot 'dwm_test_root'
    foreach ($directory in @($childAppData, $childLocalAppData, $childDwmRoot)) {
        New-VerifiedDirectory -RepositoryRoot $repositoryRoot -Path $directory
    }

    $evidenceFull = $null
    if (-not [string]::IsNullOrWhiteSpace($EvidenceLogPath)) {
        $evidenceFull = Get-CanonicalPath $(if ([IO.Path]::IsPathRooted($EvidenceLogPath)) { $EvidenceLogPath } else { Join-Path $repositoryRoot $EvidenceLogPath })
        [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $evidenceFull -RequireStrictDescendant)
        $parent = Split-Path -Parent $evidenceFull
        # The only roots whose missing parents this runner may create on demand:
        # evidence/phase_2r/logs is the Plan-01/02 evidence log root, evidence/phase_2r/closeout/logs
        # is the Plan-04 Task-3 closeout runner's log root, and .godot holds throwaway run output.
        # Every other missing parent stays refused, so this is a narrowing of one allowlist rather
        # than a relaxation of containment: the strict-descendant, non-reparse, filename,
        # exclusive-append and production-user-data guards around it are untouched.
        $creationRoots = @(
            (Join-Path $repositoryRoot 'evidence\phase_2r\logs'),
            (Join-Path $repositoryRoot 'evidence\phase_2r\closeout\logs'),
            $dotGodot
        )
        $creationAllowed = $false
        foreach ($creationRoot in $creationRoots) {
            $creationFull = Get-CanonicalPath $creationRoot
            if ($parent.Equals($creationFull, [StringComparison]::OrdinalIgnoreCase) -or
                (Test-StrictDescendant -Root $creationFull -Candidate $parent)) {
                $creationAllowed = $true
                break
            }
        }
        if (-not (Test-Path -LiteralPath $parent)) {
            if (-not $creationAllowed) { throw 'EVIDENCE_PARENT_MISSING_OUTSIDE_ALLOWED_ROOT' }
            New-VerifiedDirectory -RepositoryRoot $repositoryRoot -Path $parent
        }
        [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $parent -RequireStrictDescendant)
    }

    $logPath = Get-CanonicalPath (Join-Path $logsRoot $LogName)
    $timeoutLog = $logPath + '.timeout.log'
    [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $timeoutLog -RequireStrictDescendant)
    $proofLog = Join-Path $guidRoot 'user-dir-proof.log'
    $proofArgs = @('--headless','--path',$repositoryRoot,'--log-file',$proofLog,'-s','res://tools/evidence/print_user_dir.gd')
    $proof = Invoke-GodotChild -Executable $godotExecutable -Arguments $proofArgs -AppData $childAppData -LocalAppData $childLocalAppData -DwmTestRoot $childDwmRoot -TimeoutSeconds 60 -TimeoutLogPath $timeoutLog
    if ($proof.ExitCode -ne 0) { throw "USER_DIR_PROOF_EXIT: $($proof.ExitCode) $($proof.Stderr)" }
    $markers = @($proof.Stdout -split "`r?`n" | Where-Object { $_.StartsWith('PHASE2R_USER_DIR=', [StringComparison]::Ordinal) })
    if ($markers.Count -ne 1) { throw "USER_DIR_MARKER_COUNT: $($markers.Count)" }
    $userDir = Get-CanonicalPath $markers[0].Substring('PHASE2R_USER_DIR='.Length)
    if (-not (Test-StrictDescendant -Root $guidRoot -Candidate $userDir)) { throw 'USER_DIR_OUTSIDE_GUID_ROOT' }
    if ($userDir.Equals($productionUserDir, [StringComparison]::OrdinalIgnoreCase)) { throw 'USER_DIR_EQUALS_PRODUCTION' }
    [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $guidRoot -RequireStrictDescendant)
    [void](Assert-ContainedNonReparseChain -Root $guidRoot -Candidate $userDir -RequireStrictDescendant)

    $argv = @('--headless','--path',$repositoryRoot,'--log-file',$logPath) + @($GodotArgs)
    $startedAt = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    $requested = Invoke-GodotChild -Executable $godotExecutable -Arguments $argv -AppData $childAppData -LocalAppData $childLocalAppData -DwmTestRoot $childDwmRoot -TimeoutSeconds $TimeoutSeconds -TimeoutLogPath $timeoutLog
    $endedAt = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    $resultCode = [int]$requested.ExitCode
    # GUT exits 0 while silently downgrading an unloadable suite to a warning, so a requested
    # suite that never ran, or any failed script load, must fail this runner instead.
    $requestedSuites = @(Get-RequestedSuitePath -Arguments @($GodotArgs))
    if ($requestedSuites.Count -ne 0) {
        $suiteFailures = @(Get-SuiteExecutionFailure -LogPath $logPath -RequestedPaths $requestedSuites)
        if ($suiteFailures.Count -ne 0) {
            foreach ($suiteFailure in $suiteFailures) { [Console]::Error.WriteLine($suiteFailure) }
            if ($resultCode -eq 0) { $resultCode = 126 }
        }
    }
    $phase = 'evidence'
    $record = [ordered]@{
        suite_id = $SuiteId; argv = @($argv); exit_code = $resultCode; log_path = $logPath
        test_root = (Get-CanonicalPath $guidRoot); user_dir = $userDir
        started_at_utc = $startedAt; ended_at_utc = $endedAt
    }
    $recordJson = ConvertTo-Json -InputObject $record -Depth 4 -Compress
    if ($null -ne $evidenceFull) { Add-JsonLineExclusive -Path $evidenceFull -JsonLine $recordJson }
} catch {
    if ($phase -eq 'evidence') { $resultCode = 125 } else { $resultCode = 124 }
    [Console]::Error.WriteLine($_.Exception.Message)
} finally {
    try {
        foreach ($candidate in @($repositoryRoot, (Join-Path $repositoryRoot '.godot'), $phaseTestsRoot, $guidRoot)) {
            if (Test-Path -LiteralPath $candidate) { [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $candidate) }
        }
        if (Test-Path -LiteralPath $guidRoot) {
            $actualParent = Get-CanonicalPath (Split-Path -Parent $guidRoot)
            if (-not $actualParent.Equals((Get-CanonicalPath $phaseTestsRoot), [StringComparison]::OrdinalIgnoreCase)) { throw 'CLEANUP_PARENT_MISMATCH' }
            Assert-TreeHasNoReparsePoints -Root $guidRoot
            if (-not $KeepRoot) {
                Remove-Item -LiteralPath $guidRoot -Recurse -Force
                if (Test-Path -LiteralPath $guidRoot) { throw 'CLEANUP_TARGET_SURVIVED' }
            }
        }
        if (Test-Path -LiteralPath $phaseTestsRoot) {
            [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $phaseTestsRoot -RequireStrictDescendant)
        }
    } catch {
        $resultCode = 125
        [Console]::Error.WriteLine($_.Exception.Message)
    }
}
if ($null -ne $recordJson) { [Console]::Out.WriteLine($recordJson) }
exit $resultCode
