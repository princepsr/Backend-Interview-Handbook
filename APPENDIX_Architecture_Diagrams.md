# Appendix A: Architecture Diagrams

*Cross-referenced with handbook chapters. Best viewed in monospace font.*

---

## Diagram 1: JVM Memory Architecture
*(Supplements Chapter 5 — JVM Internals)*

The JVM divides memory into several runtime data areas. The heap holds all object instances and is managed by the garbage collector. The method area (Metaspace in Java 8+) holds class metadata. Each thread gets its own stack, PC register, and native method stack. The G1 GC view on the right shows how the heap is divided into equal-sized regions that can be dynamically assigned roles.

```
+--------------------------------------------------+     +----------------------------------+
|              JVM RUNTIME DATA AREAS              |     |        G1 GC REGION VIEW          |
+--------------------------------------------------+     |  (each square = 1-32 MB region)  |
|                                                  |     +----------------------------------+
|  +--------------------------------------------+ |     |                                  |
|  |              HEAP  (~256MB default)         | |     |  +---+---+---+---+---+---+---+  |
|  |                                            | |     |  | E | O | S | E | H | H | O |  |
|  |  +--------------------------------------+  | |     |  +---+---+---+---+---+---+---+  |
|  |  |      YOUNG GENERATION (~85MB)        |  | |     |  | S | E | O | O | E | S | E |  |
|  |  |                                      |  | |     |  +---+---+---+---+---+---+---+  |
|  |  |  +---------+ +-------+ +-------+    |  | |     |  | O | E | E | S | O | E | O |  |
|  |  |  |  EDEN   | |  S0   | |  S1   |    |  | |     |  +---+---+---+---+---+---+---+  |
|  |  |  | (~68MB) | |(~8MB) | |(~8MB) |    |  | |     |  | E | H | O | E | S | O | E |  |
|  |  |  +---------+ +-------+ +-------+    |  | |     |  +---+---+---+---+---+---+---+  |
|  |  |       |           |                  |  | |     |                                  |
|  |  +-------|-----------|------------------+  | |     |  LEGEND:                         |
|  |          |   Minor GC promotions            | |     |  E = Eden region                 |
|  |          v           v                      | |     |  S = Survivor region             |
|  |  +--------------------------------------+  | |     |  O = Old region                  |
|  |  |       OLD GENERATION (~170MB)        |  | |     |  H = Humongous region            |
|  |  |    (long-lived objects survive here) |  | |     |  (large objects > 50% region)    |
|  |  +--------------------------------------+  | |     +----------------------------------+
|  +--------------------------------------------+ |
|                                                  |     OBJECT PROMOTION PATH:
|  +--------------------------------------------+ |
|  |   METASPACE (off-heap, ~unlimited default) | |     Eden ----> Survivor ----> Old Gen
|  |   Class metadata, method bytecode,        | |       |   Minor GC    |   after N GCs
|  |   runtime constant pool, field/method info| |       +---------------+
|  +--------------------------------------------+ |          (age threshold, default 15)
|                                                  |
|  Per-Thread Areas (one set per thread):          |
|  +-------------+ +------------+ +-----------+   |
|  |   JVM STACK | | PC REGISTER| |  NATIVE   |   |
|  |             | |            | |  METHOD   |   |
|  | +frame----+ | | current    | |  STACK    |   |
|  | |local vars| | | instr ptr  | |           |   |
|  | |operand   | | |            | | (for JNI  |   |
|  | |stack     | | |            | |  methods) |   |
|  | |frame data| | |            | |           |   |
|  | +---------+ | |            | |           |   |
|  +-------------+ +------------+ +-----------+   |
+--------------------------------------------------+
```

---

## Diagram 2: Spring Bean Lifecycle
*(Supplements Chapter 7 — Spring Core & Boot)*

Spring manages beans through a well-defined lifecycle. Understanding each phase is critical for initializing resources, injecting dependencies, and cleaning up correctly. Custom hook points let you execute logic at specific phases without modifying core Spring code.

