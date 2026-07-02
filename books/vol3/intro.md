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

## Study Plan for This Volume

### 4-Week Plan (Days 8–14 of Week 2)

| Day | Chapter | Focus |
|-----|---------|-------|
| Day 8  | Ch9  | REST design principles, idempotency keys, HTTP status code semantics |
| Day 9  | Ch10 | Circuit breaker (Resilience4j), saga pattern (choreography vs orchestration), distributed tracing |
| Day 10 | Ch11 | Kafka producer acks, consumer group rebalancing, exactly-once semantics |
| Day 11 | Ch12 | Cache-aside vs write-through, Redisson distributed lock, Redis Cluster hash slots |
| Day 12 | Ch13 | OAuth2 flows (auth code + PKCE), JWT validation chain, Spring Security filter order |
| Day 13 | Review | Ch25 (Backend Systems Revision) |
| Day 14 | Mock  | Pick 5 random questions from this volume — answer out loud |

> After finishing this volume, validate with **Chapter 25** (Backend Systems Revision) in the Revision Pack.

### Crash Plan (1 week total — Day 3 of 7)

Ch9 + Ch10 + Ch13. These three cover the interview topics that appear in almost every microservices role. Kafka and Redis (Ch11/Ch12) are specialised — only prioritise if the job description mentions them.

---

## Company Focus

### Stripe / Payments
- **Ch9** — Idempotency keys as a first-class API design pattern; exactly-once payment charge design
- **Ch11** — At-least-once vs exactly-once delivery; Kafka transactions for payment event streams
- **Ch12** — Distributed lock with Redlock for preventing double-charge race conditions
- **Ch13** — OAuth2 Authorization Code + PKCE; token rotation; mTLS for service-to-service calls
- Be prepared to design a payment retry system or an idempotent charge API end-to-end

### Amazon
- **Ch10** — Service discovery (AWS Cloud Map), circuit breaker + bulkhead patterns, API Gateway integration
- Expect: "Your downstream service is slow — how do you prevent cascade failure across 15 microservices?"

### Google
- **Ch10** — Distributed tracing (OpenTelemetry), back-pressure, async event-driven decomposition
- **Ch13** — JWT claims validation, service mesh (Istio) vs application-layer auth

### Goldman Sachs / FinTech
- **Ch9** — REST vs gRPC trade-offs for high-frequency trading APIs
- **Ch13** — Mutual TLS, certificate rotation, Spring Security method-level security (`@PreAuthorize`)

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
