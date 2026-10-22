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
if ((Test-Path -LiteralPath $output) -and @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) {
    throw 'NATIVE_CAPTION_OUTPUT_NOT_FRESH'
}
New-Item -ItemType Directory -Force -Path $output, $isolated | Out-Null
if (-not (Test-Path -LiteralPath $env:GODOT_CONSOLE_PATH -PathType Leaf)) { throw 'GODOT_MISSING' }

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
# Driver-only native transport. INPUT uses its largest union member, MOUSEINPUT.
# This driver is launched in a fresh Windows PowerShell process by the existing CI step.
Add-Type -AssemblyName WindowsBase
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class DwmCaptionNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct Point { public int X; public int Y; }
    [StructLayout(LayoutKind.Sequential)]
    public struct MouseInput {
        public int dx, dy;
        public uint mouseData, dwFlags, time;
        public UIntPtr dwExtraInfo;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct Input { public uint type; public MouseInput mouse; }
    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetPhysicalCursorPos(int x, int y);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetPhysicalCursorPos(out Point point);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPhysicalPoint(Point point);
    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr window, uint flags);
    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("shell32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern IntPtr CommandLineToArgvW(string command, out int count);
    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr memory);
    public static Point Cursor() {
        Point result;
        if (!GetPhysicalCursorPos(out result)) throw new Win32Exception(Marshal.GetLastWin32Error());
        return result;
    }
    public static int[] PressedKeys() {
        var result = new List<int>();
        for (int key = 1; key < 255; key++) if (GetAsyncKeyState(key) < 0) result.Add(key);
        return result.ToArray();
    }
    public static string[] Arguments(string command) {
        int count;
        IntPtr memory = CommandLineToArgvW(command, out count);
        if (memory == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try {
            var result = new string[count];
            for (int i = 0; i < count; i++)
                result[i] = Marshal.PtrToStringUni(Marshal.ReadIntPtr(memory, i * IntPtr.Size));
            return result;
        } finally { LocalFree(memory); }
    }
    public static uint WheelDown(out int error) {
        var input = new Input[1];
        input[0].type = 0; // INPUT_MOUSE; positioning is a separately recorded operation.
        input[0].mouse.dwFlags = 0x0800; // MOUSEEVENTF_WHEEL
        input[0].mouse.mouseData = unchecked((uint)-120);
        uint inserted = SendInput(1, input, Marshal.SizeOf(typeof(Input)));
        error = inserted == 1 ? 0 : Marshal.GetLastWin32Error();
        return inserted;
    }
    public static int InputSize() { return Marshal.SizeOf(typeof(Input)); }
}
'@
$consolePath = [IO.Path]::GetFullPath($env:GODOT_CONSOLE_PATH)
if ($consolePath -notmatch '_console\.exe$') { throw 'CAPTION_PINNED_CONSOLE_NAME_REQUIRED' }
$enginePath = $consolePath -replace '_console\.exe$', '.exe'
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) { throw 'CAPTION_ENGINE_MISSING' }
$boundProcess = $null
$wheelObservation = $null
$partialPrefix = 'The live fourth'
$observations = New-Object Collections.Generic.List[object]
$captions = @('Native caption activation fixture.', 'The successor keeps its own reveal.',
    'Third witnessed caption.', 'The live fourth caption stays partial.', 'Guard caption.')
# Independent expectations for each pre-invocation runtime state.
$steps = @(
    @{ stage = 'reveal'; event_index = 0; revealing = $true; finished = 0; review_offset = 0; target_index = 0 },
    @{ stage = 'advance'; event_index = 0; revealing = $false; finished = 1; review_offset = 0; target_index = 0 },
    @{ stage = 'second-reveal'; event_index = 1; revealing = $true; finished = 1; review_offset = 0; target_index = 1 },
    @{ stage = 'second-advance'; event_index = 1; revealing = $false; finished = 2; review_offset = 0; target_index = 1 },
    @{ stage = 'third-reveal'; event_index = 2; revealing = $true; finished = 2; review_offset = 0; target_index = 2 },
    @{ stage = 'third-advance'; event_index = 2; revealing = $false; finished = 3; review_offset = 0; target_index = 2 },
    @{ stage = 'review-enter'; event_index = 3; revealing = $true; finished = 3; review_offset = 0; target_index = 3 },
    @{ stage = 'review-return'; event_index = 3; revealing = $true; finished = 3; review_offset = 1; target_index = 2 },
    @{ stage = 'fresh-reveal'; event_index = 3; revealing = $true; finished = 3; review_offset = 0; target_index = 3 },
    @{ stage = 'fresh-advance'; event_index = 3; revealing = $false; finished = 4; review_offset = 0; target_index = 3 }
)

