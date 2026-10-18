#requires -Version 7.0
# Read-only failure diagnosis, launched in a separate bounded cloud process.
param(
    [Parameter(Mandatory)][int]$TargetProcessId,
    [Parameter(Mandatory)][string]$ExpectedExecutable,
    [Parameter(Mandatory)][string]$ExpectedStartedUtc,
    [Parameter(Mandatory)][string]$OutputFile
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
function Flush-Report { $report | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $OutputFile -Encoding utf8 }
Flush-Report
try {
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
        $record = [ordered]@{handle=$handle.ToInt64(); pid=$owner; thread=$thread;
            class=[DwmWindowProbe]::ClassName($handle); visible=[DwmWindowProbe]::IsWindowVisible($handle);
            hung=[DwmWindowProbe]::IsHungAppWindow($handle); responds=[DwmWindowProbe]::Responds($handle)}
        $report.windows += $record
        Flush-Report
    }
    $report.phase = 'fresh-client-uia'
    foreach ($record in $report.windows) {
        if (-not $record.visible) { continue }
        $record.uia_phase = 'from-handle'
        Flush-Report
        $root = [Windows.Automation.AutomationElement]::FromHandle([IntPtr]$record.handle)
        if ($root.Current.ProcessId -ne $TargetProcessId) { throw 'DIAGNOSTIC_UIA_OWNER_MISMATCH' }
        $record.root_name = $root.Current.Name
        $record.root_type = $root.Current.ControlType.ProgrammaticName
        $record.uia_phase = 'descendants'
        Flush-Report
        $nodes = $root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)
        $record.descendant_count = $nodes.Count
        $record.names = @($nodes | Select-Object -First 80 | ForEach-Object { $_.Current.Name })
        $record.uia_phase = 'complete'
        Flush-Report
    }
    $report.phase = 'complete'
} catch { $report.error = $_.Exception.Message }
finally { Flush-Report }
