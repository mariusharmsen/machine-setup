<#
.SYNOPSIS
  Maintain and reproduce a Windows machine setup from a JSON manifest.

.DESCRIPTION
  Records the desired state of the machine (winget packages, environment
  variables, PATH entries, manual steps) and can re-apply it idempotently on
  the same or a new machine. The manifest lives next to this script as
  manifest.json.

.EXAMPLE
  setup.ps1 list
  setup.ps1 apply              # install/configure anything missing
  setup.ps1 apply -DryRun      # show what apply would do, change nothing
  setup.ps1 add-package -Id OpenJS.NodeJS.LTS -Name "Node.js LTS" -Note "web dev"
  setup.ps1 add-env  -Name JAVA_HOME -Value "C:\Program Files\..." -Scope Machine
  setup.ps1 add-path -Value "C:\tools\bin" -Scope User
  setup.ps1 add-step -Description "Sign into Docker Desktop and enable WSL2"
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('list', 'apply', 'add-package', 'add-env', 'add-path', 'add-step')]
    [string]$Command = 'list',

    [string]$Id,
    [string]$Name,
    [string]$Override,
    [string]$Value,
    [ValidateSet('User', 'Machine')]
    [string]$Scope = 'User',
    [string]$Description,
    [string]$Note,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ManifestPath = Join-Path $PSScriptRoot 'manifest.json'

function ConvertTo-Array($x) {
    if ($null -eq $x) { return @() }
    if ($x -is [array]) { return $x }
    return @($x)
}

function Get-Manifest {
    if (Test-Path $ManifestPath) {
        $m = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    }
    else {
        $m = [pscustomobject]@{ version = 1; updated = ''; packages = @(); env = @(); pathEntries = @(); steps = @() }
    }
    foreach ($p in 'packages', 'env', 'pathEntries', 'steps') {
        if ($null -eq $m.PSObject.Properties[$p]) {
            $m | Add-Member -NotePropertyName $p -NotePropertyValue @() -Force
        }
    }
    return $m
}

