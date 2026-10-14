# SQL Database Projects and CI/CD

> **Objective:** *Implement CI/CD by using SQL Database Projects — testing strategy; reference/static data in source control; create, build and validate database models including SDK-style; source control; branching, pull requests and conflict resolution; secrets management; schema drift; update and deploy; controls for deployment pipelines (branching policies, triggers, approvals, code owners).*

## The idea: database as code

A **SQL Database Project** is a folder of `.sql` files that **declare** the desired state of every object (`CREATE TABLE …`, `CREATE PROCEDURE …`), plus a project file.

```
build  ──►  .dacpac  (a compiled model of the database)
publish ──►  compares .dacpac to the target and generates the ALTER script automatically
```

You never hand-write `ALTER TABLE` migration scripts for schema — you edit the `CREATE` statement and the tooling computes the difference.

## SDK-style projects (Microsoft.Build.Sql)

The modern format, based on .NET SDK projects. It's the format used by the **SQL Database Projects extension for VS Code** and by **SQL database in Fabric** source control.

```bash
dotnet new install Microsoft.Build.Sql.Templates
dotnet new sqlproj -n ContosoDb
```

`ContosoDb/ContosoDb.sqlproj`:

```xml
<Project Sdk="Microsoft.Build.Sql/1.0.0">
  <PropertyGroup>
    <Name>ContosoDb</Name>
    <!-- Target platform: Azure SQL Database -->
    <DSP>Microsoft.Data.Tools.Schema.Sql.SqlAzureV12DatabaseSchemaProvider</DSP>
    <ModelCollation>1033, CI</ModelCollation>
    <RunSqlCodeAnalysis>true</RunSqlCodeAnalysis>
  </PropertyGroup>
</Project>
```

Advantages over the original (`.NET Framework`) format: cross-platform `dotnet build`, `.sql` files included by default (globbing), **NuGet package references** for database references.

Typical layout:

```
ContosoDb/
├── ContosoDb.sqlproj
├── Sales/Tables/Customers.sql
├── Sales/Tables/Orders.sql
├── Sales/Views/vOrderSummary.sql
├── Sales/StoredProcedures/usp_PlaceOrder.sql
├── Security/Roles.sql
└── Scripts/
    ├── PreDeployment.sql
    └── PostDeployment.sql      ← reference data
```

## Build and validate

```bash
dotnet build ContosoDb/ContosoDb.sqlproj
# output: ContosoDb/bin/Debug/ContosoDb.dacpac
```

The build **validates**:

- Syntax against the **target platform** (e.g., using a SQL Server 2025 function in a project targeting an older version fails).
- **References** between objects (a view referencing a missing column fails).
- **Code analysis** rules (warnings such as `SELECT *`, if enabled).

Create a project from an existing database: **extract** with VS Code (*Create Project from Database*) or `sqlpackage /Action:Extract /p:ExtractTarget=Flat`.

## Publish (deploy)

```bash
sqlpackage /Action:Publish \
  /SourceFile:ContosoDb/bin/Debug/ContosoDb.dacpac \
  /TargetConnectionString:"Server=tcp:contoso.database.windows.net;Database=ContosoDb;Authentication=Active Directory Default;" \
  /p:BlockOnPossibleDataLoss=true
```

Useful options/actions:

| Action / property | Purpose |
|---|---|
| `/Action:Script` | Generate the deployment script without running it (review in a PR) |
| `/Action:DeployReport` | XML report of changes that **would** be made |
| `/p:BlockOnPossibleDataLoss=true` | Stop if a change could lose data (default true) |
| `/p:DropObjectsNotInSource` | Remove objects not in the project (use carefully) |

## Reference / static data in source control

Lookup data (countries, order statuses) belongs in source control too. Use an **idempotent `MERGE`** in the **post-deployment script**:

```sql
-- Scripts/PostDeployment.sql
MERGE Sales.OrderStatus AS t
USING (VALUES (1, N'New'), (2, N'Paid'), (3, N'Shipped'), (4, N'Cancelled')) AS s (StatusID, Name)
    ON t.StatusID = s.StatusID
WHEN MATCHED AND t.Name <> s.Name THEN UPDATE SET Name = s.Name
WHEN NOT MATCHED BY TARGET THEN INSERT (StatusID, Name) VALUES (s.StatusID, s.Name)
WHEN NOT MATCHED BY SOURCE THEN DELETE;
```

Idempotent = safe to run on every deployment.

