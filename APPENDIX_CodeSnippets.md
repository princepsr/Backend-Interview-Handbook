# Appendix C: Must-Know Code Snippets

*Curated production-ready patterns organized by category. Every snippet here has appeared in real FAANG+ interviews.*

---

## Category 1: Core Java Patterns

### 1.1 Thread-Safe Singleton (3 approaches)

```java
// APPROACH 1: Enum Singleton — preferred; JVM guarantees single instance, serialization-safe
public enum DatabaseConnection {
    INSTANCE;

    private final Connection connection;

    DatabaseConnection() {
        this.connection = createConnection();
    }

    private Connection createConnection() {
        // initialize connection
        return null;
    }

    public Connection getConnection() {
        return connection;
    }
}
// Usage: DatabaseConnection.INSTANCE.getConnection()
```

```java
// APPROACH 2: Double-Checked Locking — use when enum is not possible (e.g., needs inheritance)
public class ConfigManager {
    // volatile prevents instruction reordering — critical for DCL correctness
    private static volatile ConfigManager instance;
    private final Map<String, String> config;

    private ConfigManager() {
        this.config = loadConfig();
    }

    public static ConfigManager getInstance() {
        if (instance == null) {                    // first check (no lock)
            synchronized (ConfigManager.class) {
                if (instance == null) {            // second check (with lock)
                    instance = new ConfigManager();
                }
            }
        }
        return instance;
    }

    private Map<String, String> loadConfig() {
        return new HashMap<>();
    }

    public String get(String key) {
        return config.get(key);
    }
}
```

```java
// APPROACH 3: Bill Pugh Holder — lazy init without synchronization overhead
public class MetricsRegistry {
    private MetricsRegistry() {}

    // Inner class is not loaded until getInstance() is called; class loader guarantees thread safety
    private static class Holder {
        static final MetricsRegistry INSTANCE = new MetricsRegistry();
    }

    public static MetricsRegistry getInstance() {
        return Holder.INSTANCE;
    }

    public void record(String metric, long value) {
        // record metric
    }
}
```

---

### 1.2 Immutable Class

```java
// Immutable class: final class + final fields + defensive copy in constructor AND getter
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;

public final class Order {                          // final: prevents subclassing
    private final String orderId;
    private final Date createdAt;                   // mutable — must be defensively copied
    private final List<String> items;               // mutable — must be defensively copied

    public Order(String orderId, Date createdAt, List<String> items) {
        this.orderId = orderId;
        this.createdAt = new Date(createdAt.getTime());  // defensive copy in constructor
        this.items = new ArrayList<>(items);              // defensive copy in constructor
    }

    public String getOrderId() {
        return orderId;                              // String is immutable — no copy needed
    }

    public Date getCreatedAt() {
        return new Date(createdAt.getTime());        // defensive copy in getter
    }

    public List<String> getItems() {
        return Collections.unmodifiableList(items); // unmodifiable view in getter
    }

    @Override
    public String toString() {
        return "Order{orderId='" + orderId + "', createdAt=" + createdAt + ", items=" + items + "}";
    }
}
```

---

### 1.3 Custom Comparable + Comparator

```java
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;

// Implement Comparable for natural ordering (e.g., by salary)
public class Employee implements Comparable<Employee> {
    private final String name;
    private final String department;
    private final double salary;

    public Employee(String name, String department, double salary) {
        this.name = name;
        this.department = department;
        this.salary = salary;
    }

    @Override
    public int compareTo(Employee other) {
        return Double.compare(this.salary, other.salary); // natural order: ascending salary
    }

    public String getName()       { return name; }
    public String getDepartment() { return department; }
    public double getSalary()     { return salary; }

    @Override
    public String toString() {
        return name + "(" + salary + ")";
    }

    public static void main(String[] args) {
        List<Employee> employees = Arrays.asList(
            new Employee("Alice", "Eng",  95000),
            new Employee("Bob",   "HR",   75000),
            new Employee("Carol", "Eng", 105000)
        );

        // 1. Natural order (Comparable): sort by salary ascending
        employees.sort(null);
        System.out.println("Natural: " + employees);

        // 2. Lambda Comparator: sort by name
        employees.sort((e1, e2) -> e1.getName().compareTo(e2.getName()));
        System.out.println("By name: " + employees);

        // 3. Method reference Comparator: sort by department
        employees.sort(Comparator.comparing(Employee::getDepartment));
        System.out.println("By dept: " + employees);

        // 4. Chained Comparator: sort by department, then salary descending
        employees.sort(
            Comparator.comparing(Employee::getDepartment)
                      .thenComparing(Comparator.comparingDouble(Employee::getSalary).reversed())
        );
        System.out.println("By dept+salary desc: " + employees);
    }
}
```

---

### 1.4 Generic Bounded Type

```java
import java.util.ArrayList;
import java.util.List;

// Generic stack bounded by Comparable — enables min() without external comparator
public class BoundedStack<T extends Comparable<T>> {
    private final List<T> elements = new ArrayList<>();

    public void push(T item) {
        elements.add(item);
    }

    public T pop() {
        if (elements.isEmpty()) throw new RuntimeException("Stack is empty");
        return elements.remove(elements.size() - 1);
    }

    public T peek() {
        if (elements.isEmpty()) throw new RuntimeException("Stack is empty");
        return elements.get(elements.size() - 1);
    }

    public T min() {
        return elements.stream().min(Comparable::compareTo)
                       .orElseThrow(() -> new RuntimeException("Stack is empty"));
    }

    // PECS: Producer Extends — copy FROM a source list (we read/produce values from src)
    public void pushAll(List<? extends T> src) {
        for (T item : src) push(item);
    }

    // PECS: Consumer Super — copy INTO a destination list (dest consumes values)
    public void popAll(List<? super T> dest) {
        while (!elements.isEmpty()) {
            dest.add(pop());
        }
    }

    public static void main(String[] args) {
        BoundedStack<Integer> stack = new BoundedStack<>();

        // Producer extends: can push from List<Integer> or List<Integer subtype>
        List<Integer> source = List.of(3, 1, 4, 1, 5);
        stack.pushAll(source);
        System.out.println("Min: " + stack.min()); // 1

        // Consumer super: can pop into List<Integer> or List<Number> or List<Object>
        List<Number> dest = new ArrayList<>();
        stack.popAll(dest);
        System.out.println("Dest: " + dest);
    }
}
```

---

### 1.5 CompletableFuture Chain

```java
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

public class CompletableFuturePatterns {

    // 1. Sequential async: thenApply (same thread) → thenCompose (new async stage)
    public CompletableFuture<String> fetchUserProfile(long userId) {
        return CompletableFuture
            .supplyAsync(() -> fetchUser(userId))          // async: fetch user
            .thenApply(user -> user.toUpperCase())         // sync transform (same thread)
            .thenCompose(user ->                           // chains new async stage
                CompletableFuture.supplyAsync(() -> enrichWithPreferences(user)));
    }

    // 2. Parallel async: allOf waits for all, then join collects results
    public CompletableFuture<List<String>> fetchAll(List<Long> userIds) {
        List<CompletableFuture<String>> futures = userIds.stream()
            .map(id -> CompletableFuture.supplyAsync(() -> fetchUser(id)))
            .toList();

        return CompletableFuture
            .allOf(futures.toArray(new CompletableFuture[0]))
            .thenApply(v -> futures.stream().map(CompletableFuture::join).toList());
    }

    // 3. Exception handling: exceptionally for recovery, handle for both paths
    public CompletableFuture<String> fetchWithFallback(long userId) {
        return CompletableFuture
            .supplyAsync(() -> fetchUser(userId))
            .exceptionally(ex -> "ANONYMOUS")             // recover on failure
            .handle((result, ex) -> {                     // always runs; ex==null on success
                if (ex != null) return "ERROR: " + ex.getMessage();
                return result.toUpperCase();
            });
    }

    // 4. Timeout (Java 9+): orTimeout throws, completeOnTimeout provides default
    public CompletableFuture<String> fetchWithTimeout(long userId) {
        return CompletableFuture
            .supplyAsync(() -> fetchUser(userId))
            .orTimeout(500, TimeUnit.MILLISECONDS)         // throws TimeoutException after 500ms
            // .completeOnTimeout("DEFAULT", 500, TimeUnit.MILLISECONDS) // returns default instead
            .exceptionally(ex -> "TIMEOUT_FALLBACK");
    }

    private String fetchUser(long id) { return "user_" + id; }
    private String enrichWithPreferences(String user) { return user + "_enriched"; }
}
```

---

### 1.6 Custom Functional Interface + Lambda

