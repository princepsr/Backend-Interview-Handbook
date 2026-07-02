# Appendix B: Master Reference Tables

*All critical comparison tables consolidated from across the handbook. Cross-referenced by chapter.*

---

## Java Core Tables

---

### T1: Collections Complexity & Characteristics (Ch3)

| Collection | get | add | remove | contains | Null Allowed | Thread-Safe | Ordered | Sorted |
|---|---|---|---|---|---|---|---|---|
| `ArrayList` | O(1) | O(1) amortized | O(n) | O(n) | Yes (one null) | No | Yes (insertion) | No |
| `LinkedList` | O(n) | O(1) | O(1) with iterator | O(n) | Yes | No | Yes (insertion) | No |
| `HashSet` | — | O(1) avg | O(1) avg | O(1) avg | Yes (one null) | No | No | No |
| `LinkedHashSet` | — | O(1) avg | O(1) avg | O(1) avg | Yes (one null) | No | Yes (insertion) | No |
| `TreeSet` | — | O(log n) | O(log n) | O(log n) | No | No | Yes (sorted) | Yes |
| `HashMap` | O(1) avg | O(1) avg | O(1) avg | O(1) avg | Yes (one null key, null values) | No | No | No |
| `LinkedHashMap` | O(1) avg | O(1) avg | O(1) avg | O(1) avg | Yes (one null key) | No | Yes (insertion or access) | No |
| `TreeMap` | O(log n) | O(log n) | O(log n) | O(log n) | No (key), Yes (value) | No | Yes (sorted) | Yes |
| `ConcurrentHashMap` | O(1) avg | O(1) avg | O(1) avg | O(1) avg | No nulls (key or value) | Yes | No | No |
| `PriorityQueue` | O(n) | O(log n) | O(log n) | O(n) | No | No | No (heap) | By comparator |
| `ArrayDeque` | O(1) ends | O(1) amortized | O(1) ends | O(n) | No | No | Yes (insertion) | No |

> **Notes:** avg = average case assuming good hash distribution. `ConcurrentHashMap` uses segment/bucket locking (Java 8+ uses CAS + synchronized on bucket head). `TreeSet`/`TreeMap` use Red-Black tree; O(log n) is worst case.

---

### T2: Java 8+ Feature Quick Reference (Ch4)

| Feature | Java Version | Purpose | Key Method / Syntax | Gotcha |
|---|---|---|---|---|
| **Lambdas** | Java 8 | Anonymous function expressions for functional interfaces | `(x, y) -> x + y` | Captures effectively-final variables only; no checked exceptions without wrapping |
| **Streams** | Java 8 | Declarative, lazy pipeline processing of sequences | `stream().filter().map().collect()` | Streams are single-use; `parallel()` adds overhead on small data |
| **Optional** | Java 8 | Represent possibly-absent values without null | `Optional.ofNullable(x).orElse(default)` | Never use `Optional.get()` without `isPresent()`; don't use as method parameter type |
| **CompletableFuture** | Java 8 | Async/non-blocking computation composition | `supplyAsync().thenApply().exceptionally()` | Default executor is `ForkJoinPool.commonPool()`; supply your own for I/O work |
| **Default Methods** | Java 8 | Interface methods with implementation | `default void method() {}` | Diamond-problem resolution: class method wins; else must override |
| **Method References** | Java 8 | Shorthand lambda referencing existing methods | `String::toUpperCase`, `obj::method` | Cannot reference overloaded methods without disambiguation |
| **`var`** | Java 10 | Local variable type inference | `var list = new ArrayList<String>()` | Compile-time only; no inference for fields/parameters; reduces readability if type is not obvious |
| **Records** | Java 16 | Immutable data classes with auto-generated boilerplate | `record Point(int x, int y) {}` | Implicitly final; all fields are final; can override accessors/equals but not add mutable state |
| **Sealed Classes** | Java 17 | Restricted class hierarchy — only permitted subclasses | `sealed class Shape permits Circle, Rect {}` | Subclasses must be `final`, `sealed`, or `non-sealed`; great for exhaustive pattern matching |
| **Pattern Matching `instanceof`** | Java 16 | Combines type check and cast | `if (obj instanceof String s) { s.length(); }` | Scoped to the `if` block; does not apply in `else` |
| **Switch Expressions** | Java 14 | Expression form of switch, exhaustive | `int r = switch(day) { case MON -> 1; ... }` | Must be exhaustive (cover all cases or have `default`); use `yield` for block bodies |
| **Text Blocks** | Java 15 | Multi-line string literals | `""" SELECT * FROM users """` | Opening `"""` must be followed by newline; trailing `"""` controls indentation stripping |
| **Virtual Threads** | Java 21 | Lightweight JVM-managed threads for high concurrency | `Thread.ofVirtual().start(runnable)` | Not suitable for CPU-bound tasks; avoid `ThreadLocal` with large values (memory); pinning with `synchronized` |

---

### T3: GC Algorithms Comparison (Ch5)

| GC Algorithm | Pause Type | Pause Time | Throughput | Heap Size | Java Version | Use Case | Key JVM Flags |
|---|---|---|---|---|---|---|---|
| **Serial GC** | Stop-the-world (STW) | High | Moderate | Small (< 4 GB) | Java 1+ | Single-core, embedded, small apps | `-XX:+UseSerialGC` |
| **Parallel GC** | STW (young + old) | Medium-High | High (batch) | Medium-Large | Java 5+ (default pre-9) | Batch processing, throughput-oriented | `-XX:+UseParallelGC`, `-XX:ParallelGCThreads=N` |
| **CMS (Deprecated)** | STW minor; concurrent major | Low (variable) | Medium | Medium | Java 1.4–Java 14 | Low-latency apps (superseded by G1) | `-XX:+UseConcMarkSweepGC` *(removed Java 15)* |
| **G1 GC** | STW (mostly), concurrent marking | Predictable (default 200 ms) | Good | Medium-Large (4–32 GB) | Java 7+ (default Java 9+) | General purpose, balanced latency/throughput | `-XX:+UseG1GC`, `-XX:MaxGCPauseMillis=200` |
| **ZGC** | Concurrent (STW < 1 ms) | Sub-millisecond | Good | Any (TB-scale) | Java 15+ (production) | Ultra-low latency, very large heaps | `-XX:+UseZGC`, `-XX:SoftMaxHeapSize=Xg` |
| **Shenandoah** | Concurrent evacuation (STW < 10 ms) | Very low | Slightly lower than G1 | Medium-Large | Java 12+ (OpenJDK) | Low-pause alternative to G1; Red Hat JDK | `-XX:+UseShenandoahGC` |

