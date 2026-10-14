# External Models and Embeddings

> **Objectives:** *Create and manage external models; identify which columns to include in embeddings; design and implement chunks for embeddings; generate embeddings.*

## Step 0 — Prerequisites

| Requirement | Azure SQL Database / Fabric | SQL Server 2025 |
|---|---|---|
| Outbound REST calls | Enabled by default | `EXEC sp_configure 'external rest endpoint enabled', 1; RECONFIGURE WITH OVERRIDE;` |
| Managed identity for credentials | Enable on the logical server | Azure Arc + `sp_configure 'allow server scoped db credentials', 1` |
| Database master key | Needed to protect credential secrets | Same |
| `AI_GENERATE_CHUNKS` | Compatibility level 170 | Compatibility level 170 |

```sql
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'<strong password>';
```

## Step 1 — Create a credential

Preferred (managed identity, no secret):

```sql
CREATE DATABASE SCOPED CREDENTIAL [https://contoso-ai.openai.azure.com]
    WITH IDENTITY = 'Managed Identity',
         SECRET   = '{"resourceid":"https://cognitiveservices.azure.com"}';
```

Alternative (API key in a header):

```sql
CREATE DATABASE SCOPED CREDENTIAL [https://contoso-ai.openai.azure.com]
    WITH IDENTITY = 'HTTPEndpointHeaders',
         SECRET   = '{"api-key":"<key from Key Vault>"}';
```

## Step 2 — Create an external model

An **external model** is a database object describing **where** an AI model is, **what API format** it uses, **what kind** it is, and **how to authenticate**.

```sql
CREATE EXTERNAL MODEL EmbeddingModel
WITH (
    LOCATION   = 'https://contoso-ai.openai.azure.com/openai/deployments/text-embedding-3-small/embeddings?api-version=2024-02-01',
    API_FORMAT = 'Azure OpenAI',             -- or 'OpenAI', 'Ollama', 'ONNX Runtime'
    MODEL_TYPE = EMBEDDINGS,                 -- the supported model type
    MODEL      = 'text-embedding-3-small',
    CREDENTIAL = [https://contoso-ai.openai.azure.com],
    PARAMETERS = '{"dimensions":1536, "sql_rest_options":{"retry_count":3}}'
);
```

| Option | Notes |
|---|---|
| `LOCATION` | HTTPS endpoint (or a local folder for ONNX Runtime) |
| `API_FORMAT` | `Azure OpenAI`, `OpenAI`, `Ollama`, `ONNX Runtime` |
| `MODEL_TYPE` | `EMBEDDINGS` |
| `PARAMETERS` | JSON appended to each request, e.g., `dimensions`; `sql_rest_options.retry_count` (0–10) retries transient HTTP errors |
| `LOCAL_RUNTIME_PATH` | ONNX Runtime only — folder containing the runtime DLLs |

### Managing external models

```sql
SELECT * FROM sys.external_models;                         -- metadata

GRANT EXECUTE ON EXTERNAL MODEL::EmbeddingModel TO [rag-app];   -- allow use
GRANT CREATE EXTERNAL MODEL TO [ai-admins];                      -- allow creation
-- ALTER EXTERNAL MODEL … to change settings; DROP EXTERNAL MODEL EmbeddingModel; to remove
```

Swapping models later (e.g., to a newer embedding model) means **re-embedding all rows** — vectors from different models aren't comparable. Plan a migration: new column/table, backfill, switch queries, drop old.

## Step 3 — Decide what to embed

### Which columns?

Embed **descriptive, meaning-bearing text** a user might search by meaning:

| Include | Usually exclude |
|---|---|
| Product name + description + category | Surrogate keys, SKUs, GUIDs |
| Review text, support ticket body | Prices, quantities, dates (filter these relationally instead) |
| Document title + section text | Highly sensitive data (PII) unless required and approved |
| Short, helpful labels ("Category: Camping") | Boilerplate repeated on every row |

**Concatenate** selected columns into one string with labels — this gives the model context:

```sql
SELECT ProductID,
       CONCAT(N'Product: ', Name, N'. Category: ', Category, N'. ', Description) AS TextToEmbed
FROM Sales.Products;
```

> **Rule of thumb:** use **vector search for meaning**, and **WHERE clauses for exact attributes** (price < 100, in stock). Combine them in one query.

### Where to store vectors

```sql
CREATE TABLE Sales.ProductEmbeddings
(
    ProductID   int          NOT NULL CONSTRAINT PK_ProductEmbeddings PRIMARY KEY
                             CONSTRAINT FK_ProductEmbeddings_Products REFERENCES Sales.Products(ProductID),
    Embedding   vector(1536) NOT NULL,
    SourceHash  varbinary(32) NOT NULL,          -- detects when the text changed
    ModelName   varchar(100) NOT NULL,
    EmbeddedAt  datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
```

A **separate table** keeps the main table narrow, lets you store multiple models/versions, and isolates vector index maintenance. A column on the main table is simpler for small solutions.

## Step 4 — Chunk long text

