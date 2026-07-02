# Volume 6: Interview Revision Pack
# Chapter 25: Backend Systems — Quick Revision

> Last-day review. Dense bullets. Scan, don't read.

---

## Section 1: REST APIs — Top 15 Questions

### Q1. What are the 6 REST constraints?
1. **Client-Server** — separation of concerns; UI decoupled from data storage
2. **Stateless** — each request contains all info; no session on server
3. **Cacheable** — responses must declare cacheability
4. **Uniform Interface** — resource identification, manipulation via representations, self-descriptive messages, HATEOAS
5. **Layered System** — client cannot tell if connected to end server or intermediary
6. **Code on Demand** (optional) — server can send executable code (JS)

### Q2. HTTP Method Safety + Idempotency

| Method  | Safe | Idempotent | Use Case                        |
|---------|------|------------|---------------------------------|
| GET     | Yes  | Yes        | Retrieve resource               |
| HEAD    | Yes  | Yes        | Retrieve headers only           |
| OPTIONS | Yes  | Yes        | CORS preflight, discover methods|
| PUT     | No   | Yes        | Full replace of resource        |
| DELETE  | No   | Yes        | Remove resource                 |
| POST    | No   | No         | Create resource, trigger action |
| PATCH   | No   | No*        | Partial update                  |

> *PATCH CAN be idempotent if implemented correctly (e.g., `SET field=X`), but is NOT guaranteed by spec.

### Q3. HTTP Status Codes Cheat Sheet

| Code | Meaning            | Key Detail                                              |
|------|--------------------|---------------------------------------------------------|
| 200  | OK                 | GET/PUT/PATCH success with body                         |
| 201  | Created            | POST success; include `Location` header                 |
| 204  | No Content         | DELETE/PUT success; no body                             |
| 301  | Moved Permanently  | Permanent redirect; browser caches                      |
| 302  | Found              | Temporary redirect; do not cache                        |
| 400  | Bad Request        | Malformed syntax, invalid params                        |
| 401  | Unauthorized       | Missing/invalid authentication (not logged in)          |
| 403  | Forbidden          | Authenticated but not authorized (logged in, no perms) |
| 404  | Not Found          | Resource does not exist                                 |
| 409  | Conflict           | State conflict (duplicate, version mismatch)            |
| 422  | Unprocessable      | Semantically invalid (validation errors)                |
| 429  | Too Many Requests  | Rate limit exceeded; include `Retry-After`              |
| 500  | Internal Server Error | Generic server failure                              |
| 502  | Bad Gateway        | Upstream server invalid response                        |
| 503  | Service Unavailable| Server down/overloaded; include `Retry-After`           |

### Q4. API Versioning Strategies
- **URI path**: `/api/v1/users` — most common, visible, breaks REST purity
- **Query param**: `/api/users?version=1` — easy but pollutes params
- **Header**: `Accept-Version: v1` or custom `X-API-Version: 1` — clean URLs
- **Content negotiation**: `Accept: application/vnd.myapi.v1+json` — RESTful purist approach
- **Best practice**: URI versioning for public APIs; header versioning for internal

### Q5. Idempotency Key Pattern
- Client generates unique key (UUID) per request, sends as `Idempotency-Key: <uuid>` header
- Server stores key + response in cache (Redis, DB) with TTL
- Duplicate request with same key returns cached response, no re-processing
- Critical for: payments, order creation, any non-idempotent POST
- Return `200` (not `201`) on replay to signal cached response

### Q6. RFC 7807 Problem Details
```json
{
  "type": "https://example.com/probs/out-of-credit",
  "title": "You do not have enough credit.",
  "status": 403,
  "detail": "Your current balance is 30, but that costs 50.",
  "instance": "/account/12345/msgs/abc"
}
```
- Content-Type: `application/problem+json`
- `type` = URI identifying problem type (stable, dereferenceable)
- `instance` = URI identifying specific occurrence
- Extend with custom fields for domain errors

### Q7. Cursor vs Offset Pagination

| Aspect          | Offset (`?page=2&size=20`)       | Cursor (`?after=eyJpZCI6MTJ9`)          |
|-----------------|----------------------------------|-----------------------------------------|
| Performance     | Slow at deep pages (OFFSET scan) | O(1) — index seek on cursor value       |
| Consistency     | Missing/duplicate on insert      | Stable — no gaps on concurrent writes   |
| Random access   | Yes — jump to any page           | No — forward/backward only              |
| Implementation  | Simple                           | More complex (encode sort key)          |
| Use case        | Admin dashboards, small datasets | Feeds, large datasets, real-time data   |

### Q8. Rate Limiting Algorithms

**Token Bucket**
- Bucket holds N tokens; refill at rate R tokens/second
- Each request consumes 1 token; reject if empty
- Allows bursts up to bucket size
- State: `{tokens, lastRefillTime}` per client

**Sliding Window Log**
- Store timestamp of each request in sorted set
- Count requests in `[now - window, now]`
- Most accurate; high memory (stores all timestamps)

**Sliding Window Counter**
- Approximate: `prevCount * (1 - elapsed/window) + currCount`
- Low memory; slightly inaccurate at window boundary

**Fixed Window Counter**
- Simple counter reset each window; vulnerable to boundary burst (2x rate)

### Q9. ETag / If-None-Match (Conditional Requests)
- Server returns `ETag: "abc123"` (hash of resource)
- Client sends `If-None-Match: "abc123"` on next request
- Server returns `304 Not Modified` if unchanged (no body) → saves bandwidth
- For updates: `If-Match: "abc123"` — server rejects with `412 Precondition Failed` if changed (optimistic locking)

### Q10. CORS Preflight
- Browser sends `OPTIONS` request with:
  - `Origin: https://app.example.com`
  - `Access-Control-Request-Method: POST`
  - `Access-Control-Request-Headers: Content-Type, Authorization`
- Server responds with:
  - `Access-Control-Allow-Origin: https://app.example.com`
  - `Access-Control-Allow-Methods: GET, POST, PUT`
  - `Access-Control-Allow-Headers: Content-Type, Authorization`
  - `Access-Control-Max-Age: 86400` (cache preflight for 24h)
