# MCP plugins

LazyCodingAgent can connect to **Model Context Protocol (MCP)** servers and expose their tools to the agent when you reference a plugin in chat.

## Configure connections

Open **Plugins → MCP Connections...**

For each connector set:

| Field | HTTP | Stdio |
|-------|------|-------|
| **Name** | Chat `@alias` (letters, digits, underscore) | Same |
| **Connection URL** | MCP HTTP endpoint | — |
| **Bearer token** | Optional `Authorization: Bearer …` | — |
| **Command** | — | Executable path |
| **Arguments** | — | JSON array, e.g. `["--stdio"]` |
| **Working directory** | — | Optional |
| **Timeout** | Request timeout (seconds) | Same |
| **Enabled** | Include in @-mention lookup | Same |

Use **Test connection** to run `tools/list` and show how many tools the server reports.

Connections are stored in **global.db** (`mcp_connections`). Bearer tokens are encrypted like other API secrets.

## Activate in chat

In any chat message, type `@` followed by the connection **name**, for example:

```text
Summarize this using @mydocs
```

- Matching is **case-insensitive**.
- The plugin stays active for the **whole chat session** until **Agent → Clear Conversation**.
- On each agent run, the app fetches tools from active plugins and adds them to the **system prompt** (and to native tool-calling payloads when enabled).
- LLM tool names are prefixed as `mcp_<alias>_<serverToolName>` to avoid clashing with built-in tools.

Unknown `@` names are ignored (the run still starts). Configure the plugin first if you need it.

## Modes

MCP tools follow the same mode rules as built-in tools where applicable. If a plugin is unavailable (network error, bad token, process exit), the run continues; the execution log notes the failure and those tools are omitted.

## Security

- HTTP plugins send your Bearer token to the URL you configured.
- Stdio plugins run a **local command** with your user privileges—only add commands you trust.
