#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Your choices for this kit: install.conf in the repo, then ~/.ai-config.local
# on this machine (never committed), which wins. See install.conf.
NEXTDNS_ID=""
CLAUDE_FLAGS=""
CLIPBOARD_LABEL="local.clipboard-image"
if [ -f "$REPO/install.conf" ]; then
  # shellcheck source=install.conf
  . "$REPO/install.conf"
fi

# Which agents get the config. agents.conf ships the defaults; a machine adds
# its own or redefines the list in ~/.ai-config.local, sourced second so it
# wins and never committed here.
. "$REPO/ai/agents.conf"
if [ -f "$HOME/.ai-config.local" ]; then
  . "$HOME/.ai-config.local"
fi

# repo file -> where it goes. Every machine gets these.
LINKS=(
  "shell/bashrc:$HOME/.bashrc"
  "shell/tmux.conf:$HOME/.tmux.conf"
  "git/gitconfig:$HOME/.gitconfig"
  "git/ignore:$HOME/.config/git/ignore"
)

# macOS is treated as the desktop: it gets zsh, the terminal config and the SSH
# config. Linux machines are treated as headless boxes that use bash and keep
# their own SSH config.
case "$OSTYPE" in
  darwin*)
    LINKS+=(
      "shell/zsh/zshrc:$HOME/.zshrc"
      "shell/zsh/zshenv:$HOME/.zshenv"
      "shell/zsh/zprofile:$HOME/.zprofile"
      "shell/zsh/zpreztorc:$HOME/.zpreztorc"
      "ghostty/config:$HOME/.config/ghostty/config"
      "ghostty/themes/catppuccin-frappe:$HOME/.config/ghostty/themes/catppuccin-frappe"
      "ssh/config:$HOME/.ssh/config"
    )
    ;;
  # Headless boxes have no clipboard. The shim reads the Mac's over SSH, so
  # Ctrl+V in Claude Code pastes images. See clipboard/.
  linux*)
    LINKS+=("clipboard/xclip:$HOME/.local/bin/xclip")
    ;;
esac

for entry in ${AGENT_DIRS[@]+"${AGENT_DIRS[@]}"}; do
  case "$entry" in
    *:*) ;;
    *)
      echo "WARNING: AGENT_DIRS entry '$entry' is not <dir>:<filename> — skipped." >&2
      continue
      ;;
  esac
  dir="${entry%:*}"
  name="${entry##*:}"
  agent="${dir##*/}"
  agent="${agent#.}"

  if [ -e "$dir" ] && [ ! -d "$dir" ]; then
    echo "ERROR: $dir exists but is not a directory. Move it aside and re-run." >&2
    exit 1
  fi
  mkdir -p "$dir"

  LINKS+=("ai/build/$agent/$name:$dir/$name")
done

# The instruction files are rendered per agent from AGENTS.src.md, so the links
# below point into build/. Rendering runs before linking so a tag error stops
# the script before it has touched anything in $HOME.
"$REPO/ai/build.sh"

# Move whatever is on this path out of the way, never clobbering an older
# backup. Symlinks included: mv moves the link itself, so the user keeps it.
preserve() {
  target="$1"

  backup="$target.bak"
  if [ -e "$backup" ] || [ -L "$backup" ]; then
    backup="$target.bak.$(date +%Y%m%d%H%M%S)"
  fi
  mv "$target" "$backup"
  echo "Backed up $(basename "$target") to $backup"
}

