# Flux.UI.Sections.ps1 — section cards, tweak rows and status painting.

function New-FluxSectionShell {
    param($Section)
    $ui = $script:FluxUi
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $ui.Window.Resources['Card']
    $card.Margin = [System.Windows.Thickness]::new(0, 0, 0, 14)

    $inner = New-Object System.Windows.Controls.StackPanel
    $card.Child = $inner

    $header = New-Object System.Windows.Controls.Grid
    $header.Margin = [System.Windows.Thickness]::new(20, 17, 20, 14)
    $colNum = New-Object System.Windows.Controls.ColumnDefinition
    $colNum.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
    $colMain = New-Object System.Windows.Controls.ColumnDefinition
    $colMain.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $colButtons = New-Object System.Windows.Controls.ColumnDefinition
    $colButtons.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
    $header.ColumnDefinitions.Add($colNum)
    $header.ColumnDefinitions.Add($colMain)
    $header.ColumnDefinitions.Add($colButtons)

    $numberBorder = New-Object System.Windows.Controls.Border
    $numberBorder.Width = 34
    $numberBorder.Height = 34
    $numberBorder.CornerRadius = [System.Windows.CornerRadius]::new(10)
    $numberBorder.Background = Get-FluxUiBrush 'GoldSoft'
    $numberBorder.VerticalAlignment = 'Top'
    $numberText = New-FluxUiText -Text ([int]$Section.No).ToString('00') -ColorKey 'GoldDeep' -Size 11 -Weight SemiBold
    $numberText.HorizontalAlignment = 'Center'
    $numberText.VerticalAlignment = 'Center'
    $numberBorder.Child = $numberText
    $header.Children.Add($numberBorder) | Out-Null

    $titleStack = New-Object System.Windows.Controls.StackPanel
    $titleStack.Margin = [System.Windows.Thickness]::new(12, 1, 12, 0)
    $title = New-FluxUiText -Text ([string]$Section.Title) -StyleKey 'H2' -Size 17
    $titleStack.Children.Add($title) | Out-Null
    $blurb = New-FluxUiText -Text ([string]$Section.Blurb) -ColorKey 'TextSecondary' -Size 11
    $blurb.TextWrapping = 'Wrap'
    $blurb.Margin = [System.Windows.Thickness]::new(0, 3, 0, 0)
    $titleStack.Children.Add($blurb) | Out-Null
    $countText = New-FluxUiText -Text '' -ColorKey 'TextTertiary' -Size 9.5
    $countText.Margin = [System.Windows.Thickness]::new(0, 5, 0, 0)
    $titleStack.Children.Add($countText) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($titleStack, 1)
    $header.Children.Add($titleStack) | Out-Null

    $buttons = New-Object System.Windows.Controls.StackPanel
    $buttons.Orientation = 'Horizontal'
    $buttons.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($buttons, 2)
    $header.Children.Add($buttons) | Out-Null

    $inner.Children.Add($header) | Out-Null
    $divider = New-Object System.Windows.Controls.Border
    $divider.Height = 1
    $divider.Background = Get-FluxUiBrush 'BorderSoft'
    $inner.Children.Add($divider) | Out-Null

    $body = New-Object System.Windows.Controls.StackPanel
    $body.Margin = [System.Windows.Thickness]::new(20, 12, 20, 16)
    $inner.Children.Add($body) | Out-Null

    return @{ Card = $card; Body = $body; CountText = $countText; ButtonPanel = $buttons }
}

