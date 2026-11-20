# Flux.UI.Operations.ps1 — dialogs, apply/revert flow, background jobs and progress.

function Initialize-FluxOperationHandlers {
    $script:FluxHandlers.Tweak = {
        param($sender, $e)
        Invoke-FluxTweakClick ([string]$sender.Tag)
    }
    $script:FluxHandlers.Info = {
        param($sender, $e)
        $tweak = $script:FluxUi.TweakCache[[string]$sender.Tag]
        if ($tweak) { Show-FluxInfo $tweak }
    }
    $script:FluxHandlers.Section = {
        param($sender, $e)
        Invoke-FluxSectionClick ([string]$sender.Tag)
    }
    $script:FluxHandlers.InfoAction = {
        param($sender, $e)
        $tweak = $script:FluxUi.InfoTweak
        $mode = $script:FluxUi.InfoActionMode
        Hide-FluxOverlay
        if (-not $tweak -or $mode -eq 'close') { return }
        Invoke-FluxTweakClick "tweak:$($tweak.Id)"
    }
    $script:FluxHandlers.InfoOpen = {
        param($sender, $e)
        $tweak = $script:FluxUi.InfoTweak
        if ($tweak -and $tweak.Open) {
            Hide-FluxOverlay
            Open-FluxTweakPanel ([string]$tweak.Open)
        }
    }
    $script:FluxHandlers.ConfirmContinue = {
        param($sender, $e)
        $data = $script:FluxUi.ConfirmData
        $restore = ($script:FluxUi.ConfirmRestoreCheck.IsChecked -eq $true)
        Hide-FluxOverlay
        if (-not $data) { return }
        if ($data.Kind -eq 'operation') {
            $params = @{ Action = $data.Action; Ids = @($data.Ids) }
            if ($data.Action -eq 'Apply' -and $restore) { $params.RestorePoint = $true }
            Start-FluxOperation @params
        }
        elseif ($data.Kind -eq 'closeapps') {
            Start-FluxCloseApps -Names @($data.Names)
        }
    }
    $script:FluxHandlers.OpenLog = {
        param($sender, $e)
        Open-FluxLog
    }
}

function Show-FluxOverlay {
    param($View, [double]$Width = 600)
    $ui = $script:FluxUi
    foreach ($child in @($ui.InfoView, $ui.ConfirmView, $ui.ResultView, $ui.StudioView)) {
        if ($child) { $child.Visibility = 'Collapsed' }
    }
    $ui.OverlayCard.Width = $Width
    $ui.OverlayLayer.Visibility = 'Visible'
    if ($View) { $View.Visibility = 'Visible' }
    $ui.OverlayCard.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $ui.OverlayCard.Opacity = 0
    $ui.OverlayCard.RenderTransform = New-Object System.Windows.Media.TranslateTransform(0, 10)
    $fade = New-Object System.Windows.Media.Animation.DoubleAnimation
    $fade.From = 0; $fade.To = 1
    $fade.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(150))
    $ui.OverlayCard.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
    $slide = New-Object System.Windows.Media.Animation.DoubleAnimation
    $slide.From = 10; $slide.To = 0
    $slide.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(180))
    $ui.OverlayCard.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $slide)
}

function Hide-FluxOverlay {
    $ui = $script:FluxUi
    if (-not $ui.OverlayLayer) { return }
    $ui.OverlayLayer.Visibility = 'Collapsed'
    foreach ($child in @($ui.InfoView, $ui.ConfirmView, $ui.ResultView, $ui.StudioView)) {
        if ($child) { $child.Visibility = 'Collapsed' }
    }
    $ui.ConfirmData = $null
}

function Show-FluxConfirm {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Warning = '',
        [string]$Foot = '',
        [string]$ContinueLabel = 'Continue',
        [bool]$ShowRestore = $false,
        $Data
    )
    $ui = $script:FluxUi
    $ui.ConfirmData = $Data
    $ui.ConfirmEyebrow.Text = 'CONFIRM'
    $ui.ConfirmTitle.Text = $Title
    $ui.ConfirmMessage.Text = $Message
    $ui.ConfirmWarnText.Text = $Warning
    $ui.ConfirmWarnBox.Visibility = if ($Warning) { 'Visible' } else { 'Collapsed' }
    $ui.ConfirmFoot.Text = $Foot
    $ui.ConfirmContinueButton.Content = $ContinueLabel
    $ui.ConfirmRestoreCheck.Visibility = if ($ShowRestore) { 'Visible' } else { 'Collapsed' }
    $ui.ConfirmRestoreCheck.IsChecked = $true
    Show-FluxOverlay -View $ui.ConfirmView -Width 600
}

