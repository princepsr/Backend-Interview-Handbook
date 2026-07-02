# Volume 5: System Design & LLD
# Chapter 20: SOLID Principles & Clean Architecture

---

# Chapter 20 — SOLID Principles & Clean Architecture (Part A)

> **Target Audience:** SDE2 / Senior Engineer | **Stack:** Java 17, Spring Boot 3.x  
> **Interview Frequency:** ★★★★★ (FAANG+, MANGA, top product companies)

---

### Topic 1: Single Responsibility Principle (SRP)

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Google, Amazon, Microsoft, Uber, Flipkart

**Q:** What is the Single Responsibility Principle, how do you identify violations, and how does it apply to microservices decomposition?

**Short Answer:**  
SRP states that a class should have only one reason to change — meaning it should encapsulate a single cohesive responsibility. A "God class" that handles persistence, business logic, and HTTP serialization all at once violates SRP because changes to any one concern force recompilation and retesting of unrelated code. In microservices, SRP maps naturally to service decomposition: each service owns one bounded business capability.

**Deep Explanation:**  
Robert C. Martin defined SRP as "a class should have one, and only one, reason to change." The word *reason* refers to an *actor* — a stakeholder or system whose requirements drive change. If the same class must change when the UI team changes the response format AND when the DBA changes the schema AND when the business team changes pricing logic, it has three reasons to change and therefore violates SRP.

**Identifying SRP violations:**
- The class name contains "And", "Manager", "Util", "Helper", or "Service" doing 10 things
- The class has more than 200-300 lines in most codebases
- The class imports from persistence, HTTP, scheduling, and email in the same file
- Unit testing requires mocking 5+ collaborators
- Changes to unrelated features frequently cause you to touch this class

**God Class anti-pattern:** A single `UserService` that: validates input, hashes passwords, persists to DB, sends welcome emails, generates JWT tokens, logs audit trails, and publishes Kafka events — every team in the company has a reason to modify it.

**Microservices SRP:** Each microservice should own one business capability (Order Service, Inventory Service, Payment Service). If your Payment Service also manages user profiles "for convenience," you have a distributed God class.

**Real-World Example:**  
At a fintech startup, a `TransactionService` grew to 2,000 lines handling: fraud detection, ledger updates, notification dispatch, PDF receipt generation, and regulatory reporting. When the compliance team mandated a new reporting format, developers had to touch code adjacent to fraud detection logic — a regression caused a production incident. The fix: extract `FraudDetectionService`, `LedgerService`, `NotificationService`, `ReceiptService`, `RegulatoryReportingService`.

**Code Example:**
```java
// ============================================================
// BAD: God class violating SRP — multiple reasons to change
// ============================================================
@Service
public class UserService {

    @Autowired private UserRepository userRepository;
    @Autowired private JavaMailSender mailSender;
    @Autowired private JwtUtil jwtUtil;
    @Autowired private PasswordEncoder passwordEncoder;
    @Autowired private KafkaTemplate<String, String> kafkaTemplate;

    // Reason 1: Business logic changes
    public void registerUser(String email, String password) {
        if (!email.contains("@")) throw new IllegalArgumentException("Bad email");

        // Reason 2: Persistence schema changes
        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(password));
        userRepository.save(user);

        // Reason 3: Email template changes
        SimpleMailMessage msg = new SimpleMailMessage();
        msg.setTo(email);
        msg.setSubject("Welcome!");
        msg.setText("Thanks for registering.");
        mailSender.send(msg);

        // Reason 4: JWT strategy changes
        String token = jwtUtil.generate(email);
        System.out.println("Token: " + token);

        // Reason 5: Kafka topic/schema changes
        kafkaTemplate.send("user-events", "USER_REGISTERED:" + email);
    }
}

// ============================================================
// GOOD: Each class has exactly one reason to change
// ============================================================

// Responsibility 1: User registration business logic only
@Service
@RequiredArgsConstructor
public class UserRegistrationService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final UserValidator userValidator;
    private final ApplicationEventPublisher eventPublisher;

    public User register(RegisterUserCommand cmd) {
        userValidator.validate(cmd);  // delegates validation
        User user = User.create(cmd.email(), passwordEncoder.encode(cmd.password()));
        userRepository.save(user);
        eventPublisher.publishEvent(new UserRegisteredEvent(user.getId(), user.getEmail()));
        return user;
    }
}

// Responsibility 2: Email notifications — only changes when email strategy changes
@Component
@RequiredArgsConstructor
public class UserWelcomeEmailHandler implements ApplicationListener<UserRegisteredEvent> {

    private final JavaMailSender mailSender;
    private final EmailTemplateRenderer templateRenderer;

    @Override
    public void onApplicationEvent(UserRegisteredEvent event) {
        String body = templateRenderer.render("welcome", Map.of("email", event.email()));
        SimpleMailMessage msg = new SimpleMailMessage();
        msg.setTo(event.email());
        msg.setSubject("Welcome!");
        msg.setText(body);
        mailSender.send(msg);
    }
}

// Responsibility 3: Kafka publishing — only changes when event schema changes
@Component
@RequiredArgsConstructor
public class UserEventPublisher implements ApplicationListener<UserRegisteredEvent> {

    private final KafkaTemplate<String, UserEvent> kafkaTemplate;

    @Override
    public void onApplicationEvent(UserRegisteredEvent event) {
        kafkaTemplate.send("user-events", new UserEvent("USER_REGISTERED", event.userId()));
    }
}
```

**Follow-up Questions:**
1. How does SRP differ from cohesion? Are they the same concept? (SRP is about actors/reasons to change; cohesion is about how strongly related the elements of a module are — related but distinct)
2. Can SRP be over-applied? What happens when you split too aggressively? (Yes — nano-classes with single methods lead to indirection explosion; balance with cohesion)
3. How do you apply SRP at the package/module level in a large Java monolith?

**Common Mistakes:**
- Confusing SRP with "a class should do only one thing" — the precise definition is one *reason to change* (actor), not one operation
- Splitting classes so finely that every method becomes its own class — this violates cohesion and creates anemic domain models
- Applying SRP only to classes but ignoring methods, packages, and microservices

**Interview Traps:**
- Interviewer asks "is a 500-line class always a SRP violation?" — No. A complex domain object with many coherent behaviors can be large; size alone doesn't determine SRP violation
- "How would you refactor a God class in a live production system?" — expect an answer about strangler fig pattern, gradual extraction, not a big-bang rewrite

**Quick Revision:** SRP = one actor, one reason to change; God classes accumulate responsibilities; use domain events to decouple side effects.

---

### Topic 2: Open/Closed Principle (OCP)

**Difficulty:** Medium-Hard | **Frequency:** High | **Companies:** Amazon, Netflix, Atlassian, Stripe, Shopify

**Q:** What is the Open/Closed Principle and how do you achieve it in Java without modifying existing code when adding new behavior?

**Short Answer:**  
OCP states that software entities should be open for extension but closed for modification — you should be able to add new behavior without changing existing, tested code. The primary mechanism is polymorphism: define abstractions (interfaces/abstract classes) so new implementations can be plugged in. In Spring Boot, this manifests as Strategy beans, `@Conditional` configurations, and plugin architectures.

**Deep Explanation:**  
Bertrand Meyer coined OCP; Martin later reframed it in terms of polymorphic OCP. The core insight: every time you open a stable class to add a feature, you risk breaking existing behavior and invalidating existing tests.

**Achieving OCP:**
1. **Strategy Pattern** — extract the varying behavior into an interface; add new strategies without modifying the context
2. **Template Method** — define the algorithm skeleton in a base class; subclasses override steps
3. **Decorator Pattern** — wrap objects to add behavior without modifying the wrapped class
4. **Spring @Conditional** — add new beans/configurations conditionally without changing existing config classes
5. **Plugin architecture** — use `ServiceLoader` or Spring's component scanning to discover implementations

**When is a switch/if-else an OCP violation?** When adding a new *type* requires you to add a new case to an existing switch statement scattered across the codebase. This is the classic "type switch" smell.

**Real-World Example:**  
A payment gateway originally supported only credit cards. Each new payment method (PayPal, UPI, crypto) required modifying the `PaymentProcessor` class, adding an if-else branch, touching fraud-check logic, and re-testing everything. After applying OCP with a `PaymentStrategy` interface, adding a new payment method meant creating a new class and registering it as a Spring bean — zero changes to existing classes.

**Code Example:**
```java
// ============================================================
// BAD: Violates OCP — every new discount type requires
// modifying existing DiscountCalculator
// ============================================================
public class DiscountCalculator {

    public double calculate(Order order, String discountType) {
        // Adding "FLASH_SALE" means opening this class
        return switch (discountType) {
            case "PERCENTAGE" -> order.getTotal() * 0.10;
            case "FIXED"      -> order.getTotal() - 50.0;
            case "BOGO"       -> order.getTotal() * 0.50;
            // Next sprint: add FLASH_SALE, LOYALTY_POINTS, REFERRAL...
            // Every addition touches this class → regression risk
            default -> order.getTotal();
        };
    }
}

// ============================================================
// GOOD: OCP via Strategy pattern + Spring bean registration
// New discount types = new class, zero modification to existing
// ============================================================

// Closed abstraction — never changes
public interface DiscountStrategy {
    boolean supports(String discountType);
    double apply(Order order);
}

// Extension point 1 — closed after implementation
@Component
public class PercentageDiscountStrategy implements DiscountStrategy {
    @Override
    public boolean supports(String type) { return "PERCENTAGE".equals(type); }
    @Override
    public double apply(Order order) { return order.getTotal() * 0.10; }
}

@Component
public class FixedDiscountStrategy implements DiscountStrategy {
    @Override
    public boolean supports(String type) { return "FIXED".equals(type); }
    @Override
    public double apply(Order order) { return Math.max(0, order.getTotal() - 50.0); }
}

// Extension point 2: add FlashSaleDiscountStrategy — no existing class touched
@Component
public class FlashSaleDiscountStrategy implements DiscountStrategy {
    @Override
    public boolean supports(String type) { return "FLASH_SALE".equals(type); }
    @Override
    public double apply(Order order) { return order.getTotal() * 0.30; }
}

// Context — closed for modification, open for extension via Spring injection
@Service
@RequiredArgsConstructor
public class DiscountCalculator {

    // Spring auto-collects ALL DiscountStrategy beans — new strategies auto-register
    private final List<DiscountStrategy> strategies;

    public double calculate(Order order, String discountType) {
        return strategies.stream()
            .filter(s -> s.supports(discountType))
            .findFirst()
            .map(s -> s.apply(order))
            .orElse(order.getTotal());
    }
}

// ============================================================
// Spring @Conditional as OCP — different implementations
// loaded based on environment without modifying config class
// ============================================================
@Configuration
public class StorageConfig {

    @Bean
    @ConditionalOnProperty(name = "storage.type", havingValue = "s3")
    public StorageService s3Storage(S3Client s3Client) {
        return new S3StorageService(s3Client);
    }

    @Bean
    @ConditionalOnProperty(name = "storage.type", havingValue = "gcs")
    public StorageService gcsStorage(Storage gcsClient) {
        return new GCSStorageService(gcsClient);
    }

    // Adding Azure storage = new @Bean method, no existing beans modified
    @Bean
    @ConditionalOnProperty(name = "storage.type", havingValue = "azure")
    public StorageService azureStorage(BlobServiceClient blobClient) {
        return new AzureStorageService(blobClient);
    }
}
```

**Follow-up Questions:**
1. Can you perfectly adhere to OCP? What's the practical limit? (No — you must predict the right extension points; wrong abstractions cause worse rigidity)
2. How does the Decorator pattern achieve OCP differently from Strategy? (Decorator adds behavior to existing objects at runtime via wrapping; Strategy swaps the algorithm)
3. What's the relationship between OCP and Feature Flags?

**Common Mistakes:**
- Creating an interface for every class "just in case" — YAGNI applies; extract the abstraction when you have two concrete implementations
- Confusing "closed for modification" with "immutable" — it means don't change the public contract and tested behavior, not that the source is locked
- Using inheritance instead of composition for OCP — inheritance creates tight coupling; prefer composition via Strategy/Decorator

**Interview Traps:**
- "Does OCP mean you should never modify existing code?" — No, it means stable, tested modules shouldn't require modification to add new features; refactoring and bug fixing are valid modifications
- "How do you design the extension point before knowing what extensions will come?" — this is the hardest part; use domain knowledge and defer abstraction until you see the second concrete case (Rule of Three)

**Quick Revision:** OCP = open for extension, closed for modification; achieve via Strategy pattern, Spring bean lists, and @Conditional — never via switch/if-else on type.

---

### Topic 3: Liskov Substitution Principle (LSP)

**Difficulty:** Hard | **Frequency:** Medium-High | **Companies:** Google, Jane Street, Goldman Sachs, Two Sigma, Palantir

**Q:** What is the Liskov Substitution Principle, what is the classic Square-Rectangle violation, and how do Java generics wildcards relate to LSP?

**Short Answer:**  
LSP states that objects of a subtype must be substitutable for objects of their supertype without altering program correctness — meaning a subclass must honor the behavioral contract (preconditions, postconditions, invariants) of its parent. The Square-extends-Rectangle example shows how a geometrically intuitive hierarchy can break client code because Square's `setWidth` must also set height, violating Rectangle's established contract. Java generics wildcards (`? extends T` / `? super T`) encode covariance and contravariance constraints that prevent LSP violations at the type system level.

**Deep Explanation:**  
Barbara Liskov (1987): "If S is a subtype of T, then objects of type T may be replaced with objects of type S without altering any of the desirable properties of the program."

**LSP requires subclasses to:**
- Not strengthen preconditions (accept at least what the parent accepts)
- Not weaken postconditions (guarantee at least what the parent guarantees)
- Preserve invariants established by the parent
- Not throw new checked exceptions not declared by the parent

**Contract-based programming (Design by Contract):**
- **Precondition:** what must be true before a method is called
- **Postcondition:** what must be true after a method returns
- **Invariant:** what must always be true about an object's state

**Java generics and LSP (variance):**
- `List<Dog>` is NOT a subtype of `List<Animal>` (invariant) — this prevents heap pollution
- `List<? extends Animal>` — covariant, read-only (producer), honors LSP for reads
- `List<? super Dog>` — contravariant, write-only (consumer), honors LSP for writes
- PECS: Producer Extends, Consumer Super

**Real-World Example:**  
A `ReadOnlyList` that extends `ArrayList` and throws `UnsupportedOperationException` from `add()` violates LSP — any code accepting an `ArrayList` and calling `add()` will fail at runtime with the subtype. Java's `Collections.unmodifiableList` wisely wraps rather than extends, and `List` interface callers should handle `UnsupportedOperationException` — but most don't. This is why `java.util.Stack` extending `Vector` is considered a design mistake in the JDK.

