# Tables, Data Types and Constraints

> **Objective:** *Design and implement tables, including data types, size, columns…; database constraints, including PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, and DEFAULT; SEQUENCES.*

## Choosing data types

**Rule:** choose the **smallest type that safely fits all valid values**. Smaller rows mean more rows per 8 KB page, less I/O, smaller indexes, and less memory.

| Data | Good choice | Avoid | Why |
|---|---|---|---|
| Whole numbers | `tinyint` (0–255), `smallint`, `int`, `bigint` | `bigint` everywhere | Each step doubles the bytes |
| Money / exact decimals | `decimal(p,s)` e.g. `decimal(10,2)` | `float`, `real` | Floats are approximate (rounding errors) |
| Text, multilingual | `nvarchar(n)` | `nvarchar(max)` by default | `max` can't be an index key and may be stored off-row |
| Text, Latin-only or UTF-8 collation | `varchar(n)` | — | Half the bytes of `nvarchar` for ASCII |
| Fixed-length codes | `char(2)` for country code | `varchar(2)` | No length overhead |
| Dates | `date` | `datetime` | `date` is 3 bytes |
| Date + time | `datetime2(0–7)` | `datetime` | More precise, wider range, often smaller |
| True/false | `bit` | `char(1)` | 1 bit (packed) |
| GUIDs | `uniqueidentifier` with `NEWSEQUENTIALID()` default | `NEWID()` as clustered key | Random GUIDs fragment clustered indexes |
| JSON documents | `json` | `nvarchar(max)` | Native binary format, validated, indexable |
| Embeddings | `vector(n)` | `varbinary` / JSON text | Optimized storage and vector functions |

> **Row size:** a row's in-row data is limited to **8,060 bytes**. Larger `max` types are pushed off-row.

## Creating a table with constraints

```sql
CREATE SCHEMA Sales;
GO

CREATE TABLE Sales.Products
(
    ProductID    int            IDENTITY(1,1)  NOT NULL,
    Sku          varchar(20)                   NOT NULL,
    Name         nvarchar(200)                 NOT NULL,
    Category     nvarchar(50)                  NOT NULL,
    Price        decimal(10,2)                 NOT NULL,
    Discontinued bit                           NOT NULL  CONSTRAINT DF_Products_Discontinued DEFAULT (0),
    CreatedAt    datetime2(0)                  NOT NULL  CONSTRAINT DF_Products_CreatedAt   DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Products        PRIMARY KEY CLUSTERED (ProductID),
    CONSTRAINT UQ_Products_Sku    UNIQUE (Sku),
    CONSTRAINT CK_Products_Price  CHECK (Price >= 0)
);

CREATE TABLE Sales.OrderLines
(
    OrderID   int           NOT NULL,
    LineNumber    smallint      NOT NULL,
    ProductID int           NOT NULL,
    Quantity  int           NOT NULL CONSTRAINT CK_OrderLines_Qty CHECK (Quantity > 0),
    UnitPrice decimal(10,2) NOT NULL,

    CONSTRAINT PK_OrderLines PRIMARY KEY (OrderID, LineNumber),
    CONSTRAINT FK_OrderLines_Products FOREIGN KEY (ProductID)
        REFERENCES Sales.Products (ProductID)
        ON DELETE NO ACTION          -- default; alternatives: CASCADE, SET NULL, SET DEFAULT
);
```

**Name every constraint** (`PK_`, `FK_`, `UQ_`, `CK_`, `DF_`). Auto-generated names differ between environments and break deployment scripts.

### Constraint behaviours to remember

| Constraint | Notes |
|---|---|
| `PRIMARY KEY` | Implies NOT NULL and unique; creates a **clustered** index by default (if none exists) |
| `UNIQUE` | Creates a nonclustered unique index; allows **one NULL** |
| `FOREIGN KEY` | Does **not** automatically create an index on the referencing column — create one yourself for join/delete performance |
| `CHECK` | Rejects rows where the condition is FALSE (UNKNOWN passes!) |
| `DEFAULT` | Used only when the column is omitted from the INSERT |

