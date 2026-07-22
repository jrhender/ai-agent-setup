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
