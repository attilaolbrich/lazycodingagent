# Application data storage

LazyCodingAgent keeps application settings and the workspace registry in a SQLite database under your user config area.

## Location

On a typical Linux setup:

- Database: `~/.config/lazycodingagent/lazycodingagent/global.db`
- Per-workspace databases (when used): `…/lazycodingagent/workspaces/<workspaceId>/workspace.db`

The exact config root follows Lazarus `GetAppConfigDir` (under a `lazycodingagent/` subfolder).

## What is stored

In **`global.db`:**

- LLM provider settings and saved model lists
- Web search connection settings and API keys
- Browser automation preferences
- Workspace registry (list of workspaces and active workspace id)
- Panel layout and general application preferences

**Still on JSON files (until later storage work):**

- Chat sessions: `…/lazycodingagent/sessions/<workspaceId>.json`
- Syntax highlighting schemes: `syntax-schemes.json` and related files under `syntax-schemes/`

## Secrets

API keys and similar secrets are **obfuscated** in the database before they are written, using built-in Free Pascal code (embedded key material, per-secret salt, and Base64 storage). No OpenSSL or other crypto DLL is required for settings. This protects casual inspection of backup files; it does **not** stop someone who has both the application binary and your database file from recovering keys (the app embeds the decryption material).

## Recovery

If something goes wrong with application settings:

1. Quit LazyCodingAgent.
2. Restore `global.db` from a backup copy, or remove it to start with empty application settings (your project folders on disk are unchanged).

There is no INI/JSON import path for settings. Back up `global.db` before major upgrades if you rely on saved API keys and workspace list.
