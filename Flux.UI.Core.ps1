# Flux.UI.Core.ps1 — window state, palette, theme, navigation and startup.

$script:FluxUi = @{
    Window            = $null
    Busy              = $false
    ActiveJob         = $null
    ProgressPath      = $null
    ProgressSeen      = 0
    DoneEvent         = $null
    OpAction          = $null
    OpIds             = @()
    StatusMap         = @{}
    TweakCache        = @{}
    TweakViews        = @{}
    SectionViews      = @{}
    NavButtons        = @{}
    ProcessCandidates = @()
    ProcessChecks     = @{}
    ProcessJob        = $null
    ProcessBusy       = $false
    ConfirmData       = $null
    InfoTweak         = $null
    InfoActionMode    = 'close'
    GuardStatus       = @{}
    CrosshairOverlay  = $null
    CrosshairCanvas   = $null
    SyncingCrosshair  = $false
    HotkeyId          = 20300
    HotkeyHook        = $null
    Handle            = [IntPtr]::Zero
    Timer             = $null
    TickCount         = 0
    LastRestorePoint  = $null
    BackupCount       = 0
    Theme             = 'light'
}

$script:FluxBrushes = @{}
$script:FluxHandlers = @{}

$script:FluxPalette = @{
    light = @{
        AppBackground = '#F6F3EA'; Surface = '#FFFFFF'; SurfaceAlt = '#FBF8F1'; SurfaceHover = '#F3EDDD'
        BorderSoft = '#E7DFC9'; BorderStrong = '#D3C5A4'
        TextPrimary = '#191712'; TextSecondary = '#6B6455'; TextTertiary = '#98907F'
        Gold = '#C8A544'; GoldBright = '#E0C35E'; GoldDeep = '#8C6D1B'; GoldSoft = '#F4EBCF'; OnGold = '#191712'
        Danger = '#B83A32'; DangerSoft = '#FBE9E7'; OnDanger = '#FFFFFF'
        Success = '#2C7A57'; SuccessSoft = '#E8F4ED'
        Warning = '#946200'; WarningSoft = '#FBF0D6'
        OverlayScrim = '#8C0F0D0A'
    }
    dark = @{
        AppBackground = '#0D0C0A'; Surface = '#15130E'; SurfaceAlt = '#1B1812'; SurfaceHover = '#241F16'
        BorderSoft = '#2C271C'; BorderStrong = '#423A28'
        TextPrimary = '#F5F0E4'; TextSecondary = '#B1A894'; TextTertiary = '#7C7462'
        Gold = '#D4AF37'; GoldBright = '#F0D16A'; GoldDeep = '#B8912F'; GoldSoft = '#2B2413'; OnGold = '#16130B'
        Danger = '#F27063'; DangerSoft = '#331A17'; OnDanger = '#FFFFFF'
        Success = '#63D3A0'; SuccessSoft = '#14281E'
        Warning = '#E5B95C'; WarningSoft = '#2A2314'
        OverlayScrim = '#B3000000'
    }
}

function ConvertTo-FluxMediaColor {
    param([string]$Value)
    try { return [System.Windows.Media.ColorConverter]::ConvertFromString($Value) }
    catch { return [System.Windows.Media.Colors]::Gold }
}

function Get-FluxUiBrush {
    param([string]$Key)
    if ($script:FluxBrushes.ContainsKey($Key)) { return $script:FluxBrushes[$Key] }
    return $null
}

function Initialize-FluxBrushes {
    param($Window, [string]$Theme)
    $key = if ($Theme -eq 'dark') { 'dark' } else { 'light' }
    $script:FluxBrushes = @{}
    foreach ($name in $script:FluxPalette[$key].Keys) {
        $color = ConvertTo-FluxMediaColor $script:FluxPalette[$key][$name]
        $brush = New-Object System.Windows.Media.SolidColorBrush $color
        $Window.Resources.Add($name, $brush)
        $script:FluxBrushes[$name] = $brush
    }
    $script:FluxUi.Theme = $key
}

function Set-FluxTheme {
    param([string]$Name, [switch]$NoAnimation, [switch]$Persist)
    $target = if ($Name -eq 'dark') { 'dark' } else { 'light' }
    $palette = $script:FluxPalette[$target]
    foreach ($key in $palette.Keys) {
        if (-not $script:FluxBrushes.ContainsKey($key)) { continue }
        $brush = $script:FluxBrushes[$key]
        $color = ConvertTo-FluxMediaColor $palette[$key]
        if ($NoAnimation) {
            $brush.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty, $null)
            $brush.Color = $color
        }
        else {
            $anim = New-Object System.Windows.Media.Animation.ColorAnimation
            $anim.To = $color
            $anim.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(240))
            $brush.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty, $anim)
        }
    }
    $script:FluxUi.Theme = $target
    Update-FluxThemeToggle -NoAnimation:$NoAnimation
    if ($Persist) {
        $script:FluxSettings.theme = $target
        Save-FluxSettings
    }
}

