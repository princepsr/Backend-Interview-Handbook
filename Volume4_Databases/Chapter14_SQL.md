# Volume 4: Databases
# Chapter 14: SQL

---

## Table of Contents

1. SQL Joins
2. Subqueries and CTEs
3. Window Functions
4. GROUP BY and HAVING
5. SQL Execution Order
6. UNION vs UNION ALL vs INTERSECT vs EXCEPT
7. NULL Handling
8. String and Date Functions

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: SQL Joins

---

#### The Idea

Imagine you have two filing cabinets. One holds customer records, the other holds order records. Each order has a customer ID written on it. A JOIN is the act of pulling matching files from both cabinets and laying them side by side on a desk so you can read them together. The customer ID is the bridge between the two cabinets.

The type of join decides what you do when a file in one cabinet has no match in the other. An INNER JOIN means you only keep pairs — anything without a partner gets discarded. A LEFT JOIN means you keep everything from the left cabinet regardless, and leave the right-side fields blank (NULL) where there is no match.

The four outer join variants cover every combination of "who gets to stay even without a partner." Understanding which rows each variant keeps — and which rows get NULL-filled — is the single most tested join concept in backend interviews.

---

#### How It Works

```
JOIN type decision logic:

INNER JOIN   → keep row only if match found on BOTH sides
LEFT JOIN    → keep ALL rows from left table; right side = NULL if no match
RIGHT JOIN   → keep ALL rows from right table; left side = NULL if no match
FULL OUTER   → keep ALL rows from BOTH tables; unmatched side = NULL
CROSS JOIN   → every row in left paired with every row in right (Cartesian product)
```

**Visual reference — given customers (C) and orders (O):**

| Join Type | Customers with orders | Customers without orders | Orders without a customer |
|---|---|---|---|
| `INNER JOIN` | Yes | No | No |
| `LEFT JOIN` (C left) | Yes | Yes (NULLs on right) | No |
| `RIGHT JOIN` (O right) | Yes | No | Yes (NULLs on left) |
| `FULL OUTER JOIN` | Yes | Yes (NULLs on right) | Yes (NULLs on left) |
| `CROSS JOIN` | N/A — every combo | N/A | N/A |

**Must-memorise gotcha — WHERE vs ON in a LEFT JOIN:**

Putting a filter in ON keeps it a LEFT JOIN. Putting the same filter in WHERE silently converts it to an INNER JOIN, because WHERE runs after the join and discards the NULL-filled rows that the LEFT JOIN produced.

```sql
-- LEFT JOIN preserved — ON filter applies during the join
SELECT c.name, o.total
FROM customers c
LEFT JOIN orders o
  ON c.id = o.customer_id
 AND o.status = 'COMPLETED';   -- customers with no completed orders still appear, o.* = NULL

-- Accidentally becomes INNER JOIN — WHERE discards the NULL rows
SELECT c.name, o.total
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.status = 'COMPLETED';  -- customers with no completed orders are gone
```

The rule: filter conditions that belong to the right table go in ON if you want a true LEFT JOIN. WHERE-clause filters run after the join and eliminate the NULLs that made it a LEFT JOIN in the first place.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between an INNER JOIN and a LEFT JOIN?"**

**One-line answer:** INNER JOIN returns only rows that match in both tables; LEFT JOIN returns all rows from the left table and fills unmatched right-side columns with NULL.

**Full answer to give in an interview:**

> "An INNER JOIN acts like a filter — it only keeps rows where the join condition is satisfied on both sides. If a customer has no orders, they disappear from the result. A LEFT JOIN keeps every row from the left table regardless of whether a match exists on the right. When there is no match, the database fills every column from the right table with NULL. This is useful when you want a complete list — for example, all customers and their orders if any — rather than only customers who happen to have placed an order. The practical difference shows up constantly: if you're trying to find customers with no orders, you do a LEFT JOIN and then filter WHERE right_table.id IS NULL, which is called an anti-join pattern. With an INNER JOIN you'd never see those customers at all."

> *Draw the Venn diagram mentally: INNER is the overlap, LEFT is the entire left circle.*

**Gotcha follow-up they'll ask:** *"You added a WHERE clause filtering the right table after a LEFT JOIN. Did you just accidentally turn it into an INNER JOIN?"*

> "Yes, exactly — that's one of the most common silent bugs in SQL. When you do a LEFT JOIN, customers with no orders appear in the result with NULL in every orders column. If you then add WHERE orders.status = 'COMPLETED', that condition evaluates to false for NULL rows (because NULL compared to anything is neither true nor false in SQL's three-valued logic), so those rows are eliminated. The result is identical to an INNER JOIN. The fix is to move the condition from WHERE into the ON clause: AND orders.status = 'COMPLETED'. That way the filter applies during the join, not after, and NULL-filled rows from the left table survive."

---

##### Q2 — Tradeoff Question
**"When would you use a FULL OUTER JOIN, and when would you use a CROSS JOIN?"**

**One-line answer:** FULL OUTER JOIN is for merging two data sources where either side may have unmatched rows; CROSS JOIN is for intentionally generating every possible combination.

**Full answer to give in an interview:**

> "A FULL OUTER JOIN is the union of a LEFT and a RIGHT join — you keep every row from both tables and NULL-fill where there is no match. The classic use case is reconciling two datasets: say you have orders from system A and orders from system B and you want to find records that exist in one but not the other. A FULL OUTER JOIN gives you all rows from both, and you can then filter WHERE a.id IS NULL OR b.id IS NULL to find the discrepancies. A CROSS JOIN is completely different — it produces the Cartesian product, meaning every row in the left table is paired with every row in the right table. If left has 100 rows and right has 50, you get 5,000 rows. That sounds like a footgun, and it usually is if done accidentally, but it's legitimate when you genuinely need all combinations — generating a test matrix of sizes and colors, or building a calendar scaffold by crossing a list of users with a list of dates. The danger is forgetting a join condition and writing an implicit CROSS JOIN by accident, which explodes the result set."

> *Mention the accidental CROSS JOIN — interviewers love testing whether you know this footgun.*

---

##### Q3 — Design Scenario
**"How would you find all customers who have never placed an order?"**

**One-line answer:** LEFT JOIN orders to customers, then filter WHERE orders.id IS NULL — this is the anti-join pattern.

**Full answer to give in an interview:**

> "There are two clean approaches. The first is the anti-join using LEFT JOIN: select all customers, left-join to orders on customer ID, then add WHERE orders.id IS NULL. Because a LEFT JOIN keeps all customers and fills order columns with NULL for those who have no orders, the WHERE clause isolates exactly those customers. The second approach is EXISTS with NOT: SELECT * FROM customers WHERE NOT EXISTS (SELECT 1 FROM orders WHERE orders.customer_id = customers.id). This is semantically clearer and often performs identically, though the query planner may choose different strategies. I'd avoid NOT IN with a subquery here because if the orders table ever contains a NULL customer_id — even one row — NOT IN returns no results at all, due to SQL's three-valued logic. That silent failure is a known trap."

> *If they push on performance: both approaches are typically index-scannable; prefer NOT EXISTS when in doubt for clarity.*

---

> **Common Mistake — Filter placement in outer joins:** Putting a right-table filter in WHERE instead of ON silently converts a LEFT JOIN to an INNER JOIN and drops all the NULL rows you wanted to keep.

---

**Quick Revision (one line):**
INNER = matched rows only; LEFT = all left rows, NULLs on right; move right-table filters to ON or you lose the outer join.

---

## Topic 2: Subqueries and CTEs

---

#### The Idea

A subquery is a query nested inside another query — like a question whose answer is used to answer a bigger question. "Which customers spent more than the average?" requires knowing the average first, so you ask that as an inner question, then use the result to filter in the outer question. The database evaluates the inner query and hands the result to the outer query as if it were a table or a value.

