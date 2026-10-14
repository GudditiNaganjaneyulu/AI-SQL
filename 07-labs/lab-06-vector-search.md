# Lab 6 — Vector Search (No AI Account Needed)

**Goal:** understand vectors, distance metrics, exact (KNN) vs approximate (ANN) search, and vector indexes — using small **hand-made vectors** so you don't need an embedding model yet.

**Requirements:** Azure SQL Database, SQL database in Fabric, or SQL Server 2025. On **SQL Server 2025**, vector indexes are preview:

```sql
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
```

## Part A — Vectors you can reason about

Real embeddings have ~1,536 dimensions nobody can interpret. Here we use **3 dimensions with meaning**:

`[ sleeping/shelter , cooking/water , wearing ]`

```sql
DROP TABLE IF EXISTS Sales.ProductConcepts;
CREATE TABLE Sales.ProductConcepts
(
    ProductID int NOT NULL PRIMARY KEY REFERENCES Sales.Products (ProductID),
    V vector(3) NOT NULL
);

INSERT INTO Sales.ProductConcepts (ProductID, V)
SELECT ProductID,
       CAST(CASE Category
                WHEN N'Camping'  THEN '[0.90, 0.10, 0.05]'
                WHEN N'Cooking'  THEN '[0.10, 0.90, 0.05]'
                WHEN N'Clothing' THEN '[0.10, 0.05, 0.90]'
                WHEN N'Footwear' THEN '[0.05, 0.05, 0.85]'
                WHEN N'Packs'    THEN '[0.50, 0.20, 0.40]'
                ELSE                  '[0.40, 0.30, 0.30]'
            END AS vector(3))
FROM Sales.Products;
```

1. Inspect a vector and its properties:

```sql
DECLARE @v vector(3) = '[0.90, 0.10, 0.05]';
SELECT @v AS v,
       VECTORPROPERTY(@v, 'Dimensions') AS dims,
       VECTORPROPERTY(@v, 'BaseType')   AS base_type,
       VECTOR_NORMALIZE(@v, 'norm2')    AS unit_v;
```

2. "I want something to **cook dinner** with" → query vector `[0.1, 0.95, 0.0]`. Return the 5 closest products by **cosine** distance:

```sql
DECLARE @q vector(3) = '[0.10, 0.95, 0.00]';
SELECT TOP (5) p.Name, p.Category,
       VECTOR_DISTANCE('cosine', c.V, @q) AS distance
FROM Sales.ProductConcepts AS c
JOIN Sales.Products AS p ON p.ProductID = c.ProductID
ORDER BY distance;
```

3. Change the query to "something **warm to wear** under 200": vector `[0.05, 0.0, 1.0]` **plus** `WHERE p.Price < 200`. This is the core pattern: **semantic ranking + relational filtering**.

4. Compare metrics for the same pair:

```sql
DECLARE @a vector(3) = '[0.90, 0.10, 0.05]', @b vector(3) = '[0.10, 0.90, 0.05]';
SELECT VECTOR_DISTANCE('cosine', @a, @b)    AS cosine,
       VECTOR_DISTANCE('euclidean', @a, @b) AS euclidean,
       VECTOR_DISTANCE('dot', @a, @b)       AS neg_dot;
```

## Part B — Approximate search with a vector index

A vector index needs **at least 100 rows**. Create 2,000 synthetic vectors:

```sql
DROP TABLE IF EXISTS dbo.MockDocs;
CREATE TABLE dbo.MockDocs
(
    id int NOT NULL PRIMARY KEY,
    title nvarchar(100) NOT NULL,
    category nvarchar(20) NOT NULL,
    embedding vector(5) NOT NULL
);

INSERT INTO dbo.MockDocs (id, title, category, embedding)
SELECT s.value,
       CONCAT(N'Doc ', s.value),
       CASE s.value % 4 WHEN 0 THEN N'tents' WHEN 1 THEN N'stoves' WHEN 2 THEN N'jackets' ELSE N'boots' END,
       CAST(JSON_ARRAY(SIN(s.value * 0.10), COS(s.value * 0.10), SIN(s.value * 0.37),
                       COS(s.value * 0.53), SIN(s.value * 0.71)) AS vector(5))
FROM GENERATE_SERIES(1, 2000) AS s;
```

