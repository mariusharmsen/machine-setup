---
name: windows-env-vars
description: >-
  Read, set, append, or remove Windows environment variables and PATH entries
  persistently. Use whenever the user wants to add something to their PATH, set
  or change an environment variable (JAVA_HOME, GOPATH, a custom var, etc.),
  fix a "command not recognized" problem after installing a tool, or inspect
  what their PATH/env currently contains. Handles the Machine vs. User scope
  distinction, persistence across reboots, and reloading values into the current
  shell. Trigger on phrases like "add X to PATH", "set JAVA_HOME", or "my tool
  isn't found even though I installed it".
---

# Managing Windows environment variables

The trap with Windows env vars is scope and persistence. `$env:FOO = 'x'` in
PowerShell only affects the current process and vanishes when it closes. To make
a change stick, you must write it to the **User** or **Machine** scope, which is
backed by the registry. This skill is about doing that safely.

## Scopes

- **User** (`'User'`) — applies to this user only. No admin rights needed. Default
  choice for per-user tools and personal config.
- **Machine** (`'Machine'`) — applies to all users; **requires an elevated
  (Administrator) shell**. Use when a tool must be available system-wide or a
  service needs it.
- **Process** (`$env:FOO`) — current shell only, temporary. Useful to *test* a
  value before persisting it.

## Read before you write

Always capture the current value first, so you can describe exactly what changed
and reconstruct it if needed:

```powershell
[Environment]::GetEnvironmentVariable('Path','User')      # or 'Machine'
[Environment]::GetEnvironmentVariable('JAVA_HOME','Machine')
```

## Set a simple variable

```powershell
[Environment]::SetEnvironmentVariable('JAVA_HOME',
  'C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot', 'User')
```

## Append to PATH safely — never overwrite

PATH is a single semicolon-delimited string. Read it, check the entry isn't
already there, then append. Overwriting PATH wholesale is the classic way to
break a machine.

```powershell
$scope = 'User'                                  # or 'Machine' (needs admin)
$new   = 'C:\tools\mybin'
$cur   = [Environment]::GetEnvironmentVariable('Path', $scope)
if (($cur -split ';') -notcontains $new) {
    $updated = ($cur.TrimEnd(';') + ';' + $new)
    [Environment]::SetEnvironmentVariable('Path', $updated, $scope)
    Write-Output "Added $new to $scope PATH."
} else {
    Write-Output "$new is already on $scope PATH."
}
```

## Remove a PATH entry

```powershell
$scope = 'User'
$drop  = 'C:\tools\mybin'
$cur   = [Environment]::GetEnvironmentVariable('Path', $scope)
$updated = (($cur -split ';') | Where-Object { $_ -and $_ -ne $drop }) -join ';'
[Environment]::SetEnvironmentVariable('Path', $updated, $scope)
```

## Make the change visible now

Persisted changes do **not** reach already-running shells or apps. A brand-new
terminal picks them up automatically. To verify in the *current* shell without
restarting it, rebuild the process PATH from both scopes:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path','User')
```

Then re-run whatever was failing (e.g. `mytool --version`). This is also the fix
for "I installed a tool but the command isn't recognized" — usually the installer
set PATH correctly and the user just needs a fresh shell or this reload.

## Record persistent changes

After you persist an env var or PATH entry (User/Machine scope, not a temporary
`$env:` one), record it in the machine manifest so a future rebuild reproduces it
— see the **windows-machine-setup** skill:

```powershell
$S = "C:\Users\mariu\.claude\skills\windows-machine-setup\scripts\setup.ps1"
& $S add-env  -Name JAVA_HOME -Value "C:\Program Files\..." -Scope Machine
& $S add-path -Value "C:\tools\bin" -Scope User
```

## Diagnosing "command not found" after an install

1. Confirm the tool's `bin` directory actually exists on disk.
2. Check whether it's on the persisted PATH:
   `([Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
     [Environment]::GetEnvironmentVariable('Path','User')) -split ';'`
3. If missing, append the `bin` dir (pattern above). If present, the open shell
   is just stale — reload (above) or open a new terminal.
