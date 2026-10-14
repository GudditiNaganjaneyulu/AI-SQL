# Glossary

| Term | Meaning |
|---|---|
| **ACID** | Atomicity, Consistency, Isolation, Durability — guarantees of a transaction |
| **ADR (Accelerated Database Recovery)** | Engine feature giving fast rollback/recovery using a persistent version store; enables optimized locking |
| **Always Encrypted** | Client-side column encryption; the server never sees plaintext |
| **ANN** | Approximate nearest neighbour search using an index (e.g., DiskANN); fast, near-exact |
| **APPLY (CROSS/OUTER)** | Evaluate a table expression for each row of the left input |
| **Auditing** | Recording database events (who did what, when) to Storage, Log Analytics or Event Hubs |
| **CDC (Change Data Capture)** | Log-based capture of inserted/updated/deleted rows with before/after values |
| **CES (Change event streaming)** | Streams row changes from the database to Event Hubs as CloudEvents |
| **Change Tracking** | Lightweight tracking of which rows changed (keys + operation), not values |
| **Chunking** | Splitting long text into smaller pieces before embedding |
| **Clustered index** | The table's rows stored in key order; one per table |
| **Columnstore** | Column-oriented, compressed storage for analytics |
| **Compatibility level** | Database setting that controls T-SQL behaviour/features (170 = SQL Server 2025 level) |
| **Cosine distance** | 1 − cosine similarity; 0 = same direction, 2 = opposite |
| **CTE** | Common table expression — a named temporary result set for one statement |
| **dacpac** | Compiled model of a database produced by building a SQL Database Project |
| **DAB (Data API builder)** | Open-source engine that exposes database objects as REST, GraphQL and MCP endpoints from a JSON config |
| **Database scoped credential** | Database object storing authentication info for external calls |
| **DDM (Dynamic Data Masking)** | Masks column values in query results for users without UNMASK |
| **Deadlock** | Circular lock wait; one session is killed with error 1205 |
| **DiskANN** | Graph-based ANN algorithm used by SQL vector indexes |
| **DMV** | Dynamic management view — live engine state (`sys.dm_*`) |
| **Embedding** | A vector representing the meaning of content |
| **Entra ID (Microsoft Entra ID)** | Microsoft's cloud identity service (formerly Azure AD) |
| **External model** | Database object describing an AI model endpoint (`CREATE EXTERNAL MODEL`) |
| **Full-text search** | Word-based search with CONTAINS/FREETEXT and full-text indexes |
| **Fuzzy matching** | Similarity of spellings (edit distance, Jaro-Winkler) |
| **Graph table** | Node and edge tables queried with MATCH |
| **Hybrid search** | Combining keyword and vector search results |
| **Iterative filtering** | Applying WHERE predicates during ANN vector search |
| **KNN** | Exact k-nearest neighbour search (compares with every vector) |
| **Ledger table** | Tamper-evident table with cryptographic verification |
| **Managed identity** | Azure-managed identity for a resource; no secrets to store |
| **MCP (Model Context Protocol)** | Open protocol that lets AI agents discover and call tools on servers |
| **Memory-optimized table** | In-memory OLTP table with lock-free structures |
| **Optimized locking** | TID locking + lock after qualification to reduce blocking |
| **Partitioning** | Splitting a table/index into partitions by a column's values |
| **Query Store** | Persistent history of queries, plans and runtime stats |
| **Query Performance Insight** | Azure portal view of top queries for Azure SQL Database |
| **RAG** | Retrieval-augmented generation: retrieve your data, give it to an LLM as context |
| **RCSI** | Read Committed Snapshot Isolation — row versioning for READ COMMITTED |
| **RLS (Row-Level Security)** | Predicate-based row filtering inside the engine |
| **RRF (Reciprocal Rank Fusion)** | Combining ranked lists with Σ 1/(k + rank) |
| **Sargable** | A predicate that can use an index seek |
| **Schema drift** | Live database differs from the source-controlled model |
| **SDK-style project** | SQL project format based on `Microsoft.Build.Sql` |
| **SEQUENCE** | Object generating numbers independently of tables |
| **SESSION_CONTEXT** | Key/value pairs set per session, used by RLS |
| **Structured output** | LLM output constrained to valid JSON matching a schema |
| **TDE** | Transparent Data Encryption — encrypts data files and backups at rest |
| **Temporal table** | System-versioned table keeping row history |
| **Token** | Unit of text processed by a language model |
| **Vector** | Fixed-length array of numbers; SQL `vector(n)` data type |
| **Vector index** | ANN index on a vector column (`CREATE VECTOR INDEX`) |
