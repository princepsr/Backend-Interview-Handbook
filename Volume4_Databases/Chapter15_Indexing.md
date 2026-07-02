# Volume 4: Databases & Performance
# Chapter 15: Indexing & Query Optimization

---

# Chapter 15: Database Indexing & Query Optimization — Part A

> **Target Audience:** SDE2 / Senior Engineers | **Companies:** FAANG, Stripe, Uber, Airbnb, Shopify, LinkedIn
> **Databases Covered:** PostgreSQL 15+, MySQL 8+ (InnoDB), with dialect notes where behavior diverges

---

### Topic 1: How Indexes Work — B-tree Structure, Page Layout, Index Traversal

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Google, Meta, Amazon, Microsoft, Stripe

**Q:** Explain how a database index works internally. Why does an index speed up reads but slow down writes?

**Short Answer:**
An index is a separate data structure (most commonly a B-tree) that stores a sorted copy of one or more columns alongside a pointer to the actual row. Reads are faster because the engine traverses the tree in O(log n) steps instead of scanning all pages. Writes are slower because every INSERT, UPDATE, or DELETE must also update all affected index structures.

**Deep Explanation:**

**B-tree Anatomy**

![B-tree index structure](https://upload.wikimedia.org/wikipedia/commons/6/65/B-tree.svg)
*B-tree — all values stored in sorted order across nodes, enabling O(log n) point and range lookups*

A B-tree (technically a B+-tree in most databases) consists of three node types:

- **Root node** — the single entry point; fits in one page
- **Internal nodes** — store separator keys and child page pointers; never hold actual row data
- **Leaf nodes** — form a doubly-linked list; each entry holds the indexed key value(s) + a row pointer (either a heap tuple ID or the clustered key)

Each node is exactly one **page** (8 KB in PostgreSQL, 16 KB in MySQL InnoDB by default). The tree stays balanced: every leaf is at the same depth. For a table of 1 billion rows with an 8-byte key, the tree is typically only 4–5 levels deep — giving ~5 page reads to locate any row.

**Page Layout**

A leaf page looks like:

```
| Page Header | Item Pointers (array) | Free Space | Item Data (right-to-left) |
```

Each item in a B-tree leaf stores: `(key_value, heap_tid)` where `heap_tid = (block_number, tuple_offset)`.

**Index Traversal (Point Lookup)**

```
SELECT * FROM orders WHERE order_id = 42;

1. Read root page            → find which child range contains 42
2. Read internal node(s)     → narrow down further
3. Read leaf page            → find (42, tid=(block=107, offset=3))
4. Read heap page 107        → fetch full row at offset 3
```

Total I/O: 4–5 pages vs. potentially thousands for a full table scan.

**Range Scan**

Because leaf nodes are linked, a range query (`WHERE created_at BETWEEN '2024-01-01' AND '2024-03-31'`) traverses the B-tree to the leftmost matching leaf, then follows the next-page pointers rightward — very cache-friendly.

**Write Overhead**

Every write must maintain the B-tree invariant:
- **INSERT**: find the correct leaf position, insert key. If the leaf is full, a **page split** occurs — the page is split into two, and a new separator key is pushed up to the parent (potentially cascading).
- **UPDATE** on an indexed column: logically a DELETE + INSERT in the index.
- **DELETE**: marks the key as dead; space is reclaimed lazily via VACUUM (PostgreSQL) or purge (InnoDB).

A table with 10 indexes means 10 separate B-tree updates on every INSERT.

**Real-World Example:**

An e-commerce platform had a `product_variants` table (50M rows) with 12 indexes for various search facets. Bulk import of 500K new products took 45 minutes. After profiling, 80% of the time was spent on index maintenance. They reduced to 7 essential indexes and moved the remaining ones to a search engine (Elasticsearch), cutting import time to 9 minutes.

**Code Example:**

```sql
-- PostgreSQL: visualize B-tree height and page count
CREATE EXTENSION IF NOT EXISTS pageinspect;

-- Check index depth (number of tree levels)
SELECT bt_metap('orders_pkey');
-- Returns: magic, version, root, level, fastroot, fastlevel, last_cleanup_num_delpages, etc.
-- level=3 means 4-level tree (root + 2 internal + leaf)

-- Examine a leaf page
SELECT * FROM bt_page_items('orders_pkey', 1);
-- Shows: itemoffset, ctid (heap tid), itemlen, nulls, vars, data (key bytes)

-- Estimate index bloat
SELECT
    relname,
    pg_size_pretty(pg_relation_size(oid)) AS index_size,
    pg_size_pretty(pg_relation_size(reltoastrelid)) AS toast_size
FROM pg_class
WHERE relname LIKE 'orders%' AND relkind = 'i';

-- InnoDB: equivalent tree depth check
SELECT b_tree_level
FROM information_schema.INNODB_SYS_INDEXES
WHERE name = 'PRIMARY';
```

**Follow-up Questions:**
1. What is a page split and when does it cause performance issues? How does a fill factor setting help?
2. How does PostgreSQL's VACUUM interact with B-tree dead entries vs. InnoDB's purge thread?
3. For a write-heavy table, what strategies exist beyond reducing index count?

**Common Mistakes:**
- Assuming index lookups are always "free" — random I/O for heap fetches (non-clustered indexes) can be more expensive than a sequential scan for large result sets.
- Forgetting that index maintenance is synchronous on write (not deferred), so index count directly impacts write latency.

**Interview Traps:**
- "Does an index always make a query faster?" — No. For queries returning >5–15% of rows, the optimizer may prefer a sequential scan. Also, index-only scans are only possible if the visibility map shows all pages are clean.
- "B-tree vs B+-tree" — Most databases use B+-tree (data only in leaves), not the original B-tree (data in all nodes). Know the difference.

**Quick Revision:** A B+-tree index stores sorted keys in leaf nodes linked as a list; reads traverse ~log(n) pages, but every write must maintain all index trees, creating O(k) overhead where k = number of indexes.

---

### Topic 2: B-tree vs Hash Index

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Uber, Shopify, Booking.com

**Q:** When would you choose a Hash index over a B-tree index? What are the limitations of Hash indexes?

**Short Answer:**
Hash indexes use a hash function to map keys to buckets, giving O(1) point lookups for exact equality — but they cannot support range queries, ordering, or prefix matching. B-tree indexes support equality, ranges, sorts, and prefix scans at O(log n), making them the default for almost all use cases.

**Deep Explanation:**

**Hash Index Internals**

```
key → hash_function(key) → bucket_number → pointer to (key, row_tid) pairs
```

Lookup: compute hash, read the bucket page, scan the bucket for exact match. Typically 1–2 page reads vs. B-tree's 3–5, but the difference is marginal in practice because B-tree pages are almost always in the buffer pool.

**B-tree Capabilities vs. Hash**

| Operation | B-tree | Hash |
|---|---|---|
| Equality (`=`) | O(log n) | O(1) |
| Range (`BETWEEN`, `>`, `<`) | Yes | No |
| Sort (`ORDER BY`) | Yes (free) | No |
| Prefix (`LIKE 'abc%'`) | Yes | No |
| NULL handling | Yes | Varies |
| Multi-column | Yes | Yes (MySQL) |

**PostgreSQL Hash Indexes**

Before PostgreSQL 10, hash indexes were not WAL-logged, meaning they were not crash-safe — you had to `REINDEX` after a crash. As of PostgreSQL 10, they are fully WAL-logged and crash-safe.

```sql
-- PostgreSQL: explicit hash index creation
CREATE INDEX CONCURRENTLY idx_sessions_token_hash
ON sessions USING hash (session_token);

-- B-tree (default)
CREATE INDEX idx_sessions_token_btree
ON sessions (session_token);
```

When to use hash in PostgreSQL: only for very large equality-only workloads on long string keys where the hash index is measurably smaller and faster in benchmarks. In practice, B-tree is usually chosen because of its flexibility.

**MySQL InnoDB Hash Indexes**

MySQL InnoDB does NOT support user-created hash indexes on disk. It has an **Adaptive Hash Index (AHI)** — an automatic in-memory cache that InnoDB builds on hot B-tree pages. It cannot be manually created; InnoDB decides which pages to hash based on access patterns. You can disable it:

```sql
-- MySQL: check AHI status
SHOW ENGINE INNODB STATUS\G
-- Look for: INSERT BUFFER AND ADAPTIVE HASH INDEX section

-- Disable if causing contention (mutex hot spot on very high-concurrency workloads)
SET GLOBAL innodb_adaptive_hash_index = OFF;
```

**MySQL MEMORY engine** supports explicit hash indexes:
```sql
CREATE TABLE cache_table (
    cache_key VARCHAR(64) NOT NULL,
    cache_value TEXT,
    INDEX USING HASH (cache_key)
) ENGINE=MEMORY;
```

**Real-World Example:**

A session store table with 200M rows and a `session_token` column (UUID, 36 chars). Queries are always `WHERE session_token = ?` — pure equality. A hash index reduces index size by ~30% compared to B-tree because it doesn't need to store the full key in sorted order. The Stripe infrastructure team documented using hash indexes for token lookup tables where the token is never used in range queries.

**Code Example:**

```sql
-- PostgreSQL: compare index sizes
CREATE TABLE sessions (
    id BIGSERIAL PRIMARY KEY,
    session_token UUID NOT NULL,
    user_id BIGINT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
);

-- Hash index on equality-only token lookups
CREATE INDEX idx_sessions_hash ON sessions USING hash (session_token);

-- B-tree on user_id for range/join queries
CREATE INDEX idx_sessions_user ON sessions (user_id, expires_at);

-- Check which index is used
EXPLAIN (ANALYZE, BUFFERS)
SELECT user_id FROM sessions WHERE session_token = '550e8400-e29b-41d4-a716-446655440000';
-- Hash index: "Index Scan using idx_sessions_hash"

-- Range query — cannot use hash, falls back to sequential scan or btree
EXPLAIN SELECT * FROM sessions WHERE expires_at > NOW();
```

**Follow-up Questions:**
1. Why did PostgreSQL hash indexes not support WAL before version 10, and what risk did that create?
2. What is InnoDB's Adaptive Hash Index and when should you disable it?
3. For a UUID primary key (pure equality lookups), would you ever choose a hash index in production PostgreSQL?

**Common Mistakes:**
- Attempting to use a hash index for `LIKE 'prefix%'` queries — it will not be used.
- Creating hash indexes in MySQL InnoDB — they are silently ignored or error depending on version; only B-tree is supported for persistent InnoDB indexes.

**Interview Traps:**
- "MySQL supports hash indexes" — only in the MEMORY engine or internally via AHI; not for InnoDB disk-based indexes.
- "Hash index is always faster for equality" — true in theory, but in practice B-tree pages for hot keys are cached in the buffer pool, and the difference is negligible. Hash indexes also have worse worst-case behavior on hash collisions.

**Quick Revision:** Hash indexes give O(1) equality lookups but cannot handle ranges or sorting; B-tree handles both at O(log n) and is the default — choose hash only for pure equality on large string keys with measured performance gain.

---

### Topic 3: Composite Indexes — Column Order, Covering Index, INCLUDE

**Difficulty:** High | **Frequency:** Very High | **Companies:** Google, Meta, Netflix, Airbnb, Stripe

**Q:** You have a query `SELECT email FROM users WHERE country = 'US' AND age > 25 ORDER BY created_at`. Design the optimal composite index. Explain the leftmost prefix rule.

**Short Answer:**
A composite index is a B-tree on multiple columns in a specified order. The **leftmost prefix rule** means the index can only be used if the query filters on the leading column(s); skipping a column breaks the prefix chain. For the query above, `(country, age, created_at)` with `email` as an INCLUDE column is optimal.

**Deep Explanation:**

**Leftmost Prefix Rule**

Given index `(a, b, c)`:

| Query Predicate | Index Usable? | Why |
|---|---|---|
| `WHERE a = 1` | Yes | Uses prefix (a) |
| `WHERE a = 1 AND b = 2` | Yes | Uses prefix (a, b) |
| `WHERE a = 1 AND b = 2 AND c = 3` | Yes | Full index |
| `WHERE b = 2` | No | Skips leading column a |
| `WHERE a = 1 AND c = 3` | Partial | Only uses a; c is not contiguous |
| `WHERE a = 1 AND b > 2 AND c = 3` | Partial | a+b used; c stops after range on b |

**Why order matters:** In a B-tree, entries are sorted first by `a`, then by `b` within the same `a`, then by `c` within the same `(a, b)`. Without knowing `a`, the tree provides no useful sorted order for `b`.

**Designing for the Query Pattern**

For `WHERE country = 'US' AND age > 25 ORDER BY created_at`:

1. **Equality columns first:** `country` — high selectivity equality filter; place first.
2. **Range column next:** `age` — range predicate; must come before `created_at` or the sort cannot use the index.
3. **Sort column last:** `created_at` — but note: once a range predicate is used on `age`, the index cannot also provide sort order on `created_at`. The optimizer will sort in memory. This is a fundamental B-tree constraint — you cannot simultaneously use an index for both a range filter and a subsequent sort on a different column.

Alternative: if you need to eliminate the sort, you must choose between filtering on `age` via index or sorting via index — they cannot both be served by the same composite index after a range predicate.

**Covering Index**

A covering index contains all columns referenced by a query — the engine can satisfy the query from the index alone without touching the heap (table). This eliminates the "table fetch" step entirely.

```sql
-- Query: SELECT email FROM users WHERE country = 'US' AND age > 25
-- Without covering index: index lookup → heap fetch for email
-- With covering index: index lookup only
CREATE INDEX idx_users_covering ON users (country, age, email);
-- OR in PostgreSQL 11+: separate INCLUDE (non-key column, not part of sort key)
CREATE INDEX idx_users_include ON users (country, age) INCLUDE (email);
```

**PostgreSQL INCLUDE Clause**

`INCLUDE` columns are stored in leaf nodes but not in internal nodes of the B-tree. This means:
- They do not contribute to the index sort order (cannot be used in WHERE/ORDER BY)
- They do not increase the size of internal nodes (slightly smaller tree, faster traversal)
- They enable index-only scans without polluting the sort key

```sql
-- PostgreSQL 11+
CREATE INDEX idx_orders_include
ON orders (customer_id, status) INCLUDE (total_amount, created_at);

-- Now this query is index-only (no heap access):
SELECT total_amount, created_at
FROM orders
WHERE customer_id = 123 AND status = 'PENDING';
```

MySQL does not have an explicit INCLUDE clause; you put all columns in the index key. The effect is similar but internal nodes also store the extra columns, making them slightly larger.

**Real-World Example:**

Airbnb's search backend had a listings table query: `WHERE city_id = ? AND active = true AND price BETWEEN ? AND ? ORDER BY rating DESC`. The team iterated through:
1. `(city_id)` — required sort + filter in memory: slow
2. `(city_id, active, price)` — covers filter, sort still in memory
3. `(city_id, active, rating DESC) INCLUDE (price, title, thumbnail_url)` — covers sort AND the 5 columns needed for the results page; eliminated heap fetch entirely, reducing query time from 80ms to 4ms

**Code Example:**

```sql
-- Problem query
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT email, created_at
FROM users
WHERE country = 'US'
  AND age > 25
ORDER BY created_at
LIMIT 20;

-- Iteration 1: basic composite
CREATE INDEX idx_v1 ON users (country, age);
-- Result: Index Cond on (country, age), Sort on created_at → expensive sort node

-- Iteration 2: covering index with INCLUDE (PostgreSQL)
CREATE INDEX idx_v2 ON users (country, age, created_at) INCLUDE (email);
-- Result: Index Scan, no separate Sort node for LIMIT queries, no heap fetch

-- Verify index-only scan
EXPLAIN (ANALYZE, BUFFERS)
SELECT email FROM users WHERE country = 'US' AND age > 25;
-- Look for "Index Only Scan" — means no heap page fetches

-- MySQL equivalent (no INCLUDE, put email in key)
CREATE INDEX idx_v2_mysql ON users (country, age, created_at, email);

-- Composite index for JPA/Hibernate entity
-- See Topic 8 for @Index annotation usage
```

**Follow-up Questions:**
1. If `age` has low cardinality (e.g., only 18–90), should you still put it in the composite index?
2. What is the difference between a covering index and an index-only scan? When does an index-only scan fail even with a covering index?
3. How does PostgreSQL's visibility map affect index-only scan eligibility?

**Common Mistakes:**
- Putting low-cardinality columns (like `status` with 3 values) before high-cardinality columns (like `user_id`) in a composite index — this reduces the effectiveness of the first key and forces the engine to scan more entries.
- Confusing INCLUDE columns with key columns — INCLUDE columns cannot be used in WHERE predicates.

**Interview Traps:**
- "Can you use index (a, b, c) for `WHERE a = 1 ORDER BY c`?" — No, because `b` is skipped and the ordering within `(a, ?)` sub-ranges is by `b`, not `c`.
- "Is a covering index always better?" — No, wider indexes increase write overhead and can reduce the buffer pool hit rate for the index itself.

**Quick Revision:** Composite index column order follows the leftmost prefix rule — equality predicates first, range predicate second, sort column last; INCLUDE adds non-key columns to leaf nodes for index-only scans without increasing internal node size.

---

### Topic 4: Index Selectivity & Cardinality

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Booking.com, LinkedIn

**Q:** What is index selectivity, and why can a low-cardinality index actually hurt performance rather than help?

**Short Answer:**
Selectivity is the ratio of distinct values to total rows (0 to 1); high selectivity means the index eliminates most rows. Low-cardinality indexes (e.g., on a boolean or status column with 3 values) are often skipped by the optimizer in favor of sequential scans because the index lookup + heap fetch overhead exceeds the cost of a full scan when a large fraction of rows matches.

**Deep Explanation:**

**Cardinality and Selectivity Defined**

```
Cardinality  = count of distinct values in the column
Selectivity  = cardinality / total_rows   (range: 0.0 to 1.0)
```

High selectivity → index is useful (e.g., `user_id` on a 10M-row table: selectivity ≈ 1.0)
Low selectivity → index may be skipped (e.g., `gender` with 2 values: selectivity = 2/10M ≈ 0.0000002, but each value matches 50% of rows)

**The Optimizer's Cost Model**

The query planner estimates the cost of:
1. Sequential scan: reads all N pages sequentially — very cache-friendly, one I/O stream
2. Index scan: reads B-tree pages + random heap page fetches for each matching row

If a query returns 30% of a 1M-row table (300K rows), the index path requires 300K random heap fetches. On spinning disk, this is catastrophically slow vs. a sequential scan. Even on SSD, beyond ~10–15% row selectivity the optimizer often prefers seq scan.

**PostgreSQL Statistics**

PostgreSQL maintains per-column statistics in `pg_statistic` (viewed via `pg_stats`):

- `n_distinct` — estimated number of distinct values (negative = fraction of rows)
- `null_frac` — fraction of nulls
- `most_common_vals` / `most_common_freqs` — top-N values and their frequencies
- `histogram_bounds` — bucket boundaries for range estimation

```sql
SELECT attname, n_distinct, null_frac, most_common_vals, most_common_freqs
FROM pg_stats
WHERE tablename = 'orders' AND attname IN ('status', 'customer_id');
-- status: n_distinct=4, most_common_freqs=[0.72, 0.18, 0.08, 0.02]
-- customer_id: n_distinct=-1 (all unique)
```

The default statistics target is 100 samples per column. For complex queries, increase it:

```sql
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
ANALYZE orders;
```

**Low-Cardinality Index on Boolean — A Common Mistake**

```sql
-- Table: email_events (500M rows), is_processed BOOLEAN
-- ~98% of rows have is_processed = TRUE
-- 2% (10M rows) have is_processed = FALSE

-- Bad: index on boolean
CREATE INDEX idx_processed ON email_events (is_processed);

-- Query: SELECT * FROM email_events WHERE is_processed = FALSE
-- Optimizer may use the index here (only 2% selectivity = 10M rows)
-- BUT: for is_processed = TRUE (98%), the optimizer will do a seq scan regardless

-- Better: partial index (Topic 6)
CREATE INDEX idx_unprocessed ON email_events (id) WHERE is_processed = FALSE;
-- This index only contains the 10M unprocessed rows — tiny, fast
```

**MySQL Statistics — Histogram Difference**

MySQL 8.0 introduced column histograms (separate from index statistics):

```sql
-- MySQL 8: create histogram for better cardinality estimates
ANALYZE TABLE orders UPDATE HISTOGRAM ON status WITH 256 BUCKETS;

SHOW COLUMNS FROM orders;  -- shows cardinality in index info
SELECT * FROM information_schema.COLUMN_STATISTICS
WHERE TABLE_NAME = 'orders';
```

**Real-World Example:**

A payments platform had an `invoices` table with 400M rows and an index on `payment_status` (values: `PENDING`, `PAID`, `FAILED`, `REFUNDED` — 90% are `PAID`). A report query `WHERE payment_status = 'PENDING'` ran in 200ms using the index. After a batch job set 95% of remaining rows to `PAID`, the same query started taking 45 seconds because the cardinality of `PENDING` dropped to 0.1% and the stale statistics still showed 10% — the optimizer chose the index but now had to do 40M heap fetches. Fix: run `ANALYZE invoices` after the batch, and add a partial index on `payment_status WHERE payment_status != 'PAID'`.

**Code Example:**

```sql
-- Check if optimizer is using index vs seq scan
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM orders WHERE status = 'CANCELLED';
-- If "Seq Scan" appears even though index exists → low selectivity

-- Force index use to compare costs (diagnostic only, not production)
-- PostgreSQL: disable seq scan temporarily
SET enable_seqscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM orders WHERE status = 'CANCELLED';
SET enable_seqscan = on;

-- MySQL: force index
SELECT id FROM orders FORCE INDEX (idx_status) WHERE status = 'CANCELLED';

-- Check cardinality for all indexes on a table (MySQL)
SELECT INDEX_NAME, COLUMN_NAME, CARDINALITY
FROM information_schema.STATISTICS
WHERE TABLE_NAME = 'orders' AND TABLE_SCHEMA = 'mydb'
ORDER BY SEQ_IN_INDEX;

-- Update statistics after large data changes
ANALYZE orders;              -- PostgreSQL
ANALYZE TABLE orders;        -- MySQL
```

**Follow-up Questions:**
1. How does PostgreSQL's `n_distinct` work, and what does a negative value like `-0.98` mean?
2. When would you add an index on a low-cardinality column despite the general rule against it?
3. How do statistics staleness cause query plan regressions, and how do you detect and fix them?

**Common Mistakes:**
- Adding an index on every column "just in case" without checking selectivity first.
- Forgetting to run ANALYZE after large bulk operations — stale statistics cause plan regressions.

**Interview Traps:**
- "Should you index a boolean column?" — Almost never directly; a partial index is almost always better. The exception: if combined with a high-cardinality column in a composite index where it narrows results meaningfully.
- "The optimizer always uses an index if one exists" — False. The cost-based optimizer chooses the cheapest plan; low selectivity or stale stats can cause it to choose seq scan even with a perfect index.

**Quick Revision:** Selectivity = distinct_values / total_rows; low-cardinality indexes are often skipped because the random I/O cost of heap fetches exceeds sequential scan cost — use partial indexes instead when a small fraction of rows is the target.

---

### Topic 5: Clustered vs Non-clustered Index

**Difficulty:** High | **Frequency:** Very High | **Companies:** Amazon, Microsoft, Netflix, Uber

**Q:** Explain the difference between a clustered and non-clustered index. How does InnoDB's clustered primary key affect secondary index performance?

**Short Answer:**
A clustered index determines the physical storage order of rows — there can be only one per table. A non-clustered (secondary) index has its own B-tree with pointers back to the clustered row location. In InnoDB, every table is clustered on the primary key; secondary indexes store the PK value as the row locator, meaning a secondary index lookup always requires a second B-tree traversal to fetch the full row.

**Deep Explanation:**

**Clustered Index (Index-Organized Table)**

The table's data rows ARE the leaf pages of the clustered B-tree. Rows are physically stored in PK order on disk (approximately — actual layout is by page fill order, but logical order matches).

```
Clustered B-tree (InnoDB PRIMARY KEY):
  Root → Internal Nodes → Leaf Pages = actual row data
  Leaf page: (PK_value | col1 | col2 | col3 | ... | all columns)
```

Benefits:
- Range scans on the PK are extremely fast — rows are co-located on adjacent pages
- No separate heap; no extra pointer lookup
- The PK lookup IS the table fetch

**Non-clustered (Secondary) Index in InnoDB**

```
Secondary index leaf page: (indexed_col_value | primary_key_value)
                                                        ↓
                                          Second lookup in clustered index
```

This second lookup is called a **double-dip** or **bookmark lookup**. For every row returned by a secondary index scan, InnoDB traverses the clustered B-tree again to fetch the full row data.

```
Secondary index on email:
  "alice@example.com" → PK=10042
                           ↓
  Clustered index lookup: PK=10042 → full row
```

Implication: secondary index range scans are expensive if many rows match and the rows are not in PK order relative to the secondary key — lots of random I/O into the clustered index.

**Heap Table (PostgreSQL)**

![PostgreSQL B-tree index structure](https://upload.wikimedia.org/wikipedia/commons/e/ee/PostgreSQL_B-tree.svg)
*PostgreSQL B-tree — leaf pages contain index entries pointing to heap (table) pages via TID (block, offset)*

PostgreSQL uses heap tables: data pages are unordered. Every index (including the "primary key" index) is a separate B-tree with `(key, heap_tid)` where `heap_tid = (page_number, tuple_offset)`.

```
Any PostgreSQL index leaf: (key_value | ctid=(block, offset))
                                               ↓
                                  Direct heap page fetch
```

No double-dip for secondary indexes, but also no physical row ordering guarantee. `CLUSTER` command can reorder the heap by a given index — once, non-persistently (new INSERTs go wherever there is space).

```sql
-- PostgreSQL: one-time physical reorder
CLUSTER orders USING idx_orders_created_at;
-- Future inserts will not maintain this order
```

**Choosing PK in InnoDB — UUID vs. Sequential Integer**

This is a critical design decision:

| PK Type | Clustered Insert Behavior | Storage |
|---|---|---|
| BIGINT AUTO_INCREMENT | Always appends to last page — hot but efficient | Minimal fragmentation |
| UUID v4 (random) | Inserts at random positions — causes page splits | High fragmentation, 50% page fill on avg |
| UUID v7 (time-ordered) | Mostly sequential — safe | Low fragmentation |
| Natural composite key | May be frequently updated — expensive | Cascades to all secondary indexes |

```sql
-- Bad: random UUID as PK in InnoDB
CREATE TABLE events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,  -- random = fragmentation
    ...
);

-- Better: BIGINT auto-increment
CREATE TABLE events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    external_id UUID NOT NULL,  -- UUID for external API, but not the clustered key
    UNIQUE KEY uq_external_id (external_id)
);

-- Or: UUID v7 (time-sortable) in PostgreSQL 17+
CREATE TABLE events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    -- In PostgreSQL 17: id UUID DEFAULT uuidv7() PRIMARY KEY
);
```

**Secondary Index Size with Large PKs**

Because InnoDB secondary indexes store the PK value, a 16-byte UUID PK means every secondary index entry is 16 bytes larger than with an 8-byte BIGINT. For a table with 10 secondary indexes and 100M rows, that is 10 × 100M × 8 bytes = 8 GB of extra index storage.

**Real-World Example:**

A logistics company migrated from UUID v4 PKs to BIGINT auto-increment on their `shipments` table (200M rows). The clustered index fragmentation with UUID PKs caused average page utilization of 52% — effectively doubling the storage footprint. After migration: page utilization rose to 89%, storage dropped from 180 GB to 94 GB, and INSERT throughput increased 3x. All 7 secondary indexes also shrank proportionally.

**Code Example:**

```sql
-- PostgreSQL: understand heap vs clustered behavior
-- Check physical order vs logical order
SELECT ctid, id, created_at
FROM orders
ORDER BY ctid  -- physical order
LIMIT 10;

-- vs logical PK order
SELECT ctid, id, created_at
FROM orders
ORDER BY id
LIMIT 10;

-- MySQL InnoDB: demonstrate double-dip
EXPLAIN FORMAT=JSON
SELECT * FROM orders WHERE customer_email = 'alice@example.com';
-- Look for "using_index: false" → secondary index + clustered lookup
-- vs
SELECT id, customer_email FROM orders WHERE customer_email = 'alice@example.com';
-- With covering index on (customer_email, id): "using_index: true" → no double-dip

-- Check InnoDB page fill factor and fragmentation
SELECT
    table_name,
    data_length / 1024 / 1024 AS data_mb,
    index_length / 1024 / 1024 AS index_mb,
    data_free / 1024 / 1024 AS fragmented_mb
FROM information_schema.tables
WHERE table_name = 'orders';

-- Defragment (rebuilds clustered index in PK order)
ALTER TABLE orders ENGINE=InnoDB;  -- online in MySQL 5.6+
-- PostgreSQL equivalent:
CLUSTER orders USING orders_pkey;
VACUUM FULL orders;  -- rewrites table, exclusive lock
```

**Follow-up Questions:**
1. What happens in InnoDB when you define no PRIMARY KEY? What does InnoDB use as the clustered key?
2. How does a covering index eliminate the double-dip in InnoDB secondary index lookups?
3. Why is `VACUUM FULL` in PostgreSQL dangerous in production, and what is the safer alternative?

**Common Mistakes:**
- Using UUID v4 as InnoDB primary key without understanding the insert fragmentation cost.
- Thinking PostgreSQL's `PRIMARY KEY` creates a clustered index like InnoDB — it does not; PostgreSQL primary keys are regular heap-separate B-tree indexes.

**Interview Traps:**
- "Can a table have multiple clustered indexes?" — No. There can be only one physical row ordering. MySQL InnoDB allows only one clustered index (the PK).
- "If I create an index on `(a, b)` in InnoDB and my PK is `id`, what does the index leaf store?" — It stores `(a, b, id)` — the PK is appended to locate the row in the clustered index.

**Quick Revision:** InnoDB clusters rows physically by PK; secondary indexes store PK values requiring a double B-tree lookup to fetch full rows — choose sequential PKs to minimize fragmentation and use covering indexes to eliminate the secondary lookup cost.

---

### Topic 6: Index Types — Partial, Functional, GIN, GiST

**Difficulty:** High | **Frequency:** Medium-High | **Companies:** Google, Stripe, Atlassian, Twilio, Heroku

**Q:** What are partial indexes and functional indexes? When would you use a GIN index in PostgreSQL?

**Short Answer:**
Partial indexes only index rows matching a WHERE predicate — they are smaller and faster for queries that always include that condition. Functional indexes index the result of an expression (e.g., `LOWER(email)`) for case-insensitive lookups. GIN (Generalized Inverted Index) is designed for multi-valued types like arrays, JSONB, and full-text search — it maps each element/lexeme to the set of rows containing it.

**Deep Explanation:**

**Partial Index**

```sql
-- Standard index: indexes ALL rows (including archived, soft-deleted)
CREATE INDEX idx_orders_status ON orders (status);  -- 50M rows

-- Partial index: only indexes the rows you actually query
CREATE INDEX idx_orders_pending ON orders (created_at)
WHERE status = 'PENDING';  -- only 50K rows
```

Benefits:
- Much smaller — fits in buffer pool; fewer I/O operations
- Less write overhead — only maintained when the partial condition is met
- Better selectivity — the indexed subset is inherently more selective

Use cases:
- Soft-delete patterns: `WHERE deleted_at IS NULL` (most queries only touch active rows)
- Status queues: `WHERE processed = FALSE`
- Recent data: `WHERE created_at > '2024-01-01'` (stale data queried rarely)

```sql
-- Common: soft-delete partial index
CREATE INDEX idx_users_active ON users (email) WHERE deleted_at IS NULL;

-- The query optimizer uses this index ONLY if the query also includes the partial condition
SELECT id FROM users WHERE email = 'bob@example.com' AND deleted_at IS NULL;
-- ✓ Uses partial index

SELECT id FROM users WHERE email = 'bob@example.com';
-- ✗ Does NOT use partial index (condition not guaranteed)
```

**Functional (Expression) Index**

Indexes the result of a function or expression rather than the raw column value.

```sql
-- Problem: case-insensitive email lookup
-- Without functional index, this cannot use a B-tree index:
SELECT * FROM users WHERE LOWER(email) = LOWER('Bob@Example.COM');

-- Solution: functional index on LOWER(email)
CREATE INDEX idx_users_email_lower ON users (LOWER(email));

-- Now works efficiently:
SELECT * FROM users WHERE LOWER(email) = 'bob@example.com';
-- "Index Scan using idx_users_email_lower"

-- Expression index for computed value
CREATE INDEX idx_orders_year ON orders (EXTRACT(YEAR FROM created_at));
SELECT * FROM orders WHERE EXTRACT(YEAR FROM created_at) = 2024;

-- MySQL: functional indexes added in 8.0
ALTER TABLE users ADD INDEX idx_email_lower ((LOWER(email)));
```

**Note on PostgreSQL immutability:** Functions used in expression indexes must be IMMUTABLE — the same arguments must always return the same result. `NOW()` is volatile (fails); `LOWER()` is immutable (ok).

**GIN Index (Generalized Inverted Index)**

GIN is designed for types where a single value contains multiple elements: arrays, JSONB, tsvector (full-text search), hstore.

Structure: GIN maps each element → sorted list of row TIDs (like a book index: "term → pages").

```sql
-- Full-text search with GIN
ALTER TABLE articles ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (
        to_tsvector('english', title || ' ' || body)
    ) STORED;

CREATE INDEX idx_articles_fts ON articles USING gin (search_vector);

-- Full-text query uses GIN
SELECT id, title
FROM articles
WHERE search_vector @@ to_tsquery('english', 'database & indexing');

-- JSONB GIN index
CREATE INDEX idx_products_attributes ON products USING gin (attributes);
-- attributes is a JSONB column

-- Query JSON data efficiently
SELECT * FROM products
WHERE attributes @> '{"color": "red", "size": "M"}';
-- @> is the "contains" operator — uses GIN

-- Array containment
CREATE INDEX idx_tags ON posts USING gin (tags);  -- tags is integer[]
SELECT * FROM posts WHERE tags @> '{5, 12}';  -- posts with both tags 5 and 12
```

**GIN vs GiST Comparison**

| Feature | GIN | GiST |
|---|---|---|
| Best for | Full-text, arrays, JSONB | Geometric, range, nearest-neighbor |
| Lookup speed | Faster (exact inverted index) | Slightly slower (lossy in some ops) |
| Build time | Slower, larger | Faster, smaller |
| Update cost | Higher (pending list helps) | Lower |
| Operators | `@@`, `@>`, `<@`, `?`, `?&` | `&&`, `<<`, `>>`, `<->` (KNN) |

```sql
-- GiST for geometric/range types
CREATE INDEX idx_reservations_period ON reservations USING gist (during);
-- during is tstzrange

-- Find overlapping reservations
SELECT * FROM reservations
WHERE during && '[2024-06-01, 2024-06-10)'::tstzrange;

-- GiST for PostGIS geographic queries
CREATE INDEX idx_locations_point ON locations USING gist (coordinates);
SELECT *, ST_Distance(coordinates, ST_MakePoint(-73.9857, 40.7484)) AS dist
FROM locations
WHERE ST_DWithin(coordinates, ST_MakePoint(-73.9857, 40.7484), 1000)
ORDER BY dist
LIMIT 10;
-- KNN (nearest-neighbor) scan using GiST index

-- pg_trgm: GIN or GiST for LIKE/ILIKE with trigrams
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_users_name_trgm ON users USING gin (name gin_trgm_ops);
-- Now supports: LIKE '%smith%', ILIKE '%Smith%' with index
SELECT * FROM users WHERE name ILIKE '%smith%';
```

**BRIN Index (Block Range INdex) — Bonus**

```sql
-- BRIN: extremely small index for naturally-ordered data (logs, time-series)
CREATE INDEX idx_events_created_brin ON events USING brin (created_at);
-- 128-page blocks, stores only (min, max) per block range
-- 100x smaller than B-tree; only useful if data is physically sorted by created_at
```

**Real-World Example:**

Stripe's invoice search feature needed to support full-text search across invoice descriptions (500M rows). The team evaluated Elasticsearch but found PostgreSQL GIN on tsvector sufficient for their latency SLA (<50ms p99). The GIN index on the generated `search_vector` column was 8 GB vs. the 180 GB table — 22x smaller. For advanced fuzzy matching (`ilike '%stripe%'`), they added `pg_trgm` GIN indexes. Total search infrastructure remained in PostgreSQL, avoiding an additional system.

**Code Example:**

```sql
-- Complete example: multi-type index strategy on a product catalog
CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    price NUMERIC(12,2),
    attributes JSONB,
    tags INTEGER[],
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 1. Partial index: active products only
CREATE INDEX idx_products_active_price
ON products (price) WHERE deleted_at IS NULL;

-- 2. Functional index: case-insensitive name search
CREATE INDEX idx_products_name_lower
ON products (LOWER(name)) WHERE deleted_at IS NULL;

-- 3. GIN on JSONB: attribute filtering
CREATE INDEX idx_products_attrs
ON products USING gin (attributes);

-- 4. GIN on array: tag filtering
CREATE INDEX idx_products_tags
ON products USING gin (tags);

-- 5. Full-text search
ALTER TABLE products ADD COLUMN search_vec tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('english', name), 'A') ||
        setweight(to_tsvector('english', COALESCE(description, '')), 'B')
    ) STORED;
CREATE INDEX idx_products_fts ON products USING gin (search_vec);

-- Query combining multiple indexes
SELECT id, name, price
FROM products
WHERE deleted_at IS NULL                    -- → partial index
  AND LOWER(name) LIKE 'widget%'            -- → functional index (prefix ok for B-tree)
  AND attributes @> '{"brand": "Acme"}'    -- → GIN JSONB
  AND search_vec @@ to_tsquery('blue & durable')  -- → GIN FTS
ORDER BY price;
```

**Follow-up Questions:**
1. Why must functions used in PostgreSQL expression indexes be marked IMMUTABLE?
2. What is the GIN "pending list" and how does it affect write performance?
3. When would you choose GiST over GIN for full-text search?

**Common Mistakes:**
- Creating a partial index but not including the partial condition in the query — the index will not be used.
- Using a GIN index for equality lookups on single-valued columns — B-tree is faster and smaller.

**Interview Traps:**
- "Can MySQL do full-text search with GIN?" — No; MySQL uses FULLTEXT indexes (inverted index, different syntax: `MATCH() AGAINST()`). GIN is PostgreSQL-specific.
- "Is a functional index maintained automatically?" — Yes, PostgreSQL maintains it on every write that affects the indexed expression. The expression is re-evaluated on each modified row.

**Quick Revision:** Partial indexes reduce size and write overhead by indexing only matching rows; functional indexes index expression results for operations like LOWER(); GIN inverted indexes enable efficient containment, full-text, and JSONB array queries that B-tree cannot handle.

---

### Topic 7: When NOT to Index

**Difficulty:** Medium | **Frequency:** High | **Companies:** All FAANG, Shopify, Atlassian, Grab

**Q:** What are the situations where adding an index would actually hurt performance? How do you identify over-indexing?

**Short Answer:**
Indexes hurt performance when write overhead exceeds read benefit: small tables (seq scan is faster), low-selectivity columns (optimizer skips the index anyway), write-heavy tables (every DML updates all indexes), and redundant/duplicate indexes (waste storage and write cycles). Over-indexing is one of the most common production database performance mistakes.

**Deep Explanation:**

**1. Small Tables**

For tables with fewer than a few hundred to a few thousand rows, a sequential scan is faster than an index lookup:
- All pages likely fit in the buffer pool (one cache hit)
- B-tree traversal has fixed overhead (3–5 page reads minimum)
- PostgreSQL optimizer will choose seq scan automatically

```sql
-- Lookup table with 50 country codes — index is wasteful
CREATE TABLE countries (code CHAR(2) PRIMARY KEY, name VARCHAR(100));
-- 50 rows: PostgreSQL will always seq scan regardless of indexes
```

**2. Low-Selectivity Columns**

Covered in Topic 4 — boolean, status with few values, gender. Adding the index wastes storage and write I/O. The optimizer will choose seq scan when selectivity is poor.

**3. Write-Heavy Tables**

Every INSERT/UPDATE/DELETE updates every index on the table. The overhead is:
- Lock acquisition on index pages
- B-tree traversal to find insertion point
- Potential page split (random I/O, cascading updates)
- WAL entries for each index page modification (PostgreSQL)
- InnoDB change buffer interactions

```
Impact formula (approx):
  Write cost = base_row_write + Σ(cost per index)
  For 10 indexes: write cost ≈ 5-10x base row write
```

Real example: a `click_events` table receiving 100K inserts/second with 8 indexes. Dropping 5 read-mostly indexes increased insert throughput from 80K/s to 140K/s.

**4. Redundant and Duplicate Indexes**

```sql
-- Duplicate: same columns, same order
CREATE INDEX idx_a ON orders (customer_id);
CREATE INDEX idx_b ON orders (customer_id);  -- exact duplicate, wasted

-- Redundant: prefix is already covered by a wider index
CREATE INDEX idx_c ON orders (customer_id, created_at);
CREATE INDEX idx_d ON orders (customer_id);  -- redundant: idx_c covers all customer_id queries

-- Both idx_d and idx_c will be maintained on every write
-- But idx_d is never used: optimizer prefers idx_c (covers more)
```

**5. Columns That Are Rarely Queried**

An index on a column that appears in only 0.01% of queries is pure write overhead for 99.99% of operations.

**6. Columns With Heavy Correlation to PK**

If a column's value is always derived from or nearly identical to the PK (e.g., `created_at` on an auto-increment PK table where rows are always inserted in time order), a BRIN index is far more appropriate than a B-tree.

**Detecting Over-Indexing**

```sql
-- PostgreSQL: find unused indexes
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS scans_since_reset,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0  -- never used since last stats reset
  AND schemaname NOT IN ('pg_catalog', 'pg_toast')
ORDER BY pg_relation_size(indexrelid) DESC;

-- Find duplicate indexes (same columns, same order)
SELECT
    pg_indexes.indexname,
    pg_indexes.tablename,
    pg_indexes.indexdef
FROM pg_indexes
JOIN pg_indexes AS pi2 ON
    pg_indexes.tablename = pi2.tablename
    AND pg_indexes.indexdef = pi2.indexdef
    AND pg_indexes.indexname > pi2.indexname;

-- MySQL: unused indexes (requires performance_schema)
SELECT object_schema, object_name, index_name, count_star
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE index_name IS NOT NULL
  AND count_star = 0
  AND object_schema NOT IN ('mysql', 'information_schema', 'performance_schema')
ORDER BY object_schema, object_name;
```

**Index Maintenance Overhead at Scale**

```
Table: order_events (1B rows, 15 indexes)
INSERT rate: 50K/s
Index write amplification: ~15x
Actual disk write rate: 50K × 15 × avg_index_entry_size ≈ significant IOPS

After index audit: reduced to 8 indexes
Write amplification: ~8x
IOPS reduction: ~47%
```

**Real-World Example:**

GitHub's engineering blog documented a `notifications` table with 23 indexes (accumulated over years of feature additions). Many were for ad-hoc reports that were later replaced by a data warehouse. After an index audit:
- 8 indexes were identified as never-used (0 scans in 30 days via `pg_stat_user_indexes`)
- 4 were redundant (prefix-covered by wider indexes)
- Dropping 12 indexes reduced notification INSERT latency from 8ms p99 to 2ms p99

**Code Example:**

```sql
-- Full index audit workflow (PostgreSQL)

-- Step 1: Reset statistics (do this, then wait 1-2 weeks of production traffic)
SELECT pg_stat_reset();

-- Step 2: After monitoring period, find candidates for removal
WITH index_usage AS (
    SELECT
        i.schemaname,
        i.tablename,
        i.indexname,
        i.indexdef,
        s.idx_scan,
        s.idx_tup_read,
        pg_size_pretty(pg_relation_size(s.indexrelid)) AS size,
        pg_relation_size(s.indexrelid) AS size_bytes
    FROM pg_indexes i
    JOIN pg_stat_user_indexes s ON i.indexname = s.indexname
    WHERE i.schemaname = 'public'
)
SELECT *
FROM index_usage
WHERE idx_scan < 10  -- fewer than 10 scans since reset
  AND indexname NOT LIKE '%_pkey'  -- keep primary keys
  AND indexname NOT LIKE '%_unique%'  -- keep unique constraints
ORDER BY size_bytes DESC;

-- Step 3: Safely "remove" without dropping (PostgreSQL 9.2+)
-- Mark as invalid to test impact before dropping
-- (Cannot be done directly, but can create without it and monitor)

-- Step 4: Drop safely with CONCURRENTLY (no table lock)
DROP INDEX CONCURRENTLY idx_orders_old_unused;

-- Step 5: Monitor write performance after removal
SELECT
    relname,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    (n_tup_ins + n_tup_upd + n_tup_del) AS total_writes
FROM pg_stat_user_tables
WHERE relname = 'orders';
```

**Follow-up Questions:**
1. How long should you monitor `pg_stat_user_indexes` before declaring an index "unused"? What seasonal patterns could mislead you?
2. What is the risk of dropping an index that is used by a unique constraint or foreign key?
3. How do you safely test the impact of dropping an index without actually dropping it?

**Common Mistakes:**
- Dropping an index without checking if it enforces a unique constraint or is used as a foreign key reference — the constraint disappears with the index in PostgreSQL.
- Only monitoring for one day before deciding an index is unused — monthly or quarterly reports may use it.

**Interview Traps:**
- "More indexes = better read performance" — Not true beyond the needed set; extra indexes reduce write performance and increase buffer pool pressure (less room for data pages).
- "Unused indexes have zero cost" — False; they still consume write I/O, WAL bandwidth, autovacuum time, and storage.

**Quick Revision:** Index when reads outweigh the write cost — avoid indexes on small tables (seq scan wins), low-selectivity columns (optimizer skips them), rarely-queried columns, and redundant duplicates; audit with pg_stat_user_indexes after weeks of production traffic.

---

### Topic 8: Index Usage in JPA/Hibernate — @Index Annotation, Spring Data JPA Optimization

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Atlassian, Booking.com, SAP, IBM

**Q:** How do you define database indexes in a JPA/Hibernate entity? How do you ensure Spring Data JPA derived queries use indexes efficiently?

**Short Answer:**
Indexes are declared on JPA entities using `@Index` inside `@Table(indexes = {...})` or `@Index` on column-level for simple cases. Hibernate's `hbm2ddl` schema generation will create them, but production deployments should use Flyway/Liquibase migrations instead. Spring Data JPA derived query methods generate SQL that must match index definitions to avoid full table scans.

**Deep Explanation:**

**Declaring Indexes in JPA Entities**

```java
@Entity
@Table(
    name = "orders",
    indexes = {
        // Single-column index
        @Index(name = "idx_orders_customer_id", columnList = "customer_id"),

        // Composite index — column order matters (leftmost prefix rule applies)
        @Index(name = "idx_orders_customer_status", columnList = "customer_id, status"),

        // Composite with descending (JPA 2.2+: append DESC)
        @Index(name = "idx_orders_created_desc", columnList = "customer_id, created_at DESC"),

        // Unique index
        @Index(name = "uq_orders_external_ref", columnList = "external_reference", unique = true)
    }
)
public class Order {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "customer_id", nullable = false)
    private Long customerId;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

    @Column(name = "external_reference", unique = true)
    private String externalReference;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "total_amount", precision = 12, scale = 2)
    private BigDecimal totalAmount;
}
```

**Index Name Convention**

Use consistent naming to avoid conflicts across environments:
- `idx_{table}_{columns}` for regular indexes
- `uq_{table}_{column}` for unique indexes
- `fk_{table}_{referenced_table}` for foreign key indexes

**Composite Index for Derived Queries**

Spring Data JPA generates SQL from method names. The generated SQL must match the index to be used:

```java
@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {

    // Generated: SELECT * FROM orders WHERE customer_id = ?
    // Uses: idx_orders_customer_id
    List<Order> findByCustomerId(Long customerId);

    // Generated: SELECT * FROM orders WHERE customer_id = ? AND status = ?
    // Uses: idx_orders_customer_status (if customer_id comes first in the index)
    List<Order> findByCustomerIdAndStatus(Long customerId, String status);

    // Generated: SELECT * FROM orders WHERE customer_id = ? AND created_at > ?
    // Uses: composite index (customer_id, created_at) if defined
    List<Order> findByCustomerIdAndCreatedAtAfter(Long customerId, LocalDateTime after);

    // PROBLEM: this generates WHERE status = ? AND customer_id = ?
    // SQL WHERE clause order does NOT matter for index usage (optimizer reorders)
    // But the INDEX column order does matter
    List<Order> findByStatusAndCustomerId(String status, Long customerId);
    // This still uses idx_orders_customer_status because optimizer knows the index
}
```

**@Query Annotation with JPQL — Index Awareness**

```java
// JPQL query — Hibernate translates to SQL
@Query("SELECT o FROM Order o WHERE o.customerId = :customerId AND o.status = :status " +
       "ORDER BY o.createdAt DESC")
List<Order> findActiveOrdersByCustomer(
    @Param("customerId") Long customerId,
    @Param("status") String status,
    Pageable pageable
);

// Optimal index for this query:
// @Index(name = "idx_orders_customer_status_created",
//        columnList = "customer_id, status, created_at DESC")
```

**Native Query with Index Hints**

```java
// PostgreSQL: force index via native query (use sparingly — only diagnostic)
@Query(value = "SELECT * FROM orders WHERE customer_id = :customerId " +
               "ORDER BY created_at DESC LIMIT 10",
       nativeQuery = true)
List<Order> findLatestOrdersNative(@Param("customerId") Long customerId);

// MySQL: index hint in native query
@Query(value = "SELECT * FROM orders USE INDEX (idx_orders_customer_status) " +
               "WHERE customer_id = :customerId AND status = :status",
       nativeQuery = true)
List<Order> findWithHint(@Param("customerId") Long customerId,
                          @Param("status") String status);
```

**Schema Migration Best Practice**

Never rely on `hbm2ddl.auto=create` or `update` in production. Use Flyway or Liquibase:

```sql
-- V15__add_order_indexes.sql (Flyway migration)
CREATE INDEX CONCURRENTLY idx_orders_customer_id
    ON orders (customer_id);

CREATE INDEX CONCURRENTLY idx_orders_customer_status
    ON orders (customer_id, status);

-- PostgreSQL: CONCURRENTLY avoids table lock
-- MySQL: CREATE INDEX is online by default in 8.0 with algorithm=inplace
```

```java
// application.yml — disable auto DDL in production
spring:
  jpa:
    hibernate:
      ddl-auto: validate  # validates schema matches entity; never modifies
  flyway:
    enabled: true
    locations: classpath:db/migration
```

**Detecting N+1 and Missing Index via Hibernate Statistics**

```java
// Enable SQL logging to spot N+1 queries that bypass indexes
// application.yml
spring:
  jpa:
    show-sql: true
    properties:
      hibernate:
        format_sql: true
        generate_statistics: true
        session.events.log.LOG_QUERIES_SLOWER_THAN_MS: 100

// Programmatic statistics
SessionFactory sf = entityManager.getEntityManagerFactory()
    .unwrap(SessionFactory.class);
Statistics stats = sf.getStatistics();
stats.setStatisticsEnabled(true);

// After executing queries:
log.info("Query count: {}", stats.getQueryExecutionCount());
log.info("Max query time: {}ms", stats.getQueryExecutionMaxTime());
log.info("Slow query: {}", stats.getQueryExecutionMaxTimeQueryString());
```

**@NaturalId — Index for Business Keys**

```java
@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue
    private Long id;  // PK / clustered key

    @NaturalId
    @Column(name = "email", unique = true)
    private String email;  // Hibernate automatically creates unique index
}

// Repository: natural ID lookup uses the unique index
userRepository.findByEmail("alice@example.com");  // uses unique index
```

**Real-World Example:**

A Spring Boot microservice at Atlassian processed Jira issue searches. The `Issue` entity had 14 `@Index` annotations accumulated over 3 years. A query `findByProjectKeyAndAssigneeIdAndStatusIn(...)` generated SQL that used only the `(project_key)` index — the full composite `(project_key, assignee_id)` was missing. Adding the composite index and adjusting the `@Table(indexes = {...})` annotation + Flyway migration reduced the query from 800ms to 12ms on a 50M-row table. The team also added `ddl-auto: validate` to catch schema/entity drift on deploy.

**Code Example:**

```java
// Complete entity with production-ready index configuration
@Entity
@Table(
    name = "orders",
    indexes = {
        @Index(
            name = "idx_orders_customer_status",
            columnList = "customer_id, status"
        ),
        @Index(
            name = "idx_orders_customer_created",
            columnList = "customer_id, created_at DESC"
        ),
        @Index(
            name = "idx_orders_created_at",
            columnList = "created_at"
        )
    },
    uniqueConstraints = {
        @UniqueConstraint(
            name = "uq_orders_external_ref",
            columnNames = {"external_reference"}
        )
    }
)
@EntityListeners(AuditingEntityListener.class)
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "customer_id", nullable = false)
    @NotNull
    private Long customerId;

    @Column(name = "status", nullable = false, length = 20)
    @NotBlank
    private String status;

    @Column(name = "external_reference", length = 64)
    private String externalReference;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "total_amount", precision = 12, scale = 2)
    private BigDecimal totalAmount;
}

// Repository aligned to index design
@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {

    // Uses idx_orders_customer_status (equality on both)
    Page<Order> findByCustomerIdAndStatus(
        Long customerId, String status, Pageable pageable);

    // Uses idx_orders_customer_created (equality + range)
    List<Order> findByCustomerIdAndCreatedAtBetween(
        Long customerId, LocalDateTime from, LocalDateTime to);

    // Avoid: findByStatus alone — low selectivity, no leading column index
    // Instead, always include customerId in the predicate

    // Projection to enable covering index scan (only fetch indexed columns)
    @Query("SELECT new com.example.OrderSummary(o.id, o.status, o.createdAt) " +
           "FROM Order o WHERE o.customerId = :customerId AND o.status = :status")
    List<OrderSummary> findSummaryByCustomerIdAndStatus(
        @Param("customerId") Long customerId,
        @Param("status") String status);
}
```

**Follow-up Questions:**
1. What is the difference between `@Index` in `@Table` and `@Column(unique = true)`? When does each create a database index?
2. How do JPA projections (interfaces or DTOs) help achieve index-only scans in Hibernate?
3. What is `hbm2ddl.auto=validate`, and why should it be the production setting?

**Common Mistakes:**
- Using `hbm2ddl.auto=update` in production — Hibernate cannot safely modify production schemas (cannot add indexes CONCURRENTLY, may lock tables).
- Forgetting that `@Column(unique = true)` creates an implicit unique index — it is equivalent to a `@UniqueConstraint` but less visible when auditing indexes.

**Interview Traps:**
- "Does JPA automatically create indexes for `@ManyToOne` foreign key columns?" — No; JPA creates the FK constraint but NOT an index on the FK column in the child table. You must manually add `@Index` for FK columns — this is a very common omission causing slow JOIN queries.
- "Does the ORDER of columns in `columnList` in `@Index` matter?" — Yes, critically. It is directly the index column order in the B-tree, following the leftmost prefix rule.

**Quick Revision:** Declare indexes via `@Table(indexes = {@Index(columnList = "col1, col2")})` matching your query predicates' leftmost prefix; use Flyway with CONCURRENTLY in production instead of hbm2ddl; always manually index FK columns since JPA does not do it automatically.

---

## Chapter 15 Part A — Quick Reference

| Topic | Key Takeaway | Common Question |
|---|---|---|
| B-tree internals | Leaf nodes linked as list; O(log n) lookup; write = update all indexes | "Why does adding 10 indexes slow inserts?" |
| Hash vs B-tree | Hash: O(1) equality only; B-tree: equality + range + sort | "When use hash index in PostgreSQL?" |
| Composite index | Leftmost prefix; equality→range→sort order; INCLUDE for covering | "Design index for WHERE a=? AND b>? ORDER BY c" |
| Selectivity | high selectivity = index useful; low cardinality → partial index | "Should I index a boolean column?" |
| Clustered vs non-clustered | InnoDB: PK=clustered; secondary indexes double-dip | "UUID vs BIGINT PK in InnoDB?" |
| Special index types | Partial (subset), Functional (expression), GIN (JSONB/FTS), GiST (geo/range) | "How to do full-text search in PostgreSQL?" |
| When not to index | Small tables, low selectivity, write-heavy, redundant — audit with pg_stat_user_indexes | "How to find unused indexes?" |
| JPA indexes | @Table(indexes={}), columnList order matters, FK columns need manual @Index | "Does JPA auto-index @ManyToOne FK?" |

---

*Continue to Part B: Query Optimization — EXPLAIN plans, join strategies, CTEs, window functions, and N+1 query detection.*


---

# Chapter 15 — Database Indexing & Query Optimization
## Part B: Topics 9–15 + Cheat Sheet

---

### Topic 9: EXPLAIN & Execution Plans

**Difficulty:** 4/5 | **Frequency:** 5/5 | **Companies:** Google, Amazon, Meta, Uber, Stripe, Shopify

**Q:** How do you read a PostgreSQL EXPLAIN output, and what do the different node types tell you about query performance?

**Short Answer:**
EXPLAIN shows the planner's chosen execution tree, where each node represents an operation (scan, join, sort). Cost estimates are in arbitrary units (page fetches), and actual row counts from EXPLAIN ANALYZE reveal estimation errors that cause bad plans.

**Deep Explanation:**

PostgreSQL's query planner generates an execution plan tree bottom-up. Each node has:
- `cost=startup..total` — estimated cost before first row (startup) and for all rows (total)
- `rows=N` — estimated row count
- `width=N` — average row width in bytes
- `actual time=X..Y` — real elapsed ms (EXPLAIN ANALYZE only)
- `actual rows=N loops=N` — real row count × loop iterations

**Scan Node Types:**

| Node | Trigger | Performance |
|------|---------|-------------|
| `Seq Scan` | No usable index, or planner deems it cheaper | O(N) full table read |
| `Index Scan` | Selective predicate, index available | Random I/O; good for < ~5% of rows |
| `Index Only Scan` | All needed columns in index (covering index) | No heap access; fastest |
| `Bitmap Index Scan` + `Bitmap Heap Scan` | Medium selectivity (5–20% of rows) | Batches heap access to reduce random I/O |

**Join Algorithms:**

| Algorithm | Best For | Complexity |
|-----------|---------|------------|
| `Nested Loop` | Small outer, indexed inner | O(N × M) but inner is index lookup |
| `Hash Join` | Larger tables, equality joins, no sort order needed | O(N+M) with hash build cost |
| `Merge Join` | Pre-sorted inputs or sort is cheap | O(N log N + M log M) |

**Cost Model:**
PostgreSQL cost = `seq_page_cost` (default 1.0) × pages + `random_page_cost` (default 4.0) × random pages + `cpu_tuple_cost` × rows + `cpu_operator_cost` × operations. Lowering `random_page_cost` to 1.1 on SSDs encourages index scans.

**Key EXPLAIN ANALYZE Patterns:**
- `rows=1 actual rows=10000` → stale statistics → run ANALYZE
- `Hash Batches: 8` → hash join spilled to disk → increase `work_mem`
- `Buffers: shared hit=X read=Y` → cache miss ratio (requires `EXPLAIN (ANALYZE, BUFFERS)`)

**Real-World Example:**
An e-commerce order query runs in 8 seconds. EXPLAIN ANALYZE shows `Seq Scan on orders (cost=0..450000 rows=2000000)` followed by a `Hash Join`. The actual rows on the inner table is 50,000 but estimated at 200 — stale stats on a recently loaded table. After `ANALYZE orders`, the planner switches to `Index Scan + Nested Loop`, reducing time to 40ms.

**Code Example:**
```sql
-- Full execution plan with buffers and timing
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT o.id, o.total, c.email
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.status = 'PENDING'
  AND o.created_at > NOW() - INTERVAL '7 days';

-- Typical output interpretation:
-- Hash Join  (cost=1250.00..8900.00 rows=450 width=48)
--            (actual time=12.3..89.4 rows=312 loops=1)
--   Hash Cond: (o.customer_id = c.id)
--   Buffers: shared hit=892 read=124
--   ->  Bitmap Heap Scan on orders  (cost=45..6200 rows=450 width=32)
--         Recheck Cond: ((status = 'PENDING') AND (created_at > ...))
--         Buffers: shared hit=210 read=120
--         ->  Bitmap Index Scan on idx_orders_status_created
--               Index Cond: (...)
--   ->  Hash  (cost=820..820 rows=30000 width=24)
--         Buckets: 32768  Batches: 1  Memory Usage: 1873kB
--         ->  Seq Scan on customers  (cost=0..820 rows=30000 width=24)

-- Force/disable specific strategies for testing
SET enable_seqscan = OFF;
SET enable_hashjoin = OFF;
SET random_page_cost = 1.1;  -- SSD setting
```

**Follow-up Questions:**
1. What does "Buffers: shared read" vs "shared hit" tell you, and how do you reduce read counts?
2. When would you prefer a Bitmap Heap Scan over an Index Scan even with high selectivity?
3. How does `work_mem` affect Hash Join and Sort node performance?

**Common Mistakes:**
- Reading only the top-level cost and ignoring inner nodes where the real bottleneck lives
- Forgetting that EXPLAIN without ANALYZE shows estimated, not actual, row counts
- Not using `EXPLAIN (ANALYZE, BUFFERS)` — missing buffer data hides I/O bottlenecks

**Interview Traps:**
- "A query has cost=0..5 but runs in 10 seconds" — cost is in planner units, not ms; always use ANALYZE for real timing
- Assuming Seq Scan is always bad — on small tables or returning > 20% of rows it's often optimal

**Quick Revision:** EXPLAIN ANALYZE shows the actual vs estimated rows per node; large discrepancies mean stale stats; Hash Join spills if batches > 1; lower random_page_cost on SSDs to prefer index scans.

---

### Topic 10: Slow Query Optimization

**Difficulty:** 4/5 | **Frequency:** 5/5 | **Companies:** Amazon, Uber, LinkedIn, DoorDash, Twilio

**Q:** Walk through your complete process for identifying and fixing a slow query in a production PostgreSQL database.

**Short Answer:**
Start by capturing slow queries via `slow query log` or `pg_stat_statements`, then use EXPLAIN ANALYZE to find the bottleneck node. Common fixes are adding indexes, rewriting correlated subqueries as joins, or updating stale statistics.

**Deep Explanation:**

**Step 1 — Identify Slow Queries:**

PostgreSQL `pg_stat_statements` extension tracks cumulative execution statistics. Key columns:
- `total_exec_time` / `calls` = average execution time
- `stddev_exec_time` — high variance indicates inconsistent performance (sometimes cached, sometimes not)
- `rows` / `calls` — average rows returned
- `shared_blks_read` — disk I/O pressure

MySQL slow query log: set `long_query_time = 1` and `log_queries_not_using_indexes = ON`.

**Step 2 — Analyze the Plan:**
Run `EXPLAIN (ANALYZE, BUFFERS)` during off-peak or on a staging replica with production data volume.

**Step 3 — Common Root Causes and Fixes:**

| Problem | Symptom in EXPLAIN | Fix |
|---------|-------------------|-----|
| Missing index | Seq Scan on large table | CREATE INDEX |
| Wrong index | Index Scan but high cost | Composite index with correct column order |
| Stale statistics | Estimated rows << actual rows | ANALYZE table |
| Correlated subquery | Subquery node with `loops=N` per outer row | Rewrite as JOIN or lateral |
| N+1 in ORM | Many identical plans with different bind values | Eager load / JOIN fetch |
| Implicit type cast | `Filter: (id::text = ...)` preventing index use | Match parameter type to column type |

**Correlated Subquery Rewrite:**
```sql
-- SLOW: correlated subquery executes once per order row
SELECT o.id
FROM orders o
WHERE o.total > (
    SELECT AVG(total) FROM orders WHERE customer_id = o.customer_id
);

-- FAST: lateral join / CTE computed once per customer
SELECT o.id
FROM orders o
JOIN (
    SELECT customer_id, AVG(total) AS avg_total
    FROM orders
    GROUP BY customer_id
) avg_by_cust ON avg_by_cust.customer_id = o.customer_id
WHERE o.total > avg_by_cust.avg_total;
```

**Real-World Example:**
A notification service query takes 4 seconds. `pg_stat_statements` shows it runs 10,000 times/minute. EXPLAIN reveals `Seq Scan on notifications (rows=5000000)` with filter `WHERE user_id = $1 AND read = false`. Adding a partial index `CREATE INDEX idx_unread ON notifications(user_id) WHERE read = false` drops query time to 2ms and eliminates the seq scan.

**Code Example:**
```sql
-- Enable pg_stat_statements (postgresql.conf)
-- shared_preload_libraries = 'pg_stat_statements'
-- pg_stat_statements.track = all

-- Find top 10 slowest queries by total time
SELECT
    round(total_exec_time::numeric, 2) AS total_ms,
    calls,
    round(mean_exec_time::numeric, 2) AS avg_ms,
    round(stddev_exec_time::numeric, 2) AS stddev_ms,
    round((shared_blks_read * 8192 / 1024.0 / 1024.0)::numeric, 2) AS disk_read_mb,
    left(query, 100) AS query_snippet
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Find queries with worst estimation error (stale stats indicator)
EXPLAIN (ANALYZE, FORMAT JSON)
SELECT * FROM orders WHERE customer_id = 42 AND status = 'PENDING';
-- Check: "Plan Rows" vs "Actual Rows" ratio > 10x = stale stats

-- PostgreSQL slow query log settings (postgresql.conf)
-- log_min_duration_statement = 1000   # log queries > 1s
-- log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
-- log_lock_waits = on
-- deadlock_timeout = 1s
```

**Follow-up Questions:**
1. How do you safely test index changes on a production table with 500 million rows without locking it?
2. What is `CREATE INDEX CONCURRENTLY` and what are its limitations?
3. How do you detect N+1 queries in a Spring/Hibernate application?

**Common Mistakes:**
- Adding indexes reactively one-by-one without considering composite index opportunities
- Running EXPLAIN on a different database than production (different data distribution = different plan)
- Not resetting `pg_stat_statements` after a schema change, making old stats mislead

**Interview Traps:**
- "Just add an index on every column" — indexes have write overhead and can actually slow INSERT/UPDATE/DELETE
- Assuming the ORM generates optimal SQL — always log and inspect actual queries in production

**Quick Revision:** pg_stat_statements + EXPLAIN ANALYZE is your diagnostic stack; look for seq scans on large tables, high loop counts on subqueries, and estimation errors > 10x as the three main signals.

---

### Topic 11: Query Optimization Techniques

**Difficulty:** 3/5 | **Frequency:** 5/5 | **Companies:** Google, Amazon, Meta, Atlassian, Grab

**Q:** What are the key query-writing techniques that improve performance, and when does each apply?

**Short Answer:**
Effective query optimization requires avoiding anti-patterns (SELECT *, functions on indexed columns, OR predicates) and applying structural rewrites (predicate pushdown, UNION over OR, covering indexes). The goal is to maximize index usage and minimize rows processed early in the plan.

**Deep Explanation:**

**1. Avoid SELECT ***
- Forces full row read even for covering index scenarios
- Breaks if table schema changes (ORM deserialization errors)
- Use explicit column list; add needed columns to covering index

**2. Push Predicates Early (Predicate Pushdown)**
The planner usually does this, but complex views and subqueries can block it:
```sql
-- BAD: filter applied after expensive join
SELECT * FROM (SELECT * FROM orders JOIN customers ...) sub WHERE sub.status = 'ACTIVE';

-- GOOD: filter applied before join
SELECT * FROM orders o JOIN customers c ON ... WHERE o.status = 'ACTIVE';
```

**3. Avoid Functions on Indexed Columns**
Functions on the left side of a predicate prevent index usage:
```sql
-- BAD: index on created_at unusable
WHERE DATE(created_at) = '2024-01-15'
WHERE LOWER(email) = 'user@example.com'
WHERE EXTRACT(YEAR FROM created_at) = 2024

-- GOOD: use range predicate or functional index
WHERE created_at >= '2024-01-15' AND created_at < '2024-01-16'
-- OR: CREATE INDEX ON users (LOWER(email));
```

**4. Rewrite OR as UNION**
OR predicates on different columns prevent index usage; UNION ALL uses an index per branch:
```sql
-- BAD: full table scan (planner may not use either index)
SELECT * FROM users WHERE email = 'a@b.com' OR phone = '555-1234';

-- GOOD: each branch uses its own index
SELECT * FROM users WHERE email = 'a@b.com'
UNION ALL
SELECT * FROM users WHERE phone = '555-1234' AND email != 'a@b.com';
```

**5. Use CTEs Wisely**
In PostgreSQL ≥ 12, CTEs are NOT optimization fences by default (unless `MATERIALIZED` is specified). In older versions they were always materialized.
```sql
-- PostgreSQL 12+: planner can inline this CTE
WITH recent_orders AS (
    SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '30 days'
)
SELECT * FROM recent_orders WHERE status = 'PENDING';

-- Force materialization when CTE is referenced multiple times
WITH MATERIALIZED expensive_calc AS (
    SELECT customer_id, SUM(total) FROM orders GROUP BY customer_id
)
SELECT * FROM expensive_calc WHERE ...;
```

**6. Use EXISTS over IN for Subqueries**
EXISTS short-circuits on first match; IN evaluates all rows:
```sql
-- Potentially slow (evaluates entire subquery)
WHERE customer_id IN (SELECT id FROM customers WHERE tier = 'PREMIUM')

-- Faster (short-circuits)
WHERE EXISTS (SELECT 1 FROM customers c WHERE c.id = o.customer_id AND c.tier = 'PREMIUM')
```

**7. Covering Indexes for Read-Heavy Queries**
Include all columns in the index to enable Index Only Scan:
```sql
-- Query: SELECT id, status, total FROM orders WHERE customer_id = 42
-- Covering index: includes all needed columns
CREATE INDEX idx_orders_cust_covering ON orders(customer_id) INCLUDE (status, total);
```

**Real-World Example:**
A reporting query uses `WHERE YEAR(order_date) = 2024` in MySQL — full table scan on 200M rows. Rewriting to `WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'` and adding index on `order_date` reduces query time from 45s to 120ms.

**Code Example:**
```sql
-- Anti-pattern: implicit type coercion prevents index use
-- users.id is INTEGER, but param passed as VARCHAR
WHERE id = '12345'  -- index on id(int) not used in some DBs

-- Anti-pattern: negation usually forces seq scan
WHERE status != 'CANCELLED'  -- use positive predicate when possible
WHERE status IN ('PENDING', 'ACTIVE', 'SHIPPED')  -- better

-- Partial index for common filter
CREATE INDEX idx_active_users ON users(email) WHERE deleted_at IS NULL;

-- Use LIMIT with ORDER BY for pagination — needs index on sort column
SELECT id, name FROM products
ORDER BY created_at DESC LIMIT 20 OFFSET 0;
-- Index: CREATE INDEX ON products(created_at DESC);
-- For deep pagination, use keyset pagination instead:
WHERE created_at < :last_seen_created_at ORDER BY created_at DESC LIMIT 20;

-- Rewrite correlated subquery count
-- BAD
SELECT c.id, (SELECT COUNT(*) FROM orders WHERE customer_id = c.id) AS order_count
FROM customers c;

-- GOOD
SELECT c.id, COALESCE(o.order_count, 0) AS order_count
FROM customers c
LEFT JOIN (SELECT customer_id, COUNT(*) AS order_count FROM orders GROUP BY customer_id) o
    ON o.customer_id = c.id;
```

**Follow-up Questions:**
1. When should you use a materialized CTE vs an inline CTE in PostgreSQL 12+?
2. How does keyset pagination differ from OFFSET pagination, and why is it faster at large offsets?
3. Why can `NOT IN` with a nullable subquery return no rows unexpectedly?

**Common Mistakes:**
- Adding LIMIT without ORDER BY — non-deterministic results
- Using `COUNT(*)` vs `COUNT(column)` — COUNT(*) counts all rows, COUNT(col) skips NULLs
- Forgetting that `OR` between indexed columns may be better served by a multi-column index with good selectivity

**Interview Traps:**
- "EXISTS is always faster than IN" — false for small sets; IN with a small literal list is often optimized to an array lookup
- Assuming CTEs always materialize — depends on PostgreSQL version and `MATERIALIZED` keyword

**Quick Revision:** The golden rules: explicit columns over *, range predicates over functions, UNION over OR on different columns, EXISTS over IN for correlated checks, and covering indexes for hot read paths.

---

### Topic 12: Connection Pooling

**Difficulty:** 3/5 | **Frequency:** 4/5 | **Companies:** Amazon, Netflix, Uber, Stripe, Shopify

**Q:** How do you size a database connection pool, and what happens when the pool is exhausted?

**Short Answer:**
HikariCP's sizing formula is `connections = (core_count * 2) + effective_spindle_count`. Over-provisioning connections wastes memory and causes context-switching overhead; under-provisioning causes request queuing. Pool exhaustion results in timeout exceptions and cascading failures.

**Deep Explanation:**

**Why Connection Pools Exist:**
Opening a TCP connection to PostgreSQL is expensive (~10-30ms, ~5MB memory per backend process). A pool maintains warm connections and hands them to application threads.

**HikariCP Sizing Formula (Hikari's "About Pool Sizing"):**
```
connections = (core_count * 2) + effective_spindle_count
```
- `core_count` = CPU cores on the DB server (not app server)
- `effective_spindle_count` = 1 for SSD (no seek time), N for N spinning disk drives
- Example: 8-core DB on SSD → `(8 * 2) + 1 = 17 connections`
- This is per application instance; with 10 instances: pool size per instance = 17/10 ≈ 2-3

**HikariCP Key Properties:**

| Property | Default | Recommendation |
|---------|---------|---------------|
| `maximumPoolSize` | 10 | Use formula above |
| `minimumIdle` | = maximumPoolSize | Set equal to max for fixed pool |
| `connectionTimeout` | 30000ms | 3000-5000ms for fail-fast |
| `idleTimeout` | 600000ms | 300000ms (5 min) |
| `maxLifetime` | 1800000ms | < DB `wait_timeout` |
| `keepaliveTime` | 0 (disabled) | 60000ms to prevent firewall drops |
| `leakDetectionThreshold` | 0 | 5000ms in dev to find connection leaks |

**PgBouncer — Connection Pooler at DB Level:**
When you have many app instances, each with their own HikariCP pool, PostgreSQL can be overwhelmed with hundreds of connections. PgBouncer sits between app and DB:

| Mode | Use Case | Limitation |
|------|---------|-----------|
| Session mode | Default; compatible with all features | No multiplexing benefit |
| Transaction mode | High throughput; most use cases | Cannot use `SET`, prepared statements need `server_reset_query` |
| Statement mode | Autocommit only | Very limited use |

**Connection Pool Exhaustion Symptoms:**
- `SQLTimeoutException: Connection is not available, request timed out after 30000ms`
- Thread dump shows all threads waiting on `HikariPool.getConnection()`
- DB server shows < max_connections but app can't connect (pool is the bottleneck, not DB)

**Real-World Example:**
A Spring Boot service with 20 instances each configured with HikariCP `maximumPoolSize=50` — that's 1000 connections to a PostgreSQL server with `max_connections=200`. The DB rejects connections with "too many clients". Solution: add PgBouncer with transaction mode, reduce HikariCP pool to 5 per instance (20 × 5 = 100 → PgBouncer multiplexes to 50 DB connections).

**Code Example:**
```java
// Spring Boot application.yml — HikariCP configuration
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/mydb
    username: app_user
    password: ${DB_PASSWORD}
    hikari:
      maximum-pool-size: 10          # (core_count * 2) + spindle_count
      minimum-idle: 10               # fixed pool — equal to max
      connection-timeout: 3000       # fail fast, don't queue for 30s
      idle-timeout: 300000           # 5 min — return idle connections
      max-lifetime: 1740000          # 29 min — less than PostgreSQL's 30min timeout
      keepalive-time: 60000          # heartbeat to prevent firewall drops
      leak-detection-threshold: 5000 # warn if connection held > 5s (dev/staging)
      pool-name: MyServicePool
      connection-test-query: SELECT 1  # validation query
      data-source-properties:
        cachePrepStmts: true
        prepStmtCacheSize: 250
        prepStmtCacheSqlLimit: 2048

// Programmatic HikariCP configuration
@Bean
public DataSource dataSource() {
    HikariConfig config = new HikariConfig();
    config.setJdbcUrl("jdbc:postgresql://localhost:5432/mydb");
    config.setMaximumPoolSize(10);
    config.setConnectionTimeout(3000);
    config.setMaxLifetime(1740000);
    config.setLeakDetectionThreshold(5000);
    // Metric reporting via Micrometer
    config.setMetricRegistry(meterRegistry);
    return new HikariDataSource(config);
}
```

```ini
# PgBouncer pgbouncer.ini
[databases]
mydb = host=postgres-primary port=5432 dbname=mydb

[pgbouncer]
listen_port = 6432
listen_addr = *
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction        # transaction-level pooling
max_client_conn = 1000         # app-side connections
default_pool_size = 50         # backend connections to PostgreSQL
reserve_pool_size = 5
server_idle_timeout = 600
```

**Follow-up Questions:**
1. Why should `maxLifetime` be set lower than the database's `wait_timeout` or `idle_connection_timeout`?
2. What Spring Boot actuator metrics expose HikariCP pool utilization?
3. When would you use PgBouncer in session mode vs transaction mode?

**Common Mistakes:**
- Setting `maximumPoolSize` to 100+ thinking "more is better" — this causes DB-side context switching overhead
- Not setting `maxLifetime` — connections can be dropped by network firewalls silently, causing errors on the next use
- Mixing connection pool sizing for OLTP (many short queries) vs OLAP (few long queries) workloads

**Interview Traps:**
- "Just increase the pool size to fix slow response times" — pool exhaustion is a symptom; the root cause is usually slow queries or too many app instances
- Assuming HikariCP pool size = number of concurrent DB connections at the DB level (with PgBouncer in between, it's different)

**Quick Revision:** Pool size = (DB cores × 2) + spindles; set connectionTimeout to 3s for fail-fast; use PgBouncer in transaction mode when many app instances overwhelm PostgreSQL's max_connections.

---

### Topic 13: Database Statistics

**Difficulty:** 3/5 | **Frequency:** 3/5 | **Companies:** Amazon, Oracle, SAP, Salesforce

**Q:** How does PostgreSQL use statistics for query planning, and what causes bad execution plans due to stale statistics?

**Short Answer:**
PostgreSQL's planner uses column-level statistics (histograms, most common values, correlation) collected by ANALYZE to estimate row counts. Stale statistics after bulk loads cause the planner to choose wrong join algorithms or skip better indexes. Auto-vacuum triggers ANALYZE automatically, but manual intervention is needed after large data changes.

**Deep Explanation:**

**What Statistics PostgreSQL Collects:**

Statistics are stored in `pg_statistic` (raw) and `pg_stats` (human-readable view):

| Statistic | Description | Use in Planning |
|-----------|-------------|-----------------|
| `null_frac` | Fraction of NULL values | Filters NULL predicates |
| `n_distinct` | Estimated distinct values | Join cardinality, GROUP BY cost |
| `most_common_vals` / `most_common_freqs` | Top N values and their frequencies | Equality predicate selectivity |
| `histogram_bounds` | Bucket boundaries for value distribution | Range predicate selectivity |
| `correlation` | Physical ordering vs logical ordering (-1 to 1) | Whether index scan is efficient (close to ±1 = ordered = index is good) |

**Statistics Target:**
`default_statistics_target = 100` controls how many values/buckets are collected per column.
- Higher target = more accurate estimates = slower ANALYZE
- Per-column override: `ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;`
- For high-cardinality join columns (user_id, customer_id) increase to 500-1000

**Stale Statistics Scenario:**

```
Scenario: ETL loads 50M rows into orders table overnight
Before ANALYZE: planner thinks table has 1M rows (old stats)
Planner chooses: Nested Loop (optimal for 1M rows)
Actual runtime: 45 minutes (wrong for 50M rows — Hash Join would be 2 min)
After: ANALYZE orders → planner chooses Hash Join → 2 minutes
```

**Auto-vacuum and Auto-analyze:**
Auto-analyze triggers when:
```
changes > autovacuum_analyze_threshold + autovacuum_analyze_scale_factor * n_live_tup
default: 50 + 0.2 * table_size
```
For a 50M row table: threshold = 50 + 0.2 × 50,000,000 = 10,000,050 changed rows.
After bulk load of 50M rows → auto-analyze won't trigger until 10M more changes. Manual ANALYZE is needed.

**Extended Statistics (PostgreSQL 10+):**
The planner assumes column independence by default. For correlated columns (city + state, or category + subcategory), create extended statistics:
```sql
CREATE STATISTICS orders_status_region ON status, region FROM orders;
ANALYZE orders;
-- Now planner knows: if status='CANCELLED' AND region='EU', selectivity is not independent
```

**Real-World Example:**
A data warehouse query has `EXPLAIN` showing `rows=500` but `actual rows=2,000,000`. The column `event_type` has `statistics_target=100` but 80% of events are type 'CLICK', making the histogram useless for this skewed distribution. Setting `statistics_target=1000` and `ANALYZE` reduces the estimation error 4000x, allowing the planner to choose a correct Hash Join.

**Code Example:**
```sql
-- Check current statistics for a table column
SELECT
    attname AS column,
    n_distinct,
    array_length(most_common_vals, 1) AS mcv_count,
    correlation
FROM pg_stats
WHERE tablename = 'orders' AND attname IN ('customer_id', 'status', 'created_at');

-- Identify tables with stale statistics (not analyzed recently)
SELECT
    schemaname,
    tablename,
    last_analyze,
    last_autoanalyze,
    n_live_tup,
    n_dead_tup,
    n_mod_since_analyze
FROM pg_stat_user_tables
WHERE n_mod_since_analyze > 1000
ORDER BY n_mod_since_analyze DESC;

-- Increase statistics target for skewed column
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
ANALYZE orders (status);  -- analyze only one column (PostgreSQL 14+)

-- Full table analyze (after bulk load)
ANALYZE VERBOSE orders;

-- Create extended statistics for correlated columns
CREATE STATISTICS stat_orders_region_status (dependencies, ndistinct)
    ON region, status FROM orders;
ANALYZE orders;

-- Check if extended statistics helped
SELECT stxname, stxkeys, stxddependencies
FROM pg_statistic_ext_data
JOIN pg_statistic_ext ON pg_statistic_ext.oid = stxoid
WHERE stxrelid = 'orders'::regclass;

-- Auto-vacuum configuration (postgresql.conf)
-- autovacuum_analyze_scale_factor = 0.05  -- analyze after 5% rows change (default 20%)
-- autovacuum_analyze_threshold = 50
-- For large tables, set per-table:
ALTER TABLE orders SET (autovacuum_analyze_scale_factor = 0.01);
```

**Follow-up Questions:**
1. How do multi-column statistics (`CREATE STATISTICS`) improve over single-column statistics for correlated predicates?
2. What is the difference between VACUUM and ANALYZE in PostgreSQL?
3. When would you disable auto-analyze on a table, and what risks does that introduce?

**Common Mistakes:**
- Running ANALYZE during peak hours — it acquires a ShareUpdateExclusiveLock and can cause brief waits
- Forgetting to ANALYZE after `CREATE INDEX` — the new index won't have useful statistics
- Not monitoring `n_mod_since_analyze` on partitioned parent tables (statistics are per-partition)

**Interview Traps:**
- "VACUUM and ANALYZE do the same thing" — VACUUM reclaims dead tuple space; ANALYZE collects statistics; VACUUM ANALYZE does both
- Assuming auto-analyze handles post-bulk-load scenarios correctly — the threshold means it often doesn't

**Quick Revision:** pg_stats holds histograms and MCVs per column; stale stats after bulk loads cause wrong join algorithm selection; manual ANALYZE is needed after large data changes; increase statistics_target for skewed columns.

---

### Topic 14: Partitioning for Performance

**Difficulty:** 4/5 | **Frequency:** 4/5 | **Companies:** Amazon, Uber, LinkedIn, Confluent, Snowflake

**Q:** Explain the types of table partitioning in PostgreSQL and how partition pruning improves query performance.

**Short Answer:**
PostgreSQL supports range, list, and hash partitioning. Partition pruning eliminates irrelevant partitions at plan time (or runtime for parameterized queries), reducing I/O proportionally to the fraction of data accessed. The key benefit is that queries touching recent data only scan recent partitions, not the entire table.

**Deep Explanation:**

**Partitioning Types:**

**Range Partitioning** — most common for time-series data:
- Partition key: date, timestamp, sequential ID
- Pruning: `WHERE created_at >= '2024-01-01'` → only 2024 partition scanned
- Use case: orders, events, logs, IoT data

**List Partitioning** — categorical data:
- Partition key: status, region, country_code
- Pruning: `WHERE region = 'EU'` → only EU partition scanned
- Use case: multi-tenant schemas (one partition per tenant), geographic sharding

**Hash Partitioning** — even distribution:
- Partition key: user_id, customer_id (hash modulo N)
- No pruning for range queries; distributes write load evenly
- Use case: reducing contention on hot partitions, parallel bulk operations

**Partition Pruning:**
PostgreSQL evaluates partition constraints at plan time (static pruning) for literal values, and at execution time (runtime pruning, PostgreSQL 11+) for parameterized queries (`$1`, bind variables). Both require the partition key in the WHERE clause.

**Partition Indexes:**
Each partition has its own indexes, which are smaller and faster to scan than a global index. A `CREATE INDEX` on the parent table automatically creates indexes on all child partitions (PostgreSQL 11+).

**Partition Overhead Considerations:**
- JOIN across partitioned tables: planner generates N × M plan combinations — can cause plan generation overhead for > 1000 partitions
- INSERT routing: planner determines correct partition via constraint check — fast but not zero cost
- Partition maintenance: `DETACH PARTITION` to archive old data is near-instant (no DELETE needed)

**Real-World Example:**
An events table with 5 billion rows is range-partitioned by month (60 partitions for 5 years). A dashboard query `WHERE event_date >= NOW() - INTERVAL '30 days'` was previously a 45-second full table scan. After partitioning, it scans 1-2 monthly partitions — 90ms. Old partitions are archived by DETACH (instant) rather than slow DELETE.

**Code Example:**
```sql
-- Range partitioning by month
CREATE TABLE events (
    id          BIGSERIAL,
    user_id     BIGINT NOT NULL,
    event_type  VARCHAR(50) NOT NULL,
    event_date  TIMESTAMP WITH TIME ZONE NOT NULL,
    payload     JSONB
) PARTITION BY RANGE (event_date);

-- Create monthly partitions
CREATE TABLE events_2024_01 PARTITION OF events
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE events_2024_02 PARTITION OF events
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Index on partitioned table — auto-creates on all partitions
CREATE INDEX idx_events_user_date ON events(user_id, event_date DESC);
CREATE INDEX idx_events_type ON events(event_type);

-- Verify partition pruning
EXPLAIN SELECT * FROM events WHERE event_date >= '2024-01-01' AND event_date < '2024-02-01';
-- Should show: "Partitions: events_2024_01"

-- List partitioning by region
CREATE TABLE orders (
    id      BIGSERIAL,
    region  VARCHAR(20) NOT NULL,
    total   NUMERIC(10,2)
) PARTITION BY LIST (region);

CREATE TABLE orders_eu PARTITION OF orders FOR VALUES IN ('EU', 'UK');
CREATE TABLE orders_na PARTITION OF orders FOR VALUES IN ('US', 'CA', 'MX');
CREATE TABLE orders_apac PARTITION OF orders FOR VALUES IN ('AU', 'JP', 'SG');

-- Hash partitioning for even distribution
CREATE TABLE sessions (
    id      BIGSERIAL,
    user_id BIGINT NOT NULL,
    data    JSONB
) PARTITION BY HASH (user_id);

CREATE TABLE sessions_0 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE sessions_1 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE sessions_2 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE sessions_3 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- Archive old partition instantly (no DELETE)
ALTER TABLE events DETACH PARTITION events_2020_01;
-- Now events_2020_01 is a standalone table, can be dumped and dropped

-- Automate partition creation (pg_partman extension or cron job)
-- CREATE TABLE events_2024_03 PARTITION OF events
--     FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
```

**Follow-up Questions:**
1. How does PostgreSQL handle an INSERT into a partitioned table when no partition matches the value (default partition)?
2. What are the performance implications of having 10,000 partitions vs 100 partitions?
3. How do foreign keys work with partitioned tables in PostgreSQL?

**Common Mistakes:**
- Not including the partition key in the WHERE clause — results in full partition scan (all partitions)
- Creating too many partitions (>1000) — planner overhead for complex queries can dominate execution time
- Forgetting to create the "default" partition to catch out-of-range values

**Interview Traps:**
- "Partitioning always improves performance" — for queries that must scan all partitions (no partition key in WHERE), it adds overhead vs a single table
- Hash partitioning enables pruning for equality on the partition key, not for range queries

**Quick Revision:** Range partition by time, list by category, hash for even distribution; partition pruning requires the partition key in WHERE; DETACH is instant archival; too many partitions (>1000) creates planner overhead.

---

### Topic 15: Read Replicas & Query Routing

**Difficulty:** 4/5 | **Frequency:** 4/5 | **Companies:** Amazon, Netflix, Shopify, GitHub, Twilio

**Q:** How do you implement read/write splitting in a Spring Boot application using read replicas, and what consistency concerns arise?

**Short Answer:**
Spring's `AbstractRoutingDataSource` routes transactions to read replicas based on `@Transactional(readOnly=true)`. The key risk is replication lag — reading from a replica immediately after a write may return stale data. Applications must implement lag detection or use sticky reads after write to maintain consistency.

**Deep Explanation:**

**Read Replica Architecture:**
PostgreSQL streaming replication sends WAL (Write-Ahead Log) segments from primary to replicas asynchronously (by default). Replicas are read-only hot standbys. Typical lag: < 100ms on same-region replicas; seconds to minutes on cross-region.

**Spring AbstractRoutingDataSource Pattern:**
```
@Transactional(readOnly=true) → replica DataSource
@Transactional             → primary DataSource
```

**Replication Lag — The Critical Problem:**

Scenario: User updates their profile, then immediately views it. If the read goes to a replica with 500ms lag, they see the old profile. This is "read-your-own-writes" consistency violation.

**Solutions:**
1. **Sticky reads after write** — route reads to primary for N seconds after a write
2. **Session consistency tokens** — pass the primary's LSN (Log Sequence Number) to the client; replica waits until it catches up to that LSN using `pg_wal_lsn_diff` + `pg_last_wal_replay_lsn()`
3. **Read from primary for sensitive operations** — never use replicas for checkout, payment, auth
4. **Sync replication for critical writes** — `synchronous_commit = on` ensures replica confirms before primary acks

**Lag Monitoring:**
```sql
-- On primary: check replication lag per replica
SELECT
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
    write_lag,
    flush_lag,
    replay_lag
FROM pg_stat_replication;

-- On replica: check own lag
SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;
```

**Real-World Example:**
An e-commerce platform has 1 primary + 3 read replicas behind a load balancer. Product listing pages use replicas (high volume, stale-ok). Cart and checkout use primary exclusively. After a flash sale starts (millions of reads), replicas lag 3 seconds — users see old inventory. Fix: add monitoring that routes to primary when `replication_lag > 1s`, and mark inventory reads as `@Transactional(readOnly=false)` for checkout flow.

**Code Example:**
```java
// 1. DataSource routing key
public enum DataSourceType {
    WRITE, READ
}

// 2. Thread-local context holder
public class DataSourceContextHolder {
    private static final ThreadLocal<DataSourceType> contextHolder = new ThreadLocal<>();

    public static void setDataSourceType(DataSourceType type) {
        contextHolder.set(type);
    }
    public static DataSourceType getDataSourceType() {
        return contextHolder.get();
    }
    public static void clearDataSourceType() {
        contextHolder.remove();
    }
}

// 3. Routing DataSource
public class RoutingDataSource extends AbstractRoutingDataSource {
    @Override
    protected Object determineCurrentLookupKey() {
        return DataSourceContextHolder.getDataSourceType();
    }
}

// 4. Spring configuration
@Configuration
public class DataSourceConfig {

    @Bean
    @ConfigurationProperties("spring.datasource.write")
    public DataSource writeDataSource() {
        return DataSourceBuilder.create().build();
    }

    @Bean
    @ConfigurationProperties("spring.datasource.read")
    public DataSource readDataSource() {
        return DataSourceBuilder.create().build();
    }

    @Bean
    @Primary
    public DataSource routingDataSource(
            @Qualifier("writeDataSource") DataSource write,
            @Qualifier("readDataSource") DataSource read) {
        RoutingDataSource routingDataSource = new RoutingDataSource();
        Map<Object, Object> targets = new HashMap<>();
        targets.put(DataSourceType.WRITE, write);
        targets.put(DataSourceType.READ, read);
        routingDataSource.setTargetDataSources(targets);
        routingDataSource.setDefaultTargetDataSource(write);
        return routingDataSource;
    }
}

// 5. AOP interceptor — routes based on @Transactional(readOnly)
@Aspect
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)  // Must run BEFORE @Transactional
public class DataSourceRoutingAspect {

    @Around("@annotation(transactional)")
    public Object route(ProceedingJoinPoint pjp, Transactional transactional) throws Throwable {
        DataSourceType type = transactional.readOnly()
                ? DataSourceType.READ
                : DataSourceType.WRITE;
        DataSourceContextHolder.setDataSourceType(type);
        try {
            return pjp.proceed();
        } finally {
            DataSourceContextHolder.clearDataSourceType();
        }
    }
}

// 6. Service usage
@Service
public class ProductService {

    @Transactional(readOnly = true)  // → read replica
    public List<Product> findActiveProducts() {
        return productRepository.findByActiveTrue();
    }

    @Transactional                   // → primary write
    public Product createProduct(ProductRequest request) {
        return productRepository.save(new Product(request));
    }
}
```

```yaml
# application.yml — multiple datasources
spring:
  datasource:
    write:
      url: jdbc:postgresql://primary:5432/mydb
      hikari:
        maximum-pool-size: 10
    read:
      url: jdbc:postgresql://replica:5432/mydb
      hikari:
        maximum-pool-size: 20  # larger pool for reads
```

```sql
-- Monitor replication lag (run on primary, alert if > 10MB)
SELECT
    application_name,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) / 1024 / 1024 AS lag_mb,
    replay_lag
FROM pg_stat_replication
ORDER BY lag_mb DESC;
```

**Follow-up Questions:**
1. How would you implement "read-your-own-writes" consistency when using a read replica in a distributed system?
2. What is the difference between synchronous and asynchronous replication in PostgreSQL, and when would you use each?
3. How does Amazon Aurora handle replica lag differently from standard PostgreSQL streaming replication?

**Common Mistakes:**
- Routing all `@Transactional` methods to the replica — any method not explicitly `readOnly=true` may write; this causes errors on a read-only replica
- Not considering that `@Transactional` AOP aspect order matters — DataSource routing aspect MUST execute before the transaction begins
- Ignoring replication lag for financial or inventory data — using stale reads for "available balance" checks

**Interview Traps:**
- "Read replicas improve write throughput" — replicas only help read throughput; they increase write overhead (WAL shipping to each replica)
- Assuming `readOnly=true` on `@Transactional` alone routes to replica — it only sets a hint to the JDBC driver unless custom routing is implemented

**Quick Revision:** AbstractRoutingDataSource + @Transactional(readOnly=true) routes reads to replicas; replication lag is the core risk; never use replicas for reads that follow writes in the same user flow without lag compensation.

---

## Cheat Sheet: Database Indexing & Query Optimization

---

### Index Decision Flowchart (Text-Based)

```
Is the query slow? (> 100ms for OLTP)
└── YES → Run EXPLAIN (ANALYZE, BUFFERS)
    │
    ├── Seq Scan on large table?
    │   └── YES → Is selectivity < 20%?
    │       ├── YES → Add single/composite index on WHERE + ORDER BY columns
    │       └── NO  → Consider partial index, or accept seq scan
    │
    ├── Index Scan but still slow?
    │   ├── High "actual rows" vs "rows" ratio?
    │   │   └── YES → ANALYZE table (stale statistics)
    │   ├── All needed columns in index?
    │   │   └── NO  → Add INCLUDE columns for covering index
    │   └── Random I/O on HDD?
    │       └── YES → Consider Bitmap Index Scan threshold or lower random_page_cost
    │
    ├── Nested Loop with high loops count?
    │   └── Is inner table large and join column unindexed?
    │       └── YES → Add index on join column OR consider Hash Join (increase work_mem)
    │
    ├── Hash Batches > 1? (sort or hash spilling to disk)
    │   └── YES → Increase work_mem for session: SET work_mem = '256MB';
    │
    └── Good plan but still slow?
        ├── Many small queries (N+1)?  → Rewrite as JOIN / batch fetch
        ├── Function on indexed column? → Rewrite predicate or add functional index
        ├── OR on different columns?    → Rewrite as UNION ALL
        └── Deep OFFSET pagination?    → Switch to keyset pagination
```

---

### EXPLAIN Output Nodes Reference Table

| Node Type | Description | Key Metric to Check |
|-----------|-------------|-------------------|
| `Seq Scan` | Full table read | Filter rows vs output rows (high filter = index opportunity) |
| `Index Scan` | B-tree walk + heap fetch per row | Rows: estimated vs actual |
| `Index Only Scan` | Index only, no heap access | Heap Fetches: should be 0 for hot data |
| `Bitmap Index Scan` | Build bitmap of matching TIDs | Part of Bitmap Heap Scan pair |
| `Bitmap Heap Scan` | Fetch heap rows in TID order | Recheck Cond: extra filter on heap |
| `Nested Loop` | Outer × inner iterations | Loops: should be low |
| `Hash Join` | Build hash table from inner, probe with outer | Batches > 1 = spill to disk |
| `Merge Join` | Merge two sorted inputs | Sort nodes beneath = sort cost |
| `Sort` | In-memory or disk sort | Sort Method: "external merge" = disk spill |
| `Hash` | Build phase of Hash Join | Buckets, Batches, Memory Usage |
| `Aggregate` | GROUP BY, COUNT, SUM | Rows in vs rows out |
| `Limit` | LIMIT clause | Applied after sort — sort still runs all rows |
| `Gather` / `Gather Merge` | Parallel query coordinator | Workers Planned vs Workers Launched |
| `Append` | UNION ALL or partition scan | Number of children = partitions scanned |
| `Materialize` | CTE or subquery materialized | Peak Memory Usage |

**Reading costs:**
```
(cost=startup..total rows=N width=W)
       ↑             ↑       ↑
  Cost before    Total cost  Avg bytes
  first row      for all     per row
  (sort = high)  rows
```

---

### Query Optimization Checklist

**Before Writing the Query:**
- [ ] Identify exact columns needed — no SELECT *
- [ ] Determine which predicates have high selectivity
- [ ] Check if needed indexes exist (`\d tablename` in psql)
- [ ] Understand data volume and distribution

**Writing the Query:**
- [ ] Predicates on indexed columns use raw values (no functions/casts on left side)
- [ ] Range predicates over date functions (`created_at >= X` not `DATE(created_at) = X`)
- [ ] OR on different indexed columns → UNION ALL
- [ ] Subquery returns aggregate per group → rewrite as JOIN + GROUP BY
- [ ] Correlated subquery → lateral join or CTE
- [ ] EXISTS instead of IN for correlated existence checks
- [ ] LIMIT with ORDER BY on indexed column
- [ ] Deep pagination → keyset (`WHERE id > last_id`) not OFFSET

**After Writing the Query:**
- [ ] Run `EXPLAIN (ANALYZE, BUFFERS)` — check estimated vs actual rows
- [ ] Verify partition pruning if table is partitioned
- [ ] Check `Buffers: shared read` — high read count = cache miss
- [ ] Confirm no Hash Join batches > 1 (disk spill)
- [ ] Verify index is actually used (no implicit type cast blocking it)

**Index Checklist:**
- [ ] Composite index column order: equality predicates first, then range, then ORDER BY
- [ ] Partial index for common filter (`WHERE deleted_at IS NULL`)
- [ ] Covering index (INCLUDE) for hot read queries
- [ ] Functional index if function on column is unavoidable
- [ ] No redundant indexes (subset indexes already covered by composite)

**Statistics & Configuration:**
- [ ] ANALYZE after bulk load (don't rely on auto-analyze alone)
- [ ] Increase statistics_target for skewed or high-cardinality join columns
- [ ] `work_mem` tuned for sort/hash operations (be careful: per-sort-node, not per-query)
- [ ] `random_page_cost = 1.1` for SSD storage

---

### HikariCP Key Configuration Properties

```yaml
spring.datasource.hikari:
  # Pool size
  maximum-pool-size: 10           # Formula: (core_count * 2) + spindle_count
  minimum-idle: 10                # Set equal to max for fixed pool size

  # Timeouts
  connection-timeout: 3000        # ms — how long app waits for a connection from pool
  idle-timeout: 300000            # ms — how long idle connections stay in pool (5 min)
  max-lifetime: 1740000           # ms — max connection age (29 min; < DB timeout of 30 min)
  keepalive-time: 60000           # ms — heartbeat interval to prevent firewall drops

  # Reliability
  connection-test-query: SELECT 1 # validation query (PostgreSQL supports ping automatically)
  leak-detection-threshold: 5000  # ms — warn if connection held longer than this (dev only)

  # Identification
  pool-name: MyServicePool         # visible in JMX, metrics, and logs

  # JDBC optimizations (PostgreSQL-specific)
  data-source-properties:
    cachePrepStmts: true
    prepStmtCacheSize: 250
    prepStmtCacheSqlLimit: 2048
    useServerPrepStmts: true
```

**Key Rules:**
- `max-lifetime` must be LESS than the database's `idle_in_transaction_session_timeout` or network firewall timeout
- `connection-timeout` should be SHORT (3s) — fail fast rather than queue for 30s under load
- Monitor `hikaricp.connections.pending` metric — if > 0 regularly, pool is undersized or queries are too slow
- `minimum-idle < maximum-pool-size` creates elastic pool — useful for bursty workloads but causes connection thrashing

**Actuator Metrics (Spring Boot + Micrometer):**
```
hikaricp.connections.active      — currently in-use connections
hikaricp.connections.idle        — available connections in pool
hikaricp.connections.pending     — threads waiting for a connection
hikaricp.connections.acquire     — time to acquire a connection (histogram)
hikaricp.connections.creation    — time to create a new connection
hikaricp.connections.timeout.total — cumulative timeout count
```

---

*End of Chapter 15 — Part B*
*Volume 4: Databases | Backend Interview Handbook*





