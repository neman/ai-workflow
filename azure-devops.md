# Azure DevOps board

How the board rules are carried out for a backlog whose profile says `Tracker: Azure DevOps` or `Code host: Azure DevOps`: the MCP server, the token, the scripts and REST calls, the field names, and the pipelines. The rules themselves (what is entered, who confirms it, how board text and pull requests are written) are in `board.md` and apply to every read and write described here: read `board.md` first. Read this file before reading or writing the board or a pull request (work items, review threads, creating a pull request, posting review comments), before writing, registering or running a pipeline or changing a variable group or environment, and before setting up the MCP server. Values marked `<…>` come from the profile's `Board` section or from the person setting things up.

## Setup

The agent uses Microsoft's Azure DevOps MCP server (`@azure-devops/mcp`, needs Node.js) with a personal access token (PAT). Interactive sign-in works only when the organization is connected to the Microsoft Entra directory that the signed-in account belongs to; an organization whose members sign in with personal accounts rejects it (`TF400813: … is not authorized`, or `invalid_scope`), and the Azure CLI token is rejected the same way. A PAT works in both cases, so it is the default.

Profile fields: `Organization`, `Project`, `MCP server` (the registered server name and the variable that holds the token) and `Pipelines`. They sit under `Board` when Azure DevOps is the tracker, and under `Code host` when it holds only the code.

1. Create a PAT at `https://dev.azure.com/<organization>/_usersSettings/tokens`, signed in with the account you use for the board. Choose "Custom defined" and tick these scopes:

   - [ ] **Work Items: Read & Write**: reading and entering board items through the MCP server.
   - [ ] **Project and Team: Read**: listing projects, teams and iterations; the server fails to start without it.
   - [ ] **Code: Read & Write**: pull requests through the REST API: creating them, posting review comments, linking work items. `Read` alone lists PRs but every write returns `401`.

   Only when the profile's `Board` section says `Pipelines: yes` (the agent registers, configures and runs pipelines, "Pipelines" below), also:

   - [ ] **Build: Read & execute**: registering a YAML pipeline, starting a run, reading runs and their logs.
   - [ ] **Variable Groups: Read, create & manage**: creating and changing a variable group.
   - [ ] **Environment: Read & manage**: reading environments, their resources and checks.
   - [ ] **Pipeline Resources: Use & manage**: allowing a pipeline to use an environment or a variable group. Without it, the owner clicks "Permit" on the first run.

   These four hold for every environment of the project, production included; "Pipelines" says what the agent may do with them. Anything else (Release, Packaging) stays unticked until a rule here needs it. When a scope is added later, the token must be regenerated and stored again (step 2); a REST call reads the new value at once, the MCP server only after step 4.
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

- `-d core work work-items` loads only the project and work item tools; `core` must stay in the list. Pull requests go through the scripts, not the `repositories` domain ("MCP or REST" below); pipelines go through REST as well ("Pipelines" below), so the `pipelines` domain stays out too.
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

- Find the PR (`Get-AdoPullRequest.ps1 -Branch`): `GET …/pullrequests?searchCriteria.sourceRefName=refs/heads/<branch>&searchCriteria.status=all&api-version=7.1`.

### Reading a pull request

Used when a review is closed (`backlog.md` "Code reviews", "Closing"), before posting comments and for release notes: `Get-AdoPullRequest.ps1 -Id <id> -Iterations -Threads`, with `-System -Brief` when closing a review. Behind it are the calls below; each also says which Azure DevOps value stands for which word of `board.md` "Pull requests".

- `GET …/pullRequests/<id>?api-version=7.1`: `status` (`active` = open, `completed` = merged, `abandoned` = closed without merging), `closedDate`, `lastMergeCommit.commitId` (the merge commit), `lastMergeTargetCommit.commitId`, `reviewers[]` with `vote` (`10` approved, `5` approved with suggestions, `-5` waiting, `-10` rejected) and `closedBy` (who merged it). An approval is a vote of `10`.
- `GET …/pullRequests/<id>/threads?api-version=7.1`: every thread with its `status` (`active` and `pending` = open; `fixed`, `wontFix`, `closed` and `byDesign` = resolved; empty on system threads) and comments. The system threads say who approved and who merged the PR, with the time.
- `GET …/pullRequests/<id>/iterations?api-version=7.1`: one entry per push with its source commit; a review names them as iterations.
- `GET …/pullRequests/<id>/workitems?api-version=7.1`: the board items linked to the PR.

