#!/usr/bin/env bash
# Verifies the statusLine merge filter used in spec.yaml preserves existing keys.
set -euo pipefail

SL='{"type":"command","command":"~/.claude/statusline/statusline.sh"}'
merge() { jq --argjson sl "$SL" '.statusLine = $sl' "$1"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/statusline-test.XXXXXX")
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
