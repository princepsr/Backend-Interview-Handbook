# Volume 4: Databases & Performance
# Chapter 17: Distributed Databases & Sharding

---

# Chapter 17: Distributed Databases & Sharding — Part A

> **Target Audience:** SDE2 / Senior Engineers interviewing at FAANG+
> **Focus Companies:** Amazon, Google, Meta, Netflix, Uber, Stripe
> **Prerequisites:** SQL fundamentals, basic networking, CAP theorem

---

## Overview

Distributed databases and sharding sit at the core of every large-scale system design interview. Amazon tests this heavily for their distributed systems teams; Google expects deep knowledge of consistency models and consensus. This chapter covers the eight foundational topics you must own before walking into any senior backend interview.

---

### Topic 1: Database Sharding
**Difficulty:** Hard | **Frequency:** Very High | **Companies:** Amazon, Meta, Uber, Stripe, LinkedIn

**Q:** How would you shard a large relational database, and what are the trade-offs between range-based, hash-based, and directory-based sharding?

**Short Answer:**
Sharding is horizontal partitioning — splitting rows of a table across multiple independent database instances (shards). The shard key determines which shard a row lives on. The choice between range, hash, and directory-based strategies involves trade-offs among query flexibility, data distribution, and operational complexity.

**Deep Explanation:**

**Why shard at all?**
A single MySQL or PostgreSQL instance tops out around 100k–500k QPS (with heavy caching). When your write throughput or dataset size exceeds what one machine can handle, you shard. Vertical scaling (bigger machines) has diminishing returns and a hard ceiling.

**Shard Key Selection — the most critical decision:**
- The shard key must distribute writes evenly (avoid hot shards)
- It should enable most queries to hit a single shard (avoid scatter-gather)
- It should rarely need to change (resharding is painful)
- Poor examples: `user_country` (US shard gets 40% of traffic), `created_at` (monotonically increasing keys all land on the latest shard)
- Good examples: `user_id` (hashed), composite key (`tenant_id + entity_id`)

**Range-Based Sharding:**
Rows are partitioned by contiguous value ranges of the shard key (e.g., user IDs 1–1M on shard 1, 1M–2M on shard 2).
- Pros: Range queries are efficient (all Jan 2024 orders are on shard 3); easy to reason about data locality
- Cons: Hot spots when data is not uniformly distributed (new users all write to the last shard); resharding requires splitting ranges and moving data

**Hash-Based Sharding:**
Apply a hash function to the shard key modulo N shards: `shard = hash(user_id) % N`
- Pros: Near-uniform distribution; simple to implement
- Cons: Range queries become scatter-gather (every shard must be queried); resharding requires remapping ~100% of keys when N changes (`hash(id) % 5` vs `hash(id) % 6` produces completely different shard assignments)

**Directory-Based Sharding (Lookup Service):**
A separate metadata service (the shard directory) stores the mapping `shard_key → shard_id`. Each write first consults the directory.
- Pros: Flexible; can move individual keys between shards without changing logic; supports heterogeneous shard sizes
- Cons: The directory is a single point of failure and a performance bottleneck; adds network round-trip; the directory itself must be highly available and consistent

**The Resharding Problem:**
When you add shards (scale out), you need to move data from overloaded shards to new ones. With naive hash sharding (`% N`), adding one shard invalidates nearly every key mapping and requires moving ~(N-1)/N of all data. This causes prolonged double-write periods and risk. Consistent hashing (Topic 2) solves this.

**Cross-Shard Queries:**
JOINs across shards require application-level scatter-gather: fan out the query to all shards, collect results, merge in memory. This is expensive. Good shard key design minimizes cross-shard queries by co-locating related data (e.g., all data for a tenant on the same shard).

**Cross-Shard Transactions:**
ACID transactions spanning multiple shards require distributed transactions (2PC — two-phase commit). 2PC is slow and blocks on coordinator failure. Most large-scale systems avoid cross-shard transactions by design (denormalization, eventual consistency, or saga patterns).

**Real-World Example:**
Instagram's user table: sharded by `user_id` using consistent hashing. Each shard is a PostgreSQL primary + replica set. Media metadata is co-located with the user on the same shard to avoid cross-shard lookups. The follower relationship table is sharded separately by `follower_id` for write throughput, accepting that "get all followers of user X" requires a cross-shard query on the celebrity shard problem.

**Code Example:**
```java
// Simple hash-based shard router
public class ShardRouter {
    private final List<DataSource> shards;
    private final int numShards;

    public ShardRouter(List<DataSource> shards) {
        this.shards = shards;
        this.numShards = shards.size();
    }

    // PROBLEM: adding a shard remaps ~(N-1)/N keys
    public DataSource getShardNaive(long userId) {
        int shardIndex = (int) (Math.abs(userId) % numShards);
        return shards.get(shardIndex);
    }

    // Directory-based routing — flexible but needs a metadata store
    private final Map<Long, Integer> directory = new ConcurrentHashMap<>();

    public DataSource getShardFromDirectory(long userId) {
        Integer shardIndex = directory.get(userId);
        if (shardIndex == null) {
            // New user: assign to least loaded shard
            shardIndex = pickLeastLoadedShard();
            directory.put(userId, shardIndex);
        }
        return shards.get(shardIndex);
    }

    // Range-based routing
    private final NavigableMap<Long, Integer> rangeMap = new TreeMap<>();
    // rangeMap: {0 -> shard0, 1_000_000 -> shard1, 2_000_000 -> shard2}

    public DataSource getShardByRange(long userId) {
        Map.Entry<Long, Integer> entry = rangeMap.floorEntry(userId);
        return shards.get(entry.getValue());
    }
}

// Vitess-style shard key annotation (pseudo-code for documentation)
// @ShardKey(column = "user_id", strategy = CONSISTENT_HASH)
// CREATE TABLE orders (user_id BIGINT, order_id BIGINT, ...);
```

**Follow-up Questions:**
1. How do you handle a "celebrity" or hot-key problem where one shard receives disproportionate write traffic?
2. If you need to rebalance shards online with zero downtime, what is your strategy?
3. How does Vitess handle sharding for MySQL, and what abstractions does it provide?

**Common Mistakes:**
- Choosing a low-cardinality shard key (e.g., `status`, `country`) that creates a small number of distinct shards and limits scalability
- Forgetting that the shard key becomes immutable in practice — updating `user_id` would require moving data across shards
- Ignoring the operational burden: backup, schema migrations, and monitoring must now run across N shards

**Interview Traps:**
- Interviewers often ask "just use a UUID as shard key" — the trap is that random UUIDs destroy B-tree locality (write amplification), hurt range queries, and make cross-entity co-location impossible
- "Can you do transactions across shards?" — Yes, via 2PC, but the correct answer is to explain why you'd redesign to avoid it at scale

**Quick Revision:** Sharding splits rows across database instances using a shard key; hash sharding distributes evenly but breaks range queries and makes resharding costly — consistent hashing and directory-based approaches mitigate this.

---

### Topic 2: Consistent Hashing
**Difficulty:** Hard | **Frequency:** Very High | **Companies:** Amazon (DynamoDB), Netflix (Cassandra), Discord, Stripe

**Q:** What is consistent hashing, and how does it solve the resharding problem? Explain virtual nodes and their purpose.

**Short Answer:**
Consistent hashing maps both data keys and server nodes onto a logical ring using the same hash function. When a node is added or removed, only keys in that node's segment of the ring need to move — on average ~K/N keys (K = total keys, N = nodes). Virtual nodes improve load balance by assigning each physical server multiple positions on the ring.

**Deep Explanation:**