**Code Example:**
```java
// ============================================================
// BAD: Classic Square extends Rectangle — LSP violation
// ============================================================
public class Rectangle {
    protected int width;
    protected int height;

    public void setWidth(int w)  { this.width = w; }
    public void setHeight(int h) { this.height = h; }
    public int area() { return width * height; }
}

public class Square extends Rectangle {
    // Must keep width == height — but this breaks Rectangle's contract
    @Override
    public void setWidth(int w)  { this.width = w; this.height = w; }  // side-effect!
    @Override
    public void setHeight(int h) { this.width = h; this.height = h; }  // side-effect!
}

// Client code that works for Rectangle but BREAKS with Square
public class GeometryClient {
    public void resizeToDoubleWidth(Rectangle r) {
        int originalHeight = r.height;         // save height
        r.setWidth(r.width * 2);               // change only width
        // Rectangle: area = 2w * h  ✓
        // Square:    area = (2w) * (2w) ✗ — height was also changed!
        assert r.area() == r.width * originalHeight : "LSP violated!";
    }
}

// ============================================================
// GOOD: Separate hierarchy — no forced is-a relationship
// ============================================================
public interface Shape {
    int area();
}

// Immutable value objects — no setters, no contract violation possible
public record Rectangle(int width, int height) implements Shape {
    public Rectangle {
        if (width <= 0 || height <= 0) throw new IllegalArgumentException("Dimensions must be positive");
    }
    @Override public int area() { return width * height; }

    // Returns a NEW rectangle — no mutation contract issues
    public Rectangle withWidth(int newWidth) { return new Rectangle(newWidth, this.height); }
}

public record Square(int side) implements Shape {
    public Square {
        if (side <= 0) throw new IllegalArgumentException("Side must be positive");
    }
    @Override public int area() { return side * side; }
}

// ============================================================
// Java Generics and LSP — PECS in action
// ============================================================
public class AnimalShelter {

    // Producer Extends: read animals from source, covariant
    // List<Dog> can be passed here — safe because we only read
    public static double totalWeight(List<? extends Animal> animals) {
        return animals.stream().mapToDouble(Animal::weight).sum();
    }

    // Consumer Super: add dogs to dest, contravariant
    // List<Animal> can be passed here — safe because we only write Dogs
    public static void addRescuedDogs(List<? super Dog> shelter, List<Dog> rescued) {
        shelter.addAll(rescued);
    }

    // LSP-correct: Subtype (List<Dog>) substitutable for reading
    public static void demo() {
        List<Dog> dogs = List.of(new Dog("Rex", 30.0), new Dog("Buddy", 25.0));
        double total = totalWeight(dogs);  // List<Dog> substituted for List<? extends Animal> ✓

        List<Animal> allAnimals = new ArrayList<>();
        addRescuedDogs(allAnimals, new ArrayList<>(dogs)); // List<Animal> accepted as consumer ✓
    }
}

// ============================================================
// Contract-based LSP: using Java assertions / preconditions
// ============================================================
public abstract class BankAccount {
    protected BigDecimal balance;

    // Postcondition: balance must decrease by exactly amount
    public void withdraw(BigDecimal amount) {
        if (amount.compareTo(BigDecimal.ZERO) <= 0)
            throw new IllegalArgumentException("Amount must be positive");  // precondition
        BigDecimal before = balance;
        doWithdraw(amount);
        // Invariant check: balance must have decreased by exactly amount
        assert balance.equals(before.subtract(amount)) : "Postcondition violated";
    }

    protected abstract void doWithdraw(BigDecimal amount);
}

public class SavingsAccount extends BankAccount {
    @Override
    protected void doWithdraw(BigDecimal amount) {
        if (balance.subtract(amount).compareTo(BigDecimal.ZERO) < 0)
            throw new InsufficientFundsException("Cannot overdraft savings account");
        balance = balance.subtract(amount);
        // Postcondition honored: balance decreased by exactly amount ✓
    }
}
```

**Follow-up Questions:**
1. How does LSP relate to covariant return types and contravariant parameter types in Java method overriding?
2. Why is `java.util.Stack` extending `Vector` considered an LSP violation?
3. How do you enforce LSP in code reviews when inheritance hierarchies grow over time?

**Common Mistakes:**
- Thinking LSP is just about runtime substitution; it's about *behavioral* contract preservation, not just compile-time type compatibility
- Solving Square-Rectangle by making both methods no-ops in Square — this violates postconditions, not just preconditions
- Confusing LSP with polymorphism — LSP is the *contract* constraint on polymorphism

**Interview Traps:**
- "Is `ArrayList` a valid subtype of `List`?" — Yes, perfectly; all contracts honored
- "Does throwing `UnsupportedOperationException` from an inherited method violate LSP?" — Yes if the parent's contract doesn't declare it as a possibility; the `Collections.unmodifiableList` approach violates LSP for the `add()` contract
- Follow-up: "Then why does Java's standard library have this violation?" — historical baggage; the lesson is don't use inheritance to restrict behavior

**Quick Revision:** LSP = subtypes must honor parent's behavioral contract (pre/post conditions + invariants); Square-Rectangle is the canonical violation; Java generics use wildcards to encode variance safely.

---

### Topic 4: Interface Segregation Principle (ISP)

**Difficulty:** Medium | **Frequency:** Medium-High | **Companies:** Amazon, Microsoft, Adobe, Salesforce, VMware

**Q:** What is the Interface Segregation Principle, what is a fat interface, and how does Spring exemplify ISP through its interface hierarchy?

**Short Answer:**  
ISP states that no client should be forced to depend on methods it does not use — prefer many small, role-specific interfaces over one large general-purpose interface. Fat interfaces force implementing classes to stub out irrelevant methods (often with `UnsupportedOperationException` or empty bodies), which is a design smell. Spring's own API demonstrates ISP excellently: `BeanFactory`, `ApplicationContext`, `ConfigurableApplicationContext`, and `WebApplicationContext` form a hierarchy of increasingly rich, role-specific contracts.

**Deep Explanation:**  
ISP is the interface-level application of SRP. Where SRP asks "does this class have one reason to change?", ISP asks "does this interface's client use all of its methods?"

**Fat interface symptoms:**
- Implementing classes stub methods with `throw new UnsupportedOperationException()`
- Large interfaces (10+ methods) with unrelated method clusters
- Clients import an interface but only call 2 of its 15 methods
- Mock objects in tests require stubbing 10 methods to test 1 behavior

**Role interfaces:** Small interfaces that represent a specific capability or role an object can play. An object can implement multiple role interfaces (composition over a single fat interface).

**Java marker interfaces:** `Serializable`, `Cloneable`, `RandomAccess` — zero-method interfaces that communicate a capability to the JVM or framework. ISP-compliant because implementing classes don't have to provide any method — they just declare the capability.

**Spring's ISP hierarchy:**
```
BeanFactory (basic bean lookup)
  └── HierarchicalBeanFactory (parent context support)
        └── ListableBeanFactory (listing beans)
              └── ApplicationContext (adds events, i18n, resources)
                    └── ConfigurableApplicationContext (adds lifecycle management)
                          └── WebApplicationContext (adds servlet context)
```
Each layer adds only what specific clients need. A library that just needs bean lookup depends on `BeanFactory`; web code depends on `WebApplicationContext`.

**Real-World Example:**  
A `DocumentProcessor` interface with `read()`, `write()`, `print()`, `fax()`, `scan()`, and `ocr()` forces every implementing class to handle all operations. A `PDFRenderer` that only reads and renders is forced to implement `fax()` by throwing `UnsupportedOperationException`. The fix: `Readable`, `Writable`, `Printable`, `Faxable`, `Scannable` role interfaces — `PDFRenderer implements Readable, Printable`.

**Code Example:**
```java
// ============================================================
// BAD: Fat interface — forces all implementors to handle
// every operation even if irrelevant to their role
// ============================================================
public interface WorkerInterface {
    void work();
    void eat();
    void sleep();
    void attendMeeting();
    void writeCodeReview();
    void deployToProduction();
}

// RobotWorker is forced to implement biological functions
public class RobotWorker implements WorkerInterface {
    @Override public void work() { System.out.println("Robot working"); }
    @Override public void eat()  { throw new UnsupportedOperationException("Robots don't eat"); }  // 🚩
    @Override public void sleep() { throw new UnsupportedOperationException("Robots don't sleep"); }  // 🚩
    @Override public void attendMeeting() { System.out.println("Robot attending meeting"); }
    @Override public void writeCodeReview() { throw new UnsupportedOperationException("Not programmed for this"); }
    @Override public void deployToProduction() { System.out.println("Robot deploying"); }
}

// ============================================================
// GOOD: Role interfaces — each interface represents one role
// ============================================================

// Narrow role interfaces
public interface Workable       { void work(); }
public interface Feedable       { void eat();  void sleep(); }
public interface Meetable       { void attendMeeting(); }
public interface CodeReviewer   { void writeCodeReview(); }
public interface Deployable     { void deployToProduction(); }

// Human engineer implements all roles relevant to humans
public class HumanEngineer implements Workable, Feedable, Meetable, CodeReviewer, Deployable {
    @Override public void work()             { System.out.println("Human coding"); }
    @Override public void eat()              { System.out.println("Human eating lunch"); }
    @Override public void sleep()            { System.out.println("Human sleeping 8 hours"); }
    @Override public void attendMeeting()    { System.out.println("Human in standup"); }
    @Override public void writeCodeReview()  { System.out.println("Human reviewing PR"); }
    @Override public void deployToProduction() { System.out.println("Human deploying"); }
}

// Robot only implements roles relevant to robots — no stubs needed
public class RobotEngineer implements Workable, Meetable, Deployable {
    @Override public void work()               { System.out.println("Robot executing tasks"); }
    @Override public void attendMeeting()      { System.out.println("Robot attending as observer"); }
    @Override public void deployToProduction() { System.out.println("Robot CI/CD pipeline"); }
    // No eat(), sleep(), writeCodeReview() — robot doesn't need them ✓
}

// ============================================================
// Spring ISP example — depend on the narrowest interface
// ============================================================
@Service
public class BeanInspector {

    // BAD: Depends on ApplicationContext (heavy) just to list beans
    // private final ApplicationContext context;

    // GOOD: Depend on ListableBeanFactory — the narrowest interface that provides what we need
    private final ListableBeanFactory beanFactory;

    public BeanInspector(ListableBeanFactory beanFactory) {
        this.beanFactory = beanFactory;
    }

    public String[] getAllBeanNames() {
        return beanFactory.getBeanDefinitionNames();  // Only need this method
    }
}

// ============================================================
// Repository segregation — read vs write separation (CQRS-aligned)
// ============================================================
public interface ReadableUserRepository {
    Optional<User> findById(UUID id);
    List<User> findByEmail(String email);
    Page<User> findAll(Pageable pageable);
}

public interface WritableUserRepository {
    User save(User user);
    void deleteById(UUID id);
    void deleteAll(List<UUID> ids);
}

// Full repository for admin services
public interface UserRepository extends ReadableUserRepository, WritableUserRepository {}

// Read-only service — depends only on ReadableUserRepository (ISP)
@Service
@RequiredArgsConstructor
public class UserQueryService {
    private final ReadableUserRepository userRepository;  // Can't accidentally call save() ✓

    public UserDTO findUser(UUID id) {
        return userRepository.findById(id).map(UserDTO::from)
            .orElseThrow(() -> new UserNotFoundException(id));
    }
}
```

**Follow-up Questions:**
1. How does ISP relate to CQRS (Command Query Responsibility Segregation)?
2. When should you combine role interfaces into a composite interface vs keeping them separate?
3. How does ISP apply to REST API design (not just Java interfaces)?

**Common Mistakes:**
- Creating one interface per class just to satisfy ISP — interfaces should represent roles/contracts, not be 1:1 with implementations
- Forgetting ISP applies to abstract classes too, not just Java interfaces
- Over-segregating to the point where every method is its own interface — diminishing returns past a point

**Interview Traps:**
- "Doesn't Java 8's default methods make ISP less relevant?" — Default methods help implement adapters but don't remove the need for segregation; they can bloat interfaces if misused
- "How is ISP different from SRP?" — SRP is about a class having one reason to change (implementation perspective); ISP is about clients not being forced to depend on unused methods (client perspective)

**Quick Revision:** ISP = many small role interfaces over one fat interface; fat interfaces breed `UnsupportedOperationException` stubs; Spring's `BeanFactory`→`ApplicationContext` hierarchy is a textbook ISP example.

---

### Topic 5: Dependency Inversion Principle (DIP)

**Difficulty:** Medium-Hard | **Frequency:** Very High | **Companies:** Google, Amazon, Netflix, Thoughtworks, Pivotal

**Q:** What is the Dependency Inversion Principle, why does field injection violate its spirit, and how does hexagonal architecture embody DIP?

**Short Answer:**  
DIP states that high-level modules should not depend on low-level modules — both should depend on abstractions; and abstractions should not depend on details, details should depend on abstractions. In Spring, constructor injection wires abstractions at object creation time, making dependencies explicit and testable. Field injection with `@Autowired` hides dependencies and makes classes harder to test outside a Spring container, undermining DIP's testability goal. Hexagonal architecture (Ports & Adapters) is the architectural expression of DIP.

**Deep Explanation:**  
DIP has two statements:
1. High-level modules should not depend on low-level modules. Both should depend on abstractions.
2. Abstractions should not depend on details. Details (concrete implementations) should depend on abstractions.

**Why dependency inversion, not just dependency injection?**
DI (the mechanism) enables DIP (the principle). But you can use DI without achieving DIP — e.g., injecting `MySQLUserRepository` (concrete) into `UserService` via constructor is DI but not DIP. DIP requires the injection point to be an abstraction (`UserRepository` interface).

**Constructor vs Field Injection:**

| Aspect | Constructor Injection | Field Injection (`@Autowired`) |
|--------|----------------------|-------------------------------|
| Testability | Plain `new` in tests, no container needed | Requires Spring container or reflection tricks |
| Immutability | Dependencies can be `final` | Cannot be `final` |
| Mandatory deps | Enforced at compile time | Fails at runtime with `NullPointerException` |
| Circular dependency | Spring detects it eagerly | Spring may silently proxy around it |
| DIP compliance | Explicit contract | Implicit, container-managed magic |

**Hexagonal Architecture and DIP:**
- **Domain layer** (high-level) defines Ports (interfaces) — it never depends on frameworks
- **Infrastructure layer** (low-level) implements Adapters — it depends on domain ports
- Spring wires adapters to ports at startup — DIP at architectural scale

**Real-World Example:**  
A `ReportService` directly instantiated `new PDFReportGenerator()` — when the client asked for Excel output, the team had to modify `ReportService`. After applying DIP: `ReportService` depends on `ReportGenerator` interface; `PDFReportGenerator` and `ExcelReportGenerator` implement it; Spring injects the right one based on config. `ReportService` never changed.

