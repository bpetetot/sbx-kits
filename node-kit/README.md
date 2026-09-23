# node-kit

A Docker Sandboxes (`sbx`) kit that runs Claude Code on a **private clone** of any Node project, npm or pnpm, with the right Node version and the dependencies already installed, and Zed connected over SSH.

```
git+https://github.com/bpetetot/sbx-kits#ref=main&dir=node-kit
```

The kit stops at dependency installation: no `docker compose up`, no databases, no browsers.

## Requirements

Once per machine:

1. Docker Sandboxes (`sbx`) 0.45.1 or later, signed in.
2. SSH access to sandboxes, used by Zed: `sbx setup ssh`.
3. Anthropic credentials: `sbx secret set anthropic` (or whatever auth already works for `sbx run claude`). The first launch needs nothing special.
4. Allow kits hosted on GitHub. By default `sbx` only accepts kits from `docker.io/`:

   ```sh
   sbx settings set kit.allowedSources '["docker.io/","github.com/bpetetot/"]'
   ```

5. `jq` on the host, for the shell recipe below. [Zed](https://zed.dev) if you want an editor.

## Launch

Pick **one** recipe per project and stick to it: `sbx env run` refuses to take over a sandbox the shell recipe created.

Both recipes name the sandbox `node-kit-<directory>` (lowercased, `_` becomes `-`), always in clone mode.

### Recipe 1: `~/.sbxenv.yaml`

Copy this file to `~/.sbxenv.yaml`, then run `sbx env run` from any project directory.

```yaml
schemaVersion: "1"
agent: node-kit
kits:
  - git+https://github.com/bpetetot/sbx-kits#ref=main&dir=node-kit
  # Optional: your personal Claude Code configuration, see "Personal configuration"
  # - git+ssh://git@github.com/<you>/dotfiles#dir=sbx-kit
workspace:
  path: ${{ env.projectDir }}
  clone: true
```

`agent:` holds the kit **name**, the reference goes in `kits:`. A reference in `agent:` makes `sbx` fail to derive a sandbox name.

### Recipe 2: shell function

Put this in your `~/.zshrc` or `~/.bashrc`, then run `sbxn` from any project directory. An alias is not enough: `--kit` is rejected once the sandbox exists, so the function reattaches instead.

```sh
SBXN_KIT='git+https://github.com/bpetetot/sbx-kits#ref=main&dir=node-kit'
SBXN_MIXIN='git+ssh://git@github.com/<you>/dotfiles#dir=sbx-kit'
sbxn() {
  local name
  name=$(sbx ls --json | jq -r --arg ws "$(pwd -P)" '.sandboxes[] | select(.workspaces[0] == $ws) | .name' | head -n1)
  if [ -n "$name" ]; then
    sbx run --name "$name" "$@"
  else
    sbx run --clone "$SBXN_KIT" --kit "$SBXN_MIXIN" "$@" .
  fi
}
```

Without a personal mixin, drop `SBXN_MIXIN` and `--kit "$SBXN_MIXIN"`.

## Why clone mode is mandatory

Clone mode is a **safety requirement, not a convenience**. With a bind mount, the sandbox and the host share `node_modules`, and an `npm ci` in the sandbox overwrites the host's native binaries with Linux ones. Both recipes force `--clone`; never fall back to a bind mount when `--clone` is refused.

`--clone` refuses to run outside a Git repository and from a secondary worktree. Run it from the main repository.

The clone holds **committed history only**, on the branch checked out on the host. Uncommitted changes and untracked files such as `.env` stay on the host.

## What happens in the sandbox

1. **Toolchain.** [mise](https://mise.jdx.dev) reads `mise.toml`, `.tool-versions`, `.nvmrc` or `.node-version`. When the project pins nothing, the kit installs Node `22` (see [Configuration](#configuration)). Tools a `mise.toml` declares, like pnpm, come with it.
2. **Dependencies.** The lockfile picks the command: `pnpm-lock.yaml` runs `pnpm install --frozen-lockfile`, `package-lock.json` runs `npm ci`, no lockfile runs `npm install`. `yarn.lock` is not supported.
3. **Plugins.** The Claude Code plugins enabled in the settings are installed.

All of this runs in the background at every start, so the agent is usable right away. It is idempotent (dependencies are skipped when the lockfile did not change) and never fails the sandbox: it writes `~/.node-kit/status`, which the agent is told to read when something is missing, and logs to `~/.node-kit/bootstrap.log` and `~/.node-kit/plugins.log`.

The kit also gives the agent these rules, in `~/.claude/CLAUDE.md`:

- create a branch `sbx/<task-slug>` before the first commit;
- never push, even though `origin` points at the real GitHub repository;
- start dev servers with `--host 0.0.0.0`;
- use `/sbx` whenever you have to act on the host.

## `/sbx`: from the sandbox to the host

`/sbx` is a skill the kit ships. Type it in Claude Code, or let the agent call it, and it prints the exact host commands for this sandbox, filled from the sandbox itself:

- open Zed: `zed -n "ssh://<name>.sbx<path>"`;
- open a shell: `ssh <name>.sbx`;
- recover the work: `git fetch sandbox-<name>` then `git switch <branch>`;
- publish every listening port: `sbx ports <name> --publish <port>:<port>`, and flag servers bound to localhost, which the host cannot reach even when published;
- `sbx stop <name>` and `sbx rm <name>`.

This is the way to connect Zed: the sandbox path is the **absolute host path** of the project, not `/home/agent/workspace`, which stays empty. SSH restarts a stopped sandbox by itself.

## Getting the work back

From the project directory on the host, with the sandbox running:

```sh
git fetch sandbox-node-kit-<directory>
git switch sbx/<task-slug>
```

`git fetch` also mirrors every branch to `refs/sandboxes/<name>/*`, which **survives `sbx rm`**. A commit never fetched is lost with the sandbox.

Untracked files go in with `sbx cp`, from the project directory:

```sh
sbx cp ./.env node-kit-<directory>:$PWD/.env
```

To automate it, a project `sbxenv.yaml` can run it after creation with `lifecycle.postCreate`.

Pushing from the sandbox is not part of the kit. If you really need it: `sbx policy allow network 'github.com:22'`, and an identity loaded in the host SSH agent (`ssh-add`) before creating the sandbox.

## Personal configuration

`node-kit` is public and neutral. Your own Claude Code configuration goes in a **private `kind: mixin` kit**, stacked on top of `node-kit` (`kits:` in `~/.sbxenv.yaml`, `--kit` on the command line). Kit references are resolved on the host, so a private repository needs no credentials and no network access inside the sandbox.

```
dotfiles/sbx-kit/
├── spec.yaml                          # schemaVersion "2", kind: mixin
└── files/home/.claude/
    ├── sbx-settings.json              # your Claude Code settings
    ├── statusline-command.sh
    ├── user-claude.md                 # your instructions
    └── skills/                        # your personal skills
```

```yaml
schemaVersion: "2"
kind: mixin
name: my-claude
version: "0.1.0"
description: Personal Claude Code configuration for sbx sandboxes
```

How the layers stack:

- Files under `files/home` are written in one phase where **the last kit wins**, so the mixin overrides `node-kit`. That is how your `sbx-settings.json` replaces the kit's empty one.
- `setup.files` run **after** that phase, so `node-kit` always wins there. The kit writes `~/.claude/CLAUDE.md` this way, and that file imports `~/.claude/user-claude.md`. Put your instructions in `user-claude.md`: the kit's workflow rules (never push) cannot be dropped by a mixin.
- `~/.claude/settings.json` is reserved by `sbx`: a kit that writes it is **silently overwritten**. `node-kit` starts Claude Code with `--settings ~/.claude/sbx-settings.json` instead, so put your settings there.
- `enabledPlugins` is honoured: the kit installs those plugins at start, including the ones hosted outside their marketplace.

## Configuration

**Default Node version.** One kit argument, `node`, used only when the project pins no version:

```sh
sbx env run --kit-arg node-kit.node=20
sbx run --clone "$SBXN_KIT" --kit-arg node-kit.node=20 .
```

Like every kit setting, it applies when the sandbox is created.

**Project file.** A `sbxenv.yaml` (no leading dot) in the project directory is merged on top of `~/.sbxenv.yaml` by `sbx env run`:

- scalars override, maps merge, lists concatenate: a project can **add** kits, never remove or replace one;
- `workspace: {clone: false}` in a project file turns clone mode off. Don't;
- to replace the global file entirely (another kit version, no mixin), write a standalone `sbxenv.yaml` and run `sbx env run .`: naming a path skips `~/.sbxenv.yaml`.

**Network.** `node-kit` declares no network rule: everything it contacts is in the default policy. When a project needs more, like a private npm registry:

- durable: a local mixin with `permissions.network.allow`, listed in the project `sbxenv.yaml`;
- one-off: `sbx policy allow network --sandbox <name> <host>`, lost on `sbx rm`.

**Resources.** `sandboxOptions` in `~/.sbxenv.yaml` sets `memory`, `cpus` or `pullPolicy: missing`. None is needed.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `node` or a dependency missing | The bootstrap runs in the background or failed. `cat ~/.node-kit/status` in the sandbox, then the log it points to. |
| `cannot be installed: its source is not in your allowlist` | `kit.allowedSources` is not set, see [Requirements](#requirements). |
| `--clone requires a Git repository` | Run from a Git repository. |
| `--clone is not supported when run from a Git worktree` | Run from the main repository, not a worktree. |
| A request fails with 403, or hangs, inside the sandbox | The host is not in the network policy. `sbx policy check network --sandbox <name> <host>` and `sbx policy log <name>`, then see [Configuration](#configuration). |
| `401 Not logged in`, `/login` fails with `OAuth error: 401` | Anthropic credentials are missing on the host. Check `sbx secret ls`. |
| A dev server works in the sandbox, not from the host | It listens on localhost. Restart it with `--host 0.0.0.0`, then publish the port (`/sbx`). |
| `git fetch sandbox-<name>` fails | The sandbox is stopped: `sbx stop` removes the remote. Start it again (`ssh <name>.sbx` is enough), then fetch. |
| Work lost after `sbx rm` | Only fetched commits survive. Fetch before removing. |
| A kit change has no effect | Kits are applied at creation. Fetch, `sbx rm <name>`, create again. |
| `--kit can only be used when creating a new sandbox` | The sandbox exists. Use `sbxn`, or `sbx run --name <name>`. |
| `sandbox name "..." is already used by workspace` | Two projects share a directory name. Pass `--name`. |

## Developing the kit

Point the recipes at your working copy (an absolute path, `~` is not expanded) and use a dedicated sandbox name:

```sh
sbx kit validate ./node-kit
sbx run --name nk-dev --clone /abs/path/to/sbx-kits/node-kit .
```

Kits are frozen at creation: after each change, `sbx rm nk-dev` and create again.

**Updating.** The recipes track `main`, and a kit is resolved when a sandbox is created: an existing sandbox keeps the version it was created with until you remove and create it again.

## Numbers

Measured on an Apple M4, sbx 0.45.1: creation takes 9 to 10 s, then the background bootstrap takes 7 s on an npm project of 500 packages with the default Node, and 9 s on a pnpm monorepo pinning Node 26. A restart replays it in about 1 s.
