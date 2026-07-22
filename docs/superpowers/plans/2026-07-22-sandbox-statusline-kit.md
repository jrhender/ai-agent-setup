# Docker Sandbox Statusline Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a committed Docker Sandboxes mixin kit that auto-installs daniel3303/ClaudeCodeStatusLine into every `sbx run claude` sandbox.

**Architecture:** A `kind: mixin` kit directory (`sandbox-kits/claude-statusline/`) vendors the upstream `statusline.sh` under `files/home/.claude/statusline/` (which Docker maps to `/home/agent/.claude/...`). Its `spec.yaml` runs three install steps at sandbox creation: install deps, make the script executable, and merge the `statusLine` block into `~/.claude/settings.json` via `jq`. A repo README documents an `sbx` shell wrapper that applies the kit by default.

**Tech Stack:** Docker Sandboxes (`sbx` CLI), YAML kit spec, Bash, `jq`.

## Global Constraints

- Kit lives in this repo at `sandbox-kits/claude-statusline/` (version-controlled, not under `~/.claude`).
- Kit kind is `mixin` (`schemaVersion: "1"`, `kind: mixin`).
- `files/home/` maps to `/home/agent/`; the vendored script's in-sandbox path is `/home/agent/.claude/statusline/statusline.sh`.
- Runtime deps to install in-sandbox: `jq`, `curl`, `git`.
- settings.json wiring is a **jq merge** (preserve existing keys), never an overwrite.
- The `statusLine` command value is exactly `~/.claude/statusline/statusline.sh`.
- Install steps run under `sh`; wrap any multi-command / process-substitution step in `bash -c '…'`.
- Validate the kit with `sbx kit validate sandbox-kits/claude-statusline` (this is the authoritative structural check; `yq`/`bats` are not available).

---

### Task 1: Kit scaffold with vendored statusline script

**Files:**
- Create: `sandbox-kits/claude-statusline/files/home/.claude/statusline/statusline.sh`

**Interfaces:**
- Produces: the vendored script at `files/home/.claude/statusline/statusline.sh`, a Bash script beginning with a `#!` shebang. Task 2's `spec.yaml` and Task 3's merge assume this path exists.

- [ ] **Step 1: Fetch the upstream script content**

Use the WebFetch tool (not `curl`, since bash network access is restricted in this environment) to retrieve the raw script, then write it verbatim to the target path:

URL: `https://raw.githubusercontent.com/daniel3303/ClaudeCodeStatusLine/main/statusline.sh`

Write the returned content to:
`sandbox-kits/claude-statusline/files/home/.claude/statusline/statusline.sh`

- [ ] **Step 2: Verify it is a well-formed shell script**

Run:
```bash
head -1 sandbox-kits/claude-statusline/files/home/.claude/statusline/statusline.sh
bash -n sandbox-kits/claude-statusline/files/home/.claude/statusline/statusline.sh && echo "SYNTAX OK"
```
Expected: first line is a shebang (e.g. `#!/usr/bin/env bash` or `#!/bin/bash`); second command prints `SYNTAX OK` with exit code 0.

- [ ] **Step 3: Commit**

```bash
git add sandbox-kits/claude-statusline/files/home/.claude/statusline/statusline.sh
git commit -m "feat: vendor ClaudeCodeStatusLine script into sandbox kit"
```

---

### Task 2: Kit spec.yaml with install steps

**Files:**
- Create: `sandbox-kits/claude-statusline/spec.yaml`

**Interfaces:**
- Consumes: the vendored script path from Task 1 (`~/.claude/statusline/statusline.sh` in-sandbox).
- Produces: a valid mixin kit that `sbx kit validate` accepts. Task 4's README and wrapper reference this kit directory.

- [ ] **Step 1: Write spec.yaml**

Write exactly this to `sandbox-kits/claude-statusline/spec.yaml`:

