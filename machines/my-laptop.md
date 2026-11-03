# my-laptop

<!-- An example machine note. Rename it, fill it in, and link it from AGENTS.md. -->

My own laptop. The main machine: this repo, SSH to everything, and day-to-day development.

## Hardware and OS

| | |
|---|---|
| Model | MacBook Pro |
| Chip | Apple M-series |
| RAM | 16 GB |
| OS | macOS |
| Hostname | `my-laptop` |

## Network

- **Tailscale:** `my-laptop.<tailnet>.ts.net`
- **DNS:** Tailscale MagicDNS while connected.

## Config from this repo

`install.sh` links these on macOS. See the root `README.md`.

| File | From |
|---|---|
| `~/.zshrc`, `~/.zshenv`, `~/.zprofile`, `~/.zpreztorc` | `shell/zsh/` |
| `~/.bashrc` | `shell/bashrc` |
| `~/.gitconfig`, `~/.config/git/ignore` | `git/` |
| `~/.config/ghostty/` | `ghostty/` |
| `~/.ssh/config` | `ssh/config` |
| `~/.claude`, `~/.codex`, `~/.agents` | `ai/` |

## Shell and tools

- **Shell:** zsh with [prezto](https://github.com/sorin-ionescu/prezto). Claude Code runs commands in Homebrew bash.
- **Terminal:** Ghostty, FiraCode Nerd Font, Catppuccin Frappé.
- **Packages:** Homebrew (`macos/Brewfile`). Language runtimes come from mise.
- **AI tools:** Claude Code, Codex.

_Last updated: YYYY-MM-DD_
