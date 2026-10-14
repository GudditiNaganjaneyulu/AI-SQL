# Lab 1 — Core Queries

**Goal:** become fluent with SELECT, filtering, joins, grouping, subqueries and data modification.

**You will learn:** to translate business questions into T-SQL — the skill every other lab depends on.

## Part A — Warm-up (single table)

1. List all products in the `Camping` category, cheapest first.
2. Show products priced between 50 and 200 that are **not** discontinued.
3. Find customers whose email is missing.
4. Show the 3 most expensive products, including ties.
5. Display each product name with a price band: `Budget` (< 75), `Standard` (75–250), `Premium` (> 250).

<details>
<summary>Solutions A</summary>

```sql
SELECT Name, Price FROM Sales.Products WHERE Category = N'Camping' ORDER BY Price;

SELECT Name, Price FROM Sales.Products
WHERE Price BETWEEN 50 AND 200 AND Discontinued = 0;

SELECT FirstName, LastName FROM Sales.Customers WHERE Email IS NULL;

SELECT TOP (3) WITH TIES Name, Price FROM Sales.Products ORDER BY Price DESC;

SELECT Name, Price,
       CASE WHEN Price < 75 THEN N'Budget'
            WHEN Price <= 250 THEN N'Standard'
            ELSE N'Premium' END AS Band
FROM Sales.Products;
```
</details>

## Part B — Joins and grouping

6. List every order with the customer's full name and order status.
7. Show revenue (Quantity × UnitPrice) per order, highest first. Exclude cancelled orders.
8. Revenue per **category**.
9. Customers with **more than 3** orders.
10. Every product and how many units were sold — include products never sold (show 0).

<details>
<summary>Solutions B</summary>

```sql
SELECT o.OrderID, CONCAT(c.FirstName, N' ', c.LastName) AS Customer, o.Status
FROM Sales.Orders AS o JOIN Sales.Customers AS c ON c.CustomerID = o.CustomerID;

SELECT o.OrderID, SUM(ol.Quantity * ol.UnitPrice) AS Revenue
FROM Sales.Orders AS o JOIN Sales.OrderLines AS ol ON ol.OrderID = o.OrderID
WHERE o.Status <> N'Cancelled'
GROUP BY o.OrderID
ORDER BY Revenue DESC;

SELECT p.Category, SUM(ol.Quantity * ol.UnitPrice) AS Revenue
FROM Sales.OrderLines AS ol JOIN Sales.Products AS p ON p.ProductID = ol.ProductID
GROUP BY p.Category ORDER BY Revenue DESC;

SELECT c.CustomerID, c.LastName, COUNT(*) AS Orders
FROM Sales.Customers AS c JOIN Sales.Orders AS o ON o.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.LastName
HAVING COUNT(*) > 3;

SELECT p.Name, COALESCE(SUM(ol.Quantity), 0) AS UnitsSold
FROM Sales.Products AS p LEFT JOIN Sales.OrderLines AS ol ON ol.ProductID = p.ProductID
GROUP BY p.Name ORDER BY UnitsSold DESC;
```
</details>

## Part C — Subqueries and APPLY

11. Products priced above the average price **of their own category** (correlated subquery).
12. Customers who have **never** ordered a `Clothing` product (`NOT EXISTS`).
13. Each customer's most recent order (`OUTER APPLY`).
14. Split the `Tags` column into one row per tag.

<details>
<summary>Solutions C</summary>

```sql
SELECT p.Name, p.Category, p.Price
FROM Sales.Products AS p
WHERE p.Price > (SELECT AVG(p2.Price) FROM Sales.Products AS p2 WHERE p2.Category = p.Category);

SELECT c.CustomerID, c.LastName
FROM Sales.Customers AS c
WHERE NOT EXISTS (
    SELECT 1 FROM Sales.Orders AS o
    JOIN Sales.OrderLines AS ol ON ol.OrderID = o.OrderID
    JOIN Sales.Products AS p ON p.ProductID = ol.ProductID
    WHERE o.CustomerID = c.CustomerID AND p.Category = N'Clothing');

SELECT c.LastName, lo.OrderID, lo.OrderDate
FROM Sales.Customers AS c
OUTER APPLY (SELECT TOP (1) OrderID, OrderDate FROM Sales.Orders AS o
             WHERE o.CustomerID = c.CustomerID ORDER BY OrderDate DESC) AS lo;

SELECT p.Name, TRIM(t.value) AS Tag
FROM Sales.Products AS p CROSS APPLY STRING_SPLIT(p.Tags, N',') AS t;
```
</details>

## Part D — Changing data safely

15. In a transaction: insert a new customer, return the new `CustomerID` with `OUTPUT`, then roll back.
16. In a transaction: raise all `Lighting` prices by 10%, show them, roll back.
17. Write a `MERGE` that upserts a product by `Sku` (`'LMP-HEAD'` with new price 49.00, or insert if missing).

<details>
<summary>Solutions D</summary>

```sql
BEGIN TRAN;
INSERT INTO Sales.Customers (FirstName, LastName, Email, Country)
OUTPUT inserted.CustomerID
VALUES (N'Test', N'User', N'test@example.com', N'India');
ROLLBACK;

BEGIN TRAN;
UPDATE Sales.Products SET Price = Price * 1.10 WHERE Category = N'Lighting';
SELECT Name, Price FROM Sales.Products WHERE Category = N'Lighting';
ROLLBACK;

MERGE Sales.Products AS t
USING (SELECT 'LMP-HEAD' AS Sku, N'Beacon Headlamp' AS Name, N'Lighting' AS Category, 49.00 AS Price) AS s
   ON t.Sku = s.Sku
WHEN MATCHED THEN UPDATE SET t.Price = s.Price
WHEN NOT MATCHED THEN INSERT (Sku, Name, Category, Price) VALUES (s.Sku, s.Name, s.Category, s.Price);
```
</details>

## Reflection

- Which query needed `LEFT JOIN` instead of `JOIN`, and why?
- Why does Part C #12 use `NOT EXISTS` instead of `NOT IN`?
