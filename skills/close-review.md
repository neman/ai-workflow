# Closing a code review

A checklist for closing the record of a code review in `code-reviews/` once its pull request is merged or abandoned. It is written for a subagent on a cheaper model: every step says what to read, what to write and what to report; the judgment stays with the main session, which reads the report before the push. The rules behind it are in `../backlog.md` "Code reviews", "Closing" and "Git"; the REST calls in `../azure-devops.md` "Reading a pull request". The labels and the language of every text written come from the profile (`AGENTS.md` of the backlog).

## Inputs

- the path of the review file (`code-reviews/<review>/<review>.md`);
- the pull request: repository and id, from the review's links section or its first lines;
- the profile: language, field map (`Closing`, `Board`, `Related`), `Backlog commits`.

## Steps

1. **Read the review file** whole. Note the thread ids it posted, every condition its findings state (a companion PR, a release order, a follow-up the author promised) and every ticket or plan it links.
2. **Read the PR**: the PR itself, its threads and its iterations (`azure-devops.md` "Reading a pull request"). Stop and report when `status` is still `active`: nothing is written.
3. **Check every condition** from step 1 against the board and the other repositories: a companion PR is read the same way; a follow-up is looked up in `tickets/`. Each condition is `holds` or `does not hold`, with the evidence (PR id and state, commit).
4. **List what outlives the PR**: a finding marked pre-existing, a follow-up the author did not do in this PR, a debt item, an unresolved thread on a merged PR. For each, grep `tickets/` for its file path or symbol: `has ticket <path>` or `no ticket`.
5. **Write the status line**: `completed` when merged, `rejected` when abandoned; then the date, the merge commit (`lastMergeCommit`), who approved (reviewers with vote `10`, from the system thread with the time), who completed the PR and when, and the state of each thread from step 1. A thread still `active` on a merged PR is named here as open; do not resolve it.
6. **Add the closing section**, headed with the profile's `Closing` label, right before the conclusion of the review (or at the end when there is none): how the PR ended (merged into which branch, when, by whom), each condition from step 3 with its result, each item from step 4 with its ticket or `no ticket`. One short paragraph; no restating of the findings.
7. **Update the tickets and plans** the review links that name the PR: add the merge (date, commit) to their `Board`/PR line and tick the checkbox for the PR. Do not change their `Status` and do not move them; merging does not complete a ticket.
8. **Check the Markdown**: one blank line between sections, no two consecutive blank lines, compact tables, quotation marks and labels as the profile's language uses them.
9. **Commit and push** only when the profile's `Backlog commits` is `agent, for closing reviews` and the main session has read the report: `git add` only the files touched in steps 5 to 7, read `git diff --cached`, commit with a message in English in the shape of `workspace.md` "Committing" (subject `Close the <repo> PR <id> review as completed`, body with how the PR ended and what outlives it), then `git push`; on a rejected push `git pull --rebase` and push again, never force. Otherwise leave the files in the working tree.

## Report

The report to the main session has four lines, nothing else:

- `PR`: id, state, merge commit, date, approved by, completed by.
- `Open threads`: the review's threads still `active`, or `none`.
- `Conditions`: each one with `holds` / `does not hold` and the evidence, or `none`.
- `Outlives the PR`: each item with its ticket path or `no ticket`, or `none`.

A `does not hold` or a `no ticket` is for the main session to handle before the push: the ticket is written by `../backlog.md` "Code reviews" and `issue-tracker.md`, the condition is told to the owner.