A CTE (Common Table Expression), written as `WITH name AS (...)`, is a named subquery that sits at the top of a statement. Think of it as a scratch-pad table you define before the main query. It makes complex queries readable by giving meaningful names to intermediate results, and it prevents you from copy-pasting the same subquery in multiple places.

A recursive CTE is a CTE that references itself. It starts with a base case (the starting point) and a recursive step (how to move one level deeper), and the database repeats the recursive step until no new rows are produced. This is how you walk a tree or hierarchy — an employee-manager chain, a folder structure, a bill of materials — in a single SQL statement.

---

#### How It Works

```
Subquery types:

Scalar subquery   → returns one value; used in SELECT or WHERE
  Example: WHERE salary > (SELECT AVG(salary) FROM employees)

Row subquery      → returns one row; rare
  
Table subquery    → returns a set of rows; used in FROM (derived table)
  Example: FROM (SELECT ...) AS sub

Correlated        → references outer query per row; re-executes for each outer row
  Expensive: O(n) executions
  Example: WHERE amount > (SELECT AVG(amount) FROM orders o2 WHERE o2.customer_id = o.customer_id)

Non-correlated    → independent of outer query; executed once
  Cheap: O(1) execution
  Example: WHERE status IN (SELECT status FROM valid_statuses)

CTE structure:
  WITH cte_name AS (
    <your subquery here>
  )
  SELECT ... FROM cte_name ...

Recursive CTE structure:
  WITH RECURSIVE cte_name AS (
    <anchor member>       -- base case, no self-reference
    UNION ALL
    <recursive member>    -- references cte_name, moves one step deeper
  )
  SELECT ... FROM cte_name
```

**Must-memorise gotcha — recursive CTE for org hierarchy traversal:**

```sql
-- employees(id, name, manager_id)
-- Find all direct and indirect reports under manager id = 1

WITH RECURSIVE org_chart AS (
    -- Anchor: start at the root manager
    SELECT id, name, manager_id, 0 AS depth
    FROM employees
    WHERE id = 1

    UNION ALL

    -- Recursive step: find each employee whose manager is already in the result
    SELECT e.id, e.name, e.manager_id, oc.depth + 1
    FROM employees e
    INNER JOIN org_chart oc ON e.manager_id = oc.id
    WHERE oc.depth < 100   -- termination guard against cycles in dirty data
)
SELECT id, name, depth
FROM org_chart
ORDER BY depth, name;
```

The anchor member runs once. The recursive member runs repeatedly, each time joining against the rows produced in the previous iteration. The database stops when the recursive step produces zero new rows, or when your depth guard fires.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between a correlated and a non-correlated subquery? Which is faster?"**

**One-line answer:** A non-correlated subquery runs once and its result is reused; a correlated subquery re-executes for every row in the outer query, making it O(n) and usually slow.

**Full answer to give in an interview:**

> "A non-correlated subquery has no reference to the outer query. The database runs it once, gets back a value or a set of rows, and then uses that result to evaluate the outer query. Something like WHERE status IN (SELECT code FROM valid_statuses) — the inner SELECT runs once, produces a set, and the outer query uses that set for every row it checks. A correlated subquery, on the other hand, references a column from the outer query. The database has to re-execute the inner query for each row the outer query processes. The classic example is finding each customer's orders that are above that customer's own average: WHERE amount > (SELECT AVG(amount) FROM orders WHERE customer_id = outer.customer_id). That inner SELECT runs once per customer row. For a million customers, that is a million subquery executions. The fix is usually to rewrite as a JOIN with a pre-aggregated subquery or a window function, which the planner can execute in a single pass. Correlated subqueries are not always avoidable, but in a hot path they are a performance red flag."

> *If asked to rewrite a correlated subquery: move the aggregation into a CTE or derived table, then JOIN.*

**Gotcha follow-up they'll ask:** *"What happens with NOT IN when the subquery can return a NULL?"*

> "This is one of SQL's nastiest traps. NOT IN uses three-valued logic. If the subquery returns even a single NULL, the NOT IN condition evaluates to UNKNOWN for every row — never TRUE — so the entire outer query returns zero rows. Silently. No error, no warning, just empty results. The fix is to use NOT EXISTS instead, which correctly handles NULLs, or to add WHERE subquery_col IS NOT NULL inside the subquery to guarantee no NULLs slip through."

---

##### Q2 — Tradeoff Question
**"When would you use a CTE versus a subquery, and is a CTE always materialized?"**

**One-line answer:** CTEs improve readability and allow reuse of a result in multiple places; whether they are materialized depends on the database version and whether you force it.

**Full answer to give in an interview:**

> "Functionally a CTE and a subquery are equivalent — both define a named intermediate result. CTEs win on readability: when a query has three or four intermediate steps, naming each one as a CTE makes the logic self-documenting, whereas deeply nested subqueries become unreadable quickly. CTEs also let you reference the same intermediate result multiple times without duplicating the subquery, which matters for correctness when the underlying data could change between executions. The materialization question is important for performance. In PostgreSQL prior to version 12, CTEs were always materialized — the database computed the CTE result once, stored it, and reused the stored copy. That meant the query planner could not push conditions from the outer query into the CTE, sometimes causing full scans. From PostgreSQL 12 onward, non-recursive CTEs are inlined by default, meaning the planner treats them like subqueries and can optimize across the boundary. You can force materialization with MATERIALIZED keyword if you want the old behavior — useful when the CTE is expensive and referenced many times."

> *This materialization nuance is a common senior-level follow-up.*

---

##### Q3 — Design Scenario
**"Walk me through how a recursive CTE works. When would you use one?"**

**One-line answer:** A recursive CTE has a base case and a recursive step joined by UNION ALL; the database iterates until no new rows are produced, making it the standard way to traverse hierarchical data in SQL.

**Full answer to give in an interview:**

> "A recursive CTE has two parts separated by UNION ALL. The anchor member is a regular SELECT that produces the starting rows — say, the root manager in an org chart. The recursive member is a SELECT that joins back against the CTE itself, effectively asking 'give me the rows one level deeper than what we already have.' The database runs the anchor once, then repeatedly runs the recursive member using the previous iteration's output as input, until the recursive member produces no new rows. You always need a termination guard — something like WHERE depth < 100 — because if your hierarchy data has a cycle (A manages B, B manages A), the recursion never terminates on its own. The canonical use cases are org charts, threaded comments, folder trees, bill-of-materials explosions, and any graph traversal where the depth is not known in advance. Prior to CTEs, you had to use application-side loops or stored procedures for this — a recursive CTE puts it all in one declarative statement."

> *Mention the cycle guard — interviewers specifically look for awareness of this failure mode.*

---

> **Common Mistake — NOT IN with nullable subqueries:** Using NOT IN when the subquery can return NULL causes the entire outer query to return zero rows silently, because SQL's three-valued logic makes NOT IN evaluate to UNKNOWN rather than TRUE.

---

**Quick Revision (one line):**
CTEs name intermediate results for readability; recursive CTEs traverse hierarchies with an anchor + recursive step; always add a depth guard to prevent infinite loops.

---

## Topic 3: Window Functions

---

#### The Idea

Imagine you have a spreadsheet of sales figures, one row per transaction. You want to add a column showing the running total up to each row, and another column showing each salesperson's rank within their region. With regular GROUP BY, you can compute totals or ranks, but you lose the individual transaction rows — they collapse into group summaries. Window functions let you have both: the individual rows stay intact, and each row gets a new column carrying the aggregate or ranking value computed across a relevant set of rows.

The "window" is the set of rows the function looks at when computing the value for the current row. You define the window with an OVER clause. You can partition the window by a column (like region, so each salesperson is ranked only against their own region), and you can order rows within the window (so the running total accumulates in date order). The database computes the window function independently for each row — it does not collapse anything.

