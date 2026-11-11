# m1-read-through-syntax-schemes — Syntax scheme repository

**Status:** Not started

**Depends on:** [m1-global-schema-v2.md](m1-global-schema-v2.md) — requires `syntax_schemes` table in global migration.

## Goal

`ISyntaxSchemeRepository` + SQLite adapter. `uSyntaxSchemeRegistry.pas` loads and saves scheme `json_body` in `global.db` (§5.1). Built-in generic scheme seeded via migration or first-run seed row.

## Deliverables

- Add `syntax_schemes` to global migration v2 (or v3) if not done in m1a completion.
- Interface + `uSqliteSyntaxSchemeRepository.pas`.
- Integration in `uSyntaxSchemeRegistry.pas`; stop writing `syntax-schemes.json` / per-id files at runtime.

## Acceptance criteria

- [ ] Custom schemes round-trip through SQLite after edit/save.
- [ ] Built-in schemes identifiable (`built_in` flag).
- [ ] Editor behavior unchanged for users on SQLite-backed schemes.

## References

- Parent §5.1 `syntax_schemes`, `uSyntaxSchemeRegistry.pas`
