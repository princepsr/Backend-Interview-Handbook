# Volume 2: Spring — Study Guide

## Priority Order

Ch8 JPA/Hibernate first — more interview-dense, more failure modes, more "gotcha" questions.
Then Ch7 Spring Core/Boot — foundational but more conceptual; easier to recall under pressure.

Order: Ch8 JPA → Ch7 Spring Core → Ch7 Spring Security

---

## 1-Week Plan (1 hr/day)

**Day 1 — Ch8 JPA: N+1 and Fetching**
- Focus: N+1 problem — how to detect it (Hibernate statistics, slow query log), how to fix it (`JOIN FETCH`, `@EntityGraph`, batch size)
- Focus: `FetchType.LAZY` vs `EAGER` — default per relationship type, when EAGER causes performance issues
- Focus: `@OneToMany` bidirectional mapping — `mappedBy`, owning side, orphan removal

**Day 2 — Ch8 JPA: Transactions and Locking**
- Focus: `@Transactional` edge cases — self-invocation bypass (proxy), checked vs unchecked rollback, `readOnly = true` optimization
- Focus: Propagation modes — `REQUIRED` vs `REQUIRES_NEW` vs `NESTED`; when each is correct
- Focus: Optimistic locking (`@Version`) vs pessimistic locking (`LockModeType.PESSIMISTIC_WRITE`); use cases for each

**Day 3 — Ch7 Spring Core: Beans and DI**
- Focus: Bean lifecycle — `@PostConstruct`, `InitializingBean`, `BeanPostProcessor`; order of execution
- Focus: Bean scopes — singleton vs prototype vs request; injecting prototype into singleton correctly (`@Lookup` or `ApplicationContext`)
- Focus: `@Conditional`, `@Profile`, `@ConditionalOnProperty` — how Spring Boot auto-configuration uses these

**Day 4 — Ch7 Spring Core: AOP and Proxying**
- Focus: How Spring AOP works — JDK dynamic proxy vs CGLIB; when each is used; interface requirement
- Focus: Self-invocation problem — why `this.method()` bypasses the proxy; solutions (`AopContext`, restructure, `@Transactional` on separate bean)
- Focus: `@Async` — thread pool configuration, return types (`void` vs `Future` vs `CompletableFuture`), exception handling in async methods

**Day 5 — Spring Security + JWT**
- Focus: Filter chain order — `SecurityFilterChain`, where `JwtAuthenticationFilter` sits, `OncePerRequestFilter`
- Focus: `UserDetailsService`, `AuthenticationManager`, `AuthenticationProvider` — how they wire together
- Focus: Stateless JWT pattern — no `HttpSession`, `SecurityContextHolder` per-request population, token expiry handling

**Day 6 — Practice: Design a Spring Boot Service**
- Build mentally (or on paper): a REST endpoint that reads/writes via JPA with correct `@Transactional` boundaries, async processing via `@Async`, and a Spring Security filter for JWT
- Identify where `@Transactional` on a `@Service` method calling another `@Service` method uses `REQUIRED` propagation (same transaction)
- Identify where `REQUIRES_NEW` is needed (audit logging that must persist even on rollback)

**Day 7 — Vol 6 Ch24 Revision**
- Test yourself on: Q2, Q5, Q9, Q14, Q20 from Ch24
- Q2: N+1 identification and fix
- Q5: `@Transactional` self-invocation scenario
- Q9: Bean scope injection problem
- Q14: AOP proxy type selection
- Q20: Spring Security filter chain customization

---

## 3-Day Crash

**Day 1 — JPA Core**
- N+1 problem: cause, detection, three fixes (`JOIN FETCH`, `@EntityGraph`, `@BatchSize`)
- `@Transactional` rollback rules: unchecked rolls back, checked does not by default — know `rollbackFor`
- Optimistic locking with `@Version`: what `OptimisticLockException` means and when it fires

**Day 2 — Spring Core**
- Bean scopes and the singleton-prototype injection trap
- `@Async` setup: `@EnableAsync`, `ThreadPoolTaskExecutor`, why `void` async methods swallow exceptions
- Spring Security filter chain: know the order, know where to insert a custom JWT filter

**Day 3 — Vol 6 Ch24 Revision**
- Q2, Q5, Q9, Q14, Q20 from Ch24
- For each: write the answer, then check — focus on what you got wrong

---

## What Interviewers Test in Spring Rounds

- They give you a `@Transactional` method calling another `@Transactional` method on the same bean — the answer is self-invocation bypasses the proxy and propagation is irrelevant
- They ask about N+1 in the context of a real REST endpoint returning a list — they want to hear "I'd check with Hibernate statistics and fix with JOIN FETCH or EntityGraph"
- They probe `@Async` exception handling — most candidates forget that exceptions in `void` async methods are silently lost unless you configure an `AsyncUncaughtExceptionHandler`
- They test bean scope understanding by describing a singleton service with a prototype-scoped dependency — they expect you to know `@Lookup` or `ObjectProvider`
- They ask about Spring Security filter chain to check if you understand the stateless JWT pattern vs session-based auth — and why `STATELESS` session creation matters for microservices

---

## Top 10 Spring/JPA Questions

1. What is the N+1 problem and how do you solve it in Spring Data JPA?
2. Explain `@Transactional` propagation — what is the difference between `REQUIRED` and `REQUIRES_NEW`?
3. What happens when a `@Transactional` method calls another `@Transactional` method on the same bean?
4. How does Spring AOP work — JDK proxy vs CGLIB and when is each used?
5. What is the difference between optimistic and pessimistic locking in JPA?
6. How do you inject a prototype-scoped bean into a singleton-scoped bean correctly?
7. How does Spring Boot auto-configuration work — explain `@Conditional` and `spring.factories`?
8. How do you handle exceptions in `@Async` methods — what is `AsyncUncaughtExceptionHandler`?
9. Explain the Spring Security filter chain — where does JWT authentication fit?
10. What is `@EntityGraph` and when would you use it over `JOIN FETCH`?

---

## Common Mistakes

- Using `@Transactional` on a `private` method — Spring proxy cannot intercept it; transaction silently does not apply
- Fetching lazy collections outside a transaction — `LazyInitializationException` in the controller layer; fix with proper service-layer transaction scope
- Configuring `@Async` without `@EnableAsync` — method runs synchronously with no error, hard to debug
- Using `FetchType.EAGER` on `@OneToMany` — causes Cartesian product joins and massive result sets on any parent query
- Forgetting `rollbackFor = Exception.class` when a method throws a checked exception — transaction commits on checked exception by default, leaving data in inconsistent state
