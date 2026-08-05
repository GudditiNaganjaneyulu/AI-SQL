# Microsoft Certified: SQL AI Developer Associate
## Master Preparation Roadmap

---

## About the Certification

**Exam:** DP-080 / AI-102 hybrid focus (SQL + AI workloads on Azure)
**Target Role:** Developer building AI-powered applications backed by Azure SQL and Azure OpenAI
**Prerequisites:** Basic SQL knowledge, familiarity with cloud concepts

---

## Exam Domain Breakdown

| Domain | Weight | Module |
|--------|--------|--------|
| SQL Fundamentals & Query Writing | ~20% | Module 1 |
| Advanced SQL, Performance & Optimization | ~20% | Module 2 |
| AI Integration — Vectors, Embeddings, OpenAI | ~30% | Module 3 |
| Azure SQL Platform & Cloud Features | ~30% | Module 4 |

---

## Study Timeline (8 Weeks)

### Week 1–2: SQL Fundamentals
- DDL / DML / DCL / TCL
- JOINs, subqueries, aggregations
- Window functions
- Indexes and query plans
- **Lab:** Build the sample schema on Neon DB

### Week 3–4: Advanced SQL & Optimization
- CTEs, recursive queries
- Query execution plans (EXPLAIN ANALYZE)
- Index strategies (B-Tree, GIN, BRIN)
- Partitioning and sharding concepts
- Transactions, isolation levels, locking
- **Lab:** Optimize slow queries, design indexes

### Week 5–6: AI Integration with SQL
- What are vector embeddings?
- pgvector extension in PostgreSQL
- Azure OpenAI API — embeddings + completions
- Semantic search with cosine similarity
- RAG (Retrieval-Augmented Generation) pattern
- Storing and querying embeddings in SQL
- **Lab:** Build a semantic search engine on Neon

### Week 7: Azure SQL Platform
- Azure SQL Database vs Managed Instance vs SQL Edge
- Elastic pools, serverless tier
- Always Encrypted, TDE, Row-Level Security
- Azure AI integration (Cognitive Services, Azure ML)
- Copilot for Azure SQL
- Azure SQL Ledger
- **Lab:** Configure security features, use Azure AI services

### Week 8: Review + Mock Exams
- Full mock exam (50 questions)
- Weak area revision
- Real-world project walkthrough
- Interview Q&A practice

---

## Directory Structure

```
AI-SQL/
├── ROADMAP.md                  ← You are here
├── db details                  ← Neon DB connection string
├── modules/
│   ├── 01-sql-fundamentals/
│   │   ├── README.md
│   │   └── exercises/
│   ├── 02-advanced-sql/
│   │   ├── README.md
│   │   └── exercises/
│   ├── 03-ai-integration/
│   │   ├── README.md
│   │   └── exercises/
│   └── 04-azure-sql/
│       ├── README.md
│       └── exercises/
├── labs/
│   ├── setup/                  ← DB setup scripts
│   └── solutions/              ← Lab answer scripts
├── mock-interviews/
│   └── 50-questions.md
├── projects/
│   └── project-briefs.md
└── cheatsheets/
    ├── sql-quick-ref.md
    └── ai-concepts.md
```

---

## Your Neon DB

- **Host:** ep-fancy-night-at61q8bl-pooler.c-9.us-east-1.aws.neon.tech
- **Database:** AISQL
- **Region:** us-east-1

Connect via psql:
```bash
psql "postgresql://neondb_owner:<password>@ep-fancy-night-at61q8bl-pooler.c-9.us-east-1.aws.neon.tech/AISQL?sslmode=require"
```

---

## Key Resources

- [Microsoft Learn — Azure SQL](https://learn.microsoft.com/en-us/azure/azure-sql/)
- [pgvector GitHub](https://github.com/pgvector/pgvector)
- [Azure OpenAI Documentation](https://learn.microsoft.com/en-us/azure/ai-services/openai/)
- [PostgreSQL EXPLAIN docs](https://www.postgresql.org/docs/current/using-explain.html)
- [Neon Documentation](https://neon.tech/docs)

---

## Progress Tracker

- [ ] Module 1: SQL Fundamentals
- [ ] Module 2: Advanced SQL
- [ ] Module 3: AI Integration
- [ ] Module 4: Azure SQL
- [ ] Labs completed
- [ ] Mock exam scored ≥ 80%
- [ ] Projects built
- [ ] Interview ready
