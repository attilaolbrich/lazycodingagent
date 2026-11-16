# 025 — Brain schema

Depends on: [024-task-confluence-connector.md](024-task-confluence-connector.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

The app can store memories in two scopes: this workspace, or the user (all workspaces on this machine). Nothing is extracted automatically yet. The Brain dialog can stay a preview. Tests prove workspace A cannot read workspace B's project memories, and a user-level memory is not copied into a project table.

## 2. Out of scope

- Do not extract lessons from chats (task 026).
- Do not inject memories into prompts (task 027).
- Do not add an HTTP brain client (task 028).
- Do not fine-tune a model.

## 3. Read these files first

- [`future-plan/Lazarus_AI_Agent_Future_Plan.md`](../future-plan/Lazarus_AI_Agent_Future_Plan.md) section 8.
- [`frmTheBrainConfig.pas`](../frmTheBrainConfig.pas) — leave behavior mostly unchanged unless a read-only count is trivial. Do not build the approve UI here.
- Global vs workspace migrations. User-level rows go in **global.db**. Workspace-level rows go in **workspace.db**.
- Latest migration versions: workspace was **7** after task 021; global was **4** after task 003. Confirm in `uAppDatabase.pas` before adding the next numbers. Add the next integer. Do not renumber old migrations.

## 4. Design decisions already made

- Same column shape in both databases:

```sql
CREATE TABLE brain_memories (
  id TEXT PRIMARY KEY,
  scope TEXT NOT NULL CHECK (scope IN ('workspace','user')),
  mem_type TEXT NOT NULL CHECK (mem_type IN ('episodic','semantic','procedural')),
  body TEXT NOT NULL,
  evidence_trace_id TEXT NOT NULL DEFAULT '',
  confidence REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL CHECK (status IN ('candidate','approved','rejected','superseded')),
  supersedes_id TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX idx_brain_status ON brain_memories(status, mem_type);
```

- In `workspace.db`, a trigger or a check in the repository rejects `scope` other than `workspace`. In `global.db`, the repository rejects `scope` other than `user`. Do both: CHECK constraint per database is awkward if the SQL is shared. **Decision:** one SQL text, and the repository method refuses the wrong scope before insert. Add a test that the workspace repository returns an error for `scope=user` and writes nothing.
- Interface GUID: `{C2F567B9-1483-4600-D5CA-E61729D7ABFC}`

```pascal
TBrainMemory = record
  Id: string;
  Scope: string;
  MemType: string;
  Body: string;
  EvidenceTraceId: string;
  Confidence: Double;
  Status: string;
  SupersedesId: string;
  CreatedAt: string;
  UpdatedAt: string;
end;
TBrainMemories = array of TBrainMemory;

IBrainBackend = interface
  ['{C2F567B9-1483-4600-D5CA-E61729D7ABFC}']
  function Add(const AWorkspaceId: string; const AMemory: TBrainMemory; out AError: string): Boolean;
  procedure List(const AWorkspaceId, AScope, AStatus: string; out ARows: TBrainMemories);
  function SetStatus(const AWorkspaceId, AId, AStatus: string; out AError: string): Boolean;
  procedure Delete(const AWorkspaceId, AId: string);
end;
```

- `List` with `AScope = 'workspace'` reads only that workspace database. `AScope = 'user'` reads only global. `AScope = 'all'` returns both, still filtered by status, and must not open other workspace ids.
- `Add` for workspace writes only that workspace file. It does not also insert a global row.
- Local class `TLocalBrainBackend` in `uBrainBackend.pas`. SQL only in `data/sqlite/uSqliteBrainRepository.pas`.
- Factory `CreateBrainBackend: IBrainBackend` returns the local class.
- No extraction, no prompt edits.

## 5. Step-by-step implementation

1. Migrations: global next version and workspace next version, each creating `brain_memories` if missing. Update fresh-db version assertions.
2. Repository and backend.
3. Tests `tests/test_brain_schema.lpr`:
   - Add workspace memory on ws A. `List('B','workspace','approved')` is empty. `List('A','workspace',...)` returns it.
   - Add user memory. It is visible from `List('A','user',...)` and `List('B','user',...)` because it is global. It is **not** present in workspace A's `brain_memories` table (open the workspace DB and assert the user memory id is absent). `List` with scope user may still show it via global.
   - `Add` with workspace id A and `Scope='user'` fails or writes only global — **decision:** `Add` uses `AMemory.Scope`. If scope is `user`, ignore the workspace table. If scope is `workspace`, do not write global. Test both directions: after a workspace add, global table does not contain that id.
   - `Delete` on workspace A does not delete workspace B's row.
   - Status `nope` fails the check (exception or error) and does not insert.
4. Register units. `run_tests.sh`. App `lazbuild` if the factory is linked.

## 6. Security

- Isolation tests above are mandatory.
- Body is data. No SQL concatenation.
- Do not store API keys in `body` in tests except a later filter task. This task does not need to redact. Do not log bodies.

## 7. Speed

- `List` filters in SQL (`WHERE status = ?1`) with the index. Do not load every memory and filter in a loop except the `all` scope, which is two queries.
- No model call.

## 8. Cloud extraction seam

`IBrainBackend` is the cloud port. `CreateBrainBackend` is what UI and later tasks call. Task 028 may wrap it. `TLocalBrainBackend` stays the offline implementation.

## 9. Tests

```bash
lazbuild tests/test_brain_schema.lpi && tests/test_brain_schema
```

## 10. README and help updates

[`help/app-data-storage.md`](../help/app-data-storage.md): user memories in `global.db`, workspace memories in that workspace's `workspace.db`. They are not copied into each other. Learning is still off until the next tasks; do not say the app already learns. [`help/workspace-layout.md`](../help/workspace-layout.md): The Brain dialog note can say storage exists and automatic learning is not on yet.

## 11. Done when

- [ ] Workspace A and B are isolated.
- [ ] User memory is not duplicated into the workspace table.
- [ ] Invalid status does not insert.
- [ ] Checkbox 025 checked, **NEXT** is task 026.

## 12. Stop

Do not extract candidates.
