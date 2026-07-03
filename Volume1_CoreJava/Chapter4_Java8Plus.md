# Volume 1: Core Java
# Chapter 4: Java 8+ Features

---

## Table of Contents
1. Lambdas & Method References
2. Functional Interfaces
3. Streams — Pipeline, Operations & Collectors
4. Streams — Advanced Usage
5. Optional
6. CompletableFuture
7. Java 9–17 Key Additions
8. Java 8+ Quick Reference

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: Lambdas & Method References

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Amazon, Google, Microsoft, Goldman Sachs, Atlassian, Netflix

---

### The Idea

Before Java 8, passing behavior meant writing an anonymous inner class — a verbose block of boilerplate just to say "do this one thing." A lambda expression is a shorthand for the same idea: it represents an instance of a functional interface (any interface with exactly one abstract method) without the ceremony.

Think of a lambda like a sticky note attached to a job description. The functional interface is the job description ("I need something that takes a String and returns a boolean"). The lambda is the sticky note you hand back: `name -> name.length() > 5`. No class name, no `new`, no `@Override` — just the logic.

Method references take this a step further. When your lambda body does nothing but call an existing method — `s -> s.toUpperCase()` — you can just write `String::toUpperCase`. Same compiled output, cleaner to read.

---

### How It Works

**Lambda compilation (pseudocode):**
```
Compiler sees lambda expression
  → emits invokedynamic bytecode instruction (not a .class file)
  → first call at runtime: JVM invokes LambdaMetafactory.metafactory()
  → LambdaMetafactory generates a hidden class implementing the functional interface
  → subsequent calls: reuse the linked CallSite — no repeated bootstrap cost
```

**Variable capture rules (pseudocode):**
```
Lambda can freely access:
  → instance variables of the enclosing class
  → static variables
  → local variables ONLY IF they are effectively final
      (never reassigned after initialization)

Reason: local variables live on the stack.
If the lambda outlives the method call (e.g. passed to another thread),
the JVM must copy the variable into the lambda closure.
Mutation would introduce race conditions.
```

**Four types of method reference:**

| Type | Syntax | Equivalent lambda |
|---|---|---|
| Static method | `Integer::parseInt` | `s -> Integer.parseInt(s)` |
| Instance — specific object | `log::add` | `s -> log.add(s)` |
| Instance — arbitrary object | `String::toUpperCase` | `s -> s.toUpperCase()` |
| Constructor | `ArrayList::new` | `() -> new ArrayList<>()` |

Key distinction for Type 2 vs Type 3: Type 2 captures a specific object already in scope. Type 3 receives the object as its first argument at call time — the stream element becomes the receiver.

**The one interview-critical gotcha — `this` inside a lambda vs anonymous class:**

```java
public class MyService {
    private String name = "service";

    Runnable lambda = () -> System.out.println(this.name);
    // 'this' = MyService instance — correct

    Runnable anon = new Runnable() {
        @Override public void run() {
            System.out.println(this.name); // compile error — 'this' = the anonymous class
        }
    };
}
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is a lambda expression and how does the compiler handle it?"**

**One-line answer:** A lambda is a concise instance of a functional interface, compiled via `invokedynamic` rather than generating a separate `.class` file.

**Full answer to give in an interview:**
> "A lambda expression lets me represent a single-method behavior — what Java calls a functional interface — without writing an anonymous inner class. The key difference from anonymous classes is at the bytecode level. The compiler emits an `invokedynamic` instruction, which is a special JVM opcode that defers method linkage to runtime. On the first call, the JVM invokes a bootstrap method called `LambdaMetafactory`, which generates a hidden class that implements the functional interface. After that first call, the CallSite is linked and subsequent calls go straight to it with no bootstrap overhead. This is why lambdas are more efficient than anonymous classes — no separate `.class` file, less class-loading pressure. There's also a capture rule: lambdas can freely read instance variables and static variables, but can only capture local variables if they are effectively final, meaning never reassigned after initialization. This exists because local variables live on the stack, and if the lambda outlives the stack frame — for example if it's passed to another thread — the JVM has to copy the value into the lambda's closure. Allowing mutation would cause race conditions."

*Say this in about 60 seconds. Emphasize the invokedynamic/LambdaMetafactory point — interviewers at Goldman and Amazon ask this specifically.*

**Gotcha follow-up they'll ask:** *"Is a lambda expression always a new object every time it is evaluated?"*

> No. The JVM may cache stateless lambdas — lambdas that capture no variables — as singletons. When there's nothing to capture, the same object can be reused safely across invocations. Lambdas that capture variables must produce a new object each time, because the captured state is part of the instance. This is an optimization detail, not a guarantee in the spec, but it is worth knowing because interviewers use it to test whether you understand the difference between stateless and stateful lambdas.

---

#### Q2 — Concept Check

**"What are method references and what are the four types?"**

**One-line answer:** Method references are shorthand lambdas that call an existing method directly, compiled via the same `invokedynamic` mechanism.

**Full answer to give in an interview:**
> "A method reference is just syntactic sugar for a lambda whose body does nothing but call one method. There are four types. First, a static method reference like `Integer::parseInt` — equivalent to `s -> Integer.parseInt(s)`. Second, an instance method reference on a specific captured object, like `log::add` where `log` is already in scope — equivalent to `s -> log.add(s)`. Third, an instance method reference on an arbitrary object of a type, like `String::toUpperCase` — here the stream element itself becomes the receiver, so `s -> s.toUpperCase()`. Fourth, a constructor reference like `ArrayList::new` — equivalent to `() -> new ArrayList<>()`. The confusing pair is type two versus type three. Type two captures a specific object. Type three has no captured object — the object is supplied as the first argument at call time, which is why you use the class name rather than an instance name. For example, `String::compareTo` as a `Comparator<String>` works because the two strings are passed as arguments — the first becomes the receiver, the second is the argument to `compareTo`."

*Lead with the four types table mentally. Slow down on type 2 vs 3 — that's where interviewers probe.*

**Gotcha follow-up they'll ask:** *"What functional interface does `String::valueOf` correspond to?"*

> `String::valueOf` is a static method that takes an `Object` and returns a `String`, so it corresponds to `Function<Object, String>`. If used in a context expecting `Function<Integer, String>`, the compiler will resolve it as `Function<Integer, String>` because `valueOf` has an overload accepting `int`. The compiler picks the overload that matches the target functional interface's signature.

---

#### Q3 — Tradeoff Question

**"When would you prefer a lambda over a method reference, or vice versa?"**

**One-line answer:** Prefer method references for pure delegation to an existing method; prefer lambdas when you need additional logic, argument reordering, or clarity over a non-obvious reference.

**Full answer to give in an interview:**
> "Method references are more readable when the lambda body is a straightforward delegation — `String::toUpperCase` communicates intent instantly. But I prefer lambdas in a few cases. First, when additional logic is needed: `s -> s.trim().toUpperCase()` cannot become a single method reference. Second, when the method reference type would be ambiguous or confusing — `String::compareTo` technically works as a `Comparator<String>` because the first string becomes the receiver and the second is the argument, but a reader might not recognize this immediately. Third, for argument reordering: if I want `(a, b) -> b.compareTo(a)` for reverse order, there is no method reference form. The underlying execution cost is identical — both compile to `invokedynamic` — so the choice is purely about readability and maintainability."

*This is a judgment question. Show you think about team readability, not just syntax tricks.*

**Gotcha follow-up they'll ask:** *"Can a method reference be used for a method that throws a checked exception?"*

> Only if the target functional interface's abstract method also declares that checked exception. Standard interfaces like `Function<T,R>` do not declare checked exceptions, so you cannot directly use a method reference to a method that throws `IOException` as a `Function`. The workaround is a custom functional interface — often called `ThrowingFunction` — whose abstract method declares `throws Exception`, plus a static wrapper that catches and re-throws as `RuntimeException`. This pattern is covered in the Functional Interfaces topic.

---

#### Q4 — Design Scenario

**"How do lambdas interact with concurrency? What are the rules around captured variables and thread safety?"**

**One-line answer:** Lambdas can only capture effectively final local variables, eliminating one class of race conditions, but captured instance state and shared mutable data structures still require explicit synchronization.

**Full answer to give in an interview:**
> "The effectively-final rule — meaning a captured local variable must never be reassigned after it is initialized — is a compile-time guarantee that prevents a specific concurrency bug: if a lambda is executed on a different thread and the capturing method has already returned, the local variable's stack frame is gone. The JVM copies the value into the lambda's closure at capture time. If mutation were allowed, you'd have a data race between the original stack frame and the copy. However, the rule only protects local variables. If the lambda captures an instance variable — for example `this.orders` — that's still shared mutable state. Two lambda instances running on separate threads can both read and write `this.orders` simultaneously unless I synchronize. Similarly, if I use a lambda with `parallelStream()` and the lambda has side effects on a shared list, I will get corruption or `ConcurrentModificationException`. Stateless lambdas — those that capture nothing — are inherently thread-safe and the JVM may even cache them as singletons."

*Good answer for senior-level interviews. Mention parallelStream side effects — that's the practical trap.*

**Gotcha follow-up they'll ask:** *"What's the difference between `this` inside a lambda vs `this` inside an anonymous inner class?"*

> Inside a lambda, `this` refers to the enclosing class instance — the same object you'd get if you used `this` in a regular method. Inside an anonymous inner class, `this` refers to the anonymous class instance itself, not the outer class. To access the outer class from an anonymous inner class, you need `OuterClass.this`. This is one of the subtle semantic differences between lambdas and anonymous classes that the compiler does not sugar away.

---

> **Common Mistake — Treating lambdas as pure anonymous class sugar:** Lambdas and anonymous classes differ in `this` semantics, bytecode representation, and capture rules. Writing code that relies on a lambda having its own `this` (for self-reference, for example) will not compile or behave as expected.

> **Common Mistake — Mutating captured variables via workaround:** Using a single-element array or an `AtomicInteger` to mutate a "captured" value from inside a lambda defeats the purpose of the effectively-final rule. It works at compile time but introduces the exact race condition the rule was designed to prevent if the lambda runs on another thread.

**Quick Revision (one line):** Lambda = `invokedynamic` + `LambdaMetafactory`, effectively-final capture, `this` = enclosing class; method references are syntactic sugar with four types distinguished by whether the receiver is captured or supplied.

---

## Topic 2: Functional Interfaces

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Amazon, Microsoft, Goldman Sachs, JPMorgan, Stripe, Uber

---

### The Idea

Java's type system is built around types, so to pass a lambda around you need a type for it to inhabit. That type is a functional interface: any interface with exactly one abstract method. The interface is the contract ("I accept a String and return a boolean"). The lambda fills the contract.

Java 8 ships a standard library of pre-built functional interfaces in `java.util.function` so you don't invent your own for every common pattern. There are five families: `Function` (transform), `Predicate` (test), `Consumer` (side effect), `Supplier` (produce), and `Operator` (same-type transform). Each also has two-input (`Bi-`) and primitive-specialized variants (`IntFunction`, `ToLongFunction`, etc.) to avoid boxing overhead.

When the standard interfaces don't fit — for example, you need a function that throws a checked exception, or one that takes three arguments — you define your own. The `@FunctionalInterface` annotation is optional but recommended: it makes the compiler enforce the single-abstract-method contract and documents the intent to future readers.

---

### How It Works

**Core functional interfaces at a glance:**

| Interface | Abstract method | What it does |
|---|---|---|
| `Function<T,R>` | `R apply(T t)` | Transform T to R |
| `BiFunction<T,U,R>` | `R apply(T t, U u)` | Two inputs, one output |
| `Predicate<T>` | `boolean test(T t)` | Test a condition |
| `BiPredicate<T,U>` | `boolean test(T t, U u)` | Two-input condition |
| `Consumer<T>` | `void accept(T t)` | Side effect, no return |
| `BiConsumer<T,U>` | `void accept(T t, U u)` | Two-input side effect |
| `Supplier<T>` | `T get()` | Produce a value, no input |
| `UnaryOperator<T>` | `T apply(T t)` | Transform T to same type T |
| `BinaryOperator<T>` | `T apply(T t1, T t2)` | Combine two T values into T |

**Composition pseudocode:**
```
Function f, Function g:
  f.andThen(g)  → input → f first → g second → output   (f then g)
  f.compose(g)  → input → g first → f second → output   (g then f)

