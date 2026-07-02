# Volume 6: Interview Revision Pack
# Chapter 23: Core Java — Quick Revision

> Last-day cheat sheet. Dense bullets. No fluff. SDE2 target.

---

## Section 1: OOP — Top 10 Interview Questions

**Q1. Abstraction vs Encapsulation?**
- Abstraction = hiding *what* (interface/abstract class hides implementation details from caller); Encapsulation = hiding *how* (bundling data + methods, controlling access via modifiers).

**Q2. Types of Polymorphism?**
- Compile-time (static): method overloading, resolved by compiler via method signature.
- Runtime (dynamic): method overriding, resolved by JVM via vtable/virtual dispatch.

**Q3. Overloading vs Overriding?**
- Overloading: same class, same name, different parameter list; resolved at compile time.
- Overriding: subclass redefines parent method with same signature; resolved at runtime; needs `@Override`; return type can be covariant.

**Q4. Interface vs Abstract Class?**

| | Interface | Abstract Class |
|---|---|---|
| State | No instance fields (only `static final`) | Can have instance fields |
| Constructor | No | Yes |
| Multiple inheritance | Yes | No |
| Default methods | Yes (Java 8+) | Yes |
| Use when | Capability contract (Serializable, Runnable) | Shared base + partial impl |

**Q5. Composition vs Inheritance?**
- Inheritance = "is-a"; tight coupling, breaks encapsulation (fragile base class problem).
- Composition = "has-a"; prefer it; swap implementations at runtime, no coupling.

**Q6. Covariant Return Types?**
- Overriding method can return a subtype of the parent's return type (Java 5+).
- `Animal clone()` in parent → `Dog clone()` valid in `Dog` subclass.

**Q7. Marker Interfaces?**
- Empty interfaces (`Serializable`, `Cloneable`, `RandomAccess`) used as type tags.
- Modern alternative: annotations (`@FunctionalInterface`, custom annotations).

**Q8. How to make an Immutable class?**
1. `final` class (prevent subclassing).
2. All fields `private final`.
3. No setters.
4. Deep copy mutable fields in constructor and getters.
5. (Optional) `Collections.unmodifiableList` for collection fields.

**Q9. equals() / hashCode() contract?**
- If `a.equals(b)` then `a.hashCode() == b.hashCode()` — MUST hold.
- Reverse not required (hash collision OK).
- If you override `equals`, you MUST override `hashCode`.
- `equals` must be: reflexive, symmetric, transitive, consistent, null-safe.

**Q10. clone() gotchas?**
- `Object.clone()` does shallow copy; implement `Cloneable` (marker), override `clone()` as `public`.
- For deep copy: manually clone mutable fields, or use copy constructor / serialization.
- Prefer copy constructors over `clone()` in practice.

---

## Section 2: Strings & Wrappers — Top 10 Questions

**Q1. String Pool?**
- String literals stored in JVM's string pool (PermGen/Metaspace area); same literal reuses same object.
- `new String("hello")` always creates heap object, bypasses pool.

**Q2. intern()?**
- `str.intern()` returns canonical pool reference; useful to deduplicate runtime strings.
- Side effect: can bloat string pool if overused.

**Q3. String vs StringBuilder vs StringBuffer?**

| | String | StringBuilder | StringBuffer |
|---|---|---|---|
| Mutability | Immutable | Mutable | Mutable |
| Thread-safe | Yes (immutable) | No | Yes (synchronized) |
| Performance | Slow in loops | Fast | ~20-25% slower than SB |

**Q4. Why is String immutable?**
- Security (class loading, passwords, network params).
- String pool feasibility (shared refs safe only if immutable).
- Safe for use as HashMap keys (hashCode cached after first call).
- Thread safety inherently.

**Q5. Integer cache (-128 to 127)?**
- `Integer.valueOf(127) == Integer.valueOf(127)` → `true` (cached).
- `Integer.valueOf(128) == Integer.valueOf(128)` → `false` (new heap objects).
- Cache range configurable via `-XX:AutoBoxCacheMax=N` (upper bound only).

