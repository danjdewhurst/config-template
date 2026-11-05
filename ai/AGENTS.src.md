# Working with me

<!--
  This is the one source for every agent's global instructions. ai/build.sh
  renders it into ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md and ~/.agents/AGENTS.md.
  Replace the examples below with your own rules. Short, concrete rules work
  better than long essays. Delete this comment when you're done.
-->

## How to reply

- Give the answer or the result first. Don't repeat my question.
- Keep replies short. Use a list or a table only when it makes the reply easier to scan.
- When you finish a task, say what you changed, how you checked it, and what you didn't do.
- If tests fail or a step was skipped, say so plainly.

## Labels

When a reply has a list of findings, options, questions or next steps, give each item a label, so I can answer with "go with O2" or "skip F3".

| Letter | List |
|---|---|
| F | Findings |
| O | Options |
| Q | Questions |
| S | Next steps (things I must do) |

- Number each letter from 1 in each reply.
- Put questions before next steps, and next steps at the end.

## How to work

- Read the code before you change it. Follow the style of the files around it.
- Run the project's tests, linters and type checks before you say a change is done.
- Ask before you do anything destructive or hard to undo: deleting data, force-pushing a shared branch, deploying, or changing a server.
- Never write secrets into a repo: no passwords, private keys, tokens or `.env` files.

## Pull requests

When I ask for a pull request:

1. Work on a branch, not the default branch.
2. Open the PR as ready for review, unless I ask for a draft.
3. Review the PR with subagents, if your agent has them:
   - Read the diff and pick 1 to 5 review focuses that fit it, for example correctness, security, tests, performance or docs accuracy.
   - Always include correctness. Add another focus only when the diff can break that area. Judge by what the change can break, not by its size, and use correctness alone for a docs-only change.
   - Start one subagent per focus, all at once. Give each one the repo, the PR number and its focus, but not your own reasoning or what you expect it to find.
   - Tell them to report findings only, and not to change files, push, or comment on the PR.
4. Wait for CI and the review subagents. Fix what fails and push again.
5. Read the findings and the review comments. Fix the ones that are correct and in scope, and reply to each PR comment with the commit that fixes it or why you didn't.
6. Don't merge unless I ask you to.
7. End with the PR link, the focuses you picked, what you fixed, and what you left open.

<!--
  A block between a tag and its closing tag, each on its own line, goes only to
  the agents the tag names. The name is the agent's directory without the dot.
-->
<claude>
## Claude Code only

- Use subagents for broad searches across many files, so the main context stays small.
</claude>
<codex>
## Codex only

- Run the tests with the sandbox's network access in mind. Say so if a test needs the network.
</codex>
