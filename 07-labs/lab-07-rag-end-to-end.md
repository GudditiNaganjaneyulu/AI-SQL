# Lab 7 — RAG End to End

**Goal:** build a product-advice assistant entirely in T-SQL: external model → embeddings → vector search → JSON context → chat completion → parsed answer.

**Requirements**

- Azure SQL Database (recommended) or SQL database in Fabric (AI features available without preview switches).
- An **Azure OpenAI** resource (in Microsoft Foundry) with two deployments:
  - an **embedding** deployment, e.g. `text-embedding-3-small` (1,536 dimensions),
  - a **chat** deployment, e.g. named `gpt-chat`.
- Permission to assign Azure roles on the Azure OpenAI resource.

> Costs: a few cents of model usage for this lab. Delete the deployments afterwards if you won't reuse them.

## Part A — Identity and credential (passwordless)

1. In the Azure portal, open your **SQL server** → **Identity** → turn **System assigned** managed identity **On**.
2. Open your **Azure OpenAI** resource → **Access control (IAM)** → **Add role assignment** → **Cognitive Services OpenAI User** → assign to the SQL server's managed identity.
3. In `DP800Lab`:

```sql
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'<a strong password>';

CREATE DATABASE SCOPED CREDENTIAL [https://<your-resource>.openai.azure.com]
    WITH IDENTITY = 'Managed Identity',
         SECRET   = '{"resourceid":"https://cognitiveservices.azure.com"}';
```

Replace `<your-resource>` everywhere in this lab.

## Part B — External model and embeddings

```sql
CREATE EXTERNAL MODEL EmbeddingModel
WITH (
    LOCATION   = 'https://<your-resource>.openai.azure.com/openai/deployments/text-embedding-3-small/embeddings?api-version=2024-02-01',
    API_FORMAT = 'Azure OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL      = 'text-embedding-3-small',
    CREDENTIAL = [https://<your-resource>.openai.azure.com]
);

-- Smoke test
SELECT AI_GENERATE_EMBEDDINGS(N'hello world' USE MODEL EmbeddingModel) AS v;
```

Create the embeddings table and embed all products:

```sql
DROP TABLE IF EXISTS Sales.ProductEmbeddings;
CREATE TABLE Sales.ProductEmbeddings
(
    ProductID  int           NOT NULL PRIMARY KEY REFERENCES Sales.Products (ProductID),
    Embedding  vector(1536)  NOT NULL,
    SourceHash varbinary(32) NOT NULL,
    EmbeddedAt datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
);

INSERT INTO Sales.ProductEmbeddings (ProductID, Embedding, SourceHash)
SELECT p.ProductID,
       AI_GENERATE_EMBEDDINGS(t.Txt USE MODEL EmbeddingModel),
       HASHBYTES('SHA2_256', t.Txt)
FROM Sales.Products AS p
CROSS APPLY (SELECT CONCAT(N'Product: ', p.Name, N'. Category: ', p.Category, N'. ', p.Description)) AS t(Txt);

SELECT COUNT(*) AS embedded FROM Sales.ProductEmbeddings;   -- 20
```

## Part C — Semantic search

Only 20 rows → a vector index can't be created (needs 100) and isn't needed. Use **exact** search:

```sql
DECLARE @qv vector(1536) = AI_GENERATE_EMBEDDINGS(N'something to keep me warm while sleeping in the snow' USE MODEL EmbeddingModel);

SELECT TOP (5) p.Name, p.Category, p.Price,
       VECTOR_DISTANCE('cosine', e.Embedding, @qv) AS distance
FROM Sales.ProductEmbeddings AS e
JOIN Sales.Products AS p ON p.ProductID = e.ProductID
WHERE p.Discontinued = 0
ORDER BY distance;
```

Try several phrasings that share **no keywords** with descriptions ("boil water quickly", "don't get lost"). Notice that meaning, not wording, drives the results.

## Part D — The RAG procedure

