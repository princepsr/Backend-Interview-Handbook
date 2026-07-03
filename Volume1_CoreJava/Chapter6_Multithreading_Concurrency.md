# Volume 1: Core Java
# Chapter 6: Multithreading & Concurrency

---

## Table of Contents
1. Thread Fundamentals
2. Synchronization
3. Locks
4. Atomic Classes
5. Thread Pools and Executors
6. Concurrent Collections
7. Concurrency Problems
8. Real-World Patterns
9. Java 21: Virtual Threads
10. Reference Diagrams and Checklists

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: Thread Fundamentals

**Difficulty:** Easy–Medium | **Frequency:** Very High | **Companies:** Amazon, Goldman Sachs, Google, Razorpay, Flipkart, Adobe

<svg viewBox="0 0 760 360" xmlns="http://www.w3.org/2000/svg" font-family="'Segoe UI', Arial, sans-serif" style="width:100%; max-width:760px; display:block; margin:16px 0;">
  <defs>
    <!-- Arrow marker -->
    <marker id="arrow-dim" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
      <polygon points="0 0, 8 3, 0 6" fill="#1e293b"/>
    </marker>
    <marker id="arrow-active" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
      <polygon points="0 0, 8 3, 0 6" fill="#38bdf8"/>
    </marker>
    <!-- Animation timing:
         Total loop = 8s
         NEW active:         0-1s
         NEW→RUNNABLE:       1-1.5s
         RUNNABLE active:    1.5-2.5s
         RUNNABLE→BLOCKED:   2.5-3s
         BLOCKED active:     3-3.8s
         BLOCKED→RUNNABLE:   3.8-4.3s
         RUNNABLE active:    4.3-5s
         RUNNABLE→WAITING:   5-5.5s
         WAITING active:     5.5-6.2s
         WAITING→RUNNABLE:   6.2-6.7s
         RUNNABLE active:    6.7-7.2s
         RUNNABLE→TERMINATED:7.2-7.6s
         TERMINATED active:  7.6-8s
    -->
    <!-- Clip paths not needed; using animate elements -->
  </defs>
  <!-- Background -->
  <rect width="760" height="360" fill="#f8fafc"/>
  <!-- Title -->
  <text x="380" y="28" text-anchor="middle" fill="#64748b" font-size="14" font-weight="600" letter-spacing="1.5">JAVA THREAD LIFECYCLE</text>
  <!-- ══════════════════════════════════════════════
       STATE NODES
       Layout (cx, cy):
         NEW         (80,  180)
         RUNNABLE    (260, 180)
         BLOCKED     (440, 90)
         WAITING     (440, 180)
         TIMED_WAIT  (440, 270)
         TERMINATED  (640, 180)
       ══════════════════════════════════════════════ -->
  <!-- ── NEW ── -->
  <g id="state-new">
    <!-- Dim ring (always visible) -->
    <circle cx="80" cy="180" r="36" fill="none" stroke="#64748b" stroke-width="2" opacity="0.3"/>
    <!-- Filled circle -->
    <circle cx="80" cy="180" r="30" fill="#f1f5f9" stroke="#64748b" stroke-width="2">
      <animate attributeName="stroke-opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.0625;0.125;1" values="0.3;1;0.3;0.3" calcMode="linear"/>
    </circle>
    <!-- Glow ring -->
    <circle cx="80" cy="180" r="36" fill="none" stroke="#64748b" stroke-width="3" opacity="0">
      <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.05;0.1;0.125;1" values="0;0.9;0.9;0;0"/>
      <animate attributeName="r" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.05;0.1;0.125;1" values="32;40;40;32;32"/>
    </circle>
    <text x="80" y="177" text-anchor="middle" fill="#64748b" font-size="11" font-weight="700">
      <animate attributeName="fill" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.05;0.125;1" values="#64748b;#1e293b;#64748b;#64748b"/>
      NEW
    </text>
    <text x="80" y="190" text-anchor="middle" fill="#64748b" font-size="8">Thread()</text>
  </g>
  <!-- ── RUNNABLE ── -->
  <g id="state-runnable">
    <circle cx="270" cy="180" r="36" fill="none" stroke="#10b981" stroke-width="2" opacity="0.3"/>
    <circle cx="270" cy="180" r="30" fill="#f1f5f9" stroke="#10b981" stroke-width="2">
      <animate attributeName="stroke-opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.15;0.1875;0.3;0.3125;0.4;0.55;0.625;0.65;0.84;0.9;1"
               values="0.3;0.3;1;1;0.3;0.3;0.3;1;1;1;0.3;0.3"/>
    </circle>
    <!-- Glow ring - fires at each RUNNABLE activation -->
    <circle cx="270" cy="180" r="36" fill="none" stroke="#10b981" stroke-width="3" opacity="0">
      <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.15;0.1875;0.3;0.3125;0.55;0.625;0.65;0.84;0.9;1"
               values="0;0;0.85;0.85;0;0;0.85;0.85;0.85;0;0"/>
      <animate attributeName="r" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.1875;0.3;0.625;0.65;0.84;0.9;1"
               values="32;40;40;40;40;40;32;32"/>
    </circle>
    <text x="270" y="177" text-anchor="middle" fill="#10b981" font-size="11" font-weight="700">
      <animate attributeName="fill" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.1875;0.3;0.625;0.84;0.9;1"
               values="#10b981;#059669;#10b981;#059669;#059669;#10b981;#10b981"/>
      RUNNABLE
    </text>
    <text x="270" y="190" text-anchor="middle" fill="#065f46" font-size="8">Running/Ready</text>
  </g>
  <!-- ── BLOCKED ── -->
  <g id="state-blocked">
    <circle cx="460" cy="90" r="36" fill="none" stroke="#ef4444" stroke-width="2" opacity="0.3"/>
    <circle cx="460" cy="90" r="30" fill="#f1f5f9" stroke="#ef4444" stroke-width="2">
      <animate attributeName="stroke-opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.3;0.3125;0.4;0.45;0.475;1"
               values="0.3;0.3;1;1;0.3;0.3;0.3"/>
    </circle>
    <circle cx="460" cy="90" r="36" fill="none" stroke="#ef4444" stroke-width="3" opacity="0">
      <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.3;0.3125;0.4;0.45;1"
               values="0;0;0.85;0.85;0;0"/>
      <animate attributeName="r" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.3125;0.4;0.45;1"
               values="32;40;40;32;32"/>
    </circle>
    <text x="460" y="87" text-anchor="middle" fill="#ef4444" font-size="11" font-weight="700">
      <animate attributeName="fill" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.3125;0.4;0.45;1"
               values="#ef4444;#fca5a5;#ef4444;#ef4444;#ef4444"/>
      BLOCKED
    </text>
    <text x="460" y="100" text-anchor="middle" fill="#7f1d1d" font-size="8">Waiting lock</text>
  </g>
  <!-- ── WAITING ── -->
  <g id="state-waiting">
    <circle cx="460" cy="180" r="36" fill="none" stroke="#f59e0b" stroke-width="2" opacity="0.3"/>
    <circle cx="460" cy="180" r="30" fill="#f1f5f9" stroke="#f59e0b" stroke-width="2">
      <animate attributeName="stroke-opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.625;0.6875;0.775;0.8375;0.84;1"
               values="0.3;0.3;1;1;0.3;0.3;0.3"/>
    </circle>
    <circle cx="460" cy="180" r="36" fill="none" stroke="#f59e0b" stroke-width="3" opacity="0">
      <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.625;0.6875;0.775;0.8375;1"
               values="0;0;0.85;0.85;0;0"/>
      <animate attributeName="r" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.6875;0.775;0.8375;1"
               values="32;40;40;32;32"/>
    </circle>
    <text x="460" y="177" text-anchor="middle" fill="#f59e0b" font-size="11" font-weight="700">
      <animate attributeName="fill" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.6875;0.775;0.8375;1"
               values="#f59e0b;#fde68a;#f59e0b;#f59e0b;#f59e0b"/>
      WAITING
    </text>
    <text x="460" y="190" text-anchor="middle" fill="#78350f" font-size="8">Indefinite</text>
  </g>
  <!-- ── TIMED_WAITING ── -->
  <g id="state-timed">
    <circle cx="460" cy="270" r="36" fill="none" stroke="#8b5cf6" stroke-width="2" opacity="0.25"/>
    <circle cx="460" cy="270" r="30" fill="#f1f5f9" stroke="#8b5cf6" stroke-width="2" stroke-opacity="0.25"/>
    <text x="460" y="265" text-anchor="middle" fill="#8b5cf6" font-size="9" font-weight="700" opacity="0.5">TIMED</text>
    <text x="460" y="277" text-anchor="middle" fill="#8b5cf6" font-size="9" font-weight="700" opacity="0.5">WAITING</text>
    <text x="460" y="290" text-anchor="middle" fill="#4c1d95" font-size="7" opacity="0.5">sleep(ms)</text>
  </g>
  <!-- ── TERMINATED ── -->
  <g id="state-terminated">
    <circle cx="650" cy="180" r="36" fill="none" stroke="#374151" stroke-width="2" opacity="0.3"/>
    <circle cx="650" cy="180" r="30" fill="#f1f5f9" stroke="#374151" stroke-width="2">
      <animate attributeName="stroke-opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.9;0.95;1"
               values="0.3;0.3;1;1"/>
    </circle>
    <circle cx="650" cy="180" r="36" fill="none" stroke="#6b7280" stroke-width="3" opacity="0">
      <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.9;0.95;1"
               values="0;0;0.7;0.7"/>
    </circle>
    <text x="650" y="177" text-anchor="middle" fill="#374151" font-size="10" font-weight="700">
      <animate attributeName="fill" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.9;0.95;1"
               values="#374151;#374151;#9ca3af;#9ca3af"/>
      TERMINATED
    </text>
    <text x="650" y="190" text-anchor="middle" fill="#1f2937" font-size="8">Dead</text>
  </g>
  <!-- ══════════════════════════════════════════════
       ARROWS (static paths, active ones fade in/out)
       ══════════════════════════════════════════════ -->
  <!-- NEW → RUNNABLE (straight, below center) -->
  <g id="arrow-new-runnable">
    <!-- Dim static line -->
    <line x1="112" y1="180" x2="232" y2="180" stroke="#cbd5e1" stroke-width="1.5"
          marker-end="url(#arrow-dim)" stroke-dasharray="4 3" opacity="0.4"/>
    <!-- Active animated line -->
    <line x1="112" y1="180" x2="232" y2="180" stroke="#38bdf8" stroke-width="2"
          marker-end="url(#arrow-active)" stroke-dasharray="120" stroke-dashoffset="120" opacity="0">
      <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.1125;0.1875;0.2;1" values="0;0;1;0;0"/>
      <animate attributeName="stroke-dashoffset" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.1125;0.1875;0.2;1" values="120;120;0;0;120"/>
    </line>
    <text x="175" y="172" text-anchor="middle" fill="#64748b" font-size="8.5">start()</text>
  </g>
  <!-- RUNNABLE → BLOCKED (curve up) -->
  <g id="arrow-runnable-blocked">
    <path d="M 285 152 Q 340 100 424 90" fill="none" stroke="#cbd5e1" stroke-width="1.5"
          marker-end="url(#arrow-dim)" stroke-dasharray="4 3" opacity="0.4"/>
    <path d="M 285 152 Q 340 100 424 90" fill="none" stroke="#38bdf8" stroke-width="2"
          marker-end="url(#arrow-active)" stroke-dasharray="160" stroke-dashoffset="160" opacity="0">
      <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.2875;0.375;0.4;1" values="0;0;1;0;0"/>
      <animate attributeName="stroke-dashoffset" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.2875;0.375;0.4;1" values="160;160;0;0;160"/>
    </path>
    <text x="342" y="105" text-anchor="middle" fill="#64748b" font-size="8">synchronized</text>
  </g>
  <!-- BLOCKED → RUNNABLE (curve down back) -->
  <g id="arrow-blocked-runnable">
    <path d="M 424 106 Q 360 140 305 162" fill="none" stroke="#cbd5e1" stroke-width="1.5"
          marker-end="url(#arrow-dim)" stroke-dasharray="4 3" opacity="0.4"/>
    <path d="M 424 106 Q 360 140 305 162" fill="none" stroke="#38bdf8" stroke-width="2"
          marker-end="url(#arrow-active)" stroke-dasharray="160" stroke-dashoffset="160" opacity="0">
      <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.45;0.5625;0.575;1" values="0;0;1;0;0"/>
      <animate attributeName="stroke-dashoffset" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.45;0.5625;0.575;1" values="160;160;0;0;160"/>
    </path>
    <text x="348" y="155" text-anchor="middle" fill="#64748b" font-size="8">lock released</text>
  </g>
  <!-- RUNNABLE → WAITING (straight right, slight offset) -->
  <g id="arrow-runnable-waiting">
    <path d="M 302 180 L 424 180" fill="none" stroke="#cbd5e1" stroke-width="1.5"
          marker-end="url(#arrow-dim)" stroke-dasharray="4 3" opacity="0.4"/>
    <path d="M 302 180 L 424 180" fill="none" stroke="#38bdf8" stroke-width="2"
          marker-end="url(#arrow-active)" stroke-dasharray="125" stroke-dashoffset="125" opacity="0">
      <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.6;0.6875;0.7;1" values="0;0;1;0;0"/>
      <animate attributeName="stroke-dashoffset" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.6;0.6875;0.7;1" values="125;125;0;0;125"/>
    </path>
    <text x="362" y="170" text-anchor="middle" fill="#64748b" font-size="8">wait()</text>
  </g>
  <!-- WAITING → RUNNABLE (curve below) -->
  <g id="arrow-waiting-runnable">
    <path d="M 424 195 Q 360 230 305 200" fill="none" stroke="#cbd5e1" stroke-width="1.5"
          marker-end="url(#arrow-dim)" stroke-dasharray="4 3" opacity="0.4"/>
    <path d="M 424 195 Q 360 230 305 200" fill="none" stroke="#38bdf8" stroke-width="2"
          marker-end="url(#arrow-active)" stroke-dasharray="150" stroke-dashoffset="150" opacity="0">
      <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.775;0.8375;0.85;1" values="0;0;1;0;0"/>
      <animate attributeName="stroke-dashoffset" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.775;0.8375;0.85;1" values="150;150;0;0;150"/>
    </path>
    <text x="360" y="242" text-anchor="middle" fill="#64748b" font-size="8">notify()</text>
  </g>
  <!-- RUNNABLE → TERMINATED -->
  <g id="arrow-runnable-terminated">
    <line x1="308" y1="180" x2="612" y2="180" stroke="#cbd5e1" stroke-width="1.5"
          marker-end="url(#arrow-dim)" stroke-dasharray="4 3" opacity="0.4"/>
    <line x1="308" y1="180" x2="612" y2="180" stroke="#38bdf8" stroke-width="2"
          marker-end="url(#arrow-active)" stroke-dasharray="310" stroke-dashoffset="310" opacity="0">
      <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.875;0.95;0.96;1" values="0;0;1;0;0"/>
      <animate attributeName="stroke-dashoffset" dur="8s" repeatCount="indefinite"
               keyTimes="0;0.875;0.95;0.96;1" values="310;310;0;0;310"/>
    </line>
    <text x="460" y="170" text-anchor="middle" fill="#64748b" font-size="8">run() completes</text>
  </g>
  <!-- RUNNABLE ↔ TIMED_WAITING (dim only, not animated in main path) -->
  <path d="M 288 212 Q 340 270 424 264" fill="none" stroke="#cbd5e1" stroke-width="1"
        marker-end="url(#arrow-dim)" stroke-dasharray="3 4" opacity="0.25"/>
  <path d="M 424 278 Q 360 310 292 214" fill="none" stroke="#cbd5e1" stroke-width="1"
        marker-end="url(#arrow-dim)" stroke-dasharray="3 4" opacity="0.25"/>
  <text x="348" y="288" text-anchor="middle" fill="#374151" font-size="7.5" opacity="0.5">sleep(ms)</text>
  <text x="316" y="304" text-anchor="middle" fill="#374151" font-size="7.5" opacity="0.5">timeout</text>
  <!-- ══════════════════════════════════════════════
       PROGRESS / STEP INDICATOR
       ══════════════════════════════════════════════ -->
  <!-- Step label at bottom -->
  <rect x="200" y="330" width="360" height="22" rx="4" fill="#f8fafc" stroke="#e2e8f0" stroke-width="1"/>
  <!-- Step labels that appear at right times -->
  <text x="380" y="345" text-anchor="middle" font-size="10" fill="#38bdf8" opacity="0">
    <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
             keyTimes="0;0.01;0.09;0.1;1" values="0;1;1;0;0"/>
    Step 1: Thread created → NEW
  </text>
  <text x="380" y="345" text-anchor="middle" font-size="10" fill="#38bdf8" opacity="0">
    <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
             keyTimes="0;0.11;0.12;0.29;0.3;1" values="0;0;1;1;0;0"/>
    Step 2: start() called → RUNNABLE
  </text>
  <text x="380" y="345" text-anchor="middle" font-size="10" fill="#38bdf8" opacity="0">
    <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
             keyTimes="0;0.3;0.31;0.44;0.45;1" values="0;0;1;1;0;0"/>
    Step 3: synchronized block → BLOCKED
  </text>
  <text x="380" y="345" text-anchor="middle" font-size="10" fill="#38bdf8" opacity="0">
    <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
             keyTimes="0;0.45;0.46;0.61;0.62;1" values="0;0;1;1;0;0"/>
    Step 4: Lock acquired → RUNNABLE again
  </text>
  <text x="380" y="345" text-anchor="middle" font-size="10" fill="#38bdf8" opacity="0">
    <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
             keyTimes="0;0.62;0.63;0.77;0.775;1" values="0;0;1;1;0;0"/>
    Step 5: wait() → WAITING
  </text>
  <text x="380" y="345" text-anchor="middle" font-size="10" fill="#38bdf8" opacity="0">
    <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
             keyTimes="0;0.775;0.785;0.87;0.88;1" values="0;0;1;1;0;0"/>
    Step 6: notify() → RUNNABLE
  </text>
  <text x="380" y="345" text-anchor="middle" font-size="10" fill="#38bdf8" opacity="0">
    <animate attributeName="opacity" dur="8s" repeatCount="indefinite"
             keyTimes="0;0.88;0.89;1" values="0;0;1"/>
    Step 7: run() completes → TERMINATED
  </text>
  <!-- ══════════════════════════════════════════════
       LEGEND
       ══════════════════════════════════════════════ -->
  <g transform="translate(10, 310)">
    <circle cx="8" cy="8" r="5" fill="none" stroke="#64748b" stroke-width="1.5"/>
    <text x="17" y="12" fill="#64748b" font-size="8">NEW</text>
    <circle cx="60" cy="8" r="5" fill="none" stroke="#10b981" stroke-width="1.5"/>
    <text x="69" y="12" fill="#64748b" font-size="8">RUNNABLE</text>
    <circle cx="135" cy="8" r="5" fill="none" stroke="#ef4444" stroke-width="1.5"/>
    <text x="144" y="12" fill="#64748b" font-size="8">BLOCKED</text>
  </g>
  <g transform="translate(10, 326)">
    <circle cx="8" cy="8" r="5" fill="none" stroke="#f59e0b" stroke-width="1.5"/>
    <text x="17" y="12" fill="#64748b" font-size="8">WAITING</text>
    <circle cx="75" cy="8" r="5" fill="none" stroke="#8b5cf6" stroke-width="1.5"/>
    <text x="84" y="12" fill="#64748b" font-size="8">TIMED_WAITING</text>
    <circle cx="175" cy="8" r="5" fill="none" stroke="#374151" stroke-width="1.5"/>
    <text x="184" y="12" fill="#64748b" font-size="8">TERMINATED</text>
  </g>
