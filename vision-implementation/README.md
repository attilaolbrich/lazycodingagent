# Vision implementation queue

This folder is the **only** execution queue for the future plans.

Design reference (do not execute from these):

- [future-plan/Lazarus_AI_Agent_Future_Plan.md](../future-plan/Lazarus_AI_Agent_Future_Plan.md)
- [future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md](../future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md)
- [future-plan/sqlite/](../future-plan/sqlite/) (schema notes; importers in that folder are cancelled)

## Rules — read this before editing code

1. Implement **only** the item marked **NEXT** below. One item. Then stop.
2. Do not start the next file in the same session. Do not combine two unchecked items.
3. When the item is done, check its box in the table, change **NEXT** to the following unchecked row, and stop.
4. Check the box only after that task's tests have been run and passed, and the README/help edits named in the task are done.
5. If a test cannot be run, leave the box unchecked and say which command failed. Do not claim success.
6. Security and speed are part of the task, not a later cleanup.
7. Persistence goes through interfaces in [`data/uRepositoryInterfaces.pas`](../data/uRepositoryInterfaces.pas) and adapters in `data/sqlite/` (HTTP clients later in `data/remote/`). Forms, [`uAgentEngine.pas`](../uAgentEngine.pas), and [`uAgentTools.pas`](../uAgentTools.pas) must not use `TSQLConnection`, `TSQLQuery`, or `sqlite3_*`.
8. Knowledge and Brain stay behind `IKnowledgeBackend` and `IBrainBackend` so a cloud implementation can replace the local one without rewriting the UI or the agent loop.
9. Leave user-owned files on disk: `<workspace>/.rules/*.md`, `<workspace>/.plan/*.md`, repository source, and shipped `help/`.
10. Secrets go through [`data/uSecurityManager.pas`](../data/uSecurityManager.pas) `EncryptSecret` / `DecryptSecret`. Do not invent a second crypto scheme. Retrieved documents and memories are untrusted evidence. Never append them to the trusted system prompt as instructions.
11. New UI stays in the existing `frm*.pas` / `.lfm` dialogs. Geometry lives in the `.lfm`. Do not mix `Align` and `SetBounds` on the same control.
12. Each task file has the same headings. Follow them from top to bottom. Do not reopen decisions in section 4.

## NEXT

**[001-task-workspace-chat-schema.md](001-task-workspace-chat-schema.md)**

## Queue

| Done | ID | Task | Summary |
| --- | --- | --- | --- |
| [x] | — | (already shipped) | Static SQLite, `global.db` through schema v3, settings and workspace registry repositories, open `global.db` at startup |
| [x] | — | (already shipped) | Workspace menu Coming Soon dialogs: Multi-Agent, Execution Plans, Knowledge Base, The Brain |
| [ ] | 001 | [001-task-workspace-chat-schema.md](001-task-workspace-chat-schema.md) | Split global vs workspace migrations; chat tables on `workspace.db` |
| [ ] | 002 | [002-task-chat-session-repository.md](002-task-chat-session-repository.md) | `uChatSessionStore` reads and writes SQLite only |
| [ ] | 003 | [003-task-syntax-scheme-repository.md](003-task-syntax-scheme-repository.md) | Syntax schemes in `global.db` |
| [ ] | 004 | [004-task-storage-help.md](004-task-storage-help.md) | User Guide and README match the SQLite layout |
| [ ] | 005 | [005-task-trace-schema.md](005-task-trace-schema.md) | Redacted execution-trace tables and repository |
| [ ] | 006 | [006-task-trace-persist-and-replay.md](006-task-trace-persist-and-replay.md) | Persist traces and replay them with no model or tool call |
| [ ] | 007 | [007-task-trace-export.md](007-task-trace-export.md) | Sanitized trace export |
| [ ] | 008 | [008-task-execution-plan-model.md](008-task-execution-plan-model.md) | Plan and task records; SQLite owns status |
| [ ] | 009 | [009-task-execution-plan-tracker-ui.md](009-task-execution-plan-tracker-ui.md) | Execution Plans dialog shows the real tracker |
| [ ] | 010 | [010-task-plan-resume.md](010-task-plan-resume.md) | Restart reconciles running tasks without re-running tools |
| [ ] | 011 | [011-task-knowledge-schema.md](011-task-knowledge-schema.md) | RAG tables and FTS5 |
| [ ] | 012 | [012-task-knowledge-local-ingest.md](012-task-knowledge-local-ingest.md) | Ingest local markdown, txt, and pasted text |
| [ ] | 013 | [013-task-embedding-provider.md](013-task-embedding-provider.md) | Embedding interface, test double, blob storage |
| [ ] | 014 | [014-task-hybrid-retrieval.md](014-task-hybrid-retrieval.md) | FTS candidates, in-process cosine, citations |
| [ ] | 015 | [015-task-knowledge-service.md](015-task-knowledge-service.md) | `IKnowledgeBackend` local service; untrusted excerpts |
| [ ] | 016 | [016-task-knowledge-tools.md](016-task-knowledge-tools.md) | Knowledge tools and bounded context enrichment |
| [ ] | 017 | [017-task-knowledge-settings-ui.md](017-task-knowledge-settings-ui.md) | Knowledge Base dialog for local sources |
| [ ] | 018 | [018-task-agent-role-model.md](018-task-agent-role-model.md) | Roles and tool allow-lists enforced in code |
| [ ] | 019 | [019-task-workflow-artifacts.md](019-task-workflow-artifacts.md) | Handoff artifacts instead of full transcripts |
| [ ] | 020 | [020-task-sequential-workflow.md](020-task-sequential-workflow.md) | Planner, approval, coder, reviewer, bounded repair |
| [ ] | 021 | [021-task-workflow-trace-links.md](021-task-workflow-trace-links.md) | Trace rows name agent, stage, and plan revision |
| [ ] | 022 | [022-task-url-ingest.md](022-task-url-ingest.md) | Scoped URL ingest with private-network blocks |
| [ ] | 023 | [023-task-pdf-text-ingest.md](023-task-pdf-text-ingest.md) | Text-layer PDF ingest, no OCR |
| [ ] | 024 | [024-task-confluence-connector.md](024-task-confluence-connector.md) | Confluence connector behind the ingest interface |
| [ ] | 025 | [025-task-brain-schema.md](025-task-brain-schema.md) | `IBrainBackend` and scoped memory tables |
| [ ] | 026 | [026-task-brain-candidates.md](026-task-brain-candidates.md) | Optional async candidates; approve, edit, reject |
| [ ] | 027 | [027-task-brain-retrieval.md](027-task-brain-retrieval.md) | Approved memories only, separate from the system prompt |
| [ ] | 028 | [028-task-remote-knowledge-brain.md](028-task-remote-knowledge-brain.md) | Remote Knowledge and Brain HTTP clients, local fallback |

## Do not start

**sqlite-vec / Phase B** is not a numbered task. Start it only after every box above is checked **and** a profiling note in this folder shows about 50k chunks in one workspace or p95 retrieve time above about 200 ms. Keep it in the same static SQLite binary, off by default. Do not add Chroma, Qdrant, Milvus, or a Docker vector server.

## Cancelled — do not implement

INI/JSON importers, `LAZYCODINGAGENT_LEGACY_STORAGE`, startup migration orchestrator, and `.bak` renames. Recovery is backup and restore of `global.db` and `workspace.db`. See `future-plan/sqlite/m2*` through `m4*`.
