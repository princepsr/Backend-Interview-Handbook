# Volume 1: Core Java
# Chapter 1: Object-Oriented Programming (OOP) in Java

---

## Table of Contents

1. Classes and Objects
2. Encapsulation
3. Inheritance
4. Polymorphism — Compile-time vs Runtime
5. Abstraction — Abstract Classes vs Interfaces
6. Association, Aggregation, Composition
7. Method Overloading vs Overriding
8. Constructor Chaining and `super`
9. `static` keyword — Fields, Methods, Blocks, Nested Classes
10. `final` keyword — Variables, Methods, Classes
11. `this` vs `super`
12. Object class methods — `equals()`, `hashCode()`, `toString()`, `clone()`
13. Covariant Return Types
14. Marker Interfaces

---

## 1. Classes and Objects

**Difficulty:** Easy
**Interview Frequency:** Very High
**Asked at:** Amazon, TCS, Infosys, Accenture, Goldman Sachs (screening rounds)

### Short Interview Answer (30–60 seconds)
A **class** is a blueprint that defines state (fields) and behavior (methods). An **object** is a runtime instance of that class, allocated on the heap. In Java, every object is created via `new`, which triggers memory allocation and constructor execution.

### Deep Explanation

When you write `Employee e = new Employee("Alice", 90000)`:

1. The JVM allocates memory on the **heap** for the `Employee` object.
2. All instance fields are initialized to default values (0, null, false).
3. The constructor runs, setting fields to the provided values.
4. A reference to the heap object is stored in the local variable `e` on the **stack**.

The reference `e` is not the object — it is a pointer to the object. This distinction matters in pass-by-value discussions.

### Java Code Example

```java
public class Employee {
    private String name;
    private double salary;

    public Employee(String name, double salary) {
        this.name = name;
        this.salary = salary;
    }

    public String getName() { return name; }
    public double getSalary() { return salary; }
}

// Usage
Employee e1 = new Employee("Alice", 90000);
Employee e2 = e1;          // e2 points to the same heap object
e2.salary = 95000;         // changes are visible via e1 as well
```

### Follow-up Questions
- Is Java pass-by-value or pass-by-reference? *(Always pass-by-value; for objects, the value is the reference.)*
- Where are objects stored vs references?
- What happens to the object when no reference points to it?

### Common Mistakes
- Confusing the reference with the object itself.
- Assuming assigning `e2 = e1` creates a copy of the object.

### Quick Revision
> Class = blueprint. Object = heap instance. Reference = stack pointer to heap. Java is always pass-by-value.

---

## 2. Encapsulation

**Difficulty:** Easy
**Interview Frequency:** Very High
**Asked at:** All companies — commonly asked in screening rounds

### Short Interview Answer
Encapsulation is the practice of restricting direct access to an object's internal state by making fields `private` and exposing controlled access through `public` getter/setter methods. It protects invariants and decouples the internal representation from the external interface.

### Deep Explanation

Encapsulation is not just about getters and setters — it is about **protecting invariants**. Consider a `BankAccount` class: the balance should never go negative. If the field is public, any caller can set `account.balance = -10000`. Making it private and routing all mutations through a `withdraw()` method allows you to enforce the rule in one place.

**Benefits in production systems:**
- You can change the internal representation without breaking callers (e.g., storing balance in cents instead of dollars).
- Thread safety can be added in one place.
- Logging, auditing, and validation live in the setter/method, not scattered across callers.

### Java Code Example

```java
public class BankAccount {
    private double balance;  // cannot be accessed directly

    public BankAccount(double initialBalance) {
        if (initialBalance < 0) throw new IllegalArgumentException("Negative balance");
        this.balance = initialBalance;
    }

    public double getBalance() {
        return balance;
    }

    public void withdraw(double amount) {
        if (amount > balance) throw new IllegalStateException("Insufficient funds");
        this.balance -= amount;
    }

    public void deposit(double amount) {
        if (amount <= 0) throw new IllegalArgumentException("Invalid deposit amount");
        this.balance += amount;
    }
}
```

### Follow-up Questions
- What is the difference between encapsulation and data hiding?
- Can encapsulation be broken? *(Yes — via reflection.)*
- How does encapsulation relate to immutability?

### Common Mistakes
- Adding getters and setters for every field without thinking — this is "anemic encapsulation" and provides no protection.
- Returning mutable objects from getters (e.g., returning a `List` field directly — callers can modify it).

