# Securing Endpoints and Identities

> **Objective:** *Secure model endpoints, including Managed Identity; secure GraphQL, REST, and MCP endpoints.*

Modern AI database solutions talk in **two directions**:

```
Outbound:  SQL ──► AI model endpoints (embeddings, chat)   via EXTERNAL MODEL / sp_invoke_external_rest_endpoint
Inbound:   Apps / agents ──► SQL data                      via REST, GraphQL, MCP (Data API builder)
```

Both must be secured.

## Outbound: securing model endpoints

### Credentials live in DATABASE SCOPED CREDENTIALs

Never put API keys in code. T-SQL calls to external endpoints authenticate through a **database scoped credential** whose **name is the endpoint URL** (protocol + host, optionally a path prefix).

```sql
-- A database master key protects credential secrets
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'<strong password>';
```

| `IDENTITY` value | How auth is sent | Recommendation |
|---|---|---|
| `'Managed Identity'` | Entra token from the SQL server's managed identity | **Preferred — no secret to store or rotate** |
| `'HTTPEndpointHeaders'` | Secret JSON added as HTTP headers (e.g., `{"api-key":"..."}`) | Acceptable when MI isn't possible |
| `'HTTPEndpointQueryString'` | Secret added to the query string | Avoid when possible |
| `'Shared Access Signature'` | SAS token | Storage scenarios |

### Managed identity to Azure OpenAI / Microsoft Foundry

1. **Enable a managed identity** on the Azure SQL logical server (system- or user-assigned). On SQL Server 2025, connect the server to **Azure Arc** and enable its managed identity, then `sp_configure 'allow server scoped db credentials', 1`.
2. **Grant an Azure RBAC role** on the AI resource to that identity — for inference, **Cognitive Services OpenAI User**.
3. **Create the credential and external model:**

```sql
CREATE DATABASE SCOPED CREDENTIAL [https://contoso-ai.openai.azure.com]
    WITH IDENTITY = 'Managed Identity',
         SECRET   = '{"resourceid":"https://cognitiveservices.azure.com"}';

CREATE EXTERNAL MODEL EmbeddingModel
WITH (
    LOCATION   = 'https://contoso-ai.openai.azure.com/openai/deployments/text-embedding-3-small/embeddings?api-version=2024-02-01',
    API_FORMAT = 'Azure OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL      = 'text-embedding-3-small',
    CREDENTIAL = [https://contoso-ai.openai.azure.com]
);
```

### Database permissions for outbound calls

```sql
GRANT EXECUTE ANY EXTERNAL ENDPOINT TO [rag-app];                     -- sp_invoke_external_rest_endpoint
GRANT EXECUTE ON EXTERNAL MODEL::EmbeddingModel TO [rag-app];           -- AI_GENERATE_EMBEDDINGS
GRANT REFERENCES ON DATABASE SCOPED CREDENTIAL::[https://contoso-ai.openai.azure.com] TO [rag-app];
```

### Network controls for outbound calls

- Azure SQL Database/MI only allow calls to an **allow-list** of Azure service domains (Azure OpenAI, Azure AI services, Functions, Event Hubs, Storage, Key Vault, API Management, …). To reach anything else, front it with **API Management**.
- **Outbound firewall rules** restrict outbound calls to specific FQDNs.
- Only **HTTPS/TLS** endpoints are allowed.

> **Data exfiltration risk:** `sp_invoke_external_rest_endpoint` can send data out of the database. Restrict who can run it (`EXECUTE ANY EXTERNAL ENDPOINT`), restrict where it can go (outbound firewall), and audit its use.

## Inbound: securing REST, GraphQL and MCP endpoints

Most DP-800 inbound scenarios use **Data API builder (DAB)**, which can expose the same entities over **REST**, **GraphQL** and **MCP**. Security layers:

### 1. Authenticate callers

DAB `runtime.host.authentication.provider` options include:

| Provider | Use |
|---|---|
| **Microsoft Entra ID / custom JWT** | Production — validates bearer tokens (issuer + audience) |
| **App Service (EasyAuth)** | DAB hosted behind App Service / Static Web Apps authentication |
| **Simulator** | Local development only |
| Unauthenticated | DAB behind a trusted front end that handles identity |

### 2. Authorize per entity, per role, per action

```json
"permissions": [
  { "role": "anonymous",     "actions": [ "read" ] },
  { "role": "authenticated", "actions": [
      { "action": "read" },
      { "action": "update", "fields": { "exclude": [ "CreditLimit" ] } }
  ] },
  { "role": "customer", "actions": [
      { "action": "read", "policy": { "database": "@item.CustomerID eq @claims.customer_id" } }
  ] }
]
```

- **Roles** come from token claims (`X-MS-API-ROLE` header selects among a user's roles).
- **Field-level** include/exclude.
- **Database policies** add row filters using claims.
- DAB can pass claims into **`SESSION_CONTEXT`**, so **RLS** in the database enforces rows even if the API config is wrong — defense in depth.

### 3. Connect DAB to SQL with least privilege

- DAB's connection uses a **managed identity** (`Authentication=Active Directory Default`) with only the permissions its entities need.
- Store the connection string in an environment variable (`@env('SQL_CONN')`) or **Azure Key Vault** — never in the committed config.

### 4. Protect the transport and surface

- HTTPS only; restrict CORS origins.
- Disable endpoints you don't need (`"rest": { "enabled": false }`, GraphQL introspection off in production).
- Production **host mode** (`"mode": "production"`) hides developer tools.
- Network isolation: private endpoints, API Management in front for rate limiting and keys.

### 5. MCP endpoints — extra care

An MCP endpoint lets **AI agents** call your data as tools:

- Expose **only** the entities/tools the agent needs (`mcp.dml-tools: false` on sensitive entities; publish curated **stored procedures** as custom tools instead of raw table DML).
- Use **read-only roles** for agent identities.
- Require authentication — never anonymous write access.
- Remember **prompt injection**: an agent may be tricked into calling tools; permissions are your real control.

## Scenario practice

| Requirement | Answer |
|---|---|
| Call Azure OpenAI from T-SQL without storing any key | Managed identity credential + `Cognitive Services OpenAI User` role |
| Only the `rag-app` user may call external endpoints | `GRANT EXECUTE ANY EXTERNAL ENDPOINT TO [rag-app]` only |
| GraphQL API: customers see only their own orders | DAB database policy with claims **and/or** RLS using session context |
| AI agent should read products but never modify | DAB MCP with read-only role; disable DML tools for writes |

## Knowledge check

1. What must the name of a database scoped credential used for REST calls match?
2. Which Azure role lets a managed identity call Azure OpenAI for inference?
3. What permission is needed to run `sp_invoke_external_rest_endpoint`?
4. Name two ways DAB can restrict which rows a caller sees.

<details>
<summary>Answers</summary>

1. The endpoint URL (protocol + FQDN, and path prefix) being called.
2. Cognitive Services OpenAI User.
3. `EXECUTE ANY EXTERNAL ENDPOINT`.
4. Database policies on permissions (using claims) and Row-Level Security via session context.
</details>
