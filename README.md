# sbx-kits

Kits for [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`).

| Kit | Kind | What it does |
|---|---|---|
| [`node-kit`](./node-kit/) | `sandbox` (extends `claude`) | Claude Code on a private clone of any Node project, npm or pnpm, with the toolchain and dependencies installed. |

Each kit lives in its own directory. Reference it on `main`:

```
git+https://github.com/bpetetot/sbx-kits#ref=main&dir=node-kit
```
