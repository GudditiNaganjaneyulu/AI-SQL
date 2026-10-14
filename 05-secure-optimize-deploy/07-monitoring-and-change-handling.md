# Monitoring and Change Handling

> **Objectives:** *Recommend Azure Monitor configurations, including Application Insights and Log Analytics; handle changes by using change event streaming (CES), change data capture (CDC), Change Tracking, Azure Functions with SQL trigger binding, or Azure Logic Apps.*

## Part 1 — Monitoring with Azure Monitor

| Component | What it collects | Use it for |
|---|---|---|
| **Azure Monitor metrics** | Numeric time series (CPU %, DTU/vCore %, storage, deadlocks, connections) | Dashboards and **metric alerts** (e.g., CPU > 80% for 10 min) |
| **Diagnostic settings** | Resource logs & metrics streamed out of Azure SQL | Send to Log Analytics, Storage or Event Hubs |
| **Log Analytics workspace** | Central log store queried with **KQL** | Query performance (Query Store runtime stats), errors, deadlocks, blocks, audit logs; **log alerts**; workbooks |
| **Application Insights** | Application telemetry: requests, dependencies (incl. SQL calls), failures, traces | End-to-end view from the app (or DAB) to the database |
| **Database watcher** | Detailed SQL monitoring data for Azure SQL estates | Fleet-level, in-depth monitoring dashboards |

### Recommended configuration

1. Create a **Log Analytics workspace**.
2. On each Azure SQL database: **Diagnostic settings** → send categories such as *SQLInsights*, *QueryStoreRuntimeStatistics*, *QueryStoreWaitStatistics*, *Errors*, *DatabaseWaitStatistics*, *Timeouts*, *Blocks*, *Deadlocks*, plus metrics, to the workspace.
3. Send **auditing** to the same workspace for security investigations.
4. Instrument the app/DAB with **Application Insights** (DAB supports OpenTelemetry/Application Insights via `runtime.telemetry`).
5. Create **alerts** (metric + log) routed to an **action group** (email, Teams, webhook).

Example KQL — deadlocks in the last day:

```kusto
AzureDiagnostics
| where Category == "Deadlocks"
| where TimeGenerated > ago(1d)
| project TimeGenerated, Resource, deadlock_xml_s
```

## Part 2 — Reacting to data changes

Many solutions need to know **what changed** — to sync systems, invalidate caches, or **regenerate embeddings** when text changes.

### Change Tracking (CT)

Records **which rows changed** (primary key + operation), **not the old/new values**. Lightweight, synchronous with the transaction.

```sql
ALTER DATABASE CURRENT
SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);

ALTER TABLE Sales.Products ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

-- Consumer: get changes since the last version it processed
DECLARE @last_sync bigint = 0;   -- persisted by the consumer
SELECT ct.ProductID, ct.SYS_CHANGE_OPERATION, ct.SYS_CHANGE_VERSION
FROM CHANGETABLE(CHANGES Sales.Products, @last_sync) AS ct;

SELECT CHANGE_TRACKING_CURRENT_VERSION();   -- save this as the new @last_sync
```

Requires a primary key. Join back to the table to read current values.

### Change Data Capture (CDC)

Reads the **transaction log** asynchronously and stores **full before/after values** in change tables.

```sql
EXEC sys.sp_cdc_enable_db;

EXEC sys.sp_cdc_enable_table
     @source_schema = N'Sales',
     @source_name   = N'Products',
     @role_name     = NULL;

DECLARE @from binary(10) = sys.fn_cdc_get_min_lsn('Sales_Products'),
        @to   binary(10) = sys.fn_cdc_get_max_lsn();

SELECT * FROM cdc.fn_cdc_get_all_changes_Sales_Products(@from, @to, N'all');
```

Use for: auditing history of values, ETL/data warehouse loading, downstream replication.

### Change event streaming (CES) — Preview

Streams row changes **directly from the database to Azure Event Hubs** (or Fabric eventstreams) as **CloudEvents** (JSON or Avro), with old and new values. No polling, no extra infrastructure to read the log.

High-level setup:

1. Configure the target **Event Hubs** namespace and authentication (managed identity recommended).
2. Enable event streaming on the database.
3. Create an **event stream group** (destination + credential).
4. Add tables to the stream group.

The system procedures include `sys.sp_enable_event_stream` and `sys.sp_create_event_stream_group`; check *Configure change event streaming* on Microsoft Learn for current parameters. Requirements and notes: the **full recovery model** on SQL Server; on SQL Server 2025 it needs `PREVIEW_FEATURES`.

Use for: event-driven microservices, real-time analytics, pushing changes to many consumers.

### Azure Functions with SQL trigger binding

An Azure Function runs automatically when rows change in a table. It is built on **Change Tracking** (CT must be enabled on the database and table).

```csharp
[Function("ProductChanged")]
public static void Run(
    [SqlTrigger("[Sales].[Products]", "SqlConnectionString")]
    IReadOnlyList<SqlChange<Product>> changes, FunctionContext ctx)
{
    foreach (var change in changes)
    {
        // change.Operation is Insert / Update / Delete; change.Item is the row
        // e.g., call the embedding model and write back the vector
    }
}
```

Use for: serverless reactions — regenerate an embedding, send a notification, call an API. Scales independently of the database.

### Azure Logic Apps

Low-code workflows with the **SQL Server connector** (e.g., triggers "When an item is created / modified", actions to run queries/procedures). Use when business users or integrators need a **visual workflow** connecting SQL to email, Teams, SharePoint, Dynamics, etc.

### Choosing

| Need | Choose |
|---|---|
| Know *which rows* changed; app pulls changes | **Change Tracking** |
| Full history of *old and new values*; ETL | **CDC** |
| Push every change as events to Event Hubs in near real time | **Change event streaming** |
| Run serverless code on each change (e.g., re-embed text) | **Azure Functions SQL trigger** (uses CT) |
| Visual, low-code integration with other SaaS | **Logic Apps** |
| Must happen *inside* the same transaction | **Trigger** (keep it small) |

These same options reappear as **embedding maintenance methods** in Domain 3.

## Knowledge check

1. Which feature records only the keys of changed rows, not the values?
2. What does the Azure Functions SQL trigger binding require on the table?
3. Where do you route Azure SQL resource logs to query them with KQL?
4. Which option streams changes to Event Hubs without polling?

<details>
<summary>Answers</summary>

1. Change Tracking.
2. Change Tracking enabled (database and table).
3. A Log Analytics workspace via diagnostic settings.
4. Change event streaming (CES).
</details>