Predicate p, Predicate q:
  p.and(q)      → true only if both pass
  p.or(q)       → true if either passes
  p.negate()    → flips result
  Predicate.not(p)  → same as negate, Java 11+

Consumer c1, Consumer c2:
  c1.andThen(c2) → run c1 then c2 on the same input
  (no compose — consumers return void, there is nothing to chain backward)
```

**The one interview-critical gotcha — `andThen` vs `compose` order:**

```java
Function<Integer, Integer> times2 = x -> x * 2;
Function<Integer, Integer> plus3  = x -> x + 3;

// andThen: times2 first, then plus3
times2.andThen(plus3).apply(5);  // (5*2)+3 = 13

// compose: plus3 first, then times2
times2.compose(plus3).apply(5);  // (5+3)*2 = 16
```

**Custom functional interface rules (pseudocode):**
```
A custom functional interface needs:
  → exactly ONE abstract method (the "functional method")
  → any number of default methods    (allowed)
  → any number of static methods     (allowed)
  → Object methods (equals, toString) do NOT count as abstract

@FunctionalInterface annotation:
  → optional at runtime
  → if present: compiler enforces exactly-one-abstract-method constraint
  → strongly recommended for documentation and safety
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q5 — Concept Check

**"What are the core built-in functional interfaces in Java 8 and when do you use each?"**

**One-line answer:** The five families are `Function` (transform), `Predicate` (test), `Consumer` (side effect), `Supplier` (produce), and `Operator` (same-type transform) — each covering a distinct role in functional pipelines.

**Full answer to give in an interview:**
> "Java 8 introduced a standard library of functional interfaces in `java.util.function` so you don't need to define your own for common patterns. I'll walk through the five families. `Function<T,R>` transforms an input of type T to an output of type R — the workhorse of stream `map` operations. `Predicate<T>` takes a T and returns a boolean — used in `filter`, validation, and conditional logic. `Consumer<T>` takes a T and returns nothing — it exists purely for side effects like logging or writing to a database. `Supplier<T>` takes no input and returns a T — useful for lazy evaluation, factory patterns, and `orElseGet` on Optional. `UnaryOperator<T>` and `BinaryOperator<T>` are specializations of `Function` where all types are the same — `UnaryOperator` for in-place transformations, `BinaryOperator` for reductions like `reduce` in streams. Each family also has two-input `Bi-` variants and primitive-specialized variants to avoid autoboxing overhead. Composition is built in: `Function` has `andThen` and `compose`, `Predicate` has `and`, `or`, `negate`, and `Consumer` has `andThen`."

*Mention the primitive variants (IntFunction, ToLongFunction) if you have time — it shows you think about performance.*

**Gotcha follow-up they'll ask:** *"What is the difference between `Function.andThen()` and `Function.compose()`?"*

> Both compose two functions into one, but the order differs. `f.andThen(g)` means apply `f` first, then pass its result to `g` — reading left to right. `f.compose(g)` means apply `g` first, then pass its result to `f` — the argument function runs before `this`. A concrete example: if `f` doubles a number and `g` adds three, `f.andThen(g).apply(5)` gives 13 (double then add), while `f.compose(g).apply(5)` gives 16 (add then double). The confusion is common because `andThen` reads naturally but `compose` reads mathematically (like function composition f∘g where g runs first).

---

#### Q6 — Concept Check

**"Why does `Consumer` have `andThen` but not `compose`?"**

**One-line answer:** `Consumer` returns void, so there is no output to feed as input to a preceding function — composition in reverse is meaningless.

**Full answer to give in an interview:**
> "Functional composition requires an output from one function to become the input of another. `Consumer<T>` accepts a value and returns nothing — void. `andThen` on `Consumer` threads the same original input to both consumers in sequence, which is valid and useful for chaining side effects like print then audit. But `compose` would mean: take my output, feed it to another function, then feed that result to me. Since my output is void, there is nothing to feed — the operation is undefined. The API designers simply omitted `compose` because it has no sensible semantics for a void-returning interface. The same logic applies to `BiConsumer`. This is also why `Consumer.andThen` takes a `Consumer` not a `Function` — you can only chain another consumer, not a transformer."

*Short question, short answer. This is a signal of whether you understand the type-level reasoning behind the API design.*

**Gotcha follow-up they'll ask:** *"When would you use `Supplier` instead of just calling a method directly?"*

> The key word is lazy. If I call a method directly — `orElse(computeExpensiveDefault())` — the expensive computation runs whether or not the Optional is empty. If I use a `Supplier` — `orElseGet(() -> computeExpensiveDefault())` — the computation only runs if the Optional is actually empty. `Supplier` defers execution until the value is truly needed. This matters for expensive database lookups, object construction, or any computation with side effects that should not happen unconditionally.

---

#### Q7 — Design Scenario

**"How do you handle checked exceptions inside a lambda? `Function<T,R>` doesn't declare any."**

**One-line answer:** Define a custom functional interface that declares `throws Exception`, then add a static wrapper method that catches and re-throws as `RuntimeException`.

**Full answer to give in an interview:**
> "The standard `Function<T,R>` interface does not declare any checked exceptions, so if my lambda calls a method that throws `IOException` — like a file read or HTTP call — it won't compile as a `Function`. There are two approaches. The quick approach is to wrap the exception inside the lambda: `t -> { try { return riskyCall(t); } catch (IOException e) { throw new RuntimeException(e); } }`. This works but is verbose and repeats at every use site. The cleaner approach is a custom functional interface — often called `ThrowingFunction<T,R>` — whose abstract method declares `throws Exception`. Then I add a static `wrap` method that converts a `ThrowingFunction` to a plain `Function` by doing the try-catch internally. That way I can write `.map(ThrowingFunction.wrap(url -> fetchData(url)))` cleanly throughout my codebase. The `wrap` method is a static method on the functional interface itself, which is allowed — functional interfaces can have any number of static methods."

*This comes up in any company that does stream-heavy data pipelines. Have the ThrowingFunction pattern memorized.*

**Gotcha follow-up they'll ask:** *"Can a functional interface extend another interface?"*

> Yes. A functional interface can extend another interface and still be functional if the result has exactly one abstract method. For example, `UnaryOperator<T>` extends `Function<T,T>` — it inherits `apply`, which is the one abstract method. The child interface adds no new abstract methods, just specializes the type. `Comparator<T>` is another example: it has many default and static methods, and even declares `equals(Object)`, but `equals` comes from `Object` and doesn't count as an abstract method in this context, so `Comparator` remains a valid functional interface with `compare` as its single abstract method.

---

#### Q8 — Tradeoff Question

**"When should you define a custom functional interface vs reuse a standard one?"**

**One-line answer:** Use standard interfaces whenever the signature fits; define custom ones when you need a checked exception declaration, more than two parameters, or domain-specific naming that improves readability.

**Full answer to give in an interview:**
> "The standard interfaces cover the vast majority of cases: transform, test, consume, produce, reduce. I default to them because they compose naturally with streams, Optional, and CompletableFuture — all of which are built around those types. I define a custom interface in three situations. First, when I need checked exceptions: as discussed, `Function` cannot declare them, so `ThrowingFunction` is necessary. Second, when the arity is wrong: the standard library goes up to `BiFunction` (two arguments) — if I need three parameters, I define `TriFunction`. Third, when domain naming makes the code significantly more readable: a `PricingStrategy` functional interface communicates intent better than a raw `BiFunction<Order, Context, Money>`, especially if that function is referenced in many places. The `@FunctionalInterface` annotation on custom interfaces is not required to make them work, but it is strongly recommended — it makes the compiler catch the mistake of accidentally adding a second abstract method, and it documents the intent."

*Show you default to standard interfaces — that's the right instinct. Custom interfaces are the exception, not the rule.*

**Gotcha follow-up they'll ask:** *"Does adding a second `default` method to a functional interface break it?"*

> No. Functional interfaces can have any number of default methods and static methods. Only abstract methods count toward the one-abstract-method constraint. Default methods have a body and are inherited by implementing classes (or lambdas). Adding `andThen` as a default method to a custom functional interface is perfectly valid and is exactly what the standard library does — `Function`, `Consumer`, and `Predicate` all have default composition methods.

---

> **Common Mistake — Confusing `andThen` and `compose` execution order:** `f.andThen(g)` runs `f` first; `f.compose(g)` runs `g` first. Getting this backwards silently produces wrong results — no compile error, no runtime exception.

> **Common Mistake — Using `orElse` with an expensive computation instead of `orElseGet`:** `orElse(expensiveMethod())` always evaluates the argument. `orElseGet(() -> expensiveMethod())` only evaluates it if the Optional is empty. The bug is silent — code is correct but wasteful, and in some cases causes unwanted side effects.

**Quick Revision (one line):** Function=transform, Predicate=test, Consumer=void side-effect, Supplier=lazy produce, Operator=same-type; `andThen` runs this-then-argument, `compose` runs argument-then-this; custom interfaces need one abstract method and should declare `@FunctionalInterface`.

---

## Topic 3: Streams — Pipeline, Operations & Collectors

**Difficulty:** Medium–Hard | **Frequency:** Very High | **Companies:** Amazon, Google, Goldman Sachs, Stripe, Netflix, Uber, JPMorgan

---

### The Idea

A stream is a conveyor belt for data. You set up a sequence of processing steps — filter these items, transform those, stop after five — and nothing moves until you press the start button at the end. That start button is the terminal operation. Until you add one, the conveyor belt just sits there with your instructions written on it but no items moving.

This is lazy evaluation: the pipeline description is built eagerly, but execution is deferred until a terminal operation pulls elements through. One element travels through all pipeline stages before the next element is fetched. This is why a `filter().limit(5)` on a million-element list only looks at the first handful of elements that pass the filter — it stops as soon as five pass, never touching the rest.

Collectors are the packaging station at the end of the belt. `collect()` is a terminal operation that accumulates stream elements into a container — a list, a map, a grouped structure. `Collectors.groupingBy` is the most powerful: it partitions elements by a classifier key and optionally applies a downstream collector (count, average, max) to each group.

---

### How It Works

**Pipeline structure (pseudocode):**
```
stream pipeline = source + zero or more intermediate ops + one terminal op

Source creates a Spliterator:
  → Spliterator knows how to traverse and optionally split the data source
  → tryAdvance() = process one element
  → trySplit()   = split for parallel processing
  → characteristics (SIZED, ORDERED, SORTED, DISTINCT...) guide optimizations

Intermediate ops (lazy):
  → each returns a new Stream (a linked ReferencePipeline stage)
  → no element processing happens yet
  → builds a description of what to do

Terminal op (triggers execution):
  → pulls elements one at a time through all fused stages
  → short-circuit terminals (findFirst, anyMatch) stop early
  → stateful ops (sorted, distinct) must buffer all elements before emitting
```