Ranking functions — ROW_NUMBER, RANK, and DENSE_RANK — are the most interview-tested window functions. They all assign a position number to each row within a partition, but they differ in how they handle ties, which is the source of nearly every interview question about them.

---

#### How It Works

```
Window function anatomy:

  function_name(expression) OVER (
    PARTITION BY partition_col     -- divide rows into independent windows
    ORDER BY order_col             -- define row ordering within the window
    ROWS/RANGE BETWEEN ... AND ... -- optional: define the frame (subset of window)
  )

Frame defaults (when ORDER BY is present):
  RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  -- includes all rows from start of partition up to current row and all peers

Common frame: running total
  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  -- strict row-by-row, no peer grouping

ROWS vs RANGE:
  ROWS  → physical rows; CURRENT ROW means exactly this one row
  RANGE → logical range; CURRENT ROW means all rows with the same ORDER BY value
         This causes LAST_VALUE to return unexpected results unless you explicitly
         set ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
```

**Must-memorise gotcha — ROW_NUMBER vs RANK vs DENSE_RANK with ties:**

Given salaries: 100, 90, 90, 80

```sql
SELECT
    name,
    salary,
    ROW_NUMBER()   OVER (ORDER BY salary DESC) AS row_num,
    RANK()         OVER (ORDER BY salary DESC) AS rnk,
    DENSE_RANK()   OVER (ORDER BY salary DESC) AS dense_rnk
FROM employees;
```

| name | salary | ROW_NUMBER | RANK | DENSE_RANK |
|---|---|---|---|---|
| Alice | 100 | 1 | 1 | 1 |
| Bob | 90 | 2 | 2 | 2 |
| Carol | 90 | 3 | 2 | 2 |
| Dave | 80 | 4 | 4 | 3 |

- **ROW_NUMBER:** always unique, no ties — assigns arbitrary sequential numbers even to duplicates. Use when you need exactly one row per group (deduplication).
- **RANK:** ties get the same number, but the next rank skips. Bob and Carol are both rank 2; Dave jumps to rank 4 (not 3). Use when "positional gaps" matter.
- **DENSE_RANK:** ties get the same number, no gaps. Bob and Carol are both rank 2; Dave is rank 3. Use when you want the Nth distinct value (e.g. 3rd highest salary).

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is a window function and how does it differ from GROUP BY?"**

**One-line answer:** A window function computes an aggregate or ranking across related rows while keeping every individual row in the output; GROUP BY collapses rows into one summary row per group.

**Full answer to give in an interview:**

> "GROUP BY is destructive — it takes multiple rows and folds them into one summary row per group. After a GROUP BY, you can only SELECT the group-by columns and aggregate expressions; the individual row data is gone. Window functions are non-destructive. They compute a value across a set of related rows — the window — and attach that value as a new column on each individual row, which stays visible. The OVER clause defines the window: PARTITION BY splits the data into independent groups (like GROUP BY but without collapsing), and ORDER BY defines the ordering within each group. So you can simultaneously see each transaction's amount AND that transaction's running total AND that transaction's rank within its customer's purchase history — all in one row. The practical consequence is that window functions can only appear in SELECT and ORDER BY, never in WHERE or HAVING, because the window is computed after those filtering steps. If you need to filter on a window function result, you have to wrap the query in a subquery or CTE and filter on the outer query."

> *The WHERE restriction trips up many candidates — mention it proactively.*

**Gotcha follow-up they'll ask:** *"Can you use a window function in a WHERE clause? Why not?"*

> "No. SQL's logical execution order is: FROM, JOIN, WHERE, GROUP BY, HAVING, SELECT, ORDER BY. Window functions are evaluated during the SELECT step, after WHERE has already filtered rows. So at the time WHERE runs, the window function result does not yet exist. The workaround is to compute the window function in a CTE or subquery, then filter on the result in the outer query's WHERE clause."

---

##### Q2 — Tradeoff Question
**"Explain the difference between ROW_NUMBER, RANK, and DENSE_RANK. When would you pick each one?"**

**One-line answer:** ROW_NUMBER always produces unique integers; RANK gives ties the same rank and skips the next; DENSE_RANK gives ties the same rank without skipping — use DENSE_RANK for Nth-highest-value queries.

**Full answer to give in an interview:**

> "All three assign a sequential number to rows based on an ORDER BY within a window. They differ only in how they handle ties — rows with the same value in the ORDER BY column. ROW_NUMBER assigns completely arbitrary unique numbers regardless of ties: if Bob and Carol both earn 90, one arbitrarily gets 2 and the other gets 3. Use this when you need exactly one row per group, such as deduplication — pick the row with the lowest ROW_NUMBER and discard the rest. RANK gives both Bob and Carol the number 2, but then skips 3 and assigns Dave the number 4. The logic is: 'there are two people tied for second place, so there is no third place.' Use this when the positional gaps are meaningful — for example, sports leaderboards. DENSE_RANK also gives Bob and Carol both the number 2, but assigns Dave the number 3 — no gaps. Use this whenever you want to find the Nth distinct value. The 'find the third highest salary' problem requires DENSE_RANK: if you used RANK, you'd ask for rank 3, which skips when there are ties and you'd miss valid results."

> *The interview will almost certainly ask you to write the Nth highest salary query — lead with DENSE_RANK.*

---

##### Q3 — Design Scenario
**"Write a query to get the most recent order for each customer."**

**One-line answer:** Use ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC), then filter WHERE rn = 1 in an outer query.

**Full answer to give in an interview:**

> "The pattern is to use ROW_NUMBER partitioned by customer_id and ordered by created_at descending, which assigns 1 to the most recent order per customer. Then wrap it in a CTE or subquery and filter WHERE row_num = 1. I use ROW_NUMBER here rather than RANK or DENSE_RANK because I want exactly one row per customer even if two orders have the same timestamp — with RANK, tied timestamps would both get rank 1 and I'd return multiple rows per customer. If I actually want to return all orders tied for the latest timestamp, I'd switch to RANK and filter WHERE rn = 1. PostgreSQL also has DISTINCT ON (customer_id) ORDER BY customer_id, created_at DESC as a shorter syntax for this specific pattern, though it's PostgreSQL-specific."

> *Mentioning DISTINCT ON shows PostgreSQL depth — good signal in a backend interview.*

---

> **Common Mistake — RANK for Nth-highest queries:** Using RANK instead of DENSE_RANK for finding the Nth highest value causes wrong results when ties exist, because RANK skips rank numbers after a tie and the Nth rank may not exist even though the Nth distinct value does.

---

**Quick Revision (one line):**
Window functions add computed columns without collapsing rows; ROW_NUMBER = unique always, RANK = gaps after ties, DENSE_RANK = no gaps — use DENSE_RANK for Nth-value queries.

---

## Topic 4: GROUP BY and HAVING

---

#### The Idea

GROUP BY is the SQL equivalent of sorting items into buckets and then doing a count or sum per bucket. Imagine a cashier tallying receipts by customer: first they sort the receipts into piles, one pile per customer, then they add up each pile. GROUP BY does the sorting into piles; aggregate functions like COUNT, SUM, and AVG do the adding up. The result is one output row per pile (per unique combination of GROUP BY columns), not one row per original receipt.

Once the data is grouped, you often want to filter at the group level — "show me only customers who spent more than $1,000 in total." That filter cannot go in WHERE, because WHERE runs before any grouping happens and can only see individual receipt rows. HAVING is the clause designed for filtering after grouping. It runs after GROUP BY, so it can reference aggregate expressions like SUM(total_amount).

The logical execution order is the key to understanding every confusing error in GROUP BY queries: FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY. Knowing this order tells you exactly which aliases and aggregates are legal at each step, and why trying to reference a SELECT alias in WHERE causes an error.

---

#### How It Works

