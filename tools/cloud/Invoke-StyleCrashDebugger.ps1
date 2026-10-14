#requires -Version 7.2
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('plain', 'pageheap')]
    [string]$Mode
)

# Diagnostic only. CDB can terminate the target after collecting an exception;
# its exit code is never a substitute for normal engine/test acceptance.
# Syntax: Microsoft Learn cdb-command-line-options, sx--sxd--sxe--sxi--sxn--sxr--sx---set-exceptions-,
# -dump--create-dump-file-, and debugger/gflags-commands.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-BoundedNative {
    param(
        [string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory,
        [hashtable]$Environment, [int]$TimeoutSeconds,
        [string]$StdoutPath, [string]$StderrPath
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Executable
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    foreach ($key in $Environment.Keys) { $start.Environment[$key] = [string]$Environment[$key] }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = $false
    $stdoutTask = $null
    $stderrTask = $null
    try {
        $started = $process.Start()
        if (-not $started) { throw "NATIVE_START_FAILED: $Executable" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            $process.Kill($true)
            if (-not $process.WaitForExit(10000)) { throw 'NATIVE_KILL_TREE_TIMEOUT' }
        }
        $drained = [Threading.Tasks.Task]::WaitAll(
            [Threading.Tasks.Task[]]@($stdoutTask, $stderrTask), 10000)
        if (-not $drained) { throw 'NATIVE_OUTPUT_DRAIN_TIMEOUT' }
        return [ordered]@{ pid = $process.Id; exit_code = $process.ExitCode; timed_out = $timedOut }
    } finally {
        if ($started -and -not $process.HasExited) {
            $process.Kill($true)
            [void]$process.WaitForExit(10000)
        }
        foreach ($stream in @(
            @{ task = $stdoutTask; path = $StdoutPath },
            @{ task = $stderrTask; path = $StderrPath }
        )) {
            if ($null -ne $stream.task -and $stream.task.IsCompletedSuccessfully) {
                [IO.File]::WriteAllText($stream.path, $stream.task.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
            } else {
                [IO.File]::WriteAllText($stream.path, 'Output unavailable or drain incomplete.', [Text.UTF8Encoding]::new($false))
            }
        }
        $process.Dispose()
    }
}

$projectRoot = [IO.Path]::GetFullPath((Get-Location).ProviderPath)
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot'))) {
    throw 'Run this diagnostic from the candidate Godot project root.'
}
if ([string]::IsNullOrWhiteSpace($env:GODOT_CONSOLE_PATH) -or [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
    throw 'GODOT_CONSOLE_PATH and RUNNER_TEMP must identify the cloud installation and scratch root.'
}
$consolePath = (Resolve-Path -LiteralPath $env:GODOT_CONSOLE_PATH).ProviderPath
$imageName = 'Godot_v4.6.3-stable_win64.exe'
$enginePath = Join-Path ([IO.Path]::GetDirectoryName($consolePath)) $imageName
$debuggerRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/Debuggers/x64'
$cdbPath = Join-Path $debuggerRoot 'cdb.exe'
$gflagsPath = Join-Path $debuggerRoot 'gflags.exe'
$testPath = Join-Path $projectRoot 'tests/integration/test_scene_caption_style_refusal.gd'
foreach ($requiredPath in @($enginePath, $cdbPath, $gflagsPath, $testPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) { throw "Missing diagnostic dependency: $requiredPath" }
}
$ciRoot = Join-Path $projectRoot '.godot/ci'
$outputRoot = Join-Path $ciRoot "native-$Mode"
$dumpRoot = Join-Path $projectRoot '.godot/native-crashes'
$isolationRoot = Join-Path $projectRoot ('.godot/phase2r_tests/cdb-' + [Guid]::NewGuid().ToString('N'))
foreach ($directory in @($ciRoot, $outputRoot, $dumpRoot, $isolationRoot)) {
    [void][IO.Directory]::CreateDirectory($directory)
}
$isolation = @{
    APPDATA = (Join-Path $isolationRoot 'roaming')
    LOCALAPPDATA = (Join-Path $isolationRoot 'local')
    DWM_TEST_ROOT = (Join-Path $isolationRoot 'tests')
}
foreach ($directory in $isolation.Values) { [void][IO.Directory]::CreateDirectory($directory) }
$commandPath = Join-Path $outputRoot 'commands.txt'
$debuggerLog = Join-Path $outputRoot 'cdb.log'
$dumpPath = Join-Path $dumpRoot "$Mode.dmp"
$receiptPath = Join-Path $ciRoot "native-$Mode.json"
if (Test-Path -LiteralPath $dumpPath) { throw "Refusing a stale diagnostic dump: $dumpPath" }

# Relative debugger dump paths contain neither spaces nor quotes. The CDB
# working directory is the candidate root. /m deliberately excludes full memory.
$capture = '.exr -1; r; kv 50; lm; .dump /m .godot/native-crashes/' + $Mode + '.dmp; q'
$commands = @(
    '.echo DWM_CDB_INITIAL_SETUP',
    ('sxe -c ".echo DWM_NATIVE_EXCEPTION_AV; ' + $capture + '" av'),
    # hc controls invalid-handle handling status; numeric 0xC0000374 is heap corruption.
    ('sxe -c ".echo DWM_NATIVE_EXCEPTION_HEAP; ' + $capture + '" 0xc0000374'),
    # Installed at the initial debugger prompt, so subsequent verifier int3s are trapped.
    ('sxe -c ".echo DWM_NATIVE_EXCEPTION_BREAKPOINT; ' + $capture + '" bpe'),
    'sxi ibp',
    '.echo DWM_CDB_FILTERS_READY',
    'sx',
    'g'
)
[IO.File]::WriteAllLines($commandPath, $commands, [Text.UTF8Encoding]::new($false))
$godotArguments = @(
    '--headless', '--path', $projectRoot,
    '--log-file', (Join-Path $outputRoot 'godot.log'),
    '-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=',
    '-gtest=res://tests/integration/test_scene_caption_style_refusal.gd',
    '-gexit', '-glog=2', "-gjunit_xml_file=res://.godot/ci/native-$Mode/gut.xml"
)
$debuggerArguments = @('-o', '-cf', $commandPath, '-logo', $debuggerLog, '-G', '-sins',
    '-y', ([IO.Path]::GetDirectoryName($enginePath)), $consolePath) + $godotArguments
$receipt = [ordered]@{
    schema_version = 1
    diagnostic_only = $true
    mode = $Mode
    started_utc = [DateTime]::UtcNow.ToString('o')
    project_root = $projectRoot
    engine = @{ path = $enginePath; sha256 = (Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    console_launcher = @{ path = $consolePath; sha256 = (Get-FileHash -LiteralPath $consolePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    debugger = @{ path = $cdbPath; sha256 = (Get-FileHash -LiteralPath $cdbPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    test = @{ path = $testPath; sha256 = (Get-FileHash -LiteralPath $testPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    arguments = $debuggerArguments
    isolation = $isolation
    symbol_scope = 'Local engine directory and module identities; official Windows Godot PDB unavailable.'
    limits = @{ debugger_seconds = 90; output_drain_seconds = 10; test_watchdog_seconds = 30 }
    acceptance = 'Not evaluated: debugger exit and GUT assertions do not establish clean native termination.'
    pageheap_enable = $null
    pageheap_disable = $null
    debugger_result = $null
    failure = $null
}
$pageheapAttempted = $false
$diagnosticFailed = $false
try {
    if ($Mode -eq 'pageheap') {
        $pageheapAttempted = $true
        $enableCall = @{
            Executable = $gflagsPath; Arguments = @('/p', '/enable', $imageName, '/full')
            WorkingDirectory = $projectRoot; Environment = @{}; TimeoutSeconds = 15
            StdoutPath = (Join-Path $outputRoot 'gflags-enable.stdout.log')
            StderrPath = (Join-Path $outputRoot 'gflags-enable.stderr.log')
        }
        $receipt.pageheap_enable = Invoke-BoundedNative @enableCall
        if ($receipt.pageheap_enable.timed_out -or $receipt.pageheap_enable.exit_code -ne 0) {
            throw 'PAGEHEAP_ENABLE_FAILED'
        }
    }
    $captureCall = @{
        Executable = $cdbPath; Arguments = $debuggerArguments
        WorkingDirectory = $projectRoot; Environment = $isolation; TimeoutSeconds = 90
        StdoutPath = (Join-Path $outputRoot 'stdout.log')
        StderrPath = (Join-Path $outputRoot 'stderr.log')
    }
    $receipt.debugger_result = Invoke-BoundedNative @captureCall
    if ($receipt.debugger_result.timed_out) { throw 'CDB_TIMEOUT_CHILD_TREE_TERMINATED' }
} catch {
    $diagnosticFailed = $true
    $receipt.failure = $_.Exception.Message
} finally {
    if ($pageheapAttempted) {
        try {
            $disableCall = @{
                Executable = $gflagsPath; Arguments = @('/p', '/disable', $imageName)
                WorkingDirectory = $projectRoot; Environment = @{}; TimeoutSeconds = 15
                StdoutPath = (Join-Path $outputRoot 'gflags-disable.stdout.log')
                StderrPath = (Join-Path $outputRoot 'gflags-disable.stderr.log')
            }
            $receipt.pageheap_disable = Invoke-BoundedNative @disableCall
            if ($receipt.pageheap_disable.timed_out -or $receipt.pageheap_disable.exit_code -ne 0) {
                throw 'PAGEHEAP_DISABLE_FAILED'
            }
        } catch {
            $diagnosticFailed = $true
            $receipt['cleanup_failure'] = $_.Exception.Message
        }
    }
    $receipt['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    $receipt['junit_exists'] = Test-Path -LiteralPath (Join-Path $outputRoot 'gut.xml')
    $receipt['dump'] = if (Test-Path -LiteralPath $dumpPath) {
        @{ path = $dumpPath; bytes = (Get-Item -LiteralPath $dumpPath).Length;
            sha256 = (Get-FileHash -LiteralPath $dumpPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    } else { $null }
    $logText = if (Test-Path -LiteralPath $debuggerLog) { [IO.File]::ReadAllText($debuggerLog) } else { '' }
    $receipt['filters_ready'] = $logText -match '(?m)^DWM_CDB_FILTERS_READY\s*$'
    $receipt['traps'] = @([regex]::Matches($logText, '(?m)^DWM_NATIVE_EXCEPTION_(AV|HEAP|BREAKPOINT)\s*$') |
        ForEach-Object { $_.Groups[1].Value })
    if (-not $receipt.filters_ready) { $diagnosticFailed = $true }
    $receipt['collection_failed'] = $diagnosticFailed
    [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
    Write-Host "DWM_NATIVE_DEBUGGER mode=$Mode receipt=$receiptPath collection_failed=$diagnosticFailed test_acceptance=not_evaluated"
}
if ($diagnosticFailed) { exit 1 }
exit 0