**map vs flatMap (pseudocode):**
```
map(f):
  for each element e → produce exactly ONE output: f(e)
  Stream<T> → Stream<R>
  shape is preserved: n inputs → n outputs

flatMap(f):
  for each element e → f(e) returns a Stream<R>
  all resulting streams are flattened into ONE stream
  Stream<T> → Stream<Stream<R>> → Stream<R>  (flatten removes one level)
  n inputs → 0 or more outputs per element
```

**Stateful vs stateless intermediate ops:**

| Operation | Type | Notes |
|---|---|---|
| `filter`, `map`, `flatMap`, `peek` | Stateless | Process each element independently |
| `distinct`, `sorted` | Stateful (buffered) | Must see ALL elements before emitting any |
| `limit`, `skip` | Stateful (counter) | `limit` is short-circuit; `skip` is not |
| `takeWhile`, `dropWhile` (Java 9) | Stateful | Stop/start based on predicate |

**Terminal operations summary:**

| Operation | Short-circuit? | Returns |
|---|---|---|
| `collect(Collector)` | No | Container |
| `forEach` | No | void |
| `reduce` | No | `T` or `Optional<T>` |
| `count` | Sometimes (SIZED) | `long` |
| `findFirst`, `findAny` | Yes | `Optional<T>` |
| `anyMatch`, `allMatch`, `noneMatch` | Yes | `boolean` |
| `min`, `max` | No | `Optional<T>` |
| `toArray` | No | `Object[]` or `T[]` |

**The one interview-critical gotcha — `toMap` throws on duplicate keys:**

```java
// DANGER: throws IllegalStateException if two employees share a dept
Map<String, Employee> byDept = employees.stream()
    .collect(Collectors.toMap(Employee::dept, e -> e)); // WRONG if depts repeat

// SAFE: provide a merge function
Map<String, Double> maxSalaryByDept = employees.stream()
    .collect(Collectors.toMap(
        Employee::dept,
        Employee::salary,
        Double::max   // merge: keep the higher salary on duplicate key
    ));
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q9 — Concept Check

**"How does a stream pipeline work? What is lazy evaluation and why does it matter?"**

**One-line answer:** A stream pipeline has a source, lazy intermediate operations, and a terminal operation that triggers execution; laziness means no element is processed until the terminal pulls it through.

**Full answer to give in an interview:**
> "A stream pipeline has three parts. The source — typically a collection, a file, or a generator — creates a `Spliterator`, which is the internal iterator abstraction that knows how to traverse and optionally split the data. Intermediate operations like `filter`, `map`, and `sorted` each return a new `Stream` object representing an additional stage in the pipeline. Critically, they do not execute anything. They just describe what to do. The terminal operation — `collect`, `findFirst`, `forEach`, and so on — is what actually starts element processing. When the terminal fires, it pulls elements one at a time through all fused stages. Lazy evaluation is what makes this efficient: elements are processed one at a time end-to-end rather than the entire collection passing through each stage in sequence. This means `limit(5)` on a million-element source stops processing after five qualifying elements — it never looks at the rest. It also means no intermediate collections are allocated. The one exception is stateful operations like `sorted` and `distinct`, which must buffer all elements before they can emit any output, breaking the one-at-a-time fusion for that stage."

*Draw the mental picture of one element traveling through all stages before the next one is fetched. That visual lands well.*

**Gotcha follow-up they'll ask:** *"What happens if I call a terminal operation on a stream that has already been consumed?"*

> It throws `IllegalStateException: stream has already been operated upon or closed`. A stream is single-use. Once a terminal operation has been called, the stream is considered consumed and cannot be reused. If you need to process the same data twice, you must either create two separate streams from the source, or collect to a list and stream from that. This is a common debugging trap — a `Stream` returned from a repository method might be consumed by one caller, and a second caller re-using the same reference gets the exception.

---

#### Q10 — Concept Check

**"Explain the difference between `map` and `flatMap` in streams."**

**One-line answer:** `map` transforms each element one-to-one; `flatMap` transforms each element into a stream and flattens all those streams into one — one-to-many with a flatten.

**Full answer to give in an interview:**
> "Both are intermediate operations that transform elements, but they differ in output cardinality. `map(f)` applies a function to each element and produces exactly one output per input — a `Stream<T>` becomes a `Stream<R>`. `flatMap(f)` applies a function where the function itself returns a `Stream<R>`, and then flattens all those inner streams into a single output stream. So a `Stream<T>` effectively becomes a `Stream<R>` after the flatten, but the intermediate shape was `Stream<Stream<R>>`. The practical difference: if I have a list of orders and each order has a list of line items, `map(Order::getLineItems)` gives me a `Stream<List<LineItem>>` — a stream of lists, not a flat stream of items. `flatMap(o -> o.getLineItems().stream())` gives me a `Stream<LineItem>` — all line items from all orders in one flat stream. A useful edge case: if `flatMap` returns `Stream.empty()` for some elements, those elements effectively disappear from the output, making `flatMap` also usable as a combined filter-and-transform."

*The order-lineitem example is the clearest real-world illustration. Use it.*

**Gotcha follow-up they'll ask:** *"Why is `sorted()` expensive on a parallel stream?"*

> `sorted()` is a stateful intermediate operation — it must see every element before it can emit any sorted output. In a parallel stream, the pipeline splits the data across multiple threads for concurrent processing. But `sorted()` requires all those partial results to be gathered and merged before sorting can proceed. This reassembly step negates the parallelism benefit for that stage and adds merge overhead on top. For large parallel streams, `sorted()` is often a bottleneck. If you need sorted output and the data is large, consider sorting at the database query level, sorting a list directly via `Collections.sort`, or accepting that the sorted stage will run serially.

---

#### Q11 — Concept Check

**"What are the main terminal operations and what is `reduce`?"**

**One-line answer:** Terminal operations trigger pipeline execution and produce a result or side effect; `reduce` folds all elements into a single value using an identity and a combining function.

**Full answer to give in an interview:**
> "Terminal operations are the trigger that starts element processing. They fall into a few categories. Aggregation: `count`, `min`, `max`, `sum` on primitive streams. Reduction to a single value: `reduce`. Collection into a container: `collect`. Short-circuit operations that may not process all elements: `findFirst`, `findAny`, `anyMatch`, `allMatch`, `noneMatch`. Side-effect operations: `forEach`, `forEachOrdered`. `reduce` works like this: you provide an identity value — a neutral starting point — and a `BinaryOperator` that combines two values of the same type. The stream folds left to right, combining the running accumulator with the next element repeatedly. For example, `reduce(0, Integer::sum)` starts at zero and adds each element. If you omit the identity, you get `Optional<T>` back because an empty stream has no result. One subtle rule: the identity must genuinely be neutral for the operation — `0` for addition, `1` for multiplication, empty string for concatenation — otherwise you corrupt the result."

*The identity-must-be-neutral point is an interview trap. Mention it.*

**Gotcha follow-up they'll ask:** *"Is `forEach` guaranteed to process elements in encounter order?"*

> On a sequential stream, yes — `forEach` processes elements in the stream's encounter order if one is defined (which it is for ordered sources like `List`). On a parallel stream, `forEach` does not guarantee order; threads process elements concurrently in whatever order they happen to complete. If order matters in a parallel stream, use `forEachOrdered`, which reestablishes encounter order at the cost of some parallelism benefit. There is also the vacuous truth trap: `allMatch` on an empty stream returns `true`, and `anyMatch` on an empty stream returns `false`. This is logically correct but frequently surprises developers who expect an empty stream to short-circuit to false for `allMatch`.

---

#### Q12 — Design Scenario

**"Explain `Collectors.groupingBy`, `partitioningBy`, and the `toMap` pitfall."**

**One-line answer:** `groupingBy` produces a `Map<K, List<V>>` grouped by a classifier; `partitioningBy` produces exactly two groups keyed by true/false; `toMap` throws `IllegalStateException` on duplicate keys unless you provide a merge function.

**Full answer to give in an interview:**
> "A `Collector` is the abstraction behind `collect()`. It defines how to accumulate stream elements into a container: a supplier to create the container, an accumulator to fold in each element, a combiner to merge two containers in parallel, and a finisher to produce the final result. `Collectors` is the utility class with pre-built implementations. `groupingBy(classifier)` takes a function from element to key and produces a `Map<K, List<V>>` where each key maps to all elements that produced it. You can chain a downstream collector as a second argument — `groupingBy(Employee::dept, Collectors.averagingDouble(Employee::salary))` gives you average salary per department directly. `partitioningBy(predicate)` is a specialized `groupingBy` with a boolean classifier — it always produces a map with both `true` and `false` keys, even if one group is empty. This differs from `groupingBy`, which only creates keys for groups that actually exist. `toMap` is the most dangerous collector: if two elements produce the same key and you haven't provided a merge function, it throws `IllegalStateException` at runtime — no warning at compile time. Always provide a merge function when your key mapper might not be unique. Also: `toMap` uses `HashMap.merge` internally and will throw `NullPointerException` if a value is null even when a merge function is present."

*The null-value NPE in `toMap` is the deep-level gotcha. Mentioning it marks you as someone who has actually debugged this in production.*

**Gotcha follow-up they'll ask:** *"What does `Stream.toList()` (Java 16) return — is it mutable?"*

> `Stream.toList()` introduced in Java 16 returns an unmodifiable list. It is a shorthand for `collect(Collectors.toUnmodifiableList())`. Attempting to call `add`, `remove`, or `set` on it throws `UnsupportedOperationException`. This is a silent behavioral change if you migrate code from `collect(Collectors.toList())` — the old form returns a mutable `ArrayList`, the new form does not. If mutability is needed after collection, keep using `collect(Collectors.toList())` or wrap the result in `new ArrayList<>(stream.toList())`.

---

> **Common Mistake — Building a pipeline with no terminal operation:** A stream with only intermediate operations executes nothing and produces no output. `list.stream().filter(...).map(...)` without a terminal call is completely inert. This is the most common stream debugging trap — the code looks like it should do something, but nothing happens.

> **Common Mistake — Calling `toMap` without a merge function on potentially non-unique keys:** The exception is thrown at runtime on the first duplicate key. If your data changes over time and keys that were once unique become duplicates, this is a latent production bug. Always ask: "Can two elements produce the same key?" before omitting the merge function.

**Quick Revision (one line):** Source → lazy intermediate ops → terminal triggers execution; `map` is 1:1, `flatMap` is 1:many-flattened; `sorted`/`distinct` buffer all elements; `reduce` folds with identity + BinaryOperator; `groupingBy` partitions into map, `toMap` needs a merge function for duplicate keys, `Stream.toList()` returns unmodifiable.

---

## Topic 4: Streams — Advanced Usage

**Difficulty:** Medium–Hard | **Frequency:** Very High | **Companies:** Amazon, Google, Goldman Sachs, Netflix, Stripe, Atlassian

---

### The Idea

Think of a stream as a conveyor belt in a factory. Raw material (your collection) sits in a warehouse (memory). You don't move all the material onto the belt at once — you only pull the next item when the next workstation is ready. That pull-on-demand behaviour is called **laziness**, and it is the foundational idea behind every stream feature.

A collection owns its data; a stream is a view over data that describes *what to do*, not *how to store it*. Because the description is separate from the data, the same pipeline can be executed sequentially or handed off to multiple workers (parallel streams) with a single method call.

Once you understand the lazy conveyor belt, four advanced topics fall into place naturally: (1) when to use streams vs. loops, (2) when to add more workers (parallel streams), (3) why there are special belts for numbers (primitive streams), and (4) why a used belt cannot be re-threaded (stream single-use rule) — plus the exotic case of a belt that never runs out of material (infinite streams).

### How It Works

**Stream vs. Collection — decision pseudocode:**

```
if operation is filter → map → reduce/collect
    AND no complex stateful mutations per element
    AND no checked exceptions to propagate
    → use stream