**Code Example:**
```java
// ============================================================
// BAD: High-level module depends directly on low-level module
// AND field injection hiding dependencies
// ============================================================
@Service
public class OrderService {

    @Autowired  // 🚩 Field injection — hidden dependency, non-final, untestable without container
    private MySQLOrderRepository orderRepository;  // 🚩 Depends on concrete class

    @Autowired
    private SmtpEmailSender emailSender;  // 🚩 Concrete SMTP implementation

    @Autowired
    private StripePaymentGateway paymentGateway;  // 🚩 Tied to Stripe forever

    public OrderConfirmation placeOrder(PlaceOrderCommand cmd) {
        // Tightly coupled — can't swap email provider, payment gateway, or DB
        PaymentResult payment = paymentGateway.charge(cmd.cardToken(), cmd.amount());
        Order order = Order.from(cmd, payment.transactionId());
        orderRepository.save(order);
        emailSender.sendOrderConfirmation(cmd.email(), order.getId());
        return new OrderConfirmation(order.getId(), payment.transactionId());
    }
}

// ============================================================
// GOOD: Both high-level and low-level depend on abstractions
// Constructor injection makes dependencies explicit + final
// ============================================================

// Domain-level abstractions (Ports in hexagonal terms)
public interface OrderRepository {
    void save(Order order);
    Optional<Order> findById(UUID id);
}

public interface EmailNotificationService {
    void sendOrderConfirmation(String email, UUID orderId);
}

public interface PaymentGateway {
    PaymentResult charge(String token, Money amount);
    void refund(String transactionId);
}

// High-level module depends only on abstractions
@Service
public class OrderService {

    private final OrderRepository orderRepository;          // interface ✓
    private final EmailNotificationService emailService;    // interface ✓
    private final PaymentGateway paymentGateway;           // interface ✓

    // Constructor injection: explicit, final, testable without Spring container
    public OrderService(OrderRepository orderRepository,
                        EmailNotificationService emailService,
                        PaymentGateway paymentGateway) {
        this.orderRepository = orderRepository;
        this.emailService = emailService;
        this.paymentGateway = paymentGateway;
    }

    public OrderConfirmation placeOrder(PlaceOrderCommand cmd) {
        PaymentResult payment = paymentGateway.charge(cmd.cardToken(), cmd.amount());
        Order order = Order.from(cmd, payment.transactionId());
        orderRepository.save(order);
        emailService.sendOrderConfirmation(cmd.email(), order.getId());
        return new OrderConfirmation(order.getId(), payment.transactionId());
    }
}

// Low-level modules implement abstractions (Adapters in hexagonal terms)
@Repository
public class JpaOrderRepository implements OrderRepository {
    private final SpringDataOrderRepository jpaRepo;  // Spring Data JPA detail
    public JpaOrderRepository(SpringDataOrderRepository jpaRepo) { this.jpaRepo = jpaRepo; }

    @Override public void save(Order order) { jpaRepo.save(OrderEntity.from(order)); }
    @Override public Optional<Order> findById(UUID id) {
        return jpaRepo.findById(id).map(OrderEntity::toDomain);
    }
}

@Component
public class SendGridEmailService implements EmailNotificationService {
    private final SendGridClient sendGrid;
    public SendGridEmailService(SendGridClient sendGrid) { this.sendGrid = sendGrid; }

    @Override
    public void sendOrderConfirmation(String email, UUID orderId) {
        sendGrid.send(email, "Order confirmed: " + orderId);
    }
}

// Pure unit test — no Spring container, no mocks framework needed for wiring
class OrderServiceTest {
    @Test
    void placeOrder_chargesAndPersists() {
        // Can instantiate directly — constructor injection enables this
        var mockRepo = new InMemoryOrderRepository();
        var mockEmail = new NoOpEmailService();
        var mockPayment = new FakePaymentGateway(PaymentResult.success("txn-123"));

        var service = new OrderService(mockRepo, mockEmail, mockPayment);
        var confirmation = service.placeOrder(TestFixtures.validOrderCommand());

        assertThat(confirmation.transactionId()).isEqualTo("txn-123");
        assertThat(mockRepo.count()).isEqualTo(1);
    }
}

// ============================================================
// Hexagonal Architecture: Ports & Adapters with Spring
// ============================================================
// Domain defines the port (inbound) — no framework dependencies
public interface ProcessOrderUseCase {
    OrderConfirmation execute(PlaceOrderCommand cmd);
}

// Application core implements the use case using outbound ports
@UseCase  // custom stereotype, not Spring @Service — domain stays clean
public class ProcessOrderUseCaseImpl implements ProcessOrderUseCase {
    // Uses outbound ports (interfaces defined in domain)
    private final OrderRepository orderRepository;
    private final PaymentGateway paymentGateway;

    @Override
    public OrderConfirmation execute(PlaceOrderCommand cmd) { /* ... */ return null; }
}

// Inbound adapter: REST controller calls the use case port
@RestController
@RequiredArgsConstructor
public class OrderController {
    private final ProcessOrderUseCase processOrderUseCase;  // depends on port, not impl

    @PostMapping("/orders")
    public ResponseEntity<OrderConfirmationDTO> placeOrder(@RequestBody PlaceOrderRequest req) {
        var confirmation = processOrderUseCase.execute(req.toCommand());
        return ResponseEntity.ok(OrderConfirmationDTO.from(confirmation));
    }
}
```

**Follow-up Questions:**
1. If constructor injection is always preferred, when is setter injection acceptable?
2. How does Spring Boot's auto-configuration relate to DIP? Does it violate it?
3. What is the difference between dependency inversion and dependency injection containers?

**Common Mistakes:**
- Injecting concrete classes (e.g., `@Autowired JdbcTemplate` directly in service) — this is DI without DIP
- Creating interfaces only for services with two implementations, but leaving repositories as concrete — inconsistent application
- Confusing the Dependency Inversion Principle with the Inversion of Control container

**Interview Traps:**
- "Doesn't Spring Boot auto-configuration violate DIP since it creates concrete beans?" — Auto-configuration operates at the infrastructure layer; the domain still depends on abstractions; DIP is satisfied if the domain doesn't know about Spring
- "When would you NOT use constructor injection?" — Circular dependencies (use setter injection to break the cycle), optional dependencies with `@Autowired(required = false)`

**Quick Revision:** DIP = high-level modules depend on abstractions, not concretes; constructor injection enables testability; hexagonal architecture is DIP at architectural scale.

---

### Topic 6: DRY, KISS, YAGNI

**Difficulty:** Medium | **Frequency:** High | **Companies:** All FAANG+, all product startups

**Q:** Explain DRY, KISS, and YAGNI with practical Java examples. When does DRY actually cause harm?

**Short Answer:**  
DRY (Don't Repeat Yourself) advocates that every piece of knowledge should have a single authoritative representation — violating it creates divergence where the same logic exists in multiple places and updates must be applied consistently everywhere. KISS (Keep It Simple, Stupid) pushes for the simplest solution that works. YAGNI (You Ain't Gonna Need It) warns against implementing features speculatively before they're actually required. The tension: premature DRY abstraction (WET — Wrong Extraction Timing) can create worse coupling than the duplication it tried to eliminate.

**Deep Explanation:**  

**DRY — deeper than copy-paste:**
DRY is about knowledge duplication, not just code duplication. Two methods with identical code that represent *different business concepts* should NOT be merged — they'll diverge as requirements change. Conversely, two methods with *different code* that both encode the same business rule (e.g., VAT calculation) violate DRY even if the code looks different.

**The Wrong Abstraction (WET) problem:**
Over-eager DRY creates premature abstractions. When you find two pieces of similar code and immediately extract them into a shared utility, you might be:
1. Coupling two unrelated concepts because they *happened* to look the same today
2. Creating a shared function that must satisfy increasingly divergent requirements
3. Adding parameters, flags, and conditionals to the abstraction until it's more complex than the original duplication

Sandi Metz: "Duplication is far cheaper than the wrong abstraction."

**Rule of Three:** Don't abstract until you see the same pattern three times — by then you understand the true shape of the abstraction.

**KISS in practice:**
- Prefer `List.of()` over a custom collection builder
- Prefer a simple `switch` expression over a strategy pattern when there are 2 cases
- Prefer synchronous REST calls over event-driven choreography when simplicity suffices
- The most maintainable code is the code that doesn't exist

**YAGNI in practice:**
- Don't add a caching layer before profiling shows it's needed
- Don't design for multi-tenancy before the second tenant exists
- Don't add pagination to an endpoint that returns 10 items
- Don't implement an event bus because "we might need it someday"

**Real-World Example:**  
Two teams at a fintech independently built identical transaction fee calculation logic. When the fee structure changed, only one team updated their code. The divergence caused incorrect fee displays in the mobile app for 3 days. After applying DRY, a single `FeeCalculationService` became the authoritative source. — Separately, a team eagerly DRY'd their user validation across registration and profile update, then spent two sprints untangling them when the rules diverged.

**Code Example:**
```java
// ============================================================
// BAD: DRY violation — same business knowledge in two places
// ============================================================
public class OrderService {
    public double calculateShipping(Order order) {
        // Free shipping logic duplicated in TWO places
        if (order.getTotal() > 100.0) return 0.0;
        return order.getWeightKg() * 2.5;
    }
}

public class CartService {
    public double estimateShipping(Cart cart) {
        // Same free-shipping threshold — if it changes to $75, must update BOTH
        if (cart.getTotal() > 100.0) return 0.0;
        return cart.getTotalWeightKg() * 2.5;  // same formula
    }
}

// ============================================================
// GOOD: DRY — single authoritative source for shipping logic
// ============================================================
@Component
public class ShippingCalculator {
    private static final double FREE_SHIPPING_THRESHOLD = 100.0;
    private static final double RATE_PER_KG = 2.5;

    public Money calculate(Money orderTotal, double weightKg) {
        if (orderTotal.isGreaterThan(Money.of(FREE_SHIPPING_THRESHOLD))) {
            return Money.ZERO;
        }
        return Money.of(weightKg * RATE_PER_KG);
    }
}

// Both services delegate to the single authoritative calculator
@Service @RequiredArgsConstructor
public class OrderService {
    private final ShippingCalculator shippingCalculator;
    public Money calculateShipping(Order order) {
        return shippingCalculator.calculate(order.getTotal(), order.getWeightKg());
    }
}

// ============================================================
// BAD: Premature DRY / Wrong Abstraction
// Two things that look similar but are actually different concepts
// ============================================================
// Registration validation and profile update validation look similar today...
public class UserValidator {
    public void validate(UserData data, boolean isRegistration) {
        if (isRegistration) {
            validateEmailUnique(data.email());  // only for registration
            validatePasswordStrength(data.password());
        }
        validateEmailFormat(data.email());
        validateNameLength(data.name());
        if (!isRegistration) {
            validatePhoneFormat(data.phone());  // only for profile update
        }
        // Flag-based conditionals — classic wrong abstraction smell
    }
}

// ============================================================
// GOOD: Keep them separate — they'll diverge
// ============================================================
@Component
public class RegistrationValidator {
    public void validate(RegisterCommand cmd) {
        validateEmailFormat(cmd.email());
        validateEmailUnique(cmd.email());
        validatePasswordStrength(cmd.password());
        validateNameLength(cmd.name());
    }
}

@Component
public class ProfileUpdateValidator {
    public void validate(UpdateProfileCommand cmd) {
        validateEmailFormat(cmd.email());
        validateNameLength(cmd.name());
        validatePhoneFormat(cmd.phone());
        // Different rules, different future — should be separate
    }
}

// ============================================================
// YAGNI violation: building event bus "just in case"
// ============================================================
// BAD: Overengineered event infrastructure for simple use case
public class OrderService {
    private final EventBus eventBus;        // complex Guava EventBus
    private final EventRouter router;       // custom routing logic
    private final EventSerializer ser;      // JSON serialization
    private final DeadLetterQueue dlq;      // dead letter handling

    public void completeOrder(Order order) {
        OrderCompletedEvent evt = new OrderCompletedEvent(order);
        eventBus.post(ser.serialize(evt));  // 4 dependencies for... one email
    }
}

// GOOD: YAGNI — just call the email service directly
@Service @RequiredArgsConstructor
public class OrderService {
    private final OrderRepository orderRepository;
    private final EmailNotificationService emailService;

    public void completeOrder(Order order) {
        order.complete();
        orderRepository.save(order);
        emailService.sendCompletionEmail(order);  // direct call — simple, testable, correct
        // Add event bus WHEN you have >1 subscriber or need async processing
    }
}

// ============================================================
// KISS: Simple beats clever
// ============================================================
// BAD: Overly clever stream pipeline
public List<String> getActiveUserEmails(List<User> users) {
    return users.stream()
        .collect(Collectors.partitioningBy(User::isActive))
        .get(true)
        .stream()
        .filter(u -> u.getEmail() != null)
        .map(User::getEmail)
        .distinct()
        .sorted(Comparator.naturalOrder())
        .collect(Collectors.toUnmodifiableList());
}

// GOOD: Clear intent, easy to read and modify
public List<String> getActiveUserEmails(List<User> users) {
    return users.stream()
        .filter(User::isActive)
        .map(User::getEmail)
        .filter(Objects::nonNull)
        .distinct()
        .sorted()
        .toList();  // Java 16+ — simpler terminal operation
}
```

**Follow-up Questions:**
1. How do you distinguish between code that *should* be DRY'd and code that just *looks* similar?
2. At what point does a YAGNI-guided codebase become technical debt that slows feature development?
3. How does DRY apply at the database level (normalized vs denormalized schemas)?

**Common Mistakes:**
- Treating DRY as "eliminate all code duplication" rather than "eliminate knowledge duplication"
- Applying YAGNI to avoid writing tests, documentation, or proper error handling — these are needed now
- Using KISS to justify shortcuts that will cost much more to undo later (e.g., hardcoding configuration values)

**Interview Traps:**
- "Should you always apply DRY?" — No; accidental duplication (code that looks the same but represents different knowledge) should stay separate
- "Is copy-paste always bad?" — No; sometimes the right answer is to duplicate and then diverge freely; the wrong abstraction is worse than duplication
- "How does DRY apply in microservices?" — Shared libraries vs duplicated domain logic is a nuanced trade-off; sharing a library creates coupling between services

**Quick Revision:** DRY = eliminate knowledge duplication (not just code); KISS = simplest working solution; YAGNI = don't build what you don't need yet; premature DRY creates wrong abstractions worse than duplication.

---

### Topic 7: Clean Architecture

**Difficulty:** Hard | **Frequency:** High | **Companies:** Netflix, Uber, Airbnb, thoughtworks, Jane Street

**Q:** Explain Clean Architecture's layers and dependency rule. How does it compare to traditional layered architecture, and how do you implement it in Spring Boot?

**Short Answer:**  
Clean Architecture (Robert C. Martin) organizes code into concentric circles — Entities (enterprise rules), Use Cases (application rules), Interface Adapters (controllers/presenters/gateways), and Frameworks & Drivers (Spring, DB, web) — where the fundamental rule is that dependencies point inward only. Unlike traditional layered architecture where the domain layer depends on the infrastructure (via JPA annotations, etc.), Clean Architecture inverts this so the domain is framework-free and the infrastructure depends on domain-defined interfaces (Ports).

**Deep Explanation:**  

**The four layers (inner to outer):**

