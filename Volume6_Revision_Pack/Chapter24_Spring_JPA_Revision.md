# Volume 6: Interview Revision Pack
# Chapter 24: Spring & JPA — Quick Revision

> Last-day review. Skim headers, drill anything that feels shaky.

---

## Section 1: Spring Core — Top 15 Questions

**Q1. IoC vs DI — what's the difference?**
IoC is the *principle* (control of object creation inverted to container); DI is one *mechanism* that implements it (dependencies injected by container, not fetched by object).

**Q2. BeanFactory vs ApplicationContext?**
BeanFactory: lazy, minimal, no AOP/events/i18n. ApplicationContext: eager singleton init, supports `@EventListener`, `MessageSource`, `BeanPostProcessor` auto-detection. Use ApplicationContext always in production.

**Q3. Bean scopes — list all five standard ones.**
- `singleton` — one instance per ApplicationContext (default)
- `prototype` — new instance every `getBean()` call
- `request` — one per HTTP request (web only)
- `session` — one per HTTP session (web only)
- `application` — one per ServletContext (web only)

**Q4. Constructor vs field injection — why constructor preferred?**
- Immutable fields (`final`), makes dependencies explicit
- Fails fast at startup (no `NullPointerException` at runtime)
- Easier unit testing (plain `new` with mocks, no reflection)
- Avoids circular dependency hiding

**Q5. @Autowired resolution order?**
1. Match by **type** — if unique, inject
2. Multiple candidates → match by **@Qualifier** name
3. Fall back to **field/parameter name** as bean name
4. Throw `NoUniqueBeanDefinitionException` if still ambiguous

**Q6. Prototype bean injected into singleton — what's the problem and fix?**
Problem: singleton is created once, so prototype dependency is also created once — effectively singleton.
Fixes:
- Inject `ObjectProvider<MyBean>` and call `.getObject()` per use
- Implement `ApplicationContextAware` and call `getBean()` each time
- Use `@Lookup` method injection (Spring proxies the method)
- Make singleton `@Scope(proxyMode = ScopedProxyMode.TARGET_CLASS)`

**Q7. Bean lifecycle phases (in order)?**
1. Instantiation (constructor)
2. Populate properties (dependency injection)
3. `*Aware` callbacks (`BeanNameAware`, `ApplicationContextAware`, …)
4. `BeanPostProcessor.postProcessBeforeInitialization()`
5. `@PostConstruct` / `InitializingBean.afterPropertiesSet()` / `init-method`
6. `BeanPostProcessor.postProcessAfterInitialization()`
7. Bean in use (ready)
8. `@PreDestroy` / `DisposableBean.destroy()` / `destroy-method`

**Q8. How does Spring resolve circular dependencies?**
Three-level cache (for singleton beans only):
- L1 `singletonObjects` — fully initialized beans
- L2 `earlySingletonObjects` — partially initialized (exposed early)
- L3 `singletonFactories` — factory lambdas that can create early reference

Spring exposes the partially-created A into L3 before injecting B; B sees A's early reference from L3 → cycle resolved. **Constructor injection cannot use this** — fails with `BeanCurrentlyInCreationException`.

**Q9. @Configuration with CGLIB vs plain @Component?**
`@Configuration`: CGLIB subclass proxies the class → `@Bean` methods called on proxy, so inter-`@Bean` calls return the *same singleton* from container.
`@Component` (or `@Configuration(proxyBeanMethods=false)`): no subclassing → inter-`@Bean` calls create new instances — use only for independent beans.

**Q10. @Bean vs @Component?**
`@Component`: Spring scans and registers the class itself as a bean.
`@Bean`: factory method inside `@Configuration` returns a bean — useful for third-party classes you cannot annotate.

**Q11. AOP: JDK dynamic proxy vs CGLIB?**
- JDK: requires target to implement an interface; proxies the interface
- CGLIB: subclasses the target class; works without interfaces; fails on `final` classes/methods
- Spring Boot default (2.x+): CGLIB for everything (`spring.aop.proxy-target-class=true`)

