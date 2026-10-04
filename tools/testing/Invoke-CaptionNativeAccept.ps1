[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\', '/')
$identity = [guid]::NewGuid().ToString('N')
$output = Join-Path $repositoryRoot '.godot/ci/caption-native'
$isolated = Join-Path $repositoryRoot ".godot/phase2r_tests/caption-native-$identity"
$log = Join-Path $output 'godot.log'
$scriptArgument = 'res://tests/manual/verify_caption_native_accept.gd'
$utf8 = New-Object Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force -Path $output, $isolated | Out-Null
if (Test-Path -LiteralPath $log) { throw 'NATIVE_CAPTION_OUTPUT_NOT_FRESH' }
if (-not (Test-Path -LiteralPath $env:GODOT_CONSOLE_PATH -PathType Leaf)) { throw 'GODOT_MISSING' }

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$observations = New-Object Collections.Generic.List[object]

function Read-Stage([string]$Stage) {
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    while ($deadline.Elapsed.TotalSeconds -lt 40) {
        if (Test-Path -LiteralPath $log) {
            $lines = @(Get-Content -LiteralPath $log)
            if ($lines | Select-String -Pattern 'SCRIPT ERROR:|CAPTION_RESULT .*"ok":false') {
                throw "CAPTION_RUNTIME_FAILED: $Stage"
            }
            $records = @($lines | Where-Object { $_.StartsWith('CAPTION_READY ') } |
                ForEach-Object { $_.Substring(14) | ConvertFrom-Json } | Where-Object { $_.stage -ceq $Stage })
            if ($records.Count -gt 1) { throw "AMBIGUOUS_STAGE: $Stage" }
            if ($records.Count -eq 1) { return $records[0] }
        }
        if ($child.HasExited) { throw "CAPTION_CHILD_EXITED: $Stage" }
        Start-Sleep -Milliseconds 100
    }
    throw "CAPTION_STAGE_TIMEOUT: $Stage"
}

function Invoke-Caption([object]$Ready) {
    $targetPid = [int]$Ready.pid
    $title = "DWM Native Caption Accept $targetPid"
    if ($Ready.window_title -cne $title -or $targetPid -le 0 -or $Ready.physical_contacts -ne 0 -or
        $Ready.text -cne 'Native caption activation fixture.' -or $Ready.event_index -ne 0 -or
        ($Ready.stage -ceq 'reveal' -and (-not $Ready.revealing -or $Ready.finished -ne 0)) -or
        ($Ready.stage -ceq 'advance' -and ($Ready.revealing -or $Ready.finished -ne 1))) {
        throw 'CAPTION_READY_CONTRACT_INVALID'
    }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $targetPid"
    if ($null -eq $process -or [string]$process.CommandLine -notlike "*$repositoryRoot*" -or
        [string]$process.CommandLine -notlike "*$scriptArgument*") { throw 'CAPTION_PROCESS_MISMATCH' }
    $native = [Diagnostics.Process]::GetProcessById($targetPid)
    $window = $null
    $target = $null
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    while ($deadline.Elapsed.TotalSeconds -lt 10) {
        $native.Refresh()
        if ($native.MainWindowHandle -ne [IntPtr]::Zero -and $native.MainWindowTitle -ceq $title) {
            $window = [Windows.Automation.AutomationElement]::FromHandle($native.MainWindowHandle)
            if ($window.Current.ProcessId -ne $targetPid) { throw 'CAPTION_WINDOW_PROCESS_MISMATCH' }
            $elements = $window.FindAll([Windows.Automation.TreeScope]::Descendants,
                [Windows.Automation.Condition]::TrueCondition)
            $snapshot = @($elements | ForEach-Object {
                [ordered]@{ name = $_.Current.Name; type = $_.Current.ControlType.ProgrammaticName;
                    enabled = $_.Current.IsEnabled; offscreen = $_.Current.IsOffscreen;
                    automation_id = $_.Current.AutomationId;
                    patterns = @($_.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName }) }
            })
            [IO.File]::WriteAllText((Join-Path $output ($Ready.stage + '-tree.json')),
                (ConvertTo-Json -InputObject $snapshot -Depth 8), $utf8)
            # RichTextLabel retains its real role; a Button-only search would be false evidence.
            $matches = @($elements | Where-Object {
                $_.Current.Name.TrimEnd() -ceq $Ready.text -and -not $_.Current.IsOffscreen
            })
            if ($matches.Count -gt 1) { throw 'CAPTION_UIA_AMBIGUOUS' }
            if ($matches.Count -eq 1) { $target = $matches[0]; break }
        }
        Start-Sleep -Milliseconds 100
    }
    if ($null -eq $target) { throw "CAPTION_UIA_NOT_FOUND: $($Ready.stage)" }
    $pattern = $null
    if (-not $target.Current.IsEnabled -or
        -not $target.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw 'CAPTION_INVOKE_PATTERN_MISSING'
    }
    $observation = [ordered]@{ stage = $Ready.stage; pid = $targetPid; window = $window.Current.Name;
        name = $target.Current.Name; type = $target.Current.ControlType.ProgrammaticName;
        runtime_id = @($target.GetRuntimeId()); command_line = $process.CommandLine;
        method = 'Windows.UIAutomation.InvokePattern.Invoke'; invocations = 1; ready = $Ready }
    # No SetFocus or callback substitution. Never retry an invocation on timeout.
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
    $observations.Add($observation)
    [IO.File]::WriteAllText((Join-Path $output 'invocations.json'),
        (ConvertTo-Json -InputObject @($observations.ToArray()) -Depth 10), $utf8)
}

