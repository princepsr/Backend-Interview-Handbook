# Volume 6: Interview Revision Pack
# Chapter 26: Databases — Quick Revision

> Last-day review. Dense bullets. SDE2 level. Scan, don't read.

---

## Section 1: SQL — Top 15 Questions

### Q1: JOIN Types
| Type | Returns |
|------|---------|
| INNER JOIN | Only matching rows from both sides |
| LEFT JOIN | All left rows + matched right (NULLs for no match) |
| RIGHT JOIN | All right rows + matched left (NULLs for no match) |
| FULL OUTER JOIN | All rows from both sides (NULLs where no match) |
| CROSS JOIN | Cartesian product (M × N rows), no ON clause |
| SELF JOIN | Table joined to itself (e.g., employee → manager) |

### Q2: SQL Execution Order (Logical)
```
FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT/OFFSET
```
- **Key:** WHERE runs before SELECT, so you cannot reference SELECT aliases in WHERE (use subquery or CTE)
- **Key:** HAVING filters after GROUP BY; use for aggregate conditions
- **Key:** Window functions execute after WHERE/GROUP BY but before ORDER BY/LIMIT

### Q3: Window Functions — ROW_NUMBER vs RANK vs DENSE_RANK
```sql
SELECT name, salary,
  ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn,
  RANK()       OVER (PARTITION BY dept ORDER BY salary DESC) AS rnk,
  DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC) AS drnk
FROM employees;
```
| Function | Ties handled | Gaps in sequence |
|----------|-------------|-----------------|
| ROW_NUMBER | Arbitrary order assigned | No gaps (1,2,3,4) |
| RANK | Same rank for ties | Gaps (1,1,3,4) |
| DENSE_RANK | Same rank for ties | No gaps (1,1,2,3) |

Other window functions: `LAG/LEAD`, `FIRST_VALUE/LAST_VALUE`, `SUM/AVG OVER (...)`, `NTILE(n)`

### Q4: CTE vs Subquery
- **CTE (WITH clause):** Named, readable, reusable within same query; in most DBs evaluated inline (not materialized) unless `MATERIALIZED` keyword used
- **Subquery:** Inline, can be correlated (references outer query), evaluated per outer row if correlated
- **When to prefer CTE:** Recursive queries, reusing same result set multiple times, readability
- **PostgreSQL:** `WITH x AS (MATERIALIZED (...))` forces materialization (one execution, result cached)

### Q5: UNION vs UNION ALL
- `UNION`: Removes duplicates (implicit DISTINCT + sort) — slower
- `UNION ALL`: Keeps all rows — faster, use when duplicates are acceptable or impossible
- Both require same number of columns with compatible types

### Q6: NULL Three-Valued Logic
- NULL comparisons return UNKNOWN, not TRUE or FALSE
- `NULL = NULL` → UNKNOWN (not TRUE)
- `NULL != NULL` → UNKNOWN
- Use `IS NULL` / `IS NOT NULL`
- In WHERE, only TRUE rows are kept; UNKNOWN is excluded

### Q7: NOT IN with NULLs Trap
```sql
-- If subquery returns any NULL, entire NOT IN returns no rows!
SELECT * FROM orders WHERE customer_id NOT IN (SELECT customer_id FROM blocked); -- TRAP if any NULL in blocked
-- Safe alternative:
SELECT * FROM orders WHERE NOT EXISTS (SELECT 1 FROM blocked WHERE blocked.customer_id = orders.customer_id);
-- Or:
SELECT * FROM orders WHERE customer_id NOT IN (SELECT customer_id FROM blocked WHERE customer_id IS NOT NULL);
```
- **Root cause:** `x NOT IN (1, NULL)` → `x != 1 AND x != NULL` → `x != 1 AND UNKNOWN` → UNKNOWN → row excluded

### Q8: GROUP BY vs HAVING
- `WHERE` filters rows before grouping
- `HAVING` filters groups after aggregation
- Cannot use aggregate functions in WHERE; must use HAVING
- Non-aggregated columns in SELECT must appear in GROUP BY (ANSI SQL) — MySQL has `sql_mode=only_full_group_by`

### Q9: COUNT(*) vs COUNT(col)
- `COUNT(*)` — counts all rows including NULLs
- `COUNT(col)` — counts non-NULL values in col
- `COUNT(DISTINCT col)` — counts distinct non-NULL values
- `SUM(col)` — ignores NULLs; `AVG(col)` — ignores NULLs (denominator is non-NULL count)

### Q10: Correlated Subquery
```sql
-- Returns employees earning more than their dept average
SELECT e.name, e.salary
FROM employees e
WHERE e.salary > (
  SELECT AVG(e2.salary) FROM employees e2 WHERE e2.dept = e.dept  -- references outer e.dept
);
```
- Executes once per outer row — O(N) subquery executions — often replaceable with window function for performance

### Q11: EXPLAIN Output — Key Nodes
| Node Type | Meaning |
|-----------|---------|
| Seq Scan | Full table scan — no index used |
| Index Scan | Uses index, fetches heap rows (random I/O) |
| Index Only Scan | Covering index — no heap fetch needed |
| Bitmap Heap Scan | Batches index lookups, then heap fetch — efficient for many rows |
| Hash Join | Build hash table on smaller side, probe with larger |
| Nested Loop | For each outer row, scan inner — good for small inner sets |
| Merge Join | Both sides sorted, merge — good for large sorted sets |

- Look for: high `rows` estimates vs actual, high `cost`, Seq Scan on large tables, Sort nodes