```java
import java.util.Arrays;
import java.util.List;
import java.util.function.Function;

// Custom @FunctionalInterface with default and static methods
@FunctionalInterface
public interface Transformer<T, R> {
    R transform(T input);                            // single abstract method

    default <V> Transformer<T, V> andThen(Transformer<R, V> after) {
        return input -> after.transform(this.transform(input));
    }

    static <T> Transformer<T, T> identity() {
        return input -> input;
    }
}

class MethodReferenceDemo {
    // All 4 types of method references
    public static void main(String[] args) {
        // 1. Static method reference: ClassName::staticMethod
        Transformer<String, Integer> parseLen = String::length;  // String.length() is instance, but:
        Function<String, Integer>    parseInt  = Integer::parseInt; // static method ref

        // 2. Instance method on arbitrary instance: ClassName::instanceMethod
        Transformer<String, String>  toUpper = String::toUpperCase;

        // 3. Instance method on particular instance: instance::instanceMethod
        String prefix = "Hello_";
        Transformer<String, String>  addPrefix = prefix::concat;

        // 4. Constructor reference: ClassName::new
        Transformer<String, StringBuilder> toSB = StringBuilder::new;

        // Compose with andThen
        Transformer<String, String> pipeline = toUpper.andThen(addPrefix);

        List<String> words = Arrays.asList("world", "java", "lambda");
        words.stream()
             .map(pipeline::transform)
             .forEach(System.out::println);
        // HELLO_WORLD, HELLO_JAVA, HELLO_LAMBDA
    }
}
```

---

### 1.7 Producer-Consumer with BlockingQueue

```java
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.TimeUnit;

// Classic producer-consumer: BlockingQueue handles all synchronization automatically
public class ProducerConsumerDemo {
    private static final String POISON_PILL = "POISON";
    private final BlockingQueue<String> queue;

    public ProducerConsumerDemo(int capacity) {
        this.queue = new ArrayBlockingQueue<>(capacity);
    }

    class Producer implements Runnable {
        private final String[] messages;

        Producer(String... messages) { this.messages = messages; }

        @Override
        public void run() {
            try {
                for (String msg : messages) {
                    queue.put(msg);                         // blocks if queue is full
                    System.out.println("Produced: " + msg);
                    Thread.sleep(100);
                }
                queue.put(POISON_PILL);                     // signal shutdown
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    class Consumer implements Runnable {
        @Override
        public void run() {
            try {
                while (true) {
                    String msg = queue.take();              // blocks if queue is empty
                    if (POISON_PILL.equals(msg)) break;    // graceful shutdown
                    System.out.println("Consumed: " + msg);
                    Thread.sleep(200);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    public static void main(String[] args) throws InterruptedException {
        ProducerConsumerDemo demo = new ProducerConsumerDemo(5);
        Thread producer = new Thread(demo.new Producer("A", "B", "C", "D", "E"));
        Thread consumer = new Thread(demo.new Consumer());
        producer.start();
        consumer.start();
        producer.join();
        consumer.join();
    }
}
```

---

### 1.8 Deadlock Example + Fix

```java
// DEADLOCK: Thread1 locks A then B; Thread2 locks B then A — circular wait
public class DeadlockDemo {
    private final Object lockA = new Object();
    private final Object lockB = new Object();

    // Thread 1: acquires A, then tries B
    public void method1() {
        synchronized (lockA) {
            System.out.println(Thread.currentThread().getName() + " holds A, waiting for B");
            synchronized (lockB) { System.out.println("method1 complete"); }
        }
    }

    // Thread 2: acquires B, then tries A — DEADLOCK with method1
    public void method2() {
        synchronized (lockB) {
            System.out.println(Thread.currentThread().getName() + " holds B, waiting for A");
            synchronized (lockA) { System.out.println("method2 complete"); }
        }
    }
}

// FIX: Consistent lock ordering — always acquire A before B in both methods
public class DeadlockFixed {
    private final Object lockA = new Object();
    private final Object lockB = new Object();

    public void method1() {
        synchronized (lockA) {                             // always A first
            synchronized (lockB) {
                System.out.println("method1 complete");
            }
        }
    }

    public void method2() {
        synchronized (lockA) {                             // always A first — no circular wait
            synchronized (lockB) {
                System.out.println("method2 complete");
            }
        }
    }
}

// ALTERNATIVE FIX: Use tryLock with timeout to avoid indefinite blocking
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;
import java.util.concurrent.TimeUnit;

public class DeadlockFixedTryLock {
    private final Lock lockA = new ReentrantLock();
    private final Lock lockB = new ReentrantLock();

    public boolean transfer() throws InterruptedException {
        while (true) {
            if (lockA.tryLock(50, TimeUnit.MILLISECONDS)) {
                try {
                    if (lockB.tryLock(50, TimeUnit.MILLISECONDS)) {
                        try {
                            // do work
                            return true;
                        } finally { lockB.unlock(); }
                    }
                } finally { lockA.unlock(); }
            }
            Thread.sleep(10); // back off and retry
        }
    }
}
```

---

### 1.9 ThreadLocal + Cleanup

```java
import java.text.SimpleDateFormat;
import java.util.Date;

// ThreadLocal: each thread gets its own SimpleDateFormat — avoids contention on shared instance
public class DateFormatter {
    // SimpleDateFormat is NOT thread-safe; ThreadLocal gives each thread its own instance
    private static final ThreadLocal<SimpleDateFormat> DATE_FORMAT =
        ThreadLocal.withInitial(() -> new SimpleDateFormat("yyyy-MM-dd HH:mm:ss"));

    public String format(Date date) {
        return DATE_FORMAT.get().format(date);
    }

    public Date parse(String dateStr) throws Exception {
        return DATE_FORMAT.get().parse(dateStr);
    }

    // CRITICAL: In thread pool environments, threads are reused — always remove() in finally
    public String formatSafe(Date date) {
        try {
            return DATE_FORMAT.get().format(date);
        } finally {
            DATE_FORMAT.remove();                          // prevent memory leak in thread pools
        }
    }
}

// Real-world usage: request context holder (common in Spring)
public class RequestContext {
    private static final ThreadLocal<String> CURRENT_USER = new ThreadLocal<>();

    public static void setUser(String userId) { CURRENT_USER.set(userId); }
    public static String getUser()            { return CURRENT_USER.get(); }
    public static void clear()                { CURRENT_USER.remove(); }  // call in finally/filter
}
```

---

## Category 2: Collections Patterns

### 2.1 Custom HashMap Operations

```java
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class HashMapPatterns {

    public static void main(String[] args) {
        List<String> words = List.of("apple", "banana", "apple", "cherry", "banana", "apple");

        // 1. getOrDefault: read with fallback — cleaner than null check
        Map<String, Integer> freq = new HashMap<>();
        for (String w : words) {
            freq.put(w, freq.getOrDefault(w, 0) + 1);
        }

        // 2. merge: update or insert with combining function — ideal for counting/aggregating
        Map<String, Integer> freq2 = new HashMap<>();
        for (String w : words) {
            freq2.merge(w, 1, Integer::sum);               // if absent: put 1; if present: sum
        }

        // 3. compute: transform existing value, or insert if absent
        Map<String, Integer> freq3 = new HashMap<>();
        for (String w : words) {
            freq3.compute(w, (k, v) -> v == null ? 1 : v + 1);
        }

        // 4. computeIfAbsent: initialize nested structure lazily — avoids double-lookup
        Map<String, List<String>> grouped = new HashMap<>();
        for (String w : words) {
            grouped.computeIfAbsent(w, k -> new java.util.ArrayList<>()).add(w.toUpperCase());
        }

        System.out.println("Frequency: " + freq);
        System.out.println("Grouped: " + grouped);
    }
}
```

---

### 2.2 Stream Collectors

```java
import java.util.*;
import java.util.stream.*;

public class CollectorPatterns {

    record Employee(String name, String dept, double salary, boolean active) {}

    public static void main(String[] args) {
        List<Employee> employees = List.of(
            new Employee("Alice", "Eng",  95000, true),
            new Employee("Bob",   "HR",   75000, false),
            new Employee("Carol", "Eng", 105000, true),
            new Employee("Dave",  "HR",   80000, true)
        );

        // 1. groupingBy: group employees by department
        Map<String, List<Employee>> byDept =
            employees.stream().collect(Collectors.groupingBy(Employee::dept));

        // 2. groupingBy + downstream: count per department
        Map<String, Long> countByDept =
            employees.stream().collect(Collectors.groupingBy(Employee::dept, Collectors.counting()));

        // 3. partitioningBy: split into two groups by predicate
        Map<Boolean, List<Employee>> activePartition =
            employees.stream().collect(Collectors.partitioningBy(Employee::active));

        // 4. toMap with merge function: name → salary, handle duplicates by taking max
        Map<String, Double> salaryMap = employees.stream().collect(
            Collectors.toMap(Employee::name, Employee::salary, Double::max));

        // 5. joining: concatenate names
        String names = employees.stream().map(Employee::name)
                                .collect(Collectors.joining(", ", "[", "]"));

        // 6. summarizingDouble: stats in one pass
        DoubleSummaryStatistics stats = employees.stream()
            .collect(Collectors.summarizingDouble(Employee::salary));
        System.out.println("Avg salary: " + stats.getAverage());
        System.out.println("Max salary: " + stats.getMax());

        System.out.println("By dept: " + byDept.keySet());
        System.out.println("Count: " + countByDept);
        System.out.println("Names: " + names);
    }
}
```

---

### 2.3 Frequency Map + Top-K Elements