function New-FluxTweakRow {
    param($Tweak)
    $ui = $script:FluxUi

    $row = New-Object System.Windows.Controls.Border
    $row.Background = Get-FluxUiBrush 'SurfaceAlt'
    $row.BorderBrush = Get-FluxUiBrush 'BorderSoft'
    $row.BorderThickness = [System.Windows.Thickness]::new(1)
    $row.CornerRadius = [System.Windows.CornerRadius]::new(12)
    $row.Padding = [System.Windows.Thickness]::new(14, 11, 12, 11)
    $row.Margin = [System.Windows.Thickness]::new(0, 0, 0, 7)

    $grid = New-Object System.Windows.Controls.Grid
    $colStatus = New-Object System.Windows.Controls.ColumnDefinition
    $colStatus.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
    $colMain = New-Object System.Windows.Controls.ColumnDefinition
    $colMain.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $colChips = New-Object System.Windows.Controls.ColumnDefinition
    $colChips.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
    $colInfo = New-Object System.Windows.Controls.ColumnDefinition
    $colInfo.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
    $colAction = New-Object System.Windows.Controls.ColumnDefinition
    $colAction.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
    $grid.ColumnDefinitions.Add($colStatus)
    $grid.ColumnDefinitions.Add($colMain)
    $grid.ColumnDefinitions.Add($colChips)
    $grid.ColumnDefinitions.Add($colInfo)
    $grid.ColumnDefinitions.Add($colAction)

    $status = New-FluxStatusPill
    $status.Border.VerticalAlignment = 'Center'
    $status.Border.Margin = [System.Windows.Thickness]::new(0, 0, 12, 0)
    $grid.Children.Add($status.Border) | Out-Null

    $main = New-Object System.Windows.Controls.StackPanel
    $main.VerticalAlignment = 'Center'
    $main.Margin = [System.Windows.Thickness]::new(0, 0, 10, 0)
    $name = New-FluxUiText -Text ([string]$Tweak.Name) -ColorKey 'TextPrimary' -Size 12.5 -Weight SemiBold
    $name.TextWrapping = 'Wrap'
    $main.Children.Add($name) | Out-Null
    $short = New-FluxUiText -Text ([string]$Tweak.Short) -ColorKey 'TextSecondary' -Size 10.5
    $short.TextWrapping = 'Wrap'
    $short.Margin = [System.Windows.Thickness]::new(0, 2, 0, 0)
    $main.Children.Add($short) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($main, 1)
    $grid.Children.Add($main) | Out-Null

    $chips = New-Object System.Windows.Controls.StackPanel
    $chips.Orientation = 'Horizontal'
    $chips.VerticalAlignment = 'Center'
    $risk = [string]$Tweak.Risk
    $bgKey = 'SuccessSoft'; $fgKey = 'Success'
    if ($risk -eq 'Caution') { $bgKey = 'WarningSoft'; $fgKey = 'Warning' }
    elseif ($risk -eq 'Risky') { $bgKey = 'DangerSoft'; $fgKey = 'Danger' }
    $riskPill = New-FluxUiPill -Text $risk -BgKey $bgKey -FgKey $fgKey -FontSize 9
    $riskPill.Border.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
    $riskPill.Border.ToolTip = "Risk: $risk"
    $chips.Children.Add($riskPill.Border) | Out-Null
    if ([bool]$Tweak.Restart) {
        $restartPill = New-FluxUiPill -Text 'Restart' -BgKey 'GoldSoft' -FgKey 'GoldDeep' -FontSize 9
        $restartPill.Border.ToolTip = 'Requires a restart or reboot for full effect.'
        $chips.Children.Add($restartPill.Border) | Out-Null
    }
    [System.Windows.Controls.Grid]::SetColumn($chips, 2)
    $grid.Children.Add($chips) | Out-Null

    $info = New-FluxUiButton -Text 'i' -StyleKey 'GhostButton' -TagValue ([string]$Tweak.Id) -Handler 'Info' -MinWidth 0
    $info.Width = 26
    $info.Height = 26
    $info.Padding = [System.Windows.Thickness]::new(0)
    $info.FontSize = 12
    $info.FontWeight = [System.Windows.FontWeights]::SemiBold
    $info.ToolTip = 'Explain this tweak'
    $info.Margin = [System.Windows.Thickness]::new(6, 0, 4, 0)
    $info.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($info, 3)
    $grid.Children.Add($info) | Out-Null

    $action = New-FluxUiButton -Text 'Apply' -StyleKey 'PrimaryButton' -TagValue ([string]$Tweak.Id) -Handler 'Tweak' -MinWidth 86
    $action.Padding = [System.Windows.Thickness]::new(12, 7, 12, 7)
    $action.FontSize = 10.5
    $action.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($action, 4)
    $grid.Children.Add($action) | Out-Null

    $row.Child = $grid
    $ui.TweakViews[[string]$Tweak.Id] = @{ Status = $status; Action = $action; Row = $row }

    $initial = $ui.StatusMap[[string]$Tweak.Id]
    if (-not $initial) {
        if ($Tweak.Kind -eq 'guide') { $initial = @{ State = 'Manual'; Label = 'Guided'; Detail = '' } }
        elseif ($Tweak.Kind -eq 'action') { $initial = @{ State = 'Action'; Label = 'Ready'; Detail = '' } }
        else { $initial = @{ State = 'NotRun'; Label = 'Not run'; Detail = '' } }
    }
    Update-FluxTweakView -Id ([string]$Tweak.Id) -Status $initial
    return $row
}

