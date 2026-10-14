# Cheat Sheet

## "Which feature when?" — the decisions the exam loves

### Data protection

| Requirement | Pick |
|---|---|
| DBAs / cloud operators must never see plaintext | **Always Encrypted** (deterministic if you search by equality) |
| Hide values on screen for some users, no app change | **Dynamic Data Masking** (+ `UNMASK`) — not a security boundary |
| Users see only their rows | **Row-Level Security** (inline TVF + security policy, `SESSION_CONTEXT`) |
| Encrypt files/backups at rest transparently | **TDE** |
| Prove data wasn't tampered with | **Ledger tables** |
| Who did what, when | **Auditing** (Storage / Log Analytics / Event Hubs) |
| App connects with no password | **Managed identity + Microsoft Entra auth** |

### Table types

| Need | Pick |
|---|---|
| History / point-in-time queries | **Temporal** (`FOR SYSTEM_TIME AS OF`) |
| Tamper evidence | **Ledger** (updatable or `APPEND_ONLY`) |
| Multi-hop relationships | **Graph** (`AS NODE`, `AS EDGE`, `MATCH`, `SHORTEST_PATH`) |
| Extreme OLTP / temp data | **Memory-optimized** (`SCHEMA_ONLY` for non-durable) |
| Query lake files in place | **External table / OPENROWSET** |
| Huge analytic table | **Clustered columnstore** |
| OLTP + live analytics | **Nonclustered columnstore** |

### Change handling / embedding maintenance

