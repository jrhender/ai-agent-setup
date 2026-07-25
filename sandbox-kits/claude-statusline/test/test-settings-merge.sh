#!/usr/bin/env bash
# Verifies the jq merge filter used in spec.yaml adds statusLine while preserving the
# base image's existing settings.json keys (defaultMode: bypassPermissions, etc.).
# Keep this filter identical to the one in spec.yaml's install command.
set -euo pipefail

FILTER='.statusLine={"type":"command","command":"bash ~/.claude/statusline/statusline.sh"}'
merge() { jq "$FILTER" "$1"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/statusline-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# Case 1: real base-image settings.json -> keys preserved, statusLine added
cat > "$tmp/base.json" <<'JSON'
{
  "themeId": 1,
  "alwaysThinkingEnabled": true,
  "defaultMode": "bypassPermissions",
  "bypassPermissionsModeAccepted": true
}
JSON
got=$(merge "$tmp/base.json")
[ "$(echo "$got" | jq -r '.defaultMode')" = "bypassPermissions" ] \
  || { echo "FAIL: defaultMode not preserved"; exit 1; }
[ "$(echo "$got" | jq -r '.bypassPermissionsModeAccepted')" = "true" ] \
  || { echo "FAIL: bypassPermissionsModeAccepted not preserved"; exit 1; }
[ "$(echo "$got" | jq -r '.themeId')" = "1" ] || { echo "FAIL: themeId not preserved"; exit 1; }
[ "$(echo "$got" | jq -r '.statusLine.command')" = "bash ~/.claude/statusline/statusline.sh" ] \
  || { echo "FAIL: statusLine.command wrong"; exit 1; }
[ "$(echo "$got" | jq -r '.statusLine.type')" = "command" ] \
  || { echo "FAIL: statusLine.type wrong"; exit 1; }

# Case 2: empty settings -> statusLine added
echo '{}' > "$tmp/empty.json"
got=$(merge "$tmp/empty.json")
[ "$(echo "$got" | jq -r '.statusLine.command')" = "bash ~/.claude/statusline/statusline.sh" ] \
  || { echo "FAIL: statusLine not added to empty settings"; exit 1; }

# Case 3: pre-existing statusLine is replaced, not left stale
echo '{"statusLine":{"type":"command","command":"/old/path.sh"}}' > "$tmp/stale.json"
got=$(merge "$tmp/stale.json")
[ "$(echo "$got" | jq -r '.statusLine.command')" = "bash ~/.claude/statusline/statusline.sh" ] \
  || { echo "FAIL: stale statusLine not replaced"; exit 1; }

echo "ALL PASS"