function Update-FluxThemeToggle {
    param([switch]$NoAnimation)
    $ui = $script:FluxUi
    if (-not $ui.ThemeKnob) { return }
    $margin = if ($ui.Theme -eq 'dark') { [System.Windows.Thickness]::new(37, 0, 0, 0) } else { [System.Windows.Thickness]::new(3, 0, 0, 0) }
    if ($NoAnimation) {
        $ui.ThemeKnob.BeginAnimation([System.Windows.FrameworkElement]::MarginProperty, $null)
        $ui.ThemeKnob.Margin = $margin
    }
    else {
        $anim = New-Object System.Windows.Media.Animation.ThicknessAnimation
        $anim.To = $margin
        $anim.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(240))
        $ui.ThemeKnob.BeginAnimation([System.Windows.FrameworkElement]::MarginProperty, $anim)
    }
    if ($ui.Theme -eq 'dark') {
        $ui.ThemeSun.Foreground = Get-FluxUiBrush 'TextTertiary'
        $ui.ThemeMoon.Foreground = Get-FluxUiBrush 'OnGold'
    }
    else {
        $ui.ThemeSun.Foreground = Get-FluxUiBrush 'OnGold'
        $ui.ThemeMoon.Foreground = Get-FluxUiBrush 'TextTertiary'
    }
}

function Toggle-FluxTheme {
    $next = if ($script:FluxUi.Theme -eq 'dark') { 'light' } else { 'dark' }
    Set-FluxTheme -Name $next -Persist
}

function New-FluxUiText {
    param([string]$Text, [string]$StyleKey = '', [string]$ColorKey = '', [double]$Size = 0, [string]$Weight = '')
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    if ($StyleKey) { $t.Style = $script:FluxUi.Window.Resources[$StyleKey] }
    if ($ColorKey) { $t.Foreground = Get-FluxUiBrush $ColorKey }
    if ($Size -gt 0) { $t.FontSize = $Size }
    if ($Weight -eq 'SemiBold') { $t.FontWeight = [System.Windows.FontWeights]::SemiBold }
    elseif ($Weight -eq 'Bold') { $t.FontWeight = [System.Windows.FontWeights]::Bold }
    return $t
}

function New-FluxUiButton {
    param([string]$Text, [string]$StyleKey = 'SecondaryButton', [string]$TagValue = '', [string]$Handler = '', [double]$MinWidth = 0)
    $b = New-Object System.Windows.Controls.Button
    $b.Content = $Text
    if ($StyleKey) { $b.Style = $script:FluxUi.Window.Resources[$StyleKey] }
    if ($TagValue) { $b.Tag = $TagValue }
    if ($MinWidth -gt 0) { $b.MinWidth = $MinWidth }
    if ($Handler -and $script:FluxHandlers.ContainsKey($Handler)) { $b.Add_Click($script:FluxHandlers[$Handler]) }
    return $b
}

function New-FluxUiPill {
    param([string]$Text, [string]$BgKey = 'SurfaceAlt', [string]$FgKey = 'TextSecondary', [double]$FontSize = 9.5)
    $border = New-Object System.Windows.Controls.Border
    $border.CornerRadius = [System.Windows.CornerRadius]::new(9)
    $border.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
    $border.Background = Get-FluxUiBrush $BgKey
    $label = New-FluxUiText -Text $Text -ColorKey $FgKey -Size $FontSize -Weight SemiBold
    $border.Child = $label
    return @{ Border = $border; Text = $label }
}

function New-FluxStatusPill {
    $border = New-Object System.Windows.Controls.Border
    $border.CornerRadius = [System.Windows.CornerRadius]::new(9)
    $border.Padding = [System.Windows.Thickness]::new(9, 3, 9, 3)
    $border.Background = Get-FluxUiBrush 'SurfaceAlt'
    $border.MinWidth = 84
    $border.HorizontalAlignment = 'Left'
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Orientation = 'Horizontal'
    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 6; $dot.Height = 6
    $dot.Fill = Get-FluxUiBrush 'TextTertiary'
    $dot.VerticalAlignment = 'Center'
    $label = New-FluxUiText -Text 'Not run' -ColorKey 'TextSecondary' -Size 9.5 -Weight SemiBold
    $label.Margin = [System.Windows.Thickness]::new(6, 0, 0, 0)
    $stack.Children.Add($dot) | Out-Null
    $stack.Children.Add($label) | Out-Null
    $border.Child = $stack
    return @{ Border = $border; Dot = $dot; Text = $label }
}