### Creating a pull request

When a pull request is created, what the owner confirms and what its text says are in `board.md` "Pull requests". After the confirmation:

- `POST …/pullrequests?api-version=7.1` with `sourceRefName`, `targetRefName`, `title`, `description` and `workItemRefs: [{"id": "<workItemId>"}]` for every board item the branch implements. Send the body as UTF-8 bytes.

### Review comments

Which findings are posted, and in which language, is in `board.md` "Pull requests".

- Read the existing threads with `Get-AdoPullRequest.ps1 -Threads`.
- Write each comment to its own Markdown file, then post it with `Add-AdoPullRequestComment.ps1 -BodyFile <file.md>` and one of:
  - `-FilePath <path> -Line <n> [-EndLine <n>] [-Iteration <n>]`: a new thread on a file line. Line numbers are those of the file at the reviewed iteration's source commit; the script uses the latest iteration unless `-Iteration` names the reviewed one, and prints the iteration and commit it anchored on.
  - `-ThreadId <id> [-Status active]`: a reply in an existing thread, for example when a fix is incomplete and the thread is reopened.
  - neither: a new thread on the PR as a whole.
- The script reads the thread back and prints its id, comment id, status and author, or fails when the stored text differs from the file. `-WhatIf` prints the request without posting.
- Behind it: `POST …/pullRequests/<id>/threads?api-version=7.1` with `threadContext.filePath` (leading `/`) and `rightFileStart` / `rightFileEnd`, and `pullRequestThreadContext` with the file's `changeTrackingId` from `GET …/iterations/<n>/changes` and both `iterationContext` comparing iterations set to `n`, which anchors the line on the diff against the common base so it stays in place when later iterations arrive ([REST reference](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-request-threads/create?view=azure-devops-rest-7.1)). The body goes as UTF-8 bytes, otherwise non-ASCII characters are garbled.

## Pipelines

Applies when the profile's `Board` section says `Pipelines: yes` and the PAT carries the pipeline scopes from "Setup". With `Pipelines: no` or a token without them, the agent writes the YAML and lists what the owner sets up by hand. Pipelines, variable groups and environments go through the REST API with the same token and the same "Handling the token" rules. Base URL: `https://dev.azure.com/<organization>/<project>/_apis`; variable groups are written at the organization level, `https://dev.azure.com/<organization>/_apis`.

### What the agent does and does not do

- **A write is shown first**, as for the board: pipeline name, folder and YAML path; variable group and variable names, with which are secret; which pipeline gets which permission. Write after the owner confirms that list; the confirmation covers only that list.
- **A run is started only when the owner confirms that run**: the pipeline, the branch and the stages it deploys. A deploy changes a server other people use. The agent never approves a run, its own included; approvals belong to the people the environment's check names.
- **Secret values stay with the owner.** The agent creates a secret variable empty and marked secret; the owner types the value in Pipelines → Library. The agent never reads, writes or prints a secret value, and prints non-secret values only when the task needs them: a connection string without a password is still an address. Report a variable as its name, whether it is secret, and whether it is empty.
- **Only the resources the owner named.** The scopes reach every environment, production included; the agent touches only the pipeline, group and environment of the task.
- **Ids go where the work is written up**: pipeline, variable group and environment ids, beside the board item.

### Writing a pipeline

- **Copy the project's closest pipeline.** List the existing pipelines first (folder and name convention), read the YAML of the one that deploys the most similar service to the same environment, and follow its tasks, artifact handling, configuration transform and step names. Every deviation is named to the owner with its reason before the pipeline is written, not discovered later in a review.
- **Configuration that `FileTransform` replaces must exist in the file.** JSON variable substitution changes only keys already present in `appsettings.<Environment>.json`; a variable named after a missing key does not add it. So the file in the repository lists every key the server needs, and each variable in the group carries the key's path (`ConnectionStrings.Default`, `Section.Key`, `Section.Array.0`; case-sensitive). The value in the file is empty rather than a placeholder text: an unreplaced empty value stops a service that validates its settings at startup, while a placeholder may be accepted as a valid key. The documentation does not say whether secret variables are substituted; the first run shows it.
- **Secrets reach a script through `env:`, never inline.** `$(Secret)` inside a script body is written into the script file on the agent; map it to an environment variable of the step and read that.
- **A value that is the same in every environment** is not a pipeline variable: it goes into `appsettings.json` in the repository and changes through a pull request.

