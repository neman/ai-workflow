# INIT: set up or check a workspace

Instructions for an agent (Claude Code or Codex) asked to set up a workspace folder for this module, or to check one that already uses it. The workspace is the folder that holds a project's code repositories side by side; it is usually not a git repository itself. Module address: `https://github.com/neman/ai-workflow`.

Idempotent: every step first checks whether its result already exists and then skips it, so running this on a finished workspace changes nothing. Never commit, push, or create remote repositories; those stay with the person.

Run every step in order. Ask questions through the interactive choice tool, recommended option first; it takes at most four questions per call, so a larger round is two consecutive calls.

## Step 1: Survey

Collect, from the workspace folder:

- code repositories: every direct subfolder that contains `.git`;
- the workspace `AGENTS.md`: exists or missing;
- the backlog: a subfolder that contains `.ai-workflow/` (if several, stop and ask which); if none, note the candidate name `ai-backlog`;
- inside the backlog, if found: `.ai-workflow/backlog.md` present and non-empty (an empty `.ai-workflow/` means the submodule is not initialised), `AGENTS.md`, `docs/agents/decisions.md`, the folders from `backlog.md` "Folders";
- each code repository's `AGENTS.md`: missing, or present with / without the line `Read ../AGENTS.md before starting.` as its first line;
- loose Markdown files in the workspace folder (for example `*findings*.md`, `*notes*.md`): candidates for the backlog;
- remote branches of each repository (`git -C <repo> branch -r`), to propose shared branches and to check the names against `.ai-workflow/workspace.md` "Branches".

Print the survey as a table `Item | Status (exists / missing / partial)`. Everything marked `exists` is skipped below.

## Step 2: Questions

Ask only what the survey did not answer. On a workspace that already has both profiles, every answer comes from them and nothing is asked. Defaults in parentheses are the recommended option.

1. Backlog folder name (`ai-backlog`, or the existing one).
2. Who works here: names of the people who run agent sessions.
3. Language of backlog items and board text (English).
4. Shared branches: `main`, `dev`, `release/*` (the default from `workspace.md` "Branches"), adjusted from the surveyed remote branches.
5. Branch naming deviations: list the surveyed remote branches that do not match the convention in `workspace.md` "Branches", and ask whether each is a legacy branch to record under `## Conventions` or a stale branch to ignore. The convention itself is not asked; it is the same in every project.
6. Tracker: Azure DevOps or none. If Azure DevOps: organization, project, server name (`azure-devops` for the first organization on this machine, `azure-devops-<org>` for further ones), environment variable name (`PERSONAL_ACCESS_TOKEN` for the first, `ADO_PAT_<ORG>` for further ones), and whether QA tests from the board (`yes` / `no` / `TBD`).
7. For each loose Markdown file from the survey: move it into the backlog as ticket(s), or leave it.

## Step 3: Backlog

Skip each item that exists.

```powershell
New-Item -ItemType Directory <backlog>
git -C <backlog> init
git -C <backlog> submodule add https://github.com/neman/ai-workflow .ai-workflow
```

If `.ai-workflow/` exists but is empty: `git -C <backlog> submodule update --init`.

Then, inside `<backlog>`:

- the folders from `.ai-workflow/backlog.md` "Folders", each with an empty `.gitkeep`: `plans/active`, `plans/proposed`, `plans/completed`, `tickets/active`, `tickets/completed`, `testing-findings`, `code-reviews`, `support/active`, `support/resolved`, `support/triage`, `architecture/adr`, `archive`;
- `docs/agents/decisions.md` with the single heading `# Decisions and rule history` and one sentence: dated events that led to a rule, newest first;
- `AGENTS.md` from `.ai-workflow/templates/backlog-AGENTS.md`, every `<…>` filled from Step 2 (`TBD` allowed). When the language is English, the Field map body is the sentence "Labels are the canonical English names."; otherwise one row per concept from `backlog.md` "Concepts the field map covers", asked from the person in one round;
- `README.md` with two sentences: what the folder is, and `git clone --recurse-submodules` (or `git submodule update --init` after a plain clone), plus a pointer to `.ai-workflow/README.md`;
- `.gitignore` only if the person names files to exclude.

