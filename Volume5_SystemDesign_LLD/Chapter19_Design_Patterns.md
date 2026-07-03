# Volume 5: System Design & LLD
# Chapter 19: Design Patterns

---

## Table of Contents

- Topic 1: Singleton Pattern
- Topic 2: Factory Method & Abstract Factory
- Topic 3: Builder Pattern
- Topic 4: Prototype Pattern
- Topic 5: Adapter Pattern
- Topic 6: Decorator Pattern
- Topic 7: Facade Pattern
- Topic 8: Proxy Pattern
- Topic 9: Observer Pattern
- Topic 10: Strategy Pattern
- Topic 11: Template Method Pattern
- Topic 12: Command Pattern
- Topic 13: Chain of Responsibility
- Topic 14: State Pattern
- Topic 15: Composite & Iterator Patterns

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: Singleton Pattern

#### The Idea
Imagine a company has exactly one CEO. No matter how many employees ask "who's the CEO?", they all get the same person — there's no second CEO created for each question. The Singleton pattern does the same for objects: it guarantees that only one instance of a class ever exists in your program, and every caller gets that exact same instance.

This is useful for things that represent a single shared resource — a database connection pool, a configuration loader, or a logging service. You don't want two independent config objects with different settings coexisting. You want one authoritative source.

The tricky part is making this work safely in a multi-threaded world, where two threads might both try to create the "first" instance at the same moment.

#### How It Works

There are four main approaches, roughly from simplest to most robust:

```
// 1. Eager init — JVM creates instance at class load time
// Thread-safe by default, but no lazy loading
static final X INSTANCE = new X();

// 2. Synchronized method — thread-safe but locks every call
// Performance bottleneck under high concurrency
static synchronized X getInstance() { ... }

// 3. Double-Checked Locking (DCL) — fast path avoids lock
// Check null → sync block → check null again → create
// Requires volatile (see code block below)

// 4. Enum Singleton — JVM guarantees one instance
// Serialization-safe, reflection-safe, preferred by Effective Java
enum Config { INSTANCE; }

// Bill Pugh / Initialization-on-demand holder
// Lazy + thread-safe via JVM class initialization guarantee, zero sync cost
class X {
    private static class Holder {
        static final X INSTANCE = new X();
    }
    public static X getInstance() { return Holder.INSTANCE; }
}
```

**Why `volatile` is mandatory in DCL:** Without it, the JVM may reorder instructions as: allocate memory → assign reference → construct object. A second thread sees a non-null reference but reads an unconstructed object. `volatile` prevents this reordering.

```java
public class ConfigManager {
    private static volatile ConfigManager instance;
    private ConfigManager() {}
    public static ConfigManager getInstance() {
        if (instance == null) {
            synchronized (ConfigManager.class) {
                if (instance == null) {
                    instance = new ConfigManager();
                }
            }
        }
        return instance;
    }
}
```

**Spring note:** `@Scope("singleton")` means one instance per `ApplicationContext`, not per JVM. Two `ApplicationContext`s = two instances.

**Serialization breaks non-enum Singletons** — fix with `readResolve()`. Reflection can bypass a private constructor — enum prevents this entirely.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview. Every concept is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods.*

---

**Q1 — Concept Check**
**"Why do you need `volatile` in the Double-Checked Locking Singleton?"**

**One-line answer:** Without `volatile`, the JVM can reorder object construction so another thread sees a non-null but partially constructed instance.

**Full answer:**
> "When you write `instance = new ConfigManager()`, the JVM breaks that into three steps: allocate memory, assign the reference to `instance`, then run the constructor. Without `volatile`, the JIT can reorder steps 2 and 3 — so `instance` becomes non-null before the object is fully built. A second thread passes the first null-check, skips the `synchronized` block, and reads a broken object. `volatile` adds a memory barrier that forces happens-before ordering: the constructor must complete before the reference is published."

> *Draw the three-step sequence on a whiteboard if available — it makes the reordering concrete.*

**Gotcha follow-up:** *"Is there a simpler Singleton implementation that avoids the `volatile` issue entirely?"*
> "Yes — the Bill Pugh holder idiom. A private static inner class `Holder` contains `static final X INSTANCE = new X()`. The JVM only initializes `Holder` when `getInstance()` is first called, and class initialization is inherently thread-safe. No `synchronized`, no `volatile`, lazy loading, zero overhead."

---

**Q2 — Tradeoff Question**
**"When would you choose Enum Singleton over Double-Checked Locking?"**

**One-line answer:** Enum is safer against serialization and reflection attacks; DCL is needed when you can't use an enum (e.g., the class must extend another class).

**Full answer:**
> "Enum Singleton is the Effective Java recommendation precisely because the JVM provides two guarantees for free: serialization always returns the same instance (no `readResolve` needed), and reflection cannot create a second instance — attempting to call `newInstance()` on an enum throws an exception. DCL gives you lazy initialization with a specific superclass, but you have to manually handle both risks. In a security-conscious or persistence-heavy system, I'd default to enum unless inheritance forces my hand."

> *Mention Effective Java Item 3 by name — it signals you read the book.*

**Gotcha follow-up:** *"Spring's `@Scope("singleton")` — is that the same as the GoF Singleton pattern?"*
> "No — they share the name but differ in scope. GoF Singleton is per-JVM-classloader. Spring singleton is per `ApplicationContext`. If you load two `ApplicationContext`s in the same JVM — common in tests or multi-tenant setups — you get two bean instances. Spring doesn't prevent you from instantiating the class directly either."

---

**Common Mistakes**
- **Omitting `volatile` in DCL:** leads to subtle, rarely-reproducible bugs on multi-core CPUs under heavy load.
- **Assuming Spring singleton = JVM singleton:** breaks in test suites that create multiple contexts.
- **Forgetting `readResolve()`:** deserialization creates a second instance, silently breaking the guarantee.

**Quick Revision:** Four impls — eager, sync method, DCL+volatile, enum; prefer enum or Bill Pugh holder; Spring singleton is per-ApplicationContext not per-JVM.

---

## Topic 2: Factory Method & Abstract Factory

#### The Idea
Imagine a staffing agency. A client says "I need a software engineer" — they don't specify which engineer, just the role. The agency (the factory) decides which specific person to send. Tomorrow the client might say "I need a designer" — same agency, different specialist. The client never needs to know how to hire; that knowledge lives in the agency.

Factory Method extends this: each type of "agency" (subclass) specialises in a different kind of hire. Abstract Factory goes further — it's not one specialist but a coordinated team: frontend engineer, backend engineer, and designer who are all guaranteed to work well together.

The payoff is the Open/Closed Principle: when you need a new product type, you add a new factory subclass rather than editing existing code.

#### How It Works

```
// Factory Method: subclasses decide which concrete product to create
interface DocumentParser { Document parse(InputStream in); }
class PdfParserFactory  { DocumentParser create() { return new PdfParser(); } }
class WordParserFactory { DocumentParser create() { return new WordParser(); } }

// Static factory shorthand (common in practice):
// ParserFactory.create("PDF") → concrete parser

// Abstract Factory: interface creates a FAMILY of related products
interface UIFactory {
    Button   createButton();
    Checkbox createCheckbox();
}
class MacUIFactory     implements UIFactory { ... }
class WindowsUIFactory implements UIFactory { ... }
// All products are guaranteed compatible within one factory
```

**Key difference in one line:** Factory Method creates one product type; Abstract Factory creates a suite of compatible products.

**Adding a new product type to Abstract Factory requires changing the interface** — that breaks every existing implementation. Factory Method avoids this: just add a new subclass.

```java
@Service
public class NotificationService {
    private final Map<String, NotificationFactory> factories;
    public NotificationService(Map<String, NotificationFactory> factories) {
        this.factories = factories;
    }
    public void notify(String channel, String recipient, String message) {
        factories.get(channel).createSender().send(recipient, message);
    }
}
```

Spring auto-collects all beans implementing `NotificationFactory` into a map keyed by bean name — adding a new channel means adding a new `@Component`, zero changes to `NotificationService`.

**Spring ApplicationContext = Abstract Factory:** creates `DataSource`, `Service`, `Repository`, `Controller` — all properly wired. `@Configuration` with `@Bean` methods is an Abstract Factory.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview. Every concept is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods.*

---

**Q1 — Concept Check**
**"What is the difference between Factory Method and Abstract Factory?"**

**One-line answer:** Factory Method creates one product type via a subclass override; Abstract Factory creates a family of related products via a multi-method interface.

**Full answer:**
> "Factory Method defines one `createProduct()` method; subclasses override it to return a specific concrete type. It answers: 'which exact class do I instantiate?' Abstract Factory has multiple `create*()` methods — `createButton()`, `createCheckbox()`, etc. — and one concrete factory implements the whole suite. The guarantee is compatibility: everything from one Abstract Factory works together. Factory Method is simpler but single-product; Abstract Factory coordinates a product family but is harder to extend — adding a new product type means adding a method to the interface, which breaks all existing implementations."

> *Use the Mac/Windows UI example to make it concrete: `MacFactory` returns `MacButton` and `MacCheckbox`, which share styling.*

**Gotcha follow-up:** *"How does Spring's `ApplicationContext` relate to Abstract Factory?"*
> "`ApplicationContext` is an Abstract Factory for the application's object graph. It creates and wires `DataSource`, repositories, services, controllers — a whole compatible family. A `@Configuration` class with multiple `@Bean` methods is the concrete Abstract Factory implementation. Spring resolves dependencies so you get a consistent, properly-wired set of collaborators."

---

**Q2 — Design Scenario**
**"Design a notification system that supports Email, SMS, and Push channels, with more channels added in future."**

