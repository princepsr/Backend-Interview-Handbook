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

- [Volume 1 Study Plan](STUDY_GUIDE.md) — 1-week plan, 3-day crash plan, top 10 questions, and daily practice tips.
- [Volume 1 Company Guide](COMPANY_GUIDE.md) — which companies go deep on Core Java and what they specifically test.

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
