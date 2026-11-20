$wsh = New-Object -ComObject WScript.Shell

$projects = [System.Environment]::GetFolderPath('Desktop')
$folder = 'C:\Users\singh\Documents\Default Project\Flux'

$targets = @(
    @{ Link = "$folder\PushFlux.lnk";     Target = "$folder\PushFlux.cmd";      Desc = 'Push Flux to GitHub' },
    @{ Link = "$folder\Flux.lnk";         Target = "$folder\Flux.exe";          Desc = 'Open Flux app' },
    @{ Link = "$folder\Flux - Fortnite performance workspace.lnk"; Target = "$folder\Flux.exe"; Desc = 'Flux Fortnite performance workspace' }
)

foreach ($t in $targets) {
    if (Test-Path -LiteralPath $t.Link) { Remove-Item -LiteralPath $t.Link -Force }
    $s = $wsh.CreateShortcut($t.Link)
    $s.TargetPath = $t.Target
    $s.WorkingDirectory = $folder
    $s.Description = $t.Desc
    $s.Save()
}

Write-Host "Created shortcuts:"
Get-ChildItem -LiteralPath $folder -Filter '*.lnk' | ForEach-Object { " - $($_.FullName)" }