```
                    SPRING BEAN LIFECYCLE
    ================================================

         +--------------------------------------+
         |  Spring ApplicationContext starts    |
         +--------------------------------------+
                          |
                          v
    +----------------------------------------------------+
    |  1. INSTANTIATION                                  |
    |     Bean class instantiated via constructor        |
    |     new MyBean() or factory method                 |
    +----------------------------------------------------+
                          |
                          v
    +----------------------------------------------------+
    |  2. POPULATE PROPERTIES                            |<-- custom hook
    |     @Autowired, @Value, @Resource injected         |    (use constructor
    |     Setter injection applied                       |     injection instead)
    +----------------------------------------------------+
                          |
                          v
    +----------------------------------------------------+
    |  3. BeanNameAware.setBeanName(String name)         |<-- Aware interfaces
    |     Bean receives its own bean name                |    (optional)
    +----------------------------------------------------+
                          |
                          v
    +----------------------------------------------------+
    |  4. BeanFactoryAware.setBeanFactory(factory)       |
    |     Bean receives reference to BeanFactory         |
    +----------------------------------------------------+
                          |
                          v
    +----------------------------------------------------+
    |  5. ApplicationContextAware                        |
    |     .setApplicationContext(ctx)                    |
    |     Bean receives full ApplicationContext ref      |
    +----------------------------------------------------+
                          |
                          v
    +====================================================+
    |  6. BeanPostProcessor                              |<== CUSTOM HOOK POINT
    |     .postProcessBeforeInitialization()             |    (AOP proxies,
    |     Applied to ALL beans in context                |     validation, etc.)
    +====================================================+
                          |
                          v
    +====================================================+
    |  7. INITIALIZATION                                 |<== CUSTOM HOOK POINT
    |     a) @PostConstruct method called                |
    |     b) InitializingBean.afterPropertiesSet()       |
    |     c) init-method="..." (XML config)              |
    +====================================================+
                          |
                          v
    +====================================================+
    |  8. BeanPostProcessor                              |<== CUSTOM HOOK POINT
    |     .postProcessAfterInitialization()              |    (most AOP proxies
    |     Applied to ALL beans in context                |     happen HERE)
    +====================================================+
                          |
                          v
    +----------------------------------------------------+
    |  9. BEAN READY FOR USE                             |
    |     Bean lives in ApplicationContext               |
    |     Injected into other beans, handles requests    |
    +----------------------------------------------------+
                          |
          (on context.close() or app shutdown)
                          |
                          v
    +====================================================+
    | 10. DESTRUCTION                                    |<== CUSTOM HOOK POINT
    |     a) @PreDestroy method called                   |
    |     b) DisposableBean.destroy()                    |
    |     c) destroy-method="..." (XML config)           |
    |     Release resources, close connections           |
    +====================================================+
                          |
                          v
         +--------------------------------------+
         |        Bean garbage collected        |
         +--------------------------------------+
```

---

## Diagram 3: JPA Entity Lifecycle
*(Supplements Chapter 8 — Spring Data JPA & Hibernate)*

A JPA entity can be in one of four states. Understanding state transitions is essential for avoiding common bugs like the "detached entity passed to persist" exception and for understanding when database synchronization actually occurs.

```
    JPA ENTITY LIFECYCLE STATE MACHINE
    ====================================

                     new MyEntity()
    +------------+   no id, no context
    |            |
    |  TRANSIENT |
    |            |
    +------------+
          |                                    ^
          | em.persist(entity)                 | (entity goes out of scope
          |                                    |  or em.close() called)
          v                                    |
    +----------------------------------+       |
    |                                  |-------+
    |           MANAGED                |  em.detach(entity)
    |  (Persistence Context tracks it) |  em.clear()
    |                                  |  em.close()
    +----------------------------------+
          |         ^         |
          |         |         |
          | em.     | em.     | em.remove(entity)
          | detach()| merge() |
          |         | (copy   v
          v         |  state) +----------------------------------+
    +----------------------------------+  |                                  |
    |                                  |  |           REMOVED                |
    |          DETACHED                |  |  (scheduled for DELETE on flush) |
    |  (snapshot exists, not tracked)  |  |                                  |
    |  modifications NOT persisted     |  +----------------------------------+
    |  automatically                   |             |
    +----------------------------------+             | em.persist(entity)  <-- re-persists
          |                                          | (rare, but valid)
          | em.merge(detached)                       |
          +------------------------------------------+
          | returns NEW managed copy

    -----------------------------------------------------------------------
    ENTITY MANAGER CONTEXT BOUNDARY:
    +---------------------------------------------------------+
    |  Persistence Context (1st Level Cache)                  |
    |  +---------+  +---------+  +---------+                  |
    |  | Entity A|  | Entity B|  | Entity C|  <- MANAGED      |
    |  +---------+  +---------+  +---------+                  |
    |                                                          |
    |  Dirty checking runs on:                                 |
    |    - em.flush()  -> SQL sent to DB (still in txn)       |
    |    - transaction commit -> auto-flush then commit        |
    +---------------------------------------------------------+
                          |
                          | JDBC
                          v
    +---------------------------------------------------------+
    |                      DATABASE                           |
    +---------------------------------------------------------+

    KEY METHODS:
      em.find(MyEntity.class, id)  -> MANAGED (from DB or 1L cache)
      em.getReference(...)         -> MANAGED (lazy proxy)
      em.flush()                   -> sync PC state to DB (no commit)
      em.refresh(entity)           -> overwrite PC state from DB
```

---

## Diagram 4: Kafka Architecture
*(Supplements Chapter 11 — Apache Kafka)*

Kafka distributes partitions across brokers for parallelism and replicates them for fault tolerance. Each partition has one leader (handles reads/writes) and N-1 followers (replicate from leader). Consumer groups enable parallel consumption while guaranteeing each partition is consumed by exactly one member per group.