```java
import java.util.*;
import java.util.stream.*;

// Find top-K most frequent words — classic interview problem
public class TopKFrequent {

    // Approach 1: Streams — clean, readable
    public List<String> topKStream(String[] words, int k) {
        return Arrays.stream(words)
            .collect(java.util.stream.Collectors.groupingBy(w -> w, Collectors.counting()))
            .entrySet().stream()
            .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
            .limit(k)
            .map(Map.Entry::getKey)
            .collect(Collectors.toList());
    }

    // Approach 2: Min-heap of size K — O(n log k), efficient for large n
    public List<String> topKHeap(String[] words, int k) {
        Map<String, Integer> freq = new HashMap<>();
        for (String w : words) freq.merge(w, 1, Integer::sum);

        // Min-heap: smallest frequency at top; evict when size > k
        PriorityQueue<Map.Entry<String, Integer>> heap =
            new PriorityQueue<>(Comparator.comparingInt(Map.Entry::getValue));

        for (Map.Entry<String, Integer> entry : freq.entrySet()) {
            heap.offer(entry);
            if (heap.size() > k) heap.poll();              // remove least frequent
        }

        // Collect and reverse (heap gives ascending order)
        List<String> result = new ArrayList<>();
        while (!heap.isEmpty()) result.add(heap.poll().getKey());
        Collections.reverse(result);
        return result;
    }

    public static void main(String[] args) {
        TopKFrequent tk = new TopKFrequent();
        String[] words = {"apple","banana","apple","cherry","banana","apple","date","cherry"};
        System.out.println("Stream: " + tk.topKStream(words, 2));  // [apple, banana]
        System.out.println("Heap:   " + tk.topKHeap(words, 2));    // [apple, banana]
    }
}
```

---

### 2.4 ConcurrentHashMap Patterns

```java
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

// ConcurrentHashMap: lock-free reads, segment-level writes; preferred over synchronized HashMap
public class ConcurrentMapPatterns {
    private final ConcurrentHashMap<String, AtomicLong> counters = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, ExpensiveObject> cache = new ConcurrentHashMap<>();

    // 1. computeIfAbsent: thread-safe lazy initialization — used for caches and grouping
    public ExpensiveObject getOrCreate(String key) {
        return cache.computeIfAbsent(key, k -> new ExpensiveObject(k));
    }

    // 2. merge: atomic increment without external locking
    public void increment(String event) {
        counters.computeIfAbsent(event, k -> new AtomicLong(0)).incrementAndGet();
        // Alternative: merge with Long
        // eventCounts.merge(event, 1L, Long::sum);
    }

    // 3. forEach with parallelismThreshold: parallel processing when map is large
    public void printStats(long parallelismThreshold) {
        counters.forEach(parallelismThreshold, (key, count) ->
            System.out.println(key + ": " + count.get()));
        // parallelismThreshold=1 → always parallel; Long.MAX_VALUE → always sequential
    }

    // 4. putIfAbsent: safe first-write-wins semantics
    public boolean registerOnce(String key, ExpensiveObject obj) {
        return cache.putIfAbsent(key, obj) == null;        // returns true if this call registered it
    }

    static class ExpensiveObject {
        ExpensiveObject(String id) { /* expensive init */ }
    }
}
```

---

## Category 3: Spring Boot Patterns

### 3.1 Complete SecurityFilterChain (Spring Security 6)

```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter) {
        this.jwtAuthFilter = jwtAuthFilter;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(csrf -> csrf.disable())                  // stateless API: no CSRF needed
            .sessionManagement(sm ->
                sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                .requestMatchers("/api/v1/auth/**").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }
}
```

---

### 3.2 JWT Token Service

```java
import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;
import java.security.Key;
import java.util.Date;
import java.util.Map;

@Service
public class JwtTokenService {
    private static final long EXPIRATION_MS = 86_400_000L; // 24 hours
    private final Key signingKey;

    public JwtTokenService(JwtProperties props) {
        // Key must be >= 256 bits for HS256
        this.signingKey = Keys.hmacShaKeyFor(props.getSecret().getBytes());
    }

    // Generate JWT with claims — use for login response
    public String generateToken(String subject, Map<String, Object> extraClaims) {
        return Jwts.builder()
            .setClaims(extraClaims)
            .setSubject(subject)
            .setIssuedAt(new Date())
            .setExpiration(new Date(System.currentTimeMillis() + EXPIRATION_MS))
            .signWith(signingKey, SignatureAlgorithm.HS256)
            .compact();
    }

    // Validate token and extract subject — returns null if invalid
    public String extractSubject(String token) {
        return extractAllClaims(token).getSubject();
    }

    public boolean isTokenValid(String token, String expectedSubject) {
        try {
            Claims claims = extractAllClaims(token);
            return expectedSubject.equals(claims.getSubject())
                && claims.getExpiration().after(new Date());
        } catch (JwtException e) {
            return false;                                  // expired, malformed, bad signature
        }
    }

    private Claims extractAllClaims(String token) {
        return Jwts.parserBuilder()
            .setSigningKey(signingKey)
            .build()
            .parseClaimsJws(token)
            .getBody();
    }
}
```

---

### 3.3 @Transactional with REQUIRES_NEW

```java
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OrderService {
    private final OrderRepository orderRepo;
    private final AuditService auditService;

    public OrderService(OrderRepository orderRepo, AuditService auditService) {
        this.orderRepo = orderRepo;
        this.auditService = auditService;
    }

    @Transactional
    public void processOrder(Order order) {
        orderRepo.save(order);
        auditService.log("ORDER_CREATED", order.getId()); // audit runs in its own tx
        if (order.getAmount() < 0) {
            throw new IllegalArgumentException("Negative amount"); // rolls back order tx
            // but audit log was already committed in its own separate tx
        }
    }
}

@Service
public class AuditService {
    private final AuditRepository auditRepo;

    public AuditService(AuditRepository auditRepo) { this.auditRepo = auditRepo; }

    // REQUIRES_NEW: suspends caller's tx, commits independently — audit persists even on rollback
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void log(String event, Long entityId) {
        auditRepo.save(new AuditLog(event, entityId, System.currentTimeMillis()));
    }
}
```

---

### 3.4 Custom BeanPostProcessor

```java
import org.springframework.beans.BeansException;
import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.stereotype.Component;

// BeanPostProcessor: intercepts every bean before/after initialization — use for instrumentation
@Component
public class TimingBeanPostProcessor implements BeanPostProcessor {

    @Override
    public Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
        // Called before @PostConstruct / afterPropertiesSet
        System.out.println("Before init: " + beanName);
        return bean;                                       // MUST return the bean (or a proxy)
    }

    @Override
    public Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
        // Called after @PostConstruct / afterPropertiesSet — good place to wrap with proxy
        System.out.println("After init: " + beanName + " [" + bean.getClass().getSimpleName() + "]");
        return bean;                                       // return proxy here for AOP-like behavior
    }
}
```

---

### 3.5 Spring Events (sync + async)

```java
import org.springframework.context.ApplicationEvent;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

// 1. Define the event
public class OrderCreatedEvent extends ApplicationEvent {
    private final Long orderId;

    public OrderCreatedEvent(Object source, Long orderId) {
        super(source);
        this.orderId = orderId;
    }

    public Long getOrderId() { return orderId; }
}

// 2. Publish the event from a service
@Service
public class OrderPublisher {
    private final ApplicationEventPublisher publisher;

    public OrderPublisher(ApplicationEventPublisher publisher) {
        this.publisher = publisher;
    }

    public void createOrder(Order order) {
        // save order...
        publisher.publishEvent(new OrderCreatedEvent(this, order.getId()));
    }
}

// 3. Synchronous listener — runs in same thread and transaction as publisher
@Component
public class SyncOrderListener {
    @EventListener
    public void onOrderCreated(OrderCreatedEvent event) {
        System.out.println("Sync: order " + event.getOrderId());
    }
}

// 4. TransactionalEventListener — fires AFTER_COMMIT; skips if tx rolls back
@Component
public class TxOrderListener {
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderCommitted(OrderCreatedEvent event) {
        // Safe to send email/push notification — order is guaranteed persisted
        System.out.println("TX committed: order " + event.getOrderId());
    }
}

// 5. Async listener — runs in separate thread (requires @EnableAsync on config class)
@Component
public class AsyncOrderListener {
    @Async
    @EventListener
    public void onOrderCreatedAsync(OrderCreatedEvent event) {
        System.out.println("Async on thread: " + Thread.currentThread().getName());
    }
}
```

---

### 3.6 @ConfigurationProperties

```java
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

// Type-safe config binding with validation — prefer over @Value for grouped properties
@Validated
@ConfigurationProperties(prefix = "app.database")
public class DatabaseProperties {

    @NotBlank
    private String url;

    @NotBlank
    private String username;

    private String password;

    @Min(1)
    private int maxPoolSize = 10;                  // default value

    @NotNull
    private PoolConfig pool = new PoolConfig();

    // getters and setters required for binding
    public String getUrl()              { return url; }
    public void setUrl(String url)      { this.url = url; }
    public String getUsername()         { return username; }
    public void setUsername(String u)   { this.username = u; }
    public String getPassword()         { return password; }
    public void setPassword(String p)   { this.password = p; }
    public int getMaxPoolSize()         { return maxPoolSize; }
    public void setMaxPoolSize(int s)   { this.maxPoolSize = s; }
    public PoolConfig getPool()         { return pool; }
    public void setPool(PoolConfig p)   { this.pool = p; }

    public static class PoolConfig {
        private int connectionTimeout = 30000;
        private int idleTimeout = 600000;
        public int getConnectionTimeout()          { return connectionTimeout; }
        public void setConnectionTimeout(int t)    { this.connectionTimeout = t; }
        public int getIdleTimeout()                { return idleTimeout; }
        public void setIdleTimeout(int t)          { this.idleTimeout = t; }
    }
}
```

