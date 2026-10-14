# Functions, CASE, Strings and Dates

> **Why this matters:** you'll transform data constantly — cleaning text before embedding it, bucketing values, formatting dates for APIs.

## CASE expressions

```sql
SELECT Name, Price,
       CASE
           WHEN Price < 50  THEN N'Budget'
           WHEN Price < 200 THEN N'Mid-range'
           ELSE N'Premium'
       END AS PriceBand
FROM Sales.Products;
```

`IIF(condition, true_value, false_value)` is a shorthand for a two-branch CASE.

## String functions

| Function | Example | Result |
|---|---|---|
| `LEN(s)` | `LEN(N'Tent ')` | 4 (trailing spaces ignored) |
| `UPPER / LOWER` | `UPPER(N'tent')` | `TENT` |
| `LEFT / RIGHT` | `LEFT(N'Trailhead', 5)` | `Trail` |
| `SUBSTRING(s, start, len)` | `SUBSTRING(N'Trailhead', 6, 4)` | `head` |
| `CHARINDEX(find, s)` | `CHARINDEX(N'@', N'a@b.com')` | 2 |
| `REPLACE(s, a, b)` | `REPLACE(N'a-b', N'-', N'_')` | `a_b` |
| `TRIM / LTRIM / RTRIM` | `TRIM(N'  x  ')` | `x` |
| `CONCAT(a, b, …)` | `CONCAT(N'A', NULL, N'B')` | `AB` (NULLs become empty) |
| `CONCAT_WS(sep, a, b, …)` | `CONCAT_WS(N', ', City, Country)` | joins with separator, skips NULLs |
| `STRING_AGG(col, sep)` | aggregate | joins values from many rows |
| `STRING_SPLIT(s, sep)` | table-valued | splits a string into rows |

> `+` also concatenates, but `N'A' + NULL` is `NULL`. Prefer `CONCAT` when values may be NULL.

## Date and time

| Type | Use |
|---|---|
| `date` | Calendar date only |
| `time` | Time only |
| `datetime2(n)` | Date + time, precise — **preferred** over legacy `datetime` |
| `datetimeoffset` | Date + time + time-zone offset |

```sql
SELECT SYSDATETIME()                          AS now_local,
       SYSUTCDATETIME()                       AS now_utc,
       DATEADD(DAY, 30, SYSDATETIME())        AS in_30_days,
       DATEDIFF(DAY, '20260101', '20260315')  AS days_between,
       DATEPART(MONTH, SYSDATETIME())         AS month_number,
       EOMONTH(SYSDATETIME())                 AS end_of_month,
       DATETRUNC(MONTH, SYSDATETIME())        AS start_of_month,   -- SQL Server 2022+
       FORMAT(SYSDATETIME(), 'yyyy-MM-dd')    AS iso_text;
```

> Use the unambiguous literal format `'YYYYMMDD'` (e.g., `'20260315'`) for dates in code.

## Conversions

```sql
SELECT CAST(N'42' AS int),
       CONVERT(varchar(10), SYSDATETIME(), 23),  -- style 23 = yyyy-mm-dd
       TRY_CAST(N'abc' AS int);                  -- NULL instead of an error
```

`TRY_CAST` / `TRY_CONVERT` return `NULL` when conversion fails — useful for messy input.

## Math

`ROUND(x, 2)`, `CEILING(x)`, `FLOOR(x)`, `ABS(x)`, `POWER(x, y)`, `SQRT(x)`.

## Generating rows: GENERATE_SERIES

```sql
SELECT value FROM GENERATE_SERIES(1, 10);      -- SQL Server 2022+, Azure SQL
```

Handy for test data and calendars.

## Try it

1. Show each customer's full name as `LastName, FirstName`.
2. Show each order with how many days ago it was placed.
3. Label products: `Cheap` (< 30), `Normal` (30–150), `Expensive` (> 150).

<details>
<summary>Answers</summary>

```sql
SELECT CONCAT(LastName, N', ', FirstName) AS FullName FROM Sales.Customers;

SELECT OrderID, DATEDIFF(DAY, OrderDate, SYSDATETIME()) AS DaysAgo FROM Sales.Orders;

SELECT Name, CASE WHEN Price < 30 THEN N'Cheap'
                  WHEN Price <= 150 THEN N'Normal'
                  ELSE N'Expensive' END AS Label
FROM Sales.Products;
```
</details>
