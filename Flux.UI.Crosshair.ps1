# Flux.UI.Crosshair.ps1 — crosshair card, drawing, overlay and studio.

$script:FluxCrosshairStyles = @('Cross', 'Dot', 'Circle', 'Cross + Circle', 'T', 'X', 'Square', 'Bracket', 'Diamond', 'Chevron')
$script:FluxCrosshairSizes = @(8, 12, 16, 20, 24)
$script:FluxCrosshairColors = @('#D4AF37', '#F2E6B8', '#FFFFFF', '#FF554D', '#6BE38B', '#59B8FF', '#F4A3FF', '#FFD84D', '#A8FFD9', '#000000')

function Get-FluxCrosshairConfig {
    $settings = $script:FluxSettings
    if (-not $settings.crosshair) {
        $settings.crosshair = @{
            enabled = $false; style = 'Cross'; size = 16; color = '#D4AF37'; opacity = 0.95
            topmost = $true; outline = $true; presets = @()
        }
    }
    $cfg = $settings.crosshair
    foreach ($key in @('enabled', 'style', 'size', 'color', 'opacity', 'topmost', 'outline', 'presets')) {
        if (-not $cfg.ContainsKey($key)) {
            switch ($key) {
                'enabled' { $cfg.enabled = $false }
                'style' { $cfg.style = 'Cross' }
                'size' { $cfg.size = 16 }
                'color' { $cfg.color = '#D4AF37' }
                'opacity' { $cfg.opacity = 0.95 }
                'topmost' { $cfg.topmost = $true }
                'outline' { $cfg.outline = $true }
                'presets' { $cfg.presets = @() }
            }
        }
    }
    if ($null -eq $cfg.presets) { $cfg.presets = @() }
    $cfg.size = [int]$cfg.size
    $cfg.opacity = [double]$cfg.opacity
    if ($cfg.opacity -lt 0.25) { $cfg.opacity = 0.25 }
    if ($cfg.opacity -gt 1) { $cfg.opacity = 1 }
    if (-not $cfg.color) { $cfg.color = '#D4AF37' }
    $cfg.color = ([string]$cfg.color).ToUpperInvariant()
    return $cfg
}

function Save-FluxCrosshair {
    Save-FluxSettings
}

function Initialize-FluxCrosshairHandlers {
    $script:FluxHandlers.CrosshairStudio = {
        param($sender, $e)
        Open-FluxCrosshairStudio
    }
    $script:FluxHandlers.CrosshairToggle = {
        param($sender, $e)
        if ($script:FluxUi.SyncingCrosshair) { return }
        Set-FluxCrosshairEnabled ([bool]$sender.IsChecked)
    }
    $script:FluxHandlers.CrosshairStyle = {
        param($sender, $e)
        if ($script:FluxUi.SyncingCrosshair) { return }
        Set-FluxCrosshairStyle ([string]$sender.Tag)
    }
    $script:FluxHandlers.CrosshairSize = {
        param($sender, $e)
        if ($script:FluxUi.SyncingCrosshair) { return }
        Set-FluxCrosshairSize ([int]$sender.Tag)
    }
    $script:FluxHandlers.CrosshairColor = {
        param($sender, $e)
        if ($script:FluxUi.SyncingCrosshair) { return }
        Set-FluxCrosshairColor ([string]$sender.Tag)
    }
    $script:FluxHandlers.CrosshairHex = {
        param($sender, $e)
        Apply-FluxCrosshairHex
    }
    $script:FluxHandlers.CrosshairOpacity = {
        param($sender, $e)
        if ($script:FluxUi.SyncingCrosshair) { return }
        Set-FluxCrosshairOpacity ([double]$sender.Value)
    }
    $script:FluxHandlers.CrosshairOutline = {
        param($sender, $e)
        if ($script:FluxUi.SyncingCrosshair) { return }
        $cfg = Get-FluxCrosshairConfig
        $cfg.outline = [bool]$sender.IsChecked
        Save-FluxCrosshair
        Update-FluxCrosshairVisuals
    }
    $script:FluxHandlers.CrosshairTopmost = {
        param($sender, $e)
        if ($script:FluxUi.SyncingCrosshair) { return }
        $cfg = Get-FluxCrosshairConfig
        $cfg.topmost = [bool]$sender.IsChecked
        Save-FluxCrosshair
        Update-FluxCrosshairVisuals
        if ($script:FluxUi.CrosshairOverlay) { $script:FluxUi.CrosshairOverlay.Topmost = [bool]$cfg.topmost }
    }
    $script:FluxHandlers.SavePreset = {
        param($sender, $e)
        Save-FluxCrosshairPreset
    }
    $script:FluxHandlers.PresetApply = {
        param($sender, $e)
        Apply-FluxCrosshairPreset ([string]$sender.Tag)
    }
    $script:FluxHandlers.PresetDelete = {
        param($sender, $e)
        Delete-FluxCrosshairPreset ([string]$sender.Tag)
    }
    $script:FluxHandlers.StudioClose = {
        param($sender, $e)
        Hide-FluxOverlay
    }
    $script:FluxHandlers.StudioReset = {
        param($sender, $e)
        Reset-FluxCrosshair
    }
}

