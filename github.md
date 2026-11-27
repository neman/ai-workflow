# GitHub

How the board rules are carried out for a backlog whose profile says `Tracker: GitHub` or `Code host: GitHub`: the `gh` command line, its sign-in, the calls and GitHub's own values. The rules themselves (what is entered, who confirms it, how board text and pull requests are written) are in `board.md` and apply to every read and write described here: read `board.md` first. Values marked `<…>` come from the profile or from the repository's remote address.

A call marked *(not run yet)* is taken from GitHub's documentation and has not been used in a project. Before its first use, tell the owner so; when it works as written, remove the mark, and when it does not, correct the call here.

## Setup

The agent uses the GitHub CLI (`gh`). There is no MCP server and no token variable: `gh` keeps its token in the operating system's credential store.

1. `gh --version`. When it is missing, the person installs it from `https://cli.github.com`.
2. The person signs in, in their own terminal: `gh auth login`, choosing GitHub.com, HTTPS and the browser. It is interactive, so the agent does not run it.
3. `gh auth status` names the signed-in account and its scopes; `repo` must be among them. With several accounts on the machine, the one marked active must be the one that reaches the repository; the person changes it with `gh auth switch -u <login>`, because it changes the account for every session on the machine.
4. `gh repo view <owner>/<repo> --json visibility,hasIssuesEnabled` answers. As tracker, `hasIssuesEnabled` must be `true`.

Profile fields. As tracker, under `Board`: `Repository` (`<owner>/<repo>`, the one repository whose issues are the board, also when the workspace holds several) and `Visibility` (`public` or `private`, from step 4). As code host, `Code host: GitHub` needs no fields: each repository's `<owner>/<repo>` is read from `git -C <repo> remote get-url origin`.

Notes:

- **Name the repository in every call** with `-R <owner>/<repo>`, or the full `repos/<owner>/<repo>/…` path for `gh api`. Without it `gh` takes the repository from the current folder, and a session in the backlog is in a different repository, or in one with no remote.
- **A public repository is public.** Where `board.md` says a board write is visible to the whole company, here it is visible to everyone and stays in search results and caches after it is deleted. An issue, a pull request or a comment in a public repository carries nothing from a support case and no client name, data, internal address or path; the ticket in the backlog keeps those, and the issue gets the part that is safe to publish. The confirmation list says `public` beside the repository.
- GitHub Projects are not covered: no project has used one with these rules. They need the extra `project` scope (`gh auth refresh -s project`, run by the person).

## Handling the token

- **The token stays inside `gh`.** Never run `gh auth token` or `gh auth status --show-token`, and never copy the token into an environment variable, a file or a URL. Every call goes through `gh`, which reads the token itself.
- **Git reaches GitHub the way the person set it up**: the credential helper from `gh auth login`, or SSH. A remote address never carries a token.
- **Signing in, switching accounts and adding scopes are the person's**: `gh auth login`, `gh auth switch` and `gh auth refresh` change the machine, not the session. When a call answers `401`, `403` or `404` on a repository that exists, show `gh auth status` and say which account or scope is missing.
- **Report the error, not the command**: the text `gh` printed, as in `workspace.md` "Tokens and other secrets".

## Pull requests

Find the pull request of a branch, in any state: `gh pr list -R <owner>/<repo> --head <branch> --state all --json number,state,title`.

A pull request and an issue share one series of numbers in a repository, so `#<n>` alone does not say which it is. In backlog items write a pull request as `PR #<n>` and an issue as `#<n>`. In a commit message or an item of another repository, the backlog's own included, write `<owner>/<repo>#<n>`: GitHub links a bare `#<n>` to the repository the text is in.

### Reading a pull request

```powershell
gh pr view <n> -R <owner>/<repo> --json number,state,title,body,baseRefName,headRefName,headRefOid,mergedAt,mergedBy,mergeCommit,closedAt,reviewDecision,latestReviews,closingIssuesReferences,commits
```

Add `--jq` and print only the fields the task needs. The GitHub values behind the words of `board.md` "Pull requests":

- **State**: `OPEN` = open, `MERGED` = merged, `CLOSED` = closed without merging.
- **Merge commit**: `mergeCommit.oid`; merged by `mergedBy.login` at `mergedAt`.
- **Approval**: an entry of `latestReviews` with `state` `APPROVED`, by `author.login` at `submittedAt`. `CHANGES_REQUESTED` blocks the pull request; `COMMENTED` is neither. `reviewDecision` is empty when the repository requires no review, so an empty value does not mean "not approved". GitHub does not let the author approve their own pull request, so in a repository where the owner is the only person, `latestReviews` is empty and the merge is the only record: a review record names who merged and says `approved by: none (the author's own pull request)`.
- **Thread**: review threads are not in `gh pr view`; they come from GraphQL. `isResolved: true` = resolved, `false` = open; `isOutdated` says the line has changed since the comment.

  ```powershell
  gh api graphql -f query='query{repository(owner:"<owner>",name:"<repo>"){pullRequest(number:<n>){reviewThreads(first:100){nodes{id isResolved isOutdated path line comments(first:50){nodes{databaseId author{login} body createdAt}}}}}}}'
  ```