```
    KAFKA CLUSTER ARCHITECTURE
    ============================

    PRODUCER                    BROKERS                          CONSUMER GROUPS
    --------                    -------                          ---------------

               Topic: "orders" (3 partitions, replication-factor=2)

    +--------+   +-----------------------------------------------+
    |        |-->| BROKER 1                                      |   GROUP A (3 consumers)
    |Producer|   | +------------------+  +------------------+   |   +--------------------+
    |        |   | | P0 [LEADER]      |  | P1 [FOLLOWER]    |   |   | Consumer A1        |
    | key=   |   | | offset: 0..1052  |  | offset: 0..1052  |   |-->| reads P0           |
    | "order |   | +------------------+  +------------------+   |   +--------------------+
    |  _id"  |   +-----------------------------------------------+   | Consumer A2        |
    |        |                                                    |-->| reads P1           |
    | hash   |   +-----------------------------------------------+   +--------------------+
    | % 3    |   | BROKER 2                                      |   | Consumer A3        |
    |  = P#  |-->| +------------------+  +------------------+   |-->| reads P2           |
    |        |   | | P1 [LEADER]      |  | P2 [FOLLOWER]    |   |   +--------------------+
    |        |   | | offset: 0..987   |  | offset: 0..987   |   |
    +--------+   | +------------------+  +------------------+   |   GROUP B (2 consumers)
                 +-----------------------------------------------+   +--------------------+
                                                                  |   | Consumer B1        |
                 +-----------------------------------------------+   | reads P0 + P1      |
                 | BROKER 3                                      |-->| (2 partitions)     |
                 | +------------------+  +------------------+   |   +--------------------+
                 | | P2 [LEADER]      |  | P0 [FOLLOWER]    |   |   | Consumer B2        |
                 | | offset: 0..1103  |  | offset: 0..1103  |   |-->| reads P2           |
                 | +------------------+  +------------------+   |   +--------------------+
                 +-----------------------------------------------+
                                   |
                                   |  cluster metadata,
                                   |  leader election,
                                   |  consumer group offsets
                                   v
              +------------------------------------------------+
              |        ZooKeeper / KRaft (Kafka 3.x+)          |
              |                                                  |
              |  - Controller election (one broker = controller)|
              |  - ISR (In-Sync Replica) tracking               |
              |  - Consumer group offset storage (__offsets)    |
              |  KRaft: metadata log replicated internally,     |
              |         no external ZK dependency               |
              +------------------------------------------------+

    PARTITION ASSIGNMENT RULES:
      Group A: 3 consumers, 3 partitions -> 1 partition each  (ideal)
      Group B: 2 consumers, 3 partitions -> B1 gets 2, B2 gets 1 (uneven)
      Rule: a partition is assigned to exactly ONE consumer per group
      If consumers > partitions: some consumers idle
```

---

## Diagram 5: OAuth2 Authorization Code + PKCE Flow
*(Supplements Chapter 13 — Security)*

PKCE (Proof Key for Code Exchange) prevents authorization code interception attacks. The client generates a random secret (code_verifier), hashes it (code_challenge), and sends the hash upfront. When exchanging the code for a token, it sends the original secret — the server verifies they match, proving the requester is the original initiator.

```
    OAUTH2 AUTHORIZATION CODE + PKCE FLOW
    =======================================

    BROWSER/CLIENT          AUTH SERVER            RESOURCE SERVER
    --------------          -----------            ---------------
         |                       |                       |
         | 1. Generate locally:  |                       |
         |    code_verifier =    |                       |
         |    random 43-128 char |                       |
         |    code_challenge =   |                       |
         |    BASE64URL(         |                       |
         |     SHA256(verifier)) |                       |
         |                       |                       |
         |----(2) GET /authorize?---------------------------------->|
         |    client_id=...      |                       |
         |    redirect_uri=...   |                       |
         |    code_challenge=... |                       |
         |    code_challenge_    |                       |
         |    method=S256        |                       |
         |    scope=openid       |                       |
         |                       |                       |
         |    (3) User sees login page, enters credentials         |
         |        User grants consent to requested scopes          |
         |                       |                       |
         |<---(4) HTTP 302 redirect to redirect_uri?code=AUTH_CODE |
         |        (short-lived, single-use code, ~10 min)          |
         |                       |                       |
         |----(5) POST /token--->|                       |
         |    grant_type=        |                       |
         |     authorization_code|                       |
         |    code=AUTH_CODE     |                       |
         |    code_verifier=     |                       |
         |    <original secret>  |                       |
         |    redirect_uri=...   |                       |
         |                       |                       |
         |    (6) Auth Server:   |                       |
         |    verifies code valid|                       |
         |    computes SHA256(   |                       |
         |     code_verifier)    |                       |
         |    compares to stored |                       |
         |    code_challenge     |                       |
         |    if match -> issue  |                       |
         |<--- tokens -----------|                       |
         |    access_token (JWT) |                       |
         |    refresh_token      |                       |
         |    id_token (OIDC)    |                       |
         |    expires_in=3600    |                       |
         |                       |                       |
         |----(7) GET /api/data (Authorization: Bearer <access_token>)-->|
         |                       |                       |
         |                       |    (8) Validate JWT:  |
         |                       |    check signature    |
         |                       |    check exp claim    |
         |                       |    check iss/aud      |
         |                       |    check scopes       |
         |<---(8) 200 OK + data----------------------------         |
         |    (or 401 Unauthorized if token invalid)                |
         |    (or 403 Forbidden if valid but insufficient scope)    |

    KEY PKCE PROTECTION:
      Attacker intercepts AUTH_CODE but does NOT have code_verifier
      -> POST /token fails (cannot compute matching hash)
      -> Code is worthless without the verifier
```

---

## Diagram 6: B-tree Index Structure
*(Supplements Chapter 15 — Indexing & Query Optimization)*

B-tree is the default index type in PostgreSQL and MySQL/InnoDB. It supports equality lookups, range scans, ORDER BY, and prefix matching. The balanced tree structure guarantees O(log n) lookup. Leaf nodes form a doubly-linked list enabling efficient range scans without returning to the root.

