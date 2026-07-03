# Volume 5: System Design & Low-Level Design
# Chapter 20: SOLID Principles & Clean Architecture
---

## Table of Contents

| # | Topic |
|---|-------|
| 1 | Single Responsibility Principle (SRP) |
| 2 | Open/Closed Principle (OCP) |
| 3 | Liskov Substitution Principle (LSP) |
| 4 | Interface Segregation Principle (ISP) |
| 5 | Dependency Inversion Principle (DIP) |
| 6 | DRY, KISS, YAGNI |
| 7 | Clean Architecture |
| 8 | Domain-Driven Design (DDD) Basics |
| 9 | Code Smells & Refactoring |
| 10 | CQRS Pattern |
| 11 | Event Sourcing |
| 12 | Hexagonal Architecture (Ports & Adapters) |
| 13 | Testing Principles |
| 14 | API Design Principles |
| 15 | Technical Debt |

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: Single Responsibility Principle (SRP)

#### The Idea

Imagine a Swiss Army knife. It has a blade, a screwdriver, a corkscrew, scissors, and a toothpick all in one handle. It sounds convenient — until the blade breaks and the whole knife goes in for repair, even though the scissors were fine. Worse, every person who uses the knife has a say in its design: the chef wants a sharper blade, the electrician wants a bigger screwdriver, the sommelier wants a better corkscrew. Three different people, three different reasons to redesign the same tool.

A class in software is like that knife. When it tries to do too many things, every team that cares about any one of those things has a reason to crack it open and change it. The Single Responsibility Principle says: give each class exactly one reason to change. One owner. One concern.

In microservices, the same idea scales up: each service should own one business capability — Order Service, Payment Service, Inventory Service. If your Payment Service quietly started managing user profiles "for convenience," you now have a distributed Swiss Army knife. When the profile format changes, your Payment Service is on the operating table.

#### How It Works

**Detecting SRP violations — what to look for:**

```
Signs a class violates SRP:
  - Name contains "Manager", "Util", "Helper", or "Service" doing 10 unrelated things
  - Imports span persistence layer, HTTP layer, email, scheduling, and messaging
  - Unit test requires mocking 5+ collaborators
  - Unrelated feature changes keep landing in the same file
  - Class body exceeds ~200–300 lines
```

**Fixing it — the event-driven split:**

```
Before (God class):
  UserService.registerUser()
    → validates email
    → hashes password
    → saves to DB
    → sends welcome email
    → generates JWT
    → publishes Kafka event

After (each class has one reason to change):
  UserRegistrationService.register()
    → validates via UserValidator
    → creates User entity
    → saves to UserRepository
    → publishes UserRegisteredEvent

  UserWelcomeEmailHandler (listens for UserRegisteredEvent)
    → renders email template
    → sends via JavaMailSender

  JwtIssuingHandler (listens for UserRegisteredEvent)
    → generates and logs JWT
```

The must-memorise gotcha is how Spring's `ApplicationEventPublisher` achieves the split without coupling:

```java
// The one real-code block: event-driven SRP split in Spring
@Service
@RequiredArgsConstructor
public class UserRegistrationService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final UserValidator userValidator;
    private final ApplicationEventPublisher eventPublisher;

    public User register(RegisterUserCommand cmd) {
        userValidator.validate(cmd);
        User user = User.create(cmd.email(), passwordEncoder.encode(cmd.password()));
        userRepository.save(user);
        // publishes event — email, JWT, Kafka are NOT this class's concern
        eventPublisher.publishEvent(new UserRegisteredEvent(user.getId(), user.getEmail()));
        return user;
    }
}
```

Each listener (`UserWelcomeEmailHandler`, `KafkaEventPublisher`, etc.) is its own class with its own single reason to change. The registration service never imports `JavaMailSender` or `KafkaTemplate`.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is the Single Responsibility Principle?"**

**One-line answer:** A class should have one, and only one, reason to change.

**Full answer:**
> "SRP — Single Responsibility Principle — says every class should have exactly one reason to change. Robert Martin defined 'reason to change' as an *actor*: a stakeholder or system whose requirements drive modifications. If the UI team, the DBA team, and the business team all need to open the same class to make their respective changes, that class has three reasons to change and violates SRP. The fix is to split the class so each piece of it is owned by one concern — for example, separating persistence logic, notification logic, and business rules into distinct classes."

> *Deliver the 'actor' definition — interviewers love it because it's precise and shows you read Martin, not just a summary.*

**Gotcha follow-up:** *"Isn't breaking a class into many smaller ones just making the codebase harder to navigate?"*
> "That's the common tension. The trade-off is: more files, but each file is smaller, easier to test in isolation, and changes for one reason only. The navigation cost is solved by good package structure and naming. The maintenance cost of a God class — where a change to email logic breaks payment logic in the same file — is much higher long term."

---

**Tradeoff Question**
**"How do you identify that a class violates SRP in a real codebase?"**

**One-line answer:** If its unit test needs to mock five or more collaborators, it's doing too many things.

**Full answer:**
> "I look for a few signals. First, the name — classes called UserManager, TransactionHelper, or OrderServiceUtil are warning signs. Second, the import list — if a class imports from the persistence layer, the HTTP layer, the email library, and the messaging system all at once, it's touching four concerns. Third, the test setup: if a unit test requires mocking a database, a mail sender, a Kafka template, and a JWT utility before you can test the simplest behaviour, the class owns too many responsibilities. Fourth, the 'unrelated change' smell — if you find yourself opening the same class for changes that have nothing to do with each other, it's a God class."

> *The five-mock heuristic lands well — it's concrete and something the interviewer can verify in their own codebase.*

**Gotcha follow-up:** *"How does SRP apply to microservices?"*
> "In microservices, SRP maps to service decomposition. Each service should own one bounded business capability — meaning one business domain, with its own data store, its own deployment lifecycle. If a Payment Service also manages user profile data 'for convenience,' you have a distributed God class. The symptom is the same: multiple unrelated teams are opening the same service to make changes."

---

**Design Scenario**
**"A TransactionService has grown to 2,000 lines and handles fraud detection, ledger updates, notification dispatch, PDF receipt generation, and regulatory reporting. How do you refactor it?"**

**One-line answer:** Extract each concern into its own service and connect them via domain events.

**Full answer:**
> "I'd start by identifying the distinct actors — the fraud team, the accounting team, the compliance team, the customer-facing team. Each actor's concern becomes its own service: FraudDetectionService, LedgerService, NotificationService, ReceiptService, RegulatoryReportingService. Then I connect them with domain events rather than direct calls. The core TransactionService publishes a TransactionCompletedEvent. Each specialist service listens for that event and handles its slice. This way, when compliance mandates a new reporting format, only RegulatoryReportingService changes — the fraud logic is never touched."

> *Mention the domain event approach — it shows you know how to achieve SRP without introducing tight coupling between the new services.*

**Gotcha follow-up:** *"What's the risk of splitting too aggressively?"*
> "Over-splitting creates nano-services that are awkward to reason about and expensive to deploy. The right boundary is the 'actor' — if one stakeholder group drives changes to a unit, it belongs together. Splitting purely by line count or file size, without understanding ownership, produces fragmentation without the SRP benefit."

---

> **Common Mistake — Splitting by Layer, Not by Responsibility:** Putting all database code in one class and all HTTP code in another is layered architecture, not SRP. SRP is about the *reason to change* (the actor), not the *technical mechanism*. A class can span multiple technical layers as long as it serves one business responsibility.

> **Common Mistake — Mistaking SRP for "One Method per Class":** SRP does not mean tiny classes. A `UserRegistrationService` that validates, persists, and publishes an event is fine — all three actions are part of the single responsibility of registering a user. The test is: does one change require you to touch logic owned by a different stakeholder?

---

**Quick Revision:** Each class should have exactly one actor whose requirements can force it to change — any more and you have a God class.

---

## Topic 2: Open/Closed Principle (OCP)

#### The Idea

Think about a power strip with fixed slots. Every time you need to plug in a new device, an electrician has to cut into the wall and rewire the outlet. That is absurd — and dangerous, because touching live wiring risks breaking the existing outlets. Now imagine a power strip with a standard plug-and-socket design. Adding a new device means plugging it in; the strip itself never changes.

