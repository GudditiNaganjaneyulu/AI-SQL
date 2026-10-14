# Practice Exam (40 Questions)

> Original study questions written against the official DP-800 skills outline (October 19, 2026). They are **not** real exam questions. Time yourself: aim for ~90 seconds per question. Answers and explanations are at the end.

## Domain 1 — Design and develop (Q1–Q15)

**Q1.** You need invoice numbers that are unique across the `Invoices` and `CreditNotes` tables, and the application must obtain the number **before** inserting. What should you use?
A. `IDENTITY` on both tables  B. A `SEQUENCE` object  C. `NEWID()`  D. A computed column

**Q2.** A product table has a `Price` column. Which data type avoids rounding errors in monetary calculations?
A. `float`  B. `real`  C. `decimal(10,2)`  D. `varchar(10)`

**Q3.** Auditors require proof that payment records have not been altered, even by database administrators. Existing history is not required. What should you create?
A. Temporal table  B. Ledger table  C. Memory-optimized table  D. Table with an AFTER trigger

**Q4.** You must report each product's price as it was on any past date. What is the simplest solution?
A. CDC  B. A system-versioned temporal table  C. Change Tracking  D. An audit trigger

**Q5.** An OLTP `Orders` table must also support real-time analytical dashboards without a separate warehouse. Which index should you add?
A. Clustered columnstore  B. Nonclustered columnstore  C. Filtered index  D. Vector index

**Q6.** You have `Attributes json` on `Sales.Products` and frequently filter on `$.color`. `CREATE JSON INDEX` fails with an error. What is the most likely cause?
A. The table has no clustered primary key  B. JSON indexes need nvarchar(max)  C. The column is NOT NULL  D. JSON indexes require a vector column

**Q7.** Which expression returns the `tags` **array** from a JSON document?
A. `JSON_VALUE(j, '$.tags')`  B. `JSON_QUERY(j, '$.tags')`  C. `JSON_PATH_EXISTS(j, '$.tags')`  D. `ISJSON(j)`

**Q8.** You need one row per category containing a JSON array of product names sorted alphabetically. Which function?
A. `STRING_AGG`  B. `JSON_OBJECTAGG`  C. `JSON_ARRAYAGG(Name ORDER BY Name)`  D. `FOR JSON AUTO`

**Q9.** A `CHECK` constraint must validate email formats using `REGEXP_LIKE`. The statement fails because the function isn't recognized. What should you change?
A. Enable `PREVIEW_FEATURES`  B. Set compatibility level to 170  C. Enable full-text search  D. Use `JSON_CONTAINS`

**Q10.** You need to identify customer records whose last names are probably misspellings of each other ("Carter" vs "Cartre"). Which function fits best?
A. `REGEXP_LIKE`  B. `JARO_WINKLER_SIMILARITY`  C. `VECTOR_DISTANCE`  D. `SOUNDEX` only

**Q11.** `JARO_WINKLER_DISTANCE('Colour','Color')` returns 0.033. What does a value of 0 mean?
A. No similarity  B. Identical strings  C. NULL input  D. Error

**Q12.** Which programmability object offers the best performance for a reusable, parameterized query used in joins?
A. Multi-statement TVF  B. Scalar UDF  C. Inline table-valued function  D. Stored procedure

**Q13.** Inside a CATCH block, `XACT_STATE()` returns -1. What must you do?
A. COMMIT  B. ROLLBACK  C. Nothing  D. Retry the statement in the same transaction

**Q14.** Your team uses GitHub Copilot. You want every chat request in the repository to follow your T-SQL naming conventions. What should you create?
A. `.vscode/settings.json`  B. `.github/copilot-instructions.md`  C. `.github/CODEOWNERS`  D. `dab-config.json`

**Q15.** A Copilot agent will query a production Azure SQL database through an MCP server to produce reports. Which configuration is most appropriate?
A. Connect as `db_owner` so all tools work  B. A read-only, least-privilege identity and only the needed tools enabled  C. SQL authentication with a shared password  D. Disable auditing to reduce overhead

## Domain 2 — Secure, optimize and deploy (Q16–Q30)

**Q16.** Cloud operators and DBAs must never see customers' national ID numbers, but the app must look customers up by exact national ID. What should you use?
A. DDM  B. TDE  C. Always Encrypted with deterministic encryption  D. Always Encrypted with randomized encryption

**Q17.** Support staff should see only the last four digits of phone numbers. No application changes are allowed. What should you use?
A. RLS  B. Dynamic Data Masking `partial()`  C. Column-level encryption  D. Ledger

**Q18.** In a multi-tenant table, each tenant's application session must see only its own rows. The app sets the tenant ID after connecting. What should you implement?
A. A view per tenant  B. RLS with a predicate using `SESSION_CONTEXT`  C. DDM  D. DENY SELECT