function Update-FluxTweakView {
    param([string]$Id, $Status)
    $ui = $script:FluxUi
    if (-not $ui.TweakViews.ContainsKey($Id)) { return }
    $view = $ui.TweakViews[$Id]
    $tweak = $ui.TweakCache[$Id]
    if (-not $tweak) { return }
    if (-not $Status) { $Status = @{ State = 'NotRun'; Label = 'Not run'; Detail = '' } }
    $state = [string]$Status.State
    $label = [string]$Status.Label
    if (-not $label) {
        $label = switch ($state) {
            'Applied' { 'Applied' }
            'Drifted' { 'Changed' }
            'Error' { 'Check failed' }
            'NA' { 'N/A' }
            'Manual' { 'Guided' }
            'Action' { 'Ready' }
            default { 'Not run' }
        }
    }
    Set-FluxStatusPill -Pill $view.Status -State $state -Label $label -Detail ([string]$Status.Detail)

    $action = $view.Action
    $busy = $ui.Busy -or $ui.ProcessBusy
    if ($tweak.Kind -eq 'guide') {
        $action.Content = 'Guide'
        $action.Style = $ui.Window.Resources['SecondaryButton']
        $action.IsEnabled = -not $busy
    }
    elseif ($tweak.Kind -eq 'action') {
        $action.Content = if ($tweak.ButtonLabel) { [string]$tweak.ButtonLabel } else { 'Run' }
        $action.Style = $ui.Window.Resources['PrimaryButton']
        $action.IsEnabled = -not $busy
    }
    else {
        switch ($state) {
            'Applied' { $action.Content = 'Restore'; $action.Style = $ui.Window.Resources['SecondaryButton']; $action.IsEnabled = -not $busy }
            'Drifted' { $action.Content = 'Re-apply'; $action.Style = $ui.Window.Resources['PrimaryButton']; $action.IsEnabled = -not $busy }
            'NA' { $action.Content = 'Unavailable'; $action.Style = $ui.Window.Resources['SecondaryButton']; $action.IsEnabled = $false }
            'Error' { $action.Content = 'Retry'; $action.Style = $ui.Window.Resources['PrimaryButton']; $action.IsEnabled = -not $busy }
            default { $action.Content = 'Apply'; $action.Style = $ui.Window.Resources['PrimaryButton']; $action.IsEnabled = -not $busy }
        }
    }
}

