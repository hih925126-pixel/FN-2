# Flux.Runtime.ps1 — status checks, batch operations, restore points, actions, process guard.

function Test-FluxAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch { return $false }
}

function Write-FluxOpEvent {
    param([string]$Path, [hashtable]$Data)
    if (-not $Path) { return }
    try {
        $line = $Data | ConvertTo-Json -Depth 8 -Compress
        Add-Content -LiteralPath $Path -Value $line -Encoding UTF8
    }
    catch { }
}

function Test-FluxBackupManaged {
    param([string]$TweakId)
    $entry = Get-FluxBackupEntry $TweakId
    if (-not $entry) { return $false }
    foreach ($key in @('registry', 'services', 'power', 'dns', 'tasks')) {
        if (@($entry[$key]).Count -gt 0) { return $true }
    }
    if ($entry.data -is [hashtable]) {
        foreach ($key in $entry.data.Keys) {
            $value = $entry.data[$key]
            if ($null -ne $value -and -not ($value -is [array] -and $value.Count -eq 0)) { return $true }
        }
    }
    return $false
}

function Clear-FluxBackupEntry {
    param([string]$TweakId)
    if ($script:FluxBackup.tweaks.ContainsKey($TweakId)) {
        $script:FluxBackup.tweaks.Remove($TweakId)
        Save-FluxBackup
    }
}

function Get-FluxTweakStatus {
    param($Tweak)
    if (-not $Tweak) { return @{ State = 'Error'; Label = 'Unknown'; Detail = 'Unknown tweak.' } }
    if ($Tweak.Kind -eq 'guide') { return @{ State = 'Manual'; Label = 'Guided'; Detail = '' } }
    if ($Tweak.Kind -eq 'action') { return @{ State = 'Action'; Label = 'Ready'; Detail = '' } }
    if (-not (Test-FluxBackupManaged $Tweak.Id)) {
        return @{ State = 'NotRun'; Label = 'Not run'; Detail = 'Flux has not applied this yet.' }
    }
    try {
        $result = & $Tweak.Detect
        if ($result -eq 'NA') { return @{ State = 'NA'; Label = 'N/A'; Detail = 'Not available on this PC.' } }
        if ($result -eq 'Manual') { return @{ State = 'Manual'; Label = 'Guided'; Detail = '' } }
        if ($result) { return @{ State = 'Applied'; Label = 'Applied'; Detail = '' } }
        return @{ State = 'Drifted'; Label = 'Changed'; Detail = 'Applied earlier, but Windows no longer matches. Restore or re-apply.' }
    }
    catch {
        Write-FluxLog "Detect failed: $($_.Exception.Message)" $Tweak.Id
        return @{ State = 'Error'; Label = 'Check failed'; Detail = $_.Exception.Message }
    }
}

function Get-FluxStatusMap {
    param([string[]]$Ids)
    $tweaks = if ($Ids -and $Ids.Count -gt 0) { @($Ids | ForEach-Object { Get-FluxTweak $_ } | Where-Object { $_ }) } else { @(Get-FluxTweakCatalog) }
    $map = @{}
    foreach ($tweak in $tweaks) { $map[$tweak.Id] = Get-FluxTweakStatus $tweak }
    return $map
}