- Simple requests (GET/POST with safe headers) skip preflight

### Q11. REST vs GraphQL vs gRPC Decision

| Factor            | REST            | GraphQL                    | gRPC                        |
|-------------------|-----------------|----------------------------|-----------------------------|
| Over/under-fetch  | Common          | Solved (query shape)       | N/A (schema defined)        |
| Protocol          | HTTP/1.1        | HTTP/1.1                   | HTTP/2 (multiplexed)        |
| Type safety       | OpenAPI/manual  | Schema + SDL               | Protobuf (strong)           |
| Caching           | Native HTTP     | Complex (POST queries)     | Manual                      |
| Streaming         | SSE/WebSocket   | Subscriptions              | Native bidirectional        |
| Best for          | Public APIs     | Complex client needs, BFF  | Internal microservices      |

### Q12. API Gateway Patterns
- **Single Entry Point**: routing, SSL termination, auth, rate limiting
- **Cross-cutting concerns**: logging, metrics, distributed tracing injection
- **Request transformation**: protocol translation, header manipulation
- **Load balancing**: round-robin, weighted, least-connections
- **Examples**: AWS API Gateway, Kong, NGINX, Spring Cloud Gateway
- **Anti-pattern**: putting business logic in gateway (keep it infrastructure)

### Q13. OpenAPI Benefits
- Machine-readable contract → auto-generate client SDKs, server stubs
- `springdoc-openapi` auto-generates from Spring annotations
- Mock servers from spec (Prism, WireMock)
- Contract testing (Pact, Dredd)
- `@Operation`, `@ApiResponse`, `@Schema` annotations

### Q14. HATEOAS
- Hypermedia As The Engine Of Application State
- Responses include links to possible next actions
```json
{
  "id": 1,
  "status": "PENDING",
  "_links": {
    "self": {"href": "/orders/1"},
    "cancel": {"href": "/orders/1/cancel", "method": "DELETE"},
    "payment": {"href": "/orders/1/payment"}
  }
}
```
- Client discovers workflow from responses (not hardcoded URLs)
- Rarely implemented in practice; useful for Level 3 REST maturity

### Q15. Content Negotiation
- Client sends `Accept: application/json, application/xml;q=0.9`
- Server uses highest-priority supported format
- Server sends `Content-Type: application/json` in response
- If cannot satisfy: `406 Not Acceptable`
- Spring: `produces = "application/json"` on `@RequestMapping`

---

## Section 2: Microservices — Top 15 Questions

### Q1. Microservices vs Monolith — When NOT to Use Microservices
**Use microservices when:**
- Different components need independent scaling
- Multiple teams need autonomous deployment
- Different components need different tech stacks
- System > 10 developers, complex domain

**Do NOT use microservices when:**
- Small team (< 5 engineers) — distributed system overhead kills velocity
- Early-stage startup — premature optimization, requirements unclear
- Domain not yet understood — wrong boundaries = distributed monolith
- Low operational maturity — no container orchestration, observability
- Simple CRUD app — overhead not justified

**Distributed monolith anti-pattern**: services that must deploy together, shared DB, synchronous chain calls

### Q2. API Gateway vs BFF (Backend for Frontend)

| Aspect        | API Gateway                      | BFF                                      |
|---------------|----------------------------------|------------------------------------------|
| Purpose       | Single entry, cross-cutting      | Tailored aggregation per client type     |
| Granularity   | Generic, one for all clients     | One per client (web, mobile, TV)         |
| Logic         | Infrastructure only              | Client-specific aggregation, transformation |
| Ownership     | Platform/infra team              | Frontend team                            |
| Example       | AWS API GW, Kong                 | Node.js BFF for React app                |

### Q3. Service Discovery

**Client-Side Discovery** (e.g., Netflix Eureka + Ribbon):
- Client queries service registry → gets instance list → client load balances
- Pro: client control over LB algorithm
- Con: client complexity, each language needs registry client

**Server-Side Discovery** (e.g., AWS ALB, Kubernetes):
- Client → Load Balancer → queries registry → routes to instance
- Pro: client simplicity, language agnostic
- Con: extra network hop, LB is potential bottleneck

**DNS-based**: Kubernetes Services — stable DNS name, kube-proxy handles routing

### Q4. Circuit Breaker States

```
CLOSED → (failure threshold exceeded) → OPEN → (wait timeout) → HALF-OPEN
  ↑                                                                    |
  └──────────────── (probe success) ─────────────────────────────────┘
                    (probe failure) → OPEN
```

- **CLOSED**: requests pass through; failure count tracked
- **OPEN**: all requests fail fast (no call to downstream); wait `waitDurationInOpenState`
- **HALF-OPEN**: limited probe requests; if succeed → CLOSED; if fail → OPEN

### Q5. Resilience4j Annotations
```java
@CircuitBreaker(name = "paymentService", fallbackMethod = "paymentFallback")
@RateLimiter(name = "paymentService")
@Retry(name = "paymentService", fallbackMethod = "paymentFallback")
@Bulkhead(name = "paymentService", type = Bulkhead.Type.SEMAPHORE)
@TimeLimiter(name = "paymentService")
```
- Configure in `application.yml` under `resilience4j.circuitbreaker.instances.paymentService`
- `fallbackMethod` must have same signature + exception parameter
- Combine: `@CircuitBreaker` wraps `@Retry` wraps `@TimeLimiter` (outer to inner)

### Q6. Saga: Choreography vs Orchestration

**Choreography** (event-driven):
- Each service publishes event → next service listens and reacts
- No central coordinator
- Pro: loose coupling, no SPOF
- Con: hard to track flow, compensating transactions scattered, debugging nightmare

**Orchestration** (command-driven):
- Central saga orchestrator sends commands, receives replies
- Pro: clear flow, easier monitoring, centralized failure handling
- Con: orchestrator becomes god object, coupling to orchestrator
- Tools: Axon Framework, Temporal, AWS Step Functions

**Compensating transactions**: `BookFlight` → `ReserveHotel` → `ChargeCreditCard`; on failure: `RefundCreditCard` → `CancelHotel` → `CancelFlight`