### Interview Trap
> "I make all fields private and add getters/setters — that's encapsulation."

This is incomplete. The interviewer expects you to mention invariant protection and controlled mutation, not just access modifiers.

### Quick Revision
> Encapsulation = private fields + public controlled access. True goal is invariant protection, not just hiding fields.

---

## 3. Inheritance

**Difficulty:** Medium
**Interview Frequency:** Very High
**Asked at:** Amazon, Microsoft, Flipkart, Accenture, Cognizant, Goldman Sachs

### Short Interview Answer
Inheritance allows a subclass to acquire the fields and methods of a superclass, enabling code reuse and establishing an IS-A relationship. Java supports single inheritance for classes and multiple inheritance through interfaces.

### Deep Explanation

**What gets inherited:**
- All `public` and `protected` members of the superclass.
- Package-private members if subclass is in the same package.
- `private` members are NOT inherited (though they exist in the object's memory).

**What does NOT get inherited:**
- Constructors (but the subclass constructor implicitly calls `super()` unless overridden).
- `static` members are not polymorphic — they belong to the class, not the instance.

**Why Java does not support multiple class inheritance:**
The **Diamond Problem** — if class `C` extends both `A` and `B`, and both define `display()`, the compiler cannot determine which version to use. Java resolves this by allowing multiple interface inheritance (since Java 8 default methods introduced a controlled form of this, resolved via explicit override).

**Inheritance vs Composition:**
Favor composition over inheritance (Effective Java, Item 18). Inheritance creates tight coupling — a change in the superclass can break all subclasses. Composition ("HAS-A") provides flexibility.

### Java Code Example

```java
public class Vehicle {
    protected String brand;
    protected int speed;

    public Vehicle(String brand, int speed) {
        this.brand = brand;
        this.speed = speed;
    }

    public void accelerate() {
        System.out.println(brand + " accelerating");
    }
}

public class ElectricCar extends Vehicle {
    private int batteryLevel;

    public ElectricCar(String brand, int speed, int batteryLevel) {
        super(brand, speed);   // must be first statement
        this.batteryLevel = batteryLevel;
    }

    @Override
    public void accelerate() {
        System.out.println(brand + " accelerating silently, battery: " + batteryLevel + "%");
    }
}
```

### Follow-up Questions
- Why does Java not support multiple inheritance of classes?
- What is the Diamond Problem?
- When would you prefer composition over inheritance?
- Can a constructor be inherited? *(No.)*
- What happens if the superclass has no default constructor?

### Common Mistakes
- Forgetting to call `super(...)` when the parent has no no-arg constructor — causes compilation error.
- Overusing inheritance for code reuse when composition is more appropriate.

### Interview Trap
> "Inheritance always improves reuse."

The trap: inheritance can cause **fragile base class** problems. If the superclass changes its behavior, all subclasses are affected, often in unexpected ways.

### Quick Revision
> Java: single class inheritance, multiple interface inheritance. Constructors not inherited. Prefer composition for flexibility.

---

## 4. Polymorphism — Compile-time vs Runtime

**Difficulty:** Medium
**Interview Frequency:** Very High
**Asked at:** Amazon, Google, Adobe, Razorpay, Goldman Sachs, Infosys

### Short Interview Answer
Polymorphism means "one interface, many implementations." Java has two forms: **compile-time polymorphism** (method overloading — resolved by the compiler based on method signature) and **runtime polymorphism** (method overriding — resolved at runtime via dynamic dispatch through the vtable).

### Deep Explanation

**Compile-time (Static) Polymorphism — Overloading:**
- Resolved during compilation.
- Differentiated by number, type, and order of parameters.
- Return type alone is NOT sufficient to distinguish overloaded methods.
- `@Override` annotation does NOT apply here.

**Runtime (Dynamic) Polymorphism — Overriding:**
- Resolved at runtime using the actual object type, not the reference type.
- JVM uses the **virtual method table (vtable)** — a per-class lookup table of method pointers.
- Only instance methods participate in runtime polymorphism. `static` and `private` methods do not.

**Internal mechanism — vtable:**
When the JVM encounters `animal.sound()` where `animal` is declared as `Animal` but points to a `Dog`, it looks up the vtable of the actual object type (`Dog`) to find the correct `sound()` method. This dispatch happens at runtime, not compile time.

### Java Code Example

```java
// Runtime polymorphism
public abstract class Animal {
    public abstract String sound();

    public void describe() {
        System.out.println("I am a " + getClass().getSimpleName() + " and I say: " + sound());
    }
}

public class Dog extends Animal {
    @Override
    public String sound() { return "Woof"; }
}

public class Cat extends Animal {
    @Override
    public String sound() { return "Meow"; }
}

// Usage
Animal a = new Dog();   // reference type: Animal, actual type: Dog
a.sound();              // calls Dog.sound() at runtime — "Woof"

// Compile-time polymorphism
public class Calculator {
    public int add(int a, int b) { return a + b; }
    public double add(double a, double b) { return a + b; }          // overload
    public int add(int a, int b, int c) { return a + b + c; }        // overload
}
```

### Real-World Backend Example
In a payment processing system, you have a `PaymentProcessor` interface implemented by `StripeProcessor`, `PaypalProcessor`, and `RazorpayProcessor`. The service layer holds a `PaymentProcessor` reference — at runtime, the correct implementation is dispatched based on the actual object injected by the Spring container. This is runtime polymorphism in production.

### Follow-up Questions
- Can `static` methods be overridden? *(No — they are hidden, not overridden.)*
- Can `private` methods be overridden? *(No — they are not visible to subclasses.)*
- What is method hiding?
- What is the role of the vtable in method dispatch?
- Can constructors be polymorphic?

### Common Mistakes
- Thinking `static` method overriding exists — it is actually **method hiding**.
- Confusing overloading with overriding.

### Interview Trap
```java
Animal a = new Dog();
// Calling a static method:
a.staticMethod(); // This calls Animal.staticMethod(), NOT Dog.staticMethod()
```
Static methods are resolved based on the **reference type**, not the actual object type.

### Quick Revision
> Overloading = compile-time, same class, different params. Overriding = runtime, subclass, same signature. static/private methods NOT overridden.

---

## 5. Abstraction — Abstract Classes vs Interfaces

**Difficulty:** Medium
**Interview Frequency:** Very High
**Asked at:** Amazon, Microsoft, Adobe, Salesforce, Goldman Sachs, Wipro

### Short Interview Answer
Abstraction hides implementation details and exposes only what is necessary. Java provides two mechanisms: **abstract classes** (partial abstraction, can have state and concrete methods) and **interfaces** (full contract definition, supports multiple inheritance). Since Java 8, interfaces can have `default` and `static` methods.

### Deep Explanation

| Feature | Abstract Class | Interface |
|---|---|---|
| Instantiation | Cannot be instantiated | Cannot be instantiated |
| Methods | Abstract + concrete | Abstract + default + static (Java 8+) |
| Fields | Instance fields allowed | Only `public static final` constants |
| Constructors | Can have constructors | No constructors |
| Access modifiers | Any | Methods are `public` by default |
| Inheritance | Single | Multiple |
| State | Can maintain state | No instance state |
| Use case | IS-A with shared behavior | CAN-DO contract |

**When to use abstract class:**
- When subclasses share significant common implementation.
- When you need to maintain state common to all subclasses.
- Template Method Pattern relies on abstract classes.

**When to use interface:**
- To define a capability contract (`Serializable`, `Comparable`, `Runnable`).
- When unrelated classes need to share a contract.
- When you need multiple inheritance of type.

**Java 8 default methods — why they were added:**
Before Java 8, adding a new method to an interface broke all implementing classes. Default methods allow backward-compatible interface evolution. This is why `Collection.stream()` was added without breaking existing code.

### Java Code Example

```java
// Abstract class — template method pattern
public abstract class ReportGenerator {
    // Template method — defines the algorithm skeleton
    public final void generateReport() {
        fetchData();
        processData();
        formatOutput();
        deliver();
    }

    protected abstract void fetchData();
    protected abstract void processData();

    protected void formatOutput() {
        System.out.println("Default PDF formatting");
    }

    private void deliver() {
        System.out.println("Delivering report");
    }
}

// Interface — capability contract
public interface Auditable {
    void logAction(String action);

    default void logWithTimestamp(String action) {
        System.out.println(System.currentTimeMillis() + ": " + action);
        logAction(action);
    }
}

public class InvoiceReportGenerator extends ReportGenerator implements Auditable {
    @Override
    protected void fetchData() { /* fetch from DB */ }

    @Override
    protected void processData() { /* process invoices */ }

    @Override
    public void logAction(String action) { /* write to audit log */ }
}
```

### Follow-up Questions
- Can an interface extend another interface? *(Yes, and multiple interfaces.)*
- Can an abstract class implement an interface without implementing all methods? *(Yes — it defers implementation to concrete subclasses.)*
- What are sealed classes (Java 17)? How do they relate to abstraction?
- What is the difference between `default` method in interface and concrete method in abstract class?
- What happens when two interfaces provide conflicting `default` methods?

### Interview Trap
> "Interfaces are always better because they support multiple inheritance."

The trap: interfaces cannot hold state. If you need shared mutable state across implementations, abstract classes are the right tool. Also, `default` method conflicts require explicit resolution in the implementing class.

### Quick Revision
> Abstract class = IS-A + shared state/behavior. Interface = CAN-DO contract + multiple inheritance. Java 8 default methods allow backward-compatible evolution.

---

## 6. Association, Aggregation, Composition

**Difficulty:** Medium
**Interview Frequency:** High
**Asked at:** Amazon, Adobe, Salesforce, Goldman Sachs (senior rounds), Capgemini

### Short Interview Answer
These describe relationships between objects. **Association** is a general "uses-a" relationship. **Aggregation** is a weak "HAS-A" — the child can exist independently. **Composition** is a strong "HAS-A" — the child cannot exist without the parent (ownership with same lifecycle).

### Deep Explanation

| Relationship | Type | Lifecycle | Example |
|---|---|---|---|
| Association | Uses-A | Independent | Teacher uses Classroom |
| Aggregation | Weak HAS-A | Child independent | Department HAS Employees |
| Composition | Strong HAS-A | Child depends on parent | House HAS Rooms |

**Composition in production:** A `PaymentOrder` contains `LineItems`. When the order is deleted, all line items are deleted. Line items have no existence outside an order — this is composition.

**Aggregation in production:** A `Project` has `Employees`. Employees exist independently and can be reassigned to other projects. Deleting the project does not delete the employees — this is aggregation.

### Java Code Example

```java
// Composition — Room cannot exist without House
public class House {
    private final List<Room> rooms;   // House creates and owns Rooms

    public House(int numberOfRooms) {
        rooms = new ArrayList<>();
        for (int i = 0; i < numberOfRooms; i++) {
            rooms.add(new Room("Room-" + (i + 1)));
        }
    }
}

// Aggregation — Employee exists independently
public class Department {
    private String name;
    private List<Employee> employees;  // Department references existing Employees

    public Department(String name) {
        this.name = name;
        this.employees = new ArrayList<>();
    }

    public void addEmployee(Employee e) {
        employees.add(e);
    }
}
```

### Follow-up Questions
- How do you model these relationships in a relational database?
- In JPA, which cascade types represent composition vs aggregation?
- How does garbage collection behave differently for aggregation vs composition?

### Quick Revision
> Composition = child created and owned by parent (same lifecycle). Aggregation = child exists independently. Association = loosest — just uses the other object.

---

## 7. Method Overloading vs Overriding

**Difficulty:** Easy–Medium
**Interview Frequency:** Very High
**Asked at:** Almost every company in first or second round

### Comparison Table

| Aspect | Overloading | Overriding |
|---|---|---|
| Location | Same class | Subclass |
| Signature | Different | Same |
| Return type | Can differ | Must be same or covariant |
| Access modifier | Can be anything | Cannot reduce visibility |
| Exceptions | Can throw any | Cannot throw new/broader checked exceptions |
| Binding | Compile-time (static) | Runtime (dynamic) |
| `static` methods | Yes | No (hidden, not overridden) |
| `private` methods | Yes | No |
| `final` methods | Yes | No |

### Interview Trap
```java
public class Parent {
    public Number getValue() { return 42; }
}

public class Child extends Parent {
    @Override
    public Integer getValue() { return 42; }  // Valid — covariant return type
}
```
Covariant return types are allowed in overriding (Java 5+). `Integer` IS-A `Number`, so this compiles.

### Follow-up Questions
1. Can you override a static method in Java?
2. What happens if you change only the return type in an overriding method?
3. What is covariant return type and when is it useful?

### Quick Revision
> Overloading = same class, different params, compile-time. Overriding = subclass, same signature, runtime. Covariant return types allowed.

---

## 8. Constructor Chaining and `super`

**Difficulty:** Medium
**Interview Frequency:** High
**Asked at:** Amazon, Microsoft, TCS, Infosys

### Short Interview Answer
Constructor chaining allows one constructor to call another. `this(...)` calls a constructor in the same class. `super(...)` calls the parent class constructor. Both must be the **first statement** in the constructor body, so they cannot both appear in the same constructor.

### Deep Explanation

**Rule:** If the first line of a constructor is not `this(...)` or `super(...)`, the compiler inserts an implicit `super()` call. If the parent class has no no-arg constructor, this causes a **compile error**.

**Execution order:**
1. `super()` chain executes top-down (grandparent → parent → child).
2. Instance initializer blocks execute in the order they appear.
3. Constructor body executes.

### Java Code Example

```java
public class Vehicle {
    protected String brand;
    protected int year;

    public Vehicle(String brand) {
        this(brand, 2024);  // chains to Vehicle(String, int)
    }

    public Vehicle(String brand, int year) {
        this.brand = brand;
        this.year = year;
    }
}

public class Car extends Vehicle {
    private int doors;

    public Car(String brand) {
        this(brand, 4);  // chains to Car(String, int)
    }

    public Car(String brand, int doors) {
        super(brand);    // calls Vehicle(String)
        this.doors = doors;
    }
}
```

### Follow-up Questions
- What happens if you have a circular constructor chain?  *(Compile error.)*
- Can you call `super()` and `this()` in the same constructor? *(No — only one can be the first statement.)*

### Quick Revision
> `this(...)` = same class constructor. `super(...)` = parent constructor. Both must be first line. Compiler inserts implicit `super()` if absent.

---

## 9. `static` Keyword

**Difficulty:** Medium
**Interview Frequency:** Very High
**Asked at:** Amazon, Google, Adobe, Goldman Sachs, Accenture

### Short Interview Answer
`static` means the member belongs to the **class**, not to any instance. Static members are loaded when the class is loaded and shared across all instances. They cannot access instance members directly because no `this` reference exists in a static context.

### Deep Explanation

**Static fields:** Single copy per class, shared across all instances. Useful for constants (`static final`) and counters.

**Static methods:** Cannot use `this` or `super`. Cannot call instance methods directly. Overriding does not apply — static methods are hidden, not overridden.

**Static blocks:** Executed once when the class is loaded by the ClassLoader, before any constructor runs. Used for complex static initialization.

**Static nested classes:** Belongs to the outer class at the type level, not to any instance. Can be instantiated without an outer class instance. Unlike inner classes, does not hold a reference to the outer class.

**Static import (Java 5+):** Allows using static members without class qualification. Commonly used with `Math.*` or `Assert.*` in tests.

### Java Code Example

```java
public class DatabaseConnectionPool {
    private static final int MAX_POOL_SIZE = 10;
    private static int activeConnections = 0;
    private static final DatabaseConnectionPool INSTANCE;

    // Static block — runs once on class load
    static {
        System.out.println("Initializing connection pool");
        INSTANCE = new DatabaseConnectionPool();
    }

    private DatabaseConnectionPool() {}

    public static DatabaseConnectionPool getInstance() {
        return INSTANCE;
    }

    public static int getActiveConnections() {
        return activeConnections;
    }

    // Static nested class
    public static class ConnectionStats {
        public static String summary() {
            return "Active: " + activeConnections + "/" + MAX_POOL_SIZE;
        }
    }
}
```

### Follow-up Questions
- Can a `static` method be `synchronized`? *(Yes — it locks on the Class object, not an instance.)*
- Can static methods be overridden? *(No — method hiding occurs.)*
- Can static blocks throw exceptions? *(Yes, but only unchecked, or checked wrapped in ExceptionInInitializerError.)*
- When is the static block executed?

### Common Mistakes
- Accessing static fields through object references — compiles but misleads readers.
- Assuming static synchronized methods lock the same monitor as instance synchronized methods — they do not.

### Quick Revision
> static = belongs to class. Static block runs once on class load. Static methods: no `this`, no override. Static nested class: no outer instance reference.

---

## 10. `final` Keyword

**Difficulty:** Easy–Medium
**Interview Frequency:** High
**Asked at:** Amazon, Adobe, Goldman Sachs, TCS

### Short Interview Answer
`final` prevents modification. A `final` variable cannot be reassigned, a `final` method cannot be overridden, and a `final` class cannot be subclassed.

### Deep Explanation

**`final` variable:**
- Primitive: value cannot change after assignment.
- Reference: reference cannot point to another object, but the object's internal state CAN change.
- Must be initialized at declaration, in an instance initializer, or in every constructor.

**`final` method:**
- Cannot be overridden in subclasses.
- JIT compiler can inline `final` methods — performance benefit.
- `private` methods are implicitly final (cannot be overridden anyway).

**`final` class:**
- Cannot be subclassed.
- `String`, `Integer`, and all wrapper classes are `final`.
- Ensures immutability and prevents subclasses from breaking contracts.

**Effectively final (Java 8+):**
A variable that is never reassigned after initialization. Lambda expressions and anonymous classes can only capture effectively final or explicitly final local variables.

### Java Code Example

```java
public final class ImmutableMoney {
    private final String currency;
    private final double amount;

    public ImmutableMoney(String currency, double amount) {
        this.currency = currency;
        this.amount = amount;
    }

    public ImmutableMoney add(ImmutableMoney other) {
        if (!this.currency.equals(other.currency))
            throw new IllegalArgumentException("Currency mismatch");
        return new ImmutableMoney(currency, this.amount + other.amount);
    }

    // Getters only, no setters
    public String getCurrency() { return currency; }
    public double getAmount() { return amount; }
}

// Effectively final in lambda context
public void process(List<String> items) {
    String prefix = "PROCESSED_";   // effectively final
    items.forEach(item -> System.out.println(prefix + item));
    // prefix = "OTHER_";  // would break effectivly-final, lambda would not compile
}
```

### Interview Trap
```java
final List<String> list = new ArrayList<>();
list.add("item");   // Valid — reference is final, not the list contents
list = new ArrayList<>();  // Compile error — cannot reassign reference
```

### Follow-up Questions
- Is `String` immutable because it is `final`? *(No — `final` prevents subclassing. Immutability comes from `private final char[]` and no mutation methods.)*
- What is the difference between `final`, `finally`, and `finalize()`?
- Can a `final` variable be changed via reflection? *(Technically yes, but unreliable and undefined behavior.)*

### Quick Revision
> `final` var = no reassignment (object state can change). `final` method = no override. `final` class = no subclass. `String` is final AND immutable.

---

## 11. `equals()` and `hashCode()` — The Contract

**Difficulty:** Medium–Hard
**Interview Frequency:** Very High
**Asked at:** Amazon, Google, Adobe, Goldman Sachs, Razorpay, Flipkart

### Short Interview Answer
`equals()` defines logical equality. `hashCode()` returns an integer used by hash-based collections. The critical contract: **if two objects are equal (`equals` returns true), they must have the same `hashCode`**. The reverse is not required (hash collisions are allowed).

### Deep Explanation

**The Contract (from `Object` Javadoc):**
1. `equals()` must be: reflexive, symmetric, transitive, consistent, and `x.equals(null)` returns false.
2. If `a.equals(b)` is true, then `a.hashCode() == b.hashCode()` must be true.
3. The reverse is not required — two unequal objects CAN have the same `hashCode` (hash collision).

**What happens when you break the contract:**
If you override `equals()` without overriding `hashCode()`, objects that are logically equal will have different hash codes. When used as `HashMap` keys, the map will NOT find the key even if the same logical key is used for lookup — it looks in a different bucket.

**Performance consideration in Java 17:**
- `Objects.hash(field1, field2, ...)` is convenient but creates a varargs array.
- For performance-critical code, manually compute: `31 * field1.hashCode() + field2.hashCode()`.
- Java records automatically generate `equals()` and `hashCode()` based on all components.

### Java Code Example

```java
public class OrderId {
    private final String value;

    public OrderId(String value) {
        this.value = Objects.requireNonNull(value, "OrderId cannot be null");
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (!(obj instanceof OrderId other)) return false;  // Java 16 pattern matching
        return Objects.equals(value, other.value);
    }

    @Override
    public int hashCode() {
        return Objects.hash(value);
    }

    @Override
    public String toString() {
        return "OrderId{" + value + "}";
    }
}

// With Java 17 record — equals/hashCode auto-generated
public record TransactionId(String value) {}
```

### Real-World Backend Example
In a payment service, `OrderId` objects are used as `HashMap` keys to cache order statuses. If `hashCode()` is not overridden, two `OrderId("ORD-001")` objects will hash to different buckets and the cache lookup will always miss, causing unnecessary database queries.

### Follow-up Questions
- What is the default `hashCode()` implementation in `Object`? *(Typically based on memory address, but not guaranteed.)*
- What happens if `hashCode()` always returns a constant? *(Legal but degrades HashMap to O(n) performance — all entries in one bucket.)*
- How does Java 17 record handle `equals()`/`hashCode()`?
- What is the impact on `HashSet` when `equals()`/`hashCode()` contract is violated?

### Common Mistakes
- Overriding `equals()` but not `hashCode()`.
- Including mutable fields in `hashCode()` — if the field changes after the object is added to a `HashSet`, it will be "lost."

### Interview Trap
> What happens if you put an object in a `HashSet`, then modify one of its fields (which is included in `hashCode()`)?

The object becomes "unreachable" inside the `HashSet` — it exists but cannot be found with `contains()` because it is now in the wrong bucket.

### Quick Revision
> `equals()` contract: reflexive, symmetric, transitive. If `a.equals(b)`, then `a.hashCode() == b.hashCode()`. Always override both together. Records do this automatically.

---

## 12. `clone()` and the Cloneable Interface

**Difficulty:** Medium
**Interview Frequency:** Medium
**Asked at:** Amazon, Adobe, Goldman Sachs (senior rounds)

### Short Interview Answer
`clone()` creates a copy of an object. Java's built-in cloning mechanism is considered broken by many experts (Effective Java). It performs a **shallow copy** by default — object fields are not deeply copied, only references are copied. You must implement `Cloneable` (a marker interface) and override `clone()` to enable cloning.

### Deep Explanation

**Shallow copy:** Copies field values. Primitive fields are duplicated. Reference fields copy the reference, not the object — both original and clone point to the same nested objects.

**Deep copy:** Recursively copies all nested objects. Must be done manually or via serialization.

**Problems with `clone()`:**
- `Cloneable` does not declare a `clone()` method — you must override it from `Object`.
- `Object.clone()` throws `CloneNotSupportedException` if `Cloneable` is not implemented.
- Does not call the constructor — can bypass invariants.
- Shallow by default — dangerous for mutable fields.

**Preferred alternatives:**
- Copy constructors: `new Employee(existingEmployee)`
- Copy factories: `Employee.copyOf(existingEmployee)`
- Serialization/deserialization for deep copy
- Libraries: Apache Commons `SerializationUtils.clone()`, or `ObjectMapper` with JSON serialization

### Java Code Example

```java
// Deep clone via copy constructor (preferred)
public class Order {
    private String orderId;
    private List<LineItem> items;

    // Copy constructor — safe deep copy
    public Order(Order other) {
        this.orderId = other.orderId;
        this.items = other.items.stream()
            .map(LineItem::new)   // copy constructor for LineItem too
            .collect(Collectors.toList());
    }
}
```

### Follow-up Questions
1. What is the difference between shallow copy and deep copy?
2. Why is Cloneable considered a broken design in Java?
3. What is a better alternative to clone() for creating copies of objects?

### Quick Revision
> `clone()` is broken — prefer copy constructors or copy factories. Shallow copy copies references. Always override `hashCode()`/`equals()` when implementing `clone()`.

---

## Chapter Summary — OOP Quick Reference

| Concept | Key Point |
|---|---|
| Class vs Object | Class = blueprint, Object = heap instance |
| Encapsulation | Private fields + controlled access = invariant protection |
| Inheritance | IS-A, single class, multiple interface |
| Polymorphism | Overloading = compile-time, Overriding = runtime (vtable) |
| Abstract vs Interface | IS-A with state vs CAN-DO contract |
| `final` | No reassign / no override / no subclass |
| `static` | Class-level, no `this`, no override (hiding) |
| `equals`/`hashCode` | Always override both; if equal, must have same hash |
| Composition | Favor over inheritance for flexibility |

---

*End of Chapter 1 — Next: Chapter 2: Strings, Wrapper Classes, and Exceptions*