if you need index-based logic
    OR break-on-complex-condition with multiple mutations
    OR tight loop where profiling shows overhead matters
    → use for/while loop
```

**Parallel stream — internal flow:**

```
parallelStream() called
  → Spliterator.trySplit() splits source into sub-ranges
  → sub-tasks submitted to ForkJoinPool.commonPool()
  → each thread executes the pipeline independently
  → results merged using combiner from terminal operation
  → final result returned to caller
```

**Primitive stream — why it exists:**

```
Stream<Integer>: each int → new Integer() on heap → GC pressure
IntStream:       each int → raw int in CPU register → no allocation

IntStream.range(0, 1_000_000).sum()   // zero boxing
Stream.of(0..999999).mapToInt(i->i).sum()  // 1M Integer objects first
```

**Stream single-use rule:**

```
AbstractPipeline internal flag: linkedOrConsumed = false

terminal_op() called:
  → set linkedOrConsumed = true
  → execute pipeline

any_subsequent_call() on same Stream instance:
  → check linkedOrConsumed → true
  → throw IllegalStateException
```

**Infinite streams — safety contract:**

```
Stream.generate(supplier)   // unordered, no seed
Stream.iterate(seed, f)     // ordered: seed, f(seed), f(f(seed)), ...
Stream.iterate(seed, pred, f)  // Java 9: stops when pred is false

SAFE terminal ops:  findFirst(), findAny(), limit(n), takeWhile(p)
UNSAFE terminal ops: count(), collect(), forEach() — hang forever
```

**Single most interview-critical gotcha — orElse eagerness on streams:**

```java
// Parallel stream race condition — the classic trap
List<String> results = new ArrayList<>();
list.parallelStream().forEach(results::add); // RACE CONDITION: ArrayList not thread-safe

// Correct — use collect, which handles merging safely
List<String> results = list.parallelStream()
    .map(this::transform)
    .collect(Collectors.toList());
```

| Scenario | Stream | Loop |
|---|---|---|
| Filter → map → collect | Preferred | Verbose |
| Budget cap with break | Awkward | Natural |
| Large CPU-bound data, parallelisable | Parallel stream | Hard to parallelize |
| IO-bound (HTTP, DB) | Avoid parallel | Use async |
| Numeric aggregation (sum, avg) | IntStream/LongStream | Loop comparable |
| Infinite lazy sequence | Stream.iterate / generate | Awkward |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q9 — Tradeoff Question

**"When do you use streams instead of a for loop in Java?"**

**One-line answer:** Use streams for declarative filter–map–reduce pipelines; use loops when you need complex stateful control flow or checked exceptions.

**Full answer to give in an interview:**

> I reach for a stream when I can describe the work as a pipeline: filter this, transform that, collect the results. Streams let me write that pipeline declaratively, and they compose naturally — I can add `.parallel()` later without restructuring the logic. They are also lazy, so operations like `findFirst()` stop early rather than processing the whole collection.
>
> I switch to a loop when: (1) I need to `break` based on accumulated state across multiple fields — the shopping cart example where I stop adding items once a budget cap is reached is easier with a loop; (2) I'm mutating several fields of the same object per iteration; (3) I'm using checked exceptions heavily, because streams don't propagate checked exceptions without an ugly wrapper; or (4) I'm in a hot path and profiling shows the lambda dispatch overhead matters.
>
> For numeric work — summing, averaging — I always use `IntStream` or `LongStream` over `Stream<Integer>` to avoid autoboxing each `int` into an `Integer` object.

*Pause after "lazy". If the interviewer asks about laziness, explain that intermediate operations like `filter` and `map` don't execute until a terminal operation like `collect` is called — this enables short-circuit evaluation and infinite sources.*

**Gotcha follow-up they'll ask:** *"Are streams always slower than loops?"*

> No. For small collections (under ~1000 elements) the overhead from lambda dispatch and pipeline setup is negligible and the JIT often eliminates it. For large datasets with `.parallel()`, streams can significantly outperform a sequential loop. The rule is: measure before assuming either direction.

---

#### Q10 — Concept Check

**"How do parallel streams work internally, and when should you avoid them?"**

**One-line answer:** Parallel streams split the source via `Spliterator`, run subtasks in `ForkJoinPool.commonPool()`, then merge results — avoid them for IO-bound work, small data, stateful ops, or shared mutable state.

**Full answer to give in an interview:**

> When you call `.parallelStream()` or `.parallel()`, the stream's `Spliterator` recursively splits the data source into smaller sub-ranges. Each sub-range becomes a task submitted to `ForkJoinPool.commonPool()`, which by default has `(number of CPU cores - 1)` threads. Each thread runs the same pipeline independently; the terminal operation's combiner function merges the partial results back into the final answer.
>
> The critical thing to know about `commonPool` is that it is **shared across the entire JVM**. `CompletableFuture.supplyAsync()` also uses it by default. If a long-running parallel stream operation occupies all threads, it can starve async tasks elsewhere. For production workloads with bursty parallelism, I'd wrap the stream in a custom `ForkJoinPool.submit(() -> list.parallelStream()...)`.
>
> I avoid parallel streams when: the data is IO-bound (blocking threads in a CPU-sized pool is wasteful); the dataset is small (splitting and merging overhead exceeds the gain — rule of thumb: under ~10,000 elements, profile first); the operations are stateful like `sorted()` or `distinct()`, which require synchronisation; or there is shared mutable state in the lambda (a shared `ArrayList` passed to `forEach` will produce corrupt results silently). `LinkedList` also parallelizes poorly because its `Spliterator` must traverse to find a midpoint, unlike `ArrayList` which can split by index instantly.

*If the interviewer seems engaged, mention the `ArrayList` vs `LinkedList` Spliterator point — it signals you understand the implementation, not just the API.*

**Gotcha follow-up they'll ask:** *"Why is `list.parallelStream().forEach(sharedList::add)` wrong?"*

> `ArrayList` is not thread-safe. Multiple threads calling `add` simultaneously can corrupt the internal array — elements get lost, duplicate slots appear, or an `ArrayIndexOutOfBoundsException` is thrown. The correct pattern is to use `collect(Collectors.toList())`, which uses a thread-safe combining strategy internally.

---

#### Q11 — Concept Check

**"What are primitive streams? Why do they exist?"**

**One-line answer:** `IntStream`, `LongStream`, and `DoubleStream` avoid the boxing overhead of `Stream<Integer>` and add numeric terminal operations like `sum()`, `average()`, and `summaryStatistics()`.

**Full answer to give in an interview:**

> Java generics are erased at runtime and cannot hold primitive types — a `Stream<int>` is not legal. Without primitive streams, every `int` value in a `Stream<Integer>` must be autoboxed into an `Integer` object on the heap. For a stream of a million integers, that's a million short-lived objects driving GC pressure. `IntStream` works directly on raw `int` values, so there is no allocation, no GC cost, and the JIT can vectorise the loop.
>
> Beyond performance, primitive streams add terminal operations that don't exist on `Stream<T>`: `sum()`, `average()` (returns `OptionalDouble`), `min()`, `max()`, and `summaryStatistics()` which gives count, min, max, sum, and average in one pass.
>
> The bridge methods are: `stream.mapToInt(ToIntFunction)` to go from object stream to `IntStream`; `intStream.boxed()` to go back to `Stream<Integer>`; and `intStream.mapToObj(IntFunction)` to produce a `Stream<R>`. For ranges, `IntStream.range(0, n)` gives `[0, n)` — exclusive end, like a for loop — and `IntStream.rangeClosed(1, n)` gives `[1, n]` inclusive.

*The `range` vs `rangeClosed` distinction trips up candidates — mention it proactively to show you know the trap.*

**Gotcha follow-up they'll ask:** *"What does `IntStream.average()` return, and why isn't it just `double`?"*

> It returns `OptionalDouble` because the stream might be empty — there is no meaningful average of zero elements. Returning `0.0` would silently mislead callers, so the type forces them to handle the empty case explicitly.

---

#### Q12 — Concept Check

**"Why can't you reuse a stream after a terminal operation? How do you work around it?"**

**One-line answer:** Streams are single-use pipelines — the internal `linkedOrConsumed` flag is set on the first terminal operation, and any subsequent call throws `IllegalStateException`.

**Full answer to give in an interview:**

> A stream is not a data structure — it is a description of a pipeline over a data source. Once the terminal operation executes (say, `count()` or `collect()`), the pipeline has been "consumed": the source has been traversed and the internal flag `linkedOrConsumed` in `AbstractPipeline` is set to true. Any further operation on that same stream instance sees the flag and throws `IllegalStateException: stream has already been operated upon or closed`. This is by design — it prevents you from accidentally re-traversing the source expecting a fresh result.
>
> The fix is always to get a new stream from the source: `collection.stream()` is cheap and creates a fresh pipeline. If I want to express reusable stream logic without repeating the source reference, I use a `Supplier<Stream<T>>`: `Supplier<Stream<String>> s = names::stream;` — then `s.get()` returns a fresh stream each time.

*Keep it concise here — this is a simpler question. The `Supplier` pattern is the detail that earns marks.*

**Gotcha follow-up they'll ask:** *"If you store a stream as a field and inject it into a service, what happens?"*

> The first caller consumes it. Every subsequent caller gets `IllegalStateException`. Never store a stream as a field — always store the collection or the `Supplier<Stream<T>>` and create streams on demand.

---

#### Q13 — Design Scenario

**"What are infinite streams? How do you use `Stream.generate` and `Stream.iterate` safely?"**

**One-line answer:** Infinite streams produce elements on demand forever — safety comes from always pairing them with a short-circuit operation (`findFirst`, `limit`, `takeWhile`) that stops the pipeline.

**Full answer to give in an interview:**

> `Stream.generate(supplier)` calls the supplier repeatedly to produce an unordered, infinite sequence — useful for things like generating UUID correlation IDs or random values. `Stream.iterate(seed, f)` produces an ordered sequence: `seed`, `f(seed)`, `f(f(seed))`, and so on — think Fibonacci numbers or exponential backoff intervals.
>
> They are safe because streams are lazy: elements are only produced when the downstream operation asks for the next one. The danger is calling a terminal operation that demands *all* elements — `collect()`, `count()`, or `forEach()` on an infinite stream will hang forever. The rule is: always bound an infinite stream with `limit(n)`, `findFirst()`, `findAny()`, or Java 9's `takeWhile(predicate)`.
>
> `takeWhile` is particularly powerful for real-world use — I've used `Stream.iterate` to walk API pagination: start at page 0, produce page 1, 2, 3, and stop with `takeWhile(page -> !page.isEmpty())`. That's cleaner than a while loop with a mutable page counter.
>
> Java 9 also added a three-argument `Stream.iterate(seed, hasNextPredicate, nextFunction)` that is finite by construction — equivalent to `for (int n = seed; hasNext(n); n = f(n))`.

*The pagination example lands well — it connects infinite streams to a concrete backend use case interviewers recognise.*

**Gotcha follow-up they'll ask:** *"What is the difference between `takeWhile` and `filter` on an infinite stream?"*

> `filter` skips elements that don't match but keeps looking — on an infinite stream it would run forever if no element ever matches after a certain point. `takeWhile` stops the entire pipeline at the first non-matching element. For ordered streams, `takeWhile` is the correct tool for "take elements while this condition holds, then stop."

---

> **Common Mistake — Mutating shared state in parallel streams:** Passing a shared non-thread-safe collection to `parallelStream().forEach()` causes silent data corruption with no exception at compile time. The consequence is lost records and non-deterministic results that are nearly impossible to reproduce in tests. Always use `collect()`.

**Quick Revision (one line):** Streams = lazy declarative pipelines; use `IntStream` for numbers, `Supplier<Stream<T>>` for reuse, `limit`/`takeWhile` to bound infinite streams, and never touch shared mutable state inside `parallelStream`.

---

## Topic 5: Optional

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Amazon, Google, Goldman Sachs, Stripe, Netflix, Uber

---

### The Idea

Before Java 8, a method that might not find a result had two bad choices: return `null` (which callers routinely forgot to check, causing `NullPointerException` at runtime) or throw an exception (which is expensive and semantically wrong for "not found"). `Optional<T>` is a container that makes the absence of a value visible in the type system — the caller *must* decide what to do when nothing is there.

Think of it as a gift box that may or may not contain something. The box itself is never null — you always get a box back. But when you open it, you are forced to handle the "empty box" case. The compiler doesn't enforce this, but the API design nudges you strongly: there is no free `get()` that silently returns null.

The most important thing to internalise about `Optional` is its *intended scope*: it is a **method return type** for APIs that may produce no result. It is explicitly not meant for fields (it breaks serialisation), not for method parameters (use overloading), and not for wrapping collections (return an empty list instead). Brian Goetz, the Java language architect, described it as "a limited mechanism for library method return types, not a general-purpose Maybe monad."

### How It Works

**Creation — three factory methods:**

```
Optional.of(value)         → non-empty; NPE if value is null
Optional.ofNullable(value) → empty if value is null, non-empty otherwise
Optional.empty()           → singleton empty instance
```

**Extraction — ordered from dangerous to safe:**

```
.get()              → value or NoSuchElementException  [avoid]
.orElse(x)          → value or x                      [x always evaluated]
.orElseGet(sup)     → value or sup.get()               [lazy — only if empty]
.orElseThrow()      → value or NoSuchElementException  [Java 10, clearer than get()]
.orElseThrow(sup)   → value or throw sup.get()         [custom exception]
```

**Transformation pipeline:**

```
.map(f)        → Optional<R>          [f returns R; null return → empty]
.flatMap(f)    → Optional<R>          [f returns Optional<R>; avoids Optional<Optional<R>>]
.filter(pred)  → Optional<T>          [empty if pred false]
.or(sup)       → Optional<T>          [Java 9; fallback Optional if empty]
```

**Conditional execution:**

```
.ifPresent(consumer)              → run consumer if present
.ifPresentOrElse(consumer, run)   → Java 9; run runnable if empty
.stream()                         → Java 9; Stream<T> of 0 or 1 element
```

**Single most interview-critical gotcha — `orElse` vs `orElseGet`:**

```java
Optional<Config> cached = redisCache.get(key);

