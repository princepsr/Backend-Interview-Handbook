# Volume 5: System Design & Low-Level Design
# Chapter 21: LLD Case Studies
---

## Table of Contents

| # | System |
|---|--------|
| 1 | Parking Lot System |
| 2 | URL Shortener (like bit.ly) |
| 3 | Rate Limiter |
| 4 | BookMyShow — Movie Ticket Booking |
| 5 | Splitwise — Expense Sharing |
| 6 | Elevator System |

---

> **How to read this chapter:** Each case study has three layers.
> - **The Idea** — what problem we're solving, no prior knowledge needed.
> - **How It Works** — every design decision explained with WHY, not just WHAT. Each decision includes the alternatives considered and the tradeoff accepted.
> - **Interview Lens** — what interviewers probe, with full speakable answers focused on reasoning.
>
> For LLD interviews: always lead with "The key challenge here is X. I chose Y over Z because [reason]."

---

# Chapter 21: LLD Case Studies

---

## Topic 1: Parking Lot System — LLD Case Study

#### The Idea

Imagine you are the engineer responsible for the software running inside a multi-storey parking garage. Cars, trucks, motorcycles, and electric vehicles pull up at the gate. Your system must instantly tell the gate whether a spot is available, issue a ticket, track where every vehicle is parked, and calculate the fee when the driver leaves. Simple enough for a single-lane garage — but now picture hundreds of cars entering and exiting simultaneously across a dozen floors, with attendants manually overriding spot assignments and payment terminals talking to your system in real time.

The hard part is not the data model — it is the concurrency. Two cars cannot share a spot, and your software is the only thing preventing that. If two threads both see the same "available" spot and both try to park there, one of them wins and one produces a ghost ticket pointing at an occupied spot. Getting this right without grinding the system to a halt with locks is the interesting engineering problem.

There is also an extensibility challenge. Parking lots regularly add new vehicle types (electric SUVs with special charging spots) and new pricing models (surge pricing, monthly passes, flat-rate evenings). If the fee calculation logic is one giant if-else tree, every new rule means touching the exit flow — a recipe for regressions. A well-designed parking lot system makes adding a new vehicle type or fee strategy a matter of writing one new class, not modifying existing code.

---

#### How It Works

**Step 1: Requirements & Clarifying Questions**

| Functional Requirement | Description |
|---|---|
| FR-1 | Multiple floors, each with multiple spots |
| FR-2 | Spot types: Compact, Large, Handicapped, Motorcycle |
| FR-3 | Vehicle types: Car, Truck, Motorcycle, Electric |
| FR-4 | Vehicle parks only in a compatible spot type |
| FR-5 | Entry issues a Ticket (timestamp, spot, vehicle) |
| FR-6 | Exit calculates fee and processes Payment |
| FR-7 | Admin can add/remove floors and spots |
| FR-8 | ParkingAttendant can manually assign spots |
| FR-9 | Real-time available spot count per floor per type |
| FR-10 | Multiple payment methods: Cash, Credit Card, UPI |

**Clarifying questions to ask in an interview:**

1. *Single building or distributed across multiple locations?* — A single building is one JVM process with shared memory; distributed means services, message queues, and distributed locking. These are architecturally different problems.
2. *Are EV charging spots a separate type or a flag on an existing spot?* — Determines whether to subclass `ParkingSpot` or add a boolean field; affects the type hierarchy.
3. *What is the fee model — flat rate, hourly, or dynamic/surge?* — Determines whether fee calculation is a simple multiplication or needs a time-series rate schedule, which changes the Strategy interface signature.
4. *Do monthly pass holders bypass the ticket flow entirely?* — If yes, you need a fast pre-check before spot assignment; affects the entry gate logic.
5. *Is payment synchronous (gate stays closed until payment confirmed) or async?* — Synchronous means the gate waits on payment API response; async means the gate opens optimistically and reconciles later. Huge difference for throughput.

---

**Step 2: Core Entities**

```
ParkingLot (Singleton)
  └── floors: List<ParkingFloor>
        └── spotsByType: Map<SpotType, List<ParkingSpot>>
              └── ParkingSpot
                    └── parkedVehicle: Vehicle

Vehicle (abstract)
  ├── Car
  ├── Truck
  ├── Motorcycle
  └── ElectricVehicle

Ticket
  ├── vehicle
  ├── spot
  ├── entryTime / exitTime
  └── status

Payment
  ├── ticket
  ├── amount
  ├── method: PaymentMethod (CASH, CREDIT_CARD, UPI)
  └── status

ParkingFeeStrategy (interface)
  ├── HourlyFeeStrategy
  ├── FlatRateFeeStrategy
  └── EVFeeStrategy
```

- **ParkingLot** is a separate entity (not just a list of floors) because it is the global coordination point — it holds active tickets, the Singleton reference, and the entry/exit API.
- **ParkingFloor** is separate from ParkingLot because floors have their own available-count tracking and future floors can be added/removed without restructuring the lot.
- **ParkingSpot** is separate from ParkingFloor because spots have identity (ID, type, status), are the unit of locking, and are associated with Tickets directly.
- **Ticket** is separate from Vehicle because the same vehicle may park multiple times; a Ticket is one parking session, not a permanent property of a vehicle.
- **Payment** is separate from Ticket because one ticket could eventually support split payments, refunds, or payment retries — coupling them would make that impossible.
- **ParkingFeeStrategy** is a standalone interface rather than a method on Vehicle because fee rules change independently of vehicle types (a promotion might make all vehicles free on weekends).

---

**Step 3: Design Decisions**

**Decision: Singleton pattern for ParkingLot**
*Why this over the alternatives:* We could instantiate ParkingLot as a normal object passed through every service. But every actor — gate terminals, attendants, display boards — needs access to the same state. A Singleton ensures there is exactly one shared state object per deployment, and the static accessor makes it reachable without dependency injection wiring. We use double-checked locking with a `volatile` field to avoid the broken-initialization race condition: without `volatile`, the JVM can publish a partially constructed object reference to a second thread.
*Tradeoff:* Singletons are notoriously hard to test (you cannot swap a fresh instance between tests). Mitigate by also providing a package-private constructor for test use, or by wrapping the Singleton behind an interface for dependency injection in tests.

**Decision: Strategy pattern for ParkingFeeStrategy**
*Why this over the alternatives:* The naive approach is a switch statement in the exit flow: `if (vehicle instanceof ElectricVehicle) { ... } else if (vehicle instanceof Truck) { ... }`. Every new vehicle type or pricing rule requires modifying the exit controller. The Strategy pattern extracts each fee algorithm into its own class implementing `calculateFee(Ticket ticket)`. The exit flow simply calls `feeStrategy.calculateFee(ticket)` — it never knows which algorithm runs. Adding "weekend flat rate" is a new class, zero modifications to existing code.
*Tradeoff:* More classes to navigate. The Strategy instance must be resolved somehow (Factory, config, or per-vehicle-type default). This is a small upfront cost that pays off the first time you add a new fee model.

**Decision: synchronized on ParkingSpot.park() to prevent double-parking**
*Why this over the alternatives:* The find-then-park sequence is a classic Time-Of-Check-To-Time-Of-Use (TOCTOU) race: Thread A finds spot #5 available, Thread B finds spot #5 available, both call park(). Without synchronization, both succeed and you have two tickets for one spot. We could use optimistic locking (compare-and-swap with AtomicReference<Vehicle>): `spot.parkedVehicle.compareAndSet(null, vehicle)` — if it returns false, another thread got there first, retry with the next spot. CAS avoids blocking but introduces retry logic. For a parking system where contention per spot is extremely low (seconds apart), synchronized is simpler and the lock overhead is negligible.
*Tradeoff:* synchronized creates a bottleneck per spot under extreme contention. In practice, two cars cannot physically reach the same spot simultaneously, so this is theoretical. If this were a purely virtual resource (like a database row), CAS would be the right call.

**Decision: AtomicInteger for available spot count per floor per type**
*Why this over the alternatives:* We could recompute available count by scanning the spots list on every query — always accurate, never stale. But scanning a 500-spot floor for every display board refresh under high concurrency is wasteful. We could also maintain a plain int counter, but then increment/decrement must be synchronized separately from spot status changes, and they can diverge if an exception fires between the two operations. An AtomicInteger keeps the count consistent without a full scan, and its increment/decrement operations are lock-free CAS under the hood.
*Tradeoff:* The count and the spot status are still two separate data structures that must be updated together. We wrap both updates in the same synchronized block on ParkingSpot to keep them atomic. This is the smallest safe unit: change status AND update count in one critical section.

**Decision: Strategy + Factory for PaymentProcessor**
*Why this over the alternatives:* A switch on `PaymentMethod` in the exit controller works for three payment types today but breaks open/closed principle when a fourth type (e.g., crypto) is added. Instead, `PaymentProcessor` is an interface with one method: `charge(amount)`. `CashProcessor`, `CreditCardProcessor`, and `UPIProcessor` implement it. A `PaymentProcessorFactory` maps `PaymentMethod` enum values to implementations. The exit controller calls `factory.get(method).charge(amount)` — completely unaware of which processor runs.
*Tradeoff:* Requires a factory and one class per payment method. For a system with two payment types this would be over-engineering; for a production parking system expected to add new payment rails, it is the right call.

**Decision: Observer pattern for DisplayBoard**
*Why this over the alternatives:* Display boards need to show current availability. We could poll: every second, query `floor.getAvailableCount()`. This works but wastes cycles when nothing changes and has up to 1-second lag. With Observer, `ParkingFloor` notifies registered `DisplayBoard` listeners whenever spot status changes. No polling, zero lag, and DisplayBoard is decoupled from ParkingFloor — it only knows about the `AvailabilityListener` interface.
*Tradeoff:* Synchronous Observer notification means a slow DisplayBoard update (e.g., a network call to a screen) blocks the thread that parked the vehicle. Mitigation: make Observer notifications asynchronous (dispatch to a separate thread pool).

---

**Step 4: Key Algorithm (pseudocode)**

```
function parkVehicle(vehicle, preferredFloor):
    floors = preferredFloor != null ? [preferredFloor] : lot.getAllFloors()
    
    for each floor in floors:
        compatibleTypes = getCompatibleSpotTypes(vehicle.type)
        
        for each spotType in compatibleTypes:
            spotList = floor.getSpots(spotType)
            
            for each spot in spotList:
                synchronized(spot):
                    if spot.status == AVAILABLE:
                        spot.status = OCCUPIED
                        spot.parkedVehicle = vehicle
                        floor.decrementAvailable(spotType)   // AtomicInteger
                        floor.notifyObservers()              // update display boards
                        
                        ticket = new Ticket(vehicle, spot, now())
                        lot.activeTickets.put(vehicle.licensePlate, ticket)
                        return ticket
    
    return NO_SPOT_AVAILABLE
```

---

**Step 5: Must-Know Code**

```java
public class ParkingSpot {
    private final String id;
    private final SpotType type;
    
    // AtomicReference allows lock-free CAS as an alternative to synchronized.
    // We use synchronized here for clarity; in an interview, mention both options.
    private final AtomicReference<Vehicle> parkedVehicle = new AtomicReference<>(null);

    /**
     * synchronized ensures that find-and-park is atomic.
     * Without this, two threads can both observe parkedVehicle == null,
     * both pass the check, and both park — TOCTOU race condition.
     */
    public synchronized boolean park(Vehicle vehicle) {
        if (parkedVehicle.get() != null) {
            return false; // already occupied — caller retries with next spot
        }
        parkedVehicle.set(vehicle);
        // Status change and count decrement happen in same synchronized block
        // so they can never diverge (e.g., count decremented but status not yet changed).
        return true;
    }

    public synchronized Vehicle unpark() {
        Vehicle v = parkedVehicle.getAndSet(null);
        // Caller is responsible for incrementing floor's available count
        // after this returns non-null.
        return v;
    }

    public boolean isAvailable() {
        return parkedVehicle.get() == null;
    }
}

// ParkingLot Singleton with double-checked locking
public class ParkingLot {
    // volatile prevents the JVM from publishing a partially constructed instance
    // to a second thread. Without volatile, the new ParkingLot() assignment
    // can be reordered: reference published before constructor completes.
    private static volatile ParkingLot instance;
    
    private final Map<String, Ticket> activeTickets = new ConcurrentHashMap<>();

    private ParkingLot() {}

    public static ParkingLot getInstance() {
        if (instance == null) {                    // first check: avoid lock on every call
            synchronized (ParkingLot.class) {
                if (instance == null) {            // second check: only one thread constructs
                    instance = new ParkingLot();
                }
            }
        }
        return instance;
    }
}
```

---

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: In case study questions, structure your answer as: "The key challenge is X. I chose Y over Z because [reason]. The tradeoff is [cost]." This signals senior-level thinking.*

---

**Concurrency**
**"Why is ParkingLot a Singleton, and how do you make it thread-safe?"**

**One-line answer:** One shared state object for the whole deployment, made thread-safe with volatile double-checked locking and ConcurrentHashMap for active tickets.

**Full answer:**
> "ParkingLot is a Singleton because every actor in the system — gate terminals, payment kiosks, attendant screens, display boards — must see the same state. If each created its own ParkingLot instance, an attendant assigning a spot and a gate terminal issuing a ticket would be working with different spot lists. The Singleton ensures a single, shared coordination point. For thread safety, I use double-checked locking with a `volatile` field. The `volatile` keyword matters because without it, the JVM can reorder the assignment: another thread might see a non-null reference to a partially constructed object and skip the synchronized block, reading garbage state. The `volatile` forces a happens-before relationship: the write to `instance` is only visible after the constructor completes. For `activeTickets`, I use `ConcurrentHashMap` rather than `HashMap` with synchronized methods — it uses lock-striping internally, so concurrent reads and writes to different buckets do not block each other."

> *Lead with why Singleton, then explain volatile before the interviewer asks.*

**Gotcha follow-up:** *"Singletons are hard to unit test — how do you handle that?"*
> "I make the Singleton implement an interface (e.g., `IParkingLot`) and inject it through the interface in all callers. Tests create a mock or a fresh implementation directly, bypassing the static accessor. The production code uses `ParkingLot.getInstance()`, but nothing forces the static call — it is only the default for production wiring."