### Variable groups

- **An update replaces the whole group** (`PUT …/distributedtask/variablegroups/<id>?api-version=7.1-preview.2`): a variable left out is deleted. Re-read the group right before writing, and send each existing secret under its own name with `isSecret: true` and no value, so the stored value stays.
- **A secret cannot be renamed through the API**: its value is never returned, so it cannot be carried to a new name. The owner renames it in Library, or the agent creates the new name empty and the owner types the value again.
- **The Library page saves the version it loaded.** A page opened before the agent's write overwrites that write when the owner saves, and the variables come back under their old names. Before the owner edits a group the agent changed, tell them to reload the page; after they edit, re-read the group before the next write.

### Environments

- **A VM's tags cannot be set through the public REST API.** The documented route (`…/distributedtask/environments/<id>/providers/virtualmachinegroups/<resourceId>/virtualmachines`, up to `6.0-preview.1`) serves only resources of type virtual machine group; for a resource of type `virtualMachine` it answers `404 Resource with ID … does not exist`, and `…/providers/virtualmachines` does not exist. The web UI saves tags through `_apis/Contribution/HierarchyQuery`, an internal data provider without a published contract, which the agent does not call. The tag is added in Pipelines → Environments → the resource → Manage tags, or when the agent is registered on the VM (`--addvirtualmachineresourcetags`). The REST API reads the tags back (`GET …/distributedtask/environments/<id>?expands=resourceReferences&api-version=7.1-preview.1`).
- **Read the environment's checks before the first run** (`GET …/pipelines/checks/configurations?resourceType=environment&resourceId=<id>&$expand=settings&api-version=7.1-preview.1`): an approval names the groups that must approve each deploy, and the owner needs to know who that is before the run waits on them.

### Calls

| Purpose | Call |
|---|---|
| List pipelines (id, folder, name) | `GET …/pipelines?api-version=7.1` |
| Register a YAML pipeline; the file must already be pushed | `POST …/pipelines?api-version=7.1` with `folder`, `name`, `configuration: { type: "yaml", path: "/<path>.yml", repository: { id, name, type: "azureReposGit" } }` |
| List or find variable groups | `GET …/distributedtask/variablegroups?groupName=<name>&api-version=7.1-preview.2` |
| Create a variable group | `POST <organization>/_apis/distributedtask/variablegroups?api-version=7.1-preview.2` with `name`, `type: "Vsts"`, `variables`, `variableGroupProjectReferences: [{ name, projectReference: { id, name } }]` |
| List environments; one with its resources and tags | `GET …/distributedtask/environments?api-version=7.1-preview.1`; `GET …/distributedtask/environments/<id>?expands=resourceReferences&api-version=7.1-preview.1` |
| Allow a pipeline to use a resource | `PATCH …/pipelines/pipelinepermissions/<environment or variablegroup>/<id>?api-version=7.1-preview.1` with `pipelines: [{ id, authorized: true }]` |
| Start a run on a branch | `POST …/pipelines/<id>/runs?api-version=7.1` with `resources: { repositories: { self: { refName: "refs/heads/<branch>" } } }` |
| Read a run: steps and their result, then a step's log | `GET …/build/builds/<runId>/timeline?api-version=7.1`; `GET …/build/builds/<runId>/logs/<logId>?api-version=7.1` |

Print from a run only the failed steps and the last lines of their logs; a whole log costs as much as a whole REST response ("MCP or REST").

## Entering items

The rules are in `board.md` "Entering items". What Azure DevOps adds:

- The work item types and the acceptance criteria field come from the project's process template (`INIT.md` Step 7 has the call).
- The acceptance criteria field is written in **Markdown** format, not as an HTML list. Through the MCP server: `update_batch` with `format: "Markdown"` on that field.
- The confirmation list names the area path and the iteration path of every item.