**One-line answer:** Map channel name to a `NotificationFactory` bean; Spring auto-wires new channels with zero changes to the service.

**Full answer:**
> "I define a `NotificationFactory` interface with `createSender()`. Each channel — `EmailNotificationFactory`, `SmsNotificationFactory`, `PushNotificationFactory` — is a `@Component` implementing it. Spring collects all `NotificationFactory` beans into a `Map<String, NotificationFactory>` injected into `NotificationService`. To add Slack: create `SlackNotificationFactory`, annotate it `@Component("slack")`, done — the service never changes. This is the Factory Method pattern composed with Spring's dependency injection for runtime dispatch."

> *This answer demonstrates OCP — open for extension, closed for modification — which is what interviewers are probing for.*

**Gotcha follow-up:** *"What happens if an unknown channel name is passed?"*
> "The map lookup returns null, and calling `createSender()` on null throws `NullPointerException`. I'd add an explicit check: if the factory isn't found, throw a descriptive `IllegalArgumentException` or return a no-op sender, depending on whether an unknown channel is a programming error or a user-input case."

---

**Common Mistakes**
- **Conflating the two patterns:** Factory Method = single product + subclass; Abstract Factory = product family + interface.
- **Breaking OCP in Abstract Factory:** adding a new product type forces interface changes across all implementations.
- **Using `if/else` or `switch` on type strings:** defeats the pattern; use a registry map or Spring bean map instead.

**Quick Revision:** Factory Method → one product, subclass decides; Abstract Factory → product suite, one interface; Spring bean map = runtime factory dispatch with zero modification.

---

## Topic 3: Builder Pattern

#### The Idea
Picture ordering a custom sandwich. You don't hand the chef a list of 15 ingredients where you leave most blank — that's the "telescoping constructor" problem. Instead you say: "sourdough, turkey, no onions, extra cheese" — only what you care about, in any order, and the chef assembles it correctly at the end. That's the Builder pattern.

The deeper benefit over regular setters is that an object built via setters can exist in an invalid intermediate state — you've set the URL but not the method yet; what happens if someone uses the object now? Builder holds all values in the builder object, validates everything in `build()`, and hands you a fully valid, immutable result.

#### How It Works

```
// Telescoping constructor problem
new HttpRequest(url, null, null, null, 5000, false, null)  // which nulls are which?

// Builder solution
HttpRequest request = new HttpRequest.Builder(url)
    .method("POST")
    .timeoutMs(3000)
    .build();   // ← validation happens here, object is immutable after this
```

```java
public final class HttpRequest {
    private final String url;
    private final String method;
    private final int timeoutMs;

    private HttpRequest(Builder b) {
        this.url = b.url; this.method = b.method; this.timeoutMs = b.timeoutMs;
    }

    public static final class Builder {
        private final String url;
        private String method = "GET";
        private int timeoutMs = 5000;

        public Builder(String url) { this.url = url; }
        public Builder method(String m) { this.method = m; return this; }
        public Builder timeoutMs(int t) { this.timeoutMs = t; return this; }

        public HttpRequest build() {
            if ("POST".equals(method) && body == null)
                throw new IllegalStateException("POST requires body");
            return new HttpRequest(this);
        }
    }
}
```

**Lombok shortcuts:** `@Builder` generates the entire Builder class. `@Builder.Default` sets default field values. `toBuilder = true` enables copy-with-modification. `@SuperBuilder` handles inheritance. **JPA caveat:** Lombok `@Builder` removes the no-arg constructor — you must add `@NoArgsConstructor` + `@AllArgsConstructor` alongside `@Builder` for JPA entities.

Cross-field validation (e.g., POST requires body) belongs in `build()`, not in the setter methods — setters don't know the full state yet.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview. Every concept is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods.*

---

**Q1 — Concept Check**
**"Why use Builder instead of just setters?"**

**One-line answer:** Setters allow invalid intermediate state and prevent immutability; Builder validates all fields atomically in `build()` and produces a fully immutable object.

**Full answer:**
> "With setters, the moment you call `new HttpRequest()`, you have an object that exists but is incomplete — URL not set, method not set. Any code that gets a reference before you finish calling setters can observe invalid state. Builder avoids this: the `Builder` object accumulates all parameters, `build()` validates cross-field constraints like 'POST requires a body', and only then constructs the product. Since all fields are final on the product, the result is immutable — safe to share across threads. Setters also force you to expose mutation on the final object; Builder lets you make the class completely final."

> *Mention that this eliminates the 'what if someone calls the object before it's ready?' class of bugs.*

**Gotcha follow-up:** *"What's the JPA problem with Lombok's `@Builder`?"*
> "Lombok `@Builder` generates a package-private all-args constructor and no no-arg constructor. JPA requires a no-arg constructor to instantiate entities when loading from the database. The fix is to add `@NoArgsConstructor` and `@AllArgsConstructor` alongside `@Builder` — `@AllArgsConstructor` gives Lombok the constructor it needs to build from, and `@NoArgsConstructor` satisfies JPA."

---

**Q2 — Tradeoff Question**
**"When is Builder overkill?"**

**One-line answer:** When the class has two or fewer parameters, a simple constructor or static factory is cleaner.

**Full answer:**
> "Builder adds a static inner class, multiple setter-style methods, and a `build()` call — meaningful boilerplate for a simple value object with one or two fields. The threshold I use: three or more parameters, especially if some are optional or of the same type (where positional confusion is a real risk), is when Builder pays off. For a `Point(x, y)` class, a constructor is cleaner. For an `HttpRequest` with URL, method, headers, timeout, retry count, and body, Builder is clearly better — the positional argument problem alone justifies it."

> *Effective Java Item 2 frames this precisely — cite it if you can.*

**Gotcha follow-up:** *"Where does cross-field validation go in a Builder?"*
> "In `build()`, not in the individual setter methods. Each setter sees only one field in isolation — it can't know whether a constraint involving two fields is violated yet. `build()` is the one place where all fields are known simultaneously, so it's the right place to throw `IllegalStateException` for constraints like 'startDate must be before endDate' or 'POST requires body'."

---

**Common Mistakes**
- **Putting cross-field validation in setters:** setters see partial state; constraints involving multiple fields will fire incorrectly.
- **Forgetting `@NoArgsConstructor` with Lombok `@Builder` on JPA entities:** causes `InstantiationException` at runtime when JPA tries to load rows.
- **Mutable product fields:** if the product class has non-final fields, you've built an immutable API wrapper around a mutable object — defensive copies are still needed for collections.

**Quick Revision:** Builder = accumulate in builder, validate in `build()`, produce immutable product; Lombok `@Builder` + JPA = must add `@NoArgsConstructor` + `@AllArgsConstructor`.

---

## Topic 4: Prototype Pattern

#### The Idea
Think of a rubber stamp. You carve one master stamp, then press copies onto paper as fast as you like — each impression is independent; writing on one copy doesn't affect another. The Prototype pattern does this for objects: instead of building a new instance from scratch (which may be expensive — reading config files, calling databases, doing complex setup), you copy an existing one.

The critical distinction is shallow vs deep copy. A shallow copy is like photocopying a page that contains a sticky note pointing to a filing cabinet — your copy has the same sticky note pointing to the same cabinet. A deep copy recreates the cabinet too, so each copy is fully independent.

#### How It Works

```
// Shallow clone: primitive fields copied by value,
// reference fields still point to the SAME nested objects
// → mutating clone.sections affects original.sections

// Deep clone: all nested objects are also copied
// → clone and original are fully independent

// Java's Cloneable pitfalls:
// - marker interface with no method
// - Object.clone() is protected — must override and make public
// - shallow by default
// - final fields incompatible with clone()
// - throws CloneNotSupportedException
// - constructor not called (can break invariants)
// → Prefer copy constructor instead
```

```java
public class ReportTemplate {
    private final String name;
    private final List<Section> sections;

    // Copy constructor — explicit deep copy
    public ReportTemplate(ReportTemplate other) {
        this.name = other.name;
        this.sections = other.sections.stream()
            .map(Section::new)  // Section copy constructor
            .collect(Collectors.toCollection(ArrayList::new));
    }
}
```

**Why copy constructor beats `Cloneable`:** explicit, works with `final` fields, no checked exception, no reflection magic, self-documenting.

**Spring `@Scope("prototype")`:** not a clone — Spring creates a fresh instance via constructor for every injection point. Unrelated to the GoF Prototype pattern despite the name.

**Serialization-based deep clone:** works if all fields are `Serializable`, but is expensive (serialize to bytes, deserialize back) and ties your cloneability to your serialization contract.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview. Every concept is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods.*

---

**Q1 — Concept Check**
**"What's wrong with Java's `Cloneable` interface?"**

**One-line answer:** It's a broken API — marker interface with no method, `Object.clone()` is protected, shallow by default, incompatible with `final` fields, and skips the constructor.

**Full answer:**
> "`Cloneable` was a design mistake acknowledged in Effective Java. First, it's a marker interface — it has no `clone()` method to implement; you have to override `Object.clone()` which is `protected`, call `super.clone()`, cast the result, and handle `CloneNotSupportedException`. Second, the default behavior is a shallow copy — reference fields point to the same nested objects, so modifying the clone's list modifies the original's list. Third, `final` fields can't be reassigned after `super.clone()`, so deep copying an object with `final` mutable fields is impossible via `clone()`. Fourth, `Object.clone()` doesn't call the constructor, which means any invariants established in the constructor are bypassed. A copy constructor solves all of these: explicit, works with `final` fields, no exceptions, calls the constructor normally."

> *Cite Effective Java Item 13 if you know it.*

