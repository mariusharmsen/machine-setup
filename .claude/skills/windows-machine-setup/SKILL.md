---
name: windows-machine-setup
description: >-
  Maintain a reproducible manifest of this Windows machine's setup and replay it.
  Use whenever the user wants to record what they've installed/configured, see
  their setup, or rebuild a machine — e.g. "set up my laptop", "install
  everything I had", "reinstall my whole setup on this new PC", "what have I
  installed", "remember this install so you can redo it later". Every time you
  install software, set an env var, or add to PATH on this machine, ALSO record
  it here so the setup stays reproducible. This skill owns the install manifest
  that `winget-install`, `windows-env-vars`, and `windows-dev-setup` feed into.
---

# Reproducible machine setup

This skill keeps a **manifest** of the machine's desired state and can replay it
on demand. The point: the user does things once (install a tool, set an env var),
you record each one, and later "set up my laptop" rebuilds everything — installing
only what's missing, so it's safe to run repeatedly and on a fresh PC.

The manifest is `scripts/manifest.json` (next to the script). It holds four lists:
`packages` (winget), `env` (variables), `pathEntries`, and `steps` (manual things
that can't be automated, e.g. signing into an app).

Drive everything through `scripts/setup.ps1` — don't hand-edit the JSON, since the
script keeps it well-formed and stamps dates.

## Two habits that make this work

1. **Record as you go.** Whenever you (or the agent) install a package, set an env
   var, or add a PATH entry on this machine, immediately add it to the manifest.
   This is what makes "redo my setup" possible later. The other Windows skills
   point back here for exactly this reason.
2. **Apply is idempotent.** `apply` checks each item and skips what's already
   present, so it's safe to run on the current machine or a brand-new one.

## Commands

Run with the PowerShell tool. `$S` below is the script path
`C:\Users\mariu\.claude\skills\windows-machine-setup\scripts\setup.ps1`.

```powershell
# See the whole recorded setup
& $S list

# Rebuild the machine: install/configure everything missing
& $S apply
& $S apply -DryRun        # preview only, change nothing

# Record things (do this right after you actually install/configure them)
& $S add-package -Id OpenJS.NodeJS.LTS -Name "Node.js LTS" -Note "web dev"
& $S add-package -Id EclipseAdoptium.Temurin.25.JDK -Name "Java 25 LTS" -Override "ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJavaHome"
& $S add-env  -Name GOPATH -Value "C:\Users\mariu\go" -Scope User
& $S add-path -Value "C:\tools\bin" -Scope User
& $S add-step -Description "Sign into Docker Desktop and enable WSL2 integration"
```

## How to use it in practice

- **"What do I have?"** → `& $S list`.
- **"Set up my laptop" / new machine** → `& $S apply`. Run `apply -DryRun` first
  to show the user what will happen, then run it for real. For Machine-scope env
  vars/PATH you need an **elevated** PowerShell — the script warns and skips those
  if you're not admin, so re-run elevated if it reports any.
- **Just installed something** → record it with `add-package` (include the
  `-Override` string if the installer used one, so a rebuild matches exactly).
- After `apply`, remind the user to open a **new terminal** so PATH/env changes
  take effect, and to complete any printed **manual steps**.

## Relationship to the other skills

`winget-install`, `windows-env-vars`, and `windows-dev-setup` do the actual work;
this skill is the memory. The rule of thumb: any durable change to the machine
gets a matching `add-*` here. Prefer storing winget **package ids** over ad-hoc
downloads — they reinstall cleanly. Things that genuinely can't be scripted
(account sign-ins, license keys, GUI toggles) go in `steps` so a rebuild surfaces
them as a checklist.
