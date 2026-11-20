param(
    [int]$WaitMinutes = 480,
    [int]$PollSeconds = 2
)

# Flux.GameAgent.ps1 — detached watcher owned by Flux.
# Waits for Fortnite, raises its priority to High with every logical core,
# then reopens the background apps Flux closed once the game exits.

$ErrorActionPreference = 'SilentlyContinue'
$appData = Join-Path $env:APPDATA 'Flux'
if (-not (Test-Path -LiteralPath $appData)) { New-Item -ItemType Directory -Path $appData -Force | Out-Null }
$statusPath = Join-Path $appData 'agent-status.json'
$pidPath = Join-Path $appData 'agent.pid'
$restorePath = Join-Path $appData 'restore-apps.json'
$logDir = Join-Path $appData 'logs'
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logPath = Join-Path $logDir ('agent-' + (Get-Date -Format 'yyyyMMdd') + '.log')

function Write-AgentLog {
    param([string]$Message)
    try {
        Add-Content -LiteralPath $logPath -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding UTF8
    }
    catch { }
}

function Write-AgentStatus {
    param([string]$State, [string]$Message, [bool]$Running = $true, [int]$GamePid = 0)
    $payload = @{
        state = $State
        running = $Running
        message = $Message
        gamePid = $GamePid
        agentPid = $PID
        updated = (Get-Date).ToString('o')
    }
    try { Set-Content -LiteralPath $statusPath -Value ($payload | ConvertTo-Json -Compress) -Encoding UTF8 } catch { }
}

function Get-FortniteProcesses {
    $names = @(
        'FortniteClient-Win64-Shipping',
        'FortniteClient-Win64-Shipping_EAC',
        'FortniteClient-Win64-Shipping_BE',
        'FortniteClient-Win64-Shipping_EAC_EOS'
    )
    return @(Get-Process -Name $names -ErrorAction SilentlyContinue)
}

function Set-GamePriority {
    param($Process)
    $changes = @()
    try {
        if ($Process.PriorityClass -ne [System.Diagnostics.ProcessPriorityClass]::High) {
            $Process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
            $changes += 'High priority'
        }
    }
    catch {
        $changes += 'priority blocked'
    }
    try {
        $cores = [Environment]::ProcessorCount
        if ($cores -gt 0 -and $cores -lt 64) {
            $mask = ([long]1 -shl $cores) - 1
            if ([long]$Process.ProcessorAffinity -ne $mask) {
                $Process.ProcessorAffinity = [IntPtr]$mask
                $changes += "all $cores cores"
            }
        }
        elseif ($cores -ge 64) {
            $changes += "$cores cores (affinity left to Windows)"
        }
    }
    catch {
        $changes += 'affinity blocked'
    }
    return @($changes)
}

function Restore-BackgroundApps {
    if (-not (Test-Path -LiteralPath $restorePath)) { return @() }
    $restored = @()
    try {
        $apps = @(Get-Content -LiteralPath $restorePath -Raw -Encoding UTF8 | ConvertFrom-Json)
        foreach ($app in $apps) {
            if (-not $app.ProcessName) { continue }
            $running = @(Get-Process -Name ([string]$app.ProcessName) -ErrorAction SilentlyContinue)
            if ($running.Count -gt 0) { continue }
            if ($app.Path -and (Test-Path -LiteralPath ([string]$app.Path))) {
                try {
                    Start-Process -FilePath ([string]$app.Path) -ErrorAction Stop
                    $restored += [string]$app.Name
                    Write-AgentLog "Reopened $($app.Name)"
                }
                catch { Write-AgentLog "Could not reopen $($app.Name): $($_.Exception.Message)" }
            }
        }
        Remove-Item -LiteralPath $restorePath -Force -ErrorAction SilentlyContinue
    }
    catch { Write-AgentLog "Restore list could not be read: $($_.Exception.Message)" }
    return @($restored)
}

function Stop-AgentSelf {
    param([string]$State, [string]$Message)
    Write-AgentStatus -State $State -Message $Message -Running $false
    try {
        $owner = ''
        if (Test-Path -LiteralPath $pidPath) { $owner = (Get-Content -LiteralPath $pidPath -Raw -ErrorAction SilentlyContinue).Trim() }
        if ($owner -eq [string]$PID) { Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue }
    }
    catch { }
    Write-AgentLog "Agent exiting: $Message"
}

if ($PollSeconds -lt 1) { $PollSeconds = 1 }
if ($WaitMinutes -lt 1) { $WaitMinutes = 480 }

try { Set-Content -LiteralPath $pidPath -Value $PID -Encoding ASCII } catch { }
Write-AgentLog "Agent started (pid $PID, watch $WaitMinutes minutes)."
Write-AgentStatus -State 'waiting' -Message 'Waiting for Fortnite'

$deadline = (Get-Date).AddMinutes($WaitMinutes)
$seenGame = $false
$lastSeen = [datetime]::MinValue
$gamePid = 0
$lastState = ''
$lastStatusWrite = [datetime]::MinValue
$lastApply = [datetime]::MinValue
$missingPolls = 0

while ($true) {
    if (-not $seenGame -and (Get-Date) -gt $deadline) { break }

    $procs = @(Get-FortniteProcesses)
    if ($procs.Count -gt 0) {
        $seenGame = $true
        $lastSeen = Get-Date
        $missingPolls = 0
        $target = $procs | Sort-Object WorkingSet64 -Descending | Select-Object -First 1
        $gamePid = [int]$target.Id

        if (((Get-Date) - $lastApply).TotalSeconds -ge 10 -or $lastState -ne 'game') {
            $changes = @(Set-GamePriority $target)
            $lastApply = Get-Date
            $message = if ($changes.Count -gt 0) { "Fortnite guarded: $($changes -join ', ')." } else { 'Fortnite is running. Priority and affinity already set.' }
            if ($lastState -ne 'game' -or ((Get-Date) - $lastStatusWrite).TotalSeconds -ge 30) {
                Write-AgentStatus -State 'game' -Message $message -GamePid $gamePid
                $lastStatusWrite = Get-Date
                Write-AgentLog $message
            }
            $lastState = 'game'
        }
    }
    else {
        if ($seenGame) {
            $missingPolls++
            if ($missingPolls -ge 3) { break }
        }
        else {
            if ($lastState -ne 'waiting' -or ((Get-Date) - $lastStatusWrite).TotalSeconds -ge 60) {
                Write-AgentStatus -State 'waiting' -Message 'Waiting for Fortnite'
                $lastStatusWrite = Get-Date
                $lastState = 'waiting'
            }
        }
    }

    Start-Sleep -Seconds $PollSeconds
}

if ($seenGame) {
    Write-AgentStatus -State 'restoring' -Message 'Fortnite closed. Reopening background apps.' -GamePid $gamePid
    $restored = @(Restore-BackgroundApps)
    if ($restored.Count -gt 0) {
        Stop-AgentSelf -State 'finished' -Message ("Fortnite closed. Reopened: " + ($restored -join ', ') + '.')
    }
    else {
        Stop-AgentSelf -State 'finished' -Message 'Fortnite closed. No apps were waiting to reopen.'
    }
}
else {
    Stop-AgentSelf -State 'finished' -Message 'Watch window ended before Fortnite started. Any closed apps can be reopened from Flux.'
}