// BAD: loadFromDatabase() executes on EVERY call, even cache hits
Config c1 = cached.orElse(loadFromDatabase());

// GOOD: loadFromDatabase() executes ONLY on cache miss
Config c2 = cached.orElseGet(() -> loadFromDatabase());
```

| Method | Argument evaluated | When to use |
|---|---|---|
| `orElse(x)` | Always (eager) | Constants, literals, `null`, `Collections.emptyList()` |
| `orElseGet(sup)` | Only if empty (lazy) | Any method call, DB lookup, object construction |
| `map(f)` | Only if present | f returns a plain value |
| `flatMap(f)` | Only if present | f returns `Optional<R>` |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q14 — Concept Check

**"What is `Optional` and what problem does it solve? When should you not use it?"**

**One-line answer:** `Optional<T>` makes the absence of a return value explicit in the type system, forcing callers to handle the empty case — but it is for return types only, not fields, parameters, or collections.

**Full answer to give in an interview:**

> Before `Optional`, the Java convention for "nothing found" was to return `null`. The problem is that null is invisible at the call site — the compiler doesn't warn you, the method signature doesn't tell you, and a forgotten null check produces a `NullPointerException` that surfaces far from where the null was introduced. `Optional<T>` makes the contract explicit: the return type itself tells you "this might be absent," and the API forces you to decide what to do.
>
> The correct use is as a **method return type** in APIs that may not find a result — think `userRepository.findById(id)` returning `Optional<User>`. The caller then chains `.orElseThrow()` to throw a domain exception, or `.orElse(defaultValue)` to supply a fallback.
>
> Where `Optional` should *not* be used: as a **field type** in entities or DTOs — `Optional` is not `Serializable`, so it breaks Java serialisation, Jackson, JPA, and similar frameworks silently. Not as a **method parameter** — if a parameter might be absent, use overloading or document it as `@Nullable`. Not wrapping **collections** — `Optional<List<T>>` is always wrong; return an empty list instead, because a list already expresses zero-or-more.

*Listing the three anti-patterns (fields, params, collections) in one breath signals senior-level awareness — most candidates only know the "return type" rule.*

**Gotcha follow-up they'll ask:** *"What happens if you call `Optional.of(null)`?"*

> It throws `NullPointerException` immediately at construction time. If the value might be null, use `Optional.ofNullable(value)` — that returns `Optional.empty()` instead of throwing.

---

#### Q15 — Concept Check

**"Walk me through the Optional API — factory methods, extraction, and transformation."**

**One-line answer:** Optional has three creation paths (`of`, `ofNullable`, `empty`), five extraction methods ordered by safety, two conditional-execution methods, and four transformation methods (`map`, `flatMap`, `filter`, `or`).

**Full answer to give in an interview:**

> Starting with creation: `Optional.of(value)` expects a non-null value and throws `NullPointerException` immediately if you pass null. `Optional.ofNullable(value)` is the null-safe version — it returns `Optional.empty()` for null and a non-empty Optional otherwise. `Optional.empty()` returns the singleton empty instance.
>
> For extraction, the methods range from dangerous to safe. `get()` returns the value or throws `NoSuchElementException` — I treat it as deprecated in practice and always use `orElseThrow()` instead, which is semantically identical but shows intent. `orElse(x)` returns the value if present, otherwise returns `x` — and `x` is *always evaluated*, even on a cache hit. `orElseGet(supplier)` is lazy: the supplier runs only when the Optional is empty. `orElseThrow(exceptionSupplier)` throws a custom exception on empty — the standard pattern in service layers.
>
> For transformation: `map(f)` applies a function to the value if present and returns an `Optional<R>`. If the function returns null, the result is `Optional.empty()` — not an NPE. `flatMap(f)` is for when the function itself returns an `Optional<R>` — using `map` in that case would give `Optional<Optional<R>>`, which `flatMap` collapses. `filter(predicate)` returns the same Optional if the predicate matches, otherwise empty. Java 9 added `or(supplier)`, which returns the same Optional if present, otherwise calls the supplier to get a fallback Optional — useful for chaining lookup strategies.
>
> Java 9 also added `ifPresentOrElse(consumer, runnable)` to handle both the present and absent cases in one call, and `stream()` to treat Optional as a `Stream<T>` of zero or one element — handy when you want to `flatMap` a stream of Optionals.

*If the interviewer asks about `flatMap` in more detail, give the safe-navigation example: `findUser(id).flatMap(user -> findAddress(user.id()))` — both methods return Optional, so `flatMap` avoids wrapping.*

**Gotcha follow-up they'll ask:** *"What does `Optional.map(f)` return if the mapping function returns null?"*

> It returns `Optional.empty()`. The implementation explicitly checks the mapper's return value for null and converts it to empty rather than wrapping a null in a non-empty Optional. This means `map` is safe to use even with functions that might return null — the result is always a valid Optional.

---

#### Q16 — Tradeoff Question

**"What is the difference between `orElse()` and `orElseGet()`? Why does it matter in production?"**

**One-line answer:** `orElse(x)` always evaluates `x` eagerly; `orElseGet(supplier)` evaluates the supplier lazily — only when the Optional is empty — so use `orElseGet` whenever the fallback involves a method call.

**Full answer to give in an interview:**

> This is one of the most common Optional interview traps, and it catches experienced developers too. `orElse(value)` is a regular method call — Java evaluates all arguments before invoking the method, so `value` is computed regardless of whether the Optional is present. `orElseGet(supplier)` takes a lambda; the lambda body is only executed when the Optional is empty.
>
> The difference is invisible for constants: `optional.orElse("default")` or `optional.orElse(null)` — those are literals with zero computation cost. But `optional.orElse(loadFromDatabase())` calls `loadFromDatabase()` on *every invocation*, even when the Optional has a value. In a cache-aside pattern — where the happy path is a cache hit — this means you're paying full database latency on every request, completely defeating the purpose of the cache.
>
> The rule I follow: if the fallback is a literal, a constant, or a no-arg static factory that returns a cached object (like `Collections.emptyList()`), `orElse` is fine. If the fallback involves any method call — especially one with IO, object allocation, or side effects — use `orElseGet` and wrap it in a lambda. The cost of the lambda allocation is negligible compared to a single database round-trip.

*Demonstrate the output difference if asked: with `Optional.of("cached-value")`, calling `orElse(expensiveMethod())` prints the expensive call's side effects; `orElseGet(() -> expensiveMethod())` does not.*

**Gotcha follow-up they'll ask:** *"Is `optional.orElse(new ArrayList<>())` a problem?"*

> Yes, every call constructs a new `ArrayList` on the heap, even when the Optional is present. On a hot path it generates unnecessary GC pressure. Use `orElseGet(ArrayList::new)` or, better, return `Collections.emptyList()` directly (which is a cached singleton) if the list is not going to be mutated.

---

> **Common Mistake — Using `Optional` as a field in a JPA entity:** Annotating an entity field as `Optional<String> phone` breaks Hibernate serialisation silently — the field may not be persisted correctly and Jackson will serialise it as `{"phone": {"present": true}}` rather than the raw value. The consequence is corrupted data in the database that only surfaces at runtime under specific code paths. Use a nullable field and document it, or use `@Nullable` from a JSR-305 library.

**Quick Revision (one line):** Optional is for return types only; prefer `orElseGet` over `orElse` for any method-call fallback; use `flatMap` when the mapping function itself returns an Optional; never use Optional as a field, parameter, or collection wrapper.

---

## Topic 6: CompletableFuture

**Difficulty:** Hard | **Frequency:** Very High | **Companies:** Amazon, Google, Netflix, Goldman Sachs, Stripe

---

### The Idea

Imagine you're ordering food from three different restaurants at once. With old-style Java (`Future`), you'd have to wait at the door of the first restaurant until your order arrived, then walk to the second, wait again, and so on — even though the kitchens are all cooking in parallel. `CompletableFuture` is like sending a delivery driver to all three simultaneously, with instructions to call you when everything arrives and to use a backup restaurant if any one fails.

`CompletableFuture` is Java's answer to non-blocking, callback-driven asynchronous programming. Introduced in Java 8, it lets you describe a *pipeline* — fetch data, transform it, combine it with other results, handle errors — without ever blocking a thread to wait. The thread is freed to do other work while the async operations run.

The name "Completable" signals two things: it can be completed programmatically (you can manually inject a result or exception), and it is a `Future` you can chain transformations onto. In backend systems this matters enormously — blocking a thread per request kills throughput under load; async pipelines let you serve many more requests with the same thread pool.

---

### How It Works

**Creating a future:**
```
supplyAsync(supplier)           → runs supplier on ForkJoinPool, returns CompletableFuture<T>
supplyAsync(supplier, executor) → use your own thread pool (preferred in production)
completedFuture(value)          → already-done future, useful for testing
```

**Transforming results (pipeline building):**
```
future.thenApply(fn)            → transform T → U (like Stream.map); runs on same thread
future.thenApplyAsync(fn)       → transform on a different thread
future.thenAccept(consumer)     → consume result, return CompletableFuture<Void>
future.thenRun(runnable)        → run after completion, ignores result
```

**Chaining dependent futures (flatMap equivalent):**
```
future.thenCompose(fn)          → fn returns CompletableFuture<U>; flattens to CompletableFuture<U>
future.thenApply(fn)            → if fn returns CompletableFuture<U>, you get CompletableFuture<CompletableFuture<U>> ← BAD
```

**Combining independent futures:**
```
allOf(f1, f2, f3)               → waits for ALL; returns CompletableFuture<Void>
anyOf(f1, f2, f3)               → completes when FIRST finishes; returns CompletableFuture<Object>
thenCombine(other, BiFunction)  → both run concurrently, combine their two results
```

**Error handling:**
```
exceptionally(fn)               → if exception: transform ex → fallback value; skip if success
handle(BiFunction<T,ex,U>)      → always runs; gets (result, exception), exactly one is null
whenComplete(BiConsumer)        → side-effect only (logging); propagates original result/exception
```

**The single most interview-critical gotcha — `allOf` returns `Void`, not the results:**

```java
CompletableFuture<User> userFuture    = userService.getAsync(userId);
CompletableFuture<List<Order>> ordersFuture = orderService.getByUserAsync(userId);
CompletableFuture<Account> accountFuture  = accountService.getAsync(userId);

