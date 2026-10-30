# ai-workflow

A set of rules for working with AI coding agents (Claude Code, Codex) across the repositories of one project, plus an **AI backlog**: a small git repository next to the code where agents and people keep implementation plans, tickets (bugs, technical debt, refactoring), testing and code-review records, support cases and architecture notes, each with a status that can be listed mechanically. The board (Azure DevOps today) is written only from those items, after confirmation.

The rules are generic: no project names, people or dates. Each project adds a short **profile** (an `AGENTS.md` with its people, language, branches, board) and a decisions file with its own dated history. The module is pulled into every project as a git submodule, so both tools read it as plain files and a rule changes in one place.

What it does not do: it is not a task runner or a plugin, and it does not replace a repository's own `AGENTS.md` with build and style rules.

## Files

| File | For | Read when |
|---|---|---|
| `workspace.md` | agents | working in any code repository of the workspace |
| `backlog.md` | agents | creating, moving or changing a backlog item |
| `azure-devops.md` | agents, people | writing to the board; setting up the MCP server |
| `INIT.md` | agents | setting up or checking a workspace |
| `skills/` | agents | a skill asks for the issue tracker, triage labels or domain docs |
| `templates/` | `INIT.md` | the two profile files it fills in |
| `scripts/` | people | `Set-AdoPat.ps1` stores the Azure DevOps token (`azure-devops.md` "Setup", step 2) |

## Prerequisites

- git: `git --version`
- Claude Code (`claude --version`) and/or Codex (`codex --version`)
- Node.js, only for the Azure DevOps board: `node --version`

## Set up a new project with an agent

The workspace is a folder that holds the project's code repositories side by side, for example:

```text
my-project/
├── api/        (git repository)
├── web/        (git repository)
└── worker/     (git repository)
```

Open Claude Code or Codex in that folder and paste:

```text
Follow https://github.com/neman/ai-workflow/blob/main/INIT.md to set up this folder.
```

The agent surveys the folder, asks a few questions (backlog name, who works here, language, shared branches, tracker), and leaves:

```text
my-project/
├── AGENTS.md                      ← workspace profile + pointer to the module
├── api/AGENTS.md                  ← first line: Read ../AGENTS.md before starting.
├── web/AGENTS.md
├── worker/AGENTS.md
└── ai-backlog/                    ← new git repository
    ├── .ai-workflow/              ← this module, as a submodule
    ├── AGENTS.md                  ← backlog profile
    ├── docs/agents/decisions.md
    ├── plans/  tickets/  testing-findings/  code-reviews/  support/  architecture/  archive/
    └── README.md
```

What stays with you: committing the backlog and the repositories' `AGENTS.md`, creating the backlog's remote repository, creating a PAT and restarting the terminal if the board is used. The agent lists these at the end. `INIT.md` can be run again at any time; it only adds what is missing.

Setting up by hand follows the same `INIT.md`, step by step.

## Azure DevOps

`azure-devops.md` "Setup" has the PAT, the MCP server registration for Claude Code and Codex, the wrapper for a second organization on the same machine, and the troubleshooting list. `INIT.md` Step 7 walks through it with your values.

## Join an existing project

```powershell
git clone --recurse-submodules <backlog-url>
# or, after a plain clone:
git submodule update --init
```

Then set up the board (previous section) if you write to it. Running `INIT.md` in the workspace folder also works: it reports what is missing on your machine and fills it in.

## Update or change the module

A submodule is pinned to one commit. To pick up new rules in a project:

```powershell
git submodule update --remote .ai-workflow
git add .ai-workflow
git commit -m "Update ai-workflow"
```

To change the rules, edit a normal clone of this repository, commit and push there, then update the submodule in every project as above. Avoid editing inside `.ai-workflow/` of a project: the submodule checkout is a detached HEAD, and a commit made there is easy to leave unpushed and lose.

## Check it works

In a fresh agent session in the backlog folder:

> Where does a new ticket go, which fields must it have, and what do you do before writing to the board?

Expected: `tickets/active/`, the fields from `backlog.md` with the labels from the profile, and "show the list and wait for confirmation" before any board write. In a fresh session in a code repository:

> You found a bug outside your task: where do you write it and do you commit?

Expected: the backlog path, and "the owner commits". The backlog is outside the repository, so Claude Code asks once per session for permission to read its files; allow it, or start the session with `claude --add-dir <path to the backlog>`.
