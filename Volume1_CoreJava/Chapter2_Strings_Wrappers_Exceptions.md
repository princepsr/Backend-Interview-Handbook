# Volume 1: Core Java
# Chapter 2: Strings, Wrappers & Exceptions

---

## Table of Contents
1. String Immutability
2. String Pool and Interning
3. String Comparison
4. StringBuilder vs StringBuffer
5. Key String Methods
6. String-to-int Conversions
7. Autoboxing and Unboxing
8. Integer Cache (-128 to 127)
9. Null Unboxing NullPointerException
10. Comparable vs Comparator
11. Exception Hierarchy
12. Checked vs Unchecked Exceptions
13. try-catch-finally Execution Order
14. try-with-resources
15. Multi-catch
16. Custom Exceptions
17. Exception Chaining
18. Common Exception Mistakes
19. Comparison Tables

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: String Immutability

**Difficulty:** Easy | **Frequency:** High | **Companies:** All

---

### The Idea

Imagine a sticky note pinned to a board. Once written, no one can erase or change the text — if you want a different message, you write a new note. That is exactly how Java Strings work. The text inside a String is fixed the moment it is created. Any operation that "changes" a String actually produces a brand-new object and leaves the original untouched.

This constraint was not an accident. The designers needed Strings to be safely shareable — passed between threads, stored as map keys, embedded in security-sensitive paths like class names and database URLs — without anyone being able to corrupt them after the fact. Making them immutable solved all of those problems in one move.

The "why this exists" moment: if Strings could be changed in place, a HashMap key could silently mutate after insertion, breaking the map's internal structure. A database URL shared between two threads could be corrupted mid-connection. Immutability rules all of that out without a single lock.

### How It Works

Internally, Java stores the string's characters in a private array that nothing outside the class can reach:

```
// Simplified internal layout (Java 9+)
class String {
    private final byte[] value   // the actual characters — no one outside can touch this
    private final byte   coder   // LATIN1 (1 byte/char) or UTF16 (2 bytes/char)
    private       int    hash    // cached result of hashCode(), 0 until first call
}
```

Three design choices lock this down:
1. `value` is `private` — no outside code can get a reference to the array.
2. `value` is `final` — the reference itself cannot be swapped for a different array.
3. The `String` class is `final` — no subclass can override methods to sneak in mutation.

Before Java 9 the array was `char[]` (2 bytes per character always). Java 9 introduced **Compact Strings**: the array became `byte[]` and a `coder` field records the encoding. Pure ASCII/Latin-1 strings use 1 byte per character, cutting memory roughly in half for typical English text.

The `hash` field is the one apparent exception — it starts at 0 and is written on the first `hashCode()` call. This is an intentional "benign data race": two threads might both compute the hash simultaneously, but they get the same answer, so correctness is never violated.

**The four benefits immutability buys:**

| Benefit | How immutability enables it |
|---|---|
| String Pool | JVM can hand the same object to many variables — nobody can corrupt it |
| HashCode caching | Computed once, stored in `hash`, never needs recomputation |
| Thread safety | No mutable state means no synchronization needed |
| Security | Class names, URLs, passwords cannot be altered after creation |

```java
public class StringImmutabilityDemo {
    public static void main(String[] args) {
        String original = "jdbc:postgresql://localhost:5432/mydb";

        // Every "modification" produces a new object
        String modified = original.replace("localhost", "prod-db.internal.com");

        System.out.println(original);             // unchanged
        System.out.println(modified);             // new string
        System.out.println(original == modified); // false — different objects

        // hashCode is computed once and cached
        int h1 = original.hashCode();
        int h2 = original.hashCode(); // reads cached value
        System.out.println(h1 == h2); // true
    }
}
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"Why is String immutable in Java?"**

**One-line answer:** Because its internal character array is private and final, and the class itself is final — so neither the data nor the type can be changed.

> **Full answer to give in an interview:**
> "String is immutable because of how it is designed internally. The characters are stored in a private final byte array — private so outside code cannot get a reference to it, and final so the reference cannot be swapped. The class itself is also declared final, which means no subclass can override methods to introduce mutation.
>
> This design gives us four concrete benefits. First, the JVM can maintain a String Pool — a cache of unique string objects — because it knows no one can change them after they are stored. Second, the hashCode can be computed once and cached in a field called hash, which is zero until the first call and then stays fixed; this makes HashMap lookups on String keys fast. Third, strings are automatically thread-safe because there is no mutable state to race on. And fourth, strings used in security-sensitive places like class loading, database URLs, and file paths cannot be corrupted by code that receives them later.
>
> One subtlety worth mentioning: in Java 9 and later, the backing store changed from char array to byte array with a companion coder field. Strings that contain only Latin-1 characters use one byte per character instead of two, cutting memory roughly in half. The immutability contract is the same."

*Deliver the four benefits as a short list — interviewers often nod at "String Pool" and "hashCode caching" because those are the non-obvious ones.*

**Gotcha follow-up they'll ask:** *"If String is immutable, why does it have a non-final field called hash?"*

> The `hash` field starts at zero and is written once on the first `hashCode()` call. This is called a benign data race — two threads might both compute the hash simultaneously, but since the result is deterministic (same characters always produce the same hash), they both write the same value. Correctness is never violated, so no synchronization is needed.

---

#### Q2 — Tradeoff Question

**"What is the cost of String immutability?"**

**One-line answer:** Every "modification" allocates a new object, which creates garbage and pressures the GC in tight loops.

> **Full answer to give in an interview:**
> "The main cost is allocation pressure. Because no String can be modified in place, any operation that looks like a modification — concatenation, replace, substring — produces a brand-new String object. The original becomes garbage for the GC to collect.
>
> In a tight loop this becomes O(n squared) in both time and memory. If I concatenate n strings together one at a time using the plus operator, each iteration copies all the characters accumulated so far into a new object. With 1000 strings each of length 10, the last iteration copies 9990 characters into a new object, and the total work is roughly 10 plus 20 plus ... plus 9990 — proportional to n squared.
>
> The fix is to use StringBuilder, which wraps a mutable byte array internally. Appending to a StringBuilder is amortized O(1) because the array only needs to be copied when it runs out of capacity, and when it does, it doubles in size. Only the final call to toString produces a String object.
>
> So the tradeoff is: immutability buys safety and cacheability at the cost of allocation. For read-heavy workloads that is a great trade. For write-heavy workloads like building large strings, you step outside String and use the mutable builder."

*Mention the O(n²) problem specifically — it signals you understand performance implications, not just the API.*

**Gotcha follow-up they'll ask:** *"Does the Java compiler optimize string concatenation automatically?"*

> For a single-statement expression like `"a" + "b" + "c"`, the compiler optimizes the whole thing — in Java 9 and later it uses a mechanism called invokedynamic with StringConcatFactory, which can pre-size a single buffer. But inside a loop, the compiler creates a new builder object on every iteration, so the O(n squared) problem remains. The optimization does not cross loop boundaries.

---

#### Q3 — Design Scenario

**"You are building a configuration loader that reads database credentials from environment variables and passes them to multiple service beans. What does String immutability guarantee here, and what does it not guarantee?"**

**One-line answer:** Immutability guarantees no bean can corrupt the credential strings, but it does not prevent the string content from being read in memory by a heap dump.

> **Full answer to give in an interview:**
> "String immutability guarantees that once I read the database URL or password into a String and pass it to five different beans, none of those beans can alter the value. There is no method on String that changes the backing array, so even a buggy bean cannot accidentally corrupt the credentials seen by another bean. This is the security benefit of immutability — it is essentially free defensive copying.
>
> What immutability does not protect against is memory inspection. A heap dump or a thread with reflective access can read the contents of the String's private byte array. In fact, Java's security guidelines recommend storing passwords in char arrays rather than Strings for exactly this reason: a char array can be explicitly zeroed after use, while a String's content stays in memory until GC collects it and the memory is overwritten.
>
> So in practice: for URLs and connection parameters, String is fine. For passwords, the best practice is to receive them as char arrays, use them, and immediately fill the array with zeros."

*The char-array-for-passwords point is a strong signal of security awareness — interviewers at financial or infrastructure companies often follow up on it.*

**Gotcha follow-up they'll ask:** *"Can you make a String mutable using reflection?"*

> Technically yes — you can call `Field.setAccessible(true)` on the private `value` field and overwrite the array. But this breaks the String Pool: if the string is a pool entry shared by multiple variables, mutating it corrupts all of them simultaneously. It also produces undefined behavior because the JVM's internal string handling assumes the contract holds. This is never done in production code; it is only a demonstration that immutability is enforced by convention and access control, not by hardware protection.

---

> **Common Mistake — Confusing `final` variable with immutable object:** Declaring `final String s` means the variable `s` cannot be reassigned to a different object. The String itself is immutable regardless of whether the variable is final. These are two separate things.

> **Common Mistake — Wrong internal type:** Saying the backing store is `char[]` has been incorrect since Java 9. It is `byte[]` with a `coder` field.

> **Common Mistake — "Immutable means synchronized":** There is no synchronization inside String. It is thread-safe because there is nothing to synchronize — no mutable state exists. Saying it is synchronized will flag you as someone who has memorized a phrase without understanding it.

**Quick Revision (one line):** String is immutable because its private final byte array is unreachable from outside and the class is final — this enables the String Pool, hashCode caching, thread safety, and security, at the cost of allocation on every "modification."

---

## Topic 2: String Pool and Interning

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google

---

### The Idea

Imagine a shared whiteboard where common phrases are written once. Anyone who needs "hello" does not write it again — they just point to the one already on the board. That is the String Pool: a JVM-managed cache of unique string objects. When your code writes `String s = "hello"`, the JVM checks the whiteboard first. If "hello" is already there, it hands back the same reference instead of creating a new object.

This exists because strings are everywhere in Java programs — HTTP headers, log messages, field names, SQL fragments — and most of them repeat. Without pooling, each occurrence would be a separate object consuming heap space. The pool makes string literals essentially free after the first one.

The "why this matters" insight: because the pool guarantees one canonical object per unique string value, you can safely compare pool strings with `==` (reference equality). But the moment a string is built at runtime — by concatenation, deserialization, or `new String(...)` — it lives outside the pool and `==` breaks.

### How It Works

The pool is implemented as a hash table inside the JVM called `StringTable`. Each entry is a weak reference — meaning if application code holds no other reference to that string, it can be garbage collected and the entry is removed automatically.

```
// Simplified pool logic for a string literal
when JVM loads: String s = "hello"
  look up "hello" in StringTable
  if found  → return existing reference
  if absent → create String object on heap, add weak reference to StringTable, return reference
```

**Where the pool lives (this answer matters in interviews):**

| Era | Location | Problem |
|---|---|---|
| Before Java 7 | PermGen (fixed-size, off-heap) | Too many interned strings → OutOfMemoryError: PermGen space |
| Java 7+ | Main heap | Garbage collected like any other object — no PermGen risk |
| Java 8+ | Main heap (PermGen removed entirely, replaced by Metaspace) | Same as Java 7 |

**When two variables share the same pool reference — guaranteed by the Java Language Specification:**

```
String a = "hello"   // pool entry created
String b = "hello"   // same pool entry returned
a == b               // true — both point to the same object
```

**When they do NOT share a reference:**

```
String c = new String("hello")     // explicitly allocates a new heap object, bypasses pool
String variable = "hel"
String d = variable + "lo"         // runtime concatenation — not a compile-time constant
a == c  // false
a == d  // false
```

**Compile-time constant folding** is the subtle part. If both operands are compile-time constants, `javac` collapses the concatenation before the program runs:

```
final String prefix = "hel"       // final local — compile-time constant
String e = prefix + "lo"          // folded to "hello" at compile time → pool entry
a == e  // true

String prefix2 = "hel"            // NOT final — not a compile-time constant
String f = prefix2 + "lo"         // computed at runtime → new heap object
a == f  // false
```

**`intern()` — the manual pool gate:**

```
String heapString = new String("hello")    // not in pool
String canonical  = heapString.intern()    // look up pool; add if absent; return reference
canonical == a  // true
```

```java
public class StringPoolDemo {
    public static void main(String[] args) {
        String s1 = "order_placed";
        String s2 = "order_placed";
        System.out.println(s1 == s2);           // true — same pool entry

        String s3 = new String("order_placed");
        System.out.println(s1 == s3);           // false — s3 is a heap object
        System.out.println(s1.equals(s3));      // true — same content

        String s4 = s3.intern();
        System.out.println(s1 == s4);           // true — intern returns pool reference

        final String prefix = "order";
        String s5 = prefix + "_placed";         // compile-time constant — folded
        System.out.println(s1 == s5);           // true

        String prefix2 = "order";               // not final
        String s6 = prefix2 + "_placed";
        System.out.println(s1 == s6);           // false — runtime concat
    }
}
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q4 — Concept Check

**"What is the String Pool, and where does it live?"**

**One-line answer:** The String Pool is a JVM-internal hash table that caches one canonical object per unique string literal, and since Java 7 it lives on the main heap.

> **Full answer to give in an interview:**
> "The String Pool — also called the String Intern Table or StringTable — is a hash table maintained inside the JVM. When the JVM encounters a string literal in code, it checks this table first. If an entry exists for that value, it returns the existing object reference. If not, it creates a new String object on the heap, stores a weak reference to it in the table, and returns the reference. The result is that all string literals with the same content share a single object in memory.
>
> Where it lives changed in Java 7. Before that, the pool was in PermGen — a fixed-size memory region separate from the main heap. If an application interned too many strings, it would hit OutOfMemoryError with the message 'PermGen space'. Starting with Java 7, the pool was moved to the main heap so that the garbage collector can reclaim entries whose referents are no longer reachable. Java 8 removed PermGen entirely, replacing it with Metaspace, which uses native memory. But the String Pool has been on the main heap since Java 7.
>
> The pool is controlled by the JVM flag -XX:StringTableSize, which sets the number of hash buckets. In Java 11 and later the default is about one million buckets."

*The PermGen → heap migration is a high-frequency interview detail at companies that care about JVM internals.*

**Gotcha follow-up they'll ask:** *"Are strings in the pool eligible for garbage collection?"*

> Yes, since Java 7. The pool stores weak references. A weak reference does not prevent garbage collection — if the only references to a string object are weak references in the pool, the GC can collect that object and the pool entry is automatically removed. Before Java 7, pool entries were effectively permanent because PermGen was not garbage collected in the same way.

---

#### Q5 — Tradeoff Question

**"When is calling `intern()` a good idea, and when does it backfire?"**

**One-line answer:** Intern when you have a bounded set of high-reuse strings (like enum-like codes); avoid it for unbounded or low-reuse strings because filling the StringTable wastes heap and increases GC work.

> **Full answer to give in an interview:**
> "Calling intern is a good idea when you have a small, bounded set of string values that appear very frequently — for example, event type codes like ORDER_PLACED or PAYMENT_FAILED arriving from a message queue. Each deserialized message creates a new String object on the heap. Calling intern on those strings means all events of the same type share one object. If you are processing millions of events per second, the reduction in object count and GC pressure can be significant.
>
> Where it backfires is when the set of unique strings is large or unbounded. Every interned string occupies a slot in the StringTable. If I intern the text body of every incoming HTTP request — which could be megabytes, all unique — I am filling the StringTable with objects that provide no sharing benefit. The GC then has to spend time sweeping weak references from the table even when those strings are no longer needed.
>
> The practical rule: intern strings that resemble enum values — short, repeated, drawn from a small alphabet. Leave everything else alone. In modern Java there are often better alternatives: use actual enums, or use a dedicated ConcurrentHashMap as an application-level intern pool where you have full control over eviction."

*Mentioning the ConcurrentHashMap alternative shows practical production thinking.*

**Gotcha follow-up they'll ask:** *"How many String objects does `new String("abc")` create?"*

> One or two, depending on context. If the literal "abc" has already appeared elsewhere in the program, its pool entry already exists — so only the heap object is new, giving one new object. If this is the first time "abc" has been seen, the JVM first creates the pool entry (one object), then new String(...) creates the heap copy (another object) — two total. In an interview the safe answer is "one or two depending on whether the pool entry already exists."

---

#### Q6 — Design Scenario

**"A high-throughput Kafka consumer processes five million events per second. Each event has a String field called eventType which is always one of ten possible values. How would you reduce allocation pressure from this field?"**

**One-line answer:** Call `eventType = eventType.intern()` after deserialization to replace each heap-allocated String with the single canonical pool instance for that value.

> **Full answer to give in an interview:**
> "The problem is that each Kafka message deserialization creates a brand-new String object on the heap for the eventType field, even though the value is always one of ten strings. At five million events per second, that is five million short-lived String objects per second going through the garbage collector.
>
> The fix is to intern the eventType immediately after deserialization: `event.eventType = event.eventType.intern()`. Intern looks up the value in the JVM's StringTable. Since there are only ten possible values, those ten objects will be in the pool after the first ten events. Every subsequent call to intern returns the existing pool reference without creating a new object. The deserialized String becomes garbage immediately, and the GC sees far fewer live objects.
>
> An alternative that gives more control is to maintain a local lookup map: a `ConcurrentHashMap<String, String>` acting as an application-level pool. You look up the deserialized value; if it is already in the map, you use the map's copy and discard the new one. This avoids touching the JVM's global StringTable and gives you the option to cap the map size or monitor it.
>
> In both cases, the key insight is that intern — whether via the JVM pool or a manual map — trades a small lookup cost for a large reduction in object allocation, which is a good trade when the value space is bounded."

*Walk through both approaches — JVM intern and manual map — to show you know the tradeoff between convenience and control.*

**Gotcha follow-up they'll ask:** *"What JVM flag controls the String Pool size?"*

> `-XX:StringTableSize` sets the number of hash buckets in the StringTable. The default in Java 11 and later is 1,000,003 buckets (a prime number to reduce hash collisions). For applications that intern large numbers of strings, increasing this value reduces the average chain length per bucket and keeps lookup O(1) in practice.

---

> **Common Mistake — Saying the pool is still in PermGen:** PermGen was removed in Java 8. The pool has been on the main heap since Java 7. Saying PermGen in an interview signals outdated knowledge.

> **Common Mistake — Saying `==` on string literals is unreliable:** For string literals, `==` is actually guaranteed by the Java Language Specification to return true when the content is the same — because they all resolve to the same pool entry. It is unreliable only for runtime-constructed strings.

> **Common Mistake — Not knowing that `final` variables participate in compile-time folding:** `final String prefix = "hel"; String s = prefix + "lo"` produces a pool entry for "hello". If prefix were not final, the concatenation would produce a heap object. This is a frequent interview trap.

**Quick Revision (one line):** The String Pool is a JVM hash table on the main heap (since Java 7) that hands out one canonical object per unique literal; `intern()` adds runtime strings to the pool; compile-time constant folding makes `final`-string concatenations hit the pool automatically.

---

## Topic 3: String Comparison

**Difficulty:** Easy | **Frequency:** High | **Companies:** All

---

### The Idea

Imagine two pieces of paper each saying "hello". Are they the same piece of paper? No. Do they say the same thing? Yes. That is the distinction between `==` and `.equals()` in Java. `==` asks "are you literally the same object in memory?" `.equals()` asks "do you contain the same characters?"

This exists because Java is an object-oriented language where variables hold references — memory addresses — not values directly. Two separate objects can hold identical content but live at different addresses. Any language feature that needs to say "same content" must have an explicit content-comparison method.

The "why it trips everyone up" insight: string literals from the pool happen to share the same address, so `==` accidentally works for them. This trains new developers to use `==`, and then their code silently breaks the moment a string arrives from a network request, a database, or a `new String(...)` call — all of which produce heap objects outside the pool.

### How It Works

**Three comparison tools:**

```
==                    → compares two memory addresses (reference equality)
.equals(other)        → compares character content (content equality)
.compareTo(other)     → compares content lexicographically, returns int
```

**How `.equals()` works internally (O(n) in the worst case):**

```
step 1: check if this == other (fast path — same object → return true)
step 2: check lengths — if different → return false immediately
step 3: compare byte arrays element by element
```

**How `.compareTo()` works:**

```
compare byte arrays element by element
at the first differing position, return (this_char - other_char)
if all characters match up to the shorter length, return (this.length - other.length)
0 means equal, negative means this < other, positive means this > other
```

**Null safety:**

```
a.equals(null)          // returns false — safe
null.equals(a)          // NullPointerException — never do this
Objects.equals(a, b)    // null-safe: true if both null, false if one null, else a.equals(b)
```

**Rule of thumb for production code:**
- Use `Objects.equals(a, b)` whenever either variable might be null.
- Use `a.equals(b)` when you know `a` is not null (e.g., a string literal on the left: `"expected".equals(userInput)`).
- Never use `==` for content comparison in business logic.