```yaml
# application.yml — matches prefix = "app.database"
app:
  database:
    url: jdbc:postgresql://localhost:5432/mydb
    username: app_user
    password: secret
    max-pool-size: 20
    pool:
      connection-timeout: 30000
      idle-timeout: 600000
```

---

### 3.7 Custom HealthIndicator

```java
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

// Expose downstream dependency health at /actuator/health
@Component("paymentGateway")                       // name appears in health response key
public class PaymentGatewayHealthIndicator implements HealthIndicator {
    private final PaymentGatewayClient client;

    public PaymentGatewayHealthIndicator(PaymentGatewayClient client) {
        this.client = client;
    }

    @Override
    public Health health() {
        try {
            long start = System.currentTimeMillis();
            boolean reachable = client.ping();
            long latency = System.currentTimeMillis() - start;

            if (reachable) {
                return Health.up()
                    .withDetail("latencyMs", latency)
                    .withDetail("endpoint", client.getEndpoint())
                    .build();
            } else {
                return Health.down()
                    .withDetail("reason", "ping returned false")
                    .build();
            }
        } catch (Exception e) {
            return Health.down(e)                  // includes exception message
                .withDetail("endpoint", client.getEndpoint())
                .build();
        }
    }
}
```

---

### 3.8 AbstractRoutingDataSource (Read/Write Split)

```java
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Before;
import org.springframework.jdbc.datasource.lookup.AbstractRoutingDataSource;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.util.Map;

// 1. Context holder — stores current routing key per thread
public class DataSourceContext {
    private static final ThreadLocal<String> CONTEXT = new ThreadLocal<>();
    public static final String WRITE = "WRITE";
    public static final String READ  = "READ";

    public static void setWrite() { CONTEXT.set(WRITE); }
    public static void setRead()  { CONTEXT.set(READ); }
    public static void clear()    { CONTEXT.remove(); }
    public static String getCurrent() { return CONTEXT.get(); }
}

// 2. Routing datasource — selects datasource based on context
public class RoutingDataSource extends AbstractRoutingDataSource {
    @Override
    protected Object determineCurrentLookupKey() {
        return DataSourceContext.getCurrent();             // returns WRITE or READ
    }
}

// 3. Configuration — wire up primary and replica
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class DataSourceConfig {
    @Bean
    public DataSource dataSource(DataSource writeDs, DataSource readDs) {
        RoutingDataSource routing = new RoutingDataSource();
        routing.setDefaultTargetDataSource(writeDs);
        routing.setTargetDataSources(Map.of(
            DataSourceContext.WRITE, writeDs,
            DataSourceContext.READ,  readDs
        ));
        return routing;
    }
}

// 4. AOP aspect — automatically route @Transactional(readOnly=true) to replica
@Aspect
@Component
public class DataSourceRoutingAspect {

    // Set READ context before read-only transactions
    @Before("@annotation(org.springframework.transaction.annotation.Transactional) " +
            "&& @annotation(tx)")
    public void setDataSourceContext(
            org.springframework.transaction.annotation.Transactional tx) {
        if (tx.readOnly()) {
            DataSourceContext.setRead();
        } else {
            DataSourceContext.setWrite();
        }
    }
}
```

---

## Category 4: JPA/Hibernate Patterns

### 4.1 N+1 Fix with @EntityGraph

```java
import jakarta.persistence.*;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

@Entity
public class Author {
    @Id @GeneratedValue Long id;
    String name;

    @OneToMany(mappedBy = "author", fetch = FetchType.LAZY)
    List<Book> books;                                      // LAZY: avoid N+1 by default
}

@Entity
public class Book {
    @Id @GeneratedValue Long id;
    String title;

    @ManyToOne(fetch = FetchType.LAZY)
    Author author;
}

public interface AuthorRepository extends JpaRepository<Author, Long> {

    // BEFORE (N+1): findAll() loads Authors, then 1 query per Author to load Books
    // List<Author> findAll();  <-- triggers N+1

    // AFTER: @EntityGraph generates single JOIN FETCH query
    @EntityGraph(attributePaths = {"books"})
    List<Author> findAll();                                // one query: SELECT a, b FROM Author a LEFT JOIN FETCH a.books b

    // Named EntityGraph alternative (defined on entity)
    // @EntityGraph(value = "Author.withBooks")
    // List<Author> findAllWithGraph();
}
```

---

### 4.2 Optimistic Locking with Retry

```java
import jakarta.persistence.*;
import org.springframework.retry.annotation.Backoff;
import org.springframework.retry.annotation.Retryable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Entity
public class Product {
    @Id @GeneratedValue Long id;
    String name;
    int stock;

    @Version                                               // Hibernate manages; increments on each update
    Integer version;
}

@Service
public class InventoryService {
    private final ProductRepository productRepo;

    public InventoryService(ProductRepository productRepo) {
        this.productRepo = productRepo;
    }

    // @Retryable retries up to 3 times with 100ms delay on optimistic lock conflict
    @Retryable(
        retryFor = {jakarta.persistence.OptimisticLockException.class,
                    org.springframework.orm.ObjectOptimisticLockingFailureException.class},
        maxAttempts = 3,
        backoff = @Backoff(delay = 100)
    )
    @Transactional
    public void decrementStock(Long productId, int quantity) {
        Product product = productRepo.findById(productId)
            .orElseThrow(() -> new RuntimeException("Product not found"));

        if (product.getStock() < quantity) {
            throw new IllegalStateException("Insufficient stock");
        }
        product.setStock(product.getStock() - quantity);
        productRepo.save(product);                         // throws OptimisticLockException if version mismatch
    }
}
```

---

### 4.3 Batch Insert Configuration

```java
import jakarta.persistence.*;

@Entity
public class Event {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE,    // SEQUENCE required for batching (IDENTITY disables it)
                    generator = "event_seq")
    @SequenceGenerator(name = "event_seq", sequenceName = "event_seq",
                       allocationSize = 50)                // allocationSize = batch_size for efficiency
    private Long id;

    private String type;
    private String payload;
}
```

```yaml
# application.yml — critical Hibernate batch properties
spring:
  jpa:
    properties:
      hibernate:
        jdbc:
          batch_size: 50              # number of inserts per batch
        order_inserts: true           # group inserts by entity type — required for batching
        order_updates: true           # group updates by entity type
        generate_statistics: true     # enable to verify batching is working
```

```java
// Service: flush and clear every batch_size to avoid OutOfMemoryError
@Service
public class EventBatchService {
    @PersistenceContext EntityManager em;
    private static final int BATCH_SIZE = 50;

    @Transactional
    public void insertBatch(List<Event> events) {
        for (int i = 0; i < events.size(); i++) {
            em.persist(events.get(i));
            if (i % BATCH_SIZE == 0 && i > 0) {
                em.flush();                                // send batch to DB
                em.clear();                                // detach to free memory
            }
        }
    }
}
```

---

### 4.4 DTO Projection (Interface + Record)

```java
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

// 1. Interface-based projection — Spring generates proxy; no constructor binding required
public interface OrderSummary {
    Long getId();
    String getCustomerName();
    Double getTotalAmount();
}

// 2. Record-based projection (Java 16+) — constructor binding via @Query
public record OrderRecord(Long id, String customerName, Double totalAmount) {}

public interface OrderRepository extends JpaRepository<Order, Long> {

    // Interface projection: Spring creates proxy automatically
    @Query("SELECT o.id as id, c.name as customerName, o.totalAmount as totalAmount " +
           "FROM Order o JOIN o.customer c WHERE o.status = :status")
    List<OrderSummary> findSummariesByStatus(String status);

    // Record projection: constructor expression matches record canonical constructor
    @Query("SELECT new com.example.OrderRecord(o.id, c.name, o.totalAmount) " +
           "FROM Order o JOIN o.customer c WHERE o.customerId = :customerId")
    List<OrderRecord> findOrderRecordsByCustomer(Long customerId);
}
```

---

### 4.5 Custom Repository with Specifications