**Gotcha follow-up:** *"Is Spring's `@Scope("prototype")` related to the Prototype design pattern?"*
> "They share the name but the mechanism is different. Spring prototype scope creates a fresh instance via the constructor every time a bean is requested — it doesn't clone an existing object. The GoF Prototype pattern copies an existing instance to avoid expensive re-initialization. Spring's naming is a conceptual analogy — 'give me a new one from the prototype definition' — not an implementation of the pattern."

---

**Q2 — Tradeoff Question**
**"When would you use Prototype over just calling `new`?"**

**One-line answer:** When constructing an object is expensive and you already have a valid instance whose state you want to start from.

**Full answer:**
> "The classic case is an object whose initialization involves I/O — reading a config file, loading a template from a database, pre-computing a large data structure. Once you have one valid instance, cloning it is far cheaper than rebuilding from scratch. A concrete example: a `ReportTemplate` that parses a large XML schema on construction. If you need 50 report instances from the same template, copy-constructing from one parsed instance avoids 49 XML parse operations. The alternative — calling `new` 50 times — would hit disk or network 50 times."

> *Contrast with Builder: Builder is about assembling from parameters; Prototype is about duplicating from an existing valid state.*

**Gotcha follow-up:** *"What's the danger of returning a shallow copy from a `clone()` method?"*
> "Any caller that modifies a mutable field on their copy — like adding an element to a list — also modifies the original, because both references point to the same underlying object. This breaks the independence guarantee that callers expect from a copy. The bug is particularly insidious because it appears only when the clone is mutated, which may happen long after it was created and in a completely different part of the code."

---

**Common Mistakes**
- **Implementing `Cloneable` and not doing a deep copy:** mutable nested fields are shared, leading to aliasing bugs.
- **Assuming `@Scope("prototype")` is a GoF Prototype:** Spring creates fresh instances; it does not clone.
- **Using serialization-based clone without checking `Serializable` on all fields:** throws `NotSerializableException` at runtime, often on a third-party field you don't control.

**Quick Revision:** Prototype = copy existing instance; prefer copy constructor over `Cloneable`; shallow copy shares references (dangerous for mutable fields); Spring `@Scope("prototype")` = new instance, not a clone.

---

## Topic 5: Adapter Pattern

#### The Idea
Picture a traveller from the US plugging a US-socket device into a UK wall outlet. The voltage and plug shape are different — they're incompatible interfaces. A travel adapter sits in between: it accepts the UK socket on one side and presents a US socket on the other. Neither the device nor the wall changes; the adapter translates between them.

That's exactly the Adapter pattern. You have a client that expects one interface and a class (often a third-party library) that provides a different interface. You write an adapter that implements the interface the client expects, and internally delegates to the incompatible class.

#### How It Works

```
// Object Adapter (preferred in Java — uses composition)
// Implements the Target interface the client expects.
// Holds the Adaptee as a field.
// Delegates to Adaptee, translating types along the way.

// Class Adapter: uses multiple inheritance
// Not idiomatic in Java (no multiple class inheritance) — avoid.

interface PaymentProcessor {
    PaymentResponse processPayment(PaymentRequest request);
}

class LegacyPaymentGateway {
    // Different method name, different parameter types
    String charge(String customerId, double amount, String currency);
}
```

```java
public class LegacyPaymentAdapter implements PaymentProcessor {
    private final LegacyPaymentGateway gateway;  // composition

    public LegacyPaymentAdapter(LegacyPaymentGateway gateway) {
        this.gateway = gateway;
    }

    @Override
    public PaymentResponse processPayment(PaymentRequest request) {
        // Translate: new API → legacy API
        String chargeId = gateway.charge(
            request.customerId(),
            request.amount().doubleValue(),   // BigDecimal → double
            request.currency()
        );
        // Translate: legacy response → domain object
        return new PaymentResponse(chargeId, "SUCCESS", request.amount());
    }
}
```

**Adapter vs Facade:** Adapter changes an interface (translation between two incompatible interfaces). Facade simplifies multiple interfaces (hides complexity behind one clean entry point). A Facade doesn't require an existing incompatible interface — it just makes things easier.

**Spring's `HandlerAdapter`:** `DispatcherServlet` calls the uniform `handle()` method; separate adapters translate that into `@Controller` method invocation, `HttpRequestHandler.handleRequest()`, and `Servlet.service()`. Spring adds support for new handler types without changing `DispatcherServlet` — OCP in action.

**Rule:** Adapters should only translate — no business logic. If you're doing calculation or validation inside the adapter, that logic belongs elsewhere.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview. Every concept is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods.*

---

**Q1 — Concept Check**
**"What is the Adapter pattern and when would you use it?"**

**One-line answer:** Adapter wraps an incompatible class behind an interface the client expects, enabling integration without modifying either side.

**Full answer:**
> "Adapter is the go-to pattern when you're integrating a third-party library or legacy system whose API doesn't match your domain model. You define or use an existing interface that your application code depends on, then write an adapter class that implements that interface and delegates to the external library, translating types along the way. Neither your code nor the library changes — the adapter bridges them. A real example: a legacy payment gateway that takes `double amount` but our system uses `BigDecimal`. The adapter converts `BigDecimal` to `double` on the way in and maps the legacy string response to our `PaymentResponse` domain object on the way out."

> *Emphasise composition over inheritance: hold the adaptee as a field, don't extend it.*

**Gotcha follow-up:** *"What's the difference between Adapter and Facade?"*
> "Adapter's purpose is translation — making an incompatible interface compatible. There's always a specific target interface the client already expects, and the adapter conforms to it. Facade's purpose is simplification — it provides a clean, high-level API that hides the complexity of several subsystems working together. A Facade doesn't need an incompatible interface to exist; it just makes things easier. You might use both: an Adapter to wrap a third-party library into your domain interface, and a Facade to orchestrate several such adapters for a use case."

---

**Q2 — Design Scenario**
**"How does Spring's `DispatcherServlet` use the Adapter pattern?"**

**One-line answer:** `HandlerAdapter` bridges `DispatcherServlet`'s uniform `handle()` call to the varied invocation mechanisms of different handler types.

**Full answer:**
> "`DispatcherServlet` needs to invoke handlers — but handlers come in different forms: a method annotated with `@RequestMapping`, an `HttpRequestHandler` implementation, a plain `Servlet`. Each has a different invocation API. Spring defines a `HandlerAdapter` interface with a `handle(request, response, handler)` method. Concrete adapters — `RequestMappingHandlerAdapter`, `HttpRequestHandlerAdapter`, `SimpleServletHandlerAdapter` — each know how to invoke one type of handler. `DispatcherServlet` picks the right adapter for the handler and calls `handle()` uniformly. Adding support for a new handler type means writing a new `HandlerAdapter` implementation — `DispatcherServlet` never changes. That's OCP delivered via Adapter."

> *This demonstrates you understand how a real framework applies the pattern, not just the textbook definition.*

**Gotcha follow-up:** *"Should an Adapter contain business logic?"*
> "No. An Adapter's job is purely translation — mapping method signatures, converting types, re-naming parameters. Business logic inside an adapter is invisible to the domain layer, untestable in isolation, and violates single responsibility. If I find myself writing conditional logic in an adapter, that's a smell that the logic belongs in a domain service or the caller, not in the translation layer."

---

**Common Mistakes**
- **Adding business logic to the adapter:** makes it invisible to the domain layer and hard to test in isolation.
- **Using class adapter (inheritance) in Java:** couples the adapter to the adaptee's implementation and breaks if the adaptee isn't extensible.
- **Confusing Adapter with Facade:** Adapter = translate one interface to another; Facade = simplify multiple subsystems behind one API.

**Quick Revision:** Adapter = composition + implement target interface + delegate to adaptee; object adapter preferred over class adapter; no business logic inside; Spring `HandlerAdapter` is the canonical real-world example.

---

## Topic 6: Decorator Pattern

#### The Idea
Imagine you order a plain coffee. You can add milk, then sugar, then whipped cream — each addition wraps the previous drink without replacing it. You still have a coffee at the core; you just layered behaviour on top. That is exactly what the Decorator pattern does to objects.

The alternative would be to create a subclass for every combination: MilkCoffee, SugarCoffee, MilkSugarCoffee, WhippedMilkSugarCoffee… The moment you have N add-ons and M base drinks, the class count explodes. Decorator sidesteps this by composing wrappers at runtime — any combination, no new subclass.

The wrapper and the wrapped object share the same interface. The outer object delegates to the inner one, doing its extra work before or after. Callers never know how many layers are present — they just call the interface.

#### How It Works

```
interface Component { void operation(); }

class ConcreteComponent implements Component { ... }

abstract class Decorator implements Component {
    private final Component wrapped;
    Decorator(Component c) { this.wrapped = c; }
    public void operation() { wrapped.operation(); }  // default: pure delegation
}

class LoggingDecorator extends Decorator {
    public void operation() {
        log("before"); super.operation(); log("after");
    }
}
```

**Java I/O is the canonical example.** `InputStream` is the Component; `FileInputStream` is the Concrete Component; `FilterInputStream` is the abstract Decorator base; `BufferedInputStream` and `GZIPInputStream` are Concrete Decorators. You compose them: `new GZIPInputStream(new BufferedInputStream(new FileInputStream("f.gz")))`.

**Spring AOP** acts as an invisible Decorator: `@Transactional`, `@Cacheable`, and `@Secured` cause Spring to wrap your bean in a CGLIB or JDK proxy that intercepts calls and adds behaviour before/after delegating to your real method.

**Order of decorators matters.** Placing `RateLimitDecorator` outside `RetryDecorator` means each retry counts against the rate limit. Swap the order and retries are transparent to the rate limiter — two very different behaviours from one ordering decision.

