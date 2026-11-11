# Lazarus AI Coding Agent — Future Plan

Author: Attila Olbrich  
Date: 8 October 2026  
Status: Product roadmap and architecture discussion; input for a later implementation plan.

## 1. Purpose and vision

Extend the Lazarus AI Coding Agent into a transparent software engineering workspace that can plan, execute, review and deliver features using configurable agents, persistent execution plans, workspace knowledge and optional adaptive memory.

The project also has an educational purpose: expose what happens between a user's request and the final result. Developers should be able to inspect enriched prompts, model responses, tool calls, arguments and results, and understand the boundary between the model and the application executing its requests.

Guiding principles: **Configurable. Observable. Human-controlled.**

This document consolidates the proposed features and suggestions from our discussion. User plans are stated as intended capabilities. Architectural suggestions remain recommendations until accepted during implementation planning. Examples and acceptance criteria are proposed targets, not evidence of completed work.

## 2. Current foundation and status

Based on the described application, the current foundation includes:

- A Lazarus / Free Pascal coding agent integrated with the development environment.
- AI conversations and tool execution.
- Tool Execution Logs and an Execution Detail view.
- Recording and inspection of enriched prompts, AI responses, tool usage and tool inputs/outputs.
- An educational demonstration of the agent execution loop.

The future systems below are planned. Their implementation must not be implied by placeholder UI.

Items to confirm against the code before planning implementation:

- Whether recordings preserve the exact request context as it existed at each step.
- Whether sessions can be replayed entirely offline without another model call.
- Current trace persistence, export support and redaction behavior.
- Current Windows and Linux build/runtime coverage.

Visible responses and execution traces do not necessarily expose a model's private internal reasoning. The application should describe its visibility accurately.

**Embedded persistence:** [Lazarus_Embedded_Storage_and_Vector_Plan.md](Lazarus_Embedded_Storage_and_Vector_Plan.md) specifies statically embedded SQLite for app configuration (`global.db`), per-workspace databases for chat and future indexes, and a minimal-dependency hybrid retrieval strategy for the knowledge base below. **Global settings and workspace registry already use SQLite** (`LazySqliteStatic`, `uAppDatabase`, repository adapters); chat sessions and syntax schemes remain JSON until M1 store work completes. Optional hosted Knowledge Base and Brain APIs are planned as remote backends behind the same service/repository boundaries (see embedded plan §9 and `.cursor/rules/persistence-and-data-access.mdc`).

## 3. Overall system responsibilities

| System | Responsibility |
| --- | --- |
| Agent runtime | Model interaction, context assembly, tools and execution permissions |
| Execution recorder | Evidence of requests, responses, actions and outcomes |
| Execution plans | What must be delivered, in what order, and with which completion conditions |
| Workflow orchestrator | Which agent runs next, approvals, routing and bounded repair cycles |
| Workspace knowledge | Relevant documentation and source-backed project information |
| The Brain | Optional adaptation from user feedback, preferences and execution experience |

Keep orchestration separate from an individual agent's execution loop. The orchestrator controls scheduling and authority; an agent chooses how to perform its assigned task within its tools and permissions.

## 4. Immediate UI scaffolding

### Intended scope

Expose all four future areas from the **Workspace** menu as classic modal setup dialogs (same interaction model as Project Rules and other `frm*` configuration forms). Each dialog previews the eventual settings layout with **disabled** controls, a visible **Coming Soon** label, and a read-only capabilities list sourced from the roadmap.

| Workspace menu item | Dialog title |
| --- | --- |
| Multi-Agent Workspace… | Multi-Agent Workspace |
| Execution Plans… | Execution Plans & Progress Tracking |
| Workspace Knowledge Base… | Workspace Knowledge Base (RAG) |
| The Brain… | The Brain — Adaptive Learning & Memory |

These entries are **not** on the left navigation rail. The rail keeps **Tasks & Plans**, which shows the live session todo list from the agent todo tool. **Execution Plans** (this menu item) is the future project-level numbered plan tracker described in section 6 — a separate product surface from session tasks.

### Constraints and completion criteria