```
    B-TREE INDEX STRUCTURE (index on "age" column)
    ================================================

    POINT LOOKUP: WHERE age = 35
    Path: Root -> Internal Node -> Leaf -> Heap Page

                         +------------------+
                         |   ROOT NODE      |   <-- always in memory (buffer pool)
                         |   [25 | 50 | 75] |
                         +------------------+
                        /        |         \
                       /         |          \
            +-----------+  +-----------+  +-----------+
            | INTERNAL  |  | INTERNAL  |  | INTERNAL  |
            | [10|18|25]|  | [30|35|42]|  | [55|63|70]|
            +-----------+  +-----------+  +-----------+
            /   |   |  \       |   |           |   \
           v    v   v   v      v   v           v    v
        +----+----+----+----+----+----+    +----+----+
        |LEAF|LEAF|LEAF|LEAF|LEAF|LEAF|<-->|LEAF|LEAF|
        | 5  | 12 | 20 | 28 | 33 | 38 |   | 56 | 67 |
        | 7  | 15 | 22 | 30 | 35 | 40 |   | 60 | 70 |
        | 9  | 17 | 24 | 32 | 36 | 45 |   | 63 | 72 |
        +-+--+-+--+-+--+-+--+-+--+-+--+   +-+--+-+--+
          |    |    |    |    |    |          |    |
          v    v    v    v    v    v          v    v
         [*]  [*]  [*]  [*]  [*]  [*]       [*]  [*]
          |              (row pointer = heap page + slot)
          v
    +------------------+
    | HEAP PAGE        |   <-- actual row data (not in index)
    | (ctid in PG,     |
    |  RID in SQL Srv) |
    +------------------+

    <--> = doubly-linked list between leaf nodes

    RANGE SCAN: WHERE age BETWEEN 30 AND 40
    1. Descend tree to leaf containing 30  (root->internal->leaf)
    2. Scan leaf forwards via linked list: 30, 32, 33, 35, 36, 38, 40
    3. For each key, follow row pointer to heap page
    4. Stop when key > 40

    +------------------------------------------------------+
    |  HASH INDEX COMPARISON                               |
    |                                                      |
    |  Hash Index:   age -> bucket via hash(age)           |
    |                                                      |
    |  +------+    +---------+                             |
    |  | hash | -> | bucket  | -> [row ptr, row ptr, ...]  |
    |  | fn   |    | 0x3F2A  |                             |
    |  +------+    +---------+                             |
    |                                                      |
    |  Point lookup:  O(1)  <-- FASTER than B-tree         |
    |  Range scan:    NOT SUPPORTED (hash destroys order)  |
    |  ORDER BY:      NOT SUPPORTED                        |
    |  Prefix match:  NOT SUPPORTED                        |
    |                                                      |
    |  Use case: equality-only (=), high-cardinality cols  |
    +------------------------------------------------------+
```

---

## Diagram 7: Consistent Hashing Ring
*(Supplements Chapter 17 — Distributed Databases & Sharding)*

Consistent hashing minimizes key remapping when nodes join or leave. Without it, adding a node requires remapping ~N/new_count keys. With consistent hashing, only ~N/new_count keys move. Virtual nodes (vnodes) distribute load more evenly and improve rebalancing granularity, solving the problem of uneven arcs in the physical node layout.

```
    CONSISTENT HASHING RING
    ========================

    HASH SPACE: 0 to 2^32 (shown as circle, clockwise)

                         0 / 2^32
                            |
                     A1(0)  |  C3(2^32-1)
                       \    |    /
              B3(3.8B)  \   |   / A3(150M)
                    \    *--+--*    /
             C2(3.3B)*  /       \  *B1(600M)
                   /  */         \*  \
                  /  / NodeB(2.9B)\   \
       NodeC(2.8B)* /               \  * A2(1.2B)
                 / *C1(2.5B)         \
                |                     * B2(1.8B)
       A1(0) --+                     |
               |    NodeA(2.1B)      |
                \        *          /
                 \      / \        / NodeB(1.8B)
                  \    /   \      /
                   *--+     +--*
                 B3       NodeC(1.6B)
                (3.8B)

    SIMPLIFIED RING VIEW (unwrapped):
    ================================================
    0         500M       1B        1.5B       2B        2.5B       3B        3.5B      2^32
    |----A1----|--B1-----|---A2----|---B2----|--A3-----|---C1----|---C2----|---B3----|--C3--|
         ^          ^         ^         ^         ^         ^         ^         ^
         |          |         |         |         |         |         |         |
        NodeA     NodeB     NodeA     NodeB     NodeA     NodeC     NodeC     NodeB     NodeC

    VIRTUAL NODE DISTRIBUTION:
      NodeA: A1(0), A2(1.2B), A3(150M)    -> owns ~33% of ring
      NodeB: B1(600M), B2(1.8B), B3(3.8B) -> owns ~33% of ring
      NodeC: C1(2.5B), C2(3.3B), C3(2^32) -> owns ~33% of ring

    DATA KEY PLACEMENT (clockwise to next vnode):
      hash("user:123") = 800M   -> goes CLOCKWISE -> hits A2(1.2B) -> NodeA
      hash("order:456") = 2.0B  -> goes CLOCKWISE -> hits A3(150M)?
                                    No, wraps: -> hits C1(2.5B) -> NodeC
      hash("item:789") = 1.6B   -> goes CLOCKWISE -> hits B2(1.8B) -> NodeB
      hash("cart:321") = 3.0B   -> goes CLOCKWISE -> hits C2(3.3B) -> NodeC

    NODE REMOVAL - NodeB goes down:
    Before:  ... A2 --[B2 owns this range]--> B2 ... A3 --[B1 owns]--> B1 ...
    After:   ... A2 --[NOW NodeA owns]--> A3 ... (only B-range keys move to next node)
             B1's keys go to A3 (next clockwise vnode)
             B2's keys go to A3 (next clockwise vnode)
             B3's keys go to C3 (next clockwise vnode)

    +----------------------------------------------------------+
    | WITHOUT VIRTUAL NODES (3 physical nodes on ring):        |
    |                                                          |
    |  0%        33%         66%        100%                   |
    |  |---NodeA--|---NodeB---|---NodeC---|                     |
    |                                                          |
    |  Problem: if NodeA is placed at 33% but NodeB at 70%    |
    |  NodeA owns 33%, NodeB owns 37%, NodeC owns 30%         |
    |  Uneven load! NodeB gets 23% more requests than NodeC   |
    |                                                          |
    | WITH VIRTUAL NODES (9 vnodes, 3 per physical):           |
    |                                                          |
    |  Each physical node has 3 positions spread evenly        |
    |  -> much more uniform load distribution                  |
    |  -> smaller rebalancing chunks on add/remove             |
    |  -> typical production: 100-200 vnodes per physical node |
    +----------------------------------------------------------+
```

