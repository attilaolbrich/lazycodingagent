# 023 — PDF text ingest

Depends on: [022-task-url-ingest.md](022-task-url-ingest.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

The user can index a PDF that already contains a text layer. Scanned pages that yield no text produce a job error. The app does not OCR.

## 2. Out of scope

- Do not add Tesseract or any OCR package.
- Do not render PDF pages to images.
- Do not fetch PDFs from URLs in this task (the file is local, under the workspace, same path rules as markdown).

## 3. Read these files first

- Local file ingest path checks in `uKnowledgeIngest.pas` (task 012).
- Knowledge dialog file picker (task 017).
- What libraries the `.lpi` already links. Do not add a new DLL. Prefer a small pure-Pascal extraction of text between parentheses in `BT`/`ET` blocks for simple uncompressed PDF content, **or** reject the file with a clear error if the stream is compressed (`/FlateDecode`) and you cannot inflate it with an existing unit (`zstream`).

## 4. Design decisions already made

- Kind `pdf`. Extension `.pdf` only. Max size **10 MiB**. Oversize is a job error and indexes nothing.
- Extractor unit `uPdfText.pas`:

```pascal
function TryExtractPdfText(const AFileName: string; out AText, AError: string): Boolean;
```

- If the extracted text trim length is under 20 characters, return false with `AError = 'No text layer in PDF'`. Do not write chunks.
- If extraction hits an unsupported encoding, return that error. Do not guess via OCR.
- Successful text goes through the same chunker, hash, and embed path as markdown.
- Path must stay inside the workspace (reuse the task 012 check).
- Enable the PDF control on the knowledge form, or accept `.pdf` in the existing file dialog and branch on extension. One picker is better than a second button if the form is crowded. Document which control you used.
- Ship a tiny fixture `tests/fixtures/knowledge/hello.pdf` that you generate in the test program with a minimal uncompressed PDF containing the visible text `PdfHelloToken`. Building the bytes in the test is better than committing a binary if the test can write the file itself. Use this minimal structure only if your extractor supports it; otherwise write the fixture to match the extractor you implemented and keep the token.

A known-minimal approach: write a one-page PDF in the test as ASCII (PDF 1.1, Helvetica, one `Tj` string `(PdfHelloToken)`, no compression). Implement the extractor to read that `Tj` string. Document the supported subset at the top of `uPdfText.pas`: uncompressed simple `Tj` strings only. Other files return `Unsupported PDF`. That subset is acceptable. Do not spend the task on a full PDF stack.

## 5. Step-by-step implementation

1. `TryExtractPdfText` for the subset above.
2. Ingest branch for `.pdf`.
3. Tests:
   - Fixture text extracts to a string containing `PdfHelloToken`.
   - Ingest creates a chunk containing that token.
   - A file that is not a PDF (rename a `.txt`) returns an error and no chunk.
   - Extractor on a PDF body you construct with no `Tj` text returns `No text layer in PDF` and the word OCR does not appear as a taken action (assert you did not add a unit named tesseract or ocr).
   - Path `../x.pdf` is rejected.
4. Form accepts the file. `lazbuild` the app.
5. `run_tests.sh`.

## 6. Security

- Same directory confinement as local files.
- Do not launch an external process (`pdftotext`, shell) to parse the file. In-process only. The test can assert the extractor unit does not use `Process`.
- PDF content is untrusted chunk text.

## 7. Speed

- 10 MiB cap before parse.
- Do not render pages.
- One document transaction, same as markdown ingest.

## 8. Cloud extraction seam

`TryExtractPdfText` is a local function behind ingest. `IKnowledgeIngest` stays the service boundary. A cloud extractor can replace the function later inside the connector, not inside the form.

## 9. Tests

```bash
lazbuild tests/test_pdf_ingest.lpi && tests/test_pdf_ingest
lazbuild lazycodingagent.lpi
```

## 10. README and help updates

Help: PDF text-layer only, no OCR, size cap, unsupported files show an error. Remove the "PDF not available" sentence from task 017's help. README one sentence.

## 11. Done when

- [ ] Fixture PDF indexes `PdfHelloToken`.
- [ ] Empty text layer errors and does not OCR.
- [ ] No external process and no path escape.
- [ ] Checkbox 023 checked, **NEXT** is task 024.

## 12. Stop

Do not start the Confluence client.
