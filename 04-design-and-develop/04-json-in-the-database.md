# JSON in the Database

> **Objectives:** *Design and implement JSON columns and indexes* and *Write queries that include JSON functions, such as JSON_OBJECT, JSON_ARRAY, JSON_ARRAYAGG, JSON_CONTAINS, OPENJSON, and JSON_VALUE.*

> **Why this matters for AI:** language models consume and produce JSON. RAG pipelines convert rows to JSON before sending them to a model, then parse the JSON response. JSON skills appear in **both** Domain 1 and Domain 3.

## When to use a JSON column

| Use JSON when… | Use normal columns when… |
|---|---|
| Attributes vary per row (product specs) | Every row has the same attributes |
| Data arrives as JSON from APIs and is mostly stored/returned whole | You filter, join, or constrain on the values constantly |
| Schema changes frequently | You need foreign keys on the values |

A common, healthy design is **hybrid**: core columns relational, variable details in JSON.

## The native `json` data type

```sql
CREATE TABLE Sales.ProductDetails
(
    ProductID  int  NOT NULL CONSTRAINT PK_ProductDetails PRIMARY KEY,
    Attributes json NOT NULL
);

INSERT INTO Sales.ProductDetails (ProductID, Attributes)
VALUES (1, N'{"color":"green","weightKg":2.4,"capacity":2,"tags":["tent","ultralight"]}'),
       (2, N'{"color":"black","fuel":"isobutane","tags":["stove"]}');
```

Benefits over storing JSON in `nvarchar(max)`:

- Validated on insert (invalid JSON is rejected).
- Stored in an optimized binary format — faster reads and partial updates.
- Supports **JSON indexes**.

> On platforms or older compatibility levels without the `json` type, store JSON in `nvarchar(max)` with `CHECK (ISJSON(col) = 1)`.

## Reading JSON

### JSON_VALUE — extract a scalar

```sql
SELECT ProductID,
       JSON_VALUE(Attributes, '$.color')                  AS Color,
       JSON_VALUE(Attributes, '$.weightKg' RETURNING decimal(5,2)) AS WeightKg
FROM Sales.ProductDetails;
```

### JSON_QUERY — extract an object or array

```sql
SELECT JSON_QUERY(Attributes, '$.tags') AS Tags FROM Sales.ProductDetails;
```

> `JSON_VALUE` returns **scalars** only; `JSON_QUERY` returns **objects/arrays** only. Using the wrong one returns NULL (lax mode) — a frequent exam trap.

### Lax vs strict paths

```sql
JSON_VALUE(Attributes, 'lax $.missing')     -- NULL if not found (default)
JSON_VALUE(Attributes, 'strict $.missing')  -- error if not found
```

### JSON_PATH_EXISTS and ISJSON

```sql
SELECT ProductID FROM Sales.ProductDetails WHERE JSON_PATH_EXISTS(Attributes, '$.fuel') = 1;
SELECT ISJSON(N'{"a":1}');   -- 1
```

### JSON_CONTAINS — is a value in the document?

```sql
-- Products tagged "ultralight" (path to an array needs the [*] wildcard)
SELECT ProductID
FROM Sales.ProductDetails
WHERE JSON_CONTAINS(Attributes, N'ultralight', '$.tags[*]') = 1;
```

Returns `1`, `0` or `NULL`. A fourth argument `search_mode = 1` switches to LIKE semantics. `JSON_CONTAINS` predicates can use a **JSON index**.

### OPENJSON — turn JSON into rows

```sql
-- Default schema: key / value / type
SELECT p.ProductID, j.[key], j.[value]
FROM Sales.ProductDetails AS p
CROSS APPLY OPENJSON(p.Attributes) AS j;

-- Explicit schema
SELECT p.ProductID, j.Color, j.WeightKg
FROM Sales.ProductDetails AS p
CROSS APPLY OPENJSON(p.Attributes)
     WITH (Color    nvarchar(20)  '$.color',
           WeightKg decimal(5,2)  '$.weightKg') AS j;

-- Expand an array
SELECT p.ProductID, t.value AS Tag
FROM Sales.ProductDetails AS p
CROSS APPLY OPENJSON(p.Attributes, '$.tags') AS t;
```

