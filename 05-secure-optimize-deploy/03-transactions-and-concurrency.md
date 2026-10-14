# Transactions and Concurrency

> **Objective:** *Preserve data integrity and consistency by using transaction isolation levels and concurrency controls.*

## The problem

Many sessions read and write the same data at once. Without control you get:

| Phenomenon | What happens |
|---|---|
| **Dirty read** | You read another transaction's **uncommitted** change, which is later rolled back |
| **Non-repeatable read** | You read a row twice in one transaction and get different values |
| **Phantom read** | You run the same range query twice and new rows appear |
| **Lost update** | Two sessions read, both update; one overwrites the other |

## Isolation levels

| Level | Dirty reads | Non-repeatable | Phantoms | How it works |
|---|---|---|---|---|
| `READ UNCOMMITTED` | ✔ possible | ✔ | ✔ | No shared locks (same as `NOLOCK`) |
| `READ COMMITTED` (locking) | ✘ | ✔ | ✔ | Shared locks released after each read |
| **`READ COMMITTED SNAPSHOT` (RCSI)** | ✘ | ✔ | ✔ | Readers see the last committed version; **readers don't block writers** |
| `REPEATABLE READ` | ✘ | ✘ | ✔ | Shared locks held to end of transaction |
| `SNAPSHOT` | ✘ | ✘ | ✘ | Whole transaction sees a consistent snapshot; **update conflicts** raise error 3960 |
| `SERIALIZABLE` | ✘ | ✘ | ✘ | Range locks; most blocking |

```sql
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRAN;
    SELECT SUM(Quantity) FROM Sales.OrderLines;   -- consistent view for the whole transaction
COMMIT;
```

### Row versioning: RCSI and SNAPSHOT

- **RCSI** changes the behaviour of the default `READ COMMITTED` level — no code change. **Enabled by default in Azure SQL Database** and SQL database in Fabric.
- **SNAPSHOT** must be allowed (`ALTER DATABASE … SET ALLOW_SNAPSHOT_ISOLATION ON`) and requested per transaction.
- Both keep row versions (in tempdb, or in the database's persistent version store with **Accelerated Database Recovery**).

```sql
ALTER DATABASE CURRENT SET READ_COMMITTED_SNAPSHOT ON;   -- SQL Server (on by default in Azure SQL DB)
ALTER DATABASE CURRENT SET ALLOW_SNAPSHOT_ISOLATION ON;
```

> **Exam tip:** "Reports block order entry" → enable **RCSI** (or use SNAPSHOT for reports). "Must never see phantom rows and must not block readers" → **SNAPSHOT**. "Absolute correctness for a range check, blocking acceptable" → **SERIALIZABLE**.

## Locks in brief

| Lock | Taken by | Compatible with |
|---|---|---|
| Shared (S) | Reads (under locking isolation) | Other S |
| Update (U) | Reading a row you intend to update | S, but not other U |
| Exclusive (X) | Writes | Nothing |
| Intent (IS, IX) | On higher levels (page/table) to signal row locks below | — |

**Lock escalation:** many row locks may escalate to a table lock to save memory — can increase blocking.

### Optimized locking

On Azure SQL Database, SQL database in Fabric, and SQL Server 2025, **optimized locking** (built on Accelerated Database Recovery) reduces lock memory and blocking:

- **Transaction ID (TID) locking:** a transaction holds one lock on its TID instead of many row locks.
- **Lock after qualification (LAQ):** with RCSI, rows are evaluated against the predicate on the latest committed version before taking locks.

## Concurrency control patterns

### Pessimistic: lock what you'll update

```sql
BEGIN TRAN;
SELECT Quantity FROM Inventory.Stock WITH (UPDLOCK, HOLDLOCK) WHERE ProductID = 7;
UPDATE Inventory.Stock SET Quantity -= 1 WHERE ProductID = 7;
COMMIT;
```

### Optimistic: detect conflicts with `rowversion`

```sql
ALTER TABLE Sales.Products ADD RowVer rowversion;

-- App read ProductID 7 with RowVer = 0x00000000000007D3
UPDATE Sales.Products
SET Price = 59.99
WHERE ProductID = 7 AND RowVer = 0x00000000000007D3;

IF @@ROWCOUNT = 0 THROW 50010, 'Row was changed by another user. Reload and retry.', 1;
```

### Queue processing without blocking

```sql
-- Each worker grabs a different job
SELECT TOP (1) JobID
FROM dbo.Jobs WITH (UPDLOCK, READPAST, ROWLOCK)
WHERE Status = N'Pending'
ORDER BY JobID;
```

Useful for **embedding-generation queues**.

### Application locks

`sp_getapplock` / `sp_releaseapplock` lock a **name** rather than data — e.g., to ensure only one job regenerates embeddings at a time.

## Keep transactions short

Long transactions hold locks and version store space. Never wait for user input — **or an external HTTP call to an AI model** — inside a transaction that holds locks.

## Knowledge check

1. Which isolation level is the default behaviour in Azure SQL Database?
2. Which level prevents phantoms without blocking readers?
3. What error indicates an update conflict under SNAPSHOT?
4. Which table hint lets workers skip locked rows?

<details>
<summary>Answers</summary>

1. READ COMMITTED with **RCSI** enabled (row versioning).
2. SNAPSHOT.
3. Error 3960.
4. `READPAST`.
</details>