```
Logical execution order:

  1. FROM        → identify source tables
  2. JOIN        → apply join conditions
  3. WHERE       → filter individual rows (no aggregates allowed here)
  4. GROUP BY    → collapse rows into groups
  5. HAVING      → filter groups (aggregates allowed here)
  6. SELECT      → compute output columns and aliases
  7. ORDER BY    → sort (can reference SELECT aliases)
  8. LIMIT       → trim result

Consequence: SELECT aliases do not exist yet when WHERE runs.
  -- This fails:
  SELECT total_amount * 1.1 AS total_with_tax
  FROM orders
  WHERE total_with_tax > 100;   -- ERROR: column "total_with_tax" does not exist

  -- Fix: repeat the expression, or use a subquery/CTE
  WHERE total_amount * 1.1 > 100;

Rules:
  - In SELECT with GROUP BY: you can only reference GROUP BY columns or aggregates
  - WHERE: filters rows before grouping; no aggregate functions allowed
  - HAVING: filters groups after grouping; aggregate functions allowed
```

**Must-memorise gotcha — WHERE vs HAVING and execution order:**

```sql
SELECT
    customer_id,
    COUNT(*)           AS order_count,
    SUM(total_amount)  AS total_spend
FROM orders
WHERE status = 'COMPLETED'          -- Step 3: filter rows BEFORE grouping
                                    -- Only completed orders enter the groups
GROUP BY customer_id                -- Step 4: one group per customer
HAVING SUM(total_amount) > 1000.00  -- Step 5: discard groups where total <= 1000
                                    -- SUM(total_amount) is valid here; status alias is not
ORDER BY total_spend DESC;          -- Step 7: ORDER BY can use SELECT alias
```