function Show-FluxResult {
    param([string]$Title, [string]$Summary, $Items = @(), [string]$Eyebrow = 'OPERATION COMPLETE')
    $ui = $script:FluxUi
    $ui.ResultEyebrow.Text = $Eyebrow
    $ui.ResultTitle.Text = $Title
    $ui.ResultSummary.Text = $Summary
    $ui.ResultList.Children.Clear()
    $items = @($Items)
    if ($items.Count -eq 0) {
        $empty = New-FluxUiText -Text 'No individual results were recorded.' -ColorKey 'TextTertiary' -Size 11
        $empty.Margin = [System.Windows.Thickness]::new(2, 4, 0, 0)
        $ui.ResultList.Children.Add($empty) | Out-Null
    }
    foreach ($item in $items) {
        $border = New-Object System.Windows.Controls.Border
        $border.Background = Get-FluxUiBrush 'SurfaceAlt'
        $border.CornerRadius = [System.Windows.CornerRadius]::new(9)
        $border.Padding = [System.Windows.Thickness]::new(12, 9, 12, 9)
        $border.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
        $line = New-Object System.Windows.Controls.StackPanel
        $line.Orientation = 'Horizontal'
        $glyph = New-Object System.Windows.Controls.TextBlock
        $glyph.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe MDL2 Assets')
        $glyph.FontSize = 11
        $glyph.Text = if ($item.Success) { [string][char]0xE73E } else { [string][char]0xE7BA }
        $glyph.Foreground = Get-FluxUiBrush $(if ($item.Success) { 'Success' } else { 'Danger' })
        $glyph.VerticalAlignment = 'Top'
        $glyph.Margin = [System.Windows.Thickness]::new(0, 2, 9, 0)
        $line.Children.Add($glyph) | Out-Null
        $text = New-FluxUiText -Text ([string]$item.Text) -ColorKey 'TextSecondary' -Size 11
        $text.TextWrapping = 'Wrap'
        $text.MaxWidth = 470
        $line.Children.Add($text) | Out-Null
        $border.Child = $line
        $ui.ResultList.Children.Add($border) | Out-Null
    }
    Show-FluxOverlay -View $ui.ResultView -Width 600
}