</svg>

---

### The Idea

Think of a process as a factory building — it has its own electricity supply, plumbing, and security doors. A thread is like a worker inside that building. Multiple workers share the same tools, materials, and floor space (heap memory), but each carries their own notepad and pen (private stack and program counter). Workers are far cheaper to hire and replace than constructing a whole new building.

Java platform threads map 1:1 to OS threads. Spawning a thread costs roughly 1 ms and ~512 KB of stack RAM. Spawning 10,000 threads on a typical server eats 5 GB of stack alone — before any heap. This is why thread pools and Java 21 virtual threads exist: you want the concurrency without the resource explosion.

A thread's life follows a strict state machine. It starts idle (NEW), enters RUNNABLE when you call `start()`, may park itself waiting for a lock (BLOCKED) or for an explicit signal (WAITING / TIMED_WAITING), and eventually finishes (TERMINATED). Understanding exactly which state a thread is in — and why — is the difference between diagnosing a production deadlock in ten minutes and spending a day guessing.

### How It Works

**Thread lifecycle (pseudocode):**
```
thread.start()
  → OS allocates stack (~512 KB), creates kernel thread
  → state: NEW → RUNNABLE

thread enters synchronized block, lock held by another
  → state: RUNNABLE → BLOCKED
  → released when lock becomes free → RUNNABLE

thread calls object.wait() or thread.join()
  → releases held lock (wait only)
  → state: RUNNABLE → WAITING
  → woken by notify() / target-thread-termination / interrupt

thread calls Thread.sleep(n) or object.wait(n)
  → state: RUNNABLE → TIMED_WAITING
  → auto-wakes after timeout, or woken early

run() returns or unhandled exception
  → state: → TERMINATED
```

**Key state distinctions:**

| State | Cause | Lock status |
|---|---|---|
| BLOCKED | Waiting to acquire a monitor lock | Does NOT hold the lock |
| WAITING | Called wait() / join() (no timeout) | Released the lock (for wait()) |
| TIMED_WAITING | sleep(n) / wait(n) / join(n) | sleep holds lock; wait releases it |
| RUNNABLE | Executing OR waiting for I/O | May or may not hold a lock |

Note: Java reports I/O-blocked threads as RUNNABLE. The JVM does not distinguish CPU work from OS I/O blocking at the Thread.State level.

**Three ways to create a task:**

```
Option A — extend Thread:
  class MyTask extends Thread { void run() { ... } }
  PROBLEM: single inheritance used up; tightly couples task + thread

Option B — implement Runnable (preferred for fire-and-forget):
  new Thread(() -> doWork()).start()
  or: executor.execute(runnable)

Option C — implement Callable (preferred when you need a result):
  Future<Integer> f = executor.submit(() -> compute())
  result = f.get()        // blocks caller until done
  result = f.get(1, SECONDS)  // blocks with timeout
  EXCEPTION: if compute() throws, f.get() wraps it in ExecutionException
```

**sleep() vs wait() — the critical distinction:**

```
Thread.sleep(500)
  ✓ pauses current thread for 500 ms
  ✗ does NOT release any held locks
  ✓ can be called anywhere

object.wait()
  ✓ releases the intrinsic lock on 'object'
  ✓ puts thread in WAITING until notify()/notifyAll()/interrupt
  ✗ MUST be called inside synchronized(object) — else IllegalMonitorStateException
  ✓ always wrap in a while loop to guard spurious wakeups
```

**One real Java gotcha — spurious wakeups:**
```java
// WRONG — uses if, vulnerable to spurious wakeup
synchronized (queue) {
    if (queue.isEmpty()) queue.wait();
    process(queue.poll()); // may NPE if spuriously woken
}

// CORRECT — recheck condition on every wakeup
synchronized (queue) {
    while (queue.isEmpty()) queue.wait();
    process(queue.poll());
}
```

**join() and happens-before:**

```
worker.join()
  → calling thread blocks until worker.run() returns
  → establishes happens-before: all writes in worker are
    visible to the calling thread after join() returns
  → join(millis) for bounded wait

Daemon threads:
  setDaemon(true)  ← MUST be called before start()
  JVM exits when ALL non-daemon threads finish, killing daemons mid-operation
  finally blocks in daemon threads are NOT guaranteed to run on JVM exit
  Use for: GC, JIT, heartbeats, monitoring — never for DB writes or file flushes
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is the difference between a process and a thread?"**

**One-line answer:** A process is an isolated program with its own memory; a thread is a unit of execution within a process that shares the heap but has its own stack.

**Full answer to give in an interview:**

> A process is like a factory building — it has its own address space, file handles, and OS resources. No other process can read its memory directly. A thread is like a worker inside that building: threads inside the same process share the heap, code segment, and static data, but each thread has its own stack (roughly 512 KB on a 64-bit JVM by default), its own program counter, and its own register set.
>
> Threads are cheaper to create — no new address space, no copy-on-write, no MMU reload on context switch. But they introduce shared-state hazards: two threads writing the same heap variable without synchronization produce a data race. A process crash is isolated; a thread crashing can corrupt shared state or kill the entire JVM.
>
> In production Java, you rarely create raw threads for every task. Platform threads map 1:1 to OS threads, so spinning up 10,000 of them burns ~5 GB of stack RAM alone. The standard approach is a bounded thread pool (ExecutorService) or, in Java 21, virtual threads — which are JVM-managed and can number in the millions without proportional OS cost.

*Keep this conversational. If the interviewer is from a trading firm, emphasize context-switch cost and cache pressure. If backend/cloud, emphasize virtual threads vs thread pools.*

**Gotcha follow-up they'll ask:**

*"What state does Java report for a thread blocked on I/O?"*

> Java's Thread.State reports RUNNABLE — the JVM does not differentiate between a thread actively running on CPU and a thread sitting in the OS waiting for a network read. The underlying OS thread is blocked, but Thread.getState() still returns RUNNABLE. This matters when you read thread dumps: a wall of RUNNABLE threads in a web server is normal; a wall of BLOCKED threads means lock contention.

---

#### Q2 — Concept Check

**"What is the difference between BLOCKED and WAITING thread states?"**

**One-line answer:** BLOCKED means a thread is waiting to acquire a monitor lock held by someone else; WAITING means the thread voluntarily suspended itself and needs an explicit signal to resume.

**Full answer to give in an interview:**

> BLOCKED is an involuntary state — the thread tried to enter a synchronized block or method, found the intrinsic lock held by another thread, and is now parked by the JVM waiting for that lock to be released. The thread holds no locks while in this state; it just can't make progress until the owner releases.
>
> WAITING is a voluntary state — the thread called `object.wait()`, `thread.join()` (no timeout), or `LockSupport.park()`. In the case of `wait()`, it actively releases the lock it was holding and signals "I need a condition to change — wake me when you call notify()." It will not resume until another thread explicitly calls `notify()`, `notifyAll()`, `unpark()`, or the joined thread terminates.
>
> In a thread dump, a production incident with thousands of BLOCKED threads on the same monitor is a lock-contention bottleneck — usually a serialized critical section under high load. WAITING threads are usually idle workers or threads parked in a connection pool waiting for a free connection. Both look similar in a naive thread dump, which is why knowing the distinction matters.

*If you get this question from a financial services company, they care about lock contention specifically — mention thread dumps and how you'd diagnose it.*

**Gotcha follow-up they'll ask:**

*"Does a BLOCKED thread hold any lock?"*

> No. A thread in BLOCKED state is waiting to acquire a lock — it does not hold it. This is a common confusion. The thread that holds the lock may be in RUNNABLE or TIMED_WAITING (for example, it called sleep() inside a synchronized block, which keeps the lock but sleeps — this is exactly why sleeping inside synchronized is considered an antipattern).

---

#### Q3 — Concept Check

**"What is the difference between Thread.sleep() and Object.wait()?"**

**One-line answer:** `sleep()` pauses the thread without releasing any locks; `wait()` must be called inside a synchronized block and releases the intrinsic lock so other threads can proceed.

**Full answer to give in an interview:**

> `Thread.sleep(millis)` is a static method — it suspends the current thread for the specified time. Crucially, it does not release any monitors the thread is holding. If you call sleep inside a synchronized block, other threads trying to enter that block will pile up in BLOCKED state for the entire duration. This is a real performance antipattern in high-throughput services.
>
> `Object.wait()` is a coordination mechanism built on the intrinsic lock. You call it inside a `synchronized(obj)` block. When called, it atomically releases the lock on `obj` and moves the thread to the WAITING state. Another thread can then enter the synchronized block, change some condition, and call `obj.notify()` or `obj.notifyAll()` to wake the waiting thread. When woken, the thread re-acquires the lock before returning from wait().
>
> The mandatory pattern is: always check the condition in a `while` loop — never `if`. The JVM (and OS) allow spurious wakeups — a thread can be woken from wait() without any notify() being called. Using `while` means the thread rechecks the condition and goes back to waiting if it's not met yet.
>
> A quick summary: sleep() holds lock, fixed time. wait() releases lock, signal-driven. Both throw InterruptedException.

*The while-vs-if gotcha on wait() comes up in almost every senior interview. Lead with it.*

**Gotcha follow-up they'll ask:**

*"What happens if you call wait() without being inside a synchronized block?"*

> You get `IllegalMonitorStateException` at runtime. The wait/notify contract is tightly coupled to the intrinsic lock — you cannot wait on an object's condition without holding its monitor. The JVM enforces this. This is also why wait() is on Object (every object has a monitor) rather than on Thread.

---

#### Q4 — Tradeoff Question

**"When would you use a daemon thread, and what are the risks?"**

**One-line answer:** Use daemon threads for background housekeeping tasks where losing work on JVM exit is acceptable; never use them for tasks that must complete, like database writes.

**Full answer to give in an interview:**

> A daemon thread is a background thread that does not prevent JVM shutdown. When every non-daemon thread finishes, the JVM exits — and any running daemon threads are killed abruptly, with no guarantee that their finally blocks will execute.
>
> Good use cases: heartbeat monitors, JVM's own GC and JIT threads, log flusher threads where losing a few tail entries on shutdown is acceptable, connection pool eviction threads (HikariCP's housekeeper is a daemon). These are background helpers that should not keep the application alive.
>
> The risks are real: if a daemon thread is in the middle of writing to a file or committing a database transaction when the JVM exits, that operation is cut short. You can end up with corrupt files, uncommitted transactions, or partially flushed metrics.
>
> One implementation rule: `setDaemon(true)` must be called before `start()`. Calling it after throws `IllegalThreadStateException`. Threads inherit daemon status from their parent — since the main thread is non-daemon, all your threads are non-daemon by default unless explicitly set.

*Mention HikariCP if you're interviewing for a backend role — it shows you know real frameworks, not just textbook answers.*

**Gotcha follow-up they'll ask:**

*"If a daemon thread spawns a child thread, is the child also a daemon?"*

> Yes — a thread inherits its daemon status from the parent thread. If a daemon thread creates a new Thread(), that child is also a daemon by default. If you want a non-daemon child, you must explicitly call `childThread.setDaemon(false)` before starting it.

---

> **Common Mistake — sleeping inside a synchronized block:** Calling `Thread.sleep()` while holding a monitor lock keeps the lock for the entire sleep duration, starving every other thread that needs that lock. Use `object.wait(timeout)` instead if you need to pause and cooperate — it releases the lock while waiting.

**Quick Revision (one line):** Thread = shared heap + private stack (~512 KB); six lifecycle states; sleep() holds locks, wait() releases them; always wait() inside a while loop; daemon threads die with the JVM — never use them for work that must complete.

---

## Topic 2: Synchronization

**Difficulty:** Medium–Hard | **Frequency:** Very High | **Companies:** Amazon, Goldman Sachs, Google, Morgan Stanley, Razorpay

---

### The Idea

Imagine two bank tellers sharing one cash drawer. If both reach in simultaneously, they might each count the same bill. The only safe solution is a rule: one teller at a time. In Java, `synchronized` implements this rule using the object's built-in monitor lock. Every Java object carries one — like a single key attached to a lockbox. Whoever holds the key can enter; everyone else waits outside.

But exclusive access is blunt. A volatile flag is like a whiteboard at the entrance that everyone can read simultaneously — useful when one person updates it and many others just need to see the latest value, with no compound operations. Volatile guarantees that writes immediately flush to main memory and reads always fetch from it, bypassing CPU caches. It does not make `i++` thread-safe, because increment is three separate operations: read, add, write.

The Java Memory Model (JMM) formalizes all of this with happens-before: a precise definition of when a write by one thread is guaranteed to be visible to another. This is why double-checked locking broke before Java 5 — without strong volatile semantics, the reference to a newly created object could become visible before the object's constructor finished running. Modern Java's fix is one word: `volatile` on the instance field.

### How It Works

**synchronized — intrinsic lock mechanics:**
```
Every Java object has one intrinsic monitor with three zones:
  Entry set  — threads competing to acquire the lock (BLOCKED)
  Owner      — single thread currently holding the lock
  Wait set   — threads that called wait() (WAITING)

Instance method:    lock = this
Static method:      lock = ClassName.class
Synchronized block: lock = whatever object you specify

Reentrancy: if thread T already holds the lock on object O,
  it can re-enter any synchronized(O) block without blocking.
  JVM tracks a hold-count; lock releases only when count → 0.
```

**volatile — cache bypass without mutual exclusion:**
```
Without volatile:
  Core 1 reads 'running' → caches true locally
  Core 2 writes running = false → updates its cache + main memory
  Core 1 never sees the update → infinite loop

With volatile:
  Every write flushes directly to main memory (store fence)
  Every read fetches directly from main memory (load fence)
  → all threads see the latest value

What volatile guarantees:
  ✓ Visibility (writes are immediately visible)
  ✓ Ordering (no reordering across the volatile barrier)
  ✗ Atomicity — count++ is still read-modify-write = NOT thread-safe
```

**Happens-before rules (JLS 17.4.5):**
```
1. Program order:   A before B in the same thread → A hb B
2. Monitor unlock:  synchronized exit hb next entry on same object
3. Volatile write:  volatile write hb any subsequent volatile read of same field
4. Thread start:    thread.start() hb any action in the started thread
5. Thread join:     all actions in thread T hb caller's return from T.join()
6. Transitivity:    A hb B and B hb C → A hb C

Practical example:
  int x = 0; volatile boolean flag = false;
  // Thread 1: x = 42; flag = true;   ← volatile write
  // Thread 2: if (flag) use(x);      ← volatile read
  Guarantee: if Thread 2 reads flag==true, x is guaranteed to be 42.
  Why: (x=42) hb (flag=true) [program order] + (flag=true) hb (flag read) [volatile] → transitivity
```

**Double-checked locking — the one real Java gotcha:**
```java
// BROKEN before Java 5 — object can be published before constructor finishes
private static Singleton instance;  // NOT volatile

// CORRECT — volatile prevents constructor reordering
private static volatile Singleton instance;

public static Singleton getInstance() {
    if (instance == null) {                  // fast path, no lock
        synchronized (Singleton.class) {
            if (instance == null) {          // re-check under lock
                instance = new Singleton();  // volatile write: full barrier
            }
        }
    }
    return instance;
}
```

**Preferred alternative — Initialization-on-Demand Holder:**
```java
public class Singleton {
    private Singleton() {}
    private static class Holder {
        static final Singleton INSTANCE = new Singleton(); // class loading is thread-safe
    }
    public static Singleton getInstance() { return Holder.INSTANCE; }
}
// No volatile, no synchronized, lazy, zero overhead after initialization
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What does the synchronized keyword guarantee, and what does it not guarantee?"**

**One-line answer:** `synchronized` guarantees mutual exclusion (one thread at a time) and visibility (exiting a synchronized block flushes all writes to main memory), but it does not guarantee fairness or liveness.

**Full answer to give in an interview:**

> synchronized uses the object's intrinsic monitor lock — sometimes called the "object's mutex." When a thread enters a synchronized method or block, it acquires that lock. Any other thread trying to acquire the same lock is placed in BLOCKED state until the owner releases it by exiting the synchronized region.
>
> Two things happen at the JMM level: mutual exclusion (only one thread holds the lock at a time) and visibility (the monitor-unlock happens-before the next monitor-lock on the same object, so all writes made while holding the lock are guaranteed visible to the next thread that acquires it).
>
> What synchronized does not guarantee: fairness. The JVM does not promise that waiting threads acquire the lock in arrival order. A newly arriving thread can "barge in" and steal the lock from threads that have been waiting longer. In practice this rarely matters, but starvation — a thread never acquiring the lock — is theoretically possible. For fairness guarantees, you need `new ReentrantLock(true)`.
>
> One important nuance: synchronizing on `this` means external code that also holds a reference to your object can lock out your methods unexpectedly. The safer pattern is to synchronize on a private final Object field — it is never shared outside your class.

*If they ask about lock scope, mention that locking on String literals or boxed Integer values is dangerous because those objects are cached/interned and shared across the entire JVM.*

**Gotcha follow-up they'll ask:**

*"Can two threads call different synchronized methods on the same object simultaneously?"*

> No. All synchronized instance methods on the same object share the same intrinsic lock — the lock on `this`. Thread A entering `deposit()` and Thread B trying to enter `withdraw()` on the same BankAccount object — Thread B blocks, because they need the same lock. Two threads CAN call synchronized methods on different instances of the same class simultaneously, because those are different lock objects.