**Q6. Autoboxing pitfalls?**
- `Integer a = null; int b = a;` → NullPointerException (unboxing null).
- `==` on Integer outside cache range: false even for "equal" values.
- Autoboxing in tight loops creates GC pressure (use `int[]` / primitives).

**Q7. String.format vs concatenation performance?**
- `+` operator on literals: compiler optimizes to `StringBuilder` at compile time.
- `+` in loop: creates new `StringBuilder` each iteration — use explicit `StringBuilder.append()`.
- `String.format`: slowest (regex parsing of format string); use only for readability.
- Java 15+: `String` templates (preview); Java 21: stable string templates.

**Q8. Compact Strings (Java 9)?**
- Before: char[] (2 bytes/char) always. After: byte[] with encoding flag.
- Latin-1 strings use 1 byte/char → ~50% heap reduction for ASCII-heavy apps.
- Transparent; no API change.

**Q9. char vs String?**
- `char` is primitive, 16-bit UTF-16 code unit; cannot represent supplementary Unicode (code points > U+FFFF).
- Use `int` (code point) or `String` for full Unicode handling.
- `Character` wrapper has `isLetter()`, `isDigit()`, `toLowerCase()` utilities.

**Q10. String.equals() vs ==?**
- `==` compares object references (identity).
- `.equals()` compares character content.
- Always use `.equals()` for value comparison; use `Objects.equals(a, b)` for null safety.

---

## Section 3: Collections — Top 15 Questions

**Q1. HashMap internals?**
- Backed by `Node<K,V>[]` array (table). Default capacity 16, load factor 0.75.
- Hash: `(key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16)` — spreads high bits.
- Bucket index: `hash & (n-1)`.
- Treeification: bucket list → Red-Black Tree when bucket size >= 8 AND table size >= 64.
- Resize (rehash): at `size > capacity * loadFactor`; capacity doubles.

**Q2. ConcurrentHashMap vs synchronized HashMap?**
- `Collections.synchronizedMap(map)`: one lock on entire map; one thread at a time.
- `ConcurrentHashMap`: segment/bin-level locking (Java 8: CAS + `synchronized` on head node only); multiple threads read/write different buckets concurrently.
- `ConcurrentHashMap`: no null keys/values; `synchronizedMap` allows null.

**Q3. LinkedHashMap vs TreeMap?**
- `LinkedHashMap`: insertion-order (or access-order if `accessOrder=true`); O(1) get/put; perfect for LRU cache.
- `TreeMap`: sorted by natural order or `Comparator`; O(log n) get/put; implements `NavigableMap` (floorKey, ceilingKey).

**Q4. ArrayDeque vs LinkedList as Queue?**
- `ArrayDeque`: array-backed, resizes; faster in practice (cache-friendly), no node allocation overhead.
- `LinkedList`: node-per-element; slower; also implements `List` (extra overhead).
- Prefer `ArrayDeque` for stack/queue; use `LinkedList` only when you need `List` + `Deque`.

**Q5. Fail-fast vs Fail-safe iterators?**
- Fail-fast: iterates original collection; throws `ConcurrentModificationException` if `modCount` changes (HashMap, ArrayList).
- Fail-safe: iterates a copy/snapshot; no exception (ConcurrentHashMap, CopyOnWriteArrayList); may not see latest writes.

**Q6. Comparable vs Comparator?**
- `Comparable<T>`: `compareTo(T o)` in the class itself; natural ordering; one order only.
- `Comparator<T>`: external; multiple orderings; use with `sorted()`, `Collections.sort()`, `TreeMap`.
- Java 8: `Comparator.comparing(Person::getName).thenComparing(Person::getAge)`.

