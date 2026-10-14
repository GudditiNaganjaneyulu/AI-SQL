# Subqueries and Correlated Queries

> **Why this matters:** **"Write correlated queries"** is an explicit DP-800 objective.

## Self-contained subqueries

A subquery that can run on its own.

```sql
-- Scalar subquery (returns one value)
SELECT Name, Price
FROM Sales.Products
WHERE Price > (SELECT AVG(Price) FROM Sales.Products);

-- Multi-valued subquery with IN
SELECT FirstName, LastName
FROM Sales.Customers
WHERE CustomerID IN (SELECT CustomerID FROM Sales.Orders WHERE Status = N'Shipped');
```

## Derived tables (subquery in FROM)

```sql
SELECT Category, AvgPrice
FROM (
    SELECT Category, AVG(Price) AS AvgPrice
    FROM Sales.Products
    GROUP BY Category
) AS c
WHERE AvgPrice > 100;
```

A derived table **must have an alias**. A **CTE** (Domain 1) is a more readable way to write the same thing.

## Correlated subqueries

A **correlated subquery** refers to a column from the **outer** query, so it is logically evaluated once per outer row.

```sql
-- Products priced above the average OF THEIR OWN CATEGORY
SELECT p.Name, p.Category, p.Price
FROM Sales.Products AS p
WHERE p.Price > (
    SELECT AVG(p2.Price)
    FROM Sales.Products AS p2
    WHERE p2.Category = p.Category      -- ← correlation to the outer row
);
```

```sql
-- Each customer's most recent order date
SELECT c.CustomerID, c.LastName,
       (SELECT MAX(o.OrderDate)
        FROM Sales.Orders AS o
        WHERE o.CustomerID = c.CustomerID) AS LastOrderDate
FROM Sales.Customers AS c;
```

## EXISTS and NOT EXISTS

`EXISTS` returns TRUE as soon as **one** matching row is found. It is usually correlated.

```sql
-- Customers who bought anything in the Camping category
SELECT c.CustomerID, c.LastName
FROM Sales.Customers AS c
WHERE EXISTS (
    SELECT 1
    FROM Sales.Orders AS o
    JOIN Sales.OrderLines AS ol ON ol.OrderID = o.OrderID
    JOIN Sales.Products   AS p  ON p.ProductID = ol.ProductID
    WHERE o.CustomerID = c.CustomerID
      AND p.Category = N'Camping'
);
```

> **Exam tip:** prefer `NOT EXISTS` over `NOT IN` when the subquery column can contain NULLs.

## Correlated subquery vs join vs window function

The same question can often be answered three ways. The optimizer frequently produces similar plans, but readability differs:

```sql
-- Window-function version of "above category average"
SELECT Name, Category, Price
FROM (
    SELECT Name, Category, Price,
           AVG(Price) OVER (PARTITION BY Category) AS CatAvg
    FROM Sales.Products
) AS x
WHERE Price > CatAvg;
```

## Try it

1. Products that have never been ordered (use `NOT EXISTS`).
2. For each order, show the number of lines using a correlated subquery in `SELECT`.
3. Employees who manage at least one other employee.

<details>
<summary>Answers</summary>

```sql
SELECT p.Name FROM Sales.Products AS p
WHERE NOT EXISTS (SELECT 1 FROM Sales.OrderLines AS ol WHERE ol.ProductID = p.ProductID);

SELECT o.OrderID,
       (SELECT COUNT(*) FROM Sales.OrderLines AS ol WHERE ol.OrderID = o.OrderID) AS Lines
FROM Sales.Orders AS o;

SELECT m.FullName FROM HR.Employees AS m
WHERE EXISTS (SELECT 1 FROM HR.Employees AS e WHERE e.ManagerID = m.EmployeeID);
```
</details>