> **Choosing:** Small heap/batch → Parallel. General cloud service → G1. Sub-ms latency SLA → ZGC. Very large heap (> 32 GB) → ZGC or Shenandoah.

---

### T4: Concurrency Primitives Comparison (Ch6)

| Primitive | Use Case | Reentrant | Fairness Option | Try-Lock | Condition Support | Performance Note |
|---|---|---|---|---|---|---|
| `synchronized` | Simple mutual exclusion on shared state | Yes | No (JVM biased/adaptive) | No | Via `wait()`/`notify()` | Low overhead for uncontended; biased locking removed Java 21 |
| `ReentrantLock` | Explicit lock with more control than `synchronized` | Yes | Yes (`new ReentrantLock(true)`) | Yes (`tryLock()`, timeout) | Yes (`newCondition()`) | Slightly higher overhead; flexible; prefer when try-lock or multiple conditions needed |
| `ReadWriteLock` / `ReentrantReadWriteLock` | Many readers, few writers | Yes (read + write locks separate) | Yes | Yes | Yes | Read lock allows concurrency; write lock is exclusive; write starvation risk without fairness |
| `StampedLock` | Optimistic read + upgrade to write | No | No | Yes | No | Best throughput for read-heavy; complex API; not reentrant — deadlock risk if misused |
| `volatile` | Single-variable visibility guarantee | N/A | N/A | N/A | N/A | No atomicity for compound ops (e.g., `i++`); JVM memory-barrier semantics |
| `AtomicInteger` | Lock-free integer counter/CAS operations | N/A | N/A | N/A | N/A | CAS loop; good under low-medium contention |
| `LongAdder` | High-contention counter | N/A | N/A | N/A | N/A | Striped cells reduce contention; prefer over `AtomicLong` when update >> read |
| `CountDownLatch` | Wait for N events to complete (one-shot) | N/A | N/A | N/A | N/A | Cannot be reset; use for startup barriers or test synchronization |
| `CyclicBarrier` | All N threads wait at a common point, then proceed | N/A | N/A | N/A | N/A | Reusable; optional barrier action; throws `BrokenBarrierException` if interrupted |
| `Semaphore` | Limit concurrent access to a resource pool | N/A | Yes | Yes (`tryAcquire()`) | N/A | Useful for rate-limiting, connection pools |
| `Phaser` | Flexible, reusable multi-phase barrier | N/A | N/A | N/A | N/A | Replaces `CountDownLatch` + `CyclicBarrier`; dynamic party registration |

---

### T5: ThreadPoolExecutor Rejection Policies (Ch6)

| Policy | Behavior | When to Use | Side Effect |
|---|---|---|---|
| `AbortPolicy` (default) | Throws `RejectedExecutionException` | When you need explicit error handling and must know tasks were dropped | Caller receives unchecked exception; task is lost |
| `CallerRunsPolicy` | Runs the rejected task on the calling thread | When you want back-pressure and can tolerate caller blocking | Slows the producer naturally; caller thread is blocked during task execution; pool queue can drain |
| `DiscardPolicy` | Silently discards the rejected task | Non-critical tasks (e.g., metrics, logging) where loss is acceptable | Task is silently lost; no feedback to caller — dangerous if used inappropriately |
| `DiscardOldestPolicy` | Discards the oldest queued task, then retries submission | When newest tasks are more important than oldest (e.g., real-time data) | Oldest pending task is silently dropped; may starve long-queued tasks |

---

## Spring & JPA Tables

---

### T6: Spring Bean Scopes (Ch7)

| Scope | One Instance Per | Default For | Thread-Safe | Use Case |
|---|---|---|---|---|
| `singleton` | Spring IoC container (application) | All `@Component`, `@Service`, `@Repository`, `@Bean` | No (your responsibility) | Stateless services, repositories, utilities |
| `prototype` | Each `getBean()` call / each injection point | Nothing by default | Yes (each caller has own instance) | Stateful beans, user-specific objects, non-shared helpers |
| `request` | Single HTTP request | Web-aware contexts only | Yes (one per request thread) | HTTP request-scoped data, form beans |
| `session` | HTTP session | Web-aware contexts only | Partially (one per session) | User session state, shopping cart |
| `application` | `ServletContext` lifecycle | Web-aware contexts only | No (shared across all users) | Application-wide settings, counters |
| `websocket` | Single WebSocket session | WebSocket-aware contexts | Yes (one per WS connection) | WebSocket session-scoped beans |

> **Gotcha:** Injecting `prototype` into `singleton` gives the same prototype instance forever. Use `ObjectProvider<T>` or `@Lookup` for correct prototype behavior.

---

### T7: @Transactional Propagation Types (Ch7/Ch8)

| Propagation | Existing Tx Present | No Tx Present | Creates New Tx? | Use Case |
|---|---|---|---|---|
| `REQUIRED` (default) | Joins existing transaction | Creates new transaction | Only if none exists | Standard service methods; most common |
| `REQUIRES_NEW` | Suspends existing; starts new | Creates new transaction | Always | Audit logging, independent ops that must commit regardless of outer tx |
| `SUPPORTS` | Joins existing transaction | Runs without transaction | No | Read-only helpers that work with or without a tx |
| `NOT_SUPPORTED` | Suspends existing; runs non-transactionally | Runs without transaction | No | Non-transactional ops inside a tx (e.g., sending JMS message) |
| `MANDATORY` | Joins existing transaction | Throws `IllegalTransactionStateException` | No | Methods that must always be called within a tx |
| `NEVER` | Throws `IllegalTransactionStateException` | Runs without transaction | No | Methods that must never run inside a tx |
| `NESTED` | Creates savepoint within existing | Creates new transaction | Savepoint (not full new tx) | Partial rollback within a larger tx; JDBC savepoint support required |

