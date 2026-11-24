#!/bin/sh
# Prints a snapshot of the git checkout that holds the current directory, for
# the best-idea skill. Run it before and after each step that a subagent could
# change, and compare the two outputs line by line.
#
# Status, HEAD, the branch and the refs print as plain text, so a change can be
# named. The parts that can be large or hold secrets (stash, local config, the
# diff, untracked files and hooks) print as one hash each, never in full.
set -u

top=$(git rev-parse --show-toplevel) || exit 1
cd "$top" || exit 1
common=$(git rev-parse --git-common-dir)

h() { git hash-object --stdin; }

echo "status:"
git status --porcelain
echo "head $(git rev-parse --verify -q HEAD || echo none)"
echo "branch $(git branch --show-current)"
echo "refs:"
git for-each-ref --format='  %(refname) %(objectname)' refs/heads refs/tags
echo "stash $(git stash list | h)"
# branch.* keys change when another worktree pushes a new branch.
echo "config $(git config --local --list | grep -v '^branch\.' | h)"
echo "diff $( { git diff HEAD 2>/dev/null || git diff --cached; } | h)"
# cksum goes on past a path that it cannot read; git hash-object would stop.
echo "untracked $(git ls-files -o --exclude-standard -z | xargs -0 cksum -- 2>&1 | h)"
echo "hooks $(find "$common/hooks" -type f -exec cksum -- {} + 2>&1 | h)"
