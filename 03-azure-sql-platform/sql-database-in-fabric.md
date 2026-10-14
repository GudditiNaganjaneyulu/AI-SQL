# SQL Database in Microsoft Fabric

> **Why this matters:** the exam names **SQL databases in Microsoft Fabric** as a target platform, and **Copilot in Fabric** appears in the AI-assisted tools objective.

## What is Microsoft Fabric?

**Microsoft Fabric** is a SaaS analytics platform: data engineering, data warehousing, real-time analytics, data science, and Power BI in one product. All Fabric data lands in **OneLake**, a single logical data lake.

## What is SQL database in Fabric?

An **operational (OLTP) SQL database** created inside a Fabric workspace. Key points:

- Built on the **same engine as Azure SQL Database** — your T-SQL skills transfer directly.
- **SaaS:** no servers, tiers, or patching to manage; it uses the workspace's **Fabric capacity**.
- Data is **automatically replicated to OneLake** in near real time (as Delta tables), so analysts can use it from lakehouses, warehouses, notebooks and Power BI **without building ETL**.
- Supports **source control integration** with Git, which matters for CI/CD.
- Supports AI features such as the `vector` type, vector search, and external models (see the platform table in *The SQL Platform Family*).

## When to choose it

| Choose SQL database in Fabric when… | Choose Azure SQL Database when… |
|---|---|
| Your organization already runs on Fabric | You need fine-grained control of tiers, networking, HA |
| You want operational data instantly available for analytics | You need features not yet available in Fabric |
| You want a simple, SaaS developer experience | Your app is outside the Fabric ecosystem |

## Copilot in Fabric (preview of Domain 1, chapter 8)

The Fabric SQL query editor includes **Copilot** for:

- Code completion as you type T-SQL.
- A chat pane to ask questions, generate queries and explain or fix code.

Copilot in Fabric needs a supported **paid Fabric capacity** and must be **enabled by a Fabric administrator** in the tenant settings. Details and the security implications are covered in *Domain 1 → AI-Assisted Development*.

## Connecting

SQL database in Fabric uses **Microsoft Entra ID authentication only**. You connect from SSMS or VS Code with the connection string shown in the Fabric portal, or from the built-in web query editor.

## Knowledge check

1. Where does data from a SQL database in Fabric get replicated automatically?
2. What authentication does SQL database in Fabric support?
3. Name one prerequisite for using Copilot in Fabric.

<details>
<summary>Answers</summary>

1. OneLake.
2. Microsoft Entra ID.
3. A supported paid Fabric capacity, and the tenant setting enabled by an administrator.
</details>
