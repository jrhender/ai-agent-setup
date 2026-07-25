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

cat <<EOF

Done. To apply this kit to every \`sbx run claude\`, add to ~/.zshrc:

  sbx() {
    if [[ "\$1" == "run" && "\$2" == "claude" ]]; then
      command sbx "\$@" --kit $kit_dir
    else
      command sbx "\$@"
    fi
  }
EOF
