# Browser testing

How an agent runs a test plan or a set of checks through a browser on a test environment: which tool, how it gets in, what it may do and what it hands back. The record of a run is a testing session (`../backlog.md` "Testing sessions"). The project's values (allowed addresses, the account, actions left out, the secrets file) come from the profile's `Browser testing` field (`AGENTS.md` of the backlog), which may point to a project doc that holds them; the language of every text written comes from the profile.

## Who does what

A subagent on a cheaper model drives the browser and writes the run record; the main session gives it the scenarios, reads the record and writes the tickets. The subagent's report carries every step's outcome and the exact on-screen text it was judged by. The board stays read-only for both: findings become tickets in the backlog.

## Choosing the tool

**Claude in Chrome is the default.** It runs in the owner's own browser and profile, handles downloads, and the owner can watch the run. The owner signs in to the environment before the run; the agent never types the password. It needs the Claude in Chrome extension in Chrome, Edge or another Chromium browser, and Claude Code signed in with a Claude plan through `/login`: with an API key or a cloud provider it stays off. A session turns it on with `claude --chrome` or `/chrome` (details: `https://code.claude.com/docs/en/chrome`).

**Playwright MCP in headless mode** is for the cases Chrome does not fit:

- several runs at once, each in its own browser: one registered server per run (see "Headless setup"), since in one Chrome the tabs and the session collide;
- a run without the owner, since headless signs in by itself;
- a run while the owner works in their own Chrome, which headless leaves untouched;
- a session that cannot use Claude in Chrome (API key, cloud provider, no browser).

Per scenario the two cost about the same in tokens and time: Chrome makes fewer, heavier calls (batched actions, screenshots), headless makes more, lighter ones (short responses, snapshots in files). Downloads are untested headless; a scenario that downloads a file runs in Chrome.

The run record names the tool used.

## Before the first action

1. **Check the address.** Open the environment and read the address after all redirects. It must be one of the addresses the profile allows; anything else, production above all, ends the run before signing in. A banner such as "test app" is no evidence either way: it is usually a deployment setting and may be off on a real test environment.
2. **Sign in.** Chrome: the session is already open; a login page means the agent stops and reports "not signed in". Headless: the account name is typed as text, and the password field gets the secret's key name (see "Headless setup"); the executed code then shows `process.env['<KEY>']`. Code showing anything else in its place ends the run, and the agent reports it without repeating the value.

## During the run

- Every action the profile allows on a test environment is in scope; the profile names what is left out (for example fiscal receipts).
- Data the run creates carries the run label from the plan in its name, so runs never mix.
- A step that cannot be done (the control is missing, the screen does not load) is recorded as not run, with the reason, and the run moves on. Two failed attempts at the same step end the run with a report.
- A downloaded file is checked by reading the file, never by its name.

## Headless setup

Once per machine, by the owner, since it changes the agent's global configuration:

```powershell
claude mcp add playwright -s user -- npx -y @playwright/mcp@latest --headless --isolated --secrets "<secrets file>" --output-dir "<output folder>"
```

- `--secrets`: a dotenv file outside every repository, one line per secret (`<KEY>=<value>`). Typing exactly the key name into a field makes the server substitute the value, and the server masks every occurrence of the value in its responses. Keep account names out of it: masking hides each occurrence on the page, so a common word vanishes from every snapshot.
- `--output-dir`: snapshots and screenshots saved without an explicit name go here. Without it they land in the session's working folder, which is often a repository.
- `--isolated`: no cookies survive between sessions, so each run signs in.
- The server runs sandboxed and cannot read environment variables: the secrets file is the only way to hand it a password.
- The server loads when the agent starts: after registering it or editing the secrets file, restart the session.
- One server drives one page: its tools act on the current tab and take no tab argument, and all subagents of a session share the server. Parallel runs need one registration per run (`playwright-1`, `playwright-2`, …, each with its own `--output-dir`), and each subagent is told which server's tools to use.

## Working with the page (headless)

- After an action the server returns the executed code and the path of a snapshot file. Read the lines you need from that file with grep (`option`, `button "<label>"`, the field label); request the full snapshot only to orient on a new screen.
- Call `browser_snapshot` and `browser_take_screenshot` without `filename`: a relative name resolves against the working folder, not the output folder.
- Overlay dropdowns (component libraries such as PrimeNG or Angular Material): click the dropdown's trigger, grep the snapshot for the `option` and click its ref. `browser_fill_form` with type `combobox` targets native selects only.
- Formatted number inputs: click the field, press `Control+a`, then `browser_type` with `slowly: true`. `fill` skips the key events the component validates on, so its message stays stale; typing without selecting first appends to the old value.

## Report

To the main session, in the profile's language:

- the address after redirects and how the session was signed in (never the password);
- each step: done, failed or not run, with the on-screen text or list value it was judged by;
- every step that needed a second attempt, and why;
- ids of the records the run created;
- anything the tool struggled with, so the plan or this skill can be corrected.
