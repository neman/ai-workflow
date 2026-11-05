# AGENTS.md

If `.ai-workflow/` is empty, run `git submodule update --init` first. Before creating, moving or changing any item in this folder, read `.ai-workflow/backlog.md`. Before any board write, read `.ai-workflow/azure-devops.md`. Before creating or changing an OpenSpec change, read `.ai-workflow/openspec.md`.

## Profile

<!-- Fill every field; `TBD` is allowed where the answer is not known yet. -->

- Who works here: <names>
- Language: <language of items and board text>
- Board:
  - Tracker: <Azure DevOps | none>
  - Organization: <organization>
  - Project: <project>
  - MCP server: <server name registered with `claude mcp add`>, token in `<env-var>`
  - Work item types: <e.g. Epic → Feature → PBI → Task>
  - Acceptance criteria field: <e.g. `Microsoft.VSTS.Common.AcceptanceCriteria` | none>
  - QA tests from the board: <yes | no>
- Domain docs: <`CONTEXT.md` and `architecture/adr/`; language rules of the glossary when the language is not English>
- Decisions: `docs/agents/decisions.md`
- Backlog commits: <owner | agent, for closing reviews>
- Spec-driven changes: <OpenSpec store `<id>` | none>

## Field map

<!-- When Language is English, replace this section's body with: "Labels are the canonical English names." Otherwise one row per concept listed in `.ai-workflow/backlog.md`, "Concepts the field map covers", e.g. `| Source | Izvor |`. -->

| Concept | Label |
|---|---|

## Agent skills

- Issue tracker: `.ai-workflow/skills/issue-tracker.md`
- Triage labels: `.ai-workflow/skills/triage-labels.md`
- Domain docs: `.ai-workflow/skills/domain.md`
- Closing a review: `.ai-workflow/skills/close-review.md`

## Project notes

<!-- Project-specific rules that are not decisions history: the exact MCP registration command with values, environment quirks, anything `.ai-workflow/` cannot know. Keep it short; dated history goes to `docs/agents/decisions.md`. -->