function Set-FluxStatusPill {
    param($Pill, [string]$State, [string]$Label, [string]$Detail = '')
    $bg = 'SurfaceAlt'; $fg = 'TextSecondary'; $dot = 'TextTertiary'
    switch ($State) {
        'Applied' { $bg = 'SuccessSoft'; $fg = 'Success'; $dot = 'Success' }
        'Drifted' { $bg = 'WarningSoft'; $fg = 'Warning'; $dot = 'Warning' }
        'Error'   { $bg = 'DangerSoft'; $fg = 'Danger'; $dot = 'Danger' }
        'NA'      { $bg = 'SurfaceAlt'; $fg = 'TextTertiary'; $dot = 'TextTertiary' }
        'Manual'  { $bg = 'GoldSoft'; $fg = 'GoldDeep'; $dot = 'Gold' }
        'Action'  { $bg = 'GoldSoft'; $fg = 'GoldDeep'; $dot = 'Gold' }
        default   { $bg = 'SurfaceAlt'; $fg = 'TextSecondary'; $dot = 'TextTertiary' }
    }
    $Pill.Border.Background = Get-FluxUiBrush $bg
    $Pill.Text.Foreground = Get-FluxUiBrush $fg
    $Pill.Dot.Fill = Get-FluxUiBrush $dot
    $Pill.Text.Text = $Label
    $Pill.Border.ToolTip = $Detail
}

function Set-FluxStatus {
    param([string]$Text, [string]$Kind = 'Ready')
    $ui = $script:FluxUi
    if (-not $ui.StatusText) { return }
    $ui.StatusText.Text = $Text
    $key = switch ($Kind) {
        'Working' { 'Gold' }
        'Warning' { 'Warning' }
        'Error' { 'Danger' }
        default { 'Success' }
    }
    $ui.StatusDot.Fill = Get-FluxUiBrush $key
}

function Get-FluxControl {
    param([string]$Name)
    return $script:FluxUi.Window.FindName($Name)
}

function Initialize-FluxNav {
    $ui = $script:FluxUi
    $ui.NavPanel.Children.Clear()
    $ui.NavButtons = @{}
    $overview = New-FluxUiButton -Text 'Overview' -StyleKey 'NavItem' -TagValue '00' -Handler 'Nav'
    $overview.CommandParameter = 'section:0'
    $overview.Tag = '00'
    $ui.NavPanel.Children.Add($overview) | Out-Null
    $ui.NavButtons[0] = $overview
    foreach ($section in @(Get-FluxSectionList)) {
        $num = ([int]$section.No).ToString('00')
        $button = New-FluxUiButton -Text ([string]$section.Title) -StyleKey 'NavItem' -TagValue $num -Handler 'Nav'
        $button.CommandParameter = "section:$($section.No)"
        $button.Tag = $num
        $ui.NavPanel.Children.Add($button) | Out-Null
        $ui.NavButtons[[int]$section.No] = $button
    }
    Set-FluxActiveNav 0
}

function Set-FluxActiveNav {
    param([int]$No)
    foreach ($key in $script:FluxUi.NavButtons.Keys) {
        $button = $script:FluxUi.NavButtons[$key]
        if ($key -eq $No) {
            $button.Background = Get-FluxUiBrush 'GoldSoft'
            $button.Foreground = Get-FluxUiBrush 'GoldDeep'
        }
        else {
            $button.Background = [System.Windows.Media.Brushes]::Transparent
            $button.Foreground = Get-FluxUiBrush 'TextSecondary'
        }
    }
}

function Open-FluxSection {
    param([string]$Target)
    if (-not $Target) { return }
    $number = 0
    if ($Target -match '^section:(\d+)$') { $number = [int]$matches[1] }
    Set-FluxActiveNav $number
    if ($number -eq 0) {
        $script:FluxUi.ContentScroll.ScrollToTop()
        return
    }
    $view = $script:FluxUi.SectionViews[$number]
    if ($view -and $view.Card) {
        try { $view.Card.BringIntoView() } catch { }
    }
}

function Update-FluxSectionCounts {
    $ui = $script:FluxUi
    foreach ($number in $ui.SectionViews.Keys) {
        $view = $ui.SectionViews[$number]
        if ($view.ContainsKey('ToggleIds')) {
            $ids = @($view.ToggleIds)
            if ($ids.Count -eq 0) { continue }
            $applied = 0
            foreach ($id in $ids) {
                $status = $ui.StatusMap[$id]
                if ($status -and $status.State -eq 'Applied') { $applied++ }
            }
            if ($view.CountText) { $view.CountText.Text = "$applied of $($ids.Count) applied" }
        }
    }
}