```java
import jakarta.persistence.criteria.*;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface ProductRepository
    extends JpaRepository<Product, Long>, JpaSpecificationExecutor<Product> {}

// Specification builder — compose dynamic queries without string concatenation
public class ProductSpecifications {

    public static Specification<Product> hasCategory(String category) {
        return (root, query, cb) ->
            category == null ? cb.conjunction()            // no filter if null
                             : cb.equal(root.get("category"), category);
    }

    public static Specification<Product> priceBetween(Double min, Double max) {
        return (root, query, cb) -> {
            if (min == null && max == null) return cb.conjunction();
            if (min == null) return cb.lessThanOrEqualTo(root.get("price"), max);
            if (max == null) return cb.greaterThanOrEqualTo(root.get("price"), min);
            return cb.between(root.get("price"), min, max);
        };
    }

    public static Specification<Product> isInStock() {
        return (root, query, cb) -> cb.greaterThan(root.get("stock"), 0);
    }
}

// Usage in service — compose specs with and()/or()
@Service
public class ProductSearchService {
    private final ProductRepository repo;

    public ProductSearchService(ProductRepository repo) { this.repo = repo; }

    public List<Product> search(String category, Double minPrice, Double maxPrice) {
        return repo.findAll(
            Specification.where(ProductSpecifications.hasCategory(category))
                         .and(ProductSpecifications.priceBetween(minPrice, maxPrice))
                         .and(ProductSpecifications.isInStock())
        );
    }
}
```

---

### 4.6 Auditing with @EnableJpaAuditing

```java
import jakarta.persistence.*;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.annotation.CreatedBy;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedBy;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.domain.AuditorAware;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.security.core.context.SecurityContextHolder;

import java.time.Instant;
import java.util.Optional;

// 1. Enable auditing in configuration
@Configuration
@EnableJpaAuditing(auditorAwareRef = "auditorProvider")
public class JpaAuditingConfig {

    @Bean
    public AuditorAware<String> auditorProvider() {
        return () -> Optional.ofNullable(
            SecurityContextHolder.getContext().getAuthentication()
        ).map(auth -> auth.getName());
    }
}

// 2. Base auditable entity — extend all entities from this
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class Auditable {

    @CreatedDate
    @Column(updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    private Instant updatedAt;

    @CreatedBy
    @Column(updatable = false)
    private String createdBy;

    @LastModifiedBy
    private String updatedBy;

    // getters omitted for brevity
}

// 3. Entity extends Auditable
@Entity
public class Order extends Auditable {
    @Id @GeneratedValue Long id;
    String status;
    Double totalAmount;
}
```

---

## Category 5: Kafka Patterns

### 5.1 Producer with Transactions (Exactly-Once)

```java
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.transaction.KafkaTransactionManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// Requires: spring.kafka.producer.transaction-id-prefix=tx-
@Service
public class ExactlyOnceProducer {
    private final KafkaTemplate<String, Object> kafkaTemplate;
    private final OrderRepository orderRepo;

    public ExactlyOnceProducer(KafkaTemplate<String, Object> kafkaTemplate,
                                OrderRepository orderRepo) {
        this.kafkaTemplate = kafkaTemplate;
        this.orderRepo = orderRepo;
    }

    // @Transactional wraps DB + Kafka in a single logical transaction
    // Use KafkaTransactionManager or ChainedTransactionManager for DB+Kafka
    @Transactional("kafkaTransactionManager")
    public void processAndPublish(Order order) {
        orderRepo.save(order);                             // DB write
        kafkaTemplate.send("orders", order.getId().toString(), order); // Kafka write (transactional)
        // Both are committed atomically — if either fails, both roll back
    }
}
```

```yaml
# application.yml — required for exactly-once semantics
spring:
  kafka:
    producer:
      transaction-id-prefix: tx-       # enables transactional producer
      acks: all                         # wait for all replicas
      retries: 3
      properties:
        enable.idempotence: true        # idempotent producer (required for transactions)
```

---

### 5.2 @KafkaListener with Manual Commit + DLQ

```java
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.listener.AcknowledgingMessageListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

@Component
public class OrderConsumer {

    @KafkaListener(
        topics = "orders",
        groupId = "order-service",
        containerFactory = "manualAckContainerFactory"    // configured with AckMode.MANUAL
    )
    public void consume(ConsumerRecord<String, Order> record, Acknowledgment ack) {
        try {
            processOrder(record.value());
            ack.acknowledge();                             // commit offset only on success
        } catch (RecoverableException e) {
            // Don't ack — message will be redelivered
            throw e;
        } catch (Exception e) {
            ack.acknowledge();                             // ack to skip; DLQ handles it
            // DefaultErrorHandler configured below will send to DLT automatically
        }
    }

    private void processOrder(Order order) { /* business logic */ }
}
```

```java
import org.apache.kafka.common.TopicPartition;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.listener.ContainerProperties;
import org.springframework.kafka.listener.DeadLetterPublishingRecoverer;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.util.backoff.FixedBackOff;

@Configuration
public class KafkaConsumerConfig {

    @Bean
    public ConcurrentKafkaListenerContainerFactory<?, ?> manualAckContainerFactory(
            ConsumerFactory<Object, Object> cf,
            KafkaTemplate<Object, Object> template) {

        var factory = new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(cf);
        factory.getContainerProperties().setAckMode(ContainerProperties.AckMode.MANUAL);

        // Send to <topic>.DLT after 3 retries with 1s interval
        DeadLetterPublishingRecoverer recoverer = new DeadLetterPublishingRecoverer(template,
            (record, ex) -> new TopicPartition(record.topic() + ".DLT", record.partition()));
        factory.setCommonErrorHandler(new DefaultErrorHandler(recoverer, new FixedBackOff(1000L, 3)));

        return factory;
    }
}
```

---

### 5.3 Idempotent Consumer

```java
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;
import java.time.Duration;

// Idempotent consumer: deduplicate using message ID stored in Redis
@Component
public class IdempotentPaymentConsumer {
    private static final String DEDUP_KEY_PREFIX = "kafka:processed:";
    private static final Duration TTL = Duration.ofHours(24);

    private final StringRedisTemplate redis;
    private final PaymentService paymentService;

    public IdempotentPaymentConsumer(StringRedisTemplate redis, PaymentService paymentService) {
        this.redis = redis;
        this.paymentService = paymentService;
    }

    @KafkaListener(topics = "payments", groupId = "payment-service")
    public void consume(PaymentEvent event, Acknowledgment ack) {
        String dedupKey = DEDUP_KEY_PREFIX + event.getMessageId();

        // setIfAbsent = SET NX EX — atomic check-and-set
        Boolean isNew = redis.opsForValue().setIfAbsent(dedupKey, "1", TTL);

        if (Boolean.TRUE.equals(isNew)) {
            paymentService.process(event);                 // first time: process
        } else {
            // Duplicate: skip silently
            System.out.println("Skipping duplicate: " + event.getMessageId());
        }
        ack.acknowledge();
    }
}
```

---

### 5.4 Kafka Streams Word Count

```java
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.*;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.Arrays;

@Configuration
public class WordCountTopology {

    @Bean
    public KStream<String, String> wordCountStream(StreamsBuilder builder) {
        KStream<String, String> textStream = builder.stream("text-input",
            Consumed.with(Serdes.String(), Serdes.String()));

        KTable<String, Long> wordCounts = textStream
            .flatMapValues(text -> Arrays.asList(text.toLowerCase().split("\\W+")))
            .groupBy((key, word) -> word, Grouped.with(Serdes.String(), Serdes.String()))
            .count(Materialized.as("word-counts-store")); // materialize to state store

        wordCounts.toStream()
                  .to("word-count-output",
                      Produced.with(Serdes.String(), Serdes.Long()));

        return textStream;
    }
}
```

---

## Category 6: Redis Patterns

### 6.1 @Cacheable Full Configuration

```java
import org.springframework.cache.annotation.CacheConfig;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import java.time.Duration;
import java.util.Map;

@Configuration
public class CacheConfig {

    @Bean
    public RedisCacheManager cacheManager(RedisConnectionFactory cf) {
        RedisCacheConfiguration defaults = RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(10))
            .disableCachingNullValues()
            .serializeKeysWith(
                RedisSerializationContext.SerializationPair.fromSerializer(new StringRedisSerializer()))
            .serializeValuesWith(
                RedisSerializationContext.SerializationPair.fromSerializer(
                    new GenericJackson2JsonRedisSerializer()));

        return RedisCacheManager.builder(cf)
            .cacheDefaults(defaults)
            .withInitialCacheConfigurations(Map.of(
                "users",    defaults.entryTtl(Duration.ofMinutes(30)),  // longer TTL for users
                "products", defaults.entryTtl(Duration.ofMinutes(5))    // shorter TTL for products
            ))
            .build();
    }
}

@CacheConfig(cacheNames = "users")
@org.springframework.stereotype.Service
public class UserCacheService {
    private final UserRepository userRepo;

    public UserCacheService(UserRepository userRepo) { this.userRepo = userRepo; }

    @Cacheable(key = "#id")                                // cache key: "users::123"
    public User findById(Long id) {
        return userRepo.findById(id).orElseThrow();
    }

    @CacheEvict(key = "#user.id")                         // evict on update
    public User update(User user) {
        return userRepo.save(user);
    }

    @CacheEvict(allEntries = true)                        // clear entire cache
    public void clearAll() {}
}
```

---

### 6.2 Redisson Distributed Lock

