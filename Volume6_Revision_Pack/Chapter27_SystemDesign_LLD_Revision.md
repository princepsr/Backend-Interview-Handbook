# Volume 6: Interview Revision Pack
# Chapter 27: System Design, LLD & Mock Interview

---

## Section 1: Design Patterns — Top 15 Questions

### 1. Singleton — Thread-Safe Variants
- **DCL + volatile** (Java 5+):
  ```java
  private static volatile Singleton instance;
  public static Singleton getInstance() {
      if (instance == null) {
          synchronized (Singleton.class) {
              if (instance == null) instance = new Singleton();
          }
      }
      return instance;
  }
  ```
  - `volatile` prevents instruction reordering; without it, partially constructed object can leak.
- **Enum Singleton** (preferred):
  ```java
  public enum Singleton { INSTANCE; }
  ```
  - JVM guarantees single instance; serialization-safe; reflection-safe.
- **Holder Pattern** (lazy, no sync overhead):
  ```java
  private static class Holder { static final Singleton INSTANCE = new Singleton(); }
  ```

### 2. Factory vs Abstract Factory
| | Factory Method | Abstract Factory |
|---|---|---|
| Creates | One product | Family of related products |
| Subclassing | One creator subclass per product | One factory per product family |
| Use when | Type unknown at compile time | Need consistent product families |
- Factory: `ShapeFactory.create("circle")` → returns Shape
- Abstract Factory: `GUIFactory` → creates Button + Checkbox (both OS-specific)

### 3. Builder vs Telescoping Constructor
- **Telescoping**: `new Pizza(size, cheese, pepperoni, mushrooms)` — unreadable, error-prone
- **Builder**: Fluent API, immutable result, optional parameters readable
  ```java
  Pizza p = new Pizza.Builder(size).cheese(true).pepperoni(true).build();
  ```
- Use Builder when: 4+ parameters, many optional, immutability needed
- **Director** pattern: encapsulates common build sequences

### 4. Adapter vs Decorator vs Proxy — Key Difference
| Pattern | Purpose | Interface change? |
|---|---|---|
| Adapter | Convert incompatible interface | Yes — wraps old, exposes new |
| Decorator | Add behavior at runtime | No — same interface, adds functionality |
| Proxy | Control access | No — same interface, controls/intercepts |
- Adapter: Legacy XML API → new JSON API
- Decorator: `BufferedInputStream(new FileInputStream(...))` — add buffering
- Proxy: Spring AOP `@Transactional`, Hibernate lazy loading

### 5. Observer — Push vs Pull
- **Push**: Subject sends full data to observers → observer gets more than needed, simpler
- **Pull**: Subject sends minimal notification, observer pulls needed data → decoupled, observer controls
- Java: `java.util.Observable` (push), `EventListener` (pull)
- Spring: `ApplicationEventPublisher` → publish/subscribe

### 6. Strategy vs Template Method
| | Strategy | Template Method |
|---|---|---|
| Varies behavior | Composition (inject algorithm) | Inheritance (override hook) |
| Runtime change | Yes | No |
| Relation | Has-a | Is-a |
- Strategy: `SortContext(new QuickSortStrategy())` — swap at runtime
- Template Method: `AbstractReport.generate()` calls `abstract fetchData()` — fixed skeleton, variable steps

### 7. Chain of Responsibility
- Decouple sender from receiver; handlers form a chain, each decides process or pass
- Use: Servlet Filters, Spring Security Filter Chain, middleware pipelines
- Key: each handler has reference to next; avoid long chains (performance)

### 8. Command (Undo/Redo)
- Encapsulates request as object: `execute()`, `undo()`
- Stack-based undo: push executed commands; undo pops and calls `undo()`
- Use: text editors, transaction managers, task queues
- `Invoker` → `Command` interface → `ConcreteCommand` → `Receiver`

### 9. State FSM
- Object behavior changes based on internal state; state transitions are explicit
- Example: Order (NEW → PAID → SHIPPED → DELIVERED → CANCELLED)
- Each state is a class implementing `State` interface; eliminates large if-else chains
- Use: workflow engines, vending machines, TCP connections

### 10. Composite
- Tree structure; treat individual objects and compositions uniformly
- `Component` interface ← `Leaf` + `Composite` (has children)
- Use: file system (File + Directory), org charts, UI components

### 11. Spring AOP = Proxy + Decorator
- Spring wraps beans in JDK Dynamic Proxy (interface-based) or CGLIB proxy (class-based)
- `@Transactional`, `@Cacheable`, `@Async` all use AOP proxies
- Proxy controls access (checks, wrapping); Decorator adds behavior (logging, caching)
- **Self-invocation problem**: calling annotated method within same class bypasses proxy

### 12. Java I/O = Decorator
- `InputStream` → `FileInputStream` (Leaf) → `BufferedInputStream(FileInputStream)` → `DataInputStream(BufferedInputStream(...))`
- Each wrapper adds behavior (buffering, data parsing) without changing interface

### 13. When to Use Each Pattern (Quick Guide)
- Singleton: shared resource (config, connection pool)
- Factory/Abstract Factory: object creation varies by type/family
- Builder: complex object construction
- Adapter: integrate legacy/third-party code
- Decorator: add behavior without subclassing
- Proxy: lazy loading, access control, logging
- Observer: event-driven, loose coupling
- Strategy: interchangeable algorithms
- Template Method: fixed algorithm with variable steps
- Command: undo/redo, queuing operations
- State: behavior varies by state
- Composite: hierarchical structures
- Chain of Responsibility: pipeline processing

### 14. Anti-Patterns (Know These)
- **God Object**: class knows/does too much → violates SRP, hard to test
- **Spaghetti Code**: tangled control flow, no structure → extract methods/classes
- **Golden Hammer**: use familiar pattern for everything → "if all you have is a hammer..."
- **Lava Flow**: dead code kept for fear of breakage → delete with tests
- **Premature Optimization**: optimize before profiling → write clear code first
- **Cargo Cult Programming**: copy-paste patterns without understanding

