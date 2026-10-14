# The SQL Platform Family

> **Why this matters:** many DP-800 features are **generally available on one platform and preview on another**. Scenario questions expect you to know which platform fits.

## One engine, many deployments

All of these run the **SQL Database Engine** and speak T-SQL:

| Platform | Model | You get | Typical use |
|---|---|---|---|
| **SQL Server 2025** | On-premises / any VM / containers | Full control of the instance and OS | Existing on-prem estates, strict data residency, edge |
| **SQL Server on Azure VM** | IaaS | SQL Server in Azure with OS access | Lift-and-shift needing OS-level features |
| **Azure SQL Managed Instance** | PaaS (instance) | Near-100% SQL Server compatibility: SQL Agent, cross-database queries, CLR, Service Broker | Migrating SQL Server apps with minimal change |
| **Azure SQL Database** | PaaS (database) | A single database (or elastic pool) fully managed; newest features first | New cloud-native apps, SaaS, AI apps |
| **SQL database in Microsoft Fabric** | SaaS | Azure SQL Database engine inside Fabric; data auto-replicated to OneLake | Operational apps that feed Fabric analytics |

## Where new features land first

Microsoft usually ships new engine features to **Azure SQL Database** and **SQL database in Fabric** first, then to **Managed Instance (Always-up-to-date policy)**, then to **SQL Server**.

Examples relevant to DP-800 (status as documented on Microsoft Learn at the time of writing):

| Feature | Azure SQL DB / Fabric SQL | SQL Server 2025 |
|---|---|---|
| `vector` data type | GA | GA |
| Vector index + `VECTOR_SEARCH` | **GA** | **Preview** (needs `PREVIEW_FEATURES = ON`) |
| `float16` vectors | GA | Preview |
| `CREATE EXTERNAL MODEL`, `AI_GENERATE_EMBEDDINGS` | Available | Available |
| `sp_invoke_external_rest_endpoint` | **Enabled by default** | Disabled by default — enable with `sp_configure 'external rest endpoint enabled', 1` |
| `EDIT_DISTANCE` and fuzzy matching | Preview | Preview |
| Change event streaming | Preview | Preview |

> Feature status changes often. When a question names a platform, think "is this GA there, or does it need a preview switch?"

## Azure SQL Managed Instance update policies

Managed Instance lets you choose how fast new engine features arrive:

| Update policy | Engine features | Why choose it |
|---|---|---|
| **SQL Server 2022** | Match SQL Server 2022 | Must be able to restore back to SQL Server 2022 |
| **SQL Server 2025** | Match SQL Server 2025 | Compatibility with SQL Server 2025 |
| **Always-up-to-date** | Newest features as soon as they ship | Want the latest features (e.g., GA vector indexes, external models) |

## Compatibility level

Each database has a **compatibility level** that controls some T-SQL behaviours. SQL Server 2025 introduces level **170**. Some new functions — for example `AI_GENERATE_CHUNKS` — require compatibility level **170** or higher.

```sql
SELECT name, compatibility_level FROM sys.databases;
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 170;
```

## Choosing a platform — decision guide

1. **Need OS access or unsupported features?** → SQL Server on Azure VM (or on-prem).
2. **Migrating an existing SQL Server app that uses SQL Agent, cross-database queries, or CLR?** → Managed Instance.
3. **Building a new cloud app or AI app?** → Azure SQL Database.
4. **Operational database whose data should flow straight into Fabric analytics/Power BI?** → SQL database in Fabric.

## Knowledge check

1. Which platform gives near-full SQL Server compatibility as PaaS?
2. On SQL Server 2025, what must you do before creating a vector index?
3. Which Managed Instance update policy gets new features first?

<details>
<summary>Answers</summary>

1. Azure SQL Managed Instance.
2. Enable preview features: `ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;`
3. Always-up-to-date.
</details>