The mistake candidates make: trying to write `HAVING status = 'COMPLETED'` (should be WHERE — it filters rows, not groups) or writing `WHERE SUM(total_amount) > 1000` (fails — aggregate not allowed in WHERE because grouping hasn't happened yet).

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between WHERE and HAVING?"**

**One-line answer:** WHERE filters individual rows before grouping; HAVING filters groups after aggregation — you need HAVING whenever the filter references an aggregate function.

**Full answer to give in an interview:**

> "The distinction comes directly from SQL's execution order. WHERE runs before GROUP BY, so it can only see individual row values. It cannot reference aggregate functions like COUNT or SUM because those values don't exist yet — the grouping hasn't happened. HAVING runs after GROUP BY, so it sees one row per group and can reference aggregate expressions. The practical rule is simple: if your filter is on a raw column value, it goes in WHERE. If it's on an aggregate result — 'customers with more than five orders', 'departments with average salary above 80,000' — it goes in HAVING. There is also a performance reason to prefer WHERE over HAVING when possible: WHERE reduces the number of rows before grouping, so fewer rows are grouped and aggregated. HAVING filters after all the aggregation work is done. If you can express a condition in WHERE, always do it there."

> *The performance point distinguishes a good answer from a great one.*

**Gotcha follow-up they'll ask:** *"Can you use a column alias defined in SELECT inside HAVING?"*

> "No, for the same execution order reason — SELECT runs after HAVING, so the alias doesn't exist yet when HAVING evaluates. You have to repeat the aggregate expression in HAVING. Some databases like MySQL let you reference SELECT aliases in HAVING as an extension, but standard SQL and PostgreSQL do not. ORDER BY is the one place where you can safely reference a SELECT alias, because ORDER BY runs last."

---

##### Q2 — Tradeoff Question
**"Why can't you use an aggregate function in a WHERE clause? What is the workaround?"**

**One-line answer:** WHERE runs before GROUP BY in SQL's execution order, so aggregate values don't exist yet; use HAVING for post-aggregation filtering, or wrap the aggregation in a subquery/CTE and filter in the outer WHERE.

**Full answer to give in an interview:**

> "The database processes SQL in a fixed logical order: FROM and JOIN first, then WHERE to filter individual rows, then GROUP BY to form groups, then HAVING to filter groups, then SELECT to project output columns. When WHERE runs, the GROUP BY step hasn't happened yet, so there are no groups and no aggregate values — asking for SUM(amount) in a WHERE clause is asking for something that does not yet exist. The first workaround is to use HAVING instead of WHERE, which works when you want to filter the groups themselves. The second workaround is to pre-aggregate in a subquery or CTE and then filter in the outer query's WHERE clause: WITH customer_totals AS (SELECT customer_id, SUM(total) AS total FROM orders GROUP BY customer_id) SELECT * FROM customer_totals WHERE total > 1000. This second form is useful when you want to join the aggregated result back to other tables, or when the condition is complex enough that HAVING alone is insufficient."

> *Showing both HAVING and the subquery workaround demonstrates you understand the constraint, not just the rule.*

---

##### Q3 — Design Scenario
**"Write a query to find customers who placed more than 3 orders and whose total spend exceeds $500, but only counting orders placed in 2024."**

**One-line answer:** Filter for 2024 orders in WHERE, group by customer, then apply both count and sum conditions in HAVING.

**Full answer to give in an interview:**

> "This query has two layers of filtering: a row-level filter on the date, which goes in WHERE before grouping, and group-level filters on the count and total, which go in HAVING after grouping. I write: SELECT customer_id, COUNT(*) AS order_count, SUM(total_amount) AS total_spend FROM orders WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01' GROUP BY customer_id HAVING COUNT(*) > 3 AND SUM(total_amount) > 500 ORDER BY total_spend DESC. The date filter in WHERE reduces the data set before any aggregation happens, which is more efficient than filtering in HAVING. Both conditions in HAVING use aggregate expressions, which is exactly what HAVING is for. I use COUNT(*) rather than COUNT(order_id) to count all rows including any with NULL values in other columns, and I use a half-open date range rather than YEAR() function on the column to keep the query index-friendly."

> *The index-friendly date range and COUNT(*) nuance are senior-level details worth mentioning.*

---

> **Common Mistake — Aggregate in WHERE:** Writing WHERE COUNT(*) > 3 causes an immediate syntax error in most databases; the fix is to move the condition to HAVING, which runs after GROUP BY and has access to aggregate values.

---

**Quick Revision (one line):**
WHERE filters rows before grouping, HAVING filters groups after aggregation — execution order is FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY.

---

## Topic 5: SQL Execution Order

---

#### The Idea

Imagine you are assembling a report from a filing cabinet. You do not start by writing the title — you first pull the folders (FROM), clip them together with related folders (JOIN), throw out irrelevant sheets (WHERE), sort the remaining sheets into piles by category (GROUP BY), discard piles that are too small (HAVING), and only then write the column headers and values you care about (SELECT). The report title (your alias) does not exist until you write it, so you cannot use it to decide which sheets to keep earlier in the process.

SQL works the same way. Every SELECT statement has a fixed logical pipeline: the database engine conceptually executes each clause in a specific order, and that order is the reason some things work and others produce errors. It does not matter how you physically type the query — the engine always processes it in the same sequence.

Understanding this order is not just trivia. It directly explains why `WHERE total > 100` fails when `total` is a SELECT alias, why aggregate functions cannot appear in a WHERE clause, and why window functions can operate on already-grouped rows. Once you have this mental model, an entire class of confusing SQL errors becomes immediately obvious.

---

#### How It Works

```
Logical execution pipeline:

1. FROM          — identify the base table(s)
2. JOIN (ON)     — combine tables; apply ON conditions; produce intermediate rows
3. WHERE         — filter individual rows
                   (no SELECT aliases — they do not exist yet)
                   (no aggregate functions — no groups exist yet)
4. GROUP BY      — collapse rows into groups by specified columns
5. HAVING        — filter groups
                   (aggregate functions OK; SELECT aliases still NOT OK in standard SQL)
6. SELECT        — evaluate expressions; assign aliases
7. DISTINCT      — remove duplicate rows from the SELECT output
8. Window funcs  — computed over the post-SELECT, post-GROUP result set
9. ORDER BY      — sort the result
                   (SELECT aliases ARE available here — SELECT already ran)
10. LIMIT/OFFSET — trim the final result set
```

The physical execution plan the database optimizer actually runs may differ — it might apply a filter early via an index — but the *logical* result is always as if these steps ran in order.

Key tradeoff: if you need to filter on a SELECT alias or an aggregate, you have two options — repeat the expression in WHERE/HAVING, or wrap the query in a CTE/subquery and filter in the outer query.

```sql
-- Must-memorise gotcha: alias in WHERE vs ORDER BY

-- FAILS — alias does not exist at the WHERE stage
SELECT total * 1.1 AS with_tax
FROM orders
WHERE with_tax > 100;           -- ERROR: column "with_tax" does not exist

-- FIX 1: repeat the expression
SELECT total * 1.1 AS with_tax
FROM orders
WHERE total * 1.1 > 100;

-- FIX 2: wrap in a CTE (alias is visible in the outer query's WHERE)
WITH priced AS (
    SELECT *, total * 1.1 AS with_tax FROM orders
)
SELECT * FROM priced WHERE with_tax > 100;

-- ORDER BY CAN use the alias — it runs after SELECT
SELECT total * 1.1 AS with_tax
FROM orders
ORDER BY with_tax DESC;         -- WORKS fine
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"In what order does SQL logically execute the clauses of a SELECT statement, and why does it matter?"**

**One-line answer:** FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → Window Functions → ORDER BY → LIMIT — this order determines which aliases and aggregates are available at each stage.

**Full answer to give in an interview:**

> "SQL processes a query in a fixed logical pipeline regardless of how you write it. It starts with FROM and JOIN to establish the full row set, then WHERE to filter individual rows before any grouping happens, then GROUP BY to collapse rows into groups, then HAVING to filter those groups — HAVING is where aggregate conditions like 'only groups with more than five rows' go. SELECT runs after all of that, which is where aliases get defined. DISTINCT and window functions run after SELECT. ORDER BY is near the end, which is why it can reference SELECT aliases — SELECT already ran. LIMIT is last of all.
>
> This matters practically because it explains two very common errors. First, if you write `WHERE total_spend > 100` and `total_spend` is a SELECT alias, you get a 'column does not exist' error — the alias hasn't been created yet at the WHERE stage. Second, `WHERE COUNT(*) > 5` fails with an 'aggregate not allowed in WHERE' error — aggregates do not exist until GROUP BY runs. The fix for the first case is to repeat the expression or use a CTE. The fix for the second is HAVING."

> *Keep the pipeline crisp — FROM through LIMIT in order. That alone scores full marks on most panel interviews.*

**Gotcha follow-up they'll ask:** *"Can you use a SELECT alias in HAVING?"*

> "Not in standard SQL — HAVING runs before SELECT in the logical pipeline, so aliases are not yet defined. However, MySQL is lenient and allows it as an extension. PostgreSQL and SQL Server do not. In portable SQL, you must either repeat the expression in HAVING or use a CTE. In interviews, state the standard behaviour and mention MySQL as a known exception."

---

##### Q2 — Tradeoff Question
**"Why can't you filter on a window function result in a WHERE clause?"**

**One-line answer:** Window functions execute after SELECT, which is after WHERE, so you cannot reference their output in WHERE — you must wrap the query in a CTE and filter in the outer query.

**Full answer to give in an interview:**

> "Window functions sit at step 8 in the logical pipeline — after GROUP BY, after SELECT, and well after WHERE which is step 3. So when WHERE is being evaluated, the window function result simply does not exist yet. If you write `WHERE RANK() OVER (ORDER BY salary DESC) <= 3`, the database returns an error because WHERE has no window function values to work with.
>
> The standard fix is a CTE or subquery: compute the window function in the inner query, then filter in the outer query's WHERE clause. For example: `WITH ranked AS (SELECT *, RANK() OVER (ORDER BY salary DESC) AS rnk FROM employees) SELECT * FROM ranked WHERE rnk <= 3`. This pattern comes up constantly in 'find the top N per group' interview problems."

> *Drawing the pipeline steps on paper during a whiteboard interview makes this answer very visual and memorable.*

---

##### Q3 — Design Scenario
**"A developer writes `SELECT customer_id, SUM(amount) AS total FROM orders WHERE total > 100 GROUP BY customer_id` and gets an error. How do you fix it?"**

**One-line answer:** Move the condition to HAVING, or repeat the expression in HAVING — WHERE runs before GROUP BY so the aggregate does not exist there.

**Full answer to give in an interview:**

> "There are two problems here that look like one. First, `total` is a SELECT alias, and WHERE runs before SELECT, so the alias does not exist at the WHERE stage. Second, even if you wrote `WHERE SUM(amount) > 100`, aggregates are not allowed in WHERE — they only exist after GROUP BY runs, which is step 4, while WHERE is step 3.
>
> The correct fix is to replace `WHERE total > 100` with `HAVING SUM(amount) > 100`. HAVING runs after GROUP BY, so the aggregate is available. HAVING is specifically designed for filtering on aggregated values. If you also have a non-aggregate filter — say, only look at orders from 2024 — that belongs in WHERE: `WHERE created_at >= '2024-01-01'`, because filtering early in WHERE reduces the number of rows that GROUP BY has to process, which is more efficient."

> *Bonus point: mention the performance reason to put non-aggregate filters in WHERE rather than HAVING.*

---

> **Common Mistake — Alias in HAVING:** Using a SELECT alias in HAVING fails in standard SQL because HAVING runs before SELECT. Always repeat the expression or use a CTE. MySQL silently allows it, but your code becomes non-portable.

---

**Quick Revision (one line):**
FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → Window Functions → ORDER BY → LIMIT; aliases only usable from ORDER BY onward; aggregates only usable from HAVING onward.

---

## Topic 6: UNION vs UNION ALL vs INTERSECT vs EXCEPT

---

#### The Idea

Imagine you have two printed lists of customer IDs — one from the US database and one from the EU database. If you want a single combined list, you can staple them together as-is (that is UNION ALL), or you can take the time to cross out every duplicate so each ID appears only once (that is UNION). The second approach costs more work — you have to compare every entry against every other entry. For a hundred rows it is trivial; for ten million rows, that deduplication step becomes expensive.

Now extend the analogy. INTERSECT gives you only the IDs that appear on *both* lists — the overlap. EXCEPT gives you the IDs on the first list that do not appear on the second — the leftovers. These are set algebra operations: union, intersection, and difference.

All four operations share one rule: the two queries must produce the same number of columns, and the columns must have compatible types. The column names in the result always come from the first query — the second query's column names are ignored.

---

#### How It Works

```
Set operator rules:
  - Both queries: same column count, compatible types
  - Result column names: taken from the FIRST query
  - ORDER BY: applies to the final combined result only (goes at the very end)
  - LIMIT on individual members: wrap in parentheses

UNION     = UNION ALL + DISTINCT on the full combined result
            cost: O(n log n) sort or O(n) hash to find duplicates
            use when: you genuinely need deduplication

UNION ALL = simple append, no extra pass
            cost: O(n) — just concatenation
            use when: data is known to be disjoint, or duplicates are acceptable

INTERSECT = rows present in BOTH result sets (all columns compared)
            equivalent to: INNER JOIN on all columns + DISTINCT
            use when: you want full-row equality across two queries

EXCEPT    = rows in the FIRST set that are NOT in the SECOND set
            (called MINUS in Oracle)
            equivalent to: LEFT JOIN anti-join on all columns
            use when: you want set difference without writing a self-join
```

Important NULL behaviour: UNION's deduplication treats NULL as equal to NULL. So two identical rows that contain NULL in the same column are collapsed into one row by UNION — even though `NULL = NULL` yields UNKNOWN in a WHERE clause. This asymmetry trips up experienced developers.

```sql
-- Must-memorise gotcha: UNION ALL vs UNION performance + NULL dedup behaviour

-- EXPENSIVE: deduplication pass on millions of rows
SELECT customer_id FROM us_customers
UNION
SELECT customer_id FROM eu_customers;

-- FAST: no dedup — correct when regions are disjoint
SELECT customer_id FROM us_customers
UNION ALL
SELECT customer_id FROM eu_customers;

-- NULL dedup: UNION collapses two identical NULL rows into one
-- (unlike WHERE col = NULL which always fails)
SELECT NULL AS val UNION SELECT NULL AS val;  -- returns ONE row: NULL
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between UNION and UNION ALL, and when would you choose one over the other?"**

**One-line answer:** UNION removes duplicates (costs an extra deduplication pass); UNION ALL keeps everything and is significantly faster — use UNION ALL whenever duplicates are acceptable or impossible.

**Full answer to give in an interview:**

> "UNION ALL simply appends the second result set to the first — it is a straight concatenation, O(n) in cost. UNION does the same concatenation but then runs a deduplication step, which requires either a hash aggregate or a sort over the combined result — O(n) or O(n log n). For small tables the difference is negligible, but on millions of rows UNION can be orders of magnitude slower.
>
> The rule I follow is: default to UNION ALL and only switch to UNION if you have a real requirement to deduplicate. Common cases where UNION ALL is correct: combining sales from different regional tables that use separate customer IDs, merging event logs from different sources, or building a multi-row report with one row per region. A case where UNION is actually needed: combining two queries that can legitimately return the same customer from both, and your downstream logic requires each customer to appear exactly once."

> *Lead with the performance reason — that is what interviewers at Amazon and Stripe are listening for.*

**Gotcha follow-up they'll ask:** *"Are two NULL values considered equal by UNION's deduplication?"*

> "Yes — and this surprises a lot of developers. In a WHERE clause, `NULL = NULL` yields UNKNOWN, so no row matches. But UNION's deduplication uses a different equality semantics where NULL is treated as equal to NULL. So if both queries return a row with NULL in the same column, UNION collapses them into a single row. UNION ALL, of course, keeps both."

---

##### Q2 — Tradeoff Question
**"When would you use INTERSECT or EXCEPT instead of a JOIN-based approach?"**

**One-line answer:** INTERSECT and EXCEPT are cleaner and more readable when you want set membership across entire rows; JOIN-based equivalents are often faster and give the optimizer more index-usage options.

**Full answer to give in an interview:**

> "INTERSECT returns rows that appear in both result sets, comparing all columns. EXCEPT returns rows in the first result that are absent from the second. They are expressive and concise — a compliance query like 'find accounts that are flagged but not yet reviewed' reads naturally as `SELECT account_id FROM flagged EXCEPT SELECT account_id FROM reviewed`. The intent is immediately clear.
>
> The tradeoff is performance. INTERSECT and EXCEPT, like UNION, require a deduplication step over the combined rows. A NOT EXISTS subquery or a LEFT JOIN anti-join can achieve the same result and gives the optimizer freedom to use indexes on the join columns. For small tables or one-off analytical queries I lean toward INTERSECT/EXCEPT for readability. For production queries on large tables I prefer NOT EXISTS or the LEFT JOIN anti-join pattern, and I check the query plan to confirm index usage."

> *Mentioning the NOT EXISTS and anti-join equivalents shows you know the patterns that actually matter in production.*

---

##### Q3 — Design Scenario
**"You need to find all users who placed an order in January but not in February. How would you write this, and what are the performance trade-offs?"**

**One-line answer:** Use EXCEPT for readable set-difference logic, or a LEFT JOIN anti-join for better optimizer control on large tables.

**Full answer to give in an interview:**

> "The cleanest expression is EXCEPT: `SELECT user_id FROM orders WHERE created_at >= '2024-01-01' AND created_at < '2024-02-01' EXCEPT SELECT user_id FROM orders WHERE created_at >= '2024-02-01' AND created_at < '2024-03-01'`. This reads exactly like the requirement — the set of January users minus the set of February users.
>
> For a large orders table I would consider the NOT EXISTS version: `SELECT DISTINCT o.user_id FROM orders o WHERE o.created_at >= '2024-01-01' AND o.created_at < '2024-02-01' AND NOT EXISTS (SELECT 1 FROM orders o2 WHERE o2.user_id = o.user_id AND o2.created_at >= '2024-02-01' AND o2.created_at < '2024-03-01')`. With an index on `(user_id, created_at)`, this can use an index seek per user rather than a full hash over the combined sets. In a real system I would run EXPLAIN ANALYZE on both and pick whichever produces the lower actual cost."

> *Showing you would check the query plan rather than assuming one approach is always faster demonstrates production-level thinking.*

---

> **Common Mistake — UNION when UNION ALL suffices:** Always ask whether the data can actually contain duplicates before using UNION. Paying the deduplication cost unnecessarily on a large table can turn a sub-second query into a multi-second one.

---

**Quick Revision (one line):**
UNION ALL is fastest (no dedup); UNION = UNION ALL + DISTINCT; INTERSECT = rows in both sets; EXCEPT = rows in first but not second; NULL equals NULL for set deduplication, unlike in WHERE.

---

## Topic 7: NULL Handling

---

#### The Idea

Most programming languages have binary logic: something is either true or false. SQL has three-valued logic: a condition can be TRUE, FALSE, or UNKNOWN. UNKNOWN arises whenever NULL — which represents a missing or inapplicable value — participates in a comparison. The database cannot say whether a missing value is equal to 5 or not equal to 5, because it simply does not know what the value is. So the comparison returns UNKNOWN.

The critical rule is: a row is included in the result only if the WHERE condition evaluates to TRUE. Rows where the condition evaluates to UNKNOWN are silently dropped — no error, no warning, just missing rows. This is the source of some of the hardest-to-debug data bugs in production SQL.

The practical consequence is that `WHERE col = NULL` will never match any row, ever, because `col = NULL` always yields UNKNOWN. To test for NULL, you must use `IS NULL` or `IS NOT NULL` — these are special operators designed specifically for the NULL case, and they return TRUE or FALSE, never UNKNOWN.

---

#### How It Works

```
Three-valued logic truth table:

AND:  TRUE  AND TRUE    = TRUE
      TRUE  AND FALSE   = FALSE
      TRUE  AND UNKNOWN = UNKNOWN
      FALSE AND UNKNOWN = FALSE   ← short-circuit: one FALSE makes AND false
      FALSE AND FALSE   = FALSE

OR:   TRUE  OR TRUE    = TRUE
      TRUE  OR FALSE   = TRUE
      TRUE  OR UNKNOWN = TRUE    ← short-circuit: one TRUE makes OR true
      FALSE OR UNKNOWN = UNKNOWN
      FALSE OR FALSE   = FALSE

NOT:  NOT TRUE    = FALSE
      NOT FALSE   = TRUE
      NOT UNKNOWN = UNKNOWN

WHERE clause: row included only if condition = TRUE
              rows where condition = UNKNOWN are silently excluded

NULL comparison rules:
  NULL = NULL     → UNKNOWN (not TRUE)
  NULL = 5        → UNKNOWN
  NULL <> 5       → UNKNOWN
  NULL IS NULL    → TRUE
  NULL IS NOT NULL → FALSE

Aggregate behaviour:
  SUM, AVG, MIN, MAX, COUNT(col) — all IGNORE NULLs
  COUNT(*) — counts every row including those with NULLs
  If ALL values are NULL: SUM/AVG/MIN/MAX return NULL (not 0)

NOT IN trap:
  WHERE id NOT IN (SELECT col FROM t)
  If the subquery returns even one NULL → entire NOT IN = UNKNOWN → zero rows returned
  Safe alternative: NOT EXISTS
```

```sql
-- Must-memorise gotcha: three-valued logic and IS NULL

-- WRONG — = NULL always yields UNKNOWN, returns ZERO rows, no error
SELECT * FROM orders WHERE discount_amount = NULL;

-- CORRECT — IS NULL returns TRUE for null rows
SELECT * FROM orders WHERE discount_amount IS NULL;

-- Dangerous NOT IN with NULLs — if any order has customer_id = NULL,
-- this returns an empty set even when it should return rows
SELECT id FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders);

-- Safe replacement: NOT EXISTS
SELECT c.id FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.id
);

-- COALESCE and NULLIF
SELECT
    product_id,
    COALESCE(discount_rate, 0.0)             AS effective_discount, -- NULL → 0
    total_revenue / NULLIF(units_sold, 0)    AS revenue_per_unit    -- divide-by-zero → NULL not ERROR
FROM product_sales;
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Explain three-valued logic in SQL. Why does `WHERE col = NULL` return no rows?"**

**One-line answer:** SQL has TRUE, FALSE, and UNKNOWN; any comparison involving NULL yields UNKNOWN; WHERE only passes rows that evaluate to TRUE, so `col = NULL` — which is always UNKNOWN — matches nothing.

**Full answer to give in an interview:**

> "Standard boolean logic has two values: true and false. SQL adds a third: UNKNOWN. UNKNOWN arises whenever NULL appears in a comparison. NULL means 'value not known,' so when you write `col = NULL`, the database cannot determine whether the missing value equals anything — it returns UNKNOWN. The WHERE clause's rule is strict: only rows where the condition is TRUE get included in the result. UNKNOWN rows are silently dropped.
>
> This means `WHERE discount = NULL` will never return any rows, ever, because the comparison is always UNKNOWN regardless of what discount actually contains. To test for the absence of a value you must use `IS NULL`, which is a special predicate that returns TRUE when the operand is NULL. Similarly, `WHERE discount != NULL` also returns nothing — not even rows where discount is not null — because `discount != NULL` is also UNKNOWN.
>
> The practical implication is that any time you write a NOT EQUAL condition on a nullable column, you must explicitly add `OR col IS NULL` if you want NULL rows included in the result."

> *Walk through the truth table briefly — TRUE/FALSE/UNKNOWN for AND and OR — if the interviewer seems to want more depth.*

**Gotcha follow-up they'll ask:** *"Does GROUP BY treat NULL values as equal to each other?"*

> "Yes, and this is a deliberate inconsistency in SQL that you need to know. In a WHERE clause, `NULL = NULL` is UNKNOWN, so two NULL rows do not match each other. But GROUP BY and DISTINCT treat all NULL values as belonging to the same group — multiple rows with NULL in the GROUP BY column are collapsed into a single group. The SQL standard explicitly specifies this behaviour for grouping. It is surprising but it is how every major database works."

---

##### Q2 — Tradeoff Question
**"What is the NOT IN NULL trap, and how do you avoid it?"**

**One-line answer:** If a subquery inside NOT IN returns even one NULL, the entire NOT IN evaluates to UNKNOWN for every outer row, silently returning an empty result set — use NOT EXISTS instead.

**Full answer to give in an interview:**

> "This is one of the most dangerous bugs in production SQL because it fails silently. The query `WHERE id NOT IN (SELECT customer_id FROM orders)` seems straightforward: find customers with no orders. But if any order has a NULL customer_id — say, from a data import that left the foreign key empty — then the subquery returns a set that includes NULL. The NOT IN check then expands to `id != 1 AND id != 2 AND ... AND id != NULL`. That last condition, `id != NULL`, yields UNKNOWN. And TRUE AND UNKNOWN is UNKNOWN. So every single outer row evaluates to UNKNOWN and is excluded. Zero rows returned, no error.
>
> The fix is NOT EXISTS: `WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id)`. NOT EXISTS works differently — it returns TRUE if the subquery returns zero rows, FALSE if it returns any rows. NULL customer_id rows in orders do not match the join condition `o.customer_id = c.id` (because NULL = c.id is UNKNOWN), so they do not cause the subquery to match, and the outer row is correctly included. Alternatively, clean the data: add a WHERE clause inside the subquery to exclude NULLs."

> *This question comes up at Google, Amazon, and Stripe. Knowing the mechanism — not just 'use NOT EXISTS' — is what separates strong candidates.*

---

##### Q3 — Concept Check
**"What do COALESCE and NULLIF do, and when would you use each?"**

**One-line answer:** COALESCE returns the first non-NULL value in a list (used for default values); NULLIF returns NULL when two values are equal (used to prevent divide-by-zero errors).

**Full answer to give in an interview:**

> "COALESCE takes any number of arguments and returns the first one that is not NULL, short-circuiting as soon as it finds a non-NULL value. The classic use case is default values: `COALESCE(preferred_name, first_name, 'Unknown')` — try preferred name first, fall back to first name, then to a literal string. It is also essential when you need aggregates to return zero instead of NULL: `COALESCE(SUM(amount), 0)` — because SUM of zero rows returns NULL, not 0.
>
> NULLIF takes exactly two arguments and returns NULL if they are equal, otherwise returns the first argument unchanged. Its primary use case is preventing divide-by-zero errors: `total_revenue / NULLIF(units_sold, 0)` — if units_sold is zero, NULLIF converts it to NULL, and dividing by NULL returns NULL rather than throwing a runtime error. Another use is normalising sentinel values: `NULLIF(status, 'UNKNOWN')` treats the string 'UNKNOWN' as a missing value by converting it to NULL, so downstream NULL-handling logic applies to it consistently."

> *Give the divide-by-zero example — it is concrete and interviewers remember it.*

---

> **Common Mistake — WHERE col = NULL:** Writing `= NULL` instead of `IS NULL` is an error that produces zero rows with no error message, making it very hard to debug. The database silently excludes every row because every comparison with NULL yields UNKNOWN.

---

**Quick Revision (one line):**
NULL comparisons yield UNKNOWN; use IS NULL not = NULL; NOT IN plus a subquery with NULLs returns an empty result — use NOT EXISTS; COALESCE for defaults; NULLIF to turn a value into NULL (e.g., prevent divide-by-zero); GROUP BY treats NULLs as equal.

---

## Topic 8: String and Date Functions

---

#### The Idea

Think of string and date functions as a formatting and arithmetic toolkit that runs inside the database, before results reach your application. Rather than pulling raw data into your application code and reformatting it there, you can ask the database to trim whitespace, extract substrings, round timestamps to the nearest month, or calculate the number of days between two dates — all in SQL. This keeps the data transformation close to the data, reduces the volume of bytes transferred, and makes the query self-documenting.

Dates in particular have a feature that makes database-side processing valuable: a timestamp like `2024-07-15 14:32:00` can be "truncated" to the month boundary `2024-07-01 00:00:00` using DATE_TRUNC, which lets you GROUP BY month without writing any date arithmetic in your application. EXTRACT pulls a single numeric component — the year, month, day, hour, or even the day of the week — out of a timestamp as a plain number.

The most common interview pitfall with these functions is applying them to an indexed column in a WHERE clause. `WHERE DATE_TRUNC('month', created_at) = '2024-01-01'` wraps the indexed column in a function, which prevents the database from using a range scan on the index. The fix is always to rewrite as a range: `WHERE created_at >= '2024-01-01' AND created_at < '2024-02-01'`.

---

#### How It Works

```
String function categories:

Case:         UPPER(s), LOWER(s)
Trim:         TRIM(s), LTRIM(s), RTRIM(s)
Length:       LENGTH(s)
Substring:    SUBSTRING(s, start, length)  — 1-indexed in SQL
              LEFT(s, n), RIGHT(s, n)
Search:       POSITION(sub IN s) — returns 1-indexed position, 0 if not found
Replace:      REPLACE(s, from_str, to_str)
Split:        SPLIT_PART(s, delimiter, n) — n-th part after splitting
Concatenate:  CONCAT(s1, s2, ...)         — NULL-safe (NULLs become empty string)
              s1 || s2                    — NULL propagates (NULL || 'x' = NULL)
Pattern:      LIKE (%), ILIKE (case-insensitive, PostgreSQL)
Format:       TO_CHAR(value, format_string)
              LPAD(s, total_len, pad_char)

Date/time types (PostgreSQL):
  DATE         — date only
  TIMESTAMP    — date + time, no timezone
  TIMESTAMPTZ  — date + time + timezone-aware (prefer this for user events)
  INTERVAL     — duration (e.g., INTERVAL '30 days')

Key date functions:
  NOW()                            — current TIMESTAMPTZ
  CURRENT_DATE                     — current DATE
  DATE_TRUNC(unit, ts)             — truncate to unit boundary
    units: second, minute, hour, day, week, month, quarter, year
    returns: TIMESTAMP at start of that period
    example: DATE_TRUNC('month', '2024-07-15') → '2024-07-01 00:00:00'

  EXTRACT(field FROM ts)           — extract numeric component
    fields: YEAR, MONTH, DAY, HOUR, DOW (day of week 0=Sun), EPOCH (unix seconds)
    example: EXTRACT(YEAR FROM NOW()) → 2026

  AGE(ts2, ts1)                    — returns INTERVAL between two timestamps
  Interval arithmetic: NOW() - INTERVAL '30 days'