> **Gotcha:** `@Transactional` on private methods is silently ignored. Self-invocation bypasses the proxy — use `AopContext.currentProxy()` or restructure.

---

### T8: Transaction Isolation Levels vs Anomalies (Ch8/Ch16)

| Isolation Level | Dirty Read | Non-Repeatable Read | Phantom Read | Write Skew | Lost Update | PostgreSQL Default | MySQL Default |
|---|---|---|---|---|---|---|---|
| `READ UNCOMMITTED` | Possible | Possible | Possible | Possible | Possible | Not supported (maps to RC) | Supported |
| `READ COMMITTED` | Prevented | Possible | Possible | Possible | Possible | **Yes (default)** | Supported |
| `REPEATABLE READ` | Prevented | Prevented | Possible (standard); Prevented (MVCC) | Possible | Prevented | Supported | **Yes (default)** |
| `SERIALIZABLE` | Prevented | Prevented | Prevented | Prevented | Prevented | Supported (SSI) | Supported (locking) |

> **PostgreSQL note:** REPEATABLE READ in PostgreSQL prevents phantom reads via MVCC snapshots but allows write skew. SERIALIZABLE uses Serializable Snapshot Isolation (SSI).  
> **MySQL note:** REPEATABLE READ uses gap locks to prevent phantoms in InnoDB.

---

### T9: JPA Fetch Type Defaults (Ch8)

| Association | Default Fetch | Recommended Fetch | N+1 Risk | Fix |
|---|---|---|---|---|
| `@OneToOne` | `EAGER` | `LAZY` (unless always needed) | High (EAGER loads always; LAZY can still trigger proxy init) | `JOIN FETCH` in JPQL, `@EntityGraph`, or DTO projection |
| `@ManyToOne` | `EAGER` | `LAZY` | High (each row triggers a parent load) | `JOIN FETCH` or DTO projection |
| `@OneToMany` | `LAZY` | `LAZY` (keep as-is) | High (accessing collection triggers query per owner) | `JOIN FETCH`, `@EntityGraph`, or batch fetch (`@BatchSize`) |
| `@ManyToMany` | `LAZY` | `LAZY` | High | `JOIN FETCH` (caution: Cartesian product); prefer DTO projection or separate queries |

> **General rule:** Set all associations to `LAZY` and use explicit fetching strategies per query. Never blindly use `EAGER`.

---

### T10: N+1 Solutions Comparison (Ch8)

| Solution | Syntax | Pros | Cons | When to Use |
|---|---|---|---|---|
| **JOIN FETCH** | `SELECT u FROM User u JOIN FETCH u.orders` | Single SQL query; simple for straightforward cases | Cartesian product with multiple collections; cannot paginate with collections | Single collection; no pagination; small result sets |
| **@EntityGraph** | `@EntityGraph(attributePaths = {"orders"})` on repository method | Declarative; reusable across queries; works with Spring Data | Still Cartesian product issue with multiple collections | Spring Data repos; avoid multiple collection paths together |
| **Batch Fetching (`@BatchSize`)** | `@BatchSize(size = 25)` on collection; `hibernate.default_batch_fetch_size` | Works with pagination; reduces N+1 to N/batch+1 queries | Slightly more queries than JOIN FETCH; less predictable | Paginated queries with collections; large datasets |
| **DTO Projection** | `SELECT new com.example.UserDTO(u.id, u.name) FROM User u JOIN u.orders o` | Maximum control; no entity overhead; best performance | More boilerplate; must maintain DTO classes | Reporting, read-only views, high-volume queries |

---

## REST & Microservices Tables

---

### T11: HTTP Methods — Safety & Idempotency (Ch9)

| Method | Safe | Idempotent | Request Body | Cacheable | Typical Status Codes |
|---|---|---|---|---|---|
| `GET` | Yes | Yes | No (allowed but discouraged) | Yes | 200, 304, 404 |
| `POST` | No | No | Yes | Rarely (must have explicit cache headers) | 201, 200, 202, 400, 409, 422 |
| `PUT` | No | Yes | Yes | No | 200, 204, 201, 400, 404 |
| `PATCH` | No | No (generally) | Yes | No | 200, 204, 400, 404, 409 |
| `DELETE` | No | Yes | Optional | No | 200, 204, 404 |
| `HEAD` | Yes | Yes | No | Yes | 200, 404 (same as GET, no body) |
| `OPTIONS` | Yes | Yes | No | No | 200, 204 |

> **Safe** = does not modify server state. **Idempotent** = same result regardless of how many times applied. PATCH is technically not guaranteed idempotent (depends on operation, e.g., `increment by 1`).

---

### T12: HTTP Status Codes Reference (Ch9)

| Code | Name | When to Use | Common Mistake |
|---|---|---|---|
| **200** | OK | Successful GET, PUT, PATCH, POST (non-creation) | Returning 200 with error details in body — use proper 4xx/5xx |
| **201** | Created | Successful resource creation (POST/PUT) | Forgetting `Location` header pointing to new resource |
| **202** | Accepted | Async operation accepted for processing | Not providing a way to poll/check status |
| **204** | No Content | Successful DELETE or PUT with no response body | Returning 204 for POST — use 200 or 201 |
| **301** | Moved Permanently | Permanent URL redirect | Browsers cache 301 aggressively; hard to undo |
| **302** | Found (Temporary Redirect) | Temporary redirect | Using 302 when 307 is meant (method preservation) |
| **304** | Not Modified | Conditional GET; resource unchanged | Not implementing ETag / Last-Modified validation |
| **400** | Bad Request | Malformed request, invalid syntax, missing required fields | Using 400 for business logic violations (use 422) |
| **401** | Unauthorized | Missing or invalid authentication credentials | Confusing with 403 — 401 means "not authenticated" |
| **403** | Forbidden | Authenticated but not authorized | Confusing with 401 — 403 means "authenticated but no permission" |
| **404** | Not Found | Resource does not exist | Leaking existence via 403 vs 404 (security consideration) |
| **405** | Method Not Allowed | HTTP method not supported for this endpoint | Not including `Allow` header listing valid methods |
| **409** | Conflict | State conflict (duplicate, version mismatch, concurrent edit) | Using 400 when the conflict is the key point |
| **410** | Gone | Resource permanently deleted (stronger than 404) | Not using it; search engines deindex faster with 410 |
| **422** | Unprocessable Entity | Well-formed request but semantic/business validation fails | Using 400 for everything; 422 is preferred for validation errors |
| **429** | Too Many Requests | Rate limit exceeded | Not including `Retry-After` header |
| **500** | Internal Server Error | Unhandled server exception | Leaking stack traces in response body |
| **502** | Bad Gateway | Upstream service returned invalid response | Confusing with 503 (502 = bad response, 503 = no response) |
| **503** | Service Unavailable | Server overloaded or down for maintenance | Not including `Retry-After` header for maintenance windows |
| **504** | Gateway Timeout | Upstream service timed out | Not distinguishing from 503 — 504 implies timeout specifically |