### Q12: Materialized View vs View
| | View | Materialized View |
|--|------|-------------------|
| Storage | No (virtual) | Yes (physical copy) |
| Always fresh | Yes | No (stale until refreshed) |
| Query speed | Depends on base tables | Fast (precomputed) |
| Refresh | N/A | `REFRESH MATERIALIZED VIEW` (PostgreSQL) |
| Use case | Abstraction, security | Expensive aggregations, dashboards |

PostgreSQL supports `REFRESH MATERIALIZED VIEW CONCURRENTLY` (requires unique index, no lock on reads).

### Q13: GROUPING SETS
```sql
-- Equivalent to multiple GROUP BYs UNION'd together
SELECT region, product, SUM(sales)
FROM sales_data
GROUP BY GROUPING SETS ((region, product), (region), (product), ());
-- () = grand total row
-- ROLLUP(region, product) = hierarchical: (region,product), (region), ()
-- CUBE(region, product) = all combinations: above + (product), ()
```

### Q14: LATERAL Join
```sql
-- LATERAL allows subquery to reference preceding FROM items
SELECT u.id, latest.created_at
FROM users u
CROSS JOIN LATERAL (
  SELECT created_at FROM orders o WHERE o.user_id = u.id ORDER BY created_at DESC LIMIT 1
) latest;
```
- Equivalent to correlated subquery but more flexible (can return multiple columns/rows)
- PostgreSQL supports; MySQL 8.0+ supports as LATERAL; SQL Server uses `CROSS APPLY`

### Q15: Recursive CTE
```sql
WITH RECURSIVE org_tree AS (
  -- Anchor: start node
  SELECT id, name, manager_id, 1 AS level FROM employees WHERE manager_id IS NULL
  UNION ALL
  -- Recursive: join to previous result
  SELECT e.id, e.name, e.manager_id, ot.level + 1
  FROM employees e
  JOIN org_tree ot ON e.manager_id = ot.id
)
SELECT * FROM org_tree;
```
- Termination: when recursive part returns no rows
- Add `WHERE level < 10` as safety guard for cycles

---

## Section 2: Indexing — Top 15 Questions

### Q1: B-tree Structure
- Balanced tree; O(log N) lookup, range scans
- Root → internal nodes → leaf nodes (contain key + pointer to heap row or row itself)
- Height typically 3-4 for millions of rows
- PostgreSQL default index type; MySQL InnoDB uses B+ tree (all data in leaves, leaves linked)

### Q2: Composite Index — Leftmost Prefix Rule
```sql
CREATE INDEX idx ON t(a, b, c);
-- USES index: WHERE a=1; WHERE a=1 AND b=2; WHERE a=1 AND b=2 AND c=3
-- USES index: WHERE a=1 AND b > 5 (range on b; c not usable after range)
-- DOES NOT use: WHERE b=2; WHERE c=3; WHERE b=2 AND c=3 (no leftmost a)
```
- Order matters: put equality columns first, range columns last
- Column order in index ≠ column order in query (optimizer reorders equality predicates)

### Q3: Covering Index
- Index contains all columns needed by query — no heap fetch (Index Only Scan)
```sql
CREATE INDEX idx_cover ON orders(customer_id, status) INCLUDE (amount, created_at);
-- Query: SELECT amount, created_at FROM orders WHERE customer_id=5 AND status='PAID'
-- All data from index — no table access
```
- `INCLUDE` columns (PostgreSQL 11+): stored in leaf pages but not part of tree key

### Q4: Index Selectivity
- `Selectivity = distinct_values / total_rows` (range 0–1; higher = more selective = better index candidate)
- High cardinality (user_id, email) → good index candidate
- Low cardinality (boolean, status with 3 values) → poor index; optimizer may prefer seq scan
- Rule of thumb: index pays off when query returns < 5-15% of table rows

### Q5: Clustered vs Non-Clustered (InnoDB)
| | Clustered (Primary Key) | Non-Clustered (Secondary) |
|--|------------------------|--------------------------|
| Storage | Data rows stored in index order | Separate structure; leaf contains PK value |
| Count per table | Exactly 1 | Multiple |
| Lookup | Direct (data in leaf) | Two steps: secondary lookup → PK → clustered |
| InnoDB | Always clustered on PK | All non-PK indexes are non-clustered |
| PostgreSQL | Heap storage by default; `CLUSTER` to reorder physically (one-time) | Separate B-tree files |

### Q6: Partial Index
```sql
-- Index only active users (90% are inactive — index much smaller)
CREATE INDEX idx_active_users ON users(email) WHERE active = true;
-- Must match WHERE predicate to be used:
SELECT email FROM users WHERE active = true AND email = 'x@y.com';  -- uses index
SELECT email FROM users WHERE email = 'x@y.com';  -- does NOT use partial index
```

### Q7: Functional Index
```sql
CREATE INDEX idx_lower_email ON users(LOWER(email));
-- Used by: WHERE LOWER(email) = 'foo@bar.com'
-- NOT used by: WHERE email = 'foo@bar.com' (different expression)
```
- Also called expression index; stores precomputed expression value
- Use when queries always apply function to column

### Q8: GIN Index for JSONB (PostgreSQL)
```sql
CREATE INDEX idx_gin ON events USING GIN (data);
-- Supports: @> (contains), <@ (contained by), ? (key exists), ?| ?&
SELECT * FROM events WHERE data @> '{"type": "click"}';  -- uses GIN index
```
- GIN = Generalized Inverted Index; each JSON key/value indexed as separate entry
- Also used for full-text search (`tsvector`), arrays
- Slower to write than B-tree; use for read-heavy JSONB queries