// allOf waits for all three to complete
CompletableFuture<Void> all = CompletableFuture.allOf(userFuture, ordersFuture, accountFuture);

// WRONG: all.thenApply(v -> v.getUser()) — there is no getUser() on Void
// CORRECT: hold references to individual futures, then join() after allOf
all.thenRun(() -> {
    User user         = userFuture.join();    // join() safe here — already completed
    List<Order> orders = ordersFuture.join();
    Account account   = accountFuture.join();
    buildDashboard(user, orders, account);
}).get();
```

**thenCompose vs thenApply — the flatMap analogy:**

| Operation | When `fn` returns plain `U` | When `fn` returns `CompletableFuture<U>` |
|---|---|---|
| `thenApply(fn)` | `CompletableFuture<U>` ✓ | `CompletableFuture<CompletableFuture<U>>` ✗ |
| `thenCompose(fn)` | Not applicable | `CompletableFuture<U>` ✓ (flattened) |

**CompletableFuture vs Future:**

| Feature | `Future` | `CompletableFuture` |
|---|---|---|
| Get result | `get()` — blocks | `thenApply()` — non-blocking callback |
| Combine futures | Manual / impossible | `allOf`, `anyOf`, `thenCombine` |
| Error handling | `try/catch` around `get()` | `exceptionally`, `handle` |
| Manual completion | No | `complete(value)`, `completeExceptionally(ex)` |
| Cancel | `cancel(true)` | Same, but downstream stages still run |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is CompletableFuture and why was it introduced?"**

**One-line answer:** `CompletableFuture` is a non-blocking, composable alternative to `Future` that lets you build async pipelines with callbacks instead of blocking `get()` calls.

**Full answer to give in an interview:**
> "`Future` — introduced in Java 5 — lets you submit work to a thread pool and retrieve the result later. But 'later' still means you must call `get()` which blocks your current thread until the result is ready. If I have ten parallel calls to make, I need ten blocked threads sitting there waiting — that doesn't scale.
>
> `CompletableFuture`, added in Java 8, solves this with a callback model. I describe what to do *when* the result arrives: `supplyAsync(() -> fetchUser(id)).thenApply(u -> enrich(u)).thenAccept(u -> cache(u))`. The calling thread never blocks — it moves on to other work. The pipeline executes on threads from `ForkJoinPool.commonPool()`, or from an `Executor` I provide.
>
> It also supports combining multiple futures: `allOf` to wait for all, `anyOf` for the first winner, `thenCombine` to merge two independent results. And it has built-in error handling via `exceptionally()` and `handle()` — no try/catch around `get()`.
>
> In Spring Boot, this is why `@Async` returns `CompletableFuture<T>` in modern code instead of raw `Future<T>`."

*Lead with the blocking-vs-callback contrast. Mention ForkJoinPool thread pool to signal you understand the threading model.*

**Gotcha follow-up they'll ask:** *"If you use `supplyAsync` without an executor, what thread pool does it use — and what's the problem with that?"*
> The default is `ForkJoinPool.commonPool()`. The problem: it's shared across the entire JVM — including parallel streams. Under heavy load, your async tasks and parallel stream operations compete for the same threads. In production backends, always pass a dedicated `ExecutorService` to `supplyAsync` so you have independent thread pool sizing and monitoring.

---

#### Q2 — Concept Check

**"What is the difference between `thenApply` and `thenCompose`?"**

**One-line answer:** `thenApply` transforms the result to a plain value; `thenCompose` is for when your transformation itself returns a `CompletableFuture` — it flattens the nesting, exactly like `flatMap` on streams.

**Full answer to give in an interview:**
> "Think of the Stream analogy: `map` transforms `T → U`, `flatMap` transforms `T → Stream<U>` and flattens. Same idea here.
>
> If I have `CompletableFuture<User>` and I call `thenApply(u -> u.getName())`, I get `CompletableFuture<String>` — the transformation is synchronous, just a function.
>
> But if my next step is itself async — say, fetching orders for that user from a remote service — my function would return `CompletableFuture<List<Order>>`. Using `thenApply` would give me `CompletableFuture<CompletableFuture<List<Order>>>` — a nested future I'd have to manually unwrap. `thenCompose` flattens that to `CompletableFuture<List<Order>>` directly.
>
> Rule of thumb: if your lambda returns a `CompletableFuture`, use `thenCompose`. If it returns a plain value, use `thenApply`."

*The `flatMap` analogy lands well with interviewers — it connects two concepts they already know.*

**Gotcha follow-up they'll ask:** *"When would you use `thenCombine` instead of `thenCompose`?"*
> `thenCompose` is for *sequential* chains — the second future depends on the result of the first. `thenCombine` is for *independent* futures that can run concurrently — you fire both and combine their results with a `BiFunction` when both complete. Example: fetch user profile and fetch account balance simultaneously, then combine into a dashboard object.

---

#### Q3 — Concept Check

**"How do you handle exceptions in a CompletableFuture pipeline?"**

**One-line answer:** Use `exceptionally` for a fallback value when there's an error, `handle` when you always want to run recovery logic regardless of success or failure.

**Full answer to give in an interview:**
> "There are three main tools. `exceptionally(fn)` is like a catch block — it only runs if an exception occurred and lets me return a fallback value. The normal pipeline stages are skipped on exception, and `exceptionally` recovers.
>
> `handle(BiFunction<T, Throwable, U>)` is like a finally block — it always runs. I receive either the successful result or the exception (exactly one will be null). I return a new value of type `U`, so I can transform the result in both the happy path and the error path.
>
> `whenComplete(BiConsumer<T, Throwable>)` is purely for side effects — logging, metrics. It doesn't change the result: it passes the original result or exception downstream unchanged.
>
> One critical gotcha: exceptions in `CompletableFuture` are wrapped in `CompletionException` when you call `join()` or `get()`. So if I call `join()` and catch `RuntimeException`, I need to inspect the cause, not the outer exception."

*Name all three, explain when you'd pick each. The CompletionException wrapping detail signals deep knowledge.*

**Gotcha follow-up they'll ask:** *"If future A fails and you call `allOf(A, B, C)`, what happens to B and C?"*
> `allOf` itself completes exceptionally immediately when any constituent future fails. But B and C continue running — they are not cancelled. If I need to cancel them, I must hold references and call `cancel(true)` on each manually.

---

#### Q4 — Design Scenario

**"Design a service that calls three downstream APIs in parallel and assembles the results, with a timeout and fallback."**

**One-line answer:** Use `supplyAsync` for each call with a dedicated executor, `allOf` to wait for all, `orTimeout` for the deadline, and `exceptionally` per future for individual fallbacks.

**Full answer to give in an interview:**
> "I'd structure this in three layers. First, I launch all three async calls simultaneously using `supplyAsync` with a bounded `ExecutorService` — not `ForkJoinPool.commonPool()` — so I control thread count and prevent starvation.
>
> Second, I attach `exceptionally` on each individual future to return a safe fallback (empty list, default object) if that specific call fails. This way one bad service doesn't blow up the whole response.
>
> Third, I call `allOf` on the three futures and chain `.orTimeout(500, TimeUnit.MILLISECONDS)` so the whole assembly has a hard deadline. After `allOf` resolves I call `join()` on each individual future — since they're already completed at that point, `join()` is instant and won't block.
>
> I would not use `anyOf` here because I need all three results. `anyOf` would be appropriate if I wanted the fastest of three redundant cache reads."

*Mentioning `orTimeout` (Java 9+) and per-future fallbacks over a single global `exceptionally` shows production thinking.*

**Gotcha follow-up they'll ask:** *"Why not just use `join()` on each future sequentially instead of `allOf`?"*
> Because sequential `join()` calls serialize the waiting. If all three calls take 300ms, sequential joins take 900ms total. `allOf` waits for the slowest of the three — in this case still 300ms. The parallelism happens in the `supplyAsync` launch; `allOf` is just the synchronization point.

---

> **Common Mistake — Calling `join()` before `allOf` completes:**
> Calling `userFuture.join()` before the `allOf` future resolves defeats the purpose — it blocks the calling thread waiting for that one future while the others are still running. Always chain logic off `allOf.thenRun(...)` or call `join()` only inside the callback after `allOf` has completed.

**Quick Revision (one line):** `CompletableFuture` replaces blocking `Future.get()` with callback chains; `thenCompose` for sequential async, `allOf` for parallel — but collect results via individual `.join()` inside the callback, not from `allOf` itself.

---

## Topic 7: Java 9–17 Key Additions

**Difficulty:** Medium | **Frequency:** High | **Companies:** Google, Amazon, Microsoft, ThoughtWorks, Atlassian

---

### The Idea

Java releases used to be massive multi-year events. Since Java 9 (2017), Oracle shifted to a six-month release cadence, shipping smaller, targeted features continuously. This is good for interviewers: instead of one big thing to learn, each version adds a focused, understandable improvement you can describe precisely.

The five features that appear most in interviews — `var`, Records, Sealed Classes, Text Blocks, and Pattern Matching for `instanceof` — all share a common theme: *reducing boilerplate while improving readability and expressiveness*. They're not replacing core Java semantics; they're cleaning up the surface syntax. Think of them as Java finally borrowing the ergonomic improvements that Kotlin and Scala users had enjoyed for years.

Each feature has a clear "before and after" story. Interviewers love these because a candidate who can articulate the *problem being solved* — not just the syntax — shows they understand the language's evolution rather than just memorizing keywords.

---

### How It Works

**`var` — Local Variable Type Inference (Java 10)**
```
// Before
ArrayList<Map<String, List<Integer>>> data = new ArrayList<>();

// After
var data = new ArrayList<Map<String, List<Integer>>>();  // type inferred from RHS

