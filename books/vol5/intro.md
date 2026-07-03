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

- [Volume 5 Study Plan](STUDY_GUIDE.md) — 1-week plan, 3-day crash plan, top 10 questions, and daily practice tips.
- [Volume 5 Company Guide](COMPANY_GUIDE.md) — which companies go deep on System Design/LLD and what they specifically test.

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
