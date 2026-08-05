# Mock Interview Questions — SQL AI Developer Associate
## 50 Questions with Answers

---

## Section 1: SQL Fundamentals (Q1–12)

**Q1. What is the difference between DELETE, TRUNCATE, and DROP?**

> - `DELETE` removes rows one-by-one, fires triggers, can be rolled back, slower
> - `TRUNCATE` removes all rows at once, does NOT fire row-level triggers, faster, can be rolled back in PostgreSQL (not in all DBs)
> - `DROP` removes the entire table structure and data permanently

---

**Q2. Explain the difference between INNER JOIN, LEFT JOIN, and FULL OUTER JOIN with an example.**

> - `INNER JOIN` returns only rows that have a match in BOTH tables
> - `LEFT JOIN` returns all rows from the left table, NULL for unmatched right-side columns
> - `FULL OUTER JOIN` returns all rows from both tables, NULLs where there's no match
>
> Example: LEFT JOIN users with orders — you get all users including those who never placed an order (their order columns will be NULL).

---

**Q3. What is a window function? How does it differ from GROUP BY?**

> Window functions calculate across a set of rows related to the current row WITHOUT collapsing them into a single output row. GROUP BY collapses rows into groups.
>
> Example: `SUM(price) OVER (PARTITION BY category)` gives you the category total on every product row, while `GROUP BY category` would give one row per category.

---

**Q4. Write a query to find the second-highest salary from an employees table.**

```sql
-- Method 1: OFFSET
SELECT DISTINCT salary
FROM employees
ORDER BY salary DESC
LIMIT 1 OFFSET 1;

-- Method 2: Subquery
SELECT MAX(salary) FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);

-- Method 3: Window function (handles ties)
SELECT salary FROM (
    SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rk
    FROM employees
) ranked
WHERE rk = 2
LIMIT 1;
```

---

**Q5. What are the different types of indexes in PostgreSQL? When would you use each?**

> - **B-Tree** (default): equality, ranges, ORDER BY — most common
> - **GIN**: multi-value columns — JSONB, arrays, full-text search
> - **GiST**: geometric data, range types, full-text search
> - **BRIN**: very large tables with natural sort order (timestamps, sequential IDs)
> - **Hash**: equality only (rare, B-Tree is usually better)
> - **SP-GiST**: partitioned search trees for non-balanced structures

---

**Q6. What is a CTE and when would you use it over a subquery?**

> A CTE (Common Table Expression) is a named temporary result set defined with `WITH`. Use CTEs when:
> - You need to reference the same subquery multiple times
> - You want recursive queries
> - You want to improve readability of complex queries
>
> Subqueries are fine for simple one-off lookups. CTEs don't necessarily improve performance — the planner may inline them anyway.

---

**Q7. Explain ACID properties.**

> - **Atomicity**: All operations in a transaction succeed or all are rolled back
> - **Consistency**: Database moves from one valid state to another
> - **Isolation**: Concurrent transactions don't interfere with each other
> - **Durability**: Committed transactions survive system failures

---

**Q8. What is the difference between UNION and UNION ALL?**

> `UNION` removes duplicate rows and sorts the result (slower).
> `UNION ALL` keeps all rows including duplicates (faster).
> Always prefer `UNION ALL` unless you specifically need deduplication.

---

**Q9. What is a covering index?**

> A covering index includes all columns needed to answer a query, so the DB can satisfy it from the index alone without going back to the table (no heap fetch). This is called an "index-only scan."
>
> Example: `CREATE INDEX idx_orders_cover ON orders(user_id) INCLUDE (order_date, total_price);`

---

**Q10. Explain EXPLAIN ANALYZE output. What do "cost" and "rows" mean?**

> - `cost=X..Y` — X is startup cost, Y is total cost (in arbitrary units)
> - `rows=N` — planner's estimate of rows returned
> - `actual time=X..Y` — real execution time in milliseconds
> - `actual rows=N` — real row count
> - Large gap between estimated and actual rows = stale statistics → run ANALYZE

---

**Q11. What is the difference between a partial index and a composite index?**