| Need | Pick |
|---|---|
| Which rows changed (keys only), lightweight | **Change Tracking** |
| Old + new values, history, ETL | **CDC** |
| Push changes to Event Hubs in near real time | **Change event streaming** |
| Serverless code on each change | **Azure Functions SQL trigger** (needs CT) |
| Low-code workflow | **Logic Apps** |
| Same transaction (small/low volume) | **Trigger** (queue, don't call the model) |

### Search

| Need | Pick |
|---|---|
| Exact codes/names/words | **Full-text** (`CONTAINS`, `FREETEXT`, `…TABLE` for `RANK`) |
| Meaning / synonyms | **Vector search** |
| General search box / RAG retrieval | **Hybrid + RRF** (`1/(k+rank)`, k≈60) |
| Typos / near-duplicate names | **Fuzzy matching** (`EDIT_DISTANCE`, `JARO_WINKLER_*`) |
| Pattern validation | **Regex** (`REGEXP_LIKE` needs compat 170) |

### Isolation

| Need | Pick |
|---|---|
| Readers shouldn't block writers (default Azure SQL DB) | **RCSI** |
| Consistent view for the whole transaction, no phantoms, no read locks | **SNAPSHOT** (conflict → error 3960) |
| Strictest, blocking OK | **SERIALIZABLE** |

## Syntax quick reference

### Vectors

```sql
col vector(1536)                    -- float32, max 1,998 dims
col vector(1536, float16)           -- max 3,996 dims
VECTOR_DISTANCE('cosine'|'euclidean'|'dot', v1, v2)   -- exact, never uses index; smaller = closer
VECTOR_NORMALIZE(v, 'norm2')        VECTORPROPERTY(v, 'Dimensions'|'BaseType')

CREATE VECTOR INDEX vix ON t(col) WITH (METRIC = 'cosine', TYPE = 'DiskANN');   -- ≥ 100 rows

SELECT TOP (10) WITH APPROXIMATE t.id, r.distance
FROM VECTOR_SEARCH(TABLE = dbo.t AS t, COLUMN = col, SIMILAR_TO = @q, METRIC = 'cosine') AS r
WHERE t.category = 'x'               -- iterative filtering
ORDER BY r.distance;                 -- distance only, ASC
```

### AI functions

```sql
CREATE DATABASE SCOPED CREDENTIAL [https://res.openai.azure.com]
  WITH IDENTITY = 'Managed Identity', SECRET = '{"resourceid":"https://cognitiveservices.azure.com"}';

CREATE EXTERNAL MODEL M WITH (LOCATION = '<…/embeddings?api-version=…>', API_FORMAT = 'Azure OpenAI',
  MODEL_TYPE = EMBEDDINGS, MODEL = 'text-embedding-3-small', CREDENTIAL = [https://res.openai.azure.com]);

AI_GENERATE_EMBEDDINGS(text USE MODEL M [PARAMETERS '{"dimensions":768}'])
AI_GENERATE_CHUNKS(SOURCE = text, CHUNK_TYPE = FIXED, CHUNK_SIZE = 800, OVERLAP = 10)   -- compat 170; use with CROSS APPLY

EXEC @ret = sp_invoke_external_rest_endpoint @url = N'…', @method = 'POST', @credential = [...],
     @payload = @json, @timeout = 120, @retry_count = 3, @response = @resp OUTPUT;   -- @ret 0 = 2xx
-- answer: $.result.choices[0].message.content   (use OPENJSON … nvarchar(max))
```

Permissions: `EXECUTE ANY EXTERNAL ENDPOINT` · `EXECUTE ON EXTERNAL MODEL::M` · `REFERENCES ON DATABASE SCOPED CREDENTIAL::[...]`
SQL Server 2025: `sp_configure 'external rest endpoint enabled', 1` · preview features: `ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON`

### JSON

```sql
JSON_VALUE(j, '$.a')              -- scalar (≤ 4000 chars)       JSON_QUERY(j, '$.arr')  -- object/array
JSON_PATH_EXISTS(j, '$.a')        JSON_CONTAINS(j, 'x', '$.tags[*]')   ISJSON(s)
OPENJSON(j [, path]) WITH (c type '$.p')                  JSON_MODIFY(j, 'append $.tags', 'x')
JSON_OBJECT('k': v)   JSON_ARRAY(a, b)   JSON_ARRAYAGG(x ORDER BY x)   JSON_OBJECTAGG(k : v)
SELECT … FOR JSON PATH [, ROOT('x')] [, WITHOUT_ARRAY_WRAPPER]
CREATE JSON INDEX jx ON t(jsoncol) FOR ('$.a', '$.b');    -- needs clustered PK, json type
```

### Regex and fuzzy

```sql
REGEXP_LIKE(s, p [, 'i'])   REGEXP_REPLACE(s, p, r)   REGEXP_SUBSTR(s, p, start, occ, flags, group)
REGEXP_INSTR   REGEXP_COUNT   REGEXP_MATCHES (TVF)   REGEXP_SPLIT_TO_TABLE (TVF)
EDIT_DISTANCE(a, b)  -- 0 = same        EDIT_DISTANCE_SIMILARITY(a, b)  -- 100 = same
JARO_WINKLER_DISTANCE(a, b) -- 0 = same JARO_WINKLER_SIMILARITY(a, b)   -- 100 = same
```

### Error handling

```sql
SET XACT_ABORT ON;
BEGIN TRY BEGIN TRAN; … COMMIT; END TRY
BEGIN CATCH IF XACT_STATE() <> 0 ROLLBACK; THROW; END CATCH
-- THROW 50001, 'msg', 1;  XACT_STATE: 1 committable, -1 doomed, 0 none;  1205 = deadlock victim
```

### Window functions

```sql
ROW_NUMBER()/RANK()/DENSE_RANK()/NTILE(n) OVER (PARTITION BY … ORDER BY …)
SUM(x) OVER (ORDER BY d ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)   -- running total (use ROWS)
LAG(x) / LEAD(x) / FIRST_VALUE(x) / LAST_VALUE(x) (needs full frame)
```

### Performance

```sql
SET STATISTICS IO, TIME ON;
sys.dm_exec_requests (blocking_session_id) · sys.dm_exec_query_stats · sys.dm_os_wait_stats / sys.dm_db_wait_stats
sys.dm_db_index_usage_stats · sys.dm_db_missing_index_details · sys.dm_db_resource_stats
ALTER DATABASE CURRENT SET QUERY_STORE = ON;
EXEC sp_query_store_force_plan @query_id, @plan_id;   EXEC sp_query_store_set_hints @query_id, N'OPTION(...)';
ALTER DATABASE CURRENT SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);
```

### SQL Database Projects

```bash
dotnet new sqlproj -n Db            # SDK-style (Microsoft.Build.Sql)
dotnet build Db.sqlproj             # → .dacpac, validates syntax + references
sqlpackage /Action:Publish | Script | DeployReport | Extract | DriftReport
```
Reference data → idempotent `MERGE` in **post-deployment** script. Approvals → GitHub **environments**. Reviewers → **CODEOWNERS**. Azure login → **OIDC**.

### Data API builder

```bash
dab init --database-type mssql --connection-string "@env('SQL_CONN')"
dab add Book --source dbo.Books --permissions "anonymous:read"
dab add V --source dbo.vX --source.type view --source.key-fields "id" --permissions "authenticated:read"
dab add P --source dbo.usp --source.type stored-procedure --permissions "authenticated:execute" --graphql.operation query
dab update A --relationship bs --target.entity B --cardinality many --relationship.fields "aid:aid"
dab update Book --cache.enabled true --cache.ttl-seconds 60
dab start
```
REST: `$select $filter $orderby $first $after` (cursor paging, `nextLink`). GraphQL: `filter`, `orderBy`, `first`, `after`, `endCursor`, `hasNextPage`.

### Copilot / MCP

`.github/copilot-instructions.md` (repo-wide) · `.github/instructions/*.instructions.md` with `applyTo` · `.vscode/mcp.json` · Agent mode calls MCP tools · least-privilege, read-only identities for agents.