function Refresh-FluxBackupStats {
    $summary = Get-FluxBackupSummary
    $count = [int]$summary.TweakCount
    $script:FluxUi.BackupCount = $count
    $script:FluxUi.StatusBackups.Text = if ($count -eq 1) { '1 backed-up tweak' } else { "$count backed-up tweaks" }
    if ($script:FluxUi.NavBackupText) {
        $script:FluxUi.NavBackupText.Text = if ($count -eq 0) { 'No Flux backups yet' } elseif ($count -eq 1) { '1 tweak has a saved backup' } else { "$count tweaks have saved backups" }
    }
}

function Refresh-FluxSafety {
    param([switch]$CheckSystem)
    $ui = $script:FluxUi
    if ($CheckSystem) { $ui.LastRestorePoint = Get-FluxLatestRestorePoint }
    $dateText = 'No Windows restore point found'
    if ($ui.LastRestorePoint) {
        try { $dateText = ([datetime]$ui.LastRestorePoint).ToString('dd MMM yyyy, HH:mm') } catch { }
    }
    if ($ui.NavSafetyText) {
        $ui.NavSafetyText.Text = if ($ui.LastRestorePoint) { "Last restore point: $dateText" } else { 'System Protection may be off. Flux still backs up each change.' }
    }
    if ($ui.SafetyRestoreText) {
        $ui.SafetyRestoreText.Text = if ($ui.LastRestorePoint) { "Windows restore point: $dateText" } else { 'Windows restore point: none found' }
    }
    if ($ui.SafetyBackupText) {
        $ui.SafetyBackupText.Text = if ($ui.BackupCount -eq 0) { 'Flux backups: none yet' } elseif ($ui.BackupCount -eq 1) { 'Flux backups: 1 tweak' } else { "Flux backups: $($ui.BackupCount) tweaks" }
    }
}

function Update-FluxSystemStats {
    param($Info)
    if (-not $Info) { return }
    $ui = $script:FluxUi
    $os = [string]$Info.OsName
    if (-not $os) { $os = 'Windows' }
    $ui.StatSystemValue.Text = "$os · $($Info.Build)"
    $ui.StatSystemDetail.Text = "$($Info.ComputerName) · $($Info.User)"
    $cpu = [string]$Info.Cpu
    if (-not $cpu) { $cpu = 'Unknown CPU' }
    if ($cpu.Length -gt 42) { $cpu = $cpu.Substring(0, 40) + '…' }
    $ui.StatHardwareValue.Text = $cpu
    $ui.StatHardwareDetail.Text = "$($Info.Cores) threads · $($Info.RamGb) GB RAM · $($Info.SystemDisk)"
    if ($Info.Fortnite) {
        $ui.StatFortniteValue.Text = 'Installed'
        $ui.StatFortniteDetail.Text = [string]$Info.Fortnite
    }
    else {
        $ui.StatFortniteValue.Text = 'Not found'
        $ui.StatFortniteDetail.Text = 'Open Epic Games Launcher once'
    }
    $ui.StatFortniteValue.ToolTip = [string]$Info.Fortnite
    $ui.StatSystemDetail.ToolTip = "$($Info.ComputerName) · $($Info.User)"
    $ui.StatHardwareValue.ToolTip = [string]$Info.Cpu
    $ui.StatusAdmin.Text = if ($Info.IsAdmin) { 'Administrator' } else { 'Limited mode' }
}

function Refresh-FluxStatuses {
    $ui = $script:FluxUi
    Set-FluxStatus 'Checking every tweak…' 'Working'
    try {
        $map = Get-FluxStatusMap
        $ui.StatusMap = $map
        foreach ($id in $map.Keys) { Update-FluxTweakView $id $map[$id] }
        Update-FluxSectionCounts
        Refresh-FluxBackupStats
        Refresh-FluxSafety
        Set-FluxStatus 'Status check complete.' 'Ready'
    }
    catch {
        Set-FluxStatus "Status check failed: $($_.Exception.Message)" 'Error'
    }
}

