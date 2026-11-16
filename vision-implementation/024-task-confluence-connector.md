# 024 — Confluence connector

Depends on: [023-task-pdf-text-ingest.md](023-task-pdf-text-ingest.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

The user can index a Confluence page and its child pages, up to a page cap, using a base URL and an API token stored like other secrets. Tests use a fake HTTP client. A live Confluence server is not required.

Removing or disabling the source removes its chunks from search.

## 2. Out of scope

- Do not require a real Confluence account in CI.
- Do not index attachments or binaries.
- Do not log the token.

## 3. Read these files first

- `EncryptSecret` / `DecryptSecret` in [`data/uSecurityManager.pas`](../data/uSecurityManager.pas).
- `IHttpGet` from task 022. You may add `IHttpGetAuth` with a bearer header if `IHttpGet` cannot send a header. The token stays in the client, not in the URL.
- Knowledge source `enabled` flag and `DeleteSource`.
- [`frmKnowledgeBaseConfig.pas`](../frmKnowledgeBaseConfig.pas).

## 4. Design decisions already made

- Kind `confluence`. `uri` is the page id or the page URL the user typed. `config_json` holds `{"baseUrl":"...","email":"..."}` only. The token is **not** inside `config_json`. Store it in `app_settings` key `confluence.token.<sourceId>` via `EncryptSecret`.
- Child walk: the connector asks `IConfluenceApi`:

```pascal
TConfluencePage = record
  Id, Title, ParentId, BodyText: string;
end;

IConfluenceApi = interface
  ['{B1E456A8-0372-45FF-C4B9-D50618C69AEB}']
  function GetPage(const APageId: string; out APage: TConfluencePage; out AError: string): Boolean;
  function ListChildren(const APageId: string; out AIds: TStringArray; out AError: string): Boolean;
end;
```

- Production class `TConfluenceHttpApi` calls the REST shape `GET {base}/rest/api/content/{id}?expand=body.storage` and children `.../child/page`. If you are unsure of a field, parse `title`, `body.storage.value`, and child `id` from JSON. HTML in the storage body is stripped with the same tag strip as URL ingest. Token header: `Authorization: Bearer` plus the decrypted token. Also allow basic auth if the user filled email: `Authorization: Basic` of `email:token` when email is non-empty. Pick **one** and document it in help. Decision: **Bearer** only. Email is stored but not sent, unless you already have a tested basic-auth helper. Bearer only is the requirement.
- Page cap **50**. Depth is not separate; stop after 50 pages. Cycle guard: do not fetch an id twice.
- `documents.loc` is `confluence:<pageId>`. `title` is the page title. Parent path may be prefixed in the title as `Parent / Child` using parent titles you already fetched. That is the hierarchy.
- Disable source: `enabled = 0` **and** delete chunks for that source (call the same delete as remove, or a `HideSource` that deletes documents and chunks but keeps the source row). Search must not return them. Test this.
- Remove source: existing `DeleteSource` plus delete the `confluence.token.<id>` settings row.
- Fake API in tests returns three pages, one of them a child, body `ConfTokenAlpha`. No socket.

## 5. Step-by-step implementation

1. Interfaces and HTTP class. HTTP class is not used in the unit test.
2. Ingest branch `Kind = 'confluence'`.
3. Form fields: base URL, page id, token (password edit). Save token with `EncryptSecret`. Never set the edit's text back from the database into a log. You may show a placeholder `saved` if a blob exists.
4. Tests:
   - Fake API indexes parent and child. Chunk contains `ConfTokenAlpha`. `loc` values include both page ids.
   - Cap: fake that would return 60 children stops at 50 requests. Assert call count <= 50 + 1.
   - Disable/hide drops FTS hits for `ConfTokenAlpha`.
   - Token value `super-secret-token` is stored as an `lca-sec:v2:` blob or otherwise `IsEncryptedSecretBlob` is true. The raw token is not in `config_json`.
   - Job error from the fake does not include the token string.
5. `run_tests.sh`. `lazbuild` the app.

## 6. Security

- Secret storage test is mandatory.
- Bearer token is not put in the query string.
- URL safety: `baseUrl` must pass `UrlIsSafe` from task 022 before any HTTP class is constructed. `http://127.0.0.1` is rejected in a test.
- Page bodies are untrusted chunks.

## 7. Speed

- Page cap 50.
- Do not re-fetch an id already seen.
- Do not download attachments.

## 8. Cloud extraction seam

`IConfluenceApi` is the port. The HTTP class is one adapter. A hosted knowledge backend can ingest Confluence server-side later; the desktop form should still be able to call `IKnowledgeIngest` without knowing which adapter runs. The form does not construct `TConfluenceHttpApi` directly. The ingest unit does, only when kind is `confluence` and tests pass a fake into the ingest constructor. Add an optional parameter or setter `SetConfluenceApi` so tests do not use HTTP.

## 9. Tests

```bash
lazbuild tests/test_confluence_ingest.lpi && tests/test_confluence_ingest
lazbuild lazycodingagent.lpi
```

## 10. README and help updates

Help: what to type (base URL, page id, token), page cap, disable removes indexed text, token is stored obfuscated with the same limits as other API keys. Do not claim Confluence data is end-to-end encrypted. README one sentence. Keywords: `confluence`.

## 11. Done when

- [ ] Fake tree indexes and disable removes search hits.
- [ ] Token is encrypted at rest and absent from errors and `config_json`.
- [ ] Private base URL is rejected.
- [ ] Checkbox 024 checked, **NEXT** is task 025.

## 12. Stop

Do not start Brain tables.
