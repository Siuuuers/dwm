#requires -Version 7.0
# REVIEW ONLY. Synchronous WCT can block indefinitely. The caller MUST launch this
# in a separate process and enforce one 5000ms wall-clock budget, including startup.
param(
    [Parameter(Mandatory)][ValidateRange(1,2147483647)][int]$TargetProcessId,
    [Parameter(Mandatory)][string]$ExpectedExecutable,
    [Parameter(Mandatory)][string]$ExpectedStartedUtc,
    [Parameter(Mandatory)][long]$ExpectedWindowHandle,
    [Parameter(Mandatory)][string]$OutputFile
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
if (Test-Path -LiteralPath $OutputFile) { throw 'WCT_OUTPUT_NOT_FRESH' }
$report = [ordered]@{ utc = [DateTime]::UtcNow.ToString('o'); diagnostic_only = $true;
    status = 'incomplete'; phase = 'startup'; error = $null; query_attempts = 0;
    parent_watchdog_required_msec = 5000; self_bounded = $false;
    privilege_policy = 'No token adjustment or elevation; access failures retained';
    requested_pid = $TargetProcessId; requested_hwnd = $ExpectedWindowHandle;
    expected_executable = $ExpectedExecutable; expected_started_utc = $ExpectedStartedUtc;
    identity_verified = $false; post_identity_verified = $false; nodes = @() }
function Flush-Report {
    $temporary = $OutputFile + '.tmp'
    [IO.File]::WriteAllText($temporary, ($report | ConvertTo-Json -Depth 12), $utf8)
    if ([IO.File]::Exists($OutputFile)) { [IO.File]::Replace($temporary, $OutputFile, $null) }
    else { [IO.File]::Move($temporary, $OutputFile) }
}
Flush-Report
$target = $null
$session = [IntPtr]::Zero
$module = [IntPtr]::Zero
$buffer = [IntPtr]::Zero
$registered = $false
try {
    if ($env:OS -cne 'Windows_NT' -or [IntPtr]::Size -ne 8) { throw 'WCT_WINDOWS_X64_REQUIRED' }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class DwmWaitChainProbe {
    public const int Capacity = 16;
    public const uint Flags = 0x1 | 0x2 | 0x4;
    // SDK wct.h, Windows x64 default packing. LockLayout represents the largest
    // union member; thread fields are four DWORDs at the same union offset.
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode, Pack=8)]
    public struct LockLayout {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string ObjectName;
        public long Timeout;
        public int Alertable;
    }
    [StructLayout(LayoutKind.Sequential, Pack=8)]
    public struct NodeLayout {
        public uint ObjectType;
        public uint ObjectStatus;
        public LockLayout LockObject;
    }
    public static void VerifyLayout() {
        if (IntPtr.Size != 8 || Marshal.SizeOf(typeof(LockLayout)) != 272 ||
            Marshal.OffsetOf(typeof(LockLayout),"Timeout").ToInt32() != 256 ||
            Marshal.OffsetOf(typeof(LockLayout),"Alertable").ToInt32() != 264 ||
            Marshal.OffsetOf(typeof(NodeLayout),"LockObject").ToInt32() != 8 ||
            Marshal.SizeOf(typeof(NodeLayout)) != 280) throw new InvalidOperationException("WCT_ABI_MISMATCH");
    }
    [DllImport("user32.dll", SetLastError=true)] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern IntPtr LoadLibraryW(string path);
    [DllImport("kernel32.dll", CharSet=CharSet.Ansi, ExactSpelling=true, SetLastError=true)] public static extern IntPtr GetProcAddress(IntPtr module, string name);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern uint GetModuleFileNameW(IntPtr module, StringBuilder path, int size);
    [DllImport("advapi32.dll", SetLastError=true)] public static extern IntPtr OpenThreadWaitChainSession(uint flags, IntPtr callback);
    [DllImport("advapi32.dll")] public static extern void CloseThreadWaitChainSession(IntPtr session);
    [DllImport("advapi32.dll")] public static extern void RegisterWaitChainCOMCallback(IntPtr call, IntPtr activation);
    [DllImport("advapi32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetThreadWaitChain(IntPtr session, UIntPtr context, uint flags, uint tid,
        ref uint count, IntPtr nodes, [MarshalAs(UnmanagedType.Bool)] out bool cycle);
    public static uint ReadDword(IntPtr pointer, int offset) { return unchecked((uint)Marshal.ReadInt32(pointer, offset)); }
}
'@
    [DwmWaitChainProbe]::VerifyLayout()
    $report.abi = [ordered]@{ architecture = 'x64'; node_bytes = 280; union_offset = 8;
        object_name_wchars = 128; lock_timeout_offset = 264; lock_alertable_offset = 272;
        capacity = 16; flags = 7; verified = $true }
    $report.phase = 'identity'
    Flush-Report
    # Same executable/start-time conventions as the retained native-window probe,
    # plus the exact previously bound HWND (never select an arbitrary process thread).
    $target = Get-Process -Id $TargetProcessId
    if ($target.HasExited -or [IO.Path]::GetFullPath($target.MainModule.FileName) -ine [IO.Path]::GetFullPath($ExpectedExecutable) -or
        $target.StartTime.ToUniversalTime().ToString('o') -cne $ExpectedStartedUtc -or
        $ExpectedWindowHandle -eq 0 -or $target.MainWindowHandle.ToInt64() -ne $ExpectedWindowHandle) {
        throw 'WCT_PROCESS_OR_WINDOW_IDENTITY_MISMATCH'
    }
    $owner = [uint32]0
    $thread = [DwmWaitChainProbe]::GetWindowThreadProcessId([IntPtr]$ExpectedWindowHandle, [ref]$owner)
    if ($thread -eq 0 -or $owner -ne $TargetProcessId) { throw 'WCT_WINDOW_OWNER_MISMATCH' }
    $report.identity = [ordered]@{ pid = $owner; thread_id = $thread; hwnd = $ExpectedWindowHandle;
        executable = $target.MainModule.FileName; started_utc = $target.StartTime.ToUniversalTime().ToString('o') }
    $report.identity_verified = $true
    $report.phase = 'com-callbacks'
    Flush-Report
    $olePath = Join-Path ([Environment]::GetFolderPath('System')) 'ole32.dll'
    $module = [DwmWaitChainProbe]::LoadLibraryW($olePath)
    if ($module -eq [IntPtr]::Zero) { throw "WCT_OLE_LOAD_FAILED: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
    $actualPath = New-Object Text.StringBuilder(32768)
    $length = [DwmWaitChainProbe]::GetModuleFileNameW($module, $actualPath, $actualPath.Capacity)
    if ($length -eq 0 -or $length -ge $actualPath.Capacity -or $actualPath.ToString() -ine $olePath) { throw 'WCT_OLE_MODULE_IDENTITY_MISMATCH' }
    $call = [DwmWaitChainProbe]::GetProcAddress($module, 'CoGetCallState')
    $activation = [DwmWaitChainProbe]::GetProcAddress($module, 'CoGetActivationState')
    if ($call -eq [IntPtr]::Zero -or $activation -eq [IntPtr]::Zero) { throw 'WCT_COM_CALLBACK_UNAVAILABLE' }
    [DwmWaitChainProbe]::RegisterWaitChainCOMCallback($call, $activation)
    $registered = $true
    $report.com_callbacks = [ordered]@{ module = $actualPath.ToString(); registered = $true;
        call_export = 'CoGetCallState'; activation_export = 'CoGetActivationState';
        call_address = $call.ToInt64(); activation_address = $activation.ToInt64();
        lifetime = 'LoadLibrary reference retained through probe process exit; no dangling callback pointers' }
    $session = [DwmWaitChainProbe]::OpenThreadWaitChainSession(0, [IntPtr]::Zero)
    if ($session -eq [IntPtr]::Zero) { throw "WCT_SESSION_FAILED: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
    $buffer = [Runtime.InteropServices.Marshal]::AllocHGlobal(280 * 16)
    [Runtime.InteropServices.Marshal]::Copy([byte[]]::new(280 * 16), 0, $buffer, 280 * 16)
    $report.phase = 'query'
    $report.query_attempts = 1
    $report.query_started_utc = [DateTime]::UtcNow.ToString('o')
    Flush-Report
    $count = [uint32]16
    $cycle = $false
    $returned = [DwmWaitChainProbe]::GetThreadWaitChain($session, [UIntPtr]::Zero, 7, $thread, [ref]$count, $buffer, [ref]$cycle)
    $errorCode = if ($returned) { 0 } else { [Runtime.InteropServices.Marshal]::GetLastWin32Error() }
    $report.query_returned_utc = [DateTime]::UtcNow.ToString('o')
    $report.api_return = $returned
    $report.win32_error = $errorCode
    $report.reported_node_count = $count
    $report.is_cycle = $cycle
    $report.truncated = $count -gt 16 -or $errorCode -in @(234, 565)
    # ERROR_MORE_DATA and ERROR_TOO_MANY_THREADS retain valid partial chains.
    if ($returned -or $errorCode -in @(234, 565)) {
        for ($i = 0; $i -lt [Math]::Min([int]$count, 16); $i++) {
            $node = [IntPtr]::Add($buffer, $i * 280)
            $type = [DwmWaitChainProbe]::ReadDword($node, 0)
            $status = [DwmWaitChainProbe]::ReadDword($node, 4)
            $entry = [ordered]@{ index = $i; object_type = $type; object_status = $status }
            if ($type -eq 8) {
                $entry.thread = [ordered]@{ pid = [DwmWaitChainProbe]::ReadDword($node,8);
                    tid = [DwmWaitChainProbe]::ReadDword($node,12); wait_time = [DwmWaitChainProbe]::ReadDword($node,16);
                    context_switches = [DwmWaitChainProbe]::ReadDword($node,20) }
            } else {
                $entry.lock = [ordered]@{ object_name = [Runtime.InteropServices.Marshal]::PtrToStringUni([IntPtr]::Add($node,8),128).Split([char]0)[0];
                    timeout_raw_reserved = [Runtime.InteropServices.Marshal]::ReadInt64($node,264);
                    alertable_raw_reserved = [Runtime.InteropServices.Marshal]::ReadInt32($node,272) }
            }
            $report.nodes += $entry
        }
    }
    if ($report.nodes.Count -gt 0) {
        $first = $report.nodes[0]
        if ($first.object_type -ne 8 -or $first.thread.pid -ne $owner -or $first.thread.tid -ne $thread) {
            throw 'WCT_CHAIN_ROOT_IDENTITY_MISMATCH'
        }
    }
    $target.Refresh()
    $postOwner = [uint32]0
    $postThread = [DwmWaitChainProbe]::GetWindowThreadProcessId([IntPtr]$ExpectedWindowHandle, [ref]$postOwner)
    if ($target.HasExited -or $target.StartTime.ToUniversalTime().ToString('o') -cne $ExpectedStartedUtc -or
        $postOwner -ne $owner -or $postThread -ne $thread -or $target.MainWindowHandle.ToInt64() -ne $ExpectedWindowHandle) {
        throw 'WCT_IDENTITY_CHANGED_DURING_QUERY'
    }
    $report.post_identity_verified = $true
    $report.status = if ($returned -and -not $report.truncated -and $count -gt 0 -and
        @($report.nodes | Where-Object { $_.object_status -in @(1,4,5,9,10) }).Count -eq 0) { 'observed' } else { 'incomplete' }
    $report.phase = 'query-returned'
    Flush-Report
} catch {
    $report.status = 'error'
    $report.error = $_.Exception.Message
} finally {
    $report.cleanup_errors = @()
    if ($session -ne [IntPtr]::Zero) {
        try { [DwmWaitChainProbe]::CloseThreadWaitChainSession($session) } catch { $report.cleanup_errors += $_.Exception.Message }
    }
    if ($buffer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::FreeHGlobal($buffer) }
    # WCT documents registration, not an unregister operation. Keep the Ole32
    # reference until this disposable process exits rather than register null
    # callbacks or leave registered pointers referring to an unloaded module.
    $report.com_module_retained_until_process_exit = $module -ne [IntPtr]::Zero
    if ($null -ne $target) { $target.Dispose() }
    if ($report.cleanup_errors.Count -gt 0) { $report.status = 'error' }
    $report.finished_utc = [DateTime]::UtcNow.ToString('o')
    Flush-Report
}
# Status observed is a diagnostic snapshot, not a health verdict or acceptance.
if ($report.status -ne 'observed') { exit 1 }
exit 0