function Read-Stage([string]$Stage) {
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    while ($deadline.Elapsed.TotalSeconds -lt 40) {
        if (Test-Path -LiteralPath $log) {
            $lines = @(Get-Content -LiteralPath $log -Encoding UTF8)
            if ($lines | Select-String -Pattern 'SCRIPT ERROR:|CAPTION_RESULT .*"ok":false') {
                throw "CAPTION_RUNTIME_FAILED: $Stage"
            }
            $allStages = @($lines | Where-Object { $_.StartsWith('CAPTION_READY ') } |
                ForEach-Object { $_.Substring(14) | ConvertFrom-Json })
            $records = @($allStages | Where-Object { $_.stage -ceq $Stage })
            if ($records.Count -gt 1) { throw "AMBIGUOUS_STAGE: $Stage" }
            if ($records.Count -eq 1) {
                if ($allStages[-1].stage -cne $Stage) { throw "CAPTION_STALE_STAGE: $Stage" }
                return $records[0]
            }
        }
        if ($child.HasExited) { throw "CAPTION_CHILD_EXITED: $Stage" }
        Start-Sleep -Milliseconds 100
    }
    throw "CAPTION_STAGE_TIMEOUT: $Stage"
}

function Resolve-Caption([object]$Ready, [object]$Expected) {
    $targetPid = [int]$Ready.pid
    $title = "DWM Native Caption Accept $targetPid"
    $isReview = $Expected.review_offset -eq 1
    if ($Ready.window_title -cne $title -or $targetPid -le 0 -or $Ready.physical_contacts -ne 0 -or
        $Ready.run_token -cne $identity -or $Ready.anything_pressed -or $Ready.tree_paused -or $Ready.runtime_paused -or
        -not $Ready.input_delay_stopped -or -not $Ready.source_admitted -or -not $Ready.window_focused -or
        $Ready.stage -cne $Expected.stage -or $Ready.ended -ne 0 -or
        $Ready.text -cne $captions[$Expected.event_index] -or $Ready.event_index -ne $Expected.event_index -or
        $Ready.target_text -cne $captions[$Expected.target_index] -or $Ready.review_offset -ne $Expected.review_offset -or
        $Ready.revealing -ne $Expected.revealing -or $Ready.finished -ne $Expected.finished -or
        $Ready.live_visible -eq $isReview -or $Ready.review_visible -ne $isReview -or
        ($isReview -and -not $Ready.review_focused) -or
        (-not $isReview -and -not $Ready.live_focused) -or
        ($Ready.revealing -and ($Ready.visible_characters -lt 0 -or $Ready.visible_characters -ge $Ready.total_characters))) {
        throw "CAPTION_READY_CONTRACT_INVALID: $($Expected.stage)"
    }
    Assert-Capture $Ready.capture $Ready.stage
    Assert-SameLiveState $Ready.capture.state $Ready
    if ($Ready.stage -in @('review-enter', 'review-return', 'fresh-reveal')) {
        $partial = $Ready.partial_setup
        if ($Ready.visible_characters -ne $partialPrefix.Length -or
            $partial.method -cne 'fixture_visible_characters_assignment' -or
            $partial.expected_prefix -cne $partialPrefix -or $partial.visible_characters -ne $partialPrefix.Length -or
            $partial.changed_caption_pixels -le 20 -or -not $partial.outside_caption_unchanged -or
            -not $partial.caption_fully_visible -or $partial.naturally_elapsed) { throw 'CAPTION_PARTIAL_SETUP_INVALID' }
    }
    # The pinned console wrapper starts the real engine as a child; it is not the window PID.
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $targetPid"
    if ($child.HasExited -or $null -eq $process -or $process.ParentProcessId -ne $child.Id -or
        [string]$process.ExecutablePath -ine $enginePath) { throw 'CAPTION_PROCESS_MISMATCH' }
    $arguments = [DwmCaptionNative]::Arguments([string]$process.CommandLine)
    $expectedArguments = [DwmCaptionNative]::Arguments('"' + $enginePath + '" ' + $start.Arguments)
    if ($arguments.Count -ne $expectedArguments.Count) { throw 'CAPTION_PROCESS_ARGUMENTS' }
    for ($i = 0; $i -lt $arguments.Count; $i++) {
        if ($arguments[$i] -cne $expectedArguments[$i]) { throw "CAPTION_PROCESS_ARGUMENT: $i" }
    }
    $processIdentity = [ordered]@{ pid = $targetPid; parent_pid = [int]$process.ParentProcessId;
        executable = [string]$process.ExecutablePath; command_line = [string]$process.CommandLine;
        created_utc = $process.CreationDate.ToUniversalTime().ToString('o'); launcher_pid = $child.Id }
    if ($null -eq $script:boundProcess) { $script:boundProcess = $processIdentity }
    elseif ((ConvertTo-Json $processIdentity -Compress) -cne (ConvertTo-Json $boundProcess -Compress)) {
        throw 'CAPTION_CHILD_IDENTITY_CHANGED'
    }
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
                    automation_id = $_.Current.AutomationId; runtime_id = @($_.GetRuntimeId());
                    physical_rectangle = @($_.Current.BoundingRectangle.X, $_.Current.BoundingRectangle.Y,
                        $_.Current.BoundingRectangle.Width, $_.Current.BoundingRectangle.Height);
                    patterns = @($_.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName }) }
            })
            [IO.File]::WriteAllText((Join-Path $output ($Ready.stage + '-tree.json')),
                (ConvertTo-Json -InputObject $snapshot -Depth 8), $utf8)
            # Match the visible action's text, which differs from live text in review.
            $matches = @($elements | Where-Object {
                $_.Current.Name.TrimEnd() -ceq $Ready.target_text -and -not $_.Current.IsOffscreen
            })
            $actionable = @($matches | Where-Object {
                $candidatePattern = $null
                $_.Current.IsEnabled -and $_.TryGetCurrentPattern(
                    [Windows.Automation.InvokePattern]::Pattern, [ref]$candidatePattern)
            })
            if ($actionable.Count -gt 1) { throw 'CAPTION_UIA_AMBIGUOUS' }
            if ($actionable.Count -eq 1) { $target = $actionable[0]; break }
        }
        Start-Sleep -Milliseconds 100
    }
    if ($null -eq $target) { throw "CAPTION_UIA_NOT_FOUND: $($Ready.stage)" }
    $pattern = $null
    if (-not $target.Current.IsEnabled -or
        -not $target.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw 'CAPTION_INVOKE_PATTERN_MISSING'
    }
    $runtimeId = @($target.GetRuntimeId())
    if ($isReview -and $observations.Count -gt 0 -and
        ($runtimeId -join ',') -ceq ($observations[$observations.Count - 1].runtime_id -join ',')) {
        throw 'CAPTION_REVIEW_REUSED_LIVE_TARGET'
    }
    $rectangle = $target.Current.BoundingRectangle
    if ($rectangle.IsEmpty -or $rectangle.Width -le 2 -or $rectangle.Height -le 2 -or
        -not $window.Current.BoundingRectangle.Contains($rectangle)) { throw 'CAPTION_NATIVE_RECTANGLE' }
    foreach ($value in @($rectangle.X, $rectangle.Y, $rectangle.Width, $rectangle.Height)) {
        if ([double]::IsNaN($value) -or [double]::IsInfinity($value)) { throw 'CAPTION_NATIVE_NONFINITE_RECTANGLE' }
    }
    $binding = [pscustomobject]@{ target = $target; pattern = $pattern; window = $window;
        window_handle = $native.MainWindowHandle.ToInt64(); pid = $targetPid;
        runtime_id = $runtimeId; rectangle = $rectangle; ready = $Ready; process_identity = $processIdentity;
        physical_rectangle = @($rectangle.X, $rectangle.Y, $rectangle.Width, $rectangle.Height) }
    $native.Dispose()
    return $binding
}

