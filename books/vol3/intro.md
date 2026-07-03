# Volume 3: Backend Systems

**5 chapters · ~120+ Q&As · Spring Boot 3.x · Kafka · Redis**

This volume covers the distributed systems layer that separates SDE2 from SDE1 candidates. REST API design, microservice patterns, Kafka, Redis, and security are all dedicated interview topics — particularly at Stripe, Amazon, and any company running a service-oriented architecture.

---

## What's In This Volume

| Chapter | Topic | Interview Weight |
|---------|-------|-----------------|
| Ch 9  | REST APIs & Web | High — idempotency, versioning, HTTP semantics |
| Ch 10 | Microservices Architecture | **Very High** — circuit breaker, saga, distributed tracing |
| Ch 11 | Apache Kafka | High — producers, consumers, exactly-once, Spring Kafka |
| Ch 12 | Redis & Caching | High — eviction policies, distributed lock, cluster |
| Ch 13 | Security (OAuth2, JWT, TLS) | High — token flow, Spring Security filter chain |

---

- [Volume 3 Study Plan](STUDY_GUIDE.md) — 1-week plan, 3-day crash plan, top 10 questions, and daily practice tips.
- [Volume 3 Company Guide](COMPANY_GUIDE.md) — which companies go deep on Backend Systems and what they specifically test.

---

## Key Concepts to Nail Cold

- **Idempotency key:** client-generated UUID sent in request header; server stores `(key → result)` in DB/Redis before processing. Prevents duplicate charges on retry.
- **Circuit breaker states:** Closed (normal) → Open (failing, reject fast) → Half-Open (probe with one request). Resilience4j `@CircuitBreaker` annotation.
- **Saga pattern:** Choreography (each service emits events, no central coordinator) vs Orchestration (saga orchestrator sends commands). Compensating transactions on failure.
- **Kafka consumer group:** each partition assigned to exactly one consumer in a group. Rebalancing triggered by consumer join/leave or `session.timeout.ms` expiry.
- **Exactly-once in Kafka:** `enable.idempotence=true` (producer) + `isolation.level=read_committed` (consumer) + `transactional.id` for cross-partition atomicity.
- **Cache-aside pattern:** app checks cache → on miss, loads from DB → writes to cache. Cache-through: write to cache, cache syncs to DB.
- **JWT validation:** verify signature → check `exp` claim → check `iss`/`aud` — in that order. Never skip signature verification.

---

*Volume 3 of 6 · [Full Handbook](../../book_output/index.html)*
