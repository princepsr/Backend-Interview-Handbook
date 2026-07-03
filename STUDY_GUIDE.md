# Backend Interview Handbook — Study Guide

> **Who this is for:** Java/Spring backend engineers at SDE1–Staff level, targeting product-based companies. This guide covers all 27 chapters across 6 volumes. Read Section 2 first. Pick your plan. Execute.

---

## Table of Contents

1. [How to Use This Handbook](#1-how-to-use-this-handbook)
2. [Self-Assessment: Know Your Starting Point](#2-self-assessment-know-your-starting-point)
3. [Plan A — 1-Week Crash Plan](#3-plan-a--1-week-crash-plan)
4. [Plan B — 4-Week Thorough Plan](#4-plan-b--4-week-thorough-plan)
5. [Plan C — 8-Week Deep Dive](#5-plan-c--8-week-deep-dive)
6. [What Interviewers Actually Test](#6-what-interviewers-actually-test)
7. [Topic Priority Heat Map](#7-topic-priority-heat-map)
8. [Daily Practice Rituals](#8-daily-practice-rituals)
9. [Chapter Map Quick Reference](#9-chapter-map-quick-reference)

---

## 1. How to Use This Handbook

This handbook has 27 chapters in 6 volumes. You do not read it cover to cover. You use one of three structured plans based on your timeline and starting point.

**The three plans:**

| Plan | Timeline | Daily Commitment | Best For |
|------|----------|------------------|----------|
| Plan A | 1 week | 5–6 hrs/day | Interview in < 2 weeks, already have Java/Spring fundamentals |
| Plan B | 4 weeks | 2 hrs/day | Most candidates — solid preparation without burning out |
| Plan C | 8 weeks | 1.5 hrs/day | Deep preparation, switching domains, or gaps in fundamentals |

**How Vol 6 fits in:** Vol 6 (Ch23–27) is a revision-only volume. It has no new concepts — only Q&As and quick-recall exercises drawn from Vols 1–5. Every plan ends each day or week with specific Vol 6 Q&As. Do not skip these. The Q&A format forces you to retrieve information from memory, which is the only thing that actually prepares you for an interview. Reading passively does not prepare you. Answering out loud does.

**How Interview Lens Q&As work:** Every chapter has Interview Lens questions. These are not comprehension checks — they are simulation questions. When you reach one, close the chapter, answer it out loud or in writing without looking, then re-open and compare. If your answer missed key points, re-read that section and answer again. One honest attempt is worth ten passive reads.

---

## 2. Self-Assessment: Know Your Starting Point

Answer these questions honestly. Do not aim for the plan that flatters you — aim for the one that fills your actual gaps.

---

### Profile 1: SDE1 / Fresh (0–2 years experience)

**What you likely know:**
- Basic Java syntax, OOP principles at the surface level
- Used Spring Boot to build something but don't know why annotations work
- Written SQL queries but never thought about indexes or execution plans
- Never designed a distributed system from scratch

**Self-assessment questions:**
- [ ] Can you explain why HashMap resizes and what happens to elements during resize?
- [ ] Can you explain what happens when Spring Boot starts — bean lifecycle, ApplicationContext?
- [ ] Can you describe what a Kafka consumer group does and why partition count matters?
- [ ] Can you walk through what happens during a database transaction with two concurrent writers?
- [ ] Can you design a URL shortener in 30 minutes, explaining every trade-off?

If you said "no" or "not confidently" to 3 or more: **use Plan C**.
If 1–2: **use Plan B**, but spend extra time on Vol 1 Ch5 (JVM) and Vol 4 Ch16 (ACID).

**Biggest gap:** Java internals and systems thinking. You know syntax; you do not yet know *why* things work. Vol 1 Ch5 (JVM), Ch6 (Multithreading), and Vol 4 Ch15–16 will close this gap faster than anything else.

---

### Profile 2: SDE2 / Mid (2–4 years experience)

**What you likely know:**
- Java collections, generics, streams — comfortable
- Spring Boot with JPA — built production features
- REST APIs, basic microservices, maybe used Kafka once
- SQL joins, basic indexes — functional but not deep

**Self-assessment questions:**
- [ ] Can you explain ConcurrentHashMap's internal segment locking vs. HashMap?
- [ ] Can you explain Spring's `@Transactional` propagation levels with a concrete edge case?
- [ ] Can you explain Kafka's exactly-once semantics and when it breaks?
- [ ] Can you explain the difference between optimistic and pessimistic locking and when to use each?
- [ ] Can you design a distributed rate limiter — what are the trade-offs between token bucket in Redis vs. API gateway?

If you said "no" to 3 or more: **use Plan B**.
If 1–2: **use Plan A** only if your interview is genuinely imminent; otherwise Plan B.

**Biggest gap:** Distributed systems depth and trade-off articulation. You have surface-level knowledge of Kafka and Redis. Interviewers at product companies test whether you understand *why* you'd choose a technology and what breaks. Vol 3 (Ch11–12) and Vol 5 (Ch22) are your highest ROI.

---

### Profile 3: Senior / Staff (4+ years experience)

**What you likely know:**
- Java internals, JVM tuning, concurrency patterns
- Spring ecosystem deeply — AOP, transaction management, bean scopes
- Kafka, Redis, distributed systems — hands-on production experience
- Database performance, query optimization

**Self-assessment questions:**
- [ ] Can you articulate the trade-off between saga choreography vs. orchestration with a concrete example of when each fails?
- [ ] Can you walk through a full system design for a payments ledger — consistency model, partitioning strategy, failure modes?
- [ ] Can you critique your own LLD design — which SOLID principle does it violate and why was that an acceptable trade-off?
- [ ] Can you explain how you'd debug a P99 latency spike in a Spring microservice under load?
- [ ] Can you explain why a particular index is or isn't used in a query, given the query and explain plan?

If you hesitated on 2+: **use Plan B**, focusing on Vol 5 (Ch19–22) and Vol 4 (Ch17–18).
Confident on all: **use Plan A** for final polish, or cherry-pick from Plan B Week 4.

**Biggest gap:** Trade-off articulation and LLD depth. You have the knowledge. The gap is communicating it under pressure in 45 minutes — making the right call fast, explaining it clearly, and defending your choices. Vol 5 Ch21 (LLD Case Studies) and Ch22 (System Design HLD) are your focus.

---

## 3. Plan A — 1-Week Crash Plan

**Prerequisite:** You already have working knowledge of Java and Spring. This plan hits the highest-ROI topics only. It does not cover everything — it covers what appears most in interviews.

**Time budget:** 5 hrs/day (2hr morning + 2hr afternoon + 1hr evening revision)

> **Note:** Items marked ⚡ Skip if short on time are lower-frequency interview topics. Cut these before cutting anything else.

---

### Monday — Core Java Foundations

**Morning (2hr):** Ch1 OOP — focus on polymorphism, interface vs abstract class, why you'd use each. Ch3 Collections — HashMap internals (hashing, collision, resize), ConcurrentHashMap vs synchronized, when to use LinkedHashMap.

**Afternoon (2hr):** Ch6 Multithreading — synchronized vs ReentrantLock, volatile, thread pools (Executors), CountDownLatch/CyclicBarrier use cases. Ch4 Java8+ — streams, Optional, CompletableFuture basics.

**Evening revision (1hr):** Open Ch23 (Core Java Revision). Answer these Q&As out loud: HashMap vs ConcurrentHashMap, what is memory visibility, explain `volatile`. Write answers on paper first, then check.

⚡ Skip if short on time: Ch2 (Strings/Wrappers/Exceptions) — low interview frequency for SDE2+. Ch5 (JVM) — skim only, full depth not needed for crash prep.

**Daily goal check:** Can you explain why HashMap is not thread-safe at the code level? Can you write a simple thread pool using ExecutorService?

---

### Tuesday — Spring Ecosystem

**Morning (2hr):** Ch7 Spring Core/Boot — IoC container, bean lifecycle, `@Component` vs `@Bean`, ApplicationContext startup sequence. Scope types — singleton vs prototype in multi-threaded context.

**Afternoon (2hr):** Ch7 continued — AOP internals (proxy-based, when `@Transactional` fails on same-class calls). Ch8 JPA/Hibernate — N+1 problem, fetch types, `@Transactional` propagation levels (REQUIRED vs REQUIRES_NEW), optimistic vs pessimistic locking.

**Evening revision (1hr):** Ch24 (Spring/JPA Revision). Answer: Why does `@Transactional` on a private method not work? What is the N+1 problem and three ways to fix it?

⚡ Skip if short on time: Spring Security basics in Ch13 — cover only if Security round is expected.

**Daily goal check:** Can you explain what happens when Spring's `@Transactional` method calls another `@Transactional` method in the same class?

---

### Wednesday — Backend Systems: Kafka + Redis

**Morning (2hr):** Ch11 Kafka — topics, partitions, consumer groups, offset management. Why partition count matters. At-most-once vs at-least-once vs exactly-once. When Kafka is the wrong choice.

**Afternoon (2hr):** Ch12 Redis/Caching — data structures and when to use each (String, Hash, Sorted Set, List). Cache-aside vs write-through vs write-behind. Cache stampede and solutions. Redis as distributed lock (Redlock caveats).

**Evening revision (1hr):** Ch25 (Backend Systems Revision). Answer: How would you design a leaderboard using Redis? What happens to Kafka message ordering when you add a partition?

⚡ Skip if short on time: Ch10 Microservices patterns — skim only the saga pattern section, skip circuit breaker deep dive.

**Daily goal check:** Design a notification system that guarantees at-least-once delivery using Kafka. What can go wrong?

---

### Thursday — Databases

**Morning (2hr):** Ch14 SQL — window functions, CTEs, JOIN types. Practice: write a query to find the second-highest salary per department. Ch15 Indexing — B-tree vs hash index, composite index column order, covering index, when an index is ignored by the optimizer.

**Afternoon (2hr):** Ch16 ACID/Transactions — isolation levels (Read Committed vs Repeatable Read vs Serializable), what phantom read is, when you'd use each level. Ch17 Distributed DBs — CAP theorem (be precise: it's about partitions, not a permanent trade-off), eventual consistency, read-your-writes.

**Evening revision (1hr):** Ch26 (DB Revision). Answer: What is a phantom read? What isolation level prevents it? Explain CAP theorem in one sentence without mentioning "trade-off between availability and consistency."

⚡ Skip if short on time: Ch18 (Advanced DB) — skip entirely in crash prep.

**Daily goal check:** Given a slow query, walk through your debugging process. What do you look at first?

---

### Friday — System Design

**Morning (2hr):** Ch22 System Design HLD — the 5-step framework: requirements → capacity → API design → component design → deep dive. Practice: design a URL shortener. Time yourself: 30 minutes, no notes.

**Afternoon (2hr):** Ch19 Design Patterns — Factory, Singleton (thread-safe impl), Strategy, Observer, Builder. Know when to use, not just definitions. Ch20 SOLID — each principle with a concrete violation example and fix.

**Evening revision (1hr):** Ch27 (System Design/LLD Revision). Answer: Design a rate limiter. What are three different implementation approaches and their trade-offs?

⚡ Skip if short on time: Ch21 LLD Case Studies — skim one case study (Parking Lot or Library Management), do not attempt all.

**Daily goal check:** Can you design a system under constraints you haven't prepared for? Try: design a distributed job scheduler in 30 minutes.

---

### Saturday — REST, Security, and Microservices

**Morning (2hr):** Ch9 REST APIs — HTTP methods, idempotency, status codes (know 200/201/204/400/401/403/404/409/422/500), versioning strategies, pagination. Ch10 Microservices — service discovery, API gateway, circuit breaker pattern, saga pattern (choreography vs orchestration).

**Afternoon (2hr):** Ch13 Security — JWT (what's in a token, when it expires, how to revoke — this is a common interview trap), OAuth2 flows, HTTPS basics. Ch9 continued — rate limiting in REST context.

**Evening revision (1hr):** Ch25 (Backend Systems Revision). Answer: How do you handle distributed transactions across two microservices without a shared database? What is the saga pattern?

**Daily goal check:** What is the difference between authentication and authorization? How does JWT handle stateless auth, and what is the revocation problem?

---

### Sunday — Full Revision + Mock

**Morning (2hr):** Re-read your weakest day's notes. Do not re-read all chapters — pick the 3 topics you hesitated on most. Answer their Vol 6 Q&As again.

**Afternoon (2hr):** Simulate a full interview loop. Pick one of these:
- System design: Design Twitter's feed system (30 min)
- LLD: Design a parking lot (30 min)
- Verbal: Answer "Tell me about a technical decision you made that you later regretted" — structure: situation, decision, outcome, what you'd do differently

**Evening (1hr):** Review anything you still feel shaky on. Write down 5 questions you'd ask an interviewer about their system. This signals seniority.

---

## 4. Plan B — 4-Week Thorough Plan

**Commitment:** 2 hours/day, 6 days/week (Sunday is light review or rest)

**Structure:** Each day has a reading focus, a practice task, and two end-of-day self-check questions you answer from memory before sleeping. End of each week is a mini self-test.

---

### Week 1 — Core Java + Spring (Vol 1 + Vol 2)

**Day 1 (Monday):** Read Ch1 OOP. Practice: write a polymorphism example from scratch — interface with default method, abstract class, and concrete implementations. When would you use each?
- Self-check: What is the difference between method overloading and overriding? What is covariant return type?

**Day 2 (Tuesday):** Read Ch2 Strings/Wrappers/Exceptions. Practice: explain String pool and `intern()`. Write a custom checked exception with a cause chain.
- Self-check: Why is String immutable in Java? What is the difference between `throw` and `throws`?

**Day 3 (Wednesday):** Read Ch3 Collections. Practice: implement a simple LRU cache using LinkedHashMap (override `removeEldestEntry`). Time yourself — 15 minutes.
- Self-check: What is the load factor in HashMap? What is a ConcurrentModificationException and how do you avoid it?

**Day 4 (Thursday):** Read Ch4 Java8+. Practice: write a stream pipeline that filters, maps, and collects; then rewrite the same logic with method references. Add a `CompletableFuture` that chains two async tasks.
- Self-check: What is the difference between `map` and `flatMap`? When does `Optional.get()` throw?

**Day 5 (Friday):** Read Ch5 JVM. Focus on GC types (G1 vs ZGC), heap vs stack, classloading, and when to tune. Practice: explain what happens to an object from creation to GC.
- Self-check: What is stop-the-world in GC? What is metaspace?

**Day 6 (Saturday):** Read Ch6 Multithreading. Practice: write a producer-consumer using BlockingQueue. Then write the same using wait/notify — understand why BlockingQueue is preferred.
- Self-check: What is a deadlock? Write the four conditions. What is the difference between `synchronized` and `ReentrantLock`?

**End of Week 1 Mini Self-Test — Vol 6 Ch23 Q&As:**
Answer these five from memory before checking:
1. Explain HashMap's internal structure and what happens on hash collision.
2. What is the Java memory model and why does it matter for multithreading?
3. What are functional interfaces? Name four from `java.util.function`.
4. Explain G1 GC — how does it divide the heap and what is its goal?
5. What is a thread-local variable and when would you use it?

---

**Day 7 (Monday, Week 1 cont):** Read Ch7 Spring Core/Boot. Focus on IoC, bean lifecycle (BeanPostProcessor, InitializingBean), and how ApplicationContext starts. Practice: trace through a Spring Boot startup — what happens before `main()` returns?
- Self-check: What is the difference between `@Component`, `@Service`, `@Repository`? Are they functionally different?

**Day 8 (Tuesday):** Read Ch7 continued — AOP. Focus on proxy mechanism (JDK dynamic proxy vs CGLIB), pointcut expressions, and why `@Transactional` fails when called from the same class.
- Self-check: What is an aspect, advice, joinpoint, and pointcut? Give one real use case for AOP beyond transactions.

**Day 9 (Wednesday):** Read Ch8 JPA/Hibernate first-level cache, second-level cache, fetch types. Practice: write a JPQL query that avoids N+1 using JOIN FETCH. Then explain what `@EntityGraph` does differently.
- Self-check: What is N+1? How does `FetchType.LAZY` interact with transactions?

**Day 10 (Thursday):** Read Ch8 continued — `@Transactional` propagation levels. Practice: write a scenario where REQUIRES_NEW causes data inconsistency (a method saves a log entry even when the outer transaction rolls back — is that intentional?).
- Self-check: What is `PROPAGATION_REQUIRES_NEW` and when is it dangerous? What is optimistic locking and what exception does it throw?

**End of Week 1 Part 2 Mini Self-Test — Vol 6 Ch24 Q&As:**
1. What is Spring's bean lifecycle? Name five key stages.
2. When does `@Transactional` not work and why?
3. What is the N+1 problem? Show three solutions ranked by preference.
4. Explain the difference between first-level and second-level cache in Hibernate.
5. What is `@EnableAutoConfiguration` doing under the hood?

---

### Week 2 — Backend Systems (Vol 3)

**Day 11 (Monday):** Read Ch9 REST APIs. Focus on idempotency (PUT vs POST), status codes (know the non-obvious ones: 202, 409, 422), and API versioning strategies. Practice: design a REST API for a hotel booking system — routes, status codes, pagination.
- Self-check: What makes an HTTP method idempotent? What is the difference between 401 and 403?

**Day 12 (Tuesday):** Read Ch10 Microservices — service discovery (Eureka, Consul), API gateway responsibilities, circuit breaker (when does it open, half-open state). Practice: draw the request flow for a microservice call with service discovery, load balancing, and circuit breaker.
- Self-check: What is the circuit breaker pattern? What is the difference between a gateway and a reverse proxy?

**Day 13 (Wednesday):** Read Ch10 continued — saga pattern. Practice: design a saga for an e-commerce order flow (inventory reserve → payment → fulfillment). Write out compensating transactions for each step. Do both choreography and orchestration versions.
- Self-check: What is the difference between saga choreography and orchestration? When does choreography fall apart at scale?

**Day 14 (Thursday):** Read Ch11 Kafka. Focus on partition assignment, consumer group rebalancing, offset commit strategies, and exactly-once semantics. Practice: explain what happens when a Kafka consumer crashes mid-processing — what messages are replayed, what can be duplicated?
- Self-check: What is a consumer group? Why does partition count set the max parallelism?

**Day 15 (Friday):** Read Ch11 continued — Kafka producer acks, ISR (in-sync replicas), retention policies. Practice: design a Kafka topology for a real-time order processing system. How many partitions? What's your consumer group strategy?
- Self-check: What is `acks=all` and when would you not use it? What is log compaction?

**Day 16 (Saturday):** Read Ch12 Redis/Caching. Practice: design a Redis-based rate limiter using sorted sets. Then design a leaderboard. Then design a distributed lock — and explain why Redlock is controversial.
- Self-check: What is cache stampede? How do you prevent it? What is the difference between cache-aside and write-through?

**Day 17 (Monday, Week 2 cont):** Read Ch13 Security. Focus on JWT structure (header.payload.signature), how validation works, and the revocation problem. OAuth2 — Authorization Code flow step by step. Practice: walk through a JWT-based login flow and explain exactly where a token is invalidated.
- Self-check: How do you revoke a JWT? What is PKCE and why does it exist?

**End of Week 2 Mini Self-Test — Vol 6 Ch25 Q&As:**
1. Design a URL shortener — API, storage, hash function, and redirect flow.
2. What is the saga pattern? When would you choose choreography over orchestration?
3. How does Kafka guarantee ordering? What breaks ordering?
4. Explain three Redis data structures and a real use case for each.
5. What is OAuth2? Walk through Authorization Code flow.

---

### Week 3 — Databases (Vol 4)

**Day 18 (Monday):** Read Ch14 SQL. Practice: write window function queries (ROW_NUMBER, RANK, DENSE_RANK, LAG, LEAD). Write a CTE that finds all employees whose salary is above their department average.
- Self-check: What is the difference between `RANK` and `DENSE_RANK`? When would you use a CTE over a subquery?

**Day 19 (Tuesday):** Read Ch14 continued — JOINs and query optimization basics. Practice: given a slow query, explain your approach. What do you look for in `EXPLAIN` output?
- Self-check: What is the difference between LEFT JOIN and INNER JOIN? What is a cross join and when is it accidentally used?

**Day 20 (Wednesday):** Read Ch15 Indexing. Focus on B-tree internals, composite index column order (why the leftmost prefix rule matters), covering index, and when the optimizer ignores your index. Practice: given a table with 10M rows and a slow query, design the optimal index.
- Self-check: Why does `LIKE '%foo'` prevent index use? What is a covering index?

**Day 21 (Thursday):** Read Ch16 ACID/Transactions. Focus on isolation levels — read uncommitted, read committed, repeatable read, serializable. Dirty read, non-repeatable read, phantom read — what each is and which level prevents it. Practice: write a scenario where two concurrent transactions cause a phantom read, then explain how SERIALIZABLE prevents it.
- Self-check: What is a phantom read? What is the default isolation level in MySQL and Postgres?

**Day 22 (Friday):** Read Ch17 Distributed DBs. Focus on CAP theorem (be precise — it's about what happens during network partition, not a permanent trade-off), eventual consistency, CRDTs, and vector clocks conceptually. Practice: explain why you'd choose AP over CP for a shopping cart but CP over AP for a payments ledger.
- Self-check: What does CAP actually say? What is BASE and how does it relate to CAP?

**Day 23 (Saturday):** Read Ch18 Advanced DB — sharding strategies (range vs hash), read replicas, connection pooling, and common anti-patterns (SELECT *, N+1 at DB level, missing indexes on foreign keys). Practice: design a sharding strategy for a multi-tenant SaaS application.
- Self-check: What is connection pool exhaustion and how do you diagnose it? What is the difference between horizontal and vertical scaling?

**End of Week 3 Mini Self-Test — Vol 6 Ch26 Q&As:**
1. Explain B-tree index structure. Why is it efficient for range queries?
2. What are the four isolation levels? What anomaly does each prevent?
3. What is the CAP theorem? Give a concrete example of an AP system and a CP system.
4. What is database sharding? What are the problems it introduces?
5. How would you debug a suddenly slow query in production?

---

### Week 4 — System Design + LLD + Full Revision (Vol 5 + Vol 6)

**Day 24 (Monday):** Read Ch19 Design Patterns. Focus on Factory Method vs Abstract Factory, Singleton (double-checked locking, enum singleton), Strategy, Observer, Decorator. Practice: implement a payment gateway that supports multiple providers using Strategy pattern.
- Self-check: Why is Singleton hard to test? What is the difference between Factory Method and Abstract Factory?

**Day 25 (Tuesday):** Read Ch20 SOLID + Clean Architecture. Practice: take any class you've written recently and identify which SOLID principle it violates. Refactor it. Then explain what "dependency inversion" means in the context of Spring's IoC container.
- Self-check: What is the Open/Closed Principle? What is the difference between the Dependency Inversion Principle and Dependency Injection?

**Day 26 (Wednesday):** Read Ch21 LLD Case Studies. Pick two: Parking Lot, Library Management System, or Hotel Booking. Practice: design one from scratch in 30 minutes — identify entities, relationships, and key design decisions. Then critique your own design.
- Self-check: What is the difference between Association, Aggregation, and Composition? When would you use an interface vs abstract class in your LLD?

**Day 27 (Thursday):** Read Ch22 System Design HLD. Practice the 5-step framework on two systems: (1) a notification service that handles 10M push notifications/day, (2) a ride-sharing matching system.
- Self-check: What is the back-of-the-envelope calculation for 10M notifications/day in terms of write throughput? What is a hotspot in consistent hashing?

**Day 28 (Friday):** Full revision — Vol 6 Ch23 + Ch24. Answer every Q&A you marked as uncertain during Weeks 1–2. Do not re-read chapters — answer from memory, then verify.

**Day 29 (Saturday):** Full revision — Vol 6 Ch25 + Ch26. Same approach.

**Day 30 (Sunday):** Full revision — Vol 6 Ch27. Full mock interview simulation:
- Round 1 (30 min): System design — pick one you haven't fully practiced
- Round 2 (20 min): LLD — design on paper, time-boxed
- Debrief (10 min): Write what you hesitated on. That list is your final study list.

**End of Week 4 Mini Self-Test — Vol 6 Ch27 Q&As:**
1. Design a distributed rate limiter. Compare token bucket in Redis vs. API gateway implementations.
2. Walk through the LLD for an elevator system. What are the entities? What design patterns apply?
3. Design a notification system. How do you handle fan-out for 10M subscribers?
4. Explain consistent hashing. Why does virtual node count matter?
5. What is the difference between HLD and LLD? What goes into each?

---

## 5. Plan C — 8-Week Deep Dive

**Commitment:** 1.5 hours/day, 6 days/week

**Structure:** Each week has daily reading + a weekly practice block with three exercises: code a small thing, design a mini system, answer 5 Vol 6 Q&As from the relevant revision chapter.

---

### Weeks 1–2 — Core Java Deep Dive (Vol 1)

**Week 1 Focus:** Ch1 OOP, Ch2 Strings/Wrappers/Exceptions, Ch3 Collections

**Daily breakdown:**
- Day 1: Ch1 OOP — polymorphism internals (vtable conceptually), interface default/static methods, sealed classes (Java 17+)
- Day 2: Ch2 Strings — String pool, `intern()`, StringBuffer vs StringBuilder threading implications
- Day 3: Ch3 Collections — HashMap internals (hashCode contract, equals contract, why both matter together)
- Day 4: Ch3 continued — TreeMap (Red-Black tree), LinkedHashMap (access order mode), PriorityQueue (heap)
- Day 5: Ch3 continued — ConcurrentHashMap segment locking (Java 7) vs CAS + synchronized (Java 8+), CopyOnWriteArrayList trade-offs
- Day 6: Week 1 practice block (see below)

**Week 1 Practice Block:**
1. **Code:** Implement a thread-safe bounded blocking queue from scratch using `ReentrantLock` and `Condition`. Do not use `BlockingQueue`. Test it with two producer threads and two consumer threads.
2. **Design:** Design the data structure layer for a Twitter timeline — what collection types would you use for in-memory operations and why?
3. **Vol 6 Ch23 Q&As:** Answer these five out loud: (1) HashMap vs TreeMap — when to use which? (2) What is the contract between `equals()` and `hashCode()`? (3) What is `CopyOnWriteArrayList` and when is it appropriate? (4) What is String interning? (5) What is the Java memory model's happens-before relationship?

**Week 2 Focus:** Ch4 Java8+, Ch5 JVM, Ch6 Multithreading

- Day 7: Ch4 — streams, lazy evaluation, parallel streams (when NOT to use them — shared mutable state, ordering cost)
- Day 8: Ch4 — CompletableFuture chaining, thenApply vs thenCompose, exceptionally, allOf/anyOf
- Day 9: Ch5 JVM — heap regions (Eden, Survivor, Old Gen), GC algorithms (G1 region-based, ZGC concurrent marking)
- Day 10: Ch5 — classloading (bootstrap, extension, application), custom classloader use case, memory leaks via classloader
- Day 11: Ch6 — thread states, synchronized monitor internals, ReentrantLock fairness, ThreadLocal use and memory leak
- Day 12: Week 2 practice block

**Week 2 Practice Block:**
1. **Code:** Write a CompletableFuture pipeline that calls three mock APIs in parallel, aggregates results, and handles partial failures — if one API fails, use a cached fallback value.
2. **Design:** Explain how you'd tune JVM settings for a Spring Boot service under heavy load — heap size, GC choice, thread pool sizing.
3. **Vol 6 Ch23 Q&As:** (1) What is a parallel stream and what can go wrong? (2) Explain G1 GC's region layout and evacuation pauses. (3) What is a classloader and how does the delegation model work? (4) What is a ThreadLocal and where can it leak? (5) What is compare-and-swap and how does Java's `AtomicInteger` use it?

---

### Week 3 — Spring Deep Dive (Vol 2)

**Focus:** Ch7 Spring Core/Boot (deep), Ch8 JPA/Hibernate (deep)

- Day 13: Spring IoC — BeanFactory vs ApplicationContext, `@Configuration` CGLIB proxying, `@Import`
- Day 14: AOP — JDK proxy vs CGLIB proxy internals, when to use each, how `@Transactional` is implemented as an aspect
- Day 15: Spring Boot autoconfiguration — `@EnableAutoConfiguration`, `META-INF/spring.factories`, condition annotations
- Day 16: JPA — entity lifecycle states (transient, managed, detached, removed), cascade types and when they bite you
- Day 17: Hibernate — query cache vs first/second-level cache, `@Version` for optimistic locking, how `PESSIMISTIC_WRITE` maps to `SELECT FOR UPDATE`
- Day 18: Practice block

**Week 3 Practice Block:**
1. **Code:** Write a Spring Boot application with a service that has a `@Transactional` method calling another `@Transactional` method in the same class. Demonstrate the proxy bypass problem. Then fix it using `@Autowired` self-injection (and explain why this is a code smell but works).
2. **Design:** Design the transaction boundary for a banking transfer — debit one account, credit another. What propagation, what isolation level, what happens if the credit step fails?
3. **Vol 6 Ch24 Q&As:** (1) What is Spring's bean lifecycle? (2) Why does `@Transactional` fail on private methods? (3) What is the N+1 problem and three ways to fix it? (4) What is `@EntityGraph`? (5) Explain Spring Boot autoconfiguration in one minute.

---

### Weeks 4–5 — Backend Systems Deep Dive (Vol 3)

**Week 4 Focus:** Ch9 REST, Ch10 Microservices, Ch11 Kafka

- Day 19: REST — idempotency, HATEOAS (know it exists, not widely tested), versioning strategies trade-offs
- Day 20: Ch10 — service mesh (Istio concept), API gateway patterns, strangler fig pattern
- Day 21: Ch10 — saga pattern deep dive: compensating transactions, why they're hard to test, idempotency of compensating actions
- Day 22: Ch11 Kafka — producer internals (batching, linger.ms, buffer.memory, retries)
- Day 23: Ch11 — consumer internals (partition assignment strategies: range, round-robin, sticky), rebalancing protocol
- Day 24: Week 4 practice block

**Week 4 Practice Block:**
1. **Code:** Write a Kafka consumer in Java that processes messages exactly once using idempotent consumer logic (store processed message IDs in Redis with TTL). Handle the case where Redis is temporarily unavailable.
2. **Design:** Design a microservices architecture for an e-commerce checkout — identify service boundaries, how the saga flows, and what happens if payment service is down for 2 minutes.
3. **Vol 6 Ch25 Q&As:** (1) What is exactly-once in Kafka and what does it require from both producer and consumer? (2) Walk through a saga for order placement. (3) What is a circuit breaker's half-open state? (4) How does service discovery work? (5) What is an API gateway and why is it not just a reverse proxy?

**Week 5 Focus:** Ch12 Redis deep, Ch13 Security

- Day 25: Redis data structures — sorted sets (ZADD/ZRANGE internals: skip list), HyperLogLog, Pub/Sub vs Streams
- Day 26: Redis patterns — rate limiting (fixed window vs sliding window using sorted sets), distributed lock (Redlock algorithm and its critics — Martin Kleppmann's critique is worth knowing)
- Day 27: Redis — eviction policies (LRU, LFU, noeviction), persistence (RDB vs AOF trade-offs), cluster mode vs sentinel
- Day 28: Ch13 Security — JWT deep dive (why stateless is a double-edged sword), refresh token rotation, PKCE
- Day 29: Ch13 — OAuth2 scopes, resource server validation, common vulnerabilities (SSRF, mass assignment)
- Day 30: Week 5 practice block

**Week 5 Practice Block:**
1. **Code:** Implement a sliding window rate limiter in Java using Redis sorted sets. Make it handle the Redis unavailability case gracefully (fail open or fail closed — justify your choice).
2. **Design:** Design a caching layer for a product catalog with 1M SKUs. Address cache warmup, invalidation, stampede prevention, and what to do when Redis goes down.
3. **Vol 6 Ch25 Q&As (continued):** (1) What is Redis Sorted Set and what is its time complexity for ZADD and ZRANGE? (2) Why is Redlock controversial? (3) What is the difference between RDB and AOF persistence? (4) How do you revoke a JWT without a blocklist? (5) What is PKCE and which OAuth2 flow uses it?

---

### Week 6 — Databases Deep Dive (Vol 4)

- Day 31: Ch14 SQL — advanced window functions, recursive CTEs, explain plan reading (identify full table scans, key lookup operations)
- Day 32: Ch15 Indexing — composite index internals, ICP (Index Condition Pushdown), partial indexes, functional indexes
- Day 33: Ch16 ACID — MVCC (Multi-Version Concurrency Control) in Postgres and MySQL — how they differ, why Postgres has table bloat, vacuum
- Day 34: Ch17 Distributed DBs — Paxos conceptually, Raft (leader election, log replication) — you don't need to implement it, but know the flow
- Day 35: Ch18 Advanced DB — NewSQL (CockroachDB, TiDB), time-series databases, column-oriented storage for analytics
- Day 36: Practice block

**Week 6 Practice Block:**
1. **Code:** Write 3 SQL queries: (1) find users who purchased in every month of 2024, (2) calculate 7-day rolling average of order value per user, (3) find the most recent order per user without a subquery.
2. **Design:** Design the database layer for a multi-tenant SaaS application — choose between shared schema, schema-per-tenant, and database-per-tenant. Justify trade-offs for a 10,000-tenant product.
3. **Vol 6 Ch26 Q&As:** (1) What is MVCC and how does it enable non-blocking reads? (2) What is Raft and what problem does it solve? (3) Explain three sharding strategies and their failure modes. (4) What is a covering index? (5) What is connection pool exhaustion and how do you prevent it?

---

### Week 7 — System Design + LLD Deep Dive (Vol 5)

- Day 37: Ch19 Design Patterns — Decorator, Proxy, Chain of Responsibility, Template Method (focus on where Spring uses these)
- Day 38: Ch20 SOLID + Hexagonal Architecture, Ports and Adapters, and how it relates to testability
- Day 39: Ch21 LLD Case Studies — full walkthrough: Parking Lot (entity design, state machine, concurrency)
- Day 40: Ch21 continued — Library Management or Hotel Booking: identify where SOLID is violated in naive designs
- Day 41: Ch22 HLD — full 45-minute design for a distributed message queue (design Kafka from scratch, roughly)
- Day 42: Practice block

**Week 7 Practice Block:**
1. **Code:** Implement a generic event bus in Java using the Observer pattern. Support synchronous and asynchronous delivery. Handle subscriber exceptions without dropping events for other subscribers.
2. **Design:** Full HLD for a food delivery platform (like Swiggy/UberEats) — cover order placement, real-time tracking, driver matching, and notification. 45 minutes, think on paper first.
3. **Vol 6 Ch27 Q&As:** (1) Walk through LLD for a vending machine using a state machine. (2) Design a consistent hashing ring — explain virtual nodes. (3) What is the difference between strong, eventual, and causal consistency? (4) Design a search autocomplete service. (5) What is a bloom filter and when would you use it in system design?

---

### Week 8 — Full Revision + Mock Interview Simulation (Vol 6)

**Day 43:** Ch23 Core Java Revision — answer every Q&A. Mark confidence: Green (got it), Yellow (partial), Red (missed). Only re-read for Red items.

**Day 44:** Ch24 Spring/JPA Revision — same approach.

**Day 45:** Ch25 Backend Systems Revision — same approach.

**Day 46:** Ch26 DB Revision — same approach.

**Day 47:** Ch27 System Design/LLD Revision — same approach.

**Day 48 (Mock Day):** Simulate a full interview loop over 3 hours:
- Round 1 (45 min): Pick a LLD problem you have not fully designed before. Timer on. Think out loud.
- Round 2 (45 min): Pick a HLD problem. Use the 5-step framework. No notes.
- Round 3 (30 min): Verbal walk-through of your hardest past project — explain it to someone who does not know your domain.
- Debrief (30 min): Write what you said well and what you hesitated on. That hesitation list is your final study list.

---

## 6. What Interviewers Actually Test

### Coding Rounds

Interviewers are not checking if you solved the problem. They are checking:

- **Do you clarify before coding?** Candidates who code immediately after hearing the problem get lower scores, even with correct solutions. Ask: what are the constraints? Is the input sorted? Can values be null?
- **Do you talk while coding?** Silent coding signals poor communication skills. Narrate your decisions, especially when you're choosing between approaches.
- **Do you know your data structures?** HashMap, TreeMap, PriorityQueue — if you always reach for a list, interviewers notice. Know when a TreeMap buys you O(log n) sorted order cheaply.
- **Do you handle edge cases proactively?** Empty input, null, single element, maximum input size — before submitting, walk through your code with these.
- **Is your code readable?** Variable names matter. `i`, `j`, `k` everywhere signals junior thinking. Name things what they are.

### System Design Rounds

The most common reasons senior candidates fail system design:

1. **Jumping to solutions before requirements.** Ask: read-heavy or write-heavy? What is acceptable latency? What is the scale (RPS, data volume)? An interviewer who does not get clarifying questions gives a low score regardless of the design quality.
2. **Going too deep too fast.** Candidates spend 20 minutes on the database schema and never cover caching, load balancing, or failure modes. The interviewer wanted breadth first, then depth on what they ask about.
3. **Not quantifying.** "We'll use Kafka because it's scalable" is a weak answer. "At 50,000 orders/minute with 4 partitions and 3 consumer replicas, we can sustain 12,500 messages/partition/minute well within Kafka's throughput ceiling" is a strong answer. Back of the envelope math is not optional at SDE2+.
4. **No failure discussion.** Every design question has a hidden sub-question: what happens when component X fails? If you do not bring this up before the interviewer does, you are leaving signal on the table.

> **The 5-minute rule:** In the first 5 minutes of a system design interview, you should have: (1) confirmed functional and non-functional requirements, (2) done a rough capacity estimate, (3) sketched the highest-level API boundary. If you are still asking questions at minute 10, you are behind.

### LLD Rounds

**The #1 mistake:** Jumping to class diagrams before requirements. LLD interviewers at product companies care about:

- Can you identify the right abstractions? Do you see an interface where one is needed?
- Do you know when NOT to over-engineer? A parking lot does not need a microservices architecture.
- Do you apply SOLID naturally, not as a checklist? Naming a principle without showing it in your design is not enough.
- Can you handle concurrency? "Thread-safe parking spot allocation" — did you think about it or did it come up only when asked?

Start every LLD round by writing: entities, key relationships, and key behaviors — before any class definitions.

### Behavioral Rounds (Product Companies Specifically)

Product companies (Google, Flipkart, Razorpay, PhonePe, Swiggy) care about impact and ownership more than service companies. Interviewers are looking for:

- **Ownership:** Did you drive the decision or were you assigned a ticket? "I noticed the P99 was degrading and proposed we migrate to async processing" > "I was asked to implement async processing."
- **Trade-off thinking:** Every story should have a moment where you chose between two valid options. If your story has no trade-off, it does not demonstrate engineering judgment.
- **Quantified outcomes:** "Reduced API latency by 40%" > "Improved performance." If you do not track impact, start tracking it now.
- **What you would do differently:** This is not a trick question. Interviewers want to see that you reflect. The best answer includes a specific technical decision you would reverse and why.

---

## 7. Topic Priority Heat Map

Must Know = guaranteed to appear | Important = appears in most loops | Good to Know = differentiates senior candidates

| Topic | Chapter | SDE1 Priority | SDE2 Priority | Senior Priority | Interview Frequency |
|-------|---------|--------------|--------------|-----------------|---------------------|
| OOP Fundamentals | Ch1 | Must Know | Must Know | Important | Very High |
| Collections Internals | Ch3 | Must Know | Must Know | Important | Very High |
| Java 8 Streams/Lambda | Ch4 | Important | Must Know | Must Know | High |
| Multithreading Basics | Ch6 | Must Know | Must Know | Must Know | Very High |
| JVM Internals + GC | Ch5 | Good to Know | Important | Must Know | Medium |
| String/Exception internals | Ch2 | Important | Good to Know | Good to Know | Medium |
| Spring IoC/AOP | Ch7 | Important | Must Know | Must Know | Very High |
| JPA/Hibernate N+1 | Ch8 | Important | Must Know | Must Know | High |
| REST API Design | Ch9 | Must Know | Must Know | Important | High |
| Microservices Patterns | Ch10 | Good to Know | Must Know | Must Know | High |
| Kafka Internals | Ch11 | Good to Know | Must Know | Must Know | High |
| Redis / Caching Patterns | Ch12 | Good to Know | Must Know | Must Know | Very High |
| Security / JWT / OAuth2 | Ch13 | Good to Know | Important | Important | Medium |
| SQL + Window Functions | Ch14 | Must Know | Must Know | Important | Very High |
| DB Indexing | Ch15 | Important | Must Know | Must Know | Very High |
| ACID / Isolation Levels | Ch16 | Good to Know | Must Know | Must Know | High |
| Distributed DBs / CAP | Ch17 | Good to Know | Important | Must Know | High |
| Advanced DB / Sharding | Ch18 | Good to Know | Important | Must Know | Medium |
| Design Patterns | Ch19 | Important | Must Know | Must Know | High |
| SOLID / Clean Arch | Ch20 | Good to Know | Important | Must Know | Medium |
| LLD Case Studies | Ch21 | Good to Know | Must Know | Must Know | Very High |
| System Design HLD | Ch22 | Good to Know | Must Know | Must Know | Very High |

---

## 8. Daily Practice Rituals

These are non-negotiable. Not optional exercises — mandatory habits. If your prep has these five, your consistency will beat candidates who study more but practice less.

**1. One Vol 6 Q&A spoken aloud before sleeping (every night, 5 minutes)**
Pick one question from the Vol 6 chapter most relevant to what you studied that day. Do not read it silently. Say the answer out loud as if you are in an interview. This is uncomfortable at first — that discomfort means it is working.

**2. One system design sketch per day (10 minutes, paper only)**
Pick a system from your life: how does WhatsApp deliver messages, how does Spotify generate recommendations, how does your bank process a transfer. Sketch the major components, identify the bottleneck, and note one failure mode. You are not designing a production system — you are training your brain to think in systems.

**3. Read one EXPLAIN query plan per week**
If you are not working in a job with database access, use a free Postgres or MySQL instance (ElephantSQL free tier, PlanetScale free tier). Create a table with 100K rows and run EXPLAIN on a query. Understand what "Seq Scan" vs "Index Scan" vs "Index Only Scan" means. Do this once a week — it is worth more than re-reading Ch15.

**4. After every practice problem, write a one-line "what I missed" note**
Not a full post-mortem — one line. "Missed the edge case where the array has one element." "Forgot that HashMap allows null keys." Keep a running list. Review it every Sunday. Patterns in what you miss reveal your actual weak spots, not the weak spots you think you have.

**5. Time-box every mock design (30 minutes, hard stop)**
When you practice system design, set a timer. When it goes off, stop. Evaluate: did you cover requirements, capacity, API, components, and at least one failure mode? If not, you know what to practice. Designs that take 90 minutes in practice will take 90 minutes in interviews, and you will not finish.

---

## 9. Chapter Map Quick Reference

| Chapter | Volume | Key Topics | Best For |
|---------|--------|------------|----------|
| Ch1 OOP | Vol 1 | Polymorphism, abstraction, encapsulation, interfaces vs abstract classes | All levels |
| Ch2 Strings/Wrappers/Exceptions | Vol 1 | String pool, immutability, exception hierarchy, try-with-resources | SDE1 |
| Ch3 Collections | Vol 1 | HashMap internals, ConcurrentHashMap, TreeMap, LinkedHashMap LRU pattern | SDE1–SDE2 |
| Ch4 Java 8+ | Vol 1 | Streams, Optional, CompletableFuture, method references | SDE1–SDE2 |
| Ch5 JVM | Vol 1 | GC algorithms, heap regions, classloading, memory model | SDE2–Senior |
| Ch6 Multithreading | Vol 1 | Thread pools, locks, volatile, concurrent collections, deadlock | All levels |
| Ch7 Spring Core/Boot | Vol 2 | IoC, AOP, bean lifecycle, autoconfiguration, proxy mechanism | SDE1–SDE2 |
| Ch8 JPA/Hibernate | Vol 2 | N+1, fetch types, caching, `@Transactional` propagation, optimistic locking | SDE1–Senior |
| Ch9 REST APIs | Vol 3 | HTTP methods, idempotency, status codes, versioning, pagination | All levels |
| Ch10 Microservices | Vol 3 | Service discovery, API gateway, circuit breaker, saga pattern | SDE2–Senior |
| Ch11 Kafka | Vol 3 | Partitions, consumer groups, offsets, exactly-once, ISR | SDE2–Senior |
| Ch12 Redis/Caching | Vol 3 | Data structures, cache patterns, distributed lock, eviction | SDE2–Senior |
| Ch13 Security | Vol 3 | JWT, OAuth2, PKCE, common vulnerabilities | SDE2 |
| Ch14 SQL | Vol 4 | Window functions, CTEs, JOIN types, query optimization | All levels |
| Ch15 Indexing | Vol 4 | B-tree, composite index, covering index, optimizer behavior | SDE2–Senior |
| Ch16 ACID/Transactions | Vol 4 | Isolation levels, dirty/phantom reads, MVCC | SDE2–Senior |
| Ch17 Distributed DBs | Vol 4 | CAP theorem, eventual consistency, Raft/Paxos concepts | Senior |
| Ch18 Advanced DB | Vol 4 | Sharding, read replicas, connection pooling, anti-patterns | Senior |
| Ch19 Design Patterns | Vol 5 | Factory, Singleton, Strategy, Observer, Decorator, Builder | SDE2–Senior |
| Ch20 SOLID/Clean Arch | Vol 5 | SOLID principles, hexagonal architecture, dependency inversion | SDE2–Senior |
| Ch21 LLD Case Studies | Vol 5 | Parking lot, library, hotel booking — entity design, state machines | SDE2–Senior |
| Ch22 System Design HLD | Vol 5 | HLD framework, capacity estimation, component design, failure modes | SDE2–Senior |
| Ch23 Core Java Revision | Vol 6 | Q&As covering Vol 1 | All levels (revision only) |
| Ch24 Spring/JPA Revision | Vol 6 | Q&As covering Vol 2 | All levels (revision only) |
| Ch25 Backend Systems Revision | Vol 6 | Q&As covering Vol 3 | All levels (revision only) |
| Ch26 DB Revision | Vol 6 | Q&As covering Vol 4 | All levels (revision only) |
| Ch27 System Design/LLD Revision | Vol 6 | Q&As covering Vol 5 | All levels (revision only) |

---

> **Final word:** The most dangerous candidate is the one who reads everything and practices nothing. This handbook is dense. You will not remember it by reading. You will remember it by doing — by answering questions out loud, designing systems on paper, writing code without autocomplete. Pick your plan, execute it, and do not switch plans mid-way because you feel behind. Feeling behind is normal. Finishing is what matters.