1. **Entities (Enterprise Business Rules)**
   - Pure domain objects — `Order`, `Customer`, `Money`
   - No framework annotations (`@Entity`, `@JsonProperty` etc.)
   - No dependencies on outer layers
   - Change only when fundamental business rules change

2. **Use Cases (Application Business Rules)**
   - Orchestrate entities to fulfill a user goal: `PlaceOrderUseCase`, `ProcessRefundUseCase`
   - Define outbound Ports (interfaces) — `OrderRepository`, `PaymentGateway`
   - No knowledge of HTTP, SQL, Kafka — only domain concepts
   - Change only when application-specific behavior changes

3. **Interface Adapters**
   - Controllers, Presenters, Gateways — translate between use case language and external formats
   - REST controllers convert HTTP requests → Use Case commands → HTTP responses
   - JPA repositories implement domain repository interfaces (Ports)
   - Kafka adapters implement domain event port interfaces

4. **Frameworks & Drivers**
   - Spring Boot, Hibernate, PostgreSQL, Kafka, Redis
   - Pure configuration — wire everything together
   - This layer is the "plugin" layer — swap it without touching the domain

**Dependency Rule (the central rule):**
Source code dependencies must point inward. Nothing in an inner circle can know about anything in an outer circle. The name of something declared in an outer circle must not be mentioned by the code in an inner circle.

**Crossed Wires — How the inner circle uses outer circle implementations:**
The Use Case layer defines a `UserRepository` interface. The Infrastructure layer implements `JpaUserRepository implements UserRepository`. At runtime, Spring injects the JPA implementation. At compile time, the Use Case only knows the interface — the dependency rule is honored.

**Clean Architecture vs Traditional Layered Architecture:**

| Aspect | Layered (MVC/3-tier) | Clean Architecture |
|--------|---------------------|-------------------|
| Domain depends on | Infrastructure (JPA, @Entity) | Nothing (pure Java) |
| Testability | Integration tests required | Unit-testable without container |
| Framework coupling | High (domain has Spring/JPA annotations) | Low (framework is a plugin) |
| Change cost | Changing DB requires domain changes | Changing DB is isolated to adapters |
| Complexity | Simple to start | Higher upfront complexity |
| When to use | Small CRUD apps, prototypes | Complex domain, long-lived systems |

**Real-World Example:**  
Netflix's recommendation engine domain logic has zero dependencies on their HTTP framework or Cassandra client. This allowed them to migrate from REST to gRPC, from Cassandra to a custom store, and from synchronous to reactive — without touching domain logic. At a smaller scale, a fintech company migrated from Stripe to Adyen by only replacing their `StripePaymentGateway` adapter with `AdyenPaymentGateway` — `ProcessPaymentUseCase` was untouched.

**Code Example:**
```java
// ============================================================
// Clean Architecture in Spring Boot — Package structure:
//
// com.example.ecommerce
// ├── domain/                     ← Layer 1: Entities
// │   ├── model/Order.java
// │   ├── model/Money.java
// │   └── event/OrderPlacedEvent.java
// ├── application/                ← Layer 2: Use Cases + Ports
// │   ├── port/in/PlaceOrderUseCase.java     (inbound port)
// │   ├── port/out/OrderRepository.java      (outbound port)
// │   ├── port/out/PaymentGateway.java       (outbound port)
// │   └── service/PlaceOrderService.java     (use case impl)
// ├── adapter/                    ← Layer 3: Interface Adapters
// │   ├── web/OrderController.java
// │   ├── persistence/JpaOrderRepository.java
// │   └── payment/StripePaymentGateway.java
// └── config/                     ← Layer 4: Framework config
//     └── ApplicationConfig.java
// ============================================================

// ---- LAYER 1: Domain Entity (no framework dependencies) ----
public class Order {  // NOT @Entity — pure domain object
    private final UUID id;
    private final UUID customerId;
    private final List<OrderItem> items;
    private OrderStatus status;
    private final Money total;

    // Domain behavior — business logic lives here
    public void confirm() {
        if (this.status != OrderStatus.PENDING)
            throw new InvalidOrderStateException("Can only confirm PENDING orders");
        this.status = OrderStatus.CONFIRMED;
    }

    public boolean canBeCancelled() {
        return status == OrderStatus.PENDING || status == OrderStatus.CONFIRMED;
    }
    // Pure Java — no Spring, no JPA, no Jackson annotations
}

// ---- LAYER 2: Inbound Port (use case interface) ----
public interface PlaceOrderUseCase {
    OrderId execute(PlaceOrderCommand command);  // command is also a domain object
}

// ---- LAYER 2: Outbound Ports (defined in application layer) ----
public interface OrderRepository {
    void save(Order order);
    Optional<Order> findById(OrderId id);
}

public interface PaymentGateway {
    PaymentResult charge(CustomerId customerId, Money amount, PaymentToken token);
}

// ---- LAYER 2: Use Case Implementation ----
@UseCase  // custom annotation, NOT @Service — keeps domain intent clear
@Transactional
@RequiredArgsConstructor
public class PlaceOrderService implements PlaceOrderUseCase {

    private final OrderRepository orderRepository;  // outbound port
    private final PaymentGateway paymentGateway;     // outbound port
    private final OrderIdGenerator idGenerator;      // outbound port

    @Override
    public OrderId execute(PlaceOrderCommand cmd) {
        // Pure business logic — no HTTP, no SQL, no Kafka here
        Order order = Order.create(
            idGenerator.generate(),
            cmd.customerId(),
            cmd.items()
        );

        PaymentResult payment = paymentGateway.charge(
            cmd.customerId(), order.getTotal(), cmd.paymentToken()
        );

        if (!payment.isSuccessful()) throw new PaymentFailedException(payment.errorCode());

        order.confirm();
        orderRepository.save(order);

        return order.getId();
    }
}

// ---- LAYER 3: Inbound Adapter (Web) ----
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {

    private final PlaceOrderUseCase placeOrderUseCase;  // depends on port, not impl

    @PostMapping
    public ResponseEntity<PlaceOrderResponse> placeOrder(
            @Valid @RequestBody PlaceOrderRequest request,
            Authentication auth) {

        // Adapter translates: HTTP → domain command
        PlaceOrderCommand command = PlaceOrderCommandMapper.from(request, auth.getName());
        OrderId orderId = placeOrderUseCase.execute(command);

        // Adapter translates: domain result → HTTP response
        return ResponseEntity
            .created(URI.create("/api/v1/orders/" + orderId.value()))
            .body(new PlaceOrderResponse(orderId.value()));
    }
}

// ---- LAYER 3: Outbound Adapter (Persistence) ----
@Repository
@RequiredArgsConstructor
public class JpaOrderRepositoryAdapter implements OrderRepository {

    private final SpringDataOrderRepository springDataRepo;  // JPA dependency isolated here
    private final OrderEntityMapper mapper;

    @Override
    public void save(Order order) {
        OrderEntity entity = mapper.toEntity(order);  // domain → JPA entity mapping
        springDataRepo.save(entity);
    }

    @Override
    public Optional<Order> findById(OrderId id) {
        return springDataRepo.findById(id.value())
            .map(mapper::toDomain);  // JPA entity → domain object mapping
    }
}

// ---- LAYER 3: Outbound Adapter (Payment) ----
@Component
@RequiredArgsConstructor
public class StripePaymentGatewayAdapter implements PaymentGateway {

    private final StripeClient stripeClient;  // Stripe SDK isolated here

    @Override
    public PaymentResult charge(CustomerId customerId, Money amount, PaymentToken token) {
        try {
            Charge charge = stripeClient.charges().create(
                ChargeCreateParams.builder()
                    .setAmount(amount.toCents())
                    .setCurrency(amount.currency().code())
                    .setSource(token.value())
                    .build()
            );
            return PaymentResult.success(charge.getId());
        } catch (StripeException e) {
            return PaymentResult.failure(e.getCode());
        }
    }
}
```

**Follow-up Questions:**
1. What is the cost of Clean Architecture, and when is it NOT worth applying?
2. How do you handle cross-cutting concerns (logging, transactions) in Clean Architecture without polluting the domain?
3. How does Clean Architecture interact with CQRS?

**Common Mistakes:**
- Putting `@Entity` or `@Table` on domain objects — this violates the dependency rule; use separate JPA entity classes and mappers
- Having use case services call `@Repository` Spring beans directly — use the port interface
- Creating Clean Architecture "by package name" but still letting domain classes import Spring annotations

**Interview Traps:**
- "Isn't Clean Architecture overkill for most applications?" — Yes for simple CRUD apps; the inflection point is when you need multiple infrastructure implementations, complex domain logic, or long-term maintainability. Most startups should start simpler and migrate toward Clean Architecture as complexity grows.
- "How do you handle Spring's `@Transactional` in Clean Architecture?" — Apply it at the Use Case service level (outermost application layer); don't push transaction management into the domain

**Quick Revision:** Clean Architecture = concentric layers, dependencies point inward only, domain has zero framework dependencies, infrastructure implements domain-defined port interfaces.

---

### Topic 8: Domain-Driven Design (DDD) Basics

**Difficulty:** Hard | **Frequency:** High | **Companies:** Amazon, Netflix, Spotify, Thoughtworks, Zalando

**Q:** Explain the core DDD building blocks — Bounded Context, Aggregate, Entity vs Value Object, Repository, Domain Events, and Ubiquitous Language. How do these map to a Spring Boot microservices architecture?

**Short Answer:**  
DDD is a software development approach where the design is driven by the domain model and close collaboration with domain experts. Key tactical patterns: Entities have identity and mutable state; Value Objects have no identity and are immutable; Aggregates are consistency boundaries protecting invariants; Repositories provide collection-like access to aggregates; Domain Events communicate state changes across boundaries. Strategic DDD uses Bounded Contexts to partition a large domain into autonomous areas, each with its own ubiquitous language and model.

**Deep Explanation:**  

**Ubiquitous Language:**
A shared vocabulary between developers and domain experts, used in code, tests, discussions, and documentation. If domain experts say "a Customer places an Order that contains Line Items," your code should have `Customer`, `Order`, and `LineItem` — not `UserRecord`, `PurchaseRequest`, and `CartEntry`. When the language in code diverges from what domain experts say, bugs hide in translation gaps.

**Entity vs Value Object:**

| Aspect | Entity | Value Object |
|--------|--------|--------------|
| Identity | Unique ID (e.g., UUID) | No identity |
| Equality | By ID | By all field values |
| Mutability | Mutable state over time | Immutable |
| Lifecycle | Has lifecycle (created, modified, deleted) | Created and discarded |
| Examples | Customer, Order, Product | Money, Address, Email, DateRange |

**Aggregate:**
A cluster of domain objects treated as a single unit for data changes. Every aggregate has a root (the Aggregate Root) — the only object in the cluster that external objects may hold a reference to. The aggregate root enforces all invariants.

Rules:
1. Reference other aggregates by ID only (not by object reference)
2. All invariants within an aggregate must be consistent after every transaction
3. One aggregate = one transaction (generally)
4. Size an aggregate by its transactional consistency requirement, not by data relatedness

**Bounded Context:**
An explicit boundary within which a domain model applies and has a specific meaning. The same word (e.g., "Customer") means different things in different contexts — in Sales, Customer includes purchasing history; in Shipping, Customer is just a delivery address. Each Bounded Context becomes a microservice (or module) with its own data store.

**Domain Events:**
Something that happened in the domain that domain experts care about: `OrderPlaced`, `PaymentProcessed`, `CustomerUpgraded`. Events communicate facts across Bounded Contexts without tight coupling. They are named in past tense (something *that happened*).

**Context Mapping patterns:**
- **Shared Kernel:** two contexts share a subset of the model (highest coupling)
- **Customer-Supplier:** upstream (supplier) produces, downstream (customer) consumes
- **Anti-Corruption Layer (ACL):** translator between two contexts with different models
- **Open Host Service:** well-documented API others can integrate with
- **Conformist:** downstream adopts upstream's model wholesale

**Real-World Example:**  
An e-commerce platform had a single `Order` concept used across Catalog, Cart, Fulfillment, Billing, and Analytics. Attempting to satisfy all contexts in one model made it impossible to evolve. After strategic DDD: `ShoppingCart` in Cart context, `SalesOrder` in Billing context, `FulfillmentOrder` in Warehouse context — same real-world concept, different models, each evolving independently. Events (`OrderConfirmed`, `PaymentReceived`) synchronize state across contexts asynchronously.

