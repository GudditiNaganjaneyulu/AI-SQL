# Advanced T-SQL

> **Objective:** *Write advanced T-SQL code — CTEs, window functions, JSON functions, regular expressions, fuzzy string matching, graph MATCH queries, correlated queries, and error handling.*

JSON functions are in *JSON in the Database*, graph `MATCH` in *Specialized Tables*, and correlated queries in *Core T-SQL → Subqueries*. This chapter covers the rest and links them together.

---

## Common table expressions (CTEs)

A CTE is a **named, temporary result set** for one statement. It makes complex queries readable.

```sql
WITH CustomerRevenue AS
(
    SELECT o.CustomerID, SUM(ol.Quantity * ol.UnitPrice) AS Revenue
    FROM Sales.Orders AS o
    JOIN Sales.OrderLines AS ol ON ol.OrderID = o.OrderID
    GROUP BY o.CustomerID
),
Ranked AS
(
    SELECT CustomerID, Revenue,
           NTILE(4) OVER (ORDER BY Revenue DESC) AS Quartile
    FROM CustomerRevenue
)
SELECT c.LastName, r.Revenue, r.Quartile
FROM Ranked AS r
JOIN Sales.Customers AS c ON c.CustomerID = r.CustomerID
WHERE r.Quartile = 1;
```

A CTE is **not materialized** — it's expanded into the query each time it's referenced.

### Recursive CTEs — hierarchies

```sql
WITH OrgChart AS
(
    -- Anchor: the top of the tree
    SELECT EmployeeID, FullName, ManagerID, 0 AS Level,
           CAST(FullName AS nvarchar(4000)) AS Path
    FROM HR.Employees
    WHERE ManagerID IS NULL

    UNION ALL

    -- Recursive member: employees reporting to the previous level
    SELECT e.EmployeeID, e.FullName, e.ManagerID, oc.Level + 1,
           CAST(oc.Path + N' > ' + e.FullName AS nvarchar(4000))
    FROM HR.Employees AS e
    JOIN OrgChart AS oc ON e.ManagerID = oc.EmployeeID
)
SELECT EmployeeID, FullName, Level, Path
FROM OrgChart
ORDER BY Path
OPTION (MAXRECURSION 100);   -- default limit is 100; 0 = unlimited
```

---

## Window functions

Window functions compute values **across a set of rows related to the current row** without collapsing them.

```
function() OVER ( [PARTITION BY …] [ORDER BY …] [ROWS|RANGE frame] )
```

### Ranking

```sql
SELECT Name, Category, Price,
       ROW_NUMBER() OVER (PARTITION BY Category ORDER BY Price DESC) AS RowNum,    -- 1,2,3,4
       RANK()       OVER (PARTITION BY Category ORDER BY Price DESC) AS Rnk,       -- 1,2,2,4 (gaps)
       DENSE_RANK() OVER (PARTITION BY Category ORDER BY Price DESC) AS DenseRnk,  -- 1,2,2,3
       NTILE(4)     OVER (ORDER BY Price)                            AS Quartile
FROM Sales.Products;
```

Top-N per group:

```sql
WITH r AS (
    SELECT Name, Category, Price,
           ROW_NUMBER() OVER (PARTITION BY Category ORDER BY Price DESC) AS rn
    FROM Sales.Products
)
SELECT Name, Category, Price FROM r WHERE rn <= 2;
```

Deduplicate (keep the newest row per email):

```sql
WITH d AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Email ORDER BY CreatedAt DESC) AS rn
    FROM Sales.Customers
)
DELETE FROM d WHERE rn > 1;
```

### Aggregate windows, running totals and moving averages

```sql
SELECT OrderID, OrderDate, OrderTotal,
       SUM(OrderTotal) OVER (ORDER BY OrderDate, OrderID
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal,
       AVG(OrderTotal) OVER (ORDER BY OrderDate, OrderID
                             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)         AS MovingAvg3,
       OrderTotal * 100.0 / SUM(OrderTotal) OVER ()                            AS PctOfAll
FROM Sales.vOrderSummary;
```

