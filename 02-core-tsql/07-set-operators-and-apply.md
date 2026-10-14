# Set Operators and APPLY

> **Why this matters:** `UNION` combines results from different searches; `CROSS APPLY` is how you call table-valued functions such as `AI_GENERATE_CHUNKS`, `OPENJSON` and `STRING_SPLIT` once per row.

## Set operators

| Operator | Returns |
|---|---|
| `UNION` | Rows in either query, duplicates removed |
| `UNION ALL` | Rows in either query, duplicates kept (faster) |
| `INTERSECT` | Rows in both queries |
| `EXCEPT` | Rows in the first query but not the second |

Rules: same number of columns, compatible data types; column names come from the first query; `ORDER BY` goes at the very end.

```sql
-- Countries that have customers but no shipped orders
SELECT Country FROM Sales.Customers
EXCEPT
SELECT c.Country
FROM Sales.Customers AS c
JOIN Sales.Orders AS o ON o.CustomerID = c.CustomerID
WHERE o.Status = N'Shipped';
```

## CROSS APPLY and OUTER APPLY

`APPLY` evaluates a table expression **for each row** of the left side — like a correlated join.

- `CROSS APPLY` — keeps only left rows that produce at least one right row (like INNER JOIN).
- `OUTER APPLY` — keeps all left rows (like LEFT JOIN).

### Top-N per group

```sql
-- The 2 most expensive products in each category
SELECT cat.Category, p.Name, p.Price
FROM (SELECT DISTINCT Category FROM Sales.Products) AS cat
CROSS APPLY (
    SELECT TOP (2) Name, Price
    FROM Sales.Products AS p
    WHERE p.Category = cat.Category
    ORDER BY Price DESC
) AS p;
```

### Calling table-valued functions per row

```sql
-- Split a comma-separated tag string into rows
SELECT p.Name, t.value AS Tag
FROM Sales.Products AS p
CROSS APPLY STRING_SPLIT(p.Tags, N',') AS t;

-- Shred JSON per row (see Domain 1 → JSON)
SELECT p.Name, j.[key], j.[value]
FROM Sales.Products AS p
CROSS APPLY OPENJSON(p.Attributes) AS j;
```

You will use the same pattern with `AI_GENERATE_CHUNKS` in Domain 3:

```sql
SELECT d.DocID, c.chunk
FROM dbo.Documents AS d
CROSS APPLY AI_GENERATE_CHUNKS(SOURCE = d.Body, CHUNK_TYPE = FIXED, CHUNK_SIZE = 500) AS c;
```

## Try it

1. Customer IDs that appear in both `Sales.Customers` and `Sales.Orders` (use `INTERSECT`).
2. The most recent order for each customer using `OUTER APPLY` (include customers with no orders).

<details>
<summary>Answers</summary>

```sql
SELECT CustomerID FROM Sales.Customers
INTERSECT
SELECT CustomerID FROM Sales.Orders;

SELECT c.CustomerID, c.LastName, lo.OrderID, lo.OrderDate
FROM Sales.Customers AS c
OUTER APPLY (
    SELECT TOP (1) o.OrderID, o.OrderDate
    FROM Sales.Orders AS o
    WHERE o.CustomerID = c.CustomerID
    ORDER BY o.OrderDate DESC
) AS lo;
```
</details>