for entry in "${LINKS[@]}"; do
  src="$REPO/${entry%%:*}"
  target="${entry#*:}"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
    echo "Already linked: $target"
    continue
  fi

  # A machine can keep a real ~/.gitconfig that includes the repo copy with
  # [include] path = <repo>/git/gitconfig. A CI runner needs this, because
  # actions/checkout copies ~/.gitconfig with symlinks kept, and a link sends
  # its safe.directory writes into this repo. Leave a file like that alone.
  if [ "$target" = "$HOME/.gitconfig" ] && [ -f "$target" ] && [ ! -L "$target" ] &&
    git config --file "$target" --get-all include.path | grep -qxF "$src"; then
    echo "Already included: $target"
    continue
  fi

  mkdir -p "$(dirname "$target")"
  # Same content as the repo copy (following links): nothing to keep, so no
  # backup. Anything else is moved aside first.
  if [ -f "$target" ] && cmp -s "$src" "$target"; then
    rm -f "$target"
  elif [ -e "$target" ] || [ -L "$target" ]; then
    preserve "$target"
  fi

  ln -sfn "$src" "$target"
  echo "Linked $target -> $src"
done

# Skills. The content lives in this repo; ~/.claude/skills is what Claude
# reads, and ~/.agents/skills is the shared directory other agents look in.
# Each skill is a direct symlink into the repo, so a pull updates it.
link_skills() {
  dest="$1"
  mkdir -p "$dest"

  for src in "$REPO"/ai/skills/*/; do
    src="${src%/}"
    [ -d "$src" ] || continue
    name="$(basename "$src")"

    link="$dest/$name"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$src" ]; then
      echo "Already linked: $link"
      continue
    fi

    # Skills used to route ~/.claude through ~/.agents; a link of that shape is
    # ours to replace. A real directory with identical content is redundant and
    # gets removed; anything else is backed up, so local edits to a skill are
    # never silently thrown away.
    if [ -L "$link" ] && [ "$(readlink "$link")" = "../../.agents/skills/$name" ]; then
      rm -f "$link"
    elif [ -d "$link" ] && [ ! -L "$link" ] && diff -rq "$src" "$link" >/dev/null 2>&1; then
      rm -rf "$link"
    elif [ -e "$link" ] || [ -L "$link" ]; then
      preserve "$link"
    fi
    ln -sfn "$src" "$link"
    echo "Linked $link -> $src"
  done

  # Prune the links this script made for skills the repo no longer carries. A
  # pull that drops one would otherwise leave a dangling link behind for good.
  # Only broken links shaped like the ones we make (any checkout, not just the
  # current $REPO: a link made before the repo moved is broken the same way)
  # are touched; anything else on this path belongs to the user.
  for link in "$dest"/*; do
    [ -L "$link" ] && [ ! -e "$link" ] || continue
    case "$(readlink "$link")" in
      */skills/"${link##*/}")
        rm -f "$link"
        echo "Pruned $link — no longer in the repo"
        ;;
    esac
  done
}

# Runs even when the repo has no skills/ directory, so a checkout that dropped
# every skill still prunes the links an earlier one made.
for dest in ${SKILL_DIRS[@]+"${SKILL_DIRS[@]}"}; do
  link_skills "$dest"
done