function New-FluxCrosshairCard {
    param($Section)
    $ui = $script:FluxUi
    $shell = New-FluxSectionShell -Section $Section
    $shell.CountText.Text = 'Overlay off'
    $ui.CrosshairCardCount = $shell.CountText

    $grid = New-Object System.Windows.Controls.Grid
    $colPreview = New-Object System.Windows.Controls.ColumnDefinition
    $colPreview.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
    $colMain = New-Object System.Windows.Controls.ColumnDefinition
    $colMain.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add($colPreview)
    $grid.ColumnDefinitions.Add($colMain)

    $preview = New-Object System.Windows.Controls.Border
    $preview.Width = 154
    $preview.Height = 154
    $preview.CornerRadius = [System.Windows.CornerRadius]::new(13)
    $preview.Background = New-Object System.Windows.Media.SolidColorBrush (ConvertTo-FluxMediaColor '#0C0B09')
    $preview.BorderBrush = Get-FluxUiBrush 'BorderSoft'
    $preview.BorderThickness = [System.Windows.Thickness]::new(1)
    $preview.VerticalAlignment = 'Center'
    $canvas = New-Object System.Windows.Controls.Canvas
    $canvas.Width = 154
    $canvas.Height = 154
    $preview.Child = $canvas
    $ui.CrosshairCardCanvas = $canvas
    $grid.Children.Add($preview) | Out-Null

    $main = New-Object System.Windows.Controls.StackPanel
    $main.Margin = [System.Windows.Thickness]::new(16, 3, 0, 0)
    $main.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($main, 1)

    $statusRow = New-Object System.Windows.Controls.StackPanel
    $statusRow.Orientation = 'Horizontal'
    $ui.CrosshairCardStatusDot = New-Object System.Windows.Shapes.Ellipse
    $ui.CrosshairCardStatusDot.Width = 7
    $ui.CrosshairCardStatusDot.Height = 7
    $ui.CrosshairCardStatusDot.Fill = Get-FluxUiBrush 'TextTertiary'
    $ui.CrosshairCardStatusDot.VerticalAlignment = 'Center'
    $statusRow.Children.Add($ui.CrosshairCardStatusDot) | Out-Null
    $ui.CrosshairCardStatus = New-FluxUiText -Text 'Overlay is off' -ColorKey 'TextSecondary' -Size 11 -Weight SemiBold
    $ui.CrosshairCardStatus.Margin = [System.Windows.Thickness]::new(7, 0, 0, 0)
    $statusRow.Children.Add($ui.CrosshairCardStatus) | Out-Null
    $main.Children.Add($statusRow) | Out-Null

    $ui.CrosshairCardType = New-FluxUiText -Text 'Cross · 16 px' -ColorKey 'TextPrimary' -Size 13 -Weight SemiBold
    $ui.CrosshairCardType.Margin = [System.Windows.Thickness]::new(0, 6, 0, 0)
    $main.Children.Add($ui.CrosshairCardType) | Out-Null

    $hint = New-FluxUiText -Text 'F6 toggles the crosshair globally. Studio tunes style, size, colour and opacity. Use borderless or windowed fullscreen over the game.' -ColorKey 'TextSecondary' -Size 10.5
    $hint.TextWrapping = 'Wrap'
    $hint.MaxWidth = 620
    $hint.Margin = [System.Windows.Thickness]::new(0, 5, 0, 0)
    $main.Children.Add($hint) | Out-Null

    $controls = New-Object System.Windows.Controls.StackPanel
    $controls.Orientation = 'Horizontal'
    $controls.Margin = [System.Windows.Thickness]::new(0, 11, 0, 0)
    $studio = New-FluxUiButton -Text 'Open studio' -StyleKey 'PrimaryButton' -TagValue 'crosshair:studio' -Handler 'CrosshairStudio' -MinWidth 108
    $studio.Padding = [System.Windows.Thickness]::new(14, 8, 14, 8)
    $studio.FontSize = 11
    $controls.Children.Add($studio) | Out-Null
    $ui.CrosshairCardSwitch = New-Object System.Windows.Controls.CheckBox
    $ui.CrosshairCardSwitch.Content = 'Show overlay (F6)'
    $ui.CrosshairCardSwitch.Style = $ui.Window.Resources['FluxSwitch']
    $ui.CrosshairCardSwitch.Margin = [System.Windows.Thickness]::new(16, 0, 0, 0)
    $ui.CrosshairCardSwitch.VerticalAlignment = 'Center'
    $ui.CrosshairCardSwitch.Add_Checked($script:FluxHandlers.CrosshairToggle)
    $ui.CrosshairCardSwitch.Add_Unchecked($script:FluxHandlers.CrosshairToggle)
    $controls.Children.Add($ui.CrosshairCardSwitch) | Out-Null
    $main.Children.Add($controls) | Out-Null

    $grid.Children.Add($main) | Out-Null
    $shell.Body.Children.Add($grid) | Out-Null

    $ui.SectionViews[9] = @{ Card = $shell.Card; CountText = $shell.CountText; ToggleIds = @(); Buttons = $shell.ButtonPanel }
    return $shell.Card
}

