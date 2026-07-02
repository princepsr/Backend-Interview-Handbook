# Volume 4: Databases & Performance
# Chapter 18: Advanced Database Topics

---

## Part A: Partitioning, Sharding, Replication, and Connection Pooling

> **Target Audience:** SDE2+ | FAANG, MAANG, and top-tier product companies
> **Prerequisites:** Chapter 15 (Indexing), Chapter 16 (Transactions), Chapter 17 (Query Optimization)

---

### Topic 1: Table Partitioning

**Difficulty:** Medium-Hard | **Frequency:** High | **Companies:** Amazon, Google, Meta, Uber, Stripe, Netflix

**Q:** How does PostgreSQL table partitioning work, and when does it help or hurt performance?

**Short Answer:**
Table partitioning divides a large table into smaller physical sub-tables (partitions) while presenting a single logical table to queries. PostgreSQL supports range, list, and hash partitioning declaratively since version 10. The planner performs partition pruning to skip irrelevant partitions, dramatically reducing I/O for selective queries on the partition key.

**Deep Explanation:**

Partitioning is a physical data organization strategy where a parent table acts as a logical façade over multiple child tables. Each partition holds a disjoint subset of rows defined by the partition key.

**Range Partitioning** — rows are distributed based on continuous ranges of a key value. Most common for time-series data (created_at, event_date). The planner can prune all partitions outside the query's date range.

**List Partitioning** — rows are distributed based on explicit enumerated values (e.g., country_code = 'US', 'EU', 'APAC'). Useful when the cardinality of the partition key is low and well-known.

**Hash Partitioning** — rows are distributed using a hash function modulo N. Used when neither range nor list applies (e.g., distributing by user_id evenly across 8 partitions). No pruning based on equality predicates is generally possible unless the exact modulus matches.

**Declarative Partitioning Syntax (PostgreSQL 10+):**

```sql
-- Range partitioning on created_at
CREATE TABLE orders (
    id          BIGSERIAL,
    user_id     BIGINT NOT NULL,
    total       NUMERIC(12,2),
    created_at  TIMESTAMPTZ NOT NULL
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2024_q1
    PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE orders_2024_q2
    PARTITION OF orders
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

-- Default partition catches anything not covered
CREATE TABLE orders_default
    PARTITION OF orders DEFAULT;
```

```sql
-- List partitioning on region
CREATE TABLE events (
    id      BIGSERIAL,
    region  TEXT NOT NULL,
    payload JSONB
) PARTITION BY LIST (region);

CREATE TABLE events_us   PARTITION OF events FOR VALUES IN ('us-east-1', 'us-west-2');
CREATE TABLE events_eu   PARTITION OF events FOR VALUES IN ('eu-west-1', 'eu-central-1');
CREATE TABLE events_apac PARTITION OF events FOR VALUES IN ('ap-southeast-1', 'ap-northeast-1');
```

```sql
-- Hash partitioning on user_id
CREATE TABLE user_activity (
    user_id    BIGINT NOT NULL,
    action     TEXT,
    ts         TIMESTAMPTZ
) PARTITION BY HASH (user_id);

CREATE TABLE user_activity_p0 PARTITION OF user_activity
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE user_activity_p1 PARTITION OF user_activity
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE user_activity_p2 PARTITION OF user_activity
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE user_activity_p3 PARTITION OF user_activity
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

**Partition Pruning:**
The planner eliminates partitions at plan time (static pruning) or execution time (dynamic pruning, PostgreSQL 11+). Dynamic pruning handles parameterized queries where the value is only known at runtime.

```sql
-- This query will prune all partitions except orders_2024_q1
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders
WHERE created_at BETWEEN '2024-01-15' AND '2024-02-15';
-- Output shows: Append (never executed: orders_2024_q2, orders_default)
```

**Partition-Wise Joins (PostgreSQL 11+):**
When two partitioned tables share the same partition key and partition bounds, the planner can join matching partition pairs independently and merge results. This enables parallelism and avoids building a hash table for the entire dataset.

```sql
SET enable_partitionwise_join = ON;
-- orders and order_items both partitioned by the same scheme
SELECT o.id, SUM(oi.price)
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
WHERE o.created_at >= '2024-01-01'
GROUP BY o.id;
```

**When Partitioning Helps:**
- Very large tables (100M+ rows) where queries always filter on the partition key
- Time-series data with rolling retention (DROP partition instead of DELETE)
- Bulk loads into a specific partition (load into staging, then ATTACH PARTITION)
- Partition-wise aggregation and join opportunities

**When Partitioning Hurts:**
- Queries that do NOT filter on the partition key (full cross-partition scans are worse than a single-table scan due to append overhead)
- Low row counts — overhead of partition management outweighs benefit
- Unique constraints across partitions — PostgreSQL requires the partition key to be part of any unique/PK constraint
- Heavy UPDATE operations that change the partition key value (triggers a DELETE + INSERT across partitions)

**Real-World Example:**
Uber's trip data table was partitioned by month on `start_time`. Retention jobs simply dropped the oldest month's partition rather than running `DELETE WHERE start_time < ...`, which avoided table bloat and VACUUM pressure. New month partitions were created in advance by a cron job.

**Follow-up Questions:**
1. How does partition pruning differ between static and dynamic pruning, and what PostgreSQL version introduced dynamic pruning?
2. How do you add a new partition to a live table without downtime?
3. What happens to a global index when you detach a partition in PostgreSQL?

**Common Mistakes:**
- Forgetting to create the default partition — rows that don't match any partition cause an error without it
- Choosing a partition key with low cardinality for hash partitioning, causing uneven data distribution
- Not including the partition key in unique constraints, leading to a "unique constraint must include all columns in the partition key" error

**Interview Traps:**
- Interviewers often confuse partitioning with sharding. Partitioning is a single-node physical organization; sharding distributes data across multiple nodes.
- "Does adding a partition lock the table?" — ATTACH PARTITION acquires a brief AccessShareLock but does not block reads/writes for long if the partition's data satisfies the constraint.

**Quick Revision:** Partitioning splits one large physical table into sub-tables by range/list/hash, enabling partition pruning to skip irrelevant data; helps most for time-series with retention and large filtered scans, hurts for cross-partition queries without the partition key.

---

### Topic 2: Horizontal vs Vertical Sharding

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, LinkedIn, Twitter/X, Shopify, Airbnb

**Q:** What is the difference between horizontal and vertical sharding, and how does sharding differ from partitioning?

**Short Answer:**
Partitioning divides data within a single database node; sharding distributes data across multiple independent database nodes (each called a shard). Vertical sharding splits a schema by column groups (feature domains), while horizontal sharding splits by rows — distributing rows across shards based on a shard key. Horizontal sharding is what most engineers mean when they say "sharding."

**Deep Explanation:**

**Partitioning vs Sharding:**

| Dimension | Partitioning | Sharding |
|---|---|---|
| Scope | Single node, single database | Multiple nodes, independent databases |
| Transparent to app? | Yes — single connection string | No — app or middleware must route |
| Failure domain | Single node | Each shard is an independent failure domain |
| Scale dimension | Read/write throughput on one machine | Scales write throughput and storage horizontally |

**Vertical Sharding (Functional Partitioning):**
The schema is split by domain — user service owns the `users` table, order service owns the `orders` table. Each microservice has its own dedicated database. This is essentially the database-per-service pattern from microservices architecture.

```
Monolith DB → User DB (users, profiles, preferences)
            → Order DB (orders, order_items, payments)
            → Inventory DB (products, stock, warehouses)
```

Benefits: each database is smaller, teams own their schema, different databases can use different engines.
Drawbacks: cross-domain joins require application-side assembly; distributed transactions needed for multi-domain writes.

**Horizontal Sharding:**
Rows of a single table are distributed across N shards based on a shard key. Each shard holds a disjoint subset of rows.

```
users table, sharded by user_id % 4:
  Shard 0: users where user_id % 4 = 0
  Shard 1: users where user_id % 4 = 1
  Shard 2: users where user_id % 4 = 2
  Shard 3: users where user_id % 4 = 3
```

**Sharding Layers:**

1. **Application-Layer Sharding** — The application contains a shard map and directly connects to the appropriate shard. Most flexible, highest coupling.

```java
// Application-layer sharding example
public DataSource getDataSource(long userId) {
    int shardIndex = (int)(userId % shardCount);
    return shardDataSources.get(shardIndex);
}
```

2. **Middleware-Layer Sharding** — A proxy sits between the application and databases, routing queries transparently. Examples: Vitess (MySQL), Citus (PostgreSQL), ProxySQL.

3. **Database-Layer Sharding** — The database engine handles distribution natively. Examples: CockroachDB, TiDB, YugabyteDB, Amazon Aurora Sharding, DynamoDB.

**Consistent Hashing for Sharding:**
Modulo-based sharding requires re-hashing all data when adding/removing shards. Consistent hashing (used by Cassandra, DynamoDB, Redis Cluster) minimizes data movement during topology changes — only K/N keys need to move (K = total keys, N = number of nodes).

**Real-World Example:**
Instagram's early scaling story: they used PostgreSQL with application-layer horizontal sharding. The users table was split across thousands of logical shards mapped onto dozens of physical PostgreSQL servers. Adding physical servers meant remapping logical shards without re-hashing the entire dataset.

**Code Example:**
```java
// Spring Boot multi-datasource routing for horizontal sharding
@Component
public class ShardRoutingDataSource extends AbstractRoutingDataSource {

    private static final int SHARD_COUNT = 4;

    @Override
    protected Object determineCurrentLookupKey() {
        Long userId = ShardContext.getCurrentUserId();
        if (userId == null) return "shard_0"; // default
        return "shard_" + (userId % SHARD_COUNT);
    }
}

// ThreadLocal context holder
public class ShardContext {
    private static final ThreadLocal<Long> USER_ID = new ThreadLocal<>();

    public static void setCurrentUserId(Long userId) { USER_ID.set(userId); }
    public static Long getCurrentUserId() { return USER_ID.get(); }
    public static void clear() { USER_ID.remove(); }
}
```

**Follow-up Questions:**
1. How does Vitess handle horizontal sharding for MySQL, and what are its trade-offs versus application-layer sharding?
2. When would you choose vertical sharding over horizontal sharding?
3. How does consistent hashing reduce re-balancing overhead compared to modulo hashing?

**Common Mistakes:**
- Using modulo sharding without planning for resharding — adding a shard requires moving ~50% of data
- Treating vertical sharding as a performance solution rather than an organizational/ownership solution
- Forgetting that cross-shard transactions require distributed transaction protocols (2PC or saga pattern)

**Interview Traps:**
- "Is Citus partitioning or sharding?" — Citus is horizontal sharding for PostgreSQL; it distributes data across worker nodes but uses PostgreSQL's partition infrastructure internally.
- Vertical sharding is often confused with column-store databases; they are different concepts.

**Quick Revision:** Partitioning = physical split within one node; sharding = distributing rows/tables across multiple nodes; vertical sharding splits by domain, horizontal sharding splits by row using a shard key.

---

### Topic 3: Shard Key Design

**Difficulty:** Hard | **Frequency:** High | **Companies:** Amazon, Meta, Google, Stripe, Uber, Lyft

**Q:** What makes a good shard key, and what problems arise from a poorly chosen shard key?

**Short Answer:**
A good shard key distributes both data and query load evenly (high cardinality, no hotspots), is immutable after assignment, and aligns with the most common access pattern to minimize cross-shard queries. Monotonically increasing keys (auto-increment IDs) are dangerous in sharded systems because all writes concentrate on the "last" shard, creating a write hotspot.

**Deep Explanation:**

**Properties of a Good Shard Key:**

1. **High Cardinality** — Enough distinct values to distribute data evenly. A shard key with only 4 distinct values (e.g., status: NEW/ACTIVE/SUSPENDED/DELETED) cannot spread data across more than 4 shards meaningfully.

2. **Uniform Distribution** — The shard key's values must distribute evenly. `user_id` is often good; `country_code` is bad because the US may hold 40% of users.

3. **Immutability** — Changing a row's shard key requires deleting from the old shard and inserting into the new shard. This is a distributed operation that is hard to make atomic. Good shard keys do not change after entity creation.

4. **Query Locality** — The most frequent queries should filter on the shard key, enabling the router to target a single shard rather than fan out to all shards.

**The Monotonically Increasing Key Problem:**
Auto-increment primary keys, UUIDs v1 (time-based), and sequential snowflake IDs create a "last-shard" write hotspot in naive hash-based sharding because all new inserts hash to the same range.

```sql
-- BAD: auto-increment as shard key
-- All new orders go to the shard that owns the latest ID range
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,  -- monotonically increasing
    user_id BIGINT,
    ...
);
-- With range sharding: shard N is always the hot shard
```

**Solutions:**

- **Prefix randomization** — Prepend a random 2-digit prefix to the ID: `shard_id || sequence_id`
- **Snowflake IDs with shard embedding** — Twitter Snowflake embeds the machine/shard ID in bits 10-22 of the 64-bit ID, ensuring new IDs are distributed across shards
- **UUID v4** — Fully random, excellent distribution, but larger and no temporal ordering
- **ULID** — Universally Unique Lexicographically Sortable Identifier: time prefix + random suffix, sortable but distributed

```java
// Snowflake ID generator — shard ID embedded
public class SnowflakeIdGenerator {
    private static final long EPOCH = 1609459200000L; // 2021-01-01
    private static final long SHARD_ID_BITS = 10;
    private static final long SEQUENCE_BITS = 12;
    private static final long MAX_SEQUENCE = (1 << SEQUENCE_BITS) - 1;

