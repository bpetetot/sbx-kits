#!/usr/bin/env bash
# node-kit: print the host commands for this sandbox as Markdown, filled from its environment.

set -uo pipefail

name="${SANDBOX_NAME:-$(hostname)}"
dir="${WORKSPACE_DIR:-}"
branch="$(git -C "$dir" branch --show-current 2>/dev/null)"

listeners="$(lsof -nP -iTCP -sTCP:LISTEN -Fn 2>/dev/null | sed -n 's/^n\(.*\):\([0-9]*\)$/\1 \2/p' | grep -v ' 9418$')"
loopback='^(127\.[0-9.]*|\[::1\]|localhost) '
reachable="$(grep -Ev "$loopback" <<<"$listeners" | cut -d' ' -f2 | sort -un)"
local_only="$(grep -E "$loopback" <<<"$listeners" | cut -d' ' -f2 | sort -un | grep -vxF "${reachable:-none}")"

summary() {
  [ -f "$1" ] || { echo "not started yet"; return; }
  echo "$(sed -n 's/^status: //p' "$1"): $(sed -n 's/^step: //p' "$1")"
}

failure_log() {
  grep -qx 'status: failed' "$2" 2>/dev/null || return
  local log
  log="$(sed -n 's/^log: //p' "$2")"
  echo
  echo "$1 failed, last lines of \`$log\`:"
  echo
  echo '```text'
  tail -n 10 "$log" 2>/dev/null
  echo '```'
}

status_file="$HOME/.node-kit/status"
plugins_file="$HOME/.node-kit/plugins.status"

echo "**Bootstrap** $(summary "$status_file") · **Plugins** $(summary "$plugins_file")"
failure_log Bootstrap "$status_file"
failure_log Plugins "$plugins_file"
echo

cat <<OUT
**Sandbox** \`$name\` on branch \`${branch:-?}\`, to run **on the host**.

### Open in Zed

\`\`\`sh
zed -n "ssh://$name.sbx$dir"
\`\`\`

### Open a shell

\`\`\`sh
ssh $name.sbx
\`\`\`

### Recover the work

\`\`\`sh
git fetch sandbox-$name
git switch ${branch:-<branch>}
git push -u origin ${branch:-<branch>}
\`\`\`

### Ports

OUT

if [ -z "$listeners" ]; then
  echo "No port listening in the sandbox."
else
  echo "| Port | Host access |"
  echo "|---|---|"
  for port in $reachable; do
    echo "| \`$port\` | http://localhost:$port once published |"
  done
  for port in $local_only; do
    echo "| \`$port\` | unreachable: listens on localhost, restart the server with \`--host 0.0.0.0\` |"
  done
fi

if [ -n "$reachable" ]; then
  echo
  echo '```sh'
  for port in $reachable; do
    echo "sbx ports $name --publish $port:$port"
  done
  echo '```'
  echo
  echo "If a host port is taken, publish with \`--publish <port>\` and read the assigned one with \`sbx ports $name\`. Undo with \`--unpublish <host>:<port>\`."
fi
