# Volume 6: Interview Revision Pack
# Chapter 24: Spring & JPA — Interview Lens

> **How to use this chapter:** Every Q&A is written to be spoken aloud in an interview. All technical terms are explained inline. Study section by section; drill Common Mistakes and Quick Revision hooks before your interview day.
>
> **Cross-reference:** Core concepts covered in depth in Volume 2 — Chapter 7 (Spring Core & Boot), Chapter 8 (JPA & Hibernate).

---

## Table of Contents
1. [Spring Core](#section-1-spring-core--top-15-questions)
2. [Spring Boot](#section-2-spring-boot--top-10-questions)
3. [Spring Data JPA](#section-3-spring-data-jpa--top-15-questions)
4. [@Transactional Propagation](#section-4-transactional-propagation)
5. [AOP](#section-5-aop)
6. [Common Spring Traps](#section-6-common-spring-traps)
7. [Hibernate Cheat Sheet](#section-7-hibernate-cheat-sheet)
8. [Must-Know Config Snippets](#section-8-must-know-config-snippets)

---

## Section 1: Spring Core

> *Reading guide: Focus on the "why" behind each mechanism — interviewers probe deeper than definitions, so understand what problem each feature solves.*

---

**Q1: What is the difference between IoC and Dependency Injection?**
*Concept Check*

**One-line answer:** IoC is the design principle of inverting who controls object creation; DI is the specific mechanism Spring uses to implement that principle by injecting dependencies from outside.

**Full answer:**
IoC, or Inversion of Control, is the principle that a class should not be responsible for creating its own dependencies. Traditionally, if a `UserService` needed a `UserRepository`, it would call `new UserRepository()` itself — the class controlled its own wiring. IoC inverts that: an external container takes over the responsibility of creating and connecting objects. Dependency Injection is the concrete mechanism that implements IoC in Spring — the container creates both `UserService` and `UserRepository`, then injects the repository into the service, either through the constructor, a setter method, or directly into a field. The reason this matters is decoupling: the `UserService` no longer knows or cares how to build a `UserRepository`, only that it receives one. In a test, I can construct `new UserService(mockRepository)` without starting a Spring context at all, which makes unit tests fast and isolated. The practical takeaway is that IoC is the concept and DI is one of its implementations — Spring also supports IoC via Service Locator patterns, but DI is the preferred approach because it keeps dependencies explicit.

*Lead with the principle-vs-mechanism distinction — interviewers frequently use the terms interchangeably and appreciate the correction.*

> **Gotcha follow-up:** Can you have IoC without DI?
> Yes. A Service Locator pattern is also an implementation of IoC — the class asks a registry for its dependency rather than creating it with `new`. The control is still inverted (the class does not instantiate the dependency), but no injection happens. Spring's `ApplicationContext.getBean()` is essentially a service locator call. DI is generally preferred because dependencies are visible in the constructor signature, but Service Locator is a valid IoC alternative, particularly in legacy code or framework bootstrapping where the container itself is not yet available.

---

**Q2: What is the difference between BeanFactory and ApplicationContext?**
*Concept Check*

**One-line answer:** BeanFactory is the bare-minimum Spring container with lazy bean creation; ApplicationContext extends it with eager initialization, event publishing, i18n, and automatic post-processor detection — use ApplicationContext in every real application.

**Full answer:**
`BeanFactory` is the root interface of the Spring container. It can create and manage beans, and it does so lazily — beans are only instantiated when first requested via `getBean()`. This means startup errors in bean configuration are not discovered until that bean is actually used, which makes problems harder to diagnose in production. `ApplicationContext` is a sub-interface that extends `BeanFactory` and adds a significant set of enterprise features. First, it eagerly instantiates all singleton beans at startup, so any wiring or configuration error is caught immediately when the application boots rather than during a live request. Second, it supports the event publishing mechanism via `ApplicationEventPublisher`, allowing beans to listen to lifecycle and custom events with `@EventListener`. Third, it provides `MessageSource` for internationalization, letting you resolve locale-specific messages. Fourth, it automatically detects and applies `BeanPostProcessor` and `BeanFactoryPostProcessor` beans without manual registration — this is how Spring's own features like `@Autowired` injection and AOP proxy creation are wired in. In practice, every Spring Boot application uses an `ApplicationContext` automatically; `BeanFactory` is only relevant in extremely constrained embedded environments where the extra overhead genuinely matters.

*When asked "which would you use," always say ApplicationContext and give at least one concrete reason — eager startup failure detection is the most interview-friendly.*

> **Gotcha follow-up:** What triggers `BeanPostProcessor` registration differently in the two containers?
> In `BeanFactory`, you must manually register `BeanPostProcessor` beans by calling `factory.addBeanPostProcessor(...)`. In `ApplicationContext`, any bean in the context that implements `BeanPostProcessor` is automatically detected during refresh and applied to all subsequently created beans. This is why features like `@Autowired` (handled by `AutowiredAnnotationBeanPostProcessor`) and AOP proxy creation (handled by `AnnotationAwareAspectJAutoProxyCreator`) work transparently in Spring Boot — you never register those post-processors manually.

---

**Q3: What are Spring's five bean scopes?**
*Concept Check*

**One-line answer:** singleton (one per context), prototype (new per injection), request (one per HTTP request), session (one per HTTP session), application (one per ServletContext).

**Full answer:**
Spring beans have a scope that controls how many instances exist and for how long. The default is `singleton`: Spring creates exactly one instance per `ApplicationContext` and returns that same instance every time the bean is injected or looked up — most service and repository beans live here. `prototype` means a brand-new instance is created every single time the bean is requested, whether via `getBean()` or through injection — the container does not manage its lifecycle after creation, so `@PreDestroy` is never called on prototype beans. The three web-aware scopes require an active web `ApplicationContext`. `request` creates one instance per HTTP request and destroys it when the request completes — useful for request-scoped state like a security context holder. `session` creates one instance per HTTP session and lives until the session expires — useful for user-specific preferences. `application` creates one instance per `ServletContext`, which effectively makes it a cross-user singleton scoped to the web application rather than the Spring context. In practice, the vast majority of beans are `singleton`. The scope that causes the most interview questions is `prototype` injected into a `singleton`, which I cover in Q6.

*Interviewers often ask "what is the default scope?" — always say singleton and briefly state what it means.*

> **Gotcha follow-up:** Does Spring call `@PreDestroy` on prototype-scoped beans?
> No. The Spring container creates prototype beans and hands them off to the caller but does not keep a reference to them afterward. Because it does not track prototype instances, it cannot call `@PreDestroy` or any destroy callback when the application shuts down. If a prototype bean holds a resource like a database connection or file handle, you are responsible for releasing it, either by managing the bean lifecycle manually or by using a `DestructionAwareBeanPostProcessor`.

---

**Q4: Why is constructor injection preferred over field injection?**
*Tradeoff Question*

**One-line answer:** Constructor injection makes dependencies explicit, allows `final` fields for immutability, fails fast at startup on missing dependencies, and enables plain-Java unit tests — field injection hides dependencies and requires Spring or reflection for testing.

**Full answer:**
With constructor injection, every dependency is listed as a constructor parameter and assigned to a `final` field. This makes the contract of the class completely explicit: anyone reading the constructor signature immediately knows what the class needs to function. Because the fields are `final`, the object is immutable after construction — no code can accidentally replace an injected dependency later. If a required bean is missing at startup, Spring throws a `BeanCreationException` immediately when it tries to construct the bean, making the failure loud and early rather than a `NullPointerException` during a live request. Unit testing is trivial: I write `new UserService(new MockUserRepository())` and the test runs without any Spring context, making it fast and IDE-friendly. Field injection uses reflection to set `private` fields annotated with `@Autowired` after the object is constructed. Those fields cannot be `final`, so the dependency could theoretically be changed after construction. More importantly, the dependencies are invisible from the outside — you cannot tell what a class needs without reading its field declarations. And in a unit test, you either need to start a Spring context or use `ReflectionTestUtils.setField(...)` to inject mocks, both of which add friction. The practical rule I follow: constructor injection for all required dependencies; setter injection only for optional ones.

*Mention the word "immutability" — it signals understanding beyond just testing convenience.*

> **Gotcha follow-up:** Lombok's `@RequiredArgsConstructor` removes boilerplate — is there any downside?
> `@RequiredArgsConstructor` generates a constructor for all `final` fields, which works perfectly with Spring's constructor injection and is the idiomatic pattern in modern Spring Boot code. The one subtle risk is that adding a new `final` field automatically adds it to the constructor, which can silently break serialization, Jackson deserialization, or any code that constructs the class directly. It also hides the constructor body, so it's slightly harder to see exactly what Spring will inject. These are minor concerns — the pattern is widely used and recommended.

---

**Q5: How does Spring resolve `@Autowired` when there are multiple candidates?**
*Concept Check*

**One-line answer:** Spring tries type match first, then `@Qualifier` name, then field/parameter name as bean name — if still ambiguous it throws `NoUniqueBeanDefinitionException`; `@Primary` designates a default winner.

**Full answer:**
When Spring encounters an `@Autowired` injection point, it follows a resolution chain. First, it searches the context for all beans whose type is assignable to the required type. If exactly one bean matches, injection succeeds immediately. If multiple beans match, Spring checks for a `@Qualifier("beanName")` annotation at the injection point and filters candidates to the one with that qualifier value. If no `@Qualifier` is present, Spring falls back to using the field name or parameter name as an implicit bean name and picks the candidate whose registered name matches. If that also fails to produce a single match, Spring throws `NoUniqueBeanDefinitionException`, which tells you there are multiple candidates and none was disambiguated. A completely missing match throws `NoSuchBeanDefinitionException`. The cleanest long-term solution when you have multiple implementations of the same interface is to annotate one with `@Primary`, making it the default when no qualifier is specified, and use `@Qualifier` on injection points that need the non-default implementation. I use `@Primary` on the real implementation and `@Qualifier("mock...")` on test doubles.

*Be ready to write the resolution order as a numbered list — interviewers love that.*

| Step | Condition | Action |
|------|-----------|--------|
| 1 | Exactly one type match | Inject it |
| 2 | Multiple matches + `@Qualifier` present | Filter by qualifier value |
| 3 | Multiple matches, no `@Qualifier` | Match by field/parameter name |
| 4 | Still multiple matches | Throw `NoUniqueBeanDefinitionException` |
| 5 | Zero matches | Throw `NoSuchBeanDefinitionException` |

> **Gotcha follow-up:** What is `@Primary` and when should you prefer `@Qualifier` over it?
> `@Primary` marks one bean as the default winner when multiple candidates of the same type exist and no qualifier is specified at the injection point. Use `@Primary` when one implementation is the overwhelmingly common choice — it keeps injection points clean. Use `@Qualifier` when different injection points legitimately need different implementations, because `@Primary` only covers the "no-preference" case. If you have three implementations and two injection points need specific ones, `@Qualifier` is clearer because it makes the selection explicit at the injection point.

---

**Q6: What happens when a prototype bean is injected into a singleton, and how do you fix it?**
*Tradeoff Question*

**One-line answer:** The prototype is created once at startup alongside the singleton and effectively lives forever — it behaves like a singleton despite the declaration; fix with `ObjectProvider`, `@Lookup`, or a scoped proxy.

**Full answer:**
This is one of the most common Spring pitfalls. A singleton bean is constructed once when the application context starts. At that moment, Spring injects all its dependencies — including any prototype-scoped beans declared as `@Autowired`. That prototype instance is created once, stored in the singleton's field, and never recreated for the life of the application. The prototype scope declaration is effectively ignored. The root cause is that scope only controls how the container creates beans; once a bean reference is held by another bean, the container is no longer in the loop. There are three standard fixes. First, inject `ObjectProvider<MyPrototypeBean>` — this is a lazy factory provided by Spring. Each time you call `provider.getObject()`, Spring creates a fresh prototype instance. Second, use `@Lookup` method injection: annotate an abstract method with `@Lookup` and Spring overrides it via CGLIB to return a new prototype instance on every call. Third, annotate the prototype bean definition with `@Scope(value = "prototype", proxyMode = ScopedProxyMode.TARGET_CLASS)` — Spring wraps the prototype in a CGLIB proxy, and every method call on the proxy triggers creation of a new underlying instance. I prefer `ObjectProvider` for its clarity; `@Lookup` is useful when you cannot change the calling class.

*The phrase "the prototype behaves like a singleton" is the key insight — say it exactly like that.*

> **Gotcha follow-up:** Does `@Scope(proxyMode = TARGET_CLASS)` work for singleton beans too?
> Yes, and it is used for request and session scoped beans injected into singletons all the time. A singleton bean might hold a reference to a request-scoped `UserContext`. Without a proxy, the request-scoped bean would be created once at startup when the singleton is injected, which makes no sense. With `proxyMode = TARGET_CLASS`, the singleton holds a proxy, and each method call on the proxy delegates to the actual request-scoped instance for the current HTTP request, which Spring stores in a `ThreadLocal`. This is the standard pattern for injecting short-lived scoped beans into long-lived ones.

---

**Q7: What are the Spring bean lifecycle phases in order?**
*Concept Check*

**One-line answer:** Constructor → property injection → Aware callbacks → `BeanPostProcessor.before` → `@PostConstruct`/`afterPropertiesSet` → `BeanPostProcessor.after` (where AOP proxies are created) → bean in use → `@PreDestroy`/`destroy`.

**Full answer:**
Understanding the lifecycle order matters when you write custom extensions or debug initialization problems. The sequence begins with instantiation — Spring calls the constructor, which is why constructor injection happens here. Next, property population injects `@Autowired` fields and setter dependencies. Then Aware callbacks fire: if the bean implements `BeanNameAware`, Spring calls `setBeanName()` so the bean knows its registered name; if it implements `ApplicationContextAware`, Spring calls `setApplicationContext()` so the bean has a reference to the context. After Aware callbacks, all registered `BeanPostProcessor` implementations run their `postProcessBeforeInitialization()` methods — these can wrap or replace the bean before initialization. Then custom initialization runs: first `@PostConstruct` annotated methods, then `InitializingBean.afterPropertiesSet()` if implemented, then any `init-method` declared in XML or `@Bean(initMethod="...")`. After initialization, `BeanPostProcessor.postProcessAfterInitialization()` runs — this is the critical phase where Spring's AOP infrastructure wraps the bean in a proxy if it matches any pointcut. The fully initialized (and possibly proxied) bean then enters the application. On context shutdown, `@PreDestroy` methods run, followed by `DisposableBean.destroy()`, followed by any declared `destroy-method`.

*The detail that AOP proxies are created in `postProcessAfterInitialization` (after init, not before) is a reliable interview differentiator.*

| Phase | What happens |
|-------|-------------|
| Instantiation | Constructor called |
| Property population | `@Autowired` dependencies injected |
| Aware callbacks | `BeanNameAware`, `ApplicationContextAware`, etc. |
| `BPP.before` | `BeanPostProcessor.postProcessBeforeInitialization()` |
| Init | `@PostConstruct` → `afterPropertiesSet()` → `init-method` |
| `BPP.after` | `BeanPostProcessor.postProcessAfterInitialization()` — **AOP proxies created here** |
| In use | Application uses the bean |
| Destroy | `@PreDestroy` → `destroy()` → `destroy-method` |

> **Gotcha follow-up:** If your `@PostConstruct` method calls a method on another Spring bean, is that other bean guaranteed to be fully initialized?
> Not necessarily. Spring initializes beans in dependency order — if bean A depends on bean B (via `@Autowired`), bean B is guaranteed to be initialized before A's `@PostConstruct` runs. But if A's `@PostConstruct` calls a method on bean C that A does not directly depend on, C may or may not be initialized yet, depending on the context's initialization order. The safe pattern is to declare all dependencies explicitly so the container knows the order, or use `@DependsOn("beanC")` to force ordering.

---

**Q8: How does Spring resolve circular dependencies, and when does it fail?**
*Concept Check*

**One-line answer:** Spring uses a three-level singleton cache to expose a partially-constructed bean early, allowing the dependent bean to complete — but this only works for field/setter injection; constructor injection always fails with circular dependencies.

**Full answer:**
Spring manages singleton bean creation with three caches, each serving a different purpose. Level 3 (`singletonFactories`) holds factory lambdas that can produce an early, partially-constructed reference to a bean that is still being initialized. Level 2 (`earlySingletonObjects`) stores early references that have already been retrieved from Level 3 and promoted. Level 1 (`singletonObjects`) stores fully initialized, production-ready beans. The resolution works like this: Spring starts creating bean A. Before A's constructor finishes, Spring registers a factory for A in Level 3. Then, while constructing A's dependencies, Spring discovers it needs bean B. Spring starts creating B. B needs A. Spring checks the caches — it finds A's factory in Level 3, calls it to get an early (incomplete) reference to A, and injects that into B. B completes initialization and moves to Level 1. Spring then finishes initializing A using the now-complete B. The reason constructor injection breaks this is that A's early reference cannot exist until its constructor completes. If A's constructor requires B and B's constructor requires A, neither constructor can ever start — Spring detects this immediately and throws `BeanCurrentlyInCreationException`. The practical rule: if you see a circular dependency, the design usually has a problem. Refactor to break the cycle by extracting shared logic into a third bean, or use `@Lazy` on one of the dependencies as a short-term workaround.

*Lead with "three-level cache" by name — it's the specific mechanism interviewers are probing for.*

> **Gotcha follow-up:** Does `@Lazy` actually fix a circular dependency, or just defer the problem?
> `@Lazy` on an `@Autowired` injection point tells Spring to inject a proxy immediately (which involves no creation of the real bean) and defer actual creation until the first method is called on the proxy. This breaks the circular dependency at startup because neither bean needs the other to be fully created during its own construction. However, the circular call can still occur at runtime if both beans call each other in the same thread — you just moved the potential problem from startup to runtime. It is a valid workaround for circular dependencies that are "logically non-circular" (A's initialization does not actually call B and vice versa), but the cleaner solution is to redesign to remove the cycle.

---

**Q9: What does `@Configuration` with CGLIB do, and how does it differ from `@Component`?**
*Concept Check*

**One-line answer:** `@Configuration` classes are CGLIB-subclassed so that `@Bean` method calls within the class return the container's singleton instead of creating a new instance; `@Component` (and `proxyBeanMethods=false`) makes them plain Java calls that always create new instances.

**Full answer:**
When Spring detects a class annotated with `@Configuration`, it creates a CGLIB subclass of it at startup. Every `@Bean` method in that subclass is overridden. The override checks the Spring container first: if the singleton for that bean type already exists, return it; if not, create it, register it, and return it. This means that if `beanA()` internally calls `this.beanB()` to set up a dependency, the CGLIB proxy intercepts that call and returns the container's singleton `beanB` rather than executing the `beanB()` method body a second time. The result is that inter-`@Bean` method calls respect singleton semantics, which is what you almost always want. A class annotated with `@Component` (or with `@Configuration(proxyBeanMethods=false)`) is not CGLIB-subclassed. If a `@Bean` method in such a class calls another `@Bean` method, it is a plain Java method call — the overridden method body runs again and produces a new object each time. This can lead to subtle bugs where two beans share what looks like the same configuration object but are actually separate instances. Use `@Configuration` when `@Bean` methods in the class reference each other. Use `proxyBeanMethods=false` for independent factory methods — it avoids CGLIB overhead and speeds up startup, which matters in large applications or serverless environments.

*The phrase "inter-bean method calls respect singleton semantics" is the core insight.*

> **Gotcha follow-up:** Is there a performance cost to CGLIB proxying in `@Configuration`?
> Yes, there is a small startup cost: Spring must generate and load a CGLIB subclass for every `@Configuration` class. At runtime, every `@Bean` method call also incurs the overhead of the proxy's interceptor checking the singleton cache. For most applications this is negligible. The reason `proxyBeanMethods=false` was introduced in Spring Boot 2.2 is to reduce startup time in applications with many configuration classes, particularly in AWS Lambda or GraalVM native image contexts where cold-start latency is critical. Spring Boot's own auto-configuration classes all use `proxyBeanMethods=false` because their `@Bean` methods are designed to be independent.

---

**Q10: What is the difference between `@Bean` and `@Component`?**
*Concept Check*

**One-line answer:** `@Component` marks a class you own for component-scan registration; `@Bean` is a method inside a `@Configuration` class that explicitly declares a bean — required for third-party classes you cannot annotate.

**Full answer:**
`@Component` (and its specializations `@Service`, `@Repository`, `@Controller`) is a class-level annotation that tells Spring's component scanning to discover the class, instantiate it, and register it as a bean. The requirement is that you must be able to modify the class to add the annotation. Spring creates the instance by calling a constructor, usually the one with `@Autowired` dependencies. `@Bean` is a method-level annotation placed inside a `@Configuration` class. The method's return value becomes a registered bean. You have full control over how the object is constructed — you can call any constructor, call builder methods, set properties, and conditionally configure the object based on environment or other beans. The critical use case for `@Bean` is third-party classes: if I need to register a Jackson `ObjectMapper`, a `RestTemplate`, or a `DataSource` from a connection pool library, those classes are not mine to annotate with `@Component`. I declare a `@Bean` method that constructs and configures them. The other use case is custom construction logic that is too complex for a single constructor — configuring a `RestTemplate` with custom interceptors, timeouts, and error handlers is cleaner as a `@Bean` method than in a constructor. In summary: `@Component` for your own classes with straightforward construction; `@Bean` for third-party classes or complex construction logic.

*The third-party library answer wins points immediately — it's the most practical motivation.*

> **Gotcha follow-up:** What is the difference between `@Service`, `@Repository`, and `@Controller` versus plain `@Component`?
> All three are meta-annotated with `@Component`, so component scanning picks them up identically. The differences are semantic and functional. `@Repository` additionally activates Spring's persistence exception translation — Spring wraps JDBC and JPA exceptions into its unified `DataAccessException` hierarchy, so your service layer catches `DataAccessException` rather than vendor-specific exceptions. `@Service` carries no extra behavior but communicates intent — this is business logic. `@Controller` (and `@RestController`) registers the class with Spring MVC's `DispatcherServlet` as a request handler. Prefer the specific annotation when it applies because it documents the role of the class and enables the relevant Spring features.

---

**Q11: When does Spring use JDK dynamic proxies versus CGLIB, and what are the limitations of each?**
*Concept Check*

**One-line answer:** JDK proxies require the target to implement an interface and only intercept interface methods; CGLIB subclasses the target so no interface is needed but cannot proxy final classes or methods — Spring Boot 2+ defaults to CGLIB.

**Full answer:**
Spring's AOP infrastructure works by wrapping beans in a proxy object that intercepts method calls and applies advice (transaction management, security checks, logging, etc.) before and after delegating to the real object. There are two proxy strategies. A JDK dynamic proxy implements the same interfaces as the target bean. All calls to the proxy go through an `InvocationHandler` which applies advice and forwards to the target. The limitation is hard: the target must implement at least one interface, and only interface methods are intercepted — concrete methods that exist only on the class are invisible to the proxy. CGLIB (Code Generation Library) generates a subclass of the target class at runtime, overriding every non-final method to insert the advice. No interface is required, making it applicable to any concrete class. The limitation: you cannot subclass a `final` class, and `final` methods cannot be overridden, so they are never intercepted — `@Transactional` on a `final` method silently does nothing, which is a dangerous footgun. Spring Boot 2.0 changed the default to always use CGLIB (controlled by `spring.aop.proxy-target-class=true`) because too many applications had beans without interfaces and the JDK proxy silently provided no proxying. I always keep the default and avoid `final` on any Spring-managed bean method.

*The "final method silently skips @Transactional" point is the most interview-relevant gotcha.*

> **Gotcha follow-up:** If your bean implements an interface, does Spring still use CGLIB in Spring Boot 2+?
> Yes. By default, `spring.aop.proxy-target-class=true` means Spring always generates a CGLIB subclass even for beans that implement interfaces. You can set `proxy-target-class=false` to restore the old behavior of using JDK proxies for interfaced beans, but there is rarely a reason to. The one edge case where you might want JDK proxies is if you need to serialize the proxy — CGLIB proxies cannot be serialized easily, while JDK proxies can. In modern Spring Boot applications that edge case almost never comes up.

---

**Q12: Why does `@Transactional` self-invocation fail, and what are the fixes?**
*Tradeoff Question*

**One-line answer:** Self-invocation bypasses the AOP proxy because `this` refers to the real object, not the proxy — the transaction advice never fires; fix by extracting the method, injecting self, or using AspectJ weaving.

**Full answer:**
Spring's `@Transactional` is implemented via an AOP proxy. When external code calls `orderService.placeOrder()`, the call arrives at the proxy first. The proxy starts a transaction, then delegates the call to the real `OrderService` object. So far, so good. But if `placeOrder()` internally calls `this.validate()`, the `this` keyword refers to the actual `OrderService` object — the one sitting behind the proxy. That call never passes through the proxy, so the transaction advice for `validate()` is never applied, even if `validate()` is annotated with `@Transactional(propagation = REQUIRES_NEW)`. The method runs, but without a transaction, which can lead to silent data corruption. There are three standard fixes. The cleanest is to extract `validate()` into a separate Spring bean — then `orderService.validate()` is a call through a proxy and the transaction advice fires. The second option is self-injection: add `@Autowired private OrderService self;` and call `self.validate()` — `self` holds the proxy. This works but looks odd and can cause circular dependency warnings. The third option is compile-time AspectJ weaving, which modifies the bytecode of the class directly so the transaction logic is baked into `this.validate()` itself, bypassing proxies entirely. I prefer extraction — it also improves single-responsibility.

*This is one of the top-3 most commonly asked Spring questions in senior interviews — be thorough.*

> **Gotcha follow-up:** Does `@Transactional` work on `private` methods?
> No. Spring's proxy-based AOP can only intercept public methods (and protected methods in CGLIB proxies, but that is not recommended). A `@Transactional` annotation on a `private` method is silently ignored — no transaction is created. This is another example of the proxy limitation: the proxy overrides methods of the class or interface, and private methods are not overridable. If you need transactional behavior on a private method, either make it package-private or protected and document why, or restructure so the transaction boundary is on a public method that calls the private one.

---

**Q13: How does Spring's event system work, and what is `@TransactionalEventListener` for?**
*Concept Check*

**One-line answer:** `publishEvent()` synchronously notifies all `@EventListener` beans of the same event type; `@TransactionalEventListener(phase=AFTER_COMMIT)` delays the listener until after the current transaction commits, preventing listeners from seeing rolled-back data.

**Full answer:**
Spring's event system is a built-in observer pattern that lets beans communicate without direct dependencies. A publisher autowires `ApplicationEventPublisher` and calls `publishEvent(new OrderPlacedEvent(order))`. Spring finds every bean with an `@EventListener` method whose parameter type matches `OrderPlacedEvent` or a supertype, and calls them. By default this is synchronous and happens in the same thread as the publisher — the `publishEvent()` call does not return until all listeners have run. To make listeners asynchronous, I add `@Async` on the listener method and `@EnableAsync` on a configuration class; Spring then submits each listener call to an executor thread pool and the publisher returns immediately. The critical concern with transactional systems is ordering: if `placeOrder()` publishes an `OrderPlacedEvent` inside a transaction, a regular `@EventListener` fires immediately — at that point the order row may not yet be committed. If the listener tries to query the order or send an email, it might read no data or reference a row that later gets rolled back. `@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)` queues the listener and fires it only after the transaction that published the event successfully commits. If the transaction rolls back, the listener never fires. This makes it safe to send emails or push notifications that reference the persisted data.

*The transactional ordering point is what separates a junior answer from a senior one.*

> **Gotcha follow-up:** What happens if `@TransactionalEventListener` is called outside a transaction?
> By default, a `@TransactionalEventListener` does nothing if there is no active transaction — the event is silently dropped. You can override this with `fallbackExecution = true`, which makes the listener execute immediately even when no transaction is active, behaving like a regular `@EventListener` in that case. The default drop behavior is usually correct for after-commit listeners because the logic "fire after commit" has no meaning outside a transaction, but `fallbackExecution = true` is useful in integration tests or batch jobs that do not run inside a transaction boundary.

---

**Q14: What are `@Conditional` annotations and how do they power auto-configuration?**
*Concept Check*

**One-line answer:** `@Conditional` annotations prevent bean registration unless a runtime condition is met — `@ConditionalOnClass`, `@ConditionalOnMissingBean`, `@ConditionalOnProperty` are the core ones that let Spring Boot provide smart defaults without overriding your choices.

**Full answer:**
`@Conditional` annotations attach conditions to bean definitions: the bean is only registered if the condition evaluates to true. Spring Boot's entire auto-configuration system is built on a family of these annotations. `@ConditionalOnClass(DataSource.class)` means "only register this bean if the DataSource class is on the classpath" — so `DataSourceAutoConfiguration` only fires if you have a JDBC driver in your dependencies. `@ConditionalOnMissingBean(DataSource.class)` means "only register this bean if no `DataSource` bean is already defined" — so if I define my own `DataSource`, Boot's auto-configuration steps back entirely. This is the key principle: auto-configuration is designed to be overridable. `@ConditionalOnProperty(name="feature.cache.enabled", havingValue="true", matchIfMissing=false)` ties a bean to a configuration property, making features togglable without code changes. `@ConditionalOnWebApplication` only activates in a servlet or reactive web context. For custom conditions, I implement the `Condition` interface — its `matches()` method receives a `ConditionContext` with access to the environment, classpath, and bean factory — and pass it to `@Conditional(MyCustomCondition.class)`. The practical effect is a configuration system that is both powerful out-of-the-box and non-intrusive.

*`@ConditionalOnMissingBean` is the most important one for explaining how auto-config "gets out of the way."*

> **Gotcha follow-up:** How would you debug why an auto-configuration class is not being applied?
> Run the application with `--debug` flag or set `logging.level.org.springframework.boot.autoconfigure=DEBUG`. Spring Boot prints a "CONDITIONS EVALUATION REPORT" at startup that lists every auto-configuration class, whether it was applied, and if not, which specific condition evaluation failed and why. This is the fastest way to diagnose "why is my DataSource not being configured" — the report tells you exactly which `@ConditionalOn*` check evaluated to false and what the evaluated value was.

---

**Q15: How does `@Profile` work, and how do you activate multiple profiles?**
*Concept Check*

**One-line answer:** `@Profile("name")` limits a bean or configuration class to active profiles; activate with `spring.profiles.active=dev,local`; `@Profile("!prod")` means "any profile except prod."

**Full answer:**
`@Profile` is a specialization of `@Conditional` that restricts bean registration to specific named environments. When I annotate a `@Configuration` class or an individual `@Bean` method with `@Profile("dev")`, Spring only registers those beans when the `dev` profile is active. The most common use case is swapping infrastructure beans: a `dev` profile uses an in-memory H2 `DataSource`, while a `prod` profile uses a HikariCP pool connected to PostgreSQL. Both configurations exist in the codebase; only the active profile's beans are registered. Profiles are activated via `spring.profiles.active=dev,local` in `application.properties`, as an environment variable `SPRING_PROFILES_ACTIVE=dev`, or as a command-line argument `--spring.profiles.active=dev`. Multiple profiles are comma-separated, and beans from all active profiles are registered. The negation syntax `@Profile("!prod")` means "register this bean in every profile except prod" — useful for beans that should exist in development and staging but must not exist in production. The `default` profile activates when no other profile is explicitly active, and beans annotated `@Profile("default")` serve as fallbacks. In testing, I use `@ActiveProfiles("test")` on the test class to activate a profile with test-specific beans like embedded databases and mock services.

*Always mention the negation syntax — it signals deeper familiarity than the basic use case.*

> **Gotcha follow-up:** What is the difference between `spring.profiles.active` and `spring.profiles.include`?
> `spring.profiles.active` replaces the active profile list — whatever you set is exactly what runs. `spring.profiles.include` adds to the active profiles unconditionally; even if a profile is not in `active`, any profile declared in `include` inside an `application-{profile}.properties` file is always added when that profile is active. It is used to compose profiles — for example, `application-dev.properties` might include `spring.profiles.include=local-db,mock-services` so that activating `dev` also automatically activates `local-db` and `mock-services` without the caller having to list all three. The key distinction is that `active` is a full replacement while `include` is additive composition.

---

**Common Mistakes — Section 1:**
- **Using field injection everywhere** → dependencies are hidden, classes are not testable without Spring, and `final` is impossible. Switch to constructor injection for required dependencies.
- **Assuming `@Transactional` on a private or final method works** → it is silently ignored. Annotate only public, non-final methods.
- **Injecting a prototype bean directly into a singleton** → the prototype becomes a singleton. Use `ObjectProvider` or `@Lookup`.
- **Using `BeanFactory` instead of `ApplicationContext`** → you lose eager startup validation, events, and automatic post-processor registration. Always use `ApplicationContext`.
- **Not understanding `@Configuration` CGLIB** → calling one `@Bean` method from another in a `@Component` class creates a new instance instead of the singleton. Use `@Configuration` when `@Bean` methods reference each other.

**Quick Revision — Section 1:** Spring's IoC container is a factory that creates, wires, and manages beans — understand how it resolves dependencies (type → qualifier → name), how it creates proxies (CGLIB subclass in `postProcessAfterInitialization`), and why `this.method()` bypasses the proxy.

---

## Section 2: Spring Boot

> *Reading guide: Focus on the auto-configuration mechanism and property resolution order — these underpin almost every Spring Boot interview question.*

---

**Q1: How does Spring Boot's auto-configuration mechanism work?**
*Concept Check*

**One-line answer:** Spring Boot reads a list of candidate auto-configuration classes from a file on the classpath, evaluates `@Conditional` annotations on each, and registers only the ones whose conditions pass — giving sensible defaults that step aside when you provide your own beans.

**Full answer:**
Spring Boot's auto-configuration is triggered by `@EnableAutoConfiguration`, which is included in `@SpringBootApplication`. At startup, Spring Boot reads from `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` (Boot 3) or `META-INF/spring.factories` (Boot 2). These files list hundreds of auto-configuration class names. Each class is annotated with conditions: `@ConditionalOnClass` checks whether a specific class is present on the classpath, `@ConditionalOnMissingBean` checks whether you have already defined a bean of that type, `@ConditionalOnProperty` checks a configuration property value. Spring evaluates each condition and registers only the configuration classes that pass. For example, `DataSourceAutoConfiguration` activates only if a JDBC driver class is on the classpath and no `DataSource` bean has been manually registered. The result is zero-configuration defaults that scale all the way from a simple demo to a production service: add `spring-boot-starter-data-jpa` and a database URL, and you get a fully configured `DataSource`, `EntityManagerFactory`, and `JpaTransactionManager` without writing a single bean definition. The override mechanism is equally important — defining your own `DataSource` bean causes `@ConditionalOnMissingBean` to fail and the auto-configured one is skipped entirely.

*The phrase "conditions pass → registered, otherwise skipped" is the mental model to lead with.*

> **Gotcha follow-up:** How would you create your own auto-configuration for a library you are publishing?
> I would create a `@Configuration` class annotated with `@AutoConfiguration` (Spring Boot 3) or `@Configuration` (Boot 2), add `@ConditionalOnClass`, `@ConditionalOnMissingBean`, and other conditions as appropriate, and register its fully qualified class name in `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`. Users of the library add it as a dependency, and Spring Boot automatically picks up and evaluates the auto-configuration — they get sensible defaults without any configuration, and they can override by defining their own beans. This is exactly how all Spring Boot starters work.

---

**Q2: What three annotations does `@SpringBootApplication` combine?**
*Concept Check*

**One-line answer:** `@Configuration` (declares this class as a bean source), `@EnableAutoConfiguration` (triggers auto-config scanning), and `@ComponentScan` (scans the current package and sub-packages for `@Component` beans).

**Full answer:**
`@SpringBootApplication` is a convenience meta-annotation that combines three annotations on the main class. `@Configuration` designates the class as a configuration source — you can add `@Bean` methods to it and they will be registered. `@EnableAutoConfiguration` activates Spring Boot's auto-configuration mechanism, instructing Spring to read the auto-configuration imports file and apply the relevant configuration classes based on the classpath and your definitions. `@ComponentScan` tells Spring to scan the package containing the main class and all its sub-packages for classes annotated with `@Component`, `@Service`, `@Repository`, `@Controller`, etc., and register them as beans. This is why the main class must be placed in the root package of your application — if it is too deep, `@ComponentScan` will miss beans in sibling packages. You can customize the scan: `@ComponentScan(basePackages = "com.example")` or `@ComponentScan(basePackageClasses = MyMarker.class)`. The annotation also accepts `exclude` and `excludeName` attributes to exclude specific auto-configuration classes when you need to prevent a default from activating.

*Knowing the package placement rule (main class in root package) is a practical detail interviewers probe for.*

> **Gotcha follow-up:** Can you use `@SpringBootApplication` on a class that is not the main class?
> Technically yes — the annotation is just a combination of three other annotations and Spring does not enforce that it is on the entry point. However, it would be unconventional and confusing. More relevantly, `@ComponentScan` scans from the annotated class's package, so if you put it on a class in a sub-package, you would miss beans in sibling packages. The idiomatic pattern is one `@SpringBootApplication` on the class with `main(String[] args)` in the root package, and nothing else uses this annotation in the project.

---

**Q3: What is the purpose of Spring Boot starter POMs?**
*Concept Check*

**One-line answer:** Starters are curated dependency sets with compatible versions managed by Spring Boot's BOM — you add one dependency and get a complete, tested stack instead of manually selecting and aligning dozens of individual libraries.

**Full answer:**
A Spring Boot starter is a Maven or Gradle dependency that pulls in a pre-selected set of transitive dependencies, all at versions that Spring Boot has tested to work together. For example, `spring-boot-starter-web` brings in `spring-webmvc`, `spring-context`, `spring-beans`, `tomcat-embed-core`, `jackson-databind`, `jackson-datatype-jsr310`, `hibernate-validator`, and more. Without starters, I would need to know which version of Jackson is compatible with which version of Spring MVC and which version of Tomcat. The Spring Boot Bill of Materials (BOM) centralizes all version declarations — any dependency managed by the BOM does not need a version specified in your `pom.xml`; Spring Boot guarantees compatibility. Starters also serve as a documentation artifact: `spring-boot-starter-data-jpa` tells a developer exactly what technology stack is in use for data access without reading the full dependency tree. The naming convention is `spring-boot-starter-{feature}` for official starters and `{name}-spring-boot-starter` for community starters. When troubleshooting dependency conflicts, running `mvn dependency:tree` or `gradle dependencies` shows the full tree; overriding a version in the BOM is done with `<properties><spring-framework.version>...</spring-framework.version></properties>` in Maven.

*The BOM (Bill of Materials) mechanism is the key technical detail behind "compatible versions."*

> **Gotcha follow-up:** What is the difference between `spring-boot-starter-web` and `spring-boot-starter-webflux`?
> `spring-boot-starter-web` includes Spring MVC and embedded Tomcat — this is the traditional synchronous, thread-per-request servlet model. `spring-boot-starter-webflux` includes Spring WebFlux and Netty — this is the reactive, non-blocking model built on Project Reactor. Having both on the classpath at the same time creates ambiguity; Spring Boot will default to the servlet stack unless you explicitly set `spring.main.web-application-type=reactive`. If you need reactive data access in a web application (e.g., R2DBC for reactive database access), you should use `webflux`, not `web`. The thread model, programming paradigm, and testing approach are fundamentally different.

---

**Q4: What are the key Spring Boot Actuator endpoints and what do they expose?**
*Concept Check*

**One-line answer:** Actuator exposes production-ready HTTP endpoints — `/health` for liveness/readiness probes, `/metrics` for performance data, `/env` for configuration, `/beans` for the bean registry, `/mappings` for URL routing, and `/loggers` for runtime log-level changes.

**Full answer:**
Spring Boot Actuator adds a set of built-in management endpoints to any application by adding `spring-boot-starter-actuator`. Each endpoint answers a specific operational question. `/actuator/health` returns the application health status (`UP` or `DOWN`) and optionally sub-component details — database connectivity, disk space, external service ping. Kubernetes readiness and liveness probes point here. `/actuator/metrics` exposes all Micrometer metrics: JVM heap and GC statistics, thread counts, HTTP request rates, error rates, and any custom metrics you register with `MeterRegistry`. `/actuator/env` shows all active property sources and their current values, with sensitive values like passwords masked. `/actuator/beans` lists every Spring bean, its type, scope, and dependencies — invaluable for debugging unexpected bean registration. `/actuator/mappings` maps every URL pattern to its handler method, showing you exactly which controller method handles each route. `/actuator/loggers` lets you view and change log levels dynamically at runtime with an HTTP POST, without restarting — incredibly useful in production incidents when you need `DEBUG` logging on a specific package. By default only `/health` and `/info` are exposed over HTTP; expose all with `management.endpoints.web.exposure.include=*`. Always restrict actuator access in production behind a firewall or authentication — these endpoints leak internal architecture.

*The security warning at the end signals operational awareness beyond just knowing the endpoints.*

> **Gotcha follow-up:** How do Kubernetes liveness and readiness probes use Actuator?
> Kubernetes liveness probe: if this check fails, Kubernetes restarts the pod. Point it at `/actuator/health/liveness` — this should only return `DOWN` if the application is in a broken, unrecoverable state. Readiness probe: if this check fails, Kubernetes stops routing traffic to the pod but does not restart it. Point it at `/actuator/health/readiness` — this should return `DOWN` during startup (before the context is fully loaded), during graceful shutdown (after receiving SIGTERM), or if a downstream dependency like a database is unavailable. Spring Boot 2.3+ provides separate liveness and readiness health indicator groups out of the box. The key distinction: liveness failure = restart the pod; readiness failure = stop sending traffic but keep the pod running.

---

**Q5: What is the Spring Boot externalized configuration priority order?**
*Concept Check*

**One-line answer:** Command-line args beat environment variables beat profile-specific properties files beat `application.properties` beat `@PropertySource` — later sources override earlier ones when properties conflict.

**Full answer:**
Spring Boot resolves properties from many sources and merges them with a defined priority. From highest priority (wins) to lowest: (1) command-line arguments like `--server.port=9090` override everything else; (2) `SPRING_APPLICATION_JSON` — an environment variable containing a JSON string of properties; (3) OS environment variables like `SPRING_DATASOURCE_URL` (Spring maps `_` to `.` and lowercases to allow `spring.datasource.url`); (4) `application-{profile}.properties` located outside the JAR (in the `./config/` directory or working directory); (5) `application.properties` outside the JAR; (6) `application-{profile}.properties` inside the JAR; (7) `application.properties` inside the JAR; (8) `@PropertySource` annotations on configuration classes; (9) `SpringApplication.setDefaultProperties()` as the lowest priority. The practical implication is that I can deploy one JAR to multiple environments by passing database URLs and secrets as environment variables — no repackaging, no Dockerfile changes, just environment variable injection. In Kubernetes, ConfigMaps and Secrets are mounted as environment variables or files outside the JAR and naturally take priority over the bundled `application.properties`.

*The "deploy one JAR everywhere, configure via env vars" implication is what interviewers care about.*

> **Gotcha follow-up:** What is relaxed binding in Spring Boot?
> Relaxed binding means that `spring.datasource.url`, `SPRING_DATASOURCE_URL`, `spring.datasource-url`, and `spring.datasource_url` all resolve to the same property. Spring Boot normalizes property names at binding time, stripping hyphens, underscores, and case differences. This matters for environment variables: OS shells do not allow dots in variable names, so `SPRING_DATASOURCE_URL` is the idiomatic form for `spring.datasource.url`. Relaxed binding also applies to `@ConfigurationProperties` POJO fields: a property declared as `myServerHost` can be set via `my-server-host`, `MY_SERVER_HOST`, or `my_server_host` and all resolve correctly.

---

**Q6: What is the difference between `@ConfigurationProperties` and `@Value`?**
*Tradeoff Question*

**One-line answer:** `@ConfigurationProperties` binds an entire property group to a typed, validatable POJO with relaxed binding and IDE completion; `@Value` injects one property with SpEL support but is brittle and scattered for multi-property configs.

**Full answer:**
`@ConfigurationProperties(prefix = "app.mail")` binds all properties under the `app.mail.*` namespace to fields of an annotated POJO class. The binding is type-safe — a `List<String>` field receives a list, a `Duration` field parses `10s` or `PT10S`, an `Integer` field parses a number and fails loudly if the value cannot be converted. Adding `@Validated` to the class enables JSR-303 bean validation on the properties, so `@NotNull`, `@Min`, `@Max` constraints fail at startup if properties are invalid. IDEs generate autocompletion metadata from the `spring-boot-configuration-processor` annotation processor, so properties.files show docs and validation. `@Value("${app.mail.host}")` injects a single property directly into a field. It supports Spring Expression Language, so `@Value("#{T(Math).PI}")` evaluates Java expressions. However, for a configuration class with 10 properties, 10 `@Value` annotations are scattered across the class, hard to document, impossible to validate as a group, and fragile if property names change. SpEL expressions in `@Value` are also difficult to test. The rule I follow: `@ConfigurationProperties` for any structured configuration group; `@Value` only for single standalone values or when SpEL evaluation is genuinely needed.

*Lead with "type-safe" and "group validation" — those are the most concrete advantages.*

> **Gotcha follow-up:** Do you need to annotate a `@ConfigurationProperties` class with `@Component`?
> Not necessarily. If the class is annotated with `@Component`, Spring will pick it up during component scan, create an instance, and bind properties to it. Alternatively, you can annotate a `@Configuration` class with `@EnableConfigurationProperties(MyProps.class)` — this registers `MyProps` as a bean without it needing `@Component`. In Spring Boot 2.2+, you can add `@ConfigurationPropertiesScan` to your main class to automatically discover all `@ConfigurationProperties` classes in the package tree without annotating each with `@Component`. The most common modern pattern is to use `@ConfigurationPropertiesScan` and drop `@Component` from the properties classes.

---

**Q7: How does Spring Boot's embedded server work?**
*Concept Check*

**One-line answer:** `spring-boot-starter-web` includes `tomcat-embed-core`; Spring Boot's auto-configuration programmatically creates a `TomcatServletWebServerFactory`, starts a Tomcat instance inside the JVM, registers `DispatcherServlet`, and begins accepting HTTP connections — no WAR, no `web.xml`, no external server required.

**Full answer:**
The traditional Java web deployment model required packaging the application as a WAR file and deploying it to an external servlet container like Tomcat or Jetty, which managed the JVM and application lifecycle. Spring Boot inverts this: the servlet container is a library, embedded inside a self-contained executable JAR. When Spring Boot auto-configuration detects `tomcat-embed-core` on the classpath (brought in by `spring-boot-starter-web`), it activates `TomcatServletWebServerFactory`, which is a `ServletWebServerFactory` bean. This factory programmatically creates a `Tomcat` instance, sets the listening port, configures connector settings, registers the `DispatcherServlet` as the front controller, applies any `Filter` and `Servlet` beans registered in the context, and calls `tomcat.start()`. All of this happens inside `SpringApplication.run()` before it returns. The result is that `java -jar myapp.jar` starts a fully operational HTTP server. You can switch the embedded server by excluding `spring-boot-starter-tomcat` and adding `spring-boot-starter-jetty` or `spring-boot-starter-undertow` — the `ServletWebServerFactory` contract abstracts the choice. Customization is via `ServerProperties` (`server.port`, `server.ssl.*`, `server.compression.*`) or by registering a `WebServerFactoryCustomizer<TomcatServletWebServerFactory>` bean for Tomcat-specific settings.

*"The servlet container is a library" is the key framing — it inverts the traditional deployment mental model.*

> **Gotcha follow-up:** How do you deploy a Spring Boot application to an external application server?
> Extend `SpringBootServletInitializer` and override `configure()` to register the application. Change the packaging from `jar` to `war` in `pom.xml`. Exclude the embedded Tomcat starter with `<scope>provided</scope>` so it is on the classpath at compile time but not bundled. Build with `mvn package` — the resulting WAR can be dropped into Tomcat's `webapps/` directory. This pattern is useful when the organization mandates an external application server for operational reasons (central management, shared SSL termination, existing infrastructure). The downsides are complexity (two deployment models to test), coupling to a specific server's configuration, and slower deployment cycles.

---

**Q8: What are the key changes in Spring Boot 3?**
*Concept Check*

**One-line answer:** Java 17 minimum, `javax.*` → `jakarta.*` namespace migration, first-class GraalVM native image support, Micrometer Tracing for observability, and auto-configuration registration moved from `spring.factories` to `AutoConfiguration.imports`.

**Full answer:**
Spring Boot 3, released in November 2022, is the most breaking upgrade since Boot 1. Java 17 is the minimum — Boot 3 uses Java 17 language features internally and aligns with the Jakarta EE 10 specification. The most disruptive change is the namespace migration from `javax.*` to `jakarta.*`: every import of `javax.servlet.*`, `javax.persistence.*`, `javax.validation.*`, `javax.transaction.*` must be updated to the `jakarta.*` equivalent. This affects every entity class, servlet filter, constraint annotation, and JAX-RS resource — automated migration tools exist (`javax-to-jakarta` and IntelliJ's migration assistant) but manual verification is still needed. GraalVM native image compilation is now a first-class, supported feature: running `mvn -Pnative package` compiles the application to a native binary with startup times of under 100 milliseconds and memory footprints 50-70% lower than a JVM deployment — critical for AWS Lambda, Kubernetes sidecars, and CLI tools. The native compilation performs ahead-of-time analysis and requires explicit hints for reflection usage, which Spring handles for its own code but third-party libraries may need manual `reflect-config.json` entries. Observability is unified via Micrometer Tracing (replacing Spring Cloud Sleuth), providing distributed tracing with Zipkin and OpenTelemetry exporters. Auto-configuration registration moved from `META-INF/spring.factories` to `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` for type safety and performance.

*The `javax` → `jakarta` migration is the most practically painful — always mention it first.*

> **Gotcha follow-up:** What are the challenges of GraalVM native image compilation with Spring?
> GraalVM's native compilation performs a closed-world analysis — it traces all code paths reachable from `main()` and compiles only those. Dynamic features like reflection, proxies, and classpath scanning that Spring relies on heavily are problems: if a class is loaded reflectively at runtime but not seen during analysis, it is excluded and throws an exception at runtime. Spring Boot 3's ahead-of-time (AOT) processing phase runs at build time, analyzes the Spring context, generates source files that explicitly register all beans and their types for reflection, and produces `reflect-config.json` for GraalVM. Spring itself is fully supported, but third-party libraries that use reflection internally (some Hibernate features, certain serialization libraries) may need manual `@RegisterReflectionForBinding` hints or `reflect-config.json` entries. The native build also takes several minutes compared to seconds for a JAR — it is a build-time trade-off for faster runtime.

---

**Q9: What is graceful shutdown in Spring Boot and why does it matter for Kubernetes?**
*Concept Check*

**One-line answer:** Graceful shutdown (`server.shutdown=graceful`) stops accepting new requests on SIGTERM while allowing in-flight requests to complete, preventing Kubernetes rolling deployments from dropping requests mid-flight.

**Full answer:**
Without graceful shutdown, when Kubernetes sends a SIGTERM signal to a pod being replaced during a rolling deployment, the application process terminates immediately. Any HTTP request that was in the middle of processing — perhaps executing a database write or calling an external service — receives a connection reset. The client gets an error, potentially corrupting data or causing a failed user-facing transaction. Graceful shutdown addresses this. Setting `server.shutdown=graceful` changes the shutdown behavior: on SIGTERM, the embedded Tomcat (or Jetty/Undertow) stops accepting new incoming connections immediately, but all threads currently processing requests are allowed to run to completion. `spring.lifecycle.timeout-per-shutdown-phase=30s` sets the maximum time Spring waits for in-flight requests before forcibly shutting down — preventing a hung request from blocking the shutdown indefinitely. The Kubernetes integration works because Kubernetes sends SIGTERM, then waits for `terminationGracePeriodSeconds` (default 30 seconds) before sending SIGKILL. During that window, the load balancer removes the pod from rotation (it stops receiving new traffic), and graceful shutdown lets existing requests finish. This requires that `terminationGracePeriodSeconds` in the pod spec is longer than `timeout-per-shutdown-phase` to avoid a race where Kubernetes kills the pod before Spring finishes.

*The Kubernetes timing interaction (terminationGracePeriodSeconds > timeout-per-shutdown-phase) is the detail that shows real operational experience.*

> **Gotcha follow-up:** What happens to background tasks or scheduled jobs during graceful shutdown?
> Graceful shutdown stops the HTTP server from accepting new requests, but Spring's `@Scheduled` tasks and `TaskExecutor` thread pools are shut down through the `SmartLifecycle` interface separately. Spring shuts down lifecycle beans in reverse dependency order. By default, the task executor waits for running tasks to complete up to the configured timeout. If a scheduled job is running when shutdown is triggered, Spring waits for it to finish before completing the shutdown phase. Long-running jobs can delay shutdown past the Kubernetes grace period, causing SIGKILL to interrupt them. For long-running batch jobs, explicitly call `executor.setWaitForTasksToCompleteOnShutdown(true)` and `executor.setAwaitTerminationSeconds(...)` on the `ThreadPoolTaskExecutor` bean.

---

**Q10: How do you customize the Spring Boot startup banner?**
*Concept Check*

**One-line answer:** Place a `banner.txt` in `src/main/resources/` to replace the default banner; disable with `spring.main.banner-mode=off`; use `${spring-boot.version}` placeholders for dynamic content.

**Full answer:**
Spring Boot prints an ASCII art banner to standard output at startup. To customize it, I create `src/main/resources/banner.txt` with any ASCII art or text. Spring Boot supports placeholder expressions inside the file: `${spring-boot.version}` inserts the Boot version, `${application.version}` reads `Implementation-Version` from `MANIFEST.MF` (populated when you build with the Maven or Gradle Spring Boot plugin), `${application.title}` reads `Implementation-Title`. Color ANSI codes work in terminals that support them — `${AnsiColor.BRIGHT_BLUE}` and `${AnsiStyle.BOLD}` wrap sections. Spring Boot also supports `banner.gif`, `banner.jpg`, or `banner.png` — it converts the image to ASCII art at startup, though this is mostly a novelty. For production environments, disable the banner with `spring.main.banner-mode=off` in `application.properties` to keep startup logs clean and reduce noise in log aggregation systems. Alternatively, `spring.main.banner-mode=log` sends the banner to the log output instead of stdout. Programmatic control: call `SpringApplication.setBanner(new ResourceBanner(resource))` before `run()` if the banner content is dynamic.

*The `banner-mode=off` production recommendation shows operational sensibility.*

> **Gotcha follow-up:** Is there any functional reason to customize the banner beyond aesthetics?
> The banner is purely cosmetic — it has no impact on application behavior, performance, or configuration. The main practical use is embedding version information (`${application.version}`) so that when reading startup logs in a log aggregation tool, you can immediately see which version of the application is running without searching through log lines for the version string. Some teams embed a build timestamp or git commit hash in the banner for the same reason. For most applications, turning it off in production is the right call.

---

**Common Mistakes — Section 2:**
- **Forgetting `javax` → `jakarta` when migrating to Boot 3** → causes `ClassNotFoundException` at runtime for every servlet, entity, and validation annotation. Use the IntelliJ migration assistant and run a full test suite.
- **Exposing all Actuator endpoints in production without authentication** → exposes configuration values, bean internals, and environment secrets. Always configure `management.endpoints.web.exposure.include` conservatively and require authentication.
- **Not setting `server.shutdown=graceful` in Kubernetes** → rolling deployments drop in-flight requests. Add the property and ensure `terminationGracePeriodSeconds` exceeds the shutdown timeout.
- **Placing the main class in a sub-package** → `@ComponentScan` misses sibling packages. Put the main class in the root package of your application.
- **Using `@Value` for groups of related properties** → scattered, unvalidated, brittle. Use `@ConfigurationProperties` with `@Validated`.

**Quick Revision — Section 2:** Spring Boot = auto-configuration (conditions + importers) + starters (curated compatible deps) + opinionated defaults (all overridable) + production tooling (Actuator) + embedded server — understand the override mechanism and you understand Spring Boot.

---

## Section 3: Spring Data JPA

> *Reading guide: Focus on the persistence context lifecycle, the N+1 problem and its fixes, and transaction propagation — these appear in nearly every senior Java interview.*

---

**Q1: What are the four JPA entity lifecycle states?**
*Concept Check*

**One-line answer:** Transient (unknown to JPA, no DB row), Managed/Persistent (tracked by EntityManager, auto-synced to DB), Detached (previously managed, changes not tracked), Removed (marked for deletion at next flush).

**Full answer:**
The JPA persistence context, managed by the `EntityManager`, tracks entity objects and their state relative to the database. Understanding these four states prevents a large class of "my changes did not save" and "unexpected update" bugs. A **transient** entity is one that has been created with `new User()` but has never been associated with an `EntityManager`. It has no database row and JPA is completely unaware of it. When I call `entityManager.persist(user)`, it transitions from transient to **managed** (also called persistent). A managed entity is inside the persistence context: any change to its fields is automatically detected — this is called dirty checking — and will be written to the database the next time the persistence context is flushed (typically just before a transaction commits). The key implication is that I do not need to call `save()` again after modifying a managed entity; the change is automatic. When the `EntityManager` is closed — typically when a transaction ends — all managed entities transition to **detached**. Detached entities still represent a row in the database, but changes to them are no longer tracked. Calling `entityManager.merge(detachedUser)` creates a new managed copy of the detached entity and schedules the changes for synchronization. The **removed** state is entered by calling `entityManager.remove(managedEntity)`. The entity is scheduled for deletion and a `DELETE` SQL statement will be issued at the next flush.

*Always anchor the states to what SQL happens: persist → INSERT scheduled, dirty checking → UPDATE scheduled, remove → DELETE scheduled.*

| State | How to enter | JPA tracks changes? | DB row exists? |
|-------|-------------|---------------------|----------------|
| Transient | `new Entity()` | No | No |
| Managed | `persist()`, `find()`, `merge()`, query result | **Yes** | Yes |
| Detached | Transaction/EM close, `detach()` | No | Yes |
| Removed | `remove()` on managed entity | No (deleted) | Pending DELETE |

> **Gotcha follow-up:** What is the difference between `merge()` and `persist()`?
> `persist()` is for transient (new) entities — it registers the entity with the persistence context and schedules an INSERT. Calling `persist()` on a detached entity throws an `EntityExistsException`. `merge()` is for detached entities — it copies the state of the detached entity into a new managed instance (or an existing one with the same ID if already in the context) and returns the managed instance. Critically, `merge()` returns the managed copy; the original detached entity remains detached. A common mistake is calling `merge(detached)` and then continuing to modify `detached` expecting the changes to persist — you must use the returned managed instance instead.

---

**Q2: What is the N+1 problem and how do you fix it?**
*Tradeoff Question*

**One-line answer:** Loading N entities and then lazily accessing an association on each triggers N additional SELECTs (1 for the list + N for the associations) — fix with JOIN FETCH, `@EntityGraph`, `@BatchSize`, or `@Fetch(SUBSELECT)`.

**Full answer:**
The N+1 problem is the most common JPA performance issue and one of the most reliable interview topics. Consider loading a list of 100 `Order` entities. Then, in a loop or during JSON serialization, you access `order.getCustomer()` for each one. If `customer` is lazily loaded (the default for `@ManyToOne` in practice after overriding the default), each access triggers a separate `SELECT * FROM customer WHERE id = ?` — 100 additional queries on top of the original 1 query for orders. Total: 101 queries instead of 1. The fix depends on the use case. For JPQL queries, `JOIN FETCH` loads the association in the same SQL statement: `SELECT o FROM Order o JOIN FETCH o.customer` generates a single SQL `JOIN`. For repository methods, `@EntityGraph(attributePaths = {"customer"})` on the method achieves the same effect declaratively without writing JPQL. For collection associations (`@OneToMany`), `@BatchSize(size = 25)` on the collection tells Hibernate to load lazy children in batches — instead of one SELECT per parent, it issues `SELECT * FROM order_item WHERE order_id IN (?, ?, ..., ?)` with 25 IDs at a time, reducing 100 queries to 4. `@Fetch(FetchMode.SUBSELECT)` is even more aggressive: it loads all children in one query using a subselect. I always use `JOIN FETCH` or `@EntityGraph` for predictable one-to-one and many-to-one cases, and `@BatchSize` for collections.

*Being able to write the SQL that each solution generates is what distinguishes a senior answer.*

> **Gotcha follow-up:** Does `JOIN FETCH` work with `Pageable` (pagination)?
> Attempting `JOIN FETCH` on a collection (`@OneToMany`) with `Pageable` causes Hibernate to issue a `HibernateJpaDialect` warning and load everything into memory before paginating in Java — it cannot apply SQL `LIMIT`/`OFFSET` to a JOIN-fetched collection correctly because the rows are multiplied by the collection size. Hibernate logs "HHH90003004: firstResult/maxResults specified with collection fetch; applying in memory." For paginated queries with collections, use either `@BatchSize` (paginate the parent query and load children in batches) or a two-query approach: paginate the IDs with one query, then fetch the full entities with `JOIN FETCH` using `WHERE id IN :ids`. `JOIN FETCH` with pagination works safely for `@ManyToOne` and `@OneToOne` because those do not multiply rows.

---

**Q3: What are the default fetch types for each JPA relationship annotation, and what is best practice?**
*Concept Check*

**One-line answer:** `@ManyToOne` and `@OneToOne` default to EAGER; `@OneToMany` and `@ManyToMany` default to LAZY — best practice is to override all to LAZY and fetch eagerly explicitly with `JOIN FETCH` or `@EntityGraph` only when needed.

**Full answer:**
The JPA specification defines default fetch types for each relationship type, and they are a frequent source of performance problems. `@ManyToOne` defaults to `FetchType.EAGER` — when you load an `Order`, JPA automatically issues a JOIN or a second SELECT to load the related `Customer`. The JPA spec assumed this was low-cost (one related object), but in practice it causes unintended queries throughout the application, especially when you are loading a list of orders and do not need customer data at all. `@OneToOne` also defaults to EAGER for the same reason. `@OneToMany` and `@ManyToMany` default to `FetchType.LAZY` — the spec recognized that a collection could be large. The best practice universally recommended by Hibernate's lead developer (Vlad Mihalcea) and by the Hibernate documentation is to override `@ManyToOne` and `@OneToOne` to `FetchType.LAZY` everywhere and only fetch eagerly when you explicitly need the association, using `JOIN FETCH` in JPQL or `@EntityGraph` on the repository method. This makes every query predictable — no hidden JOINs or extra SELECTs happen unless you request them. The annotation syntax: `@ManyToOne(fetch = FetchType.LAZY)`. With Hibernate as the provider, LAZY on `@OneToOne` on the non-owning side requires extra configuration (the `@LazyToOne` annotation or bytecode enhancement) due to how proxy creation works.

*The recommendation to override `@ManyToOne` to LAZY is the key differentiator from a textbook answer.*

> **Gotcha follow-up:** What is a `LazyInitializationException` and when does it occur?**
> A `LazyInitializationException` occurs when you try to access a lazily-loaded association on a detached entity — i.e., after the `EntityManager` (and its transaction) has been closed. For example, if a service method loads an `Order` in a transaction, returns the entity to the controller, and the controller tries to access `order.getItems()`, the transaction is already closed and Hibernate cannot issue the SELECT. The fix is to load all needed data within the transaction boundary (using `JOIN FETCH` or `@EntityGraph`) before returning from the service layer. Disabling OSIV (`spring.jpa.open-in-view=false`) makes this exception surface immediately in development, which is why disabling OSIV is the right practice — it forces you to load everything explicitly and prevents hidden queries in controllers and views.

---

**Q4: What are all seven `@Transactional` propagation levels and when do you use each?**
*Concept Check*

**One-line answer:** `REQUIRED` (default, join or create), `REQUIRES_NEW` (always new, independent commit), `SUPPORTS` (join if exists), `NOT_SUPPORTED` (suspend), `MANDATORY` (must exist or throw), `NEVER` (must not exist or throw), `NESTED` (savepoint inside outer).

**Full answer:**
Transaction propagation controls how a `@Transactional` method behaves when called from within an existing transaction or without one. `REQUIRED` is the default for over 95% of service methods: join the caller's transaction if one exists, or start a new one if not. The entire logical unit of work shares one transaction and commits or rolls back together. `REQUIRES_NEW` always suspends any existing transaction and starts a completely independent new one. The new transaction commits or rolls back independently of the outer one. The canonical use case is audit logging: even if the business transaction rolls back, the audit log entry must be committed. `SUPPORTS` joins an existing transaction if present, but runs without one if not — appropriate for read methods that work correctly either way. `NOT_SUPPORTED` suspends any existing transaction and runs entirely without one — use for non-transactional work that must not participate in a transaction (some stored procedure calls, legacy JDBC operations). `MANDATORY` throws `IllegalTransactionStateException` if no transaction exists — a contract enforcement mechanism that says "this method must always be called from within a transaction." Useful on data access methods in strict architectures. `NEVER` is the opposite: throws if a transaction does exist. `NESTED` uses a JDBC savepoint within the existing transaction. If the nested portion rolls back, it rolls back to the savepoint, not the entire outer transaction. The outer transaction can still commit. This is different from `REQUIRES_NEW` because the nested transaction shares the outer transaction's connection and will be rolled back if the outer transaction rolls back.

*`REQUIRES_NEW` vs `NESTED` is a classic interview follow-up — know the difference cold.*

| Propagation | No TX exists | TX exists |
|-------------|-------------|-----------|
| `REQUIRED` | Create new | Join it |
| `REQUIRES_NEW` | Create new | Suspend outer, create new |
| `SUPPORTS` | Run without TX | Join it |
| `NOT_SUPPORTED` | Run without TX | Suspend outer, run without TX |
| `MANDATORY` | Throw | Join it |
| `NEVER` | Run without TX | Throw |
| `NESTED` | Create new | Create savepoint in existing |

> **Gotcha follow-up:** What is the difference between `REQUIRES_NEW` and `NESTED` in terms of rollback behavior?
> With `REQUIRES_NEW`, the new transaction is completely independent — it has its own connection, its own commit, and its own rollback. If the outer transaction rolls back after the inner one has committed, the inner transaction's changes are already committed and will not be rolled back. With `NESTED`, the nested transaction is a savepoint within the outer transaction. If the nested portion fails and rolls back to the savepoint, the outer transaction can continue and commit. But if the outer transaction rolls back, the nested transaction's changes are rolled back too because they were part of the same underlying JDBC connection and transaction. `REQUIRES_NEW` = independent isolation; `NESTED` = partial rollback capability within one transaction.

---

**Q5: What are the four transaction isolation levels and what anomalies do they prevent?**
*Concept Check*

**One-line answer:** `READ_UNCOMMITTED` (dirty reads allowed), `READ_COMMITTED` (no dirty reads), `REPEATABLE_READ` (no non-repeatable reads), `SERIALIZABLE` (no phantom reads) — choose based on consistency needs vs. lock contention tradeoff.

**Full answer:**
Isolation levels control how much a transaction can see from other concurrent transactions before they commit. The tradeoff is consistency versus concurrency: higher isolation means stronger consistency guarantees but more locking and lower throughput. `READ_UNCOMMITTED` allows a transaction to read changes that another transaction has made but not yet committed — called dirty reads. If the other transaction rolls back, you have read data that was never real. Almost never used in production. `READ_COMMITTED`, the default for PostgreSQL and SQL Server, prevents dirty reads by only showing committed data. However, if you read the same row twice in one transaction, another transaction might have committed a change between the reads — a non-repeatable read. `REPEATABLE_READ`, the default for MySQL InnoDB, guarantees that reading the same row twice within a transaction gives the same result — no non-repeatable reads. Another transaction cannot modify a row that was read. However, another transaction can INSERT new rows that match a range query — a phantom read. `SERIALIZABLE` is the highest level: transactions execute as if they were serial (one after another), preventing all three anomalies. Implemented via range locks or predicate locks. It has the highest contention and lowest throughput. Set per-method: `@Transactional(isolation = Isolation.READ_COMMITTED)`. Most applications run on `READ_COMMITTED` and accept the theoretical risk of non-repeatable reads — for critical financial operations, `REPEATABLE_READ` or optimistic locking is a better choice than `SERIALIZABLE`.

*Connecting each level to the specific anomaly it prevents is what separates a thorough answer from a definition list.*

| Level | Dirty Read | Non-Repeatable Read | Phantom Read |
|-------|-----------|--------------------|-|
| `READ_UNCOMMITTED` | Possible | Possible | Possible |
| `READ_COMMITTED` | Prevented | Possible | Possible |
| `REPEATABLE_READ` | Prevented | Prevented | Possible |
| `SERIALIZABLE` | Prevented | Prevented | Prevented |

> **Gotcha follow-up:** How does Hibernate's first-level cache interact with isolation levels?
> Hibernate's first-level cache (the persistence context) is per-session and caches loaded entities for the duration of the transaction. If you call `find(Order.class, 1L)` twice in the same session, the second call returns the cached instance without hitting the database — even at `READ_COMMITTED`. This means Hibernate provides REPEATABLE_READ semantics for entities already in the first-level cache regardless of the database isolation level. However, this also means that if another transaction modifies a row after you loaded it, you will not see the change even at `READ_COMMITTED` unless you explicitly call `entityManager.refresh(entity)` to reload from the database.

---

**Q6: How does `@Version` implement optimistic locking?**
*Concept Check*

**One-line answer:** A `@Version` field is incremented on every UPDATE; JPA adds `WHERE version = ?` to the UPDATE SQL — if the row was modified concurrently, the UPDATE hits 0 rows and JPA throws `OptimisticLockException`.

**Full answer:**
Optimistic locking is based on the assumption that concurrent modifications are rare — most reads happen without conflict, so there is no need to hold database locks. The mechanism is simple and elegant. I add a `@Version Long version` field to the entity (annotated with JPA's `@Version`). When the entity is first persisted, version is 0. Every time the entity is updated, JPA automatically appends `AND version = ?` to the UPDATE SQL and increments the version value. A typical UPDATE becomes: `UPDATE product SET name = ?, price = ?, version = 2 WHERE id = ? AND version = 1`. If transaction A and transaction B both read the same product with version 1, and A commits first (incrementing version to 2), then B's UPDATE runs with `WHERE version = 1` and finds 0 matching rows. Hibernate detects this (JDBC returns 0 rows updated) and throws `OptimisticLockException` (which Spring wraps into `ObjectOptimisticLockingFailureException`). The caller retries the operation by re-reading the entity and reapplying the change. The key advantage over pessimistic locking is that no database lock is held between the read and the write — the database connection is free during the user's "think time." This gives excellent throughput for workloads where the vast majority of operations do not conflict.

*Walk through the specific SQL that changes — `AND version = ?` — to show you understand the mechanism, not just the concept.*

> **Gotcha follow-up:** Can you use `@Version` with `@Query` bulk updates?
> No, bulk JPQL updates (`UPDATE Entity e SET e.field = :value WHERE ...`) bypass the persistence context entirely — they execute directly as SQL. JPA does not run dirty checking, does not increment `@Version`, and does not enforce optimistic locking for bulk updates. If you run a bulk update on entities that have `@Version` fields, the version is not incremented, which will cause `OptimisticLockException` the next time any of those entities are updated through normal entity management. After a bulk update, you must either clear the persistence context (`entityManager.clear()`) or reload affected entities to get the correct version values.

---

**Q7: What is pessimistic locking and when should you prefer it over optimistic locking?**
*Tradeoff Question*

**One-line answer:** Pessimistic locking acquires a `SELECT FOR UPDATE` database row lock immediately on read, preventing concurrent modifications until the transaction commits — use it for high-contention scenarios where retrying (optimistic) would be too expensive.

**Full answer:**
Pessimistic locking tells the database to acquire a lock on the row at the moment it is read and hold it until the transaction commits or rolls back. In Spring Data JPA, this is done by annotating a repository method with `@Lock(LockModeType.PESSIMISTIC_WRITE)`, which translates to `SELECT ... FOR UPDATE` in PostgreSQL and MySQL. No other transaction can acquire a write lock on that row until the first transaction releases it — they either wait or fail immediately if `NOWAIT` is specified. Optimistic locking is preferable when the probability of conflict is low — the overhead of a `SELECT FOR UPDATE` lock on every read is wasteful when most transactions will succeed without conflict. Pessimistic locking is the right choice when conflicts are frequent and the cost of reading, applying business logic, and then failing at commit time (requiring a full retry) is higher than the cost of waiting for the lock upfront. The classic example is an inventory reservation in a flash sale: thousands of requests compete for the same SKU simultaneously, the optimistic retry loop would spin indefinitely under high contention, and `SELECT FOR UPDATE` serializes the requests cleanly. The risk: if the lock is held for a long time (slow business logic inside the transaction), other transactions queue up and throughput degrades. Keep pessimistic-locking transactions as short as possible.

*"High contention, retry too expensive" vs "low contention, retry acceptable" is the core tradeoff.*

> **Gotcha follow-up:** What is `LockModeType.PESSIMISTIC_READ` and when would you use it?
> `PESSIMISTIC_READ` acquires a shared lock (`SELECT ... FOR SHARE` or `LOCK IN SHARE MODE`). Multiple transactions can hold a shared lock simultaneously, but no transaction can acquire a write lock while any shared lock is held. Use `PESSIMISTIC_READ` when you need to guarantee that the data you are reading will not be modified by another transaction during your read phase, but you are not necessarily planning to modify it yourself — for example, reading a set of rows to compute an aggregate that will influence a decision, and you need to ensure the rows are not deleted or updated while you compute. `PESSIMISTIC_WRITE` (`SELECT FOR UPDATE`) prevents both reads-with-shared-locks and write locks from other transactions. In practice, `PESSIMISTIC_WRITE` is used far more often because the use case for exclusive write access is clearer and safer.

---

**Q8: Why does `IDENTITY` generation strategy break JDBC batching, and why is `SEQUENCE` better?**
*Concept Check*

**One-line answer:** With `IDENTITY`, Hibernate must INSERT each row immediately to get the auto-generated ID back from the database, preventing batch accumulation; with `SEQUENCE`, Hibernate pre-fetches a block of IDs and can batch 50 INSERTs into one round trip.

**Full answer:**
JDBC batching is a performance optimization where Hibernate accumulates multiple INSERT or UPDATE statements in memory and sends them to the database in a single network round trip. A batch of 50 INSERTs is sent as one call rather than 50, dramatically reducing network and database overhead for bulk operations. The `IDENTITY` generation strategy, used by MySQL's `AUTO_INCREMENT` and SQL Server's `IDENTITY` columns, assigns the primary key during the INSERT — the database generates it and returns it. This means Hibernate has no ID for the entity until after the INSERT executes. Because entities need IDs to be placed in the persistence context correctly, Hibernate must flush each INSERT immediately and retrieve the generated key before it can process the next entity. Batching is impossible: Hibernate calls `Statement.getGeneratedKeys()` after each individual INSERT. The `SEQUENCE` strategy uses a database sequence object. Hibernate calls `SELECT nextval('seq_name')` to pre-fetch IDs in advance, controlled by `allocationSize` (default 50). With 50 pre-fetched IDs in memory, Hibernate can accumulate 50 INSERT statements in a batch and send them all in one JDBC `executeBatch()` call, then fetch the next 50 IDs. For applications that write many entities — bulk imports, event sourcing, data pipelines — switching from `IDENTITY` to `SEQUENCE` with batching enabled (`spring.jpa.properties.hibernate.jdbc.batch_size=50`) can reduce write time by an order of magnitude.

*The phrase "must flush immediately to get the generated key" is the precise mechanism to state.*

> **Gotcha follow-up:** Does Hibernate batching work for UPDATE and DELETE statements as well?
> Yes, Hibernate can batch `UPDATE` and `DELETE` statements too. For updates, it batches dirty-checking flushes when multiple entities of the same type are modified in one session. There is one important subtlety: Hibernate's default behavior interleaves INSERTs, UPDATEs, and DELETEs as they come — `INSERT Order, UPDATE Product, INSERT Order` would result in batches of size 1 because statement types change. Setting `hibernate.order_inserts=true` and `hibernate.order_updates=true` (in `spring.jpa.properties`) reorders statements by type within a flush, enabling true batch accumulation. Without this setting, `batch_size=50` may not produce any actual batching if your application mixes entity types.

---

**Q9: What is Open Session in View (OSIV) and why should you disable it?**
*Tradeoff Question*

**One-line answer:** OSIV keeps the EntityManager open for the entire HTTP request (including controller and view rendering), enabling lazy loading anywhere but holding a database connection the whole time — disable it to force explicit data loading in the service layer.

**Full answer:**
Open Session in View (OSIV) is a pattern — and in Spring Boot, an enabled-by-default configuration — that keeps the JPA `EntityManager` (and its underlying database connection) open for the entire duration of an HTTP request, from before the `DispatcherServlet` invokes the controller to after the `ViewResolver` renders the response. The motivation is convenience: lazy-loaded associations can be accessed anywhere in the request — in the controller, in Thymeleaf templates, during JSON serialization by Jackson — without a `LazyInitializationException`. The problem is that "convenient" hides serious performance issues. A database connection from the pool is held open even while the controller executes (potentially slow business logic), while Jackson serializes the response (potentially triggering many lazy loads), and while the HTTP response is being written. The connection is not returned to the pool until the full response is sent. Under load, this depletes the connection pool and kills throughput. Worse, lazy loads triggered in controllers or views are invisible N+1 queries that bypass the service layer entirely — they appear in Hibernate logs but not in the service method, making them hard to detect in code review. Spring Boot logs a startup warning when OSIV is enabled: "spring.jpa.open-in-view is enabled by default." Disable with `spring.jpa.open-in-view=false`. This forces `LazyInitializationException` to surface in development when you forget to load associations, prompting you to add `JOIN FETCH` or `@EntityGraph` in the service layer where they belong.

*The connection pool depletion consequence is the most concrete reason to disable it.*

> **Gotcha follow-up:** After disabling OSIV, what is the correct pattern for loading data needed in a controller?
> The service method should load all data the controller will need within a single `@Transactional` method and return a fully-loaded entity or, better, a DTO (Data Transfer Object) that contains exactly the fields the response needs. Using a DTO (a plain POJO or Java record with only the needed fields) has additional benefits: it prevents accidentally serializing the entire entity graph, it allows the service to shape data for the specific use case, and it makes the API contract explicit. Spring Data JPA's projections (interface-based or class-based) are a clean way to define DTOs directly in the repository query: `@Query("SELECT new com.example.OrderSummary(o.id, o.total) FROM Order o")` returns DTO instances without loading the full entity.

---

**Q10: What is dirty checking and why does `@Transactional(readOnly=true)` improve read performance?**
*Concept Check*

**One-line answer:** Dirty checking compares every managed entity's current state to its snapshot at flush time to detect changes — `readOnly=true` skips snapshot creation entirely, saving memory and CPU for queries that never modify entities.

**Full answer:**
When Hibernate loads an entity from the database, it stores a copy of the entity's loaded state — a snapshot — in the persistence context. At flush time (before the transaction commits), Hibernate iterates over every managed entity and compares its current field values to the snapshot. Any difference is a "dirty" entity and Hibernate generates an UPDATE SQL for it. This process is called dirty checking, and it is what makes the "just modify the entity, no save needed" convenience possible. The cost of dirty checking scales with the number of managed entities and the number of fields per entity: for a service method that loads 500 order entities to compute an aggregate, Hibernate stores 500 snapshots and performs 500 comparisons at flush time, even if no modifications are made. `@Transactional(readOnly=true)` communicates to Hibernate that no entities will be modified. Hibernate skips snapshot creation — no snapshot arrays are allocated in memory — and skips the dirty-check comparison phase at flush time. It also sets the underlying JDBC connection to read-only, which some databases use as a hint to route queries to a read replica. The memory savings matter at scale: a snapshot for an entity with 20 fields is 20 object references; for 10,000 entities, that is significant heap pressure. Always annotate service methods that only read data with `readOnly=true` — it is a free optimization.

*"Skip snapshot creation" is the specific mechanism — more precise than just "performance hint."*

> **Gotcha follow-up:** Does `readOnly=true` prevent you from modifying an entity in the same method?
> No, it does not throw an exception if you modify a managed entity. Hibernate simply does not track the modification — no dirty check, no automatic UPDATE. If you rely on dirty checking to save changes and annotate the method with `readOnly=true` by mistake, your changes will be silently lost. The database connection being read-only may cause the database to reject explicit `UPDATE` statements if you try to call `entityManager.flush()` manually. The safety net is weak — `readOnly=true` is a hint, not an enforcement mechanism. The rule is simple: any method that writes must not use `readOnly=true`, and any method that only reads should.

---

**Q11: How should you size a HikariCP connection pool?**
*Design Scenario*

**One-line answer:** The HikariCP formula is `(core_count × 2) + effective_spindle_count` — for an 8-core machine with SSD this is ~17 connections max; start at 10, measure, and raise only if connection wait metrics show saturation.

**Full answer:**
Connection pool sizing is one of those areas where intuition (more connections = more throughput) is wrong. HikariCP's documentation cites a formula derived from database performance research: `pool_size = (core_count × 2) + effective_spindle_count`. For `core_count`, use the number of CPU cores available to the database server, not the application server. `effective_spindle_count` is 1 for a single spinning disk, 0 for SSD (essentially unlimited I/O concurrency). For an 8-core database server with SSD: `(8 × 2) + 0 = 16`, so the recommendation is 16-17 connections maximum. The reason more connections hurt is that database servers handle concurrent queries by running multiple threads — beyond the number of CPU cores, threads context-switch rather than execute in parallel. Too many connections mean more context switching overhead, more memory consumption per connection on the database server, and worse latency as queries wait longer for CPU time. A pool of 10-20 connections consistently outperforms a pool of 100+. In practice, I start with `maximumPoolSize=10`, enable HikariCP metrics via Micrometer (`hikaricp.connections.pending` — threads waiting for a connection), and increase the pool size in increments only if I observe sustained non-zero pending connection counts. The `minimumIdle` should equal `maximumPoolSize` to prevent connection creation overhead under sudden load.

*The counter-intuitive "smaller pool = better throughput" insight is what makes this answer stand out.*

> **Gotcha follow-up:** What is `connectionTimeout` in HikariCP and what should it be set to?**
> `connectionTimeout` is the maximum time in milliseconds a thread waits to obtain a connection from the pool before throwing a `SQLTimeoutException`. The default is 30,000 ms (30 seconds), which is far too long for a web application — a user would wait 30 seconds before getting an error. In a production web service, I set `connectionTimeout=3000` (3 seconds) to fail fast and return an error quickly when the pool is exhausted, rather than queuing hundreds of threads that each wait 30 seconds and cascade failures. `keepaliveTime` (default 0, disabled) periodically sends a keepalive query to prevent firewalls from closing idle connections. `maxLifetime` (default 30 minutes) recycles connections before they are closed by the database server's own idle timeout, preventing `Connection reset` errors.

---

**Q12: What is the difference between `EntityManager` and Hibernate's `Session`?**
*Concept Check*

**One-line answer:** `EntityManager` is the JPA standard interface for portability; `Session` is Hibernate's native extension of it with additional methods — obtain via `entityManager.unwrap(Session.class)` and use only for Hibernate-specific features.

**Full answer:**
JPA (Jakarta Persistence API) is a specification — a set of interfaces and annotations that define a standard way to do ORM in Java. `EntityManager` is the core JPA interface: `find()`, `persist()`, `merge()`, `remove()`, `createQuery()`, `flush()`. Any JPA-compliant provider (Hibernate, EclipseLink, OpenJPA) must implement this interface. Using `EntityManager` in your code means you are coding to the standard, and you could theoretically switch from Hibernate to EclipseLink without changing application code. `Session` is Hibernate's native interface. It extends `EntityManager` (since Hibernate 5.2) and adds Hibernate-specific methods: `saveOrUpdate()` (not in JPA), `createCriteria()` (legacy, deprecated since 5.2), `setFlushMode()`, natural ID loading APIs, and direct control over the session flush mode at a granular level. To obtain a `Session`, call `entityManager.unwrap(Session.class)`. In modern Spring Boot + Hibernate applications, `EntityManager` covers 95% of use cases. I reach for `Session` only when I need a Hibernate-specific feature that has no JPA equivalent — primarily `StatelessSession` for bulk insert/update operations (which bypasses the persistence context entirely for maximum performance) or the `@NaturalId` query API.

*`StatelessSession` as a use case for `Session` is a strong senior-level detail to include.*

> **Gotcha follow-up:** What is `StatelessSession` and when do you use it?
> `StatelessSession` is a Hibernate-only concept that provides a command-oriented API for database operations without a persistence context. It does not perform dirty checking, caching, or cascading — each operation immediately generates SQL. There is no first-level cache: every `get()` call hits the database. This makes it extremely efficient for bulk data processing: inserting or updating millions of rows without accumulating managed entities in memory, without snapshot comparison overhead, and without growing the first-level cache. The trade-off is that you lose all JPA conveniences — no automatic change detection, no cascading, no lazy loading. Use `StatelessSession` for ETL pipelines, batch imports, and data migration scripts where the JPA model would run out of heap managing thousands of managed entities.

---

**Q13: What is the difference between `find()` and `getReference()` in JPA?**
*Concept Check*

**One-line answer:** `find()` issues a SELECT immediately and returns null if the entity does not exist; `getReference()` returns a proxy with no SELECT until a non-ID field is accessed — use `getReference()` when you only need a foreign key reference to avoid an unnecessary query.

**Full answer:**
`entityManager.find(Product.class, id)` immediately executes `SELECT * FROM product WHERE id = ?`. If the row exists, it returns a managed entity. If the row does not exist, it returns `null`. You know immediately whether the entity exists. `entityManager.getReference(Product.class, id)` returns a proxy object — a Hibernate-generated subclass of `Product` — without issuing any SQL. The proxy holds only the ID. The SELECT is deferred until you first call a non-ID getter on the proxy (like `proxy.getName()`). If the row does not exist in the database, the `SELECT` that fires on the first access throws `EntityNotFoundException`. The important use case for `getReference()` is setting foreign key associations. If I am creating an `Order` and I know the `customerId` is valid (because it was submitted by an authenticated user), I can write `order.setCustomer(entityManager.getReference(Customer.class, customerId))`. This associates the order with the customer for the foreign key INSERT without issuing a `SELECT * FROM customer WHERE id = ?` just to get an object I will only use as a reference. Under the hood, Hibernate sets the foreign key column value from the proxy's ID without ever loading the customer row. This is a small but meaningful optimization in high-throughput scenarios.

*The foreign key association use case is the key practical motivation — most answers stop at "deferred loading."*

> **Gotcha follow-up:** What happens if you call `getReference()` and then close the `EntityManager` without ever accessing the proxy?
> Nothing. Since the proxy was never accessed (no non-ID getter called), no SQL was ever issued, and no `EntityNotFoundException` could have fired. The proxy becomes detached when the `EntityManager` closes. If you then try to access a non-ID field on the detached proxy, you get a `LazyInitializationException` (because the EntityManager that was responsible for loading the data is gone), not an `EntityNotFoundException`. If you need to verify that the entity actually exists, use `find()` — `getReference()` should only be used when you are confident the ID is valid.

---

**Q14: What is the difference between `Page<T>` and `Slice<T>` in Spring Data, and when do you use each?**
*Tradeoff Question*

**One-line answer:** `Page<T>` runs a COUNT query for total records (expensive on large tables); `Slice<T>` fetches `limit+1` rows and checks if there is a next page without a COUNT — use `Page` for paginated UIs, `Slice` for infinite scroll or API cursors.

**Full answer:**
Spring Data's `PagingAndSortingRepository` supports two styles of paginated query results. When a repository method returns `Page<T>`, Spring Data executes two SQL queries: the main query with `LIMIT` and `OFFSET` to get the current page of data, and a separate `SELECT COUNT(*) FROM ...` (with the same WHERE clause) to determine the total number of records. The `Page` object exposes `getTotalElements()`, `getTotalPages()`, `hasPreviousPage()`, and `hasNextPage()`. This is the right choice when the UI shows pagination controls like "Page 3 of 47" or "Showing 201–250 of 2,431 results." The COUNT query is the cost: on a table with 10 million rows, `COUNT(*)` with a complex WHERE clause can take seconds, making every paginated request slow. When a repository method returns `Slice<T>`, Spring Data executes only the main query, but with `LIMIT + 1` rows (one more than the page size). If the extra row is returned, `hasNext()` is `true`; if not, the current page is the last one. `getTotalElements()` and `getTotalPages()` are not available. Use `Slice` for infinite scroll (Instagram-style "load more"), for REST API cursors, or for any UI that only needs to know "is there a next page?" The single-query design scales to arbitrarily large datasets without a full-table COUNT. For very large datasets, even `OFFSET`-based pagination degrades (the database must scan and skip rows) — cursor-based pagination (using `WHERE id > lastSeenId`) is the ultimate solution.

*Mentioning cursor-based pagination as the final optimization signals senior-level awareness.*

> **Gotcha follow-up:** What performance problem does `OFFSET`-based pagination cause on large tables?
> `OFFSET N` tells the database to skip the first N rows after sorting. To do this, the database must identify, sort, and read through all N rows even though it discards them. On a table with 10 million rows, querying page 1,000 with page size 20 requires the database to process 20,000 rows to find rows 19,981–20,000. As the offset increases, the query gets progressively slower — a common source of timeouts on deep pagination. Cursor-based pagination avoids this: instead of `OFFSET`, use `WHERE id > :lastSeenId ORDER BY id LIMIT :pageSize`. The database can use the index on `id` to jump directly to the right starting point with no scan of prior rows. The trade-off is that you cannot jump to an arbitrary page number — you can only go forward or backward one page at a time, which is fine for infinite scroll and API consumers but not for UIs with page number navigation.

---

**Q15: What is the difference between JPQL and native queries in `@Query`, and when do you use each?**
*Tradeoff Question*

**One-line answer:** JPQL uses entity and field names, is portable across databases, and translated by Hibernate; native queries use raw SQL and support database-specific features JPQL cannot express — use native only when you need features unavailable in JPQL.

**Full answer:**
JPQL (Jakarta Persistence Query Language) is a SQL-like query language that operates on the JPA entity model, not the database schema. Query clauses reference entity class names and field names as declared in Java: `SELECT e FROM Employee e WHERE e.department.name = :dept`. Hibernate translates this JPQL into the appropriate SQL dialect for the target database — adding schema-specific quoting, using the correct `LIMIT` syntax, translating `CONCAT` to `||` for PostgreSQL or `CONCAT()` for MySQL. This portability means the same JPQL query works against H2 in tests and PostgreSQL in production. JPQL also participates fully in JPA's entity lifecycle — returned objects are managed entities, field names always match the Java model. Native queries (annotated with `nativeQuery = true`) use raw SQL against actual table and column names. They are required when you need database-specific features: window functions (`ROW_NUMBER() OVER (PARTITION BY ...)`), Common Table Expressions (`WITH RECURSIVE ...`), `RETURNING` clauses in PostgreSQL for insert-then-retrieve in one statement, `JSONB` operators, geospatial functions, or any vendor extension JPQL does not support. The trade-offs of native queries are that they break if you rename a table or column, they do not automatically adapt to dialect differences, and they return raw tuples unless you use `@SqlResultSetMapping` or a projection interface. My rule: use JPQL by default; only drop to native SQL for features JPQL genuinely cannot express.

*The specific list of native-only features (window functions, CTEs, RETURNING) demonstrates real-world experience.*

> **Gotcha follow-up:** How do you use a projection interface with a native query to get a typed result?
> Spring Data JPA supports closed projections (interfaces with getter methods) with native queries. Declare an interface with getter methods matching the columns you want: `interface OrderSummary { Long getId(); String getStatus(); }`. Annotate the repository method: `@Query(value = "SELECT id, status FROM orders WHERE customer_id = :id", nativeQuery = true)`. Spring Data generates a proxy implementing `OrderSummary` that maps each getter to the corresponding column by name. The column names in the SQL must match the getter names (case-insensitively, after stripping `get`). For columns whose names do not match Java naming conventions, use a `@SqlResultSetMapping` on the entity or use constructor expressions: `@Query("SELECT new com.example.OrderSummary(o.id, o.status) FROM Order o WHERE ..."), which works in JPQL but not in native queries, where `@NamedNativeQuery` with result set mapping is the alternative.

---

**Common Mistakes — Section 3:**
- **Leaving `@ManyToOne` as EAGER** → causes hidden JOINs on every load. Override to `FetchType.LAZY` universally and load eagerly only when needed.
- **Accessing lazy collections outside a transaction** → `LazyInitializationException`. Load all needed associations within the `@Transactional` service method before returning.
- **Using `IDENTITY` generation with batch inserts** → batching is silently disabled. Switch to `SEQUENCE` with `allocationSize` matching the batch size.
- **Not annotating read-only service methods with `readOnly=true`** → wastes memory on snapshots and CPU on dirty checks. Always annotate read-only methods.
- **Forgetting `Page` runs a COUNT query** → on large tables this is slow. Use `Slice` or cursor-based pagination when total count is unnecessary.
- **Modifying entities after `merge()` but using the original detached reference** → `merge()` returns the managed copy; the original stays detached. Always use the returned value.

**Quick Revision — Section 3:** The persistence context is the heart of JPA — it tracks managed entities via dirty checking and avoids redundant SELECTs; most JPA bugs are about entities being in the wrong state (detached when you expect managed) or queries being unintentionally N+1 (fix with JOIN FETCH or @EntityGraph).

---

## Section 4: @Transactional Propagation

> *Reading guide: Propagation defines what Spring does with the database transaction boundary when one transactional method calls another. Interviewers test this heavily because getting it wrong causes silent data loss or unexpected rollbacks.*

**Q1: What is @Transactional propagation and what are the 7 propagation types?**
*Concept Check*

**One-line answer:** Propagation tells Spring how to behave with respect to an existing transaction when a @Transactional method is invoked — whether to join it, create a new one, suspend it, or throw an error.

**Full answer:**
When I annotate a method with @Transactional, Spring wraps it in a proxy that manages a database transaction — that means it opens the transaction before the method runs and commits or rolls it back when it finishes. The "propagation" setting controls what happens when that method is called from inside another transactional method, because at that point a transaction might already be active on the current thread. Spring stores the active transaction in a thread-local variable, so every @Transactional method on the same thread can inspect it.

The seven propagation types are:

- **REQUIRED** (the default): if a transaction is already active on this thread, the method joins it and shares its commit/rollback boundary; if there is no active transaction, Spring creates a new one. This is correct for the vast majority of service-layer methods.
- **REQUIRES_NEW**: regardless of whether a transaction already exists, Spring suspends it, opens a completely separate transaction, and resumes the outer one when the inner method finishes. The inner transaction commits or rolls back independently. The classic use case is audit logging — you want the audit record to persist even if the outer business transaction rolls back.
- **SUPPORTS**: if a transaction is already active, the method participates in it; if there is no transaction, the method runs without one. This is useful for read methods that are safe both with and without transactional consistency guarantees.
- **NOT_SUPPORTED**: if a transaction is active, Spring suspends it for the duration of this method, then resumes it. The method runs non-transactionally. This is useful when calling a legacy system or a method that explicitly must not participate in a transaction.
- **MANDATORY**: the method must always be called from within an existing transaction. If no transaction is active, Spring throws an `IllegalTransactionStateException` at runtime. This is a useful guard on low-level repository helpers that are never safe to call without a surrounding business transaction.
- **NEVER**: the opposite of MANDATORY — if a transaction is active when this method is called, Spring throws `IllegalTransactionStateException`. Use this to enforce that certain utility methods are never accidentally called inside a transaction (for example, methods that do long-running batch reads that would hold locks).
- **NESTED**: if a transaction is already active, Spring creates a JDBC savepoint inside that transaction. The nested portion can roll back to the savepoint without rolling back the entire outer transaction. If there is no outer transaction, a new one is created. This relies on JDBC savepoint support, so it does not work with all JPA providers the same way.

*When explaining this in an interview, anchor each type to a concrete use case — that shows you have actually reasoned about when each matters, not just memorised names.*

> **Gotcha follow-up:** What is the difference between NESTED and REQUIRES_NEW?
> REQUIRES_NEW creates a fully independent transaction: if the outer transaction rolls back, the inner one is unaffected because it already committed. NESTED creates a savepoint *inside* the outer transaction: the nested portion can roll back independently, but if the outer transaction rolls back, it rolls back everything, including the work done inside the nested block, because they share the same physical database transaction. So REQUIRES_NEW gives true independence; NESTED gives partial rollback within a shared transaction. Use REQUIRES_NEW for audit logs. Use NESTED for partial retry logic where you want the outer transaction to survive a failed sub-operation.

---

**Q2: What is the difference between REQUIRES_NEW and NESTED? When would you use each?**
*Tradeoff Question*

**One-line answer:** REQUIRES_NEW creates a fully separate, independent transaction that commits on its own; NESTED creates a savepoint inside the existing transaction and still participates in the outer transaction's final outcome.

**Full answer:**
I think of REQUIRES_NEW as "bringing your own room" — the inner method opens a brand-new connection-level transaction, commits it independently, and if the outer transaction later rolls back, the inner work is already durably committed in the database. This makes it perfect for audit logging: even if a placeOrder method throws and rolls back, I still want a record that the order was attempted. The cost is that REQUIRES_NEW suspends the outer transaction, so it holds an open connection while the inner transaction runs — under high concurrency, this can cause connection pool exhaustion if the inner method is slow.

NESTED, on the other hand, uses a JDBC savepoint — think of a savepoint as a bookmark inside a single database transaction. The nested method can roll back to that bookmark without unwinding the entire outer transaction, but the outer transaction still controls the final commit. So if the outer transaction rolls back, the nested work rolls back with it. NESTED is useful when I want partial failure tolerance within a single business operation — for example, enriching each item in a batch where I can skip and continue on individual failures without aborting the whole batch. One caveat: NESTED requires the underlying JDBC driver and JPA provider to support savepoints — it works reliably with Hibernate and most SQL databases, but it is not supported by all JTA transaction managers.

*Summarise the key rule: REQUIRES_NEW = independent durability; NESTED = isolated rollback within a shared transaction.*

> **Gotcha follow-up:** Can you use REQUIRES_NEW with the same EntityManager?
> No — REQUIRES_NEW suspends the outer transaction but the current EntityManager (the JPA unit of work, basically a wrapper around a database connection) is tied to the outer transaction. Hibernate will flush the first-level cache as needed, but the inner REQUIRES_NEW method will get a new EntityManager from the pool. This is one reason REQUIRES_NEW can cause subtle issues if the outer transaction has unflushed changes — Hibernate flushes them before suspending, which can trigger unexpected SQL.

---

**Q3: What happens when a @Transactional method calls another @Transactional method in the same class?**
*Concept Check — Self-invocation Trap*

**One-line answer:** The proxy is bypassed, so the propagation setting on the called method is completely ignored — both methods run inside the caller's transaction regardless of what propagation the inner method declares.

**Full answer:**
Spring's @Transactional support works through AOP proxies. When another class calls my bean, it calls through the proxy object, which intercepts the call and applies the transactional behaviour. However, when a method inside my bean calls another method on `this`, it calls the real object directly — the proxy never gets involved. This is called the self-invocation problem.

The practical consequence is that if I have a public `placeOrder` method annotated with @Transactional and it calls `this.auditLog()` which is annotated with `@Transactional(propagation = Propagation.REQUIRES_NEW)`, the REQUIRES_NEW setting is silently ignored. Both methods run in the same transaction opened by `placeOrder`. No new transaction is created, and no audit log is committed independently.

The fix I reach for most often is to extract the inner method into a separate Spring-managed bean and inject that bean. For example, I create an `AuditService` bean, inject it into `OrderService`, and call `auditService.log(order)` — now the call goes through the proxy and the REQUIRES_NEW propagation applies correctly. Alternatively, I can inject the bean into itself using `@Autowired` self-injection (Spring handles this via a lazy proxy since 4.3), or I can programmatically access the proxy via `AopContext.currentProxy()`, though that couples the code to the AOP framework. The cleanest solution is always to separate the concern into its own bean.

*This is one of the most common real-world Spring bugs interviewers probe. State the root cause clearly: "Spring AOP is proxy-based, and self-calls skip the proxy."*

> **Gotcha follow-up:** Does AspectJ weaving fix the self-invocation problem?
> Yes — compile-time or load-time AspectJ weaving instruments the bytecode directly rather than relying on proxies, so self-calls are intercepted just like external calls. However, this requires configuring the AspectJ agent and is uncommon in typical Spring Boot applications. Most teams simply separate the method into another bean.

---

**Common Mistakes:**
- **Using REQUIRES_NEW for every important method** → This suspends the outer transaction and holds a database connection open; under load, this exhausts the connection pool. Use REQUIRES_NEW only when true independent durability is required (audit, event store).
- **Assuming NESTED is available everywhere** → NESTED requires JDBC savepoint support. It does not work with JTA transaction managers like Atomikos without extra configuration. Test your specific stack.
- **Forgetting that default propagation is REQUIRED** → Developers sometimes think that annotating a private helper with @Transactional creates its own transaction. It does not — the proxy cannot intercept private methods, so no transaction boundary is created at all.

**Quick Revision:** REQUIRED = join the party; REQUIRES_NEW = bring your own room; NESTED = bookmark inside the party.

---

## Section 5: AOP — Aspect-Oriented Programming

> *Reading guide: AOP lets you attach cross-cutting behaviour — logging, security, transactions, caching — to methods without modifying the method bodies. Spring implements AOP via proxies, which creates an important constraint: it only works on Spring-managed beans called from outside the bean.*

**Q1: What is AOP and how does it work in Spring?**
*Concept Check*

**One-line answer:** AOP (Aspect-Oriented Programming) is a technique for separating cross-cutting concerns — code that would otherwise be repeated across many classes — into a single modular unit called an aspect, which Spring applies via proxy objects at runtime.

**Full answer:**
A cross-cutting concern is behaviour that spans many otherwise unrelated classes — logging every service method call, checking security on every endpoint, starting a transaction before every repository call. Without AOP, I would have to paste the same boilerplate into dozens of methods. AOP lets me write that behaviour once in an "aspect" and declare where to apply it.

The core vocabulary is: a **join point** is a specific point in program execution where the aspect can be applied — in Spring AOP, a join point is always a method execution. A **pointcut** is an expression that selects which join points the aspect applies to — for example, "all public methods in the service package". An **advice** is the code that runs at those join points — before the method, after it, or wrapping it entirely. The combination of a pointcut and an advice is called an **aspect**.

**Weaving** is the process of applying the aspect to the target code. Spring uses *runtime proxy weaving* — when the ApplicationContext starts, for every bean that matches a pointcut, Spring wraps it in a proxy object (either a JDK dynamic proxy or a CGLIB subclass). Callers receive the proxy, and every call goes through the proxy's advice chain before reaching the real method. This is why AOP only works on Spring-managed beans called through the proxy — direct calls via `this` skip the proxy entirely.

*Always connect AOP to a concrete annotation you have used: "this is how @Transactional works — it is just @Around advice on every method annotated with @Transactional."*

> **Gotcha follow-up:** Can Spring AOP intercept calls to private methods?
> No. Spring AOP is proxy-based, and a proxy can only override methods that are visible to the proxy class — meaning public and (with CGLIB) protected methods. Private methods are not visible through a proxy. To intercept private methods, you would need compile-time AspectJ weaving, which instruments the bytecode directly.

---

**Q2: What are the 5 advice types in Spring AOP? When would you use @Around vs @Before?**
*Concept Check*

**One-line answer:** The five types are @Before, @After, @AfterReturning, @AfterThrowing, and @Around — @Around is the most powerful because it wraps the entire invocation and can suppress, replace, or retry it, while @Before simply runs code before the method without being able to affect its execution.

**Full answer:**
I think of the five advice types as different hooks in the method lifecycle:

**@Before** runs before the method executes. It cannot modify the return value or prevent the method from running (unless it throws an exception). I use it for lightweight precondition checks or logging the incoming arguments — for example, checking that the caller has a required role before a sensitive method runs.

**@After** runs after the method completes, whether it returned normally or threw an exception — it is essentially a "finally" block. I use it for cleanup operations that must always happen regardless of outcome.

**@AfterReturning** runs only after the method returns successfully. I can bind the return value in the advice and inspect or log it. I use this for logging successful results or triggering downstream events only on success.

**@AfterThrowing** runs only when the method throws an exception. I can bind the exception object and log it centrally, send an alert, or translate it. This keeps exception-handling logic out of the business method.

**@Around** wraps the entire method invocation. I receive a `ProceedingJoinPoint` object, which gives me full control: I can run code before, call `proceedingJoinPoint.proceed()` to invoke the actual method, inspect the return value, and run code after. I can also choose not to call `proceed()` at all (short-circuiting) or call it multiple times (implementing retry). @Around is used for transactions, caching, retry logic, and rate limiting.

I reach for @Around when I need to conditionally skip the method, modify the return value, retry on failure, or measure execution time. I use @Before for simpler pre-conditions where I only need to inspect inputs without affecting execution.

*Mention that @Around is the most powerful but also the most error-prone — forgetting to call proceed() silently makes the method do nothing.*

> **Gotcha follow-up:** What happens if you forget to call proceed() inside an @Around advice?
> The target method is never called. The @Around advice returns whatever value the advice body returns (null for void methods, or the declared return type's default). This is a silent bug — no exception is thrown, and the caller believes the method ran. Always ensure proceed() is called, typically inside a try-catch, unless you deliberately want to short-circuit.

---

**Q3: What is the difference between JDK dynamic proxy and CGLIB in Spring AOP? When does each apply?**
*Concept Check*

**One-line answer:** A JDK dynamic proxy wraps an interface — it can only proxy beans that implement an interface — while CGLIB creates a subclass of the bean class at runtime and can proxy any non-final class, which is why Spring Boot defaults to CGLIB.

**Full answer:**
Both proxy types serve the same purpose — intercepting method calls to apply advice — but they work through different Java mechanisms.

A **JDK dynamic proxy** uses `java.lang.reflect.Proxy` to create an object that implements the same interfaces as the target bean. Because it creates an interface-level proxy, callers must hold a reference to the interface type, not the concrete class. If a caller auto-wires by concrete class rather than interface, Spring throws a `BeanNotOfRequiredTypeException`. JDK proxies are lightweight and ship with the JDK, requiring no extra library.

**CGLIB** (Code Generation Library) generates a subclass of the target bean at runtime. The subclass overrides all non-final, non-private methods and inserts the advice calls. Because CGLIB subclasses the concrete class, callers can auto-wire by concrete type, which is more convenient. The constraint is that CGLIB cannot subclass a `final` class and cannot override a `final` method — if either is final, advice is silently skipped for that method.

Spring Boot defaults to CGLIB proxies for `@Configuration` classes and for all AOP since version 2.0, because it avoids the "must inject by interface" constraint. I can revert to JDK proxies by setting `spring.aop.proxy-target-class=false`, but that is rarely necessary. The important practical rule I follow: never mark service-layer classes or their public methods as `final` in a Spring application, because CGLIB will silently skip applying advice on those methods.

> **Gotcha follow-up:** Can a Spring bean use both JDK and CGLIB proxies simultaneously?
> No — a bean gets one proxy type. If the bean implements an interface and `proxy-target-class` is false (JDK mode), it gets a JDK proxy. If `proxy-target-class` is true (the Spring Boot default), it gets a CGLIB proxy regardless of whether it implements an interface.

---

**Q4: Write a pointcut expression to intercept all public methods in the service layer.**
*Design Scenario*

**One-line answer:** `execution(public * com.example.service.*.*(..))`  — this matches any public method, any return type, in any class in the service package, with any parameters.

**Full answer:**
The `execution` pointcut designator is the most common one I use. Its syntax is: `execution([modifier] returnType [declaringType].methodName(paramTypes) [throws])`, where items in square brackets are optional.

Breaking down `execution(public * com.example.service.*.*(..))`:
- `public` — limits to public methods only
- `*` — any return type (the first wildcard)
- `com.example.service.*` — any class directly in the service package (single `*` does not match sub-packages; use `..` for recursive)
- `.*` — any method name
- `(..)` — any number and type of parameters

If I also want to cover sub-packages (like `com.example.service.order`), I use `com.example.service..*.*(..))` with double dots.

Other pointcut designators I use alongside `execution`:
- `@annotation(org.springframework.transaction.annotation.Transactional)` — matches methods annotated with @Transactional, regardless of package
- `within(com.example.service.*)` — matches all join points (method executions) *within* classes in the service package, slightly simpler syntax
- `bean(*Service)` — matches all beans whose name ends in "Service", useful when package structure is inconsistent
- `args(Long, ..)` — matches methods where the first argument is a Long, useful for ID-based security checks

*Be ready to write these on a whiteboard — interviewers often ask for a specific expression and check that you understand the wildcard rules.*

> **Gotcha follow-up:** What is the difference between `within` and `execution` pointcuts?
> `execution` matches at the method execution join point level and can filter on return type, method name, and parameter types. `within` limits matches to all join points within a particular type or package — it cannot filter by return type or method signature. In practice, `execution` is more precise; `within` is more concise when you want to intercept all methods in a package regardless of signature.

---

**Common Mistakes:**
- **Expecting AOP on self-calls** → Spring AOP is proxy-based; `this.method()` bypasses the proxy. Fix: inject the bean or use `AopContext.currentProxy()`.
- **Marking target class or method final with CGLIB** → CGLIB cannot subclass final classes or override final methods; advice is silently not applied. Fix: remove `final`, or switch to JDK proxy with interface.
- **Forgetting to call proceed() in @Around** → The target method silently never runs. Fix: always call `joinPoint.proceed()` in the try block.
- **Using execution pointcut with double star and wrong package depth** → `com.example.*.*(..)` misses sub-packages. Use `com.example..*.*(..)` (double dot) for recursive matching.

**Quick Revision:** AOP = cross-cutting concerns via proxy; @Around = full control with proceed(); CGLIB = subclass (no final); JDK = interface only.

---

## Section 6: Common Spring Traps

> *Reading guide: These 15 traps are high-signal interview material because they represent the difference between someone who has read the docs and someone who has debugged production issues. Know the mechanism behind each one, not just the fix.*

**Trap 1: Self-invocation bypasses the proxy**
When I call `this.someMethod()` inside a Spring bean, I am calling the raw object directly, not the Spring proxy. This means any AOP advice, @Transactional boundary, or @Cacheable interception declared on `someMethod` is completely ignored. The bug is silent — no exception is thrown. The fix is to inject the bean into itself (Spring 4.3+ supports lazy self-injection) or, better, extract the called method into a separate Spring-managed bean and inject that.

**Trap 2: Prototype-scoped bean injected into a singleton**
When Spring creates a singleton bean, it resolves all its dependencies once at construction time. If a prototype-scoped bean (meaning a new instance per injection point) is injected into a singleton, that prototype instance is captured at construction and never refreshed — it effectively becomes a singleton. The fix is to use `ObjectProvider<MyPrototypeBean>` and call `getObject()` each time a fresh instance is needed, or use `@Lookup` method injection where Spring overrides the method at runtime to return a fresh prototype, or declare a scoped proxy with `@Scope(proxyMode = ScopedProxyMode.TARGET_CLASS)`.

**Trap 3: CGLIB fails on final class or final method**
CGLIB proxies work by subclassing the target class and overriding its methods. A `final` class cannot be subclassed, and a `final` method cannot be overridden. If my service class or any of its public methods are marked `final`, CGLIB silently skips applying advice — no error at startup, no exception at runtime, just missing behaviour. The fix is to remove the `final` modifier from Spring-managed beans' public methods. If the class must be final, switch to JDK dynamic proxy by having the bean implement an interface and setting `proxy-target-class=false`.

**Trap 4: @Transactional on a private method**
Spring's AOP proxy can only intercept methods that are accessible through the proxy — that means public methods (and protected with CGLIB). A private method is not accessible through any proxy. Annotating a private method with @Transactional compiles and deploys without error, but no transaction is ever created. The fix is to make the method public or protected, and ensure it is called from another bean (not self-invocation) so the proxy is involved.

**Trap 5: LazyInitializationException outside a transaction**
JPA lazy-loading works by replacing the target collection or entity with a proxy object that fetches data on first access. That fetch requires an open EntityManager (the JPA unit of work, bound to the current transaction). If a @Transactional method loads an entity and returns it to a caller outside a transaction (for example, a REST controller), and that caller then accesses a lazy collection, Hibernate throws `LazyInitializationException` because the EntityManager is already closed. The most robust fix is to load everything you need within the @Transactional boundary — use JOIN FETCH, @EntityGraph, or explicit `Hibernate.initialize()`. Spring Boot's OSIV (Open Session in View) feature keeps the EntityManager open through the HTTP request, which prevents this exception but delays its root cause and leaks database connections; disabling it (`spring.jpa.open-in-view=false`) forces you to fix the real loading strategy.

**Trap 6: Circular dependency with constructor injection**
If Bean A requires Bean B in its constructor, and Bean B requires Bean A in its constructor, Spring cannot instantiate either — it gets into an infinite loop and throws a `BeanCurrentlyInCreationException` at startup. Constructor injection is actually better practice because it makes the cycle visible immediately. The fix is to break the cycle: introduce an interface and inject the abstraction, use `@Lazy` on one of the constructor parameters to defer instantiation, switch one dependency to setter injection (Spring can handle setter-injection cycles by using partial beans), or refactor to separate the shared logic into a third bean that both depend on.

**Trap 7: Field injection breaks unit testing**
When I use `@Autowired` on a private field, Spring injects the dependency via reflection when building the ApplicationContext. But if I instantiate the class directly with `new MyService()` in a unit test, the field remains `null` — Spring's reflection injection does not run outside a Spring context. Constructor injection avoids this entirely: I pass the mock directly to the constructor. Field injection requires either a full Spring context (slow) or a reflection-based utility like `ReflectionTestUtils.setField()` (fragile). I always prefer constructor injection for Spring-managed classes for this reason.

**Trap 8: @Async in the same class (self-invocation)**
`@Async` works through the same proxy mechanism as `@Transactional`. If an async method is called via `this` from another method in the same class, the proxy is bypassed and the method runs synchronously on the same thread — completely defeating the purpose. The fix is identical to the self-invocation fix: move the @Async method to a separate Spring bean and inject it.

**Trap 9: Missing @EnableAsync causes @Async to be silently ignored**
If I annotate a method with `@Async` but forget to add `@EnableAsync` to a `@Configuration` class, Spring never registers the async processing infrastructure. The annotated method runs synchronously without any warning or error. The fix is to add `@EnableAsync` on a `@Configuration` class — in Spring Boot, placing it on the main application class is common. Similarly, `@EnableScheduling` is required for `@Scheduled` to work.

**Trap 10: @Cacheable self-call bypasses the cache**
`@Cacheable` is implemented via AOP proxy. Calling a @Cacheable method via `this` bypasses the proxy and always executes the method body — the cache is never consulted and the result is never stored. The fix is the same as all proxy bypass issues: extract the cached method into a separate bean.

**Trap 11: @Transactional on @Bean returning interface requires explicit proxy mode**
When a Spring @Bean method returns a concrete type and that bean needs to be proxied (for @Transactional or other AOP), CGLIB subclasses the concrete type. If the @Bean method return type is an interface but `proxyTargetClass` is explicitly set to `false`, Spring creates a JDK proxy. Conflicts arise when the auto-wiring point expects the concrete class. Being explicit with `@Transactional(proxyTargetClass = true)` or ensuring `proxy-target-class=true` in configuration avoids mismatches.

**Trap 12: IDENTITY generation strategy kills JDBC batching**
Hibernate's JDBC batch insert optimisation collects multiple INSERT statements and sends them to the database in a single round trip. However, with `@GeneratedValue(strategy = GenerationType.IDENTITY)`, the database generates the primary key via an auto-increment column, and Hibernate must execute each INSERT individually to retrieve the generated key before it can assign it to the entity object (because Hibernate needs the ID to manage the first-level cache). This prevents batching entirely. The fix is to use `SEQUENCE` strategy with a generous `allocationSize` (say, 50) — Hibernate pre-fetches a block of IDs from a database sequence, assigns them in memory, and can then batch all the INSERTs without round-tripping for each row.

**Trap 13: OSIV enabled by default leaks database connections**
Open Session in View (OSIV) is a Spring feature that keeps the Hibernate EntityManager open for the entire duration of an HTTP request — from when the DispatcherServlet receives the request to when it finishes writing the response. This prevents LazyInitializationException in view templates and controllers, but it holds a database connection from the pool open through the entire request lifecycle, including any time spent on JSON serialisation, view rendering, or network I/O. Under load, this exhausts the connection pool. The fix is to set `spring.jpa.open-in-view=false` and move all data loading into the @Transactional service layer so the connection is held only for the duration of the actual database work.

**Trap 14: Eager loading on @ManyToOne and @OneToOne causes unexpected JOINs**
By default in JPA, @ManyToOne and @OneToOne relationships are EAGER — Hibernate always loads the associated entity in the same query, even when you only need the parent. In an entity with multiple such relationships, every JPQL query generates multiple JOINs, loading data you never use and degrading performance. The fix is to override the fetch type to LAZY on all associations: `@ManyToOne(fetch = FetchType.LAZY)`. Then load associated data explicitly when needed, using JOIN FETCH or @EntityGraph on the specific queries that require it.

**Trap 15: Missing @EnableTransactionManagement in plain Spring (not Boot)**
In a plain Spring application (not Spring Boot), `@Transactional` annotations are silently ignored unless `@EnableTransactionManagement` is present on a `@Configuration` class (or the equivalent XML `<tx:annotation-driven/>`). Spring Boot's auto-configuration adds this automatically, so Boot developers rarely encounter this. But in a plain Spring application or when writing a shared library that is not Boot-aware, forgetting this annotation means all @Transactional methods run without any transaction management — no transaction is opened, and no rollback occurs on exceptions.

---

**Common Mistakes:**
- **Assuming @Transactional works on private methods** → it does not; make the method public and ensure it is called through the proxy (from another bean).
- **Leaving OSIV enabled in production** → set `spring.jpa.open-in-view=false` and fix lazy loading in the service layer.
- **Using IDENTITY generation for bulk inserts** → switch to SEQUENCE with a suitable `allocationSize`.

**Quick Revision:** Most Spring traps share one root cause — proxy bypass (self-invocation, private methods, final classes) or lazy loading misconfiguration (OSIV, default EAGER on @ManyToOne).

---

## Section 7: Hibernate Cheat Sheet

> *Reading guide: Hibernate questions in interviews test whether you understand the lifecycle of an entity, how Hibernate decides when to flush SQL to the database, and how to avoid performance traps like N+1 queries and unbounded eager loading.*

**Q1: Explain the 4 entity lifecycle states in JPA/Hibernate. What is dirty checking?**
*Concept Check*

**One-line answer:** JPA entities move through four states — transient, managed, detached, and removed — and Hibernate's "dirty checking" mechanism automatically detects changes to managed entities and generates UPDATE SQL at flush time, so you do not have to call an explicit save.

**Full answer:**
Understanding the entity lifecycle is fundamental to reasoning about when Hibernate flushes SQL to the database.

A **transient** entity is a plain Java object that was created with `new` and has never been associated with a Hibernate Session (or JPA EntityManager, which is the JPA-spec term for the same concept). Hibernate has no awareness of it — changes to it are not tracked.

A **managed** entity is one that is currently associated with an open EntityManager — either because it was loaded by a query, or because it was passed to `entityManager.persist()`. Hibernate keeps a snapshot of its state at the time it became managed. At flush time (before a query, before commit, or on explicit `entityManager.flush()`), Hibernate compares the current state of every managed entity against its snapshot. If anything changed, Hibernate generates and executes an UPDATE statement automatically. This is **dirty checking** — you do not need to call `save()` again after modifying a managed entity; Hibernate detects the change and persists it.

A **detached** entity was previously managed but its EntityManager has been closed (for example, the @Transactional method returned). The entity still holds its data and its primary key, but Hibernate is no longer tracking it. Changes to a detached entity are not automatically persisted. To reattach it, I call `entityManager.merge(entity)`, which copies the detached entity's state into a new managed entity.

A **removed** entity has been passed to `entityManager.remove()`. It is still managed until the flush, at which point Hibernate generates a DELETE statement and the entity becomes transient again.

*Dirty checking is the source of several surprises in interview scenarios — modifying an entity inside a @Transactional method and returning causes an UPDATE even without an explicit save call.*

> **Gotcha follow-up:** How does Hibernate implement dirty checking efficiently?
> Hibernate keeps a "snapshot" array for each managed entity in the persistence context (the EntityManager). At flush time it compares the current field values against the snapshot array. This is an O(n × fields) operation per flush. For large numbers of managed entities in a single transaction, this can be expensive. The `@DynamicUpdate` annotation and careful transaction scoping (keeping transactions short) help mitigate this.

---

**Q2: What are the different fetch strategies in Hibernate? Compare JOIN FETCH, @BatchSize, and @EntityGraph.**
*Tradeoff Question*

**One-line answer:** JOIN FETCH loads the association in a single SQL JOIN; @EntityGraph does the same thing declaratively at the repository level; @BatchSize groups lazy-load requests into batches — each solves the N+1 problem differently, with different tradeoffs around query complexity and data volume.

**Full answer:**
The N+1 problem occurs when loading N parent entities triggers N additional SELECT statements to load their associated collections or entities one by one. The fix is to change how associations are fetched.

**JOIN FETCH** is a JPQL hint: `SELECT o FROM Order o JOIN FETCH o.customer WHERE o.status = :status`. It rewrites the query as a SQL JOIN, loading all customers in the same SELECT. The result is one efficient query. The downside is that if I JOIN FETCH a collection (like order items), SQL may return duplicate rows (one row per item), which Hibernate deduplicates in memory. Fetching multiple collections in the same JOIN FETCH is problematic (produces a Cartesian product), so I use it for single associations or use separate queries.

**@EntityGraph** achieves the same result as JOIN FETCH but declaratively, at the Spring Data JPA repository level. I annotate a repository method with `@EntityGraph(attributePaths = {"customer", "items"})` and Spring generates the JOIN FETCH query automatically. This keeps my JPQL simple and moves the fetch strategy into the repository layer. The same Cartesian product caution applies when fetching multiple collections.

**@BatchSize** is a Hibernate annotation placed on the association field: `@BatchSize(size = 25)`. When lazy loading is triggered for one entity, Hibernate collects up to 25 outstanding lazy-load requests for the same association and resolves them in a single `SELECT ... WHERE id IN (...)` query. Instead of N queries, I get N/25 queries. This is useful when I cannot modify the query (third-party code, dynamic queries) or when the association is genuinely accessed only sometimes and I do not want to always JOIN FETCH it. It does not eliminate round trips entirely but reduces them dramatically.

My strategy in practice: JOIN FETCH or @EntityGraph for known access patterns in service-layer queries; @BatchSize as a safety net on entities whose associations are sometimes accessed lazily.

> **Gotcha follow-up:** What is @Fetch(FetchMode.SUBSELECT) and when would you use it?
> `@Fetch(FetchMode.SUBSELECT)` is a Hibernate-specific annotation that, when lazy loading is triggered, loads the collection for *all* parent entities in the current session using a single `SELECT ... WHERE parent_id IN (SELECT id FROM parent WHERE ...)` subselect. Unlike @BatchSize, it loads everything in one shot regardless of count. It is useful for collections that are always fully accessed, but the subselect can be expensive on large data sets. The hierarchy I follow: JOIN FETCH > @EntityGraph > @BatchSize > SUBSELECT.

---

**Q3: Why does @GeneratedValue(strategy=IDENTITY) break Hibernate batching? How do you fix it?**
*Concept Check*

**One-line answer:** IDENTITY relies on the database auto-incrementing the key and returning it after each INSERT, forcing Hibernate to execute one INSERT at a time; SEQUENCE pre-allocates IDs in a block so Hibernate can know all IDs before executing and can batch the INSERTs together.

**Full answer:**
Hibernate's JDBC batching optimisation works by accumulating multiple INSERT or UPDATE statements in memory and sending them to the database driver in a single `executeBatch()` call. This dramatically reduces network round trips for bulk operations.

For batching to work, Hibernate must know the primary key of each entity *before* executing the INSERT, because it needs to populate the entity's `@Id` field and maintain its first-level cache (EntityManager identity map). With `GenerationType.IDENTITY`, the primary key is generated by the database using an auto-increment column. The database only assigns the key value during the INSERT execution. So Hibernate cannot know the key before the INSERT — it must execute each INSERT individually and retrieve the generated key immediately. This breaks batching: every `entityManager.persist(entity)` triggers an immediate INSERT.

The fix is `GenerationType.SEQUENCE` combined with a database sequence object and a generous `allocationSize`. With `@SequenceGenerator(name="order_seq", allocationSize=50)`, Hibernate fetches the next value from the sequence (which the database increments by 50 each time), then assigns IDs in-memory from the local pool of 50, and only calls the sequence again when that pool is exhausted. Since Hibernate now knows all the IDs upfront, it can collect 50 persists and send them as a single batched INSERT, reducing 50 round trips to approximately 2 (one sequence call, one batch INSERT).

To enable JDBC batching in Spring Boot I also set `spring.jpa.properties.hibernate.jdbc.batch_size=50` and optionally `hibernate.order_inserts=true` to group INSERTs of the same entity type together.

> **Gotcha follow-up:** Does TABLE strategy avoid the batching problem?
> No — TABLE strategy uses a database table to simulate a sequence (for portability across databases without native sequence support). It also requires a SELECT and UPDATE on the key table for each allocation, which is even heavier than SEQUENCE. It also takes row-level locks on the key table, causing contention. TABLE strategy is generally discouraged. Use SEQUENCE for databases that support it (PostgreSQL, Oracle, H2), and consider UUID generation for databases that do not.

---

**Q4: What is Hibernate's second-level cache? How does it differ from the first-level cache?**
*Concept Check*

**One-line answer:** The first-level cache (L1) is per-EntityManager — it deduplicates entity lookups within one transaction; the second-level cache (L2) is shared across all EntityManagers and transactions — it caches entity state in memory (using EhCache or Caffeine) to avoid repeated database reads across different requests.

**Full answer:**
Every Hibernate EntityManager (JPA persistence context) has a built-in first-level cache. Within a single transaction, if I call `entityManager.find(Order.class, 42L)` twice, Hibernate returns the same Java object the second time without hitting the database — it looks up the entity by its ID in the L1 cache first. The L1 cache is always on, requires no configuration, and is automatically cleared when the EntityManager is closed (at transaction end). It does not survive across requests.

The second-level cache (L2C) is a shared, cross-transaction cache at the SessionFactory level (the JPA EntityManagerFactory). When an entity is marked with `@Cache(usage = CacheConcurrencyStrategy.READ_WRITE)` (or READ_ONLY for immutable data), Hibernate stores the entity's state in the L2C after loading it. The next EntityManager that needs the same entity by primary key checks the L2C first before issuing a SELECT. Because L2C lives outside any individual transaction, it survives across requests and can serve many concurrent users.

Configuring L2C requires adding a cache provider as a dependency (EhCache, Caffeine, or Hazelcast), enabling it with `hibernate.cache.use_second_level_cache=true`, and annotating the entities or collections I want cached. I choose `READ_ONLY` for reference data (countries, product categories) that never changes, and `READ_WRITE` for entities that can be updated — Hibernate uses soft locks to ensure cache coherency.

The L2C does not replace JPQL query result caching — for that I also enable `hibernate.cache.use_query_cache=true` and add `.setHint("org.hibernate.cacheable", true)` to specific queries.

> **Gotcha follow-up:** What is the risk of L2C in a clustered environment?
> In a multi-node application, each JVM has its own L2C instance. An update on node A invalidates its local cache, but node B's cache still holds stale data. The fix is to use a distributed cache provider (Hazelcast, Redis, or Infinispan) as the L2C adapter, so invalidation events propagate across nodes. Alternatively, use READ_ONLY for data that truly never changes and avoid READ_WRITE for frequently updated entities in a cluster.

---

**Q5: What do @DynamicUpdate, @Immutable, and @Formula do in Hibernate?**
*Concept Check*

**One-line answer:** @DynamicUpdate makes Hibernate include only changed columns in the UPDATE SQL (not all columns); @Immutable tells Hibernate an entity is never modified so it can skip dirty checking and DML entirely; @Formula maps a read-only derived field to a SQL expression evaluated at query time.

**Full answer:**
These three annotations each tune Hibernate's default behaviour for specific scenarios.

**@DynamicUpdate** changes how Hibernate generates UPDATE statements. By default, even if only one field of a 20-column entity changed, Hibernate generates `UPDATE table SET col1=?, col2=?, ..., col20=?` with all columns. This is safe but can cause unnecessary write amplification — especially if the table has triggers on specific columns or if many columns are indexed. With `@DynamicUpdate`, Hibernate inspects the dirty fields at flush time and generates a more targeted `UPDATE table SET changedCol=? WHERE id=?`. The tradeoff is that Hibernate cannot pre-compile and reuse the statement as a cached PreparedStatement, so there is a per-flush cost to building the dynamic SQL. I use it for wide entities where write amplification matters.

**@Immutable** marks an entity (or a collection) as read-only. Hibernate will never attempt to INSERT, UPDATE, or DELETE it — you can only load and query the data. This is useful for database views, audit log tables, or reference data tables that the application reads but never modifies. Hibernate skips dirty checking entirely for immutable entities, which saves CPU at flush time. Attempting to modify an immutable entity throws a `HibernateException`.

**@Formula** maps a field to a SQL expression rather than a column. For example: `@Formula("(SELECT COUNT(*) FROM order_item oi WHERE oi.order_id = id)")` creates a read-only field on an Order entity that is populated by a subquery whenever the entity is loaded. The SQL expression is embedded verbatim into the SELECT, so it is evaluated by the database. I use @Formula for computed aggregates, status expressions, or denormalized values that I want to access as entity fields without creating a separate query. Since it is read-only, Hibernate never writes it back to the database.

> **Gotcha follow-up:** Does @DynamicUpdate improve performance or hurt it?
> It depends. @DynamicUpdate reduces write amplification (fewer bytes to the database, fewer index updates) but prevents Hibernate from caching the PreparedStatement for that entity type, since each flush may produce a different SQL string. For wide entities on write-heavy paths with many indexed columns, @DynamicUpdate is a net win. For narrow entities or heavy insert/update workloads, the dynamic SQL generation overhead can exceed the savings. Profile first.

---

**Common Mistakes:**
- **Relying on dirty checking to save after detach** → A detached entity is not tracked; you must call `merge()` to reattach it. Modifying a detached entity and returning does nothing.
- **Using JOIN FETCH on two collections simultaneously** → causes a Cartesian product. Use separate queries for each collection, or @BatchSize.
- **Leaving IDENTITY strategy on entities that are bulk-inserted** → use SEQUENCE with allocationSize to enable batching.

**Quick Revision:** L1 = per-session, always on; L2 = shared, opt-in per entity; dirty checking = auto-UPDATE for managed entities; SEQUENCE = batch-friendly ID generation.

---

## Section 8: Must-Know Config Snippets

> *Reading guide: Being able to explain the reasoning behind each configuration value — not just recite it — is what separates a senior engineer from someone who copied a Stack Overflow answer. For each snippet, understand the unit of each value and why it is set that way.*

**Q1: How do you configure HikariCP for production? Why is max-lifetime important?**
*Design Scenario*

**One-line answer:** HikariCP is the connection pool Spring Boot uses by default — you configure pool size, idle behaviour, and lifetimes to balance resource utilisation and reliability; max-lifetime prevents connections from being returned to clients after the database server has silently closed them.

**Full answer:**
HikariCP (named after the Japanese word for "light") is a high-performance JDBC connection pool that manages a fixed number of database connections and lends them to application threads on demand. Here is a production-ready configuration and the reasoning behind each property:

```yaml
spring.datasource.hikari:
  maximum-pool-size: 10
  minimum-idle: 5
  idle-timeout: 600000
  max-lifetime: 1800000
  connection-timeout: 30000
  leak-detection-threshold: 60000
```

**maximum-pool-size: 10** — The total number of connections HikariCP maintains. I set this based on the formula: number of CPU cores × 2 + number of disk spindles, capped by what the database server can handle. Counterintuitively, making the pool too large degrades performance because of context-switching overhead and database-side connection management. For a typical 4-core application server, 10 is a reasonable starting point.

**minimum-idle: 5** — The minimum number of connections to keep open even during low traffic, so the pool does not have to create new connections (which involves a TCP handshake and database authentication handshake) when a sudden traffic spike arrives. Set this to about half of maximum-pool-size.

**idle-timeout: 600000** — 10 minutes in milliseconds. Connections that have been idle for 10 minutes are closed, down to the minimum-idle count. This reclaims database resources during quiet periods.

**max-lifetime: 1800000** — 30 minutes in milliseconds. This is the most critical setting for reliability. Most databases have a `wait_timeout` (MySQL default: 8 hours; many cloud databases: 10–30 minutes) after which they silently close idle connections from their end. If HikariCP holds a connection longer than the database's timeout, the next attempt to use it will get a "connection closed" error. By setting max-lifetime to less than the database's wait_timeout, HikariCP proactively retires connections before the database closes them. I always set max-lifetime to at least 30 seconds less than the database's wait_timeout.

**connection-timeout: 30000** — 30 seconds. How long an application thread waits for HikariCP to provide a connection before throwing `SQLTimeoutException`. I set this to a value that triggers a fast-fail before the upstream HTTP request times out.

**leak-detection-threshold: 60000** — 60 seconds. If a connection is held by a thread for more than 60 seconds without being returned, HikariCP logs a warning with the stack trace of the code that borrowed it. Invaluable for finding connection leaks in development.

*In an interview, lead with "max-lifetime must be less than the database's wait_timeout" — this is the production reliability insight most candidates miss.*

> **Gotcha follow-up:** What happens if maximum-pool-size is too large?
> With too many connections, the database server CPU spends more time on context switching between connection handling threads than on actual query execution. The TPS (transactions per second) actually decreases beyond a certain pool size. The Hikari documentation references the "pool sizing for OLTP" article, which recommends surprisingly small pools — sometimes fewer than the number of CPUs.

---

**Q2: How would you implement an audit log that persists even if the main transaction rolls back?**
*Design Scenario*

**One-line answer:** Annotate the audit logging method with `@Transactional(propagation = Propagation.REQUIRES_NEW)` so it runs in its own independent transaction that commits before control returns to the outer transaction.

**Full answer:**
The requirement is that audit records must be durable regardless of business transaction outcome — even a failed, rolled-back order placement should leave a trace. This is a textbook REQUIRES_NEW use case.

```java
@Service
public class OrderService {

    @Autowired
    private OrderRepository orderRepo;

    @Autowired
    private AuditService auditService; // separate bean — key to avoiding self-invocation

    @Transactional // REQUIRED (default) — outer transaction
    public Order placeOrder(OrderRequest req) {
        Order order = orderRepo.save(new Order(req));
        auditService.log(order); // called through proxy — REQUIRES_NEW applies
        // if this throws, outer TX rolls back, but audit log is already committed
        return order;
    }
}

@Service
public class AuditService {

    @Autowired
    private AuditRepository auditRepo;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void log(Order order) {
        auditRepo.save(new AuditLog(order)); // commits independently
    }
}
```

The critical design point: `auditService` is a separate Spring bean, not a method on the same class. This ensures the call goes through the Spring proxy, so the REQUIRES_NEW propagation actually takes effect. When `auditService.log(order)` is called, Spring suspends the outer transaction, opens a new transaction for `log()`, commits the AuditLog row to the database, and then resumes the outer transaction. If the outer transaction later throws and rolls back, the AuditLog row is already committed and unaffected.

One nuance: the Order passed to `log()` is managed in the outer transaction. Inside the REQUIRES_NEW context, if I try to navigate any lazy associations of that Order, I may get a LazyInitializationException because the outer EntityManager is suspended. I handle this by extracting only the scalar values I need (order ID, user ID, timestamp) before calling log(), or by accepting a simple DTO.

> **Gotcha follow-up:** What if the REQUIRES_NEW transaction itself fails?
> The exception propagates back to the caller. In the example above, if `auditRepo.save()` throws, that exception surfaces in `placeOrder()`. The outer transaction is still active (it was suspended, not rolled back). If I want the outer transaction to continue even when auditing fails, I wrap the `auditService.log(order)` call in a try-catch and log the failure rather than re-throwing.

---

**Q3: Show how to use @EntityGraph to solve N+1 on an Order entity with Customer and OrderItems.**
*Design Scenario*

**One-line answer:** Annotate the repository query method with `@EntityGraph(attributePaths = {"customer", "items"})` so Spring generates a JOIN FETCH for both associations in a single SQL query instead of one SELECT per Order.

**Full answer:**
Without @EntityGraph, when I call `findByStatus("PENDING")` and then access `order.getCustomer()` and `order.getItems()` for each order, Hibernate issues one SELECT for the orders, then one SELECT per order for the customer, then one SELECT per order for the items — producing 2N+1 queries for N orders.

The fix using Spring Data JPA @EntityGraph:

```java
public interface OrderRepository extends JpaRepository<Order, Long> {

    @EntityGraph(attributePaths = {"customer", "items"})
    List<Order> findByStatus(String status);
}
```

Spring Data translates this annotation into a JPQL query with a JOIN FETCH for both `customer` and `items`. The resulting SQL is a single `SELECT` with LEFT OUTER JOINs. All data comes back in one round trip.

A caveat worth mentioning in interviews: fetching two collections (customer is a many-to-one, but items is a one-to-many) in the same query can produce duplicate Order rows in the SQL result set (one row per item). Spring Data and Hibernate handle this via `DISTINCT` in the query, but if I am fetching multiple one-to-many collections simultaneously, I risk a Cartesian product that creates excessive data transfer. For the common case of one many-to-one and one one-to-many, @EntityGraph with both paths is usually fine.

For named entity graphs (reusable across multiple repository methods), I can define the graph on the entity itself:

```java
@Entity
@NamedEntityGraph(name = "Order.withCustomerAndItems",
    attributeNodes = {
        @NamedAttributeNode("customer"),
        @NamedAttributeNode("items")
    })
public class Order { ... }
```

And reference it by name: `@EntityGraph("Order.withCustomerAndItems")`.

> **Gotcha follow-up:** When would you use @BatchSize instead of @EntityGraph?
> When the access pattern is not uniform — sometimes I access the collection, sometimes I do not. @EntityGraph always fetches the association, even when the calling code will not use it. @BatchSize defers the fetch until actually needed and then batches multiple lazy loads together. For a detail page that always shows items, @EntityGraph is better. For a list page where only some items are expanded, @BatchSize is more efficient.

---

**Q4: How do you write a projection query and a modifying query in Spring Data JPA?**
*Design Scenario*

**One-line answer:** Use a projection interface to select only needed columns (avoiding loading full entities), and annotate bulk UPDATE/DELETE queries with both @Modifying and @Transactional to bypass entity lifecycle management.

**Full answer:**
Two powerful but often misused Spring Data JPA features:

**Projection interface** for a read-only subset of columns:

```java
// Projection interface — Spring generates a proxy implementing this at runtime
public interface ProductSummary {
    Long getId();
    String getName();
}

public interface ProductRepository extends JpaRepository<Product, Long> {

    @Query("SELECT p.id AS id, p.name AS name FROM Product p WHERE p.category = :category")
    List<ProductSummary> findSummariesByCategory(@Param("category") String category);
}
```

The JPQL SELECT must use aliases that match the getter names in the interface (`p.id AS id` matches `getId()`). Spring Data creates a proxy at runtime that implements the interface and delegates each getter to the corresponding value in the query result. This avoids loading the full entity (including columns I do not need) and bypasses Hibernate's dirty checking for those results since they are not managed entities.

**Modifying query** for bulk UPDATE or DELETE:

```java
@Modifying
@Transactional
@Query("UPDATE Product p SET p.active = false WHERE p.expiresAt < :now")
int deactivateExpired(@Param("now") LocalDateTime now);
```

`@Modifying` tells Spring Data that this query modifies the database rather than returning results — without it, Spring attempts to map the query to entities and fails. The `@Transactional` annotation is required here because modifying queries must run within a transaction; if the repository method is called from an already-transactional service, it joins that transaction. The return type `int` is the number of rows affected.

Important nuance: `@Modifying` bypasses the Hibernate entity lifecycle. If I have Product entities loaded in the current EntityManager and then run a bulk UPDATE via @Modifying, those in-memory entities are stale — they still show `active = true`. I should add `@Modifying(clearAutomatically = true)` to force Hibernate to clear its first-level cache after the update, ensuring subsequent queries see fresh data.

> **Gotcha follow-up:** What is the difference between a closed and open projection?
> A closed projection uses a projection interface where all methods reference entity fields — Hibernate can optimise the SQL to select only those columns. An open projection uses a @Value SpEL expression that may reference multiple fields (`@Value("#{target.firstName + ' ' + target.lastName}"`) — Hibernate cannot optimise this and loads the full entity, then applies the expression. Prefer closed projections for performance.

---

**Q5: Walk through a stateless Spring Security filter chain configuration for a JWT-based API.**
*Design Scenario*

**One-line answer:** Configure Spring Security to disable CSRF (unnecessary without server-side sessions), set session creation to STATELESS, declare URL-level authorization rules, and register the JWT validation filter before the standard username-password filter.

**Full answer:**
A JWT-based REST API is stateless — each request carries its own authentication token in the Authorization header, so the server does not maintain session state. The Spring Security configuration must reflect this:

```java
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .csrf(AbstractHttpConfigurer::disable)
        .sessionManagement(sm ->
            sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/actuator/health").permitAll()
            .requestMatchers("/api/admin/**").hasRole("ADMIN")
            .anyRequest().authenticated())
        .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
    return http.build();
}
```

Walking through each line:

**`.csrf(AbstractHttpConfigurer::disable)`** — CSRF (Cross-Site Request Forgery) protection works by embedding a token in HTML forms that the server verifies. It protects browser-based sessions where a malicious site could submit forms using the user's session cookie. A stateless JWT API does not use cookies for authentication, so there is no CSRF attack surface. Disabling it removes unnecessary overhead.

**`.sessionCreationPolicy(SessionCreationPolicy.STATELESS)`** — This tells Spring Security never to create or consult the HTTP session. Without this, Spring Security might create a session after successful authentication, which wastes server memory and conflicts with horizontal scaling. STATELESS means every request must be independently authenticated.

**`.requestMatchers("/actuator/health").permitAll()`** — The health endpoint must be reachable by load balancers without a token. I always permit this first.

**`.requestMatchers("/api/admin/**").hasRole("ADMIN")`** — All URLs under /api/admin require the ADMIN role. Spring Security prefixes role names with "ROLE_" internally, so `hasRole("ADMIN")` checks for the authority "ROLE_ADMIN".

**`.anyRequest().authenticated()`** — Any request not matched by the earlier rules must be authenticated. Ordering matters: Spring Security evaluates matchers top-to-bottom, so specific rules go first.

**`.addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)`** — This registers my custom `JwtAuthFilter` (which reads the Authorization header, validates the JWT, and sets the `SecurityContext`) so it runs before Spring's default username-password filter. If the JWT is valid, the SecurityContext is populated and downstream authorization rules see the user's roles.

*Be ready to explain what jwtAuthFilter does inside — it reads the Bearer token, validates the signature and expiry, loads the UserDetails, and calls `SecurityContextHolder.getContext().setAuthentication(token)`.*

> **Gotcha follow-up:** Why should the JWT signing key be kept secret and rotated?
> The JWT signature is what prevents clients from forging tokens with fake roles or user IDs. If the signing key is compromised, an attacker can issue valid-looking tokens for any user or role. Rotating the key invalidates all existing tokens (users must re-authenticate), which is disruptive, so key rotation is typically paired with a grace period where both old and new keys are accepted. For high-security applications, use asymmetric signing (RS256 or ES256) — the private key signs tokens on the auth server, and the public key verifies them on all service instances, so service instances never need access to the signing secret.

---

**Common Mistakes:**
- **Not disabling CSRF for stateless APIs** → Spring Security's CSRF filter blocks POST/PUT/DELETE requests that do not include a CSRF token, causing 403 errors for all write operations from API clients.
- **Forgetting STATELESS session policy** → Spring creates HTTP sessions, breaking horizontal scalability and consuming memory on sticky-session-dependent infrastructure.
- **Putting anyRequest().authenticated() before specific rules** → it matches everything, making all subsequent matchers unreachable. Always put the catch-all last.
- **Forgetting @Modifying on bulk JPQL updates** → Spring Data throws an exception at runtime because it tries to map the query result to entities.

**Quick Revision:** JWT filter chain = no CSRF + STATELESS + specific matchers first + custom filter before UsernamePasswordAuthenticationFilter.

---

## Quick-Hit Mnemonics

> *These mnemonics compress high-density material into memorable hooks. Each one is explained so you can reconstruct the full concept from the mnemonic alone.*

---

**Bean Scopes: S-P-R-S-A**

**Singleton – Prototype – Request – Session – Application**

- **Singleton**: one instance per Spring ApplicationContext (the default). Most service and repository beans are singletons.
- **Prototype**: a new instance every time the bean is requested from the context. Use for stateful beans that should not be shared.
- **Request**: one instance per HTTP request. Requires a web-aware ApplicationContext.
- **Session**: one instance per HTTP session. Persists across multiple requests from the same user.
- **Application**: one instance per ServletContext (effectively per application, like singleton but scoped to the web layer).

*Why this mnemonic works*: the five scopes go from broadest (Singleton, shared by everyone) to narrowest (Application, which in practice behaves like a web-scoped singleton), then back up through web-specific scopes. Reading the acronym aloud — "S-P-R-S-A" — gives you the full list in under a second.

---

**Bean Lifecycle: I-P-A-B-I-B**

**Instantiate – Populate – Aware callbacks – BeanPostProcessor (before) – Init – BeanPostProcessor (after)**

This is the order Spring executes when creating a bean: first the constructor runs (Instantiate), then dependency injection happens (Populate fields/setters), then Aware interfaces are called (BeanNameAware, ApplicationContextAware, etc. — these give the bean a reference to its Spring context), then BeanPostProcessors run their `postProcessBeforeInitialization` method, then the init method runs (@PostConstruct or `InitializingBean.afterPropertiesSet()`), and finally BeanPostProcessors run their `postProcessAfterInitialization`.

*Why this matters*: understanding the order tells you that @PostConstruct runs after dependency injection is complete, so all injected dependencies are available. BeanPostProcessors after init is where AOP proxies are created — which explains why @Transactional etc. is woven in at the very end of the lifecycle.

---

**Propagation: REQUIRED = join the party; REQUIRES_NEW = bring your own room**

REQUIRED finds the existing party (transaction) and joins it — same commit, same rollback. REQUIRES_NEW ignores any existing party, books a private room (separate transaction), and closes the door — commits and rolls back independently. NESTED creates a private corner *within* the same party room — you can clean up your corner without ending the party, but if the host ends the party (outer rollback), your corner goes too.

---

**IDENTITY kills batching → use SEQUENCE**

IDENTITY = the database auto-assigns the key → Hibernate must INSERT one row at a time to get each key back → batching disabled. SEQUENCE = Hibernate pre-fetches a block of IDs from the database sequence → knows all IDs upfront → can batch all INSERTs together. Rule: *never use IDENTITY on entities that will be bulk-inserted; always use SEQUENCE with a sensible allocationSize (25–100).*

---

**OSIV=false: close the session early, load in service layer**

Open Session in View keeps the Hibernate EntityManager alive through the entire HTTP request (including JSON serialisation) to prevent LazyInitializationException. But it holds a database connection open for the whole request duration — under load, this exhausts the connection pool. Setting `spring.jpa.open-in-view=false` closes the session as soon as the @Transactional service method returns, forcing you to load everything you need inside the transaction. This is the correct pattern for production applications: load eagerly in the service layer, release the connection early.

---

**N+1 Fix Hierarchy: JOIN FETCH > @EntityGraph > @BatchSize > @Fetch(SUBSELECT)**

Choose the leftmost option that fits your access pattern:
- **JOIN FETCH** (JPQL): single SQL JOIN, best performance, use when the association is always needed and there is only one collection.
- **@EntityGraph** (repository annotation): same as JOIN FETCH but declarative — cleaner for Spring Data JPA repositories.
- **@BatchSize** (entity annotation): reduces N queries to N/batch queries using `IN` clause — best when associations are sometimes accessed lazily.
- **@Fetch(SUBSELECT)** (Hibernate annotation): loads all collections in one subselect query — useful when the full collection is always needed for all loaded parents, but can be heavy on large result sets.

