# Data Security and Compliance

> **Objective:** *Design and implement data encryption, including Always Encrypted and column-level encryption; Dynamic Data Masking; Row-Level Security (RLS); object-level permissions; secure database access, including passwordless; auditing.*

## Defense in depth — the layers

```
Network      → firewall, private endpoints
Identity     → Microsoft Entra ID, managed identities, MFA
Permissions  → roles, GRANT/DENY, schemas, ownership chaining
Rows         → Row-Level Security
Columns      → Dynamic Data Masking, column permissions
Data         → TDE (at rest), TLS (in transit), Always Encrypted (in use)
Monitoring   → Auditing, Microsoft Defender for SQL
```

The exam often asks you to pick **the one feature** that meets a requirement. Learn the **"who can see plaintext?"** column below.

| Feature | Protects | Who can see plaintext? | App changes? |
|---|---|---|---|
| **TDE** (Transparent Data Encryption) | Data files & backups at rest | Anyone with database access | None (on by default in Azure SQL) |
| **TLS** | Data in transit | Endpoints | `Encrypt=True` |
| **Column-level encryption** (`ENCRYPTBYKEY`) | Selected columns, in the database | Users who can open the key | SQL code changes |
| **Always Encrypted** | Selected columns, **even from DBAs/cloud operators** | **Only the client app holding the key** | Driver setting + key access |
| **Dynamic Data Masking** | Display of values | Users with `UNMASK` | None — **not encryption** |
| **Row-Level Security** | Which rows a user sees | Rows matching the predicate | None (uses session context) |

## Always Encrypted

Data is encrypted **in the client driver** before it reaches SQL — the database engine only ever sees ciphertext.

- **Column Master Key (CMK)** — stored outside the database (e.g., **Azure Key Vault**); protects…
- **Column Encryption Key (CEK)** — stored encrypted in the database; encrypts the data.

| Encryption type | Same input → | Allows | Use for |
|---|---|---|---|
| **Deterministic** | same ciphertext | Equality lookups, joins, GROUP BY, indexes | Values you search by exact match (e.g., national ID) |
| **Randomized** | different ciphertext | Nothing (without enclaves) | Most sensitive, never-queried values |

**Secure enclaves** (Always Encrypted with secure enclaves) allow richer operations — pattern matching, range comparisons, in-place encryption — inside a protected memory region.

```sql
CREATE TABLE HR.EmployeeSecrets
(
    EmployeeID int PRIMARY KEY,
    NationalID char(11) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (COLUMN_ENCRYPTION_KEY = CEK_HR,
                        ENCRYPTION_TYPE = DETERMINISTIC,
                        ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256') NOT NULL,
    Salary decimal(10,2)
        ENCRYPTED WITH (COLUMN_ENCRYPTION_KEY = CEK_HR,
                        ENCRYPTION_TYPE = RANDOMIZED,
                        ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256') NOT NULL
);
```

Keys are normally provisioned with SSMS or PowerShell; apps add `Column Encryption Setting=Enabled` to the connection string. Deterministic encryption on strings requires a **BIN2** collation. The `vector` type isn't supported with Always Encrypted.

## Column-level encryption (cell-level, server-side)

```sql
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<strong password>';
CREATE CERTIFICATE CertPII WITH SUBJECT = 'PII protection';
CREATE SYMMETRIC KEY KeyPII WITH ALGORITHM = AES_256 ENCRYPTION BY CERTIFICATE CertPII;

OPEN SYMMETRIC KEY KeyPII DECRYPTION BY CERTIFICATE CertPII;
UPDATE HR.Contacts SET PhoneEnc = ENCRYPTBYKEY(KEY_GUID('KeyPII'), Phone);
SELECT CONVERT(varchar(20), DECRYPTBYKEY(PhoneEnc)) AS Phone FROM HR.Contacts;
CLOSE SYMMETRIC KEY KeyPII;
```

The **server** can decrypt, so DBAs with key access can read data — weaker than Always Encrypted, but flexible.

## Dynamic Data Masking (DDM)

Masks values **in query results** for users without `UNMASK`. Data is stored unchanged.

```sql
ALTER TABLE Sales.Customers ALTER COLUMN Email
    ADD MASKED WITH (FUNCTION = 'email()');                  -- aXXX@XXXX.com

ALTER TABLE Sales.Customers ALTER COLUMN Phone
    ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XXX-",4)');  -- XXX-XXX-4567

ALTER TABLE HR.Employees ALTER COLUMN Salary
    ADD MASKED WITH (FUNCTION = 'default()');                -- 0 for numbers, XXXX for strings

ALTER TABLE HR.Employees ALTER COLUMN Bonus
    ADD MASKED WITH (FUNCTION = 'random(1, 100)');

GRANT UNMASK TO SupportManagers;                           -- database-wide
GRANT UNMASK ON SCHEMA::HR TO HRManagers;                  -- granular (schema/table/column)
```

> **DDM is not a security boundary.** A user with ad-hoc query rights can infer values with `WHERE Salary > 100000`. Combine with permissions; use Always Encrypted for true confidentiality.

## Row-Level Security (RLS)

RLS filters rows **inside the engine** based on who is asking. Two parts: an **inline TVF predicate** and a **security policy**.

