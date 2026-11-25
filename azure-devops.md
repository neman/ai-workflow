# Azure DevOps board

Rules for a backlog whose profile says `Tracker: Azure DevOps`. Read this before reading or writing the board or a pull request (work items, review threads, creating a pull request, posting review comments) and before setting up the MCP server. Values marked `<…>` come from the profile's `Board` section or from the person setting things up.

## Setup

The agent uses Microsoft's Azure DevOps MCP server (`@azure-devops/mcp`, needs Node.js) with a personal access token (PAT). Interactive sign-in works only when the organization is connected to the Microsoft Entra directory that the signed-in account belongs to; an organization whose members sign in with personal accounts rejects it (`TF400813: … is not authorized`, or `invalid_scope`), and the Azure CLI token is rejected the same way. A PAT works in both cases, so it is the default.

1. Create a PAT at `https://dev.azure.com/<organization>/_usersSettings/tokens`, signed in with the account you use for the board. Tick exactly these scopes (custom defined):

   - [ ] **Work Items: Read & Write**: reading and entering board items through the MCP server.
   - [ ] **Project and Team: Read**: listing projects, teams and iterations; the server fails to start without it.
   - [ ] **Code: Read & Write**: pull requests through the REST API: creating them, posting review comments, linking work items. `Read` alone lists PRs but every write returns `401`.

   Anything else (Build, Release, Packaging) stays unticked until a rule here needs it. When a scope is added later, the token must be regenerated and stored again (step 2).
2. Store it Base64-encoded (`:<PAT>`) in a user environment variable, `<env-var>`. The name is `PERSONAL_ACCESS_TOKEN` for the first organization on this machine and `ADO_PAT_<ORG>` for every further one (`ADO_PAT_CONTOSO` for the organization `contoso`); the profile's `MCP server` line records which one the backlog uses. Either way below works; the script is the default because it refuses an empty or malformed paste.

   **With the script.** Run it from this module in PowerShell (5.1 or 7), with the variable name as its only argument. Nothing in the script is edited:

   ```powershell
   & "<backlog>\.ai-workflow\scripts\Set-AdoPat.ps1" -Name PERSONAL_ACCESS_TOKEN
   ```

   It stops at a `PAT for …:` prompt: paste the token there (nothing is echoed; use `Ctrl+V` or `Shift+Insert` if a right click pastes nothing) and press Enter. It confirms with `… stored (N characters)`, and refuses an empty paste or anything that is not a bare token, leaving the variable unchanged. Before the module is cloned, the same script runs straight from GitHub:

   ```powershell
   & ([scriptblock]::Create((Invoke-RestMethod https://raw.githubusercontent.com/neman/ai-workflow/main/scripts/Set-AdoPat.ps1))) -Name PERSONAL_ACCESS_TOKEN
   ```

   **Without the script.** The same three steps by hand in PowerShell, as one line so it pastes and runs at once: a hidden prompt, Base64 of `:<PAT>`, and a user-scope variable. Replace `PERSONAL_ACCESS_TOKEN` with the variable name:

   ```powershell
   $p = [Net.NetworkCredential]::new('', (Read-Host -AsSecureString 'PAT')).Password; [Environment]::SetEnvironmentVariable('PERSONAL_ACCESS_TOKEN', [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$p")), 'User'); Remove-Variable p
   ```

   Nothing checks the paste here: an empty Enter stores a 4-character value (Base64 of a bare colon), and the check in the notes below then returns `203`. Never set the variable through the Windows environment dialog with the raw token; it must be the Base64 form.