---

## Diagram 8: MVCC Version Chain (PostgreSQL)
*(Supplements Chapter 16 — ACID, Transactions & Normalization)*

MVCC (Multi-Version Concurrency Control) allows readers to never block writers and vice versa. Each row modification creates a new tuple version rather than overwriting in place. Transaction IDs (xmin/xmax) on each tuple determine visibility for each transaction's snapshot. Old versions accumulate until VACUUM reclaims them.

```
    MVCC VERSION CHAIN (PostgreSQL)
    =================================

    HEAP PAGE (table "accounts", row for account_id=42)

    +=========================================================+
    |                     HEAP PAGE                           |
    |                                                         |
    |  TUPLE v1 (DEAD - awaiting VACUUM)                      |
    |  +--------------------------------------------------+   |
    |  | xmin=100  | xmax=200  | id=42 | balance=1000   |   |
    |  +--------------------------------------------------+   |
    |     ^              ^                                     |
    |     |              |                                     |
    |  INSERT by       DELETED/UPDATED                        |
    |  txn xid=100     by txn xid=200                        |
    |                                                         |
    |  TUPLE v2 (LIVE for recent transactions)                |
    |  +--------------------------------------------------+   |
    |  | xmin=200  | xmax=300  | id=42 | balance=1500   |   |
    |  +--------------------------------------------------+   |
    |     ^              ^                                     |
    |     |              |                                     |
    |  INSERT by       DELETED/UPDATED                        |
    |  txn xid=200     by txn xid=300                        |
    |                                                         |
    |  TUPLE v3 (CURRENT live tuple)                          |
    |  +--------------------------------------------------+   |
    |  | xmin=300  | xmax=0    | id=42 | balance=2000   |   |
    |  +--------------------------------------------------+   |
    |     ^              ^                                     |
    |     |              |                                     |
    |  INSERT by       0 = still live                         |
    |  txn xid=300     (not deleted)                         |
    +=========================================================+

    TRANSACTION VISIBILITY (snapshot isolation):

    T1 (xid=100, started before 200) -> sees: Tuple v1 (xmin=100, xmax=200)
                                         balance=1000
                                         (xmax=200 > snapshot -> ignore)

    T2 (xid=200, started before 300) -> sees: Tuple v2 (xmin=200, xmax=300)
                                         balance=1500
                                         (xmax=300 > snapshot -> ignore v2?)
                                         No: xmin=200 = self -> sees v2
                                         balance=1500

    T3 (xid=300, started after 200)  -> sees: Tuple v3 (xmin=300, xmax=0)
                                         balance=2000
                                         Tuple v1: xmax=200 < 300 -> dead, skip
                                         Tuple v2: xmax=300 = self's txn -> skip

    VACUUM runs:
      - identifies tuples where xmax < oldest_active_xid
      - marks space as reusable
      - does NOT shrink table (use VACUUM FULL for that)

    +----------------------------------------------------------+
    |  INNODB (MySQL) COMPARISON - UNDO LOG CHAIN             |
    |                                                          |
    |  InnoDB stores only ONE current version in the page.    |
    |  Old versions live in the UNDO LOG (rollback segment).   |
    |                                                          |
    |  Clustered Index Page:                                   |
    |  +------------------------------------------------+      |
    |  | DB_TRX_ID=300 | DB_ROLL_PTR=--+  | bal=2000  |      |
    |  +------------------------------------------------+      |
    |                                  |                        |
    |                                  v                        |
    |                         UNDO LOG SEGMENT                  |
    |                         +--------------------------+      |
    |                         | old: bal=1500, trx=200   |      |
    |                         | roll_ptr ----+           |      |
    |                         +--------------------------+      |
    |                                        |                  |
    |                                        v                  |
    |                         +--------------------------+      |
    |                         | old: bal=1000, trx=100   |      |
    |                         | roll_ptr = NULL          |      |
    |                         +--------------------------+      |
    |                                                          |
    |  Reader walks back the chain until finding a version    |
    |  with DB_TRX_ID <= its read_view snapshot low_limit.    |
    |  InnoDB purge thread cleans undo log (like PG VACUUM).  |
    +----------------------------------------------------------+
```

