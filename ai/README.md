# AI agent config

Global instructions and skills for Claude Code, Codex and the shared `~/.agents` directory. `../install.sh` links them into place.

```text
~/Projects/config/ai/                   ~/
├── AGENTS.src.md ──▶ build/claude/CLAUDE.md ──▶ .claude/CLAUDE.md
│                     build/agents/AGENTS.md ──▶ .agents/AGENTS.md
│                     build/codex/AGENTS.md ───▶ .codex/AGENTS.md
├── hosts/<hostname>.md   appended to the renders on that machine
├── skills/
│   └── <skill>/ ──────────────────────▶ {.claude,.agents}/skills/<skill>
├── agents.conf
├── skills.txt
└── build.sh
```

| File | What it is |
|---|---|
| `AGENTS.src.md` | The global instructions, one source for every agent |
| `build.sh` | Renders `AGENTS.src.md` into `build/<agent>/<filename>`, which is what gets linked. `build/` is gitignored |
| `agents.conf` | Which agents get the instructions, and which skill directories get the skills |
| `hosts/` | Notes for one machine each, added to the end of the instructions on that machine |
| `skills/` | Skills kept in this repo |
| `skills.txt` | Skills installed from their own repos with the [skills CLI](https://skills.sh) |

## Change the instructions

Edit `ai/AGENTS.src.md`, not `~/.claude/CLAUDE.md`, which links to the rendered copy. Then:

```sh
~/Projects/config/ai/build.sh
git -C ~/Projects/config commit -am "Update agent instructions"
git -C ~/Projects/config push
```

On the other machines, run `git pull && ai/build.sh`. Without `build.sh`, agents keep reading the old render.

## Send a block to some agents only

A block between a tag and its closing tag, each on its own line, only goes to the agents the tag names:

```markdown
<claude>
- Only Claude reads this.
</claude>
<codex agents>
- Codex and ~/.agents read this.
</codex agents>
```

A tag name is the agent's directory without the dot: `~/.claude` is `claude`. An unknown name, a nested tag or an unclosed tag fails the build with the file and line, so a typo can't silently drop a block.

## Tell agents which machine they're on

`hosts/<hostname>.md` is added to the end of every render on the machine with that short hostname, in lowercase (`hostname -s | tr A-Z a-z`). Put in it what changes how an agent should behave there: headless or not, which URLs you can open, and what the machine can reach. The full notes stay in `../machines/`.

The template ships two examples, `hosts/my-laptop.md` and `hosts/my-server.md`. Rename them to your hostnames. A machine with no file gets only `AGENTS.src.md`, and `build.sh` prints the file name it looked for. After you edit a host file, run `build.sh` on that machine.

## Skills

| Skill | What it does |
|---|---|
| `infra` | Points agents at this repo's notes when a task touches your machines or network. Edit its `description` to list your machine names |
| `ship` | Slash command only (`/ship`, or `$ship` in Codex): take your own recommendations, ask nothing, open a PR |
| `better-writing` | An example external skill, from [forjd/better-writing](https://github.com/forjd/better-writing), listed in `skills.txt` |

`install.sh` installs anything in `skills.txt` that's missing, with `bunx skills add -g`. The CLI keeps one copy in `~/.agents/skills`, which Codex reads directly, and links it into `~/.claude/skills`. If bun is missing, it installs it with the official installer from bun.sh. To update those skills, run `bunx skills update -g`.

To add a skill kept in this repo, add a directory under `skills/` and re-run `install.sh`. Then run `git pull && ./install.sh` on each other machine. `git pull` updates skills that are already linked, but only `install.sh` links a new one. To make a skill run only when you name it, set `disable-model-invocation: true` in its `SKILL.md` front matter for Claude, and add `agents/openai.yaml` with `policy.allow_implicit_invocation: false` for Codex. `skills/ship` has both. To remove a skill, delete the directory and re-run. The links go with it. Skills an agent installed for itself aren't touched.

## Add an agent

`agents.conf` lists the agents as `<dir>:<filename>`:

```bash
AGENT_DIRS=(
  "$HOME/.claude:CLAUDE.md"
  "$HOME/.agents:AGENTS.md"
  "$HOME/.codex:AGENTS.md"
)
```

Skills are linked into the directories in `SKILL_DIRS`, also in `agents.conf`: `~/.claude/skills` and `~/.agents/skills`. Codex reads `~/.agents/skills`, so skills aren't linked into `~/.codex/skills`. A link in both would show Codex each skill twice.

To change either list on one machine only, put the same syntax in `~/.ai-config.local`, which isn't committed. `install.sh` and `build.sh` both read it. For example, `AGENT_DIRS+=("$HOME/.gemini:GEMINI.md")`.

## settings.json stays per machine

`~/.claude/settings.json` isn't in this repo, because most of it is machine-specific: MCP servers, notifications, effort level. `install.sh` only merges in two keys, `env.CLAUDE_CODE_SHELL` and `autoMemoryEnabled: false`, and keeps a `settings.json.ai-config.bak` the first time it changes an existing file. Auto memory is off so that what agents should know lives in this repo, where you can read and review it.
