# Spec-driven changes with OpenSpec

Rules for a project whose backlog profile says `Spec-driven changes: OpenSpec store <id>`. [OpenSpec](https://github.com/Fission-AI/OpenSpec) is a CLI plus agent skills (`/opsx:explore`, `/opsx:propose`, `/opsx:apply`, `/opsx:archive`) that plan a piece of work as a **change** — `proposal.md` (why and what), `specs/` (behaviour the system must have), `design.md` (how), `tasks.md` (steps) — and keep the project's durable **specs** once a change is archived. Using it is optional: with `Spec-driven changes: none` nothing here applies and plans stay in `plans/`.

OpenSpec changes nothing in the rest of this module. It adds a second shape for one artifact: the *how* of a piece of work is either a plan in `plans/` or an OpenSpec change, never both. Tickets, the board, reviews, support and the status listing are as `backlog.md` and `azure-devops.md` say.

## Plan or change: decided per piece of work

The profile's `OpenSpec store <id>` makes OpenSpec available, not mandatory. Each piece of work gets one of the two:

- **An OpenSpec change** when the owner starts it with `/opsx:explore` or `/opsx:propose`, or asks for one. It fits work whose behaviour is worth a spec: a new capability, a contract with another system, work that spans repositories, work that will be built on later.
- **A plan in `plans/`** otherwise: a fix with steps, a refactor, a delivery inside an existing epic that already has a plan. The plan rules of `backlog.md` apply unchanged.

The agent proposes the shape when the work is big enough to need one (`backlog.md` "Tickets vs plans"), with the recommended option first, and never converts one into the other on its own. The decision is recorded where the work is written up: the ticket links to the plan or to the change (`openspec/changes/<name>/`), and a plan that belongs to an epic lists the changes of that epic under its `Board` line. Both shapes end the same way: the plan moves to `plans/completed/`, the change is archived.

## Where the files live

The backlog is the project's OpenSpec **store** (an OpenSpec root in its own repository, shared by all code repositories). Code repositories hold no planning files.

```text
<backlog>/
├── .openspec-store/store.yaml     ← the store's identity (written by `openspec store register`)
└── openspec/
    ├── config.yaml                ← schema, `context` (language, constraints), `rules`
    ├── specs/<capability>/spec.md ← durable specs, filled by archiving changes
    └── changes/<change>/          ← proposal.md, specs/, design.md, tasks.md
        └── archive/               ← archived changes

<repo>/
├── openspec/config.yaml           ← one line: `store: <id>`, nothing else
└── .claude/skills/openspec-*, .claude/commands/opsx/   ← skill files from `openspec init`
```

A code repository never gets `openspec/specs/` or `openspec/changes/`: when they exist, OpenSpec uses them and ignores the `store:` line, and the planning silently splits in two. The skill files are plain Markdown installed by the CLI; they are committed like any repository file so every checkout has the commands.

## Setup

Per machine (each person, each clone):

```powershell
openspec store register "<path to backlog>" --id <id>
openspec doctor
```

Per code repository, once, on the mainline branch: write `<repo>/openspec/config.yaml` with the single line `store: <id>`, then install the skill files from the repository root (`openspec init --tools claude`, add `codex` when Codex is used). After a CLI upgrade, `openspec update` in each repository and in the backlog refreshes them; the backlog keeps its own copy of the skill files so a session started in the backlog folder has the commands too.

`openspec/config.yaml` in the backlog carries the project's constraints for the artifacts: `context` says the profile's language and what an agent cannot read from the code; `rules` per artifact. Spec keywords (`SHALL`, `MUST`, `WHEN`, `THEN`) stay English whatever the language: the validator reads them.

## A change, a ticket and a plan

- A **change** is the plan of one piece of work. Work that has a change gets no file in `plans/`; when a plan written earlier is replaced by a change, the owner says so, and the plan moves to `plans/completed/` with a pointer to the change.
- A **ticket** stays what it is: the what and why of a finding, the PBI sections and board drafts (`backlog.md` "PBI, user story and board drafts live in one place"). Work that starts from a request rather than a finding needs no ticket: `proposal.md` is its why. Write a ticket beside the change when there are findings to record or when QA tests from the board and the PBI criteria must live outside the change.
- A change may span several repositories: `tasks.md` groups the tasks by repository, and each group names its repository. Branches follow `workspace.md` "Branches", one per board item.

### `tasks.md` carries the board mapping

Directly under the title of `tasks.md`, a `Board:` line (mapped label) names the parent items, and a table maps task groups to board items:

```markdown
Board: Epic #<id>, Feature #<id>.

| Task groups | Board item |
|---|---|
| 1 | #<id> <title> |
| 2, 3 | #<id> <title> |
```

Board ids are written back here after the items are created (`azure-devops.md` "Entering items"). From then on the numbering of the task groups does not change, for the same reason as plan Tasks (`backlog.md` "Task numbers stay fixed once they are on the board"): new work goes at the end as the next group, dropped work keeps its number and is marked `Dropped`.

## Status

A change carries no `Status` line; its state is the file-existence status `openspec status --change <name>` reports, and `openspec list` is the listing of changes in flight, as `tickets/` and `plans/` are listed by the status script. The backlog status script skips `openspec/`. Open `- [ ]` boxes in `tasks.md` are open work and show up in the "anything still open" listing like a plan's steps.

Archive a change (`/opsx:archive`) only when the owner asks, after the work is merged: archiving moves the change under `openspec/changes/archive/` and merges its delta specs into `openspec/specs/`, the equivalent of moving a plan to `plans/completed/`. `openspec/specs/` is the project's description of what it already does; it grows only through archived changes and is never written by hand to document existing behaviour upfront.

## Git

Changes and specs are files in the backlog and follow `backlog.md` "Git": the owner commits, straight to the default branch. OpenSpec never clones, pulls or pushes a store; a change exists on other machines only after the backlog is pushed and pulled, and the store is registered there.

## Limits

- Stores are a beta feature of OpenSpec: command names, flags and file formats may change between releases. Pin the CLI version in the profile's `Project notes` when it matters.
- One registration per store id per machine; a second clone of the backlog needs `openspec store unregister <id>` first.
- `openspec init` runs only from a repository root, and a repository with a `store:` line must have the store registered on that machine before the skills can resolve it.