**Q7. PriorityQueue ordering?**
- Min-heap by default (natural order); head = smallest element.
- For max-heap: `new PriorityQueue<>(Comparator.reverseOrder())`.
- No guaranteed order during iteration; only `poll()` / `peek()` give sorted access.

**Q8. EnumMap?**
- Backed by array indexed by enum ordinal; O(1) operations; more efficient than HashMap for enum keys.
- No null keys; iteration order = enum declaration order.

**Q9. IdentityHashMap?**
- Uses `==` (reference equality) and `System.identityHashCode()` instead of `equals()`/`hashCode()`.
- Use case: object graph serialization, canonicalization, framework internals.

**Q10. WeakHashMap use case?**
- Keys held by weak references; GC can collect key if no strong reference exists → entry auto-removed.
- Use case: caches where keys are live objects (metadata, listeners).

**Q11. Collections.unmodifiableList vs List.of()?**
- `unmodifiableList`: wrapper around existing list; original can still be mutated by reference holder.
- `List.of()` (Java 9): truly immutable; no nulls; throws on any structural/element change.
- `List.copyOf()` (Java 10): immutable deep copy.

**Q12. Why does HashMap allow null key?**
- Null key always maps to bucket 0 (special-cased in `put`/`get`); valid design choice.
- `ConcurrentHashMap` disallows null to avoid ambiguity: `get()` returning null means "absent" vs "value is null" — no atomic way to distinguish without separate `containsKey()`.

**Q13. ArrayList vs LinkedList?**
- ArrayList: O(1) random access; O(n) insert/delete in middle; cache-friendly.
- LinkedList: O(n) random access; O(1) insert/delete at known node; high memory overhead (prev/next pointers).
- In practice: ArrayList almost always wins due to CPU cache effects.

**Q14. Set implementations?**
- `HashSet`: backed by HashMap; O(1); no order.
- `LinkedHashSet`: insertion order; slightly slower.
- `TreeSet`: sorted (NavigableSet); O(log n).
- `EnumSet`: bit-vector; extremely fast for enum values.
- `CopyOnWriteArraySet`: thread-safe, good for small, read-heavy sets.

**Q15. Initial capacity for HashMap?**
- Provide if expected size known: `new HashMap<>(expectedSize / 0.75 + 1)` to avoid rehashes.
- Each rehash is O(n); for large maps this matters at startup.

---

## Section 4: Java 8+ — Top 15 Questions

**Q1. Lambda vs Anonymous Class?**
- Lambda: no class file generated (invokedynamic); `this` = enclosing class; no state.
- Anonymous class: new `.class` file; `this` = anonymous class instance; can have state/fields.
- Lambda only works for functional interfaces (exactly one abstract method).

**Q2. Method Reference Types?**

| Type | Syntax | Example |
|---|---|---|
| Static | `Class::staticMethod` | `Integer::parseInt` |
| Instance (unbound) | `Class::instanceMethod` | `String::toUpperCase` |
| Instance (bound) | `instance::method` | `str::contains` |
| Constructor | `Class::new` | `ArrayList::new` |

**Q3. Stream lazy evaluation?**
- Intermediate ops (filter, map, sorted) are lazy — no work until terminal op.
- Short-circuit terminals (findFirst, anyMatch) stop processing early.
- Entire pipeline fused into one pass over data.

**Q4. Terminal vs Intermediate operations?**
- Intermediate: `filter`, `map`, `flatMap`, `distinct`, `sorted`, `limit`, `peek` — return `Stream`.
- Terminal: `collect`, `forEach`, `reduce`, `count`, `findFirst`, `anyMatch`, `toList` — trigger execution.
- Stream cannot be reused after terminal op.

**Q5. flatMap?**
- `map`: one-to-one; wraps result in stream of streams.
- `flatMap`: one-to-many; flattens Stream<Stream<T>> → Stream<T>.
- Example: `List<List<String>> → flatMap(Collection::stream) → Stream<String>`.

