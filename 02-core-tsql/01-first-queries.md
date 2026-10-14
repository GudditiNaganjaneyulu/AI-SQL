# Your First Queries

> **Why this matters:** `SELECT` is the foundation of every report, API, and AI retrieval query you will write.

## SELECT and FROM

```sql
-- All columns (fine for exploring; avoid in production code)
SELECT *
FROM Sales.Products;

-- Only the columns you need
SELECT ProductID, Name, Price
FROM Sales.Products;
```

## Column aliases and expressions

```sql
SELECT Name                    AS ProductName,
       Price,
       Price * 1.18            AS PriceWithTax,
       CONCAT(Name, ' (', Category, ')') AS Label
FROM Sales.Products;
```

## Sorting with ORDER BY

```sql
SELECT Name, Category, Price
FROM Sales.Products
ORDER BY Category ASC, Price DESC;   -- ASC is the default
```

> Without `ORDER BY`, **row order is not guaranteed** — even if it looks sorted today.

## Limiting rows: TOP and OFFSET-FETCH

```sql
-- The 5 most expensive products
SELECT TOP (5) Name, Price
FROM Sales.Products
ORDER BY Price DESC;

-- Include ties at the boundary
SELECT TOP (5) WITH TIES Name, Price
FROM Sales.Products
ORDER BY Price DESC;

-- Paging: skip 10 rows, return the next 10 (page 2)
SELECT Name, Price
FROM Sales.Products
ORDER BY ProductID
OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY;
```

`OFFSET-FETCH` **requires** an `ORDER BY`. (PostgreSQL/MySQL use `LIMIT` — T-SQL does not.)

## Removing duplicates: DISTINCT

```sql
SELECT DISTINCT Category
FROM Sales.Products
ORDER BY Category;
```

## Comments and batches

```sql
-- single-line comment
/* multi-line
   comment */
GO   -- batch separator used by tools (SSMS, sqlcmd, VS Code); not a T-SQL statement
```

## Variables

```sql
DECLARE @MaxPrice decimal(10,2) = 100;

SELECT Name, Price
FROM Sales.Products
WHERE Price <= @MaxPrice;
```

## Try it

1. List all customers' first and last names, sorted by last name.
2. Show the 3 cheapest products with their category.
3. Show page 3 of products when each page has 5 products, ordered by name.

<details>
<summary>Answers</summary>

```sql
SELECT FirstName, LastName FROM Sales.Customers ORDER BY LastName, FirstName;

SELECT TOP (3) Name, Category, Price FROM Sales.Products ORDER BY Price ASC;

SELECT Name FROM Sales.Products ORDER BY Name
OFFSET 10 ROWS FETCH NEXT 5 ROWS ONLY;
```
</details>
