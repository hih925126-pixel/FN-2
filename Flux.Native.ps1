# Flux.Native.ps1 — P/Invoke helpers for power settings, UI effects, memory and window styles.
if (-not ('FluxPower' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class FluxPower
{
    [DllImport("powrprof.dll")]
    private static extern uint PowerGetActiveScheme(IntPtr userRoot, out IntPtr activeGuid);
    [DllImport("powrprof.dll")]
    private static extern uint PowerSetActiveScheme(IntPtr userRoot, ref Guid schemeGuid);
    [DllImport("powrprof.dll")]
    private static extern uint PowerReadACValueIndex(IntPtr root, ref Guid scheme, ref Guid sub, ref Guid setting, out uint value);
    [DllImport("powrprof.dll")]
    private static extern uint PowerReadDCValueIndex(IntPtr root, ref Guid scheme, ref Guid sub, ref Guid setting, out uint value);
    [DllImport("powrprof.dll")]
    private static extern uint PowerWriteACValueIndex(IntPtr root, ref Guid scheme, ref Guid sub, ref Guid setting, uint value);
    [DllImport("powrprof.dll")]
    private static extern uint PowerWriteDCValueIndex(IntPtr root, ref Guid scheme, ref Guid sub, ref Guid setting, uint value);
    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr mem);

    public static Guid GetActiveScheme()
    {
        IntPtr ptr;
        uint result = PowerGetActiveScheme(IntPtr.Zero, out ptr);
        if (result != 0 || ptr == IntPtr.Zero) return Guid.Empty;
        Guid guid = (Guid)Marshal.PtrToStructure(ptr, typeof(Guid));
        LocalFree(ptr);
        return guid;
    }

    public static bool SetActiveScheme(Guid scheme)
    {
        return PowerSetActiveScheme(IntPtr.Zero, ref scheme) == 0;
    }

    public static int ReadAC(Guid scheme, Guid sub, Guid setting)
    {
        uint value;
        return PowerReadACValueIndex(IntPtr.Zero, ref scheme, ref sub, ref setting, out value) == 0 ? (int)value : -1;
    }

    public static int ReadDC(Guid scheme, Guid sub, Guid setting)
    {
        uint value;
        return PowerReadDCValueIndex(IntPtr.Zero, ref scheme, ref sub, ref setting, out value) == 0 ? (int)value : -1;
    }

    public static bool WriteAC(Guid scheme, Guid sub, Guid setting, uint value)
    {
        return PowerWriteACValueIndex(IntPtr.Zero, ref scheme, ref sub, ref setting, value) == 0;
    }

    public static bool WriteDC(Guid scheme, Guid sub, Guid setting, uint value)
    {
        return PowerWriteDCValueIndex(IntPtr.Zero, ref scheme, ref sub, ref setting, value) == 0;
    }

    public static bool Reapply()
    {
        Guid active = GetActiveScheme();
        if (active == Guid.Empty) return false;
        return SetActiveScheme(active);
    }
}
'@
}