    private final long shardId;
    private long lastTimestamp = -1L;
    private long sequence = 0L;

    public SnowflakeIdGenerator(long shardId) {
        this.shardId = shardId & ((1 << SHARD_ID_BITS) - 1);
    }

    public synchronized long nextId() {
        long ts = System.currentTimeMillis() - EPOCH;
        if (ts == lastTimestamp) {
            sequence = (sequence + 1) & MAX_SEQUENCE;
            if (sequence == 0) ts = waitNextMillis(ts);
        } else {
            sequence = 0;
        }
        lastTimestamp = ts;
        return (ts << (SHARD_ID_BITS + SEQUENCE_BITS))
             | (shardId << SEQUENCE_BITS)
             | sequence;
    }
    // ...
}
```

**Composite Shard Keys:**
Sometimes a single column doesn't provide both good distribution and query locality. Composite shard keys combine multiple columns.

```
(tenant_id, user_id) — ensures all data for a tenant's user is co-located,
good for multi-tenant SaaS where queries always filter on both.

(region, user_id % 1000) — region provides geographic routing,
modulo provides intra-region distribution.
```

**Hotspot Avoidance Patterns:**

- **Virtual shards / logical shards** — Map logical shard IDs (e.g., 1000) to physical shards (e.g., 10). Resharding moves logical shards between physical shards without rehashing.
- **Write spreading** — For celebrity/power-user accounts, pre-shard writes to multiple replicas and merge on read (Twitter's approach for @elonmusk's 100M followers).
- **Time bucketing + user_id** — `(YYYYMM || user_id % 1000)` as shard key spreads time-series data evenly.

**Real-World Example:**
DynamoDB's partition key design is exactly shard key design. Amazon's guidelines explicitly warn against monotonically increasing partition keys. For IoT sensor data, instead of using device_id (which creates cold partitions for inactive devices), they recommend a write-sharding pattern: append a random suffix (1–N) to the partition key and read from all N suffixes.

**Follow-up Questions:**
1. How does DynamoDB's write sharding pattern work, and what is its read-side cost?
2. If you must use an auto-increment ID as the primary key (for legacy reasons), how do you design the shard key separately?
3. What is a "shard rebalancing" operation and how does it differ between consistent hashing and range-based sharding?

**Common Mistakes:**
- Choosing the most commonly queried column without checking its cardinality or distribution
- Using `created_at` as a shard key for a write-heavy system (hot shard = today's data)
- Mutating the shard key — the application must prevent this via validation, not just assume the DB will handle it

**Interview Traps:**
- "Can you change a shard key later?" — Technically yes, but it requires a full data migration. Good shard key design upfront avoids this.
- UUID v4 is great for distribution but terrible for range scans and can cause B-tree index fragmentation — UUID v7 (time-ordered random) was designed to solve this.

**Quick Revision:** A good shard key is high-cardinality, uniformly distributed, immutable, and query-local; monotonically increasing keys cause write hotspots — use Snowflake IDs, UUID v4, or write-sharding patterns instead.

---

### Topic 4: Cross-Shard Queries

**Difficulty:** Hard | **Frequency:** Medium-High | **Companies:** Amazon, Google, Meta, Uber, DoorDash

**Q:** How do you handle queries that need data from multiple shards, and what patterns exist for cross-shard aggregation?

**Short Answer:**
Cross-shard queries require a scatter-gather pattern: fan out the query to all (or relevant) shards in parallel, collect results, and merge/aggregate at the application or middleware layer. Cross-shard joins are extremely expensive and should be avoided by data modeling — either denormalizing data, maintaining secondary indexes, or co-locating related data on the same shard.

**Deep Explanation:**

**Scatter-Gather Pattern:**
The coordinator (application or middleware) sends the query to all relevant shards in parallel, waits for all responses, and merges the results.

```
Query: SELECT COUNT(*) FROM orders WHERE status = 'PENDING'
  → Coordinator fans out to all N shards
  → Shard 0: COUNT = 1,200
  → Shard 1: COUNT = 1,450
  → Shard 2: COUNT = 980
  → Shard 3: COUNT = 1,100
  → Coordinator: SUM = 4,730
```

Latency = max(shard latency) + merge overhead (not sum). Tail latency dominates — one slow shard delays the entire query.

**Cross-Shard Joins (Why They're Expensive):**

A join between tables on different shards requires transferring one table's matching rows over the network to co-locate with the other table's rows. For large tables this is O(N) network transfer.

```java
// Application-side cross-shard join (expensive but sometimes necessary)
public List<OrderWithUser> getOrdersWithUsers(List<Long> orderIds) {
    // Step 1: Fetch orders from their respective shards
    Map<Integer, List<Long>> ordersByShardId = partitionOrderIdsByShardId(orderIds);
    List<Order> orders = fetchOrdersFromShards(ordersByShardId); // parallel

    // Step 2: Collect user_ids, determine their shards
    Set<Long> userIds = orders.stream().map(Order::getUserId).collect(toSet());
    Map<Integer, List<Long>> usersByShardId = partitionUserIdsByShardId(userIds);
    Map<Long, User> userMap = fetchUsersFromShards(usersByShardId)
        .stream().collect(toMap(User::getId, identity()));

    // Step 3: Merge in application memory
    return orders.stream()
        .map(o -> new OrderWithUser(o, userMap.get(o.getUserId())))
        .collect(toList());
}
```

**Strategies to Avoid Cross-Shard Joins:**

1. **Co-location** — Ensure related entities (user + orders + payments) share the same shard key so they land on the same shard.

```sql
-- Shard key: user_id
-- users:         shard_key = user_id
-- orders:        shard_key = user_id  (not order_id!)
-- order_items:   shard_key = user_id
-- All data for a user lives on the same shard
```

2. **Denormalization** — Embed frequently joined data into the primary entity.

```sql
-- Embed user_name in orders to avoid joining users table
ALTER TABLE orders ADD COLUMN user_name TEXT;
-- Accept eventual consistency for the denormalized field
```

3. **Global Tables (Broadcast Tables)** — Small reference tables (countries, product categories) are replicated to every shard.

**Fan-Out Reads:**

```java
// Parallel fan-out to all shards
public CompletableFuture<Long> countPendingOrdersAllShards() {
    List<CompletableFuture<Long>> futures = IntStream.range(0, SHARD_COUNT)
        .mapToObj(shardId ->
            CompletableFuture.supplyAsync(() ->
                getShardTemplate(shardId).queryForObject(
                    "SELECT COUNT(*) FROM orders WHERE status = 'PENDING'",
                    Long.class
                ), executor
            )
        ).collect(toList());

    return CompletableFuture.allOf(futures.toArray(new CompletableFuture[0]))
        .thenApply(v -> futures.stream()
            .mapToLong(f -> f.join())
            .sum()
        );
}
```

**Aggregation Across Shards:**
Simple aggregates (SUM, COUNT, MIN, MAX) are naturally decomposable — each shard computes a partial result and the coordinator merges. Average requires SUM + COUNT from each shard (cannot average the averages). Median and percentiles require either sorting all data centrally or approximate algorithms (HyperLogLog, t-digest).

**Global Secondary Indexes in DynamoDB:**
DynamoDB's Global Secondary Index (GSI) maintains an eventually-consistent secondary index that DynamoDB itself distributes across its own internal partitions. This allows efficient lookups on non-partition-key attributes without scatter-gather.

```java
// DynamoDB GSI query — no scatter-gather needed
QueryRequest request = QueryRequest.builder()
    .tableName("Orders")
    .indexName("UserIdIndex")  // GSI on user_id
    .keyConditionExpression("user_id = :uid")
    .expressionAttributeValues(Map.of(":uid", AttributeValue.fromN("12345")))
    .build();
// DynamoDB routes to the correct GSI partition internally
```

**Real-World Example:**
Stripe's charges table is sharded by merchant_id. Cross-shard analytics (total charges by payment method) are moved to a separate OLAP pipeline (Redshift/BigQuery) rather than being queried live against the OLTP shards. Real-time per-merchant queries hit a single shard; aggregate queries go to the analytical store.

**Follow-up Questions:**
1. What is the two-phase query pattern and how does it reduce cross-shard data transfer?
2. How does Vitess handle cross-shard aggregations, and what SQL operations does it not support natively?
3. What trade-offs do you accept when using DynamoDB GSIs versus modeling data with co-location?

**Common Mistakes:**
- Forgetting that ORDER BY + LIMIT across shards requires fetching K*LIMIT rows from each shard before applying the limit at the coordinator
- Treating cross-shard scatter-gather as equivalent performance to single-shard queries — the latency floor is the slowest shard
- Not handling partial failures in scatter-gather (one shard times out while others succeed)

**Interview Traps:**
- "Can you do ACID transactions across shards?" — Technically yes, with distributed 2PC, but this is slow and defeats much of sharding's write-throughput benefit. Most systems use sagas instead.
- `SELECT * FROM orders ORDER BY created_at LIMIT 10` on a sharded system must fetch 10 rows from EACH shard and then globally sort — it is O(N shards * 10) not O(1).

**Quick Revision:** Cross-shard queries use scatter-gather (fan out in parallel, merge at coordinator); avoid cross-shard joins via co-location, denormalization, or broadcast tables; aggregations are decomposable for SUM/COUNT/MIN/MAX but not for median/percentile without approximation.

---

### Topic 5: Database Replication Internals

**Difficulty:** Hard | **Frequency:** High | **Companies:** Amazon, Google, Meta, LinkedIn, Confluent, PlanetScale

**Q:** How does WAL-based replication work in PostgreSQL, and how does it differ from MySQL's binlog-based replication?

**Short Answer:**
PostgreSQL replication streams the Write-Ahead Log (WAL), which records byte-level page changes; replicas replay WAL to maintain an identical physical copy. MySQL's binlog replication streams SQL statements (statement-based) or row images (row-based); replicas re-execute or re-apply these events. PostgreSQL's physical streaming replication is byte-for-byte identical and very fast, while MySQL's logical binlog replication is more flexible (cross-version, cross-schema) but slower.

**Deep Explanation:**

**PostgreSQL WAL-Based Streaming Replication:**

PostgreSQL writes every change to the WAL before applying it to data pages (write-ahead logging). Streaming replication sends WAL records directly from primary to standby in real time.

```
Primary:
  1. Transaction commits → WAL records written to pg_wal/
  2. WAL sender process reads WAL and streams to standbys
  3. Data pages updated (after WAL is durable)

Standby:
  1. WAL receiver process receives WAL records
  2. WAL records written to standby's pg_wal/
  3. Startup process replays WAL into data pages (recovery mode)
```

**Replication Slots:**
Replication slots prevent the primary from discarding WAL that hasn't been consumed by a replica. Without slots, if a replica falls behind, the primary may recycle WAL files and the replica has to be rebuilt from a base backup.

```sql
-- Create a physical replication slot
SELECT pg_create_physical_replication_slot('standby_slot_1');

-- Monitor replication slot lag
SELECT
    slot_name,
    active,
    restart_lsn,
    pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS lag_bytes
FROM pg_replication_slots;
```

**Danger of replication slots:** If a replica disconnects permanently, the slot continues holding WAL indefinitely. The primary disk fills up. Always monitor slot lag and drop stale slots.

```sql
-- Monitor all replicas and their lag
SELECT
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS total_lag_bytes
FROM pg_stat_replication;
```

**Synchronous vs Asynchronous Replication:**

```sql
-- postgresql.conf on primary
synchronous_commit = on              -- wait for WAL to be flushed on at least one sync standby
synchronous_standby_names = 'FIRST 1 (standby1, standby2)'
-- 'FIRST 1' = at least 1 of the listed standbys must confirm before commit returns
-- 'ANY 2' = any 2 of the listed standbys must confirm (quorum commit, PG 10+)
```

**Logical Replication (PostgreSQL 10+):**
Logical replication streams decoded row changes (INSERT/UPDATE/DELETE) rather than raw WAL bytes. This enables cross-version replication, selective table replication, and is the foundation for CDC (Change Data Capture) with tools like Debezium.

```sql
-- On primary: enable logical replication
-- postgresql.conf: wal_level = logical

-- Create a publication
CREATE PUBLICATION orders_pub FOR TABLE orders, order_items;

-- On replica/subscriber
CREATE SUBSCRIPTION orders_sub
    CONNECTION 'host=primary port=5432 dbname=prod'
    PUBLICATION orders_pub;
```

**MySQL Binlog-Based Replication:**

MySQL writes changes to the binary log (binlog) after the storage engine commits. Replicas pull the binlog and replay events.

```
Statement-based replication (SBR): logs the SQL statement
  → Compact logs, but non-deterministic functions (NOW(), RAND()) can cause divergence

Row-based replication (RBR): logs before/after row images
  → Larger logs, but exact and safe for all operations