### Q9: Why Low-Cardinality Index Hurts
- Boolean column with 50% true/50% false: random heap I/O for 50% of rows → worse than seq scan
- Optimizer estimates index cost (random I/O per row) vs seq scan cost (sequential I/O)
- If index scan touches > 5-15% of table, seq scan wins
- PostgreSQL may choose bitmap index scan as middle ground for moderate selectivity

### Q10: UUID vs BIGINT PK — Fragmentation
- **BIGINT SERIAL/IDENTITY:** Sequential; new rows inserted at end of B-tree → minimal page splits
- **UUID v4 (random):** Random insertion → page splits throughout tree → index fragmentation → larger index, slower inserts, cache thrashing
- **UUID v7 (time-ordered):** Sequential like BIGINT but globally unique — best of both worlds
- **Solution if UUID required:** Use `uuid_generate_v7()` or ULID; run `VACUUM` / `REINDEX` periodically

### Q11: FK Not Auto-Indexed (PostgreSQL Trap)
```sql
-- PostgreSQL does NOT automatically create index on FK column
ALTER TABLE orders ADD CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(id);
-- SELECT * FROM orders WHERE customer_id = 5  →  Seq Scan on orders (potentially)
-- FIX:
CREATE INDEX idx_orders_customer ON orders(customer_id);
```
- MySQL InnoDB auto-creates index on FK (if not already indexed)
- Unindexed FK also causes lock escalation during parent row deletion

### Q12: CREATE INDEX CONCURRENTLY
```sql
CREATE INDEX CONCURRENTLY idx_name ON large_table(column);
```
- Builds index without holding table lock (allows reads and writes during build)
- Takes longer (multiple passes); cannot run inside a transaction
- On failure: leaves invalid index → must `DROP INDEX CONCURRENTLY` + retry
- Regular `CREATE INDEX` holds `ShareLock` — blocks writes

### Q13: Unused Index Audit (PostgreSQL)
```sql
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0  -- never used since last stats reset
ORDER BY schemaname, tablename;
-- Also check index size:
SELECT pg_size_pretty(pg_relation_size(indexrelid)), indexrelname FROM pg_stat_user_indexes;
```
- Reset stats: `SELECT pg_stat_reset();`
- Unused indexes waste write overhead and storage; drop them

### Q14: INCLUDE Columns (Covering Without Key Bloat)
```sql
CREATE INDEX idx_orders_status ON orders(status) INCLUDE (amount, created_at, customer_id);
-- status is the key (in tree nodes); amount/created_at/customer_id only in leaf pages
-- Avoids heap fetch for these columns without inflating tree structure
-- PostgreSQL 11+; SQL Server has similar syntax
```

### Q15: Bitmap Index Scan
- Used when query matches moderate % of rows (between index scan and seq scan efficiency)
- Phase 1: Scan index, build in-memory bitmap of matching heap page numbers
- Phase 2: Fetch only those heap pages in order (sequential I/O)
- Multiple bitmap index scans can be AND/OR'd (BitmapAnd, BitmapOr) — enables multi-column filtering without composite index

---

## Section 3: ACID & Transactions — Top 15 Questions

### Q1: ACID Internals
| Property | Mechanism |
|----------|-----------|
| Atomicity | Undo log (rollback segment) — reverses partial changes on failure |
| Consistency | Constraints, triggers, application logic enforced |
| Isolation | MVCC (PostgreSQL/InnoDB) — readers don't block writers |
| Durability | WAL/Redo log — changes written to log before data pages; survives crash |

- **WAL (Write-Ahead Log):** Write to log first, flush to disk; replay on recovery
- **MVCC:** Each row has version metadata (xmin/xmax in PostgreSQL); readers see snapshot, writers create new versions
- **Undo log (MySQL InnoDB):** Old row versions stored in undo log; active transactions can see past versions

### Q2: Isolation Levels vs Anomalies Matrix
| Isolation Level | Dirty Read | Non-Repeatable Read | Phantom Read | Write Skew |
|-----------------|-----------|---------------------|-------------|------------|
| READ UNCOMMITTED | Possible | Possible | Possible | Possible |
| READ COMMITTED | Prevented | Possible | Possible | Possible |
| REPEATABLE READ | Prevented | Prevented | Possible* | Possible |
| SERIALIZABLE | Prevented | Prevented | Prevented | Prevented |

*PostgreSQL REPEATABLE READ also prevents phantoms (via MVCC snapshot). MySQL REPEATABLE READ may still have phantom issues without gap locks.

- **Dirty Read:** Reading uncommitted data from another transaction
- **Non-Repeatable Read:** Same row returns different value within same transaction
- **Phantom Read:** Same range query returns different set of rows within same transaction
- **Write Skew:** Two transactions read overlapping data, each writes based on what they read, combined result violates invariant (e.g., on-call schedule)

### Q3: MVCC — PostgreSQL xmin/xmax vs MySQL Undo Log
**PostgreSQL:**
```
xmin = transaction ID that inserted this row version
xmax = transaction ID that deleted/updated this row (0 if still live)
```
- Reader's snapshot: row visible if `xmin` committed before snapshot AND (`xmax` = 0 OR `xmax` not committed yet)
- Old versions eventually cleaned up by VACUUM

