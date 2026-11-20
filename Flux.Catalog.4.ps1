# Sections 05-08 — Visual, GPU, Memory & Storage, Network.
function Get-FluxWifiAdapters {
    try {
        return @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object {
            $_.Status -ne 'Disabled' -and ($_.PhysicalMediaType -match '802\.11|Wireless' -or $_.InterfaceDescription -match 'Wi-Fi|Wireless|802\.11')
        })
    }
    catch { return @() }
}

function Get-FluxPagefileTargetMb {
    try {
        $bytes = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory
        return [int]([math]::Round(($bytes / 1MB) * 1.5, 0))
    }
    catch { return 0 }
}

function Get-FluxPagingFiles {
    return @(Get-FluxRegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'PagingFiles' -Default @())
}

function Test-FluxPagefileTarget {
    $target = Get-FluxPagefileTargetMb
    if ($target -le 0) { return $false }
    foreach ($entry in (Get-FluxPagingFiles)) {
        if ("$entry" -match '^([A-Za-z]):\\pagefile\.sys\s+(\d+)\s+(\d+)') {
            if ($matches[1] -ieq $env:SystemDrive.TrimEnd(':')) {
                $initial = [int]$matches[2]
                $maximum = [int]$matches[3]
                if ([math]::Abs($initial - $target) -le 32 -and [math]::Abs($maximum - $target) -le 32) { return $true }
            }
        }
    }
    return $false
}

# Section 05 — Visual.
Add-FluxTweak @{
    Id = 'visual.effects'; SectionNo = 5; Order = 31
    Name = 'Best performance & animations OFF'
    Short = 'All visual effects off. The shell gets out of the way.'
    Detail = 'Applies the Windows "Adjust for best performance" visual profile and disables shell animations, menu fades, selection fades, tooltips and taskbar animation in the current session.'
    Why = 'Every animation is compositor work taken away from the game. Off also makes the desktop feel instant.'
    Changes = @('VisualFXSetting → 2', 'Menu / taskbar / tooltip animations → off', 'Window drag and selection fades → off')
    Risk = 'Caution'; Restart = $false
    Apply = {
        $native = @{
            UIEffects = [FluxNative]::GetUIEffects()
            ClientArea = [FluxNative]::GetClientAreaAnimation()
            Menu = [FluxNative]::GetMenuAnimation()
            Selection = [FluxNative]::GetSelectionFade()
            Tooltip = [FluxNative]::GetTooltipAnimation()
            TooltipFade = [FluxNative]::GetTooltipFade()
        }
        Set-FluxBackupData -TweakId 'visual.effects' -Name 'native' -Value $native -OnlyIfMissing
        Set-FluxReg -TweakId 'visual.effects' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2 -Kind DWord
        Set-FluxReg -TweakId 'visual.effects' -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '0' -Kind String
        Set-FluxReg -TweakId 'visual.effects' -Path 'HKCU:\Control Panel\Desktop' -Name 'DragFullWindows' -Value '0' -Kind String
        Set-FluxReg -TweakId 'visual.effects' -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name 'MinAnimate' -Value '0' -Kind String
        Set-FluxReg -TweakId 'visual.effects' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'visual.effects' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ListviewAlphaSelect' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'visual.effects' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ListviewShadow' -Value 0 -Kind DWord
        [void][FluxNative]::SetUIEffects($false)
        [void][FluxNative]::SetClientAreaAnimation($false)
        [void][FluxNative]::SetMenuAnimation($false)
        [void][FluxNative]::SetSelectionFade($false)
        [void][FluxNative]::SetTooltipAnimation($false)
        [void][FluxNative]::SetTooltipFade($false)
        [FluxNative]::BroadcastSettingChange()
    }
    Revert = {
        Restore-FluxRegistryRecords 'visual.effects'
        $native = Get-FluxBackupData -TweakId 'visual.effects' -Name 'native' -Default $null
        if ($native) {
            [void][FluxNative]::SetUIEffects([bool]$native.UIEffects)
            [void][FluxNative]::SetClientAreaAnimation([bool]$native.ClientArea)
            [void][FluxNative]::SetMenuAnimation([bool]$native.Menu)
            [void][FluxNative]::SetSelectionFade([bool]$native.Selection)
            [void][FluxNative]::SetTooltipAnimation([bool]$native.Tooltip)
            [void][FluxNative]::SetTooltipFade([bool]$native.TooltipFade)
            [FluxNative]::BroadcastSettingChange()
        }
    }
    Detect = {
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Name = 'VisualFXSetting'; Value = 2 },
            @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'MenuShowDelay'; Value = '0' },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarAnimations'; Value = 0 }
        )) -and -not ([FluxNative]::GetUIEffects())
    }
}

