# Volume 4: Databases & Performance
# Chapter 14: SQL Deep Dive

---

# Chapter 14: SQL for Backend Engineers — Part A

> **Volume 4: Databases** | Target: SDE2+ | Companies: FAANG, FinTech, Stripe, Uber, Airbnb, Goldman Sachs, Morgan Stanley
>
> This chapter covers the SQL concepts most frequently tested in backend engineering interviews. PostgreSQL syntax is used throughout; Spring Data JPA equivalents are shown where applicable.

---

## Table of Contents

1. [SQL Joins](#topic-1-sql-joins)
2. [Subqueries & CTEs](#topic-2-subqueries--ctes)
3. [Window Functions](#topic-3-window-functions)
4. [GROUP BY & HAVING](#topic-4-group-by--having)
5. [SQL Execution Order](#topic-5-sql-execution-order)
6. [UNION vs UNION ALL vs INTERSECT vs EXCEPT](#topic-6-union-vs-union-all-vs-intersect-vs-except)
7. [NULL Handling](#topic-7-null-handling)
8. [String & Date Functions](#topic-8-string--date-functions)

---

### Topic 1: SQL Joins

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Google, Amazon, Meta, Stripe, Uber, Goldman Sachs

**Q:** Explain the different types of SQL joins — INNER, LEFT, RIGHT, FULL OUTER, CROSS, and SELF. How does NULL handling differ in outer joins vs inner joins?

**Short Answer:**
A JOIN combines rows from two or more tables based on a related column. INNER JOIN returns only matching rows; outer joins (LEFT, RIGHT, FULL) preserve unmatched rows from one or both sides, filling unmatched columns with NULL. The join type chosen directly affects which rows appear in the result set and is a frequent source of subtle bugs.

**Deep Explanation:**

**INNER JOIN**
Returns only rows where the join condition is satisfied in *both* tables. Rows with no match are silently discarded. This is the default join and the most common in practice.

**LEFT (OUTER) JOIN**
Returns all rows from the *left* table. For rows in the left table that have no match in the right table, the right-table columns are filled with NULL. The keyword OUTER is optional.

**RIGHT (OUTER) JOIN**
Mirror image of LEFT JOIN — all rows from the right table are preserved; unmatched left-table columns become NULL. In practice, RIGHT JOIN is rarely used; you can always rewrite it as a LEFT JOIN by swapping the tables.

**FULL OUTER JOIN**
Returns all rows from both tables. Where there is no match on either side, NULLs fill the missing columns. Useful for finding rows in either table that have no counterpart in the other.

**CROSS JOIN**
Returns the Cartesian product — every row from the left table paired with every row from the right table. Result size = |left| × |right|. No ON clause. Use carefully on large tables; it is legitimate for generating combinations (e.g., calendar × product grids).

**SELF JOIN**
A table joined to itself, always using aliases. Used to compare rows within the same table — classic examples include employee-manager hierarchies and finding duplicate records.

**NULL Handling in Outer Joins**
NULLs introduced by outer joins can silently affect downstream filters. A WHERE clause applied after an outer join effectively converts it to an inner join for any condition that rejects NULLs. To truly filter only the right side while keeping left-side NULLs, put the filter in the ON clause instead of WHERE.

**Execution Semantics**
The optimizer decides whether to use nested loops, hash joins, or merge joins. INNER JOINs give the optimizer more freedom to reorder tables. Outer joins are directionally constrained — the preserved side must be processed first in certain algorithms.

**Real-World Example:**
An e-commerce platform needs a report of all customers with their total orders. Some customers have never ordered. An INNER JOIN would silently omit those customers; a LEFT JOIN preserves them with NULL order counts, which can then be converted to 0 via COALESCE.

**Code Example:**
```sql
-- Schema
-- customers(id, name, email, created_at)
-- orders(id, customer_id, total_amount, status, created_at)
-- order_items(id, order_id, product_id, quantity, unit_price)
-- products(id, name, category, price)

-- INNER JOIN: only customers who have placed at least one order
SELECT c.id, c.name, COUNT(o.id) AS order_count
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.name;

-- LEFT JOIN: all customers, zero-count for those with no orders
SELECT
    c.id,
    c.name,
    COALESCE(COUNT(o.id), 0) AS order_count,       -- NULL -> 0
    COALESCE(SUM(o.total_amount), 0.00) AS lifetime_value
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.name;

-- FULL OUTER JOIN: find orphaned orders AND customers with no orders
SELECT
    c.id   AS customer_id,
    c.name AS customer_name,
    o.id   AS order_id,
    o.total_amount
FROM customers c
FULL OUTER JOIN orders o ON c.id = o.customer_id
WHERE c.id IS NULL OR o.id IS NULL;   -- only the unmatched rows

-- CROSS JOIN: price simulation across all products and discount tiers
SELECT
    p.name           AS product,
    d.discount_pct,
    p.price * (1 - d.discount_pct / 100.0) AS discounted_price
FROM products p
CROSS JOIN (VALUES (5), (10), (15), (20)) AS d(discount_pct);

-- SELF JOIN: employee-manager hierarchy
SELECT
    e.id       AS employee_id,
    e.name     AS employee_name,
    m.name     AS manager_name
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;    -- LEFT so CEO (no manager) is included

-- Anti-join pattern: customers who have NEVER ordered
SELECT c.id, c.name
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.id IS NULL;

-- TRAP: filter in ON vs WHERE makes a huge difference
-- This is an outer join in name only — WHERE kills the NULLs:
SELECT c.name, o.total_amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.status = 'COMPLETED';   -- ← customers with no orders are silently dropped

-- Correct way: filter in ON clause to preserve left-side rows
SELECT c.name, o.total_amount
FROM customers c
LEFT JOIN orders o
    ON c.id = o.customer_id
    AND o.status = 'COMPLETED';  -- ← customers with no completed orders still appear (NULL)
```

```java
// Spring Data JPA equivalent — JPQL LEFT JOIN FETCH
@Query("""
    SELECT c FROM Customer c
    LEFT JOIN FETCH c.orders o
    WHERE c.createdAt > :since
    """)
List<Customer> findCustomersWithOrders(@Param("since") LocalDate since);

// Native query for complex joins
@Query(value = """
    SELECT c.id, c.name, COALESCE(SUM(o.total_amount), 0) AS lifetime_value
    FROM customers c
    LEFT JOIN orders o ON c.id = o.customer_id
    GROUP BY c.id, c.name
    """, nativeQuery = true)
List<Object[]> findCustomerLifetimeValues();
```

**Follow-up Questions:**
1. How does moving a filter from WHERE to ON change the result of a LEFT JOIN? Give an example.
2. What is an anti-join, and how do you implement it without using NOT IN (which has NULL hazards)?
3. When would you choose a HASH JOIN vs MERGE JOIN vs NESTED LOOP JOIN at the execution plan level?

**Common Mistakes:**
- Using INNER JOIN when the business requirement says "all X even if no Y" — leads to silent data loss in reports.
- Filtering on a right-table column in WHERE after a LEFT JOIN, which silently converts it to an INNER JOIN.
- Forgetting that CROSS JOIN on two 1M-row tables generates 1 trillion rows.

**Interview Traps:**
- "What does `SELECT * FROM a, b WHERE a.id = b.a_id` do?" — It is an implicit INNER JOIN (comma syntax). Interviewers test whether you know the old ANSI-89 vs ANSI-92 syntax distinction.
- "Can NULL = NULL ever return true?" — No, because NULL compared to anything (including itself) is UNKNOWN, not TRUE. This means `ON a.id = b.id` silently drops rows where either ID is NULL.

**Quick Revision:** LEFT JOIN preserves all left-table rows (NULLs on right for no match); filter in ON vs WHERE is the #1 trap.

---

### Topic 2: Subqueries & CTEs

**Difficulty:** Medium-Hard | **Frequency:** High | **Companies:** Amazon, Stripe, Airbnb, JPMorgan, Goldman Sachs

**Q:** What is the difference between a correlated and non-correlated subquery? When should you use a CTE instead of a subquery? What are recursive CTEs?

**Short Answer:**
A non-correlated subquery executes once and its result is reused; a correlated subquery references the outer query and re-executes for each row of the outer query, making it potentially O(n) times slower. CTEs (WITH clauses) improve readability and allow recursion, and in PostgreSQL they act as an optimization fence in older versions (pre-12), meaning the planner cannot push predicates into them.

**Deep Explanation:**

**Non-Correlated Subquery**
Executes independently of the outer query. The database runs it once, caches the result, and uses it in the outer query. Can appear in SELECT (scalar subquery), FROM (derived table / inline view), or WHERE (IN / EXISTS / comparison).

**Correlated Subquery**
References one or more columns from the outer query. It re-executes for each row processed by the outer query. While powerful, this O(n) behaviour is usually replaceable with a JOIN or window function for better performance.

**EXISTS vs IN**
- `IN (subquery)`: materializes the full subquery result. If the subquery can return NULLs, `NOT IN` is a common trap — a single NULL in the subquery result makes the entire NOT IN return nothing.
- `EXISTS (subquery)`: short-circuits on the first matching row. Preferred for correlated existence checks because it is often faster and is NULL-safe.

**CTEs — Common Table Expressions**
Defined with the WITH clause before the main query. Benefits:
1. Readability — give a name to a complex derived table
2. Reusability within the same query — reference multiple times
3. Recursion — not possible with plain subqueries

**PostgreSQL CTE Optimization Fence (important)**
In PostgreSQL < 12, a non-recursive CTE was always materialized (evaluated once, stored). This prevented predicate pushdown but guaranteed no repeated evaluation. From PostgreSQL 12+, the planner can inline non-recursive, non-volatile CTEs. Use `WITH ... AS MATERIALIZED (...)` or `AS NOT MATERIALIZED (...)` to control this explicitly.

**Recursive CTEs**
A recursive CTE has two parts joined by UNION ALL:
1. The *anchor* (base case) — a non-recursive query
2. The *recursive member* — references the CTE itself

The engine repeatedly executes the recursive member, appending results, until no new rows are produced. Use for tree traversal (org charts, category hierarchies), graph traversal, and sequence generation. Always include a termination condition (depth limit or cycle detection) to prevent infinite loops.

**Real-World Example:**
A FinTech platform has an `accounts` table with a `parent_account_id` column for sub-accounts. To roll up balances from all descendants of a given account, a recursive CTE traverses the hierarchy from root to leaves.

**Code Example:**
```sql
-- Non-correlated subquery: orders above average value
SELECT id, customer_id, total_amount
FROM orders
WHERE total_amount > (
    SELECT AVG(total_amount) FROM orders   -- executes ONCE
);

-- Correlated subquery: for each customer, get their latest order date
-- AVOID for large tables — runs once per customer row
SELECT
    c.id,
    c.name,
    (SELECT MAX(o.created_at)
     FROM orders o
     WHERE o.customer_id = c.id) AS last_order_date  -- correlated: references c.id
FROM customers c;

-- Better: rewrite correlated subquery as a JOIN + aggregation
SELECT c.id, c.name, MAX(o.created_at) AS last_order_date
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.name;

-- EXISTS (preferred for existence checks, NULL-safe)
SELECT c.id, c.name
FROM customers c
WHERE EXISTS (
    SELECT 1                          -- SELECT 1, not SELECT *, for clarity
    FROM orders o
    WHERE o.customer_id = c.id
      AND o.status = 'COMPLETED'
);

-- NOT IN trap with NULLs — DANGEROUS
-- If ANY order has a NULL customer_id, this returns 0 rows
SELECT id FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders);   -- ← bug if NULLs exist

-- Safe alternative using NOT EXISTS
SELECT c.id FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.id
);

-- CTE: multi-step analytics pipeline (readable, composable)
WITH
    monthly_revenue AS (
        SELECT
            DATE_TRUNC('month', created_at) AS month,
            SUM(total_amount)               AS revenue
        FROM orders
        WHERE status = 'COMPLETED'
        GROUP BY 1
    ),
    revenue_with_growth AS (
        SELECT
            month,
            revenue,
            LAG(revenue) OVER (ORDER BY month) AS prev_revenue
        FROM monthly_revenue
    )
SELECT
    month,
    revenue,
    prev_revenue,
    ROUND(100.0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0), 2) AS growth_pct
FROM revenue_with_growth
ORDER BY month;

-- Recursive CTE: traverse account hierarchy to sum balances
WITH RECURSIVE account_tree AS (
    -- Anchor: start from root account
    SELECT id, name, parent_account_id, balance, 1 AS depth
    FROM accounts
    WHERE id = 42   -- root account ID

    UNION ALL

    -- Recursive member: find children of current level
    SELECT a.id, a.name, a.parent_account_id, a.balance, at.depth + 1
    FROM accounts a
    INNER JOIN account_tree at ON a.parent_account_id = at.id
    WHERE at.depth < 10   -- cycle/depth guard
)
SELECT
    id,
    name,
    depth,
    SUM(balance) OVER ()   AS total_rollup_balance
FROM account_tree
ORDER BY depth, id;

-- Recursive CTE: generate a date series (useful for filling gaps)
WITH RECURSIVE date_series AS (
    SELECT '2024-01-01'::date AS d
    UNION ALL
    SELECT d + INTERVAL '1 day'
    FROM date_series
    WHERE d < '2024-01-31'
)
SELECT d AS calendar_date
FROM date_series;
```

```java
// Spring Data JPA — CTE via native query
@Query(value = """
    WITH monthly_revenue AS (
        SELECT DATE_TRUNC('month', created_at) AS month,
               SUM(total_amount) AS revenue
        FROM orders WHERE status = 'COMPLETED'
        GROUP BY 1
    )
    SELECT month, revenue FROM monthly_revenue ORDER BY month
    """, nativeQuery = true)
List<Object[]> getMonthlyRevenue();
```

**Follow-up Questions:**
1. What happens with `NOT IN` when the subquery contains a NULL value? How do you fix it?
2. How does PostgreSQL 12's CTE inlining change query planning compared to earlier versions?
3. What is the termination condition for a recursive CTE, and how do you detect and prevent cycles?

**Common Mistakes:**
- Using a correlated subquery in SELECT for every row instead of a single JOIN + aggregation — O(n) vs O(1) query plans.
- Using `NOT IN` with a subquery that can return NULLs (the entire NOT IN returns empty due to three-valued logic).
- Writing unbounded recursive CTEs with no depth guard, causing infinite loops on cyclic graphs.

**Interview Traps:**
- "Is a CTE always faster than a subquery?" — No. Pre-PostgreSQL 12, CTEs are optimization fences and can be *slower* because predicates cannot be pushed into them. The answer depends on version, volatility, and whether inlining helps.
- "What is the difference between a derived table and a CTE?" — A derived table is an inline subquery in FROM; it cannot be referenced more than once. A CTE is named, can be referenced multiple times, and can be recursive.

**Quick Revision:** Correlated subquery = runs per outer row (slow); NOT IN + NULLs = silent empty result; recursive CTE = anchor UNION ALL recursive member + depth guard.

---

### Topic 3: Window Functions

**Difficulty:** Hard | **Frequency:** Very High | **Companies:** Google, Meta, Stripe, Uber, Airbnb, Two Sigma, Jane Street

**Q:** Explain window functions in SQL. How do ROW_NUMBER, RANK, and DENSE_RANK differ? What is the frame clause and when does it matter?

**Short Answer:**
Window functions perform calculations across a set of rows related to the current row (the "window") without collapsing those rows into a single output row — unlike GROUP BY. Each row retains its identity while gaining access to aggregated or positional values from the window. They are indispensable for rankings, running totals, moving averages, and inter-row comparisons.

**Deep Explanation:**

**Anatomy of a Window Function**
```
function_name(args) OVER (
    [PARTITION BY expr, ...]
    [ORDER BY expr [ASC|DESC], ...]
    [frame_clause]
)
```

- **PARTITION BY**: Divides rows into independent groups. The window function restarts for each partition. Optional — omitting it means the entire result set is one partition.
- **ORDER BY**: Defines the logical order within each partition. Required for ranking and offset functions; optional for pure aggregates.
- **Frame clause**: Defines which rows within the ordered partition are included in the calculation relative to the current row.

**Ranking Functions**

| Function | Behaviour on Ties | Gaps in Sequence |
|---|---|---|
| ROW_NUMBER() | Assigns arbitrary unique number | No gaps |
| RANK() | Same rank for ties | Gaps after tied group |
| DENSE_RANK() | Same rank for ties | No gaps |

Example: scores 100, 100, 90
- ROW_NUMBER: 1, 2, 3
- RANK: 1, 1, 3
- DENSE_RANK: 1, 1, 2

**Offset Functions**
- `LAG(expr, offset, default)`: Value from `offset` rows *before* current row in partition.
- `LEAD(expr, offset, default)`: Value from `offset` rows *after* current row.
- `FIRST_VALUE(expr)`: First value in the window frame.
- `LAST_VALUE(expr)`: Last value in the window frame — often needs explicit frame clause to work as expected.
- `NTH_VALUE(expr, n)`: nth value in the frame.

**Frame Clause**
Defines a sliding subset of rows around the current row. Two modes:
- `ROWS`: Physical row offsets
- `RANGE`: Logical value-based offsets (useful for time series)

Common presets:
- `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` — running total (default for most aggregates with ORDER BY)
- `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` — 3-row moving average
- `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` — full partition (default without ORDER BY)

**LAST_VALUE Trap**
By default, `LAST_VALUE` uses frame `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`, so it returns the *current row's* value, not the partition's last. Fix: `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.

**NTILE(n)**
Distributes rows into `n` ranked buckets as evenly as possible. Useful for percentile groupings.

**Performance Note**
Window functions run after WHERE and GROUP BY but before the outer SELECT's DISTINCT and ORDER BY. They cannot be referenced directly in WHERE — wrap in a subquery or CTE.

**Real-World Example:**
A trading platform needs to identify the top 3 traders by daily P&L within each trading desk, along with each trader's P&L relative to the previous trading day. This requires DENSE_RANK (for top-N without gaps) and LAG (for day-over-day delta) over a PARTITION BY desk, ORDER BY date window.

**Code Example:**
```sql
-- Sample schema: trade_results(trader_id, desk, trade_date, pnl)

-- ROW_NUMBER vs RANK vs DENSE_RANK on tied P&L values
SELECT
    trader_id,
    desk,
    pnl,
    ROW_NUMBER()  OVER (PARTITION BY desk ORDER BY pnl DESC) AS row_num,   -- unique, arbitrary tiebreak
    RANK()        OVER (PARTITION BY desk ORDER BY pnl DESC) AS rank,      -- gaps after ties
    DENSE_RANK()  OVER (PARTITION BY desk ORDER BY pnl DESC) AS dense_rank -- no gaps
FROM trade_results
WHERE trade_date = CURRENT_DATE;

-- Top 3 traders per desk (no duplicates with ties)
WITH ranked AS (
    SELECT *,
        DENSE_RANK() OVER (PARTITION BY desk ORDER BY pnl DESC) AS dr
    FROM trade_results
    WHERE trade_date = CURRENT_DATE
)
SELECT trader_id, desk, pnl, dr
FROM ranked
WHERE dr <= 3;

-- LAG and LEAD: day-over-day P&L change
SELECT
    trader_id,
    trade_date,
    pnl,
    LAG(pnl, 1, 0) OVER (PARTITION BY trader_id ORDER BY trade_date)     AS prev_day_pnl,
    LEAD(pnl, 1)   OVER (PARTITION BY trader_id ORDER BY trade_date)     AS next_day_pnl,
    pnl - LAG(pnl, 1, 0) OVER (PARTITION BY trader_id ORDER BY trade_date) AS daily_delta
FROM trade_results;

-- FIRST_VALUE and LAST_VALUE (with correct frame for LAST_VALUE)
SELECT
    trader_id,
    trade_date,
    pnl,
    FIRST_VALUE(pnl) OVER w                                          AS first_pnl_in_month,
    LAST_VALUE(pnl)  OVER (                                          -- explicit full-partition frame
        PARTITION BY trader_id, DATE_TRUNC('month', trade_date)
        ORDER BY trade_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING     -- ← required!
    )                                                                AS last_pnl_in_month
FROM trade_results
WINDOW w AS (
    PARTITION BY trader_id, DATE_TRUNC('month', trade_date)
    ORDER BY trade_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
);

-- Frame clause: 7-day moving average P&L
SELECT
    trader_id,
    trade_date,
    pnl,
    AVG(pnl) OVER (
        PARTITION BY trader_id
        ORDER BY trade_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW   -- current + 6 prior = 7 rows
    ) AS moving_avg_7d,
    SUM(pnl) OVER (
        PARTITION BY trader_id
        ORDER BY trade_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW   -- running total
    ) AS cumulative_pnl
FROM trade_results;

-- NTILE: split customers into quartiles by lifetime spend
SELECT
    customer_id,
    lifetime_value,
    NTILE(4) OVER (ORDER BY lifetime_value DESC) AS quartile,
    PERCENT_RANK() OVER (ORDER BY lifetime_value DESC) AS pct_rank
FROM customer_summary;

-- CANNOT reference window function in WHERE — use CTE
-- BAD:
-- SELECT * FROM orders WHERE ROW_NUMBER() OVER (...) = 1;  -- error!

-- GOOD:
WITH numbered AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC) AS rn
    FROM orders
)
SELECT * FROM numbered WHERE rn = 1;   -- most recent order per customer
```

```java
// Spring Data JPA — window functions via native query
@Query(value = """
    WITH ranked_orders AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC) AS rn
        FROM orders
    )
    SELECT * FROM ranked_orders WHERE rn = 1
    """, nativeQuery = true)
List<Order> findMostRecentOrderPerCustomer();
```

**Follow-up Questions:**
1. Why does `LAST_VALUE` often return unexpected results, and how do you fix it?
2. Can you use a window function in a WHERE clause? If not, what is the workaround?
3. What is the difference between `ROWS` and `RANGE` in the frame clause? Give a concrete example where they produce different results.

**Common Mistakes:**
- Using `LAST_VALUE` without specifying `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` — returns the current row value, not the partition's last.
- Trying to filter on a window function result in WHERE directly — you must wrap it in a subquery or CTE.
- Confusing `RANK` and `DENSE_RANK` — if the interviewer asks for "top N per group," using RANK can miss tied rows or include extras depending on the exact requirement.

**Interview Traps:**
- "What is the default frame for SUM with ORDER BY?" — `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`, which is range-based, not rows-based. This matters when there are ties in ORDER BY.
- "How do you get a running total that resets each month?" — Add `PARTITION BY DATE_TRUNC('month', date_column)` before `ORDER BY`.

**Quick Revision:** Window functions compute over a window without collapsing rows; RANK has gaps, DENSE_RANK does not; LAST_VALUE needs explicit full-partition frame; cannot filter on window function in WHERE.

---

### Topic 4: GROUP BY & HAVING

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Amazon, Google, Meta, Stripe, all FinTech

**Q:** What is the difference between WHERE and HAVING? What are GROUPING SETS, ROLLUP, and CUBE?

**Short Answer:**
WHERE filters individual rows *before* grouping; HAVING filters groups *after* aggregation, so it can reference aggregate functions like SUM() and COUNT(). GROUPING SETS, ROLLUP, and CUBE are SQL extensions that generate multiple levels of aggregation in a single query, avoiding repetitive UNION ALL statements.

**Deep Explanation:**

**WHERE vs HAVING**
- `WHERE` is applied at the row level before any grouping or aggregation occurs. You cannot reference aggregate functions here.
- `HAVING` is applied after GROUP BY and aggregation. You can reference both aggregate functions and grouped columns.
- Performance: push filters into WHERE whenever possible — it reduces the number of rows that go into the aggregation step.

**GROUP BY Rules (Standard SQL)**
Every column in SELECT that is not inside an aggregate function must appear in GROUP BY. PostgreSQL enforces this strictly. Exception: if the primary key is in GROUP BY, all non-key columns of that table can be included without being in GROUP BY (functional dependency rule, PostgreSQL 9.1+).

**Aggregate Functions**
- `COUNT(*)` counts all rows; `COUNT(col)` ignores NULLs.
- `SUM`, `AVG`, `MIN`, `MAX` all ignore NULL values.
- `COUNT(DISTINCT col)` counts unique non-NULL values.

**FILTER clause (PostgreSQL)**
A more readable alternative to CASE WHEN inside aggregates:
```sql
COUNT(*) FILTER (WHERE status = 'COMPLETED')
```
Equivalent to `COUNT(CASE WHEN status = 'COMPLETED' THEN 1 END)`.

**GROUPING SETS**
Allows you to specify multiple independent groupings in one query. The database computes each grouping separately and UNION ALLs the results. An empty group `()` produces the grand total.

**ROLLUP**
Generates hierarchical subtotals. `ROLLUP(a, b, c)` produces groupings: `(a,b,c)`, `(a,b)`, `(a)`, `()`. Left-to-right hierarchy — useful for date dimensions (year → month → day).

**CUBE**
Generates *all* possible combinations of groupings. `CUBE(a, b)` produces: `(a,b)`, `(a)`, `(b)`, `()`. 2^n groupings for n dimensions. Useful for pivot-table-style multi-dimensional analysis.

**GROUPING() function**
Returns 1 if the column was aggregated (i.e., it is a NULL from the ROLLUP/CUBE, not a real NULL), 0 otherwise. Useful for distinguishing "this row is a subtotal" from "this row has a real NULL in that column."

**Real-World Example:**
A retail analytics dashboard needs a single query that shows: (1) sales by region and product category, (2) subtotals by region only, (3) subtotals by category only, and (4) a grand total. CUBE produces all four levels in one query, avoiding four separate queries joined with UNION ALL.

**Code Example:**
```sql
-- Basic GROUP BY + HAVING
SELECT
    customer_id,
    COUNT(*)           AS order_count,
    SUM(total_amount)  AS total_spend,
    AVG(total_amount)  AS avg_order_value
FROM orders
WHERE status = 'COMPLETED'           -- WHERE: filters rows BEFORE grouping
GROUP BY customer_id
HAVING SUM(total_amount) > 1000.00   -- HAVING: filters AFTER aggregation
ORDER BY total_spend DESC;

-- FILTER clause (PostgreSQL) — conditional aggregation
SELECT
    customer_id,
    COUNT(*)                                        AS total_orders,
    COUNT(*) FILTER (WHERE status = 'COMPLETED')   AS completed_orders,
    COUNT(*) FILTER (WHERE status = 'CANCELLED')   AS cancelled_orders,
    SUM(total_amount) FILTER (WHERE status = 'COMPLETED') AS completed_revenue
FROM orders
GROUP BY customer_id;

-- Equivalent without FILTER (works in MySQL too)
SELECT
    customer_id,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN status = 'COMPLETED' THEN 1 END) AS completed_orders,
    SUM(CASE WHEN status = 'COMPLETED' THEN total_amount ELSE 0 END) AS completed_revenue
FROM orders
GROUP BY customer_id;

-- GROUPING SETS: multiple independent aggregations in one query
SELECT
    region,
    category,
    SUM(sales_amount) AS total_sales
FROM sales
GROUP BY GROUPING SETS (
    (region, category),  -- sales by region AND category
    (region),            -- subtotals by region only
    (category),          -- subtotals by category only
    ()                   -- grand total (empty group)
);

-- ROLLUP: hierarchical aggregation (year > month > day)
SELECT
    EXTRACT(YEAR  FROM order_date) AS yr,
    EXTRACT(MONTH FROM order_date) AS mo,
    EXTRACT(DAY   FROM order_date) AS dy,
    SUM(total_amount)              AS daily_revenue
FROM orders
GROUP BY ROLLUP (
    EXTRACT(YEAR  FROM order_date),
    EXTRACT(MONTH FROM order_date),
    EXTRACT(DAY   FROM order_date)
)
ORDER BY yr NULLS LAST, mo NULLS LAST, dy NULLS LAST;
-- Result includes: per-day rows, per-month subtotals, per-year subtotals, grand total

-- CUBE: all combinations for multi-dimensional pivot
SELECT
    region,
    product_category,
    salesperson_id,
    SUM(amount) AS total,
    GROUPING(region)           AS is_region_subtotal,   -- 1 = this is a subtotal row
    GROUPING(product_category) AS is_category_subtotal,
    GROUPING(salesperson_id)   AS is_salesperson_subtotal
FROM sales
GROUP BY CUBE (region, product_category, salesperson_id);

-- Practical: find high-value customers with at least 5 orders in last 90 days
SELECT
    c.id,
    c.name,
    COUNT(o.id)           AS recent_orders,
    SUM(o.total_amount)   AS recent_spend
FROM customers c
JOIN orders o ON c.id = o.customer_id
WHERE o.created_at >= NOW() - INTERVAL '90 days'    -- pre-filter with WHERE
  AND o.status = 'COMPLETED'
GROUP BY c.id, c.name
HAVING COUNT(o.id) >= 5                             -- post-aggregate filter
   AND SUM(o.total_amount) > 500.00
ORDER BY recent_spend DESC
LIMIT 100;
```

**Follow-up Questions:**
1. Can you use a column alias defined in SELECT within a HAVING clause in PostgreSQL?
2. What is the difference between `COUNT(*)`, `COUNT(1)`, and `COUNT(column_name)`?
3. How would you generate a report with subtotals and a grand total without using ROLLUP?

**Common Mistakes:**
- Putting aggregate function conditions in WHERE instead of HAVING (syntax error or logic error).
- Using `COUNT(col)` when `COUNT(*)` is intended — `COUNT(col)` silently ignores NULLs.
- Over-using CUBE when only a few specific groupings are needed — CUBE generates 2^n groups and can be expensive.

**Interview Traps:**
- "Can you reference a SELECT alias in HAVING?" — In standard SQL and PostgreSQL, no (HAVING is evaluated before SELECT aliasing). Workaround: repeat the expression, or use a subquery/CTE.
- "What does GROUPING SETS generate for nulls vs ROLLUP?" — ROLLUP generates NULLs in a strict left-to-right hierarchy; GROUPING SETS generates NULLs only for the specified independent subsets, giving you more control.

**Quick Revision:** WHERE filters rows (before GROUP BY), HAVING filters groups (after aggregation); ROLLUP = hierarchical subtotals, CUBE = all combinations, GROUPING() distinguishes real NULLs from subtotal NULLs.

---

### Topic 5: SQL Execution Order

**Difficulty:** Medium | **Frequency:** High | **Companies:** Google, Meta, Amazon, Morgan Stanley, Citadel

**Q:** In what order does SQL logically execute the clauses of a SELECT statement? Why does this matter for writing correct queries?

**Short Answer:**
SQL clauses are logically evaluated in this order: FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT (including window functions) → DISTINCT → ORDER BY → LIMIT/OFFSET. This order determines which clauses can reference which aliases and aggregates, and it explains many common errors like "column alias not found in WHERE" or "aggregate not allowed in WHERE."

**Deep Explanation:**

**Full Logical Execution Order**

| Step | Clause | What Happens |
|------|--------|--------------|
| 1 | FROM | Identify all base tables |
| 2 | JOIN (ON) | Apply join conditions, produce intermediate rows |
| 3 | WHERE | Filter individual rows (no aggregates, no SELECT aliases) |
| 4 | GROUP BY | Collapse rows into groups |
| 5 | HAVING | Filter groups (aggregates allowed) |
| 6 | SELECT | Evaluate expressions, apply aliases |
| 7 | DISTINCT | Remove duplicate rows |
| 8 | Window Functions | Computed after SELECT expressions are resolved |
| 9 | ORDER BY | Sort result set (SELECT aliases available here) |
| 10 | LIMIT / OFFSET | Truncate result set |

**Why This Matters**

1. **Aliases in WHERE**: SELECT aliases are not yet defined when WHERE executes. `SELECT total * 1.1 AS with_tax ... WHERE with_tax > 100` fails — you must repeat the expression in WHERE or use a subquery.

2. **Aggregates in WHERE**: Aggregates do not exist at the WHERE stage — they are computed during GROUP BY. Use HAVING.

3. **ORDER BY can reference SELECT aliases**: ORDER BY executes after SELECT, so `ORDER BY with_tax DESC` is valid (in PostgreSQL and most databases).

4. **DISTINCT before ORDER BY**: DISTINCT runs before ORDER BY, which means you can only ORDER BY columns that appear in SELECT when using DISTINCT.

5. **Window functions after GROUP BY**: Window functions execute after GROUP BY, so they see aggregated rows. You can use window functions on aggregate results (e.g., `RANK() OVER (ORDER BY SUM(amount) DESC)`).

6. **LIMIT does not help with window functions**: Window functions are computed over the full result set before LIMIT is applied. You cannot "limit" the window by putting LIMIT earlier.

**Physical vs Logical Order**
The logical order is conceptual — the actual execution plan generated by the optimizer may differ greatly (e.g., the optimizer might apply a filter early using an index even though WHERE is logically step 3). Understanding logical order is essential for writing *correct* SQL; the optimizer handles *efficient* SQL.

**Real-World Example:**
A developer writes `SELECT customer_id, SUM(amount) AS total FROM orders WHERE total > 100 GROUP BY customer_id` and gets a "column total does not exist" error. Understanding execution order explains why: WHERE runs before SELECT aliases are created. Fix: move the condition to HAVING.

**Code Example:**
```sql
-- Demonstrating execution order with a concrete pipeline

-- Step 1-2: FROM + JOIN — establish the row set
-- Step 3: WHERE — filter before aggregation (uses actual column names, not aliases)
-- Step 4: GROUP BY — collapse to groups
-- Step 5: HAVING — filter groups (can use aggregates)
-- Step 6: SELECT — evaluate expressions and aliases
-- Step 7: DISTINCT — deduplicate
-- Step 8: (window functions here if any)
-- Step 9: ORDER BY — sort (CAN use SELECT aliases)
-- Step 10: LIMIT — trim

SELECT                                          -- Step 6
    c.id          AS customer_id,
    c.name        AS customer_name,
    COUNT(o.id)   AS order_count,
    SUM(o.total_amount) AS total_spend          -- alias defined here
FROM customers c                               -- Step 1
LEFT JOIN orders o ON c.id = o.customer_id     -- Step 2
WHERE o.created_at >= '2024-01-01'             -- Step 3: no aliases, no aggregates
  AND c.is_active = TRUE
GROUP BY c.id, c.name                          -- Step 4
HAVING COUNT(o.id) >= 3                        -- Step 5: aggregates OK, aliases NOT OK
   AND SUM(o.total_amount) > 100               -- repeat expression, not alias
ORDER BY total_spend DESC                      -- Step 9: aliases OK here!
LIMIT 50;                                      -- Step 10

-- ERROR: alias in WHERE
-- SELECT total * 1.1 AS with_tax FROM orders WHERE with_tax > 100;
-- FIX 1: repeat expression
SELECT total * 1.1 AS with_tax FROM orders WHERE total * 1.1 > 100;
-- FIX 2: use subquery/CTE
WITH priced AS (SELECT *, total * 1.1 AS with_tax FROM orders)
SELECT * FROM priced WHERE with_tax > 100;

-- ERROR: aggregate in WHERE
-- SELECT customer_id FROM orders WHERE COUNT(*) > 5 GROUP BY customer_id;
-- FIX: HAVING
SELECT customer_id FROM orders GROUP BY customer_id HAVING COUNT(*) > 5;

-- Window functions run after GROUP BY — you can rank aggregated results
SELECT
    department,
    SUM(salary)                                  AS dept_salary_total,
    RANK() OVER (ORDER BY SUM(salary) DESC)      AS dept_rank_by_salary
FROM employees
GROUP BY department;
-- This works because window functions execute AFTER GROUP BY (step 8 after step 4)

-- LIMIT does not restrict what window functions see
-- This returns top-10 customers but RANK is computed over ALL customers first
WITH customer_ranks AS (
    SELECT
        customer_id,
        total_spend,
        RANK() OVER (ORDER BY total_spend DESC) AS global_rank  -- over ALL rows
    FROM customer_summary
)
SELECT * FROM customer_ranks
LIMIT 10;   -- LIMIT applied after rank is fully computed

-- DISTINCT and ORDER BY interaction
-- This FAILS if the ORDER BY column is not in SELECT:
-- SELECT DISTINCT customer_id FROM orders ORDER BY created_at;  -- error!
-- FIX: include the column in SELECT
SELECT DISTINCT customer_id, created_at FROM orders ORDER BY created_at;
-- Or use a subquery
SELECT DISTINCT customer_id FROM (
    SELECT customer_id FROM orders ORDER BY created_at
) sub;
```

```java
// In JPQL, the same logical order applies
// Aliases defined in SELECT cannot be used in WHERE
@Query("""
    SELECT o.customerId, SUM(o.totalAmount) AS totalSpend
    FROM Order o
    WHERE o.createdAt >= :since
    GROUP BY o.customerId
    HAVING SUM(o.totalAmount) > :minSpend
    ORDER BY SUM(o.totalAmount) DESC
    """)
List<Object[]> findHighSpenders(@Param("since") LocalDate since,
                                 @Param("minSpend") BigDecimal minSpend);
```

**Follow-up Questions:**
1. Why can you reference a SELECT alias in ORDER BY but not in WHERE or HAVING?
2. In what step do window functions execute, and what are the implications for filtering on window function results?
3. Does the physical execution plan follow the same order as the logical execution order?

**Common Mistakes:**
- Referencing SELECT column aliases in WHERE or HAVING (they don't exist yet at those stages).
- Placing aggregate conditions in WHERE instead of HAVING.
- Assuming LIMIT runs early and restricts what window functions or ORDER BY process — LIMIT is the last step.

**Interview Traps:**
- "MySQL allows aliases in HAVING — is this standard behaviour?" — No. MySQL is lenient and allows it as an extension. PostgreSQL and standard SQL do not. This is a portability trap.
- "Does ORDER BY always run before LIMIT?" — Logically yes, but the optimizer may use a Top-N sort (heapsort) that interleaves them for efficiency. The logical result is the same.

**Quick Revision:** FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → Window Functions → ORDER BY → LIMIT; aliases only available from ORDER BY onward; aggregates only after GROUP BY.

---

### Topic 6: UNION vs UNION ALL vs INTERSECT vs EXCEPT

**Difficulty:** Easy-Medium | **Frequency:** Medium-High | **Companies:** Amazon, Stripe, FinTech broadly

**Q:** What is the difference between UNION, UNION ALL, INTERSECT, and EXCEPT? When would you use each, and what are the performance implications?

**Short Answer:**
UNION combines result sets and removes duplicates (implicit DISTINCT); UNION ALL combines result sets and keeps all rows including duplicates, and is faster because it skips deduplication. INTERSECT returns only rows present in *both* result sets; EXCEPT returns rows in the first set that are not in the second. All four require compatible column counts and data types.

**Deep Explanation:**

**Set Operators — Core Rules**
1. Both queries must have the same number of columns.
2. Corresponding columns must have compatible data types (PostgreSQL will attempt implicit casting).
3. Column *names* in the result come from the *first* query.
4. ORDER BY applies to the final combined result, not to individual queries — place it at the very end.

**UNION**
Equivalent to `UNION ALL` + `DISTINCT` on the combined result. The database must sort or hash the combined result to find and remove duplicates — O(n log n) or O(n) depending on the algorithm. Use when you genuinely need deduplication.

**UNION ALL**
No deduplication step. Simply appends the second result set to the first. Significantly faster for large result sets. Use when:
- You know there are no duplicates (different data sources, different date ranges), or
- Duplicates are acceptable (event logs, audit trails), or
- You want to count all occurrences.

**INTERSECT**
Returns rows present in *both* queries (effectively an inner join on all columns). `INTERSECT ALL` keeps duplicate matches.

**EXCEPT** (called MINUS in Oracle)
Returns rows from the *first* query that do not appear in the *second* query. `EXCEPT ALL` keeps duplicates proportionally. Useful for finding records in one set but not another (similar to a NOT EXISTS / LEFT JOIN anti-join but over full rows).

**Performance Comparison**
- `UNION ALL` is always the fastest — no extra pass needed.
- `UNION`, `INTERSECT`, `EXCEPT` all require a deduplication step (hash or sort).
- For large tables, rewriting INTERSECT/EXCEPT as a JOIN-based query often gives the optimizer more freedom to use indexes.

**Compatibility with ORDER BY and LIMIT**
Each sub-query in a set operation can have its own LIMIT but *cannot* have a bare ORDER BY (must wrap in a subquery). The final ORDER BY and LIMIT apply to the combined result.

**Real-World Example:**
A compliance system needs to find all account IDs that appear in *either* the fraud_flags table *or* the manual_review table (UNION), then find accounts that appear in *both* (INTERSECT), then find accounts in fraud_flags but *not yet* reviewed (EXCEPT). Three set operations, three different answers from the same two tables.

**Code Example:**
```sql
-- Schema:
-- flagged_accounts(account_id, reason, flagged_at)
-- reviewed_accounts(account_id, reviewer_id, reviewed_at, outcome)

-- UNION: all accounts that are either flagged or reviewed (deduped)
SELECT account_id, 'flagged'  AS source FROM flagged_accounts
UNION
SELECT account_id, 'reviewed' AS source FROM reviewed_accounts;
-- Deduplication: rows with same account_id AND same source are removed
-- Note: 'flagged' vs 'reviewed' differ, so most rows are NOT duplicates here

-- UNION ALL: combine event logs (duplicates intentional)
SELECT account_id, event_type, created_at FROM fraud_events
UNION ALL
SELECT account_id, event_type, created_at FROM manual_events
ORDER BY created_at DESC;   -- ORDER BY on combined result, not on individual queries

-- INTERSECT: accounts that are both flagged AND reviewed
SELECT account_id FROM flagged_accounts
INTERSECT
SELECT account_id FROM reviewed_accounts;

-- Equivalent with JOIN (often faster, allows index use)
SELECT DISTINCT f.account_id
FROM flagged_accounts f
INNER JOIN reviewed_accounts r ON f.account_id = r.account_id;

-- EXCEPT: flagged accounts NOT yet reviewed
SELECT account_id FROM flagged_accounts
EXCEPT
SELECT account_id FROM reviewed_accounts;

-- Equivalent with NOT EXISTS (often faster)
SELECT f.account_id
FROM flagged_accounts f
WHERE NOT EXISTS (
    SELECT 1 FROM reviewed_accounts r WHERE r.account_id = f.account_id
);

-- Performance: UNION ALL >> UNION for large tables
-- Bad: UNION causes full sort/hash for dedup on millions of rows
SELECT customer_id FROM us_customers
UNION
SELECT customer_id FROM eu_customers;   -- expensive if millions of rows

-- Good: if you know the datasets are disjoint (different regions)
SELECT customer_id FROM us_customers
UNION ALL
SELECT customer_id FROM eu_customers;   -- no dedup pass needed

-- ORDER BY trap: this fails
-- SELECT id FROM a ORDER BY id UNION ALL SELECT id FROM b;
-- Fix: ORDER BY at the end, or wrap in subqueries
(SELECT id FROM a ORDER BY id LIMIT 5)
UNION ALL
(SELECT id FROM b ORDER BY id LIMIT 5);

-- Combining UNION ALL with aggregation
SELECT 'US' AS region, COUNT(*), SUM(revenue) FROM us_orders
UNION ALL
SELECT 'EU' AS region, COUNT(*), SUM(revenue) FROM eu_orders
UNION ALL
SELECT 'APAC' AS region, COUNT(*), SUM(revenue) FROM apac_orders;
```

```java
// JPA — native UNION ALL query
@Query(value = """
    SELECT account_id, 'flagged' AS source FROM flagged_accounts
    UNION ALL
    SELECT account_id, 'reviewed' AS source FROM reviewed_accounts
    ORDER BY account_id
    """, nativeQuery = true)
List<Object[]> getAllAccountActivity();
```

**Follow-up Questions:**
1. Can you use UNION inside a CTE or subquery? Is there any restriction on ORDER BY inside a UNION member?
2. What happens to NULL values in UNION deduplication — are two NULLs considered equal?
3. When would you prefer EXCEPT over a NOT IN or NOT EXISTS approach?

**Common Mistakes:**
- Using UNION when UNION ALL is sufficient — paying deduplication cost unnecessarily.
- Mismatching column counts or incompatible data types between the two queries (the error message is sometimes cryptic).
- Placing ORDER BY inside an individual UNION member without parentheses — this is a syntax error or logic error.

**Interview Traps:**
- "Are two NULL rows considered duplicates by UNION?" — Yes. UNION's deduplication treats NULL as equal to NULL (unlike the equality predicate `=`, which returns UNKNOWN). So two identical rows with NULLs are collapsed into one.
- "Can INTERSECT be replaced by INNER JOIN?" — Yes, conceptually, but INTERSECT compares entire row values across all columns, while INNER JOIN requires you to specify the join columns explicitly. They are equivalent when joining on all columns.

**Quick Revision:** UNION ALL is fastest (no dedup); UNION = UNION ALL + DISTINCT; INTERSECT = rows in both; EXCEPT = rows in first but not second; NULL = NULL for set deduplication.

---

### Topic 7: NULL Handling

**Difficulty:** Medium | **Frequency:** High | **Companies:** Google, Amazon, Stripe, Two Sigma, Jane Street

**Q:** Explain three-valued logic in SQL. What is the difference between IS NULL and = NULL? How do COALESCE and NULLIF work?

**Short Answer:**
SQL uses three-valued logic: expressions evaluate to TRUE, FALSE, or UNKNOWN. Any comparison with NULL yields UNKNOWN, not TRUE or FALSE, which is why `= NULL` never matches anything — you must use `IS NULL`. COALESCE returns the first non-NULL value in a list; NULLIF returns NULL if two values are equal, otherwise the first value.

**Deep Explanation:**

**Three-Valued Logic (3VL)**
In standard boolean logic, everything is TRUE or FALSE. SQL adds a third value: UNKNOWN, which arises whenever NULL is involved in a comparison.

Truth table for AND, OR, NOT with UNKNOWN:
- `TRUE AND UNKNOWN = UNKNOWN`
- `FALSE AND UNKNOWN = FALSE`
- `TRUE OR UNKNOWN = TRUE`
- `FALSE OR UNKNOWN = UNKNOWN`
- `NOT UNKNOWN = UNKNOWN`

**WHERE clause behaviour**: A row is returned only if the WHERE condition evaluates to TRUE. Rows where the condition evaluates to UNKNOWN are silently excluded — this is the source of many NULL-related bugs.

**NULL Comparison Rules**
- `NULL = NULL` → UNKNOWN (not TRUE)
- `NULL <> NULL` → UNKNOWN
- `NULL = 5` → UNKNOWN
- `NULL IS NULL` → TRUE
- `NULL IS NOT NULL` → FALSE

This means `WHERE col = NULL` will never return any rows — ever. Always use `WHERE col IS NULL`.

**NULL in Aggregate Functions**
All aggregate functions (SUM, AVG, MIN, MAX, COUNT(col)) ignore NULLs. Exceptions:
- `COUNT(*)` counts all rows regardless of NULLs.
- `COUNT(col)` ignores NULL values in that column.
- If all values are NULL, SUM/AVG/MIN/MAX return NULL (not 0).

**NULL in JOIN conditions**
`ON a.col = b.col` does not match rows where either col is NULL (comparison is UNKNOWN). This means NULL foreign keys silently exclude rows from INNER JOINs.

**NULL in NOT IN**
`WHERE id NOT IN (SELECT customer_id FROM orders)` — if the subquery returns even one NULL, the entire NOT IN evaluates to UNKNOWN for every outer row, returning zero results. This is one of the most dangerous NULL traps in SQL.

**COALESCE(val1, val2, ..., valN)**
Returns the first non-NULL argument. Short-circuits — stops evaluating once a non-NULL value is found. Use to provide default values: `COALESCE(discount, 0)`.

**NULLIF(val1, val2)**
Returns NULL if val1 = val2; otherwise returns val1. Useful for avoiding division-by-zero: `revenue / NULLIF(units_sold, 0)` — division by zero becomes division by NULL, which returns NULL rather than throwing an error.

**NVL / IFNULL / ISNULL**
Database-specific aliases for COALESCE with two arguments:
- PostgreSQL: `COALESCE` (standard)
- MySQL: `IFNULL(val, default)`
- SQL Server: `ISNULL(val, default)`
Use COALESCE for portability.

**Real-World Example:**
A FinTech reporting system calculates profit margins. If cost_basis is NULL (for legacy records), division would be problematic. Using `NULLIF(cost_basis, 0)` prevents division by zero; using `COALESCE(revenue, 0)` ensures NULL revenues are treated as zero for summation; `IS NULL` checks identify records needing data migration.

**Code Example:**
```sql
-- Three-valued logic demonstration
SELECT
    5 = NULL,         -- UNKNOWN (not false, not true)
    NULL = NULL,      -- UNKNOWN
    NULL IS NULL,     -- TRUE
    NULL IS NOT NULL, -- FALSE
    NOT NULL,         -- UNKNOWN
    TRUE AND NULL,    -- UNKNOWN
    FALSE AND NULL,   -- FALSE (short-circuit)
    TRUE OR NULL,     -- TRUE (short-circuit)
    FALSE OR NULL;    -- UNKNOWN

-- IS NULL vs = NULL
-- This returns ZERO rows — = NULL always gives UNKNOWN
SELECT * FROM orders WHERE discount_amount = NULL;    -- BUG: returns nothing

-- This returns rows where discount_amount is NULL
SELECT * FROM orders WHERE discount_amount IS NULL;   -- CORRECT

-- NULL in WHERE — rows with NULL status are excluded silently
CREATE TABLE transactions (id INT, status VARCHAR(20), amount NUMERIC);
INSERT INTO transactions VALUES (1, 'COMPLETED', 100), (2, NULL, 50), (3, 'PENDING', 75);

SELECT * FROM transactions WHERE status = 'COMPLETED';   -- returns row 1 only
SELECT * FROM transactions WHERE status != 'COMPLETED';  -- returns row 3 ONLY, row 2 (NULL) excluded!
SELECT * FROM transactions WHERE status != 'COMPLETED'
                              OR status IS NULL;         -- returns rows 2 and 3

-- NOT IN trap with NULLs
SELECT id FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders);
-- If ANY order has customer_id = NULL, this returns EMPTY SET
-- Because: id NOT IN (..., NULL) → id <> NULL → UNKNOWN → row excluded

-- Safe alternatives
SELECT c.id FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);

SELECT c.id FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.customer_id IS NULL;  -- anti-join

-- COALESCE: return first non-NULL value
SELECT
    customer_id,
    COALESCE(preferred_name, first_name, 'Unknown') AS display_name,
    COALESCE(discount_rate, 0.0)                    AS effective_discount
FROM customers;

-- NULLIF: return NULL if values are equal (avoid division by zero)
SELECT
    product_id,
    total_revenue,
    units_sold,
    total_revenue / NULLIF(units_sold, 0)        AS revenue_per_unit,  -- NULL if units=0, not ERROR
    NULLIF(status, 'UNKNOWN')                    AS clean_status       -- treat 'UNKNOWN' as NULL
FROM product_sales;

-- NULL in aggregates
SELECT
    COUNT(*)                          AS total_rows,           -- counts ALL rows (including NULL)
    COUNT(discount_amount)            AS rows_with_discount,   -- ignores NULLs
    COUNT(DISTINCT discount_amount)   AS distinct_discounts,   -- ignores NULLs
    SUM(discount_amount)              AS total_discounts,      -- NULLs ignored, 0 if all NULL → returns NULL
    COALESCE(SUM(discount_amount), 0) AS total_discounts_safe  -- NULL → 0
FROM orders;

-- NULL in ORDER BY (PostgreSQL: NULLs sort LAST by default in ASC)
SELECT id, score
FROM leaderboard
ORDER BY score DESC NULLS LAST;    -- explicitly put NULLs at end even in DESC

ORDER BY score DESC NULLS FIRST;   -- put NULLs first (treat as highest)

-- NULL-safe equality operator (PostgreSQL)
-- IS NOT DISTINCT FROM treats NULLs as equal
SELECT * FROM a
JOIN b ON a.col IS NOT DISTINCT FROM b.col;  -- NULL = NULL here is TRUE
```

```java
// Spring Data JPA — handling NULLs
@Query("SELECT o FROM Order o WHERE o.discountAmount IS NULL")
List<Order> findOrdersWithNoDiscount();

// COALESCE in JPQL
@Query("SELECT o FROM Order o WHERE COALESCE(o.discountAmount, 0) > :threshold")
List<Order> findOrdersAboveEffectiveThreshold(@Param("threshold") BigDecimal threshold);
```

**Follow-up Questions:**
1. If you do `WHERE col != 'value'`, will rows where col is NULL be returned? Why or why not?
2. What is `IS NOT DISTINCT FROM`, and when would you use it over `=`?
3. How do GROUP BY and DISTINCT treat NULL values — do they collapse multiple NULLs into one group?

**Common Mistakes:**
- Using `= NULL` instead of `IS NULL` — returns zero rows without any error.
- Using `NOT IN` with a subquery that might return NULLs — entire result becomes empty.
- Forgetting that `AVG(col)` ignores NULLs — the denominator is only the non-NULL count, which can produce misleading averages.

**Interview Traps:**
- "What does `SELECT NULL = NULL` return?" — UNKNOWN (or NULL in some display modes), not TRUE.
- "Does GROUP BY treat NULL values as equal?" — Yes. All NULL values are grouped into the same group by GROUP BY and DISTINCT, even though `NULL = NULL` is UNKNOWN in WHERE.
- "What is the result of `COALESCE(NULL, NULL, NULL)`?" — NULL. COALESCE only returns NULL if all arguments are NULL.

**Quick Revision:** NULL comparisons always yield UNKNOWN; use IS NULL not = NULL; NOT IN + NULLs = empty result; COALESCE for defaults; NULLIF for zero-division safety; GROUP BY collapses NULLs together.

---

### Topic 8: String & Date Functions

**Difficulty:** Easy-Medium | **Frequency:** Medium | **Companies:** Amazon, Stripe, Uber, all FinTech

**Q:** What are the most important string and date functions in PostgreSQL? How do you perform date arithmetic and extract components from timestamps?

**Short Answer:**
PostgreSQL provides rich string functions (UPPER, LOWER, TRIM, SUBSTRING, CONCAT, LIKE, REGEXP, SPLIT_PART) and date/time functions (NOW, CURRENT_DATE, DATE_TRUNC, DATE_PART/EXTRACT, AGE, interval arithmetic). DATE_TRUNC rounds a timestamp to a specified granularity (useful for grouping by month/week); EXTRACT pulls out a specific numeric component. CAST and :: are used for type conversion.

**Deep Explanation:**

**String Functions**

| Function | Description | Example |
|---|---|---|
| `LENGTH(s)` | Character count | `LENGTH('hello')` → 5 |
| `UPPER(s)` / `LOWER(s)` | Case conversion | `UPPER('hello')` → 'HELLO' |
| `TRIM(s)` | Remove leading/trailing spaces | `TRIM('  hi  ')` → 'hi' |
| `LTRIM` / `RTRIM` | One-sided trim | |
| `SUBSTRING(s, start, len)` | Extract substring | `SUBSTRING('hello', 2, 3)` → 'ell' |
| `LEFT(s, n)` / `RIGHT(s, n)` | First/last n chars | `LEFT('hello', 3)` → 'hel' |
| `CONCAT(s1, s2, ...)` | Concatenate (NULL-safe) | |
| `\|\|` operator | Concatenate (NULL propagates) | `'a' \|\| 'b'` → 'ab' |
| `POSITION(sub IN s)` | Find substring position | `POSITION('ll' IN 'hello')` → 3 |
| `REPLACE(s, from, to)` | Replace all occurrences | |
| `SPLIT_PART(s, delim, n)` | Split by delimiter | `SPLIT_PART('a,b,c', ',', 2)` → 'b' |
| `REGEXP_REPLACE` | Regex-based replace | |
| `REGEXP_MATCHES` | Regex-based extraction | |
| `LPAD(s, len, pad)` | Left-pad to length | `LPAD('5', 3, '0')` → '005' |
| `FORMAT(fmt, args)` | sprintf-style formatting | |
| `TO_CHAR(val, fmt)` | Value to formatted string | `TO_CHAR(NOW(), 'YYYY-MM')` |

**LIKE vs ILIKE**
- `LIKE`: case-sensitive pattern matching (`%` = any sequence, `_` = one char)
- `ILIKE`: case-insensitive (PostgreSQL extension)
- For regex: `~` (case-sensitive), `~*` (case-insensitive), `!~`, `!~*`

**Date/Time Functions and Types**

PostgreSQL date/time types:
- `DATE`: date only (no time)
- `TIME`: time only
- `TIMESTAMP`: date + time (no timezone)
- `TIMESTAMPTZ` (or `TIMESTAMP WITH TIME ZONE`): date + time + timezone-aware
- `INTERVAL`: duration

**Key Functions**

| Function | Returns | Example |
|---|---|---|
| `NOW()` | Current `TIMESTAMPTZ` | |
| `CURRENT_DATE` | Current `DATE` | |
| `CURRENT_TIMESTAMP` | Current `TIMESTAMPTZ` | SQL standard |
| `DATE_TRUNC(unit, ts)` | Truncated `TIMESTAMP` | `DATE_TRUNC('month', NOW())` → first of current month |
| `EXTRACT(field FROM ts)` | Numeric value | `EXTRACT(YEAR FROM NOW())` → 2026 |
| `DATE_PART(field, ts)` | Same as EXTRACT (PostgreSQL) | |
| `AGE(ts2, ts1)` | `INTERVAL` between two timestamps | `AGE(NOW(), birth_date)` |
| `TO_TIMESTAMP(str, fmt)` | Parse string to timestamp | |
| `TO_DATE(str, fmt)` | Parse string to date | |

**DATE_TRUNC units:** microseconds, milliseconds, second, minute, hour, day, week, month, quarter, year, decade, century, millennium

**Interval Arithmetic**
PostgreSQL lets you add/subtract intervals directly:
- `NOW() - INTERVAL '30 days'`
- `'2024-01-15'::date + 7` (add 7 days)
- `date_trunc('month', NOW()) + INTERVAL '1 month' - INTERVAL '1 day'` (last day of current month)

**AT TIME ZONE**
Converts a TIMESTAMP to a specific timezone:
```sql
NOW() AT TIME ZONE 'America/New_York'
```

**CAST and :: Operator**
- `CAST(value AS type)` — SQL standard
- `value::type` — PostgreSQL shorthand (preferred in PostgreSQL code)

**Real-World Example:**
A payments platform needs a monthly revenue report. They use `DATE_TRUNC('month', created_at)` to group transactions by month, `EXTRACT(YEAR FROM created_at)` to filter by year, and `TO_CHAR(date_trunc(...), 'Month YYYY')` for human-readable labels. String functions clean up merchant names (TRIM, UPPER for normalization) before matching.

**Code Example:**
```sql
-- String functions
SELECT
    customer_id,
    UPPER(TRIM(email))                          AS normalized_email,
    LEFT(phone, 3)                              AS area_code,
    SUBSTRING(account_number, 1, 4) || '****'  AS masked_account,
    LENGTH(description)                         AS desc_length,
    REPLACE(category, '_', ' ')                AS readable_category,
    SPLIT_PART(full_name, ' ', 1)              AS first_name,
    SPLIT_PART(full_name, ' ', 2)              AS last_name,
    LPAD(CAST(customer_id AS TEXT), 8, '0')   AS padded_id,
    CONCAT(first_name, ' ', last_name)         AS display_name  -- NULL-safe concat
FROM customers;

-- LIKE and ILIKE
SELECT * FROM products
WHERE name ILIKE '%laptop%'           -- case-insensitive search
  AND sku LIKE 'LAP-%'                -- starts with LAP-
  AND description ~ '\d{4}'          -- regex: contains 4-digit number
  AND category !~ '^legacy';         -- does NOT start with 'legacy'

-- Date arithmetic and current time
SELECT
    CURRENT_DATE                                     AS today,
    NOW()                                            AS now_with_tz,
    NOW()::DATE                                      AS now_date,
    CURRENT_DATE - INTERVAL '30 days'                AS thirty_days_ago,
    CURRENT_DATE + 7                                 AS one_week_later,    -- integer = days
    DATE_TRUNC('month', NOW())                       AS first_of_month,
    DATE_TRUNC('month', NOW()) + INTERVAL '1 month'
        - INTERVAL '1 day'                           AS last_of_month;

-- EXTRACT and DATE_PART
SELECT
    created_at,
    EXTRACT(YEAR    FROM created_at)    AS yr,
    EXTRACT(MONTH   FROM created_at)    AS mo,
    EXTRACT(DAY     FROM created_at)    AS dy,
    EXTRACT(HOUR    FROM created_at)    AS hr,
    EXTRACT(DOW     FROM created_at)    AS day_of_week,   -- 0=Sunday, 6=Saturday
    EXTRACT(EPOCH   FROM created_at)    AS unix_timestamp,
    DATE_PART('quarter', created_at)    AS quarter
FROM orders;

-- DATE_TRUNC for grouping by time period
SELECT
    DATE_TRUNC('month', created_at)   AS month,
    DATE_TRUNC('week',  created_at)   AS week_start,   -- week starts Monday in ISO
    COUNT(*)                          AS order_count,
    SUM(total_amount)                 AS revenue
FROM orders
WHERE created_at >= DATE_TRUNC('year', NOW())   -- year to date
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month;

-- Human-readable formatting with TO_CHAR
SELECT
    TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS')  AS formatted_datetime,
    TO_CHAR(created_at, 'Month DD, YYYY')           AS long_format,
    TO_CHAR(total_amount, 'FM$999,999.00')          AS formatted_amount
FROM orders;

-- Date difference and AGE
SELECT
    customer_id,
    created_at::DATE                             AS signup_date,
    CURRENT_DATE - created_at::DATE              AS days_since_signup,   -- integer
    AGE(NOW(), created_at)                       AS tenure,              -- interval '2 years 3 months'
    EXTRACT(DAY FROM (NOW() - created_at))       AS days_as_float
FROM customers;

-- Timezone handling
SELECT
    created_at                                         AS utc_time,
    created_at AT TIME ZONE 'America/New_York'        AS ny_time,
    created_at AT TIME ZONE 'Asia/Tokyo'              AS tokyo_time,
    TIMEZONE('UTC', created_at)                       AS explicit_utc
FROM orders;

-- Parsing strings to dates/timestamps
SELECT
    TO_DATE('15-07-2024', 'DD-MM-YYYY')              AS parsed_date,
    TO_TIMESTAMP('2024-07-15 14:30:00', 'YYYY-MM-DD HH24:MI:SS') AS parsed_ts,
    '2024-01-15'::DATE                               AS cast_date,
    '2024-01-15 10:30:00'::TIMESTAMP                 AS cast_ts;

-- Practical: find orders placed in the last 7 days, grouped by day
SELECT
    created_at::DATE       AS order_date,
    COUNT(*)               AS daily_orders,
    SUM(total_amount)      AS daily_revenue,
    AVG(total_amount)      AS avg_order_value
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
  AND created_at <  CURRENT_DATE + INTERVAL '1 day'  -- exclusive upper bound
GROUP BY created_at::DATE
ORDER BY order_date;

-- String matching for full-text search prep (before using tsvector)
SELECT id, title
FROM articles
WHERE title ILIKE '%machine learning%'
   OR to_tsvector('english', content) @@ to_tsquery('machine & learning');
```

```java
// Spring Data JPA — date handling
@Query("""
    SELECT o FROM Order o
    WHERE o.createdAt >= :startDate
      AND o.createdAt < :endDate
    """)
List<Order> findOrdersInRange(
    @Param("startDate") LocalDateTime startDate,
    @Param("endDate") LocalDateTime endDate
);

// Native query with date_trunc
@Query(value = """
    SELECT DATE_TRUNC('month', created_at) AS month,
           SUM(total_amount) AS revenue
    FROM orders
    GROUP BY DATE_TRUNC('month', created_at)
    ORDER BY month
    """, nativeQuery = true)
List<Object[]> getMonthlyRevenue();

// Using @CreatedDate for automatic timestamp management
@Entity
public class Order {
    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;
}
```

**Follow-up Questions:**
1. What is the difference between `TIMESTAMP` and `TIMESTAMPTZ` in PostgreSQL? Why does it matter for applications with users in multiple timezones?
2. How do you calculate the number of business days between two dates in SQL?
3. What is the difference between `DATE_TRUNC('week', ts)` and `DATE_TRUNC('day', ts)` for a Monday timestamp?

**Common Mistakes:**
- Using `TIMESTAMP` instead of `TIMESTAMPTZ` for user-facing events — timestamps lose timezone context and produce incorrect comparisons across timezone boundaries.
- String concatenation with `||` when a value might be NULL — the result is NULL. Use `CONCAT()` for NULL-safe concatenation.
- Comparing dates with `BETWEEN '2024-01-01' AND '2024-01-31'` — this includes all times up to `2024-01-31 00:00:00` but excludes `2024-01-31 23:59:59`. Use `>= start AND < end + 1 day` for inclusive date ranges.

**Interview Traps:**
- "What does `DATE_TRUNC('week', '2024-07-03'::date)` return?" — `2024-07-01` (Monday, ISO week start). PostgreSQL week starts on Monday.
- "What is the performance implication of `WHERE DATE_TRUNC('month', created_at) = '2024-01-01'`?" — Non-SARGable: it applies a function to the indexed column, preventing index range scans. Fix: `WHERE created_at >= '2024-01-01' AND created_at < '2024-02-01'`.

**Quick Revision:** DATE_TRUNC rounds timestamps for grouping; EXTRACT gets numeric components; TIMESTAMPTZ over TIMESTAMP for multi-timezone apps; function-wrapped columns in WHERE kill index usage — rewrite as range predicates.

---

## Part A Summary — Quick Revision Card

| Topic | Key Takeaway |
|-------|-------------|
| Joins | LEFT JOIN + filter in WHERE = accidental INNER JOIN. Filter in ON to preserve NULLs. |
| Subqueries & CTEs | NOT IN + NULLs = empty result. Correlated subquery = O(n). Recursive CTE needs depth guard. |
| Window Functions | LAST_VALUE needs full-partition frame. Cannot filter on window result in WHERE — use CTE. |
| GROUP BY & HAVING | WHERE = before aggregation; HAVING = after. ROLLUP = hierarchy; CUBE = all combos. |
| Execution Order | FROM→JOIN→WHERE→GROUP BY→HAVING→SELECT→WINDOW→ORDER BY→LIMIT. Aliases usable only in ORDER BY. |
| Set Operators | UNION ALL fastest (no dedup); NULL=NULL for set deduplication; EXCEPT = anti-set. |
| NULL Handling | = NULL always UNKNOWN; NOT IN + NULLs = empty; COALESCE for defaults; NULLIF for /0 safety. |
| String & Date | DATE_TRUNC for grouping; function in WHERE kills index; TIMESTAMPTZ > TIMESTAMP. |

---

*End of Chapter 14, Part A. Part B covers indexes, query optimization, transactions, and normalization.*


---

# Chapter 14 — SQL for Backend Engineers: PART B

> **Volume 4: Databases** | Target: SDE2+ | Companies: FAANG, FinTech, Enterprise

---

## Topic 9: Aggregate Functions

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Google, Amazon, Meta, Stripe, Robinhood

**Q:** What is the difference between `COUNT(*)` and `COUNT(column)`, and what are the performance implications of using `DISTINCT` inside aggregates?

**Short Answer:**
`COUNT(*)` counts every row including NULLs; `COUNT(col)` counts only non-NULL values in that column. Using `DISTINCT` inside an aggregate (e.g., `COUNT(DISTINCT col)`) forces a sort or hash operation that can dramatically increase query cost on large tables.

**Deep Explanation:**

`COUNT(*)` is the fastest aggregate — the planner can satisfy it from an index scan or even a table-level statistic in some cases. `COUNT(col)` requires the engine to inspect each value and skip NULLs, adding a null-check overhead. The difference matters most when a column has many NULLs.

For `SUM`, `AVG`, `MIN`, `MAX`:
- All ignore NULL values by definition (SQL standard).
- `AVG` computes `SUM / COUNT(non-null)`, not `SUM / total_rows`. This surprises developers when rows have NULLs.
- `MIN`/`MAX` benefit from B-tree index scans — PostgreSQL can satisfy them with an index-only scan touching just one leaf page.

`DISTINCT` inside aggregates:
- `COUNT(DISTINCT col)` forces deduplication before counting. PostgreSQL uses a hash aggregate or sort. On millions of rows this can be 10-100x slower than a plain `COUNT`.
- Approximate alternatives: `pg_catalog.pg_ndistinct` from `ANALYZE`, or the HyperLogLog extension for streaming cardinality estimates.
- `SUM(DISTINCT col)` and `AVG(DISTINCT col)` are valid SQL but rare in practice — always justify them in a review.

**Real-World Example:**
A FinTech dashboard query calculates monthly active users: `COUNT(DISTINCT user_id)`. On a 500M-row events table this takes 45 seconds. The fix is to pre-aggregate into a `monthly_active_users` summary table refreshed nightly, or use a Bloom filter / HyperLogLog approximation for real-time dashboards.

**Code Example:**
```sql
-- COUNT(*) vs COUNT(col)
SELECT
    COUNT(*)                        AS total_rows,
    COUNT(email)                    AS rows_with_email,   -- skips NULLs
    COUNT(DISTINCT email)           AS unique_emails,     -- expensive dedup
    SUM(amount)                     AS total_amount,      -- NULLs excluded
    AVG(amount)                     AS avg_amount,        -- SUM/COUNT(non-null)
    MIN(created_at)                 AS first_event,
    MAX(created_at)                 AS last_event
FROM orders
WHERE status = 'completed';

-- AVG trap: when amount can be NULL
-- This gives different results:
SELECT AVG(amount)                            AS avg_ignores_null
     , SUM(amount) / COUNT(*)                 AS avg_treats_null_as_zero
FROM orders;

-- FILTER clause (PostgreSQL 9.4+) — conditional aggregate without CASE
SELECT
    COUNT(*) FILTER (WHERE status = 'completed')  AS completed,
    COUNT(*) FILTER (WHERE status = 'pending')    AS pending,
    SUM(amount) FILTER (WHERE status = 'completed') AS completed_revenue
FROM orders;

-- Approximate distinct count with pg_stats
SELECT n_distinct
FROM pg_stats
WHERE tablename = 'orders' AND attname = 'user_id';
```

**Follow-up Questions:**
1. How does `GROUPING SETS` differ from multiple `GROUP BY` queries?
2. What does `HAVING` do that `WHERE` cannot, and at what execution stage is it applied?
3. How would you compute a running total without window functions (and why is the window function approach better)?

**Common Mistakes:**
- Assuming `AVG` divides by total rows — it divides by non-NULL count.
- Using `COUNT(DISTINCT col)` in a hot query path without understanding its cost.
- Forgetting that `SUM` of zero rows returns NULL, not 0 — use `COALESCE(SUM(col), 0)`.

**Interview Traps:**
- `SELECT COUNT(1)` vs `COUNT(*)` — in modern PostgreSQL they are identical; the optimizer rewrites them.
- `AVG` on integer columns truncates in some databases (not PostgreSQL, which promotes to numeric).

**Quick Revision:** `COUNT(*)` counts all rows; `COUNT(col)` skips NULLs; `DISTINCT` inside aggregates triggers deduplication and is expensive at scale.

---

## Topic 10: Transactions in SQL

**Difficulty:** High | **Frequency:** Very High | **Companies:** Stripe, PayPal, Goldman Sachs, Amazon, Google

**Q:** Explain transaction isolation levels in PostgreSQL. What anomalies does each level prevent, and when would you choose SERIALIZABLE?

**Short Answer:**
PostgreSQL supports READ COMMITTED (default), REPEATABLE READ, and SERIALIZABLE; READ UNCOMMITTED is accepted but silently upgraded to READ COMMITTED. Each level trades concurrency for protection against dirty reads, non-repeatable reads, and phantom reads.

**Deep Explanation:**

**Transaction basics:**
```
BEGIN → statements → COMMIT (or ROLLBACK on error)
```
A transaction is atomic: either all statements commit or none do. In PostgreSQL, DDL (CREATE TABLE, ALTER) is transactional too — a rare but powerful feature.

**Isolation anomalies (SQL standard):**
| Anomaly | Description |
|---|---|
| Dirty Read | Read uncommitted data from another transaction |
| Non-repeatable Read | Same row returns different values within a transaction |
| Phantom Read | A re-executed range query returns different rows |
| Serialization Anomaly | Committed results could not arise from any serial execution |

**PostgreSQL isolation levels:**
| Level | Dirty Read | Non-repeatable Read | Phantom Read | Serialization Anomaly |
|---|---|---|---|---|
| READ UNCOMMITTED | Prevented* | Possible | Possible | Possible |
| READ COMMITTED | Prevented | Possible | Possible | Possible |
| REPEATABLE READ | Prevented | Prevented | Prevented** | Possible |
| SERIALIZABLE | Prevented | Prevented | Prevented | Prevented |

*PostgreSQL never allows dirty reads regardless of level.
**PostgreSQL's MVCC prevents phantoms at REPEATABLE READ, unlike the SQL standard.

**MVCC (Multi-Version Concurrency Control):**
PostgreSQL does not use read locks. Instead each transaction sees a snapshot of the database taken at a specific point. Writers and readers never block each other, which is why PostgreSQL scales well for OLTP.

**SAVEPOINT:**
Allows partial rollback within a transaction. Useful in batch processing where one failed record should not abort the entire batch.

**SERIALIZABLE SNAPSHOT ISOLATION (SSI):**
PostgreSQL's SERIALIZABLE uses SSI, not locking. It detects dangerous read-write dependency cycles at commit time and aborts one of the transactions. Applications must retry aborted transactions.

**Real-World Example:**
A bank transfer: debit account A, credit account B. Without a transaction, a crash between the two statements leaves the system in an inconsistent state. With SERIALIZABLE, two concurrent transfers involving the same accounts are guaranteed to produce the same result as if they ran one after the other.

**Code Example:**
```sql
-- Basic transaction
BEGIN;
UPDATE accounts SET balance = balance - 500 WHERE id = 1;
UPDATE accounts SET balance = balance + 500 WHERE id = 2;
COMMIT;

-- ROLLBACK on error (application level)
BEGIN;
UPDATE accounts SET balance = balance - 500 WHERE id = 1;
-- something fails here
ROLLBACK;

-- SAVEPOINT for partial rollback
BEGIN;
INSERT INTO audit_log (action) VALUES ('transfer_start');

SAVEPOINT before_debit;
UPDATE accounts SET balance = balance - 500 WHERE id = 1;
-- if validation fails:
ROLLBACK TO SAVEPOINT before_debit;

COMMIT;  -- audit_log insert still commits

-- Set isolation level
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE id = 1;
-- ... other work ...
SELECT balance FROM accounts WHERE id = 1; -- guaranteed same result
COMMIT;

-- SERIALIZABLE with retry logic in application
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT SUM(balance) FROM accounts WHERE type = 'savings';
INSERT INTO interest_payments SELECT id, balance * 0.02 FROM accounts;
COMMIT; -- may raise 40001 serialization failure; app must retry

-- Advisory locks for explicit coordination
BEGIN;
SELECT pg_advisory_xact_lock(hashtext('transfer_user_42'));
-- now exclusive: safe to do multi-step logic
COMMIT;
```

**Follow-up Questions:**
1. What is the difference between optimistic and pessimistic locking, and when do you use each?
2. How does `SELECT FOR UPDATE` work and what lock does it acquire?
3. In a microservices architecture without distributed transactions, how do you ensure consistency? (Saga pattern, outbox pattern)

**Common Mistakes:**
- Using SERIALIZABLE everywhere — it adds retry overhead; READ COMMITTED is fine for most OLTP reads.
- Not handling serialization failure (error code 40001) in application code when using SERIALIZABLE.
- Long-running transactions that hold locks and bloat the MVCC dead-tuple pile.

**Interview Traps:**
- "PostgreSQL ignores READ UNCOMMITTED" — it accepts the syntax but silently uses READ COMMITTED.
- Autocommit is ON by default in psql — every statement is its own transaction unless you `BEGIN`.

**Quick Revision:** PostgreSQL uses MVCC; default isolation is READ COMMITTED; SERIALIZABLE uses SSI and requires application retry on 40001 errors.

---

## Topic 11: Views & Materialized Views

**Difficulty:** Medium | **Frequency:** High | **Companies:** Uber, LinkedIn, Snowflake, Palantir, Deutsche Bank

**Q:** What is the difference between a regular view and a materialized view, and when should you use each?

**Short Answer:**
A regular view is a stored query — it executes against live data every time it is queried with no storage cost. A materialized view stores the query result physically and must be refreshed explicitly; it trades freshness for query speed.

**Deep Explanation:**

**Regular View:**
- No physical storage for data (just the SQL definition is stored).
- Every query against the view re-executes the underlying SQL.
- Always returns current data.
- PostgreSQL can "push down" predicates into the view's query (predicate pushdown), so `SELECT * FROM my_view WHERE id = 5` does not fetch all rows first.
- Useful for: encapsulating complex joins, hiding columns for security (row/column-level security), simplifying application queries.

**Materialized View:**
- Stores the result set physically like a table.
- Query is fast (no re-computation) but data may be stale.
- Must be refreshed: `REFRESH MATERIALIZED VIEW view_name;` — this locks the view during refresh by default.
- `REFRESH MATERIALIZED VIEW CONCURRENTLY view_name;` — allows reads during refresh but requires a unique index on the materialized view.
- No automatic refresh in PostgreSQL — you schedule it (cron, pg_cron extension, or application scheduler).
- Useful for: expensive aggregations, pre-joined denormalized data for reporting, OLAP queries on OLTP databases.

**Updatable Views:**
PostgreSQL supports `INSERT`/`UPDATE`/`DELETE` on simple views (single table, no aggregation, no DISTINCT). For complex views, use `INSTEAD OF` triggers or `WITH CHECK OPTION`.

**Real-World Example:**
An e-commerce platform has a dashboard showing daily revenue by category. The underlying query joins 4 tables and aggregates 10M rows — taking 8 seconds. Converting to a materialized view refreshed every 15 minutes reduces query time to 20ms. The business accepts 15-minute-stale data for this dashboard.

**Code Example:**
```sql
-- Regular view: always live data, no storage
CREATE VIEW active_users AS
SELECT u.id, u.email, u.created_at, COUNT(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON o.user_id = u.id AND o.status = 'completed'
WHERE u.is_active = TRUE
GROUP BY u.id, u.email, u.created_at;

-- Query the view — underlying SQL runs every time
SELECT * FROM active_users WHERE id = 42;

-- Materialized view: stored result
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT
    date_trunc('day', created_at)   AS day,
    category_id,
    SUM(amount)                      AS revenue,
    COUNT(*)                         AS order_count
FROM orders
WHERE status = 'completed'
GROUP BY 1, 2;

-- Required for CONCURRENT refresh
CREATE UNIQUE INDEX ON daily_revenue (day, category_id);

-- Refresh options
REFRESH MATERIALIZED VIEW daily_revenue;              -- locks, fast
REFRESH MATERIALIZED VIEW CONCURRENTLY daily_revenue; -- no lock, slower

-- Schedule via pg_cron (if installed)
SELECT cron.schedule('refresh-daily-revenue', '*/15 * * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY daily_revenue');

-- Drop
DROP VIEW active_users;
DROP MATERIALIZED VIEW daily_revenue;

-- WITH CHECK OPTION on updatable view
CREATE VIEW adult_users AS
SELECT * FROM users WHERE age >= 18
WITH CHECK OPTION;  -- prevents INSERT of users with age < 18
```

**Follow-up Questions:**
1. How would you implement automatic incremental refresh of a materialized view?
2. What is a "deferred view" and how does PostgreSQL handle view security?
3. How do materialized views in PostgreSQL compare to those in Oracle or SQL Server?

**Common Mistakes:**
- Forgetting that `REFRESH MATERIALIZED VIEW` without `CONCURRENTLY` locks all reads.
- Not creating a unique index before using `CONCURRENTLY` (it will error).
- Using a regular view for a heavy aggregation that runs thousands of times per minute.

**Interview Traps:**
- "Can you index a regular view?" — No (not in PostgreSQL). You index a materialized view.
- Materialized view refresh is not transactional in the sense that a partial refresh failure leaves the view in its old state (the refresh is atomic).

**Quick Revision:** Regular view = stored SQL, always fresh, no storage; materialized view = stored result, must refresh, fast reads.

---

## Topic 12: Stored Procedures vs Functions

**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Oracle shops, Legacy FinTech, SAP, IBM

**Q:** What is the difference between a stored procedure and a function in PostgreSQL, and why are they generally avoided in microservices architectures?

**Short Answer:**
In PostgreSQL, functions return a value and can be used in SQL expressions; procedures (added in PG 11) do not return a value and can manage transactions. Both are avoided in microservices because they embed business logic in the database, making versioning, testing, and scaling difficult.

**Deep Explanation:**

**Functions (CREATE FUNCTION):**
- Must return a value (scalar, row, or set).
- Can be called in a `SELECT` expression: `SELECT my_func(id) FROM table`.
- Cannot issue `COMMIT`/`ROLLBACK` inside (they run within the caller's transaction).
- Pure SQL functions can be inlined by the planner (treated as a macro), enabling optimization.
- `IMMUTABLE` / `STABLE` / `VOLATILE` volatility markers affect caching and optimization.

**Procedures (CREATE PROCEDURE):**
- Introduced in PostgreSQL 11.
- Called with `CALL procedure_name(args)`.
- Can contain `COMMIT` and `ROLLBACK` — useful for batch jobs with checkpointing.
- Cannot be used in SQL expressions.

**PL/pgSQL basics:**
- Procedural language with variables, loops, conditionals, exception handling.
- `RAISE NOTICE` for logging; `RAISE EXCEPTION` for errors.
- `EXECUTE` for dynamic SQL (susceptible to injection if not using `$1` placeholders).

**Why avoid in microservices:**
1. **Deployment coupling**: schema migrations and code deployments must be coordinated.
2. **Version control**: SQL procedures are harder to diff and test than application code.
3. **Scaling**: business logic in the DB cannot be horizontally scaled independently of the DB.
4. **Language lock-in**: PL/pgSQL skills are rarer than Java/Python/Go.
5. **Testing**: unit testing stored procedures requires database infrastructure.

**When to use them:**
- Audit triggers and CDC (change data capture) hooks.
- Complex batch operations inside the DB where network round-trips are the bottleneck.
- Legacy systems where the pattern is already established.

**Real-World Example:**
A legacy bank has a stored procedure `transfer_funds` that handles the full debit/credit/audit logic. This works fine for a monolith but becomes a pain point during a microservices migration: the payments service must call the DB directly, bypassing all application-level observability (tracing, metrics, circuit breakers).

**Code Example:**
```sql
-- PL/pgSQL function: returns a value, usable in SELECT
CREATE OR REPLACE FUNCTION get_account_balance(p_account_id BIGINT)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE  -- safe to cache within a transaction
AS $$
DECLARE
    v_balance NUMERIC;
BEGIN
    SELECT balance INTO v_balance
    FROM accounts
    WHERE id = p_account_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % not found', p_account_id;
    END IF;

    RETURN v_balance;
END;
$$;

-- Call in a query
SELECT get_account_balance(42);

-- Stored procedure: can COMMIT/ROLLBACK, called with CALL
CREATE OR REPLACE PROCEDURE batch_apply_interest(p_rate NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
    v_account RECORD;
    v_processed INT := 0;
BEGIN
    FOR v_account IN SELECT id, balance FROM accounts WHERE type = 'savings'
    LOOP
        UPDATE accounts
        SET balance = balance + (balance * p_rate),
            updated_at = NOW()
        WHERE id = v_account.id;

        v_processed := v_processed + 1;

        -- Checkpoint every 1000 rows to avoid long transactions
        IF v_processed % 1000 = 0 THEN
            COMMIT;
        END IF;
    END LOOP;

    RAISE NOTICE 'Processed % accounts', v_processed;
END;
$$;

CALL batch_apply_interest(0.005);

-- Trigger function (no return value except trigger type)
CREATE OR REPLACE FUNCTION audit_account_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO account_audit (account_id, old_balance, new_balance, changed_at)
    VALUES (NEW.id, OLD.balance, NEW.balance, NOW());
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_account_audit
AFTER UPDATE OF balance ON accounts
FOR EACH ROW EXECUTE FUNCTION audit_account_changes();
```

**Follow-up Questions:**
1. What is the difference between `STABLE`, `IMMUTABLE`, and `VOLATILE` functions and why do they matter?
2. How do you prevent SQL injection in dynamic SQL within PL/pgSQL?
3. In what scenario would you choose a stored procedure over application-level logic in 2024?

**Common Mistakes:**
- Using `VOLATILE` (the default) for a function that only reads data — misses caching opportunities.
- Forgetting that `EXECUTE` in PL/pgSQL with string concatenation is injectable — always use `EXECUTE ... USING $1`.
- Creating functions without `SECURITY DEFINER` when elevated privileges are needed, or with it when they are not (privilege escalation risk).

**Interview Traps:**
- "Stored procedures are always bad" — not true; audit triggers and batch ETL inside the DB are legitimate uses.
- PostgreSQL did not have `PROCEDURE` until version 11; before that, everything was a `FUNCTION`.

**Quick Revision:** Functions return values and are embedded in SQL; procedures manage transactions and are called standalone; both add operational burden in microservices.

---

## Topic 13: SQL Anti-patterns

**Difficulty:** Medium | **Frequency:** High | **Companies:** Google, Meta, Airbnb, Netflix, Coinbase

**Q:** What are the most common SQL anti-patterns and how do you detect and fix them in a production system?

**Short Answer:**
The most damaging anti-patterns are `SELECT *`, N+1 queries, unnecessary DISTINCT, implicit type conversions that prevent index use, and calling functions on indexed columns in WHERE clauses. Most are detectable via `EXPLAIN ANALYZE` and slow query logs.

**Deep Explanation:**

**1. SELECT \***
- Fetches all columns including large TEXT/JSONB blobs that may not be needed.
- Breaks application code silently when columns are added/removed.
- Prevents index-only scans (the planner cannot satisfy `SELECT *` from an index alone unless it covers every column).
- Fix: always name the columns you need.

**2. N+1 Query Problem**
- Application executes one query to fetch N parent rows, then N more queries for children.
- Example: fetch 100 orders, then 100 separate queries for each order's items.
- Total: 101 queries instead of 1 JOIN.
- Fix: JOIN or subquery to fetch everything at once; or use `WHERE id = ANY($1)` with an array of IDs.

**3. Unnecessary DISTINCT**
- Often added to suppress duplicates caused by a bad JOIN, masking the real bug.
- Forces a deduplication step (sort or hash) over the entire result.
- Fix: fix the JOIN cardinality; use EXISTS/IN instead of JOIN when you only need a boolean.

**4. Implicit Type Conversion**
- `WHERE user_id = '123'` when `user_id` is BIGINT — PostgreSQL casts the literal, but `WHERE created_at = NOW()` when `created_at` is DATE vs TIMESTAMP may cause full scans.
- Most dangerous: `WHERE CAST(created_at AS DATE) = '2024-01-01'` — the function on the left prevents index use.
- Fix: ensure literal types match column types; use range predicates: `WHERE created_at >= '2024-01-01' AND created_at < '2024-01-02'`.

**5. Function on Indexed Column**
- `WHERE LOWER(email) = 'user@example.com'` prevents use of the index on `email`.
- Fix: create a functional index: `CREATE INDEX ON users (LOWER(email))` and query with the same expression.

**6. OR instead of UNION (in some cases)**
- `WHERE col1 = 1 OR col2 = 2` often prevents index use on either column.
- Fix: `SELECT ... WHERE col1 = 1 UNION SELECT ... WHERE col2 = 2`.

**7. OFFSET for pagination**
- `OFFSET 10000 LIMIT 20` scans and discards 10,000 rows.
- Fix: keyset/cursor pagination: `WHERE id > last_seen_id ORDER BY id LIMIT 20`.

**Real-World Example:**
A Django ORM application fetches a list of blog posts and then accesses `post.author` for each — triggering N+1 queries. Using `select_related('author')` in Django (which generates a JOIN) reduces 201 queries to 1. In raw SQL the same fix is a simple JOIN.

**Code Example:**
```sql
-- ANTI-PATTERN: SELECT *
SELECT * FROM orders WHERE user_id = 42;

-- FIX: name your columns
SELECT id, status, amount, created_at FROM orders WHERE user_id = 42;

-- ANTI-PATTERN: N+1 (conceptually — shown as two queries)
-- Query 1: SELECT id FROM orders WHERE user_id = 42;  -> [1, 2, 3, ...]
-- Query 2-N: SELECT * FROM order_items WHERE order_id = 1;
--            SELECT * FROM order_items WHERE order_id = 2; ...

-- FIX: single JOIN
SELECT o.id, o.amount, oi.product_id, oi.quantity
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.user_id = 42;

-- Or batch: WHERE order_id = ANY(ARRAY[1,2,3,...])

-- ANTI-PATTERN: function on indexed column
SELECT * FROM users WHERE LOWER(email) = 'alice@example.com';
-- index on email is NOT used

-- FIX option 1: functional index
CREATE INDEX idx_users_lower_email ON users (LOWER(email));
SELECT * FROM users WHERE LOWER(email) = 'alice@example.com';  -- uses index now

-- FIX option 2: store the normalized value
-- ALTER TABLE users ADD COLUMN email_lower TEXT GENERATED ALWAYS AS (LOWER(email)) STORED;
-- CREATE INDEX ON users(email_lower);

-- ANTI-PATTERN: implicit type conversion killing index
-- user_id is BIGINT, but:
SELECT * FROM orders WHERE user_id = '42';  -- cast happens, index may still work in PG
-- More dangerous:
SELECT * FROM events WHERE DATE(created_at) = '2024-01-01';  -- function on column = no index

-- FIX: range predicate
SELECT * FROM events
WHERE created_at >= '2024-01-01'
  AND created_at <  '2024-01-02';

-- ANTI-PATTERN: OFFSET pagination
SELECT id, title FROM posts ORDER BY created_at DESC OFFSET 50000 LIMIT 20;

-- FIX: keyset pagination
SELECT id, title FROM posts
WHERE created_at < '2024-03-15 10:00:00'  -- last seen value from previous page
ORDER BY created_at DESC
LIMIT 20;
```

**Follow-up Questions:**
1. How does the query planner decide when to use a sequential scan despite an index existing?
2. What is a "covering index" and how does it eliminate the N+1 problem at the storage layer?
3. How do you find N+1 queries in a production application without reading every ORM call?

**Common Mistakes:**
- Adding `DISTINCT` to fix a duplicate problem caused by a missing JOIN condition.
- Using `OFFSET` for API pagination, assuming it is equivalent to cursor pagination at scale.
- Creating an index on `(a, b)` but querying `WHERE b = ?` — the composite index is not used for leading column `b` alone in most cases.

**Interview Traps:**
- Not all functions on columns prevent index use — PostgreSQL can use functional indexes that exactly match the expression.
- `SELECT *` in a subquery that is never executed (e.g., `EXISTS (SELECT * FROM ...)`) is fine — the `*` is never evaluated.

**Quick Revision:** The deadliest anti-patterns are function-on-indexed-column (kills index), N+1 (kills throughput), and OFFSET pagination (kills at scale) — all fixable with schema or query changes.

---

## Topic 14: Query Plan Reading

**Difficulty:** High | **Frequency:** High | **Companies:** Google, Uber, Shopify, Datadog, Jane Street

**Q:** How do you use `EXPLAIN ANALYZE` to identify and fix a slow PostgreSQL query?

**Short Answer:**
`EXPLAIN` shows the planner's estimated cost and execution strategy; `EXPLAIN ANALYZE` actually runs the query and shows real row counts and timing. The key is to spot nodes where estimated rows diverge greatly from actual rows, or where a sequential scan appears on a large table.

**Deep Explanation:**

**EXPLAIN output structure:**
The plan is a tree of nodes, read bottom-up (innermost/indented nodes execute first). Each node shows:
- Node type (Seq Scan, Index Scan, Hash Join, etc.)
- `cost=startup..total` — planner's estimate in arbitrary units
- `rows=N` — estimated output rows
- `width=N` — estimated bytes per row

**EXPLAIN ANALYZE adds:**
- `actual time=startup..total` — real milliseconds
- `rows=N` — actual rows returned
- `loops=N` — how many times this node ran (matters for nested loops)

**Scan types:**
| Scan | When Used | Notes |
|---|---|---|
| Seq Scan | No usable index, or selectivity too low | Fast for small tables or full-table reads |
| Index Scan | High selectivity, index covers predicate | Random I/O; can be slow for many rows |
| Index Only Scan | All needed columns in the index | Fastest; no heap access |
| Bitmap Index Scan + Heap Scan | Medium selectivity | Batches random I/O into sequential |

**Join types:**
- **Nested Loop**: good for small outer sets; bad for large tables.
- **Hash Join**: builds hash table of smaller side; good for medium tables.
- **Merge Join**: requires sorted inputs; good for large sorted datasets.

**Cost estimation:**
- `seq_page_cost = 1.0` (baseline)
- `random_page_cost = 4.0` (default; lower on SSD: `ALTER SYSTEM SET random_page_cost = 1.1`)
- Planner uses table statistics from `ANALYZE` — stale stats = bad estimates = bad plans.

**Identifying problems:**
1. `rows=1 actual rows=50000` — statistics are stale; run `ANALYZE table_name`.
2. Seq Scan on a large table — missing index or low selectivity.
3. Nested loop with large outer set — force a hash join with `enable_nestloop = off` temporarily to test.
4. High `loops` value on an expensive inner node — the driving query returns too many rows.

**Real-World Example:**
A Uber-style ride query takes 3 seconds. `EXPLAIN ANALYZE` reveals a Seq Scan on a 50M-row `rides` table with `cost=0..2,000,000`. Adding a partial index on `(driver_id)` where `status = 'active'` reduces it to an Index Scan taking 4ms.

**Code Example:**
```sql
-- Basic EXPLAIN
EXPLAIN
SELECT u.name, COUNT(o.id)
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2024-01-01'
GROUP BY u.id, u.name;

-- EXPLAIN ANALYZE: actually executes the query
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.name, COUNT(o.id)
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2024-01-01'
GROUP BY u.id, u.name;

/*
Sample output interpretation:
HashAggregate  (cost=45231.00..45432.00 rows=20100 width=40)
               (actual time=2341.123..2356.789 rows=18200 loops=1)
  ->  Hash Join  (cost=8731.00..44231.00 rows=200000 width=32)
                 (actual time=234.123..1987.456 rows=220000 loops=1)
        Hash Cond: (o.user_id = u.id)
        ->  Seq Scan on orders o  (cost=0..25000.00 rows=800000 width=16)
                                   (actual time=0.123..987.456 rows=800000 loops=1)
        ->  Hash  (cost=8000.00..8000.00 rows=58480 width=24)
                  (actual time=201.234..201.234 rows=60100 loops=1)
              ->  Index Scan using idx_users_created_at on users u
                  (cost=0.43..8000.00 rows=58480 width=24)
                  (actual time=0.045..134.567 rows=60100 loops=1)
                  Index Cond: (created_at > '2024-01-01')

Key observations:
- Seq Scan on orders: 800K rows, 987ms — likely needs index on user_id
- estimated 200K join rows vs actual 220K — stats are reasonable
- HashAggregate estimated 20100 rows but actual 18200 — acceptable
*/

-- Fix: add index on orders.user_id
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders(user_id);

-- Refresh statistics
ANALYZE users;
ANALYZE orders;

-- Temporarily disable nested loop to test hash join performance
SET enable_nestloop = off;
EXPLAIN ANALYZE SELECT ...;
RESET enable_nestloop;

-- Tune random page cost for SSD storage
ALTER SYSTEM SET random_page_cost = 1.1;
SELECT pg_reload_conf();

-- Find the slowest queries via pg_stat_statements
SELECT query, calls, total_exec_time / calls AS avg_ms,
       rows / calls AS avg_rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

**Follow-up Questions:**
1. What does `BUFFERS` in `EXPLAIN (ANALYZE, BUFFERS)` show, and why is it useful?
2. How do you force PostgreSQL to use a specific index for testing?
3. What is the difference between `work_mem` and `shared_buffers` and how do they affect query plans?

**Common Mistakes:**
- Reading EXPLAIN output top-down — execution flows bottom-up (most-indented node first).
- Confusing `cost` units (arbitrary planner units) with milliseconds.
- Forgetting that `EXPLAIN ANALYZE` actually runs the query — do not run it on a destructive UPDATE/DELETE without wrapping in `BEGIN ... ROLLBACK`.

**Interview Traps:**
- A low `cost` estimate with a high actual time means stale statistics or an inaccurate cost model (e.g., `random_page_cost` set for HDD on an SSD server).
- Index Scan is not always faster than Seq Scan — for low-selectivity queries (returning >5-10% of rows), a Seq Scan is often faster due to sequential I/O prefetching.

**Quick Revision:** Read EXPLAIN ANALYZE bottom-up; seek large estimated vs actual row divergence (stale stats), Seq Scans on large tables (missing index), and high loop counts on expensive nodes.

---

## Topic 15: Common Interview SQL Problems

**Difficulty:** High | **Frequency:** Very High | **Companies:** Google, Amazon, Facebook, Microsoft, Goldman Sachs, Two Sigma

**Q:** Walk through the canonical SQL interview problems — Nth highest salary, duplicate detection, running totals, sequence gaps, and employee hierarchy.

**Short Answer:**
These problems test window functions, self-joins, CTEs, and recursive queries. Mastering them covers roughly 80% of SQL interview questions at FAANG-level companies.

**Deep Explanation:**

Each problem pattern appears repeatedly with minor variations. The key is recognizing which SQL feature maps to which pattern:
- Ranking → `DENSE_RANK()` window function
- Duplicates → `GROUP BY HAVING COUNT > 1` or `ROW_NUMBER()`
- Running totals → `SUM() OVER (ORDER BY ...)`
- Sequence gaps → self-join or `LAG()`
- Hierarchy → recursive CTE

**Real-World Example:**
These exact patterns appear in analytics dashboards (running totals for revenue), HR systems (employee hierarchy), data quality pipelines (duplicate detection), and financial reporting (sequence gap detection for missing transaction IDs).

**Code Example:**
```sql
-- ============================================================
-- PROBLEM 1: Nth Highest Salary
-- Find the 3rd highest distinct salary
-- ============================================================

-- Method 1: DENSE_RANK (preferred — handles ties correctly)
WITH ranked AS (
    SELECT
        employee_id,
        name,
        salary,
        DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
    FROM employees
)
SELECT employee_id, name, salary
FROM ranked
WHERE rnk = 3;

-- Method 2: Correlated subquery (classic, slower)
SELECT salary
FROM employees e1
WHERE 2 = (
    SELECT COUNT(DISTINCT salary)
    FROM employees e2
    WHERE e2.salary > e1.salary
);
-- Note: n=3 means "2 salaries are greater than this one"

-- Variation: Nth highest per department
WITH ranked AS (
    SELECT
        employee_id,
        name,
        department_id,
        salary,
        DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS dept_rnk
    FROM employees
)
SELECT * FROM ranked WHERE dept_rnk = 2;

-- ============================================================
-- PROBLEM 2: Duplicate Detection & Removal
-- ============================================================

-- Find duplicates (same email, multiple rows)
SELECT email, COUNT(*) AS cnt
FROM users
GROUP BY email
HAVING COUNT(*) > 1;

-- Find all duplicate rows with details
SELECT *
FROM users
WHERE email IN (
    SELECT email FROM users GROUP BY email HAVING COUNT(*) > 1
);

-- Keep one row per duplicate group (lowest id), delete rest
DELETE FROM users
WHERE id NOT IN (
    SELECT MIN(id)
    FROM users
    GROUP BY email
);

-- Modern approach with ROW_NUMBER
WITH dupes AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY email ORDER BY id) AS rn
    FROM users
)
DELETE FROM users
WHERE id IN (SELECT id FROM dupes WHERE rn > 1);

-- ============================================================
-- PROBLEM 3: Running Totals (Cumulative Sum)
-- ============================================================

-- Daily revenue running total
SELECT
    order_date,
    daily_revenue,
    SUM(daily_revenue) OVER (ORDER BY order_date
                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                             ) AS running_total
FROM (
    SELECT
        DATE(created_at) AS order_date,
        SUM(amount)       AS daily_revenue
    FROM orders
    WHERE status = 'completed'
    GROUP BY DATE(created_at)
) daily;

-- Running total per user
SELECT
    user_id,
    order_date,
    amount,
    SUM(amount) OVER (PARTITION BY user_id ORDER BY order_date) AS user_running_total
FROM orders
ORDER BY user_id, order_date;

-- Moving average (7-day)
SELECT
    order_date,
    daily_revenue,
    AVG(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS seven_day_avg
FROM daily_revenue_cte;

-- ============================================================
-- PROBLEM 4: Gaps in Sequences
-- Find missing order IDs in a sequence
-- ============================================================

-- Method 1: generate_series vs actual IDs
SELECT s.id AS missing_id
FROM generate_series(
    (SELECT MIN(id) FROM orders),
    (SELECT MAX(id) FROM orders)
) AS s(id)
LEFT JOIN orders o ON o.id = s.id
WHERE o.id IS NULL;

-- Method 2: LAG to find gaps
WITH ordered AS (
    SELECT
        id,
        LAG(id) OVER (ORDER BY id) AS prev_id
    FROM orders
)
SELECT
    prev_id + 1                 AS gap_start,
    id - 1                      AS gap_end,
    id - prev_id - 1            AS gap_size
FROM ordered
WHERE id - prev_id > 1;

-- Find date gaps (days with no orders)
WITH date_range AS (
    SELECT generate_series(
        MIN(DATE(created_at)),
        MAX(DATE(created_at)),
        INTERVAL '1 day'
    )::DATE AS day
    FROM orders
)
SELECT dr.day AS missing_day
FROM date_range dr
LEFT JOIN orders o ON DATE(o.created_at) = dr.day
WHERE o.id IS NULL;

-- ============================================================
-- PROBLEM 5: Employee Hierarchy (Recursive CTE)
-- Find all direct and indirect reports of a manager
-- ============================================================

-- employees table: (id, name, manager_id)
WITH RECURSIVE org_chart AS (
    -- Base case: the root manager
    SELECT id, name, manager_id, 0 AS depth, name::TEXT AS path
    FROM employees
    WHERE id = 1  -- starting manager

    UNION ALL

    -- Recursive case: join children
    SELECT e.id, e.name, e.manager_id,
           oc.depth + 1,
           oc.path || ' -> ' || e.name
    FROM employees e
    JOIN org_chart oc ON oc.id = e.manager_id
)
SELECT id, name, depth, path
FROM org_chart
ORDER BY path;

-- Count direct + indirect reports per manager
WITH RECURSIVE subordinates AS (
    SELECT id, manager_id FROM employees
    UNION ALL
    SELECT e.id, s.manager_id
    FROM employees e
    JOIN subordinates s ON s.id = e.manager_id
)
SELECT
    m.id,
    m.name,
    COUNT(s.id) AS total_reports
FROM employees m
JOIN subordinates s ON s.manager_id = m.id
GROUP BY m.id, m.name
ORDER BY total_reports DESC;

-- ============================================================
-- BONUS: Median Salary (no built-in MEDIAN in PostgreSQL)
-- ============================================================
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary) AS median_salary
FROM employees;

-- ============================================================
-- BONUS: Consecutive Logins (streak detection)
-- ============================================================
WITH daily_logins AS (
    SELECT DISTINCT user_id, DATE(login_at) AS login_date FROM logins
),
gaps AS (
    SELECT
        user_id,
        login_date,
        login_date - ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date)::INTEGER AS grp
    FROM daily_logins
)
SELECT user_id, grp, COUNT(*) AS streak_length,
       MIN(login_date) AS streak_start,
       MAX(login_date) AS streak_end
FROM gaps
GROUP BY user_id, grp
HAVING COUNT(*) >= 3  -- only streaks of 3+ days
ORDER BY streak_length DESC;
```

**Follow-up Questions:**
1. How would you find the median without `PERCENTILE_CONT`?
2. How do you prevent infinite recursion in a recursive CTE if the hierarchy data has a cycle?
3. How would you write the Nth highest salary query for all values of N at once (a full ranking)?

**Common Mistakes:**
- Using `RANK()` instead of `DENSE_RANK()` for Nth highest salary — `RANK()` skips numbers on ties.
- Forgetting `DISTINCT` in daily login deduplication before gap/streak analysis.
- Not adding a `WHERE depth < 100` guard in recursive CTEs for cycle protection.

**Interview Traps:**
- "What if there is no Nth salary?" — your query should return no rows (or NULL), not error. Test edge cases.
- `ROW_NUMBER()` restarts at 1 per partition; `RANK()` and `DENSE_RANK()` handle ties differently — know all three.

**Quick Revision:** Nth salary = DENSE_RANK; duplicates = GROUP BY HAVING or ROW_NUMBER PARTITION; running total = SUM OVER ORDER BY; gaps = generate_series LEFT JOIN; hierarchy = recursive CTE.

---

## Chapter 14 Cheat Sheet

### SQL JOIN Types Reference

| JOIN Type | Returns | NULL Side | Use When |
|---|---|---|---|
| `INNER JOIN` | Matching rows only | Neither | You need only matched data |
| `LEFT JOIN` | All left + matched right | Right | All left rows, optional right |
| `RIGHT JOIN` | All right + matched left | Left | All right rows, optional left |
| `FULL OUTER JOIN` | All rows from both | Either unmatched | Union of both sides |
| `CROSS JOIN` | Cartesian product | Neither | Generating combinations |
| `SELF JOIN` | Rows joined to same table | Depends | Hierarchy, comparisons within table |
| `LEFT ANTI JOIN` | Left rows with no match | Right is NULL | Find orphans; `WHERE right.id IS NULL` |
| `SEMI JOIN` | Left rows where match exists | N/A | Existence check; use `EXISTS` or `IN` |

---

### Window Function Reference

| Function | Description | Example |
|---|---|---|
| `ROW_NUMBER()` | Unique sequential number per partition | `ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC)` |
| `RANK()` | Rank with gaps on ties (1,1,3) | `RANK() OVER (ORDER BY salary DESC)` |
| `DENSE_RANK()` | Rank without gaps on ties (1,1,2) | `DENSE_RANK() OVER (ORDER BY salary DESC)` |
| `NTILE(n)` | Divide rows into n buckets | `NTILE(4) OVER (ORDER BY salary)` — quartiles |
| `LAG(col, n)` | Value from n rows before | `LAG(revenue, 1) OVER (ORDER BY month)` — previous month |
| `LEAD(col, n)` | Value from n rows after | `LEAD(revenue, 1) OVER (ORDER BY month)` — next month |
| `FIRST_VALUE(col)` | First value in window frame | `FIRST_VALUE(salary) OVER (PARTITION BY dept ORDER BY hire_date)` |
| `LAST_VALUE(col)` | Last value in window frame | Requires `ROWS BETWEEN ... AND UNBOUNDED FOLLOWING` |
| `NTH_VALUE(col, n)` | Nth value in window frame | `NTH_VALUE(salary, 2) OVER (...)` |
| `SUM(col) OVER (...)` | Running/partitioned sum | `SUM(amount) OVER (PARTITION BY user_id ORDER BY date)` |
| `AVG(col) OVER (...)` | Running/partitioned average | `AVG(salary) OVER (PARTITION BY department_id)` |
| `COUNT(*) OVER (...)` | Running/partitioned count | `COUNT(*) OVER (PARTITION BY dept)` |
| `PERCENT_RANK()` | Relative rank 0.0 to 1.0 | `PERCENT_RANK() OVER (ORDER BY salary)` |
| `CUME_DIST()` | Cumulative distribution 0.0 to 1.0 | `CUME_DIST() OVER (ORDER BY salary)` |

**Frame Clause Reference:**
```sql
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW  -- running total
ROWS BETWEEN 6 PRECEDING AND CURRENT ROW           -- 7-row rolling window
ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING   -- reverse running total
RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW  -- time-based
```

---

### SQL Execution Order (Visual)

```
Query writing order:          Execution order:
1. SELECT                     1. FROM
2. FROM                       2. JOIN ... ON
3. JOIN                       3. WHERE
4. WHERE                      4. GROUP BY
5. GROUP BY                   5. HAVING
6. HAVING                     6. SELECT (window functions here)
7. ORDER BY                   7. DISTINCT
8. LIMIT / OFFSET             8. ORDER BY
                              9. LIMIT / OFFSET
```

**Key implications:**
- You cannot reference a `SELECT` alias in `WHERE` (alias does not exist yet at that stage).
- You CAN reference a `SELECT` alias in `ORDER BY` (PostgreSQL extension — not all DBs allow this).
- `WHERE` filters before grouping; `HAVING` filters after grouping.
- Window functions execute after `WHERE`, `GROUP BY`, and `HAVING` but before `ORDER BY`.

---

### Most-Asked Interview SQL Patterns

| Problem | Pattern | Key Clause/Function |
|---|---|---|
| Nth highest value | Ranking with DENSE_RANK | `DENSE_RANK() OVER (ORDER BY col DESC)` |
| Top N per group | Partition ranking | `ROW_NUMBER() OVER (PARTITION BY grp ORDER BY col DESC)` |
| Duplicate rows | Group and count | `GROUP BY cols HAVING COUNT(*) > 1` |
| Remove duplicates | Partition + delete | `ROW_NUMBER() OVER (PARTITION BY cols ORDER BY id)` |
| Running total | Cumulative sum | `SUM(col) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING)` |
| Moving average | Rolling window | `AVG(col) OVER (ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)` |
| Year-over-year change | LAG | `col - LAG(col, 12) OVER (ORDER BY month)` |
| Gaps in sequence | generate_series LEFT JOIN | `LEFT JOIN ... WHERE right.id IS NULL` |
| Consecutive events | Island detection | `date - ROW_NUMBER() OVER (...) AS grp` |
| Tree/hierarchy | Recursive CTE | `WITH RECURSIVE cte AS (base UNION ALL recursive)` |
| Pivot (rows to cols) | Conditional aggregation | `SUM(amount) FILTER (WHERE category = 'X')` |
| Median | Percentile | `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY col)` |
| Most recent per group | ROW_NUMBER or DISTINCT ON | `DISTINCT ON (group_col) ORDER BY group_col, date DESC` |
| Exists vs count | Semi-join | `WHERE EXISTS (SELECT 1 FROM ... WHERE ...)` |
| Self-referential join | Self join | `JOIN table alias ON alias.id = table.parent_id` |
| Ratio to total | Window aggregate | `col / SUM(col) OVER ()` |

---

### Quick Index — Both Parts of Chapter 14

| Topic | Part | Core Concept |
|---|---|---|
| 1. SELECT & Filtering | A | WHERE, LIKE, NULL handling |
| 2. JOINs | A | INNER/LEFT/FULL OUTER, anti-joins |
| 3. GROUP BY & HAVING | A | Aggregation pipeline |
| 4. Subqueries | A | Correlated vs uncorrelated, EXISTS |
| 5. Indexes | A | B-tree, composite, partial, covering |
| 6. Window Functions | A | OVER, PARTITION BY, frame clause |
| 7. CTEs | A | WITH, recursive, performance |
| 8. Query Optimization | A | Statistics, join order, index hints |
| 9. Aggregate Functions | B | COUNT vs COUNT(col), DISTINCT cost |
| 10. Transactions | B | ACID, isolation levels, MVCC |
| 11. Views & Mat. Views | B | Storage, REFRESH CONCURRENTLY |
| 12. Stored Procedures | B | Function vs procedure, avoid in microservices |
| 13. SQL Anti-patterns | B | SELECT *, N+1, function on index |
| 14. Query Plan Reading | B | EXPLAIN ANALYZE, scan types |
| 15. Interview Problems | B | Salary ranking, gaps, hierarchy |

---

*End of Chapter 14, Part B — SQL for Backend Engineers*
*Volume 4: Databases | Backend Interview Handbook*