Type casting:
  CAST(value AS type)              — SQL standard
  value::type                      — PostgreSQL shorthand (e.g., '2024-01-01'::DATE)
```

Tradeoff: CONCAT is NULL-safe (ignores NULLs in its arguments) but `||` propagates NULL — `'hello' || NULL` returns NULL. Always prefer CONCAT when any argument might be NULL.

```sql
-- Must-memorise gotcha: COALESCE vs NULLIF with concrete example,
-- and the SARGability trap for date functions

-- COALESCE: first non-NULL wins — use for default values
SELECT
    COALESCE(preferred_name, first_name, 'Unknown') AS display_name,
    COALESCE(SUM(amount), 0)                        AS total_safe  -- SUM returns NULL for zero rows
FROM customers;

-- NULLIF: returns NULL when val1 = val2 — use to prevent divide-by-zero
SELECT
    total_revenue / NULLIF(units_sold, 0)  AS revenue_per_unit,  -- 0 units → NULL not ERROR
    NULLIF(status, 'UNKNOWN')              AS clean_status        -- treat sentinel as NULL
FROM product_sales;

-- SARGability trap: wrapping an indexed column in a function kills index range scans
-- BAD — function applied to indexed column, index cannot be used for range scan
WHERE DATE_TRUNC('month', created_at) = '2024-01-01';

