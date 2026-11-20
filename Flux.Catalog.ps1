# Flux.Catalog.ps1 — the tweak catalog and shared check helpers.

$script:FluxTweaks = @()
$script:FluxSections = @(
    @{ No = 1;  Title = 'Power & CPU';           Blurb = 'Clocks up, power saving off, no mid-game dips.' },
    @{ No = 2;  Title = 'Game Settings';         Blurb = 'Windows gaming stack on; capture and noise off.' },
    @{ No = 3;  Title = 'Input & Latency';       Blurb = 'Pointer processing removed. The shortest path from hand to game.' },
    @{ No = 4;  Title = 'Background & Services'; Blurb = 'Fewer services, less telemetry, more headroom.' },
    @{ No = 5;  Title = 'Visual';                Blurb = 'Best performance. Every frame goes to the game.' },
    @{ No = 6;  Title = 'GPU';                   Blurb = 'Driver-level performance, applied where it counts.' },
    @{ No = 7;  Title = 'Memory & Storage';      Blurb = 'RAM, pagefile and SSD housekeeping.' },
    @{ No = 8;  Title = 'Network';               Blurb = 'Faster DNS, lower overhead, fewer surprises.' },
    @{ No = 9;  Title = 'Crosshair';             Blurb = 'A clean overlay. F6 hides it. Studio tunes it.' },
    @{ No = 10; Title = 'Processes';             Blurb = 'Fortnite gets priority. Your apps come back after.' },
    @{ No = 11; Title = 'Safety';                Blurb = 'Backups before changes. One click to undo.' }
)

$script:PwrProcessor = '54533251-82be-4824-96c1-47b60b740d00'
$script:PwrSubProcessor = '54533251-82be-4824-96c1-47b60b740d00'
$script:PwrMinState = '893dee8e-2bef-41e0-89c6-b55d0929964c'
$script:PwrMaxState = 'bc5038f7-23e0-4960-96da-33abaf5935ec'
$script:PwrIdleDisable = '5d76a2ca-e8c0-402f-a133-2158492d58ad'
$script:PwrCoreParking = '0cc5b647-c1df-4637-891a-dec35c318583'
$script:PwrBoostMode = 'be337238-0d82-4146-a960-4f3749d470c7'
$script:PwrPcieSub = '501a4d13-42af-4429-9fd1-a8218c268e20'
$script:PwrPcieAspm = 'ee12f906-d277-404b-b6da-e5fa1a576df5'
$script:PwrUsbSub = '2a737441-1930-4402-8d77-b2bebba308a3'
$script:PwrUsbSuspend = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
$script:PwrDiskSub = '0012ee47-9041-4b5d-9b77-535fba8b1442'
$script:PwrDiskTimeout = '6738e2c4-e8a5-4a42-b16a-e040e769756e'
$script:PwrSleepSub = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
$script:PwrStandby = '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'
$script:PwrHibernate = '9d7815a6-7ee4-497e-8888-515a05f02364'
$script:PwrWifiSub = '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1'
$script:PwrWifiPowerSave = '12bbebe6-58d6-4636-95bb-3217ef867c1a'

function Add-FluxTweak {
    param([hashtable]$Tweak)
    if (-not $Tweak['Kind']) { $Tweak['Kind'] = 'toggle' }
    if (-not $Tweak['Risk']) { $Tweak['Risk'] = 'Safe' }
    if (-not $Tweak['Short']) { $Tweak['Short'] = $Tweak['Name'] }
    if (-not $Tweak['Why']) { $Tweak['Why'] = $Tweak['Detail'] }
    if (-not $Tweak['Changes']) { $Tweak['Changes'] = @() }
    if (-not $Tweak['Order']) { $Tweak['Order'] = (100 + $script:FluxTweaks.Count) }
    $script:FluxTweaks += [pscustomobject]$Tweak
}

function Test-FluxRegistryValueList {
    param([object[]]$Checks)
    foreach ($check in $Checks) {
        $sentinel = New-Object object
        $value = Get-FluxRegValue -Path $check.Path -Name $check.Name -Default $sentinel
        if ([object]::ReferenceEquals($value, $sentinel)) { return $false }
        if ($null -eq $check.Value) {
            if ($null -ne $value) { return $false }
        }
        elseif ("$value" -ne "$($check.Value)") { return $false }
    }
    return $true
}

function Test-FluxServiceDisabledList {
    param([string[]]$Names)
    $found = $false
    foreach ($name in $Names) {
        $record = Get-FluxServiceRecord $name
        if (-not $record) { continue }
        $found = $true
        if ($record.Start -ne 4) { return $false }
    }
    return $found
}

function Test-FluxPowerValue {
    param([string]$Sub, [string]$Setting, [int]$AC, [int]$DC = -1)
    $scheme = [FluxPower]::GetActiveScheme()
    if ($scheme -eq [Guid]::Empty) { return $false }
    $acValue = [FluxPower]::ReadAC($scheme, [Guid]$Sub, [Guid]$Setting)
    $dcValue = [FluxPower]::ReadDC($scheme, [Guid]$Sub, [Guid]$Setting)
    if ($acValue -ne $AC) { return $false }
    if ($DC -ge 0 -and $dcValue -ge 0 -and $dcValue -ne $DC) { return $false }
    return $true
}

