# Triage labels

The skills speak in terms of five canonical triage roles. The backlog has no labels; each role maps onto the item's `Status` value, written in the shape `../backlog.md` requires so the status listing picks it up.

| Role | Status in the backlog |
|---|---|
| `needs-triage` | `proposed` |
| `needs-info` | `blocked` — note says who is being waited on |
| `ready-for-agent` | `planned` — note: ready for an agent |
| `ready-for-human` | `planned` — note: for a person |
| `wontfix` | `rejected` — note gives the reason |

When a skill says to apply a role, set the `Status` to the value in this table, with the note after the dash, in the profile's language. A `rejected` ticket moves to `tickets/completed/` in the same edit.