**Q6. Optional.orElse vs orElseGet?**
- `orElse(value)`: always evaluates the argument (even if Optional is present).
- `orElseGet(supplier)`: lazy — supplier called only if Optional is empty.
- Rule: if default is a method call / expensive, use `orElseGet`.

**Q7. CompletableFuture.thenApply vs thenCompose?**
- `thenApply(fn)`: `fn` returns a plain value → wraps in CompletableFuture (like `map`).
- `thenCompose(fn)`: `fn` returns a CompletableFuture → flattens (like `flatMap`); avoids `CompletableFuture<CompletableFuture<T>>`.

**Q8. Parallel stream pitfalls?**
- Shared mutable state → race conditions (never use `forEach` with external accumulator).
- Small datasets: thread overhead > gain.
- Ordered pipelines (sorted, findFirst) reduce parallelism benefit.
- I/O-bound tasks: use async (CompletableFuture), not parallel streams.
- Default `ForkJoinPool.commonPool()` is shared — starving it affects other tasks.

**Q9. Collectors.groupingBy?**
```java
Map<Dept, List<Employee>> byDept =
    employees.stream()
             .collect(Collectors.groupingBy(Employee::getDept));
// with downstream:
Map<Dept, Long> countByDept =
    employees.stream()
             .collect(Collectors.groupingBy(Employee::getDept, Collectors.counting()));
```

**Q10. reduce vs collect?**
- `reduce`: immutable reduction (produces single value); not suitable for mutable containers.
- `collect`: mutable reduction into container (List, Map, StringBuilder); uses `Collector`.
- Never `reduce` into a List (creates O(n²) intermediate lists).

**Q11. var (local type inference, Java 10)?**
- Only for local variables with initializer; not for fields, parameters, return types.
- Type inferred at compile time — still statically typed.
- Avoid when type is not obvious from RHS; hurts readability.

**Q12. Records (Java 16)?**
- `record Point(int x, int y) {}` — compiler generates constructor, accessors, `equals`, `hashCode`, `toString`.
- Implicitly final; fields are private final.
- Can add compact constructors, static methods, implement interfaces.

**Q13. Sealed Classes (Java 17)?**
- `sealed interface Shape permits Circle, Rectangle, Triangle {}` — restricts which classes can extend.
- Enables exhaustive pattern matching in `switch`.
- Permitted subclasses: `final`, `sealed`, or `non-sealed`.

**Q14. Pattern Matching instanceof (Java 16)?**
- `if (obj instanceof String s) { s.length(); }` — no explicit cast.
- Scope of pattern variable: true branch of `if` (or negated false branch with `&&`/`||`).
- Java 21: full switch pattern matching — `switch(shape) { case Circle c -> ... }`.