function Initialize-FluxCrosshairStudio {
    $ui = $script:FluxUi
    if (-not $ui.StyleChips) { return }

    foreach ($style in $script:FluxCrosshairStyles) {
        $chip = New-Object System.Windows.Controls.RadioButton
        $chip.Content = $style
        $chip.Tag = $style
        $chip.GroupName = 'FluxCrosshairStyle'
        $chip.Style = $ui.Window.Resources['Chip']
        $chip.Add_Checked($script:FluxHandlers.CrosshairStyle)
        $ui.StyleChips.Children.Add($chip) | Out-Null
    }

    foreach ($size in $script:FluxCrosshairSizes) {
        $chip = New-Object System.Windows.Controls.RadioButton
        $chip.Content = "$size px"
        $chip.Tag = [string]$size
        $chip.GroupName = 'FluxCrosshairSize'
        $chip.Style = $ui.Window.Resources['Chip']
        $chip.Add_Checked($script:FluxHandlers.CrosshairSize)
        $ui.SizeChips.Children.Add($chip) | Out-Null
    }

    foreach ($hex in $script:FluxCrosshairColors) {
        $chip = New-Object System.Windows.Controls.RadioButton
        $chip.Tag = $hex
        $chip.GroupName = 'FluxCrosshairColor'
        $chip.Style = $ui.Window.Resources['ColorChip']
        $color = ConvertTo-FluxMediaColor $hex
        $chip.Background = New-Object System.Windows.Media.SolidColorBrush $color
        $chip.ToolTip = $hex
        $chip.Add_Checked($script:FluxHandlers.CrosshairColor)
        $ui.ColorChips.Children.Add($chip) | Out-Null
    }

    $ui.ColorApplyButton.Add_Click($script:FluxHandlers.CrosshairHex)
    $ui.ColorHexBox.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Return) {
            Apply-FluxCrosshairHex
            $e.Handled = $true
        }
    })
    $ui.OpacitySlider.Add_ValueChanged($script:FluxHandlers.CrosshairOpacity)
    $ui.OutlineCheck.Add_Checked($script:FluxHandlers.CrosshairOutline)
    $ui.OutlineCheck.Add_Unchecked($script:FluxHandlers.CrosshairOutline)
    $ui.TopmostCheck.Add_Checked($script:FluxHandlers.CrosshairTopmost)
    $ui.TopmostCheck.Add_Unchecked($script:FluxHandlers.CrosshairTopmost)
    $ui.OverlayEnabledCheck.Add_Checked($script:FluxHandlers.CrosshairToggle)
    $ui.OverlayEnabledCheck.Add_Unchecked($script:FluxHandlers.CrosshairToggle)
    $ui.SavePresetButton.Add_Click($script:FluxHandlers.SavePreset)
    $ui.StudioResetButton.Add_Click($script:FluxHandlers.StudioReset)
    $ui.StudioCloseButton.Add_Click($script:FluxHandlers.StudioClose)
    $ui.StudioDoneButton.Add_Click($script:FluxHandlers.StudioClose)

    Sync-FluxCrosshairUi
}

function Open-FluxCrosshairStudio {
    $ui = $script:FluxUi
    Sync-FluxCrosshairUi
    Show-FluxOverlay -View $ui.StudioView -Width 900
}

function Set-FluxCrosshairEnabled {
    param([bool]$Enabled)
    $cfg = Get-FluxCrosshairConfig
    $cfg.enabled = $Enabled
    Save-FluxCrosshair
    if ($Enabled) { Show-FluxCrosshairOverlay } else { Hide-FluxCrosshairOverlay }
    Sync-FluxCrosshairUi
    if ($Enabled) { Set-FluxStatus 'Crosshair overlay on. F6 hides it.' 'Ready' }
    else { Set-FluxStatus 'Crosshair overlay hidden. F6 shows it.' 'Ready' }
}

