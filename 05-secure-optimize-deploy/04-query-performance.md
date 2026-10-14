# Query Performance

> **Objectives:** *Recommend database configurations; evaluate query performance by using query execution plans, dynamic management views (DMVs), Query Store, and Query Performance Insight; identify and resolve query performance issues, including blocking and deadlocks.*

## A tuning method (use it every time)

1. **Find** the expensive queries — Query Store, Query Performance Insight, DMVs.
2. **Understand** why — execution plan, waits, I/O statistics.
3. **Fix** — rewrite the query, add/adjust an index, update statistics, fix parameter sensitivity, change configuration.
4. **Verify** — compare before/after in Query Store.

## Execution plans

An **execution plan** shows how the optimizer decided to run a query.

| Plan | How to get it | Contains |
|---|---|---|
| **Estimated** | SSMS *Display Estimated Plan* (Ctrl+L), `SET SHOWPLAN_XML ON` | Optimizer's guesses — query not run |
| **Actual** | SSMS *Include Actual Plan* (Ctrl+M), `SET STATISTICS XML ON` | Estimates **and** actual rows, warnings |

```sql
SET STATISTICS IO, TIME ON;    -- logical reads and CPU/elapsed time in the Messages tab
SELECT * FROM Sales.Orders WHERE CustomerID = 3;
SET STATISTICS IO, TIME OFF;
```

### What to look for

| Symptom in the plan | Usually means | Typical fix |
|---|---|---|
| **Table/Clustered Index Scan** on a big table for a selective filter | No useful index, or non-sargable predicate | Add an index; rewrite predicate |
| **Key Lookup** with high row counts | Index doesn't cover the query | `INCLUDE` the columns |
| **Estimated rows ≠ actual rows** (by 10× or more) | Stale/missing statistics, parameter sniffing, complex predicates | `UPDATE STATISTICS`; parameter-sensitivity fixes |
| **Implicit conversion** warning (`CONVERT_IMPLICIT`) | Data type mismatch, e.g., `nvarchar` parameter vs `varchar` column | Match types |
| **Sort / Hash spill to tempdb** warning | Memory grant too small | Fix estimates; memory grant feedback helps |
| **Thick arrows** | Many rows flowing | Filter earlier |

## Dynamic management views (DMVs)

DMVs expose live engine state. Must-know ones:

```sql
-- What's running right now, and who is blocking whom
SELECT r.session_id, r.status, r.command, r.wait_type, r.wait_time,
       r.blocking_session_id, r.cpu_time, r.logical_reads, t.text
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.session_id <> @@SPID;

-- Top queries by CPU since plans were cached
SELECT TOP (10)
       qs.total_worker_time / qs.execution_count AS avg_cpu,
       qs.execution_count,
       SUBSTRING(t.text, qs.statement_start_offset/2 + 1,
                 (CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(t.text)
                       ELSE qs.statement_end_offset END - qs.statement_start_offset)/2 + 1) AS stmt
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS t
ORDER BY avg_cpu DESC;

-- Where is time being spent (waits)?
SELECT TOP (10) wait_type, wait_time_ms, waiting_tasks_count
FROM sys.dm_db_wait_stats              -- Azure SQL DB; use sys.dm_os_wait_stats on SQL Server
ORDER BY wait_time_ms DESC;

-- Resource usage (Azure SQL Database, last hour in 15-second slices)
SELECT TOP (20) end_time, avg_cpu_percent, avg_data_io_percent, avg_log_write_percent
FROM sys.dm_db_resource_stats ORDER BY end_time DESC;
```

| DMV | Answers |
|---|---|
| `sys.dm_exec_requests` / `sys.dm_exec_sessions` | What's running, waiting, blocked |
| `sys.dm_exec_query_stats` + `sys.dm_exec_sql_text` + `sys.dm_exec_query_plan` | Expensive cached queries and their plans |
| `sys.dm_os_wait_stats` / `sys.dm_db_wait_stats` | Top waits |
| `sys.dm_tran_locks` | Locks held and requested |
| `sys.dm_db_index_usage_stats` | Are indexes used? |
| `sys.dm_db_missing_index_details` (+ groups/stats) | Suggested indexes |
| `sys.dm_db_resource_stats` | Azure SQL DB resource consumption |
| `sys.dm_db_vector_indexes` | Vector index health and maintenance |

## Query Store

The **flight recorder** for queries: it persists query text, plans and runtime statistics **across restarts**. On by default in Azure SQL Database and new SQL Server 2022+ databases.