**Q15. Text Blocks (Java 15)?**
- `"""..."""` — multi-line string; incidental whitespace stripped; `\n` handled.
- Trailing `"""` position controls indentation stripping.
- Embedded `"` do not need escaping; use `\` at line end for line continuation.

---

## Section 5: JVM Internals — Top 10 Questions

**Q1. Heap vs Stack vs Metaspace?**
- Stack: per-thread; holds frames (local vars, operand stack, return addr); LIFO; fast; StackOverflowError on overflow.
- Heap: shared; object instances, arrays; GC'd; OutOfMemoryError if full.
- Metaspace (Java 8+, replaced PermGen): class metadata, method bytecode, static fields; auto-grows (configurable with `-XX:MaxMetaspaceSize`).

**Q2. G1 GC regions?**
- Heap divided into equal-sized regions (~1-32 MB); each region labelled Eden/Survivor/Old/Humongous dynamically.
- Humongous: objects > 50% region size; directly in Old gen.
- GC: concurrent marking + mixed collections; predictable pause time (`-XX:MaxGCPauseMillis`).
- Default GC since Java 9.

**Q3. ZGC vs G1?**

| | G1 | ZGC |
|---|---|---|
| Pause target | ~200ms (tunable) | <1ms (Java 15+) |
| Heap | Any | Any (TB-scale) |
| Concurrent | Marking only | Marking + Compaction |
| CPU overhead | Low | Higher (~15%) |
| Production since | Java 9 | Java 15 |

**Q4. JIT tiers?**
- Tier 0: Interpreter.
- Tier 1-2: C1 (client compiler) — fast compile, no heavy opts.
- Tier 3: C1 with profiling.
- Tier 4: C2 (server compiler) — slow compile, heavy optimization (inlining, loop unrolling, escape analysis).
- Hot code (>=10,000 invocations default) promoted to Tier 4.

**Q5. Escape Analysis?**
- JIT detects objects that don't escape method scope → allocates them on stack (no GC pressure).
- Also enables scalar replacement (object fields as local vars) and lock elision (synchronized on non-escaping object removed).

**Q6. Class Loading Delegation Model?**
- Bootstrap CL → Extension/Platform CL → Application CL → Custom CLs.
- Child first checks parent; loads class if parent can't (parent delegation).
- Breaks cycle: child CL can override by checking self first (OSGI, Tomcat webapps).

**Q7. OOM types?**
- `Java heap space`: heap exhausted; increase `-Xmx` or fix leaks.
- `GC overhead limit exceeded`: GC spending >98% time, <2% freed.
- `Metaspace`: class metadata overflow; set `-XX:MaxMetaspaceSize`.
- `Unable to create new native thread`: OS thread limit hit.
- `Direct buffer memory`: off-heap NIO buffers; tune `-XX:MaxDirectMemorySize`.

**Q8. -Xmx vs -Xms?**
- `-Xms`: initial heap size (JVM requests from OS at start).
- `-Xmx`: maximum heap size.
- In containers/prod: set equal to avoid heap resizing pauses and RSS estimation issues.
- Rule: `-Xmx` = ~75% of container memory.

**Q9. Key GC tuning flags?**
```
-XX:+UseG1GC / -XX:+UseZGC / -XX:+UseShenandoahGC
-XX:MaxGCPauseMillis=200
-XX:G1HeapRegionSize=16m
-XX:InitiatingHeapOccupancyPercent=45
-XX:+PrintGCDetails -Xlog:gc*:file=gc.log
```

**Q10. Heap dump analysis?**
- Generate: `jmap -dump:format=b,file=heap.hprof <pid>` or `-XX:+HeapDumpOnOutOfMemoryError`.
- Analyze: Eclipse MAT (Leak Suspects report), VisualVM, JProfiler.
- Key: find largest retained heap objects; GC roots keeping objects alive.

---

## Section 6: Multithreading — Top 15 Questions

**Q1. synchronized vs ReentrantLock?**

| | synchronized | ReentrantLock |
|---|---|---|
| Try lock | No | `tryLock()` / `tryLock(timeout)` |
| Interruptible | No | `lockInterruptibly()` |
| Fairness | No | `new ReentrantLock(true)` |
| Condition vars | One (wait/notify) | Multiple (`newCondition()`) |
| Auto-release | Yes (block exit) | Manual `finally { unlock() }` |

**Q2. volatile — visibility NOT atomicity?**
- `volatile` guarantees: write visible to all threads immediately (no L1/L2 cache hiding); prevents reordering around the write/read.
- Does NOT make compound operations atomic: `volatile int i; i++` is NOT atomic (read-modify-write = 3 ops).
- Use `AtomicInteger` for atomic increments.

**Q3. Happens-before rules (key subset)?**
- Program order: each action HB next action in same thread.
- Monitor unlock HB subsequent lock of same monitor.
- `volatile` write HB subsequent read of same variable.
- Thread start HB any action in started thread.
- Thread termination HB `join()` return.

**Q4. Double-checked locking (DCL)?**
```java
private volatile static Singleton instance; // volatile REQUIRED
public static Singleton getInstance() {
    if (instance == null) {              // first check (no lock)
        synchronized (Singleton.class) {
            if (instance == null) {      // second check (with lock)
                instance = new Singleton();
            }
        }
    }
    return instance;
}
```
Without `volatile`: partial construction visible due to reordering.

**Q5. ThreadPoolExecutor parameters?**
```
corePoolSize   — threads always alive
maxPoolSize    — max threads when queue full
keepAliveTime  — extra threads idle timeout
workQueue      — LinkedBlockingQueue / SynchronousQueue / ArrayBlockingQueue
rejectionHandler — AbortPolicy(default) / CallerRunsPolicy / DiscardPolicy / DiscardOldestPolicy
```
- Task submitted: if threads < core → new thread; else enqueue; if queue full and threads < max → new thread; else reject.

**Q6. ForkJoinPool?**
- Designed for recursive divide-and-conquer tasks.
- Work-stealing: idle threads steal tasks from other threads' deques (LIFO steal → FIFO consume = cache-friendly).
- `RecursiveTask<V>` (returns value), `RecursiveAction` (no return).
- `commonPool()` used by parallel streams, `CompletableFuture`.

**Q7. Deadlock 4 conditions (Coffman)?**
1. Mutual exclusion — resources non-shareable.
2. Hold and wait — thread holds resource while waiting for another.
3. No preemption — resources not forcibly taken.
4. Circular wait — T1→R1→T2→R2→T1.
- Prevention: consistent lock ordering, `tryLock()` with timeout, lock-free algorithms.

**Q8. ThreadLocal memory leak?**
- `ThreadLocal` value held via `Thread.threadLocals` map; key = weak ref to ThreadLocal, value = strong ref.
- In thread pools (long-lived threads): if `ThreadLocal` is GC'd, key becomes null, but value stays until thread dies → leak.
- Fix: always call `threadLocal.remove()` in `finally` block after use.

**Q9. Virtual Threads (Java 21)?**
- Lightweight threads managed by JVM (not OS threads); mount/unmount on carrier (platform) threads.
- 1M+ virtual threads possible; near-zero creation cost.
- Blocking I/O in virtual thread → unmounts from carrier (non-blocking at OS level).
- API: `Thread.ofVirtual().start(task)` or `Executors.newVirtualThreadPerTaskExecutor()`.
- Not faster for CPU-bound; game-changer for I/O-bound server code.

**Q10. CAS & ABA problem?**
- CAS (Compare-And-Swap): atomic hardware instruction; `AtomicInteger.compareAndSet(expect, update)`.
- ABA: value changes A→B→A; CAS sees A, succeeds, but semantic state changed.
- Fix: `AtomicStampedReference<V>` (adds version stamp); `AtomicMarkableReference`.

**Q11. LongAdder vs AtomicLong?**
- `AtomicLong`: single cell; high contention → CAS loop spinning → degraded throughput.
- `LongAdder`: cell array (one per thread under contention); threads update own cell; `sum()` aggregates.
- Use `LongAdder` for high-frequency increments (counters, metrics); `AtomicLong` when you need exact current value atomically.

**Q12. CountDownLatch vs CyclicBarrier vs Semaphore?**

| | CountDownLatch | CyclicBarrier | Semaphore |
|---|---|---|---|
| Reusable | No | Yes | Yes |
| Use | Wait for N events | N threads meet at barrier | Limit concurrent access |
| Key method | `await()` / `countDown()` | `await()` | `acquire()` / `release()` |

**Q13. BlockingQueue types?**
- `ArrayBlockingQueue`: bounded, array-backed, fair option.
- `LinkedBlockingQueue`: optionally bounded (default Integer.MAX_VALUE = effectively unbounded).
- `SynchronousQueue`: zero capacity; each put waits for take (handoff).
- `PriorityBlockingQueue`: unbounded, priority-ordered.
- `DelayQueue`: elements available only after delay expires.

**Q14. wait() vs sleep() vs yield()?**
- `wait()`: releases lock; must be in `synchronized` block; woken by `notify()`/`notifyAll()` or timeout.
- `sleep()`: does NOT release lock; thread pauses for duration; `InterruptedException`.
- `yield()`: hint to scheduler to let equal-priority threads run; may be ignored; does not release lock.

**Q15. StampedLock?**
- Java 8; supports: Write lock, Read lock, Optimistic read (no lock — validates after).
- Optimistic read pattern: stamp = `tryOptimisticRead()` → read → `validate(stamp)`; retry with read lock on failure.
- Not reentrant; no Condition support; faster than `ReadWriteLock` for read-heavy workloads.

---

## Section 7: Common Traps & Gotchas

1. **Integer overflow**: `int` wraps silently; use `Math.addExact()` or `long` for large arithmetic.
2. **String `+` in loop**: creates O(n) StringBuilder objects; use `StringBuilder.append()` explicitly.
3. **`==` on Integer outside cache**: `Integer a = 200; Integer b = 200; a == b` → `false`; use `.equals()`.
4. **NPE from autoboxing**: `Integer x = null; int y = x;` → NPE; always null-check before unbox.
5. **ConcurrentModificationException**: never `list.remove()` inside `for-each`; use `iterator.remove()` or `removeIf()`.
6. **iterator.remove() vs list.remove(index)**: `list.remove(0)` during iteration breaks index; only `Iterator.remove()` is safe.
7. **HashMap initial capacity**: not providing expected size causes multiple rehashes for large maps; pre-size with `size / 0.75 + 1`.
8. **Thread-safe singleton via class loading**: enum singleton or static holder idiom is simpler than DCL.
9. **DCL without volatile**: partial construction visible to other threads; always mark instance `volatile`.
10. **Stream reuse**: stream is consumed after terminal op; `IllegalStateException` on second terminal; recreate stream.
11. **Optional.get() without isPresent()**: throws `NoSuchElementException`; always use `orElse`/`orElseThrow`/`ifPresent`.
12. **Comparator returning Integer.MIN_VALUE**: `return o1.val - o2.val` overflows for large negatives; use `Integer.compare(o1.val, o2.val)`.
13. **`finalize()` reliability**: not guaranteed to run; not for resource cleanup; use try-with-resources instead.
14. **Static field in inner class**: non-static inner class cannot have `static` fields; use `static` nested class.
15. **String switch falls through**: `switch` on String uses `equals()`; still falls through without `break`.
16. **Arrays.asList() is fixed-size**: `add()`/`remove()` throw `UnsupportedOperationException`; backed by array; `set()` works.
17. **Collections.sort vs List.sort**: `List.sort()` (Java 8) is slightly faster (no array copy); both TimSort O(n log n).
18. **wait() in loop, not if**: spurious wakeups possible; always `while (!condition) wait()`.
19. **Thread.stop() deprecated**: never use; use volatile flag or `interrupt()` + check `Thread.isInterrupted()`.
20. **long/double non-atomic on 32-bit JVM**: reads/writes of `long`/`double` fields not guaranteed atomic without `volatile`; moot on modern 64-bit JVMs but still spec-defined.

---

## Section 8: Must-Know Code Snippets

### 8.1 Thread-safe Singleton — Enum (Preferred)
```java
public enum Singleton {
    INSTANCE;
    public void doWork() { /* ... */ }
}
// Usage: Singleton.INSTANCE.doWork();
// JVM guarantees: single instantiation, serialization-safe, thread-safe
```

### 8.2 Thread-safe Singleton — DCL
```java
public class Singleton {
    private static volatile Singleton instance;
    private Singleton() {}
    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) instance = new Singleton();
            }
        }
        return instance;
    }
}
```

### 8.3 Custom Comparator — Lambda + Method Reference
```java
List<Employee> employees = ...;
// Multi-key sort: by dept then by name
employees.sort(Comparator.comparing(Employee::getDept)
                         .thenComparing(Employee::getName)
                         .reversed());
