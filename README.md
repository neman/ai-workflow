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
| `scripts/` | people | `Set-AdoPat.ps1` stores the Azure DevOps token (`azure-devops.md` "Setup", step 2); `Update-AiWorkflow.ps1` updates the module in every project at once ("Update or change the module") |

## Prerequisites

- Windows with PowerShell 5.1 or 7: the status listing, the token storage and the MCP wrapper are PowerShell and `.cmd`
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
├── api/AGENTS.md                  ← starts with: Read ../AGENTS.md before starting (and what to do if it is missing)
├── web/AGENTS.md
├── worker/AGENTS.md
└── ai-backlog/                    ← new git repository
    ├── .ai-workflow/              ← this module, as a submodule
    ├── AGENTS.md                  ← backlog profile
    ├── docs/agents/decisions.md
    ├── plans/  tickets/  testing-findings/  code-reviews/  support/  architecture/  archive/
    └── README.md
```

What stays with you: committing the backlog and the repositories' `AGENTS.md`, creating the backlog's remote repository, and, if the board is used, creating a PAT when the agent reaches `INIT.md` Step 7, then restarting the terminal and pasting the same message in a new session. Nothing needs to be prepared before the first message: the agent asks for everything in order and gives you each command with your values. `INIT.md` can be run again at any time; it only adds what is missing.

Setting up by hand follows the same `INIT.md`, step by step.

## Azure DevOps

`azure-devops.md` "Setup" has the PAT, the MCP server registration for Claude Code and Codex, the wrapper for a second organization on the same machine, and the troubleshooting list. `INIT.md` Step 7 walks through it with your values.

## Join an existing project

```powershell
git clone --recurse-submodules <backlog-url>
# or, after a plain clone:
git submodule update --init
```

Put the clone next to the code repositories, and copy `docs/agents/workspace-AGENTS.md` from it into the workspace folder as `AGENTS.md` (the workspace folder is not under version control; the backlog keeps that copy). Then set up the board (previous section) if you write to it. Running `INIT.md` in the workspace folder does all of this: it reports what is missing on your machine and fills it in.

## Update or change the module

Pushing this repository does not change any project. Each backlog pins the module to one exact commit, and the pin moves only when it is moved inside that backlog.

**Get the latest rules on your machine**, in the backlog folder of a project:

```powershell
git submodule update --remote .ai-workflow
```

Sessions in that project read the new rules immediately. `git status` in the backlog now shows `.ai-workflow` as modified; nothing else changed.

**Give the team the same version**, in the same folder, after the command above:

```powershell
git add .ai-workflow
git commit -m "Update ai-workflow"
git push
```

Teammates then pull the backlog and run `git submodule update --init` to check out the pinned commit.

**Every project at once**: `scripts/Update-AiWorkflow.ps1` searches a folder and all its subfolders for repositories with this module as a submodule, and in each one does both steps above (update, commit only the pin, push):

```powershell
.\scripts\Update-AiWorkflow.ps1 -Path C:\Code -WhatIf   # list the projects it would update
.\scripts\Update-AiWorkflow.ps1 -Path C:\Code            # update, commit and push
.\scripts\Update-AiWorkflow.ps1 -Path C:\Code -LocalOnly # only refresh this machine
```

It skips a project whose submodule has uncommitted changes or unpushed commits, and commits without pushing when the backlog branch is behind its upstream or already has other unpushed commits; the summary at the end says which and why.

**Change the rules** in a normal clone of this repository, commit and push there, then update every project (the two steps above, or the script).

**Change the rules from inside a project**, when a wrong rule shows up while working there. The submodule checkout is a detached HEAD, so a commit made there as-is hangs on no branch and is easy to lose. Put it on `main` first, then push from there and move the project's pin:

```powershell
cd <backlog>/.ai-workflow
git checkout main
git pull
# edit, then:
git add -A
git commit
git push
cd ..
git add .ai-workflow
git commit -m "Update ai-workflow"
git push
```

Every other clone and project is then refreshed as above.

- Committed before `git checkout main`: run `git branch rescue` at once so the commit is not lost, then `git checkout main` and `git cherry-pick rescue`.
- `git push` rejected: someone pushed in the meantime; `git pull --rebase`, then `git push` again.
- Pushing needs write access to this repository; without it, push to a fork and open a pull request.
- Keep the change generic (no project names, people or dates); anything specific to one project goes in that project's `AGENTS.md` or `docs/agents/decisions.md`.
- Until the change is pushed, `Update-AiWorkflow.ps1` skips that project rather than overwrite it.

## Check it works

In a fresh agent session in the backlog folder:

> Where does a new ticket go, which fields must it have, and what do you do before writing to the board?

Expected: `tickets/active/`, the fields from `backlog.md` with the labels from the profile, and "show the list and wait for confirmation" before any board write. In a fresh session in a code repository:

> You found a bug outside your task: where do you write it and do you commit?

Expected: the backlog path, and "the owner commits". The backlog is outside the repository, so Claude Code asks once per session for permission to read its files; allow it, or start the session with `claude --add-dir <path to the backlog>`.