function Toggle-FluxCrosshair {
    $cfg = Get-FluxCrosshairConfig
    Set-FluxCrosshairEnabled (-not [bool]$cfg.enabled)
}

function Set-FluxCrosshairStyle {
    param([string]$Style)
    if ($script:FluxCrosshairStyles -notcontains $Style) { return }
    $cfg = Get-FluxCrosshairConfig
    $cfg.style = $Style
    Save-FluxCrosshair
    Sync-FluxCrosshairUi
}

function Set-FluxCrosshairSize {
    param([int]$Size)
    if ($script:FluxCrosshairSizes -notcontains $Size) { return }
    $cfg = Get-FluxCrosshairConfig
    $cfg.size = $Size
    Save-FluxCrosshair
    Sync-FluxCrosshairUi
}

function Set-FluxCrosshairColor {
    param([string]$Hex)
    $cfg = Get-FluxCrosshairConfig
    $cfg.color = ([string]$Hex).ToUpperInvariant()
    Save-FluxCrosshair
    Sync-FluxCrosshairUi
}

function Set-FluxCrosshairOpacity {
    param([double]$Opacity)
    $cfg = Get-FluxCrosshairConfig
    $cfg.opacity = [math]::Round($Opacity, 2)
    Save-FluxCrosshair
    Update-FluxCrosshairVisuals
    if ($script:FluxUi.OpacityLabel) { $script:FluxUi.OpacityLabel.Text = "$([int][math]::Round($Opacity * 100))%" }
}

function Apply-FluxCrosshairHex {
    $ui = $script:FluxUi
    $raw = [string]$ui.ColorHexBox.Text
    if (-not $raw) { return }
    $raw = $raw.Trim()
    if (-not $raw.StartsWith('#')) { $raw = '#' + $raw }
    try {
        $color = [System.Windows.Media.ColorConverter]::ConvertFromString($raw)
        $hex = ('#%02X%02X%02X' -f $color.R, $color.G, $color.B)
    }
    catch {
        Set-FluxStatus 'Use a hex colour like #D4AF37.' 'Warning'
        return
    }
    Set-FluxCrosshairColor $hex
}

function Sync-FluxCrosshairUi {
    $ui = $script:FluxUi
    if (-not $ui.StyleChips) { return }
    $cfg = Get-FluxCrosshairConfig
    $ui.SyncingCrosshair = $true
    try {
        foreach ($chip in @($ui.StyleChips.Children)) { $chip.IsChecked = ([string]$chip.Tag -eq [string]$cfg.style) }
        foreach ($chip in @($ui.SizeChips.Children)) { $chip.IsChecked = ([int]$chip.Tag -eq [int]$cfg.size) }
        $matchedColor = $false
        foreach ($chip in @($ui.ColorChips.Children)) {
            $isMatch = ([string]$chip.Tag -ieq [string]$cfg.color)
            $chip.IsChecked = $isMatch
            if ($isMatch) { $matchedColor = $true }
        }
        $ui.ColorHexBox.Text = [string]$cfg.color
        $ui.OpacitySlider.Value = [double]$cfg.opacity
        $ui.OpacityLabel.Text = "$([int][math]::Round([double]$cfg.opacity * 100))%"
        $ui.OutlineCheck.IsChecked = [bool]$cfg.outline
        $ui.TopmostCheck.IsChecked = [bool]$cfg.topmost
        if ($ui.CrosshairCardSwitch) { $ui.CrosshairCardSwitch.IsChecked = [bool]$cfg.enabled }
        if ($ui.OverlayEnabledCheck) { $ui.OverlayEnabledCheck.IsChecked = [bool]$cfg.enabled }
        Update-FluxCrosshairVisuals
    }
    finally { $ui.SyncingCrosshair = $false }
}

function Update-FluxCrosshairVisuals {
    $ui = $script:FluxUi
    $cfg = Get-FluxCrosshairConfig
    $enabled = [bool]$cfg.enabled
    if ($ui.CrosshairCardCanvas) { Draw-FluxCrosshair -Canvas $ui.CrosshairCardCanvas -Config $cfg -Scale 2.3 }
    if ($ui.StudioPreviewCanvas) { Draw-FluxCrosshair -Canvas $ui.StudioPreviewCanvas -Config $cfg -Scale 5.0 }
    if ($ui.CrosshairCanvas -and $ui.CrosshairOverlay -and $ui.CrosshairOverlay.IsVisible) {
        Draw-FluxCrosshair -Canvas $ui.CrosshairCanvas -Config $cfg -Scale 1.0
    }
    if ($ui.CrosshairCardType) { $ui.CrosshairCardType.Text = "$($cfg.style) · $([int]$cfg.size) px" }
    if ($ui.CrosshairCardStatus) { $ui.CrosshairCardStatus.Text = if ($enabled) { 'Overlay is live' } else { 'Overlay is off' } }
    if ($ui.CrosshairCardStatusDot) { $ui.CrosshairCardStatusDot.Fill = Get-FluxUiBrush $(if ($enabled) { 'Success' } else { 'TextTertiary' }) }
    if ($ui.CrosshairCardCount) { $ui.CrosshairCardCount.Text = if ($enabled) { 'Overlay live · F6 hides' } else { 'Overlay off · F6 shows' } }
    if ($ui.StudioSizeLabel) { $ui.StudioSizeLabel.Text = "$([int]$cfg.size) px" }
    if ($ui.CrosshairOverlay) { $ui.CrosshairOverlay.Topmost = [bool]$cfg.topmost }
}