Claude Code reads `AGENTS.md` directly. If, in Step 8, a fresh session does not report the file as loaded, add `CLAUDE.md` containing the single line `@AGENTS.md`.

## Step 4: Workspace `AGENTS.md`

The workspace folder is not under version control, so the backlog keeps a copy of this file at `<backlog>/docs/agents/workspace-AGENTS.md`; that copy is how a second person or machine gets the same profile.

Missing: when the copy exists, create the workspace `AGENTS.md` from it. Otherwise create it from `.ai-workflow/templates/workspace-AGENTS.md` with `<backlog>` replaced by the backlog folder name and the Profile filled from Step 2; put the branch naming deviations from Step 2 under `## Conventions`, or delete that section when there are none.

Existing: do not overwrite it. Compare it with the template, list what the template has and the file lacks (the pointer line, missing Profile fields), propose the addition and apply it only after the person confirms.

In both cases, end with the copy identical to the workspace file: create or refresh `<backlog>/docs/agents/workspace-AGENTS.md`.

## Step 5: Code repositories

Show the list of repositories whose `AGENTS.md` lacks the line, and wait for confirmation: these files are under version control and the whole team sees them.

After confirmation, for each listed repository: insert `Read ../AGENTS.md before starting.` followed by a blank line as the first line of `AGENTS.md`, or create `AGENTS.md` with only that line when the file is missing. Report which branch each repository is on.

## Step 6: Existing findings

For each loose file the person chose to move in Step 2: read it, write one ticket per distinct problem in `<backlog>/tickets/active/` following `backlog.md` (language and labels from the profile; `Source`: manual finding, naming the file and its date), move the original to `<backlog>/archive/`, and list the tickets created.

## Step 7: Azure DevOps

Only when the tracker is Azure DevOps.

1. `claude mcp get <server-name>`. When it is not registered: walk the person through `.ai-workflow/azure-devops.md` "Setup", with the values from Step 2 substituted into every command. Say explicitly when the terminal must be restarted and that the rest of this step continues in a new session. When Codex is installed (`codex --version`), also check that `~/.codex/config.toml` has the server with `env_vars` as in "Setup"; add it when missing.
2. When the server answers (list projects through it, or `Invoke-WebRequest` from the Setup check returns `200`), and only while `Work item types` or `Acceptance criteria field` in the backlog profile's `Board` section is `TBD` or missing: read the project's process template and work item types (`GET https://dev.azure.com/<organization>/_apis/work/processes?api-version=7.1` and the process's work item types, or the server's project tools), find the acceptance criteria field, and fill both. Put the exact registration command used, with values, under `## Project notes` when it is not there yet.

## Step 8: Verify

All of the following must hold; fix what does not and re-check:

- `<backlog>/.ai-workflow/backlog.md` exists and is not empty;
- every relative link and path in the workspace `AGENTS.md` and the backlog `AGENTS.md` resolves to an existing file or folder;
- no `<…>` placeholder is left in either `AGENTS.md` (`TBD` is allowed);
- `<backlog>/docs/agents/workspace-AGENTS.md` is identical to the workspace `AGENTS.md`;
- every code repository's `AGENTS.md` starts with the pointer line (unless the person declined in Step 5; say so in the report);
- the status listing from `backlog.md` "Item status" runs without error in `<backlog>`;
- a fresh agent session in `<backlog>`, asked "Where does a new ticket go, which fields must it have, and what do you do before writing to the board?", answers from `backlog.md` and the profile. In a fresh session in one code repository, "You found a bug outside your task: where do you write it and do you commit?" is answered with the backlog path and "the owner commits".

## Step 9: Report

Three lists:

- **Created or changed**: every file, by path.
- **Skipped, already present**: every survey item that was `exists`.
- **For the person**: commit the backlog (`git -C <backlog> add -A` then commit) and the code repositories' `AGENTS.md` on a branch of their choosing, merged into every long-lived branch (`main`, `dev`, `release/*`) so that no checkout is without the pointer; create the backlog's remote repository and add it (`git remote add origin …`); create the PAT and restart the terminal, if Step 7 asked for it; run the two Step 8 questions themselves once.