# Drop the links this script made in an agent's skills directory that is no
# longer in SKILL_DIRS, such as ~/.codex/skills. Only links into this repo's
# skills/ are touched.
for entry in ${AGENT_DIRS[@]+"${AGENT_DIRS[@]}"}; do
  dest="${entry%:*}/skills"
  case " ${SKILL_DIRS[*]-} " in *" $dest "*) continue ;; esac
  for link in "$dest"/*; do
    [ -L "$link" ] || continue
    case "$(readlink "$link")" in
      "$REPO"/ai/skills/*)
        rm -f "$link"
        echo "Removed $link — skills aren't linked into $dest"
        ;;
    esac
  done
done
# Package manager detection: brew, then the common Linux families.
SUDO=""
APT_UPDATED=""
if command -v brew >/dev/null; then
  PM=brew
elif command -v apt-get >/dev/null; then
  PM=apt
elif command -v dnf >/dev/null; then
  PM=dnf
elif command -v pacman >/dev/null; then
  PM=pacman
else
  PM=none
fi

if [ "$PM" != brew ] && [ "$PM" != none ] && [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null; then
    SUDO="sudo"
  else
    echo "Not root and sudo is unavailable — skipping package installs."
    PM=none
  fi
fi

# Package names differ per distro.
pkg_name() {
  case "$1:$PM" in
    fd:apt)       echo "fd-find" ;;
    fd:dnf)       echo "fd-find" ;;
    gh:pacman)    echo "github-cli" ;;
    ripgrep:*)    echo "ripgrep" ;;
    *)            echo "$1" ;;
  esac
}

pm_install() {
  pkg="$(pkg_name "$1")"
  case "$PM" in
    brew)   brew install "$pkg" ;;
    apt)
      # Without this a fresh machine has no package lists and every install fails.
      if [ -z "$APT_UPDATED" ]; then
        $SUDO apt-get update -qq || echo "  apt-get update failed — carrying on."
        APT_UPDATED=1
      fi
      $SUDO apt-get install -y -qq "$pkg"
      ;;
    dnf)    $SUDO dnf install -y -q "$pkg" ;;
    pacman) $SUDO pacman -S --noconfirm --needed "$pkg" ;;
    *)      return 2 ;;
  esac
}

# Debian renames fd to avoid a clash and ships the binary as `fdfind` (the
# package is fd-find on both Debian and Fedora). Claude expects `fd`, so shim it
# into ~/.local/bin and make sure the rest of this script can see it.
shim_debian_name() {
  want="$1"
  actual="$2"
  command -v "$want" >/dev/null && return 0
  command -v "$actual" >/dev/null || return 0

  actual_path="$(command -v "$actual")"
  mkdir -p "$HOME/.local/bin"
  shim="$HOME/.local/bin/$want"
  # A real file here is the user's own binary, invisible only because
  # ~/.local/bin is not on PATH yet.
  if [ -e "$shim" ] && [ ! -L "$shim" ]; then
    echo "WARNING: $shim exists and is not a symlink — left alone, no $want shim." >&2
  elif [ "$(readlink "$shim" 2>/dev/null)" != "$actual_path" ]; then
    ln -sfn "$actual_path" "$shim"
    echo "Shimmed $want -> $actual_path at $shim"
  fi
  PATH="$HOME/.local/bin:$PATH"
  export PATH
}

install_tool() {
  cmd="$1"
  pkg="$2"
  alt_cmd="${3:-}"

  if [ -n "$alt_cmd" ]; then
    shim_debian_name "$cmd" "$alt_cmd"
  fi

  if command -v "$cmd" >/dev/null; then
    echo "$pkg already installed: $(command -v "$cmd")"
    return
  fi

  if [ "$PM" = none ]; then
    echo "$pkg not installed and no supported package manager found — install it yourself."
    return
  fi

  echo "Installing $pkg..."
  if ! pm_install "$pkg"; then
    echo "  could not install $pkg — carrying on."
    return
  fi

  if [ -n "$alt_cmd" ]; then
    shim_debian_name "$cmd" "$alt_cmd"
  fi
}

# The macOS zsh config is prezto's runcoms (linked from shell/zsh above),
# so prezto itself has to be cloned. zlogin and zlogout are upstream's, unchanged.
if [ "$(uname)" = Darwin ]; then
  if [ ! -d "$HOME/.zprezto" ]; then
    echo "Cloning prezto..."
    git clone -q --recursive https://github.com/sorin-ionescu/prezto.git "$HOME/.zprezto" ||
      echo "  could not clone prezto — carrying on."
  fi
  for rc in zlogin zlogout; do
    if [ -f "$HOME/.zprezto/runcoms/$rc" ] && [ ! -e "$HOME/.$rc" ] && [ ! -L "$HOME/.$rc" ]; then
      ln -s "$HOME/.zprezto/runcoms/$rc" "$HOME/.$rc"
      echo "Linked $HOME/.$rc -> $HOME/.zprezto/runcoms/$rc"
    fi
  done

  # Your Homebrew packages: CLI tools, apps and fonts. Installs what's missing
  # and upgrades nothing.
  if [ "$PM" = brew ]; then
    brewfile="$REPO/macos/Brewfile"
    if brew bundle check --file="$brewfile" --no-upgrade >/dev/null 2>&1; then
      echo "Already current: macos/Brewfile"
    else
      echo "Installing from macos/Brewfile. This can take a while..."
      brew bundle install --file="$brewfile" --no-upgrade ||
        echo "  some Brewfile entries failed — see above. Carrying on."
    fi
  fi

  # Serves the clipboard image to the xclip shim on the Linux boxes. A copy,
  # not a link: launchd will not load a plist through a symlink. Set
  # CLIPBOARD_LABEL="" in install.conf to skip it.
  if [ -n "$CLIPBOARD_LABEL" ]; then
    label="$CLIPBOARD_LABEL"
    plist="$HOME/Library/LaunchAgents/$label.plist"
    want="$(sed -e "s|REPO|$REPO|" -e "s|LABEL|$label|" "$REPO/clipboard/clipboard-image.plist")"
    if [ "$(cat "$plist" 2>/dev/null)" = "$want" ] && launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
      echo "Already current: $plist"
    else
      mkdir -p "$(dirname "$plist")"
      launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
      printf '%s\n' "$want" >"$plist"
      launchctl bootstrap "gui/$(id -u)" "$plist" &&
        echo "Loaded $plist" ||
        echo "  could not load $plist — carrying on."
    fi
  fi
fi

install_tool git git
install_tool rg ripgrep
install_tool fd fd fdfind
install_tool jq jq
# The linked config needs these: git/gitconfig signs in to GitHub through gh
# and filters LFS files through git-lfs, and shell/tmux.conf is for tmux.
install_tool gh gh
install_tool git-lfs git-lfs
install_tool tmux tmux

# Short-lived GitHub tokens that gh refreshes itself. This only sets the
# preference; the next `gh auth login` or `gh auth refresh --expiring` gets one.
if command -v gh >/dev/null; then
  if [ "$(gh config get expiring_credentials 2>/dev/null)" = enabled ]; then
    echo "Already current: gh expiring_credentials"
  else
    gh config set expiring_credentials enabled &&
      echo "Set gh expiring_credentials=enabled" ||
      echo "  could not set gh expiring_credentials — carrying on."
  fi
fi

# Optional: NextDNS over TLS as the Linux resolver. Set NEXTDNS_ID in
# install.conf to turn it on. If Tailscale is up, its own DNS (MagicDNS) takes
# every query ahead of the global servers set here, so this is the fallback for
# when Tailscale is off. On macOS, use a NextDNS configuration profile instead.
# Anycast servers for DNS-over-TLS, where the profile goes in the TLS name.
NEXTDNS_DOT=(45.90.28.0 45.90.30.0 2a07:a8c0:: 2a07:a8c1::)

set_nextdns_linux() {
  if ! systemctl is-active -q systemd-resolved 2>/dev/null; then
    echo "systemd-resolved is not running — NextDNS fallback not set."
    return
  fi

  # DNS-over-TLS names the device in NextDNS logs. Opportunistic, because the
  # setting is global and Tailscale's 100.100.100.100 has no TLS.
  device="$(hostname -s | tr -c 'a-zA-Z0-9\n' '-')"
  tls="#${device}-${NEXTDNS_ID}.dns.nextdns.io"
  conf="/etc/systemd/resolved.conf.d/nextdns.conf"
  want="[Resolve]
DNS=$(printf "%s$tls " "${NEXTDNS_DOT[@]}" | sed 's/ $//')
DNSOverTLS=opportunistic"

  if [ "$(cat "$conf" 2>/dev/null)" = "$want" ]; then
    echo "Already current: $conf"
    return
  fi
  $SUDO mkdir -p "$(dirname "$conf")"
  printf '%s\n' "$want" | $SUDO tee "$conf" >/dev/null &&
    $SUDO systemctl restart systemd-resolved &&
    echo "Wrote $conf" ||
    echo "  could not write $conf — carrying on."
}

case "$OSTYPE" in
  linux*) [ -z "$NEXTDNS_ID" ] || set_nextdns_linux ;;
esac

# mise manages language runtimes, and installs the tools no distro packages.
if ! command -v mise >/dev/null; then
  if [ "$PM" = brew ]; then
    echo "Installing mise..."
    brew install mise || echo "  could not install mise — carrying on."
  elif command -v curl >/dev/null; then
    echo "Installing mise from mise.run..."
    curl -fsSL https://mise.run | sh || echo "  could not install mise — carrying on."
  else
    echo "mise not installed and curl is unavailable — install it yourself."
  fi
fi

MISE=""
if command -v mise >/dev/null; then
  MISE="$(command -v mise)"
elif [ -x "$HOME/.local/bin/mise" ]; then
  MISE="$HOME/.local/bin/mise"
fi

# ast-grep and yq: package manager first where it has them, mise otherwise.
install_portable_tool() {
  cmd="$1"

  if command -v "$cmd" >/dev/null; then
    echo "$cmd already installed: $(command -v "$cmd")"
    return
  fi

  # mise-installed tools aren't on this shell's PATH, so ask mise directly
  # rather than reinstalling them on every run.
  if [ -n "$MISE" ] && "$MISE" which "$cmd" >/dev/null 2>&1; then
    echo "$cmd already installed: $("$MISE" which "$cmd")"
    return
  fi

  if [ "$PM" = brew ]; then
    echo "Installing $cmd..."
    if brew install "$cmd"; then
      return
    fi
    echo "  brew could not install $cmd, trying mise..."
  fi

  if [ -z "$MISE" ]; then
    echo "$cmd not installed and mise is unavailable — install it yourself."
    return
  fi

  echo "Installing $cmd via mise..."
  "$MISE" use -g -y "$cmd@latest" || echo "  could not install $cmd — carrying on."
}

install_portable_tool ast-grep
install_portable_tool yq

# Skills that live in their own repos, listed in ai/skills.txt, go in with the
# skills CLI. It keeps one copy in ~/.agents/skills, which Codex reads directly,
# and links it into ~/.claude/skills. Missing ones are installed; updating is
# left to `bunx skills update -g`.
find_bunx() {
  if command -v bunx >/dev/null; then
    command -v bunx
  elif [ -x "$HOME/.bun/bin/bunx" ]; then
    echo "$HOME/.bun/bin/bunx"
  elif [ -x "$HOME/.bun/bin/bun" ]; then
    # bun's installer no longer creates bunx, which is only bun under another name.
    ln -s bun "$HOME/.bun/bin/bunx"
    echo "$HOME/.bun/bin/bunx"
  elif [ -n "${MISE:-}" ] && "$MISE" which bunx >/dev/null 2>&1; then
    "$MISE" which bunx
  else
    return 1
  fi
}

install_external_skills() {
  list="$REPO/ai/skills.txt"
  [ -f "$list" ] || return 0

  # bun's own installer, into ~/.bun. SHELL=/bin/sh stops it appending to
  # ~/.zshrc or ~/.bashrc, which are linked from this repo and already put
  # ~/.bun/bin on PATH.
  if ! BUNX="$(find_bunx)"; then
    if command -v curl >/dev/null; then
      # bun's installer needs unzip, which minimal Linux images leave out.
      if ! command -v unzip >/dev/null && [ -n "${PM:-}" ]; then
        pm_install unzip || echo "  could not install unzip."
      fi
      echo "Installing bun, for the skills CLI..."
      curl -fsSL https://bun.sh/install | SHELL=/bin/sh bash >/dev/null ||
        echo "  could not install bun — carrying on."
    else
      echo "bun not installed and curl is unavailable — install it yourself."
    fi
    BUNX="$(find_bunx || true)"
  fi

  while read -r package skill; do
    case "$package" in ''|\#*) continue ;; esac

    if [ -f "$HOME/.agents/skills/$skill/SKILL.md" ] && [ -e "$HOME/.claude/skills/$skill" ]; then
      echo "Already installed: skill $skill"
      continue
    fi

    if [ -z "${BUNX:-}" ]; then
      echo "WARNING: bunx is unavailable, so skill $skill was not installed." >&2
      continue
    fi

    echo "Installing skill $skill from $package..."
    # From $HOME so the CLI can't mistake the current directory for a project.
    if ! (cd "$HOME" && "$BUNX" skills add "$package" -g -a claude-code -a codex -s "$skill" -y </dev/null >/dev/null 2>&1); then
      echo "  could not install skill $skill — carrying on."
    fi
  done < "$list"
}

install_external_skills

# Claude Code takes the Bash tool's shell from env.CLAUDE_CODE_SHELL in
# settings.json, which write_shell_setting below owns. The rc alias sets $SHELL
# for the claude command as the fallback for a machine with no jq, a broken
# settings.json, or a CLI old enough to predate the setting. The bash path
# differs per machine, so neither is synced from this repo.
bash_version_key() {
  "$1" -c 'printf "%s%03d\n" "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"' 2>/dev/null || true
}

detect_bash() {
  candidates=(/opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash /bin/bash)
  if command -v brew >/dev/null; then
    candidates=("$(brew --prefix)/bin/bash" "${candidates[@]}")
  fi

  best=""
  best_key=0
  for candidate in "${candidates[@]}"; do
    [ -x "$candidate" ] || continue
    key="$(bash_version_key "$candidate")"
    case "$key" in
      ''|*[!0-9]*) continue ;;
    esac
    [ "$key" -lt 4000 ] && continue
    if [ "$key" -gt "$best_key" ]; then
      best_key="$key"
      best="$candidate"
    fi
  done

  [ -n "$best" ] || return 1
  echo "$best"
}

if ! BASH_PATH="$(detect_bash)"; then
  if [ "$PM" != none ]; then
    echo "Installing bash..."
    pm_install bash || echo "  could not install bash — carrying on."
    BASH_PATH="$(detect_bash || true)"
  fi
fi

MARK_START="# >>> ai-config >>>"
MARK_END="# <<< ai-config <<<"

# Rewrite our marked block in $1, leaving the rest of the file alone. Refuses
# to touch a file whose markers are damaged rather than risk eating content.
write_block() {
  rc="$1"

  link="$(readlink "$rc" 2>/dev/null || true)"
  case "$link" in
    "") link="$rc" ;;
    /*) ;;
    # A relative link into the repo has to be resolved against the file's own
    # directory, or it does not look like a repo path at all.
    *)  link="$(cd "$(dirname "$rc")/$(dirname "$link")" && pwd)/$(basename "$link")" ;;
  esac
  case "$link" in
    "$REPO"/*)
      echo "Skipping $rc — it is synced from the repo."
      return
      ;;
  esac

  starts="$(grep -c "^${MARK_START}[[:space:]]*$" "$rc" || true)"
  ends="$(grep -c "^${MARK_END}[[:space:]]*$" "$rc" || true)"

  damage=""
  if [ "$starts" != "$ends" ] || [ "$starts" -gt 1 ]; then
    damage="$starts start, $ends end"
  elif [ "$starts" = "1" ]; then
    # An end marker above the start passes the count check, and the rewrite
    # below would then delete everything from the start marker to the end of
    # the file.
    start_line="$(grep -n "^${MARK_START}[[:space:]]*$" "$rc" | cut -d: -f1)"
    end_line="$(grep -n "^${MARK_END}[[:space:]]*$" "$rc" | cut -d: -f1)"
    [ "$start_line" -lt "$end_line" ] || damage="end marker above start marker"
  fi

  if [ -n "$damage" ]; then
    echo "WARNING: $rc has damaged ai-config markers ($damage)." >&2
    echo "  Left untouched. Fix the markers by hand, or delete the block, then re-run." >&2
    return
  fi

  comment="# Point Claude Code's Bash tool at bash. Written by install.sh."
  alias_line="alias claude=\"SHELL='$BASH_PATH' claude${CLAUDE_FLAGS:+ $CLAUDE_FLAGS}\""

  # Rewrite the block where it already sits. Stripping and re-appending would
  # move it to the end of the file and reorder whatever the user has after it.
  tmp="$rc.ai-config.tmp"
  if [ "$starts" = "1" ]; then
    awk -v s="^${MARK_START}[[:space:]]*$" -v e="^${MARK_END}[[:space:]]*$" \
      -v l1="$MARK_START" -v l2="$comment" -v l3="$alias_line" -v l4="$MARK_END" \
      '$0 ~ s {print l1; print l2; print l3; print l4; skip=1; next}
       $0 ~ e {skip=0; next}
       !skip {print}' "$rc" > "$tmp"
  else
    {
      cat "$rc"
      # A file with no trailing newline would glue the marker onto its last line.
      if [ -s "$rc" ] && [ -n "$(tail -c1 "$rc")" ]; then
        echo
      fi
      echo "$MARK_START"
      echo "$comment"
      echo "$alias_line"
      echo "$MARK_END"
    } > "$tmp"
  fi

  if cmp -s "$tmp" "$rc"; then
    rm -f "$tmp"
    echo "Already current: claude alias in $rc"
    return
  fi

  # Before the first modification, so the backup is of the file as it was.
  [ -e "$rc.ai-config.bak" ] || cp "$rc" "$rc.ai-config.bak"

  # Write through the symlink rather than replacing it — ~/.zshrc is often a
  # link into a dotfiles or prezto checkout.
  cat "$tmp" > "$rc"
  rm -f "$tmp"
  echo "Updated claude alias in $rc"
}

# Claude Code reads the Bash tool's shell from env.CLAUDE_CODE_SHELL in
# settings.json, and auto memory is switched off by autoMemoryEnabled. That
# file is per-machine, so each key the installer owns is merged into it and
# everything else in there is left alone.
#
# merge_setting <label> <current> <filter> [jq args...]: <current> is a jq test
# that is true when the file already has what <filter> would write. Asking
# first, rather than diffing jq's output against the file, keeps a settings.json
# that is already current byte for byte instead of rewriting it in jq's
# formatting.
SETTINGS_CREATED=""
merge_setting() {
  label="$1"
  current="$2"
  filter="$3"
  shift 3
  settings="$HOME/.claude/settings.json"
  # ~/.claude usually exists from the linking above, but the agents config can
  # drop the claude entry and this write must still land.
  mkdir -p "$HOME/.claude"

  if ! command -v jq >/dev/null; then
    echo "WARNING: jq is unavailable, so $label was not written to $settings." >&2
    echo "  Install jq and re-run, or edit the file by hand." >&2
    return
  fi

  if [ ! -e "$settings" ]; then
    jq -n "$@" "$filter" > "$settings"
    SETTINGS_CREATED=1
    echo "Created $settings with $label"
    return
  fi

  if ! jq -e . "$settings" >/dev/null 2>&1; then
    echo "WARNING: $settings is not valid JSON, so $label was not written. Fix it and re-run." >&2
    return
  fi

  if jq -e "$@" "$current" "$settings" >/dev/null 2>&1; then
    echo "Already current: $label in $settings"
    return
  fi

  tmp="$settings.ai-config.tmp"
  if ! jq "$@" "$filter" "$settings" > "$tmp"; then
    rm -f "$tmp"
    echo "WARNING: could not write $label to $settings. Left untouched." >&2
    return
  fi

  # Before the first modification, so the backup is of the file as it was. A
  # file this run created has no earlier state worth keeping.
  [ -n "$SETTINGS_CREATED" ] || [ -e "$settings.ai-config.bak" ] || cp "$settings" "$settings.ai-config.bak"

  # Write through the file rather than replacing it, so a settings.json someone
  # has symlinked out of their own dotfiles keeps its link.
  cat "$tmp" > "$settings"
  rm -f "$tmp"
  echo "Set $label in $settings"
}

if [ -n "${BASH_PATH:-}" ]; then
  echo "Claude shell: $BASH_PATH ($("$BASH_PATH" --version | sed -n 1p))"
  merge_setting "CLAUDE_CODE_SHELL=$BASH_PATH" \
    '.env.CLAUDE_CODE_SHELL == $shell' \
    '.env.CLAUDE_CODE_SHELL = $shell' \
    --arg shell "$BASH_PATH"
fi

merge_setting "autoMemoryEnabled=false" \
  '.autoMemoryEnabled == false' \
  '.autoMemoryEnabled = false'

if [ -z "${BASH_PATH:-}" ]; then
  echo "WARNING: no bash 4+ found. Claude Code will keep using your login shell."
else
  login_shell="$(basename "${SHELL:-}")"

  if [ "$login_shell" = "fish" ]; then
    echo "WARNING: your login shell is fish, which cannot parse the alias this script writes."
    echo "  Add this to ~/.config/fish/config.fish by hand:"
    echo "    alias claude \"SHELL='$BASH_PATH' claude${CLAUDE_FLAGS:+ $CLAUDE_FLAGS}\""
  fi

  # zsh is the macOS default and a fresh machine has no ~/.zshrc at all, so
  # create it rather than silently skipping the shell the user actually uses.
  if [ "$login_shell" = "zsh" ] && [ ! -e "$HOME/.zshrc" ]; then
    : > "$HOME/.zshrc"
    echo "Created $HOME/.zshrc"
  fi

  # Prefer an existing login-shell file over creating ~/.bash_profile, which
  # would shadow ~/.profile and silently disable everything in it.
  bash_login_rc=""
  for candidate in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
    if [ -e "$candidate" ]; then
      bash_login_rc="$candidate"
      break
    fi
  done
  if [ -z "$bash_login_rc" ]; then
    bash_login_rc="$HOME/.bash_profile"
    echo '[ -f ~/.bashrc ] && . ~/.bashrc' > "$bash_login_rc"
    echo "Created $bash_login_rc"
  fi

  for rc in "$HOME/.zshrc" "$bash_login_rc"; do
    [ -e "$rc" ] || continue
    # A file linked from this repo is shared by every machine, but the bash
    # path is not. shell/zsh/zshrc sources ~/.zshrc.local, so the block goes
    # there instead.
    if [ "$(readlink "$rc" 2>/dev/null || true)" = "$REPO/shell/zsh/zshrc" ]; then
      rc="$HOME/.zshrc.local"
      [ -e "$rc" ] || : > "$rc"
    fi
    write_block "$rc"
  done

  echo
  echo "Note: settings.json is what points Claude Code's Bash tool at $BASH_PATH."
  echo "The alias is only a fallback, and it covers login shells alone — a"
  echo "non-login shell, a script or cron gets it from settings.json or not at all."
fi

# The template ships a placeholder git identity. Say so until it's replaced,
# in git/gitconfig or in this machine's ~/.gitconfig.local.
if [ "$(git config --global user.email 2>/dev/null || true)" = "you@users.noreply.github.com" ]; then
  echo
  echo "WARNING: git still uses the template's placeholder identity."
  echo "  Edit [user] in git/gitconfig, or run:"
  echo "    git config --file ~/.gitconfig.local user.name \"Your Name\""
  echo "    git config --file ~/.gitconfig.local user.email you@example.com"
fi