> - **Partial index**: indexes only a subset of rows based on a WHERE condition. Smaller and faster for queries that match that condition.
> - **Composite index**: indexes multiple columns together. Column order matters — the index works for queries that use the leading columns.

---

**Q12. How does JSONB differ from JSON in PostgreSQL?**

> - `JSON` stores text as-is, re-parsed on each use
> - `JSONB` stores binary-parsed format, supports indexing (GIN), faster querying
> - `JSONB` doesn't preserve whitespace or key order
> - Always use `JSONB` unless you need exact input preservation

---

## Section 2: Advanced SQL (Q13–22)

**Q13. Write a recursive CTE to find all subordinates under a given manager.**

```sql
WITH RECURSIVE subordinates AS (
    SELECT id, name, manager_id, 0 AS depth
    FROM employees
    WHERE id = 1  -- starting manager

    UNION ALL

    SELECT e.id, e.name, e.manager_id, s.depth + 1
    FROM employees e
    JOIN subordinates s ON e.manager_id = s.id
)
SELECT * FROM subordinates WHERE depth > 0;
```

---

**Q14. What is a materialized view? When would you use it?**

> A materialized view stores the result of a query physically. Use it when:
> - The query is expensive and you don't need real-time data
> - You want to precompute aggregations/joins
>
> You must `REFRESH MATERIALIZED VIEW` to update it. For concurrent access during refresh, create a unique index and use `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

---

**Q15. What is table partitioning and what are its benefits?**

> Partitioning divides a large table into smaller physical pieces called partitions. Benefits:
> - Faster queries via partition pruning (only relevant partitions scanned)
> - Faster data archival (drop old partition instead of DELETE)
> - Better maintenance (VACUUM, index rebuilds per partition)
>
> Types: RANGE (dates, IDs), LIST (categories, regions), HASH (even distribution)

---

**Q16. What is the difference between RANK() and DENSE_RANK()?**

> Given scores: 100, 90, 90, 80
> - `RANK()`: 1, 2, 2, 4 (skips rank 3)
> - `DENSE_RANK()`: 1, 2, 2, 3 (no gaps)
>
> Use `DENSE_RANK()` when you want "N-th highest" without gaps.

---

**Q17. Explain optimistic vs pessimistic locking.**

> - **Pessimistic locking**: Lock the row when you read it (`SELECT FOR UPDATE`). Other transactions wait. Use for high-contention scenarios where conflicts are likely.
> - **Optimistic locking**: Don't lock on read. Check a version/timestamp on write. If it changed, abort and retry. Use when conflicts are rare and you want higher throughput.

---

**Q18. What are the 4 isolation levels and what anomalies does each prevent?**

> 1. **Read Uncommitted** — allows dirty reads (rarely used)
> 2. **Read Committed** (default) — prevents dirty reads
> 3. **Repeatable Read** — prevents dirty + non-repeatable reads
> 4. **Serializable** — prevents all anomalies including phantom reads

---

**Q19. How would you find duplicate rows in a table?**

```sql
-- Find duplicate emails
SELECT email, COUNT(*) AS cnt
FROM users
GROUP BY email
HAVING COUNT(*) > 1;

-- Delete duplicates keeping the earliest created
DELETE FROM users
WHERE user_id NOT IN (
    SELECT MIN(user_id)
    FROM users
    GROUP BY email
);
```

---

**Q20. What is the difference between LAG() and LEAD()?**

> - `LAG(col, n)` accesses the value n rows BEFORE the current row
> - `LEAD(col, n)` accesses the value n rows AFTER the current row
>
> Both default to n=1. Useful for period-over-period comparisons, calculating gaps between events.

---

**Q21. What is the N+1 query problem and how do you solve it?**

> The N+1 problem occurs when you run 1 query to get N records, then N additional queries to get related data for each record. Total: N+1 queries.
>
> Solution: use a JOIN to fetch everything in a single query.
>
> Example: Instead of looping `SELECT * FROM orders WHERE user_id = X` for each user, do `SELECT users.*, orders.* FROM users JOIN orders ON users.user_id = orders.user_id`.

---

**Q22. How do you do pagination efficiently in SQL?**

```sql
-- OFFSET pagination (simple but slow on large offsets)
SELECT * FROM products ORDER BY product_id LIMIT 20 OFFSET 100;

