#!/usr/bin/env python3
"""Maintain and reproduce a macOS machine setup from a JSON manifest.

The macOS twin of the Windows setup.ps1: records desired state (Homebrew
packages, env vars, PATH entries, manual steps) and re-applies it idempotently.
Manifest lives next to this script as manifest.json. Env/PATH persistence is a
managed block in ~/.zprofile that apply regenerates from the manifest.

Usage:
  setup.py list
  setup.py apply [--dry-run]
  setup.py add-package NAME [--cask] [--note "why"]
  setup.py add-env NAME VALUE
  setup.py add-path /some/dir
  setup.py add-step "Sign into Docker Desktop"
  setup.py import-brew          # bulk-add everything already installed via brew
"""
import datetime
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(HERE, "manifest.json")
ZPROFILE = os.path.expanduser("~/.zprofile")
BLOCK_START = "# >>> machine-setup managed block >>>"
BLOCK_END = "# <<< machine-setup managed block <<<"


def load():
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            m = json.load(f)
    else:
        m = {"version": 1, "updated": "", "packages": [], "env": [], "pathEntries": [], "steps": []}
    for key in ("packages", "env", "pathEntries", "steps"):
        m.setdefault(key, [])
    return m


def save(m):
    m["updated"] = datetime.date.today().isoformat()
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(m, f, indent=2)
        f.write("\n")
    print(f"Saved manifest -> {MANIFEST}")


def brew(*args, capture=False):
    return subprocess.run(["brew", *args], capture_output=capture, text=True)


def brew_installed(name, cask):
    kind = "--cask" if cask else "--formula"
    return brew("list", kind, name, capture=True).returncode == 0


def write_zprofile_block(m, dry_run):
    lines = [BLOCK_START]
    for e in m["env"]:
        lines.append(f'export {e["name"]}="{e["value"]}"')
    for p in m["pathEntries"]:
        lines.append(f'export PATH="{p["value"]}:$PATH"')
    lines.append(BLOCK_END)
    block = "\n".join(lines)

    existing = ""
    if os.path.exists(ZPROFILE):
        with open(ZPROFILE, encoding="utf-8") as f:
            existing = f.read()
    if BLOCK_START in existing:
        pre = existing.split(BLOCK_START)[0].rstrip("\n")
        post = existing.split(BLOCK_END)[-1].lstrip("\n")
        new_content = (pre + "\n\n" + block + "\n" + post).strip("\n") + "\n"
    else:
        new_content = (existing.rstrip("\n") + "\n\n" + block + "\n").lstrip("\n")

    if new_content != existing:
        print(f"  [update]  managed block in {ZPROFILE} ({len(m['env'])} env, {len(m['pathEntries'])} path)")
        if not dry_run:
            with open(ZPROFILE, "w", encoding="utf-8") as f:
                f.write(new_content)
    else:
        print(f"  [skip]    {ZPROFILE} block already up to date")


def cmd_list(m):
    print(f"Machine setup manifest (updated {m['updated']})")
    print("\nPackages (Homebrew):")
    for p in m["packages"]:
        kind = "cask   " if p.get("cask") else "formula"
        note = f" - {p['note']}" if p.get("note") else ""
        print(f"  [{kind}] {p['name']}{note}")
    print("\nEnvironment variables:")
    for e in m["env"]:
        print(f"  {e['name']} = {e['value']}")
    print("\nPATH entries:")
    for p in m["pathEntries"]:
        print(f"  {p['value']}")
    print("\nManual steps:")
    for s in m["steps"]:
        print(f"  - {s['description']}")


def cmd_apply(m, dry_run):
    if dry_run:
        print("DRY RUN - no changes will be made.\n")
    if subprocess.run(["which", "brew"], capture_output=True).returncode != 0:
        sys.exit("Homebrew is not installed. Run the bootstrap in BOOTSTRAP.md first.")

    print("== Packages ==")
    for p in m["packages"]:
        if brew_installed(p["name"], p.get("cask")):
            print(f"  [skip]    {p['name']} already installed")
        else:
            print(f"  [install] {p['name']}" + (" (cask)" if p.get("cask") else ""))
            if not dry_run:
                args = ["install"] + (["--cask"] if p.get("cask") else []) + [p["name"]]
                ok = brew(*args).returncode == 0
                print("            ok" if ok else "            FAILED")

    print("\n== Environment & PATH (~/.zprofile) ==")
    write_zprofile_block(m, dry_run)

    if m["steps"]:
        print("\n== Manual steps (do these yourself) ==")
        for s in m["steps"]:
            print(f"  - {s['description']}")
    print("\nDone. Open a new terminal (or 'source ~/.zprofile') to pick up env changes.")


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else "list"
    m = load()

    if cmd == "list":
        cmd_list(m)
    elif cmd == "apply":
        cmd_apply(m, "--dry-run" in args)
    elif cmd == "add-package":
        name = args[1]
        if any(p["name"] == name for p in m["packages"]):
            print(f"{name} already in manifest."); return
        note = args[args.index("--note") + 1] if "--note" in args else ""
        m["packages"].append({"name": name, "cask": "--cask" in args, "note": note,
                              "installed": datetime.date.today().isoformat()})
        save(m)
    elif cmd == "add-env":
        name, value = args[1], args[2]
        m["env"] = [e for e in m["env"] if e["name"] != name]
        m["env"].append({"name": name, "value": value})
        save(m)
    elif cmd == "add-path":
        value = args[1]
        if any(p["value"] == value for p in m["pathEntries"]):
            print(f"{value} already in manifest."); return
        m["pathEntries"].append({"value": value})
        save(m)
    elif cmd == "add-step":
        m["steps"].append({"description": args[1], "added": datetime.date.today().isoformat()})
        save(m)
    elif cmd == "import-brew":
        added = 0
        leaves = brew("leaves", capture=True).stdout.split()
        casks = brew("list", "--cask", capture=True).stdout.split()
        for name in leaves:
            if not any(p["name"] == name for p in m["packages"]):
                m["packages"].append({"name": name, "cask": False, "note": "imported from brew leaves",
                                      "installed": datetime.date.today().isoformat()}); added += 1
        for name in casks:
            if not any(p["name"] == name for p in m["packages"]):
                m["packages"].append({"name": name, "cask": True, "note": "imported from brew list --cask",
                                      "installed": datetime.date.today().isoformat()}); added += 1
        save(m)
        print(f"Imported {added} package(s). Review with 'setup.py list' and prune what you don't want replayed.")
    else:
        sys.exit(f"Unknown command '{cmd}'.\n{__doc__}")


if __name__ == "__main__":
    main()