```sql
ALTER DATABASE CURRENT SET QUERY_STORE = ON (OPERATION_MODE = READ_WRITE);

-- Top queries by total duration in Query Store
SELECT TOP (10) q.query_id, qt.query_sql_text,
       SUM(rs.count_executions)                       AS executions,
       SUM(rs.avg_duration * rs.count_executions)     AS total_duration
FROM sys.query_store_query          AS q
JOIN sys.query_store_query_text     AS qt ON qt.query_text_id = q.query_text_id
JOIN sys.query_store_plan           AS p  ON p.query_id = q.query_id
JOIN sys.query_store_runtime_stats  AS rs ON rs.plan_id = p.plan_id
GROUP BY q.query_id, qt.query_sql_text
ORDER BY total_duration DESC;
```

Built-in reports (SSMS): **Regressed Queries**, **Top Resource Consuming Queries**, **Queries With Forced Plans**, **Queries With High Variation**.

### Fixing a plan regression

```sql
-- Force the known-good plan
EXEC sys.sp_query_store_force_plan @query_id = 42, @plan_id = 7;

-- Or apply a hint without changing application code (Query Store hints)
EXEC sys.sp_query_store_set_hints @query_id = 42, @query_hints = N'OPTION (RECOMPILE)';
```

### Automatic tuning

Azure SQL can **automatically force the last good plan** when a regression is detected (`FORCE_LAST_GOOD_PLAN`, on by default in Azure SQL Database), and optionally **create/drop indexes**.

```sql
ALTER DATABASE CURRENT SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);
```

## Query Performance Insight

A **portal experience for Azure SQL Database** built on Query Store. It shows top queries by CPU, duration, or execution count over time, with their text and history — useful for non-DBAs to spot the worst offenders quickly.

## Blocking

**Blocking** happens when one session holds a lock another needs. It's normal briefly; it's a problem when long.

Find the head blocker:

```sql
SELECT r.session_id, r.blocking_session_id, r.wait_type, r.wait_time, t.text
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.blocking_session_id <> 0;
```

Fixes:

- Keep transactions **short**; commit sooner; no user/HTTP waits inside transactions.
- Add indexes so updates touch fewer rows (less locking).
- Use **RCSI/SNAPSHOT** so readers don't block writers.
- Avoid lock escalation by batching large modifications (`UPDATE TOP (5000) … ` in a loop).

## Deadlocks

Two (or more) sessions each wait for a lock the other holds. The engine detects it and kills one: **error 1205** ("chosen as the deadlock victim").

Capture deadlock graphs:

- SQL Server / MI: the built-in **`system_health`** Extended Events session records `xml_deadlock_report`.
- Azure SQL Database: query deadlock events (Extended Events / `sys.fn_xe_telemetry_blob_target_read_file` or Azure Monitor/Log Analytics with diagnostic settings).

Fixes:

- Access objects in the **same order** in all code paths.
- Keep transactions short; add indexes that reduce scanned rows.
- Use row-versioning isolation.
- Add **retry logic** for error 1205 (see *Domain 1 → Advanced T-SQL*).

## Recommending database configurations

| Setting | Recommendation |
|---|---|
| **Compatibility level** | Latest (e.g., 170) to unlock new optimizer features and functions; test first |
| **Query Store** | ON, `READ_WRITE` |
| **Automatic tuning** | `FORCE_LAST_GOOD_PLAN = ON` |
| **RCSI** | ON for mixed read/write workloads |
| **Accelerated Database Recovery** | ON (always on in Azure SQL) — fast rollback, enables optimized locking |
| **MAXDOP** | Database scoped configuration; Azure SQL defaults to 8 for new databases |
| **Statistics** | `AUTO_CREATE_STATISTICS` and `AUTO_UPDATE_STATISTICS` ON |
| **Service tier/size** | Right-size from `sys.dm_db_resource_stats`; use serverless for intermittent workloads |
| **Parameter Sensitive Plan optimization** | Enabled at compatibility level 160+ |

```sql
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 8;
SELECT * FROM sys.database_scoped_configurations;
```

## Knowledge check

1. What's the difference between an estimated and an actual plan?
2. Where would you find a query's plan history across server restarts?
3. What error number indicates a deadlock victim?
4. Which Azure portal feature shows top queries for Azure SQL Database using Query Store data?
5. A plan regressed after a statistics update. Fastest fix without code changes?

<details>
<summary>Answers</summary>

1. Estimated isn't executed and has only estimates; actual includes runtime row counts and warnings.
2. Query Store.
3. 1205.
4. Query Performance Insight.
5. Force the previous plan in Query Store (or rely on automatic tuning `FORCE_LAST_GOOD_PLAN`).
</details>
