# 013 — Embedding provider

Depends on: [012-task-knowledge-local-ingest.md](012-task-knowledge-local-ingest.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

Chunks can store a float32 embedding blob from a pluggable provider. Tests use a deterministic fake provider with no network. A real HTTP provider is only an interface plus a stub that returns "not configured" until settings exist. Changing the model id invalidates old vectors.

No retrieval ranking yet (task 014).

## 2. Out of scope

- Do not add sqlite-vec.
- Do not send workspace source to a live API in tests.
- Do not put the API key in logs, traces, or job error text.

## 3. Read these files first

- `chunk_embeddings` columns from task 011.
- `IKnowledgeStore` from task 012. Extend it; do not make a second SQL unit.
- [`data/uSecurityManager.pas`](../data/uSecurityManager.pas) for how other keys are stored, if you add a settings key.

## 4. Design decisions already made

- Interface in `uEmbeddingProvider.pas` (no SQL):

```pascal
TEmbeddingVector = array of Single;

IEmbeddingProvider = interface
  ['{B5E8F0A2-4D16-4F99-CE53-7FA1B2603485}']
  function ModelId: string;
  function Dimension: Integer;
  function Embed(const AText: string; out AVector: TEmbeddingVector;
    out AError: string): Boolean;
end;
```

- `TDeterministicEmbedding` for tests and for default local use until a user picks an HTTP model. Algorithm: dimension 8. For each index `i`, value is based on `SHA1` of `AText + '#' + IntToStr(i)` mapped into `-1..1`, then L2-normalize. Same text and same model id always return the same vector. Model id string: `deterministic-v1`.
- HTTP stub `THttpEmbeddingProvider` compiles but `Embed` returns false and `AError = 'Embedding HTTP provider is not configured'` when endpoint or key is empty. It must not open a socket in that case. Do not implement a live vendor API in this task.
- Settings keys in `app_settings` (global), only if you store them: `embed.provider` = `deterministic` or `http`, `embed.endpoint`, `embed.api_key` stored with `EncryptSecret`. Default provider is `deterministic` so the app works offline.
- Store blob: little-endian `Single` array, length = `dim * 4` bytes. `normalized` = 1 after L2 normalize. If the vector is all zeros, leave it unnormalized and still store it (do not divide by zero).
- `procedure EmbedMissingChunks(AStore: IKnowledgeStore; AProvider: IEmbeddingProvider; const ADocumentId: string)` in `uEmbeddingProvider.pas`:
  - Load chunks for the document.
  - If a row exists in `chunk_embeddings` with the same `chunk_id` and same `model_id`, skip `Embed`.
  - If a row exists with a different `model_id`, call `Embed` and replace the row.
  - Never mix two dimensions in one row: the new write sets `dim` from the provider.
- Add store methods: `GetEmbedding(chunkId, out modelId, dim, blob)`, `UpsertEmbedding(...)`. SQL stays in `uSqliteKnowledgeStore.pas`.
- Timeout and cancel fields exist on the HTTP stub constructor (`ATimeoutMs: Integer`) even though the stub does not connect. `EmbedMissingChunks` checks a `function Cancelled: Boolean` callback between chunks.

## 5. Step-by-step implementation

1. Extend `IKnowledgeStore` and the SQLite class.
2. Implement the deterministic provider and the HTTP stub.
3. Tests `tests/test_embeddings.lpr`:
   - Same text twice: second `EmbedMissingChunks` does not call `Embed`. Count calls by wrapping the deterministic provider in the test (`FCalls`).
   - Different text: `Embed` is called.
   - After a successful embed, change the provider model id (test subclass that returns `deterministic-v2` and a different dimension, 4). `EmbedMissingChunks` calls `Embed` again and the stored `dim` is 4.
   - Blob length is `dim * SizeOf(Single)`.
   - HTTP stub with empty endpoint returns false and the test asserts no exception and no document text in `AError`.
   - A chunk whose text contains `api_key=secret` can still be embedded (it is data). The error string of a failed call must not echo the key. The deterministic provider does not fail.
4. Add to `run_tests.sh` and the app `.lpi` (`uEmbeddingProvider.pas`).

## 6. Security

- `DecryptSecret` only inside the HTTP provider when it is actually implemented later. The stub does not decrypt for a log line.
- Do not print `AText` in exceptions.
- Deterministic embeddings are not a privacy feature. Help text must not say vectors are encrypted. They are not.

## 7. Speed

- Skip `Embed` when `model_id` and chunk id match. That is the main speed rule.
- Do not embed unchanged chunks during ingest (task 012 already left them). `EmbedMissingChunks` is the only pass.
- No network on the default path. Test must finish offline.

## 8. Cloud extraction seam

Callers take `IEmbeddingProvider`. `THttpEmbeddingProvider` is the future cloud/local-server adapter. `TDeterministicEmbedding` stays the offline default. Do not `if provider = 'openai'` inside the ingest unit.

## 9. Tests

```bash
lazbuild tests/test_embeddings.lpi && tests/test_embeddings
```

## 10. README and help updates

[`help/app-data-storage.md`](../help/app-data-storage.md): embeddings are optional numeric indexes stored as blobs; the default test provider does not call the network; vectors are not encrypted. One README sentence. Do not document a vendor API.

## 11. Done when

- [ ] Identical text and model skips the provider.
- [ ] Model change replaces the blob and dimension.
- [ ] HTTP stub does not connect when unconfigured.
- [ ] Checkbox 013 checked, **NEXT** is task 014.

## 12. Stop

Do not implement cosine search.