---

**Race Condition**
**"How do you prevent two threads from parking in the same spot?"**

**One-line answer:** Synchronize the entire check-and-assign operation on the ParkingSpot object so no other thread can interleave between finding a spot available and marking it occupied.

**Full answer:**
> "This is a Time-Of-Check-To-Time-Of-Use problem. If Thread A calls `isAvailable()` and sees true, then Thread B calls `isAvailable()` before Thread A calls `park()`, both threads see the spot as free and both proceed to park — you get two tickets for one spot. The fix is to make the check and the assignment atomic by synchronizing the entire `park()` method on the ParkingSpot instance. Now only one thread can be inside `park()` at a time. The alternative I would mention in an interview is using `AtomicReference<Vehicle>` with `compareAndSet(null, vehicle)`: if it returns false, another thread won the CAS race and this thread retries with the next spot. CAS avoids blocking entirely and is preferable for very high-contention resources. For a parking spot, contention is realistically zero — two physical cars cannot reach the same spot simultaneously — so synchronized is cleaner and equally correct."

> *Always name the TOCTOU pattern explicitly — it shows you recognize the class of problem, not just the specific fix.*

**Gotcha follow-up:** *"Can the available spot counter diverge from the actual spot statuses?"*
> "Yes, if the counter decrement and the status change happen in separate synchronized blocks. The fix is to do both inside the same critical section: inside `ParkingSpot.park()`, after successfully setting the parkedVehicle reference, call `floor.decrementAvailable(spotType)` before releasing the lock. This way, the count and the status change atomically — no thread can observe a state where the spot is occupied but the count has not yet been decremented."

---

**Design Pattern**
**"How do you support multiple payment methods without a switch statement?"**

**One-line answer:** Strategy pattern — one interface, one implementation per payment method, resolved by a Factory keyed on the PaymentMethod enum.

**Full answer:**
> "The naive approach is a switch statement in the exit flow: case CASH: do cash logic; case CREDIT_CARD: do card logic. Every new payment rail means opening the exit controller and adding a case — violating the open/closed principle and risking regression. I use the Strategy pattern instead. `PaymentProcessor` is an interface with one method: `charge(BigDecimal amount)`. `CashProcessor`, `CreditCardProcessor`, and `UPIProcessor` each implement it. A `PaymentProcessorFactory` maps the `PaymentMethod` enum value to the right implementation. The exit flow becomes: `processorFactory.get(paymentMethod).charge(fee)`. Adding a new payment method means writing one new class and one line in the factory map — zero changes to the exit controller. The pattern works because fee collection is a single operation regardless of the method; the interface is cohesive."

> *Connect the pattern name to the specific problem it solves — interviewers want to see the reasoning, not just the name.*

**Gotcha follow-up:** *"How would you extend this to a distributed, multi-building parking network?"*
> "Each building becomes its own microservice with its own database. A Central Availability Aggregator service queries all building services for their spot counts and caches the results. Spot status changes are published to a Kafka topic; display boards and the aggregator subscribe. For cross-building spot reservations, distributed locking via Redis SETNX prevents two users from booking the same spot. Tickets and payments are still per-building, but a user profile service federates them for billing history."

---

**Extensibility**
**"How do you add a new vehicle type — say, an e-scooter — without touching existing code?"**

**One-line answer:** Add an EScooter subclass of Vehicle, a new SpotType constant if needed, update the compatibility map, and add an EScooterFeeStrategy — zero changes to the parking or exit flows.

**Full answer:**
> "The design has three extension points. First, `Vehicle` is abstract — I add `EScooter extends Vehicle` and set its type enum. Second, the compatibility mapping (which vehicle types fit which spot types) is a `Map<VehicleType, List<SpotType>>` loaded at startup from config — I add one entry without touching any logic. Third, fee calculation is a Strategy — I write `EScooterFeeStrategy implements ParkingFeeStrategy` and register it in the fee strategy factory. The parking flow calls `feeStrategy.calculateFee(ticket)` with no awareness of vehicle type. The exit flow does the same. Neither flow needs modification. This is the payoff of the open/closed principle: the system is open for extension via new classes and closed for modification of existing logic."

> *Show you can trace the extension through all three layers: model, mapping, and fee. That completeness is what senior candidates do.*

---

> **Common Mistake — Recomputing available count by scanning all spots:** Computing available count by iterating the spot list on every display board refresh works correctly but causes O(n) scans under high read concurrency. At 500 spots per floor and 10 floors, every refresh scans 5,000 objects. Use an AtomicInteger per floor per spot type, updated in the same synchronized block as the spot status change, so the count is always accurate and queries are O(1).

---

**Quick Revision:** The core challenge in a Parking Lot LLD is the TOCTOU race between finding a free spot and claiming it — solve it by synchronizing the entire check-and-assign on the ParkingSpot object, and use Strategy for fees and payment methods to keep the exit flow closed to modification.

---

---

## Topic 2: URL Shortener — LLD Case Study

#### The Idea

A URL shortener takes a long, unwieldy web address and produces a short code — like turning `https://www.example.com/articles/2024/how-to-design-systems?utm_source=email&campaign=launch` into `shr.ly/aB3dE7`. Users share the short link; when someone clicks it, the shortener looks up the mapping and sends them to the original URL. The whole interaction takes a fraction of a second.

What makes this interesting to design is the extreme asymmetry in access patterns. Creating a new short link happens rarely — maybe millions of times per day across the whole platform. But *redirecting* short links can happen billions of times per day, because every person who clicks a shared link triggers a redirect. Your read path must be blazing fast (under 10 milliseconds), while your write path can tolerate a little more latency. Most system design is symmetric; this one is not.

There is also a subtle correctness problem that trips up candidates: the choice between HTTP 301 and 302. A 301 redirect is "permanent" — browsers cache it and never ask your server again. A 302 redirect is "temporary" — browsers re-request every time. If you choose 301 for speed, you lose all click analytics because subsequent clicks bypass your server entirely. That single decision shapes the entire analytics architecture, and most candidates pick 301 without realizing the consequence.

---

#### How It Works

**Step 1: Requirements & Clarifying Questions**

| Functional Requirement | Description |
|---|---|
| FR-1 | Long URL → unique short code (e.g. shr.ly/aB3dE7) |
| FR-2 | Redirect short → long URL (HTTP 301 or 302) |
| FR-3 | Custom alias (user-chosen short code) |
| FR-4 | Expiry support (TTL or fixed date) |
| FR-5 | Click analytics (count, timestamp, referrer, geo) |
| FR-6 | Authenticated users can manage their own URLs |

**Clarifying questions to ask in an interview:**

1. *What are the expected QPS for redirects vs. creation?* — If redirects are 1,000× more frequent than creates, you invest heavily in caching; if they are equal, you optimize writes as much as reads. This is the single biggest number driving architecture.
2. *301 vs. 302 for redirects?* — Not a preference question — it is a product decision with major engineering consequences. 301 = browser-cached, no analytics. 302 = always hits your server, enables analytics. Asking this shows you know the tradeoff.
3. *Are analytics real-time or eventual consistency acceptable?* — Real-time analytics requires synchronous writes on the redirect path, adding latency. Eventual is fine for most analytics dashboards and enables async/Kafka write paths.
4. *Should the same long URL always produce the same short code (dedup), or can two users shorten the same URL independently?* — Dedup is simpler but merges analytics across users, destroying per-user click isolation. Affects the code generation strategy entirely.

---

**Step 2: Core Entities**

```
ShortUrl
  ├── shortCode (PK)
  ├── longUrl
  ├── userId (FK → User)
  ├── createdAt
  ├── expiresAt
  ├── active (boolean)
  └── clickCount

ClickAnalytics
  ├── id
  ├── shortCode (FK → ShortUrl)
  ├── clickedAt
  ├── ipAddress
  ├── referrer
  └── userAgent

User
  ├── userId (PK)
  ├── email
  └── tier (FREE, PRO)
```

- **ShortUrl** is the core entity — it owns the mapping, expiry, and ownership. Everything else references it.
- **ClickAnalytics** is a separate entity rather than a counter on ShortUrl because each click has its own attributes (timestamp, IP, referrer). A counter would tell you how many clicks; a separate row per click tells you *who* clicked, *when*, and *from where* — enabling funnel analysis and geo dashboards.
- **User** is separate because authentication, tier management, and URL ownership have independent lifecycles and would bloat ShortUrl if inlined.

---

**Step 3: Design Decisions**

**Decision: Counter-based code generation (Redis INCR → Base62 encoding)**
*Why this over the alternatives:* Random 6-character codes are not enumerable (a plus for privacy), but they have collision probability that grows as the database fills. At 50% capacity, ~1 in 2 random codes collides, requiring expensive retry loops. MD5/SHA hash truncation is deterministic (same URL = same code) but has collision probability at truncation. Counter-based is the cleanest: Redis INCR is atomic and returns a globally unique integer every time, zero retries needed. Encode the integer to Base62 (`[0-9a-zA-Z]`): 6 characters = 62^6 = 56.8 billion unique codes, approximately 57 years of capacity at 1 billion URLs per year.
*Tradeoff:* Sequential counters are enumerable — an attacker can iterate `aAAAAA`, `aAAAAB`, etc. and discover all short URLs. Mitigate by shuffling the character map or XOR-masking the counter before encoding. For most products, this is an acceptable risk; for confidential links, use random generation despite the retry complexity.

**Decision: HTTP 302 redirect (not 301)**
*Why this over the alternatives:* HTTP 301 means "permanently moved" — browsers cache it and subsequent clicks go directly to the destination without touching your server. This is faster for users but catastrophically breaks analytics: once a browser caches the 301, your click counter never increments again. HTTP 302 means "temporarily moved" — browsers always re-request from your server, allowing you to count the click. The speed penalty (one extra DNS + TCP round trip per click) is mitigated by caching the shortCode→longUrl mapping at the CDN layer. The CDN handles the lookup in <1ms; your server just needs to handle cache misses and analytics writes.
*Tradeoff:* Every redirect touches your infrastructure (CDN or server), increasing operational cost and adding ~5-10ms latency vs. 301. For a product where analytics is a core feature, this is non-negotiable. If you are building a simple redirect service with no analytics requirements, 301 is correct.

**Decision: Allow duplicate short codes for the same long URL (no dedup)**
*Why this over the alternatives:* Deduplication means if User A and User B both shorten `https://example.com/`, they get the same short code and share one analytics stream. This seems efficient but destroys per-user isolation: User A cannot tell which clicks came from their audience vs. User B's audience. By allowing duplicates, each user gets their own code and their own analytics stream. The storage cost is negligible — one extra row per duplicate URL.
*Tradeoff:* Popular URLs (e.g., a news article shortened by a million users) waste storage with duplicate long URL strings. Mitigate with a separate `LongUrl` content-addressed table and foreign keys, deduplicating the *storage* without deduplicating the *codes*.