-- Cursor/keyset pagination (fast, recommended)
SELECT * FROM products
WHERE product_id > 100  -- last seen ID from previous page
ORDER BY product_id
LIMIT 20;
-- Keyset is faster because it doesn't scan skipped rows
```

---

## Section 3: AI & Vector SQL (Q23–38)

**Q23. What is a vector embedding and why do we store them in a database?**

> A vector embedding is a list of floating-point numbers that represents the semantic meaning of content. Similar content has similar vectors (close in vector space).
>
> We store them in SQL to combine semantic similarity search with regular SQL filters, joins, and business logic — no need for a separate vector database.

---

**Q24. What is pgvector? What distance operators does it support?**

> pgvector is a PostgreSQL extension for storing and querying vector embeddings.
>
> Distance operators:
> - `<->` L2 (Euclidean) distance
> - `<#>` Negative inner product
> - `<=>` Cosine distance (most used for text embeddings)
>
> Lower value = more similar for all operators.

---

**Q25. Explain cosine similarity. Why is it preferred for text embeddings?**

> Cosine similarity measures the angle between two vectors, regardless of magnitude. It ranges from -1 (opposite) to 1 (identical).
>
> It's preferred for text because the length of an embedding vector depends on the text length, not semantic meaning. Cosine similarity normalizes for this, comparing direction only.
>
> `similarity = 1 - cosine_distance`

---

**Q26. What is RAG? Describe the steps in a RAG pipeline.**

> RAG (Retrieval-Augmented Generation) grounds LLM answers in real data:
>
> 1. Embed the user's question
> 2. Search the vector DB for similar documents (top-k)
> 3. Retrieve the content and metadata
> 4. Construct a prompt: `context + question`
> 5. Send to LLM (e.g., GPT-4)
> 6. Return the grounded answer
>
> Prevents hallucinations by giving the LLM actual facts to work with.

---

**Q27. What is the difference between IVFFlat and HNSW indexes in pgvector?**

> - **IVFFlat**: Clusters vectors into lists at build time. Faster to build, less memory. Good starting point. Set `lists = sqrt(N)`.
> - **HNSW**: Hierarchical Navigable Small World. Better accuracy, more memory. Better recall for high-dimensional data. Recommended for production.
>
> Both are ANN (Approximate Nearest Neighbor) — they trade some accuracy for speed.

---

**Q28. What is chunking? How does chunk size affect RAG quality?**

> Chunking splits large documents into smaller pieces before embedding.
>
> - Too small (< 100 tokens): lacks context, low relevance
> - Too large (> 1000 tokens): dilutes the semantic signal, slower
> - Sweet spot: 256–512 tokens with 10-20% overlap between chunks
>
> Overlap ensures context isn't lost at chunk boundaries.

---

**Q29. What is hybrid search? Why is it better than pure vector search?**

> Hybrid search combines vector (semantic) search with keyword (BM25/FTS) search.
>
> - Vector search finds semantically similar content even without exact word matches
> - Keyword search catches exact terminology, product IDs, names
> - Combining both (via RRF - Reciprocal Rank Fusion) gives better overall recall
>
> Example: searching "M3 chip laptop" — vector finds semantic matches, keyword finds exact "M3" matches.

---

**Q30. How would you design a database schema for a chatbot with memory?**

```sql
-- Sessions group conversations
CREATE TABLE chat_sessions (session_id UUID PRIMARY KEY, user_id UUID, title TEXT, created_at TIMESTAMPTZ);

-- Messages with optional embeddings for semantic recall
CREATE TABLE chat_messages (
    id SERIAL PRIMARY KEY,
    session_id UUID REFERENCES chat_sessions,
    role VARCHAR(20) CHECK (role IN ('user','assistant','system')),
    content TEXT,
    embedding VECTOR(1536),  -- embed for semantic memory
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```
> For memory retrieval: embed the current question, find semantically similar past messages using vector search.

---

**Q31. What is the difference between RAG and fine-tuning?**

