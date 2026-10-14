# What Is a Database?

> **Why this matters:** every DP-800 objective — from indexes to vector search — is about storing, protecting, or retrieving data in a database. You need a clear mental model first.

## Data and databases

**Data** is any recorded fact: a customer's name, an order date, a product price.

A **database** is an organized collection of data that many people and programs can use at the same time, safely.

A **database management system (DBMS)** is the software that stores the data and answers requests for it. Microsoft's DBMS is the **SQL Database Engine**, which powers SQL Server, Azure SQL, and SQL database in Microsoft Fabric.

## Why not just use a spreadsheet?

| Need | Spreadsheet | Database |
|---|---|---|
| Thousands of people editing at once | Conflicts and overwrites | Handles concurrency with transactions and locks |
| Millions of rows | Slow or impossible | Designed for it; indexes make lookups fast |
| Stop bad data (e.g., negative price) | Easy to type anything | **Constraints** reject invalid data |
| Recover after a crash | Maybe | Transaction log guarantees committed data survives |
| Control who sees what | Whole file or nothing | Permissions down to individual rows and columns |

## Tables, rows and columns

A **relational database** stores data in **tables**.

`Customers` table:

| CustomerID | FirstName | Email | Country |
|---|---|---|---|
| 1 | Asha | asha@example.com | India |
| 2 | Ben | ben@example.com | UK |

- A **column** describes one attribute (e.g., `Email`). Every column has a **data type** such as `int`, `nvarchar(100)` (text), `date`, or `decimal(10,2)`.
- A **row** is one record — one customer.
- A **schema** (like `dbo` or `Sales`) is a folder that groups tables and other objects. A table's full name is `schema.table`, e.g., `Sales.Customers`.

## What is SQL? What is T-SQL?

**SQL** (Structured Query Language) is the standard language for working with relational databases.

**T-SQL** (Transact-SQL) is Microsoft's dialect of SQL. It adds variables, error handling, procedural logic and many functions. DP-800 is a **T-SQL exam**.

SQL statements fall into families:

| Family | Purpose | Examples |
|---|---|---|
| **DQL** — query | Read data | `SELECT` |
| **DML** — manipulate | Change rows | `INSERT`, `UPDATE`, `DELETE`, `MERGE` |
| **DDL** — define | Create/change objects | `CREATE TABLE`, `ALTER TABLE`, `DROP` |
| **DCL** — control | Permissions | `GRANT`, `DENY`, `REVOKE` |
| **TCL** — transactions | Group changes safely | `BEGIN TRAN`, `COMMIT`, `ROLLBACK` |

## Transactions in one paragraph

A **transaction** is a group of changes that succeed or fail **together**. Moving money between two accounts must debit one and credit the other — never just one. Databases guarantee the **ACID** properties:

- **Atomicity** — all or nothing.
- **Consistency** — rules (constraints) are never broken.
- **Isolation** — concurrent transactions don't see each other's half-finished work.
- **Durability** — once committed, the change survives a crash.

You will go deeper in *Domain 2 → Transactions and Concurrency*.

## Structured vs semi-structured vs unstructured data

| Type | Example | How SQL handles it |
|---|---|---|
| **Structured** | Order table with fixed columns | Normal tables and columns |
| **Semi-structured** | JSON product attributes that vary per product | `json` data type and JSON functions |
| **Unstructured** | Product manuals, support tickets | Store as text; make it searchable with **full-text search** or **embeddings + vector search** |

The exam expects you to design for **all three** — that is why JSON and vectors appear in it.

## Knowledge check

1. What is the difference between a row and a column?
2. Which statement family does `GRANT` belong to?
3. Which ACID property guarantees a committed order survives a power failure?
4. A product catalog where each product has different attributes is an example of what kind of data?

<details>
<summary>Answers</summary>

1. A column is one attribute shared by all records; a row is one record.
2. DCL (Data Control Language).
3. Durability.
4. Semi-structured data — a good fit for a JSON column.
</details>
