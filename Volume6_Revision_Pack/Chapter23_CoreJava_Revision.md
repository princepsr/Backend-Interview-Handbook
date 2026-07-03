# Volume 6: Interview Revision Pack
# Chapter 23: Core Java — Interview Lens

> **How to use this chapter:** Every Q&A is written to be spoken aloud in an interview. All technical terms are explained inline — you don't need to flip to another chapter. Study section by section; drill Common Mistakes and Quick Revision before your interview day.
>
> **Cross-reference:** Core concepts covered in depth in Volume 1 — Chapters 1 (OOP), 2 (Strings), 3 (Collections), 4 (Java 8+), 5 (JVM), 6 (Multithreading).

---

## Table of Contents
1. [OOP](#section-1-oop--top-10-interview-questions)
2. [Strings & Wrappers](#section-2-strings--wrappers--top-10-questions)
3. [Collections](#section-3-collections--top-15-questions)
4. [Java 8+](#section-4-java-8--top-15-questions)
5. [JVM Internals](#section-5-jvm-internals--top-10-questions)
6. [Multithreading](#section-6-multithreading--top-15-questions)
7. [Common Traps & Gotchas](#section-7-common-traps--gotchas)
8. [Must-Know Code Snippets](#section-8-must-know-code-snippets)

---

## Section 1: OOP

> *Reading guide: focus on the distinction between each paired concept — interviewers love asking you to contrast two related terms in one breath.*

**Q1: What is the difference between Abstraction and Encapsulation?**
*Concept Check*

**One-line answer:** Abstraction hides *what* a system exposes to callers; Encapsulation hides *how* it works internally.

**Full answer:**
Abstraction is about defining a contract — the set of operations a caller can invoke — without revealing the underlying implementation. When I declare an interface `Car` with a `drive()` method, I am practising abstraction: the caller knows they can drive the car, but they have no idea whether the engine is petrol, electric, or steam-powered. Encapsulation, on the other hand, is about bundling data and behaviour together inside a class and controlling access to that data using access modifiers like `private` and `protected`. When the `Engine` class keeps its `fuelLevel` field `private` and only exposes a `refuel()` method, that is encapsulation — the internal state is protected from outside interference. The two concepts work together: abstraction decides what to show the world, and encapsulation decides how to protect the internals from the world. A concrete way to remember the split: the `interface` keyword is your abstraction tool; the `private` keyword is your encapsulation tool.

*Deliver this as two crisp definitions followed by one concrete example each — interviewers reward clarity over length here.*

> **Gotcha follow-up:** Can a class be encapsulated but not abstract?
> Yes. A concrete class with all private fields and public getters/setters is fully encapsulated — it hides its internal state — but it is not abstract because it exposes its full implementation rather than just a contract. Abstraction usually appears at the interface or abstract-class level; encapsulation appears at the field-level of any class.

---

**Q2: What are the two types of polymorphism in Java?**
*Concept Check*

**One-line answer:** Compile-time polymorphism via method overloading, and runtime polymorphism via method overriding.

**Full answer:**
Polymorphism literally means "many forms" — the same method name behaves differently depending on context. Compile-time polymorphism (also called static dispatch) works through method overloading: you can define multiple methods with the same name in the same class as long as their parameter lists differ in type or count. The compiler looks at the method signature — the name plus the parameter types — at compile time and decides which version to call before the program even runs. Runtime polymorphism (also called dynamic dispatch) works through method overriding: a subclass redefines a parent class method using the exact same signature, and the JVM decides at runtime which version to call based on the actual object type, not the declared reference type. The JVM implements this using a virtual method table, often called a vtable — a per-class lookup table of method addresses. When you call `animal.speak()` on a reference declared as `Animal` but pointing to a `Dog` object, the JVM looks up `speak` in `Dog`'s vtable and calls `Dog.speak()`, not `Animal.speak()`.

*When explaining runtime polymorphism, briefly mention the vtable — it shows you understand the JVM mechanism, not just the Java syntax.*

> **Gotcha follow-up:** Can constructors be overridden?
> No. Constructors are not inherited and therefore cannot be overridden. They can be overloaded (a class can have multiple constructors with different parameter lists), but overriding is a subclass concept that only applies to instance methods.

---

**Q3: What is the difference between method overloading and method overriding?**
*Concept Check*

**One-line answer:** Overloading is resolved by the compiler based on signature; overriding is resolved by the JVM at runtime based on the actual object type.

**Full answer:**
Overloading happens within a single class (or across parent and child, where the child adds a version with a different signature). The compiler distinguishes overloaded methods by their method signature — the combination of the method name and parameter types. Return type alone is not enough to distinguish overloaded methods; changing only the return type causes a compile error. Overriding happens when a subclass redefines a method from its parent class using the exact same name, return type (or a covariant subtype), and parameter list. The `@Override` annotation is not mandatory, but you should always use it — if you accidentally misspell the method name or change a parameter type, the annotation causes a compile error that tells you immediately, rather than silently creating a new overloaded method that the JVM never dispatches to polymorphically. One important restriction on overriding: you cannot narrow the access modifier — a `public` parent method cannot be overridden as `protected` or `private`, because that would break the Liskov Substitution Principle (the idea that a subclass object should be usable anywhere a parent object is expected).

*Emphasise the `@Override` annotation — interviewers appreciate knowing you use it defensively.*

> **Gotcha follow-up:** Can a static method be overridden?
> No — static methods belong to the class, not the object, so dynamic dispatch does not apply. If a subclass declares a static method with the same signature as a parent's static method, it is called method hiding, not overriding. Calling the method through a parent-type reference invokes the parent's version regardless of the actual object type.

---

**Q4: When do you use an Interface vs an Abstract Class?**
*Tradeoff Question*

**One-line answer:** Use an interface to define a capability contract that unrelated classes can share; use an abstract class when you want to provide a partial implementation and shared state for a class hierarchy.

**Full answer:**
The fundamental difference is what they can hold. An interface (before Java 8) could only have abstract method declarations and `public static final` constants — no instance fields, no constructors, no concrete logic. Since Java 8, interfaces can have `default` methods (concrete methods with a body) and `static` methods, and since Java 9 they can have `private` helper methods. But they still cannot have instance fields or constructors. An abstract class can have instance fields, constructors, and any mix of abstract and concrete methods — it is essentially a regular class that happens to be incomplete. The second key difference is inheritance: a class can implement any number of interfaces (Java's answer to multiple inheritance), but it can only extend one class. The practical rule: reach for an interface when you are defining a capability that cuts across unrelated types — `Serializable`, `Runnable`, `Comparable` — because these are behaviours that many different classes in different hierarchies need to adopt. Reach for an abstract class when you have a genuine family of related types that share code and state — for example, `AbstractList` provides the bulk of `List` behaviour, and concrete implementations like `ArrayList` only need to fill in a handful of abstract methods.

| | Interface | Abstract Class |
|---|---|---|
| Instance fields | No (only `static final` constants) | Yes |
| Constructor | No | Yes |
| Multiple inheritance | Yes (implement many) | No (extend one) |
| Default methods | Yes (Java 8+) | Yes |
| Best for | Capability contract | Shared base + partial implementation |

*Recite the table from memory in an interview — it shows you have internalised the tradeoffs, not just memorised definitions.*

> **Gotcha follow-up:** Can an abstract class implement an interface without implementing all its methods?
> Yes. An abstract class can declare that it implements an interface but leave some or all of the interface's methods abstract — it defers the obligation to its concrete subclasses. This is a common pattern in the JDK: `AbstractList` implements `List` but leaves `get(int)` and `size()` abstract.

---

**Q5: Composition vs Inheritance — which should you prefer and why?**
*Tradeoff Question*

**One-line answer:** Prefer composition because it is loosely coupled and flexible; use inheritance only when a genuine "is-a" relationship exists.

**Full answer:**
Inheritance models an "is-a" relationship: a `Dog` is an `Animal`. When you extend a class, your subclass inherits all of the parent's public and protected methods and fields, which creates tight coupling — the subclass is intimately aware of the parent's internals, and a change to the parent class can silently break the subclass. This is called the fragile base class problem. Composition models a "has-a" relationship: a `Car` has an `Engine`. Instead of extending `Engine`, the `Car` class holds a reference to an `Engine` object and delegates engine-related operations to it. This means you can swap the `Engine` implementation at runtime (dependency injection), the `Car` class is not exposed to `Engine`'s internals, and changes to `Engine` only break `Car` if the public interface changes. The Gang of Four design patterns book summarises this as "favour composition over inheritance" — this is one of the most repeated pieces of advice in software design. A practical signal: if you find yourself extending a class mainly to reuse some of its methods (not because the subclass truly is a specialisation), switch to composition.

*Mention the fragile base class problem by name — it is a recognised term that shows depth.*

> **Gotcha follow-up:** Give an example where inheritance is the right choice.
> `java.io.InputStream` and its subclasses (`FileInputStream`, `ByteArrayInputStream`) are a good example. Each is genuinely a type of input stream — the "is-a" relationship holds, and they share the `read()`, `close()`, and `skip()` contract. The Template Method pattern — where a parent class defines a fixed algorithm skeleton and subclasses fill in specific steps — is another case where inheritance is the appropriate tool.

---

**Q6: What are covariant return types?**
*Concept Check*

**One-line answer:** Since Java 5, an overriding method can declare a return type that is a subtype of the parent method's return type.

**Full answer:**
Before Java 5, when overriding a method you had to match the return type exactly. Covariant return types relaxed this rule: the overriding method's return type can be the same type as the parent's or any subclass of it. For example, if `Animal` declares `Animal clone()`, a `Dog` subclass can override it as `Dog clone()` — because `Dog` is a subtype of `Animal`, this is legal. The practical benefit is that callers who have a `Dog` reference and call `clone()` get back a `Dog` directly without needing a cast. Without covariant return types, the caller would have to write `Dog d2 = (Dog) d1.clone()`, which is verbose and can throw `ClassCastException` if something goes wrong. This feature is heavily used in the Builder pattern, where each method returns `this` typed as the concrete builder subclass, enabling fluent method chaining without casts.

*Mention the Builder pattern application — it shows you connect the concept to real design patterns.*

> **Gotcha follow-up:** Does covariant return type work for primitive types?
> No. Covariance applies to reference types only. You cannot change `int` to `long` or `int` to `Integer` when overriding — those would be incompatible types, not subtypes.

---

**Q7: What is a Marker Interface, and what is the modern alternative?**
*Concept Check*

**One-line answer:** A marker interface is an empty interface used as a type tag; the modern alternative is a runtime-retained annotation.

**Full answer:**
A marker interface contains no method declarations — its sole purpose is to tag a class so that the JVM, a framework, or your own code can check `instanceof MarkerInterface` and enable certain behaviour. The three canonical examples in the JDK are `Serializable` (signals to `ObjectOutputStream` that the object can be serialised), `Cloneable` (signals to `Object.clone()` that the object consents to being shallow-copied — without it, `clone()` throws `CloneNotSupportedException`), and `RandomAccess` (signals to algorithms like `Collections.binarySearch()` that the list supports O(1) index access, so the algorithm should use index-based access rather than an iterator). The limitation of marker interfaces is that they carry no metadata — you cannot attach configuration values. Annotations with `@Retention(RetentionPolicy.RUNTIME)` are the modern equivalent: they are checked with reflection (`method.isAnnotationPresent(MyAnnotation.class)`), they can carry attribute values, and they do not pollute the type hierarchy. Spring's `@Transactional`, `@Component`, and JPA's `@Entity` are all runtime-retained annotations playing the same role a marker interface would.

*Interviewers often follow up with "why not just use an annotation then?" — be ready to explain that marker interfaces still have one advantage: they are enforced at compile time by the type system, whereas annotation checking is a runtime concern.*

> **Gotcha follow-up:** What happens if you call `clone()` on an object whose class does not implement `Cloneable`?
> `Object.clone()` checks at runtime whether the object's class implements `Cloneable`. If it does not, it throws `CloneNotSupportedException` — even though `Cloneable` has no methods to implement. This is a quirky design where the marker interface acts as a runtime permission flag checked inside native JVM code.

---

**Q8: How do you make an Immutable class in Java?**
*Design Scenario*

**One-line answer:** Declare the class `final`, all fields `private final`, provide no setters, and defensively copy any mutable fields in the constructor and getters.

**Full answer:**
An immutable class is one whose state cannot change after construction — every read of a field returns the same value for the lifetime of the object. To achieve this, follow five steps. First, declare the class `final` so no subclass can add mutable state or override methods in a way that breaks immutability guarantees. Second, declare every field `private final` — `private` prevents direct external access, and `final` ensures the field is assigned exactly once in the constructor and never reassigned. Third, provide no setter methods — there must be no way to change a field after construction. Fourth, if any field holds a reference to a mutable object — such as a `Date`, an array, or a `List` — you must make a defensive copy in the constructor. If the caller passes in a `List` and you just store the reference, the caller still holds that reference and can mutate the list, breaking your immutability. You copy the list on the way in, and on the way out you return `Collections.unmodifiableList(field)` from the getter so the caller cannot mutate the returned reference either. Fifth, `String` is the canonical immutable class in Java — it follows all of these rules, which is why it is safe to use as a `HashMap` key and safe to share across threads without synchronisation.

*Walk through all five rules in order — interviewers award full marks for completeness here.*

> **Gotcha follow-up:** Is it enough to make a field `final` to guarantee immutability?
> No. `final` only means the reference cannot be reassigned — it says nothing about the object the reference points to. A `final List<String>` field cannot be pointed at a different list, but you can still call `add()` on the list it points to. True immutability requires that the objects the fields reference are also immutable, or that you prevent external code from accessing and mutating them.

---

**Q9: Explain the `equals()` / `hashCode()` contract.**
*Concept Check*

**One-line answer:** If `a.equals(b)` is true, then `a.hashCode()` must equal `b.hashCode()` — violating this breaks `HashMap` and `HashSet`.

**Full answer:**
The contract has two parts. The mandatory part: if two objects are considered equal by `equals()`, they must produce the same hash code. The optional part (which is good practice but not required): if two objects have the same hash code, they do not necessarily have to be equal — that is just a collision, and hash-based collections handle collisions gracefully. The reason this matters: a `HashMap` uses the hash code to decide which bucket to place an entry in. When you call `map.get(key)`, it computes `key.hashCode()`, locates the bucket, and then uses `equals()` to find the exact entry within that bucket. If you override `equals()` without overriding `hashCode()`, two objects that are logically equal will have different hash codes (because they inherited `Object.hashCode()`, which is based on object identity). They will end up in different buckets, and `get()` will return `null` even though the key is logically present. The `equals()` method itself must satisfy five mathematical properties: reflexive (`a.equals(a)` is always true), symmetric (`a.equals(b)` == `b.equals(a)`), transitive (if `a.equals(b)` and `b.equals(c)` then `a.equals(c)`), consistent (repeated calls with unchanged objects return the same result), and it must return `false` — never throw — when compared against `null`.

*Always mention the five properties of `equals()` — it distinguishes a thorough answer from a surface-level one.*

> **Gotcha follow-up:** What happens if `hashCode()` always returns the same constant value for all objects?
> It technically satisfies the contract — objects that are equal have the same hash code. But performance degrades to O(n) for every `HashMap` operation: all entries land in the same bucket, turning the bucket from a linked list of one or two nodes into a linked list of all n entries. Every `get()` and `put()` must scan the entire list. This is why a good hash function distributes entries evenly across buckets.

---

**Q10: What are the gotchas with `Object.clone()`?**
*Concept Check*

**One-line answer:** `clone()` does a shallow copy by default — mutable fields are shared between the original and the clone — and the API design is awkward enough that copy constructors are usually better.

**Full answer:**
`Object.clone()` creates a new object and copies every field value from the original into it — this is called a shallow copy. For primitive fields (`int`, `double`, etc.) that is fine, because copying the value copies everything there is. For reference fields, however, shallow copy means both the original and the clone point to the same object in memory. If that object is mutable — an array, a `List`, a `Date` — mutating it through the original also changes what the clone sees, and vice versa. To perform a deep copy, you must override `clone()` and manually copy each mutable field: `this.items = Arrays.copyOf(original.items, original.items.length)`. The API design also has rough edges: to use `clone()`, your class must implement the `Cloneable` marker interface (which has no methods — it is purely a flag), and you must change the access modifier of your `clone()` override to `public` (it is `protected` in `Object`). The cleaner alternative is a copy constructor — `public MyClass(MyClass other)` — or a static factory method. These approaches are explicit, don't require `Cloneable`, can be typed precisely, and never silently do the wrong thing with mutable fields.

*Recommend copy constructors as the modern alternative — interviewers respect knowing idiomatic Java, not just the legacy API.*

> **Gotcha follow-up:** Does implementing `Cloneable` give your class a `clone()` method?
> No. `Cloneable` has zero methods. What it does is tell the JVM that calling `Object.clone()` on this object is permitted — without it, `Object.clone()` throws `CloneNotSupportedException`. You still have to override `clone()` yourself and make it `public` if you want callers to be able to clone your object.

---

**Common Mistakes:**
- **Overriding `equals()` without overriding `hashCode()`** → objects that are logically equal end up in different `HashMap` buckets; `get()` returns `null` for keys that are present. Always override both together.
- **Using `==` to compare objects** → `==` checks reference identity, not logical equality; use `.equals()` for value comparison and `Objects.equals(a, b)` when either side might be null.
- **Confusing overloading with overriding** → adding a method with a different parameter type creates a new overloaded method, not an override; the original is still called polymorphically. Use `@Override` to catch this at compile time.
- **Storing a mutable field reference directly in an immutable class** → the caller still holds the reference and can mutate the object; always defensive-copy mutable constructor arguments.

**Quick Revision:** Abstraction = the interface you show the world; Encapsulation = the `private` you hide behind it — and if you override `equals`, you must override `hashCode`, full stop.

---

## Section 2: Strings & Wrappers

> *Reading guide: focus on the memory and performance implications of each concept — the String Pool and autoboxing questions are almost always followed by a "what goes wrong" scenario.*

**Q1: What is the Java String Pool and how does it work?**
*Concept Check*

**One-line answer:** The String Pool is a region of the heap where the JVM stores a single copy of each unique string literal so that identical literals share one object rather than allocating separately.

**Full answer:**
When the JVM encounters a string literal in your code — for example `String a = "hello"` — it checks the String Pool to see whether an equal string already exists there. If it does, it returns the existing reference; if not, it adds the new string to the pool and returns that reference. When another part of the code later writes `String b = "hello"`, it gets back the exact same pooled object, so `a == b` is true (they are literally the same object in memory). This sharing is safe only because `String` is immutable — if strings were mutable, one piece of code changing `a` to `"world"` would silently change `b` as well. The String Pool lived in the PermGen (Permanent Generation) memory space before Java 7; since Java 7 it lives in the regular heap, which means pooled strings can be garbage-collected if no strong references remain and allows the pool to grow without hitting the fixed PermGen size limit. The contrast is `new String("hello")`: this explicitly allocates a brand-new `String` object on the heap, bypassing the pool entirely, so `new String("hello") == new String("hello")` is false even though the character content is identical. There is almost never a good reason to use `new String(...)`.

*Mention the Java 7 relocation from PermGen to heap — it shows you know the evolution of the JVM, which interviewers appreciate.*

> **Gotcha follow-up:** Are compile-time string concatenations added to the pool?
> Yes. Expressions like `"hel" + "lo"` where both operands are compile-time constants are evaluated by the compiler and the result `"hello"` is placed in the pool as if you had written the literal directly. But runtime concatenations like `"hel" + variable` produce a new heap string that is not automatically pooled — you would need to call `.intern()` to add it to the pool.

---

**Q2: What does `String.intern()` do and when should you use it?**
*Concept Check*

**One-line answer:** `intern()` returns the pooled canonical version of a string, adding it to the pool first if necessary — useful for deduplicating strings that are equal by value.

**Full answer:**
When you call `someString.intern()`, the JVM looks up the String Pool for an entry that is `equals()` to `someString`. If a match exists, it returns the pooled reference. If not, it adds `someString` to the pool and returns its reference. After interning, two strings that were equal by value but were different heap objects will now be the same pooled object, so you can compare them with `==` instead of `.equals()`. The use case is deduplication: imagine loading a million database rows where a `status` column has only five distinct values ("ACTIVE", "INACTIVE", "PENDING", "CANCELLED", "DELETED") but those five values are each represented as a separate `String` object for every row. Interning them means all "ACTIVE" instances share one object, reducing heap usage significantly. The risk: pooled strings are referenced by a table that the GC cannot easily clear. If you intern millions of unique strings, you permanently bloat the pool. Only intern strings when the set of distinct values is small and the strings will be long-lived.

*Quantify the deduplication benefit with a concrete scenario — it shows you understand when the tool is worth using.*

> **Gotcha follow-up:** Does `==` always work correctly after interning?
> Yes — if both strings have been interned, `==` gives the correct equality result because interned strings are canonical. But this is fragile: if any string involved was not interned, `==` silently gives the wrong answer without any error. For correctness, always use `.equals()` for value comparison; only use `==` as a performance optimisation in specific, well-understood scenarios where you have guaranteed that both sides are interned.

---

**Q3: When do you use `String` vs `StringBuilder` vs `StringBuffer`?**
*Tradeoff Question*

**One-line answer:** `String` for immutable values, `StringBuilder` for single-threaded string building, `StringBuffer` only when string building must be thread-safe (rare).

**Full answer:**
`String` is immutable — every operation that appears to modify a string (concatenation with `+`, `replace()`, `substring()`) actually creates and returns a new `String` object. This is fine for one-off operations but disastrous in a loop: `result = result + element` inside a loop of n iterations creates n intermediate `String` objects that are immediately discarded, causing significant garbage collector pressure and O(n²) total character copies. `StringBuilder` is a mutable sequence of characters backed by a resizable `char[]` array. You call `append()` to add content and `toString()` when you want the final `String`. It is not synchronised, so it is not safe to share a single `StringBuilder` across threads — but since string builders are almost always local variables used within a single method, this is not a problem in practice. `StringBuffer` predates Java 1.5 and was the original mutable string type; every method is `synchronized`, making it thread-safe but approximately 20-25% slower than `StringBuilder` due to the lock acquisition overhead on every call. In modern Java, if you need thread-safe string assembly across threads, you are usually better off using `ConcurrentLinkedQueue` to accumulate parts and joining them at the end, rather than reaching for `StringBuffer`.

*State explicitly that `StringBuffer` is rarely needed in modern code — it shows you have practical judgement, not just textbook knowledge.*

> **Gotcha follow-up:** Does the Java compiler optimise `String +` concatenation automatically?
> Yes, but only to a degree. A single statement like `String s = a + b + c` is compiled into a single `StringBuilder` chain. The trap is `+` inside a loop: each loop iteration creates a new `StringBuilder`, appends, and converts to `String` — the compiler does not hoist the `StringBuilder` creation outside the loop. From Java 9, the JVM uses `invokedynamic` and `StringConcatFactory` for concatenation, which is more efficient than a raw `StringBuilder`, but it still cannot avoid the per-iteration allocation in a loop. The only reliable fix is an explicit `StringBuilder` declared before the loop.

---

**Q4: Why is `String` immutable in Java?**
*Concept Check*

**One-line answer:** Immutability makes `String` safe for use as a `HashMap` key, safe to share across threads, safe in security-sensitive APIs, and enables the String Pool.

**Full answer:**
There are four distinct reasons. Security: `String` is used to represent class names, file paths, database URLs, and passwords throughout the JDK and application frameworks. If a string were mutable, an attacker could pass a string that passes a security check, then mutate it before the actual operation uses it — for example, passing a path that looks safe during validation but is changed to `"/etc/passwd"` before the file is opened. Immutability closes this attack surface. String Pool efficiency: the pool works by having multiple references point to a single shared object. If that shared object were mutable, one reference changing it would silently corrupt all other references — the pool would be unusable. HashMap key safety: when you use a `String` as a `HashMap` key, the map uses `hashCode()` to find the right bucket. `String` caches its hash code after the first computation — subsequent calls return the cached value in O(1). If the string were mutable, the hash code could change after insertion, and `get()` would look in the wrong bucket and return `null` for a key that is logically present. Thread safety: immutable objects are inherently safe to share across threads without any synchronisation — there are no writes to coordinate. Sharing a `String` between threads requires zero locking.

*Four reasons, stated clearly — give all four. Interviewers will probe you if you only give two.*

> **Gotcha follow-up:** Is the `String` class `final`?
> Yes. `String` is declared `final` in the JDK, which prevents subclassing. If subclassing were allowed, a subclass could override methods in a way that introduced mutability, undermining all the guarantees above. The `final` declaration is itself part of the immutability guarantee.

---

**Q5: Explain the Integer cache and why `==` on `Integer` is dangerous.**
*Concept Check*

**One-line answer:** Java caches `Integer` objects for values -128 to 127, so `==` works by accident in that range but fails for values outside it — always use `.equals()`.

**Full answer:**
When you use autoboxing — converting a primitive `int` to an `Integer` object — Java calls `Integer.valueOf(int)` under the hood. `Integer.valueOf()` has a cache: for values in the range -128 to 127, it always returns the same pre-allocated `Integer` object rather than creating a new one. So `Integer a = 100; Integer b = 100; a == b` evaluates to `true` because both variables point to the same cached object. But `Integer a = 200; Integer b = 200; a == b` evaluates to `false` because 200 is outside the cache range — `valueOf(200)` allocates a brand-new `Integer` object each time, and the two variables point to two different objects in memory. This is one of the most common sources of subtle bugs in Java: `==` on `Integer` gives the right answer for small values and the wrong answer for large values, with no error or warning. The fix is simple and absolute: always use `.equals()` when comparing `Integer` objects for value equality. The upper bound of the cache can be extended with the JVM flag `-XX:AutoBoxCacheMax=N`, but relying on this is bad practice because it makes your code's correctness depend on a JVM flag that could be absent in another environment.

*Cite the exact range (-128 to 127) and the JVM flag — both show precision.*

> **Gotcha follow-up:** Does this cache behaviour apply to other wrapper types?
> Yes. `Byte`, `Short`, `Long`, and `Character` all have similar caches for small values. `Boolean` caches both `Boolean.TRUE` and `Boolean.FALSE`. `Float` and `Double` do not cache any values. The principle is the same for all of them: use `.equals()` for value comparison, never `==`.

---

**Q6: What are the pitfalls of autoboxing?**
*Concept Check*

**One-line answer:** Autoboxing can cause `NullPointerException` on unboxing, incorrect `==` comparisons outside the cache range, and GC pressure in tight loops.

**Full answer:**
Autoboxing is the automatic conversion between primitive types (`int`, `long`, `double`) and their wrapper object counterparts (`Integer`, `Long`, `Double`). It is convenient, but it hides three traps. The first is `NullPointerException`: if you have an `Integer` field or variable that is `null` and you assign it to a primitive `int`, Java unboxes it by calling `null.intValue()`, which throws `NullPointerException`. This often appears in code like `int total = map.get("key")` where `get()` returns `null` if the key is absent. The fix is to check for null or use `map.getOrDefault("key", 0)`. The second pitfall is the `==` reference trap described in the Integer cache question — outside the -128 to 127 range, two `Integer` objects with the same value are different objects and `==` returns `false`. The third is performance: in a tight loop that produces many `Integer` objects — for example, accumulating values in a `List<Integer>` — each iteration boxes the primitive result into a new heap object. For a loop that runs a million times, that is a million short-lived `Integer` objects for the garbage collector to clean up. The fix is to use a primitive array (`int[]`), a primitive stream (`IntStream`), or a primitive collection from a library like Eclipse Collections or Trove.

*All three pitfalls — name them explicitly and give the fix for each.*

> **Gotcha follow-up:** What does `Long sum = 0; for (long i = 0; i < 1_000_000; i++) sum += i;` do wrong?
> Every iteration unboxes `sum` to a `long`, adds `i`, and then re-boxes the result into a new `Long` object. This creates one million `Long` allocations. The fix is to declare `sum` as a primitive `long` from the start.

---

**Q7: How does `String` concatenation with `+` perform compared to `String.format()`?**
*Tradeoff Question*

**One-line answer:** Compile-time `+` concatenation is fast; `+` inside a loop is O(n²) allocations; `String.format()` is the slowest due to runtime format parsing.

**Full answer:**
For a simple expression outside a loop — `String s = "Hello, " + name + "!"` — the Java compiler rewrites this as a `StringBuilder` chain, so there is effectively one allocation: the final `String`. This is fast and there is no reason to replace it with a `StringBuilder` manually. The trap is the `+` operator inside a loop. In a loop that runs n times, each iteration creates a new `StringBuilder`, appends to it, calls `toString()` to produce a `String`, and discards the `StringBuilder` — then the next iteration starts from scratch. The total number of characters copied across all iterations is 1 + 2 + 3 + ... + n = O(n²). For n = 10,000 that is 50 million character copies. The fix is to declare a single `StringBuilder` before the loop and call `append()` on each iteration. `String.format("Hello, %s!", name)` is the most expensive option: it parses the format string at runtime using a `Formatter` object, processes format specifiers, and only then builds the result. Use `String.format()` when the formatting complexity justifies the overhead — complex number formatting, locale-aware output — not for simple concatenation.

*Give the O(n²) analysis explicitly — it elevates the answer from "StringBuilder is faster" to "here is exactly why."*

> **Gotcha follow-up:** Does Java 9's `invokedynamic`-based string concatenation change the loop behaviour?
> Java 9+ replaced the `javac`-generated `StringBuilder` with `invokedynamic` calling `StringConcatFactory`, which can choose the most efficient strategy at JVM startup. For simple non-loop cases, this is slightly faster. But the fundamental loop problem remains: if `+` is inside a loop, a new concatenation operation runs on each iteration regardless of the JVM strategy. An explicit `StringBuilder` is still the correct fix.

---

**Q8: What are Compact Strings, introduced in Java 9?**
*Concept Check*

**One-line answer:** Compact Strings store Latin-1 characters as 1 byte each instead of 2, roughly halving heap usage for ASCII-heavy applications — transparently, with no API changes.

**Full answer:**
Before Java 9, every `String` was internally backed by a `char[]` array where each element was a 16-bit UTF-16 code unit — 2 bytes per character. Even a plain ASCII string like `"hello"` consumed 10 bytes of character storage. Java 9 changed the internal representation: strings are now backed by a `byte[]` array plus a 1-byte encoding flag. If all characters in the string fit in the Latin-1 range (Unicode code points 0x00 to 0xFF, which covers all ASCII and most Western European characters), the string uses 1 byte per character. If any character requires a code point above 0xFF, the string falls back to UTF-16 encoding (2 bytes per character). For typical web applications that process HTTP headers, JSON keys, SQL queries, and most English-language text — all of which are ASCII — Compact Strings reduce the heap memory consumed by strings by roughly 50%. This change is entirely transparent: the `String` API is identical, and existing code does not need to change. The JVM handles the encoding decision automatically.

*Mention that it is transparent and requires no code changes — practical interviewers care about migration impact.*

> **Gotcha follow-up:** Does Compact Strings affect string performance?
> There is a slight overhead when accessing individual characters of a UTF-16 string, because the JVM must check the encoding flag and handle two-byte pairs. For Latin-1 strings, there is no overhead — the 1-byte array access is faster than the 2-byte `char` access was. In practice, the overall effect on throughput is neutral to slightly positive for most applications, because the reduced memory footprint means better cache utilisation and less GC pressure.

---

**Q9: Why is `char` not sufficient for full Unicode support?**
*Concept Check*

**One-line answer:** A Java `char` is a 16-bit UTF-16 code unit and can only directly represent the Basic Multilingual Plane; characters above U+FFFF require two `char` values (a surrogate pair).

**Full answer:**
Java's `char` type is a 16-bit unsigned integer, which means it can represent values from 0 to 65,535 — the Unicode Basic Multilingual Plane, which covers most commonly used characters including the full Latin alphabet, Cyrillic, Arabic, Chinese, Japanese, and Korean. However, Unicode has grown beyond the BMP: supplementary characters — including many emoji, rare historical scripts, and some uncommon Chinese characters — have code points above U+FFFF, requiring values from 65,536 to 1,114,111. UTF-16 encoding represents these supplementary characters as a pair of 16-bit values called a surrogate pair: a high surrogate (U+D800 to U+DBFF) followed by a low surrogate (U+DC00 to U+DFFF). This means a `char` variable cannot hold a supplementary character — you need two `char` values to represent one logical character. If you iterate over a `String` using `charAt(i)` or a for-each loop over chars, you will mis-handle surrogate pairs and may split a single logical character across iterations. The correct approach for full Unicode support is to iterate over code points using `string.codePoints()` (returns an `IntStream` of Unicode code points) or use the `Character` class's `isHighSurrogate()`, `isLowSurrogate()`, and `toCodePoint()` methods when you need to process individual characters.

*Give the concrete code point range and the correct API — it shows production-level awareness.*

> **Gotcha follow-up:** What does `"😀".length()` return in Java?
> It returns 2, not 1. The emoji U+1F600 is a supplementary character above the BMP, so it is encoded as a two-`char` surrogate pair in Java's UTF-16 internal representation. `"😀".codePointCount(0, "😀".length())` returns 1, which is the correct logical character count.

---

**Q10: When should you use `String.equals()` vs `==`, and how do you handle null safely?**
*Concept Check*

**One-line answer:** Always use `.equals()` for `String` value comparison; use `Objects.equals(a, b)` when either side might be null.

**Full answer:**
The `==` operator on any object, including `String`, compares references — it asks whether the two variables point to the exact same object in memory. `.equals()` on `String` compares the actual sequence of characters. Because of the String Pool, two string literals written identically in your source code are often the same object, so `==` might return `true` — but this is an implementation detail, not a guarantee. Any `String` constructed at runtime (from user input, a database, a network response, `String.valueOf()`, `substring()`, etc.) will be a distinct heap object even if its value is identical to another string, so `==` will return `false`. The rule is absolute: use `.equals()` for `String` value comparison, always. For null safety: if the left-hand side of `.equals()` could be null, calling `a.equals(b)` throws `NullPointerException`. The classic workaround was to write `"literal".equals(variable)` — put the known-non-null string on the left. The modern, idiomatic solution is `Objects.equals(a, b)` (available since Java 7), which returns `false` if either or both arguments are null, and delegates to `.equals()` otherwise.

*Mention `Objects.equals()` as the null-safe solution — it shows you know the modern idiom.*

> **Gotcha follow-up:** If I intern two strings and they are equal, can I safely use `==`?
> Yes, interned equal strings will be `==` because they both point to the same pooled object. But relying on this is fragile: the guarantee only holds if you can be certain both strings have been interned, which is hard to maintain across a codebase. In all but highly specialised performance-critical scenarios, use `.equals()` for clarity and correctness.

---

**Common Mistakes:**
- **Using `new String("literal")`** → bypasses the pool, wastes memory, and confuses readers; just use the literal directly.
- **String `+` in a loop** → creates O(n) intermediate objects; declare a `StringBuilder` before the loop and `append()` inside it.
- **Comparing `Integer` with `==`** → correct for -128 to 127 by accident, silently wrong for larger values; always use `.equals()`.
- **Unboxing a null wrapper** → `Integer x = null; int y = x;` throws `NullPointerException`; check for null or use `getOrDefault()` / `Optional`.
- **Using `charAt()` to iterate emoji or supplementary characters** → splits surrogate pairs; use `codePoints()` for Unicode-correct iteration.

**Quick Revision:** `String` is immutable and pooled; `StringBuilder` builds, `StringBuffer` builds with a lock; and `Integer == Integer` is a lie outside the -128 to 127 range.

---

## Section 3: Collections

> *Reading guide: focus on the internal data structures and their performance characteristics — every question here can be answered at two levels: "what does it do" and "how does it do it efficiently."*

**Q1: How does `HashMap` work internally?**
*Concept Check*

**One-line answer:** `HashMap` hashes keys into bucket indices in an array; each bucket holds a linked list (or, for large buckets, a Red-Black Tree) of entries.

**Full answer:**
A `HashMap` is backed by an array called the bucket table, typed as `Node<K,V>[]`. The default initial capacity is 16 buckets. To store a key-value pair, Java first computes a hash of the key: it calls `key.hashCode()` and then applies a secondary mixing step — XORing the hash with itself shifted right by 16 bits (`hash ^ (hash >>> 16)`) — to spread entropy from the high bits into the low bits, reducing collisions for keys whose `hashCode()` values differ only in the upper bits. The bucket index is computed as `hash & (capacity - 1)` (bitwise AND, equivalent to modulo when capacity is a power of two, but much faster). If two keys land in the same bucket, their entries are stored as a singly-linked list within that bucket — this is called a collision. As entries are added, the table eventually needs to grow. When the number of entries exceeds `capacity * loadFactor` (0.75 by default), the table doubles in capacity and all entries are rehashed into the new, larger table — this is an O(n) operation called a resize. Java 8 introduced an optimisation: when a single bucket accumulates more than 8 entries and the overall table has at least 64 buckets, the linked list in that bucket is converted to a Red-Black Tree (a self-balancing binary search tree). This changes worst-case lookup within a heavily colliding bucket from O(n) to O(log n).

*Mention the treeification threshold (8 entries) and the minimum table size (64) — these show you know the precise JDK implementation.*

> **Gotcha follow-up:** Why does `HashMap` use a power-of-two capacity?
> When capacity is a power of two, `hash & (capacity - 1)` is equivalent to `hash % capacity` but is computed with a single bitwise AND instruction instead of a division — significantly faster on modern CPUs. The capacity doubling on resize is also trivial: the new bucket index for each entry is either the same as before or the same plus the old capacity, so the rehashing logic is simple and branch-free.

---

**Q2: How does `ConcurrentHashMap` differ from a `synchronized` `HashMap`?**
*Tradeoff Question*

**One-line answer:** `ConcurrentHashMap` uses lock-free reads and per-bucket fine-grained locking for writes; `synchronizedMap` uses a single global lock that serialises all operations.

**Full answer:**
`Collections.synchronizedMap(map)` wraps any map in a proxy where every method — every `get()`, every `put()`, every `containsKey()` — acquires a single mutex on the wrapper object. This means at most one thread can operate on the map at a time. Under high concurrency, every thread blocks waiting for the lock, turning the map into a serial bottleneck. `ConcurrentHashMap` (redesigned in Java 8) uses a much more sophisticated approach. Reads do not acquire any lock: the `value` field in each `Node` entry is declared `volatile`, which means changes made by one thread are immediately visible to all other threads without a lock. Writes use CAS (Compare-And-Swap), a hardware atomic instruction that updates a memory location only if it currently holds an expected value — this is how the map atomically inserts a new entry into an empty bucket without a lock. When a bucket already has entries, the write synchronises only on that specific bucket's head node, not the entire map. This means many threads can read and write different buckets simultaneously, achieving much higher throughput. The deliberate design choice to disallow `null` keys and `null` values follows from this concurrency model: if `get(key)` returned `null`, you could not tell whether the key was absent or whether its value was null, and verifying which case you are in requires `containsKey()` followed by `get()` — which is not atomic, so the state could change between the two calls.

*Explain the null restriction in terms of concurrency correctness — it is a commonly misunderstood design decision.*

> **Gotcha follow-up:** Is `ConcurrentHashMap.size()` exact?
> Not necessarily. In Java 8+, `size()` is computed by summing counters that are maintained across multiple `CounterCell` objects (an approach adapted from `LongAdder`). Under concurrent modifications, the returned value may be stale by the time you read it. For operations that need a precise count with consistency guarantees, you need external synchronisation or a different data structure.

---

**Q3: What is `LinkedHashMap` used for, and how does `TreeMap` differ?**
*Tradeoff Question*

**One-line answer:** `LinkedHashMap` preserves insertion (or access) order with O(1) operations; `TreeMap` stores keys in sorted order with O(log n) operations.

**Full answer:**
`LinkedHashMap` extends `HashMap` by maintaining a doubly-linked list that runs through all entries in the order they were inserted. `get()` and `put()` are still O(1) — the linked list adds only a constant overhead of updating two pointers per operation. You can construct a `LinkedHashMap` with the `accessOrder` flag set to `true`, which changes the list ordering from insertion order to access order — every call to `get()` or `put()` moves that entry to the tail of the list. The head of the list is then always the least-recently-used entry. This is exactly the behaviour needed for an LRU (Least Recently Used) cache: you subclass `LinkedHashMap`, override `removeEldestEntry()` to return `true` when the map exceeds your maximum size, and Java automatically removes the head (least-recently-used) entry. `TreeMap` stores entries in a Red-Black Tree, a self-balancing binary search tree, where nodes are ordered by key using either the key's natural ordering (the `compareTo()` method of the `Comparable` interface) or a custom `Comparator` provided at construction. All operations — `get()`, `put()`, `remove()` — are O(log n). `TreeMap` implements `NavigableMap`, giving you powerful range operations: `floorKey(k)` returns the largest key less than or equal to k, `ceilingKey(k)` returns the smallest key greater than or equal to k, `subMap(from, to)` returns a live view of a key range.

*Mention the LRU cache pattern using `removeEldestEntry()` — it is a classic interview question built on this knowledge.*

> **Gotcha follow-up:** Can `TreeMap` have `null` keys?
> No — `TreeMap` must compare keys to maintain sorted order, and calling `compareTo()` or the `Comparator` on a `null` key throws `NullPointerException`. `HashMap` allows one `null` key by special-casing it to bucket 0. `LinkedHashMap` inherits this behaviour and also allows one `null` key.

---

**Q4: Why should you prefer `ArrayDeque` over `LinkedList` for stack and queue operations?**
*Tradeoff Question*

**One-line answer:** `ArrayDeque` is backed by a contiguous array, giving better cache locality and no per-element object allocation overhead compared to `LinkedList`'s node-per-element model.

**Full answer:**
`ArrayDeque` (Array Double-Ended Queue) is backed by a resizable circular array — all elements are stored contiguously in memory. When the CPU accesses one element, the neighbouring elements are loaded into the CPU cache at the same time (spatial locality). Subsequent accesses to adjacent elements are therefore served from cache (nanosecond speed) rather than main memory (hundreds of nanoseconds). `LinkedList` allocates a separate `Node` object for every element. These nodes are created at different times and scattered across the heap, so sequential access means repeatedly fetching from different memory locations, defeating the CPU cache. Additionally, each `Node` object has object header overhead and two pointer fields (previous, next), adding memory overhead per element. In practical benchmarks, `ArrayDeque` outperforms `LinkedList` for push/pop (stack) and add/poll (queue) operations consistently — often by a factor of two or more. The JDK documentation for `LinkedList` itself recommends `ArrayDeque` for stack and queue use cases. Only prefer `LinkedList` if you specifically need it to implement both `List` and `Deque` on the same object, or if you need `ListIterator` with O(1) insertion at a known position.

*Quote the JDK recommendation — it validates the preference without needing to quote benchmark numbers.*

> **Gotcha follow-up:** Does `ArrayDeque` allow null elements?
> No. `ArrayDeque` does not permit null elements because `null` is used as a sentinel value internally to detect an empty slot in the circular array. If you need a deque that holds null values, `LinkedList` does permit them — but this is an unusual requirement.

---

**Q5: What is the difference between fail-fast and fail-safe iterators?**
*Concept Check*

**One-line answer:** Fail-fast iterators throw `ConcurrentModificationException` if the collection is modified during iteration; fail-safe iterators use a snapshot or concurrent-safe view and never throw.

**Full answer:**
Fail-fast iterators are used by the non-concurrent collections: `ArrayList`, `HashMap`, `HashSet`, and others. Each collection maintains an internal modification counter called `modCount` that increments with every structural modification (add, remove, resize). When you create an iterator, it captures the current `modCount`. On every call to `next()`, the iterator compares its saved `expectedModCount` against the collection's current `modCount`. If they differ — meaning the collection was modified outside the iterator — it immediately throws `ConcurrentModificationException`. This is a defensive mechanism: rather than silently producing incorrect results (skipping elements, visiting elements twice), the iterator tells you immediately that something is wrong. Fail-safe iterators are used by concurrent collections: `ConcurrentHashMap`'s iterator uses a weakly-consistent traversal that reflects modifications made during iteration to the extent possible without throwing, and `CopyOnWriteArrayList`'s iterator iterates over a snapshot of the array taken at the time the iterator was created, so it never sees modifications made after creation. These iterators never throw, but they may not reflect the latest state of the collection. The choice of which to use depends on whether you need strong consistency guarantees during iteration or whether eventual consistency is acceptable.

*Name both `ConcurrentHashMap` and `CopyOnWriteArrayList` as fail-safe examples — they illustrate two different mechanisms.*

> **Gotcha follow-up:** How do you safely remove elements from a collection while iterating?
> Use `Iterator.remove()`, which is the only safe way to remove the current element during iteration with a fail-fast iterator. It removes the element and updates `expectedModCount` to match the new `modCount`, so no `ConcurrentModificationException` is thrown. In Java 8+, `Collection.removeIf(predicate)` is a cleaner alternative for bulk conditional removal.

---

**Q6: What is the difference between `Comparable` and `Comparator`?**
*Tradeoff Question*

**One-line answer:** `Comparable` defines a class's natural sort order within the class itself; `Comparator` defines an external, substitutable ordering without modifying the class.

**Full answer:**
`Comparable<T>` is an interface that a class implements to define its own natural ordering. It has one method: `int compareTo(T other)`, which returns a negative number if `this < other`, zero if equal, and positive if `this > other`. A class can only have one natural order — you choose it when you implement `Comparable`. `String`'s natural order is lexicographic; `Integer`'s is numeric. `Comparator<T>` is a separate object that encapsulates a comparison strategy. Because it is external to the class being sorted, you can define as many as you need without modifying the class. Java 8 dramatically improved `Comparator` ergonomics with static factory methods: `Comparator.comparing(Person::getLastName)` creates a comparator by last name; `.thenComparing(Person::getFirstName)` chains a secondary sort criterion; `.reversed()` flips the order. These can be chained into complex multi-level sort specifications with no boilerplate. The practical rule: implement `Comparable` in a class when there is one obvious, canonical ordering (numbers, dates, strings). Use `Comparator` when you need to sort by different attributes in different contexts, when the class is third-party and you cannot modify it, or when you want to pass a sort strategy as a parameter.

*Show the Java 8 fluent `Comparator` API — interviewers appreciate knowing the modern idiom.*

> **Gotcha follow-up:** What happens if `compareTo()` is inconsistent with `equals()`?
> The general contract says that `a.compareTo(b) == 0` should imply `a.equals(b)`. If this is violated, sorted collections like `TreeSet` behave unexpectedly: `TreeSet` uses `compareTo()` for all membership tests (including `contains()` and `remove()`), not `equals()`. An element that is `compareTo == 0` but `!equals` will be treated as a duplicate and not added; an element that is `equals` but `compareTo != 0` may appear to be absent. `BigDecimal` is the famous example: `new BigDecimal("1.0").equals(new BigDecimal("1.00"))` is `false` (different scales), but `compareTo` returns 0 (same numeric value), which causes confusing behaviour in `TreeSet` and `TreeMap`.

---

**Q7: How does `PriorityQueue` work and what are its ordering gotchas?**
*Concept Check*

**One-line answer:** `PriorityQueue` is a min-heap — `poll()` always returns the smallest element — but iterating it does not give elements in sorted order.

**Full answer:**
A `PriorityQueue` is internally backed by a binary min-heap stored in an array. In a min-heap, the element at the root (index 0) is always the smallest, and every parent node is smaller than or equal to its two children. `offer()` (adding an element) and `poll()` (removing and returning the smallest element) both maintain the heap property and run in O(log n) time by "sifting" the new element up or down the tree as needed. `peek()` returns the root element without removing it in O(1). When you construct a `PriorityQueue` with no arguments, it uses natural ordering (the elements must implement `Comparable`). For a max-heap — where `poll()` returns the largest element — pass `Comparator.reverseOrder()` to the constructor. The critical gotcha: iterating a `PriorityQueue` with a for-each loop visits elements in the internal array order, which is not sorted. The heap property only guarantees the relationship between parents and children, not a total sort across all elements. The only way to extract elements in priority order is to repeatedly call `poll()` until the queue is empty.

*State the array-based heap structure — it explains why iteration is not sorted.*

> **Gotcha follow-up:** What is the time complexity of building a `PriorityQueue` from a collection?
> `new PriorityQueue<>(collection)` uses the heapify algorithm, which runs in O(n) time — it is faster than inserting n elements one by one (which would be O(n log n)) because heapify builds the heap bottom-up, sifting each element down at most once.

---

**Q8: When should you use `EnumMap`?**
*Concept Check*

**One-line answer:** Use `EnumMap` whenever your map keys are enum values — it is faster and more memory-efficient than `HashMap` because it uses a plain array indexed by enum ordinal.

**Full answer:**
Every Java enum constant has an ordinal — an integer assigned automatically based on its position in the enum declaration, starting at 0. `EnumMap` exploits this by using a plain `Object[]` array of exactly the size of the enum (the number of constants). To store or retrieve a value, `EnumMap` uses the key's ordinal as the array index — a single array access with no hashing, no bucket lookup, no collision handling. This makes all operations O(1) with extremely small constants. Memory usage is minimal: there is one array slot per enum constant regardless of how many entries the map holds (null means absent). Iteration order is always the enum declaration order, which is predictable. Contrast this with `HashMap<MyEnum, V>`: each entry involves a `Node` object, a hash computation, a bucket lookup, and the overhead of the generic `HashMap` structure. `EnumMap` is always the right choice when you know your keys will be a specific enum type.

*Give the ordinal-indexed-array explanation — it shows you understand why `EnumMap` is fast, not just that it is.*

> **Gotcha follow-up:** Does `EnumMap` allow null values?
> Yes, `EnumMap` allows null values (you can store null as the value for a key). It does not allow null keys — a null key would have no ordinal, so the array index could not be computed.

---

**Q9: What is `IdentityHashMap` and when would you use it?**
*Concept Check*

**One-line answer:** `IdentityHashMap` uses reference equality (`==`) instead of `.equals()` for key comparison — two distinct objects with equal values are treated as different keys.

**Full answer:**
In a standard `HashMap`, two keys are considered equal if `key1.equals(key2)` returns true, and their bucket is found using `key1.hashCode()`. `IdentityHashMap` breaks both of these rules. Key equality is determined by `==` (reference identity — are they literally the same object?), and the hash is computed using `System.identityHashCode(key)`, which returns a hash based on the object's memory address (or a stable approximation of it), ignoring any overridden `hashCode()`. This means two distinct objects that are logically equal — for example, two `String` objects both containing "hello" — will be treated as two completely separate keys in an `IdentityHashMap`. The use cases are specialised: object graph serialisation (where you need to track which exact objects you have already serialised, not whether you have serialised an equal object); cycle detection in graph algorithms; canonicalisation passes in compilers or bytecode processors (mapping original AST nodes to transformed nodes by identity); or any context where object identity matters more than logical value equality.

*Give at least one concrete use case — identity-based maps are not a commonly encountered type, so context helps.*

> **Gotcha follow-up:** What is the performance characteristic of `IdentityHashMap`?
> `IdentityHashMap` uses open addressing (linear probing) instead of chaining, which means collisions are resolved by probing the next slot in the same array rather than building a linked list. This makes it more cache-friendly but more sensitive to load factor. The default capacity and load factor are tuned for identity-based workloads.

---

**Q10: What is `WeakHashMap` and what problem does it solve?**
*Concept Check*

**One-line answer:** `WeakHashMap` holds keys by weak references, so entries are automatically removed when their key is garbage-collected — useful for caches that should not prevent GC of their keys.

**Full answer:**
In a standard `HashMap`, the map holds a strong reference to every key. As long as the entry is in the map, the key object cannot be garbage-collected — the map is keeping it alive. In some caching scenarios, this is the wrong behaviour: you want to store metadata associated with objects, but the cache should not be the reason those objects stay in memory. `WeakHashMap` solves this by wrapping each key in a `WeakReference` — a reference type that the garbage collector is allowed to break. If no strong reference to the key object exists anywhere else in the program, the GC can collect the key even though the `WeakHashMap` holds a weak reference to it. After the GC collects the key, the corresponding map entry is cleaned up (via a `ReferenceQueue` that `WeakHashMap` polls on each operation). A practical example: a component that needs to attach display metadata to arbitrary user objects without modifying those objects and without leaking memory when the user objects are no longer needed. A `WeakHashMap` is the correct tool. The caveat: `String` literals are in the String Pool and are never garbage-collected during normal operation, so using interned strings as `WeakHashMap` keys means those entries are effectively permanent.

*Mention the `String` literal gotcha — it is a subtle practical trap.*

> **Gotcha follow-up:** Is `WeakHashMap` thread-safe?
> No. Like `HashMap`, `WeakHashMap` is not synchronised. Under concurrent access, you need external synchronisation. However, note that `ConcurrentHashMap` does not have a weak-key variant in the JDK — for a concurrent weak-key map, you would use `Collections.synchronizedMap(new WeakHashMap<>())` or a library like Guava's `CacheBuilder`.

---

**Q11: What is the difference between `Collections.unmodifiableList()` and `List.of()`?**
*Tradeoff Question*

**One-line answer:** `unmodifiableList()` is a read-only view over an existing mutable list; `List.of()` creates a truly immutable list with no connection to any underlying mutable state.

**Full answer:**
`Collections.unmodifiableList(originalList)` returns a wrapper that delegates all read operations to `originalList` and throws `UnsupportedOperationException` on any mutation attempt (`add()`, `remove()`, `set()`). However, the wrapper is only a view — it is not a copy. Whoever holds a reference to `originalList` can still call `originalList.add("surprise")`, and that change is immediately visible through the wrapper. This is a common source of bugs: you return `Collections.unmodifiableList(internalList)` from a method thinking you have protected your internal state, but the caller can cast it back or you inadvertently mutate `internalList` elsewhere. `List.of(...)` (introduced in Java 9) creates a genuinely immutable list. It is not backed by any mutable list; it contains exactly the elements passed to the factory method and will never change. It also disallows `null` elements (throws `NullPointerException`) and is typically more memory-efficient than a `Collections.unmodifiableList` wrapper. `List.copyOf(collection)` (Java 10) creates an immutable deep copy of an existing collection — unlike `unmodifiableList`, it is independent of the source and immune to mutations of the original.

*The "wrapper vs. independent copy" distinction is the core of this answer — make it explicit.*

> **Gotcha follow-up:** Can you sort a `List.of()` list using `Collections.sort()`?
> No. `Collections.sort()` calls `set()` on the list to swap elements, which throws `UnsupportedOperationException` for both `List.of()` and `Collections.unmodifiableList()`. To sort, copy the contents into a new `ArrayList`, sort that, and if you need an immutable result, wrap it with `List.copyOf()`.

---

**Q12: Why does `HashMap` allow `null` keys but `ConcurrentHashMap` does not?**
*Concept Check*

**One-line answer:** `ConcurrentHashMap` disallows `null` to eliminate an inherent ambiguity: a `null` return from `get()` cannot safely indicate "absent" vs "stored null" without a separate non-atomic `containsKey()` call.

**Full answer:**
`HashMap` allows one `null` key by special-casing it to bucket index 0. This works safely in a single-threaded context because if `map.get(key)` returns `null`, you can immediately follow up with `map.containsKey(key)` to distinguish "the key maps to null" from "the key is absent" — and in a single-threaded environment, no other thread can change the map state between your two calls. In a concurrent context, this two-step disambiguation is broken. Between the `get()` call that returns `null` and the `containsKey()` call that should clarify the meaning, another thread could add or remove the key. The state you observe in `containsKey()` may not reflect the state that caused `get()` to return `null`. Because `ConcurrentHashMap` is designed so that every individual operation is safe to use atomically in a concurrent environment, storing `null` values would introduce an operation — "is this null because absent or because stored null?" — that inherently requires two steps and cannot be made atomic. The designers chose to make `null` illegal for both keys and values, so that `get()` returning `null` unambiguously means the key is absent.

*Frame the answer in terms of atomicity — that is the actual reason, not just "the designers decided not to."*

> **Gotcha follow-up:** How do you store a "nullable" value in a `ConcurrentHashMap`?**
> Use `Optional<V>` as the value type: `ConcurrentHashMap<K, Optional<V>>`. `Optional.empty()` represents a stored-null and `Optional.of(v)` wraps a real value. `get()` returning `null` still unambiguously means absent; `Optional.empty()` means "present, but the actual value is null."

---

**Q13: When would you use `ArrayList` vs `LinkedList`?**
*Tradeoff Question*

**One-line answer:** Use `ArrayList` for almost everything; use `LinkedList` only when you have a proven need for O(1) insertions at positions you already hold an iterator to.

**Full answer:**
`ArrayList` is backed by a contiguous `Object[]` array. Random access by index is O(1) — the JVM computes the memory offset as `base + index * element_size` with no traversal. Iteration is cache-friendly because elements are stored adjacently in memory. Inserting or removing in the middle requires shifting all subsequent elements one position — O(n) — but in practice modern CPUs perform array shifts extremely fast using memory move instructions (`System.arraycopy` under the hood). `LinkedList` is a doubly-linked chain of `Node` objects where each node stores the element, a pointer to the previous node, and a pointer to the next. Access by index is O(n) — you must traverse from the head or tail. Add/remove at the head or tail is O(1), and add/remove at a known `ListIterator` position is also O(1). However, because nodes are scattered in memory (allocated at different times), traversal causes many CPU cache misses, which is slower in practice than the theoretical O(n) equivalence would suggest. Measured benchmarks consistently show `ArrayList` winning even for use cases that appear to favour `LinkedList`, such as frequent insertion at the beginning, because cache efficiency dominates at typical list sizes (< ~1 million elements). Use `LinkedList` only when you have profiled your application and confirmed that the cache-miss cost of `ArrayList` is not the bottleneck, and you genuinely need the O(1) iterator-based insertion.

*Make the "measured benchmarks" point — interviewers appreciate knowing that big-O theory does not always predict real performance.*

> **Gotcha follow-up:** `LinkedList` implements both `List` and `Deque`. When is that useful?
> When you need an object that can serve as both a list (with index-based access) and a double-ended queue (with efficient add/remove at both ends), `LinkedList` is the only standard JDK class that satisfies both interfaces. In practice, this need is rare — if you only need the deque behaviour, `ArrayDeque` is faster.

---

**Q14: Describe the main `Set` implementations and when to use each.**
*Concept Check*

**One-line answer:** `HashSet` for general-purpose O(1) sets, `LinkedHashSet` for insertion-ordered sets, `TreeSet` for sorted sets, `EnumSet` for enum-typed elements, and `CopyOnWriteArraySet` for read-heavy concurrent sets.

**Full answer:**
`HashSet` is backed by a `HashMap` where the set elements are the keys and a shared dummy object is the value. `add()`, `contains()`, and `remove()` are O(1) on average with no guaranteed order. This is the right default for any set where you just need membership testing without caring about order. `LinkedHashSet` extends `HashSet` with an insertion-order doubly-linked list — the same enhancement as `LinkedHashMap` over `HashMap`. Iteration order is predictable (insertion order), with a small overhead for maintaining the list. Use it when you need deterministic iteration, for example when generating output that should be stable across runs. `TreeSet` is backed by a `TreeMap` (Red-Black Tree) and stores elements in sorted order. All operations are O(log n). It implements `NavigableSet`, giving you `headSet(toElement)` (all elements less than), `tailSet(fromElement)` (all elements greater than or equal to), `floor(e)`, and `ceiling(e)`. Use it when you need to iterate in sorted order or perform range queries. `EnumSet` represents a set of enum constants as a bit vector — each enum constant's ordinal maps to one bit. All operations are O(1) and the implementation is extremely compact and fast. Always use `EnumSet` instead of `HashSet<MyEnum>`. `CopyOnWriteArraySet` is backed by a `CopyOnWriteArrayList` — every write operation copies the entire backing array. This makes writes expensive (O(n)) but reads completely lock-free. Use only for small sets that are read very frequently and written very rarely, such as a set of event listeners.

*Give the backing structure for each — it shows you understand the implementation, not just the name.*

> **Gotcha follow-up:** What is the difference between `Set.of()` and `new HashSet<>()`?
> `Set.of(a, b, c)` creates an immutable set of exactly those elements — no nulls allowed, no duplicates allowed (throws `IllegalArgumentException` at creation time if duplicates are passed), and iteration order is unspecified. `new HashSet<>()` creates a mutable set backed by a `HashMap`. Use `Set.of()` for fixed sets of constants; use `new HashSet<>()` when you need to add or remove elements after creation.

---

**Q15: How should you pre-size a `HashMap` to avoid resize operations?**
*Design Scenario*

**One-line answer:** Use `new HashMap<>(expectedSize / 0.75 + 1)` to set the initial capacity high enough that no resize occurs before all expected entries are added.

**Full answer:**
A `HashMap` resize happens when the number of entries exceeds `capacity * loadFactor`. With the default capacity of 16 and load factor of 0.75, the first resize triggers at 12 entries, doubling capacity to 32. For a map that will hold 1,000 entries, the default triggers 6 resize operations (12 → 24 → 48 → 96 → 192 → 384 → 768 entries worth of capacity, needing one more resize at 768 to reach 1024). Each resize is O(n): every entry must be rehashed and redistributed into the new array. The formula for the initial capacity that avoids any resize: `Math.ceil(expectedSize / loadFactor) + 1`, which for 1,000 entries gives `ceil(1000 / 0.75) + 1 = 1334`. Passing 1334 as the initial capacity means the threshold is `1334 * 0.75 = 1000.5`, so all 1,000 entries fit without triggering a resize. Guava's `Maps.newHashMapWithExpectedSize(n)` encapsulates this formula. This pre-sizing matters most when building a map in a tight loop with a known entry count — the saved resize operations add up significantly for large maps.

*Give the concrete formula and an example calculation — vague advice to "pre-size" is less useful than a specific number.*

> **Gotcha follow-up:** Does pre-sizing a `HashMap` affect its time complexity?
> No — time complexity is O(1) amortised regardless of capacity, as long as the hash function distributes keys reasonably. Pre-sizing affects the constant factor by eliminating O(n) resize operations and reducing collision rates (fewer entries per bucket at the same load factor). It is a practical performance tuning, not a change in algorithmic complexity.

---

**Common Mistakes:**
- **Using `HashMap` in multi-threaded code without synchronisation** → structural modifications cause race conditions and can corrupt the internal state; use `ConcurrentHashMap`.
- **Relying on iteration order from `HashMap`** → `HashMap` makes no ordering guarantee; use `LinkedHashMap` for insertion order or `TreeMap` for sorted order.
- **Forgetting that `PriorityQueue` iteration is not sorted** → only `poll()` extracts in priority order; a for-each loop visits the internal array in arbitrary order.
- **Using `List.remove(int)` vs `List.remove(Object)` confusion** → `list.remove(1)` removes by index; `list.remove(Integer.valueOf(1))` removes by value; with autoboxing, passing a literal int always calls the index version.
- **Not pre-sizing a `HashMap` when the expected size is known** → unnecessary resize operations waste time; use `expectedSize / 0.75 + 1` as the initial capacity.

**Quick Revision:** `HashMap` = array of buckets with linked lists (or trees at 8+ entries); `ConcurrentHashMap` = lock-free reads, per-bucket writes; `LinkedHashMap` = insertion order; `TreeMap` = sorted; `EnumSet` = bit vector — fastest set for enums.

---

## Section 4: Java 8+

> *Reading guide: focus on the lazy evaluation model of streams and the semantic distinction between each paired concept — `map` vs `flatMap`, `thenApply` vs `thenCompose`, `orElse` vs `orElseGet` all follow the same pattern.*

**Q1: How do lambdas differ from anonymous inner classes?**
*Concept Check*

**One-line answer:** Lambdas are compiled to `invokedynamic` bytecode with no separate `.class` file and capture `this` from the enclosing class; anonymous classes compile to a separate `.class` file with their own `this`.

**Full answer:**
An anonymous inner class is a full class definition written inline — the compiler generates a separate `.class` file (named `OuterClass$1.class` or similar), and the JVM creates an instance of that class. It has its own `this` reference pointing to the anonymous class instance, and it can declare fields and additional methods. A lambda, by contrast, is compiled using the `invokedynamic` bytecode instruction, which was introduced in Java 7 to support dynamic languages. `invokedynamic` defers the decision of how to implement the lambda to the JVM at startup time via `LambdaMetafactory`. The JVM typically generates a lightweight class internally without creating a separate `.class` file that ships in your JAR. This makes lambda creation faster and reduces the size of compiled JAR files. Inside a lambda, `this` refers to the enclosing class instance — not the lambda itself — because a lambda has no `this` of its own. Lambdas can only be used where the target type is a functional interface — an interface with exactly one abstract method (for example, `Runnable` with `run()`, `Comparator<T>` with `compare()`, `Predicate<T>` with `test()`). The `@FunctionalInterface` annotation marks such interfaces and causes a compile error if the interface accidentally gains a second abstract method.

*Mention `invokedynamic` and `LambdaMetafactory` by name — these show JVM-level understanding.*

> **Gotcha follow-up:** Can a lambda capture local variables from the enclosing scope?
> Yes, but only variables that are effectively final — either declared `final` or never reassigned after their initial assignment. This restriction exists because the lambda may be executed on a different thread or at a later time; if the captured variable could change after the lambda captures it, the lambda would have an inconsistent view of the variable. The compiler enforces this: assigning to a variable after it has been captured by a lambda causes a compile error.

---

**Q2: What are the four types of method references?**
*Concept Check*

**One-line answer:** Static method, unbound instance method (instance from stream element), bound instance method (instance captured at creation), and constructor reference.

**Full answer:**
A method reference is syntactic shorthand for a lambda that does nothing but invoke an existing method. All four types compile to the same `invokedynamic` mechanism as lambdas. The first type is a reference to a static method: `Integer::parseInt` is equivalent to the lambda `x -> Integer.parseInt(x)` — the class name comes before `::` and no instance is involved. The second type is an unbound instance method reference: `String::toUpperCase` is equivalent to `s -> s.toUpperCase()` — the instance to call the method on is not fixed at the point of reference creation; it comes from the first argument when the method reference is invoked (for example, as the stream element in `stream.map(String::toUpperCase)`). The third type is a bound instance method reference: `str::contains` where `str` is a specific `String` variable is equivalent to `x -> str.contains(x)` — the instance is fixed ("bound") at the point of reference creation and captured as a closure variable. The fourth type is a constructor reference: `ArrayList::new` is equivalent to `() -> new ArrayList<>()`, or `Person::new` might match `name -> new Person(name)` depending on the functional interface's signature. The JVM infers which constructor to use from the functional interface's method signature.

*Walk through all four with a concrete example for each — completeness is the mark of a thorough answer.*

> **Gotcha follow-up:** Is `System.out::println` a bound or unbound method reference?
> It is a bound instance method reference — `System.out` is a specific `PrintStream` instance that is captured when the reference is written. The equivalent lambda is `x -> System.out.println(x)`. If `System.out` changes later (via `System.setOut()`), the method reference still calls `println` on the original `PrintStream` that was captured, not the new one.

---

**Q3: How does lazy evaluation work in Java Streams?**
*Concept Check*

**One-line answer:** Intermediate stream operations build a pipeline description but execute no code; the pipeline runs only when a terminal operation is called, and short-circuit terminals stop early.

**Full answer:**
When you call `stream.filter(predicate)`, Java does not immediately scan any elements. Instead, it records the `filter` operation in a pipeline object — think of it as a recipe that has been written down but not yet cooked. The same is true for `map()`, `sorted()`, `distinct()`, and all other intermediate operations: each one extends the pipeline recipe and returns a new `Stream` object. The computation starts only when a terminal operation is invoked. Terminal operations are the trigger that says "now execute the recipe." For a terminal like `collect()` or `forEach()`, the pipeline processes each element through all intermediate stages one at a time: element 1 goes through `filter`, then `map`, then the collector; then element 2; and so on — this is a single pass through the data, not three separate passes. For short-circuit terminals like `findFirst()`, `anyMatch()`, or `limit(n)`, the pipeline can stop as soon as the condition is satisfied. A pipeline like `stream.filter(expensive).map(transform).findFirst()` will stop calling `filter` and `map` the moment one matching element has been processed — it does not need to visit the rest of the stream. This laziness is particularly valuable when the stream source is a database query, a network connection, or any other expensive resource.

*The "single pass vs. three passes" point is commonly misunderstood — make it explicit.*

> **Gotcha follow-up:** Can you reuse a stream after calling a terminal operation?
> No. Once a terminal operation has been called, the stream is considered consumed. Any attempt to call another operation on it — intermediate or terminal — throws `IllegalStateException: stream has already been operated upon or closed`. If you need to process the same data twice, re-create the stream from its source, or collect the results into a `List` first and operate on that.

---

**Q4: What is the distinction between intermediate and terminal stream operations?**
*Concept Check*

**One-line answer:** Intermediate operations return a `Stream` and are lazy; terminal operations consume the stream, trigger execution, and produce a result or side effect.

**Full answer:**
Every stream operation falls into one of two categories. Intermediate operations return a new `Stream<T>` and are evaluated lazily — calling them records an operation in the pipeline but does not process any elements. The complete list of standard intermediate operations includes: `filter(predicate)` to keep matching elements, `map(function)` to transform each element, `flatMap(function)` to transform and flatten, `distinct()` to remove duplicates, `sorted()` to order elements, `sorted(comparator)` to order by a custom rule, `limit(n)` to cap the count, `skip(n)` to discard the first n elements, and `peek(consumer)` to inspect elements for debugging without modifying them. Terminal operations consume the stream, trigger the entire pipeline to execute, and produce either a result or a side effect. Examples: `collect(collector)` accumulates elements into a container, `forEach(consumer)` performs an action on each element, `reduce(identity, accumulator)` folds elements into a single value, `count()` returns the number of elements, `findFirst()` and `findAny()` return an `Optional<T>` with a matching element, `anyMatch()`, `allMatch()`, and `noneMatch()` test predicates, `toList()` (Java 16) creates an immutable list. Once a terminal operation completes, the stream is closed and cannot be reused.

*Enumerate the full list of intermediate operations — completeness here signals that you work with streams regularly.*

> **Gotcha follow-up:** What does `peek()` do and when should you use it?
> `peek()` is an intermediate operation that calls a consumer on each element as it passes through the pipeline, then passes the element to the next stage unchanged. It is designed for debugging: you can `peek(System.out::println)` at any stage to see what elements look like at that point in the pipeline without modifying them. Do not use `peek()` to perform side effects in production code — because of stream laziness and short-circuiting, `peek()` may not be called on all elements (for example, with `findFirst()`), leading to incomplete side effects.

---

**Q5: What is the difference between `map()` and `flatMap()` in streams?**
*Concept Check*

**One-line answer:** `map()` transforms each element one-to-one; `flatMap()` transforms each element into zero or more elements and flattens all results into a single stream.

**Full answer:**
`map(function)` applies the function to each element and produces exactly one output element per input element — a one-to-one transformation. The result is a `Stream<R>` where `R` is the return type of the function. `flatMap(function)` requires the function to return a `Stream<R>` for each element, and then flattens all those streams into a single `Stream<R>` — as if you concatenated all the individual streams together. Without `flatMap`, applying a function that returns a stream to each element would give you `Stream<Stream<R>>`, a nested stream that you would have to unwrap manually. `flatMap` does the unwrapping automatically. The clearest example: you have a `List<String>` of sentences, and you want a `Stream<String>` of all individual words. Each sentence maps to a stream of its words: `sentence -> Arrays.stream(sentence.split(" "))`. With `map()`, you get `Stream<Stream<String>>` — a stream of word-streams. With `flatMap()`, you get `Stream<String>` — all words from all sentences in a single stream. `flatMap` also handles the zero-elements case naturally: if the function returns an empty stream for some input, those inputs contribute nothing to the output, effectively filtering them out.

*The "what goes wrong with `map` when the function returns a stream" explanation is the crux — walk through it.*

> **Gotcha follow-up:** What does `flatMap` do when applied to an `Optional`?
> `Optional.flatMap(function)` is analogous but for optionals. If the `Optional` is empty, it returns `Optional.empty()`. If it is present, it applies the function (which must return another `Optional`) and returns that result — without the extra wrapping layer you would get with `Optional.map()`. For example, `Optional.of(user).flatMap(User::findAddress).flatMap(Address::getCity)` chains nullable lookups without nesting `Optional<Optional<...>>`.

---

**Q6: What is the difference between `Optional.orElse()` and `Optional.orElseGet()`?**
*Tradeoff Question*

**One-line answer:** `orElse(value)` always evaluates its argument; `orElseGet(supplier)` evaluates the supplier only when the `Optional` is empty.

**Full answer:**
`Optional<T>.orElse(T other)` takes a value that is evaluated eagerly — the Java expression passed as `other` is evaluated before `orElse` is even called, regardless of whether the `Optional` is present or empty. If the default value is a constant like `orElse("")` or `orElse(0)`, this is fine — evaluating a constant is free. The problem arises when the default involves a method call: `orElse(expensiveQuery())` calls `expensiveQuery()` every single time, even when the `Optional` is present and the result will be thrown away. `Optional.orElseGet(Supplier<T> supplier)` is lazy: it only calls the supplier if the `Optional` is actually empty. The supplier is a functional interface — typically a lambda or method reference — so `orElseGet(() -> expensiveQuery())` calls `expensiveQuery()` only when needed. The performance difference can be dramatic in a tight loop: if the `Optional` is non-empty 99% of the time, `orElse(expensiveQuery())` calls the expensive method on every iteration, while `orElseGet(() -> expensiveQuery())` calls it only on the 1% of iterations where it is actually needed.

*Quantify the cost with a percentage scenario — it makes the tradeoff tangible.*

> **Gotcha follow-up:** What is the difference between `orElse(null)` and `orElseGet(() -> null)`?
> Behaviourally they are identical when the `Optional` is empty — both return `null`. The difference is purely about evaluation eagerness: `orElse(null)` evaluates the argument `null` (which is trivial) unconditionally; `orElseGet(() -> null)` calls the supplier only when empty. For `null` specifically there is no practical difference. Where the lazy vs. eager distinction matters is for non-trivial expressions.

---

**Q7: What is the difference between `CompletableFuture.thenApply()` and `thenCompose()`?**
*Concept Check*

**One-line answer:** `thenApply()` wraps the function's return value in a new `CompletableFuture`; `thenCompose()` uses the function's returned `CompletableFuture` directly, avoiding nesting.

**Full answer:**
`CompletableFuture<T>.thenApply(Function<T, U> function)` is analogous to `Stream.map()`. The function takes the result value `T` of the current future and returns a plain value `U`. `thenApply` wraps that `U` into a new `CompletableFuture<U>` automatically. `CompletableFuture<T>.thenCompose(Function<T, CompletableFuture<U>> function)` is analogous to `Stream.flatMap()`. The function takes the result `T` and returns a `CompletableFuture<U>` — the function already returns a future. `thenCompose` uses that future directly, without wrapping it again, so the result is `CompletableFuture<U>`. Without `thenCompose`, if you used `thenApply` with a function that returns a `CompletableFuture<U>`, you would get `CompletableFuture<CompletableFuture<U>>` — a nested future that you would have to unwrap with an extra `join()` call. The practical rule: if your async callback calls another async method and returns its future, use `thenCompose`. If your callback performs a synchronous transformation and returns a plain value, use `thenApply`. For example: `fetchUser(id).thenCompose(user -> fetchOrders(user.getId()))` — `fetchOrders` returns a future, so `thenCompose` is correct. `fetchUser(id).thenApply(User::getName)` — `getName()` returns a `String`, so `thenApply` is correct.

*Give one concrete example for each — the abstraction is clearer with a name substituted in.*

> **Gotcha follow-up:** What is `thenCombine()` used for?
> `thenCombine(other, biFunction)` runs two independent `CompletableFuture`s in parallel and combines their results when both complete. Unlike `thenCompose()` (which chains sequentially — the second future depends on the first's result), `thenCombine()` starts both futures immediately and merges the results. Use it when two async operations are independent and you want to minimise total latency.

---

**Q8: What are the main pitfalls of parallel streams?**
*Tradeoff Question*

**One-line answer:** Parallel streams cause data races on shared mutable state, have overhead that exceeds the gain for small datasets, and can starve `ForkJoinPool.commonPool()` with blocking I/O.

**Full answer:**
There are five main pitfalls to know. First, shared mutable state causes race conditions: if a parallel stream's `forEach()` or `peek()` writes to an external list, counter, or map without synchronisation, multiple threads update it simultaneously, producing corrupted results. The fix is to use `collect()` or `reduce()`, which are designed for safe parallel aggregation. Second, small datasets see no speedup: splitting work across the `ForkJoinPool`, scheduling threads, and merging partial results has a fixed overhead cost. For collections smaller than a few thousand elements, this overhead typically exceeds the savings from parallelism, making parallel streams slower than sequential. Third, ordered operations serialise parallelism: operations like `sorted()` and `findFirst()` require ordering guarantees that force synchronisation points, reducing throughput. If order does not matter, use `findAny()` instead of `findFirst()`. Fourth, I/O-bound work blocks CPU threads: parallel streams use CPU-bound `ForkJoinPool` threads — blocking them on network or disk I/O starves the pool for everyone. For I/O-bound parallelism, use `CompletableFuture` with a dedicated `ExecutorService` tuned for I/O (larger thread count). Fifth, `ForkJoinPool.commonPool()` is shared: parallel streams, `CompletableFuture.supplyAsync()` (without a custom executor), and other framework code all share one pool. A heavy parallel stream can starve other tasks competing for the same pool threads.

*Five pitfalls, stated clearly — this answer separates seniors from juniors on the parallel streams topic.*

> **Gotcha follow-up:** How do you run a parallel stream on a custom thread pool instead of `commonPool`?
> Wrap the stream operation inside a `ForkJoinPool` task: `new ForkJoinPool(4).submit(() -> list.parallelStream().map(...).collect(...)).get()`. This executes the parallel stream using a dedicated pool with 4 threads, isolating it from `commonPool`. In Java 21+, structured concurrency and virtual threads offer cleaner alternatives for I/O-bound parallel work.

---

**Q9: How does `Collectors.groupingBy()` work?**
*Concept Check*

**One-line answer:** `groupingBy` partitions a stream into a `Map<K, List<V>>` by a classifier function, with an optional downstream collector for further aggregation.

**Full answer:**
`Collectors.groupingBy(classifier)` applies the `classifier` function to each stream element and groups elements by the returned key into a `Map` where each value is a `List` of the elements that produced that key. This is the stream equivalent of SQL's `GROUP BY`. The downstream collector (the optional second argument) specifies what to do with each group's elements — the default is `Collectors.toList()`. You can substitute any `Collector` as the downstream: `Collectors.counting()` to count elements per group, `Collectors.summingInt(...)` to sum a numeric field, `Collectors.mapping(function, toList())` to transform elements before collecting, or even another `groupingBy` for a nested grouping. Here are three common patterns side by side:

```java
// Group employees by department → list of employees
Map<String, List<Employee>> byDept =
    employees.stream()
             .collect(Collectors.groupingBy(Employee::getDept));

// Group by department → count per department
Map<String, Long> countByDept =
    employees.stream()
             .collect(Collectors.groupingBy(
                 Employee::getDept, Collectors.counting()));

// Group by department → list of just names
Map<String, List<String>> namesByDept =
    employees.stream()
             .collect(Collectors.groupingBy(
                 Employee::getDept,
                 Collectors.mapping(Employee::getName, Collectors.toList())));
```

*Show all three code patterns — interviewers appreciate seeing the downstream collector in action.*

> **Gotcha follow-up:** What is `Collectors.partitioningBy()`?
> `partitioningBy(predicate)` is a special case of `groupingBy` where the key is always a `Boolean`. It partitions the stream into two groups — elements for which the predicate is `true` and elements for which it is `false` — and returns a `Map<Boolean, List<T>>`. It is slightly more efficient than `groupingBy` because it always produces exactly two groups.

---

**Q10: When should you use `reduce()` vs `collect()`?**
*Tradeoff Question*

**One-line answer:** Use `reduce()` for immutable aggregation into a single value; use `collect()` for mutable accumulation into containers like `List` or `Map`.

**Full answer:**
`reduce(identity, accumulator)` performs an immutable reduction: it combines elements into a single result value using a binary operator, without mutating any intermediate object. Each step produces a new immutable value: start with the identity (e.g., 0 for sum, 1 for product), combine it with the first element to get a new value, combine that with the second element, and so on. This is mathematically clean and works correctly in parallel (the parallel version requires an additional `combiner` argument to merge partial results from different threads). `collect(collector)` performs a mutable reduction: it creates a mutable result container (a `List`, `Map`, `StringBuilder`, or custom `Collector`), and accumulates elements into it by calling a mutating method (`add()`, `put()`, `append()`). The critical trap: never use `reduce` to build a collection. `stream.reduce(new ArrayList<>(), (acc, e) -> { acc.add(e); return acc; }, (a, b) -> { a.addAll(b); return a; })` looks plausible but is wrong in parallel execution — the same `ArrayList` is shared across threads, causing race conditions. Even in sequential mode, the accumulator creates a new list on every call to maintain the immutability contract, producing O(n) intermediate list allocations. The correct tool for building a list from a stream is `collect(Collectors.toList())`.

*The "why you must not use `reduce` to build a list" explanation is the key insight — dedicate two sentences to it.*

> **Gotcha follow-up:** What does `reduce()` return when the stream is empty?
> The version `reduce(T identity, BinaryOperator<T> accumulator)` returns the identity value when the stream is empty — for example, `stream.reduce(0, Integer::sum)` returns 0 for an empty stream. The version `reduce(BinaryOperator<T> accumulator)` without an identity returns `Optional<T>` — `Optional.empty()` for an empty stream — because there is no safe default to return.

---

**Q11: What is `var` (local type inference) and when should you use it?**
*Concept Check*

**One-line answer:** `var` tells the compiler to infer the local variable's type from the initialiser; the type is still fixed at compile time — Java remains statically typed.

**Full answer:**
`var` was introduced in Java 10 as part of JEP 286. When you write `var list = new ArrayList<String>()`, the compiler infers the type as `ArrayList<String>` — not `Object`, not `List<String>`, but the exact concrete type of the right-hand side expression. The variable is fully statically typed; `var` only tells the compiler "you figure out the type so I don't have to write it." This eliminates redundant repetition in declarations like `HashMap<String, List<Integer>> map = new HashMap<String, List<Integer>>()`, which can be rewritten as `var map = new HashMap<String, List<Integer>>()`. `var` has strict restrictions: it can only be used for local variables that have an initialiser (the compiler needs the RHS to infer the type), not for method parameters, return types, or fields. It cannot be used with `null` initialisers because `null` has no type to infer. The guideline for readability: use `var` when the type is obvious from the right-hand side and adding it would be redundant (`var reader = new BufferedReader(new FileReader(path))`). Avoid `var` when the type would be unclear to someone scanning the code quickly (`var result = processData(config)` — what type is `result`?).

*The "type is still fixed at compile time" clarification is essential — many candidates think `var` introduces dynamic typing.*

> **Gotcha follow-up:** Can `var` be used in lambda parameters?
> Yes, since Java 11. You can write `(var x, var y) -> x + y` in a lambda, which is equivalent to `(x, y) -> x + y`. The main motivation for allowing `var` in lambda parameters is that it lets you add annotations to inferred-type lambda parameters: `(@NotNull var x) -> x.length()` — you cannot annotate a plain inferred parameter without the type keyword.

---

**Q12: What are Java Records and when do you use them?**
*Concept Check*

**One-line answer:** Records are concise immutable data classes where the compiler auto-generates the constructor, accessors, `equals()`, `hashCode()`, and `toString()` from the declared components.

**Full answer:**
Before records, writing a simple data-holding class required boilerplate: a constructor, private final fields, accessor methods, `equals()`, `hashCode()`, and `toString()`. Records, introduced as a standard feature in Java 16 (JEP 395), express this concisely: `record Point(int x, int y) {}` declares a class with two components, `x` and `y`. The compiler automatically generates a canonical constructor that takes `int x` and `int y` as parameters; accessor methods named `x()` and `y()` (not `getX()` — records use the component name directly); `equals()` and `hashCode()` based on all components; and a `toString()` that produces `Point[x=3, y=4]`. Records are implicitly `final` — you cannot subclass them. All fields are `private final`. You can add your own static methods, instance methods, and implement interfaces. You can write a compact constructor (without the parameter list) to add validation or normalisation: `record Range(int lo, int hi) { Range { if (lo > hi) throw new IllegalArgumentException(); } }`. Use records for DTOs (Data Transfer Objects) in API layers, value objects in domain models, or any class whose primary purpose is to transparently hold a fixed set of values.

*Mention compact constructors for validation — it shows you know the full record feature set.*

> **Gotcha follow-up:** Can a record extend another class?
> No. Records implicitly extend `java.lang.Record` and are `final`, so they cannot extend any other class. They can implement any number of interfaces, but the inheritance hierarchy is fixed. This constraint is intentional: records are value-based types, and allowing arbitrary inheritance would undermine the guarantees about what a record contains.

---

**Q13: What are Sealed Classes and why are they useful?**
*Concept Check*

**One-line answer:** Sealed classes restrict which classes can extend them, giving the compiler a complete, closed set of subtypes that enables exhaustive pattern matching.

**Full answer:**
A sealed class or interface is declared with the `sealed` keyword and a `permits` clause listing every allowed subtype: `sealed interface Shape permits Circle, Rectangle, Triangle`. Any class not in the `permits` list is prevented from implementing `Shape` — the compiler enforces this. Each permitted subtype must be declared as one of three things: `final` (no further subclassing), `sealed` (itself restricted to a further `permits` list), or `non-sealed` (opened back up to unrestricted extension). The major benefit is exhaustive pattern matching. In a `switch` expression (Java 21+), if you switch on a `Shape` and handle `Circle`, `Rectangle`, and `Triangle`, the compiler knows those are all the possibilities — no `default` branch is needed. If you later add `Hexagon` to the `permits` list, the compiler immediately reports unhandled cases in every switch over `Shape`, forcing you to update all the code that needs to handle it. This makes sealed classes ideal for modelling algebraic data types — the functional programming concept of types with a fixed, known set of variants. Common applications: AST nodes in a compiler or parser, `Result<T>` types (`Success<T>` | `Failure`), HTTP response types, or state machines with a fixed set of states.

*Mention the algebraic data type concept — it connects sealed classes to functional programming, which senior engineers appreciate.*

> **Gotcha follow-up:** What is the difference between `sealed` and `final`?
> `final` on a class prevents any subclassing — the type hierarchy terminates there, and there are no subtypes at all. `sealed` allows subclassing, but only by the explicitly listed permitted subtypes — the hierarchy is closed and enumerated. `sealed` gives you the type hierarchy you want (multiple variants) while keeping it closed (no unexpected variants can appear).

---

**Q14: How does pattern matching `instanceof` work in Java 16+?**
*Concept Check*

**One-line answer:** `if (obj instanceof String s)` combines the type check and cast into one step, binding the matched value to `s` only within the true branch.

**Full answer:**
Before Java 16, testing and using a specific type required two separate steps: `if (obj instanceof String) { String s = (String) obj; s.length(); }`. The cast is redundant — you already checked the type — but the compiler still required it. Pattern matching `instanceof` (JEP 394, permanent in Java 16) collapses this into one declaration: `if (obj instanceof String s) { s.length(); }`. The variable `s` is a pattern variable: it is bound to the cast value only within the scope where the `instanceof` is known to be true. In `if (obj instanceof String s)`, `s` is in scope in the `true` branch and in any code that follows the `if` statement in a path where the `instanceof` must have been true (for example, `if (!(obj instanceof String s)) return; s.length()` — `s` is in scope after the early return). This scoping rule is called definite assignment by the type pattern. Java 21 extended this to `switch` statements and expressions: `switch (shape) { case Circle c -> Math.PI * c.radius() * c.radius(); case Rectangle r -> r.width() * r.height(); }`. Combined with sealed classes, `switch` can be exhaustive and require no `default` branch.

*Explain the definite assignment scoping rule — it is the subtlety that separates a thorough answer.*

> **Gotcha follow-up:** Can you use pattern variables in compound boolean conditions?
> Yes, with a restriction. In `if (obj instanceof String s && s.length() > 5)`, `s` is in scope in the right-hand side of `&&` because `&&` short-circuits — if `instanceof` is false, the right side is not evaluated, so `s` is only used when the cast succeeded. With `||`, the logic is opposite: `if (!(obj instanceof String s) || s.isEmpty())` — `s` is in scope in the right side because if the `!instanceof` is false (meaning `instanceof` was true), `s` is bound. The compiler enforces these flow-sensitive scoping rules automatically.

---

**Q15: What are Text Blocks and how does incidental whitespace stripping work?**
*Concept Check*

**One-line answer:** Text blocks are multi-line string literals delimited by `"""` that automatically strip the common leading indentation from all content lines.

**Full answer:**
Text blocks, made a permanent feature in Java 15 (JEP 378), address the awkwardness of embedding multi-line strings like JSON, SQL, or HTML in Java source code. A text block begins with `"""` followed by a newline (the opening `"""` must be followed by a newline — you cannot start content on the same line as the opening delimiter) and ends with a closing `"""`. All newlines in the content are included in the string as `\n`. Double quotes inside the content do not need to be escaped (unless you need three consecutive double quotes). The most important feature is incidental whitespace stripping: when you indent a text block to align with the surrounding code, the compiler measures the smallest indentation common to all non-blank content lines and strips exactly that amount from the beginning of every line. The position of the closing `"""` also affects this: if the closing `"""` is indented further left than the content, it sets a new minimum and more leading whitespace is stripped. You can use `\` at the end of a line (a line continuation escape) to suppress the newline for that line, and `\s` to force a trailing space to be preserved (normally trailing spaces are stripped). Text blocks are ideal for inline JSON payloads in tests, embedded SQL queries, HTML email templates, and any multi-line string literal that would otherwise require explicit `\n` and concatenation.

*Explain the closing `"""` position rule — it is the nuanced detail that interviewers probe.*

> **Gotcha follow-up:** Is there a performance difference between a text block and a regular `String` literal?
> No. The compiler processes text blocks at compile time and produces a standard `String` constant in the bytecode. A text block is syntactic sugar — at runtime, it is indistinguishable from a regular `String` literal. The incidental whitespace stripping and escape processing happen entirely at compile time.

---

**Common Mistakes:**
- **Using `orElse(expensiveCall())` instead of `orElseGet(() -> expensiveCall())`** → the expensive call runs every time, even when the `Optional` is present; always use `orElseGet` for non-trivial defaults.
- **Using `thenApply` when the function returns a `CompletableFuture`** → produces `CompletableFuture<CompletableFuture<T>>`; use `thenCompose` to flatten the nested future.
- **Modifying external state in a parallel stream's `forEach`** → causes race conditions; use `collect()` or `reduce()` for aggregation in parallel streams.
- **Calling a second terminal operation on a stream** → throws `IllegalStateException`; streams are single-use, re-create from the source if you need to process twice.
- **Using `reduce` to build a `List`** → creates O(n) intermediate list allocations; use `collect(Collectors.toList())`.

**Quick Revision:** Lambdas are `invokedynamic` with no own `this`; streams are lazy until a terminal fires; `flatMap` flattens, `thenCompose` flattens, `orElseGet` is lazy — the same "flatten / defer" pattern runs through all of Java 8+.

---

## Section 5: JVM Internals

> *Reading guide: These questions probe how the JVM manages memory and optimises code at runtime. Know the three memory areas by heart, understand why G1 is the default GC and when to switch to ZGC, and be able to walk through JIT tiers confidently. OOM message types are a favourite of senior-level interviewers.*

---

**Q1: What is the difference between the Heap, the Stack, and Metaspace in the JVM?**
*Concept Check*

**One-line answer:** Stack holds per-thread method frames, Heap holds all live objects, and Metaspace holds class structure metadata.

**Full answer:**
The Stack is a per-thread memory region that holds method frames — when you call a method, a new frame is pushed onto that thread's stack containing the method's local variables, an operand stack for intermediate arithmetic results, and the return address so execution can resume after the call returns. Frames are managed in LIFO order (last in, first out), and allocation is essentially free because it is just a pointer increment. If recursion goes too deep and frames exhaust the stack, the JVM throws a StackOverflowError. The Heap is the shared region where every object instance and every array lives, regardless of which thread created it. The garbage collector reclaims heap objects when they are no longer reachable; if the heap fills up before a GC can free enough space, you get OutOfMemoryError: Java heap space. Metaspace replaced the old PermGen in Java 8 and stores class metadata — that means the structural description of each class: its field names, method bytecode, constant pool entries, and static field values. Unlike PermGen which had a fixed ceiling and would cause OutOfMemoryError: PermGen space in older Java versions, Metaspace grows automatically up to a configurable cap set by -XX:MaxMetaspaceSize. The practical consequence is that each region has a different failure mode: deep recursion kills the stack, object accumulation kills the heap, and dynamic class generation (Groovy scripts, Spring proxies, reflection-heavy frameworks) can exhaust Metaspace.

*In an interview, draw three boxes side by side and label the failure mode under each — it shows you understand not just what they are but what breaks.*

> **Gotcha follow-up:** Where do static fields live after Java 8?
> Static fields moved from PermGen to the Heap in Java 8. They are stored as part of the Class object, which itself lives on the heap. Metaspace holds the class structure description, but the actual static field values are heap-allocated.

---

**Q2: How does G1 GC (Garbage-First) divide the heap, and why is that useful?**
*Concept Check*

**One-line answer:** G1 splits the heap into equal-sized regions and labels each one dynamically, so it can collect the highest-garbage regions first without a full heap pause.

**Full answer:**
Traditional generational collectors split the heap into fixed Young and Old spaces with hard boundaries. G1 (Garbage-First) takes a different approach: it divides the entire heap into a large number of equally-sized regions — typically around 2,048 regions of 1 to 32 MB each, where the size is always a power of two. At any moment each region carries a label: Eden (where new objects are allocated), Survivor (objects that survived at least one GC cycle), Old (long-lived objects promoted out of Survivor), or Humongous (objects larger than half a region's size, which get allocated directly in the Old generation to avoid oversizing a normal region). The key insight is that these labels are dynamic — a region that was Eden can become Old, then eventually be reclaimed and relabelled Eden again. This lets G1 perform concurrent marking alongside your running application to identify which regions have the most garbage, then prioritise collecting those during its "mixed collection" pauses — which is where the "Garbage-First" name comes from. You give G1 a pause time target with -XX:MaxGCPauseMillis=200, and G1 tries to select a collection set of regions that can be processed within that budget. This is a best-effort target, not a hard guarantee. G1 has been the default GC since Java 9 because it offers a good balance between throughput and pause times for most applications.

*Mention the ~2048 region count and the Humongous category — these signal you have actually used G1 in production tuning, not just read a summary.*

> **Gotcha follow-up:** What is a "mixed collection" in G1?
> A mixed collection is a GC pause that simultaneously collects all Young regions (Eden + Survivor) plus a selected subset of Old regions — specifically the Old regions G1 identified as highest-garbage during concurrent marking. This is different from a Young-only collection that only touches Young regions, and it is how G1 reclaims Old generation space without needing a full stop-the-world compaction.

---

**Q3: When would you choose ZGC over G1, and what makes ZGC able to achieve sub-millisecond pauses?**
*Tradeoff Question*

**One-line answer:** Use ZGC when GC pauses are causing latency spikes; it achieves near-zero pauses by running compaction concurrently using load barriers.

**Full answer:**
G1 runs its marking phase concurrently — meaning it identifies live and dead objects while your application is running — but it still does compaction (moving live objects together to eliminate fragmentation and reclaim contiguous space) during a stop-the-world pause. That pause is bounded but can reach 50–200 milliseconds on large heaps. ZGC, which became production-stable in Java 15, runs both marking AND compaction concurrently, which is why its stop-the-world pauses are typically under one millisecond even on heaps measured in terabytes. ZGC achieves concurrent compaction using a mechanism called load barriers: every time your application code reads an object reference from the heap, the JVM injects a tiny piece of barrier code that checks whether the object has been relocated by the concurrent compaction and, if so, atomically updates the reference to point at the new location. This means ZGC can move objects while your application threads are reading them — the threads just see the updated address transparently. The trade-off is roughly 15% higher CPU throughput cost compared to G1 under the same workload, because all those barrier checks add up. For most web services and batch jobs, G1 is the right default. Switch to ZGC when you have hard latency SLAs — financial trading systems, real-time APIs, gaming servers — where even a 100ms pause is unacceptable.

*The phrase "load barriers" is what separates a good answer from a great one here.*

> **Gotcha follow-up:** Does ZGC still have stop-the-world pauses at all?
> Yes, ZGC still has a handful of very brief stop-the-world pauses — root scanning at the start of a marking cycle and a few synchronisation points during the cycle. But these are measured in fractions of a millisecond and do not scale with heap size, which is the critical property. G1 pauses scale with the amount of live data being evacuated; ZGC pauses do not.

---

**Q4: Walk me through JIT compilation tiers in the HotSpot JVM.**
*Concept Check*

**One-line answer:** The JVM starts by interpreting bytecode, then progressively compiles hot methods through five tiers — from fast C1 compilation to highly-optimised C2 native code.

**Full answer:**
When the JVM starts, it runs in Tier 0: pure interpretation, where it reads and executes bytecode one instruction at a time without compiling anything to native machine code. This is slow but starts immediately with no warm-up cost. As methods are called repeatedly, the JVM's profiling subsystem tracks invocation counts and branch frequencies. Once a method crosses a threshold (around 2,000 invocations), it moves to Tier 1 or Tier 2: C1 compilation, where C1 is the "client compiler" — it compiles bytecode to native code quickly without spending much time on optimisation, so the application gets a speed boost fast. Tier 3 is still C1 but with profiling instrumentation added, collecting data about which branches are taken most often. Once enough profiling data accumulates (around 10,000 invocations total), the method is handed to Tier 4: the C2 compiler, also called the "server compiler." C2 takes longer to compile but produces highly optimised native code using techniques that require the profiling data to work well — method inlining (copying the body of a called method directly into the caller to eliminate the call overhead), loop unrolling (duplicating loop bodies to reduce branch instructions), escape analysis (determining whether an object is visible outside a method, enabling stack allocation), and dead code elimination (removing branches that profiling shows are never taken). This tiered approach means your application code gets progressively faster as it runs, with the most critical hot paths eventually running as optimised native machine code.

*The key term interviewers want to hear is "C1 vs C2" — that shows you know there are two distinct compilers at play.*

> **Gotcha follow-up:** What is deoptimisation, and when does it happen?
> Deoptimisation is when the JVM discards a JIT-compiled version of a method and falls back to interpreted or less-optimised code. It happens when a speculative optimisation is invalidated — for example, C2 might inline a virtual method call based on profiling that showed only one implementation was ever used. If a new subclass is loaded later that provides a different implementation, the assumption breaks and the JIT must deoptimise. Deoptimisation is a normal part of the JVM's operation and not a bug, but excessive deoptimisation can cause noticeable performance drops.

---

**Q5: What is escape analysis, and what optimisations does it enable?**
*Concept Check*

**One-line answer:** Escape analysis determines whether an object is visible outside its creating method; if not, the JVM can skip heap allocation entirely.

**Full answer:**
Every time you write `new SomeObject()` in Java, the default assumption is that the object goes onto the heap and must eventually be garbage collected. Escape analysis is a JIT compiler analysis that asks: does this object "escape" the method that created it? An object escapes if it is returned from the method, stored in a field that outlives the method, or passed to another thread. If the JIT can prove that the object does NOT escape — it is only used locally within the method — three optimisations become possible. First, stack allocation: the object can be allocated on the call stack instead of the heap, because when the method returns the frame is popped and the memory is reclaimed instantly with no GC involvement. Second, scalar replacement: if the object is only used locally, the JIT can eliminate the object entirely and just keep its fields as individual local variables — a `Point(x, y)` object becomes two int variables x and y in registers. Third, lock elision: if you synchronise on a locally created object that doesn't escape, the JIT can remove the lock entirely because no other thread can ever see that object, making the synchronisation redundant. Escape analysis is performed automatically by the C2 compiler for Tier 4 code and requires no annotations from you.

*Interviewers asking about escape analysis usually want to know if you understand that not all heap allocations actually reach the heap — this is a common micro-optimisation point.*

> **Gotcha follow-up:** Can you force escape analysis to kick in for a specific object?
> No, you cannot annotate an object to guarantee stack allocation — it is entirely at the JIT's discretion. You can help by keeping objects local (not storing them in fields, not passing them to other classes), but whether the JIT actually applies escape analysis depends on whether the method is hot enough to reach Tier 4 and whether the analysis succeeds. The JVM flag -XX:+DoEscapeAnalysis is on by default.

---

**Q6: Explain the class loader delegation model and why it matters for security.**
*Concept Check*

**One-line answer:** Class loaders delegate upward to their parent before searching their own classpath, ensuring core Java classes can never be replaced by application code.

**Full answer:**
When the JVM needs to load a class for the first time, it does not immediately search the application's classpath. Instead, it uses a parent-delegation model: the Application ClassLoader (which knows about your application's jars) first asks its parent, the Extension or Platform ClassLoader (which knows about Java platform extensions), to load the class. The Platform ClassLoader in turn asks its parent, the Bootstrap ClassLoader — the root of the hierarchy, baked into the JVM itself — which loads core Java classes from the JDK modules. Only if the Bootstrap ClassLoader says it cannot find the class does control return down to the Platform ClassLoader, and only if that fails does the Application ClassLoader search its own classpath. This parent-first approach is a security guarantee: it means you cannot ship a jar that contains a class named java.lang.String and have it replace the real one, because the Bootstrap ClassLoader will always find and load the real String first. The consequence for developers is that class identity in the JVM is defined not just by name but by the combination of fully-qualified name plus the class loader that loaded it — two classes with the same name loaded by different class loaders are distinct types that cannot be cast to each other. Some frameworks intentionally break parent delegation: OSGi (the plugin framework used in Eclipse) and Tomcat both use child-first loading to isolate plugin bundles or web applications from each other, preventing one application's libraries from conflicting with another's.

*The phrase "class identity = name + loader" is a nuance that seniors appreciate.*

> **Gotcha follow-up:** What happens when you load the same class through two different class loaders?
> You get two distinct Class objects in the JVM, even though the bytecode is identical. Instances of ClassA loaded by loader1 cannot be cast to ClassA loaded by loader2 — you get a ClassCastException. This is why frameworks like Tomcat must be careful about which class loader loads shared utilities versus application-specific classes.

---

**Q7: What are the different types of OutOfMemoryError and what does each tell you?**
*Concept Check*

**One-line answer:** Each OOM message names a different memory region that exhausted — knowing which message you got tells you immediately where to look.

**Full answer:**
OutOfMemoryError is not a single failure; it is a family of failures, and the message is diagnostic. "Java heap space" means the garbage collector ran but could not free enough heap to satisfy an allocation — either you need a larger heap via -Xmx or, more likely, objects are being kept alive unintentionally (a memory leak). "GC overhead limit exceeded" means the JVM spent more than 98% of recent CPU time doing GC but freed less than 2% of the heap each time — the application is effectively thrashing in a GC spin loop with no useful progress, and more heap is the immediate fix though it only delays the underlying leak. "Metaspace" means the class metadata area overflowed — this almost always means a framework is generating too many classes at runtime: Groovy or JRuby scripts compiled dynamically, Spring or Hibernate creating too many proxy classes, or a classloader leak where old class loaders are not getting GC'd; cap it and investigate with -XX:MaxMetaspaceSize. "Unable to create new native thread" means the OS refused to create another thread — you have hit either the OS-level per-process thread limit (ulimit -u on Linux) or the system-wide limit; reduce your thread pool sizes or tune OS limits. "Direct buffer memory" means off-heap native memory used by java.nio.ByteBuffer.allocateDirect() exceeded the limit set by -XX:MaxDirectMemorySize — common in netty-based frameworks and high-throughput NIO servers.

*In an interview, rattling off all five message types with their root causes is a reliable signal that you have debugged production JVM issues.*

> **Gotcha follow-up:** How would you diagnose a "Java heap space" OOM in production?
> Enable -XX:+HeapDumpOnOutOfMemoryError and -XX:HeapDumpPath=/dumps/heap.hprof so the JVM automatically writes a heap snapshot when it OOMs. Load the dump in Eclipse Memory Analyzer (MAT) and run the Leak Suspects report, which identifies the objects holding the most "retained heap" — the memory that would be freed if that object were collected. The most common culprit is a large Map or List reachable from a static field, growing without bound because entries are never removed.

---

**Q8: What is the difference between -Xms and -Xmx, and how should you set them in production containers?**
*Tradeoff Question*

**One-line answer:** -Xms is the initial heap size at startup; -Xmx is the maximum; in production containers set them equal to avoid resize pauses and make memory usage predictable.

**Full answer:**
When the JVM starts, it allocates -Xms worth of heap from the OS immediately. As the application runs and the heap fills, the JVM can grow it up to -Xmx by requesting more pages from the OS. If Xms is smaller than Xmx, this growth is not free: it triggers OS memory allocation, which can cause brief pause-like behaviour as the kernel maps new memory pages, and it makes the process's RSS (Resident Set Size — the actual physical memory it is consuming) unpredictable from an external observer's perspective. In production, especially in Kubernetes where pod memory limits are strict and the kubelet will OOMKill a pod that exceeds its limit, you want the JVM to claim its full allocation at startup by setting Xms equal to Xmx. This eliminates heap-resize events entirely and makes the RSS at startup match the RSS at full load, so your Kubernetes memory requests and limits can be set accurately. The standard rule of thumb is to set Xmx to approximately 75% of the container's total memory allocation, reserving the remaining 25% for the JVM's own native memory overhead: thread stacks (each platform thread typically has a 512KB–1MB stack), the Metaspace, the JIT code cache, and off-heap buffers used by libraries.

*The Kubernetes angle — setting Xms=Xmx for predictable RSS — is what distinguishes a container-aware answer from a textbook answer.*

> **Gotcha follow-up:** What is UseContainerSupport and why does it matter?
> -XX:+UseContainerSupport (enabled by default since Java 10) makes the JVM read CPU and memory limits from the container's cgroups rather than from the host OS. Without it, the JVM would see the host machine's 64 GB RAM and set default heap sizes accordingly, ignoring the fact that the container is limited to 2 GB. With it enabled, the JVM correctly uses the container limits as the basis for default memory sizing.

---

**Q9: What are the key JVM GC tuning flags you reach for first?**
*Concept Check*

**One-line answer:** Start with GC selection, pause target, equal heap sizes, and GC logging — everything else is secondary tuning.

**Full answer:**
Before tuning anything, enable structured GC logging so you have data. The flags I reach for first are: `-XX:+UseG1GC` to be explicit about using G1 (it is the default from Java 9 but being explicit in startup scripts avoids surprises if the JVM version changes), and `-XX:MaxGCPauseMillis=200` to tell G1 what pause budget to target. For heap sizing, `-Xms2g -Xmx2g` with equal values eliminates resize events as discussed. If pause times are still too high after tuning, `-XX:+UseZGC` is the switch to sub-millisecond pauses at the cost of ~15% CPU overhead. For diagnostics, `-Xlog:gc*:file=gc.log:time,uptime` writes structured GC logs with timestamps — essential for diagnosing GC pressure after the fact — and `-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/dumps/heap.hprof` ensures you automatically capture a heap snapshot if the process OOMs. The most impactful single flag for reducing G1 pause times without switching GC is MaxGCPauseMillis; G1 will adjust its collection set size to try to meet the target.

```
-XX:+UseG1GC                              # explicit G1 (default Java 9+)
-XX:+UseZGC                               # ZGC for sub-millisecond pauses
-XX:MaxGCPauseMillis=200                  # G1 pause target (best-effort)
-XX:G1HeapRegionSize=16m                  # region size (power of 2, 1–32m)
-XX:InitiatingHeapOccupancyPercent=45     # start concurrent marking at 45% full
-Xms2g -Xmx2g                             # equal initial and max heap (prod)
-Xlog:gc*:file=gc.log:time,uptime         # structured GC log (Java 9+)
-XX:+HeapDumpOnOutOfMemoryError           # auto heap dump on OOM
-XX:HeapDumpPath=/dumps/heap.hprof        # where to write the dump
```

*Interviewers asking this are testing whether you have actually tuned JVMs in production or just read about it.*

> **Gotcha follow-up:** What does InitiatingHeapOccupancyPercent control?
> It sets the heap occupancy percentage at which G1 starts a concurrent marking cycle — the background phase where G1 identifies which objects are live and which are garbage. The default is 45%. If you lower it, G1 starts marking earlier and has more time to finish before the heap fills, reducing the chance of needing a full stop-the-world collection. If your application has a predictable allocation rate, tuning this flag can eliminate "concurrent mode failures" where G1 runs out of time.

---

**Q10: How do you perform a heap dump analysis and what are you looking for?**
*Design Scenario*

**One-line answer:** Capture a heap dump with jmap or automatically on OOM, load it into Eclipse MAT, and find objects holding the most retained heap along the GC root path.

**Full answer:**
A heap dump is a binary snapshot of the entire Java heap at a moment in time — it records every object, its class, its size, and the reference graph between objects. You generate one manually with `jmap -dump:format=b,file=heap.hprof <pid>` (where pid is the Java process ID from jps or ps) or automatically whenever an OOM occurs by passing -XX:+HeapDumpOnOutOfMemoryError at JVM startup. Load the .hprof file into Eclipse Memory Analyzer Tool (MAT) — it is the standard tool because it can handle heaps of many gigabytes and has smart analysis reports. The first report to run is "Leak Suspects," which identifies the objects with the most "retained heap" — retained heap for an object means the total memory that would be freed if that object and everything reachable only through it were collected. A legitimate memory leak shows up as one or a handful of objects with disproportionately large retained heap. The underlying concept is GC roots: the garbage collector considers an object alive if there is any reference path from a GC root to it. GC roots are: active thread stacks (local variables in currently executing methods), static fields, and JNI (Java Native Interface) references. A memory leak is almost always a collection — a Map, List, or Cache — that is reachable from a static field and is growing without anything ever removing entries from it. MAT's "Path to GC Roots" view shows you exactly which static field or thread stack is keeping the leaking object alive.

*Mention retained heap explicitly — it is MAT's most important metric and shows you understand GC reachability, not just object size.*

> **Gotcha follow-up:** What is the difference between shallow heap and retained heap in MAT?
> Shallow heap is the memory consumed by the object itself — just its fields, not any objects it references. Retained heap is the shallow heap of the object plus the shallow heap of every object that would be garbage collected if this object were removed — in other words, everything it exclusively owns. A small object can have a massive retained heap if it holds a reference to a large data structure that nothing else references.

---

**Common Mistakes:**
- **Confusing Metaspace with the heap** → Metaspace holds class structure metadata and is native memory outside the heap; it has its own OOM message and its own flags
- **Setting Xms much smaller than Xmx in containers** → leads to heap resize events and unpredictable RSS that can trigger Kubernetes OOMKill
- **Ignoring the OOM message text** → each message points to a different memory region and a different fix; treating all OOMs as "increase Xmx" wastes time
- **Not enabling GC logging before a performance incident** → you cannot diagnose GC pressure retrospectively without logs; always enable -Xlog:gc* in production

**Quick Revision:** Stack = per-thread frames, Heap = GC'd objects, Metaspace = class structure; G1 is the default, ZGC is the choice when pauses matter more than CPU; JIT goes Interpret → C1 → C2; each OOM message names its memory region.

---

## Section 6: Multithreading

> *Reading guide: These fifteen questions cover the Java concurrency toolkit from first principles (synchronized, volatile, happens-before) through the high-level utilities (ExecutorService, CompletableFuture, virtual threads). Know the gotchas — DCL without volatile, wait() in if not while, ThreadLocal leaks — because they come up in every senior Java interview.*

---

**Q1: What is the difference between synchronized and ReentrantLock?**
*Concept Check*

**One-line answer:** Both provide mutual exclusion, but ReentrantLock gives you timed attempts, interruptible waits, fairness control, and multiple condition variables that synchronized cannot.

**Full answer:**
`synchronized` is a keyword built into the JVM. When you mark a method or block synchronized, the JVM automatically acquires the object's intrinsic lock (also called a monitor) when entering and releases it when leaving — even if an exception is thrown, the unlock is guaranteed because the JVM handles it. This makes synchronized safe and simple but inflexible. `ReentrantLock` is a Java class in `java.util.concurrent.locks` that provides the same mutual exclusion semantics — only one thread holds the lock at a time — but adds capabilities that synchronized cannot match. `tryLock()` attempts to acquire the lock and returns a boolean immediately if it cannot, letting you do other work or avoid a deadlock rather than blocking forever. `tryLock(long time, TimeUnit unit)` waits at most a given duration. `lockInterruptibly()` allows the waiting thread to be cancelled by `Thread.interrupt()` — useful for building cancellable operations. `new ReentrantLock(true)` creates a fair lock, which queues waiting threads in arrival order (FIFO) to prevent thread starvation, though fairness costs throughput. Multiple `Condition` objects via `lock.newCondition()` let different groups of threads wait for different signals on the same lock — with synchronized you only get one condition queue per object. The critical downside of ReentrantLock is that you must call `unlock()` manually, always in a `finally` block, because if you forget it the lock is held forever and every other thread trying to acquire it blocks indefinitely.

*Always mention the finally block requirement — forgetting it is one of the most common bugs with ReentrantLock.*

> **Gotcha follow-up:** What does "reentrant" mean in ReentrantLock?
> Reentrant means a thread that already holds the lock can acquire it again without deadlocking itself. This matches the behaviour of synchronized, where calling a synchronized method from another synchronized method on the same object works fine. The lock maintains a hold count — each lock() increments it, each unlock() decrements it, and the lock is truly released only when the count reaches zero.

---

**Q2: What does volatile guarantee, and what does it NOT guarantee?**
*Concept Check*

**One-line answer:** volatile guarantees visibility — every write is immediately visible to all threads — but does NOT guarantee atomicity for compound read-modify-write operations.

**Full answer:**
Modern CPUs and the JVM are both allowed to cache field values in registers or CPU caches and defer writing them to main memory for performance. Without any synchronisation, one thread can write a new value to a field while another thread continues reading a stale cached copy — this is a visibility problem. Declaring a field `volatile` tells the JVM and CPU to never cache the value: every write to a volatile field is immediately flushed to main memory, and every read fetches from main memory, bypassing any cache. This means if thread A writes `volatile boolean done = true` and thread B reads `done`, thread B will see `true` — guaranteed. However, volatile makes no guarantee about atomicity of compound operations. Consider `volatile int counter; counter++` — this is three separate operations: read the current value, add one, write the result back. Another thread can execute between any of these steps and produce an incorrect count. For atomic increment of an integer, you need `AtomicInteger.incrementAndGet()`, which uses a hardware-level Compare-And-Swap (CAS) instruction that reads, increments, and writes as a single uninterruptible operation. The canonical use cases for volatile are: a boolean stop flag checked by a thread in a loop, and the instance field in double-checked locking (where it prevents reordering of object construction).

*The example of `counter++` being non-atomic is what makes this answer concrete rather than abstract.*

> **Gotcha follow-up:** Does volatile prevent instruction reordering?
> Yes. A volatile write acts as a full memory barrier — the JVM will not reorder instructions from before the write to after it, or vice versa. This is why the `instance` field in double-checked locking must be volatile: without it, the JVM could reorder the object constructor's internal writes to happen after the reference assignment, publishing a partially constructed object to other threads before its fields are fully set.

---

**Q3: What is the happens-before relationship in the Java Memory Model?**
*Concept Check*

**One-line answer:** Happens-before is the Java Memory Model's formal guarantee that one thread's actions are visible to another — without it, you have no memory visibility guarantees between threads.

**Full answer:**
The Java Memory Model (JMM) defines what values a thread is allowed to see when reading a shared variable. Without a happens-before relationship between a write and a read, the JMM says the reading thread is allowed to see any value — the write might not be visible at all. The key happens-before rules every Java developer should know: program order — within a single thread, every statement happens-before the next statement in source code order; monitor unlock — unlocking a synchronized block happens-before any subsequent lock of the same monitor, so all writes done before the unlock are guaranteed visible to the thread that acquires the lock next; volatile write — writing to a volatile field happens-before any subsequent read of that same volatile field by any thread; thread start — everything a thread does before calling `thread.start()` happens-before any code that runs inside the started thread; and thread join — all code that ran inside a thread happens-before `thread.join()` returns to the joining thread. These rules compose: if A happens-before B and B happens-before C, then A happens-before C. This is why a properly synchronised program is correct: each synchronisation action establishes a happens-before edge that carries all prior writes across the edge.

*Interviewers testing happens-before usually want to know if you understand that it is a formal model, not just intuition.*

> **Gotcha follow-up:** If thread A writes to a field and thread B reads it with no synchronisation at all, what can B see?
> Anything. The JMM says B can see the value that A wrote, a default value (zero/null/false), or any previously written value. There is no guarantee of visibility without a happens-before relationship. This is why "my code works without synchronisation on my machine" is not a correctness argument — the JMM permits the JIT or CPU to cache values, and the behaviour can change between JVM versions, hardware architectures, or even between runs.

---

**Q4: Explain Double-Checked Locking — why is the volatile keyword critical?**
*Concept Check*

**One-line answer:** DCL uses two null checks to avoid locking on every access, but without volatile the JVM can publish a partially constructed singleton, causing other threads to read corrupt state.

**Full answer:**
Double-Checked Locking is a pattern for lazily creating a singleton — deferring its creation until the first caller needs it — while minimising the synchronisation cost. The outer null check runs on every call without acquiring any lock: if the instance already exists, we return immediately, which is the common fast path. Only when instance is null does the calling thread enter the synchronized block. Inside, we check null again because two threads might have both seen null simultaneously, both entered the outer check, and one might have created the instance while the other was waiting for the lock. After the second check, we create the singleton once. The critical requirement is that `instance` must be declared `volatile`. Object construction in Java is not a single atomic operation: the JVM allocates memory, writes default field values, runs the constructor, and then assigns the reference. Without volatile, the JIT is free to reorder these steps — specifically, it might write the reference to `instance` before the constructor has finished setting the object's fields. Another thread doing the outer null check would see a non-null reference, skip the lock, and try to use a singleton whose fields are not yet initialised. The volatile write to `instance` establishes a happens-before relationship: everything done in the constructor happens-before the volatile write, and the volatile write happens-before any subsequent volatile read, so any thread reading `instance` after it is set will see the fully constructed object.

```java
private static volatile Singleton instance;
public static Singleton getInstance() {
    if (instance == null) {
        synchronized (Singleton.class) {
            if (instance == null) instance = new Singleton();
        }
    }
    return instance;
}
```

*If an interviewer asks about singletons in Java, always mention both enum singleton (preferred) and DCL with volatile.*

> **Gotcha follow-up:** If DCL is so tricky, what is the simplest correct way to write a singleton?
> An enum: `public enum Singleton { INSTANCE; }`. The JVM guarantees that enum constants are instantiated exactly once, under class initialisation, which is thread-safe by the JVM specification. It is also serialisation-safe by default — the JVM prevents a second instance from being created during deserialisation, unlike a class-based singleton that requires a custom `readResolve()` method.

---

**Q5: Explain the ThreadPoolExecutor parameters and how they interact.**
*Concept Check*

**One-line answer:** corePoolSize, maxPoolSize, the queue, and the rejection handler together determine when new threads are created, when tasks are queued, and what happens when both are exhausted.

**Full answer:**
`ThreadPoolExecutor` has a precise lifecycle for submitted tasks. When a task arrives: if active threads are fewer than `corePoolSize`, a new thread is created immediately even if existing threads are idle — the pool always tries to maintain this core count. If active threads equal corePoolSize, the task goes to the `workQueue` to wait. If the workQueue is full AND active threads are below `maxPoolSize`, a new temporary thread is created to handle the task directly. If the queue is full AND active threads equal maxPoolSize, the `rejectionHandler` fires. `keepAliveTime` specifies how long these temporary threads (beyond corePoolSize) wait for a new task before terminating. For the queue: `LinkedBlockingQueue` with no bound argument is effectively infinite — it will queue tasks forever, which means maxPoolSize is never reached (a common trap). `ArrayBlockingQueue(N)` has a hard bound. `SynchronousQueue` holds zero tasks — every submitted task must find a waiting thread immediately, or a new thread is created if below maxPoolSize (this is what `Executors.newCachedThreadPool()` uses). For the rejection handler: `AbortPolicy` (the default) throws `RejectedExecutionException`, which the caller must handle. `CallerRunsPolicy` runs the task on the submitter's thread — this is natural backpressure because the submitter slows down. `DiscardPolicy` silently drops the task. `DiscardOldestPolicy` drops the oldest queued task to make room.

*The interaction between queue capacity and maxPoolSize is the most common interview follow-up — extra threads are created only when the queue is full, not when it is busy.*

> **Gotcha follow-up:** Why does Executors.newFixedThreadPool never use threads beyond the core count?
> Because `newFixedThreadPool(n)` uses a `LinkedBlockingQueue` with no size limit. The queue is never "full," so the condition for creating threads beyond corePoolSize is never triggered. Setting maxPoolSize larger than corePoolSize with an unbounded queue has no practical effect.

---

**Q6: What is ForkJoinPool and what problem does work-stealing solve?**
*Concept Check*

**One-line answer:** ForkJoinPool lets CPU-intensive recursive tasks split themselves into subtasks, and work-stealing keeps all CPU cores busy by redistributing tasks from busy threads to idle ones.

**Full answer:**
A traditional thread pool has one central queue of tasks. When you use it for divide-and-conquer workloads — a large array to sort, a recursive tree traversal — threads generate subtasks and submit them back to the same central queue, creating contention on the queue and potentially deadlocking if waiting threads need results from subtasks they submitted. ForkJoinPool solves this differently: each worker thread has its own double-ended queue (deque) of tasks. When a thread creates a subtask with `fork()`, the subtask goes onto the head of that thread's own deque — the thread processes its own tasks in LIFO order (newest first), which improves cache locality because the most recently created subtask tends to use data the CPU already has cached. When a thread runs out of its own tasks instead of sitting idle, it steals tasks from the tail of another thread's deque — FIFO from the victim's perspective, chosen to minimise contention with the victim working the head end. This work-stealing mechanism keeps all CPU cores occupied without a central queue bottleneck. You implement tasks as `RecursiveTask<V>` (produces a value, like computing the sum of an array) or `RecursiveAction` (no return value, like an in-place sort). `ForkJoinPool.commonPool()` is the shared pool used automatically by Java parallel streams (`stream().parallel()`) and most `CompletableFuture` operations when you do not supply your own executor.

*Mention parallel streams and CompletableFuture both use commonPool — it shows you understand the practical implications.*

> **Gotcha follow-up:** What happens if a ForkJoinPool task blocks on I/O?
> ForkJoinPool is designed for CPU-bound tasks, not I/O-bound ones. If a task blocks waiting for I/O, the worker thread is stuck — it cannot steal other work. With many blocking tasks you can starve the pool. ForkJoinPool has a ManagedBlocker interface to signal the pool that a thread is about to block, allowing the pool to create a compensation thread temporarily, but it is complex to use correctly. The right answer for I/O-bound tasks is virtual threads (Java 21) or a standard thread pool.

---

**Q7: What are the four Coffman conditions for deadlock, and how do you prevent each one?**
*Concept Check*

**One-line answer:** Deadlock requires mutual exclusion, hold-and-wait, no preemption, and circular wait — all four simultaneously; breaking any one condition prevents deadlock.

**Full answer:**
Deadlock is when a set of threads are each waiting for a resource that is held by another thread in the set, with no thread able to proceed. Edward Coffman identified four necessary conditions that must ALL hold at the same time for deadlock to occur. First, mutual exclusion: at least one resource involved must be exclusively held — only one thread can use it at a time, which is the definition of a lock. You cannot eliminate this condition without removing locking entirely, which is only feasible with lock-free data structures. Second, hold and wait: a thread is holding at least one resource while waiting to acquire another. You can prevent this by requiring threads to acquire all resources they will need at once (all-or-nothing acquisition) before starting work, though this is hard to implement in practice. Third, no preemption: resources cannot be forcibly taken from a thread — a thread holding a lock can only release it voluntarily. `tryLock(timeout)` in ReentrantLock addresses this: if a thread cannot acquire a lock within a timeout, it releases what it holds and retries, preventing indefinite waiting. Fourth, circular wait: there exists a cycle of threads T1 waiting for T2's resource, T2 waiting for T3's resource, ..., Tn waiting for T1's resource. This is the condition most easily broken in practice: establish a global consistent ordering across all locks in the system and always acquire them in that order. If every thread that needs lockA and lockB always acquires lockA first and lockB second, a cycle cannot form.

*The interviewer usually wants you to name all four AND explain a fix — breaking circular wait via consistent ordering is the most practical.*

> **Gotcha follow-up:** How do you detect a deadlock in a running JVM?
> Take a thread dump with `jstack <pid>` or kill -3 on Linux. The JVM will detect and report deadlock cycles in the thread dump output, listing which threads are involved and which locks they hold and are waiting for. Tools like VisualVM and JDK Mission Control can also show live lock graphs.

---

**Q8: How does a ThreadLocal memory leak occur in a thread pool, and how do you fix it?**
*Tradeoff Question*

**One-line answer:** Thread pool threads never die, so ThreadLocal values attached to them accumulate forever if you never call remove() — the thread's threadLocals map grows without bound.

**Full answer:**
`ThreadLocal<T>` stores a value per thread by keeping it in a map on the Thread object itself (`Thread.threadLocals`). The map uses the `ThreadLocal` instance as the key, wrapped in a `WeakReference`, and your stored value as the value. The weak reference on the key means: if the `ThreadLocal` object itself becomes unreachable (no live references to it in your application), the GC can collect the key. However, the value — your stored data — is a strong reference in the map. With the key gone, the entry becomes orphaned: the GC cannot reach the value through normal reachability analysis, but the entry is still sitting in the thread's map and will never be cleaned up unless something explicitly iterates and removes null-key entries. In a long-lived thread pool, threads never terminate, so their `threadLocals` maps are never cleared. Over time, orphaned values accumulate. The fix is always to call `threadLocal.remove()` in a `finally` block when you are done with the value for the current request or task. In web frameworks like Spring, request-scoped beans and SecurityContextHolder both use ThreadLocal, and the framework's request lifecycle handling is responsible for removing these values at the end of each request — but if you add your own ThreadLocal usage, you are responsible for your own cleanup.

*Always mention `remove()` in a `finally` block — that is the concrete fix interviewers want to hear.*

> **Gotcha follow-up:** If the ThreadLocal key is a WeakReference, why doesn't the GC just clean up the entry automatically?
> The key is a WeakReference, so the ThreadLocal instance can be GC'd once nobody holds a strong reference to it. But the value is a strong reference — the GC can only collect objects that are not strongly reachable. The entry in the threadLocals map holds a strong reference to the value, and the map itself is strongly held by the Thread object, which is strongly held by the thread pool. So the value is always strongly reachable and cannot be GC'd. ThreadLocal does have code to clean up stale entries (null keys) during subsequent get/set/remove calls, but this is opportunistic and not guaranteed to run in time.

---

**Q9: What are virtual threads in Java 21 and what problem do they solve?**
*Concept Check*

**One-line answer:** Virtual threads are JVM-managed lightweight threads that unmount from OS threads when blocking on I/O, making it practical to run millions of concurrent tasks without the memory cost of millions of OS threads.

**Full answer:**
Traditional Java threads — now called "platform threads" — are mapped one-to-one to OS threads. An OS thread consumes roughly 1 MB of stack memory by default, and operating systems typically limit processes to tens of thousands of threads. This means the classic "one thread per request" model breaks down above ~10,000 concurrent requests, forcing developers to use reactive programming (callbacks, `CompletableFuture` chains, Project Reactor) to handle high concurrency with fewer threads. Reactive code is powerful but hard to read, debug, and profile because the logical flow of a request is split across many callback lambdas. Virtual threads solve this by being entirely JVM-managed. They run on top of a small pool of carrier threads (platform threads in a ForkJoinPool). When a virtual thread calls any blocking operation — reading from a socket, waiting for a database response, calling `Thread.sleep()` — the JVM automatically unmounts the virtual thread from its carrier thread; the carrier thread is immediately free to execute other virtual threads. When the blocking operation completes, the virtual thread is remounted on an available carrier and resumes from where it left off. This makes it practical to run one virtual thread per request even at a million concurrent requests: the JVM manages the multiplexing internally. Virtual threads use much less memory than platform threads (they start with a small stack that grows dynamically) and can be created with `Thread.ofVirtual().start(runnable)` or via `Executors.newVirtualThreadPerTaskExecutor()`. The critical limitation: virtual threads are not faster than platform threads for CPU-bound work. If your threads spend their time computing rather than waiting, virtual threads offer no benefit — the throughput gain is entirely from eliminating idle blocking time.

*"Not faster for CPU-bound work" is the nuance interviewers test — candidates who understand the limitation demonstrate real understanding.*

> **Gotcha follow-up:** What is a "pinned" virtual thread and why is it a problem?
> A virtual thread is pinned when it cannot be unmounted from its carrier thread while blocked. This happens when the virtual thread is inside a `synchronized` block or is calling native code through JNI. A pinned virtual thread blocks its entire carrier thread, eliminating the scalability benefit. The fix is to replace `synchronized` with `ReentrantLock` in code paths that may block on I/O, since ReentrantLock's park/unpark mechanism is compatible with virtual thread unmounting. Java 24+ is working on removing synchronisation pinning.

---

**Q10: What is CAS (Compare-And-Swap) and what is the ABA problem?**
*Concept Check*

**One-line answer:** CAS is a single atomic CPU instruction that updates a memory location only if it still holds an expected value; ABA is when a location changes A→B→A between the read and the CAS, fooling the CAS into thinking nothing changed.

**Full answer:**
Compare-And-Swap is a hardware primitive available on all modern CPUs. In Java, it is exposed through classes like `AtomicInteger.compareAndSet(expected, newValue)`. The semantics are: atomically read the current value at the memory location; if it equals `expected`, write `newValue` and return true; if it does not equal `expected`, do nothing and return false — and this entire read-compare-write happens as a single uninterruptible CPU instruction. This is the foundation of all lock-free algorithms: instead of acquiring a lock, you read the current value, compute the new value, and CAS the update. If the CAS fails (another thread changed the value between your read and your CAS), you retry the loop. This is optimistic concurrency — you assume the common case is no contention, and only retry when you are wrong. The ABA problem arises in linked data structures. Thread T1 reads node A at the head of a linked list and plans to CAS it out. Thread T2 removes node A, does some work, and then re-adds node A at the head. T1's CAS sees A at the head, thinks nothing has changed since its read, and succeeds — but the list has been modified; other nodes that were between the two As might be gone, causing corruption. The fix is `AtomicStampedReference<V>`, which pairs the value with an integer version stamp. The CAS checks both value AND stamp, so the A-then-B-then-A sequence will have a different stamp (version was incremented twice) and T1's CAS will correctly fail.

*ABA only matters for pointer-based structures like linked lists — for simple counters it is irrelevant.*

> **Gotcha follow-up:** Why is CAS called optimistic and what makes it unsuitable for high-contention counters?
> CAS is optimistic because it assumes — optimistically — that no other thread will change the value between your read and your write. Under low contention this is nearly always true and the operation succeeds on the first try. Under high contention, many threads are reading and trying to CAS the same location simultaneously; most will fail and spin-retry, wasting CPU cycles in a busy loop. This is why `LongAdder` outperforms `AtomicLong` under high contention: LongAdder distributes increments across multiple cells to reduce per-cell contention.

---

**Q11: When do you use LongAdder vs AtomicLong?**
*Tradeoff Question*

**One-line answer:** Use LongAdder for high-throughput counters under contention; use AtomicLong when you need to atomically read the current value and make a decision based on it.

**Full answer:**
`AtomicLong` uses a single `long` field protected by CAS. Under high contention — many threads calling `incrementAndGet()` simultaneously — threads repeatedly fail their CAS and spin-retry, burning CPU cycles without making progress. This is called CAS thrashing. `LongAdder` solves this with a different internal structure: it maintains a base cell for low-contention cases, and under contention it dynamically allocates a `Cell[]` array where each Cell is a padded `long` value. Using a thread probe hash, each thread is directed to its own Cell, so threads mostly increment different memory locations and rarely contend with each other. The true sum is computed lazily when you call `sum()` by adding the base and all Cell values together. The trade-off: `sum()` is not a strongly consistent snapshot — other threads might be incrementing while you compute the sum, so the returned value can be slightly stale. This is acceptable for metrics, rate counters, and statistics but not for logic that says "if the counter is exactly N, do something." For the latter, `AtomicLong.compareAndSet()` is the right choice because it lets you atomically read-then-conditionally-write in a single operation. The rule of thumb: if you only ever call `increment()` and occasionally call `get()` to report a metric, use `LongAdder`. If the current value affects program logic, use `AtomicLong`.

*The word "contention" is the key trigger — whenever you hear "high concurrency counter," the answer is LongAdder.*

> **Gotcha follow-up:** Why are LongAdder cells padded?
> To prevent false sharing — a CPU cache coherence performance problem where two logically unrelated variables happen to live in the same CPU cache line (typically 64 bytes). When one thread writes to its Cell, the CPU invalidates the entire cache line for all other CPUs, forcing threads on other cells to reload data even though they are not sharing a logical value. Padding the Cell structs to 64 bytes ensures each Cell occupies its own cache line, eliminating false sharing.

---

**Q12: Compare CountDownLatch, CyclicBarrier, and Semaphore.**
*Concept Check*

**One-line answer:** CountDownLatch waits for N events to happen once; CyclicBarrier waits for N threads to arrive together repeatedly; Semaphore limits how many threads access a resource concurrently.

**Full answer:**
`CountDownLatch` is initialised with a count. One or more threads call `await()` and block. Other threads call `countDown()` to decrement the counter. When the counter reaches zero, all waiting threads are released. A CountDownLatch cannot be reset — once it reaches zero it is done. Use case: a main thread that wants to wait for N worker threads to complete their startup sequence before accepting traffic, or a test that waits for N events to occur. `CyclicBarrier` is initialised with a party count N. N threads each call `await()`, which blocks each caller until all N have arrived. Once all N threads have called `await()`, they are all released simultaneously. The barrier automatically resets for the next cycle — hence "cyclic." You can also pass a Runnable that runs once each time the barrier is tripped. Use case: a parallel computation divided into phases where all worker threads must complete phase 1 before any thread starts phase 2. `Semaphore` is initialised with a permit count. `acquire()` decrements the permit count, blocking if it is zero. `release()` increments it, waking a waiting thread. This is not about making threads meet — it is about controlling how many threads can be in a critical section simultaneously. Use case: limiting concurrent connections to a database connection pool to at most N, or rate-limiting access to a shared resource. Semaphore is generalised mutual exclusion: a semaphore initialised to 1 is a mutex.

*The exam-style way to remember: CountDownLatch = one-shot gate, CyclicBarrier = repeating rendezvous, Semaphore = resource pool guard.*

> **Gotcha follow-up:** What is the difference between a CyclicBarrier and a Phaser?
> `Phaser` (Java 7) is a more flexible CyclicBarrier that supports dynamic registration and deregistration of parties — threads can join or leave the phaser at any phase. CyclicBarrier has a fixed party count. Phaser also supports tiered hierarchies for very large parallel programs. For most use cases CyclicBarrier is simpler.

---

**Q13: What are the different BlockingQueue implementations and when do you use each?**
*Concept Check*

**One-line answer:** ArrayBlockingQueue is bounded and predictable; LinkedBlockingQueue can be unbounded (a common trap); SynchronousQueue is a zero-buffer handoff; PriorityBlockingQueue orders by priority; DelayQueue releases by time.

**Full answer:**
`ArrayBlockingQueue(int capacity)` is backed by a fixed-size array. Once it is full, `put()` blocks and `offer()` returns false. The capacity is set at construction and cannot change. It supports an optional fairness flag that makes waiting threads dequeue in FIFO order at the cost of throughput. Use when you want bounded backpressure — you want producers to slow down when the buffer is full. `LinkedBlockingQueue` can be created with a capacity (`new LinkedBlockingQueue<>(1000)`) or without one, in which case it defaults to `Integer.MAX_VALUE` — effectively unbounded. The unbounded default is a common trap: with Executors.newFixedThreadPool(), the default LinkedBlockingQueue means tasks pile up indefinitely until the JVM runs out of heap. Always specify a capacity. `SynchronousQueue` holds zero elements. A producer calling `put()` blocks until a consumer calls `take()` — every insertion must have a matching removal, making it a direct handoff channel with no buffering at all. This is what `Executors.newCachedThreadPool()` uses so that every submitted task either finds an idle thread immediately or creates a new one. `PriorityBlockingQueue` is unbounded and dequeues the element with the highest priority (natural ordering or a Comparator) rather than FIFO. `DelayQueue` holds elements that implement the `Delayed` interface — an element can only be taken from the queue after its delay has expired. Useful for scheduling future tasks, retry queues with backoff, or session timeout management.

*Always mention the unbounded LinkedBlockingQueue trap — it signals production awareness.*

> **Gotcha follow-up:** How does the producer-consumer pattern behave if you use a SynchronousQueue with a fixed thread pool?
> If all threads in the pool are busy and you submit a new task, the SynchronousQueue will immediately reject it because it cannot buffer tasks and no thread is waiting. That triggers the pool's rejection handler. SynchronousQueue is paired with unbounded pools (like CachedThreadPool) where new threads are created on demand, or with explicit backpressure handling.

---

**Q14: What is the difference between wait(), sleep(), and yield()?**
*Concept Check*

**One-line answer:** wait() releases the lock and waits for a signal; sleep() pauses without releasing locks; yield() hints to the scheduler to give up the CPU timeslice but may be completely ignored.

**Full answer:**
`wait()` is an instance method on Object called inside a `synchronized` block. It atomically releases the intrinsic lock on that object and suspends the calling thread. The thread remains suspended until another thread calls `notify()` (wakes one waiting thread) or `notifyAll()` (wakes all waiting threads) on the same object, or a specified timeout expires. When the thread wakes, it must re-acquire the lock before proceeding. Critical: always call `wait()` in a `while` loop checking your condition, not an `if` statement. This is because of spurious wakeups — the Java specification allows a thread to wake up from `wait()` even when no `notify()` was called, so you must re-check whether the condition you were waiting for is actually true before proceeding. `sleep(long millis)` is a static method on Thread. It pauses the current thread for a fixed duration. It does NOT release any locks the thread holds — if you sleep inside a synchronized block, the lock stays locked for the entire sleep duration, blocking every other thread that needs it. Other threads gain no access to the locked resource while you sleep. `yield()` is a hint to the thread scheduler that the current thread is willing to give up its remaining CPU timeslice so other threads of equal or higher priority can run. The scheduler is completely free to ignore it. It never releases locks, never waits for any condition, and its behaviour is platform-dependent.

*The spurious wakeup requirement — while loop not if — comes up in every multithreading interview.*

> **Gotcha follow-up:** Why must wait() always be called inside a while loop and not an if?
> Because a thread can return from wait() without notify() having been called — this is a spurious wakeup, which the JVM specification explicitly allows to occur for implementation reasons. If you check the condition in an if statement, you assume that waking up means the condition is true, and you proceed when it might not be. A while loop re-checks the condition after every wakeup, ensuring you only proceed when the condition is genuinely satisfied.

---

**Q15: What is StampedLock and when is it better than ReentrantReadWriteLock?**
*Tradeoff Question*

**One-line answer:** StampedLock adds an optimistic read mode that requires no lock at all on the read path, making it significantly faster for read-heavy workloads where writes are rare.

**Full answer:**
`ReentrantReadWriteLock` allows multiple simultaneous readers but exclusive writers. This is better than a plain lock when reads dominate, but readers still contend with each other at the lock acquisition level. `StampedLock` (Java 8) supports three modes. Write lock: exclusive, just like ReentrantReadWriteLock's write lock, acquired with `writeLock()` which returns a stamp (a long token). Read lock: shared, like ReentrantReadWriteLock's read lock, acquired with `readLock()`. Optimistic read: `tryOptimisticRead()` returns a stamp immediately without acquiring any lock — it succeeds as long as no write lock is held. You then read your data and call `validate(stamp)`. If `validate()` returns true, no write occurred between your `tryOptimisticRead()` call and your `validate()` call, and your read is consistent. If `validate()` returns false, a write happened and your read may be inconsistent — you must fall back to a full read lock and re-read. This optimistic path is analogous to optimistic locking in databases: you bet that the common case (no concurrent writes) is true, check the assumption afterward, and only pay the full cost when the assumption is wrong. For read-heavy workloads where writes are rare, the optimistic path is almost always correct, and the overhead is just two method calls with no lock operations — significantly faster than acquiring even a shared lock. The trade-offs: StampedLock is NOT reentrant — a thread that holds a StampedLock write lock cannot acquire it again without deadlocking. It also has no Condition support. And the API is more complex and error-prone than ReentrantReadWriteLock, so use it only when read performance is critical.

*"NOT reentrant" is the gotcha interviewers check — it is the most common StampedLock mistake.*

> **Gotcha follow-up:** Can you upgrade an optimistic read to a write lock in StampedLock?
> You can use `tryConvertToWriteLock(stamp)` to attempt to convert your current stamp to a write lock. If it succeeds (no other threads are reading), you get a write stamp and can proceed. If it fails (readers are present), the return value is 0 and you must explicitly release your optimistic read and acquire a write lock from scratch. This is more efficient than the alternative of releasing the read stamp and acquiring a write lock blindly.

---

**Common Mistakes:**
- **Forgetting unlock() in finally with ReentrantLock** → leaves the lock held forever; every subsequent acquisition blocks indefinitely
- **Using volatile for compound operations like i++** → volatile only fixes visibility; i++ is read-modify-write and is still not atomic; use AtomicInteger
- **wait() in an if instead of while** → spurious wakeups will cause the thread to proceed when the condition is still false
- **Not calling ThreadLocal.remove() in a finally block** → values leak onto pooled threads indefinitely, causing memory growth and potentially incorrect behaviour in subsequent requests

**Quick Revision:** synchronized = simple but no tryLock; volatile = visibility only, not atomicity; happens-before chains from unlock to lock, volatile write to volatile read, start to thread body; DCL needs volatile; ThreadPool: core→queue→max→reject; virtual threads unmount on I/O, not faster for CPU.

---

## Section 7: Common Traps and Gotchas

> *Reading guide: These twenty items are the questions where candidates lose points by knowing the rule but not the mechanism. For each one, understand what the developer did wrong, why the underlying JVM or Java language mechanism causes the failure, and what the correct fix is.*

---

**1. Integer Overflow — Silent Wrap-Around**

Java's `int` type is a 32-bit signed integer with a maximum value of 2,147,483,647 (2^31 - 1). If you add 1 to `Integer.MAX_VALUE`, the result wraps silently to `Integer.MIN_VALUE` (-2,147,483,648) — the CPU performs two's complement arithmetic and Java throws no exception. This is a common bug in code that computes sums or sizes: `int total = a + b` where both are large positive values can produce a negative result. The fix is `Math.addExact(a, b)`, which throws `ArithmeticException` on overflow, making the bug visible. Alternatively, use `long` for values that might exceed 2 billion.

---

**2. String Concatenation with + Inside a Loop**

The `+` operator on Strings creates a new `StringBuilder`, appends both strings, calls `toString()` to produce a new `String`, and discards the `StringBuilder` — all in one expression. Inside a loop, this means you are creating and discarding a new `StringBuilder` on every iteration, allocating O(n) objects for a loop of n iterations. For large n this produces significant garbage collection pressure and O(n²) total character copying. The fix is to declare `StringBuilder sb = new StringBuilder()` before the loop and call `sb.append(part)` on each iteration, calling `sb.toString()` once after the loop.

---

**3. == on Integer Objects Outside the Cache Range**

Java caches `Integer` objects for values from -128 to 127. When you call `Integer.valueOf(42)` (or use autoboxing like `Integer x = 42`), Java returns the same cached object every time for values in this range. This means `Integer.valueOf(42) == Integer.valueOf(42)` is `true` — you are comparing the same object reference. But `Integer.valueOf(200) == Integer.valueOf(200)` is `false` — two different objects are created. Developers often test with small values, see == working, and assume it always works. Always use `.equals()` to compare `Integer` objects, or `Integer.compare(a, b)` for ordering.

---

**4. NullPointerException from Unboxing a Null Integer**

Autoboxing silently converts between `int` and `Integer`. When you write `Integer x = null; int y = x;`, Java compiles this as `int y = x.intValue()` — calling a method on a null reference produces a NullPointerException. This is particularly subtle in method return types: a method returning `Integer` can return `null`, and any code assigning that return value to an `int` will NPE. The fix is to either null-check before unboxing or use `int` primitives throughout where nulls are not expected.

---

**5. ConcurrentModificationException in a For-Each Loop**

Java's for-each loop compiles to an iterator call. The iterator in `ArrayList` and most standard collections tracks a `modCount` — a counter incremented on every structural modification (add, remove). When `iterator.next()` is called, it checks whether the current `modCount` matches the `modCount` when the iterator was created. If they differ, it throws `ConcurrentModificationException` — not necessarily because another thread modified the collection, but because the same thread called `list.remove()` directly while iterating. The fix is `iterator.remove()` (which keeps modCounts synchronised), `list.removeIf(predicate)`, or collecting items to remove into a separate list and removing after iteration.

---

**6. list.remove(index) vs Iterator.remove() During Iteration**

Calling `list.remove(int index)` directly while iterating with an index-based for loop (or any iterator) has two problems. In an index-based for loop, removing an element shifts all subsequent elements down by one, so the element that just moved into the removed position is skipped — your loop index advances past it. Only `Iterator.remove()` is safe because the iterator adjusts its own internal state (the cursor position and modCount) after removal, maintaining correct traversal.

---

**7. HashMap Resizing Overhead Without Pre-Sizing**

`HashMap`'s default initial capacity is 16 with a load factor of 0.75. When the number of entries exceeds `capacity × 0.75`, the map resizes: it allocates a new array twice as large and rehashes every entry into the new array — O(n) work per resize. For a map that will hold 10,000 entries, this happens at 12, 24, 48, ... entries, triggering roughly 10 resizes. You can eliminate all resizes by pre-sizing: `new HashMap<>(expectedSize / 0.75 + 1)`. The formula divides by the load factor to find the initial capacity at which the map will not trigger a resize when fully populated.

---

**8. Class-Based Singleton vs Enum Singleton**

DCL requires `volatile`, a private constructor, and careful handling of serialisation (you must implement `readResolve()` to prevent deserialisation from creating a second instance). An enum singleton is far simpler: `public enum Singleton { INSTANCE; }`. The JVM guarantees that each enum constant is instantiated exactly once, lazily on first use, under the class initialisation lock — this is inherently thread-safe with no synchronisation code required. Enum instances are also immune to reflection attacks (calling the constructor via reflection throws an exception) and serialisation attacks (the JVM uses the enum's `Enum.valueOf()` mechanism during deserialisation, returning the existing instance). Use enum singleton unless you have a specific reason you cannot.

---

**9. DCL Without volatile — Partially Constructed Object**

Object construction in Java is not atomic: the JVM allocates memory, zeroes fields, runs the constructor to set field values, and finally writes the reference into `instance`. The JIT is permitted to reorder the reference write before the constructor completes — this is a legal reordering under the Java Memory Model because from a single-thread perspective the final result is the same. But another thread doing the outer null check in DCL might see the non-null reference and use an object whose constructor has not finished running. Declaring `instance` as `volatile` creates a happens-before barrier: all writes within the constructor happen-before the volatile write to `instance`, and the volatile write happens-before any read of `instance` by another thread.

---

**10. Stream Reuse After a Terminal Operation**

A Java Stream is single-use. Once a terminal operation — `collect()`, `count()`, `findFirst()`, `forEach()`, `reduce()` — is invoked, the stream's internal state is closed. Calling any operation on the same stream object after that throws `IllegalStateException: stream has already been operated upon or closed`. Streams are not collections — they do not store data. If you need to traverse the same data twice, recreate the stream each time from its source (e.g., call `list.stream()` again), or collect the results of the first traversal into a collection you can iterate multiple times.

---

**11. Optional.get() Without Checking isPresent()**

`Optional` exists specifically to make absence explicit and force callers to handle it. Calling `optional.get()` on an empty Optional throws `NoSuchElementException` — which is just as abrupt as a NullPointerException and makes Optional pointless if you use it this way. The entire value of Optional is in its methods: `orElse(defaultValue)` returns a default if absent; `orElseThrow(() -> new MyException("message"))` throws a meaningful exception with a clear message; `ifPresent(consumer)` runs code only when a value is present; `map(function)` transforms the value if present and returns a new Optional. Use `get()` only when you have previously verified `isPresent()` — or, better, restructure the code to use one of the safe alternatives.

---

**12. Comparator Overflow in Subtraction-Based Comparison**

The lambda `(o1, o2) -> o1.val - o2.val` looks like a natural comparator but is incorrect because of integer overflow. If `o1.val` is `Integer.MAX_VALUE` (2,147,483,647) and `o2.val` is `-1`, the subtraction overflows: `2147483647 - (-1)` = 2,147,483,648, which wraps to -2,147,483,648 — a negative result, incorrectly indicating o1 < o2. This produces a corrupted sort order. Always use `Integer.compare(o1.val, o2.val)` or `Comparator.comparingInt(o -> o.val)` — these use safe subtraction-free comparison.

---

**13. finalize() for Resource Cleanup**

`finalize()` is called by the GC before reclaiming an object, but the JVM provides no guarantee about WHEN it runs — it could be seconds, minutes, or never if the JVM exits cleanly. This makes it completely unreliable for releasing file handles, network connections, or database connections. Using `finalize()` for cleanup delays GC (objects with finalizers must survive an extra GC cycle), can cause resource exhaustion (connections pile up waiting for finalisation), and was deprecated in Java 9 and removed in Java 18. The correct replacement is `try-with-resources`: implement `AutoCloseable` and put resource cleanup in `close()`. The `try-with-resources` statement guarantees `close()` is called when the try block exits, even via exception.

---

**14. Static Fields in Non-Static Inner Classes**

A non-static inner class (a class declared inside another class without the `static` keyword) holds an implicit reference to its enclosing outer class instance. This means every instance of the inner class also keeps the outer class instance alive — a common source of memory leaks when inner class instances outlive their expected scope. Static fields inside a non-static inner class do not make semantic sense (the inner class has a different instance for each outer instance) and the compiler prohibits them. The fix is to declare the inner class as `static class Inner { }` — a static nested class has no implicit reference to the outer class and can have static members normally.

---

**15. String switch Fall-Through**

A `switch` on `String` correctly uses `equals()` internally — this is not a source of bugs. However, Java's `switch` statement retains C-style fall-through semantics: if you forget a `break` at the end of a `case`, execution continues into the next `case`'s body. This is easy to miss and causes hard-to-find bugs. Use `break` at the end of each case, or better, use the Java 14+ switch expression syntax: `switch(s) { case "a" -> doA(); case "b" -> doB(); }` — the arrow form (`->`) does not fall through and makes the intent explicit.

---

**16. Arrays.asList() Returns a Fixed-Size List**

`Arrays.asList(a, b, c)` returns a `List` implementation backed directly by the array you pass. Because the underlying array cannot change size, calling `add()` or `remove()` on this List throws `UnsupportedOperationException`. The `set()` operation works because replacing an element does not resize the array. If you need a truly mutable list, wrap it: `new ArrayList<>(Arrays.asList(a, b, c))`. In Java 9+, `List.of(a, b, c)` creates an immutable list — even `set()` throws. Know which you need.

---

**17. Collections.sort() vs List.sort()**

Both use TimSort and are O(n log n). `Collections.sort(list)` is a utility method that was added in Java 2; it worked by converting the list to an array, sorting the array, and writing back — creating an intermediate array copy. `List.sort(comparator)` was added in Java 8 as a default method directly on the List interface. It sorts in place without an intermediate copy. For `ArrayList`, `List.sort()` is slightly more efficient. For correctness, both are equivalent. Prefer `list.sort()` in new code.

---

**18. wait() Called in an if Instead of while**

The Java specification explicitly allows spurious wakeups — a thread can return from `wait()` without any other thread having called `notify()`. This is permitted by the OS and hardware for implementation efficiency. If you check your condition in an `if (condition) wait()` pattern, a spurious wakeup will cause your thread to proceed even when the condition is still false, corrupting program state. The correct pattern is always `while (!condition) { wait(); }` — after every wakeup, regardless of cause, re-check whether the condition you need is actually true before proceeding.

---

**19. Thread.stop() Is Unsafe — Use Interruption Instead**

`Thread.stop()` was deprecated in Java 1.1 and removed in Java 20. It works by throwing a `ThreadDeath` error at whatever point in the target thread's execution it happens to be — even in the middle of updating a data structure. This leaves shared mutable state in an inconsistent, unpredictable condition. The safe alternative is cooperative stopping: use a `volatile boolean stopped` flag that the thread checks periodically in its loop (`while (!stopped) { doWork(); }`), or call `thread.interrupt()` which sets the thread's interrupted flag and causes blocking methods like `sleep()`, `wait()`, and `BlockingQueue.take()` to throw `InterruptedException`. The thread must then handle `InterruptedException` by re-setting the flag (`Thread.currentThread().interrupt()`) or by exiting cleanly.

---

**20. long and double Non-Atomicity on 32-Bit JVMs**

The Java Language Specification states that reads and writes of `long` (64-bit) and `double` (64-bit) fields are not guaranteed to be atomic on platforms where the word size is 32 bits. The JVM might split a 64-bit write into two 32-bit writes — a high-word write and a low-word write. Another thread can read between these two writes, seeing a "torn" value where the high bits are from the new value and the low bits are from the old value (or vice versa). On modern 64-bit JVMs this does not happen in practice, but the specification permits it. Declaring a shared `long` or `double` field `volatile` provides an atomicity guarantee that covers both the read and write as a single operation on all platforms.

---

## Section 8: Must-Know Code Snippets

> *Reading guide: These snippets are the patterns you will be asked to write or critique in coding rounds. For each one, understand the context in which you would reach for it, why the implementation works, and the common mistake versions that do not work.*

---

**8.1 Thread-Safe Singleton — Enum (Preferred)**

Use this when you want the simplest, most robust singleton. The JVM initialises enum constants exactly once during class loading, under the class initialisation lock — no synchronisation code is required, it is immune to reflection attacks on the constructor, and serialisation safety is built in. This is the Joshua Bloch recommendation from Effective Java and should be your default singleton approach.

```java
public enum Singleton {
    INSTANCE;
    public void doWork() { /* stateful operations here */ }
}

// Usage
Singleton.INSTANCE.doWork();
```

*Why it works: JVM class initialisation is thread-safe by the Java Language Specification. The INSTANCE constant is set once and never again.*

---

**8.2 Thread-Safe Singleton — Double-Checked Locking**

Use this when lazy initialisation is essential and the enum approach is unsuitable — for example, when the singleton requires constructor arguments that are only known at runtime. The `volatile` keyword is non-negotiable: it prevents the JVM from publishing a partially constructed instance to threads doing the outer null check.

```java
public class Singleton {
    private static volatile Singleton instance;
    private Singleton() {}

    public static Singleton getInstance() {
        if (instance == null) {                      // fast path: no lock
            synchronized (Singleton.class) {
                if (instance == null) {              // re-check after acquiring lock
                    instance = new Singleton();
                }
            }
        }
        return instance;
    }
}
```

*Why it works: the outer check avoids acquiring the lock on every call once the instance is created. The inner check handles the race between multiple threads that all pass the outer check simultaneously. volatile establishes the happens-before that prevents seeing a partially constructed object.*

---

**8.3 Custom Comparator — Multi-Key and Null-Safe Sorting**

Use `Comparator.comparing()` with `thenComparing()` for readable multi-key sorts. Use `Comparator.nullsLast()` when your data might contain null values — attempting to call `compareTo` on null throws NullPointerException.

```java
// Multi-key sort: by department ascending, then by name ascending, then reverse everything
employees.sort(
    Comparator.comparing(Employee::getDept)
              .thenComparing(Employee::getName)
              .reversed()
);

// Null-safe sort: nulls sorted after non-nulls
employees.sort(
    Comparator.comparing(
        Employee::getName,
        Comparator.nullsLast(Comparator.naturalOrder())
    )
);
```

*Why it works: Comparator.comparing() builds a type-safe comparator from a key extractor. thenComparing() adds a secondary key used when the primary comparison returns 0. reversed() inverts the entire chained comparator. nullsLast() wraps a comparator and handles null keys by placing them at the end.*

---

**8.4 Stream groupingBy — Partitioning with Downstream Aggregation**

Use `Collectors.groupingBy()` when you need to bucket a collection by a key and then aggregate within each bucket. The single-argument form collects matching elements into a List; the two-argument form lets you specify a downstream collector for richer aggregations.

```java
// Count employees per department
Map<String, Long> headcountByDept = employees.stream()
    .collect(Collectors.groupingBy(
        Employee::getDept,
        Collectors.counting()
    ));

// Collect employee names per department
Map<String, List<String>> namesByDept = employees.stream()
    .collect(Collectors.groupingBy(
        Employee::getDept,
        Collectors.mapping(Employee::getName, Collectors.toList())
    ));
```

*Why it works: groupingBy creates a Map<K, D> where K is the key produced by the classifier function and D is the result of the downstream collector applied to all elements with that key. counting() is a downstream that returns a Long. mapping() applies a function before passing to the inner downstream collector.*

---

**8.5 CompletableFuture Chain — Async Pipeline with Error Handling**

Use this when you have sequential async operations where each step depends on the result of the previous one. `thenApplyAsync` runs the function on an executor thread. `thenCompose` is used when the function itself returns a CompletableFuture — it flattens the nested future rather than producing `CompletableFuture<CompletableFuture<T>>`. `exceptionally` provides a fallback for any exception in the chain. `whenComplete` runs for both success and failure and is useful for logging and cleanup.

```java
CompletableFuture<String> result = CompletableFuture
    .supplyAsync(() -> fetchUserId())                   // runs on ForkJoinPool.commonPool()
    .thenApplyAsync(id -> fetchUserName(id))            // transforms the result async
    .thenCompose(name -> fetchProfile(name))            // flatMap: name -> CF<Profile>
    .thenApply(Profile::getSummary)                     // transforms synchronously
    .exceptionally(ex -> "default-summary")             // fallback if any step threw
    .whenComplete((val, ex) -> log(val, ex));           // runs always, for logging

String summary = result.get(5, TimeUnit.SECONDS);       // block with timeout
```

*Why thenCompose instead of thenApply for the profile fetch: fetchProfile(name) returns a CompletableFuture<Profile>. thenApply would give you CompletableFuture<CompletableFuture<Profile>> — a nested future you cannot easily work with. thenCompose flattens it to CompletableFuture<Profile>.*

---

**8.6 Producer-Consumer with BlockingQueue**

Use `ArrayBlockingQueue` for a bounded buffer that provides natural backpressure — producers block when the buffer is full, automatically slowing down to match consumer speed. Always handle `InterruptedException` by re-setting the interrupt flag with `Thread.currentThread().interrupt()` and exiting cleanly — swallowing the exception without re-interrupting is a common bug that causes threads to ignore shutdown signals.

```java
BlockingQueue<Integer> queue = new ArrayBlockingQueue<>(10);

Runnable producer = () -> {
    for (int i = 0; i < 100; i++) {
        try {
            queue.put(i);                                    // blocks if queue is full
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();              // restore interrupt flag
            break;
        }
    }
};

Runnable consumer = () -> {
    while (!Thread.currentThread().isInterrupted()) {
        try {
            Integer item = queue.poll(1, TimeUnit.SECONDS); // wait up to 1s for an item
            if (item == null) break;                        // timeout — no more items
            process(item);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();              // restore and exit loop
        }
    }
};

ExecutorService pool = Executors.newFixedThreadPool(2);
pool.submit(producer);
pool.submit(consumer);
```

*Why poll with timeout instead of take: take() blocks indefinitely. poll(1, SECONDS) returns null after a timeout, letting the consumer check whether to exit — useful for graceful shutdown.*

---

**8.7 Deadlock Example and Fix via Consistent Lock Ordering**

The deadlock below is a textbook circular wait: thread t1 acquires lockA and then tries to acquire lockB, while thread t2 acquires lockB and then tries to acquire lockA. Each thread holds the lock the other needs. The fix requires establishing a global lock ordering — both threads must always acquire locks in the same sequence (lockA before lockB). This eliminates the circular wait condition that is required for deadlock to occur.

```java
Object lockA = new Object();
Object lockB = new Object();

// DEADLOCK: t1 holds lockA, waits for lockB
//           t2 holds lockB, waits for lockA
Thread t1 = new Thread(() -> {
    synchronized (lockA) {
        synchronized (lockB) { /* work */ }
    }
});
Thread t2 = new Thread(() -> {
    synchronized (lockB) {       // acquires lockB first — opposite order from t1
        synchronized (lockA) { /* work */ }
    }
});

// FIX: both threads acquire locks in the same order (lockA always before lockB)
Thread t1Fixed = new Thread(() -> {
    synchronized (lockA) {
        synchronized (lockB) { /* work */ }
    }
});
Thread t2Fixed = new Thread(() -> {
    synchronized (lockA) {       // now both threads acquire lockA first
        synchronized (lockB) { /* work */ }
    }
});
```

*Why consistent ordering prevents deadlock: if every thread that needs both locks always acquires lockA before lockB, the circular wait condition cannot form. The thread that acquires lockA first will proceed to acquire lockB without contention, complete its work, and release both locks.*

---

## Quick Reference Card

### Big-O Complexity Table

| Collection | Access by Index | Search (unsorted) | Insert | Delete | Notes |
|---|---|---|---|---|---|
| **ArrayList** | O(1) | O(n) | O(1) amortised (tail), O(n) (mid) | O(n) | Backed by array; random access by index is instant; mid-insert shifts elements |
| **LinkedList** | O(n) | O(n) | O(1) with iterator position | O(1) with iterator position | No random access; good for frequent mid-list inserts/deletes if you hold iterator |
| **HashMap** | N/A | O(1) average | O(1) average | O(1) average | O(n) worst case (hash collision degenerate to list; rare with good hashCode) |
| **TreeMap** | N/A | O(log n) | O(log n) | O(log n) | Red-black BST; keys always sorted; use when you need ceiling/floor/range operations |
| **PriorityQueue** | O(n) find, O(1) peek | O(n) | O(log n) | O(log n) (remove head); O(n) arbitrary | Min-heap by default; peek/poll gives minimum; no O(1) access to arbitrary elements |
| **HashSet** | N/A | O(1) average | O(1) average | O(1) average | Backed by HashMap; same characteristics |
| **LinkedHashMap** | N/A | O(1) average | O(1) average | O(1) average | Like HashMap but maintains insertion order; slight memory overhead for doubly-linked list |

---

### Java Version Timeline — Key Features for Backend Interviews

| Version | Released | Headline Features You Must Know |
|---|---|---|
| **Java 8** | March 2014 | Lambda expressions and functional interfaces; Stream API; Optional<T>; default methods on interfaces; CompletableFuture; new Date/Time API (java.time); Metaspace replaced PermGen; Nashorn JS engine |
| **Java 9** | September 2017 | Java Platform Module System (JPMS / Project Jigsaw); G1 becomes default GC; JShell (REPL); Reactive Streams with Flow API; immutable factory methods List.of(), Set.of(), Map.of() |
| **Java 10** | March 2018 | Local variable type inference with `var`; Container-awareness for GC sizing (-XX:+UseContainerSupport enabled by default) |
| **Java 11** | September 2018 (LTS) | HTTP Client API (java.net.http, replacing deprecated HttpURLConnection); String methods: isBlank(), lines(), strip(), repeat(); running single-file programs with `java File.java`; removal of Java EE and CORBA modules |
| **Java 14** | March 2020 | Switch expressions (standard, not preview); helpful NullPointerExceptions with precise message ("Cannot read field x because obj is null"); Records as preview |
| **Java 15** | September 2020 | ZGC production-stable (no longer experimental); Shenandoah GC production-stable; Text blocks (multiline string literals) standardised |
| **Java 16** | March 2021 | Records (standard); Pattern matching for instanceof (standard — no more explicit cast after instanceof check); Unix domain socket channel support |
| **Java 17** | September 2021 (LTS) | Sealed classes and interfaces (restrict which classes can extend); Pattern matching for instanceof standardised; strong encapsulation of JDK internals by default; removal of RMI activation |
| **Java 21** | September 2023 (LTS) | Virtual threads / Project Loom (standard); Record patterns; Pattern matching for switch (standard); Sequenced collections (SequencedCollection, SequencedMap with defined encounter order and first/last access); String templates (preview) |

---

*LTS = Long-Term Support, receiving security and stability updates for 8+ years. For production systems, always deploy an LTS version. The current LTS versions are Java 11, Java 17, and Java 21.*

