# Flux.UI.Processes.ps1 — process guard card, background app picker and close flow.

function New-FluxProcessCard {
    param($Section)
    $ui = $script:FluxUi
    $shell = New-FluxSectionShell -Section $Section
    $shell.CountText.Text = 'Guard off'

    $guardGrid = New-Object System.Windows.Controls.Grid
    $colLeft = New-Object System.Windows.Controls.ColumnDefinition
    $colLeft.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $colRight = New-Object System.Windows.Controls.ColumnDefinition
    $colRight.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
    $guardGrid.ColumnDefinitions.Add($colLeft)
    $guardGrid.ColumnDefinitions.Add($colRight)

    $guardText = New-Object System.Windows.Controls.StackPanel
    $guardText.VerticalAlignment = 'Center'
    $ui.GuardTitle = New-FluxUiText -Text 'Fortnite process guard' -ColorKey 'TextPrimary' -Size 12.5 -Weight SemiBold
    $guardText.Children.Add($ui.GuardTitle) | Out-Null
    $ui.GuardDetail = New-FluxUiText -Text 'Waiting for the guard to report in.' -ColorKey 'TextSecondary' -Size 10.5
    $ui.GuardDetail.TextWrapping = 'Wrap'
    $ui.GuardDetail.Margin = [System.Windows.Thickness]::new(0, 3, 0, 0)
    $guardText.Children.Add($ui.GuardDetail) | Out-Null
    $guardGrid.Children.Add($guardText) | Out-Null

    $guardControls = New-Object System.Windows.Controls.StackPanel
    $guardControls.Orientation = 'Horizontal'
    $guardControls.VerticalAlignment = 'Center'
    $ui.GuardSwitch = New-Object System.Windows.Controls.CheckBox
    $ui.GuardSwitch.Content = 'Guard on'
    $ui.GuardSwitch.Style = $ui.Window.Resources['FluxSwitch']
    $ui.GuardSwitch.Margin = [System.Windows.Thickness]::new(14, 0, 0, 0)
    $ui.GuardSwitch.Add_Checked($script:FluxHandlers.GuardToggle)
    $ui.GuardSwitch.Add_Unchecked($script:FluxHandlers.GuardToggle)
    $guardControls.Children.Add($ui.GuardSwitch) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($guardControls, 1)
    $guardGrid.Children.Add($guardControls) | Out-Null

    $guardBorder = New-Object System.Windows.Controls.Border
    $guardBorder.Background = Get-FluxUiBrush 'SurfaceAlt'
    $guardBorder.BorderBrush = Get-FluxUiBrush 'BorderSoft'
    $guardBorder.BorderThickness = [System.Windows.Thickness]::new(1)
    $guardBorder.CornerRadius = [System.Windows.CornerRadius]::new(12)
    $guardBorder.Padding = [System.Windows.Thickness]::new(14, 11, 14, 11)
    $guardBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
    $guardBorder.Child = $guardGrid
    $shell.Body.Children.Add($guardBorder) | Out-Null

    $divider = New-Object System.Windows.Controls.Border
    $divider.Height = 1
    $divider.Background = Get-FluxUiBrush 'BorderSoft'
    $divider.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
    $shell.Body.Children.Add($divider) | Out-Null

    $headGrid = New-Object System.Windows.Controls.Grid
    $colHead = New-Object System.Windows.Controls.ColumnDefinition
    $colHead.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $colHeadButtons = New-Object System.Windows.Controls.ColumnDefinition
    $colHeadButtons.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
    $headGrid.ColumnDefinitions.Add($colHead)
    $headGrid.ColumnDefinitions.Add($colHeadButtons)
    $headText = New-Object System.Windows.Controls.StackPanel
    $headText.Children.Add((New-FluxUiText -Text 'BACKGROUND APPS' -StyleKey 'Overline' -ColorKey 'GoldDeep')) | Out-Null
    $ui.ProcessSummary = New-FluxUiText -Text 'Scanning for apps Flux can free memory from…' -ColorKey 'TextSecondary' -Size 10.5
    $ui.ProcessSummary.TextWrapping = 'Wrap'
    $ui.ProcessSummary.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
    $headText.Children.Add($ui.ProcessSummary) | Out-Null
    $headGrid.Children.Add($headText) | Out-Null

    $headButtons = New-Object System.Windows.Controls.StackPanel
    $headButtons.Orientation = 'Horizontal'
    $headButtons.VerticalAlignment = 'Center'
    $ui.ProcessRefreshButton = New-FluxUiButton -Text 'Refresh list' -StyleKey 'GhostButton' -Handler 'ProcessRefresh'
    $ui.ProcessRefreshButton.FontSize = 10.5
    $headButtons.Children.Add($ui.ProcessRefreshButton) | Out-Null
    $ui.ProcessRestoreButton = New-FluxUiButton -Text 'Reopen apps' -StyleKey 'GhostButton' -Handler 'ProcessRestore'
    $ui.ProcessRestoreButton.FontSize = 10.5
    $ui.ProcessRestoreButton.IsEnabled = $false
    $headButtons.Children.Add($ui.ProcessRestoreButton) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($headButtons, 1)
    $headGrid.Children.Add($headButtons) | Out-Null
    $shell.Body.Children.Add($headGrid) | Out-Null

    $ui.ProcessListPanel = New-Object System.Windows.Controls.StackPanel
    $ui.ProcessListPanel.Margin = [System.Windows.Thickness]::new(0, 9, 0, 0)
    $shell.Body.Children.Add($ui.ProcessListPanel) | Out-Null

    $foot = New-Object System.Windows.Controls.StackPanel
    $foot.Orientation = 'Horizontal'
    $foot.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
    $ui.ProcessCloseButton = New-FluxUiButton -Text 'Close selected apps' -StyleKey 'PrimaryButton' -Handler 'ProcessClose' -MinWidth 156
    $ui.ProcessCloseButton.Padding = [System.Windows.Thickness]::new(14, 8, 14, 8)
    $ui.ProcessCloseButton.FontSize = 11
    $ui.ProcessCloseButton.IsEnabled = $false
    $foot.Children.Add($ui.ProcessCloseButton) | Out-Null
    $note = New-FluxUiText -Text 'Apps are asked to close first; only chat apps are force-closed. They reopen when Fortnite exits while the guard is on.' -ColorKey 'TextTertiary' -Size 9.5
    $note.TextWrapping = 'Wrap'
    $note.VerticalAlignment = 'Center'
    $note.Margin = [System.Windows.Thickness]::new(12, 0, 0, 0)
    $note.MaxWidth = 460
    $foot.Children.Add($note) | Out-Null
    $shell.Body.Children.Add($foot) | Out-Null

    $ui.SectionViews[10] = @{ Card = $shell.Card; CountText = $shell.CountText; ToggleIds = @(); Buttons = $shell.ButtonPanel }
    return $shell.Card
}

