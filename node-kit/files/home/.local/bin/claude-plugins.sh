#!/usr/bin/env bash
# node-kit: install the Claude Code plugins that sbx-settings.json enables.
# enabledPlugins alone only installs plugins hosted inside the marketplace repo.
# Fail-soft: never exits non-zero, always leaves a log behind.

set -uo pipefail

STATE_DIR="$HOME/.node-kit"
LOG="$STATE_DIR/plugins.log"
SETTINGS="$HOME/.claude/sbx-settings.json"

mkdir -p "$STATE_DIR"
exec >>"$LOG" 2>&1
echo "=== node-kit plugins $(date -Is)"

# setup.startup runs without a login shell, so claude is not on PATH yet.
export PATH="$HOME/.local/bin:$PATH"

plugins="$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' "$SETTINGS" 2>/dev/null)"
if [ -z "$plugins" ]; then
  echo "node-kit: no enabled plugins"
  exit 0
fi

if grep -q '@claude-plugins-official$' <<<"$plugins"; then
  claude plugin marketplace add anthropics/claude-plugins-official
fi

while read -r plugin; do
  claude plugin install "$plugin"
done <<<"$plugins"

echo "=== node-kit plugins done $(date -Is)"
