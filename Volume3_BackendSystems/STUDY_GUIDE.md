# Volume 3: Backend Systems — Study Guide

## Priority Order

| Chapter | Why This Priority | Time Budget |
|---|---|---|
| Ch11 Kafka | Highest interview frequency; failure modes, ordering, delivery semantics are go-to deep-dives | 75 min |
| Ch12 Redis | Eviction, distributed locks, and pub/sub limits trip up most candidates | 60 min |
| Ch10 Microservices | Circuit Breaker, Saga, Outbox are design round staples | 60 min |
| Ch9 REST | Foundational but often underestimated; idempotency and versioning catch people | 45 min |
| Ch13 Security | JWT/OAuth2 tested at security-conscious companies; others treat it as a bonus | 40 min |

---

## 1-Week Plan (1 hr/day)

- **Day 1 — Ch11 Kafka:** Consumer groups, partition-level ordering, at-least-once vs exactly-once, consumer lag and monitoring
- **Day 2 — Ch12 Redis:** Eviction policies (LRU/LFU), data structures and when to pick each, Redlock for distributed locking, why pub/sub is not durable
- **Day 3 — Ch10 Microservices:** Circuit Breaker states, Saga (choreography vs orchestration), Outbox pattern, service mesh basics (sidecar, mTLS)
- **Day 4 — Ch9 REST:** Idempotency keys, HATEOAS trade-offs, versioning strategies (URI vs header), gRPC vs REST decision framework
- **Day 5 — Ch13 Security:** JWT signature validation (not just decoding), OAuth2 authorization code flow, CORS preflight, CSRF token vs SameSite cookie
- **Day 6 — Practice:** Design a Kafka-backed notification system end-to-end: producers, topics, consumer groups, dead-letter queue, Redis for dedup/rate-limit, REST API for delivery status
- **Day 7 — Vol6 Ch25 Revision:** Self-test on Q1 (Kafka delivery), Q4 (Redis eviction), Q7 (Circuit Breaker), Q9 (idempotency), Q12 (OAuth2 flow)

---

## 3-Day Crash

- **Day 1 — Ch11 Kafka + Ch12 Redis:** Delivery semantics, consumer lag, eviction, distributed lock — highest return on time
- **Day 2 — Ch10 Microservices patterns:** Circuit Breaker, Saga, Outbox; be ready to draw a failure-recovery flow
- **Day 3 — Vol6 Ch25 Revision:** Run the 5 Q numbers above as a timed mock

---

## What Interviewers Test in Backend Systems Rounds

- They do not stop at "what is Kafka" — they ask what happens when a consumer crashes mid-batch and whether you get duplicates, reordering, or both
- Delivery guarantee questions always probe the gap between producer acks, broker replication, and consumer commit timing
- Ordering constraints: they expect you to know partition-level ordering and the implications of increasing partition count after creation
- Failure modes: Redis without persistence losing a distributed lock, Kafka consumer lag causing cascading timeouts, circuit breaker in half-open state rejecting valid traffic
- They test whether you know when *not* to use a technology — "use Kafka for everything" or "Redis is always faster" are red flags

---

## Top 10 Backend Systems Questions

1. Explain Kafka's delivery semantics — at-most-once, at-least-once, exactly-once. How do you achieve exactly-once end-to-end?
2. Two consumers in the same consumer group both read the same message — why, and how do you prevent it?
3. How does consumer lag occur and how do you detect and recover from it?
4. What Redis eviction policy would you choose for a session cache under memory pressure, and why?
5. Why is Redis pub/sub not suitable for reliable messaging? What do you use instead?
6. Walk me through the Circuit Breaker state machine — Closed, Open, Half-Open. What triggers each transition?
7. Saga pattern: choreography vs orchestration — when do you choose each, and what are the failure recovery differences?
8. What is the Outbox pattern and why does it solve dual-write without distributed transactions?
9. How do you implement idempotency in a REST API receiving duplicate POST requests?
10. Explain OAuth2 authorization code flow — what does each token (access, refresh, ID) represent and where should each be stored?

---

## Common Mistakes

1. **"Use Kafka for everything"** — interviewers probe SQS/RabbitMQ tradeoffs; Kafka's complexity is a cost, not a feature
2. **Ignoring consumer lag** — treating Kafka as a solved problem once producers are healthy; lag is where production incidents live
3. **Redis as a database** — not mentioning persistence options (RDB/AOF) and what you lose when Redis restarts without them
4. **Conflating authentication and authorization** — saying "JWT handles security" without distinguishing token validation from permission checks
5. **Saga without rollback planning** — describing the happy path only; interviewers want to hear how you compensate for step 3 failing after steps 1 and 2 committed