```java
import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;
import org.springframework.stereotype.Service;
import java.util.concurrent.TimeUnit;

// Distributed lock: prevents concurrent execution across multiple JVM instances
@Service
public class DistributedTaskService {
    private final RedissonClient redisson;

    public DistributedTaskService(RedissonClient redisson) {
        this.redisson = redisson;
    }

    public void executeExclusively(String resourceId, Runnable task) {
        RLock lock = redisson.getLock("lock:" + resourceId);
        boolean acquired = false;
        try {
            // tryLock: waitTime=5s (acquire timeout), leaseTime=30s (auto-release)
            // leaseTime=-1 enables watchdog (auto-renews every 10s while locked)
            acquired = lock.tryLock(5, 30, TimeUnit.SECONDS);
            if (!acquired) {
                throw new RuntimeException("Could not acquire lock for: " + resourceId);
            }
            task.run();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException("Interrupted while acquiring lock", e);
        } finally {
            if (acquired && lock.isHeldByCurrentThread()) {
                lock.unlock();                             // ALWAYS unlock in finally
            }
        }
    }
}
```

---

### 6.3 Lua Script for Atomic Rate Limiting

```java
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;
import java.util.List;

// Sliding window rate limiter using atomic Lua script — no race condition possible
@Component
public class RateLimiter {
    private final StringRedisTemplate redis;

    // Lua script: KEYS[1]=rate limit key, ARGV[1]=limit, ARGV[2]=window(seconds)
    private static final DefaultRedisScript<Long> RATE_LIMIT_SCRIPT = new DefaultRedisScript<>("""
        local key    = KEYS[1]
        local limit  = tonumber(ARGV[1])
        local window = tonumber(ARGV[2])
        local current = redis.call('INCR', key)
        if current == 1 then
            redis.call('EXPIRE', key, window)
        end
        if current > limit then
            return 0
        else
            return 1
        end
        """, Long.class);

    public RateLimiter(StringRedisTemplate redis) { this.redis = redis; }

    // Returns true if request is allowed, false if rate limit exceeded
    public boolean isAllowed(String clientId, int limit, int windowSeconds) {
        String key = "rate:" + clientId;
        Long result = redis.execute(
            RATE_LIMIT_SCRIPT,
            List.of(key),
            String.valueOf(limit),
            String.valueOf(windowSeconds)
        );
        return Long.valueOf(1L).equals(result);
    }
}
```

---

### 6.4 Cache Stampede Prevention (XFetch Algorithm)

```java
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;
import java.time.Duration;
import java.util.function.Supplier;

// XFetch: probabilistic early expiration prevents thundering herd on cache miss
@Component
public class StampedePreventingCache {
    private final RedisTemplate<String, CacheEntry> redis;

    public StampedePreventingCache(RedisTemplate<String, CacheEntry> redis) {
        this.redis = redis;
    }

    public <T> T get(String key, Duration ttl, double beta, Supplier<T> recompute) {
        CacheEntry entry = redis.opsForValue().get(key);

        if (entry != null) {
            double remainingTtl = redis.getExpire(key, java.util.concurrent.TimeUnit.MILLISECONDS);
            double recomputeTime = entry.getDeltaMs();     // how long last recompute took

            // XFetch formula: recompute early with probability proportional to recompute cost
            double xfetch = -recomputeTime * beta * Math.log(Math.random());
            if (xfetch < remainingTtl) {
                return (T) entry.getValue();               // cache hit: return cached value
            }
        }

        // Cache miss or probabilistic early expiration: recompute
        long start = System.currentTimeMillis();
        T value = recompute.get();
        long delta = System.currentTimeMillis() - start;

        redis.opsForValue().set(key, new CacheEntry(value, delta), ttl);
        return value;
    }

    public record CacheEntry(Object value, long deltaMs) {}
}
```

---

## Category 7: REST API Patterns

### 7.1 RFC 7807 Problem Details Error Handler

```java
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.net.URI;
import java.util.Map;
import java.util.stream.Collectors;

// RFC 7807 compliant error responses — returns application/problem+json
@RestControllerAdvice
public class GlobalExceptionHandler {

    // Validation errors: 400 with field-level details
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        problem.setType(URI.create("https://api.example.com/errors/validation"));
        problem.setTitle("Validation Failed");
        problem.setDetail("One or more fields failed validation");

        Map<String, String> errors = ex.getBindingResult().getFieldErrors().stream()
            .collect(Collectors.toMap(
                FieldError::getField,
                fe -> fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "invalid",
                (a, b) -> a + "; " + b          // merge multiple errors on same field
            ));
        problem.setProperty("errors", errors);   // extension member per RFC 7807
        return problem;
    }

    // Not found: 404
    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handleNotFound(ResourceNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.NOT_FOUND);
        problem.setType(URI.create("https://api.example.com/errors/not-found"));
        problem.setTitle("Resource Not Found");
        problem.setDetail(ex.getMessage());
        return problem;
    }

    // Catch-all: 500
    @ExceptionHandler(Exception.class)
    public ProblemDetail handleGeneric(Exception ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.INTERNAL_SERVER_ERROR);
        problem.setType(URI.create("https://api.example.com/errors/internal"));
        problem.setTitle("Internal Server Error");
        problem.setDetail("An unexpected error occurred");
        return problem;
    }
}

class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String message) { super(message); }
}
```

---

### 7.2 Idempotency Key Filter

```java
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;
import java.time.Duration;

// Idempotency filter: cache response for X-Idempotency-Key header to prevent duplicate processing
@Component
public class IdempotencyFilter extends OncePerRequestFilter {
    private static final String HEADER = "X-Idempotency-Key";
    private static final Duration TTL = Duration.ofHours(24);
    private static final String PREFIX = "idempotency:";

    private final StringRedisTemplate redis;

    public IdempotencyFilter(StringRedisTemplate redis) { this.redis = redis; }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws IOException, jakarta.servlet.ServletException {
        String key = request.getHeader(HEADER);

        // Only apply to mutation methods with idempotency key
        if (key == null || !isMutationMethod(request.getMethod())) {
            chain.doFilter(request, response);
            return;
        }

        String redisKey = PREFIX + key;
        String cached = redis.opsForValue().get(redisKey);

        if (cached != null) {
            // Return cached response — idempotent replay
            response.setStatus(200);
            response.setContentType("application/json");
            response.getWriter().write(cached);
            response.setHeader("X-Idempotency-Replayed", "true");
            return;
        }

        // Wrap response to capture body
        ContentCachingResponseWrapper wrappedResponse = new ContentCachingResponseWrapper(response);
        chain.doFilter(request, wrappedResponse);

        // Cache only successful responses
        if (wrappedResponse.getStatus() < 400) {
            String body = new String(wrappedResponse.getContentAsByteArray());
            redis.opsForValue().set(redisKey, body, TTL);
        }
        wrappedResponse.copyBodyToResponse();
    }

    private boolean isMutationMethod(String method) {
        return "POST".equals(method) || "PUT".equals(method) || "PATCH".equals(method);
    }
}
```

---

### 7.3 Cursor-Based Pagination

```java
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Service;
import java.util.Base64;
import java.util.List;

// Keyset pagination: consistent under inserts, O(log n) vs O(n) for offset pagination
public record CursorPage<T>(
    List<T> items,
    String nextCursor,                                     // null if no more pages
    boolean hasMore
) {}

public interface OrderRepository extends JpaRepository<Order, Long> {
    @Query("SELECT o FROM Order o WHERE o.id > :cursor ORDER BY o.id ASC LIMIT :pageSize")
    List<Order> findAfterCursor(Long cursor, int pageSize);
}

@Service
public class OrderPaginationService {
    private final OrderRepository repo;

    public OrderPaginationService(OrderRepository repo) { this.repo = repo; }

    public CursorPage<Order> getPage(String encodedCursor, int pageSize) {
        Long cursor = decodeCursor(encodedCursor);

        // Fetch pageSize+1 to detect if there's a next page
        List<Order> results = repo.findAfterCursor(cursor, pageSize + 1);

        boolean hasMore = results.size() > pageSize;
        List<Order> items = hasMore ? results.subList(0, pageSize) : results;

        String nextCursor = hasMore
            ? encodeCursor(items.get(items.size() - 1).getId())
            : null;

        return new CursorPage<>(items, nextCursor, hasMore);
    }

    private String encodeCursor(Long id) {
        return Base64.getUrlEncoder().encodeToString(("cursor:" + id).getBytes());
    }

    private Long decodeCursor(String encoded) {
        if (encoded == null) return 0L;
        String decoded = new String(Base64.getUrlDecoder().decode(encoded));
        return Long.parseLong(decoded.replace("cursor:", ""));
    }
}
```

---

### 7.4 WebClient with Retry + Circuit Breaker