function Invoke-FluxOperation {
    param(
        [ValidateSet('Apply', 'Revert', 'Run')][string]$Action = 'Apply',
        [string[]]$Ids,
        [string]$ProgressPath,
        [switch]$RestorePoint
    )

    $tweaks = @($Ids | ForEach-Object { Get-FluxTweak $_ } | Where-Object { $_ })
    if ($Action -eq 'Revert') {
        $tweaks = @($tweaks | Where-Object { $_.Kind -ne 'toggle' -or (Test-FluxBackupManaged $_.Id) } | Sort-Object Order -Descending)
    }
    $total = $tweaks.Count
    $results = @()
    $failures = @()
    $restoreMessage = $null
    $restoreOk = $true

    Write-FluxOpEvent -Path $ProgressPath -Data @{ type = 'meta'; action = $Action; total = $total; started = (Get-Date).ToString('o') }

    if ($RestorePoint -and $Action -eq 'Apply' -and $total -gt 0) {
        Write-FluxOpEvent -Path $ProgressPath -Data @{ type = 'progress'; index = 0; total = $total; id = ''; name = 'System restore point'; message = 'Creating a restore point before any changes…' }
        $rp = New-FluxRestorePoint
        $restoreOk = [bool]$rp.Success
        $restoreMessage = $rp.Message
        Write-FluxLog "Restore point: $($rp.Message)"
        Write-FluxOpEvent -Path $ProgressPath -Data @{ type = 'restorepoint'; success = [bool]$rp.Success; message = $rp.Message; time = "$($rp.Time)" }
    }

    $index = 0
    foreach ($tweak in $tweaks) {
        $index++
        $shouldRun = $false
        if ($Action -eq 'Apply' -and $tweak.Kind -eq 'toggle') { $shouldRun = $true }
        elseif ($Action -eq 'Revert' -and $tweak.Kind -eq 'toggle') { $shouldRun = $true }
        elseif ($Action -eq 'Run' -and $tweak.Kind -eq 'action') { $shouldRun = $true }
        if (-not $shouldRun) { continue }

        $verb = switch ($Action) { 'Apply' { 'Applying' } 'Revert' { 'Restoring' } default { 'Running' } }
        Write-FluxOpEvent -Path $ProgressPath -Data @{
            type = 'progress'; index = $index; total = $total; id = $tweak.Id; name = $tweak.Name
            message = "$verb $($tweak.Name)…"
        }

        $success = $true
        $message = ''
        $status = $null
        $actionResult = $null
        $started = Get-Date
        try {
            if (-not (Test-FluxAdministrator)) { throw 'Administrator rights are required.' }
            switch ($Action) {
                'Apply' { $actionResult = & $tweak.Apply }
                'Revert' { $actionResult = & $tweak.Revert }
                'Run' { $actionResult = & $tweak.Apply }
            }
            if ($Action -eq 'Run' -and $actionResult) {
                if ($actionResult.Message) { $message = [string]$actionResult.Message }
                elseif ($actionResult -is [string]) { $message = $actionResult }
            }
            if ($tweak.Kind -eq 'toggle') {
                if ($Action -eq 'Revert') {
                    Clear-FluxBackupEntry $tweak.Id
                    $status = Get-FluxTweakStatus $tweak
                    $message = 'Restored to the state before Flux.'
                }
                else {
                    $status = Get-FluxTweakStatus $tweak
                    if ($status.State -ne 'Applied') {
                        $success = $false
                        $message = "Windows did not report the new state. $($status.Detail)".Trim()
                    }
                }
            }
        }
        catch {
            $success = $false
            $message = $_.Exception.Message
            Write-FluxLog "$Action failed: $message" $tweak.Id
            if ($tweak.Kind -eq 'toggle') { $status = Get-FluxTweakStatus $tweak }
        }

        $result = @{
            id = $tweak.Id; name = $tweak.Name; success = $success; message = $message
            seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 2)
            status = $status
        }
        $results += $result
        if (-not $success) { $failures += $result }
        Write-FluxLog "$Action $($tweak.Id): success=$success $message" $tweak.Id
        Write-FluxOpEvent -Path $ProgressPath -Data @{
            type = 'result'; index = $index; total = $total; id = $tweak.Id; success = $success
            message = $message; status = $status
        }
    }

    Save-FluxBackup
    $statusMap = @{}
    foreach ($tweak in @(Get-FluxTweakCatalog)) { $statusMap[$tweak.Id] = Get-FluxTweakStatus $tweak }

    Write-FluxOpEvent -Path $ProgressPath -Data @{
        type = 'done'; action = $Action; total = $total; results = @($results); failures = @($failures)
        statuses = $statusMap; restoreSuccess = $restoreOk; restoreMessage = $restoreMessage
    }
}

function New-FluxRestorePoint {
    $previous = Get-FluxLatestRestorePoint
    if (-not (Test-FluxAdministrator)) {
        return @{ Success = $false; Message = 'Administrator rights are required to create a restore point.'; Time = $previous }
    }
    try {
        Checkpoint-Computer -Description 'Flux - before performance changes' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        $latest = Get-FluxLatestRestorePoint
        Write-FluxLog 'System restore point created.'
        return @{ Success = $true; Message = 'Restore point created.'; Time = $latest }
    }
    catch {
        $msg = $_.Exception.Message
        if ($msg -match 'already been created|1440|frequency|within the last') {
            return @{ Success = $true; Message = 'A recent restore point already exists; Windows skipped creating another one.'; Time = $previous }
        }
        if ($msg -match 'not enabled|disabled|System Protection|0x800423') {
            return @{ Success = $false; Message = 'System Protection is off or unavailable, so Windows could not create a restore point. Flux still backed up every changed value.'; Time = $previous }
        }
        Write-FluxLog "Restore point failed: $msg"
        return @{ Success = $false; Message = "Restore point failed: $msg. Flux still backed up every changed value."; Time = $previous }
    }
}

