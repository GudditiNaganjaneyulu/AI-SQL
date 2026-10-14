# Lab 4 — Performance

**Goal:** read execution plans, fix a slow query with an index, use Query Store, and reproduce blocking and a deadlock.

## Setup — make a bigger table

The base tables are tiny. Create a larger order history to see real plan differences:

```sql
DROP TABLE IF EXISTS Sales.OrderHistory;
CREATE TABLE Sales.OrderHistory
(
    OrderID    int IDENTITY PRIMARY KEY,
    CustomerID int NOT NULL,
    OrderDate  date NOT NULL,
    Status     nvarchar(20) NOT NULL,
    Amount     decimal(12,2) NOT NULL
);

INSERT INTO Sales.OrderHistory (CustomerID, OrderDate, Status, Amount)
SELECT (s.value % 5000) + 1,
       DATEADD(DAY, -(s.value % 1500), CAST('20261001' AS date)),
       CASE s.value % 4 WHEN 0 THEN N'New' WHEN 1 THEN N'Paid' WHEN 2 THEN N'Shipped' ELSE N'Cancelled' END,
       (s.value % 500) + 9.99
FROM GENERATE_SERIES(1, 500000) AS s;
```

## Part A — Plans and I/O

1. Turn on statistics and the **actual execution plan** (Ctrl+M in SSMS; in VS Code use the *Include Actual Plan*/*Estimated Plan* options).
2. Run:

```sql
SET STATISTICS IO, TIME ON;
SELECT OrderID, OrderDate, Amount
FROM Sales.OrderHistory
WHERE CustomerID = 42
ORDER BY OrderDate DESC;
```

3. Record **logical reads** and the plan operator (expect a **Clustered Index Scan**).
4. Create a covering index and re-run:

```sql
CREATE INDEX IX_OrderHistory_Customer_Date
    ON Sales.OrderHistory (CustomerID, OrderDate DESC)
    INCLUDE (Amount);
```

5. Compare logical reads and the new operator (**Index Seek**, no sort, no lookup).

## Part B — Non-sargable predicate

6. Compare these two queries' plans and reads:

```sql
SELECT COUNT(*) FROM Sales.OrderHistory WHERE YEAR(OrderDate) = 2025;

SELECT COUNT(*) FROM Sales.OrderHistory WHERE OrderDate >= '20250101' AND OrderDate < '20260101';
```

7. Add an index on `OrderDate` and compare again. Which query benefits? Why?

<details>
<summary>Answer</summary>

Only the second (range) query can seek; `YEAR(OrderDate)` wraps the column in a function, making the predicate non-sargable.
</details>

## Part C — Query Store

8. Make sure Query Store is on: `ALTER DATABASE CURRENT SET QUERY_STORE = ON;`
9. Run the Part A query 20 times (`GO 20` in SSMS/sqlcmd).
10. Find it in Query Store:

```sql
SELECT TOP (5) q.query_id, p.plan_id, qt.query_sql_text,
       rs.count_executions, rs.avg_duration, rs.avg_logical_io_reads
FROM sys.query_store_query AS q
JOIN sys.query_store_query_text AS qt ON qt.query_text_id = q.query_text_id
JOIN sys.query_store_plan AS p ON p.query_id = q.query_id
JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = p.plan_id
WHERE qt.query_sql_text LIKE N'%OrderHistory%CustomerID = 42%'
ORDER BY rs.last_execution_time DESC;
```

11. (Azure SQL DB) Open **Query Performance Insight** in the portal and locate the same query.

## Part D — Blocking

Open **two** query windows (sessions).

**Session 1:**

```sql
BEGIN TRAN;
UPDATE Sales.Products SET Price = Price + 1 WHERE ProductID = 1;
-- do NOT commit yet
```

**Session 2:**

```sql
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT Price FROM Sales.Products WITH (READCOMMITTEDLOCK) WHERE ProductID = 1;  -- waits (forces locking read)
```

**Session 3 (or 2 after cancelling):** find the blocker:

```sql
SELECT session_id, blocking_session_id, wait_type, wait_time
FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;
```

Now in Session 2 run the same SELECT **without** the hint. On Azure SQL Database (RCSI on by default) it returns immediately with the last committed price — **readers don't block writers** under row versioning.

Finish with `ROLLBACK;` in Session 1.

## Part E — Deadlock

**Session 1:**

```sql
BEGIN TRAN;
UPDATE Sales.Products  SET Price = Price + 1 WHERE ProductID = 1;
WAITFOR DELAY '00:00:05';
UPDATE Sales.Customers SET Country = Country WHERE CustomerID = 1;
COMMIT;
```

**Session 2** (start within 5 seconds):

```sql
BEGIN TRAN;
UPDATE Sales.Customers SET Country = Country WHERE CustomerID = 1;
WAITFOR DELAY '00:00:05';
UPDATE Sales.Products  SET Price = Price + 1 WHERE ProductID = 1;
COMMIT;
```

One session fails with **error 1205**. Fix: make both transactions update tables **in the same order**, and add retry logic for 1205.

## Clean up

```sql
DROP TABLE IF EXISTS Sales.OrderHistory;
```
