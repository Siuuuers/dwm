#requires -Version 7.2
# Diagnostic only. Launch normally, attach after fixture setup, then release refusal.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Start-CapturedProcess([string]$Executable, [string[]]$Arguments, [hashtable]$Environment, [string]$Prefix) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Executable
    $info.WorkingDirectory = $projectRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($arg in $Arguments) { $info.ArgumentList.Add($arg) }
    foreach ($name in $Environment.Keys) { $info.Environment[$name] = [string]$Environment[$name] }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (-not $process.Start()) { throw "START_FAILED: $Executable" }
    return @{ process = $process; stdout = $process.StandardOutput.ReadToEndAsync(); stderr = $process.StandardError.ReadToEndAsync(); prefix = $Prefix }
}
function Close-CapturedProcess($Capture) {
    if ($null -eq $Capture) { return }
    $process = $Capture.process
    try {
        if (-not $process.HasExited) { $process.Kill($true); [void]$process.WaitForExit(10000) }
        [void][Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($Capture.stdout, $Capture.stderr), 10000)
        foreach ($stream in @('stdout', 'stderr')) {
            $task = $Capture[$stream]
            $text = if ($task.IsCompletedSuccessfully) { $task.GetAwaiter().GetResult() } else { 'Output drain incomplete.' }
            [IO.File]::WriteAllText(($Capture.prefix + '.' + $stream + '.log'), $text, [Text.UTF8Encoding]::new($false))
        }
    } finally { $process.Dispose() }
}
function Read-LiveDebuggerLog([string]$Path) {
    $stream = $null
    $reader = $null
    try {
        $stream = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        $reader = [IO.StreamReader]::new($stream)
        return $reader.ReadToEnd()
    } catch [IO.IOException] {
        # Creation and writer flush races are retried under the outer deadline.
        return ''
    } finally {
        if ($null -ne $reader) { $reader.Dispose() }
        elseif ($null -ne $stream) { $stream.Dispose() }
    }
}
$projectRoot = [IO.Path]::GetFullPath((Get-Location).ProviderPath)
if (-not $IsWindows -or -not (Test-Path (Join-Path $projectRoot 'project.godot'))) { throw 'Requires cloud Windows candidate root.' }
$consolePath = (Resolve-Path -LiteralPath $env:GODOT_CONSOLE_PATH).ProviderPath
$enginePath = if ([string]::IsNullOrWhiteSpace($env:GODOT_ENGINE_PATH)) {
    Join-Path ([IO.Path]::GetDirectoryName($consolePath)) 'Godot_v4.6.3-stable_win64.exe'
} else { (Resolve-Path -LiteralPath $env:GODOT_ENGINE_PATH).ProviderPath }
$cdbPath = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/Debuggers/x64/cdb.exe'
foreach ($path in @($enginePath, $cdbPath, (Join-Path $projectRoot 'tests/diagnostics/style_refusal_shutdown_probe.gd'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing dependency: $path" }
}
$nonce = [Guid]::NewGuid().ToString('N')
$testRoot = Join-Path $projectRoot ".godot/phase2r_tests/attach-$nonce"
$outputRoot = Join-Path $projectRoot '.godot/ci/native-attach'
$dumpRoot = Join-Path $projectRoot '.godot/native-crashes'
foreach ($path in @($testRoot, $outputRoot, $dumpRoot)) { [void][IO.Directory]::CreateDirectory($path) }
$environment = @{ DWM_TEST_ROOT = $testRoot; DWM_NATIVE_ATTACH_NONCE = $nonce; APPDATA = (Join-Path $testRoot 'roaming'); LOCALAPPDATA = (Join-Path $testRoot 'local') }
foreach ($name in @('APPDATA', 'LOCALAPPDATA')) { [void][IO.Directory]::CreateDirectory($environment[$name]) }
$readyPath = Join-Path $testRoot 'attach-ready.json'
$continuePath = Join-Path $testRoot 'attach-continue.json'
$dumpRelative = ".godot/native-crashes/attach-$nonce.dmp"
$dumpPath = Join-Path $projectRoot $dumpRelative
$debuggerLog = Join-Path $outputRoot "cdb-$nonce.log"
$commandPath = Join-Path $outputRoot "commands-$nonce.txt"
$marker = "DWM_ATTACH_FILTERS_READY_$nonce"
$capture = '.exr -1; r; kv 50; lmv m godot*; .dump /m ' + $dumpRelative + '; q'
$commands = @(
    ('sxe -c ".echo DWM_ATTACH_AV; ' + $capture + '" av'),
    ('sxe -c ".echo DWM_ATTACH_HEAP; ' + $capture + '" 0xc0000374'),
    ('sxe -c ".echo DWM_ATTACH_BREAKPOINT; ' + $capture + '" bpe'),
    'sxi ibp', ('.echo ' + $marker), 'g'
)
[IO.File]::WriteAllLines($commandPath, $commands, [Text.UTF8Encoding]::new($false))
$receipt = [ordered]@{ diagnostic_only = $true; nonce = $nonce; mode = 'explicit'; started_utc = [DateTime]::UtcNow.ToString('o'); test_root = $testRoot
    engine = @{ path = $enginePath; sha256 = (Get-FileHash $enginePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    acceptance = 'Not evaluated: debugger controls termination.'; failure = $null; released = $false; native_exit_code = $null; debugger_exit_code = $null }
$launcher = $null; $debugger = $null; $target = $null; $targetStart = $null; $failed = $false
try {
    if ((Test-Path $readyPath) -or (Test-Path $continuePath) -or (Test-Path $dumpPath)) { throw 'STALE_HANDSHAKE_OR_DUMP' }
    $launchTime = [DateTime]::UtcNow
    $arguments = @('--headless', '--path', $projectRoot, '--log-file', (Join-Path $outputRoot 'godot.log'), '-s', 'res://tests/diagnostics/style_refusal_shutdown_probe.gd')
    $launcher = Start-CapturedProcess $consolePath $arguments $environment (Join-Path $outputRoot 'target')
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    while (-not (Test-Path -LiteralPath $readyPath)) {
        if ($launcher.process.HasExited) { throw 'TARGET_EXITED_BEFORE_READY' }
        if ([DateTime]::UtcNow -ge $deadline) { throw 'ATTACH_READY_TIMEOUT' }
        Start-Sleep -Milliseconds 100
    }
    $ready = [IO.File]::ReadAllText($readyPath) | ConvertFrom-Json
    if ($ready.nonce -ne $nonce -or $ready.mode -ne 'explicit' -or [long]$ready.pid -le 0) { throw 'INVALID_ATTACH_READY' }
    $target = [Diagnostics.Process]::GetProcessById([int]$ready.pid)
    $targetStart = $target.StartTime.ToUniversalTime()
    if ($target.HasExited -or $target.MainModule.FileName -ine $enginePath -or $targetStart -lt $launchTime.AddSeconds(-1)) { throw 'TARGET_IDENTITY_MISMATCH' }
    $receipt['target_pid'] = $target.Id
    $receipt['target_started_utc'] = $targetStart.ToString('o')
    $debuggerArguments = @('-p', [string]$target.Id, '-cf', $commandPath, '-logo', $debuggerLog, '-G', '-sins', '-y', ([IO.Path]::GetDirectoryName($enginePath)))
    $debugger = Start-CapturedProcess $cdbPath $debuggerArguments @{} (Join-Path $outputRoot 'debugger')
    while ($true) {
        if ($target.HasExited -or $debugger.process.HasExited) { throw 'PROCESS_EXITED_BEFORE_FILTERS_READY' }
        $log = Read-LiveDebuggerLog $debuggerLog
        if ($log -match ('(?m)^' + [regex]::Escape($marker) + '\s*$')) { break }
        if ([DateTime]::UtcNow -ge $deadline) { throw 'ATTACH_FILTERS_TIMEOUT' }
        Start-Sleep -Milliseconds 100
    }
    $temporary = $continuePath + '.tmp'
    [IO.File]::WriteAllText($temporary, (@{ nonce = $nonce } | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temporary, $continuePath)
    $receipt.released = $true
    while (-not $target.HasExited -or -not $debugger.process.HasExited) {
        if ([DateTime]::UtcNow -ge $deadline) { throw 'ATTACHED_TARGET_TIMEOUT' }
        Start-Sleep -Milliseconds 100
    }
    $receipt.native_exit_code = $target.ExitCode
    $receipt.debugger_exit_code = $debugger.process.ExitCode
    if (-not (Test-Path -LiteralPath $dumpPath)) { throw 'ATTACH_NO_DUMP_CAUSE_UNDETERMINED' }
} catch { $failed = $true; $receipt.failure = $_.Exception.Message }
finally {
    try {
        if ($null -ne $target -and -not $target.HasExited -and $null -ne $targetStart -and $target.StartTime.ToUniversalTime() -eq $targetStart -and $target.MainModule.FileName -ieq $enginePath) {
            $target.Kill($true); [void]$target.WaitForExit(10000)
        }
    } catch { $failed = $true; $receipt['target_cleanup_failure'] = $_.Exception.Message }
    foreach ($item in @($debugger, $launcher)) {
        try { Close-CapturedProcess $item } catch { $failed = $true; $receipt['process_cleanup_failure'] = $_.Exception.Message }
    }
    if ($null -ne $target) { $target.Dispose() }
    $receipt['dump'] = if (Test-Path -LiteralPath $dumpPath) { @{ path = $dumpPath; bytes = (Get-Item $dumpPath).Length; sha256 = (Get-FileHash $dumpPath -Algorithm SHA256).Hash.ToLowerInvariant() } } else { $null }
    $receipt['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    $receipt['collection_failed'] = $failed
    [IO.File]::WriteAllText((Join-Path $projectRoot '.godot/ci/native-attach.json'), ($receipt | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    Write-Host "DWM_ATTACH_CAPTURE collection_failed=$failed test_acceptance=not_evaluated"
}
if ($failed) { exit 1 }
exit 0