function Get-FluxLatestRestorePoint {
    try {
        $points = @(Get-CimInstance -Namespace 'root/default' -ClassName SystemRestore -ErrorAction Stop | Sort-Object CreationTime -Descending)
        if ($points.Count -gt 0) { return $points[0].CreationTime }
    }
    catch { }
    return $null
}

function Get-FluxSystemInfo {
    $info = @{
        ComputerName = $env:COMPUTERNAME
        User = $env:USERNAME
        OsName = 'Windows'
        Build = [Environment]::OSVersion.Version.Build
        Cpu = ''
        Cores = [Environment]::ProcessorCount
        RamGb = 0
        Gpu = @()
        GpuVendor = 'Unknown'
        SystemDisk = 'Unknown'
        IsAdmin = (Test-FluxAdministrator)
        Fortnite = Get-FluxFortniteInstall
        LastRestorePoint = Get-FluxLatestRestorePoint
    }
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $info.OsName = $os.Caption -replace 'Microsoft ', ''
        $info.RamGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    }
    catch { }
    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $info.Cpu = $cpu.Name.Trim()
    }
    catch { }
    try {
        $gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | Where-Object { $_.Name } | Select-Object -ExpandProperty Name)
        $info.Gpu = $gpus
        $joined = ($gpus -join ' ')
        if ($joined -match 'NVIDIA') { $info.GpuVendor = 'NVIDIA' }
        elseif ($joined -match 'AMD|Radeon') { $info.GpuVendor = 'AMD' }
        elseif ($joined -match 'Intel') { $info.GpuVendor = 'Intel' }
    }
    catch { }
    try {
        $systemLetter = $env:SystemDrive.TrimEnd(':')
        $partition = Get-Partition -DriveLetter $systemLetter -ErrorAction Stop | Select-Object -First 1
        if ($partition) {
            $disk = Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.DeviceId -eq "$($partition.DiskNumber)" } | Select-Object -First 1
            if ($disk -and $disk.MediaType) { $info.SystemDisk = $disk.MediaType.ToString() }
        }
    }
    catch { }
    return $info
}

function Get-FluxFortniteInstall {
    if ($script:FluxFortnitePathResolved) { return $script:FluxFortnitePath }
    $script:FluxFortnitePathResolved = $true
    $script:FluxFortnitePath = $null
    $candidates = @()
    $candidates += (Join-Path $env:ProgramFiles 'Epic Games\Fortnite')
    if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Epic Games\Fortnite') }
    $candidates += 'C:\Epic Games\Fortnite'

    $manifestDir = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if (Test-Path -LiteralPath $manifestDir) {
        try {
            foreach ($file in @(Get-ChildItem -LiteralPath $manifestDir -Filter '*.item' -File -ErrorAction SilentlyContinue)) {
                try {
                    $json = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
                    if (("$($json.DisplayName) $($json.AppName) $($json.MandatoryAppFolderName)") -match '(?i)fortnite') {
                        if ($json.InstallLocation) { $candidates += [string]$json.InstallLocation }
                    }
                }
                catch { }
            }
        }
        catch { }
    }

    foreach ($path in $candidates) {
        if (-not $path) { continue }
        $exe = Join-Path $path 'FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe'
        if (Test-Path -LiteralPath $exe) { $script:FluxFortnitePath = (Resolve-Path -LiteralPath $path).Path; break }
    }
    if (-not $script:FluxFortnitePath -and (Test-Path -LiteralPath 'C:\Program Files\Epic Games\Fortnite')) {
        $script:FluxFortnitePath = 'C:\Program Files\Epic Games\Fortnite'
    }
    return $script:FluxFortnitePath
}

function Get-FluxFortniteExeNames {
    return @('FortniteClient-Win64-Shipping.exe', 'FortniteClient-Win64-Shipping_EAC.exe', 'FortniteLauncher.exe')
}