```sql
CREATE OR ALTER PROCEDURE dbo.usp_AskProducts
    @question nvarchar(1000),
    @maxPrice decimal(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Embed the question
    DECLARE @qv vector(1536) = AI_GENERATE_EMBEDDINGS(@question USE MODEL EmbeddingModel);

    -- 2 + 3. Retrieve top matches and convert to JSON
    DECLARE @context nvarchar(max) =
    (
        SELECT TOP (4) p.ProductID AS id, p.Name AS name, p.Category AS category,
               p.Price AS price, p.Description AS description
        FROM Sales.ProductEmbeddings AS e
        JOIN Sales.Products AS p ON p.ProductID = e.ProductID
        WHERE p.Discontinued = 0
          AND (@maxPrice IS NULL OR p.Price <= @maxPrice)
        ORDER BY VECTOR_DISTANCE('cosine', e.Embedding, @qv)
        FOR JSON PATH
    );

    -- 4. Build the chat payload safely
    DECLARE @payload nvarchar(max) = JSON_OBJECT(
        'messages': JSON_ARRAY(
            JSON_OBJECT('role': 'system',
                        'content': N'You are an outdoor-gear shop assistant. Recommend products ONLY from the JSON context. '
                                 + N'Cite product ids in square brackets like [3]. If nothing fits, say you don''t know.'),
            JSON_OBJECT('role': 'user',
                        'content': CONCAT(N'Context: ', @context, NCHAR(10), N'Question: ', @question))
        ),
        'temperature': 0.2,
        'max_tokens': 400
    );

    -- 5. Call the chat model
    DECLARE @response nvarchar(max), @ret int;
    EXEC @ret = sp_invoke_external_rest_endpoint
         @url         = N'https://<your-resource>.openai.azure.com/openai/deployments/gpt-chat/chat/completions?api-version=2024-10-21',
         @method      = 'POST',
         @credential  = [https://<your-resource>.openai.azure.com],
         @payload     = @payload,
         @timeout     = 120,
         @retry_count = 3,
         @response    = @response OUTPUT;

    IF @ret <> 0
    BEGIN
        SELECT @ret AS http_status, @response AS raw_response;
        RETURN;
    END;

    -- 6. Extract the answer
    SELECT c.answer,
           JSON_VALUE(@response, '$.result.usage.total_tokens') AS total_tokens,
           @context AS context_sent
    FROM OPENJSON(@response, '$.result.choices')
         WITH (answer nvarchar(max) '$.message.content') AS c;
END;
GO

EXEC dbo.usp_AskProducts N'I''m doing a 3-day winter hike. What should I sleep in and wear?';
EXEC dbo.usp_AskProducts N'I need to cook and purify water on a budget', @maxPrice = 80;
EXEC dbo.usp_AskProducts N'Which kayak do you recommend?';   -- should say it doesn't know
```

## Part E — Experiments

1. Remove the "ONLY from the JSON context" rule and ask about kayaks again. What happens? (Hallucination.)
2. Change `TOP (4)` to `TOP (1)`. How does answer quality change?
3. Add a log table `dbo.RagLog(Question, ContextIds, TotalTokens, AskedAt)` and insert into it from the procedure.
4. Ask the model to answer as JSON `{"recommendations":[{"id":…,"reason":…}]}` and parse it with `OPENJSON` (see *Domain 3 → RAG in T-SQL → Structured output*). Join the IDs back to `Sales.Products`.

## Troubleshooting

| Problem | Fix |
|---|---|
| `@ret` = 401 or 403 | Role assignment missing or not yet propagated (wait a few minutes); credential name must be exactly `https://<your-resource>.openai.azure.com` |
| `@ret` = 404 | Deployment name or `api-version` wrong in the URL |
| `@ret` = 429 | Rate limit — retry later or raise the deployment's quota |
| "The URL is not allowed" | The endpoint domain must be on the Azure SQL allow-list (`*.openai.azure.com`, `*.cognitiveservices.azure.com`) |
| Dimension mismatch on insert | The embedding model's dimensions must equal `vector(1536)` |

## Clean up

```sql
DROP PROCEDURE IF EXISTS dbo.usp_AskProducts;
DROP TABLE IF EXISTS Sales.ProductEmbeddings;
DROP EXTERNAL MODEL EmbeddingModel;
DROP DATABASE SCOPED CREDENTIAL [https://<your-resource>.openai.azure.com];
```
