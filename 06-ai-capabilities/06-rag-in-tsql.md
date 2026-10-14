# RAG in T-SQL

> **Objectives:** *Identify use cases for RAG; create a prompt by using the `sp_invoke_external_rest_endpoint` stored procedure; convert structured data to JSON for language model processing; send results to a language model; extract language model responses.*

## When to use RAG

| Good RAG use case | Why |
|---|---|
| Customer support Q&A over product manuals and FAQs | Answers must come from **your** content |
| "Which products suit a 3-day winter hike under $300?" | Combine semantic retrieval with **structured filters** (price, stock) |
| Internal policy assistant | Private data the model was never trained on |
| Summarize a customer's recent orders/tickets | Grounded in live database rows |

| Poor fit | Better approach |
|---|---|
| Exact numeric reporting ("total revenue last quarter") | Plain SQL / BI — don't ask an LLM to add numbers |
| Content the model already knows well, no private data | Plain prompt |
| Strict transactional decisions | Deterministic code and rules |

RAG **reduces hallucinations**, keeps answers **current** (data changes → answers change, no retraining), and enables **citations** and **permission-aware** retrieval (RLS applies to the retrieval query).

## The RAG pipeline inside the database

```
1. Embed the question            AI_GENERATE_EMBEDDINGS
2. Retrieve relevant rows        VECTOR_SEARCH / hybrid search + WHERE filters
3. Convert rows to JSON          FOR JSON PATH / JSON_OBJECT / JSON_ARRAYAGG
4. Build the prompt payload      JSON_OBJECT(...) with system + user messages
5. Call the chat model           sp_invoke_external_rest_endpoint
6. Extract the answer            JSON_VALUE / OPENJSON on @response
```

## Step 0 — Setup

```sql
-- Azure SQL Database / Fabric: REST calls already enabled. SQL Server 2025:
-- EXEC sp_configure 'external rest endpoint enabled', 1; RECONFIGURE WITH OVERRIDE;

-- Credential for the chat endpoint (managed identity)
CREATE DATABASE SCOPED CREDENTIAL [https://contoso-ai.openai.azure.com]
    WITH IDENTITY = 'Managed Identity',
         SECRET   = '{"resourceid":"https://cognitiveservices.azure.com"}';

GRANT EXECUTE ANY EXTERNAL ENDPOINT TO [rag-app];
```

## Steps 1–3 — Retrieve and convert to JSON

```sql
DECLARE @question nvarchar(1000) = N'I need a light tent for two people that handles rain. What do you recommend?';
DECLARE @qv vector(1536) = AI_GENERATE_EMBEDDINGS(@question USE MODEL EmbeddingModel);

DECLARE @context nvarchar(max) =
(
    SELECT p.ProductID AS id, p.Name AS name, p.Category AS category,
           p.Price AS price, p.Description AS description
    FROM (
        SELECT TOP (5) WITH APPROXIMATE e.ProductID, r.distance
        FROM VECTOR_SEARCH(TABLE = Sales.ProductEmbeddings AS e,
                           COLUMN = Embedding, SIMILAR_TO = @qv, METRIC = 'cosine') AS r
        ORDER BY r.distance
    ) AS hits
    JOIN Sales.Products AS p ON p.ProductID = hits.ProductID
    WHERE p.Discontinued = 0
    FOR JSON PATH
);
```

Why JSON? Models handle structured JSON context well, field names give meaning (`"price": 189.00`), and `FOR JSON` escapes special characters safely.

Keep context **small and relevant**: select only needed columns, limit rows (top-k), trim long text — tokens cost money and context windows are finite.

## Step 4 — Build the prompt

Chat Completions expects a `messages` array:

```sql
DECLARE @system nvarchar(max) = N'You are a helpful outdoor-gear assistant. '
    + N'Answer ONLY using the products in the JSON context. '
    + N'If the context does not contain the answer, say "I don''t know". '
    + N'Cite product ids in square brackets, e.g. [12].';

DECLARE @payload nvarchar(max) = JSON_OBJECT(
    'messages': JSON_ARRAY(
        JSON_OBJECT('role': 'system', 'content': @system),
        JSON_OBJECT('role': 'user',
                    'content': CONCAT(N'Context (JSON): ', @context, NCHAR(10), N'Question: ', @question))
    ),
    'temperature': 0.2,
    'max_tokens': 500
);
```

`JSON_OBJECT` / `JSON_ARRAY` nest correctly and escape quotes and newlines — **don't build JSON with string concatenation**.

**Prompt design checklist:** role + rules in the system message; "answer only from context"; what to do when unsure; output format (citations, JSON); low `temperature` for factual answers.

## Step 5 — Call the model

