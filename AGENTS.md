# AGENTS.md — working rules for AI agents in this repository

This file is for any AI coding agent (DeepSeek Harness, Claude Code, Cursor, Codex) and for the human reviewing the work.
The game specification is `docs/AI_BUILD_PROMPT.md`. It is **large on purpose** (~96 KB, ~24k tokens). This file explains how to use it without blowing up the context window.

## 1. Read order (never skip step 1)

| Step | File | Cost | Why |
|---|---|---|---|
| 1 | `docs/PROGRESS.md` | ~1k tokens | where we are, what is next, open blockers |
| 2 | `docs/milestones/M<N>.md` | ~1k tokens | the exact scope of this session |
| 3 | `docs/AI_BUILD_PROMPT.md` — **only the sections listed in the brief** | 3–8k tokens | the spec |
| 4 | `docs/DECISIONS.md`, `docs/ARCHITECTURE.md` | when relevant | why the code looks like this |

**Do not read the whole specification.** It is a reference document, not a prompt. Locate a section by heading (`grep -n "^### 4.6"` or the `grep` tool), then `read` with `offset`/`limit` around that line (±60–120 lines). Two to four sections per session is the budget.

## 2. Context budget rules

- One session = one milestone, at most one and a half.
- Batch work: one service, or one scene + its script, or one data set per step. Never "implement everything".
- Use `read` with `limit`; use `grep` instead of reading a file to find a symbol.
- Never dump whole logs: `... | Select-Object -Last 40`. Full logs are already saved to a file by the harness — read the tail, not the file.
- For the art manifest, use `docs/art_manifest.json` and filter it (count, `Select-String`, or a small script). Never load the 240-row markdown table.
- Do not re-read a file you just wrote or edited in this session.
- If a task needs broad exploration ("find all usages", "audit 20 files"), delegate it to a **subagent** with a self-contained prompt and ask for a 10-line summary. The subagent's context is disposable; yours is not.
- Keep your own replies short. A 200-line explanation after a 40-line change is wasted context.

## 3. Session protocol

1. **Boot** (2 min): read `PROGRESS.md` + milestone brief; run `git status`, `git log --oneline -5`, `git tag --list | Select-Object -Last 3`.
2. **Plan**: post the list of files you will create/modify and the order; create a todo list.
3. **Implement** in small batches, cheapest dependencies first: data → services → scenes → UI.
4. **Verify** after every batch: `tools/check_project.ps1` (headless import + parse check) and, when touched, `tests/run_tests.gd`. A red check blocks the next batch.
5. **Commit** each logical unit (`feat(m2): ...`, `fix(...): ...`). Small commits are the undo button.
6. **Close**: update `docs/PROGRESS.md` (status, tag, next 3 tasks), `CHANGELOG.md`, and `DECISIONS.md` if a decision was made.
7. **Report** ≤ 15 lines: what works, what is stubbed, known issues, exact next command.

## 4. Context reset (the most important rule)

Agents degrade before the window is full: they forget constraints, re-read files, "improve" finished code. Watch for: repeating earlier summaries, ignoring a rule from the spec, editing files not in the plan.

When that starts, or when the session feels long:

1. Write a handoff block into `docs/PROGRESS.md` — current state, files touched, exact next command, open questions.
2. Commit everything.
3. Start a **new session** and use the boot prompt below. Do not "push through" a degraded session.

## 5. Verification

- Godot binary: `$env:GODOT_BIN`, or the path in `tools/godot_path.txt`.
- `tools/check_project.ps1` — runs the project headless and fails on parse errors, missing resources or broken imports.
- `tools/smoke_test.gd` — theme integrity + every screen/component scene loads and instantiates (`--headless --script res://tools/smoke_test.gd`).
- `tests/run_tests.gd` — pure-logic unit tests (damage, curves, wallet, save migration, modifiers, manifest).
- Never report a task as done without a green check. If you could not run it, write **"not verified"** explicitly.

## 6. Hard rules

- Do not modify `docs/AI_BUILD_PROMPT.md` to make the task easier. If the spec is wrong, add an entry to `docs/DECISIONS.md` and ask.
- Do not add a third-party addon without a `DECISIONS.md` entry (version, licence, fallback).
- Do not commit builds, keystores, `.env`, production ad IDs, or `.godot/`.
- Do not refactor code outside the milestone scope, even if it looks bad. Write it into `PROGRESS.md` as a follow-up.
- Do not use `Engine.time_scale` for the speed feature, and do not put game logic in UI scripts.
- Stay inside the folder structure from spec §11.1. New top-level folders are a decision, not an improvisation.

## 7. Boot prompt (copy-paste into a fresh session)

```text
You are working on "The Tree: Idle Tower Defense" (Godot 4, GDScript) in this repository.

1. Read, in this order: AGENTS.md, docs/PROGRESS.md, docs/milestones/M<N>.md.
2. Read only the spec sections listed in the brief, from docs/AI_BUILD_PROMPT.md
   (locate by heading with grep, then read with offset/limit — do NOT read the whole file).
3. Before coding: post a short plan and the exact list of files for the first batch.
4. Implement in small batches; after each batch run tools/check_project.ps1 (and tests when touched).
5. Commit per logical unit, then update docs/PROGRESS.md and CHANGELOG.md.
6. Finish with a 10-line report: what works, what is stubbed, known issues, next command.

If you run out of room, stop at a clean boundary, write the handoff block into docs/PROGRESS.md, commit, and say "handoff written".
```
