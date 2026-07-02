# Chapter 6: Multithreading and Concurrency

**Volume 1 — Core Java | Java SDE2 Interview Handbook**

---

## Table of Contents

1. [Thread Fundamentals](#1-thread-fundamentals)
2. [Synchronization](#2-synchronization)
3. [Locks](#3-locks)
4. [Atomic Classes](#4-atomic-classes)
5. [Thread Pools and Executors](#5-thread-pools-and-executors)
6. [Concurrent Collections](#6-concurrent-collections)
7. [Concurrency Problems](#7-concurrency-problems)
8. [Real-World Patterns](#8-real-world-patterns)
9. [Java 21: Virtual Threads](#9-java-21-virtual-threads)
10. [Reference Diagrams and Checklists](#10-reference-diagrams-and-checklists)

---

## 1. Thread Fundamentals

---

### 1.1 Thread vs Process

**Difficulty:** Easy | **Interview Frequency:** Very High

**Companies:** Amazon, Goldman Sachs, Razorpay, Flipkart, Adobe, Intuit

**Short Answer (30-60 seconds):**
A process is an independent program with its own address space, memory, file handles, and OS resources. A thread is a unit of execution within a process — multiple threads share the same heap, code, and static data, but each has its own stack, program counter, and register set. Threads are cheaper to create and context-switch than processes, but they introduce shared-state concurrency hazards.

**Deep Explanation:**

| Dimension | Process | Thread |
|---|---|---|
| Memory space | Isolated address space | Shared heap; isolated stack |
| Stack size | OS-managed (~MB per process) | ~512KB–1MB per thread (JVM default: 512KB on 64-bit) |
| Creation cost | High (OS fork/exec, copy-on-write) | Lower, but still non-trivial (~1ms, OS thread) |
| Context switch cost | High (TLB flush, register save/restore, MMU reload) | Lower (no MMU reload, same address space) |
| IPC mechanism | Pipes, sockets, shared memory (explicit) | Shared heap (implicit, but requires synchronization) |
| Failure isolation | Process crash does not affect others | Thread crash can corrupt shared state or kill the JVM |
| Scheduling | OS scheduler | OS scheduler (for platform threads); JVM scheduler (for virtual threads) |

**Why threads are still expensive in Java (platform threads):**
Each Java platform thread maps 1:1 to an OS thread. The JVM allocates a fixed stack (~512KB by default, configurable via `-Xss`). With 1000 active threads you are consuming ~512MB just for stacks, before heap. Context switching at the OS level involves saving the full register set (~100 registers on x86-64), updating the kernel scheduler data structures, and potentially flushing CPU caches. This is why thread pools and virtual threads exist.

**Real-world backend example:**
A payment gateway handling 10,000 concurrent HTTP requests cannot spawn 10,000 OS threads. A typical 8-core server can run ~8 threads truly in parallel; the rest are parked waiting for I/O. The solution is either a thread pool (bounded OS threads) or virtual threads (Java 21) which the JVM multiplexes onto a small set of carrier threads.

**Java 17 code example:**
```java
public class ThreadVsProcessDemo {

    public static void main(String[] args) throws InterruptedException {
        // Threads share the same heap
        int[] sharedCounter = {0};

        Thread t1 = new Thread(() -> {
            for (int i = 0; i < 1000; i++) sharedCounter[0]++;
        });
        Thread t2 = new Thread(() -> {
            for (int i = 0; i < 1000; i++) sharedCounter[0]++;
        });

        t1.start();
        t2.start();
        t1.join();
        t2.join();

        // Result is non-deterministic — likely < 2000 due to race condition
        System.out.println("Counter: " + sharedCounter[0]);
    }
}
```

**Follow-up questions interviewers ask:**
- "How much stack memory does each Java thread consume by default?"
- "What happens if you create 100,000 threads in a Java application?"
- "How does Go's goroutine model differ from Java's platform thread model?"

**Common mistakes candidates make:**
- Saying threads have completely separate memory (they share heap but not stack).
- Claiming thread context switching is "free" — it has real CPU overhead.
- Confusing thread count with parallelism (N threads on a 1-core machine still serialize).

**Interview traps:**
- "Threads are lighter than processes" is true for creation but the interviewer may probe on stack memory consumption under high concurrency, which is where the real production cost lies.

**Quick revision notes:**
Thread = lightweight unit within a process. Shared heap, private stack (~512KB). OS thread creation costs ~1ms. Context switch cheaper than process but still involves OS kernel. Platform thread count is bounded by RAM and OS limits.

---

### 1.2 Thread Lifecycle

**Difficulty:** Easy | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Goldman Sachs, Atlassian, Razorpay

**Short Answer:**
A Java thread goes through six states: NEW (created but not started), RUNNABLE (executing or ready to execute), BLOCKED (waiting for a monitor lock), WAITING (waiting indefinitely for notify/join), TIMED_WAITING (waiting with a timeout), and TERMINATED (execution complete). State transitions are triggered by API calls.

**Deep Explanation:**

```
NEW ──start()──> RUNNABLE ──scheduler──> running
                    |  ^
         sleep()/   |  | timeout / notify() / interrupt()
         wait() /   v  |
         join() ──> TIMED_WAITING / WAITING / BLOCKED
                         |
                    run() returns / uncaught exception
                         |
                      TERMINATED
```

State transition table:

| From | To | Trigger |
|---|---|---|
| NEW | RUNNABLE | `thread.start()` |
| RUNNABLE | BLOCKED | Thread needs monitor lock held by another thread |
| BLOCKED | RUNNABLE | Monitor lock becomes available |
| RUNNABLE | WAITING | `object.wait()`, `thread.join()` (no timeout), `LockSupport.park()` |
| WAITING | RUNNABLE | `object.notify()` / `notifyAll()`, joined thread terminates, `LockSupport.unpark()` |
| RUNNABLE | TIMED_WAITING | `Thread.sleep(n)`, `object.wait(n)`, `thread.join(n)`, `LockSupport.parkNanos()` |
| TIMED_WAITING | RUNNABLE | Timeout expires, or same unpark triggers as WAITING |
| RUNNABLE | TERMINATED | `run()` returns or unhandled exception |

Key distinction — BLOCKED vs WAITING:
- BLOCKED: thread is waiting to acquire a synchronized monitor lock (at the JVM level, spinning or yielding waiting for the lock).
- WAITING: thread voluntarily gave up CPU and is waiting for an explicit signal (notify, unpark, join completion).

**Real-world backend example:**
In a connection pool (HikariCP, C3P0), threads waiting for a free connection are in WAITING or TIMED_WAITING state. A thread dump showing thousands of BLOCKED threads on a single monitor is a sign of lock contention — a common production incident in high-throughput APIs.

**Java 17 code example:**
```java
public class LifecycleDemo {

    public static void main(String[] args) throws InterruptedException {
        Object lock = new Object();

        Thread t = new Thread(() -> {
            synchronized (lock) {
                try {
                    lock.wait(5000); // TIMED_WAITING
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        });

        System.out.println(t.getState()); // NEW

        t.start();
        Thread.sleep(100); // give t time to enter wait

        System.out.println(t.getState()); // TIMED_WAITING

        synchronized (lock) {
            lock.notify();
        }

        t.join();
        System.out.println(t.getState()); // TERMINATED
    }
}
```

**Follow-up questions:**
- "What is the difference between BLOCKED and WAITING?"
- "Can a thread move from WAITING back to RUNNABLE directly?"
- "What state is a thread in while waiting for I/O?"

**Common mistakes:**
- Claiming a thread in BLOCKED state holds a lock — it does not, it is waiting to acquire one.
- Confusing WAITING (indefinite, needs signal) with TIMED_WAITING (has timeout).

**Interview traps:**
- "What state is a thread doing I/O in?" The answer from Java's perspective is RUNNABLE — the JVM does not distinguish I/O waiting from CPU work at the Thread.State level. The underlying OS thread is blocked on I/O, but Java reports RUNNABLE.

**Quick revision notes:**
Six states: NEW, RUNNABLE, BLOCKED, WAITING, TIMED_WAITING, TERMINATED. BLOCKED = waiting for monitor lock. WAITING = waiting for explicit signal. I/O threads appear RUNNABLE to Java despite being OS-blocked.

---

### 1.3 Creating Threads

**Difficulty:** Easy | **Interview Frequency:** High

**Companies:** TCS, Infosys, Flipkart, Razorpay, Paytm

**Short Answer:**
Three ways: extend Thread, implement Runnable, implement Callable (returns a value via Future). Runnable and Callable are preferred because they separate the task from the execution mechanism, allow the task class to extend another class, and work with ExecutorService.

**Deep Explanation:**

Approach 1 — Extend Thread:
```java
class MyThread extends Thread {
    @Override
    public void run() { /* task */ }
}
new MyThread().start();
```
Problem: Java has single inheritance. If MyThread extends Thread, it cannot extend any other class. Also tightly couples task logic with thread management.

Approach 2 — Implement Runnable:
```java
Thread t = new Thread(() -> System.out.println("Task"));
t.start();
```
Better: task is decoupled. Can be submitted to ExecutorService. Can extend other classes.

Approach 3 — Implement Callable + Future:
```java
Callable<Integer> task = () -> compute();
ExecutorService es = Executors.newSingleThreadExecutor();
Future<Integer> future = es.submit(task);
Integer result = future.get(); // blocks until done
```
Callable differs from Runnable: returns a value, can throw checked exceptions. Future.get() blocks the calling thread until the result is available, or throws ExecutionException wrapping any exception thrown by the task.

**Real-world backend example:**
In a payment service, a Callable is used to call an external fraud-check API concurrently with other validation tasks. Each check is submitted to a thread pool and results are collected via Future.get() with a timeout, so the overall payment flow has a deterministic SLA regardless of individual check latency.

**Java 17 code example:**
```java
import java.util.concurrent.*;

public class ThreadCreationDemo {

    public static void main(String[] args) throws Exception {
        ExecutorService executor = Executors.newFixedThreadPool(3);

        // Runnable — fire and forget
        executor.submit(() -> System.out.println("Runnable task: " + Thread.currentThread().getName()));

        // Callable — returns a value
        Future<String> future = executor.submit(() -> {
            Thread.sleep(100);
            return "Result from: " + Thread.currentThread().getName();
        });

        System.out.println(future.get(500, TimeUnit.MILLISECONDS));

        executor.shutdown();
    }
}
```

**Follow-up questions:**
- "What happens if a Callable throws an exception? How do you retrieve it?"
- "What is the difference between execute() and submit() on ExecutorService?"
- "Can you cancel a Future? What does Future.cancel(true) do?"

**Common mistakes:**
- Calling `run()` directly instead of `start()` — this executes the task on the calling thread, not a new thread.
- Not shutting down ExecutorService, causing the JVM to hang (non-daemon threads keep the JVM alive).

**Interview traps:**
- `execute()` vs `submit()`: execute takes Runnable and returns void, throws uncaught exceptions to the UncaughtExceptionHandler. `submit()` wraps exceptions inside Future — they only surface on `future.get()`.

**Quick revision notes:**
Prefer Runnable/Callable over extending Thread. Callable returns value and can throw checked exceptions. Future.get() blocks and throws ExecutionException on task failure. Always shut down ExecutorService.

---

### 1.4 Thread.sleep() vs Object.wait()

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Goldman Sachs, Morgan Stanley, Amazon, Razorpay

**Short Answer:**
`Thread.sleep()` pauses the current thread for a specified time but does NOT release any held locks. `Object.wait()` must be called inside a synchronized block, and it releases the intrinsic lock so other threads can enter the synchronized section. Both throw InterruptedException.

**Deep Explanation:**

| Dimension | Thread.sleep() | Object.wait() |
|---|---|---|
| Package | java.lang.Thread (static) | java.lang.Object (instance) |
| Requires synchronized block? | No | Yes — IllegalMonitorStateException otherwise |
| Releases lock? | No | Yes — releases the object's intrinsic lock |
| Woken by | Timeout or interrupt | notify(), notifyAll(), timeout (wait(n)), or interrupt |
| Purpose | Pause execution for a fixed time | Wait for a condition to be signaled by another thread |
| Lock state on return | Same as before sleep | Re-acquires the lock before returning |

Why does wait() require a synchronized block?
Object.wait() is a coordination mechanism built on the intrinsic lock. The contract is: "I hold the lock, I check a condition, if not met I release the lock and wait. When notified, I re-acquire the lock and recheck." Without the lock, the check-then-wait would be a race condition.

Why always use wait() in a loop (not if)?
```java
// WRONG
synchronized (queue) {
    if (queue.isEmpty()) queue.wait(); // spurious wakeup risk
    process(queue.poll());
}

// CORRECT
synchronized (queue) {
    while (queue.isEmpty()) queue.wait(); // recheck after every wakeup
    process(queue.poll());
}
```
Spurious wakeups: the JVM (and underlying OS) can wake a thread from wait() without notify() being called. This is a documented behavior. Always recheck the condition in a while loop.

**Real-world backend example:**
A rate limiter uses `wait(remainingWindowTime)` to pause threads that have exceeded their request quota, releasing the lock so other threads can check their own quotas.

**Java 17 code example:**
```java
public class WaitVsSleepDemo {

    private final Object lock = new Object();
    private boolean dataReady = false;

    public void producer() throws InterruptedException {
        Thread.sleep(500); // simulate work, lock NOT held
        synchronized (lock) {
            dataReady = true;
            lock.notifyAll();
        }
    }

    public void consumer() throws InterruptedException {
        synchronized (lock) {
            while (!dataReady) {
                lock.wait(); // releases lock, waits for notify
            }
            System.out.println("Data consumed");
        }
    }

    public static void main(String[] args) throws InterruptedException {
        WaitVsSleepDemo demo = new WaitVsSleepDemo();
        Thread c = new Thread(() -> {
            try { demo.consumer(); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
        });
        Thread p = new Thread(() -> {
            try { demo.producer(); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
        });
        c.start();
        p.start();
        c.join(); p.join();
    }
}
```

**Follow-up questions:**
- "What is a spurious wakeup and how do you guard against it?"
- "Why does wait() throw InterruptedException?"
- "What happens if you call wait() without holding the lock?"

**Common mistakes:**
- Using `if` instead of `while` for condition check around wait().
- Calling `Thread.sleep()` while holding a lock (starves other threads unnecessarily).

**Interview traps:**
- "Does sleep() release locks?" The answer is no. This is a very common interview trap to confirm candidates know the critical difference.

**Quick revision notes:**
sleep() holds lock, no coordination. wait() releases lock, coordination mechanism. Both throw InterruptedException. Always use wait() in a while loop to guard against spurious wakeups.

---

### 1.5 join()

**Difficulty:** Easy | **Interview Frequency:** High

**Companies:** Amazon, Flipkart, Adobe, Razorpay

**Short Answer:**
`thread.join()` makes the calling thread wait until the specified thread has terminated. It is used to coordinate results — the calling thread needs the target thread to finish before proceeding. It throws InterruptedException.

**Deep Explanation:**
Internally, join() calls `wait()` on the Thread object itself. When the target thread terminates, it calls `notifyAll()` on itself (this is JVM-internal behavior in Thread.join() implementation). The calling thread unblocks when either the target thread terminates, the timeout expires (join(long millis)), or the calling thread is interrupted.

```java
void join() throws InterruptedException
void join(long millis) throws InterruptedException
void join(long millis, int nanos) throws InterruptedException
```

**Real-world backend example:**
A batch payment processing service splits a large payment file into chunks, processes each chunk in a separate thread, then calls join() on all threads before aggregating results and committing to the database.

**Java 17 code example:**
```java
public class JoinDemo {

    public static void main(String[] args) throws InterruptedException {
        Thread[] workers = new Thread[5];
        int[] results = new int[5];

        for (int i = 0; i < 5; i++) {
            final int idx = i;
            workers[i] = new Thread(() -> {
                results[idx] = idx * idx; // simulate work
            });
            workers[i].start();
        }

        for (Thread worker : workers) {
            worker.join(); // wait for each to finish
        }

        int sum = 0;
        for (int r : results) sum += r;
        System.out.println("Sum: " + sum); // 0+1+4+9+16 = 30
    }
}
```

**Follow-up questions:**
- "What is the difference between join() and Future.get()?"
- "How do you join all threads in a list with a total timeout?"
- "What happens if a thread you joined throws an unchecked exception?"

**Common mistakes:**
- Not handling InterruptedException: silently swallowing it masks thread interruption protocols.
- Assuming join() guarantees a result is visible — it does, because join() establishes a happens-before relationship.

**Quick revision notes:**
join() = current thread waits for target thread to finish. Establishes happens-before (results visible after join). Throws InterruptedException. join(millis) for timeout-based waiting.

---

### 1.6 Daemon Threads

**Difficulty:** Easy | **Interview Frequency:** Medium

**Companies:** Goldman Sachs, Atlassian, Adobe

**Short Answer:**
A daemon thread is a background thread that does not prevent JVM shutdown. When all non-daemon threads finish, the JVM exits regardless of running daemon threads. Set via `thread.setDaemon(true)` before calling `start()`.

**Deep Explanation:**
The JVM exits when all non-daemon threads have terminated. Daemon threads are abruptly stopped at JVM shutdown — they do not get a chance to complete their current operation or run finally blocks reliably. This makes them unsuitable for tasks that require cleanup (file writes, database commits).

Daemon thread use cases:
- Garbage collector (JVM's GC threads are daemon)
- JVM JIT compiler threads
- Background monitoring/heartbeat threads
- Log flushing (where missing a few entries on shutdown is acceptable)
- Connection pool eviction threads (HikariCP's housekeeper is a daemon thread)

Thread inherits daemon status from its parent. The main thread is a non-daemon thread, so threads spawned from main are also non-daemon by default.

**Java 17 code example:**
```java
public class DaemonDemo {

    public static void main(String[] args) throws InterruptedException {
        Thread daemon = new Thread(() -> {
            while (true) {
                try {
                    System.out.println("Daemon heartbeat");
                    Thread.sleep(500);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        });

        daemon.setDaemon(true); // MUST be set before start()
        daemon.start();

        Thread.sleep(1200); // main thread does work
        System.out.println("Main done — JVM will exit, killing daemon");
        // JVM exits here, daemon thread abruptly stopped
    }
}
```

**Follow-up questions:**
- "Can daemon threads have non-daemon children?"
- "Is it safe to write to a database in a daemon thread?"
- "What happens to finally blocks in daemon threads during JVM shutdown?"

**Common mistakes:**
- Calling `setDaemon(true)` after `start()` — throws IllegalThreadStateException.
- Using daemon threads for tasks that must complete (file writes, metric flushes).

**Quick revision notes:**
Daemon threads die when all non-daemon threads finish. Set before start(). GC, JIT, monitoring are typical daemon use cases. finally blocks not guaranteed on daemon thread during JVM exit.

---

## 2. Synchronization

---

### 2.1 The synchronized Keyword

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Goldman Sachs, Google, Razorpay, Morgan Stanley

**Short Answer:**
`synchronized` uses the object's intrinsic lock (monitor) to ensure mutual exclusion. On an instance method, the lock is `this`. On a static method, the lock is the Class object. A synchronized block takes an explicit lock object. Intrinsic locks are reentrant — a thread that holds a lock can acquire it again without deadlocking.

**Deep Explanation:**

Every Java object has an associated monitor (intrinsic lock). The monitor has three regions:
1. Entry set: threads competing to acquire the lock (in BLOCKED state)
2. The owner: thread currently holding the lock
3. Wait set: threads that called wait() (in WAITING state)

Reentrant nature: if thread T holds the lock on object O and calls another synchronized method on the same object O, it succeeds immediately without blocking. The JVM maintains a hold count; the lock is released only when the hold count drops to zero.

```java
public class Counter {

    private int count = 0;

    // Intrinsic lock = this
    public synchronized void increment() {
        count++;
    }

    // Equivalent synchronized block form
    public void incrementBlock() {
        synchronized (this) {
            count++;
        }
    }

    // Class-level lock — synchronizes across ALL instances
    public static synchronized void staticMethod() {
        // lock = Counter.class
    }

    // Fine-grained: separate locks for separate concerns
    private final Object readLock = new Object();
    private final Object writeLock = new Object();
}
```

Object-level vs Class-level locking:
- `synchronized` instance method: locks `this` — two threads can simultaneously enter the same method on different instances.
- `synchronized` static method: locks `ClassName.class` — one thread at a time across all instances.

Synchronized block advantages over synchronized method:
- Smaller critical section (less time holding the lock, more throughput)
- Can use a dedicated lock object (finer-grained locking)
- Can prevent locking on `this` (which external code could also lock on — a security/encapsulation risk)

**Real-world backend example:**
A singleton connection pool uses `synchronized` on the `getInstance()` method. Once initialized, the lock is unnecessary — this is why double-checked locking (covered in 2.4) exists.

**Java 17 code example:**
```java
public class BankAccount {

    private double balance;

    public BankAccount(double initialBalance) {
        this.balance = initialBalance;
    }

    public synchronized void deposit(double amount) {
        if (amount <= 0) throw new IllegalArgumentException("Amount must be positive");
        balance += amount;
    }

    public synchronized boolean withdraw(double amount) {
        if (amount <= 0) throw new IllegalArgumentException();
        if (balance < amount) return false;
        balance -= amount;
        return true;
    }

    // Reentrant: withdraw calls checkBalance, both are synchronized on 'this'
    public synchronized boolean withdrawIfSufficient(double amount) {
        if (checkBalance() >= amount) { // reentrant lock acquisition
            balance -= amount;
            return true;
        }
        return false;
    }

    public synchronized double checkBalance() {
        return balance;
    }
}
```

**Follow-up questions:**
- "What is the difference between synchronizing on `this` vs a private lock object?"
- "Can two threads call different synchronized methods on the same object simultaneously?"
- "What is a reentrant lock and why is it important?"

**Common mistakes:**
- Synchronizing on a local variable or a newly created object (e.g., `synchronized (new Object())`) — each thread gets a different lock, synchronization is useless.
- Synchronizing a getter but not a setter (or vice versa) — incomplete protection.
- Over-synchronizing: making entire methods synchronized when only a few lines access shared state.

**Interview traps:**
- "Can two threads call `synchronized` methods on the same object simultaneously?" No — they both need the same lock. But two threads can call synchronized methods on different instances simultaneously.
- Synchronizing on `Integer` or `String` literals can cause subtle deadlocks because these are cached/interned objects shared across the JVM.

**Quick revision notes:**
synchronized = intrinsic lock / monitor. Instance method locks `this`, static method locks Class object. Reentrant (hold count). Smaller synchronized blocks = less contention. Never synchronize on boxed primitives or String literals.

---

### 2.2 The volatile Keyword

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Goldman Sachs, Amazon, Google, Morgan Stanley, Razorpay

**Short Answer:**
`volatile` guarantees visibility — reads and writes go directly to main memory, bypassing CPU cache. It does NOT guarantee atomicity. `i++` on a volatile variable is still a race condition (read-modify-write is three operations). Use volatile when one thread writes and others read, with no compound operations.

**Deep Explanation:**

Without volatile — the CPU cache problem:
Each CPU core has its own L1/L2 cache. Without synchronization, a thread on core 1 may cache a variable's value locally and never see updates made by a thread on core 2. This is not a bug in the CPU — it is a performance optimization.

```
Core 1 cache: running = true   ← stale, from before core 2 wrote false
Core 2 cache: running = false  ← updated
Main memory:  running = false
```

volatile inserts a memory barrier (fence instruction) that:
- Forces a write to flush to main memory immediately
- Forces a read to fetch from main memory (not cache)

What volatile guarantees:
1. Visibility: writes by thread A are visible to thread B after thread B reads the volatile variable.
2. Ordering: volatile writes cannot be reordered with respect to other memory operations (before the write or after the read). This is the key to fixing double-checked locking.

What volatile does NOT guarantee:
- Atomicity of compound operations. `count++` is: (1) read count, (2) increment, (3) write count. Two threads can both read the same value, both increment, both write — losing one increment.

```java
// CORRECT use of volatile: single writer, flag variable
private volatile boolean running = true;

public void stop() { running = false; } // thread A writes

public void run() {
    while (running) { // thread B reads — sees update due to volatile
        doWork();
    }
}

// WRONG: compound operation is not atomic even with volatile
private volatile int counter = 0;
public void increment() { counter++; } // NOT thread-safe
```

Memory barrier analogy: volatile write = "store fence" (all previous writes are committed before this write). volatile read = "load fence" (this read will see all writes that happened-before the volatile write).

**Real-world backend example:**
A circuit breaker uses a `volatile boolean` flag `isOpen` that is written by a monitoring thread and read by many worker threads. Since only one thread writes and many read (no compound operations), volatile is sufficient and avoids the overhead of synchronized.

**Java 17 code example:**
```java
public class CircuitBreaker {

    private volatile boolean isOpen = false;   // volatile: one writer, many readers
    private volatile long openedAt = 0;
    private static final long TIMEOUT_MS = 5000;

    public boolean allowRequest() {
        if (!isOpen) return true;
        // Check if timeout has elapsed to try half-open
        return (System.currentTimeMillis() - openedAt) > TIMEOUT_MS;
    }

    public void trip() {
        isOpen = true;       // volatile write — immediately visible to all threads
        openedAt = System.currentTimeMillis();
    }

    public void reset() {
        isOpen = false;
    }
}
```

**Follow-up questions:**
- "Is `long` or `double` read/write atomic in Java without volatile?"
- "What is a memory barrier and when is it inserted?"
- "Can volatile replace synchronized in all cases?"

**Common mistakes:**
- Using volatile for `count++` and believing it is thread-safe.
- Not using volatile for the `instance` field in double-checked locking (classic DCL bug).

**Interview traps:**
- 64-bit reads/writes (`long`, `double`) are NOT guaranteed to be atomic on 32-bit JVMs without volatile. On a 32-bit JVM, a 64-bit write can be split into two 32-bit writes, causing a torn read.

**Quick revision notes:**
volatile = visibility + ordering, NOT atomicity. CPU cache bypass. i++ is still a race. Use for flags with one writer. Memory barrier is inserted on every read/write.

---

### 2.3 Happens-Before Relationship

**Difficulty:** Hard | **Interview Frequency:** Medium

**Companies:** Google, Amazon, Goldman Sachs

**Short Answer:**
The Java Memory Model defines happens-before as the guarantee that if action A happens-before action B, then the effects of A are visible to B. Key rules: program order within a thread, monitor unlock happens-before re-lock, volatile write happens-before subsequent volatile read, thread start() happens-before thread's actions, thread's actions happen-before join() returns.

**Deep Explanation:**

The JMM does not say when writes happen in absolute time. It says when a write by thread A is guaranteed to be visible to thread B. Without a happens-before edge between a write and a read, the read may see a stale value — even on a multi-GHz modern machine.

Core happens-before rules (JLS 17.4.5):

1. **Program order rule**: Each action in a thread happens-before every subsequent action in that same thread.

2. **Monitor lock rule**: Unlock of a monitor happens-before every subsequent lock of that monitor.
   ```
   synchronized block exit → next synchronized entry on same object
   ```

3. **Volatile variable rule**: A write to a volatile field happens-before every subsequent read of that field.

4. **Thread start rule**: A call to `thread.start()` happens-before any action in the started thread.

5. **Thread join rule**: All actions in a thread happen-before any other thread returns from `thread.join()` on that thread.

6. **Transitivity**: If A hb B and B hb C, then A hb C.

Practical implication:
```java
int x = 0;
volatile boolean flag = false;

// Thread 1
x = 42;          // (A)
flag = true;     // (B) volatile write

// Thread 2
if (flag) {      // (C) volatile read — sees the write at (B) due to volatile rule
    // x is guaranteed to be 42 here due to:
    // (A) hb (B) [program order], (B) hb (C) [volatile rule], so (A) hb (C) [transitivity]
    System.out.println(x);
}
```

This is not just about `flag` being visible — the volatile write creates a happens-before edge that carries all prior writes (like `x = 42`) into the visibility guarantee.

**Real-world backend example:**
This is the exact mechanism that makes safe publication of objects work. When you publish an object reference via a volatile field or through synchronized, all writes to the object's fields that happened before the publish are guaranteed visible to the reader.

**Follow-up questions:**
- "Does synchronization guarantee ordering, visibility, or both?"
- "Can two threads see different orderings of each other's writes?"
- "What is the happens-before relationship between a volatile write and a subsequent synchronized block?"

**Common mistakes:**
- Thinking happens-before is about time ("A happened first"). It is about visibility guarantees, not wall-clock ordering.

**Quick revision notes:**
Happens-before = visibility guarantee. Key rules: program order, monitor unlock→lock, volatile write→read, start(), join(). Transitivity extends guarantees. Memory model formalizes what concurrent code can rely on.

---

### 2.4 Double-Checked Locking

**Difficulty:** Hard | **Interview Frequency:** High

**Companies:** Goldman Sachs, Amazon, Google, Razorpay

**Short Answer:**
Double-checked locking (DCL) is a pattern to lazily initialize a singleton with minimal locking. The classic version without `volatile` is broken because of instruction reordering — the `instance` reference can be non-null but the object not fully constructed. The fix: declare the field `volatile`.

**Deep Explanation:**

Classic (broken) DCL:
```java
// BROKEN — do not use
public class Singleton {
    private static Singleton instance; // NOT volatile

    public static Singleton getInstance() {
        if (instance == null) {         // check 1: no lock
            synchronized (Singleton.class) {
                if (instance == null) { // check 2: with lock
                    instance = new Singleton(); // DANGER
                }
            }
        }
        return instance;
    }
}
```

Why it is broken: `instance = new Singleton()` is not atomic. It compiles to roughly:
1. Allocate memory for the object
2. Initialize the object (write fields, run constructor)
3. Assign the reference to `instance`

The JIT/CPU can reorder steps 2 and 3 — the reference can be written before the object is fully initialized. Thread A is in the synchronized block, does step 1 and 3 (assigns non-null reference), then gets preempted before step 2. Thread B enters `getInstance()`, sees `instance != null` at check 1, and returns a partially constructed object. This is a real production bug.

The fix — volatile:
```java
// CORRECT
public class Singleton {
    private static volatile Singleton instance; // volatile!

    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    instance = new Singleton();
                }
            }
        }
        return instance;
    }
}
```

Why volatile fixes it: the volatile write to `instance` creates a happens-before edge. The JMM forbids reordering of the object construction with the volatile write. All writes inside the constructor happen-before the volatile write, which happens-before any thread's volatile read. The reading thread is guaranteed to see a fully constructed object.

This works since Java 5's revised JMM (JSR-133). Before Java 5, volatile did not have strong enough semantics to fix DCL.

Alternative — Initialization-on-demand holder (preferred in most cases):
```java
public class Singleton {

    private Singleton() {}

    private static class Holder {
        static final Singleton INSTANCE = new Singleton();
    }

    public static Singleton getInstance() {
        return Holder.INSTANCE;
    }
}
```
This relies on class loading being thread-safe (guaranteed by JVM). No synchronization or volatile needed. Lazy (Holder is loaded only when getInstance() is first called). This is the cleanest approach.

**Real-world backend example:**
Database connection pool initialization in a microservice. The pool is expensive to create and should be created once. DCL or the holder pattern ensures the pool is initialized lazily without synchronization overhead on every request.

**Follow-up questions:**
- "Why does volatile fix double-checked locking? What specific guarantee does it provide?"
- "What is the initialization-on-demand holder pattern?"
- "Is enum-based singleton better than DCL?"

**Common mistakes:**
- Using DCL without volatile.
- Not knowing that volatile alone would require synchronization on every read if used without the double-check.

**Interview traps:**
- "Is DCL broken in Java?" — it was broken before Java 5. With volatile and Java 5+ JMM, it is correct. Candidates who only say "yes, it's broken" without the nuance fail the follow-up.

**Quick revision notes:**
DCL without volatile is broken due to instruction reordering. volatile write creates happens-before, ensures fully constructed object is visible. Fix: `private static volatile`. Prefer Initialization-on-Demand Holder in production.

---

## 3. Locks

---

### 3.1 ReentrantLock

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Goldman Sachs, Amazon, Morgan Stanley, Razorpay, Google

**Short Answer:**
`ReentrantLock` is an explicit lock with the same mutual exclusion semantics as `synchronized` but with additional capabilities: timed lock attempts (`tryLock(timeout)`), interruptible lock acquisition (`lockInterruptibly()`), multiple Condition variables (`newCondition()`), and optional fairness. Always release in a finally block.

**Deep Explanation:**

ReentrantLock vs synchronized:

| Feature | synchronized | ReentrantLock |
|---|---|---|
| Acquisition | Blocking only | tryLock(), tryLock(timeout), lockInterruptibly() |
| Interruption | Cannot interrupt waiting thread | lockInterruptibly() can be interrupted |
| Fairness | Not guaranteed (barge-in) | Optional fair mode (FIFO ordering) |
| Condition variables | One wait set (wait/notify) | Multiple via newCondition() |
| Lock inspection | Not possible | isLocked(), isHeldByCurrentThread(), getQueueLength() |
| Performance | Often equal or better (JVM-optimized) | Slightly more overhead in low-contention |
| Code safety | Compiler ensures release | Manual finally block required |

Fairness (`new ReentrantLock(true)`):
In fair mode, the lock is granted in the order threads requested it (FIFO). This prevents starvation but reduces throughput — fairness requires an OS scheduling guarantee, which is expensive. Default (non-fair) mode allows "barge-in" where a thread can acquire a just-released lock even if other threads are waiting, which improves throughput.

Multiple Conditions:
```java
ReentrantLock lock = new ReentrantLock();
Condition notFull  = lock.newCondition();
Condition notEmpty = lock.newCondition();
```
With `synchronized`, you have one wait set per object. With Condition, producers can signal only consumers (notEmpty.signal()) without waking producers, eliminating spurious wakeups.

**Real-world backend example:**
A payment queue with separate producer and consumer pools. Producers wait on `notFull` when the queue is full, consumers wait on `notEmpty` when empty. Using two Conditions avoids waking all threads when only one type needs to proceed.

**Java 17 code example:**
```java
import java.util.concurrent.locks.*;
import java.util.*;

public class BoundedQueue<T> {

    private final ReentrantLock lock = new ReentrantLock();
    private final Condition notFull  = lock.newCondition();
    private final Condition notEmpty = lock.newCondition();
    private final Queue<T> queue;
    private final int capacity;

    public BoundedQueue(int capacity) {
        this.capacity = capacity;
        this.queue = new ArrayDeque<>(capacity);
    }

    public void put(T item) throws InterruptedException {
        lock.lock();
        try {
            while (queue.size() == capacity) {
                notFull.await(); // releases lock and waits
            }
            queue.offer(item);
            notEmpty.signal(); // wake one consumer
        } finally {
            lock.unlock(); // ALWAYS in finally
        }
    }

    public T take() throws InterruptedException {
        lock.lock();
        try {
            while (queue.isEmpty()) {
                notEmpty.await();
            }
            T item = queue.poll();
            notFull.signal(); // wake one producer
            return item;
        } finally {
            lock.unlock();
        }
    }

    // tryLock use case: non-blocking attempt
    public boolean offer(T item) {
        if (lock.tryLock()) {
            try {
                if (queue.size() < capacity) {
                    queue.offer(item);
                    notEmpty.signal();
                    return true;
                }
                return false;
            } finally {
                lock.unlock();
            }
        }
        return false; // lock not available
    }
}
```

**Follow-up questions:**
- "Why must you always unlock in a finally block?"
- "When would you choose fair mode over non-fair mode?"
- "What is the difference between Condition.await() and Object.wait()?"

**Common mistakes:**
- Not using try-finally, so an exception causes the lock to never be released (deadlock).
- Calling `lock.unlock()` when the lock is not held — throws IllegalMonitorStateException.
- Using fair lock for high-throughput systems without understanding the performance cost.

**Interview traps:**
- "Is ReentrantLock always better than synchronized?" No. For simple mutual exclusion, synchronized is often preferred — the compiler/JVM has heavy optimizations (biased locking, lock elision via escape analysis). Use ReentrantLock when you need its specific features.

**Quick revision notes:**
ReentrantLock: explicit lock, tryLock/timeout, interruptible, multiple Conditions, fairness option. Always unlock in finally. Prefer synchronized for simple cases. Multiple Conditions avoid notifyAll() waking wrong threads.

---

### 3.2 ReadWriteLock (ReentrantReadWriteLock)

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Goldman Sachs, Amazon, Google, Adobe

**Short Answer:**
`ReentrantReadWriteLock` allows multiple concurrent readers OR one exclusive writer. Reads do not block each other; a write blocks all reads and writes. Ideal for read-heavy shared data like caches. Downgrade from write to read lock is allowed; upgrade from read to write is NOT.

**Deep Explanation:**

The problem it solves: `synchronized` or `ReentrantLock` serialize all access — even two concurrent reads block each other. For a cache hit rate of 99%, you are serializing 99% of requests unnecessarily.

```java
ReadWriteLock rwLock = new ReentrantReadWriteLock();
Lock readLock  = rwLock.readLock();
Lock writeLock = rwLock.writeLock();
```

Rules:
- Multiple threads can hold the read lock simultaneously (no exclusive ownership)
- Write lock is exclusive — no readers and no other writers while held
- A thread holding the write lock can acquire the read lock (downgrade) — useful when you want to read your own writes while still allowing readers
- A thread holding the read lock CANNOT upgrade to write lock — this would deadlock (two readers both trying to upgrade wait for each other)

Write lock downgrade pattern:
```java
writeLock.lock();
try {
    updateCache(key, newValue);
    readLock.lock(); // acquire read lock before releasing write
} finally {
    writeLock.unlock(); // release write, now only holding read
}
try {
    return cache.get(key); // read while allowing others to read too
} finally {
    readLock.unlock();
}
```

**Real-world backend example:**
An in-memory routing table (API gateway) maps URL patterns to backend services. Routes are read millions of times per second but updated rarely (config change). ReadWriteLock allows all readers to proceed in parallel with zero blocking, while a config reload briefly acquires the write lock.

**Java 17 code example:**
```java
import java.util.concurrent.locks.*;
import java.util.*;

public class ReadHeavyCache<K, V> {

    private final ReentrantReadWriteLock rwLock = new ReentrantReadWriteLock();
    private final Lock readLock  = rwLock.readLock();
    private final Lock writeLock = rwLock.writeLock();
    private final Map<K, V> cache = new HashMap<>();

    public V get(K key) {
        readLock.lock();
        try {
            return cache.get(key); // many threads can read concurrently
        } finally {
            readLock.unlock();
        }
    }

    public void put(K key, V value) {
        writeLock.lock();
        try {
            cache.put(key, value); // exclusive access
        } finally {
            writeLock.unlock();
        }
    }

    public void evictAll() {
        writeLock.lock();
        try {
            cache.clear();
        } finally {
            writeLock.unlock();
        }
    }
}
```

**Follow-up questions:**
- "Why is read-to-write upgrade not supported?"
- "When would ReadWriteLock perform worse than ReentrantLock?"
- "What is the difference between ReentrantReadWriteLock and StampedLock?"

**Common mistakes:**
- Attempting read-to-write upgrade — causes deadlock.
- Using ReadWriteLock for write-heavy workloads where the write lock overhead dominates.

**Quick revision notes:**
Multiple concurrent readers, one exclusive writer. Downgrade allowed (write→read), upgrade NOT (deadlock risk). Best for read-heavy data (caches, routing tables). Write lock acquisition waits for all readers to finish.

---

### 3.3 StampedLock (Java 8+)

**Difficulty:** Hard | **Interview Frequency:** Medium

**Companies:** Goldman Sachs, Google, high-frequency trading firms

**Short Answer:**
`StampedLock` is a higher-performance alternative to `ReentrantReadWriteLock` with three modes: write, pessimistic read, and optimistic read. Optimistic read is non-blocking — it reads without acquiring a lock, then validates the stamp. StampedLock is not reentrant and not reusable after interruption.

**Deep Explanation:**

The key innovation is optimistic reading:
1. Get a stamp from `tryOptimisticRead()` — this is just a version number, no actual lock
2. Read the data
3. Validate the stamp via `validate(stamp)` — if another thread wrote between step 1 and 3, the stamp is invalid
4. If invalid, fall back to a full pessimistic read lock

This eliminates lock acquisition overhead entirely for readers when there are no concurrent writes — the common case in read-heavy workloads.

```java
StampedLock sl = new StampedLock();

// Optimistic read
long stamp = sl.tryOptimisticRead();
// read fields
if (!sl.validate(stamp)) {
    // someone wrote — upgrade to pessimistic read
    stamp = sl.readLock();
    try {
        // re-read fields
    } finally {
        sl.unlockRead(stamp);
    }
}
```

Critical warnings about StampedLock:
1. NOT reentrant — acquiring the write lock while holding a read lock deadlocks immediately.
2. Stamps are not reusable — after `unlock`, the stamp is invalid.
3. Not interruptible in the same way as ReentrantLock.
4. Cannot use it as a Condition variable.

**Real-world backend example:**
A high-frequency trading system maintains a real-time order book (price levels and quantities). Reads happen thousands of times per millisecond; writes (order fills) are much less frequent. StampedLock's optimistic read eliminates lock overhead for the dominant read path.

**Java 17 code example:**
```java
import java.util.concurrent.locks.StampedLock;

public class Point {

    private double x, y;
    private final StampedLock sl = new StampedLock();

    public void move(double deltaX, double deltaY) {
        long stamp = sl.writeLock();
        try {
            x += deltaX;
            y += deltaY;
        } finally {
            sl.unlockWrite(stamp);
        }
    }

    public double distanceFromOrigin() {
        // Try optimistic read first
        long stamp = sl.tryOptimisticRead();
        double curX = x, curY = y;

        if (!sl.validate(stamp)) {
            // Concurrent write detected — use pessimistic read
            stamp = sl.readLock();
            try {
                curX = x;
                curY = y;
            } finally {
                sl.unlockRead(stamp);
            }
        }
        return Math.sqrt(curX * curX + curY * curY);
    }
}
```

**Follow-up questions:**
- "What happens if you call writeLock() while holding a readLock() in StampedLock?"
- "How does the validate() method work internally?"
- "When should you prefer ReadWriteLock over StampedLock?"

**Quick revision notes:**
StampedLock: three modes — write, pessimistic read, optimistic read. Optimistic read is lock-free (version check). NOT reentrant — danger. Highest throughput for read-heavy + occasional-write patterns.

---

### 3.4 Lock vs synchronized — Comparison

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Goldman Sachs, Razorpay

| Feature | synchronized | ReentrantLock | ReadWriteLock | StampedLock |
|---|---|---|---|---|
| Implicit release | Yes (compiler) | No (finally required) | No | No |
| Timed tryLock | No | Yes | Yes | Yes |
| Interruptible | No | Yes | Yes | Partial |
| Fairness | No | Optional | Optional | No |
| Multiple conditions | One (wait/notify) | Multiple | N/A | No |
| Reentrancy | Yes | Yes | Yes | NO |
| Read concurrency | No | No | Yes | Yes |
| Optimistic read | No | No | No | Yes |
| JVM optimization | Biased locking, escape analysis | Less | Less | Less |

**When to use each:**
- `synchronized`: simple mutual exclusion, no special requirements. JVM can optimize heavily (lock elision, biased locking).
- `ReentrantLock`: need tryLock with timeout, interruptible waiting, multiple condition variables, or fairness.
- `ReadWriteLock`: read-heavy shared data (caches, configuration, routing tables).
- `StampedLock`: extreme performance requirement on read-heavy path, no reentrancy needed.

---

## 4. Atomic Classes

---

### 4.1 Atomic Classes and CAS

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Goldman Sachs, Google, Razorpay

**Short Answer:**
`AtomicInteger`, `AtomicLong`, `AtomicReference`, `AtomicBoolean` in `java.util.concurrent.atomic` use CAS (Compare-And-Swap) CPU instructions for lock-free thread safety. CAS atomically checks if a variable equals an expected value and, only if so, updates it. Lock-free but not wait-free — threads can retry indefinitely under contention.

**Deep Explanation:**

CAS operation:
```
boolean CAS(V: memory location, expected: old value, update: new value):
    if *V == expected:
        *V = update
        return true
    else:
        return false
    // All of the above happens atomically (single CPU instruction: CMPXCHG on x86)
```

This is implemented at the CPU level — no OS lock, no kernel call. Under low to moderate contention, it is significantly faster than a mutex.

AtomicInteger implementation of incrementAndGet:
```java
// Conceptually (actual implementation uses VarHandle in Java 9+):
public int incrementAndGet() {
    while (true) {
        int current = get();           // read current value
        int next = current + 1;        // compute new value
        if (compareAndSet(current, next)) { // atomically update if unchanged
            return next;
        }
        // Retry if CAS failed (another thread modified it)
    }
}
```

ABA problem:
A thread reads value A. Another thread changes A→B→A. First thread's CAS succeeds (sees A, expected A) but the value has changed and changed back. This matters for pointer-based data structures (linked list node was removed and re-added). Solution: `AtomicStampedReference` or `AtomicMarkableReference` which include a version counter with the reference.

```java
// ABA problem example
AtomicReference<String> ref = new AtomicReference<>("A");

// Thread 1: reads "A", plans to CAS "A" -> "C"
// Thread 2: CAS "A" -> "B" -> "A"
// Thread 1's CAS succeeds even though the value changed underneath it
```

Lock-free vs wait-free:
- Lock-free: at least one thread makes progress in finite steps (liveness guaranteed at system level). A thread may spin/retry.
- Wait-free: every thread makes progress in bounded steps. Stronger guarantee but harder to achieve.
CAS-based algorithms are lock-free, not necessarily wait-free (a thread could theoretically retry forever if constantly preempted, though in practice this is rare).

**Real-world backend example:**
A metrics collection service uses AtomicLong to count requests, errors, and latencies without locking. Under 10,000 req/s, the CAS approach is much faster than synchronized counters.

**Java 17 code example:**
```java
import java.util.concurrent.atomic.*;

public class AtomicDemo {

    private final AtomicInteger requestCount = new AtomicInteger(0);
    private final AtomicLong totalLatencyNs = new AtomicLong(0);
    private final AtomicReference<String> status = new AtomicReference<>("HEALTHY");

    public void recordRequest(long latencyNs) {
        requestCount.incrementAndGet();
        totalLatencyNs.addAndGet(latencyNs);
    }

    public double averageLatencyMs() {
        int count = requestCount.get();
        if (count == 0) return 0;
        return totalLatencyNs.get() / (count * 1_000_000.0);
    }

    // CAS-based conditional update
    public boolean tripCircuitBreaker() {
        return status.compareAndSet("HEALTHY", "OPEN"); // only first caller succeeds
    }

    // getAndUpdate — atomic read-modify-write with lambda
    public int resetCount() {
        return requestCount.getAndSet(0);
    }

    // accumulate without loop (uses internal CAS loop)
    public void addToTotal(long value) {
        totalLatencyNs.accumulateAndGet(value, Long::sum);
    }
}
```

**Follow-up questions:**
- "What is the ABA problem and how do you solve it?"
- "Is CAS wait-free?"
- "What is the difference between AtomicInteger.compareAndSet() and compareAndExchange()?"

**Common mistakes:**
- Using AtomicInteger for compound operations: `if (count.get() > 0) count.decrementAndGet()` is still a race condition. Use `updateAndGet()` or `accumulateAndGet()` with a lambda, or use explicit CAS loop.

**Quick revision notes:**
CAS = hardware atomic compare-and-swap. Lock-free, not wait-free. ABA problem with references — use AtomicStampedReference. Java 9+: VarHandle is the underlying mechanism. compareAndSet returns false on contention — caller must handle retry.

---

### 4.2 LongAdder vs AtomicLong

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Goldman Sachs, Amazon, Netflix

**Short Answer:**
`LongAdder` performs better than `AtomicLong` under high contention by maintaining a distributed set of counters (cells) and summing them on read. Under contention, threads increment different cells instead of competing for one CAS. Use LongAdder for counters/accumulators; use AtomicLong when you need CAS semantics (compareAndSet).

**Deep Explanation:**

AtomicLong under high contention:
All threads CAS the same memory location. Under contention, only one CAS succeeds per round; others spin and retry. With N threads all hammering the same location, throughput does not scale.

LongAdder (and LongAccumulator, DoubleAdder, DoubleAccumulator) from Java 8:
- Maintains a base value plus an array of Cell objects
- When base CAS fails (contention detected), thread is assigned a Cell based on a thread ID hash
- Each thread increments its Cell (low contention within a cell)
- `sum()` adds base + all cell values

Trade-off:
- `sum()` is not atomic — cells are read one by one. Under concurrent updates, sum() may return a value that was never simultaneously the "true" counter value. This is acceptable for metrics/monitoring.
- No CAS-based conditional update (`compareAndSet` does not exist on LongAdder).
- Memory cost: idle LongAdder uses more memory than AtomicLong.

```java
// LongAdder is significantly faster under high contention
LongAdder requestCount = new LongAdder();
requestCount.increment();  // add 1
requestCount.add(5);       // add N
long total = requestCount.sum(); // read (not atomic, but that's OK for counters)
requestCount.reset();      // reset to 0
long sumAndReset = requestCount.sumThenReset(); // atomic sum + reset
```

**When to use which:**
- LongAdder: high-throughput counters (request counts, error rates, byte counts), where you never need CAS semantics.
- AtomicLong: when you need `compareAndSet` (e.g., sequence number generation, version counters where the exact current value matters for the update decision).

**Real-world backend example:**
A payment service API gateway uses LongAdder to count requests per second for rate limiting statistics. Under peak load (50,000 req/s), LongAdder's distributed cells prevent CAS contention that would degrade AtomicLong's throughput.

**Java 17 code example:**
```java
import java.util.concurrent.atomic.*;

public class HighThroughputMetrics {

    // Best for high-contention counting
    private final LongAdder totalRequests  = new LongAdder();
    private final LongAdder totalErrors    = new LongAdder();
    private final LongAdder totalLatencyMs = new LongAdder();

    // Best when CAS semantics needed
    private final AtomicLong sequenceNumber = new AtomicLong(0);

    public void recordSuccess(long latencyMs) {
        totalRequests.increment();
        totalLatencyMs.add(latencyMs);
    }

    public void recordError(long latencyMs) {
        totalRequests.increment();
        totalErrors.increment();
        totalLatencyMs.add(latencyMs);
    }

    public long nextSequenceNumber() {
        return sequenceNumber.incrementAndGet(); // CAS semantics needed
    }

    public MetricSnapshot snapshot() {
        return new MetricSnapshot(
            totalRequests.sum(),
            totalErrors.sum(),
            totalLatencyMs.sum()
        );
    }

    public record MetricSnapshot(long requests, long errors, long latencyMs) {}
}
```

**Quick revision notes:**
LongAdder distributes counter across cells under contention. sum() is not atomic (acceptable for monitoring). No compareAndSet. Best for high-throughput counters. AtomicLong better when CAS semantics required.

---

## 5. Thread Pools and Executors

---

### 5.1 ExecutorService — Why Raw Threads Are Bad

**Difficulty:** Easy | **Interview Frequency:** Very High

**Companies:** Amazon, Goldman Sachs, Razorpay, Flipkart

**Short Answer:**
Creating a raw Thread per task is expensive (~1ms per creation, ~512KB stack), uncontrolled (unbounded thread growth can OOM), and hard to manage (lifecycle, error handling). ExecutorService decouples task submission from thread management and reuses threads via a pool.

**Deep Explanation:**

Problems with raw thread creation:
1. Creation overhead: allocating a native OS thread takes ~1ms and involves kernel calls.
2. Memory: each thread requires ~512KB stack (configurable). 10,000 threads = 5GB for stacks alone.
3. Context switching: too many runnable threads cause the OS scheduler to spend more time switching than executing.
4. No lifecycle management: how do you shut down all threads cleanly?
5. No backpressure: if submissions exceed capacity, you either drop tasks or OOM.

ExecutorService hierarchy:
```
Executor (execute(Runnable))
    └── ExecutorService (submit(), shutdown(), invokeAll(), invokeAny())
            └── ScheduledExecutorService (schedule(), scheduleAtFixedRate())
```

**Java 17 code example:**
```java
import java.util.concurrent.*;

public class ExecutorDemo {

    public static void main(String[] args) throws InterruptedException, ExecutionException {
        ExecutorService executor = Executors.newFixedThreadPool(4);

        // submit returns Future
        Future<String> future = executor.submit(() -> {
            Thread.sleep(100);
            return "Payment processed";
        });

        // invokeAll — submit multiple tasks, wait for all
        List<Callable<Integer>> tasks = List.of(
            () -> processPayment(1),
            () -> processPayment(2),
            () -> processPayment(3)
        );
        List<Future<Integer>> results = executor.invokeAll(tasks, 5, TimeUnit.SECONDS);

        // invokeAny — return first successful result
        String fastestResult = executor.invokeAny(List.of(
            () -> callFraudCheckPrimary(),
            () -> callFraudCheckFallback()
        ));

        System.out.println(future.get());

        // Proper shutdown sequence
        executor.shutdown(); // no new tasks accepted, existing tasks complete
        if (!executor.awaitTermination(30, TimeUnit.SECONDS)) {
            executor.shutdownNow(); // interrupt running tasks
        }
    }

    private static int processPayment(int id) { return id * 100; }
    private static String callFraudCheckPrimary() throws Exception { Thread.sleep(50); return "primary"; }
    private static String callFraudCheckFallback() throws Exception { Thread.sleep(80); return "fallback"; }
}
```

**Follow-up questions:**
- "What is the difference between shutdown() and shutdownNow()?"
- "What happens to tasks submitted after shutdown()?"
- "How does invokeAny() handle cancellation of the losing tasks?"

**Quick revision notes:**
ExecutorService: decouples task from thread lifecycle. submit() returns Future. invokeAll() waits for all. invokeAny() returns first success, cancels others. shutdown() graceful, shutdownNow() interrupts running.

---

### 5.2 ThreadPoolExecutor Internals

**Difficulty:** Hard | **Interview Frequency:** Very High

**Companies:** Goldman Sachs, Amazon, Google, Razorpay, Netflix

**Short Answer:**
ThreadPoolExecutor accepts tasks through this flow: if fewer than `corePoolSize` threads are running, create a new thread. Else, offer to the work queue. If the queue is full, create a new thread up to `maximumPoolSize`. If that is also full, apply the rejection policy. Core threads stay alive indefinitely; extra threads idle for `keepAliveTime`.

**Deep Explanation:**

Constructor:
```java
new ThreadPoolExecutor(
    int corePoolSize,      // minimum threads, always maintained (even idle)
    int maximumPoolSize,   // maximum threads allowed
    long keepAliveTime,    // idle time before extra threads are terminated
    TimeUnit unit,
    BlockingQueue<Runnable> workQueue,
    ThreadFactory threadFactory,
    RejectedExecutionHandler handler
)
```

Task acceptance algorithm:
```
submit(task):
    1. if running threads < corePoolSize:
       → create new thread, run task (even if idle threads exist)
    2. else if queue.offer(task) succeeds:
       → task queued
    3. else if running threads < maximumPoolSize:
       → create new thread, run task
    4. else:
       → apply RejectedExecutionHandler
```

Note: extra threads (above corePoolSize) are created only when the queue is FULL. If you use an unbounded queue (LinkedBlockingQueue without capacity), `maximumPoolSize` is never reached — the queue absorbs all tasks. This is the behavior of `Executors.newFixedThreadPool`.

Four built-in rejection policies:
1. `AbortPolicy` (default): throws `RejectedExecutionException`
2. `CallerRunsPolicy`: runs the task on the submitting thread (provides backpressure)
3. `DiscardPolicy`: silently discards the task
4. `DiscardOldestPolicy`: discards the oldest queued task and retries submission

Queue types and their impact:
- `SynchronousQueue`: no buffer — every submission must hand off to a thread (maximumPoolSize matters). Used by `newCachedThreadPool`.
- `LinkedBlockingQueue(unbounded)`: tasks always queue, max threads never exceed corePoolSize.
- `ArrayBlockingQueue(bounded)`: bounded, when full triggers thread creation up to maxPoolSize, then rejection.
- `PriorityBlockingQueue`: tasks ordered by priority.

**Real-world backend example (payment service):**
```
Payment API ThreadPool configuration:
corePoolSize    = 10    (handles normal load)
maximumPoolSize = 50    (handles burst traffic)
keepAliveTime   = 60s   (extra threads live 60s before termination)
workQueue       = ArrayBlockingQueue(500)   (bounded — forces rejection over OOM)
rejection       = CallerRunsPolicy          (backpressure to HTTP acceptor)
```

With CallerRunsPolicy, when the pool is at capacity, the Tomcat acceptor thread itself runs the payment task — preventing new HTTP connections from being accepted until load reduces. This is natural backpressure.

**Java 17 code example:**
```java
import java.util.concurrent.*;

public class PaymentServiceExecutor {

    public static ThreadPoolExecutor createPaymentPool() {
        return new ThreadPoolExecutor(
            10,                              // core threads
            50,                              // max threads
            60L, TimeUnit.SECONDS,           // keepAlive
            new ArrayBlockingQueue<>(500),   // bounded queue
            new ThreadFactory() {
                private int count = 0;
                public Thread newThread(Runnable r) {
                    Thread t = new Thread(r, "payment-worker-" + ++count);
                    t.setDaemon(false);
                    return t;
                }
            },
            new ThreadPoolExecutor.CallerRunsPolicy() // backpressure
        );
    }

    public static void main(String[] args) throws InterruptedException {
        ThreadPoolExecutor pool = createPaymentPool();

        // Monitor pool state
        System.out.printf("Pool size: %d, Queue size: %d, Completed: %d%n",
            pool.getPoolSize(),
            pool.getQueue().size(),
            pool.getCompletedTaskCount()
        );

        pool.shutdown();
        pool.awaitTermination(30, TimeUnit.SECONDS);
    }
}
```

**Follow-up questions:**
- "What happens with newFixedThreadPool when the queue fills up?"
- "Why does newCachedThreadPool use SynchronousQueue?"
- "How do you implement a custom rejection handler that logs and retries?"

**Common mistakes:**
- Using `LinkedBlockingQueue` (unbounded) with a maximumPoolSize — the max is never reached, making it misleading.
- Not naming threads (debugging a thread dump with thread names like "pool-1-thread-47" is painful).
- Using CallerRunsPolicy without understanding it blocks the submitter thread.

**Interview traps:**
- "Does maximumPoolSize apply when you use an unbounded queue?" No — an unbounded queue never fills, so the executor never creates threads beyond corePoolSize.

**Quick revision notes:**
Task flow: core threads → queue → max threads → rejection. Bounded queue critical in production. CallerRunsPolicy = backpressure. SynchronousQueue = direct handoff, queue never holds tasks. Name your threads.

---

### 5.3 Executors Factory Methods

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Razorpay, Flipkart, Paytm

| Factory | Threads | Queue | Use Case | Production Risk |
|---|---|---|---|---|
| `newFixedThreadPool(n)` | Core=Max=n | Unbounded LinkedBlockingQueue | Known concurrency bound | Queue grows unbounded → OOM |
| `newCachedThreadPool()` | Core=0, Max=Integer.MAX_VALUE | SynchronousQueue | Many short-lived tasks | Unlimited threads → OOM |
| `newSingleThreadExecutor()` | 1 | Unbounded LinkedBlockingQueue | Sequential task ordering | Single point of failure, unbounded queue |
| `newScheduledThreadPool(n)` | Core=n, Max=MAX_VALUE | DelayedWorkQueue | Periodic/delayed tasks | Scheduled tasks can pile up |

Why `newCachedThreadPool` is dangerous in production:
`maximumPoolSize = Integer.MAX_VALUE`. Under a burst, it creates one OS thread per submitted task. On a server receiving 50,000 requests/second, it would try to create 50,000 threads, consuming ~25GB of stack memory alone, and crashing the JVM with OutOfMemoryError.

The Sonar rule "java:S2190" flags `Executors.newCachedThreadPool()` in production code. Always use a custom `ThreadPoolExecutor` with bounded queue and explicit rejection policy.

**Java 17 code example:**
```java
// NEVER in production:
ExecutorService dangerous = Executors.newCachedThreadPool();

// Safe alternative for IO-bound tasks:
ExecutorService safe = new ThreadPoolExecutor(
    50, 200,
    60L, TimeUnit.SECONDS,
    new ArrayBlockingQueue<>(1000),
    Executors.defaultThreadFactory(),
    new ThreadPoolExecutor.AbortPolicy()
);
```

**Quick revision notes:**
newCachedThreadPool = unbounded threads, dangerous. newFixedThreadPool = unbounded queue, dangerous. In production: always use custom ThreadPoolExecutor with bounded queue. newSingleThreadExecutor for sequential ordering guarantee.

---

### 5.4 ForkJoinPool

**Difficulty:** Hard | **Interview Frequency:** Medium

**Companies:** Amazon, Google

**Short Answer:**
ForkJoinPool uses a work-stealing algorithm — idle threads steal tasks from the back of other threads' deques. Designed for recursive divide-and-conquer tasks. It is the pool behind parallel streams and `CompletableFuture.runAsync()` (common pool). Uses ForkJoinTask, RecursiveTask (returns value), RecursiveAction (void).

**Deep Explanation:**

Work-stealing algorithm:
- Each thread has a deque (double-ended queue) of tasks.
- A thread pushes/pops its own tasks from the front (LIFO — better cache locality for recursive tasks).
- When idle, a thread steals tasks from the BACK of another thread's deque (FIFO — steals the largest chunks).

This provides excellent load balancing: threads that finish their sub-tasks steal from threads that have large pending sub-trees.

ForkJoinPool common pool (Java 8+):
`ForkJoinPool.commonPool()` is shared across the JVM. Parallelism = `Runtime.availableProcessors() - 1`. Used by parallel streams and default CompletableFuture.

Warning: long-blocking tasks in the common pool can starve parallel streams across the application. Use a custom ForkJoinPool for blocking tasks.

**Java 17 code example:**
```java
import java.util.concurrent.*;

public class MergeSort extends RecursiveAction {

    private final int[] array;
    private final int from, to;
    private static final int THRESHOLD = 1000;

    public MergeSort(int[] array, int from, int to) {
        this.array = array; this.from = from; this.to = to;
    }

    @Override
    protected void compute() {
        if (to - from < THRESHOLD) {
            sortSequentially(array, from, to);
            return;
        }
        int mid = (from + to) / 2;
        MergeSort left  = new MergeSort(array, from, mid);
        MergeSort right = new MergeSort(array, mid, to);
        invokeAll(left, right); // fork both, join both
        merge(array, from, mid, to);
    }

    private void sortSequentially(int[] a, int f, int t) {
        java.util.Arrays.sort(a, f, t);
    }

    private void merge(int[] a, int f, int m, int t) {
        int[] tmp = java.util.Arrays.copyOfRange(a, f, t);
        // standard merge...
    }

    public static void main(String[] args) {
        int[] data = new int[1_000_000];
        // fill with random data
        ForkJoinPool pool = new ForkJoinPool(Runtime.getRuntime().availableProcessors());
        pool.invoke(new MergeSort(data, 0, data.length));
    }
}
```

**Quick revision notes:**
ForkJoinPool: work-stealing. RecursiveTask (returns value) / RecursiveAction (void). Common pool behind parallel streams. Long blocking tasks in common pool harm other parallel stream users — use custom pool.

---

### 5.5 Thread Pool Sizing

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Goldman Sachs, Amazon, Netflix

**Short Answer:**
For CPU-bound tasks: `N + 1` threads (N = available processors). The +1 handles one thread blocking on I/O or page fault without wasting a core. For I/O-bound tasks: `N * (1 + W/C)` where W = average wait time (I/O), C = average compute time. Higher W/C means more threads to keep CPUs busy.

**Deep Explanation:**

CPU-bound formula: `N_threads = N_cpu + 1`
- N_cpu threads fully utilize N_cpu cores.
- The +1 provides one spare thread to run if any thread gets temporarily blocked (page fault, GC pause).
- More threads than N+1 causes context switching overhead that exceeds the benefit.

I/O-bound formula: `N_threads = N_cpu * (1 + W/C)`
- Example: N_cpu = 8, each task spends 90ms waiting for DB, 10ms computing. W/C = 9.
- N_threads = 8 * (1 + 9) = 80 threads. All 8 cores stay busy while threads wait for I/O.
- Practical cap: you cannot exceed the I/O system's capacity (DB connection pool size, network bandwidth).

In practice: start with the formula, then load-test and measure CPU utilization, queue length, and latency. The formula is a starting point, not a law. Little's Law (`L = λ * W`) also applies: average concurrency = throughput * average latency.

**Real-world backend example:**
A payment service calls an external fraud check API (200ms average latency, 10ms processing). With 4 cores: 4 * (1 + 200/10) = 84 threads. But the fraud check service can only handle 100 concurrent connections — so 84 is conveniently within that limit.

**Quick revision notes:**
CPU-bound: N+1 threads. IO-bound: N*(1 + W/C). Over-threading wastes memory and causes context switching. Validate with load testing and CPU utilization measurement.

---

## 6. Concurrent Collections

---

### 6.1 ConcurrentHashMap — Concurrency-Specific Operations

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Goldman Sachs, Google, Razorpay

**Short Answer:**
ConcurrentHashMap's segment-level locking (Java 7) evolved to node-level locking (Java 8+). Beyond thread-safe get/put, atomic compound operations are critical: `putIfAbsent`, `computeIfAbsent`, `compute`, and `merge` execute as single atomic operations — they read-modify-write without the check-then-act race.

**Deep Explanation:**

Java 8+ ConcurrentHashMap:
- Lock-free reads (volatile reads of node array)
- Node-level synchronized writes (locks only the head of each bucket's linked list)
- Full lock only for resizing and some aggregate operations

Critical atomic compound operations:

```java
ConcurrentHashMap<String, Integer> map = new ConcurrentHashMap<>();

// putIfAbsent — atomic: only inserts if key absent
Integer prev = map.putIfAbsent("key", 1); // returns null if inserted, old value if present

// computeIfAbsent — atomic: compute and insert if absent (great for cache initialization)
List<String> list = map.computeIfAbsent("users", k -> new ArrayList<>());

// compute — atomic: read current value, apply function, update
map.compute("counter", (k, v) -> v == null ? 1 : v + 1);

// merge — atomic: if absent insert value, else apply BinaryOperator to old+new
map.merge("counter", 1, Integer::sum);
```

Why these methods matter for correctness:
```java
// WRONG — not atomic, race condition
if (!map.containsKey(key)) {
    map.put(key, expensiveCompute(key)); // another thread could insert between check and put
}

// CORRECT — atomic
map.computeIfAbsent(key, k -> expensiveCompute(k));
```

Warning: `computeIfAbsent` and `compute` hold the node lock while the function executes. Do NOT do I/O, call other ConcurrentHashMap operations, or call anything that could block in the compute function — this can cause deadlock or performance issues.

**Real-world backend example:**
An API gateway maintains a per-client rate limiter map: `ConcurrentHashMap<ClientId, RateLimiter>`. `computeIfAbsent` ensures only one RateLimiter is created per client even under concurrent requests from the same client.

**Java 17 code example:**
```java
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

public class RateLimiterRegistry {

    private final ConcurrentHashMap<String, AtomicInteger> requestCounts
        = new ConcurrentHashMap<>();

    public boolean tryAcquire(String clientId, int maxRequestsPerSecond) {
        // Atomically create counter if absent, then atomically increment and check
        AtomicInteger counter = requestCounts.computeIfAbsent(
            clientId,
            k -> new AtomicInteger(0)
        );
        int count = counter.incrementAndGet();
        return count <= maxRequestsPerSecond;
    }

    // Periodic reset using replaceAll
    public void resetCounts() {
        requestCounts.replaceAll((k, v) -> new AtomicInteger(0));
    }

    // Aggregate using reduce
    public long totalRequests() {
        return requestCounts.reduceValues(100, v -> (long) v.get(), Long::sum);
    }
}
```

**Quick revision notes:**
computeIfAbsent/compute/merge are atomic compound operations — use these over separate check-then-act. Node-level locking in Java 8+. Do not block inside compute functions. size() is approximate under concurrent modification.

---

### 6.2 CopyOnWriteArrayList

**Difficulty:** Medium | **Interview Frequency:** Medium

**Companies:** Goldman Sachs, Amazon, Adobe

**Short Answer:**
`CopyOnWriteArrayList` creates a fresh copy of the underlying array on every write (add, set, remove). Reads are lock-free and iterate over a snapshot. Ideal when reads dominate and writes are rare. Very expensive for frequent writes due to the full array copy.

**Deep Explanation:**

Mechanism:
```java
// Internal write (add):
synchronized (lock) {
    Object[] elements = getArray();
    Object[] newElements = Arrays.copyOf(elements, elements.length + 1);
    newElements[elements.length] = e;
    setArray(newElements);
    return true;
}
```

Read mechanism: `getArray()` returns a volatile reference. No locking. Iterator captures the array reference at the time of iterator creation — iterating over a CopyOnWriteArrayList never throws ConcurrentModificationException, even if the list is modified during iteration.

Use cases:
- Event listener lists (read many times per event, modified rarely on registration/deregistration)
- Application routing tables read by every request, updated only on config reload
- Observer pattern subscriber lists

Cost analysis:
- Read: O(1) or O(n) for iteration — fully lock-free
- Write: O(n) — full array copy for every mutation
- Memory: two copies of the array exist briefly during a write

For a list of 10,000 listeners: every write allocates and copies 10,000 elements. If writes happen frequently, use `ConcurrentLinkedDeque` or a `ReadWriteLock`-protected `ArrayList` instead.

**Java 17 code example:**
```java
import java.util.concurrent.CopyOnWriteArrayList;

public class EventBus {

    private final CopyOnWriteArrayList<EventListener> listeners
        = new CopyOnWriteArrayList<>();

    public void subscribe(EventListener listener) {
        listeners.add(listener); // creates copy, expensive but rare
    }

    public void unsubscribe(EventListener listener) {
        listeners.remove(listener);
    }

    public void publish(Event event) {
        // Snapshot iteration — lock-free, never throws ConcurrentModificationException
        for (EventListener listener : listeners) {
            listener.onEvent(event); // safe even if listeners modified during iteration
        }
    }

    interface EventListener { void onEvent(Event e); }
    record Event(String type, Object payload) {}
}
```

**Quick revision notes:**
CopyOnWriteArrayList: writes copy entire array (expensive). Reads lock-free. Iterators see snapshot, no ConcurrentModificationException. Use for event listeners, subscriber lists. Not for high-write scenarios.

---

### 6.3 BlockingQueue

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Goldman Sachs, Amazon, Razorpay, Flipkart

**Short Answer:**
`BlockingQueue` is a thread-safe queue with blocking operations: `put()` blocks when full, `take()` blocks when empty. It is the foundation of producer-consumer patterns in Java. Implementations: ArrayBlockingQueue (bounded, array-backed), LinkedBlockingQueue (optionally bounded), SynchronousQueue (no buffer — direct handoff), PriorityBlockingQueue (unbounded, priority-ordered).

**Deep Explanation:**

BlockingQueue API:

| Operation | Throws exception | Returns special value | Blocks | Times out |
|---|---|---|---|---|
| Insert | add() | offer() | put() | offer(e, time, unit) |
| Remove | remove() | poll() | take() | poll(time, unit) |
| Examine | element() | peek() | — | — |

Implementation comparison:

| Implementation | Bounded | Backing | Lock Strategy | Use Case |
|---|---|---|---|---|
| ArrayBlockingQueue | Yes (mandatory) | Array | Single ReentrantLock | Predictable memory, fair option |
| LinkedBlockingQueue | Optional | Linked nodes | Separate put/take locks | Higher throughput than Array |
| SynchronousQueue | N/A (size=0) | None | CAS / lock | Direct handoff, thread pools |
| PriorityBlockingQueue | No | Heap | Single lock | Priority-ordered task processing |
| DelayQueue | No | Heap + Delay | Lock | Scheduled task execution |

LinkedBlockingQueue has separate locks for put and take, allowing producers and consumers to proceed simultaneously (unlike ArrayBlockingQueue which uses one lock for both). This gives higher throughput when production and consumption are balanced.

SynchronousQueue has no internal storage — every put must be matched by a take, and vice versa. It is used in `newCachedThreadPool` to hand tasks directly to waiting threads (or create a new thread if none are waiting).

**Real-world backend example:**
A payment processing pipeline uses a bounded `ArrayBlockingQueue(1000)` between order validation and payment execution. If payment execution falls behind, the queue fills, and order validation threads block on `put()` — natural backpressure that prevents the system from taking in more work than it can process.

**Java 17 code example:**
```java
import java.util.concurrent.*;

public class PaymentPipeline {

    private final BlockingQueue<PaymentRequest> queue = new ArrayBlockingQueue<>(1000);

    // Producer — order validation service
    public class OrderValidator implements Runnable {
        @Override
        public void run() {
            while (!Thread.currentThread().isInterrupted()) {
                try {
                    PaymentRequest request = fetchNextOrder();
                    if (validate(request)) {
                        queue.put(request); // blocks if queue full — backpressure
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        }
        private PaymentRequest fetchNextOrder() { return new PaymentRequest(); }
        private boolean validate(PaymentRequest r) { return true; }
    }

    // Consumer — payment execution service
    public class PaymentExecutor implements Runnable {
        @Override
        public void run() {
            while (!Thread.currentThread().isInterrupted()) {
                try {
                    PaymentRequest request = queue.poll(100, TimeUnit.MILLISECONDS);
                    if (request != null) {
                        processPayment(request);
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        }
        private void processPayment(PaymentRequest r) { /* payment logic */ }
    }

    static class PaymentRequest {}
}
```

**Quick revision notes:**
put() blocks when full, take() blocks when empty. ArrayBlockingQueue: bounded, single lock. LinkedBlockingQueue: separate put/take locks, higher throughput. SynchronousQueue: zero-capacity, direct handoff. Use for producer-consumer with backpressure.

---

## 7. Concurrency Problems

---

### 7.1 Deadlock

**Difficulty:** Hard | **Interview Frequency:** Very High

**Companies:** Goldman Sachs, Amazon, Google, Morgan Stanley, Razorpay

**Short Answer:**
Deadlock occurs when two or more threads permanently wait for each other to release locks. Four necessary conditions: mutual exclusion, hold-and-wait, no preemption, and circular wait. Detect with thread dumps. Prevent with lock ordering, tryLock with timeout, or lock-free algorithms.

**Deep Explanation:**

Four Coffman conditions (ALL four must be present):
1. **Mutual exclusion**: resources cannot be shared (only one thread can hold a lock at a time).
2. **Hold and wait**: a thread holds at least one lock and waits for another.
3. **No preemption**: locks cannot be forcibly taken from a thread — it must release voluntarily.
4. **Circular wait**: thread A waits for thread B which waits for thread A (or longer cycle).

Classic deadlock:
```java
// Thread 1: acquires accountA, then tries accountB
// Thread 2: acquires accountB, then tries accountA
// → Deadlock

public void transfer(Account from, Account to, double amount) {
    synchronized (from) {          // T1 holds accountA, T2 holds accountB
        synchronized (to) {        // T1 waits for accountB, T2 waits for accountA
            from.debit(amount);
            to.credit(amount);
        }
    }
}
```

Prevention strategies:

1. **Lock ordering**: always acquire locks in the same global order. Use a consistent identifier (account ID) to determine order.
```java
public void transfer(Account from, Account to, double amount) {
    Account first  = from.getId() < to.getId() ? from : to;
    Account second = from.getId() < to.getId() ? to : from;
    synchronized (first) {
        synchronized (second) {
            from.debit(amount);
            to.credit(amount);
        }
    }
}
```

2. **tryLock with timeout**: if you cannot acquire the second lock within the timeout, release the first and retry.
```java
boolean transferred = false;
while (!transferred) {
    if (from.lock.tryLock(50, TimeUnit.MILLISECONDS)) {
        try {
            if (to.lock.tryLock(50, TimeUnit.MILLISECONDS)) {
                try {
                    from.debit(amount);
                    to.credit(amount);
                    transferred = true;
                } finally {
                    to.lock.unlock();
                }
            }
        } finally {
            from.lock.unlock();
        }
    }
    if (!transferred) Thread.sleep(randomBackoff()); // avoid livelock
}
```

3. **Single global lock**: use one lock for all inter-account operations. Simpler, but serializes all transfers.

4. **Lock-free**: use atomic operations at the database level (row-level locking, optimistic concurrency with version columns).

Detection: thread dump (`kill -3 <pid>` on Linux, `jstack <pid>`) shows DEADLOCK analysis and the cycle. Tools: VisualVM, JConsole, Java Flight Recorder.

**Real-world backend example:**
Payment service deadlock: Thread 1 processes transfer A→B (locks account A, then B). Thread 2 processes transfer B→A (locks account B, then A). Fixed at Goldman Sachs-level systems by normalizing lock order by account number.

**Java 17 code example:**
```java
import java.util.concurrent.locks.*;

public class DeadlockFreeTransfer {

    record Account(long id, ReentrantLock lock, double[] balance) {
        Account(long id, double initialBalance) {
            this(id, new ReentrantLock(), new double[]{initialBalance});
        }
    }

    public static boolean transfer(Account from, Account to, double amount)
            throws InterruptedException {

        // Always acquire in natural order — prevents circular wait
        Account first  = from.id() < to.id() ? from : to;
        Account second = from.id() < to.id() ? to : from;

        if (first.lock().tryLock(100, java.util.concurrent.TimeUnit.MILLISECONDS)) {
            try {
                if (second.lock().tryLock(100, java.util.concurrent.TimeUnit.MILLISECONDS)) {
                    try {
                        if (from.balance()[0] < amount) return false;
                        from.balance()[0] -= amount;
                        to.balance()[0]   += amount;
                        return true;
                    } finally {
                        second.lock().unlock();
                    }
                }
            } finally {
                first.lock().unlock();
            }
        }
        return false; // caller should retry
    }
}
```

**Follow-up questions:**
- "How do you detect a deadlock in production?"
- "Can you have a deadlock with a single lock?"
- "What is the difference between deadlock prevention and deadlock avoidance?"

**Common mistakes:**
- Acquiring locks in different orders in different code paths.
- Not releasing locks in finally blocks.
- Calling synchronized methods on two different objects inside a synchronized block.

**Quick revision notes:**
Deadlock = circular wait for locks. Four conditions: mutual exclusion, hold-and-wait, no preemption, circular wait. Fix: consistent lock ordering, tryLock with timeout. Detect: jstack / thread dump. Prevention > detection in production.

---

### 7.2 Livelock

**Difficulty:** Medium | **Interview Frequency:** Medium

**Companies:** Google, Goldman Sachs

**Short Answer:**
Livelock is when threads keep changing state in response to each other but neither makes progress. Unlike deadlock, threads are not blocked — they are actively running but accomplishing nothing. Classic example: two people in a narrow corridor, both moving aside in the same direction repeatedly.

**Deep Explanation:**

Livelock in the transfer retry example (from deadlock section):
```java
// If both threads always retry at the same time with the same backoff:
// Thread 1: acquire A, fail on B, release A, wait 50ms
// Thread 2: acquire B, fail on A, release B, wait 50ms
// Thread 1: acquire A, fail on B, release A, wait 50ms...
// → Livelock — both threads continuously active, no progress
```

Solution: randomized exponential backoff. Add a random jitter to the sleep/retry interval. Each retry doubles the wait time up to a maximum (similar to TCP's backoff for collision avoidance).

```java
long backoff = 10;
while (!transferred) {
    // try to transfer
    if (!success) {
        Thread.sleep(backoff + ThreadLocalRandom.current().nextLong(backoff));
        backoff = Math.min(backoff * 2, 1000); // cap at 1 second
    }
}
```

**Quick revision notes:**
Livelock: threads active but no progress — stuck in mutual interference loop. Different from deadlock (no blocking). Fix: randomized exponential backoff. Common in retry-based lock acquisition.

---

### 7.3 Starvation

**Difficulty:** Medium | **Interview Frequency:** Medium

**Companies:** Goldman Sachs, Amazon

**Short Answer:**
Starvation occurs when a thread is perpetually denied access to a resource (CPU time, lock) because other threads are constantly given priority. A high-priority thread continuously preempting lower-priority threads, or a non-fair lock always granting access to newly arriving threads over waiting threads, causes starvation.

**Deep Explanation:**

Causes:
1. Non-fair locking: synchronized and default ReentrantLock allow "barge-in" — a new thread can acquire a just-released lock before waiting threads get it.
2. Thread priority: setting high priority on threads that monopolize CPU.
3. Long critical sections: one thread holds a lock for a long time, starving others.

Solutions:
1. Fair ReentrantLock: `new ReentrantLock(true)` — FIFO ordering guarantees eventually all threads progress.
2. Limit long critical sections.
3. Use ConcurrentHashMap and concurrent collections instead of synchronized HashMap with a global lock.

Priority inversion (related concept): A high-priority thread waiting for a resource held by a low-priority thread — medium-priority threads run instead, preventing the low-priority thread from releasing the resource. Solution: priority inheritance (OS-level) or redesigning lock usage.

**Quick revision notes:**
Starvation: thread never gets CPU/lock. Causes: non-fair lock barge-in, thread priority misuse, long critical sections. Fix: fair locks, bounded wait, priority inheritance protocol.

---

### 7.4 Race Condition

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Goldman Sachs, Amazon, Google, Razorpay, Morgan Stanley

**Short Answer:**
A race condition is when the correctness of a program depends on the relative timing of thread operations. Check-then-act is the canonical pattern: check a condition, then act based on it — but another thread can change the condition between the check and the act.

**Deep Explanation:**

Classic check-then-act:
```java
// WRONG — race condition
public boolean withdraw(double amount) {
    if (balance >= amount) {        // check: passes if balance = 100, amount = 100
        // ← another thread can withdraw 100 here, making balance = 0
        balance -= amount;          // act: balance becomes -100
        return true;
    }
    return false;
}
```

The window between check and act is a race window. Under concurrent access, the invariant (balance >= 0) is violated.

Types of race conditions:
1. **Check-then-act**: `if (condition) { act }` — condition changes between check and act.
2. **Read-modify-write**: `count++` — non-atomic operation on shared variable.
3. **Put-if-absent**: `if (!map.containsKey(k)) map.put(k, v)` — key can be inserted between check and put.

Solutions:
1. Synchronization: lock the entire check-act as a single critical section.
2. Atomic operations: `AtomicInteger.compareAndSet()` for read-modify-write.
3. Concurrent collection methods: `ConcurrentHashMap.putIfAbsent()`, `computeIfAbsent()`.
4. Immutability: objects that cannot change state have no race conditions.

**Real-world backend example:**
A payment service with a daily limit: "check if user has remaining daily limit, then deduct." Without synchronization, two concurrent payments can both pass the check and both deduct, exceeding the limit. Fix: database row-level lock (`SELECT ... FOR UPDATE`) or optimistic locking with version column.

**Java 17 code example:**
```java
import java.util.concurrent.atomic.AtomicLong;

public class DailyLimitAccount {

    private final AtomicLong remainingLimit;

    public DailyLimitAccount(long dailyLimit) {
        this.remainingLimit = new AtomicLong(dailyLimit);
    }

    // WRONG: check-then-act race condition
    public boolean withdrawUnsafe(long amount) {
        if (remainingLimit.get() >= amount) {   // check
            remainingLimit.addAndGet(-amount);   // act — race window here
            return true;
        }
        return false;
    }

    // CORRECT: atomic CAS-based approach
    public boolean withdraw(long amount) {
        while (true) {
            long current = remainingLimit.get();
            if (current < amount) return false;
            long updated = current - amount;
            if (remainingLimit.compareAndSet(current, updated)) {
                return true; // atomically decremented
            }
            // CAS failed: another thread changed the value, retry
        }
    }
}
```

**Follow-up questions:**
- "How is a race condition different from a data race?"
- "Can you have a race condition with immutable objects?"
- "How does Java's memory model relate to race conditions?"

**Common mistakes:**
- Thinking volatile fixes race conditions on compound operations.
- Synchronizing the check and act in separate synchronized methods (two separate lock acquisitions, race window between them).

**Quick revision notes:**
Race condition: timing-dependent correctness failure. Check-then-act and read-modify-write are most common. Fix: single atomic operation (CAS, synchronized block covering both check and act, concurrent collection compound methods).

---

## 8. Real-World Patterns

---

### 8.1 Producer-Consumer Pattern

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Goldman Sachs, Amazon, Razorpay, Flipkart

**Short Answer:**
Producer-Consumer decouples producers (task generators) from consumers (task processors) using a BlockingQueue as the buffer. BlockingQueue handles all synchronization: put() blocks when full, take() blocks when empty. No explicit wait/notify needed.

**Deep Explanation:**

Why BlockingQueue is superior to wait/notify-based implementation:
- No explicit synchronization code — BlockingQueue handles it
- Backpressure built in (bounded queue blocks producers when consumers fall behind)
- Easy to scale (add more consumer threads)
- Natural shutdown: poison pill pattern (special sentinel value signals consumers to stop)

Poison pill shutdown:
```java
// Producers send a sentinel value to signal end of work
static final PaymentRequest POISON_PILL = new PaymentRequest(null);

// Consumer:
while (true) {
    PaymentRequest req = queue.take();
    if (req == POISON_PILL) {
        queue.put(POISON_PILL); // re-publish for other consumers
        break;
    }
    process(req);
}
```

**Real-world backend example:**
Razorpay's payment processing: HTTP request handlers (producers) place payment requests into a bounded BlockingQueue. A pool of payment processors (consumers) take from the queue. When all payment processors are busy (queue full), the HTTP handlers block on put() — preventing the system from accepting more requests than it can process.

**Java 17 code example:**
```java
import java.util.concurrent.*;

public class PaymentProcessingPipeline {

    private static final int QUEUE_CAPACITY = 500;
    private static final PaymentRequest POISON = new PaymentRequest("POISON");

    private final BlockingQueue<PaymentRequest> queue
        = new ArrayBlockingQueue<>(QUEUE_CAPACITY);
    private final ExecutorService consumerPool
        = Executors.newFixedThreadPool(10);

    public void startConsumers() {
        for (int i = 0; i < 10; i++) {
            consumerPool.submit(this::consumeLoop);
        }
    }

    private void consumeLoop() {
        while (!Thread.currentThread().isInterrupted()) {
            try {
                PaymentRequest req = queue.poll(1, TimeUnit.SECONDS);
                if (req == null) continue;
                if (req == POISON) {
                    queue.put(POISON); // signal remaining consumers
                    return;
                }
                processPayment(req);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }
        }
    }

    // Producer
    public void submitPayment(PaymentRequest req) throws InterruptedException {
        queue.put(req); // blocks if queue full — backpressure
    }

    public void shutdown() throws InterruptedException {
        queue.put(POISON); // signal all consumers to stop
        consumerPool.shutdown();
        consumerPool.awaitTermination(30, TimeUnit.SECONDS);
    }

    private void processPayment(PaymentRequest req) {
        System.out.println("Processing: " + req.id());
    }

    record PaymentRequest(String id) {}
}
```

**Follow-up questions:**
- "How do you handle a consumer that throws an exception during processing?"
- "How would you implement a priority-based payment queue?"
- "How do you gracefully shut down a producer-consumer pipeline?"

**Quick revision notes:**
Producer-Consumer: BlockingQueue as buffer. put() = backpressure, take() = blocking wait. Poison pill for graceful shutdown. Decouples production rate from consumption rate.

---

### 8.2 ThreadLocal Variables

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Goldman Sachs, Amazon, Atlassian, Razorpay

**Short Answer:**
`ThreadLocal<T>` provides a per-thread variable — each thread has its own copy, isolated from other threads. Used for per-thread contexts like database connections, user session info in web request handling. Critical warning: in thread pool environments, always call `remove()` when done to prevent memory leaks and context bleed between requests.

**Deep Explanation:**

Internals: each Thread object has a `ThreadLocalMap` (not a static global map). A ThreadLocal acts as a key into the current thread's map. This means:
- Access is O(1) — no synchronization needed (each thread accesses its own map)
- The variable is cleaned up when the thread dies (if accessed via a strong reference that also dies)

The memory leak problem in thread pools:
Thread pool threads never die. If a ThreadLocal is set but never removed, the entry persists in the thread's ThreadLocalMap for the entire pool lifetime. Worse, since ThreadLocalMap uses weak keys (the ThreadLocal reference) but strong values, if the ThreadLocal key is garbage collected while the value is still referenced elsewhere, the value entry becomes a "phantom" entry that is never collected.

```java
// Web framework pattern — CORRECT
public class UserContext {

    private static final ThreadLocal<User> currentUser = new ThreadLocal<>();

    public static void set(User user) { currentUser.set(user); }
    public static User get() { return currentUser.get(); }
    public static void clear() { currentUser.remove(); } // MUST be called in finally

    // Servlet filter usage:
    // try {
    //     currentUser.set(authenticatedUser);
    //     chain.doFilter(request, response);
    // } finally {
    //     currentUser.remove(); // prevent leaking to next request on same thread
    // }
}
```

InheritableThreadLocal: child threads inherit the parent's ThreadLocal values at the time of creation. Used for propagating request context to child threads (e.g., logging correlation IDs into async tasks).

**Real-world backend example:**
A Spring MVC application stores the authenticated user in a ThreadLocal at the start of each request (set by a security filter) and clears it at the end. Every service and repository in the request processing chain can call `UserContext.get()` without passing the user object as a parameter. This is how Spring Security's SecurityContextHolder works.

**Java 17 code example:**
```java
import java.util.UUID;

public class RequestContext {

    private static final ThreadLocal<String> correlationId = new ThreadLocal<>();
    private static final ThreadLocal<Long>   requestStartTime = new ThreadLocal<>();

    public static void init() {
        correlationId.set(UUID.randomUUID().toString());
        requestStartTime.set(System.currentTimeMillis());
    }

    public static String getCorrelationId() {
        return correlationId.get();
    }

    public static long getRequestDuration() {
        Long start = requestStartTime.get();
        return start != null ? System.currentTimeMillis() - start : -1;
    }

    public static void clear() {
        correlationId.remove();     // prevents memory leak
        requestStartTime.remove();
    }

    // Usage in a servlet filter:
    public static void simulateRequestHandling(Runnable handler) {
        try {
            init();
            System.out.println("Request " + getCorrelationId() + " started");
            handler.run();
            System.out.println("Request " + getCorrelationId()
                + " took " + getRequestDuration() + "ms");
        } finally {
            clear(); // ALWAYS in finally — thread pool threads live forever
        }
    }
}
```

**Follow-up questions:**
- "What is the memory leak risk with ThreadLocal in a web container?"
- "How does Spring Security use ThreadLocal?"
- "What is InheritableThreadLocal and when would you use it?"
- "How does ThreadLocal interact with virtual threads in Java 21?"

**Common mistakes:**
- Not calling `remove()` in a finally block.
- Storing large objects in ThreadLocal in a large thread pool.
- Using ThreadLocal with thread pools without understanding context bleed between requests.

**Interview traps:**
- "Is ThreadLocal thread-safe?" It is per-thread — there is no sharing to protect, so synchronization is irrelevant. But the objects stored in ThreadLocal may themselves need to be thread-safe if shared elsewhere.

**Quick revision notes:**
ThreadLocal: per-thread isolated variable. No synchronization needed. In thread pools: always remove() in finally — prevents context bleed and memory leaks. InheritableThreadLocal for parent-child thread propagation. Foundation of Spring Security, MDC logging.

---

## 9. Java 21: Virtual Threads

---

### 9.1 Virtual Threads — Project Loom

**Difficulty:** Medium | **Interview Frequency:** High (awareness expected for SDE2)

**Companies:** Amazon, Google, Goldman Sachs (Java 21 migration discussions)

**Short Answer:**
Virtual threads (Java 21, JEP 444) are lightweight threads managed by the JVM rather than the OS. The JVM multiplexes millions of virtual threads onto a small pool of OS carrier threads. When a virtual thread blocks on I/O, the JVM automatically unmounts it from the carrier thread, freeing the carrier to run another virtual thread.

**Deep Explanation:**

Platform thread (Java 17 and earlier):
- 1:1 mapping to OS thread
- Stack: ~512KB–1MB per thread
- Creation cost: ~1ms (kernel call)
- Practical limit: ~10,000 threads on a typical server before memory and scheduling overhead dominate

Virtual thread (Java 21):
- M:N mapping (millions of virtual threads → small number of OS carrier threads)
- Stack: small, heap-allocated, grows as needed (JVM manages)
- Creation cost: ~microseconds
- Practical limit: millions (100K–10M tested)

How mounting/unmounting works:
- Virtual thread is "mounted" on a carrier OS thread when it needs CPU
- When the virtual thread hits a blocking call (socket I/O, JDBC, sleep), it is automatically "unmounted"
- The carrier thread picks up another runnable virtual thread
- When the I/O completes, the virtual thread is rescheduled

Implication for I/O-bound services:
```java
// Java 17: thread pool with N threads, N limited by OS/memory
ExecutorService executor = Executors.newFixedThreadPool(200);

// Java 21: one virtual thread per request — scales to millions
ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
```

What virtual threads do NOT change:
- Synchronization semantics (synchronized, volatile, happens-before) are unchanged
- CPU-bound tasks: virtual threads do not provide parallelism beyond available CPU cores
- Pinning: if a virtual thread calls a native method or is inside a `synchronized` block when it blocks, it "pins" the carrier thread — the carrier cannot be reused until the virtual thread unblocks. This negates the benefit.

Pinning mitigation: replace `synchronized` blocks with `ReentrantLock` for code that may block on I/O within the critical section.

```java
// Java 21 virtual thread creation
Thread.ofVirtual().name("payment-vt").start(() -> processPayment());

// Or via executor (preferred)
try (ExecutorService vte = Executors.newVirtualThreadPerTaskExecutor()) {
    IntStream.range(0, 100_000).forEach(i ->
        vte.submit(() -> simulateIOBoundTask(i))
    );
} // try-with-resources: auto-shutdown and await termination
```

ThreadLocal and virtual threads: ScopedValues (JEP 446, also Java 21 preview) are the preferred alternative to ThreadLocal for virtual threads — they are immutable per scope, preventing the mutation-based side effects that complicate ThreadLocal in highly concurrent virtual thread workloads.

**Real-world backend example:**
A payment gateway with Java 21 can spawn one virtual thread per incoming HTTP request. With 50,000 concurrent requests — each waiting ~50ms for a database response — platform threads would require a 50,000-thread pool (25GB of stacks). Virtual threads handle this with ~10 carrier threads and minimal heap overhead.

**Quick revision notes:**
Virtual threads: JVM-managed, heap-allocated stacks, millions possible. For I/O-bound code only. Platform-thread synchronization rules still apply. Pinning risk with synchronized + I/O — prefer ReentrantLock. Use newVirtualThreadPerTaskExecutor(). Java 21 GA feature.

---

## 10. Reference Diagrams and Checklists

---

### Thread Lifecycle State Diagram (ASCII)

```
                          ┌─────────────────────────────────────────────────────┐
                          │                  Thread States                      │
                          └─────────────────────────────────────────────────────┘

     thread.start()
  ┌───────────────────────────────────────────────────────────────────────┐
  │                                                                       │
  v                                                                       │
NEW ──────────────────> RUNNABLE ◄──────────────────────────────────────┐│
                           │    ▲                                        ││
                           │    │  lock available                        ││
           wait for        │    │                                        ││
           monitor lock    v    │                                        ││
                        BLOCKED                                          ││
                                                                         ││
                           │    ▲                                        ││
          object.wait()    │    │  notify() / notifyAll()                ││
          thread.join()    │    │  target thread terminates              ││
          LockSupport      v    │  LockSupport.unpark()                  ││
          .park()       WAITING ─────────────────────────────────────────┘│
                                                                           │
                           │    ▲                                          │
      Thread.sleep(n)      │    │  timeout expires                         │
      object.wait(n)       │    │  notify() / notifyAll()                  │
      thread.join(n)       v    │  interrupt()                             │
      parkNanos()    TIMED_WAITING ──────────────────────────────────────-─┘

                    RUNNABLE ──── run() returns ────> TERMINATED
                             ──── unhandled exception ─>


  Key transitions:
  ─────────────────────────────────────────────────────────────────────
  NEW          → RUNNABLE      : thread.start()
  RUNNABLE     → BLOCKED       : attempting to enter synchronized block/method
  BLOCKED      → RUNNABLE      : monitor lock becomes available
  RUNNABLE     → WAITING       : object.wait(), thread.join(), LockSupport.park()
  WAITING      → RUNNABLE      : object.notify/notifyAll, join target terminates
  RUNNABLE     → TIMED_WAITING : Thread.sleep(n), object.wait(n), thread.join(n)
  TIMED_WAITING→ RUNNABLE      : timeout, notify, interrupt
  RUNNABLE     → TERMINATED    : run() returns or uncaught exception
  ─────────────────────────────────────────────────────────────────────
  Note: Java reports I/O-blocked threads as RUNNABLE (JVM sees no distinction)
```

---

### Concurrency Tool Selection Guide

```
PROBLEM                          RECOMMENDED TOOL
─────────────────────────────────────────────────────────────────────────────────

Simple mutual exclusion           → synchronized (method or block)
  (no timeout, no conditions)        JVM can optimize: biased locking, lock elision

Timed lock attempt                → ReentrantLock.tryLock(timeout)
Interruptible lock wait           → ReentrantLock.lockInterruptibly()
Multiple condition variables      → ReentrantLock + Condition (newCondition())
Fair access ordering              → ReentrantLock(true) — fairness=true

Read-heavy shared data            → ReentrantReadWriteLock
  (cache, config, routing table)     many concurrent readers, rare writes

Extreme read performance          → StampedLock (optimistic read)
  (no reentrancy, no conditions)     order book, in-memory index

Single counter / flag             → AtomicInteger / AtomicBoolean
  (CAS semantics needed)             sequence numbers, circuit breakers

High-contention counter           → LongAdder / LongAccumulator
  (no CAS semantics needed)          request counts, byte metrics

Thread-safe Map                   → ConcurrentHashMap
  (compound ops: computeIfAbsent,    per-client rate limiter, cache
   putIfAbsent, merge)

Read-heavy List                   → CopyOnWriteArrayList
  (rare writes, many reads)          event listeners, subscriber lists

Producer-Consumer                 → BlockingQueue (ArrayBlockingQueue for
  (bounded buffer, backpressure)     bounded, SynchronousQueue for handoff)

Per-thread state                  → ThreadLocal<T>
  (request context, user session)    always remove() in finally

Parallel divide-and-conquer       → ForkJoinPool / RecursiveTask
  (recursive tasks, work-stealing)   merge sort, parallel reduce

I/O-bound high concurrency        → Virtual Threads (Java 21)
  (thousands of concurrent I/O ops)  newVirtualThreadPerTaskExecutor()

─────────────────────────────────────────────────────────────────────────────────
```

---

### Deadlock Detection Checklist

Use this checklist when investigating a suspected deadlock in production.

```
DETECTION
─────────────────────────────────────────────────────────────────────────────────
□ 1. Take a thread dump: jstack <pid>  OR  kill -3 <pid>  OR  jcmd <pid> Thread.print
□ 2. Look for "Found one Java-level deadlock" section in the dump
□ 3. Identify threads in BLOCKED state — what lock is each waiting for?
□ 4. Identify which thread holds the lock each BLOCKED thread is waiting for
□ 5. Trace the cycle: T1 waits for L1 held by T2, T2 waits for L2 held by T1
□ 6. Use VisualVM, JConsole, or Java Flight Recorder for continuous deadlock monitoring

ROOT CAUSE ANALYSIS
─────────────────────────────────────────────────────────────────────────────────
□ 7. Are two or more locks acquired in different orders in different code paths?
□ 8. Is there a synchronized call from within another synchronized block?
□ 9. Are any callbacks or listeners called while holding a lock?
□ 10. Are there synchronized methods that call other synchronized methods on
       different objects?
□ 11. Is database row locking involved (check for DB deadlock logs too)?

PREVENTION FIXES
─────────────────────────────────────────────────────────────────────────────────
□ 12. Enforce consistent global lock ordering (use natural key ordering)
□ 13. Replace nested synchronized blocks with tryLock(timeout)
□ 14. Narrow the scope of synchronized blocks — minimize what happens inside
□ 15. Avoid calling external/unknown code (callbacks, listeners) while holding a lock
□ 16. Consider lock-free alternatives (ConcurrentHashMap, AtomicReference, CAS)
□ 17. For database deadlocks: use explicit deadlock retry in the DAL layer
□ 18. Add deadlock detection to CI pipeline using ThreadMXBean in integration tests:

  ThreadMXBean tmx = ManagementFactory.getThreadMXBean();
  long[] deadlocked = tmx.findDeadlockedThreads();
  if (deadlocked != null) {
      // dump and alert
  }

─────────────────────────────────────────────────────────────────────────────────
```

---

### Quick Summary — Key Numbers to Remember

| Concept | Value |
|---|---|
| Default thread stack size (64-bit JVM) | ~512KB (configurable via -Xss) |
| Platform thread creation time | ~1ms |
| Virtual thread creation time | ~microseconds |
| CAS instruction on x86-64 | CMPXCHG (single CPU instruction) |
| LongAdder cells (contention threshold) | Expands up to CPU count |
| Default ForkJoinPool parallelism | availableProcessors() - 1 |
| CPU-bound thread pool formula | N + 1 threads |
| I/O-bound thread pool formula | N * (1 + W/C) threads |
| ThreadPoolExecutor task acceptance order | core threads → queue → max threads → reject |

---

*End of Chapter 6: Multithreading and Concurrency*

*Next chapter: Chapter 7 — Java Memory Model and Garbage Collection*