function Initialize-FluxProcessEvents {
    $script:FluxHandlers.GuardToggle = {
        param($sender, $e)
        if ($script:FluxUi.SyncingGuard) { return }
        Set-FluxGuardEnabled ([bool]$sender.IsChecked)
    }
    $script:FluxHandlers.ProcessRefresh = {
        param($sender, $e)
        if ($script:FluxUi.ProcessBusy) { return }
        Refresh-FluxProcessList
    }
    $script:FluxHandlers.ProcessClose = {
        param($sender, $e)
        Invoke-FluxCloseSelected
    }
    $script:FluxHandlers.ProcessRestore = {
        param($sender, $e)
        $restored = @(Restore-FluxBackgroundApps)
        if ($restored.Count -eq 0) {
            Set-FluxStatus 'No closed apps were waiting to reopen.' 'Warning'
            $script:FluxUi.ProcessRestoreButton.IsEnabled = $false
        }
        else {
            Set-FluxStatus "Reopened: $($restored -join ', ')." 'Ready'
            $script:FluxUi.ProcessRestoreButton.IsEnabled = $false
        }
        $script:FluxUi.TickCount = 0
        Refresh-FluxProcessList
    }
    $script:FluxHandlers.ProcessToggle = {
        param($sender, $e)
        Update-FluxProcessSelectionState
    }
}

