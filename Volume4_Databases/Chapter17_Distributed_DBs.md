# Volume 4: Databases
# Chapter 17: Distributed Databases

---

## Table of Contents

1. Database Sharding
2. Consistent Hashing
3. Replication Strategies
4. Eventual Consistency in Practice
5. Distributed Caching Architecture
6. Time in Distributed Systems
7. Consensus Algorithms
8. Leader Election
9. DynamoDB Deep Dive
10. Cassandra Deep Dive
11. MongoDB Deep Dive
12. Time-Series Databases
13. Full-Text Search with Elasticsearch
14. Database Migration Strategies
15. Performance Benchmarking

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: Database Sharding

---

#### The Idea

Imagine a library that started with one shelf. Over time books piled up until a single shelf couldn't hold them all, so librarians split the collection across ten rooms — room 1 for A–C authors, room 2 for D–F, and so on. Each room is independent: it has its own catalogue, its own staff, and can be searched quickly. That is sharding. Instead of one giant database, you split rows across many independent database instances called shards.

The split is controlled by a **shard key** — a column (or combination of columns) chosen from your data. Every write and read uses that key to decide which shard to talk to. A user-id, order-id, or tenant-id are typical choices. Pick well and each shard handles a fair slice of traffic; pick poorly and one shard becomes a bottleneck while the others idle.

There are three main strategies for mapping a key to a shard. **Range sharding** assigns contiguous key ranges to each shard (users 1–1 000 000 on shard A, 1 000 001–2 000 000 on shard B). **Hash sharding** runs the key through a hash function and uses `hash(key) % N` to pick a shard — spreading data more evenly but losing range-query ability. **Directory-based sharding** keeps a lookup table that maps each key (or key prefix) to a shard — maximum flexibility at the cost of maintaining that lookup service.

---

#### How It Works

```
// Range sharding — router logic
function getShardForKey(key, shardRanges):
    for each range in shardRanges:
        if range.min <= key <= range.max:
            return range.shard
    throw ShardNotFound

// Hash sharding — router logic
function getShardForKey(key, numShards):
    return hash(key) % numShards

// Directory-based — router logic
function getShardForKey(key, directoryService):
    return directoryService.lookup(key)   // network call to lookup table
```

**Range sharding** enables efficient range scans (`WHERE user_id BETWEEN 1 AND 10000`) but causes **hot spots** when keys are written sequentially — all new inserts land on the last shard. **Hash sharding** distributes evenly but breaks range queries — you must scatter-gather across all shards to answer `BETWEEN` queries. **Directory-based** handles non-uniform distributions and supports resharding without changing the hash formula, but the directory itself becomes a single point of failure if not replicated.

Must-memorise gotcha — the real code interviewers expect you to know:

```java
// Cross-shard join — THIS DOES NOT WORK natively
// You cannot JOIN tables on different shards in a single SQL query.
// You must fetch from each shard and join in application memory.

List<Order> ordersFromShard1 = shard1.query("SELECT * FROM orders WHERE user_id = ?", userId);
List<Order> ordersFromShard2 = shard2.query("SELECT * FROM orders WHERE user_id = ?", userId);
// merge in application code — expensive and error-prone
```

Cross-shard joins and cross-shard transactions (two-phase commit across shards) are not supported by most sharded systems. Design your data model so that entities that are queried together live on the same shard — called **co-location**. For example, store all of a user's orders on the same shard as the user by sharding both tables on `user_id`.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is database sharding and what are the trade-offs between range, hash, and directory-based strategies?"**

**One-line answer:** Sharding horizontally partitions rows across independent database instances using a shard key, and the partitioning strategy determines the balance between even distribution, query flexibility, and operational overhead.

**Full answer to give in an interview:**

> "Sharding means splitting a single large table's rows across multiple independent database instances — each instance is called a shard and holds a subset of the data. A shard key, typically something like user-id or tenant-id, decides which shard each row lives on.
>
> The three strategies differ in their trade-offs. Range sharding assigns contiguous key ranges to each shard — this lets you do efficient range queries like 'give me all orders from user 1 to 1 000 000' but creates hot spots when keys are written sequentially because all new writes hit the last range. Hash sharding runs the key through a hash function and takes modulo N — this spreads writes evenly and avoids hot spots, but you lose range-query ability entirely; a query like 'users with id between 100 and 200' must scatter to every shard and gather results in application code. Directory-based sharding maintains a lookup table mapping keys to shards — very flexible and supports arbitrary resharding, but the directory becomes a dependency that must itself be highly available and low-latency.
>
> The big operational constraint of all three: cross-shard joins don't work natively. If an order and its user live on different shards, you cannot do a SQL JOIN — you must fetch both separately and merge in application code. So the data model must be designed for co-location: everything you join together should share the same shard key."

> *Deliver the three strategies in order. Pause after naming each one. Most interviewers will nod and let you continue — if they stop you, go deeper on whichever one they ask about.*

**Gotcha follow-up they'll ask:** *"How do you handle resharding — adding a new shard — without downtime?"*

> "Hash sharding is the painful case: changing N in `hash(key) % N` remaps almost every key, causing massive data movement. Consistent hashing was invented to solve exactly this — I can go into that if useful. Directory-based sharding handles resharding more gracefully: you just update the lookup table entries for the keys you want to move, migrate that data in the background, then flip the directory entry. Range sharding requires splitting a range and migrating half the data, which can be done online with dual-write during the migration window."

---

##### Q2 — Tradeoff Question
**"When would you choose hash sharding over range sharding for a multi-tenant SaaS application?"**

**One-line answer:** Choose hash sharding when uniform load distribution across shards matters more than the ability to do range queries on the shard key.

**Full answer to give in an interview:**

> "In a multi-tenant SaaS app I'd lean toward hash sharding on tenant-id if the tenants vary widely in activity — hash distributes them across shards more evenly, preventing one large tenant from overwhelming a single shard.
>
> Range sharding on tenant-id is tempting because it keeps a tenant's data contiguous and makes tenant-level backups or migrations easy — you know exactly which shard owns tenant X. But if tenant activity is uneven, one shard holding all the high-traffic tenants becomes a hot spot. Hash sharding breaks that correlation.
>
> The cost is losing range queries on tenant-id. But in a typical SaaS app, most queries are scoped to a single tenant anyway — 'give me all this tenant's data' — which is a point lookup on tenant-id. Range queries across tenants ('give me all tenants created in January') are rare and can be served by a secondary read replica or a data warehouse rather than the operational sharded database.
>
> For the must-avoid mistake: I'd never shard on a timestamp or an auto-increment id in a write-heavy system. Both cause all writes to go to the last shard — which defeats the purpose of sharding entirely."

> *End on the anti-pattern. It shows operational maturity and interviewers remember it.*

**Gotcha follow-up they'll ask:** *"What is a hot shard and how do you fix one in production?"*

> "A hot shard is a shard receiving disproportionately more reads or writes than the others — typically because the shard key correlates with activity (e.g., a celebrity user, a viral event). Fixes: first, identify the hot keys using slow-query logs or shard-level metrics. Then either split that shard into two smaller shards (range split), re-route hot keys to a dedicated shard via directory update, or add a read-replica for the hot shard to absorb read traffic. For write-heavy hot keys, application-level caching or rate-limiting at the API layer is often the faster short-term fix."

---

##### Q3 — Design Scenario
**"Design the sharding strategy for an e-commerce order system that needs to support both 'get orders for user X' and 'get all orders in the last 24 hours'."**

**One-line answer:** Shard on user-id for operational reads and maintain a separate time-ordered table or data warehouse for time-range queries, because no single shard key satisfies both access patterns.

**Full answer to give in an interview:**

> "These two access patterns conflict at the sharding level. 'Get orders for user X' is a point lookup — user-id is the natural shard key and co-locates a user's orders on one shard, making this a single-shard query. 'Get all orders in the last 24 hours' is a time-range scan — if we sharded by timestamp instead, this would be efficient but 'get orders for user X' would scatter-gather across all shards.
>
> My approach: shard the primary orders table by user-id for the operational workload. For time-range analytics, write a secondary copy to a separate system — either a time-series table on a different shard key, a data warehouse like BigQuery or Redshift, or a stream processor that maintains a rolling 24-hour window. The operational DB handles per-user reads at low latency; the analytics system handles cross-cutting time queries with slightly higher latency, which is acceptable for dashboard-style queries.
>
> The key insight is that operational databases are optimised for known-key lookups, and analytics databases are optimised for scans. Trying to serve both from one sharded operational DB is a common mistake that leads to either hot shards or scatter-gather inefficiency."

> *This answer demonstrates system design thinking beyond simple sharding — exactly what senior-level interviewers want to see.*

---

> **Common Mistake — Sharding on a monotonically increasing key:** Sharding on auto-increment IDs or timestamps means every new write goes to the last shard. The other shards sit idle while the hot shard becomes a bottleneck and eventually needs emergency splitting. Always model write distribution before choosing a shard key.

---

**Quick Revision (one line):**
Sharding splits rows across independent DB instances via a shard key; hash sharding distributes evenly but kills range queries, range sharding enables scans but creates hot spots, and cross-shard joins must be done in application code so co-locate data that gets queried together.

---

## Topic 2: Consistent Hashing

---

#### The Idea

Imagine a clock face with 360 positions. You have four servers and you paint each server's name at one of the positions — say 12 o'clock, 3 o'clock, 6 o'clock, and 9 o'clock. When a request comes in, you hash the request key to a position on the clock, then walk clockwise until you hit a server — that server handles the request. This is a consistent hash ring.

Now suppose the 3 o'clock server goes down. With a normal hash (`key % 4` → `key % 3`), almost every key remaps to a different server, invalidating your entire cache or forcing massive data migration. With the ring, only the keys that were pointing to the 3 o'clock server now walk forward to 6 o'clock. Every other key stays exactly where it was. Adding or removing a node disturbs only the keys in that node's arc — roughly 1/N of all keys, where N is the number of nodes.

The problem with a four-point ring is that the four arcs are rarely equal — one server might own 30% of the ring, another only 15%. **Virtual nodes** (vnodes) fix this: instead of placing each physical server at one point, you hash it multiple times and place it at many points. Server A might appear at 150 different positions on the ring. Now the ring is densely and evenly populated, each physical server owns many small arcs that together sum to roughly 1/N of the total ring, and when a server is removed its load spreads across all remaining servers proportionally rather than dumping everything on one neighbour.

---

#### How It Works

```
// Building a consistent hash ring
ring = sorted map of (hash_position -> server_name)

function addServer(serverName, numVirtualNodes):
    for i in 0..numVirtualNodes:
        position = hash(serverName + "#" + i)
        ring[position] = serverName

function removeServer(serverName, numVirtualNodes):
    for i in 0..numVirtualNodes:
        position = hash(serverName + "#" + i)
        delete ring[position]

function getServer(key):
    position = hash(key)
    // find the first ring entry at or after position (clockwise)
    entry = ring.ceilingEntry(position)
    if entry == null:
        entry = ring.firstEntry()   // wrap around
    return entry.value
```

**Adding a node:** new server's vnodes are inserted into the ring. Keys in those arcs now route to the new server — roughly 1/N of keys move. All other keys are undisturbed. **Removing a node:** its vnodes are deleted. Keys in those arcs now route clockwise to the next server — again roughly 1/N of keys, distributed across all remaining servers because vnodes are spread throughout the ring.

Without vnodes, removing one of four servers dumps 25% of all keys onto a single neighbour (the next node clockwise), which can cause a thundering herd on that neighbour. With 150 vnodes per server, that 25% is spread across all three remaining servers in ~50 small chunks each.

Must-memorise gotcha — why vnodes exist:

```java
// WITHOUT vnodes — 4 physical servers, 4 ring positions
// Server B (at position 90) is removed.
// ALL of B's keys (25% of total) now go to Server C (at position 180).
// Server C suddenly handles 50% of total load — cascading failure risk.

// WITH vnodes — 4 physical servers, 150 virtual nodes each = 600 ring positions
// Server B's 150 vnodes are removed.
// Each adjacent vnode's successor is a DIFFERENT physical server.
// B's ~25% of keys spread across A, C, D roughly evenly (~8% each).
// No single server absorbs the full load.

// Java TreeMap implementation of the ring:
TreeMap<Long, String> ring = new TreeMap<>();

void addServer(String server, int vnodeCount) {
    for (int i = 0; i < vnodeCount; i++) {
        long hash = hashFunction(server + "#" + i);
        ring.put(hash, server);
    }
}

String getServer(String key) {
    long hash = hashFunction(key);
    Map.Entry<Long, String> entry = ring.ceilingEntry(hash);
    if (entry == null) entry = ring.firstEntry(); // wrap around
    return entry.getValue();
}
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is consistent hashing and why is it used in distributed systems?"**

**One-line answer:** Consistent hashing maps keys and servers onto a ring so that adding or removing a server only remaps 1/N of all keys instead of remapping almost everything.

**Full answer to give in an interview:**

> "Consistent hashing solves the resharding problem with normal modulo hashing. With plain `hash(key) % N`, if N changes — because a server died or you added capacity — almost every key maps to a different server. For a distributed cache that means a nearly complete cache miss storm. For a distributed database it means migrating almost all your data.
>
> Consistent hashing places both keys and servers on a conceptual ring using the same hash function. A key is served by the first server you reach when you walk clockwise from the key's position on the ring. When a server is added or removed, only the keys in that server's arc — roughly 1 out of N total keys — need to move. Everything else stays put.
>
> Virtual nodes make this practical. Without them, four servers give four unequal arcs and removing one dumps all its load on a single neighbour. With virtual nodes, each physical server is hashed to many positions — say 150 — so arcs are small and numerous. When a server is removed, its 150 arcs each hand off to a different nearby server, spreading the load evenly across the whole cluster.
>
> Real-world users: Amazon DynamoDB, Apache Cassandra, and most distributed caches use consistent hashing as the foundation for key routing."

> *If they ask about the ring wrap-around: the ring is a modular space — after the last position comes the first. The TreeMap ceiling-then-first trick handles it in O(log N).*

**Gotcha follow-up they'll ask:** *"What happens to cache hit rate when a node is added to a consistent hash ring?"*

> "Only the keys in the new node's arcs — roughly 1/N of total keys — will now route to the new node. Those keys were previously cached on their old server and are not yet on the new one, so they get a cache miss and must be fetched from the database. The other (N-1)/N of keys are unaffected and continue hitting their existing servers. So cache hit rate dips by roughly 1/N immediately after adding a node and recovers as those keys are re-cached. This is far better than plain modulo hashing, where almost every key remaps and you get a near-total miss storm."

---

##### Q2 — Tradeoff Question
**"How many virtual nodes should you assign per physical server, and what are the trade-offs?"**

**One-line answer:** More virtual nodes gives better load balance but increases the memory footprint of the ring and the overhead of adding or removing a server.

**Full answer to give in an interview:**

> "The ring data structure is a sorted map — a TreeMap in Java. Each virtual node is one entry in that map. With 150 vnodes per server and 100 servers, the ring has 15 000 entries. That's negligible memory. With 1 000 vnodes per server and 10 000 servers, you have 10 million entries — still manageable but worth measuring.
>
> The main trade-off is load balance precision versus operational cost. With very few vnodes — say 10 per server — arc sizes are still uneven and some servers handle significantly more load than others. Empirically, 100–150 vnodes per server gives good balance for cluster sizes up to a few hundred nodes. Cassandra defaults to 256.
>
> Adding or removing a server requires inserting or deleting all of its vnode entries in the ring and then migrating the data those arcs covered. More vnodes means more ring updates, but the migration work is the same regardless — it's still 1/N of total data. So the overhead of more vnodes is mostly the ring update cost, not the data migration cost.
>
> Heterogeneous hardware is another reason to tune vnode count: a server with twice the RAM and CPU should get twice as many vnodes so it naturally owns twice as large a share of the ring."

> *This shows you understand the engineering nuance, not just the concept.*

**Gotcha follow-up they'll ask:** *"Cassandra uses consistent hashing — how does it decide which nodes to replicate data to?"*

> "Cassandra assigns a replication factor, say 3. When a key hashes to position P on the ring, it is written to the first three distinct physical servers encountered walking clockwise from P — these are the three replicas. Virtual nodes complicate this slightly: you walk clockwise collecting vnodes but skip additional vnodes belonging to servers you've already selected, until you have N distinct physical servers. This gives rack-aware and data-center-aware replication when Cassandra's snitch is configured to know which rack each server is in."

---

##### Q3 — Design Scenario
**"Design a consistent hash-based load balancer for a distributed cache cluster."**

**One-line answer:** Build a ring with virtual nodes for each cache server, route each cache key to its clockwise server, and rebalance by adding/removing vnodes when the cluster changes.

**Full answer to give in an interview:**

> "The load balancer maintains an in-memory sorted ring — a TreeMap of hash position to server address. At startup it adds each cache server with, say, 150 virtual nodes. For each incoming cache key, it hashes the key, does a ceiling lookup in the TreeMap, and forwards the request to that server. The lookup is O(log N) where N is total virtual nodes.
>
> When a new cache server joins, the load balancer adds its 150 vnodes to the ring. The keys in those arcs now route to the new server — they'll be cache misses initially, which is acceptable. When a server leaves or dies, its vnodes are removed and the keys route to the next server clockwise. Those keys are also cache misses initially but the system self-heals as requests repopulate the new server.
>
> For production use I'd add health checking: the load balancer pings each server periodically and removes dead servers' vnodes from the ring automatically. I'd also maintain the ring in a replicated configuration store — ZooKeeper or etcd — so all load balancer instances see the same ring state and avoid split-brain routing decisions."

> *Close with the operational detail — it shows you've thought past the algorithm.*

---

> **Common Mistake — Forgetting virtual nodes in the answer:** If you explain consistent hashing with just physical nodes on the ring, you'll describe a system where removing one of four servers dumps 25% of load on a single neighbour. That's the problem vnodes solve. Always mention vnodes when explaining consistent hashing — the interviewer is specifically checking whether you know this.

---

**Quick Revision (one line):**
Consistent hashing places keys and servers on a ring so only 1/N keys move when a server is added or removed; virtual nodes give each physical server many ring positions so load spreads evenly and no single neighbour inherits a removed server's full share.

---

## Topic 3: Replication Strategies

---

#### The Idea

A single database server is a single point of failure. If it crashes, all reads and writes fail. Replication solves this by keeping identical copies of the data on multiple servers. But keeping copies in sync raises a fundamental question: does the original server wait for all copies to confirm before telling the client "your write succeeded," or does it say "done" immediately and sync the copies in the background?

That question — wait or don't wait — is the core trade-off of every replication strategy. Waiting (synchronous replication) means every copy is guaranteed to be up to date when the client gets a success response, but every write is only as fast as your slowest replica. Not waiting (asynchronous replication) makes writes fast because you only write to the primary and reply immediately, but if the primary crashes before syncing replicas, you lose that write.

These trade-offs get more complex as you add more leaders. A single-leader system routes all writes through one node, making consistency easy but creating a write bottleneck. Multi-leader systems let multiple nodes accept writes simultaneously — useful for geo-distributed systems where users write to their nearest data centre — but require a conflict-resolution strategy when two leaders accept conflicting writes to the same record. Leaderless systems like Amazon Dynamo or Apache Cassandra go further: any replica can accept any write, and consistency is maintained through quorum reads and writes rather than through leadership.

---

#### How It Works

```
// Single-leader replication
primary receives write
  -> applies write to own storage
  -> if SYNCHRONOUS: sends to all replicas, waits for all ACKs, then responds to client
  -> if ASYNCHRONOUS: responds to client immediately, replicates in background
  -> if SEMI-SYNCHRONOUS: waits for at least one replica ACK, then responds

