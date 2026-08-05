# Module 4: Azure SQL & Cloud-Specific Features

**Duration:** Week 7
**Goal:** Understand the Azure SQL platform, security model, and cloud-native AI integration.

---

## 1. Azure SQL Product Family

| Product | Best For | Key Difference |
|---------|---------|----------------|
| **Azure SQL Database** | Cloud-native apps, SaaS | PaaS, fully managed, hyperscale available |
| **Azure SQL Managed Instance** | Lift-and-shift from on-prem | Near 100% SQL Server compatibility |
| **SQL Server on Azure VM** | Full SQL Server control | IaaS, you manage OS + patches |
| **Azure SQL Edge** | IoT / edge devices | Lightweight, runs on ARM |
| **Azure Synapse Analytics** | Data warehousing + analytics | MPP, Spark integration |

---

## 2. Service Tiers

### Azure SQL Database
| Tier | Use Case | Key Feature |
|------|---------|-------------|
| DTU-based (Basic/Standard/Premium) | Predictable workloads | Bundled compute+storage |
| vCore General Purpose | Balanced | Separate compute/storage scaling |
| vCore Business Critical | High OLTP, low latency | In-memory OLTP, read replicas |
| Hyperscale | Large databases (up to 100TB) | Rapid scale-out, fast backups |
| **Serverless** | Intermittent workloads | Auto-pause, auto-scale, pay-per-use |

---

## 3. Security

### Always Encrypted
```sql
-- Always Encrypted protects sensitive data — encrypted at rest AND in transit
-- The DB never sees plaintext — only the application with the key does

-- Column encryption types:
-- Deterministic: same value = same ciphertext (allows equality search)
-- Randomized: same value = different ciphertext (more secure, no search)

-- Example column master key (done via SSMS or PowerShell)
CREATE COLUMN MASTER KEY MyCMK
WITH (
    KEY_STORE_PROVIDER_NAME = 'AZURE_KEY_VAULT',
    KEY_PATH = 'https://myvault.vault.azure.net/keys/mykey/version'
);

CREATE COLUMN ENCRYPTION KEY MyCEK
WITH VALUES (
    COLUMN_MASTER_KEY = MyCMK,
    ALGORITHM = 'RSA_OAEP',
    ENCRYPTED_VALUE = 0x...
);
```

### Transparent Data Encryption (TDE)
- Encrypts data files at rest automatically
- Enabled by default on Azure SQL
- Uses AES-256

### Row-Level Security (RLS)
```sql
-- Only users see their own data
CREATE SCHEMA security;

CREATE FUNCTION security.user_filter(@user_id UUID)
RETURNS TABLE WITH SCHEMABINDING
AS RETURN
    SELECT 1 AS result
    WHERE @user_id = CAST(SESSION_CONTEXT(N'user_id') AS UUID);

CREATE SECURITY POLICY user_policy
ADD FILTER PREDICATE security.user_filter(user_id) ON dbo.orders,
ADD BLOCK PREDICATE  security.user_filter(user_id) ON dbo.orders;

-- PostgreSQL equivalent
CREATE POLICY user_isolation ON orders
    USING (user_id = current_setting('app.current_user_id')::UUID);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
```

### Dynamic Data Masking
```sql
-- Mask sensitive columns (T-SQL / Azure SQL)
ALTER TABLE users
ALTER COLUMN email ADD MASKED WITH (FUNCTION = 'email()');

ALTER TABLE users
ALTER COLUMN phone ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XXX-",4)');

-- Grant unmask permission
GRANT UNMASK ON users TO privileged_user;
```

---

## 4. Azure SQL Ledger

Blockchain-style immutable audit trail:

```sql
-- Updatable ledger table — tracks every change
CREATE TABLE account_balances (
    account_id  INT PRIMARY KEY,
    balance     DECIMAL(18,2)
)
WITH (LEDGER = ON);

-- Append-only ledger table — no updates allowed
CREATE TABLE audit_log (
    event_id    BIGINT GENERATED ALWAYS AS ROW START,
    event_type  NVARCHAR(100),
    payload     NVARCHAR(MAX)
)
WITH (
    LEDGER = ON,
    APPEND_ONLY = ON
);

-- Verify ledger integrity
EXECUTE sp_verify_database_ledger;

-- View ledger history for a row
SELECT * FROM sys.database_ledger_transactions;
```

---

## 5. Elastic Pools

Share compute resources across multiple databases:

```sql
-- Useful when databases have different peak times
-- e.g., one customer's peak is morning, another's is evening
-- Pool handles bursting automatically

-- Create an elastic pool (Azure Portal / CLI)
az sql elastic-pool create \
  --name mypool \
  --server myserver \
  --resource-group myrg \
  --edition GeneralPurpose \
  --capacity 4  -- vCores

-- Add database to pool
az sql db create \
  --name mydb \
  --server myserver \
  --elastic-pool mypool
```

---

## 6. Read Scale-Out & Replicas