**Q12. @Transactional self-invocation bypass — why and fix?**
`@Transactional` relies on Spring's proxy. When a bean calls its own method, the call bypasses the proxy → no transaction.
Fixes: inject `self` reference (`@Autowired ApplicationContext` + `ctx.getBean()`), or refactor into a separate bean, or use AspectJ weaving.

**Q13. Spring Events?**
Publish: `ApplicationEventPublisher.publishEvent(event)` (inject via `@Autowired`)
Listen: `@EventListener` on any Spring-managed method, or implement `ApplicationListener<E>`
Async listeners: add `@Async` + `@EnableAsync`
Transactional listeners: `@TransactionalEventListener(phase = AFTER_COMMIT)` — fires only after tx commits.

**Q14. @Conditional annotations?**
- `@ConditionalOnClass` / `@ConditionalOnMissingClass`
- `@ConditionalOnBean` / `@ConditionalOnMissingBean`
- `@ConditionalOnProperty(name="x", havingValue="true")`
- `@ConditionalOnWebApplication` / `@ConditionalOnExpression`
Custom: implement `Condition` interface, pass to `@Conditional(MyCondition.class)`.

**Q15. @Profile?**
Activates beans/config only for named profiles. Set via `spring.profiles.active=dev,local`. Combine: `@Profile("!prod")` (not prod), `@Profile({"qa","staging"})` (either). Default profile activates when no other profile is active.

---

## Section 2: Spring Boot — Top 10 Questions

**Q1. Auto-configuration mechanism?**
Spring Boot reads `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` (Boot 3) or `spring.factories` (Boot 2). Each class is annotated with `@ConditionalOnClass`, `@ConditionalOnMissingBean`, etc. Only activates if conditions pass.
`@SpringBootApplication` includes `@EnableAutoConfiguration` which triggers this scan.

**Q2. @SpringBootApplication = 3 annotations?**
- `@Configuration` — marks class as bean source
- `@EnableAutoConfiguration` — triggers auto-config
- `@ComponentScan` — scans current package and sub-packages

**Q3. Starter POMs purpose?**
Curated dependency sets (e.g., `spring-boot-starter-web` pulls Tomcat + Spring MVC + Jackson). No code — just transitive Maven/Gradle dependencies with compatible versions managed by `spring-boot-dependencies` BOM.

**Q4. Key Actuator endpoints?**
| Endpoint | Purpose |
|----------|---------|
| `/actuator/health` | Liveness/readiness status |
| `/actuator/metrics` | Micrometer metrics |
| `/actuator/env` | Property sources |
| `/actuator/beans` | All registered beans |
| `/actuator/mappings` | URL → handler mappings |
| `/actuator/loggers` | Change log level at runtime |
| `/actuator/httptrace` | Recent HTTP exchanges |

Enable all: `management.endpoints.web.exposure.include=*` (restrict in prod).

**Q5. Externalized config — priority order (high → low)?**
1. Command-line args (`--server.port=9090`)
2. `SPRING_APPLICATION_JSON` (inline JSON env var)
3. OS environment variables
4. `application-{profile}.properties` outside jar
5. `application.properties` outside jar
6. `application-{profile}.properties` inside jar
7. `application.properties` inside jar
8. `@PropertySource` annotations
9. Default properties (`SpringApplication.setDefaultProperties`)

**Q6. @ConfigurationProperties vs @Value?**
`@ConfigurationProperties(prefix="app")`: binds entire prefix to a POJO, type-safe, supports relaxed binding, `@Validated`, IDE autocompletion via metadata processor.
`@Value("${app.name}")`: single property injection, SpEL support, but brittle for large configs.