// Multi-leader replication
writer_1 on datacenter_A accepts write to record R: value = "X"
writer_2 on datacenter_B accepts write to record R: value = "Y"  (same record, same time)
both leaders sync to each other -> CONFLICT on record R
resolution strategies:
  - last-write-wins: keep whichever write has the later timestamp (loses the other)
  - application-level merge: pass both versions to application to merge
  - CRDT: use a conflict-free replicated data type that auto-merges

// Leaderless (quorum) replication — the must-memorise pattern
N = total replicas
W = number of replicas that must confirm a write (write quorum)
R = number of replicas that must respond to a read (read quorum)

if W + R > N:
    every read overlaps with every write set by at least one node
    -> at least one node in the read set has the latest write
    -> STRONG CONSISTENCY guaranteed
```

Must-memorise gotcha — the quorum condition:

```java
// W + R > N is the quorum condition for strong consistency in leaderless replication.
// Example: N=3, W=2, R=2  ->  W+R=4 > 3  ->  strong consistency
// Example: N=3, W=1, R=1  ->  W+R=2 < 3  ->  eventual consistency only

public class LeaderlessReplicaClient {
    private final int N = 3;  // total replicas
    private final int W = 2;  // write quorum
    private final int R = 2;  // read quorum

    public void write(String key, String value) {
        int acks = 0;
        for (Replica r : replicas) {
            if (r.write(key, value)) acks++;
            if (acks >= W) return;  // quorum reached
        }
        throw new QuorumNotReachedException("Only " + acks + " of " + W + " required acks");
    }

    public String read(String key) {
        List<VersionedValue> responses = new ArrayList<>();
        for (Replica r : replicas) {
            responses.add(r.read(key));
            if (responses.size() >= R) break;  // quorum reached
        }
        // return the value with the highest version number
        return responses.stream()
            .max(Comparator.comparing(VersionedValue::getTimestamp))
            .map(VersionedValue::getValue)
            .orElseThrow();
    }
}
```

Tuning W and R lets you trade off write latency versus read latency versus consistency. Setting W=N gives maximum durability (every replica has the write) but write latency equals the slowest replica. Setting W=1 gives lowest write latency but maximum data loss risk if the primary crashes before syncing.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between synchronous and asynchronous replication, and when would you choose each?"**

**One-line answer:** Synchronous replication waits for replica acknowledgement before confirming a write — zero data loss but higher latency; asynchronous replication confirms immediately and syncs in the background — lower latency but risk of data loss if the primary crashes.

**Full answer to give in an interview:**

> "With synchronous replication, after the primary writes to its own storage it sends the write to one or more replicas and waits for them to confirm before responding to the client with 'success.' The client's write is not considered done until at least one replica has it. The guarantee: if the primary crashes immediately after responding, the replica has a complete copy and can take over with no data loss. The cost: every write is as slow as the round-trip to the replica — if the replica is in a different availability zone, you add 5–20ms to every write.
>
> With asynchronous replication, the primary writes locally, responds to the client immediately, and replicates to followers in the background. Writes are fast — only limited by local disk I/O. The risk: if the primary crashes after responding to the client but before replicating, that write is gone. The replica that takes over is missing the last few writes — called replication lag.
>
> Most production systems use semi-synchronous replication as a pragmatic middle ground: wait for at least one replica to confirm, then respond. MySQL calls this 'semi-sync.' You get durability against single-node failure without waiting for all replicas. Asynchronous is the right choice for analytics replicas where you accept some lag in exchange for not slowing down primary writes."

> *Note: MySQL defaults to asynchronous replication. A common interview trap is assuming MySQL is synchronous — it is not unless you explicitly enable semi-sync with `rpl_semi_sync_master_enabled=1`.*

**Gotcha follow-up they'll ask:** *"What is replication lag and what problems does it cause?"*

> "Replication lag is the delay between a write hitting the primary and that write becoming visible on a replica. In asynchronous replication this can range from milliseconds to seconds. It causes two practical problems: first, stale reads — if your application reads from a replica to offload the primary, a user who just wrote something may not see it when they immediately read it back, because their read hit a lagging replica. Second, failover data loss — if the primary crashes and the replica is elected as new primary, any writes that were in-flight in the replication stream are lost. Read-your-writes consistency and monotonic reads are the application-level strategies for handling lag — I cover those in the eventual consistency topic."

---

##### Q2 — Tradeoff Question
**"Explain leaderless replication and the quorum condition W + R > N."**

**One-line answer:** In leaderless replication any replica can accept writes, and W + R > N ensures every read overlaps with at least one node that has the latest write, giving strong consistency.

**Full answer to give in an interview:**

> "In leaderless replication — used by Cassandra and the original Amazon Dynamo paper — there is no single designated primary. Any of the N replicas can accept a write. The client (or a coordinator node) sends the write to all N replicas simultaneously and waits for W of them to confirm. For reads, it sends the read to all N replicas and waits for R responses, then returns the value with the highest version number.
>
> The quorum condition W + R greater than N guarantees that the read set and the write set overlap by at least one node. That overlapping node holds the latest write, so the read always sees it. Classic example: N equals 3, W equals 2, R equals 2. Write quorum: 2 of 3 nodes have the write. Read quorum: 2 of 3 nodes respond. By the pigeonhole principle, at least one node is in both sets. So the read always gets the latest value.
>
> You can tune this for different trade-offs. W equals 3, R equals 1 — every replica has every write, reads are fast single-node lookups, writes are slow. W equals 1, R equals 3 — writes are instant, reads are slow. W equals 1, R equals 1 — eventual consistency, no overlap guarantee, highest throughput. Systems like Cassandra let you pick the consistency level per query: ONE, QUORUM, ALL."

> *The formula W + R > N is the exact thing interviewers check — say it explicitly.*

**Gotcha follow-up they'll ask:** *"Can you still lose data with W=2, R=2, N=3?"*

> "Yes — there is an edge case. Suppose 2 nodes acknowledge the write so the client gets a success response. Both of those 2 nodes then crash before replicating to the third. When the system recovers, the only surviving node is the one that never received the write. The quorum condition guarantees overlap while all N nodes are alive and responding, but it does not protect against simultaneous failure of W nodes. This is why durability also depends on the replication factor N — a larger N reduces the probability of simultaneous failure of W nodes."

---

##### Q3 — Design Scenario
**"Design a globally distributed database that accepts writes in both the US and Europe with no cross-region write latency."**

**One-line answer:** Use multi-leader replication with one leader per region and a last-write-wins or CRDT conflict resolution strategy, accepting that conflicting concurrent writes to the same record require explicit handling.

**Full answer to give in an interview:**

> "A globally distributed system where US and European users both write needs multi-leader replication — one leader per region, each accepting writes locally without waiting for the cross-Atlantic round trip, which would be 80–100ms and unacceptable for interactive workloads.
>
> Each leader replicates its writes to the other asynchronously in the background. Replication lag across regions is typically 100–200ms. This is fine for records that are only written in one region — a European user's profile is mostly written from Europe. The problem arises when the same record is written in both regions simultaneously: both leaders accept the conflicting writes and then discover the conflict during replication.
>
> Conflict resolution strategies: last-write-wins uses timestamps to keep the later write and discard the earlier one — simple but loses data. Application-level merge passes both versions to application code to merge — correct but requires custom logic. CRDTs, conflict-free replicated data types, are data structures designed to auto-merge without conflicts — counters, sets, and maps have well-known CRDT implementations. Google Docs uses a variant of this.
>
> I'd design the data model to minimise cross-region conflicts: user records are 'owned' by a region, and other regions only read them. Only shared global counters or globally-contested records need CRDT treatment."

> *This answer shows you understand the trade-offs at the system design level, not just the replication mechanism.*

---

> **Common Mistake — Assuming MySQL replication is synchronous:** MySQL uses asynchronous replication by default. Replicas lag behind the primary. If you failover to a replica during that lag window, you lose the unsynced writes. Semi-synchronous mode (`rpl_semi_sync_master_enabled`) waits for at least one replica before confirming — but this is not the default and must be explicitly configured.

---

**Quick Revision (one line):**
Synchronous replication gives zero data loss at the cost of write latency; asynchronous is fast but risks data loss on primary failure; leaderless quorum systems achieve strong consistency when W + R > N, meaning every read overlaps with at least one node that holds the latest write.

---

## Topic 4: Eventual Consistency in Practice

---

#### The Idea

Strong consistency means every read sees the most recent write, as if the database were a single machine. It is the easiest model to reason about — but in a distributed system, achieving it means writes must synchronise across all nodes before completing, which costs latency and availability. When a network partition occurs, a strongly consistent system must refuse writes to avoid serving stale data — it sacrifices availability for correctness.

Eventual consistency is the pragmatic alternative: replicas are allowed to be temporarily out of sync, but they will converge to the same state given enough time and no new writes. Most distributed systems — Cassandra, DynamoDB, Riak — operate in this mode by default. The challenge for application developers is that "eventually consistent" is not a programming model — it is a vague promise. You need more concrete guarantees.

Three widely used models fill the gap between "eventually consistent" and "strongly consistent." **Read-your-writes** guarantees that after you write something, your subsequent reads will see that write — even if other users may not yet. **Monotonic reads** guarantees that once you see a value at version V, you will never see an older version V-1 in a subsequent read — reads don't go backwards. **Causal consistency** is stronger: if write B depends on write A (B was made after observing A), any reader who sees B must also see A. All three are weaker than strong consistency but strong enough for most user-facing applications.

---

#### How It Works

```
// Read-your-writes: route reads to the same replica you wrote to
// (or to the primary if you can't track which replica received the write)

function readAfterWrite(userId, key):
    lastWriteReplica = sessionStore.getLastWriteReplica(userId)
    if lastWriteReplica != null:
        return lastWriteReplica.read(key)   // guaranteed to have your write
    else:
        return anyReplica.read(key)

// Monotonic reads: track the version (timestamp) of the last read per session
// Always read from a replica at least as up-to-date as your last read

function monotonicRead(sessionToken, key):
    minVersion = sessionStore.getLastSeenVersion(sessionToken)
    for replica in replicas:
        if replica.version >= minVersion:
            value = replica.read(key)
            sessionStore.setLastSeenVersion(sessionToken, replica.version)
            return value
    throw NoSuitableReplicaException("all replicas are behind session version")

// Causal consistency: attach a vector clock or logical timestamp to writes
// Readers reject responses from replicas that haven't yet seen a causally prior write

function causalRead(key, causalContext):
    for replica in replicas:
        if replica.hasSeen(causalContext):
            return replica.read(key)
    // wait or retry until a replica catches up
```

**Read-your-writes** is implemented by session affinity: route a user's reads to the same node that accepted their last write, or always route reads to the primary for data that the user wrote recently. The cost is that reads can't be freely distributed across all replicas.

**Monotonic reads** is implemented by tracking a session's "read version" — the most recent replica version the user has seen — and only routing subsequent reads to replicas at or beyond that version. This prevents a user from seeing a comment appear, then disappear, then reappear as their requests hit replicas at different lag points.

**Causal consistency** uses vector clocks or logical timestamps attached to each operation. Every write carries the context of what it observed before writing. Replicas defer reads until they have applied all causally prior writes. DynamoDB and Cosmos DB expose this as "session tokens" that clients pass with each request.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is eventual consistency and what practical consistency guarantees sit between it and strong consistency?"**

**One-line answer:** Eventual consistency means replicas converge over time but may be temporarily stale; read-your-writes, monotonic reads, and causal consistency are intermediate models that give application-level guarantees without requiring full strong consistency.

**Full answer to give in an interview:**

> "Eventual consistency is the weakest useful consistency guarantee: the system promises that, if no new writes arrive, all replicas will eventually converge to the same value. While convergence is in progress, different replicas may return different values. This is acceptable for many use cases — a product's view count being off by a few seconds is fine; a bank balance must not be.
>
> Three practical models strengthen eventual consistency without requiring the full coordination cost of strong consistency. Read-your-writes: after I post a comment, I will always see my own comment when I reload the page — even if other users might not yet. This is implemented by routing my reads to the same replica that accepted my write, or to the primary. Monotonic reads: once I see that a comment was posted at timestamp T, I will never subsequently see the page as if that comment doesn't exist — reads don't go backward in time. Implemented by tracking the latest version seen per session and only hitting replicas at or beyond that version. Causal consistency: if I post a reply to your comment, anyone who sees my reply must also see your comment — causally related operations are seen in order. Implemented with vector clocks.
>
> These models are composable. Most real applications need read-your-writes and monotonic reads. Few need full causal consistency. Strong consistency is reserved for financial ledgers, inventory counts, and other domains where stale reads have direct business consequences."

> *The three models in order — read-your-writes, monotonic reads, causal consistency — are the key content. Name them, define them, give an example.*

**Gotcha follow-up they'll ask:** *"How do you implement read-your-writes in a system that routes reads to replicas?"*

> "Two approaches. Session stickiness: record which replica received the user's last write and always route that user's subsequent reads to the same replica. This is simple but means reads aren't freely load-balanced. Primary fallback: for any data the user wrote in the last N seconds, read from the primary instead of a replica. The window N is typically slightly larger than the maximum expected replication lag. This is less efficient — it puts more load on the primary — but requires no per-session state about which replica holds which write. AWS DynamoDB's 'strongly consistent read' option essentially does this: it reads from the primary leader for that partition key."

---

##### Q2 — Tradeoff Question
**"Explain the difference between monotonic reads and causal consistency with a concrete example."**

**One-line answer:** Monotonic reads prevents your own reads from going backward in time; causal consistency prevents you from seeing an effect before its cause, even across different users' writes.

**Full answer to give in an interview:**

> "Monotonic reads is about a single reader's experience. Imagine I load a social media feed and I see a post that was published at 10:00:01. I refresh the page. Monotonic reads guarantees I will not see a version of the feed that shows the page as it was at 09:59:59 — I will never go backward. Without this guarantee, my requests could round-robin across replicas at different lag points, making items appear and disappear as I browse. The fix is session-level version tracking: each response carries the replica's current version, my session records it, and subsequent requests are only routed to replicas at or beyond that version.
>
> Causal consistency is stronger and involves multiple users. Suppose Alice posts a question: 'Should we move the meeting?' Bob reads Alice's question and replies: 'Yes, let's move it.' Causal consistency guarantees that anyone who sees Bob's reply also sees Alice's original question — because Bob's reply is causally dependent on Alice's question. Without causal consistency, a third user could see Bob's reply ('Yes, let's move it') on a less-lagged replica without seeing Alice's question, which is confusing and potentially incorrect.
>
> Causal consistency requires propagating the causal context — a vector clock or logical timestamp — with every write. Replicas delay serving a read until they have applied all causally prior writes. It is more expensive than monotonic reads but necessary for any system where users interact with each other's writes — comment threads, collaborative editing, messaging."

> *Concrete examples are the key to this answer. The Alice/Bob example is memorable and correct.*

**Gotcha follow-up they'll ask:** *"Does Cassandra provide any of these consistency guarantees?"*

> "Cassandra provides tunable consistency at the query level — you choose ONE, QUORUM, or ALL per request. With QUORUM reads and QUORUM writes where W plus R is greater than N, you get strong consistency for that record. But Cassandra's default consistency level is ONE, which gives eventual consistency only. Cassandra does not natively provide session-level read-your-writes or monotonic reads — those must be implemented in the application layer or by routing reads to the same coordinator node as writes. For causal consistency, Cassandra's lightweight transactions use Paxos but are expensive — typically avoided for high-throughput workloads."

---

##### Q3 — Design Scenario
**"A user posts a comment on a social platform and immediately reloads the page but doesn't see their comment. What consistency model was violated and how would you fix it?"**

**One-line answer:** Read-your-writes consistency was violated; fix it by routing the user's immediate post-write reads to the primary or to the replica that accepted their write.

**Full answer to give in an interview:**

> "The user wrote to the primary — or to any replica in a leaderless system — and got a success response. They then reloaded the page, which issued a read. That read was load-balanced to a replica that hadn't yet received the write due to replication lag — even a few hundred milliseconds of lag is enough. The user's own write was not visible to them. This is a violation of read-your-writes consistency.
>
> The fix: after a write, tag the user's session with the write's replication timestamp or a flag indicating 'this user wrote in the last T seconds.' On the next read, check that tag. If it is set, route the read to the primary or to the specific replica that accepted the write. If the tag is expired or not set, allow free load balancing across replicas as normal.
>
> Implementation detail: the write response from the database should include a 'consistency token' — a monotonically increasing version number or timestamp. Store this in the user's session cookie or server-side session store. On subsequent reads within the same session, pass this token to the read path. The read path selects a replica at or beyond that version. After the replication lag window passes — say 5 seconds — the token expires and reads return to normal load balancing.
>
> This is exactly how DynamoDB session consistency tokens work and how many applications implement read-your-writes on top of eventually consistent storage."

> *Close with the implementation pattern — it's the part that separates a textbook answer from an engineering answer.*

---

> **Common Mistake — Treating "eventual consistency" as a single thing:** Eventual consistency is a spectrum. Saying "we use eventual consistency" tells an interviewer almost nothing — they want to know which specific model you're targeting: read-your-writes? Monotonic reads? Causal? Quorum-based strong consistency? Always name the specific model you need for the specific access pattern you're designing for.

---

**Quick Revision (one line):**
Eventual consistency means replicas converge over time; read-your-writes, monotonic reads, and causal consistency are progressively stronger intermediate models that give practical application guarantees without the full coordination cost of strong consistency.

---

## Topic 5: Distributed Caching Architecture

---

#### The Idea

A cache is a fast, temporary store that sits in front of a slow store — typically between your application and your database. Instead of hitting the database for every read, you check the cache first. A cache hit returns data in under a millisecond; a cache miss falls through to the database. For read-heavy applications, a well-tuned cache can reduce database load by 90% or more and cut response times from tens of milliseconds to fractions of a millisecond.

A single cache server is itself a single point of failure and has finite memory. Distributed caching spreads the cached data across a cluster of cache nodes. The same consistent hashing principle from Topic 2 applies: each key is mapped to a cache node, so the cache scales horizontally and no single node holds all the data. Redis Cluster and Memcached are the two most common distributed cache technologies. Redis Cluster shards data across nodes automatically and supports replication of each shard to a replica node for fault tolerance.

The hardest problems in distributed caching are not performance — they are correctness: when does the cache become stale, what happens when the cache is empty and a thousand requests arrive simultaneously for the same key, and what happens when a frequently-read key (a "hot key") overwhelms a single cache node? Each of these failure modes has a name — cache invalidation, cache stampede, and hot key problem — and each has a well-known solution pattern that interviewers specifically test for.

---

#### How It Works

```
// Cache-aside pattern (most common)
function getUser(userId):
    value = cache.get("user:" + userId)
    if value != null:
        return value                          // cache hit
    value = database.query("SELECT * FROM users WHERE id = ?", userId)
    cache.set("user:" + userId, value, TTL=300)   // cache for 5 minutes
    return value