---

## Diagram 9: Microservices Request Flow
*(Supplements Chapter 10 — Microservices Architecture)*

A typical microservices request passes through multiple services. The API Gateway acts as the single entry point handling cross-cutting concerns. Distributed tracing correlates logs across service boundaries using trace IDs propagated in headers (e.g., W3C Trace Context or Zipkin B3 headers).

```
    MICROSERVICES REQUEST FLOW (Place Order)
    ==========================================

    CLIENT                                              INFRASTRUCTURE
    ------                                              --------------

    +--------+
    | Mobile |
    | /Web   |
    | Client |
    +--------+
         |
         | HTTPS POST /orders
         | TraceID: abc-123 (generated here or at gateway)
         v
    +------------------------------------------+
    |           API GATEWAY                     |   <-- Kong, AWS API GW, etc.
    |  - JWT validation / OAuth2 token check    |
    |  - Rate limiting (e.g. 100 req/sec/user)  |
    |  - Request routing by path/host           |
    |  - SSL termination                        |
    |  - Inject TraceID header                  |
    +------------------------------------------+
         |              |
         | lookup       | route to
         | service URL  | Order Service
         v              v
    +----------+   +-------------------------------------------------+
    | SERVICE  |   |              ORDER SERVICE                      |
    | REGISTRY |   |  span: abc-123/order-svc                        |
    | (Consul/ |   +-------------------------------------------------+
    | Eureka)  |          |              |              |
    +----------+          |              |              |
                          |              |              |
                   sync call      async publish    cache check
                 (REST/gRPC)      (Kafka event)   (Redis FIRST)
                    with CB            |                |
                          v            |                v
              +--------------+         |         +------------+
              | INVENTORY    |         |         |   REDIS    |
              | SERVICE      |         |         | Cache      |
              | span:        |         |         |            |
              | abc-123/     |         |         | GET order  |
              | inv-svc      |         |         | cache miss |
              |              |         |         | -> DB call |
              | circuit      |         |         +------------+
              | breaker:     |         |                |
              | CLOSED=ok    |         |                v
              | OPEN=fallback|         |         +------------+
              +--------------+         |         | PostgreSQL |
                                       |         | (primary)  |
                                       |         | INSERT     |
                                       |         | orders tbl |
                                       |         +------------+
                                       v
                              +------------------+
                              |     KAFKA        |
                              | Topic: orders    |
                              | Partition: P1    |
                              | offset: 10042    |
                              +------------------+
                                       |
                                       | consumer group
                                       v
                              +---------------------+
                              | NOTIFICATION SVC    |
                              | span: abc-123/notif |
                              |                     |
                              | send email/SMS      |
                              | to customer         |
                              +---------------------+

    DISTRIBUTED TRACE (Jaeger / Zipkin view):

    |<-----------  abc-123 total: 245ms  ----------------------->|
    |                                                              |
    | [API Gateway          12ms  ]                               |
    |    [Order Service              180ms              ]         |
    |       [Redis lookup  3ms]                                   |
    |       [Inventory Service (sync)   45ms      ]               |
    |       [PostgreSQL INSERT  28ms  ]                           |
    |       [Kafka publish  8ms]                                  |
    |    [Notification Svc (async)  -- not on critical path]      |

    CIRCUIT BREAKER STATES (Inventory Service call):
      CLOSED -> requests pass through, failure counted
      OPEN   -> requests fail fast (fallback: assume in-stock)
      HALF-OPEN -> test request allowed; if ok -> CLOSED
```

---

## Diagram 10: Redis Cluster Architecture
*(Supplements Chapter 12 — Redis & Caching)*

Redis Cluster shards data across masters using 16384 hash slots. Each key maps to a slot via CRC16(key) mod 16384. Hash tags allow co-locating related keys on the same slot by using curly braces. When a client sends a command to the wrong node, it receives a MOVED redirect with the correct node address.