Mixed-mode: MySQL chooses SBR when safe, RBR otherwise
```

```sql
-- MySQL: Check replication status on replica
SHOW REPLICA STATUS\G
-- Key fields:
-- Seconds_Behind_Source: replication lag in seconds
-- Replica_IO_Running: YES/NO
-- Replica_SQL_Running: YES/NO
-- Last_Error: error message if SQL thread failed

-- MySQL: Monitor binlog position
SHOW BINARY LOGS;
SHOW MASTER STATUS;
```

**GTID-Based Replication (MySQL 5.6+):**
Global Transaction Identifiers (GTIDs) uniquely identify each transaction across the cluster. Replicas track which GTIDs they've applied, making failover and replica promotion trivial compared to binlog file+offset tracking.

```sql
-- Enable GTIDs
-- my.cnf: gtid_mode=ON, enforce_gtid_consistency=ON

SHOW VARIABLES LIKE 'gtid_executed';  -- GTIDs applied on this server
SHOW VARIABLES LIKE 'gtid_purged';    -- GTIDs purged from binlog
```

**Cascading Replication:**
A replica can itself act as a replication source for downstream replicas, reducing load on the primary.

```
Primary → Replica1 (sync) → Replica2 (async) → Replica3 (async)
                           → Replica4 (async)
```

PostgreSQL cascading: set `recovery_target_timeline` and connect a standby to another standby's WAL sender. MySQL cascading: `log_replica_updates = ON` on the intermediate replica so it writes received binlog events to its own binlog.

**Real-World Example:**
GitHub's MySQL infrastructure uses cascading replication extensively. The primary replicates synchronously to a local standby in the same DC (for HA). That standby then fans out to read replicas in multiple DCs. During a primary failover, the most-up-to-date local standby is promoted using GTID to find the correct position.

**Follow-up Questions:**
1. What is replication lag and how do you monitor it in PostgreSQL vs MySQL?
2. How do replication slots prevent WAL recycling, and what is the risk of an abandoned slot?
3. How does logical replication differ from physical streaming replication, and when would you use each?

**Common Mistakes:**
- Setting `synchronous_commit = on` with no synchronous standby configured — this causes all commits to wait indefinitely until a standby connects
- Not monitoring replication slot lag — an idle slot can fill the primary's disk with retained WAL
- Confusing `Seconds_Behind_Source` in MySQL with true replication lag — it is calculated from the timestamp in the binlog event, which can be wrong if the replica's clock drifts

**Interview Traps:**
- "Does synchronous replication guarantee zero data loss?" — Only if `synchronous_commit = remote_apply` (PostgreSQL). `on` only guarantees WAL is flushed on the standby, not that it's been replayed into pages.
- Physical streaming replication in PostgreSQL creates an identical byte-for-byte copy — you cannot replicate to a different PostgreSQL major version using physical replication.

**Quick Revision:** PostgreSQL streams WAL bytes (physical) or decoded row changes (logical replication); MySQL streams binlog events (statement or row-based); replication slots hold WAL for slow consumers but risk disk exhaustion if abandoned; always monitor lag via `pg_stat_replication` or `SHOW REPLICA STATUS`.

---

### Topic 6: Replication Topologies

**Difficulty:** Medium-Hard | **Frequency:** Medium | **Companies:** Amazon, Google, Meta, MongoDB (Atlas), PlanetScale, Cockroach Labs

**Q:** Compare single-primary, multi-primary, chain, and quorum-based replication topologies. What are the trade-offs of each?

**Short Answer:**
Single-primary replication is the simplest and most common; all writes go to one primary, reads fan out to replicas. Multi-primary allows writes to multiple nodes simultaneously but requires conflict resolution. Chain replication provides strong consistency with sequential acknowledgment. Quorum-based replication (Raft, Paxos) provides consensus-based durability and is used in distributed databases like etcd, CockroachDB, and MongoDB replica sets.

**Deep Explanation:**

**1. Single-Primary Replication (Primary-Replica / Master-Slave):**

```
          Writes
Client ──────────→ Primary
                      │
          WAL/Binlog  ├──→ Replica 1 (reads)
                      ├──→ Replica 2 (reads)
                      └──→ Replica 3 (reads)
```

- All writes to primary; replicas serve reads
- Simple conflict resolution (none needed)
- Single point of write failure → needs automated failover (Patroni for PostgreSQL, MHA/Orchestrator for MySQL)
- Read scaling by adding replicas

**2. Multi-Primary Replication (Active-Active):**

All nodes accept writes. Conflicts occur when two nodes concurrently update the same row.

**Conflict Resolution Strategies:**
- **Last-Write-Wins (LWW)** — The row with the latest timestamp wins. Simple but can silently discard writes.
- **Application-level resolution** — The application is notified of conflicts and resolves them with business logic.
- **CRDTs** — Conflict-free Replicated Data Types that merge automatically (counters, sets).

**Galera Cluster (MySQL/MariaDB):**
Galera uses synchronous multi-primary replication with a certification-based conflict detection mechanism. All nodes have identical data at all times (virtual synchrony). Writes are certified against a global transaction ID set before commit.

```sql
-- Check Galera cluster status
SHOW STATUS LIKE 'wsrep%';
-- wsrep_cluster_size: 3 (number of nodes)
-- wsrep_local_state_comment: Synced
-- wsrep_flow_control_paused: flow control (0 = no throttling)
-- wsrep_cert_deps_distance: degree of parallelism in replication
```

Trade-offs: write latency increases with cluster size (certification roundtrip); split-brain risk if nodes cannot communicate; not suitable for write-heavy workloads with hotspot rows.

**3. Chain Replication:**

```
Client Write → Head (A) → B → C (Tail) → Client Ack
Client Read  → Tail (C)
```

Writes flow from head to tail sequentially; acknowledgment comes from the tail. Reads go only to the tail (always most up-to-date). 

Strong consistency guarantees: a read sees all writes that have been acknowledged. Throughput limited by the weakest link in the chain. Used in: CRAQ (Chain Replication with Apportioned Queries), some distributed storage systems.

**4. Quorum-Based Replication (Raft):**

Raft consensus protocol underlies etcd, CockroachDB, TiKV, and MongoDB replica sets.

```
N nodes, quorum = ⌊N/2⌋ + 1
- 3 nodes: quorum = 2
- 5 nodes: quorum = 3

Leader receives write → appends to its log
                      → sends AppendEntries RPC to all followers
                      → waits for quorum (⌊N/2⌋ + 1) acknowledgments
                      → commits entry, applies to state machine
                      → responds to client
```

**Raft leader election:**
Each node has an election timeout. If no heartbeat is received, a node increments its term and requests votes. A candidate needs a quorum of votes to become leader. The node with the most up-to-date log wins ties.

```
Term 1: Leader = Node A
  Network partition: Node A cannot reach B and C
  Node B times out, increments to Term 2, wins election (B+C = quorum)
  Node A: isolated, cannot commit writes (cannot get quorum)
  Split-brain prevented: A cannot commit without quorum
```

**MongoDB Replica Set (Raft-like):**

```javascript
// Check replica set status
rs.status()
// Shows: primary, secondaries, their optime lag, health

// Write concern: wait for write to reach N members
db.collection.insertOne(
    { data: "value" },
    { writeConcern: { w: "majority", j: true, wtimeout: 5000 } }
)
// w: "majority" = write must be acknowledged by majority of voting members
// j: true = write must be journaled (durable) on those members
```

**Comparison Table:**

| Topology | Write Availability | Read Scalability | Consistency | Complexity |
|---|---|---|---|---|
| Single-Primary | Low (one writer) | High (add replicas) | Strong (sync) / Eventual (async) | Low |
| Multi-Primary | High (any node) | High | Eventual (conflicts possible) | High |
| Chain | Low (head only) | Low (tail only) | Strong | Medium |
| Quorum (Raft) | Quorum required | Reads from any node (stale) or leader | Linearizable | High |

**Real-World Example:**
CockroachDB uses Raft at the range level (each 64MB data range is independently replicated via Raft). This gives CockroachDB linearizable reads from the leaseholder and cross-range ACID transactions via a distributed transaction protocol. Each range typically has 3 or 5 replicas for 1 or 2 failure tolerance.

**Follow-up Questions:**
1. How does Raft handle log divergence when a previously partitioned leader rejoins the cluster?
2. What is the difference between `writeConcern: {w: 1}` and `{w: "majority"}` in MongoDB?
3. Why does Galera Cluster become slow under high write contention, and what is flow control?

**Common Mistakes:**
- Assuming multi-primary automatically resolves conflicts — LWW silently discards concurrent writes; applications must handle conflict scenarios explicitly
- Configuring MongoDB with `writeConcern: {w: 1}` on financial data — a primary failure before replication loses acknowledged writes
- Confusing quorum reads with strong consistency — Raft-based systems require reading from the leader (or using a linearizable read barrier) to guarantee freshness

**Interview Traps:**
- "Does Galera Cluster eliminate data loss on node failure?" — Yes for committed writes (synchronous), but a network partition causing a cluster partition to lose quorum will reject writes entirely.
- Raft requires a stable leader; frequent leader elections (due to network instability) cause write unavailability — this is by design to prefer consistency over availability (CP in CAP theorem).

**Quick Revision:** Single-primary is simple with one write endpoint; multi-primary allows concurrent writes but needs conflict resolution; Raft/quorum replication provides consensus-based linearizability used in CockroachDB/MongoDB; always match topology to your consistency and availability requirements.

---

### Topic 7: Connection Pooling Deep Dive

**Difficulty:** Medium-Hard | **Frequency:** High | **Companies:** Amazon, Google, Meta, Shopify, GitHub, Cloudflare

**Q:** How does PgBouncer connection pooling work, and how do its three modes differ? How does it compare to HikariCP?

**Short Answer:**
PgBouncer is a connection pooler that sits between the application and PostgreSQL, maintaining a pool of backend connections and multiplexing many client connections onto fewer backend connections. It has three modes: session pooling (one backend per client session), transaction pooling (backend leased only for transaction duration), and statement pooling (backend returned after each statement). Transaction pooling provides the highest multiplexing ratio and is the standard production choice.

**Deep Explanation:**

**Why Connection Pooling?**

PostgreSQL creates a new OS process for each backend connection. Each connection consumes ~5-10MB of RAM and has startup overhead. A busy application with 1000 concurrent clients would need 1000 PostgreSQL backend processes. PostgreSQL's recommended `max_connections` is typically 100-300 for a standard server. PgBouncer solves the impedance mismatch.

```
Without PgBouncer:
  1000 app threads → 1000 PostgreSQL backends → Out of memory

With PgBouncer (transaction pooling):
  1000 app threads → PgBouncer (pool of 50) → 50 PostgreSQL backends
  Each backend handles ~20 transactions/sec = 1000 tps aggregate
```

**PgBouncer Modes:**

**1. Session Pooling:**
A backend connection is assigned to a client for the entire session duration (from connect to disconnect). The multiplexing ratio equals the ratio of client connections to backend connections. Minimal benefit — only reduces connection establishment overhead.

```ini
; pgbouncer.ini
pool_mode = session
max_client_conn = 1000
default_pool_size = 100
; Client holds the backend for their entire session
```

**2. Transaction Pooling (Recommended):**
A backend connection is checked out only for the duration of a transaction. After `COMMIT` or `ROLLBACK`, the backend is returned to the pool. This is the highest multiplexing mode.

```ini
pool_mode = transaction
max_client_conn = 10000
default_pool_size = 25
; 10,000 clients share 25 backends, viable if transactions are short
```

**Limitations of transaction pooling:**
- `SET` statements and session-level variables are NOT safe — they persist on the backend and affect the next client that gets that connection
- Prepared statements (protocol-level, not SQL-level) are not supported without `server_reset_query`
- Advisory locks tied to session are not reliable
- `LISTEN`/`NOTIFY` does not work (session-bound)

**3. Statement Pooling:**
Backend is returned to the pool after every single SQL statement. Multi-statement transactions are NOT supported. Very rare in production — only for truly stateless single-statement workloads.

```ini
pool_mode = statement
; Cannot use BEGIN/COMMIT — each statement auto-commits
```

**Connection Storm on Startup:**
When an application tier restarts (e.g., 50 pods come up simultaneously), all pods try to acquire connections at once, overwhelming PgBouncer or PostgreSQL.

```ini
; PgBouncer settings to mitigate connection storms
max_client_conn = 5000
default_pool_size = 25        ; max backends per db-user pair
min_pool_size = 5             ; keep N connections warm
reserve_pool_size = 5         ; emergency reserve
reserve_pool_timeout = 5      ; seconds before using reserve
server_round_robin = 1        ; spread across multiple PgBouncer instances
```

Application-side mitigation:
```yaml
# Spring Boot HikariCP: stagger connection acquisition on startup
spring.datasource.hikari.initializationFailTimeout: 60000
spring.datasource.hikari.minimumIdle: 2  # start small, grow as needed
```

**Prepared Statements in Transaction Pooling:**

PostgreSQL protocol-level prepared statements are session-scoped. With transaction pooling, the backend changes between transactions, so prepared statements prepared in one transaction are not available in the next.

Solutions:
1. **Disable server-side prepared statements** — JDBC: `prepareThreshold=0`
2. **PgBouncer `server_reset_query`** — Runs `DEALLOCATE ALL` before returning connection to pool (expensive)
3. **Use pgBouncer in session mode** for applications that require prepared statements (e.g., some ORMs)
4. **PgBouncer 1.21+ prepared statement tracking** — Experimental support for tracking and re-preparing as needed

```java
// JDBC: disable server-side prepared statements for PgBouncer transaction pooling
String url = "jdbc:postgresql://pgbouncer:5432/mydb?prepareThreshold=0";
// prepareThreshold=0 forces all queries to use simple query protocol (no server-side prepare)
```

**Pgpool-II vs PgBouncer:**
Pgpool-II provides connection pooling + load balancing + query routing (send reads to replicas, writes to primary) + parallel query execution. It is heavier-weight than PgBouncer and introduces more latency per query. PgBouncer does one thing well: connection multiplexing.

**Real-World Example:**
Shopify runs PgBouncer in transaction pooling mode in front of all their PostgreSQL shards. With hundreds of Rails app servers, each potentially holding up to `pool_size` connections, PgBouncer limits the actual backend connection count to a configured value (e.g., 25) regardless of how many app servers are running, preventing the well-known "thundering herd" problem during deployments.

**Code Example:**
```ini
; /etc/pgbouncer/pgbouncer.ini — production transaction pooling config
[databases]
mydb = host=postgres-primary port=5432 dbname=mydb

