# Full-Text and Hybrid Search

> **Objectives:** *Choose from full-text, semantic vector, and hybrid search; implement full-text search; implement hybrid search; implement reciprocal rank fusion (RRF); evaluate performance of vector and hybrid search.*

## Three ways to search text

| Search type | Matches on | Strengths | Weaknesses |
|---|---|---|---|
| **Full-text (keyword)** | Words, word forms, phrases, proximity | Exact terms, product codes, names, rare words; explainable | Misses synonyms and paraphrases ("parka" vs "warm jacket") |
| **Semantic vector** | Meaning (embeddings) | Synonyms, paraphrases, cross-language (with multilingual models) | Can miss exact identifiers; needs an embedding model; less explainable |
| **Hybrid** | Both, combined | Best overall relevance in most real apps | More complex; two indexes |

**Rule of thumb:** users who type **exact codes or names** need keyword; users who **describe what they want** need semantic; general-purpose search boxes and RAG retrieval → **hybrid**.

## Full-text search

### Set up

```sql
CREATE FULLTEXT CATALOG ftCatalog AS DEFAULT;

CREATE FULLTEXT INDEX ON Sales.Products (Name, Description LANGUAGE 1033)
    KEY INDEX PK_Products                      -- a unique, single-column, non-nullable index
    WITH CHANGE_TRACKING = AUTO;               -- keep the index updated automatically
```

### Query predicates (filter)

```sql
-- Words / phrases / boolean
SELECT Name FROM Sales.Products WHERE CONTAINS(Description, N'"waterproof" AND tent');

-- Prefix
SELECT Name FROM Sales.Products WHERE CONTAINS(Name, N'"ultra*"');

-- Inflectional forms: hike, hiked, hiking
SELECT Name FROM Sales.Products WHERE CONTAINS(Description, N'FORMSOF(INFLECTIONAL, hike)');

-- Proximity
SELECT Name FROM Sales.Products WHERE CONTAINS(Description, N'NEAR((light, tent), 5)');

-- Natural language: matches meaning-ish via word forms and thesaurus
SELECT Name FROM Sales.Products WHERE FREETEXT(Description, N'lightweight shelter for two');
```

### Ranked results (table-valued)

```sql
SELECT p.Name, ft.[RANK]
FROM FREETEXTTABLE(Sales.Products, Description, N'lightweight shelter for two') AS ft
JOIN Sales.Products AS p ON p.ProductID = ft.[KEY]
ORDER BY ft.[RANK] DESC;
```

`CONTAINSTABLE` / `FREETEXTTABLE` return `[KEY]` (the key-index value) and `[RANK]` (relevance, higher = better).

## Hybrid search

Run **both** searches, then **fuse** the two ranked lists.

### Why not just add the scores?

Full-text `RANK` and vector `distance` are on **different scales** (and one is "higher is better", the other "lower is better"). Normalizing raw scores is fragile. **Reciprocal Rank Fusion** uses only each result's **position**.

### Reciprocal Rank Fusion (RRF)

For each document, sum over every result list it appears in:

```
RRF_score(d) = Σ  1 / (k + rank_i(d))
```

- `rank_i(d)` = position of `d` in list *i* (1 = best).
- `k` = a constant (commonly **60**) that dampens the dominance of top positions.
- Documents found by **both** searches get two contributions and rise to the top.

### Hybrid search with RRF in T-SQL

```sql
DECLARE @q  nvarchar(400) = N'lightweight waterproof tent for two people';
DECLARE @qv vector(1536)  = AI_GENERATE_EMBEDDINGS(@q USE MODEL EmbeddingModel);
DECLARE @k  int = 60;

WITH keyword AS
(
    SELECT TOP (50) ft.[KEY] AS ProductID,
           ROW_NUMBER() OVER (ORDER BY ft.[RANK] DESC) AS rnk
    FROM FREETEXTTABLE(Sales.Products, (Name, Description), @q) AS ft
    ORDER BY ft.[RANK] DESC
),
semantic AS
(
    SELECT ProductID,
           ROW_NUMBER() OVER (ORDER BY distance) AS rnk
    FROM (
        SELECT TOP (50) WITH APPROXIMATE e.ProductID, r.distance
        FROM VECTOR_SEARCH(TABLE = Sales.ProductEmbeddings AS e,
                           COLUMN = Embedding, SIMILAR_TO = @qv, METRIC = 'cosine') AS r
        ORDER BY r.distance
    ) AS v                                   -- subquery: window functions can't sit beside WITH APPROXIMATE
),
fused AS
(
    SELECT COALESCE(kw.ProductID, se.ProductID) AS ProductID,
           COALESCE(1.0 / (@k + kw.rnk), 0) + COALESCE(1.0 / (@k + se.rnk), 0) AS rrf_score,
           kw.rnk AS keyword_rank,
           se.rnk AS semantic_rank
    FROM keyword AS kw
    FULL OUTER JOIN semantic AS se ON se.ProductID = kw.ProductID
)
SELECT TOP (10) p.ProductID, p.Name, f.rrf_score, f.keyword_rank, f.semantic_rank
FROM fused AS f
JOIN Sales.Products AS p ON p.ProductID = f.ProductID
ORDER BY f.rrf_score DESC;
```

> If the table is small or you have no vector index, replace the `semantic` CTE with exact KNN: `SELECT TOP (50) ProductID, ROW_NUMBER() OVER (ORDER BY VECTOR_DISTANCE('cosine', Embedding, @qv)) …`.

### Tuning hybrid search

- **Candidate depth** (`TOP (50)` per list): deeper lists improve recall but cost more.
- **k:** larger values flatten differences between ranks; 60 is a well-known default.
- **Weighting:** multiply one list's contribution (e.g., `1.5 * 1.0/(@k + se.rnk)`) if one signal is more trustworthy for your data.
- Apply **relational filters** (price, stock, tenant) inside both lists so they compete on eligible rows only.

## Evaluating search performance

| Measure | How |
|---|---|
| **Relevance** | A test set of queries with known relevant items; measure precision@k, recall@k, or MRR for keyword vs vector vs hybrid |
| **ANN recall** | Compare `VECTOR_SEARCH … WITH APPROXIMATE` results to exact `VECTOR_DISTANCE` results |
| **Latency** | `SET STATISTICS TIME ON`, Query Store duration, Application Insights end-to-end |
| **Cost** | CPU/IO in Query Store; embedding API calls per query (cache query embeddings for popular searches) |
| **Plan quality** | Execution plan: is the vector index used? Is the full-text index used? Are filters selective? |

## Knowledge check

1. A user searches for part number `TX-4410`. Which search type is most reliable?
2. Why is RRF preferred over adding raw scores?
3. In RRF, what happens to a document found by both keyword and vector search?
4. Which full-text function returns a relevance rank you can sort by?

<details>
<summary>Answers</summary>

1. Full-text (keyword) search — exact tokens.
2. Scores from different systems are on different scales; RRF uses only rank positions.
3. It receives contributions from both lists, so it ranks higher.
4. `CONTAINSTABLE` or `FREETEXTTABLE` (`[RANK]` column).
</details>