**MySQL InnoDB:**
- Row header has rollback pointer → undo log chain
- Undo log stores old versions; readers walk chain to find version visible to their snapshot
- Purge thread cleans undo log when no active transactions need old versions

### Q4: SELECT FOR UPDATE vs SELECT FOR SHARE
```sql
-- Exclusive lock — blocks other readers wanting FOR UPDATE/SHARE and all writers
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;

-- Shared lock — multiple readers can hold simultaneously; blocks writers wanting FOR UPDATE
SELECT * FROM accounts WHERE id = 1 FOR SHARE;

-- Skip locked rows (non-blocking queue processing)
SELECT * FROM jobs WHERE status = 'PENDING' LIMIT 1 FOR UPDATE SKIP LOCKED;
```
- `FOR UPDATE NOWAIT` — fails immediately if lock unavailable (no waiting)

### Q5: Deadlock — 4 Coffman Conditions
1. **Mutual exclusion** — resource held exclusively (lock on row)
2. **Hold and wait** — transaction holds lock A while waiting for lock B
3. **No preemption** — locks not forcibly taken away
4. **Circular wait** — Tx1 waits for Tx2's lock; Tx2 waits for Tx1's lock

**Prevention:** Acquire locks in consistent global order; use `NOWAIT`; shorter transactions.
**Detection:** DB detects cycle in wait-for graph → kills one transaction (deadlock victim).
**Spring JPA:** `@Retryable` on service method to retry after deadlock.

### Q6: @Version — Optimistic Locking
```java
@Entity
public class Product {
    @Id Long id;
    @Version Integer version;  // JPA increments on each update
    int stock;
}
// UPDATE products SET stock=?, version=version+1 WHERE id=? AND version=?
// If version mismatch → OptimisticLockException → retry
```
- No DB locks held; fails at commit time if concurrent modification detected
- Best for low-contention scenarios; use pessimistic locking (`SELECT FOR UPDATE`) for high contention

### Q7: Normal Forms
| NF | Rule | Violation Example |
|----|------|------------------|
| 1NF | Atomic values, no repeating groups | phone stored as "555-1234, 555-5678" |
| 2NF | 1NF + no partial dependency on composite PK | (order_id, product_id) PK; product_name depends only on product_id |
| 3NF | 2NF + no transitive dependency | employee_id → dept_id → dept_name (transitive) |
| BCNF | 3NF + every determinant is a candidate key | Stricter than 3NF; handles multi-valued dependency anomalies |

### Q8: When to Denormalize
- Reporting/read-heavy queries requiring many joins
- OLAP vs OLTP: OLAP prefers wide denormalized tables (star schema)
- High-traffic tables where join cost is prohibitive
- Caching derived aggregates (total_order_count on customer row)
- Trade-off: faster reads, slower writes, update anomaly risk, data inconsistency

### Q9: CAP Theorem
- **Consistency:** Every read receives most recent write (or error)
- **Availability:** Every request receives a response (not guaranteed latest)
- **Partition Tolerance:** System continues operating during network partition
- **Rule:** In presence of partition, choose C or A (partition tolerance is non-optional in distributed systems)

| System | Choice | Behavior |
|--------|--------|----------|
| ZooKeeper | CP | Returns error if can't guarantee consistency |
| HBase | CP | Consistency over availability |
| Cassandra | AP | Returns possibly stale data rather than error |
| DynamoDB | AP (default) | Configurable; eventual consistency default |
| Spanner | CP | External consistency (real-time ordering) |
| MongoDB | CP (default) | Primary-based consistency |
| CouchDB | AP | Multi-master, eventual consistency |

### Q10: BASE vs ACID
| | ACID | BASE |
|--|------|------|
| Meaning | Atomicity/Consistency/Isolation/Durability | Basically Available, Soft state, Eventually consistent |
| Guarantees | Strong, immediate | Weak, eventual |
| Systems | RDBMS (PostgreSQL, MySQL) | Cassandra, DynamoDB, CouchDB |
| Use case | Financial, transactional | High availability, partition tolerance |

### Q11: Two-Phase Commit (2PC) and Its Problem
- **Phase 1 (Prepare):** Coordinator asks all participants to prepare; each votes Yes/No
- **Phase 2 (Commit):** If all Yes → coordinator sends Commit; if any No → sends Abort
- **Blocking problem:** If coordinator crashes after Phase 1 but before Phase 2, participants are stuck in prepared state — holding locks, unable to commit or rollback without coordinator recovery
- **3PC** reduces blocking but still has issues; Paxos/Raft preferred for modern systems

### Q12: Saga vs 2PC
| | 2PC | Saga |
|--|-----|------|
| Coupling | Tight (all participants locked) | Loose (async events) |
| Consistency | Strong | Eventual |
| Failure handling | Rollback via abort | Compensating transactions |
| Blocking | Yes | No |
| Use case | Same DB / ACID-capable participants | Microservices, different DBs |

**Saga types:**
- **Choreography:** Services emit events, others react (no central coordinator)
- **Orchestration:** Central saga orchestrator sends commands, receives replies

### Q13: Outbox Pattern
```
Problem: Write to DB + publish event to message broker — not atomic (can publish but not commit, or vice versa)
Solution:
  1. Write business data + event record to OUTBOX table in same transaction
  2. Separate publisher reads OUTBOX, publishes to broker, marks as published
  3. At-least-once delivery; consumer must be idempotent
```
- Alternatives: Transactional Outbox with CDC (Debezium reads WAL/binlog directly)
- Guarantees: Event published if and only if transaction committed