`OPENJSON` is also how you **parse a language model's response** in RAG.

## Building JSON

### JSON_OBJECT and JSON_ARRAY

```sql
SELECT JSON_OBJECT('id': ProductID, 'name': Name, 'price': Price) AS ProductJson
FROM Sales.Products;

SELECT JSON_ARRAY(N'tent', N'stove', 42, NULL);          -- NULL ON NULL is ABSENT by default
SELECT JSON_ARRAY(N'a', NULL NULL ON NULL);              -- keep nulls
```

### Aggregating: JSON_ARRAYAGG and JSON_OBJECTAGG

```sql
-- One JSON array of product names per category
SELECT Category,
       JSON_ARRAYAGG(Name ORDER BY Name) AS Products
FROM Sales.Products
GROUP BY Category;

-- One JSON object: { "Tent": 199.00, "Stove": 49.00, ... }
SELECT JSON_OBJECTAGG(Name : Price) AS PriceMap
FROM Sales.Products;
```

### FOR JSON — whole result sets

```sql
SELECT TOP (3) ProductID AS id, Name AS name, Price AS price
FROM Sales.Products
ORDER BY Price DESC
FOR JSON PATH, ROOT('products');
```

`FOR JSON PATH` gives you control with dotted aliases (`AS [details.price]`); `FOR JSON AUTO` nests by table. Add `WITHOUT_ARRAY_WRAPPER` for a single object.

## Modifying JSON

```sql
UPDATE Sales.ProductDetails
SET Attributes = JSON_MODIFY(Attributes, '$.color', N'red')
WHERE ProductID = 1;

-- Append to an array
UPDATE Sales.ProductDetails
SET Attributes = JSON_MODIFY(Attributes, 'append $.tags', N'sale')
WHERE ProductID = 1;
```

## Indexing JSON

### Option 1 — JSON index (newest platforms)

```sql
-- Requires a clustered primary key on the table and a json-typed column
CREATE JSON INDEX JX_ProductDetails_Attributes
    ON Sales.ProductDetails (Attributes)
    FOR ('$.color', '$.tags')
    WITH (OPTIMIZE_FOR_ARRAY_SEARCH = ON);
```

Supports predicates such as `JSON_VALUE(...) = …`, `JSON_PATH_EXISTS(...) = 1`, and `JSON_CONTAINS(...)`. Limits: one JSON index per JSON column, paths can't overlap (`$.a` and `$.a.b`), offline build only.

### Option 2 — computed column + regular index (works everywhere)

```sql
ALTER TABLE Sales.ProductDetails
    ADD Color AS JSON_VALUE(Attributes, '$.color');

CREATE INDEX IX_ProductDetails_Color ON Sales.ProductDetails (Color);

-- This query can now seek:
SELECT ProductID FROM Sales.ProductDetails WHERE JSON_VALUE(Attributes, '$.color') = N'green';
```

## Preparing rows for a language model (Domain 3 preview)

```sql
DECLARE @context nvarchar(max) =
(
    SELECT TOP (5) p.Name, p.Category, p.Price, p.Description
    FROM Sales.Products AS p
    ORDER BY p.Price DESC
    FOR JSON PATH
);
SELECT @context;
```

## Knowledge check

1. You need the `tags` array from a JSON document. `JSON_VALUE` or `JSON_QUERY`?
2. What table requirement does `CREATE JSON INDEX` have?
3. Which function returns one JSON array aggregated from many rows?
4. How do you turn each element of a JSON array into a row?

<details>
<summary>Answers</summary>

1. `JSON_QUERY` (arrays/objects). `JSON_VALUE` would return NULL.
2. A clustered primary key (and the column must be the `json` type).
3. `JSON_ARRAYAGG`.
4. `CROSS APPLY OPENJSON(col, '$.array')`.
</details>