### Q7. Distributed Tracing
- **Correlation ID**: UUID injected at API Gateway, propagated via HTTP header (`X-Correlation-Id`) and Kafka headers
- **Trace**: single request journey across services
- **Span**: single unit of work within a trace (has start/end time, parent span ID)
- **OpenTelemetry**: vendor-neutral SDK; exports to Jaeger, Zipkin, Tempo
- **W3C Trace Context**: `traceparent: 00-{traceId}-{spanId}-{flags}` header standard
- Spring Boot: add `spring-boot-starter-actuator` + Micrometer Tracing + OTel bridge

### Q8. Bulkhead Pattern
- Isolate resource pools to prevent cascade failures
- **Thread pool bulkhead**: separate thread pools per downstream (Hystrix-style)
- **Semaphore bulkhead**: limit concurrent calls (Resilience4j default)
```java
@Bulkhead(name = "inventoryService", type = Type.THREADPOOL)
public CompletableFuture<Inventory> getInventory(String id) { ... }
```
- Prevents one slow service from exhausting shared thread pool

### Q9. Service Mesh (Istio Sidecar)
- **Sidecar proxy** (Envoy) injected alongside each pod; intercepts all traffic
- **Control plane** (Istiod): pushes config to sidecars
- **Capabilities**: mTLS (zero-trust), circuit breaking, retries, observability, traffic splitting
- **Pros**: offloads cross-cutting concerns from app code; language-agnostic
- **Cons**: complexity, latency overhead (~1ms), resource usage (CPU/memory per sidecar)

### Q10. Strangler Fig Migration Pattern
- New functionality in new microservice; old monolith handles existing
- Gradually route traffic: proxy/facade in front routes by feature/path
- Strangle the monolith incrementally (piece by piece)
- Never do big-bang rewrite; too risky
- Key: keep monolith and microservice in sync during transition (dual-write or CDC)

### Q11. Database per Service
- **Rule**: each microservice owns its data; no shared database
- Enables independent schema evolution, independent scaling, polyglot persistence
- **Challenges**: no cross-service joins (use API composition or CQRS), distributed transactions (use Saga)
- **Pattern**: each service has its own schema even if same DB server (good for dev) — logical isolation
- Production: separate DB instances for true isolation

### Q12. JWT Propagation in Microservices
- API Gateway validates JWT signature, extracts claims
- Downstream services receive JWT in `Authorization: Bearer <token>` header
- Services can trust claims without hitting auth server (stateless validation)
- Use shared public key (RS256) for downstream validation
- Or: Gateway exchanges JWT for internal opaque token with user context headers

### Q13. Health Check Types
- **Liveness**: "Is the process alive?" — restart if failing (stuck deadlock, OOM)
  - `/actuator/health/liveness` — Spring Boot
- **Readiness**: "Is the service ready for traffic?" — remove from load balancer if failing
  - `/actuator/health/readiness` — checks DB connection, dependencies
- **Startup probe**: grace period for slow-starting apps (prevents premature liveness kill)
- In Kubernetes: configure all three with appropriate `initialDelaySeconds`, `periodSeconds`

### Q14. Config Externalization (12-Factor App — Factor III)
- Never hardcode config; inject via environment variables or config server
- **Spring Cloud Config Server**: Git-backed, centralized config
- **Kubernetes ConfigMaps/Secrets**: mounted as env vars or volumes
- **AWS Parameter Store / Secrets Manager**: for sensitive config
- `@Value("${app.property}")` + `@ConfigurationProperties` + `@RefreshScope` (dynamic reload)

### Q15. 12-Factor App (Key Factors)
1. **Codebase** — one repo per app, multiple deploys
2. **Dependencies** — explicitly declare (Maven/Gradle), never rely on system packages
3. **Config** — in environment, not code
4. **Backing services** — treat as attached resources (DB, cache, queue)
5. **Build/Release/Run** — strict separation of stages
6. **Processes** — stateless, share-nothing; state in backing service
7. **Port binding** — export service via port (embedded server)
8. **Concurrency** — scale out via process model
9. **Disposability** — fast startup, graceful shutdown (handle SIGTERM)
10. **Dev/prod parity** — keep environments similar
11. **Logs** — treat as event streams to stdout
12. **Admin processes** — run as one-off processes (migrations, scripts)

---

## Section 3: Kafka — Top 15 Questions

### Q1. Core Concepts
- **Topic**: logical channel; split into partitions for parallelism
- **Partition**: ordered, immutable log; messages appended; each has sequential offset
- **Offset**: position of message within partition; monotonically increasing
- **Consumer Group**: set of consumers sharing topic consumption; each partition assigned to exactly one consumer in group
- **Broker**: Kafka server; cluster = multiple brokers
- **Leader**: partition's primary broker; handles all reads/writes
- **Follower**: replica of partition; takes over if leader fails

### Q2. `acks` Tradeoffs

| acks | Behavior                                     | Durability | Throughput |
|------|----------------------------------------------|------------|------------|
| 0    | No ack; fire and forget                       | Lowest     | Highest    |
| 1    | Leader ack only; follower may not have it     | Medium     | Medium     |
| all (-1) | All ISR replicas ack (+ `min.insync.replicas`) | Highest | Lowest |

- Use `acks=all` + `min.insync.replicas=2` for production

### Q3. Idempotent Producer
```properties
enable.idempotence=true
# Automatically sets: acks=all, retries=MAX, max.in.flight.requests.per.connection=5
```
- Producer gets unique PID (Producer ID) from broker
- Each message has sequence number; broker deduplicates within session
- Prevents duplicate messages on retry after network failure
- Does NOT survive producer restarts (new PID)

### Q4. Exactly-Once Semantics
```properties
transactional.id=my-app-producer-1  # unique per producer instance
```
```java
producer.initTransactions();
producer.beginTransaction();
producer.send(record);
producer.sendOffsetsToTransaction(offsets, consumerGroupId);
producer.commitTransaction(); // or abortTransaction()
```
- Consumer must set `isolation.level=read_committed`
- Use `transactional.id` = stable identifier (hostname + partition for Kafka Streams)
- Performance cost: ~20% throughput reduction

