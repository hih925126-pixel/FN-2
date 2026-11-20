# Flux.ps1 — entry point. Elevates, keeps a single instance and starts the WPF shell.

param(
    [switch]$NoElevate,
    [switch]$NoMutex
)

$ErrorActionPreference = 'Stop'
$script:FluxRoot = $PSScriptRoot
$launchLogDir = Join-Path $env:APPDATA 'Flux\logs'
$launchLog = Join-Path $launchLogDir ('launch-' + (Get-Date -Format 'yyyyMMdd') + '.log')

function Write-LaunchLog {
    param([string]$Message)
    try {
        if (-not (Test-Path -LiteralPath $launchLogDir)) { New-Item -ItemType Directory -Path $launchLogDir -Force | Out-Null }
        Add-Content -LiteralPath $launchLog -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding UTF8
    }
    catch { }
}

function Show-LaunchError {
    param([string]$Message)
    Write-LaunchLog "FATAL: $Message"
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            "$Message`n`nDetails were written to:`n$launchLog",
            'Flux could not start',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    catch { }
}

function Test-IsElevated {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch { return $false }
}

Write-LaunchLog "Launcher starting. PowerShell $($PSVersionTable.PSVersion), elevated=$(Test-IsElevated), STA=$([System.Threading.Thread]::CurrentThread.ApartmentState)."

try {
    Set-Location -LiteralPath $PSScriptRoot
}
catch {
    Show-LaunchError 'Flux could not enter its own folder.'
    exit 1
}

# Windows PowerShell starts STA in the console host, but relaunch if not so WPF stays happy.
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne [System.Threading.ApartmentState]::STA) {
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $PSCommandPath))
    if ($NoElevate) { $arguments += '-NoElevate' }
    if ($NoMutex) { $arguments += '-NoMutex' }
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList ($arguments -join ' ') | Out-Null
        exit 0
    }
    catch {
        Show-LaunchError "Flux needs Windows PowerShell in STA mode: $($_.Exception.Message)"
        exit 1
    }
}

if (-not $NoElevate -and -not (Test-IsElevated)) {
    Write-LaunchLog 'Not elevated. Relaunching with RunAs.'
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $PSCommandPath))
    if ($NoMutex) { $arguments += '-NoMutex' }
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList ($arguments -join ' ') -Verb RunAs | Out-Null
        exit 0
    }
    catch {
        Write-LaunchLog "Elevation was cancelled or failed: $($_.Exception.Message)"
        exit 0
    }
}

$mutex = $null
$ownsMutex = $false
if (-not $NoMutex) {
    try {
        $mutex = New-Object System.Threading.Mutex($false, 'Local\FluxPerformanceTuning')
        $ownsMutex = $mutex.WaitOne(0, $false)
        if (-not $ownsMutex) {
            Write-LaunchLog 'Another Flux instance is already running.'
            try {
                Add-Type -AssemblyName System.Windows.Forms
                [System.Windows.Forms.MessageBox]::Show(
                    'Flux is already open. Close the existing window before starting another copy.',
                    'Flux is already running',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            }
            catch { }
            exit 0
        }
    }
    catch {
        Write-LaunchLog "Single-instance check failed, continuing: $($_.Exception.Message)"
        $ownsMutex = $false
    }
}

try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

    $src = Join-Path $PSScriptRoot 'src'
    $files = @(
        'Flux.Native.ps1',
        'Flux.Engine.ps1',
        'Flux.Runtime.ps1',
        'Flux.Catalog.ps1',
        'Flux.Catalog.2.ps1',
        'Flux.Catalog.3.ps1',
        'Flux.Catalog.4.ps1',
        'Flux.Catalog.5.ps1',
        'Flux.UI.Core.ps1',
        'Flux.UI.Sections.ps1',
        'Flux.UI.Operations.ps1',
        'Flux.UI.Crosshair.ps1',
        'Flux.UI.Processes.ps1'
    )

    foreach ($file in $files) {
        $path = Join-Path $src $file
        if (-not (Test-Path -LiteralPath $path)) { throw "Missing source file: $file" }
        Write-LaunchLog "Loading $file"
        . $path
    }

    Initialize-FluxContext -Root $PSScriptRoot
    Write-FluxLog "Flux UI opened. Elevated=$(Test-IsElevated)."
    Start-FluxApp
    Write-FluxLog 'Flux UI closed.'
}
catch {
    $message = $_.Exception.Message
    $position = ''
    try {
        if ($_.InvocationInfo) { $position = " at line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())" }
    }
    catch { }
    Show-LaunchError "$message$position"
    exit 1
}
finally {
    if ($mutex) {
        try { if ($ownsMutex) { $mutex.ReleaseMutex() } } catch { }
        try { $mutex.Dispose() } catch { }
    }
}