$start = New-Object Diagnostics.ProcessStartInfo
$start.FileName = $env:GODOT_CONSOLE_PATH
$start.Arguments = '--path "' + $repositoryRoot + '" --rendering-method gl_compatibility --accessibility always --log-file "' + $log + '" --script ' + $scriptArgument
$start.UseShellExecute = $false
$start.EnvironmentVariables['APPDATA'] = Join-Path $isolated 'appdata'
$start.EnvironmentVariables['LOCALAPPDATA'] = Join-Path $isolated 'localappdata'
$start.EnvironmentVariables['DWM_TEST_ROOT'] = $isolated
$start.EnvironmentVariables['DWM_CAPTION_EVIDENCE_ROOT'] = $output
New-Item -ItemType Directory -Force -Path $start.EnvironmentVariables['APPDATA'], $start.EnvironmentVariables['LOCALAPPDATA'] | Out-Null
$child = New-Object Diagnostics.Process
$child.StartInfo = $start
$started = $false
try {
    $started = $child.Start()
    if (-not $started) { throw 'CAPTION_START_FAILED' }
    Invoke-Caption (Read-Stage 'reveal')
    Invoke-Caption (Read-Stage 'advance')
    if (-not $child.WaitForExit(15000)) { throw 'CAPTION_EXIT_TIMEOUT' }
    if ($child.ExitCode -ne 0) { throw "CAPTION_EXIT_CODE: $($child.ExitCode)" }
    $result = Get-Content -Raw -LiteralPath (Join-Path $output 'runtime.json') | ConvertFrom-Json
    if (-not $result.ok -or $observations.Count -ne 2 -or $result.event_index -ne 1 -or
        -not $result.revealing -or $result.finished -ne 1 -or $result.physical_contacts -ne 0) {
        throw 'CAPTION_NATIVE_RESULT_INVALID'
    }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load' -Quiet) {
        throw 'CAPTION_NATIVE_SCRIPT_ERROR'
    }
    $source = (& git -C $repositoryRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'CAPTION_SOURCE_UNKNOWN' }
    $receipt = [ordered]@{ ok = $true; checkout = $source; run_id = $env:GITHUB_RUN_ID;
        run_attempt = $env:GITHUB_RUN_ATTEMPT; native_invocations = 2; runtime = $result;
        scope = 'Mounted fixture, native Windows UIA Invoke. No screen-reader navigation or production route claim.' }
    [IO.File]::WriteAllText((Join-Path $output 'receipt.json'), (ConvertTo-Json $receipt -Depth 8), $utf8)
    Write-Output 'CAPTION_NATIVE_ACCEPT_VERIFIED'
} finally {
    if ($started -and -not $child.HasExited) { & taskkill.exe /PID $child.Id /T /F | Out-Null }
    $child.Dispose()
}
