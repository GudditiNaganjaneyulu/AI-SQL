# Real-World Projects — SQL AI Developer

Complete these projects to build portfolio-ready work and solidify every exam topic.

---

## Project 1: E-Commerce Analytics Dashboard
**Covers:** Module 1 & 2 — SQL Fundamentals, Advanced SQL, Optimization
**Estimated time:** 3–4 hours

### Objective
Build a complete analytics backend for the e-commerce sample database.

### Requirements
1. **Sales Report Query** — monthly revenue, order count, avg order value, MoM growth %
2. **Customer Segmentation** — classify users as VIP (>3 orders), Regular (1–3), New (0)
3. **Product Performance** — top 10 products by revenue, units sold, return rate
4. **Cohort Analysis** — revenue by user signup month cohort
5. **Inventory Alert** — products with stock < 10 and high demand (>5 orders last 30 days)
6. **Materialized View** — create and refresh a `daily_sales_summary` materialized view
7. **Performance** — ensure all queries run in < 50ms, add appropriate indexes

### Deliverables
- `projects/01-ecommerce/queries.sql` — all analytical queries
- `projects/01-ecommerce/indexes.sql` — index creation scripts
- `projects/01-ecommerce/explain.txt` — EXPLAIN ANALYZE output for 3 key queries

---

## Project 2: Semantic Product Search Engine
**Covers:** Module 3 — pgvector, embeddings, semantic search
**Estimated time:** 4–5 hours

### Objective
Build a semantic search engine that lets users find products using natural language queries.

### Requirements
1. **Schema** — extend the products table with an embedding VECTOR(1536) column
2. **Embedding Generation** — Python script to generate and store embeddings for all products using Azure OpenAI (or OpenAI API)
3. **Search API** — function that takes a text query, embeds it, and returns top 5 similar products
4. **Hybrid Search** — combine vector similarity with price range and category filters
5. **HNSW Index** — create and benchmark with and without the index
6. **Similarity Threshold** — only return results with similarity > 0.70

### Sample Queries to Test
- "portable music player for commuting"
- "laptop for video editing and coding"
- "comfortable chair for home office"
- "gaming console for 4K gaming"

### Deliverables
- `projects/02-semantic-search/setup.sql` — schema changes
- `projects/02-semantic-search/embed.py` — embedding generation script
- `projects/02-semantic-search/search.py` — search function
- `projects/02-semantic-search/benchmark.md` — performance comparison

---

## Project 3: AI Document Q&A System (RAG)
**Covers:** Module 3 — full RAG pipeline, chat history, semantic memory
**Estimated time:** 5–6 hours

### Objective
Build a document question-answering system that can answer questions about a set of technical documents stored in your SQL database.

### Requirements
1. **Document Ingestion** — ingest 10+ documents (PDFs, text files, or web pages), chunk them, embed, and store
2. **RAG Pipeline** — embed question → retrieve top-5 chunks → generate answer with GPT-4
3. **Chat History** — persist every conversation in SQL with session management
4. **Semantic Memory** — when conversation is long, retrieve relevant past messages via vector search instead of sending full history
5. **Evaluation** — score answer quality on 10 test questions (did it cite the right sources?)
6. **Source Attribution** — return which documents were used to generate the answer

### Architecture
```
User → Embed Question → pgvector Search → Build Prompt → GPT-4 → Answer
                            ↑
                    SQL: documents + chat_messages
```

### Deliverables
- `projects/03-rag/ingest.py` — document ingestion pipeline
- `projects/03-rag/rag.py` — core RAG logic
- `projects/03-rag/chat.py` — chat session management
- `projects/03-rag/eval.md` — evaluation results

---

## Project 4: Azure SQL Security Configuration
**Covers:** Module 4 — TDE, RLS, DDM, Ledger, Auditing
**Estimated time:** 2–3 hours

### Objective
Harden the e-commerce database with enterprise-grade security features.

### Requirements
1. **Row-Level Security** — users can only see their own orders; admins see all
2. **Dynamic Data Masking** — mask email (show first letter + domain), mask card numbers
3. **Ledger Table** — convert `orders` to a ledger table for tamper-proof audit
4. **Roles** — create `customer_role`, `analyst_role`, `admin_role` with appropriate permissions
5. **Audit Policy** — document what you would configure for Azure SQL Auditing
6. **Threat Assessment** — document SQL injection risk points in the schema

### SQL to Write
```sql
-- Create roles
-- Apply RLS policy
-- Add DDM to sensitive columns
-- Create ledger version of orders
-- Verify with test users
```

### Deliverables
- `projects/04-security/rls.sql` — row-level security setup
- `projects/04-security/masking.sql` — dynamic data masking
- `projects/04-security/ledger.sql` — ledger table migration
- `projects/04-security/roles.sql` — RBAC setup
- `projects/04-security/security-report.md` — findings and recommendations

---

## Project 5: AI-Powered Customer Support Bot
**Covers:** All modules — Full-stack SQL + AI integration
**Estimated time:** 8–10 hours (capstone project)

### Objective
Build a complete customer support chatbot backed entirely by SQL — product FAQs, order status, and AI-generated responses.

### Requirements
1. **FAQ Knowledge Base** — store 50+ Q&A pairs with embeddings in `documents` table
2. **Order Status Lookup** — bot can query user's orders and return status in natural language
3. **Intent Detection** — classify user intent as: `order_status`, `product_question`, `complaint`, `general`
4. **Smart Routing**:
   - `order_status` → SQL query for order data
   - `product_question` → RAG over product docs
   - `complaint` → escalation + log to DB
5. **Multi-turn Conversation** — maintain context across 10+ turns
6. **Hallucination Prevention** — if no relevant docs found, say "I don't know" instead of making up an answer
7. **Analytics** — SQL queries to analyze: most common questions, resolution rate, avg turns per session

### Architecture
```
User Message
    ↓
Intent Classifier (SQL + LLM)
    ↓
Router
    ├── Order Status  → SQL query
    ├── Product Q     → RAG pipeline
    └── General       → LLM with context
    ↓
Response + Store in chat_messages
```

### Deliverables
- `projects/05-support-bot/schema.sql` — any additional tables needed
- `projects/05-support-bot/bot.py` — main bot logic
- `projects/05-support-bot/intents.py` — intent classification
- `projects/05-support-bot/analytics.sql` — usage analytics queries
- `projects/05-support-bot/README.md` — architecture + demo instructions

---

## Submission Checklist

Before considering a project complete:

- [ ] All SQL runs without errors on Neon DB
- [ ] EXPLAIN ANALYZE confirms index usage on key queries
- [ ] Python scripts are runnable with a `.env` file for credentials
- [ ] README explains how to run the project
- [ ] Edge cases handled (no results, invalid input, empty embeddings)