3. Register the server at user scope, so it works in every repository of the workspace and in the backlog. The server reads the token only from `PERSONAL_ACCESS_TOKEN`, so:

   - **First organization on this machine:** `<env-var>` is `PERSONAL_ACCESS_TOKEN` and the server is added directly:

     ```powershell
     claude mcp add <server-name> -s user -e ado_mcp_project="<project>" -- npx -y @azure-devops/mcp <organization> -d core work work-items -a pat
     ```

   - **Every further organization:** its PAT lives in its own variable (for example `ADO_PAT_<ORG>`), and a small wrapper renames it before starting the server. Save it as `%USERPROFILE%\.claude\mcp\<server-name>.cmd`:

     ```bat
     @echo off
     set PERSONAL_ACCESS_TOKEN=%<env-var>%
     npx -y @azure-devops/mcp <organization> -d core work work-items -a pat
     ```

     and register the wrapper:

     ```powershell
     claude mcp add <server-name> -s user -e ado_mcp_project="<project>" -- "%USERPROFILE%\.claude\mcp\<server-name>.cmd"
     ```

   For Codex, the same server goes into `~/.codex/config.toml`. Codex passes only a short allow-list of environment variables to an MCP server, so the token variable must be named in `env_vars`, otherwise the server starts without it and every call fails:

   ```toml
   [mcp_servers.<server-name>]
   command = "npx.cmd"   # or the wrapper path for a further organization
   args = ["-y", "@azure-devops/mcp", "<organization>", "-d", "core", "work", "work-items", "-a", "pat"]  # omit for the wrapper
   env = { ado_mcp_project = "<project>" }
   env_vars = ["<env-var>"]
   ```

   Check it with `codex mcp list` and one board read (list the projects) in a Codex session.

4. Close every terminal and agent window and start the agent from a new terminal. A new user environment variable is seen only by processes started after it was set; a session resumed from an old terminal starts the server without it, and the server exits with `Connection closed`.

Notes:

- `-d core work work-items` loads only the project and work item tools; `core` must stay in the list. Pull requests go through the scripts, not the `repositories` domain ("MCP or REST" below); add `pipelines` only when a rule needs it.
- Never put the PAT itself in `claude mcp add -e …`, in a config file, in the backlog or in a repository: that stores it in plain text. When it expires, repeat step 2 and step 4. How commands and scripts may use it is in "Handling the token" below.
- Check that the PAT works without the server (`200` = OK):

  ```powershell
  (Invoke-WebRequest "https://dev.azure.com/<organization>/_apis/projects?api-version=7.1" -Headers @{Authorization="Basic $([Environment]::GetEnvironmentVariable('<env-var>','User'))"}).StatusCode
  ```

### Troubleshooting

- `Cannot find module '../build/Release/keytar.node'` from `npx -y @azure-devops/mcp --help`: the native `keytar` module was not built during the first `npx` download. Run `npm rebuild keytar` in the `npx` cache folder named in the error (`%LOCALAPPDATA%\npm-cache\_npx\<hash>`), then check `--help` again.
- `Connection closed` right after start: the environment variable is not visible to this process; see step 4.
- The check in the notes above returns `203` instead of `200`: the request was not authenticated and Azure DevOps answered with its sign-in page. Either the variable holds an empty token (set by hand; its Base64 value is then 4 characters long), or the PAT belongs to another organization, has expired, or the account is not a member of this organization. Repeat step 2.
- If the organization is later connected to the company's Entra directory, `-a interactive` or `-a azcli` becomes possible and the PAT can be dropped.

## Handling the token

These rules apply to every command and script that uses the PAT: REST calls, git over HTTPS, and anything an agent writes for the task at hand.

- **Never put the token on a command line.** Not as a git option (`git -c http.extraHeader="Authorization: Basic …"`), not as a `curl -H` or `-u` argument, not inside a URL (`https://<token>@dev.azure.com/…`), and not as an argument to a script. A command line is printed in full when the command fails, is captured by every log that records the run, and is visible in the process list while it runs.
- **Read it inside the process that sends it.** A script reads the environment variable itself and builds the `Authorization` header in memory, as the check in "Setup" does. The value is never assigned to a variable that is later echoed, and never written to a file.
- **Give it to git through the environment.** Git (2.31 or newer) takes configuration from environment variables, so the header never appears among the arguments:

  ```powershell
  $env:GIT_CONFIG_COUNT = '1'
  $env:GIT_CONFIG_KEY_0 = 'http.extraHeader'
  $env:GIT_CONFIG_VALUE_0 = "Authorization: Basic $([Environment]::GetEnvironmentVariable('<env-var>','User'))"
  git clone https://dev.azure.com/<organization>/<project>/_git/<repo>
  Remove-Item Env:GIT_CONFIG_COUNT, Env:GIT_CONFIG_KEY_0, Env:GIT_CONFIG_VALUE_0
  ```

  A script that starts git as a child process passes the same three variables in that child's environment only.
