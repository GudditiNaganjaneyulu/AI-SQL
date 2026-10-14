# Joins

> **Why this matters:** normalized data lives in many tables. Joins put it back together — and RAG queries join vector results to business data.

## INNER JOIN — only matching rows

```sql
SELECT o.OrderID, o.OrderDate, c.FirstName, c.LastName
FROM Sales.Orders AS o
INNER JOIN Sales.Customers AS c
    ON c.CustomerID = o.CustomerID;
```

Use **table aliases** (`o`, `c`) and prefix every column — it avoids ambiguity errors.

## LEFT (OUTER) JOIN — keep all rows from the left

```sql
-- Every customer, with their orders if they have any
SELECT c.CustomerID, c.FirstName, o.OrderID
FROM Sales.Customers AS c
LEFT JOIN Sales.Orders AS o
    ON o.CustomerID = c.CustomerID;
```

Customers with no orders appear with `OrderID = NULL`.

### Find rows with no match (anti-join)

```sql
SELECT c.CustomerID, c.FirstName
FROM Sales.Customers AS c
LEFT JOIN Sales.Orders AS o ON o.CustomerID = c.CustomerID
WHERE o.OrderID IS NULL;
```

> **Trap:** putting a filter on the right table in `WHERE` turns a LEFT JOIN into an inner join. Put it in the `ON` clause if you want to keep unmatched left rows.

## RIGHT and FULL OUTER JOIN

- `RIGHT JOIN` keeps all rows from the right table (rarely used — swap the tables and use LEFT).
- `FULL OUTER JOIN` keeps all rows from both sides. You'll use it for **hybrid search** to merge keyword and vector results.

## Joining many tables

```sql
SELECT o.OrderID, c.LastName, p.Name, ol.Quantity, ol.UnitPrice,
       ol.Quantity * ol.UnitPrice AS LineTotal
FROM Sales.Orders     AS o
JOIN Sales.Customers  AS c  ON c.CustomerID = o.CustomerID
JOIN Sales.OrderLines AS ol ON ol.OrderID   = o.OrderID
JOIN Sales.Products   AS p  ON p.ProductID  = ol.ProductID
ORDER BY o.OrderID;
```

(`JOIN` alone means `INNER JOIN`.)

## SELF JOIN — a table joined to itself

```sql
-- Each employee with their manager's name
SELECT e.FullName AS Employee, m.FullName AS Manager
FROM HR.Employees AS e
LEFT JOIN HR.Employees AS m ON m.EmployeeID = e.ManagerID;
```

For hierarchies of unknown depth, use a **recursive CTE** (Domain 1 → Advanced T-SQL) or a **graph table** (Domain 1 → Specialized Tables).

## CROSS JOIN

Every row of A with every row of B (a Cartesian product). Useful for generating combinations, dangerous by accident.

## Try it

1. List every product with the total quantity ever ordered (include products never ordered, showing 0).
2. List customers and the number of distinct products they've bought.

<details>
<summary>Answers</summary>

```sql
SELECT p.Name, COALESCE(SUM(ol.Quantity), 0) AS TotalQty
FROM Sales.Products AS p
LEFT JOIN Sales.OrderLines AS ol ON ol.ProductID = p.ProductID
GROUP BY p.Name;

SELECT c.FirstName, c.LastName, COUNT(DISTINCT ol.ProductID) AS DistinctProducts
FROM Sales.Customers AS c
JOIN Sales.Orders AS o      ON o.CustomerID = c.CustomerID
JOIN Sales.OrderLines AS ol ON ol.OrderID = o.OrderID
GROUP BY c.FirstName, c.LastName;
```
</details>
