# Chapter 5: JVM Internals

**Target Audience:** Java SDE2 candidates (2–5 years experience)  
**Baseline:** Java 17 LTS  
**Companies:** Amazon, Google, Goldman Sachs, Morgan Stanley, Stripe, Uber, Netflix, Atlassian, JPMorgan

---

## Table of Contents

1. [JVM Memory Architecture](#1-jvm-memory-architecture)
2. [Garbage Collection](#2-garbage-collection)
3. [Class Loading](#3-class-loading)
4. [JIT Compiler](#4-jit-compiler)
5. [Practical Diagnostics](#5-practical-diagnostics)
6. [JVM Memory Cheat Sheet](#6-jvm-memory-cheat-sheet)

---

## 1. JVM Memory Architecture

---

### Q1. Describe all JVM memory areas and what each one stores.

**Difficulty:** Medium | **Interview Frequency:** Very High  
**Companies:** Amazon, Google, Goldman Sachs, Morgan Stanley, JPMorgan, Atlassian, Stripe

---

![Java Virtual Machine Architecture](https://upload.wikimedia.org/wikipedia/commons/3/3a/Java_virtual_machine_architecture.svg)
*JVM Architecture — Class Loader, Runtime Data Areas (Heap, Stack, Method Area), and Execution Engine*

**Short Answer (30–60 seconds)**

The JVM divides memory into several runtime data areas. The **Heap** stores all object instances and is shared across threads. The **Stack** stores method frames (local variables, operand stack) and is thread-local. **Metaspace** stores class metadata and method bytecode, living in native memory. The **Code Cache** stores JIT-compiled native code. The **Native Method Stack** supports JNI calls. The **PC Register** holds the current bytecode instruction pointer and is thread-local.

---

**Deep Explanation**

The JVM specification defines six runtime data areas:

| Memory Area | Stored Content | Thread Scope | Managed By |
|---|---|---|---|
| Heap | Object instances, arrays | Shared | GC |
| JVM Stack | Method frames, local vars, operand stack | Thread-local | JVM (auto-pop on return) |
| Metaspace | Class metadata, method bytecode, constant pool | Shared | JVM + OS |
| Code Cache | JIT-compiled native code | Shared | JIT compiler |
| Native Method Stack | Native (C/C++) method frames | Thread-local | OS |
| PC Register | Current bytecode instruction address | Thread-local | JVM |

**Heap** is the primary GC-managed region. Every `new` keyword allocates on the heap (unless escape analysis moves it to the stack). Shared across all threads, requiring synchronization and GC to manage lifecycle.

**JVM Stack** is created per thread at thread creation. Each method invocation pushes a **stack frame** containing:
- Local variable array (index 0 = `this` for instance methods)
- Operand stack (values pushed/popped during bytecode execution)
- Frame data (reference to constant pool, return address)

Frames are LIFO — the current frame is always on top. When a method returns, its frame is popped. `StackOverflowError` occurs when the stack exceeds its maximum depth (`-Xss` flag).

**Metaspace** (introduced Java 8, replaced PermGen) lives in **native memory** outside the JVM heap. It stores:
- Class structures (field names, method signatures, bytecode)
- Runtime constant pool
- Static variable references (note: static variable *values* moved to heap in Java 8+)
- Method bytecode

Unlike PermGen, Metaspace grows dynamically. Without `-XX:MaxMetaspaceSize`, it can grow until native memory exhaustion.

**Code Cache** is a memory region storing native machine code produced by the JIT compiler. Managed by the JVM's code cache manager with eviction when full.

---

**Real-World Backend Example**

In a Spring Boot microservice handling 10,000 concurrent requests, each request thread allocates a JVM stack. At default `-Xss512k` per thread, 10,000 threads consume ~5 GB in stack memory alone. This is why modern services prefer async/reactive models (Project Reactor, Virtual Threads in Java 21) over traditional thread-per-request.

---

**Java 17 Code Example**

```java
public class MemoryAreaDemo {

    // Static field reference lives in Metaspace class structure;
    // the object it points to lives on the Heap
    private static final List<String> CACHE = new ArrayList<>();

    public void processRequest(String data) {
        // 'data' reference is in stack frame local variable array
        // The String object is on the heap
        String processed = data.toUpperCase(); // new String object on heap
        CACHE.add(processed);                  // reference added to heap object
    }

    // Recursive method — each call pushes a new frame onto thread stack
    public int factorial(int n) {
        if (n <= 1) return 1;
        return n * factorial(n - 1); // deep recursion → StackOverflowError
    }
}
```

---

**Follow-Up Questions**

- Where are static variables stored in Java 8 vs Java 7?
- What happens when Metaspace fills up?
- How does the PC Register handle native methods?
- Can two threads share a stack frame?

---

**Common Mistakes**

- Saying static variables are in PermGen/Metaspace — static *references* are in class structures in Metaspace; the actual object is on the heap (Java 8+).
- Confusing Code Cache with Metaspace — bytecode is in Metaspace; compiled native code is in Code Cache.
- Saying stack memory is garbage collected — it is not; frames are automatically reclaimed on method return.

---

**Interview Traps**

- "Where are String literals stored?" — In the String Pool, which is on the heap in Java 7+ (was PermGen in Java 6).
- "Is the heap always contiguous?" — No. G1 divides it into non-contiguous regions.
- "What does the PC Register hold for native methods?" — It is undefined (set to `undefined`/`null`) for native method execution.

---

**Quick Revision Notes**

- Heap = objects (GC-managed, thread-shared). Stack = method frames (thread-local, auto-managed).
- Metaspace = class metadata in native memory; grows dynamically, no fixed max by default.
- Code Cache = JIT native output. PC Register = instruction pointer, thread-local.
- Static variable *values* are on the heap (Java 8+), not in Metaspace.

---

### Q2. Explain Heap structure — generations, Eden, Survivor spaces, and object promotion.

**Difficulty:** Medium | **Interview Frequency:** Very High  
**Companies:** Amazon, Google, Goldman Sachs, Netflix, Stripe, Uber

---

**Short Answer (30–60 seconds)**

The JVM heap is split into Young Generation and Old Generation. Young Generation contains Eden space and two Survivor spaces (S0 and S1). New objects are allocated in Eden. When Eden fills, a Minor GC runs — live objects move to a Survivor space. Objects that survive multiple GC cycles are promoted to Old Generation. This design exploits the generational hypothesis: most objects die young, making young-gen collection fast and cheap.

---

**Deep Explanation**

**Generational Hypothesis:** Empirical observation that the vast majority of objects become unreachable very quickly after allocation (request-scoped objects, temporary strings, iterators). GC can exploit this by collecting the young generation frequently with low overhead instead of scanning the entire heap.

**Heap Regions:**

```
Young Generation                          Old Generation
+------------------+--------+--------+   +---------------------------+
|      Eden        |   S0   |   S1   |   |   Tenured / Old Gen       |
|  (new objects)   |(from)  | (to)   |   |  (long-lived objects)     |
+------------------+--------+--------+   +---------------------------+
```

**Object Lifecycle:**

1. New objects allocated in **Eden** (fast — just a pointer bump).
2. Eden fills → **Minor GC** triggered.
3. Live objects (reachable from GC roots) copied to **empty Survivor space** (e.g., S1). Dead objects discarded.
4. S0 (previously used) live objects also copied to S1. S0 is now empty.
5. Object's age counter incremented. When age reaches **tenuring threshold** (`-XX:MaxTenuringThreshold`, default 15), object is promoted to **Old Generation**.
6. Old Generation fills → **Major GC** or **Full GC** triggered.

**Why two Survivor spaces?** To avoid fragmentation. After each Minor GC, one Survivor space is always empty (the "to" space). Live objects are compacted into it by copying. This eliminates fragmentation in the young generation entirely — Eden and the active Survivor are always contiguous free space.

**Humongous Allocations (G1 GC):** Objects larger than 50% of a G1 region size bypass Young Generation entirely and go directly to special Humongous regions in Old Generation.

---

**Real-World Backend Example**

A REST API that processes 5,000 requests/second creates and discards thousands of DTO objects, HttpServletRequest wrappers, Jackson parse trees, and StringBuilder instances per second. These are all short-lived. With proper heap sizing, nearly all of them die in Eden and are collected by frequent, fast Minor GCs (typically 5–50ms), never polluting Old Generation. Poorly tuned applications with large Eden cause infrequent but very long Minor GCs.

---

**Java 17 Code Example**

```java
// JVM flags to observe generation behavior:
// -Xms512m -Xmx512m -XX:+UseG1GC -Xlog:gc*:stdout:time

public class GenerationDemo {

    public static void main(String[] args) throws InterruptedException {
        List<byte[]> longLived = new ArrayList<>();

        for (int i = 0; i < 1000; i++) {
            // Short-lived: dies in Eden/Survivor
            byte[] shortLived = new byte[1024];
            processData(shortLived);

            // Long-lived: survives many GC cycles, promoted to Old Gen
            if (i % 100 == 0) {
                longLived.add(new byte[10240]);
            }

            Thread.sleep(1); // allow GC to run
        }
    }

    private static void processData(byte[] data) {
        // data reference goes out of scope here → eligible for GC
    }
}
```

**Observation flags:**
```bash
-Xms256m -Xmx256m -XX:+UseG1GC -Xlog:gc*:file=gc.log:time,uptime,level,tags
```

---

**Follow-Up Questions**

- What is `-XX:NewRatio` and `-XX:SurvivorRatio`?
- What happens when an object is too large to fit in Eden?
- How does G1 GC differ from this classic generational layout?
- What is premature promotion and why is it bad?

---

**Common Mistakes**

- Saying GC moves objects from Old Gen back to Young Gen — promotion is one-way.
- Confusing S0/S1 roles — they alternate "from" and "to" roles each Minor GC.
- Not knowing that G1 GC still has logical generations but uses a region-based physical layout.

---

**Interview Traps**

- "What is premature promotion?" — When the Survivor space is too small to hold all survivors from a Minor GC, objects are promoted to Old Gen earlier than their age threshold, polluting Old Gen with short-lived objects.
- "What is `-XX:MaxTenuringThreshold=0` for?" — Forces all objects surviving one Minor GC to immediately be promoted to Old Gen; used when Old Gen is large and young gen is small.

---

**Quick Revision Notes**

- Eden → Minor GC → Survivor(s) → Old Gen (after tenuring threshold).
- Two Survivor spaces eliminate fragmentation via copy-collection.
- Generational hypothesis: most objects die young.
- Premature promotion = Survivor too small → objects go to Old Gen too early.

---

### Q3. How does Stack memory work? What causes StackOverflowError?

**Difficulty:** Easy | **Interview Frequency:** High  
**Companies:** Amazon, Google, Atlassian, Stripe

---

**Short Answer (30–60 seconds)**

Each thread has its own JVM stack. Every method call pushes a frame containing local variables, the operand stack, and the return address. Frames are popped on method return. `StackOverflowError` occurs when recursive calls push more frames than the stack can hold. Stack size is configured per thread with `-Xss`.

---

**Deep Explanation**

**Stack Frame Contents:**

```
Stack Frame
+-----------------------+
| Local Variable Array  |  Index 0 = 'this' (instance methods)
|   [this, a, b, c...]  |  Primitive values stored directly; objects store references
+-----------------------+
| Operand Stack         |  Working area for bytecode instructions
|   [val1, val2...]     |  JVM is a stack machine; ADD pops 2, pushes result
+-----------------------+
| Frame Data            |  Reference to constant pool, exception table, return address
+-----------------------+
```

**LIFO structure:** The current executing method's frame is always at the top. When `methodA` calls `methodB`, `methodB`'s frame is pushed on top. When `methodB` returns, its frame is popped and execution resumes in `methodA`'s frame.

**StackOverflowError:** Java's stack size per thread defaults to 512KB–1MB depending on the OS and JVM. Each frame consumes space proportional to the number of local variables. Deep recursion — especially with many local variables — exhausts the stack.

**Why is stack thread-local?** Each thread has an independent execution path. Sharing stacks between threads would require complex synchronization for every local variable access, defeating the purpose of thread isolation.

---

**Real-World Backend Example**

A recursive JSON parser processing deeply nested payloads (e.g., 500+ nesting levels) can cause `StackOverflowError` under load. Fix: convert recursion to iteration using an explicit `Deque<Node>` stack on the heap, or increase `-Xss` per thread (note: increasing `-Xss` multiplied by thread count increases total memory consumption).

---

**Java 17 Code Example**

```java
public class StackDemo {

    // Causes StackOverflowError for large n
    public static int recursiveSum(int n) {
        if (n == 0) return 0;
        return n + recursiveSum(n - 1); // each call: new frame with 'n' local var
    }

    // Iterative equivalent — uses O(1) stack space
    public static int iterativeSum(int n) {
        int result = 0;
        while (n > 0) result += n--;
        return result;
    }

    // Tail-recursive (JVM does NOT optimize tail calls unlike Scala/Kotlin)
    public static int tailRecursive(int n, int acc) {
        if (n == 0) return acc;
        return tailRecursive(n - 1, acc + n); // JVM still pushes a new frame here
    }

    public static void main(String[] args) {
        try {
            System.out.println(recursiveSum(100_000)); // StackOverflowError
        } catch (StackOverflowError e) {
            System.out.println("Stack exhausted: " + e);
        }
        System.out.println(iterativeSum(100_000)); // works fine
    }
}
```

---

**Follow-Up Questions**

- Does Java optimize tail recursion?
- How does increasing `-Xss` affect total memory with 1,000 threads?
- What is the difference between `StackOverflowError` and `OutOfMemoryError: unable to create native thread`?

---

**Common Mistakes**

- Assuming Java performs tail-call optimization — it does not. The JVM spec does not mandate it.
- Forgetting that `StackOverflowError` is a `java.lang.Error`, not an `Exception`, but it can be caught.

---

**Interview Traps**

- "Can you catch `StackOverflowError`?" — Yes, it is an `Error` but is `Throwable` and can be caught with `catch (StackOverflowError e)`. However, catching it is almost never the right solution.
- "What does `-Xss256k` with 10,000 threads cost?" — 10,000 × 256KB = ~2.5 GB in stack memory alone.

---

**Quick Revision Notes**

- Stack = LIFO, thread-local, one frame per method call.
- Frame = local variables + operand stack + frame data.
- `StackOverflowError` = too deep recursion (or `-Xss` too small).
- Java does NOT optimize tail recursion.

---

### Q4. What is Metaspace? How does it differ from the heap?

**Difficulty:** Medium | **Interview Frequency:** High  
**Companies:** Goldman Sachs, Morgan Stanley, Amazon, Atlassian

---

**Short Answer (30–60 seconds)**

Metaspace stores class metadata — class structures, method bytecode, and the runtime constant pool — in native memory (outside the JVM heap). It replaced PermGen in Java 8. Unlike PermGen, Metaspace grows dynamically up to the available native memory unless capped with `-XX:MaxMetaspaceSize`. It is not collected by the heap GC; class metadata is reclaimed only when a classloader is garbage collected.

---

**Deep Explanation**

**What Metaspace contains:**
- `Klass` structures (JVM's internal class representation)
- Method bytecode and metadata
- Runtime constant pool entries
- Annotations
- Static field *references* (the `Class` object itself is on the heap; static values are in the heap-resident `Class` object's mirror)

**Key behavior differences from heap:**
- Allocated from native memory (OS directly), not the JVM heap.
- Not compacted by GC; reclaimed wholesale when a `ClassLoader` becomes unreachable.
- Default max = unlimited (bounded only by available native memory).
- `-XX:MetaspaceSize` sets the initial committed size (triggers first GC of dead classloaders when reached, not the cap).
- `-XX:MaxMetaspaceSize` sets the hard cap; exceeding it throws `OutOfMemoryError: Metaspace`.

**When does Metaspace grow?**
- Loading more classes (each loaded class consumes metadata space).
- Dynamic class generation (reflection proxies, CGLIB proxies in Spring, Hibernate enhancement, lambda desugaring creates synthetic classes).
- Each web application classloader in an application server loads its own copy of framework classes.

---

**Real-World Backend Example**

A Spring Boot application heavily using CGLIB (proxies for `@Transactional`, `@Cacheable`, AOP aspects) generates synthetic subclasses at startup. Without `-XX:MaxMetaspaceSize`, Metaspace can grow to 500MB+ in large enterprise applications. In Kubernetes, this native memory is outside the JVM heap and can push container memory beyond the configured limit, causing OOM kills. Proper tuning requires setting both `-Xmx` (heap cap) and `-XX:MaxMetaspaceSize`.

---

**Follow-Up Questions**

- What causes `OutOfMemoryError: Metaspace` in production?
- How do Spring/Hibernate contribute to Metaspace usage?
- What is `-XX:MetaspaceSize` vs `-XX:MaxMetaspaceSize`?

---

**Common Mistakes**

- Saying `-XX:MetaspaceSize` is the cap — it is the initial trigger size, not the maximum.
- Forgetting that Metaspace is native memory — not counted in `-Xmx`.

---

**Interview Traps**

- "Can Metaspace be garbage collected?" — Indirectly, yes: when a classloader becomes unreachable, the GC collects it and then Metaspace reclaims all metadata associated with that classloader.
- "Where does `-XX:MaxMetaspaceSize` fit in container memory sizing?" — It must be added to `-Xmx` and other native memory uses (Code Cache, thread stacks) when computing total container memory.

---

**Quick Revision Notes**

- Metaspace = class metadata in native memory. Not on heap. No fixed default cap.
- `-XX:MaxMetaspaceSize` = hard cap. `-XX:MetaspaceSize` = initial trigger for first classloader GC.
- `OutOfMemoryError: Metaspace` → too many classes loaded, classloader leaks, excessive proxying.
- CGLIB, ASM, Groovy scripts, and JSPs all generate classes dynamically.

---

### Q5. PermGen vs Metaspace — why was PermGen removed?

**Difficulty:** Easy | **Interview Frequency:** Medium  
**Companies:** Goldman Sachs, JPMorgan, legacy enterprise shops

---

**Short Answer (30–60 seconds)**

PermGen was the pre-Java-8 area for class metadata. It had a fixed maximum size (`-XX:MaxPermSize`, default 64–256MB), causing `OutOfMemoryError: PermGen space` in applications with many classes. Java 8 removed it and replaced it with Metaspace in native memory. Metaspace grows dynamically, eliminating the fixed-size problem and simplifying JVM memory management.

---

**Deep Explanation**

**PermGen limitations:**
- Fixed maximum: `-XX:MaxPermSize` (default 64MB, often tuned to 256MB). Hard to size correctly across environments.
- Collected using full GC — PermGen collection required a full STW pause.
- Storing `java.lang.String` interned strings in PermGen caused leaks in applications with heavy string interning.
- Classloader leaks in application servers (e.g., Tomcat hot-redeploy) caused `OutOfMemoryError: PermGen space` over time as old class metadata was not fully reclaimed.

**Metaspace advantages:**
- Lives in native memory → OS manages growth dynamically.
- No fixed default cap — eliminates the most common PermGen sizing mistake.
- String interning moved to heap (String Pool on heap since Java 7, completed in Java 8).
- Classloader metadata reclamation more reliable.
- Per-classloader allocation improves reclamation granularity.

**Migration impact:**
- `-XX:MaxPermSize` and `-XX:PermSize` are silently ignored in Java 8+.
- `-XX:MetaspaceSize` and `-XX:MaxMetaspaceSize` are the replacements.
- Java 8 migration fix for `OutOfMemoryError: PermGen`: remove `-XX:MaxPermSize` and optionally add `-XX:MaxMetaspaceSize`.

---

**Quick Revision Notes**

- PermGen: fixed max, collected in full GC, removed in Java 8.
- Metaspace: native memory, dynamic growth, no default cap.
- `-XX:MaxPermSize` ignored in Java 8+; use `-XX:MaxMetaspaceSize` instead.
- String pool moved to heap in Java 7; interned strings no longer in PermGen.

---

## 2. Garbage Collection

---

### Q6. Explain GC fundamentals — mark-and-sweep, GC roots, and Stop-The-World pauses.

**Difficulty:** Medium | **Interview Frequency:** Very High  
**Companies:** Amazon, Google, Goldman Sachs, Netflix, Stripe, Uber, Atlassian

---

**Short Answer (30–60 seconds)**

Garbage collection identifies unreachable objects and reclaims their memory. The JVM uses reachability: starting from GC roots — thread stack references, static variables, JNI references — it marks all reachable objects. Everything unmarked is garbage. Stop-The-World (STW) pauses halt all application threads to ensure a consistent heap snapshot. Long STW pauses increase latency and are the primary GC tuning concern for latency-sensitive systems.

---

**Deep Explanation**

**Reachability vs. Reference Counting:**
Java uses reachability analysis, not reference counting. This correctly handles circular references (two objects referencing each other with no external reference are both unreachable and collectible).

**GC Roots — the starting points of reachability:**
1. Local variables and method parameters in active thread stacks
2. Active Java threads themselves
3. Static fields of loaded classes (references in class structures)
4. JNI (Java Native Interface) global and local references
5. References held by synchronized monitors
6. Class objects of loaded classes (held by classloaders)
7. Interned String objects

**Mark-and-Sweep phases:**
1. **Mark phase:** Traverse the object graph from all GC roots, marking every reachable object. Requires heap traversal — cost proportional to live object count.
2. **Sweep phase:** Scan the entire heap; reclaim unmarked (unreachable) objects. Returns memory to free lists.
3. **Compact phase (optional):** Move live objects together to eliminate fragmentation. Expensive but allows fast bump-pointer allocation.

**Stop-The-World (STW) pause:**
During marking, the heap graph must remain consistent — no threads can mutate references. STW pauses all application threads until GC completes the critical phase. Even 100ms STW on a 10,000 RPS service can cause 1,000 requests to see elevated latency in that window.

**Why STW matters for latency-sensitive systems:**
A trading system processing FX orders must respond in <1ms. A 200ms STW GC pause causes order rejections, slippage, and regulatory risk. This drives adoption of ZGC, Shenandoah, or hardware over-provisioning strategies.

---

**Real-World Backend Example**

A fintech payment gateway running on Parallel GC experienced 2-second full GC pauses during peak load (month-end batch + API traffic). Every pause caused HTTP timeouts visible to upstream callers. Solution: migrate to G1 GC with `-XX:MaxGCPauseMillis=200`, properly size generations to avoid full GCs, and add `-XX:+HeapDumpOnOutOfMemoryError` for diagnostics.

---

**Java 17 Code Example**

```java
// Demonstrating strong vs weak references and GC behavior
import java.lang.ref.*;

public class GCRootsDemo {

    static Object staticRoot = new Object(); // GC root: static field

    public void demonstrate() {
        Object strongRef = new Object();     // GC root: stack local variable
        WeakReference<Object> weakRef = new WeakReference<>(new Object());
        SoftReference<byte[]> cache = new SoftReference<>(new byte[1024 * 1024]);

        // Force GC (for demonstration only — never in production)
        System.gc();

        // strongRef: still reachable, NOT collected
        // weakRef.get(): likely null — object has no strong reference, collected
        // cache.get(): may survive if heap has space (JVM tries to keep soft refs)
        System.out.println("Weak ref after GC: " + weakRef.get());
        System.out.println("Soft ref after GC: " + (cache.get() != null ? "alive" : "collected"));
    }
}
```

---

**Follow-Up Questions**

- What is the difference between `WeakReference`, `SoftReference`, and `PhantomReference`?
- Can circular references be collected in Java?
- What are write barriers and why do concurrent GCs need them?

---

**Common Mistakes**

- Saying `System.gc()` guarantees immediate collection — it is only a hint; the JVM may ignore it.
- Thinking static fields are always GC roots — they are roots only for classes that are currently loaded. If a classloader is unreachable, its static fields become unreachable too.

---

**Interview Traps**

- "What happens to finalizers during GC?" — Objects with `finalize()` methods are not immediately reclaimed. They are added to the finalizer queue and finalized asynchronously. This delays reclamation and can cause memory pressure. `Cleaner` (Java 9+) is the modern replacement.
- "What are write barriers?" — Instrumentation inserted by the JVM around reference writes to keep GC data structures (like remembered sets) consistent during concurrent collection without STW.

---

**Quick Revision Notes**

- Reachability analysis from GC roots (stacks, statics, JNI). Circular refs are collectible.
- Mark → Sweep → (optional) Compact.
- STW: all threads paused during critical GC phases.
- Long STW pauses = high tail latency. Concurrent GCs (G1, ZGC) minimize STW.

---

### Q7. Minor GC vs Major GC vs Full GC — triggers, affected regions, STW implications.

**Difficulty:** Medium | **Interview Frequency:** Very High  
**Companies:** Amazon, Goldman Sachs, Netflix, Uber

---

**Short Answer (30–60 seconds)**

Minor GC collects the Young Generation when Eden fills up. It is fast (milliseconds) but is STW. Major GC collects the Old Generation — slower and longer STW. Full GC collects the entire heap (Young + Old + Metaspace) and is the most disruptive. Full GC is triggered when Old Gen fills up, explicit `System.gc()` is called, or certain GC failure conditions occur.

---

**Deep Explanation**

| GC Type | Region Collected | Typical Trigger | STW Duration | Frequency |
|---|---|---|---|---|
| Minor GC | Young Generation only | Eden full | 5–50ms | Very frequent |
| Major GC | Old Generation | Old Gen filling up | 100ms–several seconds | Less frequent |
| Full GC | Entire heap + Metaspace | Old Gen full, `System.gc()`, promotion failure | 1–10+ seconds | Should be rare |
| Mixed GC (G1) | Young + some Old regions | G1 internal triggers | Configurable | Moderate |

**Minor GC details:**
- Triggered when Eden space is exhausted.
- Collects only Young Generation (Eden + Survivor spaces).
- Uses copying algorithm: live objects copied to empty Survivor space.
- Fast because: small region, young objects mostly dead, copying only live objects.
- STW, but brief.

**Major GC details:**
- Collects Old Generation.
- Slower because Old Gen is larger, objects mostly live (survived many collections).
- Compaction required to prevent fragmentation (in most collectors).
- May be triggered concurrently (G1, CMS) to reduce pause time.

**Full GC details:**
- Collects the entire heap and Metaspace.
- Most disruptive GC event.
- Triggers:
  - Old Generation exhausted
  - Metaspace exhausted (if capped)
  - `System.gc()` or `Runtime.gc()` called
  - Allocation failure after promotion failure
  - JVM internal decisions (e.g., CMS concurrent mode failure)
- With Parallel GC: single long STW pause.
- With G1: fallback to serial Full GC if concurrent marking falls behind.

**Promotion failure:** If Old Gen has insufficient space to receive objects being promoted from Young Gen, a Full GC is triggered. This is a common cause of unexpected Full GCs in production.

---

**Real-World Backend Example**

A recommendation engine service had frequent Full GCs (every 2–3 minutes). Investigation with `-Xlog:gc*` revealed: Minor GC every 100ms promoting large byte array caches to Old Gen (premature promotion due to undersized Survivor spaces). Old Gen filled in 3 minutes, triggering Full GC. Fix: increase `-Xmn` (Young Gen size), increase `-XX:SurvivorRatio` to reduce premature promotion, and cache byte arrays in off-heap storage (Chronicle Map or direct ByteBuffer).

---

**Follow-Up Questions**

- What is promotion failure and how do you prevent it?
- Why should you avoid calling `System.gc()` in production code?
- How does G1's Mixed GC differ from a traditional Major GC?

---

**Quick Revision Notes**

- Minor GC = Young Gen, fast, frequent. Major GC = Old Gen, slower. Full GC = everything, most expensive.
- Full GC should be rare in a well-tuned application.
- Promotion failure (Old Gen full during Minor GC) triggers Full GC.
- G1 uses Mixed GC (Young + selected Old regions) to avoid full Old Gen collections.

---

### Q8. Serial GC — what it is and when to use it.

**Difficulty:** Easy | **Interview Frequency:** Low  
**Companies:** Embedded/IoT, CLI tool interviews

---

**Short Answer (30–60 seconds)**

Serial GC uses a single thread for both Minor and Major GC, fully stop-the-world. Enable with `-XX:+UseSerialGC`. It is appropriate for small heaps (<1GB), single-CPU environments, or batch processes where throughput matters and pause time does not. Not suitable for interactive or latency-sensitive server applications.

---

**Deep Explanation**

Serial GC is the simplest collector. It halts all application threads and runs GC on a single thread. This eliminates synchronization overhead between GC threads, making it efficient for small heaps. On a single-core system, it is actually competitive with parallel collectors because there are no cores to parallelize across.

**Use cases:**
- Microservices with very small heaps (e.g., AWS Lambda, CLI utilities)
- Batch processing jobs where throughput > latency
- JVM containers with 1 CPU core allocation (Kubernetes CPU limit = 0.5 cores)
- Java 17+ on small containers (JVM now auto-detects container CPU/memory limits)

**JVM auto-selection:** In Java 17, the JVM selects Serial GC automatically on machines detected as "server" class (2+ CPUs, 2GB+ RAM) using heuristics, but for containers under resource limits it may still select Serial GC.

---

**Quick Revision Notes**

- Single-threaded, full STW. Enable: `-XX:+UseSerialGC`.
- Appropriate for small heaps, single-CPU, batch jobs.
- Never use for multi-threaded server applications with latency requirements.

---

### Q9. Parallel GC — throughput-focused, multi-threaded.

**Difficulty:** Easy | **Interview Frequency:** Medium  
**Companies:** Amazon, batch processing system interviews

---

**Short Answer (30–60 seconds)**

Parallel GC uses multiple threads for Young and Old Generation collection. It is the default in Java 8. It maximizes throughput (application time / (application time + GC time)) but does not minimize pause time — all collection phases are STW, just done in parallel. Enable with `-XX:+UseParallelGC`. Best for throughput-oriented workloads (batch ETL, analytics) tolerating longer GC pauses.

---

**Deep Explanation**

Parallel GC has two components:
- **Parallel Scavenge:** Multi-threaded Minor GC in Young Gen.
- **Parallel Old:** Multi-threaded Major GC in Old Gen (Java 7+).

The number of GC threads defaults to the number of CPU cores (`-XX:ParallelGCThreads` to tune). Parallel GC can also auto-adjust heap sizes based on throughput/pause goals (`-XX:GCTimeRatio`, `-XX:MaxGCPauseMillis`) — this is called **ergonomics**.

**Throughput goal:** `-XX:GCTimeRatio=N` means the JVM targets GC consuming `1/(N+1)` of total time. Default N=99 means <1% GC overhead target.

**Limitations:** All GC phases (both Minor and Major/Full) are fully STW. With large heaps (16GB+), Full GC pauses can be many seconds. This makes Parallel GC unsuitable for online, user-facing applications.

---

**Quick Revision Notes**

- Multi-threaded, fully STW. Default in Java 8.
- Maximizes throughput. Does not minimize individual pause times.
- Use for batch processing. Avoid for latency-sensitive services.
- `-XX:+UseParallelGC`, `-XX:ParallelGCThreads=N`.

---

### Q10. CMS (Concurrent Mark Sweep) — deprecated and removed.

**Difficulty:** Easy | **Interview Frequency:** Low  
**Companies:** Legacy codebase / migration interviews

---

**Short Answer (30–60 seconds)**

CMS was a mostly-concurrent collector for Old Generation, designed to reduce pause times by doing most marking work concurrently with application threads. It was deprecated in Java 9 and removed in Java 14. The key problem was heap fragmentation — CMS did not compact memory, leading to fragmentation over time and eventual `concurrent mode failure` (fallback to full STW compaction). G1 GC replaced CMS as the low-pause-time default.

---

**Deep Explanation**

**CMS collection phases:**
1. **Initial Mark (STW):** Mark objects directly reachable from GC roots.
2. **Concurrent Mark:** Traverse object graph concurrently with application threads.
3. **Concurrent Preclean:** Clean up changes from step 2 (concurrent).
4. **Remark (STW):** Final marking pass to catch mutations during concurrent mark.
5. **Concurrent Sweep:** Reclaim dead objects (concurrent, no compaction).
6. **Concurrent Reset:** Reset data structures.

**Problems:**
- **No compaction:** Free memory returned to free lists, causing fragmentation over time.
- **Concurrent mode failure:** If Old Gen fills up while CMS is running (not keeping up with allocation rate), JVM falls back to Serial Full GC — a very long STW pause.
- **Floating garbage:** Objects that become unreachable during concurrent mark are not collected until the next cycle.
- **CPU overhead:** Concurrent phases consume CPU, reducing application throughput.

**Modern alternative:** G1 GC or ZGC. Never tune CMS in new systems; it is removed in Java 14.

---

**Quick Revision Notes**

- CMS: mostly concurrent, no compaction. Deprecated Java 9, removed Java 14.
- Key problem: fragmentation + `concurrent mode failure` → STW fallback.
- Replaced by G1 GC. Never use in Java 14+.

---

### Q11. G1 GC — the default collector since Java 9.

**Difficulty:** Hard | **Interview Frequency:** Very High  
**Companies:** Amazon, Google, Goldman Sachs, Netflix, Stripe, Uber, Morgan Stanley

---

**Short Answer (30–60 seconds)**

G1 (Garbage First) GC divides the heap into equal-sized regions rather than contiguous generations. It targets predictable pause times via `-XX:MaxGCPauseMillis`. G1 uses concurrent marking to identify garbage density across regions, then collects the regions with the most garbage first — hence "Garbage First." It is the default GC since Java 9 and handles heaps from 6GB to 100GB+ well.

---

**Deep Explanation**

**Region-based heap:**
```
Heap (e.g., 8GB, region size = 8MB = 1024 regions)
[ E ][ E ][ E ][ S ][ O ][ O ][ H ][ H ][ E ][ O ][ E ][ S ]...
  E=Eden  S=Survivor  O=Old  H=Humongous  (free regions not shown)
```

Each region is 1–32MB (JVM chooses size based on heap size, targeting ~2048 regions). Regions are dynamically assigned roles: Eden, Survivor, Old, or Humongous.

**G1 Collection Cycle:**

1. **Young Collection (Minor GC, STW):**
   - Evacuates Eden and Survivor regions.
   - Promotes objects to Survivor or Old regions based on age.
   - Pause time bounded by `-XX:MaxGCPauseMillis` (default 200ms).

2. **Concurrent Marking Cycle:**
   Triggered when heap occupancy exceeds `-XX:InitiatingHeapOccupancyPercent` (default 45%).
   - **Initial Mark (STW, piggybacks on Young GC):** Marks GC root direct references.
   - **Root Region Scan (concurrent):** Scans Survivor regions for references into Old Gen.
   - **Concurrent Mark (concurrent):** Marks live objects across entire heap using SATB (Snapshot-At-The-Beginning) algorithm.
   - **Remark (STW):** Finalizes marking with SATB processing.
   - **Cleanup (STW briefly + concurrent):** Identifies fully dead regions, computes liveness of all regions, sorts regions by GC efficiency.

3. **Mixed GC (STW):**
   After concurrent marking, G1 runs "mixed" collections that include all Young regions PLUS selected Old regions (those with most garbage per region). This gradually reclaims Old Gen without a full collection.

4. **Full GC (fallback, STW, serial in Java 10-, parallel in Java 10+):**
   If G1 cannot keep up with allocation rate, falls back to Full GC. Should never happen in well-tuned applications.

**Remembered Sets (RSet):**
G1 maintains a per-region RSet tracking which other regions hold references into that region. This allows G1 to collect individual regions without scanning the entire heap for cross-region references.

**SATB (Snapshot-At-The-Beginning):**
G1 records the object graph snapshot at the start of concurrent marking. Objects that become unreachable during concurrent marking are treated as live (collected next cycle). This ensures no live objects are accidentally collected despite concurrent mutations.

**Humongous Objects:**
Objects larger than 50% of a region size are "humongous" and allocated across contiguous Humongous regions. They are collected during concurrent marking cleanup and can cause performance issues if frequent.

---

**Real-World Backend Example**

A Java-based trading system (Goldman Sachs-style) running a 32GB heap with G1 GC:
```
-Xms32g -Xmx32g
-XX:+UseG1GC
-XX:MaxGCPauseMillis=100
-XX:InitiatingHeapOccupancyPercent=35
-XX:G1HeapRegionSize=16m
-XX:G1ReservePercent=20
-XX:ConcGCThreads=4
-Xlog:gc*:file=/var/log/app/gc.log:time,uptime,level,tags:filecount=5,filesize=20m
```

`-XX:InitiatingHeapOccupancyPercent=35` triggers concurrent marking earlier, preventing Old Gen from filling too quickly and forcing Full GC.

---

**Java 17 Code Example**

```java
// JVM flags for G1 GC monitoring
// Run with: java -XX:+UseG1GC -Xms512m -Xmx512m
//              -Xlog:gc+heap=debug:stdout:time
//              -XX:MaxGCPauseMillis=50 GCDemo

public class G1GCDemo {
    private static final List<byte[]> oldGenObjects = new ArrayList<>();

    public static void main(String[] args) throws InterruptedException {
        // Simulate mixed short-lived and long-lived allocation
        for (int i = 0; i < 10_000; i++) {
            // Short-lived: dies in Young Gen
            byte[] temp = new byte[8192];
            processTemp(temp);

            // Long-lived every 100th iteration: promoted to Old Gen
            if (i % 100 == 0) {
                oldGenObjects.add(new byte[65536]);
            }

            if (i % 1000 == 0) {
                System.out.println("Iteration: " + i +
                    " | OldGen objects: " + oldGenObjects.size());
                Thread.sleep(10);
            }
        }
    }

    private static void processTemp(byte[] data) {
        // data is unreachable after this method returns
    }
}
```

---

**Follow-Up Questions**

- How does G1 guarantee pause time targets?
- What is `-XX:InitiatingHeapOccupancyPercent` and why would you lower it?
- What is a remembered set and why does G1 need one?
- When does G1 fall back to Full GC?
- What is the SATB algorithm?

---

**Common Mistakes**

- Saying G1 eliminates STW — it reduces STW duration but does not eliminate it.
- Setting `-XX:MaxGCPauseMillis` too low (e.g., 10ms) — G1 cannot guarantee this and may cause more frequent GCs or increased overhead.
- Forgetting that G1 Full GC is serial in Java 9 and parallel in Java 10+.

---

**Interview Traps**

- "What happens if G1 cannot meet the pause target?" — G1 makes best-effort; it is a soft goal. G1 may exceed the target if there is insufficient garbage to collect within the time budget.
- "How does G1 handle humongous objects?" — Allocated in contiguous Old-like Humongous regions. Frequent large allocations degrade G1 performance. Workaround: increase region size with `-XX:G1HeapRegionSize`.

---

**Quick Revision Notes**

- G1: region-based heap, concurrent marking, predictable pauses.
- `-XX:MaxGCPauseMillis` = soft pause target. `-XX:InitiatingHeapOccupancyPercent` = concurrent marking trigger.
- Remembered Sets track cross-region references. SATB ensures concurrent marking correctness.
- Mixed GC = Young + some Old regions. Avoids full Old Gen collection.

---

### Q12. ZGC — sub-millisecond pauses for very large heaps.

**Difficulty:** Hard | **Interview Frequency:** Medium  
**Companies:** Netflix, Goldman Sachs, trading systems, Atlassian, large-scale data platforms

---

**Short Answer (30–60 seconds)**

ZGC is a concurrent, region-based, compacting GC targeting sub-millisecond STW pauses regardless of heap size. Production-ready since Java 15. It uses colored pointers (extra bits in 64-bit object references) and load barriers to perform relocation concurrently with application threads. ZGC scales from small heaps to 16TB. Use it when pause times must be consistently below 1ms.

---

**Deep Explanation**

**Core Innovation: Colored Pointers**

ZGC stores GC metadata directly in object reference pointers (the 64-bit address). On 64-bit systems, only 42–48 bits are needed for addresses. ZGC uses the spare high bits:
- `Marked0` / `Marked1` bits: track mark state
- `Remapped` bit: indicates the pointer has been updated to an object's new location after relocation
- `Finalizable` bit: marks finalized references

**Load Barriers**

Every time application code loads an object reference from the heap, ZGC's load barrier checks the colored pointer. If the `Remapped` bit is not set (object has been relocated but pointer not yet updated), the barrier updates the pointer and fixes the reference in the heap before returning it to the application. This is the mechanism allowing concurrent relocation — applications never see stale pointers.

**ZGC Collection Phases:**

| Phase | STW/Concurrent | Notes |
|---|---|---|
| Pause Mark Start | STW (~1ms) | Mark GC roots |
| Concurrent Mark | Concurrent | Traverse object graph |
| Pause Mark End | STW (~1ms) | Finalize marking |
| Concurrent Process References | Concurrent | Soft/weak/phantom refs |
| Concurrent Select Relocation Set | Concurrent | Choose regions to compact |
| Pause Relocate Start | STW (~1ms) | Root relocation |
| Concurrent Relocate | Concurrent | Move objects, fix pointers |

Three STW pauses, each typically <1ms regardless of heap size. STW duration is proportional to GC root count, not heap size.

**When to use ZGC vs G1:**
- ZGC: latency-critical, consistent sub-ms pauses required, large heaps (>16GB), cost of load barriers acceptable
- G1: general purpose, moderate latency requirements (≤200ms pauses), heaps 4–64GB

---

**Real-World Backend Example**

A low-latency market data distribution system serving 50,000 subscribers with a 64GB cache heap. G1 GC produced occasional 150–300ms pauses during Mixed GC, causing downstream consumers to miss market data events. Migration to ZGC (`-XX:+UseZGC -Xms64g -Xmx64g`) reduced worst-case pause times from 300ms to <2ms, eliminating data loss events.

---

**Follow-Up Questions**

- What is the performance cost of ZGC load barriers?
- How does ZGC handle the GC root marking pause?
- What is the difference between ZGC and Shenandoah?

---

**Quick Revision Notes**

- ZGC: colored pointers + load barriers = concurrent relocation = sub-ms STW.
- Three STW pauses per cycle, all <1ms. Scales to 16TB.
- Enable: `-XX:+UseZGC`. Production since Java 15.
- Load barrier overhead: ~5–15% throughput reduction vs G1. Acceptable for latency-sensitive apps.

---

### Q13. Shenandoah GC — concurrent compaction, RedHat contribution.

**Difficulty:** Medium | **Interview Frequency:** Low  
**Companies:** RedHat shops, OpenJDK-heavy environments

---

**Short Answer (30–60 seconds)**

Shenandoah GC performs concurrent compaction using Brooks forwarding pointers instead of colored pointers. It was contributed by RedHat and is available in OpenJDK. Like ZGC, it targets sub-10ms pauses. Unlike ZGC, it places a forwarding pointer in each object header rather than using spare address bits, making it compatible with 32-bit compressed references.

---

**Deep Explanation**

**Brooks Pointers:** Each object gets an additional 8-byte header word (forwarding pointer). During normal operation, this points to the object itself. During relocation, it is updated to point to the new copy. All accesses go through this pointer, enabling concurrent relocation. Read and write barriers check the forwarding pointer.

**Comparison with ZGC:**
- Shenandoah: Brooks pointers (extra word per object, ~8% memory overhead), read+write barriers
- ZGC: colored pointers (no extra per-object memory), load barriers only
- Shenandoah supports compressed OOPs (CompressedOrdinaryObjectPointers, -XX:+UseCompressedOops); ZGC currently does not (though improving in recent JDK versions)

Enable: `-XX:+UseShenandoahGC` (OpenJDK builds, not Oracle JDK)

---

**Quick Revision Notes**

- Shenandoah: concurrent compaction via Brooks forwarding pointers. RedHat/OpenJDK.
- Sub-10ms pauses. ~8% memory overhead per object for forwarding pointer.
- Supports `-XX:+UseCompressedOops`. Available in OpenJDK, not Oracle JDK.

---

### Q14. GC tuning flags — the essential JVM flags for production.

**Difficulty:** Medium | **Interview Frequency:** High  
**Companies:** Amazon, Goldman Sachs, any company asking about production JVM configuration

---

**Short Answer (30–60 seconds)**

The most critical GC flags are `-Xms` and `-Xmx` for heap size, `-XX:+UseG1GC` for collector selection, `-XX:MaxGCPauseMillis` for G1 pause target, `-Xlog:gc*` for GC logging, and `-XX:+HeapDumpOnOutOfMemoryError` for OOM diagnostics. Starting `-Xms` equal to `-Xmx` prevents heap resize pauses and GC ergonomics fluctuation.

---

**Deep Explanation**

**Heap Sizing:**
```bash
-Xms4g              # Initial heap size (set equal to Xmx in production)
-Xmx4g              # Maximum heap size
-Xmn1g              # Young generation size (explicit; alternative: -XX:NewRatio=3)
-XX:NewRatio=3       # Old:Young ratio = 3:1, so Young = 25% of heap
-XX:SurvivorRatio=8  # Eden:Survivor ratio; Eden = 8/(8+1+1) = 80% of Young
```

**Collector Selection:**
```bash
-XX:+UseG1GC         # G1 GC (default Java 9+)
-XX:+UseZGC          # ZGC (Java 15+ production-ready)
-XX:+UseShenandoahGC # Shenandoah (OpenJDK)
-XX:+UseParallelGC   # Parallel GC (batch workloads)
-XX:+UseSerialGC     # Serial GC (small heaps, single CPU)
```

**G1-specific:**
```bash
-XX:MaxGCPauseMillis=200        # Soft pause target
-XX:G1HeapRegionSize=16m        # Region size (1–32MB, 2048 regions ideal)
-XX:InitiatingHeapOccupancyPercent=45  # Trigger concurrent marking
-XX:G1ReservePercent=10         # Reserve for promotion overflow
-XX:ConcGCThreads=4             # Concurrent GC thread count
-XX:ParallelGCThreads=8         # STW GC thread count
```

**GC Logging (Java 9+ unified logging):**
```bash
-Xlog:gc:stdout:time                          # Basic GC log to stdout
-Xlog:gc*:file=/var/log/gc.log:time,uptime,level,tags:filecount=5,filesize=20m
```

**Diagnostics:**
```bash
-XX:+HeapDumpOnOutOfMemoryError    # Auto dump on OOM
-XX:HeapDumpPath=/var/dumps/       # Dump location
-XX:OnOutOfMemoryError="kill -9 %p" # Restart on OOM (containerized apps)
```

**Metaspace:**
```bash
-XX:MetaspaceSize=256m        # Initial Metaspace size (first GC trigger)
-XX:MaxMetaspaceSize=512m     # Hard cap
```

---

**Production Template (G1 GC, 8GB heap):**
```bash
java \
  -Xms8g -Xmx8g \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:InitiatingHeapOccupancyPercent=40 \
  -XX:G1HeapRegionSize=8m \
  -XX:G1ReservePercent=15 \
  -XX:ConcGCThreads=2 \
  -XX:+HeapDumpOnOutOfMemoryError \
  -XX:HeapDumpPath=/var/dumps/ \
  -Xlog:gc*:file=/var/log/gc.log:time,uptime,level,tags:filecount=5,filesize=20m \
  -XX:MetaspaceSize=256m \
  -XX:MaxMetaspaceSize=512m \
  -jar application.jar
```

---

**Quick Revision Notes**

- Set `-Xms` = `-Xmx` in production to avoid heap resizing overhead.
- `-XX:MaxGCPauseMillis` is G1's soft goal, not a hard guarantee.
- `-Xlog:gc*` replaces `-verbose:gc` and `-XX:+PrintGCDetails` in Java 9+.
- Always set `-XX:+HeapDumpOnOutOfMemoryError` in production.

---

### Q15. Memory leaks in Java — causes, diagnosis, and prevention.

**Difficulty:** Hard | **Interview Frequency:** Very High  
**Companies:** Amazon, Google, Goldman Sachs, every senior Java interview

---

**Short Answer (30–60 seconds)**

Memory leaks in Java occur when objects remain reachable through GC roots even though the application no longer needs them. Common causes: static collections that grow without bound, ThreadLocal values not removed after request completion, event listeners and callbacks never deregistered, unclosed streams or database connections, inner classes holding implicit outer class references, and classloader leaks in application servers.

---

**Deep Explanation**

**1. Static Collections Growing Without Bound**
```java
// LEAK: 'cache' is a GC root (static field), objects never removed
public class LeakyCache {
    private static final Map<String, byte[]> CACHE = new HashMap<>();
    
    public static void store(String key, byte[] data) {
        CACHE.put(key, data); // grows forever
    }
}
// Fix: Use WeakHashMap, Caffeine/Guava cache with eviction, or explicit remove()
```

**2. ThreadLocal Leaks (critical in servlet containers)**
```java
// LEAK: ThreadLocal value not removed, thread is pooled (not destroyed)
public class RequestContext {
    private static final ThreadLocal<UserSession> SESSION = new ThreadLocal<>();
    
    public static void set(UserSession session) {
        SESSION.set(session); // set on request start
    }
    
    // MISSING: SESSION.remove() in finally block after request handling
    // Thread returns to pool with SESSION still set
    // Next request gets stale (or wrong user's) session
}

// Fix:
try {
    SESSION.set(session);
    processRequest();
} finally {
    SESSION.remove(); // ALWAYS clean up in finally
}
```

**3. Listeners and Callbacks Not Deregistered**
```java
// LEAK: EventBus holds strong reference to listener
// If listener is a per-request object that is never deregistered:
eventBus.register(listener);
// ... request processing ...
// MISSING: eventBus.unregister(listener)
// listener object cannot be GC'd — eventBus is a long-lived static object

// Fix: Always unregister in finally/dispose/close
```

**4. Unclosed Streams and Connections**
```java
// LEAK: Connection not returned to pool / stream not closed
public void readData() throws IOException {
    InputStream is = new FileInputStream("/data/file");
    // ... if exception thrown before close() ...
    is.close(); // never reached
}

// Fix: try-with-resources
public void readData() throws IOException {
    try (InputStream is = new FileInputStream("/data/file")) {
        // auto-closed on exit
    }
}
```

**5. Inner Classes Holding Outer Class References**
```java
// LEAK: Anonymous Runnable holds implicit reference to outer instance
public class RequestHandler {
    private byte[] largeBuffer = new byte[10 * 1024 * 1024]; // 10MB
    
    public void submitAsync() {
        executor.submit(new Runnable() {
            @Override
            public void run() {
                // This anonymous class holds implicit reference to RequestHandler.this
                // largeBuffer cannot be GC'd as long as this task is queued/running
            }
        });
    }
}

// Fix: Use static nested class or lambda with explicit parameter capture
```

**6. Classloader Leaks in Application Servers**
Hot-redeploy in Tomcat/JBoss: The old application's classloader should be GC'd after redeploy. If any long-lived object in the server (JDBC driver, logging framework static fields, JVM-wide caches) holds a reference to a class loaded by the application's classloader, the entire classloader (and all its classes) cannot be GC'd. This is the classic PermGen/Metaspace leak in application servers.

Fix: Use JDBC driver deregistration on shutdown, avoid storing application classloader-loaded objects in container-level statics.

---

**Diagnosis Workflow:**

1. Observe `java.lang.OutOfMemoryError: Java heap space` or steadily rising heap in monitoring.
2. Enable GC logging; if full GCs become frequent and heap does not drop, suspect leak.
3. Capture heap dump: `jmap -dump:format=b,file=heap.hprof <pid>` or `-XX:+HeapDumpOnOutOfMemoryError`.
4. Analyze with Eclipse MAT (Memory Analyzer Tool): "Leak Suspects Report" identifies the largest retained object sets and their reference chains.
5. Look for: largest retained heap by class, unexpected collections (HashMap, ArrayList) with millions of entries, ThreadLocal instances in retained heap.

---

**Quick Revision Notes**

- Leaks = reachable but unused objects. GC cannot collect reachable objects.
- Top causes: static collections, ThreadLocal (servlet containers), listeners, unclosed resources, inner classes.
- Diagnosis: GC logs → heap dump → Eclipse MAT / VisualVM.
- Prevention: try-with-resources, ThreadLocal.remove(), listener lifecycle management, weak references for caches.

---

## 3. Class Loading

---

### Q16. Explain the classloader hierarchy.

**Difficulty:** Medium | **Interview Frequency:** High  
**Companies:** Amazon, Goldman Sachs, Atlassian, application server vendors, OSGi/plugin framework interviews

---

**Short Answer (30–60 seconds)**

Java uses a hierarchical classloader system. The Bootstrap ClassLoader (built into JVM, loads core Java classes from `java.base`), the Platform ClassLoader (formerly Extension, loads Java SE platform classes in Java 9+ modules), and the Application ClassLoader (loads classes from the application classpath) form the default hierarchy. Each classloader delegates to its parent before attempting to load a class itself.

---

**Deep Explanation**

**Classloader Hierarchy (Java 9+ with JPMS):**

```
Bootstrap ClassLoader (native, loads java.base module)
        |
Platform ClassLoader (formerly Extension ClassLoader, loads Java SE modules)
        |
Application ClassLoader / System ClassLoader (loads app classpath)
        |
[Custom ClassLoaders] (e.g., per webapp in Tomcat, OSGi bundles)
```

**Bootstrap ClassLoader:**
- Implemented in native code (C++), not a Java class.
- Loads `java.lang.*`, `java.util.*`, and all modules in `java.base`.
- In Java 9+: loads modules listed in the boot layer.
- `String.class.getClassLoader()` returns `null` — the bootstrap loader has no Java representation.

**Platform ClassLoader (Java 9+, was Extension ClassLoader in Java 8):**
- Loads Java SE platform modules not in `java.base` (e.g., `java.sql`, `java.xml`, `java.desktop`).
- In Java 8: Extension ClassLoader loaded JARs from `JAVA_HOME/lib/ext`.
- In Java 9+: Java modules replaced the extension mechanism.

**Application ClassLoader:**
- Loads classes from `-classpath` / `-cp` / `CLASSPATH` environment variable.
- The default classloader for application code.
- `MyClass.class.getClassLoader()` typically returns this loader.

---

**Quick Revision Notes**

- Bootstrap (native) → Platform → Application classloader chain.
- Bootstrap loads `java.base`; Platform loads Java SE modules; App loads classpath.
- `String.class.getClassLoader() == null` (bootstrap has no Java representation).
- Java 9+: Extension ClassLoader renamed to Platform ClassLoader; module system changes extension mechanism.

---

### Q17. Explain the class loading process — Loading, Linking, Initialization.

**Difficulty:** Medium | **Interview Frequency:** High  
**Companies:** Goldman Sachs, Amazon, Morgan Stanley

---

**Short Answer (30–60 seconds)**

Class loading has three phases: Loading (find and read the `.class` file, create a `Class` object), Linking (verify bytecode correctness, prepare static fields, optionally resolve symbolic references), and Initialization (execute static initializer blocks and assign static field values). Initialization is lazy — a class is initialized only when first actively used.

---

**Deep Explanation**

**1. Loading:**
- Find the binary `.class` file via the classloader hierarchy.
- Read bytecode into memory.
- Create a `java.lang.Class` object on the heap representing the class.
- The `Class` object itself lives on the heap; its structural metadata (method bytecode, field descriptors) lives in Metaspace.

**2. Linking — three sub-phases:**

*Verification:*
- Bytecode verifier checks the class file for structural correctness.
- Checks: valid magic number (0xCAFEBABE), correct constant pool entries, valid bytecode instructions, type safety.
- Prevents malformed or malicious bytecode from being executed.
- Can be disabled with `-Xverify:none` (dangerous — never in production).

*Preparation:*
- Allocates memory for class (static) variables.
- Sets them to **default zero values**: `0`, `0.0`, `false`, `null`.
- Does NOT execute any Java code; just allocates memory with defaults.

*Resolution (optional — may be lazy):*
- Resolves symbolic references in the constant pool to direct memory references.
- Example: replaces the symbolic reference `java/util/ArrayList` with the actual `Class` pointer.
- Lazy resolution: the JVM may delay until first use.

**3. Initialization:**
- Execute the class's static initializer blocks (`static { ... }`) in textual order.
- Assign static field values to their declared initializers (e.g., `static int MAX = 100;`).
- Triggers (active uses that force initialization):
  - Creating an instance (`new`)
  - Accessing/modifying a static field
  - Calling a static method
  - Reflection: `Class.forName("ClassName")`
  - Initializing a subclass (forces parent class initialization)
  - JVM main class
- Initialization is thread-safe: the JVM uses class-level locking to ensure `<clinit>` runs exactly once. This is exploited by the Initialization-on-Demand Holder idiom for thread-safe lazy singletons.

---

**Java 17 Code Example**

```java
// Demonstrating initialization order and lazy loading
public class ClassLoadingDemo {

    // Holder pattern: LazyHolder class not initialized until getInstance() called
    private static class LazyHolder {
        // Initialized only when LazyHolder is first accessed
        private static final ClassLoadingDemo INSTANCE = new ClassLoadingDemo();
        
        static {
            System.out.println("LazyHolder initialized"); // thread-safe, runs once
        }
    }

    private ClassLoadingDemo() {
        System.out.println("ClassLoadingDemo constructed");
    }

    public static ClassLoadingDemo getInstance() {
        return LazyHolder.INSTANCE; // triggers LazyHolder initialization
    }

    static {
        System.out.println("ClassLoadingDemo static initializer");
    }
}

// Output when ClassLoadingDemo.getInstance() is first called:
// ClassLoadingDemo static initializer
// LazyHolder initialized
// ClassLoadingDemo constructed
```

---

**Follow-Up Questions**

- What is the difference between `Class.forName()` and `ClassLoader.loadClass()`?
- When does `ExceptionInInitializerError` occur?
- Is static initialization thread-safe?

---

**Common Mistakes**

- Confusing Preparation (zero-initialization) with Initialization (declared values) — static field `int MAX = 100` gets value `0` after Preparation, `100` after Initialization.
- Saying `Class.forName()` and `ClassLoader.loadClass()` are equivalent — `Class.forName()` initializes the class (runs static blocks); `loadClass()` does not trigger initialization.

---

**Quick Revision Notes**

- Loading → Linking (Verify + Prepare + Resolve) → Initialize.
- Preparation: zero-initialize statics. Initialization: run static blocks, set declared values.
- Initialization is lazy and thread-safe (JVM-level locking on `<clinit>`).
- `Class.forName()` = load + initialize. `ClassLoader.loadClass()` = load only.

---

### Q18. Parent delegation model — why it exists and when to break it.

**Difficulty:** Medium | **Interview Frequency:** Medium  
**Companies:** Application server / OSGi / plugin framework interviews

---

**Short Answer (30–60 seconds)**

The parent delegation model means a classloader always asks its parent to load a class first before attempting to load it itself. This ensures core Java classes like `java.lang.String` are always loaded by the Bootstrap ClassLoader, preventing malicious code from substituting a fake `String` class. It also ensures class consistency: one class object per classloader hierarchy for a given class name.

---

**Deep Explanation**

**Delegation algorithm:**
```
ClassLoader.loadClass(String name):
1. Check if class already loaded (findLoadedClass)
2. If not: delegate to parent classloader (parent.loadClass)
3. If parent returns null / throws ClassNotFoundException: call findClass(name)
4. Return the loaded class
```

**Why it exists:**
- **Security:** Prevents application code from overriding `java.lang.*`. If you put a fake `java/lang/String.class` on the classpath, the Application ClassLoader delegates to Bootstrap first, which loads the real `String`. Your fake class is never loaded for `java.lang.String`.
- **Consistency:** All classes in the JVM are identified by (classloader, fully-qualified name). Two classes with the same name loaded by different classloaders are different types. Delegation ensures that library classes shared between components are loaded exactly once.

**When to break parent delegation:**
- **OSGi (Eclipse plugin system):** Each bundle has its own classloader with its own dependencies. A bundle may need `com.example.Foo v1.0` while another needs `v2.0`. The framework must intercept delegation to provide version-specific resolution.
- **Application servers (Tomcat, JBoss):** Each web application gets its own classloader that loads its own copies of framework JARs (Spring, Hibernate) to isolate apps. Child-first loading (application classloader tries before parent) is used.
- **Hot-reload / dynamic plugin systems:** Load a new version of a class while the old version is still running (different classloader instance = different class identity).

**Breaking delegation — override `loadClass()`:**
```java
@Override
public Class<?> loadClass(String name) throws ClassNotFoundException {
    // Child-first: try to load locally before delegating
    if (isAppClass(name)) {
        try {
            return findClass(name); // load from this classloader's source
        } catch (ClassNotFoundException ignored) {}
    }
    return super.loadClass(name); // fall back to parent delegation
}
```

---

**Quick Revision Notes**

- Parent delegation: ask parent first, load locally only if parent fails.
- Prevents core class override, ensures class consistency.
- Break it for: OSGi, app server isolation, hot-reload, plugin systems.
- Override `loadClass()` for child-first loading (not `findClass()`).

---

### Q19. Custom ClassLoader — use cases and implementation.

**Difficulty:** Hard | **Interview Frequency:** Medium  
**Companies:** Platform/framework engineers, OSGi/plugin specialists

---

**Short Answer (30–60 seconds)**

Custom classloaders are written when you need to load classes from non-standard sources: network, database, encrypted JARs, dynamically generated bytecode, or to implement isolation/hot-reload. Override `findClass()` to provide custom class loading while preserving parent delegation, or override `loadClass()` to implement child-first delegation for isolation.

---

**Java 17 Code Example**

```java
import java.io.*;
import java.nio.file.*;

public class FileSystemClassLoader extends ClassLoader {

    private final Path classDir;

    public FileSystemClassLoader(Path classDir, ClassLoader parent) {
        super(parent);
        this.classDir = classDir;
    }

    // Override findClass — called when parent delegation fails
    // Preserves parent delegation model
    @Override
    protected Class<?> findClass(String name) throws ClassNotFoundException {
        String fileName = name.replace('.', '/') + ".class";
        Path classFile = classDir.resolve(fileName);

        if (!Files.exists(classFile)) {
            throw new ClassNotFoundException("Class not found: " + name);
        }

        try {
            byte[] classBytes = Files.readAllBytes(classFile);
            // defineClass: hands bytecode to JVM for Linking + Initialization
            return defineClass(name, classBytes, 0, classBytes.length);
        } catch (IOException e) {
            throw new ClassNotFoundException("Error loading class: " + name, e);
        }
    }

    // Hot-reload: create a NEW ClassLoader instance for each reload
    public static Class<?> hotReload(String className, Path classDir) 
            throws ClassNotFoundException {
        // New classloader instance = new class identity = hot reload
        ClassLoader loader = new FileSystemClassLoader(classDir, 
            ClassLoader.getSystemClassLoader().getParent());
        return loader.loadClass(className);
    }
}
```

**Usage:**
```java
ClassLoader loader = new FileSystemClassLoader(
    Path.of("/app/plugins"), 
    ClassLoader.getSystemClassLoader()
);
Class<?> pluginClass = loader.loadClass("com.example.MyPlugin");
Object instance = pluginClass.getDeclaredConstructor().newInstance();
```

---

**Quick Revision Notes**

- Override `findClass()` for standard custom loading (preserves delegation).
- Override `loadClass()` only when you need to break parent delegation (isolation/child-first).
- `defineClass()` converts raw bytecode into a JVM `Class` object.
- Hot-reload = new ClassLoader instance for each version of the class.

---

## 4. JIT Compiler

---

### Q20. Interpretation vs JIT compilation — the performance model.

**Difficulty:** Easy | **Interview Frequency:** Medium  
**Companies:** Google, Amazon, performance-focused interviews

---

**Short Answer (30–60 seconds)**

The JVM starts by interpreting bytecode instruction by instruction, which is portable but slow (10–100x slower than native code). As the JVM identifies "hot" methods (executed frequently), the JIT compiler compiles them to optimized native machine code. After JIT compilation, subsequent calls to that method execute native code at near-C performance. The tradeoff: cold start is slow; warmed-up Java is fast.

---

**Deep Explanation**

**Bytecode vs Machine Code:**
Java source → `javac` → bytecode (platform-independent `.class`) → JVM interpreter → (for hot methods) → JIT compiler → native machine code (CPU-specific)

**JIT compilation trigger:**
The JVM counts method invocations and loop back-edges. When a method or loop reaches the "compilation threshold" (configurable, default ~10,000 invocations), it is submitted to the JIT compiler. The JIT compiler runs on a background thread; the method continues interpreting until JIT compilation finishes.

**Tiered compilation (Java 8+, default):**
- **Level 0:** Pure interpreter (all methods start here)
- **Level 1:** C1-compiled, no profiling (for trivially simple methods)
- **Level 2:** C1-compiled, limited profiling
- **Level 3:** C1-compiled, full profiling (counting invocations, branch frequencies, type profiles)
- **Level 4:** C2-compiled, maximum optimization (using profiling data from Level 3)

Most methods cycle through Level 0 → 3 → 4. Short methods may stay at Level 1. Deoptimization returns a method from Level 4 to Level 0 when assumptions (e.g., monomorphic call sites) are invalidated.

---

**Quick Revision Notes**

- Interpreter: portable, slow. JIT: compiles hot methods to native, fast after warmup.
- Tiered compilation: C1 (fast compile) → C2 (aggressive optimization with profiling).
- JIT threshold: ~10,000 invocations for server compiler.
- Deoptimization: JIT reverts to interpreter when assumptions are violated.

---

### Q21. Tiered compilation — C1, C2, and the five levels.

**Difficulty:** Medium | **Interview Frequency:** Medium  
**Companies:** Performance-focused interviews, JVM internals specialists

---

**Short Answer (30–60 seconds)**

Tiered compilation uses two JIT compilers. C1 (client compiler) compiles quickly with light optimization, useful for methods that need to be compiled fast but don't justify heavy optimization. C2 (server compiler) applies aggressive optimizations using profiling data gathered at C1 level, producing the fastest possible native code. Most server JVMs use both: C1 for quick initial compilation, C2 for heavily-used methods.

---

**Deep Explanation**

**C1 (Client Compiler):**
- Fast compilation, minimal optimization.
- Instruments code to collect profile data (type profiles for virtual calls, branch frequencies).
- Methods at Level 1–3.
- Startup latency vs C2: minutes faster in large applications.

**C2 (Server Compiler):**
- Slow compilation, aggressive optimization.
- Uses profiling data from C1 to make assumptions (e.g., this virtual call only ever dispatches to one implementation).
- Can inline, unroll loops, eliminate allocations, remove dead branches.
- Methods at Level 4.
- Output: highly optimized machine code, often competitive with hand-written C.

**Deoptimization:**
If a C2 assumption is violated (a second implementation of an interface is loaded), the JVM "deoptimizes" — reverts the method to the interpreter or C1, recompiles with updated profile. This is transparent but causes brief latency spikes. Visible in JVM logs as "uncommon trap" or "deoptimization."

**GraalVM/JIT in Java 17:**
Java 17 ships with JVMCI (JVM Compiler Interface), allowing alternative JIT compilers. The Graal JIT (written in Java) is available via GraalVM or JVM flags: `-XX:+UseJVMCICompiler`.

---

**Quick Revision Notes**

- C1: fast compile, light optimization, gathers profiling data. Levels 1–3.
- C2: slow compile, aggressive optimization using C1 profiles. Level 4.
- Tiered compilation default since Java 8. Disable with `-XX:-TieredCompilation`.
- Deoptimization: JIT reverts to interpreter when assumptions fail.

---

### Q22. HotSpot JIT optimizations — inlining, escape analysis, loop unrolling.

**Difficulty:** Hard | **Interview Frequency:** Medium  
**Companies:** Google, Goldman Sachs, high-performance Java interviews

---

**Short Answer (30–60 seconds)**

The JIT compiler applies several key optimizations. Method inlining replaces a method call with the method body directly, eliminating call overhead and enabling further optimization. Escape analysis determines whether an object reference "escapes" the current method — if not, the object can be stack-allocated instead of heap-allocated, eliminating GC pressure. Loop unrolling reduces loop overhead by duplicating the loop body.

---

**Deep Explanation**

**Method Inlining:**
```java
// Before inlining:
int result = add(a, b);

// After inlining (C2 may inline if method is small and hot):
int result = a + b; // call overhead eliminated, enables further optimization
```
Inlining is the most impactful JIT optimization. It enables constant folding, dead code elimination, and better register allocation. The JIT inlines methods up to a certain size (`-XX:MaxInlineSize=35` bytecodes by default for trivial methods, `-XX:FreqInlineSize=325` for hot methods).

**Escape Analysis:**
The JIT analyzes whether an object reference can "escape" the current method or thread:
- **No escape (stack allocation):** Object never passed to another method, field, or thread. JIT can allocate it on the stack → no heap allocation, no GC pressure.
- **Argument escape:** Object passed to another method but does not escape beyond the call. JIT can still optimize aggressively.
- **Global escape:** Object stored in a field, returned, or shared with another thread. Must heap-allocate normally.

```java
// Escape analysis example: Point may be stack-allocated
public double distance(double x1, double y1, double x2, double y2) {
    Point delta = new Point(x2 - x1, y2 - y1); // may be stack-allocated
    return Math.sqrt(delta.x * delta.x + delta.y * delta.y);
    // delta does not escape this method
}
```

**Lock Elision (enabled by escape analysis):**
If a synchronized object does not escape the current thread, JIT removes the synchronization entirely.
```java
public String buildMessage() {
    // StringBuffer is synchronized, but doesn't escape this method
    StringBuffer sb = new StringBuffer(); // lock elided by JIT
    sb.append("Hello").append(" World");
    return sb.toString();
}
```

**Loop Unrolling:**
```java
// Original loop (4 iterations):
for (int i = 0; i < 4; i++) sum += array[i];

// After unrolling (eliminates loop overhead: counter increment, branch):
sum += array[0]; sum += array[1]; sum += array[2]; sum += array[3];
```

---

**Quick Revision Notes**

- Inlining: replaces method call with body. Most impactful JIT optimization.
- Escape analysis: object not escaping method = stack allocation = no GC.
- Lock elision: synchronized on non-escaping object = locks removed.
- Loop unrolling: eliminates loop overhead by duplicating body.

---

### Q23. JIT warmup — the cold start problem.

**Difficulty:** Medium | **Interview Frequency:** High  
**Companies:** Netflix, Amazon (Lambda/serverless), Stripe, any cloud/container discussion

---

**Short Answer (30–60 seconds)**

JVM applications start in interpreted mode and reach peak performance only after hot methods are identified and JIT-compiled — typically after 30 seconds to 5 minutes for large applications. This "warmup" period means the JVM runs slower than its peak throughput at startup. In serverless and container environments, cold starts cause this warmup problem to repeat frequently, degrading P99 latency.

---

**Deep Explanation**

**Warmup timeline for a typical Spring Boot microservice:**
```
T=0s:   JVM starts, classes loaded, interpreter running
T=5s:   C1 compilation starts for frequently-called methods
T=30s:  C2 compilation starts for hottest methods
T=2min: Most critical paths JIT-compiled; near-peak performance
T=5min: Full peak performance reached for all paths
```

**Cloud-native cold start problem:**
- Kubernetes auto-scaling: new pod spins up under load, starts in interpreted mode, receives traffic before warmup completes → elevated latency during warmup.
- Serverless (AWS Lambda, Google Cloud Run): function container recycled after idle period → every invocation after recycling starts cold.
- GraalVM Native Image: compiles Java to ahead-of-time (AOT) native binary → instant startup, no warmup — at the cost of JIT's runtime profiling optimizations.

**Mitigation strategies:**
1. **GraalVM Native Image:** AOT compilation. Spring Boot 3 / Quarkus / Micronaut support native image. Tradeoffs: longer build time, no dynamic class loading, smaller peak throughput than JIT.
2. **Class Data Sharing (CDS):** `-XX:+UseAppCDS` saves loaded class metadata to a shared archive, reducing class loading time on subsequent startups.
3. **JVM warmup in staging:** Run synthetic load against new pods before routing production traffic (warmup / canary deployment).
4. **Ahead-of-time compilation (Java 9+ AOT):** Limited AOT via `jaotc` (deprecated in Java 17; superseded by GraalVM).
5. **Persistent Code Cache:** JVM can save/restore Code Cache across restarts in some configurations.

---

**Real-World Backend Example**

Netflix's edge service (Zuul/Envoy) runs on thousands of JVM instances. Without warmup strategies, rolling deploys caused P99 latency spikes as new instances handled traffic in interpreted mode. Netflix implemented:
- Synthetic "training traffic" replayed to new instances before shifting load.
- CDS archives to reduce class loading time by 30%.
- Monitoring warmup completion via JMX metrics on JIT compilation activity.

---

**Quick Revision Notes**

- JVM starts slow (interpreter), gets fast (JIT), reaches peak after 1–5 minutes.
- Cold start = restarting this warmup cycle. Critical for serverless/auto-scaling.
- GraalVM Native Image = AOT compilation → instant start, no warmup needed.
- CDS = shared class metadata archive → faster startup (not warmup, just loading).

---

## 5. Practical Diagnostics

---

### Q24. OutOfMemoryError types — meaning and diagnosis.

**Difficulty:** Medium | **Interview Frequency:** Very High  
**Companies:** Amazon, Goldman Sachs, Stripe, Netflix — universal senior-level question

---

**Short Answer (30–60 seconds)**

`OutOfMemoryError` has several variants, each indicating a different failure: `Java heap space` means the heap is exhausted; `GC overhead limit exceeded` means GC is running constantly with little reclamation; `Metaspace` means class metadata space is exhausted; `unable to create native thread` means OS cannot create more threads; `Direct buffer memory` means off-heap NIO buffer space is exhausted.

---

**Deep Explanation**

**1. `OutOfMemoryError: Java heap space`**
- Cause: Heap exhausted — all GC cycles fail to free sufficient memory.
- Investigation: Heap dump + MAT analysis. Look for large retained object graphs.
- Common causes: memory leaks (static collections, ThreadLocal), cache without eviction, large batch operations loading entire dataset into memory.
- Fix: Increase `-Xmx` (short term), fix memory leak (long term).

**2. `OutOfMemoryError: GC overhead limit exceeded`**
- Cause: JVM is spending >98% of CPU time on GC and recovering <2% of heap per GC cycle.
- Indicates: effective heap exhaustion — there is heap space, but GC cannot reclaim it fast enough.
- Investigation: Same as heap space OOM — likely a memory leak.
- Disable (never in production): `-XX:-UseGCOverheadLimit`.

**3. `OutOfMemoryError: Metaspace`**
- Cause: Class metadata space (Metaspace) exhausted.
- Investigation: Check for excessive class generation (Spring CGLIB, dynamic proxies, Groovy scripts, JSPs, classloader leaks).
- Fix: `-XX:MaxMetaspaceSize=512m` (increase cap); fix classloader leaks (hot-undeploy classloader not GC'd).

**4. `OutOfMemoryError: unable to create native thread`**
- Cause: OS thread limit reached — cannot create more threads.
- Common causes: unbounded thread creation (thread per request without pooling), default thread stack size too large consuming virtual address space.
- Investigation: `ulimit -u` (Linux per-user process/thread limit), `cat /proc/sys/kernel/threads-max`.
- Fix: Use thread pools, reduce `-Xss` (stack per thread size), increase OS thread limit.

**5. `OutOfMemoryError: Direct buffer memory`**
- Cause: Direct `ByteBuffer` allocation (off-heap, outside JVM heap) exceeds limit.
- Common in: Netty, NIO servers, Kafka clients (producer/consumer buffers).
- Default limit: `-XX:MaxDirectMemorySize` defaults to `-Xmx` value.
- Fix: Increase `-XX:MaxDirectMemorySize`, fix buffer leak (DirectBuffer not explicitly freed, reliant on GC finalization which is delayed).

---

**Quick Revision Notes**

- `Java heap space`: heap full, leak or undersized heap.
- `GC overhead limit exceeded`: GC running constantly, heap effectively full.
- `Metaspace`: class metadata exhausted, classloader leak or too many dynamic classes.
- `unable to create native thread`: OS thread limit, unbounded thread creation.
- `Direct buffer memory`: NIO direct buffers leak, increase `-XX:MaxDirectMemorySize`.

---

### Q25. Heap dump analysis — capturing and diagnosing memory issues.

**Difficulty:** Hard | **Interview Frequency:** High  
**Companies:** Goldman Sachs, Amazon, Morgan Stanley, any senior Java role

---

**Short Answer (30–60 seconds)**

Heap dump analysis captures a snapshot of all live objects in the heap to identify memory leaks. Capture with `jmap -dump:format=b,file=heap.hprof <pid>` or automatically via `-XX:+HeapDumpOnOutOfMemoryError`. Analyze with Eclipse MAT: the "Leak Suspects Report" finds the largest retained object graphs and traces the reference chain keeping them alive.

---

**Deep Explanation**

**Capturing heap dumps:**
```bash
# Live process (JVM must be running)
jmap -dump:format=b,file=/tmp/heap.hprof <pid>

# Live objects only (smaller file, triggers GC first)
jmap -dump:live,format=b,file=/tmp/heap-live.hprof <pid>

# Automatic on OOM (add to JVM startup flags)
-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/var/dumps/

# Using jcmd (Java 9+, preferred)
jcmd <pid> GC.heap_dump /tmp/heap.hprof
```

**Analysis with Eclipse MAT:**
1. Open heap.hprof in MAT.
2. **Leak Suspects Report:** Automatically identifies objects with unusually large retained heap. The "retained heap" of an object = the total heap freed if that object and its transitive reference graph were collected.
3. **Dominator Tree:** Shows objects dominating the most retained heap. Sorted by retained heap size.
4. **OQL (Object Query Language):** SQL-like queries against heap objects. Example: `SELECT * FROM java.util.HashMap WHERE size > 10000`
5. **Reference Chains:** From a suspected leak object, trace the "shortest path to GC roots" — this shows exactly which root is keeping the object alive.

**What to look for:**
- `java.util.HashMap`, `ArrayList`, `ConcurrentHashMap` with millions of entries
- `ThreadLocal` instances retained in large thread pool thread stacks
- `ClassLoader` instances with large retained Metaspace
- Framework cache objects (Hibernate L2 cache, Spring application context) larger than expected

**VisualVM:** GUI alternative for local/remote JVM monitoring. Shows heap over time, triggers GC, captures heap dumps, and provides basic heap analysis. Lighter weight than MAT.

---

**Real-World Backend Example**

A Goldman Sachs-style risk calculation service had a memory leak causing OOM every 48 hours. Analysis:
1. `-XX:+HeapDumpOnOutOfMemoryError` captured a 16GB heap dump.
2. MAT Leak Suspects: `HashMap` with 2.3M entries retaining 12GB.
3. Reference chain: `HashMap` → static field `RiskCalculationEngine.RESULT_CACHE` → `Thread` (GC root: main thread stack).
4. Root cause: risk results cached in a static HashMap by trade ID, never evicted. Month-end processing added 2.3M trade results. Fix: replace with Caffeine cache with `maximumSize(10000)` and `expireAfterWrite(1, TimeUnit.HOURS)`.

---

**Quick Revision Notes**

- Capture: `jmap -dump` or `-XX:+HeapDumpOnOutOfMemoryError`.
- Analyze: Eclipse MAT (Leak Suspects Report, Dominator Tree, OQL).
- Key metric: retained heap = heap freed if this object were GC'd.
- Look for: large collections, ThreadLocal values, classloader leaks.

---

### Q26. JVM flags important for production and interviews.

**Difficulty:** Medium | **Interview Frequency:** High  
**Companies:** Amazon (asks about deployment configs), Goldman Sachs, any DevOps/platform interview

---

**Short Answer (30–60 seconds)**

The critical production JVM flags are: `-Xms`/`-Xmx` for heap sizing, `-XX:+UseG1GC` for GC selection, `-XX:MaxGCPauseMillis` for G1 pause target, `-Xlog:gc*` for GC logging, `-XX:+HeapDumpOnOutOfMemoryError` for automatic diagnostics, and `-XX:MaxMetaspaceSize` to prevent unbounded Metaspace growth.

---

**Comprehensive Flag Reference:**

```bash
# === HEAP SIZING ===
-Xms4g                          # Initial heap (set = Xmx in production)
-Xmx4g                          # Max heap
-Xmn1g                          # Young gen size
-XX:NewRatio=2                   # Old:Young = 2:1 (Young = 33% of heap)
-XX:SurvivorRatio=8              # Eden:Survivor = 8:1:1

# === GC SELECTION ===
-XX:+UseG1GC                    # G1 (default Java 9+, recommended)
-XX:+UseZGC                     # ZGC (Java 15+, sub-ms pauses)
-XX:+UseParallelGC              # Parallel (batch workloads)
-XX:+UseSerialGC                # Serial (small heaps, single CPU)

# === G1 TUNING ===
-XX:MaxGCPauseMillis=200         # G1 soft pause target
-XX:InitiatingHeapOccupancyPercent=45  # Trigger concurrent marking
-XX:G1HeapRegionSize=8m         # Region size
-XX:G1ReservePercent=10          # Emergency reserve
-XX:ConcGCThreads=2              # Concurrent GC threads
-XX:ParallelGCThreads=4          # STW GC threads

# === GC LOGGING (Java 9+) ===
-Xlog:gc:stdout:time                                    # Basic to stdout
-Xlog:gc*:file=gc.log:time,uptime,level,tags:filecount=5,filesize=20m  # Production

# === DIAGNOSTICS ===
-XX:+HeapDumpOnOutOfMemoryError  # Auto-dump on OOM
-XX:HeapDumpPath=/var/dumps/     # Dump file path
-XX:OnOutOfMemoryError="kill -9 %p"  # Restart on OOM (container restart policy)
-XX:ErrorFile=/var/logs/hs_err_%p.log  # JVM crash log

# === METASPACE ===
-XX:MetaspaceSize=256m           # Initial trigger size
-XX:MaxMetaspaceSize=512m        # Hard cap

# === DIRECT MEMORY ===
-XX:MaxDirectMemorySize=1g       # NIO direct buffer cap

# === JIT ===
-XX:-TieredCompilation           # Disable tiered (use C2 only — slower warmup)
-XX:CompileThreshold=10000       # JIT compilation invocation threshold
-XX:+PrintCompilation            # Log JIT compilations (debugging only)

# === STARTUP PERFORMANCE ===
-XX:+UseAppCDS                  # Application Class Data Sharing
-XX:SharedArchiveFile=app.jsa    # CDS archive

# === THREAD ===
-Xss512k                        # Stack size per thread (default 512k-1m)
```

---

**Quick Revision Notes**

- Always: `-Xms`=`-Xmx`, `-XX:+UseG1GC`, `-XX:MaxGCPauseMillis`, `-XX:+HeapDumpOnOutOfMemoryError`, `-Xlog:gc*`.
- Metaspace: cap with `-XX:MaxMetaspaceSize` to prevent native OOM.
- `-Xlog:gc*` replaces `-verbose:gc` and `-XX:+PrintGCDetails` in Java 9+.
- `-Xss` × thread count = total stack memory (factor in container memory budgets).

---

## 6. JVM Memory Cheat Sheet

```
JVM MEMORY LAYOUT
=================================================================================

HEAP (managed by GC, -Xms / -Xmx)
┌─────────────────────────────────────────────────────────────────────────────┐
│  YOUNG GENERATION (-Xmn or -XX:NewRatio)                                    │
│  ┌──────────────────────────┬──────────────┬──────────────┐                 │
│  │         EDEN             │  SURVIVOR S0 │  SURVIVOR S1 │                 │
│  │   (new allocations here) │   (from)     │    (to)      │                 │
│  │   bump-pointer alloc     │  age 1-14    │  empty       │                 │
│  └──────────────────────────┴──────────────┴──────────────┘                 │
│         │ Minor GC                │                                          │
│         │ (STW, ~5-50ms)          │ promoted when age >= MaxTenuringThreshold│
│         ▼                         ▼                                          │
│  OLD GENERATION / TENURED                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │  Long-lived objects (survived N Minor GCs)                           │    │
│  │  Large objects (humongous in G1)                                     │    │
│  │  Major GC / Mixed GC / Full GC when filling up                       │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘

NATIVE MEMORY (outside JVM heap, not counted in -Xmx)
┌─────────────────┐  ┌──────────────┐  ┌─────────────────┐  ┌─────────────┐
│   METASPACE      │  │  CODE CACHE  │  │  THREAD STACKS  │  │DIRECT BUFS  │
│  (-XX:MaxMeta-   │  │  (JIT native │  │  (-Xss per      │  │(-XX:MaxDirect│
│   SpaceSize)     │  │   code)      │  │   thread)       │  │ MemorySize) │
│                  │  │              │  │                 │  │             │
│  Class metadata  │  │ JIT-compiled │  │ Method frames   │  │ NIO bufs    │
│  Bytecode        │  │ native instr │  │ Local variables │  │ Netty bufs  │
│  Constant pool   │  │              │  │ Operand stack   │  │             │
│  Static refs     │  │              │  │                 │  │             │
└─────────────────┘  └──────────────┘  └─────────────────┘  └─────────────┘

OBJECT LIFECYCLE (Generational GC)
=================================================================================

 new MyObject()
       │
       ▼
   ┌───────┐          Minor GC          ┌────────────┐
   │ EDEN  │ ──────────────────────────► │ SURVIVOR   │
   │       │  copy live objects          │ (age++)    │
   │ ~80%  │                             │            │
   │ young │                             │ age < 15   │
   └───────┘                             └─────┬──────┘
                                               │
                                               │ age >= MaxTenuringThreshold
                                               │ OR Survivor overflow
                                               ▼
                                         ┌──────────┐
                                         │  OLD GEN │
                                         │ (Tenured)│
                                         └──────────┘
                                               │
                                               │ Major GC / Mixed GC / Full GC
                                               ▼
                                         Object Collected

GC COLLECTOR COMPARISON
=================================================================================

Collector    | STW Pauses     | Throughput | Latency | Heap Size  | Default
-------------|----------------|------------|---------|------------|----------
Serial       | Full (single)  | Low        | High    | <1GB       | No
Parallel     | Full (multi)   | High       | Medium  | Any        | Java 8
CMS*         | Initial+Remark | Medium     | Low     | Medium     | No (removed)
G1           | Initial+Remark | Medium     | Low-Med | 4GB-100GB  | Java 9+
ZGC          | ~1ms (3 pauses)| Med-High   | Sub-ms  | Up to 16TB | No
Shenandoah   | ~10ms          | Medium     | Sub-10ms| Any        | No (OpenJDK)

*CMS deprecated Java 9, removed Java 14

CONTAINER MEMORY BUDGET
=================================================================================

Total container memory = 
    Heap (-Xmx)
  + Metaspace (-XX:MaxMetaspaceSize)
  + Code Cache (default ~240MB; tune with -XX:ReservedCodeCacheSize)
  + Thread stacks (-Xss × thread count)
  + Direct buffers (-XX:MaxDirectMemorySize)
  + JVM internal overhead (~100-300MB)
  ─────────────────────────────────────────────────────
  = Container memory limit

Example (4-core, 4GB container, G1 GC, 200 threads):
  -Xmx2g          →  2048 MB
  MaxMetaspace    →   512 MB
  Code Cache      →   256 MB
  Thread stacks   →   200 × 512KB = 100 MB
  Direct buffers  →   256 MB
  JVM overhead    →   200 MB
  ─────────────────────────────────────────────────────
  Total           ≈  3372 MB  (safe under 4096 MB limit)

=================================================================================
QUICK REFERENCE: JVM FLAGS FOR PRODUCTION (G1 GC)

-Xms4g -Xmx4g                          # Heap (set equal)
-XX:+UseG1GC                           # GC collector
-XX:MaxGCPauseMillis=200                # Pause target
-XX:InitiatingHeapOccupancyPercent=40  # Concurrent mark trigger
-XX:MaxMetaspaceSize=512m              # Metaspace cap
-XX:+HeapDumpOnOutOfMemoryError        # Auto-dump
-XX:HeapDumpPath=/var/dumps/           # Dump path
-Xlog:gc*:file=gc.log:time,uptime,level,tags:filecount=5,filesize=20m
=================================================================================
```

---

## Summary: High-Frequency Interview Topics

| Topic | Frequency | Key Points |
|---|---|---|
| JVM Memory Areas | Very High | Heap, Stack, Metaspace, Code Cache. Thread-local vs shared. |
| Heap Generations | Very High | Eden → Survivor → Old Gen. Generational hypothesis. |
| G1 GC internals | Very High | Region-based, concurrent marking, Mixed GC, RSets. |
| Memory leaks | Very High | Static collections, ThreadLocal, listeners, classloader. |
| GC types comparison | Very High | Serial/Parallel/G1/ZGC. STW pauses, use cases. |
| OOM types | Very High | Heap space, GC overhead, Metaspace, native thread. |
| Class loading | High | Bootstrap/Platform/App hierarchy, parent delegation. |
| JIT compilation | High | Tiered: C1 → C2. Inlining, escape analysis. |
| GC tuning flags | High | -Xms/Xmx, G1 flags, GC logging, HeapDump. |
| PermGen vs Metaspace | Medium | PermGen fixed, removed Java 8. Metaspace in native memory. |
| ZGC / Shenandoah | Medium | Colored pointers, load barriers, sub-ms pauses. |
| Custom ClassLoader | Medium | findClass() override, parent delegation, hot-reload. |
| Cold start / JIT warmup | Medium | Interpreter → C1 → C2 pipeline. Cloud-native impact. |
| Heap dump analysis | High | jmap, HeapDumpOnOOM, Eclipse MAT, retained heap. |

---

*End of Chapter 5: JVM Internals*



