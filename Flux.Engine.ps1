# Flux.Engine.ps1 — backup, apply and restore primitives.

function Initialize-FluxContext {
    param([string]$Root)

    if ($Root) { $script:FluxRoot = $Root }
    elseif (-not $script:FluxRoot) { $script:FluxRoot = Split-Path -Parent $PSScriptRoot }

    $script:FluxAppData = Join-Path $env:APPDATA 'Flux'
    $script:FluxLogDir = Join-Path $script:FluxAppData 'logs'
    $script:FluxBackupPath = Join-Path $script:FluxAppData 'backup.json'
    $script:FluxSettingsPath = Join-Path $script:FluxAppData 'settings.json'
    $script:FluxRestoreAppsPath = Join-Path $script:FluxAppData 'restore-apps.json'
    $script:FluxAgentPidPath = Join-Path $script:FluxAppData 'agent.pid'
    $script:FluxAgentStatusPath = Join-Path $script:FluxAppData 'agent-status.json'
    $script:FluxLogPath = Join-Path $script:FluxLogDir ("flux-" + (Get-Date -Format 'yyyyMMdd') + ".log")

    foreach ($dir in @($script:FluxAppData, $script:FluxLogDir)) {
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }

    $script:FluxBackup = @{ version = 1; tweaks = @{} }
    if (Test-Path -LiteralPath $script:FluxBackupPath) {
        try {
            $raw = Get-Content -LiteralPath $script:FluxBackupPath -Raw -ErrorAction Stop
            if ($raw.Trim()) {
                $loaded = ConvertFrom-Json -InputObject $raw
                $script:FluxBackup = ConvertTo-FluxHashtable $loaded
            }
        }
        catch {
            $corrupt = "$($script:FluxBackupPath).corrupt-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Copy-Item -LiteralPath $script:FluxBackupPath -Destination $corrupt -ErrorAction SilentlyContinue
            $script:FluxBackup = @{ version = 1; tweaks = @{} }
        }
    }

    if (-not $script:FluxBackup.version) { $script:FluxBackup = @{ version = 1; tweaks = @{} } }
    if (-not $script:FluxBackup.tweaks) { $script:FluxBackup.tweaks = @{} }
    Repair-FluxBackupShape

    $defaults = @{
        theme   = 'light'
        crosshair = @{
            enabled  = $false
            style    = 'Cross'
            size     = 16
            color    = '#D4AF37'
            opacity  = 0.95
            topmost  = $true
            outline  = $true
            presets  = @(
                @{ name = 'Gold Dot'; style = 'Dot'; size = 10; color = '#E3C15A'; opacity = 0.95; outline = $true }
            )
        }
    }
    $script:FluxSettings = $defaults
    if (Test-Path -LiteralPath $script:FluxSettingsPath) {
        try {
            $loaded = ConvertTo-FluxHashtable (Get-Content -LiteralPath $script:FluxSettingsPath -Raw | ConvertFrom-Json)
            if ($loaded -is [hashtable]) {
                foreach ($key in $loaded.Keys) { $script:FluxSettings[$key] = $loaded[$key] }
                if (-not $script:FluxSettings.crosshair) { $script:FluxSettings.crosshair = $defaults.crosshair }
                foreach ($key in $defaults.crosshair.Keys) {
                    if (-not $script:FluxSettings.crosshair.ContainsKey($key)) {
                        $script:FluxSettings.crosshair[$key] = $defaults.crosshair[$key]
                    }
                }
                if ($null -eq $script:FluxSettings.crosshair.presets) { $script:FluxSettings.crosshair.presets = @() }
            }
        }
        catch { $script:FluxSettings = $defaults }
    }
}

function ConvertTo-FluxHashtable {
    param($InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $hash = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $hash[$prop.Name] = ConvertTo-FluxHashtable $prop.Value
        }
        return $hash
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @()
        foreach ($item in $InputObject) { $items += ,(ConvertTo-FluxHashtable $item) }
        return ,$items
    }
    return $InputObject
}

function Repair-FluxBackupShape {
    if (-not $script:FluxBackup.tweaks) { return }
    foreach ($id in @($script:FluxBackup.tweaks.Keys)) {
        $entry = $script:FluxBackup.tweaks[$id]
        if ($entry -isnot [hashtable]) {
            $entry = @{}
            $script:FluxBackup.tweaks[$id] = $entry
        }
        foreach ($key in @('registry', 'services', 'power', 'dns', 'tasks')) {
            $entry[$key] = @($entry[$key] | Where-Object { $_ })
        }
        if ($entry.data -isnot [hashtable]) { $entry.data = @{} }
    }
}