```java
import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig;
import io.github.resilience4j.reactor.circuitbreaker.operator.CircuitBreakerOperator;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;
import reactor.util.retry.Retry;

import java.time.Duration;

@Service
public class InventoryClient {
    private final WebClient webClient;
    private final CircuitBreaker circuitBreaker;

    public InventoryClient(WebClient.Builder builder, CircuitBreakerRegistry registry) {
        this.webClient = builder.baseUrl("https://inventory-service").build();
        this.circuitBreaker = registry.circuitBreaker("inventory");
    }

    public Mono<InventoryResponse> getStock(String productId) {
        return webClient.get()
            .uri("/api/stock/{id}", productId)
            .retrieve()
            .onStatus(status -> status.is5xxServerError(),
                      response -> Mono.error(new ServiceException("5xx from inventory")))
            .bodyToMono(InventoryResponse.class)
            // Retry: 3 attempts, exponential backoff, only on 5xx (not 4xx)
            .retryWhen(Retry.backoff(3, Duration.ofMillis(100))
                           .maxBackoff(Duration.ofSeconds(2))
                           .filter(ex -> ex instanceof ServiceException))
            // Circuit breaker: open after 50% failure rate, half-open after 5s wait
            .transformDeferred(CircuitBreakerOperator.of(circuitBreaker))
            // Fallback: return default response when circuit is open
            .onErrorReturn(io.github.resilience4j.circuitbreaker.CallNotPermittedException.class,
                           InventoryResponse.unavailable());
    }
}

record InventoryResponse(String productId, int quantity, boolean available) {
    static InventoryResponse unavailable() {
        return new InventoryResponse(null, 0, false);
    }
}

class ServiceException extends RuntimeException {
    ServiceException(String msg) { super(msg); }
}
```

---

## Category 8: Database Patterns

### 8.1 HikariCP Optimal Configuration

```yaml
# application.yml — HikariCP connection pool tuning
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/mydb
    username: app_user
    password: secret
    driver-class-name: org.postgresql.Driver
    hikari:
      # Pool sizing: formula = (core_count * 2) + effective_spindle_count
      maximum-pool-size: 10          # max connections; don't over-provision
      minimum-idle: 5                # keep warm connections ready
      
      # Timeouts
      connection-timeout: 30000      # max wait for connection from pool (ms)
      idle-timeout: 600000           # remove idle connection after 10min (ms)
      max-lifetime: 1800000          # replace connection after 30min (ms) — shorter than DB timeout
      keepalive-time: 300000         # send keepalive query every 5min to prevent stale connections
      
      # Validation
      connection-test-query: SELECT 1  # validate connection before use (PostgreSQL supports isValid())
      validation-timeout: 5000       # timeout for validation query (ms)
      
      pool-name: MyApp-HikariPool    # visible in JMX/metrics
      
      # Leak detection — logs stack trace of connection held > threshold
      leak-detection-threshold: 60000  # 60s; set to 0 to disable
```

---

### 8.2 Flyway Migration with Expand-Contract

```sql
-- V1__add_email_column.sql — EXPAND: add nullable column (zero downtime, old code ignores it)
ALTER TABLE users ADD COLUMN email VARCHAR(255);

-- No constraint yet — old application version still works without email
```

```sql
-- V2__backfill_email.sql — BACKFILL: populate data before adding constraint
-- Run in batches to avoid long table locks
UPDATE users SET email = username || '@example.com' WHERE email IS NULL;
```

```sql
-- V3__add_email_not_null.sql — CONTRACT: add constraint now that all rows have data
-- Only safe after old app version is fully retired (no code writing NULL email)
ALTER TABLE users ALTER COLUMN email SET NOT NULL;
ALTER TABLE users ADD CONSTRAINT users_email_unique UNIQUE (email);
```

---

### 8.3 Row-Level Security in PostgreSQL

```sql
-- Row-Level Security: tenants can only see their own rows — enforced at DB level
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policy: users see only rows where tenant_id matches the app.current_tenant setting
CREATE POLICY tenant_isolation ON orders
    USING (tenant_id = current_setting('app.current_tenant')::BIGINT);

-- Optional write policy (if read policy doesn't cover writes)
CREATE POLICY tenant_insert ON orders FOR INSERT
    WITH CHECK (tenant_id = current_setting('app.current_tenant')::BIGINT);

-- App user must not be superuser (superusers bypass RLS)
GRANT SELECT, INSERT, UPDATE, DELETE ON orders TO app_user;
```

```java
// Spring integration: set tenant context before each query via AOP or interceptor
import org.hibernate.resource.jdbc.spi.StatementInspector;
import org.springframework.stereotype.Component;

@Component
public class TenantStatementInspector implements StatementInspector {
    @Override
    public String inspect(String sql) {
        // Executed before every Hibernate statement — set PostgreSQL session variable
        return sql;
    }
}

// Better approach: use Spring's TransactionSynchronizationManager or a JDBC interceptor
@Component
public class TenantAwareDataSourceProxy {
    private final DataSource dataSource;

    public Connection getConnectionForTenant(Long tenantId) throws Exception {
        Connection conn = dataSource.getConnection();
        try (var stmt = conn.prepareStatement("SET app.current_tenant = ?")) {
            stmt.setLong(1, tenantId);
            stmt.execute();
        }
        return conn;
    }
}
```

---

### 8.4 PostgreSQL Advisory Lock

```java
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

// Advisory lock: lightweight distributed lock using PostgreSQL — no external dependency
@Component
public class PostgresAdvisoryLock {
    private final JdbcTemplate jdbc;

    public PostgresAdvisoryLock(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    // Blocking acquire — waits until lock is available (session-level)
    public void lock(long lockId) {
        jdbc.execute("SELECT pg_advisory_lock(" + lockId + ")");
    }

    // Non-blocking try — returns true if acquired, false if already held
    public boolean tryLock(long lockId) {
        return Boolean.TRUE.equals(
            jdbc.queryForObject("SELECT pg_try_advisory_lock(?)", Boolean.class, lockId));
    }

    // Release session-level advisory lock
    public void unlock(long lockId) {
        jdbc.execute("SELECT pg_advisory_unlock(" + lockId + ")");
    }

    // Transaction-level: automatically released at transaction end
    public boolean tryLockTransactional(long lockId) {
        return Boolean.TRUE.equals(
            jdbc.queryForObject("SELECT pg_try_advisory_xact_lock(?)", Boolean.class, lockId));
    }

    // Usage pattern with manual lock/unlock
    public void executeWithLock(long lockId, Runnable task) {
        boolean acquired = tryLock(lockId);
        if (!acquired) throw new RuntimeException("Could not acquire advisory lock: " + lockId);
        try {
            task.run();
        } finally {
            unlock(lockId);
        }
    }
}
```

---

## Category 9: LLD Patterns

### 9.1 Strategy Pattern (Complete)

```java
import org.springframework.stereotype.Component;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

// Strategy: swap algorithms at runtime without changing the context class
public interface DiscountStrategy {
    double apply(double originalPrice, int quantity);
    String name();
}

@Component("noDiscount")
public class NoDiscountStrategy implements DiscountStrategy {
    @Override public double apply(double price, int qty) { return price; }
    @Override public String name() { return "NONE"; }
}

@Component("bulkDiscount")
public class BulkDiscountStrategy implements DiscountStrategy {
    @Override
    public double apply(double price, int qty) {
        if (qty >= 100) return price * 0.70;               // 30% off for 100+
        if (qty >= 50)  return price * 0.80;               // 20% off for 50+
        if (qty >= 10)  return price * 0.90;               // 10% off for 10+
        return price;
    }
    @Override public String name() { return "BULK"; }
}

@Component("seasonalDiscount")
public class SeasonalDiscountStrategy implements DiscountStrategy {
    @Override
    public double apply(double price, int qty) {
        return price * 0.85;                               // flat 15% seasonal discount
    }
    @Override public String name() { return "SEASONAL"; }
}

// Context: holds current strategy, delegates calculation to it
@Component
public class PriceCalculator {
    private final Map<String, DiscountStrategy> strategies;

    // Spring injects all DiscountStrategy beans as a list
    public PriceCalculator(List<DiscountStrategy> strategyList) {
        this.strategies = strategyList.stream()
            .collect(Collectors.toMap(DiscountStrategy::name, Function.identity()));
    }

    public double calculate(double price, int qty, String strategyName) {
        DiscountStrategy strategy = strategies.getOrDefault(strategyName,
            strategies.get("NONE"));
        return strategy.apply(price, qty);
    }
}
```

---

### 9.2 Observer Pattern (Complete)

```java
import org.springframework.context.ApplicationEvent;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.stereotype.Service;
import java.util.ArrayList;
import java.util.List;

// PURE JAVA IMPLEMENTATION (without Spring)
public interface OrderObserver {
    void onOrderPlaced(Order order);
}

public class OrderSubject {
    private final List<OrderObserver> observers = new ArrayList<>();

    public void addObserver(OrderObserver observer)    { observers.add(observer); }
    public void removeObserver(OrderObserver observer) { observers.remove(observer); }

    public void placeOrder(Order order) {
        // business logic...
        notifyObservers(order);
    }

    private void notifyObservers(Order order) {
        observers.forEach(o -> o.onOrderPlaced(order));  // synchronous notification
    }
}

public class EmailNotificationObserver implements OrderObserver {
    @Override public void onOrderPlaced(Order order) {
        System.out.println("Email sent for order: " + order.getId());
    }
}

public class InventoryObserver implements OrderObserver {
    @Override public void onOrderPlaced(Order order) {
        System.out.println("Inventory updated for order: " + order.getId());
    }
}

// SPRING APPLICATION EVENT IMPLEMENTATION (preferred in Spring apps)
public class OrderPlacedEvent extends ApplicationEvent {
    private final Order order;
    public OrderPlacedEvent(Object source, Order order) { super(source); this.order = order; }
    public Order getOrder() { return order; }
}

@Service
public class OrderEventPublisher {
    private final ApplicationEventPublisher publisher;
    public OrderEventPublisher(ApplicationEventPublisher publisher) { this.publisher = publisher; }

    public void placeOrder(Order order) {
        // business logic...
        publisher.publishEvent(new OrderPlacedEvent(this, order));
    }
}

@Component
public class EmailListener {
    @EventListener
    public void handle(OrderPlacedEvent event) {
        System.out.println("Spring Email for: " + event.getOrder().getId());
    }
}

@Component
public class AnalyticsListener {
    @EventListener
    public void handle(OrderPlacedEvent event) {
        System.out.println("Analytics tracked: " + event.getOrder().getId());
    }
}
```