**Q19.** A user has `GRANT SELECT` on a schema via one role and `DENY SELECT` on a table in that schema via another role. Result?
A. Can select  B. Cannot select that table  C. Error at login  D. Depends on the order roles were granted

**Q20.** An Azure Function must call Azure SQL Database without storing any secret. What should you configure?
A. SQL login in app settings  B. Managed identity + `CREATE USER … FROM EXTERNAL PROVIDER`  C. Shared access signature  D. Connection string in source control

**Q21.** T-SQL must call Azure OpenAI using the logical server's managed identity. Which Azure role should the identity receive on the Azure OpenAI resource?
A. Owner  B. Cognitive Services OpenAI User  C. SQL DB Contributor  D. Reader

**Q22.** Reports running under READ COMMITTED block order-entry updates on SQL Server. You want readers to stop blocking writers without code changes. What should you do?
A. Use SERIALIZABLE  B. Enable READ_COMMITTED_SNAPSHOT  C. Add NOLOCK hints everywhere  D. Increase MAXDOP

**Q23.** Under SNAPSHOT isolation, an update fails with error 3960. What happened?
A. Deadlock  B. Update conflict with a concurrent transaction  C. Lock timeout  D. Version store full

**Q24.** A query plan shows a Key Lookup executed 200,000 times. What is the usual fix?
A. Add a covering index with `INCLUDE`  B. Rebuild the clustered index  C. Increase DTUs  D. Add `OPTION (RECOMPILE)`

**Q25.** After a statistics update, a critical query regressed. You need the fastest fix without changing application code. What should you do?
A. Restart the server  B. Force the previous plan with Query Store  C. Drop all indexes  D. Change compatibility level to 100

**Q26.** Which Azure portal feature shows the top resource-consuming queries of an Azure SQL Database using Query Store data?
A. Azure Advisor  B. Query Performance Insight  C. Application Insights  D. Defender for SQL

**Q27.** A SQL Database Project must load status lookup values on every deployment without duplicating rows. Where and how?
A. Pre-deployment script with INSERT  B. Post-deployment script with an idempotent MERGE  C. A table trigger  D. Manually after deployment

**Q28.** Someone created an index directly in production. How do you detect this difference from source control?
A. `dotnet build`  B. Schema compare / `sqlpackage /Action:DeployReport` against production  C. Query Store  D. DBCC CHECKDB

**Q29.** Production database deployments must require a manual approval in GitHub Actions. What should you configure?
A. CODEOWNERS  B. A GitHub environment with required reviewers  C. A branch named prod  D. A cron trigger

**Q30.** You expose `Sales.vOrderSummary` (a view) through Data API builder. `dab add` fails. What is missing?
A. `--source.key-fields`  B. `--graphql.operation`  C. `--rest.methods`  D. `--cache.enabled`

## Domain 3 — AI capabilities (Q31–Q40)

**Q31.** Which object stores an AI model's endpoint, API format, model type and credential so that `AI_GENERATE_EMBEDDINGS` can use it?
A. Database scoped credential  B. External data source  C. External model  D. Linked server

**Q32.** You are embedding products. Which input is most appropriate?
A. ProductID + Price  B. Name + Category + Description concatenated with labels  C. SKU only  D. The whole row including internal cost

**Q33.** Product descriptions change a few times per minute. Embeddings must update within seconds with minimal impact on write transactions. Which approach is best?
A. AFTER trigger calling the model synchronously  B. Azure Functions with SQL trigger binding  C. Nightly full re-embedding  D. Manual updates

**Q34.** Which statement about `VECTOR_DISTANCE` is true?
A. It uses vector indexes automatically  B. It always computes exact distance and never uses an index  C. It only supports cosine  D. Larger values mean more similar

**Q35.** `CREATE VECTOR INDEX` fails with error 42266 on a table of 40 rows. What should you do?
A. Use `TYPE = 'HNSW'`  B. Load at least 100 non-NULL vectors, or use exact search  C. Change the metric  D. Partition the table

**Q36.** Which query correctly performs approximate search with a latest-version vector index?
A. `VECTOR_SEARCH(…, TOP_N = 10)`  B. `SELECT TOP (10) WITH APPROXIMATE … FROM VECTOR_SEARCH(…) AS r ORDER BY r.distance`  C. `SELECT TOP (10) … ORDER BY VECTOR_DISTANCE(…) DESC`  D. `SELECT … FROM VECTOR_SEARCH(…) ORDER BY r.distance, t.title`

**Q37.** A table has 8,000 vectors and queries always filter to ~200 rows by tenant first. Exact results are required. What should you use?
A. ANN with DiskANN  B. Exact KNN with `VECTOR_DISTANCE` after the filter  C. Full-text search  D. Fuzzy matching