[pgbouncer]
listen_port = 6432
listen_addr = 0.0.0.0
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

pool_mode = transaction
max_client_conn = 10000
default_pool_size = 25
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3

server_idle_timeout = 600        ; close idle backend after 10 min
client_idle_timeout = 0          ; don't close idle clients
server_lifetime = 3600           ; recycle backend connections hourly
server_reset_query = DISCARD ALL ; run on backend before returning to pool (session mode)
                                  ; for transaction mode, DISCARD ALL is NOT run by default
ignore_startup_parameters = extra_float_digits  ; ignore pg 12+ parameter
```

**Follow-up Questions:**
1. Why can't you use `LISTEN`/`NOTIFY` with PgBouncer in transaction pooling mode?
2. What is `DISCARD ALL` and when does PgBouncer execute it?
3. How does PgBouncer authentication work when the application provides credentials — does it pass them through or authenticate independently?

**Common Mistakes:**
- Using session-level SET statements with transaction pooling — these modify the backend session but the next client inherits them
- Not setting `prepareThreshold=0` when using Hibernate/JDBC with transaction pooling — leads to "prepared statement does not exist" errors
- Forgetting that `max_client_conn` in PgBouncer does not limit backend connections — `default_pool_size` does

**Interview Traps:**
- "PgBouncer eliminates the need for application-side pooling" — False; you should still use HikariCP (or similar) in the application to avoid per-request connection acquisition overhead from PgBouncer.
- The interaction between PgBouncer and PostgreSQL's `max_connections` is often confused — PgBouncer's `default_pool_size` should be set so `pool_size * num_databases * num_users` stays well under PostgreSQL's `max_connections`.

**Quick Revision:** PgBouncer multiplexes client connections onto fewer PostgreSQL backends; transaction pooling (the standard) leases a backend only for the transaction duration; prepared statements and session-level state are incompatible with transaction pooling; always disable server-side prepared statements (prepareThreshold=0) when using transaction pooling.

---

### Topic 8: HikariCP Internals

**Difficulty:** Medium-Hard | **Frequency:** High | **Companies:** Amazon, Google, Meta, Netflix, Shopify, any Spring Boot shop

**Q:** How does HikariCP manage connections internally, and how do you tune it correctly for production?

**Short Answer:**
HikariCP maintains a pool of PoolEntry objects wrapping JDBC connections. Connection acquisition uses a lock-free ConcurrentBag with thread-local affinity for low-latency handoff. Pool sizing follows Little's Law: pool size = (core count * 2) + number of spindles. Connections are validated on borrow (if keepaliveTime is set) and leaked connections are detected via leakDetectionThreshold.

**Deep Explanation:**

**HikariCP Architecture:**

HikariCP's core data structure is the `ConcurrentBag<PoolEntry>`. Each `PoolEntry` wraps a JDBC `Connection` and tracks its state: NOT_IN_USE, IN_USE, RESERVED, REMOVED.

```
ConcurrentBag:
  sharedList:    CopyOnWriteArrayList<PoolEntry>  (all connections)
  threadList:    ThreadLocal<List<Object>>         (thread-local affinity cache)
  waiters:       AtomicInteger                     (threads waiting for connections)
  handoffQueue:  SynchronousQueue<PoolEntry>       (for direct handoff to waiting threads)
```

**Connection Acquisition Flow:**

```java
// Simplified HikariCP acquisition logic
public Connection getConnection(long timeout) throws SQLException {
    // 1. Try thread-local list first (O(1) if recently returned by same thread)
    PoolEntry entry = bag.borrow(timeout, MILLISECONDS);
    if (entry == null) throw new SQLTransientConnectionException("timeout");

    // 2. Check if connection is still alive (if validation required)
    if (isConnectionDead(entry)) {
        closeConnection(entry, "dead connection");
        return getConnection(timeout); // retry
    }

    // 3. Wrap in ProxyConnection for leak detection and state tracking
    return entry.createProxyConnection(leakTaskFactory.schedule(entry));
}
```

**Thread-Local Affinity:**
When a thread returns a connection to the pool, it is added to that thread's local list. The next `borrow()` from the same thread checks the thread-local list first, enabling lock-free connection reuse for the common case (same thread acquires/releases repeatedly). This makes HikariCP extremely fast for request-scoped connection patterns.

**Pool Sizing Formula (Little's Law):**

HikariCP's documentation (and PostgreSQL's wiki) recommends:

```
pool_size = (number_of_cores * 2) + number_of_spindles
```

For a 4-core SSD server: `pool_size = (4 * 2) + 1 = 9`

The intuition: each core can handle 2 threads (one executing, one waiting for I/O). Disk spindles add a thread for I/O waits. More connections beyond this point do NOT increase throughput — they add context switching overhead.

```yaml
# Spring Boot application.yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/mydb
    username: app_user
    password: ${DB_PASSWORD}
    hikari:
      # Pool sizing
      maximum-pool-size: 10          # Hard cap: no more than this many connections
      minimum-idle: 5                # Keep this many connections idle (warm)
      connection-timeout: 30000      # Max ms to wait for a connection from pool
      idle-timeout: 600000           # Close idle connections after 10 min
      max-lifetime: 1800000          # Recycle connections after 30 min (< DB timeout)
      
      # Validation
      keepalive-time: 60000          # Send keepalive every 60s to prevent firewall drops
      connection-test-query: SELECT 1 # Fallback if JDBC4 isValid() not supported
      
      # Leak detection
      leak-detection-threshold: 5000 # Warn if connection held > 5s
      
      # Connection init
      connection-init-sql: "SET application_name = 'myapp'"
      pool-name: "MainPool"
      register-mbeans: true          # Expose JMX metrics
```

**Connection Validation:**

HikariCP validates connections using the JDBC4 `Connection.isValid(int timeout)` method, which sends a lightweight ping to the database. For older JDBC drivers, `connectionTestQuery` is the fallback.

`keepaliveTime` (HikariCP 5.0+): Periodically pings idle connections to keep them alive through network firewalls and load balancers that close idle TCP connections. Set this below the firewall idle connection timeout.

```java
// What happens internally during keepalive
// HikariPool.KeepaliveTask (runs every keepaliveTime ms)
for (PoolEntry entry : connectionBag.values(STATE_NOT_IN_USE)) {
    if (clock.currentTime() - entry.lastAccessed > keepaliveTime) {
        entry.connection.isValid(1); // ping
        // If not valid: close and replace with new connection
    }
}
```

**Leak Detection:**

When `leakDetectionThreshold` is set, HikariCP schedules a `ProxyLeakTask` when a connection is borrowed. If the connection is not returned within `leakDetectionThreshold` milliseconds, HikariCP logs a warning with the stack trace of the borrowing thread.

```
WARN  HikariPool-1 - Connection leak detection triggered for conn123,
      stack trace follows:
      at com.example.UserService.getUserById(UserService.java:45)
      at com.example.UserController.getUser(UserController.java:23)
      ...
```

```java
// Borrowing and returning connections in Spring (automatic via @Transactional)
@Service
@Transactional(readOnly = true)
public class UserService {
    // Connection is borrowed when method starts, returned when it ends
    // If readOnly = true, HikariCP can route to a read replica (with routing config)
    public User getUserById(Long id) {
        return userRepository.findById(id).orElseThrow();
    }
}

// Manual connection management (use sparingly)
@Autowired
private DataSource dataSource;

public void runBatch() throws SQLException {
    try (Connection conn = dataSource.getConnection()) {  // borrow
        // ... use connection
    } // auto-return via close()
}
```

**Connection Storm on Startup (HikariCP):**

When a Spring Boot application starts, HikariCP eagerly initializes `minimumIdle` connections. If the application has many instances starting simultaneously:

```yaml
hikari:
  minimum-idle: 2          # Start with only 2 connections (grow as load comes in)
  maximum-pool-size: 10    # Cap at 10
  initialization-fail-timeout: 60000  # Wait up to 60s for initial connection
  # Set to -1 to not fail startup if DB is not available (resilient startup)
```

**HikariCP vs PgBouncer:**

| Dimension | HikariCP | PgBouncer |
|---|---|---|
| Layer | Application (JVM) | Network proxy (separate process) |
| Scope | Single JVM instance | All applications connecting to a DB |
| Multiplexing | 1 connection per JVM thread slot | Many app connections → few backends |
| Session state | Preserved (same JDBC connection for session) | Lost between transactions (txn pooling) |
| Prepared statements | Fully supported | Requires prepareThreshold=0 in txn mode |
| Overhead | No network hop | Extra network hop per query |
| Best for | Reducing per-request connection overhead within one app | Limiting total connections to PostgreSQL across many apps |

**Real-World Example:**
Netflix found that most of their microservices were configured with `maximumPoolSize` of 50-100, but actual concurrency was much lower. Using HikariCP's JMX metrics (`HikariCP-MainPool-ActiveConnections`, `HikariCP-MainPool-PendingConnections`), they right-sized pools to 5-10, dramatically reducing PostgreSQL's `max_connections` pressure and memory usage.

**JMX Monitoring:**
```java
// Programmatic pool monitoring
HikariDataSource ds = (HikariDataSource) dataSource;
HikariPoolMXBean poolBean = ds.getHikariPoolMXBean();

int active     = poolBean.getActiveConnections();
int idle       = poolBean.getIdleConnections();
int total      = poolBean.getTotalConnections();
int waiting    = poolBean.getThreadsAwaitingConnection();