**Code Example:**
```java
// ============================================================
// Value Object — immutable, equality by value, no identity
// ============================================================
public record Money(BigDecimal amount, Currency currency) {

    // Canonical constructor with validation
    public Money {
        Objects.requireNonNull(amount, "amount must not be null");
        Objects.requireNonNull(currency, "currency must not be null");
        if (amount.scale() > 2) throw new IllegalArgumentException("Max 2 decimal places");
    }

    public static Money of(double amount, Currency currency) {
        return new Money(BigDecimal.valueOf(amount).setScale(2, RoundingMode.HALF_UP), currency);
    }

    public static Money usd(double amount) { return of(amount, Currency.USD); }

    public Money add(Money other) {
        if (!this.currency.equals(other.currency))
            throw new IllegalArgumentException("Cannot add different currencies");
        return new Money(this.amount.add(other.amount), this.currency);  // immutable — new instance
    }

    public boolean isGreaterThan(Money other) {
        return this.amount.compareTo(other.amount) > 0;
    }
}

// ============================================================
// Entity — has identity, mutable state, lifecycle
// ============================================================
public class OrderItem {
    private final OrderItemId id;  // own identity
    private final ProductId productId;
    private int quantity;
    private final Money unitPrice;

    // Entities compared by identity
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof OrderItem other)) return false;
        return id.equals(other.id);  // ID-based equality
    }
}

// ============================================================
// Aggregate Root — enforces invariants for the Order cluster
// ============================================================
public class Order {  // Aggregate Root

    private final OrderId id;
    private final CustomerId customerId;  // Reference by ID only — not Customer object
    private final List<OrderItem> items;  // Part of aggregate — can hold direct ref
    private OrderStatus status;
    private Money total;

    // Factory method — ensures valid initial state
    public static Order create(OrderId id, CustomerId customerId, List<OrderItem> items) {
        if (items.isEmpty()) throw new DomainException("Order must have at least one item");
        Order order = new Order(id, customerId, items, OrderStatus.PENDING);
        order.recalculateTotal();
        return order;
    }

    // Domain behavior — enforces business invariants
    public void addItem(OrderItem item) {
        if (status != OrderStatus.PENDING)
            throw new DomainException("Cannot add items to a non-pending order");
        items.add(item);
        recalculateTotal();
    }

    public void confirm(Money paymentAmount) {
        if (status != OrderStatus.PENDING)
            throw new DomainException("Only pending orders can be confirmed");
        if (!paymentAmount.equals(this.total))
            throw new DomainException("Payment amount must equal order total");
        this.status = OrderStatus.CONFIRMED;
        // Domain Event recorded (collected for publication after transaction)
        DomainEvents.raise(new OrderConfirmedEvent(this.id, this.customerId, this.total));
    }

    private void recalculateTotal() {
        this.total = items.stream()
            .map(item -> item.getUnitPrice().multiply(item.getQuantity()))
            .reduce(Money.usd(0), Money::add);
    }

    // NO setters — state changes only through domain methods that enforce invariants
}

// ============================================================
// Repository — collection-like abstraction for aggregates
// Only for aggregate roots (NOT for OrderItem directly)
// ============================================================
public interface OrderRepository {
    void save(Order order);
    Optional<Order> findById(OrderId id);
    List<Order> findByCustomerId(CustomerId customerId);
    // Note: No findOrderItemByProductId() — query aggregate root, not children
}

// ============================================================
// Domain Events — past tense, immutable facts
// ============================================================
public record OrderConfirmedEvent(
    OrderId orderId,
    CustomerId customerId,
    Money total,
    Instant occurredAt
) implements DomainEvent {
    public OrderConfirmedEvent(OrderId orderId, CustomerId customerId, Money total) {
        this(orderId, customerId, total, Instant.now());
    }
}

// ============================================================
// Domain Event Handlers — cross-context integration
// Each bounded context reacts to events it cares about
// ============================================================
// In Fulfillment Bounded Context
@Component
@RequiredArgsConstructor
public class FulfillmentOrderCreator {

    private final FulfillmentOrderRepository fulfillmentRepo;

    @EventListener
    @Transactional
    public void on(OrderConfirmedEvent event) {
        // Create a FulfillmentOrder — different model from Order in Sales context
        FulfillmentOrder fulfillmentOrder = FulfillmentOrder.create(
            FulfillmentOrderId.generate(),
            event.orderId(),   // referenced by ID — no direct coupling
            event.customerId()
        );
        fulfillmentRepo.save(fulfillmentOrder);
    }
}

// In Billing Bounded Context
@Component
@RequiredArgsConstructor
public class InvoiceGenerator {
    private final InvoiceRepository invoiceRepository;

    @EventListener
    @Async  // Different context can process asynchronously
    public void on(OrderConfirmedEvent event) {
        Invoice invoice = Invoice.generate(event.orderId(), event.total(), event.occurredAt());
        invoiceRepository.save(invoice);
    }
}

// ============================================================
// Anti-Corruption Layer (ACL) — translating between contexts
// ============================================================
@Component
@RequiredArgsConstructor
public class ExternalInventoryACL {

    private final LegacyInventoryClient legacyClient;  // external system with different model

    // Translates legacy model → our domain model
    public StockLevel getStockLevel(ProductId productId) {
        LegacyStockResponse response = legacyClient.checkStock(productId.value().toString());
        // ACL translates foreign concept "AVAIL_QTY" into our domain concept "StockLevel"
        return StockLevel.of(response.getAvailQty(), response.getReservedQty());
    }
}

// ============================================================
// Bounded Context — Spring Boot Microservice structure
// Each BC = separate Maven module / microservice
// ============================================================
/*
  order-service/          ← Sales Bounded Context
    domain/
      Order.java          ← Aggregate Root
      OrderItem.java      ← Entity (within Order aggregate)
      Money.java          ← Value Object
      OrderStatus.java    ← Enum (domain concept)
      OrderConfirmedEvent.java ← Domain Event

  fulfillment-service/    ← Fulfillment Bounded Context
    domain/
      FulfillmentOrder.java ← Different aggregate, different model
      PickList.java
      ShipmentTracker.java

  (Each service has its OWN database — no shared schema)
*/
```

**Follow-up Questions:**
1. How do you determine aggregate boundaries? What's the rule of thumb for aggregate size?
2. How do you handle eventual consistency between aggregates when a business transaction must span two aggregates?
3. What is the Saga pattern and how does it relate to DDD?

**Common Mistakes:**
- Making aggregates too large — grouping everything related in one aggregate creates performance and contention problems; size by transactional invariant, not by conceptual relatedness
- Putting domain logic in application services (anemic domain model) — business rules belong on entities and aggregates
- Using the same model across bounded contexts — this is the most common DDD anti-pattern; resist the "single source of truth" urge for cross-cutting entities

**Interview Traps:**
- "Should every microservice be a bounded context?" — 1:1 mapping is a good default, but a large bounded context might warrant multiple services, and two small bounded contexts might share a service; the boundary is logical, not technical
- "How do you choose between Domain Events and direct service calls for cross-context communication?" — Events for eventual consistency and decoupling; direct calls when you need synchronous consistency guarantees (and accept the coupling cost)
- "What is an Anemic Domain Model and why is it a DDD anti-pattern?" — An object with only getters/setters and no domain behavior; business logic leaks into services, violating encapsulation

**Quick Revision:** DDD = model software after the domain using Ubiquitous Language; Aggregates enforce invariants and are the unit of consistency; Bounded Contexts isolate models; Domain Events decouple contexts; Value Objects are immutable and compared by value.

---

## Quick Reference Card — Part A

| Principle | One-Line Summary | Key Pattern |
|-----------|-----------------|-------------|
| SRP | One class, one reason to change | Domain Events for side effects |
| OCP | Extend without modifying | Strategy + Spring bean lists |
| LSP | Subtypes honor parent contracts | Prefer composition, record types |
| ISP | Clients depend only on what they use | Role interfaces, narrow ports |
| DIP | High-level depends on abstractions | Constructor injection, hexagonal |
| DRY | One authoritative knowledge source | Extract when 3+ duplicates appear |
| Clean Arch | Dependencies inward only | Ports & Adapters |
| DDD | Domain drives design | Aggregates, Events, Bounded Contexts |

---

*Part B covers: Design Patterns (Creational, Structural, Behavioral), Anti-Patterns, Code Smells, Refactoring Techniques, and CQRS/Event Sourcing.*


---

# Chapter 20 — SOLID Principles & Clean Architecture (Part B)
### Topics 9–15 + Cheat Sheet | Java 17 | SDE2 / FAANG+

---

## Table of Contents

| # | Topic |
|---|-------|
| 9 | Code Smells & Refactoring |
| 10 | CQRS Pattern |
| 11 | Event Sourcing |
| 12 | Hexagonal Architecture (Ports & Adapters) |
| 13 | Testing Principles |
| 14 | API Design Principles |
| 15 | Technical Debt |
| — | Cheat Sheet |

---

## Topic 9 — Code Smells & Refactoring

### What is a Code Smell?
A **code smell** is a surface-level indication that something may be wrong deeper in the code. It does not always mean a bug exists, but it signals a design problem that will compound over time.

> "A code smell is a hint that something has gone wrong somewhere in your code. Use the smell to track down the problem."
> — Martin Fowler, *Refactoring*

---

### Smell 1: Long Method

**Symptom:** A method exceeds ~20 lines, handles multiple concerns, and is hard to name with a single verb phrase.

```java
// BAD — Long Method
public void processOrder(Order order) {
    // validate
    if (order.getItems() == null || order.getItems().isEmpty()) {
        throw new IllegalArgumentException("Order must have items");
    }
    if (order.getCustomerId() == null) {
        throw new IllegalArgumentException("Customer ID required");
    }

    // calculate totals
    double subtotal = 0;
    for (OrderItem item : order.getItems()) {
        subtotal += item.getPrice() * item.getQuantity();
    }
    double tax = subtotal * 0.08;
    double shipping = subtotal > 100 ? 0 : 9.99;
    double total = subtotal + tax + shipping;
    order.setTotal(total);

    // persist
    orderRepository.save(order);

    // notify
    emailService.sendOrderConfirmation(order.getCustomerId(), order.getId());
    smsService.sendConfirmation(order.getCustomerId(), order.getId());
}
```

```java
// GOOD — Extract Method refactoring
public void processOrder(Order order) {
    validateOrder(order);
    calculateTotals(order);
    orderRepository.save(order);
    notifyCustomer(order);
}

private void validateOrder(Order order) {
    if (order.getItems() == null || order.getItems().isEmpty()) {
        throw new IllegalArgumentException("Order must have items");
    }
    if (order.getCustomerId() == null) {
        throw new IllegalArgumentException("Customer ID required");
    }
}

private void calculateTotals(Order order) {
    double subtotal = order.getItems().stream()
        .mapToDouble(item -> item.getPrice() * item.getQuantity())
        .sum();
    double tax = subtotal * TAX_RATE;
    double shipping = subtotal > FREE_SHIPPING_THRESHOLD ? 0 : SHIPPING_COST;
    order.setTotal(subtotal + tax + shipping);
}

private void notifyCustomer(Order order) {
    emailService.sendOrderConfirmation(order.getCustomerId(), order.getId());
    smsService.sendConfirmation(order.getCustomerId(), order.getId());
}
```

**Refactoring techniques:** Extract Method, Replace Temp with Query, Decompose Conditional.

---

### Smell 2: Large Class (God Class)

**Symptom:** A class has too many fields, methods, and responsibilities. It knows too much and does too much.

```java
// BAD — God Class
public class UserService {
    // user management
    public User createUser(CreateUserRequest req) { ... }
    public void updateProfile(Long userId, ProfileDto dto) { ... }
    public void deleteUser(Long userId) { ... }

    // authentication
    public String login(String email, String password) { ... }
    public void logout(String token) { ... }
    public void resetPassword(String email) { ... }

    // billing
    public void createSubscription(Long userId, PlanType plan) { ... }
    public Invoice generateInvoice(Long userId, YearMonth month) { ... }
    public void processPayment(Long userId, PaymentDetails details) { ... }

    // reporting
    public UserActivityReport getActivityReport(Long userId) { ... }
    public List<User> getInactiveUsers(Duration threshold) { ... }
}
```

```java
// GOOD — Split by responsibility (SRP)
@Service
public class UserManagementService {
    public User createUser(CreateUserRequest req) { ... }
    public void updateProfile(Long userId, ProfileDto dto) { ... }
    public void deleteUser(Long userId) { ... }
}

@Service
public class AuthenticationService {
    public AuthToken login(String email, String password) { ... }
    public void logout(String token) { ... }
    public void resetPassword(String email) { ... }
}

@Service
public class BillingService {
    public void createSubscription(Long userId, PlanType plan) { ... }
    public Invoice generateInvoice(Long userId, YearMonth month) { ... }
    public void processPayment(Long userId, PaymentDetails details) { ... }
}

@Service
public class UserReportingService {
    public UserActivityReport getActivityReport(Long userId) { ... }
    public List<User> getInactiveUsers(Duration threshold) { ... }
}
```

**Refactoring techniques:** Extract Class, Move Method, Move Field.

---

### Smell 3: Feature Envy

**Symptom:** A method seems more interested in the data of another class than its own — it calls many methods on a foreign object.

```java
// BAD — Feature Envy: OrderPrinter envies Order's data
public class OrderPrinter {
    public String format(Order order) {
        StringBuilder sb = new StringBuilder();
        sb.append("Customer: ").append(order.getCustomer().getFirstName())
          .append(" ").append(order.getCustomer().getLastName());
        sb.append("\nEmail: ").append(order.getCustomer().getEmail());
        sb.append("\nAddress: ").append(order.getCustomer().getAddress().getStreet())
          .append(", ").append(order.getCustomer().getAddress().getCity());
        sb.append("\nTotal: ").append(order.getTotal());
        return sb.toString();
    }
}
```

```java
// GOOD — Move the method to where the data lives
public class Order {
    private Customer customer;
    private double total;

    public String formatForPrint() {
        return "Customer: %s\nEmail: %s\nAddress: %s\nTotal: %.2f"
            .formatted(
                customer.fullName(),
                customer.getEmail(),
                customer.formattedAddress(),
                total
            );
    }
}

public class Customer {
    public String fullName() {
        return firstName + " " + lastName;
    }
    public String formattedAddress() {
        return address.getStreet() + ", " + address.getCity();
    }
}
```

**Refactoring techniques:** Move Method, Extract Method then Move.

---

### Smell 4: Primitive Obsession

**Symptom:** Using primitive types (String, int, double) to represent domain concepts that deserve their own class.

```java
// BAD — Primitives for domain concepts
public class Order {
    private String status;           // should be an enum or value object
    private double price;            // no currency, no precision guarantee
    private String phoneNumber;      // no validation
    private String zipCode;          // no format enforcement
}

public void ship(Order order) {
    if (order.getStatus().equals("PAID")) {   // magic string
        ...
    }
}
```

```java
// GOOD — Replace Primitive with Object / Value Object
public enum OrderStatus { PENDING, PAID, SHIPPED, DELIVERED, CANCELLED }

public record Money(BigDecimal amount, Currency currency) {
    public Money {
        Objects.requireNonNull(amount);
        Objects.requireNonNull(currency);
        if (amount.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Amount cannot be negative");
        }
    }
    public Money add(Money other) {
        if (!currency.equals(other.currency)) throw new IllegalArgumentException("Currency mismatch");
        return new Money(amount.add(other.amount), currency);
    }
}

public record PhoneNumber(String value) {
    private static final Pattern PATTERN = Pattern.compile("^\\+?[1-9]\\d{1,14}$");
    public PhoneNumber {
        if (!PATTERN.matcher(value).matches()) throw new IllegalArgumentException("Invalid phone: " + value);
    }
}

public class Order {
    private OrderStatus status;
    private Money price;
    private PhoneNumber contactPhone;
}
```

**Refactoring techniques:** Replace Primitive with Object, Introduce Value Object, Replace Type Code with Class.

---

### Smell 5: Data Clumps

**Symptom:** The same group of data items (e.g., firstName, lastName, email) appear together repeatedly across multiple methods and classes, but are never encapsulated together.

```java
// BAD — Data Clumps
public void sendEmail(String firstName, String lastName, String email, String subject, String body) { ... }
public User createUser(String firstName, String lastName, String email, String role) { ... }
public Invoice bill(String firstName, String lastName, String email, Money amount) { ... }
```

```java
// GOOD — Extract Class for the clump
public record PersonName(String firstName, String lastName) {
    public String full() { return firstName + " " + lastName; }
}

public record ContactInfo(PersonName name, String email) {}

public void sendEmail(ContactInfo contact, String subject, String body) { ... }
public User createUser(ContactInfo contact, Role role) { ... }
public Invoice bill(ContactInfo contact, Money amount) { ... }
```

**Refactoring techniques:** Extract Class, Introduce Parameter Object, Preserve Whole Object.

---

### Smell 6: Shotgun Surgery

**Symptom:** Every time you make one logical change, you must make many small edits scattered across many different classes. The opposite of Large Class — the responsibility is too distributed.

```java
// BAD — VAT rate change requires touching 6 classes
public class OrderCalculator {
    public double calculateTax(double amount) { return amount * 0.20; }  // change here
}
public class InvoiceGenerator {
    public double computeVAT(double net) { return net * 0.20; }          // and here
}
public class QuoteService {
    public double estimateTax(double price) { return price * 0.20; }     // and here
}
// ... and 3 more classes
```

