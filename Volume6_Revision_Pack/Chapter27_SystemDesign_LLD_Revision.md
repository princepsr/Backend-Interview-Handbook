# Volume 6: Revision Pack
# Chapter 27: System Design & LLD Revision

> **Cross-references:** Chapter 19 (Design Patterns), Chapter 20 (SOLID & Clean Architecture), Chapter 21 (LLD Case Studies), Chapter 22 (System Design HLD)

---

## Table of Contents

1. [Design Patterns — Interview Questions](#section-1-design-patterns--interview-questions)
2. [SOLID Principles — Interview Questions](#section-2-solid-principles--interview-questions)
3. [LLD Case Studies — Interview Questions](#section-3-lld-case-studies--interview-questions)
4. [System Design HLD — Interview Questions](#section-4-system-design-hld--interview-questions)
5. [Latency Numbers Every Engineer Should Know](#section-5-latency-numbers-every-engineer-should-know)
6. [Capacity Estimation Cheat Sheet](#section-6-capacity-estimation-cheat-sheet)
7. [100 Mock Interview Q&As](#section-7-100-mock-interview-qas)
8. [Interview Day Checklist](#section-8-interview-day-checklist)

---

> **How to read this chapter:** This is your final revision chapter — pure Interview Lens. Each question has a one-line answer (for quick recall) and a full speakable answer (for the actual interview). All technical terms are explained inline so you never get stuck mid-answer. Read the checklists the night before your interview.

---
## Section 1: Design Patterns

---

**Q1: Singleton — Thread-Safe Variants**
*Concept Check*

**One-line answer:** Use Enum Singleton for the safest implementation; use Double-Checked Locking with `volatile` when lazy initialization is needed; use the Holder pattern when you want laziness without synchronization overhead.

**Full answer:**
The Singleton pattern ensures that only one instance of a class exists in the JVM. The naive approach of checking `if (instance == null)` and then creating the instance breaks under concurrent access — two threads can both see `null` and both create separate instances. Double-Checked Locking (DCL) fixes this: I declare the field as `private static volatile Singleton instance`, check for null outside a `synchronized` block, then check again inside. The `volatile` keyword is critical here — without it, the JVM's instruction reordering optimization can allow a partially constructed object to be visible to other threads before its constructor has finished running. My preferred approach in production is the Enum Singleton: I declare `public enum Singleton { INSTANCE; }` and get thread safety for free because the JVM guarantees each enum value is initialized exactly once. It is also safe against Java serialization (which would otherwise create a new instance when deserializing) and against reflection attacks (which can bypass `private` constructors). When I need lazy initialization without any synchronization overhead, I use the Holder pattern: a private static inner class `Holder` with a `static final` field holds the instance. JVM class loading guarantees that `Holder` is only loaded when `Holder.INSTANCE` is first accessed, and class loading is inherently thread-safe, so no `synchronized` or `volatile` is needed.

*Lead with the Enum Singleton as your preference and explain why it defeats serialization and reflection attacks — those are the two gotchas most candidates miss.*

> **Gotcha follow-up:** Why is `volatile` necessary in Double-Checked Locking, and what exactly breaks without it?
> Without `volatile`, the JVM can reorder the three steps of object construction: allocate memory, invoke constructor, assign reference. If the reference is assigned before the constructor finishes, another thread can read a non-null but partially initialized object from the `if (instance == null)` check and start using it — causing subtle, hard-to-reproduce bugs. `volatile` enforces a happens-before relationship, preventing any reorder across the assignment.

---

**Q2: Factory vs Abstract Factory**
*Concept Check*

**One-line answer:** Factory Method creates one product type whose concrete class is decided at runtime; Abstract Factory creates a family of related products that must be compatible with each other.

**Full answer:**
The Factory Method pattern addresses the problem where I know I need to create an object of a certain interface, but the exact concrete class to instantiate depends on runtime conditions — for example, `ShapeFactory.create("circle")` returns a `Shape` implementation without the caller knowing whether it is a `Circle` or an `Ellipse`. Each subclass of the factory is responsible for one product type. The Abstract Factory pattern steps up when I need to create multiple related objects that must all belong to the same family — for example, a `GUIFactory` that creates both a `Button` and a `Checkbox`. If I use `WindowsGUIFactory`, I get a `WindowsButton` and a `WindowsCheckbox`; if I switch to `MacGUIFactory`, I get both Mac-flavored components. The key guarantee is product compatibility: I can never accidentally mix a `WindowsButton` with a `MacCheckbox` because the factory enforces the family. I choose Factory Method when the product family has just one type and the subclass decides the variant. I choose Abstract Factory when consistency across multiple product types within a family is a hard requirement — like theming an entire UI, where mixing widget styles would be a bug.

*The clearest way to explain the difference is the "family" word: Abstract Factory guarantees all created objects are from the same family.*

> **Gotcha follow-up:** Can Factory Method and Abstract Factory be combined?
> Yes — an Abstract Factory is typically implemented using multiple Factory Methods, one per product type. The Abstract Factory interface defines `createButton()` and `createCheckbox()`, and each concrete factory subclass implements both using the Factory Method pattern. So Abstract Factory is really a compositional pattern built on top of Factory Method.

---

**Q3: Builder vs Telescoping Constructor**
*Concept Check*

**One-line answer:** Replace telescoping constructors — constructors with ever-growing parameter lists — with the Builder pattern when you have four or more parameters, especially when many are optional.

**Full answer:**
A telescoping constructor is what happens when I keep adding overloads: `new Pizza(size)`, `new Pizza(size, cheese)`, `new Pizza(size, cheese, pepperoni)`, and so on. By the time I have six parameters, the call site `new Pizza("large", true, false, true, false, true)` is completely unreadable — it is impossible to tell what each boolean means without looking at the constructor signature. The Builder pattern solves this with a fluent API: `new Pizza.Builder("large").cheese(true).pepperoni(true).build()`. Each step is named, optional parameters can be omitted, and the object is immutable once `build()` is called. I prefer Builder when there are four or more parameters, when many of them are optional, or when I want to enforce immutability on the final object. The Director pattern, an optional addition, encapsulates a common build sequence — for example, `PizzaDirector.buildMargherita(builder)` hides the exact steps from the client so they do not need to know the correct order of calls. This is especially useful when the same product can be built in multiple standard configurations.

*Mention immutability as a key benefit of Builder — it shows you think about thread safety.*

> **Gotcha follow-up:** What is the difference between Builder and the Director, and when do you need the Director?
> Builder is the mechanism — it provides the fluent API and holds the state while the object is being constructed. Director is an optional orchestrator that defines named build sequences using the Builder. I add a Director when multiple clients need to build the same standard configurations repeatedly and I do not want to duplicate the sequence of builder calls across those clients.

---

**Q4: Adapter vs Decorator vs Proxy**
*Tradeoff Question*

**One-line answer:** Adapter changes the interface; Decorator keeps the same interface and adds new behavior; Proxy keeps the same interface and controls or intercepts access.

**Full answer:**
These three patterns are easy to confuse because all three involve wrapping an object, but their purposes are distinct. The Adapter pattern is for interface translation — I have a legacy XML-based API and a new consumer that expects JSON, so I write an `XmlToJsonAdapter` that wraps the old API and exposes the new interface. The client never knows it is talking to legacy code. The Decorator pattern is for behavioral composition — I have a `FileInputStream` and I want to add buffering, so I wrap it in `BufferedInputStream`, which implements the same `InputStream` interface. I can stack decorators: `new DataInputStream(new BufferedInputStream(new FileInputStream(...)))` — each layer adds a behavior without changing the interface or subclassing. The Proxy pattern is for access control and interception — the proxy implements the same interface as the real object but intercepts calls to add cross-cutting concerns like transaction management, security checks, or lazy loading. Spring's `@Transactional` and `@Cacheable` are both implemented as proxies. The key rule I use: if it changes the interface, it is an Adapter; if it keeps the interface and adds functionality, it is a Decorator; if it keeps the interface and controls or wraps access, it is a Proxy.

*Lead with the one-line rule — interviewers love crisp distinctions. Then give the concrete examples.*

> **Gotcha follow-up:** Can a class be both a Decorator and a Proxy at the same time?
> Technically yes — if a class wraps an object with the same interface, adds some behavior (like logging), and also controls access (like checking permissions), it exhibits characteristics of both. In practice, the distinction is about intent: name it a Proxy when the primary purpose is access control or interception, and a Decorator when the primary purpose is capability extension.

---

**Q5: Observer — Push vs Pull**
*Concept Check*

**One-line answer:** Push sends full event data to observers; Pull sends a minimal notification and lets observers fetch only what they need — Pull is more decoupled.

**Full answer:**
The Observer pattern defines a one-to-many dependency so that when one object (the Subject) changes state, all its dependents (Observers) are notified automatically. The implementation choice is whether the Subject pushes data to observers or observers pull it. In the Push model, the Subject packages up all the relevant data and sends it in the notification event itself. This is simpler to implement, but observers receive more data than they may need, and if the event payload grows over time, all observers are forced to handle the larger structure even if they only care about one field. In the Pull model, the Subject sends a minimal notification — often just a reference to itself or an event type — and each Observer calls back into the Subject to fetch only the specific data it needs. This makes observers more decoupled from the Subject's internal structure; the Subject can change its internals without breaking observers that never pull the changed field. Spring's `ApplicationEventPublisher` follows a pull-style model — it publishes an `ApplicationEvent` object, and each listener reads only the fields it cares about. For most event-driven systems I prefer Pull because it keeps observers and subjects independently evolvable.

*Mention Spring ApplicationEventPublisher — it signals real-world familiarity.*

> **Gotcha follow-up:** What problem does the Observer pattern introduce at scale, and how do you mitigate it?
> At scale, synchronous observer notification blocks the Subject until all observers finish processing — if one observer is slow, the entire notification chain is delayed. The fix is to notify asynchronously via a message queue or thread pool, effectively converting synchronous observer calls into asynchronous events. This also prevents a failing observer from crashing the Subject.

---

**Q6: Strategy vs Template Method**
*Tradeoff Question*

**One-line answer:** Use Strategy (composition) when the algorithm must be swappable at runtime; use Template Method (inheritance) when the algorithm structure is fixed and only individual steps vary.

**Full answer:**
Both patterns are about making parts of an algorithm variable, but they use different mechanisms and have different flexibility. Strategy uses composition with a Has-a relationship: my `SortContext` holds a reference to a `SortStrategy` interface, and at runtime I inject `new QuickSortStrategy()` or `new MergeSortStrategy()`. I can swap the algorithm without touching `SortContext` at all — even at runtime if needed. Template Method uses inheritance with an Is-a relationship: my `AbstractReport` class defines a `generate()` method that calls `fetchData()` and `formatOutput()` in a fixed sequence, but these are abstract methods that subclasses must implement. The skeleton of the algorithm is locked in the parent class; subclasses customize individual steps by overriding them. I choose Strategy when I want to be able to change the algorithm without modifying the context class — ideal when algorithms need to vary per user, per environment, or per configuration. I choose Template Method when the algorithm structure itself is invariant and all I want to vary is specific sub-steps — like a data export pipeline that always validates, then transforms, then writes, but each step differs by export format. Strategy is generally more flexible because it avoids the fragile base class problem that inheritance introduces.

*Mention "fragile base class" — it shows awareness of the OOP inheritance pitfall.*

> **Gotcha follow-up:** Can Strategy and Template Method be combined?
> Yes — the Template Method in the abstract class can call a strategy injected into the class. For example, `AbstractReport.generate()` defines the skeleton, but one of its steps like `sortData()` delegates to an injected `SortStrategy`. This gives you the fixed structure of Template Method with the runtime flexibility of Strategy for the steps that genuinely need it.

---

**Q7: Chain of Responsibility**
*Concept Check*

**One-line answer:** Chain of Responsibility decouples the sender of a request from its receiver by passing the request through a chain of handlers, each deciding to process it or pass it along.

**Full answer:**
In Chain of Responsibility, each handler object holds a reference to the next handler in the chain. When a request arrives, the handler either processes it and stops, processes it and passes it on, or skips processing and passes it straight to the next. This means the sender does not need to know which handler will ultimately handle the request — it just sends to the head of the chain. I use this pattern whenever I have a pipeline of processing steps where the set of steps may vary or each step needs to independently decide whether it applies. Servlet Filters in Java EE are a classic example: each Filter calls `chain.doFilter()` to pass the request to the next filter or finally to the servlet. Spring Security's Filter Chain works the same way — authentication, authorization, CSRF protection, and session management are all separate handlers chained together. Middleware pipelines in frameworks like Express.js follow the same model. The key design consideration is handler ordering — a security filter must run before an authorization filter, and an authentication filter must run before a business logic filter. I also watch for chains that grow too long, because every request must traverse all handlers, which adds latency.

*Servlet Filters and Spring Security Filter Chain are the killer real-world examples here.*

> **Gotcha follow-up:** What happens if no handler in the chain handles the request?
> If the chain reaches the end without any handler processing the request, the request is silently dropped — which is usually a bug. I handle this by adding a default handler at the end of the chain that either throws an exception, returns a 400/404 response, or logs and discards. Making the chain termination explicit prevents hard-to-debug silent failures.

---

**Q8: Command Pattern — Undo/Redo**
*Concept Check*

**One-line answer:** Command encapsulates a request as an object with `execute()` and `undo()` methods, enabling undo/redo via a stack of executed commands.

**Full answer:**
The Command pattern converts an action into a standalone object that contains all information needed to perform that action — the target object (Receiver), the method to call, and the arguments. The structure has four roles: the Invoker (which triggers commands), the Command interface (with `execute()` and `undo()`), the ConcreteCommand (which implements both), and the Receiver (which does the actual work). This encapsulation is what makes undo/redo straightforward: I maintain two stacks — an undo stack and a redo stack. When I execute a command, I push it onto the undo stack. When the user triggers undo, I pop the top command and call its `undo()` method, then push it onto the redo stack. Redo pops from the redo stack and calls `execute()` again. Text editors implement Ctrl+Z and Ctrl+Y this way. Beyond undo/redo, the Command pattern enables other powerful features: I can serialize commands to a queue for asynchronous execution, replay a log of commands to rebuild state, or schedule commands for later. Transaction managers use Command to batch database operations and roll back on failure.

*Name the four roles explicitly — Invoker, Command, ConcreteCommand, Receiver — it shows structural clarity.*

> **Gotcha follow-up:** What is the difference between Command and Strategy?
> Both encapsulate behavior, but their purposes differ. A Strategy encapsulates an interchangeable algorithm that is selected once and used repeatedly by a context. A Command encapsulates a single discrete action with intent to execute it once — and crucially, commands have state that captures enough information to undo the action, which strategies do not need.

---

**Q9: State Pattern — FSM**
*Concept Check*

**One-line answer:** The State pattern models a Finite State Machine (FSM) — a system with a fixed set of states and defined transitions — by representing each state as a separate class that encapsulates its own behavior.

**Full answer:**
Without the State pattern, objects that change behavior based on internal state are typically implemented with large `if-else` or `switch` blocks — `if (currentState == PAID) { ... } else if (currentState == SHIPPED) { ... }`. These blocks grow with every new state and scatter the logic for each state across the entire method. The State pattern replaces this with a class per state, each implementing a common `State` interface. The context object (e.g., `Order`) delegates behavior to its current state object and transitions by replacing the state reference. For an e-commerce order, I model states as `NewState`, `PaidState`, `ShippedState`, `DeliveredState`, and `CancelledState`. When `order.pay()` is called, the `NewState` handles it by transitioning the order to `PaidState`. If `pay()` is called on a `ShippedState`, it throws an `InvalidStateTransitionException`. This makes state-specific logic explicit and co-located, eliminates illegal state transitions by design, and makes adding new states easy — I add a new class without modifying existing state classes. I use this pattern for workflow engines, TCP connection lifecycle management, vending machines, elevator controllers, and anywhere else state-dependent behavior would otherwise produce a complex conditional tree.

*Mention FSM explicitly — many interviewers will follow up on it, and naming it shows systems-level thinking.*

> **Gotcha follow-up:** How do you prevent invalid state transitions?
> Each state class only implements the transitions that are legal from that state. For all other method calls, the state class either does nothing (no-op) or throws an `UnsupportedOperationException` or a domain-specific `InvalidStateTransitionException`. The key is that the State class itself enforces what is and is not legal — the context does not need any if-else guards.

---

**Q10: Composite Pattern**
*Concept Check*

**One-line answer:** Composite lets clients treat individual objects (Leaves) and groups of objects (Composites) uniformly through the same interface, enabling recursive tree structures.

**Full answer:**
The Composite pattern is built around a shared `Component` interface that both Leaf nodes (which have no children) and Composite nodes (which have a list of children) implement. A client calling `component.getSize()` does not need to know whether it is dealing with a single file or a directory tree — the call recurses automatically through the tree. In a file system, both `File` and `Directory` implement `FileSystemItem`, and `Directory.getSize()` sums the sizes of all its children recursively, while `File.getSize()` just returns its own size. The beauty is that the client code is the same regardless of depth or structure — I can build arbitrarily deep hierarchies and the traversal is implicit. I use Composite in UI frameworks (a `Panel` contains `Button`, `Label`, or other `Panel` components, all implementing `UIComponent`), organizational charts (a `Manager` has `Employee` reports, some of whom are also `Manager` instances), and menu systems (a `Menu` can contain `MenuItem` or nested `Menu` objects). The main design question is whether to make child management methods (`add()`, `remove()`, `getChildren()`) part of the `Component` interface or only on `Composite`. Putting them on `Component` is more transparent but requires Leaves to handle them (by doing nothing or throwing), which can be confusing.

*The file system example is universal — use it, then mention one other domain to show breadth.*

> **Gotcha follow-up:** What is the transparency vs safety tradeoff in Composite?
> Transparency means putting `add()` and `remove()` on the `Component` interface so all nodes look the same to clients. Safety means putting those methods only on `Composite`, making it a compile-time error to call them on a Leaf. Transparency is simpler for clients but requires Leaves to handle or reject those calls at runtime. Safety catches errors earlier but requires clients to cast to `Composite` when they need to manage children, which breaks uniformity.

---

**Q11: Spring AOP — Proxy + Decorator**
*Concept Check*

**One-line answer:** Spring AOP wraps beans in proxies that intercept method calls to apply cross-cutting concerns — `@Transactional`, `@Cacheable`, and `@Async` all work this way, but they break on self-invocation.

**Full answer:**
Spring's AOP (Aspect-Oriented Programming) framework is a concrete application of the Proxy pattern. When I annotate a method with `@Transactional`, Spring does not modify my class — instead, it creates a proxy object that wraps my bean. For interfaces, Spring uses a JDK Dynamic Proxy, which is a runtime-generated class that implements the same interface and intercepts all method calls. For concrete classes without an interface, Spring uses CGLIB, a bytecode manipulation library that generates a subclass at runtime. When my code calls `myService.save()`, it is actually calling `proxy.save()`, which starts a transaction, delegates to `myService.save()`, and then commits or rolls back. This is exactly the Proxy pattern's access control and interception role, layered with Decorator-like behavioral addition. The critical gotcha is self-invocation: if inside `MyService`, I call `this.save()`, the call goes directly to the real object, bypassing the proxy entirely. The `@Transactional` annotation on that method is silently ignored. The fix is to inject the proxy reference: `applicationContext.getBean(MyService.class).save()` or `AopContext.currentProxy()` with `exposeProxy = true` configured.

*The self-invocation gotcha is a very common interview follow-up — lead with the problem and the fix.*

> **Gotcha follow-up:** Why does CGLIB subclassing have limitations that JDK proxy does not?
> CGLIB creates a subclass, so it cannot proxy `final` classes or `final` methods — subclassing is blocked by the compiler for both. JDK Dynamic Proxy creates an implementor of the interface, so it works as long as the type has an interface. If a Spring bean is a concrete class with no interface, Spring falls back to CGLIB, and any `final` methods on that class will not be proxied — aspects on those methods will silently not apply.

---

**Q12: Java I/O — Decorator Pattern**
*Concept Check*

**One-line answer:** Java's `InputStream` hierarchy is a textbook Decorator implementation — each wrapper class adds behavior while keeping the same `InputStream` interface.

**Full answer:**
Java I/O is the most frequently cited real-world example of the Decorator pattern in action. The base interface is `InputStream`. `FileInputStream` is a Leaf — it reads raw bytes from a file. Wrapping it with `BufferedInputStream` adds an internal byte buffer, reducing expensive filesystem system calls by reading chunks at a time — but it still implements `InputStream`, so the caller's code is unchanged. Wrapping further with `DataInputStream` adds typed reading methods like `readInt()` and `readUTF()` — again, without changing the interface. The composed stack `new DataInputStream(new BufferedInputStream(new FileInputStream("data.bin")))` gives me typed, buffered file reading. Each wrapper is a Decorator: it holds a reference to another `InputStream`, it delegates the base `read()` call to the inner stream, and it adds its own behavior before or after the delegation. The alternative to this pattern would be combinatorial subclassing — `BufferedFileInputStream`, `TypedBufferedFileInputStream`, `TypedFileInputStream` — which would explode into an unmanageable class hierarchy. Decorator avoids this by composing behavior at runtime through wrapping. This is also exactly how HTTP servlet filters, Spring interceptors, and middleware pipelines work structurally.

*Connect Java I/O back to real systems — middleware and filter pipelines — to show the pattern's generality.*

> **Gotcha follow-up:** What is the downside of deeply nested Decorators?
> Deep nesting makes debugging harder — a stack trace shows multiple wrapper classes between the caller and the underlying operation, and it can be difficult to determine which decorator is responsible for a bug. Configuration is also verbose: constructing `new D(new C(new B(new A(...))))` by hand is error-prone. Frameworks typically solve this with a builder or factory that constructs the chain, hiding the nesting from clients.

---

**Q13: When to Use Each Pattern**
*Concept Check*

**One-line answer:** Match the pattern to the problem: Singleton for shared resources, Factory for variable creation, Builder for complex objects, Adapter for interface mismatch, Decorator for added behavior, Proxy for access control, Observer for events, Strategy for swappable algorithms.

**Full answer:**
I think about patterns as solutions to recurring structural or behavioral problems, not as things to apply for their own sake. For shared resources — a database connection pool, a configuration registry, a logger — Singleton ensures one instance, but I use the framework-managed scope (`@Bean` with `@Scope("singleton")`) rather than rolling my own. For creation that varies by type, I use Factory Method; for creation that must stay consistent across a product family, I use Abstract Factory. When an object has too many constructor parameters, Builder gives me readability and immutability. When I inherit third-party or legacy code with the wrong interface, Adapter bridges the gap without changing either side. When I want to add capabilities — logging, caching, retry — without subclassing, Decorator lets me compose them at runtime. When I need access control, lazy loading, or AOP interception, Proxy wraps the real object. When multiple objects need to react to state changes in one object, Observer decouples them. When an algorithm needs to be swappable — payment method, compression algorithm, sorting strategy — Strategy externalizes the varying part. When behavior changes based on internal state, State replaces if-else chains. For hierarchical structures where individual and composite items need uniform treatment, Composite. For pipeline processing where each step decides to handle or pass along, Chain of Responsibility. For undo/redo and queuing, Command.

*Frame it as: "I choose patterns based on the problem, not the pattern." That signals maturity.*

> **Gotcha follow-up:** Can overusing patterns become an anti-pattern itself?
> Yes — applying a pattern where it adds complexity without solving a real problem is the "Golden Hammer" anti-pattern: using a familiar tool for everything. A two-class system does not need Abstract Factory. Adding Observer to a synchronous single-thread utility adds indirection without benefit. Patterns are solutions to specific recurring problems; the right question is always "what problem am I actually solving?" before reaching for a pattern.

---

**Q14: Anti-Patterns**
*Concept Check*

**One-line answer:** Anti-patterns are recurring bad solutions — God Object, Spaghetti Code, Golden Hammer, Lava Flow, and Premature Optimization are the most common in backend codebases.

**Full answer:**
A God Object is a class that knows too much and does too much — it violates the Single Responsibility Principle and becomes a change magnet, a testing bottleneck, and a merge conflict hotspot. The fix is to identify each distinct responsibility and extract it into its own class. Spaghetti Code is tangled, unstructured control flow — deeply nested conditionals, methods that span hundreds of lines, logic scattered randomly — making it nearly impossible to trace what the code does. I fix it by extracting methods and classes, introducing clear abstractions, and writing tests as a safety net before refactoring. Golden Hammer is the cognitive bias of applying the tool I know best to every problem — "if all you have is a hammer, everything looks like a nail." It produces inappropriate solutions: using a relational database for a graph problem, or a Singleton everywhere. The fix is to consciously assess the problem requirements before selecting a solution. Lava Flow refers to dead or legacy code that nobody dares delete out of fear that something will break — it accumulates over time and buries the codebase in confusion. The fix is test coverage: once tests prove what the live code does, dead code can be safely deleted. Premature Optimization is optimizing before measuring — spending days micro-optimizing code that is not the bottleneck. The rule is: write clear, correct code first; profile to find the actual hotspot; optimize only that.

*"Write correct first, then profile, then optimize the hot path" is a memorable and defensible line.*

> **Gotcha follow-up:** How do you identify a God Object in a real codebase?
> I look for classes with high afferent coupling (many other classes depend on them), a large number of methods, and methods whose names span multiple unrelated domains — like a single class with `processPayment()`, `sendEmail()`, `generateReport()`, and `updateUserProfile()`. High cyclomatic complexity (many branching paths) and difficulty writing focused unit tests without mocking many dependencies are also strong signals.

---

**Q15: Pattern Interview Traps**
*Tradeoff Question*

**One-line answer:** The most common pattern interview traps are: "Singleton is an anti-pattern in microservices," "combine Strategy and Factory," and "Decorator beats inheritance for behavior extension."

**Full answer:**
The Singleton-in-microservices trap: when an interviewer says "Singleton is an anti-pattern," I agree with important nuance. In a distributed microservices system, each service instance has its own JVM, so a Singleton only guarantees one instance per JVM process, not one instance per entire system. If I rely on Singleton for globally shared mutable state — like a request counter — I will get one counter per pod, not one system-wide counter. The correct approach is a DI-container-managed singleton scoped to the application context (which is what Spring `@Bean` gives me by default), plus distributed coordination via Redis or ZooKeeper when true system-wide uniqueness is needed. The Strategy + Factory combination trap: these two patterns pair naturally. A `PaymentStrategyFactory` inspects the payment method type and returns the correct `PaymentStrategy` — `CreditCardStrategy`, `UPIStrategy`, or `WalletStrategy`. The factory handles the creation decision; the strategy handles the execution. The Decorator-vs-inheritance trap: if I want an object that is both logged and cached and retried, using inheritance I need `LoggedAndCachedAndRetriedService` — a combinatorial explosion. Using Decorator I compose: `new RetryDecorator(new CacheDecorator(new LoggingDecorator(realService)))` — three separate, independently testable decorators combined at runtime. Decorator scales with the number of combinations; inheritance does not.

*These three are the traps most likely to appear in a senior interview — nail all three.*

> **Gotcha follow-up:** Why is Decorator more testable than inheritance for cross-cutting concerns?
> With inheritance, the combined behavior is baked into the subclass — to test caching in isolation I have to test through the full subclass hierarchy. With Decorator, each decorator is a standalone class that wraps any `Service` interface — I can unit-test `CacheDecorator` by passing in a mock `Service`, completely isolated from logging or retry logic.

---

**Common Mistakes:**
- **Singleton with double-checked locking but no `volatile`** → partially constructed objects are visible to other threads, causing subtle runtime corruption; always mark the field `volatile` or switch to Enum Singleton.
- **Using Decorator when you need Adapter** → the interface mismatch is not resolved; the wrapped object is still incompatible with the caller's expected type.
- **Calling `@Transactional` methods from within the same class** → self-invocation bypasses the Spring proxy; the transaction is silently not created; inject self or use `AopContext.currentProxy()`.
- **Long Chain of Responsibility with no terminal handler** → requests silently fall off the end; always add a default terminal handler that makes the "no match" case explicit.
- **Builder without enforcing required fields** → `build()` produces an object in an invalid state; enforce required fields either in the Builder constructor or with null checks in `build()`.

**Quick Revision:** Three wrapper patterns — Adapter changes the interface, Decorator adds behavior, Proxy controls access. One wrapper, three jobs.

---

## Section 2: SOLID Principles

---

**Q1: Single Responsibility Principle (SRP)**
*Concept Check*

**One-line answer:** A class should have one reason to change, meaning it serves one actor — not "does only one thing," but answers to only one stakeholder's requirements.

**Full answer:**
SRP is often misunderstood as "a class should only do one thing," but the precise definition from Robert Martin is that a module should have one reason to change — it should serve one actor, meaning one group of people whose requirements might drive a change. Consider a `UserService` that handles authentication, sends registration emails, and persists user records. If the security team changes password hashing requirements, if the marketing team changes email templates, and if the DBA changes the schema, all three different stakeholders force changes to the same class. That is three reasons to change — a clear SRP violation. The fix is to split into `AuthService` (serves the security team's requirements), `EmailNotificationService` (serves marketing), and `UserRepository` (serves the data team). Each class now changes for only one reason. In practice I identify SRP violations by asking: "who are the different people who would ask me to change this class?" If the answer involves multiple distinct stakeholder groups — product, security, infrastructure, finance — the class has too many responsibilities. High cohesion (all methods and fields relate to the same purpose) is the positive signal that SRP is being respected.

*Lead with the "one reason to change / one actor" definition, not just "does one thing" — it is more precise and interviewers reward it.*

> **Gotcha follow-up:** Does SRP mean every class should be tiny and have only one method?
> No — SRP is about cohesion, not size. A class can have twenty methods and fully comply with SRP if all twenty methods serve the same actor and the same responsibility. Splitting a logically cohesive class into tiny fragments just for the sake of smallness creates unnecessary indirection. The question is always about reasons to change, not lines of code.

---

**Q2: Open/Closed Principle (OCP)**
*Concept Check*

**One-line answer:** Software entities should be open for extension but closed for modification — add new behavior by adding new code, not by editing existing code.

**Full answer:**
The Open/Closed Principle means that when requirements change and I need to add new behavior, I should be able to do so without touching tested, deployed code. A classic violation is a `DiscountCalculator` with `if (type == "STUDENT") ... else if (type == "SENIOR") ... else if (type == "EMPLOYEE") ...` — every new customer type requires editing the existing method, risking regressions. The OCP fix is to define a `DiscountStrategy` interface with a `calculate(price)` method, and make each discount type a separate class implementing that interface. Adding a new type means adding a new class — zero changes to `DiscountCalculator`. OCP is what enables plugin architectures: the core system defines interfaces (extension points), and new functionality ships as new implementations of those interfaces without touching the core. In Java, I achieve OCP through interfaces and polymorphism, Strategy and Template Method patterns, and in Spring through dependency injection — the context wires the right implementation at startup without the core class knowing. The principle also applies at the module level: a well-designed library exposes extension points (abstract classes, interfaces, hooks) so consumers can extend behavior without forking the library's source code.

*OCP enables plugin architecture — that phrase resonates strongly in senior interviews.*

> **Gotcha follow-up:** Is OCP always achievable in practice?
> Not perfectly — anticipating every possible extension point upfront leads to over-engineering and speculative abstraction. The pragmatic approach is to apply OCP retroactively: the first time I modify a class for a new requirement, I refactor it to be open for that kind of extension. On the second change of the same type, I already have the abstraction in place. This avoids building extension points nobody uses.

---

**Q3: Liskov Substitution Principle (LSP)**
*Concept Check*

**One-line answer:** If `S` is a subtype of `T`, then everywhere a `T` is used, an `S` can be substituted without breaking the program's correctness.

**Full answer:**
LSP is the principle that makes polymorphism actually safe. The classic violation is `Square extends Rectangle`. A `Rectangle` has independent `setWidth()` and `setHeight()` methods, and code that uses `Rectangle` might rely on the contract: "after `setWidth(5)` and `setHeight(10)`, `getArea()` returns 50." A `Square` cannot honor this contract — because a square's sides must be equal, `setWidth(5)` must also set the height to 5, so `getArea()` returns 25, not 50. The client's expectation is broken. Substituting a `Square` for a `Rectangle` produces incorrect behavior — a direct LSP violation. The fix is to not model `Square` as a subtype of `Rectangle` at all, because squares do not satisfy the behavioral contract that rectangles establish. More broadly, LSP violations show up when a subclass overrides a method in a way that narrows preconditions, weakens postconditions, or throws exceptions the base class does not. I detect LSP violations by asking: "could any code that works correctly with the base class break when I hand it an instance of this subclass?" If the answer is yes, the inheritance relationship is wrong. Sometimes the fix is to use composition instead of inheritance, or to redesign the hierarchy from scratch.

*The Square-Rectangle example is the canonical one — walk through the arithmetic explicitly to show you fully understand why the contract breaks.*

> **Gotcha follow-up:** How does LSP relate to the `instanceof` smell?
> Code that uses `instanceof` to branch behavior based on the actual runtime type of an object is a strong signal that LSP is being violated. If the caller needs to check "is this actually a Square?" before using it as a Rectangle, the substitution is not transparent — the caller cannot treat subtypes uniformly. The fix is usually to move the type-specific behavior into the subtype via polymorphism, so the caller never needs to inspect the concrete type.

---

**Q4: Interface Segregation Principle (ISP)**
*Concept Check*

**One-line answer:** Clients should not be forced to depend on methods they do not use — split fat interfaces into smaller, focused ones.

**Full answer:**
ISP says that a large, general-purpose interface forces all implementors to implement methods that may be irrelevant to them. Consider an `IWorker` interface with `work()` and `eat()` — both human workers and robot workers must implement it. A `RobotWorker` has no concept of eating, so its `eat()` implementation is either empty, throws an `UnsupportedOperationException`, or returns a dummy value — all of which are code smells that signal the wrong abstraction. The fix is to split `IWorker` into `IWorkable` with `work()` and `IFeedable` with `eat()`. Human workers implement both; robot workers implement only `IWorkable`. Now each implementor only carries what is relevant to it. ISP also applies at the dependency level: if module A depends on an interface that has twenty methods but only uses three, a change to any of the other seventeen methods could require recompilation or redeployment of A even though it is not affected. Focused interfaces minimize this coupling. In Spring, this is why I prefer injecting a narrow repository interface rather than the full JPA repository — the service only needs the three query methods it uses, and the interface documents exactly what the service depends on.

*The dependency recompilation point is a subtle but impressive addition — it moves beyond the surface.*

> **Gotcha follow-up:** How do you balance ISP against interface proliferation?
> Splitting too aggressively produces dozens of single-method interfaces that fragment related concepts. The guideline is to group methods by the client that uses them: if client A uses methods X and Y together in every call, those two methods belong in the same interface. ISP says "do not force clients to depend on what they don't use" — it does not say "every method needs its own interface." The natural size is the minimal cohesive unit from each client's perspective.

---

**Q5: Dependency Inversion Principle (DIP)**
*Concept Check*

**One-line answer:** High-level modules should not depend on low-level modules — both should depend on abstractions (interfaces), and abstractions should not depend on details.

**Full answer:**
DIP inverts the traditional dependency direction. Without it, my `OrderService` (high-level business logic) directly instantiates `MySQLOrderRepository` (low-level infrastructure detail). This creates a hard coupling: if I want to switch to PostgreSQL, or unit-test `OrderService` without a real database, I cannot — the concrete class is baked in. DIP says `OrderService` should depend on an `OrderRepository` interface, and `MySQLOrderRepository` should implement that interface. Now `OrderService` knows nothing about MySQL — it only knows about the `OrderRepository` contract. This means the direction of the source code dependency is inverted relative to the flow of control: the flow still goes from `OrderService` → `MySQLOrderRepository` at runtime, but the source code dependency goes from `MySQLOrderRepository` → `OrderRepository` interface, and `OrderService` → `OrderRepository` interface. Spring's dependency injection is DIP in action: I annotate `OrderService` with `@Autowired OrderRepository repo`, and the Spring container wires in the concrete implementation at startup. My application code never calls `new MySQLOrderRepository()`. This makes it trivial to inject a `MockOrderRepository` in tests and a `PostgreSQLOrderRepository` in production, with zero changes to `OrderService`.

*"Invert the dependency direction" is the key phrase — make sure to explain what "invert" means concretely.*

> **Gotcha follow-up:** What is the difference between Dependency Inversion and Dependency Injection?
> Dependency Inversion is a design principle — it states that code should depend on abstractions, not concretions. Dependency Injection is a technique for achieving it: instead of a class creating its dependencies with `new`, the dependencies are passed in from the outside (injected) via constructor, setter, or field. DIP defines the goal; DI is one mechanism to implement it. You can have DIP without a DI framework by passing interfaces through constructors manually.

---

**Q6: DRY — Duplication vs Wrong Abstraction**
*Tradeoff Question*

**One-line answer:** DRY (Don't Repeat Yourself) eliminates knowledge duplication, not just code duplication — and premature DRY is worse than duplication because it creates the wrong abstraction.

**Full answer:**
DRY is frequently misunderstood as "never have the same lines of code twice." The actual principle from the Pragmatic Programmer is: "every piece of knowledge must have a single, unambiguous, authoritative representation in the system." Two code blocks that look identical but represent different business rules are not duplicates — they are coincidentally similar but separately owned. Merging them into a shared function creates a coupling between unrelated concepts: when one rule changes, I must add a parameter to the shared function, which now serves two masters and drifts toward a God Function. Sandi Metz's rule of thumb is the Rule of Three: wait until the third occurrence before abstracting. The first time, just write it. The second time, note the duplication. The third time, consider the abstraction. "Duplication is cheaper than the wrong abstraction" is her most quoted line — a wrong abstraction is hard to reverse because code builds on top of it, and every change requires navigating the accidental complexity of the ill-fitting abstraction. The practical test I apply: if I have to add a boolean parameter to a shared function to handle a special case for one caller, the abstraction is wrong — I should split it back into two separate implementations.

*Quoting Sandi Metz adds credibility. The "boolean parameter smell" is a concrete, memorable heuristic.*

> **Gotcha follow-up:** How do you detect the wrong abstraction in an existing codebase?
> The clearest signals are: shared functions with growing lists of boolean or enum parameters to handle edge cases for different callers; comments inside shared functions saying "for caller X, do this, but for caller Y, do that"; and difficulty naming the abstraction precisely because it does the work of two unrelated concepts. When I cannot name it without using "and," it usually does too much.

---

**Q7: Clean Architecture — Dependency Rule**
*Design Scenario*

**One-line answer:** In Clean Architecture, dependencies only point inward — from infrastructure toward the domain — so the inner layers (entities, use cases) have zero knowledge of the outer layers (frameworks, databases, UI).

**Full answer:**
Clean Architecture, popularized by Robert Martin, organizes a system into concentric layers. From outermost to innermost: Frameworks and Drivers (Spring, JPA, HTTP), Interface Adapters (REST controllers, JPA repositories), Application Use Cases (business workflows), and Enterprise Entities (core domain objects and rules). The single governing rule is that source code dependencies only point inward — an outer layer can depend on an inner layer, but never the reverse. This means my `Order` entity class has no `import` of Spring, JPA, or any infrastructure class. My `PlaceOrderUseCase` depends only on abstract `OrderRepository` and `PaymentGateway` interfaces — not on their concrete SQL or Stripe implementations. The concrete implementations live in the outer layers and are injected inward via dependency injection. The practical benefit is that I can test my entire business logic — all use cases and entities — without starting a Spring context, without a database, and without any network calls, because the inner layers have no knowledge of those outer concerns. I can also swap the database from MySQL to MongoDB by replacing only the adapter layer, with zero changes to any use case or entity.

*Emphasize the testability win — it is the most tangible benefit and resonates immediately with interviewers.*

> **Gotcha follow-up:** What is the difference between Clean Architecture and Layered (N-Tier) Architecture?
> Traditional N-Tier layering (UI → Service → Repository → DB) still allows business logic to depend on the ORM framework — the Service layer imports JPA annotations and entity mappings. Clean Architecture's dependency rule forbids this: the domain layer must be framework-agnostic. The direction of dependency is explicitly inverted at the boundary between use cases and infrastructure using interfaces (ports).

---

**Q8: Domain-Driven Design — Aggregates and Invariants**
*Concept Check*

**One-line answer:** An Aggregate is a cluster of domain objects with one root that owns all changes and enforces all invariants, and it defines the transaction boundary.

**Full answer:**
In Domain-Driven Design (DDD), an Aggregate is a group of related objects — entities and value objects — that are treated as a single unit for data changes. The Aggregate Root is the one entity in the cluster that serves as the entry point for all modifications. If I have an `Order` aggregate containing `OrderItems`, I never reach into the aggregate and directly modify `orderItem.setQuantity(3)`. All changes go through `order.updateItemQuantity(itemId, 3)`, and `Order` enforces the invariants — like "total items cannot exceed warehouse capacity" or "you cannot add items to a shipped order." If I allowed direct modification of `OrderItem`, these invariants could be bypassed, leading to an inconsistent domain state. The other critical rule is that an Aggregate defines a transaction boundary: one transaction should modify at most one Aggregate. If a business operation needs to change two Aggregates, those changes should be coordinated asynchronously via domain events, not by wrapping both in a single database transaction. This keeps transactions small and fast, reduces lock contention, and allows Aggregates to live on separate services in a distributed system. In code, I enforce Aggregate boundaries by making the inner entities package-private or by never exposing mutable references to them.

*The "never modify inner entities directly" rule is the key implementation constraint — state it explicitly.*

> **Gotcha follow-up:** How do you handle operations that span multiple Aggregates?
> If operation A must change `OrderAggregate` and `InventoryAggregate` together, I do not put them in the same transaction. Instead, `Order` publishes a domain event `OrderPlaced`, and `InventoryService` listens to that event and updates `InventoryAggregate` asynchronously. This means there is a window of eventual inconsistency between the two aggregates, which I handle with compensating transactions or idempotent event processing — but it is the correct DDD approach for decoupled, independently deployable aggregates.

---

**Q9: Hexagonal Architecture — Ports and Adapters**
*Design Scenario*

**One-line answer:** Hexagonal Architecture isolates the core domain from all external systems — ports are the domain's interfaces, adapters are the implementations that connect to the outside world.

**Full answer:**
Hexagonal Architecture, also called Ports and Adapters, was introduced by Alistair Cockburn to make the application core completely independent of delivery mechanisms and infrastructure. The core domain sits at the center and defines two types of ports. Input ports (also called driving ports) are interfaces that express what the application can do — they are the use case interfaces like `PlaceOrderUseCase` with a `placeOrder(command)` method. Output ports (also called driven ports) are interfaces that express what the application needs from the outside world — like `OrderRepository` with `save()` and `findById()` methods. Adapters implement these ports. The REST controller is an input adapter: it translates an HTTP request into a command and calls the input port. The JPA repository class is an output adapter: it implements `OrderRepository` using Spring Data and JDBC. The core domain has no `import` of Spring MVC, JPA, Kafka, or any external library — it only imports its own domain objects and interfaces. This means I can run the entire business logic in a pure unit test by substituting in-memory adapters for the ports. I can also add a new delivery channel — say, a CLI adapter — without changing a single line of domain logic, by writing a new input adapter that calls the same input port.

*Connect the pattern to testability and the ability to add delivery channels — both are concrete interviewer wins.*

> **Gotcha follow-up:** What is the difference between Hexagonal Architecture and Clean Architecture?
> They express the same core idea — the domain must not depend on infrastructure — but in different vocabularies. Clean Architecture uses concentric layers with the Dependency Rule; Hexagonal Architecture uses ports (interfaces) and adapters (implementations). Both prevent the domain from importing framework code. Clean Architecture adds the concept of Use Case layer as distinct from Entities; Hexagonal Architecture is less prescriptive about layering within the core.

---

**Q10: CQRS — Command and Query Responsibility Segregation**
*Tradeoff Question*

**One-line answer:** CQRS separates the write model (commands that mutate state) from the read model (queries that return data), enabling independent optimization and scaling of each side.

**Full answer:**
In a traditional CRUD architecture, the same model handles both writes and reads. This forces a compromise: the schema must support both efficient transactional writes and efficient complex reads, which are often at odds. CQRS splits these into two models. The Command side handles write operations — it validates the command, applies business rules, updates the write store (typically a normalized relational database), and publishes domain events. The Query side handles reads — it listens to domain events and maintains one or more read-optimized projections, which might be denormalized tables, Redis caches, Elasticsearch indices, or materialized views. The read model is never modified by the query side — it is rebuilt from events when needed. The major benefits are: the read model can be shaped exactly to what the UI needs (no expensive joins at query time), the two sides can scale independently (reads are typically 10x more frequent than writes), and read projections can be rebuilt by replaying the event log. The main trade-off is eventual consistency: after a write, the read projection is updated asynchronously, so there is a brief window where a query returns stale data. For most use cases this is acceptable; for cases where strong consistency is required (showing a user their own just-posted comment), I either tolerate the lag, route them to the write model for their own data, or use synchronous projection updates.

*Always state the eventual consistency trade-off explicitly — interviewers probe for whether you know the downside.*

> **Gotcha follow-up:** Does CQRS require Event Sourcing?
> No — they are complementary but independent. Event Sourcing stores all state changes as an immutable sequence of events; CQRS separates read and write models. You can apply CQRS with separate read/write tables in the same relational database without Event Sourcing. Event Sourcing pairs naturally with CQRS because the event log is the perfect source for rebuilding read projections, but using one does not require the other.

---

**Common Mistakes:**
- **Confusing SRP with "one method per class"** → SRP is about reasons to change and actors served, not class size; over-splitting creates unnecessary fragmentation.
- **Applying OCP upfront speculatively** → building extension points for hypothetical requirements creates over-engineered abstractions nobody uses; apply OCP the first time a second variant is needed.
- **Modelling Square extends Rectangle** → violates LSP; the inheritance hierarchy does not match the behavioral contract; use composition or a separate hierarchy.
- **Fat repository interfaces that expose every JPA method** → ISP violation; services pick up accidental dependencies on methods they never call; define narrow, caller-specific interfaces.
- **Updating two Aggregates in one transaction** → couples the two aggregates and makes them a deployment unit; use domain events and eventual consistency instead.

**Quick Revision:** SOLID in one sentence each — SRP: one actor, one reason to change. OCP: extend without modifying. LSP: subtypes must honor the base contract. ISP: no forced dependencies on unused methods. DIP: depend on abstractions, inject concretions.

---

## Section 3: LLD Quick Reference — Case Studies

---

**Q1: Design a Parking Lot**
*Design Scenario*

**One-line answer:** Model the lot as a hierarchy of floors and spots, use Singleton for the lot, Factory for vehicles, Strategy for fee calculation, and solve thread-safe spot allocation with floor-level locking.

**Full answer:**
My key entities are `ParkingLot` (the top-level aggregate), `ParkingFloor` (which contains a list of spots), `ParkingSpot` (with a type: MOTORCYCLE, COMPACT, LARGE), `Vehicle` (with subtypes `Car`, `Motorcycle`, `Truck`), `Ticket` (issued on entry, records spot and timestamp), and `Payment` (records fee and method). For design patterns: I use Singleton for `ParkingLot` because there is exactly one lot instance managing all state — I implement it with the Holder pattern for thread-safe lazy initialization. I use Factory Method via `VehicleFactory.create(type)` because the caller knows the vehicle type as a string at entry time and should not be coupled to the concrete subclasses. I use Strategy for fee calculation — a `FeeStrategy` interface with implementations `HourlyFeeStrategy`, `DailyFeeStrategy`, and `MonthlyFeeStrategy` — so I can swap fee rules per spot type or membership tier without touching the payment logic. I use Observer so that `DisplayBoard` (the physical sign showing available spots per floor) is notified whenever a spot's availability changes, without `ParkingSpot` knowing about the display system.

The hardest challenge is thread-safe spot allocation: if two cars arrive simultaneously and both threads read the same available spot, I can double-allocate it. My solution is floor-level locking — each `ParkingFloor` has its own `ReentrantLock`. When allocating a spot, I lock only the specific floor being searched. I maintain a list of available spots per type on each floor, so lookup is O(1). An `AtomicInteger` per floor tracks the available count for the display without requiring the full lock.

**Decision:** Floor-level locking vs. lot-level locking.
**Why floor-level:** Two cars going to different floors can be allocated concurrently without any contention. Lot-level locking would serialize all allocations system-wide, which is a significant throughput bottleneck in a large lot.
**Tradeoff:** Getting the total available count across all floors requires aggregating per-floor atomic counts without a single lock — the count may be momentarily inconsistent if read mid-allocation on another floor, but this is acceptable for a display board.

*Walk through the thread-safety challenge explicitly — interviewers specifically probe concurrent access in parking lot designs.*

> **Gotcha follow-up:** How do you handle the case where a motorcycle can park in a compact spot if no motorcycle spots are available?
> I define a spot preference order per vehicle type: a `Motorcycle` first searches motorcycle spots, then compact spots, then large spots. Each `ParkingFloor` maintains separate `LinkedList<ParkingSpot>` per type. The allocation method iterates through the preference order, trying to allocate from each list. All preference-list reads and removals happen within the floor-level lock to prevent concurrent threads from allocating the same spot.

---

**Q2: Design a URL Shortener**
*Design Scenario*

**One-line answer:** Use counter-based Base62 encoding for short ID generation, a Facade service for the public API, and choose 302 redirect for analytics or 301 for reduced server load.

**Full answer:**
My key entities are `ShortURL` (stores `shortCode`, `originalURL`, `userId`, `createdAt`, `expiresAt`), `User` (owns short URLs), and `AnalyticsRecord` (stores `shortCode`, `timestamp`, `ipAddress`, `userAgent` for click tracking). For patterns: I use Strategy via a `ShortCodeStrategy` interface with `CounterStrategy` (using Redis INCR to generate a monotonically increasing integer, then Base62-encoded to a 6-character string) and `RandomStrategy` (cryptographically random Base62 string with collision check). Counter-based is my default because it is collision-free by design: Base62 with 6 characters gives 62^6 ≈ 56 billion unique codes, and Redis INCR is atomic so two concurrent requests can never get the same counter value. I use Facade via `URLShortenerService` to hide the complexity of counter generation, encoding, caching, and analytics from the REST controller. I use Decorator to add analytics tracking transparently — `AnalyticsDecorator` wraps the core redirect service and logs every redirect without the core service knowing about it.

The hardest challenge is collision-free generation at scale. Random Base62 without coordination risks collisions under high concurrency. My solution is a Redis INCR counter: the URL shortener calls `INCR global_url_counter`, gets a unique integer, and encodes it to Base62. This is atomic, distributed, and collision-free.

**Decision:** 301 Permanent Redirect vs. 302 Temporary Redirect.
**Why 302 for analytics:** Every redirect request hits the server, so I can log the click, the referring IP, and the user agent for complete analytics.
**Why 301 for scale:** The browser caches the mapping permanently and redirects directly without hitting the server — reducing server load significantly for popular short URLs.
**Tradeoff:** 302 gives complete analytics at the cost of every click consuming server resources and latency. 301 is faster and cheaper but analytics are blind after the first visit from each browser. My default is 302 with aggressive server-side caching of the short-to-long mapping in Redis.

*The 301 vs 302 decision is almost always asked in follow-up — be ready to argue both sides.*

> **Gotcha follow-up:** How do you handle custom short codes and collisions with the counter-generated namespace?
> I partition the namespace: counter-generated codes start from 1 and increment upward; custom codes are stored in a separate hash map and never conflict with the numeric counter space. On redirect lookup, I check the custom code map first, then the counter-generated map. I also validate that a custom code does not already exist before accepting it, returning a `409 Conflict` if it does.

---

**Q3: Design a Rate Limiter**
*Design Scenario*

**One-line answer:** Use the Token Bucket algorithm for burst-friendly rate limiting, implement check-and-decrement as an atomic Redis Lua script, and place the limiter at the API Gateway for coarse-grained control and at the service level for per-user tiers.

**Full answer:**
My key entities are `RateLimiter` (the main service), `Rule` (defines the limit: `clientId`, `endpoint`, `limit`, `windowSeconds`), and `RequestContext` (carries `clientId`, `endpoint`, `timestamp` for the current request). I design `RateLimiter` as a Strategy interface with four algorithm implementations: Token Bucket (a bucket fills at a fixed rate; each request consumes one token; allows short bursts up to bucket size), Fixed Window (count requests in a fixed time window; simple but allows up to 2x the limit at window boundaries when requests cluster at the end of one window and the start of the next), Sliding Window Log (store each request's timestamp; count timestamps in the last N seconds; accurate but memory-intensive for high-traffic clients), and Sliding Window Counter (blend two adjacent fixed windows proportionally; memory-efficient approximation of sliding window). I use Decorator to wrap existing HTTP handlers — `RateLimitingDecorator` wraps any service endpoint and checks the limiter before delegating.

The hardest challenge is distributed atomicity: with multiple service instances, two concurrent requests for the same client must not both be allowed through if the limit is 1. A Redis Lua script solves this: the script reads the current count, increments it if below the limit, and returns allowed/denied — all in a single atomic operation. No other Redis command can interleave between read and write.

**Decision:** API Gateway rate limiting vs. service-level rate limiting.
**Why API Gateway:** First line of defense, coarse-grained by API key or IP address, protects all downstream services uniformly, and adds no latency to the service itself.
**Why service-level too:** More context — the service knows the authenticated user's tier (free vs. paid), their subscription plan, and can apply business-logic-aware limits that a gateway cannot.
**Tradeoff:** Gateway is faster and simpler but cannot apply per-user-tier rules. Service-level is more precise but adds latency and couples business logic to infrastructure.

*The Lua script atomic check-and-decrement is the implementation detail that separates candidates who have built rate limiters from those who have only read about them.*

> **Gotcha follow-up:** How do you handle the boundary burst problem in Fixed Window?
> A client sends 100 requests at 11:59:59 (allowed, window 1) and 100 requests at 12:00:01 (allowed, window 2) — 200 requests in 2 seconds, double the intended limit. The Sliding Window Counter fixes this: at 12:00:30, the weight from the previous window is `(30/60) = 0.5`, so requests from that window count at half weight in the current window's total. This approximates the true sliding window count with low memory overhead.

---

**Q4: Design BookMyShow — Seat Booking**
*Design Scenario*

**One-line answer:** Model seats with an Optimistic Locking version field for conflict detection, hold seats in Redis with TTL for the payment window, and use a State Machine for seat lifecycle.

**Full answer:**
My key entities are `Show` (a specific screening of a movie at a time), `Screen` (the physical theater), `Seat` (with `seatId`, `type`, `status`, `@Version` for optimistic locking), `Booking` (links user to seats and show), `Payment` (records payment status), and `Notification` (email/SMS confirmation). Optimistic Locking means each `Seat` row in the database has a `version` integer column. When a transaction reads the seat and then updates it, JPA includes `WHERE version = {read_version}` in the UPDATE statement. If another transaction updated the seat first, the version no longer matches, the UPDATE affects zero rows, and JPA throws `OptimisticLockException` — I catch this and tell the user "sorry, seat just taken." For the temporary hold during payment (the 10-minute window between seat selection and payment completion), I use Redis `SETNX` (set if not exists) with a TTL: `SETNX seat:{seatId}:hold {userId} EX 600`. Only the first caller succeeds; if payment is not completed in 10 minutes, the key expires and the seat is released.

The seat lifecycle is a State Machine: AVAILABLE → HOLD (on Redis SETNX success) → BOOKED (on payment success) or back to AVAILABLE (on TTL expiry or payment failure).

**Decision:** Optimistic Locking for browsing + Pessimistic Locking at final booking vs. only Optimistic Locking.
**Why hybrid:** During browsing and seat selection, reads vastly outnumber write conflicts — Optimistic Locking lets reads proceed without any locks. At the moment of final payment confirmation, I use `SELECT FOR UPDATE` (Pessimistic Locking) to prevent two users who both held the same seat (via a race before Redis) from both completing payment.
**Tradeoff:** Pure Optimistic Locking under high contention for popular seats leads to many retries and degraded user experience. Pure Pessimistic Locking serializes all bookings and limits throughput. The hybrid uses the right tool for each phase.

*The Redis TTL hold pattern is the key insight — it decouples the seat reservation from payment without keeping a DB lock open for 10 minutes.*

> **Gotcha follow-up:** What happens if the user's Redis hold expires but they complete payment just after?
> The payment service checks both the Redis hold and the Seat status in a transaction. If the Redis key has expired, the system re-attempts to set the hold. If the seat was claimed by another user in the meantime, the payment is rejected and refunded. Idempotent payment processing ensures that if the user's payment was partially processed, the refund is correctly issued. This is a common edge case to model explicitly.

---

**Q5: Design Splitwise**
*Design Scenario*

**One-line answer:** Use Strategy for split calculation (equal/exact/percent/share), store amounts in integer minor units to avoid float precision errors, and use a min-heap/max-heap pair for O(N log N) settlement minimization.

**Full answer:**
My key entities are `User`, `Group` (a collection of users who share expenses), `Expense` (total amount, payer, split strategy, participants), `Split` (the per-user portion of one expense), `Balance` (net amount user A owes user B, aggregated across all expenses), and `Settlement` (a direct payment transaction). I use Strategy via a `SplitStrategy` interface with implementations `EqualSplit` (divide total by participant count), `ExactSplit` (each participant's exact amount is specified), `PercentSplit` (each participant's percentage is specified, must sum to 100), and `ShareSplit` (each participant's share weight is specified, normalized to total). I use Template Method via `AbstractSplit.validate()`, which calls the abstract `calculateAmounts()` — the validation logic (checking amounts sum to total) is fixed in the parent; the calculation logic varies per subclass.

The hardest challenge is settlement minimization: with N users in a group, computing the minimum number of transactions to settle all balances is the problem of reducing many pairwise debts into fewer direct payments. I compute each user's net balance (total owed minus total owing across all expenses). Users with a positive net balance go into a max-heap (they are owed the most money); users with a negative net balance go into a min-heap (they owe the most money). I repeatedly take the top of each heap, create a direct settlement transaction, reduce both balances, and push them back if non-zero. This runs in O(N log N) and typically reduces N*(N-1)/2 pairwise debts to at most N-1 transactions.

**Decision:** Store monetary amounts in minor units (integer paise or cents) vs. floating point.
**Why integer minor units:** 0.1 + 0.2 = 0.30000000000000004 in IEEE 754 floating point. For a three-way equal split of Rs. 100, `100.0 / 3 = 33.333...` — rounded incorrectly three times, the total does not add back to 100. Storing amounts as integers in paise (1 Rs = 100 paise) eliminates all floating-point arithmetic from the domain.
**Tradeoff:** Display layer must divide by 100 before showing the user, and input must multiply by 100 before storing — this is a minor conversion cost worth the arithmetic correctness guarantee.

*The min-heap/max-heap settlement algorithm is non-obvious — walking through it step by step impresses interviewers.*

> **Gotcha follow-up:** How do you handle rounding in equal splits where the amount does not divide evenly?
> For a three-way split of Rs. 100, each person ideally pays Rs. 33.33... I allocate the base amount to all participants (33 paise) and give the remainder (1 paise) to the first participant. So participant 1 pays 34 paise, participants 2 and 3 pay 33 paise each — total is exactly 100 paise. The key is to compute the remainder explicitly and assign it deterministically rather than rounding independently per participant.

---

**Q6: Design an Elevator System**
*Design Scenario*

**One-line answer:** Model each elevator's lifecycle as a State Machine (IDLE, MOVING_UP, MOVING_DOWN, DOOR_OPEN, MAINTENANCE), use LOOK Algorithm for scheduling, and assign requests to the optimal elevator via a cost function.

**Full answer:**
My key entities are `ElevatorController` (the central dispatcher), `Elevator` (with current floor, direction, state, and a sorted set of pending floor stops), `Request` (either an `InternalRequest` from a button inside the cab or an `ExternalRequest` from a hall button with a requested direction), `Direction` (UP/DOWN), and `Floor`. I use State FSM via a `State` interface implemented by `IdleState`, `MovingUpState`, `MovingDownState`, `DoorOpenState`, and `MaintenanceState`. Each state implements `handleRequest()`, `moveUp()`, `moveDown()`, and `openDoor()` — illegal operations in a given state (like calling `moveUp()` while `DoorOpenState`) throw `InvalidStateTransitionException`. I use Strategy via a `SchedulingStrategy` interface for the dispatch algorithm — `LookAlgorithmStrategy` for production and `FifoStrategy` for testing. I use Observer so `DisplayPanel` (the floor indicator outside the elevator) is notified via events whenever the elevator's current floor or direction changes.

The hardest challenge is multi-elevator coordination. When a hall button is pressed, `ElevatorController` must assign the request to the best elevator. My cost function for each candidate elevator is: `cost = |elevator.currentFloor - requestFloor| + directionPenalty`, where `directionPenalty = 0` if the elevator is moving toward the request in the right direction, a medium penalty if it is idle, and a high penalty if it is moving away. The LOOK Algorithm within each elevator serves all stops in the current direction before reversing — preventing starvation of far floors, which FCFS (First-Come-First-Served) can cause when nearby requests keep arriving.

**Decision:** LOOK Algorithm vs. FCFS.
**Why LOOK:** FCFS assigns requests in arrival order, which can cause an elevator to oscillate back and forth between nearby floors indefinitely while a far floor waits. LOOK ensures that every request in the current direction is served before reversing — analogous to how a read/write disk head works — which bounds the maximum wait time.
**Tradeoff:** LOOK is more complex to implement: the elevator must maintain a sorted set of pending stops and determine the correct reversal point. FCFS is trivial to implement but produces poor throughput and fairness in high-traffic scenarios.

*The cost function for multi-elevator assignment is the depth question — have a specific formula ready.*

> **Gotcha follow-up:** How do you handle an elevator that is in MAINTENANCE state?
> `MaintenanceState` rejects all new requests by returning an error from `handleRequest()`. The `ElevatorController`'s cost function assigns `Integer.MAX_VALUE` as the cost for any elevator in MAINTENANCE state, ensuring it is never selected for new requests. The elevator in MAINTENANCE state can only transition out via an explicit admin command that calls `elevator.setAvailable()`, moving it back to `IdleState`.

---

**Common Mistakes:**
- **Using lot-level locking in Parking Lot** → unnecessarily serializes all allocations; use floor-level locking so different floors can allocate concurrently.
- **Using 301 redirect in URL Shortener when analytics are required** → browser caches the redirect and never hits the server again; analytics are permanently blind after the first visit.
- **Not using an atomic Redis Lua script for rate limiting** → two concurrent requests can both read "below limit" and both be allowed through, violating the limit; the check-and-decrement must be atomic.
- **Keeping a DB-level lock open during payment processing in seat booking** → payment can take 10+ seconds; a held database lock blocks all concurrent seat queries on that show; use Redis TTL hold instead.
- **Floating-point arithmetic for monetary splits in Splitwise** → rounding errors cause split totals to not equal the original expense amount; always store in integer minor units.

**Quick Revision:** LLD in six: Parking Lot = floor locks + Strategy fees. URL Shortener = Redis counter + 302 analytics. Rate Limiter = Token Bucket + Lua atomicity. BookMyShow = optimistic lock + Redis TTL hold. Splitwise = integer paise + heap settlement. Elevator = LOOK + cost function.

---

## Section 4: System Design

---

**Q1: RADIO Framework**
*Concept Check*

**One-line answer:** RADIO — Requirements, API Design, Data Model, Infrastructure, Optimizations — is a structured five-step framework for tackling any system design interview question.

**Full answer:**
A system design interview without a framework produces scattered, incomplete answers. RADIO gives me a repeatable structure that signals seniority and ensures I cover every dimension interviewers score. Requirements comes first: I clarify functional requirements (what the system must do — core features only) and non-functional requirements (scale, latency targets, availability SLA, consistency needs). I always ask "how many users, how many requests per second, what is the acceptable P99 latency?" before drawing any diagrams. API Design comes next: I define the public interface — REST endpoints or RPC methods, request/response schemas, authentication model, and which operations are synchronous vs asynchronous. Data Model follows: I define the core entities and their relationships, choose storage types (relational for transactional consistency, key-value for cache and session, document for flexible schema, column-store for time-series or analytics), and decide the primary partitioning key early because it governs horizontal scalability. Infrastructure is where I draw the architecture: load balancer, caches, primary database, read replicas, message queues, CDN, and service boundaries. Finally, Optimizations: I identify bottlenecks (which component fails first under 10x load?), discuss trade-offs I made, and address failure scenarios (what happens if the cache layer goes down?). Starting with back-of-envelope estimation right after Requirements shows quantitative grounding and scopes every subsequent decision.

*Signal that you always start with clarifying questions — interviewers explicitly look for this before accepting any assumptions.*

> **Gotcha follow-up:** How do you decide which non-functional requirements to focus on?
> I ask the interviewer directly if they have a specific bottleneck in mind. If not, I pick the one most likely to be the bottleneck given the use case: read-heavy systems (news feeds, product catalogs) are latency and cache hit-rate bound; write-heavy systems (logging, event ingestion) are throughput and queue depth bound; financial systems are consistency and durability bound. Naming the primary constraint early focuses the entire design.

---

**Q2: Vertical vs Horizontal Scaling**
*Tradeoff Question*

**One-line answer:** Vertical scaling (bigger machine) is simpler but hits a hardware ceiling; horizontal scaling (more machines) is theoretically unlimited but requires stateless services and distributed coordination.

**Full answer:**
Vertical scaling means upgrading a single server to more CPU, RAM, or faster disk — going from a 4-core 16GB machine to a 32-core 256GB machine. This is the first line of defense for a database primary because it requires no application changes: the database continues to operate as a single node with a single consistent state, and scaling is as simple as provisioning a larger instance. The limits are hardware ceilings and cost: a single machine can only be so large, the cost grows non-linearly, and there is a single point of failure. Horizontal scaling means adding more machines and distributing the workload across them. This is theoretically unlimited: I can keep adding commodity servers as load grows. But it requires architectural changes: application servers must be stateless (no in-memory session state, no local file writes) so any request can be routed to any server, load balancers to distribute traffic, a distributed coordination mechanism for anything that needs synchronization across nodes, and read replicas or sharding for the database layer. Stateless services are the key prerequisite — I externalize all state to Redis (sessions), S3 (files), or the database (persistent data). For most web-tier and service-tier components, horizontal scaling is the default design choice. For the database write primary, vertical scaling buys time while horizontal scaling (via sharding or CQRS read replicas) is prepared.

*"Stateless services are the prerequisite for horizontal scaling" — this is the key architectural insight.*

> **Gotcha follow-up:** How do you handle session state when moving from one server to multiple servers?
> I externalize sessions to a distributed session store like Redis. Each server reads and writes session data from Redis using the session token as the key. This makes every server stateless and interchangeable — if a server fails, any other server can continue handling that user's requests because the session data is in Redis, not in the failed server's memory.

---

**Q3: L4 vs L7 Load Balancer**
*Concept Check*

**One-line answer:** L4 load balancers route at the TCP/IP transport layer using IP and port; L7 load balancers route at the HTTP application layer using URLs, headers, and cookies — L7 is smarter but slower.

**Full answer:**
Load balancers operate at different layers of the OSI (Open Systems Interconnection) model, which is the standard framework for describing how network communication protocols are layered. An L4 load balancer, which operates at the Transport Layer, sees only IP addresses and port numbers. It routes TCP connections to backend servers without inspecting the HTTP payload — faster because less parsing, lower latency overhead. It cannot do SSL termination (decrypting HTTPS traffic) by looking at certificate content, and it routes entire TCP connections, not individual HTTP requests within a keep-alive connection. AWS Network Load Balancer (NLB) and HAProxy in TCP mode are L4. An L7 load balancer operates at the Application Layer and understands HTTP fully — it can route based on URL path (`/api/v1/users` to one backend, `/api/v1/orders` to another), HTTP headers (route by `Host:` header for virtual hosting), or cookies (route authenticated users to the same backend for sticky sessions). L7 also performs SSL termination — it decrypts HTTPS at the load balancer, allowing backend servers to communicate over plain HTTP. AWS Application Load Balancer (ALB), NGINX, and Envoy are L7. L7 enables advanced features like A/B testing (route 10% of traffic to new service version), canary deployments, JWT validation at the edge, and rate limiting per URL pattern.

*"L7 enables A/B testing and canary deployments" — these are concrete real-world features that justify the L7 overhead.*

> **Gotcha follow-up:** When would you use L4 over L7?
> L4 is preferable when ultra-low latency is the primary requirement and routing logic is simple. For a real-time gaming backend or a financial trading system processing millions of packets per second, the header inspection overhead of L7 is measurable. L4 is also the right choice for non-HTTP protocols — TCP-based database connections, MQTT for IoT, or UDP-based media streaming — because L7 load balancers are HTTP-specific.

---

**Q4: CDN — Pull vs Push**
*Tradeoff Question*

**One-line answer:** Pull CDN caches content on first miss from origin; Push CDN pre-loads content to edge before any request — Pull is simpler for dynamic content, Push is better for large static assets.

**Full answer:**
A CDN (Content Delivery Network) is a geographically distributed network of edge servers that cache content closer to users, reducing latency and origin server load. Pull CDN is the default for most web applications: when a user requests an asset that is not yet cached at the nearest edge node, the CDN fetches it from the origin server (the "pull"), caches it with a TTL (Time-To-Live — the duration before the cache considers the entry stale), and serves all subsequent requests from the edge until TTL expires. The first request is slow (origin round-trip), but all subsequent requests are fast. I control freshness via `Cache-Control` headers. Pull works well for content with unpredictable popularity — only popular content stays in the cache, and unpopular content is evicted automatically. Push CDN requires me to proactively upload content to all edge nodes before any user requests it. Every edge node has the content immediately, so the very first request is fast with no origin miss. Push is ideal for large static assets — images, videos, JavaScript bundles — that I know will be requested heavily at a known time (like a product launch). The trade-off is operational complexity: I must manage which content is on which edges, and I must invalidate content across all edges when it changes. Push also consumes edge storage for content that may never be requested from some geographic regions.

*Mention cache invalidation as the hardest operational problem in CDN — it shows real experience.*

> **Gotcha follow-up:** How do you handle cache invalidation when content changes unexpectedly?
> For Push CDN, I send an invalidation API call to the CDN provider for each changed URL — AWS CloudFront, for example, has an invalidation API. For Pull CDN, I use versioned asset URLs: instead of `/logo.png`, I deploy `/logo.v2.png` — the CDN caches both versions, and the new version is served immediately to clients using the new URL. Versioned URLs eliminate the need for manual invalidation entirely for static assets.

---

**Q5: Consistent Hashing — Virtual Nodes**
*Concept Check*

**One-line answer:** Consistent hashing minimizes key remapping when nodes are added or removed; virtual nodes (multiple ring positions per server) ensure even load distribution and handle heterogeneous hardware.

**Full answer:**
In a naive modular hash-based sharding scheme (`server = hash(key) % N`), adding or removing one server changes N, which forces nearly every key to remap to a different server — causing a cache stampede or massive data migration. Consistent hashing places both servers and keys on a conceptual ring (a hash space from 0 to 2^32). Each key is served by the first server clockwise from its position on the ring. When a new server is added, only the keys between the new server and its predecessor on the ring are remapped — a fraction of total keys proportional to 1/N. When a server is removed, only its keys are redistributed to its successor. The problem with basic consistent hashing is uneven distribution: with three servers placed randomly on the ring, one server may own 60% of the key space while another owns 10%. Virtual nodes solve this: instead of placing each server once on the ring, I assign each server V virtual node positions (typically 100–200 per server). The key space is divided into many more equal segments, and each server owns roughly K/N of the segments in expectation. For heterogeneous hardware, I assign more virtual nodes to more powerful servers — a server with 2x the RAM gets 2x the virtual nodes and thus 2x the key space. Cassandra, DynamoDB, and Riak all use virtual node consistent hashing.

*Name Cassandra and DynamoDB as real-world users — it anchors the concept in production systems.*

> **Gotcha follow-up:** What is the hotspot problem and how do virtual nodes help?
> A hotspot occurs when a disproportionate number of requests map to one server — either because a few keys are extremely popular (hot keys) or because the hash function distributes keys unevenly. Virtual nodes help with distribution unevenness: with 150 virtual nodes per server, the probability that one physical server owns more than 2x its fair share is very low. Hot keys (celebrity posts, viral content) require a separate strategy — caching at an upstream layer (Redis), replicating the hot key across multiple nodes, or adding a random suffix to the key and spreading reads across replicas.

---

**Q6: Back-of-Envelope Estimation**
*Concept Check*

**One-line answer:** Back-of-envelope estimation converts vague scale requirements into concrete numbers that drive architecture decisions — learn the key constants and practice approximations.

**Full answer:**
Interviewers use estimation to test whether I can reason quantitatively about scale before committing to architectural choices. The key numbers I keep in memory: 1 million requests per day equals roughly 12 requests per second (1,000,000 / 86,400 seconds ≈ 11.6); 10 million per day is 116 RPS; 100 million per day is ~1,160 RPS; 1 billion per day is ~11,600 RPS. These let me quickly characterize whether a system needs one server, a cluster, or a globally distributed architecture. For storage: 1 byte = 1 byte; 1 KB = 10^3 bytes; 1 MB = 10^6; 1 GB = 10^9; 1 TB = 10^12. A tweet (280 chars UTF-8) is ~280 bytes; a user record is ~1 KB; a profile photo thumbnail is ~200 KB. 100 million users posting 1 tweet per day = 100M × 280 bytes = 28 GB of new text per day. For latency: RAM access is ~100 ns; SSD random read is ~100 µs (roughly 1000x slower than RAM); HDD seek is ~10 ms (roughly 1000x slower than SSD); same-datacenter network round trip is ~0.5 ms; cross-region network is ~150 ms. These ratios — RAM is 100x faster than SSD, SSD is 100x faster than HDD, same-DC is 1000x faster than cross-region — justify caching architectures and geographic distribution decisions numerically.

*Showing fluency with these numbers in the first five minutes of a design interview signals that you have designed systems at scale.*

> **Gotcha follow-up:** How many servers does a system with 10,000 RPS need?
> A single commodity web server can handle roughly 1,000–10,000 requests per second for simple, cacheable reads. For 10,000 RPS with non-trivial processing (database reads, business logic), I plan for 2–5 active application servers with a load balancer, plus overhead for spikes and rolling deployments — so 4–10 servers total. For stateful database operations at that RPS, a single primary can handle writes if they are ~5–10% of total traffic, with read replicas for the read majority.

---

**Q7: Fanout-on-Write vs Fanout-on-Read**
*Tradeoff Question*

**One-line answer:** Fanout-on-write pre-computes feeds at post time for fast O(1) reads; fanout-on-read assembles feeds at query time for O(N) reads but O(1) writes — hybrid solves the celebrity problem.

**Full answer:**
In a social news feed (Twitter, Instagram, Facebook), "fanout" refers to the work of distributing a new post to all followers. With Fanout-on-Write (Push model), when user A posts, the system immediately writes a copy of that post's reference into the feed cache of every one of A's followers. A read of user B's feed is O(1) — just fetch the pre-computed Redis sorted set. The problem is the Celebrity Problem: a celebrity with 100 million followers generates 100 million cache write operations on a single post — this is a massive write amplification that can lag the entire system. With Fanout-on-Read (Pull model), posts are stored centrally. When user B requests their feed, the system fetches the recent posts of all N users B follows and merges them — an O(N) operation where N is the number of followed users. For a user following 1,000 accounts, that is 1,000 fetches and sorts per feed load. This is fast for writes but slow and expensive for reads at scale. The industry standard Hybrid model: apply Fanout-on-Write for normal users (below a threshold like 1 million followers), but for celebrity accounts, do Fanout-on-Read. The feed assembly layer merges the pre-computed feed (from all non-celebrity followees) with live celebrity posts fetched on demand. Instagram and Twitter both use this hybrid approach.

*Name the Celebrity Problem explicitly — it is the standard follow-up, and pre-empting it shows depth.*

> **Gotcha follow-up:** How do you decide the threshold between "celebrity" and "normal user" for the hybrid model?
> The threshold is empirically determined based on the fanout latency budget. If writing to 1 million feeds within the acceptable post propagation latency (say, 5 seconds) is feasible given infrastructure capacity, the threshold is 1 million. Accounts above that threshold are flagged (often manually reviewed or auto-promoted based on follower count) and excluded from fanout-on-write. The threshold is also dynamic — it can be reduced during peak traffic periods to protect system stability.

---

**Q8: Distributed ID Generation — Snowflake**
*Concept Check*

**One-line answer:** Twitter's Snowflake generates 64-bit IDs composed of a 41-bit millisecond timestamp, 10-bit machine ID, and 12-bit sequence number — time-sortable, collision-free, and 4.1 million IDs per second per machine.

**Full answer:**
Globally unique ID generation in a distributed system cannot rely on a single database auto-increment column — that is a single point of failure and a write bottleneck. Twitter's Snowflake algorithm generates 64-bit integers without coordination between machines. The bit layout is: 1 bit unused (sign bit, always 0 to keep IDs positive), 41 bits for milliseconds since a custom epoch (this gives 2^41 ms ≈ 69 years before rollover), 10 bits for the machine or datacenter ID (supporting 2^10 = 1,024 unique machines), and 12 bits for a sequence number within the same millisecond (2^12 = 4,096 IDs per millisecond per machine). Peak throughput is 4,096 × 1,000 ms/s = ~4.1 million IDs per second per machine — far more than any single service needs. Because the timestamp occupies the most significant bits, Snowflake IDs are roughly time-sortable: newer IDs are numerically larger. This means I can use the ID as a cursor for pagination without a separate `created_at` column. The alternatives are UUID (Universally Unique Identifier — 128-bit random, globally unique, but not time-sortable and larger), Redis INCR (simple but a single point of failure), and ULID (Universally Unique Lexicographically Sortable Identifier — time-sortable like Snowflake but uses a 16-character string encoding).

*"Newer IDs are numerically larger so they work as pagination cursors" is the practical insight that shows database usage experience.*

> **Gotcha follow-up:** What happens if two machines are assigned the same machine ID?
> Both machines will generate the same Snowflake IDs at the same millisecond and sequence number — a direct collision. Machine IDs must be assigned and tracked centrally (e.g., stored in ZooKeeper or a database table) and reclaimed when a machine shuts down. A simpler approach in cloud environments is to assign machine IDs at startup using atomic counter in Redis or from a pre-allocated pool managed by a configuration service.

---

**Q9: News Feed System Design**
*Design Scenario*

**One-line answer:** A news feed system needs a post write path with fanout service, a pre-computed feed cache in Redis, Cassandra for post storage, and S3 + CDN for media.

**Full answer:**
When designing a Twitter or Instagram-scale news feed, I start with the write path. When a user creates a post, the API server writes the post content and metadata to the Posts service, which stores it in Cassandra partitioned by `user_id`. A Fanout service (consuming a Kafka event from the Posts service) then determines the author's followers from the Social Graph service and writes the post ID into each follower's feed cache in Redis — stored as a sorted set keyed by `user_id` with scores as timestamps, enabling O(log N) insertion and O(1) range fetch. For celebrities (followers above threshold), fanout is skipped and their posts are served on-demand at read time. The read path is straightforward: the Timeline service fetches the user's pre-computed feed sorted set from Redis, hydrates the post IDs with full post content from a Posts cache (Redis) backed by Cassandra, and merges in any celebrity posts fetched live from their post lists. Media (images, videos) is never stored in the primary database — it goes to S3 with a CDN in front for low-latency delivery globally. Separate services handle notifications (via Kafka to push workers), search (post content indexed in Elasticsearch), and social graph operations (follower/following relationships in a graph database or adjacency table in Cassandra).

*Separate concerns into write path, read path, and media — this structure shows architectural clarity.*

> **Gotcha follow-up:** How do you handle a user who unfollows someone — do you remove old posts from their feed?
> Removing old posts from the feed cache on unfollow is expensive (the feed may contain thousands of posts from that person). In practice, I take two approaches: for the in-memory feed cache (Redis), I let old entries expire naturally with TTL and rebuild the feed on next access. On feed assembly, I check a "blocked/unfollowed" list and filter out posts from accounts the user no longer follows before serving — this is a fast in-memory filter. I do not proactively purge historical feed entries from Redis on unfollow.

---

**Q10: Notification System Design**
*Design Scenario*

**One-line answer:** A notification system uses Kafka queues per channel (push, email, SMS, in-app), stores notification state in a database for retry and tracking, and uses idempotency keys to prevent duplicate delivery.

**Full answer:**
A notification system must reliably deliver messages across multiple channels without losing or duplicating them. My architecture starts with the Notification Service, which accepts notification requests (from user actions, scheduled jobs, or other services), validates them, persists them to a Notifications database with status PENDING, and publishes to a Kafka topic per channel — `notifications.push`, `notifications.email`, `notifications.sms`, `notifications.inapp`. Separate channel worker services consume from each topic. The Push worker calls APNs (Apple Push Notification Service) for iOS and FCM (Firebase Cloud Messaging) for Android. The Email worker calls SendGrid or AWS SES. The SMS worker calls Twilio. On successful delivery, workers update the notification status to SENT. On failure, they retry with exponential backoff (retry after 1s, 2s, 4s, 8s) up to a limit, then mark FAILED and alert on-call. Idempotency is critical: each notification has a unique `idempotencyKey` (typically `userId:eventType:eventId`). If a worker receives the same notification twice (Kafka at-least-once delivery), it checks the key against the database and skips processing if already delivered — preventing double-send. Rate limiting per user per channel prevents notification spam: for example, no more than 10 emails per user per hour from the system.

*Idempotency key is the critical reliability mechanism — name it explicitly and explain why Kafka at-least-once delivery makes it necessary.*

> **Gotcha follow-up:** How do you handle user notification preferences (user opted out of SMS)?
> The Notification Service checks a User Preferences store (Redis cache backed by DB) before publishing to any channel topic. If the user has opted out of SMS, no message is published to `notifications.sms` for that user. This check happens at the Notification Service level, not at the worker level, so no unnecessary Kafka messages are produced. Preference changes are propagated via cache invalidation — update the database and delete the Redis cache key so the next lookup fetches the fresh preference.

---

**Q11: Rate Limiter — Placement and Response**
*Design Scenario*

**One-line answer:** Place rate limiters at the API Gateway for coarse-grained global protection and at the service level for fine-grained per-user-tier control; always respond with HTTP 429 and a `Retry-After` header.

**Full answer:**
Rate limiting protects services from intentional abuse (DDoS attacks — Distributed Denial of Service, where many sources flood a server), unintentional overload (runaway clients, misconfigured retry loops), and ensures fair resource allocation across users. Placement determines what context is available for the limit decision. At the API Gateway (AWS API Gateway, Kong, Apigee), I can rate limit by API key, by IP address, or by route — this is the first and cheapest line of defense because it stops traffic before it ever reaches the application tier. The gateway sees every request and has no access to application-level user identity or subscription tier. At the Reverse Proxy (NGINX with `limit_req_zone`), I can rate limit by source IP before traffic enters the application servers — useful for protecting against IP-based flooding. At the Service level (an in-process middleware or sidecar), I have full application context: I know the authenticated user ID, their subscription tier (free vs. paid), and the specific operation — allowing fine-grained limits like "free users can make 100 API calls per hour, paid users can make 10,000." The HTTP response for a rejected request should always be `429 Too Many Requests` with a `Retry-After` header indicating how many seconds the client must wait before retrying. This allows well-behaved clients to back off automatically rather than hammering the server.

*Naming `429 Too Many Requests` and `Retry-After` shows API design awareness beyond just the algorithm.*

> **Gotcha follow-up:** How do you rate limit across a cluster of distributed service instances?
> Each service instance cannot maintain its own in-memory counter independently — those counters would not share state, and a client could make N times the limit by round-robin hitting N instances. The solution is a centralized counter store in Redis. All instances read and write the same key (`rate:userId:windowStart`), and the check-and-increment is an atomic Lua script to prevent race conditions. Redis Cluster handles high availability and throughput at the cost of inter-instance network latency on every request.

---

**Q12: URL Shortener — 301 vs 302 Redirect**
*Tradeoff Question*

**One-line answer:** Use 301 (Permanent Redirect) to reduce server load by letting browsers cache the redirect permanently; use 302 (Temporary Redirect) for analytics because every redirect hits the server and can be tracked.

**Full answer:**
When a user visits a short URL, the server must redirect them to the long URL. The HTTP redirect mechanism has two primary status codes with very different caching semantics. A 301 Permanent Redirect tells the browser "this mapping will never change — cache it." The browser stores the short-to-long mapping locally and, on subsequent visits to the same short URL, redirects directly without making any request to the URL shortener server. From the user's perspective, subsequent clicks are faster because there is no server round-trip. From the server's perspective, it only sees the first click from each browser — all subsequent clicks are invisible. This dramatically reduces server load for popular short URLs. A 302 Temporary Redirect tells the browser "this mapping might change — check the server every time." Every single click on the short URL results in a request to the URL shortener server, which can log the click, the timestamp, the referring page, the user's geographic location based on IP, and the user agent. Complete analytics data is available, but every click consumes server resources and adds the round-trip latency of the redirect. My decision framework: if the primary business value of the URL shortener is analytics and attribution (marketing campaigns, A/B tests, click-through tracking), I use 302. If the primary value is clean URLs and reduced load, I use 301. A practical middle ground is 302 with very short TTL caching at the CDN layer to reduce server hits while still maintaining analytics for longer-duration users.

*The "analytics are blind" consequence of 301 is the key — state it plainly.*

> **Gotcha follow-up:** What happens if I serve a 301 and later want to change the destination URL?
> The user's browser has permanently cached the old destination and will never check the server again — meaning the redirect update is invisible to any user who previously visited the short URL from that browser. The cache must be manually cleared by the user, which is not feasible at scale. This is why 302 is safer for short URLs that might need to be updated (like a campaign landing page that changes after the campaign).

---

**Q13: Distributed Cache Stampede (Thundering Herd)**
*Concept Check*

**One-line answer:** Cache stampede happens when a popular cache entry expires and all concurrent misses hit the database simultaneously — solutions are mutex locking, probabilistic early expiration, background refresh, or TTL jitter.

**Full answer:**
Cache stampede, also called the thundering herd problem, occurs when a highly requested cache entry expires simultaneously for all requesters. If 10,000 requests per second are being served from a cached value and that cache entry expires, all 10,000 pending requests suddenly find a cache miss and simultaneously query the database. A database that was handling zero direct queries is now handling 10,000 concurrent queries for the same key — it can be overwhelmed, causing cascading failures. The Mutex solution uses a distributed lock: the first thread to detect a cache miss acquires a Redis lock (`SETNX lock:key expires 5s`), fetches from the database, populates the cache, and releases the lock. All other threads that detect the miss wait until the lock is released, then read from the now-populated cache. This works well but introduces latency for all waiting threads. Probabilistic Early Expiration refreshes the cache before it actually expires: I add a small random probability that any request will proactively refresh the cache even when it has not expired — the probability increases as the TTL decreases. This spreads the refresh cost over time. Background Refresh uses a separate async thread to refresh the cache before expiry, while the in-flight requests continue to serve the stale (but not expired) value — implementing the stale-while-revalidate HTTP caching pattern. TTL Jitter is the simplest: instead of setting all cache entries with TTL = 3600 seconds, I set TTL = 3600 + random(0, 600) seconds. Entries that were populated at the same time now expire at slightly different times, spreading the database load.

*TTL jitter is the simplest fix and often overlooked — mentioning it alongside the heavier solutions shows thoroughness.*

> **Gotcha follow-up:** Which solution would you use for a cache that serves 100,000 RPS for one hot key?
> For a single extremely hot key, I use Background Refresh with stale-while-revalidate: a dedicated async process refreshes the cache 30 seconds before TTL expiry, while all 100,000 requests per second continue reading the stale-but-live value. There is never a cache miss in steady state. I also replicate the key across multiple Redis nodes (read replicas or local in-process caches) to distribute the read load, because even a single Redis node may become the bottleneck at 100,000 RPS for one key.

---

**Q14: CAP Theorem in Real Systems**
*Concept Check*

**One-line answer:** CAP theorem says a distributed system can guarantee at most two of Consistency, Availability, and Partition Tolerance — in practice, partitions always happen, so the real choice is between CP and AP.

**Full answer:**
CAP theorem, proven by Eric Brewer, states that a distributed system can provide at most two of three guarantees: Consistency (every read returns the most recent write), Availability (every request receives a response, not an error), and Partition Tolerance (the system continues operating even when network messages between nodes are lost or delayed). Network partitions in distributed systems are not optional — hardware failures, network issues, and datacenter splits happen. Therefore Partition Tolerance is a given, and the real design choice is between CP (Consistency over Availability) and AP (Availability over Consistency). ZooKeeper is CP: it uses a consensus protocol (ZAB — ZooKeeper Atomic Broadcast) that requires a quorum of nodes to agree before a write is committed. During a partition, a minority partition becomes unavailable rather than serving potentially stale data. Cassandra is AP: writes and reads are accepted on any available node; during a partition, different nodes may have different data, and reads may return stale values. The system is always available but may be inconsistent. DynamoDB is AP by default with eventually consistent reads, but offers strongly consistent reads (CP behavior) at higher latency and cost. HBase is CP: it uses HDFS and ZooKeeper, and availability is sacrificed when the HBase Master is unavailable. PACELC extends CAP by adding: even when there is no partition, there is a latency vs. consistency trade-off — a system can choose low latency (serve from local replica, risk stale data) or strong consistency (coordinate with all replicas, higher latency).

*PACELC is an advanced addition — bringing it up shows you have thought beyond the basic CAP framing.*

> **Gotcha follow-up:** Can a system switch between CP and AP behavior dynamically?
> Yes — Cassandra does this via tunable consistency levels. `QUORUM` reads (reading from a majority of replicas) provide strong consistency at the cost of higher latency and unavailability if a quorum cannot be reached. `ONE` reads (reading from the nearest replica) provide eventual consistency with low latency and high availability. I choose the consistency level per operation: critical reads (account balance, inventory check before purchase) use `QUORUM`; non-critical reads (showing a like count) use `ONE`.

---

**Q15: Microservices Migration — Strangler Fig Pattern**
*Design Scenario*

**One-line answer:** The Strangler Fig Pattern migrates a monolith to microservices incrementally by routing traffic through a facade and gradually replacing functionality one feature at a time.

**Full answer:**
A big-bang monolith rewrite — where the team stops feature development, rewrites everything from scratch, and deploys the new system all at once — is widely recognized as a high-risk strategy that frequently fails. The Strangler Fig Pattern, named after a tropical plant that grows around an existing tree and eventually replaces it, provides an incremental alternative. Step one: introduce a routing facade (a reverse proxy or API gateway) in front of the monolith that passes all traffic through. This facade becomes the single entry point for all clients. Step two: identify one bounded context (a cohesive business domain with clear boundaries) from the monolith — for example, the User Authentication service. Implement it as a standalone microservice with its own database. Step three: configure the facade to route `POST /login` and `POST /register` to the new service, while all other routes still go to the monolith. Step four: once the new service is stable and traffic has been migrated, remove the corresponding code from the monolith. Repeat for each bounded context. The monolith is "strangled" gradually. Supporting patterns include: Anti-Corruption Layer (ACL), which is a translation layer that prevents the new service's domain model from being corrupted by the monolith's data model; Branch by Abstraction, which introduces an interface in the monolith that both the old and new implementations satisfy, allowing gradual swapping; and Feature Toggles, which enable switching traffic between old and new paths at runtime without a deployment.

*Name Anti-Corruption Layer explicitly — it is a DDD term that shows architectural depth beyond just the mechanics of the migration.*

> **Gotcha follow-up:** How do you handle shared database access during migration, when both the monolith and the new microservice need to read and write the same tables?
> The shared database is the hardest part of any monolith decomposition. My phased approach: first, both monolith and microservice read and write the same tables (shared schema). Second, add a synchronization layer — the microservice writes to its own schema and publishes change events; a migration job replicates changes to the monolith's schema. Third, update the monolith to read from the microservice's API instead of the database directly. Fourth, remove the monolith's direct database access. This dual-write phase is temporary but necessary to avoid a big-bang database migration.

---

**Common Mistakes:**
- **Jumping to architecture diagrams before clarifying scale requirements** → the right architecture for 1,000 users per day and 100 million users per day are completely different; always ask scale before drawing.
- **Designing fanout-on-write for celebrity accounts** → causes write amplification that can lag the entire system on a viral post; use fanout-on-read or hybrid for high-follower accounts.
- **Not specifying 429 + Retry-After for rate limiting responses** → well-behaved clients cannot implement backoff without the header; always include `Retry-After`.
- **Treating CAP as a permanent binary choice** → modern systems like Cassandra and DynamoDB offer tunable consistency; the choice is per-operation, not per-system.
- **Starting strangler fig migration with a shared database and never decomposing it** → the database becomes the new monolith; plan for database decomposition from the start, not as an afterthought.

**Quick Revision:** System design in five moves: Requirements (scale numbers first), API (endpoints and protocols), Data Model (schema and storage choice), Infrastructure (LB + cache + DB + queue), Optimizations (bottleneck + failure modes). RADIO. Always.

---

## Section 5: Latency Numbers

> *Know the numbers, design with confidence — latency intuition is the difference between a good engineer and a great one.*

---

**Q1: What are the key latency numbers every engineer should know, and why do they matter?**
*Concept Check*
**One-line answer:** A handful of latency numbers — from 1 nanosecond for L1 cache to 150 milliseconds for cross-region network — form the mental model that separates engineers who reason about performance from those who just guess.

**Full answer:** I think of latency numbers as the periodic table of systems engineering — once you internalize them, every design conversation becomes grounded in physical reality rather than intuition. At the processor level, an L1 cache hit (the fastest memory inside the CPU chip itself, holding the most recently used data) costs about 1 nanosecond; L2 cache (a slightly larger but slower on-chip store) costs about 4 nanoseconds; and L3 cache (the largest on-chip store, shared across CPU cores) costs 10–40 nanoseconds. A mutex lock (a synchronization primitive that prevents two threads from modifying shared data at the same time) costs around 25 nanoseconds, which sounds fast but matters at high concurrency. Reading from RAM (the main system memory, several chips away from the CPU) costs about 100 nanoseconds — already 100 times slower than L1 cache — and a context switch (the operating system pausing one thread and resuming another, saving and restoring all CPU registers) costs 1–10 microseconds. Moving to storage, an SSD random read (fetching a single block from a solid-state drive, which has no moving parts) costs 100–150 microseconds, while an HDD seek (physically moving the read arm on a spinning magnetic disk to the right track) costs about 10 milliseconds — 10 million times slower than L1 cache, which still amazes me. On the network side, a round trip within the same data center costs about 500 microseconds; between servers in the same region (say, two AWS availability zones) it's 1–5 milliseconds; and a cross-region round trip like US to EU costs 80–150 milliseconds. For common services, a Redis GET (in-memory key-value lookup over a local network) costs 0.1–1 millisecond, while a database indexed query (reading a row via a B-tree index on disk or in the buffer pool) costs 1–10 milliseconds. These numbers matter because every architectural decision — whether to cache, whether to replicate data closer to users, whether to use async communication — is really a question about which latency tier you want your system to operate in.

*Deliver these numbers with quiet confidence — recite the key ratios (RAM is 100× L1; SSD is 100× RAM; HDD is 100× SSD; cross-region is 1000× same-DC) to show you understand the order of magnitude, not just the raw values.*

> **Gotcha follow-up:** Why does it matter that RAM is 100× slower than L1 cache if RAM access is still only 100 nanoseconds?
> It matters because modern CPUs execute billions of instructions per second, so 100 nanoseconds of memory latency translates to hundreds of wasted CPU cycles on every cache miss — and in a tight loop hitting uncached data, you can spend 90% of execution time waiting for memory rather than computing. This is why CPU architects invest enormous die area in multi-level caches, why cache-friendly data structures (like arrays rather than linked lists) outperform cache-hostile ones even when their algorithmic complexity is identical, and why database buffer pools (in-memory caches of disk pages) are tuned to be as large as possible. At scale, the difference between L1-friendly code and RAM-bound code can be the difference between handling 10 million requests per second and 1 million.

---

**Q2: How do latency numbers influence system design decisions?**
*Tradeoff Question*
**One-line answer:** Every major architectural pattern — caching, read replicas, async messaging, CDNs — exists because someone looked at latency numbers and decided the slower tier was unacceptable for a specific use case.

**Full answer:** I use latency numbers as a forcing function when I evaluate design options. The most concrete example is the Redis versus database decision for hot data: a Redis GET costs 0.1–1 millisecond because Redis stores all its data in RAM (random-access memory that the CPU can reach in ~100 nanoseconds) and serves requests over a local network; a database indexed query costs 1–10 milliseconds because even with a buffer pool cache, the database has to parse the query, acquire locks, traverse a B-tree index (a sorted tree structure that speeds up lookups), and potentially wait for I/O if the page is not cached. That 10× difference sounds modest, but at 100,000 requests per second it's the difference between Redis handling the load with headroom and a single database instance being completely overwhelmed. SSDs over HDDs for databases is another numbers-driven decision: SSD random reads at 100–150 microseconds versus HDD seeks at 10 milliseconds means SSDs are 100× faster for random access patterns, which is exactly what a database does when it traverses an index. For synchronous service calls (where the caller blocks and waits for the response), I prefer keeping services in the same region because a same-region round trip at 1–5 milliseconds is budget-friendly, while a cross-region call at 80–150 milliseconds burns most of a typical 200-millisecond user-facing latency budget on the network alone, leaving almost nothing for computation. When cross-region communication is unavoidable — for example, replicating data to a disaster-recovery site — I insist on async patterns (message queues, event streaming) because the caller should never block on a 150-millisecond hop when the result is not immediately needed.

*Frame this as "I use latency numbers to constrain my design space" — interviewers want to see that your architectural choices are motivated by quantitative reasoning, not cargo-culting.*

> **Gotcha follow-up:** If Redis is so much faster than a database, why not put everything in Redis?
> Redis stores data in RAM, and RAM is expensive and volatile — if a Redis node crashes without persistence configured, you lose all the data it held. RAM also costs roughly 10–50× more per gigabyte than SSD storage, so caching an entire multi-terabyte dataset in Redis would be cost-prohibitive. Redis is also optimized for simple key-value and data-structure operations; it lacks the rich query capabilities, ACID transactions (Atomicity, Consistency, Isolation, Durability — the guarantees that ensure database operations are reliable and correct), and relational joins that a traditional database provides. The right architecture is to use Redis as a cache for the hot working set (typically 20% of data that handles 80% of reads) and let the database be the system of record — durable, queryable, and authoritative.

---

**Q3: How do you budget a p99 latency target of 100 milliseconds for a user-facing API?**
*Design Scenario*
**One-line answer:** I decompose the 100-millisecond budget into per-component allocations, calculate the happy-path total, identify the biggest risks to that budget, and plan which layer to optimize first if the budget is exceeded.

**Full answer:** When I hear "p99 of 100 milliseconds," I immediately think in terms of a latency budget — a fixed pool of time I have to spend across every component in the request path. P99 means the 99th percentile: 99% of requests must complete within 100 milliseconds, so even slow outliers have to fit. My happy-path breakdown for a typical three-tier web API looks like this: two network round trips (client to load balancer, load balancer to app server) cost roughly 1–2 milliseconds total in a same-datacenter deployment; application logic (JSON deserialization, business rule evaluation, response serialization) costs roughly 3–5 milliseconds; a Redis cache hit for session data or frequently read configuration costs 0.1–1 millisecond; and a single database indexed query costs 1–10 milliseconds, so I budget 5 milliseconds. That gives me a happy-path total of roughly 10–18 milliseconds — well within the 100-millisecond target, which is intentional because I need headroom for everything that goes wrong. The three biggest budget killers are N+1 queries (a pattern where fetching a list of N items triggers N additional database queries — for example, loading 50 posts and then querying the author for each post individually, turning 1 query into 51 and multiplying the 5-millisecond database cost by 51), serialization overhead on large payloads (converting a 10 MB object to JSON can take 20–50 milliseconds in a single-threaded environment), and garbage collection pauses (in JVM or Go runtimes, the garbage collector periodically stops all threads to reclaim memory, causing pauses of 10–100 milliseconds at p99 even when the median is fast). If I exceed the budget, I triage by layer: first I check whether an extra cache layer can eliminate the database call entirely; then I look for N+1 queries and replace them with batch fetches or joins; then I look at serialization and payload size; and only as a last resort do I look at application-level parallelism, because concurrency bugs are expensive to debug and maintain.

*Narrate your budget decomposition step by step — interviewers specifically want to see that you work from numbers, not vibes. Saying "roughly 18ms happy path leaves 82ms of headroom" shows you understand margin-of-safety thinking.*

> **Gotcha follow-up:** How does p99 differ from p50, and why is p99 the right metric for user-facing APIs?
> P50 (the median) is the latency that 50% of requests are faster than — it tells you how a typical request feels, but it completely hides tail latency, which is the slow end of the distribution. P99 captures what 1% of users experience, and in a system serving 1 million requests per day, 1% is 10,000 users who had a bad experience — that is not a rounding error, it is a support ticket and a churn risk. More importantly, in a microservices architecture where a single user request fans out to 10 downstream service calls, the probability that at least one of those calls lands in the slow 1% is roughly 10%, so the end-to-end p99 for the user is actually driven by the p99 of each internal service multiplied by the fan-out depth. This is why I optimize for p99 rather than p50: the median is already fast in most systems, but p99 is what determines whether users trust the product.

---

### Common Mistakes — Section 5

- Confusing microseconds (µs, millionths of a second) and milliseconds (ms, thousandths of a second): a 10× error in your latency estimates signals a lack of precision that undermines interviewer confidence.
- Quoting numbers without ratios: knowing that RAM is 100ns is less useful than knowing it is 100× slower than L1 cache, because ratios let you reason about relative cost when you cannot remember the absolute number.
- Forgetting that network latency is round-trip (RTT): a 500µs same-DC RTT means 500µs to send the request AND receive the response, not 500µs one-way.
- Ignoring tail latency (p99, p999) in favor of averages: average latency hides the slow outliers that actually hurt user experience.

### Quick Revision — Section 5

| Component | Latency | Key Ratio |
|---|---|---|
| L1 cache | 1 ns | Baseline |
| L2 cache | 4 ns | 4× L1 |
| L3 cache | 10–40 ns | 10–40× L1 |
| Mutex lock | 25 ns | — |
| RAM | 100 ns | 100× L1 |
| Context switch | 1–10 µs | — |
| SSD random read | 100–150 µs | 1000× RAM |
| HDD seek | 10 ms | 100× SSD |
| Same-DC network RTT | 500 µs | — |
| Same-region network RTT | 1–5 ms | — |
| Cross-region RTT (US–EU) | 80–150 ms | ~300× same-DC |
| Redis GET | 0.1–1 ms | — |
| DB indexed query | 1–10 ms | 10× Redis |

---

## Section 6: Capacity Estimation

> *Estimation is a skill, not a talent — interviewers reward structured reasoning and labeled assumptions over precise arithmetic.*

---

**Q1: How do you estimate storage requirements for a system at scale?**
*Concept Check*
**One-line answer:** I anchor on a simple unit-cost model — bytes per item times items per time period — then multiply through to daily, yearly, and total storage, always stating my assumptions out loud.

**Full answer:** My mental model for storage estimation starts with two anchor facts I have memorized: 1 million users each storing 1 kilobyte of data equals 1 gigabyte total, and 1 billion users each storing 1 kilobyte equals 1 terabyte — these ratios give me a quick sanity check on any estimate. For text-heavy systems, Twitter is my canonical example: 500 million tweets per day, each averaging 300 bytes of text plus metadata (user ID, timestamp, engagement counters), gives 500 million × 300 bytes = 150 gigabytes per day, which compounds to roughly 55 terabytes per year before replication. Images change the picture dramatically: 1 million image uploads per day at an average compressed size of 200 kilobytes per image gives 200 gigabytes per day, and images are often stored at multiple resolutions (thumbnail, medium, original), so the real storage multiplier is 3–5×, meaning 600 gigabytes to 1 terabyte per day just for images. Video is the most storage-intensive workload: 1 million video uploads per day at an average of 50 megabytes per upload (a compressed 5-minute clip) gives 50 terabytes per day, and at multiple quality tiers (360p, 720p, 1080p, 4K) the multiplier is 4–6×, so a YouTube-scale system ingests hundreds of terabytes daily just from uploads. I always multiply by a replication factor (typically 3× for distributed storage like HDFS or S3 with standard redundancy) and add a 20% overhead factor for indexes, metadata, and temporary files, so my final estimate is: raw data × 3 replicas × 1.2 overhead.

*State every assumption — average object size, replication factor, growth rate — before you calculate. Interviewers care more about your reasoning process than whether your final number is accurate to two significant figures.*

> **Gotcha follow-up:** How does compression affect your storage estimate?
> Compression ratios vary wildly by data type, which is why I always specify the type before applying a factor. Text data (tweets, logs, JSON) typically compresses to 20–40% of its original size with gzip or LZ4 (a fast lossless compression algorithm that trades compression ratio for speed), so a 300-byte tweet might store as 60–120 bytes. Images are already compressed (JPEG, WebP) so applying gzip achieves almost nothing and can actually make the file larger. Video is the most interesting case: raw video is enormous, but modern codecs like H.264 or H.265 (AV1) achieve 50–200× compression versus raw frames, which is why a 5-minute 1080p video is 50 MB rather than 50 GB. In my storage estimates I apply compression factors only to text and log data, treat images as already compressed, and treat video as already codec-compressed, then apply the replication and overhead multipliers on top of those post-compression sizes.

---

**Q2: How do you convert daily active users to requests per second?**
*Concept Check*
**One-line answer:** Divide daily requests by 86,400 seconds per day for the exact number, or divide by 100,000 for a two-second mental approximation — then multiply by a peak-to-average ratio of 2–3× to size infrastructure.

**Full answer:** The fundamental conversion I always have ready is that 1 day equals 86,400 seconds (24 hours × 60 minutes × 60 seconds = 86,400), which means I can turn any daily volume into requests per second by dividing by roughly 86,000. For quick back-of-envelope math I round to 100,000, which gives an answer that is within 15% of the true value and easy to compute mentally. The key numbers I have memorized: 1 million requests per day divided by 86,400 ≈ 12 requests per second; 10 million per day ≈ 116 RPS; 100 million per day ≈ 1,160 RPS; 1 billion per day ≈ 12,000 RPS. But average RPS is rarely the right number to size infrastructure for, because web traffic is bursty — during peak hours (typically 6–9 PM local time for consumer apps, or 9–11 AM for business apps) traffic can be 2–3× the daily average. So if my daily average works out to 1,000 RPS, I size my servers to handle 2,000–3,000 RPS to avoid degradation during peak periods. I also think about read-to-write ratios: a social media app might have 100 read operations (news feed loads, profile views) for every 1 write (post, like, follow), so if I compute 1,000 total RPS and the read:write ratio is 100:1, the database write throughput I need is only about 10 writes per second, which a single primary database instance handles comfortably, while the 990 reads per second is what drives the decision to add read replicas or caching.

*Recite the four key conversions (1M/10M/100M/1B per day → RPS) without hesitation — these show you have done this before. Then immediately layer on the peak multiplier, because sizing for average traffic is a rookie mistake.*

> **Gotcha follow-up:** How do you handle seasonality and viral spikes in your capacity estimate?
> Seasonality means predictable traffic variation — an e-commerce platform sees 5–10× its average traffic on Black Friday, a tax-filing service sees its peak in April, a news site spikes during breaking events. For predictable seasonality I design for the known peak, which I calculate by multiplying average daily traffic by the known spike multiplier, and I use auto-scaling (automatically adding or removing server instances based on current load) to avoid paying for peak capacity year-round. Viral spikes are harder because they are unpredictable: a tweet going viral can cause a 50–100× traffic spike in minutes, faster than most auto-scaling systems can respond. My defense is a combination of aggressive caching (so most requests hit a cache and never reach the database), circuit breakers (a pattern that stops sending requests to a downstream service when it is struggling, preventing cascade failures), and pre-warmed capacity in a hot standby pool. I always size the database and stateful storage layers conservatively because those cannot scale as quickly as stateless compute — a database shard takes minutes to add, but a stateless API server can be cloned in seconds.

---

**Q3: What are the throughput limits of common infrastructure components?**
*Concept Check*
**One-line answer:** A single unoptimized server handles 1,000–5,000 requests per second; a database handles 1,000–2,000 QPS for indexed reads; Redis handles 100,000–1,000,000 operations per second; and Kafka handles roughly 1 million messages per second per broker.

**Full answer:** I think of throughput limits as the capacity ceilings that tell me when I need to introduce a new tier or shard a component. A single application server handling simple API requests — JSON parsing, basic business logic, one database call — typically saturates around 1,000–5,000 requests per second depending on the request complexity and whether I/O is involved; the bottleneck is usually either CPU for compute-heavy logic or the number of open connections for I/O-bound work, and the fix is horizontal scaling (adding more server instances behind a load balancer). A single relational database instance (PostgreSQL, MySQL) handling indexed reads — queries that use a B-tree index to find rows without scanning the full table — can sustain roughly 1,000–2,000 queries per second before response time degrades; write throughput is lower, often 200–500 writes per second, because writes must flush to the write-ahead log (a durable append-only log that records every change before it is applied to the data pages, ensuring crash recovery). Redis is where things get exciting: because it operates entirely in memory and uses a single-threaded event loop (one thread handles all commands, eliminating lock contention), it achieves 100,000–1,000,000 operations per second on a single instance, which is why it is the go-to cache for hot data. Kafka, the distributed event streaming platform that persists messages to disk and allows multiple consumers to read from the same stream at different offsets, achieves roughly 1 million messages per second per broker because it uses sequential disk writes (which are almost as fast as RAM writes on modern SSDs) and efficient batching. These numbers tell me which component to reach for: if I need sub-millisecond at massive throughput, it is Redis; if I need durable high-throughput messaging, it is Kafka; if I need complex queries with moderate throughput, it is a relational database with appropriate indexing.

*Never claim exact limits without a caveat — hardware, network, and workload all affect throughput. Say "roughly" and explain what the bottleneck is. Interviewers are checking whether you understand the mechanism, not whether you memorized a benchmark.*

> **Gotcha follow-up:** If a relational database caps at 2,000 QPS, how do you support a system needing 20,000 QPS of reads?
> The answer is layered scaling: I attack the read problem at multiple levels rather than just throwing more database hardware at it. First, a Redis cache in front of the database with a well-designed cache key strategy can achieve a 90–99% cache hit rate for read-heavy workloads, meaning 18,000–19,800 of those 20,000 QPS never touch the database at all. Second, for the cache-miss traffic I add read replicas — database instances that receive a continuous stream of changes from the primary via replication (the primary writes changes to a binary log, replicas apply those changes asynchronously) and serve read queries independently, so five replicas multiply the read capacity to 10,000 QPS. Third, if that is still insufficient, I shard the data: I partition the dataset horizontally so that each shard owns a subset of rows (for example, users with IDs 1–1M go to shard 1, 1M–2M to shard 2), and each shard handles its fraction of the total read load. The cache is almost always the right first move because it multiplies effective capacity without adding operational complexity of managing replica lag or shard routing.

---

**Q4: How do you design for read-heavy versus write-heavy workloads?**
*Tradeoff Question*
**One-line answer:** Read-heavy workloads call for caching and read replicas to multiply read capacity; write-heavy workloads call for sharding and async queues to distribute write load; when both are heavy, CQRS separates the two concerns into independent, optimizable stores.

**Full answer:** The read-to-write ratio is the first question I ask when designing a data tier, because the two workloads require fundamentally different optimizations. For a read-heavy system (roughly 10 reads for every 1 write — a product catalog, a social feed, a configuration service), my primary tool is a Redis cache: I cache the most frequently read objects with a TTL (time-to-live, an expiration timer after which the cache entry is invalidated and the next request fetches a fresh value from the database), and I target a cache hit rate above 99% because every cache miss falls through to the database. I complement the cache with read replicas (additional database instances that replicate from the primary and serve read queries), which lets me scale read throughput linearly with the number of replicas while keeping the primary dedicated to writes. For a write-heavy system (1 read for every 10 writes — a metrics ingestion pipeline, a logging system, an IoT sensor collector), caching helps much less because data changes faster than it can be usefully cached, so I focus on horizontal partitioning through sharding: I split the dataset across multiple database instances, each owning a non-overlapping range of the key space, so that writes are distributed and no single instance becomes a bottleneck. I also introduce an async write path via a message queue (like Kafka or RabbitMQ): the API accepts writes, publishes them to a queue, and returns immediately, while consumers process the queue at the rate the database can absorb — this decouples the write ingestion rate from the storage throughput. When both reads and writes are heavy — think a financial trading platform or a large social network — I reach for CQRS (Command Query Responsibility Segregation), a pattern where write operations (commands) go to a normalized relational database optimized for write consistency, and read operations (queries) go to a denormalized read store (often a document store or a materialized view) optimized for query performance, with an event stream keeping the two stores synchronized asynchronously.

*Lead with the ratio, then the pattern. "This is a 10:1 read-to-write ratio, so my instinct is Redis cache plus read replicas" lands better than jumping to a solution without framing.*

> **Gotcha follow-up:** What are the consistency trade-offs of using read replicas?
> Read replicas introduce replication lag — the delay between when a write commits on the primary and when it appears on the replica, typically 10–100 milliseconds in a healthy same-region setup but potentially seconds or minutes during high write load or network issues. This means a user who writes data and immediately reads it back may hit a stale replica and see their old data, which is called a read-your-writes consistency violation. I address this with two strategies: first, I route reads to the primary for operations that require read-your-writes semantics (the user's own profile, their own posts), accepting the higher primary load for those specific queries; second, for cases where I can tolerate eventual consistency (reading other users' data, aggregate counters), I route freely to replicas. In practice I also expose the replication lag as a metric and alert when it exceeds a threshold, because a replica that is seconds behind is not providing meaningful read scaling — all reads are effectively stale writes that are just waiting to arrive.

---

**Q5: Explain the 80/20 rule for caching and how it influences cache sizing.**
*Concept Check*
**One-line answer:** The Pareto principle tells us 20% of content drives 80% of traffic, which means caching just 20% of a dataset can eliminate 80% of database load — and this ratio is the primary justification for Redis cluster sizing decisions.

**Full answer:** The 80/20 rule, formally called the Pareto principle after economist Vilfredo Pareto who observed it in wealth distribution, appears repeatedly in web traffic patterns: a small fraction of content (a viral tweet, a top-10 product page, a popular article) accounts for the vast majority of reads, while the long tail of rarely accessed content sits quietly on disk. This skewed access pattern is what makes caching so powerful: if I have a 10 terabyte dataset and I cache the hottest 20% (2 terabytes) in Redis, I expect to handle roughly 80% of read requests from cache at sub-millisecond speed, with only 20% of requests falling through to the database. The memory-to-cost justification is compelling: 2 terabytes of RAM in a Redis cluster costs perhaps $5,000–$10,000 per month in cloud infrastructure, but it eliminates 80% of the load from a database cluster that might cost $20,000–$50,000 per month, so the net economics strongly favor the cache. In practice I size my cache by analyzing access logs: I look at the request distribution, identify the percentile cutoff where the cache hit rate reaches 80–90%, and size the cache to hold that working set with enough headroom for hot-spot variance. I also use an LRU (Least Recently Used) eviction policy — when the cache is full and needs to add a new entry, it evicts the entry that was accessed least recently — which naturally keeps the working set populated with currently hot data and lets cold data fall out without manual management. The 80/20 rule also informs TTL strategy: very hot items (homepage content, global configuration) get long TTLs of minutes or hours because the cost of a cache miss is high and data changes slowly; moderately hot items (individual user feeds) get shorter TTLs of seconds to minutes to balance freshness against database load.

*This question is really testing whether you understand why caching works, not just that it works. Tie the Pareto principle explicitly to the memory-cost trade-off — that is what interviewers at senior level are listening for.*

> **Gotcha follow-up:** What happens to your cache hit rate during a cache stampede, and how do you prevent it?
> A cache stampede (also called a thundering herd) happens when a popular cache entry expires and dozens or hundreds of concurrent requests all experience a cache miss simultaneously, all racing to fetch the same data from the database and repopulate the cache — this can suddenly multiply database load by 100× and overwhelm a system that was handling the read load fine through the cache. I prevent stampedes with three techniques. First, I use probabilistic early expiration: I start refreshing cache entries slightly before they expire (when a random dice roll exceeds a threshold that increases as the TTL approaches zero), so the cache is refreshed in the background by a single request before it expires rather than by a burst of concurrent misses. Second, I use a mutex-based lock (a distributed lock in Redis itself using SETNX — "set if not exists" — a command that atomically sets a key only if it does not already exist): the first request to experience the miss acquires the lock, fetches from the database, and populates the cache, while all other concurrent requests wait briefly and then hit the now-populated cache entry. Third, for truly critical data I use a background refresh pattern where a scheduled job proactively refreshes the cache before entries expire, so the cache is always populated and user requests never trigger a database fetch.

---

### Common Mistakes — Section 6

- Forgetting to state assumptions: an estimate without declared assumptions is not defensible. Always say "assuming 300 bytes per tweet" before calculating.
- Sizing for average traffic instead of peak: a system that handles average load but falls over during peak is a production incident waiting to happen.
- Ignoring replication and overhead multipliers: raw data size × 3 replicas × 1.2 overhead is the realistic number; raw data size alone is not.
- Conflating QPS (queries per second, a read metric) with TPS (transactions per second, which can include multi-operation write transactions): they measure different things and both matter.
- Assuming cache hit rates of 100%: no real-world cache is 100% effective; always plan for the 10–20% miss rate and ensure the database can handle that residual load.

### Quick Revision — Section 6

| Conversion | Value |
|---|---|
| 1M req/day | ~12 RPS |
| 10M req/day | ~116 RPS |
| 100M req/day | ~1,160 RPS |
| 1B req/day | ~12,000 RPS |
| Quick approximation | Divide by 100,000 |
| Peak multiplier | 2–3× average |

| Component | Throughput |
|---|---|
| Single app server | 1,000–5,000 RPS |
| Single DB (indexed reads) | 1,000–2,000 QPS |
| Redis | 100K–1M ops/sec |
| Kafka | ~1M msgs/sec/broker |

| Storage rule of thumb | Value |
|---|---|
| 1M users × 1 KB | 1 GB |
| 1B users × 1 KB | 1 TB |
| 500M tweets/day × 300B | 150 GB/day ≈ 55 TB/year |
| 1M image uploads/day × 200 KB | 200 GB/day |
| 1M video uploads/day × 50 MB | 50 TB/day |

---

## Section 8: Interview Day Checklist

> *Your final mental preparation toolkit — actionable checklists and frameworks for interview day.*

---

### Before the Interview (T-24 Hours)

- **Review the company's engineering blog and know their tech stack and scale challenges.** Mentioning a specific technical decision the company made (e.g., "I read that you migrated from monolith to microservices to support independent deployments") signals genuine interest and gives you concrete examples to tie your answers to — interviewers remember candidates who did their homework.

- **Skim the Latency Numbers and Capacity Estimation sections of your handbook.** These two topics generate 30–40% of follow-up questions in system design interviews; having the key numbers (RAM is 100× L1 cache, SSD is 100× RAM, Redis is sub-millisecond) fresh in your mind lets you answer without visible hesitation.

- **Review your top 3 past projects in STAR format (Situation, Task, Action, Result).** Behavioral interviews are pattern-matched by interviewers, and having three well-rehearsed stories covering a technical challenge, a conflict resolution, and a leadership moment means you always have material to draw on — unprepared candidates ramble and lose credibility.

- **Re-read your strongest Low-Level Design (LLD) case study end-to-end.** LLD questions — design a parking lot, design a chess game — test object-oriented thinking, class relationships, and interface design; reviewing one strong example refreshes the mental model without requiring you to memorize every scenario.

- **Have pen and paper ready for diagramming, even in a video interview.** Drawing system components by hand and holding them up to the camera is often faster than screen-share whiteboard tools, and it signals that you are comfortable thinking visually — which is how senior engineers actually design systems.

- **Set up your IDE and practice coding for 30 minutes without autocomplete.** Autocomplete is often disabled or unavailable in interview environments, and muscle memory for common patterns (writing a hashmap, implementing a queue) degrades quickly without practice — 30 minutes of manual coding the night before reactivates that muscle memory.

- **Sleep at least 7 hours.** Cognitive performance on complex problem-solving tasks drops 20–40% with less than 6 hours of sleep, and system design interviews are cognitively demanding — no amount of last-minute cramming compensates for sleep deprivation.

- **Prepare and rehearse a 90-second "tell me about yourself" that ends with why you want this role.** The opening question sets the interviewer's frame for the rest of the session; a crisp, confident self-introduction that connects your experience to the role signals that you communicate clearly — a critical skill for senior engineers who must influence without authority.

---

### System Design Framework (Step-by-Step with Timing)

Use this framework for every system design question. The timing is approximate for a 45-minute interview.

**1. Clarify Requirements (3–5 minutes)**
Never jump to a solution before understanding the problem — interviewers deliberately leave requirements ambiguous to test whether you ask the right questions. Clarify: functional requirements (what does the system do?), non-functional requirements (scale, latency SLA, consistency guarantees), and out-of-scope constraints (mobile vs. web, authentication, billing).

**2. Estimate Scale (2 minutes)**
State your assumptions out loud and calculate daily active users → RPS, storage per day and per year, and the read:write ratio. These numbers will determine every subsequent architectural choice — a system with 1,000 RPS is designed very differently from one with 1 million RPS.

**3. Define the API (3–5 minutes)**
Write out 3–5 API endpoints with method, path, key parameters, and return type. This step forces precision about what the system actually does and creates a shared contract with the interviewer before any components are drawn — it prevents the common mistake of designing a system that does not match the requirements.

**4. High-Level Design (10 minutes)**
Draw the major components: clients, load balancer, application servers, cache, database, message queue, CDN. Use boxes and arrows, label the data flows, and narrate as you draw — "requests come in here, hit the cache first, fall through to the database on a miss." Do not go deep on any single component yet; the goal is a complete, working skeleton.

**5. Data Model (5 minutes)**
Define the primary tables or collections with their key fields, primary keys, and indexes. For SQL, sketch the schema; for NoSQL, sketch the document or key structure. This step catches mismatches between the access patterns the system requires and the data model you have chosen — a query that needs a join across three tables hints that the NoSQL choice may be wrong.

**6. Deep Dive (10–15 minutes)**
Ask the interviewer which component they want to explore, then go deep on that area. Common deep-dive areas: database sharding strategy, caching invalidation policy, handling hot partitions, message queue consumer group design, failure modes and retry logic. Show that you can reason about edge cases and failure scenarios, not just the happy path.

**7. Trade-offs (5 minutes)**
Explicitly summarize the trade-offs in your design: "I chose eventual consistency over strong consistency because it allows the replicas to serve reads independently, but it means a user might see stale data for up to 100 milliseconds after a write." Naming the trade-offs you chose demonstrates senior-level judgment — junior candidates present one design as the answer; senior candidates present it as the best choice given specific constraints.

---

### System Design Mantras

- **Start simple, add complexity on demand.** Begin with a single server, single database design and add components only when you can articulate the specific problem each component solves — interviewers are suspicious of complexity that arrives without justification, because over-engineered systems are as dangerous as under-engineered ones.

- **State trade-offs explicitly.** Every architectural choice sacrifices something: caching improves latency but introduces staleness; sharding improves write throughput but complicates queries; async writes improve availability but require handling eventual consistency. Naming the sacrifice shows you understand the full design space.

- **Ask clarifying questions before whiteboarding.** Drawing a design before understanding the requirements is the single most common mistake in system design interviews — spending 5 minutes on clarification saves 20 minutes of redesign and demonstrates that you prioritize understanding the problem over appearing busy.

- **Drive the conversation.** Interviewers expect you to narrate your thinking, propose what to discuss next, and fill silence with reasoning — passively waiting to be guided signals that you cannot run a technical design meeting, which is a core competency at senior levels.

- **Numbers matter.** Grounding every design decision in a specific number ("this component would saturate at 2,000 QPS, but our estimate requires 10,000, so we need at least 5 instances") distinguishes engineers who have built production systems from engineers who have only studied them.

---

### During Coding (Best Practices)

- **Think aloud for 1–2 minutes before writing a single line.** Interviewers are evaluating your problem-solving process, not just your solution — narrating your approach ("I am going to use a sliding window here because it avoids re-scanning elements") gives them insight into how you think and allows them to redirect you if your approach is headed in the wrong direction.

- **Write the function signature first, including parameter names and return type.** Starting with the signature forces you to define the contract before the implementation, and it gives the interviewer an anchor to check that you understood the problem correctly — it also helps you if you run out of time, because a correct signature with partial implementation is better than no signature at all.

- **Start with the happy path and explicitly note where error handling belongs.** Trying to handle every edge case from line one leads to tangled code that is hard to follow; writing the clean happy path first and then adding error handling in a second pass is how experienced engineers actually work, and it demonstrates the ability to decompose a problem.

- **Use meaningful variable names, not single-letter shortcuts (except conventional loop counters like `i`, `j`).** Meaningful names make your code self-documenting and reduce the cognitive load on the interviewer trying to follow your logic — `leftPointer` and `rightPointer` communicate intent instantly; `a` and `b` force the interviewer to track context mentally.

- **Test with one normal example and one edge case before claiming done.** Walking through your code with a concrete input catches off-by-one errors, null pointer exceptions, and empty-input bugs that are extremely common under interview pressure — interviewers specifically look for whether you validate your own code or trust it blindly.

- **State the time and space complexity of your solution at the end.** Big-O analysis (O(n) time, O(1) extra space) is a required deliverable in coding interviews; leaving it unstated suggests you cannot analyze your own code, even if the code itself is correct.

- **Use consistent indentation and formatting throughout.** Sloppy formatting in a coding interview reads as sloppy thinking — consistent style signals professional discipline and respect for the interviewer's time spent reading your code.

---

### Questions to Ask the Interviewer (Pick 2–3)

**1. "What does the on-call rotation look like, and what is the most common type of production incident you see?"**
This question reveals operational maturity — teams with frequent incidents of the same type often have unresolved systemic problems, and on-call culture is a strong predictor of work-life balance and engineering investment; it also signals that you think about production reliability, not just feature development.

**2. "What is the biggest technical challenge the team is working through right now?"**
This question shows intellectual curiosity and gives you real information about the technical environment you would be joining — if the answer is "migrating a legacy monolith," you learn about the work ahead; if it is "scaling our ML pipeline," you learn about the technical domain; either way, your follow-up question demonstrates engagement.

**3. "How does the team approach technical debt — is there dedicated time each sprint, or does it get addressed opportunistically?"**
Technical debt management is a direct indicator of engineering culture maturity — teams that address debt proactively ship reliably and onboard new engineers faster; teams that ignore it accumulate fragility and slow velocity, and this question shows you care about long-term code health.

**4. "What would a successful first 90 days look like for this role?"**
This question reframes the conversation from evaluation to planning and gives you concrete information about what the team values most in the near term — it also shows confidence and forward-thinking orientation, which are traits senior engineers need to demonstrate.

**5. "How does the team measure engineering productivity or developer experience?"**
Teams that measure and improve developer experience (build times, deployment frequency, mean time to recovery) tend to have better tooling, faster feedback loops, and higher morale — this question signals that you care about the systems that let engineers do their best work, not just the features those engineers ship.

---

### Red Flags to Avoid

**1. Starting to code (or draw a system design) without clarifying requirements.**
This is the most common and most damaging mistake in interviews — it signals that you prioritize appearing busy over solving the right problem, and interviewers will note that you built a solution to the wrong problem; always spend at least 2–3 minutes on requirements before touching the whiteboard or keyboard.

**2. Giving one-word or one-sentence answers in system design interviews.**
System design is a conversation, not a quiz — monosyllabic answers like "use Kafka" or "add a cache" without explaining why, what the trade-offs are, or how it fits into the overall design signal that you have memorized buzzwords without understanding the underlying systems.

**3. Pretending to know something you do not.**
Interviewers are experts in their own systems and will quickly probe the depth of any claim you make — saying "I have used Kafka extensively" when you have only read about it leads to an embarrassing follow-up conversation, while saying "I understand Kafka's design at a conceptual level but have not used it in production" is honest and does not hurt you nearly as much.

**4. Ignoring non-functional requirements (scalability, availability, latency, consistency).**
A system that does what it is supposed to do but falls over under load or is unavailable 10% of the time is not a production-ready system — in senior engineer interviews, non-functional requirements (often called NFRs) are frequently the real test, and ignoring them signals that you think only at the feature level rather than the systems level.

**5. Premature optimization (optimizing a component before you know it is the bottleneck).**
Spending 10 minutes on sharding strategy for a component that handles 100 QPS when your database can handle 2,000 QPS signals poor prioritization — good engineers optimize the actual bottleneck, which requires measurement or at least a capacity estimate, not the most technically interesting component.

**6. Dismissing or arguing against an interviewer suggestion.**
When an interviewer says "what if we used approach X instead?" they are testing whether you can evaluate alternatives objectively — saying "that would not work" without reasoning through it signals defensiveness and closed-mindedness; the correct response is to engage seriously: "interesting, if we went with X, we would gain Y but trade off Z."

**7. Forgetting edge cases in coding problems.**
Empty input, single-element arrays, null values, integer overflow, and off-by-one boundaries are the edge cases that make production code reliable — ignoring them signals that you only think about the happy path, which is a significant quality risk for any senior hire.

**8. Presenting an overly complex solution as your first answer.**
If a simple hash map solves the problem in O(n) time and space, leading with a trie or segment tree signals poor judgment about when complexity is warranted — interviewers specifically look for simplicity as evidence of engineering maturity, because over-engineering is a major source of production incidents and maintenance burden. Start simple, then add complexity only when you can name the specific requirement that demands it.

---

## Section 7: 100 Mock Interview Q&As

### Core Java (Q1–Q15)

**Q1: What is the difference between == and .equals() in Java?**
**One-line answer:** == compares references; .equals() compares content (if overridden).
**Full answer:** Every Java variable holds either a primitive value or an object reference — a memory pointer to where the object lives on the heap. == compares these pointers, so two distinct String objects both containing "hello" evaluate == as false even though they look identical. .equals() is a method that can be overridden — String, Integer, and all value types override it to compare actual content field by field. Always use .equals() for object content comparison, and remember to override both .equals() and hashCode() together, because HashMap and HashSet use both to locate entries correctly.

---

**Q2: Java Memory Model — heap vs stack**
**One-line answer:** Stack: method frames, local vars (thread-local); Heap: all objects (shared, GC-managed).
**Full answer:** The stack is a per-thread region storing method call frames — each frame holds local variables, parameters, and the return address; when a method returns, its frame is popped and that memory is instantly freed. The heap is the shared region where all object instances live; it is managed by the Garbage Collector, which reclaims memory from objects that are no longer reachable by any live reference. Stack allocation is extremely fast (just advance a pointer) and automatically freed at method return; heap allocation requires GC overhead. Memory leaks in Java always involve the heap — objects still referenced but never used again, such as unbounded caches or forgotten entries in static collections.

---

**Q3: What is the difference between HashMap and ConcurrentHashMap?**
**One-line answer:** HashMap not thread-safe; ConcurrentHashMap uses segment/bucket-level locking, allows concurrent reads.
**Full answer:** HashMap performs no synchronization, so concurrent reads and writes from multiple threads can corrupt its internal state — in Java 7 a resize could create an infinite loop; in Java 8 updates could be silently lost. ConcurrentHashMap in Java 8+ uses CAS (Compare-And-Swap, an atomic CPU instruction that reads and conditionally writes in a single uninterruptible step) for most updates and synchronized blocks only for rare structural changes like tree restructuring, making reads completely non-blocking. This gives ConcurrentHashMap near-HashMap read performance with full thread safety under concurrent access. Never use HashMap in a shared mutable context even for "mostly reads" — the race conditions are subtle, intermittent, and very hard to reproduce in testing.

---

**Q4: How does String immutability work in Java?**
**One-line answer:** String objects are final; any "modification" creates a new String; enables string pool and thread safety.
**Full answer:** The String class is declared final (it cannot be subclassed) and its internal character array is private and never exposed, so once a String object is created its content can never change. Operations like concat(), substring(), and replace() all return brand-new String objects — the original is completely untouched. This immutability enables the String Pool (also called string interning): the JVM can safely share a single "hello" object across all code that uses that literal, because no one can mutate it and cause side effects for other holders. Immutability also makes String inherently thread-safe — multiple threads can read the same String simultaneously with no synchronization needed.

---

**Q5: What is the difference between Comparable and Comparator?**
**One-line answer:** Comparable defines natural ordering (in the class); Comparator defines external/custom ordering (separate class).
**Full answer:** Comparable is an interface the class itself implements (class Product implements Comparable<Product>) to define what "natural order" means for that type — for example Integer sorts ascending by value and String sorts lexicographically. Comparator is a separate strategy object passed to sorting methods like Collections.sort(list, comparator) to define an alternative ordering without touching the original class. You use Comparable when there is one obvious correct ordering for the type; you use Comparator when you need multiple orderings (sort products by price, then by name, then by rating) or when the class belongs to a library you cannot modify. Java 8 made Comparator more composable with Comparator.comparing(Product::getPrice).thenComparing(Product::getName).

---

**Q6: Explain Java's volatile keyword.**
**One-line answer:** Ensures visibility of changes across threads; prevents caching in CPU registers; does NOT guarantee atomicity.
**Full answer:** Modern CPUs cache variable values in per-core registers and L1 caches for performance — without volatile, a write from Thread A may not be visible to Thread B for an unpredictable amount of time because Thread B is reading from its own stale cache. Marking a field volatile tells the JVM to always read from and write to main memory and establishes a happens-before relationship between a write and all subsequent reads of that field. However, volatile does NOT make compound operations atomic — volatile int counter; counter++ is still a read-modify-write sequence that can race between threads. Use volatile for boolean flags (volatile boolean running = true) or single-writer/multi-reader patterns; use AtomicInteger or synchronized for compound updates like incrementing.

---

**Q7: What is the difference between a synchronized method and a synchronized block?**
**One-line answer:** Method locks entire object/class; block locks specified object — finer granularity, better performance.
**Full answer:** A synchronized instance method locks on this (the current object) for the entire duration of the method; a synchronized static method locks on the Class object. A synchronized block lets you specify exactly which object to lock and for exactly which lines of code — you can lock on a dedicated private final Object lock = new Object() that is separate from the instance, preventing external code from accidentally acquiring the same monitor. Finer granularity means less contention: two synchronized blocks in the same class protecting independent data with independent lock objects can run truly concurrently on different threads. Always prefer the narrowest lock scope and shortest critical section possible to maximize throughput.

---

**Q8: How does HashMap handle collisions?**
**One-line answer:** Uses chaining (linked list at bucket); Java 8+ converts to balanced tree when chain length >= 8.
**Full answer:** A HashMap stores entries in an array of buckets; the bucket index is determined by hash(key) % capacity. When two keys hash to the same bucket (a collision), HashMap stores them as a linked list at that bucket — each node holds the key, value, hash, and a reference to the next node in the chain. In Java 8+, if a single bucket's chain grows to 8 or more entries, HashMap converts that chain to a red-black tree (a self-balancing binary search tree), changing worst-case lookup in that bucket from O(n) to O(log n). When the map is resized (triggered when the number of entries exceeds capacity × load factor, default 0.75), tree bins are converted back to linked lists if they shrink below 6 entries.

---

**Q9: What is the difference between final, finally, and finalize()?**
**One-line answer:** final: immutable var/method/class; finally: always-runs cleanup block; finalize(): deprecated GC hook.
**Full answer:** final is a keyword — on a variable it means the reference cannot be reassigned after initialization (the object itself can still be mutated if it is not immutable), on a method it prevents subclasses from overriding it, and on a class it prevents subclassing entirely, as with String. finally is part of try-catch-finally control flow and its block always executes whether or not an exception was thrown — it is the correct place for cleanup like closing streams, though try-with-resources (AutoCloseable) is now preferred because it is cleaner and handles exceptions from close() correctly. finalize() is an instance method on Object that the Garbage Collector was supposed to call before collecting an object — it was unreliable, caused GC pauses by resurrecting objects, and was deprecated in Java 9 and removed in Java 18; use Cleaner or try-with-resources instead.

---

**Q10: Explain Java Generics type erasure.**
**One-line answer:** Generic type info removed at compile time; List<String> becomes List at runtime; enables backward compatibility.
**Full answer:** Generics in Java are a compile-time feature — the compiler uses type parameters to check assignments and method calls for type safety, but then erases all generic type information before generating bytecode. At runtime, List<String> and List<Integer> are both just List (a raw type) — there is no way to ask "is this a List<String>?" via instanceof at runtime. This was a deliberate design decision to maintain backward compatibility with pre-Java-5 bytecode that expected raw types and to avoid the runtime overhead of carrying type metadata. The consequence is that you cannot create generic arrays (new T[] is illegal), cannot use generic type parameters in instanceof checks, and may encounter unchecked cast warnings when working with reflection or legacy generic APIs.

---

**Q11: What is the difference between ArrayList and LinkedList?**
**One-line answer:** ArrayList: O(1) random access, O(n) insert/delete middle; LinkedList: O(1) insert/delete at ends, O(n) random access.
**Full answer:** ArrayList stores elements in a contiguous array — accessing element at index i is O(1) because it is a direct memory offset calculation from the array base address. Inserting or deleting in the middle requires shifting all subsequent elements one position, which is O(n). LinkedList stores elements as doubly-linked nodes where each node holds a reference to the previous and next node — adding or removing at the head or tail is O(1), but finding element at index i requires traversing nodes from the head, which is O(n). In practice, ArrayList outperforms LinkedList for almost all workloads because contiguous memory access is cache-friendly — the CPU prefetcher can load the next element before it is needed, whereas pointer chasing in LinkedList causes frequent cache misses. Use LinkedList only if you specifically need the Deque (double-ended queue) interface.

---

**Q12: How does ThreadLocal work?**
**One-line answer:** Each thread gets its own copy of the variable; backed by Thread.threadLocals map; prevent leaks with remove().
**Full answer:** Each Java Thread object has an internal ThreadLocalMap field that stores a mapping from ThreadLocal instances to their per-thread values. When you call threadLocal.get(), the JVM looks up the current thread's own map and returns its specific value — no synchronization is needed because each thread reads and writes only its own map. This is the mechanism behind Spring's transaction synchronization (the current JDBC Connection is stored in ThreadLocal so the same connection is reused throughout a transaction) and RequestContextHolder (the current HTTP request is stored per-thread). The critical danger is thread pool reuse: pooled threads are never destroyed, so ThreadLocal values set during one request persist into the next task that runs on that thread unless you explicitly call threadLocal.remove() after the request completes — failing to do so causes subtle cross-request data leaks.

---

**Q13: What is the Java Memory Model's happens-before relationship?**
**One-line answer:** Guarantees action A's effects visible to B; established by: synchronized, volatile, thread start/join, lock release/acquire.
**Full answer:** The Java Memory Model (JMM) defines exactly when one thread's writes are guaranteed to be visible to another thread's reads. Without a happens-before relationship, the compiler and CPU are free to reorder instructions for optimization, meaning Thread B might read a stale cached value even after Thread A has written a new one to main memory. A happens-before relationship is established by: releasing and then acquiring a synchronized lock (the unlock in Thread A happens-before any subsequent lock acquisition in Thread B), writing and then reading a volatile variable (the write happens-before the read if the read observes the written value), Thread.start() (all actions before start() happen-before anything in the new thread), and Thread.join() (everything in the joined thread happens-before join() returns). When in doubt, use java.util.concurrent classes which are built on and document these guarantees explicitly.

---

**Q14: Explain ForkJoinPool and work-stealing.**
**One-line answer:** Thread pool where idle threads steal tasks from busy threads' queues; optimized for recursive divide-and-conquer.
**Full answer:** ForkJoinPool is a specialized ExecutorService designed for tasks that recursively split themselves into smaller subtasks (the fork step) and then combine their results (the join step) — the classic example is a parallel merge sort or parallel stream aggregate. Each worker thread has its own double-ended deque (deque) of tasks and pops work from its own head end. Work-stealing is what happens when a thread's deque is empty: instead of blocking, it steals tasks from the tail of another busy thread's deque, minimizing contention because the busy thread pushes and pops from the opposite end. This keeps all CPU cores busy even when tasks are unevenly distributed across threads. Java 8's parallel streams and CompletableFuture.supplyAsync() use the common ForkJoinPool by default, sized to the number of available CPU cores (Runtime.getRuntime().availableProcessors()).

---

**Q15: What is the difference between Checked and Unchecked exceptions?**
**One-line answer:** Checked: must be declared/caught (IOException); Unchecked: RuntimeException subclasses, optional handling.
**Full answer:** Checked exceptions extend Exception directly (but not RuntimeException) and the Java compiler enforces that every checked exception thrown by a method is either caught within that method or declared in its throws clause — this compile-time enforcement is why they are called "checked." The intent is to force callers to acknowledge and handle recoverable conditions like file not found (IOException) or connection timeout (SQLException). Unchecked exceptions extend RuntimeException and the compiler places no such requirement — they typically represent programming errors like NullPointerException or ArrayIndexOutOfBoundsException that callers cannot reasonably handle at every call site. In modern Java, the trend (and Spring's approach with DataAccessException) is to wrap checked exceptions in unchecked ones so callers can choose whether to handle them rather than being forced to, reducing boilerplate in service layers.

---

### Spring / JPA (Q16–Q30)

**Q16: What is the Spring IoC container?**
**One-line answer:** Inversion of Control: container creates and manages bean lifecycle/dependencies; reduces coupling via DI.
**Full answer:** Inversion of Control (IoC) means the framework — Spring — creates and wires your objects rather than your code explicitly calling new SomeService(). You declare what your class needs (via constructor injection annotated with @Autowired, or @Bean factory methods) and Spring's ApplicationContext resolves and injects the matching beans at startup. This decouples your classes from their concrete dependencies — OrderService can depend on a PaymentGateway interface, and Spring injects whichever implementation is on the classpath, making it trivial to swap implementations in different environments or inject mocks in unit tests. The container also manages the full bean lifecycle: instantiation, dependency injection, post-construct initialization (@PostConstruct), and pre-destroy cleanup (@PreDestroy).

---

**Q17: Explain @Transactional propagation types.**
**One-line answer:** REQUIRED (default, join/create), REQUIRES_NEW (new tx), SUPPORTS (join if exists), MANDATORY (must exist).
**Full answer:** REQUIRED (the default) checks whether a transaction already exists; if yes it joins it, if no it creates a new one — this is correct for most service methods that must run within a transaction. REQUIRES_NEW always suspends any existing transaction and opens a fresh independent transaction that commits or rolls back on its own — use this for audit logging that must persist even if the outer transaction rolls back. SUPPORTS joins an existing transaction if one is present but runs non-transactionally if there is none — appropriate for read-only query methods that work correctly either way. MANDATORY throws an exception if no transaction exists, enforcing that the method must always be called from within an already-active transaction. NEVER suspends any existing transaction and runs without one; NOT_SUPPORTED also suspends but runs without; NESTED creates a savepoint within the current transaction, allowing partial rollback.

---

**Q18: What is the N+1 problem in JPA?**
**One-line answer:** 1 query for parent + N queries for each child; fix with JOIN FETCH or @EntityGraph.
**Full answer:** The N+1 problem occurs when JPA loads a list of parent entities and your code then accesses a LAZY-loaded association on each one — JPA fires one additional SELECT per parent to load that association, resulting in 1 + N total queries. For example, loading 100 orders and then accessing order.getItems() in a loop produces 101 queries — 1 for the orders list and 1 for each order's items. Fix it with a JPQL JOIN FETCH: SELECT o FROM Order o JOIN FETCH o.items — this produces a single SQL JOIN that loads both parents and children together. @EntityGraph on a repository method achieves the same result without modifying the JPQL string, useful when you want the JOIN FETCH behavior conditionally. Always verify your query count with Hibernate's show_sql property or a DataSource proxy library in your integration tests.

---

**Q19: Difference between @Component, @Service, @Repository, @Controller?**
**One-line answer:** All create Spring beans; @Repository adds exception translation; @Controller enables MVC mapping.
**Full answer:** All four annotations are Spring stereotypes — they cause component scanning to detect the annotated class and register it as a managed bean in the ApplicationContext, making them functionally equivalent for basic dependency injection. The differences are behavioral and semantic: @Repository activates a PersistenceExceptionTranslationPostProcessor that converts low-level database exceptions (JPA's PersistenceException, JDBC's SQLException) into Spring's DataAccessException hierarchy, giving callers a consistent exception type regardless of which ORM or driver is used. @Controller marks the class as a Spring MVC handler, causing DispatcherServlet to scan it for @RequestMapping methods that handle HTTP requests. @Service has no additional behavior beyond @Component — it is a semantic marker communicating "this bean contains business logic." Always use the most specific annotation that accurately describes the bean's role.

---

**Q20: How does Spring @Cacheable work?**
**One-line answer:** Proxy intercepts method; checks cache for key; returns cached value or calls method and caches result.
**Full answer:** @Cacheable is implemented through Spring AOP (Aspect-Oriented Programming) — when another bean calls the annotated method, Spring's dynamically generated proxy intercepts the call before it reaches the real object. The proxy computes a cache key (by default derived from the method parameters) and queries the configured CacheManager (backed by Redis, Caffeine, EhCache, or another provider) for that key. On a cache hit it returns the stored value immediately without ever invoking the real method. On a cache miss it calls the real method, stores the return value under the computed key in the cache, and returns the value to the caller. The key gotcha is self-invocation: calling this.cachedMethod() from within the same class bypasses the proxy entirely, making caching invisible — the method always executes. Move cached methods to a separate bean or use ApplicationContext.getBean() to go through the proxy.

---

**Q21: JPA first-level vs second-level cache.**
**One-line answer:** L1: EntityManager-scoped (per transaction); L2: SessionFactory-scoped (shared, needs explicit config).
**Full answer:** The first-level cache, also called the persistence context, is the EntityManager itself — within a single transaction, loading the same entity twice by ID returns the exact same Java object instance because JPA tracks every loaded entity in the context and returns the cached one on the second call. This is always active and completely transparent. The second-level cache sits at the SessionFactory/EntityManagerFactory level and is shared across all transactions and threads — an entity loaded in one transaction can be served from this cache to a completely separate transaction later, avoiding a database round-trip. The L2 cache requires explicit configuration: annotate entities with @Cache(usage = CacheConcurrencyStrategy.READ_WRITE), add a caching provider dependency (Ehcache, Hazelcast, Infinispan), and enable it via hibernate.cache.use_second_level_cache=true. Beware stale data when external tools or other nodes write directly to the database.

---

**Q22: What is @Version in JPA?**
**One-line answer:** Optimistic locking: version field incremented on each update; OptimisticLockException if concurrent modification.
**Full answer:** Optimistic locking assumes conflicts are rare — unlike pessimistic locking which holds a database row lock, it reads freely and checks for conflicts only at write time. When you annotate a field with @Version (typically an Integer or Long), JPA includes it in every UPDATE: UPDATE product SET stock=?, version=version+1 WHERE id=? AND version=?. If the version in the database has changed since the entity was loaded — because another transaction updated the same row — the WHERE clause matches zero rows and JPA throws OptimisticLockException. The caller must catch this and either retry the operation or present a conflict message to the user. This is ideal for web applications where users spend several seconds on an edit form — holding a database lock for that duration would block all other writers on that row and kill throughput.

---

**Q23: Explain Spring Bean scopes.**
**One-line answer:** Singleton (default), Prototype (new per request), Request (HTTP request-scoped), Session (HTTP session-scoped).
**Full answer:** Singleton scope (the default) means Spring creates exactly one instance of the bean per ApplicationContext and returns that same instance to every injection point — this is appropriate for stateless services, repositories, and configuration beans. Prototype scope creates a brand-new bean instance every time one is requested from the context — use this for stateful beans that hold per-operation data that must not be shared between callers. Request scope creates one bean per HTTP request and destroys it when the request completes — useful for request-scoped context objects in web applications. Session scope creates one bean per HTTP session. The critical gotcha: injecting a Prototype or Request-scoped bean into a Singleton-scoped bean causes the Singleton to capture the first instance and reuse it forever — use @Lookup methods or ObjectProvider<T> to get a fresh scoped bean on each access.

---

**Q24: How does @Async work in Spring?**
**One-line answer:** Executes method in separate thread pool; requires @EnableAsync; returns Future/CompletableFuture; self-invocation bypasses.
**Full answer:** @Async works via a proxy — when another bean calls the annotated method, the proxy submits that method's execution to a TaskExecutor (a managed thread pool) and returns immediately, giving back a void (fire-and-forget), Future, or CompletableFuture that the caller can wait on if needed. You must annotate a @Configuration class with @EnableAsync; optionally define a ThreadPoolTaskExecutor bean to control pool size, queue capacity, thread name prefix, and rejection policy for when the queue is full. The same proxy limitation as @Transactional and @Cacheable applies: calling this.asyncMethod() from within the same class runs synchronously on the current thread because the call bypasses the proxy. Also critical: exceptions thrown inside @Async methods are not propagated to the caller — they are lost unless you retrieve them from the returned Future or configure an AsyncUncaughtExceptionHandler.

---

**Q25: What is the difference between EAGER and LAZY loading in JPA?**
**One-line answer:** EAGER: load relation immediately with parent; LAZY: load on first access (default for collections).
**Full answer:** EAGER loading means JPA fetches the associated entities as part of the initial query — you get the parent entity and all its related data in one shot, typically via a SQL JOIN or immediate follow-up SELECTs. LAZY loading defers fetching until your code first accesses the association — JPA generates a proxy object for the association and fires a SELECT only when you call a method on that proxy. The JPA specification defaults are EAGER for @ManyToOne and @OneToOne (single associated entity) and LAZY for @OneToMany and @ManyToMany (collections). Using EAGER on collections is a common performance trap — loading a list of 1000 orders with EAGER items unconditionally fetches all order items for all orders, even when you only need the order summaries. Prefer LAZY universally and fetch what you need explicitly with JOIN FETCH or @EntityGraph in the specific queries that require it.

---

**Q26: Explain Spring Security filter chain.**
**One-line answer:** Chain of OncePerRequestFilter; key filters: UsernamePasswordAuthentication, JwtAuthentication, ExceptionTranslation.
**Full answer:** Spring Security registers a chain of servlet filters that every HTTP request passes through in a defined order before reaching your controller. Each filter extends OncePerRequestFilter — a base class that guarantees the filter executes exactly once per request even when request forwarding or including occurs internally. For a typical JWT-secured REST API the order is: CorsFilter (handles CORS preflight OPTIONS requests), SecurityContextPersistenceFilter (restores the SecurityContext from the session if applicable), your custom BearerTokenAuthenticationFilter (extracts and validates the JWT, creates an Authentication object, and stores it in SecurityContextHolder — a thread-local store for the current user's credentials), ExceptionTranslationFilter (catches AuthenticationException and returns 401, catches AccessDeniedException and returns 403), and finally AuthorizationFilter (checks whether the authenticated principal has the required authorities for the requested resource). Your JWT filter is inserted with http.addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class).

---

**Q27: What is the difference between @Repository and JpaRepository?**
**One-line answer:** @Repository is a stereotype annotation; JpaRepository provides CRUD + pagination + query methods out of the box.
**Full answer:** @Repository is a class-level annotation that marks a class as a data access component — it enables Spring's exception translation (converting database-specific exceptions into DataAccessException) and registers the class as a bean for component scanning, but it provides no methods or behavior of its own. JpaRepository<T, ID> is a Spring Data interface — by extending it you automatically receive generated implementations for findById(), findAll(), save(), delete(), count(), existsById(), and many more without writing any code; Spring Data generates a proxy implementation at runtime. You also get Pageable-based pagination (findAll(Pageable pageable)), Sort support, and the ability to define derived query methods by naming convention such as findByEmailAndActiveTrue(String email). In modern Spring applications, JpaRepository (or CrudRepository for non-JPA stores) is almost always preferred over writing a manual @Repository class.

---

**Q28: How does Spring Boot auto-configuration work?**
**One-line answer:** @EnableAutoConfiguration scans META-INF/spring.factories; conditionally applies configurations based on classpath and properties.
**Full answer:** Spring Boot auto-configuration is activated by the @SpringBootApplication annotation, which includes @EnableAutoConfiguration. At startup, Spring Boot loads a list of candidate auto-configuration classes from META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports (previously spring.factories in older versions). Each candidate class is annotated with conditions that control whether it applies: @ConditionalOnClass (only activate if a specific class is present on the classpath), @ConditionalOnMissingBean (only activate if no bean of the specified type is already defined), and @ConditionalOnProperty (only activate if a configuration property has a certain value). For example, DataSourceAutoConfiguration activates only when a JDBC driver class is on the classpath and no DataSource bean is already defined — it then creates a default HikariCP connection pool using properties from application.properties. You override any auto-configuration simply by defining your own bean of the same type.

---

**Q29: Explain @Transactional and the self-invocation problem.**
**One-line answer:** Calling @Transactional method from same class bypasses Spring proxy; fix: inject self or AopContext.currentProxy().
**Full answer:** Spring's @Transactional works by generating a proxy wrapper around your bean — when external code calls transactionalMethod(), the call goes through the proxy, which opens a transaction, delegates to your real method, and then commits or rolls back. When code inside the same class calls this.transactionalMethod(), it calls the real object directly via the this reference — the proxy is completely bypassed, no transaction is started, and no rollback will happen on exception. This is a common production bug where a public non-transactional method calls inner methods marked @Transactional expecting them to run in separate transactions, but they run without any transaction. Fixes: (1) inject the bean into itself via @Autowired MyService self (works in Spring 4.3+), (2) move the inner method to a separate Spring-managed bean so external calls go through that bean's proxy, or (3) use AopContext.currentProxy() with proxyTargetClass=true and exposeProxy=true, casting the result to call through the proxy.

---

**Q30: What is JPQL vs Criteria API?**
**One-line answer:** JPQL: string-based, entity-centric; Criteria API: type-safe programmatic builder, better for dynamic queries.
**Full answer:** JPQL (Java Persistence Query Language) is a string-based query language that looks like SQL but operates on entity class names and field names rather than database table and column names — for example SELECT o FROM Order o WHERE o.status = 'PAID'. It is readable and familiar to anyone who knows SQL, but it has no compile-time type safety: a typo in a field name compiles successfully and only throws an exception at runtime when the query is parsed. The Criteria API builds queries programmatically using a fluent builder and optionally JPA Metamodel classes (Order_.status) generated at compile time from your entity classes — any invalid field reference is caught at compile time. The Criteria API excels at dynamic queries where filter conditions vary based on user input: you can conditionally add predicates to a list and combine them, which would require ugly string concatenation in JPQL. Spring Data Specifications wrap the Criteria API for composable, reusable query conditions.

---

### REST / Microservices + Kafka / Redis / Security (Q31–Q50)

**Q31: What are the REST constraints?**
**One-line answer:** Client-server, stateless, cacheable, uniform interface, layered system, code-on-demand (optional).
**Full answer:** REST (Representational State Transfer) is an architectural style defined by six constraints. Client-server separation means the UI and data storage concerns are decoupled, allowing them to evolve independently. Stateless means each request from the client contains all information needed to process it — the server holds no client session state between requests, making horizontal scaling trivial. Cacheable means responses must declare whether they can be cached, enabling CDN and browser caching to reduce server load. Uniform interface means resources are identified by URIs, manipulated through standard HTTP methods, responses are self-descriptive, and ideally include hypermedia links (HATEOAS) to discover next actions. Layered system means the client cannot tell if it is talking to the origin server or a proxy/CDN intermediary. Most real-world APIs implement only levels 1–2 of the Richardson Maturity Model (resources + HTTP verbs) without full HATEOAS.

---

**Q32: Difference between PUT and PATCH?**
**One-line answer:** PUT replaces entire resource (idempotent); PATCH partially updates (should be idempotent by design).
**Full answer:** PUT is semantically a full replacement — the client sends the complete representation of the resource and the server replaces whatever is stored with exactly what the client sent. If you PUT a user resource with 5 fields but only include 3, the missing 2 fields are set to null or their defaults on the server. This makes PUT naturally idempotent — sending the same body twice produces the same end state. PATCH sends only the fields that should change, leaving all other fields untouched — this is efficient when resources are large and only a small subset changes. PATCH should be designed to be idempotent (set name="Alice" applied twice has the same result) but the HTTP specification does not technically guarantee it — increment operations are non-idempotent. In practice most REST APIs implement PATCH as idempotent set-field operations.

---

**Q33: What is idempotency and why does it matter?**
**One-line answer:** Same request produces same result regardless of repetitions; critical for safe retries.
**Full answer:** An operation is idempotent if applying it multiple times has exactly the same effect as applying it once — GET, PUT, and DELETE are idempotent (GET never changes state; PUT sets to a fixed value; DELETE on an already-deleted resource is a no-op); POST is not idempotent by default (posting a create-order request twice creates two orders). Idempotency matters enormously for reliability in distributed systems: when a network request times out, the client cannot know whether the server received and processed the request or not — with idempotent operations it is always safe to retry without risk of duplicated side effects. For non-idempotent POST operations like placing an order or processing a payment, implement idempotency keys: the client generates a UUID, sends it as Idempotency-Key: <uuid>, and the server stores the key + response; retries with the same key return the stored response without re-executing the operation.

---

**Q34: How do you handle distributed transactions in microservices?**
**One-line answer:** Saga pattern (choreography or orchestration); eventual consistency; avoid 2PC.
**Full answer:** Two-phase commit (2PC) coordinates transactions across multiple databases: a coordinator sends "prepare" to all participants, waits for confirmations, then sends "commit" — but if the coordinator crashes between prepare and commit, all participants hold their locks indefinitely waiting for a decision that never comes, causing a system-wide deadlock. The Saga pattern solves this by breaking a distributed transaction into a sequence of local transactions — each microservice commits its own data locally and then publishes an event or receives a command to trigger the next step. If a step fails, previously committed steps are undone by compensating transactions (cancel reservation, refund payment). Choreography uses events so services react independently — loosely coupled but hard to visualize the full flow. Orchestration uses a central Saga Orchestrator (Temporal, Axon) that explicitly sequences steps — easier to monitor and debug at the cost of a coordination dependency.

---

**Q35: What is the Circuit Breaker pattern?**
**One-line answer:** Downstream fails repeatedly → circuit opens → requests fail fast → half-open to probe recovery.
**Full answer:** The Circuit Breaker pattern prevents an application from repeatedly wasting thread resources waiting on a downstream service that is clearly unavailable or degraded. In the CLOSED state (normal operation), requests flow through and failures are tracked in a sliding window. When the failure rate exceeds a configured threshold (e.g., 50% of calls in the last 10 seconds), the circuit OPENS — all subsequent requests immediately throw an exception without ever attempting the downstream call, failing fast and freeing threads instantly. After a configured timeout (e.g., 30 seconds), the circuit enters HALF-OPEN and allows a small number of probe requests through to test whether the downstream service has recovered. If probes succeed the circuit returns to CLOSED; if they fail it OPENS again. Without this pattern, a slow downstream exhausts your thread pool — all threads block waiting for timeout, your service's response times blow up, and the failure cascades to your callers (cascading failure). Resilience4j is the standard library in Spring for implementing this.

---

**Q36: Explain API Gateway responsibilities.**
**One-line answer:** Routing, auth/authZ, rate limiting, SSL termination, request/response transformation, load balancing, observability.
**Full answer:** An API Gateway is the single entry point that all client requests pass through before reaching any backend microservice. It handles SSL termination (decrypting HTTPS at the gateway so backend services communicate over plain HTTP on the internal network), routes requests to the correct backend service based on path patterns (/users/** → user-service, /orders/** → order-service), validates and optionally parses JWT tokens centrally so each microservice does not need to implement auth logic independently, enforces rate limits per client API key or IP address to prevent abuse, transforms request and response formats (e.g., presenting a REST interface to clients while routing to gRPC backends), and injects distributed trace headers for observability. Common implementations are AWS API Gateway, Kong, and Spring Cloud Gateway. The anti-pattern to avoid is embedding business logic in the gateway — it should remain pure infrastructure to avoid becoming a bottleneck and deployment dependency.

---

**Q37: What is a service mesh?**
**One-line answer:** Infrastructure layer for service-to-service communication: traffic management, mTLS, observability; Istio, Linkerd.
**Full answer:** A service mesh offloads cross-cutting networking concerns from application code into a dedicated infrastructure layer. Each application pod gets a sidecar proxy (Envoy in Istio, a tiny lightweight proxy in Linkerd) injected alongside it — all inbound and outbound network traffic flows through this sidecar, which the application code is completely unaware of. A control plane (Istiod in Istio) pushes configuration and policies to all sidecars across the cluster. This enables: automatic mutual TLS (mTLS) between all services — each sidecar authenticates peer certificates — providing encryption and identity without any application code change; circuit breaking, retries, and timeout configuration via YAML policies; traffic splitting for canary deployments (route 10% of traffic to v2, 90% to v1); and automatic distributed tracing metrics collection. The cost is real: each sidecar adds 1–2ms latency and ~50MB memory per pod, plus operational complexity of the control plane — justified for large deployments, overkill for a few services.

---

**Q38: Sync vs async microservice communication?**
**One-line answer:** Sync (REST/gRPC): tight coupling, real-time; Async (Kafka/RabbitMQ): loose coupling, better resilience, eventual consistency.
**Full answer:** Synchronous communication (HTTP REST or gRPC) means the caller sends a request and blocks waiting for a response — if the downstream service is slow, the caller's thread is blocked for the duration; if the downstream is down, the caller gets an immediate error. This creates temporal coupling: both services must be simultaneously available for the interaction to succeed, and a slow dependency can exhaust the caller's thread pool through cascading wait. Asynchronous communication via a message broker like Kafka or RabbitMQ decouples availability — the producer writes a message to the broker and continues processing without waiting; the consumer reads and processes the message whenever it is ready. If the consumer is temporarily down, messages queue up in the broker and are processed when it recovers, with no data loss. The trade-off is complexity: async systems require designing for eventual consistency (the result is not immediate), idempotent consumers (messages may be delivered more than once), and out-of-order processing — and tracing a request's end-to-end flow across async boundaries requires distributed tracing.

---

**Q39: What is the Outbox pattern?**
**One-line answer:** Write to DB + outbox table in same transaction; publisher reads and delivers; guarantees at-least-once publishing.
**Full answer:** The dual-write problem: if you write to your database and then publish an event to Kafka as two separate operations, a process crash between them means either the database was updated but the event was lost (downstream services never learn about the change) or the event was published but the database transaction rolled back (phantom event describing a change that did not happen). The Outbox pattern solves this by writing the event as a row in an OUTBOX table in the same local database transaction as your business data — because both writes are in one ACID transaction, they atomically succeed or fail together. A separate Outbox Publisher process (or CDC — Change Data Capture — via Debezium reading the database's transaction log) queries for unpublished outbox records, delivers them to Kafka, and marks them as published. Since the publisher retries on failure, consumers must be idempotent — the same event may arrive more than once (at-least-once delivery), but it will never be lost.

---

**Q40: How do you implement distributed tracing?**
**One-line answer:** Propagate trace ID across service calls via HTTP headers; OpenTelemetry + Jaeger/Zipkin; correlate logs by trace ID.
**Full answer:** When a user request flows through multiple microservices, a log line from one service is useless in isolation — you need to correlate all spans across all services into a single trace. Distributed tracing assigns a unique trace ID to every incoming request; when that service calls another service it injects the trace ID into an HTTP header (the W3C TraceContext standard uses traceparent: 00-{traceId}-{spanId}-01). Each service creates child spans — units of work with their own span IDs, start time, end time, service name, and tags — and reports them to a tracing backend. OpenTelemetry is the CNCF vendor-neutral SDK for instrumenting code in any language; it exports span data to Jaeger, Zipkin, or Grafana Tempo for visualization and querying. In Spring Boot 3, adding spring-boot-starter-actuator, micrometer-tracing-bridge-otel, and an exporter dependency auto-instruments RestTemplate, WebClient, Feign, and JDBC calls with no code changes — the trace ID is also automatically added to MDC (Mapped Diagnostic Context) so every log line includes it.

---

**Q41: What is HATEOAS?**
**One-line answer:** Responses include links to next possible actions; client discovers API rather than hardcoding URLs.
**Full answer:** HATEOAS — Hypermedia As The Engine Of Application State — is level 3 of the Richardson Maturity Model for REST APIs, the highest level of RESTful maturity. Instead of a client application hardcoding every possible URL and knowing the full API structure in advance, each response body includes _links describing what actions are possible from the current resource state. For example, a GET /orders/123 response might include a "cancel" link (only present if the order is still cancellable), a "payment" link (only present if payment exists), and a "self" link. The client follows these links dynamically rather than constructing URLs — meaning the server can change URL structures and business rules without breaking clients that navigate via links. Spring HATEOAS provides EntityModel, CollectionModel, and WebMvcLinkBuilder to add links to responses. In practice, fully HATEOAS-compliant APIs are relatively rare because of the implementation overhead and the need for clients to handle dynamic link discovery.

---

**Q42: How do you version APIs?**
**One-line answer:** URI (/v1/), header (Accept: application/vnd.v2+json), query param (?version=2); URI is most visible.
**Full answer:** URI versioning (/api/v1/users) is the most widely used approach — the version is visible in the URL, shows up in browser history and server logs, and is easy to understand and document. It is not strictly RESTful (the version is not a property of the resource) but pragmatism wins in most organizations. Header versioning uses a custom Accept header like Accept: application/vnd.myapi.v2+json or a dedicated X-API-Version: 2 header — this keeps URLs clean and is more REST-theoretically correct, but it requires clients to set headers explicitly and makes testing with a browser or basic curl harder. Query parameter versioning (/users?version=2) is very easy to test but pollutes the query string and can conflict with caching (some caches ignore query parameters). Regardless of strategy, the non-technical rule is most important: never break or remove an API version while active clients depend on it, maintain at least the previous major version, and publish a deprecation timeline with adequate notice.

---

**Q43: What is the Bulkhead pattern?**
**One-line answer:** Isolate resource pools per downstream; failure in one doesn't exhaust resources for others.
**Full answer:** The bulkhead pattern takes its name from the watertight compartments in a ship's hull — if one compartment floods, the sealed bulkheads prevent the water from spreading and sinking the entire ship. In microservices, if Service A calls both Service B and Service C using the same shared thread pool, a slow or unresponsive Service B can exhaust all available threads, making Service A unable to handle calls to Service C even though Service C is perfectly healthy — this is resource contamination. Bulkheads create isolated resource pools per downstream dependency: Service B gets its own dedicated thread pool of N threads, Service C gets its own; a backlog in B's pool only fails B-bound calls. Resilience4j's @Bulkhead annotation supports two modes: SEMAPHORE (limits the number of concurrent calls in the current thread without a separate pool, lower overhead) and THREADPOOL (a true separate thread pool, returning CompletableFuture). Size each pool based on the expected concurrency and the downstream service's SLA.

---

**Q44: Explain eventual consistency and how to handle it.**
**One-line answer:** System reaches consistency after some delay; handle with idempotent consumers, compensating transactions, "processing" state.
**Full answer:** Eventual consistency means that after a write completes, all nodes and services in a distributed system will converge to the same value — but not immediately. During the convergence window, different services may return different data: a user who just created an order may see it immediately in the order service, but the inventory service may still show the pre-order stock level for a short time. On the consumer side, handle this by making all operations idempotent so processing the same event multiple times produces the same outcome — use a processed_event_ids table to deduplicate. In the user interface, show an explicit "processing" or "pending" state immediately after a write so users are not confused by temporary inconsistency. Use correlation IDs to associate a user action with its eventual completion event via a websocket or polling endpoint. For the user who just made a change, implement read-your-writes consistency by routing their immediate follow-up reads to the primary database for a short window.

---

**Q45: What is gRPC and when prefer it over REST?**
**One-line answer:** Google RPC using Protocol Buffers + HTTP/2; prefer for internal high-throughput inter-service communication.
**Full answer:** gRPC uses Protocol Buffers (a binary serialization format — more compact and faster to encode/decode than JSON, typically 3–10× smaller for the same data) transmitted over HTTP/2 (which supports multiplexed streams — multiple concurrent requests share a single TCP connection, eliminating the connection overhead that HTTP/1.1 suffers from). Service contracts are defined in .proto files and gRPC generates strongly-typed client stubs and server interfaces in your target language — no hand-written HTTP clients or manual JSON parsing. Advantages over REST: lower latency due to binary encoding and HTTP/2 multiplexing, compile-time type safety via generated code, built-in support for bi-directional streaming (client can stream requests while server streams responses simultaneously), and auto-generated multi-language clients. Disadvantages: binary format is not human-readable (you cannot inspect payloads with curl without a decoder), browser support requires a gRPC-Web proxy, and the tooling learning curve is steeper. Use gRPC for internal microservice-to-microservice calls where performance is critical; use REST for public-facing APIs that need broad client compatibility and HTTP caching.

---

**Q46: What is a Kafka consumer group?**
**One-line answer:** Group of consumers sharing partition load; each partition consumed by exactly one consumer in the group.
**Full answer:** A consumer group is a named set of consumer instances that cooperate to consume messages from a Kafka topic in parallel. Kafka's broker assigns each partition of the topic to exactly one consumer within the group at any given time — this guarantees that messages in a partition are processed sequentially by a single consumer, preserving per-partition ordering. If a consumer group has 3 active consumers and the topic has 6 partitions, each consumer is assigned 2 partitions and processes them independently in parallel. Scaling up: adding more consumers increases throughput up to the number of partitions; adding consumers beyond the partition count results in idle consumers (a partition cannot be split between two consumers). Multiple different consumer groups each receive their own independent copy of all messages — reading from a topic in consumer group "billing" does not advance the offset for consumer group "analytics," allowing multiple downstream systems to consume the same event stream independently.

---

**Q47: How does Kafka ensure message ordering?**
**One-line answer:** Ordering guaranteed within a partition only; use same partition key for messages requiring order.
**Full answer:** Kafka maintains a strictly ordered, append-only log within each partition — messages written to partition 0 are always delivered to a consumer in exactly the order they were written. However, a topic with multiple partitions has no ordering guarantee across partitions — messages from partition 0 and partition 1 are consumed by different threads and may interleave in any order relative to each other. To guarantee that all events for the same logical entity are processed in order, use a partition key: Kafka hashes the key and deterministically routes all messages with the same key to the same partition. All events for orderId="123" go to the same partition and are consumed in order by the same consumer thread. The trade-off is hot partitions: if one key has dramatically higher volume than others (a celebrity user generating millions of events), the consumer for that partition falls behind while others are idle — mitigate with key salting or topic sub-partitioning strategies.

---

**Q48: Kafka delivery semantics — at-most-once, at-least-once, exactly-once?**
**One-line answer:** At-most-once (may lose), at-least-once (may duplicate), exactly-once (idempotent producer + transactional API).
**Full answer:** At-most-once delivery commits the consumer offset before processing the message — if the consumer crashes after committing but before finishing processing, that message is skipped permanently. No duplicates, but data loss is possible; acceptable only for non-critical metrics. At-least-once delivery commits the offset only after processing completes — if the consumer crashes after processing but before committing, the message is reprocessed on restart, resulting in possible duplicates. No data loss, but the consumer must be idempotent to handle duplicates safely; this is the correct default for most systems. Exactly-once semantics (EOS) require: idempotent producer (enable.idempotence=true, Kafka deduplicates retried publishes using producer sequence numbers), transactional API (transactional.id configured, messages committed atomically with offset commits), and consumer with isolation.level=read_committed (only sees messages from committed transactions). This adds roughly 20% throughput overhead. Use at-least-once with idempotent consumers for most cases; reserve EOS for financial or billing systems where duplicates cause real monetary harm.

---

**Q49: What are Redis eviction policies?**
**One-line answer:** LRU (least recently used), LFU (least frequently used), TTL-based; configure maxmemory-policy.
**Full answer:** When Redis reaches its configured maxmemory limit and a new write command arrives, the eviction policy determines which existing key to remove to make room. noeviction returns an error on write — correct when data must never be silently discarded. allkeys-lru evicts the key that was least recently accessed from the entire keyspace — the best general-purpose cache policy for uniform access patterns. volatile-lru evicts the least recently used key only among keys that have a TTL (expiry time) set — useful when Redis holds a mix of durable data (no TTL) and cache data (has TTL) and you must never evict the durable data. allkeys-lfu evicts the least frequently accessed key — superior to LRU when access patterns are highly skewed, like a social media cache where a few viral posts are accessed millions of times and should be retained while infrequently accessed items are evicted first. volatile-ttl evicts the key with the shortest remaining TTL. Choose based on your access pattern; monitor cache hit rates and eviction metrics in production to validate your choice.

---

**Q50: How do you implement a distributed lock with Redis?**
**One-line answer:** SET key value NX PX timeout atomic; Redisson watchdog extends TTL; release with Lua script.
**Full answer:** A distributed lock using Redis is acquired with the atomic command SET lock_key unique_value NX PX 30000, where NX means "only set if the key does not already exist" and PX 30000 means "auto-expire in 30000 milliseconds" — because this is a single atomic Redis command, there is no race condition between checking existence and setting the value. The value must be a unique identifier per lock holder (a UUID generated by the calling process) so that the release step can verify ownership. To release: use a Lua script (if redis.call("GET", KEYS[1]) == ARGV[1] then return redis.call("DEL", KEYS[1]) else return 0 end) — Lua scripts execute atomically in Redis, preventing the race condition where your lock expires, another process acquires it, and you accidentally delete their lock by running GET then DEL as two separate commands. Redisson's RLock adds a watchdog timer: a background thread that automatically extends the lock's TTL every 10 seconds while the owning thread is still alive, preventing premature expiry during unexpectedly long critical sections. Always release the lock in a finally block to prevent deadlock if processing throws an exception.

---

### Kafka/Redis/Security (Q46–Q60)

**Q51: What is Redis Pub/Sub? Limitations?**
**One-line answer:** Fire-and-forget messaging; not persistent; no consumer groups; use Kafka for durable messaging.
**Full answer:** Redis Pub/Sub allows publishers to send messages to named channels and all currently-subscribed clients receive them instantly — it's a real-time broadcast mechanism built into Redis. It's fire-and-forget: if no subscriber is listening when the message is published, the message is silently dropped — there is no storage, no replay, no acknowledgment whatsoever. Unlike Kafka's consumer groups (which allow multiple independent consumers each tracking their own offset into a persistent log), Redis Pub/Sub has no concept of distributed consumption or offset tracking — every active subscriber gets every message, and any offline subscriber misses it permanently. Use Redis Pub/Sub for real-time notifications where losing a message is acceptable (live sports score updates, presence indicators); use Redis Streams or Kafka when reliability, replay, or consumer group semantics are required.

---

**Q52: What is JWT? How is it validated?**
**One-line answer:** Header.payload.signature; verify signature; stateless authentication; check exp and aud claims.
**Full answer:** A JWT (JSON Web Token) is three Base64url-encoded sections separated by dots: the header (which algorithm and token type), the payload (claims — sub for subject, iss for issuer, exp for expiry, aud for audience, plus custom claims like roles), and the signature (a cryptographic proof that the header and payload haven't been tampered with). Validation steps are: split on dots and Base64url-decode each part, verify the signature using the expected algorithm and key (for RS256 this means fetching the Authorization Server's public key from /.well-known/jwks.json and verifying the signature cryptographically), then check that exp is in the future (token not expired), iss matches your trusted Authorization Server, and aud includes your service (this last check prevents a token issued for Service A from being accepted by Service B). Never accept the alg:none algorithm — attackers can craft tokens with no signature if you don't explicitly allowlist the expected algorithm.

---

**Q53: Explain OAuth2 authorization code flow.**
**One-line answer:** User → Auth server → authorization code → client exchanges for access token; code never exposed to browser.
**Full answer:** The Authorization Code flow is designed so the access token never touches the browser's URL bar or JavaScript context. Step 1: your app redirects the user to the Authorization Server (Keycloak, Auth0) with client_id, redirect_uri, scope, and a state parameter (a random value you store to prevent CSRF attacks). Step 2: the user authenticates and consents; the Auth Server redirects back to your redirect_uri with a short-lived authorization code in the query parameter. Step 3: your server-side code exchanges this code for access_token + refresh_token via a POST to the /token endpoint with the client_secret — this is a server-to-server call not visible to the browser, which is exactly why the code is safe to pass through the browser but the token exchange happens server-side. For SPAs and mobile apps where client_secret can't be safely stored, add PKCE (Proof Key for Code Exchange — a dynamically generated challenge/verifier pair) to prevent authorization code interception attacks.

---

**Q54: What is the difference between authentication and authorization?**
**One-line answer:** AuthN: verify who you are; AuthZ: verify what you can do.
**Full answer:** Authentication (AuthN) is the process of verifying identity — "I am user@example.com" — typically via password, biometric, or SSO token. It answers "who are you?" and results in a verified principal (an identity the system trusts). Authorization (AuthZ) is the process of verifying permissions — "can user@example.com delete this order?" — typically enforced via roles, OAuth2 scopes, or access control lists checked against the verified principal. AuthZ always comes after AuthN: you must know who someone is before deciding what they can do. A common point of confusion: HTTP 401 Unauthorized means "not authenticated" (credentials missing or invalid), while HTTP 403 Forbidden means "authenticated but not permitted" — the HTTP status code names are historically misleading, but the distinction matters for client error handling.

---

**Q55: How do you prevent SQL injection?**
**One-line answer:** Parameterized queries; ORM; input validation; least privilege on DB user.
**Full answer:** SQL injection occurs when user-supplied input is concatenated directly into a SQL string — an attacker can inject SQL metacharacters (single quotes, comment markers) to modify the query's logic, bypass authentication, or dump the entire database. The primary defense is parameterized queries (also called prepared statements): the SQL structure is compiled separately from the data, and the database driver ensures data values are never interpreted as SQL syntax regardless of their content. Using JPA/Hibernate provides this automatically since JPQL and the Criteria API always parameterize inputs. Input validation adds defense-in-depth (reject clearly invalid input early) but is not sufficient alone since attackers find creative encoding bypasses. Running the application's DB user with minimum necessary privileges (no DROP TABLE, no access to other schemas) limits blast radius if injection does somehow occur. Never use string concatenation for queries that include user-controlled input.

---

**Q56: What is CORS and how do you fix it?**
**One-line answer:** Cross-Origin Resource Sharing; browser blocks cross-origin requests unless server sends Allow-Origin header.
**Full answer:** CORS is a browser security policy that prevents JavaScript on one origin (https://app.example.com) from making requests to a different origin (https://api.other.com) without explicit server permission — the "origin" is the scheme + hostname + port combination. The browser enforces this by sending an OPTIONS preflight request first for non-simple requests (those with custom headers, non-GET/POST methods, or JSON bodies), and the server must respond with Access-Control-Allow-Origin: https://app.example.com, Access-Control-Allow-Methods, and Access-Control-Allow-Headers — if it doesn't, the browser blocks the actual request and JavaScript sees a generic network error. Fix in Spring Boot: annotate controllers with @CrossOrigin, or configure a CorsRegistry in WebMvcConfigurer, or add a global CorsFilter bean. One important constraint: you cannot combine Access-Control-Allow-Origin: * (wildcard) with Access-Control-Allow-Credentials: true — the browser blocks this combination to prevent credential-bearing wildcard requests.

---

**Q57: Explain Kafka consumer lag and how to monitor it.**
**One-line answer:** Lag = latest offset - consumer committed offset; alert on sustained growth; use kafka-consumer-groups.sh or Prometheus.
**Full answer:** Consumer lag is the number of messages in a Kafka partition that have been produced but not yet processed by a consumer group — specifically, it's the difference between the partition's latest offset (the most recently written message) and the consumer group's committed offset (the last message the consumer acknowledged). Lag of zero means the consumer is processing messages in real-time; growing lag means messages are arriving faster than the consumer can process them, which will eventually cause data freshness issues or backlog buildup. Monitor with the CLI tool kafka-consumer-groups.sh --describe --group my-group which shows per-partition lag, or deploy the kafka-lag-exporter (a Prometheus-compatible exporter) to create Grafana dashboards and alerts. Remediation options: add more partitions (and proportionally more consumer instances since consumer parallelism is capped at partition count), optimize per-message processing time, increase max.poll.records to process more messages per poll cycle, or scale out consumer instances.

---

**Q58: What is Redis pipeline and when to use it?**
**One-line answer:** Send multiple commands without waiting for responses; reduces network round trips; not atomic.
**Full answer:** Normally each Redis command requires one full network round trip — the client sends the command, waits for the server's response, then sends the next command, which is slow when you need many operations. With pipelining, the client sends multiple commands in a single TCP write without waiting for individual responses, then reads all responses together in a single batch — this reduces total latency from N × RTT (round-trip time) to approximately 1 × RTT regardless of how many commands are pipelined. The critical distinction: pipelining is NOT atomic — other Redis clients can interleave their commands between your pipeline's commands, so you have no isolation guarantee. For atomic multi-command operations use MULTI/EXEC transactions (buffered and executed atomically) or Lua scripts (executed atomically on the Redis server). Use pipelining for bulk read or write operations where atomicity isn't required, such as warming a cache with many keys or batch-incrementing counters.

---

**Q59: How does Spring Security CSRF protection work?**
**One-line answer:** Synchronizer token pattern; random token in session; must match token in form POST; stateless APIs disable it.
**Full answer:** CSRF (Cross-Site Request Forgery) is an attack where a malicious website tricks a logged-in user's browser into making unwanted state-changing requests to your application, exploiting the fact that the browser automatically includes session cookies on every request. Spring Security's protection uses the Synchronizer Token Pattern: on page load, the server generates a cryptographically random CSRF token, stores it in the user's HTTP session, and embeds it in HTML forms as a hidden field (or returns it in a cookie for JavaScript apps). Every state-changing request (POST, PUT, DELETE) must include this token as a form parameter or request header — if the token is missing or doesn't match the session value, Spring rejects the request with 403. A malicious third-party site cannot read the CSRF token from your domain (blocked by the same-origin policy), so it can't craft a valid forged request. For stateless REST APIs that authenticate with JWT Bearer tokens (no session cookies), CSRF attacks are impossible — disable the protection with http.csrf(csrf -> csrf.disable()) to avoid the overhead.

---

**Q60: What is Kafka log compaction?**
**One-line answer:** Retain only latest record per key; null value (tombstone) deletes the key; used for changelog/state topics.
**Full answer:** Kafka's default retention strategy deletes old log segments based on time (retention.ms) or total size — regardless of what the messages contain. Log compaction (configured with cleanup.policy=compact) takes a different approach: a background compaction thread periodically scans the log and retains only the most recent record for each distinct message key, removing older versions of the same key. This means a compacted topic always reflects the current state of each key, effectively functioning as a continuously updated key-value snapshot that survives indefinitely. A message with a null value is a "tombstone" — it signals that the key should be deleted, and compaction will eventually remove that key and its tombstone entirely. Use compacted topics for Kafka Streams KTable changelog topics (which need the current value per key to rebuild local state store after a restart), CDC (Change Data Capture) streams representing the current state of database rows, and any event stream where only the latest value per entity identity matters.

---

### SQL/DB (Q61–Q75)

**Q61: Explain ACID properties.**
**One-line answer:** Atomicity (all-or-nothing), Consistency (valid state), Isolation (appear serial), Durability (committed persists).
**Full answer:** Atomicity means a transaction is all-or-nothing — if any step within the transaction fails, all previously completed steps are rolled back using the database's undo log, leaving the data as if the transaction never started. Consistency means the database transitions from one valid state to another — all integrity constraints (foreign key relationships, unique constraints, check constraints, not-null constraints) are satisfied after every committed transaction. Isolation means concurrent transactions appear to execute serially — one transaction's intermediate uncommitted state is never visible to other transactions, with the degree of isolation being configurable via isolation levels (Read Committed, Repeatable Read, Serializable). Durability means once a transaction is committed, its changes survive any subsequent system crash — achieved through the WAL (Write-Ahead Log), which flushes changes to durable storage before the commit is acknowledged to the client.

---

**Q62: What is a database index? What types exist?**
**One-line answer:** Data structure for fast lookup; B-Tree (default), Hash (equality), GIN (JSONB/arrays), Composite (multi-column).
**Full answer:** A database index is a separate data structure that maintains a sorted or hashed mapping from column values to the physical location of matching rows, allowing the database to find rows matching a predicate without scanning every row in the table (a full table scan). B-Tree (the default in PostgreSQL and MySQL) is a balanced tree that supports equality, range queries, ORDER BY sorting, and prefix matching — it offers O(log N) lookup and covers the majority of query patterns. Hash indexes support only equality predicates (WHERE id = 5) and can be marginally faster for that specific case but cannot serve range queries. GIN (Generalized Inverted Index) indexes each element of an array or each key/value of a JSONB document separately, enabling efficient containment queries (@>), full-text search, and array membership checks. Composite indexes cover multiple columns and follow the leftmost prefix rule — an index on (a, b, c) can serve queries filtering on a, or a+b, or a+b+c, but not b alone.

---

**Q63: Explain different SQL isolation levels.**
**One-line answer:** READ UNCOMMITTED (dirty ok), READ COMMITTED (no dirty), REPEATABLE READ (no non-repeatable), SERIALIZABLE (all prevented).
**Full answer:** READ UNCOMMITTED allows reading another transaction's uncommitted changes (dirty reads) — you can see data that may be rolled back, making results potentially meaningless; this is almost never used in practice. READ COMMITTED (the default in PostgreSQL) prevents dirty reads but allows non-repeatable reads: if you read the same row twice within one transaction, the second read can see updates committed by other transactions between the two reads, meaning results can change mid-transaction. REPEATABLE READ (the default in MySQL InnoDB) prevents both dirty reads and non-repeatable reads by taking a snapshot at the start of the transaction — reads within the transaction always see the same data, and PostgreSQL's MVCC implementation also prevents phantom reads at this level. SERIALIZABLE is the strictest level, preventing all anomalies including write skew (two transactions each reading overlapping data and making conflicting writes based on what they read) — it has the highest overhead due to locking or Serializable Snapshot Isolation validation.

---

**Q64: Clustered vs non-clustered index?**
**One-line answer:** Clustered: data rows physically ordered by index (one per table); non-clustered: separate structure with pointer to row.
**Full answer:** In MySQL InnoDB, the primary key is always the clustered index — the actual table data rows are physically stored in primary key order within the B-tree leaf pages, meaning a primary key lookup retrieves the row data immediately without a second lookup. Every secondary (non-clustered) index in InnoDB stores the primary key value in its leaf nodes — so a secondary index lookup first finds the primary key, then does a second traversal of the clustered index to fetch the actual row data (this "double lookup" is called a key lookup). In PostgreSQL, all tables use a heap structure where rows are stored in the order they were inserted, and all indexes are non-clustered — they store the physical row location (ctid) and the index lookup is always followed by a heap fetch. PostgreSQL's CLUSTER command can physically reorder a table's rows by a chosen index once, but this ordering is not maintained as new rows are inserted.

---

**Q65: How do you optimize a slow query?**
**One-line answer:** EXPLAIN ANALYZE; add indexes; avoid SELECT *; avoid functions on indexed columns; optimize JOINs.
**Full answer:** I start with EXPLAIN ANALYZE (PostgreSQL) or EXPLAIN (MySQL) to see the actual execution plan — I look for Seq Scan on large tables (signals a missing index), large discrepancies between estimated rows and actual rows (stale statistics — fix with ANALYZE or VACUUM ANALYZE), and Sort or Hash operations that could be eliminated with an appropriate index. The most common fixes are: adding an index on the columns used in WHERE clauses, JOIN conditions, and ORDER BY; rewriting predicates that prevent index use — for example, WHERE YEAR(created_at) = 2024 applies a function to the indexed column making the index unusable, while WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01' is sargable (index-friendly); replacing SELECT * with only the needed columns to enable covering index scans. For complex analytical queries, consider pre-computing results into materialized views that are refreshed on a schedule.

---

**Q66: What is database sharding?**
**One-line answer:** Horizontal partitioning across multiple DB instances; shard key routes data; enables horizontal scale.
**Full answer:** Sharding splits a large table across multiple independent database servers — each server (called a shard) holds a subset of the rows rather than all rows, so both storage capacity and query throughput scale with the number of shards. The shard key is a column (or combination of columns) used to determine which shard a row belongs to — for example, hashing user_id modulo 4 distributes users evenly across 4 shards. Unlike vertical partitioning (which splits different columns into different tables), sharding splits rows horizontally, enabling true scale-out. The significant challenges are: cross-shard queries require scatter-gather (query all shards and merge results in the application layer), cross-shard transactions lack ACID guarantees (require the Saga pattern or two-phase commit), and rebalancing when adding shards requires moving data. Choose a shard key with high cardinality, even distribution, and alignment with common query access patterns to avoid hot shards where one shard receives disproportionate traffic.

---

**Q67: Explain CAP theorem.**
**One-line answer:** Distributed systems can guarantee only 2 of C, A, P; partition tolerance is unavoidable so choose CP or AP.
**Full answer:** CAP theorem states that a distributed system can provide at most two of three properties: Consistency (every read returns the most recent write — all nodes see the same data at the same time), Availability (every request receives a non-error response, though it may be stale), and Partition Tolerance (the system continues operating when network partitions prevent some nodes from communicating with others). In any real distributed system network partitions are inevitable — hardware fails, network cables degrade, datacenters become temporarily unreachable — so Partition Tolerance is non-negotiable in practice. This forces the real choice between CP systems (sacrifice availability during partitions — return an error rather than serve potentially stale data; ZooKeeper, HBase, PostgreSQL with synchronous replication) and AP systems (sacrifice consistency during partitions — serve potentially stale data rather than returning an error; Cassandra, DynamoDB, CouchDB). PACELC extends CAP by observing that even without partition, systems face a latency versus consistency tradeoff.

---

**Q68: Hot shard / hotspot sharding problem?**
**One-line answer:** Uneven key distribution causes one shard to receive disproportionate load; avoid monotonic keys as shard key.
**Full answer:** A hot shard occurs when the chosen shard key causes most reads or writes to route disproportionately to one shard while others sit largely idle — for example, using created_at timestamp as the shard key means all new writes always go to the "current" time shard, while older shards receive only reads. Another cause is low-cardinality shard keys: using status with three possible values means at most three shards can be active regardless of how many you provision. Mitigations: hash sharding (hash(key) % N) distributes writes evenly across all shards but breaks range queries since adjacent keys end up on different shards. For social media platforms, using user_id distributes writes well overall, but celebrity users with millions of followers still create read hotspots — mitigate with a random suffix per celebrity post (fan-out on write) or caching at the application layer. Monitor shard-level CPU and latency — a consistent 10x difference between shards signals a hotspot.

---

**Q69: DELETE vs TRUNCATE vs DROP?**
**One-line answer:** DELETE: row-by-row, logged, WHERE supported, rollbackable; TRUNCATE: fast, no WHERE, DDL; DROP: removes table.
**Full answer:** DELETE is a DML (Data Manipulation Language) operation — it removes rows one at a time, writes each individual deletion to the transaction log (enabling rollback), fires row-level triggers, respects referential integrity constraints (ON DELETE CASCADE/RESTRICT), and supports a WHERE clause to filter which rows to remove. For tables with millions of rows, DELETE is slow because of per-row logging overhead. TRUNCATE is a DDL (Data Definition Language) operation — it deallocates the entire table's data pages in a single operation (no per-row logging), resets the table's auto-increment counter in most databases, and cannot have a WHERE clause. In PostgreSQL, TRUNCATE is transactional and can be rolled back within a transaction; in MySQL, TRUNCATE implicitly commits the current transaction before executing. DROP removes the table structure, all its data, all associated indexes, and all constraints permanently — referencing foreign keys in other tables must be dropped or the DROP will fail.

---

**Q70: What is a covering index?**
**One-line answer:** Index contains all columns the query needs; Index Only Scan — no heap table access required.
**Full answer:** A covering index contains all the columns that a specific query needs in its SELECT, WHERE, and ORDER BY clauses — when the query optimizer recognizes this, it performs an Index Only Scan, meaning it can answer the query entirely from the index structure without ever accessing the actual table rows. This eliminates the "double lookup" of a standard index scan (find the row location in the index, then fetch the row from the heap) and is dramatically faster for read-heavy queries on large tables. In PostgreSQL 11+, the INCLUDE clause lets you add non-key columns to index leaf pages without them participating in the B-tree structure itself: CREATE INDEX idx_orders_status ON orders(status) INCLUDE (amount, created_at) allows queries filtering on status that also need amount and created_at to be served entirely from the index. In MySQL InnoDB, secondary indexes implicitly include the primary key in their leaf nodes, so a query selecting only indexed columns plus the primary key is automatically covered.

---

**Q71: Explain window functions.**
**One-line answer:** Computations over a set of related rows without collapsing them; ROW_NUMBER(), RANK(), LAG(), SUM() OVER (PARTITION BY...).
**Full answer:** Window functions perform calculations over a "window" of rows that are related to the current row — unlike GROUP BY which collapses many rows into a single aggregate row, window functions add a computed column to every row while keeping all rows visible in the result set. The OVER() clause defines the window: PARTITION BY divides rows into groups (similar to GROUP BY but non-collapsing, so all original rows are preserved), ORDER BY specifies the ordering within each partition for sequential functions, and an optional frame clause (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) specifies which rows are included in the calculation. ROW_NUMBER() assigns a unique sequential integer to each row within its partition (always 1,2,3,4 — no ties). RANK() gives the same number to tied rows but skips the next number (1,1,3 — the gap represents the tied position). LAG(col, n) accesses the value n rows before the current row in the defined order, which is invaluable for period-over-period comparisons like calculating revenue growth versus the prior month.

---

**Q72: How does DynamoDB achieve eventual consistency?**
**One-line answer:** Writes go to 2 of 3 replicas synchronously; reads from any replica may be stale; strongly consistent reads optional.
**Full answer:** DynamoDB replicates each partition's data across three availability zones within a region. A write is considered successful and acknowledged to the client after it has been written to 2 of the 3 replicas (a quorum write) — this gives durability since two independent failures would be needed to lose the data. The third replica receives the update asynchronously, usually within milliseconds, but there is a window during which it holds stale data. An eventually consistent read (the default) can be served by any of the three replicas — including the one that hasn't received the latest update yet — offering lower latency and lower cost but potentially returning slightly stale data. A strongly consistent read (set ConsistentRead: true in the request) is always routed to the leader replica, guaranteeing you receive the most recently committed write, at the cost of higher latency, reduced availability during leader failover, and double the read capacity unit consumption.

---

**Q73: How does PostgreSQL MVCC work?**
**One-line answer:** Each row has xmin/xmax transaction IDs; readers see a snapshot; no read locks needed; old versions cleaned by VACUUM.
**Full answer:** MVCC (Multi-Version Concurrency Control) is the mechanism that allows readers and writers to never block each other in PostgreSQL. Every row has two hidden system columns: xmin (the transaction ID of the transaction that created this row version) and xmax (the transaction ID that deleted or superseded this row — set to 0 if the row is still live). When a transaction starts, PostgreSQL takes a snapshot recording which transaction IDs are committed, which are in progress, and which haven't started yet. A row version is visible to the current transaction only if its xmin is a committed transaction that was committed before the snapshot, and its xmax is either 0 or a transaction that was not committed at snapshot time — this means the transaction sees a perfectly consistent view of the database as of the moment it started, completely isolated from concurrent writes. The cost is that old row versions (created by updates and deletes) accumulate as "dead tuples" — the VACUUM process must periodically scan tables and remove them to reclaim disk space, and insufficient vacuuming leads to table bloat.

---

**Q74: When to use NoSQL vs SQL?**
**One-line answer:** NoSQL: schema flexibility, horizontal scale, simple access patterns; SQL: complex queries, ACID, relational data.
**Full answer:** I choose SQL (PostgreSQL, MySQL) when the data is inherently relational with well-defined foreign key relationships, when I need ACID transactions spanning multiple tables (financial records, inventory adjustments), when queries are complex and ad-hoc (multi-table JOINs, GROUP BY aggregations, window functions for reporting), or when strong consistency is a business requirement. I choose NoSQL when the schema is flexible or rapidly evolving (document stores like MongoDB handle variable fields without migrations), when writes need to scale horizontally across many nodes (Cassandra for time-series sensor data, DynamoDB for key-value lookups at massive scale), when access patterns are simple and predefined (always querying by user_id — no need for the full relational machinery), or when sub-millisecond read latency is required (Redis for caching and session storage). Many production systems use both — polyglot persistence: PostgreSQL for transactional data, Redis for caching and rate limiting, Elasticsearch for full-text search, Cassandra for high-volume event streams.

---

**Q75: What is a database deadlock and how do you prevent it?**
**One-line answer:** Two transactions hold locks each other needs; DB detects cycle and kills one; prevent with consistent lock order.
**Full answer:** A deadlock occurs when Transaction A holds a lock on Row 1 and is waiting for a lock on Row 2, while Transaction B holds a lock on Row 2 and is waiting for a lock on Row 1 — both transactions wait indefinitely for the other to release. Databases detect deadlocks by periodically scanning the wait-for graph (a directed graph of which transactions are blocked by which) for cycles, then resolve the deadlock by selecting one transaction as the victim and rolling it back with an error. Prevention strategies: always acquire locks in a consistent global order across all code paths — if every transaction that touches both accounts locks the lower account_id first, circular waits become structurally impossible; keep transactions as short as possible to minimize the window during which locks are held; use SELECT FOR UPDATE NOWAIT (fail immediately if the row is locked) or SELECT FOR UPDATE SKIP LOCKED (skip locked rows, useful for queue processing) to avoid waiting indefinitely. In Spring, annotate service methods with @Retryable(value = {DeadlockLoserDataAccessException.class}) to transparently retry the transaction on deadlock.

---

### System Design/LLD (Q76–Q90)

**Q76: How would you design a URL shortener?**
**One-line answer:** Redis INCR for globally unique counter → Base62 encode → store mapping → cache hot URLs in Redis.
**Full answer:** The core challenge is generating a short, unique code and mapping it back to the original URL at high read throughput. I'd use a global counter: Redis INCR atomically increments a counter, returning a unique integer ID that I then Base62-encode (using the 62 characters 0-9, a-z, A-Z) — a 6-character Base62 code covers ~56 billion unique URLs which is sufficient for most use cases. Store the canonical mapping (short_code → long_url, plus metadata like creator and creation time) in a relational database or DynamoDB for durability. For redirects, the read path is the critical performance path — cache the hottest URLs in Redis with LRU eviction so most redirects are served from memory without a database query. For the HTTP redirect response: use 302 (temporary redirect) if you want to track every redirect hit on your server for analytics; use 301 (permanent redirect) if you want to offload traffic to browser caching for maximum scalability. The atomic counter approach is preferable over random hashing because it guarantees uniqueness without needing a collision-check query.

---

**Q77: How does consistent hashing work?**
**One-line answer:** Ring hash space 0-2^32; nodes and keys on ring; key routes to first node clockwise; adding node moves minimal keys.
**Full answer:** Consistent hashing places both cache/storage nodes and data keys on a conceptual circular ring representing the hash space from 0 to 2^32. Each node's position on the ring is determined by hashing its identifier (its IP address or hostname) — so nodes are placed at deterministic but distributed positions. Each key is assigned to the first node found clockwise from the key's hashed position on the ring — that node is responsible for storing or serving that key. The key property is minimal disruption during scaling: when you add a new node, only the keys that fall between the new node and its immediate counter-clockwise neighbor on the ring need to be moved — this is approximately K/N keys (total keys divided by node count), far less than the near-total remapping that traditional modulo hashing (key % N → key % (N+1)) requires. Virtual nodes (placing each physical server at 100-200 positions on the ring by hashing server_name_1, server_name_2, etc.) prevent uneven distribution and make the load share of each physical server smoother.

---

**Q78: Load balancer vs reverse proxy?**
**One-line answer:** LB distributes traffic across servers; reverse proxy adds SSL, caching, auth in front of servers.
**Full answer:** A load balancer's primary purpose is traffic distribution — it routes incoming requests across a pool of backend servers using algorithms like round-robin, least-connections, or IP hash, monitors backend health, and stops routing to unhealthy instances to provide high availability. A reverse proxy sits in front of one or more backend servers and adds value-added processing on the path: SSL/TLS termination (so backends can speak plain HTTP internally), response caching (serving cached responses without hitting the backend), request compression, authentication and authorization header injection, and rate limiting. In practice, modern tools like NGINX, HAProxy, and Envoy perform both roles simultaneously — they distribute load across backends while also handling SSL, adding headers, caching, and integrating with WAF (Web Application Firewall). AWS ALB (Application Load Balancer) is both: it distributes traffic across target groups (load balancing) and terminates SSL, performs content-based routing, and integrates with AWS WAF and Cognito (reverse proxy features).

---

**Q79: How would you design a rate limiter?**
**One-line answer:** Token bucket per key in Redis; Lua script for atomic check-and-decrement; return 429 on limit exceeded.
**Full answer:** I use the token bucket algorithm: each API key or user gets a "bucket" with a maximum capacity of N tokens (e.g., 100) that refills at a rate of R tokens per second (e.g., 10 per second, allowing short bursts up to 100). Each request consumes one token; if the bucket is empty, reject the request with HTTP 429 Too Many Requests and include a Retry-After header indicating when tokens will be available. Store the bucket state in Redis as a hash with two fields per key: current_tokens and last_refill_timestamp. The check, refill, and decrement operation must be atomic — implement this as a Redis Lua script (Redis executes Lua scripts atomically, so no other client can interleave): compute tokens earned since last_refill_timestamp, add them to current_tokens capped at capacity, check if >= 1, if so decrement and return "allowed," else return "denied." Deploy rate limiting at the API Gateway layer for coarse-grained limits by API key or IP, and within individual services for fine-grained limits by user tier or endpoint.

---

**Q80: How does CDN cache invalidation work?**
**One-line answer:** TTL expiry, API-based purge, or cache-busting URLs (versioned asset names).
**Full answer:** A CDN (Content Delivery Network) caches your content at geographically distributed edge nodes — when a user in London requests an image, they receive it from a Frankfurt edge node rather than your origin server in Virginia, dramatically reducing latency. Cache invalidation strategies: TTL (Time-To-Live) — each cached object has a max-age directive (set in Cache-Control response headers) after which the edge node discards the cached copy and refetches from origin on the next request; this is simple but serves stale content for up to TTL seconds after you update it. API-based purge — CloudFront Invalidations, Cloudflare Cache-Purge API, or Fastly Instant Purge let you immediately evict specific URL patterns from all edge nodes; this gives instant freshness but incurs API costs and has rate limits. Cache-busting embeds a content hash in the URL itself (main.abc123.js) — the old versioned file remains cached at its old URL (it's still valid content), you simply never request it again, and the new file gets a fresh cache entry at its new URL; this is the most reliable and preferred strategy for static assets like CSS, JS, and images.

---

**Q81: How would you design a notification system?**
**One-line answer:** User → Notification service → Kafka per channel → workers → APNs/FCM/SendGrid/Twilio.
**Full answer:** A notification system must handle multiple delivery channels (push, email, SMS, in-app), guarantee at-least-once delivery, respect user preferences, and throttle notifications to avoid spamming users. Architecture: the calling microservice publishes a notification request to the Notification Service (via REST or an internal event), which applies user preference rules (channel choices, do-not-disturb hours, frequency caps) and publishes one message per applicable channel to separate Kafka topics (push-notifications-topic, email-topic, sms-topic). Channel-specific workers consume from their respective topics and call provider APIs: APNs/FCM for iOS/Android push notifications, SendGrid or SES for email, Twilio for SMS. Persist each notification attempt in a database with delivered/failed/pending status — retry failed deliveries with exponential backoff, routing permanently failed deliveries to a dead-letter queue for investigation. Use an idempotency key per notification to prevent duplicate delivery on retry. Rate limit per user per channel at the Notification Service layer before publishing to Kafka.

---

**Q82: Synchronous vs event-driven architecture?**
**One-line answer:** Sync: caller waits, tight coupling, immediate feedback; event-driven: async, loose coupling, eventual consistency.
**Full answer:** In synchronous architecture, Service A calls Service B's API via HTTP/gRPC and blocks until it receives a response — both services must be simultaneously available, a slow Service B directly increases Service A's response time, and Service B failures immediately propagate as errors to Service A's callers. This provides immediate consistency (the response confirms the downstream action completed) but creates both runtime and temporal coupling between services. Event-driven architecture uses a message broker (Kafka, RabbitMQ): Service A publishes an event to a topic and returns immediately to its caller; Service B consumes the event when it's ready, potentially milliseconds or hours later. Services are decoupled in time — Service B can be down for maintenance and will process queued events when it recovers, without Service A ever erroring. The trade-offs: eventual consistency (Service A doesn't immediately know whether Service B succeeded), causality tracing across services requires distributed tracing (correlation IDs in event headers), and failure handling requires a dead-letter queue strategy. Choose event-driven for workflows where immediate confirmation is not required (order placed → fulfillment, notification sending, audit logging).

---

**Q83: How would you design a distributed cache?**
**One-line answer:** Redis Cluster with hash-slot sharding; replication for HA; LRU eviction; circuit breaker for DB fallback.
**Full answer:** I use Redis Cluster, which automatically shards data across multiple master nodes using 16,384 hash slots — each key maps to a hash slot via CRC16(key) % 16384, and each master node owns a contiguous range of slots; the client library routes requests to the correct node directly without a proxy. Each master has one or more read replicas for high availability — if a master fails, the cluster automatically promotes a replica within seconds. Set maxmemory-policy to allkeys-lru so the cache evicts the least recently used entries when memory fills, rather than returning errors. On the application side, use the Cache-Aside pattern: check the cache first, and on a cache miss, fetch from the database, populate the cache with a TTL, then return the result. Wrap all cache calls in a circuit breaker (Resilience4j CircuitBreaker) — if Redis becomes unavailable, the circuit opens and all requests fall through to the database directly, preventing the Redis unavailability from cascading into a complete application failure. Always set a TTL on every cached key to prevent indefinite accumulation of stale data.

---

**Q84: Explain Snowflake ID generation.**
**One-line answer:** 64-bit: 1(sign) + 41(timestamp ms) + 10(machine ID) + 12(sequence); time-sortable; 4M IDs/sec/machine.
**Full answer:** Snowflake IDs are 64-bit integers (fitting in a BIGINT column) that can be generated in a distributed system without coordination between nodes. The bit layout is: 1 sign bit (always 0, keeping IDs positive), 41 bits for milliseconds since a custom epoch (~69 years of range before the epoch needs to change), 10 bits for machine or datacenter/worker ID (supporting up to 1,024 distinct generators), and 12 bits for a per-millisecond sequence counter (4,096 unique IDs per millisecond per machine). Maximum throughput is 4,096 IDs per millisecond per machine, which is approximately 4.1 million IDs per second — sufficient for extreme scale. The critical operational property is that IDs are monotonically increasing over time since the timestamp occupies the most significant bits — inserting Snowflake IDs into a B-tree clustered index causes sequential (non-random) page insertions with minimal fragmentation, unlike UUID v4 which causes random page splits. The main risk is clock drift: if the system clock goes backward, the generator must either wait until the clock catches up or detect the anomaly and pad the sequence bits.

---

**Q85: Database migrations in microservices?**
**One-line answer:** Flyway/Liquibase versioned migrations; backward-compatible changes; expand-contract for column renames.
**Full answer:** In a microservices deployment using rolling updates, the old version of a service and the new version run simultaneously during the deployment window — your database migration must therefore be compatible with both the old and new application code at the same time. Backward-incompatible changes like renaming a column or removing a column that the old code reads will cause the old instances to fail with SQL errors during the rollout. The Expand-Contract pattern solves this safely: Phase 1 (Expand) — add the new column alongside the old one and deploy code that writes to both columns and reads from the old; Phase 2 (Migrate) — run a background job to backfill any historical rows into the new column; Phase 3 (Contract) — once all instances are on the new version reading from the new column, deploy a separate migration to drop the old column. Flyway manages versioned SQL scripts (V1__add_user_email_index.sql, V2__add_audit_columns.sql) tracked in a flyway_schema_history table — Spring Boot auto-runs pending migrations on startup.

---

**Q86: Saga pattern — Choreography vs Orchestration?**
**One-line answer:** Choreography: event-driven, no central coordinator; Orchestration: central brain directs each step.
**Full answer:** The Saga pattern handles distributed transactions across multiple microservices by decomposing them into a sequence of local transactions, each with a corresponding compensating transaction that undoes its work if a later step fails. Choreography implements the flow through events: each service publishes an event after completing its local transaction, and other services listen for relevant events and react — Order Service publishes OrderCreated, Payment Service listens and publishes PaymentCompleted, Inventory Service listens and reserves stock. There is no central coordinator, making each service fully autonomous and independently deployable, but the overall flow is invisible (distributed across multiple services' event handlers) and debugging a failed saga requires correlating events across multiple logs. Orchestration uses a central Saga Orchestrator (implemented with Temporal, Axon Framework, or AWS Step Functions) that explicitly sends commands to each service and awaits replies — the full flow is defined in one place, failures are immediately visible to the orchestrator which triggers compensating transactions, and the flow is much easier to monitor and debug, at the cost of the orchestrator being coupled to all participating services.

---

**Q87: How would you design a search autocomplete?**
**One-line answer:** Trie for prefix lookup; Redis sorted set by frequency for top-K; precompute popular queries.
**Full answer:** The core data structure for autocomplete is a Trie (prefix tree) — a tree where each node represents a character and paths from root to leaf nodes spell out stored strings, enabling prefix lookups in O(prefix_length + result_count) time. For top-K results per prefix, each Trie node stores the top-K completions ranked by search frequency, so the lookup returns sorted results immediately without post-processing. In production, a single in-memory Trie holding millions of queries would be very large, so I'd use Redis Sorted Sets: the set key is the prefix (e.g., "sea"), members are candidate completions, and scores are query frequencies — fetching the top 10 completions for any prefix is a single ZREVRANGE command. Pre-compute the top-10 completions for every prefix that has received queries and store them in Redis, refreshed hourly using a batch job that processes query frequency counts from Kafka logs. The most popular prefixes can be pushed to the CDN edge — autocomplete suggestions change slowly and are extremely cacheable.

---

**Q88: What is blue-green deployment?**
**One-line answer:** Two identical environments; route traffic to green; instant rollback by switching back to blue.
**Full answer:** Blue-green deployment maintains two identical production environments: Blue is currently live and serving all production traffic, and Green has the new version deployed and fully health-checked but receiving no traffic yet. Once Green passes all validation (smoke tests, synthetic monitoring, canary health checks), the load balancer is reconfigured to route all traffic from Blue to Green in a single atomic switch — this gives zero-downtime deployments because there is no period where partially-deployed code serves traffic. If Green starts showing elevated error rates or latency after the switch, rollback is equally instant: switch the load balancer back to Blue. The main cost is infrastructure: you need double the compute capacity since both environments are fully provisioned simultaneously. After Green has been confirmed stable for your rollback window (typically 15-30 minutes), Blue can be decommissioned or held for the next deployment cycle. Compare to canary deployment (route 5% of traffic to new version first, monitor, then gradually increase) which reduces risk but takes longer and requires backward-compatible changes.

---

**Q89: How do you achieve idempotency in APIs?**
**One-line answer:** Client sends idempotency key (UUID) in header; server deduplicates using stored key-response mapping.
**Full answer:** Idempotency keys solve the double-execution problem that arises when a client retries a non-idempotent operation (like creating a payment) after a network timeout — without protection, a retry creates a duplicate charge. The client generates a UUID before making the request and sends it as an Idempotency-Key: <uuid> HTTP header. The server checks its idempotency store (a Redis hash with TTL, or a dedicated database table with a unique constraint on the key) for this key: if the key is found and the request is already completed, return the stored response without re-executing the business logic; if not found, execute the operation, store both the key and the response, then return the result. On any retry with the same idempotency key, the client receives the same response as the original execution — no duplicate charge, no duplicate order created. Set a TTL on idempotency keys (typically 24-48 hours) after which clients should query the resource status directly rather than retrying. Return HTTP 200 (not 201 Created) on a replayed response to signal "this is a cached response, not a new resource creation."

---

**Q90: Orchestration vs Choreography in microservices?**
**One-line answer:** Orchestration: central brain directs all steps; Choreography: each service reacts to events independently.
**Full answer:** Orchestration uses a central Saga Orchestrator (or workflow engine like Temporal or AWS Step Functions) that explicitly knows every step of the business workflow — it sends a command to Service A, waits for a success or failure reply, then conditionally sends the next command, handles timeouts, and triggers compensating transactions on failure. The entire business flow is visible in one place, making it easy to monitor progress, detect stuck workflows, and reason about failure modes — but the orchestrator is coupled to every participating service and becomes a potential bottleneck. Choreography distributes the workflow logic across services — each service listens for specific events it cares about and publishes events in response, with no individual service knowing the "big picture" of the overall workflow. This creates maximum decoupling (each service can be deployed, scaled, and modified independently) but debugging a failed workflow requires correlating events across multiple services' logs using correlation IDs and distributed tracing. Choose orchestration when the workflow is complex, requires compensation, or needs visibility and auditability; choose choreography when maximum service autonomy and loose coupling are the priority.

---

### Behavioral/Architecture (Q91–Q100)

**Q91: Tell me about a time you improved system performance.**
**One-line answer:** STAR format: situation → bottleneck identified via profiling → solution → measurable improvement.
**Full answer:** I structure my answer using the STAR format: Situation (what system, what observable problem — for example, "our order search API had a p99 latency of 2 seconds during peak hours, causing timeout errors for 3% of users"), Task (my specific role — "I owned the investigation and fix as the backend lead"), Action (the systematic debugging process — I ran EXPLAIN ANALYZE on the slow queries and found a missing composite index on status and created_at; I also identified an N+1 query pattern in the order enrichment step that was making one database query per order item in a list response), Result (the measurable outcome — "after adding the index and batch-loading order items, p99 dropped from 2 seconds to 150ms and the error rate fell to zero"). The key detail interviewers want to see is "profiling before optimizing" — I identified the actual bottleneck using measurement rather than guessing, and the fix was targeted and specific. If you don't have a perfect story, describe one where you made a meaningful contribution, even if the improvement was modest.

---

**Q92: How do you approach debugging a production issue?**
**One-line answer:** Observe (logs/metrics/traces) → Hypothesize → Isolate → Fix → Verify → Post-mortem.
**Full answer:** I start with observability — open the dashboards to see which metrics changed and when: latency percentiles, error rate by endpoint, saturation (CPU, memory, database connection pool utilization), and check if any recent deployments correlate with the degradation onset. I check application logs for error patterns, stack traces, or unusual log volumes, and use distributed traces (Jaeger, Zipkin, AWS X-Ray) to find which service or which specific operation within a service is slow or failing. With those signals I form a hypothesis ("cache eviction spike caused a cache stampede which is overloading the database") and try to isolate it by comparing metrics before and after the incident onset, checking for correlated events (deployments, traffic spikes, external service degradations). I fix the root cause rather than the symptom — restarting a service with a memory leak buys 2 hours, not a permanent fix. After the incident is resolved, I write a blameless post-mortem documenting what happened, contributing factors, the timeline, and concrete action items to prevent recurrence — the goal is systemic improvement, not assigning blame.

---

**Q93: How do you decide between building vs buying a solution?**
**One-line answer:** Build: core differentiator, specific needs; Buy: commodity, faster time-to-market, lower long-term TCO.
**Full answer:** I build when the capability is a core competitive differentiator — our proprietary recommendation algorithm, our fraud detection model, our pricing engine — where the implementation itself is a source of competitive advantage and commercial solutions wouldn't capture the specific domain nuance we need. I also build when commercial solutions have non-negotiable gaps in latency, compliance (data residency requirements), or integration. I buy or use open source for commodity problems that many companies have already solved well: authentication and SSO (Keycloak, Auth0), observability stacks (Datadog, Grafana + Prometheus), message queuing (Kafka, RabbitMQ), search (Elasticsearch), API gateways (Kong, AWS API Gateway). When evaluating the build option, I calculate the full total cost of ownership: engineer development time (often underestimated by 3x), ongoing maintenance, security patching, documentation, and the oncall burden for keeping it running — commercial solutions have licensing costs that are frequently far less than the equivalent engineering investment over 3 years.

---

**Q94: How do you handle disagreements in technical decisions?**
**One-line answer:** Present data and trade-offs; understand their perspective; seek alignment; commit to team decision.
**Full answer:** I start from the assumption that the person disagreeing has information or context I don't have — I ask questions to genuinely understand their reasoning before presenting my counterargument, because sometimes I'm the one who's wrong. When I do present my position, I frame it around specific trade-offs and concrete data rather than personal preferences: "I'm concerned that approach X will cause Y problem in scenario Z — here's data from our production metrics that supports this concern." If the disagreement persists after exchanging perspectives, a time-boxed proof-of-concept (a spike of 1-2 days) often replaces speculation with evidence. Some disagreements are about values or priorities (build vs buy, consistency vs latency, short-term velocity vs long-term maintainability) where neither side is objectively correct — in those cases, I work with the team to surface the underlying priorities and make an explicit decision together. Once a decision is made by the team, I commit fully and execute without passive resistance — I may note my concerns in writing as a record, but I then work wholeheartedly toward the agreed approach.

---

**Q95: Describe your approach to code review.**
**One-line answer:** Check correctness, edge cases, performance, security, readability, tests; be constructive, not prescriptive.
**Full answer:** I review in roughly this order: correctness first — does the code actually do what the PR description claims? Are there uncovered edge cases (null or empty inputs, integer overflow, concurrent access to shared state, partial failure scenarios)? Then performance — are there obvious inefficiencies like N+1 database queries, missing indexes on newly queried columns, unbounded collection growth, or blocking calls on non-blocking threads? Then security — SQL injection risk, unsanitized user input rendered as HTML, hardcoded credentials, overly broad permissions, or missing authentication checks on new endpoints? Then readability — would a new team member understand this code 6 months from now without asking me? Are variable and method names self-describing? Are there comments where the "why" is non-obvious from the "what"? Finally, test coverage — do the tests verify actual behavior or just exercise the code without meaningful assertions? For tone: I prefer asking over demanding ("have you considered X for this case?"), I explain my reasoning so the author learns rather than just changes the code, and I explicitly acknowledge good solutions — code review isn't only a bug-finding exercise.

---

**Q96: How do you ensure high availability in your systems?**
**One-line answer:** Redundancy (no SPOF), health checks, circuit breakers, graceful degradation, chaos engineering, runbooks.
**Full answer:** High availability requires eliminating single points of failure at every layer: multiple application instances behind a load balancer (web tier), read replicas and automated failover for the database tier (RDS Multi-AZ, PostgreSQL Patroni), multi-AZ deployment for all infrastructure components, and redundant Kafka brokers and ZooKeeper nodes. Health checks (Kubernetes liveness probes to restart deadlocked instances, readiness probes to stop routing traffic during startup or heavy load) ensure requests only reach healthy pods. Circuit breakers (Resilience4j) prevent a slow or failing downstream dependency from exhausting all threads in the calling service — they fail fast once the error threshold is crossed and let the system recover. Graceful degradation means defining what the service returns when a dependency is down: serve cached data, show a "feature temporarily unavailable" message, or disable a non-critical widget rather than returning a 500 error that breaks the entire page. Validate that redundancy actually works with chaos engineering (terminate random pods in staging, inject latency into dependencies) rather than assuming it works.

---

**Q97: What is technical debt and how do you manage it?**
**One-line answer:** Shortcuts taken for speed that cost more later; manage with a debt register, sprint allocation, and metrics.
**Full answer:** Technical debt is the accumulated cost of past decisions that prioritized short-term speed over long-term quality — a service with no tests, a database schema that made sense three years ago but now requires complex workarounds, or a module so tangled that every change requires touching ten files. Like financial debt, it accrues interest in the form of slower feature development (engineers spend more time understanding and navigating the legacy code), more production bugs (poorly tested code hides defects), higher oncall burden (fragile systems page more), and slower onboarding of new engineers. I manage it proactively: maintain a technical debt register (items documented with business impact — "this costs us approximately X engineer-hours per sprint in bug fixes — and estimated remediation effort"), allocate a fixed fraction of every sprint to debt reduction (many teams use 20%), and track debt indicators as engineering metrics (unit test coverage percentage, mean time to build, mean time for a new engineer to ship their first feature). When discussing debt with non-technical stakeholders, I always frame it in terms of feature velocity impact rather than internal quality concerns, since that's what resonates in business planning.

---

**Q98: How do you design for failure?**
**One-line answer:** Assume everything will fail; retry with backoff; circuit breakers; fallbacks; bulkheads; chaos testing.
**Full answer:** I design starting from the assumption that every component will eventually fail — hardware dies, networks partition, third-party APIs go down — and my job is to define exactly how the system behaves when each dependency fails, rather than assuming they'll always be up. For transient failures (network blips, brief overloads), I use retries with exponential backoff and random jitter — the jitter is critical to prevent synchronized retry storms where thousands of clients all retry at the exact same moment and amplify the overload. For systemic downstream failures, I use circuit breakers (Resilience4j) to fail fast: after a configurable error threshold, the circuit opens and subsequent calls immediately return a fallback response without waiting for a timeout, allowing the downstream service to recover without being bombarded. Every external dependency must have a defined fallback behavior — "if the recommendation service is down, return the top-20 globally popular items." Bulkheads (separate thread pools per dependency) prevent one slow dependency from exhausting all threads and bringing down unrelated functionality. Validate all of this with controlled chaos engineering exercises — inject failures deliberately in staging and confirm the fallback paths actually trigger.

---

**Q99: What metrics do you monitor for a backend service?**
**One-line answer:** Latency (p50/p95/p99), error rate, throughput (req/s), saturation (CPU/memory/connections), dependency health.
**Full answer:** I use Google SRE's Four Golden Signals as the foundation: Latency (how long requests take — I always track p50 for typical user experience, p95 to understand most users, and p99 to catch the long tail; and I track these separately for successful and failed responses since a spike in errors can mask a latency regression), Traffic (requests per second — the overall demand and a baseline for correlating other signals), Errors (the rate of failed requests — I separate 5xx server errors from 4xx client errors since they indicate very different problems), and Saturation (how full the system is — CPU utilization, memory usage, JVM heap pressure, database connection pool wait times, and disk I/O on write-heavy services). Beyond the golden signals I monitor: dependency health (downstream API latency and error rate broken out by dependency, cache hit rate for Redis, Kafka consumer group lag for async workers), JVM-specific metrics (GC pause frequency and duration, heap old-gen usage before GC), and business-level metrics (order creation rate, payment success rate) which catch bugs that infrastructure metrics miss entirely. I set SLOs (Service Level Objectives) on p99 latency and error rate and configure PagerDuty alerts when the error budget burn rate is too high.

---

**Q100: How do you stay current with technology?**
**One-line answer:** Engineering blogs, open source contributions, side projects, conferences, peer learning.
**Full answer:** I follow engineering blogs from companies operating at large scale — Netflix Tech Blog, Uber Engineering, Airbnb Engineering, AWS Architecture Blog, and the Google Cloud blog — because they describe real architectural decisions, actual failure post-mortems, and hard-won lessons that no tutorial covers. I scan Hacker News and relevant technical subreddits daily, but I filter aggressively: I focus on "why is this better than the existing solution?" discussions rather than "look at this new tool" announcements, since most new tools solve the same problems slightly differently. I learn most deeply by building — side projects using unfamiliar technology force me to encounter the rough edges and operational concerns that documentation glosses over. Contributing to open source exposes me to production-grade code patterns, thorough code review from experienced maintainers, and real-world usage concerns from the issue tracker. Within my team, I run occasional tech talks (sharing something I learned), participate in engineering book clubs (currently working through "Designing Data-Intensive Applications"), and try to do pair programming sessions specifically to learn from colleagues with complementary expertise. The meta-principle: I invest in deep understanding of a small number of foundational concepts (distributed systems, concurrency, database internals, networking) rather than accumulating shallow familiarity with many frameworks — the foundations transfer to evaluating any new technology.

