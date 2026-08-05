# SQL Quick Reference Cheatsheet

## Window Functions
```sql
ROW_NUMBER() OVER (PARTITION BY col ORDER BY col)   -- unique rank
RANK()       OVER (ORDER BY col DESC)               -- gaps on ties
DENSE_RANK() OVER (ORDER BY col DESC)               -- no gaps on ties
NTILE(4)     OVER (ORDER BY col)                    -- quartiles
LAG(col, 1)  OVER (ORDER BY col)                    -- previous row
LEAD(col, 1) OVER (ORDER BY col)                    -- next row
SUM(col)     OVER (ORDER BY col ROWS UNBOUNDED PRECEDING)  -- running total
AVG(col)     OVER (ORDER BY col ROWS 2 PRECEDING)   -- 3-row moving avg
FIRST_VALUE(col) OVER (PARTITION BY g ORDER BY col) -- first in group
LAST_VALUE(col)  OVER (PARTITION BY g ORDER BY col ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
```

## Date Functions
```sql
NOW()                            -- current timestamp with tz
CURRENT_DATE                     -- date only
DATE_TRUNC('month', ts)          -- truncate to month
EXTRACT(YEAR FROM ts)            -- year number
AGE(ts1, ts2)                    -- interval between dates
ts + INTERVAL '7 days'           -- add time
ts - INTERVAL '1 month'          -- subtract time
TO_CHAR(ts, 'YYYY-MM-DD')        -- format date
```

## String Functions
```sql
UPPER(s) / LOWER(s)              -- case
LENGTH(s)                        -- char count
TRIM(s) / LTRIM / RTRIM          -- remove whitespace
SUBSTRING(s, start, len)         -- extract
POSITION('x' IN s)               -- find substring
REPLACE(s, 'old', 'new')         -- replace
SPLIT_PART(s, ',', 1)            -- split by delimiter
CONCAT(a, b) or a || b           -- concatenate
LPAD(s, 10, '0')                 -- left pad
REGEXP_REPLACE(s, pattern, new)  -- regex replace
```

## JSONB Operators
```sql
col->'key'         -- get JSON object (returns JSON)
col->>'key'        -- get text value
col->'a'->'b'      -- nested access
col @> '{"k":"v"}' -- contains
col ? 'key'        -- key exists
col #> '{a,b}'     -- path access
col #>> '{a,b}'    -- path access as text
jsonb_array_elements(col)         -- expand array
jsonb_object_keys(col)            -- get keys
```

## pgvector
```sql
col <-> other   -- L2 distance
col <#> other   -- negative inner product
col <=> other   -- cosine distance (use for text)

-- Create vector column
ALTER TABLE t ADD COLUMN emb VECTOR(1536);

-- HNSW index (recommended)
CREATE INDEX ON t USING hnsw (emb vector_cosine_ops);

-- Top-5 most similar
SELECT *, 1-(emb<=>$1) AS sim FROM t ORDER BY emb<=>$1 LIMIT 5;
```

## Index Types
```sql
CREATE INDEX         ON t(col);                    -- B-Tree
CREATE INDEX USING GIN    ON t(jsonb_col);         -- JSONB/arrays/FTS
CREATE INDEX USING BRIN   ON t(created_at);        -- large ordered tables
CREATE INDEX USING HNSW   ON t(emb vector_cosine_ops); -- vectors
CREATE INDEX ON t(col) WHERE active = true;        -- partial
CREATE INDEX ON t(LOWER(email));                   -- expression
CREATE INDEX ON t(a, b) INCLUDE (c, d);            -- covering
DROP INDEX CONCURRENTLY idx_name;                  -- non-blocking drop
```

## Performance Checklist
```
✓ Run EXPLAIN (ANALYZE, BUFFERS) on slow queries
✓ Look for Seq Scan on large tables → add index
✓ Check estimated vs actual rows → run ANALYZE if gap is large
✓ Avoid functions on indexed columns in WHERE
✓ Use covering indexes to avoid heap fetches
✓ Prefer keyset pagination over OFFSET for large pages
✓ Use VACUUM ANALYZE regularly
✓ Create partial indexes for commonly filtered subsets
✓ Use connection pooling (PgBouncer) in production
```