// Write-through pattern
function updateUser(userId, data):
    database.update(userId, data)             // write to DB first
    cache.set("user:" + userId, data, TTL=300) // immediately update cache

// Write-behind (write-back) pattern
function updateUser(userId, data):
    cache.set("user:" + userId, data)         // write to cache first
    queue.publish("db-write", {userId, data}) // DB write is async
    return                                    // respond immediately; DB catches up

// Cache stampede prevention — only one goroutine/thread fetches from DB
function getWithSingleFlight(key):
    value = cache.get(key)
    if value != null: return value
    // acquire distributed lock before hitting DB
    lock = redisLock.acquire("lock:" + key, ttl=5s)
    if lock.acquired:
        value = database.query(key)
        cache.set(key, value, TTL=300)
        lock.release()
        return value
    else:
        sleep(50ms)
        return getWithSingleFlight(key)   // retry after lock holder populates cache
```

**Cache invalidation strategies:** TTL (time-to-live) — the cache entry expires after a fixed duration, simplest but may serve stale data until expiry. Event-driven invalidation — when a database record is updated, publish an event that deletes the cache entry; lower staleness but adds complexity. Write-through — on every database write, update the cache atomically; freshest but doubles write latency.

**Hot key problem:** a single cache key (e.g., a celebrity's profile) receives so many reads per second that the single cache node handling it becomes a bottleneck. Solutions: local in-process caching (cache the value in application memory for a short window, say 1 second), read replicas for the hot cache node, or key sharding (store the hot key under multiple names — `user:123:shard:0`, `user:123:shard:1` — and round-robin reads across them).

Must-memorise gotcha — the real production code for hot key local caching:

```java
// Local hot-key cache: reduces Redis load for extremely hot keys
// by caching the value in application memory for a brief window

public class HotKeyAwareCacheClient {
    private final RedisClient redis;
    // Local in-process cache: key -> (value, expiry_time)
    private final ConcurrentHashMap<String, CachedEntry> localCache = new ConcurrentHashMap<>();
    private static final long LOCAL_TTL_MS = 1000; // 1 second local cache

    public String get(String key) {
        // Check local cache first — zero network round-trip
        CachedEntry local = localCache.get(key);
        if (local != null && !local.isExpired()) {
            return local.value;
        }

        // Fall through to Redis
        String value = fetchFromRedis(key);
        if (value != null) {
            localCache.put(key, new CachedEntry(value, System.currentTimeMillis() + LOCAL_TTL_MS));
        }
        return value;
    }

    // CachedEntry is a simple struct: value + expiry timestamp
    static class CachedEntry {
        final String value;
        final long expiresAt;
        CachedEntry(String value, long expiresAt) {
            this.value = value; this.expiresAt = expiresAt;
        }
        boolean isExpired() { return System.currentTimeMillis() > expiresAt; }
    }
}
```

This pattern reduces Redis load for hot keys by orders of magnitude: 10 000 req/s hitting the same key across 100 application instances generates only 100 Redis calls per second (one per instance per second) instead of 10 000.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is a cache stampede and how do you prevent it?"**

**One-line answer:** A cache stampede happens when a popular cache entry expires and many concurrent requests all miss and hammer the database simultaneously; prevent it with a distributed lock or probabilistic early expiry.

**Full answer to give in an interview:**

> "A cache stampede — also called a thundering herd — occurs when a highly-requested cache key expires. At the moment of expiry, all in-flight requests for that key get a cache miss simultaneously and each one independently tries to fetch from the database. For a popular key this could mean hundreds or thousands of concurrent database queries for the same record in the same millisecond, overloading the database and potentially causing a cascade failure.
>
> The primary prevention technique is the single-flight pattern or mutex-on-miss: when a cache miss occurs, only one thread or process is allowed to fetch from the database and populate the cache. The others either wait for that one fetch to complete or are served a slightly stale value from the previous cache entry while the refresh happens in the background.
>
> In a distributed system where multiple application servers all miss the same key, use a distributed lock — a short-lived Redis lock keyed on the cache key itself. The first process to acquire the lock fetches from the database and sets the cache. All others that fail to acquire the lock either sleep briefly and retry (by which time the cache is populated) or serve the previous stale value if it is still available.
>
> A softer technique is probabilistic early expiry: instead of expiring at exactly TTL, each process probabilistically decides to refresh the key slightly before it expires — the probability increases as the key approaches its TTL. This staggers the refresh work over a window of time rather than concentrating it at the exact expiry moment."

> *The distributed lock approach is the most commonly expected answer. Name it explicitly.*

**Gotcha follow-up they'll ask:** *"What is cache penetration and how is it different from a cache stampede?"*

> "Cache penetration is a different failure mode: requests for a key that does not exist in either the cache or the database. The cache always misses and every request hits the database — for zero gain. This is often triggered maliciously by querying random non-existent IDs. The fix: cache negative results — when the database returns nothing for a key, store a 'null' or 'not found' sentinel in the cache with a short TTL. Subsequent requests for the same non-existent key hit the cache and get the sentinel immediately, protecting the database. A Bloom filter is a more memory-efficient alternative: a probabilistic data structure that returns 'definitely not in the database' for unknown keys, allowing you to skip both cache and database lookups entirely for provably absent keys."

---

##### Q2 — Tradeoff Question
**"Compare cache-aside, write-through, and write-behind caching patterns. When would you use each?"**

**One-line answer:** Cache-aside is the safest default; write-through keeps the cache always fresh at the cost of double write latency; write-behind is the fastest for write-heavy workloads but risks data loss if the cache node fails before the async DB write completes.

**Full answer to give in an interview:**

> "Cache-aside — also called lazy loading — is the most common pattern. The application checks the cache, misses, reads from the database, and populates the cache. The cache only contains data that has been read at least once. Simple to implement, no wasted cache space on write-only data. The downside is that the first read for any key is always slow (cache miss), and cache entries can become stale — if the database is updated directly without touching the cache, the cache serves the old value until TTL expiry.
>
> Write-through always updates the cache synchronously on every database write. The cache is always fresh — no staleness. But every write now does two things: database write plus cache write. Write latency doubles, and you cache every written key even if it is never read. Good for read-heavy workloads where you want guaranteed freshness and can afford slightly higher write latency.
>
> Write-behind accepts writes into the cache immediately and writes to the database asynchronously in the background. Write latency is minimal — just a cache write. This is suitable for very write-heavy workloads, like game leaderboards or real-time counters, where database write throughput is the bottleneck. The risk: if the cache node crashes before the background database write completes, those writes are lost. You need a persistent cache (Redis with AOF persistence) or a write-ahead log to recover from failures.
>
> My default recommendation: cache-aside for most applications. Write-through if cache freshness is critical and write volume is moderate. Write-behind only when write throughput is the bottleneck and you can tolerate a small window of data loss."

> *Naming the trade-off for each pattern shows depth. Interviewers listen for the failure mode of each approach.*

**Gotcha follow-up they'll ask:** *"How do you handle cache invalidation when multiple services share the same cache?"*

> "Shared caches across services are dangerous because Service A may not know when Service B updates a record that Service A has cached. Two approaches. First, publish invalidation events: when Service B updates a record, it publishes a 'user:123 updated' event to a message bus. All services that care about user:123 subscribe and delete or refresh their cached copies. This gives near-real-time invalidation but couples services through the event bus. Second, use short TTLs as a backstop: even without explicit invalidation, entries expire quickly — say every 30 seconds — limiting staleness to an acceptable window. Most production systems combine both: explicit invalidation for correctness on important data, plus short TTLs as a safety net in case invalidation events are missed."

---

##### Q3 — Design Scenario
**"Design the caching layer for a social media feed that needs to handle a celebrity with 50 million followers posting a new photo."**

**One-line answer:** Pre-compute and fan-out the feed update to follower caches at write time for the top users, use local in-process hot-key caching to absorb the celebrity's own profile read storm, and design for cache misses during the fan-out window.

**Full answer to give in an interview:**

> "A celebrity posting a photo creates two distinct problems. First, 50 million follower feeds need to be updated — a write fan-out problem. Second, the celebrity's profile and the photo itself will receive millions of concurrent reads in the seconds after posting — a hot key read problem.
>
> For the feed update, the standard approach is a fan-out-on-write strategy for non-celebrities: when a user posts, write the post ID into each follower's feed cache immediately. But for a user with 50 million followers, this fan-out would take minutes and saturate the cache write tier. The hybrid approach: for users above a follower threshold, use fan-out-on-read — store the post in a 'celebrity posts' list and merge it into follower feeds at read time. Twitter called this the 'Lady Gaga problem' and moved to this hybrid model for high-follower accounts.
>
> For the hot key read problem — the celebrity's profile and the new photo being read by millions simultaneously — a single Redis node will saturate its network bandwidth. Solutions: local in-process caching in each application server with a 1-second TTL dramatically reduces Redis calls; what was 10 million req/s to Redis becomes one req/s per application instance. CDN caching for the photo binary itself — the photo is served from edge nodes, not the origin cache. Read replicas for the Redis cluster shard holding the celebrity's key, with the hot-key router distributing reads across replicas.
>
> The key design insight: the caching architecture for high-follower users must be explicitly different from the architecture for normal users. A one-size-fits-all caching strategy will fail at celebrity scale."

> *This answer references real architectural decisions (Twitter's hybrid fan-out) and shows end-to-end system thinking.*

---

> **Common Mistake — Ignoring the hot key problem:** Many candidates design a distributed cache as if all keys receive uniform traffic. In production, a tiny fraction of keys receive a disproportionate share of requests — celebrity profiles, trending products, viral content. A cache node holding a hot key can saturate its CPU and network regardless of how many other nodes are in the cluster. Always ask: "what is the traffic distribution?" and explicitly address hot keys in your design.

---

**Quick Revision (one line):**
Distributed caching spreads keys across nodes via consistent hashing; cache-aside is the default pattern, write-through keeps the cache always fresh, write-behind maximises write throughput; the three failure modes to know are cache stampede (concurrent misses on expiry), cache penetration (non-existent key hammers DB), and hot key (single key saturates one node — fix with local in-process caching).

---

## Topic 6: Time in Distributed Systems

---

#### The Idea

Imagine you and a friend are each writing entries in separate notebooks, and you want to know whose entry came first. The obvious solution is to check your watches — but what if your watches are five seconds apart? In a network of computers, every machine has its own hardware clock, and those clocks drift apart over time. Even with clock-synchronisation software like NTP, two machines can disagree on the current time by several milliseconds — and at high write rates, that window is enough to silently reorder events and lose data.

The fix is to stop using wall-clock time for ordering and instead use *logical clocks* — counters that track cause-and-effect relationships between events, not calendar time. If event A caused event B (A sent a message that B received), a logical clock guarantees A's timestamp is lower than B's, regardless of what the wall clock says.

Different logical clock designs offer different power: Lamport clocks give a total order but cannot detect when two events are truly independent; vector clocks detect independent (concurrent) events at the cost of more storage; hybrid logical clocks (HLC) combine a logical counter with wall-clock proximity so you get causality tracking *and* approximate real-world time. Google's Spanner goes further still, using GPS and atomic clocks to bound clock uncertainty to a few milliseconds and wait out that uncertainty before committing.

---

#### How It Works

```
LAMPORT CLOCK — causal ordering without wall clocks

Each node keeps counter C, starts at 0.

  On send:
    C = C + 1
    attach C to outgoing message

  On receive(msg):
    C = max(local_C, msg.C) + 1

Guarantee: if A → B (A caused B), then L(A) < L(B).
Limitation: L(A) < L(B) does NOT prove A caused B — only the converse holds.
Cannot detect concurrent events.
```

```
VECTOR CLOCK — detects concurrency

Each node i keeps a vector V[0..N-1], all zeros.

  On event at node i:   V[i]++
  On send:              attach full vector
  On receive at i:
    V[j] = max(V[j], msg.V[j])  for all j
    V[i]++

Compare V_a and V_b:
  A happened-before B  →  V_a[j] <= V_b[j] for ALL j, strict for at least one
  Concurrent           →  neither dominates the other
```

```
HYBRID LOGICAL CLOCK (HLC) — causality + wall clock proximity

HLC = (wallTime, logicalCounter)

  On tick at node:
    now = System.currentTimeMillis()
    if now > wallTime:
      wallTime = now; logicalCounter = 0
    else:
      logicalCounter++

  On receive(msg.wallTime, msg.logical):
    newWall = max(wallTime, msg.wallTime, now)
    update logicalCounter based on which source provided newWall
    wallTime = newWall

Guarantee: monotonically increasing, tracks wall clock closely, captures causality.
Used by: CockroachDB, YugabyteDB.
```

**Tradeoff table:**

| Clock | Detects causality | Detects concurrency | Real-world time | Cost |
|---|---|---|---|---|
| Lamport | Yes | No | No | O(1) per message |
| Vector | Yes | Yes | No | O(N) per message |
| HLC | Yes | Partial | Approximate | O(1) per message |
| TrueTime | Yes | Yes | Exact (bounded) | GPS/atomic hardware |

**Google TrueTime (Spanner):** `TT.now()` returns an interval `[earliest, latest]` guaranteed to contain the true time, typically 1–7 ms wide. Before committing, Spanner waits until the entire uncertainty interval has elapsed — so every subsequent transaction sees a strictly higher timestamp, giving global linearizability without cross-datacenter coordination locks.

**Must-memorise gotcha — wall-clock time is unreliable:**

```java
// WRONG: using wall clock to order distributed writes
event.setTimestamp(System.currentTimeMillis()); // node A's clock may be 50ms ahead of node B's

// If node A's clock is ahead, ALL of A's writes win last-write-wins
// even when B's write was logically later — data is silently discarded.

// RIGHT: use a logical clock or HLC for ordering
long[] hlc = hybridLogicalClock.tick(); // (wallTime, logicalCounter) — monotonic, causal
event.setHlcWall(hlc[0]);
event.setHlcLogical(hlc[1]);
```

*Two nodes can have system clocks that differ by seconds after a VM migration or NTP step adjustment. Never rely on `System.currentTimeMillis()` to order events across machines.*

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Why can't distributed systems just use wall-clock timestamps to order events?"**

**One-line answer:** Wall clocks drift and can be adjusted by NTP, so two machines can disagree on the current time by milliseconds or more — using them for ordering silently discards data.

**Full answer to give in an interview:**

> "Wall clocks on different machines are not synchronised to the microsecond. Even with NTP — the standard clock-sync protocol — clocks on a LAN can disagree by around 0.1 ms, and over the internet by 1–10 ms. More dangerously, NTP can step a clock backward or forward to correct drift, which means `System.currentTimeMillis()` is not even monotonic on a single machine. If you use wall-clock timestamps for last-write-wins conflict resolution — as many NoSQL databases do — a node whose clock runs 50 ms fast will win every conflict against nodes with slower clocks, even if those nodes wrote logically later. The result is silent data loss with no error. The standard fix is to use logical clocks: Lamport clocks assign a counter that increments on every send and receive, guaranteeing that if A causally preceded B then A's counter is lower than B's. Vector clocks extend this to a vector per node, allowing you to detect concurrent events. Hybrid logical clocks, used in CockroachDB and YugabyteDB, combine wall time with a logical counter so you get causality tracking *and* timestamps that are close to real time. Google's Spanner goes further: it uses GPS receivers and atomic clocks to bound time uncertainty to a few milliseconds and waits out that window before committing."

> *Mention NTP inaccuracy first, then LWW consequence, then the logical clock solutions in order of sophistication.*

**Gotcha follow-up they'll ask:** *"Isn't `System.nanoTime()` monotonic? Why can't you use that?"*

> "`System.nanoTime()` is monotonic within a single JVM process, so it won't jump backward on that one machine. But it has no correlation between machines — two different JVMs calling `nanoTime()` at the same physical instant will return completely unrelated numbers. It's a hardware cycle counter, not a wall clock, and it is only valid for measuring elapsed time on one node. For cross-node event ordering you still need a logical clock."

---

##### Q2 — Tradeoff Question
**"When would you choose a vector clock over a Lamport clock, and what is the cost?"**

**One-line answer:** Use vector clocks when you need to detect whether two events are concurrent rather than just knowing their causal order; the cost is O(N) storage per event where N is the number of nodes.

**Full answer to give in an interview:**

> "A Lamport clock gives you a total order: if event A causally preceded B, A's counter is strictly less than B's. But the reverse is not true — if A's counter is less than B's, all you know is that B did not cause A; they might still be concurrent. A vector clock fixes this by keeping one counter per node. Each event increments the local counter and attaches the full vector. To compare two events, you check whether one vector dominates the other element-wise: if every entry in V_a is less than or equal to V_b, and at least one is strictly less, then A happened before B. If neither vector dominates the other, the events are concurrent — neither caused the other. This is the foundation of how systems like Riak and Amazon Dynamo detect write conflicts and trigger reconciliation. The cost is real: every message and every stored record must carry a vector of N counters, where N is the number of nodes. In large clusters this becomes expensive, which is why most production systems use HLC instead — it captures causality in a single (wallTime, counter) pair while staying close to real time."

> *The word 'dominate' is the right term here — use it; it signals fluency.*

**Gotcha follow-up they'll ask:** *"How does HLC differ from a vector clock?"*

> "HLC uses just two numbers — a wall time component and a logical counter — rather than a vector of N numbers. It guarantees monotonic increase and captures happens-before relationships, but it does not distinguish between concurrent events as cleanly as a vector clock. In practice that is fine for databases: CockroachDB uses HLC for MVCC versioning and time-travel queries, not for conflict detection. The real benefit is constant space per event regardless of cluster size."

---

> **Common Mistake — Using wall-clock time for event ordering:** Relying on `System.currentTimeMillis()` across nodes causes last-write-wins to silently drop writes from nodes with slower clocks. The consequence in production is undetected data loss, not an error.

---

**Quick Revision (one line):**
Wall clocks drift and cannot be trusted for distributed ordering — use Lamport clocks for causal order, vector clocks to detect concurrency, HLC for causality plus real-time proximity, and TrueTime for bounded-uncertainty global linearizability.

---

## Topic 7: Consensus Algorithms

---

#### The Idea

Imagine five people in separate rooms trying to agree on a single answer, but they can only communicate by passing notes, and some notes get lost or delayed. One room may go dark at any moment. How do you guarantee all surviving rooms end up with the same answer, and once they commit to it, they never contradict it? This is the distributed consensus problem, and it is the foundation of every replicated database, distributed lock, and configuration store.

Consensus is needed whenever multiple nodes must agree on a sequence of values — for leader election, distributed locks, or replicated state machines. Paxos was the first rigorous solution, published by Leslie Lamport in 1989, but it is notoriously hard to reason about and implement. Raft was designed a decade later with one explicit goal: understandability. It decomposes consensus into three separate sub-problems — leader election, log replication, and safety — and solves each cleanly.

The key intuition is that you do not need every node to agree; you only need a *majority* (a quorum). A 5-node cluster can lose 2 nodes and still make progress because the 3 survivors form a majority. This is the core durability guarantee of every Raft-based system from etcd to CockroachDB.

---

#### How It Works

```
RAFT — three sub-problems

