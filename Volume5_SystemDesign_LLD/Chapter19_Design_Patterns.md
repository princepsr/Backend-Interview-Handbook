# Volume 5: System Design & LLD
# Chapter 19: Design Patterns

---

# Chapter 19 — Design Patterns (Part A): GoF Creational & Structural Patterns

> **Target Audience:** SDE2 / Senior Engineer | **Companies:** FAANG, Uber, Stripe, Shopify, Bloomberg  
> **Java Version:** Java 17 | **Framework:** Spring Boot 3.x

---

## Overview

Design patterns are reusable solutions to recurring software design problems. The Gang of Four (GoF) classified 23 patterns into three categories: Creational, Structural, and Behavioral. This chapter (Part A) covers the 4 Creational and 4 Structural patterns most frequently tested in backend interviews.

| Pattern | Category | Core Intent |
|---|---|---|
| Singleton | Creational | One instance, global access point |
| Factory Method / Abstract Factory | Creational | Delegate object creation to subclasses |
| Builder | Creational | Step-by-step object construction |
| Prototype | Creational | Clone existing objects |
| Adapter | Structural | Bridge incompatible interfaces |
| Decorator | Structural | Add behavior without subclassing |
| Facade | Structural | Simplify a complex subsystem |
| Proxy | Structural | Control access to another object |

---

### Topic 1: Singleton Pattern