Add-FluxTweak @{
    Id = 'visual.transparency'; SectionNo = 5; Order = 32
    Name = 'Transparency OFF'
    Short = 'No acrylic blur behind Start, taskbar and windows.'
    Detail = 'Disables Windows transparency effects. The Start menu, taskbar and supported surfaces become opaque.'
    Why = 'Acrylic blur is a per-frame compositor cost. Removing it frees a little GPU time and looks sharper.'
    Changes = @('EnableTransparency → 0')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'visual.transparency' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'visual.transparency' }
    Detect = { [int](Get-FluxRegValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Default 1) -eq 0 }
}

Add-FluxTweak @{
    Id = 'visual.peek'; SectionNo = 5; Order = 33
    Name = 'Peek & Snap Assist OFF'
    Short = 'No thumbnail peek, no snap suggestions.'
    Detail = 'Turns off Aero Peek previews and Windows 11 Snap Assist flyouts. Snap layouts still work when you drag a window, but the suggestion UI no longer appears.'
    Why = 'Fewer hover effects and suggestion surfaces taking focus or compositor time.'
    Changes = @('DisallowPeek → 1', 'EnableAeroPeek → 0', 'Snap Assist → off')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'visual.peek' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'DisallowPeek' -Value 1 -Kind DWord
        Set-FluxReg -TweakId 'visual.peek' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'SnapAssist' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'visual.peek' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'EnableSnapAssistFlyout' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'visual.peek' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'EnableSnapBar' -Value 0 -Kind DWord
        Set-FluxReg -TweakId 'visual.peek' -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'EnableAeroPeek' -Value 0 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'visual.peek' }
    Detect = {
        Test-FluxRegistryValueList @(
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'DisallowPeek'; Value = 1 },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'SnapAssist'; Value = 0 },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'EnableAeroPeek'; Value = 0 }
        )
    }
}

Add-FluxTweak @{
    Id = 'visual.cursor'; SectionNo = 5; Order = 34
    Name = 'Cursor shadow & font smoothing OFF'
    Short = 'Flat cursor, un smoothed text.'
    Detail = 'Turns off the shadow under the mouse cursor and disables ClearType/font smoothing. The cursor is smaller to draw and text rendering uses less GPU work, but text looks rougher.'
    Why = 'Keeps the desktop in the same flat, low-cost visual mode as the rest of the performance profile.'
    Changes = @('CursorShadow → 0', 'FontSmoothing → 0', 'SPI_SETDROPSHADOW → off')
    Risk = 'Caution'; Restart = $true
    Apply = {
        Set-FluxBackupData -TweakId 'visual.cursor' -Name 'native' -Value @{ DropShadow = [FluxNative]::GetDropShadow() } -OnlyIfMissing
        Set-FluxReg -TweakId 'visual.cursor' -Path 'HKCU:\Control Panel\Cursors' -Name 'CursorShadow' -Value '0' -Kind String
        Set-FluxReg -TweakId 'visual.cursor' -Path 'HKCU:\Control Panel\Desktop' -Name 'FontSmoothing' -Value '0' -Kind String
        Set-FluxReg -TweakId 'visual.cursor' -Path 'HKCU:\Control Panel\Desktop' -Name 'FontSmoothingType' -Value 0 -Kind DWord
        [void][FluxNative]::SetDropShadow($false)
        [FluxNative]::BroadcastSettingChange()
    }
    Revert = {
        Restore-FluxRegistryRecords 'visual.cursor'
        $native = Get-FluxBackupData -TweakId 'visual.cursor' -Name 'native' -Default $null
        if ($native) { [void][FluxNative]::SetDropShadow([bool]$native.DropShadow) }
        [FluxNative]::BroadcastSettingChange()
    }
    Detect = {
        (Test-FluxRegistryValueList @(
            @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'CursorShadow'; Value = '0' },
            @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'FontSmoothing'; Value = '0' }
        )) -and -not ([FluxNative]::GetDropShadow())
    }
}

