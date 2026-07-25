# Design: `claude-statusline` mixin kit for Docker Sandboxes

**Date:** 2026-07-22
**Status:** Approved

## Goal

Every Claude Code sandbox launched with Docker Sandboxes (`sbx run claude`) should
come up with [daniel3303/ClaudeCodeStatusLine](https://github.com/daniel3303/ClaudeCodeStatusLine)
already installed and wired into `~/.claude/settings.json` — with no manual steps
inside the sandbox.

## Background

- **Docker Sandboxes** run AI coding agents in isolated microVMs and are customized
  with **mixin kits**: a directory holding a `spec.yaml` manifest plus an optional
  `files/` tree. `files/home/` maps to `/home/agent/`; `spec.yaml` can run `install`
  commands and set environment/credentials. A kit is applied with
  `sbx run claude --kit ./my-kit/` (or `sbx kit add <sandbox> ./my-kit/`).
- **ClaudeCodeStatusLine** needs, at runtime: the `statusline.sh` script at
  `~/.claude/statusline/statusline.sh` (executable), a `statusLine` block in
  `~/.claude/settings.json`, and `jq`, `curl`, `git` on `PATH`. It reads usage /
  rate-limit data, so the sandbox must be logged into Claude (`/login`).

## Decisions

| Fork | Choice | Why |
|------|--------|-----|
| Script delivery | **Vendor** the script into the kit's `files/` | Self-contained and deterministic; works even under a Locked Down network policy (no build-time GitHub fetch). |
| Automation | **Default for every sandbox** via a shell function wrapping `sbx` | No extra typing; `sbx run claude` always gets the statusline. |
| settings.json | **`jq` merge at build** | Preserves any other keys Claude Code writes to `settings.json`. |
| Location | **Committed to this repo** under `sandbox-kits/` | The kit is version-controlled here rather than living loose under `~/.claude`. |

## Kit layout

Lives in this repo at `sandbox-kits/claude-statusline/`:

```
sandbox-kits/claude-statusline/
├── spec.yaml
├── setup.sh                    # fetches/updates vendored script, validates kit
└── files/
    └── home/
        └── .claude/
            └── statusline/
                └── statusline.sh   # vendored from upstream
```

`files/home/` → `/home/agent/`, so the script lands at
`/home/agent/.claude/statusline/statusline.sh`.

## `spec.yaml`

A `kind: mixin` kit with three `install` steps (run once at sandbox creation):

1. **Dependencies** (as root, `user: "0"`):
   `apt-get update && apt-get install -y jq curl git`. Idempotent — a no-op when
   already present.
2. **Executable bit** (agent user): `chmod +x ~/.claude/statusline/statusline.sh`
   — the `files/` drop does not reliably preserve the mode.
3. **Merge settings** (agent user): read `~/.claude/settings.json` if present (else
   `{}`), merge in the `statusLine` block, write back atomically (temp file + move).

Install steps run under `sh`; any multi-command step is wrapped in `bash -c '…'`.

The merged block:

```json
{ "statusLine": { "type": "command", "command": "~/.claude/statusline/statusline.sh" } }
```

## Making it the default

A shell function in `~/.zshrc` forwards to the real `sbx`, injecting the kit only
for `run claude`. Point it at the checked-out repo path:

```zsh
sbx() {
  if [[ "$1" == "run" && "$2" == "claude" ]]; then
    command sbx "$@" --kit /Users/john/code/jrhender/ai-agent-setup/sandbox-kits/claude-statusline
  else
    command sbx "$@"
  fi
}
```

## Setup / update automation

A `setup.sh` in the kit directory:

1. Fetches the current `statusline.sh` from upstream into `files/home/.claude/statusline/`.
2. Runs `sbx kit validate .` to verify structure.
3. Prints the `sbx` shell-function snippet to add to `~/.zshrc`.

Re-running `setup.sh` updates the vendored script — the deliberate, explicit path to
pick up upstream changes (the trade-off of vendoring for determinism).

## Out of scope

- **Login:** the statusline needs the sandbox authenticated to Claude (`/login`
  inside the sandbox, once). That is a runtime step, not part of this kit.

## Verification

- `sbx kit validate sandbox-kits/claude-statusline` passes.
- `sbx run claude …` launches and the status line renders at the bottom of Claude Code
  inside the sandbox.

## References

- [Docker Sandboxes — get started](https://docs.docker.com/ai/sandboxes/get-started/)
- [Kits](https://docs.docker.com/ai/sandboxes/customize/kits/)
- [Kit spec reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference/)
- [ClaudeCodeStatusLine](https://github.com/daniel3303/ClaudeCodeStatusLine)