### Q5. Delivery Semantics

| Semantic       | Producer                    | Consumer                        |
|----------------|-----------------------------|---------------------------------|
| At-most-once   | `acks=0`                    | Auto-commit before processing   |
| At-least-once  | `acks=all` + retry          | Manual commit after processing  |
| Exactly-once   | Idempotent + transactional  | `read_committed` + transactional|

### Q6. Consumer Rebalancing

**Eager Rebalancing** (old default):
- All consumers stop, drop all partitions → reassign
- Stop-the-world; causes lag spike

**Cooperative/Incremental Rebalancing** (Kafka 2.4+):
- Only affected partitions are revoked and reassigned
- Other consumers keep processing
- `partition.assignment.strategy=CooperativeStickyAssignor`
- Add to Spring: `spring.kafka.consumer.properties.partition.assignment.strategy=org.apache.kafka.clients.consumer.CooperativeStickyAssignor`

### Q7. Offset Commit: Auto vs Manual
**Auto-commit** (`enable.auto.commit=true`, default):
- Commits every `auto.commit.interval.ms` (5s)
- Risk: message consumed, crash before processing → at-most-once; or committed before processing → lost message
- **Avoid for production processing**

**Manual commit**:
```java
@KafkaListener(topics = "orders")
public void listen(ConsumerRecord<String, String> record, Acknowledgment ack) {
    processRecord(record); // process first
    ack.acknowledge();     // then commit
}
// spring.kafka.listener.ack-mode=manual_immediate
```

### Q8. Throughput Tuning
- **`linger.ms`**: wait up to N ms before sending batch (default 0 = send immediately)
  - Higher value → larger batches → better throughput, higher latency
- **`batch.size`**: max bytes per batch per partition (default 16KB)
  - Increase to 32KB-64KB for high-throughput
- **`compression.type`**: `snappy` or `lz4` for throughput; `gzip` for compression ratio
- **`buffer.memory`**: total producer buffer (default 32MB)
- Consumer: increase `fetch.min.bytes`, `fetch.max.wait.ms` for batched reads

### Q9. KStream vs KTable

| Aspect     | KStream                          | KTable                               |
|------------|----------------------------------|--------------------------------------|
| Represents | Infinite event stream            | Changelog (latest value per key)     |
| Analogy    | Append-only table / event log    | Materialized view / current state    |
| Null value | Regular message                  | Tombstone = delete key               |
| Use case   | Event processing, transformation | Aggregations, joins with state       |

- `KStream.toTable()` converts stream to table (aggregate by key)
- GlobalKTable: replicated to all instances (for enrichment joins)

### Q10. Schema Registry + Avro Evolution
- Schema Registry stores Avro/JSON/Protobuf schemas; returns schema ID
- Producer serializes: `[magic byte][4-byte schema ID][avro bytes]`
- Consumer fetches schema by ID, deserializes

**Backward Compatibility** (default, recommended):
- New schema can read data written with old schema
- Allowed: add optional fields (with default), remove optional fields
- Forbidden: add required fields, change field types

**Forward Compatibility**: old schema reads new data
**Full Compatibility**: both backward + forward

### Q11. Kafka vs RabbitMQ vs SQS

| Factor         | Kafka                        | RabbitMQ                    | AWS SQS                     |
|----------------|------------------------------|-----------------------------|-----------------------------|
| Model          | Pull (log-based)             | Push (broker-driven)        | Pull                        |
| Retention      | Configurable (days/TB)       | Until consumed              | Until consumed (14 day max) |
| Replay         | Yes — rewind offset          | No                          | No                          |
| Ordering       | Per partition                | Per queue                   | FIFO queue only             |
| Throughput     | Millions/sec                 | Thousands/sec               | Managed, high               |
| Use case       | Event streaming, audit log   | Task queues, routing        | Managed, AWS native         |

### Q12. ISR + min.insync.replicas
- **ISR (In-Sync Replicas)**: set of replicas caught up with leader
- Replica falls out of ISR if behind by `replica.lag.time.max.ms` (10s default)
- `min.insync.replicas=2`: at least 2 replicas (including leader) must ack before commit
- With `replication.factor=3`, `min.insync.replicas=2`: tolerate 1 broker failure
- If ISR shrinks below `min.insync.replicas`: producer gets `NotEnoughReplicasException`

### Q13. Log Compaction vs Retention
**Retention** (default): delete old segments after `retention.ms` (7 days) or `retention.bytes`
- Good for: time-windowed events, metrics

**Log Compaction** (`cleanup.policy=compact`): keep only latest message per key
- Delete records with null value (tombstones)
- Good for: change data capture, materialized views, KTable source topics
- Compaction runs in background; `min.cleanable.dirty.ratio=0.5`

### Q14. Consumer Lag Monitoring
- **Consumer Lag** = (latest offset) - (consumer committed offset) per partition
- High lag = consumer falling behind; indicates processing bottleneck
- Monitor with: Kafka built-in `kafka-consumer-groups.sh --describe`, Prometheus + Kafka Exporter, Confluent Control Center
- Alert on lag > threshold (e.g., > 10,000 messages)
- Fix: add partitions + consumers, optimize processing, tune `max.poll.records`

### Q15. @KafkaListener with Manual Commit
```java
@KafkaListener(
    topics = "${kafka.topic.orders}",
    groupId = "order-processor",
    concurrency = "3",
    containerFactory = "kafkaListenerContainerFactory"
)
public void processOrder(
    ConsumerRecord<String, OrderEvent> record,
    Acknowledgment acknowledgment
) {
    try {
        orderService.process(record.value());
        acknowledgment.acknowledge(); // commit offset
    } catch (RetryableException e) {
        // don't ack → will be redelivered (if auto-commit disabled)
        throw e;
    } catch (NonRetryableException e) {
        // send to DLQ, then ack
        deadLetterProducer.send(record);
        acknowledgment.acknowledge();
    }
}
```

---

## Section 4: Redis & Caching — Top 15 Questions

### Q1. Cache Patterns

