# Troubleshooting

## Connection problems

| Error / symptom | Cause | Fix |
|---|---|---|
| `Cannot open server … Client with IP address … is not allowed` | Azure SQL firewall | Add your client IP on the server's **Networking** page |
| `Login failed for user '<token-identified principal>'` | Entra user has no database user | Connect as the Entra admin and run `CREATE USER [name] FROM EXTERNAL PROVIDER` |
| Connection works in SSMS but not in an app | Wrong authentication mode in the connection string | Use `Authentication=Active Directory Default` and sign in with `az login` locally |
| Docker container stops immediately | Weak SA password or not enough memory | `docker logs <name>`; use a strong password; give Docker ≥ 2 GB RAM |

## Script errors

| Error | Cause | Fix |
|---|---|---|
| `Invalid object name 'Sales.Products'` | Connected to `master` or another database | Switch to `DP800Lab` |
| `'GENERATE_SERIES' is not a recognized built-in function name` | Compatibility level below 160 | `ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 170;` (or 160) |
| `REGEXP_LIKE` not recognized | Compatibility level below 170 | Set level 170 |
| `AI_GENERATE_CHUNKS` not found | Compatibility level below 170 | Set level 170 |
| `Column, parameter, or variable … Cannot find data type json` | Platform without the native `json` type | Use `nvarchar(max)` with `CHECK (ISJSON(col) = 1)` |
| Fuzzy functions not recognized / preview error | Preview features disabled (SQL Server 2025) | `ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;` |
| Collation error with fuzzy functions | Non-binary `SQL_*` collation | Add `COLLATE Latin1_General_100_CI_AS` to the arguments |

## Vector and AI errors

| Error | Cause | Fix |
|---|---|---|
| Msg 42266 when creating a vector index | Fewer than 100 non-NULL vectors | Load more rows, or use exact search (`VECTOR_DISTANCE`) |
| Msg 42274 (`TOP_N`) | Old `TOP_N` syntax against a latest-version index | Use `SELECT TOP (N) WITH APPROXIMATE` |
| Msg 42248 / 42271 | `WITH APPROXIMATE` without `ORDER BY distance`, or extra/desc sort columns | `ORDER BY r.distance` only, ascending; use a subquery for other operations |
| Vector index created but not used | Query metric differs from index metric | Use the same metric |
| `sp_invoke_external_rest_endpoint` disabled | SQL Server default | `EXEC sp_configure 'external rest endpoint enabled', 1; RECONFIGURE WITH OVERRIDE;` |
| HTTP 401/403 from the model | Managed identity lacks *Cognitive Services OpenAI User*, or credential name mismatch | Fix the role assignment; credential name = endpoint URL prefix |
| HTTP 429 | Rate limit | `retry_count`, smaller batches, more quota |
| Answer column is NULL | `JSON_VALUE` > 4,000 chars | Use `OPENJSON … WITH (answer nvarchar(max) '$.message.content')` |

## Tooling

| Problem | Fix |
|---|---|
| `dotnet build` can't find `Microsoft.Build.Sql` | Check internet access to NuGet; verify the SDK version in the `.sqlproj` |
| `dab start` fails to connect | Check the environment variable name in `@env('…')`; test the connection string in VS Code |
| DAB view entity error | Views need `--source.key-fields` |
| GitHub Actions can't log in to Azure | Federated credential subject must match the repo/branch/environment; workflow needs `permissions: id-token: write` |

## Still stuck?

1. Read the **full** error message — the first line is often not the root cause.
2. Re-run the smallest failing statement on its own.
3. Search the error number on Microsoft Learn.
4. Check the feature's **availability on your platform** (*Azure SQL Platform → The SQL Platform Family*).
