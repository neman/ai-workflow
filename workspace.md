# Workspace rules

Rules for an agent working in any code repository of a project that keeps an AI backlog. Read this before the first change in a session. The project's own values (people, language, branches, repositories, backlog folder) are in the **profile**: the `AGENTS.md` at the top of the workspace, the folder that holds the code repositories and the backlog.

## Profile

The workspace `AGENTS.md` carries these fields; every rule below that says "from the profile" reads them there.

- `Who works here`: the people who run agent sessions in this workspace. The **owner** of a session is the person running it.
- `Language`: the language of backlog items and board text.
- `Shared branches`: branches that never receive direct commits (`main`, `dev`, `release/*` by default; see "Branches").
- `Repositories`: the code repositories under the workspace folder.
- `Backlog`: the relative path of the backlog folder (the one that contains `.ai-workflow/`).

## Session findings go to the backlog

Everything discovered during a session that is not the task itself — a bug, technical debt, a refactoring idea, an architecture note, a testing or code-review finding, a support case — goes **outside the code repository**, into the backlog folder from the profile. `<backlog>/.ai-workflow/backlog.md` is the authority for its layout, statuses, required contents and file names, and `<backlog>/AGENTS.md` (the backlog profile) gives the labels to write: read both before creating or changing an item there, and never restate their rules in a repository file.

The same holds for plans: a code repository holds no planning files. When the backlog profile says `Spec-driven changes: OpenSpec store <id>`, the repository carries only the OpenSpec pointer (`openspec/config.yaml` with `store: <id>`) and the `/opsx` skill files, and every change and spec is written in the backlog (`<backlog>/.ai-workflow/openspec.md`). Whether a piece of work is planned as a change or as a plan is the owner's choice per piece of work, made there.

Write findings in the profile's language. Each item stands on its own: the owner turns it into a board item later, without the conversation. Separate what was verified by running code from what was only read in code, and keep the priority of an unconfirmed finding low.

## Branches

The naming below is the default for every project. The workspace profile's `## Conventions` lists only what deviates from it, such as a legacy branch or a prefix the project uses differently, and wins wherever the two differ. With `Tracker: none` there is no id, and a work branch is `<type>/<slug>`.

- Shared branches: `main`, `dev` and `release/<version>`. They never receive direct commits.
- Every work branch belongs to a board work item: `<type>/<id>-<slug>`, for example `fix/1234-login-timeouts`. The type follows the work item type: Bug is `fix`; Product Backlog Item, User Story and Feature are `feature`; Task is `task`. The slug is a few lowercase words from the item's title, joined by hyphens.
- A branch without an id is an exception for an experiment, not a rule. The moment the experiment becomes work, the owner creates the work item and renames the branch to the id form, before any pull request.

A project can enforce the prefixes in its pull request validation build; the `<id>-<slug>` part stays the owner's discipline.

Agents never create or rename branches. When reminding the owner to branch off a shared branch, propose the name in this form; use the same form when finding or creating a pull request (`azure-devops.md` "Pull requests").

## Committing

Leave finished work in the working tree and tell the owner what changed and which files. The owner commits and pushes, on every branch, including feature branches. When the owner says "commit this" in passing, ask before running `git commit`.

Check the current branch at the start of the session. On a shared branch from the profile, say which branch it is and remind the owner to create a new one; creating it is the owner's call.

When the owner explicitly asks for a commit or a pull request, write the message without attribution lines (`Co-Authored-By`, "Generated with", or similar), whatever the tooling suggests.

A commit message, in every repository of the project including the backlog, follows git's own convention (`Documentation/SubmittingPatches`, "Describe your changes well"):

- a subject line of about 50 characters, capitalised, without a trailing period;
- a blank line, then a body in sentences that says what the problem was and why this change is the right way to solve it, including alternatives considered and rejected; not a list of the files touched;
- the imperative mood throughout, as if giving the codebase an order: "Make the login timeout configurable", not "Made …", "Makes …" or "This commit makes …";
- the board item named as `#<id>` in the body when the branch carries one.

## Questions to the owner

Every round of questions with options — grilling, brainstorming, any decision with alternatives — goes through the interactive choice tool (`AskUserQuestion` in Claude Code, the equivalent elsewhere): one entry per question, the recommended option first and marked `(Recommended)`. Facts and reasoning may precede the call as text; the questions themselves go into the tool. The tool takes at most four questions per call, so a larger round is two consecutive calls. This holds even when a skill prescribes a text format for its questions: typed answers to a numbered list are slow and get lost.

## Tests

Write business tests only: tests that check behavior a user can see. Cover a gap in the test harness with an assertion in a business test that fails because of the gap — for example, a document filed under the wrong year folder — rather than a test of the seeding or wiring itself.

## Markdown

Applies to every Markdown file written in the workspace, including backlog items.

- One blank line between sections; never two or more consecutive blank lines (`MD012`).
- Tables use the compact pipe style: no padding spaces around `|` (`MD060`).
