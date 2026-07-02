# Volume 1: Core Java

**6 chapters · ~100+ Q&As · Java 17**

This volume covers the Java fundamentals that appear in virtually every backend interview. Expect deep questions on Collections internals, concurrency primitives, and JVM behaviour — especially at FAANG+, FinTech, and any company using a Java-heavy stack.

---

## What's In This Volume

| Chapter | Topic | Interview Weight |
|---------|-------|-----------------|
| Ch 1 | OOP Fundamentals | Medium — polymorphism, immutability, design by contract |
| Ch 2 | Strings, Wrappers & Exceptions | Medium — string pool, autoboxing traps, checked vs unchecked |
| Ch 3 | Collections & Data Structures | **Very High** — HashMap internals are asked at every level |
| Ch 4 | Java 8+ Modern Features | High — Streams, Lambdas, CompletableFuture, Optional |
| Ch 5 | JVM Internals & GC | High — heap layout, GC algorithms, memory leaks |
| Ch 6 | Multithreading & Concurrency | **Very High** — the #1 differentiator at SDE2 level |

---

## Study Plan for This Volume

### 4-Week Plan (Days 1–5 of Week 1)

| Day | Chapter | Focus |
|-----|---------|-------|
| Day 1 | Ch1 + Ch2 | Nail polymorphism, immutability, exception hierarchy |
| Day 2 | Ch3 | HashMap internals — load factor, treeification at 8, ConcurrentHashMap |
| Day 3 | Ch4 | Streams, Lambdas, CompletableFuture pipelines |
| Day 4 | Ch5 + Ch6 Part 1 | Thread basics, synchronized, volatile, happens-before |
| Day 5 | Ch6 Part 2 | ThreadPool tuning, deadlock patterns, virtual threads (Java 21) |

> After finishing this volume, validate with **Chapter 23** (Core Java Revision) in the Revision Pack.

### Crash Plan (1 week total — Day 1 of 7)

Prioritise Ch3 (Collections) and Ch6 (Multithreading). These two chapters alone are tested in the vast majority of backend coding rounds. Skim Ch1/Ch2 if time is tight; they rarely appear as standalone interview topics.

---

## Company Focus

### Amazon
- **Ch3** — HashMap treeification threshold, `ConcurrentHashMap` segment locking vs CAS
- **Ch6** — Thread pool sizing, `synchronized` vs `ReentrantLock`, deadlock detection
- Expect operational context: "What happens under contention in a high-throughput order service?"

### Google
- **Ch4** — Type erasure, bounded wildcards (`? extends T` vs `? super T`), parallel streams pitfalls
- **Ch5** — G1GC vs ZGC trade-offs, heap sizing for low-latency services
- **Ch6** — `CountDownLatch`, `Phaser`, `StampedLock` — Google probes concurrency primitives deeply
- Code quality is scored: clean stream pipelines > verbose loops

### Goldman Sachs / FinTech
- **Ch6** is the primary differentiator — JMM happens-before rules, `volatile` visibility guarantees
- Scenario questions: "Two threads update the same account balance — walk me through every failure mode"
- Correctness over cleverness: they prefer explicit locking with clear reasoning

### Atlassian / Salesforce
- Ch1 (OOP) + Ch4 (Java 8+) — clean, extensible design is valued
- Expect: "Refactor this class to be open for extension without modification"

---

## Key Concepts to Nail Cold

- **HashMap:** internal array + linked list/tree, `hashCode()` contract, resize at 0.75 load factor, treeification at 8 nodes
- **ConcurrentHashMap:** CAS for updates, no full-table lock since Java 8, `compute()` atomicity
- **volatile:** visibility guarantee only — NOT atomicity. Use `AtomicInteger` for compound actions.
- **ThreadPoolExecutor:** core/max pool size, work queue types (`LinkedBlockingQueue` vs `SynchronousQueue`), rejection policies
- **CompletableFuture:** `thenApply` (sync transform) vs `thenCompose` (async chain) vs `thenCombine` (merge two futures)
- **Virtual threads (Java 21):** carrier thread model, pinning conditions, when NOT to use them

---

*Volume 1 of 6 · [Full Handbook](../../book_output/index.html)*
