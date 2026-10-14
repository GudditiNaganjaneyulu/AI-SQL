# Vector Search

> **Objectives:** *Design for vector data, including vector data type, vector indexes, and size; identify when to use VECTOR_NORMALIZE, VECTOR_DISTANCE, VECTORPROPERTY, and VECTOR_SEARCH; choose between ANN and KNN; evaluate vector index types and metrics; implement vector search.*

## The `vector` data type

```sql
column_name VECTOR(<dimensions> [, <base_type>])
```

| Base type | Bytes per dimension | Max dimensions | Status |
|---|---|---|---|
| `float32` (default) | 4 | **1,998** | GA |
| `float16` | 2 | **3,996** | GA in Azure SQL DB / MI / Fabric; **preview** on SQL Server 2025 |

```sql
CREATE TABLE dbo.Demo
(
    id   int PRIMARY KEY,
    v    vector(3)          NOT NULL,   -- float32
    v16  vector(3, float16) NULL        -- half precision: half the storage
);

INSERT INTO dbo.Demo (id, v) VALUES (1, '[0.1, 2, 30]'), (2, JSON_ARRAY(1.0, 2.0, 3.0));
DECLARE @q vector(3) = '[1, 2, 3]';
```

Vectors are **displayed and written as JSON arrays**, stored in an optimized binary format.

### Limitations to remember

- No `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK` or `DEFAULT` on vector columns (only `NULL`/`NOT NULL`).
- No comparison or arithmetic operators on vectors.
- No B-tree or columnstore index on a vector column (it can be an `INCLUDE`d column).
- Not supported in memory-optimized tables or with Always Encrypted.

### Sizing

| Dimensions | float32 per row | float16 per row | 1M rows (float32) |
|---|---|---|---|
| 384 | ~1.5 KB | ~0.75 KB | ~1.5 GB |
| 1,536 | ~6 KB | ~3 KB | ~6 GB |

Trade-offs: fewer dimensions / `float16` → less storage and faster search, possibly slightly lower quality. Test recall on your own data.

## Vector functions

| Function | Purpose | Example |
|---|---|---|
| `VECTOR_DISTANCE(metric, v1, v2)` | **Exact** distance between two vectors (never uses an index) | `VECTOR_DISTANCE('cosine', e.Embedding, @q)` |
| `VECTOR_NORMALIZE(v, norm_type)` | Scale a vector to unit length (`'norm2'` Euclidean, `'norm1'`, `'norminf'`) | Normalize before using `dot` |
| `VECTORPROPERTY(v, property)` | Inspect a vector: `'Dimensions'` or `'BaseType'` | Validate input dimensions |
| `VECTOR_SEARCH(...)` | Nearest-neighbour search, **uses a vector index** for ANN | See below |

```sql
DECLARE @a vector(2) = '[1,1]', @b vector(2) = '[-1,-1]';
SELECT VECTOR_DISTANCE('cosine',    @a, @b) AS cosine,     -- 2  (opposite)
       VECTOR_DISTANCE('euclidean', @a, @b) AS euclidean,  -- 2.828...
       VECTOR_DISTANCE('dot',       @a, @b) AS neg_dot;    -- 2  (negative of -2)

SELECT VECTORPROPERTY(@a, 'Dimensions') AS dims,
       VECTOR_NORMALIZE(@a, 'norm2')     AS unit_vector;   -- [0.7071, 0.7071]
```

### Metric ranges

| Metric | Range | Closer = |
|---|---|---|
| `cosine` | 0 → 2 | smaller |
| `euclidean` | 0 → ∞ | smaller |
| `dot` (negative dot product) | −∞ → +∞ | smaller |

**Always sort ascending by distance.**

## Exact search (KNN) with VECTOR_DISTANCE

```sql
DECLARE @q vector(1536) = AI_GENERATE_EMBEDDINGS(N'warm jacket for winter hiking' USE MODEL EmbeddingModel);

SELECT TOP (5) p.ProductID, p.Name, p.Price,
       VECTOR_DISTANCE('cosine', e.Embedding, @q) AS distance
FROM Sales.ProductEmbeddings AS e
JOIN Sales.Products AS p ON p.ProductID = e.ProductID
WHERE p.Discontinued = 0 AND p.Price <= 300          -- relational filters
ORDER BY distance;
```

Simple, 100% accurate, and fine for small or heavily filtered data sets. Cost grows with every row scanned.

## Approximate search (ANN) with a vector index

### Create the index

```sql
-- SQL Server 2025 only: vector indexes are preview there
-- ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;

CREATE VECTOR INDEX VIX_ProductEmbeddings_Embedding
    ON Sales.ProductEmbeddings (Embedding)
    WITH (METRIC = 'cosine', TYPE = 'DiskANN');
```

