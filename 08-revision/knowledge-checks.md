# Knowledge Checks (Quick-Fire, Mixed)

Answer out loud or on paper, then reveal. Each chapter also ends with its own knowledge check — this page **mixes topics** to test recall the way the exam does.

## Round 1 — Foundations and Core T-SQL

1. In what logical order are `WHERE`, `GROUP BY`, `HAVING`, `SELECT` and `ORDER BY` processed?
2. Why does `WHERE col = NULL` never return rows?
3. Why is `NOT EXISTS` safer than `NOT IN`?
4. `TOP (5) WITH TIES` requires what clause?
5. What does `OUTER APPLY` do that `CROSS APPLY` doesn't?

<details>
<summary>Answers</summary>

1. WHERE → GROUP BY → HAVING → SELECT → ORDER BY.
2. Comparisons with NULL return UNKNOWN; use `IS NULL`.
3. If the subquery returns any NULL, `NOT IN` returns no rows.
4. `ORDER BY`.
5. Keeps left rows even when the right side returns no rows.
</details>

## Round 2 — Design and develop

6. What does a PRIMARY KEY create by default if the table has no clustered index?
7. Name the five specialized table types in the exam outline.
8. What does `RANGE RIGHT` mean in a partition function?
9. Which function type should you use as an RLS predicate?
10. What's the default `MAXRECURSION`?
11. Which regex functions return tables?
12. Which JSON function can use a JSON index to test whether an array contains a value?

<details>
<summary>Answers</summary>

6. A clustered index.
7. In-memory, temporal, external, ledger, graph.
8. Each boundary value belongs to the partition on its right.
9. An inline table-valued function (with SCHEMABINDING).
10. 100.
11. `REGEXP_MATCHES` and `REGEXP_SPLIT_TO_TABLE`.
12. `JSON_CONTAINS` (with a `[*]` path for arrays).
</details>

## Round 3 — Secure, optimize, deploy

13. Which encryption type allows equality searches in Always Encrypted?
14. What's the difference between FILTER and BLOCK predicates?
15. Which DMV column shows who is blocking a request?
16. Which Query Store procedure forces a plan?
17. What does building a SQL project produce, and what validates during build?
18. Which DAB option keeps secrets out of the config file?
19. Which change-handling feature does the Azure Functions SQL trigger depend on?

<details>
<summary>Answers</summary>

13. Deterministic.
14. FILTER hides rows from reads; BLOCK prevents writes that violate the predicate.
15. `blocking_session_id` in `sys.dm_exec_requests`.
16. `sp_query_store_force_plan`.
17. A `.dacpac`; syntax against the target platform and object references.
18. `@env('VARIABLE')`.
19. Change Tracking.
</details>

## Round 4 — AI capabilities

20. Max dimensions for float32 vectors? For float16?
21. Which three metrics do vector functions support? Which is returned negated?
22. What two things must match for a vector index to be used?
23. What does iterative filtering mean?
24. In RRF, what's a typical value of k?
25. Which permission is needed to call `sp_invoke_external_rest_endpoint`?
26. Where is the chat answer in the `@response` JSON?
27. What's the minimum compatibility level for `AI_GENERATE_CHUNKS`?

<details>
<summary>Answers</summary>

20. 1,998 (float32); 3,996 (float16).
21. Cosine, euclidean, dot — dot is returned as the negative dot product.
22. Column and metric (the query's `METRIC` must match the index's).
23. WHERE predicates are applied during the ANN search, so N qualifying rows are returned.
24. 60.
25. `EXECUTE ANY EXTERNAL ENDPOINT`.
26. `$.result.choices[0].message.content`.
27. 170.
</details>
