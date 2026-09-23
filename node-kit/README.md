# node-kit

Claude Code in a sandbox, on a private clone of your Node project (npm or pnpm), with Node and the dependencies already installed.

## Start

From your project directory (see [requirements](../README.md#requirements)):

```sh
sbx-new
```

The sandbox is named `node-kit-<directory>`. To get back into it: `sbx run --name node-kit-<directory>`.

In the background, the kit installs:

- the Node version your project pins (`mise.toml`, `.tool-versions`, `.nvmrc`, `.node-version`), or Node 26;
- your dependencies, from `pnpm-lock.yaml` or `package-lock.json` (`yarn.lock` is not supported);
- the Claude Code plugins enabled in your settings.

Your `~/.claude` configuration (`CLAUDE.md`, `settings.json`, `skills/`, `*.sh`) is copied in.

> [!IMPORTANT]
> The sandbox works on a clone, not on your files. It only gets **committed** history: copy untracked files like `.env` yourself:
>
> ```sh
> sbx cp ./.env node-kit-<directory>:$PWD/.env
> ```

## Work with the sandbox

Type `/sbx` in Claude Code. It prints the bootstrap status and the host commands for this sandbox: open Zed, open a shell, publish ports, fetch the work, stop or remove the sandbox.

The agent creates a branch `sbx/<task>`, commits, and never pushes.

## Get your work back

From your project directory, with the sandbox running:

```sh
git fetch sandbox-node-kit-<directory>
git switch sbx/<task>
```

> [!WARNING]
> Fetch before `sbx rm`: unfetched commits are lost with the sandbox.

## Options

Pass options when the sandbox is created. To change them later, fetch your work, `sbx rm <name>`, then `sbx-new` again.

| Need                                    | Command                                            |
| --------------------------------------- | -------------------------------------------------- |
| Another default Node version            | `sbx-new node-kit --kit-arg node-kit.node=20`      |
| Reach a blocked host (private registry) | `sbx policy allow network --sandbox <name> <host>` |

## Troubleshooting

| Problem                                                 | Fix                                                                |
| ------------------------------------------------------- | ------------------------------------------------------------------ |
| `node` or a dependency is missing                       | Run `/sbx` to see the bootstrap status.                             |
| `--clone requires a Git repository` or `worktree` error | Run from the main Git repository.                                  |
| A dev server is not reachable from the host             | Start it with `--host 0.0.0.0`, then publish the port (`/sbx`).    |
| `git fetch sandbox-<name>` fails                        | The sandbox is stopped. Start it (`ssh <name>.sbx`), then fetch.   |
| A request fails with 403 or hangs                       | The host is blocked, see [Options](#options).                      |
| `401 Not logged in`                                     | Check your Anthropic credentials on the host: `sbx secret ls`.     |
| A kit or settings change has no effect                  | Kits apply at creation: fetch, `sbx rm <name>`, `sbx-new`.         |
| `--kit can only be used when creating a new sandbox`    | The sandbox exists. Rejoin it with `sbx run --name <name>`, or create another with `--name`. |

## Develop the kit

`sbx-new` uses your local copy of the kit. After a change:

```sh
sbx kit validate ./node-kit
sbx rm <name> && sbx-new
```