function Show-FluxInfo {
    param($Tweak)
    $ui = $script:FluxUi
    if (-not $Tweak) { return }
    $ui.InfoTweak = $Tweak
    $status = $ui.StatusMap[[string]$Tweak.Id]
    if (-not $status) {
        if ($Tweak.Kind -eq 'guide') { $status = @{ State = 'Manual'; Label = 'Guided'; Detail = '' } }
        elseif ($Tweak.Kind -eq 'action') { $status = @{ State = 'Action'; Label = 'Ready'; Detail = '' } }
        else { $status = @{ State = 'NotRun'; Label = 'Not run'; Detail = '' } }
    }

    $ui.InfoTitle.Text = [string]$Tweak.Name
    $ui.InfoDescription.Text = [string]$Tweak.Detail
    $ui.InfoWhy.Text = [string]$Tweak.Why
    $ui.InfoChipRow.Children.Clear()

    $risk = [string]$Tweak.Risk
    $bgKey = 'SuccessSoft'; $fgKey = 'Success'
    if ($risk -eq 'Caution') { $bgKey = 'WarningSoft'; $fgKey = 'Warning' }
    elseif ($risk -eq 'Risky') { $bgKey = 'DangerSoft'; $fgKey = 'Danger' }
    $riskPill = New-FluxUiPill -Text "Risk: $risk" -BgKey $bgKey -FgKey $fgKey -FontSize 9
    $riskPill.Border.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
    $ui.InfoChipRow.Children.Add($riskPill.Border) | Out-Null
    if ([bool]$Tweak.Restart) {
        $restartPill = New-FluxUiPill -Text 'Restart required' -BgKey 'GoldSoft' -FgKey 'GoldDeep' -FontSize 9
        $restartPill.Border.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
        $ui.InfoChipRow.Children.Add($restartPill.Border) | Out-Null
    }
    $sectionTitle = ''
    foreach ($section in @(Get-FluxSectionList)) { if ([int]$section.No -eq [int]$Tweak.SectionNo) { $sectionTitle = [string]$section.Title; break } }
    if ($sectionTitle) {
        $sectionPill = New-FluxUiPill -Text "$([int]$Tweak.SectionNo). $sectionTitle" -BgKey 'SurfaceAlt' -FgKey 'TextSecondary' -FontSize 9
        $ui.InfoChipRow.Children.Add($sectionPill.Border) | Out-Null
    }

    $ui.InfoChangesPanel.Children.Clear()
    $changes = @($Tweak.Changes)
    if ($changes.Count -eq 0) {
        $none = New-FluxUiText -Text 'No system values are changed by this item.' -ColorKey 'TextTertiary' -Size 11
        $ui.InfoChangesPanel.Children.Add($none) | Out-Null
    }
    else {
        foreach ($change in $changes) {
            $line = New-FluxUiText -Text "•  $change" -ColorKey 'TextSecondary' -Size 11
            $line.TextWrapping = 'Wrap'
            $line.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
            $ui.InfoChangesPanel.Children.Add($line) | Out-Null
        }
    }

    $guide = @($Tweak.Guide)
    if ($guide.Count -gt 0) {
        $ui.InfoGuidePanel.Visibility = 'Visible'
        $ui.InfoGuideList.Children.Clear()
        $n = 0
        foreach ($step in $guide) {
            $n++
            $line = New-FluxUiText -Text "$n.  $step" -ColorKey 'TextSecondary' -Size 11
            $line.TextWrapping = 'Wrap'
            $line.Margin = [System.Windows.Thickness]::new(0, 0, 0, 5)
            $ui.InfoGuideList.Children.Add($line) | Out-Null
        }
    }
    else {
        $ui.InfoGuidePanel.Visibility = 'Collapsed'
    }

    $ui.InfoOpenButton.Visibility = if ($Tweak.Open) { 'Visible' } else { 'Collapsed' }

    $mode = 'apply'
    $actionLabel = 'Apply'
    if ($Tweak.Kind -eq 'guide') { $mode = 'close'; $actionLabel = 'Close' }
    elseif ($Tweak.Kind -eq 'action') { $mode = 'run'; $actionLabel = if ($Tweak.ButtonLabel) { [string]$Tweak.ButtonLabel } else { 'Run' } }
    elseif ($status.State -eq 'Applied' -or $status.State -eq 'Drifted') { $mode = 'revert'; $actionLabel = 'Restore' }
    $ui.InfoActionMode = $mode
    $ui.InfoActionButton.Content = $actionLabel
    $ui.InfoActionButton.Style = $ui.Window.Resources[$(if ($mode -eq 'revert' -or $mode -eq 'close') { 'SecondaryButton' } else { 'PrimaryButton' })]

    $foot = "Flux records the previous value and can undo this. "
    if ([bool]$Tweak.Restart) { $foot += 'A restart is required. ' }
    if ($Tweak.Kind -eq 'guide') { $foot = 'Guided step. Flux does not automate this.' }
    if ($Tweak.Kind -eq 'action') { $foot = 'One-shot action. No permanent system change unless described above.' }
    $ui.InfoFoot.Text = $foot

    $ui.InfoEyebrow.Text = if ($Tweak.Kind -eq 'guide') { 'GUIDED TWEAK' } elseif ($Tweak.Kind -eq 'action') { 'ACTION' } else { 'TWEAK DETAIL' }
    Show-FluxOverlay -View $ui.InfoView -Width 600
}

function Get-FluxRiskText {
    param($Tweak)
    switch ([string]$Tweak.Risk) {
        'Risky' { return 'High-impact change. Read the explanation and keep a restore point.' }
        'Caution' { return 'Noticeable change. You may want to undo this later.' }
        default { return 'Low risk. The previous value is backed up.' }
    }
}