### 15. Pattern Interview Traps
- "Singleton is anti-pattern in microservices" → agree; use DI container instead
- "Can you use Strategy + Factory together?" → Yes, factory creates the strategy
- "Decorator vs Inheritance?" → Decorator is more flexible, no combinatorial explosion
- "Observer vs Event Bus?" → Event bus decouples even further (no direct ref to subject)

---

## Section 2: SOLID — Top 10 Questions

### Core SOLID Principles
| Principle | One-liner | Violation Example |
|---|---|---|
| **SRP** — Single Responsibility | One class, one reason to change | `UserService` handles auth + email + DB |
| **OCP** — Open/Closed | Open for extension, closed for modification | `if type == "circle" ... if type == "rect"` |
| **LSP** — Liskov Substitution | Subtype must be substitutable for base type | `Square extends Rectangle` breaks setWidth/setHeight |
| **ISP** — Interface Segregation | Many specific interfaces > one fat interface | `Animal` with `fly()` forces `Dog` to implement |
| **DIP** — Dependency Inversion | Depend on abstractions, not concretions | `OrderService` directly instantiates `MySQLRepo` |

### SOLID Deep Dives
1. **SRP**: A module has one actor it serves. Not "does one thing" — one reason to change.
2. **OCP**: Add new behavior by adding code (new class/subclass), not changing existing code. Enables plugin architecture.
3. **LSP — Square-Rectangle Violation**:
   - `Rectangle.setWidth(5)` then `setHeight(10)` → area = 50
   - `Square.setWidth(5)` overrides both → area = 25, not 50 → contract broken
   - Fix: don't inherit Square from Rectangle; use composition or separate hierarchy
4. **ISP**: `IWorker { work(); eat(); }` forces robots to implement `eat()`. Split into `IWorkable` + `IFeedable`.
5. **DIP**: High-level modules define the interface; low-level modules implement it. Spring `@Autowired` = DI in action.

