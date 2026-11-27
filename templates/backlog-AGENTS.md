# AGENTS.md

If `.ai-workflow/` is empty, run `git submodule update --init` first. Before creating, moving or changing any item in this folder, read `.ai-workflow/backlog.md`. Before reading or writing the board, a pull request or a pipeline, read `.ai-workflow/board.md` and the file of the tracker or code host (`.ai-workflow/azure-devops.md` for Azure DevOps, `.ai-workflow/github.md` for GitHub). Before creating or changing an OpenSpec change, read `.ai-workflow/openspec.md`.

## Profile

<!-- Fill every field; `TBD` is allowed where the answer is not known yet. -->

- Who works here: <names>
- Language: <language of items and board text>
- Board:
  - Tracker: <Azure DevOps | GitHub | none>
  <!-- The next four lines are the Azure DevOps fields (`.ai-workflow/azure-devops.md` "Setup"); for GitHub they are `Repository: <owner>/<repo>` and `Visibility: <public | private>` (`.ai-workflow/github.md` "Setup"). -->
  - Organization: <organization>
  - Project: <project>
  - MCP server: <server name registered with `claude mcp add`>, token in `<env-var>`
  - Pipelines: <yes | no> (the agent registers, configures and runs pipelines; `yes` needs the pipeline scopes on the PAT)
  - Work item types: <e.g. Epic → Feature → PBI → Task>
  - Acceptance criteria field: <e.g. `Microsoft.VSTS.Common.AcceptanceCriteria` | none>
  - QA tests from the board: <yes | no>
- Code host: <Azure DevOps | GitHub | none; with its own fields beneath when it is not the tracker>
- Domain docs: <`CONTEXT.md` and `architecture/adr/`; language rules of the glossary when the language is not English>
- Decisions: `docs/agents/decisions.md`
- Backlog commits: <owner | agent, for closing reviews>
- Spec-driven changes: <OpenSpec store `<id>` | none>
- Browser testing: <allowed environment addresses, account, actions left out, secrets file and key for headless runs | pointer to the project doc with them | none>

## Field map

<!-- When Language is English, replace this section's body with: "Labels are the canonical English names." Otherwise one row per concept listed in `.ai-workflow/backlog.md`, "Concepts the field map covers", e.g. `| Source | Izvor |`. -->

| Concept | Label |
|---|---|

## Agent skills

- Issue tracker: `.ai-workflow/skills/issue-tracker.md`
- Triage labels: `.ai-workflow/skills/triage-labels.md`
- Domain docs: `.ai-workflow/skills/domain.md`
- Closing a review: `.ai-workflow/skills/close-review.md`
- Release notes: `.ai-workflow/skills/release-notes.md`
- Browser testing: `.ai-workflow/skills/browser-testing.md`

## Project notes

<!-- Project-specific rules that are not decisions history: the exact MCP registration command with values, environment quirks, anything `.ai-workflow/` cannot know. Keep it short; dated history goes to `docs/agents/decisions.md`. -->