function Write-CaptionJson([string]$Name, [object]$Value) {
    [IO.File]::WriteAllText((Join-Path $output $Name), (ConvertTo-Json -InputObject $Value -Depth 40), $utf8)
}

function Assert-SameLiveState([object]$Before, [object]$After) {
    foreach ($key in @('run_token', 'text', 'visible_characters', 'total_characters', 'revealing',
        'reveal_generation', 'event_index', 'finished', 'ended', 'retained_captions', 'simple_history', 'full_history')) {
        if ((ConvertTo-Json -InputObject $Before.$key -Depth 25 -Compress) -cne
            (ConvertTo-Json -InputObject $After.$key -Depth 25 -Compress)) {
            throw "CAPTION_LIVE_STATE_CHANGED: $key"
        }
    }
}

function Assert-Capture([object]$Capture, [string]$Stage) {
    if ($Capture.file -cne ($Stage + '.png') -or $Capture.width -ne 1280 -or $Capture.height -ne 720 -or
        $Capture.sha256 -cnotmatch '^[a-f0-9]{64}$') { throw "CAPTION_CAPTURE_IDENTITY: $Stage" }
    $path = Join-Path $output $Capture.file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $Capture.sha256) {
        throw "CAPTION_CAPTURE_HASH: $Stage"
    }
}

