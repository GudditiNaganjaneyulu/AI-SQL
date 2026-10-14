# Views, Functions, Procedures and Triggers

> **Objective:** *Implement programmability objects — create views, scalar functions, table-valued functions, stored procedures, and triggers.*

## Views

A **view** is a saved `SELECT` you can query like a table.

```sql
CREATE OR ALTER VIEW Sales.vOrderSummary
AS
SELECT o.OrderID, o.OrderDate, c.CustomerID, c.LastName,
       SUM(ol.Quantity * ol.UnitPrice) AS OrderTotal
FROM Sales.Orders     AS o
JOIN Sales.Customers  AS c  ON c.CustomerID = o.CustomerID
JOIN Sales.OrderLines AS ol ON ol.OrderID   = o.OrderID
GROUP BY o.OrderID, o.OrderDate, c.CustomerID, c.LastName;
GO

SELECT TOP (10) * FROM Sales.vOrderSummary ORDER BY OrderTotal DESC;
```

Uses: simplify complex joins, expose a **stable API** to apps (including Data API builder), **restrict columns** for security.

| Option | Effect |
|---|---|
| `WITH SCHEMABINDING` | Underlying tables can't be changed in a way that breaks the view; required for indexed views |
| `WITH CHECK OPTION` | Inserts/updates through the view must satisfy its `WHERE` |
| **Indexed view** | A unique clustered index **materializes** the view — fast reads, slower writes |

```sql
CREATE VIEW Sales.vCategoryTotals WITH SCHEMABINDING AS
SELECT p.Category, COUNT_BIG(*) AS Lines, SUM(ol.Quantity) AS Qty
FROM Sales.OrderLines AS ol JOIN Sales.Products AS p ON p.ProductID = ol.ProductID
GROUP BY p.Category;
GO
CREATE UNIQUE CLUSTERED INDEX UCX_vCategoryTotals ON Sales.vCategoryTotals (Category);
```

> `VECTOR_SEARCH` can't be used inside a view body.

## Functions

### Scalar functions — return one value

```sql
CREATE OR ALTER FUNCTION Sales.fnPriceWithTax (@price decimal(10,2), @rate decimal(4,3))
RETURNS decimal(10,2)
AS
BEGIN
    RETURN ROUND(@price * (1 + @rate), 2);
END;
GO
SELECT Name, Sales.fnPriceWithTax(Price, 0.18) FROM Sales.Products;
```

Historically, scalar UDFs ran row-by-row and blocked parallelism. **Scalar UDF inlining** (SQL Server 2019+, Azure SQL) rewrites eligible functions into the query automatically. Keep them simple to stay inlineable.

### Inline table-valued functions (iTVF) — a parameterized view

```sql
CREATE OR ALTER FUNCTION Sales.fnOrdersForCustomer (@CustomerID int)
RETURNS TABLE
AS
RETURN
(
    SELECT OrderID, OrderDate, Status
    FROM Sales.Orders
    WHERE CustomerID = @CustomerID
);
GO
SELECT * FROM Sales.fnOrdersForCustomer(3);
```

**Best-performing function type** — the optimizer expands it like a view. Also used as the **predicate function for Row-Level Security**.

### Multi-statement TVFs

```sql
CREATE OR ALTER FUNCTION Sales.fnTopCustomers (@n int)
RETURNS @result TABLE (CustomerID int, Revenue decimal(12,2))
AS
BEGIN
    INSERT @result
    SELECT TOP (@n) o.CustomerID, SUM(ol.Quantity * ol.UnitPrice)
    FROM Sales.Orders AS o JOIN Sales.OrderLines AS ol ON ol.OrderID = o.OrderID
    GROUP BY o.CustomerID ORDER BY 2 DESC;
    RETURN;
END;
```

Flexible but harder for the optimizer to estimate — **prefer inline TVFs** when possible.

## Stored procedures

