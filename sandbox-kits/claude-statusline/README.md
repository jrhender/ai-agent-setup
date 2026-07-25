# claude-statusline sandbox kit

A Docker Sandboxes **mixin kit** that installs
[daniel3303/ClaudeCodeStatusLine](https://github.com/daniel3303/ClaudeCodeStatusLine)
into every `sbx run claude` sandbox and wires it into `~/.claude/settings.json`.

## What it does

1. Delivers the vendored `statusline.sh` at `~/.claude/statusline/statusline.sh`
   via the kit's `files/`.
2. Runs one `install` command that jq-merges a `statusLine` entry into the agent's
   existing `~/.claude/settings.json`, invoking the script via
   `bash ~/.claude/statusline/statusline.sh` (no executable bit required).

The statusline's runtime dependencies (`jq`, `curl`, `git`) ship in the default
`claude` sandbox image, so the kit does not install them.

### Why it's built this way

Docker Sandboxes kits are experimental, and the delivery order below is *observed*,
not contractual:

- **Static `files/` are copied at sandbox creation, _after_ install commands run.**
  So an install command cannot `chmod` or read a `files/`-injected file — it isn't
  there yet — and a failing install command aborts creation with an opaque
  `500 ... failed to run sandbox container`. (An earlier `chmod` of the injected
  script is exactly what broke this kit.)
- **The base `claude` image already ships `~/.claude/settings.json`** with keys that
  must be kept — notably `defaultMode: bypassPermissions` and
  `bypassPermissionsModeAccepted: true`, which let the sandboxed agent run without
  permission prompts. That file *does* exist at install time, so we **jq-merge** into
  it rather than shipping our own (which would clobber those keys).

> **Verify, don't assume.** Static-file injection has known bugs (tar/ordering
> errors; files occasionally missing until a later `sbx kit add`). After creating a
> sandbox, confirm both pieces landed:
>
> ```bash
> sbx exec <sandbox> -- sh -c 'ls -l ~/.claude/statusline/statusline.sh; jq .statusLine ~/.claude/settings.json'
> ```

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
bash test/test-settings-merge.sh   # verifies the jq settings-merge filter
sbx kit validate .                 # verifies kit structure
```
