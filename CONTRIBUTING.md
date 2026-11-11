# Contributing to LazyCodingAgent

Thank you for your interest in contributing. This document covers workflow and
project-specific expectations. For building, running, and releasing, see
[README.md](README.md).

## Code of conduct

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## How to contribute

1. **Fork** the repository and create a branch from `main`.
2. **Make your changes** with focused commits and a clear pull request description.
3. **Open a pull request** against `main`. CI must pass (see below).
4. **Respond to review** feedback when maintainers ask for changes.

For bugs and feature ideas, use the GitHub issue forms. Do **not** report
security vulnerabilities in public issues; see [SECURITY.md](SECURITY.md).

## Continuous integration

Pull requests run [.github/workflows/build.yml](.github/workflows/build.yml):

- Linux (x86_64 and aarch64)
- Windows
- macOS

Fix any failing job before expecting a merge. You can reproduce the headless
link-and-build flow locally with `scripts/install-lca-lazarus.* --link-only`,
`scripts/install-lazarus-sqlite.*`, and `lazbuild lazycodingagent.lpi` (details
in the README).

## Lazarus and UI conventions

LazyCodingAgent is a **Lazarus + LCL** application:

- **Layout belongs in `.lfm` files** edited in the Form Designer. Open forms
  from the `.pas` unit (F12), not by hand-editing layout in Pascal.
- Prefer **LCA Design** palette components on the form for themed chrome
  ([`packages/LcaDesignSystem/`](packages/LcaDesignSystem/)).
- **Product model:** LazyCodingAgent is a professional **native desktop** app
  (menus, docked main window, **Settings and secondary flows in `frm*` dialogs**),
  not a single-surface Electron-style UI. See
  [`.cursor/rules/desktop-application-identity.mdc`](.cursor/rules/desktop-application-identity.mdc).
- Do not commit build artifacts (`lib/`, `*.ppu`, `*.o`, `dist/`, etc.); see
  [.gitignore](.gitignore).
- Avoid layout patterns that trigger LCL `ChangeBounds` loops (mixing `Align`
  with manual `SetBounds` on the same control). See project rules under
  `.cursor/rules/` for more detail.
- **Persistence:** new database code belongs behind `I*Repository` interfaces in
  `data/sqlite/` (see `.cursor/rules/persistence-and-data-access.mdc` and
  `future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md`). Do not use SQLdb
  types from forms or store units until a deliberate migration sprint.

## User-visible behavior and help

When you change behavior that users see (menus, panels, chat modes, agent tools,
settings, workspace flows), update the matching topic under [`help/`](help/) and
`help/index.json` keywords when search discoverability matters. The in-app
User Guide loads from that folder after build.

## Tests

When you change agent tools, path sandboxing, patches, shell integration, or
related logic, run:

```bash
tests/run_tests.sh
```

```bat
tests\run_tests.bat
```

Requires FPC, Lazarus `lazutils` on the unit path, and Python 3 (see README).

## Third-party code

Vendored dependencies live under [`third_party/`](third_party/). Preserve their
licenses and do not replace them with unrelated copies without discussion in an
issue or pull request.

## Pull request checklist

Use the [pull request template](.github/pull_request_template.md). In short:

- Describe what changed and how you tested it.
- Confirm no build output or secrets are included.
- Update `help/` when user-visible behavior changed.

## Questions

Open a [GitHub issue](https://github.com/olbrichattila/lazycodingagent/issues)
with the **Feature request** or **Bug report** template, or ask in an existing
discussion thread if the project enables Discussions later.