// Null-safe:
employees.sort(Comparator.comparing(Employee::getName,
               Comparator.nullsLast(Comparator.naturalOrder())));
```

### 8.4 Stream with groupingBy
```java
// Group employees by department, then count per department
Map<String, Long> headcountByDept = employees.stream()
    .collect(Collectors.groupingBy(
        Employee::getDept,
        Collectors.counting()
    ));

// Group and get list of names per department
Map<String, List<String>> namesByDept = employees.stream()
    .collect(Collectors.groupingBy(
        Employee::getDept,
        Collectors.mapping(Employee::getName, Collectors.toList())
    ));
```

### 8.5 CompletableFuture Chain
```java
CompletableFuture<String> result = CompletableFuture
    .supplyAsync(() -> fetchUserId())               // async, ForkJoinPool
    .thenApplyAsync(id -> fetchUserName(id))        // map: String -> String
    .thenCompose(name -> fetchProfile(name))        // flatMap: returns CF<Profile>
    .thenApply(Profile::getSummary)
    .exceptionally(ex -> "default-summary")        // error recovery
    .whenComplete((val, ex) -> log(val, ex));       // side effect, always runs

String summary = result.get(5, TimeUnit.SECONDS);  // block with timeout
```

### 8.6 Producer-Consumer with BlockingQueue
```java
BlockingQueue<Integer> queue = new ArrayBlockingQueue<>(10);

