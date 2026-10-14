# Specialized Tables

> **Objective:** *Design and implement specialized tables, including in-memory, temporal, external, ledger, and graph.*

| Table type | Problem it solves | One-line memory hook |
|---|---|---|
| **Temporal** | "What did this row look like last Tuesday?" | Automatic history |
| **Ledger** | "Prove nobody tampered with this data" | Cryptographic tamper evidence |
| **Graph** | "Who is connected to whom, many hops away?" | Nodes + edges + `MATCH` |
| **In-memory (memory-optimized)** | "Extreme OLTP throughput, low latency" | Lock-free, in RAM |
| **External** | "Query files in a data lake without loading them" | Data virtualization |

---

## Temporal tables (system-versioned)

The engine keeps a **history table** of every previous version of each row, with validity periods.

```sql
CREATE TABLE Sales.PriceList
(
    ProductID int           NOT NULL CONSTRAINT PK_PriceList PRIMARY KEY,
    Price     decimal(10,2) NOT NULL,
    ValidFrom datetime2(2) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
    ValidTo   datetime2(2) GENERATED ALWAYS AS ROW END   HIDDEN NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = Sales.PriceListHistory));
```

Query the past:

```sql
SELECT * FROM Sales.PriceList FOR SYSTEM_TIME AS OF '2026-09-01T00:00:00';
SELECT * FROM Sales.PriceList FOR SYSTEM_TIME BETWEEN '2026-01-01' AND '2026-06-30';
SELECT * FROM Sales.PriceList FOR SYSTEM_TIME ALL WHERE ProductID = 7;
```

Use for: auditing changes, point-in-time reporting, recovering from accidental updates, slowly changing dimensions. Set a **retention policy** (`HISTORY_RETENTION_PERIOD`) to limit history growth.

---

## Ledger tables

Ledger tables make data **tamper-evident**: changes are hashed into a blockchain-like structure, and **database digests** can be stored externally (e.g., Azure immutable Blob Storage) to prove integrity later.

```sql
-- Updatable ledger table: updates/deletes allowed, full history kept
CREATE TABLE Sales.Payments
(
    PaymentID int           NOT NULL PRIMARY KEY,
    OrderID   int           NOT NULL,
    Amount    decimal(10,2) NOT NULL
)
WITH (SYSTEM_VERSIONING = ON, LEDGER = ON);

-- Append-only ledger table: INSERT only (logs, audit events)
CREATE TABLE Audit.Events
(
    EventID   bigint IDENTITY NOT NULL,
    EventText nvarchar(400)   NOT NULL,
    EventTime datetime2       NOT NULL DEFAULT SYSUTCDATETIME()
)
WITH (LEDGER = ON (APPEND_ONLY = ON));
```

Key facts:

- You **cannot convert** an existing table into a ledger table, or turn ledger off.
- Verify integrity with the ledger verification procedures (`sys.sp_verify_database_ledger` / `sys.sp_verify_database_ledger_from_digest_storage`) against stored digests.
- A whole database can be created as a **ledger database** (all tables ledger).
- **Temporal vs ledger:** temporal gives history; ledger gives history **plus cryptographic proof** that history wasn't altered — even by administrators.

---

## Graph tables

Model many-to-many relationships as **nodes** and **edges**, then query paths with `MATCH`.

```sql
CREATE TABLE Graph.Person (PersonID int PRIMARY KEY, Name nvarchar(100)) AS NODE;
CREATE TABLE Graph.Product (ProductID int PRIMARY KEY, Name nvarchar(100)) AS NODE;
CREATE TABLE Graph.Follows AS EDGE;
CREATE TABLE Graph.Bought (PurchaseDate date) AS EDGE;

-- Insert edges using the automatically generated $node_id columns
INSERT INTO Graph.Follows ($from_id, $to_id)
SELECT p1.$node_id, p2.$node_id
FROM Graph.Person AS p1, Graph.Person AS p2
WHERE p1.PersonID = 1 AND p2.PersonID = 2;
```

Query with `MATCH` (arrow shows edge direction):

```sql
-- Products bought by people that Asha follows
SELECT DISTINCT prod.Name
FROM Graph.Person AS asha, Graph.Follows AS f, Graph.Person AS friend,
     Graph.Bought AS b, Graph.Product AS prod
WHERE MATCH(asha-(f)->friend-(b)->prod)
  AND asha.Name = N'Asha';
```

