#!/bin/sh
# Prints a snapshot of a git checkout, for the best-idea skill. The argument
# is a directory in the checkout (default: the current directory). Run it
# before and after each step that a subagent could change, and compare the
# two outputs line by line.
#
# Status, HEAD, the branch, the refs and the stash names print as plain text,
# so a change can be named. The parts that can be large or hold secrets
# (local config, the diff, untracked files and hooks) print as one hash each,
# never in full.
#
# Blind spots: worktree-only config (config.worktree) and included config
# files, ignored files, nested repos, pushes, gh actions and anything outside
# the repo.
set -u

cd "${1:-.}" || exit 1
top=$(git rev-parse --show-toplevel) || exit 1
cd "$top" || exit 1
cur=$(git branch --show-current)

h() { git hash-object --stdin; }

echo "status:"
git status --porcelain
echo "head $(git rev-parse --verify -q HEAD || echo none)"
echo "branch $cur"
echo "refs:"
git for-each-ref --format='  %(refname) %(objectname)' refs/heads refs/tags
echo "stash:"
git stash list --format='  %gd %H'
# Leave out the branch.<name>.* keys of other branches: they change when
# another worktree pushes a new branch. Keep the current branch's keys.
echo "config $(git config --local --list | awk -v c="branch.$cur." 'index($0, "branch.") != 1 || (c != "branch.." && index($0, c) == 1)' | h)"
echo "diff $( { git diff HEAD 2>/dev/null || git diff --cached; } | h)"
# cksum goes on past a path that it cannot read; git hash-object would stop.
echo "untracked $(git ls-files -o --exclude-standard -z | xargs -0 cksum -- 2>&1 | h)"
# --git-path follows core.hooksPath when it is set.
echo "hooks $(find "$(git rev-parse --git-path hooks)" -type f -exec cksum -- {} + 2>&1 | h)"