```java
// GOOD — Centralize the varying concept
@Component
public class TaxPolicy {
    @Value("${tax.vat-rate:0.20}")
    private double vatRate;

    public Money calculateVAT(Money netAmount) {
        return new Money(netAmount.amount().multiply(BigDecimal.valueOf(vatRate)),
                         netAmount.currency());
    }
}

// All services inject TaxPolicy — one change, everywhere consistent
@Service
public class OrderCalculator {
    private final TaxPolicy taxPolicy;
    public Money calculateTax(Money amount) { return taxPolicy.calculateVAT(amount); }
}
```

**Refactoring techniques:** Move Method, Move Field, Inline Class (consolidate), introduce a single authoritative class.

---

### Smell 7: Divergent Change

**Symptom:** One class is changed for many different reasons — each "why" for a change is different. Violates SRP at a higher level: the class has multiple axes of variation.

```java
// BAD — UserService changes when: auth logic changes, DB schema changes, notification format changes
public class UserService {
    public User authenticate(String email, String password) {
        // auth logic — axis 1
        User user = userRepository.findByEmail(email)   // DB access — axis 2
            .orElseThrow(() -> new AuthException("Not found"));
        emailService.sendLoginAlert(user.getEmail());   // notification — axis 3
        return user;
    }
}
```

```java
// GOOD — One class per axis of change
@Service
public class AuthenticationService {          // changes when: auth algorithm changes
    private final UserRepository userRepository;
    private final PasswordEncoder encoder;
    public AuthToken authenticate(Credentials creds) { ... }
}

@Repository
public class UserRepository { ... }          // changes when: DB schema changes

@Service
public class LoginNotificationService { ... } // changes when: notification format changes
```

**Refactoring techniques:** Extract Class, move related methods together.

---

### Refactoring Techniques Summary

| Technique | When to Apply |
|-----------|--------------|
| Extract Method | Long method; repeated code blocks |
| Extract Class | Large class; data clumps; divergent change |
| Move Method/Field | Feature envy; shotgun surgery |
| Replace Primitive with Object | Primitive obsession |
| Introduce Parameter Object | Data clumps in method signatures |
| Inline Class | Too many trivial classes after shotgun surgery fix |
| Replace Type Code with Subclasses | Type codes driving conditionals |
| Replace Conditional with Polymorphism | Switch/if chains on type |

---

## Topic 10 — CQRS Pattern

### What is CQRS?

**Command Query Responsibility Segregation (CQRS)** separates the *write* model (commands that change state) from the *read* model (queries that return data). Coined by Greg Young, inspired by Meyer's CQS principle.

```
Traditional:         CQRS:
                     ┌──────────────────────────────┐
┌──────────┐         │   COMMAND SIDE               │
│  Service │         │  Commands → Command Handlers  │
│ read +   │         │  → Write Model → Write DB     │
│ write    │         ├──────────────────────────────┤
│ same     │         │   QUERY SIDE                  │
│ model    │         │  Queries → Query Handlers     │
└──────────┘         │  → Read Model → Read DB/Cache │
                     └──────────────────────────────┘
```

### Why CQRS?

| Problem | CQRS Solution |
|---------|--------------|
| Read and write scalability differ | Scale read replicas independently |
| Domain model cluttered with projection concerns | Separate models, each optimised |
| Complex queries slow down the write path | Dedicated read store (denormalised) |
| Audit / event history needed | Commands pair naturally with event sourcing |

---

### Spring Implementation

```java
// ─── DOMAIN ──────────────────────────────────────────────────────────────────

// Write model — rich domain object
@Entity
@Table(name = "products")
public class Product {
    @Id @GeneratedValue
    private Long id;
    private String name;
    private BigDecimal price;
    private int stockQuantity;

    public void adjustStock(int delta) {
        if (stockQuantity + delta < 0) throw new InsufficientStockException(id);
        this.stockQuantity += delta;
    }

    public void updatePrice(BigDecimal newPrice) {
        if (newPrice.compareTo(BigDecimal.ZERO) <= 0) throw new InvalidPriceException();
        this.price = newPrice;
    }
}

// ─── COMMANDS ────────────────────────────────────────────────────────────────

public sealed interface ProductCommand permits
    CreateProductCommand, UpdatePriceCommand, AdjustStockCommand {}

public record CreateProductCommand(
    String name,
    BigDecimal price,
    int initialStock
) implements ProductCommand {}

public record UpdatePriceCommand(
    Long productId,
    BigDecimal newPrice
) implements ProductCommand {}

public record AdjustStockCommand(
    Long productId,
    int delta
) implements ProductCommand {}

// ─── COMMAND HANDLERS ────────────────────────────────────────────────────────

@Service
@Transactional
public class ProductCommandService {
    private final ProductWriteRepository writeRepository;
    private final ApplicationEventPublisher eventPublisher;

    public Long handle(CreateProductCommand cmd) {
        var product = new Product(cmd.name(), cmd.price(), cmd.initialStock());
        Product saved = writeRepository.save(product);
        eventPublisher.publishEvent(new ProductCreatedEvent(saved.getId(), saved.getName()));
        return saved.getId();
    }

    public void handle(UpdatePriceCommand cmd) {
        Product product = writeRepository.findById(cmd.productId())
            .orElseThrow(() -> new ProductNotFoundException(cmd.productId()));
        product.updatePrice(cmd.newPrice());
        eventPublisher.publishEvent(new PriceUpdatedEvent(cmd.productId(), cmd.newPrice()));
    }

    public void handle(AdjustStockCommand cmd) {
        Product product = writeRepository.findById(cmd.productId())
            .orElseThrow(() -> new ProductNotFoundException(cmd.productId()));
        product.adjustStock(cmd.delta());
    }
}

// ─── QUERIES ─────────────────────────────────────────────────────────────────

// Read model — flat DTO optimized for queries (denormalised)
public record ProductSummaryView(
    Long id,
    String name,
    BigDecimal price,
    int stockQuantity,
    String categoryName,    // denormalised — no join needed
    double averageRating    // denormalised — pre-computed
) {}

public record ProductDetailView(
    Long id,
    String name,
    String description,
    BigDecimal price,
    int stockQuantity,
    String categoryName,
    List<String> tags,
    double averageRating,
    int reviewCount
) {}

// ─── QUERY HANDLERS ──────────────────────────────────────────────────────────

@Service
@Transactional(readOnly = true)
public class ProductQueryService {
    private final ProductReadRepository readRepository;

    // Optimised query — hits a read-optimised projection, not the rich domain model
    public Page<ProductSummaryView> findAll(ProductSearchCriteria criteria, Pageable pageable) {
        return readRepository.findSummaries(criteria, pageable);
    }

    public Optional<ProductDetailView> findById(Long id) {
        return readRepository.findDetailById(id);
    }

    public List<ProductSummaryView> findLowStock(int threshold) {
        return readRepository.findByStockQuantityLessThan(threshold);
    }
}

// ─── CONTROLLER ──────────────────────────────────────────────────────────────

@RestController
@RequestMapping("/api/v1/products")
public class ProductController {
    private final ProductCommandService commandService;
    private final ProductQueryService queryService;

    // Writes go to command service
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Long> create(@RequestBody @Valid CreateProductRequest req) {
        Long id = commandService.handle(new CreateProductCommand(req.name(), req.price(), req.initialStock()));
        return Map.of("id", id);
    }

    @PatchMapping("/{id}/price")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updatePrice(@PathVariable Long id, @RequestBody @Valid UpdatePriceRequest req) {
        commandService.handle(new UpdatePriceCommand(id, req.price()));
    }

    // Reads go to query service
    @GetMapping
    public Page<ProductSummaryView> list(ProductSearchCriteria criteria, Pageable pageable) {
        return queryService.findAll(criteria, pageable);
    }

    @GetMapping("/{id}")
    public ProductDetailView get(@PathVariable Long id) {
        return queryService.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
    }
}
```

### Eventual Consistency in CQRS

When the read store is updated asynchronously (e.g., via events from the write store):

```java
// Event listener updates the read model when the write model changes
@Component
public class ProductReadModelProjector {
    private final ProductReadRepository readRepository;

    @EventListener
    @Async
    public void on(ProductCreatedEvent event) {
        // Write to read store — could be a different DB, Elasticsearch, Redis, etc.
        readRepository.upsertSummary(new ProductSummaryView(
            event.productId(), event.name(), event.price(), event.initialStock(),
            event.categoryName(), 0.0
        ));
    }

    @EventListener
    @Async
    public void on(PriceUpdatedEvent event) {
        readRepository.updatePrice(event.productId(), event.newPrice());
    }
}
```

**Interview tip:** "Eventual consistency means reads may briefly return stale data after a write. The UI should tolerate this — e.g., by showing the value the user just submitted (optimistic UI) while the projection catches up."

---

## Topic 11 — Event Sourcing

### Core Concept

In traditional CRUD, you store the **current state** of an entity. In Event Sourcing, you store the **sequence of events** that led to the current state. State is derived by replaying events.

```
Traditional CRUD:
  ORDER table → { id:1, status:"SHIPPED", total:99.99 }   ← only current state

Event Sourcing:
  EVENTS table:
  { aggregate_id:1, seq:1, type:"OrderPlaced",   data:{total:99.99} }
  { aggregate_id:1, seq:2, type:"PaymentReceived",data:{amount:99.99}}
  { aggregate_id:1, seq:3, type:"OrderShipped",  data:{carrier:"FedEx"}}
  
  Current state = replay seq 1→3
```

---

### Implementation

```java
// ─── EVENTS ──────────────────────────────────────────────────────────────────

public sealed interface OrderEvent permits
    OrderPlacedEvent, PaymentReceivedEvent, OrderShippedEvent, OrderCancelledEvent {}

public record OrderPlacedEvent(
    UUID orderId,
    UUID customerId,
    List<OrderItem> items,
    Money total,
    Instant occurredAt
) implements OrderEvent {}

public record PaymentReceivedEvent(
    UUID orderId,
    Money amount,
    String transactionId,
    Instant occurredAt
) implements OrderEvent {}

public record OrderShippedEvent(
    UUID orderId,
    String carrier,
    String trackingNumber,
    Instant occurredAt
) implements OrderEvent {}

// ─── AGGREGATE ───────────────────────────────────────────────────────────────

public class Order {
    private UUID id;
    private UUID customerId;
    private OrderStatus status;
    private Money total;
    private String trackingNumber;

    // Pending events to be persisted
    private final List<OrderEvent> pendingEvents = new ArrayList<>();

    // Reconstitute from events (replay)
    public static Order reconstitute(List<OrderEvent> history) {
        var order = new Order();
        history.forEach(order::apply);
        return order;
    }

    // ── Command methods (business logic) ─────────────────────────────────────

    public static Order place(UUID customerId, List<OrderItem> items, Money total) {
        var order = new Order();
        var event = new OrderPlacedEvent(UUID.randomUUID(), customerId, items, total, Instant.now());
        order.apply(event);
        order.pendingEvents.add(event);
        return order;
    }

    public void receivePayment(Money amount, String transactionId) {
        if (status != OrderStatus.PENDING) throw new IllegalStateException("Order not pending");
        var event = new PaymentReceivedEvent(id, amount, transactionId, Instant.now());
        apply(event);
        pendingEvents.add(event);
    }

    public void ship(String carrier, String trackingNumber) {
        if (status != OrderStatus.PAID) throw new IllegalStateException("Order not paid");
        var event = new OrderShippedEvent(id, carrier, trackingNumber, Instant.now());
        apply(event);
        pendingEvents.add(event);
    }

    // ── Apply methods (state mutation — no business logic here) ───────────────

    private void apply(OrderEvent event) {
        switch (event) {
            case OrderPlacedEvent e -> {
                this.id = e.orderId();
                this.customerId = e.customerId();
                this.total = e.total();
                this.status = OrderStatus.PENDING;
            }
            case PaymentReceivedEvent e -> this.status = OrderStatus.PAID;
            case OrderShippedEvent e -> {
                this.status = OrderStatus.SHIPPED;
                this.trackingNumber = e.trackingNumber();
            }
            case OrderCancelledEvent e -> this.status = OrderStatus.CANCELLED;
        }
    }

    public List<OrderEvent> drainPendingEvents() {
        var events = List.copyOf(pendingEvents);
        pendingEvents.clear();
        return events;
    }
}

// ─── EVENT STORE ─────────────────────────────────────────────────────────────

public interface EventStore {
    void append(UUID aggregateId, List<OrderEvent> events, long expectedVersion);
    List<OrderEvent> load(UUID aggregateId);
    List<OrderEvent> loadFrom(UUID aggregateId, long fromSequence);
}

@Repository
public class JdbcEventStore implements EventStore {
    private final JdbcTemplate jdbc;
    private final ObjectMapper mapper;

    @Override
    @Transactional
    public void append(UUID aggregateId, List<OrderEvent> events, long expectedVersion) {
        // Optimistic concurrency check
        Long currentVersion = jdbc.queryForObject(
            "SELECT COALESCE(MAX(sequence_number), 0) FROM order_events WHERE aggregate_id = ?",
            Long.class, aggregateId);

        if (!Objects.equals(currentVersion, expectedVersion)) {
            throw new OptimisticConcurrencyException(
                "Expected version %d but found %d".formatted(expectedVersion, currentVersion));
        }

        long seq = expectedVersion;
        for (OrderEvent event : events) {
            seq++;
            jdbc.update(
                "INSERT INTO order_events (aggregate_id, sequence_number, event_type, event_data, occurred_at) VALUES (?,?,?,?,?)",
                aggregateId, seq, event.getClass().getSimpleName(),
                serializeEvent(event), Instant.now()
            );
        }
    }

    @Override
    public List<OrderEvent> load(UUID aggregateId) {
        return jdbc.query(
            "SELECT event_type, event_data FROM order_events WHERE aggregate_id = ? ORDER BY sequence_number",
            (rs, row) -> deserializeEvent(rs.getString("event_type"), rs.getString("event_data")),
            aggregateId
        );
    }
}

// ─── REPOSITORY ──────────────────────────────────────────────────────────────

@Component
public class EventSourcedOrderRepository {
    private final EventStore eventStore;

    public Order load(UUID orderId) {
        List<OrderEvent> events = eventStore.load(orderId);
        if (events.isEmpty()) throw new OrderNotFoundException(orderId);
        return Order.reconstitute(events);
    }

    public void save(Order order) {
        List<OrderEvent> newEvents = order.drainPendingEvents();
        eventStore.append(order.getId(), newEvents, order.getVersion());
    }
}
```

### Snapshotting

Replaying thousands of events on every load is slow. Snapshots periodically checkpoint the state.

```java
public class SnapshotStrategy {
    private static final int SNAPSHOT_THRESHOLD = 100;

    public boolean shouldSnapshot(long eventCount) {
        return eventCount % SNAPSHOT_THRESHOLD == 0;
    }
}

// Load: try snapshot first, then load only events after snapshot version
public Order loadWithSnapshot(UUID orderId) {
    Optional<OrderSnapshot> snapshot = snapshotStore.findLatest(orderId);
    if (snapshot.isPresent()) {
        OrderSnapshot snap = snapshot.get();
        List<OrderEvent> tail = eventStore.loadFrom(orderId, snap.version() + 1);
        Order order = Order.fromSnapshot(snap);
        tail.forEach(order::applyExisting);
        return order;
    }
    return Order.reconstitute(eventStore.load(orderId));
}
```

