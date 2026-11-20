# Section 03 — Input & Latency.
Add-FluxTweak @{
    Id = 'input.mouseaccel'; SectionNo = 3; Order = 17
    Name = 'Mouse acceleration & smoothing OFF'
    Short = 'One-to-one movement. No Windows pointer curve.'
    Detail = 'Clears the Windows mouse acceleration thresholds and turns off enhanced pointer precision, both in the registry and in the running session. The pointer no longer covers different distances for the same hand movement.'
    Why = 'Consistent aim comes from consistent input. Acceleration makes muscle memory unreliable.'
    Changes = @('MouseSpeed / Threshold1 / Threshold2 → 0', 'SPI_SETMOUSE → 0,0,0', 'No sensitivity change')
    Risk = 'Safe'; Restart = $false
    Apply = {
        $native = [FluxNative]::GetMouse()
        Set-FluxBackupData -TweakId 'input.mouseaccel' -Name 'native' -Value @{ Threshold1 = $native[0]; Threshold2 = $native[1]; Acceleration = $native[2] } -OnlyIfMissing
        Set-FluxReg -TweakId 'input.mouseaccel' -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -Value '0' -Kind String
        Set-FluxReg -TweakId 'input.mouseaccel' -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold1' -Value '0' -Kind String
        Set-FluxReg -TweakId 'input.mouseaccel' -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold2' -Value '0' -Kind String
        [void][FluxNative]::SetMouse(0, 0, 0)
        [FluxNative]::BroadcastSettingChange()
    }
    Revert = {
        Restore-FluxRegistryRecords 'input.mouseaccel'
        $native = Get-FluxBackupData -TweakId 'input.mouseaccel' -Name 'native' -Default @{ Threshold1 = 6; Threshold2 = 10; Acceleration = 1 }
        [void][FluxNative]::SetMouse([int]$native.Threshold1, [int]$native.Threshold2, [int]$native.Acceleration)
        [FluxNative]::BroadcastSettingChange()
    }
    Detect = {
        $native = [FluxNative]::GetMouse()
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseSpeed'; Value = '0' },
            @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseThreshold1'; Value = '0' },
            @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseThreshold2'; Value = '0' }
        )) -and ($native[0] -eq 0) -and ($native[1] -eq 0) -and ($native[2] -eq 0)
    }
}

Add-FluxTweak @{
    Id = 'input.trails'; SectionNo = 3; Order = 18
    Name = 'Mouse trails OFF'
    Short = 'No ghost cursor behind the pointer.'
    Detail = 'Disables mouse pointer trails in the registry and in the live session. Trails add drawing work behind the cursor and make precise aim harder to read.'
    Why = 'A clean pointer is easier to track and costs the compositor less.'
    Changes = @('MouseTrails → 0', 'SPI_SETMOUSETRAILS → 0')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxBackupData -TweakId 'input.trails' -Name 'native' -Value ([FluxNative]::GetMouseTrails()) -OnlyIfMissing
        Set-FluxReg -TweakId 'input.trails' -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseTrails' -Value '0' -Kind String
        [void][FluxNative]::SetMouseTrails(0)
        [FluxNative]::BroadcastSettingChange()
    }
    Revert = {
        Restore-FluxRegistryRecords 'input.trails'
        $trails = [int](Get-FluxBackupData -TweakId 'input.trails' -Name 'native' -Default 0)
        [void][FluxNative]::SetMouseTrails($trails)
        [FluxNative]::BroadcastSettingChange()
    }
    Detect = {
        ([FluxNative]::GetMouseTrails() -le 0) -and
        (Test-FluxRegistryValueList @(@{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseTrails'; Value = '0' }))
    }
}

Add-FluxTweak @{
    Id = 'input.keyboard'; SectionNo = 3; Order = 19
    Name = 'Keyboard delay minimum'
    Short = 'No key-repeat delay. Fastest repeat rate.'
    Detail = 'Sets the keyboard repeat delay to the shortest value and the repeat rate to the fastest value. Useful for strafing, editing and menu navigation.'
    Why = 'Keeps held keys responsive and removes an artificial pause before repeat begins.'
    Changes = @('KeyboardDelay → 0', 'KeyboardSpeed → 31')
    Risk = 'Safe'; Restart = $false
    Apply = {
        $delay = [FluxNative]::GetKeyboardDelay()
        $speed = [FluxNative]::GetKeyboardSpeed()
        Set-FluxBackupData -TweakId 'input.keyboard' -Name 'native' -Value @{ Delay = $delay; Speed = $speed } -OnlyIfMissing
        Set-FluxReg -TweakId 'input.keyboard' -Path 'HKCU:\Control Panel\Keyboard' -Name 'KeyboardDelay' -Value '0' -Kind String
        Set-FluxReg -TweakId 'input.keyboard' -Path 'HKCU:\Control Panel\Keyboard' -Name 'KeyboardSpeed' -Value '31' -Kind String
        [void][FluxNative]::SetKeyboardDelay(0)
        [void][FluxNative]::SetKeyboardSpeed(31)
        [FluxNative]::BroadcastSettingChange()
    }
    Revert = {
        Restore-FluxRegistryRecords 'input.keyboard'
        $native = Get-FluxBackupData -TweakId 'input.keyboard' -Name 'native' -Default @{ Delay = 1; Speed = 20 }
        if ([int]$native.Delay -ge 0) { [void][FluxNative]::SetKeyboardDelay([int]$native.Delay) }
        if ([int]$native.Speed -ge 0) { [void][FluxNative]::SetKeyboardSpeed([int]$native.Speed) }
        [FluxNative]::BroadcastSettingChange()
    }
    Detect = {
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'KeyboardDelay'; Value = '0' },
            @{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'KeyboardSpeed'; Value = '31' }
        ))
    }
}