function Assert-NativeBoundary([object]$Binding) {
    $handle = [IntPtr]$Binding.window_handle
    $windowPid = [uint32]0
    [void][DwmCaptionNative]::GetWindowThreadProcessId($handle, [ref]$windowPid)
    $keys = @([DwmCaptionNative]::PressedKeys())
    if ($child.HasExited -or $windowPid -ne $Binding.pid -or
        [DwmCaptionNative]::GetForegroundWindow() -ne $handle -or $keys.Count -ne 0 -or
        -not $Binding.target.Current.IsEnabled -or $Binding.target.Current.IsOffscreen -or
        $Binding.target.Current.ProcessId -ne $Binding.pid -or
        ($Binding.target.GetRuntimeId() -join ',') -cne ($Binding.runtime_id -join ',') -or
        $Binding.target.Current.Name.TrimEnd() -cne $Binding.ready.target_text) {
        throw "CAPTION_NATIVE_CUSTODY: $($Binding.ready.stage); held_keys=$($keys -join ',')"
    }
}

function Assert-PhysicalTarget([object]$Binding, [object]$Point) {
    Assert-NativeBoundary $Binding
    $rectangle = $Binding.target.Current.BoundingRectangle
    $pointValue = [Windows.Point]::new([double]$Point.X, [double]$Point.Y)
    if (-not $rectangle.Equals($Binding.rectangle) -or -not $rectangle.Contains($pointValue) -or
        [DwmCaptionNative]::GetAncestor([DwmCaptionNative]::WindowFromPhysicalPoint($Point), 2) -ne
            [IntPtr]$Binding.window_handle) { throw 'CAPTION_PHYSICAL_TARGET_CHANGED' }
    $hit = [Windows.Automation.AutomationElement]::FromPoint($pointValue)
    $node = $hit
    $matched = $false
    for ($depth = 0; $null -ne $node -and $depth -lt 32; $depth++) {
        if ($node.Current.ProcessId -ne $Binding.pid) { break }
        if (($node.GetRuntimeId() -join ',') -ceq ($Binding.runtime_id -join ',')) { $matched = $true; break }
        $node = [Windows.Automation.TreeWalker]::RawViewWalker.GetParent($node)
    }
    if (-not $matched) { throw 'CAPTION_PHYSICAL_HIT_NOT_LIVE_TARGET' }
    return [ordered]@{ name = $hit.Current.Name; runtime_id = @($hit.GetRuntimeId());
        type = $hit.Current.ControlType.ProgrammaticName; pid = $hit.Current.ProcessId }
}