**Decorator vs AOP:** Use Decorator when the consumer explicitly opts in to a pipeline they construct. Use AOP when the concern must apply transparently across many classes without touching any of them.

```java
NotificationService base = new EmailNotificationService();
// Compose: rate limit wraps retry wraps logging wraps base
NotificationService pipeline = new RateLimitNotificationDecorator(
    new RetryNotificationDecorator(
        new LoggingNotificationDecorator(base), 3),
    100);
pipeline.send("user@example.com", "Your order shipped!");
// Adding a new concern = add one class, one wrapping line — no existing code modified
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. Read the question, attempt a mental answer, then check the full answer. Treat the italic delivery notes as coaching, not script.

> *Tip: Lead with the one-line answer first, then layer in detail. Interviewers want signal fast.*

---

**Q1 — Concept check**
**"What is the Decorator pattern and how does it differ from inheritance?"**

**One-line answer:** Decorator wraps an object implementing the same interface to add behaviour at runtime, avoiding the class explosion that inheritance causes when combining N features with M base types.

**Full answer:**
> "Inheritance bakes behaviour in at compile time. If I have three logging levels and four transport types, inheritance gives me twelve classes minimum — and I haven't handled combinations yet. Decorator flips this: each concern is its own wrapper class. At runtime I compose exactly the wrappers I need around the core object. The consumer talks to the outermost wrapper; it has no idea how many layers exist. Java's I/O streams are the textbook example — BufferedInputStream wrapping FileInputStream wrapping whatever — and Spring AOP does the same thing invisibly with @Transactional proxies."

> *Draw the wrapping chain on a whiteboard if available. Visualising layers lands faster than words alone.*

**Gotcha follow-up:** *"Does decorator order matter?"*
> "Absolutely. If RateLimitDecorator is outermost and RetryDecorator is inside it, every retry attempt counts against the rate limit quota. Swap them and retries are invisible to the rate limiter. The interface is identical either way — the behaviour is not."

---

**Q2 — Spring application**
**"How does Spring AOP relate to the Decorator pattern?"**

**One-line answer:** Spring wraps your bean in a proxy (CGLIB subclass or JDK dynamic proxy) that intercepts method calls to add cross-cutting behaviour — structurally identical to Decorator, but generated transparently at container startup.

**Full answer:**
> "When you annotate a method @Transactional, Spring doesn't modify your class. It creates a proxy object that sits in front of your bean. When a caller invokes the method, the proxy begins a transaction, delegates to your real method, then commits or rolls back. That is Decorator: same interface, extra behaviour layered on top. The difference from hand-written Decorator is that Spring builds the wrapping chain automatically from annotations, using CGLIB to subclass your bean at bytecode level. The caller — and often the developer — never sees the proxy."

> *Mention CGLIB vs JDK proxy distinction if the role is Spring-heavy — it shows depth.*

**Gotcha follow-up:** *"What breaks when you call a @Transactional method from within the same class?"*
> "Self-invocation bypasses the proxy entirely. The internal call goes directly to `this`, not through the proxy, so the transaction interceptor never fires. Fix it by restructuring into a separate bean, or by fetching the proxy reference via AopContext.currentProxy() — though that couples your code to Spring internals."

---

**Common Mistakes**
- **Ignoring decorator order:** Assuming wrappers are commutative; they are not — rate-limit-outside-retry and retry-outside-rate-limit behave completely differently.
- **Skipping the abstract decorator base:** Writing boilerplate delegation in every concrete decorator; the abstract base delegates by default so subclasses override only what they change.
- **Confusing Decorator with Proxy:** Decorator is about adding behaviour the client chooses; Proxy is about controlling access to the underlying object (laziness, security, caching).

**Quick Revision:** Decorator = same-interface wrapper that adds behaviour at runtime; order matters; Java I/O and Spring AOP proxies are canonical real-world examples.

---

## Topic 7: Facade Pattern

#### The Idea
Think of a concierge at a hotel. You say "I need a table for two at 7 pm." Behind the scenes the concierge calls the restaurant, checks availability, makes a reservation, logs it in the hotel system, and maybe arranges a taxi. You made one request; a dozen subsystem interactions happened. You never touched any of them directly.

In software, a Facade is that concierge. It sits in front of a complex cluster of subsystems — repositories, external API clients, event publishers — and exposes one clean method. Callers ask for the outcome; the Facade handles all the orchestration.

Without a Facade, controllers end up coordinating repositories, payment clients, inventory services, and notification clients directly. Every controller becomes a coordinator, business logic leaks everywhere, and any change to a subsystem ripples out to every controller that used it.

#### How It Works

```
// Without Facade — controller does orchestration (bad)
// Controller calls: inventoryRepo → paymentClient → orderRepo → notifier

// With Facade — controller calls ONE method
OrderService.placeOrder(request)
  └─ inventoryClient.reserveItems(...)
  └─ paymentClient.charge(...)
  └─ orderRepo.save(...)
  └─ notificationClient.sendConfirmation(...)
```

**Facade vs Adapter:** Adapter translates one interface into another (impedance matching). Facade simplifies many interfaces into one (complexity hiding). Different goals.

**Facade vs Mediator:** Facade is one-directional — clients talk to the Facade, the Facade talks to subsystems. Mediator coordinates peer objects that talk to each other via the mediator; the flow is bidirectional.

**Law of Demeter ("Don't Talk to Strangers"):** Controllers should only call the Service layer. If a controller imports a Repository directly, that is a design smell — the Facade layer is being bypassed.

**Avoid the God Service:** A Facade that absorbs every concern becomes unmaintainable. Split by subdomain — `OrderService`, `InventoryService`, `PaymentService` — rather than one `ApplicationService` that does everything.

**Return DTOs, not JPA entities.** The Facade is the boundary. Leaking entities out couples callers to your persistence model.

```java
@Service
@Transactional
public class OrderService {  // FACADE — one entry point
    // All subsystems injected
    private final OrderRepository orderRepo;
    private final InventoryClient inventoryClient;
    private final PaymentClient paymentClient;
    private final NotificationClient notificationClient;

    public Order placeOrder(PlaceOrderRequest req) {
        // Orchestrates all subsystems — caller sees none of this
        if (!inventoryClient.reserveItems(req.productId(), req.quantity()))
            throw new InsufficientInventoryException(req.productId());
        var payment = paymentClient.charge(req.customerId(), req.totalAmount());
        var order = orderRepo.save(Order.from(req, payment.transactionId()));
        notificationClient.sendConfirmation(req.email(), order.getId());
        return order;
    }
}
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. Read the question, attempt a mental answer, then check the full answer. Treat the italic delivery notes as coaching, not script.

> *Tip: Lead with the one-line answer first, then layer in detail. Interviewers want signal fast.*

---

**Q1 — Concept check**
**"What problem does the Facade pattern solve?"**

**One-line answer:** Facade hides the complexity of coordinating multiple subsystems behind a single, simple interface so callers don't need to know about or depend on the internals.

**Full answer:**
> "Without a Facade, every caller has to orchestrate subsystems directly. A controller placing an order would need to know about the inventory client, the payment client, the order repository, and the notification service — plus the correct sequence and error handling for each. Any change to any subsystem breaks every caller. A Facade absorbs that orchestration into one method. The controller calls placeOrder and gets back an Order; it never sees the subsystems. In Spring, the @Service layer is the natural Facade — @Transactional wraps the entire coordination in one transaction, and the controller stays clean."

> *Use the hotel concierge analogy if the interviewer looks puzzled — concrete analogies reset understanding fast.*

**Gotcha follow-up:** *"How do you prevent a Facade from becoming a God object?"*
> "Split by subdomain. Instead of one OrderApplicationService that handles orders, inventory, payments, and notifications, have an OrderService, a PaymentService, and an InventoryService, each with a focused scope. A Facade should orchestrate things that naturally belong together. If you find yourself needing to inject ten different repositories, that is a sign the subdomain boundary is drawn too broadly."

---

**Q2 — Design**
**"Should a controller ever call a repository directly?"**

**One-line answer:** No — that violates the Law of Demeter and bypasses the Facade layer, leaking orchestration and transaction management concerns into the presentation layer.

**Full answer:**
> "The controller's job is to translate HTTP to a service call and back to HTTP. If it calls a repository directly, it becomes an orchestrator: it has to manage transactions, coordinate multiple data sources, handle business validation. Now every controller that touches that data is a partial reimplementation of business logic, and they'll drift. The Service layer is the correct Facade: it knows the transaction boundary, the correct sequencing, and the business rules. Controllers should be thin — one method call down, one DTO back up."

> *This is often a follow-on to architecture questions. Connecting it to testability (services are easier to mock than repositories injected into controllers) adds depth.*

**Gotcha follow-up:** *"What should a Facade return — entities or DTOs?"*
> "DTOs. Returning a JPA entity from a Facade leaks the persistence model to callers. If the schema changes, every caller breaks. A DTO is a stable contract; the mapping from entity to DTO happens inside the Facade, which is the right place for it."

---

**Common Mistakes**
- **God Service:** Injecting every repository and client into one service class; split by subdomain instead.
- **Leaking entities:** Returning JPA entities from service methods exposes persistence details to callers.
- **Bypassing the Facade:** Controllers importing repositories directly, duplicating orchestration logic across layers.

**Quick Revision:** Facade = one clean method hiding multi-subsystem orchestration; Spring @Service is the canonical Facade; keep it focused, return DTOs, never let callers reach past it.

---

## Topic 8: Proxy Pattern

#### The Idea
A celebrity's agent is a proxy. You cannot call the celebrity directly — you call the agent. The agent decides whether to put the call through, may add conditions, logs who called, and handles some requests entirely without disturbing the celebrity at all. The caller talks to the same "person" regardless.