**Q7. Embedded server — how does it work?**
`spring-boot-starter-web` includes Tomcat. `EmbeddedWebServerFactoryCustomizerAutoConfiguration` creates `TomcatServletWebServerFactory`. Boot calls `start()` on the factory, which starts the server and deploys the `DispatcherServlet`. No WAR/deployment descriptor needed.

**Q8. Spring Boot 3 key changes?**
- Requires Java 17+
- Jakarta EE 9 namespace (`javax.*` → `jakarta.*`) — breaking change
- GraalVM native image support (`spring-native` merged into core)
- Observability first-class via Micrometer Tracing (replaces Spring Cloud Sleuth)
- `spring.factories` replaced by `AutoConfiguration.imports`

**Q9. Banner customization?**
Place `banner.txt` in `resources/`. Use `${spring-boot.version}`, `${application.version}` placeholders. Disable: `spring.main.banner-mode=off`. Programmatic: `SpringApplication.setBanner(…)`.

**Q10. Graceful shutdown?**
```yaml
server:
  shutdown: graceful
spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
```
On SIGTERM, Spring stops accepting new requests, waits up to timeout for in-flight requests to complete, then shuts down context.

---

## Section 3: Spring Data JPA — Top 15 Questions

**Q1. Entity lifecycle states?**
- **Transient**: new object, not associated with any `EntityManager`, not in DB
- **Managed** (Persistent): associated with active `EntityManager`; changes auto-synced to DB at flush
- **Detached**: was managed, `EntityManager` closed or `detach()` called; changes NOT tracked
- **Removed**: `remove()` called; will be deleted at next flush

**Q2. N+1 problem — what is it and 4 solutions?**
Problem: 1 query for list of entities + N queries for each associated collection/entity.
Solutions:
1. `JOIN FETCH` in JPQL: `SELECT e FROM Employee e JOIN FETCH e.department`
2. `@EntityGraph(attributePaths = {"department"})` on repository method
3. `@BatchSize(size = 25)` on collection mapping (Hibernate batches sub-selects)
4. `@Fetch(FetchMode.SUBSELECT)` — single sub-select for all children

**Q3. LAZY vs EAGER — defaults per relationship type?**
| Annotation | Default |
|------------|---------|
| `@ManyToOne` | EAGER |
| `@OneToOne` | EAGER |
| `@OneToMany` | LAZY |
| `@ManyToMany` | LAZY |

Best practice: override EAGER to LAZY everywhere; load eagerly explicitly when needed.

**Q4. @Transactional propagation — all 7 types?**
See Section 4 for full table.

**Q5. Isolation levels?**
| Level | Dirty Read | Non-Repeatable Read | Phantom Read |
|-------|-----------|---------------------|--------------|
| READ_UNCOMMITTED | Yes | Yes | Yes |
| READ_COMMITTED (default PG) | No | Yes | Yes |
| REPEATABLE_READ (default MySQL InnoDB) | No | No | Yes |
| SERIALIZABLE | No | No | No |

Set: `@Transactional(isolation = Isolation.READ_COMMITTED)`

**Q6. @Version for optimistic locking?**
Add `@Version Long version` to entity. JPA adds `WHERE version = ?` on UPDATE. If rows updated = 0, throws `OptimisticLockException`. Client retries. Zero DB locks. Use for low-contention data.

**Q7. SELECT FOR UPDATE pessimistic locking?**
```java
entityManager.find(Product.class, id, LockModeType.PESSIMISTIC_WRITE);
// or in repository:
@Lock(LockModeType.PESSIMISTIC_WRITE)
Optional<Product> findById(Long id);
```
Holds row-level DB lock until transaction ends. Use for high-contention, short transactions.

**Q8. IDENTITY vs SEQUENCE — why IDENTITY breaks batching?**
`IDENTITY`: DB generates ID on INSERT → Hibernate must flush immediately after each INSERT to get ID → cannot batch.
`SEQUENCE`: Hibernate pre-fetches IDs (`allocationSize=50`) → can accumulate 50 inserts and batch them in one round-trip.
Prefer SEQUENCE for high-throughput writes.