Rules:
  ✓ Local variables with initializer only
  ✗ Fields, method parameters, return types
  ✗ Null initializer (compiler cannot infer type)
  ✗ Array initializers: var arr = {1,2,3} is illegal
  
Still statically typed — type is fixed at compile time, not dynamic
```

**Records — Immutable Data Carriers (Java 16)**
```
// Before (classic POJO)
class Point {
  private final int x, y;
  public Point(int x, int y) { this.x = x; this.y = y; }
  public int x() { return x; }
  public int y() { return y; }
  // equals, hashCode, toString ... 30+ lines
}

// After
record Point(int x, int y) {}   // everything auto-generated

Compiler generates:
  - Canonical constructor
  - Accessor methods x(), y()  (NOT getX() — note the difference)
  - equals(), hashCode(), toString()
  
Cannot extend another class (implicitly extends Record)
Components are final — immutable by design
Can have compact constructors for validation
```

**Sealed Classes — Controlled Hierarchies (Java 17)**
```
sealed interface Shape permits Circle, Rectangle, Triangle {}

final class Circle    implements Shape { ... }
final class Rectangle implements Shape { ... }
final class Triangle  implements Shape { ... }
// No other class can implement Shape — compiler enforces this

Subclass must be one of: final | sealed | non-sealed
Enables exhaustive switch — compiler can verify all cases covered
```

**Text Blocks (Java 15)**
```
// Before — escape hell
String json = "{\n  \"name\": \"Alice\",\n  \"age\": 30\n}";

// After
String json = """
        {
          "name": "Alice",
          "age": 30
        }
        """;
// Indentation is stripped to the leftmost non-whitespace column
// Closing """ position controls indent stripping
```

**Pattern Matching for `instanceof` (Java 16) — the single most interview-critical example:**

```java
// Before Java 16 — check then cast (redundant)
if (obj instanceof String) {
    String s = (String) obj;   // cast we already know is safe
    System.out.println(s.toUpperCase());
}

// Java 16+ — check and bind in one step
if (obj instanceof String s) {
    System.out.println(s.toUpperCase());  // s is String, scoped to true-branch
}

// Combine with && guard
if (obj instanceof String s && s.length() > 5) {
    System.out.println("Long string: " + s);
}
```

**Feature comparison table:**

| Feature | Java Version | Problem Solved |
|---|---|---|
| `var` | 10 | Verbose type declarations on local variables |
| Text Blocks | 15 (final) | Escape sequences in embedded SQL/JSON/HTML strings |
| Records | 16 (final) | Boilerplate POJO/DTO code |
| Pattern Matching `instanceof` | 16 (final) | Redundant cast after type check |
| Sealed Classes | 17 (final) | Unrestricted open inheritance hierarchies |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is `var` and is Java now dynamically typed?"**

**One-line answer:** `var` is local variable type inference — the compiler infers the type from the right-hand side at compile time; the type is still static and fixed, just not written by the programmer.

**Full answer to give in an interview:**
> "`var` was introduced in Java 10. It tells the compiler: 'figure out the type from the right-hand side so I don't have to write it.' So `var list = new ArrayList<String>()` — the compiler knows `list` is `ArrayList<String>` and enforces that everywhere.
>
> This is not dynamic typing. Java remains statically typed. The variable's type is fully resolved at compile time. There is no runtime dispatch based on assigned value. If I write `var x = 42` and then try to assign a `String` to `x` later, the compiler rejects it.
>
> The restrictions: only local variables with an initializer. Not fields, not method parameters, not return types. You cannot write `var x = null` because there's no type to infer. You also cannot use `var` in a lambda parameter in most contexts — with the notable exception of annotating lambda parameters in Java 11 where `var` allows annotation syntax like `(@NonNull var s) -> s.length()`.
>
> When to use it: when the type is obvious from the right-hand side (constructor call, literal, method name that makes it clear). Avoid it when the type is non-obvious — it hurts readability without saving much."

*The 'statically typed at compile time' clarification is the key point interviewers test. Hit it explicitly.*

**Gotcha follow-up they'll ask:** *"Can you use `var` for a lambda parameter?"*
> Only in Java 11+ and only to attach annotations: `(@NotNull var x) -> x.toUpperCase()`. In Java 10, `var` in lambdas was not allowed. In practice this is rarely used. You cannot infer the lambda parameter type without `var` in normal lambdas anyway.

---

#### Q2 — Concept Check

**"What are Records in Java 16 and when would you use them over a regular class?"**

**One-line answer:** Records are immutable data carrier classes that auto-generate the constructor, accessors, `equals`, `hashCode`, and `toString` — ideal for DTOs, value objects, and event payloads.

**Full answer to give in an interview:**
> "Before records, creating a proper immutable data class in Java meant writing: constructor, private final fields, accessor methods, `equals()`, `hashCode()`, and `toString()` — easily 40–50 lines for a simple three-field object. Lombok helped, but it was a build-time annotation processor.
>
> Records collapse that to one line: `record Point(int x, int y) {}`. The compiler generates everything. The accessor methods are `x()` and `y()`, not `getX()` and `getY()` — important detail interviewers check. The constructor validates its arguments automatically (you can add a compact constructor for custom validation).
>
> Records are implicitly final — no subclassing. They implicitly extend `java.lang.Record`. Their components are final — mutation after construction is not allowed. This makes them safe to share across threads without synchronization.
>
> I use records for: API response DTOs, database query result projections, event objects in messaging, value objects in domain-driven design. I wouldn't use them where I need mutable state, inheritance, or JPA entity mapping (JPA requires no-arg constructors and mutable fields)."

*The accessor naming (`x()` not `getX()`), JPA incompatibility, and immutability are the three gotcha points to hit.*

**Gotcha follow-up they'll ask:** *"Can a Record implement an interface?"*
> Yes. Records can implement interfaces — they just can't extend classes (other than `Record`). This is a common pattern: define a `Printable` or `Serializable` interface and have records implement it.

---

#### Q3 — Concept Check

**"What are Sealed Classes in Java 17 and what problem do they solve?"**

**One-line answer:** Sealed classes restrict which classes can extend or implement them, giving the compiler a closed set of subtypes — enabling exhaustive, verified switch expressions and modeling closed domain hierarchies.

**Full answer to give in an interview:**
> "By default in Java, any class or interface can be extended by anyone. This open-world assumption is great for frameworks but bad when you want to model a closed domain. For example, a `PaymentMethod` in a billing system should only ever be `CreditCard`, `BankTransfer`, or `Wallet` — not an arbitrary subclass from some random package.
>
> Sealed classes enforce this with a `permits` clause: `sealed interface PaymentMethod permits CreditCard, BankTransfer, Wallet {}`. The compiler refuses to compile any other class that implements `PaymentMethod`.
>
> The payoff is exhaustive pattern matching. When I write a `switch` over a `PaymentMethod`, the compiler can verify I've handled all three permitted types and warn me if I add a fourth type later and forget to update the switch. Before Java 17, the compiler had no way to know whether the switch was exhaustive.
>
> Each permitted subclass must be declared as `final` (no further extension), `sealed` (further restricts its own subtypes), or `non-sealed` (reopens the hierarchy — essentially opts out). All permitted classes must be in the same package or module as the sealed class."

*The exhaustive switch / compiler verification angle is why sealed classes matter — connect it to pattern matching in switches.*

**Gotcha follow-up they'll ask:** *"How do Sealed Classes interact with Records?"*
> They compose naturally. A `sealed interface` with `record` implementations is idiomatic Java 17: you get the closed hierarchy from sealing and the concise syntax from records. `record CreditCard(String cardNumber, String cvv) implements PaymentMethod {}` — both features work together.

---

#### Q4 — Concept Check

**"What is pattern matching for `instanceof` and how does it differ from the old approach?"**

**One-line answer:** It eliminates the redundant explicit cast after an `instanceof` check by binding a typed variable in the same expression — less code, and the scope of the variable is narrowed to exactly where the type is guaranteed.

**Full answer to give in an interview:**
> "The classic Java idiom was: `if (obj instanceof String) { String s = (String) obj; ... }`. The cast on the second line is technically redundant — we just checked the type on the first line. It's noise the programmer must write and the reader must parse.
>
> Pattern matching for `instanceof`, finalized in Java 16, collapses this: `if (obj instanceof String s) { ... }`. The variable `s` is of type `String`, scoped to the true branch of the `if`. No cast needed. If the condition is false, `s` is out of scope — the compiler prevents accidental use.
>
> You can combine the type check with a guard using `&&`: `if (obj instanceof String s && s.length() > 5)`. The `&&` short-circuits, so `s` is always valid when `s.length()` is evaluated.
>
> This is a stepping stone toward full switch pattern matching (Java 21+), where you can switch over an object and match against multiple types with guards. In Java 17, the `instanceof` form is already final and production-ready. It also works well with sealed classes: when you switch over a sealed type, the compiler knows all possible patterns."

*Mentioning the scope narrowing and the Java 21 switch pattern matching roadmap signals awareness of the feature trajectory.*

**Gotcha follow-up they'll ask:** *"What happens if the object is null — does the pattern variable bind?"*
> No. `null instanceof String s` evaluates to `false` — no `NullPointerException`, and `s` is not bound. This is the same behavior as the old `instanceof` — it has always returned `false` for null. The new pattern matching preserves that behavior.

---

> **Common Mistake — Using `var` where the type is non-obvious:**
> Writing `var result = userService.findByEmail(email)` hides the return type from the reader. The IDE shows it on hover, but code review tools, diff viewers, and junior readers all lose the type context. Use `var` only when the type is self-evident from the right-hand side — constructor calls, literals, and clearly named factory methods.

**Quick Revision (one line):** Java 9–17 is all about ergonomics: `var` cuts declaration noise, Records cut POJO boilerplate, Sealed Classes close open hierarchies for exhaustive matching, Text Blocks end escape-sequence hell, and pattern matching `instanceof` removes redundant casts — all static, all compile-time safe.

---

## Topic 8: Java 8+ Quick Reference

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** All — appears in almost every senior Java interview

---

### The Idea

This topic is a synthesis layer. You know the individual features — lambdas, streams, Optional, CompletableFuture, records. What trips candidates up in interviews is the *decision layer*: when do you pick one tool over another? Interviewers love "compare X vs Y" and "what would you never do with Z" because those questions separate people who read the docs from people who've shipped production Java.

Think of this as your mental decision tree. When you see a collection-processing task, you should instantly know whether to reach for a stream or a loop. When you design an API return type, you should know whether `Optional` belongs there. When you write async code, you should know whether `CompletableFuture` or a plain thread is right. These aren't academic distinctions — they're the judgment calls that define a senior Java engineer.

---

### How It Works

**Lambda vs Method Reference — decision rule:**
```
Use method reference when: the lambda body is a single method call that forwards all arguments exactly

  list.forEach(s -> System.out.println(s))    → list.forEach(System.out::println)       ✓
  list.stream().map(s -> s.toUpperCase())     → list.stream().map(String::toUpperCase)  ✓

  list.stream().map(s -> s.trim().toUpperCase())  → stay with lambda (two operations)   ✗
  list.stream().filter(s -> s.length() > 5)       → stay with lambda (not a method ref) ✗

Method reference types:
  Static:   ClassName::staticMethod       (Integer::parseInt)
  Instance: instance::method              (System.out::println)
  Unbound:  ClassName::instanceMethod     (String::toUpperCase — applied to each element)
  Constructor: ClassName::new             (ArrayList::new)