function Invoke-FluxTweakClick {
    param([string]$Tag)
    $ui = $script:FluxUi
    if ($ui.Busy -or $ui.ProcessBusy) { return }
    if (-not $Tag -or $Tag -notmatch '^tweak:(.+)$') { return }
    $id = $matches[1]
    $tweak = $ui.TweakCache[$id]
    if (-not $tweak) { return }

    if ($tweak.Kind -eq 'guide') {
        Show-FluxInfo $tweak
        return
    }

    if ($tweak.Kind -eq 'action') {
        if ($id -eq 'system.restorepoint') {
            Start-FluxOperation -Action 'Run' -Ids @($id)
            return
        }
        $warning = switch ($id) {
            'memory.ram' { 'The trim is temporary. Windows refills standby memory as needed.' }
            'memory.temp' { 'Deleted files are permanent. Flux only removes files older than 24 hours and skips anything in use.' }
            default { 'This is a one-shot action.' }
        }
        Show-FluxConfirm -Title "Run $($tweak.Name)?" -Message ([string]$tweak.Detail) -Warning $warning -Foot 'No restore point is needed; no permanent system setting is changed.' -ContinueLabel $(if ($tweak.ButtonLabel) { [string]$tweak.ButtonLabel } else { 'Run' }) -ShowRestore $false -Data @{ Kind = 'operation'; Action = 'Run'; Ids = @($id) }
        return
    }

    $status = $ui.StatusMap[$id]
    if (-not $status) { $status = Get-FluxTweakStatus $tweak }
    if ($status.State -eq 'NA') {
        Set-FluxStatus "This tweak is not available on this PC." 'Warning'
        return
    }

    if ($status.State -eq 'Applied' -or $status.State -eq 'Drifted') {
        $warning = 'Flux will put back the value recorded before it changed anything.'
        if ([bool]$tweak.Restart) { $warning += ' A restart may be needed for the old value to take effect.' }
        Show-FluxConfirm -Title "Restore $($tweak.Name)?" -Message 'Windows returns to the state Flux found before this tweak was applied.' -Warning $warning -Foot 'Only values Flux recorded are touched.' -ContinueLabel 'Restore' -ShowRestore $false -Data @{ Kind = 'operation'; Action = 'Revert'; Ids = @($id) }
    }
    else {
        $warning = Get-FluxRiskText $tweak
        if ([bool]$tweak.Restart) { $warning += ' Restart Windows or the game to finish.' }
        Show-FluxConfirm -Title "Apply $($tweak.Name)?" -Message ([string]$tweak.Detail) -Warning $warning -Foot 'Flux backs up the previous value before writing.' -ContinueLabel 'Apply' -ShowRestore $true -Data @{ Kind = 'operation'; Action = 'Apply'; Ids = @($id) }
    }
}

function Invoke-FluxSectionClick {
    param([string]$Tag)
    $ui = $script:FluxUi
    if ($ui.Busy -or $ui.ProcessBusy) { return }
    if (-not $Tag -or $Tag -notmatch '^(apply|restore)section:(\d+)$') { return }
    $mode = $matches[1]
    $number = [int]$matches[2]
    $sectionTitle = "Section $number"
    foreach ($section in @(Get-FluxSectionList)) { if ([int]$section.No -eq $number) { $sectionTitle = [string]$section.Title; break } }
    $tweaks = @(Get-FluxTweakCatalog | Where-Object { [int]$_.SectionNo -eq $number -and $_.Kind -eq 'toggle' })

    if ($mode -eq 'apply') {
        $ids = @()
        foreach ($tweak in $tweaks) {
            $status = $ui.StatusMap[[string]$tweak.Id]
            if (-not $status) { $status = Get-FluxTweakStatus $tweak }
            if ($status.State -ne 'Applied' -and $status.State -ne 'NA' -and $status.State -ne 'Manual') { $ids += [string]$tweak.Id }
        }
        if ($ids.Count -eq 0) {
            Show-FluxResult -Title 'Nothing to apply' -Summary "Every automatic tweak in $sectionTitle is already applied." -Items @() -Eyebrow 'SECTION CHECK'
            return
        }
        $risky = @($tweaks | Where-Object { $_.Risk -eq 'Risky' -and $ids -contains $_.Id }).Count
        $caution = @($tweaks | Where-Object { $_.Risk -eq 'Caution' -and $ids -contains $_.Id }).Count
        $warning = "This applies $($ids.Count) tweaks. $risky risky and $caution caution-level items are included."
        if ($ids -contains 'system.restorepoint') { $warning += ' A restore point may also be created.' }
        Show-FluxConfirm -Title "Apply the $sectionTitle section?" -Message 'Flux applies every automatic tweak in this section that is not already active. Guided items are left for you.' -Warning $warning -Foot 'Review individual items first; each one stays reversible.' -ContinueLabel "Apply $($ids.Count)" -ShowRestore $true -Data @{ Kind = 'operation'; Action = 'Apply'; Ids = $ids }
    }
    else {
        $ids = @($tweaks | Where-Object { Test-FluxBackupManaged $_.Id } | Select-Object -ExpandProperty Id)
        if ($ids.Count -eq 0) {
            Show-FluxResult -Title 'Nothing to restore' -Summary "Flux has no saved changes in $sectionTitle." -Items @() -Eyebrow 'SECTION CHECK'
            return
        }
        Show-FluxConfirm -Title "Restore the $sectionTitle section?" -Message "Flux will restore $($ids.Count) tweaks to the values saved before it changed them." -Warning 'Only values recorded by Flux are restored. Items changed by Windows updates may still need a re-check.' -Foot 'You can re-apply the section at any time.' -ContinueLabel "Restore $($ids.Count)" -ShowRestore $false -Data @{ Kind = 'operation'; Action = 'Revert'; Ids = $ids }
    }
}