### DRY vs Wrong Abstraction
- **DRY** (Don't Repeat Yourself): eliminate knowledge duplication, not just code duplication
- **Wrong Abstraction**: premature DRY creates wrong abstraction; prefer duplication over wrong abstraction
- Rule: "Duplication is cheaper than the wrong abstraction" — Sandi Metz
- Wait until 3rd repetition before abstracting (Rule of Three)

### Clean Architecture — Dependency Rule
- Layers (outer → inner): Frameworks → Adapters → Use Cases → Entities
- Dependencies only point **inward** — inner layers know nothing of outer layers
- Domain entities have zero framework dependencies
- Use Cases depend on abstract interfaces (ports), not concrete implementations

### DDD — Aggregate Invariants
- **Aggregate**: cluster of domain objects with one root (Aggregate Root)
- All changes go through the root; root enforces invariants
- Example: `Order` (root) + `OrderItems` — never modify `OrderItem` directly
- Aggregates define transaction boundaries; one aggregate per transaction

### Hexagonal Architecture — Ports vs Adapters
- **Ports**: interfaces defined by the domain (input ports = use cases, output ports = repository interfaces)
- **Adapters**: implementations of ports (REST controller = input adapter, JPA repo = output adapter)
- Core domain has no knowledge of HTTP, DB, or messaging
- Enables: swap DB without touching domain logic

### CQRS — Read/Write Model Split
- **Command**: write side — handles commands, updates write model, publishes events
- **Query**: read side — handles queries, uses read-optimized projections
- Benefits: independent scaling, optimized read models, event sourcing friendly
- Trade-off: eventual consistency between write and read models
- Use when: read/write patterns differ significantly, complex reporting needs

---

## Section 3: LLD Quick Reference — 6 Case Studies

### 1. Parking Lot
**Key Entities**: `ParkingLot`, `ParkingFloor`, `ParkingSpot`, `Vehicle`, `Ticket`, `Payment`

**Patterns Used**:
- Singleton: `ParkingLot` (single lot instance)
- Factory: `VehicleFactory.create(type)` → Car/Truck/Motorcycle
- Strategy: `FeeStrategy` → `HourlyFee`, `DailyFee`, `MonthlyFee`
- Observer: `DisplayBoard` listens to spot availability changes

**Key Challenge + Solution**:
- **Thread-safe spot allocation**: `synchronized` on floor-level lock; use `AtomicInteger` for available count; avoid locking entire lot
- **Spot search**: maintain separate lists by type (compact, large, handicapped); O(1) lookup
- **Receipt on exit**: Ticket stores entry time; fee calculated at exit

**Class Sketch**:
```
ParkingLot (Singleton) → ParkingFloor[] → ParkingSpot[]
Ticket {spotId, vehicleId, entryTime}
FeeCalculator (Strategy) → calculate(ticket, exitTime)
```

---

### 2. URL Shortener
**Key Entities**: `URL`, `User`, `AnalyticsRecord`

**Patterns Used**:
- Strategy: ID generation — `CounterStrategy` (Redis INCR) vs `RandomStrategy` (UUID + Base62)
- Facade: `URLShortenerService` hides complexity of encoding, storage, caching
- Decorator: add analytics tracking transparently

**Key Challenge + Solution**:
- **Collision at scale (random)**: Use counter-based approach with Redis INCR; atomically increment global counter, encode to Base62 (62^6 = 56B URLs for 6 chars)
- **Cache hot URLs**: Redis with LRU; 80% reads hit cache
- **301 vs 302**: 301 (permanent) → browser caches, reduces server load; 302 (temporary) → server tracks every redirect for analytics

**Base62 Encoding**:
```
chars = [0-9, a-z, A-Z]  // 62 characters
encode(id): repeatedly divide by 62, map remainders to chars
decode(str): sum(char_index × 62^position)
```

---

### 3. Rate Limiter
**Key Entities**: `RateLimiter`, `Rule`, `RequestContext`

**Patterns Used**:
- Strategy: algorithm selection — `TokenBucket`, `LeakyBucket`, `FixedWindow`, `SlidingWindowLog`, `SlidingWindowCounter`
- Decorator: wrap HTTP filters/handlers with rate limiting

**Algorithms Comparison**:
| Algorithm | Pros | Cons |
|---|---|---|
| Token Bucket | Handles bursts | Complex distributed impl |
| Fixed Window | Simple | Boundary burst problem (2x at edges) |
| Sliding Window Log | Accurate | High memory |
| Sliding Window Counter | Memory efficient | Approximate |

**Key Challenge + Solution**:
- **Distributed atomicity**: single Redis Lua script for check-and-decrement (atomic, no race condition)
  ```lua
  local count = redis.call('INCR', key)
  if count == 1 then redis.call('EXPIRE', key, window) end
  return count <= limit
  ```
- **Placement**: API Gateway (coarse-grained) + service-level (fine-grained)

---

### 4. BookMyShow (Seat Booking)
**Key Entities**: `Show`, `Screen`, `Seat`, `Booking`, `Payment`, `Notification`

**Patterns Used**:
- Optimistic Locking: `@Version` on `Seat` entity — prevents double booking without pessimistic locks
- Observer: `BookingService` notifies `EmailService`, `SMSService` on booking confirmation
- Strategy: `PaymentStrategy` → `CreditCard`, `UPI`, `Wallet`
- Factory: `BookingFactory` creates booking with correct pricing

**Key Challenge + Solution**:
- **Concurrent seat booking**: `@Version` field on Seat; if two users book same seat, second gets `OptimisticLockException` → retry or show error
- **Hold seats temporarily**: Redis SETNX with TTL (10 min hold); seat reserved, payment pending; expire releases it
- **Thundering herd on popular show**: queue requests; release in batches; show "in queue" to user

**Seat State Machine**: `AVAILABLE → HOLD → BOOKED | AVAILABLE (on timeout)`

---

### 5. Splitwise
**Key Entities**: `User`, `Group`, `Expense`, `Split`, `Balance`, `Settlement`

**Patterns Used**:
- Strategy: split types — `EqualSplit`, `ExactSplit`, `PercentSplit`, `ShareSplit`
- Template Method: `AbstractSplit.validate()` with `calculateAmounts()` abstract
- Min-heap: balance simplification using net balance per user

**Key Challenge + Solution**:
- **O(N) settlement minimization**: compute net balance for each user; two-pointer or heap approach
  - Users with +balance (owed money) → max-heap
  - Users with -balance (owe money) → min-heap
  - Match creditor with debtor; one transaction settles both; O(N log N)
- **Currency**: store all amounts in minor units (paise/cents) to avoid float precision issues
- **Circular debt**: A owes B, B owes C, C owes A → simplify to direct settlements

---

### 6. Elevator System
**Key Entities**: `ElevatorController`, `Elevator`, `Request`, `Direction`, `Floor`

**Patterns Used**:
- State FSM: `Elevator` states — `IDLE`, `MOVING_UP`, `MOVING_DOWN`, `DOOR_OPEN`, `MAINTENANCE`
- Strategy: scheduling — `LOOK Algorithm` (scans in one direction, reverses at end) vs `FCFS`
- Observer: `Elevator` notifies `DisplayPanel` on floor change, door events

**Key Challenge + Solution**:
- **Multi-elevator coordination**: `ElevatorController` receives requests, assigns to optimal elevator (nearest + same direction) using cost function: `|currentFloor - requestFloor| + directionPenalty`
- **LOOK Algorithm**: serve all requests in current direction before reversing; prevents starvation
- **Emergency stop**: `MAINTENANCE` state blocks all normal requests; priority queue for emergency

**Request Types**: `InternalRequest` (button inside cab) vs `ExternalRequest` (hall button with direction)

---

## Section 4: System Design — Top 15 Questions

### 1. RADIO Framework (Interview Structure)
- **R**equirements: functional + non-functional (scale, latency, availability)
- **A**PI Design: endpoints, request/response, protocols
- **D**ata Model: schema, storage type (SQL/NoSQL), partitioning key
- **I**nfrastructure: components (LB, cache, DB, queue, CDN)
- **O**ptimizations: bottlenecks, trade-offs, failure scenarios

### 2. Vertical vs Horizontal Scaling
| | Vertical (Scale Up) | Horizontal (Scale Out) |
|---|---|---|
| How | Bigger machine | More machines |
| Limit | Hardware ceiling | Theoretically unlimited |
| Cost | Expensive, diminishing returns | Commodity hardware |
| Complexity | Simple | Needs LB, distributed coordination |
| Use | DB primary (short term) | Stateless services, read replicas |

### 3. L4 vs L7 Load Balancer
| | L4 (Transport) | L7 (Application) |
|---|---|---|
| Layer | TCP/UDP | HTTP/HTTPS |
| Routing | IP + port | URL, headers, cookies |
| Performance | Faster (less inspection) | Smarter routing |
| SSL termination | No | Yes |
| Examples | AWS NLB, HAProxy (TCP mode) | AWS ALB, NGINX, Envoy |
- L7 enables: A/B testing, canary deployment, JWT validation, rate limiting by URL

### 4. CDN — Pull vs Push
- **Pull**: CDN fetches from origin on first miss, caches with TTL
  - Pros: simple, auto-cache popular content; Cons: first request slow (cache miss)
  - Use for: dynamic content, unpredictable access patterns
- **Push**: pre-upload content to CDN before requests arrive
  - Pros: no origin load, fast first access; Cons: storage cost, must invalidate manually
  - Use for: static assets (images, videos, JS/CSS), known popular content

### 5. Consistent Hashing — Virtual Nodes
- Problem: adding/removing servers causes mass key remapping (O(K/N) keys move ideally)
- Solution: each server gets V virtual nodes on the ring; better distribution
- **V virtual nodes per server**: typically 100-200; improves load balance
- Key moves only to adjacent server when a node is added/removed
- **Hotspot mitigation**: virtual nodes spread load; weighted virtual nodes for heterogeneous servers
- Used by: Cassandra, DynamoDB, Riak

### 6. Back-of-Envelope Estimation — Key Numbers
```
Power of 2:
  2^10 = 1K,  2^20 = 1M,  2^30 = 1B,  2^40 = 1T

Character sizes:
  ASCII char = 1 byte, Unicode = 2-4 bytes
  UUID = 36 chars = 36 bytes, or 16 bytes binary

Network:
  1Gbps NIC = 125 MB/s throughput
  99th percentile latency budget: 100ms for user-facing APIs

QPS (Queries Per Second):
  1M requests/day = 12 req/s
  10M requests/day = 116 req/s
  100M requests/day = ~1,160 req/s
  1B requests/day = ~11,600 req/s

Storage:
  1 photo (compressed) ≈ 200KB
  1 tweet ≈ 280 chars ≈ 300 bytes with metadata
  1 video (1 min, 720p) ≈ 50MB

Time:
  1 year ≈ 3.15 × 10^7 seconds ≈ 31.5M seconds
  1 day = 86,400 seconds ≈ 100K seconds
```

### 7. Fanout-on-Write vs Fanout-on-Read (News Feed)
| | Fanout-on-Write (Push) | Fanout-on-Read (Pull) |
|---|---|---|
| When | At post creation | At feed request |
| Storage | Pre-computed feeds in Redis | Central post table |
| Read latency | O(1) — pre-built | O(N) — merge N feeds |
| Write latency | O(N) — push to N followers | O(1) |
| Celebrity problem | Fan-out to 100M followers → slow | Pull from celebrity; rest pre-built |
- **Hybrid**: fanout-on-write for normal users; fanout-on-read for celebrities (>1M followers)

### 8. Distributed ID — Snowflake (41+10+12 bits)
```
64-bit ID breakdown:
  1 bit  : sign (always 0)
  41 bits: timestamp (ms since epoch) → ~69 years
  10 bits: machine/datacenter ID → 1024 machines
  12 bits: sequence number → 4096 IDs/ms/machine

Peak: 4096 × 1000 = 4.1M IDs/sec per machine
```
- Time-sortable: newer IDs are always larger
- Alternatives: UUID (not sortable, 128-bit), Redis INCR (single point), ULIDé (sortable UUID)

### 9. News Feed Design (Twitter/Instagram)
- **Write path**: Post → Fanout service → push to follower feed caches (Redis sorted set by timestamp)
- **Read path**: Fetch pre-computed feed from Redis; merge with real-time posts
- **Storage**: Posts in Cassandra (partitioned by user_id); Media in S3 + CDN
- **Scale**: separate services for timeline, social graph, notification, search

### 10. Notification System
- **Channels**: Push (APNs/FCM), Email (SendGrid/SES), SMS (Twilio), In-app
- **Architecture**: Notification Service → Message Queue (Kafka per channel) → channel workers
- **Reliability**: store notification in DB; mark sent/failed; retry with backoff; idempotency key
- **Rate limiting**: prevent spam; per-user limits per channel

### 11. Rate Limiter Placement
- **API Gateway**: first line of defense; coarse-grained by API key/IP
- **Reverse Proxy (NGINX)**: `limit_req_zone`; fast, before app code
- **Service level**: fine-grained; user-tier limits; business logic aware
- **In-app middleware**: most flexible but adds latency; use for complex rules
- Response: HTTP 429 Too Many Requests + `Retry-After` header

### 12. URL Shortener — 301 vs 302
- **301 Permanent Redirect**: browser caches; future requests go direct to long URL; server never sees them → fewer server hits, analytics blind
- **302 Temporary Redirect**: browser always asks server; server can track every click → analytics complete, more server load
- **Decision**: analytics → 302; reduce load → 301

### 13. Distributed Cache Stampede (Thundering Herd)
- **Problem**: cache expires; N requests all miss cache simultaneously; all hit DB
- **Solutions**:
  - **Mutex/Lock**: first request acquires lock, fetches from DB, populates cache; others wait
  - **Probabilistic early expiration**: random chance to refresh before expiry
  - **Background refresh**: async refresh before expiry; stale-while-revalidate
  - **Jitter on TTL**: add random TTL variance to prevent mass simultaneous expiry

### 14. CAP in Real Systems
```
CAP Theorem: Distributed systems can guarantee only 2 of 3:
  C = Consistency (all nodes see same data)
  A = Availability (every request gets response)
  P = Partition Tolerance (works despite network partition)
  
Since P is unavoidable in distributed systems, choose C or A:
```
| System | Choice | Trade-off |
|---|---|---|
| Zookeeper | CP | May be unavailable during partition |
| Cassandra | AP | Tunable consistency; may return stale data |
| DynamoDB | AP (default) | Eventually consistent reads |
| HBase | CP | Availability sacrificed |
| MySQL (single) | CA | Not partition tolerant |

- **PACELC**: extends CAP — even without partition: choose Latency vs Consistency

### 15. Microservices — Strangler Fig Pattern
- **Problem**: migrate monolith to microservices without big-bang rewrite
- **Approach**: new requests → new microservice; old functionality stays in monolith; gradually strangle
- **Steps**: 1) Intercept all traffic at facade/proxy, 2) Implement feature in new service, 3) Route new service, 4) Remove from monolith
- **Other migration patterns**: Anti-Corruption Layer (ACL) between old/new; Branch by Abstraction; Feature Toggles