function Get-FluxDxGlobalSetting {
    param([string]$Key)
    $raw = [string](Get-FluxRegValue -Path 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name 'DirectXUserGlobalSettings' -Default '')
    foreach ($part in ($raw -split ';')) {
        if ($part -match '^\s*([^=]+)\s*=\s*(.*)\s*$') {
            if ($matches[1].Trim() -ieq $Key) { return $matches[2].Trim() }
        }
    }
    return $null
}

function Set-FluxDxGlobalSetting {
    param([string]$TweakId, [string]$Key, [string]$Value)
    Backup-FluxRegistryValue -TweakId $TweakId -Path 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name 'DirectXUserGlobalSettings'
    $raw = [string](Get-FluxRegValue -Path 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name 'DirectXUserGlobalSettings' -Default '')
    $found = $false
    $parts = @()
    foreach ($part in ($raw -split ';')) {
        if (-not $part.Trim()) { continue }
        if ($part -match '^\s*([^=]+)\s*=\s*(.*)\s*$' -and $matches[1].Trim() -ieq $Key) {
            $parts += "$Key=$Value"; $found = $true
        }
        else { $parts += $part.Trim() }
    }
    if (-not $found) { $parts += "$Key=$Value" }
    $newValue = ($parts -join ';') + ';'
    Set-FluxReg -TweakId $TweakId -Path 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name 'DirectXUserGlobalSettings' -Value $newValue -Kind String
}

function Clear-FluxRam {
    $critical = @(
        'system', 'idle', 'registry', 'memory compression', 'secure system', 'csrss', 'wininit', 'winlogon',
        'services', 'lsass', 'lsaiso', 'svchost', 'dwm', 'fontdrvhost', 'smss', 'audiodg', 'flux',
        'msmpeng', 'nissrv', 'securityhealthservice', 'werfault', 'registry'
    )
    $trimmed = 0
    $attempted = 0
    $candidates = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Id -ne $PID -and $_.WorkingSet64 -gt 25MB -and $critical -notcontains $_.ProcessName.ToLowerInvariant()
    })
    foreach ($process in $candidates) {
        $attempted++
        try { if ([FluxNative]::TrimProcess($process.Id)) { $trimmed++ } } catch { }
    }
    [System.GC]::Collect()
    Write-FluxLog "RAM trim requested for $trimmed of $attempted processes."
    return @{ Trimmed = $trimmed; Attempted = $attempted; Message = "Trimmed working sets for $trimmed processes. Windows reuses the memory as a cache, so this is temporary." }
}