Add-FluxTweak @{
    Id = 'input.accessibility'; SectionNo = 3; Order = 20
    Name = 'Sticky & Filter keys OFF'
    Short = 'Remove accessibility key delays and shortcuts.'
    Detail = 'Turns off Sticky Keys and Filter Keys, both of which can change how key presses are interpreted. The original accessibility flags are saved and restored exactly.'
    Why = 'Filter Keys ignores brief or repeated key presses; Sticky Keys changes modifier behaviour. Neither belongs in a competitive game.'
    Changes = @('Sticky Keys → off', 'Filter Keys → off', 'Hotkey activation → off')
    Risk = 'Caution'; Restart = $false
    Apply = {
        $sticky = [FluxNative]::GetStickyFlags()
        $filter = [FluxNative]::GetFilterFlags()
        Set-FluxBackupData -TweakId 'input.accessibility' -Name 'native' -Value @{ Sticky = $sticky; Filter = $filter } -OnlyIfMissing
        [void][FluxNative]::SetStickyFlags([uint32]($sticky -band (-bnot 5)))
        [void][FluxNative]::SetFilterFlags([uint32]($filter -band (-bnot 5)))
        [FluxNative]::BroadcastSettingChange()
    }
    Revert = {
        $native = Get-FluxBackupData -TweakId 'input.accessibility' -Name 'native' -Default $null
        if ($native) {
            [void][FluxNative]::SetStickyFlags([uint32]$native.Sticky)
            [void][FluxNative]::SetFilterFlags([uint32]$native.Filter)
            [FluxNative]::BroadcastSettingChange()
        }
    }
    Detect = {
        (([FluxNative]::GetStickyFlags() -band 1) -eq 0) -and (([FluxNative]::GetFilterFlags() -band 1) -eq 0)
    }
}

Add-FluxTweak @{
    Id = 'input.guide'; SectionNo = 3; Order = 21; Kind = 'guide'
    Name = 'Raw input & Reflex in Fortnite'
    Short = 'Three in-game settings Flux cannot change for you.'
    Detail = 'Fortnite controls its own raw input and NVIDIA Reflex settings. Flux disables Windows pointer processing; finish the job inside the game.'
    Why = 'Raw input bypasses the Windows cursor path. Reflex reduces the render queue and input latency when the GPU is busy.'
    Changes = @()
    Risk = 'Safe'
    Guide = @(
        'Open Fortnite → Settings → Mouse and Keyboard.',
        'Turn Raw Mouse Input ON.',
        'Open Settings → Video → Advanced (or Display) and set NVIDIA Reflex to On + Boost if available.',
        'Turn VSync OFF. Cap frames slightly below your refresh rate if you see tearing.',
        'Use Windowed Fullscreen if you want the F6 crosshair to appear over the game.'
    )
}

# Section 04 — Background & Services.
Add-FluxTweak @{
    Id = 'services.telemetry'; SectionNo = 4; Order = 22
    Name = 'Telemetry OFF'
    Short = 'Stop DiagTrack and Windows telemetry collection.'
    Detail = 'Stops and disables the Connected User Experiences and Telemetry service and the WAP push service, then sets the telemetry policy to the lowest level.'
    Why = 'Telemetry consumes background CPU, disk and network time. Off means less noise.'
    Changes = @('DiagTrack → disabled', 'dmwappushservice → disabled', 'AllowTelemetry → 0')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxServiceDisabled -TweakId 'services.telemetry' -Name 'DiagTrack'
        Set-FluxServiceDisabled -TweakId 'services.telemetry' -Name 'dmwappushservice'
        Set-FluxReg -TweakId 'services.telemetry' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'services.telemetry' -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Name 'AllowTelemetry' -Value 0 -Kind DWord
    }
    Revert = {
        Restore-FluxServices 'services.telemetry'
        Restore-FluxRegistryRecords 'services.telemetry'
    }
    Detect = {
        $found = $false
        foreach ($name in @('DiagTrack', 'dmwappushservice')) {
            $record = Get-FluxServiceRecord $name
            if (-not $record) { continue }
            $found = $true
            if ($record.Start -ne 4) { return $false }
        }
        $found
    }
}