### Event Sourcing vs Traditional CRUD

| Aspect | Event Sourcing | Traditional CRUD |
|--------|---------------|-----------------|
| Storage | Event log (append-only) | Current state table |
| Audit trail | Built-in — full history | Requires separate audit table |
| Temporal queries | Easy — replay to any point | Hard — need history tables |
| Debugging | Replay what happened | Check logs |
| Complexity | High — new paradigm | Low — familiar |
| Storage cost | Higher — events accumulate | Lower — current state only |
| Read performance | Slower (replay) mitigated by snapshots | Faster direct lookup |
| Best for | Complex domains, audit-critical, CQRS complement | Simple CRUD, high read/write ratio |

---

## Topic 12 — Hexagonal Architecture (Ports & Adapters)

### Overview

Proposed by Alistair Cockburn. The goal: **the application core must be independent of all infrastructure concerns**. It communicates with the outside world through **ports** (interfaces) and **adapters** (implementations).

```
                    ┌─────────────────────────────────────────┐
 REST Controller    │              APPLICATION CORE            │
 (Driving Adapter)──┤──► Driving Port ───────────────────────┤
                    │    (e.g. OrderUseCase interface)         │
 CLI                │                                          │
 (Driving Adapter)──┤──► Domain Services ◄──► Domain Model   │
                    │                                          │
                    │    Driven Port ─────────────────────────┤──► JPA Adapter
                    │    (e.g. OrderRepository interface)      │    (Driven Adapter)
                    │                                          │
                    │    Driven Port ─────────────────────────┤──► Email SMTP Adapter
                    │    (e.g. NotificationPort interface)     │
                    └─────────────────────────────────────────┘
```

- **Driving adapters** (left side) initiate interactions: REST, CLI, gRPC, message consumer
- **Driven adapters** (right side) are called by the application: DB, email, payment gateway, file system

---

### Implementation

```java
// ─── DOMAIN MODEL ────────────────────────────────────────────────────────────

// Pure Java — no framework annotations
public class Order {
    private final OrderId id;
    private final CustomerId customerId;
    private final List<OrderLine> lines;
    private OrderStatus status;
    private Money total;

    public Order(OrderId id, CustomerId customerId, List<OrderLine> lines) {
        this.id = Objects.requireNonNull(id);
        this.customerId = Objects.requireNonNull(customerId);
        this.lines = List.copyOf(lines);
        this.status = OrderStatus.PENDING;
        this.total = calculateTotal();
    }

    public void confirm() {
        if (status != OrderStatus.PENDING) throw new IllegalStateException("Cannot confirm: " + status);
        this.status = OrderStatus.CONFIRMED;
    }

    private Money calculateTotal() {
        return lines.stream()
            .map(OrderLine::subtotal)
            .reduce(Money.ZERO_USD, Money::add);
    }
}

// ─── DRIVING PORTS (what the application exposes) ────────────────────────────

public interface PlaceOrderUseCase {
    OrderId placeOrder(PlaceOrderCommand command);
}

public interface GetOrderUseCase {
    OrderDetails getOrder(OrderId orderId);
}

// ─── DRIVEN PORTS (what the application requires) ────────────────────────────

public interface OrderRepository {  // driven port — persistence abstraction
    void save(Order order);
    Optional<Order> findById(OrderId orderId);
    List<Order> findByCustomerId(CustomerId customerId);
}

public interface NotificationPort {  // driven port — notification abstraction
    void notifyOrderPlaced(CustomerId customerId, OrderId orderId, Money total);
}

public interface PaymentPort {  // driven port — payment abstraction
    PaymentResult charge(CustomerId customerId, Money amount, PaymentMethod method);
}

// ─── APPLICATION SERVICE (core — implements driving ports, uses driven ports) ──

@Service
public class PlaceOrderService implements PlaceOrderUseCase {
    private final OrderRepository orderRepository;    // driven port injected
    private final NotificationPort notificationPort;  // driven port injected
    private final PaymentPort paymentPort;            // driven port injected

    public PlaceOrderService(
        OrderRepository orderRepository,
        NotificationPort notificationPort,
        PaymentPort paymentPort
    ) {
        this.orderRepository = orderRepository;
        this.notificationPort = notificationPort;
        this.paymentPort = paymentPort;
    }

    @Override
    public OrderId placeOrder(PlaceOrderCommand command) {
        // Business logic lives here — no HTTP, no JPA, no SMTP
        List<OrderLine> lines = command.items().stream()
            .map(item -> new OrderLine(item.productId(), item.quantity(), item.unitPrice()))
            .toList();

        var order = new Order(OrderId.generate(), command.customerId(), lines);

        PaymentResult payment = paymentPort.charge(
            command.customerId(), order.getTotal(), command.paymentMethod());
        if (!payment.isSuccessful()) throw new PaymentFailedException(payment.reason());

        order.confirm();
        orderRepository.save(order);
        notificationPort.notifyOrderPlaced(command.customerId(), order.getId(), order.getTotal());

        return order.getId();
    }
}

// ─── DRIVING ADAPTER — REST ───────────────────────────────────────────────────

@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {  // driving adapter — knows HTTP, translates to use case
    private final PlaceOrderUseCase placeOrderUseCase;
    private final GetOrderUseCase getOrderUseCase;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PlaceOrderResponse place(@RequestBody @Valid PlaceOrderHttpRequest request) {
        PlaceOrderCommand command = OrderHttpMapper.toCommand(request);
        OrderId orderId = placeOrderUseCase.placeOrder(command);
        return new PlaceOrderResponse(orderId.value());
    }
}

// ─── DRIVEN ADAPTER — JPA PERSISTENCE ────────────────────────────────────────

@Repository
public class JpaOrderRepository implements OrderRepository {  // driven adapter — knows JPA
    private final OrderJpaRepository jpaRepository;
    private final OrderPersistenceMapper mapper;

    @Override
    public void save(Order order) {
        OrderEntity entity = mapper.toEntity(order);
        jpaRepository.save(entity);
    }

    @Override
    public Optional<Order> findById(OrderId orderId) {
        return jpaRepository.findById(orderId.value())
            .map(mapper::toDomain);
    }
}

// ─── DRIVEN ADAPTER — EMAIL NOTIFICATION ──────────────────────────────────────

@Component
public class SmtpNotificationAdapter implements NotificationPort {
    private final JavaMailSender mailSender;

    @Override
    public void notifyOrderPlaced(CustomerId customerId, OrderId orderId, Money total) {
        // SMTP specifics stay here — the domain doesn't know about email
        SimpleMailMessage msg = new SimpleMailMessage();
        msg.setTo(resolveEmail(customerId));
        msg.setSubject("Order Confirmed: " + orderId.value());
        msg.setText("Your order of " + total + " has been placed.");
        mailSender.send(msg);
    }
}

// ─── IN-MEMORY ADAPTER — for testing ─────────────────────────────────────────

public class InMemoryOrderRepository implements OrderRepository {
    private final Map<OrderId, Order> store = new ConcurrentHashMap<>();

    @Override
    public void save(Order order) { store.put(order.getId(), order); }

    @Override
    public Optional<Order> findById(OrderId orderId) {
        return Optional.ofNullable(store.get(orderId));
    }
}
```

### Testing Benefits — Swap Adapters

```java
// Unit test — no Spring, no DB, no SMTP
class PlaceOrderServiceTest {
    private final OrderRepository orderRepo = new InMemoryOrderRepository();
    private final NotificationPort notifier = mock(NotificationPort.class);
    private final PaymentPort payment = mock(PaymentPort.class);
    private final PlaceOrderUseCase useCase = new PlaceOrderService(orderRepo, notifier, payment);

    @Test
    void placeOrder_confirmsOrderAndNotifiesCustomer() {
        when(payment.charge(any(), any(), any())).thenReturn(PaymentResult.success("txn-123"));

        OrderId orderId = useCase.placeOrder(aValidCommand());

        assertThat(orderRepo.findById(orderId)).isPresent();
        verify(notifier).notifyOrderPlaced(any(), eq(orderId), any());
    }
}
// No @SpringBootTest, no TestContainers, no mocked HTTP — fast and focused
```

---

## Topic 13 — Testing Principles

### The Test Pyramid

```
              ╱╲
             ╱  ╲          E2E Tests
            ╱ E2E╲         (few, slow, costly, test full system)
           ╱──────╲
          ╱        ╲       Integration Tests
         ╱  INTEG.  ╲      (some, medium speed, test component interactions)
        ╱────────────╲
       ╱              ╲    Unit Tests
      ╱     UNIT       ╲   (many, fast, cheap, test single units in isolation)
     ╱──────────────────╲
```

| Level | Count | Speed | Purpose | Tools |
|-------|-------|-------|---------|-------|
| Unit | 70% | ms | Logic correctness | JUnit 5, Mockito |
| Integration | 20% | seconds | Component wiring | @SpringBootTest, TestContainers |
| E2E | 10% | minutes | User journey validation | Selenium, RestAssured |

---

### Test Doubles

```java
// ─── DUMMY ──── passed but never used (satisfies compiler/DI)
NotificationPort dummy = null; // or a no-op implementation

// ─── STUB ─────  provides canned answers to calls
public class StubUserRepository implements UserRepository {
    @Override
    public Optional<User> findById(Long id) {
        return Optional.of(new User(id, "test@example.com"));  // always returns same thing
    }
}

// ─── MOCK ─────  verifies interactions (with Mockito)
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {
    @Mock NotificationPort notificationPort;

    @Test
    void ship_sendsNotification() {
        orderService.ship(orderId);
        verify(notificationPort, times(1)).notifyShipped(eq(orderId));
    }
}

// ─── SPY ──────  wraps a real object, can verify calls AND delegate to real
@Spy
private List<String> spyList = new ArrayList<>();

@Test
void spy_delegatesToReal() {
    spyList.add("element");
    verify(spyList).add("element");        // verify the call
    assertThat(spyList).hasSize(1);        // real behaviour executed
}

// ─── FAKE ─────  working implementation with shortcuts (e.g. in-memory DB)
public class FakeOrderRepository implements OrderRepository {
    private final Map<OrderId, Order> store = new HashMap<>();

    @Override public void save(Order o) { store.put(o.getId(), o); }
    @Override public Optional<Order> findById(OrderId id) { return Optional.ofNullable(store.get(id)); }
    // No actual database — fast, but behaves like one for test purposes
}
```

---

### FIRST Principles

| Letter | Principle | Meaning |
|--------|-----------|---------|
| F | **Fast** | Tests run in milliseconds, not seconds |
| I | **Independent** | No test depends on another test's state |
| R | **Repeatable** | Same result every time, any environment |
| S | **Self-Validating** | Pass or fail — no manual inspection |
| T | **Timely** | Written just before the production code (TDD) |

---

### TDD — Red-Green-Refactor

```java
// ── RED: write a failing test ─────────────────────────────────────────────────
@Test
void calculateTax_appliesConfiguredRate() {
    var taxService = new TaxService(0.10);
    Money result = taxService.calculate(Money.of(100, "USD"));
    assertThat(result).isEqualTo(Money.of(10, "USD"));  // RED: TaxService doesn't exist yet
}

// ── GREEN: write the minimum code to pass ────────────────────────────────────
public class TaxService {
    private final double rate;
    public TaxService(double rate) { this.rate = rate; }

    public Money calculate(Money base) {
        return new Money(base.amount().multiply(BigDecimal.valueOf(rate)), base.currency());
    }
}
// Test passes — GREEN

// ── REFACTOR: improve without breaking ───────────────────────────────────────
public class TaxService {
    private final BigDecimal rate;

    public TaxService(double rate) {
        this.rate = BigDecimal.valueOf(rate).setScale(4, RoundingMode.HALF_UP);
    }

    public Money calculate(Money base) {
        BigDecimal taxAmount = base.amount()
            .multiply(rate)
            .setScale(2, RoundingMode.HALF_UP);
        return new Money(taxAmount, base.currency());
    }
}
// Still GREEN — precision improved, test unchanged
```

---

### Integration Test Example

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class OrderIntegrationTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15")
        .withDatabaseName("testdb");

    @DynamicPropertySource
    static void configure(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void placeOrder_returnsCreatedWithOrderId() {
        var request = new PlaceOrderHttpRequest(customerId, items, paymentMethod);

        ResponseEntity<PlaceOrderResponse> response = restTemplate
            .postForEntity("/api/v1/orders", request, PlaceOrderResponse.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody().orderId()).isNotNull();
    }
}
```

---

## Topic 14 — API Design Principles

### Cohesion & Coupling in APIs

**High cohesion:** An API surface exposes a coherent set of related operations. A `UserProfileApi` should only expose profile operations — not billing or authentication.

**Low coupling:** Callers depend on the API contract (interface), not the implementation. Changes to internal implementation should not require caller changes.

```java
// BAD — low cohesion, high coupling
@RestController
public class GodController {
    @GetMapping("/user/{id}") public User getUser(...) { ... }
    @PostMapping("/order") public Order placeOrder(...) { ... }
    @GetMapping("/product/{id}") public Product getProduct(...) { ... }
    @PostMapping("/payment") public Receipt pay(...) { ... }
}

// GOOD — high cohesion, clear boundaries
@RestController @RequestMapping("/api/v1/users")
public class UserController { ... }

@RestController @RequestMapping("/api/v1/orders")
public class OrderController { ... }

@RestController @RequestMapping("/api/v1/products")
public class ProductController { ... }
```

---

### API as a Product

An API is a product consumed by other developers. Design it for the **consumer**, not for your internal model.

```java
// BAD — API leaks internal structure (tight coupling to DB model)
@GetMapping("/orders/{id}")
public OrderEntity getOrder(@PathVariable Long id) {
    return orderRepository.findById(id).orElseThrow();  // returns JPA entity directly!
}

// GOOD — API contract is stable, independent of persistence model
@GetMapping("/orders/{id}")
public OrderResponse getOrder(@PathVariable Long id) {
    Order order = orderQueryService.findById(OrderId.of(id));
    return OrderResponseMapper.toResponse(order);  // maps domain → stable API DTO
}

// Stable API DTO — consumers depend on this, not the DB schema
public record OrderResponse(
    String orderId,
    String status,
    @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal total,
    String currency,
    List<OrderLineResponse> lines,
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss'Z'") LocalDateTime placedAt
) {}
```

---

### Backward Compatibility & Semantic Versioning

**SemVer:** `MAJOR.MINOR.PATCH`
- `PATCH`: bug fixes, no API change
- `MINOR`: new features, backward compatible (add optional fields, new endpoints)
- `MAJOR`: breaking changes (remove/rename fields, change semantics)

```java
// Strategy 1: URI versioning
@RequestMapping("/api/v1/users")  // stable v1
@RequestMapping("/api/v2/users")  // v2 with breaking changes