Embedding models have an input limit, and **one vector for a 30-page document blurs its meaning**. Split long text into **chunks** and embed each chunk.

### Chunking design choices

| Choice | Guidance |
|---|---|
| **Chunk size** | Small enough to be specific, large enough to keep context. Hundreds to ~1,000+ characters is common; tune with tests |
| **Overlap** | 10–20% overlap avoids cutting an idea in half at a boundary |
| **Boundaries** | Fixed size is simplest; paragraph/sentence/heading boundaries often retrieve better (done in app code) |
| **Metadata** | Store document ID, chunk order, title — needed for citations and filtering |

### AI_GENERATE_CHUNKS

```sql
SELECT d.DocID, c.chunk, c.chunk_order, c.chunk_offset, c.chunk_length
FROM dbo.Documents AS d
CROSS APPLY AI_GENERATE_CHUNKS(
    SOURCE     = d.Body,
    CHUNK_TYPE = FIXED,      -- currently the supported type
    CHUNK_SIZE = 800,        -- characters
    OVERLAP    = 10          -- percent of CHUNK_SIZE (0–50)
) AS c;
```

Returns `chunk`, `chunk_order`, `chunk_offset`, `chunk_length` (and `chunk_set_id` when `ENABLE_CHUNK_SET_ID = 1`). Requires compatibility level **170**.

## Step 5 — Generate embeddings

```sql
-- One value
DECLARE @v vector(1536) = AI_GENERATE_EMBEDDINGS(N'lightweight tent' USE MODEL EmbeddingModel);

-- Per-request parameter override
SELECT AI_GENERATE_EMBEDDINGS(N'hello' USE MODEL EmbeddingModel PARAMETERS N'{"dimensions":768}');
```

### Embed products

```sql
INSERT INTO Sales.ProductEmbeddings (ProductID, Embedding, SourceHash, ModelName)
SELECT p.ProductID,
       AI_GENERATE_EMBEDDINGS(t.TextToEmbed USE MODEL EmbeddingModel),
       HASHBYTES('SHA2_256', t.TextToEmbed),
       'text-embedding-3-small'
FROM Sales.Products AS p
CROSS APPLY (SELECT CONCAT(N'Product: ', p.Name, N'. Category: ', p.Category, N'. ', p.Description)) AS t(TextToEmbed)
WHERE NOT EXISTS (SELECT 1 FROM Sales.ProductEmbeddings AS e WHERE e.ProductID = p.ProductID);
```

### Chunk and embed documents in one statement

```sql
CREATE TABLE dbo.DocumentChunks
(
    ChunkID    int IDENTITY PRIMARY KEY,
    DocID      int           NOT NULL,
    ChunkOrder bigint        NOT NULL,
    ChunkText  nvarchar(max) NOT NULL,
    Embedding  vector(1536)  NOT NULL
);

INSERT INTO dbo.DocumentChunks (DocID, ChunkOrder, ChunkText, Embedding)
SELECT d.DocID, c.chunk_order, c.chunk,
       AI_GENERATE_EMBEDDINGS(c.chunk USE MODEL EmbeddingModel)
FROM dbo.Documents AS d
CROSS APPLY AI_GENERATE_CHUNKS(SOURCE = d.Body, CHUNK_TYPE = FIXED, CHUNK_SIZE = 800, OVERLAP = 10) AS c;
```

### Generating embeddings outside SQL

You can also call the embedding API from **application code**, an **Azure Function**, or a **Microsoft Foundry** pipeline, and write the vectors into the `vector` column (drivers such as `Microsoft.Data.SqlClient` 6.1+ send vectors natively). In-database generation is simplest; external generation scales independently and keeps long-running HTTP calls out of database sessions.

### Troubleshooting

| Symptom | Check |
|---|---|
| Error about the endpoint/credential | Credential **name** must match the URL prefix; caller needs `REFERENCES` on the credential |
| HTTP 401/403 | Managed identity role assignment (*Cognitive Services OpenAI User*); key validity |
| HTTP 429 | Rate limit — add `retry_count`, batch smaller, raise quota |
| `AI_GENERATE_CHUNKS` not found | Compatibility level below 170 |
| Dimension mismatch on insert | Column `vector(n)` must match the model's output dimensions |
| Need diagnostics | Extended Events `ai_generate_embeddings_summary` and `external_rest_endpoint_summary` |

## Knowledge check

1. Which object stores an AI endpoint's location, API format and credential?
2. Name two columns you would **not** include in an embedding for products.
3. What does `OVERLAP = 10` mean in `AI_GENERATE_CHUNKS`?
4. What permission lets a user call `AI_GENERATE_EMBEDDINGS` with a model?

<details>
<summary>Answers</summary>

1. An external model (`CREATE EXTERNAL MODEL`).
2. E.g., ProductID and Price (filter numerics relationally).
3. Each chunk includes 10% of `CHUNK_SIZE` characters from the preceding text.
4. `EXECUTE ON EXTERNAL MODEL::<name>`.
</details>
