# Module 2: Advanced SQL & Query Optimization

**Duration:** Week 3–4
**Goal:** Write production-quality SQL and understand how the database engine executes it.

---

## 1. CTEs (Common Table Expressions)

```sql
-- Basic CTE
WITH high_value_orders AS (
    SELECT *
    FROM orders
    WHERE total_price > 500
)
SELECT u.username, COUNT(*) AS big_orders
FROM high_value_orders hvo
JOIN users u ON hvo.user_id = u.user_id
GROUP BY u.username;

-- Multiple CTEs
WITH
monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(total_price) AS revenue
    FROM orders
    GROUP BY 1
),
prev_month AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS prev_revenue
    FROM monthly_sales
)
SELECT
    month,
    revenue,
    prev_revenue,
    ROUND((revenue - prev_revenue) / prev_revenue * 100, 2) AS pct_change
FROM prev_month
WHERE prev_revenue IS NOT NULL;
```

---

## 2. Recursive CTEs

```sql
-- Generate a date series
WITH RECURSIVE date_series AS (
    SELECT '2026-01-01'::DATE AS d
    UNION ALL
    SELECT d + 1 FROM date_series WHERE d < '2026-01-31'
)
SELECT d FROM date_series;

-- Org hierarchy traversal
CREATE TABLE employees (
    id         SERIAL PRIMARY KEY,
    name       TEXT,
    manager_id INTEGER REFERENCES employees(id)
);

WITH RECURSIVE org_tree AS (
    -- Anchor: top-level (no manager)
    SELECT id, name, manager_id, 0 AS depth, name::TEXT AS path
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive: children
    SELECT e.id, e.name, e.manager_id, ot.depth + 1,
           ot.path || ' > ' || e.name
    FROM employees e
    JOIN org_tree ot ON e.manager_id = ot.id
)
SELECT depth, path FROM org_tree ORDER BY path;
```

---

## 3. Query Execution Plans

```sql
-- EXPLAIN — show the plan without running
EXPLAIN
SELECT * FROM orders o
JOIN users u ON o.user_id = u.user_id
WHERE u.email = 'alice@example.com';

-- EXPLAIN ANALYZE — run it and show actual times
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders o
JOIN users u ON o.user_id = u.user_id
WHERE u.email = 'alice@example.com';
```

**What to look for in the plan:**
- `Seq Scan` → full table scan, often needs an index
- `Index Scan` → good, using an index
- `Hash Join` vs `Nested Loop` vs `Merge Join`
- `rows=` estimate vs actual — large gaps mean stale statistics
- `cost=` — planner's estimate (start..total)
- `actual time=` — real execution time in ms

**Run ANALYZE to update statistics:**
```sql
ANALYZE orders;
ANALYZE products;
VACUUM ANALYZE;  -- reclaim space + update stats
```

---

## 4. Index Strategies

```sql
-- B-Tree (default) — for =, <, >, BETWEEN, ORDER BY
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_products_price ON products(price);

-- Composite index — column order matters
-- Useful for: WHERE category = X ORDER BY price
CREATE INDEX idx_products_cat_price ON products(category, price);

-- Partial index — index a subset of rows
CREATE INDEX idx_active_users ON users(email)
WHERE is_active = TRUE;

-- Index on expression
CREATE INDEX idx_lower_email ON users(LOWER(email));
-- Now this query uses the index:
SELECT * FROM users WHERE LOWER(email) = 'alice@example.com';

-- GIN index — for JSONB, arrays, full-text search
CREATE INDEX idx_events_payload ON events USING GIN (payload);
CREATE INDEX idx_products_fts ON products
    USING GIN (to_tsvector('english', name || ' ' || COALESCE(description,'')));

-- BRIN index — for large tables with natural ordering (timestamps, auto-inc IDs)
CREATE INDEX idx_orders_date_brin ON orders USING BRIN (order_date);

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Find unused indexes
SELECT indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0;

-- Drop unused index
DROP INDEX CONCURRENTLY idx_products_price;  -- CONCURRENTLY avoids table lock
```

---

## 5. Transactions & Isolation Levels

```sql
-- Basic transaction
BEGIN;
    UPDATE products SET stock = stock - 1 WHERE product_id = 1;
    INSERT INTO orders (user_id, product_id, quantity, total_price)
    VALUES ('uuid-here', 1, 1, 999.99);
COMMIT;

-- Rollback on error
BEGIN;
    UPDATE accounts SET balance = balance - 100 WHERE id = 1;
    UPDATE accounts SET balance = balance + 100 WHERE id = 2;
    -- If anything fails, rollback everything
ROLLBACK;  -- or COMMIT

-- SAVEPOINT — partial rollback
BEGIN;
    INSERT INTO orders (...) VALUES (...);
    SAVEPOINT after_order;
    INSERT INTO payments (...) VALUES (...);
    -- Payment failed, rollback just the payment
    ROLLBACK TO SAVEPOINT after_order;
    -- Order insert is still valid
COMMIT;

-- Isolation levels
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;   -- default
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;   -- prevents non-repeatable reads
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;      -- full ACID, highest protection
```