1. LEADER ELECTION
   All nodes start as followers.
   Each follower waits a random timeout (150–300ms) for a heartbeat.
   If no heartbeat → become candidate, increment term, send RequestVote to all peers.

   A node grants vote if:
     (a) has not voted this term, AND
     (b) candidate's log is at least as up-to-date as own log

   Candidate wins if it receives votes from majority (N/2 + 1).
   Randomised timeouts prevent split votes.

2. LOG REPLICATION
   Client sends command to leader.
   Leader appends to local log with current term.
   Leader sends AppendEntries RPC to all followers.
   Once majority acknowledge → leader commits entry (applies to state machine).
   Leader includes commitIndex in next RPC; followers commit up to that index.

3. SAFETY — LOG MATCHING PROPERTY
   If two log entries at the same index have the same term,
   the logs are identical up to that index.
   Maintained by: AppendEntries includes prevLogIndex + prevLogTerm;
   follower rejects if its log doesn't match there.
```

```
PAXOS vs RAFT — quick comparison

Paxos:
  Phase 1 (Prepare): proposer sends Prepare(n) to majority;
    each acceptor promises to ignore proposals < n, replies with highest accepted value.
  Phase 2 (Accept): proposer sends Accept(n, v) to majority.

  Problems:
  - Specifies single-value agreement; multi-Paxos for a log requires significant extra protocol.
  - Original paper omits leader election, log compaction, membership changes.
  - Every real implementation is a unique variant.
  Used by: Google Chubby, Apache ZooKeeper (ZAB is Paxos-like).

Raft:
  Explicit leader, one per term.
  No log gaps allowed.
  Membership changes via joint consensus.
  Used by: etcd, CockroachDB, TiKV.
```

**Must-memorise gotcha — quorum math:**

```java
// A 5-node Raft cluster requires a majority to commit.
// Majority = floor(N/2) + 1

int nodes = 5;
int majority = nodes / 2 + 1;  // = 3

// Can tolerate 2 failures (5 - 3 = 2 nodes can go down).

// WRONG assumption: 4-node cluster tolerates 2 failures.
// 4-node majority = 3. Can only tolerate 1 failure.
// Adding a 4th node does NOT increase fault tolerance vs 3 nodes.
// Always use ODD cluster sizes: 3, 5, or 7.

// During leader election, ALL writes are unavailable.
// etcd default election timeout: 1 second.
// Design your clients with retry + backoff for this window.
```

*A 5-node cluster can tolerate 2 failures. A 4-node cluster can only tolerate 1 — same as a 3-node cluster. Always use odd cluster sizes.*

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Explain how Raft leader election works."**

**One-line answer:** Nodes use randomised election timeouts; the first node to time out requests votes, and whichever candidate collects a majority first becomes leader for that term.

**Full answer to give in an interview:**

> "Raft divides time into numbered terms. Within each term there is at most one leader. All nodes start as followers and wait for a heartbeat from the leader. Each follower's wait time is a random duration between 150 and 300 milliseconds — the randomisation is the key trick that prevents multiple nodes from timing out simultaneously. When a follower's timer fires without receiving a heartbeat, it becomes a candidate: it increments its term counter and sends a RequestVote RPC to all other nodes. A node grants its vote if two conditions hold: it has not already voted in this term, and the candidate's log is at least as up-to-date as its own. 'At least as up-to-date' means the candidate's last log entry has a higher term, or the same term and a longer log. This second condition is the election safety guarantee — it ensures a new leader always has all entries that were committed in previous terms. If the candidate receives votes from a strict majority — for a 5-node cluster that means at least 3 — it becomes leader and immediately starts sending heartbeats to suppress other elections."

> *The randomised timeout is the mechanism; the log-completeness check is the safety property. Mention both.*

**Gotcha follow-up they'll ask:** *"What happens to writes during a leader election?"*

> "Writes are unavailable for the duration of the election — typically under a second in a healthy network. The new leader cannot accept writes until it has established its authority by sending heartbeats. Reads may also be stale: a node that was partitioned away might believe it is still leader and serve reads from its own log, which could be behind. The safe solution is the ReadIndex protocol: before serving a read, the leader confirms it is still the leader by getting acknowledgement from a majority, then serves the read at the latest committed index."

---

##### Q2 — Tradeoff Question
**"How is Raft different from Paxos, and why does it matter in practice?"**

**One-line answer:** Raft was designed for understandability — it has an explicit leader, no log gaps, and clean separation of concerns, while Paxos is a family of complex variants with no standard implementation.

**Full answer to give in an interview:**

> "Paxos, in its original single-decree form, specifies how nodes agree on one value. Extending it to a replicated log — called multi-Paxos — requires significant additional protocol that the original paper doesn't fully specify: how to elect a leader, how to fill log gaps, how to handle membership changes. The result is that every production Paxos implementation — Google's Chubby, ZooKeeper's ZAB — is effectively a unique protocol. Raft was designed to be teachable and complete: it cleanly separates leader election, log replication, and membership changes, and forbids log gaps entirely. A follower that is missing entries always gets them from the leader via the AppendEntries RPC rather than having the leader work around gaps. In practice this means Raft implementations like etcd and CockroachDB are far easier to reason about, test, and operate. The performance difference is negligible — both require a majority round trip per commit. The operational difference is significant."

> *State the Paxos incompleteness problem first, then contrast with Raft's completeness. That framing is what interviewers want.*

**Gotcha follow-up they'll ask:** *"Does Raft guarantee linearizable reads?"*

> "Writes are linearizable in Raft because they go through the leader and are committed to a majority before the client gets a response. Reads are not automatically linearizable: a partitioned leader may serve stale reads without knowing it lost its leadership. The fix is the ReadIndex protocol — before serving a read, the leader confirms it still has a majority by exchanging one round of heartbeats, then serves the read at the committed index. etcd implements this and calls it 'serializable reads' versus 'linearizable reads' at the API level."

---

> **Common Mistake — Using even cluster sizes:** A 4-node cluster requires 3 nodes for a majority — tolerating only 1 failure, the same as a 3-node cluster. The extra node adds cost and operational complexity with no gain in fault tolerance. Always use 3, 5, or 7 nodes.

---

**Quick Revision (one line):**
Raft elects a single leader per term via randomised timeouts, replicates a log to a majority before committing, and guarantees safety via the log-completeness election restriction — used in etcd, CockroachDB, and TiKV.

---

## Topic 8: Leader Election

---

#### The Idea

Imagine a team of servers all capable of doing the same job, but to avoid conflicts only one should act as coordinator at a time. The challenge is not electing a leader when everything is working — it is handling the moment when the leader goes silent. Did it crash? Is it just slow? If you declare it dead too quickly and elect a new leader, you might end up with two servers both believing they are in charge — a situation called *split-brain* — and they will overwrite each other's work. If you wait too long, the system is down unnecessarily.

The fundamental obstacle is a JVM garbage-collection pause or an OS scheduling hiccup. A leader that holds a distributed lock can experience a stop-the-world pause lasting several seconds, long enough for the lock service to declare it dead and give the lock to another node. When it wakes up, it does not know it lost leadership and will attempt to write — now competing with the new leader. No amount of careful lock acquisition logic prevents this.

The only robust solution is *fencing tokens*: every time a leader is elected, it receives a monotonically increasing number from the lock service. Every write to shared storage must include that number, and storage systems reject any write whose token is lower than the highest they have seen. This ensures a zombie leader's stale writes are silently rejected even if it never learns it lost its position.

---

#### How It Works

```
ZOOKEEPER EPHEMERAL NODE RECIPE

All nodes compete to become leader:

  1. Each node creates an ephemeral sequential znode at /election/candidate-
     ZooKeeper assigns: candidate-001, candidate-002, candidate-003 ...

  2. Each node reads all children of /election/ and sorts them.

  3. If your znode has the lowest sequence number → you are the leader.

  4. Otherwise → watch the znode with the NEXT LOWER sequence number.
     (Not all nodes watch the minimum — that causes a herd effect on deletion.)

  5. When the watched znode is deleted (that node crashed) → re-read children.
     If you now have the minimum → become leader.

Ephemeral znode auto-deletes when the client's session expires (~30s default).
This is the automatic crash detection mechanism.
```

```
ETCD LEASE RECIPE

  1. Create a lease: etcd.grant(15, SECONDS) → leaseId
  2. Start keepalive to renew lease while process is alive.
  3. PUT /election/leader = nodeId WITH leaseId attached,
     conditional on: createRevision == 0 (key must not already exist).

  4. If txn succeeds → you are the leader.
  5. If txn fails → watch /election/leader for DELETE event, then retry.

  On process death: keepalive stops → lease expires → key deleted → next node wins.

etcd uses Raft internally: at most one node can hold the key at any time.
Use etcd's key revision as your fencing token for downstream writes.
```

```
REDLOCK (5 independent Redis instances)

  To acquire:
    for each of 5 Redis instances:
      SET lockKey token NX PX ttl_ms
    if 3 or more succeed within validity window → lock acquired

  To release:
    Lua script: DEL key only if value == token (atomic check-and-delete)

  Controversy (Martin Kleppmann):
    - Clock jump: a Redis server's wall clock can jump forward (NTP step),
      expiring the lock before the client expects → two holders simultaneously.
    - GC pause: client pauses > TTL, wakes up believing lock is still held.
    - No fencing tokens → cannot protect against zombie writers.

  Safe use: efficiency locks (avoid duplicate work), not correctness-critical mutual exclusion.
```

**Must-memorise gotcha — fencing tokens:**

```java
// Without fencing: GC pause causes split-brain
// Leader L holds lease until T. At T-1s, JVM pauses for 15s GC.
// Lease expires. New leader L2 is elected. L wakes up, still thinks it's leader.
// L and L2 both write to the same storage → data corruption.

// With fencing: storage rejects stale writes
// Every leader election produces a monotonically increasing token.
long fencingToken = etcdKeyRevision; // increases on every new leader

// On every write to shared storage, pass the token:
storageClient.write(key, value, fencingToken);
// Storage layer: reject write if fencingToken < lastSeenToken

// This is the ONLY robust defence against zombie leaders.
// ZooKeeper uses zxid. etcd uses key modifyRevision.
// Implement this in your downstream storage system, not the lock client.
```

*A GC pause longer than the lock TTL makes split-brain possible in any lease-based system. Fencing tokens are the only defence.*

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does ZooKeeper implement leader election, and why do nodes watch their predecessor rather than the current leader?"**

**One-line answer:** Each node creates an ephemeral sequential znode and watches the one directly ahead of it in sequence, so only one notification fires per failure instead of N-1.

**Full answer to give in an interview:**

> "ZooKeeper offers ephemeral znodes — nodes that are automatically deleted when the client's TCP session expires. Leader election uses this property. Every candidate creates an ephemeral sequential znode under a common path, for example `/election/candidate-`. ZooKeeper appends a unique monotonically increasing number to each, so you get `candidate-001`, `candidate-002`, and so on. Each node then reads all children and sorts them. If you hold the lowest sequence number, you are the leader. If not, rather than watching the current minimum — which every follower would do — you watch only the znode with the next lower number than yours. This is crucial: when the leader's znode disappears, if all N-1 followers were watching it, they would all fire simultaneously, generating N-1 watch callbacks and N-1 re-reads of the children list at the same instant — the herd effect. By watching only the predecessor, each deletion triggers exactly one watcher, creating an orderly chain of promotions."

> *The herd effect explanation is what separates a strong answer from a textbook recitation — include it.*

**Gotcha follow-up they'll ask:** *"Is the node with the ZooKeeper session truly safe to act as leader?"*

> "Not without fencing. The ZooKeeper session timeout is around 30 seconds by default. If the leader's network connection is severed but the process is still running, the leader continues to believe it holds its position for up to 30 seconds while ZooKeeper elects a new leader. Both nodes believe they are the leader simultaneously. The safe pattern is to pass ZooKeeper's transaction ID — the zxid — as a fencing token with every write to downstream storage. Any storage system that tracks the highest fencing token it has seen will silently reject the old leader's writes."

---

##### Q2 — Tradeoff Question
**"When would you choose etcd over ZooKeeper for leader election, and what are the limitations of Redlock?"**

**One-line answer:** Prefer etcd for new systems — it is operationally simpler, uses Raft with well-understood semantics, and provides revision numbers as built-in fencing tokens; avoid Redlock for correctness-critical mutual exclusion.

**Full answer to give in an interview:**

> "ZooKeeper is mature and battle-tested — Kafka used it for broker leader election for years — but it requires running a separate JVM-based cluster and deep operational knowledge of ZAB, its Paxos-like consensus protocol. etcd is a single Go binary that uses Raft, has a simpler API, and is already present in any Kubernetes cluster. For new distributed systems I would default to etcd leases: you create a lease with a TTL, attach it to a key with a conditional transaction that only succeeds if the key does not exist, and use the key's revision number as your fencing token for downstream writes. Redlock is different in kind: it does not use any consensus algorithm. It relies on acquiring the same key on a majority of independent Redis instances, and it assumes that clock drift and network delays stay within a predictable bound. Martin Kleppmann's critique is correct — if a Redis server's NTP clock jumps forward, or if the lock-holding client experiences a GC pause longer than the TTL, two clients can simultaneously believe they hold the lock. Redlock is appropriate for reducing duplicate work in idempotent jobs, not for protecting correctness-critical mutual exclusion."

> *Name Kleppmann and the specific vulnerabilities — clock jumps and GC pauses. That signals you have read the literature.*

**Gotcha follow-up they'll ask:** *"Can you make Redlock safe with fencing tokens?"*

> "Redlock itself does not produce fencing tokens — there is no monotonically increasing counter that downstream storage can check. You would need to implement a separate counter, at which point you are essentially implementing a different protocol. If you need fencing tokens, use etcd or ZooKeeper, both of which expose revision or zxid natively. Redlock's author Salvatore Sanfilippo acknowledges this — his position is that Redlock is for efficiency, not for systems where two clients holding the lock simultaneously would corrupt data."

---

> **Common Mistake — Implementing election without fencing tokens:** Acquiring the lock correctly is not enough. A GC pause or OS scheduling delay can cause a node to hold the lock past its TTL expiry. Without fencing tokens accepted by the downstream storage layer, split-brain corruption is possible even with perfect lock acquisition logic.

---

**Quick Revision (one line):**
Leader election uses ZooKeeper ephemeral sequential nodes (ZAB), etcd conditional leases (Raft), or Redlock (majority Redis quorum) — but only fencing tokens plus conditional writes in downstream storage prevent a zombie leader from causing data corruption after a GC pause.

---

## Topic 9: DynamoDB Deep Dive

---

#### The Idea

DynamoDB is Amazon's fully managed NoSQL database, and its central design philosophy is that every query must be answerable by looking up a single partition — no joins, no full-table scans in the critical path. You achieve this by choosing a *partition key* that routes each item to a specific shard, and an optional *sort key* that lets you range-query or sort items within that partition. The data model forces you to think about access patterns first and schema second.

The most important concept to internalise is the hot partition problem. DynamoDB divides its capacity across partitions, and each partition handles a fixed ceiling of read and write units. If every request goes to the same partition key — for example, all traffic for a viral product ID — that one partition is saturated even if the rest of the table is completely idle and has spare capacity. This is the single most common production failure mode with DynamoDB.

DynamoDB offers two index types to support secondary access patterns. A Local Secondary Index (LSI) keeps the same partition key as the base table but uses a different sort key — it must be created at table creation time and supports strongly consistent reads. A Global Secondary Index (GSI) can use entirely different partition and sort keys, can be added to an existing table, but only supports eventually consistent reads. Understanding which to use and when is a core interview topic.

---

#### How It Works

```
DATA MODEL

Table = collection of items
Item  = set of attributes (like a JSON object), max 400 KB
Every item identified by: partition key (PK) + optional sort key (SK)

DynamoDB hashes PK → routes to a partition node.
Items with the same PK are stored contiguously, sorted by SK.

Partition limits:
  3,000 RCU  (read capacity units) per partition per second
  1,000 WCU  (write capacity units) per partition per second

1 RCU  = 1 strongly consistent read of up to 4 KB
       = 2 eventually consistent reads of up to 4 KB
1 WCU  = 1 write of up to 1 KB
Transactions cost 2× normal RCU/WCU.
```

```
INDEX TYPES

LSI (Local Secondary Index):
  Same PK as base table, different SK.
  Created at table creation only (cannot add later).
  Shares base table's capacity.
  Supports strong OR eventual consistency.
  Max 5 per table.

GSI (Global Secondary Index):
  Entirely different PK and SK.
  Can be added after table creation.
  Separate capacity (every base-table write propagates to all GSIs).
  Eventually consistent only.
  Max 20 per table.