---

## Section 5: Latency Numbers (Must Memorize)

| Operation | Latency | Notes |
|---|---|---|
| L1 cache hit | 1 ns | |
| L2 cache hit | 4 ns | |
| L3 cache hit | 10-40 ns | |
| Mutex lock/unlock | 25 ns | |
| Main memory (RAM) access | 100 ns | L1 × 100 |
| Context switch | 1-10 µs | OS thread switch |
| SSD random read | 100-150 µs | |
| SSD sequential read | 1 GB/s | |
| HDD disk seek | 10 ms | L1 × 10,000,000 |
| HDD sequential read | 100 MB/s | |
| Network: same datacenter | 500 µs | |
| Network: same region | 1-5 ms | |
| Network: cross-region (US-EU) | 80-150 ms | |
| Network: round the world | ~300 ms | |
| Redis GET | 0.1-1 ms | In same datacenter |
| DB query (indexed) | 1-10 ms | |
| DB query (full scan) | 100ms-10s | Depends on table size |

**Key Ratios to Remember**:
- RAM 100x faster than SSD
- SSD 100x faster than HDD seek
- Same-DC network 1000x faster than cross-region
- L1 cache 100x faster than RAM

---

## Section 6: Capacity Estimation Cheat Sheet

### Storage Rules of Thumb
```
1M users × 1KB per record  = 1 GB
1M users × 1MB per record  = 1 TB
1B users × 1KB per record  = 1 TB
1B users × 1MB per record  = 1 PB

Twitter: 500M tweets/day × 300 bytes = 150 GB/day ≈ 55 TB/year
Images: 1M uploads/day × 200KB = 200 GB/day
Video:  1M uploads/day × 50MB  = 50 TB/day
```