In software, a Proxy sits in front of a real object, sharing its interface, intercepting every call. It can defer creation until the object is actually needed (Virtual Proxy), add security checks (Protection Proxy), cache results (Caching Proxy), or log every invocation (Logging Proxy). The caller has no idea a proxy is involved.

This is different from Decorator: Decorator adds behaviour the client consciously stacks. Proxy controls access to an underlying object, usually transparently. The client rarely chooses the proxy explicitly — it is installed by a framework.

#### How It Works

```
// Static proxy — hand-written, one class per interface
class LoggingUserService implements UserService {
    private final UserService delegate;
    public User findById(long id) {
        log("findById " + id);
        return delegate.findById(id);
    }
}

// JDK Dynamic Proxy — runtime-generated, requires interface
// CGLIB — bytecode subclass, works without interface, cannot proxy final classes/methods
```

**Spring AOP proxy selection:**
- Target implements an interface → JDK dynamic proxy (pre-Boot 2.0 default)
- Spring Boot 2+ → CGLIB always by default
- `@EnableAspectJAutoProxy(proxyTargetClass=true)` forces CGLIB

**Self-invocation is the classic gotcha.** When a method inside a Spring bean calls another method on `this`, it bypasses the proxy. `@Transactional` on the inner method does nothing. Fix: inject the bean into itself, or fetch the proxy via `AopContext.currentProxy()`, or restructure into two beans.

**Hibernate lazy loading** is a Virtual Proxy in practice: `entity.getOrders()` returns a CGLIB subclass proxy of the collection; the first time you call a method on it, Hibernate fires the SQL.

```java
UserService proxy = (UserService) Proxy.newProxyInstance(
    UserService.class.getClassLoader(),
    new Class<?>[]{ UserService.class },
    (proxyObj, method, args) -> {
        System.out.println("[PROXY] " + method.getName());
        long start = System.nanoTime();
        Object result = method.invoke(realService, args);
        System.out.println("[PROXY] took " + (System.nanoTime() - start) / 1000 + "μs");
        return result;
    }
);
// Spring Boot 2+: AopUtils.isCglibProxy(bean) → true even for interface-backed beans
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. Read the question, attempt a mental answer, then check the full answer. Treat the italic delivery notes as coaching, not script.

> *Tip: Lead with the one-line answer first, then layer in detail. Interviewers want signal fast.*

---

**Q1 — Spring internals**
**"How does Spring implement @Transactional under the hood?"**

**One-line answer:** Spring wraps the bean in a proxy (CGLIB or JDK dynamic) that intercepts the method call, opens a transaction before delegating to your real method, then commits or rolls back after it returns.

**Full answer:**
> "At startup, Spring's BeanPostProcessor detects @Transactional annotations and replaces the bean in the application context with a proxy. For Spring Boot 2+, that proxy is a CGLIB subclass by default. When a caller invokes a @Transactional method, the proxy intercepts the call, checks whether a transaction is already active based on the propagation setting, opens one if needed, delegates to the real method, and then commits or rolls back depending on whether an exception escaped. The caller never knows it's talking to a proxy — it asked for a UserService bean and got one, just with transactional behaviour baked in by the container."

> *Saying "BeanPostProcessor" and "CGLIB subclass" signals you understand the mechanism, not just the annotation.*

**Gotcha follow-up:** *"Why doesn't @Transactional work when you call the method from within the same class?"*
> "Because self-invocation calls `this.method()` directly — it bypasses the proxy entirely. The proxy wraps the bean externally; internal calls go straight to the real object. The transaction interceptor never fires. The fix is to restructure so the transactional method is called through the proxy — either by splitting into a separate bean, or by fetching the proxy reference from AopContext.currentProxy()."

---

**Q2 — JDK vs CGLIB**
**"What is the difference between a JDK dynamic proxy and a CGLIB proxy?"**

**One-line answer:** JDK dynamic proxy is runtime-generated and requires the target to implement an interface; CGLIB generates a bytecode subclass at runtime and works on any non-final class without needing an interface.

**Full answer:**
> "JDK proxies use java.lang.reflect.Proxy to generate a class at runtime that implements the same interfaces as the target. Every method call goes through an InvocationHandler you supply. The constraint is that the target must implement at least one interface — the proxy can only implement what the interface declares. CGLIB takes a different approach: it generates a subclass of your target class by manipulating bytecode. Because it is a subclass, it can proxy concrete classes with no interface. The constraint is that the class and the methods you want to intercept must not be final. Spring Boot 2+ defaults to CGLIB even when an interface exists, because CGLIB proxies tend to be more predictable in edge cases."

> *Mentioning the final class/method limitation for CGLIB is the gotcha interviewers look for.*

**Gotcha follow-up:** *"Can you proxy a final class with Spring AOP?"*
> "Not with CGLIB, because CGLIB needs to subclass it. If the class is final, the only option is a JDK dynamic proxy — which requires an interface. If neither is available, you cannot use Spring AOP on it. Consider refactoring to extract an interface, or use AspectJ compile-time weaving, which operates at the bytecode level before the JVM loads the class."

---

**Common Mistakes**
- **Self-invocation:** Calling a @Transactional or @Cacheable method from within the same bean and expecting the proxy to intercept — it will not.
- **Proxying final classes with CGLIB:** Forgetting that CGLIB must subclass the target; final prevents subclassing.
- **Confusing Proxy with Decorator:** Proxy controls access transparently; Decorator adds behaviour the client explicitly composes.

**Quick Revision:** Proxy = surrogate controlling access; JDK proxy needs interface, CGLIB subclasses concrete types; self-invocation bypasses Spring proxies; Hibernate lazy loading is a Virtual Proxy.

---

## Topic 9: Observer Pattern

#### The Idea
Think of a newspaper subscription. The newspaper (the Subject) does not need to know anything specific about its readers (the Observers). When a new edition is printed, every subscriber gets it automatically. Subscribers can sign up or cancel at any time without the newspaper changing anything about how it publishes.

In software, the Subject maintains a list of Observers and notifies them when its state changes. The classic benefit: the Subject and Observer are loosely coupled. The Subject does not know what the Observer does with the notification — it just broadcasts.

As systems grow distributed, Kafka takes this pattern beyond a single JVM: the topic is the Subject, consumer groups are Observers, and events are durable so latecoming Observers can replay history. The same mental model, massively scaled.

#### How It Works

```
// Push model — Subject sends data payload in notification (observer is passive)
interface Observer { void onEvent(EventPayload payload); }

// Pull model — Observer holds Subject reference, queries only what it needs
interface Observer { void notifyChanged(); }  // Observer then calls subject.getState()

// Spring: ApplicationEventPublisher decouples publisher from listeners entirely
// Listeners are @EventListener beans — publisher holds no references to them
```

**@TransactionalEventListener(phase=AFTER_COMMIT)** is the critical Spring gotcha. If you publish an event inside a @Transactional method using a plain @EventListener, the listener fires even if the transaction later rolls back. Use AFTER_COMMIT to guarantee the event fires only when the DB change is permanent.

**@Async + @EventListener:** Moves notification off the calling thread — the HTTP request returns before observers finish processing. Requires @EnableAsync.

**Memory leak warning:** In plain Java Observer implementations, failing to unsubscribe leaves the Subject holding a reference to the Observer, preventing garbage collection. Use WeakReference or rely on container-managed listeners (Spring handles registration and cleanup).

```java
@Service
public class OrderService {
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public Order placeOrder(PlaceOrderRequest req) {
        Order order = orderRepository.save(Order.from(req));
        // Published AFTER commit — no phantom notifications on rollback
        eventPublisher.publishEvent(new OrderPlacedEvent(order.getId(), order.getAmount()));
        return order;
    }
}

@Component
public class InventoryListener {
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderPlaced(OrderPlacedEvent event) {
        reserveInventory(event.orderId());  // Only runs if order was actually saved
    }
}
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. Read the question, attempt a mental answer, then check the full answer. Treat the italic delivery notes as coaching, not script.

> *Tip: Lead with the one-line answer first, then layer in detail. Interviewers want signal fast.*

---

**Q1 — Spring application**
**"Why use @TransactionalEventListener instead of @EventListener for post-order notifications?"**

**One-line answer:** @TransactionalEventListener(phase=AFTER_COMMIT) fires only after the transaction commits, so side effects like sending emails or reserving inventory never happen for orders that were rolled back.

**Full answer:**
> "If I publish an event inside a @Transactional method using a plain @EventListener, the listener runs in the same transaction context — or immediately if there is no ongoing transaction — which means it can fire before the database change is permanent. If something fails and the transaction rolls back, the email has already been sent. The inventory has already been decremented. Those side effects cannot be undone. @TransactionalEventListener with phase=AFTER_COMMIT defers execution until the transaction successfully commits. If the transaction rolls back, the listener never runs. For anything with real-world consequences — emails, inventory, payment webhooks — AFTER_COMMIT is the safe default."

> *Lead with the rollback scenario. That concretises why it matters and shows you think about failure modes.*

**Gotcha follow-up:** *"What happens to the event if the transaction rolls back?"*
> "With @TransactionalEventListener(phase=AFTER_COMMIT), the event is silently dropped — the listener never fires. If you need durable event delivery even across rollbacks, you should use the outbox pattern: write the event to a database table in the same transaction as your domain change, and have a separate process poll the table and publish. That way the event is only 'sent' once the row is committed."

---

**Q2 — Push vs Pull**
**"What is the difference between push and pull models in Observer?"**

**One-line answer:** Push sends the data payload in the notification; pull notifies the Observer that something changed and lets the Observer query only the state it needs.