### Q14: Replication Lag — Read-Your-Writes Problem
```
Problem: User writes to primary, reads from replica (which has lag) → reads own data as not yet written
Solutions:
  1. Route reads that immediately follow writes to primary
  2. Track last write timestamp; only use replica if replica_lag < threshold
  3. "Read-after-write" consistency: sticky routing based on session token
  4. Monotonic reads: client always reads from same replica
  5. Use synchronous replication (performance cost)
```

---

## Section 4: Distributed Databases — Top 15 Questions

### Q1: Sharding Strategies
| Strategy | How | Pros | Cons |
|----------|-----|------|------|
| Range sharding | Shard by key range (A-M, N-Z) | Good for range queries | Hot spots if data skewed |
| Hash sharding | Shard by hash(key) % N | Even distribution | Range queries need scatter-gather |
| Directory sharding | Lookup table maps key → shard | Flexible, no rebalancing | Lookup table bottleneck |

### Q2: Shard Key Selection Pitfalls
- **Hot spot:** Choosing timestamp as shard key → all writes go to latest shard
- **Cross-shard joins:** Shard key should align with most common query patterns
- **Low cardinality:** Can't shard on boolean — max 2 shards
- **Unbounded growth:** Some shards may grow much larger than others (range sharding)
- **Best practice:** Choose key with high cardinality, even distribution, aligns with access pattern (e.g., user_id for user data)

### Q3: Consistent Hashing + Virtual Nodes
- Map both servers and keys to a ring (hash space 0 to 2^32)
- Each key assigned to first server clockwise on ring
- **Adding server:** Only keys between new server and its predecessor move
- **Virtual nodes (vnodes):** Each physical server assigned multiple positions on ring → even load distribution, fewer hot spots, better balance when nodes have different capacities
- Used by: Cassandra, DynamoDB, Riak

### Q4: Quorum Reads/Writes
```
N = total replicas
W = write quorum (must acknowledge write)
R = read quorum (must respond to read)
Strong consistency: R + W > N
Example (N=3): W=2, R=2 → R+W=4 > 3 → consistent
Availability-first: W=1, R=1 (fast but possibly stale)
```
- **Quorum write:** Write coordinator waits for W acknowledgments
- **Sloppy quorum (DynamoDB):** Temporarily write to available nodes, hinted handoff when target recovers

### Q5: Eventual Consistency — Conflict Resolution
- **LWW (Last Write Wins):** Highest timestamp overwrites; risk of data loss on concurrent writes; used by Cassandra (configurable), DynamoDB
- **Vector clocks:** Track causality per node; detect concurrent vs sequential writes; client resolves conflicts (like Amazon shopping cart); Riak uses this
- **CRDTs (Conflict-free Replicated Data Types):** Data structures that merge deterministically (counters, sets, maps); no conflict resolution needed

### Q6: DynamoDB — Partition Key + Sort Key
- **Partition key (hash key):** Determines physical partition; must provide exact value for all lookups
- **Sort key (range key):** Optional second part of composite key; enables range queries within a partition
- **Design pattern:** `PK=USER#123`, `SK=ORDER#2024-01-15` → get all orders for user, range on date
- **Hot partition:** If partition key lacks cardinality, one partition overloaded → add random suffix + read from all, aggregate

### Q7: DynamoDB GSI vs LSI
| | LSI (Local Secondary Index) | GSI (Global Secondary Index) |
|--|---------------------------|------------------------------|
| Partition key | Same as base table | Different attribute |
| Sort key | Different attribute | Any attribute |
| Consistency | Strong or eventual | Eventual only |
| Throughput | Shared with base table | Separate provisioned capacity |
| Create time | Table creation only | Anytime |
| Use case | Alternate sort within partition | Alternate access patterns entirely |

### Q8: Cassandra — Partition Key Design (Time-Bucketing)
```
Problem: Storing time-series data with timestamp as partition key → unbounded partition growth
Solution: Time-bucketing
  PK = (sensor_id, bucket)  where bucket = YYYY-MM-DD or YYYY-WW
  SK = timestamp
-- Limits partition size; predictable growth
-- Choose bucket size based on write rate and target partition size (< 100MB recommended)
```
- Cassandra partition = all rows with same PK stored together, sorted by clustering key
- Hot partitions: avoid; write to one partition only (e.g., `bucket = current_day`)

### Q9: MongoDB Aggregation Pipeline
```javascript
db.orders.aggregate([
  { $match: { status: "COMPLETED" } },           // filter (like WHERE)
  { $group: { _id: "$customerId", total: { $sum: "$amount" } } },  // aggregate
  { $sort: { total: -1 } },                       // sort
  { $limit: 10 },                                 // top 10
  { $lookup: {                                    // JOIN
      from: "customers", localField: "_id",
      foreignField: "_id", as: "customerInfo"
  }},
  { $project: { total: 1, "customerInfo.name": 1 } }  // project fields
]);
```
- Stages: `$match`, `$group`, `$sort`, `$limit`, `$skip`, `$lookup`, `$unwind`, `$project`, `$addFields`, `$facet`
- Use `$match` early to reduce document count; `$unwind` before `$group` on arrays

### Q10: Redis Cluster — Hash Slots
- 16384 hash slots total
- Each key mapped to slot: `CRC16(key) % 16384`
- Cluster: each master node owns range of slots (e.g., node1: 0-5460, node2: 5461-10922, node3: 10923-16383)
- Hash tags: `{user}.profile` and `{user}.settings` → same slot (ensures co-location for multi-key ops)
- Adding nodes: rebalance slots between nodes; data migrated automatically