```sql
CREATE OR ALTER PROCEDURE Sales.usp_PlaceOrder
    @CustomerID int,
    @ProductID  int,
    @Quantity   int,
    @OrderID    int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;     -- suppress "n rows affected" messages
    SET XACT_ABORT ON;  -- any runtime error rolls back the whole transaction

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Sales.Orders (CustomerID, OrderDate, Status)
        VALUES (@CustomerID, SYSUTCDATETIME(), N'New');

        SET @OrderID = SCOPE_IDENTITY();

        INSERT INTO Sales.OrderLines (OrderID, LineNumber, ProductID, Quantity, UnitPrice)
        SELECT @OrderID, 1, ProductID, @Quantity, Price
        FROM Sales.Products WHERE ProductID = @ProductID;

        IF @@ROWCOUNT = 0
            THROW 50001, 'Product not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;   -- re-raise the original error to the caller
    END CATCH
END;
GO

DECLARE @newId int;
EXEC Sales.usp_PlaceOrder @CustomerID = 1, @ProductID = 2, @Quantity = 1, @OrderID = @newId OUTPUT;
SELECT @newId AS NewOrderID;
```

Why procedures?

- **Security:** grant `EXECUTE` on the procedure without granting table access (ownership chaining).
- **Plan reuse** and fewer round trips.
- **A clean API** — Data API builder can expose procedures as REST/GraphQL endpoints.
- **Prevents SQL injection** when parameters are used (never concatenate user input into dynamic SQL; use `sp_executesql` with parameters).

> **Parameter sniffing:** a plan compiled for one parameter value may be poor for another. Mitigations: `OPTION (RECOMPILE)`, `OPTIMIZE FOR`, Query Store hints, or the Parameter Sensitive Plan optimization (SQL Server 2022+/Azure SQL).

## Triggers

A **DML trigger** runs automatically after (or instead of) INSERT/UPDATE/DELETE. Inside it, the virtual tables `inserted` and `deleted` hold the affected rows.

```sql
CREATE OR ALTER TRIGGER Sales.trg_Products_PriceAudit
ON Sales.Products
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(Price) RETURN;

    INSERT INTO Sales.PriceAudit (ProductID, OldPrice, NewPrice, ChangedAt)
    SELECT d.ProductID, d.Price, i.Price, SYSUTCDATETIME()
    FROM inserted AS i
    JOIN deleted  AS d ON d.ProductID = i.ProductID
    WHERE i.Price <> d.Price;
END;
```

**Always write triggers set-based** — one statement can affect many rows; never assume one row.

| Trigger type | Fires on | Example use |
|---|---|---|
| `AFTER` (DML) | After the change | Auditing, maintaining summary tables, flagging rows for re-embedding |
| `INSTEAD OF` (DML) | Instead of the change | Making complex views updatable |
| **DDL** trigger | `CREATE/ALTER/DROP` | Block or log schema changes |
| **Logon** trigger | Login | Restrict connections |

> **AI scenario:** a trigger can mark a row as "needs new embedding" when its text changes. Calling an external model **inside** the trigger is usually a bad idea (slow, holds locks, fails the user's transaction if the endpoint is down). See *Domain 3 → Keeping Embeddings Up to Date*.

## Choosing the right object

| Need | Object |
|---|---|
| Reusable query shape, no parameters | View |
| Reusable query shape **with parameters** | Inline TVF |
| Reusable calculation returning one value | Scalar function |
| Multi-step business operation with transactions | Stored procedure |
| Automatic reaction to data changes | Trigger (sparingly) |

## Knowledge check

1. Which function type does the optimizer expand inline like a view?
2. What does `SET XACT_ABORT ON` do in a procedure?
3. Name the two virtual tables available inside a DML trigger.
4. How do you let an app run a procedure without SELECT rights on its tables?

<details>
<summary>Answers</summary>

1. Inline table-valued function.
2. Any runtime error automatically rolls back the entire transaction.
3. `inserted` and `deleted`.
4. `GRANT EXECUTE` on the procedure; ownership chaining covers table access when owners match.
</details>
