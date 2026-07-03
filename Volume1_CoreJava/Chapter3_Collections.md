# Volume 1: Core Java
# Chapter 3: Collections

---

## Table of Contents
1. ArrayList Internals
2. LinkedList Internals
3. ArrayList vs LinkedList
4. HashSet Internals
5. LinkedHashSet
6. TreeSet
7. HashMap Internals (Java 8+)
8. HashMap Performance
9. LinkedHashMap
10. TreeMap
11. ConcurrentHashMap
12. HashMap vs Hashtable vs ConcurrentHashMap
13. PriorityQueue
14. ArrayDeque
15. Fail-fast vs Fail-safe Iterators
16. ListIterator
17. Collections Utility Class
18. Arrays Utility Class
19. Comparable vs Comparator
20. CopyOnWriteArrayList
21. BlockingQueue
22. Master Comparison Table

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: ArrayList Internals

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Amazon, Google, Microsoft, Goldman Sachs, JPMorgan, Salesforce, Uber

---

### The Idea

Think of ArrayList like a whiteboard with numbered slots. You start with 10 blank slots. When you run out of space, you don't erase and rewrite — you get a new, bigger whiteboard (about 1.5x larger), copy everything over, and keep going. Most of the time you're just writing in the next empty slot, which is instant.

The key insight is that even though the occasional copy is expensive (O(n)), it happens so rarely that if you spread the cost across all insertions, each one averages out to O(1). This is called amortized constant time.

Underneath, it's just a plain Java `Object[]` array. There's nothing magic — the "list" part is just logic on top of an array that handles growing, shifting, and tracking how many slots are actually filled vs how many exist.

### How It Works

```
// Construction
create backing array = empty placeholder (not yet 10 slots)
size = 0

// add(element)
if size == array.length:
    newCapacity = oldCapacity + (oldCapacity / 2)   // ~1.5x growth
    newArray = copy of old array with newCapacity slots
    elementData = newArray
elementData[size] = element
size++

// get(index)
return elementData[index]   // direct slot access, O(1)

// remove(index)
shift all elements right of index one position left   // O(n)
elementData[size-1] = null
size--
```

The one real Java code block worth memorizing — the interview-critical gotcha around capacity vs size:

```java
ArrayList<String> list = new ArrayList<>();
// Backing array is NOT yet 10 slots — it's an empty placeholder.
// First add() triggers grow to exactly 10.

list.add("a");  // now capacity = 10, size = 1

// trimToSize() shrinks backing array to match size — useful before long-term caching
list.trimToSize();  // now capacity = 1

// ensureCapacity() — pre-allocate before bulk add to avoid multiple resizes
list.ensureCapacity(2000);

// clear() sets size=0 and nulls elements — does NOT reduce capacity
list.clear();  // capacity still 2000
```

**Growth formula:** `newCapacity = oldCapacity + (oldCapacity >> 1)` — the `>> 1` is a right bit-shift, equivalent to integer division by 2. Result: ~1.5x.

**Why `System.arraycopy` and not a loop?** It is a JVM intrinsic mapped to the platform's native `memcpy`. Far faster than element-by-element copying for large arrays.

| Operation | Complexity | Notes |
|---|---|---|
| `add(E)` append | O(1) amortized, O(n) worst | Resize copies all elements |
| `get(index)` | O(1) | Direct array index |
| `remove(index)` | O(n) | Shifts elements left |
| `remove(last)` | O(1) | No shift needed |
| `contains(E)` | O(n) | Linear scan |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"How does ArrayList grow when it runs out of capacity?"**

**One-line answer:** It allocates a new array at ~1.5x the old capacity and copies all elements over using `System.arraycopy`.

**Full answer to give in an interview:**
> "When `add()` is called and `size == array.length`, ArrayList calls its internal `grow()` method. It computes a new capacity as `oldCapacity + (oldCapacity >> 1)` — that right-shift is integer division by 2, so the new capacity is roughly 1.5 times the old one. It then calls `Arrays.copyOf`, which internally uses `System.arraycopy` — a JVM intrinsic backed by the platform's native `memcpy`. The copy is O(n), but because the array doubles roughly every n insertions, the total copy work across n insertions is 1+2+4+...+n/2 = n-1 operations. Spread across n insertions, that's O(1) amortized per add. The 1.5x factor (versus 2x in some languages) means slightly more frequent resizes but lower memory waste."

*Lead with the formula, then explain why amortized O(1) holds. Interviewers love it when you derive it from first principles rather than just stating it.*

**Gotcha follow-up they'll ask:** *"Is `add(E)` always O(1)?"*
> No — it's O(1) amortized but O(n) in the worst case when a resize is triggered. The distinction matters if you're adding to an ArrayList inside a tight latency-sensitive loop.

---

#### Q2 — Tradeoff Question

**"When would you pre-size an ArrayList, and what's the benefit?"**

**One-line answer:** When you know the approximate element count upfront — it eliminates all resize-and-copy operations entirely.

**Full answer to give in an interview:**
> "If I have a database query that returns a `COUNT(*)` of roughly 500 rows before I stream the actual records, I'd do `new ArrayList<>(500)`. This pre-allocates a backing array of exactly 500 slots. Every `add()` then goes directly into the next slot — no resize triggers, no `Arrays.copyOf`, no GC pressure from discarding old arrays. For large batch jobs processing 100K+ records, this can meaningfully reduce both CPU time and garbage collection pauses. The cost is just one upfront `int` calculation. If I slightly overestimate, the unused slots are just null references — cheap."

*In backend interviews, tie this to a real pattern: pre-sizing from a COUNT query, or `list.ensureCapacity(n)` before a bulk-add loop.*

**Gotcha follow-up they'll ask:** *"What does `trimToSize()` do, and when would you call it?"*
> `trimToSize()` resizes the backing array down to exactly `size`, eliminating any unused capacity. You'd call it before caching a list long-term — for example, storing a list of config values in a static field at startup. Without it, you might hold a 1500-slot array for a 1000-element list indefinitely.

---

#### Q3 — Design Scenario

**"ArrayList is not thread-safe. What are your options if multiple threads need to read and write to the same list?"**

**One-line answer:** Use `Collections.synchronizedList()` for simple locking, or `CopyOnWriteArrayList` for read-heavy workloads.

**Full answer to give in an interview:**
> "Plain ArrayList has no synchronization — concurrent modification can corrupt internal state or throw `ConcurrentModificationException`. There are two standard fixes. `Collections.synchronizedList(new ArrayList<>())` wraps every method in a `synchronized` block on the list object — all operations are serialized. This is correct but creates contention under high concurrency. `CopyOnWriteArrayList` takes a different approach: every write creates a fresh copy of the backing array, applies the change, then swaps the reference. Reads never block because they work on the existing snapshot. This is ideal for event listener registries or config caches where reads vastly outnumber writes. The cost is O(n) per write and extra GC pressure from discarded arrays. For a write-heavy concurrent list, neither is great — usually a `ConcurrentLinkedQueue` or blocking queue is the better design."

*Distinguish the two options by their read/write ratio tradeoff. This shows you're thinking about real contention patterns, not just reciting class names.*

**Gotcha follow-up they'll ask:** *"What happens if you call `clear()` on an ArrayList — does capacity drop?"*
> No. `clear()` sets all element references to `null` and resets `size` to 0, but the backing array retains its current length. Capacity is unchanged. Call `trimToSize()` afterward if you want to reclaim that memory.

---

> **Common Mistake — Confusing size and capacity:** Many candidates say "ArrayList starts with size 10." It starts with *capacity* 10 (the array length) and *size* 0 (the element count). Mixing these up in an interview signals a shallow understanding of the internals.

**Quick Revision (one line):** ArrayList is an `Object[]` that grows ~1.5x on overflow; `add` is O(1) amortized, `get` is O(1), `remove(index)` is O(n) due to shifting.

---

## Topic 2: LinkedList Internals

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Adobe, Flipkart, Paytm, Morgan Stanley