**Full answer:**
> "In the push model, the Subject packages the relevant data into the event object and passes it to each Observer. The Observer is passive — it receives everything it might need. This is looser coupling because the Observer does not need a reference to the Subject. In the pull model, the notification is minimal — just a signal that state changed. The Observer holds a reference to the Subject and queries for only the data it cares about. This gives finer-grained control but tightens the coupling because the Observer knows about the Subject's API. Spring's ApplicationEventPublisher uses push: the event object carries the payload, and listeners never need to reach back into the publisher."

> *Spring examples anchor abstract concepts. Concrete always beats abstract in interviews.*

**Gotcha follow-up:** *"How does Kafka extend the Observer pattern?"*
> "Kafka's topic is the Subject, consumer groups are the Observers, and events are durable records rather than transient method calls. Observers can subscribe and unsubscribe by changing their consumer group membership, they can replay historical events by resetting offsets, and they process at their own rate via the consumer poll model. The major addition over in-process Observer is durability and backpressure. The tradeoff is that observers must be idempotent because Kafka guarantees at-least-once delivery — the same event can arrive more than once."

---

**Common Mistakes**
- **Using @EventListener for transactional side effects:** Listener fires before commit; rollback leaves ghost side effects (emails sent, inventory decremented for an order that never existed).
- **Memory leak from missing unsubscribe:** Strong Subject-to-Observer reference prevents GC; use WeakReference or container-managed listeners.
- **Synchronous observers blocking the main flow:** Use @Async to move expensive observers off the request thread.

**Quick Revision:** Observer = one-to-many notification; always use @TransactionalEventListener(AFTER_COMMIT) for real-world side effects; Kafka is distributed Observer with durability and replay.

---

## Topic 10: Strategy Pattern

#### The Idea
Imagine a navigation app that needs to calculate routes. Sometimes the user wants the fastest route; sometimes the cheapest; sometimes the one that avoids tolls. The calculation algorithm changes, but everything else — taking the user's start and end point, displaying the route — stays the same.

Rather than a sprawling if-else block (`if (mode == FAST) { ... } else if (mode == CHEAP) { ... }`), Strategy extracts each algorithm into its own class. The Context (the navigator) holds a reference to whichever Strategy is active and delegates. Swapping the algorithm at runtime is a one-line assignment.

The deeper value is Open/Closed Principle: adding a new routing strategy means adding one new class. Existing code is untouched. In a Spring application, this extends further — you add a new @Component and the container wires it in automatically.

#### How It Works

```
interface ShippingStrategy { Money calculate(Order order); }

class StandardShipping implements ShippingStrategy { ... }
class ExpressShipping  implements ShippingStrategy { ... }
class FreeShipping     implements ShippingStrategy { ... }

class ShippingContext {
    private ShippingStrategy strategy;
    void setStrategy(ShippingStrategy s) { this.strategy = s; }
    Money calculate(Order o) { return strategy.calculate(o); }
}

// Runtime swap
context.setStrategy(new ExpressShipping());
```

**Spring Map injection** is the idiomatic Spring implementation. Spring automatically collects all beans implementing a Strategy interface into a `Map<String, Strategy>` keyed by bean name. No factory class, no registration code — just inject and look up.

**Adding a new strategy:** Create a new class, annotate with @Component("KEY"), done. Zero changes to existing code. The Map is populated at container startup.

**Strategy vs State:** Strategy is client-driven — the caller explicitly selects the algorithm. State is self-driven — the object transitions itself based on internal conditions.

**Strategy vs Template Method:** Strategy uses composition (a separate object holds the algorithm). Template Method uses inheritance (the algorithm skeleton lives in an abstract base class, subclasses fill in steps). Prefer Strategy — composition is more flexible and avoids the fragile base class problem.

**Lambda as Strategy:** If the interface is a @FunctionalInterface, any lambda satisfies it. `Comparator` is the canonical Java example — every `sorted(Comparator.comparing(...))` call passes a Strategy as a lambda.

```java
@Service
public class PaymentService {
    private final Map<String, PaymentStrategy> strategies;

    // Spring injects ALL PaymentStrategy beans: key = @Component value, bean = implementation
    public PaymentService(Map<String, PaymentStrategy> strategies) {
        this.strategies = strategies;
    }

    public PaymentResult process(PaymentRequest request) {
        return Optional.ofNullable(strategies.get(request.getProvider()))
            .orElseThrow(() -> new UnsupportedPaymentProviderException(request.getProvider()))
            .process(request);
        // Adding STRIPE: add StripePaymentStrategy @Component("STRIPE") — nothing else changes
    }
}
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. Read the question, attempt a mental answer, then check the full answer. Treat the italic delivery notes as coaching, not script.

> *Tip: Lead with the one-line answer first, then layer in detail. Interviewers want signal fast.*

---

**Q1 — Design decision**
**"How would you implement support for multiple payment providers without a large if-else block?"**

**One-line answer:** Define a PaymentStrategy interface, implement one class per provider annotated @Component with the provider name as the bean name, and inject the full set as a Map<String, PaymentStrategy> into the service.

**Full answer:**
> "The naive approach is a switch or if-else on the provider string — readable at first, but every new provider requires touching the switch, which violates Open/Closed Principle and creates a merge conflict magnet. Instead, I'd define a PaymentStrategy interface with a process method, and implement it once per provider: StripePaymentStrategy @Component('STRIPE'), PayPalPaymentStrategy @Component('PAYPAL'), and so on. Spring collects all beans implementing the interface into a Map<String, PaymentStrategy>, keyed by bean name, and injects it into the service constructor. At runtime, the service does a map lookup on the incoming provider string. Adding a new provider is one new class and one @Component annotation. Nothing else changes — not the service, not the tests for existing providers."

> *Walk through the code mentally before you describe it. The clarity of the explanation tracks directly with how well you know the pattern.*

**Gotcha follow-up:** *"What happens if someone passes an unsupported provider?"*
> "The map lookup returns null. Wrapping it in Optional.ofNullable and calling orElseThrow gives a clear, typed exception — UnsupportedPaymentProviderException — rather than a NullPointerException three stack frames later. This is also the right place to log the unknown provider string for operational visibility."

---

**Q2 — Comparison**
**"What is the difference between Strategy and Template Method?"**

**One-line answer:** Strategy uses composition — the algorithm lives in a separate object you inject; Template Method uses inheritance — the algorithm skeleton lives in an abstract base class you extend.

**Full answer:**
> "Template Method defines the steps of an algorithm in an abstract base class and lets subclasses override specific steps. It is stable when the overall structure truly does not change — only the details vary. The problem is it relies on inheritance: you cannot change the algorithm at runtime, and modifying the base class affects every subclass. Strategy avoids inheritance entirely. The algorithm is encapsulated in a separate object behind an interface. You compose the strategy into the context at construction time or swap it at runtime. That makes Strategy far more flexible and testable — you can mock the strategy in isolation, and you can add new algorithms without touching existing code. The general rule is to prefer Strategy over Template Method unless the algorithm structure is genuinely fixed and unlikely to change."

> *Mentioning testability tips the scales — it shows production-code thinking, not just pattern trivia.*

**Gotcha follow-up:** *"When is Template Method still the right choice?"*
> "When the algorithm skeleton genuinely belongs in a base class and subclasses are only filling in fixed, well-defined hooks. A good example is AbstractApplicationContext in Spring — the refresh() method defines a fixed lifecycle, and specific application context types override narrowly scoped hooks. When the frame is truly stable and shared, inheritance is not wrong. The error is using Template Method when the frame is not stable — that is when Strategy wins."

---

**Common Mistakes**
- **Large if-else over strategy map:** Adding a new provider requires modifying existing code; violates OCP and creates merge conflicts.
- **Missing unknown-key handling:** Map lookup returning null without a null check causes confusing NullPointerExceptions far from the origin.
- **Confusing Strategy with State:** Strategy is selected by the client; State transitions itself — different ownership of the selection decision.

**Quick Revision:** Strategy = one interface, many implementations, map injection in Spring; adding a new algorithm = one new @Component; prefer over Template Method because composition beats inheritance.

---

## Topic 11: Template Method Pattern

#### The Idea

Imagine a recipe book that fixes the cooking steps — preheat oven, mix ingredients, bake, cool — but leaves the exact ingredients and mixing technique up to the chef. The skeleton never changes; only the variable steps do. That is Template Method in a nutshell.

The base class (the "recipe") defines the algorithm as a `final` method so no subclass can reorder or remove steps. Some steps are declared `abstract` — subclasses *must* provide them. Others are "hooks" with a default no-op implementation that subclasses *may* override if they need to.

This embodies the Hollywood Principle: "Don't call us, we'll call you." The framework (base class) calls your code (subclass), not the other way around. That inversion is the root idea behind Spring's IoC container.

#### How It Works

```
Base class (final template method):
  step1()           ← fixed, implemented here
  step2()           ← abstract, subclass must implement
  hook()            ← default no-op, subclass may override
  step3()           ← fixed

Subclass:
  implements step2()
  optionally overrides hook()
```

Spring `JdbcTemplate` is the canonical backend example. The template handles connection acquisition, exception translation, statement creation, and `ResultSet` closing. You supply the SQL and a `RowMapper` — those are your "abstract steps."

```java
@Repository
public class ProductRepository {
    private final JdbcTemplate jdbcTemplate;

