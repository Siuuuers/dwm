param([Parameter(Mandatory = $true)][int]$GodotProcessId)
$ErrorActionPreference = 'Stop'

# Test-only independent physical bounds. Do not use Godot's adjusted size report.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class NativeWindowBounds {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int Size; public RECT Monitor, Work; public uint Flags; }
    public delegate bool EnumProc(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, IntPtr data);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr window, uint command);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr window, out RECT rect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr window, ref POINT point);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
    public static long[] Read(int processId) {
        if (SetThreadDpiAwarenessContext(new IntPtr(-4)) == IntPtr.Zero) throw new Exception("DPI context unavailable");
        var windows = new List<IntPtr>();
        EnumWindows((window, data) => {
            uint owner; GetWindowThreadProcessId(window, out owner);
            if (owner == processId && IsWindowVisible(window) && GetWindow(window, 4) == IntPtr.Zero) windows.Add(window);
            return true;
        }, IntPtr.Zero);
        if (windows.Count != 1) throw new Exception("Expected one visible unowned window for Godot PID; found " + windows.Count);
        IntPtr handle = windows[0];
        RECT rect; POINT origin = new POINT();
        if (!GetClientRect(handle, out rect) || !ClientToScreen(handle, ref origin)) throw new Exception("Client bounds unavailable");
        MONITORINFO monitor = new MONITORINFO(); monitor.Size = Marshal.SizeOf(typeof(MONITORINFO));
        if (!GetMonitorInfo(MonitorFromWindow(handle, 2), ref monitor)) throw new Exception("Monitor work area unavailable");
        return new long[] { handle.ToInt64(), origin.X + rect.Left, origin.Y + rect.Top,
            rect.Right - rect.Left, rect.Bottom - rect.Top, monitor.Work.Left, monitor.Work.Top,
            monitor.Work.Right - monitor.Work.Left, monitor.Work.Bottom - monitor.Work.Top };
    }
}
'@
$bounds = [NativeWindowBounds]::Read($GodotProcessId)
[ordered]@{
    process_id = $GodotProcessId
    window_handle = $bounds[0]
    client = @{ position = @($bounds[1], $bounds[2]); size = @($bounds[3], $bounds[4]) }
    work_area = @{ position = @($bounds[5], $bounds[6]); size = @($bounds[7], $bounds[8]) }
} | ConvertTo-Json -Depth 3 -Compress