- Use existing Lazarus LCL components, LCA Design themed buttons, and project form conventions (`.pas` + `.lfm`, `ApplyThemedForm`).
- Preserve chat, tools, logs, execution details and provider integration.
- Preserve Windows and Linux compatibility; avoid platform-specific UI additions.
- Add no functional agents, storage, crawling, RAG, memory or orchestration in this stage; all preview controls remain disabled.
- Compile through the existing build process and verify each menu item opens the correct dialog where available.
- Report build results and runtime checks separately; do not claim checks that were not performed.

## 5. Multi-Agent Workspace

### User's intended capabilities

Users configure multiple agents that cooperate to deliver a requested feature. A planner turns the request into a plan; after human review, a coding agent executes it. Subsequent agents perform red-pen review, code review and fixes.

Users can add or replace roles, including security review, business review and other specialist agents, and customize the workflow to their needs.

### Suggested agent configuration

| Property | Purpose |
| --- | --- |
| ID and name | Stable identity and user-facing role |
| Role and instructions | Task focus and explicit behavioral expectations |
| Model/provider | User-selected model for the role |
| Tools and permissions | Allowed actions, enforced by the runtime |
| Inputs | Requirements, plans, diffs, documents or previous findings |
| Output contract | Structured plan, implementation result or review findings |
| Routing rules | Next stage, repair route or human checkpoint |
| Limits | Time, cost, tool-call and retry boundaries |

### Suggested initial workflow

1. Planner receives the feature request and relevant workspace context.
2. Human reviews, edits or approves the plan.
3. Coder implements the approved scope and records verification evidence.
4. Red-pen reviewer challenges assumptions, unnecessary complexity and requirement gaps.
5. Code reviewer checks correctness, maintainability and verification.
6. Findings route back to the coder for repairs, followed by appropriate re-review.
7. Orchestrator presents the result and outstanding issues to the user.

Start with Planner → Human Approval → Coder → Reviewer. Add separate review roles once the handoff and repair loop work reliably.

### Architectural recommendations

- Build a configurable workflow engine rather than hard-code one permanent role sequence.
- Begin sequentially; add parallel reviews, conditional routing and workflow graphs later.
- Use artifact-based handoffs rather than copying every agent's full conversation to every other agent.
- Review inputs should include requirements, approved plan, implementation diff, relevant source and test/build results. Reviewers can retrieve more context through tools.
- Keep reviewers read-only by default. Route fixes to the coder, or explicitly grant a separate repair stage write access.
- Give reviewers independent review instructions. Different models may reduce shared assumptions, but do not guarantee independent or correct judgment.
- Bound repair cycles, for example three attempts before requesting human resolution. Make the limit configurable.
- Once parallel writers are introduced, prefer isolated Git worktrees and an explicit integration step.
- Record agent identity, workflow stage and handoff artifacts within the unified trace.

### Proposed completion criteria

A user can configure roles, approve a plan, run the workflow, inspect each agent's evidence, see review findings routed for repair, and resume an interrupted run. The orchestrator must enforce permissions and iteration limits independently of model instructions.

## 6. Execution Plans & Progress Tracking

### User's intended capabilities

Support the working approach already used on larger projects: an overall plan, numbered execution documents such as `001-step1`, a central checkbox list, ordered delivery and tracked progress.

### Suggested planning structure

1. **Project plan:** goals, requirements, architecture, scope and milestones.
2. **Numbered execution plans:** detailed tasks, dependencies and acceptance criteria.
3. **Central progress tracker:** execution order, ownership, status and evidence of actual completion.

Example repository structure, to be adapted to existing conventions:

```text
docs/ai-plans/
  project-plan.md
  progress.md
  001-foundation.md
  002-authentication.md
  003-api.md
```

### Suggested task records

- Stable task ID and display/execution order.
- Description, scope and acceptance criteria.
- Dependencies and assigned agent.
- Required permissions and approval conditions.
- Status: pending, running, blocked, awaiting review, completed or failed.
- Related files, commits, artifacts and execution trace IDs.
- Build/test results and review outcomes.
- Blocker, failure or interruption reason.
- Plan revision and approval history.

### Persistence and completion recommendations

