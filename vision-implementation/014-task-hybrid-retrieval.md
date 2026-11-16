# 014 — Hybrid retrieval

Depends on: [013-task-embedding-provider.md](013-task-embedding-provider.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

A query returns the top K chunks with citations. Keyword search (FTS5) picks at most 200 candidates. Cosine similarity re-ranks those candidates only. No sqlite-vec.

There is still no agent tool (task 016) and no dialog (task 017).

## 2. Out of scope

- Do not scan every embedding in the workspace when FTS returns zero rows. Return empty.
- Do not add a vector server.
- Do not send the query to an HTTP embedding API in the unit test. The test uses `TDeterministicEmbedding` and pre-stored blobs.

## 3. Read these files first

- `chunks_fts` triggers from task 011.
- `IEmbeddingProvider` and blob layout from task 013.
- [`future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md`](../future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md) section 7.1 and 7.3.

## 4. Design decisions already made

- New unit `uVectorMath.pas`, no SQL, no HTTP:

```pascal
function Dot(const A, B: TEmbeddingVector): Single;
function L2Norm(const A: TEmbeddingVector): Single;
function Cosine(const A, B: TEmbeddingVector): Single;
```

  Length mismatch returns cosine `0` (do not raise). Zero norm returns `0`.
- FTS candidate cap is **200**. If the caller asks for more, clamp to 200.
- Default top K is **8**. Clamp K to 1..50.
- Optional MMR: parameter `ADedupeBySource: Boolean`. When true, keep at most **2** chunks from the same `source_id` in the final K. This is the MMR stand-in. Do not add a second dependency.
- Query embedding: caller passes an `IEmbeddingProvider` and the query string. `Embed` the query once. If `Embed` fails, return an error and no hits. Do not fall back to dumping arbitrary chunks.
- FTS: build a safe MATCH string. Allow only letters, digits, and spaces from the user query. Drop other characters. If nothing remains, return empty (do not `MATCH` the raw query). Bind the sanitized string as `?1`. Quote it as a phrase or as AND of tokens: join tokens with ` OR ` after each token is already alphanumeric. Cap token count at 16.
- Interface GUID: `{C6F901B3-5E27-40AA-DF64-80B2C3714596}`

```pascal
TKnowledgeHit = record
  SourceId: string;
  DocumentId: string;
  ChunkId: string;
  Title: string;
  Loc: string;
  Excerpt: string;
  ContentHash: string;
  Score: Single;
end;
TKnowledgeHits = array of TKnowledgeHit;

IKnowledgeIndexRepository = interface
  ['{C6F901B3-5E27-40AA-DF64-80B2C3714596}']
  procedure Search(const AQuery: string; AProvider: IEmbeddingProvider;
    ATopK: Integer; ADedupeBySource: Boolean;
    out AHits: TKnowledgeHits; out AError: string);
end;
```

- Implementation `TSqliteKnowledgeIndex` in `data/sqlite/uSqliteKnowledgeIndex.pas` uses the open workspace db the same way other adapters do. It may use SQL because it is the adapter. `uVectorMath.pas` must not.
- Excerpt is the chunk text clipped to 500 characters plus `...` if longer. Do not return the whole file.
- Score is cosine of the query vector and the chunk vector. Chunks with no embedding are dropped, not ranked by FTS alone, in this task. (Keyword-only mode can wait.)
- Order hits by score descending.

## 5. Step-by-step implementation

1. `uVectorMath.pas` with tests in `tests/test_vector_math.lpr`:
   - Cosine of a vector with itself is about 1 (abs difference < 0.0001).
   - Cosine of `(1,0)` and `(0,1)` is 0.
   - Cosine of different lengths is 0.
   - Zero vector cosine is 0.
   This test does not need SQLite. Compile with `fpc` like other small tests, or lazbuild. Wire `run_tests.sh`.
2. Index repository. `TAppDatabase.KnowledgeIndex(AWsId)`.
3. Search test in `tests/test_knowledge_search.lpr`:
   - Insert two sources. Source A chunk text `zebra habitat`. Source B chunk text `unrelated boats` and another `zebra crossing`.
   - Store deterministic embeddings for those exact chunk strings (call the provider in the test, write blobs through `IKnowledgeStore`).
   - Also insert a chunk `zebra` **without** an embedding. It must not appear.
   - Search `zebra`. Top hit is one of the zebra chunks. `boats` is absent when K is 1 and scores differ. Assert citation fields: source id, title, loc, chunk id, excerpt contains `zebra`, content hash non-empty.
   - Insert 3 chunks from source A that would outrank source B. With `ADedupeBySource` true and K 3, at most 2 hits have source A.
   - Query `''' OR 1=1` returns empty or only real matches, and the test database still has the same chunk count (no SQL injection).
4. Register the index unit in the app `.lpi`.

## 6. Security

- The injection query test is mandatory.
- Excerpt is untrusted data. This unit only returns it in a record. It does not put it in a system prompt (task 015).

## 7. Speed

- SQL limit 200 before blobs are loaded. Do not `SELECT * FROM chunk_embeddings` for the whole workspace.
- Compute cosine in Pascal on that list only.
- One query embedding per search.

## 8. Cloud extraction seam

`IKnowledgeIndexRepository` can be implemented by a remote index later. `uVectorMath` stays local and pure so both sides can share tests. Task 015 wraps this behind `IKnowledgeBackend`.

## 9. Tests

```bash
lazbuild tests/test_vector_math.lpi && tests/test_vector_math
lazbuild tests/test_knowledge_search.lpi && tests/test_knowledge_search
```

Use `fpc` for vector math if that project has no SQLite dependency. Either way it must be in `run_tests.sh`.

## 10. README and help updates

One sentence in [`help/how-the-agent-works.md`](../help/how-the-agent-works.md): local knowledge search, when used later, combines keyword match with a numeric rank and returns a short excerpt plus its origin. Do not say the agent already calls it.

## 11. Done when

- [ ] Known-vector cosine tests pass.
- [ ] Search returns citations and ignores chunks with no vector.
- [ ] Dedupe keeps at most two hits per source.
- [ ] Hostile query does not change the database.
- [ ] Checkbox 014 checked, **NEXT** is task 015.

## 12. Stop

Do not register tools or define the prompt marker yet, except the one help sentence.