function Initialize-FluxHandlers {
    $script:FluxHandlers.Nav = {
        param($sender, $e)
        Open-FluxSection ([string]$sender.CommandParameter)
    }
    $script:FluxHandlers.Theme = {
        param($sender, $e)
        $e.Handled = $true
        Toggle-FluxTheme
    }
    $script:FluxHandlers.Minimize = {
        param($sender, $e)
        $script:FluxUi.Window.WindowState = 'Minimized'
    }
    $script:FluxHandlers.Maximize = {
        param($sender, $e)
        Toggle-FluxMaximize
    }
    $script:FluxHandlers.CloseWindow = {
        param($sender, $e)
        $script:FluxUi.Window.Close()
    }
    $script:FluxHandlers.TitleDrag = {
        param($sender, $e)
        if ($e.ChangedButton -ne [System.Windows.Input.MouseButton]::Left) { return }
        $node = $e.OriginalSource
        try {
            while ($node -and $node -ne $script:FluxUi.Window) {
                if ($node -is [System.Windows.Controls.Primitives.ButtonBase]) { return }
                if ($node -eq $script:FluxUi.ThemeToggle) { return }
                $node = [System.Windows.Media.VisualTreeHelper]::GetParent($node)
            }
        }
        catch { }
        if ($e.ClickCount -eq 2) { Toggle-FluxMaximize; return }
        try { $script:FluxUi.Window.DragMove() } catch { }
    }
    $script:FluxHandlers.Refresh = {
        param($sender, $e)
        if ($script:FluxUi.Busy) { return }
        Refresh-FluxStatuses
    }
    $script:FluxHandlers.CreateRestorePoint = {
        param($sender, $e)
        if ($script:FluxUi.Busy) { return }
        Start-FluxOperation -Action 'Run' -Ids @('system.restorepoint')
    }
    $script:FluxHandlers.RevertAll = {
        param($sender, $e)
        if ($script:FluxUi.Busy) { return }
        Invoke-FluxRevertAll
    }
    $script:FluxHandlers.OpenData = {
        param($sender, $e)
        Open-FluxFolder $script:FluxAppData
    }
    $script:FluxHandlers.KeyDown = {
        param($sender, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Escape -and $script:FluxUi.OverlayLayer.Visibility -eq 'Visible') {
            Hide-FluxOverlay
            $e.Handled = $true
        }
        elseif ($e.Key -eq [System.Windows.Input.Key]::T -and ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {
            Toggle-FluxTheme
            $e.Handled = $true
        }
    }
    $script:FluxHandlers.SourceInitialized = {
        param($sender, $e)
        try {
            $helper = New-Object System.Windows.Interop.WindowInteropHelper($script:FluxUi.Window)
            $script:FluxUi.Handle = $helper.Handle
            $modifiers = [uint32]0x4000
            $registered = [FluxNative]::RegisterOverlayHotkey($script:FluxUi.Handle, $script:FluxUi.HotkeyId, $modifiers, 0x75)
            if ($registered) {
                $source = [System.Windows.Interop.HwndSource]::FromHwnd($script:FluxUi.Handle)
                $script:FluxUi.HotkeyHook = {
                    param($hwnd, $msg, $wParam, $lParam, $handled)
                    if ($msg -eq 0x0312 -and $wParam.ToInt32() -eq 20300) {
                        Toggle-FluxCrosshair
                    }
                }
                $source.AddHook($script:FluxUi.HotkeyHook)
            }
            else {
                Set-FluxStatus 'F6 is already claimed by another app. Use the crosshair switch instead.' 'Warning'
            }
        }
        catch { }
    }
    $script:FluxHandlers.Closing = {
        param($sender, $e)
        $ui = $script:FluxUi
        if ($ui.Busy -or $ui.ProcessBusy) {
            $e.Cancel = $true
            Set-FluxStatus 'Let the current operation finish before closing Flux.' 'Warning'
            return
        }
        try { if ($ui.Handle -ne [IntPtr]::Zero) { [void][FluxNative]::UnregisterOverlayHotkey($ui.Handle, $ui.HotkeyId) } } catch { }
        if ($ui.Timer) { $ui.Timer.Stop() }
        if ($ui.CrosshairOverlay) { try { $ui.CrosshairOverlay.Close() } catch { } }
    }
}

function Toggle-FluxMaximize {
    $window = $script:FluxUi.Window
    if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $window.WindowState = [System.Windows.WindowState]::Normal
    }
    else {
        $window.WindowState = [System.Windows.WindowState]::Maximized
    }
}

function Update-FluxWindowStateGlyph {
    if ($script:FluxUi.Window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $script:FluxUi.MaximizeButton.Content = [string][char]0xE923
    }
    else {
        $script:FluxUi.MaximizeButton.Content = [string][char]0xE922
    }
}

