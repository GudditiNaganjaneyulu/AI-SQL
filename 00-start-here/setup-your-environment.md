# Set Up Your Environment

You need **somewhere to run T-SQL** and **a tool to write it in**. Pick one database option below; you can add others later.

## Step 1 — Choose a database

| Option | Cost | Best for | Notes |
|---|---|---|---|
| **A. Azure SQL Database (free offer)** | Free monthly allowance | Most of this guide, including AI features | Newest features (vector index GA, AI functions) arrive here first. Requires an Azure account. |
| **B. SQL Server 2025 in Docker** | Free (Developer edition) | Working offline; Linux/macOS/Windows | Some vector/AI features are **preview** on SQL Server 2025 and need `PREVIEW_FEATURES` enabled. |
| **C. SQL database in Microsoft Fabric** | Needs a Fabric capacity or trial | Fabric-specific objectives (Copilot in Fabric, Git integration) | Optional; useful later in your studies. |

> **Recommendation for beginners:** start with **Option A**. It needs no installation and matches the newest exam features. Use **Option B** as well if you want to practise offline.

### Option A — Azure SQL Database free offer

1. Create a free Azure account at <https://azure.microsoft.com/free>.
2. In the Azure portal, search **SQL databases** → **Create**.
3. Look for the banner **"Want to try Azure SQL Database for free?"** and select **Apply offer**.
4. Create a new **logical server**. Under **Authentication**, choose **Use Microsoft Entra-only authentication** and set yourself as the admin — this is the *passwordless* approach the exam favours.
5. Under **Networking**, allow your client IP address.
6. Name the database `DP800Lab`.

> Free-offer limits (vCore-seconds and storage per month) change over time — check the portal for the current values.

### Option B — SQL Server 2025 in Docker

Install Docker Desktop, then run:

```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=<YourStrong!Passw0rd>" \
  -p 1433:1433 --name sql2025 -d mcr.microsoft.com/mssql/server:2025-latest
```

Connect to `localhost,1433` with user `sa` and the password you chose. **Never use `sa` in real applications** — it is acceptable only for a local learning container.

To use preview features (vector indexes, some AI functions) in a database:

```sql
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
```

## Step 2 — Install a query tool

| Tool | Platform | Why |
|---|---|---|
| **VS Code + MSSQL extension** | Windows, macOS, Linux | Integrates with **GitHub Copilot** and **SQL Database Projects** — both are exam topics |
| **SQL Server Management Studio (SSMS) 21+** | Windows | Richest graphical tool; execution plans, Query Store reports |

Install **VS Code**, then from the Extensions view install:

- **SQL Server (mssql)**
- **SQL Database Projects**
- **GitHub Copilot** and **GitHub Copilot Chat** (a free tier is available)

## Step 3 — Other tools you will use later

| Tool | Used in | Install |
|---|---|---|
| **.NET 8 SDK or later** | SQL Database Projects build | <https://dotnet.microsoft.com/download> |
| **Data API builder CLI** | Domain 2 → Data API builder | `dotnet tool install --global Microsoft.DataApiBuilder` |
| **Git + a GitHub account** | CI/CD chapter | <https://git-scm.com> |
| **Azure OpenAI / Microsoft Foundry resource** | Domain 3 labs that call real models | Created in the Azure portal; optional until Lab 7 |

## Step 4 — Check that everything works

Connect to your database and run:

```sql
SELECT @@VERSION AS server_version,
       DB_NAME()  AS current_database,
       SYSDATETIME() AS server_time;
```

If you see one row with three values, you are ready. Continue to **Lab 0** in Hands-on Labs to create the sample database used throughout this guide.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| "Cannot open server … client with IP address … is not allowed" | Azure SQL firewall | Add your IP under the server's **Networking** blade |
| Login failed with Entra ID | Not set as Entra admin, or wrong tenant | Check **Microsoft Entra ID** blade on the logical server |
| Docker container exits immediately | Weak `MSSQL_SA_PASSWORD` | Use 8+ chars with upper, lower, digit and symbol; check `docker logs sql2025` |
| `Invalid object name` | Wrong database selected | Run `USE DP800Lab;` (SQL Server) or pick the database in the connection |
