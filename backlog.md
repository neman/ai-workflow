# Backlog rules

Rules for the AI backlog: the folder, its own git repository, where agents and people keep implementation plans, actionable tickets (bugs, technical debt, refactoring), testing and code-review records, support cases and architecture notes for a project. Read this before creating, moving or changing any item in the backlog. Project values come from the **profile**: the `AGENTS.md` at the root of the backlog.

Labels are named here by their canonical English **concept** (`Source`, `Priority`, `Remaining`, …). The profile's field map gives the label actually written in items; where a rule says "the `Source` label", write the mapped label. `Status` and its values are canonical and are never mapped, because the listing below depends on them.

## Profile

The backlog `AGENTS.md` carries:

- `Who works here`: people who run sessions here. The **owner** is the person running the session.
- `Language`: the language of items and board text.
- `Field map`: a table `Concept | Label`, or the sentence "labels are the canonical English names".
- `Board`: `Tracker`, `Organization`, `Project`, `MCP server`, `Work item types` (the hierarchy, top down), `Acceptance criteria field` (or `none`), `QA tests from the board: yes|no`. Board writes follow `azure-devops.md` when the tracker is Azure DevOps.
- `Domain docs`: where the glossary and architecture decisions live, and the glossary's language rules.
- `Decisions`: the file that records the dated history behind these rules for this project.
- `Spec-driven changes`: `OpenSpec store <id>` when the project may plan work as OpenSpec changes kept in this backlog, beside plans (`openspec.md`), or `none`.

### Concepts the field map covers

Every label the module writes into items, so a non-English profile can map each one:

- item fields: `Source`, `Discovered in`, `Priority`, `Pre-existing`, `Type`, `Blocked by`, `Answer`, `Files`, `Application ticket`, `Support case`, `Related`
- plan blocks: `Remaining`, `Updated`, `Nothing left`, `Owner`, `Waiting outside`, `Next (agent)`, `Board`, `Code review`, `Dropped`
- review blocks: `Closing`
- board text (`azure-devops.md`): `User story`, `For testing`, `PBI criteria`, `Additional checks`, `Feature scope`, `Test order`, `Out of scope`
- values: `user report` (a `Source` value)

## Folders

- `plans/active/`: approved work currently being implemented
- `plans/proposed/`: ideas and plans awaiting implementation
- `plans/completed/`: implemented plans kept for reference
- `tickets/active/`: open tickets (`proposed`, `planned`, `in-progress`, `blocked`): bugs, technical debt, refactoring opportunities, regardless of how they were found
- `tickets/completed/`: closed tickets (`completed`, `rejected`), kept as a permanent record
- `testing-findings/<session>/`: one folder per testing session: test plan, data queries, generated artifacts; findings from it are tickets
- `code-reviews/<review>/`: one folder per code review of a PR or branch: scope, method, findings, PR thread ids; findings that outlive the PR are tickets
- `support/active/<case>/`: open support cases, one folder per case with its fix script, requester reply and exported documents
- `support/resolved/<case>/`: closed support cases kept for reference
- `support/triage/<project>-<period>/`: email review packages with a message index and proposed classifications; cases and tickets are created only after owner review
- `architecture/`: architecture decisions (`architecture/adr/`), diagrams and system improvement notes
- `docs/<topic>/`: optional, created when needed: reference material the work relies on and no other folder holds, such as third-party or external API documentation, or the agent decision log (`docs/agents/`). Each topic opens with a `README.md` naming its source, the date and version taken, and what was left out and why. No secrets; large binaries (screenshots, installers, full exports) stay outside the backlog and the README says where.
- `archive/`: obsolete or superseded material
- `openspec/`: only with `Spec-driven changes: OpenSpec store <id>`: the project's OpenSpec changes and specs, ruled by `openspec.md`, not by this file

## Git (this folder)

The backlog is its own repository, not an application. Everything is committed and pushed straight to the default branch; there are no feature branches and no pull requests here, so never ask about a branch or suggest creating one. This is the one exception to the shared-branch reminder in `workspace.md`, which applies to the code repositories only.

Commits and pushes are still the owner's call: commit only when asked, and include only the files from the current work. Other sessions edit and commit the same files in parallel, so read `git diff --cached` before every commit; a file you edited may already be staged by another session.

The profile's `Backlog commits` field names the one standing exception. With `agent, for closing reviews` the agent commits and pushes the backlog itself after closing a review ([Code reviews](#code-reviews), "Closing"), with only the files that closing touched; with `owner`, the default, nothing is committed without being asked. A rejected push means someone pushed in the meantime: `git pull --rebase`, then push again; never force.