---

#### Q2 — Concept Check

**"What does volatile guarantee, and when is it not enough?"**

**One-line answer:** `volatile` guarantees visibility and ordering — every write is immediately flushed to main memory — but not atomicity, so compound operations like `i++` are still race conditions.

**Full answer to give in an interview:**

> Without volatile, each CPU core caches variables locally. A thread on Core 1 might hold a stale copy of a field that Core 2 updated milliseconds ago. In pathological cases this causes infinite loops — a server thread spinning on `while (running)` that never sees `running = false` because the write is stuck in Core 2's cache.
>
> Declaring a field volatile inserts memory barriers: every write immediately flushes to main memory, and every read fetches from main memory rather than cache. This makes writes by any thread instantly visible to all other threads.
>
> The visibility guarantee also implies ordering: the JMM prevents writes before a volatile write from being reordered to after it (and reads after a volatile read from being moved before it). This ordering guarantee is exactly what makes double-checked locking correct in Java 5+ — the volatile write on the `instance` field creates a barrier that prevents the object constructor from being reordered after the reference assignment.
>
> Where volatile fails: `count++` is three operations — read, increment, write. Two threads can both read the same value, both increment, both write back, losing one increment. Volatile cannot prevent that. Use `AtomicInteger.incrementAndGet()` for atomic compound operations, or synchronize.

*This question often follows up into double-checked locking or AtomicInteger — be ready to pivot.*

**Gotcha follow-up they'll ask:**

*"Is reading or writing a long without volatile guaranteed to be atomic?"*

> On a 64-bit JVM, long and double reads/writes are typically atomic in practice. But the JLS only guarantees atomicity for 32-bit reads/writes without synchronization. On a 32-bit JVM, a 64-bit long write can be split into two 32-bit writes, causing a torn read — another thread might see half the old value and half the new value. Declaring the field volatile makes the read/write atomic on all JVMs.

---

#### Q3 — Design Scenario

**"Walk me through why double-checked locking was broken before Java 5 and how it was fixed."**

**One-line answer:** Without `volatile`, the JIT could reorder object construction so that a non-null reference was visible to other threads before the object's constructor finished running; `volatile` prevents that reordering.

**Full answer to give in an interview:**

> `instance = new Singleton()` is not a single atomic operation. At the bytecode level it breaks down into three steps: allocate memory, initialize the object (run the constructor, write fields), assign the reference to `instance`. The JIT compiler and CPU are free to reorder steps 2 and 3 — the reference can be written to `instance` before the constructor has finished.
>
> In the classic broken DCL, Thread A enters the synchronized block, allocates memory, writes the reference to `instance` (now non-null), and gets preempted before the constructor runs. Thread B hits the first null-check outside the synchronized block, sees `instance != null`, and returns a partially initialized object. Any field access on that object is undefined behavior.
>
> The fix is `private static volatile Singleton instance`. A volatile write creates a happens-before edge: all writes before the volatile write (including everything in the constructor) are guaranteed visible to any thread that subsequently reads the volatile field. The JMM explicitly forbids reordering the constructor with the volatile assignment.
>
> The cleaner alternative I prefer in production is the Initialization-on-Demand Holder pattern: a private static nested class whose static field holds the instance. The JVM guarantees class loading is thread-safe. The Holder class is not loaded until `getInstance()` is called for the first time, giving you laziness for free, with no volatile and no synchronized needed at all.

*If you use the holder pattern in your answer, be ready to explain why class loading is thread-safe (class initializers are serialized by the class loader).*

**Gotcha follow-up they'll ask:**

*"Is DCL broken in modern Java?"*

> No — with `volatile` and Java 5+ JMM semantics (JSR-133), DCL is correct. Before Java 5, volatile had weaker semantics and did not prevent constructor reordering. Candidates who say "DCL is always broken" without qualification are citing a pre-2004 answer.

---

#### Q4 — Tradeoff Question

**"When should you use volatile versus synchronized?"**

**One-line answer:** Use volatile for a single flag or reference with one writer and many readers and no compound operations; use synchronized whenever you have compound operations, multiple related fields, or need mutual exclusion.

**Full answer to give in an interview:**

> volatile is the right tool when: (1) only one thread ever writes the field, (2) you are not doing compound operations like check-then-act or increment, and (3) you just need readers to see the latest value. A circuit-breaker open/closed flag is the canonical example — one monitoring thread flips it, thousands of worker threads read it. volatile is correct and costs far less than a synchronized method.
>
> synchronized is required when: you have compound operations (check balance, then debit — two steps that must be atomic together), multiple related fields that must be updated as a unit, or you need the thread in BLOCKED state until the lock is available rather than just seeing a fresh value.
>
> A key misconception to avoid: volatile does not provide mutual exclusion. Two threads can both read a volatile field, compute something, and both write back — with the last write winning and the first being silently lost. If any operation reads and then conditionally writes, you need synchronized or an atomic class (AtomicReference, AtomicInteger).
>
> In practice: for simple flags and references, volatile. For counters and compound state, AtomicInteger / AtomicReference. For multi-field invariants, synchronized or ReentrantLock.

*The AtomicInteger mention shows depth. If they ask about compare-and-swap, you can pivot to how CAS works.*

**Gotcha follow-up they'll ask:**

*"What happens-before relationship does a volatile write establish?"*

> A volatile write to field F happens-before any subsequent volatile read of F by any thread. Combined with program-order (everything before the volatile write happens-before the volatile write) and transitivity, this means all writes made by Thread 1 before the volatile write are visible to Thread 2 after Thread 2 reads the volatile field — even non-volatile writes like setting `x = 42` right before `flag = true` (where flag is volatile).

---

> **Common Mistake — synchronizing on a mutable or shared object:** Using `synchronized (someList)` or `synchronized (Integer.valueOf(id))` is dangerous — the list might be replaced, and Integer values are cached and shared across the JVM. Always synchronize on a `private final Object lock = new Object()` that you fully control.

**Quick Revision (one line):** synchronized = mutual exclusion + visibility via monitor lock; volatile = visibility + ordering only, not atomicity; happens-before formalizes what writes are guaranteed visible; DCL needs `volatile` since Java 5; prefer Initialization-on-Demand Holder for lazy singletons.

---

## Topic 3: Locks

**Difficulty:** Medium–Hard | **Frequency:** High | **Companies:** Goldman Sachs, Amazon, Google, Morgan Stanley, Razorpay, Adobe

---

### The Idea

`synchronized` is like a single-key bathroom lock — it works perfectly but it's all-or-nothing. One person in, everyone else waits, no exceptions. Java's explicit lock classes are like an upgraded access control system: you can say "all readers can enter simultaneously, but a writer gets the room alone" (ReadWriteLock), or "try the door for 2 seconds and if it's busy, go do something else" (tryLock with timeout), or "I'll just peek through the window to see if the data is unchanged before committing to entering" (StampedLock optimistic read).

ReentrantLock gives you the same mutual exclusion as synchronized but with fine-grained control: interruptible waits, timed attempts, and — crucially — multiple Condition variables. With synchronized, all threads that called wait() share one wait set; notifyAll() wakes everyone, including threads waiting for a different condition. ReentrantLock lets you maintain separate Condition objects so a producer signals only consumers and vice versa, eliminating unnecessary wakeups.

ReadWriteLock and StampedLock are designed for the common real-world pattern: reads are frequent and cheap, writes are rare. A routing table in an API gateway is read millions of times per second but updated once a day. Serializing all reads through a single lock wastes enormous throughput. ReadWriteLock allows unlimited concurrent readers while still giving writers exclusive access. StampedLock goes further with optimistic reads — no lock acquired at all, just a version check afterward — which is optimal when write conflicts are genuinely rare.

### How It Works

**ReentrantLock — explicit lock with options:**
```
lock.lock()               // blocks until acquired (same as synchronized)
lock.lockInterruptibly()  // blocks but responds to Thread.interrupt()
lock.tryLock()            // returns true/false immediately (non-blocking)
lock.tryLock(2, SECONDS)  // returns true/false after at most 2 seconds
lock.unlock()             // MUST be in finally block — no compiler safety net

Fairness:
  new ReentrantLock(false) // default: barge-in, higher throughput
  new ReentrantLock(true)  // FIFO ordering, prevents starvation, lower throughput

Multiple Conditions:
  Condition notFull  = lock.newCondition()
  Condition notEmpty = lock.newCondition()
  notFull.await()   // releases lock, waits for notFull.signal()
  notEmpty.signal() // wakes one thread waiting on notEmpty only
  → producers don't wake other producers; consumers don't wake other consumers
```

**ReadWriteLock — concurrent reads, exclusive writes:**
```
ReadWriteLock rwl = new ReentrantReadWriteLock()
Lock read  = rwl.readLock()
Lock write = rwl.writeLock()

Read lock:  multiple threads can hold it simultaneously
Write lock: exclusive — blocks all readers and other writers

Downgrade allowed:   writeLock → readLock (acquire read before releasing write)
Upgrade NOT allowed: readLock → writeLock causes DEADLOCK
  (two upgrading threads each wait for the other to release their read lock)

When to use: read-heavy shared data — caches, routing tables, config maps
When NOT to use: write-heavy workloads (write-lock overhead dominates)
```

**StampedLock — three modes, highest throughput:**
```
Write lock:
  long stamp = sl.writeLock()
  try { ... } finally { sl.unlockWrite(stamp) }

Pessimistic read:
  long stamp = sl.readLock()
  try { ... } finally { sl.unlockRead(stamp) }

Optimistic read (lock-free fast path):
  long stamp = sl.tryOptimisticRead()  // just reads a version number, no lock
  read fields into locals
  if (!sl.validate(stamp)) {           // was a write interleaved?
      stamp = sl.readLock()            // fall back to full read lock
      try { re-read fields } finally { sl.unlockRead(stamp) }
  }
  // if valid: proceeded with zero lock overhead

CRITICAL WARNINGS:
  NOT reentrant — writeLock() while holding readLock() = immediate deadlock
  Stamps are not reusable after unlock
  No Condition variable support
```

**One real Java gotcha — forgetting finally with ReentrantLock:**
```java
// WRONG — exception in criticalSection() leaves lock held forever
lock.lock();
criticalSection();  // if this throws, unlock() is never called → deadlock
lock.unlock();

// CORRECT — always use try-finally
lock.lock();
try {
    criticalSection();
} finally {
    lock.unlock();  // guaranteed to run even if exception is thrown
}
```

**Comparison table:**

| Feature | synchronized | ReentrantLock | ReadWriteLock | StampedLock |
|---|---|---|---|---|
| Auto-release | Yes (compiler) | No (finally) | No | No |
| tryLock / timeout | No | Yes | Yes | Yes |
| Interruptible wait | No | Yes | Yes | Partial |
| Fairness option | No | Yes | Yes | No |
| Multiple conditions | One (wait/notify) | Yes | No | No |
| Reentrancy | Yes | Yes | Yes | NO |
| Concurrent reads | No | No | Yes | Yes |
| Optimistic read | No | No | No | Yes |
| JVM optimization | Heavy (biased locking, elision) | Less | Less | Less |

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What does ReentrantLock give you that synchronized does not?"**

**One-line answer:** ReentrantLock adds timed/non-blocking lock attempts, interruptible waiting, multiple Condition variables, and an optional fairness policy — none of which synchronized supports.

**Full answer to give in an interview:**

> synchronized is baked into the language — the compiler ensures the lock is released when the block exits, which is safe but inflexible. You cannot say "try to acquire this lock for two seconds and if it's busy, do something else." You cannot interrupt a thread that's blocking on a synchronized entry. And you get exactly one wait set per object, meaning notifyAll() wakes every waiting thread regardless of what condition they're actually waiting for.
>
> ReentrantLock addresses each of those. `tryLock(2, TimeUnit.SECONDS)` attempts acquisition and returns a boolean — if it returns false, your thread can log a warning, retry with backoff, or return an error to the caller instead of hanging indefinitely. `lockInterruptibly()` lets you cancel a waiting thread by calling `thread.interrupt()` — critical in systems that need graceful shutdown.
>
> The biggest practical win is multiple Condition variables. Consider a bounded blocking queue: producers wait when the queue is full, consumers wait when it's empty. With synchronized and notifyAll(), a produce event wakes every waiting thread — consumers and producers alike. With ReentrantLock, you create `notFull` and `notEmpty` as separate Condition objects. A producer calls `notEmpty.signal()`, which wakes exactly one consumer. This eliminates spurious wakeups entirely and scales much better under high concurrency.
>
> The cost: you must release in a finally block. The compiler will not save you. Forgetting unlock() on an exception path is a deadlock waiting to happen in production.

*Mention the bounded queue use case specifically — it shows you understand why multiple conditions matter, not just that they exist.*

**Gotcha follow-up they'll ask:**

*"Is ReentrantLock always faster than synchronized?"*