- Treat plans and progress as persistent structured objects rather than rely on conversation memory.
- Consider version-controlled Markdown for portability and SQLite for runtime state, indexing and history.
- Decide which representation owns each field and how edits synchronize; avoid two competing sources of truth.
- The LLM proposes completion. The orchestrator marks a task complete only after its defined verification and approval conditions are satisfied.
- A checkbox should link to the execution and evidence that delivered it.
- On restart, reconcile running tasks before resuming; do not blindly repeat actions whose effects may already exist.

### Recovery and plan changes

Resume from objectives, the latest approved plan, current tracker, relevant artifacts and outstanding issues. Execute the next eligible task after checking dependencies.

Allow iterative planning. If implementation reveals missing work, propose a plan revision or additional task. Keep stable IDs even when display ordering changes. Material scope or architecture changes should go through the configured human review gate; routine detail updates can follow the workflow policy.

### Proposed completion criteria

Users can inspect and update the central tracker, execute tasks in dependency order, navigate to evidence, revise plans and restart the application without losing delivery state.

## 7. Workspace Knowledge Base (RAG)

### User's intended capabilities

Each workspace has configurable knowledge sources. The system fetches or imports content, processes it with an embedding model, indexes it for retrieval and supplies relevant information to agents.

Sources include URLs, free text, PDF, Markdown, TXT and Confluence. Confluence support should recursively index selected page hierarchies. The concept is similar to source-grounded document assistants such as NotebookLM, applied to software delivery.

### Suggested pipeline

1. Register a source and its workspace, scope and access settings.
2. Fetch/import the content.
3. Extract readable text and preserve source metadata.
4. Split content into meaningful chunks.
5. Generate embeddings using a configurable local or cloud provider.
6. Store documents, chunks, metadata and vectors.
7. Retrieve relevant material using keyword and semantic search.
8. Return excerpts with citations and source versions.
9. Refresh incrementally and remove inaccessible or deleted content.

### Suggested components

| Component | Initial recommendation |
| --- | --- |
| Document metadata/content | SQLite or an equivalent local document store |
| Vector search | Evaluate an embedded index or SQLite vector extension before adding a server |
| Embeddings | Configurable local/cloud provider |
| Extraction | Format-specific parsers; evaluate scanned PDF/OCR separately |
| Web ingestion | HTTP fetch and HTML content extraction |
| Confluence ingestion | API traversal with hierarchy, attachment and access handling |
| Retrieval | Hybrid keyword/vector search; evaluate reranking with actual examples |
| Background processing | Persistent, cancellable ingestion jobs |

These are options to evaluate for Free Pascal integration and packaging, not selected dependencies.

**Selected direction (planning):** [Lazarus_Embedded_Storage_and_Vector_Plan.md](Lazarus_Embedded_Storage_and_Vector_Plan.md) chooses embedded static SQLite for document/chunk metadata, FTS5 for keyword recall, `float32` embedding blobs with in-process vector rerank (Phase A), and optional sqlite-vec or USearch only if profiling requires approximate nearest-neighbor search (Phase B). Static SQLite, global config repositories, and migration v2 global schema are **implemented**; chat/syntax SQLite wiring, ingest, and hybrid search remain future work.

### Retrieval modes

- **Selective automatic enrichment:** retrieve relevant documents when assembling task context, with relevance and token limits.
- **Agent-driven retrieval:** tools such as `search_knowledge`, `get_document` and `list_knowledge_sources`.

Share retrieval through a workspace service rather than duplicate a separate RAG implementation for every agent.

### Source management and traceability

- Retain source URL/path, title, hierarchy, timestamps, source version and chunk identity.
- Show which excerpts influenced a plan or action in the execution trace.
- Support reindexing, removal, cancellation and clear ingestion errors.
- Detect unchanged content to avoid unnecessary embeddings.
- Distinguish one-page URL indexing from site crawling; configure permitted scope and depth.
- Preserve Confluence hierarchy and respect source access restrictions, including later permission changes.
- Track embedding model/version; changing incompatible embeddings requires reindexing or separate indexes.

### Knowledge boundaries

Documentation can be stale, contradictory or incomplete. Treat retrieved content as evidence, not as privileged instructions. Keep external text separate from trusted agent instructions and enforce workspace/document access in the application.

