---
name: winget-install
description: >-
  Install, update, list, or remove software on Windows using winget. Use this
  whenever the user wants to install or get an app, tool, runtime, or SDK ("install
  Java", "get the latest Node", "I need Git on this laptop"), upgrade installed
  packages, uninstall something, or check what's installed. Covers choosing the
  right version (latest LTS vs. newest), running installs cleanly and silently,
  and verifying the result actually works afterward. Trigger even when winget
  isn't mentioned — it's the default installer on this machine.
---

# Installing software with winget

The job isn't done when winget says "Successfully installed" — it's done when you
have run the thing and seen it work. Treat install + verify as one task.

## 1. Look before installing

Check whether it's already present and find the available versions:

```powershell
winget list --id <Publisher.Package>          # already installed?
$ProgressPreference='SilentlyContinue'
winget search <name> --source winget --accept-source-agreements | Out-String
```

Always set `$ProgressPreference='SilentlyContinue'` first. winget's animated
progress bars otherwise flood the output with thousands of block characters and
can even surface as a spurious non-zero exit code.

## 2. Choose the version deliberately

For runtimes/SDKs (Java, Node, .NET, Python, Go), the search list often shows
several major versions. The **latest LTS** is almost always the right "latest"
for real use — it gets years of support, and tooling/libraries target it. Newer
non-LTS feature releases get only ~6 months of support.

Default to LTS, but tell the user the newest version exists and offer it. Don't
silently install a short-lived release when they said "latest" and meant "the one
I should actually use." When unsure, a one-line "I'll install the LTS (X); newest
is Y — say the word if you want that instead" is better than guessing wrong.

## 3. Install cleanly

```powershell
$ProgressPreference='SilentlyContinue'
winget install --id <Publisher.Package> --source winget `
  --accept-package-agreements --accept-source-agreements --silent
```

- `--id ... --source winget` pins the exact package and avoids the interactive
  "which one did you mean?" prompt.
- `--silent` suppresses the vendor installer UI (won't hang waiting for clicks).
- Large packages (JDKs, .NET, big IDEs) take a while — run the command in the
  **background** and read its output file when it finishes rather than blocking.
- Some installers expose feature flags via `--override` (e.g. JDKs can set
  `JAVA_HOME` and add themselves to PATH). Use them when the user will want the
  tool on PATH.

## 4. Verify — in a fresh environment

Installers update PATH and env vars at the machine/user level, but **already-open
shells don't see those changes**. To verify in the *current* session, reload the
environment from the registry-backed scopes first:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path','User')
<tool> --version
```

Then run the real check (`<tool> --version`, a smoke command, etc.) and show the
output. Note for the user: **new terminals will pick the tool up automatically;
they only need the reload trick inside a shell that was already open.**

Beware: many tools (Java's `java -version`, others) print version info to
**stderr**, which PowerShell renders as red "error" text. That is not a failure —
read the actual text and check the exit code.

## 5. Record it for reproducibility

Right after a successful install, add the package to the machine manifest so the
setup can be rebuilt later (this is what powers "set up my laptop"). Use the
**windows-machine-setup** skill:

```powershell
& "C:\Users\mariu\.claude\skills\windows-machine-setup\scripts\setup.ps1" `
  add-package -Id <Publisher.Package> -Name "<friendly name>" -Note "<why>"
```

Include the `-Override` string if you used one, so a rebuild matches exactly.

## 6. Manage existing software

```powershell
winget upgrade                                  # what has updates
winget upgrade --id <Publisher.Package>         # update one
winget upgrade --all                            # update everything
winget uninstall --id <Publisher.Package>       # remove
```

## Common package IDs

| Tool        | winget id                          |
|-------------|------------------------------------|
| Java (Temurin) | `EclipseAdoptium.Temurin.<NN>.JDK` |
| Node.js LTS | `OpenJS.NodeJS.LTS`                |
| Python      | `Python.Python.3.<NN>`             |
| Git         | `Git.Git`                          |
| Go          | `GoLang.Go`                        |
| .NET SDK    | `Microsoft.DotNet.SDK.<NN>`        |
| VS Code     | `Microsoft.VisualStudioCode`       |
| Docker Desktop | `Docker.DockerDesktop`          |
| 7-Zip       | `7zip.7zip`                        |

When in doubt, `winget search` for the exact id rather than guessing the suffix.
