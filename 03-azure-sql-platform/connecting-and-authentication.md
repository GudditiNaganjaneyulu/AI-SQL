# Connecting and Authenticating

> **Why this matters:** *"Implement secure database access, including passwordless"* is an explicit objective. Every app, pipeline and AI agent you build must connect somehow.

## Authentication vs authorization

- **Authentication** — *who are you?* (login)
- **Authorization** — *what may you do?* (permissions, covered in Domain 2)

## Authentication options

| Method | How it works | Recommendation |
|---|---|---|
| **SQL authentication** | Username + password stored in the database server | Avoid for apps — passwords leak and must be rotated |
| **Microsoft Entra ID — user** | A person signs in with their Entra account (MFA supported) | Use for people and tools (SSMS, VS Code) |
| **Microsoft Entra ID — managed identity** | Azure gives a resource (App Service, Function, Container App, the SQL server itself) an identity; tokens are issued automatically | **Best choice for apps — passwordless** |
| **Microsoft Entra ID — service principal** | An app registration with a secret or certificate | Use when a managed identity is not possible (e.g., outside Azure); prefer **workload identity federation** for GitHub Actions |

### Microsoft Entra-only authentication

Azure SQL can **disable SQL authentication entirely** (*Microsoft Entra-only authentication*). This is the strongest posture and is a likely "most secure option" answer.

## Creating database users for Entra identities

Connect as the Entra admin, then:

```sql
-- A person
CREATE USER [asha@contoso.com] FROM EXTERNAL PROVIDER;

-- A group (preferred: manage membership in Entra, not in SQL)
CREATE USER [DP800-Developers] FROM EXTERNAL PROVIDER;

-- An app's managed identity (use the resource's name)
CREATE USER [contoso-orders-api] FROM EXTERNAL PROVIDER;

-- Grant least privilege
ALTER ROLE db_datareader ADD MEMBER [contoso-orders-api];
GRANT EXECUTE ON SCHEMA::Sales TO [contoso-orders-api];
```

These are **contained database users** — they live in the database, with no server login required.

## Connection strings

**Passwordless (managed identity / developer credentials) — .NET `Microsoft.Data.SqlClient`:**

```
Server=tcp:<server>.database.windows.net,1433;Database=DP800Lab;
Authentication=Active Directory Default;Encrypt=True;
```

`Active Directory Default` tries, in order, environment credentials, managed identity, and developer sign-ins (Visual Studio, Azure CLI…). The same string works on your laptop and in Azure.

**SQL authentication (avoid in production):**

```
Server=tcp:<server>.database.windows.net,1433;Database=DP800Lab;
User ID=<user>;Password=<password>;Encrypt=True;
```

If you must use secrets, store them in **Azure Key Vault** or your CI system's secret store — never in source control.

## Network security

| Control | Purpose |
|---|---|
| **Server firewall rules** | Allow specific public IP ranges |
| **Private endpoint** | Give the database a private IP inside your virtual network; disable public access |
| **TLS encryption** | `Encrypt=True` — all Azure SQL connections are encrypted in transit |
| **Outbound firewall rules** | Restrict which external endpoints the database can call (relevant for `sp_invoke_external_rest_endpoint`) |

## Knowledge check

1. What is the most secure way for an Azure Function to connect to Azure SQL Database?
2. Which T-SQL clause creates a database user for a Microsoft Entra identity?
3. What does Microsoft Entra-only authentication disable?

<details>
<summary>Answers</summary>

1. A managed identity with Microsoft Entra authentication (passwordless).
2. `CREATE USER [name] FROM EXTERNAL PROVIDER`.
3. SQL authentication (username/password logins).
</details>