### Throughput Rules of Thumb
```
1M  requests/day = ~12 req/s
10M requests/day = ~116 req/s
100M requests/day = ~1,160 req/s  (~1.2K req/s)
1B  requests/day = ~11,600 req/s  (~12K req/s)

Single server (simple request): ~1,000-5,000 req/s
Single DB (read, indexed): ~1,000-2,000 QPS
Redis: ~100,000-1,000,000 ops/sec
Kafka: ~1M msgs/sec per broker
```

### Scaling Strategies by Pattern
- **Read-heavy** (10:1 read/write): Add Redis cache + read replicas; target 99% cache hit rate
- **Write-heavy** (1:10 read/write): Horizontal partitioning (sharding); async writes; message queue buffer
- **Both read and write heavy**: CQRS; separate read/write stores; event sourcing
- **Hotspot key**: consistent hashing with virtual nodes; application-level sharding

### 80/20 Rule for Caching
- 20% of content generates 80% of traffic
- Cache top 20% → handle 80% of read traffic
- Memory needed: 20% of total dataset for full benefit
- Example: 10TB dataset → 2TB cache handles 80% of reads

### Replication Lag Estimation
- Master → replica sync: typically 1-100ms in same datacenter
- Async replication: seconds to minutes lag possible under load
- Read-your-writes consistency: route user's reads to master for 1 second after write

---

## Section 7: 100 Mock Interview Questions with 1-liner Answers

### Core Java (Q1-Q15)
**Q1.** What is the difference between `==` and `.equals()` in Java? → `==` compares references; `.equals()` compares content (if overridden).
**Q2.** Explain Java Memory Model — heap vs stack. → Stack: method frames, local vars (thread-local); Heap: all objects (shared, GC-managed).
**Q3.** What is the difference between `HashMap` and `ConcurrentHashMap`? → HashMap not thread-safe; ConcurrentHashMap uses segment/bucket-level locking, allows concurrent reads.
**Q4.** How does `String` immutability work in Java? → String objects are final; any "modification" creates new String; enables string pool and thread safety.
**Q5.** What is the difference between `Comparable` and `Comparator`? → Comparable defines natural ordering (in the class); Comparator defines external/custom ordering (separate class).
**Q6.** Explain Java's `volatile` keyword. → Ensures visibility of changes across threads; prevents caching in CPU registers; does NOT guarantee atomicity.
**Q7.** What is the difference between `synchronized` method and `synchronized` block? → Method locks entire object/class; block locks specified object — finer granularity, better performance.
**Q8.** How does `HashMap` handle collisions? → Uses chaining (linked list at bucket); Java 8+ converts to balanced tree (red-black) when chain length ≥ 8.
**Q9.** What is the difference between `final`, `finally`, and `finalize()`? → `final`: immutable var/method/class; `finally`: always-runs cleanup block; `finalize()`: deprecated GC hook.
**Q10.** Explain Java Generics type erasure. → Generic type info removed at compile time; `List<String>` becomes `List` at runtime; enables backward compatibility.
**Q11.** What is the difference between `ArrayList` and `LinkedList`? → ArrayList: O(1) random access, O(n) insert/delete middle; LinkedList: O(1) insert/delete at ends, O(n) random access.
**Q12.** How does `ThreadLocal` work? → Each thread gets its own copy of the variable; backed by `Thread.threadLocals` map; prevent leaks with `remove()`.
**Q13.** What is the Java Memory Model's happens-before relationship? → Guarantees action A's effects visible to B; established by: synchronized, volatile, thread start/join, lock release/acquire.
**Q14.** Explain `ForkJoinPool` and work-stealing. → Thread pool where idle threads steal tasks from busy threads' queues; optimized for recursive divide-and-conquer tasks.
**Q15.** What is the difference between `Checked` and `Unchecked` exceptions? → Checked: must be declared/caught (IOException); Unchecked: RuntimeException subclasses, optional handling.