Add-FluxTweak @{
    Id = 'services.sysmain'; SectionNo = 4; Order = 23
    Name = 'SysMain & Prefetch OFF'
    Short = 'No Superfetch, no prefetch tracing.'
    Detail = 'Disables the SysMain (Superfetch) service and Windows prefetching. Memory management stops preloading frequently used data in the background.'
    Why = 'On an SSD, prefetch provides little benefit while using CPU, disk and RAM. Off gives Fortnite a cleaner machine.'
    Changes = @('SysMain → disabled', 'EnablePrefetcher → 0', 'EnableSuperfetch → 0')
    Risk = 'Caution'; Restart = $true
    Apply = {
        Set-FluxServiceDisabled -TweakId 'services.sysmain' -Name 'SysMain'
        Set-FluxReg -TweakId 'services.sysmain' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' -Name 'EnablePrefetcher' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'services.sysmain' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' -Name 'EnableSuperfetch' -Value 0 -Kind DWord
    }
    Revert = {
        Restore-FluxServices 'services.sysmain'
        Restore-FluxRegistryRecords 'services.sysmain'
    }
    Detect = {
        (Test-FluxServiceDisabledList @('SysMain')) -and
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'; Name = 'EnablePrefetcher'; Value = 0 },
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'; Name = 'EnableSuperfetch'; Value = 0 }
        ))
    }
}

Add-FluxTweak @{
    Id = 'services.search'; SectionNo = 4; Order = 24
    Name = 'Search indexing OFF'
    Short = 'Stop the Windows Search indexer.'
    Detail = 'Stops and disables the Windows Search service. The indexer stops reading files in the background; classic file-content search and some Outlook search features become slower or unavailable.'
    Why = 'The indexer can touch the disk during a match. Off removes that disk activity.'
    Changes = @('WSearch → disabled')
    Risk = 'Caution'; Restart = $false
    Apply = { Set-FluxServiceDisabled -TweakId 'services.search' -Name 'WSearch' }
    Revert = { Restore-FluxServices 'services.search' }
    Detect = { Test-FluxServiceDisabledList @('WSearch') }
}

Add-FluxTweak @{
    Id = 'services.onedrive'; SectionNo = 4; Order = 25
    Name = 'OneDrive sync OFF'
    Short = 'Stop OneDrive syncing in the background.'
    Detail = 'Stops OneDrive and blocks OneDrive file sync with the Windows policy. Your files stay on disk, but changes stop syncing until you restore this tweak.'
    Why = 'Sync can use network, disk and CPU whenever a file changes. Off during play.'
    Changes = @('OneDrive process → stopped', 'DisableFileSyncNGSC → 1', 'Startup entry → removed')
    Risk = 'Caution'; Restart = $false
    Apply = {
        $exe = $null
        $proc = Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc) { try { $exe = $proc.Path } catch { } }
        if (-not $exe) {
            $candidate = Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\OneDrive.exe'
            if (Test-Path -LiteralPath $candidate) { $exe = $candidate }
        }
        $runValue = Get-FluxRegValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -Default $null
        if (-not $exe -and -not $runValue) { throw 'OneDrive is not installed for this user.' }
        Set-FluxBackupData -TweakId 'services.onedrive' -Name 'exe' -Value $exe -OnlyIfMissing
        Backup-FluxRegistryValue -TweakId 'services.onedrive' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive'
        Set-FluxReg -TweakId 'services.onedrive' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name 'DisableFileSyncNGSC' -Value 1 -Kind DWord
        Remove-FluxRegValue -TweakId 'services.onedrive' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive'
        Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Revert = {
        Restore-FluxRegistryRecords 'services.onedrive'
        $exe = [string](Get-FluxBackupData -TweakId 'services.onedrive' -Name 'exe' -Default '')
        if ($exe -and (Test-Path -LiteralPath $exe)) { Start-Process -FilePath $exe -ErrorAction SilentlyContinue }
    }
    Detect = {
        $installed = (Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue) -or
            (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\OneDrive.exe')) -or
            (Get-FluxRegValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -Default $null)
        if (-not $installed) { return 'NA' }
        $policy = Get-FluxRegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name 'DisableFileSyncNGSC' -Default 0
        ([int]$policy -eq 1) -and -not (Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue)
    }
}

Add-FluxTweak @{
    Id = 'services.remote'; SectionNo = 4; Order = 26
    Name = 'Remote Desktop & Assistance OFF'
    Short = 'Close the remote access doors.'
    Detail = 'Disables the Remote Desktop services, denies Remote Desktop connections and turns off Remote Assistance. Local use of the PC is unaffected.'
    Why = 'Remote services listen for connections and can wake the system. Off is a smaller attack surface and less background work.'
    Changes = @('TermService / UmRdpService → disabled', 'fDenyTSConnections → 1', 'Remote Assistance → off')
    Risk = 'Caution'; Restart = $false
    Apply = {
        Set-FluxServiceDisabled -TweakId 'services.remote' -Name 'TermService'
        Set-FluxServiceDisabled -TweakId 'services.remote' -Name 'UmRdpService'
        Set-FluxReg -TweakId 'services.remote' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 1 -Kind DWord
        Set-FluxReg -TweakId 'services.remote' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fAllowToGetHelp' -Value 0 -Kind DWord
    }
    Revert = {
        Restore-FluxServices 'services.remote'
        Restore-FluxRegistryRecords 'services.remote'
    }
    Detect = {
        (Test-FluxServiceDisabledList @('TermService')) -and
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'; Name = 'fDenyTSConnections'; Value = 1 },
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'; Name = 'fAllowToGetHelp'; Value = 0 }
        ))
    }
}

