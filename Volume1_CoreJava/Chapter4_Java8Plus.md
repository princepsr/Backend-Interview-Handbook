# Chapter 4: Java 8+ Features — Lambdas, Streams, Optional, and Modern Java

> Java 17 LTS baseline. Java 21 notes included where relevant. Target: SDE2 candidates at FAANG+, FinTech, and SaaS/Enterprise companies.

---

## Table of Contents

1. [Lambdas](#lambdas)
   - Lambda Expressions
   - Method References
2. [Functional Interfaces](#functional-interfaces)
   - Built-in Functional Interfaces
   - Custom Functional Interfaces
3. [Streams](#streams)
   - Stream Pipeline and Lazy Evaluation
   - Intermediate Operations
   - Terminal Operations
   - Collectors
   - Stream vs Collection
   - Parallel Streams
   - Primitive Streams
   - Stream Reuse
   - Infinite Streams
4. [Optional](#optional)
   - Optional Basics
   - Optional Methods
   - orElse vs orElseGet
5. [CompletableFuture](#completablefuture)
   - Basics
   - Combining Futures
   - CompletableFuture vs Future
   - Exception Handling
   - Parallel API Calls Pattern
6. [Java 9–17 Key Additions](#java-9-17-key-additions)
   - var keyword
   - Records
   - Sealed Classes
   - Text Blocks
   - Pattern Matching instanceof
7. [Streams Cheat Sheet](#streams-cheat-sheet)

---

## Lambdas

### Q1: What are lambda expressions and how does the compiler handle them?

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Microsoft, Goldman Sachs, JPMorgan, Stripe, Uber, Atlassian

**Short Answer (30–60 seconds)**

A lambda expression is a concise way to represent an instance of a functional interface — an interface with exactly one abstract method. The compiler does not generate a new `.class` file for each lambda. Instead, it uses the `invokedynamic` bytecode instruction (introduced in Java 7) with a runtime bootstrap mechanism (`LambdaMetafactory`) to create the implementation at runtime. This is more efficient than anonymous inner classes.

**Deep Explanation**

Prior to Java 8, the idiomatic way to pass behavior was through anonymous inner classes. Each anonymous class produces a separate `.class` file (e.g., `Outer$1.class`), which has memory and class-loading overhead.

Lambda expressions change this at the bytecode level:
1. The compiler emits an `invokedynamic` call site in the bytecode.
2. On first invocation, the JVM calls the bootstrap method `LambdaMetafactory.metafactory()`.
3. `LambdaMetafactory` generates the functional interface implementation at runtime, typically as a hidden class.
4. Subsequent calls hit a CallSite that is linked directly, eliminating repeated bootstrap overhead.

**Variable Capture and Effectively Final**

Lambdas can capture:
- Instance variables and static variables freely.
- Local variables **only if effectively final** — the variable is never reassigned after initialization.

The "effectively final" rule exists because local variables live on the stack. If the lambda outlives the method (e.g., passed to another thread), the variable must be copied into the lambda's closure. Allowing mutation would introduce race conditions and semantic confusion.

```java
// ILLEGAL — i is not effectively final
int i = 0;
Runnable r = () -> System.out.println(i); // compile error if i is later modified
i++;

// LEGAL — i is effectively final
int i = 0;
Runnable r = () -> System.out.println(i); // fine, i never changes
```

**Real-World Backend Example**

In a Spring service layer, lambdas are ubiquitous with streams, Optional, and CompletableFuture:

```java
List<Order> activeOrders = orders.stream()
    .filter(order -> order.getStatus() == OrderStatus.ACTIVE)
    .collect(Collectors.toList());
```

**Java 17 Code Example**

```java
import java.util.function.Function;
import java.util.function.Predicate;

public class LambdaDemo {

    public static void main(String[] args) {
        // Lambda as Predicate<String>
        Predicate<String> isLongName = name -> name.length() > 5;

        // Lambda as Function<String, Integer>
        Function<String, Integer> nameLength = name -> name.length();

        // Multi-line lambda body
        Function<Integer, String> classify = n -> {
            if (n < 0) return "negative";
            if (n == 0) return "zero";
            return "positive";
        };

        System.out.println(isLongName.test("Alexander")); // true
        System.out.println(nameLength.apply("Java"));     // 4
        System.out.println(classify.apply(-5));            // negative

        // Lambda capturing effectively final local variable
        String prefix = "ORDER-";
        Function<Long, String> orderId = id -> prefix + id;
        System.out.println(orderId.apply(1001L)); // ORDER-1001
    }
}
```

**Follow-up Questions**

- "What is `invokedynamic`? How does it differ from `invokevirtual`?"
- "Why can lambdas not capture mutable local variables?"
- "Is a lambda a new object created every time it is evaluated?"
- "What is the difference between a lambda and an anonymous inner class regarding `this`?"
- "Can a lambda throw a checked exception?"

**Common Mistakes**

- Assuming lambdas are syntactic sugar for anonymous classes — they differ at the bytecode level and in the meaning of `this`.
- Trying to assign to a local variable inside a lambda (`i++` inside lambda body).
- Throwing checked exceptions without wrapping — lambda body must declare or handle checked exceptions matching the functional interface signature.

**Interview Traps**

- In a lambda, `this` refers to the enclosing class instance, not the lambda itself. In an anonymous inner class, `this` refers to the anonymous class instance.
- Lambdas are not always a new object — the JVM may cache stateless lambdas (no captured variables) as a singleton.

**Quick Revision Notes**

- Lambda = instance of a functional interface, compiled via `invokedynamic`.
- No separate `.class` file per lambda; runtime linkage via `LambdaMetafactory`.
- Captured local variables must be effectively final.
- `this` inside a lambda = enclosing class.
- Stateless lambdas may be cached as singletons by the JVM.

---

### Q2: What are method references and what are the four types?

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Goldman Sachs, Atlassian, Netflix, Spotify

**Short Answer (30–60 seconds)**

Method references are shorthand for lambdas that do nothing but call an existing method. There are four types: static method reference, instance method reference on a specific object, instance method reference on an arbitrary object of a particular type, and constructor reference.

**Deep Explanation**

Method references improve readability when the lambda body is a direct method call. The compiler resolves them to the same `invokedynamic` mechanism as lambdas.

| Type | Syntax | Lambda Equivalent |
|---|---|---|
| Static method | `Integer::parseInt` | `s -> Integer.parseInt(s)` |
| Instance — specific object | `str::toLowerCase` | `() -> str.toLowerCase()` |
| Instance — arbitrary object | `String::toLowerCase` | `s -> s.toLowerCase()` |
| Constructor | `ArrayList::new` | `() -> new ArrayList<>()` |

**Distinguishing Type 2 vs Type 3:**
- Type 2: The object is **captured** (already known). The reference is `instance::method`.
- Type 3: The object is **the first parameter** supplied at invocation. The reference is `ClassName::method`. The method receives the object as its implicit first argument.

**Real-World Backend Example**

```java
// Type 3 is especially useful with streams
List<String> names = List.of("alice", "bob", "carol");
List<String> upper = names.stream()
    .map(String::toUpperCase)  // instance method on arbitrary String object
    .collect(Collectors.toList());
```

**Java 17 Code Example**

```java
import java.util.*;
import java.util.function.*;
import java.util.stream.*;

public class MethodReferenceDemo {

    static String addPrefix(String s) {
        return "PREFIX_" + s;
    }

    public static void main(String[] args) {
        // 1. Static method reference
        Function<String, Integer> parser = Integer::parseInt;
        System.out.println(parser.apply("42")); // 42

        // 2. Instance method reference on a specific object
        String delimiter = ", ";
        BinaryOperator<String> joiner = delimiter::concat; // not typical but valid
        // More realistic:
        List<String> log = new ArrayList<>();
        Consumer<String> logger = log::add;
        logger.accept("event1");
        logger.accept("event2");
        System.out.println(log); // [event1, event2]

        // 3. Instance method reference on arbitrary object of a type
        List<String> ids = List.of("user-1", "user-2", "user-3");
        List<String> upper = ids.stream()
            .map(String::toUpperCase)
            .collect(Collectors.toList());
        System.out.println(upper); // [USER-1, USER-2, USER-3]

        // Also works for static methods on this class
        List<String> prefixed = ids.stream()
            .map(MethodReferenceDemo::addPrefix)
            .collect(Collectors.toList());
        System.out.println(prefixed);

        // 4. Constructor reference
        Supplier<List<String>> listFactory = ArrayList::new;
        List<String> newList = listFactory.get();
        newList.add("hello");
        System.out.println(newList);
    }
}
```

**Follow-up Questions**

- "When would you prefer a lambda over a method reference?"
- "Can you use a method reference for a method that throws a checked exception?"
- "What functional interface would `String::valueOf` correspond to?"

**Common Mistakes**

- Confusing Type 2 and Type 3 — the difference is whether the object is captured or passed as the first argument.
- Using method references where the lambda has additional logic, making the code less clear.

**Interview Traps**

- `String::compareTo` is a Type 3 reference. It corresponds to `Comparator<String>` because `compareTo` takes one argument and the object (the first string) is the implicit receiver. This confuses candidates who expect a `BiFunction`.

**Quick Revision Notes**

- 4 types: static, instance on specific, instance on arbitrary, constructor.
- Type 3: `ClassName::instanceMethod` — the stream element is the receiver.
- Method references are compiled identically to equivalent lambdas.
- Prefer method references for readability when no extra logic is needed.

---

## Functional Interfaces

### Q3: What are the built-in functional interfaces in Java 8?

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Microsoft, Goldman Sachs, JPMorgan, Stripe, Uber

**Short Answer (30–60 seconds)**

Java 8 introduced a set of general-purpose functional interfaces in `java.util.function`. The core ones are: `Function<T,R>` (transforms T to R), `Predicate<T>` (tests T, returns boolean), `Consumer<T>` (consumes T, returns void), `Supplier<T>` (produces T, takes no input), `UnaryOperator<T>` (Function where T==R), and `BinaryOperator<T>` (BiFunction where all types are T).

**Deep Explanation**

| Interface | Signature | Use case |
|---|---|---|
| `Function<T,R>` | `R apply(T t)` | Transform/map values |
| `BiFunction<T,U,R>` | `R apply(T t, U u)` | Two-input transform |
| `Predicate<T>` | `boolean test(T t)` | Filter / condition check |
| `BiPredicate<T,U>` | `boolean test(T t, U u)` | Two-input condition |
| `Consumer<T>` | `void accept(T t)` | Side effects (logging, DB write) |
| `BiConsumer<T,U>` | `void accept(T t, U u)` | Two-input side effect |
| `Supplier<T>` | `T get()` | Lazy value production, factories |
| `UnaryOperator<T>` | `T apply(T t)` | In-place transformation |
| `BinaryOperator<T>` | `T apply(T t1, T t2)` | Reduction, combining same-type values |

**Composition Methods**

`Function` provides `andThen()` and `compose()`:
- `f.andThen(g)` = `x -> g(f(x))` (f first, then g)
- `f.compose(g)` = `x -> f(g(x))` (g first, then f)

`Predicate` provides `and()`, `or()`, `negate()`:
```java
Predicate<String> notEmpty = s -> !s.isEmpty();
Predicate<String> shortEnough = s -> s.length() < 20;
Predicate<String> valid = notEmpty.and(shortEnough);
```

**Real-World Backend Example**

In a payment processing pipeline:

```java
Function<Transaction, Transaction> applyFee = tx ->
    new Transaction(tx.id(), tx.amount() - calculateFee(tx));

Function<Transaction, Transaction> applyTax = tx ->
    new Transaction(tx.id(), tx.amount() - calculateTax(tx));

Function<Transaction, Transaction> pipeline = applyFee.andThen(applyTax);
Transaction result = pipeline.apply(rawTransaction);
```

**Java 17 Code Example**

```java
import java.util.function.*;

public class FunctionalInterfaceDemo {

    public static void main(String[] args) {
        // Function: transform
        Function<String, Integer> length = String::length;
        Function<Integer, String> intToStr = Object::toString;
        Function<String, String> lengthAsStr = length.andThen(intToStr);
        System.out.println(lengthAsStr.apply("hello")); // "5"

        // Predicate: filter with composition
        Predicate<Integer> isPositive = n -> n > 0;
        Predicate<Integer> isEven = n -> n % 2 == 0;
        Predicate<Integer> isPositiveEven = isPositive.and(isEven);
        System.out.println(isPositiveEven.test(4));  // true
        System.out.println(isPositiveEven.test(-4)); // false

        // Consumer: side effect chaining
        Consumer<String> print = System.out::println;
        Consumer<String> audit = s -> System.out.println("AUDIT: " + s);
        Consumer<String> both = print.andThen(audit);
        both.accept("payment processed");

        // Supplier: lazy initialization
        Supplier<List<String>> listSupplier = ArrayList::new;
        List<String> list = listSupplier.get();

        // UnaryOperator
        UnaryOperator<String> trim = String::trim;
        UnaryOperator<String> upper = String::toUpperCase;
        Function<String, String> normalize = trim.andThen(upper);
        System.out.println(normalize.apply("  hello world  ")); // HELLO WORLD

        // BinaryOperator
        BinaryOperator<Integer> add = Integer::sum;
        System.out.println(add.apply(3, 4)); // 7
    }
}
```

**Follow-up Questions**

- "What is the difference between `Function.andThen()` and `Function.compose()`?"
- "Why does `Consumer` have `andThen()` but not `compose()`?"
- "When would you use `Supplier` instead of just calling a method directly?"
- "What is `BiFunction` and when would you use it?"

**Common Mistakes**

- Confusing `andThen` and `compose` order of execution.
- Using `Consumer` where a `Function` is needed — confusing void return vs. value return.
- Not using `Predicate.not()` (Java 11) for negation: `Predicate.not(String::isEmpty)`.

**Interview Traps**

- `Supplier` is critical for lazy evaluation — `orElseGet(supplier)` vs `orElse(value)` is a classic interview trap (covered in the Optional section).
- `UnaryOperator<T>` extends `Function<T,T>` — you can pass a `UnaryOperator` anywhere a `Function<T,T>` is expected.

**Quick Revision Notes**

- Function=transform, Predicate=test, Consumer=side-effect, Supplier=produce, Operator=same-type transform.
- `andThen` = apply this first, then the argument. `compose` = apply argument first, then this.
- `Predicate.not()` available from Java 11.
- All are `@FunctionalInterface` with one abstract method.

---

### Q4: How do you create a custom functional interface?

**Difficulty:** Easy | **Interview Frequency:** Medium

**Companies:** Goldman Sachs, JPMorgan, Atlassian

**Short Answer (30–60 seconds)**

A functional interface is any interface with exactly one abstract method. The `@FunctionalInterface` annotation is optional but recommended — it makes the compiler enforce the single-abstract-method constraint and documents intent. The interface can have any number of default and static methods.

**Deep Explanation**

Rules for functional interfaces:
1. Exactly one abstract method (the "functional method").
2. May have multiple `default` methods.
3. May have multiple `static` methods.
4. Methods inherited from `Object` (like `equals`, `toString`) do not count as abstract methods.

The `@FunctionalInterface` annotation causes a compile error if the interface has zero or more than one abstract method.

**Real-World Backend Example**

Custom functional interfaces are useful for domain-specific operations that don't fit the standard library:

```java
@FunctionalInterface
public interface ThrowingFunction<T, R> {
    R apply(T t) throws Exception;

    static <T, R> Function<T, R> wrap(ThrowingFunction<T, R> f) {
        return t -> {
            try {
                return f.apply(t);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        };
    }
}
```

**Java 17 Code Example**

```java
import java.util.function.Function;

@FunctionalInterface
interface TriFunction<A, B, C, R> {
    R apply(A a, B b, C c);

    // Default method is allowed
    default <V> TriFunction<A, B, C, V> andThen(Function<? super R, ? extends V> after) {
        return (a, b, c) -> after.apply(this.apply(a, b, c));
    }
}

public class CustomFunctionalInterfaceDemo {

    public static void main(String[] args) {
        TriFunction<String, Integer, Boolean, String> formatter =
            (name, score, passed) ->
                String.format("Candidate: %s, Score: %d, Result: %s",
                    name, score, passed ? "PASS" : "FAIL");

        System.out.println(formatter.apply("Alice", 85, true));
        // Candidate: Alice, Score: 85, Result: PASS

        // Using ThrowingFunction wrapper for checked exceptions in streams
        List<String> urls = List.of("https://api.example.com/orders");
        // urls.stream().map(url -> fetchData(url)) // won't compile if fetchData throws
        // urls.stream().map(ThrowingFunction.wrap(url -> fetchData(url))); // works
    }
}
```

**Follow-up Questions**

- "Can a functional interface extend another interface?"
- "What happens if two interfaces each have one abstract method and a class implements both?"

**Common Mistakes**

- Forgetting that `@FunctionalInterface` is optional — the annotation is documentation and enforcement, not a requirement.
- Adding a second abstract method and wondering why lambdas no longer compile.

**Interview Traps**

- An interface that extends another interface can still be functional if the parent's abstract method is the only one inherited (or the child overrides the parent method with the same signature). The `Comparator<T>` interface is technically functional even though it has many methods, because `equals(Object)` from `Object` does not count.

**Quick Revision Notes**

- One abstract method = functional interface, regardless of `@FunctionalInterface`.
- `@FunctionalInterface` enforces the constraint at compile time.
- Default and static methods are allowed.
- `Object` methods don't count as abstract.

---

## Streams

### Q5: How does a stream pipeline work? What is lazy evaluation?

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Stripe, Netflix, Goldman Sachs, Uber, Atlassian

**Short Answer (30–60 seconds)**

A stream pipeline has three parts: a source, zero or more intermediate operations, and a terminal operation. Intermediate operations are lazy — they do not execute until a terminal operation is invoked. This allows the JVM to fuse operations and avoid creating intermediate collections, which improves performance especially with `limit()` or `findFirst()`.

**Deep Explanation**

**Pipeline Stages**

1. **Source:** `collection.stream()`, `Stream.of(...)`, `Files.lines(path)`, etc. Creates a `Spliterator` which defines how to traverse and split the data.
2. **Intermediate operations:** Each returns a new `Stream`. They build up a pipeline description (a chain of `ReferencePipeline` stages internally), but execute no element processing.
3. **Terminal operation:** Triggers traversal. The terminal operation pulls elements through all pipeline stages one element (or chunk) at a time.

**Spliterator**

`Spliterator<T>` is the iterator abstraction used internally by streams. It supports:
- `tryAdvance()` — process one element.
- `trySplit()` — split for parallel processing.
- Characteristics (`SIZED`, `ORDERED`, `DISTINCT`, `SORTED`, `IMMUTABLE`, `CONCURRENT`, `NONNULL`, `SUBSIZED`).

Characteristics affect optimization: for example, if a stream is `SIZED`, `count()` can short-circuit without traversal.

**Lazy Evaluation in Practice**

Without lazy evaluation:
- `filter()` would produce a new list.
- `map()` would produce another new list.
- Every intermediate step allocates memory.

With lazy evaluation:
- The pipeline fuses: for each element, filter → map → terminal are executed before moving to the next element.
- `limit(n)` can stop the source after `n` elements pass the filter, even for potentially infinite sources.

```java
// Without limit: would process all 1 million elements
// With limit: stops as soon as 5 elements pass the filter
List<Integer> result = IntStream.range(0, 1_000_000)
    .filter(n -> n % 2 == 0)
    .limit(5)
    .boxed()
    .collect(Collectors.toList()); // [0, 2, 4, 6, 8]
```

**Real-World Backend Example**

Processing a large paginated result from a database without loading everything:

```java
// Stream from a large dataset — lazy processing avoids loading all records
Stream<Order> orderStream = orderRepository.findAllAsStream();
Optional<Order> firstHighValue = orderStream
    .filter(order -> order.getAmount().compareTo(BigDecimal.valueOf(10000)) > 0)
    .findFirst(); // stops as soon as first match is found
```

**Java 17 Code Example**

```java
import java.util.List;
import java.util.stream.*;

public class LazyEvaluationDemo {

    public static void main(String[] args) {
        List<Integer> numbers = List.of(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

        // Demonstrate laziness with peek (side-effect for debugging only)
        List<Integer> result = numbers.stream()
            .filter(n -> {
                System.out.println("filter: " + n);
                return n % 2 == 0;
            })
            .map(n -> {
                System.out.println("map: " + n);
                return n * n;
            })
            .limit(3)
            .collect(Collectors.toList());

        System.out.println(result);
        // Output shows filter and map are called element-by-element,
        // and stops after 3 elements pass (not all 10 are processed).
    }
}
```

**Follow-up Questions**

- "What is a `Spliterator`? How is it different from `Iterator`?"
- "If I have `filter().map().filter()`, how many passes does the stream make over the data?"
- "What happens if I call a terminal operation on a stream that has already been consumed?"
- "Why does `peek()` sometimes not fire in production? (Hint: short-circuiting)"

**Common Mistakes**

- Assuming intermediate operations execute immediately.
- Using `peek()` for production logging assuming it always fires — it is skipped with short-circuit terminals.
- Forgetting that streams are single-use.

**Interview Traps**

- A pipeline with only intermediate operations does nothing. `stream.filter(...).map(...)` alone produces no output and processes no elements until a terminal operation is added. This is a common debugging trap.
- `sorted()` is a stateful intermediate operation — it must buffer all elements before producing any output, breaking the "one element at a time" fusion for that stage.

**Quick Revision Notes**

- Source → Intermediate (lazy, builds pipeline) → Terminal (triggers execution).
- Lazy evaluation = no intermediate collections, elements processed one at a time.
- `sorted()`, `distinct()` are stateful — they buffer; short-circuit fusion breaks there.
- `Spliterator` is the internal traversal mechanism supporting parallel split.
- One terminal operation per stream; reuse throws `IllegalStateException`.


---

### Q6: What are intermediate operations in streams? Explain map vs flatMap.

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Goldman Sachs, Stripe, Netflix, Uber

**Short Answer (30"“60 seconds)**

Intermediate operations return a new Stream and are lazy "” they don't execute until a terminal operation triggers the pipeline. Key ones: `filter` (keep elements matching predicate), `map` (transform each element), `flatMap` (transform each element to a stream and flatten one level), `sorted`, `distinct`, `limit`, `skip`, `peek`.

`map` produces one output element per input element. `flatMap` produces zero or more output elements per input, flattening the resulting streams into one stream.

**Deep Explanation**

**map vs flatMap "” the critical difference:**

`map(f)` applies `f` to each element: `Stream<T>` â†’ `Stream<R>`.
`flatMap(f)` applies `f` to each element where `f` returns a `Stream<R>`, then flattens all those streams: `Stream<T>` â†’ `Stream<Stream<R>>` â†’ `Stream<R>`.

Analogy: `map` is like multiplying each item by a factor. `flatMap` is like replacing each item with a list of items, then removing the outer list.

**Stateful vs Stateless:**
- Stateless: `filter`, `map`, `flatMap`, `peek` "” process each element independently.
- Stateful: `sorted`, `distinct`, `limit`, `skip` "” require knowledge of other elements. `sorted` and `distinct` must buffer; `limit` and `skip` maintain a counter.

**Complete List of Intermediate Operations:**

| Operation | Type | Description |
|---|---|---|
| `filter(Predicate)` | Stateless | Keep elements matching predicate |
| `map(Function)` | Stateless | Transform each element |
| `flatMap(Function<T, Stream<R>>)` | Stateless | Transform and flatten |
| `mapToInt/Long/Double` | Stateless | Map to primitive stream |
| `distinct()` | Stateful (buffered) | Remove duplicates using equals/hashCode |
| `sorted()` / `sorted(Comparator)` | Stateful (buffered) | Sort all elements |
| `limit(n)` | Short-circuit, stateful | Keep only first n elements |
| `skip(n)` | Stateful | Skip first n elements |
| `peek(Consumer)` | Stateless | Side effect, passes element through |
| `takeWhile(Predicate)` | Short-circuit (Java 9) | Take while predicate true |
| `dropWhile(Predicate)` | Stateful (Java 9) | Drop while predicate true |

**Real-World Backend Example**

Orders with multiple line items "” flattening to get all products across all orders:

```java
List<Order> orders = getOrders();

// Each order has a list of LineItems
// map would give Stream<List<LineItem>> "” not useful
// flatMap gives Stream<LineItem> "” flat list of all items

List<String> allProductIds = orders.stream()
    .flatMap(order -> order.getLineItems().stream())
    .map(LineItem::getProductId)
    .distinct()
    .sorted()
    .collect(Collectors.toList());
```

**Java 17 Code Example**

```java
import java.util.*;
import java.util.stream.*;

public class IntermediateOpsDemo {

    record LineItem(String productId, int quantity) {}
    record Order(String orderId, List<LineItem> lineItems) {}

    public static void main(String[] args) {
        List<Order> orders = List.of(
            new Order("O1", List.of(new LineItem("P1", 2), new LineItem("P2", 1))),
            new Order("O2", List.of(new LineItem("P2", 3), new LineItem("P3", 5))),
            new Order("O3", List.of(new LineItem("P1", 1)))
        );

        // map: one-to-one transform
        List<String> orderIds = orders.stream()
            .map(Order::orderId)
            .collect(Collectors.toList());
        System.out.println("Order IDs: " + orderIds);

        // flatMap: one-to-many, then flatten
        List<String> allProductIds = orders.stream()
            .flatMap(order -> order.lineItems().stream())
            .map(LineItem::productId)
            .distinct()
            .sorted()
            .collect(Collectors.toList());
        System.out.println("All product IDs: " + allProductIds); // [P1, P2, P3]

        // Total quantity across all orders for product P2
        int totalP2 = orders.stream()
            .flatMap(order -> order.lineItems().stream())
            .filter(item -> item.productId().equals("P2"))
            .mapToInt(LineItem::quantity)
            .sum();
        System.out.println("Total P2 quantity: " + totalP2); // 4

        // flatMap on Optional (common pattern)
        Optional<Optional<String>> nested = Optional.of(Optional.of("value"));
        Optional<String> flat = nested.flatMap(inner -> inner);
        System.out.println(flat.get()); // value

        // peek for debugging (not production logging)
        List<String> result = List.of("  hello ", " world ", "java ")
            .stream()
            .peek(s -> System.out.println("before: '" + s + "'"))
            .map(String::trim)
            .peek(s -> System.out.println("after: '" + s + "'"))
            .filter(s -> s.length() > 4)
            .collect(Collectors.toList());
        System.out.println(result);
    }
}
```

**Follow-up Questions**

- "What does `flatMap` do internally at the stream pipeline level?"
- "Can `flatMap` return an empty stream for some elements? What happens to those?"
- "What is the difference between `map(Optional::of).flatMap(...)` and just `map(...)`?"
- "Why is `sorted()` expensive on a parallel stream?"

**Common Mistakes**

- Using `map` when `flatMap` is needed, resulting in `Stream<List<T>>` instead of `Stream<T>`.
- Relying on `peek` for logging in production "” it may not fire on all elements due to short-circuiting.
- Calling `sorted()` on large parallel streams "” it requires gathering all elements, negating parallelism benefits.

**Interview Traps**

- `flatMap` with an empty stream for an element effectively filters that element out:
  `stream.flatMap(x -> x.isEmpty() ? Stream.empty() : Stream.of(x))` is equivalent to `stream.filter(x -> !x.isEmpty())` but is less readable.
- `distinct()` uses `equals()` and `hashCode()`. If your objects don't override these, it does nothing useful.

**Quick Revision Notes**

- `map` = 1-to-1. `flatMap` = 1-to-many, flattens one level.
- `sorted`, `distinct` are stateful and buffer all elements before emitting.
- `limit`, `skip` are short-circuit capable.
- `peek` is for debugging only; never rely on it for logic.
- `takeWhile`/`dropWhile` added in Java 9.

---

### Q7: What are terminal operations in streams?

**Difficulty:** Easy"“Medium | **Interview Frequency:** High

**Companies:** Amazon, Stripe, Goldman Sachs, Atlassian

**Short Answer (30"“60 seconds)**

Terminal operations trigger the execution of the stream pipeline and produce a result or side effect. After a terminal operation, the stream is consumed and cannot be reused. Common ones: `collect`, `forEach`, `reduce`, `count`, `findFirst`, `findAny`, `anyMatch`, `allMatch`, `noneMatch`, `min`, `max`, `toArray`.

**Deep Explanation**

Terminal operations fall into three categories:

1. **Reducing to a single value:** `reduce`, `count`, `min`, `max`, `sum` (primitive streams)
2. **Collecting into a container:** `collect(Collector)`, `toArray()`
3. **Short-circuit:** `findFirst`, `findAny`, `anyMatch`, `allMatch`, `noneMatch` "” may not process all elements

**Short-circuit semantics:**
- `anyMatch(p)` returns `true` as soon as one element matches.
- `allMatch(p)` returns `false` as soon as one element fails.
- `noneMatch(p)` returns `false` as soon as one element matches.
- `findFirst()` returns the first element; `findAny()` is non-deterministic (useful for parallel streams).

**reduce:**
`reduce(identity, BinaryOperator)` folds the stream into a single value. The identity must be a neutral element (0 for addition, 1 for multiplication, `""` for string concat). Without an identity, returns `Optional<T>`.

**Real-World Backend Example**

```java
List<Transaction> transactions = getTransactions();

// reduce to sum amounts
BigDecimal total = transactions.stream()
    .map(Transaction::getAmount)
    .reduce(BigDecimal.ZERO, BigDecimal::add);

// findFirst for early exit
Optional<Transaction> suspicious = transactions.stream()
    .filter(t -> t.getAmount().compareTo(BigDecimal.valueOf(50000)) > 0)
    .findFirst();

// anyMatch for existence check
boolean hasRefunds = transactions.stream()
    .anyMatch(t -> t.getType() == TransactionType.REFUND);
```

**Java 17 Code Example**

```java
import java.util.*;
import java.util.stream.*;

public class TerminalOpsDemo {

    public static void main(String[] args) {
        List<Integer> numbers = List.of(3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5);

        // count
        long count = numbers.stream().filter(n -> n > 3).count();
        System.out.println("count > 3: " + count); // 5

        // min, max
        Optional<Integer> max = numbers.stream().max(Integer::compareTo);
        System.out.println("max: " + max.orElseThrow()); // 9

        // reduce with identity
        int sum = numbers.stream().reduce(0, Integer::sum);
        System.out.println("sum: " + sum); // 44

        // reduce without identity "” returns Optional
        Optional<Integer> product = numbers.stream()
            .reduce((a, b) -> a * b);
        System.out.println("product present: " + product.isPresent());

        // anyMatch, allMatch, noneMatch
        System.out.println(numbers.stream().anyMatch(n -> n > 8));  // true
        System.out.println(numbers.stream().allMatch(n -> n > 0));  // true
        System.out.println(numbers.stream().noneMatch(n -> n > 10)); // true

        // findFirst vs findAny
        Optional<Integer> first = numbers.stream().filter(n -> n > 4).findFirst();
        System.out.println("first > 4: " + first.orElseThrow()); // 5

        // forEach "” side effect
        numbers.stream().distinct().sorted().forEach(System.out::println);

        // toArray
        Object[] arr = numbers.stream().distinct().toArray();
        Integer[] typedArr = numbers.stream().distinct().toArray(Integer[]::new);
    }
}
```

**Follow-up Questions**

- "What is the difference between `findFirst` and `findAny`? When does it matter?"
- "What happens if you call `reduce` on an empty stream without an identity value?"
- "Is `forEach` guaranteed to process elements in order?"

**Common Mistakes**

- Using `reduce` without understanding the identity requirement "” passing a wrong identity corrupts results.
- Assuming `findAny` returns a random element "” it returns any convenient element, often the first in sequential streams.

**Interview Traps**

- `forEach` on a sequential stream preserves order; on a parallel stream it does not. Use `forEachOrdered` if order matters in parallel.
- `allMatch` on an empty stream returns `true` (vacuous truth). `anyMatch` on an empty stream returns `false`. This is logically correct but surprises candidates.

**Quick Revision Notes**

- Terminal ops trigger pipeline execution; stream is consumed afterward.
- Short-circuit: `anyMatch`, `allMatch`, `noneMatch`, `findFirst`, `findAny`, `limit`.
- `reduce` needs an identity that is neutral for the operation.
- `forEach` does not guarantee order in parallel streams.
- Empty stream: `allMatch` â†’ true, `anyMatch` â†’ false, `count` â†’ 0.

---

### Q8: Explain Collectors. What are the most important ones?

**Difficulty:** Medium"“Hard | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Goldman Sachs, JPMorgan, Stripe, Netflix

**Short Answer (30"“60 seconds)**

`Collectors` is a utility class providing common `Collector` implementations for `collect()`. The most important: `toList()`, `toSet()`, `toMap()`, `groupingBy()`, `partitioningBy()`, `joining()`, `counting()`. In Java 16+, use `Collectors.toUnmodifiableList()` or `Stream.toList()` for immutable results.

**Deep Explanation**

A `Collector<T,A,R>` has three type parameters: input element type `T`, mutable accumulation type `A`, and result type `R`. It defines four operations: `supplier()` (create accumulator), `accumulator()` (fold element into accumulator), `combiner()` (merge two accumulators in parallel), `finisher()` (convert accumulator to result).

**groupingBy "” the most powerful Collector:**

`groupingBy(classifier)` groups elements by key into a `Map<K, List<V>>`.
`groupingBy(classifier, downstream)` applies a downstream collector to each group.

**toMap "” the most dangerous Collector:**

`Collectors.toMap(keyMapper, valueMapper)` throws `IllegalStateException` on duplicate keys by default. Always provide a merge function for potentially non-unique keys.

**Java 17 / Stream.toList():**

Java 16 added `Stream.toList()` as a terminal operation shorthand for `collect(Collectors.toUnmodifiableList())`. The result is unmodifiable.

**Real-World Backend Example**

Reporting: group transactions by merchant, then count and sum by type:

```java
Map<String, Map<TransactionType, Long>> report = transactions.stream()
    .collect(Collectors.groupingBy(
        Transaction::getMerchant,
        Collectors.groupingBy(Transaction::getType, Collectors.counting())
    ));
```

**Java 17 Code Example**

```java
import java.util.*;
import java.util.stream.*;
import java.util.function.*;

public class CollectorsDemo {

    record Employee(String name, String dept, double salary) {}

    public static void main(String[] args) {
        List<Employee> employees = List.of(
            new Employee("Alice", "Engineering", 120000),
            new Employee("Bob", "Engineering", 110000),
            new Employee("Carol", "HR", 80000),
            new Employee("Dave", "HR", 85000),
            new Employee("Eve", "Engineering", 130000)
        );

        // toList (Java 16+) "” unmodifiable
        List<String> names = employees.stream()
            .map(Employee::name)
            .toList();

        // toSet
        Set<String> depts = employees.stream()
            .map(Employee::dept)
            .collect(Collectors.toSet());

        // toMap "” MUST provide merge function if keys may duplicate
        Map<String, Double> salaryByName = employees.stream()
            .collect(Collectors.toMap(Employee::name, Employee::salary));
        // Safe here because names are unique

        // toMap with merge function for duplicate keys
        Map<String, Double> maxSalaryByDept = employees.stream()
            .collect(Collectors.toMap(
                Employee::dept,
                Employee::salary,
                Double::max  // merge: keep higher salary
            ));
        System.out.println(maxSalaryByDept); // {Engineering=130000.0, HR=85000.0}

        // groupingBy
        Map<String, List<Employee>> byDept = employees.stream()
            .collect(Collectors.groupingBy(Employee::dept));

        // groupingBy with downstream collector
        Map<String, Double> avgSalaryByDept = employees.stream()
            .collect(Collectors.groupingBy(
                Employee::dept,
                Collectors.averagingDouble(Employee::salary)
            ));
        System.out.println(avgSalaryByDept);

        // groupingBy with counting
        Map<String, Long> countByDept = employees.stream()
            .collect(Collectors.groupingBy(Employee::dept, Collectors.counting()));
        System.out.println(countByDept); // {Engineering=3, HR=2}

        // partitioningBy "” splits into true/false
        Map<Boolean, List<Employee>> seniorSplit = employees.stream()
            .collect(Collectors.partitioningBy(e -> e.salary() > 100000));
        System.out.println("Senior: " + seniorSplit.get(true).stream().map(Employee::name).toList());

        // joining
        String nameList = employees.stream()
            .map(Employee::name)
            .collect(Collectors.joining(", ", "[", "]"));
        System.out.println(nameList); // [Alice, Bob, Carol, Dave, Eve]

        // summarizingInt / summarizingDouble
        DoubleSummaryStatistics stats = employees.stream()
            .collect(Collectors.summarizingDouble(Employee::salary));
        System.out.printf("Min=%.0f, Max=%.0f, Avg=%.0f%n",
            stats.getMin(), stats.getMax(), stats.getAverage());
    }
}
```

**Follow-up Questions**

- "What exception does `toMap` throw on duplicate keys? How do you fix it?"
- "How do you create a `Map<String, Set<Employee>>` with streams?"
- "What is the difference between `partitioningBy` and `groupingBy`?"
- "How does `Collectors.counting()` differ from `Stream.count()`?"
- "What does `Stream.toList()` return? Is it mutable?"

**Common Mistakes**

- Using `Collectors.toMap` without a merge function when keys might repeat "” causes `IllegalStateException` at runtime.
- Using mutable list after `Stream.toList()` "” it throws `UnsupportedOperationException`.
- Forgetting that `groupingBy` with no downstream collector produces `Map<K, List<V>>`, not `Map<K, V>`.

**Interview Traps**

- `Collectors.toMap` with a `null` value throws `NullPointerException` even with a merge function "” the implementation uses `HashMap.merge()` which rejects null values. Use `toMap` with `(k, v, map)` via a custom collector if nulls are possible.
- `partitioningBy` always produces a `Map` with both `true` and `false` keys, even if one group is empty. `groupingBy` only produces keys for groups that exist.

**Quick Revision Notes**

- `toMap` = duplicate key â†’ `IllegalStateException`; always provide merge function.
- `groupingBy(k, downstream)` is the most versatile; chain with `counting()`, `averagingDouble()`, etc.
- `partitioningBy` = exactly two groups: true/false.
- `Stream.toList()` (Java 16) returns unmodifiable list.
- `joining(delimiter, prefix, suffix)` for CSV/formatted output.

---

### Q9: Stream vs Collection "” when do you use streams vs loops?

**Difficulty:** Easy"“Medium | **Interview Frequency:** High

**Companies:** Amazon, Goldman Sachs, Atlassian, Spotify

**Short Answer (30"“60 seconds)**

Use streams for declarative data transformation pipelines "” filtering, mapping, reducing "” especially when readability and composability matter. Use traditional loops when you need complex control flow (break by condition across multiple variables), when performance profiling shows loop is faster, or when the logic is inherently imperative with multiple mutations per element.

**Deep Explanation**

**Streams are better when:**
- Expressing a pipeline of transformations declaratively.
- You want lazy evaluation (short-circuit, infinite sources).
- You need to parallelize easily (`.parallel()`).
- The operation maps cleanly to filter/map/reduce/collect.

**Loops are better when:**
- You need to `break` out of a loop after non-trivial stateful decisions.
- You are mutating multiple fields of the same object per iteration.
- Performance-critical tight loops (streams have overhead from lambda dispatch, though JIT often eliminates this).
- You are iterating with an index (`for (int i = 0; ...)`) and the index has semantic meaning.
- Checked exceptions are heavily used "” streams do not handle checked exceptions without wrapper utilities.

**Performance reality:**
For small collections (< 1000 elements), loops are often as fast or faster than streams. Streams add JIT warm-up cost. However, for large datasets with parallelism, streams with `.parallel()` can outperform loops significantly.

**Real-World Backend Example**

```java
// Streams: clean for read-only transformation pipeline
List<String> activeUserEmails = users.stream()
    .filter(User::isActive)
    .map(User::getEmail)
    .filter(email -> email.endsWith("@company.com"))
    .sorted()
    .collect(Collectors.toList());

// Loop: better when you need to break on a complex condition
// or when you're building results with non-trivial state
List<Order> batch = new ArrayList<>();
int totalValue = 0;
for (Order order : pendingOrders) {
    if (totalValue + order.getValue() > MAX_BATCH_VALUE) break;
    batch.add(order);
    totalValue += order.getValue();
}
```

**Java 17 Code Example**

```java
import java.util.*;
import java.util.stream.*;

public class StreamVsLoopDemo {

    record Product(String name, String category, double price, boolean available) {}

    public static void main(String[] args) {
        List<Product> products = List.of(
            new Product("Laptop", "Electronics", 999.99, true),
            new Product("Phone", "Electronics", 599.99, false),
            new Product("Desk", "Furniture", 299.99, true),
            new Product("Chair", "Furniture", 199.99, true),
            new Product("Monitor", "Electronics", 449.99, true)
        );

        // Stream approach "” declarative, readable
        Map<String, Double> avgPriceByCategory = products.stream()
            .filter(Product::available)
            .collect(Collectors.groupingBy(
                Product::category,
                Collectors.averagingDouble(Product::price)
            ));
        System.out.println(avgPriceByCategory);

        // Loop approach "” necessary when building a cart with budget cap
        double budget = 1200.0;
        double spent = 0;
        List<Product> cart = new ArrayList<>();
        for (Product p : products) {
            if (!p.available()) continue;
            if (spent + p.price() > budget) continue; // can't break here "” might find cheaper later
            cart.add(p);
            spent += p.price();
        }
        System.out.println("Cart: " + cart.stream().map(Product::name).toList());
    }
}
```

**Follow-up Questions**

- "Are streams always slower than loops?"
- "When would you never use a stream?"
- "How does the JIT compiler optimize stream pipelines?"

**Common Mistakes**

- Using streams for simple single-element lookups where a loop with break is clearer and faster.
- Converting streams to/from collections unnecessarily mid-pipeline.

**Interview Traps**

- Streams have overhead "” lambda capturing, pipeline setup, boxing/unboxing. For `int` operations, always prefer `IntStream` over `Stream<Integer>` to avoid boxing.
- `Stream.iterate` and `Stream.generate` create sequential streams; adding `.parallel()` does not guarantee equal workload distribution.

**Quick Revision Notes**

- Streams = declarative pipelines, lazy, parallelizable.
- Loops = imperative, stateful, complex control flow, checked exceptions.
- Use `IntStream`/`LongStream`/`DoubleStream` to avoid boxing.
- Small collections: loop perf â‰ˆ stream. Large + parallel: stream wins.
- Streams do not support checked exceptions natively.

---

### Q10: How do parallel streams work? When should you use them?

**Difficulty:** Hard | **Interview Frequency:** High

**Companies:** Amazon, Google, Goldman Sachs, Netflix, Stripe

**Short Answer (30"“60 seconds)**

Parallel streams split the data source using `Spliterator.trySplit()`, distribute work across threads in `ForkJoinPool.commonPool()`, and merge results. Use them for CPU-bound operations on large datasets where the operations are stateless and the overhead of splitting/merging is justified. Avoid them for IO-bound work, small datasets, stateful operations, or when thread-safety of shared mutable state is a concern.

**Deep Explanation**

**How it works:**
1. `stream.parallel()` or `parallelStream()` marks the stream as parallel.
2. The `Spliterator` recursively splits the data source into subtasks.
3. Each subtask runs in a thread from `ForkJoinPool.commonPool()` (default parallelism = number of CPU cores - 1).
4. Results are merged using the combiner functions of intermediate/terminal operations.

**ForkJoinPool.commonPool:**
This is a shared pool used by all parallel streams in the JVM. If one parallel stream operation is long-running, it starves other streams (and CompletableFuture async tasks that also use this pool). For production workloads, consider a custom `ForkJoinPool`:

```java
ForkJoinPool customPool = new ForkJoinPool(4);
List<Result> results = customPool.submit(
    () -> largeList.parallelStream().map(this::expensive).collect(Collectors.toList())
).get();
```

**When NOT to use parallel streams:**

1. **Small datasets:** The overhead of splitting and merging exceeds the gain. Rule of thumb: < 10,000 elements, profile first.
2. **IO-bound operations:** Thread pool is CPU-sized; IO blocks threads wastefully. Use async IO instead.
3. **Stateful operations:** `sorted()`, `distinct()` require synchronization and buffering that negates parallelism.
4. **Ordered operations on ordered sources:** `findFirst()`, `forEachOrdered()` force serial re-assembly.
5. **Thread-unsafe shared state:** Any shared mutable state (non-atomic counters, non-concurrent collections) will produce incorrect results without explicit synchronization.

**Real-World Backend Example**

Batch processing of independent records (CPU-bound, no shared state):

```java
// Good use case: independent image resizing
List<ResizedImage> thumbnails = largeImageList.parallelStream()
    .map(img -> imageService.resize(img, 200, 200)) // CPU-bound, stateless
    .collect(Collectors.toList());

// Bad use case: incrementing a shared counter
int[] count = {0};
list.parallelStream().forEach(item -> count[0]++); // RACE CONDITION
// Use: list.parallelStream().filter(predicate).count() instead
```

**Java 17 Code Example**

```java
import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;

public class ParallelStreamDemo {

    // Simulates CPU-bound work
    static long computeHash(int n) {
        long hash = n;
        for (int i = 0; i < 1000; i++) hash = hash * 31 + i;
        return hash;
    }

    public static void main(String[] args) throws Exception {
        List<Integer> data = IntStream.rangeClosed(1, 100_000)
            .boxed()
            .collect(Collectors.toList());

        // Sequential
        long t1 = System.currentTimeMillis();
        long seqSum = data.stream().mapToLong(ParallelStreamDemo::computeHash).sum();
        System.out.println("Sequential: " + (System.currentTimeMillis() - t1) + "ms");

        // Parallel with common pool
        long t2 = System.currentTimeMillis();
        long parSum = data.parallelStream().mapToLong(ParallelStreamDemo::computeHash).sum();
        System.out.println("Parallel (common pool): " + (System.currentTimeMillis() - t2) + "ms");

        // Parallel with custom pool (avoid starving common pool)
        ForkJoinPool customPool = new ForkJoinPool(4);
        long t3 = System.currentTimeMillis();
        long customSum = customPool.submit(
            () -> data.parallelStream().mapToLong(ParallelStreamDemo::computeHash).sum()
        ).get();
        System.out.println("Parallel (custom pool): " + (System.currentTimeMillis() - t3) + "ms");
        customPool.shutdown();

        // Thread-safety demonstration "” WRONG
        List<Integer> unsafeResults = new ArrayList<>();
        // data.parallelStream().forEach(unsafeResults::add); // Race condition!

        // CORRECT: use collect
        List<Long> safeResults = data.parallelStream()
            .mapToLong(ParallelStreamDemo::computeHash)
            .boxed()
            .collect(Collectors.toList());
    }
}
```

**Follow-up Questions**

- "What is `ForkJoinPool.commonPool()`? How many threads does it have?"
- "How do you run a parallel stream in a custom thread pool?"
- "Why is `ArrayList` unsafe for parallel stream `forEach`?"
- "What stream characteristics affect parallel performance?"

**Common Mistakes**

- Using parallel streams for IO-bound tasks (HTTP calls, DB queries).
- Mutating shared collections inside `parallelStream().forEach()`.
- Not measuring "” assuming parallel is always faster.

**Interview Traps**

- `parallelStream()` on an `ArrayList` works well; on a `LinkedList` it is poor because `LinkedList`'s `Spliterator` cannot split efficiently (it must traverse to find midpoint).
- The common pool is shared with `CompletableFuture.supplyAsync()` "” a blocked parallel stream can starve async tasks.

**Quick Revision Notes**

- Parallel streams use `ForkJoinPool.commonPool()` (N-1 threads for N CPUs).
- Best for: CPU-bound, large datasets, stateless, no ordering requirements.
- Avoid: IO-bound, small data, stateful ops, shared mutable state.
- Custom pool via `ForkJoinPool.submit(() -> stream.parallel()...)`.
- `LinkedList` parallelizes poorly; `ArrayList` and arrays split efficiently.

---

### Q11: What are primitive streams? Why do they exist?

**Difficulty:** Easy | **Interview Frequency:** Medium

**Companies:** Goldman Sachs, Amazon

**Short Answer (30"“60 seconds)**

`IntStream`, `LongStream`, and `DoubleStream` are specialized stream implementations for primitive types. They exist to avoid the boxing overhead of `Stream<Integer>`, `Stream<Long>`, `Stream<Double>`. They also provide arithmetic terminal operations that are not available on object streams: `sum()`, `average()`, `min()`, `max()`, `summaryStatistics()`.

**Deep Explanation**

Every time you use `Stream<Integer>`, each `int` value is autoboxed into an `Integer` object. For a stream of 1 million integers, that is 1 million `Integer` objects on the heap. `IntStream` operates on raw `int` values, eliminating boxing entirely.

**Conversion methods:**

- `Stream<T>.mapToInt(ToIntFunction)` â†’ `IntStream`
- `IntStream.boxed()` â†’ `Stream<Integer>`
- `IntStream.mapToObj(IntFunction)` â†’ `Stream<R>`
- `IntStream.asLongStream()` â†’ `LongStream`

**Factory methods:**

- `IntStream.range(start, end)` "” exclusive end, like a for loop.
- `IntStream.rangeClosed(start, end)` "” inclusive end.
- `IntStream.of(1, 2, 3)` "” explicit values.
- `Arrays.stream(int[])` "” from array.

**Java 17 Code Example**

```java
import java.util.*;
import java.util.stream.*;

public class PrimitiveStreamDemo {

    public static void main(String[] args) {
        // IntStream.range "” exclusive end
        int sumTo99 = IntStream.range(0, 100).sum();
        System.out.println("Sum 0-99: " + sumTo99); // 4950

        // IntStream.rangeClosed "” inclusive end
        int sumTo100 = IntStream.rangeClosed(1, 100).sum();
        System.out.println("Sum 1-100: " + sumTo100); // 5050

        // summaryStatistics
        IntSummaryStatistics stats = IntStream.rangeClosed(1, 10).summaryStatistics();
        System.out.println("Count=" + stats.getCount() +
            ", Min=" + stats.getMin() + ", Max=" + stats.getMax() +
            ", Sum=" + stats.getSum() + ", Avg=" + stats.getAverage());

        // Convert Stream<String> â†’ IntStream (map to lengths)
        int totalChars = List.of("hello", "world", "java").stream()
            .mapToInt(String::length)
            .sum();
        System.out.println("Total chars: " + totalChars); // 13

        // IntStream â†’ Stream<Integer> (boxed)
        List<Integer> squares = IntStream.rangeClosed(1, 5)
            .map(n -> n * n)
            .boxed()
            .collect(Collectors.toList());
        System.out.println(squares); // [1, 4, 9, 16, 25]

        // average() returns OptionalDouble
        OptionalDouble avg = IntStream.of(1, 2, 3, 4, 5).average();
        System.out.println("Average: " + avg.getAsDouble()); // 3.0
    }
}
```

**Follow-up Questions**

- "What does `IntStream.average()` return? Why?"
- "How do you convert an `int[]` to `List<Integer>`?"

**Common Mistakes**

- Using `Stream<Integer>` with `map(...).sum()` "” `Stream<Integer>` doesn't have `sum()`; use `mapToInt` first.
- Forgetting that `IntStream.range` is exclusive at the end.

**Interview Traps**

- `IntStream.range(0, n)` generates `n` elements (0 to n-1), not n+1. Candidates confuse this with `rangeClosed`.

**Quick Revision Notes**

- Primitive streams avoid boxing: `IntStream`, `LongStream`, `DoubleStream`.
- Extra terminal ops: `sum()`, `average()` â†’ `OptionalDouble`, `summaryStatistics()`.
- `range(a, b)` = [a, b), `rangeClosed(a, b)` = [a, b].
- `mapToInt()` â†’ `IntStream`; `boxed()` â†’ `Stream<Integer>`.

---

### Q12: Why can't you reuse a stream after a terminal operation?

**Difficulty:** Easy | **Interview Frequency:** Medium

**Companies:** Any company testing Java fundamentals

**Short Answer (30"“60 seconds)**

Streams are single-use. Once a terminal operation is invoked, the stream is marked as consumed. Any further operation on the same stream instance throws `IllegalStateException: stream has already been operated upon or closed`. This is by design "” a stream is a pipeline of operations over a data source, not the data itself.

**Deep Explanation**

Internally, `AbstractPipeline` (the base class for stream implementations) maintains a `linkedOrConsumed` flag. When a terminal operation starts, it sets this flag to `true`. Any subsequent attempt to chain or execute on the same pipeline object checks this flag and throws.

The fix is simple: call `stream()` again on the source collection to get a new stream.

**Java 17 Code Example**

```java
import java.util.*;
import java.util.stream.*;

public class StreamReuseDemo {

    public static void main(String[] args) {
        List<String> names = List.of("Alice", "Bob", "Carol");

        Stream<String> stream = names.stream();
        long count = stream.count(); // terminal operation
        System.out.println("Count: " + count);

        // This throws IllegalStateException
        try {
            stream.forEach(System.out::println); // BOOM
        } catch (IllegalStateException e) {
            System.out.println("Error: " + e.getMessage());
            // stream has already been operated upon or closed
        }

        // Correct: create a new stream
        names.stream().forEach(System.out::println);

        // Supplier pattern for reusable stream logic
        java.util.function.Supplier<Stream<String>> streamSupplier = names::stream;
        long count2 = streamSupplier.get().count();
        String first = streamSupplier.get().findFirst().orElseThrow();
        System.out.println(count2 + " " + first);
    }
}
```

**Follow-up Questions**

- "How would you design a reusable stream operation?"

**Common Mistakes**

- Storing a stream in a field and reusing it across methods.

**Interview Traps**

- If you store a `Supplier<Stream<T>>` and call `get()` each time, you get a fresh stream each time "” this is the correct pattern for reusable stream logic.

**Quick Revision Notes**

- Streams are single-use: one terminal operation, then consumed.
- Reuse â†’ `IllegalStateException`.
- Pattern for reuse: `Supplier<Stream<T>> s = collection::stream`.

---

### Q13: What are infinite streams? How do you use them safely?

**Difficulty:** Medium | **Interview Frequency:** Medium

**Companies:** Google, Amazon

**Short Answer (30"“60 seconds)**

`Stream.generate(Supplier)` and `Stream.iterate(seed, UnaryOperator)` create infinite streams. They are safe because streams are lazy "” elements are only produced on demand. You must pair them with a short-circuit terminal operation (`findFirst`, `findAny`) or a size-limiting intermediate operation (`limit(n)`) to avoid infinite loops.

**Deep Explanation**

`Stream.generate(supplier)` produces an unordered infinite stream where each element is provided by calling the supplier repeatedly.

`Stream.iterate(seed, f)` produces an ordered infinite stream: `seed, f(seed), f(f(seed)), ...`.

Java 9 added `Stream.iterate(seed, hasNext, f)` "” a finite iterate with a predicate (analogous to a for loop):
`Stream.iterate(0, n -> n < 10, n -> n + 1)` â‰¡ `for (int n = 0; n < 10; n++)`

**Real-World Backend Example**

Generating unique correlation IDs, retry sequences, or pagination tokens:

```java
// Generate sequence of page tokens for pagination
Stream.iterate(0, page -> page + 1)
    .map(page -> fetchPage(apiUrl, page, PAGE_SIZE))
    .takeWhile(page -> !page.isEmpty())   // Java 9 takeWhile
    .flatMap(Collection::stream)
    .collect(Collectors.toList());
```

**Java 17 Code Example**

```java
import java.util.*;
import java.util.stream.*;

public class InfiniteStreamDemo {

    public static void main(String[] args) {
        // Stream.generate "” infinite, unordered
        List<Double> randoms = Stream.generate(Math::random)
            .limit(5)
            .collect(Collectors.toList());
        System.out.println(randoms);

        // Stream.iterate "” infinite, ordered, seed + function
        List<Integer> powersOf2 = Stream.iterate(1, n -> n * 2)
            .limit(10)
            .collect(Collectors.toList());
        System.out.println(powersOf2); // [1, 2, 4, 8, 16, 32, 64, 128, 256, 512]

        // Stream.iterate with predicate (Java 9) "” finite
        List<Integer> range = Stream.iterate(0, n -> n < 20, n -> n + 3)
            .collect(Collectors.toList());
        System.out.println(range); // [0, 3, 6, 9, 12, 15, 18]

        // findFirst with infinite stream "” short-circuits safely
        Optional<Integer> firstMultipleOf7 = Stream.iterate(1, n -> n + 1)
            .filter(n -> n % 7 == 0)
            .findFirst();
        System.out.println(firstMultipleOf7.orElseThrow()); // 7

        // UUID generator
        List<String> correlationIds = Stream.generate(() -> UUID.randomUUID().toString())
            .limit(3)
            .collect(Collectors.toList());
        System.out.println(correlationIds);
    }
}
```

**Follow-up Questions**

- "What happens if you call `collect()` on an infinite stream without `limit()`?"
- "What is `takeWhile` in Java 9? How does it differ from `filter`?"

**Common Mistakes**

- Calling a non-short-circuit terminal operation on an infinite stream (`count()`, `collect()` without `limit()`).
- Confusing `Stream.iterate(seed, hasNext, next)` (Java 9, finite) with `Stream.iterate(seed, next)` (infinite).

**Interview Traps**

- `Stream.generate` is stateless by definition "” the supplier should not have state. For stateful generation, use `Stream.iterate` or an `AtomicInteger` in the supplier (with care for parallel streams).

**Quick Revision Notes**

- `Stream.generate(supplier)` = infinite, unordered.
- `Stream.iterate(seed, f)` = infinite, ordered, sequential.
- `Stream.iterate(seed, predicate, f)` = finite, Java 9+.
- Always use `limit(n)`, `findFirst()`, `takeWhile()` to bound infinite streams.
- `takeWhile(p)` stops at first non-matching element; `filter(p)` skips non-matching elements but continues.

---



## Optional

### Q14: What is Optional and what problem does it solve?

**Difficulty:** Easy"“Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Goldman Sachs, Stripe, Netflix, Uber

**Short Answer (30"“60 seconds)**

`Optional<T>` is a container that may or may not hold a non-null value. It was introduced in Java 8 to provide a type-safe way to represent the absence of a value, forcing callers to explicitly handle the "no value" case rather than relying on null checks that are easy to forget. However, `Optional` is not a general-purpose null replacement "” it is intended for method return types only.

**Deep Explanation**

**What Optional IS:**
- A return type that communicates "this method might not return a value."
- Forces the caller to handle the empty case explicitly.
- Works well in stream pipelines (`findFirst()`, `min()`, `max()` return `Optional`).

**What Optional IS NOT:**
- Not a replacement for null in all contexts.
- Not for use as a field type "” `Optional` is not `Serializable`, so it breaks Java serialization. It also adds memory overhead (an extra object wrapper per field).
- Not for method parameters "” passing `Optional<T>` as a parameter is an anti-pattern. Use overloaded methods or null checks instead.
- Not for collections "” `Optional<List<T>>` is redundant; return an empty list instead.

**Design rationale:**
Brian Goetz (Java language architect) has stated that `Optional` was designed as a limited mechanism for library method return types, not as a general-purpose Maybe monad.

**Real-World Backend Example**

In a repository layer:
```java
// Repository
Optional<User> findById(Long id);

// Service layer "” explicit handling
User user = userRepository.findById(userId)
    .orElseThrow(() -> new UserNotFoundException("User not found: " + userId));
```

**Java 17 Code Example**

```java
import java.util.Optional;

public class OptionalBasicsDemo {

    record User(Long id, String name, String email) {}

    static Optional<User> findUser(Long id) {
        if (id == 1L) return Optional.of(new User(1L, "Alice", "alice@example.com"));
        return Optional.empty();
    }

    public static void main(String[] args) {
        // Anti-pattern: using Optional as a field
        // class UserProfile { Optional<String> phone; } // BAD

        // Anti-pattern: Optional as method parameter
        // void process(Optional<String> name) {} // BAD "” use overloading or @Nullable

        // Correct use: method return type
        Optional<User> found = findUser(1L);
        Optional<User> notFound = findUser(99L);

        System.out.println(found.isPresent());  // true
        System.out.println(notFound.isEmpty()); // true (Java 11+)

        // Correct: collection return "” empty list, not Optional<List>
        // List<User> findByDept(String dept) "” return List.of() not Optional.empty()
    }
}
```

**Follow-up Questions**

- "Why shouldn't Optional be used as a method parameter?"
- "Why isn't Optional Serializable?"
- "When would you return `Optional<List<T>>`? (Answer: almost never)"

**Common Mistakes**

- Using `Optional<T>` as a field type in entities or DTOs "” breaks serialization frameworks.
- Wrapping collections: `Optional<List<T>>` instead of returning an empty list.
- Using Optional just to call `.get()` immediately "” defeats the purpose.

**Interview Traps**

- `Optional.of(null)` throws `NullPointerException` immediately. Use `Optional.ofNullable(value)` when the value may be null.

**Quick Revision Notes**

- Optional = return type only; not fields, not params, not collections.
- `Optional.of(null)` â†’ NPE. `Optional.ofNullable(null)` â†’ `Optional.empty()`.
- Not Serializable "” avoid in JPA entities, DTOs used with serialization.
- Java 11 added `isEmpty()` as the inverse of `isPresent()`.

---

### Q15: Explain all Optional methods.

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Goldman Sachs, Stripe, Atlassian

**Short Answer (30"“60 seconds)**

Optional provides: factory methods (`of`, `ofNullable`, `empty`), presence checks (`isPresent`, `isEmpty`), value extraction (`get`, `orElse`, `orElseGet`, `orElseThrow`), conditional execution (`ifPresent`, `ifPresentOrElse`), and transformation (`map`, `flatMap`, `filter`, `or`).

**Deep Explanation**

**Factory methods:**
- `Optional.of(T)` "” creates non-empty Optional; throws NPE if value is null.
- `Optional.ofNullable(T)` "” creates Optional from potentially null value; returns empty if null.
- `Optional.empty()` "” returns the singleton empty Optional.

**Presence checks:**
- `isPresent()` "” true if value present.
- `isEmpty()` "” true if empty (Java 11+).

**Value extraction (ordered by safety):**
- `orElse(T other)` "” return value or `other` if empty. **Always evaluates `other`.**
- `orElseGet(Supplier)` "” return value or call supplier if empty. **Lazy.**
- `orElseThrow()` "” return value or throw `NoSuchElementException` (Java 10+).
- `orElseThrow(Supplier<X extends Throwable>)` "” return value or throw custom exception.
- `get()` "” return value or throw `NoSuchElementException`. **Avoid** "” use `orElseThrow()`.

**Conditional execution:**
- `ifPresent(Consumer)` "” execute consumer if value present; does nothing if empty.
- `ifPresentOrElse(Consumer, Runnable)` "” execute consumer if present, else execute runnable (Java 9+).

**Transformation:**
- `map(Function)` "” applies function to value if present; returns empty Optional if absent or if function returns null.
- `flatMap(Function<T, Optional<R>>)` "” like map but function returns Optional; avoids `Optional<Optional<T>>`.
- `filter(Predicate)` "” returns Optional with value if present and predicate matches; otherwise empty.
- `or(Supplier<Optional<T>>)` "” if empty, call supplier to get another Optional (Java 9+).

**Java 17 Code Example**

```java
import java.util.Optional;

public class OptionalMethodsDemo {

    record Address(String city, String country) {}
    record User(String name, Address address) {}

    static Optional<User> findUser(String name) {
        if ("Alice".equals(name)) {
            return Optional.of(new User("Alice", new Address("London", "UK")));
        }
        if ("Bob".equals(name)) {
            return Optional.of(new User("Bob", null)); // address is null
        }
        return Optional.empty();
    }

    public static void main(String[] args) {
        // factory methods
        Optional<String> present = Optional.of("hello");
        Optional<String> fromNull = Optional.ofNullable(null); // empty
        Optional<String> empty = Optional.empty();

        // orElse vs orElseGet (see Q16 for deep dive)
        String val1 = empty.orElse("default");
        String val2 = empty.orElseGet(() -> "computed-default");

        // orElseThrow
        try {
            empty.orElseThrow(() -> new IllegalStateException("No value"));
        } catch (IllegalStateException e) {
            System.out.println("Caught: " + e.getMessage());
        }

        // map "” safe navigation
        Optional<String> city = findUser("Alice")
            .map(User::address)           // Optional<Address> "” could be empty if address null
            .map(Address::city);          // Optional<String>
        System.out.println(city.orElse("Unknown")); // London

        // flatMap "” when map would produce Optional<Optional<T>>
        // Assume getAddress returns Optional<Address>
        // user.map(u -> getOptionalAddress(u)) => Optional<Optional<Address>> "” BAD
        // user.flatMap(u -> getOptionalAddress(u)) => Optional<Address> "” GOOD

        // filter
        Optional<String> longName = Optional.of("Alexander")
            .filter(s -> s.length() > 5);
        System.out.println(longName.isPresent()); // true

        // or (Java 9) "” fallback to another Optional
        Optional<User> user = findUser("unknown")
            .or(() -> findUser("Alice")); // fallback chain
        System.out.println(user.map(User::name).orElse("none")); // Alice

        // ifPresentOrElse (Java 9)
        findUser("Bob").ifPresentOrElse(
            u -> System.out.println("Found: " + u.name()),
            () -> System.out.println("Not found")
        );

        // stream() (Java 9) "” convert Optional to Stream of 0 or 1 elements
        long count = findUser("Alice").stream().count();
        System.out.println("Stream count: " + count); // 1
    }
}
```

**Follow-up Questions**

- "What does `Optional.map()` return if the function returns null?"
- "When would you use `flatMap` instead of `map` on an Optional?"
- "What is `Optional.stream()` (Java 9) and when is it useful?"

**Common Mistakes**

- Calling `get()` without checking `isPresent()` "” throws `NoSuchElementException`.
- Using `map` when the mapping function itself returns an `Optional`, resulting in `Optional<Optional<T>>`.

**Interview Traps**

- `Optional.map(f)` where `f` returns `null` results in `Optional.empty()`, not `Optional.of(null)`. The implementation explicitly checks for null return from the mapper.

**Quick Revision Notes**

- `of` = non-null (NPE on null). `ofNullable` = null-safe. `empty` = singleton empty.
- `get()` is dangerous "” prefer `orElseThrow()`.
- `map` = function returns T. `flatMap` = function returns Optional<T>.
- `or()` (Java 9) = fallback Optional chain. `ifPresentOrElse()` (Java 9) = handle both cases.
- `stream()` (Java 9) = treat Optional as Stream<T> of 0 or 1 elements.

---

### Q16: What is the difference between orElse() and orElseGet()?

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Goldman Sachs, Stripe, Netflix

**Short Answer (30"“60 seconds)**

`orElse(value)` always evaluates its argument "” the value expression is computed regardless of whether the Optional is empty. `orElseGet(supplier)` is lazy "” the supplier is only called when the Optional is empty. For expensive operations like database lookups or object construction, always use `orElseGet` to avoid unnecessary computation.

**Deep Explanation**

This is one of the most common Optional interview traps.

```java
Optional<Config> config = getFromCache();

// orElse: loadFromDatabase() is ALWAYS called, even if cache hit
Config c1 = config.orElse(loadFromDatabase());

// orElseGet: loadFromDatabase() is only called if cache miss
Config c2 = config.orElseGet(() -> loadFromDatabase());
```

**Why this matters:**

If `loadFromDatabase()` is expensive (network call, SQL query), `orElse` wastes resources on every cache hit. In high-throughput systems, this can cause serious performance degradation.

**When orElse is fine:**
- When the fallback is a constant, a literal, or a field reference (already evaluated).
- `optional.orElse(null)` "” null is not computed, it is a literal.
- `optional.orElse(Collections.emptyList())` "” `emptyList()` is O(1) and returns a cached object.

**Real-World Backend Example**

```java
// Config service with Redis cache
public Config getConfig(String key) {
    return redisCache.get(key)
        // BAD: always calls DB even on cache hit
        // .orElse(configRepository.findByKey(key).orElse(Config.defaults()))

        // GOOD: DB call only on cache miss
        .orElseGet(() -> configRepository.findByKey(key).orElse(Config.defaults()));
}
```

**Java 17 Code Example**

```java
import java.util.Optional;

public class OrElseVsOrElseGetDemo {

    static String expensiveComputation() {
        System.out.println("  [EXPENSIVE COMPUTATION CALLED]");
        return "expensive-result";
    }

    public static void main(String[] args) {
        System.out.println("--- When Optional IS present ---");
        Optional<String> present = Optional.of("cached-value");

        System.out.print("orElse:    ");
        String r1 = present.orElse(expensiveComputation());
        // Prints: [EXPENSIVE COMPUTATION CALLED]  <-- wasted!
        System.out.println("Result: " + r1);

        System.out.print("orElseGet: ");
        String r2 = present.orElseGet(() -> expensiveComputation());
        // Does NOT print: [EXPENSIVE COMPUTATION CALLED]  <-- saved!
        System.out.println("Result: " + r2);

        System.out.println("--- When Optional IS empty ---");
        Optional<String> empty = Optional.empty();

        System.out.print("orElse:    ");
        String r3 = empty.orElse(expensiveComputation());
        System.out.println("Result: " + r3);

        System.out.print("orElseGet: ");
        String r4 = empty.orElseGet(() -> expensiveComputation());
        System.out.println("Result: " + r4);
        // Both call expensive computation when empty "” that is expected
    }
}
```

Output when Optional is present:
```
orElse:    [EXPENSIVE COMPUTATION CALLED]  Result: cached-value
orElseGet:   Result: cached-value
```

**Follow-up Questions**

- "Is `orElse(null)` safe? Does it call null as a computation?"
- "What about `orElse(new ArrayList<>())`? When is that a problem?"

**Common Mistakes**

- Using `orElse(someMethod())` when `someMethod()` has side effects or is expensive.
- Thinking `orElse` is lazy "” it is not.

**Interview Traps**

- `optional.orElse(new SomeObject())` always constructs `SomeObject` even if the optional has a value "” each call allocates an object on the heap unnecessarily.

**Quick Revision Notes**

- `orElse(x)` "” eager: x always evaluated.
- `orElseGet(supplier)` "” lazy: supplier called only if empty.
- Rule: if fallback involves any method call, use `orElseGet`.
- Same pattern applies to `map` vs `flatMap` with expensive functions.

---

## CompletableFuture

### Q17: What are CompletableFuture basics?

**Difficulty:** Medium"“Hard | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Goldman Sachs, Stripe, Netflix, Uber, Atlassian

**Short Answer (30"“60 seconds)**

`CompletableFuture<T>` is Java 8's implementation of an asynchronous, non-blocking computation. It allows you to kick off async work, chain callbacks that run when the result is ready, combine multiple futures, and handle exceptions "” all without blocking the calling thread. `supplyAsync` starts a computation that returns a value; `runAsync` starts a computation with no return value.

**Deep Explanation**

`CompletableFuture` implements both `Future<T>` and `CompletionStage<T>`. The `CompletionStage` interface defines the chaining API.

**Core creation methods:**

| Method | Description |
|---|---|
| `CompletableFuture.supplyAsync(Supplier)` | Runs supplier in ForkJoinPool.commonPool, returns CompletableFuture<T> |
| `CompletableFuture.supplyAsync(Supplier, Executor)` | Runs supplier in provided executor |
| `CompletableFuture.runAsync(Runnable)` | Runs runnable, returns CompletableFuture<Void> |
| `CompletableFuture.completedFuture(value)` | Already-completed future (useful for testing/mocking) |

**Callback methods:**

| Method | Input | Output | Description |
|---|---|---|---|
| `thenApply(Function)` | T | U | Transform result (like map) |
| `thenAccept(Consumer)` | T | Void | Consume result (side effect) |
| `thenRun(Runnable)` | "” | Void | Run after completion, ignores result |
| `thenApplyAsync(Function)` | T | U | Transform in async thread |

The `Async` suffix variants (`thenApplyAsync`, etc.) run the callback in the async pool rather than the thread that completed the stage. Without `Async`, the callback may run in the completing thread (could be the main thread or the async thread).

**Real-World Backend Example**

Asynchronous payment processing:

```java
CompletableFuture<PaymentResult> future = CompletableFuture
    .supplyAsync(() -> paymentGateway.charge(request))     // async HTTP call
    .thenApply(response -> mapToResult(response))          // transform
    .thenApply(result -> auditLog.record(result))          // chain
    .exceptionally(ex -> PaymentResult.failed(ex.getMessage())); // error handling
```

**Java 17 Code Example**

```java
import java.util.concurrent.*;

public class CompletableFutureBasicsDemo {

    static String fetchUserName(long userId) throws InterruptedException {
        Thread.sleep(100); // simulate IO
        return "Alice";
    }

    static String fetchEmail(String name) throws InterruptedException {
        Thread.sleep(50);
        return name.toLowerCase() + "@example.com";
    }

    public static void main(String[] args) throws Exception {
        // supplyAsync "” async computation
        CompletableFuture<String> nameFuture = CompletableFuture
            .supplyAsync(() -> {
                try { return fetchUserName(1L); }
                catch (InterruptedException e) { throw new RuntimeException(e); }
            });

        // thenApply "” transform result
        CompletableFuture<String> emailFuture = nameFuture
            .thenApply(name -> name.toLowerCase() + "@example.com");

        // thenAccept "” consume result
        CompletableFuture<Void> logFuture = emailFuture
            .thenAccept(email -> System.out.println("Email: " + email));

        // thenRun "” run after completion, result ignored
        logFuture.thenRun(() -> System.out.println("Pipeline complete"));

        // exceptionally "” handle errors
        CompletableFuture<String> safe = CompletableFuture
            .supplyAsync(() -> { throw new RuntimeException("API down"); })
            .exceptionally(ex -> "fallback-value");

        // block for result (in production, use non-blocking patterns)
        System.out.println(safe.get()); // fallback-value

        // completedFuture "” useful in tests/mocks
        CompletableFuture<String> immediate = CompletableFuture.completedFuture("mock-result");
        System.out.println(immediate.get()); // mock-result

        // Custom executor (avoid common pool for IO)
        ExecutorService ioPool = Executors.newFixedThreadPool(10);
        CompletableFuture<String> ioFuture = CompletableFuture
            .supplyAsync(() -> "io-result", ioPool);
        System.out.println(ioFuture.get());
        ioPool.shutdown();
    }
}
```

**Follow-up Questions**

- "What is the difference between `thenApply` and `thenApplyAsync`?"
- "Which thread executes the callback in `thenApply`?"
- "What happens if you call `get()` on a CompletableFuture that never completes?"

**Common Mistakes**

- Using `CompletableFuture.supplyAsync` for IO-bound tasks without specifying a custom executor "” they run in `ForkJoinPool.commonPool()` which is CPU-sized and gets starved by blocking IO.
- Not handling exceptions "” an unhandled exception in a stage silently makes the future complete exceptionally.

**Interview Traps**

- `thenApply` (without `Async`) runs in whichever thread completes the previous stage. If the previous stage completes immediately on the calling thread, the callback runs on the calling thread "” defeating the purpose of async.

**Quick Revision Notes**

- `supplyAsync` = async with return value. `runAsync` = async void.
- `thenApply` = transform. `thenAccept` = consume. `thenRun` = run after, no result.
- `Async` suffix variants guarantee a new thread from the pool.
- Always use custom `Executor` for IO-bound tasks.
- `completedFuture(val)` = pre-completed, useful in tests.

---

### Q18: How do you combine multiple CompletableFutures?

**Difficulty:** Hard | **Interview Frequency:** High

**Companies:** Amazon, Google, Goldman Sachs, Netflix, Stripe

**Short Answer (30"“60 seconds)**

`thenCombine` combines two futures when both complete. `thenCompose` chains futures sequentially (like flatMap "” when the next future depends on the result of the first). `allOf` waits for all futures in a group to complete. `anyOf` completes when any one future completes.

**Deep Explanation**

| Method | Use case |
|---|---|
| `thenCombine(other, BiFunction)` | Both futures run concurrently; combine their results |
| `thenCompose(Function<T, CompletableFuture<U>>)` | Sequential chaining; second future depends on first's result |
| `allOf(futures...)` | Wait for all; returns `CompletableFuture<Void>` |
| `anyOf(futures...)` | Returns `CompletableFuture<Object>` completing with first done result |

**thenCompose vs thenApply:**
`thenApply(f)` where `f` returns a `CompletableFuture<U>` gives `CompletableFuture<CompletableFuture<U>>`.
`thenCompose(f)` flattens it to `CompletableFuture<U>`.
This is exactly analogous to `Stream.map` vs `Stream.flatMap`.

**allOf pitfall:**
`allOf` returns `CompletableFuture<Void>`, so you cannot get individual results from it directly. You must collect each future separately and then call `join()` after `allOf` completes.

**Real-World Backend Example**

Parallel API calls for an order summary page:

```java
CompletableFuture<User> userFuture = userService.getAsync(userId);
CompletableFuture<List<Order>> ordersFuture = orderService.getByUserAsync(userId);
CompletableFuture<Account> accountFuture = accountService.getAsync(userId);

CompletableFuture<Void> all = CompletableFuture.allOf(userFuture, ordersFuture, accountFuture);
all.thenRun(() -> {
    User user = userFuture.join();
    List<Order> orders = ordersFuture.join();
    Account account = accountFuture.join();
    buildDashboard(user, orders, account);
}).get();
```

**Java 17 Code Example**

```java
import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;

public class CombiningFuturesDemo {

    static CompletableFuture<String> fetchUser(long id) {
        return CompletableFuture.supplyAsync(() -> "User-" + id);
    }

    static CompletableFuture<String> fetchPermissions(String userId) {
        return CompletableFuture.supplyAsync(() -> "PERM:" + userId);
    }

    public static void main(String[] args) throws Exception {
        // thenCompose "” sequential: fetch user then fetch permissions for that user
        CompletableFuture<String> userWithPerms = fetchUser(42)
            .thenCompose(userId -> fetchPermissions(userId));
        System.out.println(userWithPerms.get()); // PERM:User-42

        // thenCombine "” parallel: two independent fetches, combine results
        CompletableFuture<String> profile = CompletableFuture
            .supplyAsync(() -> "profile-data")
            .thenCombine(
                CompletableFuture.supplyAsync(() -> "preferences-data"),
                (p, pref) -> p + " + " + pref
            );
        System.out.println(profile.get()); // profile-data + preferences-data

        // allOf "” wait for all, then collect
        List<Long> userIds = List.of(1L, 2L, 3L, 4L, 5L);
        List<CompletableFuture<String>> futures = userIds.stream()
            .map(id -> fetchUser(id))
            .collect(Collectors.toList());

        CompletableFuture<Void> all = CompletableFuture.allOf(
            futures.toArray(new CompletableFuture[0])
        );

        CompletableFuture<List<String>> allResults = all.thenApply(
            v -> futures.stream().map(CompletableFuture::join).collect(Collectors.toList())
        );

        System.out.println(allResults.get()); // [User-1, User-2, User-3, User-4, User-5]

        // anyOf "” first one wins
        CompletableFuture<Object> fastest = CompletableFuture.anyOf(
            CompletableFuture.supplyAsync(() -> { sleep(100); return "slow"; }),
            CompletableFuture.supplyAsync(() -> { sleep(10);  return "fast"; }),
            CompletableFuture.supplyAsync(() -> { sleep(50);  return "medium"; })
        );
        System.out.println(fastest.get()); // fast
    }

    static void sleep(long ms) {
        try { Thread.sleep(ms); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
    }
}
```

**Follow-up Questions**

- "Why does `allOf` return `CompletableFuture<Void>` and not `CompletableFuture<List<T>>`?"
- "What is the difference between `thenCompose` and `thenCombine`?"
- "If one future in `allOf` fails, what happens to the others?"

**Common Mistakes**

- Calling `join()` on individual futures before `allOf` completes "” blocks the calling thread.
- Using `thenApply` when the function returns a `CompletableFuture` "” produces nested futures.

**Interview Traps**

- `anyOf` returns `CompletableFuture<Object>`, not a typed result "” you must cast. This is a type-safety limitation.
- If one future in `allOf` completes exceptionally, `allOf` itself completes exceptionally, but the other futures continue running "” they are not cancelled.

**Quick Revision Notes**

- `thenCompose` = sequential chaining (like flatMap). `thenCombine` = parallel, combine two.
- `allOf` = wait for all; returns `Void` "” collect individual results via `join()` after.
- `anyOf` = first wins; returns `Object` (type-unsafe).
- Failed future in `allOf` propagates exception; other futures still run.

---

### Q19: CompletableFuture vs Future "” what are the differences?

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Goldman Sachs, JPMorgan, Stripe

**Short Answer (30"“60 seconds)**

`Future<T>` (Java 5) represents a pending asynchronous result but lacks callback support and non-blocking chaining. The only way to get its result is `get()`, which blocks. `CompletableFuture` adds non-blocking callbacks (`thenApply`, `thenAccept`), combinators (`thenCombine`, `allOf`), exception handling (`exceptionally`, `handle`), and the ability to be manually completed (`complete()`).

**Deep Explanation**

| Feature | Future | CompletableFuture |
|---|---|---|
| Get result | `get()` "” blocks | `get()` blocks; callbacks are non-blocking |
| Callback on completion | No | `thenApply`, `thenAccept`, `thenRun` |
| Chain computations | No | `thenCompose`, `thenCombine` |
| Exception handling | `get()` throws `ExecutionException` | `exceptionally`, `handle`, `whenComplete` |
| Combine multiple | No | `allOf`, `anyOf` |
| Manual completion | No | `complete(T)`, `completeExceptionally(Throwable)` |
| Cancel | `cancel(boolean)` | `cancel(boolean)` (limited support) |

**Why Future is insufficient:**

```java
// Future "” must block to get result
Future<String> future = executor.submit(() -> fetchData());
// ... other work ...
String result = future.get(); // BLOCKS "” ties up a thread

// CompletableFuture "” non-blocking chain
CompletableFuture.supplyAsync(() -> fetchData())
    .thenApply(data -> transform(data))
    .thenAccept(result -> store(result))
    .exceptionally(ex -> { log(ex); return null; });
// Main thread free to do other work
```

**Real-World Backend Example**

Spring's `@Async` used to return `Future` (blocking). Modern code uses `CompletableFuture`:

```java
@Async
public CompletableFuture<UserProfile> loadProfile(Long userId) {
    return CompletableFuture.completedFuture(profileRepository.findById(userId).orElseThrow());
}
```

**Java 17 Code Example**

```java
import java.util.concurrent.*;

public class FutureVsCompletableFuture {

    public static void main(String[] args) throws Exception {
        ExecutorService executor = Executors.newSingleThreadExecutor();

        // Future "” blocking, no callbacks
        Future<String> future = executor.submit(() -> {
            Thread.sleep(100);
            return "result";
        });
        // Can only poll or block
        System.out.println("isDone: " + future.isDone());
        String result = future.get(); // BLOCKS
        System.out.println("Future result: " + result);

        // CompletableFuture "” non-blocking pipeline
        CompletableFuture.supplyAsync(() -> "raw-data")
            .thenApply(String::toUpperCase)
            .thenAccept(s -> System.out.println("CF result: " + s));
            // Main thread continues immediately

        // Manual completion "” useful for adapting callback APIs
        CompletableFuture<String> manual = new CompletableFuture<>();
        someCallbackApi(value -> manual.complete(value),
                        err -> manual.completeExceptionally(err));
        // manual.get() will return when the callback fires

        executor.shutdown();
    }

    static void someCallbackApi(java.util.function.Consumer<String> onSuccess,
                                java.util.function.Consumer<Throwable> onError) {
        new Thread(() -> onSuccess.accept("callback-result")).start();
    }
}
```

**Follow-up Questions**

- "How do you adapt a legacy callback-based API to CompletableFuture?"
- "Can you cancel a CompletableFuture? Does cancellation propagate?"

**Common Mistakes**

- Calling `.get()` on a `CompletableFuture` chain in a servlet thread "” blocks the thread and eliminates async benefits.

**Interview Traps**

- `CompletableFuture.cancel(true)` does not actually interrupt the running thread "” the cancellation only sets the future's state. The underlying task in the thread pool continues running. This differs from `Future.cancel(true)` which attempts to interrupt the thread.

**Quick Revision Notes**

- `Future` = submit + block on `get()`. No callbacks, no chaining.
- `CompletableFuture` = non-blocking callbacks, chaining, exception handling, manual completion.
- `complete(value)` and `completeExceptionally(ex)` enable bridging callback APIs.
- Cancellation does not interrupt the underlying thread.

---

### Q20: How do you handle exceptions in CompletableFuture?

**Difficulty:** Hard | **Interview Frequency:** High

**Companies:** Amazon, Google, Goldman Sachs, Netflix

**Short Answer (30"“60 seconds)**

Three methods handle exceptions: `exceptionally(Function<Throwable, T>)` recovers from an exception by providing a fallback value; `handle(BiFunction<T, Throwable, U>)` processes both normal result and exception in one callback; `whenComplete(BiConsumer<T, Throwable>)` observes result or exception for side effects but does not transform the result.

**Deep Explanation**

| Method | Receives | Returns | Transforms? | Recovers? |
|---|---|---|---|---|
| `exceptionally(fn)` | `Throwable` only | `T` (same type) | No "” only on exception path | Yes |
| `handle(fn)` | `(T, Throwable)` both | `U` (any type) | Yes | Yes |
| `whenComplete(fn)` | `(T, Throwable)` both | `CompletableFuture<T>` (same) | No | No |

**Key distinction:**
- `exceptionally` only runs when the previous stage failed; if successful, it passes through the result unchanged.
- `handle` always runs "” it receives either the result (with null throwable) or the exception (with null result). It can transform the result.
- `whenComplete` always runs but cannot change the outcome "” it is for side effects (logging, metrics).

**Exception wrapping:**
Exceptions in `CompletableFuture` are wrapped in `CompletionException`. When you call `get()`, they are wrapped in `ExecutionException`. Use `getCause()` to access the original exception.

**Real-World Backend Example**

```java
CompletableFuture<ApiResponse> callApi(String endpoint) {
    return CompletableFuture.supplyAsync(() -> httpClient.get(endpoint))
        .exceptionally(ex -> {
            log.warn("API call failed for {}: {}", endpoint, ex.getMessage());
            return ApiResponse.empty(); // graceful degradation
        })
        .handle((response, ex) -> {
            if (ex != null) return ApiResponse.error(ex);
            return response.withTimestamp(Instant.now());
        })
        .whenComplete((response, ex) -> metrics.record(endpoint, ex == null));
}
```

**Java 17 Code Example**

```java
import java.util.concurrent.*;

public class ExceptionHandlingDemo {

    public static void main(String[] args) throws Exception {

        // exceptionally "” recover from exception
        CompletableFuture<String> withRecovery = CompletableFuture
            .supplyAsync(() -> { throw new RuntimeException("service unavailable"); })
            .exceptionally(ex -> {
                System.out.println("exceptionally: " + ex.getMessage());
                return "fallback-value";
            });
        System.out.println(withRecovery.get()); // fallback-value

        // handle "” process both success and failure
        CompletableFuture<String> handled = CompletableFuture
            .supplyAsync(() -> "success-result")
            .handle((result, ex) -> {
                if (ex != null) {
                    System.out.println("handle exception: " + ex.getMessage());
                    return "error-default";
                }
                return result.toUpperCase();
            });
        System.out.println(handled.get()); // SUCCESS-RESULT

        // whenComplete "” side effect, does not change result
        CompletableFuture<String> observed = CompletableFuture
            .supplyAsync(() -> "data")
            .whenComplete((result, ex) -> {
                if (ex != null) System.out.println("LOG ERROR: " + ex);
                else System.out.println("LOG SUCCESS: " + result);
            });
        System.out.println(observed.get()); // data (unchanged)

        // Exception in exceptionally propagates if exceptionally itself throws
        CompletableFuture<String> chainedEx = CompletableFuture
            .<String>supplyAsync(() -> { throw new RuntimeException("first"); })
            .exceptionally(ex -> { throw new RuntimeException("second: " + ex.getMessage()); })
            .exceptionally(ex -> "caught-second: " + ex.getMessage());
        System.out.println(chainedEx.get()); // caught-second: ...
    }
}
```

**Follow-up Questions**

- "If `exceptionally` throws, what happens?"
- "Can you use `handle` to convert exception to a different exception type?"
- "What is the difference between `whenComplete` and `handle`?"

**Common Mistakes**

- Confusing `whenComplete` and `handle` "” `whenComplete` cannot transform the result or recover from exceptions.
- Not unwrapping `CompletionException` / `ExecutionException` when calling `get()`.

**Interview Traps**

- `exceptionally` receives a `CompletionException` wrapping the original exception, not the original exception directly. You need `ex.getCause()` to get the root cause.

**Quick Revision Notes**

- `exceptionally` = recovery, exception path only.
- `handle` = always runs, can transform result and handle exception.
- `whenComplete` = side effect only, cannot change outcome.
- Exceptions wrapped in `CompletionException`; `get()` wraps in `ExecutionException`.
- Chain `exceptionally` to re-wrap or re-throw.

---

### Q21: Real-world pattern: parallel API calls with CompletableFuture.allOf()

**Difficulty:** Hard | **Interview Frequency:** High

**Companies:** Amazon, Google, Goldman Sachs, Netflix, Stripe, Uber

**Short Answer (30"“60 seconds)**

When building aggregation endpoints "” such as a dashboard that needs user data, order history, and account balance simultaneously "” launch all requests in parallel with `supplyAsync`, then use `CompletableFuture.allOf()` to wait for all of them. After `allOf` completes, collect results with `join()`. Use a dedicated IO thread pool, not the common fork-join pool, to avoid thread starvation.

**Deep Explanation**

This is the single most practical CompletableFuture pattern in backend development. The naive sequential approach makes N HTTP calls taking NÃ—latency. The parallel approach takes approximately max(latency_1, ..., latency_N).

**Critical detail:** Always use a custom `ExecutorService` for IO-bound parallel calls. `ForkJoinPool.commonPool()` is designed for CPU-bound work and will starve if threads block on IO.

**Error handling strategy:** Decide upfront whether partial failure should fail the whole aggregation or whether you want best-effort results. `allOf` fails fast on any exception; for best-effort, wrap each future in `exceptionally` before passing to `allOf`.

**Java 17 Code Example**

```java
import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;

public class ParallelApiCallsDemo {

    record UserProfile(long id, String name) {}
    record OrderSummary(long userId, int orderCount, double totalValue) {}
    record AccountBalance(long userId, double balance) {}
    record Dashboard(UserProfile profile, OrderSummary orders, AccountBalance balance) {}

    // Simulate IO-bound service calls
    static UserProfile fetchProfile(long userId) throws InterruptedException {
        Thread.sleep(150); return new UserProfile(userId, "Alice");
    }
    static OrderSummary fetchOrders(long userId) throws InterruptedException {
        Thread.sleep(200); return new OrderSummary(userId, 42, 5430.00);
    }
    static AccountBalance fetchBalance(long userId) throws InterruptedException {
        Thread.sleep(100); return new AccountBalance(userId, 12500.00);
    }

    public static void main(String[] args) throws Exception {
        // Dedicated IO pool "” do NOT use commonPool for IO
        ExecutorService ioPool = Executors.newFixedThreadPool(20);
        long userId = 1L;

        long start = System.currentTimeMillis();

        // Launch all in parallel
        CompletableFuture<UserProfile> profileFuture = CompletableFuture
            .supplyAsync(() -> {
                try { return fetchProfile(userId); }
                catch (InterruptedException e) { throw new CompletionException(e); }
            }, ioPool);

        CompletableFuture<OrderSummary> ordersFuture = CompletableFuture
            .supplyAsync(() -> {
                try { return fetchOrders(userId); }
                catch (InterruptedException e) { throw new CompletionException(e); }
            }, ioPool);

        CompletableFuture<AccountBalance> balanceFuture = CompletableFuture
            .supplyAsync(() -> {
                try { return fetchBalance(userId); }
                catch (InterruptedException e) { throw new CompletionException(e); }
            }, ioPool);

        // Wait for all "” overall latency approximately max(150, 200, 100) = 200ms
        CompletableFuture<Dashboard> dashboardFuture = CompletableFuture
            .allOf(profileFuture, ordersFuture, balanceFuture)
            .thenApply(v -> new Dashboard(
                profileFuture.join(),   // safe: already complete at this point
                ordersFuture.join(),
                balanceFuture.join()
            ));

        // Best-effort variant: partial failure returns null for failed component
        CompletableFuture<UserProfile> safeProfile = profileFuture
            .exceptionally(ex -> { System.err.println("Profile failed: " + ex); return null; });

        Dashboard dashboard = dashboardFuture.get(2, TimeUnit.SECONDS);
        long elapsed = System.currentTimeMillis() - start;

        System.out.printf("Dashboard built in %dms (sequential would be ~450ms)%n", elapsed);
        System.out.println("User: " + dashboard.profile().name());
        System.out.println("Orders: " + dashboard.orders().orderCount());
        System.out.println("Balance: " + dashboard.balance().balance());

        ioPool.shutdown();
    }
}
```

**Follow-up Questions**

- "What happens if one of the futures in `allOf` times out?"
- "How would you implement a timeout for the entire dashboard call?"
- "How do you handle partial success "” some calls succeed, some fail?"

**Common Mistakes**

- Using `ForkJoinPool.commonPool()` for IO-bound parallel calls.
- Calling `join()` before `allOf` completes "” this blocks the current thread.
- Not setting a timeout on the final `get()` "” a hung service can block forever.

**Interview Traps**

- `join()` vs `get()`: both block until the future completes. `join()` throws unchecked `CompletionException`; `get()` throws checked `ExecutionException`. In `thenApply` callbacks, use `join()` since you cannot throw checked exceptions.

**Quick Revision Notes**

- Parallel API calls: `supplyAsync` each + `allOf` + `thenApply(v -> joinAll)`.
- Use custom IO executor, not `commonPool`.
- `join()` in callbacks (unchecked); `get(timeout, unit)` at the call site.
- Partial failure: wrap each future in `exceptionally` before `allOf`.
- Latency approximately equals slowest call, not sum of all calls.

---


---

## Section 5: Java 9-17 Important Additions

---

### Q22: What is the `var` keyword introduced in Java 10?

**Difficulty:** Easy | **Interview Frequency:** Medium
**Companies:** Amazon, Google, Atlassian, Adobe

**Short Answer (30-60 seconds)**
`var` enables local variable type inference - the compiler infers the type from the right-hand side at compile time. It is not dynamic typing; the type is fixed at compile time. It can only be used for local variables with initializers, not for fields, method parameters, or return types.

**Deep Explanation**

`var` is purely a compile-time feature. The bytecode is identical to writing the explicit type. The compiler reads the initializer expression and determines the type - this is called LVTI (Local Variable Type Inference).

**Where `var` can be used:**
- Local variables with an initializer
- Loop variables (`for (var entry : map.entrySet())`)
- Try-with-resources variables

**Where `var` cannot be used:**
- Instance or static fields
- Method parameters
- Method return types
- Without an initializer (`var x;` is illegal)
- With null initializer (`var x = null;` is illegal - type cannot be inferred)

**Java 17 Code Example**

```java
import java.util.*;
import java.util.stream.*;

public class VarDemo {
    public static void main(String[] args) {
        // Clear - type obvious from constructor
        var list = new ArrayList<String>();
        list.add("Alice");
        list.add("Bob");

        // Clear - type obvious from Map.entry
        var map = Map.of("a", 1, "b", 2);
        for (var entry : map.entrySet()) {
            System.out.println(entry.getKey() + "=" + entry.getValue());
        }

        // Avoid var when type is not obvious from right-hand side
        // var result = userService.findActive();  // What type is this?
    }
}
```

**Follow-up Questions**
- "Is `var` dynamic typing like JavaScript?" (No - type is fixed at compile time.)
- "Can you use `var` for a lambda expression?" (No - lambda needs a target type.)
- "Does `var` affect performance?" (No - identical bytecode.)

**Common Mistakes**
- Using `var` where the type is not obvious, making code harder to read.
- Trying to use `var` for fields or method parameters.

**Interview Trap**
```java
var list = new ArrayList<>();   // inferred as ArrayList<Object>, NOT ArrayList<String>
list.add("hello");
list.add(42);   // compiles - no generic type constraint
```
Always provide the generic type: `var list = new ArrayList<String>()`.

**Quick Revision**
> `var` = compile-time local type inference. Not dynamic. Cannot use for fields/params/return types. Always provide generic type argument when using with collections.

---

### Q23: What are Records in Java 16?

**Difficulty:** Easy-Medium | **Interview Frequency:** High
**Companies:** Amazon, Google, Goldman Sachs, Stripe, Atlassian

**Short Answer (30-60 seconds)**
Records are immutable data carrier classes introduced in Java 16. They automatically generate a canonical constructor, `equals()`, `hashCode()`, `toString()`, and accessor methods for all components. They replace boilerplate-heavy POJOs/DTOs and signal clear intent: this class carries data, not behavior.

**Deep Explanation**

A record declaration `record Point(int x, int y) {}` generates:
- A `private final` field for each component
- A canonical constructor matching all components
- Public accessor methods named after the fields (`x()`, `y()`) - not `getX()`
- `equals()` and `hashCode()` based on all components
- `toString()` in the format `Point[x=1, y=2]`

**Compact constructor** for validation:
```java
record PositiveAmount(double value) {
    PositiveAmount {
        if (value <= 0) throw new IllegalArgumentException("Amount must be positive");
    }
}
```

**Java 17 Code Example**

```java
public class RecordDemo {

    record Point(double x, double y) {
        Point {
            if (Double.isNaN(x) || Double.isNaN(y))
                throw new IllegalArgumentException("Coordinates cannot be NaN");
        }

        public double distanceTo(Point other) {
            double dx = this.x - other.x;
            double dy = this.y - other.y;
            return Math.sqrt(dx * dx + dy * dy);
        }
    }

    record Pair<A, B>(A first, B second) {}

    public static void main(String[] args) {
        var p1 = new Point(3, 4);
        var p2 = new Point(0, 0);
        System.out.println(p1);                         // Point[x=3.0, y=4.0]
        System.out.println(p1.distanceTo(p2));          // 5.0
        System.out.println(p1.equals(new Point(3, 4))); // true

        var pair = new Pair<>("hello", 42);
        System.out.println(pair.first() + ", " + pair.second());
    }
}
```

**Follow-up Questions**
- "Can a record extend another class?" (No - implicitly extends Record.)
- "Can a record be mutable?" (No - all fields are final.)
- "Can records be used as JPA entities?" (No - JPA requires a no-arg constructor and mutable fields.)

**Common Mistakes**
- Expecting getter-style method names (`getX()`) - records use `x()`.
- Trying to use records as JPA entities.

**Quick Revision**
> Record = immutable data carrier. Auto-generates constructor, equals/hashCode, toString, accessors. Cannot extend classes. Compact constructor for validation. Not suitable for JPA entities.

---

### Q24: What are Sealed Classes in Java 17?

**Difficulty:** Medium | **Interview Frequency:** Medium
**Companies:** Amazon, Google, Goldman Sachs

**Short Answer (30-60 seconds)**
Sealed classes restrict which classes can extend or implement them using the `permits` clause. They enable exhaustive pattern matching - the compiler knows all possible subtypes, so switch expressions can be verified as complete. They model closed domain hierarchies where all subtypes are known.

**Deep Explanation**

Each permitted subclass must be `final`, `sealed`, or `non-sealed`.
- `final` - no further subclassing
- `sealed` - further restricts its own subclasses
- `non-sealed` - reopens the hierarchy

**Java 17 Code Example**

```java
public sealed interface PaymentMethod
    permits CreditCard, BankTransfer, Wallet {}

public record CreditCard(String cardNumber, String cvv) implements PaymentMethod {}
public record BankTransfer(String accountNumber, String routingNumber) implements PaymentMethod {}
public final class Wallet implements PaymentMethod {
    private final double balance;
    public Wallet(double balance) { this.balance = balance; }
    public double getBalance() { return balance; }
}

public class PaymentProcessor {
    public double getProcessingFee(PaymentMethod method) {
        return switch (method) {
            case CreditCard cc  -> 2.9;
            case BankTransfer bt -> 0.50;
            case Wallet w       -> 0.0;
            // No default needed - compiler knows all cases are covered
        };
    }
}
```

**Follow-up Questions**
- "What must permitted subclasses be declared as?" (final, sealed, or non-sealed)
- "How do sealed classes enable exhaustive switch?"

**Quick Revision**
> Sealed class = closed hierarchy with `permits`. Subclasses must be final/sealed/non-sealed. Enables exhaustive switch. Ideal for domain result types and discriminated unions.

---

### Q25: What are Text Blocks in Java 15?

**Difficulty:** Easy | **Interview Frequency:** Medium
**Companies:** Any company using Java 15+

**Short Answer (30-60 seconds)**
Text blocks are multiline string literals delimited by `"""`. They preserve line breaks without escape sequences, making embedded SQL, JSON, HTML readable. The compiler strips incidental indentation based on the closing `"""` position.

**Java 17 Code Example**

```java
public class TextBlockDemo {
    public static void main(String[] args) {

        String query = """
                SELECT u.id, u.name, u.email
                FROM users u
                WHERE u.active = true
                ORDER BY u.created_at DESC
                """;

        String json = """
                {
                    "orderId": "ORD-001",
                    "amount": 99.99
                }
                """;

        String html = """
                <html>
                    <body><h1>Hello, %s!</h1></body>
                </html>
                """.formatted("World");

        // Line continuation - no newline in output
        String oneLine = """
                This is \
                one line""";
        System.out.println(oneLine);  // "This is one line"
    }
}
```

**Common Mistakes**
- Placing closing `"""` at column 0 strips all indentation unexpectedly.

**Quick Revision**
> Text blocks = `"""..."""`. No escape needed for quotes or newlines. Strips incidental indentation. Use `.formatted()` for interpolation. Ideal for SQL, JSON, HTML in tests.

---

### Q26: What is Pattern Matching for `instanceof` in Java 16?

**Difficulty:** Easy | **Interview Frequency:** High
**Companies:** Amazon, Google, Goldman Sachs, Atlassian

**Short Answer (30-60 seconds)**
Pattern matching for `instanceof` eliminates the explicit cast after a type check. Instead of `if (obj instanceof String) { String s = (String) obj; ... }`, you write `if (obj instanceof String s) { ... }` - the variable `s` is automatically bound and cast within the true-branch scope.

**Deep Explanation**

The pattern variable is in scope only where the type check holds true. It can be combined with `&&` for compound conditions. Pairs naturally with sealed classes and switch expressions for exhaustive type dispatch.

**Java 17 Code Example**

```java
public class PatternMatchingDemo {

    sealed interface Shape permits Circle, Rectangle, Triangle {}
    record Circle(double radius) implements Shape {}
    record Rectangle(double width, double height) implements Shape {}
    record Triangle(double base, double height) implements Shape {}

    public static double area(Shape shape) {
        if (shape instanceof Circle c) {
            return Math.PI * c.radius() * c.radius();
        } else if (shape instanceof Rectangle r) {
            return r.width() * r.height();
        } else if (shape instanceof Triangle t) {
            return 0.5 * t.base() * t.height();
        }
        throw new IllegalArgumentException("Unknown shape");
    }

    // Cleaner with switch expression (Java 21 standard)
    public static double areaSwitch(Shape shape) {
        return switch (shape) {
            case Circle c    -> Math.PI * c.radius() * c.radius();
            case Rectangle r -> r.width() * r.height();
            case Triangle t  -> 0.5 * t.base() * t.height();
        };
    }

    public static void main(String[] args) {
        System.out.println(area(new Circle(5)));          // ~78.5
        System.out.println(area(new Rectangle(4, 6)));   // 24.0
        System.out.println(areaSwitch(new Triangle(3, 8))); // 12.0

        // Guard clause pattern
        Object obj = "hello";
        if (!(obj instanceof String s)) return;
        System.out.println(s.toUpperCase()); // s in scope here
    }
}
```

**Follow-up Questions**
- "What is the scope of the pattern variable in a negated instanceof check?"
- "How does this relate to sealed classes?"

**Quick Revision**
> `obj instanceof Type t` binds `t` in the true-branch. No explicit cast needed. Combines with `&&`. Pairs with sealed classes for exhaustive switch dispatch.

---

## Streams Quick Reference Cheat Sheet

| Operation | Type | Returns | Short-circuit | Notes |
|---|---|---|---|---|
| `filter(Predicate)` | Intermediate | `Stream<T>` | No | Stateless |
| `map(Function)` | Intermediate | `Stream<R>` | No | 1-to-1 transform |
| `flatMap(Function)` | Intermediate | `Stream<R>` | No | 1-to-many, flatten |
| `distinct()` | Intermediate | `Stream<T>` | No | Stateful, buffers all |
| `sorted()` | Intermediate | `Stream<T>` | No | Stateful, buffers all |
| `limit(n)` | Intermediate | `Stream<T>` | Yes | Stateful |
| `skip(n)` | Intermediate | `Stream<T>` | No | Stateful |
| `peek(Consumer)` | Intermediate | `Stream<T>` | No | Debug only |
| `takeWhile(Predicate)` | Intermediate | `Stream<T>` | Yes | Java 9+ |
| `dropWhile(Predicate)` | Intermediate | `Stream<T>` | No | Java 9+ |
| `forEach(Consumer)` | Terminal | `void` | No | Unordered in parallel |
| `collect(Collector)` | Terminal | `R` | No | Most flexible |
| `toList()` | Terminal | `List<T>` | No | Java 16+, unmodifiable |
| `count()` | Terminal | `long` | No | |
| `reduce(identity, op)` | Terminal | `T` | No | Fold |
| `findFirst()` | Terminal | `Optional<T>` | Yes | Ordered |
| `findAny()` | Terminal | `Optional<T>` | Yes | Parallel-friendly |
| `anyMatch(Predicate)` | Terminal | `boolean` | Yes | |
| `allMatch(Predicate)` | Terminal | `boolean` | Yes | Empty stream: true |
| `noneMatch(Predicate)` | Terminal | `boolean` | Yes | Empty stream: true |

### Key Collectors

| Collector | Returns | Notes |
|---|---|---|
| `toList()` | `List<T>` | Mutable |
| `toUnmodifiableList()` | `List<T>` | Immutable |
| `toMap(k, v)` | `Map<K,V>` | Throws on duplicate keys |
| `toMap(k, v, merge)` | `Map<K,V>` | Merge fn for duplicates |
| `groupingBy(f)` | `Map<K,List<T>>` | Most versatile |
| `groupingBy(f, downstream)` | `Map<K,R>` | Nested aggregation |
| `partitioningBy(p)` | `Map<Boolean,List<T>>` | Always 2 keys |
| `joining(delim, pre, suf)` | `String` | CSV, formatted output |
| `counting()` | `Long` | Use as downstream |
| `averagingDouble(f)` | `Double` | Use as downstream |
| `summarizingDouble(f)` | `DoubleSummaryStatistics` | min/max/avg/count/sum |

---

*End of Chapter 4 - Next: Chapter 5: JVM Internals*