### Spring/JPA (Q16-Q30)
**Q16.** What is Spring IoC container? → Inversion of Control: container creates and manages bean lifecycle/dependencies; reduces coupling via DI.
**Q17.** Explain `@Transactional` propagation types. → REQUIRED (default, join/create), REQUIRES_NEW (new tx), SUPPORTS (join if exists), MANDATORY (must exist).
**Q18.** What is N+1 problem in JPA? → 1 query for parent + N queries for each child; fix with `JOIN FETCH` or `@EntityGraph`.
**Q19.** Difference between `@Component`, `@Service`, `@Repository`, `@Controller`? → All create Spring beans; semantic specialization: Repository adds exception translation; Controller enables MVC mapping.
**Q20.** How does Spring `@Cacheable` work? → Proxy intercepts method; checks cache for key; returns cached value or calls method and caches result.
**Q21.** Explain JPA first-level vs second-level cache. → L1: EntityManager-scoped (per transaction); L2: SessionFactory-scoped (shared across transactions, explicit config).
**Q22.** What is `@Version` in JPA? → Optimistic locking: version field incremented on each update; `OptimisticLockException` if concurrent modification detected.
**Q23.** Explain Spring Bean scopes. → Singleton (default), Prototype (new per request), Request (HTTP request-scoped), Session (HTTP session-scoped).
**Q24.** How does `@Async` work in Spring? → Executes method in separate thread pool; requires `@EnableAsync`; returns `Future`/`CompletableFuture`; self-invocation bypasses proxy.
**Q25.** What is the difference between `EAGER` and `LAZY` loading in JPA? → EAGER: load relation immediately with parent query; LAZY: load on first access (default for collections).
**Q26.** Explain Spring Security filter chain. → Chain of `OncePerRequestFilter`; each filter processes request; key filters: UsernamePasswordAuthentication, JwtAuthentication, ExceptionTranslation.
**Q27.** What is the difference between `@Repository` and `JpaRepository`? → `@Repository` is a stereotype annotation; `JpaRepository` extends `CrudRepository` providing CRUD + pagination out of box.
**Q28.** How does Spring Boot auto-configuration work? → `@EnableAutoConfiguration` scans `META-INF/spring.factories`; conditionally applies configurations based on classpath and properties.
**Q29.** Explain `@Transactional` and self-invocation problem. → Calling `@Transactional` method from same class bypasses Spring proxy; fix: inject self, or use `AopContext.currentProxy()`.
**Q30.** What is JPQL vs Criteria API? → JPQL: string-based, entity-centric HQL-like query; Criteria API: type-safe programmatic query builder, better for dynamic queries.

### REST/Microservices (Q31-Q45)
**Q31.** What are the REST constraints? → Client-server, stateless, cacheable, uniform interface, layered system, code-on-demand (optional).
**Q32.** Difference between PUT and PATCH? → PUT replaces entire resource (idempotent); PATCH partially updates resource (should be idempotent by design).
**Q33.** What is idempotency? Why does it matter? → Same request produces same result regardless of repetitions; critical for retries (POST not idempotent by default).
**Q34.** How do you handle distributed transactions in microservices? → Saga pattern (choreography or orchestration); eventual consistency; avoid 2PC in microservices.
**Q35.** What is the Circuit Breaker pattern? → If downstream fails repeatedly, circuit opens; requests fail fast; half-open state to probe recovery; prevents cascade failure.
**Q36.** Explain API Gateway responsibilities. → Routing, auth/authZ, rate limiting, SSL termination, request/response transformation, load balancing, observability.
**Q37.** What is service mesh? → Infrastructure layer handling service-to-service communication: traffic management, mTLS, observability; Istio, Linkerd.
**Q38.** Difference between synchronous and asynchronous microservice communication? → Sync (REST/gRPC): tight coupling, real-time; Async (Kafka/RabbitMQ): loose coupling, better resilience, eventual consistency.
**Q39.** What is the Outbox pattern? → Write to local DB + outbox table atomically; separate process publishes outbox events; guarantees exactly-once event publishing.
**Q40.** How do you implement distributed tracing? → Propagate trace ID (W3C TraceContext) across service calls; use OpenTelemetry + Jaeger/Zipkin; correlate logs by trace ID.
**Q41.** What is HATEOAS? → Hypermedia As Engine of Application State; responses include links to possible next actions; enables API discoverability.
**Q42.** How do you version APIs? → URI versioning (`/v1/`), header versioning (`Accept: application/vnd.v2+json`), query param (`?version=2`); URI most visible.
**Q43.** What is the Bulkhead pattern? → Isolate components into pools; failure in one pool doesn't exhaust resources for others; thread pool per downstream service.
**Q44.** Explain eventual consistency and how to handle it in microservices. → System reaches consistency after some delay; handle with idempotent consumers, compensating transactions, and user-facing "processing" state.
**Q45.** What is gRPC? When prefer it over REST? → Google RPC; uses Protocol Buffers (binary, compact); HTTP/2; better for inter-service (internal) high-throughput communication.