```sql
CREATE SCHEMA Security;
GO
CREATE OR ALTER FUNCTION Security.fn_CustomerFilter (@CustomerID int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS allowed
    WHERE @CustomerID = CAST(SESSION_CONTEXT(N'CustomerID') AS int)   -- set by the app
       OR IS_MEMBER(N'SupportAgents') = 1;                            -- or a privileged role
GO

CREATE SECURITY POLICY Security.CustomerOrdersPolicy
    ADD FILTER PREDICATE Security.fn_CustomerFilter(CustomerID) ON Sales.Orders,
    ADD BLOCK  PREDICATE Security.fn_CustomerFilter(CustomerID) ON Sales.Orders AFTER INSERT
WITH (STATE = ON);
```

The application sets context after connecting:

```sql
EXEC sp_set_session_context @key = N'CustomerID', @value = 42, @read_only = 1;
SELECT * FROM Sales.Orders;   -- only customer 42's orders
```

| Predicate | Effect |
|---|---|
| **FILTER** | Silently hides rows from SELECT/UPDATE/DELETE |
| **BLOCK** (`AFTER INSERT`, `AFTER UPDATE`, `BEFORE UPDATE`, `BEFORE DELETE`) | Prevents writes that violate the predicate |

Typical uses: **multi-tenant** SaaS (`TenantID`), sales reps see only their region, customers see only their orders. RLS also applies to queries generated by **Data API builder** and **AI agents** — a strong control for AI apps.

## Object-level permissions

```sql
-- Roles group permissions
CREATE ROLE SalesReader;
GRANT SELECT ON SCHEMA::Sales TO SalesReader;            -- schema-level grant
DENY  SELECT ON Sales.Customers (Email) TO SalesReader;  -- column-level deny
ALTER ROLE SalesReader ADD MEMBER [DP800-Analysts];      -- an Entra group

-- Apps get EXECUTE only
CREATE ROLE AppExecutor;
GRANT EXECUTE ON SCHEMA::Sales TO AppExecutor;
```

| Statement | Meaning |
|---|---|
| `GRANT` | Allow |
| `DENY` | Explicitly forbid — **overrides GRANT** (except for owners/sysadmin) |
| `REVOKE` | Remove a previous GRANT or DENY |

Key concepts:

- **Least privilege:** grant the minimum; prefer roles and schema-level grants.
- **Fixed database roles:** `db_datareader`, `db_datawriter`, `db_ddladmin`, `db_owner` — convenient but broad.
- **Ownership chaining:** if a procedure and the tables it uses have the same owner, callers need only `EXECUTE` on the procedure.
- **`EXECUTE AS`:** run a module under another identity (use carefully).
- **Special permissions you'll meet:** `EXECUTE ANY EXTERNAL ENDPOINT` (for `sp_invoke_external_rest_endpoint`), `EXECUTE ON EXTERNAL MODEL::name`, `REFERENCES ON DATABASE SCOPED CREDENTIAL::name`, `UNMASK`.

## Secure (passwordless) access

Covered in *Azure SQL Platform → Connecting and Authenticating*. Summary:

- Use **Microsoft Entra ID**; enable **Microsoft Entra-only authentication**.
- Apps use **managed identities** (`CREATE USER [app-name] FROM EXTERNAL PROVIDER`).
- People are added through **Entra groups**.
- CI/CD uses **workload identity federation (OIDC)** instead of stored secrets.

## Auditing

### Azure SQL auditing

Configured at the **server** (applies to all databases) or **database** level, writing to:

- **Azure Storage** (long retention, cheap),
- **Log Analytics** (query with KQL, alerts, workbooks),
- **Event Hubs** (stream to a SIEM).

Default audit action groups capture successful/failed logins and all batches. Audit logs include who, what statement, when, from where.

### SQL Server Audit (on-prem / VM / Managed Instance)

```sql
CREATE SERVER AUDIT AuditToFile TO FILE (FILEPATH = 'C:\Audit\');
ALTER SERVER AUDIT AuditToFile WITH (STATE = ON);

CREATE DATABASE AUDIT SPECIFICATION AuditPII
FOR SERVER AUDIT AuditToFile
    ADD (SELECT ON HR.EmployeeSecrets BY public)
WITH (STATE = ON);
```

Related tools: **ledger tables** (tamper evidence), **Microsoft Defender for SQL** (vulnerability assessment, threat detection such as SQL injection alerts), **data discovery & classification** (label sensitive columns; labels appear in audit logs).

## Scenario practice

| Requirement | Feature |
|---|---|
| Cloud operators and DBAs must never see credit-card numbers | **Always Encrypted** |
| Support staff see only the last 4 digits of phone numbers | **Dynamic Data Masking** `partial()` |
| Each tenant sees only its own rows in a shared table | **Row-Level Security** |
| Prove who read the salary table last month | **Auditing** |
| Encrypt backups and data files with no app change | **TDE** (default on Azure SQL) |
| App must not store any password | **Managed identity + Entra auth** |

## Knowledge check

1. Which Always Encrypted type supports equality lookups?
2. Is DDM a replacement for encryption?
3. What two objects make up RLS?
4. Which wins: GRANT or DENY?

<details>
<summary>Answers</summary>

1. Deterministic.
2. No — it only masks query output; data is stored in plaintext and can be inferred.
3. An inline table-valued predicate function and a security policy.
4. DENY.
</details>