function New-FluxCrosshairContext {
    param($Config, [double]$Scale)
    $alpha = [int](255 * [double]$Config.opacity)
    if ($alpha -lt 0) { $alpha = 0 }
    if ($alpha -gt 255) { $alpha = 255 }
    $color = ConvertTo-FluxMediaColor ([string]$Config.color)
    $mainColor = [System.Windows.Media.Color]::FromArgb([byte]$alpha, $color.R, $color.G, $color.B)
    $outlineColor = [System.Windows.Media.Color]::FromArgb([byte][math]::Min(205, [int]($alpha * 0.7)), 0, 0, 0)
    return @{
        Main = New-Object System.Windows.Media.SolidColorBrush $mainColor
        Outline = New-Object System.Windows.Media.SolidColorBrush $outlineColor
        Scale = $Scale
    }
}

function Add-FluxCrosshairLine {
    param($Canvas, [double]$X1, [double]$Y1, [double]$X2, [double]$Y2, [double]$Thickness, $Ctx, [bool]$Outline)
    $line = New-Object System.Windows.Shapes.Line
    $line.X1 = $X1; $line.Y1 = $Y1; $line.X2 = $X2; $line.Y2 = $Y2
    $line.StrokeThickness = if ($Outline) { $Thickness + [math]::Max(1.4, $Thickness * 0.8) } else { $Thickness }
    $line.Stroke = if ($Outline) { $Ctx.Outline } else { $Ctx.Main }
    $line.StrokeStartLineCap = [System.Windows.Media.PenLineCap]::Round
    $line.StrokeEndLineCap = [System.Windows.Media.PenLineCap]::Round
    $Canvas.Children.Add($line) | Out-Null
}

function Add-FluxCrosshairPoly {
    param($Canvas, [double[]]$Values, [double]$Thickness, $Ctx, [bool]$Outline, [bool]$Closed)
    if ($Closed) { $shape = New-Object System.Windows.Shapes.Polygon }
    else { $shape = New-Object System.Windows.Shapes.Polyline }
    $points = New-Object System.Windows.Media.PointCollection
    for ($i = 0; $i + 1 -lt $Values.Count; $i += 2) {
        $points.Add([System.Windows.Point]::new($Values[$i], $Values[$i + 1]))
    }
    $shape.Points = $points
    $shape.StrokeThickness = if ($Outline) { $Thickness + [math]::Max(1.4, $Thickness * 0.8) } else { $Thickness }
    $shape.Stroke = if ($Outline) { $Ctx.Outline } else { $Ctx.Main }
    $shape.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
    $shape.StrokeStartLineCap = [System.Windows.Media.PenLineCap]::Round
    $shape.StrokeEndLineCap = [System.Windows.Media.PenLineCap]::Round
    $Canvas.Children.Add($shape) | Out-Null
}

function Add-FluxCrosshairEllipse {
    param($Canvas, [double]$Cx, [double]$Cy, [double]$Rx, [double]$Ry, [double]$Thickness, $Ctx, [bool]$Outline, [bool]$Fill)
    $ellipse = New-Object System.Windows.Shapes.Ellipse
    $ellipse.Width = $Rx * 2
    $ellipse.Height = $Ry * 2
    [System.Windows.Controls.Canvas]::SetLeft($ellipse, $Cx - $Rx)
    [System.Windows.Controls.Canvas]::SetTop($ellipse, $Cy - $Ry)
    if ($Fill) {
        $ellipse.Fill = if ($Outline) { $Ctx.Outline } else { $Ctx.Main }
    }
    else {
        $ellipse.StrokeThickness = if ($Outline) { $Thickness + [math]::Max(1.4, $Thickness * 0.8) } else { $Thickness }
        $ellipse.Stroke = if ($Outline) { $Ctx.Outline } else { $Ctx.Main }
    }
    $Canvas.Children.Add($ellipse) | Out-Null
}

