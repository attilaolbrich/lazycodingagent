# 022 — URL ingest

Depends on: [021-task-workflow-trace-links.md](021-task-workflow-trace-links.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

A knowledge source can be a URL. The default is one page. An optional depth downloads linked pages up to a hard cap. Private and link-local addresses are refused. HTML becomes text. The Knowledge Base dialog can add a URL using the control that was disabled in task 017.

## 2. Out of scope

- Do not crawl the whole site by default.
- Do not run JavaScript or browser automation for this ingest.
- Do not add PDF parsing (task 023) or Confluence (task 024).
- Tests must not require the public internet.

## 3. Read these files first

- `IKnowledgeIngest` and `TIngestRequest` from task 012.
- [`uWebFetchHttp.pas`](../uWebFetchHttp.pas) or the existing fetch tool — reuse timeout and size limits if they are sane. Do not reuse a function that follows arbitrary redirects to file URLs.
- [`frmKnowledgeBaseConfig.pas`](../frmKnowledgeBaseConfig.pas) disabled URL controls.

## 4. Design decisions already made

- New kind `url`. Implement `TUrlKnowledgeConnector` in `uKnowledgeUrlIngest.pas` that the local ingest calls when `Kind = 'url'`. Keep `IKnowledgeIngest` as the only interface the form uses. Extend `Start` so `Kind = 'url'` is legal. Locator is the URL. `Text` is empty.
- Depth: `config_json` integer `depth`. Default 0 (this page only). Maximum **2**. Maximum pages **20** including the first. Maximum bytes per page **1_000_000**. Timeout **15** seconds per page.
- Allowed schemes: `http` and `https` only. Reject `file:`, `ftp:`, `gopher:`, `javascript:`, and empty.
- Before connect, resolve the host. Refuse if any address is:
  - loopback (`127.0.0.0/8`, `::1`),
  - link-local (`169.254.0.0/16`, `fe80::/10`),
  - private (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `fc00::/7`),
  - unspecified `0.0.0.0`,
  - the metadata host name `metadata.google.internal`.
- Redirects: at most 3. Re-check the new host against the same rules. If the redirect target fails the check, stop with job error `blocked address`.
- HTML to text: strip `script`, `style`, and tags. Keep link `href` text only as visible text. Do not evaluate HTML. A small state machine or a simple tag strip is enough. Do not add a browser engine.
- Store `documents.loc` as the final URL. `fetched_at` is the ISO time. `knowledge_sources.kind` is `url`. `uri` is the start URL.
- Same chunker and hash as task 012. Then embeddings via the existing worker path used by the dialog.
- Tests inject a fetcher:

```pascal
IHttpGet = interface
  function Get(const AUrl: string; out ABody, AContentType, AError: string;
    out AStatus: Integer): Boolean;
end;
```

  The connector takes `IHttpGet`. Production code uses a class that performs the real request **after** the address check. Tests pass a fake that returns HTML for `http://example.test/a` and would return a body for `http://127.0.0.1/` if called. The test asserts the fake's call count for `127.0.0.1` is **0**.

## 5. Step-by-step implementation

1. Address check unit `uUrlSafety.pas` with pure functions `function UrlIsSafe(const AUrl: string; out AReason: string): Boolean`. For host names that are not IPs, the test can pass a resolver callback:

```pascal
TResolveProc = function(const AHost: string): string of object;
```

   so tests do not do real DNS. Production resolver uses the OS and then checks every returned address. If resolution fails, refuse.
2. Connector uses `IHttpGet` only after `UrlIsSafe`.
3. Wire `Kind = 'url'` in `TLocalKnowledgeIngest`.
4. Enable the URL field and depth control on the knowledge form. Cap the spin edit or combo at 2 in the `.lfm` if possible, and again in code.
5. Tests `tests/test_url_safety.lpr` (no network):
   - `http://127.0.0.1/x` false.
   - `http://169.254.169.254/` false.
   - `http://10.1.2.3/` false.
   - `http://192.168.0.5/` false.
   - `file:///etc/passwd` false.
   - `http://example.test/a` true when the resolver returns `93.184.216.34` (a public address used only as a fixture; do not connect).
   - Host that resolves to `10.0.0.1` is false even if the name looks public.
6. Ingest test with fake `IHttpGet`: one HTML page containing `UniqueUrlToken` becomes a chunk. A page that links to `http://127.0.0.1/secret` at depth 1 does not call Get on that URL.
7. `run_tests.sh`. `lazbuild` the app.

## 6. Security

- The blocked-address tests are the security gate. All of them must pass.
- Do not disable the check with a setting in this task.
- Fetcher is not called when the check fails.
- HTML is text, stored as untrusted chunks, never executed.

## 7. Speed

- Caps: depth 2, 20 pages, 1 MB, 15 s. Enforce them in the connector, not only in the form.
- Do not download page bodies for blocked hosts.
- Sequential fetches are enough. No thread pool.

## 8. Cloud extraction seam

`IHttpGet` and `IKnowledgeIngest` keep HTTP out of the form. A remote knowledge service can accept a URL itself later; the safety check should still run on the desktop before sending a URL to a backend, so the desktop does not ask the cloud to fetch `127.0.0.1`.

## 9. Tests

```bash
lazbuild tests/test_url_safety.lpi && tests/test_url_safety
lazbuild lazycodingagent.lpi
```

## 10. README and help updates

Help: how to add a URL, the depth cap, and that local/private addresses are refused. Update the task 017 sentence that said URL ingest is unavailable. [`help/tools-reference.md`](../help/tools-reference.md) only if a tool changed (it should not; ingest is the dialog). README one sentence.

## 11. Done when

- [ ] All blocked-address cases pass and the fake fetcher is not called for them.
- [ ] A public fixture URL indexes through the fake fetcher.
- [ ] Dialog can start a URL source.
- [ ] Checkbox 022 checked, **NEXT** is task 023.

## 12. Stop

Do not add PDF parsing.
