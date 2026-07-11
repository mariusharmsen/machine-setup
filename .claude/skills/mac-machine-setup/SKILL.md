---
name: mac-machine-setup
description: Maintain a reproducible manifest of this Mac's setup (Homebrew packages, env vars, PATH, manual steps) and replay it. Use on macOS whenever the user wants to record what they've installed/configured, see their setup, rebuild a machine, or says "set up my laptop", "install everything I had", "what have I installed", "remember this install". Every time you install software (brew install), set an env var, or add to PATH on a Mac, ALSO record it here so the setup stays reproducible. macOS twin of windows-machine-setup.
---

# Reproducible Mac setup

Keeps a **manifest** of this Mac's desired state and replays it on demand. The user
does things once (install a tool, set an env var), you record each one, and later
"set up my laptop" rebuilds everything — installing only what's missing, so it's
safe to run repeatedly and on a fresh Mac.

The manifest is `scripts/manifest.json` (next to the script): `packages` (Homebrew
formulas and casks), `env`, `pathEntries`, and `steps` (manual things like app
sign-ins). Drive everything through `scripts/setup.py` — don't hand-edit the JSON.

## Two habits that make this work

1. **Record as you go.** Whenever you install a package, set an env var, or add a
   PATH entry on this Mac, immediately add it to the manifest.
2. **Apply is idempotent.** `apply` skips what's already present — safe on the
   current machine or a brand-new one.

## Commands

`$S` below is `<this-skill-dir>/scripts/setup.py`, run with `python3`.

```bash
python3 $S list                                  # see the whole recorded setup
python3 $S apply                                 # rebuild: install/configure everything missing
python3 $S apply --dry-run                       # preview only

python3 $S add-package node --note "web dev"     # record a brew formula
python3 $S add-package docker --cask             # record a cask (GUI app)
python3 $S add-env JAVA_HOME "$(/usr/libexec/java_home)"
python3 $S add-path "$HOME/tools/bin"
python3 $S add-step "Sign into Docker Desktop"

python3 $S import-brew                           # bulk-add everything brew already has (great on an existing Mac)
```

Env vars and PATH entries persist via a managed block in `~/.zprofile` that
`apply` regenerates from the manifest — tell the user to open a new terminal
(or `source ~/.zprofile`) afterwards.

## On an already-set-up Mac

`import-brew` pulls in every top-level formula (`brew leaves`) and cask already
installed, so an existing machine's state can be captured in one command. Have the
user review the list afterwards and prune one-off experiments they don't want
replayed on future machines.

## Relationship to the Windows skills

This is the macOS counterpart of `windows-machine-setup` (winget/PowerShell based).
The manifests are separate per OS — a package name on brew rarely matches a winget
id — but the philosophy and commands mirror each other. Both live in the same
`machine-setup` repo; see `BOOTSTRAP.md` at the repo root for new-machine steps.