Add-FluxTweak @{
    Id = 'visual.wallpaper'; SectionNo = 5; Order = 35; Kind = 'guide'
    Name = 'Wallpaper slideshow'
    Short = 'Windows has no supported switch; set it to Picture.'
    Detail = 'Windows does not expose a public setting for stopping a wallpaper slideshow from the registry. Flux will not fake this. Change the background type to Picture once and Windows stops rotating it.'
    Why = 'A changing wallpaper forces Explorer and DWM to redraw the desktop. A static image is cheaper.'
    Changes = @()
    Risk = 'Safe'
    Guide = @(
        'Open Settings → Personalisation → Background.',
        'Set "Personalise your background" to Picture or Solid colour.',
        'Choose one image. Do not choose Slideshow or Windows Spotlight.',
        'If you use a theme, save the theme after changing the background.'
    )
    Open = 'wallpaper'
}

# Section 06 — GPU.
Add-FluxTweak @{
    Id = 'gpu.fortnitepref'; SectionNo = 6; Order = 36
    Name = 'Fortnite GPU preference → High Performance'
    Short = 'Windows sends Fortnite to the discrete GPU.'
    Detail = 'Adds a per-app graphics preference for FortniteClient-Win64-Shipping.exe and points it at the high-performance GPU. On a laptop with hybrid graphics this prevents Windows from choosing the integrated GPU.'
    Why = 'The wrong GPU means a huge performance loss before the game even starts.'
    Changes = @('DirectX UserGpuPreferences\FortniteClient-Win64-Shipping.exe → GpuPreference=2')
    Risk = 'Safe'; Restart = $false
    Apply = {
        $exe = 'FortniteClient-Win64-Shipping.exe'
        $path = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
        Backup-FluxRegistryValue -TweakId 'gpu.fortnitepref' -Path $path -Name $exe
        $raw = [string](Get-FluxRegValue -Path $path -Name $exe -Default '')
        $parts = @()
        $found = $false
        foreach ($part in ($raw -split ';')) {
            if (-not $part.Trim()) { continue }
            if ($part -match '^\s*([^=]+)\s*=\s*(.*)\s*$' -and $matches[1].Trim() -ieq 'GpuPreference') {
                $parts += 'GpuPreference=2'; $found = $true
            }
            else { $parts += $part.Trim() }
        }
        if (-not $found) { $parts += 'GpuPreference=2' }
        Set-FluxReg -TweakId 'gpu.fortnitepref' -Path $path -Name $exe -Value (($parts -join ';') + ';') -Kind String
    }
    Revert = { Restore-FluxRegistryRecords 'gpu.fortnitepref' }
    Detect = {
        $raw = [string](Get-FluxRegValue -Path 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name 'FortniteClient-Win64-Shipping.exe' -Default '')
        $raw -match '(?i)GpuPreference\s*=\s*2'
    }
}

Add-FluxTweak @{
    Id = 'gpu.nvidia'; SectionNo = 6; Order = 37; Kind = 'guide'
    Name = 'NVIDIA performance profile'
    Short = 'Guided: the driver stores these settings outside the registry.'
    Detail = 'NVIDIA stores per-game profiles in its driver database, not in a documented registry value. Flux opens the right panel; apply these settings once per driver update.'
    Why = 'Low Latency Ultra, VSync off and pre-render 1 cut the CPU-to-display queue. Max performance stops the GPU down-clocking between frames.'
    Changes = @()
    Risk = 'Safe'; Open = 'nvidia'
    Guide = @(
        'Open NVIDIA Control Panel → Manage 3D settings → Program Settings.',
        'Select Fortnite (or add FortniteClient-Win64-Shipping.exe).',
        'Power management mode → Prefer maximum performance.',
        'Low Latency Mode → Ultra. If unavailable, use in-game NVIDIA Reflex On + Boost.',
        'Vertical sync → Off. Maximum pre-rendered frames → 1.',
        'Threaded optimization → On. Shader Cache Size → Unlimited.',
        'Turn DSR Factors and FXAA off. Apply, then launch the game.'
    )
}

