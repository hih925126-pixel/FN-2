# Section 11 — Safety.
Add-FluxTweak @{
    Id = 'system.defender'; SectionNo = 11; Order = 52
    Name = 'Defender exclude Fortnite folder'
    Short = 'Stop real-time scans of the game folder.'
    Detail = 'Adds the Fortnite install folder and Fortnite local data folder to Windows Defender exclusions. Real-time scanning stops for those paths only. This lowers security for files in those folders.'
    Why = 'Real-time scanning of assets while the game streams map data can cost disk and CPU. Only exclude folders you trust.'
    Changes = @('Defender ExclusionPath → Fortnite folder', 'Defender ExclusionPath → %LOCALAPPDATA%\FortniteGame', 'Only added paths are removed on restore')
    Risk = 'Risky'; Restart = $false; ButtonLabel = 'Exclude'
    Apply = { Add-FluxDefenderExclusion -TweakId 'system.defender' }
    Revert = { Remove-FluxDefenderExclusion -TweakId 'system.defender' }
    Detect = { Test-FluxDefenderExclusion }
}

Add-FluxTweak @{
    Id = 'system.restorepoint'; SectionNo = 11; Order = 53; Kind = 'action'
    Name = 'Create restore point now'
    Short = 'A Windows checkpoint, on demand.'
    Detail = 'Creates a Windows System Restore checkpoint marked before performance changes. Flux also creates one automatically before its first change in a session when System Protection is available.'
    Why = 'A Windows restore point covers the whole system, including changes outside Flux. Flux keeps its own per-tweak backups as well.'
    Changes = @('System restore point', 'No tweak settings changed')
    Risk = 'Safe'; ButtonLabel = 'Create'
    Apply = {
        $result = New-FluxRestorePoint
        if (-not $result.Success) { throw $result.Message }
        return $result.Message
    }
}