---

### T13: REST vs GraphQL vs gRPC (Ch9)

| Dimension | REST | GraphQL | gRPC |
|---|---|---|---|
| **Protocol** | HTTP/1.1 or HTTP/2 | HTTP/1.1 or HTTP/2 | HTTP/2 (required) |
| **Payload Format** | JSON (typically), XML | JSON | Protocol Buffers (binary) |
| **Typing** | Informal (OpenAPI/Swagger) | Strongly typed schema (SDL) | Strongly typed (`.proto` files) |
| **Streaming** | Limited (SSE, WebSocket separately) | Subscriptions (WebSocket) | Bidirectional streaming (native) |
| **Browser Support** | Native | Native | Needs grpc-web proxy |
| **Over/Under-fetching** | Common (fixed endpoints) | None (client specifies fields) | None (defined contracts) |
| **Use Case** | Public APIs, CRUD, wide compatibility | Flexible data fetching, mobile clients, BFFs | Internal microservices, high-performance, polyglot |
| **Spring Integration** | `spring-web` (`@RestController`) | `spring-graphql` | `grpc-spring-boot-starter` |

---

### T14: Circuit Breaker States (Ch10)

| State | Description | When Transitions | Requests Allowed | Resilience4j Config |
|---|---|---|---|---|
| **CLOSED** | Normal operation; requests pass through | Failure rate exceeds `failureRateThreshold` (default 50%) over `slidingWindowSize` → moves to OPEN | All | `failureRateThreshold`, `slidingWindowSize`, `slidingWindowType` |
| **OPEN** | Circuit broken; requests rejected immediately | After `waitDurationInOpenState` (default 60s) → moves to HALF_OPEN | None (fallback invoked) | `waitDurationInOpenState` |
| **HALF-OPEN** | Probe state; limited requests allowed through | If `permittedNumberOfCallsInHalfOpenState` succeed → CLOSED; if failure rate too high → OPEN | Limited (`permittedNumberOfCallsInHalfOpenState`, default 10) | `permittedNumberOfCallsInHalfOpenState` |

> **Resilience4j key annotations:** `@CircuitBreaker(name="myService", fallbackMethod="fallback")`. Combine with `@Retry` and `@TimeLimiter` for full resilience pattern.

---

### T15: Saga Pattern Comparison (Ch10)

| Dimension | Choreography | Orchestration |
|---|---|---|
| **Coordination** | Event-driven; each service listens and reacts to events | Central orchestrator (saga coordinator) issues commands to services |
| **Coupling** | Loose (services know only events, not each other) | Tighter (orchestrator knows all participants) |
| **Visibility** | Hard to trace overall flow; requires correlation IDs + distributed tracing | Easy to visualize; flow is in the orchestrator's state machine |
| **Failure Handling** | Each service emits compensating events; complex to manage | Orchestrator coordinates compensating transactions centrally |
| **Implementation** | Kafka topics / event bus; each service has a saga handler | Temporal, AWS Step Functions, Axon Framework, or custom state machine |
| **Cyclic Dependencies** | Risk of event cycles | No cycles (orchestrator is hub) |
| **Best For** | Simple flows, small team, high decoupling needed | Complex multi-step transactions, need audit trail, large teams |

---

### T16: OAuth2 Grant Types (Ch13)

| Grant Type | Use Case | Who Initiates | Refresh Token | Security Level | Spring Support |
|---|---|---|---|---|---|
| **Authorization Code** | Server-side web apps with backend | User via browser redirect | Yes | High (code exchange server-side) | `spring-security-oauth2-client` |
| **Auth Code + PKCE** | SPAs, mobile apps, public clients | User via browser/app | Yes (optional) | High (PKCE prevents code interception) | `spring-security-oauth2-client` (recommended for public clients) |
| **Client Credentials** | Machine-to-machine, service accounts, APIs | Service/daemon | No | High (no user involved) | `spring-security-oauth2-client` with `ClientRegistration` |
| **Device Flow** | Browserless/input-constrained devices (IoT, CLI, TV) | Device polls token endpoint | Yes | Medium (polling, user authorizes on separate device) | Manual or custom `RestTemplate` flow |
| **Implicit (Deprecated)** | Legacy SPAs | User via browser | No | Low (access token in URL fragment; XSS risk) | Available but not recommended; use PKCE instead |
| **Resource Owner Password Credentials (ROPC) (Deprecated)** | Legacy trusted apps | Client sends username/password directly | Yes | Very Low (credentials exposed to client) | Available but avoid; use Authorization Code |

---

## Kafka Tables

---

### T17: Kafka Delivery Semantics (Ch11)