- **Push**: GitHub keeps no numbered list of pushes. `commits` gives the branch's commits (`oid`, `committedDate`) and `headRefOid` the head; a review record names the head commit it read, and a later session compares it with the current one.
- **Linked board items**: `closingIssuesReferences` lists only the issues the pull request will close. An issue named as `Refs #<n>` is not there; read the numbers from `body`.

### Creating a pull request

When a pull request is created, what the owner confirms and what its text says are in `board.md` "Pull requests". After the confirmation, with the description in a UTF-8 file:

```powershell
gh pr create -R <owner>/<repo> --head <branch> --base <target> --title "<title>" --body-file <file.md>
```

- Always pass `--head`: without it `gh` takes the current branch and may offer to push it. The branch is pushed first. The last output line is the pull request's address, which ends in its number.
- **The description names its board items as `Refs #<n>`.** A closing keyword before the number (`Closes`, `Fixes`, `Resolves`) makes GitHub close the issue the moment the pull request is merged, and so does linking the issue in the pull request's sidebar. The state of a board item is set by people (`board.md` "Entering items"), so a closing keyword is written only when the owner asks for it for that item.

### Review comments

Which findings are posted, and in which language, is in `board.md` "Pull requests".

- Read the existing threads with the GraphQL call above.
- A comment on a line, from a UTF-8 file, anchored on the head commit that was reviewed *(not run yet)*:

  ```powershell
  gh api repos/<owner>/<repo>/pulls/<n>/comments -F body=@<file.md> -f commit_id=<headRefOid> -f path=<path> -F line=<line> -f side=RIGHT
  ```

  Several lines add `-F start_line=<first> -f start_side=RIGHT`. A reply in an existing thread *(not run yet)*: `gh api repos/<owner>/<repo>/pulls/<n>/comments/<comment id>/replies -F body=@<file.md>`.
- A comment on the pull request as a whole *(not run yet)*: `gh pr comment <n> -R <owner>/<repo> --body-file <file.md>`.
- Record the thread `id` and the comments' `databaseId` from the GraphQL call in the review record.
- **The vote is the owner's**: never run `gh pr review --approve` or `--request-changes`, and never resolve a thread. The session ends with the verdict in the conversation (`backlog.md` "Code reviews").

## Entering items

The rules are in `board.md` "Entering items". What GitHub adds:

- **An issue is the board item**, and the hierarchy is made of sub-issues. The repository's issue types are read with the call below; `Work item types` in the profile records which type stands for the module's Feature, PBI and Task, decided with the owner before the first write.

  ```powershell
  gh api graphql -f query='query{repository(owner:"<owner>",name:"<repo>"){issueTypes(first:20){nodes{name}}}}'
  ```

- **Reading an issue**: `gh issue view <n> -R <owner>/<repo> --json number,title,state,stateReason,labels,assignees,milestone,body,closedAt`. Its type and the count of its sub-issues: `gh api repos/<owner>/<repo>/issues/<n> --jq '{type: .type.name, sub: .sub_issues_summary}'`. Its children: `gh api repos/<owner>/<repo>/issues/<n>/sub_issues`. Its parent: `gh api repos/<owner>/<repo>/issues/<n>/parent`, which answers `404` when there is none.
- **State**: `OPEN`, or `CLOSED` with `stateReason` `COMPLETED` or `NOT_PLANNED`. The state is the owner's (`board.md` "Entering items"); when the owner asks for a specific issue to be closed: `gh issue close <n> -R <owner>/<repo> --reason completed` (or `--reason "not planned"`), then read `state` and `stateReason` back and record the date in the ticket.
- **Acceptance criteria**: the profile's `Acceptance criteria field` is `none`, so they are the last section of the issue body, `## Acceptance criteria`, as a checkbox list. Ticking a box on GitHub edits the body, so re-read the body right before every write: a body written from an older copy erases the ticks made since. A change to the body, ticks included, goes through a file: `gh issue view <n> -R <owner>/<repo> --json body --jq .body > <file.md>`, edit the file, `gh issue edit <n> -R <owner>/<repo> --body-file <file.md>`, then read the body back.
- **Creating an issue**, with the body in a UTF-8 file: `gh issue create -R <owner>/<repo> --title "<title>" --body-file <file.md>`, with `--label <label>` *(not run yet)* when the item has one. Its last output line is the issue's address, which ends in the number. `gh` has no flag for the type or the parent; both are set afterwards, the type first and the parent second *(the parent call not run yet)*:

  ```powershell
  gh api -X PATCH repos/<owner>/<repo>/issues/<n> -f type=<Type>
  gh api -X POST repos/<owner>/<repo>/issues/<parent n>/sub_issues -F sub_issue_id=<child id>
  ```

  Between the two calls the issue exists without its type, so read it back (`--jq '{number, type: .type.name}'` on the first call) before reporting it as entered. `<child id>` is the child's `id` from `gh api repos/<owner>/<repo>/issues/<n> --jq .id`, not its number.
- **Labels** come from `gh label list -R <owner>/<repo>`; a label that does not exist yet is named as new in the confirmation list.
- **The confirmation list** names, for every item: the repository and its visibility, the type, the title, the parent, the labels and the milestone.
- **The id written back** is the issue number, as `#<n>`: the ticket section becomes `## PBI N (#<n>): title`.
- Issues that people entered before the backlog existed are board items like any other; their text is not rewritten into the module's shape unless the owner asks for that item.