function Clear-FluxTemp {
    $cutoff = (Get-Date).AddDays(-1)
    $deleted = 0
    $failed = 0
    $bytes = 0.0
    $targets = @($env:TEMP, (Join-Path $env:SystemRoot 'Temp'))
    foreach ($target in ($targets | Select-Object -Unique)) {
        if (-not $target -or -not (Test-Path -LiteralPath $target)) { continue }
        try {
            $items = @(Get-ChildItem -LiteralPath $target -Force -ErrorAction SilentlyContinue | Where-Object {
                $_.LastWriteTime -lt $cutoff -and $_.FullName -notmatch '[\\/]Flux[\\/]?$'
            })
            foreach ($item in $items) {
                try {
                    if ($item.PSIsContainer) {
                        $size = (Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                        $bytes += [double]($size)
                        Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                    }
                    else {
                        $bytes += [double]$item.Length
                        Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                    }
                    $deleted++
                }
                catch { $failed++ }
            }
        }
        catch { }
    }
    $mb = [math]::Round($bytes / 1MB, 1)
    Write-FluxLog "Temp cleanup: $deleted items, $mb MB, $failed skipped."
    return @{ Deleted = $deleted; Failed = $failed; Mb = $mb; Message = "Removed $deleted items ($mb MB). $failed items were in use and were skipped." }
}

function Get-FluxBackgroundCandidates {
    $apps = @(
        @{ Pattern = 'Discord'; Label = 'Discord'; Force = $true },
        @{ Pattern = 'Spotify'; Label = 'Spotify'; Force = $true },
        @{ Pattern = 'Telegram'; Label = 'Telegram'; Force = $true },
        @{ Pattern = 'Slack'; Label = 'Slack'; Force = $true },
        @{ Pattern = 'ms-teams'; Label = 'Microsoft Teams'; Force = $true },
        @{ Pattern = 'Teams'; Label = 'Microsoft Teams'; Force = $true },
        @{ Pattern = 'WhatsApp'; Label = 'WhatsApp'; Force = $true },
        @{ Pattern = 'Messenger'; Label = 'Messenger'; Force = $true },
        @{ Pattern = 'chrome'; Label = 'Google Chrome'; Force = $false },
        @{ Pattern = 'msedge'; Label = 'Microsoft Edge'; Force = $false },
        @{ Pattern = 'firefox'; Label = 'Firefox'; Force = $false },
        @{ Pattern = 'brave'; Label = 'Brave'; Force = $false },
        @{ Pattern = 'opera'; Label = 'Opera'; Force = $false },
        @{ Pattern = 'vivaldi'; Label = 'Vivaldi'; Force = $false },
        @{ Pattern = 'Arc'; Label = 'Arc'; Force = $false }
    )
    $all = @(Get-Process -ErrorAction SilentlyContinue)
    $groups = @()
    $seenLabels = @{}
    foreach ($app in $apps) {
        $matches = @($all | Where-Object { $_.ProcessName -ieq $app.Pattern })
        if ($matches.Count -eq 0) { continue }
        if ($seenLabels.ContainsKey($app.Label)) { continue }
        $main = $matches | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if (-not $main) { $main = $matches | Select-Object -First 1 }
        $path = $null
        try { $path = $main.Path } catch { }
        if (-not $path) { continue }
        $seenLabels[$app.Label] = $true
        $groups += [pscustomobject]@{
            Label = $app.Label
            ProcessName = $main.ProcessName
            ProcessIds = @($matches | Select-Object -ExpandProperty Id)
            WorkingSetMb = [math]::Round((($matches | Measure-Object -Property WorkingSet64 -Sum).Sum) / 1MB, 0)
            Path = $path
            Force = [bool]$app.Force
        }
    }
    return @($groups | Sort-Object WorkingSetMb -Descending)
}

function Close-FluxBackgroundApps {
    param($Candidates)
    $restore = @()
    $closedLabels = @()
    $keptLabels = @()
    foreach ($candidate in @($Candidates)) {
        $procs = @(Get-Process -Name $candidate.ProcessName -ErrorAction SilentlyContinue)
        if ($procs.Count -eq 0) { continue }
        $main = $procs | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($main) {
            try { [void]$main.CloseMainWindow() } catch { }
            Start-Sleep -Milliseconds 700
        }
        $remaining = @(Get-Process -Name $candidate.ProcessName -ErrorAction SilentlyContinue)
        if ($remaining.Count -gt 0 -and $candidate.Force) {
            foreach ($proc in $remaining) { try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch { } }
            Start-Sleep -Milliseconds 300
        }
        $remaining = @(Get-Process -Name $candidate.ProcessName -ErrorAction SilentlyContinue)
        if ($remaining.Count -eq 0) {
            $restore += @{ Name = $candidate.Label; ProcessName = $candidate.ProcessName; Path = $candidate.Path }
            $closedLabels += $candidate.Label
        }
        else { $keptLabels += $candidate.Label }
    }
    if ($restore.Count -gt 0) {
        ($restore | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $script:FluxRestoreAppsPath -Encoding UTF8
        $agent = Get-FluxGameAgentStatus
        if (-not $agent.running) { Start-FluxGameAgent -WaitMinutes 480 }
    }
    return @{ Closed = $closedLabels; Kept = $keptLabels; Restore = $restore }
}

function Restore-FluxBackgroundApps {
    $restored = @()
    if (-not (Test-Path -LiteralPath $script:FluxRestoreAppsPath)) { return $restored }
    try {
        $apps = @(Get-Content -LiteralPath $script:FluxRestoreAppsPath -Raw | ConvertFrom-Json)
        foreach ($app in $apps) {
            $running = @(Get-Process -Name $app.ProcessName -ErrorAction SilentlyContinue)
            if ($running.Count -eq 0 -and $app.Path -and (Test-Path -LiteralPath $app.Path)) {
                try { Start-Process -FilePath $app.Path -ErrorAction Stop; $restored += $app.Name } catch { }
            }
        }
        Remove-Item -LiteralPath $script:FluxRestoreAppsPath -Force -ErrorAction SilentlyContinue
    }
    catch { Write-FluxLog "Restore background apps failed: $($_.Exception.Message)" }
    return $restored
}

function Start-FluxGameAgent {
    param([int]$WaitMinutes = 360)
    Stop-FluxGameAgent
    $agent = Join-Path $PSScriptRoot 'Flux.GameAgent.ps1'
    if (-not (Test-Path -LiteralPath $agent)) { throw 'Game agent script is missing.' }
    $shell = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $shell)) { $shell = 'powershell.exe' }
    $argLine = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -WaitMinutes {1}' -f $agent, $WaitMinutes
    $proc = Start-Process -FilePath $shell -ArgumentList $argLine -WindowStyle Hidden -PassThru
    Set-Content -LiteralPath $script:FluxAgentPidPath -Value $proc.Id -Encoding ASCII
    Set-Content -LiteralPath $script:FluxAgentStatusPath -Value (@{ state = 'starting'; running = $true; updated = (Get-Date).ToString('o'); message = 'Waiting for Fortnite' } | ConvertTo-Json -Compress) -Encoding UTF8
    Write-FluxLog "Game agent started (pid $($proc.Id))."
    return $proc.Id
}