> - **RAG**: Retrieves external knowledge at inference time. No model training. Easy to update knowledge. Best for factual, grounded answers from your data.
> - **Fine-tuning**: Updates model weights on your data. Bakes knowledge into the model. Expensive to retrain. Better for style/tone/format adaptation.
>
> In practice: use RAG first; fine-tune only for specific behavior/style needs.

---

**Q32. How do you handle embedding updates when document content changes?**

> 1. Track `updated_at` timestamp on the document
> 2. When content changes, re-generate the embedding
> 3. Update the vector column in the same transaction as the content update
> 4. If using separate embedding table, use `ON DELETE CASCADE` on the FK
>
> For bulk updates, use background jobs to regenerate embeddings asynchronously.

---

**Q33. What is a token in the context of LLMs? Why does it matter for SQL applications?**

> A token is roughly 4 characters or 0.75 words of text. LLMs have a context window limit (e.g., GPT-4: 128K tokens).
>
> For SQL apps: you need to store token counts per message to manage context window overflow. When the conversation exceeds the limit, use semantic search to retrieve only the most relevant past messages instead of sending the full history.

---

**Q34. How would you implement semantic deduplication in SQL?**

```sql
-- Find near-duplicate documents (cosine similarity > 0.95)
SELECT a.id AS doc1, b.id AS doc2,
       1 - (a.embedding <=> b.embedding) AS similarity
FROM documents a
JOIN documents b ON a.id < b.id  -- avoid self-comparison and duplicates
WHERE 1 - (a.embedding <=> b.embedding) > 0.95
ORDER BY similarity DESC;
```

---

**Q35. What is the `<=>` operator in pgvector? Write a query that uses it.**

> `<=>` computes cosine distance (0 = identical, 2 = opposite).
>
```sql
-- Find top 5 docs similar to document with id=1
SELECT id, content,
       1 - (embedding <=> (SELECT embedding FROM documents WHERE id = 1)) AS similarity
FROM documents
WHERE id != 1
ORDER BY embedding <=> (SELECT embedding FROM documents WHERE id = 1)
LIMIT 5;
```

---

**Q36. What Azure OpenAI embedding models are available and what are their dimensions?**

> - `text-embedding-ada-002`: 1536 dimensions (legacy, widely used)
> - `text-embedding-3-small`: 1536 dimensions (better, cheaper)
> - `text-embedding-3-large`: 3072 dimensions (highest quality)
>
> You can reduce dimensions on `text-embedding-3-*` models using the `dimensions` parameter.

---

**Q37. How would you use SQL to build a recommendation system?**

```sql
-- Content-based: find products similar to what user bought
SELECT p.name, p.price, 1 - (pe.embedding <=> target.embedding) AS similarity
FROM product_embeddings pe
JOIN products p ON pe.product_id = p.product_id
CROSS JOIN (
    SELECT pe2.embedding FROM product_embeddings pe2
    JOIN orders o ON pe2.product_id = o.product_id
    WHERE o.user_id = $1
    ORDER BY o.order_date DESC LIMIT 1
) target
WHERE pe.product_id NOT IN (SELECT product_id FROM orders WHERE user_id = $1)
ORDER BY pe.embedding <=> target.embedding
LIMIT 5;
```

---

**Q38. What is sp_invoke_external_rest_endpoint in Azure SQL?**

> It's an Azure SQL system stored procedure that allows T-SQL to call external REST APIs including Azure OpenAI, Azure Cognitive Services, and any HTTPS endpoint. It enables native AI integration directly from SQL without leaving the database context.

---

## Section 4: Azure SQL Platform (Q39–50)

**Q39. What is the difference between Azure SQL Database and Azure SQL Managed Instance?**

> - **Azure SQL Database**: PaaS, cloud-native, subset of SQL Server features, lower cost, elastic pools
> - **Azure SQL Managed Instance**: Near 100% SQL Server compatibility, supports CLR, SQL Agent, cross-db queries — best for lift-and-shift migrations

---

**Q40. What is the Serverless compute tier in Azure SQL?**

