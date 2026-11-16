# 007 — Sanitized trace export

Depends on: [006-task-trace-persist-and-replay.md](006-task-trace-persist-and-replay.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

The user can export one saved trace to a UTF-8 file (Markdown). The file is safe to share in a lesson: secrets that match the rules below are gone. The on-disk trace in SQLite is not rewritten by export.

## 2. Out of scope

- Do not export every trace in one zip.
- Do not add a cloud upload.
- Do not re-run the agent.
- Do not change how live redaction works inside the LLM client except to call this same scrubber before persisting if you find an unredacted field. Prefer scrubbing at export so you do not destroy the local debugging copy. Export output is what must be clean.

## 3. Read these files first

- `IExecutionTraceRepository.LoadEntries` and `uTraceReplay.pas` from task 006.
- [`data/uSecurityManager.pas`](../data/uSecurityManager.pas) — prefix `lca-sec:v2:`.
- The execution detail text helpers in [`uExecutionDetailText.pas`](../uExecutionDetailText.pas) if present, so export headings match the in-app labels.

## 4. Design decisions already made

- New unit `uTraceExport.pas`. Function:

```pascal
function ExportTraceMarkdown(ARepo: IExecutionTraceRepository; const ATraceId: string;
  out AMarkdown: string; out AError: string): Boolean;
```

- No SQL in this unit. It only calls the repository.
- Markdown shape:
  - Heading with trace id and session id.
  - One `##` per entry: kind, seq, timestamp.
  - Fenced blocks for payload, tool args, tool output.
- Scrubber `function RedactForExport(const S: string): string` applied to every string field before it enters the markdown.
- Replacements (case-sensitive for the prefix, case-insensitive for header names):
  - Any substring starting with `lca-sec:v2:` up to the next whitespace becomes `[redacted-secret]`.
  - JSON `"api_key"\s*:\s*"[^"]*"` becomes `"api_key":"[redacted]"`.
  - JSON `"apiKey"\s*:\s*"[^"]*"` the same.
  - `Authorization: Bearer <token>` and `"Authorization"\s*:\s*"Bearer [^"]*"` become `Authorization: Bearer [redacted]`.
  - `sk-` followed by 12 or more letters or digits becomes `[redacted-key]`.
- Do not try to detect every password. The patterns above are the required set. Add a comment that export is best-effort.
- UI: **File → Export execution trace…** or a button on the detail view, designer-owned, calls a save dialog, writes the markdown with `TStringList.SaveToFile` UTF-8. If export returns false, show `AError` in a dialog. Do not write a partial file.
- Overwrite only after the save dialog returns a path the user chose. Do not default the path to the project source tree; start in the user documents or temp folder (`GetUserDir`).

## 5. Step-by-step implementation

1. Implement `RedactForExport` with plain Pascal scans or `TRegExpr` from the `RegExpr` unit (FCL, already available). Prefer one pass that cannot throw on odd Unicode: if a regex fails to compile, fix the pattern; do not catch and return the original secret string.
2. Implement `ExportTraceMarkdown`. Unknown id → false and `AError = 'Trace not found'`.
3. Menu item in [`mainunit.lfm`](../mainunit.lfm) / [`mainunit.pas`](../mainunit.pas). Published handler. No `SetBounds`.
4. Tests `tests/test_trace_export.lpr`:
   - Fixture payload containing all of: `lca-sec:v2:aabbcc`, `"api_key":"super-secret"`, `Authorization: Bearer abc.def.ghi`, `sk-1234567890abcdef`.
   - Assert the markdown contains `[redacted` and does **not** contain `super-secret`, `aabbcc`, `abc.def.ghi`, or `sk-1234567890abcdef`.
   - Assert harmless text `print('hello')` remains.
   - Assert unknown trace id returns false and does not produce markdown with the fixture.
5. Wire the test in [`tests/run_tests.sh`](../tests/run_tests.sh).

## 6. Security

- The test in section 5 is the security check. It must fail if any listed secret survives.
- Export does not include the SQLite file.
- Do not put the redacted file path into the trace payload.

## 7. Speed

- Export loads one trace. Scrub is linear in the size of that trace. No network.

## 8. Cloud extraction seam

`ExportTraceMarkdown` takes `IExecutionTraceRepository`. A remote trace backend can be passed in later without changing the scrubber.

## 9. Tests

```bash
lazbuild tests/test_trace_export.lpi && tests/test_trace_export
```

## 10. README and help updates

- Help topic that already describes Execution Detail: add how to export and that the file is scrubbed, not a full forensic copy.
- Keywords: `export`, `redact`.
- README: one sentence next to the trace sentence from task 006.

## 11. Done when

- [ ] Export file omits the four secret patterns in the test.
- [ ] Unknown id does not write a file.
- [ ] Help describes the command you added.
- [ ] Checkbox 007 checked, **NEXT** is task 008.

## 12. Stop

Do not start execution-plan tables.
