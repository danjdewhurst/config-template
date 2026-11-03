# My infrastructure

<!--
  The map that AI agents read before they touch your machines. Fill in the
  overview and the table, then delete the examples you don't need. Keep it
  short: one screen. The details go in machines/ and network/.
-->

This repo describes my machines, network, SSH setup and AI agent config. Read it before working on any of them.

## Overview

```
Tailscale tailnet (<tailnet>.ts.net)
├── my-laptop        My laptop, the main machine
├── my-phone
└── my-server        VPS or home server, Ubuntu
    └── my-vm        A VM on my-server, reached through a Tailscale subnet route
```

Public ports: none. SSH works only over Tailscale.

## How to reach things

| Target | Command |
|---|---|
| my-server | `ssh my-server` |
| my-vm | `ssh my-vm` |

These commands work from my laptop. Aliases are in `ssh/config`.

## Where the details are

| File | Contents |
|---|---|
| `machines/my-laptop.md` | The laptop: hardware, shell, tools, what this repo links there |
| `machines/my-server.md` | The server: access, services, ports, security |
| `network/tailscale.md` | Tailnet devices, DNS and subnet routes |
| `install.sh`, `install.conf` | Links this repo's config into `$HOME`. See `README.md` |
| `ai/` | Global agent instructions (`ai/AGENTS.src.md`, then run `ai/build.sh`), per-machine notes for agents (`ai/hosts/`) and skills (`ai/skills/`) |
| `scripts/refresh.sh` | Read-only snapshot of Tailscale, each server and DNS |

## Rules for agents

- **These notes can be out of date.** Before you act on a fact that matters (an IP, a port, what's running), check the live system. `scripts/refresh.sh` prints a read-only snapshot. Compare it with the notes.
- **Pull before reading, push after editing.** This repo is cloned on more than one machine. After a change to `ai/`, run `git pull && ai/build.sh` on each other clone. If the change adds or removes a skill, run `git pull && ./install.sh` instead.
- **Ask before changing anything on a server.** Read-only checks are fine. Restarts, firewall changes and package installs need my approval.
- **Never write secrets into this repo.** No passwords, private keys, tokens or `.env` files, even if the repo is private. `.gitignore` blocks the common ones, and CI runs gitleaks on every push.
- **Keep the notes current.** When you learn something new or find a note is wrong, update the file and commit it.
- **Linked files are live.** Editing `shell/`, `git/`, `ghostty/`, `ssh/` or `ai/` changes the running config on this machine at once.
- **Follow the style of the existing files:** short markdown, tables for lists of facts, and a `_Last updated_` line at the bottom.
