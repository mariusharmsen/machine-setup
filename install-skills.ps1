# Links this repo's Windows-relevant skills into the user's Claude Code skills folder.
# Idempotent: skips links that already exist. Junctions keep the repo as the single
# source of truth - a git pull updates the live skills.
$ErrorActionPreference = 'Stop'
$repoSkills = Join-Path $PSScriptRoot '.claude\skills'
$userSkills = Join-Path $env:USERPROFILE '.claude\skills'
New-Item -ItemType Directory -Force $userSkills | Out-Null

Get-ChildItem $repoSkills -Directory | Where-Object { $_.Name -notlike 'mac-*' } | ForEach-Object {
    $link = Join-Path $userSkills $_.Name
    if (Test-Path $link) {
        Write-Host "[skip] $($_.Name) already present"
    } else {
        New-Item -ItemType Junction -Path $link -Target $_.FullName | Out-Null
        Write-Host "[link] $($_.Name)"
    }
}
Write-Host "Done. Skills are live in Claude Code (new sessions pick them up)."