```java
import java.util.Objects;

public class StringComparisonDemo {
    public static void main(String[] args) {
        String a = "admin";
        String b = "admin";
        String c = new String("admin");  // heap object, not from pool
        String d = null;

        System.out.println(a == b);               // true  — same pool entry (coincidence)
        System.out.println(a == c);               // false — c is a separate heap object
        System.out.println(a.equals(c));          // true  — same content

        // Safe null patterns
        System.out.println(Objects.equals(a, d)); // false — null-safe
        System.out.println("admin".equals(d));    // false — literal on left, no NPE

        // Lexicographic order
        System.out.println("apple".compareTo("banana")); // negative
        System.out.println("banana".compareTo("apple")); // positive
        System.out.println("apple".compareTo("apple"));  // 0

        // Case-insensitive
        System.out.println("ADMIN".equalsIgnoreCase(a)); // true
    }
}
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q7 — Concept Check

**"What is the difference between `==` and `.equals()` for Strings?"**

**One-line answer:** `==` compares memory addresses; `.equals()` compares character content.

> **Full answer to give in an interview:**
> "In Java, variables hold references — memory addresses — not object contents directly. The `==` operator compares those addresses: it returns true only if both variables point to the exact same object in memory. The `.equals()` method on String is overridden to compare content: it checks that both strings have the same length and the same characters in the same order.
>
> For string literals, `==` often accidentally returns true because literals are stored in the String Pool — a JVM cache of unique string objects. If both variables hold the literal 'admin', they both point to the same pool entry, so their addresses are the same. But this is coincidental. The moment a string comes from outside the pool — from a network request body, from a database result set, from a `new String(...)` call, or from any runtime concatenation — it lives on the heap at a different address. At that point `==` returns false even though the content is identical.
>
> So the rule is: always use `.equals()` for content comparison in business logic. For null-safe comparisons, use `Objects.equals(a, b)` from java.util.Objects — it handles the case where either argument is null without throwing a NullPointerException."

*The key signal interviewers are looking for is that you understand why `==` sometimes works — and why that is dangerous.*

**Gotcha follow-up they'll ask:** *"Is `'hello' == 'hel' + 'lo'` true or false?"*

> True. The right-hand side is `"hel" + "lo"` — both operands are string literals, so the Java compiler folds the entire expression to the single literal `"hello"` at compile time before the program runs. Both sides resolve to the same String Pool entry, so `==` returns true. But if either operand were a non-final variable — `String part = "hel"; part + "lo"` — the concatenation would happen at runtime and produce a new heap object, making `==` return false.

---

#### Q8 — Tradeoff Question

**"When would you use `compareTo` instead of `equals`, and what does its return value mean?"**

**One-line answer:** Use `compareTo` when you need ordering — sorting, binary search, TreeMap keys — not just equality; it returns negative if this string comes first, zero if equal, positive if it comes second.

> **Full answer to give in an interview:**
> "The `equals` method only tells you yes or no — same content or different. `compareTo` gives you direction: it tells you which string would come first in a sorted order. The return value is an integer: negative means this string is lexicographically less than the argument, zero means they are equal, and positive means this string is greater.
>
> Lexicographic order is essentially dictionary order: compare the strings character by character from left to right. At the first position where they differ, subtract the character values. So `'b'.compareTo('a')` returns 1 because the ASCII value of 'b' is 98 and 'a' is 97 — the difference is 1. `'apple'.compareTo('banana')` returns a negative number because 'a' comes before 'b'.
>
> You use `compareTo` whenever ordering matters. Java's `TreeMap` and `TreeSet` use it to maintain keys in sorted order. `Collections.sort` on a list of strings calls `compareTo` under the hood. If you want case-insensitive ordering, use `compareToIgnoreCase`.
>
> One practical note: `compareTo` throws a NullPointerException if the argument is null. There is no null-safe version built in, so if you are writing a Comparator that might encounter nulls, handle the null check explicitly before delegating to `compareTo`."

*Mentioning TreeMap and Collections.sort shows you know where ordering is used in practice.*

**Gotcha follow-up they'll ask:** *"What does `'b'.compareTo('a')` return exactly?"*

> 1. The method compares the character values at the first differing position. 'b' has ASCII value 98 and 'a' has ASCII value 97. The difference is 98 minus 97 equals 1. A positive result means the first string ('b') is greater — it comes later in sorted order.

---

#### Q9 — Design Scenario

**"You are writing a user authentication service. A username is read from an HTTP request and compared to a value from a database. What comparison method do you use, and why?"**

**One-line answer:** Use `Objects.equals(requestUsername, dbUsername)` for null safety, or `"expectedValue".equals(requestUsername)` if the expected value is a known constant.

> **Full answer to give in an interview:**
> "I would use `Objects.equals(requestUsername, dbUsername)` — the null-safe utility from java.util.Objects. Here is why each alternative is wrong.
>
> Using `==` is wrong because both strings come from outside the String Pool. The request username was built by parsing an HTTP body — that is a runtime-constructed String on the heap. The database username was returned by JDBC — also a heap object. Even if both contain exactly 'admin', they are two different objects at two different memory addresses. `==` would return false and every login would fail.
>
> Using `requestUsername.equals(dbUsername)` is fragile because `requestUsername` could be null if the request body was malformed or the field was missing. Calling a method on null throws a NullPointerException, which would crash the request handler or get swallowed by a generic error handler — either way, a hard-to-debug failure.
>
> Using `Objects.equals(requestUsername, dbUsername)` is safe: if both are null it returns true, if exactly one is null it returns false, otherwise it calls `requestUsername.equals(dbUsername)`. No NullPointerException in any case.
>
> If one side is a known constant — like checking for a specific role — I would write `'ADMIN'.equals(userRole)`. Putting the known non-null value on the left eliminates the NPE risk without needing Objects.equals."

*Always mention the NPE risk — it is what separates someone who has written real production code from someone who has only read the API docs.*

**Gotcha follow-up they'll ask:** *"How is String.equals() implemented — is it O(1)?"*

> No, it is O(n) in the worst case, where n is the string length. The implementation has an O(1) fast path — it first checks whether the two references are the same object and returns true immediately if so. Then it checks lengths and returns false immediately if they differ — that is also O(1). But if lengths match, it must compare the backing byte arrays character by character until it finds a difference or reaches the end. For two long identical strings, every character is compared, making it O(n).

---

> **Common Mistake — Using `==` in business logic:** It works for literals by coincidence and fails silently for runtime strings. This is one of the most common real production bugs in Java codebases written by developers who learned on toy examples.

> **Common Mistake — Calling equals on the potentially-null variable:** `userInput.equals("expected")` throws NullPointerException if userInput is null. Always put the known non-null value on the left, or use Objects.equals.

> **Common Mistake — Assuming `compareTo` is case-insensitive:** By default it is case-sensitive — uppercase letters have lower ASCII values than lowercase, so 'Z' sorts before 'a'. Use `compareToIgnoreCase` when case should not affect ordering.

**Quick Revision (one line):** Always use `.equals()` for content comparison — `==` only works for pool literals by coincidence; use `Objects.equals()` when null is possible, and `compareTo()` when you need ordering.

---

## Topic 4: StringBuilder vs StringBuffer

**Difficulty:** Easy | **Frequency:** High | **Companies:** All

---

### The Idea

Imagine building a sentence word by word on a whiteboard. If you used a String for each step, you would have to erase the entire board and rewrite the full sentence every time you added a word — that is what happens when you concatenate immutable Strings in a loop. StringBuilder is the whiteboard itself: it lets you append characters to the right end without rewriting what is already there.

This exists because String immutability, while valuable for safety, makes repeated concatenation expensive. The JVM needs a mutable character buffer — a place to accumulate text efficiently — that is separate from the immutable String type. StringBuilder is that buffer.

The "why two classes exist" story: Java 1.0 shipped StringBuffer, which was thread-safe by default because every method was synchronized. By Java 1.5, the team realized that almost all string building happens on a single thread, so the synchronization overhead was pure waste. StringBuilder was added as the unsynchronized, faster alternative. StringBuffer became a legacy class kept for backward compatibility.

### How It Works

**Why String concatenation in a loop is O(n²):**

```
result = ""
for each item in list:
    result = result + item
    // This creates: new StringBuilder(result), appends item, calls toString()
    // Every iteration: copies ALL characters collected so far into a new object
```

With 1000 items of length 1: iteration 1 copies 0 chars, iteration 2 copies 1, ..., iteration 1000 copies 999. Total: 0+1+2+...+999 = ~500,000 copy operations. That is O(n²).

**How StringBuilder fixes it:**

```
sb = new StringBuilder()    // internal capacity: 16 characters
for each item in list:
    sb.append(item)          // writes to existing array — O(1) amortized
                             // array doubles when full: 16 → 34 → 70 → ...
result = sb.toString()       // ONE copy at the end
```

Append is amortized O(1) because the backing array only needs to be copied when it runs out of capacity, and each copy doubles the size, so the total number of copy operations across all appends is bounded by O(n).

**Capacity growth formula:** when current capacity `c` is exceeded, new capacity = `(c * 2) + 2`. Starting from 16: 16 → 34 → 70 → 142 → ...

**StringBuilder vs StringBuffer — the only real difference:**

| | StringBuilder | StringBuffer |
|---|---|---|
| Introduced | Java 1.5 | Java 1.0 |
| Synchronized | No | Yes (every method) |
| Thread safety | No | Yes |
| Performance | Fast | Slower (lock overhead) |
| Use case | Single-thread string building | Legacy — avoid in new code |

**Java 9+ change — expression concatenation no longer uses StringBuilder:**

For a single-statement expression like `"prefix" + value + "suffix"`, Java 9 switched from emitting `new StringBuilder(...).append(...).toString()` bytecode to using `invokedynamic` with `StringConcatFactory`. The JIT can then optimize the whole expression into a single pre-sized allocation. This makes simple expressions faster. It does NOT fix loops — each loop iteration still performs a separate allocation.

```java
public class StringBuilderDemo {

    // BAD: O(n²) — new String object on every iteration
    public static String buildBad(java.util.List<String> parts) {
        String result = "";
        for (String part : parts) {
            result = result + part + " AND ";
        }
        return result;
    }

    // GOOD: O(n) — one StringBuilder, one toString() at the end
    public static String buildGood(java.util.List<String> parts) {
        StringBuilder sb = new StringBuilder("SELECT * FROM orders WHERE ");
        for (int i = 0; i < parts.size(); i++) {
            sb.append(parts.get(i));
            if (i < parts.size() - 1) sb.append(" AND ");
        }
        return sb.toString();
    }

    public static void main(String[] args) {
        java.util.List<String> conditions =
            java.util.List.of("status='PENDING'", "amount>1000", "region='APAC'");
        System.out.println(buildGood(conditions));

        // Capacity growth demo
        StringBuilder sb = new StringBuilder(); // capacity = 16
        for (int i = 0; i < 50; i++) sb.append('x'); // grows: 16→34→70
        System.out.println(sb.length()); // 50

        // StringBuffer — synchronized, legacy
        StringBuffer buf = new StringBuffer();
        buf.append("thread-safe but slow");
        System.out.println(buf.toString());
    }
}
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q10 — Concept Check

**"What is the difference between StringBuilder and StringBuffer?"**

**One-line answer:** Both are mutable string buffers, but StringBuffer synchronizes every method for thread safety; StringBuilder does not and is therefore faster.

> **Full answer to give in an interview:**
> "Both StringBuilder and StringBuffer provide a mutable character buffer — they let you append, insert, and delete characters without creating a new object each time, unlike String which is immutable. The only meaningful difference is synchronization.
>
> StringBuffer was introduced in Java 1.0. Every one of its methods — append, insert, delete, reverse — is marked synchronized. This means only one thread at a time can execute any of those methods on a given StringBuffer instance. That makes it thread-safe, but acquiring and releasing a lock on every single operation adds overhead even when there is no contention.
>
> StringBuilder was introduced in Java 1.5 as an unsynchronized alternative. It has exactly the same API as StringBuffer but none of the synchronization overhead. Because string building almost always happens on a single thread — you build a string, convert it to an immutable String with toString(), and pass it elsewhere — the synchronization in StringBuffer is pure waste in the vast majority of cases.
>
> In practice: always use StringBuilder. StringBuffer has no place in modern new code. If you actually need to build a string across multiple threads simultaneously — which is rare and usually a design smell — you would synchronize externally, not rely on StringBuffer's per-method locks."

*Saying "StringBuffer has no place in modern new code" is a confident signal that you understand the history.*

**Gotcha follow-up they'll ask:** *"Why doesn't the compiler always optimize String concatenation to StringBuilder?"*

> The compiler does optimize single-statement concatenation — in Java 9 and later it uses invokedynamic with StringConcatFactory, which is even better than StringBuilder. But the key word is "single-statement." Inside a loop, the concatenation expression is evaluated repeatedly. Each evaluation is a separate statement from the compiler's perspective. The compiler creates a new StringBuilder — or calls StringConcatFactory — on every iteration. It does not hoist the builder out of the loop. The result is one new object per iteration, giving O(n²) allocation for n iterations. Only you, the programmer, can write the loop with a single StringBuilder declared outside the loop body.

---

#### Q11 — Tradeoff Question

**"When is it acceptable to use string concatenation with `+` instead of StringBuilder?"**

**One-line answer:** For a fixed number of concatenations outside a loop, `+` is fine and often cleaner — the compiler handles it optimally; only use StringBuilder explicitly when concatenating inside a loop or building a string incrementally across method calls.

> **Full answer to give in an interview:**
> "The rule of thumb is: if all the pieces you are joining are known at one point in the code and you write them as a single expression, use `+`. The compiler or runtime will handle it optimally. For example, `String message = 'User ' + username + ' logged in at ' + timestamp` is a single expression — Java 9 and later compiles this to a single pre-sized allocation via invokedynamic. It is readable and fast. There is no reason to write `new StringBuilder('User ').append(username).append(' logged in at ').append(timestamp).toString()` — that is just noise.
>
> Use StringBuilder explicitly when: you are concatenating inside a loop, because the compiler will not hoist the buffer out of the loop and you will get O(n squared) allocations; or when you are building a string incrementally across multiple method calls or decision branches, where the pieces are not all available in a single expression.
>
> There is also String.join and StringJoiner for the common pattern of joining a list of values with a delimiter — those are even cleaner than manual StringBuilder loops for that specific case."

*Mentioning String.join as an alternative shows you know the full API.*

**Gotcha follow-up they'll ask:** *"What is the default initial capacity of StringBuilder and how does it grow?"*

> The default initial capacity is 16 characters. When an append operation would exceed the current capacity, a new backing array is allocated with capacity `(current * 2) + 2` — so 16 grows to 34, then 70, then 142, and so on. The old array is copied into the new one and discarded. You can avoid growth entirely by pre-sizing: `new StringBuilder(expectedLength)` tells the constructor to start with a larger capacity, eliminating all intermediate copies.

---

#### Q12 — Design Scenario

**"You are building a DAO that dynamically constructs a SQL WHERE clause based on a variable number of filter criteria. How do you build the query string efficiently?"**

**One-line answer:** Use a single StringBuilder declared before the loop, append each condition inside the loop, and call toString() once at the end.

> **Full answer to give in an interview:**
> "The pattern I would use is: declare one StringBuilder before the loop, append the fixed prefix — 'SELECT * FROM orders WHERE ' — and then iterate over the filter criteria. Inside the loop, append each condition and, if it is not the last one, append ' AND '. After the loop, call toString() to produce the final immutable String.
>
> The reason this matters is allocation efficiency. If I used String concatenation with + inside the loop — `query = query + condition + ' AND '` — each iteration would create a new StringBuilder internally, append the two pieces, call toString() to produce a new String, and then throw both the StringBuilder and the previous String away as garbage. With 100 conditions, that is 200 unnecessary short-lived objects per query execution. At high throughput, those objects create GC pressure.
>
> With a single StringBuilder, the backing array grows at most O(log n) times due to the doubling strategy, and only one final String object is created by the toString() call. That is O(n) work total instead of O(n squared).
>
> For the specific case of joining a list of strings with a delimiter — which is exactly what a WHERE clause with AND is — there is also `String.join(' AND ', conditions)` which is even cleaner and delegates to StringJoiner internally. I would use String.join for simple cases and StringBuilder when I need more control over the format of individual pieces."

*Offering both the StringBuilder approach and String.join shows good API knowledge.*

**Gotcha follow-up they'll ask:** *"Can you make StringBuilder thread-safe without using StringBuffer?"*

> Yes, two ways. First, wrap the StringBuilder in a synchronized block: `synchronized(lock) { sb.append(piece); }`. This is explicit and gives you control over the granularity — you can batch multiple appends under one lock. Second, use a ThreadLocal<StringBuilder>: each thread gets its own StringBuilder instance, so there is no sharing and no synchronization needed at all. This is the pattern used internally by some logging frameworks for high-throughput log message formatting.

---

> **Common Mistake — Thinking the compiler always optimizes concatenation:** It optimizes single-statement expressions. Inside loops it creates a new builder per iteration. Saying "the compiler handles it" without this qualification is incorrect and will be challenged.

> **Common Mistake — Recommending StringBuffer in new code:** Unless you have a specific concurrent requirement that you cannot handle with external synchronization, StringBuffer is the wrong answer. Interviewers expect you to know it is legacy.

> **Common Mistake — Forgetting to call toString():** StringBuilder is not a String. Passing a StringBuilder to a method that expects a String — logging, returning from a method — without calling toString() is a type error or produces the default object representation.

**Quick Revision (one line):** Use StringBuilder for all mutable string building — it is O(n) with amortized O(1) appends; StringBuffer is the synchronized legacy version that has no place in new single-threaded code.

---

## Topic 5: Key String Methods

**Difficulty:** Easy | **Frequency:** Medium | **Companies:** All

---

### The Idea

Imagine a Swiss Army knife where each blade is a different string operation — slicing out a portion, splitting on a separator, searching for a character, cleaning up whitespace. Java's String class is that knife. The methods have been accumulating since Java 1.0, and newer versions (Java 8, 9, 11) added cleaner alternatives to some of the older, trickier ones.

This exists because string manipulation is one of the most common programming tasks. Parsing a URL, validating an email, cleaning user input, building a log message — all of these reduce to a handful of string operations. Java builds them into the String class so every application does not have to reimplement them.

The "why it trips people up" insight: several of these methods have non-obvious behavior that the JVM team locked in for backward compatibility. The two biggest traps are `split()` taking a regular expression (not a plain string), and `substring()` having had a memory leak in older JVMs that was fixed in Java 7 update 6.

### How It Works

**`substring(beginIndex, endIndex)` — the memory leak story:**

Before Java 7 update 6, String stored a `char[]` plus an offset and count. Substring returned a new String that shared the original array — a 1-character substring of a 100MB string kept 100MB alive in memory. Java 7u6 changed substring to copy only the relevant characters into a new array. No more leak. Substring is now O(n) where n is the length of the result.

**`split(regex)` — the regex trap:**

```
"192.168.1.1".split(".")    // WRONG: "." is regex for "any character" — returns empty array
"192.168.1.1".split("\\.")  // CORRECT: "\\." is the escaped literal dot
```

`split()` takes a regular expression. Any regex metacharacter — `.`, `|`, `(`, `[`, `{`, `^`, `$`, `*`, `+`, `?` — must be escaped with `\\` if you mean the literal character. Use `Pattern.quote(delimiter)` for safe escaping of arbitrary input.

**Trailing empty strings and the limit parameter:**

```
"a,b,,c,".split(",")       // ["a", "b", "", "c"]  — trailing empty strings dropped
"a,b,,c,".split(",", -1)   // ["a", "b", "", "c", ""]  — all tokens kept
```

**`replace()` vs `replaceAll()`:**

```
replace(CharSequence, CharSequence)   // literal replacement — fast, safe
replaceAll(String regex, String)       // regex replacement — slower, dangerous with user input
```

Always prefer `replace()` for literal substitutions. `replaceAll()` with user-provided input is a regex injection risk.

**`strip()` vs `trim()` (Java 11 distinction):**

```
trim()    — removes characters with code point <= U+0020 (ASCII space and control chars)
strip()   — uses Character.isWhitespace() — Unicode-aware, handles non-breaking spaces, etc.
```

Prefer `strip()` for any user-supplied text. `trim()` misses certain Unicode whitespace characters.

**Quick reference table for the methods that appear in interviews:**

| Method | Purpose | Gotcha |
|---|---|---|
| `substring(b, e)` | Extract chars [b, e) | O(n) — copies since Java 7u6 |
| `split(regex)` | Split on regex | `.` matches any char — use `\\.` for literal dot |
| `charAt(i)` | Get char at index i | O(1); throws if index out of range |
| `indexOf(s)` | First position of s, -1 if absent | Returns -1, does not throw |
| `replace(t, r)` | Literal replacement | Use this over replaceAll for literals |
| `replaceAll(regex, r)` | Regex replacement | Escape metacharacters or use replace() |
| `String.format(fmt, ...)` | Formatted string | Allocates Formatter — not for hot paths |
| `String.join(delim, ...)` | Join with delimiter | Cleaner than StringBuilder for list joins |
| `strip()` | Remove Unicode whitespace | Java 11; prefer over `trim()` |
| `isBlank()` | True if only whitespace | Java 11; equivalent to strip().isEmpty() |
| `repeat(n)` | Repeat string n times | Java 11 |
| `lines()` | Stream of lines | Java 11; handles \n, \r, \r\n |

