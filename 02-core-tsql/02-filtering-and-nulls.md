# Filtering, NULLs and Logic

> **Why this matters:** filters decide which rows reach the user — and which rows an index can skip. Getting NULL logic wrong is one of the most common bugs.

## WHERE with comparison operators

```sql
SELECT Name, Price
FROM Sales.Products
WHERE Price > 50;           -- also =, <>, <, <=, >=
```

## Combining conditions: AND, OR, NOT

```sql
SELECT Name, Category, Price
FROM Sales.Products
WHERE Category = N'Camping'
  AND (Price < 50 OR Price > 300);   -- use parentheses to make intent clear
```

`AND` is evaluated before `OR`. **Always use parentheses** when mixing them.

## IN, BETWEEN, LIKE

```sql
WHERE Country IN (N'India', N'UK', N'USA')
WHERE Price BETWEEN 20 AND 100            -- inclusive of both ends
WHERE Name LIKE N'Trail%'                 -- starts with "Trail"
WHERE Email LIKE N'%@example.com'         -- ends with
WHERE Name LIKE N'_ent'                   -- _ = exactly one character
```

> **Performance tip:** `LIKE 'abc%'` can use an index. `LIKE '%abc'` (leading wildcard) cannot — it scans.

For richer pattern matching, T-SQL now has **regular expressions** (`REGEXP_LIKE`, etc.) — see *Domain 1 → Advanced T-SQL*.

## Unicode strings: the N prefix

`N'text'` is a Unicode (`nvarchar`) literal. Use it for `nvarchar` columns, otherwise non-Latin characters can be lost and implicit conversions can hurt performance.

## NULL means "unknown"

`NULL` is not zero and not an empty string. Any comparison with `NULL` returns **UNKNOWN**, which `WHERE` treats as "not true".

```sql
-- WRONG: returns no rows, ever
SELECT * FROM Sales.Orders WHERE ShippedDate = NULL;

-- RIGHT
SELECT * FROM Sales.Orders WHERE ShippedDate IS NULL;
SELECT * FROM Sales.Orders WHERE ShippedDate IS NOT NULL;
```

### Three-valued logic

| A | B | A AND B | A OR B |
|---|---|---|---|
| TRUE | UNKNOWN | UNKNOWN | TRUE |
| FALSE | UNKNOWN | FALSE | UNKNOWN |

A classic trap:

```sql
-- If any CustomerID in the subquery is NULL, NOT IN returns NO rows.
SELECT * FROM Sales.Customers
WHERE CustomerID NOT IN (SELECT CustomerID FROM Sales.Orders);

-- Safe alternative
SELECT * FROM Sales.Customers AS c
WHERE NOT EXISTS (SELECT 1 FROM Sales.Orders AS o WHERE o.CustomerID = c.CustomerID);
```

### Handling NULLs

```sql
SELECT Name,
       ISNULL(Description, N'(no description)')  AS Desc1,   -- T-SQL specific, 2 args
       COALESCE(Description, Category, N'n/a')   AS Desc2    -- ANSI, first non-NULL of many
FROM Sales.Products;
```

## Sargable predicates (preview of performance)

A predicate is **sargable** when the engine can use an index seek for it. Wrapping the column in a function usually breaks this:

```sql
-- Not sargable: function on the column
WHERE YEAR(OrderDate) = 2026

-- Sargable: range on the bare column
WHERE OrderDate >= '20260101' AND OrderDate < '20270101'
```

## Try it

1. Products in categories `Camping` or `Hiking` priced 25–150.
2. Customers whose email is missing.
3. Customers who have never placed an order (use `NOT EXISTS`).

<details>
<summary>Answers</summary>

```sql
SELECT Name, Category, Price FROM Sales.Products
WHERE Category IN (N'Camping', N'Hiking') AND Price BETWEEN 25 AND 150;

SELECT * FROM Sales.Customers WHERE Email IS NULL;

SELECT c.* FROM Sales.Customers AS c
WHERE NOT EXISTS (SELECT 1 FROM Sales.Orders AS o WHERE o.CustomerID = c.CustomerID);
```
</details>