![Singleton UML class diagram](https://upload.wikimedia.org/wikipedia/commons/f/fb/Singleton_UML_class_diagram.svg)
*Singleton — private constructor, static instance, single point of access*

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Amazon, Google, Microsoft, Uber, Stripe

**Q:** How do you implement a thread-safe Singleton in Java? What are its pitfalls, and when should you avoid it?

**Short Answer:**
A Singleton ensures only one instance exists in the JVM. Thread-safe lazy initialization requires double-checked locking with a `volatile` field to prevent instruction reordering. In modern Java, the enum-based Singleton is considered the most robust and concise approach.

**Deep Explanation:**

The Singleton pattern has four common implementations in Java, each with different trade-offs:

1. **Eager initialization** — instance created at class loading; thread-safe by JVM but no lazy loading.
2. **Synchronized method** — thread-safe but acquires lock on every `getInstance()` call, which is expensive.
3. **Double-checked locking (DCL)** — acquires lock only on first creation; requires `volatile` to prevent the JVM from reordering the write to the reference before the constructor completes.
4. **Enum Singleton** — JVM guarantees a single instance; serialization-safe; reflection-safe; preferred by Effective Java.

**Why `volatile` matters in DCL:**
Without `volatile`, the JVM can reorder: (a) allocate memory → (b) assign reference → (c) invoke constructor. A second thread can see a non-null but partially initialized object between steps (b) and (c). The `volatile` keyword establishes a happens-before relationship that prevents this.

**Why Spring beans are Singleton by default:**
Spring's IoC container manages the lifecycle of beans. Singleton scope (`@Scope("singleton")`) means one instance per ApplicationContext. This is efficient for stateless service/repository beans. Spring's singleton is per-ApplicationContext, not per-JVM — two ApplicationContexts yield two instances.

**UML (text):**
```
Singleton
-----------
- instance: volatile Singleton  (static)
- Singleton()  (private constructor)
-----------
+ getInstance(): Singleton  (static, synchronized on first call)
```

**Real-World Example:**
A database connection pool manager — you want exactly one pool controlling all connections. If multiple pools existed, you would exhaust database connection limits. Similarly, a configuration loader that reads `application.properties` once should be a Singleton to avoid repeated disk I/O.

**Code Example:**
```java
// BEFORE: Broken lazy init — not thread-safe
public class ConfigManager {
    private static ConfigManager instance;  // NOT volatile — race condition!
    private final Properties props = new Properties();

    private ConfigManager() {
        try (var in = getClass().getResourceAsStream("/application.properties")) {
            props.load(in);
        } catch (Exception e) {
            throw new RuntimeException("Failed to load config", e);
        }
    }

    // Two threads can both see instance == null and create two objects
    public static ConfigManager getInstance() {
        if (instance == null) {
            instance = new ConfigManager();
        }
        return instance;
    }
}

// AFTER (A): Double-Checked Locking with volatile — thread-safe lazy init
public class ConfigManager {
    // volatile prevents instruction reordering; ensures full initialization
    // before reference is published to other threads
    private static volatile ConfigManager instance;
    private final Properties props = new Properties();

    private ConfigManager() {
        try (var in = getClass().getResourceAsStream("/application.properties")) {
            props.load(in);
        } catch (Exception e) {
            throw new RuntimeException("Failed to load config", e);
        }
    }

    public static ConfigManager getInstance() {
        if (instance == null) {                    // First check (no lock)
            synchronized (ConfigManager.class) {
                if (instance == null) {            // Second check (with lock)
                    instance = new ConfigManager();
                }
            }
        }
        return instance;
    }

    public String get(String key) {
        return props.getProperty(key);
    }
}

// AFTER (B): Enum Singleton — preferred (Effective Java Item 3)
// Serialization-safe, reflection-safe, thread-safe — free
public enum AppConfig {
    INSTANCE;

    private final Properties props = new Properties();

    AppConfig() {
        try (var in = getClass().getResourceAsStream("/application.properties")) {
            props.load(in);
        } catch (Exception e) {
            throw new RuntimeException("Failed to load config", e);
        }
    }

    public String get(String key) {
        return props.getProperty(key);
    }
}

// AFTER (C): Spring-managed Singleton (most common in enterprise code)
@Service  // @Scope("singleton") is implicit
public class ConfigService {
    @Value("${app.name}")
    private String appName;

    public String getAppName() { return appName; }
}

// Initialization-on-demand holder (Bill Pugh) — lazy + thread-safe, no synchronized
public class ConnectionPool {
    private ConnectionPool() {}

    private static final class Holder {
        // JVM guarantees class init is thread-safe
        static final ConnectionPool INSTANCE = new ConnectionPool();
    }

    public static ConnectionPool getInstance() {
        return Holder.INSTANCE;
    }
}

// Usage
public class Main {
    public static void main(String[] args) {
        // DCL approach
        var config = ConfigManager.getInstance();
        System.out.println(config.get("db.url"));

        // Enum approach
        System.out.println(AppConfig.INSTANCE.get("db.url"));

        // Bill Pugh approach
        var pool = ConnectionPool.getInstance();
    }
}
```

**Follow-up Questions:**
1. Why does serialization break non-enum Singletons, and how do you fix it?
2. Can a Singleton be broken by reflection, and how would you prevent it?
3. How does Spring's Singleton scope differ from the GoF Singleton pattern?

**Common Mistakes:**
- Forgetting `volatile` in DCL — leads to subtle race conditions that are hard to reproduce
- Using Singleton for stateful objects (user sessions, request data) — causes data leakage between threads
- Synchronizing the entire `getInstance()` method — unnecessary overhead after first initialization

**Interview Traps:**
- "Is an enum Singleton lazy?" — No, it initializes when the enum class is first loaded (effectively eager)
- "Two ClassLoaders in the same JVM can produce two Singleton instances" — this breaks the JVM guarantee and is a real issue in OSGi/application server environments

**Quick Revision:** Use `volatile` + DCL for lazy thread-safe Singleton; prefer enum Singleton for serialization safety; prefer Spring `@Service` in enterprise apps.

---

### Topic 2: Factory Method & Abstract Factory

![Factory Method UML class diagram](https://upload.wikimedia.org/wikipedia/commons/8/8e/Factory_Method_UML_class_diagram.svg)
*Factory Method — defines interface for creating objects, subclasses decide which class to instantiate*

![Abstract Factory UML class diagram](https://upload.wikimedia.org/wikipedia/commons/6/67/Abstract_Factory_UML_class_diagram.svg)
*Abstract Factory — creates families of related objects without specifying concrete classes*

**Difficulty:** Medium-High | **Frequency:** Very High | **Companies:** Amazon, Google, Netflix, Uber, Salesforce

**Q:** What is the difference between Factory Method and Abstract Factory? When would you use each? How does Spring use these patterns?

**Short Answer:**
Factory Method defines an interface for creating one product, letting subclasses decide which class to instantiate. Abstract Factory provides an interface for creating families of related products without specifying concrete classes. Use Factory Method when you have one product type with multiple variants; use Abstract Factory when you need multiple related products that must be used together.

**Deep Explanation:**

**Factory Method:**
- One factory method in a base class/interface
- Subclasses override to create a specific product
- "Define an interface for creating an object, but let subclasses decide which class to instantiate"
- OCP (Open/Closed Principle): add new products by adding new subclasses, not modifying existing code

**Abstract Factory:**
- Multiple factory methods grouped in one interface
- Creates a family of related objects (a product suite)
- "Provide an interface for creating families of related or dependent objects without specifying their concrete classes"
- Ensures that products from one factory are compatible with each other

**Key difference:** Factory Method is about one product with polymorphism; Abstract Factory is about a suite of related products.

**Spring BeanFactory as Abstract Factory:**
Spring's `BeanFactory` (and `ApplicationContext`) is the canonical Abstract Factory example in enterprise Java. It creates and wires beans of different types (DataSource, Service, Repository, Controller) and ensures they are properly connected — you get a consistent family of beans configured for your environment (dev, test, prod).

**UML (text) — Factory Method:**
```
DocumentParser (interface)
  + parse(String content): Document

PdfParser implements DocumentParser
XmlParser implements DocumentParser
JsonParser implements DocumentParser

ParserFactory (abstract)
  + createParser(): DocumentParser   ← Factory Method

PdfParserFactory extends ParserFactory
XmlParserFactory extends ParserFactory
```

**UML (text) — Abstract Factory:**
```
UIComponentFactory (interface)
  + createButton(): Button
  + createTextField(): TextField
  + createDialog(): Dialog

LightThemeFactory implements UIComponentFactory
DarkThemeFactory implements UIComponentFactory
```

**Real-World Example:**
A payment processing system: `PaymentProcessorFactory` can return `StripeProcessor`, `PayPalProcessor`, or `BraintreeProcessor` based on configuration (Factory Method). An Abstract Factory goes further: `PaymentEcosystemFactory` creates a consistent family — `PaymentProcessor` + `RefundProcessor` + `WebhookHandler` that all belong to the same provider (you can't mix Stripe's processor with PayPal's webhook handler).

**Code Example:**
```java
// =============================================
// FACTORY METHOD PATTERN
// =============================================

// Product interface
public interface DocumentParser {
    Document parse(String content);
    String getSupportedFormat();
}

// Concrete products
public class PdfParser implements DocumentParser {
    @Override
    public Document parse(String content) {
        System.out.println("Parsing PDF content");
        return new Document("PDF", content);
    }
    @Override public String getSupportedFormat() { return "PDF"; }
}

public class JsonParser implements DocumentParser {
    @Override
    public Document parse(String content) {
        System.out.println("Parsing JSON content");
        return new Document("JSON", content);
    }
    @Override public String getSupportedFormat() { return "JSON"; }
}

public class XmlParser implements DocumentParser {
    @Override
    public Document parse(String content) {
        System.out.println("Parsing XML content");
        return new Document("XML", content);
    }
    @Override public String getSupportedFormat() { return "XML"; }
}

// Document value object
public record Document(String format, String content) {}

// BEFORE: Messy if-else in caller (violates OCP)
public class DocumentService_Before {
    public Document processDocument(String content, String format) {
        if ("PDF".equals(format)) {
            return new PdfParser().parse(content);
        } else if ("JSON".equals(format)) {
            return new JsonParser().parse(content);
        } else if ("XML".equals(format)) {
            return new XmlParser().parse(content);
        }
        throw new IllegalArgumentException("Unknown format: " + format);
    }
}

// AFTER: Factory Method — static factory (simple form)
public class ParserFactory {
    public static DocumentParser create(String format) {
        return switch (format.toUpperCase()) {
            case "PDF"  -> new PdfParser();
            case "JSON" -> new JsonParser();
            case "XML"  -> new XmlParser();
            default     -> throw new IllegalArgumentException("Unsupported format: " + format);
        };
    }
}

// AFTER: Factory Method — polymorphic form (true GoF)
public abstract class DocumentProcessingService {
    // Factory Method — subclasses decide which parser to create
    protected abstract DocumentParser createParser();

    public final Document processDocument(String content) {
        DocumentParser parser = createParser();   // polymorphic creation
        Document doc = parser.parse(content);
        // common post-processing...
        return doc;
    }
}

public class PdfProcessingService extends DocumentProcessingService {
    @Override
    protected DocumentParser createParser() {
        return new PdfParser();
    }
}

public class JsonProcessingService extends DocumentProcessingService {
    @Override
    protected DocumentParser createParser() {
        return new JsonParser();
    }
}

// =============================================
// ABSTRACT FACTORY PATTERN
// =============================================

// Product interfaces
public interface NotificationSender {
    void send(String recipient, String message);
}

public interface NotificationLogger {
    void log(String event, String recipient);
}

public interface NotificationTracker {
    String track(String messageId);
}

// Abstract Factory
public interface NotificationFactory {
    NotificationSender createSender();
    NotificationLogger createLogger();
    NotificationTracker createTracker();
}

// Concrete family 1: Email
public class EmailSender implements NotificationSender {
    @Override public void send(String recipient, String message) {
        System.out.println("Sending email to " + recipient + ": " + message);
    }
}
public class EmailLogger implements NotificationLogger {
    @Override public void log(String event, String recipient) {
        System.out.println("Email log [" + event + "] -> " + recipient);
    }
}
public class EmailTracker implements NotificationTracker {
    @Override public String track(String messageId) { return "email-status-" + messageId; }
}

public class EmailNotificationFactory implements NotificationFactory {
    @Override public NotificationSender createSender()  { return new EmailSender(); }
    @Override public NotificationLogger createLogger()  { return new EmailLogger(); }
    @Override public NotificationTracker createTracker(){ return new EmailTracker(); }
}

// Concrete family 2: SMS (similarly defined)
public class SmsNotificationFactory implements NotificationFactory {
    @Override public NotificationSender createSender()  {
        return (r, m) -> System.out.println("SMS to " + r + ": " + m);
    }
    @Override public NotificationLogger createLogger()  {
        return (e, r) -> System.out.println("SMS log [" + e + "] -> " + r);
    }
    @Override public NotificationTracker createTracker(){
        return id -> "sms-status-" + id;
    }
}

// Client uses only the abstract factory — unaware of concrete types
public class NotificationService {
    private final NotificationSender sender;
    private final NotificationLogger logger;
    private final NotificationTracker tracker;

    public NotificationService(NotificationFactory factory) {
        this.sender  = factory.createSender();
        this.logger  = factory.createLogger();
        this.tracker = factory.createTracker();
    }

    public void notify(String recipient, String message) {
        sender.send(recipient, message);
        logger.log("SENT", recipient);
        System.out.println("Tracking: " + tracker.track("msg-001"));
    }
}

// Spring configuration as Abstract Factory
@Configuration
public class NotificationConfig {
    @Value("${notification.channel:email}")
    private String channel;

    @Bean
    public NotificationFactory notificationFactory() {
        return switch (channel) {
            case "sms"   -> new SmsNotificationFactory();
            default      -> new EmailNotificationFactory();
        };
    }

    @Bean
    public NotificationService notificationService(NotificationFactory factory) {
        return new NotificationService(factory);
    }
}

// Main demo
public class Main {
    public static void main(String[] args) {
        // Factory Method
        DocumentParser parser = ParserFactory.create("JSON");
        Document doc = parser.parse("{\"key\":\"value\"}");

        // Abstract Factory
        NotificationFactory factory = new EmailNotificationFactory();
        var service = new NotificationService(factory);
        service.notify("user@example.com", "Your order shipped!");

        // Switch entire family — no other code changes
        factory = new SmsNotificationFactory();
        service = new NotificationService(factory);
        service.notify("+15551234567", "Your order shipped!");
    }
}
```

**Follow-up Questions:**
1. How would you add a new parser type (e.g., CSV) to the Factory Method without modifying existing code?
2. What is the "product family consistency" problem that Abstract Factory solves?
3. How does Spring's `@Configuration` with `@Bean` methods implement the Abstract Factory pattern?

**Common Mistakes:**
- Confusing static factory methods (e.g., `List.of()`) with the Factory Method pattern — they are different
- Using Abstract Factory when you only have one product type — overkill; Factory Method suffices
- Making the factory a Singleton when it holds state that differs per request

**Interview Traps:**
- "Factory Method requires inheritance, but you can also implement it with lambdas/functional interfaces in Java 8+" — this is correct and shows modern Java knowledge
- "Abstract Factory can make adding new product types (not families) difficult" — adding a new method to the factory interface breaks all existing implementations

**Quick Revision:** Factory Method = one product, delegate creation to subclass; Abstract Factory = product family, ensure compatibility between products.

---

### Topic 3: Builder Pattern

![Builder UML class diagram](https://upload.wikimedia.org/wikipedia/commons/f/f3/Builder_UML_class_diagram.svg)
*Builder — separates construction of complex objects from their representation*

**Difficulty:** Easy-Medium | **Frequency:** Very High | **Companies:** Google, Amazon, Netflix, Stripe, Airbnb

**Q:** What problem does the Builder pattern solve? How does Lombok's `@Builder` work internally, and when would you prefer a manual Builder?

**Short Answer:**
Builder solves the "telescoping constructor" problem where a class with many optional parameters requires many constructor overloads. It separates object construction from representation, enables method chaining, and produces immutable objects. Lombok `@Builder` generates the builder class at compile time via annotation processing.

**Deep Explanation:**

**Telescoping Constructor Problem:**
When a class has N optional parameters, you need up to 2^N constructors (or one giant constructor where callers must pass nulls). This is unreadable, error-prone (wrong positional argument), and non-extensible.

**Builder vs Setters:**
- Setters allow mutability after construction — dangerous for multi-threaded code
- Setters provide no validation at "build time" — object can be in invalid intermediate state
- Builder validates all fields before constructing the object, ensuring invariants hold
- Builder creates immutable objects (all-final fields, no setters)

**Lombok @Builder internals:**
Lombok's annotation processor (`@Builder`) generates:
1. A static inner `Builder` class with one field per constructor parameter
2. Setter methods on `Builder` that return `this` (method chaining)
3. A `build()` method that calls the target class's constructor
4. A static `builder()` factory method on the outer class

The generated code is equivalent to a hand-written builder but eliminates boilerplate.

**Immutable Objects:**
Builder naturally produces immutable objects — the outer class has `final` fields, no setters, and is only constructed via `build()`.

**UML (text):**
```
HttpRequest (immutable product)
  - final String url
  - final String method
  - final Map<String,String> headers
  - final String body
  - final int timeoutMs

HttpRequest.Builder
  - url, method, headers, body, timeoutMs  (mutable working state)
  + url(String): Builder
  + method(String): Builder
  + header(String, String): Builder
  + body(String): Builder
  + timeoutMs(int): Builder
  + build(): HttpRequest  (validates + constructs)
```

**Real-World Example:**
`OkHttpClient.Builder`, `HttpRequest.newBuilder()` (Java 11 HttpClient), `UriComponentsBuilder` in Spring, `ResponseEntity` builder in Spring MVC, `CacheBuilder` in Guava. Any object with many optional configuration parameters benefits from Builder.

**Code Example:**
```java
// BEFORE: Telescoping constructor — unreadable, error-prone
public class HttpRequest_Before {
    private final String url;
    private final String method;
    private final Map<String, String> headers;
    private final String body;
    private final int timeoutMs;
    private final boolean followRedirects;

    // 6 constructors to handle different combinations
    public HttpRequest_Before(String url) {
        this(url, "GET", Map.of(), null, 5000, true);
    }
    public HttpRequest_Before(String url, String method) {
        this(url, method, Map.of(), null, 5000, true);
    }
    public HttpRequest_Before(String url, String method, Map<String, String> headers) {
        this(url, method, headers, null, 5000, true);
    }
    public HttpRequest_Before(String url, String method, Map<String, String> headers,
                               String body, int timeoutMs, boolean followRedirects) {
        this.url = url;
        this.method = method;
        this.headers = Map.copyOf(headers);
        this.body = body;
        this.timeoutMs = timeoutMs;
        this.followRedirects = followRedirects;
    }
    // Callers must remember argument order — easy to swap timeoutMs and followRedirects!
}

// AFTER: Builder Pattern — readable, immutable, validated
public final class HttpRequest {
    private final String url;
    private final String method;
    private final Map<String, String> headers;
    private final String body;
    private final int timeoutMs;
    private final boolean followRedirects;

    // Private constructor — only Builder can create instances
    private HttpRequest(Builder builder) {
        this.url             = builder.url;
        this.method          = builder.method;
        this.headers         = Map.copyOf(builder.headers);
        this.body            = builder.body;
        this.timeoutMs       = builder.timeoutMs;
        this.followRedirects = builder.followRedirects;
    }

    // Getters only — no setters (immutable)
    public String getUrl()          { return url; }
    public String getMethod()       { return method; }
    public Map<String, String> getHeaders() { return headers; }
    public String getBody()         { return body; }
    public int getTimeoutMs()       { return timeoutMs; }
    public boolean isFollowRedirects() { return followRedirects; }

    // Static factory method to get Builder
    public static Builder newBuilder(String url) {
        return new Builder(url);
    }

    public static final class Builder {
        // Required
        private final String url;

        // Optional with defaults
        private String method          = "GET";
        private Map<String, String> headers = new HashMap<>();
        private String body            = null;
        private int timeoutMs          = 5000;
        private boolean followRedirects = true;

        private Builder(String url) {
            if (url == null || url.isBlank()) {
                throw new IllegalArgumentException("URL must not be blank");
            }
            this.url = url;
        }

        public Builder method(String method) {
            this.method = Objects.requireNonNull(method, "method");
            return this;  // method chaining
        }

        public Builder header(String name, String value) {
            this.headers.put(
                Objects.requireNonNull(name),
                Objects.requireNonNull(value)
            );
            return this;
        }

        public Builder body(String body) {
            this.body = body;
            return this;
        }

        public Builder timeoutMs(int timeoutMs) {
            if (timeoutMs <= 0) throw new IllegalArgumentException("Timeout must be positive");
            this.timeoutMs = timeoutMs;
            return this;
        }

        public Builder followRedirects(boolean followRedirects) {
            this.followRedirects = followRedirects;
            return this;
        }

        // Validate and construct — all invariants checked here
        public HttpRequest build() {
            if ("POST".equals(method) || "PUT".equals(method)) {
                if (body == null) {
                    throw new IllegalStateException(method + " request requires a body");
                }
            }
            return new HttpRequest(this);
        }
    }
}

// Lombok @Builder — generates equivalent code at compile time
@Getter
@Builder(toBuilder = true)  // toBuilder = true allows copying with modifications
public final class UserProfile {
    @NonNull private final String userId;
    @NonNull private final String email;
    @Builder.Default private final String role = "USER";  // default value
    @Builder.Default private final boolean active = true;
    private final String phoneNumber;          // optional
    private final Instant createdAt;
}

// Spring entity with @Builder
@Entity
@Getter
@Builder
@NoArgsConstructor  // Required by JPA
@AllArgsConstructor // Required by @Builder
public class Order {
    @Id @GeneratedValue
    private Long id;

    @NonNull private String customerId;
    @NonNull private BigDecimal totalAmount;

    @Builder.Default
    @Enumerated(EnumType.STRING)
    private OrderStatus status = OrderStatus.PENDING;

    @Builder.Default
    private Instant createdAt = Instant.now();
}

enum OrderStatus { PENDING, CONFIRMED, SHIPPED, DELIVERED, CANCELLED }

// Usage
public class Main {
    public static void main(String[] args) {
        // Manual builder
        HttpRequest request = HttpRequest.newBuilder("https://api.example.com/orders")
            .method("POST")
            .header("Content-Type", "application/json")
            .header("Authorization", "Bearer token123")
            .body("{\"item\":\"book\",\"qty\":2}")
            .timeoutMs(3000)
            .build();

        // Lombok builder
        UserProfile user = UserProfile.builder()
            .userId("user-123")
            .email("alice@example.com")
            .role("ADMIN")
            .phoneNumber("+15551234567")
            .build();

        // Lombok toBuilder — copy with modification
        UserProfile deactivated = user.toBuilder()
            .active(false)
            .build();

        // Spring/JPA entity builder
        Order order = Order.builder()
            .customerId("cust-456")
            .totalAmount(new BigDecimal("99.99"))
            .build();
    }
}
```

**Follow-up Questions:**
1. How would you implement validation in a Builder that depends on multiple fields (cross-field validation)?
2. What is the difference between Lombok `@Builder` and `@SuperBuilder`, and when do you need `@SuperBuilder`?
3. How does the Builder pattern interact with the copy-on-modify (persistent data structure) pattern?

**Common Mistakes:**
- Forgetting `@NoArgsConstructor` and `@AllArgsConstructor` with Lombok `@Builder` on JPA entities — JPA requires a no-args constructor
- Making Builder fields non-final (they can be mutable since Builder itself is a temporary object) but making the product fields non-final (they should be final)
- Not validating in `build()` — defeats the purpose of Builder

**Interview Traps:**
- "Builder is always better than setters" — false for simple mutable objects in frameworks that require setters (e.g., Jackson deserialization without `@JsonDeserialize(builder=...)`)
- "Lombok @Builder generates immutable classes" — not automatically; you still need `@Getter` but no `@Setter`; fields need to be `final`

**Quick Revision:** Builder solves telescoping constructors; enables immutable objects with optional fields; validate in `build()`, not in setters.

---

### Topic 4: Prototype Pattern

**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Amazon, Oracle, Bloomberg, Goldman Sachs

**Q:** Explain shallow vs deep clone in the Prototype pattern. What are the pitfalls of Java's `Cloneable`, and what is the preferred alternative?

**Short Answer:**
Prototype creates new objects by copying existing ones, avoiding expensive creation from scratch. Java's `Cloneable` interface is a marker interface with no method — `clone()` is defined in `Object` and does shallow copy by default. Deep copy must be implemented manually. The preferred alternative is a copy constructor or copy factory method.

**Deep Explanation:**

**Shallow vs Deep Clone:**
- **Shallow clone:** Copies primitive fields by value, reference fields by reference. Both the original and the clone share the same referenced objects. Modifying a nested object through the clone affects the original.
- **Deep clone:** Recursively copies all nested objects. The clone is completely independent of the original.

**Cloneable Pitfalls (Effective Java Item 13):**
1. `Cloneable` doesn't declare `clone()` — you must override `Object.clone()` and cast
2. `Object.clone()` is `protected` — you must make it `public` in your class
3. If a superclass doesn't implement `clone()` correctly, your class is broken
4. Throws `CloneNotSupportedException` even though `Cloneable` is implemented
5. Final fields can't be assigned in `clone()` — incompatible with immutable objects
6. Deep copy requires manually cloning every mutable field

**Copy Constructor Alternative:**
A copy constructor takes an instance of the same class and creates a new instance by copying all fields. It is:
- Explicit (you control what is copied)
- Compatible with final fields
- Doesn't require try-catch
- Documented in the class signature

**Spring Prototype Scope:**
In Spring, `@Scope("prototype")` means a new bean instance is created every time it is requested from the container. Unlike GoF Prototype (which clones), Spring creates a fresh instance. Used for stateful beans (e.g., shopping cart, user session state) where each caller needs an independent copy.

**UML (text):**
```
DocumentTemplate (prototype)
  - title: String
  - sections: List<Section>  ← mutable, needs deep copy
  - metadata: Map<String,String>
  + clone(): DocumentTemplate  (shallow — WRONG for sections)
  + deepCopy(): DocumentTemplate  (correct)
  + DocumentTemplate(DocumentTemplate other)  (copy constructor — preferred)
```

**Real-World Example:**
A report template system: you have a base report template with standard sections, headers, and styling. For each report run, you clone the template and fill in the data. Creating a fresh template from scratch (parsing XML, loading resources) is expensive; cloning is cheap.

**Code Example:**
```java
import java.util.*;

// Section — a mutable nested object
public class Section {
    private String title;
    private String content;

    public Section(String title, String content) {
        this.title = title;
        this.content = content;
    }

    // Copy constructor for deep copy
    public Section(Section other) {
        this.title   = other.title;
        this.content = other.content;
    }

    public void setContent(String content) { this.content = content; }
    public String getTitle()   { return title; }
    public String getContent() { return content; }

    @Override public String toString() {
        return "Section{title='" + title + "', content='" + content + "'}";
    }
}

// BEFORE: Using Cloneable — problematic
public class ReportTemplate_Before implements Cloneable {
    private String name;
    private List<Section> sections;  // mutable!

    public ReportTemplate_Before(String name, List<Section> sections) {
        this.name = name;
        this.sections = new ArrayList<>(sections);
    }

    @Override
    public ReportTemplate_Before clone() {
        try {
            ReportTemplate_Before clone = (ReportTemplate_Before) super.clone();
            // super.clone() gives SHALLOW copy — sections list is shared!
            // clone.sections still points to same Section objects
            // We must deep copy manually:
            clone.sections = new ArrayList<>();
            for (Section s : this.sections) {
                clone.sections.add(new Section(s));  // deep copy each section
            }
            return clone;
        } catch (CloneNotSupportedException e) {
            throw new AssertionError("Should never happen", e);
        }
    }
}

// AFTER: Copy constructor — preferred approach
public class ReportTemplate {
    private final String name;
    private final List<Section> sections;
    private final Map<String, String> metadata;

    // Primary constructor
    public ReportTemplate(String name, List<Section> sections, Map<String, String> metadata) {
        this.name     = Objects.requireNonNull(name);
        this.sections = new ArrayList<>(Objects.requireNonNull(sections));
        this.metadata = new HashMap<>(Objects.requireNonNull(metadata));
    }

    // Copy constructor — explicit deep copy
    public ReportTemplate(ReportTemplate other) {
        this.name = other.name;
        // Deep copy each section
        this.sections = other.sections.stream()
            .map(Section::new)  // Section copy constructor
            .collect(java.util.stream.Collectors.toCollection(ArrayList::new));
        this.metadata = new HashMap<>(other.metadata);
    }

    // Static copy factory (alternative to copy constructor)
    public static ReportTemplate copyOf(ReportTemplate template) {
        return new ReportTemplate(template);
    }

    // Fluent modification — returns a copy with one field changed
    public ReportTemplate withName(String newName) {
        ReportTemplate copy = new ReportTemplate(this);
        // copy.name is final — can't reassign; would need to use a different approach
        // This is why Builder + Prototype often combine (toBuilder pattern)
        return new ReportTemplate(newName, copy.sections, copy.metadata);
    }

    public void addSection(Section section) {
        sections.add(new Section(section));  // defensive copy
    }

    public String getName()               { return name; }
    public List<Section> getSections()    { return Collections.unmodifiableList(sections); }
    public Map<String, String> getMetadata() { return Collections.unmodifiableMap(metadata); }

    @Override public String toString() {
        return "ReportTemplate{name='" + name + "', sections=" + sections + "}";
    }
}

// Spring Prototype scope
@Component
@Scope("prototype")  // New instance per injection point
public class ShoppingCart {
    private final List<String> items = new ArrayList<>();
    private String userId;

    public void setUserId(String userId) { this.userId = userId; }
    public void addItem(String item) { items.add(item); }
    public List<String> getItems() { return Collections.unmodifiableList(items); }
}

// In a service — each call gets a fresh ShoppingCart
@Service
public class OrderService {
    @Autowired
    private ApplicationContext ctx;

    public ShoppingCart createCartForUser(String userId) {
        // Must use ApplicationContext for prototype beans — @Autowired gives only one instance
        ShoppingCart cart = ctx.getBean(ShoppingCart.class);
        cart.setUserId(userId);
        return cart;
    }
}

// Demonstration of shallow vs deep copy problem
public class Main {
    public static void main(String[] args) {
        var original = new ReportTemplate(
            "Quarterly Report",
            List.of(new Section("Executive Summary", "Q3 results exceeded expectations")),
            Map.of("author", "Alice", "version", "1.0")
        );

        // Copy constructor — deep copy
        var copy = new ReportTemplate(original);
        copy.addSection(new Section("Appendix", "Raw data"));

        // Modifying copy does NOT affect original
        System.out.println("Original sections: " + original.getSections().size()); // 1
        System.out.println("Copy sections: " + copy.getSections().size());          // 2

        // Shallow copy problem — if we had used simple list reference copy:
        // List<Section> shallowList = original.getSections()
        // Modifying shallowList would affect original — BUG!
    }
}
```

**Follow-up Questions:**
1. How would you implement deep cloning for an object graph with circular references?
2. What is serialization-based deep cloning, and what are its trade-offs?
3. Why does `Object.clone()` return `Object` instead of the actual type, and how do covariant return types help?

**Common Mistakes:**
- Implementing `Cloneable` but only calling `super.clone()` without deep copying mutable fields — silent shallow copy bug
- Using serialization for deep clone without checking that all objects in the graph are `Serializable`
- Confusing Spring's `@Scope("prototype")` with GoF Prototype — Spring creates a new instance, not a clone

**Interview Traps:**
- "Java's `clone()` is a copy constructor" — false; `clone()` does not call any constructor, which means object invariants established in constructors may not hold
- "Deep copy is always better" — not necessarily; for immutable nested objects, shallow copy is safe and cheaper

**Quick Revision:** Prefer copy constructor over `Cloneable`; shallow copy shares references (dangerous for mutable fields); deep copy is independent but expensive.

---

### Topic 5: Adapter Pattern

![Adapter UML class diagram](https://upload.wikimedia.org/wikipedia/commons/8/8c/Adapter_using_delegation_UML_class_diagram.svg)
*Adapter — converts interface of a class into another interface clients expect*

**Difficulty:** Easy-Medium | **Frequency:** High | **Companies:** Amazon, Google, IBM, Oracle, Accenture

**Q:** What is the difference between class adapter and object adapter? How does the Adapter pattern enable legacy system integration?

**Short Answer:**
Adapter converts the interface of a class into another interface that clients expect, enabling incompatible classes to work together. Class adapter uses inheritance (only in languages with multiple inheritance); object adapter uses composition (preferred in Java). Spring's `HandlerAdapter` is a classic example of object adapter.

**Deep Explanation:**

**Class Adapter:**
- Uses multiple inheritance (or interface + inheritance)
- Inherits from both the target interface and the adaptee
- Tightly coupled — can only adapt one specific adaptee
- In Java: implements Target interface, extends Adaptee class
- Problem: less flexible, can't adapt subclasses of Adaptee

**Object Adapter:**
- Uses composition — holds a reference to the adaptee
- Implements the target interface, delegates to the adaptee
- Loosely coupled — can adapt any subclass of Adaptee
- Preferred in Java
- Can add behavior before/after delegation

**Two-Way Adapter:**
Implements both Target and Adaptee interfaces, translating in both directions.

**Spring HandlerAdapter:**
Spring MVC uses `HandlerAdapter` to invoke different controller types — `@Controller`, `HttpRequestHandler`, `Servlet` — through a uniform `handle(HttpServletRequest, HttpServletResponse, Object)` interface. Each adapter knows how to invoke one handler type. `DispatcherServlet` doesn't need to know which type of controller it's calling.

**UML (text) — Object Adapter:**
```
Client → [Target interface]
               ↑ implements
         [Adapter]
               ↓ has-a (composition)
         [Adaptee]
```

**Real-World Example:**
Integrating a third-party payment SDK that returns its own `ThirdPartyPaymentResult` with a proprietary structure into your system that expects your `PaymentResponse` domain object. The Adapter wraps the third-party call and translates the result.

**Code Example:**
```java
// =============================================
// LEGACY SYSTEM INTEGRATION SCENARIO
// =============================================

// Your new system's interface — what all payment processors must implement
public interface PaymentProcessor {
    PaymentResponse processPayment(PaymentRequest request);
    RefundResponse processRefund(String transactionId, BigDecimal amount);
}

// Your domain objects
public record PaymentRequest(String customerId, BigDecimal amount, String currency) {}
public record PaymentResponse(String transactionId, String status, BigDecimal amount) {}
public record RefundResponse(String refundId, String status) {}

// =============================================
// LEGACY SYSTEM — cannot be modified
// =============================================
// (Imagine this is a third-party library or legacy codebase)
public class LegacyPaymentGateway {
    public String charge(String userId, double amount, String currencyCode) {
        // Returns a raw charge ID like "CHG-12345"
        System.out.println("Legacy gateway: charging " + amount + " " + currencyCode);
        return "CHG-" + System.currentTimeMillis();
    }

    public boolean refund(String chargeId, double refundAmount) {
        System.out.println("Legacy gateway: refunding " + refundAmount + " for " + chargeId);
        return true;
    }
}

// =============================================
// BEFORE: Caller directly depends on legacy API — violates DIP
// =============================================
public class PaymentService_Before {
    private final LegacyPaymentGateway gateway = new LegacyPaymentGateway();

    public void process(String customerId, BigDecimal amount) {
        // Caller must know legacy API signature: double, not BigDecimal
        String chargeId = gateway.charge(customerId, amount.doubleValue(), "USD");
        System.out.println("Charged: " + chargeId);
        // Type conversion, currency code, response mapping scattered everywhere
    }
}

// =============================================
// AFTER: Object Adapter — translates interfaces
// =============================================
public class LegacyPaymentAdapter implements PaymentProcessor {
    private final LegacyPaymentGateway legacyGateway;  // composition

    public LegacyPaymentAdapter(LegacyPaymentGateway legacyGateway) {
        this.legacyGateway = legacyGateway;
    }

    @Override
    public PaymentResponse processPayment(PaymentRequest request) {
        // Adapt: translate new API to legacy API
        String chargeId = legacyGateway.charge(
            request.customerId(),
            request.amount().doubleValue(),     // BigDecimal → double
            request.currency()
        );
        // Adapt: translate legacy response to new domain object
        return new PaymentResponse(chargeId, "SUCCESS", request.amount());
    }

    @Override
    public RefundResponse processRefund(String transactionId, BigDecimal amount) {
        boolean success = legacyGateway.refund(transactionId, amount.doubleValue());
        return new RefundResponse("REF-" + transactionId, success ? "SUCCESS" : "FAILED");
    }
}

// New Stripe integration — also adapted to same interface
public class StripePaymentAdapter implements PaymentProcessor {
    // Imagine this wraps Stripe's SDK
    @Override
    public PaymentResponse processPayment(PaymentRequest request) {
        System.out.println("Stripe: processing " + request.amount() + " " + request.currency());
        return new PaymentResponse("stripe-txn-001", "SUCCESS", request.amount());
    }

    @Override
    public RefundResponse processRefund(String transactionId, BigDecimal amount) {
        return new RefundResponse("stripe-ref-001", "SUCCESS");
    }
}

// Service depends only on PaymentProcessor — unaware of legacy vs Stripe
@Service
public class PaymentService {
    private final PaymentProcessor processor;

    public PaymentService(PaymentProcessor processor) {  // DI — injected adapter
        this.processor = processor;
    }

    public PaymentResponse charge(String customerId, BigDecimal amount, String currency) {
        return processor.processPayment(new PaymentRequest(customerId, amount, currency));
    }
}

// Spring wires the appropriate adapter
@Configuration
public class PaymentConfig {
    @Bean
    @ConditionalOnProperty(name = "payment.provider", havingValue = "legacy")
    public PaymentProcessor legacyAdapter() {
        return new LegacyPaymentAdapter(new LegacyPaymentGateway());
    }

    @Bean
    @ConditionalOnProperty(name = "payment.provider", havingValue = "stripe", matchIfMissing = true)
    public PaymentProcessor stripeAdapter() {
        return new StripePaymentAdapter();
    }
}

// Usage
public class Main {
    public static void main(String[] args) {
        // Object adapter wrapping legacy system
        PaymentProcessor adapter = new LegacyPaymentAdapter(new LegacyPaymentGateway());
        PaymentService service = new PaymentService(adapter);

        PaymentResponse response = service.charge("cust-123", new BigDecimal("49.99"), "USD");
        System.out.println("Response: " + response);

        // Swap adapter — same service code, different implementation
        service = new PaymentService(new StripePaymentAdapter());
        response = service.charge("cust-123", new BigDecimal("49.99"), "USD");
        System.out.println("Response: " + response);
    }
}
```

**Follow-up Questions:**
1. How does the Adapter pattern differ from the Facade pattern? (Adapter wraps one class to change its interface; Facade wraps multiple classes to simplify)
2. Can you use an Adapter to add functionality, or is it strictly for interface translation?
3. How does Spring's `HandlerAdapter` allow `DispatcherServlet` to handle different controller types?

**Common Mistakes:**
- Conflating Adapter with Facade — Adapter changes interface without hiding complexity; Facade hides complexity
- Using class adapter (inheritance) when object adapter (composition) is more flexible
- Adding business logic in the Adapter — adapters should only translate, not transform

**Interview Traps:**
- "Adapter is the same as a Wrapper" — Wrapper is a colloquial term; Adapter specifically means adapting an interface to another; Decorator is also a wrapper but adds behavior
- "You always need an interface for Adapter to work" — not strictly true, but best practice for testability

**Quick Revision:** Adapter translates one interface to another using composition (object adapter); enables legacy integration without modifying existing code.

---

### Topic 6: Decorator Pattern

![Decorator UML class diagram](https://upload.wikimedia.org/wikipedia/commons/e/e9/Decorator_UML_class_diagram.svg)
*Decorator — wraps objects to add behavior dynamically without subclassing*

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Netflix, Spotify, Uber

**Q:** How does the Decorator pattern differ from inheritance? Give real-world Java examples. How does Spring AOP implement the Decorator pattern?

**Short Answer:**
Decorator adds behavior to an object at runtime without subclassing, by wrapping it in another object that implements the same interface. This enables combinatorial feature addition without a class explosion. Java I/O streams (`BufferedInputStream` wrapping `FileInputStream`) and Spring AOP's proxy-based advice are canonical examples.

**Deep Explanation:**

**Decorator vs Inheritance:**
- Inheritance adds behavior at compile time; Decorator adds at runtime
- With inheritance, N features on M base classes = N×M subclasses (class explosion)
- Decorator composes behaviors independently; any combination is possible without new classes
- Decorator requires the wrapped object to implement the same interface (Liskov Substitution)

**Java I/O Streams as Decorator:**
`InputStream` is the Component interface. `FileInputStream`, `ByteArrayInputStream` are Concrete Components. `FilterInputStream` is the Decorator base class. `BufferedInputStream`, `DataInputStream`, `GZIPInputStream` are Concrete Decorators that add buffering, typed reads, and decompression respectively.

```
new GZIPInputStream(new BufferedInputStream(new FileInputStream("file.gz")))
```
Each wrapper adds one behavior; you compose them freely.

**Spring AOP as Decorator:**
When you annotate a method with `@Transactional`, `@Cacheable`, or `@Secured`, Spring creates a proxy object that wraps your bean. The proxy intercepts method calls and applies the cross-cutting concern (transaction management, caching, security check) before/after delegating to your actual bean. This is the Decorator pattern implemented with JDK dynamic proxies or CGLIB.

**UML (text):**
```
NotificationService (Component interface)
  + send(String message): void

EmailNotificationService (Concrete Component)

NotificationDecorator (abstract Decorator)
  - wrapped: NotificationService

LoggingDecorator extends NotificationDecorator  (logs before/after)
RetryDecorator extends NotificationDecorator    (retries on failure)
RateLimitDecorator extends NotificationDecorator (throttles calls)
```

**Real-World Example:**
An HTTP client library: you start with a basic `HttpClient`. You wrap it with `AuthenticatedHttpClient` (adds Bearer token), wrap that with `RetryingHttpClient` (retries on 5xx), wrap that with `MetricsHttpClient` (records latency). Each concern is in its own decorator; you compose them as needed.

**Code Example:**
```java
// =============================================
// COMPONENT INTERFACE
// =============================================
public interface NotificationService {
    void send(String recipient, String message);
}

// =============================================
// CONCRETE COMPONENT — core functionality
// =============================================
public class EmailNotificationService implements NotificationService {
    @Override
    public void send(String recipient, String message) {
        System.out.println("Sending email to " + recipient + ": " + message);
    }
}

// =============================================
// BEFORE: Inheritance approach — class explosion
// =============================================
// EmailWithLogging extends EmailNotificationService
// EmailWithRetry extends EmailNotificationService
// EmailWithLoggingAndRetry extends EmailNotificationService  // ← combinatorial explosion!
// SmsWithLogging extends SmsNotificationService
// ... 2^N combinations for N features

// =============================================
// AFTER: Decorator pattern — compose behaviors
// =============================================

// Abstract Decorator — implements same interface, delegates to wrapped component
public abstract class NotificationDecorator implements NotificationService {
    protected final NotificationService wrapped;

    protected NotificationDecorator(NotificationService wrapped) {
        this.wrapped = Objects.requireNonNull(wrapped, "wrapped service must not be null");
    }
}

// Concrete Decorator 1: Logging
public class LoggingNotificationDecorator extends NotificationDecorator {
    private static final System.Logger LOGGER = System.getLogger(LoggingNotificationDecorator.class.getName());

    public LoggingNotificationDecorator(NotificationService wrapped) {
        super(wrapped);
    }

    @Override
    public void send(String recipient, String message) {
        LOGGER.log(System.Logger.Level.INFO, "Sending notification to: {0}", recipient);
        long start = System.currentTimeMillis();
        wrapped.send(recipient, message);  // delegate
        long elapsed = System.currentTimeMillis() - start;
        LOGGER.log(System.Logger.Level.INFO, "Notification sent in {0}ms", elapsed);
    }
}

// Concrete Decorator 2: Retry logic
public class RetryNotificationDecorator extends NotificationDecorator {
    private final int maxAttempts;

    public RetryNotificationDecorator(NotificationService wrapped, int maxAttempts) {
        super(wrapped);
        this.maxAttempts = maxAttempts;
    }

    @Override
    public void send(String recipient, String message) {
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                wrapped.send(recipient, message);
                return;  // success — exit
            } catch (Exception e) {
                if (attempt == maxAttempts) throw e;
                System.out.println("Attempt " + attempt + " failed, retrying...");
            }
        }
    }
}

// Concrete Decorator 3: Rate limiting
public class RateLimitNotificationDecorator extends NotificationDecorator {
    private final int maxPerMinute;
    private final java.util.concurrent.atomic.AtomicInteger count = new java.util.concurrent.atomic.AtomicInteger(0);
    private volatile long windowStart = System.currentTimeMillis();

    public RateLimitNotificationDecorator(NotificationService wrapped, int maxPerMinute) {
        super(wrapped);
        this.maxPerMinute = maxPerMinute;
    }

    @Override
    public synchronized void send(String recipient, String message) {
        long now = System.currentTimeMillis();
        if (now - windowStart > 60_000) {
            count.set(0);
            windowStart = now;
        }
        if (count.incrementAndGet() > maxPerMinute) {
            throw new RuntimeException("Rate limit exceeded: " + maxPerMinute + " per minute");
        }
        wrapped.send(recipient, message);
    }
}

// Spring AOP equivalent — Decorator via proxy
@Aspect
@Component
public class NotificationAspect {
    @Around("execution(* com.example..*NotificationService.send(..))")
    public Object aroundSend(ProceedingJoinPoint pjp) throws Throwable {
        String recipient = (String) pjp.getArgs()[0];
        System.out.println("AOP Decorator: before send to " + recipient);
        long start = System.currentTimeMillis();
        Object result = pjp.proceed();  // delegate to actual bean
        System.out.println("AOP Decorator: send took " + (System.currentTimeMillis() - start) + "ms");
        return result;
    }
}

// Java I/O Streams — classic Decorator
public class IoDecoratorDemo {
    public static void readCompressedFile(String path) throws Exception {
        // Composing decorators: FileInputStream → BufferedInputStream → GZIPInputStream
        try (var in = new java.util.zip.GZIPInputStream(
                         new java.io.BufferedInputStream(
                             new java.io.FileInputStream(path)))) {
            byte[] buffer = new byte[1024];
            int bytesRead;
            while ((bytesRead = in.read(buffer)) != -1) {
                System.out.write(buffer, 0, bytesRead);
            }
        }
    }
}

// Usage — compose decorators freely
public class Main {
    public static void main(String[] args) {
        // Base service
        NotificationService base = new EmailNotificationService();

        // Add logging
        NotificationService withLogging = new LoggingNotificationDecorator(base);

        // Add retry on top of logging
        NotificationService withRetry = new RetryNotificationDecorator(withLogging, 3);

        // Add rate limiting on top of everything
        NotificationService withRateLimit = new RateLimitNotificationDecorator(withRetry, 100);

        // Use — caller only sees NotificationService interface
        withRateLimit.send("user@example.com", "Your order has shipped!");

        // Different composition — no retry, just logging + rate limit
        NotificationService minimal = new RateLimitNotificationDecorator(
            new LoggingNotificationDecorator(base), 50);
        minimal.send("admin@example.com", "System alert!");
    }
}
```

**Follow-up Questions:**
1. How would you implement a Decorator that needs to access state from the wrapped object that isn't exposed in the interface?
2. When would you choose Decorator over AOP for cross-cutting concerns?
3. How does the Chain of Responsibility pattern differ from Decorator?

**Common Mistakes:**
- Forgetting that Decorator must implement the same interface as the component — otherwise the client can't use them interchangeably
- Adding Decorators in the wrong order (e.g., rate limiting after retry means retries count toward the rate limit)
- Using Decorator when the number of decorators applied is always fixed — simple subclassing may be cleaner

**Interview Traps:**
- "Spring AOP is exactly the Decorator pattern" — mostly true, but AOP is more powerful: it can intercept any method, not just interface methods; CGLIB-proxied beans don't require an interface
- "Java I/O is a good example of Decorator" — it is, but also often criticized because `FilterInputStream` doesn't override all methods properly

**Quick Revision:** Decorator wraps an object to add behavior at runtime; same interface as the wrapped object; compose multiple decorators for combinatorial features without subclassing.

---

### Topic 7: Facade Pattern

![Facade UML class diagram](https://upload.wikimedia.org/wikipedia/commons/d/d4/Facade_UML_class_diagram.svg)
*Facade — provides a simplified interface to a complex subsystem*

**Difficulty:** Easy | **Frequency:** High | **Companies:** Amazon, Microsoft, Pivotal, Oracle, SAP

**Q:** What problem does the Facade pattern solve? How is a service layer a Facade in Spring Boot applications?

**Short Answer:**
Facade provides a simplified, unified interface to a set of complex subsystems, reducing coupling between clients and the subsystem. In Spring Boot, the `@Service` layer acts as a Facade over the repository layer, external APIs, and domain logic. `RestTemplate`/`WebClient` are Facades over the HTTP protocol and serialization complexity.

**Deep Explanation:**

**Core Intent:**
Clients should not need to coordinate multiple subsystems directly. A Facade absorbs the complexity: it knows which subsystems to call, in what order, and how to handle partial failures. Clients communicate with only the Facade.

**Facade vs Adapter:**
- Adapter: changes interface to match what client expects (translation)
- Facade: simplifies multiple interfaces into one (simplification)
- A Facade doesn't translate interfaces; it orchestrates

**Facade vs Service Layer:**
In layered architecture:
- Controller → calls Service (Facade)
- Service orchestrates: Repository, ExternalAPI, DomainLogic, EventPublisher
- Client (Controller) doesn't know which repository or external API is involved

**Spring RestTemplate/WebClient as Facade:**
`RestTemplate` hides: HTTP connection management, serialization/deserialization (Jackson), header management, status code handling, redirect following. The caller just calls `restTemplate.getForObject(url, Type.class)`.

**UML (text):**
```
Client (Controller)
    ↓ calls
OrderFacade (@Service)
    ↓ orchestrates
├── OrderRepository (@Repository)
├── InventoryService (external gRPC)
├── PaymentService (external REST)
├── NotificationService (email/SMS)
└── AuditLogger (Kafka)

Client never directly touches any subsystem.
```

**Real-World Example:**
An e-commerce `OrderService`: to place an order, you must validate inventory, charge payment, create the order record, decrement inventory, send confirmation email, and publish an order event. Without Facade, the controller would need to orchestrate all of these. The `OrderService.placeOrder()` method is the Facade.

**Code Example:**
```java
// =============================================
// SUBSYSTEMS — complex, each does one thing
// =============================================

@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {}

@Repository
public interface CustomerRepository extends JpaRepository<Customer, Long> {}

// External inventory service client
@Component
public class InventoryClient {
    private final WebClient webClient;

    public InventoryClient(WebClient.Builder builder) {
        this.webClient = builder.baseUrl("http://inventory-service").build();
    }

    public boolean reserveItems(String productId, int quantity) {
        return Boolean.TRUE.equals(
            webClient.post()
                .uri("/reserve")
                .bodyValue(Map.of("productId", productId, "quantity", quantity))
                .retrieve()
                .bodyToMono(Boolean.class)
                .block()
        );
    }

    public void releaseReservation(String reservationId) {
        webClient.delete().uri("/reserve/" + reservationId).retrieve().bodyToMono(Void.class).block();
    }
}

// Payment client
@Component
public class PaymentClient {
    public PaymentResult charge(String customerId, BigDecimal amount) {
        System.out.println("Charging customer " + customerId + " for " + amount);
        return new PaymentResult("txn-" + System.currentTimeMillis(), "SUCCESS");
    }
    public record PaymentResult(String transactionId, String status) {}
}

// Notification client
@Component
public class NotificationClient {
    public void sendOrderConfirmation(String email, Long orderId) {
        System.out.println("Sending order confirmation to " + email + " for order " + orderId);
    }
}

// Event publisher
@Component
public class OrderEventPublisher {
    @Autowired
    private ApplicationEventPublisher publisher;

    public void publishOrderPlaced(Order order) {
        publisher.publishEvent(new OrderPlacedEvent(order));
    }
}

record OrderPlacedEvent(Order order) {}

// =============================================
// BEFORE: Controller orchestrates everything — WRONG
// =============================================
@RestController
public class OrderController_Before {
    @Autowired private OrderRepository orderRepo;
    @Autowired private CustomerRepository customerRepo;
    @Autowired private InventoryClient inventoryClient;
    @Autowired private PaymentClient paymentClient;
    @Autowired private NotificationClient notificationClient;
    @Autowired private OrderEventPublisher eventPublisher;

    @PostMapping("/orders")
    public ResponseEntity<Order> placeOrder(@RequestBody PlaceOrderRequest req) {
        // Controller knows too much — violation of SRP and high coupling
        var customer = customerRepo.findById(req.customerId()).orElseThrow();
        if (!inventoryClient.reserveItems(req.productId(), req.quantity())) {
            return ResponseEntity.badRequest().build();
        }
        var payment = paymentClient.charge(customer.getId().toString(), req.totalAmount());
        var order = new Order(/* ... */);
        orderRepo.save(order);
        notificationClient.sendOrderConfirmation(customer.getEmail(), order.getId());
        eventPublisher.publishOrderPlaced(order);
        return ResponseEntity.ok(order);
    }
}

// =============================================
// AFTER: Service layer as Facade — Controller just calls one method
// =============================================
@Service
@Transactional
public class OrderService {
    private final OrderRepository orderRepo;
    private final CustomerRepository customerRepo;
    private final InventoryClient inventoryClient;
    private final PaymentClient paymentClient;
    private final NotificationClient notificationClient;
    private final OrderEventPublisher eventPublisher;

    public OrderService(OrderRepository orderRepo, CustomerRepository customerRepo,
                        InventoryClient inventoryClient, PaymentClient paymentClient,
                        NotificationClient notificationClient, OrderEventPublisher eventPublisher) {
        this.orderRepo         = orderRepo;
        this.customerRepo      = customerRepo;
        this.inventoryClient   = inventoryClient;
        this.paymentClient     = paymentClient;
        this.notificationClient = notificationClient;
        this.eventPublisher    = eventPublisher;
    }

    // FACADE METHOD: one call, hides all orchestration
    public Order placeOrder(PlaceOrderRequest request) {
        // 1. Validate customer
        var customer = customerRepo.findById(request.customerId())
            .orElseThrow(() -> new CustomerNotFoundException(request.customerId()));

        // 2. Reserve inventory
        if (!inventoryClient.reserveItems(request.productId(), request.quantity())) {
            throw new InsufficientInventoryException(request.productId());
        }

        // 3. Process payment
        var payment = paymentClient.charge(customer.getId().toString(), request.totalAmount());
        if (!"SUCCESS".equals(payment.status())) {
            throw new PaymentFailedException(payment.transactionId());
        }

        // 4. Persist order
        var order = Order.builder()
            .customerId(customer.getId())
            .productId(request.productId())
            .quantity(request.quantity())
            .totalAmount(request.totalAmount())
            .transactionId(payment.transactionId())
            .status(OrderStatus.CONFIRMED)
            .build();
        Order saved = orderRepo.save(order);

        // 5. Notify and publish event (non-transactional side effects)
        notificationClient.sendOrderConfirmation(customer.getEmail(), saved.getId());
        eventPublisher.publishOrderPlaced(saved);

        return saved;
    }
}

// Thin controller — just HTTP concerns
@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {
    private final OrderService orderService;  // only dependency

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping
    public ResponseEntity<Order> placeOrder(@Valid @RequestBody PlaceOrderRequest request) {
        Order order = orderService.placeOrder(request);  // one call to Facade
        return ResponseEntity.status(HttpStatus.CREATED).body(order);
    }
}

// Spring RestTemplate as Facade over HTTP complexity
@Component
public class ExternalProductService {
    private final RestTemplate restTemplate;

    public ExternalProductService(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    // Facade: caller doesn't deal with HTTP, headers, deserialization
    public ProductDto getProduct(String productId) {
        return restTemplate.getForObject(
            "https://products-api.example.com/products/{id}",
            ProductDto.class,
            productId
        );
    }
}

record PlaceOrderRequest(Long customerId, String productId, int quantity, BigDecimal totalAmount) {}
record ProductDto(String id, String name, BigDecimal price) {}
class CustomerNotFoundException extends RuntimeException {
    public CustomerNotFoundException(Long id) { super("Customer not found: " + id); }
}
class InsufficientInventoryException extends RuntimeException {
    public InsufficientInventoryException(String id) { super("Insufficient inventory: " + id); }
}
class PaymentFailedException extends RuntimeException {
    public PaymentFailedException(String txnId) { super("Payment failed: " + txnId); }
}
```

**Follow-up Questions:**
1. Can a Facade violate the Single Responsibility Principle? How do you keep the Facade from becoming a "God class"?
2. How does the Facade pattern support the "Don't talk to strangers" principle (Law of Demeter)?
3. Should a Facade be stateless? What are the implications of stateful Facades?

**Common Mistakes:**
- Making the Facade a "God service" that accumulates every business operation — split by subdomain
- Exposing subsystem details through the Facade's return types — return clean DTOs, not JPA entities
- Using Facade for authorization/caching logic — those are cross-cutting concerns better handled by Decorator/AOP

**Interview Traps:**
- "Facade hides the subsystem so it can't be used directly" — false; Facade adds a simplified interface but doesn't prevent direct access; it's a convention, not enforcement
- "Service layer is always a Facade" — not always; a thin service that just calls one repository method is not really a Facade

**Quick Revision:** Facade provides a single entry point to a complex subsystem; in Spring, the `@Service` layer is a Facade over repositories, external clients, and domain logic.

---

### Topic 8: Proxy Pattern

**Difficulty:** High | **Frequency:** Very High | **Companies:** Amazon, Google, Netflix, Spring/Pivotal, Oracle

**Q:** What are the differences between JDK dynamic proxy and CGLIB proxy? How does Spring AOP decide which to use? What is a virtual proxy?

**Short Answer:**
Proxy provides a surrogate for another object to control access. JDK dynamic proxy generates an interface-based proxy at runtime; it requires the target to implement an interface. CGLIB generates a subclass-based proxy; it works on classes without interfaces but cannot proxy `final` classes/methods. Spring AOP uses JDK proxy when the target implements an interface and CGLIB otherwise (or always CGLIB with `proxyTargetClass=true`).

**Deep Explanation:**

**Static Proxy:**
- Written by hand; implements the same interface as the target
- Compile-time; no reflection
- Does not scale — one proxy class per service

**JDK Dynamic Proxy:**
- Generated at runtime by `java.lang.reflect.Proxy.newProxyInstance()`
- Requires an interface (creates a class that implements that interface)
- Each method call goes through `InvocationHandler.invoke()`
- Fast for interface-based services
- Limitation: cannot proxy classes without interfaces

**CGLIB Proxy:**
- Generates a subclass of the target class at runtime (bytecode generation)
- Works without interfaces
- Cannot proxy `final` classes or `final` methods
- Slightly slower first instantiation (bytecode generation) but similar runtime performance
- Used by Spring for `@Configuration` classes

**Spring AOP Proxy Selection:**
1. Target implements interface → JDK dynamic proxy (default)
2. Target does NOT implement interface → CGLIB automatically
3. `@EnableAspectJAutoProxy(proxyTargetClass = true)` → always CGLIB
4. Spring Boot auto-configures `proxyTargetClass = true` by default since Spring Boot 2.x

**Hibernate Lazy Loading (Virtual Proxy):**
When you fetch an entity with a `@ManyToOne` relationship with `FetchType.LAZY`, Hibernate doesn't immediately load the related entity. Instead, it injects a proxy object (a CGLIB subclass of the entity). The proxy's fields are uninitialized. The first time you call any method on it, the proxy fires a SQL query and loads the real data. This is the Virtual Proxy pattern — deferring expensive resource creation until first use.

**Proxy Types Summary:**
| Type | Purpose | Java Example |
|---|---|---|
| Virtual Proxy | Defer expensive creation | Hibernate lazy loading |
| Remote Proxy | Represent remote object | RMI stub, gRPC stub |
| Protection Proxy | Access control | Spring Security proxy |
| Caching Proxy | Cache results | Spring `@Cacheable` |
| Logging Proxy | Audit method calls | Spring AOP `@Around` |

**UML (text):**
```
Subject (interface)
  + request(): void

RealSubject implements Subject   (actual implementation)

Proxy implements Subject
  - realSubject: RealSubject    (holds reference to real object)
  + request(): void             (controls access, may delegate to realSubject)
```

**Real-World Example:**
A financial audit system: every method call on `TradeService` must be logged for regulatory compliance. A Protection Proxy checks caller permissions before delegating. A Logging Proxy records all inputs/outputs. These are implemented as CGLIB proxies by Spring AOP.

**Code Example:**
```java
import java.lang.reflect.*;
import java.util.concurrent.ConcurrentHashMap;

// =============================================
// SUBJECT INTERFACE
// =============================================
public interface UserService {
    User findById(Long id);
    User save(User user);
    void delete(Long id);
}

// Simple User record
public record User(Long id, String name, String email) {}

// =============================================
// REAL SUBJECT
// =============================================
public class UserServiceImpl implements UserService {
    private final Map<Long, User> store = new HashMap<>();

    @Override
    public User findById(Long id) {
        System.out.println("DB query: SELECT * FROM users WHERE id=" + id);
        return store.get(id);
    }

    @Override
    public User save(User user) {
        store.put(user.id(), user);
        System.out.println("DB insert/update: user " + user.id());
        return user;
    }

    @Override
    public void delete(Long id) {
        store.remove(id);
        System.out.println("DB delete: user " + id);
    }
}

// =============================================
// STATIC PROXY — written by hand
// =============================================
public class LoggingUserServiceProxy implements UserService {
    private final UserService delegate;

    public LoggingUserServiceProxy(UserService delegate) {
        this.delegate = delegate;
    }

    @Override
    public User findById(Long id) {
        System.out.println("[LOG] findById(" + id + ")");
        long start = System.nanoTime();
        User result = delegate.findById(id);  // delegate
        long elapsed = System.nanoTime() - start;
        System.out.println("[LOG] findById returned in " + elapsed / 1_000 + "μs");
        return result;
    }

    @Override
    public User save(User user) {
        System.out.println("[LOG] save(user=" + user.id() + ")");
        return delegate.save(user);
    }

    @Override
    public void delete(Long id) {
        System.out.println("[LOG] delete(" + id + ")");
        delegate.delete(id);
    }
}

// =============================================
// JDK DYNAMIC PROXY — runtime generated, interface required
// =============================================
public class DynamicProxyFactory {

    @SuppressWarnings("unchecked")
    public static <T> T createLoggingProxy(T target, Class<T> interfaceClass) {
        return (T) Proxy.newProxyInstance(
            interfaceClass.getClassLoader(),
            new Class<?>[]{ interfaceClass },
            new LoggingInvocationHandler(target)
        );
    }

    private static class LoggingInvocationHandler implements InvocationHandler {
        private final Object target;

        LoggingInvocationHandler(Object target) {
            this.target = target;
        }

        @Override
        public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
            System.out.printf("[DYN-PROXY] %s(%s)%n",
                method.getName(),
                args != null ? Arrays.toString(args) : "");
            long start = System.nanoTime();
            try {
                Object result = method.invoke(target, args);  // delegate
                System.out.printf("[DYN-PROXY] %s completed in %dμs%n",
                    method.getName(), (System.nanoTime() - start) / 1_000);
                return result;
            } catch (InvocationTargetException e) {
                System.out.println("[DYN-PROXY] " + method.getName() + " threw: " + e.getCause());
                throw e.getCause();
            }
        }
    }
}

// =============================================
// CACHING PROXY — virtual proxy pattern
// =============================================
public class CachingUserServiceProxy implements UserService {
    private final UserService delegate;
    private final Map<Long, User> cache = new ConcurrentHashMap<>();

    public CachingUserServiceProxy(UserService delegate) {
        this.delegate = delegate;
    }

    @Override
    public User findById(Long id) {
        return cache.computeIfAbsent(id, key -> {
            System.out.println("[CACHE MISS] Loading user " + key);
            return delegate.findById(key);
        });
    }

    @Override
    public User save(User user) {
        User saved = delegate.save(user);
        cache.put(saved.id(), saved);  // update cache
        return saved;
    }

    @Override
    public void delete(Long id) {
        delegate.delete(id);
        cache.remove(id);  // invalidate cache
    }
}

// =============================================
// SPRING AOP — CGLIB/JDK proxy via aspects
// =============================================

// @Transactional is implemented as a proxy
@Service
public class TransactionalUserService {
    @Autowired private UserRepository userRepository;

    @Transactional  // Spring creates a proxy that manages the transaction
    public User createUser(String name, String email) {
        // Spring proxy: BEGIN TRANSACTION
        var entity = new UserEntity(name, email);
        return userRepository.save(entity);
        // Spring proxy: COMMIT or ROLLBACK
    }

    @Cacheable("users")  // Spring creates caching proxy
    public UserEntity getUser(Long id) {
        return userRepository.findById(id).orElseThrow();
    }
}

// Spring AOP explicit proxy
@Aspect
@Component
public class SecurityProxy {
    @Before("@annotation(RequiresRole)")
    public void checkRole(JoinPoint jp) {
        var annotation = ((MethodSignature) jp.getSignature())
            .getMethod().getAnnotation(RequiresRole.class);
        String required = annotation.value();
        // Check SecurityContext
        var auth = org.springframework.security.core.context.SecurityContextHolder
            .getContext().getAuthentication();
        boolean hasRole = auth.getAuthorities().stream()
            .anyMatch(a -> a.getAuthority().equals("ROLE_" + required));
        if (!hasRole) {
            throw new org.springframework.security.access.AccessDeniedException(
                "Role required: " + required);
        }
    }
}

@Retention(java.lang.annotation.RetentionPolicy.RUNTIME)
@Target(java.lang.annotation.ElementType.METHOD)
@interface RequiresRole {
    String value();
}

// =============================================
// HIBERNATE VIRTUAL PROXY DEMO
// =============================================
@Entity
public class OrderEntity {
    @Id @GeneratedValue private Long id;
    private String productId;

    @ManyToOne(fetch = FetchType.LAZY)  // Hibernate creates a CGLIB proxy for Customer
    @JoinColumn(name = "customer_id")
    private CustomerEntity customer;    // This is a proxy until accessed

    // When you call order.getCustomer().getEmail(), Hibernate proxy fires SELECT
}

// Usage
public class Main {
    public static void main(String[] args) {
        UserService real = new UserServiceImpl();

        // Static proxy
        UserService logged = new LoggingUserServiceProxy(real);
        logged.save(new User(1L, "Alice", "alice@example.com"));
        logged.findById(1L);

        // JDK Dynamic proxy
        UserService dynamicProxy = DynamicProxyFactory.createLoggingProxy(real, UserService.class);
        dynamicProxy.findById(1L);

        // Caching proxy wrapping logging proxy (composing proxies)
        UserService cached = new CachingUserServiceProxy(logged);
        cached.findById(1L);  // cache miss — calls real
        cached.findById(1L);  // cache hit — no DB call

        // Check if Spring bean is a proxy
        // In Spring: AopUtils.isAopProxy(bean), AopUtils.isCglibProxy(bean)
        System.out.println("Dynamic proxy class: " + dynamicProxy.getClass().getName());
        // Output: com.sun.proxy.$Proxy0
    }
}
```

**Follow-up Questions:**
1. What is the "self-invocation" problem with Spring AOP proxies, and how do you work around it?
2. Why can't CGLIB proxy `final` classes? What is the underlying JVM reason?
3. How does Spring Boot decide between JDK proxy and CGLIB when `spring.aop.proxy-target-class` is not set?

**Common Mistakes:**
- Calling a `@Transactional` method from within the same bean (self-invocation bypasses the proxy)
- Applying `@Transactional` on `private` or `final` methods with CGLIB — they cannot be proxied
- Expecting `instanceof` checks to work the same on proxied beans — `AopUtils.getTargetClass(bean)` returns the real class

**Interview Traps:**
- "Spring always uses JDK proxy for interfaces" — changed in Spring Boot 2.0+; CGLIB is the default even for interface-backed beans unless configured otherwise
- "You can't use JDK proxy without an interface" — correct; this is why plain `@Service` classes (without interface) always get CGLIB
- "CGLIB proxy calls the constructor" — yes, CGLIB calls the no-arg constructor of the superclass; if your class has side effects in the constructor, be careful

**Quick Revision:** JDK proxy = interface required, reflection-based; CGLIB = subclass-based, no interface needed, can't proxy `final`; Spring Boot 2+ defaults to CGLIB; virtual proxy defers object creation until first access.

---

## Part A Summary — Quick Reference

| Pattern | Problem Solved | Key Class/Interface | Spring Example |
|---|---|---|---|
| Singleton | One instance | `volatile` + DCL / enum | `@Service`, `@Component` |
| Factory Method | Delegate creation | Abstract factory method | `BeanFactory`, `@Bean` |
| Abstract Factory | Product families | Interface with multiple `create*()` | `ApplicationContext` |
| Builder | Telescoping constructors | Inner `Builder` class | `UriComponentsBuilder` |
| Prototype | Clone objects | Copy constructor / `Cloneable` | `@Scope("prototype")` |
| Adapter | Incompatible interfaces | Implements Target, holds Adaptee | `HandlerAdapter` |
| Decorator | Add behavior at runtime | Wraps same interface | Spring AOP, Java I/O |
| Facade | Simplify subsystems | Orchestrates multiple classes | `@Service`, `RestTemplate` |
| Proxy | Control access | Implements same interface | `@Transactional`, `@Cacheable` |

---

## Part A Cheat Sheet — One-Liners

- **Singleton:** One instance per JVM; `volatile` + DCL or enum; Spring beans are per-ApplicationContext.
- **Factory Method:** Define creation in an interface; subclasses decide the concrete type.
- **Abstract Factory:** Creates compatible families of products; swap entire families by swapping the factory.
- **Builder:** `final` fields + inner Builder + validate in `build()`; Lombok `@Builder` generates this.
- **Prototype:** Prefer copy constructor over `Cloneable`; deep copy mutable fields; Spring prototype = new instance per request.
- **Adapter:** Composition-based interface translation; enables legacy integration without modifying legacy code.
- **Decorator:** Same interface, wraps another instance, adds behavior; compose multiple decorators freely.
- **Facade:** Single entry point to complex subsystem; `@Service` layer in Spring is a Facade.
- **Proxy:** Controls access to subject; JDK proxy requires interface; CGLIB extends class; Spring Boot 2+ defaults to CGLIB.

---

*Part B (Chapter 19) covers Behavioral Patterns: Observer, Strategy, Command, Template Method, Chain of Responsibility, Iterator, State, and Mediator.*


---

# Chapter 19 — Design Patterns (Part B): Behavioral Patterns
## Java Backend Interview Handbook | Volume 5: System Design & LLD
### Target: SDE2 / FAANG+ | Java 17 | Spring Boot 3.x

---

## Table of Contents

- [Topic 9: Observer Pattern](#topic-9-observer-pattern)
- [Topic 10: Strategy Pattern](#topic-10-strategy-pattern)
- [Topic 11: Template Method Pattern](#topic-11-template-method-pattern)
- [Topic 12: Command Pattern](#topic-12-command-pattern)
- [Topic 13: Chain of Responsibility](#topic-13-chain-of-responsibility)
- [Topic 14: State Pattern](#topic-14-state-pattern)
- [Topic 15: Composite & Iterator Patterns](#topic-15-composite--iterator-patterns)
- [Master Cheat Sheet](#master-cheat-sheet)

---

## Topic 9: Observer Pattern

### Core Concept

The Observer pattern defines a **one-to-many dependency** between objects so that when one object (the Subject/Observable) changes state, all its dependents (Observers) are notified and updated automatically. It is the canonical implementation of the **publish-subscribe** paradigm.

**Key participants:**
- `Subject` (Observable): maintains a list of observers, notifies them on state changes
- `Observer`: defines the update interface
- `ConcreteSubject`: stores state, sends notifications
- `ConcreteObserver`: implements the update reaction

---

### Push vs Pull Model

| Dimension | Push Model | Pull Model |
|---|---|---|
| Data direction | Subject pushes data to Observer | Observer pulls data from Subject |
| Observer knows about Subject | No — receives payload | Yes — holds reference to Subject |
| Coupling | Looser (Observer is passive) | Tighter (Observer must query Subject) |
| Bandwidth | May push unnecessary data | Observer fetches only what it needs |
| Use case | Event streaming, notifications | Polling dashboards, lazy evaluation |
| Java example | `ActionListener.actionPerformed(ActionEvent e)` — event carries data | `Observable.update(Observable o, Object arg)` — arg is null, observer calls `o.getState()` |

**Rule of thumb:** Push model is preferred when the payload is small and always relevant. Pull model suits cases where observers have different data needs or the dataset is large.

---

### Vanilla Java Implementation

```java
// Subject interface
public interface EventSource<T> {
    void subscribe(EventObserver<T> observer);
    void unsubscribe(EventObserver<T> observer);
    void publish(T event);
}

// Observer interface
@FunctionalInterface
public interface EventObserver<T> {
    void onEvent(T event);
}

// Concrete Subject — thread-safe
public class StockTicker implements EventSource<StockPrice> {

    private final String symbol;
    private final CopyOnWriteArrayList<EventObserver<StockPrice>> observers
            = new CopyOnWriteArrayList<>();
    private volatile StockPrice latestPrice;

    public StockTicker(String symbol) {
        this.symbol = symbol;
    }

    @Override
    public void subscribe(EventObserver<StockPrice> observer) {
        observers.add(observer);
    }

    @Override
    public void unsubscribe(EventObserver<StockPrice> observer) {
        observers.remove(observer);
    }

    @Override
    public void publish(StockPrice event) {
        this.latestPrice = event;
        observers.forEach(o -> o.onEvent(event));
    }

    // Pull model accessor — for observers that prefer polling
    public StockPrice getLatestPrice() {
        return latestPrice;
    }
}

// Usage
StockTicker ticker = new StockTicker("AAPL");
ticker.subscribe(price -> System.out.println("Portfolio: " + price));
ticker.subscribe(price -> alertIfDrop(price));          // lambda = FunctionalInterface
ticker.publish(new StockPrice("AAPL", 189.50));
```

---

### Java Standard Library: EventListener

Java AWT/Swing formalizes Observer through `java.util.EventListener`:

```java
// The marker interface
public interface EventListener {}

// Domain event
public class OrderEvent extends EventObject {
    private final OrderStatus status;

    public OrderEvent(Object source, OrderStatus status) {
        super(source);
        this.status = status;
    }
    public OrderStatus getStatus() { return status; }
}

// Typed listener
@FunctionalInterface
public interface OrderEventListener extends EventListener {
    void onOrderEvent(OrderEvent event);
}

// Subject using EventListenerList (thread-safe Swing pattern)
public class OrderService {
    private final EventListenerList listenerList = new EventListenerList();

    public void addOrderListener(OrderEventListener l) {
        listenerList.add(OrderEventListener.class, l);
    }

    protected void fireOrderEvent(OrderStatus status) {
        OrderEvent event = null;
        for (OrderEventListener l : listenerList.getListeners(OrderEventListener.class)) {
            if (event == null) event = new OrderEvent(this, status);
            l.onOrderEvent(event);
        }
    }

    public void placeOrder(Order order) {
        // business logic ...
        fireOrderEvent(OrderStatus.PLACED);
    }
}
```

---

### Spring ApplicationEvent / ApplicationEventPublisher

Spring's event system is Observer built into the framework. As of Spring 4.2, `@EventListener` eliminates boilerplate.

```java
// 1. Define the event (extends ApplicationEvent or is a plain POJO in Spring 4.2+)
public record OrderPlacedEvent(String orderId, BigDecimal amount, String customerId) {}

// 2. Publisher — inject ApplicationEventPublisher
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public Order placeOrder(PlaceOrderRequest request) {
        Order order = orderRepository.save(Order.from(request));
        // Event is published AFTER the transaction commits (see TransactionalEventListener)
        eventPublisher.publishEvent(new OrderPlacedEvent(
            order.getId(), order.getAmount(), order.getCustomerId()
        ));
        return order;
    }
}

// 3a. Simple synchronous listener
@Component
public class EmailNotificationListener {

    @EventListener
    public void handleOrderPlaced(OrderPlacedEvent event) {
        sendConfirmationEmail(event.customerId(), event.orderId());
    }
}

// 3b. Transactional listener — runs AFTER commit (prevents phantom sends on rollback)
@Component
public class InventoryReservationListener {

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleOrderPlaced(OrderPlacedEvent event) {
        reserveInventory(event.orderId());
    }
}

// 3c. Async listener — non-blocking
@Component
public class AnalyticsListener {

    @Async
    @EventListener
    public void trackOrderPlaced(OrderPlacedEvent event) {
        analyticsService.track("order_placed", event.amount());
    }
}
```

**Spring event phases:**
- `BEFORE_COMMIT` — validate before committing
- `AFTER_COMMIT` — trigger side effects after data is persisted (most common)
- `AFTER_ROLLBACK` — compensating actions
- `AFTER_COMPLETION` — runs regardless of outcome

---

### Kafka as a Distributed Observer

For cross-service notification at scale, Kafka implements Observer at the infrastructure level:

| Observer concept | Kafka equivalent |
|---|---|
| Subject (Observable) | Producer / Kafka Topic |
| Observer | Consumer Group |
| subscribe() | Consumer group subscription |
| unsubscribe() | Stop consumer, adjust group membership |
| Push notification | Kafka broker pushes to consumer via poll |
| Fan-out | Multiple consumer groups on same topic |

```java
// Producer = Subject
@Service
@RequiredArgsConstructor
public class OrderEventProducer {

    private final KafkaTemplate<String, OrderPlacedEvent> kafkaTemplate;

    public void publishOrderPlaced(OrderPlacedEvent event) {
        kafkaTemplate.send("order-events", event.orderId(), event)
            .whenComplete((result, ex) -> {
                if (ex != null) log.error("Failed to publish", ex);
            });
    }
}

// Consumer = Observer (independent microservice)
@Component
public class InventoryService {

    @KafkaListener(topics = "order-events", groupId = "inventory-group")
    public void onOrderPlaced(OrderPlacedEvent event) {
        reserveInventory(event.orderId());
    }
}
```

**Key differences from in-process Observer:**
- **Durability**: Events persist on disk; observers can replay
- **Backpressure**: Consumer controls polling rate
- **Decoupling**: Producer and consumer don't share a JVM
- **At-least-once vs exactly-once**: Must design idempotent observers

---

### Interview Questions

**Q1: What is the difference between Observer and Pub-Sub patterns?**

Observer: the Subject knows its Observers directly (direct coupling). Pub-Sub: Publisher and Subscriber communicate through a **message broker/event bus**; they don't know each other. Spring's `ApplicationEventPublisher` is closer to Pub-Sub because the publisher doesn't hold references to listeners.

**Q2: How do you prevent memory leaks with Observer?**

Use `WeakReference` for observers, or ensure explicit `unsubscribe()` in lifecycle methods. In Spring, `@EventListener` beans are managed by the container and cleaned up automatically.

**Q3: Why use `@TransactionalEventListener` instead of `@EventListener` for database side effects?**

`@EventListener` fires during the transaction; if the listener throws, it can roll back the outer transaction. `@TransactionalEventListener(AFTER_COMMIT)` fires only after the transaction has committed successfully, preventing phantom side effects on rollback.

---

## Topic 10: Strategy Pattern

![Strategy Pattern UML class diagram](https://upload.wikimedia.org/wikipedia/commons/0/08/StrategyPatternClassDiagram.svg)
*Strategy — defines a family of algorithms, encapsulates each, makes them interchangeable*

### Core Concept

The Strategy pattern defines a **family of algorithms**, encapsulates each one, and makes them interchangeable. Strategy lets the algorithm vary independently from clients that use it. It is the primary tool for **eliminating if-else chains** and enabling **runtime algorithm swapping**.

**Key participants:**
- `Strategy`: interface declaring the algorithm
- `ConcreteStrategy`: specific algorithm implementation
- `Context`: holds a reference to a Strategy and delegates to it

---

### Replacing If-Else Chains

**Before — procedural anti-pattern:**

```java
// Violates Open/Closed Principle — every new payment type requires modifying this method
public BigDecimal calculateShipping(Order order, String shippingType) {
    if ("STANDARD".equals(shippingType)) {
        return order.getWeight().multiply(new BigDecimal("0.50"));
    } else if ("EXPRESS".equals(shippingType)) {
        return order.getWeight().multiply(new BigDecimal("1.50")).add(new BigDecimal("5.00"));
    } else if ("OVERNIGHT".equals(shippingType)) {
        return new BigDecimal("25.00");
    } else {
        throw new IllegalArgumentException("Unknown shipping type: " + shippingType);
    }
}
```

**After — Strategy pattern:**

```java
// Strategy interface
@FunctionalInterface
public interface ShippingStrategy {
    BigDecimal calculate(Order order);
}

// Concrete strategies
public class StandardShipping implements ShippingStrategy {
    @Override
    public BigDecimal calculate(Order order) {
        return order.getWeight().multiply(new BigDecimal("0.50"));
    }
}

public class ExpressShipping implements ShippingStrategy {
    private static final BigDecimal RATE = new BigDecimal("1.50");
    private static final BigDecimal SURCHARGE = new BigDecimal("5.00");

    @Override
    public BigDecimal calculate(Order order) {
        return order.getWeight().multiply(RATE).add(SURCHARGE);
    }
}

public class OvernightShipping implements ShippingStrategy {
    @Override
    public BigDecimal calculate(Order order) {
        return new BigDecimal("25.00");
    }
}

// Context
public class ShippingCalculator {

    private ShippingStrategy strategy;

    public ShippingCalculator(ShippingStrategy strategy) {
        this.strategy = strategy;
    }

    // Runtime algorithm swapping
    public void setStrategy(ShippingStrategy strategy) {
        this.strategy = strategy;
    }

    public BigDecimal calculate(Order order) {
        return strategy.calculate(order);
    }
}
```

---

### Payment Processor Example (Real-World)

```java
// Strategy interface
public interface PaymentStrategy {
    PaymentResult process(PaymentRequest request);
    String getProviderCode();
}

// Concrete implementations
@Component("STRIPE")
public class StripePaymentStrategy implements PaymentStrategy {
    private final StripeClient stripeClient;

    @Override
    public PaymentResult process(PaymentRequest request) {
        return stripeClient.charge(request.getAmount(), request.getToken());
    }

    @Override
    public String getProviderCode() { return "STRIPE"; }
}

@Component("PAYPAL")
public class PaypalPaymentStrategy implements PaymentStrategy {
    private final PaypalClient paypalClient;

    @Override
    public PaymentResult process(PaymentRequest request) {
        return paypalClient.executePayment(request);
    }

    @Override
    public String getProviderCode() { return "PAYPAL"; }
}

@Component("RAZORPAY")
public class RazorpayPaymentStrategy implements PaymentStrategy {
    // ... implementation
    @Override
    public String getProviderCode() { return "RAZORPAY"; }
}
```

---

### Spring Bean Selection by Type

Spring enables Strategy pattern through its `ApplicationContext`. Two common approaches:

**Approach 1: Map injection by bean name**

```java
@Service
@RequiredArgsConstructor
public class PaymentService {

    // Spring injects ALL PaymentStrategy beans into this map
    // Key = bean name (component value), Value = bean instance
    private final Map<String, PaymentStrategy> strategies;

    public PaymentResult processPayment(PaymentRequest request) {
        String provider = request.getProvider().toUpperCase();
        PaymentStrategy strategy = strategies.get(provider);

        if (strategy == null) {
            throw new UnsupportedPaymentProviderException(provider);
        }
        return strategy.process(request);
    }
}
```

**Approach 2: Interface-driven lookup**

```java
@Service
public class PaymentService {

    private final Map<String, PaymentStrategy> strategyMap;

    // Constructor builds a lookup map from all implementations
    public PaymentService(List<PaymentStrategy> strategies) {
        this.strategyMap = strategies.stream()
            .collect(Collectors.toMap(
                PaymentStrategy::getProviderCode,
                Function.identity()
            ));
    }

    public PaymentResult processPayment(PaymentRequest request) {
        return Optional.ofNullable(strategyMap.get(request.getProvider()))
            .orElseThrow(() -> new UnsupportedPaymentProviderException(request.getProvider()))
            .process(request);
    }
}
```

**Adding a new provider requires zero changes to `PaymentService`** — open for extension, closed for modification.

---

### Runtime Algorithm Swapping with Java Enums

```java
public enum SortStrategy {
    QUICK_SORT {
        @Override
        public <T extends Comparable<T>> void sort(List<T> list) {
            // quicksort implementation
        }
    },
    MERGE_SORT {
        @Override
        public <T extends Comparable<T>> void sort(List<T> list) {
            // mergesort implementation
        }
    },
    TIM_SORT {
        @Override
        public <T extends Comparable<T>> void sort(List<T> list) {
            Collections.sort(list); // Java's TimSort
        }
    };

    public abstract <T extends Comparable<T>> void sort(List<T> list);
}

// Context
public class DataProcessor {
    private SortStrategy sortStrategy = SortStrategy.TIM_SORT; // default

    public void setSortStrategy(SortStrategy strategy) {
        this.sortStrategy = strategy;
    }

    public <T extends Comparable<T>> List<T> process(List<T> data) {
        sortStrategy.sort(data);
        return data;
    }
}
```

---

### Strategy vs Template Method

| Dimension | Strategy | Template Method |
|---|---|---|
| Variation mechanism | Composition (holds a strategy) | Inheritance (override hook methods) |
| Algorithm structure | Completely replaceable | Skeleton fixed, steps vary |
| Runtime swapping | Yes | No (class is fixed at compile time) |
| Coupling | Low (uses interface) | Higher (subclass couples to parent) |
| Java principle | Favor composition over inheritance | Hollywood principle |

---

### Interview Questions

**Q1: How does Strategy differ from State pattern?**

Both involve switching behavior via composition, but the intent differs. In Strategy, the **client** chooses the algorithm explicitly. In State, the **object itself** transitions between states, and behavior changes as a side effect of those transitions.

**Q2: Is a lambda expression a valid Strategy implementation in Java?**

Yes. If the Strategy interface is `@FunctionalInterface` (single abstract method), any lambda satisfies it. `Comparator<T>` is the most famous example — `list.sort((a, b) -> a.getName().compareTo(b.getName()))` is Strategy in action.

**Q3: What happens in Spring if two beans of the same Strategy type exist and are both `@Primary`?**

Spring throws `NoUniqueBeanDefinitionException`. Use `@Qualifier` on the injection point or the map-injection pattern to avoid this.

---

## Topic 11: Template Method Pattern

### Core Concept

The Template Method pattern defines the **skeleton of an algorithm** in a base class, deferring some steps to subclasses. It lets subclasses redefine certain steps of an algorithm without changing the algorithm's structure. This embodies the **Hollywood Principle**: "Don't call us, we'll call you" — the base class calls subclass hooks, not the other way around.

**Key participants:**
- `AbstractClass`: defines `templateMethod()` as `final`; calls abstract/hook methods
- `ConcreteClass`: implements the abstract steps
- Hook methods: non-abstract methods with default implementations that subclasses can optionally override

---

### Algorithm Skeleton Pattern

```java
// Abstract base class with template method
public abstract class DataMigrationJob {

    // THE TEMPLATE METHOD — final prevents subclasses from changing the algorithm
    public final MigrationResult migrate() {
        validate();
        Connection source = connectToSource();
        Connection target = connectToTarget();

        try {
            List<Record> records = extractData(source);
            List<Record> transformed = transformData(records);  // abstract
            int count = loadData(target, transformed);          // abstract

            if (shouldVerify()) {                               // hook — optional override
                verify(source, target, count);
            }
            return MigrationResult.success(count);
        } catch (Exception e) {
            handleError(e);                                     // hook — optional override
            return MigrationResult.failure(e.getMessage());
        } finally {
            cleanup(source, target);                            // hook — optional override
        }
    }

    // Abstract steps — MUST be implemented by subclasses
    protected abstract List<Record> transformData(List<Record> records);
    protected abstract int loadData(Connection target, List<Record> records);

    // Hook methods — CAN be overridden by subclasses
    protected boolean shouldVerify() { return true; }
    protected void handleError(Exception e) { log.error("Migration failed", e); }
    protected void cleanup(Connection source, Connection target) { /* close connections */ }

    // Concrete steps — shared across all subclasses
    private void validate() { /* validate configuration */ }
    private Connection connectToSource() { /* ... */ return null; }
    private Connection connectToTarget() { /* ... */ return null; }
    private void verify(Connection source, Connection target, int count) { /* ... */ }
}

// Concrete implementation
public class UserMigrationJob extends DataMigrationJob {

    @Override
    protected List<Record> transformData(List<Record> records) {
        return records.stream()
            .map(r -> r.withField("email", r.getField("email").toString().toLowerCase()))
            .collect(Collectors.toList());
    }

    @Override
    protected int loadData(Connection target, List<Record> records) {
        // batch insert
        return batchInsert(target, records);
    }

    @Override
    protected boolean shouldVerify() {
        return false; // Skip verification for user migration
    }
}
```

---

### Spring JdbcTemplate

`JdbcTemplate` is one of the most visible implementations of Template Method in the Java ecosystem. It handles the boilerplate (get connection, create statement, handle exceptions, release connection) and lets you provide only the meaningful parts.

```java
@Repository
@RequiredArgsConstructor
public class ProductRepository {

    private final JdbcTemplate jdbcTemplate;

    // Template method: JdbcTemplate handles connection, statement, ResultSet closing
    // You only provide the SQL and the RowMapper (the "hook")
    public List<Product> findByCategory(String category) {
        return jdbcTemplate.query(
            "SELECT id, name, price FROM products WHERE category = ?",
            (rs, rowNum) -> new Product(            // RowMapper = the hook method
                rs.getLong("id"),
                rs.getString("name"),
                rs.getBigDecimal("price")
            ),
            category
        );
    }

    // KeyHolder pattern — another template method variant
    public long insert(Product product) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(
            conn -> {
                PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO products (name, price, category) VALUES (?, ?, ?)",
                    Statement.RETURN_GENERATED_KEYS
                );
                ps.setString(1, product.getName());
                ps.setBigDecimal(2, product.getPrice());
                ps.setString(3, product.getCategory());
                return ps;
            },
            keyHolder
        );
        return keyHolder.getKey().longValue();
    }
}
```

---

### Spring RestTemplate

```java
@Service
@RequiredArgsConstructor
public class ExternalApiClient {

    private final RestTemplate restTemplate;

    // Template method: handles HTTP connection, marshaling, error handling
    // Hook: you provide the URI, method, entity, response type
    public UserProfile fetchUserProfile(String userId) {
        ResponseEntity<UserProfile> response = restTemplate.exchange(
            "https://api.example.com/users/{id}",
            HttpMethod.GET,
            HttpEntity.EMPTY,
            UserProfile.class,
            userId
        );
        return response.getBody();
    }
}
```

> **Note:** `RestTemplate` is in maintenance mode as of Spring 5. `WebClient` (reactive) or `RestClient` (Spring 6.1+) are preferred for new code. The Template Method pattern concept still applies to both.

---

### @Transactional as Template Method

Spring's `@Transactional` is Template Method implemented via AOP proxy:

```
begin transaction          ← template step (fixed)
    try {
        your method body   ← "abstract step" (your code)
    } catch (RuntimeException) {
        rollback           ← template step (fixed)
        throw
    }
    commit                 ← template step (fixed)
```

The transaction management algorithm is fixed. Your business logic is the "hook" that gets called in the middle:

```java
@Service
public class AccountService {

    // The @Transactional proxy wraps this method with the transaction template
    @Transactional(
        isolation = Isolation.READ_COMMITTED,
        propagation = Propagation.REQUIRED,
        rollbackFor = InsufficientFundsException.class
    )
    public void transfer(String fromId, String toId, BigDecimal amount) {
        // This is the "abstract step" — the part YOU provide
        Account from = accountRepository.findById(fromId).orElseThrow();
        Account to = accountRepository.findById(toId).orElseThrow();

        from.debit(amount);    // throws InsufficientFundsException if balance < amount
        to.credit(amount);

        accountRepository.saveAll(List.of(from, to));
    }
}
```

---

### Hollywood Principle

The Hollywood Principle states: **"Don't call us, we'll call you."**

In Template Method, the **base class (framework)** calls the **subclass (application code)** — not the other way around. This inverts the typical control flow:

```
Traditional call flow:          Hollywood / IoC call flow:
  ApplicationCode               Framework
       |                             |
       |---> calls Library           |---> calls ApplicationCode
             (library is passive)         (app code is passive/reactive)
```

This is also the basis of **Inversion of Control (IoC)** and the **Spring container**. When you annotate a bean with `@Component`, Spring calls your code (constructor, `@PostConstruct`) rather than you instantiating the framework.

---

### Interview Questions

**Q1: Why is the template method declared `final`?**

To preserve the algorithm's invariant. If subclasses could override `templateMethod()`, they could skip critical steps (like resource cleanup or security checks). Making it `final` ensures the skeleton is immutable while still allowing customization of individual steps.

**Q2: What is the difference between a hook method and an abstract method in Template Method?**

An **abstract method** must be overridden — it represents a mandatory step the subclass must provide. A **hook method** has a default (often empty or no-op) implementation — subclasses may override it but are not required to. Hooks provide optional extension points.

**Q3: Template Method uses inheritance. What is the risk of this design?**

Inheritance creates tight coupling between the base class and subclasses. Changes to the base class algorithm can break all subclasses. For this reason, Strategy (composition) is often preferred for algorithm variation. Use Template Method when the algorithm structure is truly stable and when the overhead of an extra interface/object is undesirable (e.g., performance-critical loops).

---

## Topic 12: Command Pattern

### Core Concept

The Command pattern encapsulates a **request as an object**, thereby letting you parameterize clients with different requests, queue or log requests, and support undoable operations. It decouples the **sender** (Invoker) from the **receiver** (the object that performs the action).

**Key participants:**
- `Command`: interface with `execute()` (and optionally `undo()`)
- `ConcreteCommand`: binds a Receiver to an action
- `Invoker`: asks Command to carry out the request
- `Receiver`: knows how to perform the operation
- `Client`: creates ConcreteCommand and sets its Receiver

---

### Core Implementation with Undo/Redo

```java
// Command interface
public interface Command {
    void execute();
    void undo();
}

// Receiver
public class TextDocument {
    private final StringBuilder content = new StringBuilder();

    public void insert(int position, String text) {
        content.insert(position, text);
    }

    public void delete(int position, int length) {
        content.delete(position, position + length);
    }

    public String getContent() { return content.toString(); }
}

// Concrete Command — carries all information needed to execute/undo
public class InsertTextCommand implements Command {

    private final TextDocument document;
    private final int position;
    private final String text;

    public InsertTextCommand(TextDocument document, int position, String text) {
        this.document = document;
        this.position = position;
        this.text = text;
    }

    @Override
    public void execute() {
        document.insert(position, text);
    }

    @Override
    public void undo() {
        document.delete(position, text.length());
    }
}

// Invoker — manages undo/redo stacks
public class CommandHistory {

    private final Deque<Command> undoStack = new ArrayDeque<>();
    private final Deque<Command> redoStack = new ArrayDeque<>();

    public void execute(Command command) {
        command.execute();
        undoStack.push(command);
        redoStack.clear(); // New action clears redo history
    }

    public void undo() {
        if (undoStack.isEmpty()) return;
        Command command = undoStack.pop();
        command.undo();
        redoStack.push(command);
    }

    public void redo() {
        if (redoStack.isEmpty()) return;
        Command command = redoStack.pop();
        command.execute();
        undoStack.push(command);
    }
}

// Usage
TextDocument doc = new TextDocument();
CommandHistory history = new CommandHistory();

history.execute(new InsertTextCommand(doc, 0, "Hello"));
history.execute(new InsertTextCommand(doc, 5, " World"));
System.out.println(doc.getContent()); // "Hello World"

history.undo();
System.out.println(doc.getContent()); // "Hello"

history.redo();
System.out.println(doc.getContent()); // "Hello World"
```

---

### Job Queue Implementation

Command pattern is natural for job queues — each Command encapsulates a unit of work:

```java
// Command interface for async jobs
public interface Job {
    void execute();
    String getJobId();
    JobType getType();
}

// Concrete job
public class SendEmailJob implements Job {

    private final String jobId = UUID.randomUUID().toString();
    private final EmailService emailService;
    private final EmailRequest request;

    @Override
    public void execute() {
        emailService.send(request);
    }

    @Override
    public String getJobId() { return jobId; }

    @Override
    public JobType getType() { return JobType.EMAIL; }
}

// Invoker — job queue
@Component
public class JobQueue {

    private final BlockingQueue<Job> queue = new LinkedBlockingQueue<>(1000);
    private final ExecutorService workers = Executors.newFixedThreadPool(
        Runtime.getRuntime().availableProcessors()
    );

    @PostConstruct
    public void startWorkers() {
        int workerCount = Runtime.getRuntime().availableProcessors();
        for (int i = 0; i < workerCount; i++) {
            workers.submit(this::processJobs);
        }
    }

    public void submit(Job job) {
        if (!queue.offer(job)) {
            throw new QueueFullException("Job queue is full");
        }
    }

    private void processJobs() {
        while (!Thread.currentThread().isInterrupted()) {
            try {
                Job job = queue.take();
                job.execute();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            } catch (Exception e) {
                log.error("Job execution failed", e);
            }
        }
    }

    @PreDestroy
    public void shutdown() {
        workers.shutdownNow();
    }
}
```

---

### Spring @Async as Command Pattern

Spring's `@Async` is Command pattern implemented at the framework level. The method invocation is captured as a `Callable`/`Runnable` (the Command) and submitted to an `Executor` (the Invoker):

```java
@Configuration
@EnableAsync
public class AsyncConfig {

    @Bean(name = "taskExecutor")
    public Executor taskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(20);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("async-worker-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return executor;
    }
}

@Service
public class NotificationService {

    // Spring wraps this call as a Command and submits to taskExecutor
    @Async("taskExecutor")
    public CompletableFuture<Void> sendBulkNotifications(List<String> userIds) {
        userIds.forEach(this::sendNotification);
        return CompletableFuture.completedFuture(null);
    }

    // Returns future — caller can track completion
    @Async("taskExecutor")
    public CompletableFuture<NotificationResult> sendWithResult(String userId) {
        NotificationResult result = sendNotification(userId);
        return CompletableFuture.completedFuture(result);
    }
}
```

---

### Transactional Outbox — Command + Persistence

A production-grade pattern combining Command with persistence for reliable async processing:

```java
@Entity
@Table(name = "outbox_events")
public class OutboxEvent {
    @Id
    private String eventId;
    private String aggregateId;
    private String eventType;
    @Column(columnDefinition = "jsonb")
    private String payload;
    private OutboxStatus status;          // PENDING, PROCESSING, PUBLISHED, FAILED
    private LocalDateTime createdAt;
    private int retryCount;
}

@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final OutboxRepository outboxRepository;

    @Transactional  // Both operations in the same transaction — atomicity guaranteed
    public Order placeOrder(PlaceOrderRequest request) {
        Order order = orderRepository.save(Order.from(request));

        // Command persisted as outbox record
        OutboxEvent event = OutboxEvent.builder()
            .eventId(UUID.randomUUID().toString())
            .aggregateId(order.getId())
            .eventType("ORDER_PLACED")
            .payload(serialize(new OrderPlacedEvent(order)))
            .status(OutboxStatus.PENDING)
            .build();

        outboxRepository.save(event);
        return order;
    }
}

// Separate poller publishes pending commands
@Scheduled(fixedDelay = 1000)
@Transactional
public void publishPendingEvents() {
    List<OutboxEvent> pending = outboxRepository.findByStatus(OutboxStatus.PENDING, 100);
    pending.forEach(event -> {
        kafkaTemplate.send(event.getEventType(), event.getAggregateId(), event.getPayload());
        event.setStatus(OutboxStatus.PUBLISHED);
    });
}
```

---

### Interview Questions

**Q1: How does Command pattern enable distributed transaction compensation (Saga)?**

In the Saga pattern, each step is a Command with a corresponding compensating Command (undo). If step 3 fails, the orchestrator executes the compensating commands for steps 2 and 1 in reverse order. This is Command's undo capability applied at the microservices level.

**Q2: What is the difference between Command and Strategy pattern?**

Both encapsulate behavior in objects. The key difference: Strategy encapsulates an algorithm that does something to data and returns a result (interchangeable how). Command encapsulates a request/action that changes state (interchangeable what), optionally with metadata for queuing, logging, and undo.

**Q3: How would you implement idempotent Commands in a job queue?**

Include a unique `commandId` in each Command. Before executing, check a processed-commands store (Redis SET or database table). If the ID exists, skip execution. This prevents duplicate processing in at-least-once delivery systems.

---

## Topic 13: Chain of Responsibility

### Core Concept

The Chain of Responsibility pattern passes a request along a **chain of handlers**. Each handler decides either to process the request or pass it to the next handler in the chain. It decouples senders from receivers by giving multiple objects a chance to handle the request.

**Key participants:**
- `Handler`: defines interface for handling requests; holds reference to next handler
- `ConcreteHandler`: processes requests it is responsible for; forwards others
- `Client`: initiates the request to the first handler in the chain

---

### Core Implementation

```java
// Handler interface
public abstract class RequestHandler {

    private RequestHandler next;

    public RequestHandler setNext(RequestHandler next) {
        this.next = next;
        return next; // Enables fluent chain building
    }

    protected RequestHandler getNext() { return next; }

    public abstract void handle(HttpRequest request, HttpResponse response);

    protected void passToNext(HttpRequest request, HttpResponse response) {
        if (next != null) {
            next.handle(request, response);
        }
    }
}

// Concrete handlers
public class AuthenticationHandler extends RequestHandler {

    private final TokenValidator tokenValidator;

    @Override
    public void handle(HttpRequest request, HttpResponse response) {
        String token = request.getHeader("Authorization");
        if (token == null || !tokenValidator.isValid(token)) {
            response.setStatus(401);
            response.setBody("Unauthorized");
            return; // Absorbs the request — does NOT pass to next
        }
        request.setAttribute("userId", tokenValidator.extractUserId(token));
        passToNext(request, response); // Passes to next handler
    }
}

public class RateLimitHandler extends RequestHandler {

    private final RateLimiter rateLimiter;

    @Override
    public void handle(HttpRequest request, HttpResponse response) {
        String clientIp = request.getRemoteAddr();
        if (!rateLimiter.tryAcquire(clientIp)) {
            response.setStatus(429);
            response.setBody("Too Many Requests");
            return;
        }
        passToNext(request, response);
    }
}

public class LoggingHandler extends RequestHandler {

    @Override
    public void handle(HttpRequest request, HttpResponse response) {
        long start = System.currentTimeMillis();
        passToNext(request, response); // Log wraps next handler
        long duration = System.currentTimeMillis() - start;
        log.info("{} {} -> {} ({}ms)", request.getMethod(), request.getPath(),
            response.getStatus(), duration);
    }
}

// Chain assembly
RequestHandler chain = new LoggingHandler();
chain.setNext(new AuthenticationHandler(tokenValidator))
     .setNext(new RateLimitHandler(rateLimiter))
     .setNext(new BusinessLogicHandler());

chain.handle(request, response);
```

---

### Spring Security FilterChain

Spring Security is Chain of Responsibility at its core. The `SecurityFilterChain` is a list of `Filter` objects through which every request passes:

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            // Each .xxx() call adds a filter to the chain
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .addFilterBefore(
                new JwtAuthenticationFilter(jwtService),
                UsernamePasswordAuthenticationFilter.class
            );
        return http.build();
    }
}

// Custom filter in the chain
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response); // Pass to next
            return;
        }

        try {
            String token = authHeader.substring(7);
            String userId = jwtService.extractUserId(token);

            if (userId != null && SecurityContextHolder.getContext().getAuthentication() == null) {
                UserDetails userDetails = userDetailsService.loadUserByUsername(userId);
                if (jwtService.isValid(token, userDetails)) {
                    UsernamePasswordAuthenticationToken authToken =
                        new UsernamePasswordAuthenticationToken(
                            userDetails, null, userDetails.getAuthorities()
                        );
                    SecurityContextHolder.getContext().setAuthentication(authToken);
                }
            }
        } catch (JwtException e) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            return; // Absorb — do NOT pass to next
        }

        filterChain.doFilter(request, response); // Pass to next
    }
}
```

**Default Spring Security filter order (simplified):**
1. `SecurityContextPersistenceFilter`
2. `UsernamePasswordAuthenticationFilter`
3. `JwtAuthenticationFilter` (custom — placed explicitly)
4. `ExceptionTranslationFilter`
5. `FilterSecurityInterceptor` / `AuthorizationFilter`

---

### Servlet Filter Chain

`javax.servlet.Filter` / `jakarta.servlet.Filter` is the platform-level Chain of Responsibility:

```java
@Component
@Order(1) // Lower = earlier in chain
public class RequestIdFilter implements Filter {

    @Override
    public void doFilter(
            ServletRequest request,
            ServletResponse response,
            FilterChain chain) throws IOException, ServletException {

        HttpServletRequest httpRequest = (HttpServletRequest) request;

        String requestId = Optional
            .ofNullable(httpRequest.getHeader("X-Request-Id"))
            .orElse(UUID.randomUUID().toString());

        // Enrich request
        MDC.put("requestId", requestId);
        ((HttpServletResponse) response).setHeader("X-Request-Id", requestId);

        try {
            chain.doFilter(request, response); // Always pass to next
        } finally {
            MDC.remove("requestId"); // Cleanup after the full chain executes
        }
    }
}
```

---

### Middleware Pipeline (Functional Style)

Modern Spring applications can compose middleware as functions:

```java
// Functional handler type
@FunctionalInterface
public interface Middleware<T, R> {
    R process(T request, Function<T, R> next);
}

// Pipeline builder
public class Pipeline<T, R> {

    private final List<Middleware<T, R>> middlewares = new ArrayList<>();

    public Pipeline<T, R> use(Middleware<T, R> middleware) {
        middlewares.add(middleware);
        return this;
    }

    public Function<T, R> build(Function<T, R> terminal) {
        Function<T, R> chain = terminal;
        // Build from right to left so first middleware executes first
        for (int i = middlewares.size() - 1; i >= 0; i--) {
            Middleware<T, R> middleware = middlewares.get(i);
            Function<T, R> next = chain;
            chain = request -> middleware.process(request, next);
        }
        return chain;
    }
}

// Usage
Function<OrderRequest, OrderResponse> pipeline = new Pipeline<OrderRequest, OrderResponse>()
    .use((req, next) -> {
        log.info("Processing order: {}", req.getOrderId());
        OrderResponse resp = next.apply(req);
        log.info("Completed order: {}", req.getOrderId());
        return resp;
    })
    .use((req, next) -> {
        validate(req);
        return next.apply(req);
    })
    .use((req, next) -> {
        enrichWithCustomerData(req);
        return next.apply(req);
    })
    .build(req -> orderService.process(req));
```

---

### Interview Questions

**Q1: What is the difference between Chain of Responsibility and Decorator?**

Both wrap behavior, but the intent differs. In Decorator, **every** decorator in the chain executes (all wrappers add behavior). In Chain of Responsibility, a handler **may absorb** the request and stop propagation — not all handlers necessarily execute. Decorator is additive; CoR is selective.

**Q2: What are the risks of long filter chains in production?**

Latency: each filter adds processing time, amplified under high load. Debugging: tracing which filter caused an issue requires careful logging. Order sensitivity: filters may depend on state set by previous filters. Mitigation: instrument each filter with timing metrics, enforce strict filter ordering, and keep filters stateless.

**Q3: How does Spring's `@Order` annotation affect filter chains?**

`@Order(n)` sets the execution priority. Lower values execute earlier. If two filters have the same order value, Spring falls back to bean name alphabetical ordering. For Security filters specifically, use `SecurityFilterChain.addFilterBefore/After` rather than `@Order` because Security manages its own internal ordering.

---

## Topic 14: State Pattern

![State Design Pattern UML](https://upload.wikimedia.org/wikipedia/commons/e/e8/State_Design_Pattern_UML_Class_Diagram.svg)
*State — allows object to alter behavior when internal state changes; appears to change its class*

### Core Concept

The State pattern allows an object to **alter its behavior when its internal state changes**. The object appears to change its class. It implements a **Finite State Machine (FSM)** in an object-oriented way by encapsulating each state as a separate class.

**Key participants:**
- `Context`: maintains a reference to the current State; delegates state-specific behavior
- `State`: interface defining behavior for each state
- `ConcreteState`: implements behavior for a specific state; handles transitions

---

### Finite State Machine — Order State Machine Example

```
                      ┌─────────────────────────────────┐
                      │                                 │
    [place()]         │  [pay()]         [ship()]       │  [deliver()]
DRAFT ──────► PENDING ──────► PAID ──────────► SHIPPED ──────────► DELIVERED
                 │                                                       
                 │ [cancel()]                                            
                 ▼                                                       
             CANCELLED                                                   
```

```java
// State interface
public interface OrderState {
    void pay(OrderContext context);
    void ship(OrderContext context);
    void deliver(OrderContext context);
    void cancel(OrderContext context);
    String getStateName();
}

// Context
public class OrderContext {

    private OrderState currentState;
    private final String orderId;
    private final List<OrderStateTransition> history = new ArrayList<>();

    public OrderContext(String orderId) {
        this.orderId = orderId;
        this.currentState = new PendingState();  // Initial state
    }

    void transitionTo(OrderState newState) {
        history.add(new OrderStateTransition(
            currentState.getStateName(),
            newState.getStateName(),
            LocalDateTime.now()
        ));
        log.info("Order {} transitioning: {} -> {}", orderId,
            currentState.getStateName(), newState.getStateName());
        this.currentState = newState;
    }

    // Delegate to current state
    public void pay()     { currentState.pay(this); }
    public void ship()    { currentState.ship(this); }
    public void deliver() { currentState.deliver(this); }
    public void cancel()  { currentState.cancel(this); }

    public String getCurrentState() { return currentState.getStateName(); }
}

// Concrete states
public class PendingState implements OrderState {

    @Override
    public void pay(OrderContext context) {
        // Valid transition
        context.transitionTo(new PaidState());
    }

    @Override
    public void ship(OrderContext context) {
        throw new InvalidStateTransitionException("Cannot ship an unpaid order");
    }

    @Override
    public void deliver(OrderContext context) {
        throw new InvalidStateTransitionException("Cannot deliver an unshipped order");
    }

    @Override
    public void cancel(OrderContext context) {
        context.transitionTo(new CancelledState());
    }

    @Override
    public String getStateName() { return "PENDING"; }
}

public class PaidState implements OrderState {

    @Override
    public void pay(OrderContext context) {
        throw new InvalidStateTransitionException("Order is already paid");
    }

    @Override
    public void ship(OrderContext context) {
        context.transitionTo(new ShippedState());
    }

    @Override
    public void deliver(OrderContext context) {
        throw new InvalidStateTransitionException("Cannot deliver an unshipped order");
    }

    @Override
    public void cancel(OrderContext context) {
        // Paid orders can be cancelled (triggers refund logic)
        initiateRefund(context);
        context.transitionTo(new CancelledState());
    }

    @Override
    public String getStateName() { return "PAID"; }

    private void initiateRefund(OrderContext context) {
        log.info("Initiating refund for order {}", context.getOrderId());
    }
}

public class ShippedState implements OrderState {

    @Override
    public void pay(OrderContext context) {
        throw new InvalidStateTransitionException("Order is already paid");
    }

    @Override
    public void ship(OrderContext context) {
        throw new InvalidStateTransitionException("Order is already shipped");
    }

    @Override
    public void deliver(OrderContext context) {
        context.transitionTo(new DeliveredState());
    }

    @Override
    public void cancel(OrderContext context) {
        throw new InvalidStateTransitionException("Cannot cancel a shipped order");
    }

    @Override
    public String getStateName() { return "SHIPPED"; }
}

public class DeliveredState implements OrderState {

    @Override
    public void pay(OrderContext context)    { throw new InvalidStateTransitionException("Terminal state"); }
    @Override
    public void ship(OrderContext context)   { throw new InvalidStateTransitionException("Terminal state"); }
    @Override
    public void deliver(OrderContext context){ throw new InvalidStateTransitionException("Already delivered"); }
    @Override
    public void cancel(OrderContext context) { throw new InvalidStateTransitionException("Cannot cancel delivered order"); }

    @Override
    public String getStateName() { return "DELIVERED"; }
}
```

---

### State vs Strategy Pattern

This is a critical interview distinction:

| Dimension | State | Strategy |
|---|---|---|
| **Who changes behavior** | Object transitions itself | Client explicitly sets strategy |
| **Awareness between objects** | States may know about each other (transitions) | Strategies are independent |
| **Intent** | Object behavior changes based on internal state | Algorithm is interchangeable |
| **Number of behaviors** | Fixed set of states with defined transitions | Open-ended set of algorithms |
| **Client involvement** | Client rarely needs to know current state | Client selects the algorithm |
| **Example** | Order FSM, TCP connection, vending machine | Sorting algorithms, payment methods |

**Memory aid:** State is about WHAT you are (identity/lifecycle). Strategy is about HOW you do something (algorithm).

---

### Spring StateMachine

Spring State Machine (`spring-statemachine`) provides a declarative FSM framework:

```java
@Configuration
@EnableStateMachine
public class OrderStateMachineConfig
        extends StateMachineConfigurerAdapter<OrderStatus, OrderEvent> {

    @Override
    public void configure(StateMachineStateConfigurer<OrderStatus, OrderEvent> states)
            throws Exception {
        states
            .withStates()
                .initial(OrderStatus.PENDING)
                .states(EnumSet.allOf(OrderStatus.class))
                .end(OrderStatus.DELIVERED)
                .end(OrderStatus.CANCELLED);
    }

    @Override
    public void configure(StateMachineTransitionConfigurer<OrderStatus, OrderEvent> transitions)
            throws Exception {
        transitions
            .withExternal()
                .source(OrderStatus.PENDING).target(OrderStatus.PAID)
                .event(OrderEvent.PAY_EVENT)
                .action(paymentConfirmationAction())
            .and()
            .withExternal()
                .source(OrderStatus.PAID).target(OrderStatus.SHIPPED)
                .event(OrderEvent.SHIP_EVENT)
            .and()
            .withExternal()
                .source(OrderStatus.SHIPPED).target(OrderStatus.DELIVERED)
                .event(OrderEvent.DELIVER_EVENT)
            .and()
            .withExternal()
                .source(OrderStatus.PENDING).target(OrderStatus.CANCELLED)
                .event(OrderEvent.CANCEL_EVENT)
            .and()
            .withExternal()
                .source(OrderStatus.PAID).target(OrderStatus.CANCELLED)
                .event(OrderEvent.CANCEL_EVENT)
                .action(refundAction());
    }

    @Bean
    public Action<OrderStatus, OrderEvent> paymentConfirmationAction() {
        return context -> {
            String orderId = (String) context.getExtendedState().getVariables().get("orderId");
            log.info("Payment confirmed for order: {}", orderId);
        };
    }
}

// Usage
@Service
@RequiredArgsConstructor
public class OrderWorkflowService {

    private final StateMachine<OrderStatus, OrderEvent> stateMachine;

    public void processPayment(String orderId) {
        stateMachine.getExtendedState().getVariables().put("orderId", orderId);
        boolean accepted = stateMachine.sendEvent(
            MessageBuilder.withPayload(OrderEvent.PAY_EVENT).build()
        );
        if (!accepted) {
            throw new InvalidStateTransitionException(
                "Payment event not accepted in state: " + stateMachine.getState().getId()
            );
        }
    }
}
```

---

### Interview Questions

**Q1: When would you use State pattern vs. a simple switch statement?**

Use State pattern when: the number of states is large (>4), state-specific behavior is complex (not a one-liner), states need to be added/modified frequently (OCP), or invalid transitions must be enforced at the object level. Use a switch statement for simple 2-3 state scenarios where the logic is a few lines and unlikely to change.

**Q2: How do you persist State pattern state in a database?**

Store only the state name (enum/string) in the database. When loading the entity, reconstruct the State object from the stored name. Use a factory or `Enum.valueOf()`. The State objects themselves are stateless (all context lives in the Context object).

**Q3: What are guard conditions in a State Machine?**

Guard conditions are boolean expressions evaluated before a transition. The transition only occurs if the guard returns true. In Spring State Machine, use `.guard(ctx -> ctx.getExtendedState().get("balance", BigDecimal.class).compareTo(orderTotal) >= 0)` to prevent invalid transitions based on business rules.

---

## Topic 15: Composite & Iterator Patterns

![Composite UML class diagram](https://upload.wikimedia.org/wikipedia/commons/6/68/Composite_UML_class_diagram.svg)
*Composite — treats individual objects and compositions uniformly via a common interface*

### Composite Pattern

#### Core Concept

The Composite pattern composes objects into **tree structures** to represent part-whole hierarchies. Composite lets clients treat individual objects (leaves) and compositions of objects (composites) **uniformly** through a common interface.

**Key participants:**
- `Component`: common interface for both leaves and composites
- `Leaf`: has no children; implements leaf behavior
- `Composite`: has children; implements operations by delegating to children
- `Client`: uses Component interface; doesn't need to know if it's dealing with a Leaf or Composite

---

#### Tree Structure Implementation

```java
// Component interface — uniform treatment
public interface FileSystemItem {
    String getName();
    long getSize();
    void print(String indent);
    Optional<FileSystemItem> findByName(String name);  // Recursive search
}

// Leaf
public class File implements FileSystemItem {

    private final String name;
    private final long size;

    public File(String name, long size) {
        this.name = name;
        this.size = size;
    }

    @Override
    public String getName() { return name; }

    @Override
    public long getSize() { return size; }

    @Override
    public void print(String indent) {
        System.out.println(indent + "📄 " + name + " (" + size + " bytes)");
    }

    @Override
    public Optional<FileSystemItem> findByName(String name) {
        return this.name.equals(name) ? Optional.of(this) : Optional.empty();
    }
}

// Composite
public class Directory implements FileSystemItem {

    private final String name;
    private final List<FileSystemItem> children = new ArrayList<>();

    public Directory(String name) { this.name = name; }

    public void add(FileSystemItem item) { children.add(item); }
    public void remove(FileSystemItem item) { children.remove(item); }

    @Override
    public String getName() { return name; }

    @Override
    public long getSize() {
        // Composite delegates to children — recursive
        return children.stream().mapToLong(FileSystemItem::getSize).sum();
    }

    @Override
    public void print(String indent) {
        System.out.println(indent + "📁 " + name + "/");
        children.forEach(child -> child.print(indent + "  "));
    }

    @Override
    public Optional<FileSystemItem> findByName(String targetName) {
        if (this.name.equals(targetName)) return Optional.of(this);
        return children.stream()
            .map(child -> child.findByName(targetName))
            .filter(Optional::isPresent)
            .findFirst()
            .orElse(Optional.empty());
    }
}

// Client — treats File and Directory identically
public class DiskAnalyzer {

    public void analyze(FileSystemItem item) {
        item.print("");
        System.out.printf("Total size: %d bytes%n", item.getSize());
    }
}

// Tree construction
Directory root = new Directory("root");
Directory src = new Directory("src");
Directory test = new Directory("test");

src.add(new File("Main.java", 1024));
src.add(new File("Service.java", 2048));
test.add(new File("MainTest.java", 512));

root.add(src);
root.add(test);
root.add(new File("pom.xml", 256));

new DiskAnalyzer().analyze(root); // Works on the whole tree uniformly
```

---

#### Real-World Composite: Menu/Category Hierarchy

```java
public interface MenuComponent {
    String getName();
    BigDecimal getPrice();
    boolean isCategory();
    void accept(MenuVisitor visitor);
}

public class MenuItem implements MenuComponent {
    private final String name;
    private final BigDecimal price;
    private final boolean vegetarian;

    @Override public boolean isCategory() { return false; }
    @Override public void accept(MenuVisitor visitor) { visitor.visitItem(this); }
    // ... getters
}

public class MenuCategory implements MenuComponent {
    private final String name;
    private final List<MenuComponent> items = new ArrayList<>();

    public void add(MenuComponent component) { items.add(component); }

    @Override
    public BigDecimal getPrice() {
        return items.stream()
            .map(MenuComponent::getPrice)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    @Override public boolean isCategory() { return true; }

    @Override
    public void accept(MenuVisitor visitor) {
        visitor.visitCategory(this);
        items.forEach(item -> item.accept(visitor));
    }
}
```

---

### Iterator Pattern

#### Core Concept

The Iterator pattern provides a way to **sequentially access elements** of a collection without exposing its underlying representation. It separates the traversal algorithm from the collection data structure.

**Java's `Iterator<E>` contract:**

```java
public interface Iterator<E> {
    boolean hasNext();  // Returns true if more elements remain
    E next();           // Returns next element, advances cursor; throws NoSuchElementException if none
    default void remove() {  // Optional: removes last element returned by next()
        throw new UnsupportedOperationException("remove");
    }
    default void forEachRemaining(Consumer<? super E> action) {
        Objects.requireNonNull(action);
        while (hasNext()) action.accept(next());
    }
}

public interface Iterable<T> {
    Iterator<T> iterator();  // Enables for-each loop support
}
```

---

#### Custom Iterator Implementation

```java
// Custom binary tree with in-order iterator
public class BinarySearchTree<T extends Comparable<T>> implements Iterable<T> {

    private Node<T> root;

    private static class Node<T> {
        T value;
        Node<T> left, right;
        Node(T value) { this.value = value; }
    }

    @Override
    public Iterator<T> iterator() {
        return new InOrderIterator();
    }

    // In-order iterator — does NOT expose tree structure
    private class InOrderIterator implements Iterator<T> {

        private final Deque<Node<T>> stack = new ArrayDeque<>();

        public InOrderIterator() {
            pushLeft(root);
        }

        private void pushLeft(Node<T> node) {
            while (node != null) {
                stack.push(node);
                node = node.left;
            }
        }

        @Override
        public boolean hasNext() {
            return !stack.isEmpty();
        }

        @Override
        public T next() {
            if (!hasNext()) throw new NoSuchElementException();
            Node<T> node = stack.pop();
            pushLeft(node.right);
            return node.value;
        }
    }
}

// Client — uses for-each without knowing about tree internals
BinarySearchTree<Integer> bst = new BinarySearchTree<>();
// ... insertions
for (int value : bst) {
    System.out.println(value); // In-order: sorted output
}
```

---

#### Fail-Fast vs Fail-Safe Iterators

This is a frequent Java interview topic:

| Property | Fail-Fast | Fail-Safe |
|---|---|---|
| **Behavior on modification** | Throws `ConcurrentModificationException` | Continues iteration without exception |
| **Works on** | Original collection | Snapshot / copy of collection |
| **`modCount` tracking** | Yes — checked on each `next()` call | No |
| **Memory overhead** | None | Additional copy of collection |
| **Reflects modifications** | Detects concurrent modification | Does NOT reflect modifications made during iteration |
| **Examples** | `ArrayList`, `HashMap`, `HashSet`, `TreeMap` | `CopyOnWriteArrayList`, `ConcurrentHashMap` |
| **When to use** | Single-threaded or read-only iteration | Multi-threaded concurrent access |

```java
// Fail-Fast iterator — ConcurrentModificationException
List<String> list = new ArrayList<>(List.of("a", "b", "c"));
Iterator<String> failFastIter = list.iterator();
list.add("d"); // Structural modification after iterator creation

try {
    while (failFastIter.hasNext()) {
        System.out.println(failFastIter.next()); // Throws ConcurrentModificationException!
    }
} catch (ConcurrentModificationException e) {
    System.out.println("Detected concurrent modification");
}

// Fail-Safe iterator — safe concurrent modification
List<String> cowList = new CopyOnWriteArrayList<>(List.of("a", "b", "c"));
Iterator<String> failSafeIter = cowList.iterator(); // Snapshot taken here
cowList.add("d"); // Modifies the original list; snapshot unchanged

while (failSafeIter.hasNext()) {
    System.out.println(failSafeIter.next()); // Prints: a, b, c (no "d" — snapshot)
}

// Correct way to remove during iteration with fail-fast iterator
Iterator<String> iter = list.iterator();
while (iter.hasNext()) {
    String item = iter.next();
    if (item.startsWith("a")) {
        iter.remove(); // Safe — uses iterator's remove, not collection's
    }
}

// Java 8+ alternative — removeIf (internally uses iterator.remove())
list.removeIf(item -> item.startsWith("a"));
```

---

#### How Fail-Fast Detection Works (Internal)

```java
// Simplified ArrayList internal implementation
public class SimplifiedArrayList<E> implements Iterable<E> {

    private Object[] data;
    private int size;
    private int modCount = 0; // Modification counter — incremented on structural changes

    public boolean add(E element) {
        data[size++] = element;
        modCount++; // Structural modification
        return true;
    }

    public boolean remove(Object o) {
        // ... removal logic
        modCount++; // Structural modification
        return true;
    }

    @Override
    public Iterator<E> iterator() {
        return new Itr();
    }

    private class Itr implements Iterator<E> {

        int cursor = 0;
        int expectedModCount = modCount; // Snapshot of modCount at iterator creation time

        @Override
        public boolean hasNext() {
            return cursor != size;
        }

        @Override
        @SuppressWarnings("unchecked")
        public E next() {
            checkForComodification(); // Check on EVERY call to next()
            return (E) data[cursor++];
        }

        @Override
        public void remove() {
            // ... remove element at cursor - 1
            expectedModCount = modCount; // Resync — safe removal
        }

        private void checkForComodification() {
            if (modCount != expectedModCount) {
                throw new ConcurrentModificationException();
            }
        }
    }
}
```

---

### Composite + Iterator Together

These patterns naturally compose — use Iterator to traverse a Composite tree:

```java
public class DepthFirstIterator implements Iterator<FileSystemItem> {

    private final Deque<FileSystemItem> stack = new ArrayDeque<>();

    public DepthFirstIterator(FileSystemItem root) {
        stack.push(root);
    }

    @Override
    public boolean hasNext() { return !stack.isEmpty(); }

    @Override
    public FileSystemItem next() {
        if (!hasNext()) throw new NoSuchElementException();
        FileSystemItem item = stack.pop();
        if (item instanceof Directory dir) {
            // Push children in reverse order so first child is processed first
            List<FileSystemItem> children = dir.getChildren();
            for (int i = children.size() - 1; i >= 0; i--) {
                stack.push(children.get(i));
            }
        }
        return item;
    }
}

// Client iterates entire tree without knowing it's a tree
FileSystemItem root = buildFileSystem();
Iterator<FileSystemItem> iter = new DepthFirstIterator(root);
while (iter.hasNext()) {
    FileSystemItem item = iter.next();
    if (item instanceof File f && f.getSize() > 1_000_000) {
        System.out.println("Large file: " + f.getName());
    }
}
```

---

### Interview Questions

**Q1: When would you use Composite vs. a flat list?**

Use Composite when the data has a natural tree/hierarchy (file system, organizational chart, UI component tree, menu categories). Use a flat list when relationships are lateral, not hierarchical. Composite shines when the same operation must apply recursively to both individual elements and groups.

**Q2: Can you add type-specific operations to a Composite leaf without breaking the uniform interface?**

Yes — use the **Visitor pattern** alongside Composite. The Component interface declares `accept(Visitor v)`. Each leaf and composite calls the appropriate visitor method. This maintains uniform treatment while allowing type-specific operations without modifying the component classes.

**Q3: What is the difference between `Iterator.remove()` and `Collection.remove()`?**

`Iterator.remove()` removes the element last returned by `next()` from the underlying collection and synchronizes `expectedModCount` — it is safe to call during iteration. `Collection.remove(element)` is a structural modification that increments `modCount` without updating the iterator's `expectedModCount`, causing `ConcurrentModificationException` on the next `hasNext()`/`next()` call.

---

## Master Cheat Sheet

### GoF Patterns Reference Table

| Pattern | Category | Intent | Java/Spring Example |
|---|---|---|---|
| **Singleton** | Creational | Ensure one instance | Spring beans (default scope), `Runtime.getRuntime()` |
| **Factory Method** | Creational | Define creation interface, subclass decides type | `Calendar.getInstance()`, Spring `BeanFactory` |
| **Abstract Factory** | Creational | Create families of related objects | Spring `ApplicationContext`, JDBC `Connection` |
| **Builder** | Creational | Construct complex objects step-by-step | Lombok `@Builder`, `StringBuilder`, `HttpRequest.newBuilder()` |
| **Prototype** | Creational | Create objects by cloning | `Object.clone()`, Spring prototype scope |
| **Adapter** | Structural | Convert interface to another interface | `Arrays.asList()`, `InputStreamReader`, Spring `HandlerAdapter` |
| **Bridge** | Structural | Decouple abstraction from implementation | JDBC Driver API vs. driver implementation |
| **Composite** | Structural | Tree of leaf/composite with uniform interface | File system, UI components, `JTree` |
| **Decorator** | Structural | Add responsibilities dynamically | `BufferedInputStream`, Spring `BeanDefinitionDecorator` |
| **Facade** | Structural | Simplified interface to subsystem | `JdbcTemplate`, `RedisTemplate`, REST API layer |
| **Flyweight** | Structural | Share fine-grained objects efficiently | `Integer.valueOf(-128 to 127)`, String pool |
| **Proxy** | Structural | Control access to another object | Spring AOP `@Transactional`, `@Cacheable`, `@Lazy` |
| **Chain of Responsibility** | Behavioral | Pass request along handler chain | Spring Security FilterChain, Servlet Filter |
| **Command** | Behavioral | Encapsulate request as object | Spring `@Async`, job queues, undo/redo |
| **Interpreter** | Behavioral | Language grammar as object structure | Spring EL (SpEL), SQL parsers |
| **Iterator** | Behavioral | Sequential access without exposing internals | `java.util.Iterator`, Java for-each |
| **Mediator** | Behavioral | Centralize complex communication | Spring `@EventBus`, MVC `DispatcherServlet` |
| **Memento** | Behavioral | Capture/restore object state | Undo history, JPA dirty checking |
| **Observer** | Behavioral | Notify dependents of state changes | Spring `@EventListener`, Kafka consumer groups |
| **State** | Behavioral | Behavior changes with internal state | Order FSM, Spring StateMachine |
| **Strategy** | Behavioral | Interchangeable algorithms | Payment processors, Spring bean map injection |
| **Template Method** | Behavioral | Algorithm skeleton, defer steps | `JdbcTemplate`, `@Transactional`, `RestTemplate` |
| **Visitor** | Behavioral | Operations on elements without modifying | AST traversal, `Files.walkFileTree()` |

---

### Creational vs Structural vs Behavioral Quick Reference

```
CREATIONAL — "How objects are created"
├── Singleton    → One instance, global access point
├── Factory      → Delegate creation to subclass/method
├── Abstract Factory → Family of related objects
├── Builder      → Step-by-step construction
└── Prototype    → Clone existing instances

STRUCTURAL — "How objects are composed"
├── Adapter      → Make incompatible interfaces work together
├── Bridge       → Separate abstraction from implementation
├── Composite    → Tree structures, uniform leaf/composite treatment
├── Decorator    → Add behavior without modifying class
├── Facade       → Simplify complex subsystem
├── Flyweight    → Share objects to reduce memory
└── Proxy        → Control access, add cross-cutting concerns

BEHAVIORAL — "How objects communicate"
├── Observer     → Notify on state change
├── Strategy     → Interchangeable algorithms
├── Template Method → Fixed skeleton, variable steps
├── Command      → Encapsulate requests as objects
├── Chain of Resp → Pass request along handler chain
├── State        → Behavior based on internal state
├── Iterator     → Traverse collection without knowing internals
├── Visitor      → Operations on object structure elements
├── Mediator     → Centralize inter-object communication
├── Memento      → Save/restore object state
└── Interpreter  → Language grammar as objects
```

---

### Pattern Selection Guide: "When you have X problem, use Y pattern"

| Problem / Symptom | Pattern to Use | Why |
|---|---|---|
| Only one instance should exist | **Singleton** | Guarantees single instance with global access |
| Object creation logic is complex | **Factory Method** or **Builder** | Factory: subclass decides type; Builder: complex configuration |
| Need to create families of related objects | **Abstract Factory** | Ensures product families are compatible |
| Incompatible interfaces need to work together | **Adapter** | Wraps one interface to look like another |
| Need to add behavior without modifying class | **Decorator** | Wraps object, adds behavior transparently |
| Simplify a complex API | **Facade** | Single entry point to subsystem |
| Complex if-else based on type | **Strategy** | Each branch becomes a class; inject via map |
| Need undo/redo support | **Command** | Each action captured as object with undo() |
| One-to-many notification | **Observer** | Subject notifies all registered observers |
| Object lifecycle stages with validation | **State** | Each state enforces valid transitions |
| Algorithm with fixed structure, variable steps | **Template Method** | Base class owns structure, subclasses fill in steps |
| Multiple handlers for a request | **Chain of Responsibility** | Handlers form a chain; any can absorb |
| Tree with uniform leaf/composite treatment | **Composite** | Recursive structure with single interface |
| Traverse collection without exposing internals | **Iterator** | Encapsulates traversal algorithm |
| Expensive object creation, similar instances | **Flyweight** | Share intrinsic state, externalize extrinsic |
| Cross-cutting concerns (logging, transactions) | **Proxy** | Intercept method calls transparently |
| Operations on object tree, avoid modifying classes | **Visitor** | Add operations to Composite without touching it |
| Save/restore object state | **Memento** | Snapshot state; restore on undo |

---

### Spring Framework Pattern Usage Table

| Spring Feature | Pattern(s) | Explanation |
|---|---|---|
| `ApplicationContext` | Singleton, Factory, Registry | Manages singleton beans; is a bean factory |
| `@Bean` factory methods | Factory Method | Method creates and returns the bean |
| `@Transactional` | Proxy, Template Method | AOP proxy wraps method; transaction = template algorithm |
| `JdbcTemplate` / `RestTemplate` | Template Method, Facade | Fixed algorithm skeleton; simplifies JDBC/HTTP API |
| `@EventListener` / `ApplicationEventPublisher` | Observer | Publisher notifies all registered listeners |
| `SecurityFilterChain` | Chain of Responsibility | Request passes through ordered filter chain |
| Bean map injection (`Map<String, Strategy>`) | Strategy | Runtime algorithm selection from registered beans |
| `@Async` with `TaskExecutor` | Command | Method invocation captured as runnable and queued |
| `@Cacheable` / `@CacheEvict` | Proxy, Decorator | AOP proxy intercepts method, checks/updates cache |
| `@Lazy` beans | Proxy | Returns proxy; real bean created on first access |
| Spring Data `Repository` | Proxy | Interface generates implementation at runtime |
| `BeanDefinitionDecorator` | Decorator | Adds behavior to bean definitions |
| `WebClient` / `RestClient` | Builder, Facade | Fluent builder API; simplifies HTTP client usage |
| Spring StateMachine | State | Declarative FSM with states, events, transitions |
| `@Scope("prototype")` | Prototype | New instance cloned/created per injection point |
| `FactoryBean<T>` | Factory Method | Custom bean creation logic |
| `BeanPostProcessor` | Decorator | Post-processes beans after creation |
| `HandlerInterceptor` | Chain of Responsibility | Pre/post processing for handler execution |
| `@ConditionalOnProperty` | Strategy | Selects bean based on configuration condition |

---

### Anti-Pattern Warning Table

| Anti-Pattern | Correct Pattern | Why |
|---|---|---|
| Giant if-else on type/string | Strategy | OCP violation; hard to extend |
| God object with all state logic | State | Each state should own its behavior |
| Notification via polling | Observer | Pull wastes CPU; push is event-driven |
| Copy-paste algorithm variants | Template Method | Extract common skeleton to base class |
| Long procedural pipeline method | Chain of Responsibility | Each step should be independently testable |
| Mutable Singleton | Immutable Singleton or Spring-managed bean | Concurrent modification = data corruption |
| Deeply nested Composite without Iterator | Iterator over Composite | Separates traversal concern |
| `instanceof` chains on Composite | Visitor | Avoids modifying Composite classes |

---

### Interview Scoring Guide — What Distinguishes SDE2 from SDE3

| SDE2 Expectation | SDE3 / Senior Expectation |
|---|---|
| Knows GoF names and basic intent | Can identify patterns in existing codebases |
| Can implement from scratch | Can evaluate trade-offs (when NOT to use a pattern) |
| Knows Spring uses Proxy for AOP | Can explain how `@Transactional` proxy is created (CGLIB vs JDK proxy) |
| Knows Observer = pub-sub | Can distinguish in-process Observer vs Kafka vs Spring events; knows `@TransactionalEventListener` pitfalls |
| Can write Strategy with if-else replacement | Can design extensible Spring bean map injection; knows `@Primary` vs `@Qualifier` |
| Knows fail-fast vs fail-safe | Can explain `modCount` internal mechanism and when `ConcurrentHashMap` iterator is safe |
| Knows State = FSM | Can design production-grade state machine with persistence, guard conditions, and Spring StateMachine |
| Writes working Command with undo | Can design transactional outbox pattern combining Command + persistence |

---

*End of Chapter 19, Part B — Behavioral Patterns*

*Continue to Chapter 20: Microservices Design Patterns (Saga, CQRS, Event Sourcing)*