// Metric to alert on: waiting > 0 for sustained period = pool exhaustion
```

**Follow-up Questions:**
1. Why does HikariCP recommend `maximumPoolSize` be set equal to `minimumIdle` for most production workloads?
2. How does `maxLifetime` prevent connections from being closed by the database server's `wait_timeout`?
3. What does the `connectionInitSql` property do, and when would you use it?

**Common Mistakes:**
- Setting `maximumPoolSize` too high thinking "more connections = more throughput" — beyond the optimal size, throughput decreases and memory pressure increases
- Not setting `maxLifetime` below the database server's connection timeout — the DB closes the connection but HikariCP still thinks it's valid, causing "connection closed" errors
- Setting `minimumIdle = maximumPoolSize` as a "safe" default — this pre-allocates all connections on startup, causing a connection storm with many service instances

**Interview Traps:**
- "HikariCP replaces the need for PgBouncer" — False. HikariCP pools within one JVM. If you have 100 JVM instances each with a pool of 10, you have 1000 PostgreSQL connections. PgBouncer caps this at the backend pool size regardless of application instance count.
- `leakDetectionThreshold` does NOT close the leaked connection — it only logs a warning. The connection eventually times out via `maxLifetime` or the database's own idle timeout.
- Setting `connection-timeout: 30000` means the application waits up to 30 seconds for a connection from the pool. If the pool is exhausted, users wait 30 seconds before getting an error — consider a much shorter timeout (1-3s) with circuit breakers.

**Quick Revision:** HikariCP uses a ConcurrentBag with thread-local affinity for lock-free connection handoff; size the pool to (cores * 2 + spindles); set maxLifetime below DB timeout; use keepaliveTime to prevent firewall drops; leakDetectionThreshold logs stack traces of leaked connections but does not close them.

---

## Part A Summary

| Topic | Key Takeaway |
|---|---|
| Table Partitioning | Range/list/hash split data physically; partition pruning skips irrelevant partitions; best for time-series with retention |
| H vs V Sharding | Vertical = split by domain; horizontal = split rows by shard key; sharding is multi-node partitioning |
| Shard Key Design | High cardinality, uniform, immutable, query-local; avoid monotonically increasing keys (write hotspot) |
| Cross-Shard Queries | Scatter-gather pattern; avoid cross-shard joins via co-location; aggregations decompose for SUM/COUNT not median |
| Replication Internals | PostgreSQL WAL streaming vs MySQL binlog; replication slots hold WAL but risk disk fill; monitor lag always |
| Replication Topologies | Single-primary is simple; multi-primary needs conflict resolution; Raft provides linearizable consensus |
| Connection Pooling | PgBouncer transaction pooling: max multiplexing; breaks prepared statements; set prepareThreshold=0 |
| HikariCP Internals | ConcurrentBag with thread-local affinity; size = cores*2+spindles; maxLifetime < DB timeout; leakDetectionThreshold warns |

---

*Continue to Part B: Query Planning, MVCC, Vacuum, Logical Decoding, and Time-Series Optimizations*


---

# Chapter 18 — Advanced Database Topics (Part B)
> **Target:** SDE2 / Senior, FAANG+, FinTech
> **Prerequisites:** Chapter 18 Part A (Topics 1–8)

---

### Topic 9: Database Proxies & Middleware

**Difficulty:** Hard | **Frequency:** Medium | **Companies:** Stripe, Shopify, Netflix, Uber, AWS shops

**Q:** How do database proxies like ProxySQL, pgBouncer, and AWS RDS Proxy improve scalability, and when would you choose each?

**Short Answer:**
Database proxies sit between application servers and database instances to multiplex connections, enforce read/write splitting, and abstract failover. They solve the N×M connection explosion problem where N app pods × M DB replicas would exhaust the database's connection limit. Each proxy offers different trade-offs in protocol awareness, pooling strategy, and cloud integration.

**Deep Explanation:**

**The Connection Problem**
PostgreSQL and MySQL allocate a dedicated OS process or thread per connection. Each idle connection consumes ~5–10 MB RAM on PostgreSQL. A Kubernetes deployment with 50 pods × 20 connection pool size = 1,000 connections before any traffic arrives. RDS `db.r5.4xlarge` has a `max_connections` of ~5,000 — that headroom disappears fast.

**ProxySQL (MySQL)**
- Layer 7 MySQL proxy; understands the MySQL protocol deeply
- **Read/write splitting:** Routes `SELECT` to read replicas, `INSERT/UPDATE/DELETE` to primary — configured via query rules (regex on SQL text)
- **Connection multiplexing:** Frontend connections (app → proxy) are many; backend connections (proxy → MySQL) are few
- **Query caching, query rewriting, sharding hints** built in
- **Failover:** Integrates with Orchestrator/MHA for automatic failover; updates host groups on topology change
- Config is stored in its own SQLite-backed runtime config; changes applied with `LOAD … TO RUNTIME`

```sql
-- ProxySQL: add a hostgroup rule to route reads to replicas
INSERT INTO mysql_query_rules (rule_id, active, match_digest, destination_hostgroup, apply)
VALUES (1, 1, '^SELECT', 2, 1);   -- hostgroup 2 = read replicas
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
```

**pgBouncer (PostgreSQL)**
- Lightweight (~500KB) single-process connection pooler for PostgreSQL
- Three pooling modes:
  - **Session pooling:** One server connection per client session (least multiplexing; default)
  - **Transaction pooling:** Server connection held only during a transaction — highest multiplexing; breaks `SET`, advisory locks, prepared statements
  - **Statement pooling:** One connection per statement — rarely used
- Does NOT do read/write splitting natively; pair with HAProxy or application-level routing
- Low overhead: handles 10K+ clients on a single core

**pgPool-II (PostgreSQL)**
- Heavier than pgBouncer; adds load balancing, parallel query, and in-memory query cache
- More operational complexity; community generally prefers pgBouncer + Patroni for modern stacks

**AWS RDS Proxy**
- Fully managed; sits inside your VPC
- **Connection multiplexing** backed by a connection pool maintained to RDS/Aurora
- **IAM authentication:** Applications authenticate to RDS Proxy using AWS IAM tokens (no plaintext passwords in app config); proxy holds the DB credentials in Secrets Manager
- **Failover acceleration:** On Multi-AZ failover, proxy pins active connections to new primary in ~30s vs the ~60s a direct client would take
- Pinning behavior: some operations (temp tables, `SET` commands) "pin" a connection, reducing multiplexing benefit — monitor `DatabaseConnectionsCurrentlySessionPinned` in CloudWatch

```yaml
# Spring Boot application.properties — pointing at RDS Proxy with IAM auth
spring.datasource.url=jdbc:postgresql://<proxy-endpoint>:5432/mydb
spring.datasource.username=myapp
# password = IAM token, refreshed by custom DataSource wrapper
spring.datasource.hikari.maximum-pool-size=10   # small — proxy handles the fan-out
```

**Choosing the Right Proxy**

| Scenario | Choice |
|---|---|
| MySQL at scale, need query routing + failover | ProxySQL |
| PostgreSQL, need efficient connection pooling | pgBouncer (transaction mode) |
| PostgreSQL on AWS, need IAM auth + managed ops | RDS Proxy |
| Need read/write split in PostgreSQL | pgBouncer + HAProxy, or application datasource routing |

**Real-World Example:**
A FinTech platform had 200 Spring Boot pods each with HikariCP pool size 20 = 4,000 connections to a single Aurora PostgreSQL writer. During deploy, new pods came up before old ones shut down, spiking to 6,000 connections and crashing the writer. Solution: insert pgBouncer in transaction mode capping backend connections at 200. The 4,000 frontend connections from HikariCP multiplexed down to 200 server connections — problem eliminated.

**Follow-up Questions:**
1. What operations break transaction-mode pooling in pgBouncer, and how do you handle them?
2. How does RDS Proxy "pinning" work, and what causes it?
3. How would you implement blue/green deployment with ProxySQL hostgroup switching?

**Common Mistakes:**
- Setting HikariCP pool size large AND using pgBouncer — the two pools fight; keep HikariCP at 2–5 when pgBouncer is in front
- Using pgBouncer transaction mode with prepared statements (they are session-scoped and get lost) — disable `prepareThreshold=0` in the JDBC URL or use pgBouncer's `server_reset_query`
- Not monitoring proxy connection lag — a slow proxy is invisible until it cascades

**Interview Traps:**
- "pgBouncer does read/write splitting" — it does NOT natively; this is a common misconception
- Assuming RDS Proxy eliminates all connection overhead — pinned connections still hold a real DB connection

**Quick Revision:** Database proxies multiplex many app connections into fewer DB connections; ProxySQL for MySQL with query routing, pgBouncer for lightweight PostgreSQL pooling, RDS Proxy for managed AWS with IAM auth.

---

### Topic 10: Zero-Downtime Schema Migrations

**Difficulty:** Hard | **Frequency:** High | **Companies:** GitHub, Shopify, Stripe, LinkedIn, Booking.com

**Q:** How do you perform schema migrations on a large, high-traffic table without taking downtime?

**Short Answer:**
Zero-downtime migrations follow the expand-contract pattern: add new structures while keeping the old ones working, dual-write or backfill, then remove the old structure in a later deployment. Tools like gh-ost (MySQL) and pg_repack (PostgreSQL) perform online table rebuilds without long locks. The key insight is that DDL changes must be backward-compatible with the N-1 version of the application running simultaneously.

**Deep Explanation:**

**Why Standard ALTER TABLE Fails**
`ALTER TABLE ADD COLUMN NOT NULL` on a 500M-row table in PostgreSQL < 11 rewrites the entire table, holding an `AccessExclusiveLock` for minutes. Even in PostgreSQL 11+, adding a NOT NULL column with a default is instant (stored in catalog), but adding a constraint or index still blocks writes.

**The Expand-Contract (Blue-Green Schema) Pattern**

Phase 1 — **Expand:** Add the new structure; old code ignores it
```sql
-- Safe: adds nullable column, no table rewrite in PG 11+
ALTER TABLE orders ADD COLUMN delivery_instructions TEXT;
-- Safe: CREATE INDEX CONCURRENTLY does not block reads or writes
CREATE INDEX CONCURRENTLY idx_orders_delivery ON orders(delivery_instructions);
```

Phase 2 — **Migrate/Backfill:** Populate new structure in batches
```java
// Batch backfill — never update all rows in one transaction
int batchSize = 1000;
long lastId = 0;
while (true) {
    int updated = jdbcTemplate.update(
        "UPDATE orders SET delivery_instructions = '' " +
        "WHERE id > ? AND id <= ? + ? AND delivery_instructions IS NULL",
        lastId, lastId, batchSize);
    lastId += batchSize;
    if (updated == 0) break;
    Thread.sleep(100); // throttle to avoid I/O saturation
}
```

Phase 3 — **Contract:** Remove old column/structure after new code is fully deployed
```sql
-- Only after all app versions using old column are retired
ALTER TABLE orders DROP COLUMN old_status_code;
```

**Backward-Compatible Changes Checklist**
- Adding a nullable column: SAFE
- Adding a column with a default (PostgreSQL 11+): SAFE (stored in catalog until row updated)
- Adding a NOT NULL column without default: DANGEROUS (requires backfill first, then constraint)
- Renaming a column: DANGEROUS — use a new column + copy data + remove old
- Changing column type: DANGEROUS — add new column with new type, dual-write, migrate, drop old
- Adding an index: Use `CREATE INDEX CONCURRENTLY`
- Dropping a column: Safe only after no code references it
- Adding a foreign key: `NOT VALID` first, then `VALIDATE CONSTRAINT` (shares lock only briefly)

```sql
-- Safe FK addition: two steps
ALTER TABLE order_items ADD CONSTRAINT fk_order
    FOREIGN KEY (order_id) REFERENCES orders(id) NOT VALID;
-- Later, validate (takes ShareUpdateExclusiveLock, allows reads/writes)
ALTER TABLE order_items VALIDATE CONSTRAINT fk_order;
```

**gh-ost (GitHub's Online Schema Tool for MySQL)**
- Creates a shadow table `_tablename_gho`, copies rows in chunks, applies binlog changes as deltas, then atomically renames the shadow table
- No triggers (unlike pt-online-schema-change) — less write amplification
- Supports pause/resume, throttle based on replica lag
- Runs as an external process — no MySQL plugin required

```bash
gh-ost \
  --host=primary.db.internal \
  --database=payments \
  --table=transactions \
  --alter="ADD COLUMN processed_at TIMESTAMP NULL" \
  --execute \
  --max-load=Threads_running=25 \
  --critical-load=Threads_running=100 \
  --chunk-size=1000 \
  --throttle-control-replicas=replica1.db.internal
```

**pg_repack (PostgreSQL)**
- Rebuilds a table without holding `AccessExclusiveLock` for the duration
- Uses triggers to capture changes during rebuild, then swaps at the end with a brief lock
- Useful for: reclaiming bloat, changing storage parameters, reordering rows by cluster key

```bash
pg_repack --host=localhost --dbname=payments --table=transactions --no-order
```

**Online DDL in MySQL 8**
- MySQL 8 supports `ALGORITHM=INPLACE` and `ALGORITHM=INSTANT` for many DDL operations
- `INSTANT`: Adding a column at the end (no table rebuild, metadata-only)
- `INPLACE`: Rebuilds table internally without full table lock for writes
- `COPY`: Full table copy with shared read lock — the old behavior

```sql
-- MySQL 8: instant column add
ALTER TABLE transactions 
    ADD COLUMN notes TEXT, 
    ALGORITHM=INSTANT;

-- MySQL 8: inplace index add (non-blocking for DML)
ALTER TABLE transactions 
    ADD INDEX idx_status (status),
    ALGORITHM=INPLACE, LOCK=NONE;
```

**Real-World Example:**
Stripe renamed the `amount` column to `amount_cents` on a 2-billion-row table. Their process: (1) add `amount_cents` column, (2) deploy code that writes to BOTH columns and reads from `amount_cents` if non-null else falls back to `amount`, (3) backfill `amount_cents` from `amount` in batches over 2 weeks, (4) deploy code reading only from `amount_cents`, (5) drop `amount` column 30 days later after verifying no reads.

**Follow-up Questions:**
1. How does gh-ost handle replica lag during a migration, and why does that matter?
2. What is the `NOT VALID` constraint trick, and when is it safe to validate?
3. How would you handle a migration that requires changing a column's data type from `VARCHAR(50)` to `TEXT`?

**Common Mistakes:**
- Running `CREATE INDEX` without `CONCURRENTLY` on a live table — blocks all writes
- Backfilling without throttling — saturates I/O and degrades production queries
- Deploying code that requires a new column before the migration adds it — app crashes
- Not testing the migration on a production-sized snapshot first

**Interview Traps:**
- "Just use `ALTER TABLE` in a transaction" — PostgreSQL DDL is transactional but the lock is still held for the duration
- Assuming `CONCURRENTLY` is always safe — it cannot run inside a transaction block and will fail if the table has invalid indexes

**Quick Revision:** Zero-downtime migrations use expand-contract: add new structures, backfill in small batches, then remove old structures; use `CREATE INDEX CONCURRENTLY` and tools like gh-ost/pg_repack for large tables.

---

### Topic 11: Database Observability

**Difficulty:** Medium-Hard | **Frequency:** High | **Companies:** All production engineering roles, SRE teams

**Q:** How do you diagnose slow queries, lock waits, and long-running transactions in a PostgreSQL production system?

**Short Answer:**
PostgreSQL ships with rich built-in views: `pg_stat_statements` for aggregated query performance, `pg_stat_activity` for current session state, and `pg_locks` for lock graph analysis. Pairing these with `auto_explain` for real-time EXPLAIN plans and external metrics (Datadog, Prometheus) gives full observability. Alerting on lock chains and idle-in-transaction sessions prevents cascading outages.

**Deep Explanation:**

**pg_stat_statements — Query Performance Aggregates**
```sql
-- Enable: add to postgresql.conf
-- shared_preload_libraries = 'pg_stat_statements'