function Invoke-FluxRevertAll {
    $ui = $script:FluxUi
    $ids = @(Get-FluxTweakCatalog | Where-Object { $_.Kind -eq 'toggle' -and (Test-FluxBackupManaged $_.Id) } | Select-Object -ExpandProperty Id)
    if ($ids.Count -eq 0) {
        Show-FluxResult -Title 'Nothing to restore' -Summary 'Flux has not applied any changes yet.' -Items @() -Eyebrow 'RESTORE'
        return
    }
    Show-FluxConfirm -Title 'Restore every Flux change?' -Message "Flux will restore $($ids.Count) tweaks to the values saved before it changed them. This does not uninstall Flux or undo changes made outside it." -Warning 'This is the broadest undo Flux offers. Services, power, input, network and visual settings are all included.' -Foot 'Per-setting backups remain until the restore finishes.' -ContinueLabel 'Restore all' -ShowRestore $false -Data @{ Kind = 'operation'; Action = 'Revert'; Ids = $ids }
}

function Set-FluxBusy {
    param([bool]$Value, [string]$Title = '', [string]$Detail = '')
    $ui = $script:FluxUi
    $ui.Busy = $Value
    $ui.OperationBar.Visibility = if ($Value) { 'Visible' } else { 'Collapsed' }
    if ($Value) {
        $ui.OperationTitle.Text = $Title
        $ui.OperationDetail.Text = $Detail
        $ui.OperationProgress.Value = 0
        $ui.OperationPercent.Text = '0%'
        Set-FluxStatus $Detail 'Working'
    }
    Update-FluxButtonStates
    if ((Get-Command Update-FluxProcessSelectionState -ErrorAction SilentlyContinue)) { Update-FluxProcessSelectionState }
}

function Update-FluxButtonStates {
    $ui = $script:FluxUi
    $disabled = $ui.Busy -or $ui.ProcessBusy
    $ui.RefreshButton.IsEnabled = -not $disabled
    $ui.RestorePointButton.IsEnabled = -not $disabled
    $ui.RevertAllButton.IsEnabled = -not $disabled
    foreach ($number in $ui.SectionViews.Keys) {
        $view = $ui.SectionViews[$number]
        if ($view.Buttons) {
            foreach ($button in @($view.Buttons.Children)) {
                if ($button -is [System.Windows.Controls.Button]) { $button.IsEnabled = -not $disabled }
            }
        }
    }
    foreach ($id in $ui.TweakViews.Keys) {
        $status = $ui.StatusMap[$id]
        if (-not $status) {
            $tweak = $ui.TweakCache[$id]
            if ($tweak) {
                if ($tweak.Kind -eq 'guide') { $status = @{ State = 'Manual'; Label = 'Guided'; Detail = '' } }
                elseif ($tweak.Kind -eq 'action') { $status = @{ State = 'Action'; Label = 'Ready'; Detail = '' } }
                else { $status = @{ State = 'NotRun'; Label = 'Not run'; Detail = '' } }
            }
        }
        Update-FluxTweakView -Id $id -Status $status
    }
    if (Get-Command Update-FluxGuardStatus -ErrorAction SilentlyContinue) { Update-FluxGuardStatus }
}