function Initialize-FluxUi {
    $ui = $script:FluxUi
    $ui.TitleBar = Get-FluxControl 'TitleBar'
    $ui.ThemeToggle = Get-FluxControl 'ThemeToggle'
    $ui.ThemeKnob = Get-FluxControl 'ThemeKnob'
    $ui.ThemeSun = Get-FluxControl 'ThemeSun'
    $ui.ThemeMoon = Get-FluxControl 'ThemeMoon'
    $ui.NavPanel = Get-FluxControl 'NavPanel'
    $ui.NavSafetyText = Get-FluxControl 'NavSafetyText'
    $ui.NavBackupText = Get-FluxControl 'NavBackupText'
    $ui.NavDataButton = Get-FluxControl 'NavDataButton'
    $ui.StatSystemValue = Get-FluxControl 'StatSystemValue'
    $ui.StatSystemDetail = Get-FluxControl 'StatSystemDetail'
    $ui.StatHardwareValue = Get-FluxControl 'StatHardwareValue'
    $ui.StatHardwareDetail = Get-FluxControl 'StatHardwareDetail'
    $ui.StatFortniteValue = Get-FluxControl 'StatFortniteValue'
    $ui.StatFortniteDetail = Get-FluxControl 'StatFortniteDetail'
    $ui.StatGuardValue = Get-FluxControl 'StatGuardValue'
    $ui.StatGuardDetail = Get-FluxControl 'StatGuardDetail'
    $ui.RefreshButton = Get-FluxControl 'RefreshButton'
    $ui.RestorePointButton = Get-FluxControl 'RestorePointButton'
    $ui.RevertAllButton = Get-FluxControl 'RevertAllButton'
    $ui.SectionsPanel = Get-FluxControl 'SectionsPanel'
    $ui.ContentScroll = Get-FluxControl 'ContentScroll'
    $ui.OperationBar = Get-FluxControl 'OperationBar'
    $ui.OperationTitle = Get-FluxControl 'OperationTitle'
    $ui.OperationDetail = Get-FluxControl 'OperationDetail'
    $ui.OperationProgress = Get-FluxControl 'OperationProgress'
    $ui.OperationPercent = Get-FluxControl 'OperationPercent'
    $ui.StatusText = Get-FluxControl 'StatusText'
    $ui.StatusDot = Get-FluxControl 'StatusDot'
    $ui.StatusAdmin = Get-FluxControl 'StatusAdmin'
    $ui.StatusBackups = Get-FluxControl 'StatusBackups'
    $ui.MinimizeButton = Get-FluxControl 'MinimizeButton'
    $ui.MaximizeButton = Get-FluxControl 'MaximizeButton'
    $ui.CloseButton = Get-FluxControl 'CloseButton'
    $ui.OverlayLayer = Get-FluxControl 'OverlayLayer'
    $ui.OverlayCard = Get-FluxControl 'OverlayCard'
    $ui.InfoView = Get-FluxControl 'InfoView'
    $ui.InfoEyebrow = Get-FluxControl 'InfoEyebrow'
    $ui.InfoTitle = Get-FluxControl 'InfoTitle'
    $ui.InfoChipRow = Get-FluxControl 'InfoChipRow'
    $ui.InfoCloseTop = Get-FluxControl 'InfoCloseTop'
    $ui.InfoDescription = Get-FluxControl 'InfoDescription'
    $ui.InfoWhy = Get-FluxControl 'InfoWhy'
    $ui.InfoChangesPanel = Get-FluxControl 'InfoChangesPanel'
    $ui.InfoGuidePanel = Get-FluxControl 'InfoGuidePanel'
    $ui.InfoGuideList = Get-FluxControl 'InfoGuideList'
    $ui.InfoFoot = Get-FluxControl 'InfoFoot'
    $ui.InfoOpenButton = Get-FluxControl 'InfoOpenButton'
    $ui.InfoActionButton = Get-FluxControl 'InfoActionButton'
    $ui.ConfirmView = Get-FluxControl 'ConfirmView'
    $ui.ConfirmEyebrow = Get-FluxControl 'ConfirmEyebrow'
    $ui.ConfirmTitle = Get-FluxControl 'ConfirmTitle'
    $ui.ConfirmMessage = Get-FluxControl 'ConfirmMessage'
    $ui.ConfirmWarnBox = Get-FluxControl 'ConfirmWarnBox'
    $ui.ConfirmWarnText = Get-FluxControl 'ConfirmWarnText'
    $ui.ConfirmRestoreCheck = Get-FluxControl 'ConfirmRestoreCheck'
    $ui.ConfirmFoot = Get-FluxControl 'ConfirmFoot'
    $ui.ConfirmCancelButton = Get-FluxControl 'ConfirmCancelButton'
    $ui.ConfirmContinueButton = Get-FluxControl 'ConfirmContinueButton'
    $ui.ResultView = Get-FluxControl 'ResultView'
    $ui.ResultEyebrow = Get-FluxControl 'ResultEyebrow'
    $ui.ResultTitle = Get-FluxControl 'ResultTitle'
    $ui.ResultSummary = Get-FluxControl 'ResultSummary'
    $ui.ResultList = Get-FluxControl 'ResultList'
    $ui.ResultLogButton = Get-FluxControl 'ResultLogButton'
    $ui.ResultDoneButton = Get-FluxControl 'ResultDoneButton'
    $ui.StudioView = Get-FluxControl 'StudioView'
    $ui.StudioPreviewCanvas = Get-FluxControl 'StudioPreviewCanvas'
    $ui.StudioSizeLabel = Get-FluxControl 'StudioSizeLabel'
    $ui.StyleChips = Get-FluxControl 'StyleChips'
    $ui.SizeChips = Get-FluxControl 'SizeChips'
    $ui.ColorChips = Get-FluxControl 'ColorChips'
    $ui.ColorHexBox = Get-FluxControl 'ColorHexBox'
    $ui.ColorApplyButton = Get-FluxControl 'ColorApplyButton'
    $ui.OpacitySlider = Get-FluxControl 'OpacitySlider'
    $ui.OpacityLabel = Get-FluxControl 'OpacityLabel'
    $ui.OutlineCheck = Get-FluxControl 'OutlineCheck'
    $ui.TopmostCheck = Get-FluxControl 'TopmostCheck'
    $ui.PresetChips = Get-FluxControl 'PresetChips'
    $ui.PresetNameBox = Get-FluxControl 'PresetNameBox'
    $ui.SavePresetButton = Get-FluxControl 'SavePresetButton'
    $ui.StudioResetButton = Get-FluxControl 'StudioResetButton'
    $ui.StudioCloseButton = Get-FluxControl 'StudioCloseButton'
    $ui.OverlayEnabledCheck = Get-FluxControl 'OverlayEnabledCheck'
    $ui.StudioDoneButton = Get-FluxControl 'StudioDoneButton'
}

