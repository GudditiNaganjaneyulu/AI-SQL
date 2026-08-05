# Module 1: SQL Fundamentals

**Duration:** Week 1–2
**Goal:** Master core SQL — the foundation for everything else in this certification.

---

## 1. SQL Command Categories

| Category | Commands | Purpose |
|----------|----------|---------|
| DDL | CREATE, ALTER, DROP, TRUNCATE | Define structure |
| DML | SELECT, INSERT, UPDATE, DELETE | Manipulate data |
| DCL | GRANT, REVOKE | Access control |
| TCL | BEGIN, COMMIT, ROLLBACK, SAVEPOINT | Transaction control |

---

## 2. Data Types (PostgreSQL / Azure SQL)

```sql
-- Numeric
INTEGER, BIGINT, NUMERIC(10,2), FLOAT, DECIMAL

-- Text
VARCHAR(255), TEXT, CHAR(10)

-- Date/Time
DATE, TIME, TIMESTAMP, TIMESTAMPTZ, INTERVAL

-- Boolean
BOOLEAN

-- JSON
JSON, JSONB  -- JSONB is binary, indexable, preferred

-- Special (for AI)
VECTOR(1536)  -- pgvector for embeddings
UUID
```

---

## 3. Creating Tables

```sql
-- Create a users table
CREATE TABLE users (
    user_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username    VARCHAR(100) NOT NULL UNIQUE,
    email       TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    is_active   BOOLEAN DEFAULT TRUE
);

-- Create a products table
CREATE TABLE products (
    product_id  SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    price       NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    category    VARCHAR(100),
    stock       INTEGER DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Create an orders table
CREATE TABLE orders (
    order_id    SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    product_id  INTEGER NOT NULL REFERENCES products(product_id),
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    total_price NUMERIC(10, 2),
    order_date  TIMESTAMPTZ DEFAULT NOW(),
    status      VARCHAR(50) DEFAULT 'pending'
);
```

---

## 4. INSERT / UPDATE / DELETE

```sql
-- Insert single row
INSERT INTO users (username, email)
VALUES ('alice', 'alice@example.com');

-- Insert multiple rows
INSERT INTO products (name, price, category, stock) VALUES
    ('Laptop', 999.99, 'Electronics', 50),
    ('Phone',  499.99, 'Electronics', 100),
    ('Desk',   299.99, 'Furniture',   20);

-- Update
UPDATE products
SET price = price * 0.9   -- 10% discount
WHERE category = 'Electronics';

-- Delete
DELETE FROM orders
WHERE status = 'cancelled' AND order_date < NOW() - INTERVAL '30 days';

-- Upsert (INSERT ... ON CONFLICT)
INSERT INTO users (username, email)
VALUES ('alice', 'alice@example.com')
ON CONFLICT (email) DO UPDATE
    SET username = EXCLUDED.username;
```

---

## 5. SELECT & Filtering

```sql
-- Basic select
SELECT product_id, name, price FROM products;

-- WHERE with conditions
SELECT * FROM products
WHERE price > 200 AND category = 'Electronics';

-- LIKE pattern matching
SELECT * FROM users WHERE email LIKE '%@gmail.com';

-- IN / NOT IN
SELECT * FROM orders WHERE status IN ('pending', 'processing');

-- BETWEEN
SELECT * FROM products WHERE price BETWEEN 100 AND 500;

-- NULL checks
SELECT * FROM products WHERE description IS NULL;

-- ORDER and LIMIT
SELECT * FROM products
ORDER BY price DESC
LIMIT 10 OFFSET 20;  -- pagination
```

---

## 6. Aggregate Functions

```sql
-- COUNT, SUM, AVG, MIN, MAX
SELECT
    category,
    COUNT(*)                    AS total_products,
    AVG(price)::NUMERIC(10,2)   AS avg_price,
    MAX(price)                  AS max_price,
    MIN(price)                  AS min_price,
    SUM(stock)                  AS total_stock
FROM products
GROUP BY category
HAVING COUNT(*) > 1
ORDER BY avg_price DESC;
```

---

## 7. JOINs — The Most Important Topic

```sql
-- INNER JOIN — only matching rows
SELECT
    o.order_id,
    u.username,
    p.name AS product_name,
    o.quantity,
    o.total_price
FROM orders o
INNER JOIN users u    ON o.user_id = u.user_id
INNER JOIN products p ON o.product_id = p.product_id;

-- LEFT JOIN — all users even with no orders
SELECT
    u.username,
    COUNT(o.order_id) AS order_count
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.username
ORDER BY order_count DESC;

-- RIGHT JOIN — all products even if never ordered
SELECT
    p.name,
    COALESCE(SUM(o.quantity), 0) AS units_sold
FROM orders o
RIGHT JOIN products p ON o.product_id = p.product_id
GROUP BY p.name;

-- FULL OUTER JOIN — all rows from both tables
SELECT u.username, o.order_id
FROM users u
FULL OUTER JOIN orders o ON u.user_id = o.user_id;

-- SELF JOIN — e.g. employees and their managers
SELECT
    e.username AS employee,
    m.username AS manager
FROM users e
LEFT JOIN users m ON e.user_id = m.user_id;
```