<svg viewBox="0 0 760 300" xmlns="http://www.w3.org/2000/svg" font-family="'Segoe UI', system-ui, sans-serif" style="width:100%; max-width:760px; display:block; margin:16px 0;">
  <defs>
    <style>
      #ptr-group { opacity: 0; animation: ptrAnim 9s linear infinite; }
      @keyframes ptrAnim {
        0%,   16%  { opacity: 0; transform: translateX(0px);   }
        17%        { opacity: 1; transform: translateX(0px);   }
        25%        { opacity: 1; transform: translateX(0px);   }
        30%        { opacity: 1; transform: translateX(140px);  }
        38%        { opacity: 1; transform: translateX(140px);  }
        43%        { opacity: 1; transform: translateX(280px);  }
        51%        { opacity: 1; transform: translateX(280px);  }
        56%        { opacity: 1; transform: translateX(420px);  }
        63%        { opacity: 1; transform: translateX(420px);  }
        66%        { opacity: 0; transform: translateX(420px);  }
        100%       { opacity: 0; transform: translateX(0px);   }
      }
      #insert-node { opacity: 0; animation: insertAnim 9s linear infinite; }
      @keyframes insertAnim {
        0%,  33%  { opacity: 0; transform: translateY(-40px); }
        38%        { opacity: 1; transform: translateY(0px);   }
        88%        { opacity: 1; transform: translateY(0px);   }
        94%        { opacity: 0; transform: translateY(0px);   }
        100%       { opacity: 0; transform: translateY(-40px); }
      }
      #arrow-be { opacity: 0; animation: arrowBE 9s linear infinite; }
      @keyframes arrowBE {
        0%,  37%  { opacity: 0; }
        40%        { opacity: 1; }
        88%        { opacity: 1; }
        94%        { opacity: 0; }
        100%       { opacity: 0; }
      }
      #arrow-ec { opacity: 0; animation: arrowEC 9s linear infinite; }
      @keyframes arrowEC {
        0%,  37%  { opacity: 0; }
        40%        { opacity: 1; }
        66%        { opacity: 1; }
        72%        { opacity: 0; }
        100%       { opacity: 0; }
      }
      #arrow-bc-orig { animation: arrowBCorig 9s linear infinite; }
      @keyframes arrowBCorig {
        0%,  38%  { opacity: 1; }
        40%        { opacity: 0; }
        100%       { opacity: 0; }
      }
      #delete-node-c { animation: deleteC 9s linear infinite; }
      @keyframes deleteC {
        0%,  66%  { opacity: 1; }
        72%        { opacity: 0; }
        100%       { opacity: 0; }
      }
      #delete-label { opacity: 0; animation: deleteLbl 9s linear infinite; }
      @keyframes deleteLbl {
        0%,  66%  { opacity: 0; }
        68%        { opacity: 1; }
        72%        { opacity: 0; }
        100%       { opacity: 0; }
      }
      #arrow-ed { opacity: 0; animation: arrowED 9s linear infinite; }
      @keyframes arrowED {
        0%,  71%  { opacity: 0; }
        73%        { opacity: 1; }
        94%        { opacity: 1; }
        96%        { opacity: 0; }
        100%       { opacity: 0; }
      }
      #lbl-traverse { opacity: 0; animation: lblT 9s linear infinite; }
      @keyframes lblT {
        0%,  15%  { opacity: 0; }
        17%        { opacity: 1; }
        32%        { opacity: 1; }
        34%        { opacity: 0; }
        100%       { opacity: 0; }
      }
      #lbl-insert { opacity: 0; animation: lblI 9s linear infinite; }
      @keyframes lblI {
        0%,  33%  { opacity: 0; }
        35%        { opacity: 1; }
        64%        { opacity: 1; }
        66%        { opacity: 0; }
        100%       { opacity: 0; }
      }
      #lbl-delete { opacity: 0; animation: lblD 9s linear infinite; }
      @keyframes lblD {
        0%,  64%  { opacity: 0; }
        66%        { opacity: 1; }
        88%        { opacity: 1; }
        90%        { opacity: 0; }
        100%       { opacity: 0; }
      }
      #head-label { animation: headPulse 9s linear infinite; }
      @keyframes headPulse {
        0%,100% { fill: #6366f1; }
        17%,32% { fill: #4f46e5; }
      }
    </style>
    <marker id="arr" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#6366f1"/>
    </marker>
    <marker id="arr-green" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#10b981"/>
    </marker>
    <marker id="arr-ptr" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#f59e0b"/>
    </marker>
  </defs>

  <rect width="760" height="300" fill="#f8fafc" rx="10"/>
  <text x="380" y="28" text-anchor="middle" fill="#1e293b" font-size="14" font-weight="700">Singly Linked List — Traverse, Insert, Delete</text>

  <text id="head-label" x="100" y="82" text-anchor="middle" fill="#6366f1" font-size="11" font-weight="700">HEAD</text>
  <line x1="100" y1="86" x2="100" y2="100" stroke="#6366f1" stroke-width="1.5" marker-end="url(#arr)"/>

  <!-- Node A -->
  <rect x="60" y="100" width="50" height="40" fill="#f1f5f9" stroke="#6366f1" stroke-width="2" rx="6"/>
  <rect x="110" y="100" width="30" height="40" fill="#e0e7ff" stroke="#6366f1" stroke-width="1.5"/>
  <text x="85" y="125" text-anchor="middle" fill="#1e293b" font-size="14" font-weight="700">A</text>
  <text x="125" y="118" text-anchor="middle" fill="#64748b" font-size="8">next</text>

  <line x1="140" y1="120" x2="198" y2="120" stroke="#6366f1" stroke-width="2" marker-end="url(#arr)"/>

  <!-- Node B -->
  <rect x="200" y="100" width="50" height="40" fill="#f1f5f9" stroke="#6366f1" stroke-width="2" rx="6"/>
  <rect x="250" y="100" width="30" height="40" fill="#e0e7ff" stroke="#6366f1" stroke-width="1.5"/>
  <text x="225" y="125" text-anchor="middle" fill="#1e293b" font-size="14" font-weight="700">B</text>
  <text x="265" y="118" text-anchor="middle" fill="#64748b" font-size="8">next</text>

  <line id="arrow-bc-orig" x1="280" y1="120" x2="338" y2="120" stroke="#6366f1" stroke-width="2" marker-end="url(#arr)"/>

  <!-- Node C (deletable) -->
  <g id="delete-node-c">
    <rect x="340" y="100" width="50" height="40" fill="#f1f5f9" stroke="#6366f1" stroke-width="2" rx="6"/>
    <rect x="390" y="100" width="30" height="40" fill="#e0e7ff" stroke="#6366f1" stroke-width="1.5"/>
    <text x="365" y="125" text-anchor="middle" fill="#1e293b" font-size="14" font-weight="700">C</text>
    <text x="405" y="118" text-anchor="middle" fill="#64748b" font-size="8">next</text>
    <line x1="420" y1="120" x2="478" y2="120" stroke="#6366f1" stroke-width="2" marker-end="url(#arr)"/>
  </g>

  <!-- Delete X over C -->
  <g id="delete-label">
    <line x1="335" y1="98" x2="425" y2="148" stroke="#ef4444" stroke-width="2.5"/>
    <line x1="425" y1="98" x2="335" y2="148" stroke="#ef4444" stroke-width="2.5"/>
    <rect x="336" y="88" width="66" height="18" fill="#fef2f2" stroke="#ef4444" stroke-width="1" rx="3"/>
    <text x="369" y="101" text-anchor="middle" fill="#ef4444" font-size="9" font-weight="700">DELETE</text>
  </g>

  <!-- Node D -->
  <rect x="480" y="100" width="50" height="40" fill="#f1f5f9" stroke="#6366f1" stroke-width="2" rx="6"/>
  <rect x="530" y="100" width="30" height="40" fill="#e0e7ff" stroke="#6366f1" stroke-width="1.5"/>
  <text x="505" y="125" text-anchor="middle" fill="#1e293b" font-size="14" font-weight="700">D</text>
  <text x="545" y="118" text-anchor="middle" fill="#64748b" font-size="8">next</text>

  <line x1="560" y1="120" x2="608" y2="120" stroke="#6366f1" stroke-width="2" marker-end="url(#arr)"/>
  <rect x="610" y="108" width="36" height="24" fill="#f1f5f9" stroke="#94a3b8" stroke-width="1.5" rx="4"/>
  <text x="628" y="124" text-anchor="middle" fill="#94a3b8" font-size="10" font-weight="600">null</text>

  <!-- Traverse pointer -->
  <g id="ptr-group">
    <line x1="100" y1="155" x2="100" y2="146" stroke="#f59e0b" stroke-width="2" marker-end="url(#arr-ptr)"/>
    <rect x="72" y="158" width="56" height="20" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5" rx="4"/>
    <text x="100" y="172" text-anchor="middle" fill="#92400e" font-size="10" font-weight="700">curr</text>
  </g>

  <!-- Insert node E -->
  <g id="insert-node">
    <rect x="280" y="40" width="50" height="40" fill="#d1fae5" stroke="#10b981" stroke-width="2" rx="6"/>
    <rect x="330" y="40" width="30" height="40" fill="#a7f3d0" stroke="#10b981" stroke-width="1.5"/>
    <text x="305" y="65" text-anchor="middle" fill="#065f46" font-size="14" font-weight="700">E</text>
    <text x="345" y="58" text-anchor="middle" fill="#065f46" font-size="8">next</text>
    <rect x="268" y="30" width="72" height="16" fill="#ecfdf5" stroke="#10b981" stroke-width="1" rx="3"/>
    <text x="304" y="42" text-anchor="middle" fill="#065f46" font-size="9" font-weight="700">INSERT</text>
  </g>

  <path id="arrow-be" d="M 265 108 Q 265 60 278 60" fill="none" stroke="#10b981" stroke-width="2" stroke-dasharray="5,3" marker-end="url(#arr-green)"/>
  <path id="arrow-ec" d="M 360 80 Q 360 100 358 100" fill="none" stroke="#10b981" stroke-width="2" stroke-dasharray="5,3" marker-end="url(#arr-green)"/>
  <path id="arrow-ed" d="M 360 80 Q 470 60 490 100" fill="none" stroke="#10b981" stroke-width="2" stroke-dasharray="5,3" marker-end="url(#arr-green)"/>

  <!-- Step label bar -->
  <rect x="40" y="262" width="680" height="28" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1" rx="6"/>
  <text id="lbl-traverse" x="380" y="280" text-anchor="middle" fill="#4f46e5" font-size="11" font-weight="600">Traversal: follow next pointers from HEAD until null  —  O(n)</text>
  <text id="lbl-insert" x="380" y="280" text-anchor="middle" fill="#065f46" font-size="11" font-weight="600">Insert E after B: B.next = E, E.next = C  —  O(1) pointer rewire</text>
  <text id="lbl-delete" x="380" y="280" text-anchor="middle" fill="#ef4444" font-size="11" font-weight="600">Delete C: E.next = D  —  O(1) once predecessor found</text>

  <!-- Legend -->
  <g transform="translate(50,240)">
    <rect x="0" y="-10" width="14" height="14" fill="#f1f5f9" stroke="#6366f1" stroke-width="1.5" rx="2"/>
    <text x="18" y="2" fill="#64748b" font-size="9">Data node</text>
    <rect x="110" y="-10" width="14" height="14" fill="#d1fae5" stroke="#10b981" stroke-width="1.5" rx="2"/>
    <text x="128" y="2" fill="#64748b" font-size="9">Inserted node</text>
    <rect x="240" y="-10" width="14" height="14" fill="#e0e7ff" stroke="#6366f1" stroke-width="1.5" rx="2"/>
    <text x="258" y="2" fill="#64748b" font-size="9">next pointer cell</text>
    <rect x="390" y="-10" width="14" height="14" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5" rx="2"/>
    <text x="408" y="2" fill="#64748b" font-size="9">curr (traverse)</text>
  </g>
</svg>

---

### The Idea

Imagine a treasure hunt where each clue card holds the answer and two arrows — one pointing to the previous card, one to the next. That's a doubly linked list. You don't have a single contiguous block of memory; instead, each element lives in its own `Node` object scattered across the heap, and nodes know their neighbors by reference.

The trade-off is fundamental: because nodes are linked by pointers, you can add or remove at either end in O(1) — just update two arrows. But to reach the 500th element, you have to follow 500 arrows from the beginning (or 500 from the end). There's no shortcut.

Java's `LinkedList` does double duty — it implements both `List` and `Deque`, so it can act as a list, a stack, or a queue. But in modern Java, `ArrayDeque` beats it for pure queue/stack use because contiguous memory is far more cache-friendly than scattered node objects.

### How It Works

```
// Node structure
Node {
    item    // the stored element
    next    // reference to next node (null if tail)
    prev    // reference to previous node (null if head)
}

// LinkedList fields
first = null    // head pointer
last  = null    // tail pointer
size  = 0

// addLast(element)   O(1)
newNode = Node(prev=last, item=element, next=null)
if last != null: last.next = newNode
last = newNode
if first == null: first = newNode
size++

// get(index)   O(n)
if index < size/2:
    walk forward from first, index steps
else:
    walk backward from last, (size-1-index) steps
return node.item
```

The one Java code block that catches interviewers' attention — the O(n) trap in the middle-insert claim:

```java
LinkedList<String> list = new LinkedList<>();

// O(1) at ends — just pointer updates
list.addFirst("head");
list.addLast("tail");

// O(n) in middle — finding the position costs O(n), then O(1) to link
list.add(1, "middle");  // NOT O(1) overall

// Deque interface — the correct way to use LinkedList as a queue/stack
Deque<String> deque = new LinkedList<>();
deque.push("A");   // addFirst — stack push
deque.pop();       // removeFirst — stack pop
deque.offer("B");  // addLast — queue enqueue
deque.poll();      // removeFirst — queue dequeue
```

**Per-node memory overhead:** Each `Node` object on a 64-bit JVM costs approximately 32 bytes: 16-byte object header + 3 references × 8 bytes each (item, next, prev). For 1 million integers, LinkedList uses ~5x more memory than ArrayList.

| Operation | Complexity | Notes |
|---|---|---|
| `addFirst` / `addLast` | O(1) | Pointer update only |
| `removeFirst` / `removeLast` | O(1) | Pointer update only |
| `get(index)` | O(n) | Traverses from nearer end |
| `add(index, E)` | O(n) | Finding position is O(n) |
| `remove(Object)` | O(n) | Must search by equality |
| Memory per element | ~32 bytes overhead | vs ~4–8 bytes for ArrayList |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"Why is `get(index)` O(n) in LinkedList?"**

**One-line answer:** Because elements aren't stored contiguously — to reach index i, you must follow i pointer hops from the head (or size-1-i hops from the tail).

**Full answer to give in an interview:**
> "In an ArrayList, the backing array is contiguous memory. Index i maps directly to `elementData[i]` — one CPU instruction. In LinkedList, each element lives in its own `Node` object at an arbitrary heap address. To get index i, the JVM starts at `first` (the head) and follows `node.next` i times, or starts at `last` (the tail) and follows `node.prev` (size-1-i) times — whichever is shorter. Even with that bidirectional optimization, worst case is still n/2 hops, which is O(n). There's no concept of 'jump to slot i' because there are no slots — only chains of pointers."

*The memory model explanation (contiguous vs scattered heap) is what distinguishes a strong answer from a shallow one.*

**Gotcha follow-up they'll ask:** *"So is inserting in the middle of a LinkedList O(1)?"*
> Only the pointer adjustment is O(1). Finding the insertion position by index first requires O(n) traversal. The total cost of `list.add(index, element)` is O(n). This is a classic interview trap — candidates who say "LinkedList insertions are O(1)" are only half right.

---

#### Q2 — Tradeoff Question

**"When would you choose LinkedList over ArrayDeque as a queue?"**

**One-line answer:** Almost never in modern Java — ArrayDeque is faster for queues; LinkedList's only advantage is when you also need the `List` interface alongside `Deque`.

**Full answer to give in an interview:**
> "Both LinkedList and ArrayDeque offer O(1) `offer()` and `poll()`. But ArrayDeque stores elements in a circular array — contiguous memory — so CPU cache lines load multiple elements at once. LinkedList nodes are scattered across the heap; every poll follows a pointer to a random heap address, almost guaranteed to be a cache miss. Under benchmark conditions, ArrayDeque is typically 2–4x faster for pure queue workloads. The only time I'd pick LinkedList is if I need to treat the same collection as both a List (index access, `ListIterator`) and a Deque simultaneously — that dual interface is LinkedList's niche. For anything else, ArrayDeque wins."

*Name the cache-miss reason explicitly — it shows you understand hardware, not just Big-O.*

**Gotcha follow-up they'll ask:** *"What's the memory overhead of LinkedList versus ArrayList for the same data?"*
> Each LinkedList node carries ~32 bytes of overhead beyond the element itself (object header + prev/next/item references). ArrayList stores elements directly in a primitive array — just 4–8 bytes per reference slot, no per-element object. For 1 million integers, LinkedList uses roughly 5x more memory than ArrayList.

---

#### Q3 — Design Scenario

**"Design an in-memory undo/redo system. Would you use LinkedList, ArrayDeque, or something else?"**

**One-line answer:** Two `ArrayDeque` stacks — one for undo, one for redo — are the standard choice.

**Full answer to give in an interview:**
> "I'd use two `ArrayDeque<Command>` instances: an undo stack and a redo stack. When the user performs an action, I push a `Command` object onto the undo stack and clear the redo stack. When the user undoes, I pop from undo, reverse the action, and push the command onto redo. Redo pops from redo and pushes back onto undo. All operations are O(1) stack pushes and pops. I'd pick ArrayDeque over LinkedList for the same reason as queues — contiguous memory, better cache performance, no per-node heap overhead. I'd pick ArrayDeque over a raw ArrayList because `push()` and `pop()` semantics are explicit and intent-revealing. LinkedList would also be functionally correct here, but it's the slower choice without any compensating benefit."

*Framing this as a Command pattern plus two stacks shows design thinking beyond just the data structure question.*

**Gotcha follow-up they'll ask:** *"Is LinkedList thread-safe?"*
> No. Like ArrayList, LinkedList has no internal synchronization. Concurrent access from multiple threads can corrupt the node pointers. For a thread-safe linked queue, use `ConcurrentLinkedQueue` from `java.util.concurrent`.

---

> **Common Mistake — "Middle insert is O(1)":** Candidates often claim LinkedList's middle insertion is O(1). The pointer adjustment is O(1), but locating the insertion index requires O(n) traversal. The total operation is O(n) — same as ArrayList's shift. Neither wins on middle inserts.

**Quick Revision (one line):** LinkedList is a doubly linked list with O(1) head/tail ops and O(n) random access; each node adds ~32 bytes overhead; prefer ArrayDeque for queues.

---

## Topic 3: ArrayList vs LinkedList

**Difficulty:** Easy | **Frequency:** Very High | **Companies:** Almost every Java interview

---

### The Idea

ArrayList is a numbered row of seats in a stadium — you can jump straight to seat 42 without passing seats 1 through 41. The seats are physically next to each other, so your CPU's cache loads a whole row at once. LinkedList is a scavenger hunt — each clue tells you where the next one is, so you must follow every arrow in sequence. Stadium seating wins for almost everything a backend engineer actually does.

The comparison sounds like a simple Big-O table, but the real story is cache locality. Modern CPUs are orders of magnitude faster than RAM. ArrayList's contiguous layout means the hardware prefetcher can load upcoming elements into L1/L2 cache automatically. LinkedList's heap-scattered nodes cause cache misses on nearly every access — and a cache miss costs ~100ns, roughly the same as a local network hop.

In practice, the only time LinkedList wins is when you need O(1) insert/remove at both ends AND you need the `List` interface (index-based access, `ListIterator`) on the same collection. For pure queue/stack work, ArrayDeque is better than both.

### How It Works

**Comparison table — what actually matters in interviews:**

| Operation | ArrayList | LinkedList |
|---|---|---|
| `get(index)` | O(1) | O(n) |
| `add(E)` (append) | O(1) amortized | O(1) |
| `add(0, E)` (prepend) | O(n) — shifts all | O(1) — pointer update |
| `add(i, E)` (middle) | O(n) — shift right half | O(n) find + O(1) link |
| `remove(index)` | O(n) — shift | O(n) find + O(1) unlink |
| `remove(head)` | O(n) — shifts all | O(1) |
| `remove(tail)` | O(1) | O(1) |
| Memory (1M ints) | ~4 MB | ~20 MB |
| Cache performance | Excellent (contiguous) | Poor (scattered heap) |
| Iterator speed | Fast | Moderate |

**Real-world scenario guide:**

| Use case | Best choice | Reason |
|---|---|---|
| REST API result set | ArrayList | Random access, iteration |
| Pagination buffer | ArrayList | Pre-size from COUNT(*) |
| Event listener list | CopyOnWriteArrayList | Thread-safe, read-heavy |
| Task queue / stack | ArrayDeque | O(1) push/pop, cache-friendly |
| Undo/redo history | ArrayDeque | Two-stack pattern |
| Bidirectional iteration with inserts | LinkedList | ListIterator insert is O(1) at cursor |

The interview-critical Java snippet — measuring the real performance gap:

```java
List<Integer> arrayList  = new ArrayList<>(100_000);
List<Integer> linkedList = new LinkedList<>();
for (int i = 0; i < 100_000; i++) { arrayList.add(i); linkedList.add(i); }

// ArrayList random access: ~1–2 ms for 100K gets (cache hits)
// LinkedList random access: ~10–30 s for 100K gets (O(n) each = O(n²) total + cache misses)
for (int i = 0; i < 100_000; i++) linkedList.get(i);  // NEVER do this
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"Why is ArrayList usually faster than LinkedList even for insertions in the middle?"**

**One-line answer:** Because `System.arraycopy` is a native JVM intrinsic that exploits cache locality, while LinkedList's node-pointer traversal generates cache misses on every hop.

**Full answer to give in an interview:**
> "The Big-O table makes them look equal for middle insertion — both are O(n). But real-world performance is very different. ArrayList's `add(index, E)` calls `System.arraycopy` to shift elements right. This is a bulk memory operation mapped to the CPU's native `memcpy` instruction, which moves cache lines in bulk and benefits from hardware prefetching. LinkedList's `add(index, E)` first traverses i pointers to find the position — each `node.next` dereference jumps to a random heap address, causing an L1/L2 cache miss roughly every hop. A cache miss costs ~100ns on modern hardware. For 50K-element lists, ArrayListmodification tends to be faster in practice despite the identical Big-O, because cache misses dominate the LinkedList traversal cost."

*The cache miss argument is what separates a strong candidate from one who just memorized the table.*

**Gotcha follow-up they'll ask:** *"In what scenario would LinkedList actually beat ArrayList?"*
> When you need repeated O(1) add/remove at the head of a large list and you're using an iterator (not index-based access). Specifically: if you hold a `ListIterator` positioned at an element, `iterator.remove()` and `iterator.add()` are O(1) for LinkedList. For ArrayList, they're still O(n) due to the shift. This is a niche pattern but it's the honest answer.

---

#### Q2 — Tradeoff Question

**"A colleague proposes using LinkedList as a queue in a high-throughput message processor. What's your response?"**

**One-line answer:** Recommend ArrayDeque instead — same O(1) enqueue/dequeue, but far better cache performance and no per-element heap allocation.

**Full answer to give in an interview:**
> "I'd redirect to ArrayDeque. For a queue you only need O(1) `offer()` at the tail and `poll()` at the head — both LinkedList and ArrayDeque deliver that. But the implementation matters at high throughput. ArrayDeque stores elements in a circular resizable array. When you poll an element, the next element is already in the same cache line — the hardware prefetcher likely loaded it already. LinkedList allocates a new `Node` object on the heap for every enqueued message. Each Node is 32+ bytes of overhead, each node lives at a random heap address, and each poll dereferences a pointer to a new cache line. Under high message rates, this generates significant GC pressure from discarded Node objects and causes frequent cache misses. ArrayDeque is typically 2–4x faster in benchmarks. The only reason to pick LinkedList for a queue is if you also need List semantics on the same object — which is rare."

*Quantify the overhead: "32 bytes per node", "GC pressure from short-lived objects". This signals operational awareness.*

**Gotcha follow-up they'll ask:** *"What's the difference between `offer()` and `add()` on a queue?"*
> Both enqueue an element at the tail. `add()` throws `IllegalStateException` if the queue has a capacity bound and is full. `offer()` returns `false` instead of throwing. For unbounded queues like ArrayDeque or LinkedList, they behave identically. The distinction matters for bounded queues like `ArrayBlockingQueue`.

---

#### Q3 — Design Scenario

**"You're building a pagination service. Each page fetch builds a list of 50 DTOs from a database cursor. Which List implementation do you use and why?"**

**One-line answer:** `ArrayList` pre-sized to the page size — sequential appends are O(1) amortized, random access by index is O(1) for serialization, and memory is minimal.

**Full answer to give in an interview:**
> "I'd use `new ArrayList<>(pageSize)`, where `pageSize` is the configured page limit (e.g., 50). Pre-sizing with the exact count means the backing array is allocated once at construction — no resize, no `Arrays.copyOf`, no GC churn per request. As I stream rows from the database cursor, each `list.add(dto)` goes directly into the next array slot — O(1) every time. After building the list, serializing to JSON typically iterates the list sequentially — ArrayList's contiguous layout means the CPU cache loads multiple DTOs per cache line, which is faster than following LinkedList node pointers. I'd never use LinkedList here: no head/tail insertions, no need for Deque semantics, and the per-node memory overhead would add up under high request volume. If the page size is unknown, I might use `new ArrayList<>(50)` as a reasonable default and accept at most one resize."

*The pre-sizing point always lands well — it shows you think about allocation, not just correctness.*

**Gotcha follow-up they'll ask:** *"What if you need thread safety on this list?"*
> For a single-request scope (local variable in a controller method), no synchronization is needed — the list never escapes the thread. If it were shared across threads (e.g., a cached response), I'd use `Collections.unmodifiableList()` to make it read-only after construction, or `CopyOnWriteArrayList` if writes are also needed. I'd avoid `Collections.synchronizedList()` unless the synchronized block scope can be tightly controlled, because it requires manual locking around iteration anyway.

---

> **Common Mistake — "LinkedList is better for frequent insertions":** This is only true at the head/tail, or when you already hold an iterator at the insertion point. For index-based middle insertions, both are O(n). For all practical backend list-building workloads, ArrayList with pre-sizing wins on both speed and memory.

**Quick Revision (one line):** ArrayList wins almost every real workload — O(1) get, contiguous memory, cache-friendly; use LinkedList only when you need simultaneous List + Deque semantics on one object.

---

## Topic 4: HashSet Internals

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Walmart Labs, Razorpay

---

### The Idea

HashSet is not a standalone data structure — it's a thin wrapper around a HashMap. Every element you add becomes a key in a hidden `HashMap<E, Object>`, mapped to a shared dummy sentinel value called `PRESENT`. That's it. Every `add`, `remove`, and `contains` operation is just a HashMap key operation in disguise.

This means all of HashMap's rules apply: elements need correct `hashCode()` and `equals()` to work properly, collisions are handled by chaining (and tree-ification for long chains in Java 8+), and there is absolutely no guaranteed iteration order. The iteration order you observe today may differ after adding one more element, after a JVM restart, or between Java versions.

The design is deliberately parasitic. Sun engineers didn't want to duplicate HashMap's collision resolution, load factor logic, and resize behavior. By delegating everything to HashMap, HashSet gets all of that for free, and the maintenance burden is zero.

### How It Works

```
// Internal state
map = new HashMap<E, Object>()
PRESENT = new Object()   // shared dummy value, never changes

// add(element)
previous = map.put(element, PRESENT)
return previous == null    // null means key was new → add succeeded
                           // PRESENT means key existed → duplicate, add returns false

// contains(element)
return map.containsKey(element)

// remove(element)
return map.remove(element) == PRESENT

// Null handling
null is a valid key in HashMap (stored at bucket 0)
→ HashSet allows exactly one null element
```

The single Java code block every interviewer expects you to know:

```java
Set<String> set = new HashSet<>();

// add() returns boolean — false means duplicate
System.out.println(set.add("apple"));   // true
System.out.println(set.add("apple"));   // false — already present

// Null is allowed — stored once
set.add(null);
System.out.println(set.contains(null)); // true
set.add(null);                          // no-op, still one null

// Pre-size to avoid rehashing: HashMap default load factor = 0.75
// Rehash triggers at size > capacity * loadFactor
// To hold n elements without rehash: initialCapacity = (int)(n / 0.75) + 1
int n = 1000;
Set<String> preSized = new HashSet<>((int)(n / 0.75) + 1);
```

**Why `hashCode()` and `equals()` matter:** HashMap computes `bucket = hashCode() % capacity` to find the bucket, then uses `equals()` to find the exact key within that bucket. If two logically equal objects return different `hashCode()` values, they land in different buckets and HashSet treats them as distinct — duplicates slip through.

| Property | Value |
|---|---|
| Backed by | `HashMap<E, Object>` |
| Dummy value | `PRESENT = new Object()` |
| `add` / `remove` / `contains` | O(1) average, O(log n) worst (Java 8+ treeified chains) |
| Ordering | None guaranteed |
| Nulls | Exactly one allowed |
| Not thread-safe | Use `Collections.synchronizedSet()` or `ConcurrentHashMap.newKeySet()` |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"How does HashSet prevent duplicate elements?"**

**One-line answer:** It delegates to `HashMap.put()` — if the key already exists, `put` returns the previous value (non-null), and `add()` returns false without changing anything.

**Full answer to give in an interview:**
> "HashSet internally holds a `HashMap<E, Object>`. When you call `set.add(e)`, it calls `map.put(e, PRESENT)` where `PRESENT` is a static shared `Object` sentinel. `HashMap.put` returns the previous value for that key, or null if the key was new. If `put` returns null, the element was genuinely new — `add()` returns true. If `put` returns `PRESENT` (non-null), the key already existed — HashMap updated the value to the same `PRESENT` object and returned the old one. `add()` returns false. No exception, no corruption — the duplicate is silently ignored. This mechanism relies on the element's `hashCode()` to find the right bucket and `equals()` to confirm the match within the bucket. If either is broken on a custom object, the duplicate check fails."

*The return-value-of-put explanation is the crux. Many candidates say "HashMap handles duplicates" without explaining the mechanism.*

**Gotcha follow-up they'll ask:** *"What happens if you put a mutable object into a HashSet and then mutate it?"*
> The object's `hashCode()` changes after mutation, so it now hashes to a different bucket. HashSet can no longer find it — `contains()` returns false, and `remove()` fails. The object becomes a ghost in the set: it's there, you can see it during iteration, but the set thinks it doesn't exist. Always use immutable objects (or at least objects with stable `hashCode`) as HashSet elements.

---

#### Q2 — Tradeoff Question

**"HashSet vs TreeSet — when would you choose each?"**

**One-line answer:** HashSet for O(1) lookup with no ordering; TreeSet for sorted iteration or range queries, at the cost of O(log n) operations.

**Full answer to give in an interview:**
> "HashSet gives O(1) average for add, remove, and contains — backed by HashMap's hash table. But iteration order is effectively random and changes as the set grows. TreeSet stores elements in a self-balancing Red-Black tree, so iteration is always in natural (or comparator-defined) sorted order, and operations like `headSet()`, `tailSet()`, and `subSet()` let you retrieve ranges efficiently. The cost is O(log n) for every operation instead of O(1). In a backend context: I'd use HashSet for deduplication, idempotency key lookups, or membership checks where ordering is irrelevant. I'd use TreeSet when I need to iterate in sorted order — say, returning unique tags alphabetically — or when I need range queries like 'all user IDs between 1000 and 2000'. For insertion-order preservation without sorting, LinkedHashSet is the middle ground."

*Name all three Set types and their use cases in one answer — it signals you know the whole Set hierarchy.*

**Gotcha follow-up they'll ask:** *"Can TreeSet contain null?"*
> No. TreeSet uses `compareTo()` to place elements. Calling `compareTo(null)` throws `NullPointerException`. HashSet and LinkedHashSet allow one null (stored at bucket 0 of their backing HashMap). TreeSet explicitly disallows null unless you provide a custom `Comparator` that handles null — even then, only one null can exist since it's a Set.

---

#### Q3 — Design Scenario

**"You're building an idempotency layer for a payment API. Processed request IDs must be tracked to reject duplicates. What data structure and why?"**

**One-line answer:** A `HashSet<String>` (or `ConcurrentHashMap.newKeySet()` for thread safety) — O(1) lookup per request, no ordering needed.

**Full answer to give in an interview:**
> "The core operation is `if (processedIds.contains(requestId))` — run it on every incoming request before processing. This needs O(1) average lookup, which HashSet provides. No ordering is required: I don't care which IDs came first, just whether an ID is in the set. I'd pre-size the set based on expected request volume — `new HashSet<>((int)(expectedSize / 0.75) + 1)` — to avoid rehashing under load. For thread safety in a multi-threaded server, I'd use `ConcurrentHashMap.newKeySet()` instead of plain HashSet, which gives non-blocking concurrent reads and stripe-locked writes. If the set needs to survive process restarts, I'd back it with Redis using `SETNX` or a Bloom filter for memory-efficient probabilistic deduplication. But for an in-memory single-JVM layer, HashSet is the right tool."

*Mentioning thread-safety and the ConcurrentHashMap.newKeySet() alternative shows production awareness.*

**Gotcha follow-up they'll ask:** *"What's the worst-case time complexity of `contains()` on a HashSet?"*
> O(n) in theory if all keys hash to the same bucket — a hash collision attack. In Java 8+, when a bucket's chain exceeds 8 entries, HashMap converts it to a Red-Black tree, reducing worst-case lookup in that bucket to O(log n). So the practical worst case is O(log n), not O(n), for Java 8+.

---

> **Common Mistake — Forgetting hashCode/equals:** Candidates describe HashSet correctly but forget to mention that custom objects must override both `hashCode()` and `equals()`. Without this, two logically equal objects land in different buckets and both get stored — HashSet's duplicate prevention silently fails.

**Quick Revision (one line):** HashSet wraps a HashMap; `add` delegates to `map.put`, returning false on duplicates; O(1) average ops; requires correct `hashCode()` + `equals()`; no ordering, one null allowed.

---

## Topic 5: LinkedHashSet

**Difficulty:** Easy | **Frequency:** Medium | **Companies:** Adobe, Infosys, Capgemini, mid-tier SaaS

---

### The Idea

LinkedHashSet answers a specific complaint about HashSet: "I love the O(1) lookup, but I need to iterate in the order I inserted elements." LinkedHashSet does exactly that — it's HashSet with a memory of insertion order.

Internally, it swaps the backing store from `HashMap` to `LinkedHashMap`. LinkedHashMap adds a doubly linked list that runs through all map entries in insertion order, alongside the normal hash table structure. Every `add` appends to this list; every `remove` unlinks from it. The hash table still handles O(1) lookup. The linked list handles ordered iteration.

The cost is two extra references per entry (`before` and `after` pointers in the doubly linked list) — slightly more memory than HashSet, but the same O(1) asymptotic complexity for all operations.

### How It Works

```
// LinkedHashSet construction — key detail is the 'true' flag
HashSet(int capacity, float loadFactor, boolean dummy):
    if dummy == true:
        map = new LinkedHashMap(capacity, loadFactor)
    else:
        map = new HashMap(capacity, loadFactor)

// LinkedHashSet calls: super(capacity, loadFactor, true)
// → backing map is always a LinkedHashMap

// add(element) — same as HashSet
map.put(element, PRESENT)
// LinkedHashMap additionally appends element to its internal doubly linked list

// Iteration — walks the doubly linked list in insertion order
for each entry in linkedList order:
    yield entry.key
```

The Java code block that makes the ordering guarantee concrete:

```java
Set<String> set = new LinkedHashSet<>();

set.add("banana");
set.add("apple");
set.add("cherry");
set.add("apple");   // duplicate — ignored, position NOT moved to end

// Iteration always yields: banana → apple → cherry
// Insertion order is preserved, duplicates don't shift position
for (String s : set) {
    System.out.println(s);
}

// O(1) lookup — still backed by hash table
System.out.println(set.contains("apple")); // true
```

**Key behavioral rule:** Re-inserting an existing element does NOT move it to the end of the iteration order. Its original insertion position is preserved. This differs from `LinkedHashMap` in access-order mode (which can be configured to move entries on access, used for LRU caches).

| Property | HashSet | LinkedHashSet | TreeSet |
|---|---|---|---|
| Ordering | None | Insertion order | Sorted (natural/comparator) |
| Backed by | HashMap | LinkedHashMap | Red-Black tree |
| `add/remove/contains` | O(1) avg | O(1) avg | O(log n) |
| Memory overhead | Low | Slightly higher (2 extra pointers/entry) | Higher (tree node structure) |
| Null allowed | 1 | 1 | No |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"How does LinkedHashSet maintain insertion order while still providing O(1) lookup?"**

**One-line answer:** It uses a LinkedHashMap as its backing store, which maintains a doubly linked list through all entries alongside the normal hash table — the hash table handles lookup, the linked list handles ordering.

**Full answer to give in an interview:**
> "LinkedHashSet calls a package-private HashSet constructor with a boolean flag that signals 'use LinkedHashMap instead of HashMap as the backing store'. LinkedHashMap extends HashMap but adds two extra fields to each entry: `before` and `after` — pointers forming a doubly linked list that threads through all entries in insertion order. When you add an element, it goes into the hash table (for O(1) lookup) and gets appended to the tail of the doubly linked list (for ordered iteration). When you remove an element, it's unlinked from the hash table bucket and also unlinked from the doubly linked list. Iteration walks the linked list, not the hash table buckets — so you see elements in the order they were inserted, not in hash bucket order. The cost is two extra object references per entry versus plain HashSet."

*The "two extra fields per entry" detail shows you understand the actual implementation, not just the interface contract.*

**Gotcha follow-up they'll ask:** *"If I add the same element twice to a LinkedHashSet, does its position in iteration order change?"*
> No. The second `add()` is rejected as a duplicate — the element's position in the linked list is not touched. It stays where it was first inserted. This is different from `LinkedHashMap` in access-order mode (constructed with `accessOrder = true`), where a `get()` or `put()` of an existing key moves it to the tail — that's the basis of LRU cache implementations. LinkedHashSet always uses insertion-order mode.

---

#### Q2 — Tradeoff Question

**"What are the differences between HashSet, LinkedHashSet, and TreeSet, and when would you use each?"**

**One-line answer:** HashSet for fastest lookup with no ordering; LinkedHashSet when insertion order must be preserved; TreeSet when you need elements sorted or need range queries.

**Full answer to give in an interview:**
> "All three implement `Set` — no duplicates, O(1) or O(log n) membership. HashSet is backed by HashMap: O(1) average for all operations, but iteration order is undefined and changes as the set grows. Use it when you only need membership testing — deduplication, idempotency checks, caching seen IDs. LinkedHashSet is backed by LinkedHashMap: same O(1) operations, but iteration follows insertion order. Use it when the sequence in which you encountered unique elements matters — say, preserving the order of first-seen user IDs while deduplicating a stream. TreeSet is backed by a Red-Black tree: O(log n) for all operations, but iteration is always in sorted natural or comparator order. Use it when you need sorted output, or when you need range operations like `headSet()` to get all elements below a threshold. Memory footprint goes: HashSet < LinkedHashSet < TreeSet, because each adds more structural overhead per entry."

*The three-way comparison in one breath is a common interview question. Memorize the table mentally: speed / insertion order / sorted.*

**Gotcha follow-up they'll ask:** *"Can LinkedHashSet be used as an LRU cache?"*
> Not directly. LinkedHashSet uses insertion-order, not access-order — accessing an element doesn't move it to the tail. `LinkedHashMap` can be configured with `accessOrder = true` and `removeEldestEntry()` overridden for LRU behavior — but that's a Map, not a Set. If you need an LRU Set, wrap a `LinkedHashMap` with `accessOrder = true` and use `keySet()`.

---

#### Q3 — Design Scenario

**"You're processing a stream of log events and need to return the unique event types in the order they first appeared. What do you use?"**

**One-line answer:** A `LinkedHashSet<String>` — deduplicate in O(1) while preserving the order of first occurrence automatically.

**Full answer to give in an interview:**
> "I'd stream through the log events and add each event type to a `LinkedHashSet<String>`. The set rejects duplicates (second occurrence of a type is silently ignored), and because LinkedHashSet maintains insertion order, the first occurrence of each type is automatically preserved in position. When I'm done, iterating the set gives me the unique types in the exact order they were first seen — no sorting step, no extra data structure. If I had used a plain HashSet, I'd lose the ordering. If I had used a List and deduplicated manually with `!list.contains(type)`, that's O(n²) total — one O(n) scan per element. LinkedHashSet gives me O(n) total with O(1) per add and correct ordering built in. If the stream is unbounded and memory is constrained, I'd consider a Bloom filter for approximate deduplication, but for bounded streams a LinkedHashSet is the clean answer."

*The List-with-contains anti-pattern comparison makes the answer concrete and shows you understand the complexity trap.*

**Gotcha follow-up they'll ask:** *"Does LinkedHashSet allow null?"*
> Yes, exactly one null — same as HashSet. Null is stored at bucket 0 in the backing LinkedHashMap and participates in the insertion-order linked list just like any other element. TreeSet does not allow null (comparisons on null throw NullPointerException).

---

> **Common Mistake — Using LinkedHashSet when TreeSet is needed:** Candidates sometimes reach for LinkedHashSet when the requirement is "sorted unique elements." LinkedHashSet preserves insertion order, not sorted order. For alphabetical or natural ordering, use TreeSet. For insertion order, use LinkedHashSet. Mixing them up in an interview is an immediate red flag.

**Quick Revision (one line):** LinkedHashSet = HashSet + insertion-order doubly linked list; O(1) ops, slightly more memory than HashSet; use when iteration must follow insertion sequence.

---

## Topic 6: TreeSet

**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Amazon, Google, financial firms

---

### The Idea

Imagine a sorted filing cabinet. Every time you drop a document in, it automatically slides into the right alphabetical slot — you never have to sort it yourself. That is TreeSet: a Set that keeps every element in order at all times, so your first element is always the smallest and your last is always the greatest.

Under the hood, TreeSet delegates everything to a TreeMap, which uses a Red-Black tree — a self-balancing binary search tree. The tree keeps itself balanced after every insert or delete, which guarantees that no single branch grows too long. The payoff is that every operation (add, remove, contains, floor, ceiling) costs O(log n) regardless of data shape.

Unlike HashSet, TreeSet does not allow null elements. Internally it must compare elements using `compareTo()` or a custom Comparator — calling either on null throws a NullPointerException, so null is simply rejected.

---

### How It Works

**Structure pseudocode:**
```
TreeSet wraps a TreeMap<E, PRESENT>
  where PRESENT = a shared sentinel Object (all values are the same object)
  the TreeMap is a Red-Black tree ordered by:
    - natural ordering (Comparable) if no comparator supplied
    - provided Comparator otherwise
```

**Red-Black tree invariants (what keeps it balanced):**
```
1. Every node is RED or BLACK
2. Root is always BLACK
3. No two consecutive RED nodes (a RED node's parent and children must be BLACK)
4. Every path from a node down to any null leaf has the same number of BLACK nodes
Result: tree height <= 2 * log₂(n)  →  all ops O(log n)
```

**NavigableSet operations (the key differentiator from HashSet):**

| Method | Returns | Complexity |
|---|---|---|
| `floor(e)` | Greatest element <= e | O(log n) |
| `ceiling(e)` | Smallest element >= e | O(log n) |
| `lower(e)` | Greatest element < e (strictly) | O(log n) |
| `higher(e)` | Smallest element > e (strictly) | O(log n) |
| `headSet(e)` | Live view of elements strictly < e | O(log n) |
| `tailSet(e)` | Live view of elements >= e | O(log n) |
| `subSet(from, to)` | Live view of [from, to) | O(log n) |
| `first()` / `last()` | Min / Max element | O(log n) |

**Interview-critical gotcha — Comparator contract must be consistent with equals:**

```java
// THIS IS THE GOTCHA — a Comparator that ignores case means
// "Apple" and "apple" are treated as THE SAME element in TreeSet
// even though they are not equals() — the element is silently dropped
TreeSet<String> set = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
set.add("Apple");
set.add("apple");  // silently NOT added — compareTo returns 0, so TreeSet treats as duplicate
System.out.println(set.size()); // 1, not 2
```

*Tradeoff:* TreeSet vs HashSet — use TreeSet when you need sorted order or range queries; use HashSet when you only need O(1) membership tests and order does not matter.

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What data structure backs TreeSet, and what are its time complexities?"**

**One-line answer:** TreeSet is backed by a TreeMap, which is a Red-Black tree; all operations are O(log n).

**Full answer to give in an interview:**

> TreeSet delegates every operation to a TreeMap internally. TreeMap is implemented as a Red-Black tree — a self-balancing binary search tree. The balancing invariants guarantee the tree height stays within 2 * log₂(n), which means add, remove, contains, and all NavigableSet range methods (floor, ceiling, headSet, tailSet) all run in O(log n) time. This is slower than HashSet's O(1) average, but TreeSet gives you something HashSet cannot: sorted order and efficient range queries. If I need to find all elements less than a threshold, `headSet(threshold)` does that in O(log n) without any sorting step.

*Delivery note: draw a quick BST sketch if at a whiteboard — it signals you actually know the structure, not just the complexity label.*

**Gotcha follow-up they'll ask:** *"Why does TreeSet not allow null elements?"*

> Because TreeSet must compare elements to find their position in the tree. It calls `compareTo()` on elements during every insert and lookup. Calling `compareTo(null)` throws a NullPointerException — the comparison operation is undefined for null. HashSet avoids this because it uses `hashCode()` and `equals()`, and HashMap explicitly handles the null case by assigning it to bucket 0. TreeSet has no equivalent special case.

---

#### Q2 — Tradeoff Question

**"When would you choose TreeSet over HashSet in a backend service?"**

**One-line answer:** Choose TreeSet when you need elements in sorted order or need range/navigation queries; choose HashSet for pure O(1) membership tests.

**Full answer to give in an interview:**

> If I only need to check whether an element exists, HashSet wins — O(1) average versus O(log n) for TreeSet. But TreeSet pays for itself the moment I need ordering. For example, in a session expiry scheduler I might store active session timestamps in a TreeSet. When the cleanup job runs, I call `headSet(expiryThreshold)` and get all expired sessions in O(log n + k) time, where k is the number of expired sessions. With a HashSet I would have to iterate all entries to find the expired ones — O(n). TreeSet also gives me `first()` and `last()` for min/max in O(log n), and `subSet()` for windowed queries. The tradeoff is memory: each TreeMap entry carries parent, left, right, and color pointers — roughly 5x the memory overhead of a HashSet entry.

*Delivery note: the session-expiry example lands well because it is a real backend pattern, not a toy example.*

**Gotcha follow-up they'll ask:** *"What happens if you provide a Comparator that is inconsistent with equals()?"*

> The Set contract breaks silently. TreeSet uses only the Comparator (or `compareTo`) to determine equality — it does not call `equals()`. So if the Comparator returns 0 for two objects that `equals()` would say are different, TreeSet treats them as the same element and the second add is a no-op. The element is lost with no exception. This is a common source of bugs when using case-insensitive Comparators on strings.

---

#### Q3 — Design Scenario

**"Design a leaderboard that supports: add score, remove score, get top-K scores, and get rank of a given score."**

**One-line answer:** A TreeSet with a custom Comparator (score descending, then by player ID for tie-breaking) supports all four operations in O(log n).

**Full answer to give in an interview:**

> I would use a TreeSet ordered by score descending. Since TreeSet does not allow duplicates based on comparator equality, I need a tie-breaking field — I add the player ID so two players with the same score are not collapsed into one entry. The entry class holds (score, playerId). Add and remove are O(log n) inserts/deletes on the tree. For top-K, `stream().limit(k)` iterates from the head of the sorted set — O(k). For rank of a given score, TreeSet does not natively give rank by index, so I would either maintain a separate rank counter or use a more specialised structure like a Fenwick tree for O(log n) rank queries. For most interview purposes, the TreeSet-based solution is sufficient and shows command of the API. If the interviewer pushes for O(log n) rank, I explain the Fenwick tree augmentation or mention that Redis Sorted Sets (ZSETs) solve this problem natively in production.

*Delivery note: proactively naming the limitation (no O(log n) rank) and offering the next level shows senior-level thinking.*

**Gotcha follow-up they'll ask:** *"How would you handle concurrent updates to this leaderboard?"*

> TreeSet is not thread-safe. For concurrent access I would wrap it with `Collections.synchronizedSortedSet()` for coarse-grained locking, or switch to `ConcurrentSkipListSet` which is the concurrent NavigableSet implementation in java.util.concurrent. ConcurrentSkipListSet uses a lock-free skip list and provides the same NavigableSet API (floor, ceiling, headSet) with O(log n) operations and no global lock.

---

> **Common Mistake — Comparator inconsistent with equals:** If your Comparator returns 0 for two objects that are not `equals()`, TreeSet silently drops the second element. You lose data with no exception or warning. Always ensure the Comparator's total order is consistent with `equals()` for correct Set semantics.

**Quick Revision (one line):** TreeSet = TreeMap (Red-Black tree) under the hood; O(log n) all ops; sorted order; NavigableSet API (floor/ceiling/headSet/tailSet); no nulls; Comparator must be consistent with equals.

---

## Topic 7: HashMap Internals (Java 8+)

**Difficulty:** Hard | **Frequency:** Very High | **Companies:** Google, Amazon, Goldman Sachs, Morgan Stanley, Stripe, Uber, Airbnb

<svg viewBox="0 0 760 340" xmlns="http://www.w3.org/2000/svg" font-family="system-ui, -apple-system, sans-serif" style="width:100%; max-width:760px; display:block; margin:16px 0;">
  <defs>
    <style>
      /* ── Base resets ── */
      .bucket-box { fill: #1e293b; stroke: #334155; stroke-width: 1.5; rx: 4; }
      .bucket-label { fill: #64748b; font-size: 10px; text-anchor: middle; }
      .bucket-index { fill: #475569; font-size: 9px; text-anchor: middle; }
      .key-box { fill: #1d4ed8; stroke: #3b82f6; stroke-width: 1.5; rx: 6; }
      .key-text { fill: #eff6ff; font-size: 11px; font-weight: 600; text-anchor: middle; }
      .hash-box { fill: #1e293b; stroke: #6366f1; stroke-width: 1.5; rx: 6; }
      .hash-text { fill: #a5b4fc; font-size: 10px; text-anchor: middle; }
      .node-box { rx: 5; stroke-width: 1.5; }
      .node-text { font-size: 9px; font-weight: 600; text-anchor: middle; }
      .arrow { stroke-width: 1.8; fill: none; marker-end: url(#arrowhead); }
      .title-text { fill: #94a3b8; font-size: 11px; font-weight: 500; }
      .step-label { fill: #64748b; font-size: 9px; text-anchor: middle; }

      /* ── Arrow markers ── */

      /* ── PHASE TIMING (total loop = 6s) ──
         Phase 1: 0-0.8s  — idle/reset
         Phase 2: 0.8-2.0s — put "cat" → bucket 3
         Phase 3: 2.0-3.4s — put "dog" → bucket 3 (collision)
         Phase 4: 3.4-4.6s — put "fox" → bucket 6
         Phase 5: 4.6-5.4s — treeify flash
         Phase 6: 5.4-6.0s — hold/fade
      */

      /* ══════════════════════════════════
         KEY "cat" — appears at t=0.8s
      ══════════════════════════════════ */
      #key-cat {
        opacity: 0;
        animation: showCat 6s linear infinite;
      }
      @keyframes showCat {
        0%    { opacity: 0; }
        13.3% { opacity: 0; }   /* 0.8s */
        16.7% { opacity: 1; }   /* 1.0s */
        66.7% { opacity: 1; }   /* 4.0s */
        73.3% { opacity: 0; }   /* 4.4s */
        100%  { opacity: 0; }
      }

      /* Arrow: key-cat → hash box */
      #arrow-cat-hash {
        opacity: 0;
        animation: arrowCatHash 6s linear infinite;
      }
      @keyframes arrowCatHash {
        0%    { opacity: 0; }
        16.7% { opacity: 0; }
        20.0% { opacity: 1; }
        26.7% { opacity: 0; }
        100%  { opacity: 0; }
      }

      /* Hash box pulse for cat */
      #hash-box-cat {
        opacity: 0;
        animation: hashCat 6s linear infinite;
      }
      @keyframes hashCat {
        0%    { opacity: 0; }
        18.3% { opacity: 0; }
        21.7% { opacity: 1; }
        28.3% { opacity: 0; }
        100%  { opacity: 0; }
      }

      /* Arrow: hash → bucket 3 (cat) */
      #arrow-hash-b3-cat {
        opacity: 0;
        animation: arrowHashB3Cat 6s linear infinite;
      }
      @keyframes arrowHashB3Cat {
        0%    { opacity: 0; }
        23.3% { opacity: 0; }
        26.7% { opacity: 1; }
        33.3% { opacity: 0; }
        100%  { opacity: 0; }
      }

      /* Node "cat" in bucket 3 */
      #node-cat {
        opacity: 0;
        transform: translateY(8px);
        animation: nodeCat 6s linear infinite;
      }
      @keyframes nodeCat {
        0%    { opacity: 0; transform: translateY(8px); }
        30.0% { opacity: 0; transform: translateY(8px); }
        36.7% { opacity: 1; transform: translateY(0);   }
        73.3% { opacity: 1; transform: translateY(0);   }
        78.3% { opacity: 0; transform: translateY(0);   }
        100%  { opacity: 0; transform: translateY(0);   }
      }

      /* ══════════════════════════════════
         KEY "dog" — appears at t=2.0s
      ══════════════════════════════════ */
      #key-dog {
        opacity: 0;
        animation: showDog 6s linear infinite;
      }
      @keyframes showDog {
        0%    { opacity: 0; }
        33.3% { opacity: 0; }
        36.7% { opacity: 1; }
        66.7% { opacity: 1; }
        73.3% { opacity: 0; }
        100%  { opacity: 0; }
      }

      #arrow-dog-hash {
        opacity: 0;
        animation: arrowDogHash 6s linear infinite;
      }
      @keyframes arrowDogHash {
        0%    { opacity: 0; }
        36.7% { opacity: 0; }
        40.0% { opacity: 1; }
        46.7% { opacity: 0; }
        100%  { opacity: 0; }
      }

      #hash-box-dog {
        opacity: 0;
        animation: hashDog 6s linear infinite;
      }
      @keyframes hashDog {
        0%    { opacity: 0; }
        38.3% { opacity: 0; }
        41.7% { opacity: 1; }
        48.3% { opacity: 0; }
        100%  { opacity: 0; }
      }

      #arrow-hash-b3-dog {
        opacity: 0;
        animation: arrowHashB3Dog 6s linear infinite;
      }
      @keyframes arrowHashB3Dog {
        0%    { opacity: 0; }
        43.3% { opacity: 0; }
        46.7% { opacity: 1; }
        53.3% { opacity: 0; }
        100%  { opacity: 0; }
      }

      /* Collision label */
      #collision-label {
        opacity: 0;
        animation: collisionFlash 6s linear infinite;
      }
      @keyframes collisionFlash {
        0%    { opacity: 0; }
        46.7% { opacity: 0; }
        50.0% { opacity: 1; }
        58.3% { opacity: 1; }
        63.3% { opacity: 0; }
        100%  { opacity: 0; }
      }

      /* Node "dog" chained after "cat" */
      #node-dog {
        opacity: 0;
        transform: translateY(8px);
        animation: nodeDog 6s linear infinite;
      }
      @keyframes nodeDog {
        0%    { opacity: 0; transform: translateY(8px); }
        50.0% { opacity: 0; transform: translateY(8px); }
        56.7% { opacity: 1; transform: translateY(0);   }
        73.3% { opacity: 1; transform: translateY(0);   }
        78.3% { opacity: 0; transform: translateY(0);   }
        100%  { opacity: 0; transform: translateY(0);   }
      }

      /* Link line between cat→dog nodes */
      #link-cat-dog {
        opacity: 0;
        animation: linkCatDog 6s linear infinite;
      }
      @keyframes linkCatDog {
        0%    { opacity: 0; }
        53.3% { opacity: 0; }
        58.3% { opacity: 1; }
        73.3% { opacity: 1; }
        78.3% { opacity: 0; }
        100%  { opacity: 0; }
      }

      /* ══════════════════════════════════
         KEY "fox" — appears at t=3.4s
      ══════════════════════════════════ */
      #key-fox {
        opacity: 0;
        animation: showFox 6s linear infinite;
      }
      @keyframes showFox {
        0%    { opacity: 0; }
        56.7% { opacity: 0; }
        60.0% { opacity: 1; }
        76.7% { opacity: 1; }
        81.7% { opacity: 0; }
        100%  { opacity: 0; }
      }

      #arrow-fox-hash {
        opacity: 0;
        animation: arrowFoxHash 6s linear infinite;
      }
      @keyframes arrowFoxHash {
        0%    { opacity: 0; }
        60.0% { opacity: 0; }
        63.3% { opacity: 1; }
        68.3% { opacity: 0; }
        100%  { opacity: 0; }
      }

      #hash-box-fox {
        opacity: 0;
        animation: hashFox 6s linear infinite;
      }
      @keyframes hashFox {
        0%    { opacity: 0; }
        62.0% { opacity: 0; }
        65.3% { opacity: 1; }
        70.3% { opacity: 0; }
        100%  { opacity: 0; }
      }

      #arrow-hash-b6-fox {
        opacity: 0;
        animation: arrowHashB6Fox 6s linear infinite;
      }
      @keyframes arrowHashB6Fox {
        0%    { opacity: 0; }
        65.3% { opacity: 0; }
        68.7% { opacity: 1; }
        73.7% { opacity: 0; }
        100%  { opacity: 0; }
      }

      #node-fox {
        opacity: 0;
        transform: translateY(8px);
        animation: nodeFox 6s linear infinite;
      }
      @keyframes nodeFox {
        0%    { opacity: 0; transform: translateY(8px); }
        70.0% { opacity: 0; transform: translateY(8px); }
        75.0% { opacity: 1; transform: translateY(0);   }
        88.3% { opacity: 1; transform: translateY(0);   }
        93.3% { opacity: 0; transform: translateY(0);   }
        100%  { opacity: 0; transform: translateY(0);   }
      }

      /* ══════════════════════════════════
         TREEIFY FLASH at t=4.6s
      ══════════════════════════════════ */
      #treeify-panel {
        opacity: 0;
        animation: treeifyFlash 6s linear infinite;
      }
      @keyframes treeifyFlash {
        0%    { opacity: 0; }
        76.7% { opacity: 0; }
        80.0% { opacity: 1; }
        90.0% { opacity: 1; }
        95.0% { opacity: 0; }
        100%  { opacity: 0; }
      }

      /* Bucket highlight on treeify */
      #bucket3-highlight {
        opacity: 0;
        animation: b3Highlight 6s linear infinite;
      }
      @keyframes b3Highlight {
        0%    { opacity: 0; }
        76.7% { opacity: 0; }
        80.0% { opacity: 0.6; }
        90.0% { opacity: 0.6; }
        95.0% { opacity: 0; }
        100%  { opacity: 0; }
      }
    </style>

    <marker id="arrowhead" markerWidth="7" markerHeight="7" refX="5" refY="3.5" orient="auto">
      <polygon points="0 0, 7 3.5, 0 7" fill="#6366f1" opacity="0.85"/>
    </marker>
    <marker id="arrowhead-green" markerWidth="7" markerHeight="7" refX="5" refY="3.5" orient="auto">
      <polygon points="0 0, 7 3.5, 0 7" fill="#10b981" opacity="0.85"/>
    </marker>
    <marker id="arrowhead-amber" markerWidth="7" markerHeight="7" refX="5" refY="3.5" orient="auto">
      <polygon points="0 0, 7 3.5, 0 7" fill="#f59b0b" opacity="0.9"/>
    </marker>
  </defs>

  <!-- ── Background ── -->
  <rect width="760" height="340" fill="#f8fafc" rx="10"/>

  <!-- ── Title ── -->
  <text x="380" y="22" text-anchor="middle" fill="#1e293b" font-size="13" font-weight="700" font-family="system-ui">HashMap Internals — put() Lifecycle</text>

  <!-- ════════════════════════════════════════
       BUCKET ARRAY  (8 buckets, y=40..200)
  ════════════════════════════════════════ -->
  <!-- bucket width=72, gap=8, start x=40 -->

  <!-- Bucket 0 -->
  <rect x="40" y="50" width="72" height="60" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5" rx="4"/>
  <text x="76" y="66" class="bucket-index">0</text>
  <text x="76" y="95" class="bucket-label">null</text>

  <!-- Bucket 1 -->
  <rect x="120" y="50" width="72" height="60" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5" rx="4"/>
  <text x="156" y="66" class="bucket-index">1</text>
  <text x="156" y="95" class="bucket-label">null</text>

  <!-- Bucket 2 -->
  <rect x="200" y="50" width="72" height="60" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5" rx="4"/>
  <text x="236" y="66" class="bucket-index">2</text>
  <text x="236" y="95" class="bucket-label">null</text>

  <!-- Bucket 3 (active — cat/dog) -->
  <rect x="280" y="50" width="72" height="60" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5" rx="4"/>
  <!-- treeify highlight layer -->
  <rect id="bucket3-highlight" x="280" y="50" width="72" height="60" fill="#f59b0b" stroke="none" rx="4"/>
  <text x="316" y="66" class="bucket-index">3</text>

  <!-- Bucket 4 -->
  <rect x="360" y="50" width="72" height="60" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5" rx="4"/>
  <text x="396" y="66" class="bucket-index">4</text>
  <text x="396" y="95" class="bucket-label">null</text>

  <!-- Bucket 5 -->
  <rect x="440" y="50" width="72" height="60" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5" rx="4"/>
  <text x="476" y="66" class="bucket-index">5</text>
  <text x="476" y="95" class="bucket-label">null</text>

  <!-- Bucket 6 (active — fox) -->
  <rect x="520" y="50" width="72" height="60" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5" rx="4"/>
  <text x="556" y="66" class="bucket-index">6</text>

  <!-- Bucket 7 -->
  <rect x="600" y="50" width="72" height="60" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5" rx="4"/>
  <text x="636" y="66" class="bucket-index">7</text>
  <text x="636" y="95" class="bucket-label">null</text>

  <!-- Array label -->
  <text x="40" y="44" fill="#64748b" font-size="9" font-family="system-ui">table[ ]  (capacity = 8)</text>

  <!-- ════════════════════════════════════════
       LINKED LIST NODES below bucket 3
  ════════════════════════════════════════ -->

  <!-- Node "cat" (first node in bucket 3) -->
  <g id="node-cat">
    <rect x="282" y="125" width="68" height="22" fill="#d1fae5" stroke="#10b981" stroke-width="1.5" rx="5"/>
    <text x="316" y="140" fill="#065f46" font-size="9" font-weight="600" text-anchor="middle">cat → v1</text>
    <!-- next pointer stub -->
    <rect x="338" y="131" width="12" height="10" fill="#d1fae5" stroke="#10b981" stroke-width="1" rx="2"/>
    <text x="344" y="139" fill="#065f46" font-size="7" text-anchor="middle">→</text>
  </g>

  <!-- Node "dog" (chained after cat) -->
  <g id="node-dog">
    <rect x="282" y="158" width="68" height="22" fill="#fef3c7" stroke="#f59b0b" stroke-width="1.5" rx="5"/>
    <text x="316" y="173" fill="#92400e" font-size="9" font-weight="600" text-anchor="middle">dog → v2</text>
    <rect x="338" y="164" width="12" height="10" fill="#fef3c7" stroke="#f59b0b" stroke-width="1" rx="2"/>
    <text x="344" y="172" fill="#92400e" font-size="7" text-anchor="middle">∅</text>
  </g>

  <!-- Link line cat → dog -->
  <line id="link-cat-dog" x1="316" y1="147" x2="316" y2="158" stroke="#f59b0b" stroke-width="1.5" stroke-dasharray="3,2" marker-end="url(#arrowhead-amber)"/>

  <!-- Node "fox" in bucket 6 -->
  <g id="node-fox">
    <rect x="522" y="125" width="68" height="22" fill="#d1fae5" stroke="#10b981" stroke-width="1.5" rx="5"/>
    <text x="556" y="140" fill="#065f46" font-size="9" font-weight="600" text-anchor="middle">fox → v3</text>
    <rect x="578" y="131" width="12" height="10" fill="#d1fae5" stroke="#10b981" stroke-width="1" rx="2"/>
    <text x="584" y="139" fill="#065f46" font-size="7" text-anchor="middle">∅</text>
  </g>

  <!-- ════════════════════════════════════════
       STEP INPUT AREA  (y ≈ 200–270)
  ════════════════════════════════════════ -->

  <!-- Key "cat" pill -->
  <g id="key-cat">
    <rect x="60" y="205" width="52" height="22" fill="#1d4ed8" stroke="#3b82f6" stroke-width="1.5" rx="6"/>
    <text x="86" y="220" fill="#eff6ff" font-size="11" font-weight="600" text-anchor="middle">"cat"</text>
  </g>

  <!-- Key "dog" pill -->
  <g id="key-dog">
    <rect x="60" y="205" width="52" height="22" fill="#1d4ed8" stroke="#3b82f6" stroke-width="1.5" rx="6"/>
    <text x="86" y="220" fill="#eff6ff" font-size="11" font-weight="600" text-anchor="middle">"dog"</text>
  </g>

  <!-- Key "fox" pill -->
  <g id="key-fox">
    <rect x="60" y="205" width="52" height="22" fill="#1d4ed8" stroke="#3b82f6" stroke-width="1.5" rx="6"/>
    <text x="86" y="220" fill="#eff6ff" font-size="11" font-weight="600" text-anchor="middle">"fox"</text>
  </g>

  <!-- Arrow key → hash (shared path, colored per step via separate elements) -->
  <!-- cat -->
  <g id="arrow-cat-hash">
    <line x1="114" y1="216" x2="158" y2="216" stroke="#6366f1" stroke-width="1.8" marker-end="url(#arrowhead)"/>
  </g>
  <!-- dog -->
  <g id="arrow-dog-hash">
    <line x1="114" y1="216" x2="158" y2="216" stroke="#6366f1" stroke-width="1.8" marker-end="url(#arrowhead)"/>
  </g>
  <!-- fox -->
  <g id="arrow-fox-hash">
    <line x1="114" y1="216" x2="158" y2="216" stroke="#6366f1" stroke-width="1.8" marker-end="url(#arrowhead)"/>
  </g>

  <!-- Hash function box — cat -->
  <g id="hash-box-cat">
    <rect x="160" y="204" width="88" height="24" fill="#f1f5f9" stroke="#6366f1" stroke-width="1.5" rx="6"/>
    <text x="204" y="220" fill="#a5b4fc" font-size="9" font-weight="600" text-anchor="middle">hashCode() % 8</text>
    <text x="204" y="233" fill="#6366f1" font-size="8" text-anchor="middle">→ index 3</text>
  </g>

  <!-- Hash function box — dog -->
  <g id="hash-box-dog">
    <rect x="160" y="204" width="88" height="24" fill="#f1f5f9" stroke="#6366f1" stroke-width="1.5" rx="6"/>
    <text x="204" y="220" fill="#a5b4fc" font-size="9" font-weight="600" text-anchor="middle">hashCode() % 8</text>
    <text x="204" y="233" fill="#f59b0b" font-size="8" text-anchor="middle">→ index 3 !</text>
  </g>

  <!-- Hash function box — fox -->
  <g id="hash-box-fox">
    <rect x="160" y="204" width="88" height="24" fill="#f1f5f9" stroke="#6366f1" stroke-width="1.5" rx="6"/>
    <text x="204" y="220" fill="#a5b4fc" font-size="9" font-weight="600" text-anchor="middle">hashCode() % 8</text>
    <text x="204" y="233" fill="#6366f1" font-size="8" text-anchor="middle">→ index 6</text>
  </g>

  <!-- Arrow hash → bucket 3 (cat) — diagonal up-right -->
  <g id="arrow-hash-b3-cat">
    <path d="M 248 212 Q 290 190 312 114" stroke="#10b981" stroke-width="1.8" fill="none" stroke-dasharray="5,3" marker-end="url(#arrowhead-green)"/>
    <text x="268" y="193" fill="#10b981" font-size="8" font-weight="600">bucket[3]</text>
  </g>

  <!-- Arrow hash → bucket 3 (dog/collision) -->
  <g id="arrow-hash-b3-dog">
    <path d="M 248 212 Q 290 190 312 114" stroke="#f59b0b" stroke-width="1.8" fill="none" stroke-dasharray="5,3" marker-end="url(#arrowhead-amber)"/>
    <text x="268" y="193" fill="#f59b0b" font-size="8" font-weight="600">bucket[3]</text>
  </g>

  <!-- Arrow hash → bucket 6 (fox) -->
  <g id="arrow-hash-b6-fox">
    <path d="M 248 212 Q 390 190 548 114" stroke="#10b981" stroke-width="1.8" fill="none" stroke-dasharray="5,3" marker-end="url(#arrowhead-green)"/>
    <text x="388" y="196" fill="#10b981" font-size="8" font-weight="600">bucket[6]</text>
  </g>

  <!-- Collision label -->
  <g id="collision-label">
    <rect x="270" y="194" width="92" height="16" fill="#fef3c7" stroke="#f59b0b" stroke-width="1" rx="4"/>
    <text x="316" y="205" fill="#92400e" font-size="9" font-weight="700" text-anchor="middle">⚡ COLLISION</text>
  </g>

  <!-- ════════════════════════════════════════
       TREEIFY PANEL
  ════════════════════════════════════════ -->
  <g id="treeify-panel">
    <rect x="200" y="120" width="232" height="70" fill="#fffbeb" stroke="#f59b0b" stroke-width="2" rx="8" opacity="0.97"/>
    <text x="316" y="140" fill="#92400e" font-size="11" font-weight="700" text-anchor="middle">Treeification Triggered!</text>
    <text x="316" y="157" fill="#b45309" font-size="9" text-anchor="middle">Bucket length ≥ TREEIFY_THRESHOLD (8)</text>
    <text x="316" y="172" fill="#64748b" font-size="9" text-anchor="middle">LinkedList → Red-Black Tree</text>
    <!-- small tree icon -->
    <line x1="310" y1="183" x2="316" y2="175" stroke="#10b981" stroke-width="1.5"/>
    <line x1="322" y1="183" x2="316" y2="175" stroke="#10b981" stroke-width="1.5"/>
    <line x1="316" y1="175" x2="316" y2="169" stroke="#10b981" stroke-width="1.5"/>
    <circle cx="316" cy="168" r="3" fill="#10b981"/>
    <circle cx="309" cy="183" r="3" fill="#10b981"/>
    <circle cx="323" cy="183" r="3" fill="#10b981"/>
  </g>

  <!-- ════════════════════════════════════════
       LEGEND  (y ≈ 300–330)
  ════════════════════════════════════════ -->
  <rect x="40" y="296" width="680" height="30" fill="#f8fafc" stroke="#e2e8f0" stroke-width="1" rx="6"/>

  <!-- legend item 1 -->
  <rect x="52" y="305" width="12" height="12" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5" rx="2"/>
  <text x="69" y="315" fill="#64748b" font-size="9" font-family="system-ui">Array of Buckets</text>

  <line x1="168" y1="304" x2="168" y2="318" stroke="#cbd5e1" stroke-width="1"/>

  <!-- legend item 2 -->
  <rect x="178" y="305" width="12" height="12" fill="#fef3c7" stroke="#f59b0b" stroke-width="1.5" rx="2"/>
  <text x="195" y="315" fill="#64748b" font-size="9" font-family="system-ui">Hash Collision → Linked List</text>

  <line x1="358" y1="304" x2="358" y2="318" stroke="#cbd5e1" stroke-width="1"/>

  <!-- legend item 3 -->
  <rect x="368" y="305" width="12" height="12" fill="#fffbeb" stroke="#f59b0b" stroke-width="1.5" rx="2"/>
  <text x="385" y="315" fill="#64748b" font-size="9" font-family="system-ui">8+ Nodes → Red-Black Tree</text>

  <line x1="530" y1="304" x2="530" y2="318" stroke="#cbd5e1" stroke-width="1"/>

  <!-- legend item 4 -->
  <rect x="540" y="305" width="12" height="12" fill="#d1fae5" stroke="#10b981" stroke-width="1.5" rx="2"/>
  <text x="557" y="315" fill="#64748b" font-size="9" font-family="system-ui">Successful insert</text>

  <!-- Step annotation strip -->
  <text x="380" y="285" text-anchor="middle" fill="#1e293b" font-size="8" font-family="system-ui">Java 8+ HashMap — default load factor 0.75, default capacity 16 (shown here as 8 for clarity)</text>

</svg>

---

### The Idea

Picture a city with 16 numbered post-office boxes (the default). When you send a letter (store a key-value pair), a fast sorting algorithm looks at the recipient's address (the key's hash code), mixes the upper and lower halves of the address together to spread things evenly, then assigns the letter to one specific box (bucket). Most boxes hold just one letter. Occasionally two letters end up in the same box (collision) — they form a chain. If a box gets so crowded that more than 8 letters pile up, the chain converts to a sorted tree so searching it stays fast even in the worst case.

When the post office gets too full overall (more than 75% of boxes are in use), it doubles the number of boxes and redistributes all letters. This is called rehashing, and it is an O(n) operation — the one expensive step in an otherwise O(1) world.

The design is a careful balance of speed, memory, and worst-case safety. Every constant (16, 0.75, 8, 6, 64) was chosen empirically across a wide range of real-world workloads.

---

### How It Works

**Core fields and constants (pseudocode view):**
```
table[]          → the bucket array (initially null, lazily allocated on first put)
size             → number of key-value entries stored
threshold        → size at which next resize triggers = capacity * loadFactor
loadFactor       → default 0.75

DEFAULT_INITIAL_CAPACITY = 16   (always a power of 2)
DEFAULT_LOAD_FACTOR      = 0.75
TREEIFY_THRESHOLD        = 8    (chain → tree when bin reaches this length)
UNTREEIFY_THRESHOLD      = 6    (tree → chain on resize if bin shrinks to this)
MIN_TREEIFY_CAPACITY     = 64   (resize instead of treeify if table < this size)
```

**Hash function — why XOR with upper 16 bits:**
```
hash(key):
  h = key.hashCode()
  return h XOR (h >>> 16)       // spread upper 16 bits into lower 16 bits

bucket index:
  index = hash AND (capacity - 1)   // fast modulo because capacity is power-of-2
```

With a small capacity like 16, `capacity - 1 = 0b00001111` — only the bottom 4 bits of the hash matter for bucket placement. Keys whose lower bits are similar would cluster heavily. XOR-ing the upper half into the lower half makes all 32 bits influence the result without any expensive division.

**put() flow (pseudocode):**
```
put(key, value):
  1. If table is null → resize() to allocate initial array (lazy init)
  2. index = hash(key) AND (capacity - 1)
  3. If bucket[index] is empty → insert new Node directly
  4. Else if first node in bucket matches key → update value
  5. Else if bucket is a TreeNode → delegate to tree insert (O(log n))
  6. Else traverse linked list chain:
       a. If key found → update value
       b. If end of chain → append new Node
       c. If chain length just hit TREEIFY_THRESHOLD (8):
            if table.length < MIN_TREEIFY_CAPACITY (64) → resize() instead
            else → treeifyBin() (convert chain to Red-Black tree)
  7. ++size
  8. If size > threshold → resize() (double capacity, rehash all entries)
```

**get() flow (pseudocode):**
```
get(key):
  1. index = hash(key) AND (capacity - 1)
  2. Check first node in bucket → match? return value
  3. If bucket is TreeNode → tree search O(log n)
  4. Else walk linked list → O(chain length)
  5. Return null if not found
```

**Resize / rehash (pseudocode):**
```
resize():
  newCapacity = oldCapacity * 2
  newThreshold = newCapacity * loadFactor
  For each entry in old table:
    new index = hash AND (newCapacity - 1)
    // Optimization: new index is either oldIndex OR oldIndex + oldCapacity
    // Only one new bit of the hash needs to be checked — no full recompute
```

**Interview-critical gotcha — mutable keys break HashMap silently:**

```java
// THE SINGLE MOST IMPORTANT GOTCHA
// If a key's hashCode() changes after insertion, get() will never find it
// because it looks in the WRONG bucket
List<String> key = new ArrayList<>(List.of("a", "b"));
Map<List<String>, String> map = new HashMap<>();
map.put(key, "value");

key.add("c");  // mutate the key — hashCode() changes!

String result = map.get(key);  // returns null — wrong bucket is searched
// The entry is still in the map (in the OLD bucket) — silent data loss
```

**Comparison: Java 7 vs Java 8+ buckets:**

| Aspect | Java 7 | Java 8+ |
|---|---|---|
| Collision structure | Linked list only | Linked list → Red-Black tree |
| Worst-case get/put | O(n) | O(log n) |
| Hash DoS vulnerability | Yes (O(n²) attack possible) | Mitigated by treeification |
| New-entry insertion | Head of list | Tail of list |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"Walk me through exactly what happens when you call put('key', 'value') on a HashMap."**

**One-line answer:** Hash the key (XOR upper/lower 16 bits), find the bucket via bitwise AND, insert into empty slot or chain/tree, then resize if size exceeds threshold.

**Full answer to give in an interview:**

> First, HashMap computes `hash(key)` — it calls `key.hashCode()` and then XORs the result with itself right-shifted 16 bits. This "spreads" the upper half of the hash into the lower half so that with a small bucket array, all 32 bits of the hash influence which bucket is chosen. The bucket index is `hash & (capacity - 1)` — a fast bitwise AND that works because capacity is always a power of 2.
>
> If the bucket is empty, a new Node is created and placed there directly — O(1). If the bucket is occupied, HashMap checks the first node: if hash and key match, it updates the value. Otherwise it walks the chain. If it finds a matching key, it updates. If it reaches the end without finding the key, it appends a new Node. If after appending the chain length has reached 8 and the table has at least 64 buckets, the chain is converted to a Red-Black tree (treeifyBin). If the table is smaller than 64, it resizes instead.
>
> After insertion, if `++size > threshold` (where threshold = capacity × 0.75), the table doubles in capacity and all entries are rehashed. Each entry's new index is either the same as before or old-index + old-capacity — a one-bit check, not a full recompute.

*Delivery note: pause after "XOR with upper 16 bits" — interviewers often probe here. Be ready to explain why (small capacity means only low bits determine bucket; XOR prevents clustering).*

**Gotcha follow-up they'll ask:** *"What is the default capacity, and when is the array actually allocated?"*

> The default initial capacity is 16. But the array is lazily allocated — it is null until the first `put()` call. Creating `new HashMap<>()` allocates no array. This matters for memory profiling: a map that is constructed but never written to has near-zero heap footprint.

---

#### Q2 — Tradeoff Question

**"Why does HashMap use a power-of-2 capacity, and what does that enable?"**

**One-line answer:** Power-of-2 capacity turns modulo (expensive division) into a single bitwise AND instruction, and it enables a one-bit rehash optimization during resize.

**Full answer to give in an interview:**

> The bucket index for a key is `hash % capacity`. Integer division takes 20–40 CPU cycles. When capacity is a power of 2, `capacity - 1` is a bitmask of all ones (e.g., 16 → 15 = `0b00001111`), so `hash % capacity` equals `hash & (capacity - 1)` exactly — one cycle. At millions of operations per second, this matters.
>
> The second benefit appears during resize. When capacity doubles from N to 2N, the new index of every entry is either its old index or old index + N. Which one? It depends on exactly one bit of the hash — the bit at position log₂(N). So the rehash loop checks just that one bit instead of recomputing the full modulo for every entry. This is an O(n) rehash either way, but it is a fast O(n).
>
> If you construct `new HashMap<>(10)`, HashMap rounds up to 16 internally — it always enforces power-of-2. The rounding is done via `Integer.highestOneBit((n - 1) << 1)`.

*Delivery note: mention the CPU cycle comparison to signal low-level awareness, but do not dwell on it — move to the rehash optimization which is the more interesting insight.*

**Gotcha follow-up they'll ask:** *"If two objects are equals() but have different hashCode(), what happens in a HashMap?"*

> This violates the hashCode/equals contract, and HashMap breaks silently. The two objects are placed in different buckets because their hashes differ. When you look up one using the other as a key, `get()` computes the hash, goes to the wrong bucket, and returns null — even though an "equal" key is stored elsewhere. This is a correctness bug, not a crash. The contract requires: if `a.equals(b)` then `a.hashCode() == b.hashCode()`. The reverse need not hold — two unequal objects can share a hashCode (collision), but they will both be stored and correctly distinguished by `equals()`.

---

#### Q3 — Design Scenario

**"You are building a high-throughput order cache. How would you size and configure a HashMap to avoid rehashing during a request lifecycle?"**

**One-line answer:** Pre-size with `(int)(expectedEntries / 0.75) + 1` so the initial capacity threshold exceeds your expected entry count, eliminating all resize operations.

**Full answer to give in an interview:**

> A resize is O(n) — every entry is rehashed and moved. In a latency-sensitive request path, an unexpected resize can add milliseconds. To avoid it, I pre-size the map. The formula is `new HashMap<>((int)(expectedEntries / 0.75) + 1)`. This ensures that even after all expected entries are inserted, `size` stays below `threshold = capacity * 0.75`, so no resize triggers. For example, if I expect 100 entries: `(int)(100 / 0.75) + 1 = 134`, which HashMap rounds up to 256 (next power of 2). That gives a threshold of 192, comfortably above 100.
>
> Beyond sizing, I make sure the key class has a well-distributed `hashCode()`. A poor hash (all keys returning the same code) collapses the map to a single bucket. In Java 8+ that bucket treeifies at 8 entries and degrades to O(log n), but it is still far from O(1). I also use immutable keys — mutable keys that change after insertion break `get()` silently because the hash points to the old bucket while the key now lives in a different one conceptually.

*Delivery note: the formula `expectedEntries / 0.75 + 1` is the exact pattern from Guava's `Maps.newHashMapWithExpectedSize()` — mentioning that signals library familiarity.*

**Gotcha follow-up they'll ask:** *"Why does HashMap allow null keys but ConcurrentHashMap does not?"*

> HashMap explicitly handles null: `hash(null)` returns 0, so null keys always go to bucket 0. There is exactly one null slot, and it works fine single-threaded. ConcurrentHashMap cannot support null because its concurrent get operations cannot distinguish between "key not present" and "key maps to null value" — a null return from `get()` would be ambiguous. Since ConcurrentHashMap is used in concurrent contexts where you often need to distinguish absence from null, the designers simply banned null keys and null values to eliminate that ambiguity entirely.

---

> **Common Mistake — Mutable key data loss:** Storing a mutable object as a HashMap key and then mutating it causes `get()` to search the wrong bucket and return null. The entry still occupies memory but is permanently unreachable. Always use immutable objects (String, Integer, or a record) as HashMap keys.

**Quick Revision (one line):** HashMap = array of 16 buckets (power-of-2) + linked list per bucket → Red-Black tree at bin size 8 (table >= 64); hash = `hashCode() ^ (hashCode() >>> 16)`; index = `hash & (cap-1)`; resize at 75% load doubles capacity; null key → bucket 0.

---

## Topic 8: HashMap Performance

**Difficulty:** Medium | **Frequency:** High | **Companies:** Google, Amazon, financial firms, system design rounds

---

### The Idea

HashMap advertises O(1) for get, put, and remove — but that is the average case, and averages hide the devil. The actual performance depends on three things: how evenly the hash function distributes keys across buckets, how full the map is (the load factor), and whether Java 8's treeification safety net kicks in.

Think of it like checkout lanes at a supermarket. If customers distribute evenly, each lane (bucket) has one or two people and service is instant. But if all customers pile into lane 3 (hash collision), that lane's queue grows linearly — or in Java 8+, it reorganises itself into a more searchable sorted structure once the queue hits eight people, keeping the worst case at O(log n) instead of O(n).

The resize operation is the hidden cost. When the store gets more than 75% full, management doubles the number of lanes and moves every customer to their new assigned lane. That is O(n) work — unavoidable, but amortised across many inserts so it rarely shows up in practice unless you trigger it inside a hot loop.

---

### How It Works

**Complexity table:**

| Operation | Average Case | Worst Case Java 7 | Worst Case Java 8+ |
|---|---|---|---|
| `put(k, v)` | O(1) | O(n) | O(log n) |
| `get(k)` | O(1) | O(n) | O(log n) |
| `remove(k)` | O(1) | O(n) | O(log n) |
| `containsKey(k)` | O(1) | O(n) | O(log n) |
| `resize()` | O(n) | O(n) | O(n) |
| Iteration | O(capacity + size) | O(capacity + size) | O(capacity + size) |

**Why iteration is O(capacity + size), not O(size):**
```
HashMap iterator walks the ENTIRE bucket array first, checking each slot
  Even if capacity = 65,536 and size = 3, the iterator visits 65,536 slots
  Cost = number of empty buckets visited + number of entries traversed
  → new HashMap<>(Integer.MAX_VALUE) would be catastrophic to iterate
```

**Load factor tradeoffs:**

| Load Factor | Collisions | Memory | Resize Frequency |
|---|---|---|---|
| 0.5 | Low | Wasteful (half empty on average) | More frequent |
| 0.75 (default) | Balanced | Balanced | Empirically optimal |
| 0.9 | Higher | Efficient | Less frequent |

**Hash DoS attack (why treeification matters in security contexts):**
```
Before Java 8:
  An attacker who knows the JVM's hash function can craft N keys
  that all map to bucket 0 → linked list of length N
  Each get() on that bucket costs O(N) → O(N) requests × O(N) per request = O(N²) total
  → Effective DoS with few hundred crafted keys (CVE-2011-4461 pattern)

Java 8+ mitigation:
  Bin treeifies at length 8 → worst-case per-bucket becomes O(log N)
  DoS degrades from O(N²) to O(N log N) — still harmful but much harder to exploit
```

**Interview-critical gotcha — the right pre-sizing formula:**

```java
// WRONG — causes one resize at 13 entries (16 * 0.75 = 12 threshold)
Map<String, Integer> map = new HashMap<>(16);

// RIGHT — no resize for up to 100 entries
// Formula: (int)(expectedSize / 0.75) + 1
Map<String, Integer> preSized = new HashMap<>((int)(100 / 0.75) + 1); // 135 → rounded to 256
// threshold = 256 * 0.75 = 192 > 100 ✓
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is the worst-case time complexity of HashMap.get() and when does it occur?"**

**One-line answer:** O(log n) in Java 8+ (O(n) in Java 7) when all keys hash to the same bucket, because all entries pile into one bucket chain or tree.

**Full answer to give in an interview:**

> HashMap's average case is O(1) because a good hash function distributes keys uniformly and each bucket holds only one or a few entries. The worst case occurs when every key produces the same bucket index — all entries end up in one bucket as a single chain or tree.
>
> In Java 7 and earlier, that bucket was a simple linked list. Searching it required traversing every node — O(n). In Java 8+, once a bucket's chain reaches 8 entries (and the table has at least 64 buckets), the chain is converted to a Red-Black tree. A Red-Black tree search is O(log n) — so even with every key colliding, no single lookup can take longer than O(log n). This was specifically a security fix: attackers could previously send crafted HTTP parameters whose keys all hashed to the same bucket, causing O(n²) server-side processing — a hash flood denial-of-service attack.

*Delivery note: mentioning the DoS angle shows you understand the why behind the design decision, not just the what.*

**Gotcha follow-up they'll ask:** *"Does treeification happen immediately when a bin reaches size 8?"*

> No — there is a second condition. If the total table size is less than `MIN_TREEIFY_CAPACITY = 64`, HashMap resizes instead of treeifying. The reasoning: with a small table, a long chain usually means many keys are legitimately hashing to a small number of buckets because there are too few buckets overall. Doubling the table redistributes them better. Treeifying a small table would give a false sense of safety while missing the real fix. Only when the table is at least 64 slots does a long chain indicate a genuine hash quality problem worth addressing with a tree.

---

#### Q2 — Tradeoff Question

**"What are the tradeoffs of setting the load factor to 0.5 vs 0.9 vs the default 0.75?"**

**One-line answer:** Lower load factor means fewer collisions and faster lookups but wastes more memory and triggers more resizes; higher load factor saves memory but increases collisions and slows lookups.

**Full answer to give in an interview:**

> The load factor controls the density of the map — the ratio of entries to buckets at which a resize is triggered. At 0.5, the map resizes when it is half full, so on average each bucket holds about 0.5 entries. Collisions are rare, lookups are fast, but you are paying for twice as many empty bucket slots as you need. Resize also happens earlier and more often, which is an O(n) cost each time.
>
> At 0.9, you pack more entries per bucket on average before resizing. Memory utilisation is better, but collision chains grow longer and lookups degrade. In the absolute worst case, a 0.9-loaded map with a mediocre hash function will have noticeably longer chains.
>
> The default 0.75 was chosen empirically: it sits in a sweet spot where the expected number of entries per bucket under a uniform hash function follows a Poisson distribution with mean 0.75. The Poisson probability of a bucket having 8 or more entries (triggering treeification) at mean 0.75 is roughly 0.00000006 — effectively zero for random data. For a write-heavy cache where memory is tight, I might use 0.85–0.9. For a read-heavy lookup table in a latency-sensitive path, I might drop to 0.5–0.6.

*Delivery note: mentioning Poisson distribution signals depth — but only say it if you can back it up.*

**Gotcha follow-up they'll ask:** *"Why is iterating a large sparse HashMap slow even if it has few entries?"*

> Because the HashMap iterator walks the entire bucket array, not just the occupied buckets. If I create `new HashMap<>(1_000_000)` and insert 3 entries, iterating that map visits 1,000,000 array slots to find those 3 entries. The cost is O(capacity + size), not O(size). This is why you should never over-provision initial capacity if you intend to iterate the map later. If ordered iteration is required, LinkedHashMap is better because its iteration follows a doubly linked list through only the actual entries — O(n) where n is entry count, not capacity.

---

#### Q3 — Design Scenario

**"A security engineer tells you that a public-facing API endpoint parses user-supplied JSON keys into a HashMap, and they are worried about hash flood attacks. What do you do?"**

**One-line answer:** Java 8+ treeification already mitigates to O(log n); additionally enforce key count limits, use ConcurrentHashMap for shared state, and consider alternative data structures for known-hostile inputs.

**Full answer to give in an interview:**

> The hash flood attack works by crafting input keys that all share the same hash bucket, degrading O(1) lookups to O(n) and causing O(n²) total processing cost for a request with n parameters. This was a real exploit — CVE-2011-4461 affected Tomcat and many other JVM frameworks before Java 8.
>
> In Java 8+, treeification at bin size 8 brings the worst case down to O(log n) per lookup. So a 10,000-key attack request, instead of costing O(10,000²) = O(100 million) operations, now costs O(10,000 × log 10,000) ≈ O(130,000) — a 770x improvement. That is the first line of defence and it is already in place.
>
> Additional hardening I would add: first, enforce a maximum key count on incoming JSON at the parsing layer — most legitimate requests have far fewer than 1,000 keys. Second, if the endpoint is extremely sensitive, switch to a data structure that does not have hash-based organisation at all, like a sorted list or a trie for string keys, which have no hash collision surface. Third, monitor per-request CPU time and alert on outliers — a hash flood will show up as a single-threaded CPU spike.

*Delivery note: name the CVE — it shows you know this is a real historical issue, not a theoretical one.*

**Gotcha follow-up they'll ask:** *"Does Java randomise hashCode() to prevent hash flood attacks?"*

> Java's `String.hashCode()` uses a deterministic algorithm — it has not been randomised. Some other JVM language runtimes (Ruby, Python 3.3+) added per-process hash seed randomisation specifically to defeat this attack. Java's chosen mitigation was treeification rather than hash randomisation, partly because randomised hashes break reproducibility and make debugging harder. The practical defence in Java is treeification plus input validation at the application layer.

---

> **Common Mistake — Iterating an oversized sparse map:** Creating `new HashMap<>(largeNumber)` and then iterating it is O(capacity + size), not O(size). A map pre-allocated to 1,000,000 slots but holding 10 entries will iterate 1,000,003 steps. Always size the initial capacity to match actual expected load if iteration is in the hot path.

**Quick Revision (one line):** HashMap is O(1) average / O(log n) worst case (Java 8+) for get/put/remove; iteration is O(capacity + size); load factor 0.75 is empirically optimal; treeification at bin size 8 defends against hash flood DoS; pre-size with `(int)(expected / 0.75) + 1` to eliminate resizes.

---

## Topic 9: LinkedHashMap

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Uber, Airbnb, Bloomberg

---

### The Idea

LinkedHashMap is a HashMap with a memory. Ordinary HashMap is like a bag of marbles — you can find any marble quickly, but the order you put them in is forgotten. LinkedHashMap is like a bag of marbles threaded on a string in the order you added them. You still get O(1) lookup, but you can also walk the string from first to last and recover insertion order exactly.

There is a second, more powerful mode: access order. Every time you touch a marble (read or write), it moves to the end of the string. The marble at the front of the string is always the one you touched least recently. One 12-line subclass override later and you have a fully functional LRU (Least Recently Used) cache — which is why LinkedHashMap appears in almost every LRU cache question in backend interviews.

The overhead versus plain HashMap is modest: two extra pointers per entry (before and after in the doubly linked list) plus two pointers in the map itself (head and tail). Everything else — the bucket array, the hash function, the treeification logic — is inherited unchanged from HashMap.

---

### How It Works

**Extended node structure (pseudocode):**
```
LinkedHashMap.Entry extends HashMap.Node:
  before  → pointer to previous entry in the doubly linked list
  after   → pointer to next entry in the doubly linked list

LinkedHashMap itself:
  head    → oldest entry (LRU end)
  tail    → newest / most recently used entry (MRU end)
  accessOrder → false (insertion order, default) | true (access order)
```

**Two modes:**
```
INSERTION ORDER (accessOrder = false):
  → After put(k1), put(k2), put(k3): iteration visits k1 → k2 → k3
  → Re-inserting k1 via put(k1, newValue) does NOT move k1 in the list
  → Order reflects insertion sequence, not recency of access

ACCESS ORDER (accessOrder = true):
  → After put(k1), put(k2), put(k3): head=k1, tail=k3
  → get(k1) moves k1 to tail: head=k2, tail=k1
  → put(k4, v) adds at tail: head=k2, tail=k4
  → head is always the LEAST recently used entry
```

**LRU cache mechanism (pseudocode):**
```
After every put():
  LinkedHashMap calls removeEldestEntry(head)
  Default implementation: return false  (never evict)
  Override to:  return size() > maxCapacity
    → If true, LinkedHashMap removes head (the LRU entry) automatically
```

**Complexity:**

| Operation | LinkedHashMap | Plain HashMap |
|---|---|---|
| get / put / remove | O(1) average | O(1) average |
| Iteration | O(n) — walks linked list | O(capacity + size) |
| LRU eviction check | O(1) — head pointer | n/a |

**Interview-critical gotcha — accessOrder = true is required for LRU:**

```java
// WRONG — insertion order, NOT access order. This is NOT an LRU cache.
new LinkedHashMap<>(capacity, 0.75f, false);  // false = insertion order

// RIGHT — access order. get() and put() move entries to tail.
new LinkedHashMap<>(capacity, 0.75f, true);   // true = access order
// The third constructor argument is the one interviewers test for.
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"How does LinkedHashMap maintain order, and what is the difference between its two ordering modes?"**

**One-line answer:** LinkedHashMap adds a doubly linked list through all entries; insertion-order mode preserves add sequence, access-order mode moves any accessed entry to the tail so the head is always the least recently used.

**Full answer to give in an interview:**

> LinkedHashMap extends HashMap and adds two extra pointers to each entry: `before` and `after`. These form a doubly linked list that runs through every entry in the map, from a `head` pointer to a `tail` pointer maintained by the map itself. This list is what gives LinkedHashMap its ordered iteration — when you call `entrySet().iterator()`, it walks this linked list rather than the bucket array, so iteration is O(n) where n is entry count, not O(capacity + size) like plain HashMap.
>
> The two modes differ in when the linked list is updated. In insertion-order mode (the default, `accessOrder = false`), the list is only updated on new insertions. Re-inserting an existing key updates its value but leaves its position in the list unchanged — it stays where it was first inserted. In access-order mode (`accessOrder = true`), every `get()`, `put()`, and `getOrDefault()` call moves the accessed entry to the tail. The head always holds the entry that has gone the longest without being touched — the least recently used entry. This is the property that makes access-order LinkedHashMap the natural building block for an LRU cache.

*Delivery note: explicitly state "O(n) where n is entry count, not capacity" — that distinction trips up many candidates and showing you know it earns points.*

**Gotcha follow-up they'll ask:** *"Does re-inserting an existing key change its position in insertion-order mode?"*

> No. In insertion-order mode, `put(existingKey, newValue)` updates the value but does not move the entry in the linked list. The entry stays at its original position — where it was first inserted. This is consistent with the semantics of a Set where an element's identity (position) is fixed at insertion time. Only in access-order mode does any operation on an existing key change its list position.

---

#### Q2 — Tradeoff Question

**"When would you use LinkedHashMap instead of HashMap or TreeMap?"**

**One-line answer:** Use LinkedHashMap when you need O(1) get/put AND predictable iteration order (insertion or LRU access), which neither HashMap (unordered) nor TreeMap (sort-ordered only) provides.

**Full answer to give in an interview:**

> HashMap gives O(1) operations but no guaranteed iteration order — iterating it can return entries in any sequence, and that sequence can change after a resize. TreeMap gives sorted order but at O(log n) cost per operation. LinkedHashMap sits between them: O(1) operations from its HashMap base, plus a choice of ordered iteration at O(n) — following the doubly linked list rather than scanning buckets.
>
> I reach for LinkedHashMap in three scenarios. First, when I need to produce output in the order data was received — for example, building a JSON response where field order should match the order they were added to the map. HashMap would produce arbitrary order. Second, when implementing LRU caching — access-order mode plus a `removeEldestEntry()` override gives me a cache that evicts the least recently used entry automatically, in O(1) per operation. Third, when I need a deterministic test fixture — HashMap iteration order is unstable across JVM versions and after resizes, which makes tests that depend on iteration order fragile.
>
> The cost of LinkedHashMap versus HashMap is two pointer updates per put/get in access-order mode, and two extra pointers of memory per entry. For most use cases, this is negligible.

*Delivery note: the "deterministic test fixture" use case often surprises interviewers — it shows real production experience.*

**Gotcha follow-up they'll ask:** *"Is LinkedHashMap thread-safe?"*

> No. LinkedHashMap inherits HashMap's lack of thread safety. Concurrent modifications can corrupt the doubly linked list, leading to infinite loops or lost updates. For a thread-safe LRU cache, the options are: wrap with `Collections.synchronizedMap()` (coarse lock, simple), use `ConcurrentHashMap` with manual LRU bookkeeping (complex), or use a purpose-built library like Caffeine, which implements an efficient concurrent LRU with near-zero lock contention using a lock-free ring buffer for access recording.

---

#### Q3 — Design Scenario

**"Implement an LRU cache with O(1) get and put. What is your approach and what are the edge cases?"**

**One-line answer:** Extend LinkedHashMap with `accessOrder = true` and override `removeEldestEntry()` to return true when `size() > capacity` — six lines of code, all operations O(1).

**Full answer to give in an interview:**

> The LinkedHashMap-based approach is the cleanest solution in Java. I extend LinkedHashMap, pass `true` for `accessOrder` in the super constructor call, and override `removeEldestEntry()` to return `size() > maxCapacity`. LinkedHashMap calls this hook after every `put()` and automatically removes the head (LRU entry) when the method returns true. `get()` and `put()` are both O(1) average — the linked list update on access is O(1) pointer manipulation.
>
> Edge cases to call out: first, `get()` in access-order mode counts as an access and moves the entry to the tail — this is the desired LRU behaviour, not a bug. Second, `put()` on an existing key also counts as an access and moves it to the tail. Third, this implementation is not thread-safe — for concurrent use I would synchronise externally or use Caffeine. Fourth, the `removeEldestEntry()` hook is called with the eldest entry as an argument — if I need to trigger a side effect on eviction (like persisting the evicted entry), I can do it inside this override.
>
> If the interviewer asks for an implementation without LinkedHashMap, I use HashMap + explicit DoublyLinkedList: the map stores key → node references, the list maintains LRU order. This is more code (40–50 lines) but demonstrates the underlying mechanics.

*Delivery note: always mention the thread-safety caveat proactively — it is almost always the follow-up.*

**Gotcha follow-up they'll ask:** *"What is the time complexity of LinkedHashMap iteration, and how does it differ from plain HashMap iteration?"*

> LinkedHashMap iteration is O(n) where n is the number of entries, because the iterator walks the doubly linked list which only threads through actual entries — empty buckets are never visited. Plain HashMap iteration is O(capacity + size) because the iterator must scan every slot in the bucket array to find occupied ones. If a HashMap was pre-allocated with a large capacity but holds few entries, iterating it is much slower than iterating an equivalently-populated LinkedHashMap. This is a concrete reason to prefer LinkedHashMap in use cases that mix large capacity with frequent full iteration.

---

> **Common Mistake — Forgetting accessOrder = true for LRU:** Creating `new LinkedHashMap<>(cap, 0.75f)` (two-argument constructor, or three-argument with `false`) gives insertion-order, not access-order. `get()` does not move the entry to the tail, so the "LRU" cache evicts by insertion order, not by recency of access. The bug is silent — the cache appears to work but evicts the wrong entries. Always use the three-argument constructor with `true` for LRU semantics.

**Quick Revision (one line):** LinkedHashMap = HashMap + doubly linked list per entry; insertion-order (default) or access-order (`true` third constructor arg); access-order + `removeEldestEntry()` override = LRU cache in ~6 lines; iteration O(n) via linked list (vs O(capacity+size) for HashMap).

---

## Topic 10: TreeMap

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, financial firms

---

### The Idea

Imagine a phone book that keeps every entry alphabetically sorted at all times — not just when you print it, but every time you add or remove a name. TreeMap is exactly that: a map where the keys are always in sorted order. You pay a small price (O(log n) instead of O(1)) but you gain powerful range-query superpowers in return.

Under the hood, TreeMap is backed by a Red-Black tree — a self-balancing binary search tree. Every `put()` and `remove()` performs at most O(log n) comparisons and a constant number of rotations to keep the tree balanced. Natural ordering (via `Comparable`) is used by default; you can supply a `Comparator` for custom ordering.

Because TreeMap implements `NavigableMap`, it answers spatial questions about keys that HashMap cannot: "give me the largest key smaller than X", "give me all keys between A and B", "give me a reverse-order view". These are O(log n) range queries backed by the same tree traversal.

### How It Works

**Inserting a key (pseudocode):**
```
insert(key, value):
  node = root
  while node != null:
    compare key with node.key
    if key < node.key: go left
    if key > node.key: go right
    if key == node.key: update value, return
  insert new RED node at empty position
  rebalance tree (rotations + recoloring) to maintain Red-Black invariants
```

**NavigableMap range methods:**

| Method | Returns | Time |
|--------|---------|------|
| `floorKey(k)` | Greatest key ≤ k | O(log n) |
| `ceilingKey(k)` | Smallest key ≥ k | O(log n) |
| `lowerKey(k)` | Greatest key < k | O(log n) |
| `higherKey(k)` | Smallest key > k | O(log n) |
| `firstKey()` / `lastKey()` | Min / max key | O(log n) |
| `headMap(k)` | Live view of keys < k | O(log n) |
| `tailMap(k)` | Live view of keys ≥ k | O(log n) |
| `subMap(from, to)` | Live view of keys in [from, to) | O(log n) |
| `pollFirstEntry()` / `pollLastEntry()` | Remove and return min / max entry | O(log n) |

**The critical gotcha — subMap/headMap/tailMap return live views:**

```java
TreeMap<Integer, String> map = new TreeMap<>();
map.put(1, "one"); map.put(3, "three"); map.put(5, "five"); map.put(7, "seven");

// subMap returns a LIVE VIEW — changes to the view affect the original map
NavigableMap<Integer, String> range = map.subMap(3, true, 7, true); // [3, 7]
range.put(4, "four"); // this ALSO appears in map
System.out.println(map.containsKey(4)); // true — not a copy!
```

**TreeMap vs HashMap:**

| Property | TreeMap | HashMap |
|----------|---------|---------|
| Ordering | Sorted by key | No guaranteed order |
| `get()` / `put()` | O(log n) | O(1) average |
| Null keys | Not allowed (throws NPE) | 1 null key allowed |
| Range queries | Full NavigableMap API | Not supported |
| Use when | You need sorted order or range queries | You need fast lookup only |

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"What is the time complexity of `get()` in TreeMap vs HashMap, and why?"**

**One-line answer:** TreeMap is O(log n) because it traverses a balanced binary search tree; HashMap is O(1) average because it uses a hash function to go directly to the bucket.

**Full answer to give in an interview:**
> In a TreeMap, every lookup walks down a Red-Black tree — a self-balancing binary search tree. At each node I compare the target key with the current node's key and go left or right. Since the tree stays balanced, the height is always O(log n), so `get()` is O(log n). In a HashMap, I hash the key to get a bucket index directly — that's O(1) on average, though it degrades to O(log n) in the worst case when many keys hash to the same bucket and that bucket's linked list gets converted to a tree (Java 8+ treeification at threshold 8). I choose TreeMap when I need sorted iteration or range queries, and HashMap when I only need fast key lookup.

*Lead with the tree-walk intuition, then contrast with the hash-jump. The treeification mention shows Java 8 depth.*

**Gotcha follow-up they'll ask:** *"When exactly does HashMap degrade to O(log n)?"*
> When a single bucket accumulates 8 or more entries (the TREEIFY_THRESHOLD), HashMap converts that bucket's linked list into a red-black tree. Within that bucket, lookup becomes O(log n). Globally, the average is still O(1) if load factor is kept below 0.75 and the hash function distributes keys well.

---

#### Q2 — Tradeoff Question

**"When would you use TreeMap instead of HashMap?"**

**One-line answer:** Use TreeMap when you need keys in sorted order or need to answer range queries like "all keys between A and B."

**Full answer to give in an interview:**
> I reach for TreeMap in three scenarios. First, sorted iteration — if I need to process keys in ascending or descending order, TreeMap iterates in sorted order naturally; with HashMap I'd have to copy and sort. Second, range queries — TreeMap's NavigableMap API gives me `subMap(from, to)`, `headMap(k)`, `tailMap(k)`, `floorKey(k)`, `ceilingKey(k)` all in O(log n); there's no equivalent in HashMap. Third, min/max operations — `firstKey()` and `pollFirstEntry()` give me the minimum in O(log n) which is useful for priority-like use cases. The tradeoff is speed: TreeMap's O(log n) per operation is slower than HashMap's O(1) average, so if I only need fast lookup and don't care about order, HashMap wins every time.

*A concrete example lands well here: "For a financial system tracking trades by timestamp, TreeMap lets me do `subMap(startTime, endTime)` to pull all trades in a window — that's a natural fit."*

**Gotcha follow-up they'll ask:** *"Can TreeMap replace a sorted list for range queries?"*
> It depends. TreeMap gives O(log n) range queries by key but only stores one value per key. If I need multiple entries per key (e.g., multiple trades at the same millisecond), I'd use `TreeMap<Long, List<Trade>>`. For purely positional range queries (give me elements at indices 3–7), a sorted list or segment tree is more appropriate.

---

#### Q3 — Design Scenario

**"Design a leaderboard that supports: add a score, remove a score, and find the rank of a given score."**

**One-line answer:** Use a `TreeMap<Integer, Integer>` mapping score to count; rank is computed by summing counts of all scores greater than the target using `tailMap()`.

**Full answer to give in an interview:**
> I'd use a `TreeMap<Integer, Integer>` where the key is the score and the value is the number of players with that score. To add a score I call `merge(score, 1, Integer::sum)` — atomic and concise. To remove a score I decrement the count and remove the entry if it hits zero. To find rank, I call `tailMap(score, false)` to get all scores strictly greater than the target, then sum their counts — that gives the number of players ahead of this score. The rank of this score is that sum plus 1. All operations are O(log n) per key except the rank query which is O(k log n) where k is the number of distinct scores above the target. If I need O(log n) rank queries, I'd use a Binary Indexed Tree (Fenwick tree) or an Order-Statistic Tree instead.

*This scenario tests NavigableMap API knowledge and shows you can reason about complexity tradeoffs.*

**Gotcha follow-up they'll ask:** *"What if two players have the same score — do they share the same rank?"*
> Yes, and that's exactly why I stored counts as values rather than individual entries. Players with the same score share the same rank. The next distinct rank is `(number of players with the same or higher score) + 1`. My `tailMap(score, false)` approach already handles this correctly because it excludes the current score from the count of players ahead.

---

> **Common Mistake — Treating subMap/headMap as copies:** These methods return live views backed by the original TreeMap. Adding or removing from the view modifies the original map, and adding a key outside the view's range throws `IllegalArgumentException`. Always document whether a returned view is live or a snapshot.

**Quick Revision (one line):** TreeMap = Red-Black tree, O(log n) all ops, sorted keys, no null keys, NavigableMap range queries (floorKey/ceilingKey/subMap/headMap), range views are live — not copies.

---

## Topic 11: ConcurrentHashMap

**Difficulty:** Hard | **Frequency:** Very High | **Companies:** Google, Amazon, Netflix, Stripe, Goldman Sachs

---

### The Idea

Imagine a large warehouse divided into 100 aisles. A naive thread-safe warehouse puts one lock on the front door — only one worker can enter at a time. ConcurrentHashMap is smarter: it locks only the specific aisle a worker is going to. Workers in different aisles operate in parallel; only workers who need the exact same aisle must wait for each other.

In Java 8+, ConcurrentHashMap replaced the Java 7 segment-based design (16 `ReentrantLock` segments) with per-bucket locking using `synchronized` blocks. Empty bucket insertions are done with a lockless CAS (Compare-And-Swap) operation — no blocking at all. Reads (`get()`) are entirely lock-free: they read `volatile` fields and never acquire any lock.

The result is a map that scales nearly linearly with CPU cores and handles hundreds of thousands of concurrent operations per second — while remaining completely safe without external synchronization.

### How It Works

**`put()` — two cases (pseudocode):**
```
put(key, value):
  hash = spread(key.hashCode())   // spread bits to reduce collisions
  bucket = table[hash % length]

  if bucket is empty:
    CAS(table[index], null, newNode)  // no lock — atomic hardware instruction
    if CAS succeeds: done
    if CAS fails: another thread raced us — retry loop

  else:
    synchronized(bucket.head):        // lock only this bucket's head node
      walk bucket chain / tree
      insert or update node
```

**`get()` — lock-free (pseudocode):**
```
get(key):
  bucket = table[hash % length]     // volatile read — always sees latest write
  walk bucket chain comparing keys  // all node.val fields are volatile
  return value or null
```

**Why null is not allowed:**
```java
// In single-threaded HashMap, you can disambiguate:
if (map.containsKey(key)) { /* key exists with null value */ }
else                       { /* key absent */ }

// In concurrent code this is a TOCTOU (Time-of-Check-Time-of-Use) race:
// Thread A calls containsKey(key) → false
// Thread B inserts key=null
// Thread A calls put(key, computeValue()) → silently overwrites Thread B's entry
// Banning null eliminates this entire class of bugs.
```

**Atomic compound operations (the right way to mutate):**

| Operation | What it does | Wrong alternative |
|-----------|-------------|-------------------|
| `putIfAbsent(k, v)` | Insert only if key absent | `if (!map.containsKey(k)) map.put(k, v)` — race |
| `computeIfAbsent(k, fn)` | Get or compute-and-insert | same race as above |
| `replace(k, oldV, newV)` | Conditional update | `get()` then `put()` — race |
| `merge(k, v, fn)` | Merge with existing value | `get()` + compute + `put()` — race |
| `remove(k, v)` | Conditional remove | `get()` then `remove()` — race |

**Size counting:**
ConcurrentHashMap maintains count using a distributed counter: `baseCount` (a `volatile long`) plus an array of `CounterCell` objects (Striped64 / LongAdder technique). Under contention, threads increment different cells, eliminating the hot-spot of a single shared counter. `size()` sums all cells — it's a best-effort snapshot, not a guaranteed exact count. Use `mappingCount()` for `long` precision on large maps.

**The single most interview-critical gotcha:**
```java
// WRONG — not atomic, race condition between get and put
if (!map.containsKey("key")) {
    map.put("key", new AtomicInteger(0));
}

// RIGHT — computeIfAbsent is atomic
map.computeIfAbsent("key", k -> new AtomicInteger(0)).incrementAndGet();
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"How does ConcurrentHashMap achieve thread safety without locking the entire map?"**

**One-line answer:** It uses per-bucket locking with `synchronized` on individual bucket heads, plus lockless CAS for inserting into empty buckets, so only threads touching the same bucket ever contend.

**Full answer to give in an interview:**
> Java 8 ConcurrentHashMap splits its internal array into independent buckets. When two threads write to different buckets, they never interfere — each acquires the lock on its own bucket head and they run in parallel. For an empty bucket, no lock is needed at all: the insertion uses CAS (Compare-And-Swap), a single atomic CPU instruction that sets the bucket's reference from null to the new node — either it wins or it retries. Reads are entirely lock-free because every node's value field and the table array itself are declared `volatile`, so a reading thread always sees the latest committed write without any lock. This contrasts sharply with `Hashtable`, which puts `synchronized` on the entire method — all threads, regardless of which key they touch, must take turns.

*The key phrase to say aloud: "per-bucket locking + CAS for empty buckets + volatile reads = lock-free reads and fine-grained writes."*

**Gotcha follow-up they'll ask:** *"What was different in Java 7?"*
> Java 7 used `Segment`-based locking. The array was divided into 16 segments, each protected by its own `ReentrantLock`. This allowed up to 16 concurrent writers. Java 8 dropped segments entirely and moved to per-bucket `synchronized` blocks, which scales to n concurrent writers for n buckets — a massive improvement. Mentioning this shows you know the evolution.

---

#### Q2 — Tradeoff Question

**"Why does ConcurrentHashMap not allow null keys or values?"**

**One-line answer:** Because in concurrent code, you cannot safely distinguish "key absent" from "key present with null value" without a check-then-act race condition.

**Full answer to give in an interview:**
> In a single-threaded HashMap, if `map.get(key)` returns null, you can immediately call `map.containsKey(key)` to resolve the ambiguity — the state didn't change between the two calls. In concurrent code, another thread can insert or remove the key between your two calls. This is a TOCTOU bug: Time-of-Check (containsKey) to Time-of-Use (acting on the result) is not atomic. Doug Lea, who designed ConcurrentHashMap, explicitly chose to ban null to eliminate this entire class of bugs. If you need a "null-like" sentinel in a ConcurrentHashMap, use a static `ABSENT` object instead of null. This also applies to values — a null value would make `get()` returns indistinguishable.

*Interviewers love this answer because it shows you understand not just what the rule is, but why.*

**Gotcha follow-up they'll ask:** *"Can you store a null-like sentinel in ConcurrentHashMap instead of null?"*
> Yes. A common pattern is `static final Object ABSENT = new Object()` — you store this as the value and check `value == ABSENT` instead of `value == null`. This is explicit and safe. Alternatively, use `Optional<V>` as the value type, though that adds allocation overhead.

---

#### Q3 — Design Scenario

**"Design a concurrent request counter per client ID that is both fast and correct under high concurrency."**

**One-line answer:** Use `ConcurrentHashMap<String, AtomicInteger>` with `computeIfAbsent` for initialization and `AtomicInteger.incrementAndGet()` for counting.

**Full answer to give in an interview:**
> I'd use a `ConcurrentHashMap<String, AtomicInteger>` where each key is a client ID and the value is an `AtomicInteger` counter. To increment the counter for a client: `map.computeIfAbsent(clientId, k -> new AtomicInteger(0)).incrementAndGet()`. The `computeIfAbsent` is atomic — if two threads race to initialize the same client's counter, only one wins and both end up incrementing the same AtomicInteger. The `incrementAndGet()` is a CAS-based atomic increment, so no further locking is needed. This design scales to hundreds of threads because: (1) threads on different client IDs never contend at the map level, (2) threads on the same client ID contend only at the AtomicInteger level, not the map level. For very high-frequency counters on the same key, I'd upgrade to `LongAdder` instead of `AtomicInteger` to further reduce CAS contention.

*Explicitly naming the two levels of concurrency (map-level and counter-level) shows architectural depth.*

**Gotcha follow-up they'll ask:** *"Why not use `Collections.synchronizedMap(new HashMap<>())` instead?"*
> `synchronizedMap` wraps every method in a `synchronized` block on the map object — serializing all access. Under high concurrency this becomes a bottleneck: all threads queue for the single lock even if they're accessing unrelated keys. ConcurrentHashMap's per-bucket locking means threads on different keys run in parallel. Additionally, `synchronizedMap` does not provide the atomic compound operations (`computeIfAbsent`, `merge`, `putIfAbsent`) that prevent TOCTOU races — you'd have to add external synchronization anyway.

---

> **Common Mistake — Treating get+put as atomic:** Writing `if (!map.containsKey(k)) { map.put(k, v); }` with a ConcurrentHashMap is still a race condition — another thread can insert between the check and the put. Always use `putIfAbsent()` or `computeIfAbsent()`. This is one of the most common concurrent bugs in production Java code.

**Quick Revision (one line):** ConcurrentHashMap = per-bucket `synchronized` + CAS for empty buckets + lock-free `volatile` reads; no null keys/values (TOCTOU); `size()` approximate; use `computeIfAbsent`/`merge`/`putIfAbsent` for atomic compound ops.

---

## Topic 12: HashMap vs Hashtable vs ConcurrentHashMap

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Nearly every Java interview

---

### The Idea

These three maps solve the same problem — key-value storage — but were written in three different eras with three different concurrency philosophies. Hashtable (Java 1.0) solved thread safety with a sledgehammer: lock the whole thing. HashMap (Java 1.2) threw out the lock entirely for single-threaded speed. ConcurrentHashMap (Java 5, redesigned Java 8) applied surgical locking at the bucket level, combining safety with scalability.

Knowing which to choose — and why Hashtable is dead — is a standard Java interview question at every level.

### How It Works

**Full comparison table:**

| Feature | HashMap | Hashtable | ConcurrentHashMap |
|---------|---------|-----------|-------------------|
| Thread safety | Not thread-safe | Thread-safe (full method lock) | Thread-safe (per-bucket lock) |
| Null keys | 1 null key allowed | Not allowed | Not allowed |
| Null values | Multiple null values | Not allowed | Not allowed |
| Performance (single-threaded) | Fast | Slow (unnecessary synchronization) | Slightly slower than HashMap |
| Performance (multi-threaded) | Unsafe (data corruption) | Very slow (full lock, serialized) | Fast (fine-grained locking) |
| Iterator | Fail-fast | Fail-fast (`Enumeration` is not) | Weakly consistent |
| Inheritance | Extends `AbstractMap` | Extends `Dictionary` (legacy) | Extends `AbstractMap` |
| Key ordering | No guarantee | No guarantee | No guarantee |
| Introduced | Java 1.2 | Java 1.0 (legacy) | Java 5 (redesigned Java 8) |
| Atomic ops | No | No | Yes (`putIfAbsent`, `compute`, `merge`) |
| Bucket treeification (Java 8) | Yes | No | Yes |

**Decision rule (one sentence each):**
- Single-threaded code → **HashMap**
- Multi-threaded code → **ConcurrentHashMap**
- Legacy code you're maintaining → understand Hashtable, but never write new Hashtable code

**The critical Java code gotcha — iterator behavior differs:**
```java
// Fail-fast: throws ConcurrentModificationException if map is modified during iteration
HashMap<String, Integer> map = new HashMap<>();
map.put("a", 1); map.put("b", 2);
for (String key : map.keySet()) {
    map.remove(key); // throws ConcurrentModificationException on second iteration
}

// Weakly consistent: ConcurrentHashMap iterator does NOT throw; it may or may not
// reflect modifications made after the iterator was created
ConcurrentHashMap<String, Integer> chm = new ConcurrentHashMap<>();
chm.put("a", 1); chm.put("b", 2);
for (String key : chm.keySet()) {
    chm.remove(key); // safe — no exception, but may see some removed entries
}
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"What is the difference between HashMap, Hashtable, and ConcurrentHashMap?"**

**One-line answer:** HashMap is not thread-safe; Hashtable is thread-safe with a full-map lock (legacy, avoid it); ConcurrentHashMap is thread-safe with per-bucket locking and is the right choice for concurrent code.

**Full answer to give in an interview:**
> HashMap has no synchronization — it's the fastest option in single-threaded code but will produce data corruption (lost updates, infinite loops in rare cases) under concurrent access. Hashtable was Java 1.0's answer: every method is `synchronized` on `this`, making it thread-safe but serializing all access through a single lock. Under any meaningful concurrency, Hashtable becomes a bottleneck. ConcurrentHashMap, introduced in Java 5 and significantly redesigned in Java 8, locks only at the individual bucket level and uses CAS for empty-bucket insertions. Reads are entirely lock-free. This means threads on different keys never contend. Hashtable is a legacy class that extends the legacy `Dictionary` class — it has no place in new code. If I need thread safety, I always use ConcurrentHashMap.

*Emphasizing "Hashtable is legacy, never use in new code" scores points — interviewers want to hear you know the history.*

**Gotcha follow-up they'll ask:** *"What about `Collections.synchronizedMap()`?"*
> `Collections.synchronizedMap()` wraps a HashMap and synchronizes every method on the wrapper object — functionally similar to Hashtable but slightly more modern. It still serializes all access through one lock, so it suffers the same scalability problems. Additionally, compound operations like iterate-and-remove are still not atomic; you must manually synchronize on the map during iteration. ConcurrentHashMap is superior in almost all cases.

---

#### Q2 — Tradeoff Question

**"Why is Hashtable considered legacy and when would you still encounter it?"**

**One-line answer:** Hashtable extends the obsolete `Dictionary` class, predates the Collections framework, has no atomic compound operations, and is outperformed by ConcurrentHashMap in every concurrent scenario — it exists only in old codebases.

**Full answer to give in an interview:**
> Hashtable was introduced in Java 1.0 before the Collections framework existed in Java 1.2. It extends `Dictionary`, an abstract class that is itself considered obsolete. Its thread-safety mechanism — synchronizing every public method on `this` — is the coarsest possible approach: every read and write, even unrelated ones, waits for the same lock. It doesn't allow null keys or values. It provides no atomic compound operations like `putIfAbsent` or `computeIfAbsent`, which means callers must add external synchronization anyway to avoid race conditions. In practice, I encounter it in legacy enterprise codebases, sometimes in Properties (which extends Hashtable), and in old JDBC code. My approach when I find it: if the code is in a concurrent context, replace with ConcurrentHashMap; if single-threaded, replace with HashMap.

*Mentioning `Properties extends Hashtable` shows real-world Java knowledge.*

**Gotcha follow-up they'll ask:** *"Does Properties inherit Hashtable's thread safety?"*
> Yes, `Properties` extends `Hashtable` so all its methods are synchronized. However, the recommended post-Java 9 approach is to use `Properties.load()` to populate it once at startup (under synchronization if needed) and then treat it as effectively immutable. Writing to a `Properties` object from multiple threads using the inherited Hashtable methods is technically safe but still slow.

---

#### Q3 — Design Scenario

**"A legacy service uses Hashtable for a session cache. You're asked to improve its performance under high read concurrency. What do you do?"**

**One-line answer:** Replace Hashtable with ConcurrentHashMap — reads become lock-free, writes use per-bucket locking, and throughput scales with thread count.

**Full answer to give in an interview:**
> First, I'd assess the access pattern: if reads vastly outnumber writes (typical for a session cache), the Hashtable's synchronized reads are particularly wasteful since every read acquires the global lock. I'd replace it with `ConcurrentHashMap` — reads (`get()`) become completely lock-free because they read `volatile` fields without acquiring any lock. Concurrent reads in different sessions never contend at all. Writes lock only the specific bucket containing that session's key, so two writes to different sessions also don't contend. I'd also check for any compound operations: any `containsKey()` + `put()` patterns must be rewritten as `putIfAbsent()` or `computeIfAbsent()` to remain correct without external locks. Finally, if session values are objects that are updated in place, I'd consider whether those updates also need to be thread-safe — ConcurrentHashMap protects the map structure, not the value objects themselves.

*The last sentence — about value object safety — shows you think beyond the map itself.*

**Gotcha follow-up they'll ask:** *"What if you need read-write isolation — readers should never see a partial write?"*
> ConcurrentHashMap's `volatile` writes guarantee that once a `put()` completes, any subsequent `get()` on that key sees the new value. However, it does not provide snapshot isolation across multiple keys. If I need to update several keys atomically and have readers see a consistent view, I'd need an explicit lock around the multi-key operation, or consider a different data structure like a copy-on-write map or a transactional store.

---

> **Common Mistake — Using Hashtable in new code:** Using `new Hashtable<>()` in any code written after Java 5 is a red flag in code review. It signals unfamiliarity with the Collections framework. ConcurrentHashMap is strictly superior for concurrent use; HashMap is strictly superior for single-threaded use. Hashtable has no niche in modern Java.

**Quick Revision (one line):** HashMap = fast, not thread-safe; Hashtable = legacy, full-lock, avoid; ConcurrentHashMap = per-bucket lock + lock-free reads + atomic ops — always prefer over Hashtable.

---

## Topic 13: PriorityQueue

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Facebook, Bloomberg

---

### The Idea

Imagine a hospital emergency room where patients aren't served in arrival order but by severity of condition. The sickest patient is always treated first, regardless of when they arrived. A PriorityQueue is exactly this: a collection where the "most important" element is always at the front, and "importance" is defined by natural ordering or a custom Comparator.

Internally it uses a min-heap — a complete binary tree stored as a flat array, where every parent is smaller than its children. The minimum element is always at index 0 (the root). You can't iterate a PriorityQueue in sorted order, but you can always `poll()` the minimum in O(log n), and that's the only guarantee it makes about ordering.

The heap-as-array representation is elegant: for any node at index `i`, its parent is at `(i-1)/2`, its left child is at `2*i+1`, and its right child is at `2*i+2`. No pointers needed — the structure is implicit in the indices.

### How It Works

**Heap array layout:**
```
Array:  [1, 3, 2, 7, 5, 8, 4]
Index:   0  1  2  3  4  5  6

Tree:
         1          (index 0)
       /   \
      3     2       (indices 1, 2)
     / \   / \
    7   5 8   4     (indices 3, 4, 5, 6)
```

**`add(e)` — O(log n) — sift up:**
```
add(element):
  place element at end of array (index = size)
  size++
  sift_up(size - 1):
    while index > 0:
      parent = (index - 1) / 2
      if element < array[parent]:
        swap(array[index], array[parent])
        index = parent
      else: break
```

**`poll()` — O(log n) — sift down:**
```
poll():
  result = array[0]        // save minimum
  array[0] = array[size-1] // move last element to root
  size--
  sift_down(0):
    while true:
      smallest = index
      left = 2*index + 1; right = 2*index + 2
      if left < size and array[left] < array[smallest]: smallest = left
      if right < size and array[right] < array[smallest]: smallest = right
      if smallest == index: break
      swap(array[index], array[smallest])
      index = smallest
  return result
```

**`peek()` — O(1):** Just return `array[0]`.

**Complexity summary:**

| Operation | Time | Why |
|-----------|------|-----|
| `add()` / `offer()` | O(log n) | Sift up: at most tree height hops |
| `poll()` | O(log n) | Sift down: at most tree height hops |
| `peek()` | O(1) | Root is always at index 0 |
| Build from collection | O(n) | Heapify bottom-up (not n × add) |
| `contains()` / `remove(obj)` | O(n) | No index, must scan entire array |

**The critical gotcha — max-heap requires a Comparator:**
```java
// Min-heap (default) — smallest element polled first
PriorityQueue<Integer> minHeap = new PriorityQueue<>();
minHeap.addAll(List.of(5, 1, 3, 2));
System.out.println(minHeap.poll()); // 1

// Max-heap — largest element polled first
// WRONG for custom objects: don't negate compareTo, use Comparator.reverseOrder()
PriorityQueue<Integer> maxHeap = new PriorityQueue<>(Comparator.reverseOrder());
maxHeap.addAll(List.of(5, 1, 3, 2));
System.out.println(maxHeap.poll()); // 5

// Custom object: always provide explicit Comparator
PriorityQueue<int[]> dijkstra = new PriorityQueue<>(Comparator.comparingInt(a -> a[0]));
dijkstra.offer(new int[]{4, 1}); // [distance=4, node=1]
dijkstra.offer(new int[]{0, 0}); // [distance=0, node=0]
dijkstra.offer(new int[]{2, 2}); // [distance=2, node=2]
System.out.println(dijkstra.poll()[1]); // node 0 (smallest distance)
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"Why is `poll()` O(log n) but `peek()` O(1) in PriorityQueue?"**

**One-line answer:** `peek()` just reads the root at index 0; `poll()` removes the root and must restore the heap property by sifting the replacement element down through O(log n) levels.

**Full answer to give in an interview:**
> PriorityQueue is backed by a min-heap stored as an array. The minimum element is always at index 0, so `peek()` is a single array access — O(1). `poll()` is harder: after removing the root, I need to restore the heap property. I take the last element in the array, place it at the root (index 0), and then "sift it down" — compare it with its two children, swap with the smaller child if it's larger, and repeat until the heap property holds or I reach a leaf. The heap height is O(log n), so the sift-down makes at most O(log n) comparisons and swaps. The tree height is what makes it logarithmic, not some incidental complexity.

*The phrase "sift down" and the explicit O(log n) = tree height connection are what interviewers want to hear.*

**Gotcha follow-up they'll ask:** *"What is the complexity of building a PriorityQueue from a collection of n elements?"*
> If you add n elements one by one, each `add()` is O(log n) so total is O(n log n). But Java's `PriorityQueue(Collection)` constructor uses the heapify algorithm — it starts from the last non-leaf node and calls sift-down on each node upward to the root. The mathematical analysis shows this is O(n) total (most nodes at the bottom of the tree do almost no work). So bulk construction via the constructor is O(n), which is better than n individual adds.

---

#### Q2 — Tradeoff Question

**"How would you implement a max-heap using PriorityQueue in Java, and what are the pitfalls?"**

**One-line answer:** Pass `Comparator.reverseOrder()` to the constructor for natural-ordered types; for custom objects, write a Comparator that reverses the desired ordering.

**Full answer to give in an interview:**
> Java's PriorityQueue is a min-heap by default — the smallest element (by natural order or Comparator) is at the head. To make a max-heap for integers, I pass `Comparator.reverseOrder()`: `new PriorityQueue<>(Comparator.reverseOrder())`. For custom objects, I write a Comparator that sorts in the direction I want polled first — "highest priority number" means `Comparator.comparingInt(Task::priority).reversed()`. The main pitfall I've seen in interviews is negating the key: `new PriorityQueue<>((a, b) -> b - a)` — this works for small integers but overflows for large values (Integer.MIN_VALUE - 1 wraps). Always use `Integer.compare(b, a)` or `Comparator.reverseOrder()` instead of subtraction. The second pitfall is forgetting to provide any Comparator for custom objects that don't implement `Comparable` — the queue will throw `ClassCastException` at runtime when the second element is inserted.

*The integer-subtraction overflow gotcha is a classic interview trap — naming it proactively impresses.*

**Gotcha follow-up they'll ask:** *"Can you use a PriorityQueue to find the Kth largest element in an array?"*
> Yes, the optimal approach is a min-heap of size K. Iterate through all elements: for each element, add it to the heap. If the heap size exceeds K, poll the minimum. After processing all elements, the heap contains the K largest elements and `peek()` gives the Kth largest. Time complexity is O(n log K) — much better than O(n log n) sorting for small K. Space is O(K). The code: `PriorityQueue<Integer> heap = new PriorityQueue<>()` (min-heap, size K). For each element: `heap.offer(elem); if (heap.size() > k) heap.poll();`. Return `heap.peek()`.

---

#### Q3 — Design Scenario

**"Design a task scheduler that processes tasks in priority order. Multiple threads add tasks; one thread processes them."**

**One-line answer:** Use `PriorityBlockingQueue<Task>` — it's a thread-safe min-heap with blocking `take()` that suspends the consumer thread when the queue is empty.

**Full answer to give in an interview:**
> `PriorityQueue` is not thread-safe — using it from multiple threads without external locking will corrupt the heap structure. For this scenario I'd use `PriorityBlockingQueue<Task>` from `java.util.concurrent`. It wraps a min-heap with a `ReentrantLock` and a `Condition` for blocking. Producer threads call `offer(task)` — this acquires the lock, inserts into the heap, and signals any waiting consumer. The consumer thread calls `take()` — this acquires the lock, and if the queue is empty, it suspends on the condition until a producer signals it. Tasks need to implement `Comparable<Task>` or I supply a `Comparator` to the constructor. One thing to watch: `PriorityBlockingQueue` is unbounded — there's no capacity limit, so a slow consumer with fast producers can cause memory pressure. If I need a bounded queue, I'd use a `LinkedBlockingQueue` with a separate comparator-based priority mechanism, or a `DelayQueue` if tasks have scheduled execution times.

*Naming `PriorityBlockingQueue` specifically and distinguishing it from `PriorityQueue` is the answer interviewers are fishing for.*

**Gotcha follow-up they'll ask:** *"Does `PriorityBlockingQueue` guarantee strict priority ordering when multiple threads poll concurrently?"*
> No. Under concurrent polling, two threads can both acquire the lock in sequence and each polls the current minimum at that moment. But between the two polls, the heap may change (another producer inserted a higher-priority task). So each individual `take()` or `poll()` returns the current minimum, but across concurrent consumers there's no global guarantee that elements are processed in strict priority order. For strict priority processing, use a single consumer thread (or serialize processing externally).

---

> **Common Mistake — Iterating PriorityQueue and expecting sorted output:** A `for (int x : pq)` loop does NOT iterate in heap/sorted order. The iterator traverses the backing array in array order, not priority order. Only repeated `poll()` calls drain the queue in priority order. This catches candidates off guard in whiteboard problems — always `poll()` in a loop if you need sorted output.

**Quick Revision (one line):** PriorityQueue = min-heap array, `peek()` O(1), `add()`/`poll()` O(log n), build from collection O(n); no null, not thread-safe (use PriorityBlockingQueue); iteration NOT sorted — only repeated `poll()` is sorted; max-heap via `Comparator.reverseOrder()`.

---

## Topic 14: ArrayDeque

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Microsoft

---

### The Idea

Imagine a physical queue at a coffee shop — people join at one end and leave at the other. Now imagine a fancier version: you can also jump to the front, or leave from either end. That's a **deque** (double-ended queue). `ArrayDeque` is Java's high-performance implementation of that structure.

Most Java developers reach for `Stack` or `LinkedList` when they need stack or queue behaviour. Both work, but both carry hidden costs. `Stack` was built in the early days of Java and wraps a synchronized `Vector` — every push and pop acquires a lock even when you're on a single thread. `LinkedList` allocates a separate heap object for every element, which fragments memory and slows down the CPU's cache.

`ArrayDeque` solves both problems. It is a plain, unsynchronized circular array that gives you O(1) add and remove at both ends, with no per-element allocation. It is the modern default for both stack and queue use cases.

---

### How It Works

**Internal circular buffer:**

```
FIELDS:
  elements[]   — the backing Object array (always a power of 2 in length)
  head         — index of the frontmost element
  tail         — index where the next addLast will write (one past the end)
```

Elements do not shift when you add or remove. Instead, `head` and `tail` pointers move around the array using a bitmask wrap:

```
addFirst(e):
  head = (head - 1) & (elements.length - 1)   // move head backwards, wrapping
  elements[head] = e

addLast(e):
  elements[tail] = e
  tail = (tail + 1) & (elements.length - 1)   // move tail forwards, wrapping

pollFirst():
  e = elements[head]
  elements[head] = null                        // let GC collect it
  head = (head + 1) & (elements.length - 1)
  return e

pollLast():
  tail = (tail - 1) & (elements.length - 1)
  e = elements[tail]
  elements[tail] = null
  return e
```

The array length is always a power of 2 so the bitmask trick works. When `head == tail` (full), the array doubles in size and elements are copied into a fresh contiguous layout.

**Why faster than LinkedList as a queue:**

| Factor | ArrayDeque | LinkedList |
|---|---|---|
| Memory per element | Array slot (one pointer) | Node object: data + two pointers |
| Heap allocations | None for add | One `new Node()` per element |
| CPU cache behaviour | Sequential array reads → cache-friendly | Node pointers scattered → cache misses |
| GC pressure | Low | High (many short-lived Node objects) |

**Why faster than Stack:**

`java.util.Stack` extends `Vector`, which marks every method `synchronized`. `ArrayDeque` has no synchronization — zero lock overhead on the happy path.

**The single most interview-critical gotcha:**

```java
// ArrayDeque does NOT allow null elements
Deque<String> d = new ArrayDeque<>();
d.push(null);   // throws NullPointerException
```

This matters because `null` is used internally as a sentinel to detect empty slots after a `poll()`. If you need to store nulls, use `LinkedList` instead.

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check
**"Why should you prefer ArrayDeque over java.util.Stack?"**

**One-line answer:** `Stack` is a legacy class that inherits synchronization from `Vector`, adding lock overhead even on single-threaded code; `ArrayDeque` is unsynchronized and significantly faster.

**Full answer to give in an interview:**

> "I'd always prefer `ArrayDeque` over `java.util.Stack` in new code. The reason is that `Stack` extends `Vector`, which was Java's original resizable array from the mid-90s. Every method on `Vector` — including push, pop, and peek — is marked `synchronized`, which means each call acquires and releases a monitor lock. In single-threaded code, that lock is never contended, but the JVM still has to execute the lock/unlock instructions on every operation. That's wasted work.
>
> `ArrayDeque` has no synchronization at all. It's a plain circular array with `head` and `tail` pointers. Push, pop, and peek are just array index reads/writes with a bitmask wrap — they're O(1) and branch-free on the hot path.
>
> There's also a design smell: `Stack` inherits `Vector`'s random-access methods like `get(int index)` and `add(int index, E element)`, which make no conceptual sense on a stack. `ArrayDeque` implements `Deque`, which only exposes stack- and queue-appropriate methods, so the API matches the intent."

*Say this over about 40 seconds. The interviewer will nod when they've heard enough — stop there and wait.*

**Gotcha follow-up they'll ask:** *"So how do you get a thread-safe stack in Java if ArrayDeque isn't synchronized?"*

> "You wouldn't wrap `ArrayDeque` yourself — you'd reach for the concurrent collections. `Deque<T> deque = new ConcurrentLinkedDeque<>()` gives you a lock-free thread-safe deque. Or, in the context of producer/consumer, you'd use `LinkedBlockingDeque` which blocks on empty/full. If the use case is within a single thread — which is most stack use cases — `ArrayDeque` is correct as-is."

---

#### Q2 — Tradeoff Question
**"When would you still choose LinkedList over ArrayDeque as a queue?"**

**One-line answer:** When you need to store `null` elements, or when you require guaranteed O(1) worst-case (not amortized) for every individual operation.

**Full answer to give in an interview:**

> "In practice, `ArrayDeque` wins almost every head-to-head comparison with `LinkedList` for queue or stack use. But there are two narrow cases where `LinkedList` is the right choice.
>
> First, null elements. `ArrayDeque` uses `null` as a sentinel internally to detect empty slots, so it throws `NullPointerException` if you try to add a null. `LinkedList` accepts nulls — the null lives inside a `Node` wrapper, so there's no ambiguity.
>
> Second, worst-case latency. `ArrayDeque` gives amortized O(1) for add — meaning most adds are instant, but periodically the array fills up and triggers a resize: allocate a new array twice the size, copy all elements across, then do the add. That one operation is O(n). For the vast majority of applications this average is fine. But in a latency-sensitive real-time system — think high-frequency trading or a game engine's event loop — you cannot afford occasional O(n) spikes. `LinkedList` gives you true O(1) per operation because it allocates a new node per element; there's never a bulk resize."

*This is a nuanced answer — the interviewer is checking whether you know the amortized vs. worst-case distinction. State it clearly.*

**Gotcha follow-up they'll ask:** *"Does ArrayDeque implement the Stack interface?"*

> "No — and that's intentional. There is no `Stack` interface in Java's collections framework; `java.util.Stack` is a class. `ArrayDeque` implements `Deque`, which has `push()`, `pop()`, and `peek()` methods that mirror stack behaviour exactly. The Javadoc for `Deque` explicitly recommends using it in preference to the `Stack` class."

---

#### Q3 — Design Scenario
**"You need to implement a BFS (breadth-first search) on a large graph. What data structure would you use as the queue, and why?"**

**One-line answer:** `ArrayDeque` — it is faster than `LinkedList` for queue operations because of contiguous memory layout and zero per-element allocation.

**Full answer to give in an interview:**

> "I'd use `ArrayDeque<Integer>` as the BFS queue. BFS needs a FIFO queue: nodes are enqueued at the back with `offer()` and dequeued from the front with `poll()`. Both operations are O(1) on `ArrayDeque`.
>
> The reason I'd pick it over `LinkedList` is throughput. In a large graph traversal you might process millions of nodes. `LinkedList` allocates a new `Node` object for every enqueue — millions of short-lived heap objects means frequent GC pauses. `ArrayDeque` is a single contiguous array; elements are stored at array slots, so enqueueing is just an array write and a pointer advance. There's no per-element allocation, and sequential array access plays well with CPU L1/L2 cache — the next element to be dequeued is likely already in cache.
>
> The practical setup:
>
> ```
> queue = new ArrayDeque<>()
> queue.offer(startNode)
> mark startNode as visited
>
> while queue is not empty:
>   node = queue.poll()
>   process(node)
>   for each neighbor of node:
>     if not visited:
>       mark neighbor as visited
>       queue.offer(neighbor)
> ```
>
> Marking before enqueue (not after dequeue) prevents the same node from being added to the queue multiple times."

*The pseudocode walk-through shows you can translate data structure knowledge into an algorithm. That's what the interviewer wants to see.*

**Gotcha follow-up they'll ask:** *"What happens if the graph is very deep — would you still use BFS?"*

> "If I know I only need to find the shortest path and the graph is wide but not too deep, BFS is correct. If the graph is very deep, BFS uses O(width) memory — the entire frontier level must sit in the queue. DFS uses O(depth) memory — only the path from root to the current node is on the stack. For a deep graph, DFS with an explicit `ArrayDeque` as a stack is more memory-efficient. The structural choice between BFS and DFS depends on the problem, not on the data structure — but `ArrayDeque` handles both cleanly."

---

> **Common Mistake — using java.util.Stack in new code:** Every push and pop on `Stack` acquires a synchronized monitor, making it significantly slower than `ArrayDeque` in single-threaded code. Additionally, `Stack` exposes random-access `Vector` methods that have no semantic meaning on a stack, making the API misleading. Always use `ArrayDeque` (or `Deque<T>`) in new code.

**Quick Revision (one line):**
`ArrayDeque` is a circular array implementing `Deque` — O(1) amortized at both ends, no null elements, faster than both `Stack` (no lock overhead) and `LinkedList` (no per-element allocation).

---

## Topic 15: Fail-fast vs Fail-safe Iterators

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Adobe, MakeMyTrip, Infosys

---

### The Idea

Imagine you are proofreading a printed document when a colleague walks over and starts crossing out sentences as you read. You finish the paragraph, but you have no idea whether your corrections still make sense — the document changed under you.

A **fail-fast iterator** is like a proofreader who immediately stops and shouts "the document changed!" the moment they detect any modification. A **fail-safe iterator** is like a proofreader who works from a photocopy — they finish their work without interruption, but they are not seeing the latest version.

Java's standard collections — `ArrayList`, `HashMap`, `HashSet` — use fail-fast iterators. Concurrent collections like `CopyOnWriteArrayList` and `ConcurrentHashMap` use fail-safe (or weakly consistent) iterators. Choosing the right collection depends on whether you need safe iteration under concurrent modification, and whether you can tolerate potentially stale reads.

---

### How It Works

**The `modCount` mechanism:**

Every `ArrayList`, `HashMap`, and `HashSet` maintains an internal counter:

```
protected transient int modCount = 0
```

This counter increments on every structural modification — every `add()`, `remove()`, `clear()`, or internal resize. When you call `list.iterator()`, the iterator records the current value:

```
ITERATOR CREATION:
  expectedModCount = collection.modCount

ON EACH next() CALL:
  checkForComodification():
    if modCount != expectedModCount:
      throw ConcurrentModificationException
  return next element
```

If anything — any code, anywhere, on any thread — modifies the collection between two `next()` calls, `modCount` changes, the check fires, and you get an exception immediately rather than silently reading corrupt data.

**Why the safe removal path does not throw:**

`Iterator.remove()` removes the element and then synchronizes `expectedModCount = modCount`. The iterator knows about its own removal, so the counts stay equal and no exception is thrown. Direct `list.remove()` does not do this — it increments `modCount` but leaves `expectedModCount` stale.

**Fail-safe collection comparison:**

| Collection | Iterator type | Behaviour on concurrent modification |
|---|---|---|
| `ArrayList` | Fail-fast | Throws `ConcurrentModificationException` |
| `HashMap` | Fail-fast | Throws `ConcurrentModificationException` |
| `HashSet` | Fail-fast | Throws `ConcurrentModificationException` |
| `CopyOnWriteArrayList` | Fail-safe (snapshot) | Iterates over array as it was at iterator creation; sees no concurrent adds |
| `ConcurrentHashMap` | Weakly consistent | Iterates live table; may see some concurrent modifications; never throws |

**`CopyOnWriteArrayList` internals:**

On iterator creation, a reference to the current backing array is captured. Every modification to the list (add, remove) creates a brand-new array, leaving the iterator's snapshot untouched. The iterator sees a frozen view. The trade-off: snapshots use extra memory proportional to the list size on every write.

**The critical Java gotcha — one real code block:**

```java
List<String> list = new ArrayList<>(List.of("a", "b", "c", "d"));

// WRONG — throws ConcurrentModificationException
for (String s : list) {
    if (s.equals("b")) {
        list.remove(s);  // modifies collection directly during for-each
    }
}

// CORRECT — use Iterator.remove()
Iterator<String> it = list.iterator();
while (it.hasNext()) {
    if (it.next().equals("b")) {
        it.remove();  // safe: syncs expectedModCount after removal
    }
}

// ALSO CORRECT (Java 8+) — cleaner
list.removeIf(s -> s.equals("b"));
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check
**"How does a fail-fast iterator detect concurrent modification?"**

**One-line answer:** It compares a saved `expectedModCount` against the collection's live `modCount` on every call to `next()` — if they differ, it throws `ConcurrentModificationException`.

**Full answer to give in an interview:**

> "Every `ArrayList`, `HashMap`, and `HashSet` maintains an internal integer called `modCount`. This counter increments by one every time the collection is structurally modified — every add, remove, clear, or resize operation. A structural modification is anything that changes the collection's size or rearranges its internal structure.
>
> When you call `list.iterator()`, the returned iterator records the current value of `modCount` in its own field called `expectedModCount`. Then, on every call to `next()`, the iterator calls a private `checkForComodification()` method that compares the two values. If they are equal, all is well, and `next()` proceeds. If they differ — meaning something modified the collection since the iterator was created — it immediately throws `ConcurrentModificationException`.
>
> Importantly, this check happens on `next()`, not lazily at the end of the loop. So you get the exception as soon as you try to advance past the point of modification, not at some unpredictable later time.
>
> One important nuance: `modCount` is not thread-safe. It is not a volatile field and not atomically updated. In a single-threaded context it works reliably. In a multithreaded context it is a best-effort mechanism — the JVM provides no happens-before guarantee between the thread that modifies the collection and the thread checking `modCount`."

*The mention of thread safety nuance signals senior-level understanding. Include it if the interviewer seems to want depth.*

**Gotcha follow-up they'll ask:** *"Does `ConcurrentModificationException` only happen in multithreaded code?"*

> "No — this is a common misconception. It fires just as readily in single-threaded code. The most typical case: a for-each loop over an `ArrayList` where you call `list.remove()` inside the loop body. The loop uses the iterator internally, but `list.remove()` modifies `modCount` without telling the iterator. The next call to `next()` detects the mismatch and throws. Threading is irrelevant — it's about who modified the collection without going through the iterator."

---

#### Q2 — Tradeoff Question
**"What is the difference between CopyOnWriteArrayList's iterator and ConcurrentHashMap's iterator? Both are fail-safe — aren't they the same?"**

**One-line answer:** `CopyOnWriteArrayList` gives a true snapshot — the iterator sees a frozen point-in-time view; `ConcurrentHashMap`'s iterator is weakly consistent — it reflects the live table and may see some concurrent changes.

**Full answer to give in an interview:**

> "Both avoid `ConcurrentModificationException`, but they work very differently.
>
> `CopyOnWriteArrayList` works by copying the entire backing array on every write. When you call `iterator()`, the iterator captures a reference to the current array. After that, any thread that does an `add()` or `remove()` gets a brand-new array — the iterator's reference still points at the old one. So the iterator sees a perfectly consistent snapshot of the list as it was at the moment the iterator was created. No concurrent change — past, present, or future — will affect what the iterator returns. The cost is memory: every write copies the full array, so this only makes sense for lists that are read far more often than written. Think: request interceptor lists, event listener registries.
>
> `ConcurrentHashMap`'s iterator is described in the Javadoc as 'weakly consistent.' It does not take a snapshot. Instead, it walks the live internal table. It guarantees it will not throw `ConcurrentModificationException` and it will return each entry at most once. But it may or may not see entries that were added or removed after the iterator was created — the behaviour depends on which segment of the hash table has already been visited. This makes it suitable for monitoring or bulk operations where you need reasonable throughput and can tolerate seeing a slightly stale view."

*This comparison comes up often in senior interviews. The key phrase is 'weakly consistent' — make sure you can say what it means.*

**Gotcha follow-up they'll ask:** *"Does CopyOnWriteArrayList's iterator see mutations made after the iterator was created?"*

> "No. Once the iterator is created, it holds a reference to the specific array that existed at that moment. Any write to the list creates a new backing array. The iterator's reference never changes — it stays pointed at the snapshot. So additions or removals made after the iterator was created are invisible to it. This is by design: it guarantees consistency at the cost of not seeing the latest state."

---

#### Q3 — Design Scenario
**"You have a web framework that maintains a list of request interceptors. Multiple threads call interceptors on every request, and occasionally an admin endpoint adds or removes an interceptor. What collection would you use?"**

**One-line answer:** `CopyOnWriteArrayList` — reads (iteration) dominate heavily over writes (admin changes), making the copy-on-write cost acceptable.

**Full answer to give in an interview:**

> "This is a classic read-heavy, write-rare scenario, and it fits `CopyOnWriteArrayList` almost perfectly.
>
> The read path — iterating through interceptors on every request — needs to be lock-free and fast. With `CopyOnWriteArrayList`, iteration requires no locking at all: each thread's iterator holds a reference to the backing array snapshot and reads from it directly. There is no synchronization overhead on the hot path.
>
> The write path — adding or removing an interceptor — happens rarely (admin action, deployment change). When it does, `CopyOnWriteArrayList` creates a new copy of the backing array with the modification applied, and atomically swaps the reference. Threads currently iterating continue using the old snapshot; new iterators pick up the new array. The memory cost of copying the array is acceptable when writes are rare.
>
> The alternative — wrapping an `ArrayList` in `Collections.synchronizedList()` — would require every read thread to acquire the list's lock before iterating, serializing all concurrent request processing. That's a severe throughput bottleneck.
>
> Another alternative — `ConcurrentHashMap` — does not apply here; the use case is ordered list traversal, not key-value lookup.
>
> The one risk to flag: if interceptors are added and removed frequently — say, per-request dynamic registration — the copy overhead becomes expensive and a lock-based approach with read-write locks would be better."

*Always close a design answer by identifying its failure mode — this is what distinguishes a good answer from a great one.*

**Gotcha follow-up they'll ask:** *"What's the correct way to remove an element from an ArrayList during iteration without throwing ConcurrentModificationException?"*

> "Two safe options. First, use `Iterator.remove()`: get the iterator explicitly, call `next()` to advance, then call `it.remove()` to remove the last-returned element — the iterator syncs `expectedModCount` after its own removal, so no exception is thrown. Second, use `list.removeIf(predicate)` introduced in Java 8 — cleaner, reads more naturally, and handles the iterator bookkeeping internally. What you must never do is call `list.remove()` directly inside a for-each loop — that modifies `modCount` without the iterator knowing."

---

> **Common Mistake — thinking ConcurrentModificationException is thread-safety:** Students often assume this exception signals a race condition between two threads. It does not. It is a single-threaded programming error: modifying an `ArrayList` while iterating it on the same thread. The exception name is misleading — "concurrent" refers to the modification happening concurrently with the iteration, not to multiple threads.

**Quick Revision (one line):**
Fail-fast = `modCount` check on every `next()`, throws on any outside modification; fail-safe = `CopyOnWriteArrayList` snapshot or `ConcurrentHashMap` weakly consistent — neither throws, but neither guarantees a fully up-to-date view.

---

## Topic 16: ListIterator

**Difficulty:** Easy | **Frequency:** Medium | **Companies:** Capgemini, TCS, mid-tier enterprise

---

### The Idea

A standard `Iterator` is like reading a book from front to back: you can read the current page and turn to the next, but you cannot go backwards, and you can only delete the page you just read — you cannot insert a new page or replace text mid-read.

`ListIterator` is like reading with a pencil: you can go forwards and backwards, you can cross out the current entry (`remove()`), replace it with something else (`set()`), or insert a brand-new entry right where you are (`add()`). All of this without the book falling apart — no `ConcurrentModificationException` for modifications made through the iterator itself.

The catch: `ListIterator` is only available for `List` implementations. Sets and Maps have no index-based position concept, so the cursor model does not apply.

---

### How It Works

**Methods `ListIterator` adds over plain `Iterator`:**

| Method | Description |
|---|---|
| `hasPrevious()` | `true` if there is an element before the cursor |
| `previous()` | Returns the element before the cursor and moves cursor backward |
| `nextIndex()` | Index of the element that `next()` would return |
| `previousIndex()` | Index of the element that `previous()` would return |
| `add(E e)` | Inserts element at the current cursor position |
| `set(E e)` | Replaces the last element returned by `next()` or `previous()` |

**Cursor model:**

```
List:  [ a ] [ b ] [ c ] [ d ]
Cursor:^    ^    ^    ^    ^
       0    1    2    3    4

nextIndex()     = cursor position
previousIndex() = cursor position - 1
next()          moves cursor right by 1
previous()      moves cursor left by 1
```

`add(e)` inserts before the cursor's current position. The inserted element is NOT returned by a subsequent call to `next()` — the cursor is placed after the inserted element, so `next()` would return the element that was already after the cursor.

**The one real code block — the interview-critical gotcha:**

```java
List<String> list = new ArrayList<>(List.of("a", "b", "c", "d"));
ListIterator<String> it = list.listIterator();

while (it.hasNext()) {
    String s = it.next();
    if (s.equals("b")) {
        it.set("B");    // replace "b" with "B" — safe
        it.add("B+");   // insert "B+" after "B" — safe
    }
}
// Result: [a, B, B+, c, d]

// Backward traversal continues from where forward traversal left off
while (it.hasPrevious()) {
    System.out.print(it.previous() + " ");
}
// Output: d c B+ B a
```

Note: calling `remove()` or `set()` without first calling `next()` or `previous()` throws `IllegalStateException` — the iterator has no "last returned element" to act on.

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check
**"What can ListIterator do that a regular Iterator cannot?"**

**One-line answer:** `ListIterator` adds bidirectional traversal (`previous()`, `hasPrevious()`) and mid-iteration mutation (`set()`, `add()`) — a regular `Iterator` only supports forward traversal and `remove()`.

**Full answer to give in an interview:**

> "A regular `Iterator` gives you three methods: `hasNext()`, `next()`, and `remove()`. You can walk forward through a collection and optionally delete elements as you go — that's it.
>
> `ListIterator` extends this with six additional capabilities. Directionally, it adds `hasPrevious()` and `previous()`, so you can traverse backwards through the list, or bounce back and forth. Positionally, it adds `nextIndex()` and `previousIndex()`, which tell you exactly where the cursor sits — useful if you need to track position without a separate counter.
>
> The most powerful additions are `set(E e)` and `add(E e)`. `set()` replaces the element that was most recently returned by `next()` or `previous()` — think of it as an in-place update. `add(E e)` inserts a new element at the current cursor position. Both of these are safe to call during iteration: the iterator updates its internal bookkeeping so the structural modification does not cause a `ConcurrentModificationException`.
>
> The constraint is that `ListIterator` is only available for `List` implementations — `ArrayList`, `LinkedList`, and so on. You call `list.listIterator()` to get one. Sets and Maps have no ordered index concept, so there is no `SetIterator` or `MapListIterator`."

**Gotcha follow-up they'll ask:** *"What exception is thrown if you call set() before calling next() or previous()?"*

> "`IllegalStateException`. The iterator has a concept of a 'last returned element' — the element most recently returned by `next()` or `previous()`. `set()` and `remove()` act on that element. If you call `set()` immediately after creating the iterator, or immediately after calling `add()`, there is no last returned element, so the iterator has nothing to act on and throws `IllegalStateException`."

---

#### Q2 — Tradeoff Question
**"When would you use ListIterator over a standard for-loop with an index?"**

**One-line answer:** When you need to mutate elements in place (`set()`) or insert elements mid-traversal (`add()`) — a for-loop with index can do the same but is more error-prone with shifting indices.

**Full answer to give in an interview:**

> "A standard indexed for-loop is perfectly fine for read-only traversal or simple replacements. But two scenarios favour `ListIterator`.
>
> First, inserting elements mid-traversal. With an indexed loop, inserting an element at position `i` shifts all subsequent elements — your loop index is now off, and you have to adjust it manually. `ListIterator.add()` handles the cursor advancement correctly for you. The inserted element is placed at the cursor position, and the cursor moves past it, so the next `next()` call correctly returns the element that was previously next — not the one you just inserted.
>
> Second, backward traversal. If you need to process a list in reverse, you could use `Collections.reverse()` — but that mutates the list. Alternatively, you could loop from `list.size() - 1` down to 0. But `ListIterator` gives you `hasPrevious()` and `previous()` without touching the list's order.
>
> The tradeoff against `ListIterator`: the cursor model is slightly harder to reason about than a plain index. For simple read-heavy loops, an indexed for-loop is more readable. Use `ListIterator` when you need its specific mutation or traversal capabilities."

**Gotcha follow-up they'll ask:** *"Is ListIterator available for arrays?"*

> "No. `ListIterator` is an interface in `java.util` and is only implemented by `List` implementations. Raw arrays in Java have no iterator at all — you use an indexed for-loop or convert to a `List` via `Arrays.asList()` first. `Arrays.asList()` returns a fixed-size `List` backed by the array, so you can call `listIterator()` on it, but you cannot call `add()` or `remove()` on that iterator — those operations would change the list size, which is not allowed on a fixed-size backing structure. You'd get `UnsupportedOperationException`."

---

#### Q3 — Design Scenario
**"You are processing a list of tokens in a simple text parser. For each operator token you find, you need to replace it with a normalized version and insert a whitespace token immediately after it. How would you implement this?"**

**One-line answer:** Use `ListIterator` — `set()` to replace the operator in place and `add()` to insert the whitespace token after the current position, all in a single forward pass.

**Full answer to give in an interview:**

> "This is exactly the use case `ListIterator` is designed for. I need to both replace an element and insert a new element at a specific position during the same traversal — `set()` and `add()` together give me that.
>
> ```
> tokens = ["OPEN", "+", "5", "-", "3", "CLOSE"]
>
> it = tokens.listIterator()
> while it.hasNext():
>   token = it.next()
>   if token is an operator:
>     it.set(normalize(token))    // replace "+" with "OP_ADD", "-" with "OP_SUB", etc.
>     it.add(" ")                 // insert whitespace after the current operator
>
> // Result: ["OPEN", "OP_ADD", " ", "5", "OP_SUB", " ", "3", "CLOSE"]
> ```
>
> The key behaviour to rely on: after `it.add(" ")`, the cursor is positioned after the newly inserted element. So the next call to `it.next()` returns `"5"` — not the whitespace token we just inserted. This means we do not re-process our own insertions, which is exactly what we want.
>
> Without `ListIterator`, the alternatives are awkward. I could build a new list alongside the original and swap at the end — that works but allocates extra memory. I could use an indexed loop and track index shifts manually — that works but is error-prone. `ListIterator` is the clean, allocation-free, single-pass solution."

**Gotcha follow-up they'll ask:** *"Would this work on a LinkedList as well as an ArrayList?"*

> "Yes — `ListIterator` is part of the `List` interface, so it works on any `List` implementation including `LinkedList`. In fact, for this insertion-heavy use case, `LinkedList` might be slightly better: inserting at an arbitrary position in a `LinkedList` is O(1) once you have the iterator's cursor, while inserting mid-array in an `ArrayList` requires shifting subsequent elements — O(n) in the worst case. But for most real-world list sizes the difference is negligible, and `ArrayList` is still faster in practice due to cache locality."

---

> **Common Mistake — calling set() or remove() without a preceding next() or previous():** Both `set()` and `remove()` operate on the "last returned element." If no element has been returned yet — immediately after iterator creation, or immediately after `add()` — calling either method throws `IllegalStateException`. Always call `next()` or `previous()` first to establish a current element.

**Quick Revision (one line):**
`ListIterator` extends `Iterator` with bidirectional traversal and in-place mutation (`set()`, `add()`) — available for `List` only; `set()`/`remove()` require a prior `next()` or `previous()` call.

---

## Topic 17: Collections Utility Class

**Difficulty:** Easy | **Frequency:** Medium | **Companies:** General Java interviews, mid-level screening rounds

---

### The Idea

Every language has a standard toolbox of algorithms for common data structure operations — sort, search, shuffle, find min/max. In Java, that toolbox for collections is `java.util.Collections`. It is a class of pure static methods; you never instantiate it.

Think of it as the helper you reach for when you have a collection and need to do something to it: put it in order, find something in it, randomise it, protect it from being changed, or wrap it so it is safe to use across threads.

The key mental model: `Collections` does not replace the collection — it operates on it. `Collections.sort(list)` modifies the list in place. `Collections.unmodifiableList(list)` returns a wrapper around the existing list, not a copy. Understanding which operations mutate in place and which return new views is the most important thing to know here.

---

### How It Works

**Sorting:**

```
Collections.sort(list)
  — uses TimSort (hybrid merge sort + insertion sort)
  — O(n log n) worst case, O(n) if list is already sorted
  — mutates the list in place

Collections.sort(list, comparator)
  — same algorithm with a custom ordering

// Preferred since Java 8:
list.sort(comparator)
  — delegates to Arrays.sort() on the backing array
  — same algorithm, slightly cleaner API
```

**Searching:**

```
Collections.binarySearch(list, key)
  — REQUIRES list to be sorted in ascending order first
  — returns the index if found
  — returns -(insertionPoint) - 1 if not found
       where insertionPoint = index where key would be inserted to maintain order
```

**Unmodifiable wrappers vs truly immutable collections — the critical distinction:**

```
// UNMODIFIABLE WRAPPER — read-only view of a mutable list
List<String> mutable = new ArrayList<>(List.of("a", "b", "c"));
List<String> readOnly = Collections.unmodifiableList(mutable);

readOnly.add("d");   // throws UnsupportedOperationException — as expected
mutable.add("d");    // WORKS — the underlying list is still mutable
System.out.println(readOnly);  // ["a", "b", "c", "d"] — the wrapper reflects the change!
```

This is the most frequently tested gotcha: `Collections.unmodifiableList()` prevents mutations through the wrapper reference, but the original reference can still modify the underlying list and those changes are visible through the wrapper.

**The single most interview-critical code block:**

```java
// unmodifiableList does NOT protect against mutations via the original reference
List<String> mutable = new ArrayList<>(List.of("a", "b", "c"));
List<String> readOnly = Collections.unmodifiableList(mutable);
mutable.add("d");                    // succeeds — original reference still mutable
System.out.println(readOnly.size()); // prints 4, not 3

// For true immutability (Java 9+), use List.of() — no backing mutable structure
List<String> immutable = List.of("a", "b", "c");
immutable.add("d");  // throws UnsupportedOperationException — always, no backdoor
```

**Synchronized wrappers:**

```
List<String> syncList = Collections.synchronizedList(new ArrayList<>());

// Single operations are thread-safe automatically
syncList.add("x");    // safe
syncList.get(0);      // safe

// BUT iteration requires MANUAL synchronization — NOT automatic
synchronized(syncList) {
  for (String s : syncList) {  // must hold the lock for the entire loop
    process(s);
  }
}
// Forgetting the synchronized block leads to ConcurrentModificationException
// even though you're using a "synchronized" list
```

**Utility methods summary:**

| Method | What it does | Complexity |
|---|---|---|
| `sort(list)` | TimSort in-place | O(n log n) |
| `binarySearch(list, key)` | Sorted-list search | O(log n) |
| `min(collection)` | Natural order minimum | O(n) |
| `max(collection)` | Natural order maximum | O(n) |
| `frequency(collection, obj)` | Count occurrences | O(n) |
| `shuffle(list)` | Random permutation | O(n) |
| `reverse(list)` | Reverses in place | O(n) |
| `fill(list, obj)` | Overwrites all elements | O(n) |
| `nCopies(n, obj)` | Immutable list of n copies | O(1) |
| `disjoint(c1, c2)` | True if no common elements | O(n) |
| `unmodifiableList(list)` | Read-only view | O(1) |
| `synchronizedList(list)` | Thread-safe wrapper | O(1) |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check
**"What is the difference between Collections.unmodifiableList() and List.of()?"**

**One-line answer:** `unmodifiableList()` is a read-only *view* of a mutable list — mutations via the original reference still work; `List.of()` is a truly immutable list with no mutable backing structure.

**Full answer to give in an interview:**

> "This is a subtle but important distinction. `Collections.unmodifiableList(list)` creates a wrapper object that delegates all read operations to the original list, and throws `UnsupportedOperationException` for any write operation called on the wrapper. The underlying list itself is unchanged — it is still fully mutable. If you have a reference to the original list, you can still call `add()`, `remove()`, `set()`, and those changes are immediately visible through the unmodifiable wrapper.
>
> So unmodifiableList is a read-only *view*, not a defensive copy. If you are returning an unmodifiable list from a method to protect internal state, but the caller somehow gets hold of the original mutable list, your protection is bypassed. This can happen in code that stores both the mutable and unmodifiable references and accidentally shares the wrong one.
>
> `List.of()` — introduced in Java 9 — creates a completely separate list that was never backed by a mutable structure. There is no original list to sneak a reference to. Any attempt to call `add()`, `set()`, or `remove()` on it throws `UnsupportedOperationException` always, unconditionally. It is also slightly more memory-efficient because it uses specialized compact internal implementations for small lists (0 to 2 elements) rather than an array.
>
> The rule of thumb: if you are publishing data out of a component as a read-only contract, prefer `List.of()` or `List.copyOf()`. Use `unmodifiableList()` only when you need the consumer to see live changes to the underlying list, or when you are wrapping a third-party list you do not control."

**Gotcha follow-up they'll ask:** *"Does List.of() allow null elements?"*

> "No. `List.of()` throws `NullPointerException` if you pass a null element. This is intentional — the Java API designers decided that unmodifiable lists should be null-safe by default. If you need a list that contains nulls and is also read-only, use `Collections.unmodifiableList()` wrapping a list that contains the nulls."

---

#### Q2 — Tradeoff Question
**"How does Collections.synchronizedList() differ from CopyOnWriteArrayList, and when would you choose one over the other?"**

**One-line answer:** `synchronizedList()` uses a single mutex lock on every operation — including iteration, which must be done manually; `CopyOnWriteArrayList` copies the array on every write, giving lock-free reads at the cost of write overhead.

**Full answer to give in an interview:**

> "Both make a list safe for concurrent access, but they make completely different performance tradeoffs.
>
> `Collections.synchronizedList()` wraps the list in a monitor. Every individual method — `add()`, `get()`, `size()`, `remove()` — acquires the same lock before executing and releases it after. This serializes all access: only one thread can be in any of those methods at a time. The wrapper does NOT protect iteration — if you do a for-each loop without holding the lock explicitly, another thread can modify the list between two `next()` calls and trigger `ConcurrentModificationException`. You are required to write `synchronized(syncList) { for (...) }` manually every time you iterate. It is easy to forget, and the resulting bug is intermittent and hard to reproduce.
>
> `CopyOnWriteArrayList` takes a different approach. Every write — `add()`, `remove()`, `set()` — locks and copies the entire backing array, applies the change to the copy, then atomically swaps the reference. Reads and iteration are completely lock-free: the iterator holds a reference to the array snapshot at creation time and reads from it with zero synchronization.
>
> The choice is driven by read/write ratio:
> - Read-heavy, write-rare (interceptors, listeners, configuration): use `CopyOnWriteArrayList`. Zero lock contention on reads; the occasional write cost of copying is acceptable.
> - Balanced or write-heavy: use `synchronizedList()` or, better, a purpose-built concurrent structure like `ConcurrentLinkedQueue`. `CopyOnWriteArrayList` with frequent writes means frequent full-array copies — O(n) per write — which is expensive."

*The interviewer is checking whether you know the right tool for the right access pattern. Give the decision criterion clearly.*

**Gotcha follow-up they'll ask:** *"What is the correct way to iterate a synchronizedList safely?"*

> "You must wrap the entire iteration in a `synchronized` block, passing the list as the monitor: `synchronized(syncList) { for (String s : syncList) { ... } }`. The block must cover the entire iteration from first `next()` to last — not just individual calls. If you acquire and release the lock per `next()` call, another thread can modify the list between iterations and you are back to `ConcurrentModificationException`."

---

#### Q3 — Design Scenario
**"You need to sort a list of Customer objects by last name, then by first name for ties. Which Collections methods would you use, and how?"**

**One-line answer:** Use `Collections.sort(list, comparator)` with a chained `Comparator` — `Comparator.comparing` with `thenComparing` for the tie-breaker.

**Full answer to give in an interview:**

> "I'd use `Collections.sort()` with a composite `Comparator`. Since Java 8, the `Comparator` interface has factory methods that make multi-field sorting readable:
>
> ```
> Comparator<Customer> byName =
>   Comparator.comparing(Customer::getLastName)
>             .thenComparing(Customer::getFirstName);
>
> Collections.sort(customers, byName);
> // or equivalently: customers.sort(byName);
> ```
>
> `Comparator.comparing(Customer::getLastName)` builds a comparator that uses natural String ordering on last names. `.thenComparing(Customer::getFirstName)` chains a second comparator that is applied only when the first comparator considers two entries equal — the tie-breaker.
>
> Under the hood, `Collections.sort()` uses TimSort: a hybrid of merge sort and insertion sort. Its worst-case is O(n log n), same as merge sort, but its best-case is O(n) for already-sorted or nearly-sorted input — which is common for lists that have been partially sorted by previous operations. TimSort is stable, meaning entries that compare equal preserve their original relative order. That stability matters here: if two customers have identical last name and first name, their original relative position in the list is preserved.
>
> One alternative: if `Customer` implements `Comparable` with a natural ordering, `Collections.sort(customers)` without a comparator would work. But implementing `Comparable` bakes one specific ordering into the class — for business objects that might be sorted many different ways (by name, by creation date, by account balance), comparators passed at the call site are more flexible."

*Mention TimSort stability — interviewers who ask this question often know about it and are checking whether you do too.*

**Gotcha follow-up they'll ask:** *"If binarySearch() returns a negative value, what does that value mean?"*

> "The return value is `-(insertionPoint) - 1`, where `insertionPoint` is the index where the key would need to be inserted to keep the list sorted. For example, if `binarySearch()` returns -3, then `insertionPoint = 2`, meaning the key was not found and would be inserted at index 2. The `-1` offset ensures the return value is always negative even when the insertion point is 0 — otherwise 0 would be ambiguous between 'found at index 0' and 'not found, would insert at 0'."

---

> **Common Mistake — iterating a synchronizedList without a synchronized block:** `Collections.synchronizedList()` synchronizes individual method calls but does NOT synchronize iteration. Calling `for (String s : syncList)` without a surrounding `synchronized(syncList)` block is a data race — another thread can modify the list between calls to `next()`, causing `ConcurrentModificationException`. Always wrap the entire iteration in a `synchronized` block on the list object itself.

**Quick Revision (one line):**
`Collections` provides static sort/search/shuffle/min/max utilities; `unmodifiableList()` is a mutable-backed read-only view (use `List.of()` for true immutability); `synchronizedList()` requires manual sync on iteration.

---

## Topic 18: Arrays Utility Class

**Difficulty:** Easy | **Frequency:** Medium | **Companies:** General Java screening rounds

---

### The Idea

Think of `java.util.Arrays` as a Swiss-army knife for arrays — a toolbox of static methods that handles the tasks you would otherwise write yourself: sorting, searching, copying, filling, and comparing. It ships with the JDK and works on both primitive arrays (`int[]`, `double[]`) and object arrays (`String[]`, `Employee[]`).

The most important thing to know is that the sorting algorithm it uses depends on the array type. Primitives get a highly tuned version of Quicksort (Dual-Pivot, by Yaroslavskiy et al.); objects get TimSort — a stable merge-sort variant that respects `Comparator`. Java 8 added `parallelSort()`, which splits the array across Fork/Join worker threads for large inputs.

The classic interview trap is `Arrays.asList()`. It looks like it gives you a normal mutable list, but it does not. The returned list is fixed-size: you can replace elements (`set()`), but `add()` and `remove()` throw `UnsupportedOperationException`. The list and the original array share the same backing storage, so a write to one is visible in the other.

### How It Works

```
Arrays.sort(primitiveArray)
  → Dual-Pivot Quicksort
  → O(n log n) average; insertion sort for small subarrays (<47 elements)
  → NOT stable (primitives have no identity, stability is irrelevant)

Arrays.sort(objectArray)
  → TimSort (merge-based)
  → O(n log n) worst case; stable
  → Uses Comparator if provided, else Comparable.compareTo()

Arrays.parallelSort(array)
  → Fork/Join: split array, sort each part in parallel, merge
  → Beneficial when array length > ~8192 elements
  → Falls back to sequential sort for small arrays

Arrays.binarySearch(sortedArray, key)
  → REQUIRES array to be sorted first (undefined behaviour otherwise)
  → O(log n)
  → Returns: index if found; -(insertionPoint + 1) if not found

Arrays.copyOf(arr, newLength)           → full or truncated copy
Arrays.copyOfRange(arr, from, to)       → sub-array copy (to is exclusive)
Arrays.fill(arr, value)                 → set every element to value
Arrays.equals(a, b)                     → element-wise comparison, 1D
Arrays.deepEquals(a, b)                 → element-wise comparison, nested arrays
Arrays.deepToString(a)                  → recursive string, e.g. [[1,2],[3,4]]

Arrays.asList(arr)
  → Returns List<T> backed by the original array
  → Fixed-size: set() OK, add()/remove() → UnsupportedOperationException
  → Changes to either the array or the list are reflected in the other
```

The single most interview-critical gotcha — the `asList` trap:

```java
// THE ASLIST TRAP — most common Arrays interview mistake
String[] strArr = {"x", "y", "z"};
List<String> list = Arrays.asList(strArr);

list.set(0, "X");     // OK — modifies backing array too
strArr[1] = "Y";      // OK — changes visible in list as well
// list.add("w");     // UnsupportedOperationException — fixed-size!

// To get a truly independent mutable list:
List<String> mutable = new ArrayList<>(Arrays.asList(strArr));
```

**Algorithm summary table:**

| Method | Input Type | Algorithm | Stable? | Notes |
|---|---|---|---|---|
| `sort()` | `int[]`, `long[]`, etc. | Dual-Pivot Quicksort | No | Fast in practice |
| `sort()` | `Object[]` | TimSort | Yes | Respects Comparator |
| `parallelSort()` | Any | Fork/Join + TimSort | Yes | Best for n > 8192 |
| `binarySearch()` | Sorted array | Binary search | — | Undefined if unsorted |

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What sorting algorithm does `Arrays.sort()` use, and does it depend on the input type?"**

**One-line answer:** Dual-Pivot Quicksort for primitives, TimSort for objects — and the choice matters because only TimSort is stable.

**Full answer to give in an interview:**
> When I call `Arrays.sort()` on a primitive array like `int[]`, Java uses Dual-Pivot Quicksort — a variant introduced by Yaroslavskiy, Bentley, and Bloch. It runs O(n log n) on average and falls back to insertion sort for small subarrays, which is faster in practice for nearly-sorted data. It is not stable, but that does not matter for primitives since identical values are indistinguishable anyway. When I call `Arrays.sort()` on an `Object[]`, Java switches to TimSort — a merge-sort variant that is stable, meaning equal elements keep their original relative order. This is important when I'm sorting objects by one field and need the previous sort order to be preserved for ties. For very large arrays where I want to use multiple CPU cores, I'd use `Arrays.parallelSort()`, which uses the Fork/Join framework and becomes beneficial around 8,192 elements or more.

*Lead with "it depends on the type," then walk through primitives first, then objects. This shows you know both the algorithm name and the reason the choice was made.*

**Gotcha follow-up they'll ask:** *"Is `Arrays.sort()` stable for `String[]`?"*

> Yes — `String[]` is an object array, so TimSort is used, and TimSort is stable. If I have `["banana", "apple", "Banana"]` and sort case-insensitively, the relative order of "banana" and "Banana" is preserved. For primitive arrays stability is irrelevant, so the faster Quicksort is used.

---

#### Q2 — Tradeoff Question

**"When would you choose `Arrays.parallelSort()` over `Arrays.sort()`, and are there scenarios where parallelSort is actually slower?"**

**One-line answer:** Use parallelSort for large arrays (n > ~8,192) on multi-core machines; for small arrays it is slower due to Fork/Join overhead.

**Full answer to give in an interview:**
> `Arrays.parallelSort()` uses the Fork/Join framework to divide the array into chunks, sort each chunk in a separate thread, then merge the results. The split-and-merge overhead means that for small arrays the sequential `Arrays.sort()` is faster. The threshold at which parallel beats sequential is roughly 8,192 elements, but it depends on the hardware — specifically the number of available processors and their cache sizes. In a microservice with limited CPU allocation or in a heavily loaded JVM where the common Fork/Join pool is already saturated with other tasks, parallelSort can actually degrade throughput because it competes for pool threads with other `CompletableFuture` or parallel-stream workloads. My rule of thumb: use parallelSort only for one-time large sorts (e.g., batch processing), not for arrays sorted repeatedly inside hot paths.

*This answer demonstrates you understand both the algorithm and the runtime environment — interviewers love that combination.*

**Gotcha follow-up they'll ask:** *"What thread pool does `parallelSort` use?"*

> It uses the common Fork/Join pool — the same one used by parallel streams and `CompletableFuture.supplyAsync()` without a custom executor. That shared pool is important to keep in mind; heavy parallel sorts can starve other async tasks.

---

#### Q3 — Design Scenario

**"You receive a `String[]` from an external API. You need a mutable, independently modifiable list. What is wrong with `List<String> list = Arrays.asList(arr)` and how do you fix it?"**

**One-line answer:** `Arrays.asList()` returns a fixed-size list backed by the original array — wrap it in `new ArrayList<>()` to get a truly independent mutable list.

**Full answer to give in an interview:**
> `Arrays.asList(arr)` returns a special `java.util.Arrays$ArrayList` that is backed by the original array. Two things can go wrong: first, calling `add()` or `remove()` throws `UnsupportedOperationException` because the backing array is fixed-size — I cannot resize it. Second, even though the list looks like a copy, it shares memory with the original array — if someone modifies `arr[0]`, the list reflects that change immediately, and vice versa. To get a fully independent mutable list I write `new ArrayList<>(Arrays.asList(arr))`. That constructor copies all elements into a freshly allocated ArrayList, which has its own backing array and supports all mutation operations. If I'm on Java 9+ and only need an immutable list, `List.of(arr)` is even cleaner, but it also rejects nulls, so I need to know my data.

*Concrete code + two separate failure modes (add/remove throws, shared backing) — this is exactly the depth the interviewer is probing for.*

**Gotcha follow-up they'll ask:** *"What does `Arrays.asList()` return for a primitive array like `int[]`?"*

> It does NOT unbox the primitives. `Arrays.asList(new int[]{1, 2, 3})` returns `List<int[]>` — a list of one element which is the entire array. To get a `List<Integer>` I need to use an `Integer[]` or use streams: `IntStream.of(arr).boxed().collect(Collectors.toList())`.

---

> **Common Mistake — Using `Arrays.asList()` expecting a fully mutable list:** Calling `add()` or `remove()` on the returned list throws `UnsupportedOperationException` at runtime. The compile-time type is `List<T>` so there is no warning — this always surfaces as a production runtime crash.

**Quick Revision (one line):** `Arrays.sort()` uses Dual-Pivot Quicksort for primitives and stable TimSort for objects; `asList()` gives a fixed-size array-backed list — wrap in `new ArrayList<>()` to mutate it freely.

---

## Topic 19: Comparable vs Comparator

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Goldman Sachs, Wipro, all companies using sorting

---

### The Idea

Think of `Comparable` as a class defining its own "natural" handshake: an `Employee` class that implements `Comparable<Employee>` is saying "by default, sort me alphabetically by name." That ordering is baked into the class. `Comparator` is an external judge — a separate object (often a lambda) that imposes a different ordering without touching the class at all. You can have exactly one `Comparable` ordering but an unlimited number of `Comparator` orderings.

The distinction matters whenever you use sorted collections. `TreeSet`, `TreeMap`, `Collections.sort()`, and `Arrays.sort(Object[])` all rely on either `Comparable.compareTo()` (when no Comparator is supplied) or `Comparator.compare()` (when one is). Get the wrong one or implement either incorrectly and your sorted data silently produces wrong results.

Java 8 made `Comparator` dramatically more powerful. Instead of anonymous classes, you now chain factory methods: `Comparator.comparing(Employee::getDepartment).thenComparing(Employee::getSalary).reversed()`. Null handling, reverse order, and multi-field chaining are all one-liners.

### How It Works

```
Comparable<T>
  interface method: int compareTo(T other)
  contract: return negative if this < other, 0 if equal, positive if this > other
  location: implemented INSIDE the class being compared
  used by: TreeSet, TreeMap, Collections.sort(), Arrays.sort() (no Comparator arg)

Comparator<T>
  interface method: int compare(T o1, T o2)
  contract: return negative if o1 < o2, 0 if equal, positive if o1 > o2
  location: external — anonymous class, lambda, method reference, or static field
  used by: TreeSet(comparator), TreeMap(comparator), list.sort(comparator)

Java 8 Comparator factory methods:
  Comparator.naturalOrder()               → uses Comparable.compareTo()
  Comparator.reverseOrder()               → reverse of naturalOrder()
  Comparator.comparing(keyExtractor)      → extract Comparable field, sort by it
  Comparator.comparingInt / Double / Long → avoids boxing
  .thenComparing(keyExtractor)            → secondary sort on tie
  .reversed()                             → flip the whole chain
  Comparator.nullsFirst(c)                → nulls sort before non-nulls
  Comparator.nullsLast(c)                 → nulls sort after non-nulls

TreeSet / TreeMap element identity rule:
  "Two elements are the SAME if compareTo() / compare() returns 0"
  → If compareTo() returns 0 but equals() returns false,
    TreeSet will treat them as duplicates and silently drop one
```

The single most interview-critical gotcha — integer subtraction overflow in `compareTo`:

```java
// WRONG — integer subtraction can overflow and produce wrong sign
@Override
public int compareTo(Item other) {
    return this.value - other.value;  // DANGEROUS: if this=-2B, other=+2B → overflows to positive
}

// CORRECT — use Integer.compare() which handles all edge cases
@Override
public int compareTo(Item other) {
    return Integer.compare(this.value, other.value);
}

// Java 8 multi-field Comparator — the correct idiomatic way
Comparator<Employee> comp =
    Comparator.comparing(Employee::getDepartment)
              .thenComparingDouble(Employee::getSalary).reversed()
              .thenComparing(Comparator.nullsLast(Comparator.comparing(Employee::getName)));
```

**Decision table:**

| Scenario | Use |
|---|---|
| One "natural" sort order for the class | `Comparable` |
| Multiple different sort orders | `Comparator` |
| Cannot modify the class (third-party) | `Comparator` |
| Sort by multiple fields with chaining | `Comparator` (Java 8 API) |
| `TreeSet`/`TreeMap` default ordering | `Comparable` |
| `TreeSet`/`TreeMap` custom ordering | `Comparator` passed to constructor |

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is the difference between `Comparable` and `Comparator`?"**

**One-line answer:** `Comparable` is natural ordering baked into the class via `compareTo()`; `Comparator` is an external ordering object via `compare()` — one class can have many Comparators.

**Full answer to give in an interview:**
> `Comparable<T>` is an interface I implement inside the class itself. The single method `compareTo(T other)` defines the "natural order" — how the class naturally sorts. For example, `String` implements `Comparable<String>` to sort lexicographically, and `Integer` does so to sort numerically. Collections that need ordering — `TreeSet`, `TreeMap`, `Collections.sort()` — call `compareTo()` when no external Comparator is provided. `Comparator<T>`, on the other hand, is a separate object. It lives outside the class and defines an alternate ordering via `compare(T o1, T o2)`. Because it is external, I can define as many Comparators as I want for the same class — sort employees by salary, by hire date, by department — without touching the `Employee` class. In Java 8+, Comparators are typically lambdas or method references chained with `Comparator.comparing().thenComparing().reversed()`.

*Mention the "external vs internal" axis first. That is the conceptual core. Then give the concrete example.*

**Gotcha follow-up they'll ask:** *"When should a class implement `Comparable` vs only provide Comparators?"*

> A class should implement `Comparable` when there is one obvious, universally accepted "natural" ordering — numbers by value, strings lexicographically, dates chronologically. If the class has no clear natural ordering, or if multiple orderings are equally valid, I leave `Comparable` unimplemented and provide `Comparator` constants or factory methods instead.

---

#### Q2 — Tradeoff Question

**"What does it mean for `compareTo()` to be 'consistent with equals,' and what breaks if it is not?"**

**One-line answer:** Consistent means `compareTo()` == 0 implies `equals()` == true — if this contract is broken, `TreeSet` and `TreeMap` silently discard or conflate elements that `equals()` would treat as distinct.

**Full answer to give in an interview:**
> The Java contract says: if `a.compareTo(b) == 0` then `a.equals(b)` should be `true`. When this holds, `TreeSet` and `TreeMap` behave correctly — two elements that are "equal by comparison" are treated as the same entry. If I break this — for example, I sort `BigDecimal` values `1.0` and `1.00` (they are `compareTo` equal but `equals` unequal) and put them both in a `TreeSet` — only the first one is kept, because `TreeSet` uses `compareTo` for identity. There is no exception, no warning; the second element is silently dropped. This is a subtle, hard-to-debug bug. The JDK documentation flags this explicitly, noting that sorted sets and maps "behave strangely" when consistency is violated. `HashSet`, by contrast, uses `equals` and `hashCode`, so it would keep both elements. This is why the same pair of values can coexist in a `HashSet` but collide in a `TreeSet`.

*The BigDecimal example is specific and memorable — use it.*

**Gotcha follow-up they'll ask:** *"What happens in a `TreeMap` if two different keys compare as 0?"*

> `TreeMap` treats them as the same key. The second `put()` overwrites the value associated with the first key. No exception, no duplicate — the map behaves as if both keys are identical. This is correct when `compareTo` is consistent with `equals`, but if they are not `equals()`, you have silently lost a key-value pair.

---

#### Q3 — Design Scenario

**"You need to sort a list of `Order` objects: primary sort by `createdDate` descending (newest first), secondary sort by `orderId` ascending for deterministic tie-breaking. How do you implement this in Java 8?"**

**One-line answer:** Chain `Comparator.comparing(Order::getCreatedDate).reversed().thenComparing(Order::getOrderId)`.

**Full answer to give in an interview:**
> I would use the Java 8 `Comparator` chaining API. `Comparator.comparing(Order::getCreatedDate)` creates a Comparator that sorts by date in ascending (oldest first) order. I then call `.reversed()` to flip it to descending. `.thenComparing(Order::getOrderId)` adds the secondary sort — ascending by ID, which is the natural order for integers. I apply this with `orders.sort(comparator)` or pass it to `Collections.sort()`. One subtlety: `.reversed()` reverses the entire chain up to that point, so order of operations matters — I must call `.reversed()` immediately after the primary comparator, before calling `.thenComparing()`. If `createdDate` could be null I would wrap the primary comparator with `Comparator.nullsLast()` to avoid a `NullPointerException`. In production I would store this `Comparator` as a named constant in the `Order` class so it is reusable and self-documenting: `public static final Comparator<Order> NEWEST_FIRST = ...`.

*Mentioning `.reversed()` placement and null safety shows production awareness.*

**Gotcha follow-up they'll ask:** *"Why should you never implement `compareTo()` by subtracting two integers?"*

> Because integer subtraction overflows. If `this.value` is `Integer.MIN_VALUE` (-2,147,483,648) and `other.value` is `1`, subtracting gives a large positive number — the wrong sign. The subtraction trick works only if both values are guaranteed to be non-negative and their difference cannot overflow. The correct approach is always `Integer.compare(this.value, other.value)`, which is safe regardless of sign.

---

> **Common Mistake — Integer subtraction in `compareTo()`:** `return this.value - other.value` produces the wrong ordering for large negative values due to integer overflow. The consequence is silent data corruption in sorted collections — elements appear in the wrong order with no exception thrown.

**Quick Revision (one line):** `Comparable` = one natural order inside the class (`compareTo`); `Comparator` = external, chainable, multiple orderings (`compare`); never subtract integers — use `Integer.compare()`.

---

## Topic 20: CopyOnWriteArrayList

**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Amazon, Netflix, event-driven architecture interviews

---

### The Idea

Imagine a whiteboard in a meeting room. When you read it, you just look — no one needs to stop. When you want to erase and redraw, you photo-copy the entire board first, make changes on the copy, then swap it in as the new board. Everyone who was reading the old board continues undisturbed. That is exactly `CopyOnWriteArrayList`.

Every write operation (add, set, remove) acquires a lock, copies the entire backing array, applies the change to the copy, then atomically replaces the reference. All reads operate directly on whatever array reference they captured — no lock needed. This means reads are completely non-blocking and never contend with each other or with ongoing writes.

The cost is obvious: writes are O(n) in time and memory. For a list of 10,000 elements, every `add()` allocates and copies 10,000 slots. This is acceptable only when writes are rare. The canonical use case is a list of event listeners or HTTP filters: registered at startup (a few writes), invoked on every request (millions of reads).

### How It Works

```
Backing store: volatile Object[] array

add(e) — WRITE PATH:
  1. acquire ReentrantLock
  2. snapshot = getArray()              // get current array reference
  3. newArray = Arrays.copyOf(snapshot, snapshot.length + 1)
  4. newArray[last] = e
  5. setArray(newArray)                 // volatile write → visible to all threads
  6. release lock
  → Cost: O(n) time + O(n) memory per write

get(i) — READ PATH:
  1. array = getArray()                 // volatile read — no lock
  2. return array[i]
  → Cost: O(1), lock-free

iterator() — SNAPSHOT PATH:
  1. capture current array reference at creation time
  2. iterate over that snapshot
  → Concurrent writes create NEW arrays; the iterator's snapshot is unaffected
  → Never throws ConcurrentModificationException
  → May NOT see elements added after the iterator was created
```

The single most interview-critical gotcha — writes are O(n), not O(1):

```java
// WRONG use case — high write frequency destroys performance
CopyOnWriteArrayList<String> log = new CopyOnWriteArrayList<>();
for (int i = 0; i < 100_000; i++) {
    log.add("entry-" + i);  // copies entire list 100,000 times → O(n²) total work!
}

// RIGHT use case — many reads, rare writes
CopyOnWriteArrayList<EventListener> listeners = new CopyOnWriteArrayList<>();
// At startup: register a handful of listeners (few writes, O(n) cost absorbed)
listeners.add(e -> handleEvent(e));
// At runtime: called millions of times per second (lock-free reads)
for (EventListener l : listeners) { l.onEvent(event); }
```

**Performance summary:**

| Operation | Complexity | Locking |
|---|---|---|
| `get(i)` | O(1) | None — lock-free |
| `contains(o)` | O(n) | None — lock-free |
| `add(e)` | O(n) — full array copy | Yes |
| `remove(i)` | O(n) — full array copy | Yes |
| Iteration | O(n) | None — snapshot |

**vs `Collections.synchronizedList()`:**

| Property | CopyOnWriteArrayList | synchronizedList |
|---|---|---|
| Read locking | None (lock-free) | Full lock on every read |
| Write locking | Full lock + copy | Full lock |
| Iteration safety | No lock (snapshot) | Must hold lock externally |
| ConcurrentModificationException | Never | Possible if not locked |
| Best for | Read-heavy, rare writes | Balanced or write-heavy |

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"How does `CopyOnWriteArrayList` achieve thread safety for reads without locking?"**

**One-line answer:** The backing array reference is `volatile` — reads see the latest array atomically without any lock — and writers always swap in a new array rather than mutating the existing one.

**Full answer to give in an interview:**
> `CopyOnWriteArrayList` stores its data in a `volatile Object[]` field. When I call `get(i)`, the implementation reads that volatile reference and accesses the element — no lock is acquired. The volatile keyword guarantees two things: every write to the reference is immediately visible to all threads, and reads are never reordered past the write. When a write operation happens (say `add()`), it acquires a `ReentrantLock`, copies the entire array into a new array of size n+1, appends the new element, then does a volatile write to swap the reference. Any thread already in the middle of reading the old array continues with the old array safely — it is immutable from that point on. This is the "copy-on-write" guarantee: the array currently being read is never mutated, only replaced. There are no data races on reads because the array bytes themselves are never modified once published.

*Key vocabulary: volatile, immutable snapshot, reference swap. Use all three.*

**Gotcha follow-up they'll ask:** *"Does `CopyOnWriteArrayList`'s iterator throw `ConcurrentModificationException`?"*

> No. When I call `iterator()`, it captures the current array reference as a snapshot. Subsequent writes create new arrays; the iterator keeps walking the old snapshot. Since the snapshot is never modified, there is no modification count to check and no exception to throw. The trade-off is that the iterator may not see elements added after it was created — it is effectively stale the moment a write occurs.

---

#### Q2 — Tradeoff Question

**"When would `CopyOnWriteArrayList` be a bad choice, and what would you use instead?"**

**One-line answer:** Any write-heavy scenario — the O(n) copy per write makes it O(n²) for n sequential writes; use `Collections.synchronizedList()` or a `ConcurrentLinkedQueue` instead.

**Full answer to give in an interview:**
> `CopyOnWriteArrayList` becomes catastrophically slow when writes are frequent. Each `add()` copies the entire backing array. If I add 100,000 elements sequentially, the total work is 1 + 2 + 3 + … + 100,000 = ~5 billion operations — O(n²). Memory pressure is also significant: every write allocates a new array, generating heavy garbage collection activity. For a write-heavy concurrent list, I would use `Collections.synchronizedList(new ArrayList<>())` which locks the whole list on every operation but avoids the copy cost, or `ConcurrentLinkedQueue` if FIFO order is acceptable. For a map-like structure with read-heavy access I would use `ConcurrentHashMap`. The read-to-write ratio threshold where CopyOnWriteArrayList becomes worth it is roughly in the thousands — tens of thousands of reads per write.

*State the O(n²) consequence quantitatively — it is much more convincing than just saying "it's slow."*

**Gotcha follow-up they'll ask:** *"Is `CopyOnWriteArrayList` suitable as a cache that is refreshed every 30 seconds?"*

> Yes — that is a good use case. The cache is read many times per second and refreshed rarely. On refresh, the entire list is replaced (one write, O(n)). All reads between refreshes are lock-free. The snapshot semantics mean in-flight reads at the moment of refresh continue with the old data — which is fine for a cache. This is essentially how Spring's `ApplicationContext` stores event listeners.

---

#### Q3 — Design Scenario

**"Design a thread-safe event listener registry in Java where listeners are registered once at startup and invoked millions of times per second during request handling."**

**One-line answer:** Use `CopyOnWriteArrayList<Listener>` — lock-free iteration for the hot path, rare O(n) copies only on registration.

**Full answer to give in an interview:**
> This is the textbook case for `CopyOnWriteArrayList`. At application startup, I register a small number of listeners — `listeners.add(l)` — which triggers the copy-on-write mechanism. The cost is proportional to the number of already-registered listeners, which is small. During request handling, I iterate with a for-each loop: `for (Listener l : listeners) { l.onEvent(event); }`. This iteration is entirely lock-free — the for-each captures the current array snapshot and walks it, so millions of concurrent threads can iterate simultaneously with no contention. If a listener is added or removed at runtime (rare), it creates a new array and atomically swaps the reference. Threads already iterating continue with their snapshot, and the next iteration picks up the new array. The registry is naturally thread-safe with no explicit synchronization needed in the calling code. I would NOT use `Collections.synchronizedList()` here because every read would acquire a lock, serializing all listener invocations and creating a bottleneck under high concurrency.

*Explicitly contrasting with synchronizedList shows architectural judgment.*

**Gotcha follow-up they'll ask:** *"What if a listener throws an exception during event dispatch — does it affect other listeners?"*

> That is an application-level concern, not a `CopyOnWriteArrayList` concern. The list itself is unaffected — an exception in one listener does not corrupt the list or the iteration. I would wrap each listener call in a try-catch inside the loop to ensure one failing listener does not abort dispatch to the remaining ones. This defensive pattern is common in Spring's `SimpleApplicationEventMulticaster`.

---

> **Common Mistake — Using `CopyOnWriteArrayList` in a write-heavy loop:** Every `add()` copies the entire array. In a loop adding n elements, the total cost is O(n²) time and O(n²) bytes allocated, triggering heavy GC. The consequence is application-level slowdown that worsens non-linearly as the list grows.

**Quick Revision (one line):** `CopyOnWriteArrayList` = lock-free reads via volatile array reference, O(n) write via lock + full copy; iterator never throws `ConcurrentModificationException`; ideal for read-heavy rarely-modified lists like event listeners.

---

## Topic 21: BlockingQueue

**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Amazon, Uber, backend systems design rounds

---

### The Idea

A `BlockingQueue` is a thread-safe queue with a special superpower: if you try to take from an empty queue, your thread blocks (sleeps) until something arrives. If you try to put into a full queue, your thread blocks until space opens up. This built-in blocking behaviour eliminates the need for manual `wait/notify` loops and is the standard way to implement the producer-consumer pattern in Java.

Think of it as a loading dock with a fixed number of parking bays. Delivery trucks (producers) pull in, drop off parcels, and leave. Workers (consumers) pick up parcels. If all bays are full, the next truck waits outside until a bay opens. If all bays are empty, the next worker waits until a truck arrives. No busy-waiting, no polling, no explicit synchronization — the queue handles all of it.

The two most common implementations differ in their internal locking. `ArrayBlockingQueue` uses a single lock for both put and take — producers and consumers contend with each other. `LinkedBlockingQueue` uses two separate locks (one for put, one for take) — producers and consumers can proceed simultaneously, giving higher throughput under concurrent load.

### How It Works

```
BlockingQueue<T> method matrix:

                   | On FULL queue        | On EMPTY queue
-------------------|----------------------|-------------------
add(e)/remove()    | throws IllegalState  | throws NoSuchElement
offer(e)/poll()    | returns false/null   | returns false/null
put(e)/take()      | BLOCKS indefinitely  | BLOCKS indefinitely
offer(e,t,u)/      | blocks up to timeout | blocks up to timeout
poll(t,u)          |                      |

ArrayBlockingQueue:
  - backed by fixed-size circular Object[] array
  - single ReentrantLock for both put and take → producers and consumers contend
  - optional fairness flag: FIFO among waiting threads (default: false)
  - always bounded — capacity set at construction

LinkedBlockingQueue:
  - backed by linked nodes
  - separate putLock and takeLock → producers and consumers can run concurrently
  - default capacity: Integer.MAX_VALUE (effectively unbounded unless specified)
  - higher throughput than ArrayBlockingQueue under concurrent producer+consumer load

SynchronousQueue:
  - capacity = 0
  - every put() blocks until a matching take() arrives (and vice versa)
  - direct thread-to-thread handoff with no buffering
  - used by Executors.newCachedThreadPool() for task submission

PriorityBlockingQueue:
  - unbounded, orders by Comparable / Comparator
  - put() never blocks (unbounded), take() blocks when empty

Backpressure mechanism:
  producer calls put(e)
  → if queue full → producer thread suspends (via Condition.await())
  → when consumer calls take() → queue signals putLock condition
  → producer resumes
  → natural backpressure: producers slow down when consumers are falling behind
```

The single most interview-critical gotcha — `offer()` vs `put()` silent data loss:

```java
BlockingQueue<Task> queue = new ArrayBlockingQueue<>(10);

// DANGEROUS — offer() returns false silently when queue is full
boolean added = queue.offer(task);
if (!added) {
    // task is DROPPED — no exception, no retry
    log.warn("Queue full, task dropped: " + task);
}

// CORRECT for producer-consumer — put() blocks until space is available
queue.put(task);  // blocks if full, resumes when consumer frees space

// CORRECT for bounded wait — timed offer prevents infinite blocking
boolean accepted = queue.offer(task, 5, TimeUnit.SECONDS);
if (!accepted) {
    // decide: retry, reject, or alert — but at least you know
    throw new RejectedExecutionException("Queue saturated");
}
```

**Implementation comparison:**

| Feature | ArrayBlockingQueue | LinkedBlockingQueue | SynchronousQueue |
|---|---|---|---|
| Capacity | Always bounded | Optional (default: MAX_VALUE) | Zero |
| Locking | Single lock | Two locks (put + take) | CAS / transfer |
| Throughput | Lower under contention | Higher under contention | Highest (no buffering) |
| Memory | Fixed array | Grows with elements | Minimal |
| Fairness option | Yes | No | Yes |
| Use case | Bounded work queue | General producer-consumer | Thread pool handoff |

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is the difference between `put()`, `offer()`, and `add()` in `BlockingQueue`?"**

**One-line answer:** `put()` blocks indefinitely when full; `offer()` returns false immediately (or after a timeout); `add()` throws an exception — choose based on whether the caller can tolerate waiting, losing a message, or receiving an exception.

**Full answer to give in an interview:**
> `BlockingQueue` provides three families of enqueue methods to cover different failure-handling strategies. `add(e)` follows the `Collection` contract — it throws `IllegalStateException` if the queue is full. This is appropriate when the caller is not prepared to handle backpressure and an exception is the correct signal. `offer(e)` returns `false` if the queue is full without throwing. There is also a timed variant, `offer(e, timeout, unit)`, that blocks for up to the given duration before returning false. This is useful when I want a bounded wait without blocking indefinitely. `put(e)` blocks the calling thread indefinitely until space is available — it is interruptible, so it throws `InterruptedException` if the thread is interrupted while waiting. In a producer-consumer system where I want natural backpressure — producers slow down when consumers are falling behind — `put()` is the right choice. If I want a best-effort non-blocking attempt with explicit rejection handling, I use the timed `offer()` variant.

*The key insight is that each method implements a different backpressure strategy.*

**Gotcha follow-up they'll ask:** *"What happens if a thread is blocked in `put()` and another thread calls `Thread.interrupt()` on it?"*

> `put()` is interruptible — it throws `InterruptedException` immediately when the thread's interrupt flag is set. The correct idiom in the catch block is `Thread.currentThread().interrupt()` to restore the interrupt status, so higher-level code can detect and handle the interruption. Swallowing the exception without restoring the flag is a bug — the thread's interrupt status is cleared and the interruption signal is silently lost.

---

#### Q2 — Tradeoff Question

**"When would you choose `ArrayBlockingQueue` vs `LinkedBlockingQueue`?"**

**One-line answer:** `ArrayBlockingQueue` for bounded capacity with fairness control; `LinkedBlockingQueue` for higher throughput under concurrent producers and consumers due to its two-lock design.

**Full answer to give in an interview:**
> The key architectural difference is locking. `ArrayBlockingQueue` uses a single `ReentrantLock` for both the put side and the take side. This means a producer adding an element and a consumer removing one contend on the same lock and cannot execute simultaneously. `LinkedBlockingQueue` uses two separate locks — `putLock` and `takeLock`. Producers lock only the put side; consumers lock only the take side. When the queue has elements and space, a producer and consumer can execute in parallel, which nearly doubles throughput under concurrent load. I choose `ArrayBlockingQueue` when I need strict bounded capacity (it is always bounded) and optionally need fairness — the ability to guarantee FIFO order among threads waiting to put or take. I choose `LinkedBlockingQueue` when throughput is the priority, the queue may be large, and I can tolerate the slightly higher per-node memory overhead of linked nodes. One practical note: `LinkedBlockingQueue` defaults to `Integer.MAX_VALUE` capacity — I should always specify an explicit bound in production to prevent unbounded memory growth if consumers fall behind.

*The two-lock vs one-lock distinction is the main technical differentiator interviewers test.*

**Gotcha follow-up they'll ask:** *"What is `SynchronousQueue` and where is it used in the JDK?"*

> `SynchronousQueue` has a capacity of zero — it buffers nothing. A `put()` blocks until another thread calls `take()`, and vice versa. It is a direct handoff mechanism. The JDK uses it in `Executors.newCachedThreadPool()`: submitted tasks are handed directly to an idle thread. If no idle thread exists, a new one is created. If idle threads exist, the handoff is immediate with no queuing overhead.

---

#### Q3 — Design Scenario

**"Design a rate-limited task processor that accepts tasks from multiple producers but processes at most 100 tasks concurrently. Tasks should not be dropped; producers should slow down naturally if processing falls behind."**

**One-line answer:** Use a bounded `ArrayBlockingQueue` with `put()` for producers and a fixed-size thread pool consuming via `take()` — the queue's bounded capacity provides natural backpressure.

**Full answer to give in an interview:**
> I would use an `ArrayBlockingQueue<Task>` with capacity 100 as the work queue, and a pool of consumer threads that each loop on `queue.take()`. Producers call `queue.put(task)` — when all 100 slots are full, producers block automatically. This is backpressure built into the data structure: there is no polling, no sleep loops, and no explicit signaling. The producers slow down exactly as fast as the consumers need them to. For the consumer side I could use `Executors.newFixedThreadPool(N)` with a custom `BlockingQueue` injected into a `ThreadPoolExecutor`, or manage consumer threads manually. I would choose `ArrayBlockingQueue` over `LinkedBlockingQueue` here because I want strict bounded capacity and the single-lock contention is acceptable when N consumers are all competing on the same take-side lock — with 100 consumers that could become a bottleneck, in which case I would switch to `LinkedBlockingQueue`. I would also add a timed `offer()` path for emergency overflow handling — if the queue is full for more than 30 seconds it signals a systemic backlog that warrants alerting, not indefinite blocking.

*Mentioning the switch to LinkedBlockingQueue at high consumer count shows you think about scale.*

**Gotcha follow-up they'll ask:** *"How does `BlockingQueue` implement the blocking in `put()` internally?"*

> Internally it uses `java.util.concurrent.locks.Condition`. For `ArrayBlockingQueue`, there are two `Condition` objects: `notFull` (producers wait on this when the queue is full) and `notEmpty` (consumers wait on this when the queue is empty). When a producer calls `put()` and the queue is full, it calls `notFull.await()`, which releases the lock and suspends the thread. When a consumer removes an element, it calls `notFull.signal()` to wake one waiting producer. This is a clean, efficient alternative to `Object.wait()/notify()` and is entirely encapsulated inside the queue implementation.

---

> **Common Mistake — Using `offer()` in a producer-consumer pipeline and ignoring the return value:** If `offer()` returns false the task is silently dropped — no exception, no retry, no log unless you code it explicitly. In a pipeline this means data loss. Always use `put()` for backpressure, or handle the `false` return from `offer()` explicitly.

**Quick Revision (one line):** `BlockingQueue` blocks producers (`put`) when full and consumers (`take`) when empty; `ArrayBlockingQueue` = bounded, single lock; `LinkedBlockingQueue` = optionally bounded, two locks, higher throughput; natural backpressure with no manual synchronization.

---

## Topic 22: Master Comparison Table

**Difficulty:** Easy | **Frequency:** High | **Companies:** All companies — standard Java interview reference

---

### The Idea

Java's Collections Framework has over a dozen commonly used implementations across List, Set, Map, and Queue. In interviews, you will almost always be asked to choose the right one for a given scenario — or to explain why one is better than another. This topic is a reference and decision-making tool, not a deep dive. The goal is to look at a requirement and immediately know which collection fits.

The three axes that drive every choice are: ordering requirements (none, insertion order, sorted), thread safety needs (none, read-heavy, write-heavy, fully concurrent), and performance characteristics (O(1) vs O(log n) lookups, amortized vs worst-case). Understanding which axis matters most for a given problem is what separates a junior answer from a senior one.

The decision tree at the end translates the table into a practical flowchart. In an interview, walking the interviewer through the decision tree ("I need sorted keys, so I'd use TreeMap; but if the interviewer adds concurrency requirements I'd switch to ConcurrentSkipListMap") demonstrates systematic thinking rather than memorisation.

### How It Works

**Master comparison table:**

| Collection | Thread Safe | Ordering | Null Keys | Null Values | `get` | `add`/`put` | `remove` | Backed By |
|---|---|---|---|---|---|---|---|---|
| ArrayList | No | Insertion | N/A | Yes | O(1) | O(1) amortized | O(n) | Object[] |
| LinkedList | No | Insertion | N/A | Yes | O(n) | O(1) head/tail | O(1) if at ends | Doubly linked list |
| ArrayDeque | No | Insertion | N/A | No | O(1) head/tail | O(1) amortized | O(1) head/tail | Object[] circular |
| HashSet | No | None | Yes (1 null) | N/A | O(1) avg | O(1) avg | O(1) avg | HashMap |
| LinkedHashSet | No | Insertion | Yes (1 null) | N/A | O(1) avg | O(1) avg | O(1) avg | LinkedHashMap |
| TreeSet | No | Sorted | No | N/A | O(log n) | O(log n) | O(log n) | TreeMap (RB tree) |
| HashMap | No | None | Yes (1 null) | Yes | O(1) avg | O(1) avg | O(1) avg | Array + list/tree |
| LinkedHashMap | No | Insertion or Access | Yes (1 null) | Yes | O(1) avg | O(1) avg | O(1) avg | HashMap + doubly linked |
| TreeMap | No | Sorted | No | Yes | O(log n) | O(log n) | O(log n) | Red-Black tree |
| Hashtable | Yes (full lock) | None | No | No | O(1) avg | O(1) avg | O(1) avg | Array + list (legacy) |
| ConcurrentHashMap | Yes (per-bucket) | None | No | No | O(1) avg | O(1) avg | O(1) avg | Array + list/tree |
| CopyOnWriteArrayList | Yes (write-lock) | Insertion | N/A | Yes | O(1) | O(n) | O(n) | Object[] (copy on write) |
| PriorityQueue | No | Priority | N/A | No | O(1) peek | O(log n) | O(log n) | Object[] min-heap |
| ArrayBlockingQueue | Yes | FIFO | N/A | No | O(1) | O(1)/blocks | O(1)/blocks | Object[] circular |
| LinkedBlockingQueue | Yes | FIFO | N/A | No | O(1) | O(1)/blocks | O(1)/blocks | Doubly linked list |
| PriorityBlockingQueue | Yes | Priority | N/A | No | O(1) peek | O(log n) | O(log n) | Object[] min-heap |

**Key notes:**
- "Yes (1 null)" = exactly one null key allowed.
- "O(1) avg" = O(1) average; O(log n) worst case in Java 8+ due to treeification at 8+ collisions.
- `ConcurrentHashMap` reads are always lock-free; writes lock only the affected bucket segment.
- `LinkedHashMap` in access-order mode enables LRU cache behaviour via `removeEldestEntry()`.
- `ArrayDeque` is the preferred Stack and Queue replacement over `Stack` and `LinkedList`.

**Interview decision tree:**

```
Need a List?
├── Thread-safe, rare writes → CopyOnWriteArrayList
├── Thread-safe, frequent writes → Collections.synchronizedList(ArrayList)
├── Stack or Deque operations → ArrayDeque
├── Random access heavy → ArrayList (pre-size if count known)
└── Only head/tail ops → ArrayDeque (NOT LinkedList)

Need a Set?
├── No ordering → HashSet
├── Insertion order → LinkedHashSet
└── Sorted order / range queries → TreeSet

Need a Map?
├── Single-threaded → HashMap (pre-size: new HashMap<>(expectedSize / 0.75 + 1))
├── Insertion order → LinkedHashMap
├── LRU cache → LinkedHashMap (access-order + removeEldestEntry)
├── Sorted keys / range queries → TreeMap
└── Multi-threaded → ConcurrentHashMap (NOT Hashtable)

Need a Queue?
├── Priority order → PriorityQueue
├── Thread-safe blocking, bounded → ArrayBlockingQueue
├── Thread-safe blocking, high throughput → LinkedBlockingQueue
└── Direct thread-to-thread handoff → SynchronousQueue
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is the difference between `Hashtable`, `Collections.synchronizedMap(HashMap)`, and `ConcurrentHashMap` in terms of thread safety?"**

**One-line answer:** All three are thread-safe, but `ConcurrentHashMap` is the only one that allows concurrent reads and fine-grained writes without global locking — the others lock the entire map on every operation.

**Full answer to give in an interview:**
> `Hashtable` is a legacy class that synchronises every method on `this` — a full lock on every `get`, `put`, and `remove`. This means only one thread can touch the map at a time. `Collections.synchronizedMap(new HashMap<>())` wraps a HashMap and produces the same behaviour: every method is synchronised on a mutex object. Both are equivalent for correctness but terrible for concurrency. `ConcurrentHashMap`, introduced in Java 5 and redesigned in Java 8, is fundamentally different. Reads are entirely lock-free — they never acquire any lock. Writes lock only the individual bucket (the array slot) being modified, not the whole map. In Java 8+, when a bucket grows beyond eight entries it becomes a red-black tree, but the locking granularity remains at the bucket level. The result is that a 16-bucket `ConcurrentHashMap` can support 16 concurrent writes without any contention. For read-heavy applications this is orders of magnitude faster than a `synchronizedMap`. The trade-off: `ConcurrentHashMap` does not allow null keys or null values (unlike `HashMap`), and compound operations like "check-then-act" must use atomic methods like `putIfAbsent()` and `computeIfAbsent()` to remain correct.

*End with the null-key caveat and the atomic methods — those are the follow-up questions.*

**Gotcha follow-up they'll ask:** *"Why does `ConcurrentHashMap` not allow null keys or null values?"*

> Because null introduces an ambiguity. If `map.get(key)` returns `null`, it could mean the key was explicitly mapped to `null`, or it could mean the key is absent. In a single-threaded `HashMap` I can disambiguate with `map.containsKey(key)`. In a concurrent setting, another thread could remove the key between the `get` and the `containsKey` call, making the check unreliable. By prohibiting null altogether, `ConcurrentHashMap` eliminates the ambiguity — a `null` return from `get()` unambiguously means the key is absent.

---

#### Q2 — Tradeoff Question

**"You need to implement an LRU cache that evicts the least-recently-used entry when capacity is exceeded. Which Java collection would you use as the basis, and why?"**

**One-line answer:** `LinkedHashMap` with access-order mode and an overridden `removeEldestEntry()` — it maintains access order internally and auto-evicts the eldest entry in O(1).

**Full answer to give in an interview:**
> `LinkedHashMap` can be constructed with `accessOrder = true`: `new LinkedHashMap<>(capacity, 0.75f, true)`. In this mode it maintains a doubly-linked list where the most-recently-accessed entry moves to the tail and the least-recently-accessed entry stays at the head. Every `get()` and `put()` updates the list in O(1). To add LRU eviction I override `removeEldestEntry()`: `protected boolean removeEldestEntry(Map.Entry<K,V> eldest) { return size() > maxCapacity; }`. After each `put()`, the map calls this method and, if it returns `true`, automatically removes the head entry (the LRU item) in O(1). This gives a complete LRU cache in fewer than 10 lines with no external data structures. For a thread-safe LRU cache I would wrap it with `Collections.synchronizedMap()` — but for high-concurrency use cases, Caffeine (`com.github.ben-manes.caffeine`) is the production-grade library that provides lock-free LRU semantics using a Window-TinyLFU policy.

*Mentioning Caffeine distinguishes a production-aware answer from a textbook one.*

**Gotcha follow-up they'll ask:** *"Would you use `LinkedHashMap` for a thread-safe LRU cache in a high-concurrency system?"*

> Not directly. `Collections.synchronizedMap(LinkedHashMap)` serialises all access on one lock, which creates a bottleneck under high concurrency. For high-throughput systems I would use the Caffeine library, which implements a near-optimal eviction policy with lock-free reads. Caffeine is used by Spring's `CaffeineCache` and Guava's `CacheBuilder` internally. If I cannot add a dependency, `ConcurrentHashMap` with a `ConcurrentLinkedDeque` for order tracking is a workable manual implementation, though complex.

---

#### Q3 — Design Scenario

**"You are building a leaderboard service that must rank users by score (highest first) and support O(log n) insert and O(1) peek at the top player. Which collection do you use and why?"**

**One-line answer:** `PriorityQueue` with a max-heap Comparator for O(log n) insert and O(1) peek, or `TreeMap<Integer, List<User>>` if you need range queries on scores.

**Full answer to give in an interview:**
> For a simple leaderboard where I only need to peek at the top player and insert new scores, `PriorityQueue` with a reversed comparator (max-heap) is ideal. `queue.peek()` returns the highest-scoring user in O(1) without removing them. Insertion is O(log n). However, `PriorityQueue` has limitations: it does not support random access by rank (O(n) for "give me the 5th-place user"), and it does not support efficient deletion of an arbitrary user (also O(n) because it has to find the element first). For a full leaderboard where I need rank queries and score range queries — "show users ranked 10 through 20" — I would use `TreeMap<Integer, List<User>>` keyed by score descending. `TreeMap` is backed by a Red-Black tree, giving O(log n) insert, O(log n) lookup by score, and O(log n) range queries via `subMap()`. For a production-scale global leaderboard I would use Redis Sorted Sets (ZSet), which supports all these operations at scale with built-in persistence and replication.

*Ending with Redis shows you think beyond the JDK for production systems.*

**Gotcha follow-up they'll ask:** *"Why does `PriorityQueue` default to a min-heap and how do you make it a max-heap?"*

> By default, `PriorityQueue` orders elements using their natural ordering (`Comparable.compareTo()`), which places the smallest element at the head — a min-heap. To make it a max-heap I pass a reversed comparator to the constructor: `new PriorityQueue<>(Comparator.reverseOrder())` for `Comparable` types, or `new PriorityQueue<>((a, b) -> Integer.compare(b.score, a.score))` for custom objects. The heap property is maintained internally via sift-up on insert and sift-down on remove.

---

> **Common Mistake — Using `Hashtable` or `synchronizedMap` instead of `ConcurrentHashMap` for concurrent access:** Both lock the entire map on every operation, serialising all threads. Under any meaningful concurrency this creates a throughput bottleneck. `ConcurrentHashMap` provides the same thread safety with per-bucket locking and lock-free reads — it should be the default for any concurrent map use case in modern Java.

**Quick Revision (one line):** Know the three axes — ordering, thread safety, and O-complexity — for each collection; default to `HashMap/ArrayList/ArrayDeque` for single-threaded use and `ConcurrentHashMap/CopyOnWriteArrayList/BlockingQueue` for concurrent use; `LinkedHashMap` with access-order = LRU cache in 10 lines.

---

*End of Chapter 3: Collections*