    public List<Product> findByCategory(String category) {
        // Template: JdbcTemplate handles connection, statement, ResultSet closing
        // Hook: you provide SQL and the RowMapper
        return jdbcTemplate.query(
            "SELECT id, name, price FROM products WHERE category = ?",
            (rs, rowNum) -> new Product(          // RowMapper = your hook
                rs.getLong("id"),
                rs.getString("name"),
                rs.getBigDecimal("price")
            ),
            category
        );
    }
}
```

`@Transactional` is another Template Method in disguise: begin transaction → *your method body* → commit/rollback. The transaction algorithm is fixed; your code fills the abstract step.

**Template Method vs Strategy:** Template Method uses inheritance — the variable step is baked into a subclass. Strategy uses composition — the algorithm is injected at runtime. Prefer Strategy when variation needs to be chosen at runtime; Template Method is fine when the variation is fixed at compile time.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. Read the one-line answer to check if you know it, then rehearse the full answer aloud before an interview.

> *Tip: Lead with the one-line answer first, then expand. Interviewers reward concision.*

---

**Q1 — Definition**
**"What is the Template Method pattern and where does Spring use it?"**

**One-line answer:** Template Method fixes an algorithm's skeleton in a base class and defers variable steps to subclasses; Spring uses it in `JdbcTemplate`, `@Transactional`, and `RestTemplate`.

**Full answer:**
> "Template Method defines the invariant parts of an algorithm in a `final` method on the base class, then declares the variable parts as abstract methods or hooks that subclasses override. The base class calls those overridden methods — that inversion is the Hollywood Principle and the basis of IoC. In Spring, `JdbcTemplate.query()` is the template: it acquires the connection, translates exceptions, and closes the `ResultSet`. I only supply the SQL and a `RowMapper` lambda — that lambda is my hook. `@Transactional` is the same idea: Spring wraps my method in a fixed begin/commit/rollback algorithm; my method body is the abstract step."

> *Mention the `final` keyword on the template method — it signals intentional immutability of the algorithm order.*

**Gotcha follow-up:** *"Why is `@Transactional` considered Template Method rather than Decorator?"*
> "Decorator wraps at the object level and can stack multiple decorators independently. `@Transactional` uses an AOP proxy that replaces the method invocation with a fixed transaction algorithm — it's not adding behaviour around an existing interface; it's defining the entire execution skeleton. That maps closer to Template Method."

---

**Common Mistakes**
- **Making template steps public:** Exposes internals; hook and abstract steps should be `protected`.
- **Confusing hooks with abstract steps:** Hooks have a default implementation (optional override); abstract steps have none (mandatory override).
- **Using Template Method when runtime variation is needed:** That calls for Strategy instead.

**Quick Revision:** Template Method = `final` skeleton + abstract/hook steps; Spring's `JdbcTemplate` and `@Transactional` are live examples.

---

## Topic 12: Command Pattern

#### The Idea

Think of a restaurant order slip. The waiter (Invoker) writes your request on a slip and passes it to the kitchen (Receiver). The slip is the Command — it encapsulates everything needed to fulfil the request. The waiter does not cook; the kitchen does not know who ordered. They are decoupled through the slip.

That decoupling unlocks three powerful capabilities: you can queue slips (job queue), log them for auditing, and reverse them if something goes wrong (undo/redo). Each Command object carries the state needed to both execute and undo the action.

In backend systems this shows up as async job queues, transactional outboxes, and saga compensating transactions — all share the same Command shape.

#### How It Works

```
Command interface:
  execute()
  undo()

Invoker (CommandHistory):
  undoStack: Deque<Command>
  redoStack: Deque<Command>
  execute(cmd) → run + push to undoStack + clear redoStack
  undo()       → pop undoStack + run undo + push to redoStack
  redo()       → pop redoStack + run execute + push to undoStack
```

```java
public class CommandHistory {
    private final Deque<Command> undoStack = new ArrayDeque<>();
    private final Deque<Command> redoStack = new ArrayDeque<>();

    public void execute(Command command) {
        command.execute();
        undoStack.push(command);
        redoStack.clear();  // New action clears redo history
    }
    public void undo() {
        if (undoStack.isEmpty()) return;
        Command cmd = undoStack.pop();
        cmd.undo();
        redoStack.push(cmd);
    }
    public void redo() {
        if (redoStack.isEmpty()) return;
        Command cmd = redoStack.pop();
        cmd.execute();
        undoStack.push(cmd);
    }
}
```

**Transactional Outbox = Command + Persistence:** save the Order AND an `OutboxEvent` row in the same DB transaction; a poller later publishes pending events to Kafka. The event row is a persisted Command. For idempotency, embed a unique `commandId` and check a processed-commands store before executing.

**Command vs Strategy:** Strategy decides *how* to do something (interchangeable algorithm, returns a result). Command encapsulates *what* to do (state change, optionally undoable, optionally queued).

#### Interview Lens

> **How to use this section:** Each question below is self-contained. Read the one-line answer to check if you know it, then rehearse the full answer aloud before an interview.

> *Tip: Lead with the one-line answer first, then expand.*

---

**Q1 — Definition + real usage**
**"Explain the Command pattern and how it appears in a Spring microservice."**

**One-line answer:** Command encapsulates a request as an object, decoupling sender from receiver, and enabling queuing, logging, and undo.

**Full answer:**
> "Command wraps a request — its parameters, the receiver, and the action — into a single object. The Invoker only calls `execute()` without knowing what that does. In a Spring microservice I use this in two places: async jobs submitted to a `TaskExecutor` are Runnable Commands, and the Transactional Outbox pattern stores domain events as rows in the same transaction as the business write. The poller then calls `execute()` on each unpublished event to push it to Kafka. I add a `commandId` field for idempotency — if the poller crashes and retries, we skip already-processed commands."

> *The Transactional Outbox angle differentiates you from candidates who only mention undo/redo.*

**Gotcha follow-up:** *"Why clear the redo stack on a new execute?"*
> "Redo only makes sense along a linear history. If you undo three steps and then perform a new action, the old redo branch is no longer reachable — keeping it would let users redo actions that are now inconsistent with the current state."

---

**Common Mistakes**
- **Mutable Command state:** Commands should capture all needed state at creation; mutating them later makes undo unreliable.
- **Forgetting idempotency:** In distributed systems a Command can be delivered more than once; always guard with a `commandId`.
- **Confusing with Strategy:** Strategy returns a value and is stateless; Command encapsulates a state change and carries its own data.

**Quick Revision:** Command = request-as-object; enables queue/undo/log; Transactional Outbox is Command + DB persistence.

---

## Topic 13: Chain of Responsibility

#### The Idea

Airport security has multiple checkpoints: ID check, bag scan, body scan. Each checkpoint handles what it can and waves you on to the next. If the ID check catches a problem it stops you there — the bag scan never runs. That is Chain of Responsibility: a request travels a chain of handlers until one absorbs it or it reaches the end.

Each handler knows only its own logic and a reference to the next handler. The chain is assembled externally, so you can add, remove, or reorder checkpoints without touching any individual handler. This makes it ideal for cross-cutting concerns like authentication, logging, and rate-limiting.

In Spring, the Servlet `FilterChain` and Spring Security's `SecurityFilterChain` are both CoR implementations you interact with every day.

#### How It Works

```
Handler interface:
  handle(request, response)
  setNext(handler) → returns handler (enables fluent chaining)

ConcreteHandler:
  if (canHandle(request)):
    process + return          ← absorb
  else:
    next.handle(request, response)  ← pass
```

```java
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest req,
                                    HttpServletResponse res,
                                    FilterChain chain) throws ServletException, IOException {
        String header = req.getHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) {
            chain.doFilter(req, res);  // Pass to next — no token, not our concern
            return;
        }
        try {
            String userId = jwtService.extractUserId(header.substring(7));
            // Set authentication in SecurityContext
            SecurityContextHolder.getContext().setAuthentication(buildAuth(userId));
        } catch (JwtException e) {
            res.setStatus(401);
            return;  // Absorb — invalid token stops the chain
        }
        chain.doFilter(req, res);  // Pass to next
    }
}
```

**CoR vs Decorator:** Decorator *always* executes every wrapper; CoR can stop propagation at any handler. Use CoR when short-circuiting is required (auth failure). Use Decorator when every layer must always run (logging, metrics).

**Ordering:** Use `addFilterBefore`/`addFilterAfter` in Spring Security rather than `@Order` for security filters — `@Order` affects the general filter chain, not the Security filter chain.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. Read the one-line answer to check if you know it, then rehearse the full answer aloud before an interview.

> *Tip: Lead with the one-line answer first, then expand.*

---

**Q1 — Spring Security integration**
**"How does Chain of Responsibility appear in Spring Security, and how do you add a custom filter?"**

**One-line answer:** Spring Security's `SecurityFilterChain` is a CoR where each `Filter` either processes and stops or calls `chain.doFilter()` to pass on.

**Full answer:**
> "Spring Security registers a chain of `Filter` implementations. Each filter calls `chain.doFilter(req, res)` to pass the request along, or returns early — absorbing the request — to short-circuit. For a custom JWT filter I extend `OncePerRequestFilter`, extract the `Authorization` header, validate the token, and set the `Authentication` in `SecurityContextHolder`. If the token is missing I call `chain.doFilter` — it's not my concern. If it's invalid I write a 401 and return, absorbing the request so downstream filters never see it. I register the filter with `http.addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)` rather than `@Order` because Spring Security manages its own ordered list separately from the Servlet filter chain."

> *The `addFilterBefore` vs `@Order` nuance is a common interview differentiator.*

**Gotcha follow-up:** *"What's the risk of a very long filter chain?"*
> "Every filter adds latency, even if it just passes through. More critically, debugging which filter absorbed or modified a request becomes hard. I instrument each handler with a timer metric tagged with the handler name so I can trace which step added the most latency."

---

**Common Mistakes**
- **Using `@Order` for Spring Security filters:** It affects the general Servlet chain, not the Security chain; use `addFilterBefore`/`addFilterAfter`.
- **Calling `chain.doFilter` after absorbing:** Once you write the response and return, calling `chain.doFilter` corrupts the response.
- **Building deeply nested chains:** More than 5–6 handlers becomes hard to reason about; prefer composing handlers into logical groups.

**Quick Revision:** CoR = each handler passes or absorbs; Spring Security FilterChain is the live example; use `addFilterBefore` not `@Order`.

---

## Topic 14: State Pattern

#### The Idea

An online order behaves very differently depending on where it is in its lifecycle. A PENDING order can be paid or cancelled. A PAID order can be shipped. A SHIPPED order cannot be cancelled. The same object, the same method names, but completely different rules depending on "what it is right now." That is the State pattern.

Instead of a giant `switch` statement that checks the current status on every method call, each state is its own class. The Order context delegates every state-specific method to whichever State object it currently holds. Valid transitions swap the State object; invalid transitions throw immediately — no `if` chains needed.

This scales cleanly: adding a REFUNDED state means adding one new class and touching only the states that can transition to REFUNDED, not rewriting a central switch.

#### How It Works

```
OrderContext:
  currentState: OrderState
  transitionTo(state) → currentState = state; log transition