| Option | Values |
|---|---|
| `METRIC` | `'cosine'`, `'euclidean'`, `'dot'` — **must match the metric used in queries** or the index isn't used |
| `TYPE` | `'DiskANN'` (the supported algorithm, default) |
| `MAXDOP` | Parallelism for the build |

Key facts about current (latest-version) vector indexes:

- The table needs **at least 100 rows with non-NULL vectors** before you can create the index (error 42266 otherwise).
- **Full DML support** — inserts, updates, deletes and merges are reflected automatically. (Older index versions made the table read-only.)
- **Iterative filtering** — `WHERE` predicates are applied during the search, so you get N qualifying rows.
- You **can't** partition a vector index, use `TRUNCATE TABLE` on the table, or use `VECTOR_SEARCH` inside a view.
- Monitor with `sys.vector_indexes` and `sys.dm_db_vector_indexes`.

### Query with VECTOR_SEARCH

```sql
DECLARE @q vector(1536) = AI_GENERATE_EMBEDDINGS(N'warm jacket for winter hiking' USE MODEL EmbeddingModel);

SELECT TOP (5) WITH APPROXIMATE
       e.ProductID, p.Name, p.Price, r.distance
FROM VECTOR_SEARCH(
        TABLE      = Sales.ProductEmbeddings AS e,
        COLUMN     = Embedding,
        SIMILAR_TO = @q,
        METRIC     = 'cosine'
     ) AS r
JOIN Sales.Products AS p ON p.ProductID = e.ProductID
WHERE p.Discontinued = 0 AND p.Price <= 300
ORDER BY r.distance;
```

Rules for `SELECT TOP (N) WITH APPROXIMATE`:

- `ORDER BY` is required and may contain **only the `distance` column, ascending**.
- Reference table columns through the **TABLE alias** (`e.`), and the distance through the **result alias** (`r.distance`).
- `GROUP BY`, aggregates, window functions, `DISTINCT`, `UNION`, or extra sort columns → put the vector search in a **subquery** and apply them outside.
- `CROSS APPLY VECTOR_SEARCH` with `WITH APPROXIMATE` in the outer query isn't allowed — put `TOP … WITH APPROXIMATE` inside the applied subquery.
- Hint `WITH (FORCE_ANN_ONLY)` forces the ANN index.

> **Version note:** older vector indexes used a `TOP_N = k` argument inside `VECTOR_SEARCH`. That syntax is **deprecated** and fails (error 42274) against latest-version indexes. Learn `SELECT TOP (N) WITH APPROXIMATE`.

### What VECTOR_SEARCH does without APPROXIMATE

| Query shape | Behaviour |
|---|---|
| `TOP (N) WITH APPROXIMATE … ORDER BY distance` | ANN via the vector index (optimizer may still choose kNN when cheaper) |
| `TOP (N) … ORDER BY distance` (no APPROXIMATE) | **Exact kNN** |
| No TOP / ordered by another column | Full scan computing all distances |

## ANN vs KNN — choosing

| Situation | Choose |
|---|---|
| < ~50,000 vectors, or filters reduce candidates to a few thousand | **KNN** (`VECTOR_DISTANCE`) — exact and simple |
| Hundreds of thousands to millions of vectors, low latency required | **ANN** (vector index + `VECTOR_SEARCH`) |
| Must guarantee the exact top results (e.g., compliance, evaluation baseline) | **KNN** |
| Fewer than 100 rows | KNN (index can't be created yet) |

## Choosing a metric

- Use the metric **recommended by your embedding model** (cosine for most text embeddings).
- If vectors are normalized, cosine and dot rank identically; dot can be slightly cheaper.
- Index metric **must equal** query metric.

## Evaluating vector search

- **Recall@k:** of the true top-k (from exact KNN), how many did ANN return? Compare `VECTOR_SEARCH` results with a `VECTOR_DISTANCE` baseline on a sample of queries.
- **Latency:** `SET STATISTICS TIME ON`; Query Store.
- **Relevance:** build a small test set of questions with known good answers.
- Watch for **duplicate embeddings** — they crowd results and reduce index quality; deduplicate first.
- After re-embedding most rows (e.g., model change), **drop and recreate** the vector index.

## Knowledge check

1. What's the maximum dimension count for `vector(n)` with float32?
2. Which function always performs exact distance calculation and never uses an index?
3. What must be true of `ORDER BY` with `SELECT TOP (N) WITH APPROXIMATE`?
4. Why might `CREATE VECTOR INDEX` fail on a new table?
5. Your index uses `METRIC = 'cosine'` but the query uses `'euclidean'`. What happens?

<details>
<summary>Answers</summary>

1. 1,998.
2. `VECTOR_DISTANCE`.
3. It must order only by the `distance` column, ascending.
4. Fewer than 100 rows with non-NULL vectors.
5. The ANN index isn't used; a warning is raised and kNN (exact scan) is used.
</details>
