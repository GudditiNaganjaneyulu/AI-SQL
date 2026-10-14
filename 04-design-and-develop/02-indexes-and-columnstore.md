# Indexes and Columnstore

> **Objective:** *Design and implement tables, including … indexes, and columnstore indexes.*

## Why indexes exist

Without an index, finding one customer means reading **every** row (a **scan**). An index is a sorted structure (a **B-tree**) that lets the engine jump straight to the rows (a **seek**) — like a book's index.

Trade-off: every index speeds up some reads but **slows down writes** (each INSERT/UPDATE/DELETE must maintain it) and uses storage.

## Rowstore index types

### Clustered index

- **Is** the table: the data rows are stored in clustered-key order.
- **One per table.**
- Created automatically by a `PRIMARY KEY` (unless you say `NONCLUSTERED`).
- Good clustering keys are **narrow, unique, static, and ever-increasing** (e.g., `int IDENTITY`).

A table with no clustered index is a **heap**.

### Nonclustered index

A separate B-tree holding the key columns plus a pointer to the row.

```sql
-- Supports: WHERE CustomerID = @id ORDER BY OrderDate DESC
CREATE NONCLUSTERED INDEX IX_Orders_Customer_Date
    ON Sales.Orders (CustomerID, OrderDate DESC);
```

**Column order matters:** the index above helps `WHERE CustomerID = …` but not `WHERE OrderDate = …` alone.

### Covering indexes with INCLUDE

If the query needs columns not in the index, the engine performs a **key lookup** per row into the clustered index — expensive for many rows. `INCLUDE` adds columns at the leaf level only:

```sql
CREATE NONCLUSTERED INDEX IX_Orders_Customer_Date
    ON Sales.Orders (CustomerID, OrderDate DESC)
    INCLUDE (Status, ShippedDate)
    WITH (DROP_EXISTING = ON);
```

Now `SELECT OrderDate, Status, ShippedDate FROM Sales.Orders WHERE CustomerID = 5` is **covered** — no lookups.

### Filtered index

Indexes only a subset of rows:

```sql
CREATE NONCLUSTERED INDEX IX_Orders_Open
    ON Sales.Orders (OrderDate)
    WHERE Status = N'Open';
```

Small and cheap to maintain — ideal when queries target a small, well-defined subset.

### Unique index

```sql
CREATE UNIQUE NONCLUSTERED INDEX UX_Customers_Email ON Sales.Customers (Email);
```

## Columnstore indexes

Rowstore stores **rows** together. **Columnstore** stores each **column** together, in compressed **rowgroups** of up to ~1 million rows.

| Benefit | Why |
|---|---|
| Huge compression (often 10×) | Similar values in a column compress well |
| Fast analytics | Reads only the columns a query needs; **batch mode** processes many rows at once |
| **Segment elimination** | Skips rowgroups whose min/max values can't match the filter |

### Clustered columnstore index (CCI)

The whole table is stored as columnstore. Best for **data warehouse fact tables** and large analytic tables.

```sql
CREATE CLUSTERED COLUMNSTORE INDEX CCI_SalesHistory ON Sales.SalesHistory;

-- Ordered CCI (SQL Server 2022+, Azure SQL) improves segment elimination on the ordered column
CREATE CLUSTERED COLUMNSTORE INDEX CCI_SalesHistory ON Sales.SalesHistory
    ORDER (SaleDate)
    WITH (DROP_EXISTING = ON);
```

### Nonclustered columnstore index (NCCI)

Added to a normal rowstore OLTP table to enable **real-time operational analytics** (HTAP): transactions use the rowstore, reports use the columnstore.

```sql
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_Orders
    ON Sales.Orders (OrderDate, CustomerID, Status);
```

### Choosing

| Workload | Index choice |
|---|---|
| Point lookups, small ranges, OLTP | Rowstore clustered + targeted nonclustered |
| Large scans and aggregations | Clustered columnstore |
| OLTP table that also needs live analytics | Rowstore + **nonclustered columnstore** |

## Special-purpose indexes (covered elsewhere)

| Index | Chapter |
|---|---|
| **JSON index** (`CREATE JSON INDEX`) | JSON in the Database |
| **Vector index** (`CREATE VECTOR INDEX`, DiskANN) | Domain 3 → Vector Search |
| **Full-text index** | Domain 3 → Full-Text and Hybrid Search |
| **Partitioned (aligned) indexes** | Partitioning |

## Index maintenance

```sql
-- Fragmentation
SELECT OBJECT_NAME(ips.object_id) AS table_name, i.name AS index_name,
       ips.avg_fragmentation_in_percent, ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
JOIN sys.indexes AS i ON i.object_id = ips.object_id AND i.index_id = ips.index_id
WHERE ips.page_count > 1000;

ALTER INDEX IX_Orders_Customer_Date ON Sales.Orders REORGANIZE;                -- light, always online
ALTER INDEX IX_Orders_Customer_Date ON Sales.Orders REBUILD WITH (ONLINE = ON, RESUMABLE = ON);
```

Is an index used at all?

```sql
SELECT OBJECT_NAME(s.object_id) AS table_name, i.name, s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM sys.dm_db_index_usage_stats AS s
JOIN sys.indexes AS i ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE s.database_id = DB_ID();
```

High `user_updates` with near-zero reads → candidate to drop.

Missing-index suggestions: `sys.dm_db_missing_index_details` (treat as hints, not orders). On Azure SQL, **automatic tuning** can create and drop indexes for you.

## Knowledge check

1. How many clustered indexes can a table have?
2. What removes key lookups for a frequently run query?
3. An OLTP orders table needs live dashboards without a separate warehouse. What index?
4. Which columnstore feature skips rowgroups that can't match a filter?

<details>
<summary>Answers</summary>

1. One.
2. A covering index — add the needed columns with `INCLUDE`.
3. A nonclustered columnstore index.
4. Segment elimination.
</details>