```
    REDIS CLUSTER ARCHITECTURE
    ============================

    HASH SLOT RANGES:
      Master M1: slots    0 -  5460  (~1/3 of keyspace)
      Master M2: slots 5461 - 10922  (~1/3 of keyspace)
      Master M3: slots 10923 - 16383 (~1/3 of keyspace)

    CLUSTER TOPOLOGY:

    +--------------------+          +--------------------+
    |   MASTER M1        |<-------->|   MASTER M2        |
    |   slots: 0-5460    |  gossip  |   slots: 5461-10922|
    |   192.168.1.1:6379 |  protocol|   192.168.1.3:6379 |
    +--------------------+          +--------------------+
           |    ^                          |    ^
     async |    | failover            async|    | failover
     repl  |    | promotion           repl |    | promotion
           v    |                          v    |
    +--------------------+          +--------------------+
    |   REPLICA R1       |          |   REPLICA R2       |
    |   (hot standby)    |          |   (hot standby)    |
    |   192.168.1.2:6379 |          |   192.168.1.4:6379 |
    +--------------------+          +--------------------+

    +--------------------+
    |   MASTER M3        |<-------> (gossips with M1, M2)
    |   slots: 10923-    |
    |          16383     |
    |   192.168.1.5:6379 |
    +--------------------+
           |    ^
     async |    | failover
     repl  |    | promotion
           v    |
    +--------------------+
    |   REPLICA R3       |
    |   192.168.1.6:6379 |
    +--------------------+

    CLIENT INTERACTION (MOVED redirect):

    Client                M1                  M2
      |                   |                   |
      |--SET user:42 "x"->|                   |
      |                   |                   |
      |                   | slot(user:42) =   |
      |                   | CRC16("user:42")  |
      |                   | % 16384 = 5649    |
      |                   | 5649 NOT in 0-5460|
      |                   | -> MOVED redirect |
      |<--MOVED 5649      |                   |
      |   192.168.1.3:6379|                   |
      |                   |                   |
      |---SET user:42 "x"----------------->   |
      |                   |    slot 5649      |
      |<---OK---------------------------------|
      |                   |                   |
      (client caches slot map to avoid future redirects)

    HASH TAG EXAMPLE (co-locate related keys):

      Key: {user}.profile   -> hash("{user}") not hash("{user}.profile")
      Key: {user}.session   -> hash("{user}") same result
      Key: {user}.settings  -> hash("{user}") same result

      CRC16("user") % 16384 = 5474  -> all go to M2 (5461-10922)
      -> enables MULTI/EXEC and Lua scripts across these keys

    SLOT CALCULATION:
      CRC16(key) mod 16384
      If key contains {...}: hash only the content inside braces
      If key has no {}: hash entire key

    FAILURE DETECTION & FAILOVER:
      - Nodes gossip every 100ms
      - Node marked PFAIL (probable fail) after timeout
      - Node marked FAIL when majority of masters agree
      - Replica with most up-to-date replication offset wins election
      - Failover completes in typically 1-3 seconds
```

---

## Diagram 11: Thread States & Lifecycle
*(Supplements Chapter 6 — Multithreading & Concurrency)*

Java threads have six states defined in `Thread.State`. The OS scheduler moves threads between READY and RUNNING within the RUNNABLE state — Java cannot distinguish these. Knowing valid state transitions helps diagnose deadlocks (BLOCKED threads waiting for each other) and thread leaks (threads stuck in WAITING indefinitely).

```
    JAVA THREAD STATE MACHINE
    ==========================

                         Thread t = new Thread(r);
                                    |
                                    v
                            +-------------+
                            |     NEW     |
                            |  (created,  |
                            |  not started|
                            +-------------+
                                    |
                                    | t.start()
                                    |
                                    v
                    +-------------------------------+
                    |          RUNNABLE             |
                    |  +-----------+ +-----------+  |
                    |  |  READY    | | RUNNING   |  |
                    |  | (in run   | | (on CPU)  |  |
                    |  |  queue)   | |           |  |
                    |  +-----------+ +-----------+  |
                    |    OS scheduler moves          |
                    |    between READY <-> RUNNING   |
                    +-------------------------------+
                      /          |           \
                     /           |            \
                    /            |             \
                   v             |              v
    +-----------------+          |      +------------------+
    |    BLOCKED      |          |      |  TIMED_WAITING   |
    |                 |          |      |                  |
    | waiting for     |          |      | Thread.sleep(n)  |
    | intrinsic lock  |          |      | wait(n)          |
    | (synchronized   |          |      | join(n)          |
    |  block/method)  |          |      | LockSupport      |
    |                 |          |      |  .parkNanos(n)   |
    | lock released   |          |      |                  |
    | -> RUNNABLE     |          |      | timeout expires  |
    +-----------------+          |      | or notify/unpark |
           ^                     |      | -> RUNNABLE      |
           |                     |      +------------------+
    synchronized             object.wait()     ^
    block contended          LockSupport.park()    |
                             thread.join()         |
                                  |            sleep(n)/
                                  v            wait(n)/
                         +-----------------+   join(n)
                         |    WAITING      |
                         |                 |
                         | Object.wait()   |
                         | Thread.join()   |
                         | LockSupport     |
                         |  .park()        |
                         |                 |
                         | notify()        |
                         | notifyAll()     |
                         | LockSupport     |
                         |  .unpark()      |
                         | -> RUNNABLE     |
                         +-----------------+

    All states (except NEW) -> TERMINATED when run() completes
    or unhandled exception thrown:

                         +------------------+
                         |   TERMINATED     |
                         |  run() returned  |
                         |  or exception    |
                         |  uncaught        |
                         +------------------+

    COMMON CONCURRENCY BUGS:
    -------------------------
    DEADLOCK:
      T1 holds Lock A, waits for Lock B
      T2 holds Lock B, waits for Lock A
      Both in BLOCKED state forever
      Detect: jstack shows BLOCKED with "waiting to lock <...> held by thread..."

    LIVELOCK:
      Threads keep changing state responding to each other
      but no progress (e.g., each backs off and retries simultaneously)

    STARVATION:
      Low-priority thread perpetually blocked by high-priority threads
      Thread stays BLOCKED/WAITING indefinitely

    STATE CHECK:
      thread.getState()  // returns Thread.State enum
      jstack <pid>       // dump all thread states
      VisualVM / JMC     // GUI thread dump analysis
```

