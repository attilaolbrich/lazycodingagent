# Project rules

**Project rules** are Markdown files that tailor the agent to your repo.

## Location

Rules live under:

```
<workspace>/.rules/*.md
```

Each file is plain Markdown. The app loads **all** `.md` files in that folder and combines them into the **system prompt** for Ask, Plan, and Agent runs.

## Editing rules

Open **Workspace → Project Rules…** from the main menu.

- **Add** creates a new rule file.
- **Edit** opens the selected file in the rule editor.
- **Delete** removes a rule file from disk.

Use rules for coding standards, architecture notes, test commands, or “always do X in this repo” instructions.

## Good practices

- Keep each file focused (e.g. `testing.md`, `api-style.md`).
- Put the most important constraints near the top of a file.
- Rules apply to **every** mode; use clear language so Plan mode does not assume write access it does not have.

Rules do **not** replace the built-in safety limits (write sandbox outside the workspace unless the user opts in per session, mode-gated tools). They add **project-specific** guidance on top.
