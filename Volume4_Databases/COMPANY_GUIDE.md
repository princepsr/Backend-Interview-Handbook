# Volume 4: Databases — Company Guide

## Which Companies Go Deep on Databases

| Company | SQL Depth (1-5) | Distributed DB (1-5) | What They Specifically Test |
|---|---|---|---|
| Goldman Sachs / FinTech | 5 | 3 | Isolation levels, deadlock prevention, ACID for financial records |
| Amazon / AWS | 3 | 5 | DynamoDB patterns, sharding, RDS vs DynamoDB tradeoffs |
| Google | 4 | 5 | Spanner/Bigtable concepts, distributed transactions, consensus awareness |
| Stripe | 5 | 3 | Idempotency at DB level, optimistic locking, ACID for payments |
| Atlassian / Salesforce | 4 | 3 | Multi-tenant query optimization, connection pooling, large-dataset SQL |
| Flipkart / Indian Product | 4 | 4 | SQL optimization, N+1 in ORM, Redis as DB cache, sharding for scale |
| Uber / Lyft | 3 | 5 | Geospatial indexing, time-series partitioning, distributed DB tradeoffs |

---

## Company-Specific Tips

### Goldman Sachs / FinTech
ACID is non-negotiable — financial data cannot have phantom reads, non-repeatable reads, or lost updates. Expect detailed questions on isolation level selection for specific transaction scenarios (e.g., "two trades updating the same account balance simultaneously — what isolation level and why?"). Deadlock prevention patterns matter: always acquire locks in a consistent order, use SELECT FOR UPDATE with a timeout, prefer optimistic locking for read-heavy paths. Know the difference between a DB-level transaction and an application-level saga, and why sagas do not give you atomicity.

### Amazon / AWS
DynamoDB is the centerpiece: single-table design, partition key + sort key selection, GSI/LSI trade-offs, and what happens when your partition key has low cardinality. Know when DynamoDB's eventual consistency is acceptable vs when you need strongly consistent reads (and the cost). Sharding strategy questions: consistent hashing, write throughput per partition, and hotspot mitigation (add a random suffix to the partition key). RDS vs DynamoDB is a common comparison: relational integrity vs horizontal scale — know the boundary.

### Google
Spanner and Bigtable are discussed as reference architectures, not just products. Spanner questions focus on external consistency (stronger than serializability) using TrueTime, and why globally distributed transactions are possible. Bigtable questions focus on row key design for scan locality and avoiding hot tablets. Consensus awareness (Paxos/Raft at a conceptual level) is expected — you do not need to implement Raft, but you need to know why quorum writes are needed for linearizability.

### Stripe
Every payment operation must be idempotent at the database layer — not just the API layer. Optimistic locking with a version column prevents concurrent updates to the same payment record from corrupting state. Expect questions on how you prevent double-charge when a network timeout causes a retry: the answer involves an idempotency key stored in the DB with the result, checked before processing. ACID isolation at Serializable for payment finalization, with explicit trade-off explanation for why lower isolation is risky here.

### Atlassian / Salesforce
Multi-tenant data models: shared schema (tenant_id column everywhere) vs schema-per-tenant vs DB-per-tenant — each with query, isolation, and migration trade-offs. Query optimization for large SaaS datasets: explain how an index on `tenant_id, created_at` enables efficient per-tenant time-range queries. Connection pooling is a real concern at SaaS scale — PgBouncer, pool sizing, and the difference between transaction-mode and session-mode pooling. Know how schema migrations work safely under traffic (expand/contract pattern, non-blocking DDL).

### Flipkart / Indian Product
Practical SQL optimization is tested with realistic e-commerce schemas: orders, inventory, users. JPA/Hibernate N+1 is a common scenario — identify it from slow query logs and fix with JOIN FETCH or batch loading. Redis as a DB cache layer: cache-aside pattern, TTL selection, cache stampede prevention (mutex or probabilistic early expiry). Sharding for scale: how do you shard an orders table without routing all queries to one shard? Expect a conversation about read replicas for reporting queries.

---

## The 5 DB Questions That Always Come Up

1. **"Walk me through ACID. Which isolation level would you use for a payment transaction and why?"**
   Strong answer: name the anomaly each level prevents, choose Repeatable Read or Serializable for payments, explain the throughput vs correctness trade-off, mention MVCC as the implementation mechanism.

2. **"Given this slow query, what index would you add?"**
   Strong answer: ask to see the EXPLAIN ANALYZE output first, identify whether it's a seq scan due to low selectivity or a missing composite index, design the index with correct column order (equality predicates first, then range), verify with EXPLAIN ANALYZE after.

3. **"How does consistent hashing work and why does adding a node not require full resharding?"**
   Strong answer: hash ring, each node owns a range, adding a node only moves keys from its clockwise neighbor, virtual nodes smooth load distribution — contrast with modulo hashing where adding one node remaps ~all keys.

4. **"Your DynamoDB table has a hot partition. How do you fix it?"**
   Strong answer: identify the cause (celebrity item, monotonic sort key, low-cardinality partition key), solutions: add random suffix (write sharding) + scatter-gather reads, or use a composite partition key, or restructure access pattern.

5. **"What is the N+1 problem and how do you detect it in production?"**
   Strong answer: ORM loads a list then issues one query per item for a related entity, show the SQL evidence (100 identical SELECTs in query logs), fix with JOIN FETCH or DataLoader pattern, detect with slow query log threshold + query count monitoring per request.