| Semantic | Producer acks | Consumer Commit | Duplicate Risk | Data Loss Risk | Performance | How to Achieve |
|---|---|---|---|---|---|---|
| **At-most-once** | `acks=0` or `acks=1` | Commit before processing | None | High (failure = message lost) | Highest | Auto-commit enabled; commit before `process()`; no retries |
| **At-least-once** | `acks=all` + retries | Commit after processing | High (failure before commit → reprocessing) | None | Medium | `enable.auto.commit=false`; commit after successful processing; idempotent consumers required |
| **Exactly-once** | `acks=all` + idempotent producer (`enable.idempotence=true`) | Transactional commit | None | None | Lowest | `enable.idempotence=true`; `transactional.id` set; `isolation.level=read_committed` on consumer; Kafka Streams EOS |

---

### T18: Kafka acks Settings (Ch11)

| Setting | Durability | Latency | Throughput | When to Use |
|---|---|---|---|---|
| `acks=0` | None (fire and forget) | Lowest | Highest | Metrics, logs, non-critical telemetry where loss is acceptable |
| `acks=1` | Leader acknowledged only | Low | High | Moderate durability; leader failure before replication = data loss |
| `acks=all` (or `acks=-1`) | All in-sync replicas (ISR) acknowledged | Higher | Lower | Financial data, order events, any critical data; combine with `min.insync.replicas=2` |

> **Best practice:** `acks=all` + `min.insync.replicas=2` + `enable.idempotence=true` for production pipelines.

---

### T19: Kafka vs RabbitMQ vs SQS (Ch11)

| Dimension | Kafka | RabbitMQ | Amazon SQS |
|---|---|---|---|
| **Model** | Distributed commit log (pull-based) | Message broker (push/pull, routing) | Managed queue (pull-based) |
| **Ordering** | Per partition (guaranteed) | Per queue (single consumer) | FIFO queue option; standard = best-effort |
| **Message Retention** | Configurable (hours to forever) | Until consumed (or TTL) | Up to 14 days |
| **Consumer Groups / Competing Consumers** | Consumer groups (each group gets all messages) | Competing consumers on a queue | Competing consumers only |
| **Replay** | Yes (seek to any offset) | No (once consumed, gone) | No (once deleted, gone) |
| **Throughput** | Millions/sec (horizontal partition scaling) | Hundreds of thousands/sec | High (AWS managed, scales automatically) |
| **Latency** | Low ms (> SQS for very small messages) | Very low ms | Single-digit ms to tens of ms |
| **Managed Option** | Confluent Cloud, MSK (AWS), Aiven | CloudAMQP, AmazonMQ | AWS SQS (fully managed) |
| **Best For** | Event streaming, audit log, high-throughput pipelines, event sourcing | Complex routing, task queues, RPC patterns, pub/sub with routing | Simple decoupling, AWS-native workloads, serverless (Lambda) triggers |

---

## Database Tables

---

### T20: SQL JOIN Types (Ch14)

| JOIN Type | Returns | NULL Behavior | Use Case | Example |
|---|---|---|---|---|
| `INNER JOIN` | Rows matching in **both** tables | No NULLs from join (only matched rows) | Fetch related data that must exist in both tables | `SELECT * FROM orders o INNER JOIN customers c ON o.customer_id = c.id` |
| `LEFT OUTER JOIN` | All rows from **left** table + matching right rows | Right-side columns are NULL when no match | Include all left rows even without a match (e.g., customers with no orders) | `SELECT * FROM customers c LEFT JOIN orders o ON c.id = o.customer_id` |
| `RIGHT OUTER JOIN` | All rows from **right** table + matching left rows | Left-side columns are NULL when no match | Include all right rows; less common (can rewrite as LEFT JOIN) | `SELECT * FROM orders o RIGHT JOIN customers c ON o.customer_id = c.id` |
| `FULL OUTER JOIN` | All rows from **both** tables | NULLs on either side when no match | Complete picture; finding non-matching rows in either table | `SELECT * FROM a FULL OUTER JOIN b ON a.id = b.id` |
| `CROSS JOIN` | Cartesian product of both tables | No NULLs | Generate combinations; test data; calendar × products | `SELECT * FROM products CROSS JOIN colors` |
| `SELF JOIN` | Rows from the **same** table joined to itself | Depends on join type used | Hierarchical data (manager-employee), comparing rows within same table | `SELECT e.name, m.name FROM employees e LEFT JOIN employees m ON e.manager_id = m.id` |

---

### T21: Index Types Comparison (Ch15)

| Index Type | Best Data Type | Range Scan | Equality | Use Case | PostgreSQL Support | Size Overhead |
|---|---|---|---|---|---|---|
| **B-tree** | Any ordered type (int, varchar, date) | Yes | Yes | Default; most queries; ORDER BY, BETWEEN, comparisons | Yes (default) | Medium |
| **Hash** | Exact equality only | No | Yes (O(1)) | Equality-only lookups on large tables | Yes (PostgreSQL 10+ crash-safe) | Low |
| **GIN** (Generalized Inverted) | Arrays, JSONB, full-text, tsvector | No | Yes (containment, overlap) | JSONB key queries, array contains, full-text search | Yes | High |
| **GiST** (Generalized Search Tree) | Geometric, range types, PostGIS | Yes (range/spatial) | Yes | Spatial data (PostGIS), range types, nearest-neighbor | Yes | Medium-High |
| **BRIN** (Block Range Index) | Large naturally-ordered tables (timestamps, sequential IDs) | Yes (approximate) | No (inexact) | Time-series, append-only tables; very small index size | Yes | Very Low |
| **Partial Index** | Any (with WHERE clause) | Yes | Yes | Index subset of rows (e.g., `WHERE status = 'active'`) | Yes | Small (only indexed rows) |
| **Functional / Expression Index** | Result of a function/expression | Yes | Yes | `LOWER(email)` searches, computed columns | Yes | Medium (stores computed values) |

---

### T22: CAP Theorem Systems Classification (Ch16/Ch17)