```yaml
schemaVersion: "1"
kind: mixin
name: claude-statusline
displayName: Claude Code Status Line
description: Installs daniel3303/ClaudeCodeStatusLine and wires it into settings.json.

commands:
  install:
    - command: apt-get update && apt-get install -y jq curl git
      user: "0"
      description: Install statusline runtime dependencies (jq, curl, git)
    - command: chmod +x "$HOME/.claude/statusline/statusline.sh"
      description: Make the vendored statusline script executable
    - command: >-
        bash -c 'set -e; d="$HOME/.claude"; mkdir -p "$d"; f="$d/settings.json";
        [ -f "$f" ] || echo "{}" > "$f";
        tmp=$(mktemp);
        jq --argjson sl "{\"type\":\"command\",\"command\":\"~/.claude/statusline/statusline.sh\"}" ".statusLine = \$sl" "$f" > "$tmp"
        && mv "$tmp" "$f"'
      description: Merge the statusLine block into ~/.claude/settings.json
```

- [ ] **Step 2: Validate the kit structure**

Run:
```bash
sbx kit validate sandbox-kits/claude-statusline
```
Expected: exit code 0 with a success/validation-passed message. If `sbx` reports a schema error, fix the offending field per the message and re-run until it passes.

- [ ] **Step 3: Commit**

```bash
git add sandbox-kits/claude-statusline/spec.yaml
git commit -m "feat: add claude-statusline mixin kit spec"
```

---

### Task 3: Verify the settings.json merge logic

This task proves the exact `jq` filter embedded in Task 2's third install step behaves correctly, using `jq` directly (the sandbox is not needed to test the filter).

**Files:**
- Create: `sandbox-kits/claude-statusline/test/test-settings-merge.sh`

**Interfaces:**
- Consumes: the jq filter `.statusLine = $sl` with `--argjson sl '{"type":"command","command":"~/.claude/statusline/statusline.sh"}'` from Task 2.

- [ ] **Step 1: Write the failing test**

Write this to `sandbox-kits/claude-statusline/test/test-settings-merge.sh`:

```bash
#!/usr/bin/env bash
# Verifies the statusLine merge filter used in spec.yaml preserves existing keys.
set -euo pipefail

SL='{"type":"command","command":"~/.claude/statusline/statusline.sh"}'
merge() { jq --argjson sl "$SL" '.statusLine = $sl' "$1"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Case 1: empty settings -> statusLine added
echo '{}' > "$tmp/a.json"
got=$(merge "$tmp/a.json")
[ "$(echo "$got" | jq -r '.statusLine.command')" = "~/.claude/statusline/statusline.sh" ] \
  || { echo "FAIL: statusLine not added to empty settings"; exit 1; }

# Case 2: existing keys preserved, statusLine added
echo '{"theme":"dark","model":"claude-opus-4-8"}' > "$tmp/b.json"
got=$(merge "$tmp/b.json")
[ "$(echo "$got" | jq -r '.theme')" = "dark" ]  || { echo "FAIL: theme key clobbered"; exit 1; }
[ "$(echo "$got" | jq -r '.model')" = "claude-opus-4-8" ] || { echo "FAIL: model key clobbered"; exit 1; }
[ "$(echo "$got" | jq -r '.statusLine.type')" = "command" ] || { echo "FAIL: statusLine.type wrong"; exit 1; }

# Case 3: pre-existing statusLine is replaced, not merged into stale value
echo '{"statusLine":{"type":"command","command":"/old/path.sh"}}' > "$tmp/c.json"
got=$(merge "$tmp/c.json")
[ "$(echo "$got" | jq -r '.statusLine.command')" = "~/.claude/statusline/statusline.sh" ] \
  || { echo "FAIL: stale statusLine not replaced"; exit 1; }

echo "ALL PASS"
```

- [ ] **Step 2: Run it to confirm it passes**

Run:
```bash
bash sandbox-kits/claude-statusline/test/test-settings-merge.sh
```
Expected: prints `ALL PASS`, exit code 0.

(If it fails, the jq filter in Task 2 and this test are out of sync — reconcile them so both use `.statusLine = $sl` with the identical `--argjson sl` value.)

- [ ] **Step 3: Commit**

```bash
git add sandbox-kits/claude-statusline/test/test-settings-merge.sh
git commit -m "test: verify statusLine settings merge preserves existing keys"
```

---

