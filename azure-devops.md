# Azure DevOps board

Rules for a backlog whose profile says `Tracker: Azure DevOps`. Read this before any board write (creating or changing work items, creating pull requests or posting review comments) and before setting up the MCP server. Values marked `<…>` come from the profile's `Board` section or from the person setting things up.

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

- `-d core work work-items` loads only the project and work item tools; `core` must stay in the list. Add `repositories` or `pipelines` only when they are needed.
- Never put the PAT itself in `claude mcp add -e …`, in a config file, in the backlog or in a repository: that stores it in plain text. When it expires, repeat step 2 and step 4.
- Check that the PAT works without the server (`200` = OK):

  ```powershell
  (Invoke-WebRequest "https://dev.azure.com/<organization>/_apis/projects?api-version=7.1" -Headers @{Authorization="Basic $([Environment]::GetEnvironmentVariable('<env-var>','User'))"}).StatusCode
  ```

### Troubleshooting

- `Cannot find module '../build/Release/keytar.node'` from `npx -y @azure-devops/mcp --help`: the native `keytar` module was not built during the first `npx` download. Run `npm rebuild keytar` in the `npx` cache folder named in the error (`%LOCALAPPDATA%\npm-cache\_npx\<hash>`), then check `--help` again.
- `Connection closed` right after start: the environment variable is not visible to this process; see step 4.
- The check in the notes above returns `203` instead of `200`: the request was not authenticated and Azure DevOps answered with its sign-in page. Either the variable holds an empty token (set by hand; its Base64 value is then 4 characters long), or the PAT belongs to another organization, has expired, or the account is not a member of this organization. Repeat step 2.
- If the organization is later connected to the company's Entra directory, `-a interactive` or `-a azcli` becomes possible and the PAT can be dropped.

## Pull requests

The server above has no pull request tools (`repositories` is not loaded, so every session stays light). Pull requests go through the Azure DevOps REST API with the same PAT (already Base64 `:<PAT>`, sent as `Authorization: Basic …`). Use only that variable, never search the environment for other tokens, and never print the token. Base URL: `https://dev.azure.com/<organization>/<project>/_apis/git/repositories/<repo>`, with spaces in the project name URL-encoded (`%20`).

- Find the PR: `GET …/pullrequests?searchCriteria.sourceRefName=refs/heads/<branch>&searchCriteria.status=all&api-version=7.1`. Do this before creating one, so a branch never gets two.

### Reading a pull request

Used when a review is closed (`backlog.md` "Code reviews", "Closing") and before posting comments.

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

- Find the PR as above.
- Read existing threads first (`GET …/pullRequests/<id>/threads?api-version=7.1`) so the same finding is not posted twice.
- Post: `POST …/pullRequests/<id>/threads?api-version=7.1` with `threadContext.filePath` (leading `/`) and `rightFileStart` / `rightFileEnd` line numbers from the PR's source commit. Send the body as UTF-8 bytes, otherwise non-ASCII characters are garbled.
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