**Cache-Aside (Lazy Loading)**:
1. Read: check cache → miss → read DB → populate cache → return
2. Write: write DB → invalidate/update cache (or let TTL expire)
- Pro: only load what's needed; cache failure graceful (fallback to DB)
- Con: cache miss penalty; potential inconsistency window

**Write-Through**:
1. Write: write cache + write DB synchronously
- Pro: cache always fresh; no miss on read
- Con: write latency; cache pollution (wrote things never read)

**Write-Behind (Write-Back)**:
1. Write: write cache; async flush to DB later
- Pro: low write latency; batch DB writes
- Con: data loss if cache fails before flush; complex

### Q2. Cache Stampede (Thundering Herd)
**Problem**: popular key expires → thousands of requests miss → all hit DB simultaneously

**Solutions**:
- **Mutex lock**: first miss acquires lock, fetches from DB, populates cache; others wait or return stale
- **Probabilistic early expiration**: randomly refresh before expiry (`current_time - (expiry_time - now) * log(random) * beta > expiry_time`)
- **Background refresh**: async job refreshes before TTL; serve stale while refreshing
- **Never expire + event-driven invalidation**: use event (CDC) to invalidate

### Q3. Cache Penetration
**Problem**: requests for keys that never exist → all miss cache → all hit DB

**Solutions**:
- **Bloom filter**: probabilistic set; false positives OK, no false negatives; reject requests for non-existent keys
- **Cache null values**: store `null` or empty sentinel with short TTL
- Combined: bloom filter as first gate, null caching as second

### Q4. Cache Avalanche
**Problem**: many keys expire simultaneously → mass DB load spike

**Solutions**:
- **Random TTL jitter**: `TTL = baseTTL + random(0, jitterRange)` — spreads expiry
- **Staggered cache warming**: pre-load cache in waves
- **Circuit breaker**: protect DB from overload
- **L2 cache**: Redis backed by local in-process cache (Caffeine)

### Q5. Cache Breakdown
**Problem**: single hot key expires → many concurrent requests for that key → DB stampede

**Solutions**:
- **Mutex**: only one request fetches from DB; others wait or return stale data
- **Logical expiration**: store expiry in value, not as Redis TTL; serve stale, refresh async
```java
String value = redis.get(key);
if (value == null || isExpired(value)) {
    if (redis.setnx(lockKey, "1", 10s)) { // try to acquire lock
        value = db.fetch(key);
        redis.set(key, value, ttl);
        redis.del(lockKey);
    } else {
        return staleValue; // serve old value while refreshing
    }
}
```

### Q6. Eviction Policies

| Policy      | Evicts                                          | Use Case                         |
|-------------|-------------------------------------------------|----------------------------------|
| noeviction  | Error on write when full                        | Cache must not lose data         |
| allkeys-lru | Least recently used from all keys               | General purpose cache            |
| volatile-lru| LRU from keys with TTL only                     | Mix of persistent + cache keys   |
| allkeys-lfu | Least frequently used from all keys             | Hot/cold access patterns         |
| volatile-lfu| LFU from keys with TTL only                     | Similar to volatile-lru          |
| allkeys-random | Random from all keys                         | Uniform access distribution      |
| volatile-ttl| Key with shortest remaining TTL                 | Expire soonest first             |

### Q7. Redis Data Structures Use Cases

| Structure    | Commands                   | Use Case                              |
|--------------|----------------------------|---------------------------------------|
| String       | GET/SET/INCR/SETNX         | Counters, cache, distributed lock     |
| Hash         | HGET/HSET/HMGET            | User profile, object with fields      |
| List         | LPUSH/RPOP/LRANGE          | Message queue, recent items           |
| Set          | SADD/SMEMBERS/SINTER       | Tags, unique visitors, social graphs  |
| Sorted Set   | ZADD/ZRANGE/ZRANK          | Leaderboards, rate limiting, delayed queues |
| HyperLogLog  | PFADD/PFCOUNT              | Unique count approximation (0.81% error) |
| Stream       | XADD/XREAD/XGROUP          | Event log, Kafka-like per Redis       |
| Bitmap       | SETBIT/BITCOUNT            | Feature flags, daily active users     |

### Q8. Distributed Lock (Redisson RLock)
```java
RLock lock = redissonClient.getLock("payment:lock:" + orderId);
try {
    boolean acquired = lock.tryLock(5, 30, TimeUnit.SECONDS); // wait 5s, expire 30s
    if (acquired) {
        processPayment(orderId);
    }
} finally {
    if (lock.isHeldByCurrentThread()) {
        lock.unlock();
    }
}
```
- Lua script for atomic lock/unlock (SET NX PX)
- Watchdog: Redisson auto-extends TTL if still processing (every 10s by default)
- `leaseTime=-1`: watchdog enabled; explicit leaseTime: watchdog disabled

### Q9. Redlock Algorithm (and Critics)
- Acquire lock on N/2+1 of N Redis instances (majority); use elapsed time to validate TTL
- Martin Kleppmann critique: not safe with clock drift, process pauses (GC), network delays
  - Clock jumps can cause lock to expire while held
  - GC pause: think you hold lock, but it expired
- Redis author (antirez) disagrees; debate ongoing
- **Practical advice**: use Redisson's RLock for single Redis; use ZooKeeper/etcd for strong consensus if critical (e.g., financial)

### Q10. Redis Cluster
- 16384 hash slots distributed across master nodes
- Key → CRC16(key) mod 16384 → slot → node
- `{tag}` in key forces same slot: `{user:123}:profile` and `{user:123}:settings` → same slot
- **MOVED**: permanent redirect (slot permanently on different node)
- **ASK**: temporary redirect (slot being migrated)
- Minimum: 3 masters + 3 replicas for HA
- Smart clients (Jedis cluster, Lettuce) cache slot-to-node map

### Q11. RDB vs AOF Persistence

| Aspect       | RDB (Snapshot)                      | AOF (Append-Only File)              |
|--------------|-------------------------------------|--------------------------------------|
| How          | Periodic snapshot (BGSAVE)          | Log every write command              |
| Recovery     | Fast (binary snapshot)              | Slower (replay commands)             |
| Data loss    | Up to last snapshot (minutes)       | `appendfsync=always`: zero loss      |
| File size    | Compact binary                      | Larger; auto-rewrite compacts         |
| Config       | `save 900 1` (after 900s if 1 change)| `appendfsync=everysec` (1s window)  |
| Best for     | Backups, fast restarts              | Durability                           |