OrderState interface:
  pay(ctx), ship(ctx), cancel(ctx), getStateName()

ConcreteState (e.g. PendingState):
  pay()    → ctx.transitionTo(new PaidState())     ← valid
  ship()   → throw InvalidStateTransitionException  ← invalid
  cancel() → ctx.transitionTo(new CancelledState()) ← valid
```

```java
public class PendingState implements OrderState {
    @Override
    public void pay(OrderContext ctx) {
        ctx.transitionTo(new PaidState());  // Valid
    }
    @Override
    public void ship(OrderContext ctx) {
        throw new InvalidStateTransitionException("Cannot ship unpaid order");
    }
    @Override
    public void cancel(OrderContext ctx) {
        ctx.transitionTo(new CancelledState());  // Valid
    }
    @Override
    public String getStateName() { return "PENDING"; }
}
// Context delegates: public void pay() { currentState.pay(this); }
// Invalid transitions throw at the object level — no switch/if needed
```

**Persisting state:** Store `getStateName()` as a string or enum in the DB. On load, reconstruct the State object via a factory: `StateFactory.from(order.getStatus())`. Spring StateMachine provides a declarative alternative with `@EnableStateMachine`, guard conditions, and event-driven transitions.

**State vs Strategy:** State = *what the object is* (identity, lifecycle; states know each other and trigger transitions). Strategy = *how the object does something* (algorithm, client selects, strategies are unaware of each other).

#### Interview Lens

> **How to use this section:** Each question below is self-contained. Read the one-line answer to check if you know it, then rehearse the full answer aloud before an interview.

> *Tip: Lead with the one-line answer first, then expand.*

---

**Q1 — State vs switch**
**"When would you choose the State pattern over a switch statement for an order lifecycle?"**

**One-line answer:** Use State when you have more than four states, complex per-state logic, or expect new states to be added — it removes the need to touch a central switch every time.

**Full answer:**
> "A switch on status works fine at two or three states. Once you have PENDING, PAID, SHIPPED, DELIVERED, CANCELLED, and REFUNDED — each with different valid transitions and business rules — the switch becomes a maintenance hazard: every new state requires touching every existing method. The State pattern gives each state its own class. Valid transitions call `ctx.transitionTo()`; invalid ones throw immediately at the object level. The Context never needs to know about valid transitions — each State enforces its own rules. I persist the state name as a string column and reconstruct the correct State object on load via a factory. New states are additive — open/closed principle satisfied."

> *Quote the number of states as the tipping point — it shows practical judgment, not blind pattern-worship.*

**Gotcha follow-up:** *"How do you prevent illegal transitions without the State pattern?"*
> "You'd need a transition table — a map from `(currentState, action)` to `(nextState, guard)` — and check it on every operation. That's essentially implementing a manual FSM. At some point the State pattern is cleaner because the logic lives with the state itself."

---

**Common Mistakes**
- **States knowing nothing about each other:** The State pattern *intentionally* couples states through the Context; that's how they trigger transitions.
- **Not persisting state:** If you reconstruct from DB without restoring the State object, you lose the pattern's enforcement and fall back to switch.
- **Using State for simple binary flags:** Overkill for two states; a boolean or enum + guard clause is cleaner.

**Quick Revision:** State = FSM in OO; each state class enforces its own valid transitions; persist state name, reconstruct via factory.

---

## Topic 15: Composite & Iterator Patterns

#### The Idea

**Composite:** Imagine a file system. A `File` has a size. A `Directory` also has a "size" — but it's the sum of everything inside it, which might include other directories. From the outside, you call `getSize()` on both and get a number. You do not need to know whether you are holding a file or a directory. That uniform treatment of leaves and composites is the Composite pattern.

**Iterator:** A playlist knows its songs are in an array. A podcast app uses a linked list. A streaming service uses a lazy cursor. You do not want every consumer to know those details — you want a single, consistent way to walk through any collection. Iterator provides `hasNext()` and `next()` so the traversal logic is separated from the collection structure.

Together they are the backbone of every tree-traversal and collection-processing API in Java.

#### How It Works

**Composite tree:**
```
Component interface: getSize(), accept(Visitor)
  Leaf (File):      getSize() → own size
  Composite (Dir):  getSize() → sum of children.getSize()
                    add/remove children

Client calls root.getSize() — recursive delegation handles the rest.
```

**Iterator internals — fail-fast vs fail-safe:**
```
Fail-fast (ArrayList, HashMap):
  modCount incremented on every structural change
  iterator snapshots expectedModCount at creation
  next() checks modCount == expectedModCount → throws ConcurrentModificationException if not

Fail-safe (CopyOnWriteArrayList, ConcurrentHashMap):
  iterates over a snapshot/copy
  structural changes to original not reflected during iteration
  no ConcurrentModificationException
```

The must-memorise pattern for safe removal during iteration:

```java
// Safe removal during iteration — the only correct pattern
Iterator<String> iter = list.iterator();
while (iter.hasNext()) {
    String item = iter.next();
    if (shouldRemove(item)) {
        iter.remove();  // CORRECT: syncs expectedModCount, no ConcurrentModificationException
        // list.remove(item);  // WRONG: increments modCount, throws on next iter.next()
    }
}
// Java 8+ equivalent (safe):
list.removeIf(item -> shouldRemove(item));
```

**Composite + Iterator:** A `DepthFirstIterator` traverses a Composite tree using a `Deque` stack. Push the root; on each `next()`, pop and push children in reverse order (so left child is processed first).

#### Interview Lens

> **How to use this section:** Each question below is self-contained. Read the one-line answer to check if you know it, then rehearse the full answer aloud before an interview.

> *Tip: Lead with the one-line answer first, then expand.*

---

**Q1 — Fail-fast mechanism**
**"What causes a ConcurrentModificationException and how do you safely remove elements during iteration?"**

**One-line answer:** `ConcurrentModificationException` is thrown when the collection's `modCount` diverges from the iterator's `expectedModCount`; fix it by using `iterator.remove()` or `removeIf()`.

**Full answer:**
> "Java's fail-fast iterators keep an internal `expectedModCount` snapshot taken when the iterator is created. Every structural change to the collection — add, remove, clear — increments the collection's `modCount`. On every call to `next()`, the iterator compares the two. If they differ it throws `ConcurrentModificationException` immediately rather than silently returning stale data. The correct fix during a while-iterator loop is to call `iter.remove()` instead of `list.remove(item)` — the iterator's `remove()` method keeps `expectedModCount` in sync. In Java 8+ I prefer `list.removeIf(predicate)` which handles this internally and is more readable. For concurrent access from multiple threads I use `CopyOnWriteArrayList` — it iterates over a snapshot so structural changes to the live list never affect an in-progress iterator, though the trade-off is that writes are O(n)."

> *Always distinguish single-threaded iteration (use `iter.remove()`) from multi-threaded access (use a thread-safe collection).*

**Gotcha follow-up:** *"Does CopyOnWriteArrayList throw ConcurrentModificationException?"*
> "No. Its iterator works on a fixed snapshot taken at iterator creation. You will not see concurrent modifications during iteration, but you also will not see them — the iterator reflects the list state at the moment it was created, not the current state."

---

**Q2 — Composite use case**
**"When would you use Composite over a flat list?"**

**One-line answer:** Use Composite when data has a natural tree hierarchy and clients should treat leaves and branches uniformly.

**Full answer:**
> "A flat list works when all elements are at the same level. Once data has parent-child relationships — a file system, a UI component tree, an org chart, a menu with sub-menus — a flat list forces the client to know the depth and recurse manually. Composite encapsulates that recursion inside the component: `Directory.getSize()` delegates to children, which may themselves be directories. The client just calls `root.getSize()` and gets the correct answer without any traversal code. I pair it with the Visitor pattern when I need to add new operations — like computing permissions or generating a report — without modifying the component classes."

> *Mentioning Visitor shows you know when Composite alone is insufficient.*

---

**Common Mistakes**
- **Calling `collection.remove()` inside an iterator loop:** Always throws on the next `next()` call; use `iter.remove()` or `removeIf()`.
- **Assuming fail-safe means thread-safe writes:** `CopyOnWriteArrayList` makes *reads* safe during iteration; concurrent *writes* still need external coordination if ordering matters.
- **Flat list when tree depth is unknown:** If categories can nest arbitrarily deep, a flat list with a `parentId` column forces recursive queries; Composite avoids that at the model level.

**Quick Revision:** Iterator fail-fast uses `modCount` — use `iter.remove()` or `removeIf()` to stay safe; Composite = uniform leaf/branch interface for tree data.

