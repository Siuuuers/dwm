#requires -Version 7.2
# Diagnostic only: WER captures the ordinary process crash; CDB reads the dump offline.
# https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps
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
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot'))) { throw 'Run from the candidate project root.' }
if (-not $IsWindows -or [string]::IsNullOrWhiteSpace($env:GODOT_CONSOLE_PATH) -or [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
    throw 'Requires the isolated Windows cloud installation.'
}
$consolePath = (Resolve-Path -LiteralPath $env:GODOT_CONSOLE_PATH).ProviderPath
$imageName = 'Godot_v4.6.3-stable_win64.exe'
$enginePath = Join-Path ([IO.Path]::GetDirectoryName($consolePath)) $imageName
$cdbPath = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/Debuggers/x64/cdb.exe'
$testPath = Join-Path $projectRoot 'tests/integration/test_scene_caption_style_refusal.gd'
foreach ($path in @($enginePath, $cdbPath, $testPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing dependency: $path" }
}
$outputRoot = Join-Path $projectRoot '.godot/ci/native-wer'
$dumpRoot = Join-Path $projectRoot ('.godot/native-crashes/wer-' + [Guid]::NewGuid().ToString('N'))
# Match Invoke-IsolatedGodot's proven test-root convention: Bootstrap uses it
# to select test_manual before autoload consumers freeze registration.
$isolationRoot = Join-Path $projectRoot ('.godot/phase2r_tests/wer-' + [Guid]::NewGuid().ToString('N'))
$isolation = @{ APPDATA = (Join-Path $isolationRoot 'roaming'); LOCALAPPDATA = (Join-Path $isolationRoot 'local'); DWM_TEST_ROOT = (Join-Path $isolationRoot 'tests') }
foreach ($directory in @($outputRoot, $dumpRoot) + @($isolation.Values)) { [void][IO.Directory]::CreateDirectory($directory) }
$receiptPath = Join-Path $projectRoot '.godot/ci/native-wer.json'
$registryPath = 'SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\' + $imageName
$base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
$key = $null
$existed = $false
$snapshot = @{}
$modified = $false
$failed = $false
$receipt = [ordered]@{
    schema_version = 1; diagnostic_only = $true; mode = 'wer'; started_utc = [DateTime]::UtcNow.ToString('o')
    engine = @{ path = $enginePath; sha256 = (Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    console_launcher = @{ path = $consolePath; sha256 = (Get-FileHash -LiteralPath $consolePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    debugger = @{ path = $cdbPath; sha256 = (Get-FileHash -LiteralPath $cdbPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    test = @{ path = $testPath; sha256 = (Get-FileHash -LiteralPath $testPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    isolation = $isolation; registry_path = $registryPath; registry_restored = $false
    limits = @{ process_seconds = 90; offline_debugger_seconds = 90; dump_wait_seconds = 10; output_drain_seconds = 10 }
    acceptance = 'Not evaluated: diagnostic capture is not a normal test acceptance gate.'
    native_result = $null; dumps = @(); failure = $null
}
try {
    $key = $base.OpenSubKey($registryPath, $true)
    $existed = $null -ne $key
    if ($existed) {
        foreach ($name in @('DumpFolder', 'DumpType', 'DumpCount')) {
            if ($key.GetValueNames() -contains $name) {
                $snapshot[$name] = @{ value = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames); kind = $key.GetValueKind($name) }
            }
        }
    } else { $key = $base.CreateSubKey($registryPath, $true) }
    $receipt['registry_preexisted'] = $existed
    $modified = $true
    $key.SetValue('DumpFolder', $dumpRoot, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    $key.SetValue('DumpType', 1, [Microsoft.Win32.RegistryValueKind]::DWord)
    $key.SetValue('DumpCount', 2, [Microsoft.Win32.RegistryValueKind]::DWord)
    $key.Flush()
    $arguments = @('--headless', '--path', $projectRoot, '--log-file', (Join-Path $outputRoot 'godot.log'),
        '-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=', '-gtest=res://tests/integration/test_scene_caption_style_refusal.gd',
        '-gexit', '-glog=2', '-gjunit_xml_file=res://.godot/ci/native-wer/gut.xml')
    $receipt['arguments'] = $arguments
    $call = @{ Executable = $consolePath; Arguments = $arguments; WorkingDirectory = $projectRoot; Environment = $isolation; TimeoutSeconds = 90
        StdoutPath = (Join-Path $outputRoot 'stdout.log'); StderrPath = (Join-Path $outputRoot 'stderr.log') }
    $receipt.native_result = Invoke-BoundedNative @call
    if ($receipt.native_result.timed_out) { throw 'WER_TARGET_TIMEOUT_CHILD_TREE_TERMINATED' }
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        $dumps = @(Get-ChildItem -LiteralPath $dumpRoot -Filter '*.dmp' -File)
        if ($dumps.Count -gt 0) { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($dumps.Count -eq 0) { throw 'WER_NO_DUMP_CAPTURED_CAUSE_UNDETERMINED' }
    $index = 0
    foreach ($dump in $dumps) {
        $index++
        $commands = Join-Path $outputRoot "offline-$index.txt"
        [IO.File]::WriteAllLines($commands, @('.echo DWM_WER_OFFLINE_ANALYSIS', '.exr -1', '.ecxr', 'r', 'kv 50', 'lm', 'q'), [Text.UTF8Encoding]::new($false))
        $analysis = @{ Executable = $cdbPath; Arguments = @('-z', $dump.FullName, '-cf', $commands, '-logo', (Join-Path $outputRoot "cdb-$index.log"), '-sins', '-y', ([IO.Path]::GetDirectoryName($enginePath)))
            WorkingDirectory = $projectRoot; Environment = @{}; TimeoutSeconds = 90
            StdoutPath = (Join-Path $outputRoot "cdb-$index.stdout.log"); StderrPath = (Join-Path $outputRoot "cdb-$index.stderr.log") }
        $result = Invoke-BoundedNative @analysis
        $receipt.dumps += @{ path = $dump.FullName; bytes = $dump.Length; sha256 = (Get-FileHash -LiteralPath $dump.FullName -Algorithm SHA256).Hash.ToLowerInvariant(); offline_result = $result }
        if ($result.timed_out -or $result.exit_code -ne 0) { throw 'WER_OFFLINE_ANALYSIS_FAILED' }
    }
} catch {
    $failed = $true
    $receipt.failure = $_.Exception.Message
} finally {
    try {
        if ($modified) {
            foreach ($name in @('DumpFolder', 'DumpType', 'DumpCount')) {
                if ($snapshot.ContainsKey($name)) { $key.SetValue($name, $snapshot[$name].value, $snapshot[$name].kind) }
                else { $key.DeleteValue($name, $false) }
            }
            $key.Flush()
            $removeCreated = -not $existed -and $key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0
            $key.Dispose(); $key = $null
            if ($removeCreated) { $base.DeleteSubKey($registryPath, $false) }
        }
        $receipt.registry_restored = $true
    } catch { $failed = $true; $receipt['cleanup_failure'] = $_.Exception.Message }
    if ($null -ne $key) { $key.Dispose() }
    $base.Dispose()
    $receipt['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    $receipt['junit_exists'] = Test-Path -LiteralPath (Join-Path $outputRoot 'gut.xml')
    $receipt['collection_failed'] = $failed
    [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
    Write-Host "DWM_WER_CAPTURE receipt=$receiptPath collection_failed=$failed test_acceptance=not_evaluated"
}
if ($failed) { exit 1 }
exit 0
