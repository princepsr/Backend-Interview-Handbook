# Volume 1: Core Java — Company Guide

## Which Companies Go Deep on Java

| Company | Java Depth (1-5) | What They Specifically Test | Key Chapters |
|---|---|---|---|
| Goldman Sachs | 5 | Concurrency, memory model, GC tuning | Ch6, Ch5 |
| Atlassian | 4 | JVM internals, Spring integration, thread safety | Ch5, Ch6 |
| Salesforce | 4 | Collections performance, OOP design, Java 8 | Ch3, Ch1, Ch4 |
| Amazon | 3 | Practical concurrency, DS via Collections | Ch6, Ch3 |
| Flipkart | 4 | Java 8 streams, collections, practical coding | Ch4, Ch3 |
| Swiggy / CRED / Zepto | 3 | Java 8+, exception handling, OOP design | Ch4, Ch1, Ch2 |
| Stripe | 4 | Thread safety, code quality, immutability | Ch6, Ch1 |
| Google | 2 | Algorithm over Java; language basics only | Ch3, Ch4 |
| Thoughtworks | 3 | SOLID, clean OOP, functional style | Ch1, Ch4 |

---

## Company-Specific Tips

### Amazon
- Amazon's Java rounds are rarely about JVM internals — they care about using Java correctly in system design contexts (thread pools, blocking queues, executor frameworks)
- Expect to write `BlockingQueue`-based producer-consumer or a thread-safe cache using `ConcurrentHashMap` + `ReentrantLock`
- `HashMap` internals are asked in the bar-raiser round — know treeification, load factor, and why `null` key is allowed

### Google
- Google prioritizes algorithm correctness and time complexity over Java language depth — do not over-invest in JVM or concurrency specifics
- Java 8 streams are used as a tool to solve collection manipulation problems, not as interview topics in themselves
- Focus on using `TreeMap`, `PriorityQueue`, `LinkedHashMap` correctly in algorithm problems — that is where Java knowledge matters at Google

### Goldman Sachs / FinTech
- Concurrency and the Java Memory Model are mandatory — expect whiteboard questions on `volatile`, `happens-before`, and `CAS` operations
- GC pauses are a real production concern in trading systems — know G1 GC tuning flags (`-XX:MaxGCPauseMillis`, region sizing) and what causes long pauses
- `ThreadLocal` misuse and memory leaks in thread pool environments come up because they are real issues in financial middleware

### Atlassian / Salesforce
- Both companies run large multi-tenant JVM applications — JVM tuning, heap sizing, and GC selection matter in interviews at senior level
- Expect design questions that require combining Spring (DI, AOP) with correct Java concurrency — e.g. singleton beans with shared mutable state
- Salesforce asks about `ClassLoader` isolation for plugin architectures; Atlassian asks about OSGi-like plugin loading patterns

### Stripe
- Stripe values immutability and correctness above performance — be ready to explain why you chose `final` fields, `CopyOnWriteArrayList`, or `Collections.unmodifiableMap`
- Thread safety questions are code-review style — "what is wrong with this class" rather than "explain the Java Memory Model"
- Clean exception handling matters: checked vs unchecked, not swallowing exceptions, using custom exception hierarchies

### Flipkart / Indian Product (Swiggy, Zepto, CRED)
- Java 8 streams and lambda usage are tested with practical output-prediction questions — know lazy evaluation and short-circuit behavior
- Collections performance tradeoffs come up in system design: which data structure to use for a leaderboard, frequency map, or deduplication
- Exception handling and `Optional` usage are assessed in live coding — they want pragmatic, readable code, not over-engineered patterns

---

## Questions That Separate SDE2 from SDE1

1. **"Why can two threads see stale values even when one thread has already written to a variable?"**
   SDE1 says "use synchronized." SDE2 explains the CPU cache, memory visibility, and why `volatile` solves this specific case without locking.

2. **"Design a thread-safe LRU cache without using `Collections.synchronizedMap`."**
   SDE1 wraps `LinkedHashMap` with `synchronized`. SDE2 uses `LinkedHashMap` with `ReentrantReadWriteLock`, explains read/write contention, then discusses `ConcurrentLinkedHashMap` or Guava Cache as production alternatives.

3. **"What happens during a Full GC and how do you reduce its frequency?"**
   SDE1 says "old generation fills up." SDE2 explains promotion failure, humongous objects in G1, survivor space tuning, and how to read `gc.log` to diagnose the root cause.

4. **"You have a `Callable` returning a result from a thread pool. How do you handle the case where it throws an exception?"**
   SDE1 wraps in try-catch. SDE2 explains `Future.get()` wrapping in `ExecutionException`, `CompletableFuture.exceptionally()`, and how to propagate errors correctly across async boundaries.

5. **"Why does `HashMap` allow one null key but `Hashtable` does not?"**
   SDE1 says "HashMap supports null." SDE2 explains `hashCode()` on null returns 0 by HashMap's own null-key handling, whereas `Hashtable.put` calls `key.hashCode()` directly, throwing `NullPointerException` — and why this design difference exists.
