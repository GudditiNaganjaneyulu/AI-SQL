# Keeping Embeddings Up to Date

> **Objective:** *Choose an embedding maintenance method, including table triggers, Change Tracking, Azure Functions with SQL trigger binding, Azure Logic Apps, CDC, and Microsoft Foundry.*

## The problem

When a product description changes, its stored embedding is **stale** — vector search will return results based on old text. You need a reliable way to **detect changes** and **regenerate embeddings**, without hurting the application.

## Design principles

1. **Don't call the AI endpoint inside the user's transaction.** HTTP calls are slow and can fail; doing them synchronously slows writes, holds locks, and can roll back the user's change.
2. **Detect cheaply, process asynchronously.** Mark or capture changes in the transaction; generate embeddings afterwards.
3. **Only re-embed when the embedded text actually changed.** Compare a hash of the source text (`HASHBYTES('SHA2_256', …)`).
4. **Make it idempotent and retryable.** Rate limits (HTTP 429) and timeouts will happen.

## The options

### 1. Table trigger

```sql
-- Lightweight: just flag rows; a background job does the embedding
CREATE OR ALTER TRIGGER Sales.trg_Products_FlagForEmbedding
ON Sales.Products
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Sales.EmbeddingQueue (ProductID, QueuedAt)
    SELECT i.ProductID, SYSUTCDATETIME()
    FROM inserted AS i
    LEFT JOIN deleted AS d ON d.ProductID = i.ProductID
    WHERE d.ProductID IS NULL                                   -- insert
       OR ISNULL(i.Description, N'') <> ISNULL(d.Description, N'')
       OR i.Name <> d.Name;                                     -- relevant text changed
END;
```

| Pros | Cons |
|---|---|
| Captures every change synchronously, inside the database | Adds work to every write; **calling the model inside the trigger** is risky (latency, failures, locks) |

Use a trigger to **queue**, not to **embed** (except for very low-volume tables).

### 2. Change Tracking + scheduled job

Enable Change Tracking; a SQL Agent job (SQL Server/MI), Elastic Job, or external scheduler periodically reads `CHANGETABLE(CHANGES …)` and re-embeds changed rows.

| Pros | Cons |
|---|---|
| Very low overhead; built in; no triggers | Polling interval adds latency; you must store the last sync version |

### 3. Azure Functions with SQL trigger binding

A Function fires on changes (built on Change Tracking), calls the embedding model, and writes the vector back.

| Pros | Cons |
|---|---|
| Near real-time, serverless, scales independently, keeps HTTP calls out of the database | Another component to deploy and monitor |

**A common best-practice answer** for "keep embeddings current with minimal impact on the database".

### 4. Azure Logic Apps

A low-code workflow (SQL connector trigger → call Azure OpenAI → update row).

| Pros | Cons |
|---|---|
| No code; easy to integrate approvals/notifications | Less control and throughput than code; per-action cost |

### 5. Change Data Capture (CDC)

CDC captures before/after values from the log; a consumer (job, Function, Data Factory) processes them.

| Pros | Cons |
|---|---|
| Asynchronous (log-based), full history, can tell exactly which column values changed | More setup and storage than CT; more than you need if you only want "which rows changed" |

### 6. Microsoft Foundry / external pipelines

Use **Microsoft Foundry** (Azure AI) tooling or other data pipelines to process documents (extract, chunk, embed) at scale and write vectors to SQL — useful for large document corpora and multimodal content.

| Pros | Cons |
|---|---|
| Built for large-scale ingestion, document cracking, multimodal | Outside the database; more moving parts |

### (Related) Change event streaming

CES pushes row changes to Event Hubs; a consumer generates embeddings. Good when many services also need the change events.

## Decision table

| Scenario | Best fit |
|---|---|
| A few hundred rows change per day, simplest possible solution | Trigger → queue table + scheduled job, or Change Tracking + job |
| Embeddings must update within seconds of a change; minimal DB impact | **Azure Functions SQL trigger** |
| Business team wants a visual workflow with an approval step | **Logic Apps** |
| Need to know old and new values and keep history | **CDC** |
| Millions of documents/PDFs to ingest and embed | **Microsoft Foundry** / external pipeline |
| Low-volume table, embedding must exist when the transaction commits | Trigger calling the model (accept the risks) |

## Processing a queue with T-SQL

```sql
-- Worker: take a batch without blocking other workers
WITH batch AS (
    SELECT TOP (50) q.ProductID
    FROM Sales.EmbeddingQueue AS q WITH (UPDLOCK, READPAST, ROWLOCK)
    ORDER BY q.QueuedAt
)
DELETE FROM batch
OUTPUT deleted.ProductID INTO #work (ProductID);

MERGE Sales.ProductEmbeddings AS t
USING (
    SELECT p.ProductID, x.TextToEmbed
    FROM #work AS w
    JOIN Sales.Products AS p ON p.ProductID = w.ProductID
    CROSS APPLY (SELECT CONCAT(N'Product: ', p.Name, N'. Category: ', p.Category, N'. ', p.Description)) AS x(TextToEmbed)
) AS s
ON t.ProductID = s.ProductID
WHEN MATCHED AND t.SourceHash <> HASHBYTES('SHA2_256', s.TextToEmbed) THEN
    UPDATE SET Embedding  = AI_GENERATE_EMBEDDINGS(s.TextToEmbed USE MODEL EmbeddingModel),
               SourceHash = HASHBYTES('SHA2_256', s.TextToEmbed),
               EmbeddedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (ProductID, Embedding, SourceHash, ModelName)
    VALUES (s.ProductID, AI_GENERATE_EMBEDDINGS(s.TextToEmbed USE MODEL EmbeddingModel),
            HASHBYTES('SHA2_256', s.TextToEmbed), 'text-embedding-3-small');
```

(`#work` is a temp table created before the batch: `CREATE TABLE #work (ProductID int PRIMARY KEY);`.)

## Don't forget deletes

When a product is deleted, delete its embedding (FK with `ON DELETE CASCADE`, or handle the delete operation in your change processor) so search never returns ghosts.

## Knowledge check

1. Why is calling an embedding endpoint inside an AFTER trigger usually discouraged?
2. Which Azure feature runs code automatically on row changes and relies on Change Tracking?
3. How can you avoid re-embedding rows whose text didn't change?
4. Which method is best when you need the old and new values of changed rows?

<details>
<summary>Answers</summary>

1. It adds latency to every write, holds locks during an HTTP call, and failures can roll back the user's transaction.
2. Azure Functions with the SQL trigger binding.
3. Store a hash of the embedded text and compare it before calling the model.
4. Change Data Capture (CDC).
</details>
