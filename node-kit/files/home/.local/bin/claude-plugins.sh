#!/usr/bin/env bash
# node-kit: install the Claude Code plugins that sbx-settings.json enables.
# enabledPlugins alone only installs plugins hosted inside the marketplace repo.
# Fail-soft: never exits non-zero, always leaves a log behind.

set -uo pipefail

STATE_DIR="$HOME/.node-kit"
LOG="$STATE_DIR/plugins.log"
STATUS="$STATE_DIR/plugins.status"
SETTINGS="$HOME/.claude/sbx-settings.json"

mkdir -p "$STATE_DIR"
exec >>"$LOG" 2>&1
echo "=== node-kit plugins $(date -Is)"

report() {
  printf 'status: %s\nstep: %s\nlog: %s\n' "$1" "$2" "$LOG" >"$STATUS"
}

report running "installing plugins"

# setup.startup runs without a login shell, so claude is not on PATH yet.
export PATH="$HOME/.local/bin:$PATH"

plugins="$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' "$SETTINGS" 2>/dev/null)"
if [ -z "$plugins" ]; then
  echo "node-kit: no enabled plugins"
  report ok "no enabled plugins"
  exit 0
fi

if grep -q '@claude-plugins-official$' <<<"$plugins"; then
  claude plugin marketplace add anthropics/claude-plugins-official
fi

failed=()
while read -r plugin; do
  claude plugin install "$plugin" || failed+=("$plugin")
done <<<"$plugins"

if [ ${#failed[@]} -gt 0 ]; then
  report failed "claude plugin install ${failed[*]}"
else
  report ok "$(wc -l <<<"$plugins" | tr -d ' ') plugins installed"
fi

echo "=== node-kit plugins done $(date -Is)"