| System | CAP Classification | Consistency Model | Replication | Best For |
|---|---|---|---|---|
| **ZooKeeper** | CP | Strong (linearizable) | Leader-follower (Paxos/ZAB) | Distributed coordination, leader election, config |
| **etcd** | CP | Strong (linearizable via Raft) | Raft consensus | Kubernetes config store, service discovery |
| **Cassandra** | AP (tunable) | Eventual (tunable via quorum: `ONE` to `ALL`) | Multi-master, peer-to-peer | High write throughput, geographically distributed |
| **DynamoDB** | AP (tunable) | Eventual (default); Strong (optional, extra cost) | Multi-AZ, AWS-managed | Serverless, AWS-native, key-value at massive scale |
| **CockroachDB** | CP | Serializable (distributed MVCC) | Raft per range | Distributed SQL, global ACID transactions |
| **MongoDB** | CP (primary reads); AP (secondary reads) | Strong (primary); Eventual (secondary reads) | Replica set (leader-follower) | Document store, flexible schema, general purpose |
| **Redis** | CP (single-node); AP (cluster) | Strong (single); Eventual (cluster async replication) | Master-replica; Redis Cluster | Caching, session store, pub/sub, leaderboards |
| **Spanner (Google)** | CP (effectively) | External consistency (TrueTime) | Paxos, multi-region | Global ACID SQL at planetary scale |
| **MySQL (single)** | CA (no partition tolerance in single node) | Strong (ACID) | N/A (single node) | Traditional OLTP on single server |
| **MySQL (cluster / Galera)** | CP | Synchronous replication (wsrep) | Synchronous multi-master | HA MySQL with write synchronization |

> **Note:** No real system is purely CA in a distributed environment; partition tolerance is mandatory when nodes communicate over a network.

---

### T23: NoSQL Database Selection Guide (Ch17)

| Type | Examples | Data Model | Query Patterns | Consistency | Scale | Java Client | Best For |
|---|---|---|---|---|---|---|---|
| **Key-Value** | Redis, DynamoDB, Memcached | Flat key → value pairs | Get, put, delete by key; scan (limited) | Eventual (usually) | Horizontal (sharding) | Jedis, Lettuce (Redis); AWS SDK (DynamoDB) | Session caching, user preferences, rate limiting, leaderboards |
| **Document** | MongoDB, Couchbase, Firestore | JSON/BSON documents in collections | Rich queries, aggregation pipelines, indexing on nested fields | Tunable (eventual to strong) | Horizontal (sharding) | MongoDB Driver, Spring Data MongoDB | Catalogs, CMS, user profiles, semi-structured data |
| **Wide-Column** | Cassandra, HBase, ScyllaDB | Rows with dynamic columns; partition + clustering keys | Partition-key lookups; range scans on clustering key | Tunable (eventual to quorum) | Horizontal (peer-to-peer) | DataStax Java Driver, Spring Data Cassandra | IoT time-series, activity feeds, write-heavy workloads |
| **Graph** | Neo4j, Amazon Neptune, JanusGraph | Nodes and edges with properties | Cypher/Gremlin traversals, path finding, connected data | Strong (ACID for Neo4j) | Vertical + limited horizontal | Neo4j Java Driver, Spring Data Neo4j | Social networks, fraud detection, recommendation engines, knowledge graphs |
| **Time-Series** | InfluxDB, TimescaleDB, Prometheus | Timestamped measurements | Time-range queries, aggregations (avg, max over window), downsampling | Eventual (most) | Horizontal (sharding/partitioning) | InfluxDB Java Client, JDBC (TimescaleDB) | Metrics, monitoring, financial tick data, sensor readings |
| **Search** | Elasticsearch, OpenSearch, Solr | Inverted index over JSON documents | Full-text search, relevance scoring, aggregations, geo queries | Eventual | Horizontal (shards + replicas) | Elasticsearch Java Client, Spring Data Elasticsearch | Full-text search, log analytics, autocomplete, faceted search |

---

### T24: Sharding Strategies (Ch17/Ch18)

| Strategy | Key Selection | Hotspot Risk | Resharding Difficulty | Cross-Shard Query | Use Case |
|---|---|---|---|---|---|
| **Range Sharding** | Ordered key ranges (e.g., user IDs 1–1M on shard 1) | High (sequential inserts hit latest shard; popular ranges) | Easy (split ranges) | Easy (range queries stay on shard) | Time-series where recent data is accessed most; ordered data |
| **Hash Sharding** | Hash(key) mod N → shard | Low (uniform distribution) | Hard (rehashing moves all data) | Hard (scatter-gather required) | User data, random-access workloads, uniform distribution needed |
| **Directory Sharding** | Lookup table maps key → shard | Low | Easy (update lookup table) | Medium | Flexible routing; different entities on different shards |
| **Geo-based Sharding** | User region / country → shard | Medium (unequal geography) | Medium | Hard (cross-region queries) | Data residency requirements, latency reduction for regional users |
| **Consistent Hash Ring** | Virtual nodes on hash ring; key mapped to nearest node | Low (even with virtual nodes) | Easy (only neighboring shards affected) | Hard | Distributed caches (Cassandra, Memcached); elastic scaling |

---

### T25: Multi-Tenancy Patterns (Ch18)

| Pattern | Isolation | Cost | Complexity | Scale Limit | Regulatory Compliance | Spring Implementation |
|---|---|---|---|---|---|---|
| **Shared Table (`tenant_id` column)** | Low (data mixed in same tables) | Lowest | Low | Highest (single DB) | Hard (data co-mingled, hard to purge per-tenant) | Filter via Hibernate Filter / JPA criteria on every query; `@TenantId` in Hibernate 6 |
| **Shared Schema (Row-Level Security)** | Medium (DB enforces RLS per tenant) | Low | Medium | High | Medium (DB-enforced isolation, but same schema) | PostgreSQL RLS + Hibernate `TenantIdentifierResolver`; Spring's `AbstractRoutingDataSource` |
| **Separate Schema per Tenant** | Medium-High (schema isolation) | Medium | Medium-High | Medium (DB handles ~100–1000 schemas) | Good (schema-level separation; easier to export/purge) | Hibernate multi-tenancy `SCHEMA` mode; `DataSourceBasedMultiTenantConnectionProviderImpl` |
| **Separate Database per Tenant** | Highest (full DB isolation) | Highest | High | Lowest (ops overhead per tenant) | Best (complete separation; GDPR deletion trivial) | Spring `AbstractRoutingDataSource`; per-tenant `DataSource` beans; Flyway per-tenant migration |