```sql
-- Route read-only queries to a replica (Business Critical / Hyperscale)
-- Connection string parameter:
-- ApplicationIntent=ReadOnly

-- In application code:
-- "Server=myserver.database.windows.net;Database=mydb;
--  Authentication=Active Directory Default;
--  ApplicationIntent=ReadOnly"

-- Verify you're on replica
SELECT DATABASEPROPERTYEX(DB_NAME(), 'Updateability');
-- Returns 'READ_ONLY' when on replica
```

---

## 7. Azure AI Integration

### Azure SQL + Azure AI Services
```sql
-- Azure SQL Database can call external REST endpoints
-- including Azure Cognitive Services and Azure OpenAI

-- Example: Sentiment analysis via Azure AI Language
DECLARE @response NVARCHAR(MAX);
EXEC sp_invoke_external_rest_endpoint
    @url = 'https://your-cognitive.cognitiveservices.azure.com/text/analytics/v3.1/sentiment',
    @method = 'POST',
    @headers = '{"Ocp-Apim-Subscription-Key": "your-key", "Content-Type": "application/json"}',
    @payload = '{"documents": [{"id": "1", "text": "This product is amazing!"}]}',
    @response = @response OUTPUT;

SELECT JSON_VALUE(@response, '$.documents[0].sentiment') AS sentiment;
```

### Azure SQL Copilot
- Natural language to SQL query generation
- Automated performance recommendations
- Integrated in Azure Portal query editor
- Available via Azure Data Studio + Copilot extension

---

## 8. Performance & Monitoring

```sql
-- Query Store — captures query performance history
-- Enabled by default on Azure SQL
ALTER DATABASE [mydb] SET QUERY_STORE = ON;
ALTER DATABASE [mydb] SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE,
    INTERVAL_LENGTH_MINUTES = 15,
    MAX_STORAGE_SIZE_MB = 1024
);

-- Find top 10 slowest queries
SELECT TOP 10
    qs.total_elapsed_time / qs.execution_count AS avg_elapsed_ms,
    qs.execution_count,
    SUBSTRING(st.text, 1, 200) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY avg_elapsed_ms DESC;

-- Automatic Tuning — Azure SQL can auto-create/drop indexes
ALTER DATABASE [mydb] SET AUTOMATIC_TUNING (
    FORCE_LAST_GOOD_PLAN = ON,
    CREATE_INDEX = ON,
    DROP_INDEX = ON
);

-- Intelligent Query Processing (IQP) features:
-- - Adaptive joins
-- - Batch mode on rowstore
-- - Memory grant feedback
-- - Parameter sensitivity plan (SQL 2022+)
```

---

## 9. Backup & Business Continuity

| Feature | Description | RPO | RTO |
|---------|-------------|-----|-----|
| Automated backups | Full/diff/log backups | ≤ 1 hour | Minutes |
| Point-in-time restore (PITR) | Restore to any second | 1 second | Minutes |
| Geo-redundant backup | Cross-region backup | ≤ 1 hour | Hours |
| Active geo-replication | Readable secondary in another region | Seconds | < 30 sec |
| Auto-failover groups | Automatic failover with single endpoint | Seconds | < 30 sec |
| Zone redundant | Availability zones (same region) | 0 | < 30 sec |

```sql
-- Check backup history
SELECT database_name, backup_start_date, backup_finish_date,
       type, backup_size / 1024 / 1024 AS size_mb
FROM msdb.dbo.backupset
WHERE database_name = 'mydb'
ORDER BY backup_start_date DESC;
```

---

## 10. Exam Key Terms Cheatsheet

| Term | Definition |
|------|------------|
| DTU | Database Transaction Unit — blended measure of CPU, memory, I/O |
| vCore | Virtual core — direct mapping to physical CPU cores |
| Hyperscale | Azure SQL tier supporting up to 100TB with rapid scale |
| Serverless | Auto-pause/resume, billed per second |
| TDE | Transparent Data Encryption — at-rest encryption |
| Always Encrypted | Client-side encryption, DB never sees plaintext |
| RLS | Row-Level Security — filter rows per user |
| DDM | Dynamic Data Masking — mask data for non-privileged users |
| Ledger | Immutable, tamper-evident tables with blockchain digest |
| Elastic Pool | Shared compute across multiple databases |
| Failover Group | Auto-failover with single read-write endpoint |
| PITR | Point-in-Time Restore — restore to any moment |
| Query Store | Query performance history and plan forcing |
| Automatic Tuning | AI-driven index and plan management |

---

## Module 4 Checklist

- [ ] Know when to use SQL Database vs Managed Instance vs SQL on VM
- [ ] Understand and configure TDE, Always Encrypted, RLS, DDM
- [ ] Know how elastic pools work and when to use them
- [ ] Understand Azure SQL Ledger use cases
- [ ] Configure read scale-out for read replicas
- [ ] Explain all BCDR options (PITR, geo-replication, failover groups)
- [ ] Know what Azure SQL Copilot and Automatic Tuning do
- [ ] Use Query Store to find and fix slow queries
