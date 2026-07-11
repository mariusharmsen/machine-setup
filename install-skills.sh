#!/usr/bin/env bash
# Links this repo's Mac-relevant skills into the user's Claude Code skills folder.
# Idempotent: skips links that already exist. Symlinks keep the repo as the single
# source of truth - a git pull updates the live skills.
set -euo pipefail
repo_skills="$(cd "$(dirname "$0")" && pwd)/.claude/skills"
user_skills="$HOME/.claude/skills"
mkdir -p "$user_skills"

for dir in "$repo_skills"/*/; do
    name="$(basename "$dir")"
    case "$name" in windows-*|winget-*) continue ;; esac
    link="$user_skills/$name"
    if [ -e "$link" ]; then
        echo "[skip] $name already present"
    else
        ln -s "$dir" "$link"
        echo "[link] $name"
    fi
done
echo "Done. Skills are live in Claude Code (new sessions pick them up)."