Add-FluxTweak @{
    Id = 'gpu.amd'; SectionNo = 6; Order = 38; Kind = 'guide'
    Name = 'AMD performance profile'
    Short = 'Guided: AMD stores these settings in Radeon Software.'
    Detail = 'AMD game profiles live in Radeon Software. Flux opens it; set the Fortnite profile once after each major driver update.'
    Why = 'Anti-Lag cuts the render queue, VSync off removes an extra frame of delay, and a performance profile stops power saving from throttling.'
    Changes = @()
    Risk = 'Safe'; Open = 'amd'
    Guide = @(
        'Open AMD Software: Adrenalin Edition → Gaming → Games.',
        'Select Fortnite (add the game if it is missing).',
        'Radeon Anti-Lag → On (or Anti-Lag+ if your driver offers it).',
        'Radeon Chill → Off. Radeon Boost → Off unless you deliberately use it.',
        'Wait for Vertical Refresh → Always Off. Set the profile to Performance.',
        'Use in-game VSync off and cap frames slightly below your refresh rate.'
    )
}

# Section 07 — Memory & Storage.
Add-FluxTweak @{
    Id = 'memory.ram'; SectionNo = 7; Order = 39; Kind = 'action'
    Name = 'Free RAM now'
    Short = 'Ask Windows to trim cached working sets.'
    Detail = 'Asks user processes to release cached working-set pages. Windows reuses that memory as a file cache and refills it on demand, so this is a temporary trim, not a permanent speed boost.'
    Why = 'Useful before a long session on a memory-tight machine. It is a one-shot action, not a background cleaner.'
    Changes = @('Working sets trimmed for user processes', 'No permanent system change')
    Risk = 'Caution'; ButtonLabel = 'Trim'
    Apply = { Clear-FluxRam }
}

Add-FluxTweak @{
    Id = 'memory.temp'; SectionNo = 7; Order = 40; Kind = 'action'
    Name = 'Clear temp files'
    Short = 'Delete temp files older than 24 hours.'
    Detail = 'Deletes files and folders older than 24 hours from your user temp folder and the Windows temp folder. Locked files are skipped. This action is permanent; it does not use a backup.'
    Why = 'Removes stale installers and cache files that waste disk space and can slow indexing.'
    Changes = @('User temp → cleaned', 'Windows temp → cleaned', 'Files in use → skipped')
    Risk = 'Caution'; ButtonLabel = 'Clear'
    Apply = { Clear-FluxTemp }
}

Add-FluxTweak @{
    Id = 'memory.pagefile'; SectionNo = 7; Order = 41
    Name = 'Pagefile 1.5× RAM'
    Short = 'Fixed pagefile sized to 1.5× physical RAM.'
    Detail = 'Turns off automatic pagefile management and sets a fixed pagefile on the system drive at 1.5× your installed RAM. A fixed size avoids Windows resizing the file mid-session.'
    Why = 'A stable pagefile removes resize hitches. Too small a pagefile can break large games; 1.5× is a conservative fixed size.'
    Changes = @('Automatic pagefile management → off', 'C:\pagefile.sys → 1.5× RAM', 'Reboot required')
    Risk = 'Caution'; Restart = $true
    Apply = {
        $target = Get-FluxPagefileTargetMb
        if ($target -le 0) { throw 'Could not read installed RAM.' }
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        Set-FluxBackupData -TweakId 'memory.pagefile' -Name 'autoManaged' -Value ([bool]$cs.AutomaticManagedPagefile) -OnlyIfMissing
        Backup-FluxRegistryValue -TweakId 'memory.pagefile' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'PagingFiles'
        try { Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $false } -ErrorAction Stop }
        catch { Write-FluxLog "Could not disable automatic pagefile management: $($_.Exception.Message)" 'memory.pagefile' }
        Set-FluxReg -TweakId 'memory.pagefile' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'PagingFiles' -Value @("C:\pagefile.sys $target $target") -Kind MultiString
    }
    Revert = {
        Restore-FluxRegistryRecords 'memory.pagefile'
        $auto = [bool](Get-FluxBackupData -TweakId 'memory.pagefile' -Name 'autoManaged' -Default $false)
        if ($auto) {
            try {
                $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
                Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $true } -ErrorAction Stop
            }
            catch { Write-FluxLog "Could not restore automatic pagefile management: $($_.Exception.Message)" 'memory.pagefile' }
        }
    }
    Detect = {
        if (-not (Test-FluxPagefileTarget)) { return $false }
        try { -not (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).AutomaticManagedPagefile }
        catch { $true }
    }
}