Software works the same way. The Open/Closed Principle says: once a piece of code is stable and tested, you should be able to add new behaviour by *plugging in* new code, not by cracking open the existing class and rewiring it. Open for extension (new plugs welcome), closed for modification (don't touch the wiring).

Every time you open a stable, tested class to add a feature, you risk breaking what was already working. The goal is to design the socket — the abstraction — so that new behaviour arrives as a new implementation, not as a change to the existing code.

#### How It Works

**The pattern that enables OCP — Strategy:**

```
1. Identify the behaviour that varies (e.g., discount calculation logic)
2. Extract an interface (DiscountStrategy) with one method (apply)
3. Each variant becomes its own implementing class
4. The context (DiscountCalculator) holds a collection of strategies
5. Adding a new discount type = writing a new class + registering it
   → zero changes to DiscountCalculator
```

**Spring's mechanism — auto-collecting strategy beans:**

```
Spring injects List<DiscountStrategy> automatically,
collecting every @Component that implements DiscountStrategy.
New strategy: annotate with @Component → Spring discovers it.
No modification to DiscountCalculator needed.
```

The must-memorise gotcha is the Spring bean collection pattern — this is what interviewers probe:

```java
// The one real-code block: OCP via Strategy + Spring bean collection
public interface DiscountStrategy {
    boolean supports(String discountType);
    double apply(Order order);
}

@Component
public class PercentageDiscountStrategy implements DiscountStrategy {
    @Override public boolean supports(String type) { return "PERCENTAGE".equals(type); }
    @Override public double apply(Order order)     { return order.getTotal() * 0.10; }
}

// Adding FlashSale: write this class, nothing else changes
@Component
public class FlashSaleDiscountStrategy implements DiscountStrategy {
    @Override public boolean supports(String type) { return "FLASH_SALE".equals(type); }
    @Override public double apply(Order order)     { return order.getTotal() * 0.30; }
}

@Service
@RequiredArgsConstructor
public class DiscountCalculator {
    // Spring injects ALL DiscountStrategy beans automatically
    private final List<DiscountStrategy> strategies;

    public double calculate(Order order, String discountType) {
        return strategies.stream()
            .filter(s -> s.supports(discountType))
            .findFirst()
            .map(s -> s.apply(order))
            .orElse(order.getTotal());
    }
}
```

**Tradeoff to know:**
- OCP is most valuable for stable, frequently-extended extension points (payment methods, discount types, report formats)
- Applying OCP everywhere up front is over-engineering — the "Rule of Three" heuristic: consider OCP after the second or third time you extend the same class

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is the Open/Closed Principle?"**

**One-line answer:** Software entities should be open for extension but closed for modification.

**Full answer:**
> "The Open/Closed Principle — OCP — says that once a class is stable and tested, you should be able to add new behaviour without opening that class and changing its code. 'Open for extension' means new behaviour is welcome. 'Closed for modification' means existing, tested code is not touched. The primary mechanism for achieving this is polymorphism: you define an abstraction — an interface or abstract class — and new behaviour arrives as a new implementation of that abstraction. The original class never changes."

> *Keep the definition crisp. Most interviewers want to hear 'open for extension, closed for modification' verbatim, then a mechanism.*

**Gotcha follow-up:** *"When is a switch statement an OCP violation?"*
> "When adding a new type requires you to find every switch statement that checks the type and add a new case to each one. If that switch is in one place, it might be acceptable. But if the pattern is scattered across ten files — a switch in the calculator, a switch in the validator, a switch in the formatter — then adding a new type means opening ten existing classes. That's a textbook OCP violation, and the fix is to replace the switches with polymorphism: each type becomes a class, and the behaviour lives inside the class."

---

**Tradeoff Question**
**"How do you implement OCP in a Spring Boot application?"**

**One-line answer:** Define a Strategy interface, implement it per variant as a Spring bean, and inject the full list into the context class.

**Full answer:**
> "The cleanest Spring idiom is the Strategy pattern with bean collection. You define an interface — say, PaymentStrategy — with a supports method and a process method. Each payment method — CreditCard, PayPal, UPI — becomes its own @Component implementing that interface. The PaymentProcessor service declares a constructor dependency on List<PaymentStrategy>. Spring automatically collects every bean that implements the interface and injects the list. Adding a new payment method means writing one new class and annotating it with @Component. The PaymentProcessor class is never touched. That is OCP in practice."

> *The 'Spring injects List<Interface>' pattern is the key detail — interviewers from Spring-heavy shops will probe exactly this.*

**Gotcha follow-up:** *"Should you always apply OCP up front?"*
> "No — applying OCP everywhere up front is over-engineering. The cost of a Strategy hierarchy is indirection: finding where the behaviour actually lives requires tracing through an interface and multiple implementations. I use a 'Rule of Three' heuristic: the first time I add a variant, I write it inline. The second time, I notice the pattern. The third time, I refactor to the Strategy pattern. OCP is most valuable at stable extension points you know will keep growing — payment methods, notification channels, discount types."

---

**Design Scenario**
**"A payment gateway originally supported only credit cards. Now PayPal, UPI, and crypto need to be added. The current PaymentProcessor is a big class with nested if-else blocks. How do you redesign it?"**

**One-line answer:** Extract a PaymentStrategy interface, move each payment method into its own class, and let Spring wire the collection.

**Full answer:**
> "I'd define a PaymentStrategy interface with two methods: supports(String paymentType) returning boolean, and process(PaymentRequest) returning PaymentResult. Then I extract the credit card logic into CreditCardPaymentStrategy, create PayPalPaymentStrategy, UpiPaymentStrategy, and CryptoPaymentStrategy as separate classes, each annotated with @Component. The PaymentProcessor becomes a thin orchestrator that holds a List<PaymentStrategy>, finds the one that supports the incoming payment type, and delegates to it. The processor itself is now closed for modification — adding the next payment method requires writing exactly one new class."

> *Draw the before/after class structure if on a whiteboard. The visual makes the OCP benefit obvious.*

**Gotcha follow-up:** *"What if two strategies both claim to support the same payment type?"*
> "That's a configuration bug, not an OCP flaw. You can guard against it with @Order annotations to establish priority, or with a startup validation check that asserts at most one strategy supports each type. The Strategy pattern doesn't prevent ambiguity — your wiring discipline does."

---

> **Common Mistake — Confusing OCP with "Never Change Existing Code":** OCP applies to *stable* code at *extension points*. When you find a bug, you fix the class. When you refactor, you change it. OCP is about not having to open stable, working code just to *add* new, unrelated behaviour.

> **Common Mistake — Switch Statements as a Red Flag in the Wrong Context:** Not every switch violates OCP. A single switch in one place that maps an enum to a value is fine. The violation is when the switch is duplicated across the codebase and every new type requires opening multiple existing files.

---

**Quick Revision:** Define an abstraction; new behaviour arrives as a new implementation — the original class is never opened.

---

## Topic 3: Liskov Substitution Principle (LSP)

#### The Idea

Imagine you order a "vehicle" from a rental agency. You expect it to accelerate when you press the gas, brake when you press the brake, and steer when you turn the wheel. The agency sends you a boat. It floats, it has an engine — technically it is a vehicle — but pressing the brake does nothing useful on water, and steering works completely differently. The rental agency violated your contract: you could not substitute their "vehicle" for what you expected.

Liskov Substitution Principle says exactly this: if S is a subtype of T, you must be able to use an S anywhere a T is expected, and the program must still behave correctly. A subclass that throws exceptions from methods the parent guaranteed would work, or that changes behaviour in a way that breaks the parent's contract, is a boat pretending to be a car.

The classic example in code is a Square extending a Rectangle. Geometrically, a square is a special rectangle — makes sense. But the Rectangle's contract says you can set width and height independently. A square cannot honour that contract: when you set the width, the height must also change. Any code written against Rectangle breaks when handed a Square.

#### How It Works

**The four LSP requirements for a valid subtype:**

```
A subclass must:
  1. Not strengthen preconditions  → accept at least what the parent accepts
  2. Not weaken postconditions     → guarantee at least what the parent guarantees
  3. Preserve invariants           → maintain the parent's established constraints
  4. Not add new checked exceptions → callers of the parent aren't prepared to handle them
```

**The Square-Rectangle violation visualised:**

```
Rectangle contract:
  setWidth(w)  → width = w, height unchanged
  setHeight(h) → height = h, width unchanged
  area()       → width * height

Square breaks the contract:
  setWidth(w)  → width = w, height = w  ← side-effect the caller doesn't expect
  setHeight(h) → height = h, width = h  ← same side-effect

Client code:
  resizeToDoubleWidth(Rectangle r):
    savedHeight = r.height         // 5
    r.setWidth(r.width * 2)        // expects height to stay 5
    assert r.area() == r.width * savedHeight
    // With Rectangle: 10 * 5 = 50  ✓
    // With Square:    10 * 10 = 100 ✗ — height silently changed
```

The must-memorise gotcha is the Java generics covariance trap — this is what senior-level interviewers probe:

```java
// The one real-code block: why List<Dog> is NOT a List<Animal> — the LSP + generics connection
List<Dog> dogs = new ArrayList<>();
// List<Animal> animals = dogs;  // DOES NOT COMPILE — and this is correct!

// If it compiled, this would corrupt the list:
// animals.add(new Cat());  // Cat is an Animal — but dogs list now contains a Cat!
// Dog d = dogs.get(0);     // ClassCastException at runtime

// The safe covariant read-only pattern (PECS: Producer Extends)
List<? extends Animal> animals = dogs;   // OK — covariant, read-only
Animal first = animals.get(0);           // safe read ✓
// animals.add(new Cat());               // COMPILE ERROR — can't write, type unknown ✓

// The safe contravariant write-only pattern (PECS: Consumer Super)
List<? super Dog> kennel = new ArrayList<Animal>();
kennel.add(new Dog());                   // safe write ✓
// Dog d = (Dog) kennel.get(0);          // unsafe read — not enforced by compiler
```

**Tradeoff:** Prefer composition over inheritance when the "is-a" relationship breaks substitutability. `Collections.unmodifiableList` wraps rather than extends `ArrayList` precisely because a "read-only ArrayList" cannot honour `add()` — wrapping avoids the LSP violation.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is the Liskov Substitution Principle?"**

**One-line answer:** Any subtype must be fully substitutable for its parent type without breaking the program's correctness.

**Full answer:**
> "LSP — Liskov Substitution Principle — says that if S is a subtype of T, every place in the program that expects a T must work correctly when handed an S instead. This means the subclass must honour the parent's *contract*: it cannot tighten the conditions required to call a method, it cannot weaken the guarantees the method makes, and it cannot throw exceptions the parent never declared. The subclass can do *more*, but it must not do *less* or *differently* in a way that breaks callers who were written against the parent."

> *Barbara Liskov's original 1987 definition is worth memorising: 'objects of type T may be replaced with objects of type S without altering any of the desirable properties of the program.'*

**Gotcha follow-up:** *"What is the Square-Rectangle problem?"*
> "It's the canonical LSP violation. Rectangle has a contract: you can set width and height independently. Square extends Rectangle, but a square's sides must always be equal, so overriding setWidth must also change height, and vice versa. Client code that calls setWidth on a Rectangle and expects height to be unchanged will get the wrong area when handed a Square. The fix is to not model Square as a subclass of Rectangle at all — use a common Shape interface instead, or make both immutable records. The lesson: geometric 'is-a' intuition does not always translate to safe inheritance."

---

**Tradeoff Question**
**"How does LSP relate to Java generics wildcards?"**

**One-line answer:** Generics are invariant by default to prevent LSP violations; wildcards opt into safe covariance or contravariance.

**Full answer:**
> "In Java, List<Dog> is not a subtype of List<Animal>, even though Dog is a subtype of Animal. This is intentional. If it were allowed, you could assign a List<Dog> to a List<Animal> variable and then call add(new Cat()) — a Cat is an Animal, so the compiler would accept it, but the underlying list is a List<Dog>, and you'd get a ClassCastException at runtime. That is heap pollution, an LSP violation at the type-system level. Java prevents it by making generics *invariant*. Wildcards let you opt into safe variance: List<? extends Animal> is covariant — you can read Animals from it, but you cannot add anything, because the compiler doesn't know the exact element type. List<? super Dog> is contravariant — you can add Dogs to it, but reads come back as Object. The mnemonic is PECS: Producer Extends, Consumer Super."

> *PECS is a frequent follow-up. State it proactively.*

**Gotcha follow-up:** *"Why does Collections.unmodifiableList wrap rather than extend ArrayList?"*
> "Because a read-only list cannot honour ArrayList's add() contract. If ReadOnlyList extended ArrayList and threw UnsupportedOperationException from add(), any code holding an ArrayList reference and calling add() would fail at runtime with the subtype. That is a direct LSP violation. Wrapping is the correct pattern: the wrapper presents its own interface — one where add() is legitimately not supported — without pretending to be a full ArrayList."

---

**Design Scenario**
**"You inherit a codebase where NotificationService has a subclass SilentNotificationService that overrides sendAlert() to do nothing. Is this an LSP violation?"**

**One-line answer:** Yes — callers of NotificationService who expect sendAlert() to send an alert will get silent failures with the subtype.

**Full answer:**
> "This is a textbook LSP violation called the 'do-nothing override.' The parent's contract — sendAlert() sends an alert — is weakened to a postcondition of 'might do nothing.' Any code that calls sendAlert() and then checks whether the alert was delivered will behave incorrectly with the subtype. The fix depends on intent. If SilentNotificationService is for testing, it should be a test double that never enters production code paths — that's fine. If it represents a legitimate 'opt-out' scenario in production, the correct design is a nullable or optional NotificationService, or a NullObject pattern where the interface explicitly documents that implementations may be no-ops."

> *The NullObject pattern is the clean production answer — name it explicitly.*

**Gotcha follow-up:** *"What's the difference between the Null Object pattern and a do-nothing override?"*
> "In the Null Object pattern, the no-op behaviour is *declared* as the contract of that specific implementation — it's not a surprise. Clients can be handed a NullNotificationService and know it does nothing, by design. With a do-nothing override on a subclass of NotificationService, clients are surprised: they asked for a NotificationService expecting alerts, and silently got nothing. The difference is whether the behaviour is documented and intentional at the type level."

---

> **Common Mistake — Treating Geometric Intuition as Inheritance Guidance:** "A square is a rectangle" is true in geometry but wrong in software if the Rectangle class has mutable width and height. LSP is about behavioural contracts, not real-world category membership.

> **Common Mistake — Throwing UnsupportedOperationException in a Subclass:** If a subclass overrides a method only to throw UnsupportedOperationException, the subclass is not substitutable for the parent. Prefer composition or a redesigned interface hierarchy over this pattern.

---

**Quick Revision:** A subtype must honour its parent's contract — if substituting it can break existing caller code, LSP is violated.

---

## Topic 4: Interface Segregation Principle (ISP)

#### The Idea

Picture a restaurant menu that is actually the entire company handbook: kitchen recipes, employee HR policies, supplier contracts, health inspection checklists, and the wine list — all in one document. You hand it to a customer who just wants to order dinner. They are forced to carry and page through hundreds of pages they will never use.

An interface in code is like that menu. If you create one giant interface with fifteen methods and force every class to implement all of them, most implementors end up writing stub methods that do nothing or throw errors — they are carrying pages they will never use. The Interface Segregation Principle says: break the big menu into small, role-specific menus. The customer gets the dinner menu. The sommelier gets the wine list. The chef gets the recipe book.

Spring's own framework is the best real-world example of ISP done right. The ApplicationContext is not one monolithic interface. It is a hierarchy of small, focused interfaces: BeanFactory for basic bean lookup, ListableBeanFactory for enumerating beans, ApplicationContext adding events and i18n, WebApplicationContext adding servlet context. Each client depends on only the slice it needs.

#### How It Works

**Detecting fat interface violations:**

```
Symptoms:
  - Implementing classes contain:
      throw new UnsupportedOperationException("not supported")
      or empty method bodies { }
  - Interface has 10+ methods with clearly unrelated clusters
  - Clients import the interface but call only 2 of its 15 methods
  - Changes to one method cluster force recompilation of all implementors
```

**Splitting a fat interface — the role-interface pattern:**

```
Before (fat):
  WorkerInterface:
    work(), eat(), sleep(), attendMeeting(), deployToProduction()

After (role interfaces):
  Workable:       work()
  Feedable:       eat(), sleep()
  Meetable:       attendMeeting()
  Deployable:     deployToProduction()

  HumanEngineer   implements Workable, Feedable, Meetable, Deployable
  RobotEngineer   implements Workable, Meetable, Deployable  // no Feedable needed
  Contractor      implements Workable, Meetable              // no Deployable access
```

The must-memorise gotcha is how Spring demonstrates ISP through its `BeanFactory` hierarchy — interviewers at Spring-heavy shops ask this directly:

```java
// The one real-code block: depend on the narrowest Spring interface
@Service
public class BeanInspector {
    // Wrong: depends on ApplicationContext — pulls in event publishing,
    //        i18n, resource loading, lifecycle — none of which we need
    // private final ApplicationContext ctx;

    // Right: ListableBeanFactory is the narrowest interface providing
    //        getBeanDefinitionNames() — that's all this class needs
    private final ListableBeanFactory beanFactory;

    public BeanInspector(ListableBeanFactory beanFactory) {
        this.beanFactory = beanFactory;
    }

    public String[] getAllBeanNames() {
        return beanFactory.getBeanDefinitionNames();
    }
}
```

**Spring ISP hierarchy for reference:**
```
BeanFactory
  └─ HierarchicalBeanFactory
       └─ ListableBeanFactory
            └─ ApplicationContext  (adds events, i18n, resources)
                 └─ ConfigurableApplicationContext  (adds lifecycle, refresh)
                      └─ WebApplicationContext  (adds servlet context)
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is the Interface Segregation Principle?"**

**One-line answer:** No client should be forced to depend on methods it does not use.

**Full answer:**
> "ISP — Interface Segregation Principle — says that large, general-purpose interfaces should be broken into small, role-specific ones. The problem with a fat interface is that every class implementing it must provide a body for every method, even methods irrelevant to that class. You end up with empty implementations or methods that throw UnsupportedOperationException — a lie that compiles. The fix is role interfaces: each interface captures one cohesive role. Implementing classes pick up only the interfaces that match their actual capabilities. Clients depend only on the slice they use."

> *The 'lie that compiles' phrase for UnsupportedOperationException lands well — it shows you understand why the pattern is harmful, not just that it violates a rule.*

**Gotcha follow-up:** *"How does Spring exemplify ISP in its own API?"*
> "Spring's ApplicationContext hierarchy is a textbook ISP example. At the root is BeanFactory — just basic bean lookup. ListableBeanFactory adds enumeration of all bean names. ApplicationContext adds event publishing, internationalisation, and resource loading. WebApplicationContext adds servlet context awareness. A class that only needs to list beans should depend on ListableBeanFactory, not ApplicationContext. Taking ApplicationContext when you only need BeanFactory violates ISP — and it makes testing harder because you drag in all the additional capability unnecessarily."

---

**Tradeoff Question**
**"What is the difference between ISP and SRP?"**

**One-line answer:** SRP is about why a class changes; ISP is about what a client is forced to depend on.

**Full answer:**
> "SRP — Single Responsibility Principle — governs classes: it says a class should have one reason to change, meaning one actor driving its modifications. ISP governs interfaces: it says clients should not be forced to depend on methods they don't use. They are related but distinct. A class can satisfy SRP — one responsibility — but still expose a fat interface that forces clients to import methods irrelevant to them. And you can have role-segregated interfaces where each interface's implementing class still violates SRP by doing too many things. In practice, applying both together produces the cleanest design: cohesive classes with narrow interfaces."

> *This distinction trips up a lot of candidates. Having a crisp comparison ready shows depth.*

**Gotcha follow-up:** *"Can you split interfaces too aggressively?"*
> "Yes. If you split to the point where every method is its own interface, you get interface explosion — dozens of one-method interfaces that are hard to discover and compose. The right granularity is the *role* or *client*. Ask: which clients exist, and what does each one actually call? Group the methods that always get called together into one interface. Splitting methods that are never called in isolation from each other adds indirection without benefit."

---

**Design Scenario**
**"You have a Document interface with methods: read(), write(), print(), fax(), scan(). A DigitalDocument class doesn't have a physical scanner or fax machine. How do you redesign?"**

**One-line answer:** Split into Readable, Writable, Printable, Faxable, Scannable role interfaces.

**Full answer:**
> "The fat Document interface forces DigitalDocument to either throw UnsupportedOperationException from fax() and scan() or leave them as empty bodies — both are lies. I'd split it into role interfaces: Readable with read(), Writable with write(), Printable with print(), Faxable with fax(), Scannable with scan(). DigitalDocument implements Readable and Writable. A physical all-in-one document handler implements all five. Clients that only read documents depend on Readable — they never see write(), print(), fax(), or scan(). When a method is added to Faxable, DigitalDocument is not affected at all."

> *On a whiteboard, draw the before/after class diagram — ISP benefits are visually obvious with a split hierarchy.*

**Gotcha follow-up:** *"What if most clients need all five operations most of the time?"*
> "Then the split may not be worth the cost. ISP is most valuable when clients have genuinely different subsets of needs. If every client calls all five methods, a single Document interface is appropriate. The principle warns against *forcing* clients to depend on what they don't use — if they use it all, there's no forcing."

---

> **Common Mistake — Implementing UnsupportedOperationException Instead of Splitting:** When you find yourself writing throw new UnsupportedOperationException() in an interface implementation, that is the ISP alarm going off. The right response is to split the interface, not to accept the lie.

> **Common Mistake — Depending on ApplicationContext When a Narrower Interface Suffices:** In Spring, injecting ApplicationContext when you only need BeanFactory or ListableBeanFactory violates ISP, makes the class harder to test, and couples it to the full application context lifecycle unnecessarily.

---

**Quick Revision:** Prefer many small, role-specific interfaces over one fat one — clients should depend only on what they actually use.

---

## Topic 5: Dependency Inversion Principle (DIP)

#### The Idea

Imagine a surgeon who can only operate with one specific brand of scalpel, manufactured by one specific supplier, delivered by one specific courier. If the supplier changes, the surgeon cannot work. If the courier is delayed, the operating room shuts down. The surgeon — a high-level professional — is directly dependent on low-level logistics.

Now imagine the hospital defines a standard for surgical instruments: size, sharpness, handle grip. Any supplier meeting the standard can supply the scalpels. The surgeon depends on the standard, not on any specific supplier. New suppliers can be swapped in without the surgeon changing anything about how they operate.

Dependency Inversion Principle is this insight applied to software. High-level modules — your business logic, your OrderService — should not depend directly on low-level modules like MySQLOrderRepository or StripePaymentGateway. Both should depend on an abstraction — an interface. The interface is the hospital's standard: any implementation that meets it can be plugged in. The business logic never knows which specific database or payment provider is wired up.

Hexagonal architecture — also called Ports and Adapters — is the full architectural expression of this idea. The domain layer defines Ports (interfaces). The infrastructure layer provides Adapters (implementations). The domain never imports from infrastructure. DIP, enforced at architectural scale.

#### How It Works

**The two statements of DIP:**

```
1. High-level modules should not depend on low-level modules.
   Both should depend on abstractions (interfaces).

2. Abstractions should not depend on details.
   Details (concrete implementations) should depend on abstractions.
```

**Constructor injection vs field injection — the DIP relevance:**

```
Constructor injection:
  + Dependencies declared as final → immutable
  + Missing dependency = compile-time error (can't call new without it)
  + Testable with plain new in unit tests — no Spring container needed
  + Spring detects circular dependencies eagerly, at startup

Field injection (@Autowired on a field):
  - Dependencies hidden inside the class — callers can't see them
  - Cannot be final
  - Missing dependency = NullPointerException at runtime
  - Unit tests require Spring container or reflection hacks
  - Circular dependencies silently proxied by Spring
```

**Hexagonal architecture and DIP:**

```
Domain layer (high-level):
  Defines: OrderRepository (interface), PaymentGateway (interface)
  Never imports: JPA, JDBC, Stripe SDK, SMTP library

Infrastructure layer (low-level):
  Implements: JpaOrderRepository, StripePaymentGateway, SmtpEmailNotificationService
  Imports: the domain interfaces

Spring (wiring layer):
  At startup: injects JpaOrderRepository where OrderRepository is declared
  → swapping database = change one @Bean definition, zero domain changes
```

The must-memorise gotcha is the constructor injection pattern that enables plain-new unit testing:

```java
// The one real-code block: constructor injection + pure unit test without Spring
@Service
public class OrderService {
    private final OrderRepository orderRepository;       // interface — not MySQL
    private final EmailNotificationService emailService; // interface — not SMTP
    private final PaymentGateway paymentGateway;        // interface — not Stripe

    // Constructor injection: dependencies explicit, final, testable
    public OrderService(OrderRepository orderRepository,
                        EmailNotificationService emailService,
                        PaymentGateway paymentGateway) {
        this.orderRepository = orderRepository;
        this.emailService    = emailService;
        this.paymentGateway  = paymentGateway;
    }
}

// Pure unit test — no @SpringBootTest, no container, no mocking framework required
class OrderServiceTest {
    @Test
    void placeOrder_chargesAndPersists() {
        var service = new OrderService(
            new InMemoryOrderRepository(),
            new NoOpEmailService(),
            new FakePaymentGateway(PaymentResult.success("txn-123"))
        );
        var confirmation = service.placeOrder(TestFixtures.validOrderCommand());
        assertThat(confirmation.transactionId()).isEqualTo("txn-123");
    }
}
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is the Dependency Inversion Principle?"**

**One-line answer:** High-level business logic should depend on interfaces, not on concrete implementations.

**Full answer:**
> "DIP — Dependency Inversion Principle — has two parts. First: high-level modules, meaning your business logic, should not import or instantiate low-level modules, meaning your database repositories, email senders, or payment SDKs, directly. Both should depend on an abstraction — an interface. Second: the interface itself should be defined by the high-level module's needs, not shaped by the low-level module's capabilities. In practice: your OrderService declares what it needs as interfaces — OrderRepository, PaymentGateway, EmailNotificationService. The infrastructure layer provides implementations. Spring wires the implementations to the interfaces at startup. The business logic never knows whether it is talking to MySQL or PostgreSQL, Stripe or PayPal."

> *The 'interface defined by the high-level module's needs' distinction is subtle but important — name it if the interview feels senior-level.*

**Gotcha follow-up:** *"What is Dependency Injection, and how does it relate to DIP?"*
> "DIP is the principle: depend on abstractions. Dependency Injection — DI — is the mechanism that implements it: instead of a class creating its own dependencies with new, the dependencies are provided from the outside, typically through the constructor. Spring is a DI container: it knows which implementations exist, reads your constructor signatures, and wires the right implementations in. DIP tells you *what* to depend on; DI tells you *how* to receive the dependency."

---

**Tradeoff Question**
**"Why is constructor injection preferred over field injection with @Autowired?"**

**One-line answer:** Constructor injection makes dependencies explicit, final, and testable without a Spring container.

**Full answer:**
> "Field injection — @Autowired on a private field — hides dependencies. If I look at the class signature, I have no idea what it needs. It cannot be marked final, so nothing prevents accidental reassignment. If Spring fails to wire a dependency, the failure happens at runtime as a NullPointerException, not at the compile stage. And if I want to unit test the class, I either spin up the whole Spring container — slow — or use reflection to inject the field — fragile. Constructor injection solves all of these: every dependency appears in the constructor signature, can be final, fails at compile time if missing, and allows plain new in tests with any implementation I choose."

> *The 'plain new in unit tests' argument is the strongest one for engineering-focused interviewers. Lead with it.*

**Gotcha follow-up:** *"Are there cases where field injection is acceptable?"*
> "In test classes — @Autowired in @SpringBootTest or @DataJpaTest is fine because the test itself needs the container. In configuration classes where the injection is essentially a wiring declaration, it's a minor style point. But in application service classes and domain components that should be unit-testable, constructor injection is the right default."

---

**Design Scenario**
**"Your OrderService directly instantiates MySQLOrderRepository, StripePaymentGateway, and SmtpEmailSender. A new requirement needs to support PostgreSQL and PayPal. How do you redesign?"**

**One-line answer:** Extract interfaces for each dependency, inject them via constructor, and provide new implementations — zero changes to OrderService.

**Full answer:**
> "The current design has OrderService coupled to three specific technologies. To apply DIP, I define three interfaces based on what OrderService actually needs: OrderRepository with save and findById, PaymentGateway with charge, and EmailNotificationService with sendOrderConfirmation. The existing MySQLOrderRepository and StripePaymentGateway implement these interfaces. New JpaOrderRepository, PostgreSQLOrderRepository, and PayPalPaymentGateway also implement them. OrderService's constructor takes the three interfaces. The Spring configuration — a @Configuration class or @Bean methods — decides which implementation to inject. Adding PostgreSQL support means writing JpaOrderRepository and updating one @Bean definition. OrderService is never touched."

> *Explicitly call out that the @Configuration class is the only thing that changes when swapping implementations — this demonstrates you understand where the coupling now lives.*

**Gotcha follow-up:** *"What is hexagonal architecture, and how does it relate to DIP?"*
> "Hexagonal architecture — also called Ports and Adapters — is DIP applied at the architectural level. The domain layer, containing business logic, defines Ports: interfaces for everything it needs from the outside world — persistence, messaging, external APIs. The infrastructure layer provides Adapters: concrete implementations of those ports. The critical rule is that the domain never imports from infrastructure. Only infrastructure imports from domain. Spring acts as the wiring layer that connects adapters to ports at startup. Swapping a database or a payment provider means replacing an adapter — the domain is untouched."

---

> **Common Mistake — Injecting Concrete Classes Instead of Interfaces:** `@Autowired private MySQLOrderRepository repo` defeats DIP entirely. If the field type is a concrete class, you cannot swap implementations without changing the class. Always declare the field type as the interface.

> **Common Mistake — Field Injection in Domain Services:** Using @Autowired field injection in core business services makes them impossible to unit test without a Spring container. This hidden coupling slows the test suite and ties the domain to the framework — exactly what DIP and hexagonal architecture are designed to prevent.

---

**Quick Revision:** Business logic depends on interfaces it defines; infrastructure provides implementations — swap the infrastructure without touching the logic.

---

## Topic 6: DRY, KISS, YAGNI

#### The Idea

Imagine a law firm where the same contract clause is typed out in full across fifty different documents. When the law changes, someone has to find and update all fifty copies. Miss one and you have a legal liability. DRY — Don't Repeat Yourself — is the software equivalent of that lesson: every piece of business knowledge should live in exactly one place so there is one thing to update, one thing to test, and one place to be wrong.

KISS (Keep It Simple, Stupid) is the counterforce that stops you from over-engineering. When you have two cases to handle, a simple switch is better than a strategy-pattern class hierarchy. The most maintainable code is the code that does not exist at all.

YAGNI (You Ain't Gonna Need It) extends KISS across time: do not build the caching layer before you have measured a performance problem, do not design for ten thousand tenants when you have two. Every speculative feature is future maintenance weight carried on a bet that may never pay off.

#### How It Works

The three principles work together as a system:

```
DRY: when you see the same business rule in two places
  → ask: "is this one rule expressed twice, or two different rules that look alike?"
  → if one rule: extract it to a single authoritative home
  → if two rules: leave them separate — they will diverge

KISS: when choosing between two implementations
  → pick the one that requires the least explanation
  → prefer built-in constructs over custom abstractions
  → a method under 20 lines almost always fits on one screen — aim for that

YAGNI: before adding a new capability
  → does a real, current requirement justify this?
  → if the answer is "we might need it someday" — stop, do not build it
  → revisit when the requirement is actual
```

The hardest trap is **premature DRY**: merging two code blocks because they look identical today, when they represent different concepts that will diverge tomorrow. The rule of three helps — wait until you see the same pattern three times before abstracting it.

```java
// The one must-memorise gotcha: DRY is about knowledge, not text.
// Two methods with identical code but DIFFERENT business concepts → do NOT merge.
// Two methods with DIFFERENT code but the SAME business rule → they DO violate DRY.

// BAD: same shipping threshold in two places — one business rule, two homes
public class OrderService {
    public double calculateShipping(Order order) {
        if (order.getTotal() > 100.0) return 0.0;          // threshold here
        return order.getWeightKg() * 2.5;
    }
}
public class CartService {
    public double estimateShipping(Cart cart) {
        if (cart.getTotal() > 100.0) return 0.0;           // same threshold duplicated
        return cart.getTotalWeightKg() * 2.5;
    }
}

// GOOD: single authoritative source — change the threshold once, everywhere picks it up
@Component
public class ShippingCalculator {
    private static final double FREE_SHIPPING_THRESHOLD = 100.0;
    private static final double RATE_PER_KG = 2.5;

    public Money calculate(Money orderTotal, double weightKg) {
        if (orderTotal.isGreaterThan(Money.of(FREE_SHIPPING_THRESHOLD))) return Money.ZERO;
        return Money.of(weightKg * RATE_PER_KG);
    }
}
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What does DRY actually mean — isn't it just about avoiding copy-paste?"**

**One-line answer:** DRY is about not duplicating *knowledge* — a business rule — not just duplicating text.

**Full answer:**
> "DRY stands for Don't Repeat Yourself, and the common misreading is that it means never having two methods with the same code. The real definition is narrower and more precise: every piece of business knowledge should have a single authoritative representation. Two methods can share identical code and not violate DRY if they represent genuinely different business concepts that happen to look alike today but will diverge tomorrow. Conversely, two methods with completely different code can violate DRY if they both independently encode the same business rule — like a shipping threshold of £100 — because when that rule changes you now have two places to update, and you will likely miss one. I have seen this exact bug in production: two teams independently calculated transaction fees, the fee structure changed, one team updated their code, the other did not, and the mobile app showed wrong fees for three days."

> *Deliver the production story with a brief pause before it — interviewers remember concrete failures.*

**Gotcha follow-up:** *"So when should you NOT apply DRY?"*
> "When you would be creating the wrong abstraction. Sandi Metz put it well: duplication is far cheaper than the wrong abstraction. The rule of three helps here — wait until you see the same pattern appear three times before extracting it. The classic failure mode is two methods that look identical, you merge them into one with a boolean flag parameter like `validate(data, isRegistration)`, and now you have a method with branching internal logic that handles two different workflows. Those two workflows will diverge. When they do, that flag grows into a switch statement, and you end up with something far harder to change than the original duplication."

---

**Tradeoff Question**
**"When does YAGNI conflict with good architecture, and how do you navigate that tension?"**

**One-line answer:** YAGNI applies to features and capabilities, not to foundational design decisions like separating layers or writing tests.

**Full answer:**
> "YAGNI — You Ain't Gonna Need It — says don't implement things before they are actually required. The tension with architecture is real: if I'm building a service today, should I design it to be multi-tenant on day one even though I only have one customer? YAGNI says no. But YAGNI doesn't mean skip your service layer, collapse your abstractions, or skip writing tests because you might refactor later. The line I draw: YAGNI applies to *features* and *infrastructure* — caching layers, event buses, multi-tenancy, internationalisation. It does not apply to *structural* decisions like separating concerns, keeping your domain logic framework-free, or writing a clean interface over an external dependency. A clean interface costs almost nothing to add and saves you enormously when you swap implementations. A full event bus before you have any consumers is just inventory you have to maintain."

> *Pause after the one-line answer. If the interviewer nods, give the line about where you draw the boundary.*

**Gotcha follow-up:** *"Give me an example of a YAGNI violation you've seen or would flag in a code review."*
> "A common one: a developer adds a pluggable caching abstraction with a Cache interface, a NoOpCache implementation, a RedisCache implementation, and a factory — before any profiling has shown a performance problem. The code now has four new files, a configuration property to choose the implementation, and test stubs for all of it. If performance ever becomes a problem, a simple Spring Cache annotation on the method would solve it in two lines. The abstraction was built for a problem that may never exist, and in the meantime it's dead weight that new team members have to understand."

---

**Design Scenario**
**"I see two services with near-identical validation logic. Should I extract a shared validator?"**

**One-line answer:** Only if they represent the same business rule — check whether they will stay in sync or diverge over time.

**Full answer:**
> "The question I ask first is: are these two pieces of validation encoding the same business invariant, or do they just look similar today? If it's the same rule — say, both services check that an email address is syntactically valid — then yes, extract a shared EmailValidator. That is a single fact about the world and it should live in one place. But if one is validating user registration — which includes checking the email is unique in the database and the password meets complexity requirements — and the other is validating a profile update — which has different required fields and different constraints — then they should stay separate even if eighty percent of the code looks identical. The moment you merge them with a flag parameter, you have coupled two workflows that have different owners and different change rates. I would leave the duplication, accept the similarity, and let them evolve independently."

> *This answer shows you understand the deeper principle, not just the rule. Interviewers at mid-to-senior level are probing for exactly this nuance.*

**Gotcha follow-up:** *"What's the 'wrong abstraction' problem?"*
> "It's what happens when you apply DRY too eagerly. You see two similar code blocks, merge them, and the merged version needs a parameter to switch between the two behaviours. Over time more callers arrive with slightly different needs, more parameters get added, and the method grows into a conditional maze that is doing five different things. At that point the duplication you saved is dwarfed by the complexity you created. The fix is often to delete the abstraction and go back to duplication — then re-abstract more carefully once you can see the actual shared shape across three or more real examples."

---

> **Common Mistake — Merging validators with a boolean flag:** Extracting two different workflows into one method with an `isRegistration`-style flag parameter defeats the purpose of DRY. You have removed textual duplication but created conceptual coupling. When the workflows diverge — and they will — you will be modifying a method that affects both paths, making every change riskier and every test more complex.

---

**Quick Revision:** DRY eliminates duplicated *knowledge* (one business rule, one home), KISS prefers the simplest working solution, and YAGNI stops you building features before they are genuinely needed.

---

## Topic 7: Clean Architecture

#### The Idea

Think of a hospital. The doctors — the core experts — do not need to know which brand of MRI machine is installed, whether patient records are stored on paper or in a cloud system, or which insurance billing software is running. Their medical knowledge is the heart of the hospital, and it must work regardless of the surrounding equipment. If a better MRI machine arrives, you replace the machine; the doctors' expertise does not change.

Clean Architecture works the same way. Your business logic — the rules about what constitutes a valid order, how discounts are applied, when a payment is considered successful — sits at the centre. The frameworks, databases, HTTP layers, and message queues sit at the outside. The rule is: the centre never knows about the outside. The outside knows about the centre and adapts to it.

This is a deliberate inversion from traditional layered architecture, where the domain layer typically imports JPA annotations, Spring beans, and database types. In Clean Architecture, the domain is pure Java. The infrastructure (JPA, Spring, Kafka) depends on the domain through interfaces — not the other way round. The payoff: you can test every business rule with plain unit tests, no application container required, and you can swap your entire persistence layer without touching a single domain class.

#### How It Works

```
Four concentric layers, outermost wraps innermost:

Layer 1 — Entities (innermost):
  Pure domain objects. No @Entity, no @JsonProperty, no Spring.
  Change only when fundamental business rules change.

Layer 2 — Use Cases:
  Orchestrate entities to fulfill one user goal.
  Define outbound Ports (interfaces) that the infrastructure will implement.
  No knowledge of HTTP, SQL, or Kafka.

Layer 3 — Interface Adapters:
  Controllers (HTTP → use case command)
  Gateways (use case port → actual DB/API call)
  Translate between use-case language and external formats.

Layer 4 — Frameworks & Drivers (outermost):
  Spring Boot, Hibernate, PostgreSQL, Kafka.
  Pure configuration — wire everything together.

Dependency Rule:
  Source code dependencies point INWARD only.
  Layer 4 may import Layer 3. Layer 3 may import Layer 2.
  Layer 2 NEVER imports Layer 3 or 4.
  Layer 1 NEVER imports anything outside itself.
```

The single must-memorise pattern is how the Dependency Inversion works for persistence:

```java
// Layer 2 (Use Case) defines the port as an interface — it owns the contract
public interface OrderRepository {          // lives in the application layer
    void save(Order order);
    Optional<Order> findById(OrderId id);
}

// Layer 2 (Use Case) depends on the interface — never on JPA
@UseCase
public class PlaceOrderService implements PlaceOrderUseCase {
    private final OrderRepository orderRepository;   // injected — could be JPA, in-memory, anything
    private final PaymentGateway paymentGateway;

    public OrderId execute(PlaceOrderCommand cmd) {
        Order order = Order.create(IdGenerator.generate(), cmd.customerId(), cmd.items());
        PaymentResult payment = paymentGateway.charge(cmd.customerId(), order.getTotal(), cmd.paymentToken());
        if (!payment.isSuccessful()) throw new PaymentFailedException(payment.errorCode());
        order.confirm();
        orderRepository.save(order);
        return order.getId();
    }
}

// Layer 3 (Adapter) implements the port — all JPA/Spring lives here
@Repository
public class JpaOrderRepositoryAdapter implements OrderRepository {  // implements domain port
    private final SpringDataOrderRepository springDataRepo;          // uses Spring Data internally

    @Override
    public void save(Order order) {
        springDataRepo.save(OrderEntity.from(order));   // maps domain → JPA entity
    }

    @Override
    public Optional<Order> findById(OrderId id) {
        return springDataRepo.findById(id.value())
                             .map(OrderEntity::toDomain);  // maps JPA entity → domain
    }
}
// Swap Hibernate for JDBC: write a new JdbcOrderRepositoryAdapter. PlaceOrderService: unchanged.
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is Clean Architecture and what problem does it solve?"**

**One-line answer:** Clean Architecture keeps your business logic framework-free by enforcing that all source code dependencies point inward toward the domain.

**Full answer:**
> "Clean Architecture, introduced by Robert C. Martin, organises code into concentric rings: the domain entities at the centre, use cases around them, interface adapters next, and frameworks at the outer edge. The single rule is that source code dependencies point inward only — an inner layer never imports anything from an outer layer. The problem it solves is framework coupling. In a traditional Spring application, your domain classes are annotated with @Entity, they import javax.persistence, their behaviour is tested by starting a full Spring context. The domain is coupled to Hibernate. If you want to switch to a document database, or test your business rules without a container, you can't. Clean Architecture inverts this: the domain is pure Java, the infrastructure implements interfaces the domain defines. The domain tests run in milliseconds with no container. When Netflix migrated from REST to gRPC and from Cassandra to a custom store, their domain logic was untouched because it had no knowledge of the transport or persistence layers."

> *The Netflix example lands well — it shows the payoff is real, not theoretical.*

**Gotcha follow-up:** *"What is the Dependency Inversion Principle and how does it make this possible?"*
> "The Dependency Inversion Principle says that high-level modules — your business logic — should not depend on low-level modules — your database or HTTP framework. Both should depend on abstractions. In practice: the use case layer defines an interface called OrderRepository. The use case depends on that interface — it calls save() and findById(). The JPA adapter in the infrastructure layer implements OrderRepository. So the dependency arrow points from infrastructure inward to the domain interface, not from the domain outward to JPA. This is what makes the domain testable in isolation: you inject an in-memory fake OrderRepository in your unit tests. No Spring context, no database, no network — your business rules run and verify in milliseconds."

---

**Tradeoff Question**
**"When would you NOT use Clean Architecture?"**

**One-line answer:** For simple CRUD services or short-lived prototypes, the overhead of ports and adapters outweighs the benefit.

**Full answer:**
> "Clean Architecture has real costs. Every external interaction needs a port interface in the application layer and an adapter in the infrastructure layer. Mapping between domain objects and JPA entities adds code. The package structure is more complex than a simple controller-service-repository split. For a straightforward CRUD API — a configuration service, an internal reporting endpoint, a prototype — this overhead is not justified. The benefit of Clean Architecture is that it protects a rich domain model from framework churn and makes complex business rules unit-testable. If there is no rich domain model — just CRUD — there is nothing to protect. I would use traditional layered architecture with Spring Data repositories directly for CRUD apps, and reach for Clean Architecture when the domain has real invariants, complex workflows, and a lifecycle longer than one or two years."

> *Interviewers respect trade-off thinking. The candidate who says 'use Clean Architecture everywhere' has not shipped production code.*

**Gotcha follow-up:** *"How do you handle the mapping cost between domain objects and JPA entities?"*
> "The mapping is the most common complaint against Clean Architecture and it is legitimate — you end up with an Order domain class, an OrderEntity JPA class, and a mapper between them. The tradeoff is that the domain object is clean: no @Column annotations, no nullable fields forced by the ORM, no equals/hashCode dictated by Hibernate. My approach in practice: keep the mappers simple — static factory methods like OrderEntity.from(Order) and OrderEntity.toDomain(). If the mapping becomes complex enough that it feels painful, that is usually a signal the domain model and persistence model have genuinely different shapes — which is fine, they often should. The alternative — putting @Entity on your domain object — is worse: you have now let Hibernate dictate your domain design."

---

**Design Scenario**
**"Walk me through how a PlaceOrder request flows through a Clean Architecture system."**

**One-line answer:** HTTP → Controller translates to a command → Use Case enforces invariants → Adapter persists → Response mapped back.

**Full answer:**
> "The request arrives at the OrderController in the interface adapter layer — Layer 3. The controller translates the raw HTTP request body into a PlaceOrderCommand, a plain data object with no HTTP types in it — just customerId, a list of order lines, and a payment token. It calls PlaceOrderUseCase.execute(cmd). The use case — PlaceOrderService in Layer 2 — creates an Order domain object, calls the PaymentGateway port to charge the card, calls order.confirm() to enforce the state transition invariant, then calls OrderRepository.save(order). Both PaymentGateway and OrderRepository are interfaces defined in Layer 2. At runtime, Spring injects the JPA adapter for OrderRepository and the Stripe adapter for PaymentGateway — both from Layer 3. The use case returns an OrderId. The controller maps that to an HTTP 201 Created response. At no point does the use case import anything from Spring, Hibernate, or Stripe — it only depends on its own ports."

> *Draw this on a whiteboard if given the opportunity — concentric circles with arrows pointing inward are immediately clear.*

**Gotcha follow-up:** *"Where do domain events fit in this architecture?"*
> "Domain events — things like OrderPlaced or PaymentProcessed — are raised inside the domain or use case layer and consumed by other use cases or adapters. The event itself lives in the domain layer: it is a plain Java record with no framework types. The use case can publish it via an EventPublisher port — an interface defined in Layer 2. The actual Spring ApplicationEventPublisher implementing that port lives in Layer 3. Event handlers in other bounded contexts live in their own adapters. This keeps the domain oblivious to how events are dispatched — in tests you use a fake EventPublisher that records published events for assertion."

---

> **Common Mistake — Putting @Entity on domain objects:** Annotating your domain classes directly with @Entity and @Column is the most common violation of Clean Architecture in Spring Boot projects. It couples your domain model to Hibernate: you cannot easily rename fields, add validation annotations, or change nullability without Hibernate constraints interfering. It also means your domain unit tests must load a JPA context. Maintain a separate JPA entity class in the adapter layer and map between them — the cost is small, the isolation benefit is large.

---

**Quick Revision:** Clean Architecture keeps business logic in a framework-free centre by making infrastructure implement domain-defined interfaces, so the Dependency Rule — all source code dependencies point inward — is never broken.

---

## Topic 8: Domain-Driven Design (DDD) Basics

#### The Idea

Imagine you are building software for a hospital. The word "patient" means something very specific to the billing department — an account holder with an insurance policy and outstanding invoices. The same word means something completely different to the surgical team — a person on a table with vitals and a procedure in progress. If you build one single "Patient" class shared across both departments, you end up with a class that tries to satisfy both worlds: it has insurance fields that the surgeons never touch, and it has intraoperative notes that billing never needs. Worse, when the billing team wants to rename a field, they break the surgical team's code.

Domain-Driven Design (DDD) says: align your software model with the real-world domain it represents, work closely with the people who know that domain (the domain experts), and use the same language in code that those experts use in conversation. If a billing expert says "a patient's account is written off," your code should have a writeOff() method on a BillingAccount — not a setStatus("WRITTEN_OFF") call on a shared Patient record.

DDD also gives you strategic tools to manage the size problem. Large domains are divided into Bounded Contexts — explicit boundaries inside which one vocabulary and one model applies. "Customer" in the Sales context is a prospect with a pipeline stage. "Customer" in the Shipping context is a delivery address. They are different models for different purposes, each owned by a different team, and they communicate through well-defined events rather than sharing a database table.

#### How It Works

```
Tactical DDD building blocks:

Entity:
  Has a unique identity (UUID). Identity persists through state changes.
  Two entities are equal if their IDs are equal, even if all other fields differ.
  Examples: Customer, Order, Product.

Value Object:
  Has no identity. Defined entirely by its attribute values.
  Immutable — operations return new instances.
  Two value objects are equal if all their fields are equal.
  Examples: Money, Address, EmailAddress, DateRange.

Aggregate:
  A cluster of Entities and Value Objects treated as one consistency unit.
  Has one Aggregate Root — the single entry point for all external operations.
  Rules:
    1. External objects reference the aggregate only through the root.
    2. External aggregates reference each other by ID only — never by direct object reference.
    3. One aggregate = one transaction (no cross-aggregate transactions).
    4. All invariants within the aggregate are consistent after every transaction.

Repository:
  Provides collection-like access to aggregates.
  Defined in the domain layer (interface), implemented in infrastructure.
  Only Aggregate Roots have repositories — not child entities.

Domain Event:
  A named fact that something happened. Always past tense: OrderPlaced, PaymentProcessed.
  Used to communicate state changes across Bounded Contexts without tight coupling.

Bounded Context:
  Explicit boundary where one domain model and one vocabulary apply.
  Different contexts can use the same word to mean different things.
  Communicate across boundaries via Domain Events or Anti-Corruption Layers.
```

The must-memorise gotcha is that **an Aggregate Root must enforce all invariants** — no setters, only domain methods:

```java
// Value Object — immutable, equality by all fields, no identity
public record Money(BigDecimal amount, Currency currency) {
    public Money {
        Objects.requireNonNull(amount, "amount required");
        if (amount.compareTo(BigDecimal.ZERO) < 0) throw new IllegalArgumentException("Money cannot be negative");
    }
    public Money add(Money other) {
        if (!this.currency.equals(other.currency)) throw new IllegalArgumentException("Currency mismatch");
        return new Money(this.amount.add(other.amount), this.currency);  // new instance — immutable
    }
}

// Aggregate Root — enforces all invariants; no public setters
public class Order {
    private final OrderId id;
    private final CustomerId customerId;   // cross-aggregate ref by ID only — NOT Customer object
    private final List<OrderItem> items;
    private OrderStatus status;

    // State change via domain method — invariant checked inside
    public void confirm(Money paymentAmount) {
        if (status != OrderStatus.PENDING)
            throw new DomainException("Only PENDING orders can be confirmed");
        if (!paymentAmount.equals(this.calculateTotal()))
            throw new DomainException("Payment amount must match order total");
        this.status = OrderStatus.CONFIRMED;
        // Raise domain event — other contexts listen without tight coupling
        DomainEvents.raise(new OrderConfirmedEvent(this.id, this.customerId, this.calculateTotal()));
    }
    // NO setters — the only way to change status is through confirm(), cancel(), etc.
}
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is the difference between an Entity and a Value Object?"**

**One-line answer:** An Entity has a unique identity that persists through state changes; a Value Object has no identity and is defined entirely by its values.

**Full answer:**
> "An Entity is an object that has a continuous identity over time. A Customer is an Entity: the same customer can change their email address, their name, even their country, and they are still the same customer — identified by their CustomerId, typically a UUID. Two Customer objects with the same ID are the same customer even if all their other fields differ. A Value Object has no such identity. Money is a Value Object: £100.00 GBP is not 'a specific hundred pounds with an ID' — it is just the value £100.00 GBP. Any instance representing that value is interchangeable with any other. Value Objects are always immutable: instead of modifying a Money object, you produce a new one. This immutability makes them safe to share and cache without defensive copying. The practical rule: if you would care that it's *this specific thing* even after it changes, make it an Entity. If you only care about the value itself, make it a Value Object. Address, DateRange, EmailAddress, Weight — all Value Objects. Order, Customer, Product — Entities."

> *The 'same customer' framing clicks immediately for interviewers.*

**Gotcha follow-up:** *"When should an Address be a Value Object versus an Entity?"*
> "Almost always a Value Object — you care about the street, city, and postcode, not about tracking a specific address instance over time. But there is a real exception: in a logistics system that tracks address history for fraud detection or compliance — 'this customer's delivery address changed three times in one week' — you may need to treat each address as an Entity with its own ID and creation timestamp so you can query the history. The question to ask is: does my business need to distinguish between two addresses that are identical in all their field values? If yes, make it an Entity. In ninety-nine percent of e-commerce, the answer is no."

---

**Concept Check**
**"What is an Aggregate and why does the rule 'one aggregate per transaction' exist?"**

**One-line answer:** An Aggregate is a consistency boundary — a cluster of objects where all invariants must hold after every change — and one transaction per aggregate prevents distributed locking problems.

**Full answer:**
> "An Aggregate is a cluster of domain objects — Entities and Value Objects — that are treated as a single unit for the purpose of data changes. Every Aggregate has one Aggregate Root: the single object that external code interacts with. You cannot reach into an aggregate and modify a child entity directly — you always go through the root, which enforces all invariants. The reason for 'one aggregate per transaction' is consistency and scalability. If you allow a single transaction to modify two aggregates — say, decrement inventory in a Product aggregate and create an order in an Order aggregate simultaneously — you need a distributed lock or a distributed transaction to keep them consistent. Those are expensive and fragile. Instead, DDD says: make each transaction touch exactly one aggregate, and use Domain Events — named facts about things that happened — to propagate changes to other aggregates asynchronously. The eventual consistency between aggregates is an accepted tradeoff for the scalability and isolation you gain."

> *Pause after explaining the one-transaction rule. This is where interviewers often probe.*

**Gotcha follow-up:** *"So what if I genuinely need two aggregates to be consistent at the same time?"*
> "That is a signal to re-examine your aggregate boundaries. Often when you feel you need a cross-aggregate transaction, it means the two aggregates should actually be one — they share an invariant that must hold together, which is the definition of an aggregate boundary. The classic example: Order and OrderItem are almost always in the same aggregate because 'the total of all line items equals the order total' is an invariant that must hold atomically. If you truly cannot merge them — perhaps they are owned by different teams or different services — then you have to accept eventual consistency and compensating transactions: if the second step fails, publish a compensating event that reverses the first."

---

**Tradeoff Question**
**"What is a Bounded Context and why does it matter?"**

**One-line answer:** A Bounded Context is an explicit boundary within which one vocabulary and one domain model applies, preventing the 'God model' problem of one class meaning all things to all parts of the system.

**Full answer:**
> "A Bounded Context is an explicit boundary — in code, in the team, in the conversation — inside which one unified model applies. The classic example: 'Order' means something very different to the Billing team and the Warehouse team. In Billing, an Order is a financial obligation with tax lines and payment terms. In the Warehouse, a Fulfillment Order is a list of pick-and-pack instructions with bin locations. If you force both teams to share one Order class, you end up with a class that has billing fields the warehouse never touches and warehouse fields that billing ignores. Worse, when one team wants to rename a field or add a constraint, they must negotiate with the other team. Bounded Contexts solve this by saying: each context has its own model. When an order is confirmed in the Sales context, it raises an OrderConfirmed domain event. The Warehouse context listens for that event and creates its own FulfillmentOrder. The two models evolve independently. Teams move faster. The models stay clean."

> *The split between Billing Order and Fulfillment Order is a concrete example interviewers remember.*

**Gotcha follow-up:** *"How do two Bounded Contexts communicate?"*
> "Primarily through Domain Events — named facts published when something significant happens in one context, consumed asynchronously by other contexts. This is loose coupling: the Sales context does not know which other contexts care about OrderConfirmed, and those contexts do not reach into Sales. For synchronous needs, an Anti-Corruption Layer translates between the models — it is an adapter that sits on the boundary and prevents one context's concepts from leaking into another. If you are calling an external payment provider, the Anti-Corruption Layer translates between your domain's PaymentResult concept and whatever Stripe returns, so your domain never knows you are using Stripe."

---

> **Common Mistake — Referencing aggregates by object instead of by ID:** If your Order aggregate holds a direct Java reference to a Customer object — `private Customer customer` — instead of a CustomerId — `private CustomerId customerId` — you have coupled two aggregates. Loading an Order now triggers a Customer load. Saving an Order might cascade-save changes to Customer. The two aggregates can no longer be stored in different services or databases. Always reference other aggregates by their ID only; load the referenced aggregate separately when you need it.

---

**Quick Revision:** DDD aligns code with the real domain by using Entities (identity-based), Value Objects (value-based, immutable), Aggregates (consistency boundaries with one root), and Bounded Contexts (vocabulary boundaries that let teams evolve models independently).

---

## Topic 9: Code Smells & Refactoring

#### The Idea

A code smell is not a bug. The tests pass. The feature works. But something about the structure makes you uneasy when you read it — a method that scrolls for two screens, a class with forty private fields, a method that constantly reaches into another object to pull out its data. These are smells: symptoms that something in the design is under stress. Martin Fowler's *Refactoring* catalog documents them with names so teams can discuss them without arguing about aesthetics.

The analogy: a code smell is like a persistent cough. It does not mean you are dying. But it is a signal worth investigating before it becomes pneumonia. A Long Method is not inherently broken — it might work fine — but it is harder to test in isolation, harder to reuse, and harder to change without breaking something unintended.

Refactoring is the discipline of improving the internal structure of code without changing its observable behaviour. The safety net is tests: you never refactor without tests, because without them you cannot know whether your improvement broke something. The rhythm is Red-Green-Refactor — make the tests pass first, then improve the structure under the protection of a green test suite.

#### How It Works

```
Key smells and their fixes:

Long Method (>20-30 lines, multiple responsibilities)
  → Extract Method: name each logical chunk as a well-named private method
  → Signal: if you need a comment to explain what a block does, that block wants to be a method

God Class (hundreds of lines, many unrelated fields, high coupling)
  → Extract Class: find cohesive sub-groups of fields+methods, move them to a new class
  → Move Method: if a method uses another class's data more than its own, move it there

Feature Envy (method constantly calls getters on another class)
  → Move Method to the class whose data it envies
  → Ask: "where does this behaviour naturally live?"

Data Clumps (same group of fields always travel together)
  → Extract Class or record: street + city + zip → Address value object

Primitive Obsession (String email, int orderId, String status)
  → Replace Primitive with Object: Email, OrderId, OrderStatus
  → Benefits: validation in constructor, type safety, no invalid states

Switch on Type / instanceof chains
  → Replace Conditional with Polymorphism
  → Each 'case' becomes a subclass or implementation

Long Parameter List (4+ parameters)
  → Introduce Parameter Object: group related params into a record/command object

Duplicated Code
  → Extract Method, then Pull Up Method to shared location

Dead Code (unreachable, unused fields/methods)
  → Delete it — source control remembers history

Refactoring rhythm:
  1. Ensure tests cover the behaviour you will change (write them if missing)
  2. Make one small change
  3. Run tests — must stay green
  4. Repeat
```

The must-memorise gotcha is the **Introduce Parameter Object** refactoring, which also eliminates Data Clumps and Long Parameter Lists simultaneously:

```java
// SMELL: Long Parameter List + Data Clumps + Long Method with mixed concerns
public class OrderProcessor {
    public void process(String firstName, String lastName, String email,
                        String street, String city, String zip,
                        List<String> productIds, double[] prices, int[] quantities) {
        if (!email.contains("@")) throw new IllegalArgumentException("Bad email");
        double total = 0;
        for (int i = 0; i < productIds.size(); i++) total += prices[i] * quantities[i];
        if (total > 100) total *= 0.95;
        System.out.println("Sending to " + email + ": total " + total);
    }
}

// REFACTORED: Parameter Objects + Extract Method + separated concerns
public record CustomerInfo(String firstName, String lastName, Email email) {}
public record ShippingAddress(String street, String city, String zip) {}
public record OrderLine(ProductId productId, Money unitPrice, int quantity) {
    public Money lineTotal() { return unitPrice.multiply(quantity); }
}
public record PlaceOrderCommand(CustomerInfo customer, ShippingAddress address, List<OrderLine> lines) {}

@Service
public class OrderProcessor {
    private final OrderValidator validator;
    private final PricingService pricingService;
    private final EmailService emailService;
    private final OrderRepository orderRepository;

    public OrderConfirmation process(PlaceOrderCommand cmd) {
        validator.validate(cmd);                                    // Single Responsibility
        Money total = pricingService.calculateTotal(cmd.lines());  // Feature Envy fixed
        Order order = Order.create(cmd.customer(), cmd.address(), cmd.lines(), total);
        orderRepository.save(order);
        emailService.sendConfirmation(cmd.customer().email(), order);
        return OrderConfirmation.from(order);
    }
}
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is Feature Envy and how do you fix it?"**

**One-line answer:** Feature Envy is when a method is more interested in the data of another class than its own — the fix is to move the method to the class it envies.

**Full answer:**
> "Feature Envy is the smell where a method spends most of its time calling getters on another class to do its work. The canonical example: you have an OrderService method that calls order.getItems(), then for each item calls item.getProductId(), item.getUnitPrice(), item.getQuantity() — to compute the order total. That method belongs on the Order class, not on OrderService. The data it needs lives in Order; it is envious of that data. The fix is the Move Method refactoring: move the method to the class whose data it uses most. The result is more cohesive classes — each class holds both the data and the behaviour that operates on that data — which is the Object-Oriented principle of encapsulation. It also reduces coupling: fewer classes need to know the internal structure of Order."

> *Use the Order total example — it is immediately concrete.*

**Gotcha follow-up:** *"What if the method needs data from two different classes equally?"*
> "Then you have a harder design question: which class is responsible for this behaviour? Often the right answer is to introduce a third concept — a domain service or a value object — that takes both objects as inputs. For example, calculating shipping cost might need both the Order's weight and the Customer's loyalty tier. Neither Order nor Customer owns shipping logic exclusively. A ShippingCalculator service accepting both as parameters is cleaner than forcing the logic into either class. The smell has pointed you toward a missing abstraction."

---

**Tradeoff Question**
**"When is it acceptable to leave a code smell in place rather than refactoring it?"**

**One-line answer:** When the cost of refactoring — risk, time, test coverage — exceeds the benefit given how often the code actually changes.

**Full answer:**
> "Refactoring has a cost: time to write the improved version, risk of introducing regressions if test coverage is thin, cognitive overhead for the team during the transition. The benefit is proportional to how frequently the code changes and how many people need to understand it. If a Long Method has been stable for three years, is touched twice a year, and the team all know it well, the return on refactoring it is low. I would note it as technical debt but not prioritise it. The cases where I always refactor: code that is actively being changed, code that is blocking a new feature, and code where a smell is causing actual pain — like a God Class where every new requirement requires modifying one four-hundred-line file and merging conflicts weekly. The Strangler Fig pattern is useful here for large refactors: instead of a big-bang rewrite, gradually route new call paths through the improved code while old paths continue to work. You reduce risk and deliver incrementally."

> *The Strangler Fig mention signals senior-level thinking about large-scale change.*

**Gotcha follow-up:** *"What is the Red-Green-Refactor cycle and why does the order matter?"*
> "Red-Green-Refactor is the TDD discipline: write a failing test (Red), write the minimum code to make it pass (Green), then improve the structure without changing behaviour (Refactor). The order matters because Refactor is only safe when you are Green. If you refactor while tests are failing, you cannot distinguish between regressions you introduced and failures that were already there. The tests are your safety net — refactoring without them is working without a net. This is why the first step before any refactoring is: do I have tests covering the behaviour I am about to change? If not, write the characterisation tests first."

---

**Design Scenario**
**"I have a 400-line service class with twelve injected dependencies. How do you approach it?"**

**One-line answer:** A God Class with twelve dependencies is violating Single Responsibility — look for cohesive clusters of fields and methods that want to be separate classes.

**Full answer:**
> "A class with twelve injected dependencies is almost certainly violating the Single Responsibility Principle — the principle that a class should have exactly one reason to change. The approach: list all twelve dependencies and ask what each one is used for. You will find clusters: maybe four of them are used together to handle payment processing, three others are always used together for notifications, and five more handle order fulfilment. Each cluster is a candidate for Extract Class. Extract the payment-related dependencies and methods into a PaymentOrchestrator. Extract the notification dependencies into a NotificationService. The original God Class shrinks to an orchestrator that delegates to these focused collaborators. The risk: do this in small steps with tests running after each extraction. Move one cluster at a time, verify the tests stay green, then move the next."

> *Walk through the 'list dependencies, find clusters' step explicitly — it is a concrete, actionable approach.*

**Gotcha follow-up:** *"What is Primitive Obsession and why does replacing primitives with objects matter in Java?"*
> "Primitive Obsession is using raw types like String, int, or double to represent domain concepts. You see orderId as a long, email as a String, status as a String. The problem is that Java's type system cannot protect you: you can pass an order ID where a product ID is expected and the compiler says nothing. You can set status to any arbitrary String including typos. Replacing them with wrapper types — OrderId, Email, OrderStatus as an enum — gives you compiler-checked type safety, a natural home for validation (the Email constructor rejects invalid formats), and self-documenting method signatures. findById(OrderId id) is immediately clearer than findById(long id). In Spring Boot, the mapping from HTTP request parameters to these types is handled by a simple @ParameterObject or a converter, so the overhead is minimal."

---

> **Common Mistake — Refactoring without a safety net:** Improving a God Class or extracting methods from a Long Method without first establishing test coverage is how refactors introduce regressions. The smell fix takes five minutes; the incident investigation takes three days. Always write characterisation tests — tests that document the current behaviour, even if that behaviour is imperfect — before touching the structure of code you do not fully understand.

---

**Quick Revision:** Code smells are structural symptoms — Long Method, God Class, Feature Envy, Primitive Obsession — that signal where design is breaking down; refactoring fixes structure without changing behaviour, always under the protection of a green test suite.

---

## Topic 10: CQRS Pattern

#### The Idea

Imagine a library. When a librarian catalogues a new book — recording its title, author, shelf location, and condition — they fill in a precise acquisition form that enforces every required field and validation rule. When a reader searches for a book, they use a completely different interface: a search terminal optimised for fast lookup by title, author, or genre. Nobody asks the reader to fill in an acquisition form to search, and nobody hands the librarian a search result to catalogue a return. The two workflows are fundamentally different in shape, speed, and purpose.

CQRS — Command Query Responsibility Segregation — applies this same insight to software. A Command is anything that changes state: place an order, cancel a subscription, process a payment. A Query is anything that reads state: show me my order history, get the product catalogue, render a dashboard. These two concerns have opposite needs. Commands need strict consistency — you cannot place an order if the inventory is zero. Queries need speed and flexibility — you want to join order data with customer data with product data and return it in one fast response. Using one model for both is like forcing the library's reader and the librarian to use the same form.

The practical payoff: your write side is a clean domain model that enforces business rules on aggregates. Your read side is a set of pre-computed, denormalised view tables — one per query pattern — that answer queries with a single SELECT statement. No joins, no aggregate traversal, no ORM overhead at query time.

#### How It Works

```
CQRS separates two flows:

WRITE SIDE (Commands):
  1. Controller receives HTTP request
  2. Translates to a Command object (no response data — just intent)
  3. Command Handler loads Aggregate from repository
  4. Aggregate enforces invariants, updates state
  5. Repository saves Aggregate
  6. Domain Event published: "OrderPlaced"
  7. Returns only an ID or void — never the full updated state

READ SIDE (Queries):
  1. Controller receives HTTP request
  2. Query Handler goes directly to a read model (view table / cache)
  3. Returns a DTO shaped exactly for the UI — no domain object traversal
  4. No writes, no aggregate loading, no invariant checking

PROJECTION (keeping read model in sync):
  1. Listens for Domain Events from write side
  2. On OrderPlaced event: denormalize data into order_summary_view table
     (join Customer name+email, compute item count, store total — all pre-computed)
  3. Runs asynchronously — eventual consistency

Consistency model:
  Write side: strongly consistent (within one aggregate)
  Read side: eventually consistent (updated after event, milliseconds to seconds behind)
```

The must-memorise gotcha is that the **read model is deliberately denormalised** — and this is not a mistake, it is the design:

```java
// The read model is a pre-joined, pre-computed view — this is intentional
@Entity
@Table(name = "order_summary_view")
public class OrderSummaryView {
    @Id private UUID orderId;
    private String customerEmail;   // denormalized from Customer aggregate
    private String customerName;    // denormalized from Customer aggregate
    private BigDecimal totalAmount;
    private String status;
    private Instant placedAt;
    private int itemCount;          // pre-computed — no COUNT(*) at query time
    // Query is: SELECT * FROM order_summary_view WHERE customer_email = ? ORDER BY placed_at DESC
    // Zero joins. Constant time regardless of order size.
}

// Projection handler keeps the view in sync — runs asynchronously after write
@Component
public class OrderProjectionHandler {
    private final OrderSummaryViewRepository viewRepository;
    private final CustomerRepository customerRepository;

    @EventListener
    @Async  // async — does not block the write transaction
    public void on(OrderPlacedEvent event) {
        Customer customer = customerRepository.findById(event.customerId()).orElseThrow();
        OrderSummaryView view = new OrderSummaryView();
        view.setOrderId(event.orderId().value());
        view.setCustomerEmail(customer.getEmail());
        view.setCustomerName(customer.getFullName());
        view.setTotalAmount(event.total().amount());
        view.setStatus("PLACED");
        view.setPlacedAt(Instant.now());
        view.setItemCount(event.itemCount());
        viewRepository.save(view);
        // Read model is now eventually consistent with the write side
    }
}
```

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is CQRS and why does it exist?"**

**One-line answer:** CQRS separates the write model — which enforces business invariants — from the read model — which is optimised for query performance — because the two have opposite design requirements.

**Full answer:**
> "CQRS stands for Command Query Responsibility Segregation, a pattern introduced by Greg Young. The core observation is that the data shape you need for writes — a domain aggregate that enforces invariants like 'you cannot exceed your credit limit' — is almost never the same shape you need for reads — a flat, pre-joined view that renders a dashboard in one query. In a traditional CRUD system you use one model for both. To render an order summary page, you load the Order aggregate, traverse its items, call the Customer service to get the customer's name, call the Product service to get product names — multiple queries, multiple joins, all happening at render time. In CQRS, when an order is placed, a projection handler — a background subscriber to the OrderPlaced event — pre-computes all that joined data and writes it into an order_summary_view table. The query is then a single-table SELECT. At Amazon and Shopify scale, the difference between 'join at query time' and 'pre-computed view' is the difference between P99 latency of 2 seconds and 20 milliseconds."

> *The latency framing ties it to real business impact.*

**Gotcha follow-up:** *"What is eventual consistency in the context of CQRS and when is it a problem?"*
> "Eventual consistency means the read model is updated asynchronously after the write model changes. When a customer places an order, the write side saves the Order aggregate and publishes an OrderPlaced event. The projection handler processes that event — usually within milliseconds — and updates the order_summary_view. During that window, a query for the customer's order list might not show the order they just placed. For most read scenarios — browsing an order list, viewing a dashboard, generating a report — this brief inconsistency is acceptable. The problem arises when a write decision depends on current read state: checking whether inventory is still available before confirming a second order. That check must go through the write side's strongly consistent aggregate model, not the eventually consistent read model. The design rule: use the write side's aggregate for any read that must be consistent with the write you are about to perform."

---

**Tradeoff Question**
**"What are the costs of CQRS and when should you not use it?"**

**One-line answer:** CQRS adds complexity — two models, projection handlers, eventual consistency to manage — and is only justified when query and write patterns genuinely diverge at scale.

**Full answer:**
> "The costs are real. You now have two separate models to maintain. Every domain event that changes the write model potentially requires updating one or more projection handlers. If a projection handler fails or falls behind, your read model is stale — you need monitoring, alerting, and a way to rebuild projections from event history. You now have eventual consistency to explain to product managers and handle in the UI. For a straightforward CRUD service — a configuration API, an internal admin tool, a prototype — none of this complexity is justified. CQRS is the right choice when: your query patterns and write patterns are genuinely different in shape; you have specific read-side performance requirements that a normalised write model cannot meet; or your read and write loads are asymmetric enough that you want to scale them independently — for example, ten reads per second against a heavily cached read model but a hundred writes per second going through the aggregate. I would default to a single model and add CQRS only when I have measured a problem it solves."

> *'I would default to a single model' is the senior answer — it shows you are not pattern-chasing.*

**Gotcha follow-up:** *"How do you handle a failed projection update — the event is processed but the view table write fails?"**
> "The standard approach is to treat the projection handler as a consumer with at-least-once delivery semantics and make projection updates idempotent. If the same OrderPlaced event is processed twice — because a retry fires after a partial failure — the result should be the same: one correct row in the view table. This usually means using UPSERT (INSERT ... ON CONFLICT DO UPDATE in PostgreSQL) rather than a blind INSERT. For critical projections, you can use an outbox pattern on the write side: write the domain event to an events table in the same transaction as the aggregate, then a separate process reliably delivers it to the projection handler. This ensures no event is ever lost even if the application crashes between the aggregate save and the event publish."

---

**Design Scenario**
**"Walk me through implementing CQRS for an order history feature in Spring Boot."**

**One-line answer:** Write side uses an Order aggregate and publishes OrderPlaced events; an async projection handler denormalises into an order_summary_view; the query handler does a single-table SELECT.

**Full answer:**
> "The write side stays as a clean aggregate. OrderCommandHandler receives a PlaceOrderCommand, creates an Order domain object, processes payment through a PaymentGateway port, calls order.confirm(), saves via OrderRepository, and publishes an OrderPlacedEvent using Spring's ApplicationEventPublisher. The Order aggregate and use case have no knowledge of the read model. On the read side, I create an order_summary_view table with all the data needed for the order history UI pre-joined: customer email, customer name, order total, status, date, item count — all denormalised. An OrderProjectionHandler annotated with @EventListener and @Async listens for OrderPlacedEvent. It loads the Customer by ID, constructs an OrderSummaryView entity with all the pre-joined fields, and saves it. The OrderQueryHandler has a single method: getOrdersForCustomer(email) — it goes directly to the OrderSummaryViewRepository and returns a List<OrderSummaryDTO> from a single-table query. No aggregate loading, no joins, no ORM traversal at query time."

> *Walking through the full flow end-to-end is exactly what the interviewer wants — it shows you have built it, not just read about it.*

**Gotcha follow-up:** *"How does CQRS relate to Event Sourcing — are they the same thing?"*
> "They are different patterns that are often used together but do not require each other. CQRS separates the write model from the read model. Event Sourcing is a persistence strategy where instead of storing the current state of an aggregate, you store the sequence of events that led to that state — and derive current state by replaying them. Event Sourcing makes CQRS natural because the event log is your canonical source of truth and projections are just materialized views built by replaying that log. But you can have CQRS without Event Sourcing — storing aggregate state normally in a relational database and publishing events only to drive projections — which is what most Spring Boot CQRS implementations do. And you could theoretically use Event Sourcing without CQRS, though that is unusual. At companies like Amazon, both are used together: the event log enables auditability, time-travel debugging, and rebuilding any projection from scratch by replaying history."

---

> **Common Mistake — Querying the write model from the read side:** The most common CQRS implementation mistake is having a query handler load an aggregate, traverse its domain objects, and map to a DTO — defeating the entire purpose of the pattern. The read side must go directly to the denormalised read model. If you find yourself calling OrderRepository from a query handler, you have not separated the models; you have just added naming overhead. The read model is its own repository, its own table, its own optimised data structure — completely independent of the aggregate.

---

**Quick Revision:** CQRS separates write (Commands enforce invariants through aggregates) from read (Queries hit pre-computed denormalised views updated asynchronously via projection handlers), trading eventual consistency for query performance and model clarity.

---

## Topic 11: Event Sourcing

#### The Idea

Imagine a bank. At any moment, the bank knows your balance — but how do they know it? Not because they wrote "balance = $1,247" on a sticky note and updated it every transaction. They know it because they have a complete ledger of every deposit and withdrawal since the account opened. The balance is derived by summing all those entries. The ledger is the truth; the balance is just a convenient summary.

Event Sourcing applies the same idea to software. Instead of storing just the current state of an object (the balance), you store every event that changed it (the transactions). The current state is computed on demand by replaying those events from the beginning. The event log is the system of record, not any single "latest value."

This shifts what you can do: you can ask "what did this order look like last Tuesday?" or "replay all events through a new projection to answer a query we didn't anticipate at design time." Traditional CRUD systems discard history the moment you overwrite a row — Event Sourcing makes history first-class.

#### How It Works

```
// Pseudocode: Core Event Sourcing mechanics

// Command: intent to change state
placeOrder(customerId, lines):
    order = Order.empty()
    order.apply(OrderCreated(orderId, customerId, now))
    for each line in lines:
        order.apply(OrderItemAdded(orderId, line.productId, line.qty, line.price))
    eventStore.append(orderId, order.pendingEvents, expectedVersion=0)

// Load aggregate by replaying events from store
loadOrder(orderId):
    events = eventStore.load(orderId)           // fetch all events for this aggregate
    order = Order.empty()
    for each event in events:
        order.apply(event)                      // mutate state only through apply()
    return order

// Snapshot optimization: load snapshot + only newer events
loadOrderWithSnapshot(orderId):
    snapshot = snapshotStore.latestFor(orderId) // may be null
    fromVersion = snapshot ? snapshot.version : 0
    events = eventStore.loadFrom(orderId, fromVersion)
    order = snapshot ? snapshot.state : Order.empty()
    for each event in events:
        order.apply(event)
    return order

// Projection: a read model built from the event stream
// Runs asynchronously, consumes events, materialises a query-optimised view
onEvent(OrderConfirmed e):
    orderSummaryTable.upsert(e.orderId, status="CONFIRMED", total=e.total)
```

The single most interview-critical gotcha is the **optimistic locking pattern in the event store append**. Concurrent writes to the same aggregate are detected by checking the expected version:

```java
// The must-memorise pattern: append with optimistic locking
@Repository
public interface EventStore {
    // expectedVersion is the version you loaded — if someone else wrote since then,
    // the store throws OptimisticLockException and the caller must retry.
    void append(UUID aggregateId, List<DomainEvent> newEvents, int expectedVersion);
}

// In the repository:
public void save(Order order) {
    // order.getVersion() = version when we loaded it
    // order.pendingEvents() = new events from this command
    eventStore.append(order.getId(), order.pendingEvents(), order.getVersion());
}
```

**Inline tradeoffs:**
- Append-only log = trivial horizontal scaling for writes; reads require projection.
- Replay is correct but slow on aggregates with thousands of events — snapshots are the fix.
- Projections are eventually consistent; there is no "SELECT * WHERE status = PENDING" against the event log directly.
- Changing an event's schema is hard — you stored the old shape; migration requires versioned event upcasters.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is Event Sourcing and how does it differ from storing current state?"**

**One-line answer:** Instead of overwriting a row with the latest state, you append immutable events and derive state by replaying them.

**Full answer:**
> "In a traditional CRUD system — Create, Read, Update, Delete — you store the current state of an entity in a database row, and every update overwrites the previous value. History is lost. Event Sourcing stores the sequence of *events* that happened to an entity — an append-only log — and derives the current state by replaying those events. Think of a bank: the account balance is derived from the transaction ledger, not stored independently. This gives you a complete audit trail, the ability to reconstruct state at any past point in time, and the ability to build multiple *projections* — that is, different query-optimised read models — from the same event history. The cost is higher complexity and the fact that querying current state requires a separately maintained projection, not a simple SQL query."

> *Lead with the bank analogy — interviewers respond well to it. Then pivot to the technical mechanics only if probed.*

**Gotcha follow-up:** *"How do you handle concurrent writes to the same aggregate in Event Sourcing?"*
> "With optimistic locking on the event store. When you load an aggregate, you record the version — the sequence number of the last event you read. When you append new events, you pass that expected version. If another writer appended events since you loaded, the expected version won't match, the store throws a concurrency exception, and your command handler retries from a fresh load. This is the same idea as a database optimistic lock with a version column, but applied to an append-only log."

---

**Tradeoff Question**
**"What are the main drawbacks of Event Sourcing?"**

**One-line answer:** High complexity, eventual consistency on projections, and painful event schema evolution.

**Full answer:**
> "Event Sourcing is significantly more complex than CRUD. The main drawbacks are: first, *eventual consistency* — projections, which are the read models built from the event stream, are updated asynchronously, so reads may lag behind writes; second, *replay performance* — an aggregate with thousands of events is slow to reconstitute; you solve this with *snapshots*, which are checkpoints of the aggregate state at a given event number, so you only replay events since the last snapshot; third, *schema evolution* — events are immutable facts you stored months ago; when the shape of an event needs to change, you need *upcasters*, code that transforms old event versions into the current schema on the way out of the store; and fourth, *query complexity* — there is no simple 'SELECT WHERE status = PENDING'; every query pattern needs a purpose-built projection. I'd only choose Event Sourcing when the audit trail or temporal query requirements genuinely justify the overhead."

> *Naming all four drawbacks signals seniority. Mentioning snapshots and upcasters specifically shows hands-on experience.*

**Gotcha follow-up:** *"When would you NOT use Event Sourcing?"*
> "For most CRUD-heavy domains — user profiles, product catalogues, simple config data — where history is not a business requirement. The complexity premium is only worth paying when you need a full audit trail, temporal queries, or the ability to rebuild projections as query requirements evolve. Using it everywhere is an anti-pattern; it should be scoped to the aggregates or bounded contexts where the benefits are concrete."

---

**Design Scenario**
**"How would you implement snapshots to optimise replay performance?"**

**One-line answer:** Periodically persist the aggregate state at a version number; on load, fetch the latest snapshot and replay only newer events.

**Full answer:**
> "Without snapshots, loading an aggregate means replaying every event since it was created — if an order has accumulated ten thousand events over its lifetime, that's slow. A snapshot is a serialised copy of the aggregate's state at a specific event version, stored separately from the event log. When loading, you first check the snapshot store for the latest snapshot of that aggregate. If one exists, you deserialise it — giving you the state as of, say, event 9,800 — then fetch only the events after version 9,800 from the event store and replay those. The aggregate arrives in the same final state but with a fraction of the replay work. You create new snapshots on a policy: every N events, or every time the aggregate is saved with more than N pending replays. The tricky part is keeping snapshots consistent with schema evolution — if your aggregate's shape changed after a snapshot was written, your deserialiser needs to handle the old format."

> *Draw this as a timeline: [snapshot@v9800] → [events 9801–9950] → current state. Visual makes it stick.*

---

**Concept Check**
**"What is a projection in Event Sourcing?"**

**One-line answer:** A read model built by subscribing to the event stream and materialising a query-optimised view.

**Full answer:**
> "Because Event Sourcing's event store is append-only and not directly queryable like a relational table, you need *projections* to answer read queries. A projection is a process that consumes events from the stream and writes a derived view into a fast read store — a database table, a Redis cache, an Elasticsearch index. For example, an OrderSummary projection might listen for OrderCreated, OrderConfirmed, and OrderCancelled events and maintain a table with one row per order showing its current status and total. The power of projections is that you can build multiple, independently optimised views from the same event history, and you can *rebuild* any projection from scratch by replaying all historical events if requirements change or the projection becomes corrupted."

> *Emphasise rebuildability — that's what distinguishes projections from just another database table.*

**Gotcha follow-up:** *"What consistency guarantees do projections give you?"*
> "Eventual consistency only. Projections are updated asynchronously after events are written to the store. A client that writes an event and immediately reads from a projection may see stale data. Strategies to handle this include: returning the new state directly from the command response so the UI doesn't need to read the projection immediately; using version tokens so the client can request a projection that is at least as fresh as a given version; or accepting the lag and designing the UI to show 'processing' states."

---

> **Common Mistake — Mutating state outside the apply() method:** Aggregate state must only change inside `apply(event)`. If command handlers set fields directly, replaying the event log will not reproduce the same state, breaking the entire model. Every state mutation — no matter how small — must be expressed as an event and handled in `apply()`.

---

**Quick Revision:** Event Sourcing stores the history of events rather than current state; current state is derived by replay, projections provide queryable read models, and optimistic locking on the event store prevents concurrent write conflicts.

---

## Topic 12: Hexagonal Architecture (Ports & Adapters)

#### The Idea

Imagine a universal power adapter. Your laptop has a single power jack — that's its port — and it doesn't care whether the electricity comes from a UK socket, a US socket, or a car charger. Each socket type has an adapter that converts the local power format into what your laptop expects. Your laptop's internals are completely insulated from the specifics of international electrical standards.

Hexagonal Architecture applies this idea to software. The application core — your business logic — defines *ports*, which are abstract interfaces for every external interaction it needs: "give me an order", "charge a payment", "publish an event". The outside world connects through *adapters* that translate between the port's language and the external system's reality. The core never knows whether the adapter behind "charge a payment" is Stripe, PayPal, or a test double that always succeeds.

The name "hexagonal" isn't about six sides — it emphasises that no side is more important. A REST adapter driving your core is equal to a CLI adapter driving your core is equal to a test driving your core. The shape has no top or bottom; the business logic sits at the centre, and everything else surrounds it symmetrically.

#### How It Works

```
// Pseudocode: The two kinds of ports and their adapters

// INBOUND PORT — defined by the core, implemented by the core, called by adapters
interface PlaceOrderUseCase:
    placeOrder(command: PlaceOrderCommand) → OrderId

// OUTBOUND PORT — defined by the core, called by the core, implemented by adapters
interface OrderRepository:
    save(order: Order)
    findById(id: OrderId) → Optional<Order>

interface PaymentPort:
    charge(customerId, amount) → PaymentResult

// APPLICATION SERVICE — the core, implements inbound port, uses outbound ports
class OrderApplicationService implements PlaceOrderUseCase:
    constructor(repo: OrderRepository, payment: PaymentPort)  // injected via ports, not concrete classes

    placeOrder(command):
        order = Order.create(command)
        result = payment.charge(order.customerId, order.total)
        if not result.successful: throw PaymentFailedException
        order.confirm()
        repo.save(order)
        return order.id

// INBOUND ADAPTER — drives the core
class OrderRestController:
    constructor(useCase: PlaceOrderUseCase)
    POST /orders → useCase.placeOrder(mapFromRequest(request))

// OUTBOUND ADAPTER — implements a port
class JpaOrderAdapter implements OrderRepository:
    save(order) → jpaRepo.save(JpaEntity.from(order))
    findById(id) → jpaRepo.findById(id).map(JpaEntity::toDomain)

// TEST — also an inbound adapter; swaps all outbound adapters for in-memory fakes
test placeOrder:
    repo = InMemoryOrderRepository()
    payment = AlwaysSucceedingPayment()
    service = OrderApplicationService(repo, payment)   // zero Spring context
    id = service.placeOrder(validCommand())
    assert repo.findById(id).isPresent()
```

The single most interview-critical gotcha is the **dependency direction rule**: the core must never import from adapters. The outbound port interface lives in the core package; the JPA adapter implements it and lives in the infrastructure package. This is the Dependency Inversion Principle — the core defines the contract, adapters obey it.

```java
// The must-memorise rule: dependency arrows always point INWARD
// core package — no framework imports
public interface OrderRepository {          // port lives in the core
    void save(Order order);
    Optional<Order> findById(OrderId id);
}

// infrastructure package — adapter depends on the core, not the other way
@Component
public class JpaOrderAdapter implements OrderRepository {   // adapter imports core interface
    // Spring, JPA imports are fine here — they never leak into the core
    @Override
    public void save(Order order) { /* JPA logic */ }
    @Override
    public Optional<Order> findById(OrderId id) { /* JPA query */ }
}
// The core package has ZERO imports from org.springframework, javax.persistence, etc.
```

**Inline tradeoffs:**
- Maximum testability: swap any adapter for a test double without starting a Spring context.
- More boilerplate: every external interaction needs a port interface and at least one adapter.
- Mapping overhead: domain objects must be translated to/from external representations (JPA entities, HTTP DTOs) at adapter boundaries — this is intentional, not waste.
- Hexagonal vs Clean Architecture: same dependency rule, different naming; Clean Architecture adds explicit layer labels (Entities, Use Cases, Interface Adapters, Frameworks); they are complementary.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is the difference between an inbound port and an outbound port?"**

**One-line answer:** An inbound port is an interface the core exposes for drivers to call; an outbound port is an interface the core defines for infrastructure it needs.

**Full answer:**
> "In Hexagonal Architecture, *ports* are the boundary of the application core. An *inbound port* — also called a driving port — is an interface that the core publishes representing a use case: for example, `PlaceOrderUseCase`. External systems like REST controllers or Kafka consumers call this interface to drive the application. The core both defines and implements it. An *outbound port* — also called a driven port — is an interface that the core defines representing something it needs from the outside world: for example, `OrderRepository` or `PaymentPort`. The core calls these interfaces; infrastructure *adapters* implement them. The key point is that both kinds of ports are defined *by the core* — the core dictates the contract, and everything outside obeys it. This is what keeps the core free of framework dependencies: it never imports Spring or JPA; it only talks to its own interfaces."

> *Drawing two concentric shapes — core in the middle, adapters around it — and labelling which direction each port faces makes this very concrete on a whiteboard.*

**Gotcha follow-up:** *"Why does the dependency point inward? Couldn't the core just call the JPA class directly?"*
> "If the core called `JpaOrderRepository` directly, it would import JPA annotations and Spring classes. Now the core is coupled to your persistence technology. If you want to test the core without a database, you can't — you must start a Spring context and connect to a database. By defining `OrderRepository` as an interface in the core and having the JPA class implement it, you invert the dependency: the infrastructure depends on the core, never the other way. Swapping the JPA adapter for an in-memory one in tests becomes trivial — you just construct the core with a different implementation of the same interface."

---

**Tradeoff Question**
**"What are the costs of Hexagonal Architecture?"**

**One-line answer:** More files, more mapping code, and a steeper learning curve — justified when testability and long-term maintainability matter.

**Full answer:**
> "The main costs are *boilerplate* and *mapping overhead*. Every external interaction requires a port interface plus at least one adapter class — for small services this feels like a lot of ceremony for modest benefit. Mapping is the other cost: because the core uses domain objects and adapters use external representations — JPA entities, HTTP DTOs, Kafka Avro schemas — you need translation code at every adapter boundary. This mapping is intentional; it prevents your domain model from being shaped by persistence or transport concerns. The payoff is that you can test the entire core logic in plain JUnit tests with no Spring context, no database, no network — just Java objects. For complex business logic, this speed and isolation makes the architecture worth it. For a simple CRUD service with no domain complexity, it is over-engineering."

> *The honest answer includes "sometimes it's overkill." Interviewers at senior level want judgment, not advocacy.*

---

**Design Scenario**
**"How would you add a Kafka consumer as a new entry point without touching the core?"**

**One-line answer:** Write a new inbound adapter — a Kafka listener — that maps the Kafka message to a command and calls the existing inbound port.

**Full answer:**
> "This is exactly where Hexagonal Architecture pays off. The core already exposes `PlaceOrderUseCase` as an inbound port. To add Kafka as a new driver, I create a new inbound adapter — a class annotated with `@KafkaListener` that lives in the infrastructure package. It deserialises the Kafka message into a `PlaceOrderCommand` and calls `placeOrderUseCase.placeOrder(command)`. The core doesn't know or care that the call came from Kafka rather than an HTTP request. No core code changes. The core was already tested in isolation; the Kafka adapter needs only a thin integration test checking that the message format maps correctly to the command."

> *The phrase "the core doesn't know or care" is the key insight — say it explicitly.*

---

**Concept Check**
**"How is Hexagonal Architecture different from Clean Architecture?"**

**One-line answer:** They enforce the same inward-pointing dependency rule but use different naming conventions; they are complementary, not competing.

**Full answer:**
> "Both enforce the *Dependency Rule*: source code dependencies must point inward toward the core, never outward toward infrastructure. The difference is in naming and layer granularity. Hexagonal Architecture calls things ports and adapters and focuses on the testability benefit of swapping adapters. Clean Architecture — Robert Martin's version — names explicit concentric layers: Entities at the centre, then Use Cases, then Interface Adapters, then Frameworks and Drivers at the outermost ring. Clean Architecture gives more guidance about what goes inside the core: Entities hold enterprise business rules, Use Cases hold application-specific rules. Many teams combine both vocabularies — 'we use Hexagonal for the port/adapter structure and Clean Architecture naming for the layers inside the core' — and that is perfectly fine."

> *If asked which is better: they solve the same problem; pick the one your team finds more readable.*

**Gotcha follow-up:** *"Where do mappers/DTOs live in this architecture?"*
> "At the adapter boundary, in the infrastructure or interface-adapter layer — never in the core. The REST controller adapter maps the incoming HTTP JSON body into a domain command object before calling the inbound port. The JPA adapter maps domain objects into JPA entities before saving. These mapping classes live in the adapter package and depend on both the external format and the core's domain types. The core never sees a Jackson `@JsonProperty` annotation or a JPA `@Column` annotation — those details are confined to the adapter layer."

---

> **Common Mistake — Letting framework annotations leak into the core:** Adding `@Entity`, `@Column`, `@JsonProperty`, or `@Service` to domain classes breaks the isolation hexagonal architecture is built on. The core becomes coupled to Spring and JPA; tests require a full application context; swapping persistence technology means modifying domain objects. Keep the core as plain Java — no framework imports, no annotations.

---

**Quick Revision:** The application core defines port interfaces for everything it needs and exposes; adapters outside the core implement or call those ports, and dependencies always point inward, keeping the core testable in isolation without any framework.

---

## Topic 13: Testing Principles

#### The Idea

Think about how a car is assembled and tested. Individual parts — the alternator, the brakes, the fuel injector — are each tested in isolation before the car is assembled. Once the car is assembled, subsystems are tested together: does the engine connect correctly to the transmission? Finally, the complete car is test-driven on a track. This isn't just a methodology preference — it's economics. Catching a faulty brake pad in isolation costs almost nothing. Catching it during the final test drive, after assembly, costs hours of disassembly.

Software testing follows the same logic, described as the Test Pyramid. Unit tests (isolated component tests) are fast, cheap, and numerous — they form the wide base. Integration tests (components working together) sit in the middle — fewer, slower, but they catch boundary problems. End-to-end tests (full user flows) sit at the top — few, slow, fragile, but they confirm the complete system works.

The pyramid shape is intentional. Inverting it — few unit tests, many end-to-end tests — produces a test suite that is slow, brittle, and expensive to maintain. Teams with inverted pyramids spend more time fixing flaky tests than writing features.

#### How It Works

```
// Pseudocode: What belongs at each pyramid layer

// UNIT TESTS — base of pyramid
// Test one class in isolation. All dependencies are test doubles.
// No Spring context. No I/O. Runs in < 10ms.
test "placeOrder saves order when payment succeeds":
    repo = mock(OrderRepository)
    payment = stub(PaymentGateway, returns: PaymentResult.success("txn-1"))
    service = OrderService(repo, payment)

    result = service.placeOrder(validCommand())

    assert result.transactionId == "txn-1"
    verify repo.save was called once     // behaviour verification

// INTEGRATION TESTS — middle of pyramid
// Test component interactions with real infrastructure.
// Spring context, real DB (Testcontainers), real HTTP.
// Runs in seconds.
@DataJpaTest with real Postgres container:
test "save and findById round-trip":
    repo.save(pendingOrder)
    found = repo.findById(pendingOrder.id)
    assert found.status == PENDING

// END-TO-END TESTS — top of pyramid
// Full stack: HTTP request → controller → service → DB → HTTP response.
// Runs in tens of seconds. Only critical happy paths.
@SpringBootTest(webEnvironment=RANDOM_PORT):
test "POST /orders creates order":
    response = http.post("/api/v1/orders", validOrderBody)
    assert response.status == 201
    assert response.body.orderId != null
```

The single must-memorise thing is the **F.I.R.S.T. properties of a good unit test**, especially *Isolated* — shared mutable state between tests causes the most mysterious failures:

```java
// The must-memorise gotcha: NEVER share mutable state between tests
// BAD — shared mock causes order-dependent test failures
class OrderServiceTest {
    static OrderRepository sharedMock = mock(OrderRepository.class); // shared = broken

    @Test void test1() { when(sharedMock.findById(any())).thenReturn(...); }
    @Test void test2() { /* sharedMock still has stubbing from test1 — flaky! */ }
}

// GOOD — fresh doubles per test via @BeforeEach
class OrderServiceTest {
    OrderRepository repo;
    OrderService service;

    @BeforeEach
    void setUp() {
        repo = mock(OrderRepository.class);    // fresh mock every test
        service = new OrderService(repo, mock(PaymentGateway.class));
    }
    // Each test is fully isolated — run in any order, same result
}
```

**Inline tradeoffs:**
- Unit tests: ultra-fast feedback, catch logic bugs, but don't catch integration problems (wrong SQL, missing FK constraint).
- Integration tests: catch real boundary problems, but slower and require infrastructure setup.
- `@DataJpaTest` spins up only the JPA slice of Spring — faster than full `@SpringBootTest`.
- Testcontainers provides a real Postgres in Docker for integration tests — more faithful than H2 in-memory.
- Mocks vs Fakes: mocks verify behaviour ("was save called?"); fakes verify state ("is the order in the store?"). Fakes are more refactoring-resistant; mocks couple tests to implementation.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"Explain the test pyramid and why it matters."**

**One-line answer:** Most tests should be fast, isolated unit tests; fewer integration tests; fewest end-to-end tests — because cost and speed of feedback scales with the pyramid level.

**Full answer:**
> "The test pyramid describes the ideal distribution of automated tests. At the base are *unit tests* — tests of individual classes or methods in complete isolation, with all dependencies replaced by test doubles. These run in milliseconds, give instant feedback, and should make up the majority of a test suite. In the middle are *integration tests* — tests that verify two or more components work correctly together, often involving a real database or real HTTP layer. These run in seconds and catch boundary problems that unit tests can't. At the top are *end-to-end tests* — tests that exercise the full stack from an external request to the database and back. These give the highest confidence but are the slowest and the most brittle, so there should be very few of them, covering only critical user journeys. The pyramid shape matters because it keeps the feedback loop fast: if most of your tests are unit tests, a developer gets a pass or fail in under a minute. If most tests are end-to-end, a failing build might take twenty minutes to diagnose."

> *Mention the 'inverted pyramid' anti-pattern if the interviewer seems interested — it signals you've seen real codebases.*

**Gotcha follow-up:** *"What's wrong with testing everything at the integration level?"*
> "Integration tests are slower — they may need a database container to start, Spring to initialise, and HTTP to round-trip. Running a suite of five hundred integration tests can take twenty minutes versus thirty seconds for the same coverage in unit tests. More importantly, when an integration test fails, diagnosing the cause is harder: was it the business logic, the SQL query, the mapping, the HTTP serialisation? Unit tests fail at a single method, making the bug immediately obvious. Integration tests are necessary but should be targeted at the actual integration points — not used as a substitute for thinking about unit-level design."

---

**Concept Check**
**"What is the difference between a mock, a stub, and a fake?"**

**One-line answer:** A stub returns pre-configured responses to control test inputs; a mock verifies that certain calls were made; a fake is a working simplified implementation.

**Full answer:**
> "These are all *test doubles* — stand-ins for real dependencies — but they serve different purposes. A *stub* controls the state seen by the code under test: 'when paymentGateway.charge() is called, return PaymentResult.success()'. It doesn't care whether the method was actually called. A *mock* verifies behaviour: 'assert that orderRepository.save() was called exactly once with an Order in CONFIRMED status'. Mocks couple tests to implementation details — if you refactor the internals without changing observable behaviour, mock-heavy tests break. A *fake* is a working, simplified implementation: an in-memory repository that stores objects in a HashMap instead of a database. Fakes verify state rather than behaviour, and they survive refactoring better because they test outcomes, not method calls. In practice: use stubs for external dependencies you need to control, fakes for repositories when you want state-based assertions, and mocks sparingly — only when verifying that a side effect actually occurred is genuinely important."

> *The mock-vs-fake distinction often prompts a follow-up about over-mocking — see below.*

**Gotcha follow-up:** *"What is over-mocking and why is it a problem?"*
> "Over-mocking means replacing so many collaborators with mocks that the test ends up asserting the implementation rather than the behaviour. If every method call is stubbed and every interaction is verified, the test is essentially a transcript of the production code — it breaks on any refactoring, even when the observable behaviour is unchanged. The fix is to mock only things you don't own — external services, databases — and use real collaborators or fakes for internal domain objects. Tests should answer 'does the system behave correctly?' not 'did the implementation call these methods in this order?'"

---

**Tradeoff Question**
**"When would you use @DataJpaTest versus @SpringBootTest?"**

**One-line answer:** `@DataJpaTest` for testing the persistence layer in isolation; `@SpringBootTest` for testing the full application stack.

**Full answer:**
> "`@DataJpaTest` is a *slice test* — it starts only the JPA-related parts of the Spring context: entity scanning, repositories, and a transaction manager. It does not start web layers, service beans, or security. This makes it significantly faster than a full context and appropriate for testing that your JPA queries, entity mappings, and repository methods work correctly with a real database. I pair it with Testcontainers to use a real Postgres rather than H2 in-memory, because H2 doesn't support all Postgres-specific SQL and gives false confidence. `@SpringBootTest` starts the full application context and is appropriate for integration tests that span multiple layers — testing that a REST controller correctly calls through to a service that calls through to a repository. It is slower and heavier; I use it only for a small number of critical end-to-end integration scenarios, not for every test."

> *Mentioning Testcontainers with @DataJpaTest is a strong signal of real-world experience.*

---

> **Common Mistake — Testing private methods or implementation details:** If you find yourself wanting to test a private method, it is a design signal: that logic is probably a missing class. Private methods are tested indirectly through public API. Writing tests that assert on internal state or method call sequences makes the test suite brittle — every internal refactor breaks tests even when behaviour is unchanged. Test public behaviour and observable outcomes, not implementation.

---

**Quick Revision:** Most tests should be fast, isolated unit tests at the base of the pyramid; integration tests verify component boundaries; end-to-end tests cover only critical flows; and good tests are isolated, fast, and assert observable behaviour rather than implementation details.

---

## Topic 14: API Design Principles

#### The Idea

Think about a well-designed household electrical socket. It has a standard interface: specific voltage, specific plug shape, specific safety guarantees. Any device built to that standard works. The socket doesn't change its shape every month. If a new standard is needed, old sockets continue to work for the old devices while new sockets serve new ones. The interface is stable, predictable, and self-describing enough that you can plug in a device you've never used before and have a reasonable expectation of what will happen.

A well-designed REST API works the same way. It uses standard conventions — HTTP methods, status codes, URL patterns — so that a developer who has never seen your specific API can form a reasonable hypothesis about how it works. It is stable: changes don't silently break existing clients. It handles failure gracefully: errors are structured and machine-readable, not arbitrary strings. And it manages growth: new versions coexist with old ones, pagination handles large datasets efficiently.

The four topics that come up almost universally in API design interviews are: versioning strategy, idempotency, error response format, and pagination.

#### How It Works

```
// Pseudocode: The four core API design decisions

// 1. VERSIONING — URL path versioning (most common)
GET /api/v1/orders/123   // v1 stable for existing clients
GET /api/v2/orders/123   // v2 adds new fields, different shape

// 2. IDEMPOTENCY — safe retry for non-idempotent operations
POST /api/v1/orders
  Header: Idempotency-Key: client-uuid-per-logical-operation

server:
    cached = idempotencyStore.get(key)
    if cached: return cached                // same response as first call
    result = processOrder(body)
    idempotencyStore.put(key, result, ttl=24h)
    return result

// HTTP method idempotency:
//   GET, PUT, DELETE → idempotent (safe to retry)
//   POST → NOT idempotent (creates new resource on each call)

// 3. ERROR RESPONSES — consistent machine-readable format
{
  "errorCode": "ORDER_NOT_FOUND",     // machine-readable, stable across versions
  "message": "Order abc-123 not found",  // human-readable
  "traceId": "req-xyz",               // correlates to server logs
  "timestamp": "2024-01-15T10:30:00Z",
  "fieldErrors": []                   // populated for validation failures
}

// 4. PAGINATION — cursor-based (interview-preferred over offset)
GET /api/v1/orders?after=cursor_abc&size=20

server:
    lastId = decode(cursor)           // cursor encodes the last seen ID
    rows = db.query("WHERE id > ? ORDER BY id LIMIT ?", lastId, size + 1)
    hasMore = rows.size > size
    nextCursor = hasMore ? encode(rows[size-1].id) : null
    return { data: rows[0..size], nextCursor, hasMore }

// Why cursor beats offset:
//   OFFSET 10000 scans 10000 rows to discard them — O(n) cost
//   WHERE id > last_id uses an index — O(log n) cost
//   Cursor is also stable: new inserts don't shift pages like offset does
```

The single must-memorise gotcha is **idempotency key handling** — specifically why POST needs it and what the server must do:

```java
// The must-memorise pattern: idempotency key prevents duplicate orders on retry
@PostMapping("/api/v1/orders")
public ResponseEntity<OrderResponse> placeOrder(
        @RequestBody @Valid PlaceOrderRequest request,
        @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey) {

    if (idempotencyKey != null) {
        Optional<OrderResponse> cached = idempotencyStore.get(idempotencyKey);
        if (cached.isPresent()) {
            return ResponseEntity.ok(cached.get()); // exact same response, not a new order
        }
    }

    OrderId orderId = placeOrderUseCase.execute(request.toCommand());
    OrderResponse response = OrderResponse.of(orderId);

    if (idempotencyKey != null) {
        idempotencyStore.put(idempotencyKey, response, Duration.ofHours(24));
    }
    // 201 Created with Location header pointing to the new resource
    return ResponseEntity.created(URI.create("/api/v1/orders/" + orderId.value())).body(response);
}
// Without this: a network timeout causes the client to retry, creating two orders for one purchase.
```

**Inline tradeoffs:**
- URL versioning is the most pragmatic: easy to route, cache, and test; the downside is "ugly" URLs that some purists dislike.
- Offset pagination is simple to implement but degrades on large datasets; cursor pagination is more work but scales.
- 422 Unprocessable Entity vs 400 Bad Request: 400 = malformed request (unparseable JSON); 422 = valid format but business rule violation (order total doesn't match items). Using them correctly signals API maturity.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is idempotency in APIs and why does it matter?"**

**One-line answer:** An operation is idempotent if calling it multiple times produces the same result as calling it once — critical for safe retries over unreliable networks.

**Full answer:**
> "Idempotency means that repeating an operation has the same effect as performing it once. GET, PUT, and DELETE are idempotent by HTTP convention: fetching the same resource twice returns the same data; updating a resource to the same value twice leaves it unchanged; deleting a resource twice leaves it deleted. POST is not idempotent — submitting an order form twice creates two orders. This matters because networks are unreliable: a client sends a POST, the server processes it but the response never arrives, the client retries, and now there are two orders for one intended purchase. The standard fix is an *Idempotency-Key* header: the client generates a unique UUID per logical operation and sends it on every attempt. The server stores the response from the first successful execution keyed by that UUID, and returns the stored response for any duplicate request with the same key. Stripe uses this pattern for payment processing exactly because charging a card twice on a timeout retry would be a severe bug."

> *The Stripe example grounds it in production reality — use it.*

**Gotcha follow-up:** *"How long should the server store idempotency keys?"**
> "Long enough to cover the client's entire retry window, typically 24 hours for payment operations. The key is stored in a fast cache — Redis is common — with a TTL. The tradeoff: too short and legitimate retries after a slow network event get treated as new requests; too long and you're storing data you'll never use. 24 hours is the Stripe standard and a reasonable default for most financial operations."

---

**Tradeoff Question**
**"Why is cursor-based pagination better than offset pagination for large datasets?"**

**One-line answer:** Offset pagination scans and discards rows proportional to the offset; cursor pagination uses an index seek and is O(log n) regardless of page number.

**Full answer:**
> "Offset pagination — `?page=500&size=20` — translates to `OFFSET 10000 LIMIT 20` in SQL. The database must scan and discard the first 10,000 rows before returning the 20 you want. At page 1,000 you're discarding 20,000 rows per request; the query gets slower as clients page deeper. There is also a correctness problem: if a new order is inserted while a client is paginating, every subsequent page shifts by one, causing items to be skipped or duplicated across pages. Cursor pagination avoids both problems. The cursor encodes the ID of the last item seen. The query becomes `WHERE id > :lastSeenId ORDER BY id LIMIT 21` — this hits an index directly, costs O(log n) regardless of how far into the dataset you are, and is stable under concurrent inserts because it anchors on a value, not a position. The downside is that cursor pagination doesn't support random access — you can't jump to page 47. If random access matters, offset is the only option, but for infinite scroll or sequential data exports, cursor is always better."

> *The phrase "anchors on a value, not a position" is a concise explanation of why cursors are stable — use it.*

---

**Design Scenario**
**"How would you design a consistent error response format for a REST API?"**

**One-line answer:** A fixed JSON shape with a machine-readable error code, human-readable message, correlation ID, and field-level errors for validation failures.

**Full answer:**
> "The most important property of an error response is that it's *consistent* — every error from every endpoint has the same JSON shape, so clients can write one error handler for the whole API. I'd design: `errorCode` — a stable string constant like 'ORDER_NOT_FOUND' that the client can switch on in code; `message` — a human-readable description for logs or display; `traceId` — a correlation ID that links this response to a specific span in your distributed tracing system, so support can look it up; `timestamp`; and `fieldErrors` — an array of `{field, message}` objects, populated only for validation failures, so the client knows which specific field failed and can highlight it in the UI. This means: a 400 Bad Request for malformed JSON has an empty fieldErrors array; a 422 Unprocessable Entity for a business rule violation like 'insufficient inventory' uses a domain errorCode; a 404 gets 'ORDER_NOT_FOUND'. I'd implement this with a `@RestControllerAdvice` in Spring that catches typed exceptions and maps them to this structure centrally — no individual controller handles error formatting."

> *Mentioning @RestControllerAdvice signals Spring production experience.*

---

**Concept Check**
**"What HTTP status codes should you know for a backend interview?"**

**One-line answer:** Know the 2xx (success), 4xx (client error), and 5xx (server error) families with the key distinctions within each.

**Full answer:**
> "The ones that come up in interviews: 200 OK for a successful read; 201 Created when a resource is created, paired with a Location header pointing to the new resource; 204 No Content for a successful DELETE with no response body. For client errors: 400 Bad Request for malformed input the server cannot parse; 401 Unauthorized when the request lacks valid authentication — despite the name, it means 'not authenticated'; 403 Forbidden when the caller is authenticated but lacks permission; 404 Not Found; 409 Conflict for state conflicts like a duplicate resource or an optimistic lock failure; 422 Unprocessable Entity for requests that are syntactically valid but violate a business rule; 429 Too Many Requests when rate limiting kicks in. For servers: 500 Internal Server Error for unexpected failures; 503 Service Unavailable when the service is temporarily down or overloaded. The nuance interviewers test: 401 vs 403 — 401 means 'I don't know who you are'; 403 means 'I know who you are and you can't do this'. And 400 vs 422 — 400 is a parsing failure; 422 is a business validation failure."

> *The 401-vs-403 and 400-vs-422 distinctions are the two most common interview follow-ups on status codes.*

---

> **Common Mistake — Returning 200 OK with an error body:** Some teams return `200 OK` with `{"success": false, "error": "..."}` in the body to avoid handling error status codes on the client. This breaks HTTP caching, prevents middleware from detecting errors, and makes monitoring impossible — your APM tool sees 100% success rate while customers see failures. Always use the correct 4xx or 5xx status code; the body provides detail, the status code signals outcome.

---

**Quick Revision:** A well-designed REST API uses URL versioning for stability, idempotency keys for safe retries on non-idempotent operations, a consistent machine-readable error format with correct status codes, and cursor-based pagination for efficient traversal of large datasets.

---

## Topic 15: Technical Debt

#### The Idea

Imagine taking out a mortgage to buy a house. The debt lets you move in now instead of saving for twenty years — that is a deliberate, rational decision. But the interest compounds. If you make only the minimum payment every month and never pay it down, the total cost grows until it consumes a significant portion of your income. The debt was useful when taken; the problem is failing to manage it.

Technical debt works the same way. Ward Cunningham — who coined the term — meant it as an analogy: choosing a quick implementation now is like borrowing against your future development capacity. The interest is paid as slower feature delivery, more bugs, harder onboarding for new engineers, and increasing reluctance to touch the affected code. Deliberately taking on debt to meet a deadline is a sound business decision, as long as you pay it back. Accumulating it through neglect or poor practices is what turns it into a crisis.

The key distinction for interviews: debt is not a synonym for "bad code." It is a conscious tradeoff between short-term speed and long-term maintainability, with a cost that accrues over time.

#### How It Works

```
// Pseudocode: Fowler's Technical Debt Quadrant — how debt is incurred

// Axis 1: Deliberate vs Inadvertent
//   Deliberate: the team knew the right approach and chose the shortcut
//   Inadvertent: the team didn't know, or didn't realise the cost

// Axis 2: Reckless vs Prudent
//   Reckless: "we don't have time for tests / design"  — dangerous
//   Prudent: "we understand the cost and accept it consciously"

// Quadrant outcomes:
Deliberate + Reckless:  "No time for design" → dangerous, avoid
Deliberate + Prudent:   "Ship now, refactor after launch" → manageable
Inadvertent + Reckless: "What's cohesion?" → dangerous, hire/train
Inadvertent + Prudent:  "Now we see how we should have done it" → normal learning

// Measuring debt — key metrics:
cyclomatic_complexity(method):
    // Number of independent code paths = number of if/else/for/catch + 1
    // > 10 → hard to test, likely has hidden bugs
    // Tool: SonarQube, Checkstyle

code_coverage:
    // Low coverage = tests don't exist for this path = risky to change
    // < 60% on critical paths = implicit debt

duplication_rate:
    // Copy-pasted logic = change must be applied in N places = debt multiplier

dependency_freshness:
    // Outdated dependencies with CVEs = security debt accruing interest every day

// Communicating to stakeholders: translate to business impact
debt_as_business_case:
    current_checkout_latency = 800ms
    projected_after_refactor = 200ms
    industry_conversion_impact = 1% per 100ms improvement
    revenue_impact = 6% conversion gain on checkout page
    // Now it is a feature with ROI, not "cleaning up code"
```

The single must-memorise gotcha is how to **frame technical debt for a non-technical stakeholder** — this is what separates engineers who can influence decisions from those who can't:

```java
// The must-memorise pattern: translate debt into business language

// DON'T say: "The OrderService has high cyclomatic complexity and low test coverage."
// DO say:

/*
 * DEBT ITEM: Payment service has no integration tests
 * Current cost:   Every deployment requires a manual smoke-test (2 hours developer time)
 *                  20% of deployments trigger a manual rollback (4 hours each)
 *                  With 20 deployments/month: 20*2h + 4*20*0.2 = 56 developer-hours/month wasted
 * Fix investment: 2 weeks to write integration test suite
 * Payback:        ~2 months; every month after = 56 developer-hours saved = cost of a half-engineer
 * Risk if ignored: A regression in payment processing causes revenue loss and customer trust damage
 */

// The same structure works for any debt item:
// CURRENT COST (time, risk, conversion) + FIX INVESTMENT + PAYBACK PERIOD + RISK IF IGNORED
```

**Inline tradeoffs:**
- Not all debt should be paid: if a component is stable, never changes, and causes no pain, the ROI of refactoring it may be negative.
- Tech debt registers (a prioritised list of known debt with estimated business impact) make debt visible as a first-class business concern alongside feature work.
- DORA metrics (Deployment Frequency, Lead Time for Changes, Mean Time to Recovery, Change Failure Rate) are the most objective signals of accumulated debt — low deployment frequency and high failure rate are debt's fingerprints.
- The Boy Scout Rule: leave the code slightly better than you found it. Continuous small improvements prevent debt from compounding.

#### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline.

> *Tip: Lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

**Concept Check**
**"What is technical debt and how does it differ from just bad code?"**

**One-line answer:** Technical debt is the future cost of a deliberate shortcut taken now; bad code is debt incurred without awareness.

**Full answer:**
> "Ward Cunningham coined the term as a deliberate analogy to financial debt. Taking on debt can be rational: choosing a simpler implementation to ship on a deadline is a conscious decision with a known cost — just like taking a mortgage to buy a house now rather than saving for twenty years. The 'interest' on technical debt is paid as slower feature development, more bugs, and harder onboarding in the future. The problem isn't debt itself; it's unmanaged debt. Fowler's quadrant captures the distinction: *prudent deliberate* debt — 'we ship now and refactor after launch' — is manageable if you follow through. *Reckless* debt — skipping tests, ignoring design, copy-pasting — is dangerous because the interest compounds without a payback plan. Bad code in a component that never changes and causes no pain may not be worth paying back at all; bad code in a critical path that is touched every sprint is costing you every week. The question is always: what is the cost of the debt versus the cost of the fix?"

> *The mortgage analogy resonates with non-technical interviewers and business-minded engineers alike.*

**Gotcha follow-up:** *"How do you decide which debt to prioritise paying back?"**
> "By combining two factors: the pain it causes now and the likelihood of change. A messy component that nobody touches and never changes costs almost nothing to leave alone. A messy component on the critical checkout flow that every engineer fears modifying costs you on every feature that touches it. I prioritise debt that sits on high-churn, high-criticality code paths. I frame it as: the cost of the debt per month in developer time or risk, versus the cost of fixing it. If the payback period is under three months, it is usually worth doing."

---

**Design Scenario**
**"How would you make the case for a refactoring project to a product manager?"**

**One-line answer:** Translate the debt into business metrics — developer-hours wasted, conversion impact, deployment risk — with a payback period.

**Full answer:**
> "Product managers optimise for business outcomes, not code quality. Speaking about 'high cyclomatic complexity' lands with no one outside engineering. The frame that works is: current cost, fix investment, payback. For example: 'Our search endpoint takes 800ms. Industry data shows each 100ms of latency costs roughly 1% conversion. Refactoring the query layer would bring it to 200ms — a projected 6% conversion gain on the search-to-purchase funnel. The refactor is two engineer-weeks. At our current revenue, the payback period is six weeks.' That is a feature with a return on investment, not 'cleaning up code.' For operational risk debt — like the payment service with no integration tests — the frame is: 'Every deployment requires two hours of manual smoke testing. Twenty percent of deployments trigger a manual rollback costing four hours each. That is over fifty developer-hours a month. Two weeks to build integration tests pays back in under two months, and eliminates the risk of a payment regression in production.'"

> *Having the structure memorised — current cost / fix investment / payback / risk if ignored — lets you build the case on the spot for any debt item.*

---

**Tradeoff Question**
**"What metrics would you use to detect and track technical debt?"**

**One-line answer:** Cyclomatic complexity, test coverage, code duplication, dependency freshness, and DORA metrics — because debt manifests as slow delivery and high failure rate.

**Full answer:**
> "Static analysis tools like SonarQube surface: *cyclomatic complexity* — the number of independent code paths through a method; anything above ten is hard to test and maintain. *Code coverage* — low coverage on critical paths means changes are risky; I treat below sixty percent on business-critical code as implicit debt. *Code duplication* — copy-pasted logic means a bug fix or rule change must be applied in multiple places; SonarQube quantifies this as a percentage. *Dependency freshness* — outdated libraries with known CVEs are security debt accruing interest every day. The most important signals come from *DORA metrics* — Deployment Frequency, Lead Time for Changes, Mean Time to Recovery, and Change Failure Rate. These are the fingerprints of accumulated debt in production: a team that deploys infrequently because deployments are risky, takes weeks to ship small changes because the codebase resists modification, and spends significant time on rollbacks has a debt problem even if SonarQube looks clean."

> *DORA metrics is a senior-level signal — knowing them shows you think about debt systemically, not just at the code level.*

---

**Concept Check**
**"What is the Boy Scout Rule in software and how does it relate to debt?"**

**One-line answer:** Always leave the code slightly better than you found it — a continuous practice that prevents debt from compounding faster than it is paid.

**Full answer:**
> "The Boy Scout Rule — 'always leave the campsite cleaner than you found it' — applied to code means: whenever you touch a file, make a small improvement. Rename a confusing variable. Extract a long method. Add a missing test for the function you just modified. None of these are big refactoring projects; each takes minutes. The compounding benefit is that the areas of the codebase that are touched most often — the high-churn paths — steadily improve, because those are the places where the rule is applied most frequently. Debt naturally concentrates on frequently changed code; the Boy Scout Rule targets precisely those areas. The alternative — waiting to schedule a dedicated refactoring sprint — rarely happens; product backlogs are long and 'refactoring' never wins against features in priority ordering. Continuous small improvements embedded in feature work are more sustainable."

> *Contrasting it with "refactoring sprints that never happen" is the realistic observation that resonates with experienced interviewers.*

---

> **Common Mistake — Calling everything "technical debt":** Not every imperfection is debt. Calling poorly structured code that was never going to cause pain "debt" dilutes the term and leads to refactoring work with no business justification. True technical debt has an *interest rate* — it costs you something measurable over time. If a piece of messy code in a stable, never-touched module has zero carrying cost, leaving it alone is the correct engineering decision. Reserve the term for debt that actually slows you down.

---

**Quick Revision:** Technical debt is the future cost of a deliberate shortcut; it compounds like financial interest; prudent debt taken consciously with a payback plan is manageable, while reckless debt is dangerous; always translate it into business terms — developer-hours wasted, risk, or revenue impact — when making the case to stakeholders.

