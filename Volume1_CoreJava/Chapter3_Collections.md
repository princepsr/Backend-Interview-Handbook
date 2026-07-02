# Chapter 3: Java Collections Framework

**Target Audience:** Java SDE2 candidates (2–5 years experience)  
**Java Version:** Java 17 LTS  
**Interview Focus:** FAANG+, FinTech, SaaS/Enterprise

---

## Table of Contents

1. [ArrayList Internals](#1-arraylist-internals)
2. [LinkedList Internals](#2-linkedlist-internals)
3. [ArrayList vs LinkedList](#3-arraylist-vs-linkedlist)
4. [HashSet Internals](#4-hashset-internals)
5. [LinkedHashSet](#5-linkedhashset)
6. [TreeSet](#6-treeset)
7. [HashMap Internals (Java 8+)](#7-hashmap-internals-java-8)
8. [HashMap Performance](#8-hashmap-performance)
9. [LinkedHashMap](#9-linkedhashmap)
10. [TreeMap](#10-treemap)
11. [ConcurrentHashMap](#11-concurrenthashmap)
12. [HashMap vs Hashtable vs ConcurrentHashMap](#12-hashmap-vs-hashtable-vs-concurrenthashmap)
13. [PriorityQueue](#13-priorityqueue)
14. [ArrayDeque](#14-arraydeque)
15. [Fail-fast vs Fail-safe Iterators](#15-fail-fast-vs-fail-safe-iterators)
16. [ListIterator](#16-listiterator)
17. [Collections Utility Class](#17-collections-utility-class)
18. [Arrays Utility Class](#18-arrays-utility-class)
19. [Comparable vs Comparator](#19-comparable-vs-comparator)
20. [CopyOnWriteArrayList](#20-copyonwritearraylist)
21. [BlockingQueue](#21-blockingqueue)
22. [Master Comparison Table](#22-master-comparison-table)

---

## 1. ArrayList Internals

**Difficulty:** Medium | **Interview Frequency:** Very High  
**Asked at:** Amazon, Google, Microsoft, Goldman Sachs, JPMorgan, Salesforce, Uber

### Short Interview Answer (30–60 seconds)

ArrayList is backed by a plain Object array. It starts with a default initial capacity of 10. When you add an element that exceeds the current capacity, it creates a new array of size `oldCapacity * 1.5 + 1` (approximately 1.5x growth), copies all existing elements using `System.arraycopy`, and then adds the new element. Because most adds do not trigger a resize, the amortized time complexity for `add()` is O(1).

### Deep Explanation

**Internal Structure:**

```
transient Object[] elementData;   // the backing array
private int size;                 // logical size, not array length
```

The backing array is marked `transient` so custom serialization (`writeObject`/`readObject`) can avoid serializing unused slots at the end.

**Initial Capacity:**

When you call `new ArrayList<>()`, the backing array is initialized to a shared empty array constant (`DEFAULTCAPACITY_EMPTY_ELEMENTDATA`). The first `add()` call triggers a grow to exactly 10. This lazy initialization avoids allocating 10-slot arrays that might never be used.

```java
// From OpenJDK source (simplified)
private static final int DEFAULT_CAPACITY = 10;
private static final Object[] DEFAULTCAPACITY_EMPTY_ELEMENTDATA = {};
```

**Growth Formula:**

```java
// OpenJDK ArrayList.grow()
private Object[] grow(int minCapacity) {
    int oldCapacity = elementData.length;
    if (oldCapacity > 0 || elementData != DEFAULTCAPACITY_EMPTY_ELEMENTDATA) {
        int newCapacity = ArraysSupport.newLength(oldCapacity,
                minCapacity - oldCapacity,   // minimum growth
                oldCapacity >> 1);           // preferred growth = oldCapacity / 2
        return elementData = Arrays.copyOf(elementData, newCapacity);
    } else {
        return elementData = new Object[Math.max(DEFAULT_CAPACITY, minCapacity)];
    }
}
```

The `oldCapacity >> 1` is a right-bit-shift equivalent to integer division by 2. So the new capacity is approximately `oldCapacity + oldCapacity/2 = 1.5 * oldCapacity`.

**Why `System.arraycopy` and not a loop?**

`System.arraycopy` is a native JVM intrinsic. It uses the underlying platform's memory copy instruction (e.g., `memcpy` on Linux), making it significantly faster than element-by-element copying, especially for large arrays.

**Amortized O(1) Analysis:**

Suppose we start with capacity 1 and double each time (for simplicity). After n elements:
- Copies performed: 1 + 2 + 4 + ... + n/2 = n - 1
- Total cost across n insertions: O(n)
- Amortized cost per insertion: O(n)/n = O(1)

The 1.5x growth factor (as opposed to 2x used in some languages) trades off slightly more frequent resizes for lower memory waste.

**Random Access:**

`get(int index)` is O(1) because it directly accesses `elementData[index]`. This is contiguous memory, which is CPU-cache friendly.

**Remove:**

`remove(int index)` is O(n) because elements to the right of the removed index must shift left by one position using `System.arraycopy`. Removing the last element is O(1).

### Real-World Backend Example

In a REST API returning paginated results, you build a response list by iterating a database cursor and appending to an ArrayList. Since you only append (and occasionally read by index), ArrayList is ideal. If you know the approximate count from a `COUNT(*)` query, pre-sizing with `new ArrayList<>(estimatedSize)` eliminates all resize operations.

### Java 17 Code Example

```java
import java.util.ArrayList;
import java.util.List;

public class ArrayListInternals {

    public static void main(String[] args) {
        // Default capacity: 10 (allocated lazily on first add)
        ArrayList<String> list = new ArrayList<>();

        // Pre-size when count is known — avoids all resizes
        int estimatedSize = 500;
        ArrayList<String> preSized = new ArrayList<>(estimatedSize);

        // Amortized O(1) add
        for (int i = 0; i < 1000; i++) {
            list.add("item-" + i);
        }

        // O(1) get — direct array index
        String item = list.get(42);

        // O(n) remove by index — shifts remaining elements left
        list.remove(0);

        // O(1) remove last element
        list.remove(list.size() - 1);

        // Trim to exact size — useful before long-term caching
        list.trimToSize();

        // ensureCapacity — hint to pre-allocate before bulk add
        list.ensureCapacity(2000);

        System.out.println("Size: " + list.size());
    }
}
```

### Follow-up Questions Interviewers Ask

1. What is the difference between `size()` and `capacity()` in ArrayList?
2. If you call `new ArrayList<>(0)`, when does the first resize happen?
3. How does ArrayList handle concurrent modification? What exception is thrown?
4. When would you call `trimToSize()`?
5. What is the maximum size of an ArrayList?

### Common Mistakes Candidates Make

- Saying the growth factor is exactly 2x (it is approximately 1.5x in Java).
- Saying initial capacity is 10 even for `new ArrayList<>(0)` — no, it grows to 10 only for the default constructor on first add.
- Confusing `size` (number of elements) with `capacity` (length of backing array).
- Claiming `remove(Object o)` is O(1) — it is O(n) because it must search first, then shift.

### Interview Traps

- **Trap:** "Is `add(E e)` always O(1)?" — Correct answer: O(1) amortized, O(n) worst case during resize.
- **Trap:** "Is ArrayList thread-safe?" — No. Use `Collections.synchronizedList()` or `CopyOnWriteArrayList`.
- **Trap:** "What happens to capacity after `clear()`?" — `clear()` sets all elements to null and sets `size = 0`, but does NOT reduce capacity. The backing array retains its current length.

### Quick Revision Notes

- Backed by `Object[]`; default capacity 10 (lazy); growth ~1.5x.
- `add()` is O(1) amortized, O(n) worst; `get()` is O(1); `remove(index)` is O(n).
- `System.arraycopy` is used for resize and shift operations — native intrinsic.
- Not thread-safe. Pre-size with `new ArrayList<>(n)` when count is known.

---

## 2. LinkedList Internals

**Difficulty:** Medium | **Interview Frequency:** High  
**Asked at:** Amazon, Adobe, Flipkart, Paytm, Morgan Stanley

### Short Interview Answer (30–60 seconds)

LinkedList is implemented as a doubly linked list. Each element is wrapped in a `Node` object containing a reference to the element, the previous node, and the next node. The class maintains a `first` (head) and `last` (tail) pointer. Adding or removing at either end is O(1). Random access by index requires traversal from head or tail, making `get(int index)` O(n).

### Deep Explanation

**Node Structure (from OpenJDK):**

```java
private static class Node<E> {
    E item;
    Node<E> next;
    Node<E> prev;

    Node(Node<E> prev, E element, Node<E> next) {
        this.item = element;
        this.next = next;
        this.prev = prev;
    }
}
```

Each `Node` adds ~32 bytes of overhead on a 64-bit JVM (object header, three references). For a list of 1 million integers, LinkedList consumes roughly 5x more memory than ArrayList due to this per-node overhead.

**Class Fields:**

```java
transient int size = 0;
transient Node<E> first;    // head pointer
transient Node<E> last;     // tail pointer
```

**O(1) Operations:**

- `addFirst(E)` / `addLast(E)` — adjusts head/tail pointer, O(1).
- `removeFirst()` / `removeLast()` — adjusts head/tail pointer, O(1).
- `peekFirst()` / `peekLast()` — reads head/tail item, O(1).

**O(n) Operations:**

`get(int index)` traverses from head if `index < size/2`, otherwise from tail. This halves traversal on average but is still O(n):

```java
Node<E> node(int index) {
    if (index < (size >> 1)) {
        Node<E> x = first;
        for (int i = 0; i < index; i++) x = x.next;
        return x;
    } else {
        Node<E> x = last;
        for (int i = size - 1; i > index; i--) x = x.prev;
        return x;
    }
}
```

**Implements Both List and Deque:**

LinkedList implements `List<E>` and `Deque<E>`, giving access to stack operations (`push`, `pop`) and queue operations (`offer`, `poll`) simultaneously. This dual-interface nature is sometimes its only practical advantage over ArrayDeque.

### Real-World Backend Example

A message broker's in-memory queue where messages are produced at the tail and consumed at the head. O(1) enqueue and dequeue operations matter under high throughput. However, in most modern applications, `ArrayDeque` is preferred over `LinkedList` as a queue because it avoids per-element heap allocation.

### Java 17 Code Example

```java
import java.util.LinkedList;
import java.util.Deque;

public class LinkedListInternals {

    public static void main(String[] args) {
        LinkedList<String> list = new LinkedList<>();

        // O(1) add at ends
        list.addFirst("first");
        list.addLast("last");
        list.add("middle");   // addLast equivalent

        // O(n) random access — avoid in hot loops
        String item = list.get(1);  // traverses from head or tail

        // O(1) remove at ends
        String head = list.removeFirst();
        String tail = list.removeLast();

        // Use as Deque (preferred interface)
        Deque<String> deque = new LinkedList<>();
        deque.push("A");   // addFirst
        deque.pop();       // removeFirst — stack semantics

        deque.offer("B");  // addLast — queue semantics
        deque.poll();      // removeFirst

        // Iteration is O(n) and efficient via iterator (node.next)
        for (String s : deque) {
            System.out.println(s);
        }
    }
}
```

### Follow-up Questions Interviewers Ask

1. Why is random access O(n) in LinkedList but O(1) in ArrayList?
2. When would you choose LinkedList over ArrayDeque as a queue?
3. What is the memory overhead of LinkedList compared to ArrayList?
4. Can LinkedList store null elements?

### Common Mistakes Candidates Make

- Recommending LinkedList for queue operations when ArrayDeque is almost always faster due to cache locality.
- Forgetting that `remove(Object o)` in LinkedList is O(n) — it must find the node first.
- Claiming middle insertion is always O(1) — finding the position is O(n), the pointer adjustment is O(1).

### Interview Traps

- **Trap:** "LinkedList insert is O(1), right?" — Partial truth. Insert at a known node reference is O(1), but finding the insertion point by index is O(n).
- **Trap:** "Is LinkedList thread-safe?" — No. Neither ArrayList nor LinkedList is synchronized.

### Quick Revision Notes

- Doubly linked list; each node holds prev/next/item pointers (~32 bytes overhead).
- `addFirst`/`addLast`/`removeFirst`/`removeLast` are O(1).
- `get(index)` is O(n) — traverses from nearer end.
- High memory overhead; poor cache locality; prefer ArrayDeque for queues.

![Singly Linked List structure](https://upload.wikimedia.org/wikipedia/commons/6/6d/Singly-linked-list.svg)
*Singly linked list — each node holds data and a pointer to the next node*

---

## 3. ArrayList vs LinkedList

**Difficulty:** Easy | **Interview Frequency:** Very High  
**Asked at:** Almost every Java interview

### Short Interview Answer (30–60 seconds)

ArrayList is backed by a contiguous array, giving O(1) random access and better cache locality. LinkedList is a doubly linked list with O(1) add/remove at head/tail but O(n) random access. For most real-world use cases — building result sets, batch processing, pagination — ArrayList is faster due to CPU cache friendliness. LinkedList is preferred only when frequent insertions/deletions at both ends are required alongside list semantics.

### Deep Explanation

**Cache Locality:**

Modern CPUs load data in cache lines (typically 64 bytes). ArrayList elements are stored contiguously in memory. When you access `list.get(i)`, the CPU loads the surrounding elements into the L1/L2 cache, making the next access nearly free. LinkedList nodes are scattered across the heap. Each node access is likely a cache miss, adding ~100ns penalty per access on modern hardware.

**Comparison Table:**

| Operation | ArrayList | LinkedList |
|-----------|-----------|------------|
| `get(index)` | O(1) | O(n) |
| `add(E)` (append) | O(1) amortized | O(1) |
| `add(0, E)` (prepend) | O(n) | O(1) |
| `add(i, E)` (middle) | O(n) | O(n) find + O(1) link |
| `remove(index)` | O(n) | O(n) find + O(1) unlink |
| `remove(head)` | O(n) | O(1) |
| `remove(tail)` | O(1) | O(1) |
| Memory (1M ints) | ~4 MB | ~20 MB |
| Cache performance | Excellent | Poor |
| Iterator speed | Fast | Moderate |

### Real-World Use Cases

| Scenario | Choice | Reason |
|----------|--------|--------|
| REST API result set | ArrayList | Random access, iteration |
| Event listener list | CopyOnWriteArrayList | Thread-safe, read-heavy |
| Undo/redo history | ArrayDeque | Stack operations |
| Task queue | ArrayDeque | O(1) enqueue/dequeue |
| Bidirectional iteration with inserts | LinkedList | ListIterator insert |

### Java 17 Code Example

```java
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

public class ListComparison {

    public static void main(String[] args) {
        List<Integer> arrayList = new ArrayList<>(100_000);
        List<Integer> linkedList = new LinkedList<>();

        // Populate
        for (int i = 0; i < 100_000; i++) {
            arrayList.add(i);
            linkedList.add(i);
        }

        // ArrayList: O(1) random access
        long start = System.nanoTime();
        for (int i = 0; i < 100_000; i++) {
            arrayList.get(i);  // direct array index
        }
        System.out.println("ArrayList get: " + (System.nanoTime() - start) + " ns");

        // LinkedList: O(n) random access — much slower
        start = System.nanoTime();
        for (int i = 0; i < 100_000; i++) {
            linkedList.get(i);  // traversal each time
        }
        System.out.println("LinkedList get: " + (System.nanoTime() - start) + " ns");

        // LinkedList wins: prepend operation
        start = System.nanoTime();
        ((LinkedList<Integer>) linkedList).addFirst(999);
        System.out.println("LinkedList addFirst: " + (System.nanoTime() - start) + " ns");

        start = System.nanoTime();
        arrayList.add(0, 999);  // shifts all elements
        System.out.println("ArrayList add(0,e): " + (System.nanoTime() - start) + " ns");
    }
}
```

### Follow-up Questions Interviewers Ask

1. Why is ArrayList usually faster than LinkedList even for insertions?
2. In what scenario would you actually use LinkedList in production code?
3. Why does Java's LinkedList implement both List and Deque?

### Common Mistakes Candidates Make

- Saying "LinkedList is better for insertions in the middle" without clarifying that finding the position is still O(n).
- Underestimating the cache miss penalty of LinkedList under real workloads.

### Quick Revision Notes

- ArrayList: O(1) get, O(n) prepend, cache-friendly, lower memory.
- LinkedList: O(1) head/tail operations, O(n) get, high memory overhead.
- For queues, use ArrayDeque. For most lists, use ArrayList.

---

## 4. HashSet Internals

**Difficulty:** Medium | **Interview Frequency:** High  
**Asked at:** Amazon, Google, Walmart Labs, Razorpay

### Short Interview Answer (30–60 seconds)

HashSet is backed entirely by a HashMap. Every element added to the HashSet becomes a key in the underlying HashMap, mapped to a shared dummy `Object` value (`PRESENT`). All HashSet operations delegate directly to HashMap, so the time complexity and collision behavior is identical to HashMap.

### Deep Explanation

**From OpenJDK source:**

```java
public class HashSet<E> extends AbstractSet<E> {
    private transient HashMap<E,Object> map;
    private static final Object PRESENT = new Object();  // dummy value

    public boolean add(E e) {
        return map.put(e, PRESENT) == null;
    }

    public boolean remove(Object o) {
        return map.remove(o) == PRESENT;
    }

    public boolean contains(Object o) {
        return map.containsKey(o);
    }
}
```

**Null Handling:**

HashSet allows exactly one null element, stored in bucket 0 of the underlying HashMap (just as HashMap handles null keys).

**No Duplicate Guarantee:**

When `add(e)` is called, `map.put(e, PRESENT)` returns the previous value. If the key already existed (duplicate), it returns `PRESENT` (non-null), so `add()` returns false. If the key was new, `put` returns null, so `add()` returns true.

**Ordering:**

HashSet provides no ordering guarantee. Iteration order depends on bucket placement and is effectively unpredictable across JVM versions and restarts.

### Real-World Backend Example

Deduplication of request IDs in an idempotency layer: before processing a payment, check `if (!processedIds.contains(requestId))` in a HashSet. O(1) lookup, no ordering needed.

### Java 17 Code Example

```java
import java.util.HashSet;
import java.util.Set;

public class HashSetInternals {

    public static void main(String[] args) {
        Set<String> set = new HashSet<>();

        // add() returns false if duplicate
        System.out.println(set.add("apple"));   // true
        System.out.println(set.add("apple"));   // false — duplicate

        // One null allowed
        set.add(null);
        System.out.println(set.contains(null)); // true

        // O(1) average contains/add/remove
        set.add("banana");
        set.remove("banana");
        System.out.println(set.contains("banana")); // false

        // Iteration order is NOT guaranteed
        for (String s : set) {
            System.out.println(s);  // order unpredictable
        }

        // Pre-size to avoid rehashing: capacity = n/0.75 + 1
        int expectedSize = 1000;
        Set<String> preSized = new HashSet<>((int)(expectedSize / 0.75) + 1);
    }
}
```

### Follow-up Questions Interviewers Ask

1. How is HashSet backed by HashMap?
2. How does HashSet ensure no duplicates?
3. Can HashSet contain null?
4. What is the time complexity of `contains()`?

### Common Mistakes Candidates Make

- Forgetting that HashSet is backed by HashMap and reinventing the explanation.
- Saying HashSet maintains insertion order — it does not (use LinkedHashSet for that).
- Not mentioning that `hashCode()` and `equals()` must be properly overridden for custom objects in a HashSet.

### Quick Revision Notes

- Backed by `HashMap<E, Object>`; dummy value `PRESENT`.
- `add`, `remove`, `contains` are O(1) average, O(log n) worst (Java 8+).
- Allows one null, no duplicates, no ordering.
- Requires correct `hashCode()` and `equals()` for custom objects.

---

## 5. LinkedHashSet

**Difficulty:** Easy | **Interview Frequency:** Medium  
**Asked at:** Adobe, Infosys, Capgemini, mid-tier SaaS

### Short Interview Answer (30–60 seconds)

LinkedHashSet extends HashSet but maintains insertion order. Internally it is backed by a LinkedHashMap instead of HashMap. It uses a doubly linked list running through all entries to track the order in which elements were inserted. Performance is slightly slower than HashSet due to the extra list maintenance, but still O(1) for add/remove/contains.

### Deep Explanation

**Internal Backing:**

```java
public class LinkedHashSet<E> extends HashSet<E> {
    // calls HashSet's package-private constructor that creates a LinkedHashMap
    public LinkedHashSet(int initialCapacity, float loadFactor) {
        super(initialCapacity, loadFactor, true);  // 'true' signals LinkedHashMap
    }
}
```

The `true` flag in HashSet's constructor creates a `LinkedHashMap` instead of `HashMap` as the backing store.

**Order Guarantee:**

The iteration order matches the order elements were first inserted. Re-inserting an existing element does not change its position.

**Memory:**

Slightly higher than HashSet — each entry in LinkedHashMap has two additional pointers (`before` and `after`) for the doubly linked list.

### Real-World Backend Example

Storing recently accessed user IDs in a session context where display order should match access order. Or building a result set that must preserve the order in which unique items were encountered while scanning records.

### Java 17 Code Example

```java
import java.util.LinkedHashSet;
import java.util.Set;

public class LinkedHashSetExample {

    public static void main(String[] args) {
        Set<String> set = new LinkedHashSet<>();

        set.add("banana");
        set.add("apple");
        set.add("cherry");
        set.add("apple");   // duplicate — ignored, order not changed

        // Prints: banana, apple, cherry — insertion order preserved
        for (String s : set) {
            System.out.println(s);
        }

        System.out.println(set.contains("apple")); // O(1)
    }
}
```

### Follow-up Questions Interviewers Ask

1. What is the difference between HashSet, LinkedHashSet, and TreeSet?
2. Does LinkedHashSet allow null?
3. When would you use LinkedHashSet over HashSet?

### Quick Revision Notes

- Backed by LinkedHashMap; insertion order preserved.
- O(1) for add/remove/contains; slightly more memory than HashSet.
- One null allowed; no duplicates.

---

## 6. TreeSet

**Difficulty:** Medium | **Interview Frequency:** Medium  
**Asked at:** Amazon, Google (for NavigableSet usage), financial firms

### Short Interview Answer (30–60 seconds)

TreeSet is backed by a TreeMap, which is a Red-Black tree. Elements are stored in sorted natural order (or by a provided Comparator). All operations — add, remove, contains — are O(log n). TreeSet also implements NavigableSet, giving access to methods like `floor()`, `ceiling()`, `headSet()`, and `tailSet()`.

### Deep Explanation

**Backing Structure:**

```java
public class TreeSet<E> extends AbstractSet<E> implements NavigableSet<E> {
    private transient NavigableMap<E,Object> m;
    private static final Object PRESENT = new Object();

    public TreeSet() {
        this(new TreeMap<>());  // natural ordering
    }

    public TreeSet(Comparator<? super E> comparator) {
        this(new TreeMap<>(comparator));
    }
}
```

**Red-Black Tree Properties:**

A Red-Black tree is a self-balancing BST with these invariants:
1. Every node is red or black.
2. The root is black.
3. Red nodes cannot have red children (no two consecutive reds).
4. Every path from a node to its null descendant has the same number of black nodes.

These properties ensure the tree height is at most `2 * log₂(n)`, guaranteeing O(log n) operations.

**No Null Elements:**

TreeSet does not allow null (unlike HashSet/LinkedHashSet) because comparison (`compareTo`) would throw a NullPointerException.

**NavigableSet Methods:**

| Method | Description |
|--------|-------------|
| `floor(e)` | Greatest element <= e |
| `ceiling(e)` | Smallest element >= e |
| `lower(e)` | Greatest element < e |
| `higher(e)` | Smallest element > e |
| `headSet(e)` | View of elements strictly < e |
| `tailSet(e)` | View of elements >= e |
| `subSet(from, to)` | View of elements in [from, to) |
| `first()` / `last()` | Min/max element |

### Real-World Backend Example

Maintaining a sorted set of active session timestamps for an expiry scheduler. `TreeSet.headSet(expiryThreshold)` returns all sessions that have expired in O(log n + k) time, where k is the number of expired sessions.

### Java 17 Code Example

```java
import java.util.TreeSet;
import java.util.NavigableSet;
import java.util.Comparator;

public class TreeSetExample {

    public static void main(String[] args) {
        TreeSet<Integer> set = new TreeSet<>();
        set.add(5); set.add(3); set.add(8); set.add(1); set.add(7);

        // Sorted order: 1, 3, 5, 7, 8
        System.out.println(set);  // [1, 3, 5, 7, 8]

        // NavigableSet operations — O(log n)
        System.out.println(set.floor(6));     // 5 (greatest <= 6)
        System.out.println(set.ceiling(6));   // 7 (smallest >= 6)
        System.out.println(set.lower(5));     // 3 (strictly less)
        System.out.println(set.higher(5));    // 7 (strictly greater)

        // Range views
        NavigableSet<Integer> head = set.headSet(5);  // [1, 3] (< 5)
        NavigableSet<Integer> tail = set.tailSet(5);  // [5, 7, 8] (>= 5)

        // Custom Comparator — reverse order
        TreeSet<String> reversed = new TreeSet<>(Comparator.reverseOrder());
        reversed.add("banana"); reversed.add("apple"); reversed.add("cherry");
        System.out.println(reversed);  // [cherry, banana, apple]

        // First/last
        System.out.println(set.first()); // 1
        System.out.println(set.last());  // 8
    }
}
```

### Follow-up Questions Interviewers Ask

1. What tree does TreeSet use internally?
2. What is the time complexity of `add()`, `remove()`, `contains()` in TreeSet?
3. Why does TreeSet not allow null?
4. What is the difference between `floor()` and `lower()`?

### Common Mistakes Candidates Make

- Saying TreeSet uses a B-tree or AVL tree (it uses a Red-Black tree).
- Forgetting that TreeSet does not allow null elements.
- Mixing up `floor()` (<=) with `lower()` (strictly <).

### Quick Revision Notes

- Backed by TreeMap (Red-Black tree); O(log n) for all operations.
- Sorted by natural order or Comparator; no null elements.
- Implements NavigableSet: floor, ceiling, lower, higher, headSet, tailSet.

---

## 7. HashMap Internals (Java 8+)

**Difficulty:** Hard | **Interview Frequency:** Very High  
**Asked at:** Every FAANG company, Goldman Sachs, Morgan Stanley, Stripe, Uber, Airbnb

> This is the single most important topic in Java collections interviews. Senior interviewers can spend 20+ minutes here. Know every detail.

### Short Interview Answer (30–60 seconds)

HashMap uses an array of buckets (default capacity 16, load factor 0.75). When you call `put(key, value)`, it computes the hash of the key, mixes the upper 16 bits into the lower 16 bits to reduce collisions, then maps it to a bucket index using bitwise AND. Collisions are resolved by chaining — a linked list per bucket. In Java 8+, when a bucket's chain exceeds 8 entries, it converts to a Red-Black tree for O(log n) worst-case lookup. When the total number of entries exceeds `capacity * loadFactor`, the map doubles in capacity and rehashes all entries.

### Deep Explanation

**Core Fields (from OpenJDK):**

```java
transient Node<K,V>[] table;          // the bucket array
transient int size;                   // number of key-value mappings
int threshold;                        // next resize at size > threshold
final float loadFactor;               // default 0.75
static final int DEFAULT_INITIAL_CAPACITY = 1 << 4;  // 16
static final float DEFAULT_LOAD_FACTOR = 0.75f;
static final int TREEIFY_THRESHOLD = 8;    // convert chain to tree
static final int UNTREEIFY_THRESHOLD = 6;  // revert tree to chain
static final int MIN_TREEIFY_CAPACITY = 64; // minimum table size for treeification
```

**Node Structure:**

```java
static class Node<K,V> implements Map.Entry<K,V> {
    final int hash;       // cached hash of key
    final K key;
    V value;
    Node<K,V> next;       // next node in chain (null if no collision)
}
```

For tree buckets, `Node<K,V>` is replaced by `TreeNode<K,V>`, which extends `LinkedHashMap.Entry` and adds Red-Black tree pointers.

---

**The Hash Function — Why XOR with Upper 16 Bits:**

```java
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
```

After computing `hash`, the bucket index is:

```java
int index = hash & (n - 1);   // n = table.length, always a power of 2
```

Because `n` is typically small (16, 32, 64...), `n - 1` has only a few low bits set. For example, with `n = 16`, `n - 1 = 0b00001111`, so only the bottom 4 bits of the hash determine the bucket. If many keys have similar lower bits but different upper bits, collisions pile up.

The XOR of `h` with `h >>> 16` "spreads" the upper 16 bits into the lower 16 bits, ensuring that high bits of the hash code influence the bucket index. This reduces collision clustering without expensive computation.

**Example:**

```
h             = 0xABCD1234
h >>> 16      = 0x0000ABCD
h ^ (h>>>16)  = 0xABCD1234 ^ 0x0000ABCD = 0xABCDBBF9
```

Now bucket index with n=16: `0xABCDBBF9 & 0xF = 0x9 = 9`
Without spreading: `0xABCD1234 & 0xF = 0x4 = 4` — potentially worse distribution.

---

**Why Capacity is Always a Power of 2:**

The bucket index calculation `hash & (n - 1)` only works correctly (distributes evenly) when `n` is a power of 2. If n is a power of 2, `n - 1` is all ones in binary (e.g., 16 → 15 = `0b1111`), making the AND operation a fast modulo equivalent.

Using the `%` operator instead (`hash % n`) would require an integer division instruction (~20-40 CPU cycles), while bitwise AND is a single cycle. At millions of operations per second, this matters.

If you provide a non-power-of-2 initial capacity (e.g., `new HashMap<>(10)`), HashMap rounds it up to the next power of 2 (16) internally.

---

**`put()` Step by Step:**

```java
public V put(K key, V value) {
    return putVal(hash(key), key, value, false, true);
}

final V putVal(int hash, K key, V value, boolean onlyIfAbsent, boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;

    // 1. Initialize table on first put (lazy initialization)
    if ((tab = table) == null || (n = tab.length) == 0)
        n = (tab = resize()).length;

    // 2. Compute bucket index: i = hash & (n-1)
    if ((p = tab[i = (n - 1) & hash]) == null)
        // 3a. Bucket is empty — insert directly
        tab[i] = newNode(hash, key, value, null);
    else {
        Node<K,V> e; K k;

        // 3b. Check if first node in bucket matches
        if (p.hash == hash && ((k = p.key) == key || (key != null && key.equals(k))))
            e = p;

        // 3c. Bucket is a tree node (treeified)
        else if (p instanceof TreeNode)
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);

        // 3d. Traverse linked list chain
        else {
            for (int binCount = 0; ; ++binCount) {
                if ((e = p.next) == null) {
                    p.next = newNode(hash, key, value, null);
                    // 3e. Treeify if chain length >= TREEIFY_THRESHOLD (8)
                    if (binCount >= TREEIFY_THRESHOLD - 1)
                        treeifyBin(tab, hash);
                    break;
                }
                if (e.hash == hash && ((k = e.key) == key || (key != null && key.equals(k))))
                    break;  // found existing key
                p = e;
            }
        }

        // 4. Update existing key
        if (e != null) {
            V oldValue = e.value;
            if (!onlyIfAbsent || oldValue == null)
                e.value = value;
            return oldValue;
        }
    }

    ++modCount;

    // 5. Resize if size exceeds threshold (capacity * loadFactor)
    if (++size > threshold)
        resize();

    return null;
}
```

---

**`get()` Step by Step:**

```java
public V get(Object key) {
    Node<K,V> e;
    return (e = getNode(hash(key), key)) == null ? null : e.value;
}

final Node<K,V> getNode(int hash, Object key) {
    Node<K,V>[] tab; Node<K,V> first, e; int n; K k;

    // 1. Table must be non-null and bucket non-empty
    if ((tab = table) != null && (n = tab.length) > 0 &&
        (first = tab[(n - 1) & hash]) != null) {

        // 2. Check first node
        if (first.hash == hash &&
            ((k = first.key) == key || (key != null && key.equals(k))))
            return first;

        // 3. Search chain or tree
        if ((e = first.next) != null) {
            if (first instanceof TreeNode)
                return ((TreeNode<K,V>)first).getTreeNode(hash, key);
            do {
                if (e.hash == hash && ((k = e.key) == key || (key != null && key.equals(k))))
                    return e;
            } while ((e = e.next) != null);
        }
    }
    return null;
}
```

---

**Resize / Rehash:**

When `size > threshold` (= `capacity * loadFactor`), the table doubles:

```java
// New capacity = oldCapacity << 1 (multiply by 2)
// New threshold = newCapacity * loadFactor
```

All existing entries are rehashed. For each entry, because the new capacity is exactly 2x the old capacity, the rehash calculation only adds one new bit to the index. An entry either stays at the same index or moves to `oldIndex + oldCapacity`. This allows an optimization in OpenJDK where the rehash loop only checks one bit of the hash to decide placement — no full recomputation needed.

---

**Treeification:**

When a bucket's linked list chain reaches `TREEIFY_THRESHOLD = 8`, `treeifyBin()` is called. However, if the total table size is less than `MIN_TREEIFY_CAPACITY = 64`, the table resizes instead of treeifying (because a small table is more likely to have collision problems fixed by resizing).

The reverse operation — `UNTREEIFY_THRESHOLD = 6` — prevents oscillation: a bucket won't flip between tree and list if entries hover around 8.

---

**Null Key:**

Null keys always use hash 0, which maps to bucket 0. HashMap explicitly allows one null key. ConcurrentHashMap does not allow null keys (see section 11).

### Real-World Backend Example

A high-throughput order processing service uses a HashMap to cache `orderId -> Order` mappings within a request scope. Proper sizing (`new HashMap<>(expectedSize * 4 / 3 + 1)`) prevents rehashing during the request lifecycle. Custom `hashCode()` and `equals()` on the key class ensure correct lookups.

### Java 17 Code Example

```java
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

public class HashMapInternals {

    // Custom key class — must override hashCode and equals
    record ProductKey(String category, long id) {
        @Override
        public int hashCode() {
            return Objects.hash(category, id);
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof ProductKey pk)) return false;
            return id == pk.id && Objects.equals(category, pk.category);
        }
    }

    public static void main(String[] args) {
        // Pre-size to avoid rehashing for 100 entries
        // threshold = capacity * 0.75; capacity needed = 100 / 0.75 ~ 134 -> next power of 2 = 256? 
        // Practical formula: (int)(expectedSize / 0.75) + 1
        int expectedEntries = 100;
        Map<ProductKey, String> map = new HashMap<>((int)(expectedEntries / 0.75) + 1);

        // put() — hash computed, bucket found, inserted
        map.put(new ProductKey("electronics", 1001L), "Laptop");
        map.put(new ProductKey("electronics", 1002L), "Phone");
        map.put(new ProductKey("books", 2001L), "Effective Java");

        // Null key — stored in bucket 0
        map.put(null, "null-key-value");

        // get() — O(1) average
        String product = map.get(new ProductKey("electronics", 1001L));
        System.out.println(product);  // Laptop

        // getOrDefault — safer than get() + null check
        String val = map.getOrDefault(new ProductKey("toys", 9999L), "NOT_FOUND");

        // putIfAbsent — atomic check-and-insert
        map.putIfAbsent(new ProductKey("electronics", 1001L), "New Value");  // no-op

        // computeIfAbsent — compute and cache
        map.computeIfAbsent(new ProductKey("food", 3001L), k -> "Pizza");

        // Iteration — entrySet is most efficient
        for (Map.Entry<ProductKey, String> entry : map.entrySet()) {
            System.out.println(entry.getKey() + " -> " + entry.getValue());
        }

        // merge — combine values
        map.merge(new ProductKey("electronics", 1001L), " Pro",
                  (existing, newVal) -> existing + newVal);

        System.out.println(map.get(new ProductKey("electronics", 1001L)));  // Laptop Pro
    }
}
```

### Follow-up Questions Interviewers Ask

1. Walk me through exactly what happens when you call `put("key", "value")` on a HashMap.
2. Why does HashMap use a power-of-2 capacity? What is the benefit?
3. What is the purpose of XOR-ing the hash with its upper 16 bits?
4. At what point does HashMap convert a linked list to a tree? Why 8?
5. What happens during resize? Does every entry get rehashed from scratch?
6. What is the load factor, and what are the tradeoffs of setting it to 0.5 vs 0.9?
7. Why does HashMap allow null keys but ConcurrentHashMap does not?
8. If two objects are `equals()` but have different `hashCode()`, what happens?
9. What happens if you store mutable keys in a HashMap and mutate them?

### Common Mistakes Candidates Make

- Saying the hash function uses only `key.hashCode()` — missing the upper 16-bit XOR spreading.
- Saying treeification happens at size > 8 — it's at `binCount >= TREEIFY_THRESHOLD - 1` (i.e., when adding the 9th element to a bin).
- Forgetting `MIN_TREEIFY_CAPACITY = 64`: below this, resize happens instead of treeify.
- Saying capacity is any arbitrary number — it is always rounded up to a power of 2.
- Confusing `size` (entries) with `capacity` (array slots).

### Interview Traps

- **Trap:** "What is the default capacity of HashMap?" — 16, but the array is lazily initialized on the first `put()`.
- **Trap:** "If I set initial capacity to 10, what capacity does HashMap actually use?" — 16 (next power of 2 above 10).
- **Trap:** "What if two different keys produce the same `hashCode()` but are not `equals()`?" — They go in the same bucket (collision), chained together.
- **Trap:** "What if a key's `hashCode()` changes after insertion?" — The entry becomes unreachable via `get()` because the hash maps to a different bucket. This is a silent data loss bug.
- **Trap:** "Is HashMap ordered?" — No guaranteed order. Iteration order can change after resize. Use LinkedHashMap for insertion order, TreeMap for sorted order.

### Quick Revision Notes

- Array of 16 buckets (power of 2); load factor 0.75; threshold = capacity * 0.75.
- Hash = `hashCode() ^ (hashCode() >>> 16)`; index = `hash & (capacity - 1)`.
- Collision: linked list → Red-Black tree when bin size >= 8 (and table size >= 64).
- Resize: double capacity, rehash; O(n) operation but amortized.
- Null key goes to bucket 0; one null key allowed.

![Hash table with chaining](https://upload.wikimedia.org/wikipedia/commons/d/d0/Hash_table_5_0_1_1_1_1_1_LL.svg)
*HashMap internals — hash function maps keys to buckets, collisions resolved by chaining*

---

## 8. HashMap Performance

**Difficulty:** Medium | **Interview Frequency:** High  
**Asked at:** Google, Amazon, financial firms, system design rounds

### Short Interview Answer (30–60 seconds)

HashMap average-case performance is O(1) for get, put, and remove because the hash function distributes keys uniformly across buckets. In the worst case — all keys collide into one bucket — performance degrades to O(n) in Java 7 (linked list traversal) or O(log n) in Java 8+ (Red-Black tree in treeified bucket). In practice, a good hash function keeps collisions minimal.

### Deep Explanation

**Complexity Summary:**

| Operation | Average Case | Worst Case (Java 7) | Worst Case (Java 8+) |
|-----------|-------------|---------------------|----------------------|
| `put(k, v)` | O(1) | O(n) | O(log n) |
| `get(k)` | O(1) | O(n) | O(log n) |
| `remove(k)` | O(1) | O(n) | O(log n) |
| `containsKey(k)` | O(1) | O(n) | O(log n) |
| `resize()` | O(n) | O(n) | O(n) |
| Iteration | O(capacity + size) | O(capacity + size) | O(capacity + size) |

**Why Iteration is O(capacity + size):**

Iterating a HashMap traverses the entire bucket array regardless of how many entries exist. An empty map with capacity 65536 takes longer to iterate than a full map with capacity 16. This is why `new HashMap<>(Integer.MAX_VALUE)` is a bad idea.

**Hash DoS Attack:**

Before Java 8, an adversary who could predict the hash function could craft keys that all hash to the same bucket, causing O(n) lookups and effectively a DoS attack. Java 8's treeification mitigates this to O(log n). Java also added hash randomization (`String.hashCode()` uses a stable algorithm, but some JVM implementations add per-JVM-instance hash seed for other types).

**Load Factor Tradeoffs:**

| Load Factor | Effect |
|-------------|--------|
| 0.5 | Fewer collisions, more memory wasted, more frequent resizes |
| 0.75 (default) | Good balance, empirically tested |
| 0.9 | Higher memory utilization, more collisions, slower lookups |

### Real-World Backend Example

In a security-sensitive system (e.g., parsing user-controlled JSON keys into a HashMap), treeification at TREEIFY_THRESHOLD = 8 is the mitigation against hash collision attacks. An attacker with knowledge of the hash function could previously send 10,000 keys that all map to bucket 0, causing O(n²) behavior in a worst-case scenario for a HashMap-backed request parameter parser (as seen in CVE-2011-4461 in older Java/Tomcat stacks).

### Java 17 Code Example

```java
import java.util.HashMap;
import java.util.Map;

public class HashMapPerformance {

    public static void main(String[] args) {
        // Demonstrate collision: equal hashCode, different equals
        Map<CollisionKey, String> map = new HashMap<>(16);

        // These keys all have the same hashCode — all in bucket (hashCode & 15)
        for (int i = 0; i < 20; i++) {
            map.put(new CollisionKey(i), "value-" + i);
        }
        // After 9th entry in same bucket: treeify occurs
        // Lookups now O(log n) instead of O(n)

        // Good practice: pre-size to avoid rehashing
        Map<String, Integer> preSized = new HashMap<>((int)(10_000 / 0.75) + 1);
    }

    static class CollisionKey {
        final int id;
        CollisionKey(int id) { this.id = id; }

        @Override
        public int hashCode() {
            return 42;  // all keys collide intentionally
        }

        @Override
        public boolean equals(Object o) {
            return o instanceof CollisionKey ck && ck.id == this.id;
        }
    }
}
```

### Follow-up Questions
1. What is the worst-case time complexity of HashMap get() and when does it occur?
2. How does Java 8's treeification of buckets improve worst-case performance?
3. What initial capacity should you set when you know the expected number of entries?

### Quick Revision Notes

- O(1) average, O(log n) worst case (Java 8+), O(n) worst case (Java 7).
- Treeification protects against hash DoS attacks.
- Iteration is O(capacity + size) — avoid large initial capacities if iterating frequently.
- Load factor 0.75 is empirically the best tradeoff between space and time.

---

## 9. LinkedHashMap

**Difficulty:** Medium | **Interview Frequency:** High  
**Asked at:** Amazon, Uber, Airbnb (LRU cache question), Bloomberg

### Short Interview Answer (30–60 seconds)

LinkedHashMap extends HashMap and maintains either insertion order or access order through an additional doubly linked list that runs through all entries. In access-order mode, accessing an entry via `get()` or `put()` moves it to the end of the list, making LinkedHashMap the ideal base for building an LRU (Least Recently Used) cache by overriding `removeEldestEntry()`.

### Deep Explanation

**Internal Structure:**

LinkedHashMap adds two extra fields to each HashMap.Node:

```java
static class Entry<K,V> extends HashMap.Node<K,V> {
    Entry<K,V> before, after;  // doubly linked list pointers
}
```

The LinkedHashMap itself maintains:

```java
transient LinkedHashMap.Entry<K,V> head;  // oldest entry (list head)
transient LinkedHashMap.Entry<K,V> tail;  // newest entry (list tail)
final boolean accessOrder;               // false = insertion order, true = access order
```

**Two Modes:**

1. **Insertion order** (`accessOrder = false`, default): Iteration visits entries in the order they were inserted. Re-inserting an existing key does NOT change its position.

2. **Access order** (`accessOrder = true`): Any access (`get()`, `put()`, `getOrDefault()`) moves the accessed entry to the tail of the linked list. The head always holds the least recently used entry.

**LRU Cache Implementation:**

```java
protected boolean removeEldestEntry(Map.Entry<K,V> eldest) {
    return false;  // default: never remove automatically
}
```

Override `removeEldestEntry()` to return true when `size() > maxCapacity`. LinkedHashMap calls this after every `put()` and removes the head entry (LRU entry) if the method returns true.

### Real-World Backend Example

An LRU cache for database query results in a DAO layer. Cache hit rate is maximized by evicting the least recently used entry when capacity is exceeded, ensuring hot data stays in memory.

### Java 17 Code Example

```java
import java.util.LinkedHashMap;
import java.util.Map;

public class LinkedHashMapExample {

    // LRU Cache using LinkedHashMap
    static class LRUCache<K, V> extends LinkedHashMap<K, V> {
        private final int maxCapacity;

        LRUCache(int maxCapacity) {
            super(maxCapacity, 0.75f, true);  // true = access-order mode
            this.maxCapacity = maxCapacity;
        }

        @Override
        protected boolean removeEldestEntry(Map.Entry<K, V> eldest) {
            return size() > maxCapacity;
        }
    }

    public static void main(String[] args) {
        // Insertion-order LinkedHashMap
        Map<String, Integer> insertionOrder = new LinkedHashMap<>();
        insertionOrder.put("c", 3);
        insertionOrder.put("a", 1);
        insertionOrder.put("b", 2);
        System.out.println(insertionOrder.keySet());  // [c, a, b]

        // LRU Cache with capacity 3
        LRUCache<Integer, String> cache = new LRUCache<>(3);
        cache.put(1, "one");
        cache.put(2, "two");
        cache.put(3, "three");

        cache.get(1);  // access 1 — moves to tail (most recently used)
        // Order now: 2(LRU head), 3, 1(MRU tail)

        cache.put(4, "four");  // evicts LRU entry (key=2)
        System.out.println(cache.containsKey(2));  // false — evicted
        System.out.println(cache.keySet());         // [3, 1, 4]
    }
}
```

### Follow-up Questions Interviewers Ask

1. How would you implement an LRU cache in Java without using LinkedHashMap?
2. What is the difference between insertion order and access order in LinkedHashMap?
3. What is the time complexity of LinkedHashMap operations?
4. How does `removeEldestEntry()` work?

### Common Mistakes Candidates Make

- Forgetting to pass `true` for `accessOrder` when implementing LRU.
- Implementing LRU from scratch with HashMap + DoublyLinkedList when LinkedHashMap is sufficient.
- Saying LinkedHashMap iteration is O(n²) — it is O(n) because it follows the linked list, not the bucket array.

### Quick Revision Notes

- Extends HashMap; adds doubly linked list through entries.
- Two modes: insertion-order (default) and access-order.
- Access-order + `removeEldestEntry()` = LRU cache.
- All operations O(1) average; iteration O(n) via linked list.

---

## 10. TreeMap

**Difficulty:** Medium | **Interview Frequency:** High  
**Asked at:** Amazon, Google, financial firms (range queries)

### Short Interview Answer (30–60 seconds)

TreeMap is backed by a Red-Black tree. It stores keys in sorted order — natural ordering by default, or by a provided Comparator. All operations are O(log n). TreeMap implements NavigableMap, providing rich range-query methods: `floorKey()`, `ceilingKey()`, `headMap()`, `tailMap()`, `subMap()`. It does not allow null keys.

### Deep Explanation

**Internal Structure:**

```java
public class TreeMap<K,V> extends AbstractMap<K,V>
    implements NavigableMap<K,V> {

    private final Comparator<? super K> comparator;  // null = natural ordering
    private transient Entry<K,V> root;               // root of Red-Black tree
    private transient int size = 0;

    static final class Entry<K,V> implements Map.Entry<K,V> {
        K key;
        V value;
        Entry<K,V> left;
        Entry<K,V> right;
        Entry<K,V> parent;
        boolean color = BLACK;  // Red-Black tree color
    }
}
```

**NavigableMap Methods:**

| Method | Description | Time |
|--------|-------------|------|
| `floorKey(k)` | Greatest key <= k | O(log n) |
| `ceilingKey(k)` | Smallest key >= k | O(log n) |
| `lowerKey(k)` | Greatest key < k | O(log n) |
| `higherKey(k)` | Smallest key > k | O(log n) |
| `firstKey()` / `lastKey()` | Min/max key | O(log n) |
| `headMap(k)` | View of entries with key < k | O(log n) |
| `tailMap(k)` | View of entries with key >= k | O(log n) |
| `subMap(from, to)` | View of entries in [from, to) | O(log n) |
| `descendingMap()` | Reverse-order view | O(1) |
| `pollFirstEntry()` / `pollLastEntry()` | Remove and return min/max | O(log n) |

### Real-World Backend Example

A financial application tracking stock trade prices uses a TreeMap where keys are timestamps. `subMap(startTime, endTime)` retrieves all trades in a time window for OHLC (Open-High-Low-Close) calculations. `floorKey(timestamp)` finds the most recent trade before a given time.

### Java 17 Code Example

```java
import java.util.TreeMap;
import java.util.NavigableMap;
import java.util.Map;

public class TreeMapExample {

    public static void main(String[] args) {
        // Natural ordering (Integer keys sorted ascending)
        TreeMap<Integer, String> map = new TreeMap<>();
        map.put(5, "five"); map.put(3, "three"); map.put(8, "eight");
        map.put(1, "one");  map.put(7, "seven");

        // Sorted iteration
        for (Map.Entry<Integer, String> e : map.entrySet()) {
            System.out.println(e.getKey() + " -> " + e.getValue());
        }
        // Output: 1, 3, 5, 7, 8 in order

        // NavigableMap range queries
        System.out.println(map.floorKey(6));     // 5
        System.out.println(map.ceilingKey(6));   // 7
        System.out.println(map.lowerKey(5));     // 3
        System.out.println(map.higherKey(5));    // 7

        // Range view — subMap is a live view, modifications reflected in original
        NavigableMap<Integer, String> range = map.subMap(3, true, 7, true);  // [3, 7]
        System.out.println(range);  // {3=three, 5=five, 7=seven}

        // headMap: keys strictly less than 5
        System.out.println(map.headMap(5));  // {1=one, 3=three}

        // tailMap: keys >= 5
        System.out.println(map.tailMap(5));  // {5=five, 7=seven, 8=eight}

        // Custom comparator — reverse order
        TreeMap<String, Integer> reversed = new TreeMap<>(
            (a, b) -> b.compareTo(a)
        );
        reversed.put("banana", 1); reversed.put("apple", 2); reversed.put("cherry", 3);
        System.out.println(reversed.firstKey());  // cherry

        // Poll (remove and return)
        Map.Entry<Integer, String> min = map.pollFirstEntry();  // removes 1=one
        Map.Entry<Integer, String> max = map.pollLastEntry();   // removes 8=eight
    }
}
```

### Follow-up Questions Interviewers Ask

1. What is the time complexity of `get()` in TreeMap vs HashMap?
2. When would you use TreeMap instead of HashMap?
3. What happens if you use a null key in TreeMap?
4. What is the difference between `headMap()` and `subMap()`?

### Common Mistakes Candidates Make

- Forgetting that TreeMap does not allow null keys.
- Using TreeMap when only O(1) lookup is needed — HashMap is faster.
- Misunderstanding that `subMap`, `headMap`, and `tailMap` return live views — modifications to the view affect the original map.

### Quick Revision Notes

- Red-Black tree; O(log n) for all operations.
- Sorted by natural order or Comparator; no null keys.
- NavigableMap: floorKey, ceilingKey, headMap, tailMap, subMap.
- Range views are live — modifications propagate.

![Binary search tree structure](https://upload.wikimedia.org/wikipedia/commons/f/f7/Binary_tree.svg)
*TreeMap/TreeSet use a Red-Black tree (balanced BST) for O(log n) operations*

---

## 11. ConcurrentHashMap

**Difficulty:** Hard | **Interview Frequency:** Very High  
**Asked at:** Google, Amazon, Netflix, Stripe, Goldman Sachs, any concurrent programming interview

### Short Interview Answer (30–60 seconds)

ConcurrentHashMap in Java 8+ uses an array of nodes with fine-grained locking. Instead of locking the entire map (as Hashtable does), it synchronizes only on individual bucket heads using `synchronized` blocks. For empty bucket insertions, it uses CAS (Compare-And-Swap) operations to avoid locking entirely. It does not allow null keys or values because null would be ambiguous — you cannot distinguish "key not present" from "key present with null value" in a concurrent context.

### Deep Explanation

**Java 7 vs Java 8 Implementation:**

Java 7 used `Segment`-based locking — the array was divided into 16 segments, each with its own `ReentrantLock`. This allowed up to 16 concurrent writers.

Java 8 completely redesigned this to use per-bucket locking with `synchronized`, achieving much higher concurrency (up to n concurrent writers for n buckets).

**Java 8 Internal Structure:**

```java
// Same as HashMap's Node
static class Node<K,V> implements Map.Entry<K,V> {
    final int hash;
    final K key;
    volatile V val;      // volatile ensures visibility
    volatile Node<K,V> next;
}

transient volatile Node<K,V>[] table;           // main table
private transient volatile Node<K,V>[] nextTable; // resizing target
private transient volatile long baseCount;
private transient volatile int sizeCtl;  // controls initialization and resize
```

All shared state uses `volatile` to ensure memory visibility across threads without full synchronization.

**`put()` Operation — Two Cases:**

```
Case 1: Bucket is empty
   → Use CAS to atomically insert the new node
   → No lock acquired, no thread blocking

Case 2: Bucket is non-empty
   → synchronized(bucketHead) { ... }
   → Only threads accessing the SAME bucket are serialized
   → Different buckets can be written concurrently
```

This design allows near-linear scalability with the number of CPU cores.

**`get()` Operation — Lock-Free:**

`get()` is entirely lock-free. It reads `volatile` fields, ensuring it sees the latest writes without acquiring any lock. This makes reads extremely fast.

**Size Counting:**

`size()` in ConcurrentHashMap is not exact under concurrent modification — it returns a best-effort snapshot. The count is maintained using a distributed counter (`baseCount` + array of `CounterCell` objects using Striped64 technique, borrowed from LongAdder), reducing contention on a single counter.

**Why Null Keys and Values Are Not Allowed:**

```java
// In HashMap: get() returns null for both cases
map.get(key) == null  // could mean: key not present, OR key->null

// In ConcurrentHashMap, this ambiguity is dangerous in concurrent code:
if (!map.containsKey(key)) {       // thread A: key not present
    // ... another thread adds key=null here ...
    map.put(key, computeValue());  // thread A: overwrites null value
}

// With HashMap in single-threaded code, you can call containsKey() 
// to resolve the ambiguity — safe. In concurrent code, this TOCTOU 
// (Time-of-Check-Time-of-Use) window is a race condition.
// Disallowing null eliminates this entire class of bugs.
```

Doug Lea (ConcurrentHashMap author) explicitly documented this design decision: null is not useful in a concurrent map because the check-then-act pattern is inherently racy.

**Atomic Operations:**

ConcurrentHashMap provides atomic compound operations that HashMap does not:

```java
map.putIfAbsent(key, value)         // atomic check-and-insert
map.replace(key, oldVal, newVal)    // atomic conditional replace
map.remove(key, value)              // atomic conditional remove
map.compute(key, remappingFn)       // atomic compute-and-store
map.computeIfAbsent(key, fn)        // atomic get-or-compute
map.merge(key, value, mergeFn)      // atomic merge
```

All of these execute atomically with respect to each other on the same key.

### Real-World Backend Example

A high-concurrency API rate limiter: `ConcurrentHashMap<String, AtomicInteger>` maps client IDs to request counts. `computeIfAbsent(clientId, k -> new AtomicInteger(0))` safely initializes the counter for new clients, and `AtomicInteger.incrementAndGet()` atomically increments without locking.

### Java 17 Code Example

```java
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class ConcurrentHashMapExample {

    public static void main(String[] args) throws InterruptedException {
        ConcurrentHashMap<String, AtomicInteger> requestCounts = new ConcurrentHashMap<>();

        // Null keys/values NOT allowed
        // map.put(null, new AtomicInteger(1));  // throws NullPointerException

        // computeIfAbsent — atomic: safe for concurrent initialization
        requestCounts.computeIfAbsent("client-A", k -> new AtomicInteger(0))
                     .incrementAndGet();

        // Concurrent increments from multiple threads
        ExecutorService pool = Executors.newFixedThreadPool(10);
        for (int i = 0; i < 1000; i++) {
            final String clientId = "client-" + (i % 5);
            pool.submit(() ->
                requestCounts.computeIfAbsent(clientId, k -> new AtomicInteger(0))
                             .incrementAndGet()
            );
        }
        pool.shutdown();
        pool.awaitTermination(5, TimeUnit.SECONDS);

        System.out.println("client-0: " + requestCounts.get("client-0").get());  // ~200

        // putIfAbsent — atomic insert if key absent
        requestCounts.putIfAbsent("client-new", new AtomicInteger(0));

        // merge — thread-safe merge operation
        // (for simple counters, prefer compute + AtomicInteger)
        ConcurrentHashMap<String, Integer> wordCount = new ConcurrentHashMap<>();
        String[] words = {"apple", "banana", "apple", "cherry", "banana", "apple"};
        for (String word : words) {
            wordCount.merge(word, 1, Integer::sum);
        }
        System.out.println(wordCount);  // {apple=3, banana=2, cherry=1}

        // size() is approximate under concurrent modification
        System.out.println("Approx size: " + requestCounts.size());

        // mappingCount() — preferred for large maps (returns long)
        System.out.println("Exact count: " + requestCounts.mappingCount());
    }
}
```

### Follow-up Questions Interviewers Ask

1. How does ConcurrentHashMap achieve thread safety without locking the whole map?
2. Why does ConcurrentHashMap not allow null keys or values?
3. What is the difference between ConcurrentHashMap in Java 7 and Java 8?
4. Is `get()` in ConcurrentHashMap thread-safe? Does it acquire a lock?
5. Why is `size()` not exact in ConcurrentHashMap?
6. What is the difference between `putIfAbsent()` and `computeIfAbsent()`?

### Common Mistakes Candidates Make

- Saying ConcurrentHashMap uses a `ReentrantLock` per segment (Java 7 behavior, not Java 8).
- Claiming `get()` acquires a lock — it does not; it reads volatile fields.
- Using `get()` + `put()` as an atomic check-and-set pattern instead of `computeIfAbsent`.
- Forgetting that ConcurrentHashMap does not allow null, leading to runtime NPEs.

### Interview Traps

- **Trap:** "Is the following code thread-safe with ConcurrentHashMap?" — `if (!map.containsKey(k)) { map.put(k, v); }` — No. Use `putIfAbsent()` instead.
- **Trap:** "Can you use ConcurrentHashMap in place of Collections.synchronizedMap()?" — Yes, and it's faster under high contention.

### Quick Revision Notes

- Java 8: per-bucket locking (synchronized on bucket head) + CAS for empty buckets.
- `get()` is lock-free (reads volatile fields).
- No null keys or values — prevents TOCTOU ambiguity in concurrent code.
- Size tracking uses distributed counters (Striped64); `size()` is approximate.
- Use atomic operations: `computeIfAbsent`, `merge`, `putIfAbsent`.

---

## 12. HashMap vs Hashtable vs ConcurrentHashMap

**Difficulty:** Medium | **Interview Frequency:** Very High  
**Asked at:** Nearly every Java interview

| Feature | HashMap | Hashtable | ConcurrentHashMap |
|---------|---------|-----------|-------------------|
| Thread Safety | Not thread-safe | Thread-safe (synchronized on entire map) | Thread-safe (per-bucket locking) |
| Null Keys | 1 null key allowed | Not allowed | Not allowed |
| Null Values | Multiple null values | Not allowed | Not allowed |
| Performance (single-threaded) | Fast | Slow (unnecessary synchronization) | Slightly slower than HashMap |
| Performance (multi-threaded) | Unsafe | Very slow (full lock) | Fast (fine-grained locking) |
| Iteration | Fail-fast iterator | Fail-fast iterator (Enumeration is not) | Weakly consistent iterator |
| Inheritance | Extends AbstractMap | Extends Dictionary (legacy) | Extends AbstractMap |
| Ordering | No guarantee | No guarantee | No guarantee |
| Introduced | Java 1.2 | Java 1.0 (legacy) | Java 5 (significantly redesigned Java 8) |
| Atomic operations | No | No | Yes (putIfAbsent, compute, merge) |
| Java 8 treeification | Yes | No | Yes |

**Key Takeaway:** Hashtable is a legacy class. Never use it in new code. Use HashMap for single-threaded code and ConcurrentHashMap for concurrent code.

---

## 13. PriorityQueue

**Difficulty:** Medium | **Interview Frequency:** High  
**Asked at:** Amazon, Google, Facebook (graph algorithms), Bloomberg

### Short Interview Answer (30–60 seconds)

PriorityQueue is implemented as a min-heap using a backing array. The smallest element (by natural order or Comparator) is always at the head. `peek()` returns the minimum in O(1). `add()` and `poll()` are O(log n) because they require heap sift-up and sift-down operations respectively. PriorityQueue does not guarantee ordering of elements beyond the head.

### Deep Explanation

**Min-Heap Array Representation:**

For a heap stored in array `queue[]`:
- Root (minimum): `queue[0]`
- Parent of node at index `i`: `queue[(i - 1) / 2]`
- Left child of node at index `i`: `queue[2*i + 1]`
- Right child of node at index `i`: `queue[2*i + 2]`

**Heap Property (Min-Heap):** Every parent is less than or equal to its children.

**`add(E e)` — O(log n) — Sift Up:**

1. Add element at the end of the array.
2. Compare with parent; if smaller, swap (sift up).
3. Repeat until heap property is restored or root is reached.

**`poll()` — O(log n) — Sift Down:**

1. Return `queue[0]` (minimum).
2. Move last element to `queue[0]`.
3. Compare with smaller child; swap if larger (sift down).
4. Repeat until heap property is restored or leaf is reached.

**`peek()` — O(1):** Simply returns `queue[0]`.

**Initial Capacity:** 11 (default); grows like ArrayList (~1.5x).

**No Null Elements:** Throws NullPointerException.

**Not Thread-Safe:** Use `PriorityBlockingQueue` for concurrent use.

### Real-World Backend Example

**Dijkstra's shortest path algorithm:** A `PriorityQueue<int[]>` stores `[distance, nodeId]` pairs. The node with the smallest current distance is always processed first. `poll()` gives the current minimum-distance node in O(log V).

**Task scheduler:** A background job processor uses `PriorityQueue<ScheduledTask>` ordered by scheduled execution time. The next task to execute is always at the head.

### Java 17 Code Example

```java
import java.util.PriorityQueue;
import java.util.Comparator;
import java.util.Arrays;

public class PriorityQueueExample {

    record Task(String name, int priority) {}

    public static void main(String[] args) {
        // Min-heap by default (natural ordering)
        PriorityQueue<Integer> minHeap = new PriorityQueue<>();
        minHeap.add(5); minHeap.add(1); minHeap.add(3); minHeap.add(2);

        System.out.println(minHeap.peek());   // 1 — O(1)
        System.out.println(minHeap.poll());   // 1 — O(log n), removes
        System.out.println(minHeap.poll());   // 2

        // Max-heap: reverse the Comparator
        PriorityQueue<Integer> maxHeap = new PriorityQueue<>(Comparator.reverseOrder());
        maxHeap.addAll(Arrays.asList(5, 1, 3, 2));
        System.out.println(maxHeap.poll());   // 5

        // Custom object ordering by priority field
        PriorityQueue<Task> taskQueue = new PriorityQueue<>(
            Comparator.comparingInt(Task::priority)  // lowest priority number = first
        );
        taskQueue.add(new Task("low", 10));
        taskQueue.add(new Task("high", 1));
        taskQueue.add(new Task("medium", 5));

        while (!taskQueue.isEmpty()) {
            System.out.println(taskQueue.poll().name()); // high, medium, low
        }

        // Dijkstra-style: [distance, node]
        PriorityQueue<int[]> pq = new PriorityQueue<>(Comparator.comparingInt(a -> a[0]));
        pq.offer(new int[]{0, 0});  // [distance=0, node=0]
        pq.offer(new int[]{4, 1});
        pq.offer(new int[]{2, 2});

        while (!pq.isEmpty()) {
            int[] curr = pq.poll();
            System.out.println("Process node " + curr[1] + " at distance " + curr[0]);
        }
        // Output: node 0 (d=0), node 2 (d=2), node 1 (d=4)
    }
}
```

### Follow-up Questions Interviewers Ask

1. What is the internal data structure of PriorityQueue?
2. Why is `poll()` O(log n) but `peek()` O(1)?
3. How would you implement a max-heap using PriorityQueue?
4. How do you find the Kth largest element using a PriorityQueue?
5. Is PriorityQueue thread-safe?

### Common Mistakes Candidates Make

- Claiming PriorityQueue iterates in sorted order — iteration order is NOT guaranteed to be sorted. Only `poll()` returns elements in order.
- Forgetting to provide a Comparator for custom objects without natural ordering.
- Using `PriorityQueue` in concurrent code without wrapping it.

### Interview Traps

- **Trap:** "Is `for(int x : pq)` sorted?" — No. Only repeated `poll()` gives sorted order.
- **Trap:** "What is the complexity of building a PriorityQueue from n elements?" — O(n) using `addAll()` with heapify, vs O(n log n) for n individual `add()` calls. Java's `PriorityQueue(Collection)` constructor uses the heapify algorithm.

### Quick Revision Notes

- Min-heap backed by array; `queue[0]` is always the minimum.
- `add()` and `poll()` are O(log n); `peek()` is O(1).
- No null elements; not thread-safe (use PriorityBlockingQueue).
- Iteration order NOT guaranteed sorted — only repeated `poll()` is sorted.

![Queue data structure (FIFO)](https://upload.wikimedia.org/wikipedia/commons/7/76/Data_queue.svg)
*Queue — First In First Out (FIFO) with enqueue/dequeue operations*

---

## 14. ArrayDeque

**Difficulty:** Medium | **Interview Frequency:** High  
**Asked at:** Amazon, Google, Microsoft (stack/queue design questions)

### Short Interview Answer (30–60 seconds)

ArrayDeque is a resizable circular array implementation of the Deque interface. It provides O(1) amortized add/remove at both ends. It is preferred over Stack (legacy, synchronized) for stack operations and over LinkedList for queue operations because it avoids per-element heap allocation and benefits from CPU cache locality.

### Deep Explanation

**Circular Array:**

ArrayDeque uses an `Object[] elements` array as a circular buffer with `head` and `tail` pointers:

```java
transient Object[] elements;
transient int head;   // index of front element
transient int tail;   // index where next element will be added (one past end)
```

`head` and `tail` wrap around using bitmask: `(head - 1) & (elements.length - 1)`. The array length is always a power of 2 to enable this bitwise wrap.

**Double-Ended Operations:**

- `addFirst(e)`: `elements[head = (head - 1) & mask] = e`
- `addLast(e)`: `elements[tail] = e; tail = (tail + 1) & mask`
- `pollFirst()`: return `elements[head]`, set to null, `head = (head + 1) & mask`
- `pollLast()`: `tail = (tail - 1) & mask`, return `elements[tail]`, set to null

All are O(1) amortized — no element shifting required.

**Growth:** When `head == tail` (full), capacity doubles and elements are laid out in a new contiguous array.

**ArrayDeque vs Stack:**

`Stack` extends `Vector`, which uses `synchronized` on every operation. ArrayDeque has no synchronization overhead. Prefer ArrayDeque for all stack use cases.

**ArrayDeque vs LinkedList as Queue:**

ArrayDeque is faster because:
1. No per-element object allocation (just array slots).
2. Contiguous memory — better CPU cache utilization.
3. Less GC pressure.

### Real-World Backend Example

BFS (Breadth-First Search) for graph traversal in a social network recommendation engine. `ArrayDeque<Node>` as a queue: `offer()` to enqueue, `poll()` to dequeue. Much faster than `LinkedList<Node>` under high-throughput traversal.

### Java 17 Code Example

```java
import java.util.ArrayDeque;
import java.util.Deque;

public class ArrayDequeExample {

    public static void main(String[] args) {
        Deque<String> deque = new ArrayDeque<>();

        // Stack operations (LIFO) — prefer over java.util.Stack
        deque.push("first");   // addFirst
        deque.push("second");  // addFirst
        deque.push("third");   // addFirst
        System.out.println(deque.pop());  // third — removeFirst

        // Queue operations (FIFO)
        deque.offer("A");   // addLast
        deque.offer("B");   // addLast
        deque.offer("C");   // addLast
        System.out.println(deque.poll());  // A — removeFirst

        // Deque operations (both ends)
        deque.offerFirst("Z");  // addFirst
        deque.offerLast("D");   // addLast
        System.out.println(deque.peekFirst()); // Z — no removal
        System.out.println(deque.peekLast());  // D — no removal

        // BFS with ArrayDeque
        Deque<Integer> queue = new ArrayDeque<>();
        queue.offer(1);  // root node
        while (!queue.isEmpty()) {
            int node = queue.poll();
            System.out.println("Visiting: " + node);
            // Enqueue children
            if (node < 4) {
                queue.offer(node * 2);
                queue.offer(node * 2 + 1);
            }
        }
    }
}
```

### Follow-up Questions Interviewers Ask

1. Why prefer ArrayDeque over Stack for stack operations?
2. Why prefer ArrayDeque over LinkedList for queue operations?
3. Is ArrayDeque thread-safe?
4. Can ArrayDeque store null?

### Common Mistakes Candidates Make

- Using `java.util.Stack` in new code — it is synchronized and extends the legacy `Vector`.
- Forgetting that ArrayDeque does not allow null elements.
- Using LinkedList as a queue when ArrayDeque performs better.

### Quick Revision Notes

- Circular array; O(1) amortized add/remove at both ends.
- Preferred over Stack (legacy, synchronized) and LinkedList (poor cache locality).
- No null elements; not thread-safe.
- Implements both Stack and Queue semantics via Deque interface.

![Stack data structure (LIFO)](https://upload.wikimedia.org/wikipedia/commons/2/29/Data_stack.svg)
*Stack — Last In First Out (LIFO) with push/pop operations*

---

## 15. Fail-fast vs Fail-safe Iterators

**Difficulty:** Medium | **Interview Frequency:** High  
**Asked at:** Amazon, Adobe, MakeMyTrip, Infosys

### Short Interview Answer (30–60 seconds)

Fail-fast iterators throw `ConcurrentModificationException` if the collection is structurally modified during iteration by any means other than the iterator's own `remove()` method. They detect modification by checking `modCount` — a counter incremented on every structural change. Fail-safe iterators operate on a copy of the collection or use weak consistency, so they do not throw exceptions but may not reflect recent changes.

### Deep Explanation

**`modCount` Mechanism:**

Every ArrayList, HashMap, HashSet, etc. maintains:

```java
protected transient int modCount = 0;
```

This counter increments on every structural modification (add, remove, clear, resize). An iterator records `modCount` at creation:

```java
// From ArrayList.Itr (inner class)
int expectedModCount = modCount;

public E next() {
    checkForComodification();
    // ...
}

final void checkForComodification() {
    if (modCount != expectedModCount)
        throw new ConcurrentModificationException();
}
```

If any code outside the iterator modifies the collection between `next()` calls, `modCount != expectedModCount` and the exception is thrown.

**Important Note:** This is a best-effort mechanism, not a guarantee. It detects most concurrent modifications but is not fool-proof (e.g., modifications between `checkForComodification()` and the actual access in `next()` in a multithreaded environment would not be caught).

**Fail-Safe Collections:**

| Collection | Iterator Type | Behavior |
|------------|---------------|----------|
| CopyOnWriteArrayList | Fail-safe | Iterates over snapshot at creation time |
| ConcurrentHashMap | Weakly consistent | Reflects some or all updates made after iterator creation |
| ArrayList, HashMap, HashSet | Fail-fast | Throws ConcurrentModificationException on modification |

**CopyOnWriteArrayList Iterator:**

On creation, captures a reference to the current backing array. All subsequent `next()` calls read from this snapshot. Modifications to the original list create a new array, leaving the iterator's snapshot unchanged.

**ConcurrentHashMap Iterator:**

Provides "weakly consistent" iteration. It does not use a snapshot. Instead, it traverses the live table and provides a best-effort view. It will not throw `ConcurrentModificationException` and will reflect some concurrent modifications.

### Real-World Backend Example

A web server framework maintains a list of request interceptors. Using `CopyOnWriteArrayList` allows one thread to iterate and invoke interceptors while another thread safely adds a new interceptor — no synchronization needed on the read path.

### Java 17 Code Example

```java
import java.util.ArrayList;
import java.util.List;
import java.util.Iterator;
import java.util.ConcurrentModificationException;
import java.util.concurrent.CopyOnWriteArrayList;

public class IteratorTypes {

    public static void main(String[] args) {
        // Fail-fast: ConcurrentModificationException
        List<String> list = new ArrayList<>(List.of("a", "b", "c", "d"));
        try {
            for (String s : list) {
                if (s.equals("b")) {
                    list.remove(s);  // modifies collection during iteration
                }
            }
        } catch (ConcurrentModificationException e) {
            System.out.println("ConcurrentModificationException caught");
        }

        // Correct way to remove during iteration: use Iterator.remove()
        Iterator<String> it = list.iterator();
        while (it.hasNext()) {
            String s = it.next();
            if (s.equals("c")) {
                it.remove();  // safe — does not increment modCount
            }
        }
        System.out.println(list);  // [a, d]

        // Or use removeIf (Java 8+) — cleaner
        list.removeIf(s -> s.equals("a"));
        System.out.println(list);  // [d]

        // Fail-safe: CopyOnWriteArrayList
        CopyOnWriteArrayList<String> cowList = new CopyOnWriteArrayList<>(
            List.of("x", "y", "z")
        );
        for (String s : cowList) {
            cowList.add("new");  // no exception — iterates over snapshot
            System.out.println(s);  // prints x, y, z only (snapshot)
        }
    }
}
```

### Follow-up Questions Interviewers Ask

1. How does fail-fast work internally? What is `modCount`?
2. Is `ConcurrentModificationException` thrown only in multithreaded scenarios?
3. What is the correct way to remove elements while iterating?
4. What is the difference between fail-safe and weakly consistent?

### Common Mistakes Candidates Make

- Thinking fail-fast only applies to concurrent (multithreaded) access — it also triggers in single-threaded code if you modify the collection outside the iterator.
- Not knowing `Iterator.remove()` as the safe removal mechanism during iteration.
- Confusing CopyOnWriteArrayList (snapshot) with ConcurrentHashMap's weakly consistent iterator.

### Quick Revision Notes

- Fail-fast: checks `modCount` on every `next()`; throws `ConcurrentModificationException`.
- Use `Iterator.remove()` or `Collection.removeIf()` for safe removal during iteration.
- Fail-safe collections: `CopyOnWriteArrayList` (snapshot), `ConcurrentHashMap` (weakly consistent).
- `modCount` is best-effort, not thread-safe by itself.

---

## 16. ListIterator

**Difficulty:** Easy | **Interview Frequency:** Medium  
**Asked at:** Capgemini, TCS, mid-tier enterprise companies

### Short Interview Answer (30–60 seconds)

ListIterator extends Iterator with bidirectional traversal and mutation capabilities. It can iterate forward and backward, and can call `add()`, `set()`, and `remove()` during iteration without causing ConcurrentModificationException. It is obtained via `list.listIterator()` and is available only for List implementations.

### Deep Explanation

**Additional Methods over Iterator:**

| Method | Description |
|--------|-------------|
| `hasPrevious()` | Returns true if there are elements before cursor |
| `previous()` | Returns previous element and moves cursor backward |
| `nextIndex()` | Returns index of element that `next()` would return |
| `previousIndex()` | Returns index of element that `previous()` would return |
| `add(E e)` | Inserts element at cursor position |
| `set(E e)` | Replaces last element returned by `next()` or `previous()` |

### Java 17 Code Example

```java
import java.util.ArrayList;
import java.util.List;
import java.util.ListIterator;

public class ListIteratorExample {

    public static void main(String[] args) {
        List<String> list = new ArrayList<>(List.of("a", "b", "c", "d"));

        ListIterator<String> it = list.listIterator();

        // Forward traversal with mutation
        while (it.hasNext()) {
            String s = it.next();
            if (s.equals("b")) {
                it.set("B");    // replace current element
                it.add("B+");   // insert after current position
            }
        }
        System.out.println(list);  // [a, B, B+, c, d]

        // Backward traversal
        while (it.hasPrevious()) {
            System.out.print(it.previous() + " ");
        }
        System.out.println();  // d c B+ B a
    }
}
```

### Follow-up Questions
1. How is ListIterator different from a regular Iterator?
2. Can you use ListIterator to iterate backwards?
3. What happens if you call remove() without calling next() or previous() first?

### Quick Revision Notes

- Bidirectional; supports `add()`, `set()`, `remove()` during iteration.
- Available only for List, not Set or Map.
- Does not throw ConcurrentModificationException for its own mutations.

---

## 17. Collections Utility Class

**Difficulty:** Easy | **Interview Frequency:** Medium  
**Asked at:** General Java interviews, mid-level screening rounds

### Short Interview Answer (30–60 seconds)

`java.util.Collections` is a utility class with static methods for common collection operations: sorting, searching, shuffling, creating synchronized/unmodifiable wrappers, and finding min/max. It only works on Collection implementations (Lists, Sets, Maps via entrySet).

### Deep Explanation

**Sorting:**

`Collections.sort(List)` uses TimSort — a hybrid merge sort + insertion sort with O(n log n) worst case and O(n) best case (already sorted). Since Java 8, `list.sort(comparator)` is preferred as it delegates to `Arrays.sort()` for arrays, which uses the same algorithm.

**Binary Search:**

`Collections.binarySearch(List, key)` requires the list to be sorted and returns the index of the key, or `-(insertionPoint) - 1` if not found.

**Thread-Safety Wrappers:**

`Collections.synchronizedList(list)` wraps every method with `synchronized`. Unlike CopyOnWriteArrayList, iteration requires manual synchronization:

```java
List<String> syncList = Collections.synchronizedList(new ArrayList<>());
synchronized(syncList) {  // REQUIRED for iteration
    for (String s : syncList) { ... }
}
```

**Unmodifiable Wrappers vs Immutable Collections:**

`Collections.unmodifiableList()` creates a read-only view — the underlying list can still be modified through the original reference. Java 9+ `List.of()` creates a truly immutable list with no backing mutable structure.

### Java 17 Code Example

```java
import java.util.*;

public class CollectionsUtility {

    public static void main(String[] args) {
        List<Integer> list = new ArrayList<>(Arrays.asList(3, 1, 4, 1, 5, 9, 2, 6));

        // Sort — TimSort, O(n log n)
        Collections.sort(list);
        System.out.println(list);  // [1, 1, 2, 3, 4, 5, 6, 9]

        // Sort with Comparator
        Collections.sort(list, Comparator.reverseOrder());

        // Binary search — list must be sorted ascending first
        Collections.sort(list);
        int idx = Collections.binarySearch(list, 5);  // returns index of 5
        System.out.println("Index of 5: " + idx);

        // Min/Max
        System.out.println(Collections.min(list));  // 1
        System.out.println(Collections.max(list));  // 9

        // Frequency
        System.out.println(Collections.frequency(list, 1));  // 2

        // Shuffle
        Collections.shuffle(list);

        // Reverse
        Collections.reverse(list);

        // Fill
        Collections.fill(list, 0);

        // Unmodifiable wrapper
        List<String> mutable = new ArrayList<>(List.of("a", "b", "c"));
        List<String> readOnly = Collections.unmodifiableList(mutable);
        // readOnly.add("d");  // throws UnsupportedOperationException
        mutable.add("d");  // this STILL works — readOnly just wraps mutable
        System.out.println(readOnly);  // [a, b, c, d] — shows mutation

        // Better: use List.of() for true immutability (Java 9+)
        List<String> immutable = List.of("x", "y", "z");
        // immutable.add("w");  // UnsupportedOperationException

        // Synchronized wrapper
        List<String> syncList = Collections.synchronizedList(new ArrayList<>());
        synchronized (syncList) {
            for (String s : syncList) {  // must synchronize iteration manually
                System.out.println(s);
            }
        }

        // Disjoint — true if no common elements
        List<Integer> a = List.of(1, 2, 3);
        List<Integer> b = List.of(4, 5, 6);
        System.out.println(Collections.disjoint(a, b));  // true

        // nCopies — creates immutable list of n copies
        List<String> copies = Collections.nCopies(5, "hello");
        System.out.println(copies);  // [hello, hello, hello, hello, hello]
    }
}
```

### Follow-up Questions
1. What is the difference between Collections.unmodifiableList() and List.of()?
2. What algorithm does Collections.sort() use and what is its time complexity?
3. How does Collections.synchronizedList() differ from CopyOnWriteArrayList?

### Quick Revision Notes

- `sort()`: TimSort O(n log n); `binarySearch()`: requires sorted list, O(log n).
- `unmodifiableList()`: read-only view, underlying list still mutable.
- `synchronizedList()`: requires manual sync block for iteration.
- Prefer `List.of()` / `Map.of()` (Java 9+) for true immutability.

---

## 18. Arrays Utility Class

**Difficulty:** Easy | **Interview Frequency:** Medium  
**Asked at:** General Java screening rounds

### Short Interview Answer (30–60 seconds)

`java.util.Arrays` provides static utility methods for array operations: sort, binary search, copy, fill, and comparison. `Arrays.sort()` uses Dual-Pivot Quicksort for primitives and TimSort for objects. `Arrays.parallelSort()` (Java 8+) uses Fork/Join for large arrays.

### Deep Explanation

**Sort Algorithms:**

- `Arrays.sort(int[])` — Dual-Pivot Quicksort (Yaroslavskiy, Bentley, Bloch). O(n log n) average; uses insertion sort for small subarrays.
- `Arrays.sort(Object[])` — TimSort (same as Collections.sort). Stable, O(n log n) worst case.
- `Arrays.parallelSort(int[])` — Fork/Join based parallel sort for large arrays (>8192 elements by default).

**`asList()` Returns a Fixed-Size List:**

`Arrays.asList(arr)` returns a `List` backed by the array. It is fixed-size — `add()` and `remove()` throw `UnsupportedOperationException`. Element replacement (`set()`) is allowed.

### Java 17 Code Example

```java
import java.util.Arrays;
import java.util.List;

public class ArraysUtility {

    public static void main(String[] args) {
        int[] arr = {5, 3, 8, 1, 9, 2};

        // Sort — Dual-Pivot Quicksort for primitives
        Arrays.sort(arr);
        System.out.println(Arrays.toString(arr));  // [1, 2, 3, 5, 8, 9]

        // Parallel sort — better for large arrays (uses Fork/Join)
        int[] large = new int[1_000_000];
        Arrays.fill(large, 42);
        Arrays.parallelSort(large);

        // Binary search — array must be sorted
        int idx = Arrays.binarySearch(arr, 5);
        System.out.println("Index of 5: " + idx);  // 3

        // Copy
        int[] copy = Arrays.copyOf(arr, arr.length);  // full copy
        int[] range = Arrays.copyOfRange(arr, 1, 4);  // [2, 3, 5]

        // Fill
        int[] filled = new int[5];
        Arrays.fill(filled, 7);
        System.out.println(Arrays.toString(filled));  // [7, 7, 7, 7, 7]

        // Equals (element-wise)
        System.out.println(Arrays.equals(arr, copy));  // true

        // Deep equals for 2D arrays
        int[][] a = {{1, 2}, {3, 4}};
        int[][] b = {{1, 2}, {3, 4}};
        System.out.println(Arrays.deepEquals(a, b));   // true
        System.out.println(Arrays.deepToString(a));    // [[1, 2], [3, 4]]

        // asList — fixed-size list backed by array
        String[] strArr = {"x", "y", "z"};
        List<String> list = Arrays.asList(strArr);
        list.set(0, "X");     // OK — modifies array
        // list.add("w");     // UnsupportedOperationException

        strArr[1] = "Y";      // modifies list too — same backing array
        System.out.println(list);  // [X, Y, z]

        // To get a truly independent mutable list:
        List<String> mutable = new java.util.ArrayList<>(Arrays.asList(strArr));
    }
}
```

### Follow-up Questions
1. What sorting algorithm does Arrays.sort() use for primitives vs objects?
2. What is the difference between Arrays.copyOf() and Arrays.copyOfRange()?
3. When would you use Arrays.asList() and what is its limitation?

### Quick Revision Notes

- Primitives: Dual-Pivot Quicksort; Objects: TimSort (stable).
- `parallelSort()` uses Fork/Join; beneficial for arrays > 8192 elements.
- `asList()` returns fixed-size, array-backed list — no add/remove.
- `copyOf` vs `copyOfRange` for partial/full copies.

---

## 19. Comparable vs Comparator

**Difficulty:** Medium | **Interview Frequency:** High  
**Asked at:** Amazon, Goldman Sachs, Wipro, all companies using sorting

### Short Interview Answer (30–60 seconds)

`Comparable` defines the natural ordering of a class by implementing the `compareTo()` method within the class itself. `Comparator` defines an external ordering, allowing multiple different sort sequences without modifying the class. In Java 8+, Comparator has been significantly enhanced with default methods for chaining (`thenComparing`), reversing (`reversed`), and handling nulls (`nullsFirst`, `nullsLast`).

### Deep Explanation

**Comparable:**

```java
public interface Comparable<T> {
    int compareTo(T o);
    // Returns: negative if this < o, 0 if equal, positive if this > o
}
```

Used by: `TreeSet`, `TreeMap`, `Collections.sort()`, `Arrays.sort()` for the default (natural) order.

**Comparator:**

```java
@FunctionalInterface
public interface Comparator<T> {
    int compare(T o1, T o2);
    // Returns: negative if o1 < o2, 0 if equal, positive if o1 > o2
}
```

**Contract — Consistency with equals:**

It is strongly recommended that `compareTo()` is consistent with `equals()`: `(x.compareTo(y) == 0)` should imply `x.equals(y)`. If violated, TreeSet/TreeMap will behave as if `equals()` were never overridden.

**Java 8 Comparator Chaining:**

```java
Comparator.comparing(Employee::getDepartment)
          .thenComparing(Employee::getSalary, Comparator.reverseOrder())
          .thenComparing(Comparator.nullsLast(Employee::getName));
```

### Real-World Backend Example

Sorting API response records: primary sort by `createdDate` descending (most recent first), secondary sort by `id` ascending for deterministic ordering when dates are equal.

### Java 17 Code Example

```java
import java.util.*;
import java.time.LocalDate;

public class ComparableVsComparator {

    // Comparable: natural ordering built into the class
    static class Employee implements Comparable<Employee> {
        String name;
        String department;
        double salary;
        LocalDate hireDate;

        Employee(String name, String dept, double salary, LocalDate hireDate) {
            this.name = name; this.department = dept;
            this.salary = salary; this.hireDate = hireDate;
        }

        @Override
        public int compareTo(Employee other) {
            // Natural order: by name alphabetically
            return this.name.compareTo(other.name);
        }

        @Override
        public String toString() {
            return name + "(" + department + ", " + salary + ")";
        }
    }

    public static void main(String[] args) {
        List<Employee> employees = new ArrayList<>(Arrays.asList(
            new Employee("Charlie", "Engineering", 95000, LocalDate.of(2020, 3, 1)),
            new Employee("Alice",   "Marketing",   80000, LocalDate.of(2019, 6, 15)),
            new Employee("Bob",     "Engineering", 110000, LocalDate.of(2021, 1, 10)),
            new Employee("Diana",   "Marketing",   85000, LocalDate.of(2018, 9, 1))
        ));

        // Natural ordering (Comparable.compareTo) — alphabetical by name
        Collections.sort(employees);
        System.out.println("Natural order: " + employees);

        // Comparator — sort by salary descending
        employees.sort(Comparator.comparingDouble(Employee::salary).reversed());
        System.out.println("By salary desc: " + employees);

        // Chained comparator: department asc, then salary desc
        Comparator<Employee> byDeptThenSalaryDesc =
            Comparator.comparing((Employee e) -> e.department)
                      .thenComparing(Comparator.comparingDouble((Employee e) -> e.salary)
                                               .reversed());
        employees.sort(byDeptThenSalaryDesc);
        System.out.println("By dept, salary desc: " + employees);

        // Null-safe comparator
        List<String> withNulls = new ArrayList<>(Arrays.asList("banana", null, "apple", null, "cherry"));
        withNulls.sort(Comparator.nullsLast(Comparator.naturalOrder()));
        System.out.println("Nulls last: " + withNulls);  // [apple, banana, cherry, null, null]

        // TreeSet uses natural ordering (Comparable)
        TreeSet<Employee> sortedSet = new TreeSet<>();
        sortedSet.addAll(employees);
        System.out.println("TreeSet (natural): " + sortedSet);

        // TreeSet with custom Comparator
        TreeSet<Employee> bySalary = new TreeSet<>(
            Comparator.comparingDouble((Employee e) -> e.salary)
        );
        bySalary.addAll(employees);
        System.out.println("TreeSet (salary): " + bySalary);
    }
}
```

### Follow-up Questions Interviewers Ask

1. What is the difference between `Comparable` and `Comparator`?
2. What does it mean for `compareTo()` to be consistent with `equals()`?
3. What happens in a TreeMap if two keys compare as 0 but are not `equals()`?
4. How do you sort by multiple fields in Java 8?

### Common Mistakes Candidates Make

- Implementing `compareTo()` by subtracting integers — risks integer overflow. Use `Integer.compare(a, b)` instead.
- Forgetting that `Comparator.comparing()` requires a `Comparable` return type for the extractor (or use `comparingInt`, `comparingDouble`).
- Not making `Comparator` consistent with `equals()` in `TreeSet/TreeMap`, leading to missing entries.

### Quick Revision Notes

- `Comparable`: `compareTo()` — natural ordering, within the class.
- `Comparator`: `compare()` — external ordering, multiple orderings possible.
- Java 8: `Comparator.comparing().thenComparing().reversed().nullsFirst()`.
- Never subtract integers in comparisons — use `Integer.compare()`.

---

## 20. CopyOnWriteArrayList

**Difficulty:** Medium | **Interview Frequency:** Medium  
**Asked at:** Amazon, Netflix, event-driven architecture interviews

### Short Interview Answer (30–60 seconds)

CopyOnWriteArrayList creates a fresh copy of the entire backing array on every write operation (add, set, remove). Reads are lock-free and operate directly on the current array. This makes it ideal for read-heavy, rarely-modified lists where thread safety is needed without locking on every read — for example, maintaining a list of event listeners or request filters.

### Deep Explanation

**Write Operation:**

```java
// CopyOnWriteArrayList.add() — simplified
public boolean add(E e) {
    synchronized (lock) {                          // acquire lock
        Object[] elements = getArray();
        int len = elements.length;
        Object[] newElements = Arrays.copyOf(elements, len + 1);  // copy entire array
        newElements[len] = e;
        setArray(newElements);                     // atomic reference swap
        return true;
    }                                              // release lock
}
```

Every mutation locks, copies the full array, modifies the copy, then atomically replaces the array reference. The old array remains valid for any readers currently using it.

**Read Operation (Lock-Free):**

```java
public E get(int index) {
    return elementAt(getArray(), index);  // no lock — reads volatile array reference
}
```

`getArray()` returns a `volatile Object[]`. The volatile guarantee ensures readers always see the latest array reference without locking.

**Iterator Snapshot:**

When an iterator is created, it captures the current array reference. Subsequent modifications create new arrays, leaving the iterator's snapshot unchanged. Iterators never throw `ConcurrentModificationException`.

**Performance Characteristics:**

| Operation | Time Complexity | Locking |
|-----------|-----------------|---------|
| `get(i)` | O(1) | None |
| `contains(o)` | O(n) | None |
| `add(e)` | O(n) — full array copy | Yes |
| `remove(i)` | O(n) — full array copy | Yes |
| Iteration | O(n) | None (snapshot) |

**Use Cases:**

- Event listener lists (many reads, rare adds/removes).
- HTTP filter chains in web servers.
- Plugin/interceptor registries.
- Publisher-subscriber systems with infrequent subscriber changes.

**When NOT to Use:**

Any scenario with frequent writes. The O(n) copy on every write makes it unsuitable for frequently modified lists. Use `Collections.synchronizedList()` or explicit locking instead.

### Real-World Backend Example

A Spring application's `ApplicationEventMulticaster` internally uses CopyOnWriteArrayList to store event listeners. At startup, listeners are registered (few writes). At runtime, events are published and all listeners are invoked (many reads). The lock-free reads ensure event broadcasting does not become a bottleneck.

### Java 17 Code Example

```java
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.List;
import java.util.Iterator;

public class CopyOnWriteArrayListExample {

    interface EventListener {
        void onEvent(String event);
    }

    public static void main(String[] args) throws InterruptedException {
        CopyOnWriteArrayList<EventListener> listeners = new CopyOnWriteArrayList<>();

        // Register listeners (writes — copy array each time)
        listeners.add(event -> System.out.println("Listener 1: " + event));
        listeners.add(event -> System.out.println("Listener 2: " + event));
        listeners.add(event -> System.out.println("Listener 3: " + event));

        // Simulate concurrent publish and add
        Thread publisher = new Thread(() -> {
            for (int i = 0; i < 5; i++) {
                // Lock-free iteration — no ConcurrentModificationException
                for (EventListener listener : listeners) {
                    listener.onEvent("event-" + i);
                }
            }
        });

        Thread adder = new Thread(() -> {
            // Adding while publisher iterates — safe, no exception
            listeners.add(event -> System.out.println("Late listener: " + event));
        });

        publisher.start();
        adder.start();
        publisher.join();
        adder.join();

        // Iterator works on snapshot — does not see concurrent additions
        Iterator<EventListener> it = listeners.iterator();
        // Adding more listeners here does NOT affect 'it'
        listeners.add(event -> System.out.println("After iterator: " + event));
        System.out.println("Iterator snapshot size is for 4 listeners, map now has 5");

        System.out.println("Final listener count: " + listeners.size());
    }
}
```

### Follow-up Questions Interviewers Ask

1. Why is CopyOnWriteArrayList suitable for read-heavy use cases?
2. Why would it be inefficient in a write-heavy scenario?
3. Does CopyOnWriteArrayList's iterator throw ConcurrentModificationException?
4. What is the difference between CopyOnWriteArrayList and synchronizedList?

### Common Mistakes Candidates Make

- Using CopyOnWriteArrayList in write-heavy scenarios — O(n) write cost makes this catastrophic at scale.
- Forgetting that the iterator sees a snapshot — code expecting the iterator to see a concurrent add will be surprised.

### Quick Revision Notes

- Every write: lock + copy entire array + swap reference.
- Every read: lock-free, reads volatile array reference.
- Iterator: snapshot-based, never throws ConcurrentModificationException.
- Best for: read-heavy, rarely-modified; bad for: frequent writes.

---

## 21. BlockingQueue

**Difficulty:** Medium | **Interview Frequency:** Medium  
**Asked at:** Amazon, Uber, backend systems design rounds

### Short Interview Answer (30–60 seconds)

BlockingQueue is a thread-safe Queue that blocks the calling thread when the queue is full (on put) or empty (on take). It is the foundation of the producer-consumer pattern in Java. Common implementations: `ArrayBlockingQueue` (bounded, backed by array), `LinkedBlockingQueue` (optionally bounded, backed by linked nodes).

### Deep Explanation

**Key Methods:**

| Method | Behavior when Full/Empty |
|--------|--------------------------|
| `add(e)` / `remove()` | Throws exception |
| `offer(e)` / `poll()` | Returns false/null |
| `put(e)` / `take()` | **Blocks indefinitely** |
| `offer(e, time, unit)` / `poll(time, unit)` | Blocks for timeout |

**ArrayBlockingQueue vs LinkedBlockingQueue:**

| Feature | ArrayBlockingQueue | LinkedBlockingQueue |
|---------|-------------------|---------------------|
| Backing | Array | Linked nodes |
| Capacity | Always bounded | Optional bound (default: Integer.MAX_VALUE) |
| Locking | Single lock (put and take contend) | Two locks (putLock, takeLock — separate) |
| Memory | Lower per-element overhead | Higher per-element overhead |
| Throughput | Lower under heavy contention | Higher under concurrent put+take |
| Fairness | Optional (FIFO among waiting threads) | No fairness option |

LinkedBlockingQueue uses two separate locks (`putLock` and `takeLock`), allowing producers and consumers to operate concurrently without contending on the same lock. This is why it typically has higher throughput than ArrayBlockingQueue under concurrent producer-consumer scenarios.

**PriorityBlockingQueue:**

Unbounded, orders elements by natural order or Comparator. `put()` never blocks (unbounded). `take()` blocks if empty.

**SynchronousQueue:**

Capacity of zero. Every `put()` blocks until a corresponding `take()` arrives and vice versa. Used in `Executors.newCachedThreadPool()` for direct handoff between producer and consumer threads.

### Real-World Backend Example

A web scraper service uses `LinkedBlockingQueue<URL>` as a work queue. A pool of downloader threads call `take()` (blocking when queue is empty). A coordinator thread calls `put()` with new URLs to crawl. The blocking behavior provides natural backpressure — the coordinator stops adding URLs if the queue is full.

### Java 17 Code Example

```java
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.TimeUnit;

public class BlockingQueueExample {

    record Task(int id, String payload) {}

    public static void main(String[] args) throws InterruptedException {
        // Bounded queue with capacity 10
        BlockingQueue<Task> queue = new ArrayBlockingQueue<>(10);

        // Producer thread
        Thread producer = new Thread(() -> {
            try {
                for (int i = 0; i < 20; i++) {
                    Task task = new Task(i, "payload-" + i);
                    queue.put(task);  // blocks if queue full (capacity=10)
                    System.out.println("Produced: " + task.id());
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        // Consumer thread
        Thread consumer = new Thread(() -> {
            try {
                while (true) {
                    // blocks for up to 2 seconds if queue empty
                    Task task = queue.poll(2, TimeUnit.SECONDS);
                    if (task == null) break;  // timeout — no more tasks
                    System.out.println("Consumed: " + task.id());
                    Thread.sleep(100);  // simulate processing
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        producer.start();
        consumer.start();
        producer.join();
        consumer.join();

        // LinkedBlockingQueue — better throughput (separate put/take locks)
        BlockingQueue<String> lbq = new LinkedBlockingQueue<>(100);
        lbq.offer("msg1");  // non-blocking, returns false if full
        lbq.put("msg2");    // blocks if full
        String msg = lbq.take();  // blocks if empty
        System.out.println("Consumed from LBQ: " + msg);
    }
}
```

### Follow-up Questions Interviewers Ask

1. What is the difference between `put()` and `offer()` in BlockingQueue?
2. When would you use ArrayBlockingQueue vs LinkedBlockingQueue?
3. How does BlockingQueue implement backpressure?
4. What is SynchronousQueue used for?

### Quick Revision Notes

- `put()`/`take()` block; `offer()`/`poll()` return immediately; timed variants for bounded wait.
- ArrayBlockingQueue: bounded, single lock; LinkedBlockingQueue: optionally bounded, two locks (higher throughput).
- SynchronousQueue: zero capacity, direct handoff.
- Natural fit for producer-consumer pattern with built-in backpressure.

---

## 22. Master Comparison Table

| Collection | Thread Safe | Ordering | Null Keys | Null Values | `get(key)` | `add(e)` / `put(k,v)` | `remove` | Backed By |
|------------|-------------|----------|-----------|-------------|------------|----------------------|----------|-----------|
| ArrayList | No | Insertion | N/A | Yes | O(1) | O(1) amortized | O(n) | Object[] |
| LinkedList | No | Insertion | N/A | Yes | O(n) | O(1) head/tail | O(1) if at ends | Doubly linked list |
| ArrayDeque | No | Insertion | N/A | No | O(1) head/tail | O(1) amortized | O(1) head/tail | Object[] circular |
| HashSet | No | None | Yes (1) | N/A | O(1) avg | O(1) avg | O(1) avg | HashMap |
| LinkedHashSet | No | Insertion | Yes (1) | N/A | O(1) avg | O(1) avg | O(1) avg | LinkedHashMap |
| TreeSet | No | Sorted | No | N/A | O(log n) | O(log n) | O(log n) | TreeMap (RB tree) |
| HashMap | No | None | Yes (1) | Yes | O(1) avg | O(1) avg | O(1) avg | Array + linked list/tree |
| LinkedHashMap | No | Insertion or Access | Yes (1) | Yes | O(1) avg | O(1) avg | O(1) avg | HashMap + doubly linked list |
| TreeMap | No | Sorted | No | Yes | O(log n) | O(log n) | O(log n) | Red-Black tree |
| Hashtable | Yes (full lock) | None | No | No | O(1) avg | O(1) avg | O(1) avg | Array + linked list (legacy) |
| ConcurrentHashMap | Yes (per-bucket) | None | No | No | O(1) avg | O(1) avg | O(1) avg | Array + linked list/tree |
| CopyOnWriteArrayList | Yes (write-lock) | Insertion | N/A | Yes | O(1) | O(n) | O(n) | Object[] (copied on write) |
| PriorityQueue | No | Priority | N/A | No | O(1) peek | O(log n) | O(log n) | Object[] min-heap |
| ArrayBlockingQueue | Yes | FIFO | N/A | No | O(1) | O(1) / blocks | O(1) / blocks | Object[] circular |
| LinkedBlockingQueue | Yes | FIFO | N/A | No | O(1) | O(1) / blocks | O(1) / blocks | Doubly linked list |
| PriorityBlockingQueue | Yes | Priority | N/A | No | O(1) peek | O(log n) | O(log n) | Object[] min-heap |

**Notes:**
- "Null Keys: Yes (1)" means exactly one null key is allowed.
- "O(1) avg" means O(1) average case; O(log n) worst case in Java 8+ due to treeification.
- Thread safety in ConcurrentHashMap is per-bucket — concurrent reads are always lock-free.
- `get()` column for List types refers to `get(index)`; for Map types refers to `get(key)`.

---

## Quick Reference: Interview Decision Tree

```
Need a List?
├── Thread-safe reads, rare writes → CopyOnWriteArrayList
├── Thread-safe with frequent writes → Collections.synchronizedList(ArrayList)
├── Stack operations → ArrayDeque
├── Queue operations → ArrayDeque
├── Random access heavy → ArrayList (pre-size if count known)
└── Only head/tail operations (rare use) → LinkedList

Need a Set?
├── No ordering needed → HashSet
├── Insertion order needed → LinkedHashSet
└── Sorted order needed → TreeSet

Need a Map?
├── Single-threaded → HashMap (pre-size if count known)
├── Insertion order → LinkedHashMap
├── LRU cache → LinkedHashMap (access-order + removeEldestEntry)
├── Sorted keys / range queries → TreeMap
└── Multi-threaded → ConcurrentHashMap

Need a Queue?
├── Priority order → PriorityQueue
├── Thread-safe blocking → ArrayBlockingQueue / LinkedBlockingQueue
└── Direct handoff → SynchronousQueue
```

---

*End of Chapter 3: Java Collections Framework*

*Next: Chapter 4 — Java Concurrency and Multithreading*