function Save-Manifest($m) {
    $m.updated = (Get-Date -Format 'yyyy-MM-dd')
    ($m | ConvertTo-Json -Depth 10) | Set-Content -Path $ManifestPath -Encoding UTF8
    Write-Host "Saved manifest -> $ManifestPath"
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-PackageInstalled($id) {
    $ProgressPreference = 'SilentlyContinue'
    winget list --id $id -e --accept-source-agreements *> $null
    return ($LASTEXITCODE -eq 0)
}

function Install-Package($pkg) {
    $ProgressPreference = 'SilentlyContinue'
    $a = @('install', '--id', $pkg.id, '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements', '--silent')
    if ($pkg.override) { $a += @('--override', $pkg.override) }
    winget @a
    return ($LASTEXITCODE -eq 0)
}

switch ($Command) {

    'list' {
        $m = Get-Manifest
        Write-Host "Machine setup manifest (updated $($m.updated))" -ForegroundColor Cyan
        Write-Host "`nPackages:" -ForegroundColor Cyan
        foreach ($p in ConvertTo-Array $m.packages) {
            $note = if ($p.note) { " - $($p.note)" } else { '' }
            Write-Host ("  {0,-40} {1}{2}" -f $p.id, $p.name, $note)
        }
        Write-Host "`nEnvironment variables:" -ForegroundColor Cyan
        foreach ($e in ConvertTo-Array $m.env) { Write-Host ("  {0} [{1}] = {2}" -f $e.name, $e.scope, $e.value) }
        Write-Host "`nPATH entries:" -ForegroundColor Cyan
        foreach ($pe in ConvertTo-Array $m.pathEntries) { Write-Host ("  {0} [{1}]" -f $pe.value, $pe.scope) }
        Write-Host "`nManual steps:" -ForegroundColor Cyan
        foreach ($s in ConvertTo-Array $m.steps) { Write-Host ("  - {0}" -f $s.description) }
    }

    'apply' {
        $m = Get-Manifest
        $admin = Test-IsAdmin
        if ($DryRun) { Write-Host "DRY RUN - no changes will be made.`n" -ForegroundColor Yellow }

        Write-Host "== Packages ==" -ForegroundColor Cyan
        foreach ($pkg in ConvertTo-Array $m.packages) {
            if (Test-PackageInstalled $pkg.id) {
                Write-Host "  [skip]    $($pkg.name) already installed"
            }
            else {
                Write-Host "  [install] $($pkg.name) ($($pkg.id))" -ForegroundColor Green
                if (-not $DryRun) {
                    if (Install-Package $pkg) { Write-Host "            ok" } else { Write-Host "            FAILED" -ForegroundColor Red }
                }
            }
        }

        Write-Host "`n== Environment variables ==" -ForegroundColor Cyan
        foreach ($e in ConvertTo-Array $m.env) {
            if ($e.scope -eq 'Machine' -and -not $admin) {
                Write-Host "  [warn]    $($e.name) needs an elevated shell (Machine scope) - skipped" -ForegroundColor Yellow
                continue
            }
            $cur = [Environment]::GetEnvironmentVariable($e.name, $e.scope)
            if ($cur -eq $e.value) { Write-Host "  [skip]    $($e.name) already set" }
            else {
                Write-Host "  [set]     $($e.name) [$($e.scope)]" -ForegroundColor Green
                if (-not $DryRun) { [Environment]::SetEnvironmentVariable($e.name, $e.value, $e.scope) }
            }
        }

        Write-Host "`n== PATH entries ==" -ForegroundColor Cyan
        foreach ($pe in ConvertTo-Array $m.pathEntries) {
            if ($pe.scope -eq 'Machine' -and -not $admin) {
                Write-Host "  [warn]    $($pe.value) needs an elevated shell (Machine scope) - skipped" -ForegroundColor Yellow
                continue
            }
            $cur = [Environment]::GetEnvironmentVariable('Path', $pe.scope)
            if (($cur -split ';') -contains $pe.value) { Write-Host "  [skip]    $($pe.value) already on PATH" }
            else {
                Write-Host "  [add]     $($pe.value) [$($pe.scope)]" -ForegroundColor Green
                if (-not $DryRun) {
                    $updated = ($cur.TrimEnd(';') + ';' + $pe.value)
                    [Environment]::SetEnvironmentVariable('Path', $updated, $pe.scope)
                }
            }
        }

        $steps = ConvertTo-Array $m.steps
        if ($steps.Count) {
            Write-Host "`n== Manual steps (do these yourself) ==" -ForegroundColor Cyan
            foreach ($s in $steps) { Write-Host "  - $($s.description)" }
        }
        Write-Host "`nDone. Open a new terminal to pick up PATH/env changes." -ForegroundColor Cyan
    }

    'add-package' {
        if (-not $Id) { throw "Provide -Id (e.g. -Id OpenJS.NodeJS.LTS)" }
        $m = Get-Manifest
        if ((ConvertTo-Array $m.packages | Where-Object { $_.id -eq $Id })) {
            Write-Host "$Id already in manifest." -ForegroundColor Yellow; return
        }
        $entry = [pscustomobject]@{
            id        = $Id
            name      = if ($Name) { $Name } else { $Id }
            override  = $Override
            note      = $Note
            installed = (Get-Date -Format 'yyyy-MM-dd')
        }
        $m.packages = @(ConvertTo-Array $m.packages) + $entry
        Save-Manifest $m
    }

    'add-env' {
        if (-not $Name) { throw "Provide -Name" }
        $m = Get-Manifest
        $m.env = @(ConvertTo-Array $m.env | Where-Object { -not ($_.name -eq $Name -and $_.scope -eq $Scope) })
        $m.env += [pscustomobject]@{ name = $Name; value = $Value; scope = $Scope }
        Save-Manifest $m
    }

    'add-path' {
        if (-not $Value) { throw "Provide -Value (the directory to add)" }
        $m = Get-Manifest
        if ((ConvertTo-Array $m.pathEntries | Where-Object { $_.value -eq $Value -and $_.scope -eq $Scope })) {
            Write-Host "$Value [$Scope] already in manifest." -ForegroundColor Yellow; return
        }
        $m.pathEntries = @(ConvertTo-Array $m.pathEntries) + [pscustomobject]@{ value = $Value; scope = $Scope }
        Save-Manifest $m
    }

    'add-step' {
        if (-not $Description) { throw "Provide -Description" }
        $m = Get-Manifest
        $m.steps = @(ConvertTo-Array $m.steps) + [pscustomobject]@{
            description = $Description; added = (Get-Date -Format 'yyyy-MM-dd')
        }
        Save-Manifest $m
    }
}
