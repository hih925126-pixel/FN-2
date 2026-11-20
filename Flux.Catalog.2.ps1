# Section 02 — Game Settings.
Add-FluxTweak @{
    Id = 'game.mode'; SectionNo = 2; Order = 7
    Name = 'Game Mode ON'
    Short = 'Windows prioritises the game.'
    Detail = 'Enables Windows Game Mode and allows it to turn on automatically. Game Mode reduces background activity and gives the foreground game priority for CPU and GPU resources.'
    Why = 'Fortnite gets the resources first, without you closing everything manually.'
    Changes = @('AutoGameModeEnabled → 1', 'AllowAutoGameMode → 1')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'game.mode' -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1 -Kind DWord
        Set-FluxReg -TweakId 'game.mode' -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AllowAutoGameMode' -Value 1 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'game.mode' }
    Detect = {
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'AutoGameModeEnabled'; Value = 1 },
            @{ Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'AllowAutoGameMode'; Value = 1 }
        ))
    }
}

Add-FluxTweak @{
    Id = 'game.hags'; SectionNo = 2; Order = 8
    Name = 'Hardware-accelerated GPU scheduling'
    Short = 'HAGS on. Restart required.'
    Detail = 'Sets HwSchMode to enabled, which lets the GPU manage its own command queues and video memory. Support depends on your GPU and driver.'
    Why = 'On supported systems HAGS can reduce CPU overhead and frame pacing jitter. On some older drivers it can cause stutter, so test it.'
    Changes = @('HwSchMode → 2 (enabled)', 'Reboot required to take effect')
    Risk = 'Caution'; Restart = $true
    Apply = {
        Set-FluxReg -TweakId 'game.hags' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Value 2 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'game.hags' }
    Detect = { [int](Get-FluxRegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Default 1) -eq 2 }
}

Add-FluxTweak @{
    Id = 'game.windowed'; SectionNo = 2; Order = 9
    Name = 'Optimizations for windowed games'
    Short = 'Flip-model presentation for borderless play.'
    Detail = 'Enables the Windows 11 flip-model upgrade for DX10/DX11 windowed and borderless games. It lowers frame latency and allows features such as Auto HDR and VRR in borderless mode.'
    Why = 'Most Fortnite players run borderless fullscreen. This is the Windows feature that makes borderless feel closer to exclusive fullscreen.'
    Changes = @('DirectXUserGlobalSettings → SwapEffectUpgradeEnable=1', 'Restart the game (not the PC)')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxDxGlobalSetting -TweakId 'game.windowed' -Key 'SwapEffectUpgradeEnable' -Value '1'
    }
    Revert = { Restore-FluxRegistryRecords 'game.windowed' }
    Detect = { (Get-FluxDxGlobalSetting -Key 'SwapEffectUpgradeEnable') -eq '1' }
}

Add-FluxTweak @{
    Id = 'game.gamebar'; SectionNo = 2; Order = 10
    Name = 'Game Bar & Xbox overlay OFF'
    Short = 'No Game Bar pop-ups or overlay hooks.'
    Detail = 'Disables the Game Bar startup panel, the Game Bar overlay entry point and the Windows Game DVR policy that allows Xbox capture. Your game no longer has another overlay hooking it.'
    Why = 'Overlays cost a little CPU/GPU and can conflict with anti-cheat or frame pacing. Off is cleaner for competitive play.'
    Changes = @('Game Bar startup panel → off', 'Xbox Game DVR policy → disabled', 'App capture → off')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'game.gamebar' -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'ShowStartupPanel' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'game.gamebar' -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'UseNexusForGameBarEnabled' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'game.gamebar' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'game.gamebar' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'game.gamebar' }
    Detect = {
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'ShowStartupPanel'; Value = 0 },
            @{ Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'UseNexusForGameBarEnabled'; Value = 0 },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled'; Value = 0 },
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR'; Value = 0 }
        ))
    }
}

Add-FluxTweak @{
    Id = 'game.dvr'; SectionNo = 2; Order = 11
    Name = 'Background recording OFF'
    Short = 'Game DVR stops recording in the background.'
    Detail = 'Turns off Game DVR background recording and forces fullscreen-exclusive friendly presentation behaviour. This removes the constant capture buffer from the GPU path.'
    Why = 'Background recording polls the GPU and encodes continuously. With it off, Fortnite gets the whole GPU.'
    Changes = @('GameDVR_Enabled → 0', 'FSE behaviour → exclusive friendly', 'Historical capture → off')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'game.dvr' -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'game.dvr' -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_FSEBehaviorMode' -Value 2 -Kind DWord
        Set-FluxReg -TweakId 'game.dvr' -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_HonorUserFSEBehaviorMode' -Value 1 -Kind DWord
        Set-FluxReg -TweakId 'game.dvr' -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_DXGIHonorFSEWindowsCompatible' -Value 1 -Kind DWord
        Set-FluxReg -TweakId 'game.dvr' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'HistoricalCaptureEnabled' -Value 0 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'game.dvr' }
    Detect = {
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Value = 0 },
            @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_FSEBehaviorMode'; Value = 2 },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'HistoricalCaptureEnabled'; Value = 0 }
        ))
    }
}