### Kafka/Redis/Security (Q46-Q60)
**Q46.** What is Kafka's consumer group? → Group of consumers sharing partition load; each partition consumed by exactly one consumer in a group; enables parallel processing.
**Q47.** How does Kafka ensure message ordering? → Ordering guaranteed within a partition only; use same partition key for related messages needing order.
**Q48.** Difference between Kafka `at-least-once`, `at-most-once`, `exactly-once`? → At-most-once: may lose; At-least-once: may duplicate; Exactly-once: idempotent producer + transactional API.
**Q49.** What is Redis data eviction? Key policies? → LRU (evict least recently used), LFU (least frequently used), TTL-based; configure `maxmemory-policy`.
**Q50.** How do you implement distributed lock with Redis? → `SET key value NX PX timeout` (atomic); Redlock algorithm for multi-master; release only own lock (Lua script check-and-delete).
**Q51.** What is Redis Pub/Sub? Limitations? → Publish-subscribe messaging; not persistent (lost if no subscriber); no consumer groups; use Kafka for durable messaging.
**Q52.** What is JWT? How is it validated? → JSON Web Token: header.payload.signature; validated by verifying HMAC/RSA signature; stateless authentication; check `exp` claim.
**Q53.** Explain OAuth2 authorization code flow. → User → Auth server → authorization code → client exchanges for access token; token used for API calls; never expose to browser.
**Q54.** What is the difference between authentication and authorization? → AuthN: verify who you are (login); AuthZ: verify what you can do (permissions/roles).
**Q55.** How do you prevent SQL injection? → Parameterized queries/prepared statements; ORM (JPA/Hibernate); input validation; principle of least privilege on DB user.
**Q56.** What is CORS? How to fix it? → Cross-Origin Resource Sharing; browser blocks cross-origin requests unless server sends `Access-Control-Allow-Origin` header.
**Q57.** Explain Kafka consumer lag. How to monitor? → Difference between latest offset and consumer committed offset; use `kafka-consumer-groups.sh`; alert on sustained lag growth.
**Q58.** What is Redis pipeline? When to use? → Send multiple commands without waiting for responses; reduces RTT; use for batch operations; not atomic (use transaction for atomicity).
**Q59.** How does Spring Security CSRF protection work? → Synchronizer token pattern; server generates token; client must send it in form POST; stateless APIs typically disable CSRF.
**Q60.** What is Kafka log compaction? → Retain only latest record per key; useful for changelog/state topics; tombstone (null value) deletes key.

### SQL/DB (Q61-Q75)
**Q61.** Explain ACID properties. → Atomicity (all-or-nothing), Consistency (valid state transitions), Isolation (concurrent tx appear serial), Durability (committed data persists).
**Q62.** What is an index? Types? → Data structure for fast lookup; B-Tree (default, range queries), Hash (equality), Full-text (text search), Composite (multi-column).
**Q63.** Explain different isolation levels. → READ UNCOMMITTED (dirty reads), READ COMMITTED (no dirty, phantom ok), REPEATABLE READ (no dirty/non-repeatable), SERIALIZABLE (all anomalies prevented).
**Q64.** What is the difference between clustered and non-clustered index? → Clustered: table data physically ordered by index (one per table, InnoDB PK default); Non-clustered: separate structure with pointer to row.
**Q65.** How do you optimize a slow query? → EXPLAIN/EXPLAIN ANALYZE; add indexes; avoid SELECT *; avoid functions on indexed columns; optimize JOINs order; pagination.
**Q66.** What is database sharding? → Horizontal partitioning across multiple DB instances; each shard has subset of data; routes by shard key; enables horizontal scale.
**Q67.** Explain CAP theorem for databases. → Cannot have Consistency + Availability + Partition Tolerance simultaneously; distributed DBs choose CA or AP; see Section 4.14.
**Q68.** What is the N-Queens sharding problem? → Hotspot when shard key creates uneven distribution; user_id better than country; use consistent hashing to avoid resharding pain.
**Q69.** Difference between DELETE, TRUNCATE, DROP? → DELETE: row-by-row, logged, WHERE supported, rollbackable; TRUNCATE: fast, not row-logged, no WHERE, DDL; DROP: removes table entirely.
**Q70.** What is a covering index? → Index contains all columns needed by query; query satisfied from index alone without accessing table rows; fastest read.
**Q71.** Explain window functions. → Perform calculations across rows related to current row without collapsing rows; `ROW_NUMBER()`, `RANK()`, `LAG()`, `LEAD()`, `SUM() OVER(PARTITION BY...)`.
**Q72.** What is eventual consistency? How does DynamoDB achieve it? → System converges to consistent state; DynamoDB uses synchronous writes to 2 of 3 replicas; read-any-replica may be stale.
**Q73.** How does PostgreSQL MVCC work? → Multi-Version Concurrency Control; each row has `xmin`/`xmax` transaction IDs; readers see snapshot at tx start; no read locks needed.
**Q74.** When to use NoSQL vs SQL? → NoSQL: schema flexibility, horizontal scale, simple access patterns; SQL: complex queries, transactions, relational data, reporting.
**Q75.** What is a database deadlock? How to prevent? → Two transactions wait for each other's locks; prevent by: consistent lock ordering, short transactions, retry on deadlock detection.

### System Design/LLD (Q76-Q90)
**Q76.** How would you design a URL shortener? → Hash/Base62 encode unique ID from Redis INCR; store mapping in DB + cache hot URLs in Redis; 302 for analytics.
**Q77.** How does consistent hashing work? → Ring of hash space 0-2^32; nodes and keys placed on ring; key goes to first node clockwise; add/remove moves minimal keys.
**Q78.** What is the difference between load balancer and reverse proxy? → LB distributes traffic across multiple servers; reverse proxy sits in front, can do LB + SSL + caching + auth.
**Q79.** How would you design a rate limiter? → Token bucket in Redis; Lua script for atomic check-and-decrement; return 429 with Retry-After on limit exceeded.
**Q80.** What is CDN? How does cache invalidation work? → Content Delivery Network; edge servers cache content; invalidation: TTL expiry, API-based purge, cache version in URL.
**Q81.** How would you design a notification system? → User service → Notification service → Kafka topics per channel → workers → APNs/FCM/SendGrid/Twilio.
**Q82.** What is the difference between synchronous and event-driven architecture? → Sync: caller waits, tight coupling; Event-driven: async, loose coupling, scalable, eventual consistency.
**Q83.** How would you design a distributed cache? → Redis Cluster: hash slots sharded across nodes; replication for HA; LRU eviction; circuit breaker for fallback to DB.
**Q84.** Explain Snowflake ID generation. → 64-bit: 1(sign) + 41(timestamp ms) + 10(machine ID) + 12(sequence); time-sortable; 4M IDs/sec/machine.
**Q85.** How do you handle database migrations in microservices? → Flyway/Liquibase; backward-compatible migrations; expand-contract pattern; never break existing columns immediately.
**Q86.** What is the Saga pattern? Choreography vs Orchestration? → Choreography: services react to events (no coordinator); Orchestration: central coordinator directs steps; orchestration easier to debug.
**Q87.** How would you design a search autocomplete? → Trie in memory (prefix lookup); top-K suggestions per prefix; Redis sorted set (score = frequency); precompute popular queries.
**Q88.** What is blue-green deployment? → Run two identical environments; switch LB traffic from blue to green; instant rollback by switching back; requires 2x infrastructure.
**Q89.** How do you achieve idempotency in APIs? → Client sends idempotency key (UUID) in header; server stores key → response mapping; duplicate request returns stored response.
**Q90.** What is the difference between orchestration and choreography in microservices? → Orchestration: central brain (saga orchestrator) knows all steps; Choreography: each service knows its role, reacts to events — more decoupled.

