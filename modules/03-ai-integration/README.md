# Module 3: AI Integration with SQL

**Duration:** Week 5–6
**Goal:** Build AI-powered features directly in and around your SQL database.

---

## 1. What Are Vector Embeddings?

An **embedding** is a list of numbers (a vector) that represents the semantic meaning of text, images, or any data. Similar content has similar vectors.

```
"cat"    → [0.12, -0.33, 0.87, ..., 0.05]  (1536 numbers)
"kitten" → [0.13, -0.31, 0.86, ..., 0.06]  ← very similar!
"car"    → [0.89,  0.12, -0.44, ..., 0.78] ← very different
```

**Why store them in SQL?**
- Run similarity search alongside regular SQL filters
- Join with your business data
- No need for a separate vector database

---

## 2. Setting Up pgvector

```sql
-- Enable the pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create a table with an embedding column
-- text-embedding-ada-002 produces 1536 dimensions
-- text-embedding-3-small produces 1536 dimensions
-- text-embedding-3-large produces 3072 dimensions
CREATE TABLE documents (
    id          SERIAL PRIMARY KEY,
    content     TEXT NOT NULL,
    metadata    JSONB,
    embedding   VECTOR(1536),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Create a products table with embeddings for semantic search
CREATE TABLE product_embeddings (
    product_id  INTEGER PRIMARY KEY REFERENCES products(product_id),
    description TEXT,
    embedding   VECTOR(1536)
);
```

---

## 3. Generating Embeddings with Azure OpenAI

```python
# Python — generate embeddings via Azure OpenAI
import openai
import psycopg2
import json

# Azure OpenAI config
client = openai.AzureOpenAI(
    api_key="your-api-key",
    api_version="2024-02-01",
    azure_endpoint="https://your-resource.openai.azure.com"
)

def get_embedding(text: str, model="text-embedding-ada-002") -> list[float]:
    response = client.embeddings.create(input=text, model=model)
    return response.data[0].embedding

# Store embedding in database
def store_document(content: str, metadata: dict = None):
    embedding = get_embedding(content)
    conn = psycopg2.connect("your-connection-string")
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO documents (content, metadata, embedding) VALUES (%s, %s, %s)",
        (content, json.dumps(metadata), embedding)
    )
    conn.commit()
    cur.close()
    conn.close()

# Example usage
store_document(
    "The new MacBook Pro features the M3 chip with incredible performance.",
    {"source": "tech_news", "category": "apple"}
)
```

---

## 4. Similarity Search

pgvector supports three distance operators:

| Operator | Distance Type | Best For |
|----------|--------------|---------|
| `<->` | L2 (Euclidean) | General purpose |
| `<#>` | Inner Product (negative) | Normalized vectors |
| `<=>` | Cosine Distance | Text embeddings |

```sql
-- Find top 5 most similar documents to a query embedding
-- (Replace '[0.1, 0.2, ..., 0.5]' with actual embedding array)
SELECT
    id,
    content,
    metadata,
    1 - (embedding <=> '[0.1, 0.2, 0.3]'::vector) AS similarity
FROM documents
ORDER BY embedding <=> '[0.1, 0.2, 0.3]'::vector
LIMIT 5;

-- Semantic search with metadata filter
SELECT
    d.id,
    d.content,
    d.metadata->>'source' AS source,
    1 - (d.embedding <=> $1::vector) AS similarity
FROM documents d
WHERE d.metadata->>'category' = 'tech_news'
  AND 1 - (d.embedding <=> $1::vector) > 0.7  -- similarity threshold
ORDER BY d.embedding <=> $1::vector
LIMIT 10;

-- Semantic product search
SELECT
    p.name,
    p.price,
    p.category,
    1 - (pe.embedding <=> $1::vector) AS similarity
FROM products p
JOIN product_embeddings pe ON p.product_id = pe.product_id
WHERE p.price < 1000
ORDER BY pe.embedding <=> $1::vector
LIMIT 5;
```

---

## 5. Indexing Vectors (ANN Search)

Exact nearest-neighbor is slow on large datasets. Use approximate nearest-neighbor (ANN) indexes:

```sql
-- IVFFlat — inverted file index (faster, less accurate)
-- lists = sqrt(total_rows) is a good starting point
CREATE INDEX idx_documents_ivfflat ON documents
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- HNSW — hierarchical navigable small world (better accuracy, more memory)
-- Recommended for most production use cases
CREATE INDEX idx_documents_hnsw ON documents
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- Set probes for IVFFlat at query time (higher = more accurate, slower)
SET ivfflat.probes = 10;

-- Set ef_search for HNSW at query time
SET hnsw.ef_search = 100;

-- Check index usage
EXPLAIN SELECT * FROM documents
ORDER BY embedding <=> '[0.1, 0.2, ...]'::vector
LIMIT 10;
```

---

## 6. RAG — Retrieval-Augmented Generation

RAG is the core pattern for AI apps backed by SQL:

```
User Question
    ↓
1. Embed the question
    ↓
2. Find similar chunks in DB (vector search)
    ↓
3. Retrieve context from SQL
    ↓
4. Send question + context to LLM
    ↓
5. Return grounded answer
```

