# Volume 5: System Design & LLD

**4 chapters · ~80+ Q&As · RADIO Framework · GoF Patterns · LLD Case Studies**

The design round is the primary differentiator at SDE2. Most candidates can code — fewer can design a clean, extensible class hierarchy under time pressure, or articulate trade-offs in a distributed system at scale. This volume covers both LLD (Low-Level Design) and HLD (High-Level Design) in the depth expected at FAANG+, Atlassian, and product companies.

---

## What's In This Volume

| Chapter | Topic | Interview Weight |
|---------|-------|-----------------|
| Ch 19 | Design Patterns | High — Singleton, Factory, Builder, Proxy, Strategy, Observer |
| Ch 20 | SOLID & Clean Architecture | High — the lens interviewers use to evaluate your LLD code |
| Ch 21 | LLD Case Studies | **Very High** — Parking Lot, URL Shortener, Rate Limiter, BookMyShow |
| Ch 22 | System Design HLD | **Very High** — RADIO framework, capacity estimation, news feed design |

---

## Study Plan for This Volume

### 4-Week Plan (Days 22–28 of Week 4)

| Day | Chapter | Focus |
|-----|---------|-------|
| Day 22 | Ch19 | Singleton (thread-safe variants), Factory vs Abstract Factory, Builder, Proxy, Strategy, Observer |
| Day 23 | Ch20 | Work through BAD → GOOD code transformations; apply SOLID critique to your own code |
| Day 24 | Ch21 | Parking Lot + URL Shortener — design both from scratch without notes |
| Day 25 | Ch21 | Rate Limiter + BookMyShow — focus on concurrency and thread safety |
| Day 26 | Ch22 | RADIO framework, back-of-envelope math, news feed design |
| Day 27 | Ch21 + Ch22 | Splitwise + Elevator + 2 HLD designs from scratch — time-boxed 45 min each |
| Day 28 | Full mock | Ch27 (100 Q&As) + interview checklist |

> After finishing this volume, validate with **Chapter 27** (System Design & LLD Revision) in the Revision Pack.

### Crash Plan (1 week total — Days 5–6 of 7)

Day 5: Ch19 + Ch20 + 2 LLD designs from Ch21 (Parking Lot + URL Shortener).  
Day 6: Ch22 — 2 HLD designs from scratch using the RADIO framework.

---

## Company Focus

### Amazon
- **Ch22** — System design is the primary L5 differentiator. Include monitoring/alerting in every design.
- Expect: capacity estimation first → then architecture. "How many writes per second? What's your SLA?"
- Bar raiser: ambiguous requirements — push back and clarify rather than assume
- LPs in design: Ownership (justify trade-offs), Dive Deep (internals), Invent and Simplify

### Google
- **Ch22** — Start every design with constraints and capacity math. Push to 1B users.
- **Ch20** — Code quality is evaluated in LLD rounds: clean naming, single responsibility, open/closed
- "What would break first?" — prepare failure mode analysis for every component

### Atlassian / Salesforce
- **Ch19 + Ch20 + Ch21** — LLD is a primary round. Model features from their own products.
- Atlassian: Jira board state machine, Confluence page hierarchy (tree structure with permissions)
- Salesforce: multi-tenant data model, extensible object/field metadata system
- Expect: "Design the class hierarchy before writing any code"

### Goldman Sachs / FinTech
- **Ch19** — Command pattern for order execution, Observer for market data feeds
- **Ch21** — Rate limiter with correctness under concurrent updates; focus on thread safety proofs

---

## LLD Interview Playbook (5-Step Process)

1. **Clarify requirements** — functional (what it does) + non-functional (scale, consistency, latency). Never code before this.
2. **Identify entities** — nouns in the requirements become classes. Verbs become methods or relationships.
3. **Draw the class diagram** — mentally or on whiteboard. Establish inheritance vs composition before typing.
4. **Apply patterns naturally** — at least 2–3 patterns. Do not force-fit; identify where extensibility or decoupling is genuinely needed.
5. **Address concurrency** — if shared state exists, state your locking strategy explicitly. Interviewers notice when you skip this.

## HLD Interview Playbook (RADIO Framework)

| Step | What to cover |
|------|--------------|
| **R**equirements | Functional + non-functional. Ask: scale (DAU, QPS), consistency model, SLA |
| **A**rchitecture | High-level diagram — clients, load balancer, services, DB, cache, queue |
| **D**ata model | Schema or key design. Justify SQL vs NoSQL with access patterns |
| **I**nterface | Key API contracts (REST/gRPC), event schemas for async flows |
| **O**ptimisations | Caching strategy, CDN, read replicas, sharding, async decoupling |

---

## Key Concepts to Nail Cold

- **Singleton thread safety:** double-checked locking with `volatile`, or Bill Pugh holder idiom (`static` inner class). Enum singleton is serialisation-safe.
- **Strategy vs State:** Strategy swaps algorithm externally (caller chooses). State transitions internally (object changes its own behaviour based on internal state).
- **Open/Closed Principle:** open for extension (add new Strategy/Command), closed for modification (no `if/else` chains to add new behaviour).
- **Back-of-envelope:** 1M DAU × 10 actions/day = 10M writes/day ≈ 115 writes/sec. 1KB per write = 10GB/day ≈ 3.6TB/year.
- **Rate limiting algorithms:** Token Bucket (burst-friendly), Leaky Bucket (smooth output), Sliding Window Counter (accurate, higher memory). Fixed Window is simplest but has boundary burst issue.

---

*Volume 5 of 6 · [Full Handbook](../../book_output/index.html)*