5. **Exact KNN** baseline — save the true top 10:

```sql
DECLARE @q vector(5) = '[0.5, 0.5, 0.1, -0.2, 0.3]';

DROP TABLE IF EXISTS #exact;
SELECT TOP (10) id, VECTOR_DISTANCE('cosine', embedding, @q) AS distance
INTO #exact
FROM dbo.MockDocs
ORDER BY distance;

SELECT * FROM #exact ORDER BY distance;
```

6. Create the **DiskANN** index:

```sql
CREATE VECTOR INDEX VIX_MockDocs_Embedding
    ON dbo.MockDocs (embedding)
    WITH (METRIC = 'cosine', TYPE = 'DiskANN');
```

7. **Approximate** search and **recall** against the baseline:

```sql
DECLARE @q vector(5) = '[0.5, 0.5, 0.1, -0.2, 0.3]';

DROP TABLE IF EXISTS #ann;
SELECT TOP (10) WITH APPROXIMATE d.id, r.distance
INTO #ann
FROM VECTOR_SEARCH(TABLE = dbo.MockDocs AS d, COLUMN = embedding,
                   SIMILAR_TO = @q, METRIC = 'cosine') AS r
ORDER BY r.distance;

SELECT COUNT(*) * 10 AS recall_percent
FROM #ann AS a JOIN #exact AS e ON e.id = a.id;
```

> If `SELECT … INTO` with `WITH APPROXIMATE` is rejected on your platform, run the SELECT without `INTO`, and compare the id lists by eye.

8. **Iterative filtering** — top 5 *jackets* only:

```sql
DECLARE @q vector(5) = '[0.5, 0.5, 0.1, -0.2, 0.3]';
SELECT TOP (5) WITH APPROXIMATE d.id, d.title, d.category, r.distance
FROM VECTOR_SEARCH(TABLE = dbo.MockDocs AS d, COLUMN = embedding,
                   SIMILAR_TO = @q, METRIC = 'cosine') AS r
WHERE d.category = N'jackets'
ORDER BY r.distance;
```

9. Prove the table is **not read-only** with a latest-version index: insert a row whose vector equals `@q`, then re-run step 8 with `category = 'jackets'` for that row — it should come first with distance ≈ 0.

```sql
INSERT INTO dbo.MockDocs (id, title, category, embedding)
VALUES (9999, N'Exact match', N'jackets', '[0.5, 0.5, 0.1, -0.2, 0.3]');
```

10. Try these and read the errors (they're exam material):

```sql
DECLARE @q vector(5) = '[0.5, 0.5, 0.1, -0.2, 0.3]';
-- a) ORDER BY a second column with APPROXIMATE
SELECT TOP (5) WITH APPROXIMATE d.id, r.distance
FROM VECTOR_SEARCH(TABLE = dbo.MockDocs AS d, COLUMN = embedding, SIMILAR_TO = @q, METRIC = 'cosine') AS r
ORDER BY r.distance, d.id;

-- b) Metric that doesn't match the index — runs, but as exact kNN with a warning
SELECT TOP (5) d.id, r.distance
FROM VECTOR_SEARCH(TABLE = dbo.MockDocs AS d, COLUMN = embedding, SIMILAR_TO = @q, METRIC = 'euclidean') AS r
ORDER BY r.distance;

-- c) TRUNCATE a table that has a vector index
TRUNCATE TABLE dbo.MockDocs;
```

11. Inspect the index:

```sql
SELECT * FROM sys.vector_indexes;
```

## Reflection

- Why was the exact query perfectly fine for `Sales.ProductConcepts` (20 rows)?
- What would change if `MockDocs` had 5 million rows?
- What must match between the index and the query for the ANN index to be used?

## Clean up

```sql
DROP TABLE IF EXISTS dbo.MockDocs;
DROP TABLE IF EXISTS Sales.ProductConcepts;
```
