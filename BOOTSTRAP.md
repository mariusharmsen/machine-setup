# Bootstrap a new laptop

This repo carries Marius' machine-setup skills and the install manifests. On any
new machine, three steps get you to "tell Claude: set up my laptop".

## Windows

Open PowerShell:

```powershell
# 1. Get git + Claude Code CLI (winget ships with Windows 11)
winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements
winget install --id Anthropic.ClaudeCode --silent --accept-package-agreements --accept-source-agreements

# 2. Clone this repo (open a NEW terminal first so git is on PATH)
git clone https://github.com/mariusharmsen/machine-setup.git $env:USERPROFILE\machine-setup

# 3. Link the skills into Claude Code
powershell -File $env:USERPROFILE\machine-setup\install-skills.ps1
```

Then run `claude`, sign in, and say: **"set up my laptop"** — the
windows-machine-setup skill replays the Windows manifest (preview first with a
dry run). Docker/WSL2 and other manual steps are printed as a checklist.

## macOS

Open Terminal:

```bash
# 1. Get the basics: Xcode command line tools (includes git), Homebrew, Claude Code CLI
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
curl -fsSL https://claude.ai/install.sh | bash

# 2. Clone this repo
git clone https://github.com/mariusharmsen/machine-setup.git ~/machine-setup

# 3. Link the skills into Claude Code
bash ~/machine-setup/install-skills.sh
```

Then run `claude`, sign in, and say: **"set up my laptop"** — the
mac-machine-setup skill replays the Mac manifest.

### Capturing an existing Mac

Already set a Mac up by hand (like the one this week)? Clone the repo on it, link
the skills, and tell Claude: **"import my brew packages into the machine
manifest"** — it runs `setup.py import-brew`, which records every installed
formula and cask. Review the list, prune what you don't want replayed, commit and
push. From then on that Mac's setup is reproducible too.

## Keeping it in sync

Whenever Claude installs something on any machine, the skills record it in the
manifest — commit and push this repo afterwards ("commit my machine setup"), and
pull it on the other machines. Windows and Mac manifests are separate files, so
the two OSes never fight.
