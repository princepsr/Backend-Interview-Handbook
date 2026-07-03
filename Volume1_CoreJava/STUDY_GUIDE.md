# Volume 1: Core Java — Study Guide

## Priority Order (read in this sequence)

| Chapter | Why First | Time Budget |
|---|---|---|
| Ch6 Multithreading | Most frequently tested in senior rounds; separates SDE1 from SDE2 | 60 min |
| Ch3 Collections | Asked in every Java interview; HashMap internals are mandatory | 60 min |
| Ch4 Java 8+ | Stream, Optional, lambdas — practical coding questions guaranteed | 60 min |
| Ch1 OOP | Foundation; SOLID + design principles asked conceptually | 45 min |
| Ch5 JVM | GC, memory model, classloading — asked at mid-senior level | 45 min |
| Ch2 Strings/Wrappers/Exceptions | Shorter chapter; mostly tricky edge-case questions | 30 min |

Order: Ch6 → Ch3 → Ch4 → Ch1 → Ch5 → Ch2

---

## 1-Week Plan (1 hr/day)

**Day 1 — Ch6 Multithreading**
- Focus: `synchronized` vs `ReentrantLock` vs `volatile` — know when each is correct
- Focus: `ExecutorService`, `Future`, `CompletableFuture` chaining
- Focus: Deadlock conditions and how to prevent; `ThreadLocal` use cases

**Day 2 — Ch3 Collections**
- Focus: `HashMap` internals — hashing, collision, treeification at threshold 8
- Focus: `ConcurrentHashMap` vs `Collections.synchronizedMap` — when and why
- Focus: `LinkedHashMap` (LRU cache), `TreeMap` ordering, `PriorityQueue` heap ops

**Day 3 — Ch4 Java 8+**
- Focus: Stream pipeline — `map`, `flatMap`, `reduce`, `collect(Collectors.groupingBy)`
- Focus: `Optional` — correct usage, avoiding `get()` without check, `orElseGet` vs `orElse`
- Focus: Functional interfaces — `Predicate`, `Function`, `Supplier`, `Consumer`; method references

**Day 4 — Ch1 OOP**
- Focus: SOLID principles — one real-world violation example per principle
- Focus: Composition over inheritance — when to use each
- Focus: Abstract class vs interface post-Java 8; covariant return types; `equals`/`hashCode` contract

**Day 5 — Ch5 JVM**
- Focus: Heap regions — Young Gen (Eden + Survivor), Old Gen, Metaspace
- Focus: GC algorithms — G1 vs ZGC vs Serial; when each is used in production
- Focus: ClassLoader delegation model; `PermGen` removal in Java 8

**Day 6 — Ch2 Strings/Wrappers/Exceptions**
- Focus: String pool, `intern()`, `StringBuilder` vs `StringBuffer`
- Focus: Integer caching (-128 to 127); autoboxing pitfalls with `==`
- Focus: Checked vs unchecked; `try-with-resources`; exception chaining

**Day 7 — Vol 6 Ch23 Revision**
- Test yourself on: Q1, Q4, Q7, Q12, Q18 from Ch23
- Q1: HashMap thread-safety scenario
- Q4: Deadlock identification and fix
- Q7: Stream pipeline output prediction
- Q12: GC tuning flags meaning
- Q18: `CompletableFuture` exception handling

---

## 3-Day Crash (urgent interview)

**Day 1 — Ch6 + Ch3 (most tested)**
- Morning: `synchronized`, `volatile`, `ReentrantLock`, `CountDownLatch`, `Semaphore`
- Afternoon: `HashMap` internals, `ConcurrentHashMap`, `LinkedHashMap` for LRU

**Day 2 — Ch4 + Ch1**
- Morning: Stream pipelines, `Optional`, lambdas, method references
- Afternoon: SOLID, composition vs inheritance, `equals`/`hashCode`

**Day 3 — Ch5 + Vol 6 Ch23 Revision**
- Morning: GC types, heap regions, classloading
- Afternoon: Vol 6 Ch23 — Q1, Q4, Q7, Q12, Q18

---

## What Interviewers Test in Java Rounds

- They test whether you know *why* a feature exists, not just *what* it does — e.g. why `ConcurrentHashMap` outperforms `Hashtable`
- They give you broken concurrent code and ask you to find the race condition or deadlock
- They ask you to predict output of tricky autoboxing, string pool, or stream short-circuit scenarios
- They probe GC knowledge only at senior level — they want to know you've tuned JVM in production, not read a book
- They expect you to connect Java features to design decisions — "why use `Optional` here instead of null check" is a judgment question, not a trivia question

---

## Top 10 Java Questions Asked in Every Interview

1. How does `HashMap` work internally — hashing, collision handling, resizing?
2. What is the difference between `synchronized` and `ReentrantLock`?
3. Explain `volatile` — what it guarantees and what it does not?
4. What is the Java Memory Model and what is a happens-before relationship?
5. How does `ConcurrentHashMap` achieve thread safety without locking the entire map?
6. What is the difference between `Comparable` and `Comparator`?
7. Explain `CompletableFuture` — how do you chain async tasks and handle exceptions?
8. What is the difference between `abstract class` and `interface` in Java 8+?
9. How does garbage collection work — explain Young Gen, Old Gen, and G1 GC?
10. What is a deadlock? Write code that produces one and then fix it.

---

## Common Mistakes to Avoid

- Using `==` to compare `Integer` objects above 127 — cache boundary; result is `false` unexpectedly
- Mutating a collection inside a `forEach` lambda — throws `ConcurrentModificationException` at runtime
- Calling `stream()` on a list and assuming it is parallelized — sequential by default; need `parallelStream()` explicitly
- Catching `Exception` broadly and swallowing the stack trace — makes debugging impossible; loses root cause
- Assuming `volatile` is enough for compound operations like `i++` — not atomic; need `AtomicInteger` or synchronization