Rule of thumb:
  Need strong consistency → LSI.
  Need flexible access pattern after launch → GSI.
  Writes to GSI cost extra RCU/WCU — include in capacity planning.
```

```
SINGLE-TABLE DESIGN (example: e-commerce)

Access patterns: get order, list orders by customer, list items in order.

PK                  SK                      Entity
CUSTOMER#c1         CUSTOMER#c1             customer profile
CUSTOMER#c1         ORDER#2024-01-15#o1     order (sortable by date)
ORDER#o1            ITEM#p1                 order line item
PRODUCT#p1          PRODUCT#p1             product catalog

GSI1: (GSI1PK, GSI1SK) for inverted patterns
  e.g., find all customers who ordered product P:
    GSI1PK = PRODUCT#p1, GSI1SK = CUSTOMER#c1

Pattern: overload PK/SK with entity-type prefixes so one table holds all entities.
Use sparse GSIs: only items with the GSI attribute are indexed → lower cost.
```

**Must-memorise gotcha — hot partition:**

```java
// HOT PARTITION PROBLEM
// Bad partition key: low-cardinality or traffic-skewed attribute

// WRONG: status as partition key — all "PENDING" orders go to one partition
String pk = "STATUS#PENDING";  // every new order hits the same partition
// Result: partition saturated at 1,000 WCU/s even if table has 100,000 WCU provisioned.

// WRONG: product ID when one product is viral
String pk = "PRODUCT#bestseller-123";  // all reads for the hit product → one partition

// RIGHT: high-cardinality partition key
String pk = "ORDER#" + orderId;  // each order in its own partition → even distribution

// RIGHT: write sharding for truly hot keys
String pk = "PRODUCT#bestseller-123#" + (writerId % 10);  // spread across 10 partitions
// Then query all 10 shards and aggregate at the application layer.

// DynamoDB Adaptive Capacity (automatic) partially mitigates hot partitions
// by redistributing capacity, but it has limits — design your key first.
```

*All traffic to one partition key saturates that partition's capacity ceiling even if the rest of the table's total provisioned capacity is unused. Design partition keys for uniform distribution.*

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between a Local Secondary Index and a Global Secondary Index in DynamoDB?"**

**One-line answer:** An LSI shares the base table's partition key and supports strong consistency but must be created at table creation; a GSI uses a different partition key, can be added later, but is always eventually consistent and has its own capacity cost.

**Full answer to give in an interview:**

> "Both LSIs and GSIs let you query a DynamoDB table on attributes other than the primary key, but they work differently. An LSI keeps the same partition key as the base table and only changes the sort key — so it is useful when you always know the partition (the customer ID, say) but want to sort or filter by a different attribute (order status instead of order date). Because it shares the base table's partition, it can serve strongly consistent reads. The constraint is that LSIs must be declared at table creation time — you cannot add one to an existing table. A GSI, by contrast, can project any attribute as the new partition key, effectively creating a separate view of the data stored on its own partitions. This means a GSI can only serve eventually consistent reads — its data is replicated asynchronously from the base table. GSIs can be added after table creation, which is important for evolving schemas. The hidden cost of GSIs is that every write to the base table propagates to all GSIs, consuming additional write capacity units. If you have five GSIs and write one item, you pay for up to six writes. For read-after-write consistency requirements — for example, in payment systems where you just wrote a record and immediately read it back to confirm — use an LSI or query the base table directly."

> *The read-after-write consistency trap with GSIs is the most common interview follow-up — proactively mention it.*

**Gotcha follow-up they'll ask:** *"Can you make a GSI strongly consistent?"*

> "No. GSIs are replicated asynchronously from the base table, and DynamoDB does not expose a way to request strongly consistent reads on a GSI. If you need strong consistency on a secondary access pattern, you have two options: use an LSI if you can accept the same partition key and the index can be defined at table creation time, or query the base table directly using a filter expression — which may be less efficient but gives you strong consistency."

---

##### Q2 — Design Scenario
**"A product on your DynamoDB-backed e-commerce platform goes viral. How do you handle the hot partition?"**

**One-line answer:** Spread writes across multiple partition key shards by appending a random or modulo suffix, then fan out reads across all shards and aggregate.

**Full answer to give in an interview:**

> "DynamoDB assigns a fixed ceiling to each partition — 3,000 read capacity units and 1,000 write capacity units per second. When a single product ID becomes the partition key and millions of users read it simultaneously, all those requests hit the same physical partition. Even if you have provisioned 100,000 RCUs across the whole table, only 3,000 of them can serve that one partition — you get throttling errors. DynamoDB's Adaptive Capacity feature can partially mitigate this by redistributing capacity to hot partitions automatically, but it has limits and is not a substitute for good key design. The standard solution is write sharding: instead of storing the viral product as a single item under `PRODUCT#p123`, store it as ten items: `PRODUCT#p123#0` through `PRODUCT#p123#9`. On each write, randomly pick a shard. On reads, query all ten keys in parallel and merge the results at the application layer. For read-heavy hot keys that rarely change — like a product catalogue entry — the better solution is to put a cache in front: ElastiCache or DAX (DynamoDB Accelerator), which is a write-through cache native to DynamoDB. DAX reduces read latency from single-digit milliseconds to microseconds and absorbs the hot-key read traffic entirely."

> *Name DAX by name — it signals AWS-specific knowledge that interviewers at Amazon and AWS-heavy shops will notice.*

**Gotcha follow-up they'll ask:** *"What is DynamoDB Adaptive Capacity and does it solve the hot partition problem?"*

> "Adaptive Capacity automatically shifts capacity from cool partitions to hot ones, allowing a single partition to temporarily exceed its baseline allocation. It kicks in within seconds and is transparent to the application. However, it has a hard physical limit — one partition's throughput is bounded by the throughput of the underlying storage node, which DynamoDB does not publish but is finite. For sustained viral traffic, adaptive capacity buys you time but does not solve the problem. It is not a substitute for high-cardinality partition key design or write sharding."

---

##### Q3 — Tradeoff Question
**"When would you choose on-demand capacity mode over provisioned capacity mode?"**

**One-line answer:** Use on-demand for unpredictable or spiky workloads where you cannot forecast traffic; use provisioned with auto-scaling for steady or predictable workloads where cost matters.

**Full answer to give in an interview:**

> "On-demand mode charges per request and scales instantly — there is no capacity to provision or auto-scaling policy to tune. It is the right choice when traffic is genuinely unpredictable, such as a new product launch, a batch job that fires irregularly, or a development table. The cost per request is roughly two to three times higher than provisioned mode at equivalent throughput, so for steady workloads on-demand is significantly more expensive. Provisioned mode lets you set read and write capacity units, optionally with auto-scaling policies that adjust within a min/max range in response to CloudWatch metrics. For production services with predictable traffic patterns — or ones you can model — provisioned with auto-scaling gives you cost control and protection against runaway spend. One important asymmetry: you can switch a table from provisioned to on-demand at any time, but you can only switch back from on-demand to provisioned once every 24 hours. This matters during an incident: switching to on-demand during a traffic spike is easy; switching back cheaply requires planning."

> *The 24-hour cooldown on switching back from on-demand is a real operational gotcha — mention it.*

---

> **Common Mistake — Low-cardinality partition keys:** Using an attribute like `status` (`PENDING`, `SHIPPED`, `DELIVERED`) as the partition key routes the majority of new writes to the `PENDING` partition and causes immediate hot partition throttling. Partition keys must have high cardinality and uniform access distribution.

---

**Quick Revision (one line):**
DynamoDB routes items by partition key hash and range-queries by sort key; LSIs share the PK and support strong consistency, GSIs use independent keys and are eventually consistent; the hot partition problem occurs when all traffic concentrates on one key — fix with write sharding or DAX for reads.

---

## Topic 10: Cassandra Deep Dive

---

#### The Idea

Imagine a circular arrangement of servers — a ring. Every piece of data gets hashed to a point on the ring, and the server that owns that point stores the data. To tolerate failures, data is replicated to the next two servers clockwise. Any server can accept any request and route it to the right replicas. There is no master, no single coordinator, and no single point of failure. This is Cassandra's ring architecture, and it is the reason Cassandra can serve millions of writes per second across multiple datacenters with no downtime for node additions or removals.

The design forces a fundamental constraint: all data for a given partition key lives on the same set of replicas and must be read or written together. You cannot ask Cassandra to join two tables across partitions — there is no cross-partition transaction, no ad-hoc query engine. Before you write a single line of CQL, you must know every read pattern your application needs. This is called *query-first design*, and violating it is the single most common Cassandra mistake in production.

Consistency in Cassandra is tunable. The same cluster can serve requests at eventual consistency (ONE — only one replica must acknowledge) for maximum throughput, or at strong consistency (QUORUM — a majority must acknowledge both reads and writes) when correctness matters. You choose per-request, which means different parts of the same application can have different guarantees from the same cluster.

---

#### How It Works

```
RING ARCHITECTURE

Token space: -2^63 to +2^63 (Murmur3 partitioner)
Each node owns one or more token ranges (vnodes, typically 256 per node).
Vnodes make load distribution even and simplify adding/removing nodes.

To write a row:
  1. Hash(partition_key) → token value
  2. Route to coordinator node (any node can be coordinator)
  3. Coordinator finds the N replica nodes that own the token range
  4. Sends write to all N replicas
  5. Waits for CL acknowledgements before returning to client

Gossip protocol: each node gossips with 1–3 peers every second.
All nodes learn about topology and failures within seconds. No master required.
```

```
REPLICATION STRATEGIES

SimpleStrategy:
  Replicas = next N nodes clockwise on ring.
  Single datacenter only.

NetworkTopologyStrategy:
  Replicas per datacenter specified separately.
  CREATE KEYSPACE ks WITH replication = {
    'class': 'NetworkTopologyStrategy', 'dc1': 3, 'dc2': 2
  };
  Rack-aware: replicas placed on different racks within each DC.

CONSISTENCY LEVELS (read and write):
  ONE    = 1 replica must ack
  QUORUM = RF/2 + 1 replicas must ack (LOCAL_QUORUM for single DC)
  ALL    = all RF replicas must ack
  ANY    = even a hinted handoff counts (write only)

Strong consistency: write CL + read CL > RF
  e.g., QUORUM write + QUORUM read with RF=3: 2+2>3 → guaranteed overlap
```

```
COMPACTION STRATEGIES

STCS (Size-Tiered):  merges SSTables of similar size.
  Best for: write-heavy workloads with few reads.

LCS (Leveled):  maintains N levels, each 10× larger than previous.
  Best for: read-heavy workloads; reduces read amplification.

TWCS (Time-Window):  groups SSTables by time window, drops entire windows on TTL expiry.
  Best for: time-series data with TTL — compaction drops old windows without tombstones.
  Use with: default_time_to_live on the table.

Tombstones:
  Deletes write a marker, not a removal.
  Removed after gc_grace_seconds (default 10 days) by compaction.
  Excessive tombstones cause read latency — prefer TTL over explicit deletes.
```

```
PARTITION KEY DESIGN FOR TIME-SERIES (IoT)

Bad:   sensor_id alone
       → one sensor generates billions of rows → partition overflow

Better: (sensor_id, date)
       → known partition size, but fixed bucket granularity

Best:  (sensor_id, bucket)
       bucket = floor(epoch_seconds / BUCKET_SIZE)
       → tunable; e.g., daily bucket = floor(epoch_seconds / 86400)

Clustering key: recorded_at DESC
       → most-recent-first queries read the top of the SSTable
```

**Must-memorise gotcha — no joins, no transactions, query-first design:**

```java
// WRONG: designing schema like a relational database
// Table: orders (order_id, customer_id, product_id, status, created_at)
// Table: customers (customer_id, name, email)
// Plan: JOIN orders o ON o.customer_id = c.customer_id WHERE c.email = 'x'
// → Cassandra cannot do this. No JOINs. No subqueries. Full table scan required.

// RIGHT: one table per query pattern
// Query: "get all orders for a customer, sorted by date"
// Table: orders_by_customer
//   PRIMARY KEY ((customer_id), created_at, order_id)
//   CLUSTERING ORDER BY (created_at DESC)

// Query: "get order by ID"
// Table: orders_by_id
//   PRIMARY KEY (order_id)

// You maintain TWO tables and write to BOTH on every order creation.
// This is the Cassandra way: denormalize, duplicate, design around reads.

// Cassandra's "transactions":
// - Lightweight transactions (LWT): IF NOT EXISTS / IF condition → uses Paxos, slow
// - Use only for uniqueness checks, not as a general transaction mechanism
// - Batch: provides atomicity for same-partition writes, NOT cross-partition
```

*Cassandra does not support joins or multi-partition transactions. Every query pattern requires its own table. Design the tables from the queries, not the data.*

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Explain Cassandra's ring architecture and how replication works."**

**One-line answer:** Each node owns a range of hash values on a token ring, and data is replicated to the next N nodes clockwise; any node can serve any request as coordinator with no single master.

**Full answer to give in an interview:**

> "Cassandra maps the entire key space — typically a 64-bit integer range from negative two to the sixty-third to positive two to the sixty-third — onto a circular ring. Each node is assigned one or more token ranges on that ring using virtual nodes, or vnodes. By default each physical node owns 256 vnodes spread across the ring, which means data is distributed evenly even if nodes have different capacities, and adding a new node only requires migrating a fraction of the data from many existing nodes rather than half the data from one. When a client writes a row, the partition key is hashed by the Murmur3 algorithm to produce a token. The coordinator node — any node that received the request — looks up which replica nodes own that token range according to the replication factor and the replication strategy. With NetworkTopologyStrategy and a replication factor of 3 in a datacenter, three replicas are placed on different racks within that datacenter. The coordinator sends the write to all replicas simultaneously and waits for the number of acknowledgements specified by the consistency level before responding to the client. There is no master: every node knows the full ring topology through the gossip protocol, which exchanges state between one to three random peers every second. A node failure is detected within seconds without any central coordinator."

> *Mention vnodes explicitly — they are the mechanism for even distribution and easy rebalancing; many candidates skip them.*

**Gotcha follow-up they'll ask:** *"How does Cassandra handle a node failure during a write?"*

> "When a replica is down at write time, the coordinator uses hinted handoff: it stores the write locally as a 'hint' — a record of the write that was intended for the failed node. When that node comes back online, the coordinator replays the hints. Hinted handoff is configurable; hints are stored for a maximum window (default 3 hours). For longer outages, the recovered node uses read repair and anti-entropy repair — a background process that uses Merkle trees to compare data across replicas and synchronise differences. If you write at consistency level ONE and the only available replica is storing a hint, the write succeeds but the data is not yet on any permanent replica — this is the tradeoff of low consistency levels."

---

##### Q2 — Design Scenario
**"Design a Cassandra schema for an IoT platform storing sensor readings that needs to query the last 24 hours of data for a specific sensor."**

**One-line answer:** Use a composite partition key of (sensor_id, daily_bucket) and a clustering column of recorded_at DESC so each day's readings for one sensor form a single, bounded partition.

**Full answer to give in an interview:**

> "The query pattern drives everything in Cassandra. The query is: give me all readings for sensor X in the last 24 hours. That translates to: I know the sensor ID, I know the time range. The partition key must contain sensor ID so all of a sensor's data lands on the same set of replicas. But using sensor ID alone is dangerous for a busy sensor that writes every second — over months that partition grows unbounded and eventually cannot be read efficiently. The fix is time-bucketing: add a daily bucket to the partition key, computed as the floor of the Unix timestamp divided by 86,400 — the number of seconds in a day. Now each partition holds exactly one day of data for one sensor, which is predictable and bounded. For a 24-hour query you almost always hit just one partition. For a query spanning midnight you query two partitions — both known before you start — and merge the results at the application layer. The clustering key is `recorded_at DESC` so the most recent readings are at the head of each SSTable and short-range queries avoid scanning the entire partition. Use TimeWindowCompactionStrategy with a one-day window to match the bucket size, and set a TTL of 30 days — TWCS drops entire expired windows without accumulating tombstones, which is critical for read latency."

> *Explaining why TWCS matches the bucket size is the detail that separates a senior answer — make that connection explicit.*

**Gotcha follow-up they'll ask:** *"What happens if you use `ALLOW FILTERING` in production?"*

> "`ALLOW FILTERING` tells Cassandra to perform a full scan of all partitions that match the partition key criteria, applying a filter in memory on each node that receives the scatter request. For a single partition this is merely inefficient. For a query without a partition key predicate it is a cluster-wide full table scan — every node reads every SSTable, applies the filter, and the coordinator merges the results. At any non-trivial scale this saturates disk I/O, causes garbage collection pressure, and starves concurrent reads. It is effectively `SELECT *` with a `WHERE` clause executed in Java. The correct fix is always to create a new table or GSI — in Cassandra's case, a new denormalised table — that makes the desired access pattern a partition-key lookup."

---

##### Q3 — Tradeoff Question
**"Cassandra is described as an AP database. Is that accurate?"**

**One-line answer:** It depends on the consistency level — with QUORUM reads and writes Cassandra is effectively CP; the AP characterisation applies at low consistency levels like ONE.

**Full answer to give in an interview:**

> "The CAP theorem classification is a simplification, and Cassandra is a good example of why. The AP label means: in a partition, choose availability over consistency. That is true when you use low consistency levels like ONE — a write succeeds as long as one replica acknowledges, even if the others are unreachable, so you have high availability but potentially stale reads. But Cassandra's consistency level is tunable per request. If you write at QUORUM — which requires acknowledgement from the majority of replicas — and read at QUORUM, the read and write sets are guaranteed to overlap because two times (RF divided by two plus one) is greater than RF. That is strong consistency. With ALL consistency level — all replicas must respond — Cassandra is effectively CP: it will refuse to serve a request if any replica is unreachable. So Cassandra's position on the CAP spectrum depends entirely on how you configure it. Most teams use LOCAL_QUORUM for cross-datacenter deployments, which gives strong consistency within each datacenter while allowing each datacenter to operate independently if the inter-DC link fails."

> *The formula — write quorum plus read quorum greater than RF implies overlap — is the key mathematical point. State it explicitly.*

---

> **Common Mistake — Modelling data like a relational schema:** Cassandra cannot join tables or run ad-hoc queries across partitions. Designing tables first and figuring out queries later always results in full-cluster `ALLOW FILTERING` scans in production. Always start with the access patterns, then design one table per query.

---

**Quick Revision (one line):**
Cassandra's masterless ring replicates data to N consecutive nodes; consistency is tunable per-request from ONE to ALL; TWCS compaction is optimal for time-series with TTL; and because Cassandra has no joins or multi-partition transactions, every read pattern requires its own denormalised table — design queries first, schema second.

