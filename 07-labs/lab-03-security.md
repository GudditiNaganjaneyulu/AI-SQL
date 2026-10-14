# Lab 3 — Security

**Goal:** apply least-privilege permissions, Dynamic Data Masking and Row-Level Security, and observe their effects by impersonating test users.

> Uses **users without logins** so it works on Azure SQL Database and SQL Server alike. In real systems you would use Microsoft Entra users, groups and managed identities.

## Setup — test users

```sql
CREATE USER SalesAnalyst WITHOUT LOGIN;
CREATE USER SupportAgent WITHOUT LOGIN;
CREATE USER CustomerApp  WITHOUT LOGIN;
```

## Part A — Roles and permissions

1. Create role `SalesReaders` with `SELECT` on schema `Sales`, and add `SalesAnalyst`.
2. **Deny** `SalesReaders` access to `Sales.Customers.Phone`.
3. Impersonate `SalesAnalyst` and verify: products readable; `SELECT Phone FROM Sales.Customers` fails; `SELECT FirstName FROM Sales.Customers` works.

```sql
CREATE ROLE SalesReaders;
GRANT SELECT ON SCHEMA::Sales TO SalesReaders;
DENY  SELECT ON Sales.Customers (Phone) TO SalesReaders;
ALTER ROLE SalesReaders ADD MEMBER SalesAnalyst;

EXECUTE AS USER = 'SalesAnalyst';
    SELECT TOP (3) Name FROM Sales.Products;          -- works
    SELECT TOP (3) FirstName FROM Sales.Customers;    -- works
    SELECT TOP (3) Phone FROM Sales.Customers;        -- error: permission denied
REVERT;
```

## Part B — Dynamic Data Masking

4. Mask `Email` with `email()`, `Phone` with `partial(0,"XXX-XXX-",4)`, and `HR.Employees.Salary` with `default()`.
5. Grant `SupportAgent` SELECT on `Sales.Customers` and `HR.Employees`, and compare what `SupportAgent` sees vs `dbo`.
6. Grant `UNMASK` on just `HR.Employees` to `SupportAgent`; re-check.
7. As `SupportAgent`, run `SELECT COUNT(*) FROM HR.Employees WHERE Salary > 150000`. What does this prove about DDM?

```sql
ALTER TABLE Sales.Customers ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
ALTER TABLE Sales.Customers ALTER COLUMN Phone ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XXX-",4)');
ALTER TABLE HR.Employees    ALTER COLUMN Salary ADD MASKED WITH (FUNCTION = 'default()');

GRANT SELECT ON Sales.Customers TO SupportAgent;
GRANT SELECT ON HR.Employees    TO SupportAgent;

EXECUTE AS USER = 'SupportAgent';
    SELECT TOP (3) Email, Phone FROM Sales.Customers;
    SELECT TOP (3) FullName, Salary FROM HR.Employees;
REVERT;

GRANT UNMASK ON HR.Employees TO SupportAgent;

EXECUTE AS USER = 'SupportAgent';
    SELECT TOP (3) FullName, Salary FROM HR.Employees;               -- now unmasked
    SELECT COUNT(*) FROM HR.Employees WHERE Salary > 150000;         -- inference works even when masked
REVERT;
```

<details>
<summary>Answer to 7</summary>

Even with masking (before `UNMASK`), filters operate on real values, so users can infer data by repeated range queries. **DDM is not encryption** — combine with permissions, or use Always Encrypted for confidentiality.
</details>

## Part C — Row-Level Security with SESSION_CONTEXT

8. Create a predicate function and a security policy so that `CustomerApp` sees only the orders of the customer ID stored in `SESSION_CONTEXT(N'CustomerID')`, while `dbo` (or members of a support role) sees all.
9. Add a BLOCK predicate so the app can't insert orders for other customers.

```sql
CREATE SCHEMA Security;
GO
CREATE OR ALTER FUNCTION Security.fn_OrderFilter (@CustomerID int)
RETURNS TABLE WITH SCHEMABINDING AS
RETURN SELECT 1 AS allowed
       WHERE @CustomerID = CAST(SESSION_CONTEXT(N'CustomerID') AS int)
          OR USER_NAME() = N'dbo';
GO
CREATE SECURITY POLICY Security.OrderPolicy
    ADD FILTER PREDICATE Security.fn_OrderFilter(CustomerID) ON Sales.Orders,
    ADD BLOCK  PREDICATE Security.fn_OrderFilter(CustomerID) ON Sales.Orders AFTER INSERT
WITH (STATE = ON);
GO

GRANT SELECT, INSERT ON Sales.Orders TO CustomerApp;

EXECUTE AS USER = 'CustomerApp';
    EXEC sp_set_session_context @key = N'CustomerID', @value = 3;
    SELECT OrderID, CustomerID, Status FROM Sales.Orders;            -- only customer 3
    INSERT INTO Sales.Orders (CustomerID, OrderDate, Status)
    VALUES (5, SYSUTCDATETIME(), N'New');                            -- blocked
REVERT;
```

> Session context persists for the connection; set it with `@read_only = 1` in real apps so it can't be changed later in the session.

## Clean up (optional)

```sql
DROP SECURITY POLICY Security.OrderPolicy;
DROP FUNCTION Security.fn_OrderFilter;
ALTER TABLE Sales.Customers ALTER COLUMN Email DROP MASKED;
ALTER TABLE Sales.Customers ALTER COLUMN Phone DROP MASKED;
ALTER TABLE HR.Employees    ALTER COLUMN Salary DROP MASKED;
DROP USER SalesAnalyst; DROP USER SupportAgent; DROP USER CustomerApp;
DROP ROLE SalesReaders;
```

(Drop the users after removing them from roles if `DROP USER` complains.)

## Reflection

- Which feature would you choose if DBAs must not see salaries at all? (Hint: not DDM.)
- Where would you set `SESSION_CONTEXT` in a real application or in Data API builder?
