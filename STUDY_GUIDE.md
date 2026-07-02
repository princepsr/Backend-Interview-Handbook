# Interview Study Guide

A practical, timeline-driven study plan for the Java Backend Interview Handbook. Use this guide to focus your preparation based on your experience level, available time, and target company.

---

## Assess Your Starting Point

### SDE1 (0-2 years)

**Priority order:** Vol 1 (Core Java) → Vol 2 (Spring) → Vol 4 (DB basics) → Vol 6 (Revision)

**Skip initially:** Vol 5 system design depth, Kafka/Redis advanced topics

Focus on getting the fundamentals right. Interviewers at this level test core Java, basic Spring, and SQL. System design is typically lightweight.

---

### SDE2 (2-5 years) — Primary Target

**Use the full handbook.** Follow the 4-week plan below for best results.

All six volumes are fair game. Expect deep questions on multithreading, Spring internals, distributed systems, and at least one LLD design round.

---

### Senior / Staff

**Focus order:** Vol 4 (distributed DBs) → Vol 5 (system design) → Vol 3 (Kafka/microservices) → Vol 1/2 (as refresher)

Interviewers expect you to drive trade-off discussions. Spend more time on Ch17 (distributed DBs), Ch22 (HLD), and Ch21 (LLD with concurrency). Vol 1/2 are revision-only unless you have gaps.

---

## Study Plans by Timeline

### 4-Week Plan (Recommended — SDE2)

#### Week 1: Core Java + Spring

| Day | Topics | Notes |
|-----|--------|-------|
| Day 1 | Ch1 (OOP) + Ch2 (Strings/Wrappers/Exceptions) | Nail polymorphism, immutability |
| Day 2 | Ch3 (Collections) | HashMap internals are critical — spend extra time |
| Day 3 | Ch4 (Java 8+) | Streams, Lambdas, CompletableFuture |
| Day 4 | Ch5 (JVM) + Ch6 Part 1 | Thread basics, synchronized, volatile |
| Day 5 | Ch6 Part 2 | ThreadPool, deadlock, virtual threads |
| Day 6 | Ch7 (Spring Core) + Ch8 (JPA/Hibernate) | @Transactional propagation, N+1 problem |
| Day 7 | Review using Ch23 + Ch24 | Revision chapters — test yourself |

#### Week 2: Backend Systems

| Day | Topics | Notes |
|-----|--------|-------|
| Day 8 | Ch9 (REST APIs) | Must know cold |
| Day 9 | Ch10 (Microservices) | Circuit breaker, saga, distributed tracing |
| Day 10 | Ch11 (Kafka) | Producers, consumers, exactly-once, Spring integration |
| Day 11 | Ch12 (Redis) | Caching patterns, distributed lock, cluster |
| Day 12 | Ch13 (Security) | JWT, OAuth2, Spring Security |
| Day 13 | Review using Ch25 | Revision chapter |
| Day 14 | Mock interview | Pick 5 random questions from Vol 3 |

#### Week 3: Databases

| Day | Topics | Notes |
|-----|--------|-------|
| Day 15 | Ch14 (SQL) | Window functions, CTEs, execution order |
| Day 16 | Ch15 (Indexing) | B-tree, composite index, EXPLAIN |
| Day 17 | Ch16 (ACID) | MVCC, isolation levels, locking |
| Day 18 | Ch17 (Distributed DBs) | Sharding, consistent hashing, Cassandra, DynamoDB |
| Day 19 | Ch18 (Advanced DB) | Connection pooling, zero-downtime migrations |
| Day 20 | Review using Ch26 | Revision chapter |
| Day 21 | SQL practice | Write all 7 patterns from Ch26 Section 6 from memory |

#### Week 4: System Design + LLD

| Day | Topics | Notes |
|-----|--------|-------|
| Day 22 | Ch19 (Design Patterns) | Singleton, Factory, Builder, Proxy, Strategy, Observer |
| Day 23 | Ch20 (SOLID) | Work through BAD/GOOD code examples |
| Day 24 | Ch21 (LLD) | Parking Lot + URL Shortener — design from scratch |
| Day 25 | Ch21 continued | Rate Limiter + BookMyShow — focus on concurrency |
| Day 26 | Ch22 (System Design HLD) | RADIO framework, back-of-envelope, news feed |
| Day 27 | Ch21 + Ch22 | Splitwise + Elevator + 2 HLD designs from scratch |
| Day 28 | Full mock | Ch27 — 100 Q&As + interview checklist |

---

### 2-Week Intensive Plan

#### Week 1: Core + Spring + REST

| Day | Topics |
|-----|--------|
| Days 1-2 | Ch1-Ch3 (OOP, Strings, Collections) |
| Day 3 | Ch4 + Ch5 (Java 8+, JVM) |
| Day 4 | Ch6 (Multithreading) — most important for FAANG |
| Day 5 | Ch7 + Ch8 (Spring + JPA) |
| Day 6 | Ch9 + Ch10 (REST + Microservices) |
| Day 7 | Revision — Ch23 + Ch24 |

#### Week 2: Systems + DB + Design

| Day | Topics |
|-----|--------|
| Day 8 | Ch11 + Ch12 (Kafka + Redis) |
| Day 9 | Ch13 + Ch14 (Security + SQL) |
| Day 10 | Ch15 + Ch16 (Indexing + ACID) |
| Day 11 | Ch17 + Ch18 (Distributed + Advanced DB) |
| Day 12 | Ch19 + Ch20 (Patterns + SOLID) |
| Day 13 | Ch21 (3 LLD designs) + Ch22 (2 HLD designs) |
| Day 14 | Ch27 — 100 mock Q&As + interview checklist |

