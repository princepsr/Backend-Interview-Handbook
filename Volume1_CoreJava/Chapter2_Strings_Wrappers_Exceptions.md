# Chapter 2: Strings, Wrapper Classes, and Exceptions

**Volume 1 — Core Java | Java 17 LTS Baseline**
**Target: SDE2 Candidates (2–5 Years Experience) | FAANG+, FinTech, SaaS/Enterprise**

---

## Table of Contents

1. [String Immutability](#1-string-immutability)
2. [String Pool and Interning](#2-string-pool-and-interning)
3. [String Comparison](#3-string-comparison)
4. [StringBuilder vs StringBuffer](#4-stringbuilder-vs-stringbuffer)
5. [Key String Methods](#5-key-string-methods)
6. [String-to-int Conversions](#6-string-to-int-conversions)
7. [Autoboxing and Unboxing](#7-autoboxing-and-unboxing)
8. [Integer Cache (-128 to 127)](#8-integer-cache--128-to-127)
9. [Null Unboxing NullPointerException](#9-null-unboxing-nullpointerexception)
10. [Comparable vs Comparator](#10-comparable-vs-comparator)
11. [Exception Hierarchy](#11-exception-hierarchy)
12. [Checked vs Unchecked Exceptions](#12-checked-vs-unchecked-exceptions)
13. [try-catch-finally Execution Order](#13-try-catch-finally-execution-order)
14. [try-with-resources](#14-try-with-resources)
15. [Multi-catch](#15-multi-catch)
16. [Custom Exceptions](#16-custom-exceptions)
17. [Exception Chaining](#17-exception-chaining)
18. [Common Exception Mistakes](#18-common-exception-mistakes)
19. [Comparison Tables](#19-comparison-tables)

---

## 1. String Immutability

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Google, Amazon, Microsoft, Goldman Sachs, Morgan Stanley, Flipkart, Atlassian

---

### Short Interview Answer (30–60 seconds)

String is immutable in Java because its internal character array is declared `private final`, and the class itself is `final` so it cannot be subclassed. This design enables safe sharing of String objects across threads without synchronization, allows the JVM to cache strings in the String Pool, and makes strings safe to use as HashMap keys or in security-sensitive contexts like class loading and network URLs.

---

### Deep Explanation

**Internal representation before and after Java 9:**

Before Java 9, String stored data as `private final char[] value` — each character occupied 2 bytes (UTF-16). Java 9 introduced **Compact Strings** (JEP 254): the backing store changed to `private final byte[] value` with a companion `private final byte coder` field. If all characters fit in Latin-1 (ISO-8859-1), the coder is `LATIN1` (1 byte per char). Otherwise it falls back to `UTF16` (2 bytes per char). This cuts memory by roughly 50% for typical ASCII workloads.

```
// Java 17 internals (simplified from OpenJDK source)
public final class String implements Serializable, Comparable<String>, CharSequence {
    private final byte[] value;
    private final byte coder;   // LATIN1 = 0, UTF16 = 1
    private int hash;           // cached hashCode, lazily computed
    // ...
}
```

**Why immutability matters — four concrete reasons:**

1. **String Pool / caching:** The JVM can safely hand out the same object to multiple variables because nobody can mutate it.
2. **Thread safety:** No synchronization is needed when sharing strings across threads.
3. **HashCode caching:** `hashCode()` is computed once and cached in the `hash` field. HashMap lookups on String keys are fast.
4. **Security:** Class names, file paths, database URLs, passwords in transit — none of these can be altered by rogue code after creation.

**What "immutable" actually means:**

The `value` array reference is `final` (the reference cannot be reassigned), and the array itself is not exposed. There is no method on String that modifies `value`. Even `substring()` creates a new String object backed by a new array (post Java 7u6 — more on this in section 5).

---

### Real-World Backend Example

A REST API reads a database connection URL from environment variables and passes it to multiple beans during application startup. Because String is immutable, any bean that receives the URL string cannot accidentally corrupt it. If String were mutable (like StringBuilder), a poorly written bean could call something like `url.setCharAt(0, 'x')` and break every other bean sharing that reference.

---

### Java 17 Code Example

```java
public class StringImmutabilityDemo {

    public static void main(String[] args) {
        String original = "jdbc:postgresql://localhost:5432/mydb";

        // "Modifying" a string always produces a new object
        String modified = original.replace("localhost", "prod-db.internal.com");

        System.out.println(original);   // jdbc:postgresql://localhost:5432/mydb  (unchanged)
        System.out.println(modified);   // jdbc:postgresql://prod-db.internal.com:5432/mydb
        System.out.println(original == modified); // false — different objects

        // Compact strings: all-ASCII string uses 1 byte per char internally
        // No direct API to observe coder, but memory footprint is halved
        String ascii  = "hello";   // coder = LATIN1
        String greek  = "αβγδ";    // coder = UTF16

        // hashCode is cached after first call
        int h1 = original.hashCode();
        int h2 = original.hashCode(); // reads cached value, no recomputation
        System.out.println(h1 == h2); // true
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "If String is immutable, why does `hashCode()` have a non-final field `hash`?" — It is lazily initialized (0 until first call). This is a benign data race: the worst case is computing the same hash twice, but since the result is deterministic, correctness is never violated.
- "Can you make String mutable using reflection?" — Yes, technically, by accessing the private `value` array via `Field.setAccessible(true)`. This breaks the contract, corrupts the String Pool, and causes undefined behavior. Interviewers ask this to see if you know the difference between enforcing immutability via the type system vs. via security managers.
- "What is a String intern() and how does compact strings affect the pool?"

---

### Common Mistakes Candidates Make

- Confusing immutability with the variable being `final`. A `final String s` means the variable cannot be reassigned; the String itself is immutable regardless.
- Saying the internal array is `char[]` — it has been `byte[]` since Java 9.
- Claiming String is immutable "so it's synchronized" — there is no synchronization; it's safe because there is nothing to synchronize (no mutable state).

---

### Interview Traps

**Trap:** "Is `String s = new String("hello")` the same object as `"hello"` in the pool?"
Answer: No. `new String(...)` always allocates a new object on the heap. It does not reference the pool entry. Use `s.intern()` to get the canonical pool reference.

---

### Quick Revision Notes

- String is `final`, backed by `private final byte[] value` + `byte coder` (Java 9+ compact strings).
- Immutability enables String Pool, hashCode caching, thread safety, and security.
- `new String("x")` creates a heap object distinct from the pool literal `"x"`.
- `hash` field is lazily set — benign data race, safe due to determinism.

---

## 2. String Pool and Interning

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Adobe, PayPal, Walmart Labs, Deutsche Bank

---

### Short Interview Answer (30–60 seconds)

The String Pool is a region inside the heap (moved from PermGen to the main heap in Java 7) where the JVM stores one canonical copy of each string literal. When you write `String s = "hello"`, the JVM checks the pool first; if "hello" already exists there, it returns the existing reference. `String.intern()` lets you manually add a string to the pool and get back the canonical reference.

---

### Deep Explanation

**Historical location:**

- Before Java 7: String Pool lived in PermGen (Permanent Generation), a fixed-size memory region. Large applications could hit `OutOfMemoryError: PermGen space` from too many interned strings.
- Java 7+: Pool moved to the main heap. It is now garbage collected like any other object. This makes it safe to intern more strings without risking PermGen exhaustion.
- Java 8: PermGen was removed entirely, replaced by Metaspace (native memory).

**How the pool works:**

The pool is implemented as a hash table inside the JVM (a `StringTable`). Each entry is a weak reference to a String object on the heap. When the referent is no longer reachable from application code and the GC runs, the entry is removed.

**When two literals share the same reference:**

The Java Language Specification guarantees that string literals with the same content are interned — they point to the same object. The compiler emits one constant pool entry per unique string literal, and the JVM ensures they map to one pool entry.

```java
String a = "hello";
String b = "hello";
System.out.println(a == b); // true — same pool entry
```

**When they do NOT share the same reference:**

```java
String c = new String("hello");   // explicit heap allocation
String d = "hel" + new String("lo"); // right side is not a compile-time constant
System.out.println(a == c); // false
System.out.println(a == d); // false
```

Compile-time constant folding: `"hel" + "lo"` (both literals) is folded by `javac` to `"hello"` and resolves to the pool entry. `"hel" + variable` is not folded and produces a new heap String.

**`intern()` mechanics:**

`intern()` looks up the string in the pool. If found, returns the pool reference. If not found, adds the string to the pool and returns the same reference. Calling `intern()` on a string literal is a no-op (it is already in the pool).

---

### Real-World Backend Example

A high-throughput event processing service reads millions of event type codes (e.g., "ORDER_PLACED", "PAYMENT_FAILED") from Kafka. Each event object holds a `String eventType`. Without interning, each Kafka message deserialization allocates a new String on the heap. With `eventType = eventType.intern()`, all objects sharing the same event type code share one String instance, dramatically reducing GC pressure.

---

### Java 17 Code Example

```java
public class StringPoolDemo {

    public static void main(String[] args) {
        // Literals — same pool reference
        String s1 = "order_placed";
        String s2 = "order_placed";
        System.out.println(s1 == s2);           // true

        // Explicit heap allocation
        String s3 = new String("order_placed");
        System.out.println(s1 == s3);           // false
        System.out.println(s1.equals(s3));      // true

        // intern() returns pool canonical reference
        String s4 = s3.intern();
        System.out.println(s1 == s4);           // true

        // Compile-time constant folding
        final String prefix = "order";
        String s5 = prefix + "_placed";         // constant, folded at compile time
        System.out.println(s1 == s5);           // true — compiler folds to "order_placed"

        // Non-constant concatenation — no folding
        String prefix2 = "order";               // not final
        String s6 = prefix2 + "_placed";
        System.out.println(s1 == s6);           // false

        // High-throughput intern pattern for event codes
        String fromKafka = new String("ORDER_PLACED"); // simulates deserialization
        String canonical = fromKafka.intern();
        System.out.println(canonical == "ORDER_PLACED"); // true — pool entry
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "What are the risks of over-using `intern()`?" — Filling the StringTable with low-reuse strings wastes memory and increases GC work for weak reference sweeping.
- "Can the String Pool cause memory leaks in Java 7+?" — Much less likely than pre-Java 7, but interning large volumes of unique strings still wastes heap space.
- "What JVM flag controls the size of the String Pool?" — `-XX:StringTableSize` (default 65536 buckets in older JVMs, 1,000,003 in Java 11+).

---

### Common Mistakes Candidates Make

- Saying the pool is in PermGen (true only before Java 7).
- Saying `==` on string literals is "unreliable" — it is actually guaranteed by the JLS for literals.
- Not knowing that `final` String variables participate in compile-time constant folding.

---

### Interview Traps

**Trap:** `String s = "a" + "b" + "c"` — how many String objects are created?
Answer: One. The compiler folds all-literal concatenation at compile time. Only the final `"abc"` exists in the pool.

**Trap:** `String s = new String("abc")` — how many?
Answer: One or two. If `"abc"` is already in the pool (e.g., the literal appeared elsewhere), only the heap object is new. If this is the first encounter of `"abc"`, the pool entry is also created — so potentially two.

---

### Quick Revision Notes

- Pool lives on the heap since Java 7 (PermGen before).
- String literals with same content share one pool reference; `new String(...)` does not.
- `intern()` adds to pool and returns canonical reference.
- Compile-time constant folding applies to `final` String variables and all-literal concatenation.
- Control pool size via `-XX:StringTableSize`.

---

## 3. String Comparison

**Difficulty:** Easy | **Interview Frequency:** Very High

**Companies:** Every company — this is the most common Java screening question.

---

### Short Interview Answer (30–60 seconds)

Use `.equals()` to compare String content — it compares character by character. `==` compares object references (addresses in memory), which only happens to work for pool-interned literals by coincidence. `.compareTo()` returns a negative, zero, or positive integer and is used for lexicographic ordering — for example, when sorting.

---

### Deep Explanation

**`==` operator:**
Compares two references. Returns `true` only if both variables point to the exact same object. For String literals from the same pool entry, this happens to be `true` — but relying on it is fragile.

**`.equals()` method:**
Overridden in String to compare content. Implementation: checks reference equality first (fast path), then checks length, then compares `byte[]` contents. O(n) in the worst case.

**`.compareTo()` method:**
Implements `Comparable<String>`. Returns: negative if this string is lexicographically less than the argument, 0 if equal, positive if greater. Under the hood: compares the `byte[]` arrays element by element, returning the difference of the first differing characters.

**`.equalsIgnoreCase()` and `.compareToIgnoreCase()`:**
Case-insensitive variants. Important for username lookups, case-insensitive API parameters.

**`Objects.equals(a, b)`:**
Null-safe. Returns `true` if both are null, `false` if exactly one is null, otherwise delegates to `a.equals(b)`. Essential in service/DAO layers where strings may be null.

---

### Real-World Backend Example

A user authentication service compares usernames coming from HTTP requests. Using `==` would occasionally work for common names due to pool interning but would silently fail for names built dynamically from a request body. Using `.equals()` or `Objects.equals()` is always correct.

---

### Java 17 Code Example

```java
import java.util.Objects;

public class StringComparisonDemo {

    public static void main(String[] args) {
        String a = "admin";
        String b = "admin";
        String c = new String("admin");
        String d = null;

        // Reference comparison
        System.out.println(a == b);           // true  — same pool entry
        System.out.println(a == c);           // false — c is a new heap object
        System.out.println(a.equals(c));      // true  — same content

        // NullPointerException risk
        // System.out.println(d.equals(a));   // NPE — never call equals on potentially null

        // Safe patterns
        System.out.println(a.equals(d));      // false — no NPE (a is not null)
        System.out.println(Objects.equals(a, d)); // false — null-safe
        System.out.println(Objects.equals(d, d)); // true  — both null

        // Lexicographic ordering
        System.out.println("apple".compareTo("banana")); // negative (a < b)
        System.out.println("banana".compareTo("apple")); // positive
        System.out.println("apple".compareTo("apple"));  // 0

        // Case-insensitive comparison in auth service
        String inputUsername = "ADMIN";
        boolean match = inputUsername.equalsIgnoreCase(a);
        System.out.println(match); // true

        // Sorting strings
        java.util.List<String> roles = new java.util.ArrayList<>(
            java.util.List.of("USER", "ADMIN", "MODERATOR"));
        java.util.Collections.sort(roles); // uses compareTo
        System.out.println(roles); // [ADMIN, MODERATOR, USER]
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "When would you ever use `==` for Strings?" — Almost never in application code. Possibly in a custom String interning utility where you explicitly need reference identity.
- "What does `compareTo` return for `"abc".compareTo("abd")`?" — -1 (difference of 'c' - 'd' = -1).
- "How is `String.equals()` implemented — is it O(1)?" — No, O(n). First checks reference equality (O(1) fast path), then length (O(1)), then character-by-character.

---

### Common Mistakes Candidates Make

- Using `==` in any business logic string comparison.
- Calling `.equals()` on the possibly-null variable: `userInput.equals("expected")` — NPE if `userInput` is null. Put the literal first or use `Objects.equals()`.
- Forgetting that `compareTo` is case-sensitive by default.

---

### Interview Traps

**Trap:** `"hello" == "hel" + "lo"` — true or false?
Answer: True. Both sides are compile-time constants. `javac` folds `"hel" + "lo"` to `"hello"`, which hits the same pool entry.

**Trap:** What does `"b".compareTo("a")` return?
Answer: 1 (ASCII value of 'b' minus ASCII value of 'a' = 98 - 97 = 1).

---

### Quick Revision Notes

- `==` compares references; `.equals()` compares content.
- Never call `.equals()` on a potentially null variable — use `Objects.equals()` or put the literal on the left.
- `compareTo()` returns <0, 0, or >0 for lexicographic ordering.
- `"lit" + "eral"` is compile-time folded; `"lit" + variable` is not.

---

## 4. StringBuilder vs StringBuffer

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Microsoft, Infosys, TCS, Cognizant, Accenture

---

### Short Interview Answer (30–60 seconds)

StringBuilder and StringBuffer both provide mutable character sequences. StringBuffer is synchronized — every method is `synchronized`, making it thread-safe but slower due to lock overhead. StringBuilder is unsynchronized and faster. In modern code, StringBuilder is almost always preferred because string building operations are typically confined to a single thread. StringBuffer is only justified in rare legacy scenarios where a buffer is shared across threads.

---

### Deep Explanation

**Why string concatenation in loops is bad:**

Consider:
```java
String result = "";
for (String s : list) {
    result = result + s;
}
```

Each `+` operation creates a new String object (strings are immutable). With n strings, you create O(n) intermediate String objects. The compiler does NOT optimize this across loop iterations.

The compiler does optimize a single-statement concatenation: `String s = "a" + "b" + "c"` becomes one `StringBuilder` chain. But inside a loop, the compiler creates a **new** StringBuilder on every iteration:

```
// Bytecode equivalent of result = result + s in a loop body:
result = new StringBuilder(result).append(s).toString();
```

So n iterations = n new StringBuilder objects + n new String objects.

**StringBuilder internals:**

StringBuilder wraps a `char[]` (or `byte[]` with compact strings internally) with a capacity. Default initial capacity is 16. When capacity is exceeded, it grows to `(current * 2) + 2`. Growth involves array copy. Amortized O(1) append.

**StringBuffer vs StringBuilder:**

| | StringBuffer | StringBuilder |
|---|---|---|
| Introduced | Java 1.0 | Java 1.5 |
| Synchronization | Every method is `synchronized` | None |
| Thread safety | Yes | No |
| Performance | Slower (lock acquire/release) | Faster |
| Use case | Legacy, shared mutable buffer | Single-thread string building |

**Java 9+ optimization — String concatenation with `invokedynamic`:**

Java 9 introduced JEP 280: string concatenation no longer uses `StringBuilder` at the bytecode level. It uses `invokedynamic` with `StringConcatFactory`, which the JIT can optimize differently (e.g., pre-size a single buffer for the entire expression). This makes simple concatenations faster but does NOT fix the loop problem — each loop iteration still incurs allocation.

---

### Real-World Backend Example

Building a dynamic SQL query in a DAO layer or constructing a large JSON string manually (before switching to Jackson). A loop over filter criteria appending clauses must use StringBuilder to avoid O(n²) string allocation.

---

### Java 17 Code Example

```java
import java.util.List;

public class StringBuilderDemo {

    // BAD: O(n^2) allocations
    public static String buildQueryBad(List<String> conditions) {
        String query = "SELECT * FROM orders WHERE ";
        for (String condition : conditions) {
            query = query + condition + " AND "; // new String on every iteration
        }
        return query;
    }

    // GOOD: O(n) with StringBuilder
    public static String buildQueryGood(List<String> conditions) {
        StringBuilder sb = new StringBuilder("SELECT * FROM orders WHERE ");
        for (int i = 0; i < conditions.size(); i++) {
            sb.append(conditions.get(i));
            if (i < conditions.size() - 1) {
                sb.append(" AND ");
            }
        }
        return sb.toString();
    }

    // GOOD: StringJoiner / String.join — even cleaner for this case
    public static String buildQueryClean(List<String> conditions) {
        return "SELECT * FROM orders WHERE " + String.join(" AND ", conditions);
    }

    public static void main(String[] args) {
        List<String> conditions = List.of(
            "status = 'PENDING'", "amount > 1000", "region = 'APAC'");

        System.out.println(buildQueryGood(conditions));

        // StringBuilder capacity growth demo
        StringBuilder sb = new StringBuilder(); // capacity = 16
        for (int i = 0; i < 50; i++) {
            sb.append('x'); // grows automatically: 16 -> 34 -> 70 -> ...
        }
        System.out.println("length=" + sb.length()); // 50

        // StringBuffer — thread-safe but rarely needed
        StringBuffer buf = new StringBuffer();
        buf.append("thread-safe");
        System.out.println(buf.toString());
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "Does Java 9's `invokedynamic` concatenation eliminate the need for StringBuilder in loops?" — No. It optimizes single-expression concatenation but not loop bodies.
- "What is the initial capacity of StringBuilder and how does it grow?" — 16 characters; grows to `(capacity * 2) + 2` on overflow.
- "Can you make StringBuilder thread-safe without using StringBuffer?" — Yes: wrap the StringBuilder access in a `synchronized` block, or use a `ThreadLocal<StringBuilder>` per thread.

---

### Common Mistakes Candidates Make

- Saying "the compiler always optimizes string concatenation to StringBuilder" — it does so only for single-statement expressions, not across loop iterations.
- Recommending StringBuffer in new code without a specific thread-safety requirement.
- Not calling `.toString()` when passing the StringBuilder result to another API.

---

### Interview Traps

**Trap:** "If I write `String s = "a" + "b" + "c" + "d"` in Java 9+, does it use StringBuilder?"
Answer: No. Java 9+ uses `invokedynamic`/`StringConcatFactory`, not `StringBuilder`. But this is a JIT/bytecode detail — for the interview, the key point is that all-literal concatenation is optimized; loop concatenation is not.

---

### Quick Revision Notes

- String concatenation in loops is O(n²) — use StringBuilder.
- StringBuilder: unsynchronized, fast, single-thread use.
- StringBuffer: synchronized, slower, legacy.
- Default StringBuilder capacity is 16; grows by `(cap * 2) + 2`.
- Java 9+ uses `invokedynamic` for expression concatenation, not StringBuilder.

---

## 5. Key String Methods

**Difficulty:** Easy–Medium | **Interview Frequency:** High

**Companies:** Amazon, Google, Walmart, Booking.com, Razorpay

---

### Short Interview Answer (30–60 seconds)

The most interview-critical String methods are `substring()`, `split()`, `charAt()`, `indexOf()`, `replace()`, `format()`, and `join()`. The historical trap is the pre-Java 7u6 `substring()` memory leak — it shared the original backing array. Since Java 7u6, `substring()` copies the chars, so no leak.

---

### Deep Explanation

**`substring(int beginIndex, int endIndex)` — the memory leak story:**

Before Java 7u6 (update 6), String stored a `char[]` plus an `offset` and `count`. `substring()` returned a new String that shared the original `char[]`, with different `offset`/`count`. This meant a 1-character substring of a 100MB string kept the entire 100MB array alive. The fix: Java 7u6 made `substring()` copy the relevant portion into a new array. No more leak.

**`split(String regex)`:**

Takes a regular expression, not a plain string. Common pitfall: `"192.168.1.1".split(".")` returns an empty array because `.` is a regex metacharacter matching any character. Use `"\\."` or `Pattern.quote(".")`.

**`charAt(int index)`:**

O(1). Throws `StringIndexOutOfBoundsException` if index < 0 or >= length().

**`indexOf(String str)` / `lastIndexOf(String str)`:**

Returns -1 if not found. Runs in O(n * m) naive implementation (Java uses Boyer-Moore-Horspool internally for long patterns).

**`replace(CharSequence target, CharSequence replacement)`:**

Literal string replacement (not regex). `replaceAll()` uses regex — beware performance with complex patterns.

**`String.format(String format, Object... args)`:**

Internally uses `java.util.Formatter`. Slower than StringBuilder for high-throughput logging because it allocates a Formatter, a StringBuilder, and the result String. Prefer structured logging frameworks in production.

**`String.join(CharSequence delimiter, CharSequence... elements)` (Java 8+):**

Clean, readable alternative to manual StringBuilder joins. Delegates to `StringJoiner`.

**`strip()` vs `trim()` (Java 11):**

`trim()` removes characters <= U+0020 (ASCII space). `strip()` uses `Character.isWhitespace()` — Unicode-aware. Prefer `strip()` for user input.

**`isBlank()` (Java 11):**

Returns true if string is empty or contains only whitespace. Equivalent to `s.strip().isEmpty()` but more efficient.

**`repeat(int count)` (Java 11):**

`"ab".repeat(3)` returns `"ababab"`.

**`lines()` (Java 11):**

Returns a `Stream<String>` of lines, splitting on `\n`, `\r`, or `\r\n`.

---

### Real-World Backend Example

Parsing a CSV line in a data import pipeline: `split(",")` works for simple cases but breaks on quoted fields containing commas. Real parsers use libraries, but for interviews the key is knowing `split()` takes a regex. Parsing an IP address: `"192.168.1.1".split("\\.")`.

---

### Java 17 Code Example

```java
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

public class StringMethodsDemo {

    public static void main(String[] args) {
        // substring — copies since Java 7u6
        String url = "https://api.example.com/v1/orders";
        String path = url.substring(url.indexOf("/v1")); // "/v1/orders"
        System.out.println(path);

        // split — regex trap
        String ip = "192.168.1.1";
        String[] parts = ip.split("\\.");   // correct
        System.out.println(Arrays.toString(parts)); // [192, 168, 1, 1]

        String[] wrong = ip.split(".");     // "." matches any char — empty result
        System.out.println(wrong.length);   // 0

        // charAt
        String eventType = "ORDER_PLACED";
        System.out.println(eventType.charAt(0)); // 'O'

        // indexOf
        int idx = eventType.indexOf('_');
        System.out.println(idx);             // 5
        System.out.println(eventType.indexOf("MISSING")); // -1

        // replace vs replaceAll
        String masked = "4111-1111-1111-1111".replace("-", "");
        System.out.println(masked); // 4111111111111111

        // format — use for readability in logging, not hot paths
        String log = String.format("User %s performed %s on resource %d", "alice", "DELETE", 42);
        System.out.println(log);

        // join
        List<String> permissions = List.of("READ", "WRITE", "EXECUTE");
        String joined = String.join(", ", permissions);
        System.out.println(joined); // READ, WRITE, EXECUTE

        // Java 11 additions
        String input = "  \t Hello World \n  ";
        System.out.println(input.strip());      // "Hello World"
        System.out.println("   ".isBlank());    // true
        System.out.println("ab".repeat(3));     // ababab

        // lines() for multiline payloads
        String csv = "name,age\nAlice,30\nBob,25";
        csv.lines()
           .skip(1) // skip header
           .forEach(System.out::println);
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "What is the difference between `replace()` and `replaceAll()`?" — `replace()` is literal; `replaceAll()` uses regex. `replace()` is safer and faster for literal substitutions.
- "What does `split("a", -1)` do differently from `split("a")`?" — The second argument is the limit. With -1, trailing empty strings are preserved. Default behavior discards trailing empty strings.
- "Is `String.format()` thread-safe?" — Yes, it creates a new `Formatter` object on each call.

---

### Common Mistakes Candidates Make

- Using `split(".")` to split on a literal dot.
- Using `replaceAll()` with unescaped special regex characters.
- Assuming `substring()` is O(1) — it is O(n) because it copies.

---

### Interview Traps

**Trap:** `"a,b,,c,".split(",")` — how many elements?
Answer: 4: `["a", "b", "", "c"]`. The trailing empty string after the last comma is dropped by default. `split(",", -1)` returns 5: `["a", "b", "", "c", ""]`.

---

### Quick Revision Notes

- `substring()` copies since Java 7u6 — no more memory leak.
- `split()` takes regex — escape `.` as `\\.`.
- `strip()` is Unicode-aware; prefer over `trim()`.
- `isBlank()`, `repeat()`, `lines()` added in Java 11.
- `replace()` is literal; `replaceAll()` is regex.

---

## 6. String-to-int Conversions

**Difficulty:** Easy | **Interview Frequency:** High

**Companies:** Amazon, Paypal, Razorpay, HDFC Securities, Morgan Stanley

---

### Short Interview Answer (30–60 seconds)

`Integer.parseInt(String s)` returns a primitive `int`. `Integer.valueOf(String s)` returns an `Integer` object, using the integer cache for values between -128 and 127. For the reverse, `String.valueOf(int)` or `Integer.toString(int)` are the standard approaches. Both throw `NumberFormatException` for invalid input.

---

### Deep Explanation

**`Integer.parseInt(String s)`:**

Returns `int` (primitive). Internally parses digit by digit, handling leading `-` or `+`. Throws `NumberFormatException` for null input, empty string, non-digit characters, or values outside `Integer.MIN_VALUE` to `Integer.MAX_VALUE`.

**`Integer.valueOf(String s)`:**

Returns `Integer` (object). Internally calls `parseInt` and wraps the result. Benefits from the integer cache for -128 to 127 (same cached object returned — section 8 covers this).

**When to use which:**

- Arithmetic operations: `parseInt` — avoids boxing overhead.
- Collections, Optional, generic methods: `valueOf` — needs an object.

**Radix variants:**

`Integer.parseInt("FF", 16)` parses hexadecimal. `Integer.toBinaryString(42)`, `Integer.toHexString(42)`, `Integer.toOctalString(42)` for reverse.

**`NumberFormatException`:**

Unchecked exception, extends `IllegalArgumentException`. Always validate or catch when parsing user input.

**Java 8+ `Optional` pattern:**

```java
OptionalInt result = OptionalInt.empty();
try {
    result = OptionalInt.of(Integer.parseInt(input));
} catch (NumberFormatException ignored) {}
```

Or a utility method wrapping the parse in a try-catch returning `Optional<Integer>`.

---

### Real-World Backend Example

A REST API endpoint receives a `page` query parameter as a String. Parsing it with `Integer.parseInt(page)` without validation throws `NumberFormatException` if the user sends `page=abc`. In a Spring controller, `@RequestParam(defaultValue = "0") int page` handles this — Spring itself calls `parseInt` and returns a 400 Bad Request on failure if the binding fails.

---

### Java 17 Code Example

```java
import java.util.Optional;

public class StringIntConversionDemo {

    // Safe parse utility
    public static Optional<Integer> parseIntSafe(String s) {
        if (s == null || s.isBlank()) return Optional.empty();
        try {
            return Optional.of(Integer.parseInt(s.strip()));
        } catch (NumberFormatException e) {
            return Optional.empty();
        }
    }

    public static void main(String[] args) {
        // parseInt — returns primitive
        int page = Integer.parseInt("42");
        System.out.println(page); // 42

        // valueOf — returns Integer object
        Integer cached = Integer.valueOf("100"); // may return cached instance
        Integer parsed = Integer.valueOf("200"); // new object

        // Common exceptions
        try {
            Integer.parseInt("abc");
        } catch (NumberFormatException e) {
            System.out.println("Invalid number: " + e.getMessage());
        }

        try {
            Integer.parseInt(null);
        } catch (NumberFormatException e) {
            System.out.println("null input: " + e.getMessage());
        }

        // Radix parsing
        int hex = Integer.parseInt("FF", 16);   // 255
        int bin = Integer.parseInt("1010", 2);  // 10
        System.out.println(hex + " " + bin);

        // int to String
        String s1 = String.valueOf(42);         // "42"
        String s2 = Integer.toString(42);       // "42"
        String s3 = "" + 42;                    // "42" — compiler uses StringBuilder; avoid in loops

        // Radix formatting
        System.out.println(Integer.toHexString(255));    // ff
        System.out.println(Integer.toBinaryString(42));  // 101010

        // Safe parse in real usage
        Optional<Integer> result = parseIntSafe("  123  ");
        result.ifPresent(v -> System.out.println("Parsed: " + v));

        Optional<Integer> bad = parseIntSafe("not_a_number");
        System.out.println(bad.isPresent()); // false
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "What is the difference between `Integer.parseInt` and `Integer.decode`?" — `decode` handles hexadecimal (`0x`/`#` prefix), octal (`0` prefix), and decimal automatically.
- "What does `Integer.parseInt("2147483648")` throw?" — `NumberFormatException` — it exceeds `Integer.MAX_VALUE` (2147483647). Use `Long.parseLong` for that value.

---

### Common Mistakes Candidates Make

- Not handling `NumberFormatException` on user input.
- Using `"" + number` for int-to-String in high-frequency code paths.
- Forgetting `parseInt(null)` throws `NumberFormatException`, not `NullPointerException`.

---

### Interview Traps

**Trap:** Does `Integer.parseInt("  42  ")` work?
Answer: No — throws NumberFormatException. You must call `.strip()` or `.trim()` first.

---

### Quick Revision Notes

- `parseInt` → `int`; `valueOf` → `Integer` (uses cache for -128–127).
- `NumberFormatException` for null, blank, non-numeric, or out-of-range input.
- `parseInt(s, radix)` for hex/binary parsing.
- Always validate or catch when parsing request parameters.

---

## 7. Autoboxing and Unboxing

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Google, JPMorgan, Goldman Sachs, Flipkart

---

### Short Interview Answer (30–60 seconds)

Autoboxing is the automatic conversion of a primitive to its wrapper class — e.g., `int` to `Integer`. Unboxing is the reverse. The compiler inserts the conversion calls (`Integer.valueOf()` and `Integer.intValue()`) at compile time. While convenient, autoboxing has performance overhead because it involves heap allocation and potential GC pressure, and unboxing null causes `NullPointerException`.

---

### Deep Explanation

**Compiler transformation:**

```java
Integer i = 5;         // compiler inserts: Integer i = Integer.valueOf(5);
int j = i;             // compiler inserts: int j = i.intValue();
```

**When autoboxing occurs:**

- Assigning a primitive to a wrapper variable.
- Passing a primitive to a method expecting a wrapper (or `Object`).
- Adding a primitive to a `Collection<WrapperType>`.
- Using a wrapper in arithmetic (triggers unbox, operation, rebox).

**Performance overhead:**

1. `Integer.valueOf(int)` allocates a heap object for values outside the cache range (-128 to 127).
2. Every allocation is a potential GC pause.
3. Wrapper objects are larger than primitives: an `Integer` is 16 bytes (object header 12 + 4 bytes data, on 64-bit JVM with compressed oops); an `int` is 4 bytes.

**Performance trap — boxing in hot loops:**

```java
Long sum = 0L;
for (long i = 0; i < 1_000_000; i++) {
    sum += i; // unbox sum to long, add, rebox to Long — 1M allocations
}
```
Correct: use `long sum = 0L`.

**Collections and generics:**

Generics cannot use primitives. `List<int>` is a compile error. `List<Integer>` forces boxing on every insertion. For performance-sensitive code, use primitive collections from libraries like Eclipse Collections or Trove.

---

### Real-World Backend Example

A financial batch service sums 10 million transaction amounts using `List<Long>`. Every element access unboxes the `Long` to `long`. Switching to a `long[]` array (or LongStream) eliminates 10M unboxing operations and reduces GC.

---

### Java 17 Code Example

```java
import java.util.ArrayList;
import java.util.List;

public class AutoboxingDemo {

    public static void main(String[] args) {
        // Autoboxing
        Integer a = 42;             // Integer.valueOf(42) — from cache
        Integer b = 200;            // Integer.valueOf(200) — new heap object

        // Unboxing
        int c = a;                  // a.intValue()

        // Arithmetic triggers unbox + rebox
        Integer x = 10;
        Integer y = 20;
        Integer z = x + y;          // unbox x, unbox y, add, rebox to Integer

        // Performance pitfall — boxing in loop
        long startBad = System.nanoTime();
        Long sumBad = 0L;
        for (long i = 0; i < 100_000; i++) {
            sumBad += i; // 100K Long allocations
        }
        long endBad = System.nanoTime();

        long startGood = System.nanoTime();
        long sumGood = 0L;
        for (long i = 0; i < 100_000; i++) {
            sumGood += i; // no allocations
        }
        long endGood = System.nanoTime();

        System.out.println("Bad (ms):  " + (endBad - startBad) / 1_000_000.0);
        System.out.println("Good (ms): " + (endGood - startGood) / 1_000_000.0);

        // Autoboxing in collections
        List<Integer> list = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            list.add(i); // autoboxes each int
        }

        // NPE from unboxing null (see section 9 for detail)
        Integer nullInt = null;
        try {
            int val = nullInt; // NullPointerException — calls nullInt.intValue() on null
            System.out.println(val);
        } catch (NullPointerException e) {
            System.out.println("NPE on unboxing null Integer");
        }
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "Does autoboxing affect `==` comparison for Integer?" — Yes. Two `Integer` objects for values outside -128 to 127 will be different heap objects, so `==` returns false. Use `.equals()`.
- "Can you avoid autoboxing in a List?" — Not with standard `List<Integer>`. Use primitive arrays or specialized libraries.
- "What is the difference between `Integer.valueOf(127) == Integer.valueOf(127)` and `Integer.valueOf(128) == Integer.valueOf(128)`?" — First is true (cached); second is false (new objects).

---

### Common Mistakes Candidates Make

- Using `Long` instead of `long` as a sum accumulator in loops.
- Comparing autoboxed values with `==` for values outside the cache range.
- Not knowing the JVM overhead: 16-byte `Integer` vs 4-byte `int`.

---

### Interview Traps

**Trap:** What does `Integer a = null; if (a == 1)` do?
Answer: NullPointerException. The comparison `a == 1` unboxes `a` via `a.intValue()`, which throws NPE because `a` is null.

---

### Quick Revision Notes

- Autoboxing: primitive → wrapper via `valueOf()`; unboxing: wrapper → primitive via `xxxValue()`.
- Boxing in loops causes heap allocation per iteration — use primitives.
- Unboxing null throws NPE.
- Generics require wrapper types — use `int[]` / `long[]` or specialized collections for performance.

---

## 8. Integer Cache (-128 to 127)

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Google, Uber, Paytm, Goldman Sachs

---

### Short Interview Answer (30–60 seconds)

`Integer.valueOf()` caches Integer objects for values between -128 and 127 inclusive. Calls with the same value in this range return the same cached object. Outside this range, a new Integer object is created each time. This means `==` on Integer objects gives counterintuitive results — true inside the range, false outside.

---

### Deep Explanation

**JLS specification:**

Section 5.1.7 requires that `Boolean`, `Byte`, `Short` (all values), `Character` (0–127), and `Integer` (-128–127) are cached. The spec does NOT require caching outside -128–127 for Integer, but implementations may extend the upper bound via `-XX:AutoBoxCacheMax=<size>`.

**Implementation (OpenJDK):**

```java
// Simplified from Integer.java
private static class IntegerCache {
    static final int low = -128;
    static final int high; // 127 by default, configurable
    static final Integer[] cache;
    static {
        high = Math.max(127, 
            Integer.parseInt(
                System.getProperty("java.lang.Integer.IntegerCache.high", "127")));
        cache = new Integer[high - low + 1];
        for (int k = 0; k < cache.length; k++)
            cache[k] = new Integer(low + k); // pre-allocated at class init
    }
}
```

**Other wrapper caches:**

- `Boolean`: only two values, both always cached.
- `Byte`: all 256 values cached.
- `Short`: -128 to 127.
- `Long`: -128 to 127.
- `Character`: 0 to 127.
- `Double`, `Float`: NO caching (floating-point values are not identifiable by a small fixed set).

**The ==  trap in interviews:**

```java
Integer a = 127;
Integer b = 127;
System.out.println(a == b); // true — both point to cache[255]

Integer c = 128;
Integer d = 128;
System.out.println(c == d); // false — two new heap objects
```

This is one of the most frequently asked Java trick questions.

---

### Real-World Backend Example

A legacy service used `Integer == Integer` comparisons to check if two order statuses were the same. It worked in testing (small status codes all within -128–127), but in production with large numeric status codes it silently failed equality checks — a subtle bug that slipped through because the common test cases were all cached values.

---

### Java 17 Code Example

```java
public class IntegerCacheDemo {

    public static void main(String[] args) {
        // Cache range — same object
        Integer a = 127;
        Integer b = 127;
        System.out.println(a == b);       // true
        System.out.println(a.equals(b));  // true

        // Outside cache — different objects
        Integer c = 128;
        Integer d = 128;
        System.out.println(c == d);       // false
        System.out.println(c.equals(d));  // true  — always use equals

        // Explicit valueOf also uses cache
        Integer e = Integer.valueOf(100);
        Integer f = Integer.valueOf(100);
        System.out.println(e == f);       // true

        // new Integer bypasses cache (deprecated in Java 9, removed in Java 17)
        // Integer g = new Integer(100); // compilation error in Java 17

        // Long cache
        Long l1 = 127L;
        Long l2 = 127L;
        System.out.println(l1 == l2);     // true — Long also caches -128 to 127

        Long l3 = 128L;
        Long l4 = 128L;
        System.out.println(l3 == l4);     // false

        // Character cache (0-127)
        Character ch1 = 'A'; // 65
        Character ch2 = 'A';
        System.out.println(ch1 == ch2);   // true

        // Double — no cache
        Double d1 = 1.0;
        Double d2 = 1.0;
        System.out.println(d1 == d2);     // false — always new objects

        // Safe comparison
        Integer x = 1000, y = 1000;
        System.out.println(x.equals(y));  // true — always correct
        System.out.println(x.intValue() == y.intValue()); // true — unbox both
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "Can you change the Integer cache upper bound?" — Yes, via `-XX:AutoBoxCacheMax=<n>` JVM flag or the system property `java.lang.Integer.IntegerCache.high`.
- "Why does the cache start at -128 rather than 0?" — Because negative numbers (-128 to -1) are frequently used as error codes and array indices in existing code. The JLS chose this range pragmatically.
- "Is `new Integer(5)` the same as `Integer.valueOf(5)`?" — `new Integer(5)` was deprecated in Java 9 and removed in Java 17. It always created a new object, bypassing the cache. `Integer.valueOf(5)` uses the cache.

---

### Common Mistakes Candidates Make

- Not knowing `new Integer()` was removed in Java 17.
- Applying the cache rule to `Double` and `Float` — they have no cache.
- Forgetting that `Long` also has the same -128 to 127 cache.

---

### Interview Traps

**Trap:** `Integer.valueOf(127) == Integer.valueOf(127)` — true or false?
Answer: True — both return the same cached instance.

**Trap:** Is the cache range guaranteed to be exactly -128 to 127?
Answer: The lower bound (-128) is fixed by the JLS. The upper bound is at least 127, but can be higher via JVM flags.

---

### Quick Revision Notes

- `Integer.valueOf()` caches -128 to 127; outside this range, new objects are created.
- Long, Short, Byte, Character have similar caches; Double/Float do not.
- Always use `.equals()` or `intValue() ==` for Integer comparison, never `==`.
- `new Integer(n)` removed in Java 17.
- Upper bound configurable via `-XX:AutoBoxCacheMax`.

---

## 9. Null Unboxing NullPointerException

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Morgan Stanley, Deutsche Bank, Thoughtworks

---

### Short Interview Answer (30–60 seconds)

When a wrapper type (Integer, Long, Boolean, etc.) is null and is automatically unboxed to its corresponding primitive, the JVM calls `.intValue()` (or equivalent) on a null reference, causing a NullPointerException. This is a hidden danger because the NPE's stack trace points to the unboxing line, not to where null was assigned, making it non-obvious.

---

### Deep Explanation

**When null unboxing occurs:**

1. Assigning a null wrapper to a primitive variable.
2. Using a null wrapper in arithmetic or boolean expressions.
3. Passing a null wrapper to a method that expects a primitive parameter.
4. Returning a null wrapper from a method with a primitive return type.
5. The ternary operator with mixed types: `condition ? Integer : int`.

**Why it is non-obvious:**

Consider a method that returns `Integer` from a Map lookup:
```java
Map<String, Integer> scores = new HashMap<>();
int score = scores.get("alice"); // get returns null; unboxing null → NPE
```
The NPE message in Java 17 is helpful: "Cannot unbox null value" with the JEP 358 Helpful NPE Messages feature.

**The ternary operator trap:**

```java
Integer x = null;
int result = (condition) ? x : 0;
// If condition is true: unboxes x (null) → NPE
// JLS: ternary with Integer and int promotes the whole expression to int, 
// unboxing happens regardless of which branch is taken? No — unboxing happens 
// on the Integer branch when that branch is chosen and the result type is int.
```

Actually more subtle: the expression type is `int` (due to numeric promotion), so the Integer branch is unboxed when selected.

**Java 14+ Helpful NPEs:**

JEP 358 (Java 14, finalized in Java 17) produces messages like:
`NullPointerException: Cannot invoke "Integer.intValue()" because the return value of "java.util.Map.get(Object)" is null`

This makes null unboxing NPEs much easier to diagnose.

---

### Real-World Backend Example

A pricing service returns `Integer getDiscount(String promoCode)` from a database lookup. The caller does:
```java
int discount = pricingService.getDiscount(promoCode);
```
If the promo code doesn't exist, the service returns null, causing a silent NPE at the unboxing assignment. The fix: return `OptionalInt` or change the caller to use `Integer` and check for null.

---

### Java 17 Code Example

```java
import java.util.HashMap;
import java.util.Map;
import java.util.OptionalInt;

public class NullUnboxingDemo {

    // Dangerous: returns null when not found
    static Integer getScore(Map<String, Integer> map, String key) {
        return map.get(key); // null if key absent
    }

    // Safe: returns OptionalInt
    static OptionalInt getScoreSafe(Map<String, Integer> map, String key) {
        Integer val = map.get(key);
        return val != null ? OptionalInt.of(val) : OptionalInt.empty();
    }

    public static void main(String[] args) {
        Map<String, Integer> scores = new HashMap<>();
        scores.put("alice", 95);

        // NPE scenario 1: unboxing null return value
        try {
            int s = getScore(scores, "bob"); // bob absent → null → NPE
            System.out.println(s);
        } catch (NullPointerException e) {
            // Java 17 helpful message: Cannot invoke "Integer.intValue()" because
            // the return value of "NullUnboxingDemo.getScore(Map, String)" is null
            System.out.println("NPE: " + e.getMessage());
        }

        // NPE scenario 2: Map.getOrDefault with primitive default
        int safeScore = scores.getOrDefault("bob", 0); // no NPE — default is int literal, autoboxed to Integer
        System.out.println(safeScore); // 0

        // NPE scenario 3: Boolean unboxing
        Map<String, Boolean> flags = new HashMap<>();
        try {
            boolean active = flags.get("featureX"); // null → NPE
            System.out.println(active);
        } catch (NullPointerException e) {
            System.out.println("Boolean unboxing NPE: " + e.getMessage());
        }

        // NPE scenario 4: ternary operator
        Integer x = null;
        try {
            int result = true ? x : 0; // x is unboxed to int → NPE
            System.out.println(result);
        } catch (NullPointerException e) {
            System.out.println("Ternary NPE: " + e.getMessage());
        }

        // Safe pattern: OptionalInt
        getScoreSafe(scores, "bob")
            .ifPresentOrElse(
                v -> System.out.println("Score: " + v),
                () -> System.out.println("No score found"));
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "How would you fix a method that sometimes returns null Integer and is assigned to an int?" — Change return type to `OptionalInt`, use `getOrDefault`, or add a null check before unboxing.
- "What does Java 14+ print for a null unboxing NPE?" — JEP 358 helpful NPEs identify the exact method call that returned null.
- "Can auto-unboxing cause NPE in a switch statement?" — Yes: `switch(nullInteger)` unboxes the Integer to int, causing NPE.

---

### Common Mistakes Candidates Make

- Returning `null` from methods with `Integer` return type and then assigning to `int`.
- Using `Boolean` as a tri-state (true/false/null) and unboxing it.
- Not recognizing ternary operator type promotion as an unboxing trigger.

---

### Interview Traps

**Trap:** `Map<String, Boolean> m = ...; if (m.get("key")) { ... }` — what happens if "key" is absent?
Answer: NPE. `m.get("key")` returns null; the `if` condition unboxes null Boolean to boolean, throwing NPE.

---

### Quick Revision Notes

- Unboxing null wrapper → NullPointerException.
- Common sources: Map.get(), method return, ternary, switch.
- Fix: null check, getOrDefault, OptionalInt/OptionalLong, or use wrapper type.
- Java 17 helpful NPE messages identify the exact source.

---

## 10. Comparable vs Comparator

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Google, Flipkart, Zalando, ThoughtWorks

---

### Short Interview Answer (30–60 seconds)

`Comparable` defines the natural ordering of a class — implemented inside the class itself via `compareTo()`. `Comparator` defines an external, custom ordering — implemented outside the class and passed to sort methods. Use `Comparable` when there is one obvious default ordering (e.g., Order by amount). Use `Comparator` for multiple orderings or when you cannot modify the class.

---

### Deep Explanation

**`Comparable<T>` interface:**

```java
public interface Comparable<T> {
    int compareTo(T o);
}
```

Contract: returns negative if this < o, 0 if equal, positive if this > o. Classes implementing Comparable can be sorted by `Collections.sort()`, `Arrays.sort()`, and stored in `TreeSet`/`TreeMap` without supplying an external comparator.

**`Comparator<T>` interface:**

```java
@FunctionalInterface
public interface Comparator<T> {
    int compare(T o1, T o2);
}
```

Java 8 added many default/static methods for chaining.

**Java 8 Comparator chaining:**

```java
Comparator<Order> byAmountThenDate = 
    Comparator.comparingDouble(Order::getAmount)
              .thenComparing(Order::getCreatedAt)
              .reversed();
```

**`reversed()` subtlety:**

`reversed()` wraps the whole comparator, reversing the final sign. `thenComparing(...)` after `reversed()` applies the secondary sort in natural order within the reversed primary. If you want both reversed: `reversed().thenComparing(Comparator.comparing(Order::getCreatedAt).reversed())`.

**`Comparator.comparing()` with key extractor:**

Takes a `Function<T, U extends Comparable<U>>` — extracts a key and delegates to the key's natural ordering. Avoids boilerplate null checks in many cases. For null-safe ordering: `Comparator.comparing(Order::getDate, Comparator.nullsLast(naturalOrder()))`.

**Consistency with equals:**

The Comparable contract recommends (but does not require) that `(a.compareTo(b) == 0) == a.equals(b)`. Violation can cause bizarre behavior in `TreeSet`/`TreeMap` (elements with compareTo == 0 are treated as duplicates and dropped).

---

### Real-World Backend Example

An e-commerce order service needs to display orders sorted by: (1) priority (HIGH before LOW), (2) amount descending, (3) creation time ascending. This multi-key sort is expressed cleanly with Comparator chaining and passed to `orders.sort(comparator)`.

---

### Java 17 Code Example

```java
import java.time.LocalDateTime;
import java.util.*;

public class ComparatorDemo {

    enum Priority { HIGH, MEDIUM, LOW }

    record Order(String id, double amount, LocalDateTime createdAt, Priority priority)
            implements Comparable<Order> {

        // Natural ordering: by amount ascending
        @Override
        public int compareTo(Order other) {
            return Double.compare(this.amount, other.amount);
        }
    }

    public static void main(String[] args) {
        List<Order> orders = new ArrayList<>(List.of(
            new Order("O1", 500.0, LocalDateTime.of(2024, 1, 3, 10, 0), Priority.LOW),
            new Order("O2", 1200.0, LocalDateTime.of(2024, 1, 1, 9, 0), Priority.HIGH),
            new Order("O3", 500.0, LocalDateTime.of(2024, 1, 2, 8, 0), Priority.HIGH),
            new Order("O4", 800.0, LocalDateTime.of(2024, 1, 4, 11, 0), Priority.MEDIUM)
        ));

        // Natural ordering (Comparable): sort by amount ascending
        Collections.sort(orders);
        orders.forEach(o -> System.out.printf("%-3s %.0f%n", o.id(), o.amount()));

        System.out.println("---");

        // Custom ordering via Comparator: priority asc, then amount desc, then date asc
        Comparator<Order> businessSort = Comparator
            .comparing(Order::priority)           // enum natural order: HIGH < MEDIUM < LOW
            .thenComparingDouble(o -> -o.amount()) // descending amount via negation
            .thenComparing(Order::createdAt);      // ascending date

        orders.sort(businessSort);
        orders.forEach(o -> System.out.printf("%-3s %-6s %.0f  %s%n",
            o.id(), o.priority(), o.amount(), o.createdAt().toLocalDate()));

        System.out.println("---");

        // Null-safe comparator
        List<String> withNulls = new ArrayList<>(Arrays.asList("banana", null, "apple", null, "cherry"));
        withNulls.sort(Comparator.nullsLast(Comparator.naturalOrder()));
        System.out.println(withNulls); // [apple, banana, cherry, null, null]

        // TreeSet with natural ordering (uses Comparable)
        TreeSet<Order> orderSet = new TreeSet<>();
        orderSet.addAll(orders);
        System.out.println("TreeSet size (duplicates by amount collapsed): " + orderSet.size());
        // O1 and O3 both have amount 500 — compareTo returns 0 — TreeSet sees them as duplicates!
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "What happens if you put two objects with `compareTo() == 0` but `equals() != 0` into a TreeSet?" — The second is dropped. TreeSet uses compareTo for identity, not equals.
- "How do you sort in descending order with Comparator?" — `Comparator.comparingInt(Order::getAmount).reversed()` or use `Collections.reverseOrder()` with natural ordering.
- "What does `Comparator.naturalOrder()` return?" — A comparator that imposes natural ordering using Comparable. Equivalent to `(a, b) -> a.compareTo(b)`.

---

### Common Mistakes Candidates Make

- Subtracting two ints in `compareTo` (`return this.amount - other.amount`) — causes integer overflow for large values. Always use `Integer.compare()` or `Double.compare()`.
- Using `Comparable` for multiple sort orders — correct approach is multiple `Comparator` implementations.
- Not knowing that `reversed()` wraps the whole comparator chain built so far.

---

### Interview Traps

**Trap:** `return o1.amount - o2.amount` in a Comparator for int comparison — what's wrong?
Answer: Integer overflow. If `o1.amount = Integer.MIN_VALUE` and `o2.amount = 1`, the subtraction overflows to a large positive value, reversing the order. Always use `Integer.compare(o1.amount, o2.amount)`.

---

### Quick Revision Notes

- `Comparable`: natural ordering inside the class (`compareTo`).
- `Comparator`: external ordering, passed to sort methods.
- Java 8: `Comparator.comparing()`, `thenComparing()`, `reversed()`, `nullsFirst()/nullsLast()`.
- Never subtract ints in compareTo — use `Integer.compare()`.
- TreeSet/TreeMap use compareTo for identity — inconsistency with equals drops elements.

---

## 11. Exception Hierarchy

**Difficulty:** Easy–Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Microsoft, Oracle, SAP, Capgemini

---

### Short Interview Answer (30–60 seconds)

At the top is `Throwable`. It has two direct subclasses: `Error` for JVM-level problems (OutOfMemoryError, StackOverflowError) that applications should not catch, and `Exception` for conditions that applications handle. Exception splits into checked exceptions (must be declared or caught — IOException, SQLException) and unchecked exceptions (extend RuntimeException — NullPointerException, IllegalArgumentException).

---

### Deep Explanation

**Full hierarchy:**

```
Throwable
├── Error
│   ├── OutOfMemoryError
│   ├── StackOverflowError
│   ├── AssertionError
│   └── VirtualMachineError
└── Exception
    ├── IOException (checked)
    │   ├── FileNotFoundException
    │   └── SocketException
    ├── SQLException (checked)
    ├── CloneNotSupportedException (checked)
    ├── InterruptedException (checked)
    └── RuntimeException (unchecked)
        ├── NullPointerException
        ├── IllegalArgumentException
        │   └── NumberFormatException
        ├── IllegalStateException
        ├── ArrayIndexOutOfBoundsException
        ├── ClassCastException
        ├── ArithmeticException
        ├── UnsupportedOperationException
        └── ConcurrentModificationException
```

**Error vs Exception:**

`Error` signals JVM/system-level failures. Applications should almost never catch `Error`. Exceptions to this rule (pun intended): catching `OutOfMemoryError` in a framework to try to reclaim large caches, or catching `Error` in a thread pool executor to prevent silent thread death.

**Checked exceptions:**

Enforced by the compiler. The method must either handle them in a try-catch or declare them with `throws`. Purpose: force callers to acknowledge recoverable conditions (file missing, network timeout).

**Unchecked exceptions (RuntimeException):**

Not enforced by the compiler. Signal programming errors (null dereference, bad arguments). Caller is not expected to recover from these — fix the bug.

**`Throwable.getMessage()` vs `Throwable.toString()` vs `Throwable.printStackTrace()`:**

- `getMessage()`: the detail message set in the constructor.
- `toString()`: class name + ": " + getMessage().
- `printStackTrace()`: writes the full stack trace to stderr. Never use in production — use a logging framework.

---

### Real-World Backend Example

A Spring Boot REST API has a global `@ControllerAdvice` exception handler. It catches `ConstraintViolationException` (a RuntimeException subclass) and maps it to HTTP 400. It catches `ResourceNotFoundException` (custom unchecked) and maps it to HTTP 404. It does NOT catch `Error` — if the JVM runs out of memory, the application should restart.

---

### Java 17 Code Example

```java
public class ExceptionHierarchyDemo {

    public static void main(String[] args) {
        // Checked exception — must handle
        try {
            java.nio.file.Files.readAllBytes(java.nio.file.Path.of("/nonexistent"));
        } catch (java.io.IOException e) {
            System.out.println("IOException caught: " + e.getMessage());
        }

        // Unchecked exception — optional handling
        try {
            String s = null;
            s.length(); // NullPointerException
        } catch (NullPointerException e) {
            System.out.println("NPE: " + e.getMessage());
        }

        // Error — typically not caught
        // StackOverflowError from infinite recursion
        try {
            recurse(0);
        } catch (StackOverflowError e) {
            System.out.println("StackOverflow caught (educational only — don't do this in prod)");
        }

        // Demonstrating the hierarchy via instanceof
        try {
            throw new NumberFormatException("bad input");
        } catch (RuntimeException e) {
            // NumberFormatException is-a IllegalArgumentException is-a RuntimeException
            System.out.println("Caught as RuntimeException: " + e.getClass().getSimpleName());
            System.out.println("Is IllegalArgumentException: " + (e instanceof IllegalArgumentException));
        }
    }

    static void recurse(int depth) {
        recurse(depth + 1); // endless recursion
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "Can you catch Error in Java?" — Syntactically yes; semantically almost never should. Some frameworks catch `OutOfMemoryError` for specific cache-clearing purposes.
- "Is `InterruptedException` checked or unchecked?" — Checked. And it deserves special handling — you must restore the interrupt flag: `Thread.currentThread().interrupt()`.
- "Where does `AssertionError` fit?" — It extends `Error`. Thrown by assert statements when assertions are enabled (`-ea` JVM flag).

---

### Common Mistakes Candidates Make

- Placing `RuntimeException` as a sibling of `Exception` rather than a subclass.
- Forgetting that `Error` is a sibling of `Exception`, not a subclass.
- Saying checked exceptions must always be caught — they can also be declared with `throws` and propagated.

---

### Interview Traps

**Trap:** "Is `NullPointerException` a checked or unchecked exception?"
Answer: Unchecked — extends RuntimeException. Trick: it is in `java.lang` and very common, which sometimes confuses candidates.

---

### Quick Revision Notes

- `Throwable` → `Error` (JVM problems, don't catch) + `Exception` (application issues).
- `Exception` → checked (IOException, SQLException) + `RuntimeException` (unchecked).
- Checked = compiler-enforced; unchecked = programmer's responsibility.
- `RuntimeException` extends `Exception` — it IS an Exception, just unchecked.

---

## 12. Checked vs Unchecked Exceptions

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Google, Amazon, ThoughtWorks, Atlassian, Spotify

---

### Short Interview Answer (30–60 seconds)

Checked exceptions model recoverable conditions that the caller is expected to handle — the compiler enforces this by requiring `try-catch` or a `throws` declaration. Unchecked exceptions model programming errors that callers are not expected to recover from. Modern frameworks like Spring prefer unchecked exceptions because checked exceptions pollute method signatures and make it harder to use lambdas and streams without boilerplate.

---

### Deep Explanation

**The case for checked exceptions:**

- Forces callers to be aware of failure modes at compile time.
- Appropriate for truly recoverable conditions: file not found (try another path), network timeout (retry), database unavailability (circuit break).
- Documents API contracts — method signature lists what can go wrong.

**The case against checked exceptions (and Spring's choice):**

- Propagation pollution: every layer from DAO to Controller must either handle or re-declare the exception.
- Incompatible with functional interfaces: `Runnable`, `Callable` (sort of), lambdas. `Consumer<T>` does not declare `throws Exception`, so you cannot use a checked-exception-throwing method reference in `forEach` without a wrapper.
- James Gosling later expressed regret about checked exceptions.
- Spring wraps all JDBC `SQLException` (checked) in `DataAccessException` (unchecked). This is the canonical example.

**Lambda/Stream problem:**

```java
List<String> paths = List.of("a.txt", "b.txt");
// This doesn't compile — Files.readString throws IOException (checked)
paths.stream()
     .map(Files::readString) // compile error
     .collect(toList());

// Must wrap:
paths.stream()
     .map(p -> { try { return Files.readString(Path.of(p)); } 
                 catch (IOException e) { throw new UncheckedIOException(e); } })
     .collect(toList());
```

`UncheckedIOException` (Java 8) is the standard wrapper for `IOException` in stream contexts.

**When to use which in practice:**

| Condition | Recommendation |
|---|---|
| Caller can realistically recover | Checked exception |
| Programming bug (null, bad arg) | Unchecked (RuntimeException) |
| Framework/library internal error | Unchecked (wrap checked with unchecked) |
| Public API where contract is important | Checked can be justified |
| Used in lambdas/streams | Unchecked |

---

### Real-World Backend Example

Spring Data wraps `java.sql.SQLException` (checked) in `org.springframework.dao.DataAccessException` (unchecked). Service layer code doesn't need `throws SQLException` on every method. When the database is unavailable, the exception propagates up to the global exception handler which maps it to HTTP 503.

---

### Java 17 Code Example

```java
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Collectors;

public class CheckedUncheckedDemo {

    // Checked exception — caller MUST handle or declare
    static String readConfig(String path) throws IOException {
        return Files.readString(Path.of(path));
    }

    // Unchecked wrapper — allows use in streams
    static String readConfigUnchecked(String path) {
        try {
            return Files.readString(Path.of(path));
        } catch (IOException e) {
            throw new UncheckedIOException("Failed to read config: " + path, e);
        }
    }

    // Spring-style service: unchecked throughout
    static class OrderService {
        // No throws declaration needed — exception propagates freely
        String getOrder(String id) {
            if (id == null || id.isBlank()) {
                throw new IllegalArgumentException("Order ID must not be blank");
            }
            // Simulated DAO that throws unchecked DataAccessException
            throw new RuntimeException("Database unavailable"); // simplified
        }
    }

    public static void main(String[] args) {
        // Using checked exception — verbose
        try {
            String config = readConfig("/etc/app/config.properties");
            System.out.println(config);
        } catch (IOException e) {
            System.out.println("Config not found: " + e.getMessage());
        }

        // Using unchecked wrapper — works in streams
        List<String> configPaths = List.of("/etc/app/app.properties", "/etc/app/db.properties");
        List<String> contents = configPaths.stream()
            .map(CheckedUncheckedDemo::readConfigUnchecked)
            .collect(Collectors.toList());

        // UncheckedIOException usage
        try {
            readConfigUnchecked("/nonexistent/path");
        } catch (UncheckedIOException e) {
            System.out.println("Unchecked: " + e.getMessage());
            System.out.println("Cause: " + e.getCause().getClass().getSimpleName());
        }
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "How do you use a checked-exception-throwing method in a Java Stream?" — Wrap it in a helper that catches the checked exception and re-throws as unchecked (`UncheckedIOException` or a custom runtime exception).
- "What did Spring do with JDBC's `SQLException`?" — Wrapped it in `DataAccessException` (unchecked), classified by type (deadlock, constraint violation, etc.).
- "What is `Callable` vs `Runnable` for checked exceptions?" — `Callable<V>` declares `throws Exception`; `Runnable` does not. For tasks that throw checked exceptions, use `Callable`.

---

### Common Mistakes Candidates Make

- Catching a checked exception and re-throwing as `new RuntimeException(e.getMessage())` — loses the stack trace.
- Declaring `throws Exception` on every method to avoid thinking about exception types.
- Not knowing `UncheckedIOException` exists.

---

### Interview Traps

**Trap:** "Can a method override a parent method and throw a broader checked exception?"
Answer: No. Overriding methods can throw the same or narrower checked exceptions, or no checked exception — not broader. This is the Liskov Substitution Principle applied to exceptions.

---

### Quick Revision Notes

- Checked: recoverable, compiler-enforced; unchecked: programming errors, not enforced.
- Spring prefers unchecked — wraps `SQLException` in `DataAccessException`.
- Checked exceptions cannot be used directly in lambdas — wrap in unchecked.
- Override cannot throw broader checked exceptions than the parent method.
- `UncheckedIOException` (Java 8) is the standard unchecked wrapper for `IOException`.

---

## 13. try-catch-finally Execution Order

**Difficulty:** Medium | **Interview Frequency:** Very High

**Companies:** Amazon, Goldman Sachs, Morgan Stanley, Barclays, Infosys

---

### Short Interview Answer (30–60 seconds)

`finally` always executes after try and catch blocks, whether or not an exception was thrown or caught — except if `System.exit()` is called or the JVM crashes. If a `return` statement is in the try block, finally still runs before the method actually returns. If both try and finally have `return` statements, the finally's return overrides the try's return.

---

### Deep Explanation

**Execution order:**

1. try block executes.
2. If exception thrown and matching catch exists: catch executes.
3. If no matching catch: exception propagates, but finally still runs.
4. finally executes.
5. If try/catch completed normally: method returns.
6. If exception was not caught: exception propagates after finally.

**`return` in try block:**

The return value is computed, saved on the stack, then finally runs. After finally, the saved return value is returned. The finally block cannot alter this return value by a subsequent assignment to a local variable — UNLESS finally itself has a `return` statement.

**`return` in finally — overrides try's return:**

```java
static int test() {
    try {
        return 1;
    } finally {
        return 2; // overrides — method returns 2
    }
}
```

This pattern is considered harmful — it swallows any exception thrown in the try block.

**Exception in finally — swallows try exception:**

```java
static void test() throws Exception {
    try {
        throw new IOException("from try");
    } finally {
        throw new RuntimeException("from finally"); // IOException is LOST
    }
}
```

The IOException is completely swallowed. This is one reason try-with-resources uses suppressed exceptions instead.

**`System.exit()` prevents finally from running:**

`System.exit(0)` immediately terminates the JVM. Shutdown hooks run, but finally blocks do not.

---

### Real-World Backend Example

A JDBC DAO uses try-catch-finally to close database connections. The finally block calls `connection.close()`, ensuring the connection is returned to the pool even if a `SQLException` is thrown. However, if `connection.close()` itself throws, the original SQL exception is swallowed — this is why try-with-resources is better.

---

### Java 17 Code Example

```java
import java.io.IOException;

public class TryCatchFinallyDemo {

    // Case 1: normal flow
    static String normalFlow() {
        try {
            System.out.println("try");
            return "from try";
        } catch (Exception e) {
            System.out.println("catch");
            return "from catch";
        } finally {
            System.out.println("finally"); // prints before return
        }
    }

    // Case 2: exception thrown, caught
    static String exceptionCaught() {
        try {
            System.out.println("try");
            throw new RuntimeException("oops");
        } catch (RuntimeException e) {
            System.out.println("catch: " + e.getMessage());
            return "from catch";
        } finally {
            System.out.println("finally");
        }
    }

    // Case 3: return in finally overrides try return
    static int finallyOverrides() {
        try {
            return 1;
        } finally {
            return 2; // bad practice — overrides 1
        }
    }

    // Case 4: exception in finally swallows try exception
    static void finallySwallows() throws Exception {
        try {
            throw new IOException("original");
        } finally {
            throw new RuntimeException("finally exception"); // IOException lost
        }
    }

    // Case 5: exception not caught — finally still runs
    static void exceptionPropagates() {
        try {
            System.out.println("about to throw");
            throw new RuntimeException("uncaught");
        } finally {
            System.out.println("finally runs despite uncaught exception");
        }
    }

    public static void main(String[] args) {
        System.out.println("=== Normal flow ===");
        System.out.println(normalFlow());

        System.out.println("\n=== Exception caught ===");
        System.out.println(exceptionCaught());

        System.out.println("\n=== finally overrides return ===");
        System.out.println(finallyOverrides()); // 2

        System.out.println("\n=== finally swallows exception ===");
        try {
            finallySwallows();
        } catch (Exception e) {
            System.out.println("Caught: " + e.getClass().getSimpleName()); // RuntimeException — IOException lost
        }

        System.out.println("\n=== Exception propagates through finally ===");
        try {
            exceptionPropagates();
        } catch (RuntimeException e) {
            System.out.println("Eventually caught: " + e.getMessage());
        }
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "Does finally run if the thread is killed via `Thread.stop()`?" — Yes. `Thread.stop()` throws a `ThreadDeath` error; finally blocks execute as the stack unwinds.
- "Can finally prevent an exception from propagating?" — Yes, by catching it (empty finally does not prevent propagation) or by having a `return` statement in finally.
- "What is the difference between finally and a shutdown hook?" — Shutdown hooks are for JVM exit (registered via `Runtime.getRuntime().addShutdownHook()`). Finally is for method/block-level cleanup.

---

### Common Mistakes Candidates Make

- Saying "finally doesn't run if an exception is not caught" — it runs regardless.
- Not knowing that `return` in finally overrides `return` in try.
- Having `connection.close()` in finally without its own try-catch — if close() throws, the original exception is swallowed.

---

### Interview Traps

**Trap:** What is the output?
```java
static int count() {
    int i = 0;
    try { i = 1; return i; }
    finally { i = 2; }
}
```
Answer: 1. The return value `1` is saved before finally runs. `i = 2` modifies the local variable, but the return value (already saved) is 1. If finally had `return i;`, it would return 2.

---

### Quick Revision Notes

- finally always runs (except `System.exit()` / JVM crash).
- `return` in try saves return value; finally runs; saved value returned.
- `return` in finally overrides try's return.
- Exception in finally swallows the original try/catch exception.
- Use try-with-resources to avoid finally exception swallowing.

---

## 14. try-with-resources

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Google, Netflix, Booking.com, SAP

---

### Short Interview Answer (30–60 seconds)

try-with-resources, introduced in Java 7, automatically closes resources that implement `AutoCloseable`. The `close()` method is called in the reverse order of declaration, even if an exception is thrown. If both the try block and `close()` throw exceptions, the close exception is added as a suppressed exception on the primary exception — nothing is lost, unlike the traditional finally pattern.

---

### Deep Explanation

**`AutoCloseable` vs `Closeable`:**

`Closeable` (from Java 1.1) extends `AutoCloseable` (Java 7). `Closeable.close()` throws `IOException`; `AutoCloseable.close()` throws `Exception`. For resources that don't throw `IOException`, implement `AutoCloseable` directly.

**Bytecode transformation:**

The compiler transforms:
```java
try (Resource r = new Resource()) {
    use(r);
}
```
into approximately:
```java
Resource r = new Resource();
Throwable primaryException = null;
try {
    use(r);
} catch (Throwable t) {
    primaryException = t;
    throw t;
} finally {
    if (primaryException != null) {
        try { r.close(); }
        catch (Throwable suppressed) {
            primaryException.addSuppressed(suppressed);
        }
    } else {
        r.close();
    }
}
```

**Suppressed exceptions:**

`Throwable.addSuppressed(Throwable)` attaches a secondary exception to a primary. Retrieve with `Throwable.getSuppressed()`. This was specifically designed for try-with-resources to not lose `close()` exceptions. Logging frameworks should log suppressed exceptions too.

**Multiple resources:**

```java
try (InputStream in = new FileInputStream(src);
     OutputStream out = new FileOutputStream(dst)) {
    // use in and out
}
```
Resources are closed in reverse declaration order: `out.close()` then `in.close()`. If `out.close()` throws, `in.close()` still runs and any exception from `in.close()` is suppressed onto the `out.close()` exception.

**Java 9 enhancement — effectively final variables:**

Before Java 9, the resource variable had to be declared in the try header. Java 9 allows:
```java
InputStream in = openStream();
try (in) { // no re-declaration needed if in is effectively final
    process(in);
}
```

---

### Real-World Backend Example

A file processing service reads a CSV file from S3 via an `S3ObjectInputStream`. With try-with-resources, the stream is closed automatically even if parsing throws an exception. This prevents connection leaks to S3 that would eventually exhaust the connection pool.

---

### Java 17 Code Example

```java
import java.io.*;
import java.nio.file.*;

public class TryWithResourcesDemo {

    // Custom AutoCloseable resource
    static class DatabaseConnection implements AutoCloseable {
        final String name;

        DatabaseConnection(String name) {
            this.name = name;
            System.out.println("Opening: " + name);
        }

        void query(String sql) {
            System.out.println("Executing on " + name + ": " + sql);
            if (sql.contains("bad")) {
                throw new RuntimeException("Query failed: " + sql);
            }
        }

        @Override
        public void close() {
            System.out.println("Closing: " + name);
        }
    }

    // Resource whose close() also throws
    static class FlakyConnection implements AutoCloseable {
        @Override
        public void close() throws Exception {
            throw new Exception("close() failed");
        }
    }

    public static void main(String[] args) {
        // Basic try-with-resources
        try (DatabaseConnection conn = new DatabaseConnection("primary")) {
            conn.query("SELECT * FROM orders");
        } // close() called automatically

        System.out.println("---");

        // Multiple resources — closed in reverse order
        try (DatabaseConnection conn1 = new DatabaseConnection("primary");
             DatabaseConnection conn2 = new DatabaseConnection("replica")) {
            conn1.query("SELECT * FROM users");
            conn2.query("SELECT * FROM products");
        } // conn2.close() first, then conn1.close()

        System.out.println("---");

        // Suppressed exceptions
        try (FlakyConnection fc = new FlakyConnection()) {
            throw new RuntimeException("primary exception");
        } catch (RuntimeException e) {
            System.out.println("Primary: " + e.getMessage());
            for (Throwable suppressed : e.getSuppressed()) {
                System.out.println("Suppressed: " + suppressed.getMessage());
            }
        } catch (Exception e) {
            System.out.println("Other: " + e.getMessage());
        }

        System.out.println("---");

        // Java 9: effectively final variable in try header
        InputStream stream = TryWithResourcesDemo.class.getResourceAsStream("/some-resource");
        if (stream != null) {
            try (stream) {
                byte[] bytes = stream.readAllBytes();
                System.out.println("Read " + bytes.length + " bytes");
            } catch (IOException e) {
                System.out.println("Read error: " + e.getMessage());
            }
        }

        // File I/O with try-with-resources
        Path tempFile = Path.of(System.getProperty("java.io.tmpdir"), "test.txt");
        try {
            Files.writeString(tempFile, "hello world");
            try (BufferedReader reader = Files.newBufferedReader(tempFile)) {
                System.out.println(reader.readLine());
            }
        } catch (IOException e) {
            System.out.println("IO error: " + e.getMessage());
        }
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "What happens if `close()` throws and the try block also throws?" — `close()` exception is suppressed on the try block exception. Access via `e.getSuppressed()`.
- "In what order are multiple resources closed?" — Reverse declaration order, like a stack.
- "Can you use try-with-resources with a `null` resource?" — If the resource variable is null, `close()` is not called. No NPE. (Java 9+ behavior — the JLS explicitly handles null resources.)

---

### Common Mistakes Candidates Make

- Thinking that try-with-resources prevents exceptions from `close()` — it doesn't prevent them, it attaches them as suppressed.
- Not knowing suppressed exceptions exist and failing to log them.
- Using the old finally-close pattern with JDBC when try-with-resources is cleaner.

---

### Interview Traps

**Trap:** "What if you null-check the resource after declaring it in try header — is that valid?"
Answer: You can't null-check inside the try-with-resources header. If the constructor returns null (unusual) or you use a factory that could return null, use a conditional before the try block or handle it differently. Since Java 9, you can use an existing nullable variable in `try (var)` — if it's null, close is skipped.

---

### Quick Revision Notes

- try-with-resources: automatically calls `close()` in reverse declaration order.
- Requires `AutoCloseable` (or `Closeable`) implementation.
- If try body throws and `close()` also throws: `close()` exception is SUPPRESSED on primary.
- Java 9: effectively final variables usable without re-declaration in try header.
- `Throwable.getSuppressed()` retrieves suppressed exceptions.

---

## 15. Multi-catch

**Difficulty:** Easy | **Interview Frequency:** Medium

**Companies:** Amazon, Cognizant, Infosys, Accenture

---

### Short Interview Answer (30–60 seconds)

Java 7 introduced multi-catch syntax — `catch (IOException | SQLException e)` — to handle multiple exception types in one catch block without duplicating code. The variable `e` is implicitly `final` in a multi-catch block, preventing reassignment. This is purely a syntactic convenience; the compiler generates separate catch blocks in bytecode.

---

### Deep Explanation

**Rules:**

1. The exception types must not be in an inheritance relationship. `catch (Exception | IOException e)` is a compile error because `IOException` is a subtype of `Exception` — the `IOException` branch is redundant.
2. `e` is effectively final — you cannot assign to it inside the multi-catch block.
3. The type of `e` is the most specific common supertype of the listed exceptions.

**When to use:**

- When two unrelated exception types require identical handling (logging, rethrowing, mapping to HTTP error).
- To eliminate copy-paste catch blocks that do the same thing.

**When NOT to use:**

- When each exception type requires different handling. Use separate catch blocks.

**Compiler output:**

The compiler generates a single bytecode handler entry that matches both exception types. The exception variable is effectively treated as the LUB (Least Upper Bound) of the types.

---

### Real-World Backend Example

A data import service tries to parse a record and persist it. Both `ParseException` and `DataIntegrityViolationException` (unchecked) mean "this record is bad, skip it and log". A multi-catch handles both identically.

---

### Java 17 Code Example

```java
import java.io.IOException;
import java.sql.SQLException;
import java.text.ParseException;

public class MultiCatchDemo {

    static void processRecord(String record) throws IOException, SQLException, ParseException {
        if (record.startsWith("IO"))   throw new IOException("IO error");
        if (record.startsWith("SQL"))  throw new SQLException("SQL error");
        if (record.startsWith("PARSE")) throw new ParseException("Parse error", 0);
        System.out.println("Processed: " + record);
    }

    public static void main(String[] args) {
        String[] records = {"OK_record", "IO_bad", "SQL_bad", "PARSE_bad"};

        for (String record : records) {
            try {
                processRecord(record);
            } catch (IOException | SQLException e) {
                // Handles both — same action: log and continue
                System.out.println("Infrastructure error for [" + record + "]: " + e.getMessage());
                // e = new IOException("x"); // COMPILE ERROR — e is effectively final
            } catch (ParseException e) {
                // Different handling for parse errors
                System.out.println("Parse error at offset " + e.getErrorOffset() + " for: " + record);
            }
        }

        // Compile error example (commented out):
        // catch (Exception | IOException e) {} // IOException is subtype of Exception
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "What is the type of `e` in `catch (IOException | SQLException e)`?" — The LUB, which is `Exception` (since both extend `Exception` and there's no closer common ancestor that both share in the standard library).
- "Why can't you reassign `e` in a multi-catch?" — Because the compiler must statically know the exact type at the point of use. If you could reassign `e` to a new `IOException` in a block that also handles `SQLException`, the type system would be inconsistent.

---

### Common Mistakes Candidates Make

- Trying to catch a parent and child in the same multi-catch.
- Trying to reassign `e` and getting confused by the compile error.

---

### Interview Traps

**Trap:** Is `catch (Exception | RuntimeException e)` valid?
Answer: No — `RuntimeException` is a subtype of `Exception`. Compile error: "Alternatives in a multi-catch statement cannot be related by subclassing."

---

### Quick Revision Notes

- `catch (A | B e)`: handles A and B in one block.
- A and B must not be in a parent-child relationship.
- `e` is effectively final.
- Compiler generates separate bytecode handlers — purely syntactic sugar.

---

## 16. Custom Exceptions

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Google, Stripe, Razorpay, ThoughtWorks

---

### Short Interview Answer (30–60 seconds)

Custom exceptions should extend `RuntimeException` for most modern application code — they propagate freely without forcing callers to declare them, which is especially important in Spring applications with global exception handlers. Extend `Exception` (checked) only when callers genuinely must be forced to handle the condition. Always include a constructor that accepts a cause (another Throwable) to preserve the exception chain.

---

### Deep Explanation

**Naming conventions:**

- Name ends in `Exception`: `OrderNotFoundException`, `InsufficientFundsException`.
- Package: `com.myapp.exception` or module-specific.

**Minimum constructors to include:**

```java
public class OrderNotFoundException extends RuntimeException {
    public OrderNotFoundException(String message) { super(message); }
    public OrderNotFoundException(String message, Throwable cause) { super(message, cause); }
}
```

Omitting the `cause` constructor is a common mistake that forces callers to use `initCause()` separately.

**Including domain context:**

Add fields for entity ID, error codes, or other structured data that frameworks (Spring's `@ControllerAdvice`) can use to build structured error responses.

**Exception codes for API responses:**

Many enterprise APIs return machine-readable error codes. The custom exception can carry the code as a field, mapped to a problem detail response (RFC 7807).

**Serializable consideration:**

If you plan to serialize exceptions (e.g., sending them over RMI or storing them), implement `Serializable` and define `serialVersionUID`. In most REST/microservice contexts this is not needed.

---

### Real-World Backend Example

A Spring Boot order service throws `OrderNotFoundException(orderId)` from the service layer. A `@ControllerAdvice` catches it and returns HTTP 404 with a structured JSON body containing the error code and order ID. The controller methods don't catch this exception at all — the global handler does the work.

---

### Java 17 Code Example

```java
// Custom unchecked exception with domain context
public class OrderNotFoundException extends RuntimeException {

    private final String orderId;
    private final String errorCode;

    public OrderNotFoundException(String orderId) {
        super("Order not found: " + orderId);
        this.orderId = orderId;
        this.errorCode = "ORDER_NOT_FOUND";
    }

    public OrderNotFoundException(String orderId, Throwable cause) {
        super("Order not found: " + orderId, cause);
        this.orderId = orderId;
        this.errorCode = "ORDER_NOT_FOUND";
    }

    public String getOrderId() { return orderId; }
    public String getErrorCode() { return errorCode; }
}

// Custom checked exception — use when caller MUST handle it
public class InsufficientFundsException extends Exception {

    private final double amount;
    private final double balance;

    public InsufficientFundsException(double amount, double balance) {
        super(String.format(
            "Insufficient funds: requested %.2f, available %.2f", amount, balance));
        this.amount = amount;
        this.balance = balance;
    }

    public InsufficientFundsException(double amount, double balance, Throwable cause) {
        super(String.format(
            "Insufficient funds: requested %.2f, available %.2f", amount, balance), cause);
        this.amount = amount;
        this.balance = balance;
    }

    public double getAmount() { return amount; }
    public double getBalance() { return balance; }
}

// Service using custom exceptions
public class OrderServiceDemo {

    static String findOrder(String orderId) {
        if (orderId == null || orderId.isBlank()) {
            throw new IllegalArgumentException("Order ID must not be blank");
        }
        if (orderId.startsWith("UNKNOWN")) {
            throw new OrderNotFoundException(orderId);
        }
        return "Order[" + orderId + "]";
    }

    static void processPayment(double amount, double balance) throws InsufficientFundsException {
        if (amount > balance) {
            throw new InsufficientFundsException(amount, balance);
        }
        System.out.println("Payment processed: " + amount);
    }

    public static void main(String[] args) {
        // Unchecked — no catch required
        try {
            findOrder("UNKNOWN-123");
        } catch (OrderNotFoundException e) {
            System.out.println("Code: " + e.getErrorCode());
            System.out.println("ID:   " + e.getOrderId());
            System.out.println("Msg:  " + e.getMessage());
        }

        // Checked — must handle
        try {
            processPayment(500.0, 100.0);
        } catch (InsufficientFundsException e) {
            System.out.printf("Need %.2f more%n", e.getAmount() - e.getBalance());
        }
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "Why include a constructor with a `Throwable cause`?" — To support exception chaining — the original cause is preserved in the stack trace. Without it, the root cause is lost.
- "Should you always extend RuntimeException?" — In modern Spring/Jakarta EE code, almost always yes. Extend `Exception` only for truly recoverable, caller-acknowledged conditions.
- "What fields should a custom exception have for a REST API?" — Error code (machine-readable), message (human-readable), timestamp, offending entity ID. Avoid exposing internal details.

---

### Common Mistakes Candidates Make

- Not including a constructor with a `Throwable cause` parameter.
- Putting too much sensitive information in the exception message (it may be logged or returned to the client).
- Extending `Exception` (checked) for domain exceptions in Spring applications, forcing `throws` declarations everywhere.

---

### Interview Traps

**Trap:** Why not just use `IllegalArgumentException` or `RuntimeException` everywhere instead of custom exceptions?
Answer: Custom exceptions allow precise exception handling — a `@ControllerAdvice` can catch `OrderNotFoundException` specifically and return 404, while `ProductNotFoundException` returns 404 with a different body. Generic `RuntimeException` forces the handler to parse the message string, which is fragile.

---

### Quick Revision Notes

- Custom exceptions: extend `RuntimeException` for most modern code.
- Always provide a `(String message, Throwable cause)` constructor.
- Add domain fields (entity ID, error code) for structured error responses.
- Extend `Exception` (checked) only when callers genuinely must handle it.
- Name ends in `Exception`; place in a dedicated package.

---

## 17. Exception Chaining

**Difficulty:** Medium | **Interview Frequency:** Medium

**Companies:** Google, Amazon, Oracle, ThoughtWorks

---

### Short Interview Answer (30–60 seconds)

Exception chaining preserves the original cause when you catch one exception and throw another. Pass the original exception as the `cause` parameter in the new exception's constructor. Without chaining, you lose the original stack trace — debugging becomes much harder. The root cause is retrievable via `getCause()` and appears in the printed stack trace under "Caused by:".

---

### Deep Explanation

**Why chain exceptions:**

In a layered architecture (Controller → Service → DAO), a `SQLException` from the DAO should not bubble up to the controller (it would expose database details). The DAO catches it and throws a `DataAccessException` wrapping the original. The controller catches `DataAccessException`, but the full diagnostic chain (including the original SQL and stack frame) is preserved in the cause.

**Two ways to chain:**

1. Constructor: `throw new ServiceException("message", originalException);` — preferred.
2. `initCause()`: `exception.initCause(originalException)` — used when the exception class doesn't have a cause constructor. Can only be called once.

**What is lost without chaining:**

```java
// BAD — stack trace is lost
} catch (SQLException e) {
    throw new DataAccessException(e.getMessage()); // no cause
}
```

The `DataAccessException` will only show the DAO layer stack frame; the original SQL exception and its stack trace disappear.

**Reading a chained stack trace:**

```
Exception in thread "main" com.app.ServiceException: Failed to load order
    at com.app.OrderService.load(OrderService.java:45)
    at com.app.OrderController.getOrder(OrderController.java:30)
Caused by: java.sql.SQLException: Connection refused
    at com.jdbc.Driver.connect(Driver.java:120)
    ...
```

The "Caused by:" section shows the original exception.

**Cause chains can be arbitrarily deep.** `getCause()` returns null when the end is reached.

---

### Real-World Backend Example

A Spring Data repository wraps `java.sql.SQLIntegrityConstraintViolationException` in a `DataIntegrityViolationException`. The service layer catches that and throws a `DuplicateEmailException` (chaining the DataIntegrityViolationException as cause). The controller sees only `DuplicateEmailException` and returns HTTP 409, but the full chain is in the logs.

---

### Java 17 Code Example

```java
import java.sql.SQLException;

public class ExceptionChainingDemo {

    // Simulated DAO layer
    static void loadFromDB(String orderId) throws SQLException {
        throw new SQLException("Connection timeout for query: SELECT * FROM orders WHERE id='" + orderId + "'");
    }

    // Service layer — chains exception
    static String getOrder(String orderId) {
        try {
            loadFromDB(orderId);
            return "order data";
        } catch (SQLException e) {
            // GOOD: chain the cause
            throw new RuntimeException("Failed to retrieve order: " + orderId, e);
        }
    }

    // BAD version — loses original stack trace
    static String getOrderBad(String orderId) {
        try {
            loadFromDB(orderId);
            return "order data";
        } catch (SQLException e) {
            throw new RuntimeException(e.getMessage()); // root cause is GONE
        }
    }

    // Using initCause() — needed for old exception classes without cause constructor
    static void legacyChaining(String orderId) {
        try {
            loadFromDB(orderId);
        } catch (SQLException e) {
            RuntimeException wrapped = new RuntimeException("Legacy error: " + orderId);
            wrapped.initCause(e); // alternative to constructor
            throw wrapped;
        }
    }

    public static void main(String[] args) {
        // Good chaining — full cause chain visible
        try {
            getOrder("ORD-001");
        } catch (RuntimeException e) {
            System.out.println("Exception: " + e.getMessage());
            System.out.println("Cause: " + e.getCause().getMessage());
            System.out.println("Root cause class: " + e.getCause().getClass().getSimpleName());

            // Walk the full chain
            Throwable t = e;
            int depth = 0;
            while (t != null) {
                System.out.printf("Depth %d: [%s] %s%n",
                    depth++, t.getClass().getSimpleName(), t.getMessage());
                t = t.getCause();
            }
        }

        System.out.println("---");

        // Bad chaining — cause is lost
        try {
            getOrderBad("ORD-002");
        } catch (RuntimeException e) {
            System.out.println("Exception: " + e.getMessage());
            System.out.println("Cause: " + e.getCause()); // null — original SQLException gone
        }
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "Can a cause itself have a cause?" — Yes. Cause chains can be arbitrary depth. Circular cause chains are detected and printed safely by `printStackTrace()`.
- "When would you use `initCause()` over the constructor?" — When working with legacy exception classes that predate Java 1.4 and don't have a constructor accepting `Throwable`. For new exceptions, always add a cause constructor.

---

### Common Mistakes Candidates Make

- `throw new RuntimeException(e.getMessage())` — loses the stack trace. Always pass `e` directly, not `e.getMessage()`.
- Not knowing `getCause()` exists.
- Deep DAO-level exceptions surfacing all the way to the API response body — always translate at layer boundaries.

---

### Interview Traps

**Trap:** What is the difference between `throw new Exception(e)` and `throw new Exception(e.getMessage())`?
Answer: `new Exception(e)` chains the original exception — `getCause()` returns `e`, full stack trace preserved. `new Exception(e.getMessage())` creates a new exception with just the message string — cause is null, original stack trace lost.

---

### Quick Revision Notes

- Always pass the original exception as the `cause` parameter.
- `throw new AppException("msg", originalException)` — preserves full chain.
- `throw new AppException(e.getMessage())` — loses root cause. Never do this.
- Access cause chain via `getCause()` (returns null at the root).
- Stack trace shows "Caused by:" for each level in the chain.

---

## 18. Common Exception Mistakes

**Difficulty:** Medium | **Interview Frequency:** High

**Companies:** Amazon, Google, ThoughtWorks, Stripe, Atlassian

---

### Short Interview Answer (30–60 seconds)

The most dangerous exception anti-patterns are: swallowing exceptions silently (empty catch block), catching `Throwable` or `Exception` too broadly, using exceptions for control flow (performance and readability problem), and losing the original stack trace by reconstructing exceptions from just the message.

---

### Deep Explanation

**1. Swallowing exceptions (most harmful):**

```java
try {
    doSomething();
} catch (Exception e) {
    // silence — nothing happens
}
```

The application continues in an inconsistent state with no diagnostic information. Every exception should at minimum be logged. If you genuinely want to ignore an exception (rare), add a comment explaining why.

**2. Catching `Throwable` or `Exception`:**

Catching `Throwable` means you catch `OutOfMemoryError`, `StackOverflowError`, etc. The JVM is now in an undefined state and you may make things worse. Catching `Exception` catches `InterruptedException`, suppressing thread interruption signals.

Special case for `InterruptedException`: 
```java
try {
    Thread.sleep(1000);
} catch (InterruptedException e) {
    Thread.currentThread().interrupt(); // MUST restore the interrupt flag
}
```

**3. Using exceptions for flow control:**

```java
// BAD: using exception for expected case
try {
    return map.get(key); // throws if null? No, but simulating
} catch (NullPointerException e) {
    return defaultValue;
}
```

Exceptions are expensive: creating a `Throwable` captures the full stack trace. Use `if/else` or `map.getOrDefault()` for expected conditions.

**4. Losing stack trace:**

```java
} catch (Exception e) {
    throw new ServiceException(e.getMessage()); // stack trace gone
}
// Correct:
    throw new ServiceException("context info", e); // chain preserved
```

**5. `printStackTrace()` in production:**

Prints to stderr. In production, stderr may be ignored, not captured by the logging framework, or written to a separate file. Always use `log.error("message", e)`.

**6. Catching exception and re-throwing the same type without adding value:**

```java
try { ... }
catch (IOException e) { throw e; } // pointless — just let it propagate
```

Unless you need a finally block, there's no reason to catch and re-throw identically.

**7. Broad `throws Exception` declarations:**

```java
public void process() throws Exception { ... }
```

Forces every caller to handle or re-declare `Exception`. Defeats the purpose of checked exception specificity. Declare the specific exception types.

---

### Real-World Backend Example

A legacy batch processor had `catch (Exception e) {}` throughout the codebase. When the database schema changed and all queries started throwing `SQLException`, the application silently processed nothing for hours before anyone noticed from the business metrics — no logs, no alerts.

---

### Java 17 Code Example

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.util.concurrent.BlockingQueue;

public class ExceptionAntiPatternsDemo {

    private static final Logger log = LoggerFactory.getLogger(ExceptionAntiPatternsDemo.class);

    // ANTI-PATTERN 1: swallowing exception
    static void antiPattern1(String data) {
        try {
            process(data);
        } catch (Exception e) {
            // silently ignored — NEVER DO THIS
        }
    }

    // FIX 1: at minimum, log it
    static void fix1(String data) {
        try {
            process(data);
        } catch (Exception e) {
            log.error("Failed to process data: {}", data, e);
            // rethrow or handle gracefully
        }
    }

    // ANTI-PATTERN 2: swallowing InterruptedException
    static void antiPattern2() {
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            // interrupt flag is now cleared — thread will never know it was interrupted
        }
    }

    // FIX 2: restore interrupt flag
    static void fix2() {
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt(); // restore interrupt status
            log.warn("Thread interrupted during sleep", e);
        }
    }

    // ANTI-PATTERN 3: using exception for flow control
    static int antiPattern3(String s) {
        try {
            return Integer.parseInt(s);
        } catch (NumberFormatException e) {
            return -1; // exception used as if/else — expensive stack capture
        }
    }

    // FIX 3: check before parsing
    static int fix3(String s) {
        if (s == null || !s.matches("-?\\d+")) return -1;
        return Integer.parseInt(s);
    }

    // ANTI-PATTERN 4: losing stack trace
    static void antiPattern4() throws Exception {
        try {
            loadData();
        } catch (Exception e) {
            throw new RuntimeException(e.getMessage()); // root cause GONE
        }
    }

    // FIX 4: chain the exception
    static void fix4() throws Exception {
        try {
            loadData();
        } catch (Exception e) {
            throw new RuntimeException("Failed during load", e); // cause preserved
        }
    }

    // ANTI-PATTERN 5: catching Throwable
    static void antiPattern5() {
        try {
            heavyOperation();
        } catch (Throwable t) {
            // catches OutOfMemoryError, StackOverflowError — JVM may be compromised
            log.error("Caught Throwable", t); // dangerous to continue
        }
    }

    // Helpers
    static void process(String data) { /* ... */ }
    static void loadData() throws Exception { throw new Exception("DB down"); }
    static void heavyOperation() { /* ... */ }

    public static void main(String[] args) {
        // Demonstrate fix3 vs antiPattern3
        System.out.println(fix3("123"));     // 123
        System.out.println(fix3("abc"));     // -1 (no exception)
        System.out.println(antiPattern3("abc")); // -1 (via exception — slower)
    }
}
```

---

### Follow-up Questions Interviewers Ask

- "Is it ever acceptable to have an empty catch block?" — Rarely. One documented case: catching `InterruptedException` when you're in a context where you cannot propagate it and have restored the interrupt flag. Always add a comment.
- "What is the performance cost of throwing an exception?" — Capturing the stack trace in the Throwable constructor is the expensive operation. On a hot path, this can be 1000x slower than a simple if/else check.
- "When is catching `Throwable` acceptable?" — In thread pool executors or top-level server loop to prevent thread death. Must log and possibly restart. Very rare and deliberate.

---

### Common Mistakes Candidates Make

- Not restoring the interrupt flag after catching `InterruptedException`.
- Logging `e.getMessage()` without the exception object — loses stack trace in logs.
- Using `e.printStackTrace()` instead of a logger.

---

### Interview Traps

**Trap:** `log.error(e.getMessage())` — is this sufficient for production logging?
Answer: No. It logs only the message string, not the stack trace. Use `log.error("description", e)` — the exception object as the second argument tells SLF4J/Logback to append the full stack trace.

---

### Quick Revision Notes

- Never swallow exceptions silently.
- Always restore interrupt flag after catching `InterruptedException`.
- Never use exceptions for expected flow control — use conditionals.
- Always chain exceptions: pass `e` not `e.getMessage()`.
- Use `log.error("msg", e)` not `e.printStackTrace()`.
- Avoid catching `Throwable` except in framework-level thread management.

---

## 19. Comparison Tables

### Strings

| Topic | Key Point |
|---|---|
| Immutability | `private final byte[] value` + `byte coder` (Java 9+); no mutating methods |
| String Pool | Main heap (since Java 7); GC'd; intern() adds to pool |
| `==` vs `equals()` | `==` = reference; `equals()` = content; always use `equals()` |
| StringBuilder | Unsynchronized, fast; single-thread string building |
| StringBuffer | Synchronized, slower; rarely needed in modern code |
| `substring()` | Copies array since Java 7u6; no more memory leak |
| `split()` | Takes regex; escape `.` as `\\.` |
| `strip()` vs `trim()` | `strip()` is Unicode-aware (Java 11); prefer over `trim()` |
| Integer.parseInt | Returns `int`; throws NFE on invalid input; does not handle whitespace |
| Integer.valueOf | Returns `Integer`; uses cache for -128–127 |

---

### Wrapper Classes

| Topic | Key Point |
|---|---|
| Autoboxing | `int` → `Integer` via `Integer.valueOf()`; overhead in hot loops |
| Unboxing | `Integer` → `int` via `intValue()`; null unboxing = NPE |
| Integer cache | -128 to 127; `==` works in this range but is still bad practice |
| Double/Float cache | No cache; `==` is always reference comparison |
| Comparable | Natural ordering inside the class; TreeSet/TreeMap use it |
| Comparator | External ordering; Java 8 chaining: `thenComparing`, `reversed` |
| Comparator pitfall | Never subtract ints; use `Integer.compare()` |

---

### Exceptions

| Topic | Key Point |
|---|---|
| Hierarchy | `Throwable` → `Error` + `Exception` → `RuntimeException` |
| Checked | Compiler-enforced; use for recoverable conditions |
| Unchecked | RuntimeException; preferred in Spring/functional code |
| finally | Always runs (except `System.exit()`); return in finally overrides try |
| try-with-resources | Auto-closes in reverse order; close() failures → suppressed exceptions |
| Multi-catch | `catch (A \| B e)`; A and B must not be related; `e` is effectively final |
| Custom exceptions | Extend RuntimeException; always include (msg, cause) constructor |
| Exception chaining | Pass `e` not `e.getMessage()`; use getCause() to walk chain |
| Swallowing | Worst anti-pattern; always at least log the exception |
| InterruptedException | MUST restore interrupt flag: `Thread.currentThread().interrupt()` |

---

### String Pool vs Heap

| Scenario | Location | Pool Reference? |
|---|---|---|
| `String s = "hello"` | Pool (heap) | Yes |
| `String s = new String("hello")` | Heap | No |
| `"hel" + "lo"` (compile-time) | Pool | Yes |
| `"hel" + variable` | Heap | No |
| `s.intern()` on heap string | Returns pool ref | Yes |

---

### StringBuilder vs StringBuffer vs String

| | String | StringBuilder | StringBuffer |
|---|---|---|---|
| Mutable | No | Yes | Yes |
| Thread-safe | Yes (immutable) | No | Yes (synchronized) |
| Performance | New object per mutation | Best | Medium (lock overhead) |
| Since | Java 1.0 | Java 1.5 | Java 1.0 |
| Use for | Constants, keys, params | Single-thread building | Legacy shared buffers |

---

### Exception Decision Guide

| Situation | Recommendation |
|---|---|
| Caller must acknowledge failure | Checked Exception |
| Programming bug (null, bad arg) | Unchecked (IllegalArgumentException, etc.) |
| Business rule violation | Custom RuntimeException |
| Cross-layer translation | Chain with cause |
| Use in lambdas/streams | Unchecked (or UncheckedIOException) |
| Spring service/DAO layer | RuntimeException (DataAccessException pattern) |
| JVM/system failure | Error (don't catch) |

---

*End of Chapter 2 — Strings, Wrapper Classes, and Exceptions*

*Next: Chapter 3 — Collections Framework (List, Map, Set, Queue — internals, complexity, thread safety)*