// Producer
Runnable producer = () -> {
    for (int i = 0; i < 100; i++) {
        try { queue.put(i); }           // blocks when full
        catch (InterruptedException e) { Thread.currentThread().interrupt(); break; }
    }
};

// Consumer
Runnable consumer = () -> {
    while (!Thread.currentThread().isInterrupted()) {
        try {
            Integer item = queue.poll(1, TimeUnit.SECONDS); // blocks 1s max
            if (item == null) break;    // timeout = no more data
            process(item);
        } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
    }
};

new Thread(producer).start();
new Thread(consumer).start();
```

### 8.7 Deadlock Example
```java
Object lockA = new Object();
Object lockB = new Object();

Thread t1 = new Thread(() -> {
    synchronized (lockA) {
        sleep(50);
        synchronized (lockB) { /* work */ }  // waits for lockB
    }
});

Thread t2 = new Thread(() -> {
    synchronized (lockB) {
        sleep(50);
        synchronized (lockA) { /* work */ }  // waits for lockA → DEADLOCK
    }
});
// Fix: always acquire locks in same order (lockA then lockB) in both threads
```

---

## Quick Reference Card

### Big-O Cheat Sheet — Collections

| Operation | ArrayList | LinkedList | HashMap | TreeMap | PriorityQueue |
|---|---|---|---|---|---|
| get(i) | O(1) | O(n) | O(1) avg | O(log n) | O(n) |
| add | O(1) amort | O(1) | O(1) avg | O(log n) | O(log n) |
| remove | O(n) | O(n) | O(1) avg | O(log n) | O(log n) |
| contains | O(n) | O(n) | O(1) avg | O(log n) | O(n) |

### Java Version Timeline (Interview Relevance)

| Version | Key Features |
|---|---|
| Java 8 | Lambdas, Streams, Optional, CompletableFuture, Default methods, LocalDateTime |
| Java 9 | Modules, List.of(), compact strings, Stream.takeWhile/dropWhile |
| Java 10 | `var` local type inference, List.copyOf() |
| Java 11 | String methods (isBlank, strip, lines), HttpClient, running single-file |
| Java 14 | Records (preview), helpful NPE messages |
| Java 15 | Text blocks, sealed classes (preview) |
| Java 16 | Records (stable), pattern matching instanceof (stable) |
| Java 17 | Sealed classes (stable) — LTS |
| Java 21 | Virtual threads (stable), sequenced collections, pattern matching switch — LTS |

---

*End of Chapter 23 — Core Java Quick Revision*