---

### 9.3 Builder Pattern (Manual)

```java
import java.time.Instant;
import java.util.Collections;
import java.util.List;

// Builder: construct complex immutable object step-by-step with validation
public final class HttpRequest {
    private final String method;
    private final String url;
    private final java.util.Map<String, String> headers;
    private final String body;
    private final int timeoutMs;
    private final int retries;
    private final Instant createdAt;

    private HttpRequest(Builder builder) {
        this.method    = builder.method;
        this.url       = builder.url;
        this.headers   = Collections.unmodifiableMap(new java.util.HashMap<>(builder.headers));
        this.body      = builder.body;
        this.timeoutMs = builder.timeoutMs;
        this.retries   = builder.retries;
        this.createdAt = Instant.now();
    }

    public String getMethod()   { return method; }
    public String getUrl()      { return url; }
    public String getBody()     { return body; }
    public int getTimeoutMs()   { return timeoutMs; }
    public int getRetries()     { return retries; }

    public static Builder builder(String method, String url) {
        return new Builder(method, url);
    }

    public static final class Builder {
        // Required parameters
        private final String method;
        private final String url;

        // Optional parameters with defaults
        private java.util.Map<String, String> headers = new java.util.HashMap<>();
        private String body;
        private int timeoutMs = 30_000;
        private int retries   = 0;

        private Builder(String method, String url) {
            this.method = method;
            this.url    = url;
        }

        public Builder header(String key, String value) {
            this.headers.put(key, value);
            return this;
        }

        public Builder body(String body) {
            this.body = body;
            return this;
        }

        public Builder timeoutMs(int timeoutMs) {
            this.timeoutMs = timeoutMs;
            return this;
        }

        public Builder retries(int retries) {
            this.retries = retries;
            return this;
        }

        public HttpRequest build() {
            // Validation in build() — fail fast before object is created
            if (method == null || method.isBlank()) throw new IllegalStateException("method required");
            if (url == null || url.isBlank())       throw new IllegalStateException("url required");
            if (timeoutMs <= 0)                     throw new IllegalStateException("timeout must be positive");
            if (retries < 0)                        throw new IllegalStateException("retries must be >= 0");
            return new HttpRequest(this);
        }
    }

    // Usage:
    // HttpRequest req = HttpRequest.builder("POST", "https://api.example.com/orders")
    //     .header("Content-Type", "application/json")
    //     .body("{\"item\": \"book\"}")
    //     .timeoutMs(5000)
    //     .retries(3)
    //     .build();
}
```

---

### 9.4 State Machine (Order)

```java
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.Map;
import java.util.Set;

// State machine: explicit transitions prevent invalid state changes
public enum OrderStatus {
    PENDING, CONFIRMED, SHIPPED, DELIVERED, CANCELLED
}

public class OrderStateMachine {
    // Define valid transitions: from state → set of allowed next states
    private static final Map<OrderStatus, Set<OrderStatus>> TRANSITIONS =
        new EnumMap<>(OrderStatus.class);

    static {
        TRANSITIONS.put(OrderStatus.PENDING,   EnumSet.of(OrderStatus.CONFIRMED, OrderStatus.CANCELLED));
        TRANSITIONS.put(OrderStatus.CONFIRMED, EnumSet.of(OrderStatus.SHIPPED,   OrderStatus.CANCELLED));
        TRANSITIONS.put(OrderStatus.SHIPPED,   EnumSet.of(OrderStatus.DELIVERED));
        TRANSITIONS.put(OrderStatus.DELIVERED, EnumSet.noneOf(OrderStatus.class)); // terminal
        TRANSITIONS.put(OrderStatus.CANCELLED, EnumSet.noneOf(OrderStatus.class)); // terminal
    }

    private OrderStatus currentStatus;

    public OrderStateMachine(OrderStatus initialStatus) {
        this.currentStatus = initialStatus;
    }

    public void transition(OrderStatus nextStatus) {
        Set<OrderStatus> allowed = TRANSITIONS.getOrDefault(currentStatus, EnumSet.noneOf(OrderStatus.class));
        if (!allowed.contains(nextStatus)) {
            throw new IllegalStateException(
                "Invalid transition: " + currentStatus + " → " + nextStatus +
                ". Allowed: " + allowed);
        }
        System.out.println("Transitioning: " + currentStatus + " → " + nextStatus);
        this.currentStatus = nextStatus;
    }

    public OrderStatus getStatus() { return currentStatus; }
    public boolean canTransitionTo(OrderStatus next) {
        return TRANSITIONS.getOrDefault(currentStatus, EnumSet.noneOf(OrderStatus.class)).contains(next);
    }

    public static void main(String[] args) {
        OrderStateMachine sm = new OrderStateMachine(OrderStatus.PENDING);
        sm.transition(OrderStatus.CONFIRMED);
        sm.transition(OrderStatus.SHIPPED);
        sm.transition(OrderStatus.DELIVERED);
        // sm.transition(OrderStatus.CANCELLED); // throws: DELIVERED is terminal
    }
}
```

---

### 9.5 Balance Simplification Algorithm (Splitwise)

```java
import java.util.*;

// Minimizes number of transactions to settle group expenses — greedy with max-heap/min-heap
public class BalanceSimplifier {

    public record Transaction(String from, String to, double amount) {}

    public List<Transaction> simplify(Map<String, Double> balances) {
        // Max-heap: person who is owed the most (creditor)
        PriorityQueue<Map.Entry<String, Double>> creditors =
            new PriorityQueue<>((a, b) -> Double.compare(b.getValue(), a.getValue()));

        // Min-heap: person who owes the most (debtor) — most negative balance first
        PriorityQueue<Map.Entry<String, Double>> debtors =
            new PriorityQueue<>(Comparator.comparingDouble(Map.Entry::getValue));

        for (Map.Entry<String, Double> entry : balances.entrySet()) {
            if (entry.getValue() > 0.001)        creditors.offer(entry);
            else if (entry.getValue() < -0.001)  debtors.offer(entry);
        }

        List<Transaction> result = new ArrayList<>();

        while (!creditors.isEmpty() && !debtors.isEmpty()) {
            Map.Entry<String, Double> creditor = creditors.poll();
            Map.Entry<String, Double> debtor   = debtors.poll();

            double amount = Math.min(creditor.getValue(), -debtor.getValue());
            result.add(new Transaction(debtor.getKey(), creditor.getKey(), amount));

            double newCreditorBalance = creditor.getValue() - amount;
            double newDebtorBalance   = debtor.getValue()   + amount;

            if (newCreditorBalance > 0.001) creditors.offer(Map.entry(creditor.getKey(), newCreditorBalance));
            if (newDebtorBalance  < -0.001) debtors.offer(Map.entry(debtor.getKey(), newDebtorBalance));
        }

        return result;
    }

    // Net balance computation from expense list
    public Map<String, Double> computeNetBalances(List<Expense> expenses) {
        Map<String, Double> balances = new HashMap<>();

        for (Expense expense : expenses) {
            double share = expense.amount() / expense.participants().size();
            // Payer gains (is owed) the amount minus their own share
            balances.merge(expense.payer(), expense.amount() - share, Double::sum);
            // Each other participant owes their share
            for (String participant : expense.participants()) {
                if (!participant.equals(expense.payer())) {
                    balances.merge(participant, -share, Double::sum);
                }
            }
        }
        return balances;
    }

    public record Expense(String payer, double amount, List<String> participants) {}

    public static void main(String[] args) {
        BalanceSimplifier simplifier = new BalanceSimplifier();

        List<Expense> expenses = List.of(
            new Expense("Alice", 90.0, List.of("Alice", "Bob", "Carol")),  // each owes 30
            new Expense("Bob",   60.0, List.of("Alice", "Bob", "Carol")),  // each owes 20
            new Expense("Carol", 30.0, List.of("Alice", "Bob", "Carol"))   // each owes 10
        );

        Map<String, Double> balances = simplifier.computeNetBalances(expenses);
        System.out.println("Balances: " + balances);
        // Alice: +60-20-10 = +30, Bob: +40-30-10 = 0, Carol: +20-30-20 = -30

        List<Transaction> transactions = simplifier.simplify(balances);
        transactions.forEach(t ->
            System.out.printf("%s pays %s $%.2f%n", t.from(), t.to(), t.amount()));
    }
}
```

---

*End of Appendix C*