function Stop-FluxGameAgent {
    try {
        $procs = @(Get-CimInstance -ClassName Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'Flux\.GameAgent\.ps1' })
        foreach ($proc in $procs) { try { Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
        Remove-Item -LiteralPath $script:FluxAgentPidPath -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $script:FluxAgentStatusPath) {
            Set-Content -LiteralPath $script:FluxAgentStatusPath -Value (@{ state = 'off'; running = $false; updated = (Get-Date).ToString('o'); message = 'Guard off' } | ConvertTo-Json -Compress) -Encoding UTF8
        }
    }
    catch { }
}

function Get-FluxGameAgentStatus {
    $status = @{ running = $false; state = 'off'; message = 'Guard off'; updated = $null }
    if (Test-Path -LiteralPath $script:FluxAgentStatusPath) {
        try {
            $data = Get-Content -LiteralPath $script:FluxAgentStatusPath -Raw | ConvertFrom-Json
            foreach ($prop in $data.PSObject.Properties) { $status[$prop.Name] = $prop.Value }
        }
        catch { }
    }
    try {
        $procs = @(Get-CimInstance -ClassName Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'Flux\.GameAgent\.ps1' })
        $status.running = ($procs.Count -gt 0)
        if (-not $status.running -and $status.state -notin @('off', 'finished')) {
            $status.state = 'off'
            $status.message = 'Guard stopped'
        }
    }
    catch { }
    return $status
}

function Get-FluxDefenderGamePaths {
    $root = Get-FluxFortniteInstall
    $paths = @()
    if ($root) { $paths += $root }
    $local = Join-Path $env:LOCALAPPDATA 'FortniteGame'
    if (Test-Path -LiteralPath $local) { $paths += $local }
    return @($paths | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
}

function Add-FluxDefenderExclusion {
    param([string]$TweakId)
    $paths = @(Get-FluxDefenderGamePaths)
    if ($paths.Count -eq 0) { throw 'Fortnite was not found. Install or open the game once, then try again.' }
    try { $prefs = Get-MpPreference -ErrorAction Stop } catch { throw 'Windows Defender is not available (another antivirus may be active).' }
    $existing = @($prefs.ExclusionPath)
    $added = @($paths | Where-Object { $existing -notcontains $_ })
    if ($added.Count -gt 0) {
        Add-MpPreference -ExclusionPath $added -ErrorAction Stop
        Set-FluxBackupData -TweakId $TweakId -Name 'defenderAdded' -Value @($added) -OnlyIfMissing
    }
    Write-FluxLog "Defender exclusions added: $($added -join ', ')" $TweakId
}

function Remove-FluxDefenderExclusion {
    param([string]$TweakId)
    $added = @(Get-FluxBackupData -TweakId $TweakId -Name 'defenderAdded' -Default @())
    foreach ($path in $added) {
        try { Remove-MpPreference -ExclusionPath $path -ErrorAction Stop } catch { Write-FluxLog "Defender exclusion removal failed for $path" $TweakId }
    }
    Set-FluxBackupData -TweakId $TweakId -Name 'defenderAdded' -Value @()
}

function Test-FluxDefenderExclusion {
    $paths = @(Get-FluxDefenderGamePaths)
    if ($paths.Count -eq 0) { return 'NA' }
    try { $prefs = Get-MpPreference -ErrorAction Stop } catch { return 'NA' }
    $existing = @($prefs.ExclusionPath)
    foreach ($path in $paths) { if ($existing -notcontains $path) { return $false } }
    return $true
}