### Q11: Elasticsearch — Inverted Index + BM25
- **Inverted index:** Maps terms → list of documents containing them + positions + frequencies
- **Indexing:** Text analyzed (tokenized, lowercased, stemmed, stop words removed) → terms stored in inverted index
- **BM25 scoring:** Relevance score based on:
  - TF (term frequency in document) with saturation (diminishing returns)
  - IDF (inverse document frequency — rare terms score higher)
  - Field length normalization (shorter docs with term rank higher)
- **Query types:** `match` (full-text), `term` (exact), `range`, `bool` (must/should/must_not)

### Q12: Flyway vs Liquibase
| | Flyway | Liquibase |
|--|--------|-----------|
| Format | SQL or Java | XML, YAML, JSON, SQL |
| Migration tracking | `flyway_schema_history` | `databasechangelog` |
| Rollback | Pro version / manual | Built-in rollback support |
| Naming convention | `V1__description.sql`, `R__repeatable.sql` | Changesets with author + id |
| Spring Boot | `spring.flyway.*` | `spring.liquibase.*` |
| Philosophy | Simplicity | Flexibility |

### Q13: Expand-Contract Migration (Parallel Change)
```
Problem: Rename column `user_name` → `username` without downtime
Solution (3-phase):
  Phase 1 (Expand): Add new column `username`; app writes to both; reads from old
  Phase 2 (Migrate): Backfill `username` from `user_name`; app reads from new column
  Phase 3 (Contract): Drop old `user_name` column
-- Each phase deployed separately; never breaks running version
```

### Q14: Zero-Downtime DDL
- **ADD COLUMN (with default):** PostgreSQL 11+ stores default in catalog — instant; old versions rewrote table
- **ADD INDEX:** `CREATE INDEX CONCURRENTLY` — no table lock
- **ALTER COLUMN TYPE:** Usually requires table rewrite → downtime; use expand-contract instead
- **DROP COLUMN:** Fast (just marks invisible); physical reclaim at next VACUUM FULL
- **MySQL `pt-online-schema-change`:** Copies table, applies changes, swaps → triggers keep sync during copy

### Q15: Multi-Tenancy Patterns
| Pattern | Isolation | Cost | Use Case |
|---------|-----------|------|----------|
| Separate database per tenant | High | High | Enterprise, compliance requirements |
| Separate schema per tenant | Medium | Medium | Mid-scale SaaS |
| Shared schema + `tenant_id` column | Low | Low | High-scale SaaS |
| Row-Level Security (RLS) | High (enforced at DB) | Low | PostgreSQL; policy-based tenant isolation |

```sql
-- PostgreSQL RLS example
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON orders
  USING (tenant_id = current_setting('app.current_tenant')::bigint);
-- App sets: SET app.current_tenant = '123'
-- All queries on orders automatically filtered to tenant 123
```

---

## Section 5: Quick Reference Tables

### Isolation Levels × Anomalies (Full Matrix)
| Isolation Level | Dirty Read | Non-Repeatable Read | Phantom Read | Write Skew | Lost Update |
|-----------------|:----------:|:-------------------:|:------------:|:----------:|:-----------:|
| READ UNCOMMITTED | YES | YES | YES | YES | YES |
| READ COMMITTED | NO | YES | YES | YES | YES |
| REPEATABLE READ | NO | NO | YES* | YES | NO |
| SERIALIZABLE | NO | NO | NO | NO | NO |

*PostgreSQL RR prevents phantoms via MVCC snapshot.

### SQL JOIN Types Reference
```
INNER JOIN:  A ∩ B  (matching rows only)
LEFT JOIN:   A + (A ∩ B)  (all A, matching B or NULL)
RIGHT JOIN:  B + (A ∩ B)  (all B, matching A or NULL)
FULL JOIN:   A ∪ B  (all rows from both, NULLs for no match)
CROSS JOIN:  A × B  (every combination)
SELF JOIN:   table joined to itself (aliased)
```

### CAP Theorem — Systems Classification
| System | C | A | P | Notes |
|--------|---|---|---|-------|
| ZooKeeper | YES | NO | YES | CP; refuses requests when partition detected |
| HBase | YES | NO | YES | CP; depends on ZooKeeper |
| Cassandra | NO | YES | YES | AP; tunable consistency |
| DynamoDB | NO | YES | YES | AP by default; strong consistency optional |
| Google Spanner | YES | ~YES | YES | CP; TrueTime gives external consistency |
| MongoDB | YES | NO | YES | CP; primary election on partition |
| CouchDB | NO | YES | YES | AP; multi-master replication |
| Etcd | YES | NO | YES | CP; Raft-based strong consistency |

### NoSQL Database Selection Guide
| Use Case | Database | Reason |
|----------|----------|--------|
| Session store, caching, rate limiting | Redis | In-memory, sub-ms latency |
| User profiles, product catalog (flexible schema) | MongoDB | Document model, rich queries |
| Time-series, IoT metrics | InfluxDB / TimescaleDB | Optimized time-series ingestion |
| Full-text search | Elasticsearch / OpenSearch | Inverted index, relevance scoring |
| Wide-column, high write throughput | Cassandra | Append-only writes, linear scale |
| Key-value at massive scale | DynamoDB | Managed, single-digit ms at any scale |
| Graph data (social, recommendation) | Neo4j / Neptune | Native graph traversal |
| Event streaming / message queue | Kafka | Append log, consumer groups, replay |
| Leaderboard, sorted sets | Redis (ZSET) | O(log N) sorted set operations |
| Relational + ACID, moderate scale | PostgreSQL | Feature-rich, extensions (PostGIS, JSONB) |

