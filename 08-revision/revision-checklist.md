# Revision Checklist

Every bullet of the **official skills measured (as of October 19, 2026)**. Tick an item only when you can **explain it out loud** and **write the code without notes**.

## Domain 1 — Design and develop database solutions (35–40%)

### Design and implement database objects
- [ ] Tables: data types, size, columns, indexes, columnstore indexes
- [ ] Specialized tables: in-memory, temporal, external, ledger, graph
- [ ] JSON columns and JSON indexes
- [ ] Constraints: PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, DEFAULT
- [ ] SEQUENCES
- [ ] Partitioning for tables and indexes

### Implement programmability objects
- [ ] Views
- [ ] Scalar functions
- [ ] Table-valued functions (inline and multi-statement)
- [ ] Stored procedures
- [ ] Triggers

### Write advanced T-SQL code
- [ ] Common table expressions (including recursive)
- [ ] Window functions
- [ ] JSON functions: JSON_OBJECT, JSON_ARRAY, JSON_ARRAYAGG, JSON_CONTAINS, OPENJSON, JSON_VALUE
- [ ] Regular expressions: REGEXP_LIKE, REGEXP_REPLACE, REGEXP_SUBSTR, REGEXP_INSTR, REGEXP_COUNT, REGEXP_MATCHES, REGEXP_SPLIT_TO_TABLE
- [ ] Fuzzy matching: EDIT_DISTANCE, EDIT_DISTANCE_SIMILARITY, JARO_WINKLER_DISTANCE
- [ ] Graph queries with MATCH
- [ ] Correlated queries
- [ ] Error handling

### Design and implement SQL solutions by using AI-assisted tools
- [ ] Interpret the security impact of AI-assisted tools
- [ ] Enable GitHub Copilot and Copilot in Fabric
- [ ] Configure model and MCP tool options in a Copilot chat session
- [ ] Create and configure GitHub Copilot instruction files
- [ ] Connect to MCP server endpoints, including SQL Server and Fabric lakehouse

## Domain 2 — Secure, optimize, and deploy database solutions (35–40%)

### Implement data security and compliance
- [ ] Always Encrypted and column-level encryption
- [ ] Dynamic Data Masking
- [ ] Row-Level Security
- [ ] Object-level permissions
- [ ] Secure database access, including passwordless
- [ ] Auditing
- [ ] Secure model endpoints, including Managed Identity
- [ ] Secure GraphQL, REST, and MCP endpoints

### Optimize database performance
- [ ] Recommend database configurations
- [ ] Transaction isolation levels and concurrency controls
- [ ] Execution plans, DMVs, Query Store, Query Performance Insight
- [ ] Identify and resolve blocking and deadlocks

### Implement CI/CD by using SQL Database Projects
- [ ] Testing strategy: unit and integration tests
- [ ] Reference/static data in source control
- [ ] Create, build and validate database models, including SDK-style
- [ ] Source control for SQL Database Projects
- [ ] Branching, pull requests, conflict resolution
- [ ] Secrets management
- [ ] Detect schema drift
- [ ] Update a SQL database project and deploy changes
- [ ] Pipeline controls: branching policies, triggers, approvals, code owners

### Integrate SQL solutions with Azure services
- [ ] Data API builder configuration files
- [ ] Entities for REST and GraphQL: caching, pagination, searching, filtering
- [ ] Configure REST or GraphQL endpoints
- [ ] Expose tables, stored procedures and views, including GraphQL relationships
- [ ] Configure and implement DAB deployment
- [ ] Azure Monitor: Application Insights and Log Analytics
- [ ] Change handling: CES, CDC, Change Tracking, Azure Functions SQL trigger, Logic Apps

## Domain 3 — Implement AI capabilities in database solutions (25–30%)

### Design and implement models and embeddings
- [ ] Evaluate external models: multimodal, multilanguage, sizes, structured output
- [ ] Create and manage external models
- [ ] Choose an embedding maintenance method: triggers, Change Tracking, Azure Functions SQL trigger, Logic Apps, CDC, Microsoft Foundry
- [ ] Identify which columns to include in embeddings
- [ ] Design and implement chunks
- [ ] Generate embeddings

### Design and implement intelligent search
- [ ] Choose full-text vs semantic vector vs hybrid search
- [ ] Implement full-text search
- [ ] Vector data type, vector indexes, size
- [ ] VECTOR_NORMALIZE, VECTOR_DISTANCE, VECTORPROPERTY, VECTOR_SEARCH
- [ ] ANN vs KNN
- [ ] Vector index types and metrics
- [ ] Implement vector search
- [ ] Implement hybrid search
- [ ] Reciprocal rank fusion (RRF)
- [ ] Evaluate vector and hybrid search performance

### Design and implement RAG
- [ ] Identify RAG use cases
- [ ] Create a prompt with sp_invoke_external_rest_endpoint
- [ ] Convert structured data to JSON for a language model
- [ ] Send results to a language model
- [ ] Extract language model responses

## Readiness

- [ ] Practice exam ≥ 80%
- [ ] Microsoft official practice assessment ≥ 80%
- [ ] All labs completed
