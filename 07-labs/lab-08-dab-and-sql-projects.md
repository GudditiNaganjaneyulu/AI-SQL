# Lab 8 — Data API Builder and SQL Database Projects

**Goal:** put the lab schema under source control as an SDK-style SQL project, build a `.dacpac`, deploy it, detect drift, and expose the data through Data API builder (REST, GraphQL, MCP). Finish with a Copilot instruction file.

**Requirements:** .NET 8 SDK or later, VS Code with the **SQL Database Projects** extension, the DAB CLI (`dotnet tool install --global Microsoft.DataApiBuilder`), `SqlPackage` (`dotnet tool install --global microsoft.sqlpackage`), Git, and a GitHub account (Part D).

## Part A — Create a project from the existing database

1. In VS Code: **Database Projects** view → **Create Project from Database** → choose `DP800Lab` → SDK-style project → folder `database/DP800Lab`.
   (Alternative: `sqlpackage /Action:Extract /SourceConnectionString:"…" /TargetFile:DP800Lab.dacpac`, then create the project from the dacpac.)
2. Inspect the generated files: one `.sql` file per object, organized by schema and type.
3. Open the `.sqlproj` file and note the `Sdk="Microsoft.Build.Sql/…"` attribute and the `<DSP>` target platform.

## Part B — Build, change, and deploy

4. Build:

```bash
dotnet build database/DP800Lab/DP800Lab.sqlproj
```

5. Introduce an error on purpose: in a view file, reference a column that doesn't exist. Build again and read the error. Undo it.
6. Make a real change: add a nullable column `LoyaltyTier nvarchar(20) NULL` to `Sales/Tables/Customers.sql` **by editing the CREATE TABLE statement** (don't write an ALTER).
7. Add reference data in a **post-deployment script** (`Scripts/PostDeployment.sql`, set its build action to PostDeploy):

```sql
IF OBJECT_ID(N'Sales.LoyaltyTiers') IS NOT NULL
MERGE Sales.LoyaltyTiers AS t
USING (VALUES (N'Bronze', 0), (N'Silver', 500), (N'Gold', 2000)) AS s (Tier, MinSpend)
   ON t.Tier = s.Tier
WHEN MATCHED THEN UPDATE SET MinSpend = s.MinSpend
WHEN NOT MATCHED BY TARGET THEN INSERT (Tier, MinSpend) VALUES (s.Tier, s.MinSpend);
```

(Also add a `Sales/Tables/LoyaltyTiers.sql` file: `CREATE TABLE Sales.LoyaltyTiers (Tier nvarchar(20) NOT NULL PRIMARY KEY, MinSpend decimal(10,2) NOT NULL);`)

8. Rebuild, then **generate a report** before deploying:

```bash
sqlpackage /Action:DeployReport \
  /SourceFile:database/DP800Lab/bin/Debug/DP800Lab.dacpac \
  /TargetConnectionString:"<your DP800Lab connection string>" \
  /OutputPath:deployreport.xml
```

9. Publish:

```bash
sqlpackage /Action:Publish \
  /SourceFile:database/DP800Lab/bin/Debug/DP800Lab.dacpac \
  /TargetConnectionString:"<your DP800Lab connection string>"
```

Verify the new column and the three loyalty tiers exist.

## Part C — Detect schema drift

10. Directly in the database (simulating a hotfix): `CREATE INDEX IX_Customers_Country ON Sales.Customers (Country);`
11. Run the **DeployReport** again. The report shows the project would **drop** that index — that is drift.
12. Decide: add the index to the project (keep it) **or** republish (remove it). Use **Schema Compare** in VS Code to view the difference visually.

## Part D — CI with GitHub Actions

13. Commit the project to a GitHub repository.
14. Add `.github/workflows/database-ci.yml` that builds the project on every pull request (use the workflow from *Domain 2 → SQL Database Projects and CI/CD*; you can omit the deploy job).
15. Protect `main`: require a pull request and a passing build. Add `.github/CODEOWNERS` with `/database/ @<your-github-username>`.
16. Open a PR that changes a view and watch the check run.

## Part E — Data API builder

17. Initialize and add entities (run in a new folder):

```bash
export SQL_CONNECTION_STRING="Server=tcp:<server>.database.windows.net,1433;Database=DP800Lab;Authentication=Active Directory Default;Encrypt=True;"

dab init --database-type mssql --connection-string "@env('SQL_CONNECTION_STRING')" --host-mode development

dab add Product  --source Sales.Products  --permissions "anonymous:read" --rest products --graphql "product:products"
dab add Customer --source Sales.Customers --permissions "anonymous:read" --fields.exclude "Email,Phone"
dab add Order    --source Sales.Orders    --permissions "anonymous:read"

dab update Customer --relationship orders   --target.entity Order    --cardinality many --relationship.fields "CustomerID:CustomerID"
dab update Order    --relationship customer --target.entity Customer --cardinality one  --relationship.fields "CustomerID:CustomerID"

dab update Product --cache.enabled true --cache.ttl-seconds 60
```

(On Windows `cmd`, use `set SQL_CONNECTION_STRING=...`. For SQL Server in Docker, use a SQL login connection string for this lab only.)

18. Start it: `dab start`, then try:

```
GET  http://localhost:5000/api/products?$filter=Category eq 'Camping'&$orderby=Price desc&$first=3
GET  http://localhost:5000/api/products?$select=Name,Price&$first=5
```

Follow the `nextLink` in the response to page through results.

19. Open `http://localhost:5000/graphql` and run:

```graphql
query {
  customers(filter: { Country: { eq: "India" } }) {
    items { FirstName LastName orders { items { OrderID Status } } }
  }
}
```

20. Expose the stored procedure from Lab 2 (if you created it):

```bash
dab add PlaceOrder --source Sales.usp_PlaceOrder --source.type stored-procedure \
  --permissions "authenticated:execute" --rest.methods "POST" --graphql.operation mutation
```

Notice that `authenticated` callers are required — anonymous users can't place orders.

21. Security review — answer in your notes:
    - Why are `Email` and `Phone` excluded from `Customer`?
    - What would you change for production? (Production host mode, Entra ID auth, managed identity connection, no anonymous access to customers, CORS, introspection off.)

## Part F — Copilot instruction file and MCP

22. In your repository, add `.github/copilot-instructions.md` with your SQL conventions (see the example in *Domain 1 → AI-Assisted Development*).
23. With DAB running (version with MCP support), add `.vscode/mcp.json` pointing to `http://localhost:5000/mcp`, open Copilot Chat in **Agent** mode, enable only the DAB tools, and ask: *"List the three most expensive camping products."* Observe which tool calls the agent makes.
24. Discuss: which DAB role should the agent's MCP connection use, and why should it not have write permissions?