- Production recommendation: enable both RDB + AOF (`appendfsync=everysec`)

### Q12. Redis Pub/Sub vs Streams

| Feature       | Pub/Sub                    | Streams                              |
|---------------|----------------------------|--------------------------------------|
| Persistence   | No — fire and forget       | Yes — stored in log                  |
| Consumer groups | No                       | Yes — like Kafka consumer groups     |
| Replay        | No                         | Yes — read from ID                   |
| At-least-once | No                         | Yes (ACK mechanism)                  |
| Use case      | Real-time notifications    | Event sourcing, reliable messaging   |

### Q13. Spring Cache Annotations
```java
@Cacheable(value = "users", key = "#id", unless = "#result == null")
public User getUser(Long id) { ... }

@CacheEvict(value = "users", key = "#user.id")
public void updateUser(User user) { ... }

@CachePut(value = "users", key = "#user.id")
public User saveUser(User user) { ... } // always executes, updates cache

@Caching(evict = {
    @CacheEvict("users"),
    @CacheEvict(value = "usersByEmail", key = "#user.email")
})
public void deleteUser(User user) { ... }
```
- Configure: `@EnableCaching` + `RedisCacheManager` bean
- Serialization: use `GenericJackson2JsonRedisSerializer` (not Java default)

### Q14. Session Management with Redis
- **Server-side sessions**: session data in Redis; session ID in cookie
- Spring Session: `@EnableRedisHttpSession` + `spring-session-data-redis`
- Session replication: all app nodes share Redis → sticky sessions not needed
- Session attributes stored as Redis hash: `spring:session:sessions:{sessionId}`
- TTL = `server.servlet.session.timeout`

### Q15. Redis as Rate Limiter
```lua
-- Sliding window counter in Lua (atomic)
local key = KEYS[1]
local window = tonumber(ARGV[1])
local limit = tonumber(ARGV[2])
local now = tonumber(ARGV[3])

redis.call('ZREMRANGEBYSCORE', key, 0, now - window)
local count = redis.call('ZCARD', key)
if count < limit then
    redis.call('ZADD', key, now, now)
    redis.call('EXPIRE', key, window)
    return 1 -- allowed
end
return 0 -- rate limited
```

---

## Section 5: Security — Top 15 Questions

### Q1. JWT Structure
```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.  ← Header (Base64url)
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6Ikpva  ← Payload (Base64url)
hn Doe","iat":1516239022}.
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQ  ← Signature
```
- **Header**: `{"alg": "RS256", "typ": "JWT"}`
- **Payload**: claims — `sub`, `iss`, `aud`, `exp`, `iat`, `jti`, + custom
- **Signature**: `RSASHA256(base64url(header) + "." + base64url(payload), privateKey)`
- NOT encrypted by default (use JWE for encryption); just signed

### Q2. HS256 vs RS256

| Aspect       | HS256 (HMAC-SHA256)              | RS256 (RSA-SHA256)                    |
|--------------|----------------------------------|---------------------------------------|
| Key type     | Shared secret (symmetric)        | Private/public key pair (asymmetric)  |
| Signing      | Same key signs + verifies        | Private key signs, public key verifies|
| Use case     | Single service (same key owner)  | Distributed (share public key only)   |
| Key exposure | Secret must stay secret on all   | Public key can be shared openly       |
| Microservices| Problematic (all services need secret) | Ideal (services verify with public key) |

### Q3. alg:none Attack
- Attacker changes header to `{"alg": "none"}` and removes signature
- Naive libraries accept if they don't validate algorithm
- **Defense**: always explicitly specify allowed algorithms; never accept `alg:none`
```java
JWTVerifier verifier = JWT.require(Algorithm.RSA256(publicKey, null)).build();
// Never: Algorithm.none()
```

### Q4. JWT Validation Checklist (9 Steps)
1. Token format: 3 parts separated by `.`
2. Algorithm: matches expected (RS256/HS256); reject `none`
3. Signature: cryptographically valid
4. `exp` (expiry): not expired (`now < exp`)
5. `nbf` (not before): if present, `now >= nbf`
6. `iss` (issuer): matches expected issuer
7. `aud` (audience): contains expected audience (your service)
8. `jti` (JWT ID): not in revocation list (if stateful revocation implemented)
9. Claims: required custom claims present and valid

### Q5. OAuth2 Roles
- **Resource Owner**: user who owns the data
- **Client**: application requesting access
- **Authorization Server**: issues tokens (Keycloak, Auth0, Okta)
- **Resource Server**: API protecting resources, validates access tokens

### Q6. Authorization Code + PKCE Flow
```
1. Client generates code_verifier (random) + code_challenge = SHA256(code_verifier)
2. Redirect user to: /authorize?response_type=code&code_challenge=<hash>&code_challenge_method=S256
3. User authenticates → Authorization Server → redirect to callback with ?code=<auth_code>
4. Client POST /token: { code, code_verifier, client_id, redirect_uri }
5. Auth Server verifies SHA256(code_verifier) == code_challenge → issues access_token + refresh_token
```
- PKCE prevents authorization code interception attacks (mobile/SPA)
- `code_verifier` proves same party that initiated flow is exchanging code

### Q7. Client Credentials Flow (Service-to-Service)
```
POST /token
{ grant_type: client_credentials, client_id, client_secret, scope }
→ access_token (no refresh token)
```
- No user involved; service authenticates as itself
- Use for: batch jobs, background workers, internal microservice calls
- Store `client_secret` in Vault/Secrets Manager, not code

### Q8. OIDC ID Token vs Access Token
- **ID Token**: JWT; for the CLIENT; contains user identity claims (`sub`, `email`, `name`)
  - Never send to Resource Server; meant for client to know who logged in
- **Access Token**: for the RESOURCE SERVER; contains scopes/permissions
  - Can be opaque or JWT; Resource Server validates it