Add-FluxTweak @{
    Id = 'services.errors'; SectionNo = 4; Order = 27
    Name = 'Error reporting OFF'
    Short = 'No WER crash reports in the background.'
    Detail = 'Disables the Windows Error Reporting service and its reporting switch. Apps still crash, but Windows no longer collects and uploads a report.'
    Why = 'Crash reporting can spike disk and CPU right after a game closes. Off keeps the exit clean.'
    Changes = @('WerSvc → disabled', 'WER Disabled → 1')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxServiceDisabled -TweakId 'services.errors' -Name 'WerSvc'
        Set-FluxReg -TweakId 'services.errors' -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 1 -Kind DWord
    }
    Revert = {
        Restore-FluxServices 'services.errors'
        Restore-FluxRegistryRecords 'services.errors'
    }
    Detect = {
        (Test-FluxServiceDisabledList @('WerSvc')) -and
        (Test-FluxRegistryValueList @(@{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1 }))
    }
}

Add-FluxTweak @{
    Id = 'services.store'; SectionNo = 4; Order = 28
    Name = 'Store auto-updates OFF'
    Short = 'Apps update when you say so.'
    Detail = 'Turns off automatic Microsoft Store app updates for this user and machine. You can still update apps manually from the Store.'
    Why = 'Store updates can download and install in the background while you play. Manual updates keep the machine predictable.'
    Changes = @('WindowsStore AutoDownload → 2', 'User Store AutoDownload → 2')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'services.store' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Name 'AutoDownload' -Value 2 -Kind DWord
        Set-FluxReg -TweakId 'services.store' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate' -Name 'AutoDownload' -Value 2 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'services.store' }
    Detect = {
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'; Name = 'AutoDownload'; Value = 2 },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate'; Name = 'AutoDownload'; Value = 2 }
        ))
    }
}

Add-FluxTweak @{
    Id = 'services.deliveryopt'; SectionNo = 4; Order = 29
    Name = 'Windows Update P2P OFF'
    Short = 'Updates download only from Microsoft.'
    Detail = 'Sets Delivery Optimization to HTTP-only. Windows Update stops using other PCs on your network or the internet as a peer source.'
    Why = 'Peer-to-peer update traffic can consume upload bandwidth while you play. Downloads still work normally.'
    Changes = @('DODownloadMode → 0 (HTTP only)')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'services.deliveryopt' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode' -Value 0 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'services.deliveryopt' }
    Detect = { [int](Get-FluxRegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode' -Default 1) -eq 0 }
}

Add-FluxTweak @{
    Id = 'services.wifisense'; SectionNo = 4; Order = 30
    Name = 'Wi-Fi Sense & hotspot auto-connect OFF'
    Short = 'Stop suggested open hotspots and OEM auto-connect.'
    Detail = 'Disables Windows automatically connecting to suggested open hotspots and OEM-provisioned Wi-Fi networks. Networks you added yourself still auto-connect.'
    Why = 'A machine that silently joins unknown open networks is both a privacy and a latency risk.'
    Changes = @('AutoConnectAllowedOEM → 0', 'AllowAutoConnectToWiFiSenseHotspots → 0')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'services.wifisense' -Path 'HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config' -Name 'AutoConnectAllowedOEM' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'services.wifisense' -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots' -Name 'Value' -Value 0 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'services.wifisense' }
    Detect = {
        Test-FluxRegistryValueList @(
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config'; Name = 'AutoConnectAllowedOEM'; Value = 0 },
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots'; Name = 'Value'; Value = 0 }
        )
    }
}