Add-FluxTweak @{
    Id = 'game.notifications'; SectionNo = 2; Order = 12
    Name = 'Notifications OFF'
    Short = 'No toast pop-ups over the game.'
    Detail = 'Mutes Windows toast notifications at the shell level. Game invites, browser alerts and system tips will not slide over your screen during a fight.'
    Why = 'A notification can steal focus, drop frames and, at minimum, break concentration.'
    Changes = @('Toast notifications → 0', 'Global toast setting → 0')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'game.notifications' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' -Name 'ToastEnabled' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'game.notifications' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings' -Name 'NOC_GLOBAL_SETTING_TOASTS_ENABLED' -Value 0 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'game.notifications' }
    Detect = {
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'; Name = 'ToastEnabled'; Value = 0 },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'; Name = 'NOC_GLOBAL_SETTING_TOASTS_ENABLED'; Value = 0 }
        ))
    }
}

Add-FluxTweak @{
    Id = 'game.autohdr'; SectionNo = 2; Order = 13
    Name = 'Auto HDR OFF'
    Short = 'No tone-mapped SDR-to-HDR pass.'
    Detail = 'Turns off Auto HDR system-wide for DirectX games. Auto HDR can add a small presentation cost and change colours in competitive games.'
    Why = 'Consistent SDR colours and one less GPU pass. Turn this on if you use native HDR, not Auto HDR.'
    Changes = @('DirectXUserGlobalSettings → AutoHDREnable=0')
    Risk = 'Safe'; Restart = $false
    Apply = { Set-FluxDxGlobalSetting -TweakId 'game.autohdr' -Key 'AutoHDREnable' -Value '0' }
    Revert = { Restore-FluxRegistryRecords 'game.autohdr' }
    Detect = { (Get-FluxDxGlobalSetting -Key 'AutoHDREnable') -eq '0' }
}

Add-FluxTweak @{
    Id = 'game.tips'; SectionNo = 2; Order = 14
    Name = 'Tips & suggestions OFF'
    Short = 'No Windows tips, welcome screens or app suggestions.'
    Detail = 'Disables Windows suggestion surfaces: tips, soft landing pages, suggested apps and the rotating lock-screen overlay.'
    Why = 'Less background content delivery and fewer interruptions.'
    Changes = @('Subscribed tips → off', 'App suggestions → off', 'Lock screen tips → off')
    Risk = 'Safe'; Restart = $false
    Apply = {
        $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        foreach ($name in @('SubscribedContent-338389Enabled', 'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled', 'SilentInstalledAppsEnabled', 'RotatingLockScreenOverlayEnabled')) {
            Set-FluxReg -TweakId 'game.tips' -Path $path -Name $name -Value 0 -Kind DWord
        }
    }
    Revert = { Restore-FluxRegistryRecords 'game.tips' }
    Detect = {
        $checks = @()
        foreach ($name in @('SubscribedContent-338389Enabled', 'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled', 'SilentInstalledAppsEnabled', 'RotatingLockScreenOverlayEnabled')) {
            $checks += @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = $name; Value = 0 }
        }
        Test-FluxRegistryValueList $checks
    }
}

Add-FluxTweak @{
    Id = 'game.backgroundapps'; SectionNo = 2; Order = 15
    Name = 'Background apps OFF'
    Short = 'Desktop apps lose background execution rights.'
    Detail = 'Disables background execution for packaged and Store apps for the current user. Apps only run while they are open.'
    Why = 'Stops invisible updaters and chat apps from waking the CPU during a match. Some apps will stop showing notifications until opened.'
    Changes = @('Global background access → disabled', 'Search background apps → off')
    Risk = 'Caution'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'game.backgroundapps' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1 -Kind DWord
        Set-FluxReg -TweakId 'game.backgroundapps' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'BackgroundAppGlobalToggle' -Value 0 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'game.backgroundapps' }
    Detect = {
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Name = 'GlobalUserDisabled'; Value = 1 },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BackgroundAppGlobalToggle'; Value = 0 }
        ))
    }
}

Add-FluxTweak @{
    Id = 'game.widgets'; SectionNo = 2; Order = 16
    Name = 'Widgets & news OFF'
    Short = 'Remove the widget feed and taskbar button.'
    Detail = 'Uses the Windows policy to disable the Widgets/News and Interests feed and hides the taskbar widget button for the current user.'
    Why = 'No feed process quietly refreshing content, no accidental hover while playing.'
    Changes = @('AllowNewsAndInterests → 0', 'TaskbarDa → 0')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'game.widgets' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'game.widgets' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa' -Value 0 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'game.widgets' }
    Detect = {
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0 },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarDa'; Value = 0 }
        ))
    }
}
