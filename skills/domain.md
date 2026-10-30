# Domain docs

How engineering skills consume the project's domain documentation. The profile's `Domain docs` section says where the files are and which language rules the glossary follows.

## Before exploring, read these

- the glossary (`CONTEXT.md` at the backlog root unless the profile says otherwise): the domain terms;
- `architecture/adr/`: the ADRs that touch the area you are about to work in. Other notes in `architecture/` may also be relevant.

If any of these files do not exist, **proceed silently**. Do not flag their absence and do not suggest creating them upfront. The `/domain-modeling` skill creates them lazily when terms or decisions actually get resolved.

## File structure

Single-context:

```text
/
├── CONTEXT.md
└── architecture/
    └── adr/
        ├── 0001-<decision>.md
        └── 0002-<decision>.md
```

## Use the glossary's vocabulary

When your output names a domain concept (in a ticket title, a refactor proposal, a hypothesis, a test name), use the term as defined in the glossary. Do not drift to synonyms the glossary explicitly avoids.

Glossary terms are canonical in English, matching the code. When the profile's language is not English, the profile's `Domain docs` section says how the two languages are laid out in the glossary and which term goes on the board and into tickets.

If the concept you need is not in the glossary yet, either you are inventing language the project does not use (reconsider) or there is a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (…), but worth reopening because…_