---

## Caching & Security Tables

---

### T26: Cache Eviction Policies (Ch12)

| Policy | Evicts | Best For | Redis Config Value | Memory Pressure Behavior |
|---|---|---|---|---|
| **LRU** (Least Recently Used) | Least recently accessed key | General-purpose cache; temporal locality expected | `allkeys-lru` / `volatile-lru` | Evicts keys not accessed recently; good for general web caches |
| **LFU** (Least Frequently Used) | Least frequently accessed key | Access frequency matters more than recency; hot-cold data | `allkeys-lfu` / `volatile-lfu` | Retains frequently accessed keys; better than LRU for skewed access patterns |
| **LRU-K** | Key not accessed in last K references | Advanced; approximates optimal; reduces one-time scan pollution | N/A (not native Redis; algorithmic) | Prevents one-time-access items from evicting hot items |
| **allkeys-lru** | Any key (LRU order) regardless of TTL | Cache-only Redis; all keys are cache candidates | `maxmemory-policy allkeys-lru` | Evicts any key; good when all data is cache data |
| **volatile-lru** | Only keys with TTL set, LRU order | Mixed usage (cache + persistent); protect non-expiring keys | `maxmemory-policy volatile-lru` | Only TTL keys evicted; non-TTL keys never evicted |
| **allkeys-random** | Any random key | Random access patterns; when LRU overhead is undesirable | `maxmemory-policy allkeys-random` | Unpredictable eviction; generally avoid unless truly random access |
| **volatile-TTL** | Key with shortest TTL first | When TTL is a good proxy for importance | `maxmemory-policy volatile-ttl` | Evicts keys expiring soonest; useful for time-windowed data |
| **noeviction** (default) | Nothing; returns OOM error | Databases using Redis; cannot afford cache eviction | `maxmemory-policy noeviction` | Rejects writes when memory full; client receives error |

---

### T27: Caching Patterns (Ch12)

| Pattern | Read Path | Write Path | Consistency | Implementation Complexity | Best For |
|---|---|---|---|---|---|
| **Cache-Aside** (Lazy Loading) | App checks cache; on miss, loads from DB, populates cache | App writes to DB; invalidates or updates cache separately | Eventual (cache may be stale between write and invalidation) | Low | General purpose; read-heavy; when stale data is acceptable briefly |
| **Read-Through** | App reads from cache; cache loads from DB on miss automatically | App writes to DB (or via cache) | Eventual | Medium (cache provider must support it) | Read-heavy workloads; transparently backed by DB (JPA 2nd level cache) |
| **Write-Through** | App reads from cache | App writes to cache; cache synchronously writes to DB | Strong (cache and DB always in sync) | Medium | Write + read heavy; data must always be fresh; no stale reads |
| **Write-Behind** (Write-Back) | App reads from cache | App writes to cache; cache asynchronously writes to DB | Eventual (DB may lag cache) | High (async flush, crash recovery needed) | Write-heavy workloads; reduce DB write pressure; tolerate brief inconsistency |
| **Refresh-Ahead** | App reads from cache (always hits) | Background thread refreshes cache before TTL expires | Strong (proactively refreshed) | High (background refresh logic, predicting access) | Highly predictable access patterns; critical low-latency reads |

---

### T28: Password Hashing Algorithms (Ch13)

| Algorithm | Type | Salt | Iterations/Cost | Memory-Hard | GPU-Resistant | Recommended | Spring PasswordEncoder Class |
|---|---|---|---|---|---|---|---|
| **MD5** | Fast hash (cryptographic) | No (must add manually) | None | No | No | Never (broken) | `MessageDigestPasswordEncoder` (deprecated) |
| **SHA-1** | Fast hash (cryptographic) | No (must add manually) | None | No | No | Never (broken) | `MessageDigestPasswordEncoder` (deprecated) |
| **SHA-256** | Fast hash (cryptographic) | No (must add manually) | None | No | No | Never for passwords (fast = brute-forceable) | Not recommended |
| **bcrypt** | Adaptive slow hash | Yes (built-in, 22 chars) | Work factor (default 10; ~100ms) | No | Partially (sequential operations limit GPU) | Yes (widely supported) | `BCryptPasswordEncoder` |
| **scrypt** | Memory-hard KDF | Yes | N (CPU), r (block), p (parallel) | Yes | Yes | Yes | `SCryptPasswordEncoder` |
| **Argon2id** | Memory-hard KDF (NIST/OWASP recommended) | Yes | `memory`, `iterations`, `parallelism` | Yes | Yes | **Best choice** (winner of Password Hashing Competition) | `Argon2PasswordEncoder` |

> **OWASP recommendation (2024):** Argon2id with m=64MB, t=3 iterations, p=4 lanes. If Argon2 unavailable, use bcrypt with work factor ≥ 12.

---

## System Design Tables

---

### T29: Latency Numbers Every Engineer Should Know (Ch22)

| Operation | Latency | Notes |
|---|---|---|
| L1 cache reference | ~1 ns | On-chip; fastest memory |
| L2 cache reference | ~4 ns | Still on-die; ~4× L1 |
| L3 cache reference | ~40 ns | Shared across cores; ~40× L1 |
| Mutex lock/unlock | ~25 ns | Uncontended; includes memory barrier |
| Main memory (RAM) access | ~100 ns | ~100× L1 cache |
| Context switch (OS) | ~1–10 µs | Depends on kernel, CPU, and scheduler |
| NVMe SSD random read | ~100 µs | Modern NVMe; 4KB block |
| SSD random read (SATA) | ~100–200 µs | Typical SATA SSD |
| SSD sequential read | ~1 GB/s throughput (~1 µs/KB) | Sequential bandwidth; modern NVMe higher |
| HDD seek time | ~10 ms | Mechanical arm movement; 10,000× RAM |
| Compress 1 KB with Snappy | ~3 µs | CPU-bound; fast compression |
| Send 1 KB over 1 Gbps network | ~10 µs | Transfer only; not including latency |
| Network round-trip (same datacenter) | ~500 µs | LAN; includes switch hops |
| Network round-trip (cross-region, same continent) | ~10–40 ms | Transcontinental fiber |
| Network round-trip (cross-continent, US–EU) | ~80–120 ms | Transatlantic |
| Packet round-trip (same host loopback) | ~50 µs | OS networking stack overhead |
| Read 1 MB sequentially from RAM | ~250 µs | Memory bandwidth limited |
| Read 1 MB sequentially from SSD | ~1 ms | Flash bandwidth |
| Read 1 MB sequentially from HDD | ~20 ms | Rotational speed limited |
| Database query (indexed, local) | ~1–5 ms | Well-optimized, warm cache |
| Database query (cross-network) | ~5–20 ms | Includes network round-trip |

