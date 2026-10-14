# Partitioning

> **Objective:** *Design and implement partitioning for tables and indexes.*

## What partitioning is (and isn't)

**Partitioning** splits one large table (or index) into pieces by a column value — usually a date — while it still looks like **one table** to queries.

Benefits:

- **Data lifecycle management:** load or remove a whole month instantly with `SWITCH` / `TRUNCATE … WITH (PARTITIONS …)`.
- **Partition elimination:** queries filtering on the partition column read only relevant partitions.
- **Maintenance per partition:** rebuild just the active partition's indexes.

Not a magic performance switch: a query that doesn't filter on the partitioning column may scan **every** partition. Indexes are still your main tuning tool.

> Partitioning is **horizontal** (rows split). **Sharding** splits data across **separate databases** — a different technique.

## The three building blocks

```
Partition FUNCTION  → defines boundary values   (how to split)
Partition SCHEME    → maps partitions to filegroups (where to store)
Table / index       → created ON the scheme with a partitioning column
```

### 1. Partition function

```sql
CREATE PARTITION FUNCTION pfOrderDate (date)
AS RANGE RIGHT FOR VALUES ('20250101', '20260101', '20270101');
```

`RANGE RIGHT` puts each boundary value in the partition to its **right**. With the values above:

| Partition | Rows |
|---|---|
| 1 | `< 2025-01-01` |
| 2 | `>= 2025-01-01` and `< 2026-01-01` |
| 3 | `>= 2026-01-01` and `< 2027-01-01` |
| 4 | `>= 2027-01-01` |

`n` boundaries → `n + 1` partitions. **RANGE RIGHT is the usual choice for dates.**

### 2. Partition scheme

```sql
CREATE PARTITION SCHEME psOrderDate
AS PARTITION pfOrderDate ALL TO ([PRIMARY]);
```

(On Azure SQL Database only the `PRIMARY` filegroup exists, so `ALL TO ([PRIMARY])` is the standard form.)

### 3. Partitioned table

```sql
CREATE TABLE Sales.OrderHistory
(
    OrderID   int           NOT NULL,
    OrderDate date          NOT NULL,
    Amount    decimal(12,2) NOT NULL,
    CONSTRAINT PK_OrderHistory PRIMARY KEY CLUSTERED (OrderDate, OrderID)
)
ON psOrderDate (OrderDate);
```

The partitioning column must be part of every **unique** index key (including the PK) for the indexes to be **aligned**.

## Inspecting partitions

```sql
SELECT $PARTITION.pfOrderDate('20260515') AS partition_number;   -- which partition?

SELECT p.partition_number, p.rows
FROM sys.partitions AS p
WHERE p.object_id = OBJECT_ID('Sales.OrderHistory') AND p.index_id IN (0, 1);
```

## Sliding window: add new, remove old

```sql
-- Add a boundary for 2028 (split the last partition)
ALTER PARTITION SCHEME psOrderDate NEXT USED [PRIMARY];
ALTER PARTITION FUNCTION pfOrderDate() SPLIT RANGE ('20280101');

-- Remove the oldest data instantly
TRUNCATE TABLE Sales.OrderHistory WITH (PARTITIONS (1));

-- Merge the now-empty boundary
ALTER PARTITION FUNCTION pfOrderDate() MERGE RANGE ('20250101');
```

### SWITCH — move a partition in or out as a metadata operation

```sql
-- Staging table must have identical structure, indexes and a CHECK constraint matching the partition range
ALTER TABLE Sales.OrderHistory SWITCH PARTITION 2 TO Sales.OrderHistoryArchive;
```

## Partitioned indexes

```sql
CREATE NONCLUSTERED INDEX IX_OrderHistory_Amount
    ON Sales.OrderHistory (Amount)
    ON psOrderDate (OrderDate);      -- aligned index

ALTER INDEX IX_OrderHistory_Amount ON Sales.OrderHistory REBUILD PARTITION = 3;
```

Columnstore indexes combine well with partitioning for large fact tables.

> Vector indexes **can't** be partitioned (current limitation).

## Knowledge check

1. With `RANGE RIGHT FOR VALUES ('20260101')`, which partition holds `2026-01-01`?
2. What is the fastest way to delete all 2024 rows from a date-partitioned table?
3. Why must the partition column be in the primary key?

<details>
<summary>Answers</summary>

1. The partition to the right (the second partition).
2. `TRUNCATE TABLE … WITH (PARTITIONS (n))` or `SWITCH` the partition out.
3. Unique indexes must include the partitioning column to be aligned with the table.
</details>