function Refresh-FluxProcessList {
    $ui = $script:FluxUi
    if (-not $ui.ProcessListPanel) { return }
    $ui.ProcessChecks = @{}
    $ui.ProcessListPanel.Children.Clear()
    $candidates = @()
    try { $candidates = @(Get-FluxBackgroundCandidates) }
    catch { $candidates = @() }
    $ui.ProcessCandidates = @($candidates)

    if ($candidates.Count -eq 0) {
        $empty = New-FluxUiText -Text 'No known chat or browser apps are running. Open a few, then refresh.' -ColorKey 'TextTertiary' -Size 10.5
        $empty.TextWrapping = 'Wrap'
        $empty.Margin = [System.Windows.Thickness]::new(2, 3, 0, 3)
        $ui.ProcessListPanel.Children.Add($empty) | Out-Null
        $ui.ProcessSummary.Text = 'Nothing to close right now.'
    }
    else {
        $totalMb = 0
        foreach ($candidate in $candidates) {
            $totalMb += [double]$candidate.WorkingSetMb
            $row = New-Object System.Windows.Controls.Border
            $row.Background = Get-FluxUiBrush 'Surface'
            $row.BorderBrush = Get-FluxUiBrush 'BorderSoft'
            $row.BorderThickness = [System.Windows.Thickness]::new(1)
            $row.CornerRadius = [System.Windows.CornerRadius]::new(10)
            $row.Padding = [System.Windows.Thickness]::new(12, 8, 12, 8)
            $row.Margin = [System.Windows.Thickness]::new(0, 0, 0, 5)

            $grid = New-Object System.Windows.Controls.Grid
            $colCheck = New-Object System.Windows.Controls.ColumnDefinition
            $colCheck.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            $colPill = New-Object System.Windows.Controls.ColumnDefinition
            $colPill.Width = [System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Auto)
            $grid.ColumnDefinitions.Add($colCheck)
            $grid.ColumnDefinitions.Add($colPill)

            $key = [string]$candidate.Label
            $check = New-Object System.Windows.Controls.CheckBox
            $check.Content = [string]$candidate.Label
            $check.Style = $ui.Window.Resources['FluxCheckBox']
            $check.Tag = $key
            $check.IsChecked = $true
            $check.VerticalAlignment = 'Center'
            $check.Add_Checked($script:FluxHandlers.ProcessToggle)
            $check.Add_Unchecked($script:FluxHandlers.ProcessToggle)
            $ui.ProcessChecks[$key] = $check
            $grid.Children.Add($check) | Out-Null

            $pill = New-FluxUiPill -Text ("{0:N0} MB · {1} process{2}" -f [double]$candidate.WorkingSetMb, @($candidate.ProcessIds).Count, $(if (@($candidate.ProcessIds).Count -eq 1) { '' } else { 'es' })) -BgKey 'SurfaceAlt' -FgKey 'TextSecondary' -FontSize 9
            $pill.Border.VerticalAlignment = 'Center'
            if ($candidate.Force) { $pill.Border.ToolTip = 'Flux may force-close this app if it ignores the close request.' }
            else { $pill.Border.ToolTip = 'Flux only asks this app to close. It will not force-close a browser.' }
            [System.Windows.Controls.Grid]::SetColumn($pill.Border, 1)
            $grid.Children.Add($pill.Border) | Out-Null

            $row.Child = $grid
            $ui.ProcessListPanel.Children.Add($row) | Out-Null
        }
        $ui.ProcessSummary.Text = "{0} apps running · {1:N0} MB working set · untick anything you want to keep open." -f $candidates.Count, $totalMb
    }

    $restoreWaiting = Test-Path -LiteralPath $script:FluxRestoreAppsPath
    $ui.ProcessRestoreButton.IsEnabled = $restoreWaiting -and -not ($ui.Busy -or $ui.ProcessBusy)
    $ui.ProcessRefreshButton.IsEnabled = -not ($ui.Busy -or $ui.ProcessBusy)
    Update-FluxProcessSelectionState
}

function Update-FluxProcessSelectionState {
    $ui = $script:FluxUi
    if (-not $ui.ProcessCloseButton) { return }
    $checked = 0
    foreach ($key in $ui.ProcessChecks.Keys) {
        if ($ui.ProcessChecks[$key].IsChecked -eq $true) { $checked++ }
    }
    $busy = $ui.Busy -or $ui.ProcessBusy
    $ui.ProcessCloseButton.IsEnabled = ($checked -gt 0) -and -not $busy
    $ui.ProcessCloseButton.Content = if ($checked -gt 1) { "Close $checked apps" } else { 'Close selected apps' }
}

function Invoke-FluxCloseSelected {
    $ui = $script:FluxUi
    if ($ui.Busy -or $ui.ProcessBusy) { return }
    $names = @()
    foreach ($key in $ui.ProcessChecks.Keys) {
        if ($ui.ProcessChecks[$key].IsChecked -eq $true) { $names += $key }
    }
    if ($names.Count -eq 0) {
        Set-FluxStatus 'Tick at least one app first.' 'Warning'
        return
    }
    $totalMb = 0
    foreach ($candidate in $ui.ProcessCandidates) {
        if ($names -contains [string]$candidate.Label) { $totalMb += [double]$candidate.WorkingSetMb }
    }
    Show-FluxConfirm -Title "Close $($names.Count) background app$(if ($names.Count -eq 1) { '' } else { 's' })? " -Message ("Flux will close {0}. This frees about {1:N0} MB of memory. Unticked apps stay open." -f ($names -join ', '), $totalMb) -Warning 'Unsaved work in a browser tab can be lost. Chat apps are force-closed if they ignore the request; browsers are never force-closed.' -Foot 'If the guard is on, these apps reopen after Fortnite exits.' -ContinueLabel 'Close apps' -ShowRestore $false -Data @{ Kind = 'closeapps'; Names = $names }
}