> No. For simple uncontended mutual exclusion, synchronized often performs equally or better. The JVM applies heavy optimizations to synchronized: biased locking (nearly zero-cost when only one thread accesses the object), lock elision (the JIT eliminates locks on objects that escape analysis proves don't escape the thread), and adaptive spinning. ReentrantLock doesn't get these JVM-level optimizations. Use ReentrantLock when you specifically need its features, not as a default replacement for synchronized.

---

#### Q2 — Concept Check

**"How does ReadWriteLock work, and when would it hurt performance rather than help?"**

**One-line answer:** ReadWriteLock allows many concurrent readers OR one exclusive writer; it improves throughput for read-heavy workloads but can hurt performance when writes are frequent, because every write still blocks all readers.

**Full answer to give in an interview:**

> ReentrantReadWriteLock provides two lock views: `readLock()` and `writeLock()`. The read lock can be held by any number of threads simultaneously — they do not block each other. The write lock is exclusive: acquiring it waits for all current readers to finish, and while held, no new readers can enter.
>
> This is a win for data that is read often but updated rarely. An API gateway's routing table — URL patterns mapped to backend service URLs — might be read millions of times per second but updated once when a deployment happens. With plain synchronized, those millions of reads serialize needlessly. With ReadWriteLock, they all run in parallel; only the rare config reload briefly blocks traffic.
>
> Where it hurts: if writes are frequent, the write lock acquisition is expensive — it must wait for all active readers to drain before it can proceed. Under high write throughput, readers and writers are constantly contending, and the lock management overhead can make ReadWriteLock slower than a plain ReentrantLock. The crossover point depends on workload; the general rule is ReadWriteLock wins when the read-to-write ratio is substantially greater than 1.
>
> One important restriction: you cannot upgrade a read lock to a write lock. Two threads both trying to upgrade deadlock — each holds a read lock and waits for the other to release before the write lock can be granted. Downgrade (write to read) is allowed and has a safe pattern: acquire the read lock while still holding the write lock, then release the write lock.

*The upgrade-deadlock point is a reliable gotcha — interviewers love it.*

**Gotcha follow-up they'll ask:**

*"How is StampedLock different from ReadWriteLock?"*

> StampedLock adds a third mode: optimistic read. An optimistic read acquires no lock — it reads a version stamp (an integer), reads the data, and then validates that the stamp hasn't changed (meaning no write happened). If the validation fails, it falls back to a full pessimistic read lock. For workloads where writes are genuinely rare, this eliminates lock-acquisition overhead entirely on the hot read path. The cost: StampedLock is not reentrant — acquiring the write lock while holding a read lock deadlocks immediately, with no safety net.

---

#### Q3 — Design Scenario

**"Design a thread-safe bounded blocking queue using ReentrantLock."**

**One-line answer:** Use a ReentrantLock with two Condition variables — `notFull` for producers to wait on and `notEmpty` for consumers — so each side signals only the other, with no spurious wakeups.

**Full answer to give in an interview:**

> I'd use a ReentrantLock with two Condition variables. The key insight is that a producer only needs to be woken when a slot frees up, and a consumer only needs to be woken when an item appears. If I used synchronized with notifyAll(), every put or take would wake every waiting thread — producers and consumers — even though most of them can't make progress.
>
> The structure: one ReentrantLock, two Conditions (`notFull` and `notEmpty`), an ArrayDeque as the backing store, and a capacity bound.
>
> For `put`: acquire the lock. While the queue is at capacity, call `notFull.await()` — this releases the lock and parks the thread. When woken, re-check the condition (while loop, not if — spurious wakeups are real). Once there's space, add the item, then call `notEmpty.signal()` to wake one waiting consumer. Release the lock in the finally block.
>
> For `take`: mirror image — wait on `notEmpty`, poll the item, signal `notFull`.
>
> I'd also add a non-blocking `offer()` using `lock.tryLock()` — if the lock is available and there's space, insert and return true; otherwise return false immediately. This is useful for callers that have fallback behavior instead of blocking.
>
> The critical rule: every `lock.lock()` must be paired with `lock.unlock()` in a finally block. A single missed unlock on an exception path means the lock is held forever, and every subsequent call to put() or take() blocks forever — a production deadlock with no stack trace pointing to the cause.

*Walk through the code structure verbally — they're testing whether you know the while-loop pattern and the finally requirement, not whether you can recite syntax.*

**Gotcha follow-up they'll ask:**

*"What happens if you use Condition.signal() instead of signalAll(), and another thread is waiting on a different condition?"*

> That's exactly why two separate Conditions matter. `signal()` wakes one thread from that Condition's wait set. If you have `notFull` and `notEmpty` as separate Conditions, a consumer calling `notFull.signal()` wakes a producer — never a consumer. If you used a single Condition (or synchronized's single wait set), you'd need `signalAll()` to avoid a scenario where a producer wakes another producer that can't make progress, while a consumer that could make progress stays asleep. Two Conditions make `signal()` safe and efficient.

---

#### Q4 — Tradeoff Question

**"When should you use StampedLock, and what are the dangers?"**

**One-line answer:** Use StampedLock when you have extreme read-heavy throughput requirements and can guarantee no reentrancy — its optimistic read mode eliminates lock acquisition overhead on the hot path but the non-reentrant behavior is a silent deadlock risk.

**Full answer to give in an interview:**

> StampedLock's optimistic read mode is its killer feature. Instead of acquiring a lock, you call `tryOptimisticRead()` which returns a version stamp — essentially a sequence number. You read your fields, then call `validate(stamp)`. If no write happened between the stamp read and the validate, you proceed with zero lock overhead. If a write did happen, the stamp is invalid and you fall back to a full pessimistic read lock and re-read.
>
> For a high-frequency trading order book that is read thousands of times per millisecond but updated far less often, this eliminates nearly all lock overhead on the dominant read path. The validate-and-fallback adds a branch and a memory fence, but that's far cheaper than full lock acquisition.
>
> The dangers are serious. StampedLock is not reentrant. If your code path holds a read lock and somewhere in the call chain you try to acquire the write lock, it deadlocks immediately — there's no hold count, no "you already own this lock" detection. This is a silent, hard-to-reproduce production bug.
>
> Stamps are also not reusable — once you call unlock, the stamp is invalid. There's no Condition variable support. And the API is manual (like ReentrantLock) — you must handle the stamp carefully in finally blocks.
>
> My rule: StampedLock for performance-critical, well-understood code paths where reentrancy is definitively not needed. ReadWriteLock for everything else where concurrent reads matter. synchronized for simple mutual exclusion.

*The non-reentrancy danger is the examiner's real target here — show you know it without prompting.*

**Gotcha follow-up they'll ask:**

*"Why is read-to-write lock upgrade not supported in ReadWriteLock — wouldn't that be useful?"*

> It would be useful, but it's not safely implementable without a mechanism to handle the contention. Suppose two threads both hold the read lock and both want to upgrade to write. Each waits for the other to release its read lock before the write lock can be granted. Neither releases, both wait — deadlock. Allowing upgrade requires either serializing upgrade attempts (only one upgrader at a time, which negates the benefit) or introducing a tryUpgrade that fails if another upgrader is present. Java chose not to support it in the standard API. StampedLock's optimistic read is the practical substitute — you read optimistically and fall back to a write lock if the data changed, rather than upgrading an existing read lock.

---

> **Common Mistake — not unlocking ReentrantLock in finally:** If an exception is thrown between `lock.lock()` and `lock.unlock()`, and unlock is not in a finally block, the lock is held forever. Every subsequent thread that tries to acquire it blocks indefinitely. This is a production deadlock with no obvious stack trace cause — the victim threads are BLOCKED waiting for a lock that will never be released.

**Quick Revision (one line):** ReentrantLock adds tryLock/timeout/interruptible/Conditions over synchronized; ReadWriteLock allows concurrent reads for read-heavy data; StampedLock's optimistic read is lock-free but NOT reentrant; always unlock in finally; prefer synchronized for simple cases where JVM optimization applies.

---

## Topic 4: Atomic Classes

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Amazon, Goldman Sachs, Google, Razorpay

---

### The Idea

Imagine a shared counter on a whiteboard in a busy office. If two people try to read the number, add one, and write it back at the same time, you get the wrong result — both read "5", both write "6", but the true answer is "7". One increment got lost. A mutex is like posting a security guard at the whiteboard: only one person at a time. Atomic classes are different — they use a hardware trick called Compare-And-Swap (CAS) that lets a CPU update a value in a single, uninterruptible step, no guard needed.

Java's `java.util.concurrent.atomic` package — `AtomicInteger`, `AtomicLong`, `AtomicReference`, `AtomicBoolean` — wraps primitive values or object references and exposes them through CAS-based operations. Under low to moderate contention they are significantly faster than a `synchronized` block because there is no OS lock, no kernel call, no blocked thread waiting.

`LongAdder` (Java 8+) goes one step further for pure counting: instead of all threads fighting over one CAS location, it maintains a distributed array of cells and sums them on read. This scales much better under heavy write contention, at the cost of a non-atomic `sum()` — acceptable for metrics, not acceptable when you need `compareAndSet` semantics.

---

### How It Works

**CAS operation (pseudocode):**
```
function CAS(memoryLocation, expectedValue, newValue):
    if *memoryLocation == expectedValue:
        *memoryLocation = newValue
        atomically  // single CPU instruction: CMPXCHG on x86
        return true
    else:
        return false
```

**AtomicInteger.incrementAndGet — CAS retry loop (pseudocode):**
```
function incrementAndGet():
    loop forever:
        current = read()           // read current value
        next    = current + 1
        if CAS(location, current, next):
            return next            // CAS succeeded — we win
        // else another thread changed it; retry
```

**LongAdder internal structure (pseudocode):**
```
structure LongAdder:
    base: long
    cells: Cell[]      // created lazily under contention

function increment():
    if CAS(base, base, base+1) fails:
        pick cell by threadId hash
        CAS(cell.value, cell.value, cell.value + 1)

function sum():
    return base + sum(cells)   // NOT atomic — cells read one by one
```

**Comparison table:**

| Feature | `AtomicLong` | `LongAdder` |
|---|---|---|
| compareAndSet support | Yes | No |
| High-contention throughput | Lower (all threads fight one location) | Higher (distributed cells) |
| sum() atomic? | Yes (single volatile read) | No (cells summed one-by-one) |
| Memory use | Minimal | Higher (cell array) |
| Best for | Sequence numbers, CAS-based state | Request counters, error counts |

**The single most interview-critical gotcha — compound operations are NOT atomic:**

```java
// WRONG — still a race condition even with AtomicInteger
if (count.get() > 0) {
    count.decrementAndGet(); // another thread could decrement between get() and here
}

// CORRECT — single atomic operation
count.updateAndGet(current -> current > 0 ? current - 1 : 0);
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is CAS and why is it faster than a synchronized block?"**

**One-line answer:** CAS is a single CPU instruction that atomically reads, compares, and conditionally writes a value — no OS lock, no blocked threads, no kernel calls.

**Full answer to give in an interview:**

> "Compare-And-Swap is a hardware primitive — on x86 it's the CMPXCHG instruction — that reads a memory location, checks it against an expected value, and writes a new value only if they match, all in one uninterruptible step. The JVM exposes this via VarHandle under the hood for all `java.util.concurrent.atomic` classes.
>
> A `synchronized` block goes through the JVM monitor, which ultimately calls into the OS for lock management — context switches, kernel transitions, thread parking. Under low to moderate contention, CAS avoids all of that. It is lock-free: at least one thread always makes progress. However, it is not wait-free — under extreme contention, a single thread could theoretically keep losing its CAS and spinning indefinitely, though in practice this is rare.
>
> The trade-off: CAS is only efficient for single-variable updates. If you need to update two variables together atomically, you still need `synchronized` or a lock."

*If they nod, add: "Java 9+ replaced sun.misc.Unsafe with java.lang.invoke.VarHandle as the underlying CAS mechanism, which is part of the public API."*

**Gotcha follow-up they'll ask:** *"Is CAS wait-free?"*

> No. CAS-based algorithms are lock-free (system-wide progress guaranteed) but not wait-free (per-thread bounded progress not guaranteed). A thread could retry its CAS loop many times if other threads keep winning. True wait-free algorithms exist but are much harder to design.

---

#### Q2 — Concept Check

**"What is the ABA problem and how do you solve it in Java?"**

**One-line answer:** A value changes from A → B → A between a thread's read and its CAS, so the CAS succeeds even though the value was modified underneath — use `AtomicStampedReference` to include a version counter.

**Full answer to give in an interview:**

> "The ABA problem occurs when a thread reads value A, gets preempted, and another thread changes the value A → B → A. When the first thread resumes and does its CAS expecting A, it succeeds — but the value has been changed and changed back. For simple counters this doesn't matter, but for pointer-based structures (like a linked list node that was removed and re-inserted) it can silently corrupt state.
>
> Java's solution is `AtomicStampedReference<V>`, which pairs the reference with an integer stamp (version counter). CAS checks both the reference AND the stamp, so a value that cycles A → B → A also changes stamp 1 → 2 → 3, and the original CAS expecting stamp 1 fails.
>
> In practice, the ABA problem matters mainly for lock-free data structure implementations. Application-level code rarely needs to worry about it directly."

*Keep this answer tight. Interviewers mostly want to know you can identify where it applies, not build a lock-free list live.*

**Gotcha follow-up they'll ask:** *"When does the ABA problem matter vs. when can you ignore it?"*

> It matters when the identity of an object at a memory address is significant — e.g., linked list node pointers where a node can be freed and reallocated at the same address. It is irrelevant for simple numeric counters: if a counter goes 5 → 6 → 5, the CAS intending to go from 5 → 7 still produces the correct increment.

---

#### Q3 — Tradeoff Question

**"When would you use `LongAdder` instead of `AtomicLong`?"**

**One-line answer:** Use `LongAdder` for high-contention counters where you never need `compareAndSet`; use `AtomicLong` when you need CAS semantics like sequence number generation.

**Full answer to give in an interview:**

> "Under high contention — say, 50 threads all hammering the same counter — `AtomicLong` degrades because only one CAS succeeds per round and all others spin and retry. `LongAdder` sidesteps this by maintaining a base value plus an array of Cell objects. Each thread, when it loses on base, is hashed to a Cell and increments that instead. `sum()` adds base plus all cells.
>
> The trade-off is that `sum()` is not atomic — it reads the cells one by one — so under concurrent updates you might get a value that was never simultaneously the true total. For request counters or error rates in a metrics dashboard, that imprecision is fine. For a sequence number generator or a circuit breaker counter where the exact current value drives a business decision, you need `AtomicLong` with `compareAndSet`.
>
> Another difference: `LongAdder` has no `compareAndSet` method at all, so you literally cannot use it for CAS-based patterns. I reach for `LongAdder` for any high-throughput counting use case — request counts, byte metrics, event totals — and `AtomicLong` when the read-modify-write must be conditional."

*If they ask about memory cost: "An idle `LongAdder` still allocates the cell array when contention is first detected, so it uses more memory than a bare `AtomicLong`. For low-traffic counters the difference is negligible."*

**Gotcha follow-up they'll ask:** *"Is `LongAdder.sum()` safe to call from multiple threads?"*

> It is safe in the sense that it won't throw an exception or return corrupt data. But it is not atomic — between reading `base` and reading each cell, other threads may increment them. The returned value is an approximation of the true total at some recent moment, not a guaranteed consistent snapshot.

---

#### Q4 — Design Scenario

**"Design a thread-safe circuit breaker state machine using atomic classes."**

**One-line answer:** Use `AtomicReference<State>` for the state and CAS-based transitions to ensure only one thread opens or closes the breaker.

**Full answer to give in an interview:**

> "A circuit breaker has three states: CLOSED (normal), OPEN (rejecting requests), HALF_OPEN (testing recovery). The critical requirement is that the transition from CLOSED to OPEN happens exactly once even under concurrent failures.
>
> I'd model state as an `AtomicReference<CircuitState>` and use `compareAndSet` for transitions:
>
> ```java
> public boolean recordFailure() {
>     failures.incrementAndGet();
>     if (failures.get() >= threshold) {
>         // Only the first thread to see threshold trips the breaker
>         return state.compareAndSet(CLOSED, OPEN);
>     }
>     return false;
> }
>
> public boolean tryReset() {
>     return state.compareAndSet(OPEN, HALF_OPEN);
> }
> ```
>
> `compareAndSet` guarantees that even if 1,000 threads simultaneously detect the threshold breach, only one of them transitions the state to OPEN — the rest see `false` and move on. For the failure counter itself I'd use `LongAdder` if it's purely a metric, or `AtomicInteger` if the exact value drives the CAS decision, which it does here."

*Pause after the code sketch. If they probe further, discuss adding a timeout for OPEN → HALF_OPEN using `ScheduledExecutorService`.*

**Gotcha follow-up they'll ask:** *"What if you need to reset the failure counter when the breaker closes? Is that atomic with the state transition?"*

> It is not — resetting two separate atomic variables together is not a single atomic operation. You either accept a brief window of inconsistency (usually fine for a circuit breaker), or you encapsulate both state and counter into a single immutable record and use `AtomicReference.compareAndSet` on the entire record at once.

---

> **Common Mistake — Treating multi-step atomic operations as thread-safe:**
> Calling `get()` followed by `set()` on an `AtomicInteger` is two separate atomic operations, not one combined atomic operation. Another thread can interleave between them. Always use `updateAndGet()`, `accumulateAndGet()`, or an explicit CAS loop for read-modify-write sequences. The consequence is a classic check-then-act race that can silently corrupt state under load.

**Quick Revision (one line):** CAS = single hardware instruction; lock-free not wait-free; ABA → AtomicStampedReference; compound operations need updateAndGet/CAS loop, not separate get+set; LongAdder for high-contention counters, AtomicLong for compareAndSet semantics.

---

## Topic 5: Thread Pools and Executors

**Difficulty:** Medium–Hard | **Frequency:** Very High | **Companies:** Amazon, Goldman Sachs, Google, Razorpay, Netflix

---

### The Idea

Imagine a restaurant kitchen. One naive approach: for every new order, hire a brand-new chef, let them cook one dish, then fire them. The hiring overhead alone would bankrupt you. The sensible approach: hire a fixed team of chefs (a pool) who pick up tickets from a board and execute them. When a rush hits, you can temporarily call in extra staff up to a maximum, and if the kitchen is truly overwhelmed, you tell the waiter "we can't take more orders right now" — that's backpressure.

Java's `ExecutorService` is that kitchen model. You submit tasks; the framework manages the threads. A raw `new Thread(runnable).start()` per task is the "hire and fire" approach — each thread costs ~1ms to create, ~512KB of stack memory, and a kernel call. With 10,000 concurrent tasks that's 5GB of stack alone, and the OS scheduler spends more time context-switching than executing.

`ThreadPoolExecutor` is the production-grade implementation. Its acceptance flow is precisely defined: fill core threads first, then queue tasks, then expand to max threads only when the queue is full, then apply a rejection policy. Understanding this exact flow — and the danger of unbounded queues and unbounded thread counts in the Executors factory methods — is what separates candidates who have read about thread pools from those who have run them in production.

---

### How It Works

**ThreadPoolExecutor task acceptance algorithm (pseudocode):**
```
function submit(task):
    if runningThreads < corePoolSize:
        createThread(task)          // even if idle threads exist
        return

    if queue.offer(task):           // non-blocking enqueue attempt
        return                      // task accepted into queue

    if runningThreads < maximumPoolSize:
        createThread(task)          // extra thread, only when queue full
        return

    apply RejectedExecutionHandler  // queue full AND at max threads
```

**Key insight:** extra threads (above corePoolSize) are created only when the queue is FULL. An unbounded queue (like `LinkedBlockingQueue` without a capacity argument) never fills — so `maximumPoolSize` is never reached. This is what `Executors.newFixedThreadPool` does, silently.

**Factory method comparison table:**

| Factory | Core | Max | Queue | Production Risk |
|---|---|---|---|---|
| `newFixedThreadPool(n)` | n | n | Unbounded LinkedBQ | Queue grows to OOM |
| `newCachedThreadPool()` | 0 | Integer.MAX_VALUE | SynchronousQueue | Unlimited threads → OOM |
| `newSingleThreadExecutor()` | 1 | 1 | Unbounded LinkedBQ | Single point of failure + OOM queue |
| `newScheduledThreadPool(n)` | n | MAX_VALUE | DelayedWorkQueue | Scheduled tasks pile up |

**Built-in rejection policies:**

| Policy | Behaviour | Use when |
|---|---|---|
| `AbortPolicy` (default) | Throws `RejectedExecutionException` | Caller handles rejection |
| `CallerRunsPolicy` | Submitting thread runs the task | Natural backpressure to HTTP layer |
| `DiscardPolicy` | Task silently dropped | Metrics, non-critical events |
| `DiscardOldestPolicy` | Oldest queued task dropped, retry | Real-time pipelines |

**The single most interview-critical gotcha — CallerRunsPolicy as backpressure:**

```java
// Production-grade payment pool — never use Executors factory methods
ThreadPoolExecutor pool = new ThreadPoolExecutor(
    10,                              // core threads
    50,                              // max threads
    60L, TimeUnit.SECONDS,
    new ArrayBlockingQueue<>(500),   // bounded — forces rejection over OOM
    r -> {
        Thread t = new Thread(r, "payment-worker-" + counter.incrementAndGet());
        t.setDaemon(false);
        return t;
    },
    new ThreadPoolExecutor.CallerRunsPolicy() // Tomcat thread runs task → stops accepting HTTP
);
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"Walk me through exactly what happens when you submit a task to a ThreadPoolExecutor."**

**One-line answer:** Core threads first, then queue, then extra threads up to max, then rejection — extra threads only when the queue is full, not when core threads are busy.

**Full answer to give in an interview:**

> "When a task is submitted, the executor checks in this order. First: if the number of running threads is below `corePoolSize`, it creates a new thread and runs the task — even if other threads are currently idle. This surprises people; idle threads are not reused until corePoolSize is reached. Second: if we're at or above corePoolSize, it tries to enqueue the task with a non-blocking `offer()` call. If the queue has space, the task waits there. Third: if the queue is full, it tries to create a new thread up to `maximumPoolSize`. Fourth: if we're also at max threads, the configured `RejectedExecutionHandler` fires.
>
> The critical insight is that extra threads above corePoolSize are created only when the queue overflows. If you use an unbounded `LinkedBlockingQueue` — which `Executors.newFixedThreadPool` does — the queue never fills, so `maximumPoolSize` is effectively meaningless. You get bounded threads but potentially unbounded memory consumption from the queue."

*If they nod: add the lifecycle of extra threads — they are terminated after `keepAliveTime` of being idle, bringing the pool back toward corePoolSize.*

**Gotcha follow-up they'll ask:** *"So if I set maximumPoolSize=100 with a LinkedBlockingQueue, I'll never get more than corePoolSize threads?"*

> Exactly right. An unbounded queue never triggers the "create extra thread" branch. The pool behaves as if maximumPoolSize equals corePoolSize. This is a common misconfiguration in production — developers set a high max expecting burst capacity, but the unbounded queue silently absorbs all tasks instead.

---

#### Q2 — Tradeoff Question

**"Why should you never use `Executors.newCachedThreadPool()` in a production backend?"**

**One-line answer:** Its `maximumPoolSize` is `Integer.MAX_VALUE` — under any load spike it creates one thread per submitted task, potentially exhausting memory and crashing the JVM.

**Full answer to give in an interview:**

> "`newCachedThreadPool` sets corePoolSize to 0, maximumPoolSize to `Integer.MAX_VALUE`, and uses a `SynchronousQueue` — a queue with zero capacity that forces immediate handoff to a thread. When a task arrives, the executor tries to hand it off to a waiting thread. If none is waiting, it creates a new one. There is no upper bound.
>
> On a service receiving a traffic spike of 10,000 requests/second, this creates 10,000 threads in seconds — each consuming ~512KB of stack, totalling ~5GB just for stacks. The JVM crashes with `OutOfMemoryError: unable to create new native thread` before the GC can help.
>
> The same logic applies to `newFixedThreadPool` for a different reason: its unbounded `LinkedBlockingQueue` can accumulate millions of tasks during a slow consumer, consuming heap until the JVM OOMs.
>
> In production I always use a custom `ThreadPoolExecutor` with a bounded `ArrayBlockingQueue` and an explicit rejection policy. `CallerRunsPolicy` is my preferred default — when the pool and queue are both saturated, the submitting thread (usually a Tomcat worker) runs the task itself, which slows down the HTTP acceptor and provides natural backpressure rather than crashing."

*If they ask about `newCachedThreadPool` use cases: "It's acceptable for short-lived background tasks in CLI tools or tests where thread counts are bounded by the use case, not the executor."*

**Gotcha follow-up they'll ask:** *"What rejection policy would you use, and why?"*

> For a payment service: `CallerRunsPolicy` — when the pool is full, the Tomcat acceptor thread runs the task, which prevents it from accepting new HTTP connections until load drops. That's the system saying "slow down" to upstream callers. For a metrics ingestion service where losing data occasionally is acceptable: `DiscardOldestPolicy` — drop the stalest data and accept the new. `AbortPolicy` (the default) is fine only if the caller has a proper catch and retry loop.

---

#### Q3 — Concept Check

**"What is `ForkJoinPool` and when would you use it over a regular `ThreadPoolExecutor`?"**

**One-line answer:** ForkJoinPool uses work-stealing for recursive divide-and-conquer tasks — idle threads steal work from busy threads, maximising CPU utilisation without manual load balancing.

**Full answer to give in an interview:**

> "ForkJoinPool is designed for recursive tasks that fork themselves into subtasks. Each thread has its own deque of tasks. A thread pushes and pops from the front of its own deque — LIFO ordering, which means a thread works on the most recently forked subtask first, keeping related data hot in cache. When a thread runs out of work, it steals from the back of another thread's deque — FIFO ordering, which takes the oldest and largest chunks, naturally balancing the workload.
>
> You use `RecursiveTask<V>` when the task returns a value, `RecursiveAction` when it doesn't. `ForkJoinPool.commonPool()` is shared across the JVM and is what powers parallel streams and the default `CompletableFuture.runAsync()`.
>
> I'd reach for ForkJoinPool for CPU-bound recursive algorithms: parallel merge sort, parallel tree traversal, parallel map/reduce over large arrays. For I/O-bound tasks — database calls, HTTP requests — a regular `ThreadPoolExecutor` with an I/O-sized thread count is better, because ForkJoinPool's work-stealing adds overhead that only pays off when work can actually be recursively subdivided.
>
> One warning: avoid long-blocking operations in `commonPool()` — they starve parallel streams anywhere else in the application. Use a dedicated custom `ForkJoinPool` for blocking work."

*Keep this crisp. Interviewers usually want to know you understand the work-stealing concept and the commonPool warning, not that you can code merge sort.*

**Gotcha follow-up they'll ask:** *"How do you run a parallel stream in a custom ForkJoinPool instead of the common pool?"*

> Wrap it in a `ForkJoinPool.submit()` call: `customPool.submit(() -> list.parallelStream().map(...).collect(...)).get()`. The parallel stream picks up the ForkJoinPool from the thread's context.

---

#### Q4 — Design Scenario

**"How would you size the thread pool for a payment service that calls an external fraud-check API?"**

**One-line answer:** For I/O-bound tasks use `N × (1 + W/C)` — available CPU cores times one plus the ratio of wait time to compute time.

**Full answer to give in an interview:**

> "Thread pool sizing depends on whether the work is CPU-bound or I/O-bound. For CPU-bound tasks the formula is `N_cpu + 1` — one thread per core plus one spare to cover occasional page faults or GC pauses. More threads than that just adds context-switching overhead.
>
> A fraud-check API call is I/O-bound: the thread spends most of its time waiting for the network response. The formula is `N_cpu × (1 + W/C)` where W is the average wait time and C is the average compute time. If I have 8 cores, the fraud API averages 200ms response time, and my code spends 10ms doing actual computation per request: W/C = 20, so 8 × 21 = 168 threads. All 8 cores stay busy processing while threads wait for I/O.
>
> But I can't just set 168 without constraints. The fraud check service may only support 100 concurrent connections — so I'd cap at 100 and measure. I'd also instrument CPU utilisation, queue depth, and p99 latency under load. If CPU is under 50% and the queue is growing, add threads. If CPU is maxed out and latency is spiking, reduce threads and look at optimising the compute path. The formula gives a starting point; load testing gives the real answer."

*If they push on queue sizing: "I'd use an `ArrayBlockingQueue` sized to maybe 2–3× the thread count as a burst buffer, with `CallerRunsPolicy` so the HTTP layer slows down instead of queuing unboundedly."*

**Gotcha follow-up they'll ask:** *"What's the risk of setting thread count too high for I/O-bound tasks?"*

> More threads than the downstream system can handle floods it — you're doing your own denial of service. Also, each idle thread consumes ~512KB of stack and a file descriptor. Beyond a certain point, context-switching overhead and memory pressure actually reduce throughput. The formula accounts for the I/O ratio but not for downstream capacity limits — those come from load testing.

---

> **Common Mistake — Using `Executors.newFixedThreadPool` in production and assuming the max thread count protects you from memory issues:**
> The unbounded `LinkedBlockingQueue` backing `newFixedThreadPool` will happily absorb millions of tasks, consuming heap until the JVM OOMs. The thread count is bounded; the memory is not. Always use a custom `ThreadPoolExecutor` with a bounded `ArrayBlockingQueue` and a rejection policy that matches your resilience requirements.

**Quick Revision (one line):** Task flow is core threads → bounded queue → extra threads → rejection; unbounded queues make maximumPoolSize irrelevant; never use Executors factory methods in production; CallerRunsPolicy = backpressure; CPU-bound: N+1 threads; I/O-bound: N×(1+W/C).

---

## Topic 6: Concurrent Collections

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Amazon, Goldman Sachs, Google, Razorpay

---

### The Idea

Thread-safe collections existed since Java 1.0 in the form of `Vector` and `Hashtable` — they synchronised every method on the whole object. The result was correct but slow: one read blocked every other read and write. The `java.util.concurrent` package introduced a better model: collections that allow concurrent reads with minimal locking, and that expose atomic compound operations so you can never accidentally write a check-then-act race.

The key mental model is to distinguish three categories. `ConcurrentHashMap` is the workhorse — high-read, moderate-write scenarios, with atomic compound operations like `computeIfAbsent` that you must use instead of a separate `containsKey + put`. `CopyOnWriteArrayList` is the specialist — near-zero write rate, very high read rate, snap-shotted iteration that never throws `ConcurrentModificationException`. `BlockingQueue` is the coordinator — the natural foundation of producer-consumer pipelines, where `put()` and `take()` provide backpressure by blocking when the queue is full or empty.

Each has a failure mode when misused: using plain `get + put` instead of `computeIfAbsent` on a `ConcurrentHashMap` creates a race; using `CopyOnWriteArrayList` with frequent writes burns CPU copying arrays; using an unbounded `LinkedBlockingQueue` without backpressure lets the queue grow until OOM.

---

### How It Works

**ConcurrentHashMap — Java 8+ locking model (pseudocode):**
```
read(key):
    volatile-read node array       // no lock
    return bucket[hash(key)]

write(key, value):
    synchronized(bucket_head):     // lock only this bucket's head node
        update linked list

resize():
    full table lock                // lock entire table, rare
```

**Atomic compound operations — the operations you must use (pseudocode):**
```
// WRONG — two operations, race between them
if map.containsKey(key) == false:
    map.put(key, expensiveValue)   // another thread may insert here

// CORRECT — single atomic operation
map.computeIfAbsent(key, k -> expensiveValue)
```

**CopyOnWriteArrayList — write path (pseudocode):**
```
write(element):
    lock(this)
    newArray = copy(backingArray, length + 1)
    newArray[length] = element
    backingArray = newArray         // volatile write
    unlock(this)

read / iterate:
    snapshot = backingArray        // volatile read, no lock
    // iterate over snapshot — safe even if backing array replaced
```

**BlockingQueue operations reference table:**

| | Throws exception | Returns value | Blocks forever | Times out |
|---|---|---|---|---|
| Insert | `add()` | `offer()` | `put()` | `offer(e, t, u)` |
| Remove | `remove()` | `poll()` | `take()` | `poll(t, u)` |

**BlockingQueue implementations:**

| Implementation | Bounded | Lock Strategy | Use Case |
|---|---|---|---|
| `ArrayBlockingQueue` | Yes (mandatory) | Single ReentrantLock | Predictable memory, optional fairness |
| `LinkedBlockingQueue` | Optional | Separate put/take locks | Higher throughput when balanced |
| `SynchronousQueue` | N/A (size = 0) | CAS | Direct handoff; used by newCachedThreadPool |
| `PriorityBlockingQueue` | No | Single lock | Priority-ordered processing |

**The single most interview-critical gotcha — do not block inside `computeIfAbsent`:**

```java
// DANGEROUS — holds bucket lock while doing I/O
cache.computeIfAbsent(key, k -> {
    return restTemplate.getForObject(url, Config.class); // I/O inside locked section
});

// SAFE — compute outside, use putIfAbsent to race only on the insert
Config computed = restTemplate.getForObject(url, Config.class);
cache.putIfAbsent(key, computed); // may compute twice on first race, but no deadlock
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"Why is `map.containsKey(k)` followed by `map.put(k, v)` wrong on a ConcurrentHashMap, and what do you use instead?"**

**One-line answer:** The two calls are not atomic — another thread can insert between them, creating a duplicate; use `computeIfAbsent` which reads and writes as a single atomic operation.

**Full answer to give in an interview:**

> "Even though each individual ConcurrentHashMap operation is thread-safe, a sequence of two operations is not. Between `containsKey` returning false and `put` executing, another thread can call `put` with the same key. Both threads then insert, and the second insert silently overwrites the first — or you create two expensive objects when you intended one.
>
> `ConcurrentHashMap` provides atomic compound operations specifically for this: `putIfAbsent(key, value)` inserts only if the key is absent and returns the previous value if one existed. `computeIfAbsent(key, mappingFunction)` is better when creation is expensive — it calls the mapping function only if the key is absent, and the entire read-compute-insert sequence is atomic at the bucket level.
>
> One warning I always give: `computeIfAbsent` holds the internal node lock while the mapping function runs. Do not do I/O, call other `ConcurrentHashMap` operations, or do anything that could block or deadlock inside the function. If creation is expensive or involves I/O, compute the value outside and use `putIfAbsent` to race on the insert — you might compute twice on the very first concurrent call, but you avoid holding a lock across an I/O operation."

*If they probe on `compute` vs `computeIfAbsent`: "`compute` always runs the function, even if the key is present — it can update or remove the mapping. `computeIfAbsent` runs the function only if absent. `merge` inserts a value if absent, or applies a BinaryOperator to combine old and new if present."*

**Gotcha follow-up they'll ask:** *"Is `ConcurrentHashMap.size()` accurate?"*

> Not under concurrent modification. `size()` is approximate — the map uses a distributed cell-based counter (similar to LongAdder) to track size without global locking. Under concurrent puts and removes, `size()` may return a value that was never simultaneously true. Use it for monitoring and estimates, not for control flow.

---

#### Q2 — Tradeoff Question

**"When would you use `CopyOnWriteArrayList` and what are its costs?"**

**One-line answer:** Use it when reads vastly outnumber writes and lock-free iteration matters — every write copies the entire array, making it prohibitively expensive for frequent mutation.

**Full answer to give in an interview:**

> "CopyOnWriteArrayList works by making every write — add, remove, set — create a full copy of the backing array. The write is synchronized so only one copy happens at a time, and then the reference is atomically replaced with a volatile write. Reads and iterators capture the array reference at the moment they start, giving them a stable snapshot. They see the list as it was when they began iterating, even if another thread modifies it concurrently. No `ConcurrentModificationException` is ever thrown.
>
> This makes it perfect for patterns where the list is read many times per write cycle: event listener registrations (subscribe once, fire on every event), routing tables (updated on config reload, read on every request), observer pattern subscriber lists. The read path is completely lock-free.
>
> The cost is the write: O(n) time and O(n) memory for every mutation. A list of 10,000 listeners does a 10,000-element array copy on every subscribe or unsubscribe call. Under frequent writes that overhead dominates and you should use a `ReadWriteLock`-protected `ArrayList` or a `ConcurrentLinkedDeque` instead."

*If they ask about the iterator behaviour specifically: "The iterator is a snapshot iterator — it will not see any modifications made after the iterator was created. For most use cases this is a feature, not a bug."*

**Gotcha follow-up they'll ask:** *"What would you use instead of `CopyOnWriteArrayList` if writes are frequent?"*

> A `ReadWriteLock` wrapping a regular `ArrayList`: multiple readers can hold the read lock simultaneously, and a single writer holds the write lock exclusively. Reads are still concurrent; writes are exclusive but don't copy the array. For unordered collections with high write rates, `ConcurrentHashMap` as a set (using `Collections.newSetFromMap`) or `ConcurrentLinkedDeque` are options depending on the access pattern.

---

#### Q3 — Concept Check

**"Explain how `BlockingQueue` implements the producer-consumer pattern and what backpressure means here."**

**One-line answer:** `put()` blocks when the queue is full and `take()` blocks when empty — full-queue blocking is the backpressure signal that slows producers to match consumer speed.

**Full answer to give in an interview:**

> "BlockingQueue is the canonical Java tool for producer-consumer pipelines. The producer calls `put(item)` — if the queue has capacity the call returns immediately; if the queue is full the producer thread blocks until a consumer takes something. The consumer calls `take()` — if the queue has items the call returns one immediately; if the queue is empty the consumer blocks.
>
> This blocking behaviour is the backpressure mechanism. If consumers are slower than producers — say, payment execution is slower than order validation — the queue fills up and `put()` blocks the validation thread. The validation thread cannot accept new orders from the HTTP layer, which propagates the slowdown upstream to the client. The system regulates itself without dropping data or crashing.
>
> For implementation choice: `ArrayBlockingQueue` uses a single `ReentrantLock` for both put and take, so concurrent producers and consumers still serialise. `LinkedBlockingQueue` uses separate locks for the head and tail, allowing a producer and a consumer to proceed simultaneously as long as the queue is neither full nor empty — better throughput when production and consumption are balanced. `SynchronousQueue` has zero capacity — `put()` blocks until a thread is ready to `take()`, and vice versa. It is used in `Executors.newCachedThreadPool` to hand tasks directly to waiting threads."

*If they probe on poll vs take: "`poll(timeout, unit)` is usually better than `take()` in production — it allows the consumer loop to periodically check an interrupt flag or a shutdown signal, rather than blocking forever."*

**Gotcha follow-up they'll ask:** *"What happens if you use an unbounded `LinkedBlockingQueue` as the queue in this producer-consumer pipeline?"*

> You lose backpressure. The queue grows without bound — producers never block, consumers fall further behind, and eventually the heap fills with pending tasks and the JVM OOMs. Always use a bounded `ArrayBlockingQueue` in production pipelines where you need backpressure. Size the queue to absorb short bursts (typically 2–5× thread count) without allowing runaway growth.

---

#### Q4 — Design Scenario

**"Design a per-client rate limiter that can handle 10,000 concurrent clients using concurrent collections."**

**One-line answer:** Use `ConcurrentHashMap<ClientId, AtomicInteger>` with `computeIfAbsent` for lazy counter creation and a `ScheduledExecutorService` to reset counters each second.

**Full answer to give in an interview:**

> "The core data structure is a `ConcurrentHashMap` mapping client ID to a request counter. The critical operation is getting-or-creating the counter atomically:
>
> ```java
> AtomicInteger counter = requestCounts.computeIfAbsent(clientId, k -> new AtomicInteger(0));
> int count = counter.incrementAndGet();
> return count <= maxRequestsPerSecond;
> ```
>
> `computeIfAbsent` guarantees that even if 100 requests arrive for a new client simultaneously, only one `AtomicInteger` is created and stored — all 100 threads get the same counter. Then `incrementAndGet` is its own atomic CAS, so the increment is also race-free.
>
> For the reset every second, I'd schedule a `ScheduledExecutorService` task that calls `requestCounts.replaceAll((k, v) -> new AtomicInteger(0))`. The window reset is not perfectly atomic — a client could squeeze in a few extra requests during the replace — but for rate limiting that imprecision is typically acceptable. For strict guarantees, I'd switch from a counter-per-window to a token bucket with `AtomicLong` holding a fixed-point representation of tokens, topped up by the scheduler.
>
> Memory: 10,000 clients × ~48 bytes per AtomicInteger + CHM overhead is roughly 1–2MB — completely manageable. I'd also add periodic eviction of idle clients using `computeIfPresent` to avoid unbounded map growth."

*Pause after the design sketch. If they probe further, discuss sliding windows, token bucket algorithms, or distributed rate limiting with Redis.*

**Gotcha follow-up they'll ask:** *"Why not just use `synchronized` on a regular HashMap?"*

> A single lock serialises all 10,000 concurrent clients — every request blocks on every other request regardless of client ID. `ConcurrentHashMap` with node-level locking allows 10,000 concurrent operations on different keys to proceed in parallel. At 10,000 clients per second, the `synchronized` HashMap approach would be the throughput bottleneck.

---

> **Common Mistake — Doing I/O or blocking operations inside `computeIfAbsent`:**
> `computeIfAbsent` holds the internal bucket lock while the mapping function executes. If the function calls a database, an HTTP endpoint, or another `ConcurrentHashMap` operation that hashes to the same bucket, you can cause thread starvation or deadlock. The consequence is subtle — it may work fine in testing and only deadlock under contention in production. Always keep the mapping function fast, pure, and non-blocking; compute expensive values outside and use `putIfAbsent` to race on the insert.

**Quick Revision (one line):** Use `computeIfAbsent`/`compute`/`merge` for atomic compound operations on ConcurrentHashMap; never block inside the mapping function; CopyOnWriteArrayList for read-heavy, write-rare lists (O(n) write cost); BlockingQueue `put`/`take` provide natural backpressure in producer-consumer pipelines; always use bounded queues in production.

---

## Topic 7: Concurrency Problems

**Difficulty:** Hard | **Frequency:** Very High | **Companies:** Goldman Sachs, Amazon, Google, Morgan Stanley, Razorpay

---

### The Idea

Imagine four philosophers sitting around a table, each needing two chopsticks to eat. Each grabs the one on their left — now everyone is waiting for the one on their right, which their neighbor is holding. Nobody eats. That is a deadlock: a circular standstill where every participant is waiting for someone else to move first.

Livelock is the opposite problem: the philosophers all politely put their chopsticks down at the same time and reach again — simultaneously — forever. They are moving, they are responsive, but no one makes progress.

Starvation is quieter: one philosopher keeps getting skipped because the two beside them always eat at the same time. The food never runs out, but they never get a turn. Race conditions are different again — two philosophers reach for the last dumpling at the same time, both see it available, and both grab it. One ends up with nothing on their plate and confusion about why.

### How It Works

**Deadlock — four necessary conditions (Coffman):**

```
ALL four must be true for deadlock to occur:
1. Mutual exclusion  — resource can only be held by one thread
2. Hold-and-wait     — thread holds one lock and waits for another
3. No preemption     — locks cannot be forcibly taken away
4. Circular wait     — T1 waits for T2, T2 waits for T1 (cycle)

Break ANY one condition → deadlock impossible
```

**Classic deadlock scenario (pseudocode):**

```
Thread 1:                         Thread 2:
  acquire lock(accountA)            acquire lock(accountB)
  waiting for lock(accountB) ←→     waiting for lock(accountA)
  → DEADLOCK
```

**Prevention strategies:**

```
Strategy 1 — Lock ordering (break circular wait):
  always acquire locks in the same global order
  order = accountA.id < accountB.id ? [A, B] : [B, A]
  both threads acquire in same order → no cycle possible

Strategy 2 — tryLock with timeout (break hold-and-wait):
  try acquire lock1 with 50ms timeout
  if success, try acquire lock2 with 50ms timeout
  if lock2 fails → release lock1, sleep(randomBackoff), retry

Strategy 3 — Single global lock (break hold-and-wait):
  one lock guards all inter-account operations
  simpler, but serializes all transfers → throughput bottleneck
```

**The one interview-critical gotcha — deadlock with lock ordering:**

```java
// WRONG: different code paths acquire locks in different orders
public void transfer(Account from, Account to, double amount) {
    synchronized (from) {       // T1: holds accountA, waits for accountB
        synchronized (to) {     // T2: holds accountB, waits for accountA
            from.debit(amount); // DEADLOCK
            to.credit(amount);
        }
    }
}

// CORRECT: enforce consistent global order by account ID
public static boolean transfer(Account from, Account to, double amount)
        throws InterruptedException {
    Account first  = from.id() < to.id() ? from : to;
    Account second = from.id() < to.id() ? to   : from;

    if (first.lock().tryLock(100, TimeUnit.MILLISECONDS)) {
        try {
            if (second.lock().tryLock(100, TimeUnit.MILLISECONDS)) {
                try {
                    if (from.balance()[0] < amount) return false;
                    from.balance()[0] -= amount;
                    to.balance()[0]   += amount;
                    return true;
                } finally { second.lock().unlock(); }
            }
        } finally { first.lock().unlock(); }
    }
    return false; // caller retries with randomized backoff
}
```

**Livelock — pseudocode:**

```
Both threads retry at the same cadence:
  T1: acquire A, fail B, release A, sleep 50ms
  T2: acquire B, fail A, release B, sleep 50ms
  T1: acquire A, fail B, release A, sleep 50ms ...
  → No deadlock (nothing is blocked), but no progress either

Fix: randomized exponential backoff
  backoff = 10ms
  on failure: sleep(backoff + random(backoff))
              backoff = min(backoff * 2, 1000ms)
```

**Starvation — causes and fixes:**

```
Causes:
  - Non-fair locking: new threads "barge in" ahead of waiting threads
  - Thread priority monopolization
  - Long critical sections blocking all others

Fixes:
  - new ReentrantLock(true)   → fair FIFO ordering
  - Narrow critical sections
  - ConcurrentHashMap instead of synchronized HashMap
```

**Race condition — types:**

| Type | Example | Fix |
|---|---|---|
| Check-then-act | `if (balance >= x) { deduct x }` | Synchronize the whole check+act block |
| Read-modify-write | `count++` (not atomic) | `AtomicInteger.incrementAndGet()` |
| Put-if-absent | `if (!map.containsKey(k)) map.put(k,v)` | `ConcurrentHashMap.computeIfAbsent()` |

**Race condition — the interview gotcha:**

```java
// WRONG: check and act are two separate operations — race window in between
public boolean withdrawUnsafe(long amount) {
    if (remainingLimit.get() >= amount) {  // check passes at T=0
        // another thread withdraws here at T=1 — balance now insufficient
        remainingLimit.addAndGet(-amount); // act at T=2 — goes negative
        return true;
    }
    return false;
}

// CORRECT: CAS loop — atomic check-and-update
public boolean withdraw(long amount) {
    while (true) {
        long current = remainingLimit.get();
        if (current < amount) return false;
        long updated = current - amount;
        if (remainingLimit.compareAndSet(current, updated)) {
            return true; // atomically swapped — no other thread can sneak in
        }
        // CAS failed: someone else changed it first, retry
    }
}
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is a deadlock, and what are the four conditions required for it to occur?"**

**One-line answer:** Deadlock is a circular standstill where each thread holds a lock another thread needs — four conditions must all be true simultaneously.

**Full answer to give in an interview:**

> "A deadlock happens when two or more threads each hold a resource the other needs, and neither can proceed. Four conditions must hold simultaneously — remove any one and deadlock becomes impossible. First, mutual exclusion: a lock can only be held by one thread. Second, hold-and-wait: a thread holds at least one lock while waiting for another. Third, no preemption: you cannot forcibly take a lock away from a thread. Fourth, circular wait: thread A waits for a lock held by thread B, which waits for a lock held by A.
>
> The classic example is a money transfer: Thread 1 locks account A then tries to lock account B; Thread 2 locks account B then tries to lock account A. They are stuck forever.
>
> The standard fix is lock ordering — always acquire locks in a deterministic global order, for example by sorting accounts by ID. This breaks circular wait. A safer alternative is `tryLock` with a timeout: if you cannot acquire the second lock within 100ms, release the first lock and retry with randomized backoff to avoid livelock."

*Lead with the four conditions by name — interviewers at Goldman Sachs and Amazon expect you to name them, not just describe the concept.*

**Gotcha follow-up they'll ask:** *"Can you have a deadlock with a single lock?"*

> "No — a single lock cannot form a cycle. A thread holding its own lock trying to re-acquire it would cause a hang only if the lock is non-reentrant (which `synchronized` and `ReentrantLock` are not). Deadlock by definition requires a cycle across at least two resources held by different threads."

---

#### Q2 — Tradeoff Question

**"What is the difference between deadlock, livelock, and starvation?"**

**One-line answer:** Deadlock: all stuck, no one moves. Livelock: all moving, no one progresses. Starvation: one thread perpetually skipped while others proceed.

**Full answer to give in an interview:**

> "These are three distinct failure modes. In a deadlock, threads are blocked — completely frozen, waiting for locks that will never be released. The system is stuck. In a livelock, threads are actively running and responding to each other, but their responses keep cancelling each other out — like two people in a corridor who both step aside in the same direction, forever. The canonical code example is two threads both retrying lock acquisition at the same fixed interval: neither ever gets both locks.
>
> Starvation is different — the system makes progress overall, but one particular thread never gets CPU time or lock access. This happens with non-fair locks where newly arriving threads barge ahead of threads that have been waiting, or when thread priorities are misused.
>
> Livelock is fixed with randomized exponential backoff on retry — add a random jitter to the sleep time so the two threads desynchronize. Starvation is fixed with `new ReentrantLock(true)` — the fair flag enforces FIFO ordering so every waiting thread eventually gets the lock."

*Interviewers use this as a filter question — many candidates conflate livelock and deadlock. The word "actively running" is the key distinguisher for livelock.*

**Gotcha follow-up they'll ask:** *"How do you detect a deadlock in production?"*

> "Take a thread dump with `jstack <pid>` or `jcmd <pid> Thread.print`. JVM thread dumps include a 'Found one Java-level deadlock' section that names the cycle explicitly. For continuous monitoring, `ThreadMXBean.findDeadlockedThreads()` returns the IDs of deadlocked threads and can be polled in a background health-check thread or an integration test."

---

#### Q3 — Design Scenario

**"You are building a payment transfer service. Two threads process A→B and B→A simultaneously and the system freezes. How do you diagnose and fix it?"**

**One-line answer:** Take a thread dump to confirm the deadlock cycle, then fix by enforcing consistent lock acquisition order by account ID.

**Full answer to give in an interview:**

> "I'd start diagnosis by running `jstack <pid>` on the JVM. The output will show a deadlock section naming exactly which threads are waiting, which locks they hold, and which lock each is waiting for. That confirms the circular wait.
>
> The root cause is acquiring locks in different orders: the A→B thread locks account A first, then B; the B→A thread locks account B first, then A. They form a cycle.
>
> The fix is lock ordering — always acquire locks in ascending account ID order. Compute `first = min(from.id, to.id)`, `second = max(from.id, to.id)`, acquire `first` then `second`. Both threads now always acquire in the same order — no cycle can form.
>
> For extra safety I'd use `tryLock` with a 100ms timeout on each acquisition. If I cannot get both locks, I release whatever I hold and retry after a randomized backoff — this prevents livelock if two transfers are genuinely contending. I'd also add a `ThreadMXBean.findDeadlockedThreads()` assertion in the integration test suite to catch regressions before they reach production."

*Mention jstack, lock ordering by ID, and tryLock — those three together signal you have production debugging experience.*

**Gotcha follow-up they'll ask:** *"What is a race condition, and is it the same as a data race?"*

> "A race condition is a correctness bug where program behavior depends on thread timing — the most common form is check-then-act: you check a condition, another thread changes it before you act, and you proceed on stale information. A data race is narrower: it is specifically when two threads access the same variable concurrently with no synchronization and at least one access is a write. You can have a race condition without a data race — for example, two threads each doing an atomic `get()` followed by an atomic `set()` on a `ConcurrentHashMap` have no data race but still have a check-then-act race condition. The fix for race conditions is to make the check and act a single atomic operation."

---

#### Q4 — Concept Check

**"How does `AtomicInteger.compareAndSet` eliminate a race condition on a shared counter?"**

**One-line answer:** CAS is a single uninterruptible CPU instruction — it reads, compares, and conditionally writes in one atomic step, closing the race window that exists between a separate read and write.

**Full answer to give in an interview:**

> "The race condition in `count++` is that it expands to three operations: read the current value, add one, write back. Another thread can run between the read and the write and increment the same value, causing a lost update.
>
> `compareAndSet(expected, updated)` maps to the `CMPXCHG` instruction on x86-64 — a single CPU instruction that reads the memory location, checks it equals `expected`, and only writes `updated` if it does. This is atomic at the hardware level; no other thread can interrupt it.
>
> The standard usage is a CAS loop: read the current value into a local variable, compute the new value, then call `compareAndSet(current, newValue)`. If it returns `true`, the update succeeded. If it returns `false`, another thread changed the value between your read and your CAS — you loop and retry with the fresh value. This is the same mechanism used inside `ConcurrentHashMap`, `LongAdder`, and most of Java's `java.util.concurrent` data structures.
>
> For high-contention counters — like a request counter hit by thousands of threads — `LongAdder` is faster than `AtomicLong` because it maintains a cell per CPU and only aggregates on `sum()`, reducing CAS contention."

*The CMPXCHG detail signals hardware-level understanding — drop it casually to differentiate yourself.*

**Gotcha follow-up they'll ask:** *"Can you use `volatile` to fix a race condition on `count++`?"*

> "No. `volatile` guarantees visibility — every read sees the most recent write — but it does not make compound operations atomic. `count++` is still a read-then-write across two operations even on a volatile variable. Thread A reads 5, Thread B reads 5, Thread A writes 6, Thread B writes 6 — you lost one increment. You need `AtomicInteger` or synchronization."

---

> **Common Mistake — Synchronizing check and act in separate methods:**
> Declaring both `checkBalance()` and `deductBalance()` as `synchronized` does not prevent a race. Each method acquires the lock independently — another thread can run between the two calls. The check and act must be inside a single `synchronized` block or CAS loop to be atomic.

**Quick Revision (one line):** Deadlock = circular lock wait (fix: lock ordering by ID); livelock = mutual interference with no progress (fix: randomized backoff); starvation = thread perpetually skipped (fix: fair lock); race condition = timing-dependent correctness failure (fix: atomic CAS or single synchronized block covering check + act).

---

## Topic 8: Real-World Patterns

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Goldman Sachs, Amazon, Atlassian, Razorpay, Flipkart

---

### The Idea

Think of a highway toll plaza. Cars arrive (producers) at unpredictable rates and line up in lanes (a queue). Toll booth operators (consumers) process one car at a time. The queue absorbs bursts — when traffic spikes, cars wait in lane rather than crashing the booth. When all lanes are full, cars are turned away (backpressure). This is the Producer-Consumer pattern: the queue is the bounded buffer that decouples arrival rate from processing rate.

Now imagine each toll booth operator carries a clipboard with the current shift's rules — speed limits, discount codes, special flags. That clipboard belongs only to that operator and changes with every shift. It is not shared with other operators; no coordination is needed to read it. This is ThreadLocal: a per-thread variable that is isolated from all other threads, so each thread can read and write its own copy without synchronization.

Both patterns appear constantly in backend systems. Producer-Consumer is the backbone of every payment processing pipeline, log ingestion system, and message queue consumer. ThreadLocal is the mechanism behind Spring Security's `SecurityContextHolder`, SLF4J's MDC (logging correlation IDs), and every web framework that attaches a request context to a thread.

### How It Works

**Producer-Consumer — why BlockingQueue is the right tool:**

```
Without BlockingQueue (manual wait/notify):
  producer must call wait() when queue full
  consumer must call notifyAll() after consuming
  easy to get wrong — missed signals, spurious wakeups

With BlockingQueue (the correct approach):
  put()  → blocks the producer when queue is full (backpressure built in)
  take() → blocks the consumer when queue is empty
  No explicit wait/notify, no synchronized blocks needed
  Bounded queue = natural backpressure upstream
```

**Poison pill shutdown (pseudocode):**

```
Define a sentinel constant: POISON_PILL = special PaymentRequest("POISON")

Producer sends shutdown:
  queue.put(POISON_PILL)

Each consumer:
  loop:
    req = queue.take()
    if req == POISON_PILL:
      queue.put(POISON_PILL)  // re-publish for the other consumers
      stop
    else:
      processPayment(req)
```

**The one interview-critical gotcha — backpressure via bounded queue:**

```java
public class PaymentProcessingPipeline {

    private static final PaymentRequest POISON = new PaymentRequest("POISON");

    // Bounded queue — put() blocks producers when 500 slots full
    private final BlockingQueue<PaymentRequest> queue
        = new ArrayBlockingQueue<>(500);
    private final ExecutorService consumerPool
        = Executors.newFixedThreadPool(10);

    public void startConsumers() {
        for (int i = 0; i < 10; i++) consumerPool.submit(this::consumeLoop);
    }

    private void consumeLoop() {
        while (!Thread.currentThread().isInterrupted()) {
            try {
                PaymentRequest req = queue.poll(1, TimeUnit.SECONDS);
                if (req == null) continue;        // timed out, loop again
                if (req == POISON) {
                    queue.put(POISON);            // re-signal remaining consumers
                    return;
                }
                processPayment(req);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }
        }
    }

    public void submitPayment(PaymentRequest req) throws InterruptedException {
        queue.put(req); // blocks here when queue full — this IS the backpressure
    }

    public void shutdown() throws InterruptedException {
        queue.put(POISON);
        consumerPool.shutdown();
        consumerPool.awaitTermination(30, TimeUnit.SECONDS);
    }

    record PaymentRequest(String id) {}
}
```

**ThreadLocal — internals:**

```
Each Thread object owns a ThreadLocalMap (not a global map).
A ThreadLocal<T> is just a key into the current thread's map.

Access is O(1) — no synchronization ever needed.
The entry lives as long as the thread lives.

Thread pool risk:
  Pool threads live forever.
  If you set a ThreadLocal and never call remove():
    - the entry stays in the thread's map across requests
    - Thread 2's request on the same thread sees Thread 1's data
    - (context bleed — a security bug in web apps)
    - The value is strongly referenced → memory leak

Fix: always call remove() in a finally block.
```

**ThreadLocal memory leak mechanism:**

```
ThreadLocalMap uses weak keys (the ThreadLocal reference)
but strong values (the object you stored).

If the ThreadLocal variable itself is GC'd (goes out of scope):
  → the key becomes null (weak ref cleared)
  → the value is still strongly referenced by the map
  → the entry is never collected → memory leak

Prevention: call threadLocal.remove() before the request finishes.
```

**ThreadLocal — the interview-critical pattern:**

```java
public class RequestContext {

    private static final ThreadLocal<String> correlationId  = new ThreadLocal<>();
    private static final ThreadLocal<Long>   requestStartTime = new ThreadLocal<>();

    public static void init() {
        correlationId.set(UUID.randomUUID().toString());
        requestStartTime.set(System.currentTimeMillis());
    }

    public static String getCorrelationId()   { return correlationId.get(); }
    public static long   getRequestDuration() {
        Long start = requestStartTime.get();
        return start != null ? System.currentTimeMillis() - start : -1;
    }

    // CRITICAL: always in finally — thread pool threads never die
    public static void clear() {
        correlationId.remove();
        requestStartTime.remove();
    }

    public static void simulateRequestHandling(Runnable handler) {
        try {
            init();
            handler.run();
        } finally {
            clear(); // missing this = context bleed into next request on same thread
        }
    }
}
```

**BlockingQueue implementations — when to use which:**

| Implementation | Bound | Use Case |
|---|---|---|
| `ArrayBlockingQueue(n)` | Bounded | Payment pipeline, task queue — backpressure required |
| `LinkedBlockingQueue()` | Unbounded (Integer.MAX_VALUE) | Risk: unbounded growth → OOM |
| `SynchronousQueue` | Zero capacity | Direct handoff — producer blocks until consumer ready |
| `PriorityBlockingQueue` | Unbounded | Priority-ordered processing (e.g., VIP payments first) |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Design Scenario

**"Design a payment processing pipeline that decouples HTTP request handlers from payment processors and handles backpressure."**

**One-line answer:** Use a bounded `BlockingQueue` as the buffer between producer threads (HTTP handlers) and consumer threads (payment processors) — `put()` on a full queue blocks the producer, which is the backpressure mechanism.

**Full answer to give in an interview:**

> "I'd use the Producer-Consumer pattern with a `BlockingQueue` as the shared buffer. HTTP handlers are producers: they call `queue.put(paymentRequest)`. Payment processors are consumers running in a fixed thread pool: each loops calling `queue.poll(1, TimeUnit.SECONDS)` and processes whatever it takes.
>
> The key design choice is using a bounded queue — `new ArrayBlockingQueue<>(500)`. When all 500 slots are occupied (consumers are fully busy), `put()` blocks the HTTP handler thread. This creates natural backpressure: the system stops accepting new requests at exactly the rate it cannot process them. Without a bounded queue, requests pile up in memory until the JVM OOMs.
>
> For shutdown, I use a poison pill pattern: a sentinel `PaymentRequest` with a special ID. The shutdown method puts one poison pill into the queue. The first consumer that reads it re-publishes it before stopping, so every consumer eventually sees it. I pair this with `consumerPool.awaitTermination(30, TimeUnit.SECONDS)` to wait for in-flight payments to finish before the JVM exits.
>
> For exception handling in consumers: wrap `processPayment` in a try-catch, log the failure with the correlation ID, and push the failed request to a dead-letter queue for later replay. Never let an uncaught exception kill a consumer thread — the pool size would silently shrink."

*Mention bounded queue + backpressure explicitly — that is the first-principles answer interviewers at Razorpay and Goldman Sachs are listening for.*

**Gotcha follow-up they'll ask:** *"How would you implement a priority-based payment queue — VIP payments processed first?"*

> "`PriorityBlockingQueue` with a `Comparator` on `PaymentRequest` by priority tier. Important caveat: `PriorityBlockingQueue` is unbounded — it has no backpressure. For a production system, I would wrap it with a semaphore or a secondary size check to bound the total number of queued requests. Alternatively, maintain two separate `ArrayBlockingQueue`s — one for VIP, one for standard — and have consumers drain the VIP queue first using a poll-with-timeout strategy."

---

#### Q2 — Concept Check

**"What is ThreadLocal, and why do you need to call `remove()` in a thread pool environment?"**

**One-line answer:** `ThreadLocal` gives each thread its own isolated copy of a variable; in a thread pool, threads are reused across requests — without `remove()`, the previous request's data bleeds into the next request on the same thread.

**Full answer to give in an interview:**

> "A `ThreadLocal<T>` is a per-thread variable. Each `Thread` object carries a `ThreadLocalMap` — when you call `threadLocal.set(value)`, the value is stored in the current thread's own map. Reads and writes require no synchronization because no other thread can see your thread's copy.
>
> This is how Spring Security's `SecurityContextHolder` works: a servlet filter sets the authenticated user into a `ThreadLocal` at the start of the request. Every downstream service in the call chain calls `SecurityContextHolder.getContext().getAuthentication()` without any method parameters being passed — the context travels on the thread.
>
> The danger in thread pools: pool threads are never destroyed between requests. If request A sets `correlationId` to `'abc-123'` and the filter fails to call `remove()` before returning, request B — processed on the same thread — will call `correlationId.get()` and see `'abc-123'`. This is a context-bleed bug that can leak PII between users.
>
> There is also a memory leak dimension: `ThreadLocalMap` holds a strong reference to the value object. If the `ThreadLocal` key itself is garbage collected (weak reference), the value becomes unreachable via normal GC paths but is still strongly held by the map entry. The fix is always calling `remove()` in a `finally` block — that explicitly clears the entry and prevents both context bleed and memory accumulation."

*The context-bleed example with PII is the detail that signals production experience at Atlassian and Amazon-level interviews.*

**Gotcha follow-up they'll ask:** *"What is `InheritableThreadLocal` and when would you use it?"*

> "`InheritableThreadLocal` causes child threads to inherit the parent thread's ThreadLocal values at the moment of creation. This is useful for propagating a request correlation ID into async tasks — for example, when a payment service spawns a child thread for an asynchronous notification, the child inherits the request's correlation ID so logs from both the parent and child can be correlated. The caveat with thread pools: threads are created once at pool startup, not per request — they inherit the creation-time values, not per-task values. For task-scoped propagation in thread pools you need to manually copy and clear the ThreadLocal at task boundaries, or use `TransmittableThreadLocal` (a third-party library)."

---

#### Q3 — Tradeoff Question

**"When would you choose `SynchronousQueue` over `ArrayBlockingQueue` for a producer-consumer pipeline?"**

**One-line answer:** Use `SynchronousQueue` when you want direct handoff with zero buffering — each producer is paired directly with a consumer and blocks until a consumer is ready to take the item.

**Full answer to give in an interview:**

> "`SynchronousQueue` has zero capacity — it is not a queue in the traditional sense, it is a rendezvous point. A producer's `put()` blocks until a consumer is ready to call `take()`. They synchronize directly.
>
> This is useful in two scenarios. First, when you want to bound latency rather than throughput: if no consumer is available right now, the producer gets immediate backpressure feedback rather than silently buffering. A payment retry service might use this — if no retry worker is free, the HTTP handler should return a 503 immediately rather than let items pile up. Second, `Executors.newCachedThreadPool()` uses `SynchronousQueue` internally: each submitted task hands off directly to an existing idle thread or triggers a new thread creation.
>
> `ArrayBlockingQueue` is better when you want to absorb bursts — the buffer smooths out spikes in arrival rate without blocking producers immediately. The tradeoff is that buffered items represent in-flight work that can be lost on a crash. For payment systems, I would use `ArrayBlockingQueue` with a bounded size for throughput smoothing, and combine it with a persistent queue (Kafka, RabbitMQ) for durability."

*Mentioning `newCachedThreadPool`'s internal use of `SynchronousQueue` is a signal that you have read the JDK source — it consistently impresses at Google and Goldman.*

**Gotcha follow-up they'll ask:** *"Is ThreadLocal thread-safe?"*

> "The question is a slight category error. ThreadLocal is per-thread by definition — there is no sharing between threads, so thread-safety in the synchronization sense is irrelevant. Each thread reads and writes only its own copy; no lock is needed. However, the *objects stored inside* the ThreadLocal can still be shared if you expose them across threads. If you store a mutable object in a ThreadLocal and then pass a reference to that object to another thread, that object can race. ThreadLocal isolates access by thread; it does not make objects immutable."

---

#### Q4 — Design Scenario

**"How does Spring Security use ThreadLocal, and what risk does this create?"**

**One-line answer:** Spring Security stores the authenticated `SecurityContext` in a `ThreadLocal` in a servlet filter, making it available to any code in the request without parameter passing — the risk is context bleed if `clearContext()` is not called in the filter's finally block.

**Full answer to give in an interview:**

> "Spring Security's `SecurityContextHolder` uses a `ThreadLocalSecurityContextHolderStrategy` by default. At the start of each request, `SecurityContextPersistenceFilter` loads the security context (from session or token validation) and calls `SecurityContextHolder.setContext(context)` — this writes into a `ThreadLocal` keyed to the current thread.
>
> Every downstream component — service layer, repository, even custom `@PreAuthorize` annotations — calls `SecurityContextHolder.getContext().getAuthentication()` to get the current user. No one has to pass the `Authentication` object as a parameter. This is clean architecture: the cross-cutting concern travels on the thread.
>
> The risk: if the filter does not clear the context in a finally block, the next request processed by the same thread in the Tomcat/Jetty thread pool inherits the previous user's context. User A's authentication context can be seen by User B's request. Spring's own filter does call `SecurityContextHolder.clearContext()` in a finally block — the risk appears when developers write custom filters or interceptors without following the same pattern.
>
> In Java 21 with virtual threads, there is an additional wrinkle: `SecurityContextHolder` can be configured with `MODE_INHERITABLETHREADLOCAL` so async child threads see the parent's context — but with virtual threads and `newVirtualThreadPerTaskExecutor()`, thousands of threads may inherit the same context object. This is where Spring recommends migrating to `ScopedValue` (Java 21 preview) for immutable, scope-bound propagation."

*The Java 21 / ScopedValue angle shows awareness of emerging patterns — drop it only if the interviewer has already signaled familiarity with Java 21.*

**Gotcha follow-up they'll ask:** *"How would you propagate a correlation ID from a parent thread to tasks submitted to an `ExecutorService`?"*

> "The safest approach is to capture the correlation ID before submitting the task and close over it in the lambda: `String id = RequestContext.getCorrelationId(); executor.submit(() -> { RequestContext.set(id); try { doWork(); } finally { RequestContext.clear(); } });`. This avoids any ThreadLocal inheritance complexity. For a framework-level solution, I would wrap the `ExecutorService` with a decorator that captures and restores the ThreadLocal context around every submitted task — this is essentially what MDC-aware executors in Logback do."

---

> **Common Mistake — Using an unbounded queue in production:**
> `new LinkedBlockingQueue<>()` has a capacity of `Integer.MAX_VALUE` — it will never block producers. Under load spikes the queue grows without bound, consuming heap until the JVM throws `OutOfMemoryError`. Always size your queue explicitly: `new ArrayBlockingQueue<>(N)` where N reflects the maximum in-flight work your consumers can handle.

**Quick Revision (one line):** Producer-Consumer: bounded `BlockingQueue` as buffer — `put()` = backpressure, `take()` = blocking wait, poison pill = graceful shutdown; ThreadLocal: per-thread isolated variable, no synchronization needed, always `remove()` in finally in thread pool environments to prevent context bleed and memory leaks.

---

## Topic 9: Java 21 — Virtual Threads

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Goldman Sachs

---

### The Idea

A traditional Java thread is a 1:1 wrapper around an OS thread. Creating one costs about 1ms and ~512KB of stack memory. A typical server with 200 threads is servicing 200 concurrent requests — and 190 of those threads are doing nothing at any instant except waiting for a database to respond. The OS is juggling 200 stacks for 10 threads worth of actual CPU work.

Virtual threads flip this model. The JVM manages a pool of a handful of OS "carrier" threads. It runs virtual threads on top of them like a lightweight scheduler. When a virtual thread hits a blocking call — a JDBC query, an HTTP call, a `Thread.sleep()` — the JVM unmounts it from its carrier thread in microseconds, lets another virtual thread use that carrier, and remounts the original virtual thread when the I/O completes. The OS thread is never parked; it always has work.

The result: you can spawn one virtual thread per incoming request — one per database connection, one per downstream API call. Hundreds of thousands of them. They cost microseconds to create and a few hundred bytes on the heap. The thread-per-request model becomes feasible at a scale that would have required reactive programming (CompletableFuture chains, Project Reactor) before Java 21.

### How It Works

**Platform thread vs. virtual thread — the numbers:**

| Property | Platform Thread (Java ≤ 17) | Virtual Thread (Java 21) |
|---|---|---|
| OS mapping | 1:1 (one OS thread each) | M:N (millions → handful of OS threads) |
| Stack memory | ~512KB–1MB per thread | Heap-allocated, grows as needed (~KB) |
| Creation cost | ~1ms (kernel syscall) | ~microseconds |
| Practical limit | ~10,000 threads | 100K–10M tested |
| Best for | CPU-bound work | I/O-bound work |

**Mount / unmount lifecycle (pseudocode):**

```
Virtual thread VT1 runs on carrier OS thread C1:
  VT1.executeCode()
  VT1 calls socket.read()           ← blocking I/O
    JVM: unmount VT1 from C1        ← happens in microseconds
    JVM: mount VT2 on C1            ← C1 continues without parking
    ... time passes, I/O completes ...
    JVM: re-mount VT1 on an available carrier thread
    VT1.continueAfterRead()
```

**The one interview-critical gotcha — pinning with synchronized:**

```java
// PROBLEM: synchronized block + blocking I/O = carrier thread pinned
// The JVM cannot unmount a virtual thread that is inside a synchronized block
// The carrier thread is stuck waiting — defeats the entire purpose

void processWithPinning() {
    synchronized (this) {          // virtual thread enters synchronized
        String result = callDatabase(); // blocks here → carrier thread PINNED
        // other virtual threads cannot use this carrier until I/O returns
    }
}

// FIX: replace synchronized with ReentrantLock for sections that may block on I/O
private final ReentrantLock lock = new ReentrantLock();

void processWithoutPinning() {
    lock.lock();
    try {
        String result = callDatabase(); // blocks → virtual thread unmounts cleanly
        // carrier thread is freed for other virtual threads while I/O waits
    } finally {
        lock.unlock();
    }
}

// Creating virtual threads — two patterns:
// 1. Named virtual thread
Thread.ofVirtual().name("payment-vt").start(() -> processPayment());

// 2. Executor (preferred in production)
try (ExecutorService vte = Executors.newVirtualThreadPerTaskExecutor()) {
    IntStream.range(0, 100_000).forEach(i ->
        vte.submit(() -> simulateIOBoundTask(i))
    );
} // try-with-resources → auto-shutdown + awaitTermination
```

**What virtual threads do NOT change:**

```
Synchronization model:         unchanged — synchronized, volatile, happens-before all apply
CPU-bound parallelism:         unchanged — still limited by available CPU cores
Thread.currentThread():        still works — returns the virtual thread
Thread.sleep():                works — unmounts instead of parking OS thread
ThreadLocal:                   works — but scoped values (JEP 446) are preferred
                               for virtual threads: immutable, no remove() needed
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What are virtual threads in Java 21, and how are they different from platform threads?"**

**One-line answer:** Virtual threads are JVM-managed, heap-allocated threads that multiplex millions of lightweight execution contexts onto a small pool of OS carrier threads — when a virtual thread blocks on I/O, the carrier thread is freed immediately for another virtual thread.

**Full answer to give in an interview:**

> "Platform threads — Java's traditional threads — map 1:1 to OS threads. Each one costs about 512KB of stack and ~1ms to create via a kernel call. A server with 1,000 platform threads is burning 500MB just for stacks, and most threads spend the majority of their time waiting for I/O.
>
> Virtual threads, introduced as a GA feature in Java 21 (JEP 444), break that 1:1 mapping. The JVM runs a small pool of OS 'carrier' threads — typically one per CPU core. Millions of virtual threads are scheduled on top. When a virtual thread blocks — on a database query, an HTTP call, a `Thread.sleep()` — the JVM unmounts it from its carrier thread in microseconds, stores its stack state on the heap, and immediately mounts another runnable virtual thread on that carrier. The OS thread is never idle.
>
> The practical implication: you can spawn one virtual thread per incoming HTTP request without worrying about the thread count. A payment gateway handling 50,000 concurrent requests, each waiting 50ms for a database response, would need a 50,000 platform-thread pool (25GB of stacks). With virtual threads, 10 carrier threads and a few hundred MB of heap handle the same load.
>
> One critical constraint: virtual threads are designed for I/O-bound workloads. For CPU-bound work, virtual threads do not provide additional parallelism beyond the number of CPU cores — the carrier threads are still the ceiling. For CPU-bound tasks you still want `ForkJoinPool` with work-stealing."

*Lead with the mount/unmount mechanism — that is the mechanism question interviewers at Amazon and Google are listening for.*

**Gotcha follow-up they'll ask:** *"What is pinning, and when does it happen with virtual threads?"*

> "Pinning is when a virtual thread cannot be unmounted from its carrier thread even when it blocks. This happens in two cases: when the virtual thread is inside a `synchronized` block or method when it hits a blocking call, and when it is executing a native method. The JVM's unmounting mechanism cannot operate through the JVM's monitor protocol (`synchronized`) — so the carrier thread parks along with the virtual thread, defeating the purpose. The fix is to replace `synchronized` blocks that contain I/O calls with `ReentrantLock`, which allows clean unmounting. JDK 24+ has been progressively fixing internal JDK classes to avoid synchronized+I/O combinations for exactly this reason."

---

#### Q2 — Tradeoff Question

**"Should you always prefer virtual threads over platform threads in Java 21?"**

**One-line answer:** No — virtual threads are designed for I/O-bound tasks; CPU-bound work sees no benefit and should still use a bounded `ForkJoinPool` or fixed thread pool sized to core count.

**Full answer to give in an interview:**

> "Virtual threads are a replacement for platform threads specifically in I/O-bound scenarios — web handlers waiting for database responses, microservice clients waiting for downstream HTTP calls, anything where threads spend most of their time blocked. The JVM multiplexes carrier threads across virtual threads only when virtual threads are actually waiting; if they are computing, they sit on a carrier thread the entire time, and you gain nothing over a platform thread.
>
> For CPU-bound work — image processing, cryptography, data compression, ML inference — the right tool is still a fixed-size platform thread pool sized to `availableProcessors()` or `N+1`. Adding more threads than CPU cores just increases context-switch overhead with no throughput gain.
>
> There is also the pinning risk: if existing code uses `synchronized` blocks that happen to contain I/O (for example, older JDBC drivers or third-party libraries using `synchronized` internally), switching to virtual threads can silently pin carrier threads under load. Before migrating a service to virtual threads, you should enable JVM pinning warnings with `-Djdk.tracePinnedThreads=full` and audit any synchronized blocks that could call I/O.
>
> The migration guidance for a Java 21 upgrade: replace `Executors.newFixedThreadPool(200)` with `Executors.newVirtualThreadPerTaskExecutor()` for I/O-bound services, audit for synchronization+I/O combinations, and replace `ThreadLocal` usages with `ScopedValue` (JEP 446, preview in Java 21) where the immutability and scope-bounding semantics are a better fit."

*The pinning + `-Djdk.tracePinnedThreads` flag is a production-readiness signal that differentiates you from candidates who only know the marketing pitch.*

**Gotcha follow-up they'll ask:** *"How do ThreadLocal and virtual threads interact?"*

> "`ThreadLocal` works with virtual threads — `set()`, `get()`, `remove()` all function correctly. The concern is scale: with millions of virtual threads, if each carries a large `ThreadLocal` value, heap usage grows proportionally. The deeper issue is mutation — `ThreadLocal` is mutable, and in a highly concurrent virtual-thread workload, managing when to set and clear it across millions of short-lived tasks becomes fragile. Java 21 introduces `ScopedValue` (JEP 446, preview) as the preferred alternative: a `ScopedValue` is immutable within a defined scope, automatically cleared when the scope exits, and is safely inherited by child threads within the scope without the remove-in-finally ceremony. Think of it as a call-stack variable that is visible to all code within a delimited scope, not a per-thread mutable slot."

---

#### Q3 — Design Scenario

**"A payment gateway currently uses a 200-thread fixed pool and is hitting throughput limits under 10,000 concurrent requests. How would you migrate it to virtual threads?"**

**One-line answer:** Replace `Executors.newFixedThreadPool(200)` with `Executors.newVirtualThreadPerTaskExecutor()`, audit for synchronized+I/O pinning, and replace any `ThreadLocal` usages that may accumulate across millions of threads.

**Full answer to give in an interview:**

> "The first step is verifying the bottleneck is actually I/O-bound — check thread dump to confirm threads are in `TIMED_WAITING` or `WAITING` state waiting for JDBC, HTTP, or cache calls. If they are CPU-saturated, virtual threads will not help.
>
> Assuming it is I/O-bound: I swap the executor to `Executors.newVirtualThreadPerTaskExecutor()`. This creates one virtual thread per submitted task — each incoming request gets its own thread. The synchronous, thread-per-request code style is preserved exactly; no reactive rewrites needed.
>
> Next I audit for pinning. I add `-Djdk.tracePinnedThreads=full` to JVM startup flags and run load tests. Any log lines show the exact stack frames where pinning occurs — typically synchronized JDBC driver internals or legacy library code. For JDBC: HikariCP with recent PostgreSQL drivers is already virtual-thread friendly. For custom code: replace synchronized blocks that contain database calls with `ReentrantLock`.
>
> I also review `ThreadLocal` usage. With millions of virtual threads each potentially holding a ThreadLocal value, a large correlation ID context object that is set but not cleared promptly causes heap pressure. I either ensure every virtual thread task calls `remove()` in a finally block, or migrate to `ScopedValue` where the scope-based cleanup is automatic.
>
> In production I monitor carrier thread count (should be low, ~core count), virtual thread count (can be in the millions), and heap pressure from stack frames. Java Flight Recorder in Java 21 has explicit virtual thread event support."

*Mentioning JFR virtual thread events shows you know the observability story — that is what a senior engineer at Goldman Sachs would ask about.*

**Gotcha follow-up they'll ask:** *"Would you use virtual threads for a CPU-bound batch job that processes 10 million records?"*

> "No. CPU-bound work parallelizes at the level of physical cores — adding more threads than cores just means more context switching with no throughput gain. For a 10-million-record batch I would use a `ForkJoinPool` with parallelism set to `availableProcessors()`, using `RecursiveTask` to split the dataset into chunks, process each chunk, and merge results. Or I would use the parallel stream API, which uses the common `ForkJoinPool` under the hood with the same work-stealing scheduler. Virtual threads would add overhead here with no benefit — they are designed to keep OS threads busy during blocking waits, not to provide more CPU parallelism."

---

> **Common Mistake — Assuming virtual threads fix CPU-bound bottlenecks:**
> Virtual threads free carrier threads only when a virtual thread is blocked waiting for I/O. A CPU-bound virtual thread occupies a carrier thread the entire time it runs. Replacing a fixed pool with `newVirtualThreadPerTaskExecutor()` on a CPU-bound workload increases context-switch overhead and can actually reduce throughput compared to a properly-sized fixed pool.

**Quick Revision (one line):** Virtual threads: JVM-managed heap-allocated threads, millions possible, unmount from carrier on I/O — for I/O-bound work only; pinning risk with synchronized+I/O (fix: ReentrantLock); create with `Executors.newVirtualThreadPerTaskExecutor()`; Java 21 GA.

---

## Topic 10: Reference Diagrams and Checklists

**Difficulty:** N/A | **Frequency:** Reference | **Companies:** All

---

### The Idea

Before an interview, two things matter most: being able to draw the thread state machine from memory when asked "walk me through the thread lifecycle," and being able to pick the right concurrency tool in under 10 seconds when given a design problem. This topic gives you both as dense reference material — the state diagram, the tool-selection guide, the deadlock checklist, and the key numbers you should be able to cite without hesitation.

These are not things to understand for the first time here. They are things to review the night before so they are at the front of your working memory when the whiteboard question starts.

### How It Works

**Thread lifecycle — six states:**

```
NEW ──── thread.start() ────► RUNNABLE
                                 │        ▲
              wait for           │        │  lock becomes available
              monitor lock       ▼        │
                              BLOCKED ────┘

                                 │        ▲
          object.wait()          │        │  notify() / notifyAll()
          thread.join()          ▼        │  join target terminates
          LockSupport.park()  WAITING ────┘  LockSupport.unpark()

                                 │        ▲
          Thread.sleep(n)        │        │  timeout / notify / interrupt
          object.wait(n)         ▼        │
          thread.join(n)    TIMED_WAITING ┘

RUNNABLE ──── run() returns ────────────► TERMINATED
         ──── uncaught exception ──────►
```

**State transition table:**

| From | To | Trigger |
|---|---|---|
| NEW | RUNNABLE | `thread.start()` |
| RUNNABLE | BLOCKED | Attempting to enter a `synchronized` block held by another thread |
| BLOCKED | RUNNABLE | Monitor lock becomes available |
| RUNNABLE | WAITING | `object.wait()`, `thread.join()`, `LockSupport.park()` |
| WAITING | RUNNABLE | `notify()`/`notifyAll()`, join target terminates, `LockSupport.unpark()` |
| RUNNABLE | TIMED_WAITING | `Thread.sleep(n)`, `object.wait(n)`, `thread.join(n)`, `parkNanos()` |
| TIMED_WAITING | RUNNABLE | Timeout expires, `notify()`, `interrupt()` |
| RUNNABLE | TERMINATED | `run()` returns or uncaught exception |

> **Note:** Java reports I/O-blocked threads as RUNNABLE — the JVM has no separate state for threads waiting on socket or disk I/O. This is why a thread dump may show many "RUNNABLE" threads that are actually idle waiting for network.

**Concurrency tool selection guide:**

| Problem | Tool | Why |
|---|---|---|
| Simple mutual exclusion | `synchronized` | JVM can optimize with biased locking and lock elision |
| Timed lock attempt | `ReentrantLock.tryLock(timeout)` | Deadlock prevention |
| Multiple condition variables | `ReentrantLock` + `Condition` | `await()` / `signal()` per condition |
| Fair access ordering | `new ReentrantLock(true)` | FIFO prevents starvation |
| Read-heavy shared data | `ReentrantReadWriteLock` | Many concurrent readers, rare writes |
| Extreme read performance | `StampedLock` (optimistic read) | No reentrancy; order books, in-memory indexes |
| Single counter / flag | `AtomicInteger` / `AtomicBoolean` | CAS semantics; sequence numbers, circuit breakers |
| High-contention counter | `LongAdder` / `LongAccumulator` | No CAS contention; request counts, byte metrics |
| Thread-safe Map | `ConcurrentHashMap` | Compound ops: `computeIfAbsent`, `putIfAbsent`, `merge` |
| Read-heavy List | `CopyOnWriteArrayList` | Snapshot-on-write; event listeners, subscriber lists |
| Producer-Consumer | `BlockingQueue` (`ArrayBlockingQueue`) | Bounded buffer; `put()` = backpressure |
| Per-thread state | `ThreadLocal<T>` | Always `remove()` in finally; request context, MDC |
| Parallel divide-and-conquer | `ForkJoinPool` / `RecursiveTask` | Work-stealing scheduler; merge sort, parallel reduce |
| I/O-bound high concurrency | Virtual Threads (Java 21) | `newVirtualThreadPerTaskExecutor()`; unmount on I/O block |

**Deadlock detection and prevention checklist:**

```
DETECT
──────────────────────────────────────────────────────────────
□ 1. jstack <pid>  OR  jcmd <pid> Thread.print
□ 2. Look for "Found one Java-level deadlock" in the dump
□ 3. Identify BLOCKED threads — what lock is each waiting for?
□ 4. Trace the cycle: T1 waits for L1 held by T2,
                      T2 waits for L2 held by T1
□ 5. Programmatic detection in tests:
     ThreadMXBean tmx = ManagementFactory.getThreadMXBean();
     long[] ids = tmx.findDeadlockedThreads();
     assert ids == null : "deadlock detected in " + Arrays.toString(ids);

ROOT CAUSE
──────────────────────────────────────────────────────────────
□ 6. Two locks acquired in different orders in different code paths?
□ 7. synchronized call inside another synchronized block?
□ 8. Callbacks or listeners invoked while holding a lock?
□ 9. DB row locking involved? (check DB deadlock logs too)

PREVENTION FIXES
──────────────────────────────────────────────────────────────
□ 10. Enforce consistent global lock order (sort by natural key)
□ 11. Replace nested synchronized with tryLock(timeout) + backoff
□ 12. Narrow synchronized scopes — minimize work inside the lock
□ 13. Never call external/unknown code while holding a lock
□ 14. Consider lock-free alternatives (ConcurrentHashMap, AtomicReference)
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"Walk me through the Java thread lifecycle states."**

**One-line answer:** Six states: NEW, RUNNABLE, BLOCKED, WAITING, TIMED_WAITING, TERMINATED — a thread progresses through them based on lock contention, wait/notify calls, sleep, and join.

**Full answer to give in an interview:**

> "A thread starts in NEW — it exists as an object but has not been scheduled. Calling `thread.start()` moves it to RUNNABLE, which means the JVM scheduler may run it. RUNNABLE does not mean it is actually executing — it may be waiting for a CPU turn.
>
> BLOCKED is specifically for lock contention: when a thread tries to enter a `synchronized` block that another thread holds, it moves to BLOCKED. It returns to RUNNABLE automatically when the lock is released — no programmer action needed.
>
> WAITING is for explicit coordination: `object.wait()`, `thread.join()`, and `LockSupport.park()` move a thread to WAITING indefinitely. It wakes only via `notify()`/`notifyAll()`, the joined thread completing, or `LockSupport.unpark()`. TIMED_WAITING is the same but with a timeout — `Thread.sleep(n)`, `object.wait(n)`, `thread.join(n)`.
>
> One interviewer trap: Java reports threads doing socket I/O as RUNNABLE. There is no separate BLOCKED-ON-IO state in the JVM — all I/O-waiting threads appear RUNNABLE in a thread dump. This is why virtual threads (Java 21) represent a scheduler-level change rather than a state-model change: the JVM internally tracks I/O completion callbacks but the state API is unchanged.
>
> TERMINATED is final — once a thread's `run()` returns or throws an uncaught exception, it cannot be restarted."

*The RUNNABLE-for-I/O point catches most candidates off guard — mention it proactively to show depth.*

**Gotcha follow-up they'll ask:** *"What is the difference between BLOCKED and WAITING?"*

> "BLOCKED means a thread is queued for a monitor lock — it is waiting for `synchronized` access and will be automatically rescheduled when the lock becomes available. WAITING means the thread has explicitly relinquished the CPU and will not run until explicitly notified — via `notify()`, a join completing, or `unpark()`. BLOCKED threads are competing for a lock passively; WAITING threads are parked and require an intentional signal to wake. You cannot interrupt a BLOCKED thread to make it stop waiting for the lock — you can interrupt a WAITING thread, which will cause `wait()` to throw `InterruptedException`."

---

#### Q2 — Tradeoff Question

**"When should you use `LongAdder` instead of `AtomicLong`?"**

**One-line answer:** Use `LongAdder` for high-contention counters where many threads increment simultaneously — it eliminates CAS contention by maintaining per-CPU-cell counters; use `AtomicLong` when you need CAS semantics (compare-and-set) or immediate consistent reads.

**Full answer to give in an interview:**

> "`AtomicLong` uses a single CAS instruction on one memory location. Under high contention — hundreds of threads all calling `incrementAndGet()` simultaneously — threads keep retrying their CAS because another thread just changed the value. This is called CAS spinning, and it degrades throughput roughly linearly with thread count.
>
> `LongAdder` solves this by maintaining an array of cells, one per CPU (it expands dynamically up to the CPU count). Each thread increments its local cell with minimal contention. The true sum is computed lazily only when you call `sum()` — which adds all cells together. This means `sum()` is not instantaneously consistent (a thread may have incremented its cell between your `sum()` start and finish), but for metrics and counters that accept approximate values, this is fine.
>
> Use `AtomicLong` when: you need `compareAndSet()` (implement a state machine, a circuit breaker); you need the exact current value to make a decision (check-then-set patterns); there is low contention. Use `LongAdder` when: you only need eventual accurate counts (request counter, byte transfer metrics, cache hit counts); contention is high (many threads updating simultaneously). `LongAccumulator` generalizes `LongAdder` to any associative, commutative operation — for example, a running maximum."

*The "CAS spinning degrades linearly" insight is the mechanism-level answer — pair it with the use-case table to show both depth and practical judgment.*

**Gotcha follow-up they'll ask:** *"What is the CPU-bound thread pool sizing formula, and why?"*

> "For CPU-bound work: `N + 1` threads, where N is `Runtime.getRuntime().availableProcessors()`. The +1 accounts for one thread occasionally being descheduled by the OS (page fault, context switch) — having one extra thread ensures the CPU is never idle due to a momentary pause. For I/O-bound work: `N × (1 + W/C)`, where W is the average wait time (I/O) and C is the average compute time. If threads spend 90% of their time waiting on I/O (W/C = 9), you need 10x CPU count threads to keep CPUs saturated. In practice, profile your actual W/C ratio rather than guessing."

---

#### Q3 — Concept Check

**"What key numbers about Java concurrency should you be able to cite in an interview?"**

**One-line answer:** Platform thread stack ~512KB, creation ~1ms; virtual thread creation ~microseconds; CAS = single CMPXCHG instruction; default ForkJoinPool parallelism = `availableProcessors() - 1`; CPU-bound pool = N+1, I/O-bound = N×(1+W/C).

**Full answer to give in an interview:**

> "A few numbers I keep in mind: platform thread stack size defaults to about 512KB on a 64-bit JVM — configurable with `-Xss`. Creating one costs roughly 1 millisecond because it requires a kernel syscall to allocate the OS thread. Virtual threads in Java 21 cost microseconds to create and use heap-allocated stacks that start small and grow as needed.
>
> At the hardware level, a CAS operation maps to a single `CMPXCHG` instruction on x86-64 — it is atomic at the hardware level without requiring OS involvement. `LongAdder` cells expand up to the CPU count to minimize CAS contention.
>
> For thread pool sizing: `ForkJoinPool`'s common pool has parallelism of `availableProcessors() - 1` by default (leaving one core for the main thread and GC). For a custom CPU-bound pool: `N + 1`. For I/O-bound: `N × (1 + W/C)` where W is wait time and C is compute time — if a thread waits 9ms per 1ms of computation, you need 10× CPU count threads to keep cores busy.
>
> `ThreadPoolExecutor` task acceptance order is worth knowing: core threads first, then the queue, then up to max threads, then the rejection handler. A common mistake is setting a large max thread count and a bounded queue, expecting max threads to kick in early — they do not until the queue is full."

*The `ThreadPoolExecutor` acceptance order is a classic interview trap — many developers assume max threads engage before the queue.*

**Gotcha follow-up they'll ask:** *"What does `availableProcessors()` return on a container with CPU limits?"*

> "It returns the number of logical CPUs the JVM sees — on a Docker container with a CPU limit, JVMs before Java 10 would return the host machine's full CPU count, causing thread pool over-provisioning. From Java 10 onwards, the JVM reads `cpu.shares` and `cpu.cfs_quota_us` from cgroup files and computes the effective CPU count correctly. On Kubernetes with a 0.5 CPU limit, Java 10+ returns 1. If you are running Java 8 in a container, either set `-XX:+UseContainerSupport` (backported in later Java 8 updates) or pass `-XX:ActiveProcessorCount=N` explicitly."

---

#### Q4 — Design Scenario

**"During a code review you see `new ReentrantLock(true)` used everywhere in a high-throughput payment service. What is your feedback?"**

**One-line answer:** Fair locking prevents starvation but significantly reduces throughput under high contention — in a high-throughput payment service, unfair locking is almost always the right default unless starvation is a proven problem.

**Full answer to give in an interview:**

> "The `true` argument to `ReentrantLock` enables fair mode — threads acquire the lock in FIFO order, so no thread is ever indefinitely skipped. That sounds appealing, but it comes with a real cost.
>
> In unfair mode, when a lock is released, the JVM can immediately grant it to a thread that just called `lock()` — no queue lookup needed. This 'barging' is fast. In fair mode, the JVM must check whether there are threads already queued, and if so, park the new thread and wake the head of the queue. That involves OS scheduling, which adds microseconds per acquisition. Under high contention this overhead compounds: throughput can drop 20–50x compared to unfair mode in benchmarks.
>
> My feedback: remove `true` unless there is a specific demonstrated starvation problem. Starvation is rare in practice because most lock hold times are short — threads cycle through quickly. If there genuinely is a starvation concern (a specific low-priority thread never getting the lock), address it with architectural changes: a dedicated thread for that work, a separate queue, or a priority-aware routing mechanism. Using fair locks system-wide as a precaution trades real throughput for a theoretical correctness benefit.
>
> The exception: `ReentrantReadWriteLock` in write-heavy scenarios. Without fairness, a continuous stream of readers can starve writers permanently. Here, fair mode for the write lock specifically may be warranted."

*The 20–50x throughput drop figure is real from JMH benchmarks — citing it shows you have actually tested this, not just read about it.*

**Gotcha follow-up they'll ask:** *"When should you use `StampedLock` over `ReentrantReadWriteLock`?"*

> "`StampedLock` offers an optimistic read mode: you call `tryOptimisticRead()` which returns a stamp without acquiring any lock. You read the data, then call `validate(stamp)` — if no write occurred between your read and validate, the stamp is still valid and you got a consistent snapshot with zero locking cost. Only on validation failure do you upgrade to a full read lock. This is ideal for read-dominated data structures where writes are very rare — an in-memory order book, a configuration cache, a routing table. The tradeoff: `StampedLock` is not reentrant (calling it again from the same thread will deadlock), does not support condition variables, and the optimistic pattern requires you to defensively re-read if validation fails. It is a low-level, high-performance tool — reach for `ReentrantReadWriteLock` first and only profile your way to `StampedLock` if read contention is a demonstrated bottleneck."

---

> **Common Mistake — Treating all RUNNABLE threads as CPU-active:**
> A thread dump showing dozens of RUNNABLE threads does not mean the CPU is saturated. Threads blocked on socket I/O appear RUNNABLE in Java's state model. Misreading this leads to unnecessarily expanding thread pools when the actual fix is reducing I/O latency or switching to virtual threads.

**Quick Revision (one line):** Six thread states: NEW → RUNNABLE → BLOCKED/WAITING/TIMED_WAITING → TERMINATED; I/O-blocked threads show as RUNNABLE in thread dumps; pick tools by problem type (synchronized → simple mutex, ReentrantLock → timed/condition, AtomicLong → CAS, LongAdder → high-contention counter, BlockingQueue → producer-consumer, virtual threads → I/O-bound scale); CPU-bound pool = N+1, I/O-bound = N×(1+W/C).

---

*End of Chapter 6: Multithreading & Concurrency*