**Q9. Open Session in View (OSIV) — why disable it?**
`spring.jpa.open-in-view=true` (default): keeps `EntityManager` open for entire HTTP request including view rendering → lazy loads work in view layer, but:
- Leaks DB connection for entire request duration
- Lazy load in controller/view = hidden N+1 risk
- Set `open-in-view=false`; load everything in `@Transactional` service layer.

**Q10. Dirty checking and readOnly=true?**
On flush, Hibernate compares each managed entity's current state to its snapshot taken at load time. If different → UPDATE issued.
`@Transactional(readOnly=true)`: Hibernate skips snapshot creation and dirty checking → memory savings, faster queries. Use on all read-only service methods.

**Q11. HikariCP sizing formula?**
```
pool_size = (number_of_cores * 2) + effective_spindle_count
```
For most web apps: `maximumPoolSize = 10` is a good starting point. Never set it too high — DB connections are expensive. Monitor `hikaricp.connections.pending`.

**Q12. EntityManager vs Session?**
`EntityManager`: JPA standard interface.
`Session`: Hibernate's extension of `EntityManager` with extra features (`createCriteria`, `saveOrUpdate`, `merge` with return).
Obtain: `entityManager.unwrap(Session.class)`. Prefer JPA API for portability.

**Q13. find() vs getReference()?**
`find(Class, id)`: issues SELECT immediately; returns `null` if not found.
`getReference(Class, id)`: returns hollow proxy; SELECT deferred until first field access; throws `EntityNotFoundException` on access if not found.
Use `getReference()` when you only need a foreign key association (avoids unnecessary SELECT).

**Q14. Page vs Slice in Spring Data?**
`Page<T>`: executes count query + data query; total elements/pages available. Expensive on large tables.
`Slice<T>`: only data query + one extra row to check hasNext(); no count query. Use for cursor/infinite-scroll pagination.

**Q15. @Query — named vs native?**
```java
@Query("SELECT e FROM Employee e WHERE e.dept = :dept")  // JPQL
@Query(value = "SELECT * FROM employee WHERE dept = :dept", nativeQuery = true)  // SQL
```
Use native for DB-specific features (window functions, CTEs). Use JPQL for portability.

---

## Section 4: @Transactional Propagation Quick Reference

| Propagation | Existing TX present | No TX present | Typical Use Case |
|-------------|--------------------|--------------------|-----------------|
| `REQUIRED` (default) | Joins existing | Creates new | Standard service methods |
| `REQUIRES_NEW` | Suspends existing, creates new | Creates new | Audit logging, must-commit-independently |
| `SUPPORTS` | Joins existing | Runs without TX | Read methods that may or may not need TX |
| `NOT_SUPPORTED` | Suspends existing | Runs without TX | Non-transactional operation inside TX context |
| `MANDATORY` | Joins existing | Throws `IllegalTransactionStateException` | Methods that must always be called within TX |
| `NEVER` | Throws `IllegalTransactionStateException` | Runs without TX | Methods that must never run in TX |
| `NESTED` | Creates savepoint in existing TX | Creates new | Partial rollback scenarios (JDBC savepoint) |

**NESTED vs REQUIRES_NEW**: NESTED still participates in outer TX (outer rollback rolls back nested). REQUIRES_NEW is fully independent — inner commit/rollback does not affect outer.

---

## Section 5: AOP Quick Reference

### Pointcut Expression Syntax
```
execution([modifiers] return-type declaring-type.method-name(params) [throws])

execution(* com.example.service.*.*(..))         // all methods in service package
execution(public * *(..))                          // all public methods
execution(* *..Service+.*(..))                     // Service interface and subclasses
within(com.example.service.*)                      // all beans in package
@annotation(org.springframework.transaction.annotation.Transactional)  // annotated methods
bean(*Service)                                     // beans named *Service
args(Long, ..)                                     // first arg is Long
```