function Draw-FluxCrosshair {
    param($Canvas, $Config, [double]$Scale = 1.0)
    if (-not $Canvas) { return }
    $Canvas.Children.Clear()
    $width = [double]$Canvas.Width
    if ([double]::IsNaN($width) -or $width -le 0) { $width = $Canvas.ActualWidth }
    $height = [double]$Canvas.Height
    if ([double]::IsNaN($height) -or $height -le 0) { $height = $Canvas.ActualHeight }
    $cx = $width / 2
    $cy = $height / 2
    $ctx = New-FluxCrosshairContext -Config $Config -Scale $Scale
    $outline = [bool]$Config.outline
    $s = [double]$Config.size * $Scale
    $gap = [math]::Max(1.2 * $Scale, $s * 0.22)
    $thickness = [math]::Max(1.0, $s * 0.10)
    $style = [string]$Config.style

    switch ($style) {
        'Cross' {
            foreach ($outlinePass in @($true, $false)) {
                if (-not $outline -and $outlinePass) { continue }
                Add-FluxCrosshairLine $Canvas ($cx + $gap) $cy ($cx + $s) $cy $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas ($cx - $s) $cy ($cx - $gap) $cy $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas $cx ($cy + $gap) $cx ($cy + $s) $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas $cx ($cy - $s) $cx ($cy - $gap) $thickness $ctx $outlinePass
            }
        }
        'Dot' {
            $r = [math]::Max(1.6 * $Scale, $s * 0.16)
            if ($outline) { Add-FluxCrosshairEllipse $Canvas $cx $cy ($r + [math]::Max(1.0, $thickness * 0.7)) ($r + [math]::Max(1.0, $thickness * 0.7)) $thickness $ctx $true $true }
            Add-FluxCrosshairEllipse $Canvas $cx $cy $r $r $thickness $ctx $false $true
        }
        'Circle' {
            $r = $s * 0.82
            if ($outline) { Add-FluxCrosshairEllipse $Canvas $cx $cy $r $r $thickness $ctx $true $false }
            Add-FluxCrosshairEllipse $Canvas $cx $cy $r $r $thickness $ctx $false $false
        }
        'Cross + Circle' {
            $r = $s * 0.92
            if ($outline) { Add-FluxCrosshairEllipse $Canvas $cx $cy $r $r $thickness $ctx $true $false }
            Add-FluxCrosshairEllipse $Canvas $cx $cy $r $r $thickness $ctx $false $false
            foreach ($outlinePass in @($true, $false)) {
                if (-not $outline -and $outlinePass) { continue }
                Add-FluxCrosshairLine $Canvas ($cx + $gap) $cy ($cx + $s * 0.58) $cy $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas ($cx - $s * 0.58) $cy ($cx - $gap) $cy $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas $cx ($cy + $gap) $cx ($cy + $s * 0.58) $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas $cx ($cy - $s * 0.58) $cx ($cy - $gap) $thickness $ctx $outlinePass
            }
        }
        'T' {
            foreach ($outlinePass in @($true, $false)) {
                if (-not $outline -and $outlinePass) { continue }
                Add-FluxCrosshairLine $Canvas ($cx - $s) $cy ($cx + $s) $cy $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas $cx ($cy - $s) $cx ($cy - $gap * 0.6) $thickness $ctx $outlinePass
            }
        }
        'X' {
            $d = $s * 0.68
            foreach ($outlinePass in @($true, $false)) {
                if (-not $outline -and $outlinePass) { continue }
                Add-FluxCrosshairLine $Canvas ($cx - $d) ($cy - $d) ($cx - $gap * 0.7) ($cy - $gap * 0.7) $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas ($cx + $gap * 0.7) ($cy + $gap * 0.7) ($cx + $d) ($cy + $d) $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas ($cx + $gap * 0.7) ($cy - $gap * 0.7) ($cx + $d) ($cy - $d) $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas ($cx - $d) ($cy + $d) ($cx - $gap * 0.7) ($cy + $gap * 0.7) $thickness $ctx $outlinePass
            }
        }
        'Square' {
            $h = $s * 0.68
            $points = @($cx - $h, $cy - $h, $cx + $h, $cy - $h, $cx + $h, $cy + $h, $cx - $h, $cy + $h)
            if ($outline) { Add-FluxCrosshairPoly $Canvas $points $thickness $ctx $true $true }
            Add-FluxCrosshairPoly $Canvas $points $thickness $ctx $false $true
        }
        'Bracket' {
            $h = $s * 0.78
            $len = $s * 0.46
            $corners = @(
                @($cx - $h, ($cy - $h) + $len, $cx - $h, $cy - $h, ($cx - $h) + $len, $cy - $h),
                @(($cx + $h) - $len, $cy - $h, $cx + $h, $cy - $h, $cx + $h, ($cy - $h) + $len),
                @($cx - $h, ($cy + $h) - $len, $cx - $h, $cy + $h, ($cx - $h) + $len, $cy + $h),
                @(($cx + $h) - $len, $cy + $h, $cx + $h, $cy + $h, $cx + $h, ($cy + $h) - $len)
            )
            foreach ($corner in $corners) {
                if ($outline) { Add-FluxCrosshairPoly $Canvas $corner $thickness $ctx $true $false }
                Add-FluxCrosshairPoly $Canvas $corner $thickness $ctx $false $false
            }
        }
        'Diamond' {
            $d = $s * 0.82
            $points = @($cx, $cy - $d, $cx + $d, $cy, $cx, $cy + $d, $cx - $d, $cy)
            if ($outline) { Add-FluxCrosshairPoly $Canvas $points $thickness $ctx $true $true }
            Add-FluxCrosshairPoly $Canvas $points $thickness $ctx $false $true
        }
        'Chevron' {
            $points = @($cx - $s * 0.7, $cy + $s * 0.22, $cx, $cy - $s * 0.45, $cx + $s * 0.7, $cy + $s * 0.22)
            if ($outline) { Add-FluxCrosshairPoly $Canvas $points $thickness $ctx $true $false }
            Add-FluxCrosshairPoly $Canvas $points $thickness $ctx $false $false
        }
        default {
            foreach ($outlinePass in @($true, $false)) {
                if (-not $outline -and $outlinePass) { continue }
                Add-FluxCrosshairLine $Canvas ($cx + $gap) $cy ($cx + $s) $cy $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas ($cx - $s) $cy ($cx - $gap) $cy $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas $cx ($cy + $gap) $cx ($cy + $s) $thickness $ctx $outlinePass
                Add-FluxCrosshairLine $Canvas $cx ($cy - $s) $cx ($cy - $gap) $thickness $ctx $outlinePass
            }
        }
    }
}