---

## Topic 11: MongoDB Deep Dive

---

#### The Idea

Imagine you have a filing cabinet full of paper forms. A relational database forces every form to have the same fields — you pre-print 50 columns and most stay blank. MongoDB works the opposite way: each document is a flexible JSON envelope. A user record can embed an array of addresses right inside it instead of joining across three tables. You query one document, you get everything you need — no JOIN tax.

The aggregation pipeline is MongoDB's answer to SQL's GROUP BY and JOINs. Instead of writing a SQL statement, you describe a sequence of stages — filter here, group there, reshape the output at the end — and MongoDB executes them on the server in one round trip.

Sharding is how MongoDB scales writes beyond one machine. A mongos router sits in front of the cluster. Your application talks only to mongos; it consults a config server to find which shard holds which chunk of data, then routes the request transparently. From your application's perspective, there is one database; behind the scenes, data is spread across many replica sets.

---

#### How It Works

```
Document model
  Collection: "orders"
  Document:   { _id, customerId, items: [...], shippingAddress: {...} }
  Flexible schema — each document can differ in fields
  16 MB BSON size limit — embed for 1:few, reference for 1:many high-cardinality

Aggregation pipeline (server-side, sequential stages)
  db.orders.aggregate([
    { $match:   { status: "completed" } },   // stage 1: filter
    { $unwind:  "$items" },                   // stage 2: flatten array
    { $group:   { _id: "$items.productId",    // stage 3: aggregate
                  total: { $sum: "$items.qty" } } },
    { $sort:    { total: -1 } },              // stage 4: order
    { $limit:   10 }                          // stage 5: top-10
  ])
  RAM limit per stage: 100 MB — use allowDiskUse: true for large datasets

Replica set
  1 primary (reads + writes) + N secondaries (read replicas + failover)
  Oplog: capped collection on primary, secondaries tail it to stay in sync
  Election: if primary is unreachable, secondaries elect a new primary (Raft-like)
  writeConcern w:majority — write acknowledged only after majority of nodes persist it

Transactions (MongoDB 4.0+)
  Multi-document ACID transactions within a replica set
  Multi-shard transactions supported from 4.2+
  Expensive — grab a session, start transaction, commit/abort
  Prefer single-document atomicity when possible (faster, no 2PC overhead)

Sharding
  mongos (router) — your app talks only here
  Config servers — store chunk metadata (which shard owns which key range)
  Chunks — 64 MB key-range segments, auto-balanced across shards
  Shard key choice:
    Hashed  → uniform write distribution, no range scans
    Ranged  → range scans fast, but risk hot-spot on monotonic keys (ObjectId, timestamp)
```

Must-memorise gotcha — unbounded array growth:

```java
// DANGEROUS: storing every event inside the parent document
db.users.updateOne(
    { _id: userId },
    { $push: { events: newEvent } }   // array grows forever
);
// When the array hits thousands of entries the document
// approaches the 16 MB BSON limit and update latency spikes.
// MongoDB must rewrite the entire document on disk when it outgrows its allocated space.

// CORRECT: reference pattern — store events in a separate collection
db.userEvents.insertOne({ userId, timestamp, type, payload });
// Query with a targeted index — no document size ceiling.
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is MongoDB's aggregation pipeline, and how does it differ from a SQL GROUP BY query?"**

**One-line answer:** The aggregation pipeline is a sequence of data-transformation stages executed server-side, equivalent to chained SQL clauses but composable and more expressive for document reshaping.

**Full answer to give in an interview:**

> "In SQL you write one declarative statement — SELECT, FROM, WHERE, GROUP BY, HAVING, ORDER BY — and the database figures out execution. MongoDB's aggregation pipeline is more explicit: you describe each transformation step in sequence. A `$match` stage filters documents (like WHERE), a `$group` stage aggregates them (like GROUP BY), a `$project` stage reshapes the output (like SELECT with computed fields), and a `$lookup` stage joins another collection (like a LEFT JOIN). Each stage outputs documents that flow into the next stage. The advantage is composability — you can insert a `$unwind` to flatten an embedded array before grouping, which has no clean SQL equivalent. The trade-off is that aggregation pipelines have a 100 MB per-stage RAM limit by default, so you need `allowDiskUse: true` for large datasets. For analytics on huge collections, a dedicated tool like Spark reading from MongoDB is often more appropriate."

> *Keep it concrete — mention the stage names and the RAM limit. That signals hands-on experience.*

**Gotcha follow-up they'll ask:** *"What happens if an aggregation pipeline stage exceeds 100 MB of memory?"*

> "The stage throws an error — `'Exceeded memory limit for $group, but did not opt in to external sorting'`. The fix is to add `{ allowDiskUse: true }` to the aggregate options, which lets MongoDB spill intermediate results to disk. For very large aggregations you should also push the `$match` and `$sort` stages as early as possible so subsequent stages process a smaller dataset."

---

##### Q2 — Tradeoff Question
**"When would you embed a sub-document versus using a reference in MongoDB, and what is the risk of getting this wrong?"**

**One-line answer:** Embed when data is co-accessed and bounded in size; reference when the nested data can grow unboundedly or is shared across many parent documents.

**Full answer to give in an interview:**

> "The embedding-versus-reference decision in MongoDB is driven by two questions: how often is the nested data accessed together with the parent, and how large can the nested data grow? If a user always needs their shipping addresses when you fetch their profile, embed the addresses array — one document read, no join. But if a user can place thousands of orders, embedding all orders inside the user document is dangerous. MongoDB has a hard 16 MB BSON document size limit. An embedded array that grows without bound will eventually hit that ceiling, causing write failures and performance degradation as MongoDB rewrites larger and larger documents on disk. The correct pattern for high-cardinality one-to-many relationships — user to events, product to reviews — is a reference: store the parent ID in the child collection and use an index on that foreign key. You trade one extra query for safety and scalability. The rule of thumb: embed for `1:1` and `1:few` with stable, bounded size; reference for `1:many` and `many:many`."

> *The 16 MB limit is the interviewer's target — mention it explicitly.*

**Gotcha follow-up they'll ask:** *"How does MongoDB 4.0's multi-document transaction support change this design decision?"*

> "Before 4.0, MongoDB guaranteed atomicity only within a single document, which was a strong incentive to embed related data. Since 4.0, multi-document ACID transactions are available — you can update a parent document and a separate child collection atomically. This makes the reference pattern safer for use-cases that previously needed embedding for atomicity. However, transactions in MongoDB are still more expensive than in a relational database because they involve two-phase commit across replica set nodes and hold locks during the transaction. The guidance remains: prefer single-document atomicity for performance-critical paths, and use transactions only when you genuinely need cross-document consistency."

---

##### Q3 — Design Scenario
**"You are designing a sharded MongoDB cluster for a high-write IoT system. What shard key would you choose and why?"**

**One-line answer:** Use a hashed shard key on the device ID to distribute writes uniformly across shards and avoid hot-spotting.

**Full answer to give in an interview:**

> "The biggest mistake in shard key selection is choosing a monotonically increasing value like a timestamp or MongoDB ObjectId with ranged sharding. All new writes land on the last chunk — the one with the highest key values — turning that shard into a hot spot while the others sit idle. For an IoT system with continuous high-frequency writes, I would use a hashed shard key on `deviceId`. Hashing converts the device ID into a uniform distribution across chunks, so writes spread evenly regardless of insertion order. The trade-off is that range queries on `deviceId` — 'give me all readings for devices D1 through D100' — become scatter-gather operations across all shards, which is slower than a ranged shard key would allow. For IoT analytics that query by time range across all devices, I would add a compound index on `{ deviceId, timestamp }` and accept the scatter-gather cost for dashboard queries, since write throughput is the bottleneck. If range queries are equally critical, a compound shard key of `{ deviceId, timestamp }` with zone sharding can co-locate each device's data on one shard while still distributing devices across shards."

> *Mention hot-spotting by name — it shows you know the canonical failure mode.*

**Gotcha follow-up they'll ask:** *"How does mongos handle a query that does not include the shard key in its filter?"*

> "Without the shard key in the filter, mongos cannot determine which shard holds the matching documents. It broadcasts the query to all shards — a scatter-gather — and merges the results. This is correct but expensive: latency scales with the slowest shard, and every shard bears the read load. For collections where non-shard-key queries are frequent, add secondary indexes on the query fields. Each shard maintains its own index, so mongos still scatters the query, but each shard uses the index locally instead of doing a full collection scan."

---

> **Common Mistake — Unbounded Array Growth:** Pushing events, logs, or messages into an embedded array without a growth ceiling will eventually cause the document to exceed MongoDB's 16 MB BSON limit, resulting in `BSONObjectTooLarge` write errors in production. Always use a reference collection for one-to-many relationships with high or unbounded cardinality.

---

**Quick Revision (one line):**
MongoDB stores flexible BSON documents; use the aggregation pipeline for server-side analytics; replica sets provide HA via oplog replication; mongos routes sharded queries transparently; never embed unbounded arrays — reference instead to stay within the 16 MB document limit.

---

## Topic 12: Time-Series Databases

---

#### The Idea

Imagine a power meter that records voltage 10 times per second for every device in a factory. Over a month, that is billions of rows. A traditional relational database stores each reading as a separate row — an INSERT per event, a B-tree index update per row, and a table that grows until queries grind to a halt. Time-series databases are purpose-built for this exact pattern: an append-only, time-ordered flood of numeric measurements.

The key insight is that time-series data is almost never updated or deleted randomly. Readings arrive in timestamp order and are mostly read in time ranges — "give me the last hour of CPU metrics." This access pattern allows a fundamentally different storage design: column-oriented storage where all values for one metric are stored together, compressed aggressively because adjacent values are similar.

Downsampling is the other killer feature. You do not need millisecond resolution for a trend chart covering six months. Time-series databases let you define continuous aggregates — "pre-compute the 1-minute average of every metric every minute" — so dashboards query a 100-row summary instead of 600,000 raw rows. InfluxDB calls these continuous queries; TimescaleDB calls them continuous aggregates.

---

#### How It Works

```
Why NOT a relational DB for high-frequency time-series
  Each event = one INSERT + one B-tree index update
  Index update is random I/O — amplified write cost
  Table bloat: 10,000 sensors × 10 readings/sec × 1 month = 26 billion rows
  Vacuum, autovacuum, MVCC overhead compounds the problem

Column-oriented storage (InfluxDB TSM, TimescaleDB compression)
  Traditional row store: [time, sensor, value] [time, sensor, value] ...
  Column store:          [time, time, time, ...] | [sensor, sensor, ...] | [value, value, ...]
  Numeric columns compress 10-50x (delta encoding + run-length encoding)
  Sequential disk reads for time-range queries — CPU cache friendly

Time-based partitioning (TimescaleDB hypertables)
  One logical table "sensor_readings" splits into chunks by time interval (e.g. 7 days)
  Query planner applies chunk exclusion: "WHERE time > NOW() - INTERVAL '1 hour'"
  Only the current chunk is scanned — past chunks are skipped entirely
  Old chunks can be compressed independently or tiered to cold storage

InfluxDB concepts
  Measurement  → table analogy
  Tags         → indexed string dimensions (device_id, region) — low cardinality!
  Fields       → numeric values (temperature, voltage) — not indexed
  Retention policy → auto-delete data older than N days
  Series cardinality = unique (measurement, tag-set) combinations
    → High cardinality (e.g., user_id as a tag) blows up the in-memory index

Downsampling (continuous aggregates)
  TimescaleDB:
    CREATE MATERIALIZED VIEW sensor_1min
    WITH (timescaledb.continuous) AS
    SELECT time_bucket('1 minute', time), sensor_id,
           avg(value), max(value), min(value)
    FROM sensor_readings GROUP BY 1, 2;

  InfluxDB task (Flux):
    every: 1m, query raw, write 1-min averages to a separate bucket
    Raw bucket: 7-day retention. Aggregate bucket: 1-year retention.
```

Must-memorise gotcha — never use row-per-event in a relational DB for high-frequency time-series:

```sql
-- WRONG: relational DB, one row per IoT event, 10k sensors at 10 Hz
CREATE TABLE sensor_events (
    id          BIGSERIAL PRIMARY KEY,   -- B-tree index updated every insert
    sensor_id   UUID NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL,
    value       DOUBLE PRECISION
);
-- After 1 month: 26 billion rows, index bloat, autovacuum can't keep up,
-- writes slow from microseconds to milliseconds.
-- Symptom: pg_stat_bgwriter shows constant checkpoint pressure.

-- CORRECT: TimescaleDB hypertable (PostgreSQL extension)
SELECT create_hypertable('sensor_events', 'recorded_at',
                         chunk_time_interval => INTERVAL '1 day');
-- Now: chunk exclusion skips all but the relevant day-partition,
-- compression reduces storage 10x, continuous aggregates serve dashboards.
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Why is a standard relational database a poor fit for high-frequency time-series data, and what specifically makes InfluxDB or TimescaleDB better?"**

**One-line answer:** Relational databases incur write amplification from B-tree index updates on every INSERT; time-series databases use column-oriented storage and time-based partitioning to achieve 10-100x better write throughput and compression.

**Full answer to give in an interview:**

> "The core problem is write amplification. A relational database like PostgreSQL maintains a B-tree index on every indexed column. Every INSERT updates the index — that is a random write to a page that may not be in memory. At 10,000 sensors writing 10 readings per second, you have 100,000 random I/Os per second just for index maintenance. SSDs handle this better than spinning disks, but it still burns I/O bandwidth and causes page eviction pressure in the buffer pool. InfluxDB addresses this with its TSM — Time-Structured Merge — storage engine: writes go to an in-memory store first, then are flushed to immutable columnar files and compacted in the background, similar to an LSM tree. Reads scan compressed column files sequentially rather than traversing a B-tree. TimescaleDB takes a different approach: it is a PostgreSQL extension that partitions your table into time-based chunks automatically. Queries with a time-range filter skip irrelevant chunks entirely — chunk exclusion — so a query for the last hour only touches the current chunk, not five years of history. Both solutions also offer native downsampling — pre-aggregated rollups — so dashboards query a summary table with hundreds of rows instead of billions of raw measurements."

> *Mention write amplification and chunk exclusion by name — they are the canonical technical terms.*

**Gotcha follow-up they'll ask:** *"What is the high-cardinality problem in InfluxDB and how do you avoid it?"*

> "In InfluxDB, tags are indexed dimensions — every unique combination of tag values defines a separate time series in memory. If you use `user_id` as a tag, and you have one million users, you create one million series. InfluxDB keeps the series index in memory, so high cardinality causes memory exhaustion and slow compaction. The fix is to keep tags genuinely low-cardinality — device type, region, environment — and put high-cardinality identifiers like user IDs or request IDs in fields instead of tags. Fields are not indexed, so queries on them do a full scan within the time range, but that is usually acceptable."

---

##### Q2 — Tradeoff Question
**"What is downsampling in a time-series context, and how would you implement a tiered retention strategy?"**

**One-line answer:** Downsampling pre-aggregates raw high-resolution data into lower-resolution summaries, allowing you to discard raw data after a short window while retaining trends for years.

**Full answer to give in an interview:**

> "Raw time-series data is enormous and most of it goes stale quickly. For a CPU metric sampled every second, you need second-level resolution only for incident investigation over the last few hours. For a quarterly capacity planning report, one-minute or one-hour averages are sufficient. Downsampling is the process of computing those averages — min, max, avg, percentile — and writing them to a lower-resolution series or table. A tiered retention strategy stacks this: keep raw data for 7 days, keep 1-minute aggregates for 90 days, keep 1-hour aggregates for 2 years, keep daily aggregates forever. In TimescaleDB I would implement this with continuous aggregates — a materialized view that automatically refreshes every minute — plus a data retention policy that drops raw chunks older than 7 days. In InfluxDB 2.x I would use tasks to write downsampled data to a separate bucket with a longer retention policy, and set a short TTL on the raw bucket. The key design principle is that continuous aggregation must happen before the raw data expires — if the refresh interval is 1 hour and retention is 7 days, the aggregate lags by at most 1 hour, which is acceptable."

> *Mentioning the refresh-before-expiry constraint shows operational maturity.*

**Gotcha follow-up they'll ask:** *"How do you handle late-arriving data — events that arrive after the time window has already been aggregated?"*

> "Late-arriving data is a genuine challenge for continuous aggregates. In TimescaleDB, continuous aggregates have a `refresh_lag` parameter that keeps a refresh window open for late data — for example, always recompute the last 2 hours. If data arrives within that window, the aggregate is updated correctly. For data arriving beyond the lag window, you have to manually trigger a refresh: `CALL refresh_continuous_aggregate('sensor_1min', older_bound, newer_bound)`. In streaming systems like Kafka with Flink, the standard pattern is watermarking — accept events up to a configurable late-arrival tolerance, then close the window and emit the result."

---

##### Q3 — Design Scenario
**"Design a metrics pipeline for 50,000 IoT sensors each writing 1 reading per second. What database would you use and how would you structure the schema?"**

**One-line answer:** Use TimescaleDB with a hypertable partitioned by time, compressed chunks, and a continuous aggregate for dashboard queries.

**Full answer to give in an interview:**

> "Fifty thousand sensors at one reading per second is 50,000 writes per second — well within TimescaleDB's range on modest hardware. I would create a hypertable on the `time` column with a 1-day chunk interval. Chunk interval choice matters: too small means too many chunks and planning overhead; too large means compressing a big chunk takes longer. One day is a safe default for this volume. For compression I would set a compression policy that compresses chunks older than 7 days — this uses delta-delta encoding for timestamps and delta encoding for numeric values, achieving roughly 10x compression. For the schema I would use `(time TIMESTAMPTZ, sensor_id UUID, metric_name TEXT, value DOUBLE PRECISION)`. I would add a compound index on `(sensor_id, time DESC)` for per-sensor queries and rely on chunk exclusion for time-range queries. For dashboards I would create a continuous aggregate at 1-minute resolution refreshing every minute. Dashboard queries would hit the aggregate — a few thousand rows — rather than the 50,000-row-per-second raw table. I would also add a data retention policy dropping raw chunks after 90 days to control storage growth."

> *Walk through the chunk interval, compression policy, and continuous aggregate in sequence — it shows end-to-end operational thinking.*

**Gotcha follow-up they'll ask:** *"Why is TimescaleDB sometimes preferred over InfluxDB for teams already using PostgreSQL?"*