```python
def rag_query(user_question: str) -> str:
    # Step 1: Embed the question
    question_embedding = get_embedding(user_question)

    # Step 2 & 3: Retrieve relevant context from DB
    conn = psycopg2.connect("your-connection-string")
    cur = conn.cursor()
    cur.execute("""
        SELECT content, metadata->>'source' AS source
        FROM documents
        ORDER BY embedding <=> %s::vector
        LIMIT 5
    """, (question_embedding,))
    results = cur.fetchall()
    cur.close()
    conn.close()

    # Build context string
    context = "\n\n".join([f"[{r[1]}]: {r[0]}" for r in results])

    # Step 4: Ask the LLM with context
    response = client.chat.completions.create(
        model="gpt-4",
        messages=[
            {
                "role": "system",
                "content": "Answer questions based only on the provided context."
            },
            {
                "role": "user",
                "content": f"Context:\n{context}\n\nQuestion: {user_question}"
            }
        ]
    )

    return response.choices[0].message.content
```

---

## 7. Hybrid Search (Vector + Full-Text)

Combine semantic search with keyword search for best results:

```sql
-- Reciprocal Rank Fusion (RRF) hybrid search
WITH
vector_search AS (
    SELECT id, content,
           ROW_NUMBER() OVER (ORDER BY embedding <=> $1::vector) AS rank
    FROM documents
    LIMIT 50
),
text_search AS (
    SELECT id, content,
           ROW_NUMBER() OVER (
               ORDER BY ts_rank(
                   to_tsvector('english', content),
                   to_tsquery('english', $2)
               ) DESC
           ) AS rank
    FROM documents
    WHERE to_tsvector('english', content) @@ to_tsquery('english', $2)
    LIMIT 50
),
rrf AS (
    SELECT
        COALESCE(v.id, t.id) AS id,
        COALESCE(v.content, t.content) AS content,
        COALESCE(1.0 / (60 + v.rank), 0) +
        COALESCE(1.0 / (60 + t.rank), 0) AS rrf_score
    FROM vector_search v
    FULL OUTER JOIN text_search t ON v.id = t.id
)
SELECT id, content, rrf_score
FROM rrf
ORDER BY rrf_score DESC
LIMIT 10;
```

---

## 8. Storing Chat History in SQL

```sql
-- Chat sessions and messages
CREATE TABLE chat_sessions (
    session_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(user_id),
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    metadata    JSONB
);

CREATE TABLE chat_messages (
    message_id  SERIAL PRIMARY KEY,
    session_id  UUID REFERENCES chat_sessions(session_id) ON DELETE CASCADE,
    role        VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content     TEXT NOT NULL,
    embedding   VECTOR(1536),  -- embed for semantic memory retrieval
    tokens      INTEGER,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Retrieve conversation history
SELECT role, content, created_at
FROM chat_messages
WHERE session_id = $1
ORDER BY created_at ASC;

-- Semantic memory: find relevant past messages
SELECT role, content, created_at,
       1 - (embedding <=> $1::vector) AS relevance
FROM chat_messages
WHERE session_id = $2
  AND embedding IS NOT NULL
ORDER BY embedding <=> $1::vector
LIMIT 5;
```

---

## 9. Azure OpenAI in SQL (Azure SQL Database)

Azure SQL Database has native integration with Azure OpenAI:

```sql
-- Azure SQL: call OpenAI embeddings directly in T-SQL
-- (requires Azure SQL managed identity + OpenAI linked service)

DECLARE @embedding NVARCHAR(MAX);

EXEC sp_invoke_external_rest_endpoint
    @url = 'https://your-resource.openai.azure.com/openai/deployments/text-embedding-ada-002/embeddings?api-version=2024-02-01',
    @method = 'POST',
    @headers = '{"Content-Type":"application/json"}',
    @payload = '{"input":"search query text here"}',
    @response = @embedding OUTPUT;

-- Parse and store the embedding
-- (parse JSON response to extract the embedding array)
```

---

## 10. Key AI Concepts for the Exam

| Concept | What It Is | SQL Relevance |
|---------|-----------|---------------|
| Embedding | Dense vector representation of content | Store as VECTOR column |
| Cosine Similarity | Angle between vectors (1 = identical) | `<=>` operator |
| RAG | Retrieval-Augmented Generation | SQL as knowledge retrieval layer |
| Chunking | Splitting docs into smaller pieces | Decide chunk size before embedding |
| Top-K | Retrieve K most similar results | LIMIT clause |
| Hallucination | LLM making up facts | RAG prevents this with grounding |
| ANN | Approximate Nearest Neighbor | HNSW / IVFFlat indexes |
| Fine-tuning | Training model on your data | Different from RAG |
| Token | Unit of text for LLMs (~4 chars) | Affects context window size |
| Context window | Max tokens LLM can process at once | Affects how much context you send |

---

## Module 3 Checklist

- [ ] Can enable and use pgvector extension
- [ ] Generate embeddings via Azure OpenAI API
- [ ] Store embeddings and query by similarity
- [ ] Build a working RAG pipeline
- [ ] Create HNSW index for production-scale search
- [ ] Implement hybrid search (vector + full-text)
- [ ] Design chat history schema with semantic memory
- [ ] Explain difference between RAG and fine-tuning
