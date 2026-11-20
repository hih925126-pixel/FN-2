# PushFluxToGitHub.ps1
# Creates the GitHub repo "Flux" for hih925126-pixel and pushes the local Flux files.
# Change $pat if you want to use a different token.

param([switch]$CreateOnly)

$pat = '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'
$repoName = 'Flux'
$account = 'hih925126-pixel'
$remote = "https://x-access-token:$pat@github.com/$account/$repoName.git"

$headers = @{
    'Authorization' = "Bearer $pat"
    'User-Agent' = 'FluxPush'
    'Accept' = 'application/vnd.github+json'
    'Content-Type' = 'application/json'
}

function New-FluxRepoRequest($Name) {
    @{
        name            = $Name
        description     = 'Flux — Fortnite performance tuning app (PowerShell/WPF).'
        private         = $false
        default_branch  = 'main'
    } | ConvertTo-Json -Depth 3
}

# 1. Check if repo exists.
$exists = $false
try {
    $existing = Invoke-RestMethod -Uri "https://api.github.com/repos/$account/$repoName" -Headers $headers -Method Get -ErrorAction Stop
    $exists = ($existing -and $existing.name -eq $repoName)
}
catch {
    $exists = $false
}

if (-not $exists) {
    try {
        $body = New-FluxRepoRequest -Name $repoName
        $r = Invoke-RestMethod -Uri 'https://api.github.com/user/repos' -Headers $headers -Method Post -Body $body -ErrorAction Stop
        Write-Host "Created repo: $($r.full_name) ($($r.html_url))"
    }
    catch {
        Write-Warning "Could not create repo: $($_.Exception.Message)"
        Write-Warning "If you get 403, generate a token with the 'repo' scope at https://github.com/settings/tokens and update `$pat in this script."
        return
    }
}
else {
    Write-Host "Repo exists: $($account)/$repoName"
}

if ($CreateOnly) { return }

# 2. Push local files.
$git = 'C:\Users\singh\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\mingw64\bin\git.exe'
Set-Location -LiteralPath 'C:\Users\singh\Documents\Default Project\Flux'
& $git remote remove origin 2>$null
& $git remote add origin $remote
Write-Host 'Pushing...'
& $git push -u origin main
