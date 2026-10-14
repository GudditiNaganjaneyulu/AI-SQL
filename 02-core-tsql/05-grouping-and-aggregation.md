# Grouping and Aggregation

> **Why this matters:** totals, averages and counts power every dashboard — and aggregations over vector-search results are a tested pattern.

## Aggregate functions

```sql
SELECT COUNT(*)             AS ProductCount,
       COUNT(Description)   AS WithDescription,  -- COUNT(col) ignores NULLs
       SUM(Price)           AS TotalPrice,
       AVG(Price)           AS AvgPrice,
       MIN(Price)           AS Cheapest,
       MAX(Price)           AS MostExpensive
FROM Sales.Products;
```

All aggregates except `COUNT(*)` **ignore NULLs**.

## GROUP BY

```sql
SELECT Category,
       COUNT(*)   AS Products,
       AVG(Price) AS AvgPrice
FROM Sales.Products
GROUP BY Category
ORDER BY Products DESC;
```

**Rule:** every column in `SELECT` must either be in `GROUP BY` or inside an aggregate.

## HAVING — filter groups

```sql
SELECT Category, COUNT(*) AS Products
FROM Sales.Products
GROUP BY Category
HAVING COUNT(*) >= 3;
```

- `WHERE` filters **rows before grouping**.
- `HAVING` filters **groups after grouping**.

## Revenue per customer (a classic)

```sql
SELECT c.CustomerID, c.LastName,
       SUM(ol.Quantity * ol.UnitPrice) AS Revenue
FROM Sales.Customers AS c
JOIN Sales.Orders     AS o  ON o.CustomerID = c.CustomerID
JOIN Sales.OrderLines AS ol ON ol.OrderID  = o.OrderID
WHERE o.Status <> N'Cancelled'
GROUP BY c.CustomerID, c.LastName
HAVING SUM(ol.Quantity * ol.UnitPrice) > 500
ORDER BY Revenue DESC;
```

## STRING_AGG — combine text from many rows

```sql
SELECT Category,
       STRING_AGG(Name, N', ') WITHIN GROUP (ORDER BY Name) AS ProductList
FROM Sales.Products
GROUP BY Category;
```

This is useful for building context text to send to a language model.

## Subtotals: ROLLUP, CUBE, GROUPING SETS

```sql
SELECT Category, YEAR(o.OrderDate) AS OrderYear, SUM(ol.Quantity) AS Qty
FROM Sales.OrderLines AS ol
JOIN Sales.Orders   AS o ON o.OrderID = ol.OrderID
JOIN Sales.Products AS p ON p.ProductID = ol.ProductID
GROUP BY ROLLUP (Category, YEAR(o.OrderDate));   -- adds subtotals and a grand total
```

## Aggregates vs window functions

Aggregates **collapse** rows into groups. **Window functions** (Domain 1 → Advanced T-SQL) compute across rows **without collapsing** them — e.g., a running total next to each order.

## Try it

1. Number of orders per status.
2. Categories whose average price is above 100.
3. For each customer, a comma-separated list of the countries… (trick: each customer has one country) — instead, list each country with a comma-separated list of customer last names.

<details>
<summary>Answers</summary>

```sql
SELECT Status, COUNT(*) AS Orders FROM Sales.Orders GROUP BY Status;

SELECT Category, AVG(Price) AS AvgPrice FROM Sales.Products
GROUP BY Category HAVING AVG(Price) > 100;

SELECT Country, STRING_AGG(LastName, N', ') AS Customers
FROM Sales.Customers GROUP BY Country;
```
</details>