> **Key rule of thumb:** RAM < µs. Local SSD < ms. Network same DC < 1 ms. Cross-region > 10 ms. HDD seeks are death at scale.

---

### T30: Design Patterns Quick Reference (Ch19)

| Pattern | Category | Intent | Java Example | Spring Example |
|---|---|---|---|---|
| **Abstract Factory** | Creational | Create families of related objects without specifying concrete classes | `DocumentFactory` creates `Button` + `Checkbox` per OS | `ApplicationContext` creates environment-specific beans |
| **Builder** | Creational | Construct complex objects step by step; separate construction from representation | `StringBuilder`, `Lombok @Builder`, `UriComponentsBuilder` | `MockMvcRequestBuilders`, `BeanDefinitionBuilder` |
| **Factory Method** | Creational | Define interface for creating objects; let subclasses decide which class to instantiate | `Calendar.getInstance()`, `Collection.iterator()` | `FactoryBean<T>`, `@Bean` factory methods |
| **Prototype** | Creational | Create new objects by cloning an existing object | `Object.clone()`, copy constructors | Spring `prototype` scope; `@Scope("prototype")` |
| **Singleton** | Creational | Ensure a class has only one instance and provide global access | Double-checked locking, enum singleton | Spring `singleton` bean scope (default) |
| **Adapter** | Structural | Convert incompatible interface into one the client expects | `Arrays.asList()` (array → List), `InputStreamReader` | Spring MVC `HandlerAdapter`, `JpaVendorAdapter` |
| **Bridge** | Structural | Decouple abstraction from implementation so both can vary independently | Shape + DrawingAPI separation | `JdbcTemplate` (abstraction) + JDBC driver (implementation) |
| **Composite** | Structural | Compose objects into tree structures; treat individual and compositions uniformly | `File` + `Directory` (both are `FileSystemItem`) | Spring `SecurityFilterChain` (composite of filters) |
| **Decorator** | Structural | Add responsibilities to objects dynamically without subclassing | `BufferedInputStream(new FileInputStream(...))` | Spring AOP advice, `HttpServletRequestWrapper` |
| **Facade** | Structural | Simplified interface to a complex subsystem | `SLF4J` over Logback/Log4j | Spring's `JdbcTemplate` (facade over raw JDBC), `RestTemplate` |
| **Flyweight** | Structural | Share common state among many fine-grained objects to reduce memory | Integer cache (`Integer.valueOf()`), String pool | Spring bean singleton scope for stateless beans |
| **Proxy** | Structural | Provide a surrogate to control access to another object | `java.lang.reflect.Proxy`, CGLIB proxy | Spring AOP, `@Transactional`, `@Cacheable` (JDK/CGLIB proxy) |
| **Chain of Responsibility** | Behavioral | Pass request along a chain of handlers; each decides to handle or pass | `javax.servlet.Filter` chain | Spring Security `FilterChain`, Spring MVC `HandlerInterceptor` |
| **Command** | Behavioral | Encapsulate a request as an object; support undo, queuing, logging | `Runnable`, `Callable`, menu actions | Spring `@Scheduled` tasks, Spring Batch `Step` |
| **Interpreter** | Behavioral | Define grammar and interpreter for a language | SQL parser, `java.util.regex.Pattern` | Spring SpEL (`@Value("#{...}")`) |
| **Iterator** | Behavioral | Provide sequential access to elements without exposing underlying structure | `java.util.Iterator`, enhanced for-loop | Spring Data `Streamable<T>`, `Page<T>` |
| **Mediator** | Behavioral | Reduce direct dependencies between objects by introducing a mediator | Air traffic control, chat room | Spring `ApplicationEventPublisher`, `@EventListener` |
| **Memento** | Behavioral | Capture and restore an object's internal state without violating encapsulation | Undo in text editors, game save states | Spring Batch `ExecutionContext` (job state) |
| **Observer** | Behavioral | Notify multiple objects when state changes | `java.util.Observer` (deprecated), `PropertyChangeListener` | Spring `ApplicationEvent` / `@EventListener`, Spring Reactor `Flux` |
| **State** | Behavioral | Allow object to alter its behavior when internal state changes | Vending machine states, order lifecycle | Spring State Machine (`spring-statemachine`), workflow engines |
| **Strategy** | Behavioral | Define family of algorithms; make them interchangeable | `Comparator`, `Comparator.comparing()` | Spring Security `AuthenticationStrategy`, Spring MVC `ViewResolver` |
| **Template Method** | Behavioral | Define skeleton of algorithm in base class; defer steps to subclasses | `AbstractList`, `AbstractMap` | `JdbcTemplate`, `RestTemplate`, Spring Batch `AbstractItemReader` |
| **Visitor** | Behavioral | Add operations to object structure without modifying classes | `javax.lang.model.element.ElementVisitor`, file system traversal | Spring `BeanDefinitionVisitor`, AST visitors in annotation processors |

---

*End of Appendix B — Master Reference Tables*

*Cross-reference index: T1–T5 (Ch3–6 Java Core) · T6–T10 (Ch7–8 Spring/JPA) · T11–T16 (Ch9–10, 13 REST/Microservices) · T17–T19 (Ch11 Kafka) · T20–T25 (Ch14–18 Databases) · T26–T28 (Ch12–13 Cache/Security) · T29–T30 (Ch22, Ch19 System Design)*