> "TimescaleDB is a PostgreSQL extension — it speaks standard SQL, supports foreign keys, JOINs, and transactions, and works with every PostgreSQL-compatible tool: psql, pgAdmin, JDBC, Hibernate. Teams do not need to learn a new query language like InfluxQL or Flux, and they can JOIN time-series data with relational tables in the same query — for example, joining sensor readings with a devices reference table to filter by device location. InfluxDB is purpose-built for time-series and can be faster at extreme ingest rates, but it requires a separate query language, separate tooling, and cannot do cross-data-model JOINs without application-level logic."

---

> **Common Mistake — Row-per-Event in a Relational DB:** Using a plain PostgreSQL table with a BIGSERIAL primary key for high-frequency time-series data causes write amplification from B-tree index maintenance, autovacuum lag, and table bloat. Performance degrades non-linearly as the table grows. Always use a time-series-native engine (InfluxDB, TimescaleDB) for data volumes above a few thousand writes per second.

---

**Quick Revision (one line):**
Time-series DBs solve write amplification with column-oriented storage and time-partitioning; InfluxDB uses TSM + tags/fields + retention policies; TimescaleDB uses PostgreSQL hypertables + chunk exclusion + continuous aggregates; never store high-frequency events row-per-event in a plain relational table.

---

## Topic 13: Full-Text Search with Elasticsearch

---

#### The Idea

Imagine a library with a million books. Finding all books that contain the word "distributed" on any page requires reading every page of every book — that is a full table scan. An inverted index solves this: before any query arrives, the library builds a lookup table that maps every word to the list of books containing it. "distributed" → [Book 42, Book 107, Book 953]. Elasticsearch is built on this data structure.

Relevance scoring is what separates a search engine from a simple keyword filter. When you search for "distributed systems", you do not just want all documents that contain those words — you want the most relevant ones first. Elasticsearch scores documents using BM25 (an evolution of TF-IDF): documents where your search terms appear more frequently and in a smaller document score higher. Terms that appear in many documents are less informative (stop words like "the"), so they contribute less to the score.

The critical distinction to carry into every design conversation: Elasticsearch is a search and analytics engine, not a primary database. It does not support ACID transactions. Writes are eventually consistent — an indexed document may not be searchable for a fraction of a second. Always maintain a source-of-truth database (PostgreSQL, MongoDB) and sync to Elasticsearch asynchronously.

---

#### How It Works

```
Inverted index construction (at index time)
  Document: "Distributed systems use consensus algorithms"
  Analyzer pipeline:
    1. Tokenizer:   ["Distributed", "systems", "use", "consensus", "algorithms"]
    2. Lowercase:   ["distributed", "systems", "use", "consensus", "algorithms"]
    3. Stop words:  ["distributed", "systems", "consensus", "algorithms"]  (remove "use")
    4. Stemmer:     ["distribut", "system", "consensus", "algorithm"]
  Inverted index:
    "distribut"  → [doc1, doc5, doc12]
    "system"     → [doc1, doc3, doc8, doc12]
    "consensus"  → [doc1, doc7]
    "algorithm"  → [doc1, doc2, doc7]

Relevance scoring: BM25
  Score(doc, query) = Σ IDF(term) × TF(term, doc) / (TF + k1 × (1 - b + b × docLen/avgDocLen))
  IDF (Inverse Document Frequency): rare terms score higher than common ones
  TF  (Term Frequency): more occurrences in a document = higher score, but with diminishing returns
  k1, b: tuning parameters (default k1=1.2, b=0.75)

Query context vs Filter context
  Query context  → calculates a relevance _score (expensive, not cacheable)
    { "match": { "title": "distributed systems" } }
  Filter context → yes/no match, no score (cheap, results are cached)
    { "filter": { "term": { "status": "published" } } }
  Best practice: combine — filter first to shrink the candidate set, then score

Shards vs Replicas
  Shard   = a self-contained Lucene index (primary copy)
  Replica = copy of a shard (read scalability + fault tolerance)
  Index:  { "settings": { "number_of_shards": 3, "number_of_replicas": 1 } }
  Shards cannot be changed after index creation (reindex required)
  Rule of thumb: shard size 10–50 GB; too many small shards wastes memory on overhead

Mapping types
  text    → analyzed, full-text searchable, not aggregatable
  keyword → not analyzed, exact match, aggregatable (facets, sorting)
  date, integer, float, boolean → structured, filterable
  Dual-field mapping: title.keyword (exact) + title (analyzed)
  Dynamic mapping: risky in production — can explode mapping with unexpected fields
```

Must-memorise gotcha — Elasticsearch is NOT a primary database:

```java
// WRONG: using Elasticsearch as the source of truth
public Order getOrder(String orderId) {
    // If ES hasn't indexed this yet (eventual consistency window),
    // or if an index corruption forces a reindex, order is "lost"
    return elasticsearchClient.get(orderId, Order.class);
}

// CORRECT: dual-write architecture
public Order createOrder(OrderRequest req) {
    // 1. Write to the source-of-truth DB first (ACID guaranteed)
    Order order = postgresRepository.save(req.toOrder());

    // 2. Publish event; async consumer indexes to ES
    eventBus.publish(new OrderCreatedEvent(order));

    // 3. Return from the authoritative store
    return order;
}

// Read path:
//   Search queries  → Elasticsearch (relevance, full-text)
//   ID lookups      → PostgreSQL (authoritative, consistent)
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does Elasticsearch's inverted index work, and how does BM25 score a document?"**

**One-line answer:** An inverted index maps every analyzed token to the list of documents containing it; BM25 scores documents by weighing term frequency with diminishing returns against inverse document frequency, penalising very long documents.

**Full answer to give in an interview:**

> "When you index a document in Elasticsearch, an analyzer pipeline runs over the text fields. It tokenizes the text into terms, lowercases them, removes stop words like 'the' and 'a', and optionally applies a stemmer so 'running' and 'runs' map to the same root token 'run'. These processed tokens are added to an inverted index — a sorted map from token to a posting list containing the IDs of every document that contains that token, plus metadata like term frequency and field positions. At query time, Elasticsearch looks up your query terms in the inverted index, retrieves the candidate document sets, takes their intersection or union depending on the query type, and scores them. BM25 — the default scoring algorithm since Elasticsearch 5.0 — is an improvement over plain TF-IDF. It rewards documents where query terms appear frequently, but with diminishing returns: the tenth occurrence of 'distributed' in a document adds far less to the score than the first. It also uses IDF — inverse document frequency — so terms that appear in almost every document (like common nouns) contribute less to relevance than rare, specific terms. Finally, BM25 normalises for document length: a short document where 'distributed' appears once is more relevant than a long document where it also appears once buried in 10,000 words."

> *Mention the analyzer pipeline and the BM25 length normalisation — these are the details that distinguish strong answers.*

**Gotcha follow-up they'll ask:** *"What is the difference between query context and filter context, and why does it matter for performance?"*

> "In Elasticsearch, a query clause in query context calculates a floating-point relevance score — `_score` — for every matching document. This computation is expensive and the results are not cacheable because scores depend on the overall index statistics. A query clause in filter context answers only yes/no: does this document match? There is no score computation. Filter results are cached in a bit-set per segment, so re-running the same filter is essentially free. The practical pattern is to use filter context for structured criteria — status equals 'published', date in a range, category equals 'electronics' — to eliminate non-matching documents cheaply, and then use query context only for the full-text search part that needs scoring. In a bool query this looks like: `must` clause with the `match` query (scored), and a `filter` clause with `term` and `range` queries (not scored, cached)."

---

##### Q2 — Tradeoff Question
**"What is the difference between shards and replicas in Elasticsearch, and how do you choose shard count for an index?"**

**One-line answer:** Shards are the unit of horizontal scaling for both storage and write throughput; replicas are copies of shards that add read throughput and fault tolerance but do not increase write capacity.

**Full answer to give in an interview:**

> "Each Elasticsearch index is divided into a configurable number of primary shards. Each shard is a self-contained Lucene index — it holds a subset of the documents and can be placed on any node. Adding more primary shards lets you spread storage across more nodes and parallelize writes. Replicas are additional copies of primary shards. A primary shard with one replica means two copies of the data exist. Replicas serve read requests, so adding replicas increases search throughput. However, writes must be replicated to all copies — replicas do not help write throughput, they increase it slightly because the primary must do more work. The critical constraint is that the number of primary shards cannot be changed after the index is created without a full reindex operation, which involves creating a new index and using the `_reindex` API to copy all documents. This makes initial shard sizing important. The rule of thumb is to target shard sizes between 10 and 50 GB and to keep the number of shards proportional to the number of data nodes. Too many small shards are expensive because Elasticsearch allocates memory overhead per shard regardless of its size — each shard is a Lucene instance with open file handles, segment metadata, and JVM heap usage."

> *The reindex-required constraint is the key gotcha — mention it explicitly.*

**Gotcha follow-up they'll ask:** *"What happens to search availability when a primary shard's node fails?"*

> "If a node fails and it held a primary shard, Elasticsearch promotes one of that shard's replicas to become the new primary automatically. This is handled by the cluster master node — it detects the failure, updates the cluster state, and promotes the replica, typically within a few seconds. During this window, the shard is unavailable for writes but can still serve reads from the replica. If no replica exists — `number_of_replicas: 0` — the shard is lost until the node recovers. For production clusters, always set at least one replica, and distribute primary shards and their replicas across different availability zones."

---

##### Q3 — Design Scenario
**"Design a product search feature for an e-commerce site using Elasticsearch. What fields would you map, and how would you keep ES in sync with your primary database?"**

**One-line answer:** Map text fields as both analyzed and keyword sub-fields, use a dual-write pattern via an event queue to sync from PostgreSQL to ES, and use filter context for structured facets plus query context for full-text scoring.

**Full answer to give in an interview:**

> "For an e-commerce product search I would define the ES mapping with `name` and `description` as `text` fields using a custom analyzer — standard tokenizer, lowercase, optional synonym filter for 'laptop' / 'notebook'. I would also add a `.keyword` sub-field on `name` for exact-match sorting. Structured dimensions like `category`, `brand`, and `status` would be `keyword` — not analyzed — for faceted filtering and aggregation. `price` and `stock_count` would be numeric. For the sync architecture, PostgreSQL is the source of truth. On every product create/update/delete, the application publishes an event to a Kafka topic. A separate consumer service reads from Kafka and writes to Elasticsearch using the bulk API for throughput efficiency. This gives eventual consistency — there is a short lag between a product update and its appearance in search results, which is acceptable for e-commerce. For the query itself, I would build a bool query with a `filter` clause for facets — `term: {category: 'laptops'}`, `range: {price: {gte: 500}}` — and a `must` clause with a `multi_match` query on `name` and `description` for full-text scoring. Filter clauses are cached; the multi_match clause computes BM25 scores only on the filtered subset."

> *Calling out the filter-before-score pattern and the Kafka sync is the signal of a production-aware answer.*

**Gotcha follow-up they'll ask:** *"How would you handle a full reindex without downtime when you need to change the mapping?"*

> "The standard pattern is index aliasing. Instead of pointing the application directly at `products_v1`, you point it at an alias called `products`. To reindex: create `products_v2` with the new mapping, run the `_reindex` API to copy documents from `products_v1` to `products_v2`, and once the reindex completes, atomically swap the alias with a single API call — remove `products → products_v1`, add `products → products_v2`. The application sees no interruption. During the reindex, writes that arrive must go to both the old and new index — either via dual-write in the sync consumer or by re-processing the event queue from a point-in-time offset."

---

> **Common Mistake — Elasticsearch as Primary Database:** Storing records only in Elasticsearch and querying it for ID lookups or transactional reads exposes you to eventual consistency gaps (a document just written may not yet be searchable) and data loss risk (Elasticsearch's replication is best-effort, not ACID). Always keep a relational or document database as the authoritative source and treat Elasticsearch as a derived, queryable projection.

---

**Quick Revision (one line):**
Elasticsearch builds an inverted index at ingest time; BM25 scores documents by term frequency and inverse document frequency; primary shards determine storage scaling, replicas add read capacity; never use ES as a primary DB — maintain a source-of-truth store and sync asynchronously.

---

## Topic 14: Database Migration Strategies

---

#### The Idea

Imagine you need to rename a street while cars are still driving on it. You cannot close the street, rename it, and reopen it — that is offline maintenance with downtime. Instead, you add the new street sign alongside the old one, let traffic learn the new name gradually, then remove the old sign once no one references it. This is the expand-contract pattern for database migrations.

Database schema changes are among the riskiest operations in production engineering. Adding a column is usually safe. Renaming a column without coordination can silently break the running application because old code writes to the old name and new code reads from the new name — these are different columns, so data is lost. The critical skill is sequencing migrations so any schema state is compatible with both the currently deployed code and the code about to be deployed.

Flyway and Liquibase are migration management tools that track which SQL scripts have already been applied and ensure they are applied in order across every environment — development, staging, production — reproducibly. The difference is in philosophy: Flyway is SQL-first and simple; Liquibase is database-agnostic and supports rollback.

---

#### How It Works

```
Migration tool concepts

Flyway
  Versioned scripts: V1__create_users.sql, V2__add_email_index.sql
    Applied in order, checksums prevent modification of applied scripts
  Repeatable scripts: R__create_views.sql (re-runs when content changes)
  flyway_schema_history table tracks applied migrations
  Spring Boot: spring.flyway.enabled=true, classpath:db/migration/

Liquibase
  Changelog: XML, YAML, JSON, or SQL format
  Changesets: <changeSet id="1" author="alice"> ... </changeSet>
  Rollback: each changeset can define a rollback block (Flyway Teams only)
  generateChangeLog: reverse-engineer existing schema
  Database-agnostic: same changelog deploys to PostgreSQL or Oracle

Zero-downtime migration patterns

1. Adding a new column (safe)
   ALTER TABLE users ADD COLUMN phone VARCHAR(20);   -- nullable, instant
   → Old code ignores it. New code starts writing it.

2. Adding NOT NULL column (DANGEROUS without planning)
   ALTER TABLE users ADD COLUMN phone VARCHAR(20) NOT NULL;
   → On large tables: full table rewrite, exclusive lock, minutes of downtime

3. Correct NOT NULL pattern (expand-contract, 3 deployments)
   Step 1 - Expand:
     ALTER TABLE users ADD COLUMN phone VARCHAR(20);  -- nullable
     Deploy code that writes phone on new records
   Step 2 - Backfill:
     UPDATE users SET phone = ... WHERE phone IS NULL; -- batched, no lock
   Step 3 - Contract:
     ALTER TABLE users ALTER COLUMN phone SET NOT NULL;  -- fast, all rows populated
     ALTER TABLE users ADD CONSTRAINT phone_not_null CHECK (phone IS NOT NULL) NOT VALID;
     ALTER TABLE users VALIDATE CONSTRAINT phone_not_null;  -- offline validate, no lock

4. Zero-downtime column rename (4 deployments)
   Step 1: Add new column "new_name", write to both old and new
   Step 2: Backfill new_name from old_name for existing rows
   Step 3: Read from new_name, stop writing to old_name
   Step 4: Drop old_name column
```

Must-memorise gotcha — NOT NULL without default causes full table rewrite:

```sql
-- DANGEROUS: adding NOT NULL column to a live 100M-row table
ALTER TABLE users ADD COLUMN phone VARCHAR(20) NOT NULL DEFAULT 'unknown';
-- PostgreSQL must rewrite every row to include the default value.
-- On a 100M-row table: 10–30 minutes, exclusive lock, full outage.

-- CORRECT: three-phase migration
-- Phase 1: Add nullable column (sub-second, no lock)
ALTER TABLE users ADD COLUMN phone VARCHAR(20);

-- Phase 2: Backfill in small batches (runs live, no lock)
DO $$
DECLARE
  batch_size INT := 10000;
  last_id BIGINT := 0;
BEGIN
  LOOP
    UPDATE users
    SET phone = lookup_phone(id)
    WHERE id > last_id AND phone IS NULL
    RETURNING id INTO last_id;
    EXIT WHEN NOT FOUND;
    PERFORM pg_sleep(0.01);  -- yield to avoid I/O saturation
  END LOOP;
END $$;

-- Phase 3: Add NOT NULL constraint (validates without full rewrite in PostgreSQL 12+)
ALTER TABLE users ADD CONSTRAINT users_phone_not_null
  CHECK (phone IS NOT NULL) NOT VALID;          -- metadata only, instant
ALTER TABLE users VALIDATE CONSTRAINT users_phone_not_null;  -- scans, but no lock
ALTER TABLE users ALTER COLUMN phone SET NOT NULL;  -- fast: constraint already validated
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the expand-contract pattern for database migrations, and when is it necessary?"**

**One-line answer:** Expand-contract is a three-phase technique — add the new schema alongside the old, migrate data, then remove the old — so any intermediate schema state is compatible with both the old and new version of the deployed application.

**Full answer to give in an interview:**

> "The expand-contract pattern, sometimes called parallel-change, solves the deployment ordering problem: you cannot atomically replace both your schema and your running application. There will always be a window — however brief — where the old code and new schema coexist, or the new code and old schema coexist. The expand phase makes the schema backward-compatible: if you are renaming a column from `user_name` to `username`, you add the new column and update the application to write to both. The old code still writes to the old column, the new code writes to both. In the contract phase, once you are certain no running instance references the old column, you drop it. This pattern is necessary whenever you are removing or renaming a column, changing a column's type, or splitting a column — any structural change that would break existing code that runs against the new schema. It is not needed for pure additions that are nullable and have no application-level mandatory constraint."

> *Distinguish additive-safe migrations from structural changes — that is what interviewers are testing.*

**Gotcha follow-up they'll ask:** *"How do Flyway and Liquibase differ in their approach to rollbacks?"*

> "Flyway's free tier does not support automated rollback. If a migration fails, you manually fix the data and then run `flyway repair` to clear the failed entry from the schema history table. Flyway Teams adds `U` (undo) migrations — `U2__Undo_add_email.sql` — which you write manually and Flyway can run on demand. Liquibase supports rollback natively via a `rollback` block inside each changeset — you declare exactly what SQL to run to reverse the change. However, rollback is not magic: if the changeset added a column and you roll it back, the `DROP COLUMN` DDL loses the data in that column permanently. Rollback scripts are most useful for structural changes that have no data in the new columns yet, or for reverting indexes and constraints. For data migrations, a forward-only strategy — write a new migration to undo what the bad one did — is often safer because it preserves the audit trail in the schema history."

---

##### Q2 — Tradeoff Question
**"How do you rename a column in PostgreSQL without causing downtime?"**

**One-line answer:** Use a four-phase expand-contract: add the new column, dual-write in application code, backfill old data, then drop the old column — never use ALTER TABLE RENAME COLUMN on a live table with active application deployments.

**Full answer to give in an interview:**