### HikariCP Key Properties
```properties
# Connection pool sizing
spring.datasource.hikari.maximum-pool-size=10          # max connections (CPU cores * 2 + disk spindles)
spring.datasource.hikari.minimum-idle=5                # min idle connections
spring.datasource.hikari.connection-timeout=30000      # ms to wait for connection from pool
spring.datasource.hikari.idle-timeout=600000           # ms before idle connection evicted
spring.datasource.hikari.max-lifetime=1800000          # ms max connection lifetime (< DB wait_timeout)
spring.datasource.hikari.keepalive-time=300000         # ms; send keepalive to prevent firewall timeout
spring.datasource.hikari.leak-detection-threshold=2000 # ms; log warning if connection held > threshold
```
- **Pool size formula (OLTP):** `connections = (cores * 2) + effective_spindle_count` (HikariCP docs)
- **Connection leak:** Use `leak-detection-threshold`; always close connections in `finally` or try-with-resources

---

## Section 6: Must-Know SQL Patterns

### Nth Highest Salary
```sql
-- Method 1: DENSE_RANK (handles ties correctly)
SELECT salary FROM (
  SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk FROM employees
) ranked WHERE rnk = 3;  -- 3rd highest

-- Method 2: Subquery (no window function)
SELECT MIN(salary) FROM employees
WHERE salary IN (SELECT DISTINCT salary FROM employees ORDER BY salary DESC LIMIT 3);
```

### Duplicate Detection + Deletion
```sql
-- Find duplicates
SELECT email, COUNT(*) FROM users GROUP BY email HAVING COUNT(*) > 1;

-- Delete duplicates, keep lowest id
DELETE FROM users WHERE id NOT IN (
  SELECT MIN(id) FROM users GROUP BY email
);

-- PostgreSQL: Using ctid (physical row identifier)
DELETE FROM users a USING users b
WHERE a.email = b.email AND a.id > b.id;
```

### Running Total
```sql
SELECT
  order_date,
  amount,
  SUM(amount) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM orders;
-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW is default for SUM OVER ORDER BY
-- ROWS = physical rows; RANGE = logical (same ORDER BY value grouped)
```

### Gaps in Sequence
```sql
-- Find missing IDs in sequence
SELECT s.id + 1 AS gap_start
FROM orders s
LEFT JOIN orders n ON n.id = s.id + 1
WHERE n.id IS NULL AND s.id < (SELECT MAX(id) FROM orders);

-- PostgreSQL: generate_series approach
SELECT gs.id AS missing_id
FROM generate_series(1, (SELECT MAX(id) FROM orders)) gs(id)
LEFT JOIN orders o ON o.id = gs.id
WHERE o.id IS NULL;
```

### Employee Hierarchy (Recursive CTE)
```sql
WITH RECURSIVE org_tree AS (
  SELECT id, name, manager_id, name::TEXT AS path, 0 AS depth
  FROM employees WHERE manager_id IS NULL  -- root (CEO)
  UNION ALL
  SELECT e.id, e.name, e.manager_id,
         ot.path || ' > ' || e.name,
         ot.depth + 1
  FROM employees e
  JOIN org_tree ot ON e.manager_id = ot.id
  WHERE ot.depth < 10  -- safety limit
)
SELECT id, name, depth, path FROM org_tree ORDER BY path;
```

### Moving Average (Window Function)
```sql
-- 7-day moving average of daily sales
SELECT
  sale_date,
  daily_total,
  AVG(daily_total) OVER (
    ORDER BY sale_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW  -- 7-day window
  ) AS moving_avg_7d
FROM daily_sales;
-- ROWS = physical rows; use RANGE for calendar-based (handles missing days)
```

### Top-N Per Group
```sql
-- Top 3 products by sales per category
SELECT category, product, sales
FROM (
  SELECT category, product, sales,
         ROW_NUMBER() OVER (PARTITION BY category ORDER BY sales DESC) AS rn
  FROM product_sales
) ranked
WHERE rn <= 3;

-- PostgreSQL: DISTINCT ON (one per group)
SELECT DISTINCT ON (category) category, product, sales
FROM product_sales ORDER BY category, sales DESC;  -- top 1 per category
```

---

## Section 7: Common Traps (20 Items)

1. **NOT IN with NULL subquery** — If subquery returns any NULL, `NOT IN` returns 0 rows. Use `NOT EXISTS` instead.

2. **Implicit type conversion breaks index** — `WHERE user_id = '123'` where `user_id` is INTEGER forces cast on every row; index not used. Match types exactly.

3. **Function on indexed column** — `WHERE YEAR(created_at) = 2024` prevents index use; rewrite as `WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01'`.

4. **OFFSET pagination at scale** — `OFFSET 1000000 LIMIT 10` scans and discards 1M rows. Use keyset pagination: `WHERE id > last_seen_id ORDER BY id LIMIT 10`.

5. **SELECT * in production** — Fetches unnecessary columns; breaks covering indexes; fragile against schema changes; serializes hidden LOB columns. Always specify columns.

6. **Missing index on FK column (PostgreSQL)** — PostgreSQL does not auto-create FK indexes. Every join or delete cascading through FK does seq scan.

