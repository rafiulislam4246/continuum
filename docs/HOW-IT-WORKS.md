# How it works

## The problem, precisely

Claude Code starts every session with a fresh context window. Conversation
history does not carry over, and `--continue` / `--resume` replay a single
session's transcript rather than reconstructing project knowledge. Compaction
inside a long session summarises, and a summary of a summary loses exactly the
detail that was expensive to acquire: which approach was already tried, which
command proves the feature works, which file is half migrated.

Anything that is going to survive has to live on disk, in the repository, in a
form a cold reader can act on.

## The three mechanisms

**1. Automatic injection.** The `SessionStart` hook fires on `startup`,
`resume`, `clear`, `compact` and `fork`. Plain stdout on that event is added to
the session's context, which is the one place the pack does not depend on the
model remembering to do anything. The brief is capped at 9000 bytes against the
10000-character limit on injected context.

**2. Write-ahead state.** State is stamped after each unit of work, not at the
end of the session. The stamp records time, git sha, branch, dirty-file count
and the next concrete action. Because the sha is recorded, the next session can
compute drift: `git log <last-sha>..HEAD` tells it that work landed which the
state does not describe, so state gets reconciled before anything is built on
it. This is what stops confident work on a stale premise.

**3. Evidence as a hard gate.** `continuum task done` exits non-zero when the
evidence field is empty. The state files are only valuable if they are trusted,
and they are only trustworthy if DONE means something was run and read. A ledger
of unverified claims is worse than no ledger, because later sessions build on it.

## Hook wiring

| Event | Matcher | Does |
|---|---|---|
| `SessionStart` | `startup\|resume\|clear\|compact\|fork` | prints the brief to stdout, which the session receives as context |
| `Stop` | none | emits `hookSpecificOutput.additionalContext` when the tree has moved but state has not been stamped for 25 minutes, with a 20 minute cooldown so it cannot nag |
| `PreCompact` | none | journals the compaction; warns the user if nothing was ever checkpointed |
| `SessionEnd` | none | journals the close reason |

`Stop` cannot reach the model through plain stdout, which is why that hook emits
JSON. `PreCompact` cannot inject context at all, which is why the recovery path
after compaction is `SessionStart` firing again with `source=compact`.

## Why a shell CLI and not a model that edits files directly

The model writes the prose, because judgement about what matters is the part it
is good at. The CLI owns the mechanical parts: stamping, appending, assembling
the brief, maintaining the cross-project registry. Those have to be correct even
when the session is confused or out of context, and they must not consume
context to perform. It is POSIX `sh` with no dependencies so it runs wherever the
project runs, including in CI.

## Identity across projects

Each project carries an id in `.continuum/config.json`, formed from its display
name and a `cksum` fingerprint of its absolute path, so two checkouts of one repo
are two distinct projects. Every checkpoint upserts a row in
`~/.continuum/registry.tsv`: id, name, path, updated, open task count, next
action. `continuum projects` reads that file, which is how a session in one repo
can answer what is pending in another without opening it.

The brief names the project explicitly, because a session that infers the project
from a directory path will eventually infer wrong, and the cost of acting on the
wrong project's state is high.

## What is deliberately not here

- **No embeddings or vector search.** At one project's scale, six curated files a
  session reads on demand beat a retrieval system that returns plausible
  fragments. Retrieval failure is silent; a missing file is not.
- **No background daemon.** Nothing runs between sessions. All state changes are
  caused by a hook or an explicit command, so the state is always explainable.
- **No conversation transcripts.** Those are what `--resume` already does, and
  storing them again would reproduce the problem: a long history nobody reads
  instead of a short brief everybody does.

## Sources

- [How Claude Code works](https://code.claude.com/docs/en/how-claude-code-works)
- [Hooks reference](https://code.claude.com/docs/en/hooks)