> Serverless automatically pauses the database after a configurable idle period and resumes on the next connection. You're billed only for compute seconds used (not when paused). Ideal for dev/test or intermittent workloads. Cold start latency on resume is the main trade-off.

---

**Q41. Explain Transparent Data Encryption (TDE).**

> TDE encrypts data files at rest using AES-256. It's automatic and transparent to applications — no query changes needed. Azure SQL has TDE enabled by default using service-managed keys. You can bring your own key (BYOK) via Azure Key Vault for more control.

---

**Q42. What is Always Encrypted and how does it differ from TDE?**

> - **TDE**: Encrypts the database files on disk. The database engine can read plaintext — it decrypts when data is loaded into memory.
> - **Always Encrypted**: Client-side encryption. The database engine NEVER sees plaintext. Only the application with the encryption key can read/write the data. Protects against DBA snooping and cloud provider access.

---

**Q43. What is Row-Level Security (RLS) in Azure SQL?**

> RLS restricts which rows a user can see or modify using a predicate function. Applied transparently — the user's queries are automatically filtered. Use cases: multi-tenant apps, user-level data isolation.

---

**Q44. What is Azure SQL Ledger?**

> Azure SQL Ledger provides cryptographic proof that data hasn't been tampered with. It creates a blockchain-style digest of database changes stored in Azure Blob Storage.
>
> - **Updatable ledger tables**: track full change history
> - **Append-only ledger tables**: no updates/deletes allowed

---

**Q45. What are elastic pools in Azure SQL and when would you use them?**

> Elastic pools allow multiple databases to share a pool of compute resources (DTUs or vCores). Cost-effective when databases have different peak usage times. Instead of provisioning max capacity for each DB, they share resources and burst when needed.

---

**Q46. What is the difference between active geo-replication and auto-failover groups?**

> - **Active geo-replication**: manually create readable secondary in another region. Manual failover. Up to 4 secondaries.
> - **Auto-failover groups**: automatic failover with a single read-write endpoint that automatically redirects after failover. Simpler for applications — connection string doesn't change.

---

**Q47. What is Query Store in Azure SQL?**

> Query Store captures query execution plans and runtime statistics over time. It allows you to:
> - Identify regressed queries (plan changed, performance degraded)
> - Force a previous good plan (`sp_query_store_force_plan`)
> - Analyze top resource-consuming queries
> Enabled by default on Azure SQL.

---

**Q48. What is Automatic Tuning in Azure SQL?**

> Azure SQL's AI-driven feature that automatically:
> - Creates indexes identified as beneficial by the query optimizer
> - Drops indexes no longer used
> - Reverts to a previous query plan when regression is detected (Force Last Good Plan)
>
> Can be set to `ON` (auto-apply) or just report recommendations.

---

**Q49. What is Azure SQL Hyperscale?**

> Hyperscale is a service tier that decouples compute from storage, enabling:
> - Databases up to 100TB
> - Near-instant backups regardless of database size
> - Rapid scale-out with read replicas
> - Fast scale-up without data movement
>
> Best for large OLTP databases that need flexibility.

---

**Q50. How would you secure a multi-tenant SQL database application?**

> Multi-layered approach:
>
> 1. **Authentication**: Azure AD / Managed Identity — no passwords in connection strings
> 2. **Row-Level Security**: filter rows by tenant ID automatically
> 3. **Dynamic Data Masking**: mask PII for low-privilege roles
> 4. **TDE**: encrypt at rest (on by default)
> 5. **Always Encrypted**: for most sensitive fields (PII, financial)
> 6. **Network**: VNet service endpoints, Private Link
> 7. **Firewall**: whitelist specific IP ranges
> 8. **Auditing**: Azure SQL Audit log to storage/Event Hub
> 9. **Threat Detection**: Advanced Threat Protection for SQL injection alerts
> 10. **Ledger**: for tamper-proof audit of sensitive tables

---

## Scoring Guide

| Score | Assessment |
|-------|------------|
| 45–50 | Exam ready — excellent |
| 38–44 | Almost there — review weak areas |
| 28–37 | Need more practice on gaps |
| < 28  | Back to modules, more hands-on labs |
