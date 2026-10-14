# Hands-on Labs

Reading builds understanding; **labs build skill**. Each lab matches a stage of the study roadmap.

| Lab | Do it after | Needs | Time |
|---|---|---|---|
| [Lab 0 — Create the Lab Database](lab-00-setup.md) | Start Here → Set up your environment | Any database option | 20 min |
| [Lab 1 — Core Queries](lab-01-core-queries.md) | Core T-SQL | Lab 0 | 60–90 min |
| [Lab 2 — Schema and Programmability](lab-02-schema-and-programmability.md) | Domain 1 → chapters 1–6 | Lab 0 | 90 min |
| [Lab 3 — Security](lab-03-security.md) | Domain 2 → Data Security | Lab 0 | 60 min |
| [Lab 4 — Performance](lab-04-performance.md) | Domain 2 → Concurrency and Query Performance | Lab 0 | 60 min |
| [Lab 5 — JSON, Regex and Fuzzy Matching](lab-05-json-regex-fuzzy.md) | Domain 1 → JSON and Advanced T-SQL | Lab 0; compatibility level 170 | 60 min |
| [Lab 6 — Vector Search](lab-06-vector-search.md) | Domain 3 → Vector Search | Lab 0; **no AI account needed** | 60 min |
| [Lab 7 — RAG End to End](lab-07-rag-end-to-end.md) | Domain 3 → RAG | Azure SQL DB + Azure OpenAI deployment | 90 min |
| [Lab 8 — Data API Builder and SQL Projects](lab-08-dab-and-sql-projects.md) | Domain 2 → CI/CD and DAB | .NET SDK, DAB CLI, GitHub | 90–120 min |
| [Troubleshooting](troubleshooting.md) | Whenever something fails | — | — |

## How to work through a lab

1. Read the **goal** and **you will learn** sections.
2. Type the code — don't paste blindly. Predict the result before running.
3. Complete the **challenges** without looking at the solutions.
4. Compare with the **solutions** (collapsed sections).
5. Write down anything that surprised you — those notes become your revision material.

## The lab database

`setup/create-lab-database.sql` creates the `Sales` and `HR` schemas used throughout this guide. It is safe to re-run; it drops and recreates the lab tables.
