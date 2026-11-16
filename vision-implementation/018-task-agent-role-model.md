# 018 — Agent role model

Depends on: [017-task-knowledge-settings-ui.md](017-task-knowledge-settings-ui.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

Each workspace can store agent roles (name, instructions, model id, tool allow-list, write flag, step and retry limits). Before a tool runs, code checks the active role. A reviewer role cannot call `write_file` even if the model asks.

The Multi-Agent dialog can stay mostly Coming Soon. Add a minimal list of roles only if it fits the existing form without a layout rewrite. If that is tight, skip UI and ship the repository plus the enforcement hook. Task 020 builds the workflow. This task must enforce permissions even when the only caller is a test.

## 2. Out of scope

- Do not implement the planner/coder/reviewer loop (task 020).
- Do not add parallel agents or git worktrees.
- Do not let role instructions edit the trusted system prompt permanently. They are an extra user-role block later. This task only stores them and enforces tools.

## 3. Read these files first

- [`uAgentEngine.pas`](../uAgentEngine.pas) `ExecuteToolDirect`.
- [`uAgentTools.pas`](../uAgentTools.pas) tool names (`write_file`, `edit_file`, `apply_patch`, `shell` / the run-process tool name — read the `RegisterTool` names and use the real strings).
- [`frmMultiAgentWorkspace.pas`](../frmMultiAgentWorkspace.pas) — do not pretend the full workflow UI is done.
- Workspace migration head. After task 011 fresh databases are version **4**. This task adds workspace version **5**. Update version assertions the same way earlier tasks did.

## 4. Design decisions already made

- Roles live in the **workspace** database, not global. A project convention must not become an account-wide permission.

```sql
CREATE TABLE agent_roles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  instructions TEXT NOT NULL DEFAULT '',
  model_id TEXT NOT NULL DEFAULT '',
  tools_json TEXT NOT NULL DEFAULT '[]',
  allow_write INTEGER NOT NULL DEFAULT 0,
  max_steps INTEGER NOT NULL DEFAULT 20,
  max_retries INTEGER NOT NULL DEFAULT 3,
  updated_at TEXT NOT NULL
);
```

- `tools_json` is a JSON array of tool name strings. Empty array means **no tools**, not all tools.
- Write tools, even if listed, are denied when `allow_write` is 0. Write tool names (confirm against the registry and include every mutating one you find): `write_file`, `edit_file`, `apply_patch`, and the process-run tool if it can change the machine. Read-only tools such as `read_file`, `search_knowledge`, `get_document`, `list_knowledge_sources` are allowed when named in the list.
- Default seed rows in the same migration (deterministic ids):
  - `role-reviewer`: name Reviewer, `allow_write` 0, tools `["read_file","search_knowledge","get_document","list_knowledge_sources"]`, max_retries 3.
  - `role-coder`: name Coder, `allow_write` 1, tools include the write tools plus read tools, max_steps 20, max_retries 3.
  - Do not seed a planner with write access. Planner tools: read and knowledge tools only, `allow_write` 0, id `role-planner`.
- Interface GUID: `{E8B123D5-7049-42CC-F186-A2D4E59367B8}`

```pascal
TAgentRoleRow = record
  Id, Name, Instructions, ModelId, ToolsJson: string;
  AllowWrite: Boolean;
  MaxSteps, MaxRetries: Integer;
end;

IAgentRoleRepository = interface
  ['{E8B123D5-7049-42CC-F186-A2D4E59367B8}']
  procedure Upsert(const ARole: TAgentRoleRow);
  function Find(const AId: string; out ARole: TAgentRoleRow): Boolean;
  procedure ListRoles(out ARoles: array of TAgentRoleRow); { use TAgentRoleRows }
  function ToolAllowed(const ARoleId, AToolName: string): Boolean;
end;
```

- `ToolAllowed` is false when the role is missing, when the name is not in `tools_json`, or when the tool is a write tool and `allow_write` is 0.
- `ExecuteToolDirect` gains an optional role id argument with default `''`. When `''`, keep today's behavior so normal chat does not break. When non-empty, if `ToolAllowed` is false, do not run the tool. Return a tool result string `Tool not permitted for this role` and do not touch the file. The engine must check **before** the tool's `Execute`.
- A prompt, system or user, cannot add a name to `tools_json`. There is no tool `grant_tool`.

## 5. Step-by-step implementation

1. Migration v5 plus three seed roles. Transaction. If roles already exist (re-entry), skip seed with `INSERT OR IGNORE`.
2. SQLite repository `data/sqlite/uSqliteAgentRoleRepository.pas`. Bound parameters. Parse `tools_json` with `fpjson`. Invalid JSON → `ToolAllowed` false.
3. Hook `ExecuteToolDirect`.
4. Tests `tests/test_agent_roles.lpr`:
   - Reviewer `ToolAllowed('role-reviewer','write_file')` is false.
   - Reviewer `ToolAllowed(...,'read_file')` is true.
   - Coder `write_file` is true.
   - Unknown tool name is false.
   - Call the check function used by `ExecuteToolDirect` with a fake tool that increments a counter. The counter stays 0 for reviewer + `write_file`. You can test this by extracting:

```pascal
function TryAuthorizeTool(const ARoleId, AToolName: string; out ADenyReason: string): Boolean;
```

     in `uAgentRoles.pas` and calling it from `ExecuteToolDirect`. The test calls `TryAuthorizeTool` without starting a model.
   - Missing role id `nope` is denied.
5. Bump workspace version expectations in older tests to **5** if those tests open a fresh workspace and assert the latest version. Keep their table checks.
6. Register units. `run_tests.sh`.

## 6. Security

- Deny is the default for a named role with an empty tool list. Test an extra role you insert with `tools_json` `[]` and `allow_write` 1. `write_file` is still false because the name is not listed.
- `allow_write` 0 blocks write tools even if `tools_json` includes `write_file`. Insert that row and assert deny. This is the bypass test.
- Do not log full role instructions at info level if they might contain copied secrets. Not required to redact storage.

## 7. Speed

- `ToolAllowed` loads one role row per tool call, or caches the active role on the engine for the run. Cache on the engine if `ExecuteToolDirect` would otherwise query every step: load once when the role id is set, clear when it changes. One query per run, not per tool, when the cache is valid.
- Index is unnecessary for a handful of roles. Primary key is enough.

## 8. Cloud extraction seam

`IAgentRoleRepository` is the port. Enforcement uses `ToolAllowed`, not SQL, so a remote role service can answer the same question. `TryAuthorizeTool` depends on the interface.

## 9. Tests

```bash
lazbuild tests/test_agent_roles.lpi && tests/test_agent_roles
```

## 10. README and help updates

[`help/workspace-layout.md`](../help/workspace-layout.md): roles can be stored per workspace; a reviewer cannot run write tools. If the dialog is still Coming Soon, say configuration UI is not finished and the permission check exists for the workflow that follows. Do not claim the full multi-agent product is done.

[`help/how-the-agent-works.md`](../help/how-the-agent-works.md): tool permission is enforced by the application, not by the prompt.

## 11. Done when

- [ ] Reviewer cannot authorize `write_file` even if the JSON lists it and `allow_write` is 0.
- [ ] Empty allow-list denies every tool.
- [ ] Normal chat with empty role id still runs tools (existing tool tests, or a direct note that `TryAuthorizeTool` is not called when role id is empty — add a test that the engine helper returns true immediately when role id is `''` without reading the database).
- [ ] Checkbox 018 checked, **NEXT** is task 019.

## 12. Stop

Do not build the orchestrator loop.