function Test-FluxFortniteRunning {
    return [bool](Get-Process -Name 'FortniteClient-Win64-Shipping', 'FortniteClient-Win64-Shipping_EAC', 'FortniteLauncher' -ErrorAction SilentlyContinue)
}

function Test-FluxNetworkFiles {
    return $true
}

# ── Section 01 — Power & CPU ────────────────────────────────────────────────
Add-FluxTweak @{
    Id = 'power.plan'; SectionNo = 1; Order = 1
    Name = 'High Performance power plan'
    Short = 'Keep Windows on the High Performance plan.'
    Detail = 'Switches Windows to the built-in High Performance power plan. This stops the OS from throttling the CPU aggressively during play and removes the balanced plan''s latency-oriented power saving.'
    Why = 'A balanced plan can lower clocks between frames, which shows up as micro-stutter. High Performance keeps the CPU ready.'
    Changes = @('Active power scheme → High Performance', 'Previous scheme recorded for one-click restore')
    Risk = 'Safe'; Restart = $false
    Apply = {
        $scheme = [FluxPower]::GetActiveScheme()
        Set-FluxBackupData -TweakId 'power.plan' -Name 'previousScheme' -Value $scheme.ToString() -OnlyIfMissing
        $high = [Guid]'8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
        if (-not [FluxPower]::SetActiveScheme($high)) { throw 'Could not activate the High Performance power plan.' }
        Write-FluxLog 'High Performance plan active.' 'power.plan'
    }
    Revert = {
        $previous = [string](Get-FluxBackupData -TweakId 'power.plan' -Name 'previousScheme' -Default '')
        if ($previous) { [void][FluxPower]::SetActiveScheme([Guid]$previous) }
    }
    Detect = {
        ([FluxPower]::GetActiveScheme()) -eq [Guid]'8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    }
}

Add-FluxTweak @{
    Id = 'power.cpu100'; SectionNo = 1; Order = 2
    Name = 'Pin CPU to 100%'
    Short = 'Minimum and maximum processor state at 100%.'
    Detail = 'Sets both the minimum and maximum processor state to 100% on AC and battery. The CPU stops down-clocking and stays at its configured top frequency.'
    Why = 'Removes frequency ramp-up delay in the first frames after a lull. On laptops this increases heat and battery drain.'
    Changes = @('Minimum processor state → 100%', 'Maximum processor state → 100%')
    Risk = 'Caution'; Restart = $false
    Apply = {
        Set-FluxPowerValue -TweakId 'power.cpu100' -Sub $script:PwrProcessor -Setting $script:PwrMinState -AC 100 -DC 100 -Label 'Minimum processor state'
        Set-FluxPowerValue -TweakId 'power.cpu100' -Sub $script:PwrProcessor -Setting $script:PwrMaxState -AC 100 -DC 100 -Label 'Maximum processor state'
    }
    Revert = { Restore-FluxPowerValues 'power.cpu100' }
    Detect = {
        (Test-FluxPowerValue -Sub $script:PwrProcessor -Setting $script:PwrMinState -AC 100) -and
        (Test-FluxPowerValue -Sub $script:PwrProcessor -Setting $script:PwrMaxState -AC 100)
    }
}

Add-FluxTweak @{
    Id = 'power.devices'; SectionNo = 1; Order = 3
    Name = 'Disable PCIe, USB & HDD power saving'
    Short = 'Stop devices from being put to sleep.'
    Detail = 'Turns off PCI Express link state power management, USB selective suspend and hard-disk idle timeouts. Devices stay awake instead of taking a few milliseconds to wake up.'
    Why = 'Device wake-up latency is a common source of stutter when input, storage or the GPU drops into a low-power state.'
    Changes = @('PCIe ASPM → Off', 'USB selective suspend → Disabled', 'Hard disk sleep → Never')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxPowerValue -TweakId 'power.devices' -Sub $script:PwrPcieSub -Setting $script:PwrPcieAspm -AC 0 -DC 0 -Label 'PCIe ASPM'
        Set-FluxPowerValue -TweakId 'power.devices' -Sub $script:PwrUsbSub -Setting $script:PwrUsbSuspend -AC 0 -DC 0 -Label 'USB selective suspend'
        Set-FluxPowerValue -TweakId 'power.devices' -Sub $script:PwrDiskSub -Setting $script:PwrDiskTimeout -AC 0 -DC 0 -Label 'Hard disk sleep'
    }
    Revert = { Restore-FluxPowerValues 'power.devices' }
    Detect = {
        (Test-FluxPowerValue -Sub $script:PwrPcieSub -Setting $script:PwrPcieAspm -AC 0) -and
        (Test-FluxPowerValue -Sub $script:PwrUsbSub -Setting $script:PwrUsbSuspend -AC 0) -and
        (Test-FluxPowerValue -Sub $script:PwrDiskSub -Setting $script:PwrDiskTimeout -AC 0)
    }
}

