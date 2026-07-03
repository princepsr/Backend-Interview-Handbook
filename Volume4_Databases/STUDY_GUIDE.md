# Volume 4: Databases — Study Guide

## Priority Order

| Chapter | Why | Time Budget |
|---|---|---|
| Ch16 ACID/Transactions | Isolation levels and deadlocks appear in almost every senior backend round | 75 min |
| Ch15 Indexing | EXPLAIN ANALYZE, composite index design, and covering indexes are tested constantly | 70 min |
| Ch17 Distributed DBs | CAP theorem, sharding, and consistent hashing are system design prerequisites | 60 min |
| Ch18 Advanced DB | Window functions, partitioning, replication lag — tested at data-heavy companies | 50 min |
| Ch14 SQL | Assumed known; focus on query optimization and window function practice | 30 min |

---

## 1-Week Plan (1 hr/day)

- **Day 1 — Ch16 ACID:** Four isolation levels (Read Uncommitted → Serializable), which anomaly each prevents, MVCC mechanics, optimistic vs pessimistic locking and when each wins, deadlock detection and prevention
- **Day 2 — Ch15 Indexing:** B-Tree structure and why range scans are fast, composite index column ordering rules, covering index (index-only scan), EXPLAIN ANALYZE — how to read rows vs actual rows, why a full scan beats an index on low-cardinality columns
- **Day 3 — Ch17 Distributed DBs:** CAP theorem with concrete examples (not just definitions), consistent hashing and virtual nodes, horizontal sharding strategies and hotspot problems, DynamoDB single-table design and partition key selection
- **Day 4 — Ch18 Advanced DB:** Window functions (ROW_NUMBER, RANK, LAG/LEAD, running totals), table partitioning (range vs list vs hash), replication lag causes and read-your-writes guarantees
- **Day 5 — Ch14 SQL:** Write and optimize 3-4 complex queries using CTEs + window functions, practice rewriting correlated subqueries as joins, identify N+1 patterns in ORM-generated SQL
- **Day 6 — Practice:** Given a schema (orders, products, users), identify missing indexes, write an EXPLAIN ANALYZE plan, fix an N+1 query, choose an isolation level for a checkout transaction
- **Day 7 — Vol6 Ch26 Revision:** Self-test on Q2 (isolation levels), Q5 (index design), Q8 (CAP tradeoffs), Q10 (window functions), Q13 (sharding hotspot)

---

## 3-Day Crash

- **Day 1 — Ch16 ACID + Ch15 Indexing:** The two highest-frequency DB topics; know anomalies by isolation level and be able to design a composite index given a query pattern
- **Day 2 — Ch17 Distributed DBs:** CAP, consistent hashing, sharding — you will not pass a system design round without these
- **Day 3 — Vol6 Ch26 Revision:** Run the 5 Q numbers above as a timed mock

---

## What Interviewers Test in DB Rounds

- They read EXPLAIN plans with you — they want to see you spot a seq scan where an index scan is expected and explain why it happened
- Isolation level questions always go beyond naming them: "your payment service runs at Read Committed — what anomaly are you still exposed to, and what does that mean for a double-spend scenario?"
- N+1 diagnosis: they show you JPA/Hibernate-generated SQL and ask why the app is slow under load — you need to spot the loop and know the fix (`JOIN FETCH`, `IN` clause, eager loading trade-offs)
- Index design is always given a specific query — not "explain B-Tree" but "here's a WHERE clause and ORDER BY, design the index and explain the column order"
- Sharding hotspot questions probe whether you understand that a monotonically increasing partition key (e.g., `created_at`, auto-increment ID) routes all writes to one shard

---

## Top 10 Database Questions

1. What are the four ACID isolation levels? Which anomaly does each prevent?
2. What is MVCC and how does Postgres use it to avoid read locks?
3. Two transactions deadlock — walk me through exactly what happened and how the DB resolves it
4. Given this query `WHERE status = 'active' AND created_at > ?`, design the optimal composite index and explain your column order
5. What is a covering index and when does it eliminate a table lookup entirely?
6. CAP theorem: can a distributed DB be both consistent and available during a partition? Give a real-world example of a CP vs AP choice
7. How does consistent hashing minimize resharding cost compared to modulo hashing?
8. What causes replication lag and how do you guarantee a user reads their own write from a replica?
9. Write a query using a window function to find the second-highest salary per department without a subquery
10. What is the N+1 problem? Show SQL evidence of it and fix it

---

## Common Mistakes

1. **"Just add an index"** — without considering write amplification, index cardinality, or whether the query planner will even use it at that selectivity
2. **Naming isolation levels without knowing the anomalies** — saying "use Serializable for safety" without explaining the throughput cost and deadlock risk
3. **CAP as a binary choice** — not explaining that most systems tune consistency vs availability per operation, not per system
4. **Sharding without hotspot awareness** — choosing `user_id` as a shard key without asking about the access pattern (celebrity users dominate traffic)
5. **EXPLAIN without ANALYZE** — EXPLAIN shows the plan; EXPLAIN ANALYZE runs it and shows actual vs estimated rows — the gap between them is where bugs hide
