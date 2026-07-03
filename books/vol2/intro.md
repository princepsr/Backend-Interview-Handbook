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

- [Volume 2 Study Plan](STUDY_GUIDE.md) — 1-week plan, 3-day crash plan, top 10 questions, and daily practice tips.
- [Volume 2 Company Guide](COMPANY_GUIDE.md) — which companies go deep on Spring/JPA and what they specifically test.

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
