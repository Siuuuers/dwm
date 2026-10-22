[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BindingPath,
    [Parameter(Mandatory = $true)][string]$ReceiptPath,
    [Parameter(Mandatory = $true)][string]$StopPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$clock = [Diagnostics.Stopwatch]::StartNew()
$utf8 = New-Object Text.UTF8Encoding($false)
$events = New-Object Collections.Generic.List[object]
$record = [ordered]@{ reader_pid = $PID; clock = 'system UTC Unix milliseconds; elapsed uses Stopwatch';
    status = 'starting'; ok = $false; discovered = $false; identity = $null; hwnd = $null;
    attachment_started_unix_msec = $null; attachment_completed_unix_msec = $null;
    discovery_started_unix_msec = $null; discovery_completed_unix_msec = $null;
    reader_completed_unix_msec = $null;
    descendant_count = $null; error = $null; exit_code = $null; events = @() }
$native = $null
$launcher = $null
$window = $null
$elements = $null
$result = 1
$nativeSession = $null
$record['client_route'] = 'managed-discovery-then-native-COM-provenance'
$record['native_provider'] = [ordered]@{ status = 'not_started'; operations = @(); cleanup_errors = @(); identity_verified = $false; diagnostic_only = $true }

. (Join-Path $PSScriptRoot 'Get-ContinueFileSha256.ps1')
. (Join-Path $PSScriptRoot 'Save-ContinueReaderEvent.ps1')
. (Join-Path $PSScriptRoot 'Select-ContinueEngineChild.ps1')
$selectionObserved = $false

try {
    Save-ReaderEvent 'reader_start'
    # Compile declarations before attaching to the short-lived game fixture.
    # No native client/session operation occurs until after managed discovery.
    $interopPath = Join-Path $PSScriptRoot 'ContinueNativeProvider.cs'
    Save-ReaderEvent 'interop_compile_start'
    Add-Type -Path $interopPath
    Save-ReaderEvent 'interop_compile_ready'
    $binding = Get-Content -LiteralPath $BindingPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $launcherPid = [int]$binding.launcher_pid
    $launcherTicks = [long]$binding.launcher_start_ticks
    $consolePath = [IO.Path]::GetFullPath([string]$binding.console_path)
    $enginePath = [IO.Path]::GetFullPath([string]$binding.engine_path)
    if ($launcherPid -le 0 -or $launcherTicks -le 0 -or
        $consolePath -notmatch '_console\.exe$' -or
        $enginePath -ine ($consolePath -replace '_console\.exe$', '.exe')) {
        throw 'UIA_BINDING_INVALID'
    }
    $record['binding'] = $binding
    $launcher = [Diagnostics.Process]::GetProcessById($launcherPid)
    function Assert-Launcher {
        $launcher.Refresh()
        $info = Get-CimInstance Win32_Process -Filter "ProcessId = $launcherPid"
        if ($launcher.HasExited -or $launcher.StartTime.ToUniversalTime().Ticks -ne $launcherTicks -or
            $null -eq $info -or [string]$info.ExecutablePath -ine $consolePath) {
            throw 'UIA_LAUNCHER_IDENTITY_CHANGED'
        }
    }
    Assert-Launcher
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    Add-Type -AssemblyName WindowsBase
    # Identity parsing and HWND ownership only: no input or action imports.
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class DwmContinueReader {
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("shell32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern IntPtr CommandLineToArgvW(string command, out int count);
    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr memory);
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
}
'@
    $expectedArguments = [DwmContinueReader]::Arguments('"' + $enginePath + '" ' + [string]$binding.arguments)
    function Get-EngineIdentity([object]$Info) {
        if ([int]$Info.ParentProcessId -ne $launcherPid -or [string]$Info.ExecutablePath -ine $enginePath) {
            throw 'UIA_ENGINE_IDENTITY_INVALID'
        }
        # CIM CreationDate may truncate sub-microsecond precision. Compare start
        # ordering through the same native Process API used for the launcher;
        # retain CIM creation time separately as part of the immutable identity.
        $candidate = [Diagnostics.Process]::GetProcessById([int]$Info.ProcessId)
        try {
            $candidateStart = $candidate.StartTime.ToUniversalTime().Ticks
            if ($candidate.HasExited -or $candidateStart -lt $launcherTicks) {
                throw 'UIA_ENGINE_START_IDENTITY_INVALID'
            }
        } finally { $candidate.Dispose() }
        $arguments = [DwmContinueReader]::Arguments([string]$Info.CommandLine)
        if ($arguments.Count -ne $expectedArguments.Count) { throw 'UIA_ENGINE_ARGUMENT_COUNT' }
        for ($i = 0; $i -lt $arguments.Count; $i++) {
            if ($arguments[$i] -cne $expectedArguments[$i]) { throw "UIA_ENGINE_ARGUMENT: $i" }
        }
        return [ordered]@{ pid = [int]$Info.ProcessId; parent_pid = [int]$Info.ParentProcessId;
            executable = [string]$Info.ExecutablePath; command_line = [string]$Info.CommandLine;
            created_utc = $Info.CreationDate.ToUniversalTime().ToString('o');
            native_start_ticks = $candidateStart.ToString([Globalization.CultureInfo]::InvariantCulture);
            launcher_pid = $launcherPid }
    }
    $record.status = 'resolving_identity'
    Save-ReaderEvent 'identity_start'
    while ($clock.Elapsed.TotalSeconds -lt 120) {
        if (Test-Path -LiteralPath $StopPath) { throw 'UIA_STOPPED_BEFORE_DISCOVERY' }
        Assert-Launcher
        # Never enumerate or attach to arbitrary desktop processes/windows.
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $launcherPid")
        $selection = Select-ContinueEngineChild -Children $children -LauncherId $launcherPid -EngineExecutable $enginePath
        $record['child_selection'] = $selection.receipt
        # One initial sample; later identity/failure/completion receipts retain the latest inventory.
        if (-not $selectionObserved) {
            Save-ReaderEvent 'child_selection'
            $selectionObserved = $true
        }
        if ($null -ne $selection.error) { throw $selection.error }
        if ($null -ne $selection.candidate) {
            $identity = Get-EngineIdentity $selection.candidate
            if ($null -eq $record.identity) {
                $record.identity = $identity
                $native = [Diagnostics.Process]::GetProcessById([int]$identity.pid)
                $record['engine_start_ticks'] = $native.StartTime.ToUniversalTime().Ticks
                Save-ReaderEvent 'identity_bound'
            } elseif ((ConvertTo-Json $identity -Compress) -cne
                (ConvertTo-Json $record.identity -Compress)) {
                throw 'UIA_ENGINE_IDENTITY_CHANGED'
            }
            $native.Refresh()
            if ($native.HasExited -or $native.StartTime.ToUniversalTime().Ticks -ne $record.engine_start_ticks) {
                throw 'UIA_ENGINE_STALE_BEFORE_DISCOVERY'
            }
            $handle = $native.MainWindowHandle
            if ($handle -ne [IntPtr]::Zero) {
                [uint32]$windowPid = 0
                if ([DwmContinueReader]::GetWindowThreadProcessId($handle, [ref]$windowPid) -eq 0 -or
                    $windowPid -ne [uint32]$identity.pid) { throw 'UIA_HWND_PROCESS_MISMATCH' }
                $record.hwnd = $handle.ToInt64()
                $record.status = 'attaching'
                Save-ReaderEvent 'attachment_start'
                # Persist first: UIA may block; the owning helper enforces process timeout/cleanup.
                $window = [Windows.Automation.AutomationElement]::FromHandle($handle)
                if ($null -eq $window -or $window.Current.ProcessId -ne [int]$identity.pid) {
                    throw 'UIA_ELEMENT_PROCESS_MISMATCH'
                }
                Save-ReaderEvent 'attachment_return'
                Assert-Launcher
                $current = Get-CimInstance Win32_Process -Filter "ProcessId = $($identity.pid)"
                if ($null -eq $current -or (ConvertTo-Json (Get-EngineIdentity $current) -Compress) -cne
                    (ConvertTo-Json $identity -Compress)) { throw 'UIA_ENGINE_CHANGED_BEFORE_DISCOVERY' }
                $native.Refresh()
                [uint32]$windowPid = 0
                if ($native.HasExited -or $native.MainWindowHandle -ne $handle -or
                    [DwmContinueReader]::GetWindowThreadProcessId($handle, [ref]$windowPid) -eq 0 -or
                    $windowPid -ne [uint32]$identity.pid) { throw 'UIA_HWND_CHANGED_BEFORE_DISCOVERY' }
                $record.status = 'discovering'
                Save-ReaderEvent 'discovery_start'
                $elements = $window.FindAll([Windows.Automation.TreeScope]::Descendants,
                    [Windows.Automation.Condition]::TrueCondition)
                $record.descendant_count = $elements.Count
                $record.discovered = $true
                $record.status = 'holding_reader'
                Save-ReaderEvent 'discovery_success'
                $record['provider_observation'] = [ordered]@{ scope = 'existing UIA element after discovery; descriptive only';
                    started_unix_msec = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); completed_unix_msec = $null }
                Save-ReaderEvent 'provider_observation_start'
                $record.provider_observation['framework_id'] = $window.Current.FrameworkId
                $record.provider_observation['class_name'] = $window.Current.ClassName
                $record.provider_observation['control_type'] = $window.Current.ControlType.ProgrammaticName
                $record.provider_observation['native_window_handle'] = $window.Current.NativeWindowHandle
                $record.provider_observation.completed_unix_msec = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                Save-ReaderEvent 'provider_observation_complete'
                # A second client route, after the unchanged managed observation.
                # This may itself activate a provider; it is not a matched baseline.
                $record.native_provider.status = 'loading_interop'
                Save-ReaderEvent 'native_interop_start'
                $record.native_provider['interop_sha256'] = (Get-ContinueFileSha256 -LiteralPath $interopPath)
                $record.native_provider['powershell'] = $PSVersionTable.PSVersion.ToString()
                $record.native_provider['clr'] = [Environment]::Version.ToString()
                $record.native_provider['process_bits'] = [IntPtr]::Size * 8
                $record.native_provider['reader_path'] = $PSCommandPath
                $record.native_provider['reader_sha256'] = (Get-ContinueFileSha256 -LiteralPath $PSCommandPath)
                $uiaCorePath = Join-Path $env:SystemRoot 'System32/UIAutomationCore.dll'
                $record.native_provider['uia_core'] = [ordered]@{ path = $uiaCorePath;
                    file_version = [Diagnostics.FileVersionInfo]::GetVersionInfo($uiaCorePath).FileVersion;
                    sha256 = (Get-ContinueFileSha256 -LiteralPath $uiaCorePath) }
                $nativeSession = New-Object DwmNativeProvider.Session
                $record.native_provider['assembly'] = $nativeSession.GetType().Assembly.FullName
                $record.native_provider['apartment'] = $nativeSession.Apartment
                Save-ReaderEvent 'native_interop_ready'
                function Assert-NativeBinding {
                    Assert-Launcher
                    $native.Refresh()
                    [uint32]$currentWindowPid = 0
                    if ($native.HasExited -or $native.StartTime.ToUniversalTime().Ticks -ne $record.engine_start_ticks -or
                        $native.MainWindowHandle -ne $handle -or
                        [DwmContinueReader]::GetWindowThreadProcessId($handle, [ref]$currentWindowPid) -eq 0 -or
                        $currentWindowPid -ne [uint32]$identity.pid) { throw 'UIA_NATIVE_BINDING_CHANGED' }
                }
                Assert-NativeBinding
                $record.native_provider.status = 'activating_client'
                Save-ReaderEvent 'native_activate_start'
                $operation = $nativeSession.Activate()
                $record.native_provider.operations = @($nativeSession.Operations)
                Save-ReaderEvent 'native_activate_return'
                if ($operation.State -cne 'ok') { throw 'UIA_NATIVE_ACTIVATION_FAILED' }
                Assert-NativeBinding
                $record.native_provider.status = 'attaching'
                Save-ReaderEvent 'native_attach_start'
                $operation = $nativeSession.Attach($handle)
                $record.native_provider.operations = @($nativeSession.Operations)
                Save-ReaderEvent 'native_attach_return'
                if ($operation.State -cne 'ok') { throw 'UIA_NATIVE_ATTACHMENT_FAILED' }
                Assert-NativeBinding
                foreach ($propertyId in @(30002, 30020)) {
                    $record.native_provider.status = 'verifying_identity'
                    Save-ReaderEvent "native_property_${propertyId}_start"
                    $operation = $nativeSession.Read($propertyId)
                    $record.native_provider.operations = @($nativeSession.Operations)
                    Save-ReaderEvent "native_property_${propertyId}_return"
                    Assert-NativeBinding
                    if ($operation.State -cne 'value' -or $operation.Value -isnot [int]) { throw "UIA_NATIVE_IDENTITY_UNAVAILABLE: $propertyId" }
                    if ($propertyId -eq 30002 -and $operation.Value -ne [int]$identity.pid) { throw 'UIA_NATIVE_PID_MISMATCH' }
                    if ($propertyId -eq 30020) {
                        # UIA NativeWindowHandle is VT_I4, even in a 64-bit client.
                        $normalized = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$operation.Value), 0)
                        $handle64 = $handle.ToInt64()
                        $upper = $handle64 -shr 32
                        if (($upper -ne 0 -and $upper -ne -1) -or
                            [long]$normalized -ne ($handle64 -band 4294967295L)) { throw 'UIA_NATIVE_HWND_MISMATCH' }
                        $record.native_provider['native_hwnd_uint32'] = [long]$normalized
                    }
                }
                $record.native_provider.identity_verified = $true
                $record.native_provider.status = 'reading_provenance'
                Save-ReaderEvent 'native_property_30107_start'
                $operation = $nativeSession.Read(30107)
                $record.native_provider.operations = @($nativeSession.Operations)
                Save-ReaderEvent 'native_property_30107_return'
                Assert-NativeBinding
                $current = Get-CimInstance Win32_Process -Filter "ProcessId = $($identity.pid)"
                if ($null -eq $current -or (ConvertTo-Json (Get-EngineIdentity $current) -Compress) -cne
                    (ConvertTo-Json $identity -Compress)) { throw 'UIA_NATIVE_ENGINE_CHANGED_AFTER_QUERY' }
                if ($operation.State -notin @('value', 'empty', 'null', 'null_variant', 'unsupported')) { throw 'UIA_NATIVE_PROVENANCE_QUERY_FAILED' }
                $record.native_provider.status = 'observed'
                Save-ReaderEvent 'native_provenance_complete'
                # Keep native client/element alive alongside the original managed objects.
                break
            }
        } elseif ($null -ne $record.identity) { throw 'UIA_BOUND_ENGINE_DISAPPEARED' }
        Start-Sleep -Milliseconds 50
    }
    if (-not $record.discovered) { throw 'UIA_ATTACHMENT_TIMEOUT' }
    # Keep the exact UIA objects alive; never invoke a pattern, action, focus or input.
    while ($clock.Elapsed.TotalSeconds -lt 120) {
        if (Test-Path -LiteralPath $StopPath) {
            $record.status = 'stopped_by_owner'
            Save-ReaderEvent 'stop_requested'
            $result = 0
            break
        }
        $native.Refresh()
        if ($native.HasExited) {
            $record.status = 'engine_exited'
            Save-ReaderEvent 'engine_exit_observed'
            $result = 0
            break
        }
        Start-Sleep -Milliseconds 50
    }
    if ($result -ne 0) { throw 'UIA_READER_LIFETIME_TIMEOUT' }
} catch {
    $record.status = 'failed'
    $record.error = $_.Exception.Message
    $result = 1
    Save-ReaderEvent 'failure'
} finally {
    if ($null -ne $nativeSession) {
        $nativeSession.Dispose()
        $record.native_provider.operations = @($nativeSession.Operations)
        $record.native_provider.cleanup_errors = @($nativeSession.CleanupErrors)
        if ($nativeSession.CleanupErrors.Length -ne 0) {
            if ($null -eq $record.error) { $record.error = 'UIA_NATIVE_CLEANUP_FAILED' }
            $record.status = 'failed'
            $result = 1
        }
    }
    # These references deliberately survive until the child exits or its owner stops us.
    [GC]::KeepAlive($elements)
    [GC]::KeepAlive($window)
    if ($null -ne $native) { $native.Dispose() }
    if ($null -ne $launcher) { $launcher.Dispose() }
    $record.exit_code = $result
    $record.ok = $result -eq 0
    Save-ReaderEvent 'reader_complete'
}
exit $result