**Decision: Async analytics writes (fire-and-forget on redirect path)**
*Why this over the alternatives:* Writing a ClickAnalytics row on the synchronous redirect path adds database write latency to every user redirect. Users experience this as slow redirects. The user clicking the link does not care about analytics; they care about reaching the destination. By publishing a click event to a Kafka topic (or using Spring's `@Async` event listener) on the redirect path, the redirect returns immediately and the analytics write happens in the background. Analytics dashboards are updated within seconds, which is good enough for every realistic analytics use case.
*Tradeoff:* Analytics are eventually consistent — a dashboard refresh immediately after a click might not show that click yet. Clicks can be lost if the Kafka consumer crashes before committing the offset (mitigate with at-least-once delivery + idempotent writes keyed on a UUID per click event).

**Decision: Redis cache for shortCode→longUrl lookups**
*Why this over the alternatives:* The redirect path hits the same hot short codes millions of times per day. Without caching, every redirect queries PostgreSQL. At 100,000 redirects/second, that is 100,000 DB reads/second — expensive and slow. Redis can handle millions of reads per second with sub-millisecond latency. Cache hit rate for popular URLs exceeds 99%. Set TTL = expiry time of the short URL so the cache entry self-expires when the URL does.
*Tradeoff:* Cache invalidation is needed when a URL is deactivated or its expiry is updated. Two strategies: write-through (update cache on every DB write) or TTL-based expiry (stale entries serve expired URLs for up to TTL seconds). For URL shorteners, TTL-based is acceptable — a few seconds of serving an expired URL is not a safety issue. For instant deactivation (abuse cases), write-through or active cache deletion is required.

---

**Step 4: Key Algorithm (pseudocode)**

```
function redirect(shortCode, requestContext):
    // Step 1: Check Redis cache first
    longUrl = redis.get("url:" + shortCode)
    
    if longUrl is null:
        // Step 2: Cache miss — query database
        shortUrl = db.findByShortCode(shortCode)
        
        if shortUrl is null or shortUrl.active == false:
            return HTTP 404
        
        if shortUrl.expiresAt != null and shortUrl.expiresAt < now():
            return HTTP 410 GONE  // expired, different from "never existed"
        
        longUrl = shortUrl.longUrl
        redis.set("url:" + shortCode, longUrl, TTL = shortUrl.expiresAt - now())
    
    // Step 3: Fire analytics event asynchronously — DO NOT await
    eventBus.publishAsync(ClickEvent {
        shortCode: shortCode,
        clickedAt: now(),
        ipAddress: requestContext.ip,
        referrer: requestContext.referer
    })
    
    // Step 4: Return 302 redirect
    return HTTP 302 Location: longUrl


function createShortUrl(longUrl, userId, customAlias, expiresAt):
    shortCode = customAlias != null
        ? validateAndReserve(customAlias)
        : base62Encode(redis.incr("global:url:counter"))
    
    db.insert(ShortUrl {
        shortCode: shortCode,
        longUrl: longUrl,
        userId: userId,
        createdAt: now(),
        expiresAt: expiresAt,
        active: true
    })
    
    return "https://shr.ly/" + shortCode
```

---

**Step 5: Must-Know Code**

```java
@Service
public class UrlShortenerService {

    private static final String BASE62 = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    private static final String COUNTER_KEY = "global:url:counter";
    private static final String CACHE_PREFIX = "url:";

    private final RedisTemplate<String, String> redis;
    private final ShortUrlRepository repository;
    private final ApplicationEventPublisher eventPublisher;

    public String createShortUrl(String longUrl, Long userId, String customAlias, Instant expiresAt) {
        String shortCode;

        if (customAlias != null) {
            // Custom aliases must be checked for conflicts before insert.
            // Use INSERT ... ON CONFLICT DO NOTHING and check rows affected.
            if (repository.existsByShortCode(customAlias)) {
                throw new AliasAlreadyTakenException(customAlias);
            }
            shortCode = customAlias;
        } else {
            // Redis INCR is atomic: guaranteed unique integer across all instances.
            // No retry loop needed — this is the key advantage over random generation.
            long counter = redis.opsForValue().increment(COUNTER_KEY);
            shortCode = toBase62(counter);
        }

        repository.save(new ShortUrl(shortCode, longUrl, userId, Instant.now(), expiresAt, true));
        return "https://shr.ly/" + shortCode;
    }

    public String resolveAndRedirect(String shortCode, ClickContext ctx) {
        // Check cache first — this is the hot path, must be sub-millisecond
        String cached = redis.opsForValue().get(CACHE_PREFIX + shortCode);
        if (cached != null) {
            // Publish analytics event without blocking the redirect response.
            // @Async means this returns immediately; the event listener writes to DB.
            eventPublisher.publishEvent(new ClickEvent(shortCode, Instant.now(), ctx.ip(), ctx.referrer()));
            return cached; // caller returns HTTP 302 to this URL
        }

        // Cache miss: query DB, validate, cache, then redirect
        ShortUrl shortUrl = repository.findByShortCode(shortCode)
                .orElseThrow(() -> new UrlNotFoundException(shortCode));

        if (!shortUrl.isActive()) {
            throw new UrlNotFoundException(shortCode);
        }
        if (shortUrl.getExpiresAt() != null && shortUrl.getExpiresAt().isBefore(Instant.now())) {
            throw new UrlExpiredException(shortCode); // caller returns HTTP 410
        }

        // Cache with TTL aligned to URL expiry so cache auto-expires with the URL.
        Duration ttl = shortUrl.getExpiresAt() != null
                ? Duration.between(Instant.now(), shortUrl.getExpiresAt())
                : Duration.ofHours(24); // default TTL for URLs with no expiry
        redis.opsForValue().set(CACHE_PREFIX + shortCode, shortUrl.getLongUrl(), ttl);

        eventPublisher.publishEvent(new ClickEvent(shortCode, Instant.now(), ctx.ip(), ctx.referrer()));
        return shortUrl.getLongUrl();
    }

    // Base62 encoding: maps integer to [0-9a-zA-Z] string.
    // Equivalent to converting a number to base 62, reading digits right-to-left.
    private String toBase62(long n) {
        StringBuilder sb = new StringBuilder();
        while (n > 0) {
            sb.append(BASE62.charAt((int)(n % 62)));
            n /= 62;
        }
        return sb.reverse().toString();
    }
}
```

---

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: In case study questions, structure your answer as: "The key challenge is X. I chose Y over Z because [reason]. The tradeoff is [cost]." This signals senior-level thinking.*

---

**Tradeoff**
**"Why would you choose 302 over 301 for the redirect response?"**

**One-line answer:** 301 is permanently cached by the browser, so subsequent clicks never reach your server and you lose all analytics; 302 forces every click through your server so you can count them.

**Full answer:**
> "This is one of those decisions that looks like a performance question but is actually a product question. A 301 (Moved Permanently) response tells the browser to cache the destination URL forever. The first click goes through your server; every subsequent click from that browser goes directly to the destination, bypassing you entirely. That is great for latency — zero server involvement after the first click. But it kills analytics permanently. A 302 (Found / Moved Temporarily) tells the browser not to cache; it must re-request every time. Every click touches your server, so you can count it, record the timestamp, capture the referrer and IP, and build usage dashboards. For a URL shortener where analytics is a core feature — the whole reason businesses use it — 302 is the correct choice. The latency penalty is real but manageable: CDN caches the shortCode-to-longUrl mapping at an edge node near the user, so the lookup is <1ms even though the request hits 'your infrastructure'."

> *End with the mitigation — showing you know the tradeoff has a solution signals senior-level thinking.*

**Gotcha follow-up:** *"What if the user deactivates a short URL — how quickly does the CDN cache invalidate?"*
> "Standard CDN caches respect Cache-Control headers. If I set `Cache-Control: max-age=60` on the 302 response, the CDN may serve the old mapping for up to 60 seconds after deactivation. For most URLs this is acceptable. For abuse cases — a URL serving malware that must be deactivated immediately — I issue a CDN cache purge API call as part of the deactivation flow. Most CDN providers (Cloudflare, Fastly) have a purge-by-tag or purge-by-URL API that propagates within seconds globally."

---

**Design**
**"How would you generate short codes without collisions at scale?"**

**One-line answer:** Use an atomic Redis INCR counter, then encode the integer to Base62 — every call gets a unique integer and no retry loop is ever needed.

**Full answer:**
> "There are three common approaches. Random generation picks a random 6-character alphanumeric code. Simple to implement, but collision probability grows as the database fills. At 50% capacity (28 billion URLs), roughly 1 in 2 random codes collides and you need retry loops. Hash-based generation takes MD5 or SHA256 of the long URL and uses the first 6 characters. Deterministic, but different long URLs can produce the same truncated prefix. Counter-based generation increments a global counter and encodes it to Base62 (the character set `[0-9a-zA-Z]`, 62 characters). The Redis INCR command is atomic — no two calls ever return the same value, even across distributed service instances. A 6-character Base62 code encodes integers up to 62^6, which is approximately 56.8 billion — enough for roughly 57 years at 1 billion URLs per year. I prefer counter-based because it eliminates retries entirely and the capacity math is simple to reason about."

> *Always walk through the capacity math — it shows you can validate your own design choices.*

**Gotcha follow-up:** *"Counter-based codes are sequential and enumerable — is that a security concern?"*
> "Yes, a sequential counter means an attacker can enumerate `aAAAAA`, `aAAAAB`, and so on to discover all URLs. Mitigations: shuffle the Base62 alphabet (use a private permutation of the 62 characters), or XOR-mask the counter with a secret key before encoding. Neither adds meaningful latency, and both make enumeration computationally infeasible without knowing the key. For truly sensitive links, use a longer random code (8+ characters) and accept the retry complexity."

---

**Scalability**
**"How would you scale the redirect path to 1 million requests per second?"**

**One-line answer:** Redis cache for sub-millisecond lookups, CDN in front of the redirect endpoint, read replicas for PostgreSQL, and stateless service instances behind a load balancer.

**Full answer:**
> "The redirect path is a pure read: given a short code, return a long URL. At 1 million RPS, the bottleneck is the lookup. Layer the solution. First layer: Redis cache. Popular short codes are requested millions of times per day. Cache the shortCode-to-longUrl mapping in Redis with a TTL matching the URL expiry. Cache hit rate exceeds 99% for popular links; Redis handles millions of reads per second with sub-millisecond latency. Second layer: CDN. Put a CDN (Cloudflare, Fastly) in front of the redirect endpoint. Cache the 302 response (with short max-age to preserve analytics freshness) at CDN edge nodes globally. For geographically distributed traffic, CDN reduces latency from 50-100ms to 1-5ms by serving from a nearby edge. Third layer: read replicas for PostgreSQL. Cache misses fall through to the database. With read replicas, multiple service instances can query different replicas simultaneously without overwhelming the primary. Fourth layer: horizontal scaling. The redirect service is stateless — it holds no in-process state, only reads from Redis and DB. Add instances behind a load balancer freely."

> *Name the layers in order — it shows you think in tiers, not just 'add Redis'.*

---

**Concurrency / Design**
**"How do you handle two users simultaneously trying to claim the same custom alias?"**

**One-line answer:** Use a database unique constraint on the shortCode column; the first INSERT wins, the second gets a unique violation and returns an error to the user.

**Full answer:**
> "Custom aliases are user-chosen short codes. Two users could both type `shr.ly/mycoollink` at the same moment. The naive approach — check if it exists, then insert — has a TOCTOU race: both threads check, both see it absent, both insert, one fails with a DB error in an unexpected code path. The correct approach skips the check entirely and relies on the database's unique constraint on the `short_code` column. Both threads issue `INSERT INTO short_urls (short_code, ...) VALUES ('mycoollink', ...)`. The database serializes the two inserts; the first succeeds, the second raises a unique constraint violation. In Java, this surfaces as a `DataIntegrityViolationException`. Catch it in the service layer and return a clean `AliasAlreadyTakenException` to the caller. This approach requires zero coordination between application threads and is safe under any level of concurrency."

> *The 'check then insert' antipattern is extremely common in interviews — calling it out by name lands well.*

---

> **Common Mistake — Choosing 301 for performance without considering analytics:** Candidates often pick 301 because "it's faster — the browser caches it." This is correct but kills click analytics entirely after the first redirect per browser. Always ask whether analytics is a requirement before choosing the redirect type. In a URL shortener, it almost always is.

---

**Quick Revision:** The core insight of a URL shortener is the 302-vs-301 decision: use 302 so every click reaches your server for analytics, mitigate the latency cost with CDN caching of the mapping lookup, and use Redis INCR + Base62 encoding for collision-free code generation at any scale.

---

---

## Topic 3: Rate Limiter — LLD Case Study

#### The Idea

Imagine your API is a restaurant kitchen. Customers (API callers) place orders continuously. Without any rules, a single customer could place a thousand orders per minute, monopolizing the kitchen and starving everyone else. A rate limiter is the maitre d' at the door: each customer gets a quota — say, 100 requests per minute — and once they hit it, they are politely asked to come back later (HTTP 429: Too Many Requests).

The interesting engineering is not the quota itself — it is making the check fast, accurate, and consistent when your API runs across dozens of servers. If each server tracks its own per-user counter independently, a user can hit 100 requests on each of your 10 servers, making 1,000 total requests and completely defeating the rate limiter. The check must be centralized. Redis is the standard answer for this: a single fast shared counter that all servers query. But then you face a new problem — what if Redis itself goes down?

There is also a subtle correctness challenge called the boundary attack. If your rate limiter resets its counter at the top of every minute, a clever user can send 100 requests at 11:59:59 and another 100 requests at 12:00:01, making 200 requests in two seconds without ever technically "exceeding" the per-minute limit. Choosing the right algorithm determines whether your rate limiter can be gamed this way — and most candidates pick the simplest algorithm without realizing the vulnerability.

---

#### How It Works

**Step 1: Requirements & Clarifying Questions**

| Functional Requirement | Description |
|---|---|
| FR-1 | Limit requests per user/IP in a configurable time window |
| FR-2 | Return HTTP 429 + `Retry-After` header when limit exceeded |
| FR-3 | Per-user, per-IP, and per-API-key limiting supported |
| FR-4 | Multiple algorithms selectable per endpoint |
| FR-5 | Different limits per endpoint or user tier |
| FR-6 | Return `X-RateLimit-Remaining` and `X-RateLimit-Reset` headers |

**Clarifying questions to ask in an interview:**

1. *What is the granularity of limits — per second, per minute, per hour?* — Per-second limits require very low-latency counters (Redis mandatory); per-hour limits are more forgiving and could even be database-backed. Determines the performance requirements.
2. *Should burst traffic be tolerated, or must the rate be strictly smooth?* — Burst tolerance → Token Bucket. Strict smoothing → Leaky Bucket. These are architecturally distinct algorithms.
3. *What is the failure mode when the rate limiter's backing store (Redis) is unavailable — fail-open (allow all) or fail-closed (deny all)?* — Fail-open keeps the API available but unprotected; fail-closed keeps the API protected but breaks it for all users. This is a product decision, not a technical one.
4. *Do rate limits apply per individual endpoint or globally per user?* — Per-endpoint limits (payment API: 10/min, search API: 200/min) require a composite key; global limits are simpler. Knowing this early determines the key structure.

---

**Step 2: Core Entities**

```
RateLimiter (interface)
  ├── TokenBucketRateLimiter
  ├── SlidingWindowCounterRateLimiter
  ├── FixedWindowRateLimiter
  └── SlidingWindowLogRateLimiter

RateLimitConfig
  ├── capacity (max tokens / max requests)
  ├── refillRate (tokens per second) or windowSizeMs
  ├── algorithm: RateLimitAlgorithm enum
  └── scope: USER, IP, API_KEY

RateLimitResult
  ├── allowed: boolean
  ├── remaining: int
  └── resetAt: Instant

RateLimiterFactory
  └── creates RateLimiter from RateLimitConfig

RateLimitFilter (Servlet Filter / Spring Interceptor)
  └── intercepts requests, calls RateLimiter, sets response headers
```

- **RateLimiter** is an interface (not a class) because different algorithms have fundamentally different state — Token Bucket tracks token count and last refill time; Sliding Window Log tracks a sorted set of timestamps. A single class cannot represent both cleanly.
- **RateLimitConfig** is separate from RateLimiter because configuration is data — it can be stored in a database, loaded from a config file, and changed at runtime — while RateLimiter is behavior. Mixing them would make runtime config changes impossible.
- **RateLimitResult** is a value object rather than a boolean because callers need remaining count and reset time for response headers (`X-RateLimit-Remaining`, `X-RateLimit-Reset`), not just the allow/deny decision.
- **RateLimitFilter** is separate from RateLimiter because it handles cross-cutting concerns: key extraction (from JWT, IP, API key header), header setting, and failure mode. RateLimiter implementations stay pure: take a key and config, return a result.

---

**Step 3: Design Decisions**

**Decision: Token Bucket as the default algorithm for general-purpose APIs**
*Why this over the alternatives:* Fixed Window Counter is the simplest — increment a counter per minute, reset at boundary. But it is vulnerable to the boundary attack: 100 requests in the last second of minute N, then 100 requests in the first second of minute N+1 = 200 requests in 2 seconds. Sliding Window Log is perfectly accurate — store every request timestamp, count those within the rolling window — but uses O(requests-in-window) memory, which is expensive at high QPS. Token Bucket fills the gap: each user has a bucket that holds up to `capacity` tokens, refilled at `refillRate` tokens per second. Burst traffic uses saved tokens; sustained traffic is limited to the refill rate. No boundary vulnerability, O(1) memory (just store token count and last refill timestamp), and burst tolerance is usually the right behavior for API clients.
*Tradeoff:* Token Bucket requires fractional token bookkeeping: if `refillRate = 10/sec` and 300ms has elapsed, the bucket refills by exactly 3 tokens. This requires storing the last-refill timestamp alongside the token count and doing floating-point math in the Lua script. Slightly more complex than a fixed counter, but manageable.

**Decision: Lua script in Redis for atomic token check-and-decrement**
*Why this over the alternatives:* The Token Bucket check requires multiple Redis operations: GET the current token count, calculate how many tokens to add (based on elapsed time), SET the new count, and return the result. If two requests execute these operations concurrently, both can GET the same count, both add tokens, and both decrement — the decrement effectively happens once, not twice. This is a race condition that allows 2× the intended requests through. We could use a Redis distributed lock (SETNX + EXPIRE) around the multi-step operation, but distributed locks add two extra round trips (acquire + release) and a risk of lock contention under high load. A Lua script is a better solution: Redis is single-threaded, and a Lua script executes atomically — no other command can interleave while the script runs. The entire check-add-decrement completes in one atomic operation with one network round trip.
*Tradeoff:* Lua scripts are harder to debug and test than application code. Logic errors in the script require careful Redis unit testing. Also, Lua scripts cannot be directly profiled with standard Java tooling — you need Redis SLOWLOG to detect performance issues in the script.

**Decision: Redis for shared rate limit state across distributed instances**
*Why this over the alternatives:* If each service instance maintains its own in-memory token bucket per user, a user with 100 requests/minute limit hitting a load-balanced cluster of 5 instances can send 100 requests to each instance — 500 total — without any single instance noticing a violation. In-memory per-instance state is fundamentally incompatible with horizontal scaling. Redis provides a single centralized counter accessible to all instances simultaneously. Every token check and decrement goes through Redis, so the limit is enforced globally regardless of which instance receives the request.
*Tradeoff:* Every rate limit check adds a Redis round trip: typically 1-2ms in a co-located setup. At 100,000 RPS, that is 100,000 Redis operations per second — Redis handles this easily (it supports millions of operations per second), but the latency adds up if Redis is geographically distant. Solution: deploy Redis in the same availability zone as the API servers.

**Decision: Composite Redis key structure: `ratelimit:{userId}:{endpoint}`**
*Why this over the alternatives:* A key structure of `ratelimit:{userId}` enforces a single global limit per user across all endpoints. This prevents "payment API gets 10 requests while the user can still hammer search API" — they share one bucket. But conflating all endpoints also means a search-heavy user consumes quota needed for payment calls. A composite key `ratelimit:{userId}:{endpoint}` allows independent limits per endpoint: payment endpoint at 10/min, search at 200/min, with separate buckets. The rate limit filter resolves the applicable config by looking up `(endpoint, userTier)` in a config table, falls back to a global per-user config if no endpoint-specific rule exists.
*Tradeoff:* More Redis keys per user (one per endpoint per user rather than one per user). At 10 endpoints × 1 million users = 10 million Redis keys. Each key is a few dozen bytes — well within Redis's capacity. The operational complexity of managing endpoint-specific configs is real but necessary for fine-grained control.

**Decision: Fail-open for non-critical APIs when Redis is unavailable**
*Why this over the alternatives:* When Redis is unreachable, the rate limiter cannot make a correct decision. Two options: fail-open (allow all requests as if the limiter does not exist) or fail-closed (deny all requests with HTTP 503). Fail-open prioritizes API availability — users experience no degradation during a Redis outage, but the API is temporarily unprotected from abuse. Fail-closed prioritizes protection — abusive traffic is blocked, but legitimate users also get 503s. The right choice depends on what the rate limiter protects. A public search API → fail-open (a few minutes of unprotected traffic is not dangerous). A payment API where rate limiting is a fraud control → fail-closed (a Redis outage that allows unlimited payment calls is a security incident). Wrap the Redis check in a Resilience4j circuit breaker so the limiter detects Redis failure within milliseconds and triggers the fallback, rather than timing out on every request.
*Tradeoff:* Fail-open means the rate limiter provides zero protection during outages. Fail-closed means legitimate users experience failures during Redis outages. There is no risk-free option — the product team must decide which failure mode is less harmful.

---

**Step 4: Key Algorithm (pseudocode)**

```
-- Lua script running inside Redis (executes atomically)
-- KEYS[1] = rate limit key (e.g., "ratelimit:user123:search")
-- ARGV[1] = current timestamp in milliseconds
-- ARGV[2] = bucket capacity (max tokens)
-- ARGV[3] = refill rate (tokens per millisecond)

local key = KEYS[1]
local now = tonumber(ARGV[1])
local capacity = tonumber(ARGV[2])
local refillRate = tonumber(ARGV[3])

local data = redis.call('HMGET', key, 'tokens', 'lastRefill')

local tokens = tonumber(data[1]) or capacity  -- default full bucket on first call
local lastRefill = tonumber(data[2]) or now

-- Calculate tokens earned since last request
local elapsed = now - lastRefill
local earned = elapsed * refillRate
tokens = math.min(capacity, tokens + earned)  -- cap at capacity

local allowed = false
local remaining = math.floor(tokens)

if tokens >= 1 then
    tokens = tokens - 1
    remaining = math.floor(tokens)
    allowed = true
end

-- Persist updated state; TTL = capacity / refillRate * 2 (auto-expire idle keys)
redis.call('HMSET', key, 'tokens', tokens, 'lastRefill', now)
redis.call('PEXPIRE', key, math.ceil(capacity / refillRate * 2000))

return {allowed and 1 or 0, remaining}
```

---

**Step 5: Must-Know Code**

```java
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private final RedisTemplate<String, String> redis;
    private final RateLimitConfigResolver configResolver;
    
    // Load the Lua script once at startup; Redis caches it by SHA hash.
    // Repeated EVAL with the same script text has Redis re-parse it every time.
    // EVALSHA with the cached SHA is faster and the standard production pattern.
    private final DefaultRedisScript<List> rateLimitScript;

    public RateLimitFilter(RedisTemplate<String, String> redis,
                           RateLimitConfigResolver configResolver) {
        this.redis = redis;
        this.configResolver = configResolver;
        this.rateLimitScript = new DefaultRedisScript<>();
        this.rateLimitScript.setScriptText(loadLuaScript()); // reads from classpath
        this.rateLimitScript.setResultType(List.class);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        
        String userId = extractUserId(request); // from JWT or session
        String endpoint = request.getRequestURI();
        RateLimitConfig config = configResolver.resolve(userId, endpoint);

        // Composite key: per-user per-endpoint. Allows different limits per endpoint.
        String redisKey = "ratelimit:" + userId + ":" + endpoint;

        try {
            List<Long> result = redis.execute(
                rateLimitScript,
                Collections.singletonList(redisKey),
                String.valueOf(System.currentTimeMillis()),
                String.valueOf(config.getCapacity()),
                String.valueOf(config.getRefillRatePerMs())
            );

            boolean allowed = result.get(0) == 1L;
            long remaining = result.get(1);

            // Always set rate limit headers so clients know their quota status
            response.setHeader("X-RateLimit-Remaining", String.valueOf(remaining));
            response.setHeader("X-RateLimit-Limit", String.valueOf(config.getCapacity()));

            if (!allowed) {
                // Retry-After tells the client how long to wait before retrying.
                // Without this, clients retry immediately and amplify load.
                response.setHeader("Retry-After", String.valueOf(config.getRetryAfterSeconds()));
                response.sendError(HttpStatus.TOO_MANY_REQUESTS.value(), "Rate limit exceeded");
                return; // do NOT call chain.doFilter — request is rejected
            }

        } catch (Exception e) {
            // Redis is unavailable. Fail-open: log the error but let the request through.
            // For payment APIs, change this to: response.sendError(503) — fail-closed.
            log.error("Rate limiter Redis unavailable, failing open", e);
            // Fall through to chain.doFilter
        }

        chain.doFilter(request, response);
    }
}
```

---

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: In case study questions, structure your answer as: "The key challenge is X. I chose Y over Z because [reason]. The tradeoff is [cost]." This signals senior-level thinking.*

---

**Concurrency / Correctness**
**"Why do you need a Lua script for the Redis token bucket? Why not just use regular Redis commands?"**

**One-line answer:** Multiple Redis commands are not atomic — two concurrent requests can both read the same token count, both pass the check, and both decrement, allowing 2× the intended throughput; a Lua script runs atomically on Redis's single thread, eliminating the race.

**Full answer:**
> "The token bucket check requires multiple steps: read the current token count, calculate tokens earned since the last refill, add them (capped at capacity), check if there is at least one token, decrement if yes, and write back the new state. If two requests run these steps concurrently using separate Redis GET and SET commands, both can read the same starting count — say, 1 token remaining — both see it as allowed, both decrement, and you end up with -1 tokens and both requests passed. Your rate limit is effectively 2×. You could solve this with a Redis distributed lock: SETNX to acquire, do the multi-step logic, DEL to release. But distributed locks add two extra round trips (acquire + release) per request and introduce lock contention under high load. The Lua script is better: Redis executes it as a single atomic unit on its single thread. No other command can interleave. No lock needed. One network round trip for the entire check-and-decrement. This is the standard production pattern for Redis rate limiters."

> *Name the race condition explicitly — 'TOCTOU' or 'read-modify-write race' — before giving the solution.*

**Gotcha follow-up:** *"What if the Lua script has a bug that causes an infinite loop?"*
> "Redis has a script execution timeout (`lua-time-limit`, default 5 seconds). If a script runs longer than this, Redis returns a BUSY error to callers and accepts only SCRIPT KILL or SHUTDOWN NOSAVE commands. The defense is keeping Lua scripts simple and thoroughly tested in a staging environment. For a token bucket script that is 10-15 lines of arithmetic, an infinite loop is not a realistic risk, but the timeout is the safety net."

---

**Algorithm**
**"When would you use Sliding Window Log over Token Bucket for a rate limiter?"**

**One-line answer:** When you need perfect accuracy with no boundary vulnerabilities and the endpoint is low-volume enough that per-request timestamp storage is affordable — like a payment API.

**Full answer:**
> "Token Bucket is great for most APIs: burst-tolerant, O(1) memory, no boundary attack. But it has approximation: the refill calculation uses elapsed time since last refill, so brief bursts can still exceed the window-average rate. For a payment API where the rate limit is a fraud control, even a brief burst of unauthorized transactions is unacceptable. Sliding Window Log stores every request timestamp in a Redis sorted set. On each request: add current timestamp, remove entries older than the window, count remaining entries. If count < limit, allow and the set now has the new entry; if count >= limit, reject. This is perfectly accurate — no approximation, no boundary vulnerability. The cost is memory: a user sending 1,000 requests per minute stores 1,000 timestamps in Redis. For a payment API allowing 10 requests per minute, the set has at most 10 entries — negligible. The memory cost only becomes a concern at high volume, which is exactly when you would not use Sliding Window Log anyway."

> *Anchor the algorithm choice to a concrete endpoint type — payment APIs vs. search APIs. Interviewers want judgment, not a textbook comparison.*

**Gotcha follow-up:** *"What is the boundary attack on Fixed Window Counter and how does Token Bucket avoid it?"*
> "Fixed Window Counter resets at clock boundaries — say, the top of every minute. An attacker sends 100 requests at 11:59:55 (within limit) and another 100 at 12:00:05 (new window, counter reset to 0). In a 10-second window straddling midnight they sent 200 requests — 2× the limit — without triggering a violation. Token Bucket avoids this because there is no reset. The bucket refills continuously at a constant rate. To send 200 requests quickly, you need 200 tokens saved up, which takes 200 ÷ refillRate seconds to accumulate. There is no 'window boundary' to exploit."

---

**Architecture**
**"How do you implement different rate limits for Free vs. Pro users?"**

**One-line answer:** Resolve the user's tier from their JWT, look up the tier-specific RateLimitConfig from a config store, and pass capacity and refill rate as parameters to the Lua script — the same Redis key structure works for all tiers.

**Full answer:**
> "The rate limit filter extracts the user ID from the JWT on every request. A `RateLimitConfigResolver` takes the user ID and endpoint, looks up the user's tier (from the JWT claim or a cached user-service call), and returns the appropriate RateLimitConfig: Free tier gets `capacity=100, refillRate=100/hour`; Pro tier gets `capacity=10000, refillRate=10000/hour`. These config values are passed as arguments to the Lua script — the script itself does not know about tiers, it just does arithmetic on capacity and rate. The Redis key remains `ratelimit:{userId}:{endpoint}` regardless of tier, so no key structure change is needed when a user upgrades from Free to Pro. The only change is the config values passed to the script on the next request — the new, higher capacity takes effect immediately."

> *Emphasize that the algorithm is tier-agnostic — tiers are resolved in the application layer, not baked into Redis scripts. This shows clean separation of concerns.*

**Gotcha follow-up:** *"If a user upgrades from Free to Pro mid-day, when does the new limit take effect?"*
> "If the JWT contains the tier claim and is re-issued on upgrade, the new config takes effect on the next request. If you cache the user-tier lookup (to avoid a user-service call on every request), invalidate the cache entry on upgrade. For the Redis token bucket state itself: when the config changes, the existing bucket state (e.g., 80 tokens remaining at the Free capacity of 100) is still valid. The Lua script enforces the new capacity going forward — tokens will now refill toward 10,000 rather than 100. No manual Redis key cleanup needed."

---

**Failure Handling**
**"What happens to your rate limiter when Redis goes down?"**

**One-line answer:** Decide per API: fail-open (allow all traffic, lose protection) for availability-critical APIs, or fail-closed (return 503) for security-critical APIs; wrap Redis calls in a circuit breaker so the fallback triggers in milliseconds, not after a timeout.

**Full answer:**
> "When Redis is unreachable, the rate limiter cannot check or update the token count. Every request's Redis call would time out, adding seconds of latency before the failure mode kicks in. The fix for the latency part is a Resilience4j circuit breaker around the Redis call: after a configurable number of failures (e.g., 5 in 10 seconds), the circuit opens and the fallback triggers immediately without waiting for a Redis timeout. For the fallback itself, the choice is product-driven. Fail-open: log the Redis failure, allow the request through. The API remains available; rate limiting is temporarily suspended. Correct for a public search or read API where a few minutes of unprotected traffic is not dangerous. Fail-closed: return HTTP 503 Service Unavailable. The API is unavailable during the Redis outage, but malicious traffic is also blocked. Correct for a payment or authentication API where unprotected traffic is a fraud or security risk. An intermediate option: in-memory per-instance fallback with much stricter limits (e.g., 10% of normal quota). This provides degraded protection without full outage."

> *Framing this as a product decision, not just a technical one, is the signal of a senior engineer. The interviewer expects you to ask what the API does before recommending fail-open or fail-closed.*

---

> **Common Mistake — Fixed Window Counter without acknowledging the boundary attack:** Many candidates implement Fixed Window Counter because it is the simplest — increment a counter per time window, reset at the boundary. This is acceptable if acknowledged with the caveat that it is vulnerable to the boundary attack (2× burst at window edges). The mistake is proposing it as a complete solution without mentioning the vulnerability. If the interviewer asks "is this accurate?", the correct answer is "no — a user can send 2× the limit by splitting requests across a window boundary; if that matters, use Sliding Window Counter (approximate, O(1)) or Token Bucket."

---

**Quick Revision:** The core insight of a Rate Limiter LLD is that the check-and-decrement must be atomic — use a Lua script in Redis so concurrent requests cannot race past the limit — and the failure mode when Redis is unavailable is a product decision (fail-open for availability, fail-closed for security) that must be made before you write any code.

---

## Topic 4: BookMyShow — Movie Ticket Booking System — LLD Case Study

#### The Idea

Think about what happens when a blockbuster releases and a million people try to buy tickets at 8 AM. Two friends, sitting side by side, both open the app and both tap on seat A1. Without careful design, they could both complete their purchase and arrive at the cinema to find someone else already sitting there. This is the core challenge: a seat can only be sold once, but the internet makes it trivially easy for thousands of people to try to claim the same thing at the same moment.

The second hard problem is abandonment. You have probably held seats in your cart, gone to enter payment details, and then gotten distracted. Those seats are now frozen for everyone else. If the system never releases them, every popular show would appear fully booked within minutes, with most of those "bookings" never actually paid. The system needs a way to automatically reclaim seats that were held but never purchased.

The third challenge is scale under read pressure. When a show goes live, thousands of users are constantly refreshing the seat map to see which seats are still available. If each refresh hits the database, you have a query storm on a table that is changing constantly. This system sits at the intersection of consistency (no double bookings), availability (the seat map must load fast), and time-bounded locks (abandoned carts must expire).

#### How It Works

**Step 1: Requirements & Clarifying Questions**

Functional requirements:
- Search movies by city, date, genre, and language
- Browse theatres, shows, and available seats on a visual map
- Select seats (Silver / Gold / Platinum tiers) and book them
- Process payment via Credit Card, UPI, or Wallet
- Receive booking confirmation by Email, SMS, or Push
- Cancel a booking and receive a refund

Non-functional requirements:
- Support 1,000+ concurrent users booking the same show
- A seat must never be double-booked
- Seat locks expire automatically after 10 minutes if payment is abandoned
- Sub-second seat availability queries

Clarifying questions:

1. **Can a user book multiple seats in one transaction?** Yes — this matters because the atomicity requirement expands: all seats must be locked together or the entire attempt must fail. Partial locks (some seats locked, others taken by a race) are not acceptable.

2. **What happens if payment fails after seats are locked?** Seats return to AVAILABLE and the booking is marked EXPIRED. This defines the lifecycle states we need and tells us the lock-expiry mechanism is critical, not optional.

3. **How long should a seat lock last?** 10 minutes. This sets the TTL for the expiry job and determines the user-facing countdown timer on the payment page.

4. **Is seat availability displayed in real time or near-real time?** Near-real time (a few seconds of staleness is acceptable). This unlocks the use of a cache layer — if strict real-time were required, we would need WebSocket push instead of polling.

5. **Should we support waiting lists for sold-out shows?** No (out of scope for this interview). This keeps the seat state machine simpler: no WAITLISTED state.

---

**Step 2: Core Entities**

```
Movie ──< Show >── Screen ── Theatre
                      │
                   ShowSeat  (Silver/Gold/Platinum, @Version for optimistic lock)
                      │
Booking ──> BookingSeat ──> ShowSeat
   │
Payment
   │
User
```

- **Movie**: stores title, genre, language, duration. Exists separately because the same film plays at many theatres and times.
- **Show**: a specific screening of a Movie at a Screen on a date/time. The join point between content (Movie) and logistics (Screen).
- **Screen**: a physical auditorium inside a Theatre. Defines the seat layout once; ShowSeats are generated per Show.
- **ShowSeat**: represents one physical seat for one specific Show. This is the most important entity — it holds the booking status and the optimistic lock version. It must be per-Show (not per-Screen) because the same seat can be AVAILABLE for Tuesday's show and BOOKED for Wednesday's.
- **Booking**: tracks the user's overall reservation (PENDING → CONFIRMED → CANCELLED / EXPIRED) and has an `expiresAt = createdAt + 10 min`.
- **BookingSeat**: join table between Booking and ShowSeat. Exists separately so one Booking can cover multiple seats.
- **Payment**: tracks method, status, and transaction ID. Separate from Booking because payment processing is an external concern (PSP integration) with its own lifecycle.

---

**Step 3: Design Decisions**

**Decision: Optimistic locking via `@Version` to prevent double-booking**
*Why this over the alternatives:* The naive approach reads seat status, checks AVAILABLE, then writes LOCKED as two separate operations. Between the read and the write, another thread can do the same read and also see AVAILABLE — both threads then write LOCKED and both believe they succeeded (a classic Time-of-Check / Time-of-Use race). Pessimistic locking (`SELECT FOR UPDATE`) fixes this by holding a row-level DB lock for the entire transaction, but with 1,000 concurrent users on the same seat, every request queues behind the one holding the lock: DB connection pool exhaustion, thread starvation, cascading timeouts. Optimistic locking adds zero overhead when there is no contention (the common case — most users are looking at different seats). When two users race on the same seat, JPA checks the version at commit time: the first writer increments version from 5 to 6; the second writer's `UPDATE ... WHERE version=5` matches zero rows, JPA throws `ObjectOptimisticLockingFailureException`, and Spring rolls back the transaction cleanly.
*Tradeoff:* The losing user must be told to retry or pick a different seat. This is the right trade — a rare retry is far better than serializing every booking request.

**Decision: Scheduled expiry job to release abandoned seat locks**
*Why this over the alternatives:* A database row with status LOCKED has no self-expiry mechanism — TTL is a cache concept (Redis), not a relational DB concept. A TTL column in an in-memory cache cannot be the authoritative state because caches can evict entries or restart. The DB is the source of truth. A scheduled job (`@Scheduled(fixedDelay = 60_000)`) that queries `WHERE status = LOCKED AND lockedAt < NOW() - 10 minutes` is simple, auditable (every expiry is a logged DB write), and requires no additional infrastructure.
*Tradeoff:* Seats may stay locked for up to 10 minutes and 60 seconds (job interval) instead of exactly 10 minutes. This is an acceptable approximation — users are not harmed by a 60-second overrun, and simplicity is worth more than precision here.

**Decision: Cache the seat map with a 5-second TTL, evict on every state change**
*Why this over the alternatives:* Every page load fetching all seat statuses for a show performs a full table scan on the ShowSeat table. Under high traffic, this is a query storm — thousands of identical reads hitting the DB simultaneously. Caching with `@Cacheable("showSeats")` absorbs the reads. The TTL of 5 seconds is deliberately short because seat availability changes rapidly during peak booking windows. A longer TTL (say, 60 seconds) means users see stale data, attempt to book already-locked seats, and get unnecessary optimistic lock failures. `@CacheEvict` on every booking and lock operation ensures the cache is invalidated immediately on writes.
*Tradeoff:* Users may see a seat as AVAILABLE for up to 5 seconds after it was locked by someone else, leading to a slightly higher rate of optimistic lock conflicts. This is the correct trade — sub-second queries at scale matter more than perfect freshness.

**Decision: Observer pattern (ApplicationEventPublisher) for post-booking notifications**
*Why this over the alternatives:* After a booking is confirmed, the service needs to send an email, an SMS, and a push notification. If `BookingService.confirmBooking()` directly calls `EmailService`, `SmsService`, and `PushService`, it is coupled to all three. Adding a WhatsApp channel requires modifying `BookingService`. The Observer pattern decouples the publisher from its subscribers: `BookingService` publishes a `BookingConfirmedEvent`; `EmailNotificationListener`, `SmsNotificationListener`, and `PushNotificationListener` each subscribe independently.
*Tradeoff:* The flow of control is less obvious — you cannot find all post-booking side effects by reading `BookingService` alone. Debugging notification failures requires checking listener registrations.

**Decision: Strategy pattern for payment methods**
*Why this over the alternatives:* Without Strategy, `PaymentService` contains `if (method == CREDIT_CARD) { ... } else if (method == UPI) { ... }` — a block that grows with every new payment provider. Strategy pattern defines a `PaymentStrategy` interface; `CreditCardPaymentStrategy`, `UpiPaymentStrategy`, and `WalletPaymentStrategy` implement it. Spring auto-discovers them as `@Component` beans, and `PaymentService` holds a `Map<PaymentMethod, PaymentStrategy>` populated at startup.
*Tradeoff:* Adds a layer of indirection — tracing a payment flow requires knowing which concrete strategy is in the map.

**Decision: Factory pattern for notification channels**
*Why this over the alternatives:* When new notification channels are added (WhatsApp, in-app), calling code should not need to change. `NotificationFactory` holds a `Map<String, NotificationChannel>` populated automatically by Spring bean names. Calling code invokes `factory.getChannel("EMAIL")` without depending on the concrete implementation.
*Tradeoff:* Convention-based (bean names as channel keys) — mistyping a channel name fails at runtime, not compile time.

---

**Step 4: Key Algorithm (pseudocode)**

```
LOCK SEATS AND CREATE BOOKING:

function createBooking(userId, showId, seatIds):
    seats = loadSeatsWithOptimisticLock(showId, seatIds)

    unavailable = seats where status != AVAILABLE
    if unavailable is not empty:
        throw SeatsUnavailableException

    for each seat in seats:
        seat.status = LOCKED
        seat.lockedAt = now()
    save all seats
    // At commit: JPA checks version on each seat.
    // If any version mismatch → ObjectOptimisticLockingFailureException → rollback.

    booking = new Booking(userId, showId, status=PENDING, expiresAt=now()+10min)
    for each seat: create BookingSeat(booking, seat)
    save booking

    return booking

EXPIRY JOB (runs every 60 seconds):

function expireAbandonedLocks():
    expiredSeats = query ShowSeat where status=LOCKED and lockedAt < now()-10min
    for each seat: seat.status = AVAILABLE
    save all expired seats

    expiredBookings = query Booking where status=PENDING and expiresAt < now()
    for each booking: booking.status = EXPIRED
    save all expired bookings

CONFIRM BOOKING (after payment success):

function confirmBooking(bookingId, paymentDetails):
    booking = load(bookingId)
    if booking.expiresAt < now(): throw BookingExpiredException

    payment = processPayment(paymentDetails)   // call PSP
    if payment fails: releaseSeats(booking); throw PaymentFailedException

    for each seat in booking: seat.status = BOOKED
    booking.status = CONFIRMED
    save all

    publish BookingConfirmedEvent(booking)   // async: email + SMS + push
```

---

**Step 5: Must-Know Code**

```java
// ShowSeat entity — the @Version field is the entire anti-double-booking mechanism.
@Entity
public class ShowSeat {
    @Id private Long id;

    @Version
    private Long version;  // JPA increments this on every UPDATE.
                           // Two concurrent updates with the same version → only one wins.

    private SeatStatus status;   // AVAILABLE | LOCKED | BOOKED
    private LocalDateTime lockedAt;
    // ... tier, seatNumber, etc.
}

// In BookingService — the critical section:
@Transactional
public Booking createBooking(Long userId, Long showId, List<Long> seatIds) {

    // Load with OPTIMISTIC lock mode — tells JPA to verify version at commit time.
    List<ShowSeat> seats = showSeatRepo.findByShowIdAndIdInWithLock(showId, seatIds);

    // Validate ALL seats before mutating ANY — all-or-nothing semantics.
    List<ShowSeat> unavailable = seats.stream()
        .filter(s -> s.getStatus() != SeatStatus.AVAILABLE).toList();
    if (!unavailable.isEmpty()) throw new SeatsUnavailableException(unavailable);

    // Mutate — the version check happens at transaction commit, not here.
    seats.forEach(s -> {
        s.setStatus(SeatStatus.LOCKED);
        s.setLockedAt(LocalDateTime.now());
    });
    showSeatRepo.saveAll(seats);
    // If another transaction already updated a seat's version:
    //   JPA throws ObjectOptimisticLockingFailureException → Spring rolls back.

    Booking booking = new Booking(userId, showId, BookingStatus.PENDING,
                                  LocalDateTime.now().plusMinutes(10));
    seats.forEach(seat -> booking.addSeat(new BookingSeat(booking, seat)));
    return bookingRepo.save(booking);
}

// Global exception handler — translate the JPA exception into an HTTP 409.
@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(ObjectOptimisticLockingFailureException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public Map<String, String> handleOptimisticLock(ObjectOptimisticLockingFailureException ex) {
        // Return a user-friendly message — the client should prompt the user to re-select seats.
        return Map.of("error", "One or more seats were just taken. Please try again.");
    }
}
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained. Every concept explained inline.

> *Tip: Structure answers as: "The key challenge is X. I chose Y over Z because [reason]. The tradeoff is [cost]."*

---

**Concept Check — Concurrency**
**"How do you handle 1,000 concurrent users trying to book the same seat?"**

**One-line answer:** Optimistic locking with `@Version` — the first writer wins; all others get a conflict error and are told to retry.

**Full answer:**
> "The key challenge is that read-then-write is not atomic. If I read the seat status as AVAILABLE and then write LOCKED as two separate DB operations, two threads can both read AVAILABLE before either writes, and both will think they succeeded. The fix is `@Version` on the ShowSeat entity. Every UPDATE includes a `WHERE version = ?` clause. The first writer increments the version from 5 to 6; every other writer's update matches zero rows, and JPA throws `ObjectOptimisticLockingFailureException`. I catch that in a `@RestControllerAdvice` and return an HTTP 409 with a message asking the user to re-select. I chose optimistic over pessimistic (`SELECT FOR UPDATE`) because pessimistic locking serializes all 1,000 requests through a single DB row lock — connection pool exhaustion, thread starvation. Optimistic locking has zero overhead in the common case where two users are not racing on the exact same seat at the exact same millisecond."

> *Lead with the race condition problem, then explain why the version field fixes it atomically.*

**Gotcha follow-up:** *"When would you use pessimistic locking instead?"*
> "For flash sales or extremely high-contention scenarios — like a single item in a limited inventory drop where nearly every request is competing on the same resource. In those cases, optimistic locking generates so many retries that it actually hurts throughput. `SELECT FOR UPDATE` serializes the requests but eliminates wasted work from failed retries. The tradeoff is lower throughput and the risk of deadlocks if multiple rows are locked in inconsistent order."

---

**Tradeoff Question — Seat Expiry**
**"How do you prevent seats from being locked forever when a user abandons the payment?"**

**One-line answer:** A scheduled job runs every 60 seconds and resets any seat locked more than 10 minutes ago back to AVAILABLE.

**Full answer:**
> "The temptation is to use a TTL, but TTL is a cache concept — it does not apply to rows in a relational database. The database is my authoritative state, so I need the expiry to happen there. I use a `@Scheduled(fixedDelay = 60_000)` job that queries `WHERE status = LOCKED AND lockedAt < NOW() - 10 minutes` and resets those seats to AVAILABLE, then marks the associated Bookings as EXPIRED. This is simple, auditable, and requires no extra infrastructure. The tradeoff is imprecision — seats can be locked for up to 10 minutes and 60 seconds instead of exactly 10 minutes. That is acceptable here. If I needed exact expiry, I could push seat IDs into a Redis sorted set keyed by expiry timestamp and have a consumer pop entries when they expire — but that adds Redis as a hard dependency for correctness, which is overkill for a 60-second tolerance."

> *Interviewers like hearing you rule out the wrong approach (TTL) before explaining the right one.*

---

**Design Scenario — Notifications**
**"How would you design the post-booking notification system so it does not slow down the booking transaction?"**

**One-line answer:** Publish a `BookingConfirmedEvent` after the transaction commits; listeners handle email, SMS, and push asynchronously.

**Full answer:**
> "The booking transaction itself — locking seats, recording payment, updating status — should complete and return a response to the user as fast as possible. Sending an email synchronously inside that transaction would add hundreds of milliseconds and make the booking fail if the email service is down. I use Spring's `ApplicationEventPublisher` to publish a `BookingConfirmedEvent` after the transaction commits. Separate `@EventListener` beans handle email, SMS, and push notifications independently and asynchronously. The core benefit is decoupling: adding a WhatsApp notification requires a new listener class, zero changes to `BookingService`. The tradeoff is that the flow of control is less visible — you cannot trace all post-booking effects by reading `BookingService` alone."

> *Always frame async design around: what fails if this is synchronous, and what is the failure mode if the async step fails.*

**Gotcha follow-up:** *"What happens if the async email listener throws an exception?"*
> "By default, a Spring `@EventListener` failure does not affect the caller because the event was already published after the transaction committed. The booking is confirmed; only the notification fails. I would add retry logic — either Spring Retry with exponential backoff on the listener, or a dead-letter queue pattern where failed notification jobs are persisted and retried by a separate job. The booking confirmation should never be rolled back because a notification email failed."

---

**Tradeoff Question — Caching**
**"How do you serve the seat map quickly when thousands of users are loading it simultaneously?"**

**One-line answer:** Cache seat availability with `@Cacheable` and a 5-second TTL; evict on every booking or lock change.

**Full answer:**
> "Without caching, every seat map load is a query on the ShowSeat table filtered by showId. During a popular release, you get thousands of identical queries per second — a read storm. `@Cacheable('showSeats')` puts the result in memory (or Redis for a distributed deployment). I use a 5-second TTL rather than a longer one because seat availability changes rapidly during peak booking. If I used 60 seconds, users would try to book seats that have been locked for the past minute and hit unnecessary optimistic lock conflicts. `@CacheEvict` on every booking mutation keeps the cache reasonably fresh. For even higher scale, I would push seat changes over WebSocket to all connected browsers, eliminating polling entirely — but that adds significant infrastructure complexity."

> *Show you understand the tradeoff between cache freshness and query volume.*

---

> **Common Mistake — Using `double` or `float` for prices:** Ticket prices and payment amounts stored as `double` will accumulate floating-point rounding errors (IEEE 754 cannot represent 0.1 exactly). Use `BigDecimal` for all monetary values and `DECIMAL(10,2)` in the database schema — a wrong price on a payment confirmation is a serious production bug.

---

**Quick Revision:** The entire correctness of BookMyShow rests on one field — `@Version` on ShowSeat — which turns a read-then-write race condition into an atomic compare-and-swap at the database level.

---

## Topic 5: Splitwise — Expense Sharing System — LLD Case Study

#### The Idea

Imagine you go on a trip with five friends. One person pays for the hotel, another for dinner, a third for the rental car. By the end of the trip, you have a tangle of debts: Alice owes Bob, Bob owes Carol, Carol owes Alice, and Dave owes everyone a little bit. If everyone settled individually, you might need eight or nine separate bank transfers. Splitwise's core insight is that you can collapse all of those debts into a much smaller set of transfers that net to the same result.

That is the interesting design problem: given an arbitrary graph of who-owes-whom, find the minimum number of transactions that clears all debts. This turns out to be solvable with a greedy algorithm using two priority queues, and it is a favourite interview question because it sits at the intersection of financial correctness, data modelling, and algorithm design.

The second non-obvious challenge is money arithmetic. Splitting $10 three ways gives $3.333... You have to decide how to handle the rounding remainder (one person pays $3.34 instead of $3.33), and you must use exact-precision arithmetic (`BigDecimal`) throughout — IEEE 754 floating point cannot represent fractions like 0.1 exactly, and rounding errors compound across hundreds of expenses.

#### How It Works

**Step 1: Requirements & Clarifying Questions**

Functional requirements:
- Create groups and add members
- Add an expense: one person paid, split among some or all members
- Split types: Equal, Exact amount, Percentage, Shares
- View net balance: who owes whom, how much
- Settle up: simplify debts to minimise the number of transactions
- View expense history

Non-functional requirements:
- All monetary values stored as `BigDecimal`, never `double`/`float`
- Support groups of up to 50 members
- Simplification algorithm runs in O(N log N)

Clarifying questions:

1. **Can a non-member be added to a split?** No — splits are within the group. This keeps balance tracking scoped to group members and prevents orphaned debt records.

2. **Are balances computed on the fly or pre-aggregated?** This determines the read vs. write trade-off. On-the-fly is always accurate but slow for large history; pre-aggregated (cached net balance per user-pair) is fast but must be invalidated on every new expense.

3. **What currency precision is required?** Two decimal places (standard currency). This determines the `BigDecimal` scale and rounding mode, and affects how we assign the rounding remainder.

4. **Can percentages be fractional (e.g., 33.33%)?** Yes. This means percentage splits must handle the case where percentages sum to 99.99% due to rounding — the last participant absorbs the remainder.

5. **Is real-time balance notification required?** If yes, we need WebSocket push on every new expense. If near-real-time is acceptable, cache invalidation with polling suffices. This question controls a significant architecture decision.

---

**Step 2: Core Entities**

```
User ──member of──> Group
                      │
                   Expense (paidBy: User, splitType, totalAmount)
                      │
               ExpenseSplit (one row per participant: user + amountOwed)
                      ↓
     [EqualSplit | ExactSplit | PercentageSplit | ShareSplit]

Balance = net amount User A owes User B (derived from ExpenseSplits, cached)
Transaction = a recorded settlement payment between two users
```

- **Group**: the boundary of shared expenses. Members are listed here; balances are meaningful only within a group.
- **Expense**: the top-level record of a payment event. `paidBy` identifies who fronted the money; `totalAmount` is what they paid; `splitType` tells the system how to divide it.
- **ExpenseSplit**: one row per participant per expense, recording how much that person owes. This is a separate entity (not embedded in Expense) because each split has its own `amountOwed` and different split types carry additional metadata (percentage value, share count).
- **Balance**: the net amount one user owes another. Not stored as a primary record — computed by aggregating all ExpenseSplits between two users, then cached.
- **Transaction**: records that User A paid User B a settlement amount. Updates the cached balance.

---

**Step 3: Design Decisions**

**Decision: Separate `ExpenseSplit` entity rather than embedding splits in `Expense`**
*Why this over the alternatives:* Embedding all split data in the Expense table would require nullable columns for percentage values, share counts, and exact amounts — only some of which apply to any given expense type. It would also require switching logic in every query that needs to compute how much a particular user owes. A separate `ExpenseSplit` entity keeps each row uniform: every split has a user and an `amountOwed`. Type-specific metadata (the percentage, the share count) lives in subtype tables or a `details` JSON column on the split row.
*Tradeoff:* Every expense load requires a join to ExpenseSplit. For large groups with long history, this is more queries — mitigated by indexed foreign keys and caching.

**Decision: Strategy pattern for split calculation**
*Why this over the alternatives:* Equal, Exact, Percentage, and Shares splits have fundamentally different calculation logic. Without Strategy, `ExpenseService` contains a growing `switch` statement: `case EQUAL: ..., case PERCENTAGE: ..., case SHARES: ...`. Every new split type requires modifying this method, violating the Open/Closed Principle. With Strategy, `EqualSplitStrategy`, `PercentageSplitStrategy`, `ExactSplitStrategy`, and `SharesSplitStrategy` each implement `SplitStrategy.calculateSplits(expense, participants)`. Adding a `CustomFormulaSplit` type requires one new class and one new Spring `@Component` registration.
*Tradeoff:* The indirection means reading `ExpenseService` alone does not tell you how a split is calculated — you must follow the strategy lookup.

**Decision: Greedy two-heap algorithm for debt simplification**
*Why this over the alternatives:* Naive simplification matches debts pair-by-pair in the order they appear, producing one transaction per debt edge — potentially O(N²) transactions for a group of N people. Graph reduction algorithms exist but are O(N²) and do not reduce the transaction count beyond what the greedy approach achieves. The greedy approach exploits the key accounting identity: net balances always sum to zero, meaning every creditor's surplus exactly matches some debtor's deficit. By always matching the largest creditor with the largest debtor, we clear at least one party to zero on every iteration, and the number of resulting transactions is at most N-1. Two max-heaps give us the largest creditor and largest debtor in O(log N) each, making the full algorithm O(N log N).
*Tradeoff:* The greedy result minimises transaction count but does not necessarily optimise for the most convenient pairings (e.g., Alice and Bob might prefer to settle directly even if an algorithmically optimal path routes through Carol).

**Decision: `BigDecimal` with `HALF_UP` rounding, remainder assigned to the last participant**
*Why this over the alternatives:* IEEE 754 `double` cannot represent 0.1 exactly — `0.1 + 0.2 = 0.30000000000000004`. Over hundreds of expense splits, these errors compound into noticeable discrepancies. `BigDecimal` provides exact arbitrary-precision arithmetic. The rounding problem: `$10 / 3 = $3.333...`, which rounds to `$3.33` × 3 = `$9.99` — one cent short. Assigning the remainder to the last participant gives `$3.33, $3.33, $3.34` — the splits sum to exactly `$10.00`. Distributing it randomly or to the first participant would also work; the convention is to assign it to the last person in the list.
*Tradeoff:* The last participant in the list always absorbs the rounding remainder. For tiny amounts (a cent), this is fair enough. For unusual currencies with larger subunit values, a more sophisticated distribution might be warranted.

**Decision: Template Method pattern for expense processing pipeline**
*Why this over the alternatives:* Every expense, regardless of split type, follows the same five-step flow: validate input → calculate splits → persist expense → update cached balances → notify participants. Without Template Method, this pipeline would be duplicated (with subtle variations) in each expense type's service method. Template Method defines the skeleton in an abstract `ExpenseProcessor.processExpense()` and lets subclasses override individual steps — for example, a recurring expense subclass overrides only the "persist" step to create multiple dated records.
*Tradeoff:* The control flow is inverted — the base class calls subclass methods, which can be hard to follow when debugging.

---

**Step 4: Key Algorithm (pseudocode)**

```
BALANCE SIMPLIFICATION:

function simplify(netBalances: Map<UserId, Amount>):
    // netBalances[user] = total owed to user minus total user owes
    // Positive = creditor (others owe them), Negative = debtor (they owe others)

    creditors = max-heap sorted by balance (largest credit first)
    debtors   = max-heap sorted by absolute balance (largest debt first)

    for each user, balance in netBalances:
        if balance > 0: creditors.add(user, balance)
        if balance < 0: debtors.add(user, abs(balance))
        // balance == 0: already settled, skip

    result = []

    while creditors and debtors are not empty:
        creditor = creditors.pollMax()   // e.g., Bob is owed $20
        debtor   = debtors.pollMax()     // e.g., Alice owes $30

        transfer = min(creditor.amount, debtor.amount)  // $20
        result.add(Transaction(debtor=Alice, creditor=Bob, amount=transfer))

        remainingCredit = creditor.amount - transfer    // $0  → Bob is cleared
        remainingDebt   = debtor.amount - transfer      // $10 → Alice still owes $10

        if remainingCredit > 0: creditors.add(creditor.user, remainingCredit)
        if remainingDebt   > 0: debtors.add(debtor.user, remainingDebt)

    return result
    // Result: Alice pays Bob $20, Alice pays Carol $10 → 2 transactions, not 3.

EQUAL SPLIT CALCULATION:

function calculateEqualSplits(totalAmount, participants):
    n = participants.size()
    perPerson = totalAmount.divide(n, 2, HALF_UP)  // e.g., $3.33
    splits = []
    runningTotal = ZERO

    for i = 0 to n-2:  // all but last
        splits.add(participants[i], perPerson)
        runningTotal += perPerson

    // Last person absorbs rounding remainder
    splits.add(participants[n-1], totalAmount - runningTotal)  // e.g., $3.34
    return splits
```

---

**Step 5: Must-Know Code**

```java
public List<SettlementTransaction> simplify(Map<Long, BigDecimal> netBalances) {
    // Creditors: users who are owed money. Max-heap: largest creditor polled first.
    PriorityQueue<Map.Entry<Long, BigDecimal>> creditors =
        new PriorityQueue<>((a, b) -> b.getValue().compareTo(a.getValue()));

    // Debtors: users who owe money, stored as positive values for easy comparison.
    PriorityQueue<Map.Entry<Long, BigDecimal>> debtors =
        new PriorityQueue<>((a, b) -> b.getValue().compareTo(a.getValue()));

    for (var entry : netBalances.entrySet()) {
        int cmp = entry.getValue().compareTo(BigDecimal.ZERO);
        if (cmp > 0) creditors.offer(entry);                                    // net positive → creditor
        else if (cmp < 0) debtors.offer(Map.entry(entry.getKey(),
                                                   entry.getValue().negate())); // store as positive
        // cmp == 0 → balanced, skip
    }

    var result = new ArrayList<SettlementTransaction>();

    while (!creditors.isEmpty() && !debtors.isEmpty()) {
        var creditor = creditors.poll();   // largest amount owed to someone
        var debtor   = debtors.poll();     // largest amount someone owes

        // Transfer is limited by the smaller of the two — one of them hits zero.
        BigDecimal transfer = creditor.getValue().min(debtor.getValue());
        result.add(new SettlementTransaction(debtor.getKey(), creditor.getKey(), transfer));

        // Return non-zero remainders to their respective heaps for the next iteration.
        BigDecimal remainingCredit = creditor.getValue().subtract(transfer);
        BigDecimal remainingDebt   = debtor.getValue().subtract(transfer);

        if (remainingCredit.compareTo(BigDecimal.ZERO) > 0)
            creditors.offer(Map.entry(creditor.getKey(), remainingCredit));
        if (remainingDebt.compareTo(BigDecimal.ZERO) > 0)
            debtors.offer(Map.entry(debtor.getKey(), remainingDebt));
    }

    return result;  // at most N-1 transactions for N users
}
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained. Every concept explained inline.

> *Tip: Structure answers as: "The key challenge is X. I chose Y over Z because [reason]. The tradeoff is [cost]."*

---

**Concept Check — Core Algorithm**
**"Walk me through the balance simplification algorithm."**

**One-line answer:** Compute net balances, then greedily match the largest creditor with the largest debtor using two max-heaps until everyone is cleared.

**Full answer:**
> "The key challenge is minimising the number of transactions needed to clear all debts. The raw debt graph after many expenses can have an edge between every pair of users — O(N²) transactions. The insight is the accounting identity: net balances always sum to zero. This means every creditor's surplus is exactly covered by some debtor's deficit. I compute each user's net balance — total owed to them minus total they owe. Positive means creditor, negative means debtor. I put creditors in a max-heap sorted by amount and debtors in another max-heap sorted by absolute debt. On each iteration, I poll the largest creditor and the largest debtor, transfer the minimum of their amounts, and return the non-zero remainder to the heap. Each iteration clears at least one party to zero, so the algorithm runs in O(N log N) and produces at most N-1 transactions. For a group of 50, the worst case is 49 transactions — much better than the naive pairwise approach."

> *Draw the state of the two heaps after the first iteration to show you understand what 'returning the remainder' means.*

**Gotcha follow-up:** *"Why does this greedy approach guarantee the minimum number of transactions?"*
> "Because net balances sum to zero (fundamental accounting identity), every creditor's total can always be paid by debtors, and every iteration removes at least one person from further consideration. The minimum possible transactions to clear N people is N-1 (a spanning tree structure). The greedy two-heap approach achieves this bound. A simpler pairwise matching would produce N-1 transactions in the best case but can produce more if matching is done naively."

---

**Tradeoff Question — Money Arithmetic**
**"Why must you use BigDecimal for money, and how do you handle the rounding remainder in equal splits?"**

**One-line answer:** `double` cannot represent 0.1 exactly in IEEE 754 binary; `BigDecimal` uses exact decimal arithmetic, and the remainder goes to the last participant.

**Full answer:**
> "IEEE 754 floating-point represents numbers in base 2, but many common decimal fractions — like 0.1 — have no exact binary representation. So `0.1 + 0.2` in Java evaluates to `0.30000000000000004`. For a single calculation this is negligible, but across hundreds of expense splits, these errors compound: a group might find their balances are off by a few cents with no obvious cause. `BigDecimal` uses exact decimal arithmetic, so `0.1 + 0.2` is precisely `0.3`. I always set scale 2 and `RoundingMode.HALF_UP`. For the rounding remainder problem: `$10 / 3 = $3.333...`, which rounds to `$3.33`. Three people paying `$3.33` sum to `$9.99` — one cent short. I calculate `perPerson * (n-1)` and assign `totalAmount - runningTotal` to the last participant. This guarantees splits always sum to exactly `totalAmount` with no residue."

> *Mention the PostgreSQL column type too — store as `DECIMAL(19,4)`, never `FLOAT`.*

---

**Design Scenario — Scale**
**"How would you scale Splitwise to millions of groups?"**

**One-line answer:** Partition by `groupId`, cache net balances in Redis with event-driven invalidation, and keep the simplification algorithm in-memory per group.

**Full answer:**
> "The key scaling insight is that groups are isolated units — a group of five friends in Mumbai has no data dependency on a group in London. I would shard the expense and split data by `groupId`, so each shard handles a subset of groups. For read performance, net balances per group are pre-computed and stored in Redis. When a new expense is added, a `GroupBalanceUpdated` event invalidates the cached balance for that group and triggers a recomputation. The simplification algorithm is O(N log N) and runs in memory — for a 50-person group, this is microseconds. For even higher read throughput, I would push balance changes to connected clients via WebSocket on the `GroupBalanceUpdated` event, eliminating polling entirely."

> *Always show you know where the partition boundary is — for Splitwise it is the group.*

---

**Concept Check — Split Types**
**"How does the percentage split handle the case where percentages don't sum to exactly 100%?"**

**One-line answer:** Validation rejects it if the sum deviates beyond rounding tolerance; the remainder after `BigDecimal` arithmetic is assigned to the last participant.

**Full answer:**
> "I validate that percentages sum to exactly 100 before processing — if they don't, I return a 400 Bad Request. The trickier case is when percentages are valid (sum to 100) but the resulting amounts don't sum to `totalAmount` due to `BigDecimal` rounding. For example, three people at 33.33%, 33.33%, 33.34%: `100 * 0.3333 = $33.33`, `100 * 0.3333 = $33.33`, `100 * 0.3334 = $33.34`. If I compute each independently with `HALF_UP`, the sum might be `$33.33 + $33.33 + $33.34 = $100.00` — lucky. But with awkward amounts it can be off by a cent. The safe approach: compute the first N-1 splits, sum them, and assign `totalAmount - sum` to the last participant. This guarantees the total always balances."

> *This is a common follow-up and tests whether you know the 'last person absorbs remainder' pattern.*

---

> **Common Mistake — Storing balances as a dense user-pair matrix:** Pre-computing and storing a balance row for every pair of users in a group creates O(N²) rows. For a 50-person group that is 1,225 rows, each updated on every new expense. Instead, store only non-zero balances — in practice, most user pairs in a group never transact directly — and recompute on demand from the ExpenseSplit ledger, caching the result.

---

**Quick Revision:** Splitwise's entire algorithmic insight is that net balances sum to zero, which lets a greedy two-heap algorithm collapse any debt graph into at most N-1 transactions in O(N log N).

---

## Topic 6: Elevator System — LLD Case Study

#### The Idea

An elevator system sounds simple — press a button, the elevator comes, you go to your floor. But think about what happens during morning rush hour in a 50-storey office building when 200 people are all pressing the UP button on floors 1 through 5 simultaneously. Which of the six elevators should respond to each request? Should elevator 3 go all the way to floor 1 to pick someone up when elevator 2 is already on floor 2 heading up? How does an elevator decide the order in which to serve its queued floors?

The scheduling problem is the heart of this design. A naive approach (First Come, First Served) serves requests in the order they arrive, which can make an elevator travel from floor 10 down to floor 1, back up to floor 3, down to floor 2, and so on — an enormous amount of unnecessary travel. The SCAN and LOOK algorithms, borrowed from disk scheduling, dramatically reduce travel by committing the elevator to one direction until all requests in that direction are served.

The concurrency problem is equally important. Each elevator runs as its own thread. External requests come in from the main thread. The data structure tracking which floors the elevator needs to visit is shared between these threads. Without synchronisation, you get `ConcurrentModificationException` or, worse, silently lost requests. The design must coordinate a background thread (the elevator moving) with a foreground thread (the controller dispatching requests) safely and efficiently.

#### How It Works

**Step 1: Requirements & Clarifying Questions**

Functional requirements:
- N elevators, M floors in a building
- External request: a person on floor F presses UP or DOWN
- Internal request: a person inside an elevator presses their destination floor
- Elevators move to serve requests; doors open and close at each served floor
- Elevators can be placed in MAINTENANCE mode (stop accepting requests)

Non-functional requirements:
- Minimise average wait time across all requests
- No request starves indefinitely (fairness guarantee)
- Scheduling algorithm is pluggable — support FCFS, SCAN, and LOOK
- Thread-safe: multiple elevators run concurrently as separate threads

Clarifying questions:

1. **Is this a simulation or a real controller?** Simulation. This matters because in a real controller, `step()` would be driven by hardware interrupts; in a simulation, it is called by a scheduled timer or a tight loop.

2. **Can multiple people board the same elevator at the same floor?** Yes, but for the LLD we model floors served, not individual passengers. This keeps the scope focused on scheduling rather than capacity management.

3. **What happens to in-flight requests when an elevator enters MAINTENANCE mode?** Pending requests are redistributed to other elevators by the `ElevatorController`. This defines the MAINTENANCE transition behaviour.

4. **Should the system prefer to pick up nearby requests or stick to its current direction?** This is the core scheduling question — the answer (LOOK algorithm) drives several data structure choices.

5. **What is the expected group size (N elevators, M floors)?** Knowing the scale — say, 10 elevators, 50 floors — tells us whether O(N²) operations per step are acceptable or whether O(N log N) is required.

---

**Step 2: Core Entities**

```
Building
  └── ElevatorController  (1 per building)
           │  receives ExternalRequest(floor, direction)
           │  assigns using SchedulingStrategy
           ▼
       Elevator  (N instances, each runs as a Thread)
           │  receives InternalRequest(destinationFloor)
           │
       State: IDLE | MOVING_UP | MOVING_DOWN | MAINTENANCE
           │
       pendingFloors: TreeSet<Integer>
```

- **Building**: the root entity. Holds the `ElevatorController` and the list of `Elevator` instances.
- **ElevatorController**: the dispatcher. Receives external button presses and assigns them to an elevator using the configured `SchedulingStrategy`. Has no opinion on how a single elevator serves its queue — that is the elevator's responsibility.
- **Elevator**: the workhorse. Runs its own thread, maintains its `pendingFloors` TreeSet, and implements the LOOK algorithm in `step()`.
- **ElevatorState** (IDLE / MOVING_UP / MOVING_DOWN / MAINTENANCE): encodes what the elevator is currently doing. Drives the behaviour of `step()` and `addDestination()`.
- **SchedulingStrategy**: decides which elevator to assign an external request to. Injected into `ElevatorController` — pluggable without changing dispatcher logic.
- **ExternalRequest / InternalRequest**: value objects. External = someone waiting on a floor. Internal = someone inside pressing a destination floor.

---

**Step 3: Design Decisions**

**Decision: `TreeSet<Integer>` for `pendingFloors`**
*Why this over the alternatives:* The LOOK algorithm needs to find the nearest floor above the current position (`ceiling(currentFloor)`) and the nearest floor below (`floor(currentFloor)`) on every `step()` call. A `List` or `ArrayDeque` would require O(N) linear scan to find these values — every step would iterate through all pending floors. `TreeSet` is a sorted set backed by a red-black tree; `ceiling()` and `floor()` run in O(log N). `TreeSet` also auto-deduplicates: if a passenger presses floor 5 twice, it is stored only once.
*Tradeoff:* `TreeSet` is not thread-safe. Every access must be wrapped in a `synchronized(lock)` block. A concurrent data structure like `ConcurrentSkipListSet` would avoid explicit locking but would sacrifice the `wait/notifyAll` mechanism used to park the idle elevator thread.

**Decision: State pattern for elevator behaviour**
*Why this over the alternatives:* Without a State pattern, every method in `Elevator` starts with `if (state == MAINTENANCE) throw ...` or `if (state == IDLE) ...` — scattered conditionals that grow with each new state. The State pattern encapsulates state-specific behaviour: `MaintenanceState.addDestination()` throws an exception; `IdleState.addDestination()` accepts the floor and transitions to MOVING_UP or MOVING_DOWN. Adding a new `DOOR_OPEN` state (to prevent movement while doors are open) requires one new class and changes to the two adjacent states (MOVING and IDLE), not changes to `Elevator` itself.
*Tradeoff:* State transitions are now spread across multiple classes, making the full lifecycle harder to see in one place. A state transition diagram is essential documentation for this design.

**Decision: Strategy pattern for dispatcher scheduling**
*Why this over the alternatives:* The `ElevatorController` needs to pick the best elevator for each external request. Different algorithms make different trade-offs: FCFS is simple but ignores elevator position; LOOK-based scoring (distance + direction penalty + queue depth) minimises average wait time but is more complex. Without Strategy, `ElevatorController` has a switch statement that changes when you want to test a different algorithm or configure per environment. With `SchedulingStrategy` as an interface, `LookSchedulingStrategy` and `FcfsSchedulingStrategy` are swappable `@Component` beans.
*Tradeoff:* A scoring function in `LookSchedulingStrategy` has tunable weights (how much to penalise direction mismatch vs. distance). Getting these weights wrong can increase average wait time. This needs experimentation or offline simulation.

**Decision: `synchronized` block with `wait/notifyAll` for thread coordination**
*Why this over the alternatives:* The elevator's `step()` loop runs in a background thread; `addDestination()` is called from the main `ElevatorController` thread. Both access `pendingFloors` (the `TreeSet`). Unsynchronised concurrent access to a `TreeSet` causes `ConcurrentModificationException` or silent data corruption. `synchronized(lock)` on a shared `Object lock` ensures mutual exclusion. When `pendingFloors` is empty, `step()` calls `lock.wait()` to park the thread (releasing the lock) rather than spinning in a busy loop — which would waste CPU. `addDestination()` calls `lock.notifyAll()` to wake the parked elevator thread the moment a new floor is added.
*Tradeoff:* `wait/notifyAll` is low-level and easy to misuse (spurious wakeups require a `while` loop, not an `if`). A higher-level `BlockingQueue` or `Condition` object from `java.util.concurrent` would be cleaner — but `TreeSet` with range queries cannot be replaced by a `BlockingQueue` directly.

**Decision: LOOK algorithm over SCAN for floor selection**
*Why this over the alternatives:* FCFS serves floors in arrival order — an elevator on floor 10 might travel down to floor 1 to serve the first request, then back up to floor 8 for the second, zig-zagging wastefully. SCAN commits to one direction (down to floor 0, then up to the top floor) like a typewriter head — better than FCFS but travels to the building boundary even when no requests exist there. LOOK is like SCAN but reverses at the last pending request in the current direction, not at the building boundary. In a 50-floor building where all requests are on floors 5-20, SCAN travels all the way to floor 50 before reversing; LOOK reverses at floor 20. Fewer unnecessary floors travelled means lower average wait time.
*Tradeoff:* LOOK requires knowing the highest and lowest pending floors at all times — which is why `TreeSet.last()` and `TreeSet.first()` are used, requiring O(log N) per step rather than O(1) for a simple queue pop.

---

**Step 4: Key Algorithm (pseudocode)**

```
LOOK ALGORITHM — step():

function step(elevator):
    acquire elevator.lock

    while pendingFloors is empty and state != MAINTENANCE:
        state = IDLE
        lock.wait()   // park thread; release lock while waiting

    if pendingFloors is empty: release lock; return

    nextFloor = selectNextFloor(elevator)

    if nextFloor > currentFloor:
        currentFloor++
        state = MOVING_UP
    else if nextFloor < currentFloor:
        currentFloor--
        state = MOVING_DOWN

    if currentFloor == nextFloor:
        pendingFloors.remove(nextFloor)
        openAndCloseDoors()
        if pendingFloors is empty: state = IDLE

    release elevator.lock

function selectNextFloor(elevator):
    if state == MOVING_UP:
        above = pendingFloors.ceiling(currentFloor)  // nearest floor ≥ currentFloor
        if above != null: return above
        else: return pendingFloors.last()            // reverse: no more above, go to highest

    if state == MOVING_DOWN:
        below = pendingFloors.floor(currentFloor)    // nearest floor ≤ currentFloor
        if below != null: return below
        else: return pendingFloors.first()           // reverse: no more below, go to lowest

    if state == IDLE:
        above = pendingFloors.ceiling(currentFloor)
        below = pendingFloors.floor(currentFloor)
        if above == null: return below
        if below == null: return above
        return whichever of (above, below) is closer to currentFloor

DISPATCHER — selectElevator(floor, direction):

for each elevator that is not MAINTENANCE:
    score = distanceTo(elevator, floor)
    if elevator.state == MOVING_UP and direction == DOWN: score += DIRECTION_PENALTY
    if elevator.state == MOVING_DOWN and direction == UP: score += DIRECTION_PENALTY
    score += elevator.pendingFloors.size() * LOAD_PENALTY

return elevator with lowest score
```

---

**Step 5: Must-Know Code**

```java
public class Elevator implements Runnable {
    private final Object lock = new Object();
    private final TreeSet<Integer> pendingFloors = new TreeSet<>();
    private volatile int currentFloor = 0;          // volatile: ElevatorController reads this without locking
    private volatile ElevatorState state = ElevatorState.IDLE;

    @Override
    public void run() {
        while (!Thread.currentThread().isInterrupted()) {
            step();
        }
    }

    public void step() {
        synchronized (lock) {
            // Spurious wakeup guard: must be a while loop, not if.
            while (pendingFloors.isEmpty() && state != ElevatorState.MAINTENANCE) {
                state = ElevatorState.IDLE;
                try { lock.wait(); } catch (InterruptedException e) {
                    Thread.currentThread().interrupt(); return;
                }
            }
            if (pendingFloors.isEmpty()) return;

            // LOOK: find next floor in the current direction of travel.
            Integer nextFloor = switch (state) {
                case MOVING_UP -> {
                    Integer above = pendingFloors.ceiling(currentFloor); // O(log N)
                    yield above != null ? above : pendingFloors.last();  // reverse at last request above
                }
                case MOVING_DOWN -> {
                    Integer below = pendingFloors.floor(currentFloor);   // O(log N)
                    yield below != null ? below : pendingFloors.first(); // reverse at last request below
                }
                default -> {  // IDLE: pick the closer of above/below
                    Integer above = pendingFloors.ceiling(currentFloor);
                    Integer below = pendingFloors.floor(currentFloor);
                    if (above == null) yield below;
                    if (below == null) yield above;
                    yield (above - currentFloor <= currentFloor - below) ? above : below;
                }
            };

            // Move one floor at a time toward nextFloor.
            if      (nextFloor > currentFloor) { currentFloor++; state = ElevatorState.MOVING_UP; }
            else if (nextFloor < currentFloor) { currentFloor--; state = ElevatorState.MOVING_DOWN; }

            if (currentFloor.equals(nextFloor)) {  // arrived
                pendingFloors.remove(nextFloor);   // O(log N)
                openAndCloseDoors();
                if (pendingFloors.isEmpty()) state = ElevatorState.IDLE;
            }
        }
    }

    public void addDestination(int floor) {
        synchronized (lock) {
            pendingFloors.add(floor);  // TreeSet deduplicates; pressing 5 twice has no effect
            if (state == ElevatorState.IDLE)
                state = floor >= currentFloor ? ElevatorState.MOVING_UP : ElevatorState.MOVING_DOWN;
            lock.notifyAll();  // wake the step() loop if it is parked in lock.wait()
        }
    }
}
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained. Every concept explained inline.

> *Tip: Structure answers as: "The key challenge is X. I chose Y over Z because [reason]. The tradeoff is [cost]."*

---

**Concept Check — Scheduling Algorithm**
**"Explain the LOOK algorithm and why it is better than SCAN."**

**One-line answer:** LOOK reverses at the last pending request in the current direction, not at the building boundary — eliminating unnecessary travel past the last requested floor.

**Full answer:**
> "SCAN works like a typewriter head: the elevator travels from the bottom floor to the top floor and back, serving every pending request it passes. The problem is that it travels all the way to the building boundary even if there are no requests past a certain point. In a 50-floor building where all current requests are on floors 5 through 15, SCAN goes all the way to floor 50, serves nothing between floors 15 and 50, then reverses — pure waste. LOOK fixes this by reversing at the last pending request in the current direction. Using a `TreeSet`, I find `pendingFloors.last()` as the reversal point when moving up and `pendingFloors.first()` when moving down. This eliminates the unnecessary travel to the building boundary. LOOK reduces average wait time compared to SCAN at the cost of slightly more complexity — the reversal point changes dynamically as requests are added and served."

> *Use a concrete example with specific floor numbers — it demonstrates you understand the algorithm, not just the name.*

**Gotcha follow-up:** *"Can LOOK cause starvation?"*
> "Not in practice for this problem. Because the elevator reverses at the extreme pending request rather than the building boundary, every pending request is eventually reached on the next sweep in its direction. The only starvation risk is a continuous stream of same-direction requests always added ahead of a waiting request — but in a finite building with bounded traffic, this resolves in at most two full sweeps. If starvation is a hard requirement, I would add a 'maximum wait' counter: any request waiting more than K sweeps gets elevated priority, forcing the elevator to serve it next."

---

**Concept Check — Thread Safety**
**"How do you handle concurrent requests from multiple threads safely?"**

**One-line answer:** A shared `Object lock` guards all `TreeSet` access; `step()` parks with `lock.wait()` when idle, and `addDestination()` wakes it with `lock.notifyAll()`.

**Full answer:**
> "Each `Elevator` has a background thread running its `step()` loop and the `ElevatorController` calls `addDestination()` from the main thread. Both access `pendingFloors`, a `TreeSet` that is not thread-safe — concurrent modification would cause `ConcurrentModificationException` or data loss. I guard every `TreeSet` access with `synchronized(lock)` where `lock` is a private `Object` in `Elevator`. When `pendingFloors` is empty, `step()` calls `lock.wait()`, which atomically releases the lock and parks the thread — no CPU spinning. When `addDestination()` adds a new floor, it calls `lock.notifyAll()` inside its own `synchronized(lock)` block, waking the parked `step()` thread. The `wait()` is inside a `while` loop (not `if`) to guard against spurious wakeups — a Java threading requirement. `currentFloor` and `state` are `volatile` so the `ElevatorController` can read them for scoring without acquiring the lock."

> *Explicitly mention the spurious wakeup guard — it separates candidates who know Java concurrency from those who learned the pattern without understanding it.*

**Gotcha follow-up:** *"Why not use a `ConcurrentSkipListSet` instead of a synchronized `TreeSet`?"*
> "`ConcurrentSkipListSet` provides thread-safe `ceiling()` and `floor()` operations, which would avoid explicit locking for the read path. However, I still need `wait/notifyAll` to park the elevator thread when the set is empty — and that mechanism requires an explicit lock object. Mixing `ConcurrentSkipListSet` with a separate monitor for the wait/notify creates a compound check-then-act that is harder to reason about correctly. The synchronized `TreeSet` plus a single lock object keeps all coordination through one mechanism. If I were using a `BlockingQueue`, I could use `take()` to block on empty — but a queue does not support the range queries (`ceiling`, `floor`) the LOOK algorithm needs."

---

**Tradeoff Question — Data Structure**
**"Why TreeSet for pendingFloors instead of a List or Queue?"**

**One-line answer:** LOOK needs the nearest floor above and below in O(log N); a List requires O(N) scan; `TreeSet.ceiling()` and `TreeSet.floor()` are O(log N) by design.

**Full answer:**
> "The LOOK algorithm's core operation is: given my current floor, find the nearest pending floor above me (to continue upward) or the nearest below (to continue downward). On a `List`, this requires iterating through every pending floor to find the minimum distance — O(N) per step. For an elevator serving 20 requests, that is 20 comparisons on every simulated step. `TreeSet` is a sorted red-black tree. `ceiling(x)` returns the smallest element greater than or equal to x in O(log N). `floor(x)` returns the largest element less than or equal to x in O(log N). `last()` and `first()` give the reversal points in O(log N). Additionally, `TreeSet` automatically deduplicates: if a passenger presses floor 5 inside the elevator and another passenger on floor 5 presses the DOWN button, the floor is stored only once. A `Queue` cannot be used because it forces FIFO ordering — the whole point of LOOK is to ignore insertion order in favour of direction-optimal ordering."

> *Mention deduplication — it is a free benefit of `TreeSet` that interviewers appreciate.*

---

**Design Scenario — Further Optimisation**
**"How would you reduce average wait time beyond the LOOK algorithm?"**

**One-line answer:** Destination dispatch, express zones, predictive scheduling, and dynamic idle rebalancing each attack a different dimension of wait time.

**Full answer:**
> "LOOK minimises in-shaft travel, but there are four further levers. First, destination dispatch: instead of pressing UP or DOWN in the lobby, passengers enter their destination floor on a keypad before boarding. The controller groups passengers going to nearby floors onto the same elevator — one elevator handles floors 20-25, another handles 30-35. This dramatically reduces stops per trip. Second, express zones: some elevators serve only floors 1-20, others 21-40, others 41-50. Passengers transfer at zone boundaries. Fewer floors per elevator means faster service within each zone. Third, predictive scheduling: the system learns that 8-9 AM sees a surge of UP requests from floor 1, so it pre-positions more elevators at the ground floor before rush hour rather than waiting for requests to accumulate. Fourth, dynamic rebalancing: when all elevators cluster at the top of the building (evening rush going down), idle elevators are proactively sent back to mid-building floors to reduce the initial travel distance for the next request."

> *Showing you can think beyond the algorithm to operational optimisations signals senior-level thinking.*

---

> **Common Mistake — Using `if` instead of `while` for `lock.wait()`:** Java's `wait()` can return spuriously — the thread wakes without `notifyAll()` being called. If the guard is `if (pendingFloors.isEmpty()) lock.wait()`, the thread may proceed on a spurious wakeup and call `step()` on an empty `TreeSet`, causing a `NoSuchElementException` on `pendingFloors.last()`. Always use `while (pendingFloors.isEmpty()) lock.wait()` — this is a non-negotiable rule in Java concurrent programming.

---

**Quick Revision:** The elevator system's correctness rests on two things: a `TreeSet` for O(log N) directional floor selection, and a `synchronized` + `wait/notifyAll` pattern that lets the elevator thread sleep efficiently between requests without busy-waiting.

