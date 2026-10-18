#requires -Version 7.0
# Read-only failure diagnosis, launched in a separate bounded cloud process.
param(
    [Parameter(Mandatory)][int]$TargetProcessId,
    [Parameter(Mandatory)][string]$ExpectedExecutable,
    [Parameter(Mandatory)][string]$ExpectedStartedUtc,
    [Parameter(Mandatory)][string]$OutputFile,
    [long]$ExpectedWindowHandle = 0
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class DwmWindowProbe {
    public delegate bool EnumProc(IntPtr hwnd, IntPtr param);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr param);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsHungAppWindow(IntPtr hwnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, IntPtr wp, IntPtr lp, uint flags, uint timeout, out IntPtr result);
    public static IntPtr[] Windows(uint pid) {
        var found = new List<IntPtr>();
        EnumWindows((h,p) => { uint owner; GetWindowThreadProcessId(h,out owner); if(owner==pid) found.Add(h); return true; }, IntPtr.Zero);
        return found.ToArray();
    }
    public static string ClassName(IntPtr h) { var s=new StringBuilder(256); GetClassName(h,s,256); return s.ToString(); }
    public static bool Responds(IntPtr h) { IntPtr result; return SendMessageTimeout(h,0,IntPtr.Zero,IntPtr.Zero,2,1000,out result)!=IntPtr.Zero; }
}
'@
$report = [ordered]@{ utc=[DateTime]::UtcNow.ToString('o'); diagnostic_only=$true; phase='identity'; windows=@() }
function Flush-Report { $report.updated_utc = [DateTime]::UtcNow.ToString('o'); $report | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $OutputFile -Encoding utf8 }
Flush-Report
function Assert-Identity([long]$Handle = 0) {
    $identity = Get-Process -Id $TargetProcessId
    try {
        if ($identity.HasExited -or [IO.Path]::GetFullPath($identity.MainModule.FileName) -ine $ExpectedExecutable -or
            $identity.StartTime.ToUniversalTime().ToString('o') -cne $ExpectedStartedUtc) { throw 'DIAGNOSTIC_PROCESS_IDENTITY_MISMATCH' }
        if ($ExpectedWindowHandle -ne 0 -and $identity.MainWindowHandle.ToInt64() -ne $ExpectedWindowHandle) {
            throw 'DIAGNOSTIC_ORIGINAL_WINDOW_CHANGED'
        }
        if ($Handle -ne 0) {
            $owner = [uint32]0
            [void][DwmWindowProbe]::GetWindowThreadProcessId([IntPtr]$Handle,[ref]$owner)
            if ($owner -ne $TargetProcessId) { throw 'DIAGNOSTIC_WINDOW_OWNER_CHANGED' }
        }
        $report.identity_checked_utc = [DateTime]::UtcNow.ToString('o')
    } finally { $identity.Dispose() }
}
function Read-Node($Element, [int]$Index, [int]$Parent, [int]$Depth) {
    $observation = [ordered]@{ utc=[DateTime]::UtcNow.ToString('o'); index=$Index; parent_index=$Parent; depth=$Depth }
    try {
        $observation.runtime_id = @($Element.GetRuntimeId())
        $current = $Element.Current
        $observation.pid = $current.ProcessId
        $observation.name = $current.Name
        $observation.type = $current.ControlType.ProgrammaticName
        $observation.offscreen = $current.IsOffscreen
    } catch { $observation.error = $_.Exception.Message }
    $observation.completed_utc = [DateTime]::UtcNow.ToString('o')
    return $observation
}
# Cooperative limits do not interrupt blocked provider calls. The caller's existing
# 15-second child-process deadline is the hard bound; flush before every UIA call.
function Capture-Raw($Root, $Record) {
    $raw = [ordered]@{ started_utc=[DateTime]::UtcNow.ToString('o'); max_nodes=128; max_depth=32;
        budget_seconds=8; nodes=@(); truncation=@(); phase='start'; completed=$false }
    $Record.raw = $raw
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $walker = [Windows.Automation.TreeWalker]::RawViewWalker
    $pending = [Collections.Generic.Stack[object]]::new()
    $pending.Push(@{ element=$Root; parent=-1; depth=0 })
    $seen = [Collections.Generic.HashSet[string]]::new()
    try {
        while ($pending.Count -gt 0) {
            if ($raw.nodes.Count -ge 128) { $raw.truncation += 'node-limit'; break }
            if ($watch.Elapsed.TotalSeconds -ge 8) { $raw.truncation += 'time-limit'; break }
            Assert-Identity $Record.handle
            $item = $pending.Pop()
            $raw.phase = 'read-node'; $raw.observation_utc = [DateTime]::UtcNow.ToString('o'); Flush-Report
            $node = Read-Node $item.element $raw.nodes.Count $item.parent $item.depth
            $raw.nodes += $node
            Flush-Report
            Assert-Identity $Record.handle
            if ($node.Contains('error')) { $raw.truncation += "node-read-error:$($node.index)"; continue }
            if ($node.pid -ne $TargetProcessId) { throw 'DIAGNOSTIC_RAW_OWNER_MISMATCH' }
            $key = $node.runtime_id -join ','
            if (-not $seen.Add($key)) { $raw.truncation += "repeated-runtime-id:$key"; continue }
            # Stack sibling first so the child is visited next (depth-first order).
            if ($item.depth -gt 0) {
                if ($watch.Elapsed.TotalSeconds -ge 8) { $raw.truncation += 'time-limit'; break }
                $raw.phase = 'next-sibling'; $raw.observation_utc = [DateTime]::UtcNow.ToString('o'); Flush-Report
                $sibling = $walker.GetNextSibling($item.element)
                Assert-Identity $Record.handle
                if ($null -ne $sibling) { $pending.Push(@{ element=$sibling; parent=$item.parent; depth=$item.depth }) }
            }
            if ($item.depth -ge 32) { $raw.truncation += "depth-limit:$($node.index)"; continue }
            if ($raw.nodes.Count -ge 128) { $raw.truncation += 'node-limit'; break }
            if ($watch.Elapsed.TotalSeconds -ge 8) { $raw.truncation += 'time-limit'; break }
            $raw.phase = 'first-child'; $raw.observation_utc = [DateTime]::UtcNow.ToString('o'); Flush-Report
            $first = $walker.GetFirstChild($item.element)
            Assert-Identity $Record.handle
            if ($null -ne $first) { $pending.Push(@{ element=$first; parent=$node.index; depth=($item.depth + 1) }) }
        }
        $raw.completed = $raw.truncation.Count -eq 0
        $raw.phase = 'complete'
    } catch { $raw.error = $_.Exception.Message }
    finally { $raw.elapsed_seconds = $watch.Elapsed.TotalSeconds; $raw.finished_utc=[DateTime]::UtcNow.ToString('o'); Flush-Report }
}
try {
    Assert-Identity
    $report.expected_window_handle = $ExpectedWindowHandle
    $target = Get-Process -Id $TargetProcessId
    if ($target.HasExited -or [IO.Path]::GetFullPath($target.MainModule.FileName) -ine $ExpectedExecutable -or
        $target.StartTime.ToUniversalTime().ToString('o') -cne $ExpectedStartedUtc) { throw 'DIAGNOSTIC_PROCESS_IDENTITY_MISMATCH' }
    $report.pid = $target.Id
    $report.main_window_handle = $target.MainWindowHandle.ToInt64()
    $report.phase = 'native-windows'
    $handles = @([DwmWindowProbe]::Windows([uint32]$TargetProcessId))
    if ($handles.Count -gt 16) { throw 'DIAGNOSTIC_WINDOW_LIMIT' }
    foreach ($handle in $handles) {
        $owner = [uint32]0
        $thread = [DwmWindowProbe]::GetWindowThreadProcessId($handle,[ref]$owner)
        if ($owner -ne $TargetProcessId) { throw 'DIAGNOSTIC_WINDOW_OWNER_CHANGED' }
        Assert-Identity ($handle.ToInt64())
        $record = [ordered]@{utc=[DateTime]::UtcNow.ToString('o'); handle=$handle.ToInt64(); pid=$owner; thread=$thread;
            class=[DwmWindowProbe]::ClassName($handle); visible=[DwmWindowProbe]::IsWindowVisible($handle);
            hung=[DwmWindowProbe]::IsHungAppWindow($handle); responds=[DwmWindowProbe]::Responds($handle)}
        $report.windows += $record
        Flush-Report
    }
    $report.phase = 'fresh-client-uia'
    foreach ($record in $report.windows) {
        if (-not $record.visible) { continue }
        if ($ExpectedWindowHandle -ne 0 -and $record.handle -ne $ExpectedWindowHandle) { continue }
        Assert-Identity $record.handle
        $record.uia_phase = 'from-handle'
        $record.uia_started_utc = [DateTime]::UtcNow.ToString('o')
        Flush-Report
        $root = [Windows.Automation.AutomationElement]::FromHandle([IntPtr]$record.handle)
        if ($root.Current.ProcessId -ne $TargetProcessId) { throw 'DIAGNOSTIC_UIA_OWNER_MISMATCH' }
        $record.root_name = $root.Current.Name
        $record.root_type = $root.Current.ControlType.ProgrammaticName
        Assert-Identity $record.handle
        if ($ExpectedWindowHandle -ne 0) { Capture-Raw $root $record }
        else { $record.raw_skipped = 'original-window-handle-unavailable' }
        Assert-Identity $record.handle
        $record.uia_phase = 'descendants'
        $record.findall_started_utc = [DateTime]::UtcNow.ToString('o')
        Flush-Report
        $nodes = $root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)
        Assert-Identity $record.handle
        $record.findall_finished_utc = [DateTime]::UtcNow.ToString('o')
        $record.descendant_count = $nodes.Count
        $record.findall_nodes = @()
        for ($i = 0; $i -lt [Math]::Min($nodes.Count,128); $i++) {
            $record.uia_phase = "findall-node-$i"; Flush-Report
            $record.findall_nodes += (Read-Node $nodes[$i] $i -1 -1)
            Assert-Identity $record.handle
            Flush-Report
        }
        $record.findall_truncated = $nodes.Count -gt 128
        $record.findall_node_errors = @($record.findall_nodes | Where-Object { $_.Contains('error') }).Count
        if ($record.Contains('raw')) {
            $rawIds = @($record.raw.nodes | Where-Object { $_.Contains('runtime_id') -and $_.depth -gt 0 } | ForEach-Object { $_.runtime_id -join ',' })
            $findIds = @($record.findall_nodes | Where-Object { $_.Contains('runtime_id') } | ForEach-Object { $_.runtime_id -join ',' })
            $record.comparison = [ordered]@{ utc=[DateTime]::UtcNow.ToString('o'); sequential_not_atomic=$true;
                raw_only_runtime_ids=@($rawIds | Where-Object { $_ -notin $findIds });
                findall_only_runtime_ids=@($findIds | Where-Object { $_ -notin $rawIds });
                partial=($record.findall_truncated -or -not $record.raw.completed -or $record.findall_node_errors -gt 0) }
        }
        $record.names = @($record.findall_nodes | Select-Object -First 80 | ForEach-Object { if ($_.Contains('name')) { $_.name } })
        $record.uia_phase = 'complete'
        Flush-Report
    }
    $report.phase = 'complete'
} catch { $report.error = $_.Exception.Message }
finally { Flush-Report }