## Item status

Each ticket, plan, review and testing session carries one of:

- `proposed`: identified but not yet approved
- `planned`: implementation plan is agreed
- `in-progress`: implementation has started
- `blocked`: cannot continue without an external decision or dependency
- `completed`: implementation and verification are complete
- `rejected`: intentionally not planned for implementation

Support cases have their own statuses (see [Support cases](#support-cases)).

### How to write the status

Write the status in one of these two shapes, so the whole backlog can be listed mechanically:

```text
**Status:** `proposed` — optional note                 (findings, plans)
| Status | `proposed` — optional note |                (items with a header table)
```

The literal word `Status`, then the value in backticks. Nothing else counts: a status written as plain `Status: proposed`, or only in prose, is invisible to the listing and the item silently drops off the radar.

The overview of the backlog is derived from the items, never from a hand-maintained index (a hand-maintained one goes stale, and a stale index is worse than none):

```powershell
# every item and its status
Get-ChildItem -Recurse -Filter *.md -Exclude README.md,AGENTS.md | Where-Object { $_.FullName -notmatch '[\\/](\.ai-workflow|openspec)[\\/]' } |
  Select-String -Pattern '(?<=^\|\s*Status\s*\|\s*|^-?\s*\*\*Status:\*\*\s*)`[a-z-]+`' -AllMatches |
  ForEach-Object { [PSCustomObject]@{ Status = ($_.Matches[0].Value -replace '`',''); Item = (Resolve-Path -Relative $_.Path) } } |
  Sort-Object Status, Item | Format-Table -AutoSize -Wrap

# anything still open inside an item
Get-ChildItem -Recurse -Filter *.md | Where-Object { $_.FullName -notmatch '[\\/]\.ai-workflow[\\/]' } | Select-String -Pattern '^\s*- \[ \]'
```

Run it from the backlog root. The `Where-Object` filter skips `.ai-workflow/`, where this file shows the status shape and would otherwise appear in the listing, and `openspec/` in the status listing, since OpenSpec changes carry no `Status` line and are listed by `openspec list` (`openspec.md` "Status"); their open `- [ ]` boxes still count as open work.

An item is done when its status is `completed` **and** it has no open `- [ ]` checkboxes left; only then does a ticket move to `tickets/completed/`. A support case is done when its status is `resolved` or `rejected` and it has no open checkboxes left.

## Tickets

A ticket is the **what and why** of one piece of work: problem, evidence, acceptance criteria. It is a permanent record: when the work is done its status becomes `completed` and the file moves to `tickets/completed/`.

### Source lives in the item, not in the folder name

Tickets from every origin — a plan, a testing session, a code review, a user report, a manual finding — share one `tickets/` folder. Each item names its origin in its `Source` / `Discovered in` field. Splitting tickets by origin into separate folders makes the same finding get written up twice and one problem get split across folders; categories mix freely anyway, since a code-review finding is often a plain bug and a debt item often carries a crash risk.

**Before adding a ticket, grep `tickets/` for the file path or symbol it is about.** A ticket that already covers the code you are writing up is extended, not duplicated.

### Open and closed tickets

`tickets/` is split by **state**, so what is done and what is not is visible at a glance. The folder follows the `Status` field:

- `tickets/active/`: `proposed`, `planned`, `in-progress`, `blocked`
- `tickets/completed/`: `completed`, `rejected`

A new ticket starts in `tickets/active/`. When its status becomes `completed` or `rejected`, move it to `tickets/completed/` **in the same edit**, together with its helper files, and fix every relative link to and from it: its links to sibling tickets become `../active/…`, and links from plans, findings and support cases gain the subfolder. Grep the whole backlog for the file name before moving. A ticket that is reopened moves back to `tickets/active/`.

The `Status` field is the source of truth; the folder is a view of it. If the two disagree, the status wins and the file is in the wrong folder.

### One topic per folder

A folder holds files about one topic only. When a topic grows past a single file — a ticket with its review findings, a plan per delivery, a Word or PDF source — give it a subfolder named after the topic and put all of its files there, in `tickets/active/<topic>/` and `plans/proposed/<topic>/`. Leave no such files loose among unrelated ones.

A topic subfolder moves as a unit through states: when the topic's tickets close, move the files to `tickets/completed/<topic>/`, with relative links adjusted. The status listing is recursive, so subfolders need no extra handling.

Notes that belong to one ticket (for example drafts of board items) go into that ticket as a section, not into a new file.

A topic folder may carry its own `AGENTS.md` with rules for that topic: which branch is the base, what to read before a code review, which branches are open. **Before working on a topic, look for an `AGENTS.md` in its folder and read it**; it adds to this file and wins where it is more specific.

### PBI, user story and board drafts live in one place

On the board a PBI **is** the user story, so a ticket never carries both. Write one section per PBI, named `## PBI N (workItemId): title` (`## PBI N: title` until it is entered on the board), and put in it, in this order: the user story (in the `User story` shape of the profile's language), the acceptance criteria as `- [ ]` checkboxes, then the text of each Task (frontend / backend) under it. The criteria are written once, in the wording that goes to the board; a separate "user stories" list and a second "drafts for the board" list of the same content drift apart. A ticket with several PBIs opens with a table of work items (type, id, delivery) and carries the Feature description in its own section. A PBI that is dropped keeps its section marked `Dropped`, with the reason, and its bullets are plain (not `- [ ]`) so they do not show up as open work. Other items refer to a PBI by its number in the ticket (`PBI 3`), not by "User Story 3".

File names are descriptive kebab-case with no numeric prefix: numbering a ticket folder invites renumbering and says nothing. The board's work item id is the only identifier worth carrying.

## Tickets vs plans

A ticket and a plan are different artifacts and both can exist for the same work:

- the ticket (`tickets/`) is the **what and why**: problem, evidence, acceptance criteria;
- the plan (`plans/`) is the **how**: steps, checkpoints, order of work.

**A ticket does not automatically become a plan.** Write a plan only when the work is big enough to need steps: several files, an open business question, or a dependency on other work. For a small item, do it and set the status to `completed`; a plan for a one-line change is pure ceremony.

When a plan is written, it links back to the ticket instead of restating the problem, and the ticket links to the plan. On completion the plan moves to `plans/completed/` and the ticket becomes `completed` and moves to `tickets/completed/`.

Priority order for what to work on next is derived from `Priority`, whether the defect is pre-existing (`Pre-existing`) and dependencies between items, read across `tickets/` and `plans/` together. Neither folder is a priority queue.

With `Spec-driven changes: OpenSpec store <id>` in the profile, the *how* of a piece of work may also be an OpenSpec change in `openspec/changes/` instead of a file in `plans/`: one or the other per piece of work, chosen by the owner, never both. The ticket rules above apply either way; `openspec.md` says when a change fits and how it relates to tickets and the board.

### Every plan opens with `Remaining`

A plan grows long — steps, full code blocks, findings — and the answer to "what is still left?" ends up spread across a thousand lines of checkboxes. So every plan carries, **directly under its header and status**, a short `## Remaining` section (mapped label) that answers exactly that question on one screen:

```markdown
## Remaining

_Updated: <date>._

- **Owner:** commit Task 6; push and PR for the ticket — note in the description that functional tests were run locally
- **Waiting outside:** nightly run on the release branch after the merge
- **Next (agent):** close the ticket, move the plan to `plans/completed/`
```

- **Update it in the same edit that changes a step's state**: ticking a step, adding a finding that creates new work, a decision that removes work. A stale `Remaining` is worse than none.
- **Plain bullets, not checkboxes.** The steps below already carry the `- [ ]` boxes; repeating them as checkboxes makes the "anything still open" listing count every item twice.
- **Group by who or what the item waits on**: the owner (commit, PR, a decision), something external (pipeline, business, another team), or the next step for the implementer. One line per item; the detail stays in the step it points to.
- **Keep the date line** (`Updated`, mapped) so it is obvious how old the answer is.
- When nothing is left, write the `Nothing left` line of the profile's language before moving the plan.

### Task numbers stay fixed once they are on the board

When the work items of a plan are entered on the board, each board Task refers to a plan Task by its number ("In the plan: Task 4"), and the board is expensive to change. So after the mapping exists, **the numbering of the plan's Tasks does not change** for as long as the work lasts:

- Never renumber, reorder or insert Tasks in the middle. New work goes at the end as the next number, or as a sub-step inside an existing Task (and the board Task text says which part of the plan Task it covers).
- When a board Task covers only part of a plan Task, say so in both places (the board draft in the ticket and the plan Task) instead of splitting the plan Task into two numbers.
- A Task that turns out to be unnecessary keeps its number and is marked `Dropped` with the reason.
- The mapping line of the plan (`Board:`) is updated in the same edit as any board number that is entered or changed.

The same applies to the numbering of PBIs inside a ticket (`PBI 3`): numbers and letters used in references do not change after they are entered.

## Testing sessions

`testing-findings/` is organised by **session**, not by item: each folder is the record of one testing session — test plan, data queries, generated documents, helper scripts and a `README.md` index.

Every finding that is work — it has a problem, a proposed fix or acceptance criteria — goes to `tickets/active/` **when it is written**, not later. It records the session in `Source` / `Discovered in`, and the session's `README.md` links to it. The session keeps only the observation in its test plan (what was run and what came out), never a second copy of the ticket. A finding left inside a finished session keeps the session looking open and puts ticket status in two places.

The session `README.md` links tickets but does not copy their status or priority; those change in the ticket and a copy goes stale.

A session is done when both hold:

- its test plan has status `completed` and no open `- [ ]` checks: every check is ticked, marked not applicable with a reason, or moved out into a ticket;
- every finding from it is a ticket in `tickets/` (or was rejected in the test plan with a reason).

After that the session folder is a closed record of evidence and is not edited except to fix links. Whether its tickets are resolved does not matter; that is visible in `tickets/`.

## Code reviews

A code review of a PR or a branch goes to `code-reviews/<repo>-pr-<id>-<slug>/` (or `code-reviews/<repo>-<branch-slug>/` when there is no PR yet), in a file named after the folder. It is organised by **session**, like `testing-findings/`: the record says what was reviewed (source and target commits, branches), how (read in code, executed, queried), what was found, which findings were posted to the PR and in which threads, and what was rejected after a second look. It closes when the PR is merged or abandoned, which makes it a different kind of item from a ticket: a ticket's life is the work, a review's life is the PR.

- The review file carries the `Status` (`in-progress` while threads are open, `completed` when the PR is merged and every thread is resolved, `rejected` when the PR is abandoned) and the thread ids of every comment posted. A review that was only written up, not posted, says so.
- A finding that outlives the PR — a pre-existing defect (`Pre-existing`), a follow-up the author will not do in this PR, a debt item — is a ticket in `tickets/active/` **when it is written**, with `Source` pointing to the review folder; the review keeps a one-line pointer to it. Findings the PR author fixes in the PR stay in the review only.
- A review of a branch that belongs to an epic with its own plan may stay as a `Code review` section in that plan; do not duplicate it in `code-reviews/`. A standalone review never lives in `tickets/`.

### Closing

A review is closed by the agent, not left to the owner to ask for. At the start of every session in the backlog, and whenever the owner asks, list the reviews whose `Status` is `in-progress` and read each one's PR (`azure-devops.md` "Reading a pull request"). A PR that is still active is left alone and not mentioned. For a merged or abandoned one, in this order:

- `Status` becomes `completed` (merged) or `rejected` (abandoned), with the date, the merge commit, who approved and who merged, and the state of every thread the review posted. A thread still `active` on a merged PR is named in the status line; the agent does not resolve it.
- A `## Closing` section (label from the profile's field map) says how the PR ended, whether every condition the findings stated holds (a companion PR merged, a release order kept) and which findings outlive the PR. Each of those is a ticket by the rule above; one that has no ticket yet gets it now, and the review gets the pointer.
- Every ticket and plan that names the PR gets the merge recorded (date, merge commit) and its checkbox for the PR ticked. Merging does not complete a ticket: that follows [Item status](#item-status).
- When the profile's `Backlog commits` allows it, commit only those files and push ([Git](#git-this-folder)); otherwise leave them in the working tree and say so.

The steps are a checklist in `skills/close-review.md`, written so that a subagent on a cheaper model can run them. Its report names the open threads, the unmet conditions and the findings that outlive the PR; the main session reads that report before the push, since those three are the only judgment in the task.

## Support cases

A support case is a concrete request from support or a user about **specific data or a specific document** — an order with surplus pieces, a purchase entered with the wrong price — that needs a manual intervention (a script against a production database, a regenerated document) and an answer back to the requester. It lives in `support/`, not in `tickets/`.

Never send email. Prepare a draft reply for the owner to review and send; the draft is a file in the case folder.

### Case vs ticket

A case and a ticket answer different questions and usually both exist:

- the **case** (`support/`) is the one-off fix: what was reported, what was found in the database, the script, the reply to the requester and the checklist until the data is correct. It closes when the data is fixed and the requester has been answered.
- the **ticket** (`tickets/`) is the defect in the application that made the manual fix necessary, for example "a completed order cannot be corrected". It stays open after the case is resolved.

The case links to the ticket (`Application ticket`) and the ticket links back to the case in its `Source` or `Support case` row. Describe the application defect in the case in one sentence at most, and keep incident data, scripts and requester replies out of the ticket.

A user report that needs only a code change — no data fix and no one-off answer — is a plain ticket with `Source: user report` (mapped value); it does not get a case.

### Layout

One folder per case, named after the case in kebab-case with the business identifier in the name. Inside it:

- `<case-folder-name>.md`: the case itself, carrying the status. Not `README.md` or `AGENTS.md`: the status listing skips those files.
- helper files: SQL fix script, instructions for support, requester reply, exported documents. Files already handed to support or a requester **keep the name they were delivered under**, so the requester and the backlog refer to the same file; list them in a `Files` table in the case.
- only the case file carries a `Status`; helper `.md` files link to the case instead, so a case shows up once in the listing.

When a case moves to `resolved` or `rejected`, move its folder from `support/active/` to `support/resolved/` in the same edit and fix relative links (the case, its helper files and the linked ticket).

### Case status

Cases use their own statuses, written in the same ``| Status | `...` |`` shape so the listing picks them up:

- `in-progress`: being investigated, or the fix is being prepared or tested
- `waiting`: blocked on the requester or on someone outside IT — a confirmation, an answer to the reply, a run of the script in production; the note says who
- `resolved`: data fixed and verified, requester answered
- `rejected`: no fix needed or the requester withdrew the request; the note says why

### Case contents

Each case includes:

- date of the request and who sent it (role or name as written in the request)
- database or environment affected, and which copy the analysis was run on
- the request, in the requester's terms
- what was verified in the database by queries, separated from what was only read in code
- the fix: script, what it changes, how it guards against unexpected state, and where it was tested
- a checklist until done: confirmations from the requester, production run, check in the application
- the reply to the requester, in plain language without technical details, if one is sent
- link to the ticket for the application defect, if there is one

## Email triage

Use `support/triage/<project>-<period>/` for review artifacts prepared from email, such as a spreadsheet message index and a Markdown decision summary. A triage folder is a review record, not a support case or an application ticket. Create case and ticket items only after the owner has reviewed the proposed classification and scope.

- Record the mailbox/search scope, sender or domain filter, date range, time zone, search date, and count of messages returned. State whether the end date is inclusive.
- Keep an index row for every in-scope message: received date, sender, subject, short excerpt, preliminary category, and a link back to the original message.
- Separate strict support (a defect, failed existing operation, incorrect existing data or document, or concrete correction to an existing record) from new functionality, long project discussions, general process questions, and other mail. Put unclear items in a manual-triage category instead of silently dropping them.
- Group messages by the underlying issue, using the described behavior, business identifiers, environment, affected record, participants, and chronology. Never merge messages on subject alone; split unrelated issues that share a subject and split distinct problems raised in one thread.
- For every support candidate, record the original report date and link to the first report. If the original date cannot be established because the search starts later or the earlier message is missing, write `unknown` and explain the limit. Also record the earliest relevant message found in the searched period so the evidence remains traceable.
- Assign temporary review numbers in chronological order by original report date, oldest first. When dates tie, use the time of the first report; if the date is unknown, place the item after dated cases and keep it visibly marked as unknown. Re-number the review list when a date changes. Never use these temporary numbers in support-case folder names or ticket filenames.
- Search the organization's sent mail and the thread for replies up to the stated search date. Match responses by issue details and identifiers, not by subject alone. Record response date, sender, link, and the substance of the reply when found; explicitly say when no response was found.
- Keep separate states for unanswered, answered and awaiting information, workaround applied, fix announced or deployed, and resolution confirmed by the requester. A sent answer or promised fix is not proof that the issue was resolved. State what is confirmed by the emails and what remains unverified.
- Preserve source links for both the first report and relevant replies. Keep unrelated thread content out of an issue summary. Make each candidate understandable without relying on the chat.
- Before creating a case or ticket from an approved candidate, follow the item rules above, check existing backlog items for duplicates, and link the new item to its source messages.

## Recommended item contents

Each new item includes:

- date created or discovered
- affected project or repository
- `Source`: plan, testing session, code review, user report, or manual finding
- problem description
- proposed solution
- `Priority`
- acceptance criteria
- `Status`
- links to related code, issues, pull requests, or test results

Use descriptive kebab-case file names, for example:

```text
plans/proposed/add-feature-build-version-check.md
tickets/active/missing-authorization-check.md
testing-findings/feature-login-timeout/test-plan-feature-login-timeout.md
support/active/surplus-pieces-order-00011/surplus-pieces-order-00011.md
```