-- GOOD — rewrite as explicit range, index can scan from start to end date
WHERE created_at >= '2024-01-01'
  AND created_at <  '2024-02-01';
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is DATE_TRUNC and how does it differ from EXTRACT?"**

**One-line answer:** DATE_TRUNC rounds a timestamp down to a period boundary and returns a TIMESTAMP (useful for grouping); EXTRACT pulls out a single numeric component like year or month.

**Full answer to give in an interview:**

> "DATE_TRUNC takes a unit — second, minute, hour, day, week, month, quarter, year — and a timestamp, and returns a new TIMESTAMP truncated to the start of that unit. For example, `DATE_TRUNC('month', '2024-07-15 14:32:00')` returns `2024-07-01 00:00:00`. The result is still a timestamp, which means you can GROUP BY it directly: `GROUP BY DATE_TRUNC('month', created_at)` gives you one group per calendar month, and each group's key is the first instant of that month. This is the standard pattern for time-series aggregations.
>
> EXTRACT, by contrast, pulls a single numeric value out of a timestamp — `EXTRACT(MONTH FROM created_at)` returns 7 for July. It returns a number, not a timestamp. The difference matters for grouping: if you GROUP BY EXTRACT(MONTH, created_at), January 2023 and January 2024 end up in the same group because they both have month = 1. DATE_TRUNC avoids this because `2023-01-01` and `2024-01-01` are different timestamp values."

> *The 'same month across different years' trap is the exam-ready example that distinguishes the two functions clearly.*

**Gotcha follow-up they'll ask:** *"What does `DATE_TRUNC('week', '2024-07-03'::date)` return in PostgreSQL?"*

> "It returns 2024-07-01, which is a Monday. PostgreSQL uses ISO week conventions where weeks start on Monday. July 3, 2024 is a Wednesday, so the week boundary is July 1. This catches people out who assume weeks start on Sunday."

---

##### Q2 — Tradeoff Question
**"Why is `WHERE DATE_TRUNC('month', created_at) = '2024-01-01'` a performance problem, and how do you fix it?"**

**One-line answer:** Wrapping an indexed column in a function makes the expression non-SARGable — the database cannot use an index range scan and must evaluate the function on every row; rewrite as an explicit date range.

**Full answer to give in an interview:**

> "SARGable stands for Search ARGument ABLE — it means the predicate can use an index to seek directly to matching rows rather than scanning the whole table. When you write `WHERE DATE_TRUNC('month', created_at) = '2024-01-01'`, the database has to apply DATE_TRUNC to every value of created_at in the table before it can compare the result. Even if there is a perfectly good B-tree index on created_at, the index stores the raw timestamp values, not the truncated ones. The optimizer cannot use the index for a range scan.
>
> The fix is to rewrite the condition as a range that the index can satisfy: `WHERE created_at >= '2024-01-01' AND created_at < '2024-02-01'`. Now the predicate is directly against the indexed column with no function wrapping, and the optimizer can do an index range scan from the start of January to the start of February. This applies to any function wrapping — `WHERE YEAR(created_at) = 2024`, `WHERE UPPER(email) = 'FOO@BAR.COM'` — all prevent index use. The general rule is: keep the indexed column bare on one side of the comparison."

> *This comes up constantly at Amazon and Stripe. Knowing the term SARGable and the mechanism makes you sound senior.*

---

##### Q3 — Concept Check
**"What is the difference between CONCAT and the || operator for string concatenation, and when does it matter?"**

**One-line answer:** CONCAT treats NULL as an empty string (NULL-safe); `||` propagates NULL so any NULL input produces a NULL result — matters whenever any concatenated column can be NULL.

**Full answer to give in an interview:**

> "In PostgreSQL, `||` is the standard string concatenation operator: `'hello' || ' ' || 'world'` returns `'hello world'`. But if any operand is NULL — for example `first_name || ' ' || last_name` where last_name is NULL — the entire result is NULL. This silently drops the first name from your output whenever last name is missing.
>
> CONCAT handles NULL differently: it converts each NULL argument to an empty string before concatenating. So `CONCAT(first_name, ' ', last_name)` with a NULL last_name returns `'John '` rather than NULL. For building display names, email subjects, or any string from columns that might be NULL, CONCAT is the safer choice. If you want to skip NULL segments entirely — not even include the space — combine with COALESCE: `CONCAT(first_name, COALESCE(' ' || last_name, ''))` to conditionally include the space-plus-last-name only when last_name is not NULL."

> *Give the first_name + last_name example — every interviewer has encountered this bug in production.*

---

> **Common Mistake — Function on indexed column in WHERE:** Writing `WHERE DATE_TRUNC(...)` or `WHERE UPPER(col)` wraps the indexed column in a function, preventing index range scans and causing full table scans. Always rewrite as a range or store a pre-computed column with a functional index.

---

**Quick Revision (one line):**
DATE_TRUNC for timestamp grouping; EXTRACT for numeric components; COALESCE for NULL defaults; NULLIF to convert a value to NULL (divide-by-zero safety); CONCAT over `||` when columns may be NULL; never wrap an indexed column in a function in WHERE — rewrite as a range.
