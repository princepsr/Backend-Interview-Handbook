# Volume 4: Databases & Performance

**5 chapters · ~100+ Q&As · SQL · PostgreSQL · Cassandra · DynamoDB**

Databases are a dedicated interview round at most companies. This volume covers SQL fundamentals, index internals, transaction isolation, and distributed database design — the full range from "write a window function" to "design a sharding strategy for 10TB of order data."

---

## What's In This Volume

| Chapter | Topic | Interview Weight |
|---------|-------|-----------------|
| Ch 14 | SQL Deep Dive | **Very High** — window functions, CTEs, execution order |
| Ch 15 | Indexing & Query Optimization | **Very High** — B-tree internals, composite index column order, EXPLAIN |
| Ch 16 | ACID, Transactions & Normalization | High — MVCC, isolation levels, deadlock prevention |
| Ch 17 | Distributed Databases & Sharding | **Very High** — CAP theorem, consistent hashing, DynamoDB design |
| Ch 18 | Advanced DB Topics | High — connection pooling, zero-downtime migrations, read replicas |

---

## Study Plan for This Volume

### 4-Week Plan (Days 15–21 of Week 3)

| Day | Chapter | Focus |
|-----|---------|-------|
| Day 15 | Ch14 | Window functions (`ROW_NUMBER`, `RANK`, `LAG`), CTEs, SQL execution order |
| Day 16 | Ch15 | B-tree structure, composite index column ordering, `EXPLAIN ANALYZE` output reading |
| Day 17 | Ch16 | MVCC mechanics, isolation levels (Read Committed vs Repeatable Read vs Serializable), phantom reads |
| Day 18 | Ch17 | Consistent hashing with virtual nodes, Cassandra vs DynamoDB access patterns, CAP in practice |
| Day 19 | Ch18 | HikariCP pool sizing, online schema migration (pt-online-schema-change / pg_repack), read replica lag |
| Day 20 | Review | Ch26 (Databases Revision) |
| Day 21 | SQL practice | Write all 7 SQL patterns from Ch26 Section 6 from memory |

> After finishing this volume, validate with **Chapter 26** (Databases Revision) in the Revision Pack.

### Crash Plan (1 week total — Day 4 of 7)

Ch14 + Ch15 + Ch16. These three are tested at every company and every level. Ch17 (Distributed DBs) is essential for SDE2+ — add it if you're targeting Amazon or Google.

---

## Company Focus

### Amazon
- **Ch14/Ch15** — SQL proficiency expected even for DynamoDB-heavy roles; composite index design
- **Ch17** — DynamoDB is the key differentiator: GSI vs LSI, single-table design, hot partition avoidance
- Expect: "Design the DynamoDB schema for an order management system supporting queries by customer, by status, and by date range"

### Google
- **Ch17** — CAP theorem in practice, Spanner's external consistency model, consistent hashing with virtual nodes
- **Ch15** — Index selection reasoning — Google probes "why this index, what does the query planner see?"

### Goldman Sachs / FinTech
- **Ch16** — Transaction correctness is paramount: MVCC, `SELECT FOR UPDATE`, isolation level trade-offs for account balance updates
- **Ch14** — Window functions for trade P&L calculations, recursive CTEs for hierarchical position data
- Scenario: "Two concurrent transactions both try to debit the same account — walk through every possible outcome"

### Stripe / Payments
- **Ch16** — Idempotent DB writes: `INSERT ... ON CONFLICT DO NOTHING`, optimistic locking with version columns
- **Ch18** — Zero-downtime migration patterns for high-traffic payment tables (add column, backfill, then constraint)

---

## Key Concepts to Nail Cold

- **B-tree index:** balanced tree, O(log n) lookup, leaf nodes store actual row pointers. Composite index: leftmost prefix rule — `(a, b, c)` index supports queries on `a`, `(a, b)`, `(a, b, c)` but NOT `(b, c)` alone.
- **MVCC:** each transaction sees a snapshot of committed data at start time. Writers don't block readers. Old row versions kept in undo log / dead tuples until VACUUM.
- **Isolation levels:** Read Uncommitted → Read Committed → Repeatable Read → Serializable. Each higher level prevents more anomalies (dirty read, non-repeatable read, phantom read) at increasing lock cost.
- **Consistent hashing:** servers placed on a hash ring; a key maps to the nearest server clockwise. Virtual nodes (vnodes) distribute load evenly. Rebalancing moves only `K/n` keys on node add/remove.
- **DynamoDB access patterns:** design keys around your query patterns, not around entities. GSI enables alternate access patterns; LSI must be defined at table creation.
- **Connection pool sizing:** `pool_size = (core_count × 2) + effective_spindle_count` (HikariCP recommendation). Too large → DB CPU context switching; too small → thread starvation.

---

*Volume 4 of 6 · [Full Handbook](../../book_output/index.html)*