### Advice Types
| Annotation | When it runs | Can modify return / suppress exception |
|------------|-------------|----------------------------------------|
| `@Before` | Before method invocation | No |
| `@After` | After method (finally — always) | No |
| `@AfterReturning` | After successful return | Can access return value |
| `@AfterThrowing` | After exception thrown | Can access exception |
| `@Around` | Wraps entire invocation | Yes — full control via `ProceedingJoinPoint` |

### JDK Proxy vs CGLIB
| | JDK Dynamic Proxy | CGLIB |
|--|------------------|-------|
| Requirement | Target must implement interface | No interface needed |
| Mechanism | Proxies interface | Subclasses target class |
| Limitation | Only interface methods proxied | Cannot proxy `final` class/method |
| Boot default | No (Boot 2+ defaults CGLIB) | Yes |

Enable: `@EnableAspectJAutoProxy(proxyTargetClass = true)` (or `spring.aop.proxy-target-class=true`).

### Common AOP Use Cases
- **Logging**: `@Around` — log method entry/exit, duration, arguments
- **Security**: `@Before` — check permissions before method runs
- **Transaction**: `@Around` — begin/commit/rollback (Spring's own `@Transactional`)
- **Caching**: `@Around` — return cached value or proceed and cache result
- **Retry**: `@Around` — catch exception and retry N times
- **Rate limiting**: `@Before` — check rate limit, throw if exceeded

---

## Section 6: Common Spring Traps (15 Items)

1. **Self-invocation bypasses proxy** — `this.method()` inside bean skips AOP/`@Transactional`/`@Cacheable`. Fix: inject self or separate bean.

2. **Prototype in singleton** — prototype injected at singleton construction → lives as long as singleton. Fix: `ObjectProvider`, `@Lookup`, or scoped proxy.

3. **CGLIB fails on final class/method** — `Cannot subclass final class`. Fix: remove `final`, or use JDK proxy with interface.

4. **@Transactional on private method** — Spring proxy cannot intercept private methods. Move to public/protected or use AspectJ weaving.

5. **LazyInitializationException outside transaction** — accessing lazy collection after `EntityManager` closed. Fix: disable OSIV and load eagerly, use `@Transactional`, or use DTO projection.

6. **Circular dependency with constructor injection** — fails at startup (no proxy workaround). Fix: refactor to setter injection, or break cycle with interface/event.

7. **Field injection in unit tests** — `@Autowired` field injection requires Spring context; plain `new` leaves fields null. Fix: constructor injection → testable with `new MyService(mockDep)`.

8. **@Async in same class** — same proxy bypass problem as self-invocation. Fix: move `@Async` method to separate bean.

9. **Missing @EnableAsync** — `@Async` annotations silently ignored without `@EnableAsync` on a `@Configuration` class.

10. **@Cacheable self-call** — `this.cachedMethod()` bypasses cache proxy. Fix: same as self-invocation.

11. **@Transactional on @Bean returning interface** — CGLIB proxy fails if bean declared as concrete class but Spring Boot tries to proxy interface. Be explicit with `proxyTargetClass`.

12. **IDENTITY strategy kills batching** — use SEQUENCE + `allocationSize` for bulk inserts.

13. **OSIV enabled (default) leaks DB connections** — disable with `spring.jpa.open-in-view=false`.

14. **Eager loading by default on @ManyToOne/@OneToOne** — causes unexpected JOIN on every query. Override to LAZY.

15. **Missing @EnableTransactionManagement** — required in plain Spring (not needed in Boot, auto-configured). If transactions silently do nothing, check this.

---

## Section 7: Hibernate Cheat Sheet

### Entity State Transitions (text diagram)
```
new Object()
    │  persist()
    ▼
[TRANSIENT] ──────────────────────────────────────────────────────────┐
                                                                      │
    persist() / merge()                                               │
    ▼                                                                 │
[MANAGED] ──── flush() ──→ DB ◀── SELECT/JPQL ── [MANAGED]          │
    │                                                                 │
    │ close() / evict() / detach()                                   │
    ▼                                                                 │
[DETACHED] ── merge() ──→ [MANAGED]                                  │
                                                                      │
[MANAGED] ── remove() ──→ [REMOVED] ── flush() ──→ DELETE in DB ────┘
```

### Fetch Strategy Comparison
| Strategy | How it works | When to use |
|----------|-------------|-------------|
| `FetchType.LAZY` | Proxy; SELECT on access | Default for collections |
| `FetchType.EAGER` | JOIN in main SELECT | Avoid; causes over-fetching |
| `JOIN FETCH` (JPQL) | Explicit JOIN in query | Targeted loading, avoids N+1 |
| `@BatchSize(size=N)` | IN-clause batching | Collections loaded in batches |
| `@Fetch(SUBSELECT)` | Single sub-SELECT for all children | Full collection loads |

### N+1 Solutions Comparison
| Solution | Query count | Requires schema change | Pros | Cons |
|----------|------------|----------------------|------|------|
| `JOIN FETCH` | 1 | No | Simple JPQL | Cartesian product for multiple collections |
| `@EntityGraph` | 1 | No | Reusable, declarative | Same cartesian issue |
| `@BatchSize` | 1 + N/batch | No | Transparent, no query change | Extra queries, not 1 |
| `@Fetch(SUBSELECT)` | 2 | No | 1 sub-select for all | Loads all children, not pageable |
| DTO projection | 1 | No | Minimal data transfer | No entity lifecycle |

### Batch Insert Configuration
```yaml
spring:
  jpa:
    properties:
      hibernate:
        jdbc.batch_size: 50
        order_inserts: true
        order_updates: true
        generate_statistics: true   # dev only
```
Also requires SEQUENCE id strategy (not IDENTITY).

### Second-Level Cache (L2C)
- L1 = EntityManager (per-session, always on)
- L2 = shared across sessions; opt-in per entity
```java
@Entity
@Cache(usage = CacheConcurrencyStrategy.READ_WRITE)
public class Product { … }
```
Providers: EhCache, Caffeine (via hibernate-jcache), Redis.
Enable: `hibernate.cache.use_second_level_cache=true`, `hibernate.cache.region.factory_class=…`

### Useful Hibernate-Specific Annotations
| Annotation | Purpose |
|-----------|---------|
| `@Formula("(SELECT COUNT(*) FROM orders o WHERE o.cust_id = id)")` | Computed read-only column |
| `@Immutable` | Entity/collection never updated; Hibernate skips dirty check |
| `@NaturalId` | Business key; Hibernate L2C key |
| `@DynamicUpdate` | Only changed columns in UPDATE statement |
| `@DynamicInsert` | Only non-null columns in INSERT |
| `@BatchSize(size=N)` | Batch lazy collection loading |
| `@Fetch(FetchMode.SUBSELECT)` | Sub-select fetch for collections |

### JPA Standard vs Hibernate-Specific
| Feature | JPA Standard | Hibernate |
|---------|-------------|-----------|
| Named query | `@NamedQuery` | same |
| Sequence | `@SequenceGenerator` | `@GenericGenerator` |
| Optimistic lock | `@Version` | same |
| Criteria API | `CriteriaBuilder` | `DetachedCriteria` (legacy) |
| Soft delete | Manual | `@SQLDelete` + `@Where` |
| UUID PK | Manual | `@UuidGenerator` (6.x) |

---

## Section 8: Must-Know Config Snippets

### HikariCP Optimal Config (YAML)
```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10          # cores*2+1 or benchmark
      minimum-idle: 5
      idle-timeout: 600000           # 10 min
      max-lifetime: 1800000          # 30 min (< DB wait_timeout)
      connection-timeout: 30000      # 30 sec
      leak-detection-threshold: 60000 # warn if connection held > 60s
      pool-name: HikariPool-main
      connection-test-query: SELECT 1  # for databases without JDBC4
```

### @Transactional with Propagation Example
```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepo;
    private final AuditService auditService;  // separate bean

    @Transactional                           // REQUIRED (default)
    public Order placeOrder(OrderRequest req) {
        Order order = orderRepo.save(new Order(req));
        auditService.log(order);             // REQUIRES_NEW — commits independently
        return order;
    }
}

@Service
public class AuditService {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void log(Order order) {
        // saved even if outer transaction rolls back
        auditRepo.save(new AuditLog(order));
    }
}
```

### N+1 Fix with @EntityGraph
```java
// Entity
@Entity
public class Order {
    @ManyToOne(fetch = FetchType.LAZY)
    private Customer customer;

    @OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
    private List<OrderItem> items;
}

// Repository
public interface OrderRepository extends JpaRepository<Order, Long> {

    @EntityGraph(attributePaths = {"customer", "items"})
    List<Order> findByStatus(String status);

    // Named EntityGraph alternative
    @EntityGraph("Order.withCustomerAndItems")
    Optional<Order> findById(Long id);
}

// Entity with named graph
@Entity
@NamedEntityGraph(
    name = "Order.withCustomerAndItems",
    attributeNodes = {
        @NamedAttributeNode("customer"),
        @NamedAttributeNode("items")
    }
)
public class Order { … }
```

### Custom JPA Repository with @Query
```java
public interface ProductRepository extends JpaRepository<Product, Long>,
        JpaSpecificationExecutor<Product> {

    // JPQL — returns projection interface
    @Query("SELECT p.id AS id, p.name AS name, p.price AS price " +
           "FROM Product p WHERE p.category = :category AND p.active = true")
    List<ProductSummary> findSummariesByCategory(@Param("category") String category);

    // Native query with pagination
    @Query(
        value = "SELECT * FROM product WHERE price BETWEEN :min AND :max",
        countQuery = "SELECT COUNT(*) FROM product WHERE price BETWEEN :min AND :max",
        nativeQuery = true
    )
    Page<Product> findByPriceRange(@Param("min") BigDecimal min,
                                   @Param("max") BigDecimal max,
                                   Pageable pageable);

    // Modifying query
    @Modifying
    @Transactional
    @Query("UPDATE Product p SET p.active = false WHERE p.expiresAt < :now")
    int deactivateExpired(@Param("now") LocalDateTime now);
}

// Projection interface
public interface ProductSummary {
    Long getId();
    String getName();
    BigDecimal getPrice();
}
```

### Spring Security FilterChain Skeleton
```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)   // enables @PreAuthorize
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)          // stateless API
            .sessionManagement(sm -> sm
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health").permitAll()
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated())
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint(customEntryPoint)
                .accessDeniedHandler(customAccessDeniedHandler));
        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    public AuthenticationManager authenticationManager(
            AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
}
```

---

## Quick-Hit Mnemonics

- **Bean scopes**: S-P-R-S-A (Singleton, Prototype, Request, Session, Application)
- **Lifecycle**: I-P-A-B-I-B → "In Production A Bean Is Busy" (Instantiate, Populate, Aware, BPP-before, Init, BPP-after)
- **Propagation required vs requires_new**: `REQUIRED` = join the party; `REQUIRES_NEW` = bring your own room
- **IDENTITY kills batching**: "IDENTITY = 1 flush per INSERT" — use SEQUENCE
- **OSIV=false**: "close the session early, load everything in service layer"
- **N+1 quick fix hierarchy**: JOIN FETCH > @EntityGraph > @BatchSize > @Fetch(SUBSELECT)

---

*Chapter 24 — Spring & JPA Revision | Volume 6: Interview Revision Pack*