7. **IDENTITY / SERIAL breaks batch insert** — If using JDBC `executeBatch()`, ensure `Statement.RETURN_GENERATED_KEYS` or use sequence directly; some drivers fetch keys one-by-one.

8. **Shared database between microservices** — Creates tight coupling; one service's schema change can break another; prevents independent deployments. Use private DB per service.

9. **Auto-commit in JDBC** — Default is `true`; each statement is its own transaction. Wrap related statements in explicit transaction: `conn.setAutoCommit(false)`.

10. **Stale statistics cause bad query plans** — After bulk load, `ANALYZE` (PostgreSQL) or `ANALYZE TABLE` (MySQL) to update statistics; planner uses them for join ordering and index choice.

11. **N+1 query problem** — Loading 100 orders then fetching each order's customer separately = 101 queries. Fix: `JOIN FETCH` in JPQL, `@EntityGraph`, or `IN` clause batch fetch.

12. **String concatenation in queries (SQL injection)** — Never concatenate user input. Use prepared statements / parameterized queries always.

13. **Locking entire table with LOCK TABLE** — Prefer row-level locks (`SELECT FOR UPDATE`). Table-level locks serialize all access.

14. **Forgetting transaction on multi-step operation** — Two related updates without transaction; first succeeds, second fails → inconsistent state.

15. **Cascade delete without index on FK** — Deleting parent row triggers FK cascade check; without index on child FK column, full child table scan.

16. **Using ORM lazy loading outside transaction** — `LazyInitializationException` in Spring when accessing lazy collection outside `@Transactional` scope. Use eager fetch or open session in correct scope.

17. **DATETIME vs TIMESTAMP in MySQL** — `DATETIME` stores literal value, no timezone. `TIMESTAMP` converts to UTC for storage, back to session timezone on retrieval. Use `TIMESTAMP` for audit fields.

18. **COUNT(DISTINCT col)** over large table — No index helps without covering index; may require full scan. Approximate: `HLL` (HyperLogLog) in PostgreSQL/Redis for cardinality estimation.

19. **Deadlock due to inconsistent lock ordering** — Tx1 locks A then B; Tx2 locks B then A → deadlock. Always acquire locks in same global order (e.g., always by ascending primary key).

20. **VACUUM not running (PostgreSQL table bloat)** — Dead row versions accumulate if `autovacuum` disabled or can't keep up. Table grows; queries slow. Monitor `pg_stat_user_tables.n_dead_tup`; tune autovacuum or run manual `VACUUM ANALYZE`.

---

## Final 5-Minute Recall Checklist

- [ ] SQL execution order: FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY
- [ ] DENSE_RANK has no gaps; RANK has gaps; ROW_NUMBER is always unique
- [ ] NOT IN + NULL = 0 rows. Use NOT EXISTS.
- [ ] Composite index: leftmost prefix must match for index to be used
- [ ] PostgreSQL: FK indexes NOT automatic → create manually
- [ ] MVCC: readers don't block writers (no read locks in PostgreSQL/InnoDB)
- [ ] SERIALIZABLE prevents write skew; REPEATABLE READ does not
- [ ] 2PC blocking problem → Saga pattern for microservices
- [ ] Outbox pattern: DB write + event in same transaction
- [ ] CAP: Cassandra=AP, ZooKeeper=CP, Spanner=CP
- [ ] Consistent hashing + vnodes: adding node only moves adjacent keys
- [ ] R + W > N = strong consistency in quorum systems
- [ ] UUID v4 = index fragmentation; use UUID v7 or BIGINT
- [ ] `CREATE INDEX CONCURRENTLY`: no table lock; cannot run in transaction
- [ ] HikariCP `max-lifetime` must be less than DB `wait_timeout`
- [ ] Keyset pagination > OFFSET for large datasets
- [ ] RLS (Row Level Security): tenant isolation enforced at DB level
- [ ] Expand-contract: safe column rename without downtime
- [ ] Bitmap index scan: used for moderate selectivity (between index scan and seq scan)
- [ ] GIN index: JSONB containment queries and full-text search
- [ ] Know the difference between clustered and non-clustered index
- [ ] Know UUID fragmentation problem (use BIGINT or UUID v7)
- [ ] Foreign keys are NOT auto-indexed in PostgreSQL
- [ ] CREATE INDEX CONCURRENTLY for zero-downtime
- [ ] Isolation levels: READ COMMITTED is PostgreSQL default, REPEATABLE READ is MySQL default
- [ ] MVCC: PostgreSQL uses xmin/xmax, MySQL uses undo log chain
- [ ] Deadlock: 4 Coffman conditions — mutual exclusion, hold-and-wait, no preemption, circular wait
- [ ] Optimistic locking: @Version generates WHERE version = ? UPDATE; throws OptimisticLockException on conflict
- [ ] CAP: ZooKeeper = CP, Cassandra = AP, Spanner = CA (with GPS clock)
- [ ] Sharding: monotonically increasing keys cause hotspots — use hash sharding or Snowflake ID
- [ ] Consistent hashing: virtual nodes solve uneven distribution on node add/remove
- [ ] DynamoDB: partition key = hash, sort key = range; GSI = global, LSI = local (same partition)
- [ ] Cassandra: partition key drives data locality; never use high-cardinality partition key with time as sole clustering key without bucketing
- [ ] Elasticsearch: shards are immutable Lucene segments; use aliases for zero-downtime reindex
- [ ] Flyway: expand-contract pattern = add column → deploy → backfill → drop old column

---

*Chapter 26 — Databases Quick Revision | Volume 6: Interview Revision Pack*


