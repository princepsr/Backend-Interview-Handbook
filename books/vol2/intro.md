# Volume 2: Spring Ecosystem

**2 chapters · ~60+ Q&As · Spring Boot 3.x · Java 17**

Spring is the default framework for Java backend roles. Interviewers assume you use it daily and probe its internals — not just how to use annotations, but what happens underneath them. This volume covers Spring Core/Boot and Spring Data JPA + Hibernate in the depth expected at SDE2 level.

---

## What's In This Volume

| Chapter | Topic | Interview Weight |
|---------|-------|-----------------|
| Ch 7 | Spring Core & Boot | **Very High** — IoC, AOP, `@Transactional`, auto-configuration |
| Ch 8 | Spring Data JPA & Hibernate | **Very High** — N+1 problem, fetch strategies, second-level cache |

---

## Study Plan for This Volume

### 4-Week Plan (Day 6 of Week 1)

| Day | Chapters | Focus |
|-----|---------|-------|
| Day 6 | Ch7 + Ch8 | `@Transactional` propagation types, N+1 detection with `EAGER` vs `LAZY`, proxy pitfalls |

> After finishing this volume, validate with **Chapter 24** (Spring & JPA Revision) in the Revision Pack.

> **Note:** Vol 2 is short but extremely dense. Allocate more than one day if Spring is not your daily driver — Ch7 alone contains 30+ Q&As at SDE2 depth.

### Crash Plan (1 week total — Day 2 of 7)

Read Ch7 + Ch8 back to back. Focus on: `@Transactional` propagation, `REQUIRES_NEW` vs `NESTED`, `@Async` proxy gotcha, N+1 problem detection and fix (`@EntityGraph` or `JOIN FETCH`).

---

## Company Focus

### Amazon
- **Ch7** — `@Transactional` propagation: `REQUIRED` vs `REQUIRES_NEW` with concrete rollback scenarios
- **Ch8** — N+1 problem diagnosis using `show_sql`, fix with batch fetching or `JOIN FETCH`
- Expect: "Walk me through what happens when `@Transactional(propagation = REQUIRES_NEW)` is called from within the same bean"

### Atlassian / Salesforce
- **Ch7** — Spring AOP: pointcut expressions, advice ordering, `@Around` vs `@Before`
- **Ch8** — `@ManyToMany` mapping pitfalls, bidirectional consistency, `CascadeType.MERGE` vs `PERSIST`
- LLD rounds sometimes model a Spring service — know how beans wire together

### Goldman Sachs / FinTech
- **Ch7** — Transaction isolation levels mapped to Spring: `@Transactional(isolation = SERIALIZABLE)` and its performance cost
- **Ch8** — Optimistic vs pessimistic locking (`@Version` vs `PESSIMISTIC_WRITE`), deadlock risks under concurrent updates

### Stripe / Payments
- **Ch7** — Idempotency at the service layer: `@Transactional` + idempotency key pattern
- **Ch8** — Database sequence vs UUID primary key trade-offs at payment-level write throughput

---

## Key Concepts to Nail Cold

- **Bean lifecycle:** instantiation → dependency injection → `@PostConstruct` → use → `@PreDestroy`. `BeanPostProcessor` hooks.
- **`@Transactional` proxy:** only works on public methods called from outside the bean — self-invocation bypasses the proxy
- **Propagation types:** `REQUIRED` (join or create), `REQUIRES_NEW` (always new, suspends outer), `NESTED` (savepoint — needs JDBC support)
- **N+1 problem:** caused by `LAZY` collections accessed in a loop after session scope. Fix: `JOIN FETCH` in JPQL, `@EntityGraph`, or `@BatchSize`
- **First vs second-level cache:** L1 is per-session (always on). L2 is per-SessionFactory (opt-in, needs provider like Ehcache/Redis)
- **`@Async` gotcha:** same proxy limitation as `@Transactional` — calling `@Async` from the same bean runs synchronously

---

*Volume 2 of 6 · [Full Handbook](../../book_output/index.html)*
