# Core T-SQL

DP-800 assumes you **already write T-SQL fluently**. This space builds that skill from the first `SELECT` to correlated subqueries.

## Before you start

Run **Lab 0** (Hands-on Labs space) to create the `DP800Lab` sample database. Every example here uses its tables:

| Table | What it holds |
|---|---|
| `Sales.Customers` | CustomerID, FirstName, LastName, Email, Country, CreatedAt |
| `Sales.Products` | ProductID, Name, Category, Price, Description, Attributes (JSON) |
| `Sales.Orders` | OrderID, CustomerID, OrderDate, Status |
| `Sales.OrderLines` | OrderID, ProductID, Quantity, UnitPrice |
| `HR.Employees` | EmployeeID, FullName, Title, ManagerID |

## Chapters (in order)

1. [Your First Queries](01-first-queries.md)
2. [Filtering, NULLs and Logic](02-filtering-and-nulls.md)
3. [Functions, CASE, Strings and Dates](03-functions-and-case.md)
4. [Joins](04-joins.md)
5. [Grouping and Aggregation](05-grouping-and-aggregation.md)
6. [Subqueries and Correlated Queries](06-subqueries.md)
7. [Set Operators and APPLY](07-set-operators-and-apply.md)
8. [Modifying Data](08-modifying-data.md)

## Logical query processing order

Memorize this — it explains most beginner errors:

```
1. FROM / JOIN      ← which rows exist
2. WHERE            ← filter rows
3. GROUP BY         ← form groups
4. HAVING           ← filter groups
5. SELECT           ← compute columns and aliases
6. DISTINCT
7. ORDER BY         ← sort (can use SELECT aliases)
8. TOP / OFFSET-FETCH
```

That is why you **cannot use a SELECT alias in WHERE** (WHERE runs first) but **can use it in ORDER BY**.
