---
name: windows-dev-setup
description: >-
  Set up a development environment or language toolchain on Windows from scratch.
  Use when the user wants to start developing in a language or stack and needs the
  tools in place — e.g. "set me up for Node development", "I want to start a Python
  project", "get this machine ready for Java/Spring", "install a C++ toolchain", or
  "set up Git". Orchestrates installing the runtime/SDK, wiring up PATH/env vars,
  installing supporting tooling (package managers, build tools, an editor), and
  verifying the whole chain works with a smoke test. Trigger for any "set up / get
  ready for / start developing in <stack>" request on Windows.
---

# Setting up a dev environment on Windows

Goal: take the machine from "nothing installed" to "I can create and run a project
in this stack." Lean on the companion skills — **winget-install** for installing
packages and **windows-env-vars** for PATH/var wiring — and add the
language-specific glue and a real smoke test here.

## Workflow

1. **Confirm the stack and scope.** Which language/framework, and roughly what
   they'll build (web, CLI, data, etc.)? That decides which extras to include.
   Default to the latest **LTS** runtime unless they want bleeding edge.
2. **Install the core runtime/SDK** via the winget-install skill.
3. **Wire up environment** via the windows-env-vars skill (e.g. `JAVA_HOME`,
   `GOPATH`) — only where the toolchain needs it; many modern installers handle
   PATH themselves.
4. **Install supporting tooling** — package manager, build tools, an editor, a
   version control client. See per-stack notes below.
5. **Smoke test the whole chain** in a fresh environment: create a tiny project,
   build/run it, confirm it works, then clean up. This is what proves the setup,
   not the individual `--version` checks.

## Per-stack quick reference

### Node.js / JavaScript
- Install: `OpenJS.NodeJS.LTS` (bundles `npm`). Consider `Git.Git`.
- Optional: `pnpm`/`yarn` via `npm i -g`, or `Volta.Volta` / `Schniz.fnm` for
  managing multiple Node versions.
- Smoke test: `node -e "console.log('ok')"`, then `npm init -y` in a temp dir.

### Python
- Install: `Python.Python.3.<NN>` (includes `pip`). Newest stable is fine here;
  Python doesn't use the LTS model.
- Verify `py --version` and `python --version`; create a venv:
  `python -m venv .venv` and confirm activation works.
- Optional: `astral-sh.uv` for fast env/dependency management.

### Java / JVM
- Install: `EclipseAdoptium.Temurin.<NN>.JDK` (latest LTS). Set `JAVA_HOME` and
  ensure `%JAVA_HOME%\bin` is on PATH (the Temurin installer can do both).
- Build tool: `Apache.Maven` or `Gradle.Gradle`.
- Smoke test: compile and run a one-class `HelloWorld`, or `mvn -v`.

### Go
- Install: `GoLang.Go` (puts `go` on PATH). Set `GOPATH` only if customizing.
- Smoke test: `go run` a tiny `main.go`.

### .NET
- Install: `Microsoft.DotNet.SDK.<NN>` (LTS).
- Smoke test: `dotnet new console -o tmp && dotnet run --project tmp`.

### C/C++
- Install: `Microsoft.VisualStudio.2022.BuildTools` (MSVC + Windows SDK), or
  MSYS2 (`MSYS2.MSYS2`) for a GCC toolchain.
- Smoke test: compile a tiny `main.c`.

## Common extras
- Editor: `Microsoft.VisualStudioCode`.
- Version control: `Git.Git` — then set `user.name` / `user.email`.
- Containers: `Docker.DockerDesktop` (needs WSL2; expect a reboot).

## Verify in a fresh shell
Everything installed in this session won't be on the PATH of already-open
terminals. Run the smoke test in a new shell, or reload PATH in-session (see the
windows-env-vars skill). Report the actual smoke-test output — that's the proof
the environment is ready.