```

**Stream vs Loop — decision rules:**
```
Prefer STREAM when:
  - Transforming / filtering / collecting a pipeline
  - Readability matters more than micro-performance
  - Parallel processing is needed (.parallelStream())
  - You want lazy evaluation (infinite streams, short-circuit with findFirst/anyMatch)

Prefer LOOP when:
  - You need early exit with complex state changes (break + mutation)
  - Performance is critical and profiling shows stream overhead
  - Checked exceptions must be thrown (streams don't propagate checked exceptions cleanly)
  - You're iterating and mutating external mutable state (confusing inside stream lambdas)
  - Debugging is hard: stack traces through stream pipelines are noisy
```

**Optional dos and don'ts:**
```
DO:
  - Return Optional<T> from methods that legitimately have no result
  - Use orElse(default), orElseGet(supplier), orElseThrow() to extract value safely
  - Use map(), flatMap(), filter() to transform without null checks
  - Use Optional for repository return types (findById → Optional<User>)

DON'T:
  - Use Optional as a field type in a class (serialization issues, heap overhead)
  - Use Optional as a method parameter (caller can still pass Optional.empty() or null — not a null guard)
  - Call get() without isPresent() check (defeats the purpose — same as NPE risk)
  - Use Optional<List<T>> — return empty list instead, never null collections
  - Use Optional in collections: List<Optional<T>> is an anti-pattern
```

**CompletableFuture vs plain Future:**
```
Feature                    | Future        | CompletableFuture
---------------------------|---------------|------------------
Non-blocking callback      | No            | Yes (thenApply, thenAccept)
Combine multiple futures   | No            | Yes (allOf, anyOf, thenCombine)
Exception handling         | try/catch get()| exceptionally, handle
Manual completion          | No            | complete(), completeExceptionally()
Timeout                    | No (Java 8-)  | orTimeout() (Java 9+)
Cancel propagates          | Stops task    | Downstream stages still run

Rule: if you need callbacks, combination, or error recovery → CompletableFuture always.
Use plain Future only in legacy code or when submitting a single task and blocking for it immediately.
```

**Which Java 9–17 features matter most in interviews:**
```
Tier 1 — Asked constantly:
  Records        → "Replace this DTO class with a record"
  var            → "Is Java dynamically typed now?"
  Pattern matching instanceof → "Clean up this type dispatch code"

Tier 2 — Asked often in design questions:
  Sealed Classes → "How would you model a closed payment type hierarchy?"
  Text Blocks    → "How do you embed SQL/JSON in Java cleanly?"

Tier 3 — Good to mention, rarely drilled:
  Switch Expressions (Java 14) → returns a value, no fall-through
  Stream.toList() (Java 16)    → unmodifiable list without Collectors.toList()
  Map.copyOf(), List.copyOf() (Java 10) → defensive immutable copies
```

**The one Java gotcha table every senior candidate must know:**

| Gotcha | Wrong | Right |
|---|---|---|
| `allOf` result | `allOf.thenApply(v -> getResult())` | Collect individual futures, `join()` after `allOf` |
| `Optional` parameter | `void save(Optional<String> name)` | Overload the method instead |
| `thenApply` + async fn | `future.thenApply(id -> fetchAsync(id))` | `future.thenCompose(id -> fetchAsync(id))` |
| Stream with checked ex | `stream.map(f -> checkedMethod(f))` | Wrap in try/catch inside lambda or use utility |
| Record accessor name | `point.getX()` | `point.x()` — records don't use `get` prefix |
| Sealed class subtype | `non-sealed` reopens hierarchy | Use `final` unless you explicitly want to reopen |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Tradeoff Question

**"When would you use a stream and when would you use a for-loop?"**

**One-line answer:** Use streams for declarative pipelines — transform, filter, collect — where readability wins; use loops when you need early exit with mutable state, must throw checked exceptions, or profiling shows stream overhead.

**Full answer to give in an interview:**
> "The real question is readability vs. control. Streams shine when I'm describing *what* to do: `employees.stream().filter(e -> e.isActive()).map(Employee::getSalary).reduce(0, Integer::sum)`. The intent is clear at a glance.
>
> Loops are better when I need control flow that doesn't map cleanly to stream operators. If I need to `break` with complex state — say, I'm searching and also accumulating a side-effect result — a loop is clearer. Streams don't support `break` at all; `findFirst` or `anyMatch` provide short-circuiting but only for simple termination.
>
> Checked exceptions are the other big pain point. If `readFile(path)` throws `IOException`, I can't write `paths.stream().map(this::readFile)` without wrapping it in a try/catch inside the lambda — ugly. A loop handles it naturally.
>
> Performance: parallel streams are genuinely useful for CPU-bound work on large datasets. For small in-memory collections under a few thousand elements, streams and loops are effectively equivalent. I wouldn't optimize prematurely — profiler first."

*The checked exception pain point is a detail many candidates miss — it signals real experience.*

**Gotcha follow-up they'll ask:** *"Can you use `parallelStream()` safely on any collection?"*
> No. `parallelStream()` splits work using the ForkJoinPool. If the stream pipeline has side effects — writing to a shared list, for example — you'll get race conditions. It's only safe when each element's processing is independent and you're collecting to a thread-safe terminal (like `collect(Collectors.toList())`). Also, the overhead of splitting and joining means it's only faster than sequential for large datasets with CPU-heavy per-element work.

---

#### Q2 — Tradeoff Question

**"What are the rules you follow for `Optional` — when to use it and when not to?"**

**One-line answer:** Return `Optional<T>` from methods that may legitimately have no result; never use it as a field type, method parameter, or wrapper around collections.

**Full answer to give in an interview:**
> "The purpose of `Optional` is to make the absence of a value explicit at the API level — it's a contract that says 'this method might not find anything.' Repository methods like `findById(id)` are the canonical use case.
>
> The antipatterns: using `Optional` as a method parameter is pointless — the caller can still pass `Optional.empty()` or even null, so you haven't gained safety. Use method overloading instead. Using `Optional` as a field type causes serialization issues (Jackson can't map `Optional<String>` cleanly without configuration) and adds heap overhead for every instance.
>
> `Optional<List<T>>` is always wrong — if you have no items, return an empty list, not `Optional<List>`. The same applies to `Optional<String>` for empty-vs-absent — be explicit about whether empty string and absent are the same case.
>
> The other antipattern: calling `optional.get()` without checking `isPresent()`. You've just recreated the NPE risk. Always use `orElse(default)`, `orElseGet(supplier)`, or `orElseThrow(exception)`. Chain transformations with `map()` and `filter()` to stay in the `Optional` monad until you're forced to extract."

*The four specific antipatterns (field, parameter, collection wrapper, bare `get()`) give the answer structure and signal breadth of experience.*

**Gotcha follow-up they'll ask:** *"What's the difference between `orElse` and `orElseGet`?"*
> `orElse(value)` always evaluates the argument — even if the Optional has a value. `orElseGet(supplier)` evaluates the supplier lazily, only when the Optional is empty. If the default is expensive to compute (database call, object creation), always use `orElseGet`. Using `orElse` with a method call is a common performance bug.

---

#### Q3 — Tradeoff Question

**"Lambda vs method reference — how do you decide which to use?"**

**One-line answer:** Use a method reference when the lambda body is a single method call that passes all arguments directly; stay with a lambda when there's any transformation, composition, or conditional logic.

**Full answer to give in an interview:**
> "Method references are a readability win when they make the intent obvious. `list.stream().map(String::toUpperCase)` reads like English. The reader immediately knows we're transforming each string by uppercasing it, without wading through lambda syntax.
>
> But method references become a readability loss when they obscure intent. `stream.map(this::processAndValidate)` — what does `processAndValidate` do? I'd rather see `stream.map(item -> validate(transform(item)))` so the two steps are visible at the call site.
>
> The technical decision: if the lambda body is exactly `args -> SomeClass.method(args)` or `args -> obj.method(args)` with no modification, a method reference works. If I'm adding arguments, calling two methods, adding a conditional — stay with the lambda.
>
> One subtle gotcha: unbound instance method references like `String::toUpperCase` look like static references but aren't. The first argument becomes the receiver. `stream.map(String::toUpperCase)` is equivalent to `stream.map(s -> s.toUpperCase())`. Interviewers sometimes ask about this to test whether you understand the four method reference forms."

*The four method reference forms and the unbound instance method distinction are the knowledge signals interviewers probe for.*

**Gotcha follow-up they'll ask:** *"Can a method reference throw a checked exception?"*
> Yes, if the functional interface it targets declares the exception. But most built-in functional interfaces (`Function`, `Predicate`, `Consumer`) don't declare checked exceptions. You can't use a method reference that throws `IOException` with `Stream.map()` — you'd need a custom functional interface that declares the exception, or wrap the call in a try/catch. This is one of the rougher edges of Java streams.

---

#### Q4 — Design Scenario

**"If I gave you a legacy Java 8 codebase and said 'modernize it to Java 17,' what changes would you make and in what order?"**

**One-line answer:** Start with Records for DTOs (highest boilerplate reduction), then `var` for verbose declarations, then pattern matching to clean up instanceof casts, then text blocks for embedded strings, then sealed classes for closed hierarchies where exhaustive matching matters.

**Full answer to give in an interview:**
> "I'd prioritize by impact-to-risk ratio.
>
> First, Records. DTOs and value objects are the biggest boilerplate in most Java codebases. Converting a 50-line `UserDto` to `record UserDto(String name, String email, long id) {}` is low risk (immutability is a strict improvement for DTOs) and high impact. One caveat: skip JPA entities — records and JPA are incompatible due to JPA's no-arg constructor requirement.
>
> Second, `var` for obvious local declarations. I'd do this conservatively — only where the type is clear from the right-hand side. This is a purely cosmetic change with zero semantic impact.
>
> Third, pattern matching `instanceof`. Search for the two-line pattern `if (x instanceof Foo) { Foo f = (Foo) x; ... }` and collapse it. Again, zero semantic change — strictly cleaner.
>
> Fourth, text blocks for embedded SQL, JSON, HTML strings. Easy wins — find string concatenation with `\n` and `\"` sequences.
>
> Last, sealed classes — these require design thought. I'd apply them only to existing hierarchies that are already de-facto closed. Don't force it on genuinely open extension points.
>
> Throughout: I'd leave `CompletableFuture` and streams alone unless there are correctness bugs. Async refactoring carries real risk and needs load testing."

*The JPA–Records incompatibility and the risk-ordered migration plan show production thinking, not just syntax knowledge.*

**Gotcha follow-up they'll ask:** *"Records are immutable. How do you handle validation in a Record constructor?"*
> Use a compact constructor — a constructor with no parameter list that runs inside the canonical constructor. You can validate and throw there: `record Range(int min, int max) { Range { if (min > max) throw new IllegalArgumentException("min > max"); } }`. The compact constructor runs before the fields are assigned, giving you a validation hook.

---

> **Common Mistake — Treating Java 9–17 features as optional polish:**
> Not adopting Records for DTOs in a Java 17 codebase is a red flag in code review. The features aren't syntactic sugar to be ignored — they're the idiomatic way to write modern Java, and interviewers expect you to use them. A 40-line POJO with getters and Lombok annotations when you could have a 1-line record signals the candidate hasn't kept current.

**Quick Revision (one line):** The Java 8+ decision framework: method references for simple forwarding, streams for pipelines, Optional for nullable returns (never fields or params), CompletableFuture for anything async over `Future`, and Java 9–17 features (Records, `var`, sealed, text blocks, pattern matching) as the default idiom in any Java 17+ codebase.

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

---

*End of Chapter 4: Java 8+ Features*