function New-FluxCrosshairOverlayWindow {
    $ui = $script:FluxUi
    $overlay = New-Object System.Windows.Window
    $overlay.WindowStyle = [System.Windows.WindowStyle]::None
    $overlay.AllowsTransparency = $true
    $overlay.Background = [System.Windows.Media.Brushes]::Transparent
    $overlay.Topmost = $true
    $overlay.ShowInTaskbar = $false
    $overlay.ShowActivated = $false
    $overlay.Focusable = $false
    $overlay.ResizeMode = [System.Windows.ResizeMode]::NoResize
    $overlay.Width = 240
    $overlay.Height = 240
    $overlay.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
    $overlay.IsHitTestVisible = $false

    $canvas = New-Object System.Windows.Controls.Canvas
    $canvas.Width = 240
    $canvas.Height = 240
    $overlay.Content = $canvas
    $overlay.Add_Closed({
        param($sender, $e)
        $script:FluxUi.CrosshairOverlay = $null
        $script:FluxUi.CrosshairCanvas = $null
    })

    $ui.CrosshairOverlay = $overlay
    $ui.CrosshairCanvas = $canvas
}

function Position-FluxCrosshairOverlay {
    $overlay = $script:FluxUi.CrosshairOverlay
    if (-not $overlay) { return }
    try {
        $screenWidth = [System.Windows.SystemParameters]::PrimaryScreenWidth
        $screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight
        $overlay.Left = [math]::Round(($screenWidth - $overlay.Width) / 2)
        $overlay.Top = [math]::Round(($screenHeight - $overlay.Height) / 2)
    }
    catch { }
}

function Show-FluxCrosshairOverlay {
    $ui = $script:FluxUi
    $cfg = Get-FluxCrosshairConfig
    if (-not $ui.CrosshairOverlay) { New-FluxCrosshairOverlayWindow }
    $overlay = $ui.CrosshairOverlay
    $overlay.Topmost = [bool]$cfg.topmost
    Position-FluxCrosshairOverlay
    if (-not $overlay.IsVisible) {
        try { $overlay.Show() } catch { }
    }
    try {
        $helper = New-Object System.Windows.Interop.WindowInteropHelper($overlay)
        [FluxNative]::MakeOverlay($helper.Handle)
    }
    catch { }
    if ($ui.CrosshairCanvas) { Draw-FluxCrosshair -Canvas $ui.CrosshairCanvas -Config $cfg -Scale 1.0 }
}

function Hide-FluxCrosshairOverlay {
    $ui = $script:FluxUi
    if ($ui.CrosshairOverlay -and $ui.CrosshairOverlay.IsVisible) {
        try { $ui.CrosshairOverlay.Hide() } catch { }
    }
}

