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

- [Volume 4 Study Plan](STUDY_GUIDE.md) — 1-week plan, 3-day crash plan, top 10 questions, and daily practice tips.
- [Volume 4 Company Guide](COMPANY_GUIDE.md) — which companies go deep on Databases and what they specifically test.

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