if (-not ('FluxNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class FluxNative
{
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SystemParametersInfo(uint action, uint param, IntPtr data, uint winIni);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam, string lParam, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")]
    private static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int index);
    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int index, IntPtr value);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint modifiers, uint vk);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    [DllImport("psapi.dll", SetLastError = true)]
    private static extern bool EmptyWorkingSet(IntPtr process);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    private const uint SPIF_UPDATE = 0x01;
    private const uint SPIF_SEND = 0x02;
    private const uint SPIF_BOTH = SPIF_UPDATE | SPIF_SEND;

    private const uint SPI_SETMOUSE = 0x0004;
    private const uint SPI_GETMOUSE = 0x0003;
    private const uint SPI_GETMOUSETRAILS = 0x005E;
    private const uint SPI_SETMOUSETRAILS = 0x005D;
    private const uint SPI_SETKEYBOARDDELAY = 0x0017;
    private const uint SPI_SETKEYBOARDSPEED = 0x000B;
    private const uint SPI_GETKEYBOARDDELAY = 0x0016;
    private const uint SPI_GETKEYBOARDSPEED = 0x000A;
    private const uint SPI_GETDROPSHADOW = 0x1028;
    private const uint SPI_SETDROPSHADOW = 0x1027;
    private const uint SPI_GETUIEFFECTS = 0x103E;
    private const uint SPI_SETUIEFFECTS = 0x103F;
    private const uint SPI_GETCLIENTAREAANIMATION = 0x1042;
    private const uint SPI_SETCLIENTAREAANIMATION = 0x1043;
    private const uint SPI_GETMENUANIMATION = 0x1002;
    private const uint SPI_SETMENUANIMATION = 0x1003;
    private const uint SPI_GETSELECTIONFADE = 0x1012;
    private const uint SPI_SETSELECTIONFADE = 0x1013;
    private const uint SPI_GETTOOLTIPANIMATION = 0x1014;
    private const uint SPI_SETTOOLTIPANIMATION = 0x1015;
    private const uint SPI_GETTOOLTIPFADE = 0x1016;
    private const uint SPI_SETTOOLTIPFADE = 0x1017;
    private const uint SPI_GETSTICKYKEYS = 0x003A;
    private const uint SPI_SETSTICKYKEYS = 0x003B;
    private const uint SPI_GETFILTERKEYS = 0x0032;
    private const uint SPI_SETFILTERKEYS = 0x0033;

    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_TRANSPARENT = 0x00000020;
    private const int WS_EX_TOOLWINDOW = 0x00000080;
    private const int WS_EX_LAYERED = 0x00080000;
    private const int WS_EX_NOACTIVATE = 0x08000000;
    private const uint PROCESS_SET_QUOTA = 0x0100;
    private const uint PROCESS_QUERY_INFORMATION = 0x0400;

    public static int[] GetMouse()
    {
        IntPtr mem = Marshal.AllocHGlobal(12);
        try
        {
            if (!SystemParametersInfo(SPI_GETMOUSE, 0, mem, 0)) return new int[] { 0, 0, 0 };
            int[] values = new int[3];
            Marshal.Copy(mem, values, 0, 3);
            return values;
        }
        finally { Marshal.FreeHGlobal(mem); }
    }

    public static bool SetMouse(int threshold1, int threshold2, int acceleration)
    {
        IntPtr mem = Marshal.AllocHGlobal(12);
        try
        {
            int[] values = new int[] { threshold1, threshold2, acceleration };
            Marshal.Copy(values, 0, mem, 3);
            return SystemParametersInfo(SPI_SETMOUSE, 0, mem, SPIF_BOTH);
        }
        finally { Marshal.FreeHGlobal(mem); }
    }

    public static int GetMouseTrails()
    {
        IntPtr mem = Marshal.AllocHGlobal(4);
        try
        {
            Marshal.WriteInt32(mem, 0);
            if (!SystemParametersInfo(SPI_GETMOUSETRAILS, 0, mem, 0)) return 0;
            return Marshal.ReadInt32(mem);
        }
        finally { Marshal.FreeHGlobal(mem); }
    }

    public static bool SetMouseTrails(int count)
    {
        return SystemParametersInfo(SPI_SETMOUSETRAILS, (uint)Math.Max(0, count), IntPtr.Zero, SPIF_BOTH);
    }

    public static int GetKeyboardDelay()
    {
        IntPtr mem = Marshal.AllocHGlobal(4);
        try
        {
            Marshal.WriteInt32(mem, 0);
            if (!SystemParametersInfo(SPI_GETKEYBOARDDELAY, 0, mem, 0)) return -1;
            return Marshal.ReadInt32(mem);
        }
        finally { Marshal.FreeHGlobal(mem); }
    }

    public static int GetKeyboardSpeed()
    {
        IntPtr mem = Marshal.AllocHGlobal(4);
        try
        {
            Marshal.WriteInt32(mem, 0);
            if (!SystemParametersInfo(SPI_GETKEYBOARDSPEED, 0, mem, 0)) return -1;
            return Marshal.ReadInt32(mem);
        }
        finally { Marshal.FreeHGlobal(mem); }
    }

    public static bool SetKeyboardDelay(int delay)
    {
        return SystemParametersInfo(SPI_SETKEYBOARDDELAY, (uint)delay, IntPtr.Zero, SPIF_BOTH);
    }

    public static bool SetKeyboardSpeed(int speed)
    {
        return SystemParametersInfo(SPI_SETKEYBOARDSPEED, (uint)speed, IntPtr.Zero, SPIF_BOTH);
    }

    private static bool GetBool(uint action)
    {
        IntPtr mem = Marshal.AllocHGlobal(4);
        try
        {
            Marshal.WriteInt32(mem, 0);
            if (!SystemParametersInfo(action, 0, mem, 0)) return false;
            return Marshal.ReadInt32(mem) != 0;
        }
        finally { Marshal.FreeHGlobal(mem); }
    }

    private static bool SetBool(uint action, bool value)
    {
        IntPtr mem = Marshal.AllocHGlobal(4);
        try
        {
            Marshal.WriteInt32(mem, value ? 1 : 0);
            return SystemParametersInfo(action, 0, mem, SPIF_BOTH);
        }
        finally { Marshal.FreeHGlobal(mem); }
    }

    public static bool GetDropShadow() { return GetBool(SPI_GETDROPSHADOW); }
    public static bool SetDropShadow(bool value) { return SetBool(SPI_SETDROPSHADOW, value); }
    public static bool GetUIEffects() { return GetBool(SPI_GETUIEFFECTS); }
    public static bool SetUIEffects(bool value) { return SetBool(SPI_SETUIEFFECTS, value); }
    public static bool GetClientAreaAnimation() { return GetBool(SPI_GETCLIENTAREAANIMATION); }
    public static bool SetClientAreaAnimation(bool value) { return SetBool(SPI_SETCLIENTAREAANIMATION, value); }
    public static bool GetMenuAnimation() { return GetBool(SPI_GETMENUANIMATION); }
    public static bool SetMenuAnimation(bool value) { return SetBool(SPI_SETMENUANIMATION, value); }
    public static bool GetSelectionFade() { return GetBool(SPI_GETSELECTIONFADE); }
    public static bool SetSelectionFade(bool value) { return SetBool(SPI_SETSELECTIONFADE, value); }
    public static bool GetTooltipAnimation() { return GetBool(SPI_GETTOOLTIPANIMATION); }
    public static bool SetTooltipAnimation(bool value) { return SetBool(SPI_SETTOOLTIPANIMATION, value); }
    public static bool GetTooltipFade() { return GetBool(SPI_GETTOOLTIPFADE); }
    public static bool SetTooltipFade(bool value) { return SetBool(SPI_SETTOOLTIPFADE, value); }

    public static uint GetStickyFlags()
    {
        IntPtr mem = Marshal.AllocHGlobal(8);
        try
        {
            Marshal.WriteInt32(mem, 0, 8);
            Marshal.WriteInt32(mem, 4, 0);
            if (!SystemParametersInfo(SPI_GETSTICKYKEYS, 8, mem, 0)) return 0;
            return (uint)Marshal.ReadInt32(mem, 4);
        }
        finally { Marshal.FreeHGlobal(mem); }
    }

    public static bool SetStickyFlags(uint flags)
    {
        IntPtr mem = Marshal.AllocHGlobal(8);
        try
        {
            Marshal.WriteInt32(mem, 0, 8);
            Marshal.WriteInt32(mem, 4, (int)flags);
            return SystemParametersInfo(SPI_SETSTICKYKEYS, 8, mem, SPIF_BOTH);
        }
        finally { Marshal.FreeHGlobal(mem); }
    }

    public static uint GetFilterFlags()
    {
        IntPtr mem = Marshal.AllocHGlobal(24);
        try
        {
            Marshal.WriteInt32(mem, 0, 24);
            if (!SystemParametersInfo(SPI_GETFILTERKEYS, 24, mem, 0)) return 0;
            return (uint)Marshal.ReadInt32(mem, 4);
        }
        finally { Marshal.FreeHGlobal(mem); }
    }

    public static bool SetFilterFlags(uint flags)
    {
        IntPtr mem = Marshal.AllocHGlobal(24);
        try
        {
            Marshal.WriteInt32(mem, 0, 24);
            if (!SystemParametersInfo(SPI_GETFILTERKEYS, 24, mem, 0))
            {
                Marshal.WriteInt32(mem, 4, (int)flags);
                Marshal.WriteInt32(mem, 8, 0);
                Marshal.WriteInt32(mem, 12, 0);
                Marshal.WriteInt32(mem, 16, 0);
                Marshal.WriteInt32(mem, 20, 0);
            }
            Marshal.WriteInt32(mem, 4, (int)flags);
            return SystemParametersInfo(SPI_SETFILTERKEYS, 24, mem, SPIF_BOTH);
        }
        finally { Marshal.FreeHGlobal(mem); }
    }

    public static void BroadcastSettingChange()
    {
        IntPtr result;
        SendMessageTimeout((IntPtr)0xFFFF, 0x001A, IntPtr.Zero, "WindowMetrics", 0x0002, 1500, out result);
    }

    public static void MakeOverlay(IntPtr hwnd)
    {
        IntPtr style = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
        long value = style.ToInt64() | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW;
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, new IntPtr(value));
    }

    public static bool RegisterOverlayHotkey(IntPtr hwnd, int id, uint modifiers, uint key)
    {
        return RegisterHotKey(hwnd, id, modifiers, key);
    }

    public static bool UnregisterOverlayHotkey(IntPtr hwnd, int id)
    {
        return UnregisterHotKey(hwnd, id);
    }

    public static bool TrimProcess(int pid)
    {
        IntPtr handle = OpenProcess(PROCESS_SET_QUOTA | PROCESS_QUERY_INFORMATION, false, pid);
        if (handle == IntPtr.Zero) return false;
        try { return EmptyWorkingSet(handle); }
        finally { CloseHandle(handle); }
    }
}
'@
}
