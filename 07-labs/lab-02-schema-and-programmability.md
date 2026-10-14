# Lab 2 — Schema and Programmability

**Goal:** design objects with the right types and constraints, then build views, functions, procedures and triggers.

## Part A — Constraints and a SEQUENCE

1. Create `Sales.Invoices` with:
   - `InvoiceNo int` defaulting from a new sequence `Sales.InvoiceNumbers` starting at 100000,
   - `OrderID` FK to `Sales.Orders`, unique (one invoice per order),
   - `Amount decimal(10,2)` with a CHECK `>= 0`,
   - `IssuedAt datetime2(0)` defaulting to UTC now.
2. Insert invoices for all **Paid** and **Shipped** orders using their revenue.
3. Try to insert a negative amount and read the error message.

<details>
<summary>Solution A</summary>

```sql
CREATE SEQUENCE Sales.InvoiceNumbers AS int START WITH 100000 INCREMENT BY 1;

CREATE TABLE Sales.Invoices
(
    InvoiceNo int           NOT NULL CONSTRAINT DF_Invoices_No DEFAULT (NEXT VALUE FOR Sales.InvoiceNumbers),
    OrderID   int           NOT NULL,
    Amount    decimal(10,2) NOT NULL,
    IssuedAt  datetime2(0)  NOT NULL CONSTRAINT DF_Invoices_IssuedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Invoices PRIMARY KEY (InvoiceNo),
    CONSTRAINT UQ_Invoices_Order UNIQUE (OrderID),
    CONSTRAINT FK_Invoices_Orders FOREIGN KEY (OrderID) REFERENCES Sales.Orders (OrderID),
    CONSTRAINT CK_Invoices_Amount CHECK (Amount >= 0)
);

INSERT INTO Sales.Invoices (OrderID, Amount)
SELECT o.OrderID, SUM(ol.Quantity * ol.UnitPrice)
FROM Sales.Orders AS o JOIN Sales.OrderLines AS ol ON ol.OrderID = o.OrderID
WHERE o.Status IN (N'Paid', N'Shipped')
GROUP BY o.OrderID;

INSERT INTO Sales.Invoices (OrderID, Amount) VALUES (1, -5);   -- fails: CK_Invoices_Amount
```
</details>

## Part B — Temporal table

4. Create a system-versioned temporal table `Sales.PriceList (ProductID PK, Price)` and load current prices.
5. Change two prices, wait a few seconds, change one again.
6. Query the price list **as of** before your first change, and show all versions of one product.

<details>
<summary>Solution B</summary>

```sql
CREATE TABLE Sales.PriceList
(
    ProductID int NOT NULL CONSTRAINT PK_PriceList PRIMARY KEY,
    Price decimal(10,2) NOT NULL,
    ValidFrom datetime2(2) GENERATED ALWAYS AS ROW START NOT NULL,
    ValidTo   datetime2(2) GENERATED ALWAYS AS ROW END   NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = Sales.PriceListHistory));

INSERT INTO Sales.PriceList (ProductID, Price) SELECT ProductID, Price FROM Sales.Products;

DECLARE @before datetime2(2) = SYSUTCDATETIME();
WAITFOR DELAY '00:00:02';
UPDATE Sales.PriceList SET Price = Price * 0.9 WHERE ProductID IN (1, 2);
WAITFOR DELAY '00:00:02';
UPDATE Sales.PriceList SET Price = 199 WHERE ProductID = 1;

SELECT * FROM Sales.PriceList FOR SYSTEM_TIME AS OF @before WHERE ProductID IN (1, 2);
SELECT *, ValidFrom, ValidTo FROM Sales.PriceList FOR SYSTEM_TIME ALL WHERE ProductID = 1 ORDER BY ValidFrom;
```

(Temporal periods use **UTC**.)
</details>

## Part C — View, inline TVF and stored procedure

7. Create view `Sales.vOrderSummary` (OrderID, OrderDate, CustomerID, LastName, Status, OrderTotal).
8. Create inline TVF `Sales.fnCustomerOrders(@CustomerID)` returning that customer's rows from the view.
9. Create procedure `Sales.usp_PlaceOrder` (as in the chapter) with `SET NOCOUNT ON`, `SET XACT_ABORT ON`, `TRY…CATCH`, `THROW`, and an `@OrderID OUTPUT`. Call it with a valid and an invalid product.