-- Top 10 slowest queries by total time
SELECT 
    left(query, 80) AS query_preview,
    calls,
    round(total_exec_time::numeric, 2) AS total_ms,
    round(mean_exec_time::numeric, 2) AS mean_ms,
    round(stddev_exec_time::numeric, 2) AS stddev_ms,
    rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Queries with high I/O (missing indexes)
SELECT 
    left(query, 80),
    shared_blks_read,   -- pages read from disk
    shared_blks_hit,    -- pages served from buffer cache
    round(100.0 * shared_blks_hit / 
          NULLIF(shared_blks_hit + shared_blks_read, 0), 1) AS cache_hit_pct
FROM pg_stat_statements
WHERE shared_blks_read > 10000
ORDER BY shared_blks_read DESC;
```

**pg_stat_activity — Live Session Monitor**
```sql
-- Find long-running queries (> 5 minutes)
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state,
    wait_event_type,
    wait_event
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
  AND state != 'idle'
ORDER BY duration DESC;

-- Find idle-in-transaction sessions (connection leak indicator)
SELECT pid, usename, application_name, 
       now() - xact_start AS txn_age,
       state, query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND xact_start < now() - interval '1 minute';
```

**pg_locks — Lock Graph Analysis**
```sql
-- Find blocking lock chains
SELECT 
    blocked.pid AS blocked_pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query,
    blocked.wait_event_type,
    blocked.wait_event
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking 
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE cardinality(pg_blocking_pids(blocked.pid)) > 0;

-- Kill a blocking session (requires superuser)
SELECT pg_terminate_backend(blocking_pid);
```

**auto_explain — Capture Slow Query Plans**
```sql
-- postgresql.conf
-- shared_preload_libraries = 'auto_explain'
-- auto_explain.log_min_duration = 1000    -- log plans for queries > 1s
-- auto_explain.log_analyze = on           -- include actual rows/time
-- auto_explain.log_buffers = on           -- include buffer stats
-- auto_explain.log_nested_statements = on -- log plans inside functions
```

The logged plan appears in `postgresql.log` — feed to PgBadger or pganalyze for analysis.

**MySQL Slow Query Log**
```ini
# my.cnf
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1        # seconds
log_queries_not_using_indexes = 1
log_throttle_queries_not_using_indexes = 10  # max 10/min to avoid log spam
```

```sql
-- MySQL: PERFORMANCE_SCHEMA equivalent of pg_stat_statements
SELECT 
    DIGEST_TEXT,
    COUNT_STAR,
    SUM_TIMER_WAIT/1e12 AS total_sec,
    AVG_TIMER_WAIT/1e12 AS avg_sec
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;
```

**Prometheus + Grafana Setup**
Use `postgres_exporter` (prometheus-community/postgres_exporter):
```yaml
# Key metrics to alert on:
# pg_stat_activity_count{state="active"} > 100        -- connection saturation
# pg_locks_count{mode="ExclusiveLock"} > 10           -- lock contention
# pg_stat_bgwriter_maxwritten_clean_total              -- checkpoint pressure
# pg_replication_lag_seconds > 30                     -- replica falling behind
# rate(pg_stat_statements_total_time[5m]) > threshold -- query time spike
```

**Datadog DB Monitoring**
Datadog's Database Monitoring product captures query samples with full explain plans, tracks query metrics over time, and alerts on plan regressions — e.g., a query that switches from index scan to seq scan after a statistics update.

**Alerting Best Practices**
```yaml
alerts:
  - name: LongRunningTransaction
    condition: "pg_stat_activity where state='idle in transaction' AND age > 5min"
    severity: warning
    action: "auto_explain capture, notify on-call"
    
  - name: LockWaitCascade
    condition: "pg_blocking_pids chain length > 3"
    severity: critical
    action: "dump pg_locks, pg_stat_activity, consider pg_terminate_backend"
    
  - name: ConnectionPoolExhaustion
    condition: "active_connections / max_connections > 0.85"
    severity: warning
    action: "check for connection leaks, idle-in-transaction sessions"
```

**Real-World Example:**
A payment service experienced random 30-second query spikes every few hours. `pg_stat_statements` showed the culprit was a `SELECT * FROM ledger WHERE account_id = ?` that had 1000x variance in execution time (stddev >> mean). `auto_explain` captured plans during a slow period, revealing a sequential scan — the statistics had gone stale due to a bulk import, causing the planner to choose a full scan over the index. Fix: `ANALYZE ledger` after bulk imports + set `autovacuum_analyze_threshold` lower for that table.

**Follow-up Questions:**
1. How do you identify N+1 query patterns in production without modifying application code?
2. What causes auto_explain to produce different plans than manual EXPLAIN ANALYZE?
3. How would you set up alerting for a deadlock — not just a lock wait?

**Common Mistakes:**
- Not enabling `pg_stat_statements` at all (it ships disabled)
- Ignoring `stddev_exec_time` — a query with mean 10ms but stddev 500ms is far more dangerous than a steady 100ms query
- Not monitoring replica lag alongside primary metrics

**Interview Traps:**
- "Just look at slow query log" — it only captures completed slow queries; `pg_stat_activity` catches currently-running long queries
- `pg_stat_statements` resets on server restart unless `pg_stat_statements.save = on`

**Quick Revision:** Use `pg_stat_statements` for query trends, `pg_stat_activity` for live sessions, `pg_locks`/`pg_blocking_pids()` for lock chains, and `auto_explain` to capture plans of slow queries automatically.

---

### Topic 12: Backup & Recovery Strategies

**Difficulty:** Medium-Hard | **Frequency:** Medium-High | **Companies:** All production DBA/SRE roles, FinTech, Healthcare

**Q:** What are the differences between logical and physical backups in PostgreSQL, and how do you implement Point-In-Time Recovery (PITR)?

**Short Answer:**
Logical backups (`pg_dump`) export data as SQL or custom format — portable across versions but slow for large databases. Physical backups (`pg_basebackup`) copy data files at the filesystem level — fast and complete but version-specific. WAL archiving combined with a base backup enables PITR: restoring to any point in time, not just a backup timestamp. RTO and RPO requirements dictate which strategy to use.

**Deep Explanation:**

**RTO vs RPO**
- **RPO (Recovery Point Objective):** Maximum acceptable data loss. If RPO = 5 minutes, you must be able to restore to within 5 minutes of any failure
- **RTO (Recovery Time Objective):** Maximum acceptable downtime. If RTO = 30 minutes, the database must be back up within 30 minutes
- Daily backup → RPO = up to 24h. WAL archiving every 1 minute → RPO ≈ 1 minute

**Logical Backups — pg_dump**
```bash
# Dump a single database in custom format (compressed, parallel-restorable)
pg_dump \
  --host=primary.db.internal \
  --port=5432 \
  --username=backup_user \
  --dbname=payments \
  --format=custom \           # custom format supports parallel restore
  --compress=9 \
  --file=/backups/payments_$(date +%Y%m%d).dump

# Parallel restore (uses multiple workers)
pg_restore \
  --host=restore-target.db.internal \
  --dbname=payments \
  --jobs=4 \                  # 4 parallel workers
  --verbose \
  /backups/payments_20260702.dump

# Dump schema only (for DDL audits)
pg_dump --schema-only --dbname=payments > schema.sql

# Dump specific table
pg_dump --table=transactions --dbname=payments > transactions.sql
```

**Physical Backups — pg_basebackup**
```bash
# Full cluster backup (streaming protocol)
pg_basebackup \
  --host=primary.db.internal \
  --username=replication_user \
  --pgdata=/backups/base/$(date +%Y%m%d) \
  --format=tar \
  --gzip \
  --checkpoint=fast \
  --wal-method=stream \       # include WAL generated during backup
  --progress \
  --verbose
```

**WAL Archiving + PITR**

Step 1: Configure WAL archiving on the primary
```ini
# postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'aws s3 cp %p s3://my-wal-archive/%f'
# %p = full path to WAL file, %f = filename only
```

Step 2: Take a base backup periodically (e.g., nightly)

Step 3: To restore to a point in time (e.g., just before an accidental DELETE at 14:32:00):
```bash
# 1. Stop the target PostgreSQL instance
# 2. Restore the base backup
tar -xzf /backups/base/20260702.tar.gz -C /var/lib/postgresql/data

# 3. Create recovery configuration
cat > /var/lib/postgresql/data/recovery.signal  # empty file signals recovery mode

# postgresql.conf (or recovery.conf in PG < 12)
restore_command = 'aws s3 cp s3://my-wal-archive/%f %p'
recovery_target_time = '2026-07-02 14:31:59'
recovery_target_action = 'promote'  # promote to primary after reaching target

# 4. Start PostgreSQL — it replays WAL up to the target time
# 5. Verify data, then promote
```

**pgBackRest — Enterprise Backup Solution**
pgBackRest addresses limitations of raw pg_dump/pg_basebackup:
- **Incremental backups:** Only changed blocks since last full backup (WAL-based delta)
- **Parallel backup/restore:** Multi-threaded for speed
- **Compression and encryption:** Built-in AES-256 encryption
- **S3/GCS/Azure integration:** Direct cloud storage
- **Retention policies:** Automatically expire old backups

```ini
# /etc/pgbackrest/pgbackrest.conf
[global]
repo1-path=/var/lib/pgbackrest
repo1-cipher-type=aes-256-cbc
repo1-cipher-pass=secretpassphrase
repo1-s3-bucket=my-pg-backups
repo1-s3-region=us-east-1
repo1-type=s3
process-max=4

[payments-db]
pg1-path=/var/lib/postgresql/data
pg1-host=primary.db.internal
```

```bash
# Take a full backup
pgbackrest --stanza=payments-db backup --type=full

# Incremental backup (default after first full)
pgbackrest --stanza=payments-db backup

# PITR restore
pgbackrest --stanza=payments-db restore \
  --target="2026-07-02 14:31:59" \
  --target-action=promote
```

**Backup Testing — Restore Drills**
A backup that has never been tested is not a backup. Best practices:
- **Weekly restore drills:** Restore latest backup to a staging environment; verify row counts, spot-check data
- **Automated verification:** After every backup, run `pgbackrest verify` to check archive integrity
- **RTO testing:** Time the full restore process; if it exceeds your RTO SLA, invest in faster restore (parallel restore, incremental backups, read replicas)
- **Chaos engineering:** Simulate disk failure, corrupted WAL segment, accidental `DROP TABLE`

**Comparison Table**

| Aspect | pg_dump (Logical) | pg_basebackup (Physical) | pgBackRest |
|---|---|---|---|
| Speed (500GB DB) | Hours | 30–60 min | 15–30 min (incremental) |
| PITR support | No | Yes (with WAL) | Yes (native) |
| Cross-version restore | Yes | No | No |
| Encryption | External | External | Built-in |
| Incremental | No | No | Yes |
| Recommended for | Dev/schema, small DBs | Production base | Production enterprise |

**Real-World Example:**
A FinTech firm suffered an accidental `DELETE FROM accounts WHERE status = 'inactive'` that also deleted 50,000 active accounts (bad WHERE clause). With WAL archiving enabled and pgBackRest, they identified the timestamp from application logs (14:47:23), restored to 14:47:20 on a parallel instance, exported the deleted rows to CSV, and re-inserted them into production. Total data recovery time: 22 minutes. Without WAL archiving, the RPO would have been 24 hours (daily pg_dump).

**Follow-up Questions:**
1. How does `pg_basebackup --wal-method=stream` differ from `--wal-method=fetch`?
2. What happens if a WAL segment is missing from the archive during PITR — can you still recover?
3. How would you test that your backup encryption keys are correct without waiting for a disaster?

**Common Mistakes:**
- Storing backups on the same disk/server as the database
- Never testing restores — discovering backup corruption during an incident
- Not monitoring `archive_status` — failed archive commands silently leave WAL files piling up locally until disk fills
- Forgetting that `pg_dump` does not capture roles/tablespaces — use `pg_dumpall --globals-only` for those

**Interview Traps:**
- "pg_dump supports PITR" — it does not; pg_dump is a point-in-time snapshot with no WAL continuity
- Assuming `COPY` in pg_dump is transactionally consistent — it is (pg_dump opens a repeatable-read transaction), but many candidates don't know this

**Quick Revision:** Physical backups + WAL archiving = PITR (restore to any second); pgBackRest adds incremental backups, encryption, and S3 support; always schedule automated restore drills to validate backups.

---

### Topic 13: Multi-Tenancy Patterns

**Difficulty:** Hard | **Frequency:** High | **Companies:** Salesforce, Twilio, HubSpot, Atlassian, SaaS startups

**Q:** What are the main multi-tenancy database patterns, and how do you choose between them?

**Short Answer:**
Multi-tenancy patterns range from fully shared (one table with a `tenant_id` column) to fully isolated (one database per tenant), with two hybrid approaches in between. The choice involves trade-offs between operational complexity, data isolation, performance isolation, and cost. PostgreSQL Row-Level Security (RLS) is a critical tool for enforcing isolation in shared-schema approaches.

**Deep Explanation:**

**Pattern 1: Shared Table (tenant_id column)**
All tenants share the same tables. A `tenant_id` column discriminates rows.

```sql
-- Schema
CREATE TABLE orders (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   UUID NOT NULL,
    amount      NUMERIC(15,2),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orders_tenant ON orders(tenant_id, created_at DESC);

-- Application MUST always filter by tenant_id
SELECT * FROM orders WHERE tenant_id = $1 AND created_at > $2;
```

Risk: A missing `WHERE tenant_id = ?` clause leaks all tenants' data. Mitigation: enforce at ORM layer, or use RLS.

```sql
-- Row-Level Security to prevent cross-tenant leakage
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON orders
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

-- Application sets tenant context at connection start
SET app.current_tenant_id = '123e4567-e89b-12d3-a456-426614174000';
-- Now ALL queries on orders are automatically filtered — even accidental SELECTs
```

**Pattern 2: Shared Schema with RLS (PostgreSQL native)**
Same database, same schema, but RLS enforces isolation. More sophisticated than Pattern 1 because isolation is guaranteed by the database, not application logic.

```sql
-- Using app.current_tenant_id set per request in pgBouncer or app
-- Policy applies to all roles except superuser (FORCE option)
CREATE POLICY tenant_isolation ON orders
    AS RESTRICTIVE
    USING (tenant_id = current_setting('app.current_tenant_id', true)::UUID)
    WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::UUID);

