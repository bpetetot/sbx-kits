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
cd "$dir"
git fetch sandbox-$name
git switch ${branch:-<branch>}
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

cat <<OUT

### Stop or remove

\`\`\`sh
sbx stop $name
\`\`\`

> **Fetch first.** \`sbx rm\` destroys the clone, and commits never fetched are lost.

\`\`\`sh
sbx rm $name
\`\`\`
OUT