Add-FluxTweak @{
    Id = 'memory.trim'; SectionNo = 7; Order = 42
    Name = 'SSD TRIM ON'
    Short = 'Keep TRIM enabled. Write caching: verify in Device Manager.'
    Detail = 'Ensures NTFS delete notification is enabled so the SSD can reclaim unused blocks (TRIM). Write caching is a per-drive device setting and is not safely scriptable; Flux leaves it alone and tells you where to check it.'
    Why = 'TRIM keeps SSD write performance and endurance healthy. Flux will not disable it. Check "Enable write caching" in Device Manager if you want it on.'
    Changes = @('DisableDeleteNotify → 0', 'fsutil TRIM enabled')
    Risk = 'Safe'; Restart = $false
    Apply = {
        Set-FluxReg -TweakId 'memory.trim' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'DisableDeleteNotify' -Value 0 -Kind DWord
        fsutil.exe behavior set DisableDeleteNotify 0 | Out-Null
    }
    Revert = { Restore-FluxRegistryRecords 'memory.trim' }
    Detect = { [int](Get-FluxRegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'DisableDeleteNotify' -Default 1) -eq 0 }
}

Add-FluxTweak @{
    Id = 'memory.defrag'; SectionNo = 7; Order = 43
    Name = 'Scheduled defrag & last-access stamps OFF'
    Short = 'No weekly optimisation task. No last-access writes.'
    Detail = 'Disables the ScheduledDefrag task and turns off NTFS last-access timestamp updates. On an SSD this stops the weekly optimisation job; TRIM can still be run manually with Optimize-Volume.'
    Why = 'Removes scheduled disk work and a tiny metadata write on every file access. On a hard drive, leaving defrag on is usually better.'
    Changes = @('ScheduledDefrag → disabled', 'NtfsDisableLastAccessUpdate → 1')
    Risk = 'Caution'; Restart = $false
    Apply = {
        Set-FluxScheduledTaskDisabled -TweakId 'memory.defrag' -TaskPath '\Microsoft\Windows\Defrag\' -TaskName 'ScheduledDefrag'
        Set-FluxReg -TweakId 'memory.defrag' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'NtfsDisableLastAccessUpdate' -Value 1 -Kind DWord
        fsutil.exe behavior set disablelastaccess 1 | Out-Null
    }
    Revert = {
        Restore-FluxScheduledTasks 'memory.defrag'
        Restore-FluxRegistryRecords 'memory.defrag'
    }
    Detect = {
        try { (Get-ScheduledTask -TaskPath '\Microsoft\Windows\Defrag\' -TaskName 'ScheduledDefrag' -ErrorAction Stop).State -eq 'Disabled' }
        catch { $false }
    }
}

# Section 08 — Network.
Add-FluxTweak @{
    Id = 'network.dns'; SectionNo = 8; Order = 44
    Name = 'Cloudflare DNS'
    Short = '1.1.1.1 + 1.0.0.1 on active adapters.'
    Detail = 'Sets Cloudflare DNS on every active physical network adapter, IPv4 and IPv6 where supported. Existing adapter DNS settings are recorded and restored.'
    Why = 'Cloudflare is usually faster than ISP DNS and avoids some DNS interception. It will not fix a bad route or packet loss.'
    Changes = @('IPv4 DNS → 1.1.1.1, 1.0.0.1', 'IPv6 DNS → Cloudflare', 'DNS cache flushed')
    Risk = 'Safe'; Restart = $false
    Apply = { Set-FluxCloudflareDns -TweakId 'network.dns' }
    Revert = { Restore-FluxDns -TweakId 'network.dns' }
    Detect = { Test-FluxCloudflareDns }
}

Add-FluxTweak @{
    Id = 'network.nagle'; SectionNo = 8; Order = 45
    Name = 'Nagle''s algorithm OFF'
    Short = 'Small packets leave immediately.'
    Detail = 'Sets TcpAckFrequency=1, TCPNoDelay=1 and TcpDelAckTicks=0 on active physical adapters. Small game packets are not held back to coalesce with others.'
    Why = 'Can shave milliseconds off small-packet latency. It can reduce throughput on poor networks; revert if downloads or streams suffer.'
    Changes = @('TcpAckFrequency → 1', 'TCPNoDelay → 1', 'TcpDelAckTicks → 0')
    Risk = 'Caution'; Restart = $true
    Apply = {
        $adapters = Get-FluxPhysicalAdapters
        if (-not $adapters) { throw 'No active physical network adapter found.' }
        foreach ($adapter in $adapters) {
            $guid = $adapter.InterfaceGuid.ToString()
            $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
            Set-FluxReg -TweakId 'network.nagle' -Path $path -Name 'TcpAckFrequency' -Value 1 -Kind DWord
            Set-FluxReg -TweakId 'network.nagle' -Path $path -Name 'TCPNoDelay' -Value 1 -Kind DWord
            Set-FluxReg -TweakId 'network.nagle' -Path $path -Name 'TcpDelAckTicks' -Value 0 -Kind DWord
        }
    }
    Revert = { Restore-FluxRegistryRecords 'network.nagle' }
    Detect = {
        $adapters = Get-FluxPhysicalAdapters
        if (-not $adapters) { return 'NA' }
        foreach ($adapter in $adapters) {
            $guid = $adapter.InterfaceGuid.ToString()
            $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
            $checks = @(
                @{ Path = $path; Name = 'TcpAckFrequency'; Value = 1 },
                @{ Path = $path; Name = 'TCPNoDelay'; Value = 1 },
                @{ Path = $path; Name = 'TcpDelAckTicks'; Value = 0 }
            )
            if (-not (Test-FluxRegistryValueList $checks)) { return $false }
        }
        return $true
    }
}

Add-FluxTweak @{
    Id = 'network.autotuning'; SectionNo = 8; Order = 46
    Name = 'TCP auto-tuning OFF'
    Short = 'Fixed receive window instead of dynamic scaling.'
    Detail = 'Disables Windows receive-window auto-tuning on the TCP templates. The receive window no longer grows dynamically during a connection.'
    Why = 'Some older guides recommend this for lower jitter. It can hurt high-bandwidth or high-latency downloads. Test it on your network.'
    Changes = @('AutoTuningLevelLocal → Disabled on TCP templates')
    Risk = 'Caution'; Restart = $true
    Apply = {
        $settings = @(Get-NetTCPSetting | Where-Object { $_.AutoTuningLevelLocal -and "$($_.AutoTuningLevelLocal)" } | Select-Object SettingName, AutoTuningLevelLocal)
        if (-not $settings) { throw 'Could not read TCP settings.' }
        $backup = @($settings | ForEach-Object { @{ SettingName = $_.SettingName; Level = [string]$_.AutoTuningLevelLocal } })
        Set-FluxBackupData -TweakId 'network.autotuning' -Name 'settings' -Value $backup -OnlyIfMissing
        foreach ($setting in $settings) {
            try { Set-NetTCPSetting -SettingName $setting.SettingName -AutoTuningLevelLocal Disabled -ErrorAction Stop }
            catch { Write-FluxLog "Auto-tuning template $($setting.SettingName) failed: $($_.Exception.Message)" 'network.autotuning' }
        }
    }
    Revert = {
        $backup = @(Get-FluxBackupData -TweakId 'network.autotuning' -Name 'settings' -Default @())
        foreach ($setting in $backup) {
            try { Set-NetTCPSetting -SettingName $setting.SettingName -AutoTuningLevelLocal $setting.Level -ErrorAction Stop }
            catch { Write-FluxLog "Auto-tuning restore failed for $($setting.SettingName): $($_.Exception.Message)" 'network.autotuning' }
        }
    }
    Detect = {
        $settings = @(Get-NetTCPSetting | Where-Object { $_.AutoTuningLevelLocal -and "$($_.AutoTuningLevelLocal)" })
        if (-not $settings) { return $false }
        foreach ($setting in $settings) { if ("$($setting.AutoTuningLevelLocal)" -ne 'Disabled') { return $false } }
        return $true
    }
}

Add-FluxTweak @{
    Id = 'network.ipv6'; SectionNo = 8; Order = 47
    Name = 'IPv6 OFF'
    Short = 'Disable all IPv6 components. Reboot required.'
    Detail = 'Sets DisabledComponents to 0xFF, disabling IPv6 on all interfaces except the loopback. Some apps, VPNs, Xbox networking and corporate networks require IPv6.'
    Why = 'Removes IPv6 overhead and some dual-stack DNS timing issues. This is the riskiest network tweak in Flux; revert if anything breaks.'
    Changes = @('DisabledComponents → 0xFF', 'Reboot required')
    Risk = 'Risky'; Restart = $true
    Apply = {
        Set-FluxReg -TweakId 'network.ipv6' -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisabledComponents' -Value 255 -Kind DWord
    }
    Revert = { Restore-FluxRegistryRecords 'network.ipv6' }
    Detect = { [int](Get-FluxRegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisabledComponents' -Default 0) -eq 255 }
}

Add-FluxTweak @{
    Id = 'network.qos'; SectionNo = 8; Order = 48
    Name = 'QoS packet scheduler OFF'
    Short = 'Unbind the Windows QoS scheduler from active adapters.'
    Detail = 'Disables the ms_pacer QoS packet scheduler binding on active physical adapters and clears the policy reserved bandwidth. Network traffic bypasses the Windows QoS scheduler.'
    Why = 'Removes a scheduling layer from the network path. It can affect VoIP or managed networks; revert if needed.'
    Changes = @('ms_pacer binding → disabled', 'NonBestEffortLimit → 0')
    Risk = 'Caution'; Restart = $false
    Apply = {
        $adapters = Get-FluxPhysicalAdapters
        if (-not $adapters) { throw 'No active physical network adapter found.' }
        $disabled = @()
        foreach ($adapter in $adapters) {
            $binding = Get-NetAdapterBinding -Name $adapter.Name -ComponentID 'ms_pacer' -ErrorAction SilentlyContinue
            if ($binding -and $binding.Enabled) {
                try { Disable-NetAdapterBinding -Name $adapter.Name -ComponentID 'ms_pacer' -ErrorAction Stop; $disabled += $adapter.Name }
                catch { Write-FluxLog "QoS disable failed on $($adapter.Name): $($_.Exception.Message)" 'network.qos' }
            }
        }
        Set-FluxBackupData -TweakId 'network.qos' -Name 'adapters' -Value @($disabled) -OnlyIfMissing
        Set-FluxReg -TweakId 'network.qos' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched' -Name 'NonBestEffortLimit' -Value 0 -Kind DWord
    }
    Revert = {
        $adapters = @(Get-FluxBackupData -TweakId 'network.qos' -Name 'adapters' -Default @())
        foreach ($name in $adapters) {
            try { Enable-NetAdapterBinding -Name $name -ComponentID 'ms_pacer' -ErrorAction Stop }
            catch { Write-FluxLog "QoS restore failed on ${name}: $($_.Exception.Message)" 'network.qos' }
        }
        Restore-FluxRegistryRecords 'network.qos'
    }
    Detect = {
        $adapters = Get-FluxPhysicalAdapters
        if (-not $adapters) { return 'NA' }
        $found = $false
        foreach ($adapter in $adapters) {
            $binding = Get-NetAdapterBinding -Name $adapter.Name -ComponentID 'ms_pacer' -ErrorAction SilentlyContinue
            if (-not $binding) { continue }
            $found = $true
            if ($binding.Enabled) { return $false }
        }
        return $found
    }
}

Add-FluxTweak @{
    Id = 'network.filesharing'; SectionNo = 8; Order = 49
    Name = 'File sharing OFF'
    Short = 'Stop the SMB server service.'
    Detail = 'Stops and disables the LanmanServer service. Other devices can no longer access shared folders or printers on this PC.'
    Why = 'No inbound SMB listener, no share maintenance. Gaming does not need it.'
    Changes = @('LanmanServer → disabled')
    Risk = 'Caution'; Restart = $false
    Apply = { Set-FluxServiceDisabled -TweakId 'network.filesharing' -Name 'LanmanServer' }
    Revert = { Restore-FluxServices 'network.filesharing' }
    Detect = { Test-FluxServiceDisabledList @('LanmanServer') }
}

Add-FluxTweak @{
    Id = 'network.teredo'; SectionNo = 8; Order = 50
    Name = 'Teredo & ISATAP OFF'
    Short = 'Disable IPv6 transition tunnels.'
    Detail = 'Disables Teredo and ISATAP, two legacy IPv6 transition mechanisms. Normal IPv4 and native IPv6 are unaffected.'
    Why = 'Unused tunnels add hidden interfaces and can cause odd routing. Off is cleaner.'
    Changes = @('Teredo → Disabled', 'ISATAP → Disabled')
    Risk = 'Safe'; Restart = $false
    Apply = {
        try {
            $teredo = Get-NetTeredoConfiguration -ErrorAction Stop
            $isatap = Get-NetIsatapConfiguration -ErrorAction Stop
            Set-FluxBackupData -TweakId 'network.teredo' -Name 'native' -Value @{ Teredo = [string]$teredo.Type; Isatap = [string]$isatap.State } -OnlyIfMissing
        }
        catch { Set-FluxBackupData -TweakId 'network.teredo' -Name 'native' -Value @{ Teredo = 'Default'; Isatap = 'Default' } -OnlyIfMissing }
        Set-NetTeredoConfiguration -Type Disabled -ErrorAction Stop
        Set-NetIsatapConfiguration -State Disabled -ErrorAction Stop
    }
    Revert = {
        $native = Get-FluxBackupData -TweakId 'network.teredo' -Name 'native' -Default $null
        if ($native) {
            try { Set-NetTeredoConfiguration -Type $native.Teredo -ErrorAction Stop } catch { }
            try { Set-NetIsatapConfiguration -State $native.Isatap -ErrorAction Stop } catch { }
        }
    }
    Detect = {
        $teredo = (Get-NetTeredoConfiguration -ErrorAction SilentlyContinue).Type
        $isatap = (Get-NetIsatapConfiguration -ErrorAction SilentlyContinue).State
        ("$teredo" -eq 'Disabled') -and ("$isatap" -eq 'Disabled')
    }
}

Add-FluxTweak @{
    Id = 'network.wifipower'; SectionNo = 8; Order = 51
    Name = 'Wi-Fi power saving OFF'
    Short = 'Wireless adapter stays at maximum performance.'
    Detail = 'Sets the wireless adapter power-saving mode to maximum performance on AC and battery. The adapter stops turning off the radio to save power.'
    Why = 'Power saving on Wi-Fi can add latency spikes and packet jitter. On a laptop this costs battery life.'
    Changes = @('Wireless Power Saving Mode → maximum performance')
    Risk = 'Safe'; Restart = $false
    Apply = {
        if (-not (Get-FluxWifiAdapters)) { throw 'No Wi-Fi adapter found.' }
        Set-FluxPowerValue -TweakId 'network.wifipower' -Sub $script:PwrWifiSub -Setting $script:PwrWifiPowerSave -AC 0 -DC 0 -Label 'Wi-Fi power saving'
    }
    Revert = { Restore-FluxPowerValues 'network.wifipower' }
    Detect = {
        if (-not (Get-FluxWifiAdapters)) { return 'NA' }
        Test-FluxPowerValue -Sub $script:PwrWifiSub -Setting $script:PwrWifiPowerSave -AC 0
    }
}
