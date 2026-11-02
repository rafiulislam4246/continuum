# Continuum

Durable project memory for Claude Code. Drop it into any project, and a new
session picks up exactly where the last one stopped, without being told what the
project is.

Every new session starts with a fresh context window. Claude Code's own docs are
explicit about it: conversation history does not carry over, and `--continue` /
`--resume` only replay one session's transcript. Close the terminal, switch
machines, let the context compact, come back a week later, and the thread is
gone. Continuum fixes that by putting the memory in the repository instead of in
the conversation.

```
you, next monday:  "continue"
claude:            [reads .continuum/, runs the verify command, starts work]
```

---

## What it installs

```
your-project/
├── .continuum/                 state the project carries
│   ├── STATE.md                where we are          (injected every session)
│   ├── NEXT.md                 the resume contract   (injected every session)
│   ├── TASKS.md                the ledger, evidence required
│   ├── DECISIONS.md            what must not be relitigated
│   ├── brain/                  how this project works (6 files, read on demand)
│   ├── journal/                append-only daily log
│   └── bin/continuum           the CLI, POSIX sh, no dependencies
└── .claude/
    ├── skills/continuum*/      6 skills that drive the discipline
    ├── hooks/continuum-*.sh    SessionStart, Stop, PreCompact, SessionEnd
    └── settings.json           hook wiring, merged into whatever is there
```

The `SessionStart` hook is the mechanism that makes this automatic: on `startup`,
`resume`, `clear`, `compact` and `fork`, it prints a resume brief, and stdout on
that event is added to the session's context. So the session knows the project
before you type anything.

---

## Install

```sh
git clone https://github.com/rafiulislam4246/continuum.git
cd continuum
./install.sh /path/to/your-project
```

Then open Claude Code in that project and run `/continuum`. On first contact it
onboards: explores the repo, writes the brain files, seeds state and tasks, and
asks you at most three questions that the code genuinely cannot answer.

Install the skills once for every project, plus the CLI on your PATH:

```sh
./install.sh --global /path/to/your-project
```

Re-running the installer is safe. Existing state files are never overwritten,
and the hook wiring is merged into your `settings.json` rather than replacing it.

**Commit `.continuum/` in your project.** That is what makes the state travel
with the repo, to your other machine and to anyone else working on it. Never put
secret values in it: record the variable name and where the value lives.

Requirements: POSIX `sh`, `git`, and `python3` for the `settings.json` merge
(without it the installer writes the file when absent and prints the snippet
otherwise). Tested on macOS and Linux.

---

## Many projects, one machine

Each project gets a stable id (`name-pathhash`) and registers itself in
`~/.continuum/registry.tsv` on every checkpoint. So a session always knows which
project it is in, and you can see everything in flight from anywhere:

```
$ continuum projects
    PROJECT                    UPDATED              OPEN  NEXT ACTION
->  Review Engine              2026-11-02T09:40:39  3     add the 30s cap in src/webhook.ts:88, then pnpm test
    Lead Engine                2026-11-01T18:22:04  1     verify the 004 migration landed, then re-run the seed
    Ads System                 2026-10-29T11:07:50  0     -

$ continuum where          # which project is this, and what was it doing
$ continuum switch "Lead Engine"   # resolve its path, print its brief
```

Two checkouts of the same repo are two projects with two ids and two states.
Nothing is shared, and no session reads another project's notes.

---

## The CLI

```sh
continuum init                        scaffold .continuum/ here
continuum brief                       the resume brief (what the hook prints)
continuum checkpoint "<next action>"  stamp state, journal it, update the registry
continuum log "<line>"                append to today's journal
continuum task add "<task>"           create a task, prints its ID
continuum task start T-007
continuum task done  T-007 "<evidence>"    refuses an empty evidence field
continuum task block T-007 "<why>"
continuum task {list|open}
continuum status                      short state and open tasks
continuum where                       this project's identity and next action
continuum projects                    everything registered on this machine
continuum switch <name|id>            resolve another project
continuum rename "<name>"             change the display name, id stays stable
continuum doctor                      health and drift check, exit 1 if degraded
```

Env: `CONTINUUM_DIR` overrides the state location, `CONTINUUM_HOME` the registry
(default `~/.continuum`), `CONTINUUM_NAME` the display name at init,
`CONTINUUM_STALE_MIN` / `CONTINUUM_COOLDOWN_MIN` the stop hook's thresholds.

---

## The skills

| Skill | Does |
|---|---|
| `continuum` | Entry point. Establishes which project this is, then routes. |
| `continuum-onboard` | First contact: explore the repo, write the brain. |
| `continuum-resume` | Load state, verify it against the tree, execute the contract. |
| `continuum-checkpoint` | Persist a completed unit of work. |
| `continuum-handoff` | Close a session so the next one starts at full speed. |
| `continuum-verify` | Evidence gate before any claim that something works. |

Three rules carry most of the value:

1. **Checkpoint after every unit of work**, not at the end. A session that dies
   between checkpoints loses one unit, not a day.
2. **No task is DONE without evidence**: the command run and the result read.
   The CLI refuses an empty evidence field on purpose.
3. **Correct the brain on contact.** Stale memory is worse than no memory,
   because it gets trusted.

---

## What the session actually receives

```
=== CONTINUUM RESUME BRIEF ===
project : Review Engine
id      : review-engine-7d9f10ff
root    : /Users/you/work/review-engine
repo    : a86f053 on main
as of   : 2026-11-02T09:39:46Z

--- STATE ---          objective, focus, state of play, blockers, decisions, do-not
--- NEXT ---           the three first actions, the verify command, out of scope
--- OPEN TASKS ---     up to 14 rows from the ledger
--- DRIFT ---          commits landed since the last checkpoint, uncommitted count
--- JOURNAL TAIL ---   the last 14 lines of what happened
--- BRAIN ---          the six files and their titles, read on demand
```

Capped at 9000 bytes, inside the 10000-character limit on injected hook context.
The drift section is the part people underestimate: it tells the session that
someone committed work it does not know about, so state gets reconciled before
anything is built on it.

---

## Compaction

When the context window fills, `PreCompact` journals the event, and
`SessionStart` fires again with `source=compact`, re-injecting the brief. A
checkpointed project survives compaction with its thread intact, because the
state files are read fresh rather than summarised.

---

## Does this replace CLAUDE.md?

No. `CLAUDE.md` holds standing instructions: how you want Claude to behave in
this repo. Continuum holds moving state: what is happening right now, what is
proven, what is next. They sit side by side, and the brain files are the place
for the project knowledge that would otherwise bloat `CLAUDE.md` into something
nobody maintains.

---

## Removing it

```sh
./uninstall.sh /path/to/your-project          # hooks and skills, state kept
./uninstall.sh --purge /path/to/your-project  # state too
```

---

## Sources

- [How Claude Code works](https://code.claude.com/docs/en/how-claude-code-works) - fresh context per session, auto memory, CLAUDE.md
- [Hooks reference](https://code.claude.com/docs/en/hooks) - which events inject context, matchers, `additionalContext`

MIT licensed. Issues and pull requests welcome.