---

### 1-Week Crash Plan

Focus only on the highest-frequency topics. Skip depth, prioritize breadth and recall.

| Day | Topics | Rationale |
|-----|--------|-----------|
| Day 1 | Ch3 (Collections/HashMap) + Ch6 (Multithreading) | Asked in virtually every backend interview |
| Day 2 | Ch7 + Ch8 (Spring + JPA) | Core of most Java backend roles |
| Day 3 | Ch9 + Ch10 (REST + Microservices) + Ch13 (Security) | Architecture and API essentials |
| Day 4 | Ch14 + Ch15 + Ch16 (SQL, Indexing, ACID) | DB rounds are common at all levels |
| Day 5 | Ch19 + Ch20 (Patterns + SOLID) + 2 LLD designs | LLD is a dedicated round at most companies |
| Day 6 | Ch22 (2 HLD designs) | System design is scored heavily at SDE2+ |
| Day 7 | Ch27 (100 mock Q&As) + all 5 revision chapters | Consolidate and identify gaps |

---

## Topic Priority by Company

### Amazon (Leadership Principles + Technical)

| Area | Chapters |
|------|----------|
| Must master | Ch6 (Multithreading), Ch7/Ch8 (Spring/JPA), Ch10 (Microservices), Ch17 (DynamoDB), Ch22 (System Design) |
| LP alignment | Ownership → design decisions; Dive Deep → internals; Deliver Results → trade-offs in system design |

Expect bar-raiser rounds to challenge your assumptions. Have a real system you built ready to discuss in depth.

---

### Google

| Area | Chapters |
|------|----------|
| Must master | Ch4/Ch5 (Java internals), Ch3 (Collections), Ch22 (System Design), Ch17 (Distributed DBs) |
| Differentiator | Clean code, SOLID (Ch20), algorithm-level thinking embedded in design discussions |

Google rounds weight scalability and code quality heavily. Practice verbalizing trade-offs.

---

### Goldman Sachs / FinTech

| Area | Chapters |
|------|----------|
| Must master | Ch6 (Multithreading), Ch16 (ACID/Transactions), Ch13 (Security), Ch7/Ch8 (Spring/JPA), Ch14 (SQL) |
| Focus | Correctness, transaction safety, concurrency correctness under load |

Expect scenario-based questions: "What happens if two threads update the same account balance simultaneously?"

---

### Stripe / Payments

| Area | Chapters |
|------|----------|
| Must master | Ch9 (REST APIs) — idempotency keys, Ch13 (Security) — OAuth2/JWT, Ch12 (Redis) — distributed lock, Ch11 (Kafka) |
| Focus | API design, distributed systems, fault tolerance, at-least-once vs exactly-once semantics |

Be prepared to design a payment retry system or an idempotent charge API end-to-end.

---

### Atlassian / Salesforce

| Area | Chapters |
|------|----------|
| Must master | Ch7/Ch8 (Spring/JPA), Ch10 (Microservices), Ch19 (Design Patterns), Ch20 (SOLID), Ch21 (LLD) |
| Focus | Clean OOP, extensible design, system design at product scale |

LLD rounds at these companies often ask you to model features from their own products (e.g., Jira board, Confluence page hierarchy).

---

## What Interviewers Actually Test

### Coding Rounds

- **Collections:** HashMap internal workings, ConcurrentHashMap, TreeMap ordering, LinkedHashMap LRU
- **Streams + Lambdas:** Chaining, collectors, parallel streams, short-circuit operations
- **Multithreading:** Race conditions, synchronized blocks, volatile, CountDownLatch, Semaphore
- **Generics:** Bounded wildcards, type erasure — often surfaces in API design questions

### System Design Rounds

- **Back-of-envelope estimation:** Memorize latency numbers (L1 cache ~1 ns, disk seek ~10 ms, network round trip ~150 ms)
- **Trade-off articulation:** Strong consistency vs. availability (CAP theorem in practice), synchronous vs. asynchronous
- **Database selection rationale:** Justify SQL vs. NoSQL with concrete reasons, not buzzwords
- **Use the RADIO framework (Ch22):** Requirements → Architecture → Data model → Interface → Optimizations

### LLD Rounds

1. Start with requirements clarification, not code
2. Identify entities and relationships before writing any classes
3. Draw the class diagram mentally (or on whiteboard) before coding
4. Apply at least 2-3 design patterns naturally — do not force-fit
5. Address concurrency concerns explicitly if the problem involves shared state

### Behavioral / Architecture Rounds

- Prepare one story about the most complex system you built
- Quantify scale: requests per second, data volume, latency SLAs
- Articulate trade-offs you made and what you would do differently today
- Map your story to the company's LPs or engineering values

---

## Quick Reference: Chapter Map

| Volume | Chapters | Theme |
|--------|----------|-------|
| Vol 1 — Core Java | Ch1–Ch6 | OOP, Collections, Java 8+, JVM, Multithreading |
| Vol 2 — Spring | Ch7–Ch8 | Spring Core/Boot, JPA/Hibernate |
| Vol 3 — Backend Systems | Ch9–Ch13 | REST, Microservices, Kafka, Redis, Security |
| Vol 4 — Databases | Ch14–Ch18 | SQL, Indexing, ACID, Distributed DBs, Advanced DB |
| Vol 5 — Design | Ch19–Ch22 | Patterns, SOLID, LLD, HLD |
| Vol 6 — Revision | Ch23–Ch27 | Per-volume revision + 100 mock Q&As + checklist |

---

*Good luck. Consistency beats cramming — two focused hours a day beats one ten-hour session.*