-- Spring Boot integration: set tenant at connection borrow time
@Bean
public DataSource dataSource() {
    HikariDataSource ds = new HikariDataSource(hikariConfig);
    return new TenantAwareDataSource(ds); // wraps to SET app.current_tenant_id on borrow
}
```

**Pattern 3: Separate Schema Per Tenant**
Each tenant gets their own PostgreSQL schema within one database. Application connects with `search_path = tenant_xyz`.

```sql
-- Create tenant schema
CREATE SCHEMA tenant_abc;
CREATE TABLE tenant_abc.orders (LIKE public.orders INCLUDING ALL);

-- Flyway/Liquibase migration must run per schema
-- Spring datasource switches search_path on each connection
SET search_path = tenant_abc;
SELECT * FROM orders;  -- resolves to tenant_abc.orders
```

**Pattern 4: Separate Database Per Tenant**
Each tenant has their own PostgreSQL instance or database cluster.

```java
// Dynamic datasource routing in Spring
@Component
public class TenantRoutingDataSource extends AbstractRoutingDataSource {
    @Override
    protected Object determineCurrentLookupKey() {
        return TenantContext.getCurrentTenant(); // ThreadLocal
    }
}
```

**Comparison Table**

| Dimension | Shared Table | Shared Schema + RLS | Separate Schema | Separate DB |
|---|---|---|---|---|
| Isolation level | Logical (app) | Logical (DB-enforced) | Schema-level | Full |
| Noisy neighbor risk | High | High | Medium | None |
| Operational complexity | Low | Low-Medium | Medium | High |
| Migration complexity | Low | Low | Medium (per-schema) | High (per-DB) |
| Tenants supported | Millions | Millions | ~1,000 | ~100 (managed) |
| Custom schema per tenant | No | No | Yes | Yes |
| Compliance isolation (GDPR) | Hard | Medium | Medium | Easy |
| Cost | Lowest | Lowest | Medium | Highest |
| On-boarding new tenant | Instant | Instant | CREATE SCHEMA + migrate | Provision cluster |

**Hybrid Approaches**
Many SaaS companies use a tiered model:
- Free/Starter tier: shared table with RLS (millions of tenants, low cost)
- Business tier: separate schema (hundreds of tenants, some isolation)
- Enterprise tier: separate database or cluster (full isolation, custom SLA)

**Real-World Example:**
Atlassian's JIRA initially used shared tables. As enterprise customers demanded data residency (data must stay in EU), they evolved to separate databases per large enterprise tenant while keeping SMB customers on shared infrastructure. The schema-per-tenant approach for mid-tier customers allows running per-tenant Flyway migrations without risk of affecting other tenants.

**Follow-up Questions:**
1. How do you handle RLS bypass by superusers, and why does that matter for security audits?
2. How would you implement per-tenant connection pooling with pgBouncer in the separate-schema model?
3. What challenges arise when you need to run cross-tenant analytics queries in a separate-database model?

**Common Mistakes:**
- Not indexing `tenant_id` as the leading column in composite indexes
- Forgetting to include `tenant_id` in `WITH CHECK` (INSERT/UPDATE) not just `USING` (SELECT/DELETE)
- Not testing RLS with `SET ROLE application_user` — superuser bypasses RLS by default

**Interview Traps:**
- "RLS guarantees complete isolation" — superusers bypass RLS unless you use `FORCE ROW LEVEL SECURITY`
- Assuming separate schemas eliminate noisy neighbor problems — they still share I/O, CPU, and connection limits

**Quick Revision:** Four patterns — shared table, shared schema + RLS, separate schema, separate DB — increasing isolation and cost; PostgreSQL RLS is the preferred middle ground for most SaaS at scale.

---

### Topic 14: Database-Level Security

**Difficulty:** Medium-Hard | **Frequency:** Medium-High | **Companies:** FinTech, Healthcare, Government, Stripe, Goldman Sachs

**Q:** How do you implement row-level security, audit logging, and encryption in PostgreSQL for a compliance-sensitive application?

**Short Answer:**
PostgreSQL provides native Row-Level Security (RLS) for data access control, column-level `GRANT` permissions, and the `pgaudit` extension for SOC2/PCI-compliant audit trails. Encryption at rest is handled by the OS/storage layer or TDE-capable forks; encryption in transit uses TLS. Together these layers satisfy most regulatory requirements (PCI-DSS, HIPAA, SOC2 Type II).

**Deep Explanation:**

**Row-Level Security (RLS)**
```sql
-- Enable RLS
ALTER TABLE customer_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_data FORCE ROW LEVEL SECURITY;  -- also applies to table owner

-- Policy: users can only see their own records
CREATE POLICY user_self_access ON customer_data
    FOR ALL
    TO application_role
    USING (user_id = current_user_id())   -- current_user_id() = custom function returning auth context
    WITH CHECK (user_id = current_user_id());

-- Policy: admins see everything
CREATE POLICY admin_full_access ON customer_data
    FOR ALL
    TO admin_role
    USING (true);

-- Policy for multi-tenancy: see only your tenant's rows
CREATE POLICY tenant_policy ON customer_data
    USING (tenant_id = current_setting('app.tenant_id')::UUID);
```

**Column-Level Permissions**
```sql
-- Create a restricted view of sensitive table
CREATE ROLE readonly_analyst;
GRANT SELECT (id, created_at, amount, status) ON transactions TO readonly_analyst;
-- Analyst cannot SELECT card_number, ssn, or other PII columns

-- Or use a view to mask sensitive data
CREATE VIEW transactions_masked AS
SELECT 
    id,
    amount,
    status,
    created_at,
    CONCAT('****-****-****-', RIGHT(card_number, 4)) AS card_last4
FROM transactions;

GRANT SELECT ON transactions_masked TO readonly_analyst;
REVOKE ALL ON transactions FROM readonly_analyst;
```

**Audit Logging with pgaudit**
pgaudit provides structured audit logging that satisfies SOC2, PCI-DSS, and HIPAA requirements.

```ini
# postgresql.conf
shared_preload_libraries = 'pgaudit'
pgaudit.log = 'write, ddl'     # log all writes (INSERT/UPDATE/DELETE) and DDL
pgaudit.log_catalog = off       # don't audit system catalog queries (noise)
pgaudit.log_relation = on       # log table name with each statement
pgaudit.log_statement_once = on # log statement text only on first entry
```

```sql
-- Session-level audit for a specific user
ALTER ROLE audited_service SET pgaudit.log = 'all';

-- Object-level audit (audit specific tables)
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Audit all access to the accounts table
SELECT pgaudit.set_object_log(
    'public', 'accounts', 'select, write'
);
```

Sample audit log entry:
```
AUDIT: SESSION,1,1,WRITE,INSERT,TABLE,public.accounts,
"INSERT INTO accounts (id, balance) VALUES (123, 5000.00)",<not logged>
```

**Encryption at Rest**
Options in order of trust boundary:
1. **Storage-level encryption (dm-crypt/LUKS on Linux):** Protects against physical disk theft; PostgreSQL is unaware
2. **Cloud disk encryption (AWS EBS, GCP Persistent Disk):** Transparent; protects against provider-level access
3. **TDE forks (Percona, EDB):** PostgreSQL-level encryption; protects against filesystem access by OS users
4. **Application-level encryption:** Most granular; encrypt specific columns before storing

```java
// Application-level column encryption with AES-256
@Column(name = "ssn_encrypted")
@Convert(converter = EncryptedStringConverter.class)
private String socialSecurityNumber;

// The converter encrypts before INSERT and decrypts on SELECT
// The DB never sees plaintext SSN
```

**Encryption in Transit**
```ini
# postgresql.conf
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'
ssl_ca_file = '/etc/ssl/certs/ca.crt'
ssl_min_protocol_version = 'TLSv1.2'
ssl_ciphers = 'HIGH:!aNULL:!MD5'
```

```
# pg_hba.conf — require SSL for all connections
hostssl  all  all  0.0.0.0/0  scram-sha-256
# 'hostssl' means SSL is mandatory; 'host' allows non-SSL (avoid in prod)
```

**Transparent Data Encryption (TDE)**
TDE encrypts data at the database engine level — data files, WAL files, and temp files are encrypted. The key advantage over OS-level encryption: DBAs cannot read data files directly by gaining OS access. Percona Distribution for PostgreSQL and EDB Postgres Advanced Server both offer TDE. AWS RDS/Aurora provides TDE at the storage level using KMS keys.

```sql
-- On EDB with TDE: verify encryption
SELECT pg_is_in_recovery(), current_setting('tde.enabled');
```

**Secrets Management**
```java
// Never hardcode DB credentials; use Vault or AWS Secrets Manager
@Bean
public DataSource dataSource() {
    String password = vaultTemplate.read("secret/database/payments")
        .getData().get("password").toString();
    HikariConfig config = new HikariConfig();
    config.setPassword(password);
    // Rotate password: Vault dynamic secrets generate short-lived credentials
    return new HikariDataSource(config);
}
```

**Real-World Example:**
A healthcare company processing PHI needed HIPAA compliance. Implementation: (1) pgaudit logging all DML to a separate syslog server (immutable log chain), (2) RLS ensuring clinicians only access their patients' records, (3) column-level permissions so billing analysts see diagnoses but not treatment notes, (4) all PII columns encrypted at application layer before storage, (5) full-disk encryption on RDS using AWS KMS with key rotation every 90 days.

**Follow-up Questions:**
1. How does `FORCE ROW LEVEL SECURITY` differ from regular RLS, and when is it needed?
2. What are the performance implications of application-level column encryption vs storage-level encryption?
3. How would you implement data masking for a non-production environment that mirrors production schema?

**Common Mistakes:**
- Using `hostssl` vs `host` in pg_hba.conf — `host` allows unencrypted connections
- Not setting `FORCE ROW LEVEL SECURITY` — table owners bypass RLS
- Logging audit trails to the same database being audited — an attacker with DB access can delete the audit log
- Not testing RLS bypass scenarios (SET ROLE, superuser access)

**Interview Traps:**
- "Encryption at rest protects against SQL injection" — it does not; that requires application-layer controls
- "pgaudit captures all database activity" — it captures SQL; it does not capture OS-level file access or network sniffing

**Quick Revision:** RLS enforces row-level access control in the database layer; pgaudit provides structured audit logs for compliance; encryption in transit (SSL/TLS) and at rest (storage/TDE) together satisfy most regulatory requirements.

---

### Topic 15: Emerging Patterns in Databases

**Difficulty:** Hard | **Frequency:** Medium (but rising fast) | **Companies:** Google, Cockroach Labs, PlanetScale, Neon, startups, FAANG architecture rounds

**Q:** What is NewSQL, HTAP, and database branching — and when would you choose these over traditional PostgreSQL?

**Short Answer:**
NewSQL databases (CockroachDB, Cloud Spanner) bring distributed ACID transactions with horizontal scalability — solving the scale-out problem that drove companies to NoSQL without sacrificing consistency. HTAP systems handle both transactional and analytical workloads in one engine, eliminating ETL pipelines. Database branching (Neon, PlanetScale) brings Git-like workflows to database schemas, enabling instant copy-on-write clones for testing.

**Deep Explanation:**

**NewSQL: Global ACID at Scale**

**CockroachDB**
- Distributed SQL; compatible with PostgreSQL wire protocol
- Uses Raft consensus for replication; each range (64MB partition) has 3+ replicas
- Serializable isolation (default) using MVCC + distributed timestamps
- Automatic sharding — no manual shard keys needed for most workloads
- Geo-partitioning: pin data to specific regions for data residency compliance

```sql
-- CockroachDB: create a geo-partitioned table (data stays in EU for GDPR)
CREATE TABLE user_profiles (
    user_id     UUID PRIMARY KEY,
    region      STRING NOT NULL,
    email       STRING,
    created_at  TIMESTAMPTZ DEFAULT now()
)
PARTITION BY LIST (region) (
    PARTITION eu VALUES IN ('eu-west-1', 'eu-central-1'),
    PARTITION us VALUES IN ('us-east-1', 'us-west-2')
);