### Task 4: Update script, README, and default-sbx wrapper docs

**Files:**
- Create: `sandbox-kits/claude-statusline/setup.sh`
- Create: `sandbox-kits/claude-statusline/README.md`

**Interfaces:**
- Consumes: the kit directory from Tasks 1–2.
- Produces: `setup.sh` (re-vendors the upstream script + validates), and README usage docs including the `sbx` shell wrapper.

- [ ] **Step 1: Write setup.sh**

Write this to `sandbox-kits/claude-statusline/setup.sh`:

```bash
#!/usr/bin/env bash
# Re-vendor the upstream statusline script and validate the kit.
# Run this to pick up upstream ClaudeCodeStatusLine changes.
set -euo pipefail

kit_dir="$(cd "$(dirname "$0")" && pwd)"
dest="$kit_dir/files/home/.claude/statusline/statusline.sh"
url="https://raw.githubusercontent.com/daniel3303/ClaudeCodeStatusLine/main/statusline.sh"

echo "Fetching $url"
mkdir -p "$(dirname "$dest")"
curl -fsSL "$url" -o "$dest"
chmod +x "$dest"
bash -n "$dest"
echo "Vendored script updated: $dest"

echo "Validating kit..."
sbx kit validate "$kit_dir"

cat <<'EOF'

Done. To apply this kit to every `sbx run claude`, add to ~/.zshrc:

  sbx() {
    if [[ "$1" == "run" && "$2" == "claude" ]]; then
      command sbx "$@" --kit /Users/john/code/jrhender/ai-agent-setup/sandbox-kits/claude-statusline
    else
      command sbx "$@"
    fi
  }
EOF
```

- [ ] **Step 2: Syntax-check setup.sh**

Run:
```bash
bash -n sandbox-kits/claude-statusline/setup.sh && echo "SYNTAX OK"
chmod +x sandbox-kits/claude-statusline/setup.sh
```
Expected: `SYNTAX OK`.

- [ ] **Step 3: Write README.md**

Write this to `sandbox-kits/claude-statusline/README.md`:

```markdown
# claude-statusline sandbox kit

A Docker Sandboxes **mixin kit** that installs
[daniel3303/ClaudeCodeStatusLine](https://github.com/daniel3303/ClaudeCodeStatusLine)
into every `sbx run claude` sandbox and wires it into `~/.claude/settings.json`.

## What it does

At sandbox creation the kit:

1. Drops the vendored `statusline.sh` at `~/.claude/statusline/statusline.sh`.
2. Installs `jq`, `curl`, `git`.
3. `chmod +x` the script.
4. Merges `{ "statusLine": { "type": "command", "command": "~/.claude/statusline/statusline.sh" } }`
   into `~/.claude/settings.json` (existing keys preserved).

## Apply it once

```bash
sbx run claude --kit /Users/john/code/jrhender/ai-agent-setup/sandbox-kits/claude-statusline
```

## Apply it by default

Add to `~/.zshrc` so every `sbx run claude` gets it:

```zsh
sbx() {
  if [[ "$1" == "run" && "$2" == "claude" ]]; then
    command sbx "$@" --kit /Users/john/code/jrhender/ai-agent-setup/sandbox-kits/claude-statusline
  else
    command sbx "$@"
  fi
}
```

## Update the vendored script

```bash
./setup.sh
```

Re-fetches the upstream `statusline.sh`, validates the kit, and reprints the wrapper snippet.

## One-time runtime step

The status line reads usage / rate-limit data from Claude, so run `/login` inside the
sandbox once to authenticate.

## Test

```bash
bash test/test-settings-merge.sh   # verifies the settings-merge filter
sbx kit validate .                 # verifies kit structure
```
```

- [ ] **Step 4: Final validation**

Run:
```bash
sbx kit validate sandbox-kits/claude-statusline && echo "KIT OK"
bash sandbox-kits/claude-statusline/test/test-settings-merge.sh
```
Expected: `KIT OK` then `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add sandbox-kits/claude-statusline/setup.sh sandbox-kits/claude-statusline/README.md
git commit -m "docs: add setup script and README for claude-statusline kit"
```