Variable-length paths use `SHORTEST_PATH`:

```sql
SELECT p1.Name,
       STRING_AGG(p2.Name, N' -> ') WITHIN GROUP (GRAPH PATH) AS FollowPath
FROM Graph.Person AS p1,
     Graph.Follows FOR PATH AS f,
     Graph.Person  FOR PATH AS p2
WHERE MATCH(SHORTEST_PATH(p1(-(f)->p2)+))
  AND p1.Name = N'Asha';
```

Use graphs for social networks, recommendation paths, org charts, fraud rings, bill of materials.

---

## In-memory (memory-optimized) tables

Stored in memory with **lock- and latch-free** data structures. Combined with **natively compiled stored procedures**, they deliver very high OLTP throughput.

```sql
CREATE TABLE Sales.ShoppingCart
(
    CartID    int       NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 1000000),
    UserID    int       NOT NULL,
    CreatedAt datetime2 NOT NULL,
    INDEX IX_User NONCLUSTERED (UserID)
)
WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);
```

| Option | Meaning |
|---|---|
| `DURABILITY = SCHEMA_AND_DATA` | Data survives restart (default) |
| `DURABILITY = SCHEMA_ONLY` | Data is lost on restart — great for caches, session state, staging |

Requirements: on SQL Server, a **MEMORY_OPTIMIZED_DATA filegroup**; on Azure SQL Database, the **Business Critical** (or Premium) tier. Memory-optimized tables can't hold `vector` columns.

Use for: session state, shopping carts, high-rate ingestion, staging tables, replacing temp tables (`SCHEMA_ONLY`).

---

## External tables (data virtualization)

Query files in **Azure Blob Storage / Data Lake** (Parquet, CSV, Delta) with T-SQL **without copying them in**.

```sql
CREATE DATABASE SCOPED CREDENTIAL LakeCred
    WITH IDENTITY = 'Managed Identity';

CREATE EXTERNAL DATA SOURCE SalesLake
    WITH (LOCATION = 'abs://sales@contosolake.blob.core.windows.net', CREDENTIAL = LakeCred);

CREATE EXTERNAL FILE FORMAT ParquetFormat WITH (FORMAT_TYPE = PARQUET);

CREATE EXTERNAL TABLE Lake.SalesHistory
(
    SaleDate date, ProductID int, Quantity int, Amount decimal(12,2)
)
WITH (LOCATION = '/history/', DATA_SOURCE = SalesLake, FILE_FORMAT = ParquetFormat);

SELECT TOP (10) * FROM Lake.SalesHistory;

-- Ad hoc, without creating a table
SELECT TOP (10) *
FROM OPENROWSET(BULK '/history/*.parquet', DATA_SOURCE = 'SalesLake', FORMAT = 'PARQUET') AS rows;
```

Location prefixes and supported formats vary by platform (SQL Server 2022+/2025, Azure SQL Managed Instance, Azure SQL Database). Check the data virtualization docs for your target platform.

Use for: querying cold/archive data, joining lake data with operational data, exporting with **CETAS** (`CREATE EXTERNAL TABLE AS SELECT`).

---

## Scenario practice

| Requirement | Table type |
|---|---|
| Auditors must be able to prove financial records weren't altered, even by DBAs | **Ledger** (updatable) |
| Show the product price as it was on any past date | **Temporal** |
| "Friends of friends who bought this" recommendations | **Graph** |
| 500k shopping-cart writes/second; data can be rebuilt after restart | **Memory-optimized, SCHEMA_ONLY** |
| Query five years of Parquet sales files in the lake from T-SQL | **External table** |
| Append-only security event log | **Append-only ledger** |

## Knowledge check

1. What clause queries a temporal table at a past point in time?
2. Can you turn an existing table into a ledger table?
3. What keyword pattern queries graph relationships?
4. Which durability option makes an in-memory table lose data on restart?

<details>
<summary>Answers</summary>

1. `FOR SYSTEM_TIME AS OF '<datetime>'`.
2. No — ledger tables must be created as ledger.
3. `MATCH(node-(edge)->node)` (and `SHORTEST_PATH` for variable length).
4. `DURABILITY = SCHEMA_ONLY`.
</details>
