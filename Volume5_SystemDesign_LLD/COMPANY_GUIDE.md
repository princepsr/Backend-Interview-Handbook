# Volume 5: System Design & LLD — Company Guide

## Which Companies Emphasise System Design

| Company | HLD Weight | LLD Weight | Design Patterns | Typical Design Question |
|---|---|---|---|---|
| Google | Very High | Medium | Low (implicit) | Search indexing, Maps, YouTube |
| Meta / Facebook | Very High | Medium | Low | News Feed, Messenger, Instagram |
| Amazon | High | Medium | Low | Order pipeline, notification system |
| Uber / Lyft | High | Medium | Low | Ride matching, driver tracking |
| Netflix | High | Low | Low | Video streaming, recommendation |
| Atlassian | Medium | Very High | High | Jira-like ticketing, multi-tenant SaaS |
| Salesforce | Medium | High | High | CRM entity model, workflow engine |
| Stripe | High | High | Medium | Payment API, idempotency, webhooks |
| Flipkart / Meesho | High | Medium | Low | Flash sale, product catalog, cart |
| Razorpay / CRED | High | High | Medium | Payment gateway, reconciliation |

---

## Company-Specific Tips

### Google
Scale is the answer. Every design must handle billions of users — single points of failure are disqualifying. Expect deep dives into consistency vs availability trade-offs. Reference distributed systems concepts: consistent hashing, quorum reads/writes, log-structured storage. Spanner-like strong consistency and Bigtable-like wide-column stores are fair game. Interviewers want to hear you reason about CAP, not just recite it.

### Meta / Facebook
Social graph scale drives every design. News Feed requires fan-out strategy (on write for celebrities is too expensive — hybrid model). Real-time messaging needs low-latency pub/sub. CDN placement and cache hierarchy at extreme scale (hundreds of millions of concurrent users) are expected discussion points. Know how Facebook uses Memcached and TAO.

### Amazon
Leadership Principles are embedded in design discussions. Frame your design decisions around operational excellence (monitoring, alerting), fault tolerance (retry with exponential backoff, dead-letter queues), and observability (structured logging, distributed tracing). Expect questions on SQS/SNS patterns and DynamoDB single-table design.

### Uber / Lyft
Real-time geo systems dominate. Know geohashing and quadtrees for location indexing. Ride matching is a supply-demand optimisation problem — discuss how to reduce latency of the matching algorithm. Surge pricing is a separate service reading demand signals. Driver location streaming requires a high-write, low-latency store (Redis sorted sets are the canonical answer).

### Netflix
Content delivery is the core. CDN strategy, adaptive bitrate streaming (HLS/DASH), and cache warming are expected. Recommendation system design: collaborative filtering at scale, near-real-time feature pipelines. Chaos engineering is culturally embedded — expect to discuss failure injection and graceful degradation. Know the difference between the data plane (video serving) and control plane (metadata, catalogue).

### Atlassian / Salesforce
LLD-heavy interviews. Expect to design a Jira-like ticket system: entities (Issue, Project, User, Status, Transition), workflow state machine, permission model, plugin/extension points. Multi-tenant SaaS patterns matter: tenant isolation at DB level (schema-per-tenant vs row-level security). For Salesforce: CRM entity hierarchy, configurable fields, workflow automation engine design.

### Stripe
API design is treated as system design. Idempotency keys on payment requests, versioned API contracts, backward-compatible schema evolution. Webhook reliability: at-least-once delivery, signature verification, retry with exponential backoff. Reconciliation pipeline for detecting missed events. Strong consistency requirements for financial data.

### Flipkart / Indian Product Companies
E-commerce systems: product catalogue (search indexing, faceted filtering), cart (session-based vs persistent), order pipeline (state machine: placed → confirmed → shipped → delivered). Flash sale handling is a common deep dive: token bucket / queue-based admission, inventory reservation with optimistic locking, cache stampede prevention.

---

## The 5 LLD Questions That Always Come Up

1. **Parking Lot System** — entities: ParkingLot, Floor, Slot, Vehicle, Ticket. Strong answer: strategy pattern for pricing, observer for slot availability updates, factory for vehicle types.

2. **Library Management System** — entities: Book, Member, Loan, Fine, Reservation. Strong answer: state machine for loan lifecycle, decorator for fine calculation, clean separation of search vs borrow vs return services.

3. **Hotel / Restaurant Booking** — entities: Room/Table, Booking, User, Payment. Strong answer: calendar-based availability (interval tree or bitmap), concurrency handling for double-booking prevention.

4. **Snake and Ladder / Chess / Tic-Tac-Toe** — tests object modelling under constraints. Strong answer: board abstraction, player strategy interface, game loop separation from rules engine.

5. **ATM / Vending Machine** — state machine question. Strong answer: explicit states (Idle, CardInserted, PinVerified, Dispensing), transitions modelled as strategy or state pattern, no switch-case spaghetti.

---

## The 5 HLD Questions That Always Come Up

1. **URL Shortener** — hashing strategy (MD5 vs counter-based), redirect flow, analytics, expiry. Tests: data model, cache layer, CAP trade-off.

2. **Rate Limiter** — algorithms (token bucket vs sliding window log vs fixed window). Tests: distributed coordination, Redis atomic ops, where to place it in the stack.

3. **Notification System** — fan-out models, push vs pull, channel abstraction (email/SMS/push). Tests: queue design, idempotency, retry, delivery guarantees.

4. **Twitter / News Feed** — fan-out on write vs read vs hybrid, timeline aggregation, celebrity problem. Tests: scale reasoning, cache design, eventual consistency acceptance.

5. **Distributed Cache (Redis-like)** — consistent hashing, replication, eviction policies (LRU/LFU), persistence options. Tests: depth of distributed systems knowledge.
