# Chapter 7: Spring Core & Spring Boot

**Volume 2 — Spring Ecosystem**
**Target:** Java SDE2 | FAANG+, FinTech, SaaS/Enterprise
**Baseline:** Java 17 LTS | Spring Boot 3.x | Spring 6.x

---

## Table of Contents

1. [IoC — Inversion of Control](#1-ioc--inversion-of-control)
2. [Dependency Injection Types](#2-dependency-injection-types)
3. [@Autowired Internals](#3-autowired-internals)
4. [Stereotype Annotations](#4-stereotype-annotations)
5. [Bean Scopes](#5-bean-scopes)
6. [Bean Lifecycle — Full Sequence](#6-bean-lifecycle--full-sequence)
7. [BeanPostProcessor vs BeanFactoryPostProcessor](#7-beanpostprocessor-vs-beanfactorypostprocessor)
8. [@PostConstruct and @PreDestroy](#8-postconstruct-and-predestroy)
9. [Circular Dependencies](#9-circular-dependencies)
10. [AOP Fundamentals](#10-aop-fundamentals)
11. [@Transactional Internals](#11-transactional-internals)
12. [Common AOP Use Cases in Production](#12-common-aop-use-cases-in-production)
13. [Spring Boot Auto-Configuration Internals](#13-spring-boot-auto-configuration-internals)
14. [@SpringBootApplication](#14-springbootapplication)
15. [application.properties vs application.yml](#15-applicationproperties-vs-applicationyml)
16. [Spring Profiles](#16-spring-profiles)
17. [Spring Boot Actuator](#17-spring-boot-actuator)
18. [Spring Boot Startup Sequence](#18-spring-boot-startup-sequence)
19. [@Configuration vs @Component for @Bean Methods](#19-configuration-vs-component-for-bean-methods)
20. [@Conditional Annotations](#20-conditional-annotations)
21. [Spring Events](#21-spring-events)
22. [@Value and SpEL](#22-value-and-spel)
- [ASCII Bean Lifecycle Diagram](#ascii-bean-lifecycle-diagram)
- [Quick Reference: Annotation Table](#quick-reference-annotation-table)
- [Proxy Type Selection Table](#proxy-type-selection-table)

---

## 1. IoC — Inversion of Control

**Difficulty:** Easy | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Microsoft, Goldman Sachs, Adobe, Salesforce, JPMorgan, Uber

---

### Short Interview Answer (30–60 seconds)

IoC means the framework controls the creation and wiring of objects rather than the application code doing it manually. In Spring, the ApplicationContext is the IoC container — it instantiates beans, injects their dependencies, manages their lifecycle, and destroys them on shutdown. Your code declares what it needs; Spring figures out how to provide it.

---

### Deep Explanation

**IoC as a design principle:**
Without IoC, your class does `new OrderRepository()` and is tightly coupled to the concrete implementation. IoC inverts this: the container creates `OrderRepository` and hands it to `OrderService`. The class has no knowledge of how its dependencies are constructed.

**BeanFactory vs ApplicationContext:**

| Feature | BeanFactory | ApplicationContext |
|---|---|---|
| Bean instantiation | Lazy by default | Eager for singletons by default |
| AOP integration | No | Yes |
| Application events | No | Yes (`ApplicationEventPublisher`) |
| i18n / MessageSource | No | Yes |
| BeanPostProcessor auto-registration | Manual | Automatic |
| Typical use | Embedded/constrained environments | All standard applications |

`ApplicationContext` extends `BeanFactory`. In practice, you never use `BeanFactory` directly in modern Spring; it is the internal SPI. `ClassPathXmlApplicationContext`, `AnnotationConfigApplicationContext`, and `SpringApplication`-created contexts all implement `ApplicationContext`.

**Spring implementation of IoC:**
Spring uses reflection and metadata (annotations, XML, Java config) to build a `BeanDefinition` registry. At refresh time, it resolves the dependency graph, instantiates beans in dependency order, injects collaborators, and runs lifecycle callbacks.

---

### Real-World Backend Example

A payment processing service has `PaymentService` depending on `FraudDetector`, `AuditLogger`, and `PaymentGatewayClient`. Without IoC you write constructors chaining `new` calls, coupling the entire tree. With Spring IoC each class declares its dependencies; the container assembles the graph at startup — including swapping `MockPaymentGatewayClient` in tests without changing any production code.

---

### Code Example

```java
// ApplicationContext created by Spring Boot — you rarely do this manually
@SpringBootApplication
public class PaymentApp {
    public static void main(String[] args) {
        ConfigurableApplicationContext ctx = SpringApplication.run(PaymentApp.class, args);

        // Retrieve a bean — demonstrates the container in action
        PaymentService svc = ctx.getBean(PaymentService.class);
        svc.processPayment(new PaymentRequest());
    }
}

// Programmatic context (useful in tests or non-Boot code)
AnnotationConfigApplicationContext ctx =
    new AnnotationConfigApplicationContext(AppConfig.class);
PaymentService svc = ctx.getBean(PaymentService.class);
ctx.close();
```

---

### Follow-Up Questions

- What is the difference between `BeanFactory` and `ApplicationContext`?
- How does Spring know the order in which to instantiate beans?
- Can you get a bean from the container at runtime (service locator pattern)? When is that acceptable?

---

### Common Mistakes

- Confusing IoC (the principle) with DI (the mechanism that implements it).
- Saying ApplicationContext is just a "better BeanFactory" without explaining what it adds.
- Not knowing that ApplicationContext eager-initializes singletons by default — which is why startup errors surface immediately.

---

### Interview Traps

- **Trap:** "BeanFactory is deprecated." — False. It is still the root interface; ApplicationContext extends it.
- **Trap:** Saying "Spring creates all beans lazily." — Wrong. Singleton beans are eager by default. Add `@Lazy` to defer.

---

### Quick Revision Notes

- IoC = framework controls object creation; DI = mechanism to supply dependencies.
- `ApplicationContext` adds AOP, events, i18n, eager singleton init on top of `BeanFactory`.
- `BeanDefinition` is Spring's metadata object for each bean (class, scope, init method, etc.).
- `SpringApplication.run()` creates an `AnnotationConfigServletWebServerApplicationContext` for servlet apps.

---

## 2. Dependency Injection Types

**Difficulty:** Easy | **Interview Frequency:** Very High

**Companies:** Amazon, Adobe, Salesforce, Goldman Sachs, Stripe, Atlassian

---

### Short Interview Answer (30–60 seconds)

Spring supports three injection styles: constructor injection, setter injection, and field injection. Constructor injection is the recommended approach — it makes dependencies explicit, enables immutability with `final` fields, and works without Spring in unit tests. Field injection with `@Autowired` is the most concise but the least testable and hides dependencies. Spring's own documentation has recommended constructor injection since version 4.x.

---

### Deep Explanation

**Constructor Injection:**
Dependencies are supplied through the constructor. If there is exactly one constructor, Spring 4.3+ auto-wires it without `@Autowired`. Fields can be `final`, ensuring the object is always in a valid, fully initialized state.

**Setter Injection:**
Dependencies are supplied through setter methods. Suitable for optional dependencies or for breaking circular dependencies in edge cases. The object can exist in a partially initialized state, which is a risk.

**Field Injection:**
`@Autowired` placed directly on a field. Spring uses reflection to inject the value, bypassing encapsulation. You cannot write `new OrderService()` in a unit test without using Spring or a reflection helper like `ReflectionTestUtils`. Considered a code smell in production code.

**Spring's own stance:**
The Spring team publicly recommends constructor injection for mandatory dependencies and setter injection for optional dependencies. Field injection appears in Spring's own older sample code but is no longer recommended.

---

### Real-World Backend Example

An `OrderService` in an e-commerce system depends on `InventoryClient`, `PricingEngine`, and `OrderRepository`. Using constructor injection, a unit test can instantiate `OrderService` with mocks using `new OrderService(mockInventory, mockPricing, mockRepo)` — no Spring context, no `@SpringBootTest`, fast test execution.

---

### Code Example

```java
// RECOMMENDED: Constructor injection
@Service
public class OrderService {

    private final InventoryClient inventoryClient;
    private final PricingEngine pricingEngine;
    private final OrderRepository orderRepository;

    // @Autowired optional if single constructor (Spring 4.3+)
    public OrderService(InventoryClient inventoryClient,
                        PricingEngine pricingEngine,
                        OrderRepository orderRepository) {
        this.inventoryClient = inventoryClient;
        this.pricingEngine = pricingEngine;
        this.orderRepository = orderRepository;
    }
}

// Setter injection — optional dependency example
@Service
public class NotificationService {

    private EmailClient emailClient;

    @Autowired(required = false)
    public void setEmailClient(EmailClient emailClient) {
        this.emailClient = emailClient;
    }
}

// Field injection — avoid in production
@Service
public class ReportService {
    @Autowired  // bad: hidden dependency, not testable without Spring
    private ReportRepository reportRepository;
}
```

---

### Follow-Up Questions

- How do you unit test a class that uses field injection?
- Can you have multiple constructors with `@Autowired`?
- Why can't field injection be used with `final` fields?

---

### Common Mistakes

- Using field injection everywhere because it is less verbose, then struggling to write fast unit tests.
- Forgetting that `@Autowired(required = false)` makes the dependency optional — the field will be `null` if no bean is found.
- Believing setter injection is deprecated; it is not — it is valid for optional dependencies.

---

### Interview Traps

- **Trap:** "Constructor injection causes circular dependency issues." — True, but that is a feature: circular deps are usually a design flaw. Spring cannot resolve constructor-based circular deps and forces you to fix the design.
- **Trap:** "Field injection is fine in tests." — Only because test frameworks tolerate it. It is still an anti-pattern.

---

### Quick Revision Notes

- Constructor injection: `final` fields, explicit deps, testable without Spring.
- Setter injection: optional deps, post-construction reconfiguration.
- Field injection: concise but violates encapsulation and prevents pure unit testing.
- Spring 4.3+: single-constructor classes auto-wired — no `@Autowired` annotation needed.

---

## 3. @Autowired Internals

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Microsoft, Uber, Flipkart, PayPal

---

### Short Interview Answer (30–60 seconds)

`@Autowired` is processed by `AutowiredAnnotationBeanPostProcessor`. It first resolves by type — if exactly one bean matches, it is injected. If multiple beans of the same type exist, Spring falls back to matching by the field or parameter name. `@Qualifier` pins a specific bean by name. `@Primary` marks a default bean when no qualifier is specified. If ambiguity remains, Spring throws `NoUniqueBeanDefinitionException`.

---

### Deep Explanation

**AutowiredAnnotationBeanPostProcessor:**
This `BeanPostProcessor` scans every bean after instantiation for `@Autowired`, `@Value`, and `@Inject` annotations. For each injection point it calls `DefaultListableBeanFactory.resolveDependency()`, which does:

1. Find all beans of the required type (`getBeansOfType()`).
2. If exactly one match — inject it.
3. If multiple matches — check `@Primary` first, then fall back to name matching (field name vs bean name).
4. If still ambiguous and no `@Qualifier` — throw `NoUniqueBeanDefinitionException`.

**Resolution order:**
```
By type → @Primary → By name (@Qualifier / field name) → NoUniqueBeanDefinitionException
```

**@Qualifier:**
`@Qualifier("stripePaymentGateway")` directly names the target bean. Can also be used as a meta-annotation to create custom qualifiers (e.g., `@Stripe`, `@PayPal`).

**@Primary:**
Applied to a bean definition to indicate "prefer this bean when multiple candidates exist." Useful when a library provides a generic bean and you want to override it without changing every injection point.

---

### Real-World Backend Example

A FinTech application has `StripePaymentGateway` and `PayPalPaymentGateway` both implementing `PaymentGateway`. By default this causes `NoUniqueBeanDefinitionException`. Resolution: annotate `StripePaymentGateway` with `@Primary` (system default), and use `@Qualifier("payPalPaymentGateway")` only where PayPal is explicitly needed.

---

### Code Example

```java
public interface PaymentGateway {
    PaymentResult charge(Money amount);
}

@Service
@Primary  // default bean
public class StripePaymentGateway implements PaymentGateway { ... }

@Service
public class PayPalPaymentGateway implements PaymentGateway { ... }

@Service
public class CheckoutService {

    private final PaymentGateway defaultGateway;  // gets StripePaymentGateway via @Primary
    private final PaymentGateway payPalGateway;

    public CheckoutService(PaymentGateway defaultGateway,
                           @Qualifier("payPalPaymentGateway") PaymentGateway payPalGateway) {
        this.defaultGateway = defaultGateway;
        this.payPalGateway = payPalGateway;
    }
}

// Inject all implementations as a list
@Service
public class PaymentRouter {
    private final List<PaymentGateway> gateways;

    public PaymentRouter(List<PaymentGateway> gateways) {  // Spring injects all beans of this type
        this.gateways = gateways;
    }
}
```

---

### Follow-Up Questions

- What exception is thrown when two beans of the same type exist and neither is `@Primary` nor `@Qualifier`-qualified?
- How would you inject all beans of a given type?
- What is the order of resolution for `@Autowired`?

---

### Common Mistakes

- Expecting `@Qualifier` on a field alone to work without also placing it at the matching `@Bean` method or class — the qualifier name must match.
- Confusing `@Primary` (type-level preference) with `@Qualifier` (explicit pinning).
- Not knowing that you can inject `List<T>`, `Set<T>`, or `Map<String, T>` to get all beans of a type.

---

### Interview Traps

- **Trap:** "If I have two beans and I name my field exactly like one bean name, Spring auto-resolves." — Technically true, but relying on field names for disambiguation is fragile. Always use `@Qualifier` explicitly.
- **Trap:** "`@Autowired` is the only way to inject." — `@Inject` (JSR-330) works identically. `@Resource` (JSR-250) resolves by name first.

---

### Quick Revision Notes

- `AutowiredAnnotationBeanPostProcessor` drives `@Autowired` resolution.
- Resolution order: by type → `@Primary` → by name/`@Qualifier` → `NoUniqueBeanDefinitionException`.
- `@Primary`: mark one bean as the default; `@Qualifier`: pinpoint a specific bean by name.
- `List<PaymentGateway>` injection collects all beans implementing the interface.

---

## 4. Stereotype Annotations

**Difficulty:** Easy | **Interview Frequency:** High

**Companies:** Amazon, Adobe, Infosys, TCS, Walmart Labs, Deutsche Bank

---

### Short Interview Answer (30–60 seconds)

`@Component` is the generic stereotype. `@Service`, `@Repository`, and `@Controller` are specializations that carry the same component-scanning behavior but add semantic meaning. `@Repository` goes further — it activates Spring's `PersistenceExceptionTranslationPostProcessor`, which translates technology-specific persistence exceptions (like `HibernateException`) into Spring's `DataAccessException` hierarchy. `@Controller` marks a class as an MVC endpoint handler.

---

### Deep Explanation

**Component scanning:**
`@ComponentScan` (implied by `@SpringBootApplication`) instructs Spring to scan the specified base package and register any class annotated with `@Component` or its meta-annotations as a bean.

**Stereotype differences in depth:**

| Annotation | Extends | Extra Behavior |
|---|---|---|
| `@Component` | — | Base stereotype; detected by component scanning |
| `@Service` | `@Component` | Purely semantic; no extra Spring magic |
| `@Repository` | `@Component` | Triggers `PersistenceExceptionTranslationPostProcessor` |
| `@Controller` | `@Component` | Marks handler methods (`@RequestMapping`) for Spring MVC |
| `@RestController` | `@Controller` + `@ResponseBody` | All methods return response body directly |

**PersistenceExceptionTranslation:**
`@Repository` beans are wrapped so that exceptions thrown by JPA, Hibernate, JDBC, etc., are caught and translated into Spring's `DataAccessException` subclasses (`DataIntegrityViolationException`, `EmptyResultDataAccessException`, etc.). This decouples your service layer from JPA-specific exceptions.

---

### Real-World Backend Example

A `UserRepository` annotated with `@Repository` throws a `ConstraintViolationException` (JPA/Hibernate) when you try to save a duplicate email. With `@Repository`, the exception is translated to `DataIntegrityViolationException` before it reaches `UserService`. The service layer never imports Hibernate classes.

---

### Code Example

```java
@Repository
public class UserJpaRepository {

    @PersistenceContext
    private EntityManager em;

    public User save(User user) {
        em.persist(user);   // If duplicate: ConstraintViolationException
        return user;        // Spring translates to DataIntegrityViolationException
    }
}

@Service
public class UserService {

    private final UserJpaRepository repo;

    public UserService(UserJpaRepository repo) {
        this.repo = repo;
    }

    public User register(UserRequest request) {
        try {
            return repo.save(new User(request.email()));
        } catch (DataIntegrityViolationException ex) {
            throw new EmailAlreadyExistsException(request.email());
        }
        // No import of org.hibernate.exception.ConstraintViolationException here
    }
}
```

---

### Follow-Up Questions

- What happens if you annotate a repository with `@Component` instead of `@Repository`?
- What is the difference between `@Controller` and `@RestController`?
- How does component scanning find beans across multiple packages?

---

### Common Mistakes

- Using `@Service` on a repository or DAO class — it works for bean creation but loses exception translation.
- Not knowing that `@RestController` is a composed annotation (`@Controller` + `@ResponseBody`).
- Believing all stereotypes are identical — the exception translation from `@Repository` is a real behavioral difference.

---

### Interview Traps

- **Trap:** "All stereotype annotations do the same thing." — `@Repository` has concrete extra behavior via `PersistenceExceptionTranslationPostProcessor`.

---

### Quick Revision Notes

- All stereotypes are detected by component scanning; `@Component` is the root.
- `@Repository` adds persistence exception translation via `PersistenceExceptionTranslationPostProcessor`.
- `@Controller` activates Spring MVC handler detection.
- `@RestController` = `@Controller` + `@ResponseBody`.

---

## 5. Bean Scopes

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Uber, Salesforce, Shopify, JPMorgan, Visa

---

### Short Interview Answer (30–60 seconds)

Spring has six built-in scopes. `singleton` (default) creates one instance per container. `prototype` creates a new instance every time the bean is requested. `request`, `session`, `application`, and `websocket` are web-aware scopes tied to HTTP lifecycle. The most common interview focus is the scope-mismatch problem: injecting a `prototype` bean into a `singleton` bean. Since the singleton is created once, it holds one prototype reference forever, effectively making it singleton too. The fix is `ObjectProvider`, `@Lookup`, or a scoped proxy.

---

### Deep Explanation

**Singleton:**
One instance per `ApplicationContext`. The container holds a reference in its `singletonObjects` map. Stateless service beans, repositories, and clients should be singletons. Not thread-safe by default — your code must be stateless or use synchronization.

**Prototype:**
A new instance is created each time `context.getBean()` is called or the dependency is injected. Spring does not manage the lifecycle of prototype beans after creation — `@PreDestroy` is NOT called for prototype beans.

**Web scopes:**
- `request`: new instance per HTTP request.
- `session`: new instance per HTTP session.
- `application`: one instance per `ServletContext` (broader than singleton in a servlet app with multiple contexts).
- `websocket`: one instance per WebSocket session.

**Scope mismatch — the prototype-in-singleton problem:**

```
Singleton A created once → holds reference to Prototype B
B is injected once at A's creation time → B never refreshes
Result: B behaves as a singleton inside A
```

**Solutions:**

1. **`ObjectProvider<B>`** — inject the provider; call `provider.getObject()` each time a new B is needed.
2. **`@Lookup` method injection** — Spring overrides the method via CGLIB to return a new prototype each call.
3. **Scoped proxy** — `@Scope(value="prototype", proxyMode=ScopedProxyMode.TARGET_CLASS)` — Spring injects a proxy; every method call on the proxy delegates to a new target instance.

---

### Real-World Backend Example

A singleton `ReportGenerator` service needs a new `ReportContext` (prototype) per report generation call, because `ReportContext` holds mutable per-report state. Injecting `ReportContext` directly into the singleton would share one context across all reports. Using `ObjectProvider<ReportContext>` ensures a fresh instance per call.

---

### Code Example

```java
@Component
@Scope("prototype")
public class ReportContext {
    private final List<String> lines = new ArrayList<>();
    private LocalDateTime startTime = LocalDateTime.now();
    // mutable per-report state
}

// Solution 1: ObjectProvider
@Service
public class ReportGenerator {

    private final ObjectProvider<ReportContext> contextProvider;

    public ReportGenerator(ObjectProvider<ReportContext> contextProvider) {
        this.contextProvider = contextProvider;
    }

    public Report generate(ReportRequest request) {
        ReportContext ctx = contextProvider.getObject();  // new instance each call
        // use ctx...
        return new Report(ctx);
    }
}

// Solution 2: @Lookup method injection
@Service
public abstract class ReportGeneratorLookup {

    @Lookup
    protected abstract ReportContext createContext();  // Spring provides implementation

    public Report generate(ReportRequest request) {
        ReportContext ctx = createContext();
        return new Report(ctx);
    }
}

// Solution 3: Scoped proxy
@Component
@Scope(value = "prototype", proxyMode = ScopedProxyMode.TARGET_CLASS)
public class ReportContextProxy {
    // Spring generates CGLIB subclass; each method call uses a new target
}
```

---

### Follow-Up Questions

- Is `@PreDestroy` called for prototype beans?
- What is `ScopedProxyMode.INTERFACES` vs `ScopedProxyMode.TARGET_CLASS`?
- When would you use `session` scope in a REST API?

---

### Common Mistakes

- Assuming prototype beans are destroyed by Spring — they are not.
- Injecting `ApplicationContext` and calling `getBean()` everywhere as a service locator instead of `ObjectProvider`.
- Using `session` scope in a stateless REST API (session scope only makes sense with `HttpSession`-backed state).

---

### Interview Traps

- **Trap:** "Prototype beans are not singletons, so they are safe for concurrent use." — A prototype bean is freshly created but it may still reference shared singleton state internally.
- **Trap:** "Thread safety is guaranteed by singleton scope." — No. Singleton means one instance; your methods must still be stateless or synchronized.

---

### Quick Revision Notes

- `singleton`: one per container, eager init, lifecycle managed fully.
- `prototype`: new instance per request, `@PreDestroy` not called.
- Scope mismatch: prototype injected into singleton stays as one instance — fix with `ObjectProvider`, `@Lookup`, or scoped proxy.
- Web scopes (`request`, `session`) require active `WebApplicationContext`.

---

## 6. Bean Lifecycle — Full Sequence

**Difficulty:** Hard | **Interview Frequency:** Very High

**Companies:** Amazon, Goldman Sachs, Adobe, Salesforce, Google, Microsoft

---

### Short Interview Answer (30–60 seconds)

Spring's bean lifecycle has roughly four phases: instantiation, dependency injection, initialization callbacks, and destruction callbacks. After the container creates the bean and injects properties, it runs `Aware` interface callbacks so the bean can access container metadata, then `BeanPostProcessor.postProcessBeforeInitialization`, then `@PostConstruct` / `InitializingBean.afterPropertiesSet` / custom init-method, then `BeanPostProcessor.postProcessAfterInitialization`. On shutdown: `@PreDestroy` / `DisposableBean.destroy` / custom destroy-method.

---

### Deep Explanation

**Full sequence in detail:**

```
1.  Instantiate bean (constructor called)
2.  Populate properties (@Autowired, @Value injection)
3.  BeanNameAware.setBeanName()
4.  BeanClassLoaderAware.setBeanClassLoader()
5.  BeanFactoryAware.setBeanFactory()
6.  EnvironmentAware.setEnvironment()
7.  EmbeddedValueResolverAware.setEmbeddedValueResolver()
8.  ResourceLoaderAware.setResourceLoader()
9.  ApplicationEventPublisherAware.setApplicationEventPublisher()
10. MessageSourceAware.setMessageSource()
11. ApplicationContextAware.setApplicationContext()
12. BeanPostProcessor.postProcessBeforeInitialization()  [all registered BPPs run]
13. @PostConstruct method(s)
14. InitializingBean.afterPropertiesSet()
15. Custom init-method (init-method attribute / @Bean(initMethod="..."))
16. BeanPostProcessor.postProcessAfterInitialization()  [all registered BPPs run — AOP proxy created here]
    → Bean is now READY for use
    ---
17. @PreDestroy method(s)                              [on context.close()]
18. DisposableBean.destroy()
19. Custom destroy-method
```

**Key insight — AOP proxy creation:**
`AbstractAutoProxyCreator` is a `BeanPostProcessor`. It runs at step 16 (`postProcessAfterInitialization`) and wraps the target bean in a JDK or CGLIB proxy if any advice applies. The bean stored in `singletonObjects` is the proxy, not the original instance.

**Aware interfaces:**
Used when a bean needs to access the Spring container or metadata. Example: `ApplicationContextAware` lets a bean look up other beans at runtime (service locator pattern). Generally avoid unless necessary — it couples the bean to Spring.

---

### Real-World Backend Example

A `CacheWarmingService` needs to pre-load data from a database after the bean is fully wired. It implements `@PostConstruct` to load cache entries. A `ConnectionPool` bean implements `@PreDestroy` to drain connections before JVM shutdown. A `MetricsReporter` implements `ApplicationContextAware` to dynamically discover all beans implementing `Metric` after startup.

---

### Code Example

```java
@Service
public class CacheWarmingService implements BeanNameAware, ApplicationContextAware {

    private String beanName;
    private ApplicationContext context;
    private final ProductRepository productRepository;

    public CacheWarmingService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    @Override
    public void setBeanName(String name) {
        this.beanName = name;  // step 3
        System.out.println("Bean name: " + beanName);
    }

    @Override
    public void setApplicationContext(ApplicationContext applicationContext) {
        this.context = applicationContext;  // step 11
    }

    @PostConstruct
    public void warmUp() {
        // step 13 — runs after all properties are set
        List<Product> featured = productRepository.findFeatured();
        featured.forEach(p -> CacheStore.put(p.id(), p));
        System.out.println("Cache warmed: " + featured.size() + " products");
    }

    @PreDestroy
    public void flushCache() {
        // step 17 — runs before bean is destroyed
        CacheStore.clear();
        System.out.println("Cache cleared");
    }
}
```

---

### Follow-Up Questions

- At which step does Spring create the AOP proxy?
- What is the difference between `@PostConstruct` and `InitializingBean.afterPropertiesSet()`?
- What happens to lifecycle callbacks on prototype beans?

---

### Common Mistakes

- Believing `@PostConstruct` runs before dependency injection — it runs after properties are set.
- Forgetting that `@PreDestroy` does not run for prototype-scoped beans.
- Implementing `ApplicationContextAware` when constructor injection would suffice — overcomplicates the design.

---

### Interview Traps

- **Trap:** "The AOP proxy is created during instantiation." — Wrong. It is created at step 16, inside `BeanPostProcessor.postProcessAfterInitialization`.
- **Trap:** "InitializingBean and @PostConstruct do the same thing." — They do, but `InitializingBean` couples the class to Spring API; `@PostConstruct` (JSR-250) does not.

---

### Quick Revision Notes

- Full sequence: instantiate → inject → Aware → BPP.before → `@PostConstruct` → `afterPropertiesSet` → init-method → BPP.after → READY → `@PreDestroy` → `destroy` → destroy-method.
- AOP proxy is created in step 16 (BPP.postProcessAfterInitialization).
- `@PreDestroy` is not called for prototype beans.
- Prefer `@PostConstruct`/`@PreDestroy` over `InitializingBean`/`DisposableBean` to avoid Spring API coupling.

---

## 7. BeanPostProcessor vs BeanFactoryPostProcessor

**Difficulty:** Hard | **Interview Frequency:** High

**Companies:** Amazon, Google, Pivotal (VMware), Goldman Sachs, Adobe

---

### Short Interview Answer (30–60 seconds)

`BeanFactoryPostProcessor` runs once before any beans are created — it modifies bean definitions, not bean instances. `PropertySourcesPlaceholderConfigurer` is the canonical example: it reads `application.properties` and updates `${placeholder}` values in bean definitions before instantiation. `BeanPostProcessor` runs per bean after instantiation — it modifies or wraps individual bean instances. `AutowiredAnnotationBeanPostProcessor` and `AbstractAutoProxyCreator` (for AOP) are examples.

---

### Deep Explanation

**BeanFactoryPostProcessor:**
- Registered in the `ApplicationContext` before any regular beans are created.
- Receives a `ConfigurableListableBeanFactory` containing all registered `BeanDefinition` objects.
- Can add, modify, or remove bean definitions.
- Must itself be a static `@Bean` method in `@Configuration` to avoid premature instantiation issues.

```
ApplicationContext refresh → register all BeanDefinitions
→ instantiate and invoke all BeanFactoryPostProcessors
→ now instantiate all other beans
```

**BeanPostProcessor:**
- Registered during normal bean creation.
- `postProcessBeforeInitialization(Object bean, String beanName)` — runs before init callbacks.
- `postProcessAfterInitialization(Object bean, String beanName)` — runs after init callbacks; returns the bean (or a proxy replacing it).
- Returning `null` from either method uses the original bean — be careful.

**Well-known implementations:**

| Impl | Type | What it does |
|---|---|---|
| `PropertySourcesPlaceholderConfigurer` | BFPP | Resolves `${...}` placeholders in bean definitions |
| `AutowiredAnnotationBeanPostProcessor` | BPP | Processes `@Autowired`, `@Value`, `@Inject` |
| `CommonAnnotationBeanPostProcessor` | BPP | Processes `@PostConstruct`, `@PreDestroy`, `@Resource` |
| `AbstractAutoProxyCreator` | BPP | Creates AOP proxies for `@Transactional`, `@Cacheable`, etc. |
| `ConfigurationClassPostProcessor` | BFPP | Processes `@Configuration` classes, `@ComponentScan`, `@Import` |

---

### Code Example

```java
// Custom BeanFactoryPostProcessor — modifies a bean definition before instantiation
@Component
public class DatabaseBeanDefinitionPostProcessor implements BeanFactoryPostProcessor {

    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) {
        BeanDefinition bd = beanFactory.getBeanDefinition("dataSource");
        bd.getPropertyValues().add("maxPoolSize", "50");  // override config programmatically
    }
}

// Custom BeanPostProcessor — wraps every service bean with an execution timer
@Component
public class ExecutionTimerPostProcessor implements BeanPostProcessor {

    @Override
    public Object postProcessAfterInitialization(Object bean, String beanName) {
        if (bean.getClass().isAnnotationPresent(Service.class)) {
            return Proxy.newProxyInstance(
                bean.getClass().getClassLoader(),
                bean.getClass().getInterfaces(),
                (proxy, method, args) -> {
                    long start = System.nanoTime();
                    Object result = method.invoke(bean, args);
                    long elapsed = System.nanoTime() - start;
                    log.info("{}.{} took {}ns", beanName, method.getName(), elapsed);
                    return result;
                }
            );
        }
        return bean;
    }
}
```

---

### Follow-Up Questions

- Why must `BeanFactoryPostProcessor` beans be declared as `static @Bean` methods in `@Configuration` classes?
- Can a `BeanPostProcessor` return a completely different object than the one passed to it?
- What happens if a `BeanPostProcessor` throws an exception?

---

### Common Mistakes

- Confusing the two: BFPP modifies definitions; BPP modifies instances.
- Forgetting that `BeanPostProcessor` beans themselves are special — they are instantiated early by the container and do not receive full BPP processing themselves.

---

### Interview Traps

- **Trap:** "I can use `@Autowired` freely in a `BeanFactoryPostProcessor`." — Risky. BFPPs are instantiated very early; not all beans may be available, causing premature instantiation.

---

### Quick Revision Notes

- BFPP: modifies `BeanDefinition` objects before any beans are created. Runs once.
- BPP: modifies/wraps bean instances after creation. Runs per-bean, twice (before and after init).
- `ConfigurationClassPostProcessor` (BFPP) processes `@Configuration`; `AutowiredAnnotationBeanPostProcessor` (BPP) handles `@Autowired`.

---

## 8. @PostConstruct and @PreDestroy

**Difficulty:** Easy | **Interview Frequency:** High

**Companies:** Amazon, Atlassian, Salesforce, Visa, Morgan Stanley

---

### Short Interview Answer (30–60 seconds)

`@PostConstruct` marks a method that Spring calls after dependency injection is complete and before the bean is put into service. `@PreDestroy` marks a method called just before the bean is destroyed on context close. Both are JSR-250 annotations — they work with Spring but have no Spring API import in your class. They are preferred over `InitializingBean`/`DisposableBean` because the class remains decoupled from Spring.

---

### Deep Explanation

**Processing:**
Both are handled by `CommonAnnotationBeanPostProcessor`:
- `@PostConstruct` is invoked in `postProcessBeforeInitialization` (before `InitializingBean.afterPropertiesSet`).
- `@PreDestroy` is registered as a destroy callback and called during context `close()`.

**Constraints:**
- Method must have no parameters.
- Method must return void.
- Method must not be static.
- Only one `@PostConstruct` per class is reliable (multiple are technically allowed but order is not guaranteed).

**Use cases for `@PostConstruct`:**
- Warming caches
- Validating configuration (e.g., fail fast if a required external URL is unreachable)
- Starting background threads or schedulers
- Pre-computing derived values

**Use cases for `@PreDestroy`:**
- Releasing database connections
- Flushing buffers / persisting in-memory state
- Shutting down thread pools
- Deregistering from service registries (e.g., deregister from Consul)

---

### Code Example

```java
@Service
public class ExchangeRateService {

    private final ExchangeRateClient client;
    private volatile Map<String, BigDecimal> rateCache;

    public ExchangeRateService(ExchangeRateClient client) {
        this.client = client;
    }

    @PostConstruct
    public void init() {
        rateCache = client.fetchCurrentRates();
        log.info("Exchange rate cache initialized with {} entries", rateCache.size());
    }

    public BigDecimal getRate(String currencyPair) {
        return rateCache.getOrDefault(currencyPair, BigDecimal.ONE);
    }

    @PreDestroy
    public void shutdown() {
        log.info("ExchangeRateService shutting down, clearing rate cache");
        rateCache = Collections.emptyMap();
        client.close();
    }
}
```

---

### Follow-Up Questions

- What is the execution order: `@PostConstruct` vs `InitializingBean.afterPropertiesSet` vs custom `init-method`?
- Is `@PreDestroy` called for prototype beans?
- What happens if `@PostConstruct` throws an exception?

---

### Common Mistakes

- Placing `@PostConstruct` on a method with parameters — it will not be called.
- Expecting `@PreDestroy` to run in prototype-scoped beans — it does not.
- Doing expensive I/O in `@PostConstruct` that blocks application startup without a timeout.

---

### Interview Traps

- **Trap:** "`@PostConstruct` runs before `@Autowired` injects dependencies." — False. Injection happens first.

---

### Quick Revision Notes

- `@PostConstruct`: after injection, before `afterPropertiesSet` and init-method.
- `@PreDestroy`: before `destroy()` and destroy-method, only for singleton beans.
- Both are JSR-250, processed by `CommonAnnotationBeanPostProcessor`.
- Prefer over `InitializingBean`/`DisposableBean` to avoid Spring coupling.

---

## 9. Circular Dependencies

**Difficulty:** Hard | **Interview Frequency:** High

**Companies:** Amazon, Google, Adobe, Uber, Goldman Sachs

---

### Short Interview Answer (30–60 seconds)

Spring resolves singleton circular dependencies using a three-level cache: `singletonObjects` (fully initialized), `earlySingletonObjects` (partially initialized, exposed early), and `singletonFactories` (object factories that expose a raw reference before the bean is fully initialized). This works only for setter or field injection — constructor injection fails because the object does not exist yet when the constructor argument is needed. Spring Boot 2.6+ prohibits circular deps by default; they usually signal a design problem.

---

### Deep Explanation

**The three-level cache:**

```
singletonFactories     (level 3): ObjectFactory<T> that creates an early reference
earlySingletonObjects  (level 2): early reference moved here once first accessed
singletonObjects       (level 1): fully initialized beans
```

**Resolution flow for A → B and B → A (setter injection):**

```
1. Create A: starts instantiation, registers ObjectFactory in singletonFactories
2. Inject B into A: A needs B
3. Create B: starts instantiation, registers ObjectFactory in singletonFactories
4. Inject A into B: B needs A
5. A not in singletonObjects — check earlySingletonObjects — check singletonFactories
6. Found A's factory — create early A reference — put in earlySingletonObjects
7. B gets early A (partially initialized)
8. B finishes initialization — placed in singletonObjects
9. A gets fully initialized B — A finishes — placed in singletonObjects
```

**Why constructor injection cannot be resolved:**
At step 1, A's constructor needs B. But B is not yet in any cache (its creation has not started). Spring begins creating B, which needs A in its constructor, but A is also not yet in the cache (it failed before completing instantiation). Result: `BeanCurrentlyInCreationException`.

**Spring Boot 2.6+ default:**
Circular dependencies are prohibited by default. If they exist:
```
The dependencies of some of the beans in the application context form a cycle
```
Override with: `spring.main.allow-circular-references=true`

**Better solution: redesign.**
Circular deps usually mean a class has too many responsibilities. Extract a third class or introduce an event to break the cycle.

---

### Code Example

```java
// Circular dep via constructor — will throw BeanCurrentlyInCreationException
@Service
public class ServiceA {
    public ServiceA(ServiceB b) { }  // needs B
}
@Service
public class ServiceB {
    public ServiceB(ServiceA a) { }  // needs A — DEADLOCK
}

// Resolvable via setter injection (but indicates design smell)
@Service
public class ServiceA {
    private ServiceB serviceB;
    @Autowired
    public void setServiceB(ServiceB serviceB) { this.serviceB = serviceB; }
}

// Clean solution: extract a shared dependency
@Service
public class SharedService { ... }  // both A and B depend on this, not each other

// Or use an event to decouple
@Service
public class ServiceA implements ApplicationEventPublisherAware {
    private ApplicationEventPublisher publisher;
    public void doWork() { publisher.publishEvent(new WorkDoneEvent(this)); }
}
@Service
public class ServiceB {
    @EventListener
    public void onWorkDone(WorkDoneEvent event) { ... }
}
```

---

### Follow-Up Questions

- Can you resolve a constructor-injection circular dependency?
- What does `@Lazy` do when placed on an injection point involved in a cycle?
- What is `BeanCurrentlyInCreationException`?

---

### Common Mistakes

- Treating circular dependencies as a Spring problem to solve, rather than a design problem to fix.
- Adding `spring.main.allow-circular-references=true` in production without investigating root cause.

---

### Interview Traps

- **Trap:** "`@Lazy` fixes all circular deps." — `@Lazy` on one injection point delays initialization and can break the cycle, but it masks the design issue.

---

### Quick Revision Notes

- Three-level cache enables singleton circular dep resolution for setter/field injection only.
- Constructor circular deps always fail — use this as a design signal.
- Spring Boot 2.6+: circular deps prohibited by default.
- Fix by extracting shared state or decoupling via events.

---

## 10. AOP Fundamentals

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Goldman Sachs, Adobe, Salesforce, PayPal, Visa

---

### Short Interview Answer (30–60 seconds)

AOP lets you apply cross-cutting concerns — logging, security, transactions, caching — without scattering that logic through every class. The key terms are: Aspect (the module containing the concern), Advice (the code to run), Pointcut (the expression describing where to apply it), and Join Point (an execution point the advice targets). Spring uses JDK dynamic proxies when the bean implements an interface, and CGLIB when it does not. `@Around` is the most powerful advice — it controls whether the target method even runs.

---

### Deep Explanation

**Advice types:**

| Advice | Runs | Can prevent execution |
|---|---|---|
| `@Before` | Before the join point | No |
| `@After` | After, regardless of outcome | No |
| `@AfterReturning` | After successful return | No |
| `@AfterThrowing` | After exception thrown | No |
| `@Around` | Wraps join point | Yes (skip `proceed()`) |

**JDK Dynamic Proxy:**
Created by `java.lang.reflect.Proxy`. Works only when the target bean implements at least one interface. The proxy implements the same interfaces and intercepts method calls. Cannot proxy methods not declared in the interface.

**CGLIB Proxy:**
Creates a subclass of the target class at runtime (using ASM bytecode generation). Used when:
- The bean does not implement any interface, or
- `@EnableAspectJAutoProxy(proxyTargetClass = true)` / `spring.aop.proxy-target-class=true`.

**CGLIB limitations:**
- Cannot subclass `final` classes.
- Cannot override `final` methods.
- Requires a no-arg constructor (Spring 4+ uses `Objenesis` to bypass this, but it is version-dependent).

**Pointcut expression syntax (AspectJ):**
```
execution(modifiers? return-type declaring-type? method-name(params) throws?)
execution(public * com.example.service.*.*(..))   — all public methods in service package
within(com.example.service.*)                     — all methods in service package
@annotation(org.springframework.transaction.annotation.Transactional)
bean(orderService)                                — specific bean
```

---

### Code Example

```java
@Aspect
@Component
public class AuditAspect {

    private static final Logger log = LoggerFactory.getLogger(AuditAspect.class);

    // Around advice: log + measure every public service method
    @Around("execution(public * com.example.service..*(..))")
    public Object auditExecution(ProceedingJoinPoint pjp) throws Throwable {
        String method = pjp.getSignature().toShortString();
        long start = System.currentTimeMillis();
        try {
            Object result = pjp.proceed();  // invoke the real method
            long elapsed = System.currentTimeMillis() - start;
            log.info("[AUDIT] {} completed in {}ms", method, elapsed);
            return result;
        } catch (Exception ex) {
            log.error("[AUDIT] {} threw {}: {}", method, ex.getClass().getSimpleName(), ex.getMessage());
            throw ex;
        }
    }

    // Before advice: validate input not null
    @Before("execution(* com.example.service.OrderService.placeOrder(..)) && args(request)")
    public void validateRequest(OrderRequest request) {
        if (request == null) throw new IllegalArgumentException("OrderRequest must not be null");
    }

    // AfterReturning: publish event after successful payment
    @AfterReturning(pointcut = "execution(* com.example.service.PaymentService.charge(..))",
                    returning = "result")
    public void onPaymentSuccess(PaymentResult result) {
        log.info("Payment succeeded: txId={}", result.transactionId());
    }
}
```

---

### Follow-Up Questions

- Why can't Spring AOP proxy `final` methods?
- What is the difference between compile-time weaving (AspectJ) and load-time/proxy weaving (Spring AOP)?
- Can you apply two aspects to the same method? How is ordering determined (`@Order`)?

---

### Common Mistakes

- Expecting AOP to work on `private` methods — proxy cannot intercept them.
- Not enabling `@EnableAspectJAutoProxy` when using `@Aspect` in non-Boot context.
- Forgetting that `@Around` must call `pjp.proceed()` or the target method never runs.

---

### Interview Traps

- **Trap:** "Spring AOP can proxy any method." — Only `public` (and `protected` for CGLIB-subclassed classes) methods on Spring beans. Private and `final` methods are not interceptable.

---

### Quick Revision Notes

- JDK proxy: requires interface; CGLIB: subclasses target class, cannot handle `final`.
- `@Around` is the most powerful advice; must call `proceed()` to run the real method.
- Pointcut syntax: `execution()`, `within()`, `@annotation()`, `bean()`.
- `@EnableAspectJAutoProxy` activates Spring AOP (auto-applied in Spring Boot).

---

## 11. @Transactional Internals

**Difficulty:** Hard | **Interview Frequency:** Very High

**Companies:** Amazon, Goldman Sachs, JPMorgan, Adobe, Uber, Stripe, Visa

---

### Short Interview Answer (30–60 seconds)

`@Transactional` is implemented through AOP. Spring wraps the bean in a proxy. When a transactional method is called from outside the bean, the proxy intercepts the call, opens a transaction via `PlatformTransactionManager`, invokes the real method, and either commits or rolls back. Two critical pitfalls: `@Transactional` on a `private` method is silently ignored because the proxy cannot override it. Self-invocation — calling a transactional method from within the same class using `this` — bypasses the proxy, so no transaction is created.

---

### Deep Explanation

**Proxy interception flow:**
```
Caller → Proxy.methodA() → open transaction
           → real bean.methodA()
              → does work
           ← return/exception
        → commit (or rollback)
← return to Caller
```

**Why private methods fail:**
A proxy (JDK or CGLIB) can only override methods that are visible to the subclass/proxy. `private` is not overridable — the annotation is present at compile time but the proxy never generates code to intercept it.

**Self-invocation problem:**
```java
@Service
public class OrderService {
    public void processOrder(Order o) {
        this.saveOrder(o);   // 'this' is the real bean, not the proxy — no transaction!
    }

    @Transactional
    public void saveOrder(Order o) { ... }
}
```
`this.saveOrder(o)` calls the real `saveOrder` directly — no proxy interception.

**Solutions to self-invocation:**
1. Inject `OrderService` into itself: `@Autowired private OrderService self;` then `self.saveOrder(o)`.
2. Use `AopContext.currentProxy()`: `((OrderService) AopContext.currentProxy()).saveOrder(o)` — requires `exposeProxy=true`.
3. Refactor: move `saveOrder` to a different service class.

**Rollback rules:**
By default, Spring rolls back on unchecked exceptions (`RuntimeException` and `Error`). Checked exceptions do NOT trigger rollback unless specified: `@Transactional(rollbackFor = IOException.class)`.

**Propagation modes (most common):**

| Mode | Behavior |
|---|---|
| `REQUIRED` (default) | Join existing transaction; create new if none |
| `REQUIRES_NEW` | Always create new transaction; suspend current |
| `NESTED` | Create a savepoint within the existing transaction |
| `SUPPORTS` | Use existing if available; run without if not |
| `NOT_SUPPORTED` | Always run without a transaction; suspend current |
| `MANDATORY` | Must have existing transaction; throw if none |
| `NEVER` | Must NOT have a transaction; throw if one exists |

---

### Code Example

```java
@Service
public class PaymentService {

    private final PaymentRepository paymentRepo;
    private final AuditLogRepository auditRepo;

    public PaymentService(PaymentRepository paymentRepo, AuditLogRepository auditRepo) {
        this.paymentRepo = paymentRepo;
        this.auditRepo = auditRepo;
    }

    // Correct: public method, called from outside — proxy intercepts
    @Transactional(rollbackFor = PaymentException.class)
    public PaymentResult processPayment(PaymentRequest request) {
        Payment payment = paymentRepo.save(new Payment(request));
        auditRepo.save(new AuditLog("PAYMENT", payment.id()));
        return new PaymentResult(payment.id(), "SUCCESS");
    }

    // REQUIRES_NEW: audit must persist even if outer transaction rolls back
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void logFailure(String reason) {
        auditRepo.save(new AuditLog("PAYMENT_FAILURE", reason));
    }

    // WRONG: private — @Transactional silently ignored
    @Transactional
    private void internalSave(Payment p) { paymentRepo.save(p); }

    // Self-invocation fix: inject self
    @Autowired
    private PaymentService self;

    public void batchProcess(List<PaymentRequest> requests) {
        requests.forEach(r -> self.processPayment(r));  // proxy intercepts each call
    }
}
```

---

### Follow-Up Questions

- What happens if you annotate `@Transactional` on an interface method vs a class method?
- Explain `REQUIRES_NEW` vs `NESTED` propagation.
- Why doesn't `@Transactional` roll back on a checked exception by default?

---

### Common Mistakes

- Placing `@Transactional` on `private` methods and expecting it to work.
- Using `@Transactional` on a `@Repository` and then also on the calling `@Service` — nested transactions with default `REQUIRED` propagation just join; it is fine but redundant.
- Expecting all exceptions to trigger rollback — only `RuntimeException` and `Error` do by default.

---

### Interview Traps

- **Trap:** "Annotating an interface with `@Transactional` works the same as annotating the implementation." — With JDK proxies it works; with CGLIB (`proxyTargetClass=true`) it may not detect the annotation on the interface.
- **Trap:** "Self-calling a transactional method is a Spring bug." — It is a deliberate proxy-based design consequence.

---

### Quick Revision Notes

- `@Transactional` = AOP proxy that wraps the method in a transaction.
- Private methods: proxy cannot override — annotation silently ignored.
- Self-invocation (`this.method()`): bypasses proxy — no transaction.
- Default rollback: unchecked exceptions only. Use `rollbackFor` for checked.
- `REQUIRES_NEW`: always a fresh transaction; `NESTED`: savepoint within existing.

---

## 12. Common AOP Use Cases in Production

**Difficulty:** Medium | **Interview Frequency:** Medium

**Companies:** Amazon, Adobe, Salesforce, Atlassian, Stripe

---

### Short Interview Answer (30–60 seconds)

Spring AOP powers many Spring framework features: `@Cacheable`/`@CacheEvict` (caching), `@Retryable` (retry with backoff), `@PreAuthorize` (method-level security), `@Async` (async execution). In custom code, common uses include execution time logging, distributed tracing injection (e.g., propagating correlation IDs), rate limiting, and circuit breaker integration. These are all implemented as aspects that wrap method calls without modifying business logic.

---

### Deep Explanation

**`@Cacheable` / `@CacheEvict`:**
Backed by `CacheInterceptor` (a `MethodInterceptor`). On `@Cacheable`, before invoking the target method, the interceptor checks the cache. On a hit, it returns the cached value without calling the method. On a miss, it calls the method and caches the result. `@CacheEvict` removes entries. Configured via `CacheManager` (Redis, Caffeine, etc.).

**`@Retryable` (Spring Retry):**
`RetryOperationsInterceptor` wraps the method. On exception, it retries up to `maxAttempts` times with configurable backoff (`@Backoff`). Works with any `RetryPolicy`. Requires `@EnableRetry`.

**`@PreAuthorize` / `@PostAuthorize`:**
`MethodSecurityInterceptor` evaluates a SpEL expression before/after the method. If the expression returns false, `AccessDeniedException` is thrown. Requires `@EnableMethodSecurity` (Spring Security 6.x).

**`@Async`:**
`AsyncAnnotationAdvisor` intercepts `@Async` methods and submits them to an `Executor` (thread pool). The calling thread returns immediately; the method runs asynchronously. Return type should be `void` or `CompletableFuture<T>`.

---

### Code Example

```java
// Caching with Redis
@Service
public class ProductCatalogService {

    @Cacheable(value = "products", key = "#productId",
               condition = "#productId != null",
               unless = "#result == null")
    public Product getProduct(String productId) {
        return productRepository.findById(productId).orElseThrow();
    }

    @CacheEvict(value = "products", key = "#product.id")
    public Product updateProduct(Product product) {
        return productRepository.save(product);
    }
}

// Retry with exponential backoff
@Service
public class ExternalApiClient {

    @Retryable(
        retryFor = {RestClientException.class, TimeoutException.class},
        maxAttempts = 3,
        backoff = @Backoff(delay = 500, multiplier = 2)  // 500ms, 1000ms, 2000ms
    )
    public ExchangeRate fetchRate(String pair) {
        return restClient.get()
            .uri("/rates/{pair}", pair)
            .retrieve()
            .body(ExchangeRate.class);
    }

    @Recover
    public ExchangeRate fallback(RestClientException ex, String pair) {
        log.warn("Rate fetch failed for {}, using default", pair);
        return ExchangeRate.defaultRate(pair);
    }
}

// Method security
@Service
public class AccountService {

    @PreAuthorize("hasRole('ADMIN') or #accountId == authentication.name")
    public AccountDetails getAccount(String accountId) { ... }

    @PostAuthorize("returnObject.ownerId == authentication.name")
    public Transaction getTransaction(String txId) { ... }
}

// Async method
@Service
public class EmailService {

    @Async("emailThreadPool")
    public CompletableFuture<Void> sendWelcomeEmail(String email) {
        // runs on emailThreadPool, not the caller's thread
        emailClient.send(email, "Welcome!");
        return CompletableFuture.completedFuture(null);
    }
}
```

---

### Follow-Up Questions

- How does `@Cacheable` determine the cache key when multiple parameters exist?
- What happens if `@Async` is called from within the same class?
- Can `@Retryable` and `@Transactional` be combined on the same method? What is the advice ordering concern?

---

### Common Mistakes

- Using `@Async` for self-invocation — it has the same proxy bypass issue as `@Transactional`.
- Forgetting `@EnableCaching`, `@EnableRetry`, `@EnableMethodSecurity`, `@EnableAsync` — the feature annotations are no-ops without these.
- Not specifying `rollbackFor` when combining `@Retryable` with `@Transactional` — checked exceptions may not roll back.

---

### Quick Revision Notes

- `@Cacheable`: cache hit skips method; `@CacheEvict`: removes cache entry — backed by `CacheInterceptor`.
- `@Retryable`: retries on exception with configurable backoff; requires `@EnableRetry`.
- `@PreAuthorize`: SpEL-based method security; requires `@EnableMethodSecurity`.
- `@Async`: async execution via `Executor`; requires `@EnableAsync`; same proxy caveat as `@Transactional`.

---

## 13. Spring Boot Auto-Configuration Internals

**Difficulty:** Hard | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Adobe, Salesforce, Goldman Sachs, Stripe

---

### Short Interview Answer (30–60 seconds)

Spring Boot auto-configuration uses `@EnableAutoConfiguration`, which triggers a `SpringFactoriesLoader` to read a list of candidate auto-configuration classes from `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` (Boot 3). Each class carries conditional annotations — `@ConditionalOnClass`, `@ConditionalOnMissingBean`, `@ConditionalOnProperty` — that guard whether the beans inside are actually created. Only conditions that pass lead to bean creation. Run with `--debug` to see the `ConditionEvaluationReport`.

---

### Deep Explanation

**Boot 2 vs Boot 3 location change:**
- Boot 2: `META-INF/spring.factories` under key `org.springframework.boot.autoconfigure.EnableAutoConfiguration`.
- Boot 3: `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` (one class per line).

**`ImportCandidates` and the loading flow:**
1. `@EnableAutoConfiguration` is a meta-annotation on `@SpringBootApplication`.
2. `AutoConfigurationImportSelector.selectImports()` calls `ImportCandidates.load()` to read all candidate auto-configuration class names.
3. Candidates are filtered by exclusions (`exclude` attribute) and the `AutoConfigurationImportFilter`.
4. Filtered candidates are imported into the `ApplicationContext` as `@Configuration` classes.
5. Each candidate's `@Conditional...` annotations are evaluated at bean-definition processing time. If conditions do not pass, the entire class (and its `@Bean` methods) are skipped.

**Key conditional annotations:**

| Annotation | Condition |
|---|---|
| `@ConditionalOnClass` | Bean created only if listed class is on classpath |
| `@ConditionalOnMissingClass` | Bean created only if class is NOT on classpath |
| `@ConditionalOnBean` | Bean created only if listed bean exists in context |
| `@ConditionalOnMissingBean` | Bean created only if NO bean of that type exists |
| `@ConditionalOnProperty` | Bean created only if property is set (and optionally has value) |
| `@ConditionalOnExpression` | Bean created only if SpEL evaluates to true |
| `@ConditionalOnWebApplication` | Bean created only in web app context |
| `@ConditionalOnResource` | Bean created only if a classpath resource exists |

**`@ConditionalOnMissingBean` pattern:**
The canonical auto-config pattern — provide a default bean, but back off if the user has already defined their own:
```java
@Bean
@ConditionalOnMissingBean
public DataSource dataSource() { return ... }
```

**Debugging:**
Run with `--debug` flag or set `logging.level.org.springframework.boot.autoconfigure=DEBUG`. The `ConditionEvaluationReport` shows which auto-configs were matched (positive matches) and which were not (negative matches, with reason).

---

### Code Example

```java
// Writing a custom auto-configuration (library author perspective)
@AutoConfiguration                      // Boot 3 meta-annotation
@ConditionalOnClass(AuditService.class) // only if our library is on classpath
@EnableConfigurationProperties(AuditProperties.class)
public class AuditAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean           // back off if user defines their own
    public AuditService auditService(AuditProperties props) {
        return new DefaultAuditService(props.getStorageType());
    }

    @Bean
    @ConditionalOnProperty(prefix = "audit", name = "async.enabled", havingValue = "true")
    public AsyncAuditService asyncAuditService(AuditService delegate) {
        return new AsyncAuditService(delegate);
    }
}

// META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
// com.example.audit.AuditAutoConfiguration
```

```java
// Debugging in your application
// Run: java -jar myapp.jar --debug
// Or in application.properties:
// debug=true
// Output includes ConditionEvaluationReport:
//   Positive matches:
//     DataSourceAutoConfiguration matched
//      - @ConditionalOnClass found required class 'javax.sql.DataSource' (OnClassCondition)
//   Negative matches:
//     MongoAutoConfiguration:
//      - @ConditionalOnClass did not find required class 'com.mongodb.client.MongoClient'
```

---

### Follow-Up Questions

- How do you exclude a specific auto-configuration class?
- What is the difference between `@ConditionalOnBean` and `@ConditionalOnMissingBean`?
- How does Spring Boot know in which order to apply auto-configurations (`@AutoConfigureBefore`, `@AutoConfigureAfter`, `@AutoConfigureOrder`)?

---

### Common Mistakes

- Modifying `spring.factories` in a Spring Boot 3 project — Boot 3 uses `AutoConfiguration.imports`.
- Placing application beans in a package outside the `@SpringBootApplication` base package and wondering why auto-config does not pick them up (component scan vs auto-config are different mechanisms).

---

### Interview Traps

- **Trap:** "Auto-configuration creates all the beans listed." — No. Conditionals filter most of them out. Only conditionally matched beans are created.

---

### Quick Revision Notes

- Auto-config class list loaded from `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` (Boot 3).
- Each class guarded by `@Conditional...` annotations — most will not activate in any given app.
- `@ConditionalOnMissingBean`: the "back-off" pattern — your beans override auto-config defaults.
- Debug with `--debug` flag → `ConditionEvaluationReport`.

---

## 14. @SpringBootApplication

**Difficulty:** Easy | **Interview Frequency:** Very High

**Companies:** Amazon, Atlassian, Adobe, Salesforce, Visa

---

### Short Interview Answer (30–60 seconds)

`@SpringBootApplication` is a composed annotation that combines three annotations: `@Configuration` (this class can define `@Bean` methods), `@EnableAutoConfiguration` (activate auto-configuration), and `@ComponentScan` (scan for components starting from the annotated class's package). You can exclude auto-configurations directly on this annotation.

---

### Deep Explanation

**Composed annotation breakdown:**

```java
@SpringBootApplication
// equivalent to:
@Configuration
@EnableAutoConfiguration
@ComponentScan(basePackages = "com.example")
```

**`@ComponentScan` default behavior:**
Scans the package of the annotated class and all sub-packages. This is why the `@SpringBootApplication` class is conventionally placed in the root package of the project — it ensures all application classes are found.

**Excluding auto-configurations:**
```java
@SpringBootApplication(exclude = {
    DataSourceAutoConfiguration.class,  // disable embedded DB setup
    SecurityAutoConfiguration.class     // disable default Spring Security config
})
```

Or via properties: `spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration`

**Scanning customization:**
```java
@SpringBootApplication(scanBasePackages = {"com.example.api", "com.example.domain"})
// or
@SpringBootApplication(scanBasePackageClasses = {ApiMarker.class, DomainMarker.class})
```

---

### Code Example

```java
@SpringBootApplication(
    exclude = {DataSourceAutoConfiguration.class},  // no DB for this microservice
    scanBasePackages = "com.example"
)
public class OrderServiceApplication {

    public static void main(String[] args) {
        SpringApplication app = new SpringApplication(OrderServiceApplication.class);
        app.setDefaultProperties(Map.of("server.port", "8080"));
        app.run(args);
    }
}
```

---

### Follow-Up Questions

- What happens if you put `@SpringBootApplication` in a sub-package instead of the root?
- Can you have multiple `@SpringBootApplication` classes in one project?
- What is the difference between `exclude` on `@SpringBootApplication` and setting `spring.autoconfigure.exclude`?

---

### Common Mistakes

- Placing `@SpringBootApplication` in a sub-package — classes in sibling packages are not scanned.
- Excluding auto-configurations at class level when it should be environment-specific (use properties instead for environment-specific exclusions).

---

### Quick Revision Notes

- `@SpringBootApplication` = `@Configuration` + `@EnableAutoConfiguration` + `@ComponentScan`.
- Place in the root package so all sub-packages are scanned.
- Use `exclude` attribute or `spring.autoconfigure.exclude` property to disable specific auto-configs.

---

## 15. application.properties vs application.yml

**Difficulty:** Easy | **Interview Frequency:** High

**Companies:** Amazon, Adobe, Salesforce, Goldman Sachs, Atlassian

---

### Short Interview Answer (30–60 seconds)

Both file formats configure Spring Boot applications and are functionally equivalent. `application.yml` is more readable for hierarchical configuration. For injecting a single value, use `@Value("${property.name}")` with an optional default: `@Value("${timeout:30}")`. For a group of related properties, prefer `@ConfigurationProperties(prefix="app")` — it gives type-safe binding with IDE support, validation, and no scattered `@Value` annotations.

---

### Deep Explanation

**`@Value` internals:**
Processed by `AutowiredAnnotationBeanPostProcessor` using `EmbeddedValueResolverAware`. The `${...}` syntax reads from `Environment` (which aggregates all `PropertySource` objects). SpEL `#{...}` expressions are also supported.

**`@ConfigurationProperties`:**
- Binds all properties under a given prefix to a Java record or class.
- Supports nested objects, lists, maps.
- Enables JSR-303 validation with `@Validated` + `@NotNull`, `@Min`, etc.
- Requires `@EnableConfigurationProperties(AppProperties.class)` or `@ConfigurationPropertiesScan`.
- Spring Boot 3 generates metadata (`spring-configuration-metadata.json`) for IDE auto-completion when `spring-boot-configuration-processor` is on the classpath.

**Property source precedence (highest to lowest):**
1. Command-line arguments (`--server.port=9090`)
2. `SPRING_APPLICATION_JSON` environment variable
3. `application-{profile}.properties/yml`
4. `application.properties/yml`
5. `@PropertySource` annotations
6. Default properties

---

### Code Example

```yaml
# application.yml
app:
  payment:
    gateway: stripe
    timeout-seconds: 30
    retry:
      max-attempts: 3
      backoff-ms: 500
  feature-flags:
    new-checkout: true
```

```java
// Type-safe binding with a record (Java 16+)
@ConfigurationProperties(prefix = "app.payment")
@Validated
public record PaymentProperties(
    @NotBlank String gateway,
    @Min(5) @Max(120) int timeoutSeconds,
    RetryConfig retry
) {
    public record RetryConfig(
        @Min(1) int maxAttempts,
        @Min(100) long backoffMs
    ) {}
}

// Enable in Boot 3
@SpringBootApplication
@ConfigurationPropertiesScan  // auto-discovers all @ConfigurationProperties
public class PaymentApp { ... }

// Inject and use
@Service
public class PaymentGatewayClient {

    private final PaymentProperties props;

    public PaymentGatewayClient(PaymentProperties props) {
        this.props = props;
    }

    public PaymentResult charge(Money amount) {
        // use props.gateway(), props.timeoutSeconds(), props.retry()
    }
}

// @Value for simple cases
@Service
public class FeatureFlagService {

    @Value("${app.feature-flags.new-checkout:false}")
    private boolean newCheckoutEnabled;

    @Value("#{${app.payment.timeout-seconds} * 1000}")  // SpEL arithmetic
    private long timeoutMs;
}
```

---

### Follow-Up Questions

- What is `@ConfigurationPropertiesScan`?
- How do you validate configuration properties at startup?
- What happens if a required `@ConfigurationProperties` field is missing?

---

### Common Mistakes

- Using dozens of `@Value` annotations instead of one `@ConfigurationProperties` class.
- Forgetting `@Validated` on the `@ConfigurationProperties` class — JSR-303 annotations are ignored without it.
- Not adding `spring-boot-configuration-processor` to get IDE auto-completion.

---

### Quick Revision Notes

- `@Value("${x:default}")`: single value with optional default.
- `@ConfigurationProperties(prefix="x")`: type-safe grouped binding, supports validation.
- Use `@ConfigurationPropertiesScan` or `@EnableConfigurationProperties` to activate.
- Property source priority: CLI args > profile-specific > application.properties > defaults.

---

## 16. Spring Profiles

**Difficulty:** Easy | **Interview Frequency:** High

**Companies:** Amazon, Adobe, Salesforce, Goldman Sachs, Atlassian, Stripe

---

### Short Interview Answer (30–60 seconds)

Spring Profiles let you segregate application configuration and beans by environment. `@Profile("prod")` on a bean or `@Configuration` class means it is only registered when the `prod` profile is active. Profile-specific property files (`application-prod.yml`) override the base `application.yml`. Activate profiles with `spring.profiles.active=prod` (property, env var, or CLI arg). In tests, use `@ActiveProfiles("test")`.

---

### Deep Explanation

**Activation mechanisms (in priority order for Spring Boot):**
1. `SpringApplication.setAdditionalProfiles()`
2. `SPRING_PROFILES_ACTIVE` environment variable
3. `spring.profiles.active` in `application.properties`
4. `--spring.profiles.active=prod` command-line argument

**Profile-specific files:**
`application-{profile}.yml` (or `.properties`) is loaded in addition to `application.yml`. Properties in the profile-specific file override the base file. Multiple profiles can be active simultaneously.

**Bean-level profiles:**
```java
@Service
@Profile("prod")
public class AwsS3StorageService implements StorageService { ... }

@Service
@Profile({"dev", "test"})
public class LocalFileStorageService implements StorageService { ... }
```

**Profile groups (Boot 2.4+):**
```yaml
spring.profiles.group.production=prod,monitoring,security
```
Activating `production` activates all three.

**`@Profile` with NOT operator:**
```java
@Profile("!prod")  // active in all profiles EXCEPT prod
public class MockPaymentGateway implements PaymentGateway { ... }
```

---

### Code Example

```yaml
# application.yml (base — shared across all envs)
app:
  name: order-service
  api-version: v2

---
# application-dev.yml
spring:
  datasource:
    url: jdbc:h2:mem:devdb
app:
  payment.gateway: mock

---
# application-prod.yml
spring:
  datasource:
    url: jdbc:postgresql://prod-db:5432/orders
    hikari:
      maximum-pool-size: 20
app:
  payment.gateway: stripe
```

```java
// Profile-specific beans
@Configuration
public class StorageConfig {

    @Bean
    @Profile("prod")
    public StorageService awsS3StorageService(AmazonS3 s3) {
        return new AwsS3StorageService(s3);
    }

    @Bean
    @Profile("!prod")  // dev and test
    public StorageService localStorageService(@Value("${storage.local.path}") String path) {
        return new LocalStorageService(path);
    }
}

// Test using profile
@SpringBootTest
@ActiveProfiles("test")
class OrderServiceIntegrationTest {
    // picks up application-test.yml and test-profile beans
}
```

---

### Follow-Up Questions

- What is the difference between `@Profile` and `@ConditionalOnProperty`?
- How do you activate multiple profiles simultaneously?
- What are Spring Profile groups?

---

### Common Mistakes

- Using `@Profile` when `@ConditionalOnProperty` is more appropriate — profiles are for environment (dev/test/prod), properties are for feature toggles.
- Not setting `spring.profiles.active` in CI/CD pipelines, causing test profile beans to bleed into staging.

---

### Quick Revision Notes

- `@Profile("prod")`: bean registered only when `prod` profile is active.
- `application-{profile}.yml` overrides `application.yml`.
- `@Profile("!prod")`: active in all environments except prod.
- `@ActiveProfiles` in tests; `SPRING_PROFILES_ACTIVE` env var for containers.
- Profile groups (Boot 2.4+): activate multiple profiles with one name.

---

## 17. Spring Boot Actuator

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Goldman Sachs, Adobe, Salesforce, JPMorgan, Uber

---

### Short Interview Answer (30–60 seconds)

Spring Boot Actuator exposes production-ready endpoints for health checks, metrics, configuration inspection, and thread dumps. Key endpoints: `/actuator/health` (used by load balancers and Kubernetes liveness/readiness probes), `/actuator/metrics` (Micrometer-backed), `/actuator/env`, `/actuator/beans`. By default most endpoints are exposed only over JMX — you must explicitly expose them over HTTP. In production they must be secured with Spring Security.

---

### Deep Explanation

**Endpoint exposure configuration:**
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
        # avoid exposing: env,beans,heapdump,threaddump in production
  endpoint:
    health:
      show-details: when-authorized  # never expose details publicly
  server:
    port: 8081  # separate management port — do not expose to internet
```

**Health indicators:**
Spring Boot auto-configures `HealthIndicator` beans for DataSource, Redis, RabbitMQ, Kafka, etc. You can add a custom one:
```java
@Component
public class PaymentGatewayHealthIndicator implements HealthIndicator {
    @Override
    public Health health() {
        boolean up = paymentGatewayClient.ping();
        return up ? Health.up().withDetail("gateway", "stripe").build()
                  : Health.down().withDetail("reason", "timeout").build();
    }
}
```

**Micrometer metrics:**
Actuator integrates with Micrometer, which provides a vendor-neutral API for metrics. Backends: Prometheus, Datadog, CloudWatch, InfluxDB. Common metric types:
- `Counter`: monotonically increasing count (e.g., HTTP requests)
- `Timer`: duration measurements (e.g., service call latency)
- `Gauge`: current value (e.g., queue depth, active connections)

**Liveness vs Readiness (Boot 2.3+):**
```yaml
management.endpoint.health.group.liveness.include: livenessState
management.endpoint.health.group.readiness.include: readinessState,db,redis
```
- `/actuator/health/liveness`: Is the app alive? (Kubernetes liveness probe)
- `/actuator/health/readiness`: Is the app ready for traffic? (Kubernetes readiness probe)

---

### Code Example

```java
// Custom health indicator
@Component
public class ExternalPaymentHealthIndicator implements HealthIndicator {

    private final PaymentGatewayClient client;

    public ExternalPaymentHealthIndicator(PaymentGatewayClient client) {
        this.client = client;
    }

    @Override
    public Health health() {
        try {
            PingResponse response = client.ping();
            return Health.up()
                .withDetail("gateway", response.provider())
                .withDetail("responseTimeMs", response.latencyMs())
                .build();
        } catch (Exception ex) {
            return Health.down()
                .withDetail("reason", ex.getMessage())
                .build();
        }
    }
}

// Custom metrics with Micrometer
@Service
public class OrderService {

    private final Counter orderCounter;
    private final Timer orderTimer;

    public OrderService(MeterRegistry registry) {
        this.orderCounter = Counter.builder("orders.created")
            .description("Total orders created")
            .tag("region", "us-east-1")
            .register(registry);
        this.orderTimer = Timer.builder("orders.processing.time")
            .description("Time to process an order")
            .register(registry);
    }

    public Order createOrder(OrderRequest request) {
        return orderTimer.record(() -> {
            Order order = processOrder(request);
            orderCounter.increment();
            return order;
        });
    }
}

// Secure actuator endpoints
@Configuration
public class ActuatorSecurityConfig {

    @Bean
    @Order(1)
    public SecurityFilterChain actuatorSecurity(HttpSecurity http) throws Exception {
        return http
            .securityMatcher("/actuator/**")
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health/**").permitAll()
                .requestMatchers("/actuator/**").hasRole("ACTUATOR_ADMIN")
            )
            .httpBasic(withDefaults())
            .build();
    }
}
```

---

### Follow-Up Questions

- How does Actuator integrate with Kubernetes liveness and readiness probes?
- What is the difference between `@Endpoint`, `@WebEndpoint`, and `@JmxEndpoint`?
- How do you create a custom Actuator endpoint?

---

### Common Mistakes

- Exposing `/actuator/env` or `/actuator/heapdump` over HTTP in production — massive security risk.
- Not setting `management.server.port` in production — management endpoints on the same port as API traffic.
- Using `/actuator/health` (which shows all component health) as a Kubernetes readiness probe — prefer grouped probes.

---

### Quick Revision Notes

- Key endpoints: `health`, `info`, `metrics`, `env`, `beans`, `loggers`, `threaddump`.
- Expose via `management.endpoints.web.exposure.include`.
- Use `management.server.port` to isolate management traffic.
- Micrometer: `Counter`, `Timer`, `Gauge` — backend-agnostic metric types.
- Boot 2.3+: liveness/readiness probes for Kubernetes.

---

## 18. Spring Boot Startup Sequence

**Difficulty:** Medium | **Interview Frequency:** Medium

**Companies:** Amazon, Adobe, Salesforce, Google

---

### Short Interview Answer (30–60 seconds)

`SpringApplication.run()` creates the appropriate `ApplicationContext` type, loads all configuration, performs component scanning, instantiates and wires all singleton beans, runs `ApplicationRunner` and `CommandLineRunner` callbacks, then signals readiness. Key lifecycle events are published at each stage: `ApplicationStartingEvent`, `ApplicationEnvironmentPreparedEvent`, `ApplicationContextInitializedEvent`, `ApplicationPreparedEvent`, `ApplicationStartedEvent`, and `ApplicationReadyEvent`. `ApplicationRunner` receives structured `ApplicationArguments`; `CommandLineRunner` receives raw `String[]`.

---

### Deep Explanation

**Detailed sequence:**
```
SpringApplication.run(args)
  1. ApplicationStartingEvent published
  2. Prepare environment (load properties, profiles)
  3. ApplicationEnvironmentPreparedEvent published
  4. Create ApplicationContext (AnnotationConfigServletWebServerApplicationContext for MVC)
  5. ApplicationContextInitializedEvent published
  6. Load bean definitions (component scan, @Bean methods, auto-config)
  7. ApplicationPreparedEvent published
  8. Refresh context:
       a. Invoke BeanFactoryPostProcessors
       b. Register BeanPostProcessors
       c. Instantiate all singleton beans
       d. Finalize context (start embedded server)
  9. ApplicationStartedEvent published
  10. Run ApplicationRunner and CommandLineRunner beans (in @Order)
  11. ApplicationReadyEvent published
  → Application is serving traffic
```

**ApplicationRunner vs CommandLineRunner:**

| Feature | `ApplicationRunner` | `CommandLineRunner` |
|---|---|---|
| Argument type | `ApplicationArguments` | `String[]` |
| Access named args | Yes (`getOptionValues("profile")`) | No (raw strings) |
| Order | `@Order(1)` annotation | `@Order(1)` annotation |
| Use case | Structured arg processing | Simple startup logic |

**Common uses:**
- `CommandLineRunner`: data migrations, cache warm-up, database seed for dev.
- `ApplicationRunner`: startup validation, registering with service discovery.

---

### Code Example

```java
// ApplicationRunner — structured arg access
@Component
@Order(1)
public class DatabaseMigrationRunner implements ApplicationRunner {

    private final FlywayMigrationService migrationService;

    public DatabaseMigrationRunner(FlywayMigrationService migrationService) {
        this.migrationService = migrationService;
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        boolean dryRun = args.containsOption("dry-run");
        String target = args.getOptionValues("migrate-to")
            .stream().findFirst().orElse("latest");
        migrationService.migrate(target, dryRun);
        log.info("Migration complete to version: {}", target);
    }
}

// CommandLineRunner — simple startup task
@Component
@Order(2)
public class CacheWarmupRunner implements CommandLineRunner {

    private final ProductCacheService cacheService;

    public CacheWarmupRunner(ProductCacheService cacheService) {
        this.cacheService = cacheService;
    }

    @Override
    public void run(String... args) throws Exception {
        cacheService.warmFeaturedProducts();
        log.info("Product cache warmed up");
    }
}

// Listening to application lifecycle events
@Component
public class StartupEventListener implements ApplicationListener<ApplicationReadyEvent> {

    @Override
    public void onApplicationEvent(ApplicationReadyEvent event) {
        long uptimeMs = event.getTimeTaken().toMillis();
        log.info("Application ready in {}ms", uptimeMs);
        // register with service discovery, etc.
    }
}
```

---

### Follow-Up Questions

- What is the difference between `ApplicationStartedEvent` and `ApplicationReadyEvent`?
- Can `CommandLineRunner` beans cause application startup to fail?
- How would you run some logic after the embedded Tomcat is started but before accepting traffic?

---

### Common Mistakes

- Doing heavy synchronous work in `CommandLineRunner` that times out the startup health check.
- Expecting `ApplicationRunner` to run before the web server starts — it runs after context refresh, when the server is already up.

---

### Quick Revision Notes

- Event order: Starting → EnvironmentPrepared → ContextInitialized → Prepared → Started → (Runners) → Ready.
- `ApplicationReadyEvent`: app fully ready for traffic.
- `ApplicationRunner`: structured args; `CommandLineRunner`: raw `String[]`.
- Multiple runners ordered with `@Order`.

---

## 19. @Configuration vs @Component for @Bean Methods

**Difficulty:** Hard | **Interview Frequency:** High

**Companies:** Amazon, Google, Goldman Sachs, Adobe

---

### Short Interview Answer (30–60 seconds)

`@Configuration` classes are CGLIB-proxied. When a `@Bean` method inside a `@Configuration` class calls another `@Bean` method, the CGLIB proxy intercepts the call and returns the existing singleton bean from the container — so you get the same instance every time. In a `@Component` class (lite mode), there is no CGLIB proxy — calling a `@Bean` method directly creates a new Java object. This is a subtle but critical difference for bean wiring correctness.

---

### Deep Explanation

**Full (`@Configuration`) mode:**
The class is subclassed by CGLIB. Every `@Bean` method call goes through the CGLIB proxy, which checks `singletonObjects` and returns the existing bean if already created. This ensures singleton semantics even when `@Bean` methods reference each other.

**Lite (`@Component` / `@Bean` without `@Configuration`) mode:**
No CGLIB proxy. `@Bean` methods are plain Java methods. Calling one `@Bean` method from another simply calls the Java method, which instantiates a new object. The two `@Bean` method results are different objects.

**Why this matters — the classic trap:**
```java
@Configuration
public class AppConfig {
    @Bean
    public DataSource dataSource() { return new HikariDataSource(...); }

    @Bean
    public JdbcTemplate jdbcTemplate() {
        return new JdbcTemplate(dataSource());  // CGLIB proxy returns singleton DataSource
    }

    @Bean
    public TransactionManager txManager() {
        return new DataSourceTransactionManager(dataSource());  // SAME DataSource instance
    }
}
```
Both `jdbcTemplate` and `txManager` share the same `DataSource` because CGLIB intercepts `dataSource()` calls and returns the singleton. In `@Component` mode, two different `HikariDataSource` instances would be created — a connection pool leak.

**Detecting lite mode:**
If you write `@Bean` methods in a class annotated only with `@Component`, `@Service`, or similar, you are in lite mode.

---

### Code Example

```java
// FULL configuration (CGLIB-proxied) — safe cross-@Bean references
@Configuration
public class DataConfig {

    @Bean
    public DataSource dataSource() {
        HikariDataSource ds = new HikariDataSource();
        ds.setJdbcUrl("jdbc:postgresql://localhost:5432/mydb");
        ds.setMaximumPoolSize(10);
        return ds;
    }

    @Bean
    public JdbcTemplate jdbcTemplate() {
        return new JdbcTemplate(dataSource());  // proxy returns the singleton
    }

    @Bean
    public JdbcTransactionManager transactionManager() {
        return new JdbcTransactionManager(dataSource());  // same singleton
    }
}

// LITE configuration — cross-@Bean call creates a new instance!
@Component  // NOT @Configuration
public class LiteConfig {

    @Bean
    public DataSource dataSource() {
        return new HikariDataSource(...);  // new instance every time this method is called
    }

    @Bean
    public JdbcTemplate jdbcTemplate() {
        return new JdbcTemplate(dataSource());  // DIFFERENT DataSource — connection pool leak!
    }
}

// Safe lite-mode alternative: inject via parameters
@Component
public class SafeLiteConfig {

    @Bean
    public JdbcTemplate jdbcTemplate(DataSource dataSource) {  // Spring injects the singleton
        return new JdbcTemplate(dataSource);
    }

    @Bean
    public JdbcTransactionManager txManager(DataSource dataSource) {  // same singleton
        return new JdbcTransactionManager(dataSource);
    }
}
```

---

### Follow-Up Questions

- What happens if you mark a `@Configuration` class as `final`?
- What does `@Configuration(proxyBeanMethods = false)` do?
- In which Spring Boot scenario would you use `proxyBeanMethods = false`?

---

### Common Mistakes

- Using `@Component` on a class with cross-referencing `@Bean` methods and wondering why two different instances of what should be a singleton are created.
- Marking `@Configuration` as `final` — CGLIB cannot subclass `final` classes; Spring throws an exception at startup.

---

### Interview Traps

- **Trap:** "`@Configuration` and `@Component` are the same for `@Bean` methods." — Completely wrong. `@Configuration` adds CGLIB proxying; `@Component` does not.
- **Trap:** "I can avoid CGLIB by using `@Configuration(proxyBeanMethods = false)`." — Yes, but you must not call `@Bean` methods from within the class; use method parameters for cross-wiring.

---

### Quick Revision Notes

- `@Configuration`: CGLIB proxy — inter-`@Bean` method calls return singletons.
- `@Component` (lite mode): no proxy — inter-`@Bean` method calls create new instances.
- `@Configuration(proxyBeanMethods = false)`: lite mode explicitly; faster startup, safe if no cross-references.
- `@Configuration` class must not be `final` — CGLIB cannot subclass it.

---

## 20. @Conditional Annotations

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Pivotal/VMware, Goldman Sachs, Adobe, Stripe

---

### Short Interview Answer (30–60 seconds)

`@Conditional` annotations allow beans to be registered only when specific conditions are met. They are the mechanism behind Spring Boot auto-configuration. The most common ones: `@ConditionalOnClass` (class on classpath), `@ConditionalOnMissingBean` (no existing bean of that type), `@ConditionalOnProperty` (a property has a specific value). You can write a custom condition by implementing the `Condition` interface.

---

### Deep Explanation

**Evaluation timing:**
Conditions are evaluated during `ConfigurationClassPostProcessor`'s processing of `@Configuration` classes and `@Bean` methods. If a condition fails on a `@Configuration` class, none of its `@Bean` methods are processed.

**Commonly used conditions:**

```java
// Only create if HikariDataSource is on the classpath
@ConditionalOnClass(HikariDataSource.class)

// Only create if no DataSource bean has been registered yet
@ConditionalOnMissingBean(DataSource.class)

// Only create if spring.datasource.url is set
@ConditionalOnProperty(name = "spring.datasource.url")

// Only create if property equals specific value
@ConditionalOnProperty(prefix = "app.cache", name = "type", havingValue = "redis")

// Only create if property is set AND not equal to "false"
@ConditionalOnProperty(prefix = "app", name = "feature.enabled",
                       havingValue = "true", matchIfMissing = false)
```

**Custom `Condition`:**
Implement `org.springframework.context.annotation.Condition`:
```java
public class OnKubernetesCondition implements Condition {
    @Override
    public boolean matches(ConditionContext context, AnnotatedTypeMetadata metadata) {
        return context.getEnvironment().containsProperty("KUBERNETES_SERVICE_HOST");
    }
}

@Conditional(OnKubernetesCondition.class)
@Bean
public ServiceMeshHealthIndicator k8sHealthIndicator() { ... }
```

---

### Code Example

```java
// Auto-configuration with multiple conditions
@AutoConfiguration
@ConditionalOnClass({RedisConnectionFactory.class, RedisTemplate.class})
@ConditionalOnProperty(prefix = "spring.redis", name = "host")
public class RedisAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(name = "redisTemplate")
    public RedisTemplate<Object, Object> redisTemplate(RedisConnectionFactory factory) {
        RedisTemplate<Object, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(factory);
        return template;
    }

    @Bean
    @ConditionalOnMissingBean
    public StringRedisTemplate stringRedisTemplate(RedisConnectionFactory factory) {
        return new StringRedisTemplate(factory);
    }
}

// Custom condition using environment and classpath
@Target({ElementType.TYPE, ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Conditional(OnProductionEnvironmentCondition.class)
public @interface ConditionalOnProduction { }

public class OnProductionEnvironmentCondition implements Condition {

    @Override
    public boolean matches(ConditionContext context, AnnotatedTypeMetadata metadata) {
        Environment env = context.getEnvironment();
        String[] activeProfiles = env.getActiveProfiles();
        return Arrays.asList(activeProfiles).contains("prod");
    }
}

@Bean
@ConditionalOnProduction
public CloudMetricsReporter cloudMetrics() {
    return new CloudMetricsReporter();
}
```

---

### Follow-Up Questions

- What is the difference between `@ConditionalOnProperty(havingValue = "true")` and `@ConditionalOnProperty(matchIfMissing = true)`?
- How do you combine multiple conditions (`AND` / `OR` logic)?
- What is `AllNestedConditions` and `AnyNestedCondition`?

---

### Common Mistakes

- Using `@ConditionalOnBean` for auto-configuration that should use `@ConditionalOnMissingBean` — the intent is usually "provide a default unless the user defined their own."
- Forgetting that condition evaluation order matters; Spring evaluates class-level conditions before method-level conditions.

---

### Quick Revision Notes

- `@ConditionalOnClass`: class must be on classpath.
- `@ConditionalOnMissingBean`: no bean of that type registered yet — the "back-off" pattern.
- `@ConditionalOnProperty`: property must be set (and optionally have a specific value).
- Custom conditions: implement `Condition.matches(ConditionContext, AnnotatedTypeMetadata)`.

---

## 21. Spring Events

**Difficulty:** Medium | **Interview Frequency:** Medium

**Companies:** Amazon, Adobe, Salesforce, Goldman Sachs

---

### Short Interview Answer (30–60 seconds)

Spring's event system allows beans to communicate without direct coupling. `ApplicationEventPublisher.publishEvent()` publishes an event; `@EventListener` on a method subscribes to it. Events are synchronous by default — the publisher waits for all listeners to complete. Add `@Async` (with `@EnableAsync`) to process events on a separate thread. `@TransactionalEventListener` is critical for use cases like "send an email after an order is committed" — it fires the listener only after the transaction successfully commits, avoiding sending emails for rolled-back orders.

---

### Deep Explanation

**Event model:**
Events can be any object (Spring 4.2+, no need to extend `ApplicationEvent`). The `ApplicationEventPublisher` resolves all registered listeners for that event type and invokes them.

**Listener resolution:**
`ApplicationListenerMethodAdapter` handles `@EventListener` method detection. Events are matched by method parameter type (including supertype matching).

**`@TransactionalEventListener`:**
Backed by `TransactionalApplicationListenerMethodAdapter`. Binds the listener to a transaction phase:
- `AFTER_COMMIT` (default): fires after successful transaction commit.
- `AFTER_ROLLBACK`: fires after rollback.
- `AFTER_COMPLETION`: fires regardless of outcome.
- `BEFORE_COMMIT`: fires before commit.

**Important:** `@TransactionalEventListener` only fires if the listener is invoked within a transaction. If there is no active transaction, the event is discarded by default (unless `fallbackExecution = true`).

**Ordered listeners:**
```java
@EventListener
@Order(1)
public void firstHandler(OrderCreatedEvent event) { ... }
```

---

### Code Example

```java
// Event class (plain POJO in Spring 4.2+)
public record OrderCreatedEvent(String orderId, String customerId, BigDecimal total) { }

// Publisher
@Service
public class OrderService {

    private final OrderRepository orderRepo;
    private final ApplicationEventPublisher eventPublisher;

    public OrderService(OrderRepository orderRepo, ApplicationEventPublisher eventPublisher) {
        this.orderRepo = orderRepo;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
    public Order createOrder(OrderRequest request) {
        Order order = orderRepo.save(new Order(request));
        // Event published WITHIN the transaction — listeners decide when to act
        eventPublisher.publishEvent(new OrderCreatedEvent(order.id(), request.customerId(), order.total()));
        return order;
    }
}

// Synchronous listener
@Component
public class InventoryReservationListener {

    @EventListener
    public void onOrderCreated(OrderCreatedEvent event) {
        // Runs synchronously in the same transaction as createOrder()
        inventoryService.reserve(event.orderId());
    }
}

// Async listener (decoupled from transaction)
@Component
public class OrderAnalyticsListener {

    @EventListener
    @Async("analyticsExecutor")
    public void onOrderCreated(OrderCreatedEvent event) {
        // Runs on analyticsExecutor thread pool; independent of transaction outcome
        analyticsService.trackOrder(event.orderId(), event.total());
    }
}

// Transactional listener — fires only after commit
@Component
public class OrderConfirmationEmailListener {

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderCommitted(OrderCreatedEvent event) {
        // Only fires if createOrder() transaction committed successfully
        // Safe to send email — the order definitely exists in DB
        emailService.sendOrderConfirmation(event.customerId(), event.orderId());
    }
}

// Configuration
@SpringBootApplication
@EnableAsync
public class OrderApp { ... }
```

---

### Follow-Up Questions

- What happens to a `@TransactionalEventListener` if there is no active transaction?
- How do you publish an event and wait for all listeners to complete?
- Can a listener publish its own events?

---

### Common Mistakes

- Using `@EventListener` to send emails, assuming the transaction has committed — use `@TransactionalEventListener(AFTER_COMMIT)` instead.
- Forgetting `@EnableAsync` when using `@Async` on event listeners — the annotation is silently ignored without it.
- Not handling exceptions in async listeners — uncaught exceptions in async methods go to `AsyncUncaughtExceptionHandler`.

---

### Quick Revision Notes

- `publishEvent()`: synchronous by default, all listeners run before returning.
- `@Async` + `@EventListener`: async, decoupled from publisher thread.
- `@TransactionalEventListener(AFTER_COMMIT)`: fires only on successful commit — prevents side effects for rolled-back transactions.
- Events can be any POJO since Spring 4.2.

---

## 22. @Value and SpEL

**Difficulty:** Easy | **Interview Frequency:** High

**Companies:** Amazon, Adobe, Salesforce, Atlassian, Deutsche Bank

---

### Short Interview Answer (30–60 seconds)

`@Value("${property.name}")` injects a property value from the `Environment`. Add a colon for a default: `@Value("${timeout:30}")`. For Spring Expression Language, use `#{}` syntax: `@Value("#{systemProperties['user.home']}")`. SpEL can call methods, access static fields, evaluate arithmetic, and reference other beans — it is a full expression language embedded in annotations.

---

### Deep Explanation

**`${...}` — Property placeholder:**
Resolved by `PropertySourcesPlaceholderConfigurer` (a `BeanFactoryPostProcessor`) against all registered `PropertySource` objects (environment variables, system properties, `application.properties`, etc.).

**`#{...}` — SpEL expression:**
Evaluated by the Spring Expression Language engine at runtime. Can reference:
- System properties: `#{systemProperties['user.home']}`
- Environment: `#{environment['spring.profiles.active']}`
- Other beans: `#{orderConfig.maxItems}`
- Static methods: `#{T(java.lang.Math).PI}`
- Java operators: `#{1 + 2}`, `#{price * 0.9}`, `#{items.?[price > 100]}`

**Combined:**
```java
@Value("#{${app.timeout.seconds} * 1000}")  // property value used in SpEL arithmetic
```

**Type conversion:**
`@Value` handles type conversion automatically (String to int, String to Duration, String to List<String> via comma separation).

```java
@Value("${app.allowed-origins}")   // "http://a.com,http://b.com"
private List<String> allowedOrigins;  // auto-split by Spring's ConversionService
```

---

### Code Example

```java
@Service
public class RecommendationService {

    // Property injection with default
    @Value("${recommendation.max-results:10}")
    private int maxResults;

    // SpEL: access system property
    @Value("#{systemProperties['user.timezone']}")
    private String timezone;

    // SpEL: call static method
    @Value("#{T(java.time.ZoneId).of('UTC')}")
    private ZoneId utcZone;

    // SpEL: reference another bean's property
    @Value("#{featureFlagConfig.newAlgorithmEnabled}")
    private boolean newAlgorithmEnabled;

    // SpEL arithmetic on a property
    @Value("#{${recommendation.cache-ttl-seconds:300} * 1000}")
    private long cacheTtlMs;

    // List injection from comma-separated property
    @Value("${recommendation.allowed-categories:electronics,books}")
    private List<String> allowedCategories;

    // Map injection
    @Value("#{${recommendation.weights}}")
    // properties: recommendation.weights={price:0.3, rating:0.5, relevance:0.2}
    private Map<String, Double> weights;
}

// SpEL in @ConditionalOnExpression
@Bean
@ConditionalOnExpression("'${app.env}' == 'prod' && ${app.feature.premium.enabled:false}")
public PremiumFeatureService premiumService() {
    return new PremiumFeatureService();
}
```

---

### Follow-Up Questions

- What is the difference between `${...}` and `#{...}` in `@Value`?
- How do you inject a `Duration` or `List<String>` using `@Value`?
- Can SpEL reference a Spring bean? How?

---

### Common Mistakes

- Using `@Value("${property}")` when the property is not defined and not providing a default — results in `IllegalArgumentException` at startup.
- Mixing `${...}` and `#{...}` incorrectly: `@Value("#{${price} * 1.2}")` is valid (outer SpEL, inner property), but `@Value("${#{expr}}")` is not.

---

### Interview Traps

- **Trap:** "SpEL is only for `@Value`." — SpEL is used in `@PreAuthorize`, `@ConditionalOnExpression`, `@Cacheable(key="...")`, `@EventListener(condition="...")`, `@Query` (Spring Data), and more.

---

### Quick Revision Notes

- `${prop:default}`: property placeholder with optional default.
- `#{...}`: SpEL — arithmetic, method calls, bean references, static types via `T(...)`.
- `@Value` converts to int, long, Duration, List, Map automatically.
- SpEL is also used in `@PreAuthorize`, `@Cacheable`, `@ConditionalOnExpression`.

---

## ASCII Bean Lifecycle Diagram

```
    Spring ApplicationContext.refresh()
           |
           v
    +-------------------------------+
    |  1. INSTANTIATE               |
    |     new Bean()                |
    +-------------------------------+
           |
           v
    +-------------------------------+
    |  2. POPULATE PROPERTIES       |
    |     @Autowired, @Value        |
    +-------------------------------+
           |
           v
    +-------------------------------+
    |  3. AWARE CALLBACKS           |
    |  BeanNameAware                |
    |  BeanFactoryAware             |
    |  ApplicationContextAware      |
    |  (+ other Aware interfaces)   |
    +-------------------------------+
           |
           v
    +-------------------------------+
    |  4. BeanPostProcessor         |
    |     .postProcessBefore        |
    |     Initialization()          |
    +-------------------------------+
           |
           v
    +-------------------------------+
    |  5. INIT CALLBACKS            |
    |  a) @PostConstruct            |
    |  b) InitializingBean          |
    |     .afterPropertiesSet()     |
    |  c) custom init-method        |
    +-------------------------------+
           |
           v
    +-------------------------------+
    |  6. BeanPostProcessor         |
    |     .postProcessAfter         |
    |     Initialization()          |
    |     << AOP PROXY CREATED >>   |
    +-------------------------------+
           |
           v
    +===============================+
    ||  BEAN READY (in container)  ||
    +===============================+
           |
           | (on context.close())
           v
    +-------------------------------+
    |  7. DESTROY CALLBACKS         |
    |  a) @PreDestroy               |
    |  b) DisposableBean.destroy()  |
    |  c) custom destroy-method     |
    +-------------------------------+
           |
           v
    +-------------------------------+
    |  BEAN DESTROYED               |
    +-------------------------------+

    NOTE: Steps 3-6 and 7 do NOT apply to prototype-scoped beans
          (Spring does not track prototype lifecycle after creation)
```

---

## Quick Reference: Annotation Table

| Annotation | Purpose | When to use |
|---|---|---|
| `@Component` | Generic Spring-managed bean | Any class that should be a Spring bean |
| `@Service` | Service layer bean | Business logic, domain services |
| `@Repository` | Data access bean | DAO, repository classes (adds exception translation) |
| `@Controller` | MVC controller | Classes with `@RequestMapping` handler methods |
| `@RestController` | REST controller | REST APIs; combines `@Controller` + `@ResponseBody` |
| `@Autowired` | Inject a dependency | Constructor (preferred), setter, or field |
| `@Qualifier("name")` | Select a specific bean when multiple candidates exist | With `@Autowired` when `@Primary` is not sufficient |
| `@Primary` | Mark the default bean when multiple candidates exist | On one of multiple beans of the same type |
| `@Scope("prototype")` | Change bean scope | Non-singleton beans (per-request, per-use) |
| `@Lazy` | Defer bean initialization | Optional deps, breaking non-critical startup cycles |
| `@PostConstruct` | Init callback after injection | Cache warm-up, validation, scheduling |
| `@PreDestroy` | Cleanup callback before destruction | Release resources, flush state |
| `@Configuration` | Define bean factory class (CGLIB-proxied) | Infrastructure config, `@Bean` method classes |
| `@Bean` | Declare a bean in a config class | Third-party or programmatic bean creation |
| `@SpringBootApplication` | Combine config + scan + auto-config | Main application class |
| `@EnableAutoConfiguration` | Activate auto-configuration | Embedded in `@SpringBootApplication` |
| `@ComponentScan` | Scan for beans in specified packages | Customize scanning beyond default base package |
| `@ConditionalOnClass` | Bean if class is on classpath | Auto-configuration guards |
| `@ConditionalOnMissingBean` | Bean if no existing bean of that type | Default bean with back-off |
| `@ConditionalOnProperty` | Bean if property is set/has value | Feature toggles, environment-based activation |
| `@Value("${...}")` | Inject a property value | Single scalar values from config |
| `@ConfigurationProperties` | Bind a group of properties type-safely | Multiple related properties |
| `@Profile("prod")` | Register bean only in specific profile | Environment-specific beans/config |
| `@ActiveProfiles` | Set active profiles in test | Test configuration |
| `@EventListener` | Subscribe to application events | Loose coupling between components |
| `@TransactionalEventListener` | Event fires after transaction commits | Post-commit side effects (email, outbox) |
| `@Transactional` | Wrap method in a transaction | Service layer DB operations |
| `@Async` | Execute method asynchronously | Background tasks, async event handling |
| `@Cacheable` | Cache method result | Read-heavy operations with stable results |
| `@CacheEvict` | Remove cache entries | After write/update operations |
| `@Retryable` | Retry on specified exceptions | Calls to flaky external services |
| `@PreAuthorize` | Method-level security via SpEL | Fine-grained authorization |
| `@Aspect` | Declare an aspect class | Cross-cutting concern modules |
| `@Around` | Around advice wrapping a join point | Timing, tracing, conditional execution |
| `@Before` | Advice before join point | Validation, logging |
| `@After` | Advice after join point (any outcome) | Cleanup |
| `@AfterReturning` | Advice after successful return | Audit on success |
| `@AfterThrowing` | Advice after exception | Error tracking |
| `@Lookup` | Prototype injection into singleton | Break scope mismatch via method injection |

---

## Proxy Type Selection Table

| Scenario | Proxy Type | Why |
|---|---|---|
| Bean implements one or more interfaces | JDK Dynamic Proxy | Default; uses `java.lang.reflect.Proxy`; lightweight |
| Bean has NO interface | CGLIB | JDK proxy requires at least one interface; CGLIB subclasses the class |
| `@EnableAspectJAutoProxy(proxyTargetClass = true)` | CGLIB | Explicitly requested; bypasses interface check |
| `spring.aop.proxy-target-class=true` (Boot default) | CGLIB | Spring Boot defaults to CGLIB for all beans since 2.x |
| Target is `final` class | Neither — fails | CGLIB cannot subclass `final`; JDK proxy needs interface |
| Target method is `final` | Intercepted by JDK proxy (if interface), not by CGLIB | CGLIB cannot override `final` methods |
| Target method is `private` | Neither proxy type | Proxies cannot intercept non-overridable methods |
| `@Transactional` on class without interface | CGLIB | Most common Spring Boot scenario |
| `@Transactional` on class with interface | CGLIB (Boot default) or JDK (if `proxyTargetClass=false`) | Boot defaults to CGLIB; original Spring default was JDK |
| `@Cacheable` on service bean | CGLIB (Boot default) | Same as `@Transactional` — Spring Boot prefers CGLIB |
| AspectJ compile-time weaving | No proxy at all | Bytecode modified at compile time; works on private/final |

**Summary rule for Spring Boot 3.x:**
Spring Boot defaults `spring.aop.proxy-target-class=true`, meaning **CGLIB is used for all beans regardless of whether they implement an interface**. To get JDK proxies, set `spring.aop.proxy-target-class=false`.

---

*End of Chapter 7 — Spring Core & Spring Boot*

*Volume 2, Chapter 8: Spring MVC & REST API Design*

---

## Supplementary: Real-World Examples & Interview Traps (Q7–Q22)

### Q7 — BeanPostProcessor vs BeanFactoryPostProcessor
**Real-World Example:** Spring Security uses `AutowiredAnnotationBeanPostProcessor` to inject security context into beans. `PropertySourcesPlaceholderConfigurer` is a `BeanFactoryPostProcessor` that resolves `${...}` placeholders in `@Value` annotations before beans are created — it must run before bean instantiation.

**Interview Traps:**
- `BeanPostProcessor` operates on bean instances (after creation); `BeanFactoryPostProcessor` operates on bean definitions (before creation). Confusing the two leads to ordering bugs.
- A `BeanPostProcessor` bean itself cannot be `@Lazy` — the container must create it eagerly to apply it to other beans.

### Q8 — @PostConstruct and @PreDestroy
**Real-World Example:** A `DatabaseConnectionPool` bean uses `@PostConstruct` to validate the JDBC URL and pre-warm connections on startup. `@PreDestroy` gracefully closes all connections and releases resources before the application shuts down — critical for avoiding connection leaks in Cloud-native deployments with rolling restarts.

**Interview Traps:**
- `@PostConstruct` runs after dependency injection but before the bean is put into service — calling `@Autowired` fields is safe here.
- `@PreDestroy` is NOT called for prototype-scoped beans — the container does not manage their destruction. Use `DisposableBean` or a custom scope if cleanup is needed.

### Q9 — Circular Dependencies
**Real-World Example:** In a payment service, `PaymentService` depends on `FraudService` for fraud checks, and `FraudService` depends on `PaymentService` to retrieve payment history. This circular dependency manifests as a `BeanCurrentlyInCreationException` with constructor injection. Resolution: use `@Lazy` on one parameter, or redesign to extract the shared logic into a third `PaymentHistoryService`.

**Interview Traps:**
- Constructor injection fails immediately with circular deps; setter/field injection works via the 3-level cache but hides the design smell.
- Spring Boot 2.6+ disables circular dependency detection by default — it will throw; set `spring.main.allow-circular-references=true` only as a temporary workaround.

### Q10 — AOP Fundamentals
**Real-World Example:** Netflix uses AOP-style interceptors for distributed tracing — every service call is wrapped to propagate trace IDs without cluttering business logic. In Spring, a `@Around` advice on `@Service` methods automatically injects `X-Correlation-ID` into MDC for structured logging across microservices.

**Interview Traps:**
- AOP only intercepts calls that go through the Spring proxy. A method calling another method within the same class bypasses the proxy — `this.method()` is a direct call, not a proxy call.
- `@Transactional` is implemented as AOP — this is why self-invocation breaks `@Transactional` too.

### Q11 — @Transactional Internals
**Real-World Example:** In an e-commerce order service, `OrderService.placeOrder()` is `@Transactional`. It calls `inventoryService.deductStock()` (REQUIRED — joins the same transaction) and `auditService.logOrder()` (REQUIRES_NEW — runs in a separate transaction so audit logs are preserved even if the order fails). This pattern ensures the audit trail is always written regardless of order placement outcome.

**Interview Traps:**
- `@Transactional` on a `private` method is silently ignored — Spring AOP cannot intercept private methods.
- `@Transactional(readOnly = true)` does NOT prevent writes — it's a hint to the connection pool (Hibernate skips dirty checking, improving performance), but the DB will still execute writes if you issue them.

### Q12 — Common AOP Use Cases in Production
**Real-World Example:** Stripe uses AOP-equivalent patterns for idempotency enforcement — every payment API endpoint is wrapped with logic that checks an idempotency key in Redis before executing. In Spring, this is implemented as a `@Around` advice on methods annotated with a custom `@Idempotent` annotation.

**Interview Traps:**
- Applying `@Around` advice to all `@Service` methods indiscriminately adds overhead to every bean call. Narrow pointcut expressions (e.g., only public methods on `@RestController`) prevent performance regression.
- AOP advice execution order with multiple aspects is determined by `@Order` — without explicit ordering, advice execution order is undefined.

### Q13 — Spring Boot Auto-Configuration Internals
**Real-World Example:** When you add `spring-boot-starter-data-redis` to a Spring Boot project, `RedisAutoConfiguration` activates automatically because `LettuceConnectionFactory` is on the classpath. It creates a `RedisTemplate` bean with default serializers. Without any explicit `@Configuration`, you get a working Redis connection — this is how Spring Boot reduces boilerplate configuration.

**Interview Traps:**
- Auto-configuration classes are listed in `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` (Spring Boot 3.x) — NOT in `@ComponentScan` path. They are NOT picked up by component scanning.
- `@ConditionalOnMissingBean` means "only create this bean if you haven't defined one yourself" — define your own bean to override auto-configuration.

### Q14 — @SpringBootApplication
**Real-World Example:** A multi-module Spring Boot project may have the main `@SpringBootApplication` class in the root package to ensure component scanning covers all sub-packages. Moving it to a sub-package accidentally excludes other sub-packages from scanning — a common cause of `NoSuchBeanDefinitionException` in multi-module setups.

**Interview Traps:**
- `@SpringBootApplication` is equivalent to `@Configuration + @EnableAutoConfiguration + @ComponentScan`. Forgetting `@EnableAutoConfiguration` (when configuring manually) disables all auto-configuration.
- Placing `@SpringBootApplication` in the wrong package causes incomplete component scanning — always place it in the root package of the application.

### Q15 — application.properties vs application.yml
**Real-World Example:** A microservice team uses `application.yml` for its hierarchical clarity (database config nested under `spring.datasource`) and profile-specific overrides in `application-prod.yml`. Kubernetes deploys config via ConfigMaps that override values using environment variables — `SPRING_DATASOURCE_URL` overrides `spring.datasource.url`, which is the 3rd-highest priority in Spring's property resolution order.

**Interview Traps:**
- YAML uses spaces (not tabs) for indentation — a tab character causes a parse error with no obvious error message.
- `${VAR:defaultValue}` syntax works in both properties and YAML. In YAML, special characters in default values may require quoting.

### Q16 — Spring Profiles
**Real-World Example:** A financial application has `dev`, `test`, `staging`, and `prod` profiles. The `prod` profile activates encrypted datasource credentials and disables H2 console. CI/CD pipeline sets `SPRING_PROFILES_ACTIVE=staging` as an environment variable, overriding any `application.properties` setting — environment variables have higher precedence than config files.

**Interview Traps:**
- `@Profile("!prod")` means "active when prod profile is NOT active" — useful for excluding dev-only beans from production.
- Multiple active profiles: `spring.profiles.active=dev,security` activates both. Profile-specific files (`application-dev.yml`) are loaded additionally, not as replacements.

### Q17 — Spring Boot Actuator
**Real-World Example:** A Kubernetes deployment uses Actuator's `/actuator/health/liveness` and `/actuator/health/readiness` endpoints for liveness and readiness probes. The readiness probe also checks database connectivity and message broker health via `HealthIndicator` — if the DB is down, the pod is removed from load balancing without being restarted (readiness failure vs liveness failure distinction).

**Interview Traps:**
- `/actuator/health` only shows `UP`/`DOWN` by default. To expose full component details, set `management.endpoint.health.show-details=always` — but never do this without authentication in production (exposes DB credentials format, URLs).
- Actuator endpoints are on a separate management port by default — configure `management.server.port=8081` to separate operational traffic from application traffic.

### Q18 — Spring Boot Startup Sequence
**Real-World Example:** An application needs to validate external API keys on startup. Implementing `ApplicationRunner` runs the validation after the full context is ready (beans wired, datasource connected). If validation fails, throwing an exception in `ApplicationRunner.run()` triggers graceful shutdown — better than a `@PostConstruct` NPE that crashes mid-initialization.

**Interview Traps:**
- `CommandLineRunner` vs `ApplicationRunner`: both run after context refresh, but `ApplicationRunner` receives `ApplicationArguments` (parsed) while `CommandLineRunner` receives raw `String[]` args.
- `@EventListener(ApplicationReadyEvent.class)` fires after all `CommandLineRunner` and `ApplicationRunner` beans complete — use it for post-startup tasks that depend on runners finishing.

### Q19 — @Configuration vs @Component for @Bean Methods
**Real-World Example:** A team defines a `DataSourceConfig` class with `@Component` instead of `@Configuration`. Two `@Bean` methods both call `dataSource()` internally — because there's no CGLIB proxy, each call creates a NEW `DataSource` instance. The application now has two separate connection pools instead of one shared pool — a silent resource leak discovered only under load testing.

**Interview Traps:**
- `@Configuration` classes are CGLIB-proxied — `@Bean` method calls within the same class return the cached bean instance. `@Component` (lite mode) does NOT proxy — each call creates a new instance.
- `@Configuration(proxyBeanMethods = false)` opts out of CGLIB proxying for performance (faster startup, no CGLIB dependency) — safe only if `@Bean` methods are never called directly from other `@Bean` methods.

### Q20 — @Conditional Annotations
**Real-World Example:** A library provides both Redis and in-memory implementations of a `CacheService`. `@ConditionalOnClass(RedisConnectionFactory.class)` activates the Redis implementation when Lettuce/Jedis is on the classpath; `@ConditionalOnMissingBean(CacheService.class)` ensures applications can override it with their own implementation. This is the exact pattern used by Spring Boot's own auto-configuration starters.

**Interview Traps:**
- `@ConditionalOnProperty(name="feature.x", havingValue="true")` requires the property to exist AND equal "true". `matchIfMissing=true` makes the condition pass even if the property is absent.
- Conditional evaluation order matters — `@ConditionalOnBean` relies on bean registration order, which can cause flakiness. Prefer `@ConditionalOnClass` (classpath-based) for library auto-configuration.

### Q21 — Spring Events
**Real-World Example:** An order service publishes `OrderPlacedEvent` after successful persistence. `EmailNotificationListener` and `InventoryUpdateListener` independently handle the event — decoupled, no direct service dependencies. Using `@TransactionalEventListener(phase = AFTER_COMMIT)` ensures notifications are only sent after the order transaction commits — prevents sending confirmation emails for rolled-back orders.

**Interview Traps:**
- `@EventListener` runs synchronously in the same thread by default. For async processing, add `@Async` and `@EnableAsync` — but be aware this loses the transaction context.
- `@TransactionalEventListener` only fires if there is an active transaction. If the publishing method is not `@Transactional`, the event is dropped silently.

### Q22 — @Value and SpEL
**Real-World Example:** A service reads AWS region from environment: `@Value("${aws.region:us-east-1}")` with a default. SpEL is used for conditional injection: `@Value("#{environment.getProperty('feature.new-algo') == 'true' ? @newAlgoBean : @legacyAlgoBean}")` — injects different strategy implementations based on a feature flag without changing Java code.

**Interview Traps:**
- `@Value` is resolved by `PropertySourcesPlaceholderConfigurer` which is a `BeanFactoryPostProcessor` — it must be registered as a `static @Bean` in `@Configuration` classes to apply to other `@Configuration` beans.
- SpEL `#{...}` and property placeholder `${...}` are different syntax — `#{${some.property}}` wraps a property value inside SpEL evaluation.

---

