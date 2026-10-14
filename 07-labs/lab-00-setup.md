# Lab 0 — Create the Lab Database

**Goal:** create the `DP800Lab` database and sample data used by every chapter.

## Steps

1. Complete *Start Here → Set Up Your Environment* and connect to your server.
2. Create an empty database named **`DP800Lab`**:
   - **Azure SQL Database:** created in the portal during setup.
   - **SQL Server 2025 (Docker):** run `CREATE DATABASE DP800Lab;` then switch to it (`USE DP800Lab;`).
3. Open `setup/create-lab-database.sql` from this repository (folder `07-labs/setup/`) in VS Code or SSMS.
4. Make sure the connection's **database is `DP800Lab`** (not `master`).
5. Run the whole script.

## Expected result

The final query returns:

| TableName | NumRows |
|---|---|
| Customers | 15 |
| Products | 20 |
| Orders | 40 |
| OrderLines | 80 |
| Employees | 12 |

## What was created

| Object | Notes |
|---|---|
| `Sales.Customers` | Includes a customer with a NULL email and one with a NULL phone — for NULL-handling exercises |
| `Sales.Products` | Rich `Description` text (for full-text and vector search), a `Tags` CSV column, an `Attributes` **json** column; one product discontinued |
| `Sales.Orders` | Statuses New/Paid/Shipped/Cancelled; `ShippedDate` NULL for unshipped orders |
| `Sales.OrderLines` | 1–3 lines per order |
| `HR.Employees` | A 4-level management hierarchy with salaries — for recursive CTEs, masking and RLS |

## Quick checks

```sql
SELECT TOP (5) Name, Category, Price FROM Sales.Products ORDER BY Price DESC;

SELECT JSON_VALUE(Attributes, '$.weightKg') AS WeightKg, Name
FROM Sales.Products
WHERE Category = N'Camping';

SELECT name, compatibility_level FROM sys.databases WHERE name = DB_NAME();
```

If the compatibility-level statement at the top of the script fails on your platform, remove it and continue — most labs work at level 160; `REGEXP_LIKE` and `AI_GENERATE_CHUNKS` need 170.

If anything fails, see [Troubleshooting](troubleshooting.md).