function Start-FluxOperation {
    param(
        [ValidateSet('Apply', 'Revert', 'Run')][string]$Action,
        [string[]]$Ids,
        [switch]$RestorePoint
    )
    $ui = $script:FluxUi
    if ($ui.Busy -or $ui.ProcessBusy) { return }
    $ids = @($Ids | Where-Object { $_ })
    if ($ids.Count -eq 0) { return }

    $ui.DoneEvent = $null
    $ui.ProgressSeen = 0
    $ui.OpAction = $Action
    $ui.OpIds = $ids
    $opsDir = Join-Path $script:FluxAppData 'ops'
    if (-not (Test-Path -LiteralPath $opsDir)) { New-Item -ItemType Directory -Path $opsDir -Force | Out-Null }
    $progressPath = Join-Path $opsDir ("op-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.jsonl')
    $modulePath = Join-Path $PSScriptRoot 'Flux.Core.psm1'
    $idText = ($ids -join '|')
    $restoreFlag = [bool]$RestorePoint

    $title = switch ($Action) {
        'Apply' { 'Applying changes' }
        'Revert' { 'Restoring changes' }
        default { 'Running action' }
    }
    try {
        $job = Start-Job -ScriptBlock {
            param($modulePath, $action, $idText, $progressPath, $restore)
            Import-Module -Name $modulePath -Force
            $ids = @($idText -split '\|' | Where-Object { $_ })
            if ($restore) { Invoke-FluxOperation -Action $action -Ids $ids -ProgressPath $progressPath -RestorePoint }
            else { Invoke-FluxOperation -Action $action -Ids $ids -ProgressPath $progressPath }
        } -ArgumentList $modulePath, $Action, $idText, $progressPath, $restoreFlag
        $ui.ActiveJob = $job
        $ui.ProgressPath = $progressPath
        Set-FluxBusy -Value $true -Title $title -Detail 'Starting background worker…'
        Set-FluxStatus "$title…" 'Working'
    }
    catch {
        Set-FluxBusy -Value $false
        Show-FluxResult -Title 'Could not start' -Summary $_.Exception.Message -Items @() -Eyebrow 'ERROR'
        Set-FluxStatus "Could not start: $($_.Exception.Message)" 'Error'
    }
}

function Read-FluxOpEvents {
    $ui = $script:FluxUi
    if (-not $ui.ProgressPath) { return }
    $lines = @()
    try {
        if (-not (Test-Path -LiteralPath $ui.ProgressPath)) { return }
        $stream = [System.IO.File]::Open($ui.ProgressPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $reader = [System.IO.StreamReader]::new($stream)
        $text = $reader.ReadToEnd()
        $reader.Dispose()
        $stream.Dispose()
        if ($text) { $lines = @($text -split "`r?`n") }
    }
    catch { return }

    while ($ui.ProgressSeen -lt $lines.Count) {
        $line = $lines[$ui.ProgressSeen]
        $ui.ProgressSeen++
        if (-not $line -or -not $line.Trim()) { continue }
        try { $evt = $line | ConvertFrom-Json } catch { continue }

        switch ([string]$evt.type) {
            'progress' {
                $total = [int]$evt.total
                $index = [int]$evt.index
                $percent = if ($total -gt 0) { [int][math]::Round(($index / $total) * 100) } else { 0 }
                if ($percent -gt 100) { $percent = 100 }
                $ui.OperationProgress.Value = $percent
                $ui.OperationPercent.Text = "$percent%"
                if ($evt.message) { $ui.OperationDetail.Text = [string]$evt.message }
            }
            'restorepoint' {
                if ($evt.time) {
                    try { $ui.LastRestorePoint = [datetime]$evt.time } catch { }
                    Refresh-FluxSafety
                }
                if (-not $evt.success) {
                    $ui.OperationDetail.Text = [string]$evt.message
                }
            }
            'done' {
                $ui.DoneEvent = $evt
            }
        }
    }
}

function Update-FluxOperationPoll {
    $ui = $script:FluxUi

    if ($ui.ActiveJob) {
        Read-FluxOpEvents
        $state = [string]$ui.ActiveJob.State
        if ($ui.DoneEvent -and $state -in @('Completed', 'Failed', 'Stopped')) {
            $job = $ui.ActiveJob
            $done = $ui.DoneEvent
            $ui.ActiveJob = $null
            $ui.ProgressPath = $null
            Complete-FluxOperation -Done $done
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            return
        }
        if ($state -in @('Failed', 'Stopped')) {
            $message = ''
            try { $message = [string](Receive-Job -Job $ui.ActiveJob -ErrorAction SilentlyContinue 2>&1 | Out-String) } catch { }
            $job = $ui.ActiveJob
            $ui.ActiveJob = $null
            $ui.ProgressPath = $null
            if (-not $message.Trim()) { $message = "The background worker stopped before finishing ($state)." }
            Complete-FluxOperation -ErrorText $message.Trim()
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            return
        }
    }

    if ($ui.ProcessJob) { Update-FluxCloseAppsJob }
}

function Complete-FluxOperation {
    param($Done, [string]$ErrorText = '')
    $ui = $script:FluxUi
    Set-FluxBusy -Value $false

    if ($ErrorText -or -not $Done) {
        $summary = if ($ErrorText) { $ErrorText } else { 'The operation did not report a result.' }
        Show-FluxResult -Title 'Operation failed' -Summary $summary -Items @() -Eyebrow 'OPERATION'
        Set-FluxStatus 'Operation failed. Check the log.' 'Error'
        return
    }

    try {
        $statuses = ConvertTo-FluxHashtable $Done.statuses
        if ($statuses -is [hashtable]) {
            foreach ($id in $statuses.Keys) {
                $ui.StatusMap[$id] = $statuses[$id]
                Update-FluxTweakView -Id $id -Status $statuses[$id]
            }
            Update-FluxSectionCounts
        }
    }
    catch { }

    Refresh-FluxBackupStats
    Refresh-FluxSafety

    $items = @()
    $successCount = 0
    $failureCount = 0
    $restartNames = @()
    foreach ($result in @($Done.results)) {
        $success = [bool]$result.success
        if ($success) { $successCount++ } else { $failureCount++ }
        $text = [string]$result.name
        if ($result.message) { $text += " — $($result.message)" }
        elseif ($success) { $text += ' — complete' }
        $items += @{ Success = $success; Text = $text }
        if ($success -and [string]$Done.action -eq 'Apply') {
            $tweak = $ui.TweakCache[[string]$result.id]
            if ($tweak -and [bool]$tweak.Restart) { $restartNames += [string]$tweak.Name }
        }
    }
    if ($Done.restoreSuccess -eq $false) {
        $items += @{ Success = $false; Text = "Restore point — $($Done.restoreMessage)" }
    }
    elseif ($Done.restoreMessage) {
        $items += @{ Success = $true; Text = "Restore point — $($Done.restoreMessage)" }
    }

    $total = $successCount + $failureCount
    $title = switch ([string]$Done.action) {
        'Apply' { if ($failureCount -gt 0) { 'Applied with issues' } else { 'Changes applied' } }
        'Revert' { if ($failureCount -gt 0) { 'Restored with issues' } else { 'Changes restored' } }
        default { if ($failureCount -gt 0) { 'Action finished with issues' } else { 'Action complete' } }
    }
    $summary = "$successCount of $total steps completed."
    if ($Done.action -eq 'Revert' -and $successCount -gt 0) { $summary += ' Windows is back to the values Flux recorded.' }
    if ($restartNames.Count -gt 0) {
        $unique = @($restartNames | Select-Object -Unique)
        $summary += " Restart needed for: $($unique -join ', ')."
    }
    Show-FluxResult -Title $title -Summary $summary -Items $items -Eyebrow 'OPERATION COMPLETE'
    if ($failureCount -gt 0) { Set-FluxStatus "$title. $failureCount issue(s). Open the log for details." 'Warning' }
    else { Set-FluxStatus "$title. $successCount step(s) completed." 'Ready' }
}

function Update-FluxCloseAppsJob {
    param([switch]$Silent)
    $ui = $script:FluxUi
    if (-not $ui.ProcessJob) { return }
    try {
        $done = Get-Job -Job $ui.ProcessJob -ErrorAction SilentlyContinue
        if ($done -and $done.State -in @('Completed', 'Failed', 'Stopped')) {
            $job = $ui.ProcessJob
            $ui.ProcessJob = $null
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            Update-FluxProcessSelectionState
            Set-FluxStatus 'Apps finished being closed.' 'Ready'
        }
        elseif ($done -and $done.State -eq 'Running') {
            Update-FluxProcessSelectionState
        }
    }
    catch {
        $job = $ui.ProcessJob
        $ui.ProcessJob = $null
        if ($job) { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
    }
}

function Update-FluxOperationProgressOnly {
    param([string]$Detail, [int]$Percent)
    $ui = $script:FluxUi
    if ($Detail) { $ui.OperationDetail.Text = $Detail }
    if ($Percent -ge 0) {
        $ui.OperationProgress.Value = $Percent
        $ui.OperationPercent.Text = "$Percent%"
    }
}
