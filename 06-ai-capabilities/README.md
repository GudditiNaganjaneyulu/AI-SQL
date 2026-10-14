# Domain 3 — Implement AI Capabilities in Database Solutions (25–30%)

This domain is where everything comes together: **embeddings**, **vector search**, **hybrid search**, and **retrieval-augmented generation (RAG)** — implemented inside the database with T-SQL.

## Prerequisites (don't skip)

| You need | From |
|---|---|
| Joins, `CROSS APPLY`, window functions, CTEs | Core T-SQL, Domain 1 → Advanced T-SQL |
| JSON functions (`JSON_OBJECT`, `OPENJSON`, `FOR JSON`) | Domain 1 → JSON in the Database |
| Database scoped credentials, managed identity | Domain 2 → Securing Endpoints and Identities |
| Change Tracking, CDC, Azure Functions SQL trigger | Domain 2 → Monitoring and Change Handling |
| Feature availability per platform | Azure SQL Platform → The SQL Platform Family |

## Chapters and the objectives they cover

| # | Chapter | Official objective |
|---|---|---|
| 1 | [AI Concepts for SQL Developers](01-ai-concepts.md) | Background for all of Domain 3; evaluate external models |
| 2 | [External Models and Embeddings](02-external-models-and-embeddings.md) | Create and manage external models; columns to embed; chunking; generate embeddings |
| 3 | [Keeping Embeddings Up to Date](03-embedding-maintenance.md) | Choose an embedding maintenance method |
| 4 | [Vector Search](04-vector-search.md) | Vector data type, indexes, size; VECTOR_* functions; ANN vs KNN; index types and metrics; implement vector search |
| 5 | [Full-Text and Hybrid Search](05-full-text-and-hybrid-search.md) | Choose full-text/semantic/hybrid; implement full-text and hybrid search; RRF; evaluate performance |
| 6 | [RAG in T-SQL](06-rag-in-tsql.md) | RAG use cases; prompts with `sp_invoke_external_rest_endpoint`; JSON for models; send and extract responses |

## Matching labs

- **Lab 6** — Vector search (no AI account required — uses small mock vectors)
- **Lab 7** — RAG end to end (requires an Azure OpenAI / Microsoft Foundry deployment)
