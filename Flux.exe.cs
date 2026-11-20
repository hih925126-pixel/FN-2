// Flux.exe — lightweight double-click launcher.
// It runs Flux.ps1 with the built-in Windows PowerShell 5.1 and hides its own console window.
using System;
using System.Diagnostics;
using System.IO;

class FluxLauncher
{
    static int Main(string[] args)
    {
        string baseDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
        string script = Path.Combine(baseDir, "Flux.ps1");
        if (!File.Exists(script))
        {
            Console.Error.WriteLine("Flux.ps1 is missing next to Flux.exe.");
            return 2;
        }

        string powershell = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            "WindowsPowerShell", "v1.0", "powershell.exe");
        if (!File.Exists(powershell))
        {
            powershell = "powershell.exe";
        }

        string extraArgs = "";
        if (args.Length > 0)
        {
            extraArgs = " " + string.Join(" ", args);
        }

        var info = new ProcessStartInfo
        {
            FileName = powershell,
            CreateNoWindow = true,
            UseShellExecute = false,
            Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File \"" + script + "\"" + extraArgs,
        };

        var proc = Process.Start(info);
        proc.WaitForExit();
        return proc.ExitCode;
    }
}