### Behavioral/Architecture (Q91-Q100)
**Q91.** Tell me about a time you improved system performance. → Structure: situation → bottleneck identified (profiling) → solution implemented → measurable improvement.
**Q92.** How do you approach debugging a production issue? → Observe (logs/metrics/traces) → Hypothesize → Isolate (narrow scope) → Fix → Verify → Post-mortem.
**Q93.** How do you decide between building vs buying a solution? → Build: core differentiator, specific requirements; Buy: commodity, faster time-to-market, total cost of ownership.
**Q94.** How do you handle disagreements in technical decisions? → Present data/trade-offs; understand their perspective; escalate if needed; accept team decision and commit.
**Q95.** Describe your approach to code review. → Check correctness, edge cases, performance, security, readability, test coverage; be respectful and constructive; suggest don't dictate.
**Q96.** How do you ensure high availability in your systems? → Redundancy (no SPOF), health checks, circuit breakers, graceful degradation, chaos engineering, runbooks.
**Q97.** What is technical debt? How do you manage it? → Shortcuts taken for speed that cost more later; manage with: debt register, allocate % of sprint to debt, track in metrics.
**Q98.** How do you design for failure? → Assume everything fails; retry with exponential backoff; circuit breakers; fallbacks; bulkheads; chaos monkey testing.
**Q99.** What metrics do you monitor for a backend service? → Latency (p50/p95/p99), error rate, throughput (req/s), saturation (CPU/memory/connections), dependency health.
**Q100.** How do you stay current with technology? → Read engineering blogs (Netflix, Uber, Airbnb tech); contribute to open source; build side projects; attend conferences; peer learning.

---

## Section 8: Interview Day Checklist

### Before the Interview (T-24 hours)
- [ ] Review company's engineering blog — know their tech stack and scale challenges
- [ ] Skim Sections 5 & 6 (latency numbers + capacity estimation)
- [ ] Review your top 3 past projects — STAR format ready
- [ ] Re-read LLD case study for your strongest domain
- [ ] Have pen + paper ready for system design diagramming
- [ ] Set up IDE with Java 17+ — practice coding without autocomplete for 30 min
- [ ] Sleep 7+ hours — cognitive performance degradation is real
- [ ] Prepare your "tell me about yourself" — 90 seconds, focused on impact

### During System Design (Step-by-Step)
1. **Clarify requirements** (3-5 min): Ask about scale, users, features, constraints; NEVER jump to solution
2. **Estimate scale** (2 min): DAU, QPS, storage — back-of-envelope; state assumptions clearly
3. **Define API** (3-5 min): endpoints, request/response, protocols
4. **High-level design** (10 min): draw components — clients, LB, services, cache, DB, CDN
5. **Data model** (5 min): key tables/schemas, partition strategy, storage choice
6. **Deep dive** (10-15 min): discuss bottlenecks; interviewer usually guides here
7. **Trade-offs** (5 min): acknowledge what you sacrificed; no design is perfect

**System Design Mantras**:
- Start simple, add complexity on demand
- State trade-offs explicitly — interviewers love "we chose X because, but it costs Y"
- Ask clarifying questions before whiteboarding
- Drive the conversation — don't wait for prompts
- Numbers matter: "supports 1M DAU at 99.9% uptime" beats "highly scalable"

### During Coding (Best Practices)
- Think aloud before coding — explain approach
- Write function signature + brief comment first
- Start with happy path; add edge cases after
- Use meaningful variable names — readability > brevity in interview
- Test your code with the example from the problem + edge case
- If stuck: explain your thinking, reduce to simpler version, ask for hints
- Mention time/space complexity before being asked
- Code style: consistent indentation, no magic numbers, handle null inputs

### Questions to Ask the Interviewer (Pick 2-3)
1. "What does the engineering team's on-call process look like, and how do you handle incidents?"
2. "What's the biggest technical challenge the team is working on right now?"
3. "How does the team approach technical debt and refactoring?"
4. "What does a successful first 90 days look like for this role?"
5. "How do you measure engineering productivity and code quality here?"

### Red Flags to Avoid
- **Don't** start coding without clarifying requirements
- **Don't** give one-word answers in system design — always explain reasoning
- **Don't** pretend to know something you don't — say "I don't know, but here's how I'd approach it"
- **Don't** ignore non-functional requirements (availability, consistency, latency)
- **Don't** optimize prematurely in code — write correct first, then optimize if asked
- **Don't** dismiss the interviewer's suggestions — engage, consider, adapt
- **Don't** forget to handle edge cases: null inputs, empty collections, integer overflow
- **Don't** use overly complex solutions when simple ones work — KISS principle

---

*End of Chapter 27 — Volume 6: Interview Revision Pack*
*Review time: 90-120 minutes for full chapter | Quick scan: 30 minutes for Sections 5, 6, 7*


