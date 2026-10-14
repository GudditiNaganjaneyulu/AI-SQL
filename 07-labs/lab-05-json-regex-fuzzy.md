# Lab 5 — JSON, Regex and Fuzzy Matching

**Goal:** query and build JSON, validate and clean text with regular expressions, and find near-duplicates with fuzzy matching.

**Requirements:** compatibility level 170 (for `REGEXP_LIKE`). Fuzzy functions are **preview** — on SQL Server 2025 run `ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;` first.

## Part A — Reading JSON

1. Show each Camping product with `capacity`, `weightKg` and `seasons` from `Attributes`.
2. List products whose attributes contain a `fuel` property.
3. Shred all attributes of product 1 into key/value rows.
4. Products that weigh less than 1 kg (convert the value to decimal).

<details>
<summary>Solutions A</summary>

```sql
SELECT Name,
       JSON_VALUE(Attributes, '$.capacity') AS Capacity,
       JSON_VALUE(Attributes, '$.weightKg') AS WeightKg,
       JSON_VALUE(Attributes, '$.seasons')  AS Seasons
FROM Sales.Products WHERE Category = N'Camping';

SELECT Name FROM Sales.Products WHERE JSON_PATH_EXISTS(Attributes, '$.fuel') = 1;

SELECT j.[key], j.[value], j.[type]
FROM Sales.Products AS p CROSS APPLY OPENJSON(p.Attributes) AS j
WHERE p.ProductID = 1;

SELECT Name, TRY_CAST(JSON_VALUE(Attributes, '$.weightKg') AS decimal(6,2)) AS WeightKg
FROM Sales.Products
WHERE TRY_CAST(JSON_VALUE(Attributes, '$.weightKg') AS decimal(6,2)) < 1;
```
</details>

## Part B — Building JSON

5. Return one JSON object per product: `{"id":…, "name":…, "price":…}` using `JSON_OBJECT`.
6. Return one row per category with a JSON array of product names (sorted) using `JSON_ARRAYAGG`.
7. Return the 3 most expensive products as a JSON document with root `products` using `FOR JSON PATH`.
8. Add `"onSale": true` to product 7's attributes with `JSON_MODIFY`.

<details>
<summary>Solutions B</summary>

```sql
SELECT JSON_OBJECT('id': ProductID, 'name': Name, 'price': Price) AS ProductJson FROM Sales.Products;

SELECT Category, JSON_ARRAYAGG(Name ORDER BY Name) AS Products FROM Sales.Products GROUP BY Category;

SELECT TOP (3) ProductID AS id, Name AS name, Price AS price
FROM Sales.Products ORDER BY Price DESC
FOR JSON PATH, ROOT('products');

UPDATE Sales.Products SET Attributes = JSON_MODIFY(Attributes, '$.onSale', CAST(1 AS bit)) WHERE ProductID = 7;
SELECT Attributes FROM Sales.Products WHERE ProductID = 7;
```
</details>

## Part C — JSON index (newest platforms)

9. Create a JSON index on `Sales.Products(Attributes)` for the paths `$.color` and `$.fuel`, then query by color.

```sql
CREATE JSON INDEX JX_Products_Attributes ON Sales.Products (Attributes) FOR ('$.color', '$.fuel');

SELECT Name FROM Sales.Products WHERE JSON_VALUE(Attributes, '$.color') = 'green';
```

If `CREATE JSON INDEX` isn't available on your platform, use the computed-column approach from the chapter instead.

## Part D — Regular expressions

10. Find customers whose email is **not** a valid format (regex), including NULLs.
11. Add a CHECK constraint that rejects badly formatted phone numbers (`555-201-1001` style) but allows NULL.
12. Mask all digits in phone numbers with `#` using `REGEXP_REPLACE`.
13. Extract the email domain with `REGEXP_SUBSTR`.
14. Count the words in each product description with `REGEXP_COUNT`.

<details>
<summary>Solutions D</summary>

```sql
SELECT CustomerID, Email FROM Sales.Customers
WHERE Email IS NULL OR NOT REGEXP_LIKE(Email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

ALTER TABLE Sales.Customers ADD CONSTRAINT CK_Customers_Phone
    CHECK (Phone IS NULL OR REGEXP_LIKE(Phone, '^\d{3}-\d{3}-\d{4}$'));

SELECT Phone, REGEXP_REPLACE(Phone, '\d', '#') AS Masked FROM Sales.Customers;

SELECT Email, REGEXP_SUBSTR(Email, '@(.+)$', 1, 1, 'i', 1) AS Domain FROM Sales.Customers;

SELECT Name, REGEXP_COUNT(Description, '\w+') AS Words FROM Sales.Products;
```
</details>

## Part E — Fuzzy matching (Preview)

15. Insert two "dirty" duplicate customers: `Asha Raoo` (India) and `Benn Carter` (UK).
16. Find likely duplicates: same country and `JARO_WINKLER_SIMILARITY` of full names ≥ 90.
17. Compare `EDIT_DISTANCE`, `EDIT_DISTANCE_SIMILARITY` and `JARO_WINKLER_DISTANCE` for each pair.

<details>
<summary>Solutions E</summary>

```sql
INSERT INTO Sales.Customers (FirstName, LastName, Email, Country)
VALUES (N'Asha', N'Raoo', N'asha.r@example.com', N'India'),
       (N'Benn', N'Carter', N'benn.c@example.com', N'UK');

WITH n AS (SELECT CustomerID, Country, CONCAT(FirstName, N' ', LastName) AS FullName FROM Sales.Customers)
SELECT a.CustomerID, a.FullName, b.CustomerID, b.FullName,
       JARO_WINKLER_SIMILARITY(a.FullName, b.FullName) AS jw_sim,
       EDIT_DISTANCE(a.FullName, b.FullName)           AS ed,
       EDIT_DISTANCE_SIMILARITY(a.FullName, b.FullName) AS ed_sim,
       JARO_WINKLER_DISTANCE(a.FullName, b.FullName)   AS jw_dist
FROM n AS a
JOIN n AS b ON a.CustomerID < b.CustomerID AND a.Country = b.Country
WHERE JARO_WINKLER_SIMILARITY(a.FullName, b.FullName) >= 90;
```

Fuzzy functions require Windows or binary collations; if you get a collation error, add `COLLATE Latin1_General_100_CI_AS` to the arguments.
</details>

## Reflection

- When would you choose fuzzy matching over vector search for duplicate detection?
- Why is `REGEXP_LIKE(Email, '@example\.com$')` unable to use an index seek?
