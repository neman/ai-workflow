# Issue tracker: AI backlog convention

Issues for this project are Markdown tickets in `tickets/` and plans in `plans/` of the backlog. `../backlog.md` is the authoritative source for folder layout, required contents, statuses and file naming; read it before creating or changing an item. The board (profile, `Board` section) holds the work items, written only through `../azure-devops.md` or the tracker's equivalent. Labels below are canonical concepts; write the label from the profile's field map.

## When a skill says "publish to the issue tracker"

- Grep `tickets/` for the file path or symbol first; extend an existing ticket instead of duplicating it.
- Create `tickets/active/<kebab-case-name>.md`, in the profile's language, with no numeric prefix. When a topic needs more than one file, give it a subfolder `tickets/active/<topic>/`.
- Include the contents `backlog.md` requires: date, affected project, `Source` / `Discovered in`, problem, proposed solution, `Priority`, acceptance criteria, and a `Status` in the backticked shape (``**Status:** `proposed` ``).
- Separate what was verified by execution from what was only read in code.
- A spec or multi-step work goes to `plans/proposed/<name>.md`. It opens with `Remaining` and links back to the ticket; the ticket links to the plan. Do not write a plan for a small change. When the profile says `Spec-driven changes: OpenSpec store <id>`, that work may instead be an OpenSpec change, chosen by the owner per piece of work (`../openspec.md` "Plan or change"); the ticket then links to the change.
- Several implementation issues for one feature are PBI sections inside one ticket (`## PBI N: title`), not one file per issue.

## When a skill says "fetch the relevant ticket"

Read the file at the path the user passes. Given a board work item id, grep `tickets/` and `plans/` for it; read it from the board through the MCP server only if no file has it.

## The board

A skill never writes to the board on its own. Show the owner the exact list (type, title, parent, area and iteration path), write only after the owner confirms that list, then write the returned work item ids back into the ticket or plan in the same session. `State`, closing and deleting follow `../azure-devops.md` "Entering items": people set them, not agents.

## Comments

Comments and conversation history go into a section of the ticket, never into a new file.

## Wayfinding operations

Used by `/wayfinder`.

- **Map**: a plan at `plans/proposed/<effort>/<effort>.md` (Notes / Decisions so far / Fog).
- **Child ticket**: `tickets/active/<effort>/<kebab-case-question>.md`, with the question in the body and a `Type` line (`research` / `prototype` / `grilling` / `task`).
- **Blocking**: a `Blocked by` line listing the files it waits on. A ticket is unblocked when every listed file has status `completed`.
- **Frontier**: tickets in `tickets/active/<effort>/` with status `proposed` or `planned` and no open blockers.
- **Claim**: set status `in-progress` and save before any work.
- **Resolve**: append the answer under `## Answer` (mapped), set status `completed`, add a gist and link to the map's Decisions so far, and move the ticket to `tickets/completed/<effort>/` as `backlog.md` requires.
