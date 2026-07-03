# Volume 6: Revision Pack
# Chapter 26: Databases Revision

> **Cross-references:** This chapter revises core material from Volume 4 — SQL (Ch14), Indexing (Ch15), ACID & Transactions (Ch16), Distributed DBs (Ch17), Advanced DB (Ch18). Use this as your final interview pass, not a first read.

---

## Table of Contents

- [Section 1: SQL](#section-1-sql) — 15 Questions
- [Section 2: Indexing](#section-2-indexing) — 15 Questions
- [Section 3: ACID & Transactions](#section-3-acid--transactions) — 15 Questions
- [Section 4: Distributed Databases](#section-4-distributed-databases) — 15 Questions
- [Section 5: Quick Reference Q&As](#section-5-quick-reference-qas) — 5 Questions
- [Section 6: Must-Know SQL Patterns](#section-6-must-know-sql-patterns) — 5 Questions
- [Section 7: Common Traps](#section-7-common-traps) — 20 Items

---

> **How to read this chapter:** Each section is a standalone interview Q&A block. Every answer is fully self-contained — all technical terms are explained inline. Read the one-line answer first, then the full answer as if speaking it aloud. Gotcha follow-ups are the exact questions interviewers ask after your first answer.

---
## Section 1: SQL

**Q1: JOIN Types**
*Concept Check*

**One-line answer:** JOINs combine rows from two tables based on a condition, and the type controls which unmatched rows survive.

**Full answer:**
I think of JOINs as controlling what happens to rows that don't find a match on the other side. An INNER JOIN is the strictest — it returns only rows where the ON condition matches in both tables, so unmatched rows from either side are discarded. A LEFT JOIN keeps every row from the left (first) table and fills in NULLs for the right-side columns wherever there's no match — useful when I want "all customers, even those with no orders." A RIGHT JOIN is the mirror image, keeping every row from the right table. A FULL OUTER JOIN keeps all rows from both sides, NULLs where no match exists; this is rare but handy for reconciliation queries like finding rows present in one dataset but not the other. A CROSS JOIN produces the Cartesian product — every row from the left paired with every row from the right — so M × N result rows with no ON clause; I use this for generating combinations but I'm always careful because the result set explodes fast. A SELF JOIN is not a separate syntax — it's just joining a table to itself using an alias, typically to model hierarchical relationships like an employee table where each row has a manager_id that points back to another row in the same table.

*Start with INNER vs LEFT since those come up in 90% of interviews. Mention the NULL-filling behaviour explicitly — it shows you understand the output shape, not just the syntax.*

> **Gotcha follow-up:** If I do `SELECT * FROM A LEFT JOIN B ON A.id = B.a_id WHERE B.col = 'X'`, is this still a LEFT JOIN?
> No — the WHERE clause on the right-side table converts it back to an INNER JOIN in practice. When B.col is NULL (no match), the condition `B.col = 'X'` evaluates to UNKNOWN, which is excluded by WHERE. To keep the LEFT JOIN semantics I must move that filter into the ON clause: `ON A.id = B.a_id AND B.col = 'X'`.

---

**Q2: SQL Logical Execution Order**
*Concept Check*

**One-line answer:** SQL clauses execute in a fixed logical order — FROM first, SELECT near last — which explains why you can't use SELECT aliases in WHERE.

**Full answer:**
Even though I write SELECT at the top of a query, the database processes it much later. The logical order is: FROM and JOIN first (the engine decides which tables and rows to work with), then WHERE (filter individual rows), then GROUP BY (bucket the surviving rows into groups), then HAVING (filter those groups), then SELECT (compute expressions and aliases), then DISTINCT (remove duplicates), then ORDER BY (sort), and finally LIMIT/OFFSET (trim the result). This order has concrete consequences: because WHERE runs before SELECT, I cannot use a SELECT alias in a WHERE clause — the alias doesn't exist yet at that point. If I need to filter on a derived column, I wrap the query in a subquery or use a CTE (Common Table Expression — a named temporary result set defined with the WITH keyword). HAVING is specifically for filtering after aggregation — for example, `HAVING COUNT(*) > 5` — while WHERE cannot contain aggregate functions. Window functions (functions that compute a value per row using a sliding frame of related rows, like `ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary)`) execute after WHERE and GROUP BY but before ORDER BY and LIMIT, which means I can filter on their results only in an outer query.

*Interviewers love asking "why can't you use a WHERE alias" — lead with the execution order and derive the answer from first principles.*

> **Gotcha follow-up:** Can I use an ORDER BY alias in the same query?
> Yes — ORDER BY runs after SELECT, so by the time the engine reaches ORDER BY the aliases are already resolved. This is one of the few places a SELECT alias is visible without a subquery.

---

**Q3: Window Functions — ROW_NUMBER vs RANK vs DENSE_RANK**
*Concept Check*

**One-line answer:** All three number rows within a partition, but they differ in how they handle ties — only DENSE_RANK avoids gaps while still sharing tied ranks.

**Full answer:**
Window functions compute a value for each row by looking at a "window" — a subset of rows defined by PARTITION BY (think GROUP BY but without collapsing rows) and ORDER BY within that partition. ROW_NUMBER assigns a unique sequential number starting at 1; if two rows are tied on the ORDER BY column it picks an arbitrary one to go first, so you get 1, 2, 3, 4 with no repeated numbers. RANK assigns the same number to tied rows but then skips ahead — two rows tied for first both get rank 1, and the next row gets rank 3 (rank 2 is skipped), which can look confusing to end users. DENSE_RANK also assigns the same rank to ties but does not skip — two rows tied for first get rank 1, the next row gets rank 2, no gaps. Beyond these three, the window function family includes LAG and LEAD (access the value from a preceding or following row without a self-join), FIRST_VALUE and LAST_VALUE (get the first or last value in the window frame), SUM and AVG OVER (running totals or moving averages), and NTILE(n) which divides rows into n roughly equal buckets. All of these use the OVER clause and do not collapse the result set, which is why they're more powerful than GROUP BY for per-row computations.

*The key differentiator to say explicitly: RANK has gaps, DENSE_RANK has no gaps. Draw 1,1,3 vs 1,1,2 mentally and describe it.*

> **Gotcha follow-up:** When would you use ROW_NUMBER instead of RANK?
> ROW_NUMBER is ideal when I need exactly one row per group — for example, the "top 1 order per customer" query where I want a unique number so I can filter `WHERE rn = 1`. If I used RANK and two orders tied, I'd get two rows back for that customer, which might break downstream logic expecting a single row.

---

**Q4: CTE vs Subquery**
*Concept Check*

**One-line answer:** A CTE (WITH clause) is a named, readable temporary result set; a subquery is inline — but the key difference is a CTE can be referenced multiple times and supports recursion.

**Full answer:**
A subquery is an anonymous query nested inside another query, either in the FROM clause (derived table) or in a WHERE/SELECT clause. A correlated subquery is one that references a column from the outer query — it re-executes once per outer row, which can be an O(N) performance issue on large tables. A CTE, written with the WITH keyword before the main SELECT, gives the intermediate result a name and separates it visually from the main logic, which dramatically improves readability for complex queries. In most databases, a CTE is expanded inline by the optimizer — meaning it's not actually stored anywhere, just substituted like a macro — so there's no automatic performance benefit over a subquery. However, PostgreSQL allows the MATERIALIZED keyword on a CTE to force it to execute once and cache the result, which is useful when the same CTE is referenced multiple times and the optimizer would otherwise re-evaluate it each time. CTEs also unlock recursive queries with the WITH RECURSIVE syntax (used for tree traversal), which subqueries cannot do. My rule of thumb: use a CTE whenever the query is complex enough that naming intermediate steps improves readability, or when I need recursion or multiple references to the same derived result.

*Mention the "inline by default" behaviour — most candidates assume CTEs are always materialized and interviewers will probe that assumption.*

> **Gotcha follow-up:** When would a CTE actually hurt performance compared to a subquery?
> When the optimizer would normally push a filter down into a subquery (predicate pushdown), marking a CTE as MATERIALIZED prevents that — the CTE runs in full before the outer filter is applied. So if I write `WITH x AS MATERIALIZED (SELECT * FROM huge_table) SELECT * FROM x WHERE id = 1`, the entire huge_table is scanned first. A plain subquery would let the planner apply the WHERE id = 1 filter early.

---

**Q5: UNION vs UNION ALL**
*Concept Check*

**One-line answer:** UNION deduplicates rows (slower); UNION ALL keeps everything (faster) — use UNION ALL unless duplicates are actually a problem.

**Full answer:**
Both UNION and UNION ALL vertically stack the results of two SELECT statements, and both require the same number of columns with compatible data types in each SELECT. The difference is what happens to duplicate rows: UNION implicitly applies a DISTINCT operation across the combined result, which means the database must sort or hash the entire result set to find and remove duplicates — that's extra CPU and memory work. UNION ALL simply concatenates the two result sets without any deduplication step, making it significantly faster. In practice, I default to UNION ALL and only switch to UNION if I genuinely need deduplication — for example, combining two queries against different shards where the same row could theoretically appear in both. A common mistake I watch for is using UNION when the two queries are against non-overlapping data (say, orders from 2023 and orders from 2024) where duplicates are structurally impossible — UNION ALL is correct there and avoids a wasteful sort.

*Lead with the performance implication — interviewers want to know you default to UNION ALL deliberately, not by accident.*

> **Gotcha follow-up:** Can you ORDER BY in individual SELECT statements within a UNION ALL?
> No — in SQL standard and most databases, ORDER BY is only valid on the final combined result. Each individual SELECT contributes unordered rows to the union. If I need to sort the final output I put a single ORDER BY at the end of the whole UNION ALL query.

---

**Q6: NULL Three-Valued Logic**
*Concept Check*

**One-line answer:** NULL is not a value — it means "unknown" — so any comparison involving NULL returns UNKNOWN, not TRUE or FALSE, and WHERE only keeps TRUE rows.

**Full answer:**
SQL uses three-valued logic: TRUE, FALSE, and UNKNOWN. NULL represents the absence of a known value — it's not zero, not empty string, not false. When I compare anything to NULL using =, !=, <, or >, the result is UNKNOWN, not TRUE or FALSE. This means `NULL = NULL` is UNKNOWN (not TRUE), which surprises most developers. The WHERE clause only passes rows where the condition is TRUE — UNKNOWN is silently discarded, which means NULL rows quietly disappear from results if I'm not careful. The correct way to test for NULL is `IS NULL` or `IS NOT NULL`, which are special predicates designed for this purpose. This also affects aggregate functions: COUNT(*) counts all rows including NULLs, but COUNT(col) only counts rows where col is not NULL, and SUM/AVG silently skip NULL values in their calculation. In boolean expressions, `NULL AND FALSE` is FALSE (because the result can't be true regardless of the NULL), but `NULL AND TRUE` is UNKNOWN — the three-value logic has specific rules that are worth knowing for complex WHERE conditions.

*The classic trap is `WHERE col != 'x'` not returning rows where col IS NULL — state this explicitly.*

> **Gotcha follow-up:** What does `WHERE col NOT IN (1, 2, NULL)` return?
> It returns no rows. NOT IN with a NULL in the list expands to `col != 1 AND col != 2 AND col != NULL`. The last condition is UNKNOWN, and UNKNOWN AND anything is UNKNOWN (or FALSE), so every row is excluded. This is the famous NOT IN / NULL trap.

---

**Q7: NOT IN with NULLs Trap**
*Tradeoff Question*

**One-line answer:** If the subquery inside NOT IN returns even one NULL, the entire NOT IN clause returns no rows — always use NOT EXISTS instead.

**Full answer:**
This is one of the most dangerous silent bugs in SQL. When I write `WHERE customer_id NOT IN (SELECT customer_id FROM orders)`, the subquery might return NULLs if the customer_id column in orders has any NULL values. NOT IN desugars to a series of `!=` comparisons ANDed together: `customer_id != 1 AND customer_id != 2 AND customer_id != NULL`. That last comparison evaluates to UNKNOWN, and since the entire AND chain must be TRUE for the row to pass, every row ends up as UNKNOWN or FALSE — the result set is empty regardless of the data. The safe rewrite is NOT EXISTS: `WHERE NOT EXISTS (SELECT 1 FROM orders WHERE orders.customer_id = c.customer_id)`. NOT EXISTS uses a correlated subquery — one that references the outer query's row — and its truth value is based on whether rows are found, not on value comparisons, so NULLs don't poison it. Alternatively, I can add `WHERE customer_id IS NOT NULL` inside the subquery, but NOT EXISTS is cleaner and expresses the intent more clearly.

*Frame this as a real bug you watch for in code review — it's subtle, causes zero error messages, and returns silently empty results.*

> **Gotcha follow-up:** Does IN have the same NULL problem?
> Partially. `IN (1, NULL)` will still match rows where the column equals 1, because the match on 1 returns TRUE (and TRUE OR anything is TRUE). But it will never match rows where the column is NULL itself (since NULL = NULL is UNKNOWN). So IN silently drops NULL-valued rows from matching, while NOT IN with a NULL completely empties the result.

---

**Q8: GROUP BY vs HAVING**
*Concept Check*

**One-line answer:** WHERE filters rows before grouping; HAVING filters groups after aggregation — they are not interchangeable.

**Full answer:**
The distinction comes directly from the logical execution order. WHERE runs before GROUP BY, so it filters individual rows before they're bucketed into groups. HAVING runs after GROUP BY, so it filters the resulting groups, and it can reference aggregate functions like COUNT, SUM, AVG. A concrete example: if I want departments with more than 10 employees, I cannot write `WHERE COUNT(*) > 10` — WHERE fires before the grouping happens, so the count doesn't exist yet. I must write `HAVING COUNT(*) > 10`. Conversely, if I want to exclude a specific department before grouping, I should put that in WHERE, not HAVING — it's more efficient because fewer rows enter the grouping phase. ANSI SQL also requires that any non-aggregated column in the SELECT list must appear in the GROUP BY clause — this prevents ambiguity about which row's value to pick when multiple rows collapse into one group. Some databases like MySQL are lenient about this in non-strict mode, but PostgreSQL enforces it strictly.

*The performance point matters — WHERE before GROUP BY means the aggregation engine works on fewer rows. Mention this to show you think about execution, not just syntax.*

> **Gotcha follow-up:** Can I use a SELECT alias in HAVING?
> In standard SQL, no — HAVING runs before SELECT in the logical order, so aliases aren't resolved yet. PostgreSQL and some other databases are permissive and allow it as an extension, but for portable SQL I'd use the full expression or a subquery wrapping the original query.

---

**Q9: COUNT(*) vs COUNT(col)**
*Concept Check*

**One-line answer:** COUNT(*) counts all rows including NULLs; COUNT(col) counts only non-NULL values in that column — and the difference can silently skew your results.

**Full answer:**
COUNT(*) is the most general — it counts the number of rows in the group regardless of what's in any column, including rows where every column is NULL. COUNT(col) counts only rows where col is not NULL, so if 20% of rows have a NULL in that column, COUNT(col) will be 20% lower than COUNT(*). This becomes a real trap when computing ratios — for example, if I divide SUM(revenue) by COUNT(customer_id) to get average revenue per transaction, and some rows have NULL customer_id, I'll get a higher average than reality because the denominator is smaller. COUNT(DISTINCT col) counts the number of distinct non-NULL values, which is useful for cardinality estimation but can be slow on large tables without a specialized index. The same NULL-ignoring behaviour applies to SUM and AVG: SUM(col) adds only non-NULL values, and AVG(col) divides the sum by the count of non-NULL values — not the total row count — which means AVG can differ significantly from SUM/COUNT(*).

*Always state: "AVG ignores NULLs in both numerator and denominator" — this is the most misunderstood part.*

> **Gotcha follow-up:** How would you count the number of NULLs in a column?
> I'd use `COUNT(*) - COUNT(col)` — the difference between total rows and non-NULL values in that column gives the NULL count. Alternatively, `SUM(CASE WHEN col IS NULL THEN 1 ELSE 0 END)` is explicit and self-documenting.

---

**Q10: Correlated Subquery**
*Tradeoff Question*

**One-line answer:** A correlated subquery references the outer query's row and re-executes once per outer row — it's O(N) and should usually be replaced with a window function.

**Full answer:**
A correlated subquery is one where the inner SELECT references a column from the outer query. For example, to find employees earning more than their department's average: `SELECT * FROM employees e WHERE salary > (SELECT AVG(salary) FROM employees WHERE dept_id = e.dept_id)`. The inner subquery references `e.dept_id`, so for every row in the outer query the database re-runs the subquery for that specific department. If there are 100,000 employees, the inner AVG query runs 100,000 times — that's O(N) subquery executions, which is catastrophically slow on large tables even if each subquery is fast. The correct rewrite uses a window function: `SELECT *, AVG(salary) OVER (PARTITION BY dept_id) AS dept_avg FROM employees` — the average is computed once per partition, then joined back to each row. The result is a single pass over the data. Correlated subqueries do have legitimate uses where the equivalent window function is awkward — for example, EXISTS checks or when you need to reference multiple outer columns — but for aggregate comparisons, I always reach for window functions first.

*State "O(N) subquery executions" explicitly — that's the alarming phrase that makes the interviewer nod.*

> **Gotcha follow-up:** Can the optimizer automatically rewrite a correlated subquery to a join or window function?
> Modern optimizers (PostgreSQL, SQL Server) can sometimes decorrelate simple correlated subqueries into hash joins or lateral joins automatically. But this transformation is not guaranteed, especially for complex correlations. I never rely on the optimizer to fix a correlated subquery — I rewrite it explicitly so the intent is clear and the plan is predictable.

---

**Q11: EXPLAIN Output — Key Nodes**
*Concept Check*

**One-line answer:** EXPLAIN shows how the planner will execute a query — the key is spotting Seq Scans on large tables, high-cost Sort nodes, and estimates that diverge wildly from actuals.

**Full answer:**
EXPLAIN (or EXPLAIN ANALYZE in PostgreSQL, which actually runs the query and shows real timings) produces a tree of plan nodes. A Sequential Scan (Seq Scan) means the database reads every page of the table in order — fine for small tables, a red flag for large ones if an index should apply. An Index Scan uses an index to find matching row pointers, then fetches the actual rows from the heap (the main table storage) — this involves random I/O to the heap, which can be slower than expected for many rows. An Index Only Scan is the best case: all needed columns are in the index itself (a covering index), so the heap is never touched. A Bitmap Heap Scan is a middle ground — it first scans the index to build an in-memory bitmap of which heap pages contain matches, then fetches those pages in order; this is more efficient than random Index Scan when a moderate number of rows match. For joins, Hash Join builds a hash table from the smaller side and probes it with the larger side — good for large unsorted datasets. Nested Loop works for each outer row by scanning the inner — efficient when the inner is small or accessed by index. Merge Join requires both sides sorted on the join key, then zips them together — efficient for large pre-sorted or indexed sets. The most important things I look for: huge differences between estimated and actual row counts (stale statistics — run ANALYZE to fix), Seq Scans on large tables that should have an index, and Sort nodes that spill to disk (indicated by "Batches: >1" in PostgreSQL).

*Walk through a concrete plan hierarchy verbally — it shows you've actually used EXPLAIN, not just read about it.*

> **Gotcha follow-up:** Why might the planner choose a Seq Scan even when an index exists?
> If the query returns a large fraction of the table (typically more than 5–15%), random I/O to individual heap rows via the index costs more than a single sequential pass through the table. The planner estimates row counts using statistics (pg_statistic) and chooses the cheaper path. An outdated statistics can also cause wrong choices — running ANALYZE refreshes them.

---

**Q12: Materialized View vs Regular View**
*Tradeoff Question*

**One-line answer:** A regular view is a saved query with no storage — always fresh, always slow; a materialized view is a physical snapshot — fast, but stale until refreshed.

**Full answer:**
A regular view is just a named SELECT statement stored in the database catalog. Every time I query the view, the database re-runs the underlying query against the live base tables — so results are always current, but performance depends entirely on how expensive the underlying query is. There's no caching. A materialized view (supported in PostgreSQL, Oracle, SQL Server) physically stores the query result on disk like a table. Reads are fast because they hit precomputed data. The downside is staleness: the data doesn't update automatically when the base tables change — I must explicitly run REFRESH MATERIALIZED VIEW. In PostgreSQL, `REFRESH MATERIALIZED VIEW CONCURRENTLY` rebuilds the view in the background without locking out readers, but it requires a unique index on the materialized view. I use materialized views for expensive aggregation queries that power dashboards or reports where slight staleness (refreshed every hour, or triggered after batch loads) is acceptable. Regular views are better for abstraction and security — hiding complex joins or sensitive columns — where freshness is required.

*The "CONCURRENTLY requires a unique index" detail separates candidates who've used this in production from those who just read the docs.*

> **Gotcha follow-up:** What happens if you forget to add CONCURRENTLY and refresh a materialized view on a live production table?
> Without CONCURRENTLY, PostgreSQL acquires an exclusive lock on the materialized view for the duration of the refresh, blocking all reads against it. On a busy reporting database this can cause cascading query timeouts. CONCURRENTLY avoids this by computing the diff and applying it incrementally, but it takes longer and requires the unique index precondition.

---

**Q13: GROUPING SETS / ROLLUP / CUBE**
*Concept Check*

**One-line answer:** These are shorthand for running multiple GROUP BY levels in one query — ROLLUP does hierarchical subtotals, CUBE does all combinations, GROUPING SETS is explicit.

**Full answer:**
Traditional SQL lets me GROUP BY a fixed set of columns, producing one level of aggregation per query. GROUPING SETS, ROLLUP, and CUBE are extensions that let me compute multiple grouping levels in a single query without UNION ALL. GROUPING SETS lets me specify exactly which combinations I want — `GROUP BY GROUPING SETS ((region, product), (region), ())` gives me region+product subtotals, region-only subtotals, and a grand total (empty parentheses mean "no grouping — aggregate everything"). ROLLUP is a shorthand for hierarchical grouping — `ROLLUP(region, product)` produces (region, product), then (region alone), then () grand total — it always drills up the hierarchy left to right. CUBE goes further — `CUBE(region, product)` produces all 2^N combinations: (region, product), (region), (product), and (). These are especially useful in reporting queries where I'd otherwise write three separate GROUP BY queries and UNION ALL them together; the single-query version is both more readable and allows the optimizer to share the scan of the base table.

*The empty-parentheses grand total `()` trips people up — say it explicitly and give the intuition for it.*

> **Gotcha follow-up:** How do you tell, in the result set, which rows are subtotals vs detail rows?
> The GROUPING() function returns 1 for columns that were suppressed in a particular grouping level and 0 for columns that participated. For example, `GROUPING(product)` returns 1 on the region-only subtotal rows where product was rolled up. I use this in a CASE expression to label those rows "Subtotal" or to distinguish them from detail rows in application logic.

---

**Q14: LATERAL Join**
*Concept Check*

**One-line answer:** LATERAL lets a subquery in the FROM clause reference columns from earlier in the same FROM clause — essentially a correlated subquery that can return multiple rows and columns.

**Full answer:**
In a standard FROM clause, each table or subquery is independent — you can't reference columns from one table while defining another. LATERAL removes that restriction: a LATERAL subquery can reference columns from preceding FROM items, making it behave like a correlated subquery but with the full power of returning multiple rows and columns. The canonical use case is "get the N most recent orders for each customer" — a correlated scalar subquery can return only one value, but LATERAL can return multiple rows per customer, which I then join to. In PostgreSQL I write `FROM customers c, LATERAL (SELECT * FROM orders WHERE customer_id = c.id ORDER BY created_at DESC LIMIT 3) recent_orders`. The SQL Server equivalent is CROSS APPLY (for cases where the subquery must return at least one row) and OUTER APPLY (for cases where no-match rows should be preserved with NULLs, analogous to LEFT JOIN). MySQL added LATERAL support in version 8.0. Without LATERAL, achieving the same result requires either a window function with a filter (less intuitive) or a more complex self-join with row number filtering.

*Mention CROSS APPLY / OUTER APPLY for SQL Server — it shows cross-database awareness.*

> **Gotcha follow-up:** What's the difference between a plain correlated subquery in SELECT and a LATERAL in FROM?
> A correlated subquery in SELECT returns exactly one scalar value per row — if it returns more than one row, the database throws an error. LATERAL in FROM can return multiple rows and multiple columns, and those rows are joined (multiplied) with the outer row. So LATERAL is strictly more powerful — use a SELECT subquery for a single value, LATERAL for a set of rows.

---

**Q15: Recursive CTE**
*Concept Check*

**One-line answer:** A recursive CTE uses WITH RECURSIVE to repeatedly join a query back to itself until no new rows are produced — the standard tool for tree and graph traversal in SQL.

**Full answer:**
A recursive CTE has two parts separated by UNION ALL inside the WITH RECURSIVE block. The anchor member is the base case — it runs once and produces the starting rows (for example, the root node of an org chart). The recursive member joins the CTE back to itself or to another table to find the next level (for example, employees whose manager_id matches an id already in the CTE). The database alternates: run the recursive part against the current result, add new rows, repeat — until the recursive part returns an empty set. This is the standard SQL way to walk hierarchical data like org charts, bill-of-materials structures, or category trees without needing application-level recursion. The termination condition is implicit: when the recursive query produces no new rows it stops. The danger is cycles in the data — if employee A manages B and B manages A, the recursion never terminates. I guard against this with a depth counter: add a `level` column to the anchor (starting at 1), increment it in the recursive member, and add `WHERE level < 20` to prevent runaway loops. PostgreSQL also supports a CYCLE clause to explicitly detect and break cycles.

*The "add a level guard" advice is a practical production detail that distinguishes real experience from textbook knowledge.*

> **Gotcha follow-up:** Can you use UNION instead of UNION ALL in a recursive CTE?
> Technically yes in some databases — UNION would deduplicate rows at each iteration, which could help break certain cycles. But it's much slower because deduplication requires hashing or sorting every intermediate result. The preferred approach is UNION ALL with an explicit level or visited-set guard rather than relying on UNION's deduplication for correctness.

---

**Common Mistakes:**
- **Using WHERE to filter aggregate results** → the query errors or gives wrong results; use HAVING for post-aggregation filters.
- **NOT IN with a nullable subquery** → returns zero rows silently; always use NOT EXISTS or add IS NOT NULL to the subquery.
- **UNION instead of UNION ALL on non-overlapping data** → unnecessary sort/hash dedup pass; default to UNION ALL and add UNION only when deduplication is proven necessary.
- **Correlated subquery for per-group aggregates** → O(N) re-executions; replace with window functions.
- **Forgetting leftmost prefix on composite index** → index silently unused; confirm with EXPLAIN.

**Quick Revision:** SQL execution order (FROM→WHERE→GROUP BY→HAVING→SELECT→ORDER BY) is the root cause of half of all SQL surprises — memorise it and derive the rules from it.

---

## Section 2: Indexing

**Q1: B-tree Index Structure**
*Concept Check*

**One-line answer:** A B-tree index is a self-balancing tree where all leaf nodes are at the same depth, giving O(log N) lookup and efficient range scans.

**Full answer:**
A B-tree (Balanced Tree) index organises data in a tree of pages. At the top is the root page, which contains key ranges and pointers to internal (branch) pages, which in turn point to leaf pages. The leaf pages contain the actual indexed key values plus pointers to the corresponding heap rows (the actual table data stored separately). Because the tree is always balanced — all leaf nodes sit at the same depth — every single-key lookup traverses exactly the same number of levels, typically 3 to 4 levels for tables with millions of rows. This gives O(log N) lookup time. B-trees also support range scans efficiently because the leaf pages are linked in order — once I find the starting key I can follow leaf-page pointers sequentially without going back up the tree. PostgreSQL uses B-tree as the default index type. MySQL's InnoDB uses a variant called B+ tree where all actual row data lives in the leaf pages of the primary key index (the clustered index), and secondary indexes store the primary key value rather than a direct heap pointer. This distinction matters because in InnoDB a secondary index lookup always involves two steps: find the primary key in the secondary index, then traverse the clustered index to get the full row.

*Mention the 3-4 level height for millions of rows — it makes the O(log N) claim concrete and memorable.*

> **Gotcha follow-up:** Why does a B-tree index slow down random UUID inserts?
> B-tree leaf pages are ordered by key. Sequential keys (like auto-increment integers) always insert at the rightmost leaf page. Random UUIDs insert anywhere in the tree, causing page splits throughout — when a leaf page is full and a new key must go in the middle, the page is split in two. Frequent splits fragment the index, increase its size, cause cache misses, and slow down inserts. UUID v7 or ULID (both time-ordered) solve this by keeping insertions sequential while remaining globally unique.

---

**Q2: Composite Index — Leftmost Prefix Rule**
*Concept Check*

**One-line answer:** A composite index on (a, b, c) is only used if the query filters on the leftmost column a — skipping the first column makes the index useless.

**Full answer:**
A composite index sorts data first by column a, then by b within each a value, then by c within each b value. This means the index is ordered and searchable only when I start from the left. A query with `WHERE a = 1` can use the index to jump directly to all rows where a equals 1. A query with `WHERE a = 1 AND b = 2` uses the index further — after narrowing by a, it narrows by b. A query with `WHERE a = 1 AND b > 5` uses the index for a and b, but after the range condition on b, column c is not usable — range stops the leftmost prefix from extending further right. A query with only `WHERE b = 2` cannot use the index at all because b is not the leftmost column — there's no shortcut to "rows where b = 2" in the sort order. The practical design rule: put equality-filter columns first (they narrow the most), range-filter columns last (they stop further leftward use), and order by selectivity within that. If I need to search by b alone frequently, I should create a separate index starting with b.

*Draw out the sort order mentally and explain why skipping the first column breaks the navigation — the intuition is the key.*

> **Gotcha follow-up:** Does column order in WHERE matter for using a composite index?
> No — the query planner is smart enough to rearrange WHERE conditions. `WHERE b = 2 AND a = 1` will use the index on (a, b) just as well as `WHERE a = 1 AND b = 2`. What matters is which columns are present in the predicate, not their order in the SQL text.

---

**Q3: Covering Index**
*Concept Check*

**One-line answer:** A covering index contains all columns needed by a query, so the database never touches the main table (heap) — giving the fastest possible read path.

**Full answer:**
After the index finds the matching rows, the database normally has to fetch the actual row from the heap (the main table storage) to retrieve columns not in the index. This heap fetch involves random I/O — potentially one disk read per row — which is expensive. A covering index eliminates this by storing all the columns the query needs directly in the index. If my query is `SELECT email FROM users WHERE user_id = 42`, an index on (user_id, email) is covering — the planner sees it can get user_id (for filtering) and email (for output) entirely from the index, so it performs an Index Only Scan with no heap touch. PostgreSQL 11+ introduced INCLUDE columns on indexes: `CREATE INDEX ON orders (customer_id) INCLUDE (order_total, created_at)`. The INCLUDE columns are stored only in the leaf pages of the index, not in the internal branch nodes. This means they don't inflate the size of the tree structure (which would slow down traversal), but they do satisfy queries that need those columns after filtering by customer_id. The trade-off: every write to the table must also update the index, including its INCLUDE columns, so I balance read performance gain against write overhead.

*The INCLUDE vs key-column distinction is PostgreSQL-specific but shows depth — mention it naturally.*

> **Gotcha follow-up:** Can a covering index help a query that uses ORDER BY?
> Yes — if the ORDER BY matches the index order and all selected columns are in the index, the planner can use the index to deliver rows in sorted order without a separate Sort node. This eliminates one of the most expensive plan operations. I always check EXPLAIN for Sort nodes and ask whether a covering index with the right column order could remove them.

---

**Q4: Index Selectivity**
*Concept Check*

**One-line answer:** Selectivity is the fraction of distinct values in a column — high selectivity means the index filters aggressively and is worth using; low selectivity means it may be slower than a full table scan.

**Full answer:**
Selectivity is formally defined as distinct_values / total_rows, giving a number between 0 and 1. A column like user_id or email with nearly unique values has selectivity close to 1 — an index on it finds a tiny fraction of the table, making random I/O to fetch those rows cheap relative to scanning everything. A column like `status` with three possible values (active, inactive, deleted) has selectivity of roughly 3 / row_count, approaching 0 — an index on it might return 30% of the table for a single value query. When the index scan would touch more than roughly 5–15% of the table's rows, the cost of random I/O per row exceeds the cost of one sequential table scan, and the optimizer correctly ignores the index. This is why indexing a boolean column is usually pointless — if 50% of rows are true, an index scan for `WHERE active = true` touches half the table via random I/O, far worse than a seq scan. The exception is a partial index (covered in Q6) which creates an index only on the interesting subset, dramatically improving selectivity.

*The "5-15% threshold" for when index beats seq scan is a useful mental model — state it with the caveat that it depends on hardware (SSD vs HDD).*

> **Gotcha follow-up:** How does the optimizer know the selectivity of a column?
> PostgreSQL maintains per-column statistics in the pg_statistic system catalog — histograms, most-common values, and their frequencies. These are populated by the ANALYZE command (run automatically by autovacuum). If statistics are stale or the data distribution is highly skewed, the planner can make poor choices. Running ANALYZE manually after a large data load forces a refresh.

---

**Q5: Clustered vs Non-Clustered Index (InnoDB)**
*Concept Check*

**One-line answer:** In InnoDB (MySQL), the clustered index IS the table — rows are physically stored in primary key order; every other index is non-clustered and stores the PK as its row pointer.

**Full answer:**
In InnoDB, there is exactly one clustered index per table, and it is always the primary key. The actual row data — all columns — lives in the leaf pages of this clustered index, sorted by primary key value. A lookup by primary key traverses the B+ tree and arrives directly at the row data: one tree traversal, data in hand. A non-clustered index (any secondary index in InnoDB) has its own B+ tree structure, but its leaf pages contain the indexed column's value plus the primary key value, not a direct pointer to the row. So a secondary index lookup is two steps: traverse the secondary index tree to find the primary key, then traverse the clustered index tree again to fetch the full row. This "double dip" is called a clustered index lookup or bookmark lookup. This has an important implication: keeping the primary key small (like an 8-byte BIGINT vs a 16-byte UUID) reduces the size of every secondary index because every secondary index leaf embeds the PK. PostgreSQL uses a different architecture: heap-based storage where rows are stored in unordered pages, and all indexes (including the primary key index) store a tuple ID (page number + row offset). There is no physical clustering unless I manually run the CLUSTER command, which sorts the heap once but is not maintained on subsequent writes.

*The "every secondary index embeds the PK" consequence of InnoDB's design is a frequently asked follow-up — pre-empt it.*

> **Gotcha follow-up:** What happens if a table has no primary key in InnoDB?
> InnoDB requires a clustered index, so if I don't define a primary key it looks for a NOT NULL UNIQUE column to use instead. If none exists, InnoDB silently creates a hidden 6-byte row ID (GEN_CLUST_INDEX) as the clustered index. This hidden key is invisible to the application, non-sequential writes are slower, and secondary indexes grow larger because they embed the hidden key. Always define an explicit primary key.

---

**Q6: Partial Index**
*Concept Check*

**One-line answer:** A partial index is built only on rows matching a WHERE predicate — smaller, faster, and only usable for queries that include that predicate.

**Full answer:**
A full index on a column indexes every row in the table regardless of value. A partial index filters the rows that are indexed: `CREATE INDEX idx_active_users ON users (email) WHERE active = true`. This index contains only the rows of active users. If the table has 10 million users but only 50,000 are active, the index is 200× smaller than a full index on email. Smaller means it fits more easily in memory (the database's buffer pool — the in-memory cache of pages), which means fewer disk reads, faster traversal, and less write overhead because only inserts/updates that affect active rows touch the index. For the planner to use a partial index, the query's WHERE clause must imply the index predicate — `WHERE active = true AND email = 'x@example.com'` satisfies the predicate, so the partial index is eligible. A query with only `WHERE email = 'x@example.com'` (no active filter) cannot use the partial index because it might need to return inactive users too. This is also a powerful technique for unique constraints on subsets: `CREATE UNIQUE INDEX ON bookings (seat_id) WHERE status = 'confirmed'` enforces that no two confirmed bookings share a seat, while allowing multiple cancelled bookings for the same seat.

*The unique partial index use case is excellent to mention — it solves a common real-world constraint problem elegantly.*

> **Gotcha follow-up:** Can you create a partial index in MySQL?
> No — MySQL does not support partial indexes. This is a significant feature gap compared to PostgreSQL. In MySQL, the closest alternative is a generated (computed) column combined with a regular index, or using a filtered query with an index and accepting that the index covers more rows than needed. This is one reason I prefer PostgreSQL for workloads with heterogeneous data distributions.

---

**Q7: Functional / Expression Index**
*Concept Check*

**One-line answer:** An expression index stores the precomputed result of a function applied to a column — it makes queries that always apply that function to a column use the index.

**Full answer:**
A standard index on a column stores the raw column value. If my queries always apply a function before comparing — for example, `WHERE LOWER(email) = 'alice@example.com'` for case-insensitive lookups — a regular index on email is useless because the planner needs the lowercased value, not the raw value, to navigate the index tree. An expression index solves this: `CREATE INDEX ON users (LOWER(email))`. Now the index stores LOWER(email) for every row, and the planner can use it for queries with `WHERE LOWER(email) = ...`. The critical requirement is that the query must use the exact same expression as the index definition — `WHERE LOWER(email) = 'x'` uses it, but `WHERE email = 'X'` does not (different expression). Expression indexes are also how I index into JSON fields without GIN: `CREATE INDEX ON events ((payload->>'event_type'))` indexes a specific JSON key's value. The trade-off is write overhead: every INSERT or UPDATE that changes the email column must also recompute LOWER(email) and update the index.

*Emphasise "exact same expression" — it's the most common reason expression indexes silently go unused.*

> **Gotcha follow-up:** How would you make a case-insensitive unique constraint in PostgreSQL?
> I'd create a unique expression index: `CREATE UNIQUE INDEX ON users (LOWER(email))`. This enforces uniqueness on the lowercased value, so 'Alice@example.com' and 'alice@EXAMPLE.COM' would conflict. I'd also always normalize input to lowercase before inserting, both for the constraint and for consistent queries.

---

**Q8: GIN Index for JSONB**
*Concept Check*

**One-line answer:** A GIN (Generalized Inverted Index) indexes each key and value inside a JSONB document separately, enabling fast containment and key-existence queries at the cost of slower writes.

**Full answer:**
A B-tree index stores values atomically — it can only compare one ordered scalar value per entry. JSONB columns contain nested documents where I might query any key at any level. A GIN index solves this by decomposing each JSONB document into individual key-value pairs and indexing each one as a separate entry — similar to how a book index maps each word to the pages it appears on. This enables three operators that only GIN supports: `@>` (does the document contain this sub-document?), `<@` (is this document contained by another?), and `?` (does this key exist?). For example, `WHERE payload @> '{"status": "active"}'` uses the GIN index to find all rows whose payload JSON contains that key-value pair. GIN indexes are more expensive to build and maintain than B-tree — each document write must update potentially many index entries — so they're best on read-heavy JSONB columns where flexible querying is more important than write throughput. GIN is also used for PostgreSQL full-text search (where it indexes each lexeme — a normalized word token — in a tsvector) and for array containment queries.

*The connection to full-text search tsvectors shows breadth — mention it as a bonus.*

> **Gotcha follow-up:** Can you use a B-tree index to query a specific JSONB key?
> Yes, but only by creating an expression index on that specific key path: `CREATE INDEX ON events ((payload->>'event_type'))`. This creates a B-tree index on a single extracted value, enabling fast equality and range queries on that specific key. It's much more efficient than GIN for queries that always target the same known key, and has lower write overhead. GIN is better when the keys being queried vary or when you need containment checks across arbitrary paths.

---

**Q9: Why Low-Cardinality Index Hurts**
*Tradeoff Question*

**One-line answer:** A low-cardinality index (like a boolean) causes random I/O to fetch many rows, which is more expensive than reading the table sequentially — so the optimizer ignores it.

**Full answer:**
An index scan is only faster than a sequential scan when it significantly reduces the number of pages I need to touch. When a column has low cardinality — few distinct values — a WHERE clause on it matches a large fraction of rows. For a boolean `active` column where 50% of rows are true, an index scan for `WHERE active = true` returns half the table. But accessing half the table via index means following pointers to heap rows that are scattered across all data pages, causing random I/O — potentially one disk read per row. A sequential scan, by contrast, reads every page once in order, benefiting from OS prefetching and hardware sequential read speeds. On spinning disks the difference is dramatic; on SSDs it's less severe but still real. The database optimizer uses cost estimates: index scan cost is proportional to rows × random_page_cost; seq scan cost is proportional to total_pages × seq_page_cost. When index scan cost exceeds seq scan cost, the planner ignores the index. PostgreSQL offers a middle ground: a Bitmap Index Scan, which first scans the index to build a bitmap of matching heap page numbers, then fetches those pages in page-sorted order — more sequential than a plain index scan, viable at moderate selectivity.

*The cost formula (rows × random_page_cost vs total_pages × seq_page_cost) shows you understand the optimizer's model, not just the outcome.*

> **Gotcha follow-up:** How would you efficiently query a low-cardinality status column?
> Several options: a partial index on the interesting subset (if only one value is queried far more than others); a composite index where status is the second column and a high-cardinality column is first (improving overall selectivity); or for OLAP queries, accepting a seq scan and tuning the query plan via parallel seq scans. Sometimes the right answer is just: don't index it, let the seq scan run, and add it to a composite index where it reduces the result set in combination with more selective columns.

---

**Q10: UUID vs BIGINT PK — Fragmentation**
*Tradeoff Question*

**One-line answer:** Random UUID primary keys cause B-tree page splits throughout the index, fragmenting it and slowing inserts — UUID v7 or BIGINT eliminates this.

**Full answer:**
A BIGINT SERIAL or IDENTITY primary key generates sequentially increasing values — 1, 2, 3, and so on. In a B-tree clustered index (InnoDB) or any B-tree index, sequential keys always insert at the rightmost leaf page, which splits cleanly: the current page fills up, a new page is appended to the right. This is very efficient — minimal page splits, compact index, good cache locality. UUID v4 is randomly generated — each new UUID is equally likely to fall anywhere in the 128-bit key space. This means inserts land in the middle of existing leaf pages scattered throughout the tree, causing page splits at random locations. Over time the index becomes fragmented: pages are partially filled, the index is larger than it needs to be, traversal requires more page reads, and the buffer pool (memory cache) is less effective because many pages are accessed once and evicted. UUID v7 solves this: it embeds a millisecond-precision timestamp in the most significant bits, making new UUIDs sort after all previous ones — so inserts are sequential like BIGINT but the identifier is still globally unique and opaque. ULID (Universally Unique Lexicographically Sortable Identifier) is a similar concept. If I'm stuck with v4 UUIDs, periodic VACUUM FULL or REINDEX reclaims fragmented space, but this is disruptive.

*Always mention UUID v7 / ULID as the modern solution — it's on every senior engineer's radar now.*

> **Gotcha follow-up:** Why does UUID v4 fragmentation matter more for clustered indexes than non-clustered?
> In a clustered index (InnoDB primary key), the row data itself is stored in the B-tree leaf pages, so fragmentation directly affects the physical layout of the table — full row fetches suffer from cache misses. In a non-clustered index, the leaf stores only the key and a pointer, so fragmentation inflates the index structure but the heap data layout is separate. Both are hurt by fragmentation, but the clustered case is worse because the data pages themselves are scattered.

---

**Q11: FK Not Auto-Indexed in PostgreSQL**
*Concept Check*

**One-line answer:** PostgreSQL does NOT automatically create an index on foreign key columns — unindexed FKs cause sequential scans on every join and slow down parent-row deletions.

**Full answer:**
In PostgreSQL, declaring a FOREIGN KEY constraint only adds the referential integrity check — it does not create an index on the referencing (child) column. MySQL InnoDB automatically creates an index on the FK column if one doesn't already exist, which is why this trap often surprises developers coming from MySQL. Without an index on the FK column, any query that joins through the FK — `SELECT * FROM orders JOIN customers ON orders.customer_id = customers.id` — causes a sequential scan of the orders table for each customer row, unless the planner can choose a hash join (which still scans the full orders table once). More insidiously, when I delete a parent row, PostgreSQL must check the child table for referencing rows to enforce the FK constraint. Without an index it scans the entire child table, holding a lock during that scan — on large tables this can cause lock contention and timeouts. The fix is simple: `CREATE INDEX ON orders (customer_id)` immediately after the FK declaration. I audit unindexed FKs by checking pg_constraint joined against pg_index.

*The delete-time lock escalation is a production gotcha that gets experienced engineers nodding.*

> **Gotcha follow-up:** How would you find all unindexed foreign keys in a PostgreSQL database?
> I query the system catalogs: join pg_constraint (for FK definitions) against pg_index (for existing indexes) and look for FK columns that don't appear as the leading column of any index. There are community-provided queries for this pattern — I keep one in my DBA toolkit and run it after every schema migration.

---

**Q12: CREATE INDEX CONCURRENTLY**
*Concept Check*

**One-line answer:** CREATE INDEX CONCURRENTLY builds the index without blocking writes — essential for production tables — but it takes longer and cannot run inside a transaction.

**Full answer:**
A regular CREATE INDEX acquires a ShareLock on the table, which allows reads but blocks all writes (INSERT, UPDATE, DELETE) for the duration of the build. On a large table this can take minutes or hours, causing a production outage. CREATE INDEX CONCURRENTLY avoids this by performing multiple passes: first it scans the table and builds an initial index while tracking concurrent writes; then it does additional passes to incorporate changes made during the build; finally it marks the index valid. Throughout all passes, reads and writes to the table proceed normally. The cost is that CONCURRENTLY takes roughly 2–3× longer than a regular build. The constraints: it cannot run inside an explicit transaction block (BEGIN/COMMIT), because the multi-pass approach relies on seeing changes across transaction boundaries. If the build fails partway through — due to a unique constraint violation or a cancelled query — it leaves an invalid index behind. An invalid index shows up in pg_indexes with `indisvalid = false`; it wastes write overhead without helping reads and must be cleaned up with `DROP INDEX CONCURRENTLY` before retrying. Always monitor for invalid indexes after deployments.

*The "invalid index after failure" consequence is the part most people miss — mention it explicitly.*

> **Gotcha follow-up:** Can you drop an index concurrently as well?
> Yes — DROP INDEX CONCURRENTLY avoids the table lock just like CREATE INDEX CONCURRENTLY. A regular DROP INDEX acquires an exclusive lock. The concurrent drop takes longer and also cannot run inside a transaction. I always use CONCURRENTLY for both creates and drops on production tables.

---

**Q13: Unused Index Audit**
*Concept Check*

**One-line answer:** Indexes that are never scanned add write overhead and storage cost with no read benefit — audit with pg_stat_user_indexes and drop unused ones.

**Full answer:**
Every index must be maintained on every INSERT, UPDATE, or DELETE — the database updates the index pages in addition to the table pages. An index that is never used for reads is pure write overhead: more I/O per write, more WAL (Write-Ahead Log — the durability journal) generated, more memory consumed in the buffer pool (leaving less room for hot data), and more lock contention. PostgreSQL tracks how many times each index has been used for index scans in the pg_stat_user_indexes view, specifically the idx_scan counter. A query like `SELECT schemaname, tablename, indexname FROM pg_stat_user_indexes WHERE idx_scan = 0 AND indexname NOT LIKE 'pg_%'` lists all indexes that have never been used since stats were last reset. Before dropping anything I reset the stats with `SELECT pg_stat_reset()` and let the system run through a representative traffic period (ideally a full week covering all load patterns) before re-querying. I never drop a primary key or unique constraint index — those enforce data integrity. For other zero-scan indexes I drop them with DROP INDEX CONCURRENTLY to avoid table locks.

*The "reset stats and wait a representative period" step is critical — without it you might drop an index used only in monthly batch jobs.*

> **Gotcha follow-up:** What about indexes that are used very infrequently — say once a month for a batch job?
> I check when the last scan happened using pg_stat_user_indexes.last_idx_scan (PostgreSQL 16+) or by correlating with known batch schedules. An index used 12 times a year for a multi-million-row batch query might be worth keeping even though idx_scan looks low. Context matters — I don't mechanically drop anything with low scan counts without understanding the query patterns it supports.

---

**Q14: INCLUDE Columns — Covering Without Key Bloat**
*Concept Check*

**One-line answer:** INCLUDE columns in an index are stored only in leaf pages, not in internal tree nodes — they enable covering index scans without inflating the tree structure.

**Full answer:**
When I add extra columns to an index key to create a covering index, those columns appear at every level of the B-tree — root, internal nodes, and leaf pages. This inflates the size of the internal nodes, making the tree taller or wider, slowing down navigation. The INCLUDE clause (PostgreSQL 11+, SQL Server) separates "key columns" from "payload columns." Key columns appear throughout the tree and determine sort order and searchability. INCLUDE (payload) columns are stored only in the leaf pages — the final destination once the tree traversal is complete. This means the extra columns don't bloat the internal structure, but they are available once a matching leaf is reached, satisfying covering index requirements for those columns. Example: `CREATE INDEX ON orders (customer_id) INCLUDE (order_total, status)`. Queries filtering by customer_id that also need order_total and status can be served entirely from the index — Index Only Scan — without touching the heap. But I can't filter by order_total in the index tree itself (since it's only in leaves, not navigable). INCLUDE is ideal for frequently-read columns that I don't filter on but want to avoid heap fetches for.

*"Key columns navigate the tree; INCLUDE columns ride in the leaf" is a good one-line mental model to offer.*

> **Gotcha follow-up:** When should you add columns to the index key vs the INCLUDE list?
> If I need to filter, sort, or enforce uniqueness using a column, it must be a key column. If I only need to retrieve its value after the key columns have already found the matching rows, INCLUDE is better — it keeps the internal tree leaner. A common pattern: `CREATE UNIQUE INDEX ON users (email) INCLUDE (user_id, name)` — email is the unique key I search on, user_id and name ride along in leaves so SELECT user_id, name WHERE email = ? never touches the heap.

---

**Q15: Bitmap Index Scan**
*Concept Check*

**One-line answer:** A Bitmap Index Scan builds an in-memory bitmap of matching heap pages before fetching them in order — it trades a two-phase process for more sequential I/O than a plain index scan.

**Full answer:**
A plain Index Scan follows index pointers to heap rows one by one, in index order. If matching rows are scattered across many heap pages, this causes random I/O — each row potentially triggers a different page fetch. A Bitmap Index Scan breaks this into two phases. Phase 1 (Bitmap Index Scan node): walk the index and build a bitmap in memory where each bit represents a heap page that contains at least one matching row. No heap reads happen yet. Phase 2 (Bitmap Heap Scan node): fetch the marked heap pages in physical page order (not index order) — this converts random I/O into more sequential I/O, which is faster for moderate result sets. The powerful feature is that multiple Bitmap Index Scans can be combined with bitwise AND or OR before the heap scan — for example, a query with `WHERE status = 'active' AND region = 'us-east'` can run two separate index scans (one on status, one on region), AND the bitmaps, and fetch only the pages that satisfy both conditions. This means two single-column indexes can together handle a query as effectively as a composite index in many cases. The planner chooses Bitmap Heap Scan when a plain Index Scan would be too scattered and a Seq Scan would be overkill — it's the middle ground for 1–20% selectivity queries.

*The "two single-column indexes can be AND-ed" insight is the most practical takeaway — it justifies not always needing composite indexes.*

> **Gotcha follow-up:** What is a "lossy" bitmap and when does it occur?
> When the number of matching pages is very large, the in-memory bitmap can exceed the work_mem budget. PostgreSQL then switches to a lossy bitmap where each bit represents a heap page but without row-level precision — meaning the heap scan must re-check every row on those pages against the original condition (the Recheck Cond in EXPLAIN output). This adds CPU overhead but avoids an out-of-memory condition. Increasing work_mem can avoid lossy mode for large result sets.

---

**Common Mistakes:**
- **Not indexing FK columns in PostgreSQL** → seq scans on every join and slow cascade deletes; always add an index on FK columns immediately after creating the constraint.
- **Using a regular index on a low-cardinality column** → optimizer ignores it, or worse uses it and causes slower random I/O; use partial index or composite index instead.
- **Using UUID v4 as a primary key without concern** → B-tree fragmentation, slower inserts, larger indexes; migrate to UUID v7, ULID, or BIGINT SERIAL.
- **Running CREATE INDEX without CONCURRENTLY on a live table** → blocks all writes until the build completes; always use CONCURRENTLY on production.
- **Never auditing pg_stat_user_indexes** → accumulating dead-weight indexes that slow writes; schedule periodic unused index reviews.

**Quick Revision:** An index is only as good as its selectivity and the leftmost prefix rule — if you can't explain which fraction of the table it eliminates and why the query's predicates hit the first column, the index probably isn't helping.

---

## Section 3: ACID & Transactions

**Q1: ACID Internals**
*Concept Check*

**One-line answer:** ACID is enforced by four separate mechanisms: undo log for Atomicity, constraints for Consistency, MVCC for Isolation, and WAL for Durability.

**Full answer:**
ACID is the set of properties that make database transactions reliable. Atomicity — the guarantee that a transaction either fully commits or fully rolls back, never leaving partial changes — is implemented via the undo log (called the rollback segment in MySQL InnoDB). The undo log stores the before-images of modified rows; if the transaction fails or is rolled back, the engine applies the undo entries to reverse every change. Consistency — the guarantee that the database moves from one valid state to another — is enforced by constraints (NOT NULL, UNIQUE, FK, CHECK), triggers, and application-level invariants; the database cannot enforce business logic it doesn't know about. Isolation — the guarantee that concurrent transactions don't interfere with each other — is implemented in PostgreSQL and InnoDB using MVCC (Multi-Version Concurrency Control). MVCC keeps multiple versions of each row simultaneously; readers see a consistent snapshot of the database as it existed at the start of their transaction, and writers create new versions rather than overwriting in place, so readers never block writers and writers never block readers. Durability — the guarantee that committed data survives crashes — is implemented via WAL (Write-Ahead Log, also called the redo log in MySQL). Before any data page is modified on disk, the change is first written to the WAL (a sequential append-only file). On crash recovery, the engine replays WAL entries to reconstruct any commits that hadn't yet been flushed to data pages.

*Walk through each letter with its mechanism — it shows you know ACID as an engineering design, not just a buzzword.*

> **Gotcha follow-up:** If WAL guarantees durability, why do data pages get written at all?
> WAL is written first and flushed to disk on every commit, which is sufficient for durability — the database can always recover by replaying the log. Data pages are written to disk lazily in the background (by the checkpointer process in PostgreSQL) as a performance optimization: once a checkpoint is reached, earlier WAL can be discarded because the changes are now in the data files. Without writing data pages, the WAL would grow indefinitely and recovery time would be proportional to the entire transaction history.

---

**Q2: Isolation Levels vs Anomalies**
*Concept Check*

**One-line answer:** There are four isolation levels, each preventing a different set of anomalies — READ COMMITTED is the common default; SERIALIZABLE prevents all anomalies including write skew.

**Full answer:**
The SQL standard defines four isolation levels and the anomalies they prevent. READ UNCOMMITTED is the weakest — a transaction can read uncommitted changes from other concurrent transactions, called a dirty read; this is almost never used in practice. READ COMMITTED prevents dirty reads — you only see committed data — but allows non-repeatable reads (reading the same row twice in one transaction can give different values if another transaction commits between the reads) and phantom reads (a range query can return different sets of rows if rows are inserted/deleted between reads). REPEATABLE READ prevents dirty and non-repeatable reads; in MySQL it still allows phantoms, but PostgreSQL's REPEATABLE READ uses MVCC snapshots and also prevents phantoms. SERIALIZABLE is the strongest — it prevents all anomalies including write skew. Write skew is subtle: two transactions each read overlapping data, each decides to write based on what they read, and the combined result violates an invariant that neither transaction individually violated — for example, two doctors both see "there's at least one doctor on call" and both decide to go off-call, leaving zero on call. SERIALIZABLE in PostgreSQL uses Serializable Snapshot Isolation (SSI), which tracks read/write dependencies and aborts transactions that would cause a cycle — it's optimistic and only aborts when an actual conflict is detected.

*Write skew is the hardest anomaly to explain — use the on-call doctor example, it's canonical and memorable.*

> **Gotcha follow-up:** Is READ COMMITTED the PostgreSQL default?
> Yes — PostgreSQL defaults to READ COMMITTED. This is a pragmatic choice: it prevents the most common anomaly (dirty reads) while having the lowest performance cost (each statement gets a fresh snapshot rather than holding one for the whole transaction). For financial operations or anything requiring stronger guarantees, I explicitly set `BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE` or REPEATABLE READ.

---

**Q3: MVCC — PostgreSQL xmin/xmax vs MySQL Undo Log**
*Concept Check*

**One-line answer:** PostgreSQL tags each row version with xmin/xmax transaction IDs and uses a visibility check against the transaction's snapshot; MySQL InnoDB chains old versions in a separate undo log.

**Full answer:**
MVCC (Multi-Version Concurrency Control) is the mechanism that allows readers and writers to operate concurrently without blocking each other by maintaining multiple versions of rows simultaneously. In PostgreSQL, every row version carries two hidden system columns: xmin (the transaction ID that inserted this row version) and xmax (the transaction ID that deleted or updated this row version; 0 if the row is still current). When a transaction reads a row, it checks visibility: the row is visible if xmin represents a committed transaction that started before this transaction's snapshot, and xmax is either 0 or represents a transaction that had not yet committed at snapshot time. This means old row versions accumulate in the heap pages; VACUUM's job is to clean up dead versions (where xmax is a committed transaction) and reclaim space. In MySQL InnoDB, each row in the main heap has a rollback pointer in its header that points to the previous version stored in the undo log. Readers that need an older version follow the rollback pointer chain until they find a version that was committed before their read view. A separate purge thread asynchronously cleans undo log entries once no active transaction needs them. The key difference: PostgreSQL stores old versions in the main heap (table bloat if VACUUM is slow); MySQL stores them in a centralized undo tablespace (undo log bloat if purge is slow).

*The physical storage location of old versions (heap vs undo tablespace) is the concrete difference that sets experienced answers apart.*

> **Gotcha follow-up:** What is a transaction ID wraparound in PostgreSQL and why is it dangerous?
> PostgreSQL uses 32-bit transaction IDs. After approximately 2 billion transactions, the counter wraps around. If VACUUM has not frozen old row versions (marking their xmin as a special "frozen" ID that is always visible), those rows can appear to be in the future after wraparound and become invisible — effectively data loss. PostgreSQL autovacuum handles this automatically via aggressive vacuuming of tables with high xmin age, but very busy systems or disabled autovacuum can approach the limit. Monitoring pg_database.datfrozenxid is essential in high-transaction environments.

---

**Q4: SELECT FOR UPDATE vs SELECT FOR SHARE**
*Concept Check*

**One-line answer:** FOR UPDATE acquires an exclusive row lock blocking all other lockers and writers; FOR SHARE acquires a shared lock allowing other readers but blocking writers.

**Full answer:**
Normally, SELECT in PostgreSQL takes no row locks at all — MVCC handles concurrency for plain reads. But sometimes I need to lock rows to prevent concurrent modification between my read and my subsequent write. SELECT FOR UPDATE acquires an exclusive lock on each returned row. This blocks any other transaction that tries to SELECT FOR UPDATE, SELECT FOR SHARE, or write to those rows — they wait until my transaction commits or rolls back. This is pessimistic locking — I assume a conflict will happen and lock proactively. SELECT FOR SHARE acquires a shared lock: multiple transactions can hold FOR SHARE on the same rows simultaneously (they're all reading), but a transaction wanting FOR UPDATE or wanting to write must wait. FOR SHARE is useful for operations like "check this row, then reference it in another insert" where I want to prevent the row being deleted but don't mind other readers. Two important variants: FOR UPDATE SKIP LOCKED skips any rows that are currently locked rather than waiting — this is the foundation of reliable job queue implementations where multiple workers compete for tasks without serialising on a single lock. FOR UPDATE NOWAIT raises an error immediately if any row is already locked rather than waiting — useful when I'd rather fail fast and retry than queue up.

*SKIP LOCKED for job queues is a common real-world pattern — mention it proactively.*

> **Gotcha follow-up:** Does SELECT FOR UPDATE prevent phantom reads?
> Yes — in PostgreSQL, SELECT FOR UPDATE at READ COMMITTED level locks the rows found and re-evaluates the predicate, preventing phantoms for the locked range through a gap-lock-like effect. At REPEATABLE READ and SERIALIZABLE, phantom prevention is handled by MVCC snapshots plus SSI tracking. SKIP LOCKED combined with FOR UPDATE is how I build a queue that's immune to the "two workers grab the same job" phantom problem.

---

**Q5: Deadlock — Coffman Conditions and Prevention**
*Concept Check*

**One-line answer:** A deadlock occurs when two transactions each hold a lock the other needs — databases detect the cycle and kill one victim; prevention is acquiring locks in a consistent global order.

**Full answer:**
A deadlock requires four conditions to hold simultaneously — the Coffman conditions. Mutual exclusion: a resource (like a row lock) can be held by only one transaction at a time. Hold and wait: a transaction holds at least one lock while waiting to acquire another. No preemption: locks are not forcibly taken away from a transaction; it must release them voluntarily. Circular wait: transaction A holds what B needs, and B holds what A needs, forming a cycle. If any one of these is broken, deadlocks cannot occur. In practice, databases don't prevent deadlocks — they detect them. PostgreSQL and MySQL periodically check the lock wait-for graph (a graph where each transaction points to the transaction it's waiting for) for cycles. When a cycle is found, the database selects a deadlock victim (usually the transaction with the least work done) and rolls it back with an error, allowing the other to proceed. The prevention strategy in application code is: always acquire locks in the same global order. If I always lock the lower customer ID before the higher one, the circular wait condition is impossible. In Spring JPA, I annotate service methods with `@Retryable` so that a deadlock victim automatically retries the transaction after a brief delay — this is the standard Spring pattern for handling transient deadlock errors.

*The Coffman conditions are the theory; lock ordering + @Retryable are the practice. Cover both.*

> **Gotcha follow-up:** Can deadlocks occur between tables, not just rows?
> Yes — a transaction that acquires a table-level lock (like during ALTER TABLE or LOCK TABLE) can deadlock with a transaction holding row locks if the table-lock acquisition must wait and the row-lock holder then tries to acquire a different table lock. The same circular-wait condition applies at any lock granularity. In PostgreSQL, DDL operations acquire exclusive table locks, which is why running migrations during live traffic (without CONCURRENTLY) is risky.

---

**Q6: @Version — Optimistic Locking in JPA**
*Concept Check*

**One-line answer:** @Version tells JPA to add a version number column and include it in UPDATE WHERE clauses — if another transaction already incremented the version, the update matches zero rows and throws OptimisticLockException.

**Full answer:**
Optimistic locking is a concurrency strategy based on the assumption that conflicts are rare — so instead of acquiring a database lock when reading, I simply check at write time whether anyone else modified the data in the meantime. In JPA, I annotate a numeric or timestamp field with `@Version`. JPA automatically includes this column in every UPDATE it generates: `UPDATE products SET stock = ?, version = version + 1 WHERE id = ? AND version = ?`. The WHERE clause includes the version number I read. If another transaction committed an update and incremented the version between my read and my write, the version no longer matches — the UPDATE affects zero rows. JPA detects zero affected rows and throws an OptimisticLockException (which Spring translates to ObjectOptimisticLockingFailureException). My service layer catches this and retries the entire operation. Optimistic locking is ideal for low-contention scenarios — shopping cart updates, user profile edits — where conflicts are rare and holding database locks is wasteful. For high-contention scenarios — inventory decrement, seat booking — pessimistic locking via SELECT FOR UPDATE is more appropriate because it prevents conflicts rather than detecting them after the fact, avoiding repeated retry cycles.

*The "zero affected rows = conflict detected" mechanism is the key insight — explain it explicitly rather than just naming the exception.*

> **Gotcha follow-up:** What happens if you catch OptimisticLockException and retry, but the retry also fails?
> I add a maximum retry count — typically 3 attempts — and if all fail I surface an error to the user (e.g., "this item is currently being modified, please try again"). Infinite retries under contention can cause a thundering herd — many threads all retrying simultaneously, amplifying the conflict. Using exponential backoff with jitter between retries reduces this. If retries consistently fail, it signals that the contention is high enough to warrant switching to pessimistic locking for that code path.

---

**Q7: Normal Forms**
*Concept Check*

**One-line answer:** Normal forms (1NF through BCNF) progressively eliminate different kinds of data redundancy and update anomalies by ensuring each fact is stored in exactly one place.

**Full answer:**
Normalisation is the process of organising a schema to reduce data redundancy — storing each fact exactly once so that updates don't create inconsistencies. First Normal Form (1NF) requires atomic values in each column (no sets or arrays stored as comma-separated strings) and no repeating column groups — every value must be a single scalar, and each row must be unique. Second Normal Form (2NF) builds on 1NF and requires no partial dependency: every non-key column must depend on the entire primary key, not just part of it. This only matters when the primary key is composite — if a non-key column depends on only one part of a composite key, it should be in its own table. Third Normal Form (3NF) additionally requires no transitive dependency: non-key columns must depend directly on the primary key, not on another non-key column. If city → zip code and zip code is a non-key column that determines city, that's a transitive dependency — zip code and city should be in a separate Zip table. Boyce-Codd Normal Form (BCNF) is a stricter version of 3NF that handles edge cases with multiple overlapping candidate keys — every functional determinant must be a candidate key. In practice, I design to 3NF for transactional systems and evaluate BCNF when I find anomalies that 3NF didn't eliminate.

*Frame normalisation as "where does each fact live" — one fact, one place — it's more memorable than formal definitions.*

> **Gotcha follow-up:** Can you give a concrete example of a transitive dependency violating 3NF?
> An orders table with columns order_id, customer_id, customer_city. customer_city depends on customer_id, not on order_id — so customer_city should live in the customers table. If a customer moves, I'd otherwise have to update customer_city in every order row, risking inconsistency if any rows are missed. Moving it to customers means one update, consistent everywhere.

---

**Q8: When to Denormalize**
*Tradeoff Question*

**One-line answer:** Denormalize when join costs dominate read-heavy or reporting workloads — accept redundancy and update anomaly risk in exchange for query speed.

**Full answer:**
Normalisation is designed for write-heavy transactional systems (OLTP — Online Transaction Processing) where each write touches one fact in one place. But read-heavy reporting systems (OLAP — Online Analytical Processing) often need to aggregate data across many tables, and joining ten normalised tables for every dashboard query becomes the bottleneck. In these cases I deliberately denormalize: I store derived or duplicated data to avoid joins at read time. Common patterns: storing customer_name redundantly in the orders table so order history queries don't need to join to customers; pre-aggregating totals like total_order_count on a customer row; using a star schema in a data warehouse where a central fact table is surrounded by dimension tables (flat, denormalized) to enable fast analytical queries. The tradeoffs are clear: reads are faster because fewer joins; writes are more expensive because multiple locations must be kept in sync; update anomalies become a risk — if I update a name in one place but forget another, the data is inconsistent. Mitigation strategies include application-level dual writes, database triggers to propagate changes, or change data capture (CDC) systems that replicate changes asynchronously. I always document the denormalization and its consistency strategy explicitly so future maintainers know it's intentional.

*OLTP vs OLAP framing is the key context — it legitimizes denormalization for the right workload.*

> **Gotcha follow-up:** How would you handle a denormalized cache column becoming stale?
> Options in order of complexity: trigger on the source table to update the cache column on every change (synchronous, strong consistency, adds write latency); application-level dual write in the service layer wrapped in a transaction (simple but requires discipline); asynchronous event-driven update via a message queue or CDC (eventual consistency, acceptable for dashboards, decoupled from write path). I choose based on how stale the data can be and whether the write path can absorb the synchronous overhead.

---

**Q9: CAP Theorem**
*Concept Check*

**One-line answer:** The CAP theorem says a distributed system can guarantee at most two of: Consistency, Availability, and Partition Tolerance — and since network partitions are unavoidable, the real choice is between C and A during a partition.

**Full answer:**
CAP stands for Consistency (every read returns the most recent write or an error — not eventual consistency, but immediate linearizability), Availability (every request gets a response, though it might be stale), and Partition Tolerance (the system keeps operating even when network messages between nodes are lost or delayed). Network partitions — where some nodes can't communicate — are a physical reality in any distributed system; they happen due to hardware failures, packet loss, and network congestion. This means Partition Tolerance is not optional for any system that runs on multiple machines. The real design choice is: during a partition, do I keep serving requests and risk returning stale data (choose Availability), or do I stop serving requests until the partition heals to guarantee fresh data (choose Consistency)? Systems like ZooKeeper and Spanner are CP — they stop serving writes during a partition to maintain consistency. Systems like Cassandra and DynamoDB are AP — they serve requests from any available replica even if some replicas are behind. MongoDB is CP by default (primary must be reachable for writes) but can be tuned. In practice, "AP" systems often offer tunable consistency — DynamoDB allows strongly consistent reads at higher cost — blurring the binary choice.

*CAP is often misunderstood as a static label. Emphasise that it describes behaviour during a partition, and that tunable consistency exists.*

> **Gotcha follow-up:** What is the PACELC theorem and why was it proposed?
> CAP only addresses behaviour during a partition. PACELC (Partition → choose A or C; Else → choose Latency or Consistency) extends this: even in normal operation without a partition, there's a tradeoff between latency (responding fast from a local replica) and consistency (waiting for all replicas to acknowledge). For example, Cassandra is PA/EL — available during partition, low latency in normal operation. Spanner is PC/EC — consistent during partition, consistent at the cost of higher latency in normal operation. PACELC is a more complete model for real-world distributed system design.

---

**Q10: BASE vs ACID**
*Concept Check*

**One-line answer:** ACID guarantees strong immediate consistency for transactions; BASE accepts eventual consistency in exchange for higher availability and partition tolerance in distributed systems.

**Full answer:**
ACID (Atomic, Consistent, Isolated, Durable) is the transaction model of traditional relational databases. Every committed transaction is immediately visible to all subsequent reads, constraints are always enforced, and partial failures are impossible — the database is always in a valid state. This is achieved by coordination mechanisms (locks, WAL, undo log) that introduce latency and limit horizontal scalability. BASE is the contrasting model for distributed NoSQL systems. Basically Available means the system always responds, even if some responses are stale or approximate. Soft State means the system's state can change over time without any input — replicas catching up, convergence happening asynchronously. Eventually Consistent means if no new updates are made, all replicas will converge to the same value — but there's no guarantee of when. Cassandra is BASE: writes go to a configurable number of replicas (quorum), reads may return older data from a replica that hasn't received the latest write yet. DynamoDB is similar. These systems achieve high write throughput across geographically distributed nodes because they don't need all replicas to agree before returning success. The design choice is driven by requirements: for financial ledgers, inventory, and anything where "lost" or "double-counted" operations are unacceptable, ACID is non-negotiable. For activity feeds, product catalogs, and shopping carts where brief inconsistency is acceptable, BASE enables the scale needed.

*Use "financial ledger vs activity feed" as the concrete contrast — it makes the tradeoff immediate and relatable.*

> **Gotcha follow-up:** Can you get strong consistency from a BASE system like Cassandra?
> Yes, at a cost. Cassandra supports a quorum consistency level: a write must be acknowledged by a majority of replicas before returning success, and a read must query a majority of replicas and return the most recent result. Read + write quorum together guarantee strong consistency (because the sets must overlap). But quorum reads and writes are slower and less available during failures than eventual consistency — you're opting into ACID-like behaviour on a per-operation basis by sacrificing some of what makes Cassandra attractive in the first place.

---

**Q11: Two-Phase Commit (2PC) and Its Problem**
*Concept Check*

**One-line answer:** 2PC coordinates an atomic commit across multiple systems, but if the coordinator crashes after asking participants to prepare, everyone is stuck holding locks indefinitely.

**Full answer:**
Two-Phase Commit (2PC) is a distributed protocol for achieving atomicity across multiple independent databases or services that are all part of one logical transaction. Phase 1 (Prepare): the coordinator sends a "prepare to commit" message to all participants. Each participant records the transaction to its WAL (durable), acquires all needed locks, and votes Yes if it can commit or No if it cannot. Phase 2 (Commit/Abort): if all participants voted Yes, the coordinator sends Commit; if any voted No, it sends Abort. Participants execute accordingly and release locks. The fatal problem is the blocking failure scenario: if the coordinator crashes after participants have voted Yes but before sending the Phase 2 decision, participants are stuck in the "prepared" state — they've committed their undo log, hold all their locks, and cannot proceed without the coordinator's decision. Other transactions trying to access those rows are blocked indefinitely. Three-Phase Commit (3PC) adds a pre-commit phase to reduce blocking, but it's complex and rarely implemented. Modern distributed systems prefer consensus algorithms like Raft (used in etcd, CockroachDB, TiDB) which tolerate node failures without blocking. Google Spanner uses 2PC but ensures the coordinator is itself a Paxos group (fault-tolerant), removing the single-point-of-failure problem.

*The "participants stuck holding locks" scenario is the memorable failure mode — describe it vividly.*

> **Gotcha follow-up:** When would you still use 2PC in a microservices architecture?
> 2PC makes sense when all participants are ACID databases that support the XA protocol (a standard interface for distributed transactions) and the coordinator is highly available. Some JDBC-based systems use XA transactions across two databases when atomicity is critical (e.g., a payment system writing to both a ledger DB and an audit DB in the same transaction). But for most microservices architectures with heterogeneous stores, Sagas are preferred because they avoid the blocking and tight coupling of 2PC.

---

**Q12: Saga vs 2PC**
*Tradeoff Question*

**One-line answer:** 2PC is synchronous and tightly coupled with strong consistency; Sagas are asynchronous and loosely coupled with eventual consistency via compensating transactions.

**Full answer:**
2PC achieves atomicity by holding locks across all participants until the coordinator decides — strong consistency, but blocking and requiring all participants to support the XA protocol. Sagas decompose a distributed transaction into a sequence of local transactions, each within a single service and its own database. If a later step fails, the Saga executes compensating transactions — previously defined rollback steps — to undo the effects of earlier steps. For example, a hotel booking Saga: book flight (local commit) → charge payment (local commit) → book hotel (local commit). If the hotel is unavailable, compensating transactions reverse the payment charge and cancel the flight booking. Each local commit is immediately visible (no distributed lock held), which is why Sagas are eventually consistent rather than strictly atomic — between the first commit and a compensation, the system is in an intermediate state. There are two implementation styles: choreography, where each service publishes events and other services react to them (no central coordinator, loosely coupled, but hard to follow the overall flow); and orchestration, where a central Saga orchestrator sends commands to each service and tracks progress (easier to reason about, but the orchestrator becomes a coordination point). Most microservices teams prefer orchestration for complex Sagas because debugging a failure is much simpler when one component knows the full state.

*Choreography vs orchestration is a common follow-up — address it proactively.*

> **Gotcha follow-up:** What happens if a compensating transaction itself fails?
> This is the hard problem with Sagas. The standard answer is: compensating transactions must be idempotent (safe to retry multiple times) and the Saga framework must retry them until they succeed, with dead-letter handling for persistent failures. In practice, compensating transactions should be designed to always succeed (e.g., a "cancel booking" that marks the booking cancelled even if it's already cancelled). For truly unrecoverable failures a human intervention step is modeled into the Saga — an alert is raised and a support team resolves the inconsistency manually.

---

**Q13: Outbox Pattern**
*Design Scenario*

**One-line answer:** The Outbox pattern writes business data and an event record in the same database transaction, then a separate publisher reads the outbox and delivers the event — solving the dual-write atomicity problem.

**Full answer:**
The fundamental problem: I need to write data to my database AND publish an event to a message broker (Kafka, RabbitMQ) as part of the same logical operation. But these are two different systems — I cannot wrap them in a single ACID transaction. If I write to the DB first and the broker publish fails, the downstream consumers never see the event. If I publish first and the DB write fails, consumers process an event for data that doesn't exist. The Outbox pattern solves this with a single-system guarantee: in the same database transaction that writes the business data (e.g., INSERT INTO orders), I also INSERT INTO outbox (event_type, payload, status='pending'). Since both writes are in the same transaction, they commit atomically. A separate outbox publisher process (a background thread, a scheduled job, or a Debezium CDC connector) polls the outbox table for pending events, publishes each to the message broker, and marks it as published. This guarantees at-least-once delivery — if the publisher crashes after publishing but before marking as published, it will publish again on restart. Consumers must therefore be idempotent — processing the same event twice should produce the same result as processing it once. The most scalable implementation is CDC (Change Data Capture): Debezium reads the database's WAL/binlog directly, picks up inserts to the outbox table, and forwards them to Kafka without any polling overhead on the database.

*At-least-once delivery + idempotent consumers is the full contract — state both halves.*

> **Gotcha follow-up:** How do you prevent the outbox table from growing unboundedly?
> The publisher deletes or archives rows after successful publication. I typically add a status column (pending → published → archived) and a created_at timestamp, and run a periodic cleanup job to delete rows older than a retention window (e.g., 7 days). An index on status + created_at ensures the publisher's poll query stays fast even if the table temporarily has many pending rows.

---

**Q14: Replication Lag — Read-Your-Writes Problem**
*Tradeoff Question*

**One-line answer:** Replication lag means a user's own write may not yet be visible on a replica they read from — the fix is routing reads immediately after writes to the primary.

**Full answer:**
Asynchronous replication means primary commits a write, sends it to replicas, but returns success to the client before replicas confirm receipt. Replicas apply changes with some delay — replication lag — which can range from milliseconds to seconds under load. The read-your-writes problem is: a user saves their profile photo (write goes to primary), then immediately loads the page (read goes to a replica that hasn't received the write yet) and sees the old photo. The user believes their save failed. Several solutions exist at different complexity levels. The simplest is to route reads to the primary for a short period after any write from the same session — typically the expected lag window (e.g., 500ms). A more robust approach is tracking a write timestamp or LSN (Log Sequence Number — a monotonically increasing pointer into the WAL stream) on the client, and checking that the replica's current LSN is at least as recent before serving the read from it; if not, fall back to the primary. Monotonic reads is a related guarantee: once a user has seen a particular version of data on one replica, they should not see an older version on a subsequent read — solved by stickying the user to the same replica for the duration of a session. Synchronous replication (the primary waits for at least one replica to acknowledge before confirming the write) gives strong consistency but increases write latency and reduces availability.

*LSN-based routing is the production-grade solution that shows you've thought beyond "just read from primary."*

> **Gotcha follow-up:** In PostgreSQL, how do you implement LSN-based read routing?
> On every write, capture `pg_current_wal_lsn()` and store it in the session (or in a Redis key for the user). Before executing a read on a replica, query `pg_last_wal_replay_lsn()` on that replica and compare. If the replica's LSN is less than the captured write LSN, the replica is behind — either wait briefly and retry, or route the read to the primary. This logic is often encapsulated in a connection pool proxy (PgBouncer, Pgpool-II) or in application-level middleware.

---

**Q15: @Transactional Propagation**
*Concept Check*

**One-line answer:** @Transactional propagation controls whether a method joins an existing transaction, creates a new one, or runs outside any transaction — REQUIRED joins or creates; REQUIRES_NEW always creates a fresh one.

**Full answer:**
Spring's @Transactional annotation manages transaction boundaries declaratively. The propagation attribute determines what happens when a transactional method calls another transactional method. REQUIRED (the default) joins the calling transaction if one exists; if not, creates a new one. This means a nested REQUIRED method shares the same transaction — if it throws, the entire outer transaction rolls back. REQUIRES_NEW always suspends any existing transaction and starts a completely independent new one; even if the outer transaction rolls back, the inner one has already committed independently. I use REQUIRES_NEW for audit logging: I want the audit record to persist even if the main business operation fails. SUPPORTS joins a transaction if one exists, but runs non-transactionally if there is none — useful for read-only methods that work fine either way. MANDATORY requires that a transaction already exist; if called outside a transaction it throws IllegalTransactionStateException — used to enforce that a method is never accidentally called without a transaction. NEVER is the opposite: it must not run inside a transaction and throws if one exists — useful for operations that are intentionally non-transactional. NOT_SUPPORTED suspends any existing transaction and runs non-transactionally. NESTED creates a savepoint within the current transaction (using database savepoints); if the nested portion fails, only its portion is rolled back — but PostgreSQL doesn't fully support nested transactions via JPA savepoints in practice, so I use REQUIRES_NEW instead on PostgreSQL.

*The REQUIRES_NEW vs NESTED distinction for audit logging is a practical real-world pattern — use it as the example.*

> **Gotcha follow-up:** What is the self-invocation problem with @Transactional?
> Spring implements @Transactional via a proxy — when code outside the class calls a method, the call goes through the Spring AOP proxy which applies the transaction logic. But when a method in the same class calls another @Transactional method on `this`, it bypasses the proxy entirely and goes directly to the object, so the transaction annotation on the inner method is ignored. The fix is to inject the bean into itself via @Autowired (self-injection) or @Lazy, call through the injected reference, or restructure the code so the inner method is on a separate bean.

---

**Common Mistakes:**
- **Assuming REPEATABLE READ prevents write skew** → it doesn't (except in PostgreSQL with SSI); use SERIALIZABLE for invariants that span multiple rows.
- **Using @Transactional REQUIRES_NEW for all nested calls** → each new transaction suspends the outer one, increasing connection pool pressure; only use REQUIRES_NEW when the inner work must commit independently.
- **Not handling OptimisticLockException at the service layer** → the exception propagates to the user as an HTTP 500; always catch and retry, with a max retry count and backoff.
- **Ignoring replication lag for post-write reads** → users see stale data after saving; implement read-your-writes routing for user-facing write operations.
- **Using NOT IN with a subquery that can return NULLs** → silent empty results; use NOT EXISTS.

**Quick Revision:** ACID's four mechanisms (undo log, constraints, MVCC, WAL) are independent engineering problems solved independently — knowing which mechanism solves which letter transforms ACID from a slogan into a design.

---

## Section 4: Distributed Databases

**Q1: Walk me through the three main sharding strategies and when you'd pick each one.**
*Concept Check*

**One-line answer:** Range sharding splits data by key ranges, hash sharding distributes via a hash function, and directory sharding uses a lookup table — each trades range-query friendliness for distribution evenness.

**Full answer:**
When I need to split a large dataset across multiple database nodes — a technique called sharding, where each node (shard) holds a subset of the rows — I have three main strategies to choose from. With range sharding, I assign contiguous key ranges to each shard, like A–M goes to shard 1 and N–Z goes to shard 2; this is great for range queries because all matching rows live on one shard, but it creates hot spots when data is skewed — if most usernames start with A, shard 1 gets hammered. With hash sharding, I compute `hash(key) % N` to assign each row to a shard, which gives even distribution across shards, but it destroys key ordering, so a range query like "all orders from last week" must be sent to every shard and the results merged — a pattern called scatter-gather. With directory sharding, I maintain an explicit lookup table that maps each key (or key range) to a shard; this is the most flexible — I can move individual keys without rehashing — but the lookup table itself becomes a bottleneck and a single point of failure if not replicated carefully. I choose range sharding for time-series or lexicographic workloads where range scans dominate, hash sharding for write-heavy workloads where even distribution matters most, and directory sharding when I need fine-grained control over data placement, such as co-locating a specific tenant's data on a specific shard for compliance.

*Mention the scatter-gather cost of hash sharding — interviewers often probe this.*

> **Gotcha follow-up:** What happens to hash sharding when you add a new shard?
> With naive modular hashing, adding a new shard changes N, which changes the target shard for almost every key, forcing a massive data migration. Consistent hashing solves this by mapping both servers and keys onto a ring, so adding a node only moves the keys that fall between the new node and its predecessor on the ring — typically 1/N of all keys.

---

**Q2: What makes a bad shard key, and what properties should a good shard key have?**
*Concept Check*

**One-line answer:** A bad shard key creates hot spots, cross-shard joins, or unbounded partition growth; a good one has high cardinality, even distribution, and aligns with the dominant query pattern.

**Full answer:**
A shard key is the attribute I use to decide which shard a row belongs to, so choosing it incorrectly causes performance problems that are very hard to fix later without downtime. The most common mistake is using a timestamp as the shard key in a write-heavy system — because all new writes land on the shard that owns the current time range, that shard gets all the write traffic while older shards sit idle, a problem called a hot spot. Another mistake is choosing a low-cardinality attribute — for example, sharding on a boolean `is_premium` field gives me at most two shards, which prevents any meaningful horizontal scaling. If I choose a shard key that does not align with my most common query pattern, many queries will need to hit multiple shards (cross-shard queries), increasing latency and complexity. With range sharding specifically, some ranges may naturally have far more data than others — for example, users whose names start with common letters — causing unbounded growth on certain shards. The ideal shard key has high cardinality (many distinct values), produces even distribution across shards, and matches the attribute I filter on most often; for user-centric applications, `user_id` is a classic choice because it has high cardinality, distributes evenly when hashed, and most queries are scoped to a single user.

*This question tests whether you understand the operational consequences of the shard key, not just the mechanics.*

> **Gotcha follow-up:** How do you handle a hot partition in DynamoDB when you can't change the partition key?
> A common workaround is to append a random suffix (1–N) to the partition key when writing, spreading writes across N logical partitions, then fan out reads to all N partitions and aggregate the results in application code — accepting higher read cost in exchange for write scalability.

---

**Q3: Explain consistent hashing and virtual nodes. Why do virtual nodes matter?**
*Concept Check*

**One-line answer:** Consistent hashing maps servers and keys onto a hash ring so that adding or removing a node only moves a fraction of keys; virtual nodes give each physical server multiple positions on the ring for better load balance.

**Full answer:**
In consistent hashing, I imagine the entire hash space — say 0 to 2^32 − 1 — arranged as a circle, often called a ring. I hash each server's identifier to place it at a position on that ring, and I hash each data key the same way. To find which server owns a key, I walk clockwise from the key's position until I hit a server — that server is responsible for the key. The elegant property is that when I add a new server, only the keys between the new server and its clockwise predecessor need to move; all other keys are unaffected, so the migration cost is O(K/N) where K is total keys and N is the number of servers. However, if I only place each physical server once on the ring, the distribution can be uneven — one server might own a large arc of the ring and receive disproportionate traffic. Virtual nodes (vnodes) solve this: instead of placing each server at one point, I place each physical server at many points (say 100–150) distributed around the ring. This makes the expected load per server much more uniform and also means that when a server leaves, its load is spread across many remaining servers rather than entirely shifting to one neighbor. Systems like Cassandra, DynamoDB, and Riak all use consistent hashing with vnodes for exactly this reason.

*Draw the ring on a whiteboard if given the chance — it communicates the concept far faster than words alone.*

> **Gotcha follow-up:** How do vnodes affect rebalancing when a node joins?
> With vnodes, a joining node claims many small token ranges from many different existing nodes rather than one large range from one neighbor; this means the data migration is parallelized across the cluster, completing faster and with less impact on any single node.

---

**Q4: What are quorum reads and writes, and how do you tune them for consistency vs. availability?**
*Concept Check*

**One-line answer:** A quorum is the minimum number of replicas that must acknowledge a read or write; the rule R + W > N guarantees strong consistency, and relaxing it trades consistency for lower latency.

**Full answer:**
In a distributed database that stores N replicas of each piece of data — where N is the replication factor — a quorum is the minimum number of those replicas I require to respond before I consider an operation successful. I define W as the write quorum (how many replicas must confirm a write) and R as the read quorum (how many replicas I must read from). The key insight is that if R + W > N, then the set of nodes I write to and the set I read from must overlap by at least one node, guaranteeing I always read the most recent write — this is the condition for strong consistency. For example, with N=3, setting W=2 and R=2 gives R + W = 4 > 3, so I am guaranteed strong consistency. If instead I set W=1 and R=1, writes and reads complete as soon as one replica responds, maximizing availability and minimizing latency, but I may read a stale value if the replica I happen to hit hasn't received the latest write yet. DynamoDB introduces the concept of a sloppy quorum: if the target nodes for a write are temporarily unavailable, the write is accepted by other available nodes with a "hint" to forward the data when the target recovers — a process called hinted handoff — which improves write availability at the cost of temporary inconsistency.

*Be ready to plug in numbers: N=5, W=3, R=3 → R+W=6>5 → consistent. N=5, W=1, R=1 → not consistent.*

> **Gotcha follow-up:** Can you get strong consistency with W=3 and R=1 in an N=3 system?
> Yes — if all three replicas must confirm every write (W=3=N), then every read from any single replica is guaranteed to see the latest write because all replicas are always up to date. The tradeoff is that writes are slower and unavailable if any replica is down.

---

**Q5: How do distributed databases resolve write conflicts under eventual consistency?**
*Tradeoff Question*

**One-line answer:** The three main strategies are Last Write Wins by timestamp, vector clocks that track causal history, and CRDTs that merge deterministically without needing conflict resolution at all.

**Full answer:**
Eventual consistency means that if no new writes occur, all replicas will eventually converge to the same value — but in the meantime, two clients may write to different replicas simultaneously, creating a conflict that the database must resolve. The simplest strategy is Last Write Wins (LWW): each write is tagged with a wall-clock timestamp, and the write with the higher timestamp wins; Cassandra and DynamoDB use this by default, but it risks silently discarding a concurrent write if both happened at nearly the same time, which is a form of data loss. A more precise approach is vector clocks, where each write carries a version vector — a list of (node, counter) pairs — that encodes the causal history of the value; the database can then detect whether two versions are causally related (one happened before the other) or truly concurrent (neither caused the other), and in the concurrent case, surfaces the conflict to the client to resolve; Riak uses this approach. The most elegant solution for certain data types is CRDTs — Conflict-free Replicated Data Types — which are data structures mathematically designed so that any two versions can always be merged deterministically without requiring conflict resolution; a distributed counter that only increments (a G-Counter) is a simple example because merging two replicas just means taking the maximum count from each node. The right choice depends on the use case: LWW is simple but lossy, vector clocks are precise but require application-level conflict resolution, and CRDTs are ideal when the data type supports a commutative and associative merge operation.

*Interviewers love asking "what happens to concurrent writes in Cassandra?" — the answer is LWW with potential data loss.*

> **Gotcha follow-up:** What is the risk of LWW in a multi-datacenter setup?
> Clock skew between datacenters means a write that logically happened later may have an earlier timestamp, causing it to be silently overwritten by the older write. This is why Cassandra recommends using its own hybrid logical clock timestamps rather than relying on system wall clocks.

---

**Q6: How would you design a DynamoDB table to store users and their orders efficiently?**
*Design Scenario*

**One-line answer:** Use a composite key with partition key USER#\{userId\} and sort key ORDER#\{date\} to co-locate each user's orders and enable date-range queries within a partition.

**Full answer:**
DynamoDB is a key-value and document store where the partition key (also called the hash key) determines which physical partition stores the item, and the optional sort key (also called the range key) allows ordering and range queries within that partition. If I store users and orders in the same table using a single-table design pattern, I might set PK=`USER#123` and SK=`ORDER#2024-01-15` for an order item, and PK=`USER#123`, SK=`PROFILE` for the user's profile record. This design means all of user 123's data lives in the same partition — partitions are the unit of co-location in DynamoDB, and reads within a single partition are fast and cheap. I can then query all orders for user 123 in a date range by doing a Query operation with PK=`USER#123` and SK BETWEEN `ORDER#2024-01-01` AND `ORDER#2024-12-31`, which is a single-partition range scan with no scatter-gather overhead. The danger to avoid is choosing a partition key with low cardinality — for example, if I used ORDER_STATUS as the partition key, all pending orders go to one partition, all completed to another, creating a hot partition that throttles my throughput because DynamoDB caps each partition at 3,000 RCUs and 1,000 WCUs per second. High-cardinality keys like `user_id` distribute the load evenly across many partitions.

*Single-table design in DynamoDB is a common interview topic — explain the PK/SK pattern clearly.*

> **Gotcha follow-up:** How do you add a new access pattern — say "find all orders placed on a given date across all users" — without doing a full table scan?
> I create a Global Secondary Index (GSI) with a new partition key of ORDER_DATE and a sort key of USER_ID; the GSI is an eventually consistent separate index with its own provisioned capacity, and it lets me query all orders for a given date efficiently without touching the base table.

---

**Q7: What is the difference between a DynamoDB LSI and a GSI, and when do you use each?**
*Tradeoff Question*

**One-line answer:** An LSI (Local Secondary Index) keeps the same partition key and adds an alternate sort key; a GSI (Global Secondary Index) defines an entirely different partition key and supports new access patterns.

**Full answer:**
In DynamoDB, indexes exist to support access patterns that the base table's primary key does not directly serve. A Local Secondary Index (LSI) shares the same partition key as the base table but uses a different sort key — for example, if my base table has PK=USER_ID and SK=ORDER_DATE, an LSI could have PK=USER_ID and SK=TOTAL_AMOUNT, letting me query a user's orders sorted by amount instead of date. Because the LSI lives in the same partition as the base data, it shares the partition's provisioned throughput, supports both strong and eventual consistency, and can only be created at table creation time — I cannot add an LSI to an existing table. A Global Secondary Index (GSI) uses a completely different partition key, which means it spans all partitions of the base table, making it truly "global"; it always provides only eventual consistency and has its own separately provisioned read and write capacity units, which I must monitor and scale independently. I can create a GSI at any time after table creation, which makes it much more flexible for evolving access patterns. I use an LSI when I need an alternate sort order within a partition and I know the access pattern at design time; I use a GSI when I need to query by an attribute that is not related to the base partition key at all.

*A common mistake is forgetting that GSI writes consume capacity from the GSI's provisioned units, not the base table's — undersizing a GSI causes throttling.*

> **Gotcha follow-up:** What happens to a GSI if the base table item is deleted?
> DynamoDB asynchronously propagates deletes to GSIs, so there is a brief eventual-consistency window where a deleted item may still appear in a GSI query; for most use cases this is acceptable, but critical reads should fall back to the base table for confirmation.

---

**Q8: How do you design a Cassandra partition key for time-series sensor data?**
*Design Scenario*

**One-line answer:** Bucket the time dimension into fixed intervals in the partition key — for example (sensor_id, YYYY-MM-DD) — to prevent unbounded partition growth while keeping time-range queries efficient.

**Full answer:**
Cassandra stores all rows with the same partition key together on disk, sorted by the clustering key (which is like DynamoDB's sort key), and a partition can only live on one node — so if a partition grows without bound, one node ends up holding disproportionate data and serving all queries for that partition, creating a hot node. If I naively set the partition key to just sensor_id and the clustering key to timestamp, a sensor that has been running for three years would accumulate millions of rows in a single partition that keeps growing indefinitely. The solution is time-bucketing: I compose the partition key as (sensor_id, bucket) where bucket is a truncated time value like YYYY-MM-DD or YYYY-WW (year and week number), chosen so that each partition stays under roughly 100MB — Cassandra's recommended guideline for partition size. With this design, a query for "sensor 42's readings for the past week" reads from at most 7 partitions, which is a small and bounded amount of scatter-gather work. The bucket granularity depends on the write rate: a sensor writing 1KB per second generates about 86MB per day, so a daily bucket is appropriate; a higher-frequency sensor might need hourly buckets. I always include the sensor_id in the partition key because my primary access pattern is "readings for a specific sensor," and I want those rows co-located.

*Cassandra partition sizing is a favourite Cassandra-specific interview topic — know the 100MB guideline.*

> **Gotcha follow-up:** How do you query across bucket boundaries, for example "the last 30 days of data for sensor 42"?
> I must query 30 separate partitions — one per day — in the application layer, either in parallel or sequentially, and merge the results. This is the inherent tradeoff of time-bucketing: it bounds partition size but pushes multi-bucket range queries to the application.

---

**Q9: Walk me through the MongoDB aggregation pipeline and how to use it efficiently.**
*Concept Check*

**One-line answer:** The aggregation pipeline is a sequence of transformation stages that process documents in order; placing `$match` and `$sort` early lets MongoDB use indexes and reduces the document volume for expensive later stages.

**Full answer:**
MongoDB's aggregation pipeline processes a stream of documents through a sequence of stages, where each stage transforms the output of the previous one — conceptually similar to SQL's logical execution order. The most important stages I use are `$match` (filters documents by a condition, equivalent to SQL WHERE), `$group` (aggregates documents by a key and computes expressions like `$sum` or `$avg`, equivalent to GROUP BY), `$sort` (orders results), `$limit` and `$skip` (pagination), `$lookup` (performs a left outer join to another collection, equivalent to SQL JOIN), `$unwind` (deconstructs an array field so each element becomes a separate document — necessary before grouping on nested arrays), and `$project` (selects or renames fields, equivalent to SELECT). The key efficiency rule is to put `$match` as early as possible in the pipeline, before `$unwind` or `$lookup`, so that indexes can filter the document set down before the expensive stages run; if I put `$match` after `$unwind`, MongoDB must first explode every array in every document before filtering, which is enormously wasteful. Similarly, if my pipeline starts with `$match` followed by `$sort` on indexed fields, MongoDB can use an index to satisfy both stages without loading documents into memory. I also use `$facet` when I need to compute multiple independent aggregations in a single pass — for example, a search results page that simultaneously returns paginated results and a count of total matches.

*Always mention the "put `$match` first" optimization — it shows you understand pipeline execution, not just syntax.*

> **Gotcha follow-up:** How does `$lookup` perform at scale, and what is the alternative?
> `$lookup` performs a nested-loop join under the hood, which becomes expensive on large collections; the alternative at scale is to denormalize related data into the same document at write time (embed rather than reference), accepting write overhead and data duplication in exchange for single-document reads.

---

**Q10: How does Redis Cluster distribute data using hash slots?**
*Concept Check*

**One-line answer:** Redis Cluster divides the key space into 16,384 hash slots using CRC16, assigns ranges of slots to masters, and uses hash tags to co-locate related keys on the same slot.

**Full answer:**
Redis Cluster is the built-in sharding mechanism in Redis that lets me spread data across multiple master nodes without a proxy. The key space is divided into exactly 16,384 slots, numbered 0 to 16,383, and every key is assigned to a slot by computing `CRC16(key) % 16384` — CRC16 is a checksum algorithm that produces a consistent numeric value for any string. Each master node in the cluster is assigned ownership of a contiguous range of slots, and any key whose slot falls in that range is stored on that node. When a client sends a command for a key to the wrong node, that node responds with a MOVED redirect that includes the correct node's address, allowing the client to retry; a MOVED redirect means the slot has permanently moved, whereas an ASK redirect is a temporary redirect during an ongoing slot migration. The challenge with this scheme is that a multi-key operation (like `MGET` or a Lua script) only works if all involved keys live on the same slot — hash tags solve this by letting me force keys to the same slot: if a key contains a string enclosed in curly braces, only the part inside the braces is used for hashing, so `{user:123}.profile` and `{user:123}.settings` both hash on `user:123` and land on the same slot, enabling atomic multi-key operations.

*Know the difference between MOVED (permanent) and ASK (in-progress migration) — it comes up in cluster troubleshooting questions.*

> **Gotcha follow-up:** What happens during a hash slot migration between nodes?
> Keys are moved one at a time from the source node to the destination node while both nodes remain online; during the migration, the source issues ASK redirects for migrating keys so clients go to the destination, and MOVED redirects only become permanent once the slot migration is complete and the cluster configuration is updated.

---

**Q11: Explain how Elasticsearch indexes text and scores search results.**
*Concept Check*

**One-line answer:** Elasticsearch builds an inverted index mapping terms to the documents containing them, then scores results using BM25, which rewards documents where the search term appears frequently but in a short field.

**Full answer:**
When I index a document in Elasticsearch, the text fields go through an analysis pipeline — tokenization (splitting "Quick Brown Fox" into ["quick", "brown", "fox"]), normalization (lowercasing, stemming), and stop-word removal — and the resulting tokens are stored in an inverted index, which is a data structure that maps each unique token to a list of document IDs, positions, and frequencies that contain it. When a search query arrives, Elasticsearch looks up each query term in the inverted index, retrieves the matching document lists, and computes a relevance score for each document. The default scoring algorithm is BM25 (Best Match 25), which combines three factors: Term Frequency (TF) measures how often the search term appears in the document, but with saturation — doubling the count doesn't double the score, because after a point extra occurrences matter less; Inverse Document Frequency (IDF) measures how rare the term is across all documents — a term like "the" that appears in every document gets a near-zero IDF score, while a rare technical term gets a high IDF score; and field length normalization penalizes documents where the term appears in a very long field, because finding "database" in a 5-word title is more significant than finding it in a 5,000-word article. For query types, I use `match` queries for full-text search (text goes through the same analysis pipeline), `term` queries for exact keyword matching (no analysis, used on keyword fields), `range` for numeric or date ranges, and `bool` with `must`, `should`, and `must_not` clauses to compose complex queries.

*Explain the difference between `match` and `term` — a very common interview gotcha.*

> **Gotcha follow-up:** Why does a `term` query on an analyzed text field often return no results?
> A `term` query does not analyze the input, so if I search for `term: "Quick Brown"` on a field that was indexed as `["quick", "brown", "fox"]`, it finds nothing because the exact string "Quick Brown" never existed as a token; I must use a `match` query for full-text fields so the query string goes through the same analysis as the indexed text.

---

**Q12: What is the difference between Flyway and Liquibase, and how do they integrate with Spring Boot?**
*Concept Check*

**One-line answer:** Both are database migration tools that version-control schema changes; Flyway uses SQL files with a strict naming convention, while Liquibase uses changelogs in XML/YAML/JSON/SQL with rollback support built in.

**Full answer:**
Database migration tools let me track schema changes as versioned artifacts in source control so that every environment — developer laptops, CI, staging, production — applies exactly the same sequence of changes in the same order. Flyway takes a convention-over-configuration approach: I create SQL files named `V1__create_users_table.sql`, `V2__add_email_index.sql`, and so on, and Flyway applies unapplied migrations in version order, recording each one in a `flyway_schema_history` table. The naming format `V{version}__{description}.sql` is strictly required — a double underscore separates version from description. Liquibase takes a more structured approach: I define changes as changesets in a changelog file (XML, YAML, JSON, or SQL), each with an `id` and `author` attribute, and Liquibase tracks applied changesets in a `DATABASECHANGELOG` table; the key advantage is that Liquibase has built-in rollback support — each changeset can declare a rollback operation, letting me undo migrations programmatically. Both tools integrate with Spring Boot via auto-configuration: I add `spring-boot-starter-flyway` or `liquibase-core` to my dependencies, provide the migration files in the standard location (`db/migration` for Flyway, `db/changelog` for Liquibase), and Spring Boot automatically runs pending migrations on startup. I prefer Flyway for simpler projects where SQL is all I need, and Liquibase when I need rollback support or want to manage migrations in a database-agnostic format like YAML.

*Know the Flyway naming convention cold — `V`, then version, then `__` double underscore, then description.*

> **Gotcha follow-up:** Can you modify a Flyway migration file after it has been applied?
> No — Flyway stores a checksum of each applied migration, and if the file changes, Flyway throws a validation error on the next startup; the correct approach is to create a new migration file for any further changes, never editing an already-applied one.

---

**Q13: What is the expand-contract migration pattern, and why is it needed for zero-downtime deployments?**
*Design Scenario*

**One-line answer:** Expand-contract (also called parallel change) splits a breaking schema change into three phases — add the new structure, migrate data, remove the old structure — so no single deployment breaks the running application.

**Full answer:**
Zero-downtime deployment means I can roll out a new version of the application without taking the service offline, but this creates a constraint: during the rollout, both the old version and the new version of the app are running simultaneously, reading and writing the same database, so the schema must be compatible with both versions at the same time. A renaming a column — say from `user_name` to `username` — is a classic problem: if I rename it in one step, the old app version breaks immediately because it references `user_name` which no longer exists. The expand-contract pattern solves this with three separately deployed phases. In the Expand phase, I add the new `username` column (without dropping `user_name`), and I update the application to write to both columns and read from the old `user_name` column; the database now has both columns and both app versions work. In the Migrate phase, I run a backfill script (or a background job) that copies data from `user_name` into `username` for all existing rows, then update the application to read from the new `username` column; now both columns are populated and the new app reads from the right place. In the Contract phase, after confirming no old-version instances are running, I drop the `user_name` column; the schema is clean and the migration is complete. Each phase is a separate deployment, which means the process takes longer but never causes an outage.

*This pattern applies to any breaking schema change: column renames, type changes, table splits.*

> **Gotcha follow-up:** What happens if you skip the migrate phase and go straight from expand to contract?
> Any rows written between the expand deployment and the contract deployment will have a populated `user_name` but an empty `username`, so after the contract phase drops `user_name`, that data is permanently lost; the migrate phase exists precisely to ensure 100% of data is backfilled before removing the old column.

---

**Q14: Which DDL operations in PostgreSQL require a table lock and how do you work around them?**
*Concept Check*

**One-line answer:** Adding a column with a default, adding an index, and altering a column type each have different locking behaviors; `CREATE INDEX CONCURRENTLY` and the expand-contract pattern are the key tools for avoiding table locks in production.

**Full answer:**
A table lock (specifically an Access Exclusive Lock) prevents all reads and writes to a table while a DDL operation runs, which can cause an outage on a busy table. In PostgreSQL 11 and later, adding a column with a constant default value is instantaneous — PostgreSQL stores the default in the system catalog and computes it on the fly rather than rewriting every row, so no table lock is needed for long. Before PostgreSQL 11, `ALTER TABLE ADD COLUMN DEFAULT` rewrote the entire table, which was catastrophically slow on large tables. Creating an index with the standard `CREATE INDEX` statement takes an Access Share Lock that blocks writes; `CREATE INDEX CONCURRENTLY` avoids this by building the index in multiple passes without blocking writes, though it takes longer and can fail if a unique constraint is violated during the build. Changing a column's data type with `ALTER COLUMN TYPE` requires a full table rewrite in most cases, which takes an exclusive lock for the entire duration — for a large table this means minutes of downtime; the correct approach is the expand-contract pattern: add a new column of the correct type, backfill it, update the app to use it, then drop the old column. Dropping a column is fast because PostgreSQL simply marks the column as invisible in the catalog; the physical space is only reclaimed the next time `VACUUM FULL` or `CLUSTER` is run. MySQL's `pt-online-schema-change` tool handles this differently by creating a shadow copy of the table, applying the change, using triggers to keep the copy in sync during the copy process, then atomically swapping the tables.

*Always lead with `CREATE INDEX CONCURRENTLY` when asked about adding indexes to production tables.*

> **Gotcha follow-up:** What is the danger of running `CREATE INDEX CONCURRENTLY` in a transaction?
> `CREATE INDEX CONCURRENTLY` cannot run inside a transaction block; if I wrap it in a `BEGIN`/`COMMIT`, PostgreSQL will raise an error, so it must be run as a standalone statement outside any explicit transaction.

---

**Q15: Compare the three multi-tenancy patterns — when would you choose each one?**
*Tradeoff Question*

**One-line answer:** Separate databases give the most isolation but the highest cost; shared schema with a tenant_id column is cheapest but requires disciplined query filtering; row-level security gives strong database-enforced isolation at low cost.

**Full answer:**
Multi-tenancy means a single deployment of my application serves multiple customers (tenants), and the key design question is how to isolate each tenant's data. The separate database per tenant pattern gives the strongest isolation — each tenant has their own database server or at least their own database, so a runaway query from one tenant cannot affect another, and I can offer tenant-specific backup schedules, data residency, and schema versions; this is appropriate for enterprise customers with compliance requirements, but it is the most expensive pattern operationally because I must manage N databases and run N connection pools. The separate schema per tenant pattern stores each tenant's tables in a different schema within the same database; I get reasonable isolation (schema search paths prevent accidental cross-tenant queries) and can still share the database server's resources, which is a good middle ground for mid-size SaaS products, though schema creation and migration management become more complex as tenant count grows. The shared schema with a `tenant_id` column pattern stores all tenants' data in the same tables, using a `tenant_id` column on every table to identify which tenant each row belongs to; this is the cheapest and most scalable pattern — I can serve thousands of tenants on a handful of servers — but it is the most dangerous if I forget to include `WHERE tenant_id = ?` in a query, which could expose one tenant's data to another. Row-Level Security (RLS) in PostgreSQL addresses this danger: I define a policy like `USING (tenant_id = current_setting('app.current_tenant')::bigint)` on each table, and the database automatically filters every query by the current tenant's ID set in the session, so even if the application forgets the WHERE clause, the database enforces the isolation.

*RLS is the elegant answer that shows depth — mention it explicitly.*

> **Gotcha follow-up:** What is the risk of using Row-Level Security without careful policy design?
> RLS policies apply to SELECT, INSERT, UPDATE, and DELETE, but superusers and table owners bypass RLS by default; if the application connects as the table owner, RLS is silently bypassed, so I must connect as a non-owner role and explicitly enable `FORCE ROW LEVEL SECURITY` on the table to ensure even privileged connections are filtered.

---

**Common Mistakes:**
- **Choosing timestamp as shard key** → all writes land on the current shard; use high-cardinality attributes like user_id instead
- **Forgetting R + W > N for strong consistency** → using W=1, R=1 on N=3 reads stale data; recalculate quorum sizes when changing replication factor
- **Creating DynamoDB indexes without monitoring capacity** → GSIs have separate provisioned units; a GSI write throttle silently drops writes to the index
- **Unbounded Cassandra partitions** → partition grows indefinitely; always bucket time-series partition keys with a date/week component
- **Using term query on analyzed text field in Elasticsearch** → returns zero results; use match query for full-text fields and term query only for keyword fields
- **Modifying an applied Flyway migration** → checksum mismatch fails application startup; always create a new versioned migration file

**Quick Revision:** Distributed DB = know your R+W>N quorum math, shard key cardinality rules, and always bucket time-series partition keys.

---

## Section 5: Quick Reference Q&As

**Q1: Walk me through the SQL logical execution order and why it matters for writing correct queries.**
*Concept Check*

**One-line answer:** SQL is processed in the order FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT, which is why SELECT aliases cannot be referenced in WHERE.

**Full answer:**
Understanding SQL's logical execution order — the sequence in which the database engine conceptually evaluates each clause — prevents a whole class of confusing errors where syntactically valid SQL produces unexpected results. Execution starts with FROM, which identifies the base tables, then JOIN, which adds related rows from other tables; at this point the full combined row set exists in memory. WHERE then filters individual rows before any grouping happens — this is why I cannot use a SELECT alias in a WHERE clause, because the alias hasn't been computed yet at the point WHERE runs; the database doesn't know what `total_amount` means in WHERE because SELECT hasn't run. GROUP BY then collapses filtered rows into groups, and HAVING filters those groups — HAVING is the right place to write aggregate conditions like `HAVING COUNT(*) > 5`, not WHERE, because COUNT doesn't exist until after GROUP BY. SELECT runs next, computing expressions and aliases from the grouped results, followed by DISTINCT which removes duplicate output rows, then ORDER BY which sorts — ORDER BY can reference SELECT aliases because it runs after SELECT. Finally, LIMIT and OFFSET restrict the number of returned rows. In practice, this order explains why `SELECT YEAR(created_at) AS yr FROM orders WHERE yr = 2024` fails in most databases — I must repeat the expression in WHERE as `WHERE YEAR(created_at) = 2024` because the alias `yr` doesn't exist at WHERE evaluation time.

*This question is asked surprisingly often — the key gotcha is WHERE vs HAVING and the alias visibility rule.*

> **Gotcha follow-up:** Can ORDER BY reference a SELECT alias?
> Yes — ORDER BY runs after SELECT in the logical execution order, so aliases defined in SELECT are visible to ORDER BY; this is one of the few places in SQL where you can reference a SELECT alias directly.

---

**Q2: What are all the ACID isolation levels, what anomaly does each prevent, and what does PostgreSQL do differently?**
*Concept Check*

**One-line answer:** The four isolation levels build up from allowing dirty reads to preventing all concurrency anomalies; PostgreSQL's REPEATABLE READ also prevents phantom reads via MVCC, which is stronger than the SQL standard requires.

**Full answer:**
ACID isolation levels define how much a transaction is exposed to the concurrent activity of other transactions, with higher isolation providing stronger guarantees at the cost of reduced concurrency. READ UNCOMMITTED is the lowest level — a transaction can read rows modified by other transactions that haven't committed yet, called a dirty read; this anomaly means I might base a decision on data that gets rolled back. READ COMMITTED prevents dirty reads by only seeing committed data, but it allows non-repeatable reads — if I read the same row twice in the same transaction, another transaction can commit a change in between, so I get different values each time. REPEATABLE READ prevents non-repeatable reads by guaranteeing that any row I read once will show the same value for the rest of my transaction, but the SQL standard allows phantom reads at this level — a range query might return different rows on a second execution if another transaction inserted matching rows in between. SERIALIZABLE is the highest level, preventing all anomalies including write skew — where two transactions read the same data, each makes a decision based on it, and both write back changes that together violate a constraint neither violated individually. PostgreSQL's implementation is notable: it uses MVCC (Multi-Version Concurrency Control, a technique where each transaction sees a snapshot of the database as it existed at a point in time) so aggressively that its REPEATABLE READ level already prevents phantom reads, which is stronger than the SQL standard requires for that level; PostgreSQL's SERIALIZABLE uses SSI (Serializable Snapshot Isolation) to detect write skew without taking table-level locks.

*Know that PostgreSQL REPEATABLE READ blocks phantoms — interviewers who know PostgreSQL well will test this.*

> **Gotcha follow-up:** What is a write skew anomaly and which isolation level prevents it?
> Write skew occurs when two transactions each read a set of rows, check a condition, and then write different rows — individually both writes are valid, but together they violate the condition; for example, two on-call schedule transactions both see one doctor on call, both decide they can go off-call, and both commit, leaving nobody on call. Only SERIALIZABLE prevents write skew.

---

**Q3: Compare Cassandra, DynamoDB, MongoDB, Redis, and Elasticsearch — when would you choose each?**
*Tradeoff Question*

**One-line answer:** Each database is optimized for a different primary use case — Cassandra and DynamoDB for high-write time-series or key-value data, MongoDB for flexible documents, Redis for caching and real-time structures, and Elasticsearch for full-text search.

**Full answer:**
Cassandra is a wide-column store optimized for high-throughput, geographically distributed writes with no single point of failure; I choose it for time-series data, event logs, or IoT telemetry where I need to write millions of events per second across multiple datacenters and can accept eventual consistency — its masterless architecture (any node can accept writes) gives it exceptional write availability. DynamoDB is Amazon's managed key-value and document store; I choose it when I want near-zero operational overhead, need single-digit millisecond latency at any scale, and my access patterns are well-defined in advance — the tradeoff is that its rigid partition and sort key model requires careful upfront data modeling, and poorly chosen partition keys cause expensive hot partitions. MongoDB is a document store where each record is a JSON-like document that can have nested objects and arrays; I choose it when my data has a naturally hierarchical, variable structure — like a product catalog where different product categories have different attributes — and when I want flexible querying without defining a fixed schema upfront; it supports secondary indexes, aggregation pipelines, and multi-document transactions. Redis is an in-memory data structure store; I choose it for caching (storing frequently read database results to avoid expensive recomputation), session storage, rate limiting counters, pub/sub messaging, or leaderboards — its key strength is microsecond read and write latency because all data lives in RAM, with optional persistence to disk. Elasticsearch is a distributed search engine built on Apache Lucene; I choose it when full-text search is the primary requirement — product search, log analysis, or any use case where I need relevance scoring, fuzzy matching, or faceted filtering — not as a primary database, but as a specialized search index that I keep in sync with a source of truth.

*Frame each choice around the primary access pattern it excels at, not just the data model.*

> **Gotcha follow-up:** Why should you not use Elasticsearch as your primary database?
> Elasticsearch prioritizes search performance over strict data durability and consistency — it has a brief window after an index operation where data may not be visible to search (near-real-time refresh), does not support multi-document ACID transactions, and complex updates require fetching and re-indexing entire documents; it is designed to be fed from a durable source of truth like PostgreSQL, not to be that source of truth itself.

---

**Q4: What HikariCP connection pool settings do you tune, and why?**
*Concept Check*

**One-line answer:** The critical settings are `maximum-pool-size` (bounded by the CPU formula), `connection-timeout` (client wait limit), `max-lifetime` (must be less than the database's idle connection timeout), and `leak-detection-threshold` for diagnosing connection leaks.

**Full answer:**
HikariCP is the default JDBC connection pool in Spring Boot, and a connection pool is a cache of open database connections that are reused across requests rather than created and torn down for every query — because opening a TCP connection and authenticating to a database takes tens of milliseconds, pooling is essential for performance under load. The most important setting is `maximum-pool-size`, which caps how many connections the pool will open to the database; a counterintuitive finding from HikariCP's author is that more connections are not always better — the recommended formula is `connections = (number of CPU cores × 2) + effective_spindle_count` where spindle count is the number of physical disk spindles (SSDs count as 1); going far above this causes the database server to spend more time context-switching between connection threads than doing actual work. The `minimum-idle` setting controls how many connections are kept warm when the pool is lightly loaded; setting it equal to `maximum-pool-size` creates a fixed-size pool that never tears down connections, reducing latency spikes. `connection-timeout` (default 30 seconds) is the maximum time a thread waits for a connection from the pool before throwing an exception — if this fires often, my pool is too small. `max-lifetime` (default 30 minutes) is the maximum age of a connection in the pool; it must be set a few seconds shorter than the database server's `wait_timeout` (MySQL) or `idle_in_transaction_session_timeout` (PostgreSQL), otherwise the database silently closes idle connections and the pool hands out broken connections. `keepalive-time` periodically sends a ping query on idle connections to prevent firewall or NAT rules from closing them. `leak-detection-threshold` logs a warning if a connection is held for longer than the threshold without being returned to the pool, which is invaluable for diagnosing connection leaks.

*`max-lifetime` vs DB `wait_timeout` is a classic production gotcha — set max-lifetime shorter than the DB timeout.*

> **Gotcha follow-up:** What happens if `max-lifetime` is set higher than the database's connection idle timeout?
> The database silently closes connections that have been idle longer than its timeout, but HikariCP doesn't know this; the next time a thread checks out one of these dead connections, it gets a connection error; HikariCP will retry and open a new connection, but the first request to get the stale connection fails — causing intermittent "connection reset" or "broken pipe" errors in production.

---

**Q5: Compare the three sharding strategies — range, hash, and directory — for a trade-off interview question.**
*Tradeoff Question*

**One-line answer:** Range sharding excels at range queries but risks hot spots; hash sharding distributes evenly but breaks range queries; directory sharding offers full flexibility but introduces a lookup-table bottleneck.

**Full answer:**
When an interviewer asks me to compare sharding strategies, I frame the comparison around three axes: query patterns supported, distribution evenness, and operational complexity. Range sharding assigns each shard a contiguous range of the key space — for example, orders with IDs 1–1,000,000 on shard A and 1,000,001–2,000,000 on shard B; the major advantage is that range scans ("give me all orders from last week") are routed to a single shard or a small contiguous set of shards, making them very efficient. The danger is hot spots: if my key is a timestamp, all current writes land on the shard owning the current time range, overwhelming it while older shards sit idle. Hash sharding computes a hash of the key and uses modulo to assign the row to a shard — this spreads writes and reads evenly across shards regardless of the key's natural distribution, which eliminates hot spots. The downside is that the hash destroys key ordering, so any range query must be sent to all shards and the results merged at the application layer, a scatter-gather operation that multiplies latency and increases inter-node traffic. Directory sharding maintains an explicit mapping table that says "key X lives on shard Y"; this is maximally flexible — I can assign any key to any shard, move individual keys without rehashing, and co-locate related keys on purpose — but the mapping table is a centralized component that must be highly available and introduces a network round-trip for every lookup.

*When asked to pick one, say: "I'd use hash sharding as the default for write-heavy workloads, range sharding for time-series data with bounded time ranges, and directory sharding only when I need precise control over data placement for compliance or co-location reasons."*

> **Gotcha follow-up:** What is the operational challenge of re-sharding with range sharding vs. hash sharding?
> With range sharding, re-sharding means choosing new range boundaries and migrating a contiguous block of rows — the scope of migration is clear and targeted; with hash sharding, changing the number of shards changes the modulo N, which reassigns almost every key to a different shard, requiring a near-total data migration unless I use consistent hashing.

---

**Common Mistakes:**
- **Confusing WHERE and HAVING** → WHERE runs before GROUP BY and cannot use aggregate functions; HAVING runs after and is for aggregate conditions
- **Assuming PostgreSQL REPEATABLE READ allows phantoms** → it does not; PostgreSQL's MVCC implementation prevents phantoms at REPEATABLE READ, stronger than the SQL standard
- **Setting HikariCP max-lifetime equal to or greater than DB wait_timeout** → dead connections handed to application threads cause intermittent connection errors; set max-lifetime shorter by at least 30 seconds
- **Choosing MongoDB for high-write append-only workloads** → it lacks Cassandra's masterless write scalability; choose the database that matches the primary access pattern
- **Equating more connection pool threads with more throughput** → beyond the CPU formula, extra threads increase context switching and reduce throughput

**Quick Revision:** SQL runs FROM-JOIN-WHERE-GROUP-HAVING-SELECT-ORDER-LIMIT; isolation levels layer on anomaly prevention; each NoSQL database is designed for one primary access pattern.

---

## Section 6: Must-Know SQL Patterns

**Q1: How would you find the Nth highest salary in SQL, handling ties correctly?**
*Concept Check*

**One-line answer:** Use `DENSE_RANK()` rather than `ROW_NUMBER()` so that employees with the same salary share the same rank, and the Nth dense rank returns all employees at that salary level.

**Full answer:**
Finding the Nth highest salary is a classic SQL interview question that tests knowledge of window functions — functions that compute a value for each row based on a set of related rows (the "window") without collapsing the result set the way GROUP BY does. The naive approach with ROW_NUMBER() assigns a unique sequential rank to each row, so if three employees all earn 50,000 (the second highest), one gets rank 2, one gets rank 3, and one gets rank 4; asking for the "3rd highest" with ROW_NUMBER returns just one of those employees, not all of them, which is usually wrong. DENSE_RANK() solves this by assigning the same rank to employees with identical salaries and not skipping ranks afterward: if 80,000 is rank 1 and three employees earn 50,000, all three get rank 2, and the next salary gets rank 3. The window-function approach looks like: `SELECT * FROM (SELECT name, salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk FROM employees) ranked WHERE rnk = N`. An alternative approach for databases without window function support is a correlated subquery: `SELECT MIN(salary) FROM employees WHERE salary IN (SELECT DISTINCT salary FROM employees ORDER BY salary DESC LIMIT N)`, but this is less readable and often less performant. When the question asks about "Nth highest per department," I add `PARTITION BY department_id` inside the OVER clause, which resets the ranking for each department independently.

*Always mention the ties problem first — it shows you've been burned by ROW_NUMBER on this exact question.*

> **Gotcha follow-up:** What is the difference between RANK() and DENSE_RANK()?
> Both assign the same rank to tied rows, but RANK() skips subsequent rank numbers after a tie — so if two employees tie for rank 2, the next rank is 4, not 3 — while DENSE_RANK() never skips ranks, so the next rank after a tie at 2 is always 3; for most salary-ranking problems, DENSE_RANK() is what you want.

---

**Q2: How do you detect and delete duplicate rows in SQL?**
*Concept Check*

**One-line answer:** Detect duplicates with GROUP BY and HAVING COUNT(*) > 1; delete them by keeping the minimum ID per group and deleting all others using a subquery or CTE.

**Full answer:**
Duplicate rows occur when data is inserted multiple times without a unique constraint to prevent it, and cleaning them up requires identifying which rows are duplicates and which to keep. To find duplicate emails in a users table, I use: `SELECT email, COUNT(*) FROM users GROUP BY email HAVING COUNT(*) > 1` — the GROUP BY groups rows with the same email together, and HAVING COUNT(*) > 1 filters to groups with more than one row, which are the duplicates. To delete duplicates while keeping one row per email — typically the row with the lowest ID, assuming ID is an auto-increment primary key — I use: `DELETE FROM users WHERE id NOT IN (SELECT MIN(id) FROM users GROUP BY email)`, which keeps the minimum ID for each email group and deletes all other rows. In PostgreSQL specifically, a more efficient approach for large tables uses the `ctid` system column — a physical row identifier unique to PostgreSQL — in a self-join: `DELETE FROM users a USING users b WHERE a.email = b.email AND a.ctid > b.ctid`, which deletes the physically later duplicate for each email pair. Before running any DELETE, I always wrap it in a transaction and SELECT first to verify the rows I am about to delete are exactly the ones I intend to remove, then commit or rollback.

*Always verify with a SELECT before committing the DELETE — interviewers look for this discipline.*

> **Gotcha follow-up:** What would happen if you ran the NOT IN subquery-based delete and one of the emails is NULL?
> NOT IN returns false for every row when the subquery contains a NULL, because `value NOT IN (NULL, ...)` evaluates to UNKNOWN in SQL's three-valued logic; the DELETE would delete no rows at all, leaving all duplicates in place. I must add `WHERE email IS NOT NULL` or use NOT EXISTS instead, which handles NULLs correctly.

---

**Q3: How do you compute a running total in SQL, and what is the difference between ROWS and RANGE window frames?**
*Concept Check*

**One-line answer:** Use `SUM(amount) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` for a running total; ROWS counts physical rows while RANGE includes all rows with the same ORDER BY value as the current row.

**Full answer:**
A running total is a cumulative sum where each row shows the total of all values up to and including that row — for example, a bank account balance after each transaction. I compute it with a window function: `SELECT order_date, amount, SUM(amount) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total FROM orders`. The OVER clause defines the window, ORDER BY specifies the order in which rows are accumulated, and the frame clause `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` specifies that the window for each row includes all rows from the beginning of the partition up to and including the current physical row. The difference between ROWS and RANGE is subtle but important: ROWS counts physical rows — the frame always ends at exactly the current row regardless of its ORDER BY value. RANGE includes all rows whose ORDER BY value is less than or equal to the current row's ORDER BY value, which means if two rows have the same date, both are included in each other's window; for a running total with duplicate dates, RANGE produces a "look-ahead" sum that includes all rows with the same date rather than accumulating one at a time, which can produce unexpected jumps. For strict running totals where I want to accumulate row by row, ROWS is the correct choice. I can also reset the running total per group using PARTITION BY — for example, a running total per customer: `SUM(amount) OVER (PARTITION BY customer_id ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`.

*The ROWS vs RANGE distinction is a favourite deep-cut window function question.*

> **Gotcha follow-up:** What does `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` compute?
> That frame includes every row in the entire partition regardless of position, so it computes the grand total of the entire partition for every row — effectively the same as a subquery or GROUP BY total applied back to each row, useful for computing a percentage of total.

---

**Q4: How do you find gaps in a numeric sequence in SQL?**
*Concept Check*

**One-line answer:** Use a self-join where you look for IDs where `id + 1` does not exist in the table, or use `generate_series` in PostgreSQL to produce all expected IDs and LEFT JOIN to find which ones are missing.

**Full answer:**
A gap in a numeric sequence means there are values that should be present but are not — for example, invoice numbers 1, 2, 3, 5 have a gap at 4. The classic self-join approach: `SELECT s1.id + 1 AS gap_start FROM sequence s1 LEFT JOIN sequence s2 ON s2.id = s1.id + 1 WHERE s2.id IS NULL AND s1.id < (SELECT MAX(id) FROM sequence)` — for each row, I try to join to the row whose ID is exactly one greater; if no such row exists (s2.id IS NULL), then s1.id + 1 is missing from the sequence. The condition `s1.id < MAX(id)` excludes the last row, because the value after the maximum is not a gap but simply the end of the data. In PostgreSQL, a more readable approach uses `generate_series` to generate all integers in the expected range and then LEFT JOINs to the actual table: `SELECT gs.id FROM generate_series(1, (SELECT MAX(id) FROM sequence)) AS gs(id) LEFT JOIN sequence s ON s.id = gs.id WHERE s.id IS NULL`, which returns every integer in the expected range that does not have a matching row. The generate_series approach is clearer about the intent and easier to extend — for example, to find gaps in a date sequence I can use `generate_series('2024-01-01'::date, '2024-12-31'::date, '1 day'::interval)`.

*PostgreSQL's generate_series is the clean solution — mention it explicitly for PostgreSQL interviews.*

> **Gotcha follow-up:** How would you find gap ranges (start and end of each gap) rather than individual missing values?
> I can use the `LAG` window function to compare each existing value to the previous one: `SELECT prev_id + 1 AS gap_start, id - 1 AS gap_end FROM (SELECT id, LAG(id) OVER (ORDER BY id) AS prev_id FROM sequence) t WHERE id > prev_id + 1`, which surfaces each gap as a start-end range in a single pass.

---

**Q5: How do you retrieve the top-N rows per group in SQL?**
*Concept Check*

**One-line answer:** Use `ROW_NUMBER() OVER (PARTITION BY group_col ORDER BY ranking_col DESC)` in a subquery or CTE, then filter the outer query to `WHERE rn <= N`; PostgreSQL's DISTINCT ON is a shortcut for the top-1 case.

**Full answer:**
Top-N per group — for example, the top 3 best-selling products per category — requires a combination of window functions and filtering that cannot be expressed with simple GROUP BY. The standard approach wraps a window function in a CTE or derived table: `WITH ranked AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY category ORDER BY sales DESC) AS rn FROM products) SELECT * FROM ranked WHERE rn <= 3`. The PARTITION BY category clause resets the row numbering for each category independently, and ORDER BY sales DESC ensures rank 1 goes to the highest-selling product within that category. I use ROW_NUMBER() rather than DENSE_RANK() here because I want exactly N rows per group — with DENSE_RANK(), tied rows at position N would both get rank N and I'd get more than N rows per group; whether that is correct depends on the business requirement, so I clarify the tie-breaking rule with the interviewer. For the top-1 per group case in PostgreSQL, `DISTINCT ON` is a clean shorthand: `SELECT DISTINCT ON (category) category, product_name, sales FROM products ORDER BY category, sales DESC` returns exactly one row per category — the one with the highest sales — without needing a subquery. The window function approach is portable across all major databases (PostgreSQL, MySQL 8+, SQL Server, Oracle) while DISTINCT ON is PostgreSQL-specific.

*Clarify tie-breaking behavior — it shows you think about edge cases, which interviewers appreciate.*

> **Gotcha follow-up:** Why can't you put a window function directly in a WHERE clause?
> Window functions are evaluated after WHERE in SQL's logical execution order, so by the time the WHERE clause runs, the window function result doesn't exist yet; I must wrap the window function in a subquery or CTE so the outer WHERE can filter on the already-computed rank column.

---

**Common Mistakes:**
- **Using ROW_NUMBER for Nth highest when ties exist** → returns only one tied employee instead of all at that rank; use DENSE_RANK instead
- **NOT IN with a nullable column** → returns zero rows because NULL makes every comparison UNKNOWN; use NOT EXISTS for nullable subqueries
- **Using RANGE instead of ROWS for running totals** → rows with the same ORDER BY value are all included in each other's window, causing jumps instead of row-by-row accumulation; use ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
- **Forgetting to verify DELETE results before committing** → irreversible data loss; always SELECT the rows first, then DELETE inside a transaction
- **Putting a window function in WHERE directly** → SQL error; wrap in a subquery or CTE and filter in the outer query

**Quick Revision:** Window functions need a subquery wrapper for WHERE filtering; DENSE_RANK handles ties; ROWS BETWEEN for strict running totals.

---

## Section 7: Common Traps

**Q1: What is the NOT IN with NULL subquery trap, and how do you fix it?**
*Concept Check*

**One-line answer:** If a subquery used with NOT IN contains any NULL values, the entire NOT IN expression returns no rows because any comparison with NULL evaluates to UNKNOWN in SQL's three-valued logic.

**Full answer:**
SQL uses three-valued logic — TRUE, FALSE, and UNKNOWN — and any comparison involving NULL evaluates to UNKNOWN, not FALSE. When I write `WHERE id NOT IN (SELECT manager_id FROM employees)` and the `manager_id` column contains NULLs (representing employees with no manager), the database evaluates each id against the list including NULL; since `5 != NULL` is UNKNOWN (not TRUE), no row passes the NOT IN filter, and the query returns zero rows — silently, with no error. The fix is to use NOT EXISTS: `WHERE NOT EXISTS (SELECT 1 FROM employees e2 WHERE e2.manager_id = e1.id)`, which correctly handles NULLs because the correlated subquery either finds a matching row (exists) or doesn't (doesn't exist), without any NULL comparison. Alternatively, I can add `WHERE manager_id IS NOT NULL` inside the subquery to explicitly exclude NULLs, but NOT EXISTS is more idiomatic and communicates intent more clearly.

---

**Q2: How does implicit type conversion break index usage?**
*Concept Check*

**One-line answer:** When the filter value's type doesn't match the column type, the database casts the column on every row rather than the value once, preventing index use and forcing a full table scan.

**Full answer:**
If I have a `user_id INTEGER` column with an index and write `WHERE user_id = '123'`, the database must compare an integer column to a string literal. Rather than using the index, the database applies a cast function to every row (`CAST(user_id AS VARCHAR) = '123'`), which forces a sequential scan of the entire table — the index is built on the raw integer values, not the cast results. The fix is simple: always match the literal type to the column type, writing `WHERE user_id = 123` (no quotes). This trap is common in dynamically typed languages like Python or JavaScript where all query parameters might be passed as strings, so I must ensure the ORM or query builder sends parameters with the correct type. In PostgreSQL, implicit casts between compatible types (like integer to bigint) do use indexes, but varchar-to-integer casts are not implicit and will always break index use.

---

**Q3: Why does putting a function on an indexed column prevent index use?**
*Concept Check*

**One-line answer:** Applying a function to a column means the index's pre-computed values can't be matched to the function's output, so the database must compute the function on every row and scan the full table.

**Full answer:**
An index on `created_at` stores the raw timestamp values in sorted order. When I write `WHERE YEAR(created_at) = 2024`, the database cannot look up YEAR=2024 in the raw timestamp index — it would have to evaluate `YEAR(created_at)` for every row in the table and compare to 2024, making the index useless. The rewrite is to express the condition as a range on the raw column: `WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01'`, which the index can satisfy directly with a range scan. The same principle applies to any function: `WHERE LOWER(email) = 'alice@example.com'` won't use an index on `email` because the index stores mixed-case values, not lowercased ones. PostgreSQL allows creating a functional index — `CREATE INDEX ON users (LOWER(email))` — which stores the function's result in the index, letting `WHERE LOWER(email) = 'alice@example.com'` use it; but for most cases, the range rewrite is simpler.

---

**Q4: Why is OFFSET pagination slow at scale, and what is the alternative?**
*Concept Check*

**One-line answer:** OFFSET N forces the database to scan and discard the first N rows before returning results; keyset pagination (also called cursor pagination) avoids this by filtering directly on the last seen value.

**Full answer:**
When I write `SELECT * FROM orders ORDER BY id LIMIT 20 OFFSET 1000000`, the database must read and discard the first million rows before returning the next 20 — the work grows linearly with the page number. For a table with 10 million rows and a user paging through to page 50,000, the query scans half the table just to return 20 rows, making late pages catastrophically slow. Keyset pagination — also called cursor-based pagination — avoids this by using the last seen value as a filter: `SELECT * FROM orders WHERE id > 999980 ORDER BY id LIMIT 20`. Because this is a range predicate on an indexed column, the database uses the index to jump directly to row 999981 and reads forward 20 rows — constant time regardless of how many pages the user has paged through. The tradeoff is that keyset pagination doesn't support random page access ("jump to page 500") and requires a stable sort key with no duplicates; for duplicate sort values I use a composite cursor like `(created_at, id)` to ensure uniqueness.

---

**Q5: What are the problems with SELECT * in production code?**
*Concept Check*

**One-line answer:** SELECT * transfers unnecessary columns over the network, prevents covering index optimizations, breaks if columns are reordered, and may silently include large binary columns that degrade performance.

**Full answer:**
SELECT * retrieves every column in the table, including ones the application doesn't use, which wastes network bandwidth and memory on both the database server and the application server. It also prevents covering index optimizations: if my query only needs `user_id` and `email`, the database can satisfy it entirely from an index on `(user_id, email)` without touching the heap (the main table storage) — but if I write SELECT *, it must fetch every column, forcing a heap access for every row. Schema fragility is another concern: if a new `profile_blob` column storing large binary data is added to the table, all SELECT * queries immediately start transferring that data, potentially multiplying response sizes by 10x with no code change. In ORMs, SELECT * may hydrate full entity objects including lazy-loaded relationships, triggering N+1 queries or loading more data than the use case needs. The fix is always to name the columns explicitly in SELECT, which documents intent, enables covering indexes, and is robust against schema evolution.

---

**Q6: What happens when you don't index a foreign key column in PostgreSQL?**
*Concept Check*

**One-line answer:** PostgreSQL does not automatically create an index on foreign key columns, so every JOIN through the foreign key and every cascading delete performs a sequential scan of the child table.

**Full answer:**
In PostgreSQL, a foreign key constraint ensures referential integrity — for example, `orders.user_id REFERENCES users(id)` — but the constraint itself does not create an index on `orders.user_id`. MySQL does create an index automatically for foreign keys, which makes this a PostgreSQL-specific gotcha. Without the index, every query that joins orders to users via user_id must do a sequential scan of the orders table — reading every row to find those with the matching user_id — rather than using an index to jump directly to the relevant rows. This is especially painful for DELETE operations: if I delete a user, PostgreSQL must scan the entire orders table to check whether any orphaned orders remain (to enforce the FK constraint or apply CASCADE DELETE), which is extremely slow on large tables. The fix is straightforward: `CREATE INDEX ON orders (user_id)` after defining the foreign key. I check for missing FK indexes in production using the query: `SELECT conrelid::regclass, conname FROM pg_constraint WHERE contype = 'f' AND NOT EXISTS (SELECT 1 FROM pg_index WHERE indrelid = conrelid AND indkey[0] = conkey[1])`.

---

**Q7: What is the batch insert problem with IDENTITY/SERIAL columns?**
*Concept Check*

**One-line answer:** Some JDBC drivers fetch auto-generated keys one row at a time after batch inserts, negating the performance benefit of batching; configure the driver and ORM to retrieve keys in bulk.

**Full answer:**
When I insert multiple rows at once using JDBC batch processing — grouping many INSERT statements into a single network round-trip — I often need the database-generated ID for each inserted row to set up relationships. The problem is that calling `getGeneratedKeys()` after a batch insert may, depending on the JDBC driver and database combination, fetch keys through individual round-trips per row rather than in a single response. With PostgreSQL and the pgjdbc driver, I must use `Statement.RETURN_GENERATED_KEYS` and the driver retrieves all generated keys in one shot. With MySQL, the behavior is correct for INSERT batch statements. With Hibernate/JPA, the `IDENTITY` generation strategy disables JDBC batching entirely because Hibernate needs each ID immediately after insertion to set the entity's identity, forcing one INSERT per row; switching to `SEQUENCE` generation lets Hibernate batch multiple inserts because it pre-allocates ID ranges without needing a round-trip after each insert. The fix for Spring Data JPA is to use `@GeneratedValue(strategy = GenerationType.SEQUENCE)` with a custom sequence that has a large `allocationSize` (e.g., 50), configure `spring.jpa.properties.hibernate.jdbc.batch_size=50`, and verify with SQL logging that batch INSERTs are actually being sent.

---

**Q8: Why is a shared database between microservices an anti-pattern?**
*Concept Check*

**One-line answer:** Sharing a database tightly couples microservices at the schema level, preventing independent deployment, breaking encapsulation, and making it impossible to evolve one service's data model without coordinating with all others.

**Full answer:**
The core principle of microservices is that each service is independently deployable, owns its data, and communicates with others only through well-defined APIs. When two services share a database, Service A can read Service B's internal tables directly, bypassing Service B's business logic and validation — this is tight coupling at the data layer, the worst kind, because it's invisible and hard to enforce. A schema change in Service B's tables (renaming a column, splitting a table) immediately breaks Service A, even though they're supposed to be independent; now both services must be tested and deployed together, eliminating the independent deployment benefit. The databases also create a shared resource contention point: a slow query from Service A can starve Service B's connections and degrade its latency. The correct pattern is for each microservice to own its data exclusively — Service A must call Service B's API to access B's data, giving B the opportunity to enforce business rules, evolve its schema independently, and scale its database separately. Data that needs to be shared is replicated via events (event-driven architecture) or queried via synchronous API calls.

---

**Q9: What happens when JDBC auto-commit is left at its default setting?**
*Concept Check*

**One-line answer:** With auto-commit enabled (the JDBC default), every SQL statement is its own transaction that commits immediately, making multi-statement operations non-atomic and preventing rollback on partial failure.

**Full answer:**
JDBC connections have `auto-commit` set to `true` by default, which means every `executeUpdate()` or `executeQuery()` call is automatically wrapped in its own `BEGIN`/`COMMIT` block and committed immediately. For single-statement operations this is often fine, but for any operation that requires multiple statements to execute atomically — for example, debiting one account and crediting another — auto-commit is dangerous: if the debit succeeds and the credit throws an exception, the debit has already committed and cannot be rolled back, leaving the data inconsistent. The fix is to call `connection.setAutoCommit(false)` before the operation, execute all statements, then call `connection.commit()` on success or `connection.rollback()` on failure. In Spring, the `@Transactional` annotation handles this automatically: Spring intercepts the method, disables auto-commit, begins a transaction, runs the method body, and commits on success or rolls back on any unchecked exception. A related trap is using a connection pool with auto-commit disabled globally but forgetting to commit explicitly — this leaves long-running transactions that hold locks and inflate the transaction log.

---

**Q10: How do stale statistics cause bad query plans?**
*Concept Check*

**One-line answer:** The query planner uses table statistics to estimate row counts and choose join strategies; after a bulk load, statistics are stale, causing the planner to choose inefficient nested-loop joins or wrong index use.

**Full answer:**
The PostgreSQL query planner (and equivalent planners in MySQL, SQL Server, etc.) estimates the cost of different execution plans — sequential scan vs. index scan, nested loop join vs. hash join — using statistics about each table: the number of rows, the distribution of values in each column, and the correlation between column values and physical storage order. These statistics are stored in `pg_statistic` and updated by the `ANALYZE` command (automatically by autovacuum, but with a delay). After a bulk data load — for example, importing 10 million rows into a previously empty table — the statistics may still show the old row count (close to zero), causing the planner to estimate that each table scan returns very few rows; it might choose a nested-loop join strategy that is catastrophically slow on 10M rows because nested-loop is only efficient for small row counts. The fix is to run `ANALYZE table_name` (or `ANALYZE` with no argument to analyze all tables) immediately after any bulk load, and to consider running `VACUUM ANALYZE` after bulk deletes as well. I can verify the plan after updating statistics using `EXPLAIN (ANALYZE, BUFFERS)`, which shows both the planner's estimated row counts and the actual row counts from execution.

---

**Q11: What is the N+1 query problem and how do you fix it?**
*Concept Check*

**One-line answer:** N+1 occurs when fetching a list of N parent records triggers N separate queries to fetch each parent's related records; fix it with JOIN FETCH, EntityGraph, or batched IN-clause loading.

**Full answer:**
The N+1 query problem is one of the most common performance issues in ORM-based applications. If I load 100 orders with `orderRepository.findAll()` and then access `order.getCustomer()` inside a loop, each `getCustomer()` call triggers a separate SQL query to fetch that order's customer — I started with 1 query (the N orders) and end up executing 101 queries total (1 + 100 = N+1). Each query has network round-trip overhead, so 100 extra queries can easily add hundreds of milliseconds to a request. The most direct fix in JPA/Hibernate is JOIN FETCH: `SELECT o FROM Order o JOIN FETCH o.customer` loads orders and their customers in a single SQL JOIN, bringing back everything in one round-trip. The `@EntityGraph` annotation lets me define which associations to eagerly load without modifying the JPQL query, keeping the repository methods clean. For collections (one-to-many), IN-clause batch fetching is often better than a JOIN because a JOIN for a one-to-many produces duplicate parent rows that Hibernate must de-duplicate; setting `@BatchSize(size = 100)` on the collection makes Hibernate load all collections for up to 100 parents in a single `WHERE id IN (...)` query instead of 100 separate queries. I detect N+1 problems in development using the `hibernate.show_sql` property or a tool like p6spy that logs every SQL statement.

---

**Q12: Why is string concatenation in SQL queries a security vulnerability?**
*Concept Check*

**One-line answer:** Concatenating user input directly into SQL allows an attacker to inject arbitrary SQL commands; always use parameterized queries or prepared statements where the driver sends parameters separately from the SQL text.

**Full answer:**
SQL injection is one of the most severe and prevalent web security vulnerabilities. If I build a query like `"SELECT * FROM users WHERE email = '" + userInput + "'"` and the attacker submits `userInput = "' OR '1'='1"`, the resulting query becomes `SELECT * FROM users WHERE email = '' OR '1'='1'`, which returns all users in the table because `'1'='1'` is always true. With a more targeted input, an attacker can delete tables (`'; DROP TABLE users; --`), extract all data, or bypass authentication entirely. Parameterized queries (also called prepared statements) prevent this by sending the SQL structure and the parameter values separately to the database: `PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE email = ?"); ps.setString(1, userInput)`. The database driver quotes and escapes the parameter value before substituting it into the query, so even if the value contains single quotes or SQL keywords, they are treated as data, never as SQL syntax. Using an ORM like Hibernate or Spring Data JPA uses parameterized queries automatically for standard repository methods, but raw JPQL or native queries with string concatenation are still vulnerable — I must use named parameters (`:email`) or positional parameters (`?1`) even in JPQL.

---

**Q13: Why is LOCK TABLE harmful and what is the alternative?**
*Concept Check*

**One-line answer:** LOCK TABLE acquires an exclusive lock on the entire table, serializing all concurrent reads and writes; row-level locking with SELECT FOR UPDATE is almost always the correct granularity.

**Full answer:**
`LOCK TABLE orders IN EXCLUSIVE MODE` prevents any other transaction from reading or writing to the orders table until the lock is released — in a high-traffic application, this creates a queue of waiting connections, exhausts the connection pool, and causes a cascading timeout failure for all concurrent requests. Table locks are a blunt instrument left over from the early days of databases; modern relational databases support row-level locking, which only locks the specific rows being modified rather than the entire table. The correct approach for most use cases is `SELECT FOR UPDATE`, which locks only the rows returned by the SELECT: `SELECT * FROM inventory WHERE product_id = 42 FOR UPDATE`. Any concurrent transaction that tries to read or modify product 42 with `FOR UPDATE` will wait, but transactions working with product 43 proceed unimpeded. For optimistic locking — where I want to detect conflicts rather than serialize — I use a version column: `WHERE id = 42 AND version = 5`, and if the row has been updated by another transaction since I read it, the UPDATE affects zero rows, which I detect and handle by retrying the operation. Table locks are occasionally appropriate for bulk maintenance operations that must run without any concurrent access, but never for transactional application logic.

---

**Q14: Why must multi-step operations always be wrapped in a transaction?**
*Concept Check*

**One-line answer:** Without a transaction, a failure between two related statements leaves the database in a partially updated, inconsistent state that violates business rules and cannot be automatically reversed.

**Full answer:**
The Atomicity property of ACID guarantees that a transaction is all-or-nothing: either all statements in the transaction commit, or none of them do. Without an explicit transaction, if I execute `UPDATE accounts SET balance = balance - 100 WHERE id = 1` (debit) and then `UPDATE accounts SET balance = balance + 100 WHERE id = 2` (credit) as two separate auto-committed statements, and the application crashes, the database server is restarted, or a network error occurs between the two statements, the debit commits but the credit never runs — $100 has vanished. Wrapping both statements in a `BEGIN`/`COMMIT` block (or using Spring's `@Transactional`) means both succeed or both are rolled back: if the second statement fails for any reason, the first is automatically undone by the database. Beyond crashes, transactions also provide isolation: without a transaction, another concurrent request could read the account balance between my debit and my credit, seeing an inconsistent intermediate state where $100 is missing from account 1 but hasn't appeared in account 2 yet. The fix is universal: any operation that modifies more than one row or more than one table to maintain a consistent state must be wrapped in an explicit transaction.

---

**Q15: What is cascade delete without a foreign key index, and why is it slow?**
*Concept Check*

**One-line answer:** When deleting a parent row, the database must verify that no orphaned child rows exist; without an index on the child's foreign key column, this check requires a full sequential scan of the child table.

**Full answer:**
A foreign key constraint with ON DELETE CASCADE means that deleting a parent row automatically deletes all child rows that reference it — for example, deleting a user also deletes all their orders. To perform this cascading delete, PostgreSQL must find all rows in the orders table where `user_id = 42`, delete them, then delete the user. Without an index on `orders.user_id`, finding those rows requires a sequential scan of the entire orders table — every row is examined to check if `user_id = 42`. For a large orders table with millions of rows, this sequential scan is slow and locks the orders table for a long time, blocking other transactions. PostgreSQL also performs this scan for non-cascading foreign keys (with ON DELETE RESTRICT or the default behavior) to check that no child rows reference the parent before allowing the delete — so the scan cost exists regardless of whether CASCADE is used. The fix is `CREATE INDEX ON orders (user_id)`, which allows the index to efficiently locate just the rows for `user_id = 42` in logarithmic time. This is the most commonly missed index in PostgreSQL schemas because the database creates an index on the primary key automatically but not on columns that reference other tables' primary keys.

---

**Q16: What is LazyInitializationException and how do you prevent it?**
*Concept Check*

**One-line answer:** LazyInitializationException occurs in Hibernate when you access a lazily loaded association outside of an active transaction (and thus outside an open persistence context); fix it by loading the data within the transaction or using JOIN FETCH.

**Full answer:**
In Hibernate/JPA, associations like `@OneToMany` collections are loaded lazily by default — the collection is not fetched from the database until the first access. While this avoids unnecessary data loading, it creates a trap: the lazy load can only succeed while the Hibernate persistence context (session) is open, which in Spring is typically the duration of the `@Transactional` method. If a service method without `@Transactional` returns an entity and the caller (a controller, a test, or another service method) tries to access a lazy collection on that entity, the persistence context has already closed, and Hibernate throws `LazyInitializationException: could not initialize proxy - no Session`. The most robust fix is to load the required associations eagerly within the transaction boundary using JOIN FETCH or `@EntityGraph`, so the data is already in memory when the persistence context closes. Alternatively, I can use the OSIV (Open Session In View) pattern — a Spring filter that keeps the persistence context open for the entire HTTP request — but this is generally discouraged for new code because it hides lazy loading costs in the view layer and can produce unexpected extra queries. Using DTOs (Data Transfer Objects) instead of passing raw entities across transaction boundaries avoids the problem entirely because DTOs are plain objects with no proxies.

---

**Q17: What is the difference between MySQL's DATETIME and TIMESTAMP types?**
*Concept Check*

**One-line answer:** DATETIME stores the literal date and time as entered with no timezone conversion; TIMESTAMP converts to UTC on write and back to the session timezone on read — always use TIMESTAMP for audit and event fields.

**Full answer:**
In MySQL, DATETIME stores a date and time value exactly as provided — `2024-07-15 14:30:00` is stored and returned as-is, regardless of what timezone the client or server is in. This means if I store a timestamp in a DATETIME column from a server in New York (UTC-5) and read it from a server in London (UTC+0), I get back the same literal string `2024-07-15 14:30:00` with no indication of which timezone it represents — ambiguous and prone to errors in globally distributed systems. TIMESTAMP, by contrast, converts the input value to UTC at write time using the session's timezone, stores UTC internally, and converts back to the session's current timezone at read time. This means a value stored from New York and read in London will be correctly offset by 5 hours, reflecting the same instant in time. For application fields like `created_at`, `updated_at`, and any event timestamps, TIMESTAMP is almost always correct because these represent instants in time, not calendar values. The practical caveats are that TIMESTAMP has a range of 1970–2038 (the year-2038 problem for 32-bit Unix timestamps), while DATETIME supports 1000–9999; for dates beyond 2038, use DATETIME with explicit UTC application-side handling, or use PostgreSQL's `TIMESTAMP WITH TIME ZONE` (TIMESTAMPTZ), which stores UTC internally without the 2038 limitation.

---

**Q18: Why is COUNT(DISTINCT col) slow on large tables and what is the alternative?**
*Concept Check*

**One-line answer:** COUNT(DISTINCT col) must process and de-duplicate every value in the column even if an index exists; for large-scale cardinality estimation where approximate results are acceptable, HyperLogLog (HLL) gives results in milliseconds.

**Full answer:**
`COUNT(DISTINCT user_id)` computes the exact number of unique user IDs in the table. To do this, the database must scan every row (or every entry in an index on user_id), collect all values into a hash set, and count the distinct entries — this is O(N) work and requires O(N) memory proportional to the number of distinct values. For a column with 100 million rows, even with an index scan, this can take minutes. A covering index on the counted column helps by avoiding heap access, but the fundamental O(N) scan cost remains. When I need cardinality estimation — "approximately how many distinct users visited this week?" — rather than an exact count, HyperLogLog (HLL) is the right tool. HLL is a probabilistic data structure that can estimate the cardinality of a set to within about 2% error using only a few kilobytes of memory, regardless of the number of distinct values. PostgreSQL has the `hll` extension; systems like BigQuery, ClickHouse, and Redis natively support HLL via `APPROX_COUNT_DISTINCT` or `PFCOUNT`. For analytics dashboards and reporting where slight imprecision is acceptable, HLL gives answers in milliseconds that would take minutes with exact COUNT(DISTINCT). For use cases requiring an exact count, I maintain a materialized count that is updated incrementally rather than recomputed from scratch.

---

**Q19: How do you prevent deadlocks in database transactions?**
*Concept Check*

**One-line answer:** Deadlocks occur when two transactions wait for each other's locks; the primary prevention is to always acquire multiple locks in the same global order (e.g., ascending primary key) across all transactions.

**Full answer:**
A deadlock is a circular wait: Transaction 1 holds a lock on Row A and is waiting for a lock on Row B; Transaction 2 holds a lock on Row B and is waiting for a lock on Row A — neither can proceed, and the database must detect and break the deadlock by rolling back one transaction. The most reliable prevention strategy is to enforce a consistent global lock acquisition order: if every transaction that needs to lock multiple rows always acquires them in ascending primary key order, circular waits are impossible because no transaction will request a lock on a lower-ID row that another transaction already holds while waiting for a higher-ID row. For example, a money transfer between accounts should always lock `MIN(account_id_A, account_id_B)` first, then the other — never the destination before the source. Beyond ordering, keeping transactions short reduces the window during which locks are held, which reduces the chance of overlap with concurrent transactions. For operations that are idempotent, catching the deadlock exception and retrying the transaction is a valid strategy because the retry will succeed once the other transaction commits and releases its locks. I detect deadlock patterns in PostgreSQL by querying `pg_locks` joined to `pg_stat_activity`, and I configure `deadlock_timeout` (default 1 second) to control how long PostgreSQL waits before checking for deadlocks, since the check itself has overhead.

---

**Q20: What is PostgreSQL table bloat and how do you manage it?**
*Concept Check*

**One-line answer:** PostgreSQL's MVCC mechanism leaves dead row versions in place after updates and deletes; without regular VACUUM, these accumulate as table bloat, wasting disk space and slowing queries that must scan past dead rows.

**Full answer:**
PostgreSQL implements MVCC (Multi-Version Concurrency Control) by never overwriting a row in place — instead, an UPDATE inserts a new version of the row and marks the old version as deleted, and a DELETE just marks the row as deleted without physically removing it. This approach allows readers to see a consistent snapshot of the table without taking locks, but it means the table file on disk accumulates dead row versions that are no longer visible to any transaction. `VACUUM` is the process that reclaims this space by marking dead row versions as reusable for future inserts; `VACUUM FULL` actually rewrites the entire table to reclaim disk space but requires an exclusive lock. The autovacuum daemon runs VACUUM automatically based on thresholds, but if autovacuum is tuned too conservatively for high-churn tables — or if a long-running transaction prevents dead rows from being reclaimed — bloat can grow significantly. I monitor bloat by querying `pg_stat_user_tables`: the `n_dead_tup` column shows the number of dead tuples, and a high ratio of `n_dead_tup / n_live_tup` indicates bloat. A bloated table causes slower queries because sequential scans read through dead rows, and index scans must follow more pointers to the heap to discover that rows are dead (dead row versions are called row visibility problems in the buffer cache). For high-update tables, I tune `autovacuum_vacuum_scale_factor` to a lower value so autovacuum triggers more frequently, preventing bloat from accumulating.

---

**Common Mistakes:**
- **Using NOT IN on a nullable column** → returns zero rows silently; always use NOT EXISTS for nullable foreign key subqueries
- **Writing WHERE YEAR(col) = 2024 on an indexed column** → disables index; rewrite as a range predicate on the raw column
- **Leaving JDBC auto-commit enabled for multi-statement operations** → partial failures leave data inconsistent; use @Transactional or explicit commit/rollback
- **Forgetting to CREATE INDEX on foreign key columns in PostgreSQL** → all JOIN and cascade delete operations scan the full child table; index every FK column explicitly
- **Using DATETIME for audit timestamps in MySQL** → timezone information lost; use TIMESTAMP for instants in time, DATETIME only for "wall calendar" values like birth dates
- **Ignoring n_dead_tup in pg_stat_user_tables** → silent table bloat degrades query performance over time; monitor and tune autovacuum for high-churn tables

**Quick Revision:** Every trap comes down to one of three root causes — type mismatches that break indexes, missing transactions that break atomicity, or missing indexes that force full scans.