function Invoke-Caption([object]$Ready, [object]$Expected) {
    $binding = Resolve-Caption $Ready $Expected
    Assert-NativeBoundary $binding
    [void](Read-Stage $Ready.stage) # Refuse a stage that advanced during discovery.
    $observation = [ordered]@{ stage = $Ready.stage; pid = $binding.pid;
        window_handle = $binding.window_handle; window = $binding.window.Current.Name;
        name = $binding.target.Current.Name; type = $binding.target.Current.ControlType.ProgrammaticName;
        runtime_id = $binding.runtime_id; process = $binding.process_identity;
        physical_rectangle = $binding.physical_rectangle; foreground = $binding.window_handle;
        method = 'Windows.UIAutomation.InvokePattern.Invoke'; attempted_calls = 1; returned = $false;
        invocations = 0; ready = $Ready }
    $observations.Add($observation)
    Write-CaptionJson 'invocations.json' @($observations.ToArray())
    # No SetFocus, callback substitution or automatic invocation retry.
    try {
        ([Windows.Automation.InvokePattern]$binding.pattern).Invoke()
        $observation.returned = $true
        $observation.invocations = 1
    } finally { Write-CaptionJson 'invocations.json' @($observations.ToArray()) }
}

function Invoke-ReviewWheel([object]$Ready, [object]$Expected) {
    $binding = Resolve-Caption $Ready $Expected
    Assert-NativeBoundary $binding
    $rectangle = $binding.rectangle
    $destination = New-Object DwmCaptionNative+Point
    $destination.X = [int][Math]::Floor($rectangle.X + $rectangle.Width / 2)
    $destination.Y = [int][Math]::Floor($rectangle.Y + $rectangle.Height / 2)
    $cursorBefore = [DwmCaptionNative]::Cursor()
    $script:wheelObservation = [ordered]@{ stage = $Ready.stage; run_token = $identity; pid = $binding.pid;
        process = $binding.process_identity; window_handle = $binding.window_handle;
        live_runtime_id = $binding.runtime_id; physical_rectangle = $binding.physical_rectangle;
        before = $Ready; after = $null; observed_transition = $false;
        cursor = [ordered]@{ method = 'SetPhysicalCursorPos'; attempted_calls = 1;
            before = $cursorBefore; requested = $destination; succeeded = $false; after = $null };
        wheel = [ordered]@{ method = 'SendInput/MOUSEEVENTF_WHEEL'; delta = -120;
            attempted_calls = 0; requested_packets = 1; inserted_packets = $null; last_error = $null;
            input_size = [DwmCaptionNative]::InputSize() } }
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
    $wheelObservation.cursor.succeeded = [DwmCaptionNative]::SetPhysicalCursorPos($destination.X, $destination.Y)
    $wheelObservation.cursor['last_error'] = if ($wheelObservation.cursor.succeeded) { 0 } else { [Runtime.InteropServices.Marshal]::GetLastWin32Error() }
    $wheelObservation.cursor.after = [DwmCaptionNative]::Cursor()
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
    if (-not $wheelObservation.cursor.succeeded -or $wheelObservation.cursor.after.X -ne $destination.X -or
        $wheelObservation.cursor.after.Y -ne $destination.Y) { throw 'CAPTION_CURSOR_POSITION_FAILED' }
    Start-Sleep -Milliseconds 150 # Settle positioning; this is not a caption action or retry.
    $actualPoint = [DwmCaptionNative]::Cursor()
    if ($actualPoint.X -ne $destination.X -or $actualPoint.Y -ne $destination.Y) { throw 'CAPTION_CURSOR_MOVED' }
    $wheelObservation['hit'] = Assert-PhysicalTarget $binding $actualPoint
    [void](Read-Stage $Ready.stage)
    $wheelObservation.wheel.attempted_calls = 1
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
    $errorCode = 0
    $wheelObservation.wheel.inserted_packets = [DwmCaptionNative]::WheelDown([ref]$errorCode)
    $wheelObservation.wheel.last_error = $errorCode
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
    if ($wheelObservation.wheel.inserted_packets -ne 1) { throw "CAPTION_WHEEL_INSERTION_FAILED: $errorCode" }
    # Insertion is not acceptance. The fixture must observe the actual review transition.
    $after = Read-Stage 'review-return'
    $wheelObservation.after = $after
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
    Assert-SameLiveState $Ready $after
    if ($Ready.review_offset -ne 0 -or $after.review_offset -ne 1 -or $after.pid -ne $Ready.pid -or
        $after.run_token -cne $identity -or $after.target_text -cne $captions[2] -or
        -not $after.review_focused -or -not $after.review_visible -or $after.live_visible -or
        $after.physical_contacts -ne 0 -or $after.anything_pressed -or -not $after.source_admitted) {
        throw 'CAPTION_WHEEL_REVIEW_TRANSITION_FAILED'
    }
    $wheelObservation.observed_transition = $true
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
}