### Cascading actions

```sql
-- Deleting a customer deletes their addresses automatically
CONSTRAINT FK_Addresses_Customers FOREIGN KEY (CustomerID)
    REFERENCES Sales.Customers (CustomerID) ON DELETE CASCADE
```

Use cascades deliberately — they can delete far more than expected.

### Disabling and re-enabling constraints (bulk loads)

```sql
ALTER TABLE Sales.OrderLines NOCHECK CONSTRAINT FK_OrderLines_Products;
-- bulk load...
ALTER TABLE Sales.OrderLines WITH CHECK CHECK CONSTRAINT FK_OrderLines_Products;  -- re-validates = "trusted"
```

Re-enable `WITH CHECK` so the optimizer can **trust** the constraint.

## Computed columns

```sql
ALTER TABLE Sales.OrderLines
ADD LineTotal AS (Quantity * UnitPrice) PERSISTED;   -- PERSISTED stores it; can be indexed
```

## SEQUENCE objects

A **SEQUENCE** generates numbers independently of any table.

```sql
CREATE SEQUENCE Sales.InvoiceNumbers
    AS int
    START WITH 100000
    INCREMENT BY 1
    MINVALUE 100000
    NO CYCLE
    CACHE 50;          -- caching improves performance; gaps possible after restart

-- Use it directly
SELECT NEXT VALUE FOR Sales.InvoiceNumbers;

-- Or as a column default
CREATE TABLE Sales.Invoices
(
    InvoiceNo int NOT NULL
        CONSTRAINT DF_Invoices_No DEFAULT (NEXT VALUE FOR Sales.InvoiceNumbers),
    OrderID   int NOT NULL,
    CONSTRAINT PK_Invoices PRIMARY KEY (InvoiceNo)
);

-- Reserve a block of values (e.g., for an app that assigns numbers itself)
DECLARE @first sql_variant;
EXEC sys.sp_sequence_get_range
     @sequence_name = N'Sales.InvoiceNumbers',
     @range_size = 100,
     @range_first_value = @first OUTPUT;
```

### IDENTITY vs SEQUENCE

| | IDENTITY | SEQUENCE |
|---|---|---|
| Scope | One column in one table | Independent object, shareable across tables |
| Get value before insert | No | Yes (`NEXT VALUE FOR`) |
| Restart / cycle | Reseed with `DBCC CHECKIDENT` | `ALTER SEQUENCE … RESTART`; `CYCLE` option |
| Reserve ranges | No | `sp_sequence_get_range` |
| Gaps | Possible | Possible |

> **Exam tip:** "a number unique **across several tables**" or "need the value **before** inserting" → **SEQUENCE**.

## Altering tables safely

```sql
ALTER TABLE Sales.Products ADD Weight decimal(6,2) NULL;          -- adding NULLable columns is fast
ALTER TABLE Sales.Products ALTER COLUMN Name nvarchar(300) NOT NULL;
ALTER TABLE Sales.Products DROP CONSTRAINT CK_Products_Price;
```

In real projects, schema changes are made through **SQL Database Projects** (Domain 2), not ad-hoc scripts.

## Knowledge check

1. Why should `decimal` be used for prices instead of `float`?
2. Does a FOREIGN KEY automatically create an index?
3. You need invoice numbers unique across `Invoices` and `CreditNotes`. Which object?
4. What does `WITH CHECK CHECK CONSTRAINT` do?

<details>
<summary>Answers</summary>

1. `float` is approximate and introduces rounding errors; `decimal` is exact.
2. No — create an index on the FK column yourself.
3. A `SEQUENCE` used as the default in both tables.
4. Re-enables the constraint **and** validates existing rows so the constraint becomes trusted.
</details>
