# Data API Builder

> **Objective:** *Create configuration files for Data API builder (DAB); configure entities for REST and GraphQL, including data caching, pagination, searching, and filtering; configure REST or GraphQL endpoints; expose database objects, stored procedures, and views, including GraphQL relationships; configure and implement DAB deployment.*

## What DAB is

**Data API builder** is a free, open-source engine that turns database objects into **REST**, **GraphQL** and (v1.7+) **MCP** endpoints from **one JSON configuration file** — no custom API code. It supports SQL Server, Azure SQL, PostgreSQL, MySQL and Cosmos DB.

```
dab-config.json  ──►  DAB runtime (container/App Service)  ──►  /api/...   (REST)
                                                          ──►  /graphql  (GraphQL)
                                                          ──►  /mcp      (MCP tools for agents)
```

Install the CLI:

```bash
dotnet tool install --global Microsoft.DataApiBuilder
```

## 1. Create the configuration file

```bash
dab init --database-type mssql \
         --connection-string "@env('SQL_CONNECTION_STRING')" \
         --host-mode development
```

`@env('…')` reads the connection string from an environment variable so **no secret is stored in the file**. Use a passwordless string, e.g. `Server=…;Database=DP800Lab;Authentication=Active Directory Default;`.

The generated `dab-config.json` has three main sections:

```json
{
  "$schema": "https://github.com/Azure/data-api-builder/releases/latest/download/dab.draft.schema.json",
  "data-source": { "database-type": "mssql", "connection-string": "@env('SQL_CONNECTION_STRING')" },
  "runtime": {
    "rest":    { "enabled": true, "path": "/api" },
    "graphql": { "enabled": true, "path": "/graphql", "allow-introspection": true },
    "host":    { "mode": "development",
                 "cors": { "origins": [], "allow-credentials": false },
                 "authentication": { "provider": "StaticWebApps" } }
  },
  "entities": { }
}
```

## 2. Add entities

### A table

```bash
dab add Product \
  --source Sales.Products \
  --source.type table \
  --permissions "anonymous:read" \
  --rest products \
  --graphql "product:products"
```

Resulting entity:

```json
"Product": {
  "source":  { "type": "table", "object": "Sales.Products" },
  "rest":    { "enabled": true, "path": "/products" },
  "graphql": { "enabled": true, "type": { "singular": "product", "plural": "products" } },
  "permissions": [ { "role": "anonymous", "actions": [ { "action": "read" } ] } ]
}
```

### A view (needs key fields)

```bash
dab add OrderSummary \
  --source Sales.vOrderSummary \
  --source.type view \
  --source.key-fields "OrderID" \
  --permissions "authenticated:read"
```

### A stored procedure

```bash
dab add PlaceOrder \
  --source Sales.usp_PlaceOrder \
  --source.type stored-procedure \
  --permissions "authenticated:execute" \
  --rest.methods "POST" \
  --graphql.operation mutation
```

Procedures exposed this way are ideal **curated operations** for apps and agents (including as **MCP custom tools** with `--mcp.custom-tool true`).

### More permissions

`--permissions` takes one role per command; add more with `dab update`:

```bash
dab update Product --permissions "authenticated:create,read,update,delete"
dab update Product --permissions "anonymous:read" --fields.exclude "Cost"
dab update Product --permissions "authenticated:read" --policy-database "@item.Discontinued eq false"
```

## 3. Relationships (GraphQL)

```bash
dab add Customer --source Sales.Customers --permissions "authenticated:read"
dab add Order    --source Sales.Orders    --permissions "authenticated:read"

dab update Customer \
  --relationship orders \
  --target.entity Order \
  --cardinality many \
  --relationship.fields "CustomerID:CustomerID"

dab update Order \
  --relationship customer \
  --target.entity Customer \
  --cardinality one \
  --relationship.fields "CustomerID:CustomerID"
```

Now one GraphQL request navigates the relationship:

```graphql
query {
  customers(filter: { Country: { eq: "India" } }, first: 5) {
    items {
      FirstName
      LastName
      orders { items { OrderID OrderDate Status } }
    }
  }
}
```

Many-to-many relationships use `--linking.object` (the junction table).

## 4. Querying: filtering, sorting, paging, selecting

### REST (OData-like query string)

```http
GET /api/products?$select=ProductID,Name,Price
GET /api/products?$filter=Category eq 'Camping' and Price lt 100
GET /api/products?$orderby=Price desc
GET /api/products?$first=10
GET /api/products?$first=10&$after=<continuation token from previous response>
GET /api/products/ProductID/7
```

Responses contain `value` (rows) and, when more rows exist, `nextLink` for the next page. **Pagination is cursor-based** (`$after`), with a default and maximum page size set in `runtime.pagination`.

### GraphQL

```graphql
query {
  products(
    filter: { and: [ { Category: { eq: "Camping" } }, { Price: { lt: 100 } } ] }
    orderBy: { Price: DESC }
    first: 10
    after: null
  ) {
    items { ProductID Name Price }
    hasNextPage
    endCursor
  }
}
```

Searching uses filter operators such as `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `contains`, `notContains`, `startsWith`, `endsWith`, `isNull`, combined with `and` / `or`.

## 5. Caching

```bash
dab update Product --cache.enabled true --cache.ttl-seconds 60
```

Runtime-level cache must also be on:

```json
"runtime": { "cache": { "enabled": true, "ttl-seconds": 30 } }
```

Caching reduces database load for frequently read, rarely changed data (product catalogs). Choose short TTLs for data that changes often.

## 6. Configure endpoints

| Setting | Example |
|---|---|
| Change base paths | `"rest": { "path": "/data" }`, `"graphql": { "path": "/gql" }` |
| Disable REST or GraphQL globally | `"rest": { "enabled": false }` |
| Disable per entity | `"rest": false` in the entity |
| Custom REST route per entity | `--rest products` |
| Turn off GraphQL introspection in prod | `"allow-introspection": false` |
| Production host mode | `"host": { "mode": "production" }` |
| Authentication | `"authentication": { "provider": "AzureAD", "jwt": { "audience": "...", "issuer": "..." } }` |

Run locally:

```bash
dab validate     # check config against the database
dab start
```

Swagger UI is available at `/swagger` and a GraphQL IDE at `/graphql` in development mode.

## 7. Deploy DAB

DAB is a **stateless container** (`mcr.microsoft.com/azure-databases/data-api-builder`). Common hosts:

| Host | Notes |
|---|---|
| **Azure Container Apps** | Most common; scale to zero; managed identity for SQL; mount config or bake it into a custom image |
| **Azure App Service (Web App for Containers)** | Easy auth integration |
| **Azure Static Web Apps database connections** | Hosts a DAB-based API alongside a static front end |
| **AKS / Container Instances / on-prem** | When you need full control |

Deployment checklist:

1. Store `dab-config.json` in **source control**; promote it through CI/CD like code.
2. Supply the connection string through an **environment variable / Key Vault**.
3. Use a **managed identity** for the DAB → SQL connection with least privilege.
4. Set `"mode": "production"`, restrict CORS, enable Entra/JWT auth.
5. Send telemetry to **Application Insights** (see next chapter).

## Knowledge check

1. What CLI command creates a new DAB configuration file?
2. What must you specify when exposing a view?
3. How does DAB paginate results?
4. How do you keep the connection string out of `dab-config.json`?
5. Which option makes a stored procedure appear as a GraphQL query instead of a mutation?

<details>
<summary>Answers</summary>

1. `dab init`.
2. Key fields (`--source.key-fields`), because views have no primary key.
3. Cursor-based: `$first` + `$after` (REST) / `first` + `after` with `endCursor` (GraphQL).
4. Use `@env('VAR_NAME')` (and Key Vault/app settings to supply the value).
5. `--graphql.operation query`.
</details>
