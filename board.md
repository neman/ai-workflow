# Board rules

Rules for a backlog whose profile names a tracker, whichever it is: what goes on the board, who confirms it and how board text is written. Read this before reading or writing the board or a pull request (work items, review threads, creating a pull request, posting review comments). How each write is carried out (setup, the token, the calls, field names and values) is in the file of the tracker or the code host, read together with this one: `azure-devops.md` for Azure DevOps, `github.md` for GitHub. Values marked `<…>` come from the profile's `Board` section.

## The tracker's file and the code host's file

The profile names two things. `Tracker` is where the board is. `Code host` is where the code repositories and their pull requests are; a profile without that line means the tracker holds both. Each one the module knows has a single file (`azure-devops.md`, `github.md`), and one file serves both roles when they are the same. Every such file carries the same section names, so a rule here or in another file can point at them without naming the product:

- `Setup`: what a person does once per machine so the agent can reach it, and which fields the profile carries for it.
- `Handling the token`: how a command or script may use the credential.
- `Pull requests`, with `Reading a pull request`, `Creating a pull request` and `Review comments`, read from the code host's file: the calls, and its own values for a pull request's state, approvals and threads.
- `Entering items`, read from the tracker's file: the calls and formats for work items, and what this tracker adds to the confirmation list.

A file for another tracker or code host is written from work in a real project that uses it, with these sections; it holds no rule that is already here. Until it exists the profile says `none` for that role, and that part of the work stays with the person.

## Entering items

Board items are entered by the agent, never copied by hand. `Work item types` in the profile gives the hierarchy (for example Epic → Feature → PBI → Task). The module's words for the levels stay the same whatever the tracker calls them: a **PBI** is the item that carries the user story, a **Feature** the item above it, a **Task** a piece of work under it.

- Titles and descriptions are in the profile's language, written for non-technical readers.
- A PBI description opens with the user story under the English label **`User story:`**; the story itself is in the profile's language, in its `User story` shape.
- Acceptance criteria go into the profile's `Acceptance criteria field` as a checkbox list (`- [ ] …`), not into the description; the tracker's file says in which format the field is written. When the profile says the field is `none`, the criteria are the last section of the description.
- Writing to the board is visible to the whole company. Before creating or changing items, show the owner the exact list: type, title, parent, and where the tracker places each item (the tracker's file names those fields). Write only after the owner confirms that list. A confirmation covers only that list.
- Before the first write in a project, check which work item types exist and which field holds the acceptance criteria. Record the answer in the profile's `Board` section.
- Create parents first (top of the hierarchy down) and link each child to its parent in the same run.
- After creating items, write the returned work item ids back where the draft lives: the ticket section `## PBI N (workItemId): title`, the plan's `Board:` line, or the task list of the change. Do this in the same session, before the numbers are lost.
- The state of a board item is set by people: never change it, and never delete or close a board item, unless the owner asks for that specific item. This holds after a merge too.

## Board, ticket and test plan carry the same criteria

Applies when the profile says `QA tests from the board: yes`. QA and the product owner test from the board, so a PBI must be testable from its board text alone.

- **PBI description:** the user story, one or two sentences of context with links as `#workItemId`, and a `For testing` note when the PBI needs setup or cannot be tested yet (frontend missing, depends on another PBI). Items are referred to only by `#workItemId`; links go to the board or the web, never to local files.
- **Acceptance criteria field:** one observable outcome per `- [ ]`, written for the tester: the exact on-screen texts (buttons, messages), how to trigger the case, example values. Verify every behavioural claim in the code before it goes in, and note in the ticket that it was read in code, not executed.
- **Three places, one text:** the criteria are word for word the same in the board field, the PBI section of the ticket, and a `PBI criteria <id>` block in the PBI's test plan section. Change all three in the same edit. Test-only checks (direct API calls, SQL, API client collections) go under `Additional checks` in the test plan. A test plan check that another PBI's criterion already covers becomes a plain-bullet pointer to it, so every check is ticked in one place.
- **Feature description:** `Feature scope` with one line per child (`- what it does - #id`), then `Test order` with a user story and a numbered list in test order, each line starting with `#id`, untestable children marked as such. Scope notes (`Out of scope`) stay in the ticket.
- **Known open defects** stay out of the PBI text. The test plan notes them beside the criterion as expected `[!]` with the fixing Task.
- **Before every board write**, re-read the item (revision, state, criteria): QA works in parallel. When QA has ticked a criterion or the PBI is in a testing or done state, leave its text as it is and add the clarification as a comment on the item. Mirror QA's ticks (`[X]` on the board) into the ticket and the test plan with who and when.

## QA tests through the application

Applies when the profile says `QA tests from the board: yes`. Board text names no people (not who prepares data, not who tests) and never sends the tester to the API, SQL or an API client. When a PBI needs data that only another PBI's screen can create, the `For testing` note names that PBI (`#id`) and the PBI is tested after it; the Feature's test order follows. API, SQL and client steps stay under `Additional checks` in the test plan.

## Pull requests

The calls are in the code host's file, under the same headings. Every other file of the module speaks of a pull request in the words below; the code host's file, "Reading a pull request", gives its own value for each:

- its state: `open`, `merged` or `closed without merging`;
- the merge commit, who merged it and when;
- an approval: who approved and when;
- a thread: `open` or `resolved`;
- a push: one update of the source branch after the pull request was opened.

- **One per branch.** Look for a pull request of the branch, in any state, before creating one.
- **Creating.** Only when the owner asks for it; the branch must already be pushed. Show the owner the source branch, the target branch and the title, and create the pull request after confirmation, linked to every board item the branch implements.
  - The source branch is named after the board item (`workspace.md` "Branches"); a branch without an id gets its work item and its name first. The target is the branch the work was cut from (`dev` or `main`, the profile's `Conventions` when they differ, or the integration branch of an epic from the topic's `AGENTS.md`).
  - Title and description in English, whatever the profile's language: a pull request belongs to the code, like branch names and commit messages. Written for non-technical readers, no attribution lines. The description says what changes for the user and names the board items as `#<id>`. It has no code, diffs, file trees, class, method or test names, test counts or pipeline steps; those belong in the commit messages and the repository's `docs/`. When a PR-writing skill or template asks for them (a diff sketch, a call tree, test evidence, a merge-risk section), this rule wins.
  - Record the pull request id where the work is written up (the ticket, the plan's `Board:` line or the review record).
- **Review comments.** When the owner asks for review comments on a pull request "in their name": read the existing threads first, so the same finding is not posted twice. Post only findings about the diff (`backlog.md` "Code reviews"): a finding in a file outside the pull request's changes, or about code it does not touch, goes to a ticket, not to a thread on the pull request as a whole. Comments are in the profile's language. Record the pull request and thread ids where the review is written up (the plan's `Code review` section, the review record or the ticket).