function Initialize-FluxStaticEvents {
    $ui = $script:FluxUi
    $ui.ThemeToggle.Add_MouseLeftButtonUp($script:FluxHandlers.Theme)
    $ui.ThemeToggle.Add_MouseLeftButtonDown({ param($sender, $e) $e.Handled = $true })
    $ui.MinimizeButton.Add_Click($script:FluxHandlers.Minimize)
    $ui.MaximizeButton.Add_Click($script:FluxHandlers.Maximize)
    $ui.CloseButton.Add_Click($script:FluxHandlers.CloseWindow)
    $ui.TitleBar.Add_MouseLeftButtonDown($script:FluxHandlers.TitleDrag)
    $ui.RefreshButton.Add_Click($script:FluxHandlers.Refresh)
    $ui.RestorePointButton.Add_Click($script:FluxHandlers.CreateRestorePoint)
    $ui.RevertAllButton.Add_Click($script:FluxHandlers.RevertAll)
    $ui.NavDataButton.Add_Click($script:FluxHandlers.OpenData)
    $ui.InfoCloseTop.Add_Click({ param($sender, $e) Hide-FluxOverlay })
    $ui.InfoActionButton.Add_Click($script:FluxHandlers.InfoAction)
    $ui.InfoOpenButton.Add_Click($script:FluxHandlers.InfoOpen)
    $ui.ConfirmCancelButton.Add_Click({ param($sender, $e) Hide-FluxOverlay })
    $ui.ConfirmContinueButton.Add_Click($script:FluxHandlers.ConfirmContinue)
    $ui.ResultDoneButton.Add_Click({ param($sender, $e) Hide-FluxOverlay })
    $ui.ResultLogButton.Add_Click($script:FluxHandlers.OpenLog)
    $ui.Window.Add_SourceInitialized($script:FluxHandlers.SourceInitialized)
    $ui.Window.Add_Closing($script:FluxHandlers.Closing)
    $ui.Window.Add_KeyDown($script:FluxHandlers.KeyDown)
    $ui.Window.Add_StateChanged({ param($sender, $e) Update-FluxWindowStateGlyph })
}

function Initialize-FluxTimer {
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(250)
    $timer.Add_Tick({
        try { Update-FluxOperationPoll } catch { }
        $script:FluxUi.TickCount++
        if (($script:FluxUi.TickCount % 24) -eq 0) {
            try { Update-FluxGuardStatus } catch { }
        }
    })
    $timer.Start()
    $script:FluxUi.Timer = $timer
}

function Initialize-FluxDashboard {
    Set-FluxStatus 'Reading this PC…' 'Working'
    try {
        $info = Get-FluxSystemInfo
        Update-FluxSystemStats $info
    }
    catch { }
    Refresh-FluxSafety -CheckSystem
    Refresh-FluxBackupStats
    try { Refresh-FluxStatuses } catch { }
    try { Initialize-FluxCrosshairUi } catch { }
    try { Refresh-FluxProcessList } catch { }
    try { Update-FluxGuardStatus } catch { }
    try {
        $cfg = Get-FluxCrosshairConfig
        if ($cfg.enabled) { Show-FluxCrosshairOverlay } else { Hide-FluxCrosshairOverlay }
    }
    catch { }
    Set-FluxStatus 'Ready. Nothing changes without your confirmation.' 'Ready'
}

