# Cloud Concepts for Database Developers

> **Why this matters:** DP-800 spans SQL Server (you manage it), Azure SQL (Microsoft manages it), and Fabric (fully SaaS). Scenario questions often hinge on **who is responsible for what**.

## Service models

| Model | You manage | Provider manages | SQL example |
|---|---|---|---|
| **On-premises** | Everything | Nothing | SQL Server on your own hardware |
| **IaaS** (Infrastructure as a Service) | OS, SQL Server, patching, backups | Hardware, networking | **SQL Server on Azure VM** |
| **PaaS** (Platform as a Service) | Your schema, data, queries, security config | OS, engine patching, backups, high availability | **Azure SQL Database**, **Azure SQL Managed Instance** |
| **SaaS** (Software as a Service) | Your data and how you use it | Almost everything | **SQL database in Microsoft Fabric** |

Rule of thumb: **the further down the table, the less you operate and the less you can customize.**

## Regions and availability

- An **Azure region** is a set of datacenters in one geography (e.g., *East US*, *Central India*).
- **Availability zones** are physically separate datacenters within a region. Zone-redundant databases survive a datacenter failure.
- **Geo-replication / failover groups** copy a database to another region for disaster recovery.

## Identity: Microsoft Entra ID

**Microsoft Entra ID** (formerly Azure Active Directory) is Microsoft's cloud identity service. It authenticates:

- **Users** — people signing in.
- **Groups** — collections of users (grant permissions to groups, not individuals).
- **Service principals** — identities for applications.
- **Managed identities** — identities that Azure creates and rotates for a resource (a web app, a Function, or the SQL server itself). **No password or secret is stored anywhere.**

> **Exam tip:** "passwordless" in DP-800 almost always means **Microsoft Entra authentication**, usually with a **managed identity**. Prefer it over SQL logins with passwords.

## Cost models (basic vocabulary)

| Term | Meaning |
|---|---|
| **Provisioned** | You pay for a fixed size whether you use it or not |
| **Serverless** | Compute scales automatically and can pause when idle; you pay per second of use |
| **vCore** | Pricing based on virtual CPU cores you choose |
| **DTU** | Older bundled measure of CPU + memory + I/O |
| **Capacity (Fabric)** | A pool of compute units shared by all Fabric items in a workspace |

## Infrastructure as Code and DevOps (preview of later topics)

- **Source control** (Git/GitHub) stores your database code, not just application code.
- **CI** (Continuous Integration) automatically builds and tests every change.
- **CD** (Continuous Deployment/Delivery) automatically deploys approved changes.

DP-800 tests this through **SQL Database Projects** and **GitHub** workflows (Domain 2).

## Knowledge check

1. Who patches the operating system for Azure SQL Database?
2. Which service model is SQL database in Microsoft Fabric?
3. What kind of identity lets an Azure Function connect to Azure SQL without storing a password?

<details>
<summary>Answers</summary>

1. Microsoft (it's PaaS).
2. SaaS.
3. A managed identity (authenticated through Microsoft Entra ID).
</details>
