# Volume 6: Revision Pack — Company-Specific Revision Strategy

## Which Revision Chapters to Prioritise Per Company

| Company | Must Revise | Skim | Skip if Short on Time |
|---|---|---|---|
| Google | Ch27 (HLD deep), Ch23 (Java internals) | Ch25 (backend systems) | Ch24 Spring/JPA |
| Meta / Facebook | Ch27 (HLD + LLD), Ch23 | Ch25 | Ch26 DB (unless data-heavy role) |
| Amazon | Ch27 (HLD), Ch25 (queues, reliability) | Ch23, Ch26 | Ch24 (unless Spring role) |
| Uber / Lyft / Swiggy | Ch27 (HLD geo/streaming), Ch25 | Ch26 (geo indexes) | Ch24 |
| Netflix | Ch27 (HLD CDN/recommendation), Ch25 | Ch23 | Ch24, Ch26 |
| Atlassian / Salesforce | Ch27 (LLD heavy), Ch24 (Spring/JPA) | Ch23, Ch26 | Ch25 |
| Stripe / Razorpay / CRED | Ch27 (API design), Ch26 (DB consistency) | Ch25, Ch23 | Ch24 (unless Java-heavy role) |
| Flipkart / Meesho / Amazon India | Ch27 (HLD), Ch25, Ch26 | Ch23 | Ch24 |
| Goldman / Morgan Stanley | Ch23 (Java internals), Ch26 (DB) | Ch25 | Ch27 (unless platform role) |
| Startup (unknown stack) | Ch27 Q1–Q10, Ch23 one-liners | Ch24, Ch25 | Deep dives in any chapter |

---

## Company-Type Revision Profiles

### Product — Amazon, Google, Meta, Flipkart

**Must revise**: Ch27 Q1–Q40 (HLD), Ch23 Q on JVM internals, concurrency, collections.

**Specific Q numbers (Ch27)**: Q1–Q10 (top HLD designs), Q21–Q30 (distributed systems trade-offs), Q41–Q50 (LLD for product entities like feed, notifications).

**Key focus**: scale reasoning, trade-off articulation, failure handling. Interviewers expect you to volunteer non-functional requirements before being asked.

---

### FinTech — Goldman Sachs, Stripe, Razorpay, CRED

**Must revise**: Ch26 Q on ACID, isolation levels, distributed transactions. Ch27 Q11–Q20 (API design, idempotency). Ch23 Q on concurrency (locks, atomic ops).

**Specific Q numbers (Ch27)**: Q11–Q20 (consistency, idempotency, API versioning), Q71–Q80 (reliability patterns: circuit breaker, retry, saga).

**Key focus**: correctness over throughput. Every design decision needs a consistency argument. Mention exactly-once semantics, idempotency keys, and reconciliation pipelines.

---

### Enterprise SaaS — Atlassian, Salesforce

**Must revise**: Ch27 Q41–Q60 (LLD case studies), Ch24 Q on JPA relationships, lazy loading, N+1. Ch20-mapped Q in Ch27 on SOLID and patterns.

**Specific Q numbers (Ch27)**: Q41–Q60 (LLD designs), Q81–Q90 (design patterns applied to real systems).

**Key focus**: extensibility and multi-tenancy. Every LLD answer should mention interfaces over concrete classes, open-closed principle, and how a new type would be added without modifying existing code.

---

### Ride / Real-time — Uber, Lyft, Swiggy, Zepto, Dunzo

**Must revise**: Ch27 Q21–Q30 (geo systems, streaming, real-time matching), Ch25 Q on message queues, WebSockets, event streaming.

**Specific Q numbers (Ch27)**: Q21–Q30 (location tracking, ride matching), Q61–Q70 (trade-off deep dives).

**Key focus**: latency over consistency. Know geohashing and quadtrees. Know when to use Redis vs Kafka vs a DB. Driver location writes are very high frequency — the data model matters.

---

### Streaming / Content — Netflix

**Must revise**: Ch27 Q31–Q40 (CDN, recommendation, video pipeline), Ch25 Q on caching strategies and async processing.

**Specific Q numbers (Ch27)**: Q31–Q40 (Netflix-class designs), Q61–Q70 (trade-offs: availability vs consistency).

**Key focus**: availability over consistency, graceful degradation. Every service must degrade independently. Know adaptive bitrate streaming at a high level. Recommendation systems need feature pipeline design, not just ML model selection.

---

## 10 Q&As That Come Up in Every Interview

These are the most universally tested questions across company types. If you only have time for 10, do these.

| # | Question | One-Liner Answer |
|---|---|---|
| Ch23-Q1 | What happens during JVM class loading? | Bootstrap → Extension → Application classloader; loads, links (verify/prepare/resolve), then initialises. |
| Ch23-Q4 | How does HashMap handle collisions in Java 8+? | Chaining via linked list; converts to balanced tree (TreeMap) when bucket size exceeds 8. |
| Ch23-Q9 | What is the difference between synchronized and ReentrantLock? | Both provide mutual exclusion; ReentrantLock adds tryLock, fairness policy, and interruptible waiting. |
| Ch24-Q3 | What is the N+1 select problem and how do you fix it? | One query fetches N parents, then N separate queries fetch children; fix with JOIN FETCH or @BatchSize. |
| Ch25-Q2 | When do you choose a message queue over a synchronous REST call? | When the caller does not need an immediate result, or when you need durability, fan-out, or decoupling under load. |
| Ch26-Q1 | What are the four ACID properties? | Atomicity (all-or-nothing), Consistency (valid state to valid state), Isolation (concurrent txns don't interfere), Durability (committed data survives crash). |
| Ch26-Q5 | What is the difference between Read Committed and Repeatable Read isolation? | Read Committed prevents dirty reads; Repeatable Read additionally prevents non-repeatable reads; neither prevents phantom reads (need Serializable). |
| Ch27-Q1 | Walk me through how you would design a URL shortener. | Clarify scale → hash strategy (base62 counter or MD5 truncated) → redirect flow → cache hot URLs → analytics pipeline → expiry handling. |
| Ch27-Q3 | How would you design a rate limiter? | Token bucket or sliding window log → Redis for distributed state → atomic INCR + TTL → place at API gateway layer. |
| Ch27-Q5 | What is the difference between fan-out on write and fan-out on read? | On write: pre-populate each follower's timeline at post time — fast reads, expensive writes. On read: aggregate at read time — cheaper writes, slower reads. Hybrid for celebrity accounts. |

---

## Last 24 Hours Checklist

Work through this list in order. Stop when you run out of time — the items are ranked by return on investment.

- [ ] Write the 7-step system design framework from memory (no notes).
- [ ] Speak aloud the one-liner answer for the 10 Q&As in the table above.
- [ ] Review Ch27 Q numbers matching your target company type (see table above).
- [ ] Re-read "Common Mistakes" section of Vol 5 Study Guide.
- [ ] Say out loud: one trade-off for SQL vs NoSQL, one for sync vs async, one for cache-aside vs write-through.
- [ ] Confirm your environment: interview link, time zone, working IDE/whiteboard tool.
- [ ] Sleep 7+ hours. Fatigue costs more points than one extra hour of revision.
