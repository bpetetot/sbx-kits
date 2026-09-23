#!/usr/bin/env bash
# node-kit: print the host commands for this sandbox, filled from its environment.

set -uo pipefail

name="${SANDBOX_NAME:-$(hostname)}"
dir="${WORKSPACE_DIR:-}"
branch="$(git -C "$dir" branch --show-current 2>/dev/null)"

cat <<OUT
# Open the project in Zed
zed -n "ssh://$name.sbx$dir"

# Open a shell in the sandbox
ssh $name.sbx

# Recover the work, from the project directory on the host
cd "$dir"
git fetch sandbox-$name
git switch ${branch:-<branch>}
OUT

listeners="$(lsof -nP -iTCP -sTCP:LISTEN -Fn 2>/dev/null | sed -n 's/^n\(.*\):\([0-9]*\)$/\1 \2/p' | grep -v ' 9418$')"
loopback='^(127\.[0-9.]*|\[::1\]|localhost) '
reachable="$(grep -Ev "$loopback" <<<"$listeners" | cut -d' ' -f2 | sort -un)"
local_only="$(grep -E "$loopback" <<<"$listeners" | cut -d' ' -f2 | sort -un | grep -vxF "${reachable:-none}")"

echo
[ -n "$listeners" ] || echo "# No port listening in the sandbox"
for port in $reachable; do
  echo "# Publish port $port, then open http://localhost:$port"
  echo "sbx ports $name --publish $port:$port"
  echo "# If host port $port is taken, let sbx pick one (sbx ports $name lists it)"
  echo "sbx ports $name --publish $port"
  echo "# Unpublish"
  echo "sbx ports $name --unpublish $port:$port"
done
for port in $local_only; do
  echo "# Port $port listens on loopback only, unreachable from the host: restart the server with --host 0.0.0.0"
done

cat <<OUT

# Stop the sandbox (the sandbox-$name remote disappears until it restarts)
sbx stop $name

# Remove the sandbox. Fetch first: commits never fetched are lost.
sbx rm $name
OUT