![Consistent hashing ring](https://upload.wikimedia.org/wikipedia/commons/7/71/Consistent_Hashing_Sample_Illustration.png)
*Consistent hashing — nodes and keys are mapped to the same ring; each key is owned by the next clockwise node, minimizing remapping when nodes join/leave*

**The Classic Resharding Problem:**
With `shard = hash(key) % N`, adding one server changes N to N+1. Almost every key maps to a different shard. You must move ~(N-1)/N of all data — a catastrophic migration.

**The Ring Abstraction:**
Hash both servers and keys to a number in range [0, 2^32). Arrange these numbers on a circular ring. Each key is served by the first server encountered when walking clockwise from the key's position.

```
           Server A (hash=10)
              *
    Key K1        Key K2
    (hash=8)      (hash=15)
              *
           Server B (hash=20)
```
K1 → Server A (first server clockwise from 8 is A at 10)
K2 → Server B (first server clockwise from 15 is B at 20)

**Adding/Removing Nodes:**
- Add Server C at position 12: only keys between 10 and 12 (previously owned by B) now move to C
- Remove Server A: only its keys (between previous server and A's position) move to the next server clockwise
- Result: only ~K/N keys move on average, regardless of total cluster size

**Virtual Nodes (vnodes):**
Problem with basic consistent hashing: with few physical servers, they land at sparse, uneven positions on the ring → load imbalance. Also, when a server goes down, all its load falls on a single neighbor.

Solution: each physical server is assigned V virtual nodes (V=150 in Cassandra by default). Each vnode has its own position on the ring. Physical server S1 might occupy positions {17, 83, 201, 445, ...} spread around the ring.

Benefits:
1. **Load balance**: With 150 vnodes per server, the probabilistic spread gives near-uniform key distribution
2. **Fault tolerance**: When S1 fails, its ~150 segments are distributed across ~150 different neighbors — no single neighbor gets all the load
3. **Heterogeneous hardware**: Give powerful servers more vnodes to carry more data proportionally

**Implementation in Cassandra/DynamoDB:**
- Cassandra: `num_tokens = 256` (vnodes per node). The token ring is stored in the `system.tokens` table, gossipped between nodes
- DynamoDB: uses consistent hashing internally but abstracts it completely behind the SDK; the partition key IS the consistent hash key
- Amazon's paper (Dynamo, 2007) introduced vnodes to production systems

**Lookup Complexity:**
- Naive: O(N) linear scan of all node positions
- Production: sorted array of token positions + binary search = O(log N)
- Java `TreeMap` / `NavigableMap` is the standard implementation vehicle

**Real-World Example:**
Discord serves billions of messages. Their message store uses Cassandra with consistent hashing. When they add capacity (new Cassandra node), only the new node's portion of the ring migrates — typically a few percent of data. A full cluster expansion from 20→21 nodes means roughly 1/21 of data moves rather than remapping everything.

**Code Example:**
```java
import java.security.MessageDigest;
import java.util.SortedMap;
import java.util.TreeMap;

public class ConsistentHashRing {
    private final SortedMap<Long, String> ring = new TreeMap<>();
    private final int virtualNodes;

    public ConsistentHashRing(int virtualNodes) {
        this.virtualNodes = virtualNodes;
    }

    public void addServer(String server) {
        for (int i = 0; i < virtualNodes; i++) {
            long hash = hash(server + "#vnode" + i);
            ring.put(hash, server);
        }
    }

    public void removeServer(String server) {
        for (int i = 0; i < virtualNodes; i++) {
            long hash = hash(server + "#vnode" + i);
            ring.remove(hash);
        }
    }

    public String getServer(String key) {
        if (ring.isEmpty()) throw new IllegalStateException("No servers");
        long hash = hash(key);
        // Find first server clockwise from key's hash
        SortedMap<Long, String> tail = ring.tailMap(hash);
        Long serverHash = tail.isEmpty() ? ring.firstKey() : tail.firstKey();
        return ring.get(serverHash);
    }

    // Replicated writes: get next N unique servers clockwise
    public List<String> getReplicaServers(String key, int replicationFactor) {
        List<String> replicas = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        long hash = hash(key);
        // Walk clockwise, collect distinct physical servers
        SortedMap<Long, String> tail = ring.tailMap(hash);
        for (Map.Entry<Long, String> e : Iterables.concat(tail, ring).entrySet()) {
            if (seen.add(e.getValue())) {
                replicas.add(e.getValue());
                if (replicas.size() == replicationFactor) break;
            }
        }
        return replicas;
    }

    private long hash(String key) {
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] digest = md.digest(key.getBytes());
            // Use first 8 bytes as long
            long h = 0;
            for (int i = 0; i < 8; i++) h = (h << 8) | (digest[i] & 0xFF);
            return h;
        } catch (Exception e) { throw new RuntimeException(e); }
    }
}

// Usage:
// ConsistentHashRing ring = new ConsistentHashRing(150);
// ring.addServer("redis-1:6379");
// ring.addServer("redis-2:6379");
// String server = ring.getServer("user:12345"); // → "redis-1:6379"
```

**Follow-up Questions:**
1. How does replication factor interact with consistent hashing? How do you select replica nodes?
2. What happens during a node addition if we want zero-downtime — how do we stream data to the new node while serving reads?
3. MD5 is used above — in production, would you use MD5? What are the alternatives and why?

**Common Mistakes:**
- Forgetting that without virtual nodes, a single node failure dumps all its load onto exactly one neighbor — a thundering herd
- Using `String.hashCode()` (non-deterministic across JVM restarts since Java 7) as the hash function
- Not handling the ring wrap-around: if a key hashes to a value larger than all servers, it must wrap to the first server (the `ring.firstKey()` fallback)

**Interview Traps:**
- "Can you just use modulo hashing with a prime number?" — No, the modulo issue is about N changing, not about the modulus value
- Interviewer may ask you to implement getReplicaServers — the key insight is collecting distinct **physical** servers, not just N consecutive vnodes (multiple vnodes of the same server must be skipped)

**Quick Revision:** Consistent hashing maps nodes and keys to a ring; adding/removing a node moves only ~1/N of keys; virtual nodes (150+ per server) ensure uniform distribution and spread failure impact across many neighbors.

---

### Topic 3: Replication Strategies
**Difficulty:** Hard | **Frequency:** Very High | **Companies:** Amazon, Google, MongoDB Atlas, CockroachDB

**Q:** Compare single-leader, multi-leader, and leaderless replication. When would you choose each, and what consistency guarantees does each provide?

**Short Answer:**
Single-leader replication serializes all writes through one node for strong consistency but creates a write bottleneck and failover complexity. Multi-leader enables writes at multiple datacenters but requires conflict resolution. Leaderless (Dynamo-style) uses quorum writes/reads (R+W>N) for tunable consistency with no single point of failure.

**Deep Explanation:**

**Single-Leader (Primary-Replica) Replication:**
One primary accepts all writes; replicas receive changes via replication log (binlog in MySQL, WAL in PostgreSQL).

*Synchronous vs. Asynchronous:*
- **Synchronous**: Primary waits for at least one replica to acknowledge before confirming write. Guarantees no data loss on primary failure but increases write latency
- **Semi-synchronous**: At least one replica is synchronous; others async. MySQL default since 5.7
- **Asynchronous**: Primary confirms immediately; replicas lag. High write throughput, but replica lag causes stale reads and potential data loss on failover

*Failover:*
When primary fails, a replica must be promoted. Challenges:
1. **Replica lag**: New primary may not have all writes → acknowledged writes can be lost (split brain if old primary recovers)
2. **Epoch/generation numbers**: Raft/Paxos-based systems use fencing tokens to prevent old leader from writing after being demoted

**Multi-Leader Replication:**
Multiple nodes accept writes simultaneously. Common in multi-datacenter deployments (each DC has its own leader; replication is async between DCs).

Use cases: offline-capable apps (CouchDB), multi-datacenter active-active (Cassandra's multi-DC mode)

*Conflict Resolution:* When two leaders receive conflicting writes to the same row:
- **Last-write-wins (LWW)**: Highest timestamp wins. Simple but loses data; vulnerable to clock skew
- **Custom conflict handlers**: Application-provided merge logic (CouchDB)
- **CRDTs**: Conflict-free Replicated Data Types that auto-merge (Topic 4)

**Leaderless Replication (Dynamo-style):**
Any replica can accept any write. Used in DynamoDB, Cassandra, Riak, Voldemort.

*Quorum reads and writes:*
- N = total replicas for a key
- W = replicas that must acknowledge a write
- R = replicas that must respond to a read
- Condition for strong consistency: **R + W > N**

Example: N=3, W=2, R=2 → at least one replica in any read set must have seen the latest write.

Common configurations:
| Config | R | W | Trade-off |
|--------|---|---|-----------|
| High availability | 1 | 1 | Fastest but inconsistent |
| Read-heavy | 1 | 3 | All writes hit all replicas; reads from any one |
| Balanced | 2 | 2 | Standard; tolerates 1 node failure |
| Consistency | 3 | 3 | All nodes must agree; no tolerance |

*Sloppy quorum:* During network partition, writes can be accepted by nodes outside the key's home set (hinted handoff). Improves availability at the cost of durability guarantees. W + R > N no longer holds strictly.

*Version vectors / conflict detection:* Leaderless systems use vector clocks or version vectors to detect conflicting concurrent writes. The client or system then resolves the conflict.

**Real-World Example:**
Amazon S3 uses leaderless replication internally. When you PUT an object with `x-amz-server-side-encryption`, the write is confirmed after W replicas acknowledge. A subsequent GET may return a stale version if it hits R replicas that haven't yet received the write — this is the eventual consistency window S3 historically exposed (now S3 is strongly consistent since 2020, achieved by adding a strong-consistency layer).

**Code Example:**
```java
// Quorum write/read in a leaderless system (pseudo-implementation)
public class LeaderlessReplicaClient {
    private final List<ReplicaNode> replicas; // e.g., 3 nodes
    private final int N, W, R;

    public LeaderlessReplicaClient(List<ReplicaNode> replicas, int w, int r) {
        this.replicas = replicas;
        this.N = replicas.size();
        this.W = w; // e.g., 2
        this.R = r; // e.g., 2
        assert W + R > N : "Quorum condition R+W>N must hold for consistency";
    }

    public void write(String key, String value, long timestamp) {
        List<CompletableFuture<Void>> futures = replicas.stream()
            .map(r -> CompletableFuture.runAsync(() -> r.write(key, value, timestamp)))
            .collect(Collectors.toList());

        // Wait for W acknowledgments (others may lag — async replication)
        int acks = 0;
        for (CompletableFuture<Void> f : futures) {
            try {
                f.get(100, TimeUnit.MILLISECONDS);
                if (++acks == W) return; // Quorum reached
            } catch (Exception e) { /* replica failed or slow */ }
        }
        if (acks < W) throw new QuorumNotReachedException("Write failed: only " + acks + "/" + W);
    }

    public String read(String key) {
        List<VersionedValue> responses = replicas.parallelStream()
            .map(r -> { try { return r.read(key); } catch (Exception e) { return null; } })
            .filter(Objects::nonNull)
            .limit(R)
            .collect(Collectors.toList());

        if (responses.size() < R) throw new QuorumNotReachedException("Read failed");

        // Read repair: if versions differ, write latest back to stale replicas
        VersionedValue latest = responses.stream()
            .max(Comparator.comparingLong(VersionedValue::getTimestamp))
            .orElseThrow();

        responses.stream()
            .filter(v -> v.getTimestamp() < latest.getTimestamp())
            .forEach(stale -> /* async repair write to stale replica */ );

        return latest.getValue();
    }
}
```

**Follow-up Questions:**
1. How does replica lag affect monotonic read consistency, and how does session stickiness address it?
2. In a network partition, what does Cassandra do with writes that can't reach a quorum?
3. What is "read your own writes" consistency and how do you implement it in a leaderless system?

**Common Mistakes:**
- Confusing R+W>N (strong read-after-write) with general strong consistency — even with R+W>N, concurrent writes can still cause conflicts
- Assuming synchronous replication is "free" — it doubles write latency and ties write availability to replica availability
- Forgetting that sloppy quorums break the R+W>N guarantee: during a partition, W might be satisfied by non-home replicas

**Interview Traps:**
- "MySQL replication is synchronous, right?" — By default, MySQL uses asynchronous replication. Only with `rpl_semi_sync_master_enabled` does it become semi-synchronous
- "With N=3, W=2, R=2, can you lose data?" — Yes: if W nodes acknowledge and then both crash before replicating to the third, the write is lost even though quorum was reached

**Quick Revision:** Single-leader is simple but bottlenecks writes; multi-leader enables multi-DC writes but needs conflict resolution; leaderless (R+W>N) gives tunable consistency with no SPOF, at the cost of conflict detection complexity.

---

### Topic 4: Eventual Consistency in Practice
**Difficulty:** Hard | **Frequency:** High | **Companies:** Amazon, Meta, Netflix, Riak, Cassandra teams

**Q:** Explain how eventual consistency systems handle conflicting concurrent writes. What are vector clocks, and when would you use CRDTs instead?

**Short Answer:**
Eventual consistency guarantees that, absent new writes, all replicas will converge to the same value — but doesn't specify when or how conflicts are resolved. Systems use last-write-wins (simple but lossy), vector clocks (detect causality to identify true conflicts), or CRDTs (data structures that provably merge without conflicts) depending on the required semantics.

**Deep Explanation:**

**The Conflict Problem:**
In a leaderless or multi-leader system, two clients can simultaneously write different values to the same key on different replicas. Both writes are locally valid; the system must reconcile them during read or anti-entropy.

**Last-Write-Wins (LWW):**
Each write is tagged with a timestamp. On conflict, the higher timestamp wins; the other write is discarded.
- Used by: Cassandra (default), DynamoDB (optional)
- Pros: Simple, O(1) space, easy to implement
- Cons: **Loses data** — a perfectly valid write is silently dropped. Vulnerable to clock skew: a node with a fast clock can override a later write. Even a few milliseconds of drift is enough to corrupt data

**Vector Clocks:**
A vector clock is a map `{nodeId → counter}`. Each write increments the local node's counter. When merging, compare two vector clocks:
- If V1 dominates V2 (all V1 counters >= V2 counters, at least one strictly greater), V1 causally follows V2 — V1 is newer, no conflict
- If neither dominates the other, the writes are **concurrent** — a true conflict requiring resolution

```
Client A writes at [A:1, B:0] → "Alice"
Client B writes at [A:0, B:1] → "Alicia"
Neither dominates → sibling versions, conflict surfaced to client
```

Amazon's original DynamoDB paper described surfacing siblings to the client for application-level resolution. Riak implements this. The trade-off: the application must handle multiple values being returned for a single key.

**Version Vectors vs. Vector Clocks:**
In systems like Riak, each **replica** has a version vector (not each client). This avoids unbounded growth of the clock when many clients write. Vector clocks grow with the number of writers; version vectors grow with the number of replicas.

**CRDTs (Conflict-free Replicated Data Types):**
CRDTs are data structures mathematically designed so that any two replicas can be merged in any order, and the result is the same. No conflict resolution logic needed.

Two types:
1. **State-based CRDTs (CvRDTs)**: Replicas periodically merge their full state. The merge function must be commutative, associative, and idempotent (a join-semilattice)
2. **Operation-based CRDTs (CmRDTs)**: Replicate operations (not state); requires reliable delivery

Common CRDTs:
| CRDT | Use Case | Merge Rule |
|------|----------|------------|
| G-Counter | Distributed counter (increment only) | Max per node |
| PN-Counter | Bidirectional counter | Two G-Counters (P and N) |
| LWW-Register | Single value (with LWW semantics) | Higher timestamp wins |
| OR-Set | Set with add/remove | Tag elements with unique IDs; remove only removes specific tagged element |
| RGA (Replicated Growable Array) | Collaborative text editing | Position-aware ordering |

Figma, Notion, and Google Docs use CRDT-based approaches for real-time collaboration. Redis has CRDT data types in Redis Enterprise (CRDB).

**Read Repair:**
When a read coordinator queries R replicas and finds different versions, it:
1. Returns the most recent version to the client
2. Asynchronously writes the most recent version back to stale replicas (read repair)
Read repair converges stale replicas but only for hot keys — cold keys may stay stale for a long time.

**Anti-Entropy (Background Repair):**
A background process (Cassandra's `nodetool repair`) compares replicas using **Merkle trees** (hash trees). Each leaf is a hash of a data range; internal nodes hash their children. Two replicas can compare their Merkle tree roots — if equal, they are in sync. If not, binary search down the tree to find the divergent leaf range. Only the divergent data is transferred.
- Cassandra: run `nodetool repair` weekly (or continuously in newer versions)
- DynamoDB: internal anti-entropy service runs continuously

**Real-World Example:**
Amazon's shopping cart (from the Dynamo paper) uses an OR-Set CRDT. Adding an item tags it with a unique identifier. Deleting removes that specific tag. If two offline clients both add different items and then sync, both additions are preserved (union of item sets). If one client deletes and the other adds the same item concurrently, the add wins — which is the correct business semantics for a shopping cart (prefer data retention over deletion consistency).

**Code Example:**
```java
// G-Counter CRDT: increment-only distributed counter
public class GCounter {
    private final String nodeId;
    private final Map<String, Long> counts = new ConcurrentHashMap<>();

    public GCounter(String nodeId) {
        this.nodeId = nodeId;
        counts.put(nodeId, 0L);
    }

    public void increment() {
        counts.merge(nodeId, 1L, Long::sum);
    }

    public long value() {
        return counts.values().stream().mapToLong(Long::longValue).sum();
    }

    // Merge two replicas: take element-wise max (join operation)
    public GCounter merge(GCounter other) {
        GCounter result = new GCounter(nodeId);
        Set<String> allNodes = new HashSet<>(this.counts.keySet());
        allNodes.addAll(other.counts.keySet());
        for (String node : allNodes) {
            result.counts.put(node, Math.max(
                this.counts.getOrDefault(node, 0L),
                other.counts.getOrDefault(node, 0L)
            ));
        }
        return result;
    }
}

// Vector clock implementation
public class VectorClock {
    private final Map<String, Long> clock = new HashMap<>();

    public void increment(String nodeId) {
        clock.merge(nodeId, 1L, Long::sum);
    }

    // Returns true if this clock causally dominates other (this happened after other)
    public boolean dominates(VectorClock other) {
        boolean strictlyGreater = false;
        for (String node : other.clock.keySet()) {
            long mine = clock.getOrDefault(node, 0L);
            long theirs = other.clock.get(node);
            if (mine < theirs) return false;
            if (mine > theirs) strictlyGreater = true;
        }
        return strictlyGreater || clock.keySet().stream()
            .anyMatch(n -> clock.get(n) > other.clock.getOrDefault(n, 0L));
    }

    public boolean isConcurrentWith(VectorClock other) {
        return !this.dominates(other) && !other.dominates(this);
    }
}
```

**Follow-up Questions:**
1. What is the "tombstone" problem in Cassandra, and how does it relate to eventual consistency and LWW deletion?
2. How does a Merkle tree enable efficient anti-entropy between two replicas? What is the time complexity?
3. Explain the difference between a state-based and operation-based CRDT. When does each become impractical?

**Common Mistakes:**
- Conflating "eventual consistency" with "inconsistent forever" — eventual consistency is a liveness property, not a safety failure
- Assuming LWW is safe because clocks are "usually accurate" — NTP has millisecond-level drift; at high write rates, this causes real data loss
- Implementing a custom conflict resolution strategy when an OR-Set or PN-Counter CRDT would give provably correct semantics

**Interview Traps:**
- "Just use timestamps" — The interviewer wants to hear you identify clock skew as a fundamental problem, not just a corner case
- "Is Cassandra eventually consistent?" — Nuanced: at quorum=ALL it is strongly consistent; below quorum, it is eventually consistent. The model is tunable

**Quick Revision:** Eventual consistency resolves conflicts via LWW (lossy), vector clocks (detect concurrent writes for app-level resolution), or CRDTs (provably conflict-free data structures); background anti-entropy via Merkle trees ensures cold data also converges.

---

### Topic 5: Distributed Caching Architecture
**Difficulty:** Medium-Hard | **Frequency:** Very High | **Companies:** Amazon, Meta, Twitter, Netflix, Cloudflare

**Q:** How does Redis Cluster use consistent hashing for shard key routing? What is the hot key problem and how do you solve it?

**Short Answer:**
Redis Cluster partitions keys across 16,384 hash slots (not pure consistent hashing — it uses a fixed slot space), with each master node owning a range of slots. A key's slot is `CRC16(key) % 16384`. The hot key problem occurs when a single key (e.g., a celebrity's profile) concentrates disproportionate traffic on one shard, causing CPU saturation.

**Deep Explanation:**

**Redis Cluster Architecture:**
Redis Cluster does not use traditional consistent hashing. Instead:
1. The key space is divided into 16,384 hash slots
2. Each master node owns a contiguous range of slots (e.g., node1: 0–5460, node2: 5461–10922, node3: 10923–16383)
3. Key routing: `slot = CRC16(key) % 16384`
4. Every Redis Cluster node knows the full slot-to-node mapping (gossip protocol)
5. If a client sends a command to the wrong node, the node responds with `MOVED <slot> <host>:<port>`

This is closer to range-based sharding on a fixed keyspace than true consistent hashing. Adding a node requires resharding — migrating specific slot ranges using `CLUSTER SETSLOT` commands (can be done online).

**Hash Tags:**
To force multiple keys to the same slot (enabling multi-key operations): use `{tag}` in the key name.
- `{user:123}.profile` and `{user:123}.settings` both hash to slot `CRC16("user:123") % 16384`
- Allows MGET, MSET, Lua scripts, and transactions across these keys

**Cache Sharding Strategies (beyond Redis Cluster):**
1. **Client-side sharding**: Application decides which Redis shard based on consistent hashing. Simple, no proxy overhead, but resharding requires application changes
2. **Proxy-based sharding**: Twemproxy (nutcracker) or Envoy proxy handles routing. Transparent to application; single point of failure risk
3. **Redis Cluster**: Native cluster mode; most production setups use this

**The Hot Key Problem:**
Scenario: A celebrity tweet is retweeted 10M times. The tweet object `tweet:elonmusk:12345` maps to one Redis slot, which maps to one Redis master. All 1M cache reads/sec hit that single 1-CPU Redis process.

**Solutions:**
1. **Key replication / read replicas**: Redis replica nodes serve reads. Add replicas for hot shards (Redis Cluster supports per-slot replica counts, though less common)
2. **Local in-process cache**: Application-level cache (Caffeine/Guava) holds hot keys in JVM heap. Reads never leave the process. TTL of 100ms is sufficient for most hot keys
3. **Key segmentation**: Append a random suffix: `tweet:12345:shard_1`, `tweet:12345:shard_2`, ..., `tweet:12345:shard_K`. Write to all K shards; read randomly from one shard. Distributes read load K-fold. Consistency trade-off: invalidation must hit all K shards
4. **Request coalescing (request collapsing)**: When many requests arrive for the same key simultaneously (thundering herd), coalesce them into one backend request and fan out the result
5. **Micro-sharding via consistent hashing**: Increase the number of Redis instances just for hot keys

**Cache Invalidation Patterns:**
- **Cache-aside (lazy loading)**: Read from cache; on miss, load from DB and populate cache
- **Write-through**: Write to cache and DB simultaneously; always consistent but slower writes
- **Write-behind (write-back)**: Write to cache immediately, flush to DB asynchronously; fast writes but risk of data loss on cache failure
- **Refresh-ahead**: Proactively refresh cache entries before they expire based on access frequency

**Real-World Example:**
Facebook's Memcached (McSqueal, Tao) handles hot keys via "lease" mechanisms. When a cache miss occurs during a thundering herd, the first requesting client gets a lease token to populate the cache. All other clients wait briefly and then retry. This prevents the "cache stampede" (all clients simultaneously hammering the DB on a popular cache miss).

**Code Example:**
```java
// Local hot-key cache with random shard selection for distributed Redis
@Component
public class HotKeyAwareCacheClient {
    private final RedisCluster redisCluster;
    private final LoadingCache<String, String> localHotCache;
    private static final int HOT_KEY_SHARDS = 10;

    public HotKeyAwareCacheClient(RedisCluster redisCluster) {
        this.redisCluster = redisCluster;
        // Local in-process cache for hot keys: max 1000 entries, 100ms TTL
        this.localHotCache = Caffeine.newBuilder()
            .maximumSize(1000)
            .expireAfterWrite(100, TimeUnit.MILLISECONDS)
            .build(key -> fetchFromRedis(key));
    }

    public String get(String key, boolean isHotKey) {
        if (isHotKey) {
            // Check local cache first (0 network hops)
            return localHotCache.get(key);
        }
        return fetchFromRedis(key);
    }

    public void setHotKey(String key, String value, int ttlSeconds) {
        // Write to all shards for a hot key
        for (int i = 0; i < HOT_KEY_SHARDS; i++) {
            redisCluster.setex(key + ":shard:" + i, ttlSeconds, value);
        }
    }

    public String getHotKey(String key) {
        // Read from random shard to distribute load
        int shard = ThreadLocalRandom.current().nextInt(HOT_KEY_SHARDS);
        String shardedKey = key + ":shard:" + shard;
        return redisCluster.get(shardedKey);
    }

    // Request coalescing: prevent thundering herd
    private final ConcurrentHashMap<String, CompletableFuture<String>> inflightRequests
        = new ConcurrentHashMap<>();

    public CompletableFuture<String> getWithCoalescing(String key) {
        return inflightRequests.computeIfAbsent(key, k ->
            CompletableFuture
                .supplyAsync(() -> fetchFromDbAndCache(k))
                .whenComplete((v, e) -> inflightRequests.remove(k))
        );
        // All concurrent callers for the same key share this future
    }
}
```

**Follow-up Questions:**
1. How does Redis Cluster handle node failures and slot reassignment? What is the role of replicas during failover?
2. What is a cache stampede (thundering herd), and how do probabilistic early expiration (PER) or mutex-based solutions address it?
3. How would you implement a circuit breaker pattern for a Redis cache to protect the database during cache failures?

**Common Mistakes:**
- Not setting TTLs on cached values — cache grows unbounded, evicts LRU, unpredictable behavior
- Using `KEYS *` in production Redis (O(N) scan blocks the single-threaded event loop)
- Forgetting that Redis Cluster requires that multi-key operations use hash tags to guarantee same-slot placement

**Interview Traps:**
- "Redis is strongly consistent" — Redis is not strongly consistent by default. Async replication means a master failure can lose recent writes. Redis with `WAIT` command provides stronger guarantees but is not the default
- "Just add more Redis replicas to solve the hot key problem" — Redis replicas are not automatically read-load-balanced in Redis Cluster; you need client-side read replica routing

**Quick Revision:** Redis Cluster uses 16,384 hash slots (not pure consistent hashing); hot keys are solved through local in-process caches, key segmentation across N shards, or request coalescing — never by adding replicas alone.

---

### Topic 6: Time in Distributed Systems
**Difficulty:** Hard | **Frequency:** Medium-High | **Companies:** Google (Spanner), Amazon, Cockroach Labs, Stripe

**Q:** Why can't we rely on wall clocks in distributed systems? Explain Lamport timestamps, vector clocks, and Google TrueTime.

**Short Answer:**
Wall clocks (system clocks) in distributed systems are unreliable due to clock skew (different machines disagree on current time) and clock drift (clocks run at slightly different rates). Lamport timestamps provide causal ordering without wall clocks. TrueTime (Google Spanner) uses GPS/atomic clocks with explicit uncertainty intervals to enable globally consistent transactions.

**Deep Explanation:**

**Why Wall Clocks Fail:**
1. **Clock skew**: Two machines read `System.currentTimeMillis()` simultaneously and get different values. NTP (Network Time Protocol) synchronizes clocks but only to ~1–10ms accuracy over the internet, ~0.1ms on a LAN
2. **Clock drift**: CPU oscillators run at slightly different frequencies. Without NTP correction, clocks drift ~100–200 ppm (parts per million) = 8–17 seconds/day
3. **NTP step adjustments**: NTP can jump the clock backward or forward, causing `System.currentTimeMillis()` to be non-monotonic. Using `System.nanoTime()` (monotonic clock) avoids backward jumps but is only valid within one JVM instance
4. **VM clock issues**: On virtualized infrastructure, the VM clock is managed by the hypervisor and can stall (during live migration) or jump unexpectedly

**Implications for LWW:**
If you use timestamps for last-write-wins and node A's clock is 50ms ahead, all writes from A win over concurrent writes from B — even if B's write was logically later. This silently discards data.

**Lamport Timestamps:**
A logical clock that captures causal ordering without wall clocks:
- Each process maintains a counter C, initialized to 0
- On send: increment C, attach C to message
- On receive: C = max(local_C, message_C) + 1
- Guarantee: if event A causally precedes event B, then L(A) < L(B)
- Limitation: if L(A) < L(B), it does NOT mean A causally preceded B (false positives). Cannot detect concurrent events

**Vector Clocks:**
Extend Lamport clocks to detect concurrency (covered in Topic 4). Each process tracks a counter per process in the system. Allows detecting whether two events are concurrent or causally related.

**Hybrid Logical Clocks (HLC):**
Combine wall clock time with a logical counter:
- `HLC = (physical_time, logical_counter)`
- Normal operation: HLC tracks wall clock time
- On message receive: if wall clock has advanced, use wall clock; otherwise increment logical counter
- Guarantee: monotonically increasing, close to wall clock time, captures causality
- Used by: CockroachDB, YugabyteDB

HLC provides the best of both worlds: causality tracking AND approximate real-world time alignment.

**Google TrueTime:**
Spanner's innovation — explicitly model clock uncertainty:
- GPS receivers and atomic clocks in each Google datacenter
- TrueTime API: `TT.now()` returns `[earliest, latest]` — an interval guaranteed to contain the true current time
- Typical uncertainty: 1–7ms
- **Commit wait**: Before committing a transaction, Spanner waits until `TT.after(commit_timestamp)` is true — i.e., the uncertainty interval has passed, guaranteeing the commit timestamp is definitively in the past
- This enables **external consistency** (linearizability) across globally distributed data without coordination

```
TT.now() returns [t - ε, t + ε]
Spanner waits at least 2ε before returning, so all subsequent transactions
see a higher timestamp → global linearizability guaranteed
```

**Practical Timeline of Distributed Time Solutions:**
1. Wall clocks + NTP: 1ms–10ms accuracy; sufficient for LWW if you accept occasional conflicts
2. Lamport clocks: total order without wall clocks; doesn't capture real time
3. Vector clocks: detect concurrent events; space O(N) per event
4. HLC: causality + wall clock proximity; used in NewSQL databases
5. TrueTime: true wall clock with explicit uncertainty; requires hardware (GPS/atomic clocks)

**Real-World Example:**
CockroachDB uses HLC for multi-region transactions. When a transaction spans datacenters, HLC ensures that reads in datacenter B always see writes committed in datacenter A before them (causal consistency). CockroachDB also uses HLC for MVCC — each row version is tagged with an HLC timestamp, enabling time-travel queries (`AS OF SYSTEM TIME`).

**Code Example:**
```java
// Lamport Clock implementation
public class LamportClock {
    private final AtomicLong counter = new AtomicLong(0);

    public long tick() {
        return counter.incrementAndGet();
    }

    public long onSend() {
        return counter.incrementAndGet(); // Attach this to outgoing message
    }

    public long onReceive(long receivedTimestamp) {
        return counter.updateAndGet(current -> Math.max(current, receivedTimestamp) + 1);
    }

    public long current() { return counter.get(); }
}

// Hybrid Logical Clock (simplified)
public class HybridLogicalClock {
    private volatile long wallTime = 0;    // last known physical time
    private volatile long logicalCounter = 0;

    public synchronized long[] tick() {
        long now = System.currentTimeMillis();
        if (now > wallTime) {
            wallTime = now;
            logicalCounter = 0;
        } else {
            logicalCounter++;
        }
        return new long[]{wallTime, logicalCounter};
    }

    public synchronized long[] onReceive(long msgWallTime, long msgLogical) {
        long now = System.currentTimeMillis();
        long newWall = Math.max(Math.max(wallTime, msgWallTime), now);
        if (newWall == wallTime && newWall == msgWallTime) {
            logicalCounter = Math.max(logicalCounter, msgLogical) + 1;
        } else if (newWall == wallTime) {
            logicalCounter++;
        } else if (newWall == msgWallTime) {
            logicalCounter = msgLogical + 1;
        } else {
            logicalCounter = 0;
        }
        wallTime = newWall;
        return new long[]{wallTime, logicalCounter};
    }
}

// TrueTime-style API (conceptual — requires hardware)
public class TrueTime {
    private final AtomicReference<Interval> uncertainty = new AtomicReference<>();

    public Interval now() {
        // In reality: query GPS/atomic clock service
        long epsilon = 4; // ms, typical Spanner uncertainty
        long now = System.currentTimeMillis();
        return new Interval(now - epsilon, now + epsilon);
    }

    public boolean before(long timestamp) {
        return now().getLatest() < timestamp;
    }

    public boolean after(long timestamp) {
        return now().getEarliest() > timestamp;
    }
}
```

**Follow-up Questions:**
1. CockroachDB doesn't have Google's atomic clock hardware. How does it approximate TrueTime semantics, and what consistency trade-offs result?
2. Why does Spanner's commit-wait introduce latency proportional to the TrueTime uncertainty, and how does this affect cross-region transaction performance?
3. What is "clock bound" in distributed systems, and how does Amazon's TimeSync service compare to Google TrueTime?

**Common Mistakes:**
- Using `System.currentTimeMillis()` for ordering distributed events — it's not monotonic and varies across machines
- Assuming `System.nanoTime()` works across machines — it doesn't; it's only monotonic within a single JVM and not correlated between machines
- Forgetting that even with perfect time sync, the definition of "simultaneous" is ambiguous in physics (relativity), which is why TrueTime uses intervals rather than points

**Interview Traps:**
- "Just use a centralized timestamp server" — Single point of failure; the timestamp server itself becomes a bottleneck and its clock can drift
- "NTP is good enough" — For LWW conflict resolution in databases, a 10ms NTP error translates directly to a 10ms window where writes can be silently reordered; at high write rates this is unacceptable

**Quick Revision:** Wall clocks can't be trusted due to NTP skew and drift; Lamport clocks give causal ordering, vector clocks detect concurrency, HLC combines both, and TrueTime provides bounded uncertainty using GPS/atomic clocks for global linearizability in Spanner.

---

### Topic 7: Consensus Algorithms
**Difficulty:** Very Hard | **Frequency:** Medium | **Companies:** Google, Amazon, Cloudflare, HashiCorp, etcd/Kubernetes

**Q:** Explain the Raft consensus algorithm. How does leader election work, and how does log replication guarantee safety?

**Short Answer:**
Raft is a consensus algorithm designed for understandability. A cluster elects a single leader via randomized election timeouts; the leader receives all writes, replicates log entries to followers, and commits once a majority acknowledge. Safety is guaranteed by the log matching property: if two logs agree on an entry's index and term, they agree on all preceding entries.

**Deep Explanation:**

**Why Consensus Matters:**
In a distributed system, getting N nodes to agree on a single value (or sequence of values) is the fundamental problem. Consensus is needed for: leader election, distributed locks, atomic broadcast, replicated state machines.

**Paxos — the original (and hard to understand):**
Leslie Lamport's Paxos (1989) has two phases:
1. **Prepare phase**: Proposer sends `Prepare(n)` to majority. Each acceptor promises to ignore proposals < n and replies with the highest-numbered accepted value
2. **Accept phase**: Proposer sends `Accept(n, v)` where v is the highest-valued proposal from prepare responses. Acceptors accept if they haven't promised to ignore n

Problems: Paxos specifies agreement on a single value (single-decree Paxos). Multi-Paxos (for a log) requires significant additional protocol. The original paper doesn't specify many practical details (leader election, log compaction, membership changes). Result: every Paxos implementation is effectively a unique protocol.

**Raft — designed for understandability:**
Raft decomposes consensus into three separable subproblems:
1. **Leader election**
2. **Log replication**
3. **Safety**

**Raft Terms:**
Time is divided into **terms** (monotonically increasing integers). Each term begins with an election. If a candidate wins, it leads for the remainder of the term. Terms serve as logical clocks — a node receiving a message with a higher term immediately updates and reverts to follower.

**Leader Election:**
- All nodes start as **followers**
- Followers expect a heartbeat from the leader. Each follower has a random **election timeout** (150–300ms)
- If no heartbeat received within the timeout, follower becomes a **candidate** and increments its term
- Candidate sends `RequestVote` RPC to all peers
- A node grants its vote if: (a) it hasn't voted in this term yet, AND (b) the candidate's log is at least as up-to-date as its own (log completeness check)
- If a candidate receives votes from majority (N/2 + 1), it becomes **leader**
- Randomized timeouts prevent split votes: if two candidates start simultaneously, one will win before the other's timeout fires in the next attempt

**Log Replication:**
1. Client sends command to leader
2. Leader appends entry to its local log with current term
3. Leader sends `AppendEntries` RPC (also serves as heartbeat) to all followers
4. Once majority acknowledge, leader **commits** the entry (applies to state machine)
5. Leader includes `commitIndex` in subsequent RPCs; followers commit up to that index

**Safety — Log Matching Property:**
If two log entries at the same index have the same term, the logs are identical up to that index. This is maintained by `AppendEntries` consistency check: the RPC includes the previous entry's index and term; a follower rejects if its log doesn't match at that point.

**Election Restriction (Vote Safety):**
A candidate's log must be at least as up-to-date as any majority member before it can win. "Up-to-date" means: higher term in last entry, or same term with longer log. This ensures that leaders always have all committed entries.

**Log Compaction (Snapshots):**
Logs grow unbounded. Raft uses snapshots: state machine periodically serializes its state, and all log entries up to that point are discarded. Lagging followers receive the snapshot via `InstallSnapshot` RPC.

**Cluster Membership Changes:**
Adding/removing nodes without taking the cluster offline uses joint consensus: first commit a log entry specifying the joint configuration (old + new); then commit the new configuration. During joint consensus, both configurations must agree on any decision.

**Raft vs. Paxos:**
| Aspect | Raft | Multi-Paxos |
|--------|------|-------------|
| Understandability | Designed for it | Notoriously complex |
| Leader | Explicit, one per term | Can have multiple proposers |
| Log gaps | Not allowed | Allowed (must be filled) |
| Implementation | etcd, CockroachDB, TiKV | Chubby (Google), some DBs |

**Real-World Example:**
etcd (used by Kubernetes for cluster state) uses Raft. When a Kubernetes API server writes a pod spec, etcd's Raft leader replicates it to a majority of etcd members before responding. If the leader crashes, etcd elects a new leader within the election timeout (default: 1s). During the election, writes are unavailable — Kubernetes operators see this as brief API server unresponsiveness.

**Code Example:**
```java
// Raft state machine (simplified — key structures and transitions)
public class RaftNode {
    enum State { FOLLOWER, CANDIDATE, LEADER }

    private volatile State state = State.FOLLOWER;
    private volatile int currentTerm = 0;
    private volatile String votedFor = null;
    private final List<LogEntry> log = new ArrayList<>();
    private volatile int commitIndex = 0;
    private volatile int lastApplied = 0;
    private final String nodeId;
    private final List<String> peers;

    // Leader state (reinitialized after election)
    private final Map<String, Integer> nextIndex = new HashMap<>();   // for each server: next log index to send
    private final Map<String, Integer> matchIndex = new HashMap<>();  // for each server: highest known replicated index

    // Election timeout: 150-300ms random
    private ScheduledFuture<?> electionTimer;

    public synchronized void onReceiveRequestVote(RequestVoteRequest req, ResponseCallback cb) {
        if (req.getTerm() > currentTerm) {
            currentTerm = req.getTerm();
            state = State.FOLLOWER;
            votedFor = null;
        }

        boolean logUpToDate = isLogAtLeastAsUpToDate(req.getLastLogIndex(), req.getLastLogTerm());
        boolean voteGranted = req.getTerm() == currentTerm
            && (votedFor == null || votedFor.equals(req.getCandidateId()))
            && logUpToDate;

        if (voteGranted) votedFor = req.getCandidateId();
        cb.reply(new RequestVoteResponse(currentTerm, voteGranted));
    }

    public synchronized void onReceiveAppendEntries(AppendEntriesRequest req, ResponseCallback cb) {
        if (req.getTerm() < currentTerm) {
            cb.reply(new AppendEntriesResponse(currentTerm, false));
            return;
        }
        // Reset election timer — valid leader heartbeat received
        resetElectionTimer();
        if (req.getTerm() > currentTerm) {
            currentTerm = req.getTerm();
            state = State.FOLLOWER;
        }

        // Log consistency check
        if (req.getPrevLogIndex() > 0
            && (log.size() < req.getPrevLogIndex()
                || log.get(req.getPrevLogIndex() - 1).getTerm() != req.getPrevLogTerm())) {
            cb.reply(new AppendEntriesResponse(currentTerm, false));
            return;
        }

        // Append new entries (remove conflicting suffix first)
        for (int i = 0; i < req.getEntries().size(); i++) {
            int logIndex = req.getPrevLogIndex() + i;
            if (logIndex < log.size()) {
                if (log.get(logIndex).getTerm() != req.getEntries().get(i).getTerm()) {
                    // Conflict: truncate and replace
                    while (log.size() > logIndex) log.remove(log.size() - 1);
                    log.add(req.getEntries().get(i));
                }
            } else {
                log.add(req.getEntries().get(i));
            }
        }

        if (req.getLeaderCommit() > commitIndex) {
            commitIndex = Math.min(req.getLeaderCommit(), log.size());
            applyCommitted();
        }
        cb.reply(new AppendEntriesResponse(currentTerm, true));
    }

    private boolean isLogAtLeastAsUpToDate(int candidateLastIndex, int candidateLastTerm) {
        if (log.isEmpty()) return true;
        LogEntry lastEntry = log.get(log.size() - 1);
        if (candidateLastTerm != lastEntry.getTerm()) return candidateLastTerm > lastEntry.getTerm();
        return candidateLastIndex >= log.size();
    }
}
```

**Follow-up Questions:**
1. What happens in Raft if the network partitions and the leader gets isolated with a minority of nodes? Can it continue to serve reads?
2. How does Raft handle a scenario where a leader crashes after committing to its own log but before replicating to any follower?
3. What is "pre-vote" in Raft, and why does it prevent disruptive elections?

**Common Mistakes:**
- Thinking Raft provides strong consistency for reads by default — a leader can serve stale reads if it's been partitioned (it may not know it's no longer leader). Solutions: leader leases, read-index protocol
- Forgetting that Raft requires an odd number of nodes: with 4 nodes, you need 3 for majority, tolerating only 1 failure — same as 3 nodes. Always use 3, 5, or 7 nodes
- Assuming Raft is linearizable out of the box for read operations — writes are linearizable, reads require the ReadIndex protocol to avoid stale reads

**Interview Traps:**
- "Can Raft have multiple leaders?" — No, but a node might believe it's still leader after a partition. The key safety property is that committed entries are never overridden — a new leader will have all committed entries due to the election restriction
- "How is Raft different from 2PC?" — 2PC requires all participants to agree (blocking on any failure); Raft only requires majority agreement (tolerates minority failures)

**Quick Revision:** Raft achieves consensus via an elected leader that replicates a log to majority; safety relies on the election restriction (leaders must have all committed entries) and log matching property; used in etcd, CockroachDB, TiKV.

---

### Topic 8: Leader Election
**Difficulty:** Hard | **Frequency:** Medium-High | **Companies:** Amazon, Google, HashiCorp, Confluent, Netflix

**Q:** How would you implement distributed leader election? Compare ZooKeeper ephemeral nodes, etcd distributed locks, and Redis Redlock. What makes leader election fundamentally hard?

**Short Answer:**
Leader election requires that exactly one node believes it is the leader at any time (the safety property). ZooKeeper uses ephemeral znodes with sequential numbering to elect leaders safely. Redis Redlock distributes lock acquisition across multiple Redis instances. The fundamental difficulty is preventing two nodes from simultaneously believing they are leader (split-brain) in the presence of network partitions and timing assumptions.

**Deep Explanation:**

**Why Leader Election is Hard:**
The core challenge: you cannot reliably distinguish between "the leader crashed" and "the leader is temporarily unreachable due to a network partition." If you revoke leadership too eagerly, you get split-brain (two leaders). If you wait too long, availability suffers.

**The GC Pause / Stop-the-World Problem:**
Consider: Leader L holds a lease until time T. At T-1 second, L experiences a JVM garbage collection pause lasting 15 seconds. During the pause, the lease expires and a new leader L2 is elected. L resumes and doesn't know it lost leadership — it attempts to write, now competing with L2. This is the fundamental timing problem.

Solution: **fencing tokens**. Every time a leader is elected, it receives a monotonically increasing token from the lock service. Any write to external storage must include the fencing token. Storage systems (ZooKeeper, DynamoDB conditional writes) reject writes with old tokens.

**ZooKeeper Ephemeral Nodes:**
ZooKeeper nodes (znodes) can be **ephemeral**: they are automatically deleted when the client's session expires (session = TCP connection + heartbeat). This makes them ideal for leader election.

*Recipe:*
1. All nodes create an ephemeral sequential znode at `/election/candidate-` (ZooKeeper assigns sequential numbers: candidate-001, candidate-002, ...)
2. Each node reads all children of `/election/` and sorts them
3. If your znode has the lowest sequence number → you are the leader
4. Otherwise → watch the znode with the next lower sequence number for deletion
5. When the watched znode is deleted (node crashed), re-evaluate — if you now have the lowest number, become leader

*Why watch the predecessor (not all children)?*
If all nodes watch the same leader znode (the minimum), when it disappears, all N-1 followers trigger simultaneously → herd effect → O(N) ZooKeeper requests at once. Watching only predecessor creates a chain: O(1) notifications.

*Session timeout:* ZooKeeper default session timeout is ~30 seconds. If the leader's network connection is lost but the process is alive, it may still believe it's leader for up to 30 seconds — another process is elected. Both believe they are leader. Fencing tokens prevent dangerous concurrent actions.

**etcd Distributed Lock:**
etcd provides a lock primitive via its client library using leases:
1. Create a lease with TTL: `etcd.grant(15, TimeUnit.SECONDS)`
2. Put a key `/locks/my-service` with the lease ID attached
3. If the put uses `txn` with `createRevision == 0` (key doesn't exist), the lock is acquired
4. If createRevision != 0, watch the key for deletion and retry
5. Renew the lease periodically; if the process dies, the lease expires and the key is deleted

etcd uses Raft internally, so the lock is consistent: at most one node can acquire it at any time (unlike Redis without Raft). The lock service itself is fault-tolerant: etcd's Raft quorum means the lock state survives minority node failures.

**Redis Redlock:**
Proposed by Redis creator Salvatore Sanfilippo for fault-tolerant locking when a single Redis instance is unreliable.

*Algorithm:*
1. Deploy N independent Redis instances (no replication between them), typically N=5
2. To acquire lock: for each Redis instance, attempt `SET key token NX PX ttl_ms`
3. Lock is acquired if majority (N/2 + 1 = 3) succeed within a validity window
4. Validity time = TTL - time_to_acquire - clock_drift_buffer
5. To release: send a Lua script to each instance to delete only if value matches token

*Controversy:*
Martin Kleppmann (author of DDIA) published a critique of Redlock:
- **Clock jump problem**: Redis uses TTL based on wall clock. If a Redis server's clock jumps forward (e.g., NTP step adjustment), the lock expires before the client expects, and two clients can both believe they hold the lock
- **GC pause problem**: Same as ZooKeeper — a client can experience a GC pause longer than the lock TTL, regain execution, and believe it still holds the lock while another client has acquired it
- **Network timing**: Redlock makes timing assumptions about network delays that cannot be guaranteed in asynchronous networks (FLP impossibility applies)

Salvatore's counter-argument: Redlock is designed for efficiency (avoiding duplicate work), not correctness-critical mutual exclusion. For true safety, use fencing tokens with a backend that supports conditional writes.

**Summary Comparison:**

| Aspect | ZooKeeper | etcd | Redlock |
|--------|-----------|------|---------|
| Consensus | ZAB (Paxos-like) | Raft | None (multi-instance voting) |
| Consistency | Strong | Strong | Weak (clock-dependent) |
| Fencing tokens | Yes (zxid) | Yes (revision) | No (requires external implementation) |
| Lease renewal | Session heartbeat | Lease keepalive | EXPIRE reset |
| Safety under GC | Requires fencing | Requires fencing | Vulnerable without fencing |
| Operational complexity | High (JVM, ZooKeeper knowledge) | Low (single binary) | Medium |

**Real-World Example:**
Kafka uses ZooKeeper for broker leader election (Kafka 2.x and earlier). Each partition has a leader broker; ZooKeeper ephemeral nodes track which broker is alive. When the partition leader crashes, its ephemeral node disappears, triggering a re-election for that partition. Kafka 3.x introduces KRaft (Kafka Raft metadata) to remove the ZooKeeper dependency — Kafka's own Raft implementation handles leader election internally, reducing operational complexity.

**Code Example:**
```java
// etcd distributed lock for leader election using Jetcd client
public class DistributedLeaderElection {
    private final Client etcdClient;
    private final String serviceName;
    private volatile boolean isLeader = false;
    private volatile long leaseId;

    public DistributedLeaderElection(String etcdEndpoint, String serviceName) {
        this.etcdClient = Client.builder().endpoints(etcdEndpoint).build();
        this.serviceName = serviceName;
    }

    public void startElection() throws Exception {
        // 1. Create a lease with 15-second TTL
        LeaseGrantResponse leaseResp = etcdClient.getLeaseClient()
            .grant(15).get();
        leaseId = leaseResp.getID();

        // 2. Start keepalive to renew lease while we're alive
        etcdClient.getLeaseClient().keepAlive(leaseId, new StreamObserver<>() {
            @Override public void onNext(LeaseKeepAliveResponse r) { /* renewed */ }
            @Override public void onError(Throwable t) { onLeadershipLost(); }
            @Override public void onCompleted() { onLeadershipLost(); }
        });

        // 3. Try to acquire lock atomically (only if key doesn't exist)
        String lockKey = "/election/" + serviceName + "/leader";
        String nodeId = InetAddress.getLocalHost().getHostName() + ":" + System.currentTimeMillis();
        ByteSequence key = ByteSequence.from(lockKey, StandardCharsets.UTF_8);
        ByteSequence val = ByteSequence.from(nodeId, StandardCharsets.UTF_8);

        // Conditional put: createRevision == 0 means key doesn't exist
        Txn txn = etcdClient.getKVClient().txn();
        TxnResponse txnResp = txn
            .If(new Cmp(key, Cmp.Op.EQUAL, CmpTarget.createRevision(0)))
            .Then(Op.put(key, val, PutOption.newBuilder().withLeaseId(leaseId).build()))
            .commit().get();

        if (txnResp.isSucceeded()) {
            isLeader = true;
            onLeadershipAcquired();
        } else {
            // Watch the key; when it's deleted (leader dies), retry election
            watchAndRetry(key);
        }
    }

    private void watchAndRetry(ByteSequence key) {
        etcdClient.getWatchClient().watch(key, WatchOption.DEFAULT, response -> {
            for (WatchEvent event : response.getEvents()) {
                if (event.getEventType() == WatchEvent.EventType.DELETE) {
                    try { startElection(); } catch (Exception e) { /* retry with backoff */ }
                }
            }
        });
    }

    private void onLeadershipAcquired() {
        System.out.println("This node is now the leader. LeaseId=" + leaseId);
        // Begin leader tasks: e.g., coordinate workers, accept writes
    }

    private void onLeadershipLost() {
        isLeader = false;
        System.err.println("Leadership lost! Stopping leader activities.");
        // Immediately stop all leader activities to prevent split-brain
    }

    // Fencing token: use etcd's revision number as a monotonic token
    // Pass this to storage systems on every write operation
    public long getFencingToken() {
        return leaseId; // In practice, use the key's modifyRevision from etcd
    }
}
```

**Follow-up Questions:**
1. What is a "zombie leader" in distributed systems, and how do fencing tokens prevent it from causing data corruption?
2. How would you implement a distributed cron scheduler (single instance running a job at a time) using leader election?
3. Martin Kleppmann argues that Redlock is unsafe even with fencing. Do you agree? Under what conditions would you still use Redlock?

**Common Mistakes:**
- Implementing leader election without fencing tokens — the GC pause / long STW issue can cause split-brain even with perfect lock acquisition logic
- Using a single Redis instance for distributed locking — a single instance is a SPOF; if it fails, the lock is gone; if it restarts and loses data (no persistence), old lock holders may act without knowing the lock was reassigned
- Not handling the "I think I'm still leader" scenario — after acquiring leadership, always check on every operation whether the lease/lock is still valid before acting

**Interview Traps:**
- "Is etcd distributed lock perfectly safe?" — No: a process that acquires the lock can pause (GC, OS scheduling) longer than the TTL. After waking up, it believes it still holds the lock. Fencing tokens + conditional writes in the downstream system are required for true safety
- "Can you use database row locking for leader election?" — Yes (SELECT ... FOR UPDATE on a heartbeat table is a common pattern), but the database itself must be highly available and the row lock must expire if the leader crashes (requires a watchdog or TTL mechanism)
- "Just use a single strong master database for coordination" — The point of leader election is to handle the case where that master fails; circular dependency

**Quick Revision:** Leader election ensures exactly one active leader using ZooKeeper ephemeral nodes (ZAB consensus), etcd leases (Raft consensus), or Redlock (majority Redis quorum); the core challenge is preventing split-brain during GC pauses or network partitions — fencing tokens with conditional writes are the only safe solution.

---

## Chapter 17 Part A — Quick Reference Card

| Topic | Key Algorithm | Production System | Interview Trigger |
|-------|--------------|-------------------|-------------------|
| Sharding | Hash/Range/Directory | Vitess, Citus | "Scale MySQL to 1B rows" |
| Consistent Hashing | Ring + vnodes | Cassandra, Redis Cluster | "Add cache nodes without downtime" |
| Replication | Leader/Leaderless + Quorum | DynamoDB, Cassandra | "How does replication work in Cassandra?" |
| Eventual Consistency | LWW / Vector Clocks / CRDTs | Riak, Cassandra | "How do you handle write conflicts?" |
| Distributed Cache | Redis Cluster + 16384 slots | Redis, Memcached | "Handle 1M reads/sec on a hot key" |
| Time | Lamport → HLC → TrueTime | CockroachDB, Spanner | "How does Spanner achieve global consistency?" |
| Consensus | Raft (leader + log replication) | etcd, TiKV | "Explain how etcd works" |
| Leader Election | Ephemeral znodes / etcd lease | ZooKeeper, etcd | "How does Kafka elect a partition leader?" |

---

*Part B continues with: Distributed Transactions (2PC, Saga, Outbox Pattern), CRDB Architecture, NewSQL vs NoSQL trade-offs, Read/Write Path of DynamoDB, and Distributed Query Execution.*


---

# Chapter 17 — Distributed Databases & Sharding: PART B
## Topics 9–15 + Cheat Sheet

---

### Topic 9: DynamoDB Deep Dive

**Difficulty:** Hard | **Frequency:** Very High | **Companies:** Amazon, Netflix, Lyft, Airbnb, Snap

**Q:** Explain DynamoDB's data model, indexing strategies (LSI vs GSI), capacity planning, and how you would design a single-table schema for an e-commerce application.

**Short Answer:**
DynamoDB is a fully managed, serverless key-value and document store where every item is identified by a partition key (and optionally a sort key). LSIs share the base table's partition key but allow a different sort key, while GSIs allow entirely different partition and sort keys and are stored as separate, eventually-consistent projections. Single-table design collapses multiple entity types into one table to enable efficient, low-latency access patterns without JOINs.

**Deep Explanation:**

**Data Model Fundamentals:**
- **Partition Key (PK):** Determines the partition node. DynamoDB hashes the PK to route requests. High-cardinality PKs distribute load evenly.
- **Sort Key (SK):** Enables range queries within a partition. Items with the same PK are stored contiguously, sorted by SK.
- **Item size:** Max 400 KB. Attribute names count toward the limit.
- **Partition capacity:** Each partition handles up to 3,000 RCUs and 1,000 WCUs. Hot partitions cause throttling.

**Index Types:**

| Feature | LSI (Local Secondary Index) | GSI (Global Secondary Index) |
|---|---|---|
| Partition Key | Same as base table | Different from base table |
| Sort Key | Different from base table | Any attribute |
| Consistency | Strong or eventual | Eventual only |
| Storage | Shares base table partition | Separate partition space |
| Limit per table | 5 | 20 |
| Created after table creation | No | Yes |
| Throttling | Shares base table capacity | Separate capacity units |

**Capacity Modes:**
- **Provisioned:** Specify RCUs and WCUs. Auto-scaling adjusts within min/max bounds. Cost-effective for predictable workloads.
- **On-Demand:** Pay per request. No capacity planning. 2–3x more expensive but scales instantly.
- **Read Capacity Unit (RCU):** 1 strongly consistent read or 2 eventually consistent reads of up to 4 KB/s.
- **Write Capacity Unit (WCU):** 1 write of up to 1 KB/s.
- **Transactional reads/writes:** Consume 2x the normal capacity.

**DynamoDB Streams:**
- Ordered, time-limited (24h) log of item-level changes (INSERT, MODIFY, REMOVE).
- Stream record contains old image, new image, or both.
- Powers Lambda triggers for event-driven architectures (CDC, cache invalidation, search index sync).
- Exactly-once delivery per shard via Lambda event source mapping.

**Single-Table Design Philosophy:**
- One table per service/application. Entity types coexist using PK/SK conventions.
- Access patterns drive schema design — identify all read/write patterns before modeling.
- Overloaded indexes: multiple entity types share the same GSI using different PK/SK semantics.
- Sparse indexes: GSIs only index items that have the GSI attribute, reducing cost.

**Real-World Example:**
An e-commerce platform needs: get order by ID, list orders by customer, list items in an order, get product by ID. Single-table design:

```
PK=CUSTOMER#c1   SK=CUSTOMER#c1          → customer profile
PK=CUSTOMER#c1   SK=ORDER#2024-01-15#o1  → order (sort by date)
PK=ORDER#o1      SK=ITEM#p1              → order line item
PK=PRODUCT#p1    SK=PRODUCT#p1           → product catalog
```

GSI1 on (GSI1PK, GSI1SK) for inverted access patterns (e.g., find all customers who ordered product P).

**Code Example:**

```java
// Spring Boot + AWS SDK v2 DynamoDB Enhanced Client
// Entity definition with single-table design

@DynamoDbBean
public class Order {

    private String pk;        // "ORDER#orderId"
    private String sk;        // "ORDER#orderId"
    private String customerId;
    private String gsi1Pk;    // "CUSTOMER#customerId"
    private String gsi1Sk;    // "ORDER#2024-01-15T10:00:00#orderId"
    private String status;
    private BigDecimal total;
    private String createdAt;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("PK")
    public String getPk() { return pk; }

    @DynamoDbSortKey
    @DynamoDbAttribute("SK")
    public String getSk() { return sk; }

    @DynamoDbSecondaryPartitionKey(indexNames = "GSI1")
    @DynamoDbAttribute("GSI1PK")
    public String getGsi1Pk() { return gsi1Pk; }

    @DynamoDbSecondarySortKey(indexNames = "GSI1")
    @DynamoDbAttribute("GSI1SK")
    public String getGsi1Sk() { return gsi1Sk; }

    // getters/setters omitted for brevity
}

@Service
public class OrderRepository {

    private final DynamoDbTable<Order> table;
    private final DynamoDbIndex<Order> gsi1;

    public OrderRepository(DynamoDbEnhancedClient client) {
        this.table = client.table("ecommerce", TableSchema.fromBean(Order.class));
        this.gsi1 = table.index("GSI1");
    }

    // Get single order
    public Optional<Order> getOrder(String orderId) {
        Key key = Key.builder()
            .partitionValue("ORDER#" + orderId)
            .sortValue("ORDER#" + orderId)
            .build();
        return Optional.ofNullable(table.getItem(key));
    }

    // List orders for a customer (paginated, sorted by date desc)
    public List<Order> getOrdersByCustomer(String customerId, String exclusiveStartKey) {
        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
            .queryConditional(QueryConditional.keyEqualTo(
                Key.builder().partitionValue("CUSTOMER#" + customerId).build()))
            .scanIndexForward(false)  // descending sort
            .limit(20)
            .build();

        return gsi1.query(request)
            .stream()
            .flatMap(page -> page.items().stream())
            .collect(Collectors.toList());
    }

    // Transactional write: create order + decrement inventory
    public void createOrderWithInventoryUpdate(Order order, String productId, int quantity) {
        TransactWriteItemsEnhancedRequest txRequest = TransactWriteItemsEnhancedRequest.builder()
            .addPutItem(table, TransactPutItemEnhancedRequest.builder(Order.class)
                .item(order)
                .conditionExpression(Expression.builder()
                    .expression("attribute_not_exists(PK)")
                    .build())
                .build())
            .addUpdateItem(/* inventory table */ table,
                TransactUpdateItemEnhancedRequest.builder(Order.class)
                    .item(buildInventoryUpdate(productId, quantity))
                    .conditionExpression(Expression.builder()
                        .expression("quantity >= :qty")
                        .expressionValues(Map.of(":qty",
                            AttributeValue.fromN(String.valueOf(quantity))))
                        .build())
                    .build())
            .build();

        // DynamoDbEnhancedClient handles transaction
        // client.transactWriteItems(txRequest);
    }

    // DynamoDB Streams processor (Lambda handler pattern)
    public void processStreamRecord(Map<String, Object> event) {
        List<Map<String, Object>> records = (List<Map<String, Object>>) event.get("Records");
        for (Map<String, Object> record : records) {
            String eventName = (String) record.get("eventName");
            Map<String, Object> dynamodb = (Map<String, Object>) record.get("dynamodb");

            switch (eventName) {
                case "INSERT":
                    handleNewOrder(dynamodb.get("NewImage"));
                    break;
                case "MODIFY":
                    handleOrderUpdate(dynamodb.get("OldImage"), dynamodb.get("NewImage"));
                    break;
                case "REMOVE":
                    handleOrderDelete(dynamodb.get("OldImage"));
                    break;
            }
        }
    }

    private void handleNewOrder(Object newImage) {
        // Trigger fulfillment, send confirmation email, update search index
    }

    private void handleOrderUpdate(Object oldImage, Object newImage) {
        // Detect status changes, notify customer
    }

    private void handleOrderDelete(Object oldImage) {
        // Audit log, cleanup
    }

    private Order buildInventoryUpdate(String productId, int quantity) {
        // Build inventory decrement item
        return new Order(); // simplified
    }
}

// Capacity planning utility
public class DynamoCapacityCalculator {

    /**
     * Calculate required RCUs for a given workload.
     * @param readsPerSecond  expected read operations per second
     * @param avgItemSizeKb   average item size in KB
     * @param strongConsistency whether strong consistency is required
     */
    public static int calculateRCU(int readsPerSecond, double avgItemSizeKb,
                                    boolean strongConsistency) {
        // Round up to nearest 4KB
        int roundedSizeKb = (int) Math.ceil(avgItemSizeKb / 4.0) * 4;
        int rcuPerRead = strongConsistency ? 1 : (int) Math.ceil(0.5);  // 0.5 for eventual
        return readsPerSecond * (roundedSizeKb / 4) * rcuPerRead;
    }

    public static int calculateWCU(int writesPerSecond, double avgItemSizeKb) {
        int roundedSizeKb = (int) Math.ceil(avgItemSizeKb);
        return writesPerSecond * roundedSizeKb;
    }
}
```

**Follow-up Questions:**
1. How do you handle DynamoDB hot partition problems when a single product goes viral?
2. What is the difference between optimistic locking with a version attribute and DynamoDB conditional expressions?
3. How would you migrate from a multi-table design to single-table design without downtime?

**Common Mistakes:**
- Using low-cardinality partition keys (e.g., `status` field) causing hot partitions.
- Forgetting that GSIs are eventually consistent — critical for financial read-after-write scenarios.
- Not accounting for GSI write costs when planning capacity (every write to a base table propagates to all GSIs).
- Using scan operations instead of designing proper access patterns upfront.

**Interview Traps:**
- "DynamoDB is just a key-value store" — it also supports rich query semantics via sort key range queries, filter expressions, and projection expressions.
- Confusing LSI (must be created at table creation, strong consistency possible) with GSI (can be added later, eventual consistency only).
- Assuming DynamoDB transactions are free — they cost 2x RCU/WCU.

**Quick Revision:** DynamoDB: partition key routes to shard, sort key enables range queries; LSIs share PK + strong consistency, GSIs are separate + eventual; single-table design models all entity access patterns in one table using PK/SK conventions and sparse GSIs.

---

### Topic 10: Cassandra Deep Dive

**Difficulty:** Hard | **Frequency:** High | **Companies:** Netflix, Apple, Instagram, Uber, Discord

**Q:** Explain Cassandra's ring architecture, how it achieves high availability, and how you would design a partition key for a time-series IoT sensor data workload.

**Short Answer:**
Cassandra uses a consistent hashing ring where each node owns a range of token values; data is replicated to N consecutive nodes on the ring, and the replication factor and consistency level together determine the availability/consistency trade-off. Gossip protocol disseminates node state across the cluster without a single coordinator. Partition key design is critical because all data for a partition key must fit on one node and be read/written atomically.

**Deep Explanation:**

**Ring Architecture:**
- The keyspace is a circular token space (typically -2^63 to 2^63-1 for Murmur3 partitioner).
- Each node is assigned one or more token ranges (vnodes/virtual nodes, typically 256 per node).
- Vnodes distribute data more evenly and simplify node addition/removal.
- The coordinator node (the node that received the client request) routes requests to the appropriate replica nodes.

**Replication Strategies:**
- **SimpleStrategy:** Replicas placed on next N nodes clockwise. Single datacenter only.
- **NetworkTopologyStrategy:** Specifies replica count per datacenter. Rack-aware placement.
- `CREATE KEYSPACE ks WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 3, 'dc2': 2};`

**Consistency Levels:**
- **ONE/TWO/THREE:** Specific replica count must acknowledge.
- **QUORUM:** (RF/2 + 1) replicas. LOCAL_QUORUM for multi-DC.
- **ALL:** All replicas must respond. Highest consistency, lowest availability.
- **ANY:** Even a hint counts. Lowest consistency, highest availability.
- Strong consistency: write CL + read CL > RF (e.g., QUORUM + QUORUM with RF=3).

**Gossip Protocol:**
- Each node gossips with 1–3 peers every second, exchanging endpoint state (status, load, schema version).
- Convergence is O(log N) rounds. All nodes learn about failures within seconds.
- `nodetool gossipinfo` shows gossip state; `nodetool status` shows ring topology.

**Compaction Strategies:**

| Strategy | Use Case | How It Works |
|---|---|---|
| STCS (Size-Tiered) | Write-heavy, few reads | Merges SSTables of similar size |
| LCS (Leveled) | Read-heavy, mixed | Maintains leveled structure, O(10) file count per level |
| TWCS (Time-Window) | Time-series, TTL | Groups SSTables by time window, drops entire windows on expiry |
| DTCS (Date-Tiered) | Legacy time-series | Precursor to TWCS |

**Tombstones:**
- Deletes in Cassandra write a tombstone marker rather than removing data immediately.
- Tombstones accumulate until gc_grace_seconds (default 10 days) expires, after which compaction removes them.
- Excessive tombstones cause read latency (Cassandra must scan past them).
- Mitigation: use TTL instead of explicit deletes where possible, tune gc_grace_seconds for short-lived data.

**Partition Key Design for IoT:**
- Bad: `sensor_id` alone — one sensor could generate billions of rows → partition overflow.
- Better: `(sensor_id, date)` — time-bucketed partition. Known partition size.
- Best: `(sensor_id, bucket)` where bucket = `floor(timestamp / BUCKET_SIZE)` — tunable bucket size.

**Real-World Example:**
Netflix uses Cassandra for viewing history. Partition key: `(account_id, content_type)`, clustering key: `(watched_at DESC)` for recent history queries. TWCS compaction drops old SSTables without tombstone overhead. 99th-percentile read latency < 1ms at 1M+ ops/sec globally.

**Code Example:**

```java
// Spring Data Cassandra — IoT sensor time-series

// Schema (CQL)
/*
CREATE TABLE sensor_readings (
    sensor_id   UUID,
    bucket      INT,           -- floor(epoch_seconds / 86400) = daily bucket
    recorded_at TIMESTAMP,
    temperature DOUBLE,
    humidity    DOUBLE,
    PRIMARY KEY ((sensor_id, bucket), recorded_at)
) WITH CLUSTERING ORDER BY (recorded_at DESC)
  AND compaction = {
      'class': 'TimeWindowCompactionStrategy',
      'compaction_window_unit': 'DAYS',
      'compaction_window_size': 1
  }
  AND default_time_to_live = 2592000;  -- 30 days TTL
*/

@Table("sensor_readings")
public class SensorReading {

    @PrimaryKeyClass
    public static class SensorReadingKey implements Serializable {
        @PrimaryKeyColumn(name = "sensor_id", ordinal = 0, type = PrimaryKeyType.PARTITIONED)
        private UUID sensorId;

        @PrimaryKeyColumn(name = "bucket", ordinal = 1, type = PrimaryKeyType.PARTITIONED)
        private int bucket;

        @PrimaryKeyColumn(name = "recorded_at", ordinal = 2,
                          type = PrimaryKeyType.CLUSTERED,
                          ordering = Ordering.DESCENDING)
        private Instant recordedAt;

        public SensorReadingKey(UUID sensorId, Instant recordedAt) {
            this.sensorId = sensorId;
            this.recordedAt = recordedAt;
            this.bucket = (int) (recordedAt.getEpochSecond() / 86400);
        }
        // getters/setters
    }

    @PrimaryKey
    private SensorReadingKey key;

    @Column("temperature")
    private double temperature;

    @Column("humidity")
    private double humidity;

    // getters/setters
}

@Repository
public interface SensorReadingRepository
        extends CassandraRepository<SensorReading, SensorReading.SensorReadingKey> {

    // Query recent readings within a time range (single partition = fast)
    @Query("SELECT * FROM sensor_readings WHERE sensor_id = ?0 AND bucket = ?1 " +
           "AND recorded_at >= ?2 AND recorded_at <= ?3")
    List<SensorReading> findByTimeRange(UUID sensorId, int bucket,
                                         Instant from, Instant to);

    // Multi-partition query for longer ranges (use ALLOW FILTERING cautiously)
    @Query("SELECT * FROM sensor_readings WHERE sensor_id = ?0 " +
           "AND bucket IN ?1 AND recorded_at >= ?2 LIMIT 1000")
    List<SensorReading> findAcrossBuckets(UUID sensorId, List<Integer> buckets, Instant from);
}

@Service
public class SensorService {

    private final SensorReadingRepository repository;
    private final CassandraOperations cassandraOps;

    // Batch insert for high-throughput ingestion
    public void bulkInsert(List<SensorReading> readings) {
        // Use unlogged batch for same-partition writes (logged batch is an anti-pattern)
        BatchStatements batch = BatchStatements.of(readings.stream()
            .map(r -> QueryBuilder.insertInto("sensor_readings")
                .value("sensor_id", r.getKey().getSensorId())
                .value("bucket", r.getKey().getBucket())
                .value("recorded_at", r.getKey().getRecordedAt())
                .value("temperature", r.getTemperature())
                .value("humidity", r.getHumidity())
                .build())
            .collect(Collectors.toList()));
        // cassandraOps.execute(batch);
    }

    // Query spanning multiple daily buckets
    public List<SensorReading> getReadingsForDateRange(UUID sensorId,
                                                         LocalDate startDate,
                                                         LocalDate endDate) {
        List<Integer> buckets = startDate.datesUntil(endDate.plusDays(1))
            .map(d -> (int) d.toEpochDay())
            .collect(Collectors.toList());

        return buckets.stream()
            .flatMap(bucket -> repository.findByTimeRange(
                sensorId, bucket,
                startDate.atStartOfDay().toInstant(ZoneOffset.UTC),
                endDate.atTime(23, 59, 59).toInstant(ZoneOffset.UTC)).stream())
            .collect(Collectors.toList());
    }
}

// Cassandra configuration with retry and load balancing policies
@Configuration
public class CassandraConfig extends AbstractCassandraConfiguration {

    @Override
    protected String getKeyspaceName() { return "iot_platform"; }

    @Bean
    public CqlSessionFactoryBean cassandraSession() {
        CqlSessionFactoryBean session = new CqlSessionFactoryBean();
        session.setContactPoints("cassandra-node1:9042,cassandra-node2:9042");
        session.setLocalDatacenter("dc1");
        session.setKeyspaceName(getKeyspaceName());
        // Driver handles retry, load balancing, and speculative execution
        // via application.conf (DataStax driver config)
        return session;
    }
}
```

**Follow-up Questions:**
1. How does Cassandra handle a node failure during a write with QUORUM consistency?
2. What is the difference between a logged batch and an unlogged batch, and when should you use each?
3. How would you perform a schema migration in a running Cassandra cluster without downtime?

**Common Mistakes:**
- Using logged batches for performance (they are for atomicity across partitions, not throughput; unlogged batches on a single partition are the performance tool).
- Designing wide rows without TTL or compaction strategy, leading to unbounded partition growth.
- Using secondary indexes (`CREATE INDEX`) on high-cardinality columns — Cassandra's secondary indexes are local to each node, causing full-cluster scatter-gather reads.
- Querying with `ALLOW FILTERING` in production — always a table scan on affected partitions.

**Interview Traps:**
- "Cassandra is AP" — partially true; consistency level is tunable. With ALL + RF=1 it is CP.
- Cassandra does not support JOINs or subqueries. Data must be denormalized.
- "Last Write Wins" conflict resolution uses client-provided timestamps, not server time. Clock skew matters.

**Quick Revision:** Cassandra: consistent hashing ring + vnodes for data distribution; gossip for failure detection; QUORUM reads+writes for tunable strong consistency; TWCS for time-series compaction; partition key must be high-cardinality and time-bucketed for IoT.

---

### Topic 11: MongoDB Deep Dive

**Difficulty:** Medium-Hard | **Frequency:** High | **Companies:** MongoDB, Lyft, Expedia, Bosch, Verizon

**Q:** Explain MongoDB's document model advantages, how the aggregation pipeline works, and how sharding with mongos differs from application-level sharding.

**Short Answer:**
MongoDB stores data as BSON documents (binary JSON), enabling flexible schemas and embedded sub-documents that eliminate JOIN overhead for co-located data. The aggregation pipeline processes documents through sequential stages (match, group, lookup, project) with server-side computation. Sharding in MongoDB is transparent to the application: mongos (query router) intercepts queries, consults the config server for chunk metadata, and routes to the appropriate shard replica sets.

**Deep Explanation:**

**Document Model:**
- Documents are BSON (Binary JSON) — supports rich types: Date, ObjectId, Decimal128, Binary, Array.
- Flexible schema: documents in the same collection can have different fields. Schema validation via JSON Schema optional.
- Embedding vs referencing: embed for 1:1 and 1:few with co-access patterns; reference (DBRef or manual) for 1:many and many:many.
- 16 MB document size limit. GridFS for larger files.

**Index Types:**

| Index Type | Use Case |
|---|---|
| Single Field | Equality and range queries on one field |
| Compound | Multi-field queries, covered indexes |
| Multikey | Array fields — one index entry per array element |
| Text | Full-text search (English stemming, stop words) |
| Geospatial 2dsphere | GeoJSON queries (near, within) |
| Hashed | Shard key with uniform distribution |
| Wildcard | Dynamic/unknown field schemas |
| TTL | Auto-expire documents (e.g., sessions, logs) |
| Partial | Index subset of documents meeting a filter expression |

**Aggregation Pipeline:**
Sequential stages, each transforming the document stream:
- `$match` — filter (uses indexes if first stage)
- `$group` — group by key + accumulators (`$sum`, `$avg`, `$push`, `$addToSet`)
- `$project` — reshape documents, add computed fields
- `$lookup` — left outer join to another collection
- `$unwind` — deconstruct array into individual documents
- `$sort` / `$limit` / `$skip` — ordering and pagination
- `$facet` — multiple pipelines in parallel for faceted search
- `$bucket` / `$bucketAuto` — histogram bucketing

**Replica Sets:**
- Primary handles all writes. Secondaries replicate via oplog (operations log — a capped collection).
- Elections: Raft-based. Majority vote required. Minimum 3 nodes (1 primary + 2 secondaries or 1 arbiter).
- Read preferences: `primary`, `primaryPreferred`, `secondary`, `secondaryPreferred`, `nearest`.
- `writeConcern: {w: "majority", j: true}` — written to majority + journaled before acknowledgment.
- Replica set lag monitoring: `rs.printReplicationInfo()`.

**Sharding Architecture:**
- **Shard:** Replica set holding a subset of data.
- **mongos:** Stateless query router. Application connects to mongos, not shards directly.
- **Config servers:** 3-node replica set storing chunk metadata (which shard owns which range).
- **Chunk:** 64 MB range of shard key values. Auto-split and auto-balance.
- Shard key strategies:
  - **Ranged:** Efficient range queries but susceptible to hot spots on monotonically increasing keys.
  - **Hashed:** Uniform distribution but range queries scatter across all shards.
  - **Zone sharding:** Pin data to specific shards by key range (multi-region, tiered storage).

**Real-World Example:**
An e-commerce product catalog: shard key `{category: 1, _id: "hashed"}` — zone sharding pins popular categories to high-memory shards. Aggregation pipeline computes "top 10 products by revenue in last 30 days" server-side, avoiding data transfer to application.

**Code Example:**

```java
// Spring Data MongoDB — aggregation pipeline and sharding config

@Document(collection = "orders")
public class Order {

    @Id
    private ObjectId id;

    @Field("customer_id")
    private String customerId;

    @Field("product_id")
    private String productId;

    @Field("category")
    private String category;

    @Field("amount")
    private BigDecimal amount;

    @Field("status")
    private String status;

    @Field("created_at")
    private LocalDateTime createdAt;

    // getters/setters
}

@Repository
public class OrderAnalyticsRepository {

    private final MongoTemplate mongoTemplate;

    public OrderAnalyticsRepository(MongoTemplate mongoTemplate) {
        this.mongoTemplate = mongoTemplate;
    }

    // Aggregation: top 10 products by revenue in last 30 days
    public List<ProductRevenue> getTopProductsByRevenue(int days) {
        LocalDateTime cutoff = LocalDateTime.now().minusDays(days);

        Aggregation aggregation = Aggregation.newAggregation(
            // Stage 1: filter — uses index on created_at + status
            Aggregation.match(Criteria.where("created_at").gte(cutoff)
                                      .and("status").is("COMPLETED")),

            // Stage 2: group by product, sum revenue
            Aggregation.group("product_id")
                       .sum("amount").as("totalRevenue")
                       .count().as("orderCount"),

            // Stage 3: sort by revenue descending
            Aggregation.sort(Sort.Direction.DESC, "totalRevenue"),

            // Stage 4: limit to top 10
            Aggregation.limit(10),

            // Stage 5: lookup product details
            Aggregation.lookup("products", "_id", "_id", "productDetails"),

            // Stage 6: unwind the joined array
            Aggregation.unwind("productDetails"),

            // Stage 7: project final shape
            Aggregation.project("totalRevenue", "orderCount")
                       .and("productDetails.name").as("productName")
                       .and("productDetails.category").as("category")
        );

        AggregationResults<ProductRevenue> results =
            mongoTemplate.aggregate(aggregation, "orders", ProductRevenue.class);

        return results.getMappedResults();
    }

    // Aggregation: revenue by category per month (faceted analytics)
    public List<CategoryMonthlyRevenue> getRevenueByCategoryMonth(int year) {
        Aggregation aggregation = Aggregation.newAggregation(
            Aggregation.match(Criteria.where("created_at")
                .gte(LocalDateTime.of(year, 1, 1, 0, 0))
                .lt(LocalDateTime.of(year + 1, 1, 1, 0, 0))),

            Aggregation.project("category", "amount")
                .andExpression("month(created_at)").as("month"),

            Aggregation.group(Fields.fields("category", "month"))
                       .sum("amount").as("revenue"),

            Aggregation.sort(Sort.by("_id.category", "_id.month"))
        );

        return mongoTemplate.aggregate(aggregation, "orders",
                                        CategoryMonthlyRevenue.class)
                            .getMappedResults();
    }

    // Change Streams (MongoDB equivalent of DynamoDB Streams / Kafka CDC)
    public void watchOrderChanges() {
        List<Bson> pipeline = List.of(
            Aggregates.match(Filters.in("operationType", List.of("insert", "update")))
        );

        // Non-blocking reactive change stream
        mongoTemplate.getCollection("orders")
            .watch(pipeline)
            .forEach(event -> {
                String opType = event.getOperationType().getValue();
                Document fullDoc = event.getFullDocument();
                // Process change event
                System.out.printf("Operation: %s, Document: %s%n", opType, fullDoc);
            });
    }
}

// Repository with Spring Data MongoDB
@Repository
public interface OrderRepository extends MongoRepository<Order, ObjectId> {

    // Uses compound index on (customer_id, created_at)
    List<Order> findByCustomerIdOrderByCreatedAtDesc(String customerId);

    // Partial index query — only completed orders (partial index: {status: "COMPLETED"})
    @Query("{'status': 'COMPLETED', 'amount': {$gte: ?0}}")
    List<Order> findHighValueCompletedOrders(BigDecimal minAmount);

    // Geospatial query — find orders from users near a location
    @Query("{'location': {$near: {$geometry: {type: 'Point', coordinates: [?0, ?1]}, $maxDistance: ?2}}}")
    List<Order> findNearLocation(double longitude, double latitude, double maxDistanceMeters);
}

// Index creation
@Configuration
public class MongoIndexConfig {

    @Bean
    public MongoCustomConversions mongoCustomConversions() {
        return new MongoCustomConversions(Collections.emptyList());
    }

    // Programmatic index creation
    @EventListener(ApplicationReadyEvent.class)
    public void initIndexes(ApplicationReadyEvent event) {
        MongoTemplate mongoTemplate = event.getApplicationContext()
                                          .getBean(MongoTemplate.class);

        // Compound index for common query pattern
        mongoTemplate.indexOps("orders").ensureIndex(
            new Index()
                .on("customer_id", Sort.Direction.ASC)
                .on("created_at", Sort.Direction.DESC)
                .named("customer_created_compound")
        );

        // TTL index for session expiry
        mongoTemplate.indexOps("sessions").ensureIndex(
            new Index()
                .on("expires_at", Sort.Direction.ASC)
                .expire(0)  // expire at the time specified in the field
                .named("session_ttl")
        );

        // Partial index — only index active products
        mongoTemplate.indexOps("products").ensureIndex(
            new CompoundIndexDefinition(
                new org.bson.Document("category", 1).append("price", 1))
                .named("active_category_price")
                .partial(PartialIndexFilter.of(Criteria.where("active").is(true)))
        );
    }
}
```

**Follow-up Questions:**
1. How does MongoDB's WiredTiger storage engine handle concurrent reads and writes differently from the old MMAPv1 engine?
2. What are the trade-offs of embedding vs referencing documents, and how do access patterns influence this decision?
3. How does MongoDB handle a mongos router failure in a sharded cluster?

**Common Mistakes:**
- Choosing a monotonically increasing shard key (e.g., ObjectId, timestamp) with ranged sharding — all writes go to the last chunk (hot spot).
- Using `$lookup` (server-side join) across shards — cross-shard lookups do not use indexes on the joined collection.
- Neglecting `writeConcern` defaults — MongoDB 5.0+ defaults to `w: majority`, but older versions default to `w: 1` (not durable across replica failover).
- Not capping pipeline memory — aggregation stages default to 100 MB RAM limit; use `allowDiskUse: true` for large datasets.

**Interview Traps:**
- MongoDB is not ACID — False. Since 4.0, multi-document transactions with ACID guarantees are supported (but expensive; prefer single-document atomicity when possible).
- "Schema-less means no schema" — MongoDB should have an implicit or explicit schema (JSON Schema validation) to avoid data quality issues.

**Quick Revision:** MongoDB: BSON documents with flexible schema; aggregation pipeline for server-side analytics; replica set oplog for replication; mongos routes sharded queries transparently; choose hashed shard key for write distribution, ranged for range query efficiency.

---

### Topic 12: Time-Series Databases

**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Datadog, InfluxData, Timescale, AWS, Azure, Google

**Q:** What makes time-series data special, and how do databases like InfluxDB and TimescaleDB handle retention policies and downsampling differently from general-purpose databases?

**Short Answer:**
Time-series data is append-only, high-frequency, and queried as recent-first ranges or aggregated over time windows — patterns that general-purpose databases handle inefficiently due to index overhead and lack of native time-bucketing. InfluxDB stores data in time-ordered TSM (Time-Structured Merge Tree) files optimized for high write throughput and column compression, while TimescaleDB extends PostgreSQL with automatic hypertable partitioning (chunks) on the time dimension, enabling familiar SQL alongside time-series optimizations.

**Deep Explanation:**

**Time-Series Data Characteristics:**
- **Append-mostly:** Inserts dominate; updates and deletes are rare (only for late-arriving data corrections).
- **High cardinality:** Many independent series (e.g., one per device × metric × tag combination).
- **Temporal locality:** Recent data is accessed far more frequently than old data.
- **Regular intervals:** Lends itself to column-store compression (delta encoding, run-length encoding, Gorilla float compression).
- **Time-range queries:** "Give me CPU usage for host A between 14:00 and 15:00" is the dominant pattern.

**InfluxDB Architecture:**
- **Line Protocol:** `measurement,tag1=v1,tag2=v2 field1=1.5,field2=2.0 1694000000000000000`
- **TSM (Time-Structured Merge Tree):** Like LSM but optimized for time. Data organized by measurement + tag set. WAL + in-memory cache + TSM files.
- **Series:** Unique combination of measurement + tag set. High cardinality of series (millions) can cause memory issues (series index).
- **Retention Policies (InfluxDB 1.x) / Buckets (InfluxDB 2.x):** Define how long data is stored. Data outside retention window is dropped at shard group boundaries (not row-by-row).
- **Continuous Queries (1.x) / Tasks (2.x):** Schedule downsampling: aggregate raw 1-second data into 1-minute summaries, store in a separate bucket with longer retention.

**TimescaleDB Architecture:**
- PostgreSQL extension — full SQL, all PostgreSQL indexes, foreign keys, JOINs.
- **Hypertable:** A PostgreSQL table that is automatically partitioned into "chunks" by time (and optionally by space/hash).
- **Chunk:** A regular PostgreSQL table. Old chunks can be compressed, tiered to object storage, or dropped.
- **Continuous Aggregates:** Materialized views that incrementally refresh as new data arrives. SQL-defined downsampling.
- **Compression:** Column-oriented storage within chunks. 10–20x compression typical. Compressed chunks are read-only.

**Downsampling:**
Converting high-resolution raw data to lower-resolution summaries (e.g., 1s → 1m → 1h → 1d) to:
1. Reduce storage cost.
2. Speed up long-range queries.
3. Enforce retention policies (keep 1d raw, 30d 1m, 1y 1h, forever 1d).

**Real-World Example:**
Datadog ingests 10 trillion data points per day. InfluxDB (Gorilla compression + TSM) stores raw metrics for 15 days. A continuous task downsamples to 1-minute averages stored for 90 days, and 1-hour P95 values stored for 2 years. The monitoring dashboard queries the appropriate resolution tier based on the time range selected.

**Code Example:**

```java
// Spring Boot + TimescaleDB (via Spring Data JPA + JDBC)

// TimescaleDB Hypertable setup (executed via Flyway migration)
/*
-- V1__create_metrics_hypertable.sql
CREATE TABLE sensor_metrics (
    time        TIMESTAMPTZ NOT NULL,
    sensor_id   UUID        NOT NULL,
    metric_name TEXT        NOT NULL,
    value       DOUBLE PRECISION NOT NULL,
    tags        JSONB
);

-- Convert to hypertable, partition by time with 1-day chunks
SELECT create_hypertable('sensor_metrics', 'time',
                          chunk_time_interval => INTERVAL '1 day');

-- Composite index for common query pattern
CREATE INDEX ON sensor_metrics (sensor_id, time DESC);

-- Enable compression on chunks older than 7 days
ALTER TABLE sensor_metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sensor_id, metric_name',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('sensor_metrics', INTERVAL '7 days');

-- Auto-drop chunks older than 90 days
SELECT add_retention_policy('sensor_metrics', INTERVAL '90 days');

-- Continuous aggregate: 1-minute averages
CREATE MATERIALIZED VIEW sensor_metrics_1min
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 minute', time) AS bucket,
    sensor_id,
    metric_name,
    AVG(value)  AS avg_value,
    MIN(value)  AS min_value,
    MAX(value)  AS max_value,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY value) AS p95_value,
    COUNT(*)    AS sample_count
FROM sensor_metrics
GROUP BY bucket, sensor_id, metric_name;

SELECT add_continuous_aggregate_policy('sensor_metrics_1min',
    start_offset => INTERVAL '1 hour',
    end_offset   => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute');
*/

// Java entity and repository
@Entity
@Table(name = "sensor_metrics")
public class SensorMetric {

    @Id
    @Column(name = "time")
    private OffsetDateTime time;

    @Column(name = "sensor_id")
    private UUID sensorId;

    @Column(name = "metric_name")
    private String metricName;

    @Column(name = "value")
    private double value;

    @Type(JsonBinaryType.class)
    @Column(name = "tags", columnDefinition = "jsonb")
    private Map<String, String> tags;

    // getters/setters
}

@Repository
public class MetricsRepository {

    private final JdbcTemplate jdbcTemplate;
    private final NamedParameterJdbcTemplate namedJdbc;

    // Time-bucketed query using time_bucket() function
    public List<MetricBucket> getMinuteAverages(UUID sensorId, String metric,
                                                  OffsetDateTime from, OffsetDateTime to) {
        String sql = """
            SELECT
                time_bucket('1 minute', time) AS bucket,
                AVG(value) AS avg_value,
                MIN(value) AS min_value,
                MAX(value) AS max_value
            FROM sensor_metrics
            WHERE sensor_id = :sensorId
              AND metric_name = :metric
              AND time BETWEEN :from AND :to
            GROUP BY bucket
            ORDER BY bucket ASC
            """;

        MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("sensorId", sensorId)
            .addValue("metric", metric)
            .addValue("from", from)
            .addValue("to", to);

        return namedJdbc.query(sql, params, (rs, rowNum) -> new MetricBucket(
            rs.getObject("bucket", OffsetDateTime.class),
            rs.getDouble("avg_value"),
            rs.getDouble("min_value"),
            rs.getDouble("max_value")
        ));
    }

    // Batch insert using COPY protocol (high throughput)
    public void bulkInsert(List<SensorMetric> metrics) {
        jdbcTemplate.batchUpdate(
            "INSERT INTO sensor_metrics (time, sensor_id, metric_name, value, tags) " +
            "VALUES (?, ?, ?, ?, ?::jsonb) ON CONFLICT DO NOTHING",
            metrics.stream()
                .map(m -> new Object[]{
                    m.getTime(), m.getSensorId(), m.getMetricName(),
                    m.getValue(), toJsonString(m.getTags())
                })
                .collect(Collectors.toList())
        );
    }

    // Query the continuous aggregate for fast dashboard rendering
    public List<MetricBucket> getDashboardData(UUID sensorId, String metric,
                                                 OffsetDateTime from, OffsetDateTime to) {
        // For ranges > 1 hour, query the 1-min aggregate instead of raw data
        Duration range = Duration.between(from, to);
        String table = range.toHours() > 1 ? "sensor_metrics_1min" : "sensor_metrics";

        if ("sensor_metrics_1min".equals(table)) {
            String sql = """
                SELECT bucket, avg_value, min_value, max_value
                FROM sensor_metrics_1min
                WHERE sensor_id = :sensorId
                  AND metric_name = :metric
                  AND bucket BETWEEN :from AND :to
                ORDER BY bucket ASC
                """;
            // execute and return
        }

        return getMinuteAverages(sensorId, metric, from, to);
    }

    private String toJsonString(Map<String, String> tags) {
        try {
            return new ObjectMapper().writeValueAsString(tags);
        } catch (Exception e) { return "{}"; }
    }
}

// InfluxDB 2.x client (Spring Boot integration)
@Service
public class InfluxMetricsService {

    private final InfluxDBClient influxClient;
    private final WriteApiBlocking writeApi;
    private final QueryApi queryApi;

    public InfluxMetricsService(InfluxDBClient influxClient) {
        this.influxClient = influxClient;
        this.writeApi = influxClient.getWriteApiBlocking();
        this.queryApi = influxClient.getQueryApi();
    }

    public void writeSensorReading(UUID sensorId, String metric,
                                    double value, Map<String, String> tags) {
        Point point = Point.measurement("sensor_readings")
            .addTag("sensor_id", sensorId.toString())
            .addTag("metric", metric)
            .addTags(tags)
            .addField("value", value)
            .time(Instant.now(), WritePrecision.NS);

        writeApi.writePoint("my-bucket", "my-org", point);
    }

    public List<FluxRecord> queryLastHour(String sensorId, String metric) {
        String flux = String.format("""
            from(bucket: "my-bucket")
              |> range(start: -1h)
              |> filter(fn: (r) => r._measurement == "sensor_readings")
              |> filter(fn: (r) => r.sensor_id == "%s")
              |> filter(fn: (r) => r.metric == "%s")
              |> aggregateWindow(every: 1m, fn: mean, createEmpty: false)
              |> yield(name: "mean")
            """, sensorId, metric);

        return queryApi.query(flux, "my-org").stream()
            .flatMap(table -> table.getRecords().stream())
            .collect(Collectors.toList());
    }
}
```

**Follow-up Questions:**
1. How does TimescaleDB's chunk exclusion work, and why is it important for query performance?
2. What is the "high cardinality problem" in InfluxDB, and how do you mitigate it in tag design?
3. How would you handle late-arriving data (out-of-order writes) in a time-series database?

**Common Mistakes:**
- Treating timestamps as strings rather than native timestamp types — loses index efficiency and timezone handling.
- Storing too many unique tag values in InfluxDB (e.g., user_id as a tag) — creates a new series per user, blowing up the series cardinality.
- Not planning downsampling strategy upfront — trying to add continuous aggregates retroactively requires backfilling.
- Using raw-data table for long-range dashboard queries (weeks/months) when continuous aggregates would be 100x faster.

**Interview Traps:**
- TimescaleDB is not a separate database — it is a PostgreSQL extension. You get full SQL, foreign keys, and JOINs.
- InfluxDB 2.x (Flux query language) is very different from InfluxDB 1.x (InfluxQL). Know which version is in use.

**Quick Revision:** Time-series DBs: optimized for append-heavy, time-ordered data; InfluxDB uses TSM column storage + retention policies + continuous tasks for downsampling; TimescaleDB uses PostgreSQL hypertable chunks + continuous aggregates + compression policies — full SQL with time-series superpowers.

---

### Topic 13: Full-Text Search with Elasticsearch

**Difficulty:** Hard | **Frequency:** High | **Companies:** Elastic, Uber, LinkedIn, GitHub, Netflix, Shopify

**Q:** Explain Elasticsearch's shard and segment architecture, how the inverted index enables relevance scoring, and how you would integrate Elasticsearch with a Spring Boot application.

**Short Answer:**
Elasticsearch distributes data across shards (each a self-contained Lucene index); each shard contains multiple immutable segments which are the unit of the inverted index. The inverted index maps terms to posting lists (document IDs + term frequencies + positions), enabling O(1) term lookup. BM25 scoring computes relevance using term frequency, inverse document frequency, and field length normalization to rank results.

**Deep Explanation:**

**Architecture:**

```
Cluster
├── Node 1 (Master-eligible, Data)
│   ├── Shard P0 (Primary)   — Lucene Index
│   │   ├── Segment 1 (immutable)
│   │   ├── Segment 2 (immutable)
│   │   └── In-memory buffer → flush → new segment
│   └── Shard R1 (Replica of P1)
├── Node 2 (Data)
│   ├── Shard P1 (Primary)
│   └── Shard R0 (Replica of P0)
└── Node 3 (Master-eligible, Data)
    └── Shard P2, R2...
```

**Index vs Shard vs Segment:**
- **Index:** Logical namespace. Backed by multiple shards.
- **Shard:** Lucene index. Primary shard count is fixed at index creation (cannot change without reindexing). Replica shards can be added/removed live.
- **Segment:** Immutable unit within a Lucene index. Writes buffer in memory, flush creates a new segment. Segment merge (background) reclaims space from deleted documents. Forcing a merge reduces segment count, improving read performance.
- **Refresh:** Makes in-memory data searchable (creates new segment). Default: 1 second. `refresh_interval: -1` during bulk indexing.
- **Flush:** Writes memory buffer + translog to a new Lucene commit point (durable). Default: every 30 minutes or when translog exceeds 512 MB.

**Inverted Index:**
```
Term       → Document IDs (posting list)   + TF    + Positions
"java"     → [doc1(tf:3), doc4(tf:1)]       ...     [doc1: [2,8,15]]
"spring"   → [doc1(tf:2), doc2(tf:5)]       ...
"microservice" → [doc1(tf:1), doc3(tf:2)]   ...
```

**BM25 Relevance Scoring (default since ES 5.0):**
- `score(q, d) = IDF(t) × (TF(t,d) × (k1+1)) / (TF(t,d) + k1 × (1 - b + b × |d|/avgdl))`
- IDF penalizes common terms ("the", "a"); TF rewards documents with more occurrences; field length normalization (`b` parameter) penalizes longer documents.
- Boosting: multiply scores at query time (`^2`), index time (field mapping `boost`), or function score query (custom formula).

**Analyzers:**
- Text analysis pipeline: character filter → tokenizer → token filter.
- Standard analyzer: lowercase + stop words + unicode normalization.
- Custom: `edge_ngram` for autocomplete, `keyword` for exact match, `icu_analyzer` for multilingual.

**Query DSL Types:**
- **Full-text:** `match`, `match_phrase`, `multi_match`, `query_string`
- **Term-level:** `term`, `terms`, `range`, `exists`, `prefix`, `wildcard`, `regexp`
- **Compound:** `bool` (must/should/must_not/filter), `dis_max`, `function_score`
- **Geo:** `geo_distance`, `geo_bounding_box`
- **Aggregations:** `terms`, `date_histogram`, `range`, `avg`, `percentiles`, `nested`

**Real-World Example:**
GitHub's code search uses Elasticsearch for full-text search across 10+ billion files. Shard count is set at 5 per index; indices are rolled over (index lifecycle management — ILM) monthly. Custom analyzers handle language-specific tokenization. `function_score` boosts results from popular repositories.

**Code Example:**

```java
// Spring Data Elasticsearch + Spring Boot

// Entity mapping
@Document(indexName = "products")
@Setting(settingPath = "elasticsearch/product-settings.json")
@Mapping(mappingPath = "elasticsearch/product-mapping.json")
public class ProductDocument {

    @Id
    private String id;

    @Field(type = FieldType.Text, analyzer = "english")
    private String name;

    @Field(type = FieldType.Text, analyzer = "english")
    private String description;

    @Field(type = FieldType.Keyword)
    private String category;

    @Field(type = FieldType.Double)
    private double price;

    @Field(type = FieldType.Double)
    private double rating;

    @Field(type = FieldType.Integer)
    private int reviewCount;

    @Field(type = FieldType.Keyword)
    private List<String> tags;

    @Field(type = FieldType.Date, format = DateFormat.date_time)
    private LocalDateTime createdAt;

    // Nested objects for complex queries
    @Field(type = FieldType.Nested)
    private List<ProductVariant> variants;

    // getters/setters
}

// product-settings.json (analyzer configuration)
/*
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "refresh_interval": "1s",
    "analysis": {
      "filter": {
        "autocomplete_filter": {
          "type": "edge_ngram",
          "min_gram": 2,
          "max_gram": 20
        }
      },
      "analyzer": {
        "autocomplete": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "autocomplete_filter"]
        },
        "autocomplete_search": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase"]
        }
      }
    }
  }
}
*/

@Repository
public interface ProductSearchRepository
        extends ElasticsearchRepository<ProductDocument, String> {

    // Spring Data method derivation
    List<ProductDocument> findByCategory(String category);
    Page<ProductDocument> findByPriceBetween(double min, double max, Pageable pageable);
}

@Service
public class ProductSearchService {

    private final ElasticsearchOperations esOps;
    private final ProductSearchRepository repository;

    public ProductSearchService(ElasticsearchOperations esOps,
                                  ProductSearchRepository repository) {
        this.esOps = esOps;
        this.repository = repository;
    }

    // Full-text search with boosting and filtering
    public SearchHits<ProductDocument> search(String query, String category,
                                               Double minPrice, Double maxPrice,
                                               int page, int size) {
        // Full-text match on name (boosted) and description
        Query textQuery = NativeQuery.builder()
            .withQuery(q -> q
                .bool(b -> {
                    // Must: text relevance
                    b.must(m -> m.multiMatch(mm -> mm
                        .query(query)
                        .fields(List.of("name^3", "description^1", "tags^2"))
                        .type(TextQueryType.BestFields)
                        .fuzziness("AUTO")
                    ));

                    // Filter: exact matches, no scoring impact
                    if (category != null) {
                        b.filter(f -> f.term(t -> t.field("category").value(category)));
                    }
                    if (minPrice != null) {
                        b.filter(f -> f.range(r -> r.field("price").gte(JsonData.of(minPrice))));
                    }
                    if (maxPrice != null) {
                        b.filter(f -> f.range(r -> r.field("price").lte(JsonData.of(maxPrice))));
                    }

                    return b;
                })
            )
            // Function score: boost high-rated, popular products
            .withQuery(q -> q
                .functionScore(fs -> fs
                    .functions(
                        FunctionScore.of(f -> f
                            .fieldValueFactor(fvf -> fvf
                                .field("rating")
                                .factor(1.2)
                                .modifier(FieldValueFactorModifier.Sqrt)
                                .missing(1.0)
                            )
                        )
                    )
                    .boostMode(FunctionBoostMode.Multiply)
                )
            )
            .withPageable(PageRequest.of(page, size))
            .withSort(Sort.by(Sort.Direction.DESC, "_score"))
            .withHighlightQuery(HighlightQuery.of(h -> h
                .fields("name", "description")
                .preTags("<em>")
                .postTags("</em>")
            ))
            .build();

        return esOps.search(textQuery, ProductDocument.class);
    }

    // Aggregation for faceted search
    public Map<String, List<BucketResult>> getFacets(String query) {
        NativeQuery nativeQuery = NativeQuery.builder()
            .withQuery(q -> q.match(m -> m.field("name").query(query)))
            .withAggregation("by_category", Aggregation.of(a -> a
                .terms(t -> t.field("category").size(20))
            ))
            .withAggregation("price_ranges", Aggregation.of(a -> a
                .range(r -> r
                    .field("price")
                    .ranges(
                        AggregationRange.of(ar -> ar.to(50.0)),
                        AggregationRange.of(ar -> ar.from(50.0).to(200.0)),
                        AggregationRange.of(ar -> ar.from(200.0))
                    )
                )
            ))
            .build();

        SearchHits<ProductDocument> hits = esOps.search(nativeQuery, ProductDocument.class);
        // Extract aggregation results from hits.getAggregations()
        return Map.of(); // simplified
    }

    // Bulk indexing for initial load / reindexing
    public void bulkIndex(List<ProductDocument> products) {
        // Disable refresh during bulk load for performance
        IndexOperations indexOps = esOps.indexOps(ProductDocument.class);

        List<IndexQuery> queries = products.stream()
            .map(p -> new IndexQueryBuilder()
                .withId(p.getId())
                .withObject(p)
                .build())
            .collect(Collectors.toList());

        esOps.bulkIndex(queries, ProductDocument.class);
        indexOps.refresh();  // manual refresh after bulk
    }

    // Index lifecycle management (ILM) — rolling indices for logs
    public void setupILMPolicy() {
        // Typically done via Kibana or REST API during cluster setup
        // Roll over when index > 50GB or > 30 days old
        // Hot → Warm (force merge, shrink) → Cold (freeze) → Delete
    }
}
```

**Follow-up Questions:**
1. How would you handle a near-real-time search requirement where documents must be searchable within 100ms of creation, while also minimizing segment proliferation?
2. What is the difference between `query` context and `filter` context in Elasticsearch, and why does it matter for performance?
3. How do you perform a zero-downtime reindex when you need to change a field's mapping (e.g., keyword to text)?

**Common Mistakes:**
- Using `_all` field queries instead of `multi_match` (deprecated and removed in ES 7.0).
- Setting too many shards at index creation — more shards = more overhead per query (scatter-gather). Rule of thumb: 20-40 GB per shard.
- Ignoring `filter` context — filters are cached and do not compute scores; using `must` for non-text filters wastes CPU.
- Not using `_bulk` API for large indexing jobs — individual index requests have 10x the overhead.
- Using wildcard queries on un-analyzed keyword fields for large datasets — full-scan of the posting list.

**Interview Traps:**
- Elasticsearch is not a primary database — it should be treated as a search replica with eventual consistency from the primary store (CDC pattern).
- Split-brain prevention: since ES 7.0, Zen2 discovery (Raft-based) prevents split-brain by requiring majority quorum for master election. The `minimum_master_nodes` setting from 6.x is gone.

**Quick Revision:** Elasticsearch: inverted index in immutable segments per Lucene shard; BM25 relevance scoring; `filter` context is cached + no scoring; use `bool` query for compound logic; bulk API for indexing; ILM for index lifecycle management; treat ES as a search projection, not a source of truth.

---

### Topic 14: Database Migration Strategies

**Difficulty:** Medium | **Frequency:** High | **Companies:** All (critical production engineering skill)

**Q:** Compare Flyway and Liquibase for schema migration management, and explain the expand-contract pattern for zero-downtime migrations.

**Short Answer:**
Flyway uses versioned SQL scripts applied in order with a checksum validation to prevent modification; Liquibase uses an XML/YAML/JSON changelog with more flexibility (rollback support, database-agnostic abstractions). The expand-contract pattern (also called parallel-change) is the key technique for zero-downtime migrations: first expand the schema to be backward-compatible with both old and new code, deploy new code, then contract by removing the old schema once no code references it.

**Deep Explanation:**

**Flyway:**
- Versioned migrations: `V1__Create_users.sql`, `V2__Add_email_index.sql`.
- Repeatable migrations: `R__Create_views.sql` (re-runs when content changes).
- Undo migrations (Flyway Teams): `U2__Undo_email_index.sql`.
- Checksums prevent modification of applied migrations (fail-fast on tampering).
- Baseline: marks an existing schema as already at a given version.
- Repair: fixes failed migrations by removing failed entries from `flyway_schema_history`.
- Spring Boot auto-configuration: `spring.flyway.enabled=true`, scripts in `classpath:db/migration`.

**Liquibase:**
- Changesets: individual units of change with `author` + `id` attributes.
- Changelogs: master changelog references other changelog files.
- `preconditions`: run changeset only if condition met (e.g., table does not exist).
- Built-in rollback: `<rollback>` tag per changeset; `liquibase rollbackCount 1`.
- Database-agnostic: `createTable`, `addColumn`, `createIndex` generate appropriate DDL per database.
- Spring Boot: `spring.liquibase.change-log=classpath:db/changelog/db.changelog-master.yaml`.

**Comparison:**

| Feature | Flyway | Liquibase |
|---|---|---|
| Primary format | SQL | XML/YAML/JSON/SQL |
| Rollback support | Manual (Undo migrations, Teams only) | Built-in per changeset |
| Database abstraction | SQL dialect variants | Full abstraction layer |
| Learning curve | Low | Medium |
| Flexibility | Lower (SQL only for complex ops) | Higher (changesets + preconditions) |
| Community | Large | Large |
| Best for | SQL-first teams, simple workflows | Complex multi-DB, enterprise rollbacks |

**Expand-Contract Pattern (Zero-Downtime Migrations):**

The pattern consists of three phases:

**Phase 1: Expand**
- Add new column/table/index alongside the old one.
- New column is nullable (or has a default) so existing code can still insert without providing it.
- New code writes to both old and new columns.

**Phase 2: Migrate + Transition**
- Backfill new column from old: `UPDATE table SET new_col = transform(old_col) WHERE new_col IS NULL`.
- Deploy new application version that reads from new column, writes to both.
- Verify: confirm new column is fully populated and correct.

**Phase 3: Contract**
- Once all application instances read from the new column and no code touches the old column, drop the old column.
- This is a separate migration deployed after confirming no rollback to old code is needed.

**Common Zero-Downtime Migration Scenarios:**

1. **Rename a column:** Add new column → backfill → dual-write → switch reads → drop old column.
2. **Change column type:** Add new typed column → backfill with cast → switch → drop old.
3. **Add NOT NULL constraint:** Add column as nullable → backfill → add `CHECK (col IS NOT NULL)` → `ALTER COLUMN SET NOT NULL` (validates inline on Postgres 12+ with NOT VALID then VALIDATE CONSTRAINT).
4. **Add index:** `CREATE INDEX CONCURRENTLY` — non-blocking on PostgreSQL (cannot be in a transaction).
5. **Split a table:** Add new table → dual-write → backfill → switch reads → remove writes to old table → drop old table.

**Real-World Example:**
At a fintech startup, renaming `user.phone` to `user.phone_number` without downtime: add `phone_number` column (V5 migration), deploy v2 app writing both columns, run backfill job for existing rows, verify 100% populated, deploy v2.1 reading from `phone_number`, wait 1 week, deploy V6 migration dropping `phone`.

**Code Example:**

```java
// Flyway versioned migration examples

// V1__Create_users_table.sql
/*
CREATE TABLE users (
    id          BIGSERIAL PRIMARY KEY,
    username    VARCHAR(50)  NOT NULL UNIQUE,
    email       VARCHAR(255) NOT NULL,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_users_email ON users(email);
*/

// V2__Add_phone_column.sql  (EXPAND phase - backward compatible)
/*
ALTER TABLE users ADD COLUMN phone VARCHAR(20);  -- nullable, old app still works
*/

// V3__Backfill_phone_from_contact.sql  (MIGRATE phase)
/*
-- Backfill from a contacts table migration
UPDATE users u
SET phone = c.phone_number
FROM contacts c
WHERE c.user_id = u.id
  AND u.phone IS NULL;
*/

// V4__Add_phone_not_null_constraint.sql  (phase 2 of EXPAND - after backfill)
/*
-- Add NOT VALID first (does not scan existing rows, fast)
ALTER TABLE users ADD CONSTRAINT users_phone_not_null
    CHECK (phone IS NOT NULL) NOT VALID;

-- Validate separately (can be interrupted, no full table lock in Postgres 12+)
ALTER TABLE users VALIDATE CONSTRAINT users_phone_not_null;
*/

// V5__Create_index_concurrently.sql  (cannot be in transaction, use Flyway's outOfOrder or separate)
/*
-- Note: Flyway wraps migrations in transactions by default.
-- For CONCURRENTLY, use: spring.flyway.mixed=true or split to separate migration
-- with executeInTransaction=false annotation.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_phone ON users(phone);
*/

// Flyway Java migration for CONCURRENTLY (must disable transaction wrapping)
@Component
public class V5__Create_phone_index_concurrently implements JavaMigration {

    @Override
    public MigrationVersion getVersion() {
        return MigrationVersion.fromVersion("5");
    }

    @Override
    public String getDescription() {
        return "Create phone index concurrently";
    }

    @Override
    public boolean canExecuteInTransaction() {
        return false;  // CONCURRENTLY cannot run inside a transaction
    }

    @Override
    public void migrate(Context context) throws Exception {
        try (Statement stmt = context.getConnection().createStatement()) {
            stmt.execute(
                "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_phone ON users(phone)"
            );
        }
    }
}

// Liquibase YAML changelog example
/*
# db/changelog/003-expand-phone-column.yaml
databaseChangeLog:
  - changeSet:
      id: 003-add-phone-number-column
      author: prince.singh
      preConditions:
        onFail: MARK_RAN
        - not:
            columnExists:
              tableName: users
              columnName: phone_number
      changes:
        - addColumn:
            tableName: users
            columns:
              - column:
                  name: phone_number
                  type: VARCHAR(20)
                  constraints:
                    nullable: true
      rollback:
        - dropColumn:
            tableName: users
            columnName: phone_number

  - changeSet:
      id: 004-backfill-phone-number
      author: prince.singh
      runOnChange: false
      changes:
        - sql:
            sql: >
              UPDATE users SET phone_number = phone WHERE phone_number IS NULL AND phone IS NOT NULL
        - sql:
            sql: >
              UPDATE users SET phone_number = 'UNKNOWN' WHERE phone_number IS NULL
      rollback:
        - sql:
            sql: UPDATE users SET phone_number = NULL
*/

// Spring Boot migration configuration
@Configuration
public class MigrationConfig {

    // Flyway configuration with repair on checksum mismatch
    @Bean
    public FlywayMigrationInitializer flywayInitializer(Flyway flyway) {
        return new FlywayMigrationInitializer(flyway, f -> {
            FlywayMigrationStrategy strategy = applicationContext -> {
                // Repair before migrate to handle failed migrations
                f.repair();
                f.migrate();
            };
            strategy.migrate(f);
        });
    }
}

// application.yml
/*
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: false
    out-of-order: false
    validate-on-migrate: true
    # For teams: connect-retries for cloud DB startup lag
    connect-retries: 10
    connect-retries-interval: 3
*/

// Zero-downtime migration orchestration service
@Service
public class SchemaMigrationOrchestrator {

    private final JdbcTemplate jdbcTemplate;
    private final MeterRegistry meterRegistry;

    // Backfill with progress tracking and batching (avoid long-running transactions)
    public void backfillPhoneNumber(int batchSize) {
        int totalUpdated = 0;
        int updated;

        do {
            // Small batch — keeps transaction short, reduces lock contention
            updated = jdbcTemplate.update(
                "UPDATE users SET phone_number = phone " +
                "WHERE id IN (SELECT id FROM users WHERE phone_number IS NULL LIMIT ?)",
                batchSize
            );
            totalUpdated += updated;

            meterRegistry.counter("migration.backfill.rows",
                Tags.of("table", "users", "column", "phone_number"))
                .increment(updated);

            if (updated > 0) {
                try { Thread.sleep(10); }  // brief pause to reduce DB pressure
                catch (InterruptedException e) { Thread.currentThread().interrupt(); break; }
            }
        } while (updated > 0);

        log.info("Backfill complete. Total rows updated: {}", totalUpdated);
    }

    // Verify migration readiness before contracting (removing old column)
    public MigrationReadiness checkReadiness(String tableName, String newColumn) {
        Long nullCount = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM " + tableName + " WHERE " + newColumn + " IS NULL",
            Long.class);

        Long totalCount = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM " + tableName, Long.class);

        return new MigrationReadiness(
            nullCount == 0,
            totalCount,
            nullCount,
            (nullCount * 100.0) / Math.max(totalCount, 1) + "% null"
        );
    }
}
```

**Follow-up Questions:**
1. How would you handle a long-running backfill migration on a 500-million-row table without impacting production query performance?
2. What happens if a Flyway migration fails halfway through, and how do you recover?
3. How do you coordinate schema migrations with application deployments in a Kubernetes rolling update scenario?

**Common Mistakes:**
- Modifying already-applied Flyway migration scripts — Flyway detects the checksum change and fails.
- Adding `NOT NULL` constraint directly without `NOT VALID` + `VALIDATE CONSTRAINT` — causes full table lock in PostgreSQL.
- Running `CREATE INDEX` (not `CONCURRENTLY`) in a Flyway migration — locks the table for the duration.
- Deploying new application code before the expand migration is applied — new code expects new column that doesn't exist yet.

**Interview Traps:**
- "You can just rename a column in one migration" — renaming a column in one step breaks existing application code that has the old column name in queries.
- Liquibase rollback is not magic — it generates `DROP TABLE` or `DROP COLUMN` DDL; data is lost for add-column rollbacks.

**Quick Revision:** Flyway: versioned SQL scripts + checksum integrity, simple but SQL-only; Liquibase: changesets + built-in rollback + DB abstraction; expand-contract: add backward-compatible changes first, backfill, then contract once all code is updated — never in one step for zero downtime.

---

### Topic 15: Performance Benchmarking

**Difficulty:** Medium-Hard | **Frequency:** Medium | **Companies:** All (SRE, Platform Engineering roles)

**Q:** How do you benchmark a PostgreSQL database to establish performance baselines, and how do you identify whether a production slowdown is caused by CPU, I/O, network, or lock contention?

**Short Answer:**
Database benchmarking uses standardized workloads (TPC-C for OLTP, TPC-H for OLAP) or workload-specific tools (pgbench for PostgreSQL, sysbench for MySQL) to measure throughput (TPS), latency percentiles, and saturation under varying concurrency. Production slowdowns are diagnosed by correlating database metrics (wait events, lock views, query stats) with OS-level metrics (CPU saturation, iowait, network throughput) to pinpoint the bottleneck tier.

**Deep Explanation:**

**Industry Benchmarks:**

| Benchmark | Type | Measures | Use Case |
|---|---|---|---|
| TPC-C | OLTP | Transactions per minute (tpmC), mixed read/write | Order entry simulation, RDBMS comparison |
| TPC-H | OLAP | Query execution time for 22 analytical queries | Data warehouse query engines |
| TPC-E | OLTP | More realistic than TPC-C, brokerage workload | Modern OLTP systems |
| YCSB | NoSQL | Configurable read/write/scan mix | Comparing NoSQL databases |
| HammerDB | Free TPC-C/TPC-H | Open-source TPC testing | PostgreSQL, MySQL benchmarking |

**pgbench (PostgreSQL):**
- Built-in: `pgbench -i -s 10 mydb` (initialize, scale factor 10 = 1M rows).
- Run: `pgbench -c 50 -j 4 -T 300 mydb` (50 clients, 4 workers, 300 seconds).
- Reports: TPS, latency average, latency stddev.
- Custom scripts: `-f custom.sql` for workload-specific queries.
- Read-only mode: `-S` (SELECT only).

**sysbench (MySQL/PostgreSQL):**
- `sysbench oltp_read_write --db-driver=pgsql --pgsql-db=mydb --tables=10 --table-size=1000000 prepare`
- `sysbench oltp_read_write ... --threads=32 --time=300 run`
- Reports: TPS, QPS, P95/P99 latency, errors.

**Identifying Bottlenecks:**

**CPU Bottleneck:**
- OS: `top`, `vmstat`, `mpstat` showing >80% CPU utilization.
- PostgreSQL: `pg_stat_activity` showing many active queries; `EXPLAIN ANALYZE` showing high execution time without I/O waits.
- Root cause: inefficient queries (missing index → sequential scan), high connection count (each connection = OS process in PostgreSQL).
- Fix: add indexes, query optimization, PgBouncer connection pooling, read replicas.

**I/O Bottleneck:**
- OS: `iostat -x` showing `%util` > 80%, high `await` (queue latency), low `r/s` or `w/s` throughput headroom.
- PostgreSQL: `pg_stat_bgwriter` showing high `buffers_clean` (background writer running out); `pg_stat_user_tables` showing high `seq_scan` (missing indexes causing full table scans).
- Wait events: `pg_stat_activity.wait_event_type = 'IO'`, `wait_event = 'DataFileRead'`.
- Fix: add indexes (eliminate sequential scans), increase `shared_buffers` (reduce disk reads), upgrade to NVMe/SSD, enable `pg_prewarm`.

**Network Bottleneck:**
- OS: `sar -n DEV`, `netstat -s`, `ss -s` showing high packet loss, retransmits, or near-bandwidth utilization.
- Common causes: chatty application (N+1 queries), large result sets, no connection pooling (TLS handshake overhead).
- Fix: batching, pagination, connection pooling, compression for large results.

**Lock Contention:**
- PostgreSQL: `pg_locks` joined with `pg_stat_activity` reveals blocking queries.
- `pg_stat_activity.wait_event_type = 'Lock'` identifies lock waiters.
- Common culprits: long-running transactions holding row locks, DDL migrations taking table-level locks, deadlocks.
- Fix: shorter transactions, `SELECT FOR UPDATE SKIP LOCKED` for queue processing, advisory locks for application-level coordination.

**Connection Pool Monitoring:**
- PgBouncer: `SHOW POOLS;` — `cl_waiting` > 0 means clients queuing for a connection.
- HikariCP: `hikaricp.connections.active`, `hikaricp.connections.pending`, `hikaricp.connections.timeout.total`.
- Signs of pool exhaustion: `Connection is not available, request timed out after Xms` errors; all connections in `active` state.
- Sizing: `pool_size = (core_count × 2) + effective_spindle_count` (HikariCP recommended formula).

**Real-World Example:**
A fintech company notices P99 checkout latency increased from 200ms to 2s after deploying a new version. Investigation: `pg_stat_activity` shows 40 queries waiting on `Lock` type (`relation` subtype). Root cause: a new nightly batch job runs `UPDATE orders SET status = 'archived'` in a single transaction, holding a `RowExclusiveLock` on all matching rows, blocking checkout queries that `SELECT FOR UPDATE` on individual order rows. Fix: batch job processes 1000 rows per transaction with `pg_sleep(10ms)` between batches.

**Code Example:**

```java
// Spring Boot — database performance monitoring and diagnostics

// HikariCP pool metrics integration with Micrometer
@Configuration
public class DatabaseMetricsConfig {

    @Bean
    public DataSource dataSource(MeterRegistry meterRegistry) {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl("jdbc:postgresql://localhost:5432/mydb");
        config.setUsername("app_user");
        config.setPassword("password");
        config.setMaximumPoolSize(20);
        config.setMinimumIdle(5);
        config.setConnectionTimeout(30_000);
        config.setIdleTimeout(600_000);
        config.setMaxLifetime(1_800_000);
        config.setLeakDetectionThreshold(60_000);  // warn if connection held > 60s

        // Register Micrometer metrics
        config.setMetricRegistry(meterRegistry);

        return new HikariDataSource(config);
    }
}

// Lock contention diagnostic queries
@Repository
public class DatabaseDiagnosticsRepository {

    private final JdbcTemplate jdbcTemplate;

    // Find blocking queries and their victims
    public List<LockInfo> findBlockingQueries() {
        String sql = """
            SELECT
                blocked.pid          AS blocked_pid,
                blocked.query        AS blocked_query,
                blocked.wait_event   AS blocked_wait_event,
                blocking.pid         AS blocking_pid,
                blocking.query       AS blocking_query,
                blocking.query_start AS blocking_query_start,
                NOW() - blocking.query_start AS blocking_duration
            FROM pg_stat_activity blocked
            JOIN pg_locks          blocked_locks  ON blocked.pid = blocked_locks.pid
            JOIN pg_locks          blocking_locks ON blocked_locks.transactionid = blocking_locks.transactionid
                                                  AND blocked_locks.pid != blocking_locks.pid
            JOIN pg_stat_activity  blocking       ON blocking.pid = blocking_locks.pid
            WHERE NOT blocked_locks.granted
            ORDER BY blocking_duration DESC
            """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new LockInfo(
            rs.getInt("blocked_pid"),
            rs.getString("blocked_query"),
            rs.getInt("blocking_pid"),
            rs.getString("blocking_query"),
            rs.getObject("blocking_duration", Duration.class)
        ));
    }

    // Identify slow queries from pg_stat_statements
    public List<SlowQuery> findTopSlowQueries(int limit) {
        String sql = """
            SELECT
                query,
                calls,
                total_exec_time / calls AS avg_exec_ms,
                (total_exec_time / calls) * calls / 1000.0 AS total_exec_seconds,
                rows / NULLIF(calls, 0) AS avg_rows,
                stddev_exec_time AS stddev_ms,
                shared_blks_hit,
                shared_blks_read,
                shared_blks_hit::float / NULLIF(shared_blks_hit + shared_blks_read, 0) AS cache_hit_ratio
            FROM pg_stat_statements
            WHERE calls > 10
            ORDER BY avg_exec_ms DESC
            LIMIT ?
            """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new SlowQuery(
            rs.getString("query"),
            rs.getLong("calls"),
            rs.getDouble("avg_exec_ms"),
            rs.getDouble("stddev_ms"),
            rs.getDouble("cache_hit_ratio")
        ), limit);
    }

    // Cache hit ratio — should be > 99% for OLTP
    public double getBufferCacheHitRatio() {
        String sql = """
            SELECT
                ROUND(100.0 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2)
                AS cache_hit_ratio
            FROM pg_stat_database
            WHERE datname = current_database()
            """;
        return jdbcTemplate.queryForObject(sql, Double.class);
    }

    // Table bloat estimate
    public List<TableBloat> getTopBloatedTables(int limit) {
        String sql = """
            SELECT
                schemaname || '.' || relname AS table_name,
                n_dead_tup AS dead_tuples,
                n_live_tup AS live_tuples,
                ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
                last_autovacuum,
                last_autoanalyze
            FROM pg_stat_user_tables
            WHERE n_dead_tup > 10000
            ORDER BY dead_pct DESC
            LIMIT ?
            """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new TableBloat(
            rs.getString("table_name"),
            rs.getLong("dead_tuples"),
            rs.getLong("live_tuples"),
            rs.getDouble("dead_pct"),
            rs.getObject("last_autovacuum", LocalDateTime.class)
        ), limit);
    }

    // Connection pool utilization
    public ConnectionPoolStats getConnectionStats() {
        String sql = """
            SELECT
                count(*) FILTER (WHERE state = 'active')   AS active_connections,
                count(*) FILTER (WHERE state = 'idle')     AS idle_connections,
                count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_tx,
                count(*) AS total_connections,
                (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS max_connections
            FROM pg_stat_activity
            WHERE datname = current_database()
            """;

        return jdbcTemplate.queryForObject(sql, (rs, rowNum) -> new ConnectionPoolStats(
            rs.getInt("active_connections"),
            rs.getInt("idle_connections"),
            rs.getInt("idle_in_tx"),
            rs.getInt("total_connections"),
            rs.getInt("max_connections")
        ));
    }
}

// Performance monitoring scheduled task
@Component
public class DatabaseHealthMonitor {

    private final DatabaseDiagnosticsRepository diagnostics;
    private final MeterRegistry meterRegistry;
    private final AlertService alertService;

    @Scheduled(fixedDelay = 30_000)  // every 30 seconds
    public void checkDatabaseHealth() {
        // 1. Check cache hit ratio
        double cacheHitRatio = diagnostics.getBufferCacheHitRatio();
        meterRegistry.gauge("db.cache.hit_ratio", cacheHitRatio);
        if (cacheHitRatio < 95.0) {
            alertService.warn("Low DB cache hit ratio: " + cacheHitRatio + "% (target >99%)");
        }

        // 2. Check for lock contention
        List<LockInfo> locks = diagnostics.findBlockingQueries();
        meterRegistry.gauge("db.locks.blocking_count", locks.size());
        locks.stream()
            .filter(l -> l.getBlockingDuration().toSeconds() > 30)
            .forEach(l -> alertService.alert("Long-running blocking query: " + l));

        // 3. Check connection pool
        ConnectionPoolStats pool = diagnostics.getConnectionStats();
        double utilization = (double) pool.getTotalConnections() / pool.getMaxConnections();
        meterRegistry.gauge("db.connections.utilization", utilization);
        if (pool.getIdleInTransaction() > 5) {
            alertService.warn("Idle-in-transaction connections: " + pool.getIdleInTransaction());
        }
    }
}

// pgbench equivalent: custom load test with Spring
@Component
public class DatabaseLoadTester {

    private final JdbcTemplate jdbcTemplate;
    private final ExecutorService executor = Executors.newFixedThreadPool(50);

    public LoadTestResult runBenchmark(int concurrency, int durationSeconds) throws Exception {
        AtomicLong totalOps = new AtomicLong();
        AtomicLong totalLatencyNs = new AtomicLong();
        AtomicLong errors = new AtomicLong();
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch doneLatch = new CountDownLatch(concurrency);
        AtomicBoolean running = new AtomicBoolean(true);

        for (int i = 0; i < concurrency; i++) {
            executor.submit(() -> {
                try {
                    startLatch.await();
                    while (running.get()) {
                        long start = System.nanoTime();
                        try {
                            jdbcTemplate.queryForObject(
                                "SELECT balance FROM accounts WHERE id = ?",
                                Long.class,
                                ThreadLocalRandom.current().nextLong(100_000));
                            totalOps.incrementAndGet();
                            totalLatencyNs.addAndGet(System.nanoTime() - start);
                        } catch (Exception e) {
                            errors.incrementAndGet();
                        }
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                } finally {
                    doneLatch.countDown();
                }
            });
        }

        long startTime = System.currentTimeMillis();
        startLatch.countDown();
        Thread.sleep(durationSeconds * 1000L);
        running.set(false);
        doneLatch.await();

        long elapsedMs = System.currentTimeMillis() - startTime;
        long ops = totalOps.get();

        return new LoadTestResult(
            (double) ops / (elapsedMs / 1000.0),  // TPS
            ops > 0 ? (totalLatencyNs.get() / ops / 1_000_000.0) : 0,  // avg latency ms
            errors.get()
        );
    }
}
```

**Follow-up Questions:**
1. What is the difference between `pg_stat_statements` and `EXPLAIN ANALYZE` for query performance analysis, and when do you use each?
2. How would you detect and fix N+1 query problems in a Spring Data JPA application automatically?
3. What is connection pool oversizing, and why can adding more connections sometimes make performance worse?

**Common Mistakes:**
- Benchmarking with a single thread — doesn't reveal concurrency-related bottlenecks (lock contention, connection pool exhaustion).
- Not warming up the buffer cache before measuring — cold benchmarks are not representative of production.
- Ignoring P99/P99.9 latency — average latency hides tail latency that affects 1% of users at scale.
- Benchmarking on a different hardware profile than production — especially storage (HDD vs SSD vs NVMe).
- Not resetting `pg_stat_statements` (`SELECT pg_stat_statements_reset()`) between test runs.

**Interview Traps:**
- "More connections = more throughput" — false above a threshold. PostgreSQL's process-per-connection model means high connection counts cause OS scheduling overhead and memory pressure. PgBouncer transaction pooling is the answer.
- TPC-C results from different vendors are not directly comparable — hardware, OS, and configuration differ.

**Quick Revision:** Benchmark with pgbench/sysbench (TPS + P99 latency); diagnose CPU via `pg_stat_activity` active query count; I/O via `pg_stat_bgwriter` + `wait_event='DataFileRead'`; locks via `pg_locks` join; connection pressure via PgBouncer `SHOW POOLS`; cache hit ratio should exceed 99% for OLTP.

---

## Cheat Sheet: Distributed Databases & Sharding Quick Reference

### NoSQL Database Selection Guide

| Use Case | Database Type | Best Choice | Why |
|---|---|---|---|
| User sessions, caching | Key-Value | Redis | Sub-millisecond, TTL support, data structures |
| Shopping cart, user prefs | Document | DynamoDB, MongoDB | Flexible schema, nested objects |
| Social graph, fraud detection | Graph | Neo4j, Amazon Neptune | Traversal queries, relationship-first |
| IoT sensor telemetry | Time-Series | TimescaleDB, InfluxDB | Compression, downsampling, retention |
| Product catalog, content | Document | MongoDB, Elasticsearch | Rich queries, full-text, aggregations |
| E-commerce order history | Wide-Column | Cassandra, DynamoDB | High write throughput, time-based queries |
| Real-time leaderboards | Key-Value | Redis Sorted Sets | O(log N) rank queries |
| Full-text search | Search Engine | Elasticsearch, Solr | Inverted index, relevance scoring |
| Financial transactions | Relational | PostgreSQL, CockroachDB | ACID, strong consistency, complex joins |
| Analytics / OLAP | Columnar | Redshift, BigQuery, Snowflake | Column compression, vectorized execution |
| Multi-region, active-active | Wide-Column | Cassandra, DynamoDB Global Tables | Tunable consistency, multi-DC replication |
| Hierarchical/config data | Document | MongoDB, Couchbase | Nested document model |

---

### Sharding Strategy Comparison

| Strategy | How It Works | Pros | Cons | Best For |
|---|---|---|---|---|
| **Range Sharding** | Each shard owns a key range (e.g., A–M, N–Z) | Range queries stay on one shard; easy shard management | Hot spots on monotonic keys (e.g., timestamps, auto-increment IDs) | Non-monotonic keys with range queries |
| **Hash Sharding** | Hash(key) mod N → shard | Uniform distribution, no hot spots | Range queries scatter across all shards | Write-heavy workloads, no range queries |
| **Directory Sharding** | Lookup table maps key → shard | Maximum flexibility, supports irregular distributions | Lookup table becomes a bottleneck; single point of failure if not replicated | Custom routing, tenant-based sharding |
| **Geo/Zone Sharding** | Shard assigned by geographic region or data attribute | Data locality, regulatory compliance (GDPR) | Uneven shard sizes if regions differ; increased complexity | Multi-region applications, data residency requirements |
| **Consistent Hashing** | Virtual nodes on a hash ring; key → nearest node | Minimal data movement on node add/remove; natural replication | Complex implementation; requires vnodes for uniformity | Distributed caches (Redis Cluster), Cassandra, DynamoDB |
| **Entity-Group / Application-Level** | Application routes by entity type or tenant ID | Full control; can co-locate related entities | Application complexity; requires custom routing logic | Multi-tenant SaaS, microservice databases |

---

### Replication Topology Comparison

| Topology | Architecture | Consistency | Availability | Use Cases | Examples |
|---|---|---|---|---|---|
| **Single Primary (Leader-Follower)** | One write node, N read replicas | Strong on primary; eventual on replicas | Primary SPOF unless promoted | OLTP read scaling, reporting replicas | PostgreSQL streaming replication, MySQL replica |
| **Multi-Primary (Multi-Master)** | Multiple write nodes, all replicate to each other | Conflict resolution needed (last-write-wins or application) | High (any node accepts writes) | Active-active multi-region, geo-distributed writes | MySQL Group Replication, CockroachDB |
| **Quorum-Based (Paxos/Raft)** | Leader elected by majority; writes to quorum | Strong consistency if W + R > N | Survives minority node failures | Consensus-critical systems (etcd, ZooKeeper, CockroachDB) | etcd, CockroachDB, MongoDB replica sets |
| **Masterless (Leaderless)** | Any node accepts writes; replication to N peers | Tunable (ONE/QUORUM/ALL) | Extremely high (no leader election) | High-availability, AP systems | Cassandra, DynamoDB, Riak |
| **Chain Replication** | Writes to head, propagate through chain, ack at tail | Strong (tail-read guarantee) | Tail is bottleneck; head failure needs reconfiguration | Object storage, file systems | Azure Storage, CRAQ |
| **Synchronous Replication** | Primary waits for all replicas to acknowledge | Strong | Lower availability (slow replica = slow writes) | Regulatory/financial systems, RPO=0 | PostgreSQL synchronous_commit = on |
| **Asynchronous Replication** | Primary acknowledges before replicas confirm | Eventual (potential data loss on failover) | Higher availability (primary not blocked) | Read scaling, non-critical replicas | PostgreSQL default streaming replication |

---

### Key Distributed Systems Theorems

#### CAP Theorem (Brewer, 2000)
A distributed system can only guarantee **two of three** properties simultaneously:

| Property | Definition |
|---|---|
| **Consistency (C)** | Every read receives the most recent write or an error (linearizability) |
| **Availability (A)** | Every request receives a non-error response (but may not be latest data) |
| **Partition Tolerance (P)** | System continues to operate despite arbitrary network partitions |

**Key insight:** Network partitions are unavoidable in distributed systems, so the real choice is **CP vs AP**:
- **CP systems:** PostgreSQL (with sync replication), HBase, ZooKeeper, etcd — reject writes or return error during partitions to maintain consistency.
- **AP systems:** Cassandra, DynamoDB (eventual), CouchDB — remain available with possible stale reads during partitions.
- **Not a binary choice:** Cassandra with `QUORUM` consistency is effectively CP for that request; with `ONE` it is AP. Many systems are tunable.

---

#### PACELC Theorem (Abadi, 2012)
Extends CAP to address the trade-off that exists **even without partitions**:

> If there is a **Partition (P)**, choose **Availability (A)** or **Consistency (C)**;
> **Else (E)** (no partition), choose **Latency (L)** or **Consistency (C)**.

| System | Partition Behavior | Normal Behavior | Classification |
|---|---|---|---|
| DynamoDB (default) | Available | Low Latency | PA/EL |
| DynamoDB (strong consistency) | Consistent | Higher Latency | PC/EC |
| Cassandra (ONE) | Available | Low Latency | PA/EL |
| Cassandra (QUORUM) | Consistent | Higher Latency | PC/EC |
| PostgreSQL (sync replication) | Consistent | Higher Latency | PC/EC |
| CRDT-based systems | Available | Low Latency | PA/EL |

**Key insight:** PACELC is more practical than CAP because real systems are almost never partitioned but are always trading latency for consistency.

---

#### FLP Impossibility Theorem (Fischer, Lynch, Paterson, 1985)
> In a fully **asynchronous** distributed system, there is no deterministic consensus algorithm that can tolerate even a **single crash failure** and still guarantee termination.

**Implications:**
- Explains why Paxos and Raft use timeouts and randomization (not pure determinism).
- Real-world systems add **synchrony assumptions** (timeouts, heartbeats, leases) to work around FLP.
- **Paxos:** Uses a two-phase protocol with an elected proposer; relies on timeouts for liveness.
- **Raft:** Simplifies Paxos with leader election, log replication, and safety via term numbers.
- **ZAB (ZooKeeper Atomic Broadcast):** Crash-recovery variant of Paxos used in ZooKeeper.

---

#### Additional Distributed Systems Principles

**Two Generals Problem:**
- It is impossible to achieve guaranteed agreement between two nodes over an unreliable communication channel.
- Explains why TCP's three-way handshake can still theoretically fail (SYN-ACK-ACK can be lost).
- **Application:** Distributed transaction coordinators (2PC) can block indefinitely if the coordinator crashes mid-commit — solved by 3PC, Paxos, or Saga pattern.

**Byzantine Fault Tolerance (BFT):**
- Handles **malicious/arbitrary failures** (not just crashes). Requires 3f+1 nodes to tolerate f Byzantine failures.
- Used in: blockchain consensus (PBFT, Tendermint), aerospace systems.
- **Not used in:** most distributed databases (assume crash-fail model, not Byzantine).

**Eventual Consistency + CRDT:**
- **Conflict-free Replicated Data Type (CRDT):** Data structures that merge concurrently without conflicts.
- Types: G-Counter (grow-only), PN-Counter, LWW-Register (last-write-wins), OR-Set (observed-remove set).
- **Application:** Collaborative editing (Google Docs), shopping carts, presence systems.

**Vector Clocks vs Lamport Timestamps:**

| Feature | Lamport Timestamp | Vector Clock |
|---|---|---|
| What it captures | Causal ordering (happens-before) | Full causal history per node |
| Size | Single integer | Array of size N (one per node) |
| Detects concurrency | No | Yes |
| Application | Log ordering, mutual exclusion | Version conflict detection (Riak, DynamoDB) |

---

*End of Chapter 17 Part B — Distributed Databases & Sharding*

*Volume 4: Databases | Backend Interview Handbook*
*Target Audience: SDE2–Senior / FAANG+ | Topics 9–15 + Cheat Sheet*