$start = New-Object Diagnostics.ProcessStartInfo
$start.FileName = $consolePath
$start.Arguments = '--path "' + $repositoryRoot + '" --rendering-method gl_compatibility --audio-driver Dummy --accessibility always --log-file "' + $log + '" --script ' + $scriptArgument
$start.UseShellExecute = $false
$start.EnvironmentVariables['APPDATA'] = Join-Path $isolated 'appdata'
$start.EnvironmentVariables['LOCALAPPDATA'] = Join-Path $isolated 'localappdata'
$start.EnvironmentVariables['DWM_TEST_ROOT'] = $isolated
$start.EnvironmentVariables['DWM_CAPTION_EVIDENCE_ROOT'] = $output
$start.EnvironmentVariables['DWM_CAPTION_RUN_TOKEN'] = $identity
New-Item -ItemType Directory -Force -Path $start.EnvironmentVariables['APPDATA'], $start.EnvironmentVariables['LOCALAPPDATA'] | Out-Null
$child = New-Object Diagnostics.Process
$child.StartInfo = $start
$started = $false
$previousDpi = [IntPtr]::Zero
$activeStage = 'launch'
try {
    $previousDpi = [DwmCaptionNative]::SetThreadDpiAwarenessContext([IntPtr](-4))
    if ($previousDpi -eq [IntPtr]::Zero -or [DwmCaptionNative]::InputSize() -ne 40 -or [IntPtr]::Size -ne 8) {
        throw 'CAPTION_NATIVE_DRIVER_ABI_OR_DPI'
    }
    $started = $child.Start()
    if (-not $started) { throw 'CAPTION_START_FAILED' }
    foreach ($step in $steps) {
        $activeStage = $step.stage
        $ready = Read-Stage $step.stage
        if ($step.stage -ceq 'review-enter') { Invoke-ReviewWheel $ready $step }
        else { Invoke-Caption $ready $step }
    }
    $activeStage = 'verify-result'
    if (-not $child.WaitForExit(15000)) { throw 'CAPTION_EXIT_TIMEOUT' }
    if ($child.ExitCode -ne 0) { throw "CAPTION_EXIT_CODE: $($child.ExitCode)" }
    $result = Get-Content -Raw -LiteralPath (Join-Path $output 'runtime.json') -Encoding UTF8 | ConvertFrom-Json
    if (-not $result.ok -or $observations.Count -ne 9 -or $result.event_index -ne 4 -or
        $result.text -cne $captions[4] -or -not $result.revealing -or $result.finished -ne 4 -or
        $result.ended -ne 0 -or $result.physical_contacts -ne 0 -or $result.review_offset -ne 0) {
        throw 'CAPTION_NATIVE_RESULT_INVALID'
    }
    if ($result.run_token -cne $identity -or $null -eq $wheelObservation -or
        -not $wheelObservation.observed_transition -or $wheelObservation.wheel.attempted_calls -ne 1 -or
        $wheelObservation.wheel.inserted_packets -ne 1 -or $result.anything_pressed -or
        @($observations | Where-Object { -not $_.returned -or $_.invocations -ne 1 }).Count -ne 0) {
        throw 'CAPTION_NATIVE_ACTION_RECORDS'
    }
    $entry = $result.review_entry
    Assert-SameLiveState $entry.before $entry.after
    Assert-SameLiveState $wheelObservation.before $entry.before
    Assert-SameLiveState $wheelObservation.after $entry.after
    if (-not $entry.invariants_unchanged -or ($entry.observed_offsets -join ',') -cne '0,1' -or
        $entry.before.review_offset -ne 0 -or $entry.after.review_offset -ne 1) { throw 'CAPTION_ENTRY_RESULT' }
    $review = $result.review_return
    $before = $review.before
    $returned = $review.returned
    Assert-SameLiveState $before $returned
    Assert-SameLiveState $entry.before $before
    if ($before.visible_characters -ne $partialPrefix.Length -or
        $returned.scroll_offset -ne $before.scroll_offset -or -not $review.partial_pixels_equal) {
        throw 'CAPTION_NONZERO_RETURN_RESULT'
    }
    foreach ($capture in $result.captures.PSObject.Properties) { Assert-Capture $capture.Value $capture.Name }
    if (-not $review.invariants_unchanged -or -not $review.native_history_unchanged -or
        $before.event_index -ne 3 -or $before.finished -ne 3 -or -not $before.revealing -or
        $review.reviewing.review_offset -ne 1 -or $review.reviewing.target_text -cne $captions[2] -or
        $returned.review_offset -ne 0 -or -not $returned.live_visible -or $returned.review_visible -or
        -not $returned.live_focused -or -not $returned.revealing -or $returned.physical_contacts -ne 0 -or
        $returned.event_index -ne $before.event_index -or $returned.finished -ne $before.finished -or
        $returned.ended -ne $before.ended -or $returned.text -cne $before.text -or
        $returned.visible_characters -ne $before.visible_characters -or
        $returned.reveal_generation -ne $before.reveal_generation -or
        (ConvertTo-Json -InputObject $returned.simple_history -Depth 20 -Compress) -cne
            (ConvertTo-Json -InputObject $before.simple_history -Depth 20 -Compress) -or
        (ConvertTo-Json -InputObject $returned.full_history -Depth 20 -Compress) -cne
            (ConvertTo-Json -InputObject $before.full_history -Depth 20 -Compress)) {
        throw 'CAPTION_NATIVE_REVIEW_RETURN_INVALID'
    }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load' -Quiet) {
        throw 'CAPTION_NATIVE_SCRIPT_ERROR'
    }
    $source = (& git -C $repositoryRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'CAPTION_SOURCE_UNKNOWN' }
    $receipt = [ordered]@{ ok = $true; checkout = $source; run_id = $env:GITHUB_RUN_ID;
        run_attempt = $env:GITHUB_RUN_ATTEMPT; native_invocations = 9; runtime = $result;
        review_return_verified = $true; native_wheel_entry_verified = $true; run_token = $identity;
        wheel_entry = $wheelObservation; process_identity = $boundProcess;
        console_sha256 = (Get-FileHash $consolePath -Algorithm SHA256).Hash.ToLowerInvariant();
        engine_sha256 = (Get-FileHash $enginePath -Algorithm SHA256).Hash.ToLowerInvariant();
        scope = 'Mounted fixture; native wheel entry plus UIA return. Nonzero count is seeded with elapsed reveal disabled. No speech, ScrollPattern, production consequences or timed-lifecycle claim. PNGs are Godot viewport captures.' }
    [IO.File]::WriteAllText((Join-Path $output 'receipt.json'), (ConvertTo-Json $receipt -Depth 25), $utf8)
    Write-Output 'CAPTION_NATIVE_ACCEPT_VERIFIED'
} catch {
    Write-CaptionJson 'driver-failure.json' ([ordered]@{ ok = $false; stage = $activeStage; run_token = $identity;
        error = $_.Exception.Message; position = $_.InvocationInfo.PositionMessage;
        process_identity = $boundProcess; wheel_entry = $wheelObservation;
        invocations = @($observations.ToArray()); run_id = $env:GITHUB_RUN_ID; run_attempt = $env:GITHUB_RUN_ATTEMPT })
    throw
} finally {
    if ($started -and -not $child.HasExited) { & taskkill.exe /PID $child.Id /T /F | Out-Null }
    $child.Dispose()
    if ($previousDpi -ne [IntPtr]::Zero) { [void][DwmCaptionNative]::SetThreadDpiAwarenessContext($previousDpi) }
    $files = @(Get-ChildItem -LiteralPath $output -File | Where-Object { $_.Name -cne 'files.sha256.json' } |
        Sort-Object Name | ForEach-Object { [ordered]@{ file = $_.Name; bytes = $_.Length;
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() } })
    Write-CaptionJson 'files.sha256.json' $files
}