```sql
DECLARE @response nvarchar(max), @ret int;

EXEC @ret = sp_invoke_external_rest_endpoint
     @url        = N'https://contoso-ai.openai.azure.com/openai/deployments/gpt-chat/chat/completions?api-version=2024-10-21',
     @method     = 'POST',
     @credential = [https://contoso-ai.openai.azure.com],
     @payload    = @payload,
     @timeout    = 120,
     @retry_count = 3,
     @response   = @response OUTPUT;
```

| Parameter | Notes |
|---|---|
| `@url` | HTTPS endpoint (must be an allowed domain on Azure SQL) |
| `@method` | Default `POST` |
| `@headers` | Flat JSON of headers (optional) |
| `@payload` | JSON/XML/text body (up to 100 MB) |
| `@credential` | Database scoped credential whose name matches the URL prefix |
| `@timeout` | Seconds, 1–230 (default 30) |
| `@retry_count` | 0–10, retries on 408/429/5xx |
| `@response OUTPUT` | Response envelope (see below) |
| Return value | `0` for HTTP 2xx; otherwise the HTTP status code |

## Step 6 — Extract the answer

The `@response` envelope:

```json
{
  "response": { "status": { "http": { "code": 200, "description": "OK" } }, "headers": { } },
  "result":   { "choices": [ { "message": { "role": "assistant", "content": "..." } } ],
                "usage":   { "prompt_tokens": 812, "completion_tokens": 143, "total_tokens": 955 } }
}
```

```sql
IF @ret <> 0
    THROW 50100, 'Model call failed — inspect @response for the HTTP status and error body.', 1;

SELECT c.answer,
       JSON_VALUE(@response, '$.result.usage.total_tokens') AS total_tokens,
       JSON_VALUE(@response, '$.response.status.http.code')  AS http_status
FROM OPENJSON(@response, '$.result.choices')
     WITH (answer nvarchar(max) '$.message.content') AS c;
```

> **Why OPENJSON for the answer?** `JSON_VALUE` returns at most 4,000 characters (`nvarchar(4000)`) and, in lax mode, **returns NULL** when the value is longer. `OPENJSON … WITH (… nvarchar(max))` returns the full text.

### Structured output

Ask the model for JSON (and, where supported, enforce a schema with `response_format`), then shred it with `OPENJSON`:

```sql
-- Model asked to return: {"recommendations":[{"id":12,"reason":"..."}]}
SELECT r.id, r.reason
FROM OPENJSON(@response, '$.result.choices')
     WITH (content nvarchar(max) '$.message.content') AS c
CROSS APPLY OPENJSON(c.content, '$.recommendations')
     WITH (id int '$.id', reason nvarchar(400) '$.reason') AS r;
```

This lets you **join model output back to tables** (e.g., `JOIN Sales.Products ON ProductID = r.id`).

## Wrap it in a stored procedure

Put steps 1–6 in `dbo.usp_AskProducts @question nvarchar(1000)` so apps — or **Data API builder** / an **MCP tool** — can call it. Also:

- **Log** question, retrieved IDs, token usage and latency in a table for evaluation and cost tracking.
- Store chat history (`ChatSessions`, `ChatMessages`) if you need multi-turn conversations; retrieve recent turns as additional context.
- Rely on **RLS** so retrieval only returns rows the caller may see.

## Common problems

| Problem | Fix |
|---|---|
| Answer is generic / invents products | Stronger system prompt; lower temperature; better retrieval (hybrid, more relevant chunks) |
| `@ret` = 401/403 | Managed identity role or credential name mismatch |
| `@ret` = 429 | Rate limiting — `@retry_count`, backoff, quota increase |
| Answer truncated to NULL | Use `OPENJSON … nvarchar(max)` instead of `JSON_VALUE` |
| Slow | Fewer/shorter context rows; ANN index; cache embeddings for repeated questions |
| Security concerns | Least-privilege credentials; outbound firewall; never send unneeded PII; audit calls |

## Knowledge check

1. Which system procedure calls a chat-completions REST endpoint from T-SQL?
2. Why build the payload with `JSON_OBJECT` instead of string concatenation?
3. Where in `@response` is the model's answer for Azure OpenAI chat completions?
4. Why can `JSON_VALUE` return NULL for a long answer?
5. Give one scenario where RAG is a poor choice.

<details>
<summary>Answers</summary>

1. `sp_invoke_external_rest_endpoint`.
2. It produces valid JSON and escapes quotes/newlines correctly.
3. `$.result.choices[0].message.content`.
4. It returns at most 4,000 characters; in lax mode longer values return NULL.
5. Exact aggregations like total revenue — use SQL directly.
</details>