- **Report the error, not the command.** When a call that carries the token fails, show the error text the tool returned (status code, git's last lines). Do not print the command, the request headers or the environment, and catch the failure so the runtime does not print them for you: an unhandled exception from a child process includes its full argument list.
- **If the token shows up anyway** (in terminal output, a log file, a transcript, a commit, a ticket), tell the owner at once and say where. Delete the log file if it is yours to delete, do not repeat the value in the message, and recommend creating a new PAT and revoking the old one. Then fix what printed it before running it again.
- **A clone or fetch can be cut off by the network.** Retry it up to three times. Before a retry, remove the folder an interrupted clone left behind: it looks like a repository and is not one.

## MCP or REST

Whatever a call returns stays in the session's context for every later turn, so the route is chosen by what comes back:

- **Reading** work items and pull requests: the scripts below. They print only what a task needs, a fifth to a seventh of the raw response with the command included. When a work item is read through the MCP server instead, pass `fields` on `wit_work_item`; `get_batch` without `fields` returns neither the description nor the criteria.
- **Board writes** (creating and changing work items, their comments): the MCP server. It handles Markdown fields and encoding, and REST costs about as much here, mostly in the tokens the agent writes.
- **Pull requests**, reading and commenting: the scripts. The MCP `repositories` domain stays out of the registration: its pull request responses are two to three times the scripts' output and its tools carry the largest schemas.

Print only the fields the task needs; a whole REST response (`ConvertTo-Json`) costs many times more and adds nothing.

### Scripts

In `scripts/`, PowerShell 7. Each takes `-Organization` and `-Project` from the profile, reads the token from `-TokenVariable` (default `PERSONAL_ACCESS_TOKEN`) as "Handling the token" requires, and prints `ERR: <status and message>` on failure. `Get-Help <script> -Full` lists every parameter.

| Script | Prints or does |
|---|---|
| `Get-AdoWorkItem.ps1 -Id 1234,1235 [-Comments] [-Fields …]` | type, state, title, assignee, iteration, parent, tags, description, criteria or repro steps; `-Fields` names the profile's `Acceptance criteria field` when the process calls it differently |
| `Get-AdoPullRequest.ps1 -Repository <repo> -Id <id> [-Iterations] [-Threads] [-System] [-Brief]` | state, branches, source, target and merge commits, reviewers with votes, work items, description; iterations; review threads with every comment; `-System` adds the system threads (votes, auto-complete, completion) |
| `Get-AdoPullRequest.ps1 -Repository <repo> -Branch <branch>` | every pull request of that source branch, any status |
| `Add-AdoPullRequestComment.ps1 -Repository <repo> -Id <id> -BodyFile <file.md> …` | posts a comment from a UTF-8 file and reads it back ("Review comments") |

```powershell
& "<backlog>\.ai-workflow\scripts\Get-AdoPullRequest.ps1" -Organization <organization> -Project "<project>" -Repository <repo> -Id <id> -Iterations -Threads
```

## Pull requests

Pull requests go through the REST API, read and commented on with the scripts above. The calls below are what the scripts do, and the reference for anything they do not cover, such as creating a pull request. The same PAT (already Base64 `:<PAT>`) goes in the `Authorization: Basic …` header; use only that variable and follow "Handling the token" above. Base URL: `https://dev.azure.com/<organization>/<project>/_apis/git/repositories/<repo>`, with spaces in the project name URL-encoded (`%20`).

- Find the PR (`Get-AdoPullRequest.ps1 -Branch`): `GET …/pullrequests?searchCriteria.sourceRefName=refs/heads/<branch>&searchCriteria.status=all&api-version=7.1`. Do this before creating one, so a branch never gets two.

### Reading a pull request

Used when a review is closed (`backlog.md` "Code reviews", "Closing") and before posting comments: `Get-AdoPullRequest.ps1 -Id <id> -Iterations -Threads`, with `-System` when closing a review. Behind it:

- `GET …/pullRequests/<id>?api-version=7.1`: `status` (`active`, `completed` = merged, `abandoned`), `closedDate`, `lastMergeCommit.commitId`, `lastMergeTargetCommit.commitId`, `reviewers[]` with `vote` (`10` approved, `5` approved with suggestions, `-5` waiting, `-10` rejected) and `closedBy`.
- `GET …/pullRequests/<id>/threads?api-version=7.1`: every thread with its `status` (`active`, `fixed`, `wontFix`, `closed`, `byDesign`, `pending`; empty on system threads) and comments. The system threads say who approved and who completed the PR, with the time.
- `GET …/pullRequests/<id>/iterations?api-version=7.1`: one entry per push with its source commit; a review names them as iterations.

### Creating a pull request

Only when the owner asks for it; the branch must already be pushed. Show the owner the source branch, the target branch and the title, and create the PR after confirmation:

- `POST …/pullrequests?api-version=7.1` with `sourceRefName`, `targetRefName`, `title`, `description` and `workItemRefs: [{"id": "<workItemId>"}]` for every board item the branch implements. Send the body as UTF-8 bytes.
- The source branch is named after the board item (`workspace.md` "Branches"); a branch without an id gets its work item and its name first. The target is the branch the work was cut from (`dev` or `main`, the profile's `Conventions` when they differ, or the integration branch of an epic from the topic's `AGENTS.md`).
- Title and description in English, whatever the profile's language: a pull request belongs to the code, like branch names and commit messages. Written for non-technical readers, no attribution lines. The description says what changes for the user and names the board items as `#<id>`.
- Record the PR id where the work is written up (the ticket, the plan's `Board:` line or the review record).

### Review comments

When the owner asks for review comments on a PR "in their name":

- Read the existing threads first (`Get-AdoPullRequest.ps1 -Threads`) so the same finding is not posted twice.
- Post only findings about the diff (`backlog.md` "Code reviews"). A finding in a file outside the PR's changes, or about code the PR does not touch, goes to a ticket, not to a PR-level thread.
- Write each comment to its own Markdown file, then post it with `Add-AdoPullRequestComment.ps1 -BodyFile <file.md>` and one of:
  - `-FilePath <path> -Line <n> [-EndLine <n>] [-Iteration <n>]`: a new thread on a file line. Line numbers are those of the file at the reviewed iteration's source commit; the script uses the latest iteration unless `-Iteration` names the reviewed one, and prints the iteration and commit it anchored on.
  - `-ThreadId <id> [-Status active]`: a reply in an existing thread, for example when a fix is incomplete and the thread is reopened.
  - neither: a new thread on the PR as a whole.
- The script reads the thread back and prints its id, comment id, status and author, or fails when the stored text differs from the file. `-WhatIf` prints the request without posting.
- Behind it: `POST …/pullRequests/<id>/threads?api-version=7.1` with `threadContext.filePath` (leading `/`) and `rightFileStart` / `rightFileEnd`, and `pullRequestThreadContext` with the file's `changeTrackingId` from `GET …/iterations/<n>/changes` and both `iterationContext` comparing iterations set to `n`, which anchors the line on the diff against the common base so it stays in place when later iterations arrive ([REST reference](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-request-threads/create?view=azure-devops-rest-7.1)). The body goes as UTF-8 bytes, otherwise non-ASCII characters are garbled.
- Comments are in the profile's language. Record the PR and thread ids where the review is written up (the plan's `Code review` section, the review record or the ticket).

## Entering items

Board items are entered by the agent, never copied by hand. `Work item types` in the profile gives the hierarchy (for example Epic → Feature → PBI → Task); "PBI" below stands for the type that carries the user story.

- Titles and descriptions are in the profile's language, written for non-technical readers.
- A PBI description opens with the user story under the English label **`User story:`**; the story itself is in the profile's language, in its `User story` shape.
- Acceptance criteria go into the profile's `Acceptance criteria field`, in **Markdown** format, as a checkbox list (`- [ ] …`), not as an HTML list and not in the description. Through the MCP server: `update_batch` with `format: "Markdown"` on that field. When the profile says the field is `none`, the criteria are the last section of the description.
- Writing to the board is visible to the whole company. Before creating or changing items, show the owner the exact list: type, title, parent, area and iteration path. Write only after the owner confirms that list. A confirmation covers only that list.
- Check the process template before the first write in a project: which work item types exist and which field holds the acceptance criteria. Record the answer in the profile's `Board` section.
- Create parents first (top of the hierarchy down) and link each child to its parent in the same run.
- After creating items, write the returned work item ids back where the draft lives: the ticket section `## PBI N (workItemId): title`, the plan's `Board:` line, or the task list of the change. Do this in the same session, before the numbers are lost.
- `State` is set by people: never change it, and never delete or close a board item, unless the owner asks for that specific item. This holds after a merge too.

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