<details>
<summary>Solution C</summary>

```sql
CREATE OR ALTER VIEW Sales.vOrderSummary AS
SELECT o.OrderID, o.OrderDate, c.CustomerID, c.LastName, o.Status,
       SUM(ol.Quantity * ol.UnitPrice) AS OrderTotal
FROM Sales.Orders AS o
JOIN Sales.Customers  AS c  ON c.CustomerID = o.CustomerID
JOIN Sales.OrderLines AS ol ON ol.OrderID   = o.OrderID
GROUP BY o.OrderID, o.OrderDate, c.CustomerID, c.LastName, o.Status;
GO

CREATE OR ALTER FUNCTION Sales.fnCustomerOrders (@CustomerID int)
RETURNS TABLE AS RETURN
    SELECT OrderID, OrderDate, Status, OrderTotal
    FROM Sales.vOrderSummary WHERE CustomerID = @CustomerID;
GO

CREATE OR ALTER PROCEDURE Sales.usp_PlaceOrder
    @CustomerID int, @ProductID int, @Quantity int, @OrderID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO Sales.Orders (CustomerID, OrderDate, Status) VALUES (@CustomerID, SYSUTCDATETIME(), N'New');
        SET @OrderID = SCOPE_IDENTITY();
        INSERT INTO Sales.OrderLines (OrderID, LineNumber, ProductID, Quantity, UnitPrice)
        SELECT @OrderID, 1, ProductID, @Quantity, Price FROM Sales.Products WHERE ProductID = @ProductID;
        IF @@ROWCOUNT = 0 THROW 50001, 'Product not found.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

DECLARE @id int;
EXEC Sales.usp_PlaceOrder 1, 2, 1, @id OUTPUT; SELECT @id AS NewOrder;
EXEC Sales.usp_PlaceOrder 1, 9999, 1, @id OUTPUT;   -- raises 50001, nothing committed
```
</details>

## Part D — Audit trigger

10. Create `Sales.PriceAudit (AuditID identity, ProductID, OldPrice, NewPrice, ChangedAt)`.
11. Create a **set-based** AFTER UPDATE trigger on `Sales.Products` that logs price changes only.
12. Update prices for a whole category and confirm one audit row per changed product.

<details>
<summary>Solution D</summary>

```sql
CREATE TABLE Sales.PriceAudit
(
    AuditID int IDENTITY PRIMARY KEY,
    ProductID int NOT NULL, OldPrice decimal(10,2), NewPrice decimal(10,2),
    ChangedAt datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
CREATE OR ALTER TRIGGER Sales.trg_Products_PriceAudit ON Sales.Products AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(Price) RETURN;
    INSERT INTO Sales.PriceAudit (ProductID, OldPrice, NewPrice)
    SELECT i.ProductID, d.Price, i.Price
    FROM inserted AS i JOIN deleted AS d ON d.ProductID = i.ProductID
    WHERE i.Price <> d.Price;
END;
GO
UPDATE Sales.Products SET Price = Price + 1 WHERE Category = N'Cooking';
SELECT * FROM Sales.PriceAudit;
```
</details>

## Part E — Recursive CTE

13. Show the full management chain for every employee as a path (`Priya Menon > Tom Becker > …`) with a level number.

<details>
<summary>Solution E</summary>

```sql
WITH Org AS (
    SELECT EmployeeID, FullName, ManagerID, 0 AS Lvl, CAST(FullName AS nvarchar(4000)) AS Path
    FROM HR.Employees WHERE ManagerID IS NULL
    UNION ALL
    SELECT e.EmployeeID, e.FullName, e.ManagerID, o.Lvl + 1, CAST(o.Path + N' > ' + e.FullName AS nvarchar(4000))
    FROM HR.Employees AS e JOIN Org AS o ON e.ManagerID = o.EmployeeID
)
SELECT EmployeeID, Lvl, Path FROM Org ORDER BY Path;
```
</details>
