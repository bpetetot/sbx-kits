# sbx-kits

Kits for [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`).

| Kit | Kind | What it does |
|---|---|---|
| [`node-kit`](./node-kit/) | `sandbox` (extends `claude`) | Claude Code on a private clone of any Node project, npm or pnpm, with the toolchain and dependencies installed. |

## Requirements

Once per machine:

1. Docker Sandboxes (`sbx`) 0.45.1 or later, signed in.
2. SSH access to sandboxes, used by Zed: `sbx setup ssh`.
3. [Zed](https://zed.dev) if you want an editor.

## Launch

`sbx-new` creates a sandbox from a kit of this repository. Put it on your `PATH` once:

```sh
ln -s "$PWD/sbx-new" ~/.local/bin/sbx-new
```

Then, from any project directory:

```sh
sbx-new            # node-kit by default
sbx-new <kit>
```

It creates the sandbox in clone mode from your local copy of the kit, with your Claude Code configuration (`~/.claude/CLAUDE.md`, `settings.json`, `skills/`, `*.sh`) copied into a mixin in `.personal-mixin/`. Arguments after the kit go to `sbx run`.

The sandbox is named `<kit>-<directory>`. To create another one for the same project, name it:

```sh
sbx-new node-kit --name node-kit-<directory>-2
```

To get back into an existing sandbox, use `sbx` directly (`sbx ls` lists them):

```sh
sbx run --name <name>
```
