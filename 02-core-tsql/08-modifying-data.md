# Modifying Data

> **Why this matters:** applications insert and update data constantly; embedding pipelines update vector columns; CI/CD scripts load reference data with `MERGE`.

> **Note:** `Sales.ProductArchive`, `Sales.Promotions`, `Staging.Products` and `Staging.ImportRows` below are illustrative and are **not** created by Lab 0. The "Try it" exercises use only lab tables.

## INSERT

```sql
-- One row (list the columns explicitly — always)
INSERT INTO Sales.Customers (FirstName, LastName, Email, Country)
VALUES (N'Chen', N'Li', N'chen@example.com', N'Singapore');

-- Many rows
INSERT INTO Sales.Customers (FirstName, LastName, Email, Country)
VALUES (N'Ana', N'Silva', N'ana@example.com', N'Brazil'),
       (N'Omar', N'Haddad', N'omar@example.com', N'UAE');

-- From a query
INSERT INTO Sales.ProductArchive (ProductID, Name, Price)
SELECT ProductID, Name, Price
FROM Sales.Products
WHERE Discontinued = 1;
```

### Getting generated keys

```sql
INSERT INTO Sales.Orders (CustomerID, OrderDate, Status)
OUTPUT inserted.OrderID              -- returns the new identity value(s)
VALUES (1, SYSDATETIME(), N'New');

SELECT SCOPE_IDENTITY();             -- last identity in this scope (single-row inserts)
```

`OUTPUT` works for multi-row inserts and with `UPDATE`, `DELETE` and `MERGE` (`inserted.*` / `deleted.*`).

## UPDATE

```sql
UPDATE Sales.Products
SET Price = Price * 1.05
WHERE Category = N'Camping';

-- Update using a join
UPDATE p
SET p.Price = p.Price * 0.9
FROM Sales.Products AS p
JOIN Sales.Promotions AS pr ON pr.ProductID = p.ProductID
WHERE pr.IsActive = 1;
```

> **Safety habit:** write the `SELECT` with the same `WHERE` first, check the rows, then change it to `UPDATE`. Better still, wrap it in a transaction (below).

## DELETE and TRUNCATE

```sql
DELETE FROM Sales.Orders WHERE Status = N'Cancelled' AND OrderDate < '20250101';

TRUNCATE TABLE Staging.ImportRows;   -- removes ALL rows, minimally logged, resets identity
```

`TRUNCATE` can't be used on tables referenced by a foreign key, and (relevant later) **can't be used on tables with a vector index**.

## MERGE — insert, update and delete in one statement

```sql
MERGE Sales.Products AS target
USING Staging.Products AS source
    ON target.ProductID = source.ProductID
WHEN MATCHED AND target.Price <> source.Price THEN
    UPDATE SET target.Price = source.Price
WHEN NOT MATCHED BY TARGET THEN
    INSERT (ProductID, Name, Category, Price)
    VALUES (source.ProductID, source.Name, source.Category, source.Price)
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
OUTPUT $action, inserted.ProductID, deleted.ProductID;
```

`MERGE` is commonly used to load **reference/static data** in post-deployment scripts (Domain 2 → CI/CD).

## Transactions — your safety net

```sql
BEGIN TRANSACTION;

UPDATE Sales.Products SET Price = Price * 1.10 WHERE Category = N'Hiking';

-- Inspect the result...
SELECT Name, Price FROM Sales.Products WHERE Category = N'Hiking';

-- ...then choose one:
ROLLBACK TRANSACTION;   -- undo
-- COMMIT TRANSACTION;  -- keep
```

Error-safe patterns (`TRY...CATCH`, `XACT_ABORT`) are in *Domain 1 → Advanced T-SQL*.

## Identity vs SEQUENCE (preview)

- `IDENTITY(1,1)` — a column property that auto-numbers rows in one table.
- `SEQUENCE` — a separate object that generates numbers usable across tables. Covered in *Domain 1 → Tables, Data Types and Constraints*.

## Try it

1. Insert a new product and return its new `ProductID` using `OUTPUT`.
2. In a transaction, raise all prices by 10%, check them, then roll back.
3. Write a `MERGE` that upserts one customer by email.

<details>
<summary>Answers</summary>

```sql
INSERT INTO Sales.Products (Name, Category, Price)
OUTPUT inserted.ProductID
VALUES (N'Ultralight Pillow', N'Camping', 24.99);

BEGIN TRAN;
UPDATE Sales.Products SET Price = Price * 1.10;
SELECT TOP (5) Name, Price FROM Sales.Products;
ROLLBACK;

MERGE Sales.Customers AS t
USING (SELECT N'zoe@example.com' AS Email, N'Zoe' AS FirstName, N'Park' AS LastName, N'Korea' AS Country) AS s
    ON t.Email = s.Email
WHEN MATCHED THEN UPDATE SET t.FirstName = s.FirstName, t.LastName = s.LastName, t.Country = s.Country
WHEN NOT MATCHED THEN INSERT (FirstName, LastName, Email, Country)
                      VALUES (s.FirstName, s.LastName, s.Email, s.Country);
```
</details>
