-- =============================================================
-- AI-SQL Certification Prep — Lab Setup Script
-- Database: AISQL (Neon PostgreSQL)
-- Run this first to set up all sample data
-- =============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- for fuzzy text search

-- =============================================================
-- SCHEMA SETUP
-- =============================================================

-- Users
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS product_embeddings CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
DROP TABLE IF EXISTS chat_sessions CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS employees CASCADE;

CREATE TABLE users (
    user_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username    VARCHAR(100) NOT NULL UNIQUE,
    email       TEXT NOT NULL UNIQUE,
    full_name   TEXT,
    country     VARCHAR(100) DEFAULT 'US',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    is_active   BOOLEAN DEFAULT TRUE
);

-- Products
CREATE TABLE products (
    product_id  SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    price       NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    category    VARCHAR(100),
    stock       INTEGER DEFAULT 0,
    rating      NUMERIC(3,2) CHECK (rating >= 0 AND rating <= 5),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Orders
CREATE TABLE orders (
    order_id    SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    product_id  INTEGER NOT NULL REFERENCES products(product_id),
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    total_price NUMERIC(10, 2),
    order_date  TIMESTAMPTZ DEFAULT NOW(),
    status      VARCHAR(50) DEFAULT 'pending'
        CHECK (status IN ('pending','processing','shipped','delivered','cancelled'))
);

-- Documents (for AI/RAG labs)
CREATE TABLE documents (
    id          SERIAL PRIMARY KEY,
    title       TEXT,
    content     TEXT NOT NULL,
    source      TEXT,
    category    TEXT,
    embedding   VECTOR(3),  -- 3-dim for lab examples (use 1536 with real OpenAI)
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Product embeddings
CREATE TABLE product_embeddings (
    product_id  INTEGER PRIMARY KEY REFERENCES products(product_id) ON DELETE CASCADE,
    embedding   VECTOR(3),  -- simplified for lab
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Chat sessions & messages
CREATE TABLE chat_sessions (
    session_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES users(user_id),
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    title       TEXT
);

CREATE TABLE chat_messages (
    message_id  SERIAL PRIMARY KEY,
    session_id  UUID REFERENCES chat_sessions(session_id) ON DELETE CASCADE,
    role        VARCHAR(20) NOT NULL CHECK (role IN ('user','assistant','system')),
    content     TEXT NOT NULL,
    embedding   VECTOR(3),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Employees (for recursive CTE lab)
CREATE TABLE employees (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    role        TEXT,
    manager_id  INTEGER REFERENCES employees(id),
    salary      NUMERIC(10,2),
    hire_date   DATE DEFAULT CURRENT_DATE
);

-- =============================================================
-- SAMPLE DATA
-- =============================================================

-- Users (20 users)
INSERT INTO users (username, email, full_name, country) VALUES
    ('alice_j',    'alice@example.com',    'Alice Johnson',   'US'),
    ('bob_smith',  'bob@example.com',      'Bob Smith',       'UK'),
    ('charlie_d',  'charlie@example.com',  'Charlie Davis',   'CA'),
    ('diana_r',    'diana@example.com',    'Diana Rodriguez', 'US'),
    ('evan_k',     'evan@example.com',     'Evan Kim',        'KR'),
    ('fiona_m',    'fiona@example.com',    'Fiona Moore',     'AU'),
    ('george_w',   'george@example.com',   'George Wilson',   'US'),
    ('hannah_t',   'hannah@example.com',   'Hannah Taylor',   'UK'),
    ('ivan_p',     'ivan@example.com',     'Ivan Petrov',     'RU'),
    ('julia_n',    'julia@example.com',    'Julia Nguyen',    'VN'),
    ('kevin_o',    'kevin@example.com',    'Kevin O''Brien',  'IE'),
    ('laura_b',    'laura@example.com',    'Laura Brown',     'US'),
    ('michael_c',  'michael@example.com',  'Michael Chen',    'CN'),
    ('natasha_v',  'natasha@example.com',  'Natasha Volkov',  'RU'),
    ('oliver_h',   'oliver@example.com',   'Oliver Harris',   'UK'),
    ('priya_s',    'priya@example.com',    'Priya Sharma',    'IN'),
    ('quinn_l',    'quinn@example.com',    'Quinn Lee',       'US'),
    ('rosa_m',     'rosa@example.com',     'Rosa Martinez',   'MX'),
    ('sam_a',      'sam@example.com',      'Sam Anderson',    'US'),
    ('tina_z',     'tina@example.com',     'Tina Zhang',      'CN');

-- Products (15 products)
INSERT INTO products (name, description, price, category, stock, rating) VALUES
    ('MacBook Pro 16"',    'Apple M3 Pro chip, 18GB RAM, 512GB SSD', 2499.99, 'Laptops',     30,  4.8),
    ('Dell XPS 15',        'Intel Core i9, 32GB RAM, NVIDIA RTX',    1799.99, 'Laptops',     45,  4.6),
    ('iPhone 16 Pro',      '6.3" display, A18 Pro chip, 5G',         1199.99, 'Phones',     150,  4.7),
    ('Samsung Galaxy S25', '6.2" Dynamic AMOLED, Snapdragon 8 Gen 4',999.99, 'Phones',     200,  4.5),
    ('Sony WH-1000XM6',    'Industry-leading noise cancelling',        349.99, 'Audio',      80,   4.9),
    ('AirPods Pro 3',      'Active noise cancellation, H2 chip',       249.99, 'Audio',     120,   4.7),
    ('iPad Pro 13"',       'M4 chip, Liquid Retina XDR display',       1299.99,'Tablets',    60,   4.8),
    ('Kindle Scribe',      'E-ink writing tablet, 10.2" display',       339.99,'Tablets',    70,   4.4),
    ('LG OLED C4 65"',     '65-inch OLED, 4K 120Hz, WebOS 24',        1799.99, 'TVs',       15,   4.9),
    ('Dyson V15 Detect',   'Laser dust detection, 60min runtime',       649.99, 'Appliances',40,   4.6),
    ('Standing Desk Pro',  'Electric height-adjustable, 72" wide',      599.99, 'Furniture', 25,   4.5),
    ('Ergonomic Chair',    'Lumbar support, adjustable armrests',       449.99, 'Furniture', 35,   4.7),
    ('PS5 Pro',            'PlayStation 5 Pro, 2TB SSD, 8K ready',      699.99, 'Gaming',    55,   4.8),
    ('Xbox Series X',      '12 TFLOPS GPU, 1TB NVMe SSD, 4K 120fps',   499.99, 'Gaming',    60,   4.7),
    ('USB-C Hub 12-in-1',  'Thunderbolt 4, 4K HDMI, SD card',          79.99,  'Accessories',90,  4.5);

-- Orders (30 orders over the past 6 months)
INSERT INTO orders (user_id, product_id, quantity, total_price, order_date, status)
SELECT
    u.user_id,
    p.product_id,
    CASE WHEN p.price > 500 THEN 1 ELSE floor(random() * 3 + 1)::int END AS quantity,
    p.price * CASE WHEN p.price > 500 THEN 1 ELSE floor(random() * 3 + 1)::int END,
    NOW() - (random() * INTERVAL '180 days'),
    (ARRAY['pending','processing','shipped','delivered','delivered','delivered','cancelled'])[floor(random() * 7 + 1)::int]
FROM users u
CROSS JOIN products p
WHERE random() < 0.1  -- ~10% chance of each combination
ORDER BY random()
LIMIT 30;

-- Documents for RAG lab (simplified 3-dim embeddings for demo)
INSERT INTO documents (title, content, source, category, embedding) VALUES
    ('Vector Databases 101',
     'Vector databases store high-dimensional vectors for semantic similarity search. They power AI applications by enabling fast nearest-neighbor lookups.',
     'tech_blog', 'AI',
     '[0.8, 0.3, 0.1]'),

    ('PostgreSQL pgvector Guide',
     'pgvector is a PostgreSQL extension for storing and querying vector embeddings. It supports L2, cosine, and inner product distance operators.',
     'docs', 'Database',
     '[0.7, 0.4, 0.2]'),

    ('RAG Architecture Explained',
     'Retrieval-Augmented Generation combines a retrieval system with a language model. The retriever finds relevant documents; the LLM generates grounded answers.',
     'research_paper', 'AI',
     '[0.9, 0.2, 0.1]'),

    ('Azure SQL Security Features',
     'Azure SQL provides Always Encrypted, TDE, Row-Level Security, and Dynamic Data Masking to protect sensitive data at multiple layers.',
     'azure_docs', 'Database',
     '[0.1, 0.9, 0.3]'),

    ('Query Optimization Best Practices',
     'Use indexes strategically, avoid functions on indexed columns, analyze query plans with EXPLAIN ANALYZE, and keep statistics up to date.',
     'dba_guide', 'Database',
     '[0.2, 0.8, 0.4]'),

    ('Azure OpenAI Embeddings',
     'Azure OpenAI text-embedding-ada-002 produces 1536-dimensional vectors. Use these for semantic search, classification, and clustering tasks.',
     'azure_docs', 'AI',
     '[0.85, 0.25, 0.15]'),

    ('SQL Window Functions',
     'Window functions perform calculations across related rows without collapsing them. ROW_NUMBER, RANK, LAG, LEAD, and SUM OVER are commonly used.',
     'tutorial', 'Database',
     '[0.15, 0.75, 0.5]');

-- Product embeddings (simplified)
INSERT INTO product_embeddings (product_id, embedding) VALUES
    (1,  '[0.9, 0.1, 0.8]'),  -- MacBook Pro - laptop
    (2,  '[0.8, 0.2, 0.7]'),  -- Dell XPS - laptop
    (3,  '[0.1, 0.9, 0.7]'),  -- iPhone - phone
    (4,  '[0.2, 0.8, 0.6]'),  -- Samsung - phone
    (5,  '[0.3, 0.3, 0.9]'),  -- Sony headphones - audio
    (6,  '[0.4, 0.2, 0.8]'),  -- AirPods - audio
    (7,  '[0.7, 0.3, 0.9]'),  -- iPad - tablet
    (13, '[0.5, 0.1, 0.9]'),  -- PS5 - gaming
    (14, '[0.4, 0.2, 0.8]');  -- Xbox - gaming

-- Employees (for recursive CTE lab)
INSERT INTO employees (name, role, manager_id, salary, hire_date) VALUES
    ('CEO Sarah',      'CEO',               NULL, 250000, '2015-01-01'),
    ('CTO Mark',       'CTO',               1,    180000, '2016-03-15'),
    ('CFO Lisa',       'CFO',               1,    170000, '2016-06-01'),
    ('VP Eng Tom',     'VP Engineering',    2,    150000, '2017-01-10'),
    ('VP Data Ana',    'VP Data',           2,    145000, '2017-04-20'),
    ('Lead Dev Jake',  'Lead Developer',    4,    120000, '2018-02-01'),
    ('Lead Dev Emma',  'Lead Developer',    4,    118000, '2018-05-15'),
    ('Data Eng Raj',   'Data Engineer',     5,    110000, '2019-01-15'),
    ('Dev Carlos',     'Developer',         6,     95000, '2020-03-01'),
    ('Dev Mia',        'Developer',         6,     92000, '2020-06-01'),
    ('Dev Liam',       'Developer',         7,     90000, '2021-01-10'),
    ('Analyst Zoe',    'Data Analyst',      8,     85000, '2021-07-01');

-- =============================================================
-- INDEXES
-- =============================================================
CREATE INDEX idx_orders_user_id    ON orders(user_id);
CREATE INDEX idx_orders_product_id ON orders(product_id);
CREATE INDEX idx_orders_date       ON orders(order_date DESC);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_price    ON products(price);
CREATE INDEX idx_users_email       ON users(LOWER(email));
CREATE INDEX idx_users_active      ON users(user_id) WHERE is_active = TRUE;

-- Vector index for documents
CREATE INDEX idx_documents_embedding ON documents
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 4);  -- small for lab data

-- =============================================================
-- VERIFY SETUP
-- =============================================================
SELECT 'users'     AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'products',  COUNT(*) FROM products
UNION ALL
SELECT 'orders',    COUNT(*) FROM orders
UNION ALL
SELECT 'documents', COUNT(*) FROM documents
UNION ALL
SELECT 'employees', COUNT(*) FROM employees;
