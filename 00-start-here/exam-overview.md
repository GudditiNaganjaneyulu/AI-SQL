# About the DP-800 Exam

> Source: Microsoft Learn — [Study guide for Exam DP-800](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-800). Always re-check this page before you book; Microsoft updates the skills outline periodically. This guide follows the **skills measured as of October 19, 2026**.

## The essentials

| Item | Detail |
|---|---|
| Exam code | **DP-800** |
| Exam title | **Developing AI-Enabled Database Solutions** |
| Passing score | **700** (on a scale of 1–1000) |
| Platforms covered | Microsoft SQL Server, Azure SQL, and SQL database in Microsoft Fabric |
| Renewal | Associate-level certifications expire annually and are renewed with a free online assessment on Microsoft Learn |
| Practice | Microsoft offers a free practice assessment and an exam sandbox — links are on the study guide page |

## Who the exam is for

The audience profile says you should be able to:

- Design and develop database solutions with **structured and semi-structured** (JSON) data.
- **Integrate AI features** into scalable enterprise applications.
- **Secure, optimize, and deploy** database solutions.
- **Implement AI capabilities** inside the database (embeddings, vector search, RAG).

It also expects familiarity with **T-SQL**, **CI/CD in GitHub**, **AI-assisted development tools** (GitHub Copilot, Copilot in Fabric), and **AI concepts** such as embeddings, vectors, and models.

## Skills measured and where to learn them

### Domain 1 — Design and develop database solutions (35–40%)

| Objective | Chapter in this guide |
|---|---|
| Design and implement database objects (tables, data types, indexes, columnstore, specialized tables, JSON columns/indexes, constraints, SEQUENCES, partitioning) | Domain 1 → chapters 1–5 |
| Implement programmability objects (views, scalar functions, table-valued functions, stored procedures, triggers) | Domain 1 → chapter 6 |
| Write advanced T-SQL (CTEs, window functions, JSON functions, regular expressions, fuzzy matching, graph MATCH, correlated queries, error handling) | Domain 1 → chapter 7 (+ Core T-SQL for correlated queries) |
| Design and implement SQL solutions by using AI-assisted tools (security impact, GitHub Copilot, Copilot in Fabric, model/MCP options, instruction files, MCP endpoints) | Domain 1 → chapter 8 |

### Domain 2 — Secure, optimize, and deploy database solutions (35–40%)

| Objective | Chapter in this guide |
|---|---|
| Implement data security and compliance (Always Encrypted, column encryption, Dynamic Data Masking, RLS, permissions, passwordless access, auditing, Managed Identity for model endpoints, securing GraphQL/REST/MCP endpoints) | Domain 2 → chapters 1–2 |
| Optimize database performance (configuration, isolation levels, execution plans, DMVs, Query Store, Query Performance Insight, blocking, deadlocks) | Domain 2 → chapters 3–4 |
| Implement CI/CD by using SQL Database Projects (testing, reference data, SDK-style projects, source control, branching/PRs, secrets, schema drift, deployment controls) | Domain 2 → chapter 5 |
| Integrate SQL solutions with Azure services (Data API builder, REST/GraphQL, Azure Monitor, CES, CDC, Change Tracking, Azure Functions SQL trigger, Logic Apps) | Domain 2 → chapters 6–7 |

### Domain 3 — Implement AI capabilities in database solutions (25–30%)

| Objective | Chapter in this guide |
|---|---|
| Design and implement models and embeddings (evaluate models, external models, embedding maintenance, column selection, chunking, generating embeddings) | Domain 3 → chapters 1–3 |
| Design and implement intelligent search (full-text, vector, hybrid, vector data type and indexes, VECTOR_* functions, ANN vs KNN, RRF, performance) | Domain 3 → chapters 4–5 |
| Design and implement RAG (use cases, `sp_invoke_external_rest_endpoint`, converting data to JSON, sending to and extracting from a language model) | Domain 3 → chapter 6 |

## What changed on October 19, 2026

Microsoft lists **minor** changes to: *Design and implement database objects*, *AI-assisted tools*, *Models and embeddings*, and *Intelligent search*. This guide follows the new outline.

## Important mindset

The exam tests **choosing the right tool for a scenario**, not just syntax. For every feature in this guide, learn:

1. **What problem it solves.**
2. **When to choose it over the alternatives.**
3. **Its key limitations.**