- **Refresh Token**: long-lived; exchange for new access token; stored securely (httpOnly cookie)

### Q9. Spring Security FilterChain Order
Key filters (in order):
1. `SecurityContextPersistenceFilter` — restore SecurityContext
2. `UsernamePasswordAuthenticationFilter` — form login
3. `BasicAuthenticationFilter` — HTTP Basic
4. `BearerTokenAuthenticationFilter` — JWT/OAuth2
5. `ExceptionTranslationFilter` — convert exceptions to HTTP responses
6. `FilterSecurityInterceptor` / `AuthorizationFilter` — access control

```java
@Bean
SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    return http
        .csrf(csrf -> csrf.disable()) // for REST APIs
        .sessionManagement(s -> s.sessionCreationPolicy(STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/public/**").permitAll()
            .anyRequest().authenticated()
        )
        .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
        .build();
}
```

### Q10. @PreAuthorize SpEL
```java
@PreAuthorize("hasRole('ADMIN')")
@PreAuthorize("hasAuthority('SCOPE_read:users')")
@PreAuthorize("hasRole('USER') and #userId == authentication.principal.id")
@PreAuthorize("@securityService.canAccess(#resourceId, authentication)")
@PostAuthorize("returnObject.owner == authentication.name")
```
- Enable: `@EnableMethodSecurity` (Spring Security 6+)
- Old: `@EnableGlobalMethodSecurity(prePostEnabled = true)` (deprecated)

### Q11. bcrypt vs Argon2
- **bcrypt**: adaptive work factor (`$2a$12$...`); 12 rounds = ~300ms; 72-char limit
- **Argon2id**: winner of Password Hashing Competition; tunable memory + parallelism + iterations
  - Memory-hard: resists GPU attacks
  - Parameters: `memory=65536`, `iterations=3`, `parallelism=4`
- Spring: `new BCryptPasswordEncoder(12)` or `Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8()`
- **Never use**: MD5, SHA-1, SHA-256 (too fast for passwords); always use slow adaptive hash

### Q12. HTTPS/TLS Handshake (TLS 1.3 simplified)
1. Client Hello: TLS version, cipher suites, random, supported groups
2. Server Hello: chosen cipher, server certificate (contains public key), server random
3. Client verifies certificate (CA chain, expiry, hostname)
4. Key exchange: ECDHE — both generate session key from ephemeral keys
5. Client Finished (encrypted with session key)
6. Server Finished
7. Encrypted application data
- **Perfect Forward Secrecy (PFS)**: ephemeral keys (ECDHE) ensure past sessions safe even if private key compromised

### Q13. CORS vs CSRF
- **CORS**: browser security mechanism preventing cross-origin requests
  - Server opts-in via `Access-Control-Allow-Origin` headers
  - Protects: API from unauthorized cross-origin browser requests
- **CSRF**: attacker's site tricks logged-in user's browser to make request to your API
  - Defense: CSRF token (synchronized token pattern), `SameSite=Strict/Lax` cookie
  - For REST APIs with stateless JWT (no cookies): **CSRF not applicable** → disable in Spring Security

### Q14. SameSite Cookie
- `SameSite=Strict`: cookie only sent in same-site requests (breaks cross-site navigation)
- `SameSite=Lax` (default modern browsers): sent on same-site + top-level cross-site navigations (GET)
- `SameSite=None`: sent cross-site; **requires `Secure` attribute** (HTTPS only)
- Prevents CSRF by default in modern browsers
- Auth cookies: `HttpOnly=true` (no JS access), `Secure=true` (HTTPS), `SameSite=Lax`

### Q15. OWASP API Top 10 Key Issues

| Rank | Issue                              | Example / Fix                                      |
|------|------------------------------------|----------------------------------------------------|
| 1    | BOLA (Broken Object Level Auth)    | `/api/orders/{id}` — check `order.userId == currentUser.id` |
| 2    | Broken Authentication              | Weak JWT validation, exposed secrets               |
| 3    | Broken Object Property Level Auth  | Mass assignment: `user.setRole(dto.getRole())`; use DTOs |
| 4    | Unrestricted Resource Consumption  | No rate limiting, no pagination limits             |
| 5    | BFLA (Broken Function Level Auth)  | User calling admin endpoints; check roles          |
| 6    | Unrestricted Access to Business Flows | No bot detection; scraping, account takeover  |
| 7    | SSRF                               | User-supplied URL fetched server-side; validate/allowlist |
| 8    | Security Misconfiguration          | Debug endpoints exposed, default creds, verbose errors |
| 9    | Improper Inventory Management      | Old API versions still active (`/api/v1/` unpatched)|
| 10   | Unsafe Consumption of APIs         | Trust 3rd party APIs without validation            |

---

## Section 6: Quick Reference Tables

### Table 1: HTTP Methods — Safe + Idempotent + Use Case

| Method  | Safe | Idempotent | Body (req) | Body (resp) | Primary Use Case         |
|---------|------|------------|------------|-------------|--------------------------|
| GET     | Yes  | Yes        | No         | Yes         | Retrieve resource        |
| POST    | No   | No         | Yes        | Yes         | Create resource, actions |
| PUT     | No   | Yes        | Yes        | Optional    | Full replace             |
| PATCH   | No   | No*        | Yes        | Optional    | Partial update           |
| DELETE  | No   | Yes        | No         | Optional    | Delete resource          |
| HEAD    | Yes  | Yes        | No         | No          | Check existence/headers  |
| OPTIONS | Yes  | Yes        | No         | Yes         | CORS preflight, discovery|

### Table 2: OAuth2 Grant Types Comparison

| Grant Type           | Use Case                        | User Involved | Refresh Token |
|----------------------|---------------------------------|---------------|---------------|
| Authorization Code + PKCE | Web/SPA/Mobile (user login) | Yes       | Yes           |
| Client Credentials   | Service-to-service (M2M)        | No            | No            |
| Device Code          | Smart TVs, CLI tools            | Yes (other device) | Yes      |
| Implicit             | **Deprecated** (use Auth Code+PKCE) | Yes      | No            |
| Resource Owner Password | **Legacy only** (avoid)      | Yes (directly)| Yes           |