Eventually index approved plans, architecture decisions and useful execution outcomes. Label authoritative documentation, historical decisions, failed attempts and execution records distinctly. Mark superseded material so old decisions are not presented as current policy.

### Proposed completion criteria

A workspace can ingest supported sources, retrieve relevant excerpts with origins, update changed content, remove sources and show retrieval evidence in an agent trace. Retrieval quality should be evaluated on representative project questions before broader automation.

## 8. The Brain — Adaptive Learning & Memory

### User's intended capabilities

An optional learning agent called **The Brain** learns from conversations and working with the user. It adapts assistance to the user's preferences and the workspace's experience.

This can be implemented through extraction, persistent memory and retrieval. It does not require training or fine-tuning an LLM.

### Suggested learning inputs

- Conversations and explicit user preferences.
- Corrections, feedback and approval decisions.
- Project decisions and their scope.
- Successful and failed execution outcomes.
- Repeated tool failures or manual interventions.

### Suggested memory categories

| Type | Purpose | Example |
| --- | --- | --- |
| Episodic | Record a past event | A tool sequence failed in a specific session |
| Semantic | Capture supported knowledge | This workspace follows a particular architecture |
| Procedural | Capture working preferences | Create numbered plans for large features |

Keep user-level preferences separate from workspace-level memory. A project convention must not automatically become a universal user preference.

### Suggested memory lifecycle

1. Extract candidate lessons after a conversation or execution.
2. Attach source evidence, scope, timestamp and confidence.
3. Detect duplicates, contradictions and one-off instructions.
4. Present candidates for approval/edit/rejection under the configured memory policy.
5. Store approved memories and retrieve only those relevant to the task.
6. Allow inspection, correction, deletion and supersession.

Example candidate: a user asks to replace a new abstraction with an existing service. The Brain may propose “Prefer existing project abstractions before adding a new framework,” but should not silently turn a single local correction into a permanent global rule.

### Recommendations and boundaries

- Make learning explicitly optional, configurable per user/workspace.
- Start with asynchronous extraction and retrieval during execution to avoid latency on every tool call.
- Distinguish observed agent behavior from a confirmed user preference.
- Avoid automatic retention of secrets or sensitive information.
- Do not let The Brain silently expand tools/permissions or rewrite privileged agent instructions.
- Let it propose workflow improvements using trace evidence; review before activation.
- Define how memory deletion affects stored records, retrieval indexes and exports.

### Proposed completion criteria

Users can enable/disable learning, inspect why a memory exists, approve/edit/delete it, and see which memories were supplied to an agent. Workspace isolation and supersession should be demonstrated.

## 9. Execution Transparency and Educational Features

Continue making the recorder a central feature across all future systems.

### Suggested trace content

- User request and exact enriched request sent to the model, including available tools and supplied history.
- Model/provider identity and recorded responses.
- Tool-call IDs, names, arguments, results and failures.
- Agent, task, workflow stage and plan revision.
- Retrieved knowledge chunks and supplied memories with source/version references.
- Human approvals, routing decisions and verification outcomes.
- Timing, token usage and estimated cost where reliable provider data exists.

Distinguish exact recorded payloads from reconstructed or summarized views. Distinguish provider-reported metrics from estimates.

### Suggested interface extensions

- Unified multi-agent timeline, filterable by agent/task/stage.
- Links from completed tasks and review findings to relevant trace entries.
- A summary of model requests, tool calls, tokens and elapsed time.
- Replay of a recorded session without re-executing tools or calling the model.
- Readable presentation mode with larger Execution Detail text.
- Sanitized export for teaching and troubleshooting.

### Teaching message

The model requests actions; the application executes permitted tools and returns their results to the next model interaction. A coding agent combines an LLM with instructions, context, tools, state and a control loop.

For demonstrations, use a small synthetic project, show the original request beside the enriched prompt, inspect a tool call and its result, and explain how the result influences the next request. Recorded examples provide a fallback when live execution is unpredictable. Avoid exposing API keys or confidential code in trace exports or screen sharing.

## 10. Example End-to-End Future Workflow

Request: “Implement a reporting endpoint according to our architecture and security standards.”