// Strategy 2: Header versioning
@GetMapping("/users/{id}")
public ResponseEntity<UserResponse> getUser(
    @PathVariable Long id,
    @RequestHeader(value = "Accept-Version", defaultValue = "v1") String version
) {
    return switch (version) {
        case "v2" -> ResponseEntity.ok(userServiceV2.getUser(id));
        default   -> ResponseEntity.ok(userServiceV1.getUser(id));
    };
}

// Strategy 3: Content-type negotiation
// Accept: application/vnd.myapi.v2+json
```

---

### Deprecation Strategy

```java
// Step 1: Mark as deprecated — communicate in API response
@GetMapping("/v1/users/{id}")
@Deprecated
public ResponseEntity<UserV1Response> getUserV1(@PathVariable Long id) {
    HttpHeaders headers = new HttpHeaders();
    headers.add("Deprecation", "true");
    headers.add("Sunset", "2025-12-31");  // RFC 8594 — when it will be removed
    headers.add("Link", "</api/v2/users/" + id + ">; rel=\"successor-version\"");
    return ResponseEntity.ok().headers(headers).body(userService.getUserV1(id));
}

// Step 2: Monitor usage of deprecated endpoint
@EventListener
public void on(DeprecatedEndpointCalledEvent event) {
    metricsService.increment("deprecated.endpoint.calls", "path", event.path());
    log.warn("Deprecated endpoint called: {} by client: {}", event.path(), event.clientId());
}

// Step 3: Remove after sunset date with proper migration guide in docs
```

---

### API Design Checklist

| Concern | Best Practice |
|---------|--------------|
| Naming | Nouns for resources, verbs for RPC (`/orders`, not `/getOrder`) |
| HTTP methods | GET (idempotent), POST (create), PUT (replace), PATCH (partial update), DELETE |
| Status codes | 200/201/204 for success; 400 for bad input; 404 for not found; 409 for conflict; 422 for validation; 500 for server error |
| Pagination | Cursor-based for large datasets; `?cursor=X&limit=20` |
| Filtering | `?status=ACTIVE&createdAfter=2024-01-01` |
| Error format | Consistent: `{ "code": "VALIDATION_ERROR", "message": "...", "details": [...] }` |
| Idempotency | `Idempotency-Key` header for POST mutations |
| Rate limiting | `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `Retry-After` headers |

---

## Topic 15 — Technical Debt

### Types of Technical Debt

| Type | Description | Example |
|------|-------------|---------|
| **Deliberate & Prudent** | "We know the right way, but we need to ship now" — documented, planned payback | TODO: refactor when we have time; using direct SQL instead of ORM for speed |
| **Deliberate & Reckless** | "We don't have time for design" — no plan to fix | Copy-pasting code, skipping tests, hardcoding credentials |
| **Inadvertent & Prudent** | "Now we know how we should have done it" — learned after the fact | Discovered that the service should be split after implementing it |
| **Inadvertent & Reckless** | Don't even know they're doing it wrong | Misusing transactions, ignoring thread safety |
| **Bit Rot** | Good code that decays as the surrounding system changes | Old integration code that no longer matches updated contract |

---

### Measuring Technical Debt

**Cyclomatic Complexity** — number of independent paths through a method. Higher = harder to test and maintain.

```java
// BAD — Cyclomatic Complexity: 8 (every branch adds 1)
public String classify(int score, boolean vip, String region) {
    if (score > 90) {                              // +1
        if (vip) {                                 // +1
            return "PLATINUM";
        } else {
            return "GOLD";
        }
    } else if (score > 70) {                       // +1
        if (region.equals("EU")) {                 // +1
            return "SILVER_EU";
        } else if (region.equals("US")) {          // +1
            return "SILVER_US";
        } else {
            return "SILVER";
        }
    } else if (score > 50) {                       // +1
        return vip ? "BRONZE_VIP" : "BRONZE";      // +1
    }
    return "STANDARD";
}
// Cyclomatic complexity = 8; target < 5 per method
```

```java
// GOOD — reduce complexity with strategy/table lookup
private static final List<ClassificationRule> RULES = List.of(
    new ClassificationRule(score -> score > 90 && vip,           "PLATINUM"),
    new ClassificationRule(score -> score > 90,                   "GOLD"),
    new ClassificationRule(score -> score > 70 && isEU(region),  "SILVER_EU"),
    new ClassificationRule(score -> score > 70 && isUS(region),  "SILVER_US"),
    new ClassificationRule(score -> score > 70,                   "SILVER"),
    new ClassificationRule(score -> score > 50 && vip,           "BRONZE_VIP"),
    new ClassificationRule(score -> score > 50,                   "BRONZE")
);

public String classify(int score, boolean vip, String region) {
    return RULES.stream()
        .filter(rule -> rule.matches(score, vip, region))
        .map(ClassificationRule::label)
        .findFirst()
        .orElse("STANDARD");
}
// Cyclomatic complexity = 1; each rule is independently testable
```

**Coupling metrics:**

```java
// Afferent coupling (Ca) — how many classes depend on this class
// High Ca = dangerous to change (ripple effect)

// Efferent coupling (Ce) — how many classes this class depends on
// High Ce = this class knows too much (fragile)

// Instability = Ce / (Ca + Ce)
// 0 = maximally stable (nothing depends on changing), 1 = maximally unstable

// Example: measure with tools like JDepend, ArchUnit
@AnalyzeClasses(packages = "com.example")
public class CouplingTest {
    @ArchTest
    static final ArchRule domainShouldNotDependOnInfrastructure =
        noClasses().that().resideInAPackage("..domain..")
                   .should().dependOnClassesThat()
                   .resideInAnyPackage("..infrastructure..", "..adapter..");
}
```

---

### Strategies to Manage Technical Debt

#### 1. Boy Scout Rule

```java
// When you open a file to make a change, leave it cleaner than you found it
// Don't do a massive refactor — just clean the immediate area

// You came to add a feature to processOrder:
public void processOrder(Order order) {
    // Before: validate() is 50 lines inline; extract it while you're here
    validateOrder(order);        // extracted — small, targeted improvement
    calculateTotals(order);
    orderRepository.save(order);
    notifyCustomer(order);
}
```

#### 2. Refactoring Sprints (Dedicated Debt Repayment)

```
Sprint planning:
  ┌─────────────────────────────────────────┐
  │  Technical Debt Backlog                 │
  │  ┌──────────────────────────────────┐   │
  │  │ [HIGH] UserService God Class     │   │
  │  │   Effort: 3 sprints              │   │
  │  │   Impact: -40% change fail rate  │   │
  │  ├──────────────────────────────────┤   │
  │  │ [MED] Replace magic strings      │   │
  │  │   Effort: 1 sprint               │   │
  │  │   Impact: -15% config bugs       │   │
  │  └──────────────────────────────────┘   │
  └─────────────────────────────────────────┘

Allocation: 20% of each sprint to debt (sustainable pace)
           or dedicated "debt sprint" every quarter
```

#### 3. Strangler Fig Pattern for Large Debt

```java
// Gradually replace legacy system — new functionality written in clean code
// Legacy code strangled over time, not rewritten all at once

@Component
public class OrderProcessingFacade {
    private final LegacyOrderService legacy;
    private final NewOrderService newService;

    @Value("${feature.new-order-processing:false}")
    private boolean useNewService;

    public OrderResult processOrder(Order order) {
        if (useNewService && isEligibleForNewService(order)) {
            return newService.processOrder(order);   // gradually migrate
        }
        return legacy.processOrder(order);           // fall back to legacy
    }
}
```

#### 4. Code Metrics Thresholds (enforce with CI)

```yaml
# .sonarqube.yml / SonarQube Quality Gate
quality_gate:
  conditions:
    - metric: code_smells
      operator: GREATER_THAN
      threshold: 100          # fail if > 100 new smells
    - metric: cognitive_complexity
      operator: GREATER_THAN
      threshold: 15           # per method
    - metric: duplicated_lines_density
      operator: GREATER_THAN
      threshold: 3            # max 3% duplication
    - metric: coverage
      operator: LESS_THAN
      threshold: 80           # min 80% test coverage on new code
    - metric: security_hotspots_reviewed
      operator: LESS_THAN
      threshold: 100
```

---

# Cheat Sheet — SOLID Principles & Clean Architecture

---

## 1. SOLID Principles Quick Reference

| Principle | One-Liner | Violation Example | Fix |
|-----------|-----------|-------------------|-----|
| **S** — SRP | One class, one reason to change | `UserService` handles auth, billing, reporting | Split into `AuthService`, `BillingService`, `ReportingService` |
| **O** — OCP | Open for extension, closed for modification | `if (type == "email") ... else if (type == "sms")...` | `NotificationStrategy` interface + implementors |
| **L** — LSP | Subtypes must be substitutable for base types | `Square extends Rectangle` breaks `setWidth` contract | Use composition; don't inherit just for reuse |
| **I** — ISP | Clients shouldn't depend on interfaces they don't use | `Worker` interface forces `Robot` to implement `eat()` | Split: `Workable`, `Feedable` interfaces |
| **D** — DIP | Depend on abstractions, not concretions | `OrderService` `new`s a `MySQLOrderRepository` | Inject `OrderRepository` interface |

---

## 2. Clean Architecture Layers (ASCII Diagram)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         FRAMEWORKS & DRIVERS                              │
│   Spring Boot · REST Controllers · JPA · Kafka · Redis · React · CLI     │
│ ┌────────────────────────────────────────────────────────────────────┐   │
│ │                    INTERFACE ADAPTERS                               │   │
│ │   Controllers · Presenters · Gateways · Repository Implementations │   │
│ │ ┌──────────────────────────────────────────────────────────────┐   │   │
│ │ │                   APPLICATION USE CASES                       │   │   │
│ │ │   PlaceOrderUseCase · GetOrderUseCase · CancelOrderUseCase   │   │   │
│ │ │ ┌──────────────────────────────────────────────────────┐     │   │   │
│ │ │ │              ENTERPRISE BUSINESS RULES               │     │   │   │
│ │ │ │   Order · Customer · Product · Money · OrderStatus   │     │   │   │
│ │ │ │         (Pure Java — no framework imports)           │     │   │   │
│ │ │ └──────────────────────────────────────────────────────┘     │   │   │
│ │ └──────────────────────────────────────────────────────────────┘   │   │
│ └────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘

Dependency Rule: arrows point INWARD ONLY
Inner layers know nothing about outer layers
```

---

## 3. Code Smell Quick Reference

| Smell | Symptom | Fix |
|-------|---------|-----|
| **Long Method** | Method > 20 lines; hard to name | Extract Method |
| **Large Class** | > 500 lines; many fields; multiple concerns | Extract Class, Move Method |
| **Feature Envy** | Method uses another class's data more than its own | Move Method to that class |
| **Primitive Obsession** | String for status; double for money; int for ID | Introduce Value Object / Replace Primitive with Object |
| **Data Clumps** | Same 3+ fields appear together everywhere | Extract Class; Introduce Parameter Object |
| **Shotgun Surgery** | One change forces edits in many unrelated classes | Move Method/Field; consolidate |
| **Divergent Change** | One class changes for many different reasons | Extract Class per axis of change |
| **Switch Statements** | `switch`/`if` chains on type code | Replace with Polymorphism / Strategy |
| **Parallel Inheritance** | Adding a subclass in one hierarchy requires one in another | Merge or use delegation |
| **Lazy Class** | Class does so little it doesn't justify its existence | Inline Class |
| **Speculative Generality** | Abstract hooks, params "just in case" | YAGNI — remove unused abstraction |
| **Temporary Field** | Field only set in some scenarios | Extract Class; use Optional |
| **Message Chains** | `a.b().c().d().e()` — Law of Demeter violation | Hide Delegate; add intermediary method |
| **Middle Man** | Class delegates everything to another class | Remove Middle Man; call directly |
| **Comments (as smell)** | Comment explains what the code does (not why) | Extract Method with meaningful name |

---

## 4. Design Principle Interaction Map

```
                    ┌──────────┐
                    │   SRP    │──────────────────────────────────┐
                    │ (1 reason│                                  │
                    │to change)│                                  │
                    └────┬─────┘                                  │
                         │ enables                                │ prevents
                         ▼                                        ▼
                    ┌──────────┐         ┌──────────┐       ┌──────────┐
                    │   OCP    │──────── ▶│ Strategy │       │ God      │
                    │(open/    │ uses     │ Pattern  │       │ Class    │
                    │ closed)  │         └──────────┘       │ Smell    │
                    └────┬─────┘                            └──────────┘
                         │ requires
                         ▼
                    ┌──────────┐                    ┌──────────────────┐
                    │   LSP    │                    │  Clean           │
                    │(Liskov   │◀───────────────────│  Architecture    │
                    │substitu- │  enforces correct  │  (Dependency     │
                    │  tion)   │  abstraction       │   Rule)          │
                    └────┬─────┘                    └────────┬─────────┘
                         │ guides                            │ separates layers
                         ▼                                   ▼
                    ┌──────────┐         ┌──────────┐  ┌──────────┐
                    │   ISP    │─────────▶│  Port    │  │Hexagonal │
                    │(interface│ defines  │Interface │  │Arch.     │
                    │segregat.)│          └──────────┘  └──────────┘
                    └────┬─────┘               ▲
                         │ enables             │ implements
                         ▼                     │
                    ┌──────────┐         ┌──────────┐
                    │   DIP    │─────────▶│Adapter   │
                    │(depend on│ realized │Pattern   │
                    │abstracts)│    by    └──────────┘
                    └──────────┘
                         │
                         │ facilitates
                         ▼
                    ┌──────────────────────────┐
                    │         CQRS             │
                    │  (separate command/query │
                    │   models per abstraction)│
                    └──────────────────────────┘
                              │
                              │ pairs with
                              ▼
                    ┌──────────────────────────┐
                    │      Event Sourcing      │
                    │  (commands → events →    │
                    │   state reconstruction)  │
                    └──────────────────────────┘

Key:
──▶  uses / requires
◀──  enables / informs
```

---

## 5. Interview Quick-Fire Reference

| Question | Answer in 1 sentence |
|----------|----------------------|
| CQRS in one line | Separate the model for writing state from the model for reading state |
| Event Sourcing in one line | Store a sequence of immutable events, not the current state; rebuild state by replay |
| Hexagonal in one line | Application core communicates with the outside world only through port interfaces, keeping it infrastructure-agnostic |
| TDD cycle | Red (failing test) → Green (minimum code to pass) → Refactor (improve without breaking) |
| Cyclomatic complexity | Number of linearly independent paths through a method; target ≤ 5 |
| Boy Scout Rule | Always leave the code a little cleaner than you found it |
| Strangler Fig | Gradually replace legacy by routing new features to new implementation until old code can be deleted |
| SemVer breaking change | Increment the MAJOR version; signal to consumers their code may break |

---

*End of Chapter 20 Part B — SOLID Principles & Clean Architecture*
*Volume 5: System Design & Low-Level Design*



