# my-server

<!-- An example machine note for a server. Rename it, fill it in, and link it from AGENTS.md. -->

A small Ubuntu server for side projects and long-running AI agent sessions.

## Access

| What | How |
|---|---|
| SSH | `ssh my-server`, over Tailscale only |
| Web UIs | Tailscale Serve, `https://my-server.<tailnet>.ts.net:<port>/` |
| Break-glass | The provider's web console, if Tailscale is down |

## Details

| | |
|---|---|
| Provider | (VPS provider, or home) |
| OS | Ubuntu 24.04 LTS |
| Specs | 4 vCPU, 8 GB RAM, 80 GB disk |
| User | `me`, passwordless sudo |
| This repo | Cloned at `~/Projects/config`, installed with `install.sh` |

## Services

| Service | Port | Notes |
|---|---|---|
| (example) app | 3000 | Docker Compose in `/srv/app`. Served on Tailscale Serve port 3000 |

## Security

- Public ports: none. The cloud firewall blocks everything but Tailscale.
- SSH: keys only, password login off.
- Updates: `unattended-upgrades` for security patches.

_Last updated: YYYY-MM-DD_