ALTER PARTITION eu OF INDEX user_profiles@primary
    CONFIGURE ZONE USING constraints = '[+region=eu-west-1]';
```

**Google Cloud Spanner**
- Globally distributed, externally consistent (TrueTime API)
- Can achieve serializable isolation across continents — unique in the industry
- Proprietary; not PostgreSQL-compatible (uses ANSI SQL)
- Purpose-built for global financial systems (used by Google's own payments infra)
- Expensive: ~$0.90/node/hour vs Aurora at ~$0.10/hour

**When to choose NewSQL:**
- You need horizontal write scalability beyond what a single PostgreSQL instance + read replicas can provide
- You need multi-region active-active writes (not just reads)
- You cannot tolerate the complexity of application-level sharding

**HTAP: Hybrid Transactional/Analytical Processing**

Traditional architecture separates OLTP (PostgreSQL) and OLAP (Redshift/BigQuery) with ETL. HTAP eliminates that boundary.

**TiDB** (PingCAP)
- MySQL-compatible HTAP database
- TiKV (row store for OLTP) + TiFlash (columnar store for OLAP) in one system
- Automatically replicates rows from TiKV to TiFlash; queries are routed to the appropriate engine
- Analytics queries run against near-real-time data without ETL lag

```sql
-- TiDB: force a query to use the columnar (TiFlash) engine
ALTER TABLE orders SET TIFLASH REPLICA 1;  -- enable columnar replica

SELECT 
    date_trunc('month', created_at) AS month,
    SUM(amount) AS revenue
FROM orders
WHERE created_at > NOW() - INTERVAL '1 year'
/*+ READ_FROM_STORAGE(TIFLASH[orders]) */  -- hint to use columnar engine
GROUP BY 1;
```

**Aurora DSQL / Redshift Spectrum as HTAP-adjacent**
Aurora stores data in S3 (Aurora's storage layer), and Redshift Spectrum can query it directly. Not true HTAP but enables analytics on near-real-time OLTP data.

**Database Branching — Git for Databases**

**Neon (Serverless PostgreSQL)**
- Built on a custom storage engine that separates compute from storage
- Copy-on-write branching: creating a branch from production is instant and free (no data copy — shares storage pages)
- Branches diverge as writes occur (only modified pages are duplicated)

```bash
# Neon CLI: create a branch from production for a PR
neon branches create \
  --name pr-42-new-payment-flow \
  --parent main

# Get connection string for this branch
neon connection-string pr-42-new-payment-flow
# Returns: postgresql://user:pass@ep-cool-fog-123.us-east-2.aws.neon.tech/payments

# Run migration on branch (isolated from production)
flyway -url="jdbc:postgresql://ep-cool-fog-123..." migrate

# After PR merge, delete branch
neon branches delete pr-42-new-payment-flow
```

**PlanetScale (MySQL, Vitess-based)**
- Database branching with schema change management
- Non-blocking schema changes via Vitess's online DDL
- Deploy requests: propose a schema change, review diff, deploy like a PR

**Serverless Databases**

**Aurora Serverless v2**
- Scales ACUs (Aurora Capacity Units) in ~0.5 ACU increments in seconds
- Minimum ~0.5 ACUs (warm but near-idle cost)
- Maximum configurable; scales to hundreds of ACUs under load
- Same Aurora storage layer; compatible with Aurora Serverless v1 and provisioned

```yaml
# CloudFormation: Aurora Serverless v2 cluster
Type: AWS::RDS::DBCluster
Properties:
  Engine: aurora-postgresql
  EngineVersion: "15.4"
  ServerlessV2ScalingConfiguration:
    MinCapacity: 0.5
    MaxCapacity: 32.0
```

**Trade-offs of Serverless Databases**

| Aspect | Aurora Serverless v2 | Neon | PlanetScale |
|---|---|---|---|
| Cold start penalty | Seconds (scale from min) | Sub-second (branching) | N/A (always on) |
| Pricing model | Per-ACU-second | Per compute-second + storage | Per row reads/writes |
| Best for | Unpredictable workloads | Dev/test branching | MySQL at scale |
| PITR support | Yes (native) | Yes (branching = PITR) | Limited |

**Emerging Pattern: Database Mesh**
The concept of applying service mesh principles (sidecar proxies, traffic management, observability) to database access. PgCat (Rust-based PostgreSQL proxy) and Envoy-based DB proxies are early implementations.

**Real-World Example:**
A FinTech startup used Neon to solve the "integration test environment" problem. Previously, each developer needed their own PostgreSQL instance seeded with test data (~30 minutes to provision). With Neon branching, each PR automatically gets a branch from the shared staging database (instant), runs migrations on the branch, runs integration tests, then deletes the branch. CI time for DB setup dropped from 30 minutes to 3 seconds.

**Follow-up Questions:**
1. What are the consistency guarantees of CockroachDB vs Cloud Spanner — specifically around TrueTime?
2. How does HTAP handle the "thundering herd" problem where a heavy analytics query impacts OLTP performance?
3. What are the operational challenges of migrating from PostgreSQL to CockroachDB despite its PostgreSQL compatibility?

**Common Mistakes:**
- Assuming NewSQL has the same performance profile as single-node PostgreSQL — distributed transactions have cross-node latency overhead
- Using CockroachDB for workloads that don't actually need global distribution — unnecessary complexity
- Treating Neon branches as production-worthy without understanding that branched data diverges from main

**Interview Traps:**
- "CockroachDB is just distributed PostgreSQL" — it has significant behavioral differences (e.g., no stored procedures, different DDL locking, schema change behavior)
- "Serverless databases are always cheaper" — for steady-load workloads, provisioned instances are almost always cheaper

**Quick Revision:** NewSQL (CockroachDB, Spanner) = distributed ACID at global scale; HTAP (TiDB) = one engine for both OLTP and OLAP; database branching (Neon) = instant copy-on-write clones for development workflows.

---

## Chapter 18 Master Cheat Sheet

### Table 1: Partitioning vs Sharding

| Dimension | Table Partitioning | Database Sharding |
|---|---|---|
| Scope | Within one PostgreSQL instance | Across multiple instances |
| Transparency | Fully transparent to queries | Requires shard routing logic |
| Cross-partition joins | Native SQL JOIN (optimizer-managed) | Application-level or scatter-gather |
| Max data size | Limited by single machine | Unlimited horizontal scale |
| Complexity | Low (declarative DDL) | High (application + ops) |
| Transactions | Full ACID | Distributed transactions (complex) |
| Implementation | `PARTITION BY RANGE/LIST/HASH` | Vitess, Citus, custom app logic |
| Foreign keys | Limited across partitions | Not supported across shards |
| Partition pruning | Automatic (query planner) | Manual (shard key in every query) |
| Best for | Time-series, archival, large tables | Write-scale beyond single node |
| Failure isolation | None (same instance) | Shard failure isolates to that shard |
| Rebalancing | Fast (DDL operations) | Expensive (data movement across nodes) |

---

### Table 2: Connection Pooling Options

| Feature | HikariCP | pgBouncer | RDS Proxy | ProxySQL |
|---|---|---|---|---|
| Layer | Application (JVM) | Infrastructure | Managed AWS | Infrastructure |
| Protocol | JDBC | PostgreSQL wire | PostgreSQL/MySQL | MySQL |
| Pooling modes | Application-managed | Session/Transaction/Statement | Transaction-like | Session/Transaction |
| Max multiplexing | 1:1 (app to DB) | Many:few | Many:few | Many:few |
| Failover handling | Via JDBC URL / app logic | Manual reconfigure | Automatic (30s) | Via Orchestrator |
| IAM auth | Via custom datasource | No | Yes (native) | No |
| Prepared statements | Yes | Breaks in tx mode | Limited | Yes |
| Monitoring | JMX/Micrometer metrics | Admin console | CloudWatch | Admin UI + stats tables |
| Best pool size formula | CPU cores × 2 + disk count | Backend: 5–20; frontend: unlimited | Set by RDS instance class | Similar to pgBouncer |
| Typical use | Always (base layer) | PostgreSQL at scale | PostgreSQL on AWS | MySQL at scale |
| Open source | Yes | Yes | No (AWS managed) | Yes |

---

### Table 3: Replication Topology Trade-offs

| Topology | Consistency | Write Scale | Read Scale | HA | Latency | Complexity |
|---|---|---|---|---|---|---|
| Single primary + streaming replicas | Strong (sync) or eventual (async) | None (one writer) | High (N readers) | Manual failover | Low | Low |
| Synchronous replication (1 standby) | Strong (zero data loss) | None | Medium | Automatic (Patroni) | Higher (waits for standby ack) | Medium |
| Logical replication | Eventual | Single writer per replica | High | No (logical only) | Variable | Medium |
| Multi-primary (BDR/Citus) | Eventual / conflict-resolved | Medium (avoid conflicts) | High | Yes | Medium | High |
| CockroachDB (Raft) | Serializable | High (distributed) | High | Yes | Higher (network RTT) | High |
| Aurora Global Database | Strong (< 1s replica lag) | One region primary | High | Cross-region failover < 1min | Regional | Low (managed) |
| Read replica fan-out | Eventual | None | Very high | No (reads only) | Low | Low |

---

### Table 4: Zero-Downtime Migration Checklist

**Pre-Migration**
- [ ] Profile table size, row count, write rate (rows/s)
- [ ] Identify peak traffic windows; schedule for off-peak
- [ ] Take a point-in-time backup / snapshot
- [ ] Test migration on a production-sized clone (restore drill environment)
- [ ] Verify the change is backward-compatible with N-1 app version
- [ ] Estimate duration (gh-ost dry-run, pg_repack dry-run)
- [ ] Set up throttle limits to protect production queries

**During Migration**
- [ ] Monitor replica lag during gh-ost / pg_repack run
- [ ] Monitor `pg_stat_activity` for lock waits
- [ ] Keep migration step idempotent (can be retried on failure)
- [ ] Use `CREATE INDEX CONCURRENTLY` for new indexes
- [ ] Use `NOT VALID` + `VALIDATE CONSTRAINT` for FK additions
- [ ] Backfill new columns in small batches (1K–10K rows) with sleep between batches

**Deploy Sequence (Expand-Contract)**
- [ ] Phase 1: Add new column/index (backward-compatible) — deploy DB change
- [ ] Phase 2: Deploy app code reading NEW if non-null, else OLD; writing to BOTH
- [ ] Phase 3: Backfill new column from old
- [ ] Phase 4: Deploy app code reading only NEW column
- [ ] Phase 5: Remove old column (after verifying zero reads for 1+ week)

**Post-Migration**
- [ ] `ANALYZE <table>` to update statistics
- [ ] Verify index usage with `pg_stat_user_indexes`
- [ ] Confirm old column/index no longer appears in `pg_stat_statements`
- [ ] Update runbook + data dictionary
- [ ] Archive migration script with timestamp in version control

---

### Table 5: Multi-Tenancy Pattern Comparison

| Dimension | Shared Table (tenant_id) | Shared Schema + RLS | Separate Schema | Separate Database |
|---|---|---|---|---|
| Data isolation level | Application-enforced | DB-enforced (RLS) | Schema isolation | Full DB isolation |
| Isolation guarantee | Weak (app bugs leak) | Strong (DB enforced) | Strong | Strongest |
| Max tenant count | Millions | Millions | ~1,000 (schema limit) | ~100 (ops limit) |
| Noisy neighbor (CPU/IO) | High risk | High risk | Medium risk | Isolated |
| Noisy neighbor (connections) | High risk | High risk | High risk | Isolated |
| New tenant onboarding | Instant (INSERT) | Instant | CREATE SCHEMA + migrate | Provision instance |
| Migration complexity | Low (one migration) | Low | Medium (per-schema scripts) | High (per-instance) |
| Custom schema per tenant | No | No | Yes | Yes |
| Tenant-level PITR | No | No | No | Yes |
| GDPR right to deletion | Bulk DELETE with tenant_id | Same | DROP SCHEMA CASCADE | DROP DATABASE |
| Data residency support | No | No | No | Yes (region per DB) |
| Cross-tenant reporting | Easy (no joins needed) | Easy | Hard (cross-schema) | Very hard |
| Cost per tenant | ~$0 | ~$0 | ~$0 (shared compute) | ~$50–500/month |
| Typical adopter | Early-stage SaaS | Mid-scale SaaS | Mid-market SaaS | Enterprise SaaS |
| Example companies | Small SaaS startups | GitLab, Basecamp | Shopify (shop schema) | Salesforce (top tier) |

---

*End of Chapter 18, Part B*
*Next: Chapter 19 — Distributed Systems & Consensus Algorithms*