## Testing strategy

| Test type | What it checks | How |
|---|---|---|
| **Build validation** | Syntax and references | `dotnet build` on every PR |
| **Code analysis** | Anti-patterns | `RunSqlCodeAnalysis` |
| **Unit tests** | One procedure/function in isolation | e.g., **tSQLt** framework (fake tables, assert results) |
| **Integration tests** | Deployed database + app behaviour | Deploy the dacpac to an ephemeral database (e.g., a SQL Server container in the pipeline), run tests |
| **Deployment report review** | Unexpected destructive changes | `DeployReport` / `Script` artifact in the PR |

## Source control, branching and pull requests

- Store the project in **Git (GitHub)**.
- Use a branching model such as **feature branches → pull request → main**.
- **Pull requests** trigger CI (build + tests) and require review.
- **Merge conflicts** in declarative `.sql` files are resolved like code conflicts: keep the intended final definition of the object, rebuild to validate.
- **SQL database in Fabric** can sync with a Git repo (Azure DevOps or GitHub) through workspace Git integration.

## Secrets management

- **Never** commit connection strings with passwords.
- GitHub Actions: authenticate to Azure with **OpenID Connect (workload identity federation)** — no client secret stored; store non-secret IDs as variables, any unavoidable secrets as **GitHub encrypted secrets** (environment-scoped).
- Read runtime secrets from **Azure Key Vault**.
- The deploying identity should be an **Entra service principal or managed identity** with only the permissions needed to deploy (e.g., `db_ddladmin` + data permissions for post-deploy scripts — not `sysadmin`).

## Schema drift

**Drift** = the live database no longer matches source control (someone ran a hotfix directly in production).

Detect it by comparing the project with the target:

- **Schema compare** (VS Code / Visual Studio) between the project and the database.
- `sqlpackage /Action:DeployReport` against production — any unexpected changes mean drift.
- `sqlpackage /Action:DriftReport` for databases registered as data-tier applications.

Then either **bring the change into the project** (if it should stay) or **redeploy** to remove it.

## A GitHub Actions pipeline

```yaml
name: database-ci-cd
on:
  pull_request:
    branches: [ main ]
    paths: [ 'database/**' ]
  push:
    branches: [ main ]
    paths: [ 'database/**' ]

permissions:
  id-token: write     # for OIDC login to Azure
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '8.0.x' }
      - run: dotnet build database/ContosoDb/ContosoDb.sqlproj -c Release
      - uses: actions/upload-artifact@v4
        with:
          name: dacpac
          path: database/ContosoDb/bin/Release/ContosoDb.dacpac

  deploy-prod:
    if: github.event_name == 'push'
    needs: build
    runs-on: ubuntu-latest
    environment: production          # environment with required reviewers = approval gate
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
      - uses: azure/sql-action@v2
        with:
          connection-string: ${{ vars.SQL_CONNECTION_STRING }}   # uses Entra auth, contains no password
          path: database/ContosoDb/ContosoDb.sqlproj
          action: publish
          arguments: '/p:BlockOnPossibleDataLoss=true'
```

## Deployment pipeline controls

| Control | Where | Purpose |
|---|---|---|
| **Branch protection / rulesets** | GitHub repo settings | Require PRs, passing status checks, and reviews before merging to `main`; block force-pushes |
| **CODEOWNERS** | `.github/CODEOWNERS` | Automatically request review from the DBA team for `database/**` |
| **Triggers** | Workflow `on:` (PR, push, paths, manual `workflow_dispatch`) | Run the right jobs at the right time |
| **Environments + required reviewers** | GitHub environments | Manual **approval** before production deployment; environment-scoped secrets |
| **Least-privilege deploy identity** | Entra + database roles | Limits blast radius |

`.github/CODEOWNERS` example:

```
/database/  @contoso/dba-team
```

## Knowledge check

1. What does building a SQL Database Project produce?
2. Where should reference data loading go?
3. How do you detect that production has changes not in source control?
4. Which GitHub feature requires a human approval before the production job runs?
5. How does GitHub Actions authenticate to Azure without storing a client secret?

<details>
<summary>Answers</summary>

1. A `.dacpac` file.
2. An idempotent `MERGE` in the post-deployment script.
3. Schema compare / `DeployReport` (or `DriftReport`) against production — schema drift detection.
4. An **environment** with required reviewers.
5. OpenID Connect (workload identity federation) via `azure/login`.
</details>