---

## Diagram 12: Spring Security Filter Chain
*(Supplements Chapter 13 — Security)*

Spring Security implements security as a chain of servlet filters. Every HTTP request passes through this chain before reaching the controller. Authentication failures return 401 (unauthenticated), while authorization failures return 403 (authenticated but lacks permission). Understanding the filter order is essential for customizing security behavior.

```
    SPRING SECURITY FILTER CHAIN
    ==============================

    INCOMING HTTP REQUEST
           |
           v
    +--------------------------------------------------+
    | DelegatingFilterProxy                            |
    | (bridges servlet container to Spring context)    |
    +--------------------------------------------------+
           |
           v
    +==================================================+
    ||           SecurityFilterChain                  ||
    ||                                                ||
    ||  +-----------------------------------------+  ||
    ||  | SecurityContextPersistenceFilter         |  ||
    ||  | Load SecurityContext from HttpSession     |  ||
    ||  | (or from JWT/token for stateless)        |  ||
    ||  +-----------------------------------------+  ||
    ||                    |                           ||
    ||                    v                           ||
    ||  +-----------------------------------------+  ||
    ||  | UsernamePasswordAuthenticationFilter     |  ||
    ||  | (or JwtAuthenticationFilter - custom)    |  ||    +---------------------------+
    ||  | Checks for credentials in request        |--||-->| AuthenticationManager     |
    ||  | Creates UsernamePasswordAuthToken        |  ||    | (ProviderManager)         |
    ||  +-----------------------------------------+  ||    +---------------------------+
    ||                    |                           ||              |
    ||                    v                           ||              v
    ||  +-----------------------------------------+  ||    +---------------------------+
    ||  | BasicAuthenticationFilter                |  ||    | AuthenticationProvider    |
    ||  | Checks Authorization: Basic header       |  ||    | (DaoAuthenticationProvider|
    ||  | Base64 decode -> authenticate            |  ||    | or JwtAuthProvider)       |
    ||  +-----------------------------------------+  ||    +---------------------------+
    ||                    |                           ||              |
    ||                    v                           ||              v
    ||  +-----------------------------------------+  ||    +---------------------------+
    ||  | RememberMeAuthenticationFilter           |  ||    | UserDetailsService        |
    ||  | Check remember-me cookie/token           |  ||    | loadUserByUsername()      |
    ||  +-----------------------------------------+  ||    | -> UserDetails object     |
    ||                    |                           ||    +---------------------------+
    ||                    v                           ||              |
    ||  +-----------------------------------------+  ||              | if authenticated
    ||  | AnonymousAuthenticationFilter            |  ||              v
    ||  | Set ROLE_ANONYMOUS if no auth yet        |  ||    +---------------------------+
    ||  +-----------------------------------------+  ||    | SecurityContextHolder     |
    ||                    |                           ||    | .getContext()             |
    ||                    v                           ||    | .setAuthentication(auth)  |
    ||  +-----------------------------------------+  ||    +---------------------------+
    ||  | ExceptionTranslationFilter               |--||--+
    ||  | Catches AuthenticationException:         |  ||  |  401 UNAUTHORIZED
    ||  |   -> 401 + WWW-Authenticate header        |  ||  |  (no/invalid credentials)
    ||  | Catches AccessDeniedException:            |  ||  |
    ||  |   if anon -> redirect to login            |  ||  |  403 FORBIDDEN
    ||  |   if auth -> 403 Forbidden                |  ||  |  (authenticated but no
    ||  +-----------------------------------------+  ||  |   permission for resource)
    ||                    |                           ||  |
    ||                    v                           ||  |
    ||  +-----------------------------------------+  ||  |
    ||  | FilterSecurityInterceptor                |  ||  |
    ||  | (or AuthorizationFilter in Spring 6)     |  ||  |
    ||  | Checks SecurityMetadataSource            |  ||  |
    ||  | @PreAuthorize, hasRole(), etc.            |  ||  |
    ||  | Calls AccessDecisionManager              |  ||  |
    ||  +-----------------------------------------+  ||  |
    ||                    |                           ||  |
    +==================================================+  |
                          |                              |
                          v  (if all checks pass)        |
    +--------------------------------------------------+  |
    |            YOUR CONTROLLER                       |  |
    |  @GetMapping("/admin/data")                      |  |
    |  @PreAuthorize("hasRole('ADMIN')")               |  |
    +--------------------------------------------------+  |
                          |                              |
                          v                              |
                   HTTP RESPONSE               <---------+
                   (200 OK + data)              (or 401/403)

    SECURITY CONTEXT FLOW:
      Request arrives -> load SecurityContext from session
      Authentication happens -> store in SecurityContextHolder (ThreadLocal)
      Request completes -> save SecurityContext back to session
      SecurityContextHolder.clearContext() -> after response sent

    JWT STATELESS FLOW (no session):
      JwtAuthenticationFilter extracts + validates JWT
      Sets Authentication in SecurityContextHolder
      Never stores in HttpSession (SESSION=STATELESS)
      Each request must carry valid JWT
```

---

*End of Appendix A*

---

*For the most up-to-date diagrams and interactive versions, refer to the companion repository.*