function Add-FluxSafetyStrip {
    param($Body)
    $ui = $script:FluxUi
    $divider = New-Object System.Windows.Controls.Border
    $divider.Height = 1
    $divider.Background = Get-FluxUiBrush 'BorderSoft'
    $divider.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
    $Body.Children.Add($divider) | Out-Null

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = [System.Windows.Thickness]::new(0, 12, 0, 0)
    $colLeft = New-Object System.Windows.Controls.ColumnDefinition
    $colLeft.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $colRight = New-Object System.Windows.Controls.ColumnDefinition
    $colRight.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
    $grid.ColumnDefinitions.Add($colLeft)
    $grid.ColumnDefinitions.Add($colRight)

    $left = New-Object System.Windows.Controls.StackPanel
    $left.Children.Add((New-FluxUiText -Text 'RECOVERY & BACKUPS' -StyleKey 'Overline' -ColorKey 'GoldDeep')) | Out-Null
    $ui.SafetyRestoreText = New-FluxUiText -Text 'Windows restore point: checking…' -ColorKey 'TextSecondary' -Size 10.5
    $ui.SafetyRestoreText.Margin = [System.Windows.Thickness]::new(0, 5, 0, 0)
    $left.Children.Add($ui.SafetyRestoreText) | Out-Null
    $ui.SafetyBackupText = New-FluxUiText -Text 'Flux backups: checking…' -ColorKey 'TextTertiary' -Size 10
    $ui.SafetyBackupText.Margin = [System.Windows.Thickness]::new(0, 2, 0, 0)
    $left.Children.Add($ui.SafetyBackupText) | Out-Null
    $grid.Children.Add($left) | Out-Null

    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $right.VerticalAlignment = 'Center'
    $openData = New-FluxUiButton -Text 'Open data folder' -StyleKey 'GhostButton' -Handler 'OpenData'
    $openData.FontSize = 10.5
    $right.Children.Add($openData) | Out-Null
    $openLog = New-FluxUiButton -Text 'Open log' -StyleKey 'GhostButton' -Handler 'OpenLog'
    $openLog.FontSize = 10.5
    $right.Children.Add($openLog) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($right, 1)
    $grid.Children.Add($right) | Out-Null

    $Body.Children.Add($grid) | Out-Null
}

function Build-FluxSections {
    $ui = $script:FluxUi
    $ui.SectionsPanel.Children.Clear()
    $ui.TweakViews = @{}
    $ui.SectionViews = @{}

    foreach ($section in @(Get-FluxSectionList)) {
        if ([int]$section.No -eq 9) {
            $card = New-FluxCrosshairCard -Section $section
            $ui.SectionsPanel.Children.Add($card) | Out-Null
            continue
        }
        if ([int]$section.No -eq 10) {
            $card = New-FluxProcessCard -Section $section
            $ui.SectionsPanel.Children.Add($card) | Out-Null
            continue
        }

        $tweaks = @(Get-FluxTweakCatalog | Where-Object { [int]$_.SectionNo -eq [int]$section.No })
        $shell = New-FluxSectionShell -Section $section
        $toggleIds = @($tweaks | Where-Object { $_.Kind -eq 'toggle' } | Select-Object -ExpandProperty Id)

        foreach ($tweak in $tweaks) {
            $shell.Body.Children.Add((New-FluxTweakRow -Tweak $tweak)) | Out-Null
        }

        if ($toggleIds.Count -gt 0) {
            $apply = New-FluxUiButton -Text 'Apply all' -StyleKey 'SmallButton' -TagValue "applysection:$($section.No)" -Handler 'Section'
            $apply.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
            $shell.ButtonPanel.Children.Add($apply) | Out-Null
            $restore = New-FluxUiButton -Text 'Restore all' -StyleKey 'GhostButton' -TagValue "restoresection:$($section.No)" -Handler 'Section'
            $restore.FontSize = 10.5
            $shell.ButtonPanel.Children.Add($restore) | Out-Null
        }

        if ([int]$section.No -eq 11) { Add-FluxSafetyStrip -Body $shell.Body }

        $ui.SectionViews[[int]$section.No] = @{
            Card = $shell.Card
            CountText = $shell.CountText
            ToggleIds = $toggleIds
            Buttons = $shell.ButtonPanel
        }
        $ui.SectionsPanel.Children.Add($shell.Card) | Out-Null
    }
}