---

## 8. Subqueries

```sql
-- Subquery in WHERE
SELECT * FROM products
WHERE price > (SELECT AVG(price) FROM products);

-- Subquery in FROM (derived table)
SELECT category, avg_price
FROM (
    SELECT category, AVG(price) AS avg_price
    FROM products
    GROUP BY category
) AS cat_avg
WHERE avg_price > 300;

-- EXISTS
SELECT * FROM users u
WHERE EXISTS (
    SELECT 1 FROM orders o WHERE o.user_id = u.user_id
);

-- Correlated subquery
SELECT p.name,
       (SELECT COUNT(*) FROM orders o WHERE o.product_id = p.product_id) AS times_ordered
FROM products p;
```

---

## 9. Window Functions

```sql
-- ROW_NUMBER — rank each product within its category by price
SELECT
    name,
    category,
    price,
    ROW_NUMBER() OVER (PARTITION BY category ORDER BY price DESC) AS rank
FROM products;

-- RANK vs DENSE_RANK (handles ties differently)
SELECT
    name,
    price,
    RANK()       OVER (ORDER BY price DESC) AS rank,
    DENSE_RANK() OVER (ORDER BY price DESC) AS dense_rank
FROM products;

-- LAG / LEAD — compare with previous/next row
SELECT
    order_date,
    total_price,
    LAG(total_price)  OVER (ORDER BY order_date) AS prev_order_price,
    LEAD(total_price) OVER (ORDER BY order_date) AS next_order_price
FROM orders;

-- Running total
SELECT
    order_date,
    total_price,
    SUM(total_price) OVER (ORDER BY order_date ROWS UNBOUNDED PRECEDING) AS running_total
FROM orders;

-- Moving average (last 3 orders)
SELECT
    order_date,
    total_price,
    AVG(total_price) OVER (ORDER BY order_date ROWS 2 PRECEDING) AS moving_avg_3
FROM orders;
```

---

## 10. String & Date Functions

```sql
-- String functions
SELECT
    UPPER(username),
    LOWER(email),
    LENGTH(username),
    SUBSTRING(email, 1, POSITION('@' IN email) - 1) AS email_prefix,
    CONCAT(username, ' <', email, '>') AS display_name,
    TRIM('  hello  '),
    REPLACE(name, 'Laptop', 'Notebook')
FROM users;

-- Date functions
SELECT
    NOW(),
    CURRENT_DATE,
    DATE_TRUNC('month', NOW()),
    EXTRACT(YEAR FROM order_date) AS year,
    EXTRACT(MONTH FROM order_date) AS month,
    AGE(NOW(), created_at) AS account_age,
    order_date + INTERVAL '7 days' AS delivery_estimate
FROM orders;
```

---

## 11. CASE Expression

```sql
SELECT
    name,
    price,
    CASE
        WHEN price < 100  THEN 'Budget'
        WHEN price < 500  THEN 'Mid-range'
        WHEN price < 1000 THEN 'Premium'
        ELSE 'Luxury'
    END AS price_tier
FROM products;
```

---

## 12. JSONB Queries (Azure SQL / PostgreSQL)

```sql
-- Create table with JSONB
CREATE TABLE events (
    id      SERIAL PRIMARY KEY,
    payload JSONB,
    ts      TIMESTAMPTZ DEFAULT NOW()
);

-- Insert JSON
INSERT INTO events (payload) VALUES
    ('{"user": "alice", "action": "login", "device": {"os": "iOS"}}');

-- Query JSON fields
SELECT payload->>'user' AS username,
       payload->>'action' AS action,
       payload->'device'->>'os' AS os
FROM events;

-- Filter on JSON field
SELECT * FROM events
WHERE payload->>'action' = 'login'
  AND payload @> '{"device": {"os": "iOS"}}';

-- Index on JSONB field
CREATE INDEX idx_events_user ON events ((payload->>'user'));
```

---

## Exercises

See `exercises/` folder for hands-on practice on:
1. `ex01-basic-queries.sql`
2. `ex02-joins.sql`
3. `ex03-aggregations.sql`
4. `ex04-window-functions.sql`
5. `ex05-subqueries.sql`
6. `ex06-jsonb.sql`

---

## Module 1 Checklist

- [ ] Can write DDL for complex schemas with constraints
- [ ] Comfortable with all JOIN types and know when to use each
- [ ] Can use window functions (ROW_NUMBER, RANK, LAG, SUM OVER)
- [ ] Understand subqueries vs JOINs and when each is better
- [ ] Can query JSONB fields
- [ ] Completed all 6 exercises