function Open-FluxFolder {
    param([string]$Path)
    if (-not $Path) { return }
    if (-not (Test-Path -LiteralPath $Path)) {
        Set-FluxStatus 'That folder does not exist yet.' 'Warning'
        return
    }
    try { Start-Process explorer.exe -ArgumentList "`"$Path`"" } catch { Set-FluxStatus 'Could not open the folder.' 'Error' }
}

function Open-FluxLog {
    $path = $script:FluxLogPath
    if (-not $path -or -not (Test-Path -LiteralPath $path)) {
        Set-FluxStatus 'No log file yet. Run a tweak first.' 'Warning'
        return
    }
    try { Start-Process notepad.exe -ArgumentList "`"$path`"" } catch { Open-FluxFolder $script:FluxLogDir }
}

function Open-FluxTweakPanel {
    param([string]$Kind)
    switch ($Kind) {
        'wallpaper' {
            try { Start-Process 'ms-settings:personalization-background'; Set-FluxStatus 'Opened Background settings.' 'Ready' }
            catch { Set-FluxStatus 'Open Settings > Personalisation > Background.' 'Warning' }
        }
        'nvidia' {
            $paths = @(
                'C:\Program Files\NVIDIA Corporation\Control Panel Client\nvcplui.exe',
                'C:\Program Files\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA app.exe'
            )
            $opened = $false
            foreach ($path in $paths) {
                if (Test-Path -LiteralPath $path) {
                    try { Start-Process -FilePath $path; $opened = $true; break } catch { }
                }
            }
            if (-not $opened) {
                try { Start-Process 'ms-settings:display-advancedgraphics' } catch { }
                Set-FluxStatus 'GPU software was not found. Open Windows graphics settings or your NVIDIA app from the Start menu.' 'Warning'
            }
            else { Set-FluxStatus 'Opened NVIDIA settings.' 'Ready' }
        }
        'amd' {
            $paths = @(
                'C:\Program Files\AMD\CNext\CNext\RadeonSoftware.exe',
                'C:\Program Files\AMD\CNext\CNext\RadeonSoftwareStart.exe'
            )
            $opened = $false
            foreach ($path in $paths) {
                if (Test-Path -LiteralPath $path) {
                    try { Start-Process -FilePath $path; $opened = $true; break } catch { }
                }
            }
            if (-not $opened) {
                try { Start-Process 'ms-settings:display-advancedgraphics' } catch { }
                Set-FluxStatus 'Radeon Software was not found. Open it from the Start menu, or use Windows graphics settings.' 'Warning'
            }
            else { Set-FluxStatus 'Opened AMD Radeon Software.' 'Ready' }
        }
        default {
            try { Start-Process 'ms-settings:display-advancedgraphics' } catch { }
        }
    }
}

function Start-FluxApp {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

    $xamlPath = Join-Path $PSScriptRoot 'Flux.UI.xaml'
    if (-not (Test-Path -LiteralPath $xamlPath)) { throw 'Flux.UI.xaml is missing.' }
    $xml = New-Object System.Xml.XmlDocument
    $xml.LoadXml((Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8))
    $reader = New-Object System.Xml.XmlNodeReader $xml
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    $script:FluxUi.Window = $window
    $savedTheme = 'light'
    try { if ($script:FluxSettings.theme -eq 'dark') { $savedTheme = 'dark' } } catch { }
    Initialize-FluxBrushes -Window $window -Theme $savedTheme
    Initialize-FluxUi
    Initialize-FluxHandlers
    Initialize-FluxOperationHandlers
    Initialize-FluxCrosshairHandlers
    Initialize-FluxProcessEvents
    Initialize-FluxNav

    $script:FluxUi.TweakCache = @{}
    foreach ($tweak in @(Get-FluxTweakCatalog)) { $script:FluxUi.TweakCache[$tweak.Id] = $tweak }

    Build-FluxSections
    Initialize-FluxStaticEvents
    Initialize-FluxCrosshairStudio

    Update-FluxThemeToggle -NoAnimation
    Update-FluxWindowStateGlyph
    Set-FluxStatus 'Starting Flux…' 'Working'

    $window.Add_Loaded({
        $script:FluxUi.Window.Dispatcher.BeginInvoke(
            [System.Windows.Threading.DispatcherPriority]::Background,
            [System.Action]{ Initialize-FluxDashboard }
        ) | Out-Null
    })

    Initialize-FluxTimer

    $smokeSeconds = 0
    try { $smokeSeconds = [int]$env:FLUX_SMOKE_TEST_SECONDS } catch { }
    if ($smokeSeconds -gt 0) {
        $smokeTimer = New-Object System.Windows.Threading.DispatcherTimer
        $smokeTimer.Interval = [TimeSpan]::FromSeconds($smokeSeconds)
        $smokeTimer.Add_Tick({
            try { $script:FluxUi.Window.Close() } catch { }
        })
        $smokeTimer.Start()
        $script:FluxUi.SmokeTimer = $smokeTimer
    }

    $app = New-Object System.Windows.Application
    $app.ShutdownMode = [System.Windows.ShutdownMode]::OnMainWindowClose
    $app.Run($window) | Out-Null
}
