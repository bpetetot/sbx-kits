#!/usr/bin/env bash
# node-kit: install the toolchain, then the project dependencies.
# Fail-soft: never exits non-zero, always leaves a status file behind.

set -uo pipefail

STATE_DIR="$HOME/.node-kit"
LOG="$STATE_DIR/bootstrap.log"
STATUS="$STATE_DIR/status"
DEFAULT_NODE="${{ kit.args.node }}"

mkdir -p "$STATE_DIR"
exec >>"$LOG" 2>&1
echo "=== node-kit bootstrap $(date -Is)"

export PATH="$HOME/.local/share/mise/shims:$PATH"

report() {
  printf 'status: %s\nstep: %s\nlog: %s\n' "$1" "$2" "$LOG" >"$STATUS"
}

fail() {
  echo "node-kit: FAILED at $1"
  report failed "$1"
  exit 0
}

report running "starting"

workspace="${WORKSPACE_DIR:-}"
[ -n "$workspace" ] || fail "WORKSPACE_DIR is not set"
cd "$workspace" || fail "workspace $workspace not found"

# --- Toolchain: mise reads the project config, or falls back to the kit default
mise trust --quiet "$workspace" 2>/dev/null
pinned=false
for f in mise.toml .mise.toml .tool-versions .config/mise.toml .nvmrc .node-version; do
  [ -f "$f" ] && pinned=true && break
done
if [ "$pinned" = true ]; then
  mise install || fail "mise install"
else
  echo "node-kit: no version file, falling back to node@$DEFAULT_NODE"
  mise use --global "node@$DEFAULT_NODE" || fail "mise use node@$DEFAULT_NODE"
fi
mise reshim
command -v node >/dev/null || fail "node missing after mise install"

# --- Package manager and install command, driven by the lockfile
if [ ! -f package.json ]; then
  echo "node-kit: no package.json, nothing to install"
  report ok "no package.json"
  exit 0
fi

if [ -f pnpm-lock.yaml ]; then
  install_cmd=(pnpm install --frozen-lockfile)
  lockfile=pnpm-lock.yaml
elif [ -f package-lock.json ]; then
  install_cmd=(npm ci)
  lockfile=package-lock.json
elif [ -f yarn.lock ]; then
  echo "node-kit: yarn is not supported by this kit"
  report failed "yarn.lock is not supported"
  exit 0
else
  install_cmd=(npm install)
  lockfile=package.json
fi

if [ "${install_cmd[0]}" = pnpm ] && ! command -v pnpm >/dev/null; then
  if grep -q '"packageManager"[[:space:]]*:[[:space:]]*"pnpm@' package.json; then
    corepack enable pnpm || fail "corepack enable pnpm"
  else
    mise use --global pnpm@latest || fail "mise use pnpm@latest"
  fi
  mise reshim
fi

# --- Dependencies, skipped when nothing changed since the last run
hash_file="$STATE_DIR/deps.hash"
current_hash="$(sha256sum "$lockfile" | cut -d' ' -f1)"
if [ -d node_modules ] && [ "$(cat "$hash_file" 2>/dev/null)" = "$current_hash" ]; then
  echo "node-kit: dependencies already installed for $lockfile"
  report ok "dependencies up to date"
  exit 0
fi

echo "node-kit: ${install_cmd[*]}"
"${install_cmd[@]}" || fail "${install_cmd[*]}"
echo "$current_hash" >"$hash_file"

report ok "$(node --version) / ${install_cmd[*]}"
echo "=== node-kit bootstrap done $(date -Is)"