1. Load workspace objectives and relevant approved preferences.
2. Retrieve architecture, API and security documentation with source references.
3. Planner produces numbered tasks and acceptance criteria.
4. Human approves the plan.
5. Orchestrator selects the next eligible task and assigns the coder.
6. Coder implements and verifies the task.
7. Red-pen/code/security reviewers inspect the relevant artifacts independently.
8. Findings route to repair; re-review runs within the configured limits.
9. Tracker records completion only when required conditions pass.
10. User receives the result, verification evidence and unresolved issues.
11. The Brain optionally proposes lessons asynchronously.

Every stage links to execution evidence, and interrupted delivery can resume from persistent state.

## 11. Suggested Delivery Sequence

The order below is a recommendation for later planning, not a delivery commitment.

| Phase | Deliverable | Exit condition |
| --- | --- | --- |
| 0 | Future-feature Workspace menu and Coming Soon setup forms | All four dialogs open from the menu with disabled previews; nav rail unchanged for live views; existing UI remains usable |
| 1 | Recorder/replay foundation review | Exact trace behavior documented; persistence and replay gaps resolved |
| 2 | Persistent plans and central tracker | Tasks, approvals, evidence and restart recovery work |
| 3 | Workspace knowledge MVP | Local/free-text sources retrieve with citations and refresh correctly |
| 4 | Sequential multi-agent MVP | Planner, approval, coder, reviewer and bounded repair work |
| 5 | Extended knowledge sources | Scoped URLs and recursive Confluence indexing work |
| 6 | The Brain MVP | Optional candidate learning, review, scoped retrieval and deletion work |
| 7 | Advanced workflows | Custom roles, conditional routing and isolated parallel work validated |

Local knowledge sources are suggested before complex connectors to validate retrieval early. A basic sequential agent workflow can proceed independently of full Confluence integration. Review this ordering against actual code dependencies and priorities.

## 12. Decisions to Resolve Before Implementation

- Which existing units/components own runtime, navigation, traces and persistence?
- What is the authoritative representation of plans and task state?
- What are the structured handoff and review-finding contracts?
- Which workflow changes need human approval, and how is approval tied to a plan revision?
- Which tools may each role use, and how are permissions enforced?
- How are retries, cancellation, budgets and interrupted operations handled?
- When are isolated worktrees necessary, and who integrates their changes?
- Which embedded storage/vector option packages reliably on Windows and Linux?
- Which embedding providers and content extractors are supported first?
- How will source freshness, permissions and deletion propagate to indexes?
- What memory approval defaults, scope rules and retention policy apply?
- Can existing recordings support exact offline inspection without executing actions?

## 13. Converting This Roadmap Into Implementation Plans

Inspect the actual codebase first. Use this document as intent and design guidance, not as proof of existing capabilities.

For each phase, create a numbered execution plan containing:

- Goal, user-visible behavior and explicit exclusions.
- Existing code to reuse and affected units/forms.
- Data contracts, persistence changes and compatibility requirements.
- Ordered tasks and dependencies.
- Acceptance criteria and meaningful validation.
- Failure, interruption and recovery behavior where applicable.
- Approval points, migration needs and rollback approach.
- Links to implementation commits and execution evidence.

Maintain one central progress tracker. Keep the initial implementation small, preserve current agent functionality, and expand only after the underlying workflow and evidence are reliable.

## 14. Roadmap Checklist

- [ ] Add four future-feature navigation entries and placeholder panels.
- [ ] Confirm exact trace persistence and offline replay capabilities.
- [ ] Design persistent plans, task records and the central tracker.
- [ ] Implement ordered task execution and restart recovery.
- [ ] Define configurable agent roles, permissions and handoff contracts.
- [ ] Implement sequential workflow with approval and bounded repairs.
- [ ] Build workspace knowledge ingestion and cited retrieval.
- [ ] Add scoped URL ingestion and recursive Confluence support.
- [ ] Connect knowledge retrieval to agents and traces.
- [ ] Implement optional The Brain candidate learning and memory management.
- [ ] Connect approved memory retrieval to agent context.
- [ ] Extend traces across tasks, agents, knowledge and memory.
- [ ] Add conditional/parallel workflows with isolated writes when required.
- [ ] Validate supported Windows and Linux configurations at each relevant phase.

These checkboxes describe future roadmap work. They are not claims about implementation status.