> "A direct `ALTER TABLE users RENAME COLUMN user_name TO username` is a metadata-only operation in PostgreSQL — it is very fast and acquires only a brief lock. The danger is not the DDL itself; it is the deployment sequencing. The moment the rename executes, any running application instance that reads or writes `user_name` gets a column-not-found error. In a rolling deployment with 20 application pods, some pods will be on the old version and some on the new version simultaneously. If the rename has already run, all old-version pods break. The expand-contract sequence avoids this entirely. Migration 1: add column `username` as nullable, deploy app version 2 that writes to both `user_name` and `username`. Migration 2: run a backfill script — `UPDATE users SET username = user_name WHERE username IS NULL` — in batches to populate historical rows. Migration 3: deploy app version 3 that reads from `username` and stops writing to `user_name`. Migration 4: once all version 2 pods are drained, run `ALTER TABLE users DROP COLUMN user_name`. Each migration is independently safe with the corresponding app version."

> *Walking through the four phases in sequence is the full answer — most candidates stop at 'use the expand-contract pattern' without the specifics.*

**Gotcha follow-up they'll ask:** *"What risk does Flyway's checksum validation introduce for hotfix deployments?"*

> "Flyway computes a checksum of every applied migration script and stores it in `flyway_schema_history`. If anyone edits a migration script after it has been applied — even to fix a comment — Flyway will refuse to run on the next deployment with a checksum mismatch error. This is intentional: it prevents accidental schema drift between environments. The problem in a hotfix scenario is that a developer might try to modify an already-applied migration instead of creating a new one. The correct response is: never edit applied migrations. Create a new versioned migration that corrects the mistake. If a migration was only applied in development and genuinely needs fixing before it reaches staging, use `flyway repair` to remove the history entry, fix the script, and re-apply — but only before the migration has been promoted beyond the local environment."

---

##### Q3 — Design Scenario
**"You need to split a `full_name` column into `first_name` and `last_name` with zero downtime. Walk through the migration plan."**

**One-line answer:** Use expand-contract over four deployments: add the new columns, dual-write in code, backfill, then drop the old column.

**Full answer to give in an interview:**

> "This is a classic structural split migration. Step one — expand: write and apply a Flyway migration that adds `first_name VARCHAR(100)` and `last_name VARCHAR(100)` as nullable columns. Both columns are nullable so the DDL is instant with no table rewrite. Deploy application version 2 alongside version 1 — version 2 parses `full_name` on write and populates all three columns. Step two — backfill: run a data migration script that loops over rows where `first_name IS NULL`, splits the existing `full_name` on the first space, and writes the parts. This runs against the live table in small batches with a brief sleep between batches to avoid overwhelming I/O. Step three — contract the reads: deploy application version 3 that reads exclusively from `first_name` and `last_name`, writes to all three columns for backward compatibility with any lagging version 2 pods. Step four — contract the schema: once all version 2 and version 3 pods are confirmed drained from the load balancer, apply the final migration: `ALTER TABLE users DROP COLUMN full_name`. Add NOT NULL constraints on `first_name` and `last_name` using the NOT VALID / VALIDATE CONSTRAINT pattern to avoid a table rewrite. The whole process spans four separate deployments spread over days or weeks depending on the team's deployment cadence."

> *The key detail is that version 2 writes to all three columns during the transition — that is what protects you if you need to roll back to version 1.*

**Gotcha follow-up they'll ask:** *"What happens if your Flyway migration runs on startup and the migration script throws an error halfway through on a production server?"*

> "Flyway marks the migration as failed in the `flyway_schema_history` table — the entry gets a state of `FAILED`. On the next startup attempt Flyway refuses to run any further migrations until the failure is resolved, to prevent applying migrations out of order. If the DDL was wrapped in a transaction — which PostgreSQL supports for most DDL — the partial changes are rolled back automatically. If it was not transactional — for example, a concurrent index creation or a large backfill — the partial changes remain on disk. The resolution steps are: fix the data manually to restore a consistent state, then run `flyway repair` to remove or mark-as-successful the failed history entry, then restart the application. This is why large data migrations — backfills of millions of rows — should never be part of a Flyway migration that runs on startup. They should be separate operational scripts run by an engineer with monitoring and the ability to pause."

---

> **Common Mistake — NOT NULL Column Without Default on a Live Table:** Running `ALTER TABLE ADD COLUMN phone VARCHAR(20) NOT NULL` or `NOT NULL DEFAULT 'x'` on a large live table causes PostgreSQL to rewrite every row to include the default, holding an access exclusive lock for the duration — potentially minutes. Always add the column as nullable first, backfill in batches, then add the constraint using `NOT VALID` / `VALIDATE CONSTRAINT` to avoid a blocking rewrite.

---

**Quick Revision (one line):**
Use expand-contract for zero-downtime structural changes; Flyway tracks versioned SQL scripts via checksum, Liquibase adds native rollback; never add a NOT NULL column without a default to a live table — add nullable, backfill, then add constraint.

---

## Topic 15: Performance Benchmarking

---

#### The Idea

Imagine tuning a car engine. You would not claim the car is fast based on how it sounds — you would put it on a dyno and measure horsepower and torque under controlled load. Database performance benchmarking is the same discipline: measure actual throughput and latency under realistic conditions before claiming the system is production-ready.

The trap most engineers fall into is measuring the wrong thing. A single-threaded benchmark cannot reveal lock contention. A test run on cold storage does not reflect the steady-state behaviour of a warmed buffer cache. And averages lie: if 99% of requests complete in 5 ms but 1% take 10 seconds, the average looks fine while real users experience timeouts. Percentile latency — P95, P99, P99.9 — is the correct metric.

Diagnosing a slow database is a structured process. First, identify whether the bottleneck is CPU, I/O, memory, or network. PostgreSQL's system views — `pg_stat_activity`, `pg_stat_user_tables`, `pg_stat_bgwriter`, `pg_locks` — expose the internal state of the database engine at query time. The skill is knowing which view answers which question.

---

#### How It Works

```
Benchmark tools
  pgbench (PostgreSQL built-in)
    pgbench -i -s 100 mydb          # initialise 100x scale (1.4M rows)
    pgbench -c 50 -j 4 -T 60 mydb   # 50 clients, 4 threads, 60-second run
    Reports: TPS, latency average, latency stddev
    Custom scripts: -f custom.sql for application-realistic workloads

  sysbench (MySQL, general purpose)
    sysbench oltp_read_write --threads=32 --time=60 run
    TPC-C: standard OLTP benchmark (orders, stock, warehouses) — vendor-neutral

Key metrics
  TPS (Transactions Per Second)  — throughput
  P50, P95, P99, P99.9 latency   — distribution tells the story averages hide
  Cache hit ratio                 — should exceed 99% for OLTP
    SELECT sum(blks_hit) / (sum(blks_hit)+sum(blks_read)) FROM pg_stat_database;
  Connection utilisation          — active vs idle vs idle_in_transaction

Diagnosing bottlenecks with PostgreSQL system views

  1. Long-running queries (CPU / bad plan)
     SELECT pid, now()-query_start AS duration, query
     FROM pg_stat_activity
     WHERE state = 'active' AND query_start < now() - INTERVAL '5s'
     ORDER BY duration DESC;

  2. I/O pressure (buffer misses)
     SELECT relname, heap_blks_read, heap_blks_hit,
            heap_blks_hit::float/(heap_blks_hit+heap_blks_read) AS hit_ratio
     FROM pg_statio_user_tables
     WHERE heap_blks_read > 0
     ORDER BY heap_blks_read DESC LIMIT 10;

  3. Lock waits (contention)
     SELECT blocked.pid, blocked.query AS blocked_query,
            blocking.pid AS blocking_pid, blocking.query AS blocking_query
     FROM pg_locks blocked_locks
     JOIN pg_stat_activity blocked ON blocked.pid = blocked_locks.pid
     JOIN pg_locks blocking_locks ON blocking_locks.transactionid = blocked_locks.transactionid
     JOIN pg_stat_activity blocking ON blocking.pid = blocking_locks.pid
     WHERE NOT blocked_locks.granted;

  4. Checkpoint pressure (write I/O)
     SELECT checkpoints_timed, checkpoints_req,
            buffers_checkpoint, buffers_clean, buffers_backend
     FROM pg_stat_bgwriter;
     -- buffers_backend high → WAL writes are forced by backends, not checkpointer
     -- Increase checkpoint_completion_target and shared_buffers

  5. Slow queries (aggregate over time)
     SELECT query, calls, total_exec_time/calls AS avg_ms,
            rows/calls AS avg_rows
     FROM pg_stat_statements
     ORDER BY total_exec_time DESC LIMIT 10;
     -- Reset between test runs: SELECT pg_stat_statements_reset();

Connection pooling
  PostgreSQL: one process per connection = ~5–10 MB RAM, OS scheduling overhead
  Above ~200 connections: throughput plateaus, latency rises (context switching)
  PgBouncer: connection pool proxy
    Session pooling:     1:1 client-to-server connection (no benefit)
    Transaction pooling: server connection held only for duration of transaction
                         supports hundreds of app threads on 20 server connections
    Statement pooling:   only for simple autocommit queries
```

Must-memorise gotcha — single-threaded benchmark hides concurrency bottlenecks:

```java
// WRONG: benchmark with a single thread
public void benchmarkSingleThread() {
    long start = System.currentTimeMillis();
    for (int i = 0; i < 100_000; i++) {
        orderRepo.findByCustomerId(customerId);  // serialised, no lock contention
    }
    long elapsed = System.currentTimeMillis() - start;
    System.out.println("TPS: " + (100_000_000.0 / elapsed));
    // Reports 50,000 TPS — sounds great.
    // Under 200 concurrent users, real TPS drops to 800 due to connection pool
    // exhaustion and row-level lock contention. The single-thread test never saw this.
}

// CORRECT: concurrent benchmark with pgbench or a custom multi-threaded harness
// pgbench -c 200 -j 8 -T 120 mydb -f order_lookup.sql
// Reports: TPS under realistic concurrency, P99 latency, stddev
// Reveals: connection pool saturation, hot-row lock contention, index bloat under load

// After the benchmark, diagnose with:
// SELECT wait_event_type, wait_event, count(*)
// FROM pg_stat_activity WHERE state != 'idle'
// GROUP BY 1, 2 ORDER BY 3 DESC;
// Lock waits appear as wait_event_type = 'Lock'
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How would you identify whether a slow PostgreSQL database is bottlenecked on CPU, I/O, or lock contention?"**

**One-line answer:** Query `pg_stat_activity` for active query count and wait events, `pg_statio_user_tables` for cache hit ratios to identify I/O pressure, and `pg_locks` joined to `pg_stat_activity` to find blocked queries and their blockers.

**Full answer to give in an interview:**

> "I approach this as a layered diagnosis. First I check `pg_stat_activity` filtered to state equals 'active' — if there are dozens of long-running queries all with `wait_event_type` of 'CPU', the bottleneck is the query plan and possibly missing indexes. If `wait_event` shows 'DataFileRead', queries are reading from disk rather than the buffer pool — I/O is the bottleneck. To confirm I/O pressure I check `pg_statio_user_tables`: the ratio of `heap_blks_hit` to `heap_blks_hit + heap_blks_read` should be above 99% for an OLTP workload. A ratio of 80% means 20% of block reads are going to disk — either the buffer pool (`shared_buffers`) is too small, or a large table scan is evicting hot pages. For lock contention I join `pg_locks` to `pg_stat_activity` to find queries waiting for a lock and the query that is holding it. A long-running UPDATE or an idle transaction that forgot to commit are common culprits. Checkpoint pressure — excessive write I/O from WAL flushing — shows up in `pg_stat_bgwriter`: if `buffers_backend` is high relative to `buffers_checkpoint`, backends are being forced to write dirty buffers themselves, and `checkpoint_completion_target` or `shared_buffers` needs tuning."

> *Walking through all three diagnostic paths — CPU, I/O, lock — is the complete answer.*

**Gotcha follow-up they'll ask:** *"Why does adding more database connections sometimes make performance worse?"*

> "PostgreSQL's architecture spawns a separate OS process for every client connection. Each process consumes roughly 5–10 MB of RSS memory plus a share of the buffer pool. At low connection counts the bottleneck is query execution. Above roughly 100–200 connections, the OS scheduler has to context-switch between hundreds of processes on a handful of CPU cores, and memory pressure from the per-process overhead starts evicting buffer pages. The result is counter-intuitive: TPS goes up until around 150 connections, then plateaus, then drops as connections increase further. The correct solution is not to limit connections at the application level — that means threads wait for a connection and you lose the ability to burst. The correct solution is PgBouncer with transaction pooling: application threads each get a client connection to PgBouncer immediately, but only 20–50 actual server-side PostgreSQL connections exist. Each server connection is leased for the duration of one transaction, then returned to the pool."

---

##### Q2 — Tradeoff Question
**"What is the difference between `EXPLAIN` and `EXPLAIN ANALYZE` in PostgreSQL, and when should you use each?"**

**One-line answer:** `EXPLAIN` shows the query planner's estimated execution plan without running the query; `EXPLAIN ANALYZE` executes the query and shows actual row counts and timings, revealing where the planner's estimates are wrong.

**Full answer to give in an interview:**

> "`EXPLAIN` is safe to run on any query including destructive writes — it outputs the planner's chosen execution plan: index scans versus sequential scans, nested loop versus hash join, estimated rows and cost at each node. The cost numbers are in arbitrary units calibrated to the planner's cost model. `EXPLAIN ANALYZE` runs the query for real and adds two critical fields to each node: the actual row count versus the estimated row count, and the actual time in milliseconds. The gap between estimated and actual rows is where most performance problems hide. If the planner estimated 100 rows but 10 million were returned, the hash join it chose is catastrophically wrong — it should have used a merge join or a different index. The planner's row estimates come from the statistics in `pg_statistic`, updated by `ANALYZE`. Stale statistics after a large data import cause exactly this kind of mis-estimate. `EXPLAIN ANALYZE` with `BUFFERS` adds cache hit and miss counts per node, pinpointing which join or scan is doing the most physical I/O. For a complex query in production, I always use `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` to get the full picture. One important caution: `EXPLAIN ANALYZE` runs the query — if it is a write, the write happens. Wrap it in a transaction and roll back if you need to analyze a destructive query safely."

> *The estimated vs actual row count gap is the killer detail — it is what most candidates miss.*

**Gotcha follow-up they'll ask:** *"How does `pg_stat_statements` differ from `EXPLAIN ANALYZE` for ongoing performance monitoring?"*

> "`EXPLAIN ANALYZE` is a one-time diagnostic tool — you run it on a specific query you suspect is slow. `pg_stat_statements` is a PostgreSQL extension that automatically records aggregate statistics for every unique query shape — normalised to replace literal values with parameters. It accumulates total execution count, total execution time, min/max/mean time, rows returned, and block reads. You query it like a table: `SELECT query, calls, total_exec_time/calls AS avg_ms FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10`. This tells you which query patterns consume the most total database time across all executions — not just the slowest single execution, but the most impactful. An individual query that takes 500 ms and runs 100,000 times per day is more important to optimise than one that takes 5 seconds and runs once a week. Reset it before a benchmark run with `SELECT pg_stat_statements_reset()` so you capture only the test workload."

---

##### Q3 — Design Scenario
**"Production PostgreSQL is showing elevated P99 latency (2 seconds) on an endpoint that usually responds in 50 ms. Walk through your diagnosis."**

**One-line answer:** Check active queries and wait events in `pg_stat_activity`, then check lock contention via `pg_locks`, then check I/O via cache hit ratio, then check for checkpoint pressure in `pg_stat_bgwriter`.

**Full answer to give in an interview:**

> "My first query is always `pg_stat_activity`: `SELECT pid, now()-query_start AS age, wait_event_type, wait_event, left(query,80) FROM pg_stat_activity WHERE state='active' ORDER BY age DESC`. If I see dozens of sessions with `wait_event_type='Lock'`, it is a lock contention spike — a slow transaction is holding a row or table lock and everyone else is queued. I then run the lock contention query against `pg_locks` to find the blocking pid and its query. The fix is usually to kill the blocking session or to find the long-running transaction that forgot to commit. If wait events show `DataFileRead`, I check the cache hit ratio in `pg_statio_user_tables`. A drop from 99.5% to 85% means something is doing large sequential scans and evicting the buffer pool — often a new slow query, a missing index, or an autovacuum full-table scan running concurrently. If `pg_stat_bgwriter` shows `checkpoints_req` rising — meaning checkpoints are triggered by dirty buffer pressure rather than on schedule — I/O is saturated by write amplification. I would check `pg_stat_statements` for queries with high `blk_write_time` and look at whether a bulk import or update is running. Finally I check connection counts: `SELECT state, count(*) FROM pg_stat_activity GROUP BY state`. If `idle_in_transaction` is high, leaked transactions are holding locks and connections, compounding everything else."

> *Running through the four views in sequence — activity, locks, I/O, bgwriter — is the structured answer interviewers are looking for.*

**Gotcha follow-up they'll ask:** *"What is connection pool oversizing and how does PgBouncer solve it?"*

> "Connection pool oversizing is when an application maintains more simultaneous database connections than PostgreSQL can efficiently serve. Because each PostgreSQL connection is a separate OS process, 500 connections means 500 processes competing for CPU time on perhaps 16 cores. Even if most connections are idle, the kernel's process scheduler and the PostgreSQL lock manager incur overhead proportional to connection count. PgBouncer sits between the application and PostgreSQL as a proxy. In transaction pooling mode, the application's connection pool can have 500 logical connections to PgBouncer, but PgBouncer maintains only, say, 30 physical server-side connections to PostgreSQL. When a transaction begins, PgBouncer leases one of the 30 physical connections; when the transaction commits, the physical connection returns to the pool immediately, ready for the next application request. The application never waits for a physical connection as long as total concurrent transactions stay below 30. This decouples application-level concurrency from PostgreSQL process count, eliminating the degradation curve above 200 connections."

---

> **Common Mistake — Single-Threaded Benchmarking:** Running a load test with a single thread produces misleadingly optimistic throughput numbers because it serialises all operations and eliminates lock contention, connection pool pressure, and cache thrashing. Production workloads are concurrent — always benchmark with at least as many threads as the expected peak connection count, and measure P99 latency, not averages.

---

**Quick Revision (one line):**
Benchmark with pgbench at realistic concurrency and measure P99 latency; diagnose via `pg_stat_activity` (wait events), `pg_statio_user_tables` (cache hit ratio), `pg_locks` (contention), and `pg_stat_bgwriter` (checkpoint pressure); use PgBouncer transaction pooling to decouple application connection count from PostgreSQL process overhead.