function Sync-FluxPresetChips {
    $ui = $script:FluxUi
    if (-not $ui.PresetChips) { return }
    $ui.PresetChips.Children.Clear()
    $cfg = Get-FluxCrosshairConfig
    $presets = @($cfg.presets)
    if ($presets.Count -eq 0) {
        $none = New-FluxUiText -Text 'No presets saved yet.' -ColorKey 'TextTertiary' -Size 10.5
        $none.Margin = [System.Windows.Thickness]::new(0, 3, 0, 6)
        $ui.PresetChips.Children.Add($none) | Out-Null
        return
    }
    foreach ($preset in $presets) {
        $border = New-Object System.Windows.Controls.Border
        $border.Background = Get-FluxUiBrush 'SurfaceAlt'
        $border.BorderBrush = Get-FluxUiBrush 'BorderSoft'
        $border.BorderThickness = [System.Windows.Thickness]::new(1)
        $border.CornerRadius = [System.Windows.CornerRadius]::new(8)
        $border.Padding = [System.Windows.Thickness]::new(3, 2, 3, 2)
        $border.Margin = [System.Windows.Thickness]::new(0, 0, 6, 6)
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Orientation = 'Horizontal'
        $name = [string]$preset.name
        $apply = New-FluxUiButton -Text $name -StyleKey 'GhostButton' -TagValue $name -Handler 'PresetApply'
        $apply.FontSize = 10
        $apply.Padding = [System.Windows.Thickness]::new(6, 4, 6, 4)
        $row.Children.Add($apply) | Out-Null
        $delete = New-FluxUiButton -Text ([string][char]0xE711) -StyleKey 'GhostButton' -TagValue $name -Handler 'PresetDelete'
        $delete.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe MDL2 Assets')
        $delete.FontSize = 8
        $delete.Padding = [System.Windows.Thickness]::new(4, 4, 4, 4)
        $delete.ToolTip = "Delete preset $name"
        $row.Children.Add($delete) | Out-Null
        $border.Child = $row
        $ui.PresetChips.Children.Add($border) | Out-Null
    }
}

function Save-FluxCrosshairPreset {
    $ui = $script:FluxUi
    $cfg = Get-FluxCrosshairConfig
    $name = ([string]$ui.PresetNameBox.Text).Trim()
    if (-not $name) { $name = 'My crosshair' }
    $snapshot = @{
        name = $name; style = [string]$cfg.style; size = [int]$cfg.size
        color = [string]$cfg.color; opacity = [double]$cfg.opacity; outline = [bool]$cfg.outline
    }
    $list = @()
    $replaced = $false
    foreach ($preset in @($cfg.presets)) {
        if ([string]$preset.name -ieq $name) { $list += $snapshot; $replaced = $true }
        else { $list += $preset }
    }
    if (-not $replaced) { $list += $snapshot }
    if ($list.Count -gt 12) { $list = @($list[($list.Count - 12)..($list.Count - 1)]) }
    $cfg.presets = @($list)
    Save-FluxCrosshair
    Sync-FluxPresetChips
    Set-FluxStatus "Crosshair preset '$name' saved." 'Ready'
}

function Apply-FluxCrosshairPreset {
    param([string]$Name)
    $cfg = Get-FluxCrosshairConfig
    $preset = $null
    foreach ($item in @($cfg.presets)) { if ([string]$item.name -ieq $Name) { $preset = $item; break } }
    if (-not $preset) { return }
    $cfg.style = [string]$preset.style
    $cfg.size = [int]$preset.size
    $cfg.color = ([string]$preset.color).ToUpperInvariant()
    $cfg.opacity = [double]$preset.opacity
    $cfg.outline = [bool]$preset.outline
    Save-FluxCrosshair
    Sync-FluxCrosshairUi
    Set-FluxStatus "Preset '$Name' applied." 'Ready'
}

function Delete-FluxCrosshairPreset {
    param([string]$Name)
    $cfg = Get-FluxCrosshairConfig
    $cfg.presets = @($cfg.presets | Where-Object { [string]$_.name -ine $Name })
    Save-FluxCrosshair
    Sync-FluxPresetChips
    Set-FluxStatus "Preset '$Name' deleted." 'Ready'
}

function Reset-FluxCrosshair {
    $cfg = Get-FluxCrosshairConfig
    $cfg.style = 'Cross'
    $cfg.size = 16
    $cfg.color = '#D4AF37'
    $cfg.opacity = 0.95
    $cfg.outline = $true
    $cfg.topmost = $true
    Save-FluxCrosshair
    Sync-FluxCrosshairUi
    Set-FluxStatus 'Crosshair reset to Flux gold.' 'Ready'
}

function Initialize-FluxCrosshairUi {
    Sync-FluxPresetChips
    Sync-FluxCrosshairUi
    Update-FluxCrosshairVisuals
    $cfg = Get-FluxCrosshairConfig
    if ($cfg.enabled) { Show-FluxCrosshairOverlay } else { Hide-FluxCrosshairOverlay }
}