> **Use `ROWS`, not the default `RANGE`, for running totals.** When you specify `ORDER BY` without a frame, the default is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`, which treats ties as one group and is slower.

### Offset functions

```sql
SELECT OrderID, CustomerID, OrderDate,
       LAG(OrderDate)  OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS PrevOrder,
       LEAD(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS NextOrder,
       DATEDIFF(DAY,
                LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate),
                OrderDate)                                                AS DaysSincePrev,
       FIRST_VALUE(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS FirstOrder
FROM Sales.Orders;
```

`LAST_VALUE` needs an explicit frame (`ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`) to return the true last value.

### The WINDOW clause (SQL Server 2022+, Azure SQL)

```sql
SELECT Name, Price,
       ROW_NUMBER() OVER w AS rn,
       AVG(Price)   OVER w AS avg_so_far
FROM Sales.Products
WINDOW w AS (PARTITION BY Category ORDER BY Price);
```

---

## Regular expressions

Available on SQL Server 2025, Azure SQL Database, Azure SQL Managed Instance (SQL Server 2025 or Always-up-to-date policy) and SQL database in Fabric.

| Function | Returns | Signature |
|---|---|---|
| `REGEXP_LIKE` | true/false (use in WHERE/CHECK) | `REGEXP_LIKE(string, pattern [, flags])` |
| `REGEXP_REPLACE` | modified string | `REGEXP_REPLACE(string, pattern [, replacement [, start [, occurrence [, flags]]]])` |
| `REGEXP_SUBSTR` | matched substring | `REGEXP_SUBSTR(string, pattern [, start [, occurrence [, flags [, group]]]])` |
| `REGEXP_INSTR` | position of match | `REGEXP_INSTR(string, pattern [, start [, occurrence [, return_option [, flags [, group]]]]])` |
| `REGEXP_COUNT` | number of matches | `REGEXP_COUNT(string, pattern [, start [, flags]])` |
| `REGEXP_MATCHES` | **table** of matches | `REGEXP_MATCHES(string, pattern [, flags])` |
| `REGEXP_SPLIT_TO_TABLE` | **table** of pieces | `REGEXP_SPLIT_TO_TABLE(string, pattern [, flags])` |

Flags: `i` case-insensitive, `c` case-sensitive (default), `m` multi-line, `s` dot matches newline.

> **`REGEXP_LIKE` requires database compatibility level 170.** The other scalar regex functions work at any level.

```sql
-- Validate data with a CHECK constraint
ALTER TABLE Sales.Customers
ADD CONSTRAINT CK_Customers_Email
CHECK (REGEXP_LIKE(Email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'));

-- Find customers with example.com emails, case-insensitive
SELECT * FROM Sales.Customers WHERE REGEXP_LIKE(Email, '@example\.com$', 'i');

-- Mask digits in free text before sending it to an AI model
SELECT REGEXP_REPLACE(N'Call me on 555-123-4567', '\d', '#');

-- Extract the domain from an email
SELECT REGEXP_SUBSTR(Email, '@(.+)$', 1, 1, 'i', 1) AS Domain FROM Sales.Customers;

-- Count words
SELECT REGEXP_COUNT(Description, '\w+') AS WordCount FROM Sales.Products;

-- Split text on any whitespace or punctuation
SELECT value, ordinal FROM REGEXP_SPLIT_TO_TABLE(N'tent, stove;  lamp', '[,;\s]+');
```

**Sargability:** `REGEXP_LIKE` can use an index seek only when the pattern starts with the `^` anchor.

---

## Fuzzy string matching (Preview)

Fuzzy functions measure how **similar** two strings are — useful for typos, deduplication, and matching names across systems. They're in **preview**; on SQL Server 2025 you must enable `PREVIEW_FEATURES`.

| Function | Returns | Meaning |
|---|---|---|
| `EDIT_DISTANCE(a, b [, max_distance])` | `int` | Number of insertions, deletions, substitutions, transpositions (Damerau-Levenshtein). **0 = identical** |
| `EDIT_DISTANCE_SIMILARITY(a, b)` | `int` 0–100 | **100 = identical** |
| `JARO_WINKLER_DISTANCE(a, b)` | `float` | **0 = identical**; favours strings that match from the start |
| `JARO_WINKLER_SIMILARITY(a, b)` | `int` 0–100 | **100 = identical** |

```sql
SELECT EDIT_DISTANCE(N'Colour', N'Color')             AS ed,     -- 1
       EDIT_DISTANCE_SIMILARITY(N'Colour', N'Color')  AS ed_sim, -- 83
       JARO_WINKLER_SIMILARITY(N'Colour', N'Color')   AS jw_sim; -- 97

-- Possible duplicate customers
SELECT a.CustomerID, b.CustomerID, a.LastName, b.LastName
FROM Sales.Customers AS a
JOIN Sales.Customers AS b
  ON a.CustomerID < b.CustomerID
 AND a.Country = b.Country                                   -- cheap filter first
WHERE JARO_WINKLER_SIMILARITY(a.LastName, b.LastName) >= 90;
```

> **Distance vs similarity:** *distance* → lower is closer. *Similarity* → higher is closer. Watch for this in exam answers.

### Fuzzy matching vs full-text vs vector search

| Technique | Matches | Example |
|---|---|---|
| `LIKE` / regex | Exact patterns | Emails ending in `.org` |
| **Fuzzy matching** | Similar **spelling** | "Jonh Smtih" ≈ "John Smith" |
| **Full-text search** | Words and word forms | "running" finds "run" |
| **Vector search** | Similar **meaning** | "warm jacket" finds "insulated parka" |

---

## Graph queries (recap)

```sql
SELECT friend.Name
FROM Graph.Person AS me, Graph.Follows AS f, Graph.Person AS friend
WHERE MATCH(me-(f)->friend) AND me.Name = N'Asha';
```

Full coverage, including `SHORTEST_PATH`, is in *Specialized Tables*.

---

## Error handling

### TRY…CATCH and THROW

```sql
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE Sales.Products SET Price = -1 WHERE ProductID = 1;   -- violates CHECK
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    SELECT ERROR_NUMBER()    AS ErrNumber,
           ERROR_SEVERITY()  AS Severity,
           ERROR_STATE()     AS State,
           ERROR_PROCEDURE() AS ProcName,
           ERROR_LINE()      AS Line,
           ERROR_MESSAGE()   AS Msg;

    THROW;          -- re-raise to the caller (keeps the original error)
END CATCH;
```

| Statement | Use |
|---|---|
| `THROW 50000, 'message', 1;` | Raise a custom error (number ≥ 50000). Always terminates the batch |
| `THROW;` (inside CATCH) | Re-throw the caught error |
| `RAISERROR` | Legacy; supports `printf`-style formatting and severity. Prefer `THROW` in new code |

### XACT_STATE

| Value | Meaning | Action |
|---|---|---|
| `1` | Active, committable transaction | Commit or roll back |
| `-1` | Uncommittable ("doomed") transaction | **Must** roll back |
| `0` | No transaction | Nothing to do |

### SET XACT_ABORT ON

Makes most runtime errors roll back the **entire** transaction automatically. Recommended at the start of procedures that use transactions.

### Retrying on deadlocks

```sql
DECLARE @retry int = 3;
WHILE @retry > 0
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        -- work...
        COMMIT;
        BREAK;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        IF ERROR_NUMBER() = 1205 AND @retry > 1      -- 1205 = deadlock victim
        BEGIN
            SET @retry -= 1;
            WAITFOR DELAY '00:00:00.200';
        END
        ELSE
            THROW;
    END CATCH
END;
```

## Knowledge check

1. What's the default recursion limit of a recursive CTE, and how do you change it?
2. `RANK` vs `DENSE_RANK` on values 10, 9, 9, 8?
3. Which regex function requires compatibility level 170?
4. Does a higher `JARO_WINKLER_DISTANCE` mean more or less similar?
5. What should you do in CATCH when `XACT_STATE()` returns -1?

<details>
<summary>Answers</summary>

1. 100; `OPTION (MAXRECURSION n)`.
2. RANK: 1, 2, 2, 4. DENSE_RANK: 1, 2, 2, 3.
3. `REGEXP_LIKE`.
4. Less similar (distance: 0 = identical).
5. Roll back — the transaction is uncommittable.
</details>