**Isolation Level Comparison:**

| Level | Dirty Read | Non-repeatable Read | Phantom Read |
|-------|-----------|---------------------|--------------|
| Read Uncommitted | ✅ possible | ✅ possible | ✅ possible |
| Read Committed | ❌ prevented | ✅ possible | ✅ possible |
| Repeatable Read | ❌ prevented | ❌ prevented | ✅ possible |
| Serializable | ❌ prevented | ❌ prevented | ❌ prevented |

---

## 6. Locking

```sql
-- SELECT FOR UPDATE — lock rows for update
BEGIN;
SELECT * FROM products WHERE product_id = 1 FOR UPDATE;
UPDATE products SET stock = stock - 1 WHERE product_id = 1;
COMMIT;

-- SELECT FOR UPDATE SKIP LOCKED — skip locked rows (queuing pattern)
SELECT * FROM jobs WHERE status = 'pending'
ORDER BY id
LIMIT 1
FOR UPDATE SKIP LOCKED;

-- Advisory locks — application-level locks
SELECT pg_advisory_lock(12345);    -- acquire
SELECT pg_advisory_unlock(12345);  -- release

-- Check active locks
SELECT pid, mode, granted, relation::regclass
FROM pg_locks
WHERE relation IS NOT NULL;
```

---

## 7. Partitioning

```sql
-- Range partitioning by date
CREATE TABLE orders_partitioned (
    order_id    SERIAL,
    user_id     UUID,
    total_price NUMERIC(10,2),
    order_date  TIMESTAMPTZ NOT NULL
) PARTITION BY RANGE (order_date);

-- Create partitions
CREATE TABLE orders_2025 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE orders_2026 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

-- List partitioning
CREATE TABLE products_partitioned (
    product_id SERIAL,
    name TEXT,
    category TEXT NOT NULL
) PARTITION BY LIST (category);

CREATE TABLE products_electronics PARTITION OF products_partitioned
    FOR VALUES IN ('Electronics', 'Gadgets');

CREATE TABLE products_furniture PARTITION OF products_partitioned
    FOR VALUES IN ('Furniture', 'Home');
```

---

## 8. Performance Patterns

```sql
-- Bad: function on indexed column prevents index use
SELECT * FROM users WHERE EXTRACT(YEAR FROM created_at) = 2026;

-- Good: range query uses index
SELECT * FROM users
WHERE created_at >= '2026-01-01' AND created_at < '2027-01-01';

-- Bad: leading wildcard kills index
SELECT * FROM users WHERE email LIKE '%gmail.com';

-- Good: trailing wildcard can use index
SELECT * FROM users WHERE username LIKE 'alice%';

-- Bad: implicit type cast
SELECT * FROM users WHERE user_id = '123';  -- if user_id is INTEGER

-- Good: match types
SELECT * FROM users WHERE user_id = 123;

-- Bad: SELECT * on large tables
SELECT * FROM orders;

-- Good: select only what you need
SELECT order_id, total_price, order_date FROM orders;

-- Avoid N+1: use JOIN instead of looping queries
-- Bad (N+1): SELECT user for each order
-- Good: single JOIN
SELECT o.order_id, u.username, o.total_price
FROM orders o
JOIN users u ON o.user_id = u.user_id;
```

---

## 9. Materialized Views

```sql
-- Create a materialized view for expensive aggregations
CREATE MATERIALIZED VIEW monthly_revenue AS
SELECT
    DATE_TRUNC('month', order_date) AS month,
    COUNT(*) AS order_count,
    SUM(total_price) AS revenue
FROM orders
GROUP BY 1
ORDER BY 1;

-- Query it like a table (fast!)
SELECT * FROM monthly_revenue WHERE month >= '2026-01-01';

-- Refresh when data changes
REFRESH MATERIALIZED VIEW monthly_revenue;

-- Non-blocking refresh (requires unique index)
CREATE UNIQUE INDEX ON monthly_revenue(month);
REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_revenue;
```

---

## 10. Full-Text Search

```sql
-- Create FTS index
CREATE INDEX idx_products_fts ON products
USING GIN (to_tsvector('english', name || ' ' || COALESCE(description, '')));

-- Search
SELECT name, description,
       ts_rank(to_tsvector('english', name || ' ' || COALESCE(description,'')),
               to_tsquery('english', 'wireless & headphones')) AS rank
FROM products
WHERE to_tsvector('english', name || ' ' || COALESCE(description,''))
      @@ to_tsquery('english', 'wireless & headphones')
ORDER BY rank DESC;

-- Phrase search
SELECT * FROM products
WHERE to_tsvector('english', name) @@ phraseto_tsquery('english', 'gaming laptop');
```

---

## Module 2 Checklist

- [ ] Write complex multi-CTE queries
- [ ] Read and interpret EXPLAIN ANALYZE output
- [ ] Choose the right index type for each scenario
- [ ] Understand all 4 isolation levels and when to use each
- [ ] Implement optimistic vs pessimistic locking
- [ ] Create and refresh materialized views
- [ ] Implement table partitioning
- [ ] Identify and fix common query performance anti-patterns
