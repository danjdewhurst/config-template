---
name: ship
description: Take your own recommendations, decide everything else yourself, finish the task and open a PR. Run only when the user invokes it by name (/ship in Claude Code, $ship in Codex).
disable-model-invocation: true
argument-hint: "[extra instructions]"
---

# Ship

The user wants the task finished on your judgement, with no questions, and a PR at the end.

Extra instructions from the user: $ARGUMENTS

Claude Code fills in that line. In other agents, use any text the user typed with the command. If there is any, it wins over anything below (for example "don't merge" or "skip the tests"). If you have nothing pending from earlier in the conversation, treat it as the task.

## What to do

1. Look back at your latest options, recommendations and open questions. Take your recommended choice for each one. Where you gave no recommendation, pick what you judge best.
2. Don't ask the user anything: no question tools, no "shall I?", no pause for approval. When something is unclear, take the sensible default, note it, and carry on.
3. Do the whole task: code, tests and docs. Run the repo's tests, linters and type checks, and fix what fails.
4. If you're on the default branch, make a branch. Commit the work.
5. Open the PR and follow the "Pull requests" rules in your global instructions.

## Where you still stop

The user's approval rules still hold. Stop and ask only for:

- an action that is destructive or hard to undo outside the PR: deleting data, force-pushing a default branch, a production deploy, or a server change;
- a secret or login that you don't have;
- a choice that the instructions or the code can't settle and a wrong guess would be costly to undo.

If the work isn't in a git repo with a remote, finish it and say in the report why there's no PR.

## Report

End with the PR link, each decision you made for the user, and what you didn't do and why.