```java
import java.util.Arrays;
import java.util.List;

public class StringMethodsDemo {
    public static void main(String[] args) {
        // substring — copies since Java 7u6
        String url = "https://api.example.com/v1/orders";
        String path = url.substring(url.indexOf("/v1")); // "/v1/orders"
        System.out.println(path);

        // split — THE most common interview trap
        String ip = "192.168.1.1";
        String[] correct = ip.split("\\.");          // [192, 168, 1, 1]
        String[] wrong   = ip.split(".");            // [] — empty array
        System.out.println(Arrays.toString(correct));
        System.out.println(wrong.length);            // 0

        // split with limit — preserve trailing empty strings
        System.out.println(Arrays.toString("a,b,,c,".split(",", -1))); // [a, b, , c, ]

        // replace (literal) vs replaceAll (regex)
        String masked = "4111-1111-1111-1111".replace("-", "");
        System.out.println(masked); // 4111111111111111

        // join — cleaner than StringBuilder for delimiter-separated lists
        List<String> roles = List.of("READ", "WRITE", "EXECUTE");
        System.out.println(String.join(", ", roles)); // READ, WRITE, EXECUTE

        // Java 11 additions
        String raw = "  \t Hello \n  ";
        System.out.println(raw.strip());          // "Hello"
        System.out.println("   ".isBlank());      // true
        System.out.println("ab".repeat(3));       // ababab

        // lines() — process multiline input
        "header\nAlice,30\nBob,25".lines()
            .skip(1)
            .forEach(System.out::println);
    }
}
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q13 — Concept Check

**"What did the `substring()` memory leak look like, and is it still a problem?"**

**One-line answer:** Before Java 7 update 6, substring shared the original string's backing array, so a tiny substring kept a huge string in memory; the fix was to copy — it is not a problem in any supported JVM.

> **Full answer to give in an interview:**
> "Before Java 7 update 6, String stored not just a byte array but also an offset and a count. Substring did not copy characters — it created a new String object that pointed to the same underlying array, with different offset and count values to describe the slice. This was an optimization to make substring O(1) in time: no copying needed.
>
> The problem was memory. If I had a 100-megabyte string — say, a large XML document loaded into memory — and I called substring to extract a 10-character document ID, the resulting 10-character string object silently held a reference to the same 100MB array. Even if I discarded the original large string, the array could not be garbage collected because the tiny substring still referenced it. This is a classic space leak: objects staying alive far longer than the programmer expected.
>
> Java 7 update 6 changed substring to always copy the relevant portion into a fresh array. Substring became O(n) in time — proportional to the length of the result — but O(n) in space where n is just the result length, not the source. The space leak was eliminated.
>
> Today, no supported JVM has this problem. The version you would encounter in any production system is Java 11 at minimum, and usually Java 17 or 21. But the question appears in interviews because it tests whether you understand how the backing array sharing worked."

*Knowing the history signals real depth — this was a well-known Java pitfall for years.*

**Gotcha follow-up they'll ask:** *"Is `substring()` O(1) or O(n)?"*

> Since Java 7u6 it is O(n), where n is the length of the resulting substring. It must copy n characters from the source array into a new array. Before 7u6 it was O(1) in time because no copy was made — but at the cost of the memory leak. The current behavior trades time for correct memory semantics, which is the right trade.

---

#### Q14 — Tradeoff Question

**"What is the difference between `replace()` and `replaceAll()`, and when would you prefer each?"**

**One-line answer:** `replace()` does literal character-for-character substitution; `replaceAll()` treats the first argument as a regular expression — use `replace()` for literals, `replaceAll()` only when you actually need regex pattern matching.

> **Full answer to give in an interview:**
> "Both methods return a new String with occurrences of one substring replaced by another. The difference is how the first argument is interpreted.
>
> `replace(CharSequence target, CharSequence replacement)` treats the target as a literal sequence of characters. No special metacharacter interpretation. If I call `replace('.', ',')` on an IP address, I get commas where the dots were, exactly as expected.
>
> `replaceAll(String regex, String replacement)` treats the first argument as a regular expression — a pattern language where characters like `.`, `*`, `(`, `)`, `[`, `^`, `$` have special meaning. `replaceAll('.', ',')` replaces every character — because `.` in regex means 'any character'. To replace a literal dot, I would need `replaceAll('\\.', ',')`.
>
> My preference: always use `replace()` for literal substitutions. It is safer — no accidental regex interpretation — and slightly faster because no regex compilation happens. Use `replaceAll()` only when you genuinely need pattern matching, and be careful about user-controlled input: if the first argument to replaceAll comes from user input, an attacker could craft a pathologically slow regex — this is called ReDoS, regular expression denial of service. In that case, sanitize the input or use `replace()` with Pattern.quote."

*Mentioning ReDoS shows security awareness — a strong signal for senior-level interviews.*

**Gotcha follow-up they'll ask:** *"What does `split('a', -1)` do differently from `split('a')`?"*

> The second argument is the limit parameter. With no limit or limit zero, `split` discards trailing empty strings from the result. So `"a,b,,c,".split(",")` returns four elements — the trailing empty string after the last comma is dropped. With limit -1, all trailing empty strings are preserved. `"a,b,,c,".split(",", -1)` returns five elements, the last being an empty string. This matters in data parsing: if your CSV format represents a missing final field as a trailing comma, you need -1 to detect it.

---

#### Q15 — Concept Check

**"What is the difference between `strip()` and `trim()`, and which should you prefer?"**

**One-line answer:** `trim()` removes only ASCII whitespace (code points ≤ U+0020); `strip()` uses the Unicode definition of whitespace and handles characters like non-breaking spaces — prefer `strip()` for user input.

> **Full answer to give in an interview:**
> "Both methods remove leading and trailing whitespace from a string and return a new trimmed string. The difference is what they consider whitespace.
>
> `trim()` was introduced in Java 1.0. It removes any character whose Unicode code point is less than or equal to U+0020 — that is, the ASCII space character and all ASCII control characters below it, like tab and newline. It does not know about Unicode whitespace characters that were defined later in the Unicode standard.
>
> `strip()` was introduced in Java 11 and uses `Character.isWhitespace()`, which follows the Unicode definition. It handles characters like U+00A0, the non-breaking space that appears in text copied from web pages or PDFs, and other Unicode space separators.
>
> In practice, if your application processes user input from a web form, a mobile app, or text copied from a document, prefer strip(). Text pasted from browsers often contains non-breaking spaces that look like normal spaces visually but are not caught by trim(). Using trim() would leave invisible characters at the edges of the string, causing equality checks to fail in ways that are extremely hard to debug.
>
> Java 11 also added `stripLeading()` and `stripTrailing()` for removing whitespace from only one end, and `isBlank()` which returns true if the string is empty or contains only whitespace characters — equivalent to `strip().isEmpty()` but without creating the intermediate stripped string."

*The non-breaking space from copy-pasted web content is a real-world bug that trips up many production systems.*

**Gotcha follow-up they'll ask:** *"Is `String.format()` thread-safe, and is it appropriate for high-throughput logging?"*

> `String.format()` is thread-safe — it creates a new Formatter object on every invocation, so there is no shared state. But it is not appropriate for high-throughput logging precisely because of those allocations. Each call to format allocates a Formatter, a StringBuilder inside the Formatter, and the result String. For a service logging thousands of lines per second, this is measurable allocation pressure. Production logging frameworks like Logback and Log4j2 use lazy parameter evaluation and pre-sized buffers to avoid these allocations for log levels that are not enabled. In application code, use String.format for readability in non-critical paths and avoid it in hot paths.

---

> **Common Mistake — Using `split('.')` to split on a literal dot:** The dot is a regex metacharacter meaning "any character." The correct way to split on a literal dot is `split("\\.")`. This is one of the most common runtime bugs from Java interview candidates who have not internalized that split takes a regex.

> **Common Mistake — Using `replaceAll()` with unescaped special characters:** Same issue — if the replacement target contains `.`, `(`, `[`, or other regex metacharacters, the behavior is wrong unless they are escaped. Use `replace()` for literals.

> **Common Mistake — Assuming `substring()` is still O(1):** Some candidates have read older material that describes the pre-7u6 behavior. Since 7u6, substring copies — it is O(n). Saying it is O(1) will be corrected.

**Quick Revision (one line):** The two biggest traps in String methods are `split()` taking a regex (escape `.` as `\\.`) and `substring()` being O(n) since Java 7u6; use `strip()` over `trim()` for Unicode safety, and `replace()` over `replaceAll()` for literal substitutions.

---

## Topic 6: String-to-int Conversions

**Difficulty:** Easy/Medium | **Frequency:** High | **Companies:** Amazon, PayPal, Razorpay, Morgan Stanley, HDFC Securities

---

### The Idea

Imagine you receive a text message with the number "42" written in it. You can read those two characters as letters, or you can interpret them as the number forty-two and do math with them. That gap — between a sequence of characters and an actual numeric value — is exactly the problem String-to-int conversion solves.

Java keeps text (String) and numbers (int) as completely separate types. A String lives on the heap as an object; an int is a raw four-byte slot in memory. So when a web request arrives with `?page=3` in the URL, that "3" is text. Before you can add 1 to it, Java has to parse the characters and produce a real integer.

Java gives you two main conversion methods: `Integer.parseInt` and `Integer.valueOf`. They both read the same characters, but they hand back different things — one a bare `int` primitive, the other an `Integer` object. Knowing when to use which, and what can go wrong, is the whole interview topic.

---

### How It Works

**Parsing primitives vs objects:**

```
Integer.parseInt("42")   → int  42          // raw number, no object
Integer.valueOf("42")    → Integer(42)       // heap object, may be cached
```

`parseInt` is the lower-level call — it just does the conversion and returns a primitive. `valueOf` internally calls `parseInt` and then wraps the result. For values between -128 and 127, `valueOf` returns a cached `Integer` object rather than allocating a new one (the Integer cache — covered in Topic 8).

**When each makes sense:**

```
USE parseInt WHEN:
  - storing result in int/long variable
  - doing arithmetic immediately
  - no collections or generics involved

USE valueOf WHEN:
  - storing in Integer, List<Integer>, Optional<Integer>
  - passing to a method that expects an Object
  - working with generics
```

**Radix (base) variants:**

```
Integer.parseInt("FF", 16)    → 255   (hexadecimal)
Integer.parseInt("1010", 2)   → 10    (binary)
Integer.toBinaryString(42)    → "101010"
Integer.toHexString(255)      → "ff"
```

**int back to String:**

```
String.valueOf(42)      → "42"   // recommended
Integer.toString(42)    → "42"   // equivalent
"" + 42                 → "42"   // works but avoid in loops — creates StringBuilder
```

**The single most interview-critical gotcha — leading/trailing whitespace:**

```java
// This throws NumberFormatException — parseInt does NOT strip whitespace
int page = Integer.parseInt("  42  "); // THROWS

// Fix: strip first
int page = Integer.parseInt("  42  ".strip()); // OK → 42
```

**What throws `NumberFormatException`:**
- null input (`parseInt(null)` throws NFE, not NPE)
- empty or blank string
- non-digit characters (`"abc"`, `"12px"`)
- value outside `Integer.MIN_VALUE` to `Integer.MAX_VALUE`

**Tradeoff table:**

| Method | Returns | Caches -128–127 | Radix support | Notes |
|---|---|---|---|---|
| `parseInt(s)` | `int` | N/A | `parseInt(s, radix)` | Fastest, no allocation |
| `valueOf(s)` | `Integer` | Yes | `valueOf(s, radix)` | Slower; use for collections |
| `decode(s)` | `Integer` | Yes | Auto-detects `0x`, `#`, `0` prefix | Convenient for hex/octal |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"What is the difference between `Integer.parseInt` and `Integer.valueOf` when given a String?"**

**One-line answer:** `parseInt` returns a primitive `int`; `valueOf` returns an `Integer` object and may return a cached instance for values between -128 and 127.

> **Full answer to give in an interview:**
>
> "Both methods parse the same text — they read digit by digit, handle an optional leading minus sign, and throw `NumberFormatException` if the input is invalid. The difference is what they hand back. `parseInt` returns a bare primitive `int` — no object, no heap allocation. `valueOf` returns an `Integer` object, and for values between -128 and 127 it hands back a pre-allocated cached instance from a static array that the JVM sets up at startup, so you're not creating a new object on every call for those common small values. Outside that range, `valueOf` does allocate a new object. For arithmetic or when storing in an `int` variable, I'd use `parseInt` — it's a direct conversion with no boxing overhead. For collections like `List<Integer>` or when the API needs an object, I'd use `valueOf` since you need the wrapper type anyway."

*Keep your answer at that. If they ask about the cache, you can mention -128 to 127 and say you can go deeper — don't volunteer it unprompted.*

**Gotcha follow-up they'll ask:**

*"Does `Integer.parseInt("  42  ")` work?"*

> No — it throws `NumberFormatException`. `parseInt` does not strip whitespace. You must call `.strip()` or `.trim()` on the string before parsing. This comes up constantly with web request parameters, where users or clients accidentally include spaces. The fix is either `Integer.parseInt(input.strip())` or a utility method that strips and wraps the parse in a try-catch.

---

#### Q2 — Tradeoff Question

**"When would you choose `parseInt` over `valueOf`, and vice versa?"**

**One-line answer:** Use `parseInt` for arithmetic and primitive storage; use `valueOf` when you need an object for collections, generics, or API boundaries.

> **Full answer to give in an interview:**
>
> "The decision comes down to whether you need a primitive or an object. `parseInt` gives you a raw `int` — four bytes on the stack. No allocation, no GC pressure. For a loop counter, a numeric ID you're going to do math on, or a method that returns `int`, this is the right choice. `valueOf` gives you an `Integer` object — it lives on the heap. You need it whenever Java's type system demands an object: `List<Integer>`, `Optional<Integer>`, `Map<String, Integer>`, or any generic method with `T extends Number`. The performance difference matters at scale. In a batch job processing millions of records, parsing each record's amount with `parseInt` avoids millions of unnecessary heap allocations. For a single-record REST endpoint, either works fine. There's also `Integer.decode` — that one auto-detects the base from the prefix: `0x` for hex, `0` for octal, no prefix for decimal. Useful when you're parsing configuration values that can be written in different bases."

*Mention the scale/performance angle — that signals backend experience.*

**Gotcha follow-up they'll ask:**

*"What does `Integer.parseInt(null)` throw?"*

> `NumberFormatException`, not `NullPointerException`. This surprises most people. The JDK's implementation checks for null early and throws NFE with the message "null". So if you're writing a null check before parse, it's not strictly necessary to prevent an NPE — but it's still good practice for clarity and for producing a better error message to the caller.

---

#### Q3 — Design Scenario

**"A REST controller receives a query parameter `page` as a String. How do you safely parse it to an int?"**

**One-line answer:** Null-check, strip whitespace, wrap `parseInt` in a try-catch, and return a sensible default on failure.

> **Full answer to give in an interview:**
>
> "In production, you can't trust query parameters. They may be null (parameter not sent), blank, contain letters, or be a number too large for an int. My first line of defense in a Spring Boot controller is to use `@RequestParam(defaultValue = '0') int page` — Spring calls `parseInt` internally and returns HTTP 400 Bad Request automatically if binding fails. But if I'm parsing manually — say, from a map of headers or a CSV field — I'd write a small utility method: null-check first (return empty Optional), then strip whitespace, then `parseInt` inside a try-catch that catches `NumberFormatException` and returns an empty `Optional<Integer>`. The caller decides what the default should be — I don't bake assumptions into the parser. I'd also validate the range: a page number of -1 or 1,000,000 might parse fine but be semantically wrong, so I'd add a bounds check after parsing."

*Mentioning `@RequestParam` shows real framework knowledge. The utility method pattern shows you've thought about reusability.*

**Gotcha follow-up they'll ask:**

*"What about parsing `'2147483648'` — one more than `Integer.MAX_VALUE`?"*

> It throws `NumberFormatException` — the value is 2,147,483,648 which exceeds `Integer.MAX_VALUE` of 2,147,483,647 by one. If you need to handle values in that range, switch to `Long.parseLong`, which handles up to about 9.2 × 10^18. This comes up in financial systems dealing with large account balances or timestamps in milliseconds.

---

> **Common Mistake — Not handling `NumberFormatException` on user input:** Letting the exception propagate to the caller gives a 500 error instead of a 400, and leaks stack trace details in the response.

> **Common Mistake — Using `"" + number` for int-to-String in loops:** Every concatenation creates a `StringBuilder` object under the hood. At a million iterations this creates a million short-lived objects. Use `String.valueOf(n)` or `Integer.toString(n)` instead.

> **Common Mistake — Assuming `parseInt(null)` throws NPE:** It throws `NumberFormatException`. Write tests for null inputs explicitly.

**Quick Revision (one line):** `parseInt` returns a primitive `int`, `valueOf` returns a cached `Integer` object, both throw `NumberFormatException` for null/blank/invalid/out-of-range input — always strip whitespace and catch the exception on user input.

---

## Topic 7: Autoboxing and Unboxing

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Amazon, Google, JPMorgan, Goldman Sachs, Flipkart

---

### The Idea

Java has two completely separate type systems that live side by side: primitives and objects. Primitives — `int`, `long`, `boolean`, `double` — are raw values stored directly on the stack or inline in arrays. Objects live on the heap, have methods, and can be null. The problem is that Java's collections framework, generics, and many APIs were designed around objects, not primitives. So `List<int>` is a compile error. You need `List<Integer>`.

This gap would force you to manually write `Integer.valueOf(x)` every time you put an int into a list, and `x.intValue()` every time you took it out. That's exactly what autoboxing eliminates: the compiler inserts those conversions for you, invisibly. It's a convenience feature — but "invisible" means you can accidentally pay the cost without noticing.

The cost is real: an `Integer` object on a 64-bit JVM takes 16 bytes (12-byte object header plus 4 bytes of data). A bare `int` takes 4 bytes. Box a million values in a loop and you've just created a million 16-byte heap objects, each of which the garbage collector must eventually process.

---

### How It Works

**What the compiler does behind the scenes:**

```
// What you write:
Integer i = 5;
int j = i;

// What the compiler generates:
Integer i = Integer.valueOf(5);   // autoboxing
int j = i.intValue();             // unboxing
```

**When autoboxing is triggered:**

```
ASSIGNMENT:     Integer x = someInt;
COLLECTION:     list.add(someInt);          // List<Integer> triggers boxing
METHOD CALL:    method(someInt);            // if method expects Integer/Object
ARITHMETIC:     Integer x = 10; x + 5;     // unbox x, add, rebox result
RETURN:         Integer method() { return 5; }  // 5 is autoboxed
```

**The performance trap — boxing inside a hot loop:**

```java
// BAD: 1,000,000 Long object allocations
Long sum = 0L;
for (long i = 0; i < 1_000_000; i++) {
    sum += i;  // unbox sum → add i → rebox result to Long → repeat
}

// GOOD: zero allocations
long sum = 0L;
for (long i = 0; i < 1_000_000; i++) {
    sum += i;
}
```

The bad version creates one million `Long` objects. The good version creates zero. In a real batch job this is the difference between seconds and milliseconds.

**Memory comparison:**

| Type | Size on 64-bit JVM (compressed oops) |
|---|---|
| `int` (primitive) | 4 bytes |
| `Integer` (object) | 16 bytes (12-byte header + 4-byte value) |
| `long` (primitive) | 8 bytes |
| `Long` (object) | 24 bytes |

**Comparison trap — `==` on autoboxed values:**

```java
Integer a = 127;  Integer b = 127;
a == b   // true  — both point to the same cached Integer object

Integer c = 128;  Integer d = 128;
c == d   // false — two different heap objects (outside cache range)
```

The cache range is -128 to 127 (Topic 8). Outside it, `==` compares object references, not values. Always use `.equals()`.

**Unboxing null throws NPE:**

```java
Integer x = null;
int y = x;  // NullPointerException — calls x.intValue() on null
```

Covered in detail in Topic 9.

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"What is autoboxing, and what does the compiler do when it sees `Integer i = 5`?"**

**One-line answer:** Autoboxing is the compiler automatically inserting `Integer.valueOf(5)` — converting a primitive `int` to its wrapper `Integer` object — when the context requires an object.

> **Full answer to give in an interview:**
>
> "Autoboxing is a compile-time transformation. When the compiler sees `Integer i = 5`, it rewrites it as `Integer i = Integer.valueOf(5)`. `Integer.valueOf` first checks a static cache — for values between -128 and 127, it returns a pre-allocated cached instance; outside that range, it allocates a new `Integer` object on the heap. The reverse — unboxing — happens when an `Integer` is used where an `int` is expected: the compiler inserts `.intValue()`. So `int j = someInteger` becomes `int j = someInteger.intValue()`. This happens automatically for assignments, method calls, arithmetic, and collection operations. The convenience is real, but the cost is real too: outside the cache range, every boxing call allocates a heap object. In a loop running a million times, that's a million short-lived objects for the GC to clean up."

*The mention of the cache and GC overhead signals deeper knowledge — interviewers at Amazon and Goldman Sachs specifically probe this.*

**Gotcha follow-up they'll ask:**

*"Does arithmetic on two `Integer` objects cause boxing?"*

> Yes. `Integer z = x + y` — where x and y are `Integer` — first unboxes both to `int`, adds them, then reboxes the result back to `Integer`. That's two unbox calls and one box call for a single addition. If `x` and `y` are both `Integer` variables used in a tight loop, you're paying that cost every iteration. The fix is to declare the loop variable and accumulator as primitives.

---

#### Q2 — Tradeoff Question

**"What are the performance implications of using `List<Long>` to sum 10 million values versus a `long[]` array?"**

**One-line answer:** `List<Long>` boxes every value into a 24-byte heap object causing massive GC pressure; `long[]` stores raw 8-byte values inline with zero boxing overhead.

> **Full answer to give in an interview:**
>
> "A `List<Long>` stores references to `Long` objects on the heap. Each `Long` is 24 bytes — 12-byte object header plus 8 bytes of data. For 10 million values, that's 240 MB of heap just for the wrapper objects, plus the list's internal reference array. Every insertion boxes the primitive `long` via `Long.valueOf()`; every read unboxes it. That's 20 million method calls just to get the values in and out. A `long[]` array is completely different: the values are stored inline, 8 bytes each, 80 MB total, with zero boxing overhead. Iteration reads memory sequentially, which is also cache-friendly at the CPU level. In my experience on batch financial services, switching from `List<Long>` to `long[]` or `LongStream` for aggregation pipelines can reduce run time by an order of magnitude. If you need the flexibility of a resizable collection but care about performance, libraries like Eclipse Collections or Trove provide primitive-typed lists that avoid boxing entirely."

*Mentioning the exact memory math and real-world experience is what separates senior answers from junior ones.*

**Gotcha follow-up they'll ask:**

*"Can you use `int` directly as a generic type parameter, like `List<int>`?"*

> No — Java generics only work with reference types, not primitives. This is a fundamental limitation of how Java generics were implemented via type erasure: at runtime, the JVM erases generic type information and the bytecode works with `Object` references. A primitive `int` cannot be stored as an `Object` reference. So you must use `List<Integer>`. Project Valhalla (a long-running JDK research project) is working on value types and primitive generics, but as of Java 21 they are not yet in production releases.

---

#### Q3 — Design Scenario

**"You have a financial batch service that sums 10 million transaction amounts stored in `List<Long>`. It's running slowly. How would you diagnose and fix the boxing overhead?"**

**One-line answer:** Profile to confirm GC pressure from Long allocations, then replace `List<Long>` with `long[]` or `LongStream` to eliminate boxing entirely.

> **Full answer to give in an interview:**
>
> "First I'd confirm the hypothesis with profiling — JDK Flight Recorder or YourKit can show you the allocation rate by type. If you see millions of `Long` objects being allocated and collected per second, boxing is the culprit. The fix has a few options in increasing order of invasiveness: first, if the data fits in memory as an array, replace `List<Long>` with `long[]` — direct indexed access, zero boxing, best cache locality. Second, if you need stream-style operations, use `LongStream` from the `java.util.stream` package — it operates on primitive `long` values natively and provides `sum()`, `average()`, `reduce()` without boxing. Third, if you need a resizable structure with collection semantics, look at Eclipse Collections' `LongList` or Trove's `TLongArrayList`. For the sum specifically, I'd write `LongStream.of(array).sum()` — the JIT compiles this down to a tight loop over primitive values with no object creation. The key insight is: avoid mixing boxed and unboxed types at the boundary of hot code paths."

*The structured escalation — array, stream, library — shows engineering judgment.*

**Gotcha follow-up they'll ask:**

*"Would switching to `int[]` instead of `Integer[]` affect null handling?"*

> Yes — primitive arrays cannot store null. An `Integer[]` can have null elements; an `int[]` cannot. If your data might contain null to represent "no value," you have a design choice: either use a sentinel value (like `-1` or `Integer.MIN_VALUE`) for "absent," or keep `Integer[]` for correctness and accept the boxing cost, or switch to `OptionalInt` when passing individual values around. For bulk aggregation where you know values are never null, `int[]` is strictly better.

---

> **Common Mistake — Using `Long` instead of `long` as a sum accumulator:** Every `sum += value` iteration creates a new `Long` object. Use primitive `long` for accumulators.

> **Common Mistake — Comparing autoboxed `Integer` values with `==`:** For values outside -128–127 this compares object references and returns false even when the numeric values are equal. Always use `.equals()` or unbox both sides.

> **Common Mistake — Not recognizing arithmetic on `Integer` as a source of boxing:** `Integer z = a + b` with `Integer a, b` silently unboxes both operands and reboxes the result. Declare loop variables as primitives.

**Quick Revision (one line):** Autoboxing is the compiler inserting `valueOf()` to convert primitives to wrapper objects; it costs heap allocation outside the -128–127 cache range, so use primitive types in loops and accumulators, and always use `.equals()` not `==` for wrapper comparison.

---

## Topic 8: Integer Cache -128 to 127

**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Amazon, Google, Uber, Paytm, Goldman Sachs, Meta

---

### The Idea

Think about a vending machine that pre-stocks the most popular snacks so customers don't have to wait for them to be made fresh. Java's Integer cache does something similar: the JVM pre-creates Integer objects for the 256 most commonly used integer values (-128 through 127) at startup, and reuses those same objects every time your code boxes one of those values. There's no point making a new "42" object every time someone writes `Integer x = 42` — the "42" object from the cache works perfectly.

This optimization matters because small integers — loop counters, status codes, IDs under 128 — are the most frequent values in typical programs. By caching them, the JVM avoids millions of tiny heap allocations per second in real applications.

The catch: the cache makes `==` comparison on `Integer` give different results depending on the value. For values inside the cache, two independently assigned `Integer` variables pointing to "127" will be the exact same object in memory, so `==` returns true. For values outside the cache, they'll be different objects, so `==` returns false. This asymmetry is one of the most common Java interview trick questions.

---

### How It Works

**What the JVM pre-allocates at startup:**

```
Static Integer cache array: [-128, -127, ..., 0, 1, ..., 126, 127]
Total: 256 pre-allocated Integer objects, never garbage collected
```

**How `Integer.valueOf` uses it:**

```
if value is in [-128, 127]:
    return cache[value + 128]   // same object every time
else:
    return new Integer(value)   // new heap object every time
```

**The `==` trap — the most-asked Java trick question:**

```java
Integer a = 127;  Integer b = 127;
a == b    // true  — a and b point to cache[255], the same object

Integer c = 128;  Integer d = 128;
c == d    // false — c and d are two different new heap objects
```

The safe rule: **never use `==` to compare `Integer` values. Always use `.equals()` or unbox with `intValue()`.**

**Which wrapper types have caches:**

```
Boolean:    true, false — always cached (only two values exist)
Byte:       all 256 values (-128 to 127) — always cached
Short:      -128 to 127
Integer:    -128 to 127 (upper bound configurable)
Long:       -128 to 127
Character:  0 to 127
Double:     NO CACHE
Float:      NO CACHE
```

Double and Float have no cache because floating-point values are not identifiable by a small fixed set — infinitely many fractional values make pre-allocation impractical.

**The JVM flag to extend the upper bound:**

```
-XX:AutoBoxCacheMax=<n>
```

This increases the Integer cache upper limit beyond 127. Useful in applications that heavily use common IDs or status codes in a known range. The lower bound of -128 is fixed by the Java Language Specification and cannot be changed.

**Why -128 specifically as the lower bound:**

The JLS chose -128 pragmatically — negative numbers like -1 (error code), -128 to -1 are common in array indexing, error returns, and C-style APIs. Starting the cache at -128 captures those common cases.

**`new Integer(n)` is gone:**

Prior to Java 9, you could write `new Integer(100)` to explicitly bypass the cache and create a fresh object. This was deprecated in Java 9 and removed entirely in Java 17. If you write it in Java 17, it's a compile error.

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"What does `Integer.valueOf(127) == Integer.valueOf(127)` return, and why?"**

**One-line answer:** `true` — both calls return the same pre-allocated cached `Integer` object from the JVM's static Integer cache array.

> **Full answer to give in an interview:**
>
> "This returns `true`. `Integer.valueOf` maintains a static array of pre-created `Integer` objects for values between -128 and 127, inclusive. When you call `Integer.valueOf(127)`, it checks: is 127 within the cache range? Yes. So it returns `cache[255]` — a specific slot in that pre-allocated array. Both calls return the exact same object reference. The `==` operator compares object identity — are these two variables pointing at the same object in memory? Yes they are, so `==` returns `true`. Now if you change the value to 128 — one above the cache boundary — `valueOf(128)` falls outside the range and creates a new `Integer` object on the heap each time. Two calls to `valueOf(128)` return two different objects, and `==` returns `false` even though the numeric values are identical. This is why you should always use `.equals()` or compare the unboxed `intValue()` when comparing `Integer` objects — `==` gives you unreliable results that change based on the numeric value."

*This is a verbatim interview question at Amazon, Uber, and Goldman Sachs. Nail the explanation of object identity vs value equality.*

**Gotcha follow-up they'll ask:**

*"Does `Long` have the same caching behavior?"*

> Yes — `Long.valueOf` also caches -128 to 127. So `Long.valueOf(127L) == Long.valueOf(127L)` is `true`, and `Long.valueOf(128L) == Long.valueOf(128L)` is `false`. The same caching rule applies to `Short` and the `char`/`Character` range 0–127. `Double` and `Float` have no cache at all — every `Double.valueOf(1.0)` creates a new object, so `==` always returns `false` for boxed doubles.

---

#### Q2 — Tradeoff Question

**"Should you ever rely on the Integer cache for correctness in production code?"**

**One-line answer:** No — the cache is a performance optimization, not a contract for object identity; code that depends on `==` being `true` for cached Integers is fragile and wrong.

> **Full answer to give in an interview:**
>
> "Never rely on cache identity for correctness. The JLS guarantees that `Integer.valueOf` returns cached instances for -128 to 127, but it says nothing about the semantics of `==`. Your code's logic should never depend on two `Integer` variables being the same object — it should depend on their values being equal, which is what `.equals()` checks. The cache is purely a space and time optimization. There's a real-world failure mode here: I've seen services where `Integer == Integer` worked in all test cases because the test data used small status codes (0 through 10) — all within the cache range — but silently broke in production with larger status codes. The fix was always `.equals()`. The only legitimate use of the cache as a conscious design choice is performance: if you're creating many `Integer` objects for values in a known range, you can rely on `valueOf` reusing cached instances to reduce allocation pressure. But even then you'd use `valueOf` explicitly and never write `==` comparisons."

*The production failure story makes this answer memorable.*

**Gotcha follow-up they'll ask:**

*"Can you change the Integer cache range at runtime?"*

> You can change the upper bound only, and only at JVM startup via the `-XX:AutoBoxCacheMax=<n>` JVM flag or the system property `java.lang.Integer.IntegerCache.high`. The lower bound of -128 is hard-coded in the JLS and cannot be changed. You cannot extend the cache to negative values below -128. Increasing the cache size is occasionally useful in applications that heavily use a known range of IDs — for example, an application where all user roles are coded as integers from 1 to 500 could pre-warm those into cache at startup to reduce allocation in hot paths.

---

#### Q3 — Design Scenario

**"A legacy codebase uses `Integer == Integer` comparisons throughout. Tests pass but a production bug is reported where two orders with the same status code are treated as different. How do you diagnose and fix this?"**

**One-line answer:** The status codes are outside -128–127 so `==` compares object references and returns false even for equal values — replace every `Integer == Integer` with `.equals()`.

> **Full answer to give in an interview:**
>
> "This is a classic Integer cache boundary bug. My first step is to look at the actual status code values in the failing production case. If they're above 127, the bug is immediately clear: `Integer.valueOf(200) == Integer.valueOf(200)` returns `false` because 200 is outside the cache range, and two separate calls allocate two distinct objects. Tests pass because test data used small codes — 0, 1, 2 — all cached, so `==` happened to return `true`. The fix is mechanical: replace every `==` between `Integer` variables with `.equals()`. In a large codebase I'd write a static analysis rule — tools like SpotBugs or SonarQube have this check built in (it's rule `RV_INTEGER_OPERATION_OVERFLOW` or similar). For the long term, I'd argue for using `int` primitives for status codes rather than `Integer` objects — primitives always compare correctly with `==` because there's no object identity to confuse with value equality."

*Naming SpotBugs/SonarQube shows you think about systemic prevention, not just point fixes.*

**Gotcha follow-up they'll ask:**

*"Is `new Integer(100)` equivalent to `Integer.valueOf(100)`?"*

> They were different, and `new Integer(100)` no longer exists. In Java 8 and earlier, `new Integer(100)` always created a fresh heap object — it deliberately bypassed the cache. `Integer.valueOf(100)` returned the cached instance. So `new Integer(100) == Integer.valueOf(100)` returned `false`. In Java 9, `new Integer(n)` was deprecated. In Java 17, the `Integer(int)` constructor was removed and calling it is a compile error. Today, `Integer.valueOf(100)` is the only correct way to get a boxed integer, and it uses the cache for values in range.

---

> **Common Mistake — Applying the cache rule to `Double` and `Float`:** These types have no cache. `Double.valueOf(1.0) == Double.valueOf(1.0)` is always `false`.

> **Common Mistake — Not knowing `new Integer()` was removed in Java 17:** Saying "you can bypass the cache with `new Integer(n)`" in an interview for a Java 17+ role is a red flag.

> **Common Mistake — Thinking the cache covers all negative integers:** The cache starts at -128 specifically. Values like -200, -1000 are not cached and will produce different objects on each `valueOf` call.

**Quick Revision (one line):** `Integer.valueOf` returns cached objects for -128 to 127 making `==` true in that range and false outside it — always use `.equals()` for Integer comparison, and know that `Long`/`Short`/`Byte` have the same cache but `Double`/`Float` do not.

---

## Topic 9: Null Unboxing NullPointerException

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Morgan Stanley, Deutsche Bank, ThoughtWorks

---

### The Idea

When you unbox a wrapper object — convert an `Integer` to an `int`, for example — Java calls the `.intValue()` method on that object. That's just a regular method call. And like any method call, if the object reference is null, calling a method on it throws a `NullPointerException`.

The dangerous part is that unboxing happens invisibly. You write `int x = someInteger` and it looks like a simple assignment. But the compiler has secretly inserted `someInteger.intValue()`. If `someInteger` is null, you get an NPE on what looks like a trivial assignment line — not on the method call that returned null, not on the place where null was introduced.

This is a particularly nasty bug in backend systems because Map lookups return null for absent keys, database queries return null for missing columns, and optional service responses use null to signal "not found." All of these null values, if assigned to a primitive variable, silently cause NPEs at the unboxing site.

---

### How It Works

**The exact mechanism:**

```
Integer x = null;
int y = x;          // compiler rewrites as: int y = x.intValue();
                    // → NullPointerException because x is null
```

**Five scenarios where null unboxing silently hides:**

```
SCENARIO 1 — Map lookup:
    int score = scores.get("alice");  // get() returns null if absent → NPE

SCENARIO 2 — Method return:
    int discount = service.getDiscount(code);  // returns Integer, may be null → NPE

SCENARIO 3 — Conditional expression:
    boolean active = flags.get("featureX");  // Boolean unboxed to boolean → NPE

SCENARIO 4 — Ternary operator:
    int result = condition ? someInteger : 0;
    // if condition is true and someInteger is null → NPE
    // JLS: ternary expression type is int → unboxing applied to Integer branch

SCENARIO 5 — Switch statement:
    switch(nullableInteger) { ... }  // unboxes Integer selector → NPE
```

**Java 17's Helpful NPE Messages (JEP 358):**

Before Java 14, an NPE just said "NullPointerException" with no details. Since Java 14 (finalized in Java 17), the JVM generates messages that identify the exact null source:

```
NullPointerException: Cannot invoke "Integer.intValue()" because
the return value of "java.util.Map.get(Object)" is null
```

This makes null unboxing bugs dramatically faster to find in production logs.

**Fix patterns:**

```
FIX 1 — Null check before unboxing:
    Integer val = map.get(key);
    int score = (val != null) ? val : 0;

FIX 2 — Map.getOrDefault (avoids null entirely):
    int score = scores.getOrDefault("alice", 0);

FIX 3 — OptionalInt for method returns:
    OptionalInt getDiscount(String code) {
        Integer val = repo.find(code);
        return val != null ? OptionalInt.of(val) : OptionalInt.empty();
    }

FIX 4 — Keep the type as Integer (don't unbox):
    Integer score = map.get("alice");  // null is valid, no NPE
    if (score != null) { ... }
```

**The ternary operator subtlety:**

```java
Integer x = null;
int result = true ? x : 0;
// Compiles fine. At runtime: true branch selected → x unboxed → NPE.
// The type of the whole expression is int (numeric promotion),
// so the Integer branch is unboxed when selected.
```

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"Why does `int x = map.get('key')` throw a NullPointerException when the key is absent?"**

**One-line answer:** `Map.get()` returns `null` when the key is absent, and assigning that null `Integer` to an `int` primitive triggers unboxing — `null.intValue()` — which throws NPE.

> **Full answer to give in an interview:**
>
> "When a key is absent, `Map.get('key')` returns `null` — a null `Integer` reference. The left side of the assignment is `int x` — a primitive. The compiler sees a mismatch: you have an `Integer` on the right and an `int` slot on the left. So it inserts an automatic unboxing call, rewriting the statement as `int x = map.get('key').intValue()`. At runtime, `.intValue()` is a method call on the null reference, and any method call on null throws `NullPointerException`. The NPE's stack trace points to this assignment line, which makes it look like the assignment itself failed — but the real cause is the null returned by the map lookup one expression earlier. In Java 17, the helpful NPE message makes this clearer: it says exactly 'Cannot invoke Integer.intValue() because the return value of Map.get(Object) is null'. The fix is to use `map.getOrDefault('key', 0)` which returns 0 instead of null when the key is absent, completely avoiding the unboxing of null."

*The explanation of where the NPE points vs where the bug is makes this a great interview answer.*

**Gotcha follow-up they'll ask:**

*"What about `if (map.get('featureFlag')) { ... }` where the map is `Map<String, Boolean>`?"*

> Same problem, same mechanism. `map.get('featureFlag')` returns null if the key is absent. The `if` condition expects a `boolean` primitive. The compiler inserts `map.get('featureFlag').booleanValue()` — calling `.booleanValue()` on null throws NPE. This is subtle because the `if` statement looks like a boolean expression, not a method call. Fix: use `Boolean.TRUE.equals(map.get('featureFlag'))` — this is null-safe because `Boolean.TRUE.equals(null)` returns `false` without throwing. Or use `map.getOrDefault('featureFlag', false)`.

---

#### Q2 — Tradeoff Question

**"When should you return `Optional<Integer>` vs `OptionalInt` vs a plain `Integer` from a method that might not have a value?"**

**One-line answer:** Use `OptionalInt` for primitive-safe optional returns in performance-sensitive code; use `Optional<Integer>` in generic or stream pipelines; use nullable `Integer` only in tight internal code with documented null contracts.

> **Full answer to give in an interview:**
>
> "`OptionalInt` is the primitive-specialized optional — it wraps an `int` without boxing it into an `Integer` object. Use it when the method is performance-sensitive and callers will frequently call `.getAsInt()`, which returns the raw primitive. `Optional<Integer>` boxes the integer into an `Integer` object inside the optional — it's slightly heavier but integrates cleanly with `Stream<Optional<Integer>>`, `flatMap`, and generic code. Use it in stream pipelines or when consistency with other `Optional<T>` return types matters more than the boxing overhead. A plain nullable `Integer` return is the most permissive but the most dangerous: callers must know to null-check before unboxing, and nothing in the type system enforces that. In a public API, I prefer `OptionalInt` or `Optional<Integer>` over null returns specifically to prevent null unboxing NPEs at call sites. For internal code with a tight documented null contract — say, a private method where the caller always null-checks — a nullable `Integer` is acceptable."

*The explicit three-way comparison with rationale for each is what senior interviewers want to hear.*

**Gotcha follow-up they'll ask:**

*"Can `OptionalInt` itself be null?"*

> No — `OptionalInt` is a value-container object. The contract is that you never return a null `OptionalInt`; you return either `OptionalInt.of(value)` for a present value or `OptionalInt.empty()` for absent. If a method returns a null `OptionalInt`, callers calling `.isPresent()` on it would get an NPE — which defeats the purpose. Spotting this in code review is a sign someone misunderstood Optional's contract.

---

#### Q3 — Design Scenario

**"A pricing service has `Integer getDiscount(String promoCode)` and callers do `int discount = pricingService.getDiscount(code)`. In production, some promo codes cause an NPE. Fix it without changing every call site."**

**One-line answer:** Change the method signature to return `OptionalInt`, update the implementation once, and fix the call sites to use `.orElse(0)`.

> **Full answer to give in an interview:**
>
> "The root cause is clear: `getDiscount` returns null for unknown promo codes, and the caller immediately unboxes that null `Integer` to `int`, throwing NPE. The ideal fix is to change the method return type from `Integer` to `OptionalInt` — this makes the 'might not have a value' contract explicit in the type system and forces callers to handle the absent case. The implementation changes from `return repo.findDiscount(code)` to `Integer val = repo.findDiscount(code); return val != null ? OptionalInt.of(val) : OptionalInt.empty()`. Each call site changes from `int discount = service.getDiscount(code)` to `int discount = service.getDiscount(code).orElse(0)`. If changing the signature is not feasible — say, it's a public API used by many external clients — then at minimum add a null check in the calling code: `Integer d = service.getDiscount(code); int discount = d != null ? d : 0`. The quick band-aid that avoids touching either the service or all call sites is a wrapper utility: `getDiscountOrDefault(code, 0)` that does the null check internally. But I'd argue for the OptionalInt approach because it makes the contract permanent and compiler-enforced."

*The structured 'ideal fix / constrained fix / band-aid' approach demonstrates engineering maturity.*

**Gotcha follow-up they'll ask:**

*"Would adding `@NonNull` annotation to the return type fix the NPE?"*

> No — `@NonNull` and similar annotations (`@NotNull`, JSR-305's `@Nonnull`) are documentation and static analysis hints, not runtime enforcement. They tell tools like IntelliJ or CheckerFramework to warn if you pass a potentially-null value where non-null is expected, but at runtime the JVM ignores them entirely. A `@NonNull Integer` can still be null at runtime if the implementation violates the contract. To fix the NPE you need actual null-prevention logic: either return `OptionalInt`, add a null guard in the implementation, or check at the call site.

---

> **Common Mistake — Returning null from `Integer`-typed methods and expecting callers to guard:** Callers assign to `int` and forget to null-check. Make the contract explicit with `OptionalInt`.

> **Common Mistake — Using `Boolean` as a tri-state (true/false/null) and unboxing in `if`:** A null `Boolean` unboxed to `boolean` throws NPE. Use `Boolean.TRUE.equals(val)` for null-safe boolean checks.

> **Common Mistake — Not recognizing the ternary operator as an unboxing trigger:** `condition ? nullableInteger : 0` — when the integer branch is selected and the value is null, the NPE happens inside what looks like a simple expression.

**Quick Revision (one line):** Null wrapper types throw NPE when unboxed to primitives because the compiler calls `.intValue()` on null — the four danger zones are Map.get(), method returns, ternary expressions, and switch selectors; fix with `.getOrDefault()`, null checks, or `OptionalInt`.

---

## Topic 10: Comparable vs Comparator

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Flipkart, Zalando, ThoughtWorks, Meta

---

### The Idea

Imagine you own a music store and want to sort CDs. "By default, CDs go on the shelf alphabetically by artist name" — that's the natural ordering the CD itself knows about. That's `Comparable`: the object itself knows how to compare itself to another of the same type.

But sometimes a customer wants them sorted by price, another wants them by release year, and a third wants newest releases first. None of those are "the CD's default" — they're external, context-specific orderings applied from outside. That's `Comparator`: a separate object that knows how to order CDs by some criterion, passed in at sort time.

Java's collections — `TreeSet`, `TreeMap`, `Collections.sort`, `List.sort` — need to know how to order objects. If the object implements `Comparable`, you get sorting for free with no extra setup. If you need a different order — or the class doesn't implement `Comparable` — you pass a `Comparator`. Java 8 made Comparator dramatically more expressive with `comparing()`, `thenComparing()`, and `reversed()`.

---

### How It Works

**`Comparable<T>` — defined inside the class:**

```
interface Comparable<T> {
    int compareTo(T other);
    // Return: negative if this < other
    //          0 if this == other
    //          positive if this > other
}
```

A class implementing `Comparable` defines its own natural ordering. `Collections.sort(list)` and `TreeSet` use this without any extra argument.

**`Comparator<T>` — defined outside the class:**

```
@FunctionalInterface
interface Comparator<T> {
    int compare(T o1, T o2);
    // Return: negative if o1 < o2, 0 if equal, positive if o1 > o2
}
```

Passed to `list.sort(comparator)`, `Collections.sort(list, comparator)`, `TreeSet(comparator)`.

**Java 8 Comparator chaining — the key API:**

```
Comparator.comparing(Order::getAmount)          // primary key, natural order
          .thenComparing(Order::getCreatedAt)   // secondary key
          .reversed()                           // reverses the whole chain

// Null-safe:
Comparator.comparing(Order::getDate, Comparator.nullsLast(naturalOrder()))
```

**`reversed()` subtlety:**

`reversed()` wraps the entire comparator built so far. If you call `.reversed().thenComparing(x)`, the secondary sort `x` is in natural order. If you want both reversed: explicitly reverse each comparator.

```
// Both primary and secondary reversed:
Comparator.comparing(Order::getAmount).reversed()
          .thenComparing(Comparator.comparing(Order::getDate).reversed())
```

**The overflow trap — never subtract in `compareTo`:**

```
// WRONG — integer overflow for large values:
return this.amount - other.amount;

// If this.amount = Integer.MIN_VALUE and other.amount = 1:
// Integer.MIN_VALUE - 1 = Integer.MAX_VALUE (overflow!) → wrong order

// CORRECT:
return Integer.compare(this.amount, other.amount);
return Double.compare(this.amount, other.amount);
```

**Consistency with equals — critical for TreeSet/TreeMap:**

```
TreeSet uses compareTo for identity, not equals.
If a.compareTo(b) == 0 but !a.equals(b):
    b is silently dropped when you try to add it to the TreeSet
    (treated as a duplicate of a)
```

The Java docs say `compareTo` should be consistent with `equals` — strongly recommended, not required.

**Comparison table:**

| Feature | `Comparable` | `Comparator` |
|---|---|---|
| Lives | Inside the class | Outside the class |
| Number of orderings | One (natural) | Many (one per instance) |
| Modify class needed | Yes | No |
| Java 8 chaining | No | Yes (`thenComparing`, `reversed`) |
| Used by `TreeSet` default | Yes | Pass to constructor |
| Lambda-friendly | No | Yes (functional interface) |

---

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"What is the difference between `Comparable` and `Comparator` in Java?"**

**One-line answer:** `Comparable` defines a class's own natural ordering via `compareTo` inside the class; `Comparator` defines an external, context-specific ordering via `compare` in a separate object.

> **Full answer to give in an interview:**
>
> "`Comparable` is an interface with a single method `compareTo(T other)`, implemented by the class itself. When a class implements `Comparable`, it bakes one ordering into the class — the natural ordering. For example, `String` implements `Comparable<String>` with lexicographic ordering; `Integer` uses numeric ordering. Once a class implements `Comparable`, you can sort lists of it with `Collections.sort()` and store it in `TreeSet` or `TreeMap` without any extra argument. `Comparator` is a separate functional interface with `compare(T o1, T o2)`. It defines an ordering externally — in a lambda, a static constant, or a method reference. You pass it to `list.sort(comparator)`, `Collections.sort(list, comparator)`, or `new TreeSet<>(comparator)`. The reason both exist: `Comparable` is for the one true default ordering; `Comparator` handles all other orderings, handles classes you can't modify, and enables multiple orderings on the same type. In Java 8, `Comparator` became dramatically more expressive: `Comparator.comparing(Order::getAmount).thenComparing(Order::getDate).reversed()` chains multiple sort keys in one readable expression."

*Lead with the definition, then show you know Java 8 chaining. That's the signal interviewers at Google and Amazon look for.*

**Gotcha follow-up they'll ask:**

*"What happens if two objects have `compareTo() == 0` but `equals()` returns `false`, and you add both to a `TreeSet`?"*

> Only the first one is kept. `TreeSet` uses `compareTo` to determine whether two elements are the same — if `compareTo` returns 0, the set treats them as duplicates and drops the second. `equals` is never consulted by `TreeSet` or `TreeMap`. This is an "inconsistency with equals" and it violates the recommendation in the `Comparable` contract. A concrete example: if you implement `compareTo` on `Order` by amount only, two orders with the same amount but different IDs will have `compareTo == 0` but `equals != 0`. Adding both to a `TreeSet` silently drops one. The fix is to include a tiebreaker in `compareTo` — add `.thenComparing(Order::getId)` — so that `compareTo` returns 0 only when `equals` would also return true.

---

#### Q2 — Tradeoff Question

**"When would you implement `Comparable` versus using a `Comparator`?"**

**One-line answer:** Use `Comparable` when there is one obvious, immutable natural ordering for the class; use `Comparator` for multiple orderings, context-specific sorting, or when you cannot modify the class.

> **Full answer to give in an interview:**
>
> "I think of `Comparable` as 'the ordering this type is named after' — the one ordering so obvious it belongs to the type itself. `String` is alphabetical; `Integer` is numeric; a `Date` is chronological. If I'm designing a `Money` class and there's only ever one sensible way to compare money — by amount — I'd implement `Comparable<Money>`. It integrates with `TreeSet`, `PriorityQueue`, and `Collections.sort` with zero extra code at the call site. But the moment I need two different orderings — say, sort products by price for one view and by popularity for another — `Comparable` can't help, because a class only gets one `compareTo`. That's when I reach for static `Comparator` constants: `Product.BY_PRICE`, `Product.BY_POPULARITY`. Java 8 makes this clean: `Comparator.comparing(Product::getPrice)` creates a comparator with one line. I'd also use `Comparator` when the class is from a library I can't modify — I can't add `Comparable` to a third-party class, but I can write a comparator for it. The practical guideline: if you're writing the class and there's one obvious ordering, implement `Comparable`. For everything else, write a `Comparator`."

*The `BY_PRICE`/`BY_POPULARITY` static constants pattern is a real-world idiom worth naming.*

**Gotcha follow-up they'll ask:**

*"What does `Comparator.naturalOrder()` return, and when would you use it?"*

> `Comparator.naturalOrder()` returns a comparator that delegates to `compareTo` — effectively `(a, b) -> a.compareTo(b)`. It's useful when you need a `Comparator` object but want it to use the natural ordering — for example, `Comparator.nullsLast(Comparator.naturalOrder())` creates a comparator that puts non-null elements in natural order and null elements at the end. You'd pass this to `list.sort()` or `TreeSet(comparator)` when you need null-safe natural ordering. `Comparator.reverseOrder()` is the reverse — it's `(a, b) -> b.compareTo(a)` — and is used the same way.

---

#### Q3 — Design Scenario

**"You need to sort a list of orders by: (1) priority HIGH before LOW, (2) amount descending, (3) creation time ascending. Write the Comparator."**

**One-line answer:** Chain `Comparator.comparing` calls with `thenComparing` for each key, using negation or `.reversed()` for descending order.

> **Full answer to give in an interview:**
>
> "I'd build this with Java 8 Comparator chaining. Priority ordering depends on how the `Priority` enum is defined — if it's declared as `HIGH, MEDIUM, LOW` in that order, the enum's natural ordering (`ordinal()`) already puts HIGH first, so `Comparator.comparing(Order::getPriority)` gives priority ascending which is HIGH before LOW. For amount descending, I'd either negate the key extractor or use `.reversed()` carefully. The cleanest readable form:
>
> ```java
> Comparator<Order> sort = Comparator
>     .comparing(Order::getPriority)
>     .thenComparing(Comparator.comparingDouble(Order::getAmount).reversed())
>     .thenComparing(Order::getCreatedAt);
> ```
>
> One subtlety: if I wrote `.thenComparing(Order::getAmount).reversed()` at the end, the `reversed()` would reverse the entire chain — priority descending, amount ascending — which is wrong. So I reverse only the amount comparator before passing it to `thenComparing`. Never use integer subtraction in `compareTo` for numeric fields — `return o1.amount - o2.amount` can overflow. Always use `Double.compare(o1.amount, o2.amount)` or `Integer.compare`. And if any field might be null — say, `createdAt` might not be set — I'd wrap the comparator: `thenComparing(Order::getCreatedAt, Comparator.nullsLast(naturalOrder()))`."

*Catching the `reversed()` scope mistake is a key signal. Many candidates get this wrong.*

**Gotcha follow-up they'll ask:**

*"Why should you never use subtraction in `compareTo` for integer fields?"*

> Integer overflow. If `o1.amount` is `Integer.MIN_VALUE` (-2,147,483,648) and `o2.amount` is 1, then `o1.amount - o2.amount` overflows to a large positive number — the JVM wraps around. The comparator then says o1 is *greater than* o2, which is backwards. This is a classic subtle bug that is hard to catch in testing because it only appears with extreme values. `Integer.compare(a, b)` is implemented as `(a < b) ? -1 : ((a == b) ? 0 : 1)` — no arithmetic, no overflow. Always use the static compare methods.

---

> **Common Mistake — Using subtraction in `compareTo` for integers:** Integer overflow produces wrong ordering for extreme values. Always use `Integer.compare()` or `Double.compare()`.

> **Common Mistake — Calling `.reversed()` at the end of a chain expecting only the last key to reverse:** `.reversed()` wraps the entire comparator built so far. Apply `.reversed()` to individual sub-comparators inside `thenComparing()` to reverse specific keys.

> **Common Mistake — Implementing `Comparable` inconsistently with `equals`:** `TreeSet` and `TreeMap` use `compareTo` for identity. If `compareTo` returns 0 for two unequal objects, the second is silently dropped. Ensure `compareTo == 0` if and only if `equals` is true, or add a tiebreaker field.

**Quick Revision (one line):** `Comparable` is natural ordering baked into the class via `compareTo`; `Comparator` is external ordering passed to sort methods — use Java 8's `comparing().thenComparing().reversed()` for multi-key sorts, never subtract integers in comparisons, and remember `TreeSet` uses `compareTo` for identity so inconsistency with `equals` silently drops elements.

---

## Topic 11: Exception Hierarchy

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Microsoft, Oracle, SAP, Capgemini

---

### The Idea

Think of Java's exception system like a hospital triage chart. At the top is one master category — `Throwable` — meaning "something went wrong." It splits into two wings. The first wing is the Emergency Room for the JVM itself: `Error`. These are crises the hospital cannot treat — the building is on fire (`OutOfMemoryError`), the elevator is stuck in a loop (`StackOverflowError`). You don't try to handle these; you call 911 (let the JVM restart).

The second wing is regular medicine: `Exception`. These are conditions that application code can diagnose and treat. Within `Exception`, there are two wards. The *checked* ward (IOException, SQLException) posts a sign: "You must acknowledge this risk before entering." The compiler is the security guard enforcing that sign. The *unchecked* ward (`RuntimeException`) has no sign — these are programming mistakes like forgetting to check for null. Nobody expects you to recover from your own bug.

The key insight for interviews: `RuntimeException` is a *subclass* of `Exception`, not a sibling. That surprises many candidates. It means every `RuntimeException` IS an `Exception`, just without the compiler mandate.

### How It Works

```
// Pseudocode: the hierarchy
Throwable
  ├── Error                    ← JVM-level, don't catch
  │     OutOfMemoryError
  │     StackOverflowError
  │     AssertionError
  └── Exception                ← application-level
        ├── IOException        ← checked (must handle or declare)
        ├── SQLException       ← checked
        ├── InterruptedException ← checked
        └── RuntimeException   ← unchecked (compiler silent)
              NullPointerException
              IllegalArgumentException
                NumberFormatException
              ClassCastException
              ArithmeticException
```

Key relationships to know:
- `Error` and `Exception` are *siblings* under `Throwable` — not parent/child.
- `RuntimeException` extends `Exception` — it IS an Exception, just unchecked.
- Checked = enforced by compiler. Unchecked = programmer's responsibility.

**The interview-critical gotcha — `return` in finally vs. the hierarchy catch order:**

```java
// The instanceof chain — NumberFormatException IS-A IllegalArgumentException IS-A RuntimeException
try {
    throw new NumberFormatException("bad input");
} catch (RuntimeException e) {
    // Caught here because NumberFormatException extends IllegalArgumentException extends RuntimeException
    System.out.println(e.getClass().getSimpleName());           // NumberFormatException
    System.out.println(e instanceof IllegalArgumentException);  // true
}
```

| Node | Parent | Category |
|---|---|---|
| `Error` | `Throwable` | JVM crisis — do not catch |
| `Exception` | `Throwable` | Application issue — handle |
| `RuntimeException` | `Exception` | Unchecked — programmer bug |
| `IOException` | `Exception` | Checked — recoverable I/O |
| `NullPointerException` | `RuntimeException` | Unchecked |
| `AssertionError` | `Error` | JVM-level assert failure |

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q1 — Concept Check

**"Walk me through the Java exception hierarchy."**

**One-line answer:** `Throwable` splits into `Error` (JVM failures, don't catch) and `Exception` (application issues), with `RuntimeException` as an unchecked subclass of `Exception`.

> **Full answer to give in an interview:** "At the root is `Throwable` — the supertype of everything that can be thrown or caught in Java. It has two direct subclasses. `Error` represents JVM-level failures like `OutOfMemoryError` or `StackOverflowError` — the kind of thing where the runtime itself is broken. Application code should almost never catch these; there's nothing useful to do. The other subclass is `Exception`, which covers things application code can respond to. `Exception` further splits: checked exceptions like `IOException` and `SQLException` must be either caught or declared in the method signature — the compiler enforces this. Then there's `RuntimeException`, which is a subclass of `Exception` — this is the unchecked branch. Things like `NullPointerException` and `IllegalArgumentException` live here. The compiler doesn't force you to handle them because they indicate programming bugs, not recoverable conditions. One thing that trips people up: `RuntimeException` is a *subclass* of `Exception`, not a sibling."

*Sketch the tree if you have a whiteboard — Throwable at the top, two branches down. It shows spatial thinking.*

**Gotcha follow-up they'll ask:** *"Is `RuntimeException` checked or unchecked?"*
> Unchecked. `RuntimeException` and all its subclasses are unchecked — the compiler does not require you to catch or declare them. This surprises candidates because `RuntimeException` *extends* `Exception`, which sounds like it should be checked, but the JLS makes a specific carve-out: anything that extends `RuntimeException` is unchecked.

#### Q2 — Concept Check

**"Can you catch `Error` in Java? Should you?"**

**One-line answer:** Syntactically yes; in practice almost never — `Error` means the JVM itself is broken and there's typically nothing safe to do.

> **Full answer to give in an interview:** "Java's syntax lets you write `catch (Error e)` or even `catch (Throwable t)` — it compiles and runs. But `Error` signals that the JVM or underlying system is in a state from which it generally cannot recover. `OutOfMemoryError` means the heap is exhausted; `StackOverflowError` means the call stack is full from infinite recursion. In both cases, executing more Java code is risky. That said, there are narrow legitimate uses: some frameworks catch `OutOfMemoryError` to try to free large caches and give the application one last chance to breathe. A thread pool executor might catch `Throwable` so that a thread that dies on an `Error` doesn't take the whole pool down silently. But these are expert-level cases. The default rule is: don't catch `Error`."

*Pause after "almost never." Wait to see if they probe. If they do, give the framework/thread-pool exception.*

**Gotcha follow-up they'll ask:** *"Where does `AssertionError` fit in the hierarchy?"*
> `AssertionError` extends `Error`, not `Exception`. It is thrown by Java's `assert` statements when assertions are enabled via the `-ea` JVM flag. Because it extends `Error`, it is unchecked and you should not catch it in normal code.

#### Q3 — Concept Check

**"Is `InterruptedException` checked or unchecked?"**

**One-line answer:** Checked — and it requires special handling: you must restore the interrupt flag after catching it.

> **Full answer to give in an interview:** "InterruptedException is checked, meaning the compiler forces you to handle or declare it. It's thrown when a thread is waiting or sleeping and another thread calls `interrupt()` on it. The important thing — and this is a common mistake — is what to do when you catch it. Many developers just swallow it with an empty catch block, which is wrong. When you catch `InterruptedException`, you must restore the interrupt flag by calling `Thread.currentThread().interrupt()`. Here's why: catching the exception clears the interrupted status of the thread. If your catch block just logs and continues, the calling code that checks `Thread.isInterrupted()` will think the thread was never interrupted and may fail to shut down gracefully. The rule is: if you catch `InterruptedException` and can't re-throw it, you must call `Thread.currentThread().interrupt()` before returning."

*This answer shows concurrency awareness, which distinguishes senior candidates.*

> **Common Mistake — Wrong position of RuntimeException in hierarchy:** Candidates often say `RuntimeException` is a sibling of `Exception` rather than a subclass of it. The consequence: they incorrectly claim `RuntimeException` cannot be caught by `catch (Exception e)` — it can, because it IS an Exception.

> **Common Mistake — Checked exceptions must always be caught:** Checked exceptions can also be *declared* with `throws` and propagated to the caller. Catching is not the only option.

**Quick Revision (one line):** `Throwable` → `Error` (JVM, don't catch) + `Exception` → checked (compiler-enforced) + `RuntimeException` (unchecked, programmer bugs).

---

## Topic 12: Checked vs Unchecked Exceptions

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, ThoughtWorks, Atlassian, Spotify

---

### The Idea

Imagine you're writing a recipe for a chef. For some steps, you *must* write a warning: "This step can fail — here's what to do if it does." That's a checked exception. The compiler is the editor who won't let you publish the recipe without the warning. For other steps — like "don't drop the knife" — you trust the chef to know better. That's an unchecked exception.

The design intent was sound: force callers to acknowledge genuinely recoverable failures (file not found — try another path; network timeout — retry). But the real world pushed back. By the time a `SQLException` from the database layer travels through the service layer and controller layer, every method in the chain needs `throws SQLException` on its signature. The exception pollutes the entire call stack without adding information.

Modern Java — and Spring in particular — largely moved to unchecked exceptions. Spring wraps all JDBC `SQLException` (checked) inside `DataAccessException` (unchecked). Service code stops declaring `throws SQLException` and the framework's global exception handler maps it to the right HTTP status code. This is now the industry standard pattern.

### How It Works

```
// Pseudocode: the compiler's perspective
method readFile(path):
    // This throws IOException (checked)
    // You MUST either:
    //   a) catch it here, OR
    //   b) declare: throws IOException
    // Otherwise: compile error

method getUser(id):
    // This throws NullPointerException (unchecked, extends RuntimeException)
    // Compiler says nothing — your responsibility to not pass null
```

The practical decision table:

| Condition | Use |
|---|---|
| Caller can realistically recover (retry, fallback) | Checked exception |
| Programming bug (null, bad arg, invalid state) | Unchecked (`RuntimeException`) |
| Framework/library error wrapping another | Unchecked (wrap checked with unchecked) |
| Used inside lambdas or streams | Unchecked — checked exceptions don't work in lambdas |

**The interview-critical gotcha — checked exceptions inside lambda/streams:**

```java
List<String> paths = List.of("a.txt", "b.txt");

// This does NOT compile — Files.readString throws IOException (checked)
// and Stream.map's functional interface doesn't declare throws IOException
paths.stream()
     .map(Files::readString) // compile error

// Fix: wrap in unchecked
paths.stream()
     .map(p -> {
         try { return Files.readString(Path.of(p)); }
         catch (IOException e) { throw new UncheckedIOException(e); }
     })
     .collect(toList());
```

`UncheckedIOException` (added in Java 8) is the standard wrapper for `IOException` in stream contexts. Always wrap with the original exception as the cause — never pass only `e.getMessage()`, or you lose the stack trace.

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q4 — Concept Check

**"What is the difference between checked and unchecked exceptions?"**

**One-line answer:** Checked exceptions are enforced by the compiler for recoverable conditions; unchecked exceptions extend `RuntimeException` and signal programming bugs the compiler doesn't track.

> **Full answer to give in an interview:** "Checked exceptions are subclasses of `Exception` that do *not* extend `RuntimeException`. The compiler enforces that any method calling code which throws a checked exception either wraps it in a try-catch or declares it in its `throws` clause. Examples: `IOException`, `SQLException`. The intent is to force callers to think about failure modes — the file might not exist, the network might be down, and those are conditions a well-designed application can recover from. Unchecked exceptions extend `RuntimeException`. The compiler has no requirement to handle them. They represent programming errors: calling a method on a null reference (`NullPointerException`), passing a bad argument (`IllegalArgumentException`). Callers are not expected to recover from a programming bug — the fix is in the code. In modern Java, most frameworks prefer unchecked exceptions for application errors, because checked exceptions pollute method signatures across layers and can't be used cleanly in lambdas and streams."

*If they nod, volunteer the Spring/DataAccessException example — it shows real-world awareness.*

**Gotcha follow-up they'll ask:** *"Why can't you use a checked-exception-throwing method in a Java 8 lambda?"*
> Because Java's functional interfaces — `Function`, `Consumer`, `Supplier` — don't declare `throws Exception` in their abstract method signature. The compiler requires that any checked exception either be caught or declared. Inside a lambda, you can't add `throws IOException` to the lambda's effective signature. The workaround is to catch the checked exception inside the lambda and rethrow it as an unchecked exception — either a generic `RuntimeException` or the purpose-built `UncheckedIOException` for I/O cases.

#### Q5 — Tradeoff Question

**"Why does Spring prefer unchecked exceptions? Is there a downside?"**

**One-line answer:** Unchecked exceptions avoid signature pollution and work with lambdas, but they shift the documentation burden from the compiler to Javadoc and developer discipline.

> **Full answer to give in an interview:** "Spring's position, which is now the industry mainstream, is that checked exceptions create more pain than they solve. The canonical example is JDBC: `java.sql.SQLException` is checked, so every DAO method that talks to the database must declare `throws SQLException`. That forces every service method calling the DAO to either catch it or declare it too, and so on up to the controller. By the time you have five layers, every method signature carries `throws SQLException` even though only the DAO knows what to do with it. Spring wraps all JDBC exceptions in `DataAccessException`, which is unchecked. The service layer doesn't need to know about JDBC at all. The downside is that unchecked exceptions are invisible in method signatures. With checked exceptions, the compiler tells you what can go wrong. With unchecked, you rely on Javadoc, good naming, and code review. If a library throws an undocumented `RuntimeException` that you're not catching, it will silently propagate to the top of your stack. The tradeoff is: less ceremony, more discipline required."

*The phrase "more discipline required" signals maturity. Most interviewers appreciate the balanced take.*

**Gotcha follow-up they'll ask:** *"Can an overriding method throw a broader checked exception than the parent?"*
> No. An overriding method can throw the same checked exceptions as the parent, narrower ones, or none at all — but not broader. If the parent declares `throws IOException`, the override can declare `throws FileNotFoundException` (narrower) but not `throws Exception` (broader). This is the Liskov Substitution Principle applied to exceptions: code that holds a reference to the parent type must be able to handle the exceptions the parent declares, and the override must not surprise it with new ones.

#### Q6 — Design Scenario

**"You're writing a library method that reads a config file. Should you throw a checked or unchecked exception if the file is missing?"**

**One-line answer:** Checked if the file path is user-supplied and missing is recoverable; unchecked if the path is hardcoded and its absence is a deployment error.

> **Full answer to give in an interview:** "It depends on whether the caller can realistically do something useful when the file is missing. If the file path comes from user input or a configuration parameter, the caller might want to show an error message, fall back to defaults, or prompt for a correct path. That's genuinely recoverable — a checked exception is appropriate because it forces the caller to think about the failure mode. But if the file is a bundled application resource that must exist for the application to function — like a schema file or a required properties file — then its absence is a deployment bug, not a runtime condition. An unchecked exception like `IllegalStateException` with a clear message is better: 'Required config file not found at /etc/app/config.properties — check deployment.' I'd also think about the API audience. If this is a public library that other teams consume, checked exceptions document the contract clearly. If it's internal code in a Spring service, unchecked keeps the code cleaner and the global exception handler can map it to HTTP 500."

*Structure: recoverable → checked, deployment bug → unchecked. That framework answers 90% of follow-ups.*

> **Common Mistake — Losing the stack trace:** Catching a checked exception and rethrowing as `new RuntimeException(e.getMessage())` loses the original stack trace. Always pass the original exception as the cause: `new RuntimeException("message", e)` or `new UncheckedIOException(e)`.

> **Common Mistake — Blanket `throws Exception`:** Declaring `throws Exception` on every method to avoid thinking about exception types is worse than useless — it forces every caller to catch `Exception`, which is too broad to handle meaningfully.

**Quick Revision (one line):** Checked = compiler-enforced, for recoverable failures; unchecked = runtime, for bugs; Spring wraps JDBC's checked `SQLException` in unchecked `DataAccessException`; checked exceptions can't be used directly in lambdas.

---

## Topic 13: try-catch-finally Execution Order

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Goldman Sachs, Morgan Stanley, Barclays, Infosys

---

### The Idea

Imagine a restaurant kitchen. The cook (try block) attempts to prepare a dish. If something goes wrong, the sous-chef steps in (catch block). Regardless of whether the dish was a success or a disaster, someone always cleans the station at the end (finally block). The cleaning happens even if the cook quits mid-service — as long as the kitchen is still standing.

That "as long as the kitchen is still standing" clause is the key. The one exception: if the entire building is demolished (`System.exit()` or JVM crash), the cleaning crew never gets in. But short of that, finally always runs.

The subtlety that catches people in interviews: if the cook writes the final receipt before leaving (`return` in try), the receipt is already written. The cleaner (finally) can dust around it but cannot change what's written — unless the cleaner writes a *new* receipt themselves (`return` in finally). That new receipt overrides the cook's.

### How It Works

```
// Pseudocode: execution order
execute try block
  if exception thrown AND matching catch exists:
    execute catch block
  if exception thrown AND no matching catch:
    exception is held, not yet propagated
execute finally block (ALWAYS, except System.exit/JVM crash)
  if exception was not caught:
    now propagate it
  if try/catch returned normally:
    return that value
```

Order of events in every scenario:

| Scenario | Order |
|---|---|
| No exception | try → finally → return |
| Exception caught | try → catch → finally → return |
| Exception not caught | try → finally → exception propagates |
| `return` in try | try (saves return value) → finally → return saved value |
| `return` in finally | try → finally (overrides) → return finally's value |
| Exception in finally | try exception LOST, finally exception propagates |

**The interview-critical gotcha — `return` in finally swallows exceptions:**

```java
// Classic interview trap
static int count() {
    int i = 0;
    try { i = 1; return i; }  // return value 1 is saved on the stack
    finally { i = 2; }        // modifies local var, but saved return value is still 1
}
// Returns 1, not 2

// Truly dangerous pattern:
static void dangerous() throws Exception {
    try {
        throw new IOException("original");
    } finally {
        throw new RuntimeException("from finally"); // IOException is COMPLETELY LOST
    }
}
```

The exception-in-finally scenario is why try-with-resources was invented: instead of silently losing the original exception, it attaches the close exception as a *suppressed* exception on the original.

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q7 — Concept Check

**"Does `finally` always execute?"**

**One-line answer:** Yes, except when `System.exit()` is called or the JVM crashes — those are the only two cases where finally is skipped.

> **Full answer to give in an interview:** "Finally always executes after the try and catch blocks — whether the try block completed normally, an exception was thrown and caught, or an exception was thrown and not caught. In the last case, finally still runs before the exception propagates up the call stack. The two exceptions to this rule: `System.exit()` immediately terminates the JVM — shutdown hooks run but finally blocks do not. And if the JVM itself crashes — segfault, kill -9 — finally obviously cannot run. One more edge case worth knowing: if the thread is stopped via `Thread.stop()`, which throws `ThreadDeath`, finally blocks *do* execute as the stack unwinds — that's actually the main reason `Thread.stop()` was deprecated, the ThreadDeath flowing through finally blocks could leave objects in inconsistent states."

*Mentioning `Thread.stop()` and `ThreadDeath` is a nice bonus that signals depth.*

**Gotcha follow-up they'll ask:** *"What happens if there's a `return` statement in both try and finally?"*
> The finally's return wins. When try executes `return 1`, the JVM saves the return value on the stack and jumps to finally. If finally contains `return 2`, that `return` exits the method immediately with value 2. The saved value of 1 is discarded. This also silently swallows any exception that was thrown in the try block — the exception is abandoned because finally exited via `return` instead of falling through. This is why `return` in finally is considered an anti-pattern.

#### Q8 — Tradeoff Question

**"Why is putting `connection.close()` in a finally block dangerous, and what's the fix?"**

**One-line answer:** If `close()` itself throws, the original exception is silently swallowed; use try-with-resources instead, which converts the close exception into a suppressed exception on the original.

> **Full answer to give in an interview:** "The classic JDBC pattern puts `connection.close()` in finally to ensure cleanup. The danger is exception swallowing. If the try block throws a `SQLException` — say, a deadlock — and then `connection.close()` in finally also throws — say, a network error — Java only propagates the *finally* exception. The original `SQLException` is completely lost. The caller sees a network error and has no idea there was a deadlock. This makes debugging very hard. The fix is try-with-resources. When `Connection` implements `AutoCloseable` — which it does — you write `try (Connection conn = dataSource.getConnection())`. If the try body throws and `close()` also throws, Java attaches the `close()` exception as a *suppressed* exception on the original using `addSuppressed()`. The original exception propagates, and the close exception can be retrieved via `getSuppressed()`. Nothing is lost."

*This answer shows you know JDBC, exception semantics, and the motivation for try-with-resources — three layers.*

**Gotcha follow-up they'll ask:** *"What is the output of `count()` where try does `i=1; return i` and finally does `i=2`?"*
> Returns 1. When `return i` executes in try, the current value of `i` (which is 1) is copied to a return-value slot on the stack. Then finally runs and sets `i = 2` — but that only changes the local variable, not the already-saved return value. The method returns 1. If finally had `return i`, it would return 2 — because that's a new `return` statement that overrides the one in try.

#### Q9 — Design Scenario

**"You're writing a JDBC DAO. Where do you put the connection close, and why?"**

**One-line answer:** Use try-with-resources so the connection is auto-closed and any close exception becomes a suppressed exception rather than swallowing the real error.

> **Full answer to give in an interview:** "I'd use try-with-resources rather than a finally block. `java.sql.Connection` extends `AutoCloseable`, so I can write `try (Connection conn = dataSource.getConnection(); PreparedStatement ps = conn.prepareStatement(sql))`. Both the statement and connection are closed automatically in reverse order — statement first, then connection — even if the query throws. The key advantage over finally: if the try body throws a `SQLException` and then `close()` also throws, the close exception is attached as a suppressed exception on the SQL exception rather than replacing it. I still get the real error, plus the close error is accessible via `getSuppressed()` if I need it for diagnostics. I'd also make sure my logging framework logs suppressed exceptions — some don't by default, and you can miss important close failures."

*The detail about logging suppressed exceptions is the kind of practical note that lands well in interviews.*

> **Common Mistake — Assuming finally doesn't run when no exception is caught:** Finally runs regardless. Whether the try block completed normally, caught an exception, or has an uncaught exception flying through — finally always executes.

> **Common Mistake — `connection.close()` in finally without its own try-catch:** If `close()` throws and you haven't wrapped it, it will propagate and silently swallow whatever the try block threw. Always use try-with-resources to avoid this.

**Quick Revision (one line):** finally always runs except `System.exit()`; `return` in finally overrides try's return; exception in finally swallows the original; use try-with-resources to avoid this.

---

## Topic 14: try-with-resources

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Netflix, Booking.com, SAP

---

### The Idea

Every time you open a file, database connection, or network socket, you're renting a resource. Good tenants return what they rent. The problem in Java was that "returning" (closing) the resource required a finally block — and as Topic 13 showed, exceptions thrown by `close()` would silently swallow the exception you actually cared about.

Java 7 introduced try-with-resources as a contract: if your object implements `AutoCloseable` (which just means it has a `close()` method), you can declare it in the try header and Java guarantees it will be closed when the block exits — no matter what. The clever twist: if both your code and `close()` throw exceptions, Java doesn't lose either one. The close exception is *suppressed* — attached to the primary exception — and you can retrieve it later.

Think of it like a rented car. You have an accident (primary exception). When you return the car, there's also a scratch (close exception). The rental company doesn't pretend the accident didn't happen — they file both claims. The accident is the main report, the scratch is the supplementary note.

### How It Works

```
// Pseudocode: what the compiler generates for try-with-resources
declare resource r
primaryException = null
try:
    use r
catch any Throwable t:
    primaryException = t
    re-throw t
finally:
    if primaryException != null:
        try: r.close()
        catch suppressed: primaryException.addSuppressed(suppressed)
    else:
        r.close()   // no primary exception — let close() exception propagate normally
```

Multiple resources close in reverse declaration order (last-declared closes first):

```
// Pseudocode: multiple resources
try (A a = new A(); B b = new B()):
    use a and b
// Exit: b.close() first, then a.close()
// If b.close() throws, a.close() still runs;
// a.close() exception is suppressed onto b.close() exception
```

**The interview-critical gotcha — suppressed exceptions and `getSuppressed()`:**

```java
static class FlakyConnection implements AutoCloseable {
    @Override
    public void close() throws Exception {
        throw new Exception("close() failed");
    }
}

try (FlakyConnection fc = new FlakyConnection()) {
    throw new RuntimeException("primary exception");
} catch (RuntimeException e) {
    System.out.println("Primary: " + e.getMessage());         // "primary exception"
    for (Throwable s : e.getSuppressed()) {
        System.out.println("Suppressed: " + s.getMessage()); // "close() failed"
    }
}
// The primary exception propagates; close() exception is NOT lost
```

| Feature | try-finally (old) | try-with-resources (Java 7+) |
|---|---|---|
| Auto-close guarantee | Manual finally | Built into syntax |
| Exception from `close()` | Swallows primary | Suppressed on primary |
| Multiple resources | Nested finally blocks | Inline, reverse-order close |
| Null resource | Must null-check manually | Null resource → close() skipped (Java 9+) |
| Code verbosity | High | Low |

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q10 — Concept Check

**"What happens if both the try block and `close()` throw exceptions in try-with-resources?"**

**One-line answer:** The try block's exception is the primary and propagates; the `close()` exception is attached as a suppressed exception retrievable via `getSuppressed()`.

> **Full answer to give in an interview:** "This is the key advantage of try-with-resources over the old finally pattern. If the try body throws — say a `RuntimeException` — and then `close()` also throws when the resource is being cleaned up, Java uses a mechanism called suppressed exceptions. The `close()` exception is attached to the primary exception using `Throwable.addSuppressed()`, which was added specifically for this in Java 7. The primary exception propagates normally to the caller. If the caller wants to know about the close failure, they call `e.getSuppressed()`, which returns an array of the suppressed throwables. This is much better than the old finally behavior where a `close()` exception would completely replace the original exception, losing all information about what actually went wrong in the business logic."

*Use the word "suppressed" explicitly — it's the key term the interviewer wants to hear.*

**Gotcha follow-up they'll ask:** *"In what order are multiple resources closed in try-with-resources?"*
> Reverse declaration order — like a stack. If you declare `try (A a = ...; B b = ...)`, then `b.close()` runs first, then `a.close()`. This mirrors the natural stack discipline: last opened, first closed. If `b.close()` throws, `a.close()` still runs — and if `a.close()` also throws, that exception is suppressed onto the `b.close()` exception.

#### Q11 — Concept Check

**"What is `AutoCloseable` and how does it relate to `Closeable`?"**

**One-line answer:** `AutoCloseable` (Java 7) is the interface try-with-resources requires; `Closeable` (older) extends it and narrows `close()` to throw only `IOException`.

> **Full answer to give in an interview:** "To use try-with-resources, the resource class must implement `java.lang.AutoCloseable`, which has a single method: `close() throws Exception`. That's it — a very simple contract. `Closeable`, which has been in Java since 1.1 for streams and I/O, was retrofitted to extend `AutoCloseable` in Java 7. The difference: `Closeable.close()` declares `throws IOException`, while `AutoCloseable.close()` declares `throws Exception`. For non-I/O resources — like a database connection wrapper or a lock — you implement `AutoCloseable` directly and your `close()` can throw a more specific exception. For I/O resources, `Closeable` is the standard. In practice, most things that implement `Closeable` — `InputStream`, `OutputStream`, `Reader`, `Writer`, JDBC `Connection`, `Statement`, `ResultSet` — work seamlessly with try-with-resources because `Closeable` is a subtype of `AutoCloseable`."

*Mentioning JDBC types shows you connect the concept to real API usage.*

**Gotcha follow-up they'll ask:** *"Can you use a nullable resource with try-with-resources?"*
> If the resource variable is null when the try block exits, Java skips calling `close()` — no `NullPointerException`. This behavior is specified in the JLS and applies from Java 9 onwards when using the "effectively final variable" form (`try (existingVar) { ... }`). With the declaration form inside the try header, if the constructor returns null (unusual), the behavior is the same — null is checked before `close()` is called.

#### Q12 — Design Scenario

**"How would you implement a custom `AutoCloseable` resource for a connection pool entry?"**

**One-line answer:** Implement `AutoCloseable`, return the connection to the pool in `close()`, and make `close()` idempotent so double-close is harmless.

> **Full answer to give in an interview:** "I'd create a wrapper class — say `PooledConnection` — that implements `AutoCloseable`. It holds a reference to the underlying JDBC `Connection` and a reference to the pool. The `close()` method doesn't actually close the connection; it returns it to the pool by calling `pool.release(this)`. I'd make `close()` idempotent — if called twice, the second call is a no-op — because resource management code sometimes calls `close()` defensively. I'd also mark the connection as 'returned' with a boolean flag and throw `IllegalStateException` if any method is called after it's been returned, so bugs surface fast. The caller's code is then: `try (PooledConnection conn = pool.acquire()) { conn.execute(sql); }`. The connection is guaranteed to return to the pool even if `execute()` throws. Any exception from `release()` in `close()` would be suppressed onto the `execute()` exception, not replacing it."

*The idempotency point and the post-close guard are the details that distinguish a senior answer.*

> **Common Mistake — Thinking try-with-resources prevents `close()` exceptions:** It doesn't prevent them — it handles them gracefully by suppressing them. If the try block completes *normally* and `close()` throws, that exception propagates as usual. Suppression only happens when there's already a primary exception in flight.

> **Common Mistake — Not logging suppressed exceptions:** Many logging frameworks only log `e.getMessage()` or the primary stack trace. Suppressed exceptions from `close()` failures are silently dropped. Make sure your logging captures `e.getSuppressed()`.

**Quick Revision (one line):** try-with-resources auto-closes `AutoCloseable` resources in reverse order; if both try body and `close()` throw, `close()` exception is suppressed on primary; Java 9 allows effectively-final variables in the try header.

---

## Topic 15: Multi-catch

**Difficulty:** Easy | **Frequency:** Medium | **Companies:** Amazon, Cognizant, Infosys, Accenture

---

### The Idea

Before Java 7, if two unrelated exceptions needed the same handling — log it, return a default, rethrow as a domain exception — you wrote two identical catch blocks. One for `IOException`, one for `SQLException`. Copy-paste code with the exact same body. Multi-catch is Java 7's fix: `catch (IOException | SQLException e)` handles both in one block.

There's one important constraint that the compiler enforces: the two exception types cannot be in a parent-child relationship. If you write `catch (Exception | IOException e)`, the compiler rejects it — `IOException` is already covered by `Exception`, making the `IOException` branch redundant. The rule prevents accidental over-catching disguised as a multi-catch.

The other constraint is subtle: the variable `e` is *effectively final* inside a multi-catch block. You cannot reassign it. This is because the compiler cannot statically determine whether `e` is an `IOException` or a `SQLException` at the reassignment point — the type would be ambiguous.

### How It Works

```
// Pseudocode: multi-catch
try:
    risky operation that can throw TypeA or TypeB
catch (TypeA | TypeB e):
    // TypeA and TypeB must NOT be parent/child of each other
    // e is effectively final — cannot reassign e inside here
    handle both the same way

// Compile error examples:
catch (Exception | IOException e)    // IOException IS-A Exception — redundant
catch (RuntimeException | NPE e)     // NPE IS-A RuntimeException — redundant
```

The compiler generates separate bytecode handler entries for each exception type in the multi-catch, then routes both to the same handler code. From the JVM's perspective, it is two separate catch blocks that happen to share a body. The type of `e` is the *least upper bound* of the listed types — for `IOException | SQLException`, that is `Exception`, since they share no closer common supertype in the standard library.

**The interview-critical gotcha — effectively final `e` and why it matters:**

```java
try {
    processRecord(record);
} catch (IOException | SQLException e) {
    System.out.println(e.getMessage()); // fine

    // e = new IOException("replacement"); // COMPILE ERROR
    // Why: e's static type is LUB(IOException, SQLException) = Exception
    // If reassignment were allowed, you could put an IOException
    // into a slot that might conceptually be a SQLException — type unsafe

    throw e; // fine — rethrowing is allowed
}
```

| | Single catch per type | Multi-catch |
|---|---|---|
| Code duplication | High if handlers identical | None |
| Different handling per type | Supported | Not supported — use separate catches |
| Related exceptions (parent/child) | Supported | Compile error |
| `e` mutability | Mutable | Effectively final |
| Bytecode | One handler | Multiple handlers, shared body |

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

#### Q13 — Concept Check

**"What is multi-catch and what are its constraints?"**

**One-line answer:** Multi-catch (`catch (A | B e)`) handles multiple unrelated exception types in one block; the types must not be in a parent-child relationship and `e` is effectively final.

> **Full answer to give in an interview:** "Multi-catch was introduced in Java 7 to eliminate duplicate catch blocks that do the same thing. The syntax is `catch (IOException | SQLException e)` — a pipe-separated list of exception types. There are two compiler constraints. First, the exception types in the list must not be related by inheritance. If `TypeA` is a parent or ancestor of `TypeB`, the `TypeB` branch is redundant — it would always be caught by `TypeA` first. The compiler rejects this with 'Alternatives in a multi-catch statement cannot be related by subclassing.' Second, the variable `e` is effectively final inside the multi-catch block — you cannot reassign it. This is because the compiler infers the type of `e` as the least upper bound of the listed types, and reassigning with a specific type would be inconsistent. Under the hood, the compiler generates separate bytecode handler entries for each type, routing both to the same handler code — so it's syntactic sugar, not a new JVM instruction."

*"Syntactic sugar" is the technically precise phrase. Use it.*

**Gotcha follow-up they'll ask:** *"What is the type of `e` in `catch (IOException | SQLException e)`?"*
> The least upper bound of `IOException` and `SQLException`. Since they both extend `Exception` and share no closer common supertype in the standard library, the type of `e` is effectively `Exception`. This is why you can only call methods available on `Exception` — like `getMessage()` and `getCause()` — on `e` inside the catch block. You cannot call `IOException`-specific methods unless you do an `instanceof` check and cast.

#### Q14 — Concept Check

**"Why can't you reassign `e` in a multi-catch block?"**

**One-line answer:** Because `e`'s static type is the least upper bound of all listed types, allowing reassignment would break type safety since you could assign a type inconsistent with one of the alternatives.

> **Full answer to give in an interview:** "The compiler infers the type of `e` as the least upper bound of the listed exception types. For `catch (IOException | SQLException e)`, that's `Exception`. If you could do `e = new IOException(...)` inside the catch block, it would appear type-safe because `IOException` is an `Exception`. But the compiler also needs to let you rethrow `e` — `throw e` — and it needs to statically verify that the rethrown exception is declared or caught. If `e` were reassignable, the compiler couldn't know at the `throw e` site whether `e` was an `IOException` or a `SQLException`. Making `e` effectively final means the compiler can look back at the catch declaration and know exactly what types `e` can be, enabling precise throws-checking. It's a type-system correctness decision, not an arbitrary restriction."

*This is a deeper answer than most candidates give. The connection to `throw e` type-checking is the key insight.*

**Gotcha follow-up they'll ask:** *"Is `catch (Exception | RuntimeException e)` valid?"*
> No — compile error. `RuntimeException` is a subclass of `Exception`. The compiler rejects this because `RuntimeException` is redundant: any `RuntimeException` would already be caught by the `Exception` branch. The error message is: "Alternatives in a multi-catch statement cannot be related by subclassing."

#### Q15 — Design Scenario

**"A data import pipeline calls a parser and a database write. Both can fail with different exceptions but both failures mean 'skip this record.' How would you structure the catch?"**

**One-line answer:** Use multi-catch for the two unrelated exception types since the handling is identical — log and skip — keeping the code DRY.

> **Full answer to give in an interview:** "Since `ParseException` and `DataIntegrityViolationException` — the Spring unchecked wrapper for constraint violations — are unrelated in the hierarchy and both mean 'this record is bad, skip it,' multi-catch is the right tool. I'd write `catch (ParseException | DataIntegrityViolationException e)`. Inside, I log the record identifier and the exception, increment a bad-record counter, and continue. I wouldn't use a single `catch (Exception e)` even though it's simpler — that would also catch unexpected exceptions like `OutOfMemoryError` subtypes or framework bugs that I want to see fail loudly. Multi-catch keeps the scope precise: I handle exactly the two failure modes I expect, and anything else propagates. If the two failures ever needed different handling — say, parse errors should be reported to the user while database errors should trigger an alert — I'd split them into separate catch blocks at that point."

*The contrast with `catch (Exception e)` shows you think about scope. That's a senior signal.*

> **Common Mistake — Catching a parent and child together:** Writing `catch (Exception | IOException e)` is a compile error. `IOException` is a subclass of `Exception`. The compiler prevents this because it's logically redundant and likely a mistake.

> **Common Mistake — Trying to reassign `e`:** Developers sometimes try `e = new IOException("wrapped")` inside a multi-catch to add context. This is a compile error. Use a separate variable: `IOException wrapped = new IOException("context", e)` and throw that.

**Quick Revision (one line):** `catch (A | B e)` handles unrelated exception types in one block; A and B must not be parent/child; `e` is effectively final; the compiler generates separate bytecode handlers — purely syntactic sugar.

---

## Topic 16: Custom Exceptions

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Stripe, ThoughtWorks

---

### The Idea

Most programming languages let you signal problems by throwing objects. Java's built-in exceptions — `NullPointerException`, `IllegalArgumentException` — describe generic problems. But when your application fails for a business reason, like "Order not found" or "Insufficient funds," a generic exception tells the caller almost nothing useful. A custom exception is simply a class you write that extends one of Java's exception types, with a name and fields that describe exactly what went wrong in your domain.

The reason custom exceptions exist is to make error handling precise and informative. Instead of catching a generic `RuntimeException` and guessing what happened by parsing its message string, a `@ControllerAdvice` (Spring's global error handler) can catch `OrderNotFoundException` specifically and return an HTTP 404 with a structured JSON body — order ID, error code, human-readable message — all in one go.

The design rule is simple: in modern Java (Spring Boot, Jakarta EE), extend `RuntimeException` by default. These are called unchecked exceptions — they propagate freely without forcing every method in the call stack to declare `throws YourException`. Only extend checked `Exception` when callers genuinely must be forced to handle the failure and cannot reasonably continue without doing so.

### How It Works

```
// Pseudocode: minimum viable custom exception
class OrderNotFoundException extends RuntimeException:
    field orderId
    field errorCode = "ORDER_NOT_FOUND"

    constructor(orderId):
        super("Order not found: " + orderId)
        this.orderId = orderId

    constructor(orderId, cause):         // CRITICAL: always include this
        super("Order not found: " + orderId, cause)
        this.orderId = orderId
```

The `cause` constructor is the single most important detail. When the DAO catches a `SQLException` and wraps it in your custom exception, passing the original exception as `cause` preserves the full original stack trace. Without it, the root cause vanishes and debugging becomes guesswork.

**Naming and packaging conventions:**
- Name always ends in `Exception`: `OrderNotFoundException`, `InsufficientFundsException`
- Place in a dedicated package: `com.myapp.exception` or alongside the domain it belongs to

**Domain fields to include for REST APIs (RFC 7807 pattern):**

| Field | Purpose |
|---|---|
| `errorCode` | Machine-readable string (e.g. `ORDER_NOT_FOUND`) — used by API clients |
| `entityId` | The ID of the thing that was not found or violated a rule |
| `message` | Human-readable — do NOT include internal details or stack info |

**Tradeoff — checked vs unchecked:**

| Extend | When | Cost |
|---|---|---|
| `RuntimeException` | Default; Spring/stream-friendly; global handler catches it | No `throws` declarations needed anywhere |
| `Exception` (checked) | Caller absolutely must acknowledge failure (e.g. `InsufficientFundsException` in a payment API) | Every caller must `catch` or `throws` it — adds ceremony |

The most interview-critical gotcha — the cause constructor that most candidates forget:

```java
public class OrderNotFoundException extends RuntimeException {

    private final String orderId;
    private final String errorCode;

    public OrderNotFoundException(String orderId) {
        super("Order not found: " + orderId);
        this.orderId = orderId;
        this.errorCode = "ORDER_NOT_FOUND";
    }

    // Without this constructor, callers must call initCause() separately — easy to forget
    public OrderNotFoundException(String orderId, Throwable cause) {
        super("Order not found: " + orderId, cause);
        this.orderId = orderId;
        this.errorCode = "ORDER_NOT_FOUND";
    }

    public String getOrderId()   { return orderId; }
    public String getErrorCode() { return errorCode; }
}
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"Why create custom exceptions instead of just using `IllegalArgumentException` or `RuntimeException` everywhere?"**

**One-line answer:** Custom exceptions make error handling precise — handlers can catch a specific type and respond with the right HTTP status code and structured payload, without parsing message strings.

> **Full answer to give in an interview:**
>
> "The core problem with generic exceptions is that a handler cannot distinguish between failures. If a service throws `RuntimeException` for both 'order not found' and 'payment declined', a global error handler has to inspect the message string to decide whether to return a 404 or a 402 — that's fragile and breaks when someone changes the message wording.
>
> With custom exceptions, the type itself carries the meaning. A `@ControllerAdvice` — Spring's global error-handling mechanism, where you write one method per exception type that gets invoked automatically — can catch `OrderNotFoundException` and return an HTTP 404 with a JSON body containing the order ID and a machine-readable error code. It can catch `InsufficientFundsException` and return 402 with the shortfall amount. No string parsing required.
>
> Beyond routing, custom exceptions carry structured data — fields like `orderId`, `errorCode`, `requestedAmount` — that make both logs and API responses informative. A generic exception can only give you a message string."

*Pause after the first sentence. If the interviewer nods, add the Spring example. If they probe "what structured data?", give the field examples.*

**Gotcha follow-up they'll ask:** *"What's the one constructor you must always include in a custom exception?"*

> The constructor that accepts `(String message, Throwable cause)`. When a lower layer — say, a DAO catching a `SQLException` — wraps that exception in your custom type, passing the original as `cause` preserves the full original stack trace. If you omit this constructor, callers are forced to call `initCause()` as a separate step, which is easy to forget and breaks exception chaining.

---

#### Q2 — Tradeoff Question

**"When would you extend checked `Exception` instead of unchecked `RuntimeException` for a custom exception?"**

**One-line answer:** Only when callers genuinely must be forced to acknowledge and handle the failure — not just log it and move on.

> **Full answer to give in an interview:**
>
> "Checked exceptions — those that extend `Exception` but not `RuntimeException` — are enforced by the Java compiler: every method that might throw one must either catch it or declare `throws` in its signature. This forces the failure to be visible at every layer.
>
> The textbook case is a payment API's `InsufficientFundsException`. It represents a business condition the caller cannot ignore — the money isn't there and processing must stop in a deliberate way. Making it checked forces the calling code to explicitly handle or propagate it.
>
> In practice, though, most modern Java code — especially Spring Boot applications — defaults to unchecked exceptions, for two reasons. First, Spring's `@ControllerAdvice` handles exceptions globally, so you don't need the compiler to force catch blocks everywhere. Second, checked exceptions don't play well with functional interfaces like `Function` or `Supplier` — lambdas can't throw checked exceptions without wrapping them, which adds boilerplate.
>
> My rule: start with unchecked. Switch to checked only if callers are expected to handle it in specific ways and you want the compiler to enforce that contract."

*If they ask about Spring specifically, mention that Spring's `DataAccessException` hierarchy deliberately made everything unchecked for this reason.*

**Gotcha follow-up they'll ask:** *"What fields should a custom exception carry for a REST API?"*

> An error code — a short uppercase string like `ORDER_NOT_FOUND` that API clients can switch on programmatically — the ID of the entity involved, and a human-readable message. Following RFC 7807 (Problem Details for HTTP APIs), the exception maps to a structured JSON response with `type`, `title`, `status`, and `detail` fields. Avoid including internal stack details or database error messages in the response body — those belong in server-side logs only.

---

#### Q3 — Design Scenario

**"Design the exception hierarchy for a payments service that handles order lookup failures, payment failures, and validation errors."**

**One-line answer:** Create a common base `PaymentServiceException`, then specific subtypes per failure mode, all extending `RuntimeException`.

> **Full answer to give in an interview:**
>
> "I'd start with a sealed base exception for the service, something like `PaymentServiceException extends RuntimeException`, with the two constructors — message-only, and message-plus-cause. This gives the global handler one catch-all and also lets it catch specific subtypes.
>
> Under that I'd have: `OrderNotFoundException` — carries `orderId`, thrown when an order lookup returns empty; `InsufficientFundsException` — carries `requestedAmount` and `availableBalance`, thrown by the payment processor; and `PaymentValidationException` — carries a list of validation failures, thrown before any processing happens.
>
> Each has the same structure: a domain-specific constructor that builds a readable message, a cause constructor for wrapping lower-level exceptions, and getter methods for the fields. The `@ControllerAdvice` has one `@ExceptionHandler` method per type.
>
> I'd keep them all unchecked unless there's a strong contract reason — like if `InsufficientFundsException` must be handled explicitly by every caller and not just swallowed by a global handler."

*Draw the hierarchy on the whiteboard if available: `RuntimeException → PaymentServiceException → OrderNotFoundException / InsufficientFundsException / PaymentValidationException`.*

**Gotcha follow-up they'll ask:** *"How do you prevent sensitive information leaking in exception messages?"*

> The message in the exception is what gets logged and potentially returned in the API response. For payment amounts and account numbers, I'd include only what's needed for diagnosis — the magnitude of the shortfall, not the full account balance. For entity IDs I'd use the business key, not a database primary key. In the global error handler I'd map exception types to sanitized response bodies, keeping internal detail server-side only.

---

> **Common Mistake — Missing cause constructor:** Omitting `(String message, Throwable cause)` forces callers to use `initCause()` separately, which they routinely forget. This destroys the exception chain and makes production debugging significantly harder.

> **Common Mistake — Sensitive data in messages:** Exception messages can end up in logs, API responses, and error monitoring tools. Never include passwords, full account numbers, or raw SQL in the message text.

> **Common Mistake — Checked exceptions in Spring services:** Extending `Exception` (checked) in a Spring service forces `throws` declarations through every layer and breaks lambdas — use `RuntimeException` and let `@ControllerAdvice` handle it globally.

**Quick Revision (one line):** Custom exceptions extend `RuntimeException` by default, always include a `(message, cause)` constructor, and carry domain fields like `errorCode` and `entityId` for structured API responses.

---

## Topic 17: Exception Chaining

**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Amazon, Google, Oracle, ThoughtWorks

---

### The Idea

Imagine a stack of translators. A database driver speaks SQL; your DAO layer speaks `DataAccessException`; your service layer speaks `OrderServiceException`; your controller speaks HTTP. When the database fails, you don't want the raw SQL error to bubble all the way to the HTTP response — that would expose internal details. But you also don't want to throw away the SQL error entirely, because when you're debugging at 2am, that original stack trace is the only thing that tells you which query failed and why.

Exception chaining solves this. When you catch one exception and throw another, you pass the original exception as the `cause` parameter. Java threads them together. When the final exception is printed, it shows your high-level description first, then "Caused by:" with the original error below it. The full diagnostic chain is preserved, but each layer only exposes its own abstraction to callers.

The mechanism is simple: every exception constructor accepts an optional `Throwable cause`. Pass it. One line. The mistake people make — throwing `new ServiceException(e.getMessage())` instead of `new ServiceException("message", e)` — loses the entire original stack trace. All you get is a string copy of the message, with no indication of where in the codebase the root failure occurred.

### How It Works

```
// Pseudocode: layered architecture exception translation
function DAO.loadOrder(orderId):
    try:
        result = database.query("SELECT * FROM orders WHERE id = ?", orderId)
        return result
    catch SQLException as e:
        throw new DataAccessException("DB query failed for order: " + orderId, e)
        //                                                               ^ original exception preserved as cause

function Service.getOrder(orderId):
    try:
        return DAO.loadOrder(orderId)
    catch DataAccessException as e:
        throw new OrderServiceException("Could not retrieve order: " + orderId, e)
        //                                                              ^ chain continues

// Stack trace you see when the final exception propagates:
// OrderServiceException: Could not retrieve order: ORD-001
//   at Service.getOrder(...)
// Caused by: DataAccessException: DB query failed for order: ORD-001
//   at DAO.loadOrder(...)
// Caused by: java.sql.SQLException: Connection refused
//   at jdbc.Driver.connect(...)
```

**Two ways to attach a cause:**

| Method | When to use |
|---|---|
| Constructor: `new MyException("msg", cause)` | Default — always prefer this. Clean and explicit. |
| `exception.initCause(original)` | Only when working with legacy exception classes that predate Java 1.4 and have no cause constructor. Can only be called once per exception instance. |

**Walking the cause chain programmatically:**

```
// Pseudocode: walk chain to find root cause
function getRootCause(throwable):
    current = throwable
    while current.getCause() is not null:
        current = current.getCause()
    return current   // getCause() returns null at the root
```

The single most interview-critical gotcha — losing the cause by passing only the message:

```java
// BAD — passes only the message string; original stack trace is gone
} catch (SQLException e) {
    throw new DataAccessException(e.getMessage()); // getCause() will return null
}

// GOOD — passes the original exception as cause; full chain preserved
} catch (SQLException e) {
    throw new DataAccessException("Failed to load order: " + orderId, e);
}
```

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is exception chaining and why does it matter?"**

**One-line answer:** Exception chaining attaches the original exception as the `cause` of a new one so the full diagnostic history is preserved across layer boundaries.

> **Full answer to give in an interview:**
>
> "In a layered architecture — say, Controller → Service → DAO → Database — each layer works at a different level of abstraction. The DAO knows about SQL; the service knows about orders; the controller knows about HTTP. When the database fails, you don't want a raw `SQLException` reaching the controller — it exposes database internals and breaks the abstraction.
>
> So the DAO catches the `SQLException` and throws a `DataAccessException`. But if it does `throw new DataAccessException(e.getMessage())`, it only copies the message string — the original `SQLException`, its stack trace, and its stack frames are gone. That's the chain-breaking mistake.
>
> Exception chaining means passing the original exception as the `cause`: `throw new DataAccessException('message', e)`. Java stores the reference. When the exception is printed, you see the new exception first, then 'Caused by: SQLException: ...' below it, with the full original stack trace. You can retrieve the original programmatically via `getCause()`, which walks down the chain returning null when it reaches the root.
>
> In production, this is often the difference between a five-minute fix and a two-hour debugging session."

*The phrase "Caused by:" in a stack trace is the visible sign of correct exception chaining — worth mentioning.*

**Gotcha follow-up they'll ask:** *"What's the difference between `throw new Exception(e)` and `throw new Exception(e.getMessage())`?"*

> `new Exception(e)` wraps the original exception as the cause — `getCause()` returns `e`, the original class name appears in "Caused by:", and the full stack trace is preserved. `new Exception(e.getMessage())` creates a brand-new exception containing only a string copy of the message — `getCause()` returns null, the original exception type is lost, and the original stack trace is gone. In production, the second form makes the root cause nearly impossible to find.

---

#### Q2 — Tradeoff Question

**"When would you use `initCause()` instead of the cause constructor?"**

**One-line answer:** Only when the exception class was written before Java 1.4 and has no constructor that accepts a `Throwable`.

> **Full answer to give in an interview:**
>
> "Java 1.4 standardized exception chaining by adding the `(String message, Throwable cause)` constructor to `Throwable` itself, and all modern exception classes inherit or override it. For any exception you write yourself, always include a cause constructor — that's the clean path.
>
> `initCause()` exists for backward compatibility with legacy exception classes that were written before Java 1.4 and only have constructors accepting a message string. You construct the exception, then call `exception.initCause(originalException)` as a separate step before throwing. Two constraints: it can only be called once per exception instance — calling it a second time throws `IllegalStateException` — and the cause must be set before the exception is thrown.
>
> In modern code, `initCause()` is rare. If you're maintaining legacy exception classes that lack a cause constructor, the right fix is to add one rather than rely on `initCause()` scattered through callers."

*If the interviewer asks about thread safety: `initCause()` is not inherently thread-safe if the exception escapes its constructing thread before being thrown — another reason to prefer the constructor form.*

**Gotcha follow-up they'll ask:** *"Can a cause chain be circular — can exception A be the cause of exception B which is the cause of A?"*

> Technically you could construct one before throwing, but `printStackTrace()` detects circular cause chains and breaks the loop rather than printing forever. In practice, circular chains never occur naturally — you'd have to construct it deliberately. The more practical question is whether the chain can be arbitrarily deep, and yes it can; `getCause()` returns null at the root, which is how you know you've reached the end.

---

#### Q3 — Design Scenario

**"A Spring Boot service calls a third-party payment gateway. The gateway client throws a checked `PaymentGatewayException`. How do you handle it in the service layer?"**

**One-line answer:** Catch it, chain it into a domain-specific unchecked exception, and let the global error handler translate it to an HTTP response.

> **Full answer to give in an interview:**
>
> "The gateway client is an infrastructure concern — its exception type belongs to the client library, not to our domain. Letting it propagate directly would couple the service layer to the library's exception hierarchy, making it hard to swap the gateway later.
>
> In the service method I'd catch `PaymentGatewayException` and throw a `PaymentProcessingException` — our own unchecked exception extending `RuntimeException` — with the gateway exception chained as the cause: `throw new PaymentProcessingException('Payment failed for order: ' + orderId, gatewayException)`. The original gateway exception, its message, and its stack trace are all preserved in the cause chain.
>
> In the `@ControllerAdvice` — Spring's global exception handler — I'd have a method annotated with `@ExceptionHandler(PaymentProcessingException.class)` that returns HTTP 502 or 402 depending on the business context. The full chain is logged with `log.error('Payment failed', e)`, which Logback renders with all Caused-by entries.
>
> This means: the controller knows nothing about the gateway library, the service layer's abstraction is clean, and the full diagnostic chain is in the logs."

*Mention that `log.error("message", e)` — passing the exception object as the second argument — is what triggers SLF4J/Logback to print the full Caused-by chain.*

**Gotcha follow-up they'll ask:** *"What if the gateway exception itself has a cause — how deep does the chain go in the logs?"*

> All the way. Logback and Log4j2 print the entire cause chain, each level indented with "Caused by:". There is no depth limit imposed by the logging framework. In practice, three to four levels is typical in a layered application — framework wrapping → library exception → your domain exception. All levels appear in the log entry when you pass the exception object to the logger.

---

> **Common Mistake — Passing `e.getMessage()` instead of `e`:** This is the single most common chain-breaking mistake. `new ServiceException(e.getMessage())` creates a new exception with a string copy of the message; the original type, the original stack trace, and `getCause()` are all lost.

> **Common Mistake — Not knowing `getCause()` exists:** Many candidates describe exception chaining conceptually but can't name the API. `getCause()` returns the chained cause (or null at the root). Walk it with a while loop to find the root cause.

> **Common Mistake — Letting low-level exceptions surface to the API layer:** A raw `java.sql.SQLException` in an HTTP response body leaks database vendor details. Translate at every layer boundary using exception chaining to preserve diagnostics internally.

**Quick Revision (one line):** Always pass the original exception as the cause — `throw new MyException("msg", e)` not `throw new MyException(e.getMessage())` — so `getCause()` and "Caused by:" in stack traces preserve the full diagnostic chain.

---

## Topic 18: Common Exception Mistakes

**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Stripe, Atlassian, ThoughtWorks

---

### The Idea

Exceptions are one of the areas in Java where well-intentioned code does the most damage. An empty catch block looks harmless — it just means the error is ignored. But the application continues running in a state where something went wrong, no log was written, no alert fired, and no one knows. A batch processor with a single `catch (Exception e) {}` can silently fail to process every record for hours before anyone notices from the business metrics — not from any technical alert.

The common thread in exception mistakes is the tradeoff between convenience and information. Swallowing an exception is convenient — the code compiles, the tests pass. But in production, information is what lets you fix problems. Every exception mistake is fundamentally a choice that trades information away.

There are six patterns that come up repeatedly in interviews and in real codebases, each with a specific consequence: swallowing exceptions (information disappears entirely), catching too broadly (control flow assumptions break), using exceptions for flow control (performance degrades), losing the stack trace (root cause vanishes), using `printStackTrace()` in production (logging infrastructure bypassed), and broad `throws Exception` declarations (the specificity of checked exceptions is defeated).

### How It Works

```
// Pseudocode: the six anti-patterns and their fixes

// ANTI-PATTERN 1: Swallowing — worst
try:
    doSomething()
catch Exception e:
    pass   // silent — application continues in broken state

// FIX: always at minimum log it
try:
    doSomething()
catch Exception e:
    log.error("Failed to do something", e)   // exception object, not e.getMessage()
    // then rethrow or handle gracefully

// ANTI-PATTERN 2: Catching InterruptedException and discarding it
try:
    Thread.sleep(1000)
catch InterruptedException e:
    pass   // interrupt flag is now cleared — thread coordination broken

// FIX: restore the interrupt flag
try:
    Thread.sleep(1000)
catch InterruptedException e:
    Thread.currentThread().interrupt()   // restore the flag so callers can see it
    log.warn("Thread interrupted", e)

// ANTI-PATTERN 3: Exceptions for flow control
try:
    return Integer.parseInt(input)
catch NumberFormatException e:
    return -1   // creating a full stack trace just to return -1 — expensive

// FIX: check before acting
if input is null or not numeric: return -1
return Integer.parseInt(input)

// ANTI-PATTERN 4: Losing the stack trace
catch Exception e:
    throw new ServiceException(e.getMessage())   // original stack trace gone

// FIX: chain it
catch Exception e:
    throw new ServiceException("Failed during load", e)   // cause preserved

// ANTI-PATTERN 5: printStackTrace() in production
catch Exception e:
    e.printStackTrace()   // goes to stderr — may not be captured by the logging framework

// FIX: use the logger
catch Exception e:
    log.error("Operation failed", e)   // SLF4J/Logback appends full stack trace

// ANTI-PATTERN 6: Broad throws declaration
public void process() throws Exception { ... }   // caller must handle all of Exception

// FIX: declare specific types
public void process() throws DataAccessException, ValidationException { ... }
```

**Performance note on exceptions for flow control:**

| Operation | Approximate cost |
|---|---|
| `if/else` branch | Nanoseconds |
| `throw new Exception()` (stack capture) | Microseconds — roughly 1000x slower |

In a tight loop parsing user input, the difference is measurable. Use conditionals for expected cases.

The single most interview-critical gotcha — `InterruptedException` handling:

```java
// This silently breaks thread coordination — the interrupt signal is lost
try {
    Thread.sleep(1000);
} catch (InterruptedException e) {
    // empty or just a log — WRONG
}

// Correct: restore the interrupt flag immediately
try {
    Thread.sleep(1000);
} catch (InterruptedException e) {
    Thread.currentThread().interrupt(); // restore so the caller's interrupt check works
    log.warn("Thread interrupted during sleep", e);
}
```

`InterruptedException` is special because catching it clears the interrupt flag on the current thread. If you swallow it, any code up the call stack that checks `Thread.isInterrupted()` to decide whether to stop working will never see the interrupt. Thread pools, task executors, and graceful shutdown mechanisms all depend on this flag. Clearing it without restoring it is a subtle concurrency bug.

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"What is exception swallowing and why is it the worst exception anti-pattern?"**

**One-line answer:** Exception swallowing means catching an exception and doing nothing — no log, no rethrow — so the application continues in a broken state with zero diagnostic information.

> **Full answer to give in an interview:**
>
> "An empty catch block looks like this: `catch (Exception e) { }` — the braces are empty, or maybe there's a comment. The exception is caught, nothing is recorded, and execution continues on the next line as if nothing happened. From the application's perspective, the failure is invisible.
>
> The consequence depends on what failed. If a database write failed silently, the application continues processing the next record. The data never got written. No alert fires. No log entry exists. Operators only notice when business metrics look wrong hours later — 'why did we process zero payments today?' There is nothing in the logs to point to the cause.
>
> The fix is minimal: at absolute minimum, `log.error('description', e)` — passing the exception object, not `e.getMessage()`. The exception object is what tells SLF4J — the standard Java logging facade — to append the full stack trace including class name, message, and every stack frame. Just the message string loses the type and location.
>
> If you genuinely want to ignore an exception — which is rare but occasionally correct, like ignoring `CloseException` on a connection that's already broken — add a comment explaining why. That comment proves the decision was intentional, not accidental."

*The real-world example lands well: 'legacy batch processor silently failed for hours, operators only noticed from business metrics.'*

**Gotcha follow-up they'll ask:** *"Is `log.error(e.getMessage())` sufficient, or do you need to pass the exception object?"*

> Not sufficient. `log.error(e.getMessage())` logs only a string — the message text. The exception type, the stack trace, and the cause chain are all absent. The correct form is `log.error("description", e)` — with the exception object as the second argument. SLF4J and Logback treat the trailing `Throwable` argument specially: they append the full stack trace and all "Caused by:" entries to the log entry. The difference between these two calls is often the difference between a five-minute fix and an hour of guessing.

---

#### Q2 — Tradeoff Question

**"When is it acceptable to catch `Throwable` or `Exception`? What are the risks?"**

**One-line answer:** Catching `Throwable` is acceptable only at the very top of a thread's execution — like a server request loop — to prevent the thread from dying, and must always log and potentially restart.

> **Full answer to give in an interview:**
>
> "The risk of catching `Throwable` is that it catches everything in Java's hierarchy — including `Error` subclasses like `OutOfMemoryError` and `StackOverflowError`. These are JVM-level failures that indicate the runtime itself is in trouble, not your application code. Catching `OutOfMemoryError` and continuing as if nothing happened can make things worse: you're running in a JVM that can't allocate memory, and any subsequent operation that allocates — which is almost everything in Java — will fail too.
>
> Catching `Exception` is slightly less dangerous but still risky, because it catches `InterruptedException`. `InterruptedException` is thrown when another thread calls `interrupt()` on this thread — typically as a signal to shut down gracefully. Catching it and ignoring it clears the interrupt flag, so the shutdown signal is lost and the thread keeps running when it should stop.
>
> The acceptable uses of broad catches are narrow and deliberate: at the very top of a thread pool worker to log and survive unexpected exceptions without killing the thread; in a framework's top-level request handler where losing a thread would degrade the server; in JUnit test runners that must report and continue even if a test throws an unexpected `Error`. In all these cases: log at ERROR level, and consider whether to restart or alert."

*The `InterruptedException` detail often surprises interviewers — it demonstrates knowing the thread lifecycle.*

**Gotcha follow-up they'll ask:** *"Why is using exceptions for flow control a performance problem?"*

> Creating a `Throwable` in Java captures the full call stack — every method frame from the current point up to the thread's entry point. That stack capture is what makes `new Exception()` orders of magnitude slower than an `if/else` branch. In a method called thousands of times per second to parse user input, using `NumberFormatException` to detect non-numeric strings imposes a measurable performance penalty. The fix is to check first: if the input matches the expected pattern, parse it; otherwise return the default without creating any exception object.

---

#### Q3 — Design Scenario

**"A colleague's code has `catch (Exception e) { throw new ServiceException(e.getMessage()); }`. What are the two problems and how do you fix them?"**

**One-line answer:** It catches too broadly (includes `InterruptedException`) and loses the stack trace by passing only the message string instead of the exception object.

> **Full answer to give in an interview:**
>
> "Two distinct problems here.
>
> First, `catch (Exception e)` catches everything including `InterruptedException`. As I mentioned, `InterruptedException` is thrown by the JVM when another thread signals this thread to stop — catching it and not restoring the interrupt flag silently discards that signal. The thread continues running when it should shut down. The fix is to either catch specific exception types, or to check for `InterruptedException` explicitly and restore the flag with `Thread.currentThread().interrupt()` before rethrowing or continuing.
>
> Second, `new ServiceException(e.getMessage())` creates a new exception containing only a string copy of the original message. The `getCause()` method on this exception returns null. The original exception's type, its stack frames, and any cause it had are all gone. When this appears in logs, you see the `ServiceException` with one stack frame pointing to this catch block — the actual root cause is invisible. The fix is `new ServiceException('context information', e)` — passing the original exception as the cause parameter. Now `getCause()` returns the original, and the log entry shows the full Caused-by chain.
>
> The correct form of this catch block: catch specific exception types, log with the exception object, and chain the original when wrapping."

*Writing out the before/after on a whiteboard is effective here: the one-line change from `e.getMessage()` to `, e` makes the code dramatically more debuggable in production.*

**Gotcha follow-up they'll ask:** *"Is there ever a valid reason to have an empty catch block?"*

> Very rarely. One documented case: catching `InterruptedException` in a context where you cannot propagate or handle it — but only after calling `Thread.currentThread().interrupt()` to restore the flag. Another: suppressing `close()` failures on a resource that's already been processed successfully, where a close exception would be misleading. In both cases, an explanatory comment is mandatory — it signals the decision was deliberate, not an oversight. Without the comment, any reviewer must assume it's a bug.

---

> **Common Mistake — Not restoring the interrupt flag:** `catch (InterruptedException e) { }` clears the interrupt flag. Thread pools, graceful shutdown, and task cancellation all depend on that flag. Clearing it without restoring it with `Thread.currentThread().interrupt()` is a subtle concurrency bug that manifests only under shutdown or cancellation scenarios.

> **Common Mistake — `log.error(e.getMessage())` instead of `log.error("msg", e)`:** The first logs a string with no stack trace. The second tells Logback to append the full stack trace and all Caused-by entries. In production, the stack trace is often the only thing that identifies the source of the problem.

> **Common Mistake — Using `e.printStackTrace()` instead of a logger:** `printStackTrace()` writes to `stderr`. In production, `stderr` may be redirected to a file separate from the application log, aggregated differently by the log shipper, or silently dropped. Use `log.error("message", e)` to ensure the exception appears in the same log stream as everything else.

**Quick Revision (one line):** Never swallow exceptions, always restore the interrupt flag, never use exceptions for flow control, always pass `e` (not `e.getMessage()`) when chaining, and use `log.error("msg", e)` instead of `printStackTrace()`.

---

## Topic 19: Comparison Tables

**Difficulty:** Easy | **Frequency:** High | **Companies:** All

---

### The Idea

Comparison tables exist in interviews because interviewers want to know whether you can reason about tradeoffs quickly. The question "StringBuilder vs StringBuffer" is not really about knowing which class has `synchronized` methods — it is about understanding when thread safety matters, what it costs, and why the default in modern code is almost always the unsynchronized version. The same applies to every table here: the value is not memorizing the cells, it is understanding the reasoning behind each choice.

This section consolidates the comparison knowledge from Chapter 2 into one place. Each table comes with a mental model — the question to ask yourself when you encounter the choice in real code or an interview question.

The tables cover four domains: Strings (immutability, pool, building), Wrapper Classes (autoboxing traps, cache ranges, comparison), Exceptions (hierarchy, checked vs unchecked, common patterns), and String Pool vs Heap allocation (where literals and `new String()` land in memory). A fifth table gives a decision guide for choosing the right exception strategy.

### How It Works

**Mental model for reading these tables:** For each row, ask "when does this choice matter?" Knowing that `StringBuffer` is synchronized is useless without knowing that you'd only reach for it in a legacy multi-threaded context where a shared mutable string is being built — which is almost never the right architecture today.

### Strings

| Topic | Key Point | When it matters |
|---|---|---|
| Immutability | `private final byte[] value` + `byte coder` (Java 9+); no mutating methods | Every `+` on a String creates a new object — matters in loops |
| String Pool | Main heap (since Java 7); GC'd; `intern()` adds a heap string to the pool | Memory optimization for repeated literal strings |
| `==` vs `equals()` | `==` compares references; `equals()` compares content | Always use `equals()` — two `new String("a")` are `==` false |
| StringBuilder | Unsynchronized, fast; single-thread string building | Default for any string construction in a method |
| StringBuffer | Synchronized, slower; rarely needed in modern code | Legacy shared buffers only |
| `substring()` | Copies array since Java 7u6; no more memory leak | No longer a trap in modern JVMs |
| `split()` | Takes a regex; escape `.` as `\\.` | `"a.b".split(".")` returns empty — a common gotcha |
| `strip()` vs `trim()` | `strip()` is Unicode-aware (Java 11+); prefer over `trim()` | Handling international whitespace characters |
| `Integer.parseInt` | Returns `int`; throws `NumberFormatException` on invalid input | Does not handle leading/trailing whitespace |
| `Integer.valueOf` | Returns `Integer` (boxed); uses cache for -128–127 | Repeated calls in range return the same object — `==` is true |

---

### Wrapper Classes

| Topic | Key Point | When it matters |
|---|---|---|
| Autoboxing | `int` → `Integer` via `Integer.valueOf()` — automatic | Overhead in hot loops; unexpected NPE when unboxing null |
| Unboxing | `Integer` → `int` via `intValue()` — automatic | `Integer i = null; int x = i;` throws NullPointerException |
| Integer cache | -128 to 127; `==` works in this range (same object) but is still bad practice | Never use `==` for Integer comparison — use `equals()` or `intValue()` |
| Double/Float cache | No cache; `==` is always reference comparison | `Double.valueOf(1.0) == Double.valueOf(1.0)` is false |
| Comparable | Natural ordering defined inside the class; used by TreeSet/TreeMap | Implement when your class has one obvious ordering |
| Comparator | External, ad-hoc ordering; Java 8 chaining: `thenComparing`, `reversed` | Multiple orderings, or ordering a class you don't own |
| Comparator pitfall | Never subtract ints in a comparator — integer overflow causes wrong results | Use `Integer.compare(a, b)`, never `return a - b` |

---

### Exceptions

| Topic | Key Point |
|---|---|
| Hierarchy | `Throwable` → `Error` + `Exception` → `RuntimeException` |
| Checked | Compiler-enforced; use for recoverable conditions the caller must acknowledge |
| Unchecked | Extends `RuntimeException`; preferred in Spring/functional code |
| `finally` | Always runs (except `System.exit()`); `return` in finally overrides `try` return |
| try-with-resources | Auto-closes in reverse declaration order; `close()` failures become suppressed exceptions |
| Multi-catch | `catch (A \| B e)`; A and B must not be in the same hierarchy; `e` is effectively final |
| Custom exceptions | Extend `RuntimeException`; always include `(String msg, Throwable cause)` constructor |
| Exception chaining | Pass `e` not `e.getMessage()`; walk chain with `getCause()` |
| Swallowing | Worst anti-pattern; always at minimum log with `log.error("msg", e)` |
| InterruptedException | MUST restore interrupt flag: `Thread.currentThread().interrupt()` |

---

### String Pool vs Heap

| Scenario | Location | Pool Reference? |
|---|---|---|
| `String s = "hello"` | String pool (inside heap, since Java 7) | Yes |
| `String s = new String("hello")` | Heap (new object every time) | No |
| `"hel" + "lo"` (compile-time constant fold) | Pool | Yes — compiler folds at compile time |
| `"hel" + variable` (runtime concatenation) | Heap | No — built at runtime |
| `s.intern()` on a heap string | Returns the pool reference | Yes — adds to pool if absent |

*Why this matters in interviews:* `new String("hello") == "hello"` is false. `"hello" == "hello"` is true (same pool object). `"hel" + "lo" == "hello"` is true (compile-time fold). These three cases test whether you understand the pool mechanism.

---

### StringBuilder vs StringBuffer vs String

| | String | StringBuilder | StringBuffer |
|---|---|---|---|
| Mutable | No | Yes | Yes |
| Thread-safe | Yes (immutable) | No | Yes (synchronized methods) |
| Performance | New object per mutation | Best — no lock overhead | Medium — lock overhead per call |
| Since | Java 1.0 | Java 1.5 | Java 1.0 |
| Use for | Constants, map keys, parameters | Single-thread string building (default) | Legacy shared buffers only |

*The interview answer:* "In virtually all modern code I'd use `StringBuilder`. `StringBuffer` exists for legacy reasons — if you're sharing a mutable string builder across threads, the architecture is usually wrong; build the string in one thread and share the immutable result."

---

### Exception Decision Guide

| Situation | Recommendation | Reason |
|---|---|---|
| Caller must acknowledge failure | Checked Exception | Compiler enforces handling |
| Programming bug (null arg, bad state) | Unchecked (`IllegalArgumentException`, etc.) | Bugs should not be caught — they should be fixed |
| Business rule violation | Custom `RuntimeException` | Domain-specific, global handler maps to HTTP code |
| Cross-layer exception translation | Chain with cause (`new MyEx("msg", e)`) | Preserves diagnostic chain, hides implementation detail |
| Use in lambdas or streams | Unchecked (or `UncheckedIOException`) | Functional interfaces cannot declare checked exceptions |
| Spring service/DAO layer | `RuntimeException` (`DataAccessException` pattern) | Global handler manages response; no `throws` pollution |
| JVM or system failure | `Error` — do not catch | JVM state is undefined; catching makes it worse |

### Interview Lens

> **How to use this section:** Each question below is self-contained. You can read just this section the night before an interview and walk in prepared. Every concept referenced is explained inline — no need to flip back.

> *Tip: In a real interview, lead with the one-line answer first. Pause. Expand only if the interviewer nods or probes.*

---

#### Q1 — Concept Check

**"When would you use `StringBuffer` over `StringBuilder` in modern Java?"**

**One-line answer:** Almost never — `StringBuffer` exists for legacy multi-threaded contexts; in modern code, build strings in a single thread with `StringBuilder` and share the immutable result.

> **Full answer to give in an interview:**
>
> "The difference is that every method in `StringBuffer` is `synchronized`, meaning only one thread can execute any of its methods at a time. `StringBuilder` has identical methods but no synchronization.
>
> The synchronization in `StringBuffer` was designed for scenarios where multiple threads share a mutable string buffer — each thread appending characters concurrently. In practice, this design is usually wrong: a shared mutable buffer under concurrent modification still requires careful coordination to produce a meaningful result even with synchronization, because the order of appends is non-deterministic.
>
> In modern code, the correct pattern is: each thread builds its own string with `StringBuilder` — fast, no contention — and produces an immutable `String` result when done. Strings are immutable and inherently thread-safe, so the result can be shared freely. `StringBuffer` only appears in legacy code written before Java 5, when `StringBuilder` didn't exist. I'd use `StringBuilder` by default and reach for `StringBuffer` only if I'm maintaining code that already uses it and refactoring is out of scope."

*Mentioning Java 5 as the `StringBuilder` introduction date is a detail that signals depth.*

**Gotcha follow-up they'll ask:** *"What is the Integer cache and when does it cause bugs?"*

> Java caches `Integer` objects for values from -128 to 127. When you call `Integer.valueOf(100)` — including via autoboxing — you get back the same cached object every time. So `Integer.valueOf(100) == Integer.valueOf(100)` is `true`. But `Integer.valueOf(200) == Integer.valueOf(200)` is `false` — two different objects. The bug pattern is comparing `Integer` variables with `==` instead of `.equals()`. Below 128 it works by accident; above 127 it silently returns the wrong result. The rule is: never use `==` to compare `Integer` objects — always use `.equals()` or unbox with `intValue()`.

---

#### Q2 — Tradeoff Question

**"When should you use a checked exception vs an unchecked exception?"**

**One-line answer:** Use checked when the caller must be forced to acknowledge the failure; use unchecked for everything else, especially in Spring or functional code.

> **Full answer to give in an interview:**
>
> "The distinction is about who is responsible for handling the failure and whether the compiler should enforce that responsibility.
>
> Checked exceptions — those that extend `Exception` but not `RuntimeException` — are enforced by the Java compiler: every method that can throw one must either catch it or declare `throws` in its signature. The intent is to make the failure visible at every layer and force callers to have a plan. The textbook use case is `IOException` — a file operation that may fail due to disk errors. The caller should decide whether to retry, use a fallback, or abort.
>
> Unchecked exceptions — extending `RuntimeException` — propagate freely without any `throws` declaration. They're appropriate for programming errors (`NullPointerException`, `IllegalArgumentException`), business rule violations (`OrderNotFoundException`), and any exception used in Spring services where a `@ControllerAdvice` global handler is responsible for the response. They also work cleanly in lambdas, which cannot declare checked exceptions.
>
> The modern default in most enterprise Java is unchecked. Spring's own `DataAccessException` hierarchy made the switch from checked to unchecked deliberately because forcing every DAO caller to declare `throws DataAccessException` added ceremony without safety. I follow the same pattern: unchecked by default, checked only where the compiler forcing acknowledgement genuinely improves correctness."

*The Spring `DataAccessException` example is a real historical design decision — it demonstrates knowing why, not just what.*

**Gotcha follow-up they'll ask:** *"What does `return` in a `finally` block do?"*

> It overrides the return value from the `try` block — and also suppresses any exception that was in flight. If `try` returns 1 and `finally` returns 2, the method returns 2. If `try` throws an exception and `finally` returns a value, the exception is silently discarded and the method returns normally. This is a trap: `finally` should be used for cleanup — closing resources, resetting state — never for returning values. Modern code uses try-with-resources instead of explicit `finally` for resource cleanup.

---

#### Q3 — Design Scenario

**"A code review shows `new String("hello")` used as a map key throughout a service. What is the problem and what would you change?"**

**One-line answer:** `new String("hello")` creates a new heap object on every call — `equals()` still works for `HashMap` lookup, but it bypasses the string pool and creates unnecessary garbage.

> **Full answer to give in an interview:**
>
> "For `HashMap` correctness, this actually works fine — `HashMap` uses `equals()` and `hashCode()` for key lookup, not reference equality, and `String.equals()` compares content. So `map.get(new String('hello'))` will find an entry keyed by `'hello'`.
>
> The problem is efficiency and intent. `new String('hello')` creates a new `String` object on the heap every time it is called — it bypasses the string pool entirely. The string pool, maintained in the heap since Java 7, returns the same object for equal string literals, so `'hello' == 'hello'` is true because they point to the same pooled instance. `new String('hello')` explicitly opts out of this. In a hot path — a method called thousands of times per second — creating and discarding `String` objects adds garbage collection pressure.
>
> The fix is to use string literals directly: `'hello'` instead of `new String('hello')`. If the string comes from a runtime source — a parsed field, a network payload — it's already a new heap object and `new String(...)` is never needed to wrap it. The `new String(char[])` constructor has a legitimate use when you want to copy a character array and discard the original for security reasons — like zeroing a password buffer — but that's a narrow special case."

*The security use case — zeroing char arrays after password use — is a detail that signals real-world experience.*

**Gotcha follow-up they'll ask:** *"What is the `Comparator` subtraction pitfall and why does it cause bugs?"*

> Writing `return a - b` in a comparator for integers looks correct — it returns negative, zero, or positive as required. But if `a` is large positive and `b` is large negative, `a - b` overflows the 32-bit integer range and returns a negative number — reversing the intended order. The comparator silently produces wrong sort results for large values near `Integer.MAX_VALUE` or `Integer.MIN_VALUE`. The fix is `Integer.compare(a, b)` — a static method that handles the comparison without arithmetic, guaranteed to be correct for all int values.

---

> **Common Mistake — Using `==` to compare `Integer` objects:** Works for values -128 to 127 due to the cache, fails silently above 127. Always use `.equals()` or `intValue()`.

> **Common Mistake — `return` in `finally`:** Overrides the `try` return and silently swallows exceptions. Use `finally` only for cleanup, never for return values.

> **Common Mistake — Subtraction in Comparator:** `return a - b` overflows for extreme values. Use `Integer.compare(a, b)`.

**Quick Revision (one line):** Key tradeoffs: `StringBuilder` over `StringBuffer` (no sync needed), `equals()` over `==` for all wrappers, unchecked exceptions by default in Spring, and `Integer.compare()` over subtraction in comparators.

---

*End of Chapter 2: Strings, Wrappers & Exceptions*