function Save-FluxBackup {
    try {
        $json = $script:FluxBackup | ConvertTo-Json -Depth 20
        Set-Content -LiteralPath $script:FluxBackupPath -Value $json -Encoding UTF8
    }
    catch { Write-FluxLog "Could not save backup: $($_.Exception.Message)" }
}

function Write-FluxLog {
    param([string]$Message, [string]$TweakId = '')
    try {
        if (-not $script:FluxLogPath) { Initialize-FluxContext }
        $prefix = if ($TweakId) { "[$TweakId] " } else { '' }
        Add-Content -LiteralPath $script:FluxLogPath -Value ("{0}  {1}{2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $prefix, $Message) -Encoding UTF8
    }
    catch { }
}

function Get-FluxBackupEntry {
    param([string]$TweakId, [switch]$Create)
    if (-not $TweakId) { return $null }
    if (-not $script:FluxBackup.tweaks.ContainsKey($TweakId)) {
        if (-not $Create) { return $null }
        $script:FluxBackup.tweaks[$TweakId] = @{
            registry = @(); services = @(); power = @(); dns = @(); tasks = @(); data = @{}
        }
    }
    $entry = $script:FluxBackup.tweaks[$TweakId]
    foreach ($key in @('registry', 'services', 'power', 'dns', 'tasks')) {
        if ($null -eq $entry[$key]) { $entry[$key] = @() } else { $entry[$key] = @($entry[$key]) }
    }
    if ($entry.data -isnot [hashtable]) {
        $converted = ConvertTo-FluxHashtable $entry.data
        if ($converted -is [hashtable]) { $entry.data = $converted } else { $entry.data = @{} }
    }
    return $entry
}

function Get-FluxRegistryLocation {
    param([string]$Path)
    $p = $Path.Trim()
    if ($p -match '^(?i)(HKCU|HKEY_CURRENT_USER)(:|\\|$)') {
        return @{ Hive = [Microsoft.Win32.Registry]::CurrentUser; Root = 'HKCU'; SubKey = ($p -replace '^(?i)(HKCU|HKEY_CURRENT_USER):?\\?', '') }
    }
    if ($p -match '^(?i)(HKLM|HKEY_LOCAL_MACHINE)(:|\\|$)') {
        return @{ Hive = [Microsoft.Win32.Registry]::LocalMachine; Root = 'HKLM'; SubKey = ($p -replace '^(?i)(HKLM|HKEY_LOCAL_MACHINE):?\\?', '') }
    }
    if ($p -match '^(?i)(HKCR|HKEY_CLASSES_ROOT)(:|\\|$)') {
        return @{ Hive = [Microsoft.Win32.Registry]::ClassesRoot; Root = 'HKCR'; SubKey = ($p -replace '^(?i)(HKCR|HKEY_CLASSES_ROOT):?\\?', '') }
    }
    if ($p -match '^(?i)(HKU|HKEY_USERS)(:|\\|$)') {
        return @{ Hive = [Microsoft.Win32.Registry]::Users; Root = 'HKU'; SubKey = ($p -replace '^(?i)(HKU|HKEY_USERS):?\\?', '') }
    }
    throw "Unsupported registry path: $Path"
}

function Get-FluxRegValue {
    param([string]$Path, [string]$Name, $Default = $null)
    try {
        $loc = Get-FluxRegistryLocation $Path
        $key = $loc.Hive.OpenSubKey($loc.SubKey, $false)
        if (-not $key) { return $Default }
        try { return $key.GetValue($Name, $Default) } finally { $key.Close() }
    }
    catch { return $Default }
}

function Test-FluxRegValue {
    param([string]$Path, [string]$Name, $Expected)
    $value = Get-FluxRegValue -Path $Path -Name $Name -Default ([object]::new())
    if ($value -is [object] -and $value.GetType().FullName -eq 'System.Object') { return $false }
    return ($value -eq $Expected)
}

function Backup-FluxRegistryValue {
    param([string]$TweakId, [string]$Path, [string]$Name)
    $entry = Get-FluxBackupEntry -TweakId $TweakId -Create
    foreach ($existing in @($entry.registry)) {
        if ($existing.Path -eq $Path -and $existing.Name -eq $Name) { return }
    }
    $record = @{ Path = $Path; Name = $Name; Exists = $false; Kind = 'None'; Value = $null; ValueB64 = $null }
    try {
        $loc = Get-FluxRegistryLocation $Path
        $key = $loc.Hive.OpenSubKey($loc.SubKey, $false)
        if ($key) {
            try {
                $names = @($key.GetValueNames())
                $hasValue = $false
                foreach ($n in $names) { if ([string]::Equals($n, $Name, [System.StringComparison]::OrdinalIgnoreCase)) { $hasValue = $true; break } }
                if ($hasValue) {
                    $record.Exists = $true
                    $kind = $key.GetValueKind($Name)
                    $record.Kind = $kind.ToString()
                    $value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                    if ($kind -eq [Microsoft.Win32.RegistryValueKind]::Binary) {
                        $record.ValueB64 = [Convert]::ToBase64String([byte[]]$value)
                    }
                    elseif ($kind -eq [Microsoft.Win32.RegistryValueKind]::None) { $record.Value = $null }
                    else { $record.Value = $value }
                }
            }
            finally { $key.Close() }
        }
    }
    catch { Write-FluxLog "Backup failed for $Path\$Name : $($_.Exception.Message)" }
    $entry.registry = @($entry.registry) + $record
    Save-FluxBackup
}

function Restore-FluxRegistryRecord {
    param($Record)
    try {
        $loc = Get-FluxRegistryLocation $Record.Path
        if ($Record.Exists) {
            $key = $loc.Hive.CreateSubKey($loc.SubKey)
            if (-not $key) { throw "Could not open $($Record.Path)" }
            try {
                $kind = [System.Enum]::Parse([Microsoft.Win32.RegistryValueKind], [string]$Record.Kind, $true)
                $value = $Record.Value
                if ($kind -eq [Microsoft.Win32.RegistryValueKind]::Binary) {
                    $value = [Convert]::FromBase64String([string]$Record.ValueB64)
                }
                $key.SetValue($Record.Name, $value, $kind)
            }
            finally { $key.Close() }
        }
        else {
            $key = $loc.Hive.OpenSubKey($loc.SubKey, $true)
            if ($key) {
                try { $key.DeleteValue($Record.Name, $false) } finally { $key.Close() }
            }
        }
    }
    catch { Write-FluxLog "Restore failed for $($Record.Path)\$($Record.Name): $($_.Exception.Message)" }
}

function Set-FluxReg {
    param(
        [Parameter(Mandatory)][string]$TweakId,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')]
        [string]$Kind = 'DWord'
    )
    Backup-FluxRegistryValue -TweakId $TweakId -Path $Path -Name $Name
    $loc = Get-FluxRegistryLocation $Path
    $key = $loc.Hive.CreateSubKey($loc.SubKey)
    if (-not $key) { throw "Could not create registry key $Path" }
    try {
        $registryKind = [System.Enum]::Parse([Microsoft.Win32.RegistryValueKind], $Kind, $true)
        $key.SetValue($Name, $Value, $registryKind)
    }
    finally { $key.Close() }
    Write-FluxLog "Set $Path\$Name ($Kind)" $TweakId
}

function Remove-FluxRegValue {
    param([Parameter(Mandatory)][string]$TweakId, [Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    Backup-FluxRegistryValue -TweakId $TweakId -Path $Path -Name $Name
    $loc = Get-FluxRegistryLocation $Path
    $key = $loc.Hive.OpenSubKey($loc.SubKey, $true)
    if ($key) {
        try { $key.DeleteValue($Name, $false) } finally { $key.Close() }
    }
    Write-FluxLog "Removed $Path\$Name" $TweakId
}

function Restore-FluxRegistryRecords {
    param([string]$TweakId)
    $entry = Get-FluxBackupEntry $TweakId
    if (-not $entry) { return }
    foreach ($record in @($entry.registry)) { Restore-FluxRegistryRecord $record }
    $entry.registry = @()
    Save-FluxBackup
}

function Set-FluxBackupData {
    param([string]$TweakId, [string]$Name, $Value, [switch]$OnlyIfMissing)
    $entry = Get-FluxBackupEntry -TweakId $TweakId -Create
    if ($OnlyIfMissing -and $entry.data.ContainsKey($Name)) { return }
    $entry.data[$Name] = $Value
    Save-FluxBackup
}

function Get-FluxBackupData {
    param([string]$TweakId, [string]$Name, $Default = $null)
    $entry = Get-FluxBackupEntry $TweakId
    if (-not $entry -or -not $entry.data.ContainsKey($Name)) { return $Default }
    return $entry.data[$Name]
}

function Get-FluxServiceRecord {
    param([string]$Name)
    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if (-not (Test-Path -LiteralPath $key)) { return $null }
    $props = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    return @{
        Name = $Name
        Exists = $true
        Start = if ($null -ne $props.Start) { [int]$props.Start } else { $null }
        Delayed = if ($null -ne $props.DelayedAutostart) { [int]$props.DelayedAutostart } else { $null }
        Status = if ($svc) { $svc.Status.ToString() } else { 'Unknown' }
    }
}

function Backup-FluxService {
    param([string]$TweakId, [string]$Name)
    $entry = Get-FluxBackupEntry -TweakId $TweakId -Create
    foreach ($existing in @($entry.services)) { if ($existing.Name -eq $Name) { return } }
    $record = Get-FluxServiceRecord $Name
    if (-not $record) { $record = @{ Name = $Name; Exists = $false; Start = $null; Delayed = $null; Status = 'Missing' } }
    $entry.services = @($entry.services) + $record
    Save-FluxBackup
}

function Set-FluxServiceDisabled {
    param([Parameter(Mandatory)][string]$TweakId, [Parameter(Mandatory)][string]$Name)
    Backup-FluxService -TweakId $TweakId -Name $Name
    $record = Get-FluxServiceRecord $Name
    if (-not $record) { Write-FluxLog "Service $Name not present; skipped." $TweakId; return }
    try { Stop-Service -Name $Name -Force -ErrorAction Stop } catch { Write-FluxLog "Could not stop ${Name}: $($_.Exception.Message)" $TweakId }
    try { Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop }
    catch {
        $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
        Set-ItemProperty -LiteralPath $key -Name Start -Value 4 -Type DWord -ErrorAction Stop
    }
    Write-FluxLog "Disabled service $Name" $TweakId
}

function Restore-FluxServiceRecord {
    param($Record)
    if (-not $Record.Exists) { return }
    try {
        $svc = Get-Service -Name $Record.Name -ErrorAction SilentlyContinue
        if (-not $svc) { return }
        $startType = switch ([int]$Record.Start) {
            2 { 'Automatic' }
            3 { 'Manual' }
            4 { 'Disabled' }
            default { $null }
        }
        if ($startType) {
            Set-Service -Name $Record.Name -StartupType $startType -ErrorAction Stop
            if ($null -ne $Record.Delayed) {
                $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Record.Name)"
                Set-ItemProperty -LiteralPath $key -Name DelayedAutostart -Value ([int]$Record.Delayed) -Type DWord -ErrorAction SilentlyContinue
            }
        }
        if ($Record.Status -eq 'Running' -and $Record.Start -ne 4) {
            Start-Service -Name $Record.Name -ErrorAction SilentlyContinue
        }
    }
    catch { Write-FluxLog "Restore service $($Record.Name) failed: $($_.Exception.Message)" }
}

function Restore-FluxServices {
    param([string]$TweakId)
    $entry = Get-FluxBackupEntry $TweakId
    if (-not $entry) { return }
    foreach ($record in @($entry.services)) { Restore-FluxServiceRecord $record }
    $entry.services = @()
    Save-FluxBackup
}

function Backup-FluxPowerValue {
    param([string]$TweakId, [string]$Sub, [string]$Setting, [string]$Label)
    $entry = Get-FluxBackupEntry -TweakId $TweakId -Create
    foreach ($existing in @($entry.power)) {
        if ($existing.Sub -eq $Sub -and $existing.Setting -eq $Setting) { return }
    }
    $scheme = [FluxPower]::GetActiveScheme()
    if ($scheme -eq [Guid]::Empty) { return }
    $subGuid = [Guid]$Sub
    $settingGuid = [Guid]$Setting
    $ac = [FluxPower]::ReadAC($scheme, $subGuid, $settingGuid)
    $dc = [FluxPower]::ReadDC($scheme, $subGuid, $settingGuid)
    $record = @{
        Scheme = $scheme.ToString(); Sub = $Sub; Setting = $Setting; Label = $Label
        ACExists = ($ac -ge 0); AC = if ($ac -ge 0) { $ac } else { 0 }
        DCExists = ($dc -ge 0); DC = if ($dc -ge 0) { $dc } else { 0 }
    }
    $entry.power = @($entry.power) + $record
    Save-FluxBackup
}

function Set-FluxPowerValue {
    param(
        [Parameter(Mandatory)][string]$TweakId,
        [Parameter(Mandatory)][string]$Sub,
        [Parameter(Mandatory)][string]$Setting,
        [Parameter(Mandatory)][int]$AC,
        [int]$DC = -1,
        [string]$Label = ''
    )
    Backup-FluxPowerValue -TweakId $TweakId -Sub $Sub -Setting $Setting -Label $Label
    $scheme = [FluxPower]::GetActiveScheme()
    $subGuid = [Guid]$Sub
    $settingGuid = [Guid]$Setting
    [void][FluxPower]::WriteAC($scheme, $subGuid, $settingGuid, [uint32]$AC)
    if ($DC -ge 0) { [void][FluxPower]::WriteDC($scheme, $subGuid, $settingGuid, [uint32]$DC) }
    [void][FluxPower]::Reapply()
    Write-FluxLog "Power $Label = $AC" $TweakId
}

function Remove-FluxPowerRegistryValue {
    param([string]$Scheme, [string]$Sub, [string]$Setting, [string]$ValueName)
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$Scheme\$Sub\$Setting"
    if (Test-Path -LiteralPath $path) {
        Remove-ItemProperty -LiteralPath $path -Name $ValueName -ErrorAction SilentlyContinue
    }
}

function Restore-FluxPowerRecord {
    param($Record)
    try {
        $scheme = [Guid]$Record.Scheme
        $subGuid = [Guid]$Record.Sub
        $settingGuid = [Guid]$Record.Setting
        if ($Record.ACExists) { [void][FluxPower]::WriteAC($scheme, $subGuid, $settingGuid, [uint32]$Record.AC) }
        else { Remove-FluxPowerRegistryValue -Scheme $Record.Scheme -Sub $Record.Sub -Setting $Record.Setting -ValueName 'ACSettingIndex' }
        if ($Record.DCExists) { [void][FluxPower]::WriteDC($scheme, $subGuid, $settingGuid, [uint32]$Record.DC) }
        else { Remove-FluxPowerRegistryValue -Scheme $Record.Scheme -Sub $Record.Sub -Setting $Record.Setting -ValueName 'DCSettingIndex' }
    }
    catch { Write-FluxLog "Restore power $($Record.Label) failed: $($_.Exception.Message)" }
}

function Restore-FluxPowerValues {
    param([string]$TweakId)
    $entry = Get-FluxBackupEntry $TweakId
    if (-not $entry) { return }
    foreach ($record in @($entry.power)) { Restore-FluxPowerRecord $record }
    [void][FluxPower]::Reapply()
    $entry.power = @()
    Save-FluxBackup
}

function Get-FluxPhysicalAdapters {
    try {
        return @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' })
    }
    catch { return @() }
}

function Backup-FluxDns {
    param([string]$TweakId)
    $entry = Get-FluxBackupEntry -TweakId $TweakId -Create
    if (@($entry.dns).Count -gt 0) { return }
    $records = @()
    foreach ($adapter in (Get-FluxPhysicalAdapters)) {
        foreach ($family in @('IPv4', 'IPv6')) {
            try {
                $current = @(Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily $family -ErrorAction Stop)
                $servers = @()
                foreach ($row in $current) { $servers += @($row.ServerAddresses) }
                # If an address family is bound, there is a row even when set to automatic.
                $bound = ($current.Count -gt 0)
                if ($bound) {
                    $records += @{
                        Alias = $adapter.Name; Guid = $adapter.InterfaceGuid.ToString(); Family = $family
                        Automatic = ($servers.Count -eq 0); Servers = @($servers)
                    }
                }
            }
            catch { }
        }
    }
    $entry.dns = @($records)
    Save-FluxBackup
}

function Set-FluxCloudflareDns {
    param([string]$TweakId)
    Backup-FluxDns -TweakId $TweakId
    $adapters = Get-FluxPhysicalAdapters
    if (-not $adapters) { throw 'No active physical network adapter found.' }
    foreach ($adapter in $adapters) {
        try { Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses @('1.1.1.1', '1.0.0.1') -ErrorAction Stop }
        catch { Write-FluxLog "DNS IPv4 failed on $($adapter.Name): $($_.Exception.Message)" $TweakId }
        try { Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses @('2606:4700:4700::1111', '2606:4700:4700::1001') -ErrorAction Stop }
        catch { }
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-FluxLog 'Cloudflare DNS set on active physical adapters.' $TweakId
}

function Restore-FluxDns {
    param([string]$TweakId)
    $entry = Get-FluxBackupEntry $TweakId
    if (-not $entry) { return }
    foreach ($record in @($entry.dns)) {
        try {
            $adapter = Get-NetAdapter -Name $record.Alias -ErrorAction SilentlyContinue
            if (-not $adapter) { continue }
            if ($record.Automatic) {
                Set-DnsClientServerAddress -InterfaceAlias $record.Alias -ResetServerAddresses -ErrorAction Stop
            }
            else {
                Set-DnsClientServerAddress -InterfaceAlias $record.Alias -ServerAddresses @($record.Servers) -ErrorAction Stop
            }
        }
        catch { Write-FluxLog "DNS restore failed on $($record.Alias): $($_.Exception.Message)" $TweakId }
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    $entry.dns = @()
    Save-FluxBackup
}

function Test-FluxCloudflareDns {
    $adapters = @(Get-FluxPhysicalAdapters)
    if (-not $adapters) { return 'NA' }
    foreach ($adapter in $adapters) {
        try {
            $rows = @(Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction Stop)
            $servers = @()
            foreach ($row in $rows) { $servers += @($row.ServerAddresses) }
            if ($servers -notcontains '1.1.1.1' -or $servers -notcontains '1.0.0.1') { return $false }
        }
        catch { return $false }
    }
    return $true
}

function Backup-FluxScheduledTask {
    param([string]$TweakId, [string]$TaskPath, [string]$TaskName)
    $entry = Get-FluxBackupEntry -TweakId $TweakId -Create
    foreach ($existing in @($entry.tasks)) {
        if ($existing.TaskPath -eq $TaskPath -and $existing.TaskName -eq $TaskName) { return }
    }
    try {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
        $entry.tasks = @($entry.tasks) + @{ TaskPath = $TaskPath; TaskName = $TaskName; State = $task.State.ToString() }
    }
    catch { $entry.tasks = @($entry.tasks) + @{ TaskPath = $TaskPath; TaskName = $TaskName; State = 'Missing' } }
    Save-FluxBackup
}

function Set-FluxScheduledTaskDisabled {
    param([string]$TweakId, [string]$TaskPath, [string]$TaskName)
    Backup-FluxScheduledTask -TweakId $TweakId -TaskPath $TaskPath -TaskName $TaskName
    try { Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop | Out-Null }
    catch { throw "Could not disable scheduled task ${TaskName}: $($_.Exception.Message)" }
    Write-FluxLog "Disabled task $TaskName" $TweakId
}

function Restore-FluxScheduledTasks {
    param([string]$TweakId)
    $entry = Get-FluxBackupEntry $TweakId
    if (-not $entry) { return }
    foreach ($record in @($entry.tasks)) {
        try {
            if ($record.State -eq 'Disabled') { Disable-ScheduledTask -TaskPath $record.TaskPath -TaskName $record.TaskName -ErrorAction Stop | Out-Null }
            else { Enable-ScheduledTask -TaskPath $record.TaskPath -TaskName $record.TaskName -ErrorAction Stop | Out-Null }
        }
        catch { Write-FluxLog "Task restore $($record.TaskName) failed: $($_.Exception.Message)" $TweakId }
    }
    $entry.tasks = @()
    Save-FluxBackup
}

function Get-FluxBackupSummary {
    if (Test-Path -LiteralPath $script:FluxBackupPath) {
        try {
            $data = ConvertTo-FluxHashtable (Get-Content -LiteralPath $script:FluxBackupPath -Raw | ConvertFrom-Json)
            if ($data.tweaks) { return @{ TweakCount = @($data.tweaks.Keys).Count } }
        }
        catch { }
    }
    return @{ TweakCount = 0 }
}

function Get-FluxSectionList {
    if ($script:FluxSections) { return $script:FluxSections }
    return @()
}

function Get-FluxTweakCatalog {
    return @($script:FluxTweaks | Sort-Object Order)
}

function Get-FluxTweak {
    param([string]$Id)
    foreach ($tweak in $script:FluxTweaks) { if ($tweak.Id -eq $Id) { return $tweak } }
    return $null
}

function Get-FluxSettings {
    return $script:FluxSettings
}

function Save-FluxSettings {
    try {
        $json = $script:FluxSettings | ConvertTo-Json -Depth 10
        Set-Content -LiteralPath $script:FluxSettingsPath -Value $json -Encoding UTF8
    }
    catch { Write-FluxLog "Could not save settings: $($_.Exception.Message)" }
}