**Q38.** You combine full-text results and vector results. Why use Reciprocal Rank Fusion instead of summing raw scores?
A. RRF is faster  B. Scores are on different scales; RRF uses rank positions  C. RRF needs no indexes  D. Full-text can't return scores

**Q39.** In a RAG stored procedure, `JSON_VALUE(@response, '$.result.choices[0].message.content')` returns NULL for long answers. Why, and what's the fix?
A. Wrong path; use `$.choices`  B. JSON_VALUE returns at most 4,000 chars; use `OPENJSON … WITH (… nvarchar(max))`  C. The model failed; retry  D. Need `FOR JSON`

**Q40.** Which scenario is the **poorest** fit for RAG?
A. Answering questions over product manuals  B. Recommending products from the catalog based on a description  C. Calculating exact quarterly revenue totals  D. Summarizing a customer's recent support tickets

---

## Answers and explanations

| Q | Answer | Why |
|---|---|---|
| 1 | **B** | A SEQUENCE is shared across tables and `NEXT VALUE FOR` gives the value before insert. |
| 2 | **C** | `decimal` is exact; `float`/`real` are approximate. |
| 3 | **B** | Ledger provides cryptographic tamper evidence; temporal provides history only. |
| 4 | **B** | `FOR SYSTEM_TIME AS OF` answers point-in-time questions directly. |
| 5 | **B** | Nonclustered columnstore enables real-time operational analytics on rowstore OLTP tables. |
| 6 | **A** | JSON indexes require a clustered primary key on the table. |
| 7 | **B** | `JSON_QUERY` returns objects/arrays; `JSON_VALUE` returns scalars only (NULL in lax mode for arrays). |
| 8 | **C** | `JSON_ARRAYAGG` aggregates into a JSON array and supports `ORDER BY`. |
| 9 | **B** | `REGEXP_LIKE` requires compatibility level 170. |
| 10 | **B** | Fuzzy similarity is designed for spelling variations. Vector search measures meaning, regex exact patterns. |
| 11 | **B** | Distance 0 = identical (similarity functions use 100 = identical). |
| 12 | **C** | Inline TVFs are expanded by the optimizer like views. |
| 13 | **B** | -1 = uncommittable transaction; it must be rolled back. |
| 14 | **B** | Repository-wide custom instructions for Copilot. |
| 15 | **B** | Least privilege, read-only identity, minimal tools; never over-privileged agents. |
| 16 | **C** | Always Encrypted hides data from the server; deterministic supports equality lookups. |
| 17 | **B** | DDM `partial()` masks output without app changes. |
| 18 | **B** | RLS predicate comparing the tenant column to `SESSION_CONTEXT`. |
| 19 | **B** | DENY overrides GRANT. |
| 20 | **B** | Managed identity + Entra database user = passwordless. |
| 21 | **B** | Cognitive Services OpenAI User allows inference calls. |
| 22 | **B** | RCSI uses row versions so readers don't take shared locks. |
| 23 | **B** | 3960 = snapshot update conflict. |
| 24 | **A** | Covering index removes lookups. |
| 25 | **B** | Query Store plan forcing (or automatic tuning FORCE_LAST_GOOD_PLAN). |
| 26 | **B** | Query Performance Insight is the portal view over Query Store for Azure SQL DB. |
| 27 | **B** | Idempotent MERGE in the post-deployment script. |
| 28 | **B** | Compare the model with the target to detect schema drift. |
| 29 | **B** | Environments with required reviewers gate jobs on approval. |
| 30 | **A** | Views have no primary key; DAB needs key fields. |
| 31 | **C** | `CREATE EXTERNAL MODEL`. |
| 32 | **B** | Embed meaningful text with context; filter numeric attributes relationally. |
| 33 | **B** | Asynchronous, near-real-time, keeps HTTP calls out of user transactions. |
| 34 | **B** | `VECTOR_DISTANCE` is always exact; use `VECTOR_SEARCH` for ANN. |
| 35 | **B** | Vector indexes need ≥ 100 non-NULL vectors; small tables can use exact search. |
| 36 | **B** | `TOP (N) WITH APPROXIMATE` + ORDER BY distance only; `TOP_N` is deprecated. |
| 37 | **B** | Small, pre-filtered candidate sets → exact KNN is fast and 100% accurate. |
| 38 | **B** | RRF fuses by rank, avoiding score normalization problems. |
| 39 | **B** | `JSON_VALUE` is limited to 4,000 characters in lax mode. |
| 40 | **C** | Exact aggregations should be computed with SQL, not generated by an LLM. |

## Scoring

| Score | Meaning |
|---|---|
| 36–40 | Ready — take the official practice assessment |
| 32–35 | Nearly there — revise the domains of your wrong answers |
| < 32 | Re-study the weakest domain and redo its labs before re-testing |