Add-FluxTweak @{
    Id = 'power.sleep'; SectionNo = 1; Order = 4
    Name = 'Disable sleep & hibernation'
    Short = 'No PC sleep, no hibernate file.'
    Detail = 'Sets the sleep and hibernate timeouts to Never and turns off the hibernation feature. The machine will not drop into a low-power state during a download, a match or a long session.'
    Why = 'Sleep and hibernation can interrupt downloads, game installs and long uptimes. Turning them off also removes hiberfil.sys and frees disk space.'
    Changes = @('Sleep → Never', 'Hibernate → Never', 'powercfg /hibernate off')
    Risk = 'Caution'; Restart = $false
    Apply = {
        $hb = Get-FluxRegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled' -Default 1
        Set-FluxBackupData -TweakId 'power.sleep' -Name 'hibernateWasEnabled' -Value ([bool]($hb -eq 1)) -OnlyIfMissing
        Backup-FluxRegistryValue -TweakId 'power.sleep' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled'
        Set-FluxPowerValue -TweakId 'power.sleep' -Sub $script:PwrSleepSub -Setting $script:PwrStandby -AC 0 -DC 0 -Label 'Sleep timeout'
        Set-FluxPowerValue -TweakId 'power.sleep' -Sub $script:PwrSleepSub -Setting $script:PwrHibernate -AC 0 -DC 0 -Label 'Hibernate timeout'
        powercfg.exe /hibernate off | Out-Null
    }
    Revert = {
        Restore-FluxPowerValues 'power.sleep'
        Restore-FluxRegistryRecords 'power.sleep'
        if ([bool](Get-FluxBackupData -TweakId 'power.sleep' -Name 'hibernateWasEnabled' -Default $false)) {
            powercfg.exe /hibernate on | Out-Null
        }
    }
    Detect = {
        $hibernate = Get-FluxRegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled' -Default 0
        (Test-FluxPowerValue -Sub $script:PwrSleepSub -Setting $script:PwrStandby -AC 0) -and
        (Test-FluxPowerValue -Sub $script:PwrSleepSub -Setting $script:PwrHibernate -AC 0) -and
        ([int]$hibernate -eq 0)
    }
}

Add-FluxTweak @{
    Id = 'power.faststartup'; SectionNo = 1; Order = 5
    Name = 'Disable Fast Startup'
    Short = 'Full shutdown every time.'
    Detail = 'Fast Startup keeps a hibernated kernel session between shutdowns. Flux turns it off so every shutdown is a real shutdown, with clean drivers and devices.'
    Why = 'Fast Startup can preserve stale drivers and cause weird device or overlay behaviour. Off is the safer state for a tuned gaming PC.'
    Changes = @('HiberbootEnabled → 0', 'Takes effect on the next shutdown')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'power.faststartup' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'power.faststartup' }
    Detect = { [int](Get-FluxRegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Default 1) -eq 0 }
}

Add-FluxTweak @{
    Id = 'power.cstates'; SectionNo = 1; Order = 6
    Name = 'C-states off, core parking off, boost Aggressive'
    Short = 'No idle sleep states. No parked cores. Aggressive boost.'
    Detail = 'Disables processor idle states (C-states), keeps every core unparked, and sets the processor performance boost mode to Aggressive. This is the most aggressive power tweak in Flux.'
    Why = 'C-state exit and core unparking cost time. Keeping every core hot removes that latency, at the cost of more idle power and heat.'
    Changes = @('Processor idle disable → disabled (C-states off)', 'Core parking minimum cores → 100%', 'Performance boost mode → Aggressive')
    Risk = 'Risky'; Restart = $false
    Apply = {
        Set-FluxPowerValue -TweakId 'power.cstates' -Sub $script:PwrProcessor -Setting $script:PwrIdleDisable -AC 1 -DC 1 -Label 'Processor idle disable'
        Set-FluxPowerValue -TweakId 'power.cstates' -Sub $script:PwrProcessor -Setting $script:PwrCoreParking -AC 100 -DC 100 -Label 'Core parking minimum cores'
        Set-FluxPowerValue -TweakId 'power.cstates' -Sub $script:PwrProcessor -Setting $script:PwrBoostMode -AC 2 -DC 2 -Label 'Processor boost mode'
    }
    Revert = { Restore-FluxPowerValues 'power.cstates' }
    Detect = {
        (Test-FluxPowerValue -Sub $script:PwrProcessor -Setting $script:PwrIdleDisable -AC 1) -and
        (Test-FluxPowerValue -Sub $script:PwrProcessor -Setting $script:PwrCoreParking -AC 100) -and
        (Test-FluxPowerValue -Sub $script:PwrProcessor -Setting $script:PwrBoostMode -AC 2)
    }
}