function Start-FluxCloseApps {
    param([string[]]$Names)
    $ui = $script:FluxUi
    if ($ui.Busy -or $ui.ProcessBusy) { return }
    $selected = @($ui.ProcessCandidates | Where-Object { $Names -contains [string]$_.Label })
    if ($selected.Count -eq 0) { return }

    $ui.ProcessBusy = $true
    $ui.ProcessCloseButton.Content = 'Closing apps…'
    Update-FluxButtonStates
    Set-FluxStatus 'Closing background apps…' 'Working'
    try {
        $result = Close-FluxBackgroundApps -Candidates $selected
        $parts = @()
        if (@($result.Closed).Count -gt 0) { $parts += "closed $($result.Closed -join ', ')" }
        if (@($result.Kept).Count -gt 0) { $parts += "kept $($result.Kept -join ', ') (still running)" }
        $summary = if ($parts.Count -gt 0) { ($parts -join '; ') + '.' } else { 'No matching apps were running.' }
        Show-FluxResult -Title 'Background apps handled' -Summary $summary -Items @() -Eyebrow 'PROCESSES'
        Set-FluxStatus $summary 'Ready'
    }
    catch {
        Show-FluxResult -Title 'Could not close apps' -Summary $_.Exception.Message -Items @() -Eyebrow 'PROCESSES'
        Set-FluxStatus "Could not close apps: $($_.Exception.Message)" 'Error'
    }
    finally {
        $ui.ProcessBusy = $false
        Update-FluxButtonStates
        Refresh-FluxProcessList
        Update-FluxGuardStatus
    }
}

function Set-FluxGuardEnabled {
    param([bool]$Enabled)
    $ui = $script:FluxUi
    try {
        if ($Enabled) {
            [void](Start-FluxGameAgent -WaitMinutes 480)
            Set-FluxStatus 'Guard on. Fortnite gets High priority and all cores; apps reopen when it exits.' 'Ready'
        }
        else {
            Stop-FluxGameAgent
            Set-FluxStatus 'Guard off. Fortnite runs with normal priority.' 'Ready'
        }
    }
    catch {
        Set-FluxStatus "Guard could not start: $($_.Exception.Message)" 'Error'
    }
    Update-FluxGuardStatus
}

function Update-FluxGuardStatus {
    $ui = $script:FluxUi
    $status = @{}
    try { $status = Get-FluxGameAgentStatus } catch { }
    $ui.GuardStatus = $status
    $running = [bool]$status.running
    $state = [string]$status.state
    $message = [string]$status.message

    if ($ui.GuardSwitch -and -not $ui.SyncingGuard) {
        $ui.SyncingGuard = $true
        try { $ui.GuardSwitch.IsChecked = $running } finally { $ui.SyncingGuard = $false }
    }

    $detail = switch ($state) {
        'waiting' { 'Waiting for Fortnite. Background apps will reopen after the game closes.' }
        'game' { 'Fortnite is running with High priority and every core. Apps reopen when the game exits.' }
        'restoring' { 'Fortnite closed. Reopening background apps…' }
        'finished' { 'Guard finished its watch window. Switch it on again for the next session.' }
        'starting' { 'Guard is starting up…' }
        default { if ($running) { 'Guard is running.' } else { 'Guard off. Use the switch to enable High priority and all cores for Fortnite.' } }
    }
    if ($ui.GuardDetail) { $ui.GuardDetail.Text = $detail }
    if ($ui.GuardTitle) { $ui.GuardTitle.Text = if ($running) { 'Fortnite process guard · on' } else { 'Fortnite process guard · off' } }
    if ($ui.StatGuardValue) { $ui.StatGuardValue.Text = if ($running) { 'On' } else { 'Off' } }
    if ($ui.StatGuardDetail) { $ui.StatGuardDetail.Text = if ($running) { "Waiting for game · High priority + all cores" } else { 'High priority + all cores' } }

    $restoreWaiting = Test-Path -LiteralPath $script:FluxRestoreAppsPath
    if ($ui.ProcessRestoreButton) { $ui.ProcessRestoreButton.IsEnabled = $restoreWaiting -and -not ($ui.Busy -or $ui.ProcessBusy) }
    if ($ui.SectionViews -and $ui.SectionViews.ContainsKey(10)) {
        $count = $ui.SectionViews[10].CountText
        if ($count) {
            $count.Text = if (-not $running) { 'Guard off' }
            elseif ($state -eq 'game') { 'Game guarded' }
            elseif ($restoreWaiting) { 'Closed apps waiting to reopen' }
            else { 'Guard active' }
        }
    }
    if ($message -and $state -eq 'finished' -and $ui.GuardSwitch -and -not $running) {
        $ui.GuardSwitch.IsChecked = $false
    }
}