### Table 3: Kafka Delivery Semantics

| Producer `acks` | Consumer Commit   | Delivery Semantic | Notes                          |
|-----------------|-------------------|-------------------|--------------------------------|
| 0               | Before processing | At-most-once      | Data loss possible             |
| 1               | After processing  | At-least-once     | Duplicate on retry possible    |
| all             | After processing  | At-least-once     | No data loss; may duplicate    |
| all + idempotent| After processing  | At-least-once     | No producer duplicates         |
| transactional   | Transactional     | Exactly-once      | read_committed + transactions  |

### Table 4: Redis Eviction Policies

| Policy           | Eviction Target                  | When to Use                    |
|------------------|----------------------------------|--------------------------------|
| noeviction       | None (error on write)            | When data must not be lost     |
| allkeys-lru      | LRU across all keys              | General cache                  |
| volatile-lru     | LRU among TTL keys               | Mixed persistent + cache       |
| allkeys-lfu      | LFU across all keys              | Skewed access patterns         |
| volatile-lfu     | LFU among TTL keys               | Mixed with hot/cold data       |
| volatile-ttl     | Shortest TTL first               | Expire-soonest semantics       |
| allkeys-random   | Random all keys                  | Uniform access                 |
| volatile-random  | Random TTL keys                  | Random among expiring          |

### Table 5: Resilience4j Patterns

| Pattern        | Class/Annotation    | Key Config                              | Purpose                        |
|----------------|---------------------|-----------------------------------------|--------------------------------|
| Circuit Breaker | `@CircuitBreaker`  | `slidingWindowSize`, `failureRateThreshold`, `waitDurationInOpenState` | Stop calls to failing service |
| Retry          | `@Retry`            | `maxAttempts`, `waitDuration`, `retryExceptions` | Retry transient failures  |
| Rate Limiter   | `@RateLimiter`      | `limitForPeriod`, `limitRefreshPeriod`  | Limit outgoing call rate       |
| Bulkhead       | `@Bulkhead`         | `maxConcurrentCalls` (semaphore), `maxWaitDuration` | Isolate resource pools  |
| Time Limiter   | `@TimeLimiter`      | `timeoutDuration`                       | Timeout for async calls        |

---

## Section 7: Common Traps — 20 Items

1. **401 vs 403**: `401 Unauthorized` = not authenticated (send credentials); `403 Forbidden` = authenticated but lacks permission. Using them interchangeably is wrong.

2. **PUT vs PATCH idempotency**: PUT is always idempotent (full replace); PATCH is NOT guaranteed idempotent by spec (e.g., `increment counter` PATCH is not idempotent; `set field=value` PATCH is).

3. **Offset pagination at scale**: `OFFSET 1000000 LIMIT 20` scans and discards 1M rows in SQL. Use cursor/keyset pagination for large datasets.

4. **Kafka auto-commit = at-most-once risk**: `enable.auto.commit=true` commits offsets before processing completes on a crash. Always use manual commit for reliable processing.

5. **Consumer group rebalance storm**: adding/removing consumers too fast, or long `max.poll.interval.ms` violations, cause repeated rebalances. Use cooperative rebalancing and tune `session.timeout.ms`.

6. **Redis `KEYS *` in production**: O(N) operation blocks Redis single thread. Always use `SCAN` with cursor and COUNT for key enumeration.

7. **JWT stateless revocation problem**: JWTs can't be truly revoked before expiry (stateless). Solutions: short expiry (5-15min) + refresh tokens, or maintain a revocation list in Redis (partial statefulness).

8. **CSRF disable for REST APIs (correct)**: REST APIs using Bearer tokens (not cookies) are NOT vulnerable to CSRF. Disabling CSRF in Spring Security for REST is correct, not a security hole.

9. **OAuth2 Implicit grant deprecated**: Implicit returns tokens in URL fragment (visible in browser history/logs). Always use Authorization Code + PKCE for SPAs/mobile.

10. **JWT `aud` claim not validated**: Many implementations skip audience validation, allowing tokens issued for Service A to be accepted by Service B (confused deputy attack).

11. **N+1 in microservices**: Fetching a list of orders, then calling inventory service for each order = N+1 HTTP calls. Use batch endpoint, GraphQL DataLoader, or aggregate in BFF.

12. **Shared database anti-pattern**: Two microservices sharing a DB table = tight coupling. Schema changes require coordinated deployment; eliminates independent scaling/deployment.

13. **Circuit breaker half-open timing**: If `waitDurationInOpenState` is too short, circuit reopens before downstream recovers, causing rapid OPEN→HALF-OPEN oscillation.

14. **Redis cluster cross-slot operations**: MGET/MSET/pipeline on keys in different slots fails in cluster mode. Use hash tags `{prefix}` to force same slot, or use single-key operations.

15. **bcrypt 72-char truncation**: bcrypt silently ignores characters after position 72. Long passwords may have less entropy than expected. Pre-hash with SHA-256 or use Argon2id.

16. **Kafka exactly-once requires both sides**: Idempotent producer alone gives at-least-once from producer side. True exactly-once needs transactional producer + `read_committed` consumer.

17. **Spring @Transactional and async**: `@Transactional` method calling another `@Transactional` method in the SAME bean bypasses the proxy — inner method joins outer transaction (may cause surprises). Call via separate bean/proxy.

18. **linger.ms=0 in production Kafka**: Default 0ms linger means each record sent immediately (1 record per batch). Set `linger.ms=5-20` for batching; dramatically improves throughput.

19. **Redlock clock drift**: Redlock assumes synchronized clocks. A 10ms clock drift on a 30s lock TTL is fine; but leap seconds, NTP jumps can cause unexpected lock expiry. Use with caution for critical sections.

20. **Health endpoint exposing sensitive info**: `/actuator/health` showing DB connection strings, internal IPs, or dependency details publicly. Configure `management.endpoint.health.show-details=when_authorized` or restrict actuator port.

---

*Chapter 25 — Backend Systems Revision | Volume 6: Interview Revision Pack*
*Dense reference for SDE2 last-day review. Cover REST, Microservices, Kafka, Redis, Security.*


