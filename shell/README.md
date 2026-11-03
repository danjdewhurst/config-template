# Shell config

| File | Linked to | Used by |
|---|---|---|
| `bashrc` | `~/.bashrc` | Claude Code's Bash tool on every machine, and SSH logins on Linux |
| `tmux.conf` | `~/.tmux.conf` | tmux, mainly on servers |
| `zsh/zshrc`, `zsh/zshenv`, `zsh/zprofile`, `zsh/zpreztorc` | `~/.zshrc` and so on | Your interactive shell on macOS |

## zsh

The interactive shell on macOS is zsh with [prezto](https://github.com/sorin-ionescu/prezto), which `install.sh` clones to `~/.zprezto`. The four files in `zsh/` are prezto's runcoms with a few changes. They live here so the prezto clone stays a clean copy of upstream. `~/.zlogin` and `~/.zlogout` link into `~/.zprezto/runcoms`, since they're unchanged.

Completion directories are added to `fpath` before prezto loads, so its single `compinit` picks them all up. Tool installers like to append PATH lines to `~/.zshrc`, which is this repo's file. Move them into the `path=(...)` list instead, using `$HOME` rather than your home path.

The last line sources `~/.zshrc.local`, which isn't committed. `install.sh` writes the `claude` alias there.

## Why there's a bashrc

Claude Code runs its Bash tool in bash, not in zsh. It's what the commands Claude writes assume, and it keeps the agent's environment separate from your interactive one.

Sourcing `~/.zshrc` from `~/.bashrc` doesn't work: bash can't parse zsh syntax, prezto refuses to load, and any `echo` lands at the top of every command's output. So `bashrc` is its own file, and deliberately minimal: Homebrew, mise, PATH. No aliases or completions. The one extra is a git-aware prompt, which only loads in interactive shells, such as an SSH login. Claude's commands run non-interactively and skip it.

It's not optional. Homebrew on Apple Silicon lives at `/opt/homebrew/bin`, which isn't on the default PATH. Without `brew shellenv`, Claude gets a shell with no `node` or `rg`.

The last line sources `~/.bashrc.local` if it exists, for anything machine-specific. On a server, that's a good place to attach to tmux on SSH login.

## Why the bash path is written per machine

Claude Code reads the Bash tool's shell from `env.CLAUDE_CODE_SHELL` in `~/.claude/settings.json`. bash is at a different path on each machine:

| Machine | bash |
|---|---|
| macOS, Apple Silicon | `/opt/homebrew/bin/bash` |
| macOS, Intel | `/usr/local/bin/bash` |
| Linux | `/usr/bin/bash` |
| macOS, preinstalled | `/bin/bash`, version 3.2. Avoid |

So `install.sh` finds the newest bash 4+ and merges its path into `settings.json` with `jq`, leaving every other key alone.

As a fallback, it also writes an alias into the login shell's rc file, between `# >>> ai-config >>>` markers:

```bash
alias claude="SHELL='/opt/homebrew/bin/bash' claude"
```

Add flags to it with `CLAUDE_FLAGS` in `install.conf`. It rewrites the block in place on re-runs, and leaves the file alone if the markers are damaged. When `~/.zshrc` is linked from this repo, the block goes in `~/.zshrc.local` instead.

The alias only affects interactive shells. `claude` started from a script or cron relies on `settings.json`.
