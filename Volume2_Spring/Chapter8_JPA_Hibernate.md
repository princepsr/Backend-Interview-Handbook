# Volume 2: Spring Ecosystem
# Chapter 8: Spring Data JPA & Hibernate

---
# Chapter 8: Spring Data JPA & Hibernate "” Part A

> Spring Boot 3 / Java 17 / Hibernate 6 / Jakarta Persistence 3.x

---

## Q1: JPA vs Hibernate

**Difficulty:** Easy | **Interview Frequency:** Very High
**Companies:** Amazon, Google, Microsoft, Flipkart, Paytm, TCS, Infosys, Wipro, Capgemini

**Short Answer (30-60 seconds):**
JPA (Jakarta Persistence API) is a specification defined under `jakarta.persistence` that describes how Java objects should be mapped to relational databases. Hibernate is the most popular implementation of that specification. JPA defines the contracts "” annotations like `@Entity`, `@Id`, the `EntityManager` interface, JPQL. Hibernate implements all of that and adds its own extras: HQL (Hibernate Query Language, a superset of JPQL), the `Session` API, second-level caching, batch processing, and advanced mapping features.

**Deep Explanation:**
- **JPA (specification):** Defined as part of Jakarta EE. Key packages: `jakarta.persistence.*`. Defines `EntityManager`, `EntityManagerFactory`, `Persistence`, JPQL, standard annotations, and transaction semantics. Any compliant ORM (Hibernate, EclipseLink, OpenJPA) can be swapped in.
- **Hibernate (implementation):** Ships `hibernate-core`. Implements `EntityManager` via its `Session` interface. Adds:
  - **HQL** "” superset of JPQL with Hibernate-specific functions
  - **Session / SessionFactory** "” native Hibernate API (more powerful than `EntityManager`)
  - **First-level cache** "” per `Session`, automatic
  - **Second-level cache** "” shared across sessions, pluggable (EhCache, Redis, Caffeine)
  - **Batch processing** "” `hibernate.jdbc.batch_size`, `@BatchSize`
  - **Filters, interceptors, events**
  - **Envers** "” entity auditing
- Spring Data JPA sits on top of JPA and provides repository abstractions, further simplifying data access.

**Real-World Example:**
In a payment processing system, the team uses JPA annotations (`@Entity`, `@OneToMany`) for portability. But for high-throughput batch inserts of 10,000 payment records, they configure `hibernate.jdbc.batch_size=50` and use Hibernate's second-level cache for frequently read `PaymentStatus` lookup tables "” features that go beyond what the JPA spec mandates.

**Java Code Example:**
```java
// JPA-only code "” works with any JPA provider
import jakarta.persistence.*;

@Entity
@Table(name = "orders")
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "order_seq")
    @SequenceGenerator(name = "order_seq", sequenceName = "order_seq", allocationSize = 50)
    private Long id;

    @Column(nullable = false)
    private String customerId;

    @Column(nullable = false)
    private java.math.BigDecimal totalAmount;

    // getters / setters omitted for brevity
}

// Hibernate-specific: accessing Session for batch flush
import org.hibernate.Session;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import jakarta.persistence.EntityManager;

@Service
public class OrderBatchService {

    private final EntityManager em;

    public OrderBatchService(EntityManager em) {
        this.em = em;
    }

    @Transactional
    public void bulkInsert(List<Order> orders) {
        Session session = em.unwrap(Session.class); // Hibernate-specific
        for (int i = 0; i < orders.size(); i++) {
            session.persist(orders.get(i));
            if (i % 50 == 0) {
                session.flush();
                session.clear(); // free first-level cache
            }
        }
    }
}
```

**Follow-up Questions:**
1. Can you replace Hibernate with EclipseLink in a Spring Boot app? What changes?
2. What is the difference between JPA's `EntityManager` and Hibernate's `Session`?
3. Why does Spring Boot auto-configure Hibernate as the JPA provider?

**Common Mistakes:**
- Mixing `jakarta.persistence` and `javax.persistence` imports (Spring Boot 3 requires `jakarta.*`)
- Treating HQL and JPQL as identical "” HQL has additional Hibernate-specific syntax
- Forgetting that `SessionFactory` is the Hibernate equivalent of `EntityManagerFactory`

**Interview Trap:**
"Hibernate IS JPA" "” Wrong. Hibernate implements JPA but also provides features outside the JPA specification. You can use Hibernate directly (via `Session`) without any JPA annotations.

**Quick Revision:**
- JPA = specification (`jakarta.persistence`) | Hibernate = implementation
- Hibernate extras: HQL, Session, L2 cache, batch, Envers
- Spring Boot 3 uses `jakarta.*` (not `javax.*`)

---

## Q2: Entity Lifecycle States

**Difficulty:** Medium | **Interview Frequency:** Very High
**Companies:** Amazon, Uber, Swiggy, PhonePe, Oracle, SAP, Thoughtworks

**Short Answer (30-60 seconds):**
A JPA entity goes through four lifecycle states: **Transient** (new object, not known to persistence context), **Persistent** (managed by `EntityManager`, changes are tracked), **Detached** (was managed, session closed or explicitly detached), and **Removed** (marked for deletion). State transitions happen via `persist()`, `merge()`, `remove()`, `detach()`, and `refresh()`. The key trap: `merge()` returns a NEW managed instance "” the original object passed in remains detached.

**Deep Explanation:**

| State | Description | DB row exists | Tracked by EM |
|---|---|---|---|
| Transient | `new Entity()`, no ID, not persisted | No | No |
| Persistent | After `persist()` or loaded from DB | Yes (or pending flush) | Yes |
| Detached | After session close / `detach()` / `clear()` | Yes | No |
| Removed | After `remove()` called | Will be deleted on flush | Yes (for deletion) |

**State Transitions:**
- `persist(entity)` â†’ Transient â†’ Persistent
- `remove(entity)` â†’ Persistent â†’ Removed
- `detach(entity)` â†’ Persistent â†’ Detached
- `merge(detached)` â†’ Detached â†’ returns new Persistent instance (original stays Detached)
- `refresh(entity)` â†’ reloads persistent entity from DB (discards in-memory changes)
- Session close â†’ all Persistent â†’ Detached

**Critical merge() behavior:** `merge()` copies the state of the detached object into a managed entity (or creates a new one) and returns the managed copy. The caller MUST use the returned reference.

**Real-World Example:**
In an e-commerce checkout flow, an `Order` entity is loaded in one HTTP request (session closes, entity becomes detached). The user updates the shipping address and sends a PUT request. The controller receives a detached `Order`. Wrong: calling `entityManager.persist(detachedOrder)` throws `EntityExistsException`. Correct: `Order managed = entityManager.merge(detachedOrder)` "” use `managed` from that point.

**Java Code Example:**
```java
import jakarta.persistence.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OrderLifecycleService {

    @PersistenceContext
    private EntityManager em;

    @Transactional
    public void demonstrateLifecycle() {
        // 1. TRANSIENT "” not known to persistence context
        Order order = new Order();
        order.setCustomerId("CUST-001");
        order.setTotalAmount(new java.math.BigDecimal("499.99"));

        // 2. PERSISTENT "” tracked; INSERT will happen on flush
        em.persist(order);
        System.out.println("State: Persistent, id=" + order.getId());

        // 3. DETACHED "” no longer tracked
        em.detach(order);
        order.setTotalAmount(new java.math.BigDecimal("599.99")); // change ignored

        // 4. MERGE "” returns NEW managed instance; original stays detached
        Order managedOrder = em.merge(order);
        // managedOrder.getTotalAmount() == 599.99, tracked for UPDATE
        // order (original) is still detached

        // 5. REMOVED "” will be deleted on flush/commit
        em.remove(managedOrder);
        // managedOrder is now in Removed state
    }

    @Transactional
    public void refreshExample(Long orderId) {
        Order order = em.find(Order.class, orderId);
        order.setTotalAmount(new java.math.BigDecimal("999.99")); // in-memory change

        // Discard in-memory change, reload from DB
        em.refresh(order);
        // order.getTotalAmount() now reflects DB value
    }
}
```

**Follow-up Questions:**
1. What happens if you call `persist()` on a detached entity?
2. What does `merge()` do if the entity does not exist in the DB?
3. What is the difference between `detach()` and `clear()`?

**Common Mistakes:**
- Using the original object after `merge()` instead of the returned managed instance
- Calling `persist()` on a detached entity (throws `EntityExistsException` or `DetachedObjectException`)
- Not understanding that `clear()` detaches ALL entities in the persistence context

**Interview Trap:**
"merge() updates the original object and makes it managed" "” Wrong. `merge()` copies state to a new (or existing) managed instance and returns it. The passed-in detached object stays detached.

**Quick Revision:**
- 4 states: Transient â†’ Persistent â†’ Detached / Removed
- `merge()` returns a new managed copy; original stays detached "” always use the return value
- `refresh()` discards in-memory changes and reloads from DB

---

## Q3: EntityManager vs Session

**Difficulty:** Medium | **Interview Frequency:** High
**Companies:** Goldman Sachs, Morgan Stanley, Thoughtworks, Razorpay, Zomato

**Short Answer (30-60 seconds):**
`EntityManager` is the JPA standard API; Hibernate's `Session` extends it with additional capabilities. Key differences: `save()` (Hibernate, always inserts, returns generated ID immediately) vs `persist()` (JPA, void return); `get()` (returns null if not found) vs `load()` (returns a proxy, throws `ObjectNotFoundException` on access if not found). You access `Session` from `EntityManager` via `em.unwrap(Session.class)`.

**Deep Explanation:**

| Operation | JPA EntityManager | Hibernate Session |
|---|---|---|
| Save new entity | `persist(entity)` "” void | `save(entity)` "” returns Serializable ID |
| Save or update | `merge(entity)` "” returns managed copy | `saveOrUpdate(entity)` "” void, mutates original |
| Find by ID | `find(Class, id)` "” returns null if absent | `get(Class, id)` "” returns null if absent |
| Proxy by ID | No direct equivalent | `load(Class, id)` "” returns proxy; throws if accessed and absent |
| Flush | `flush()` | `flush()` |
| Clear context | `clear()` | `clear()` |
| Execute HQL | `createQuery(jpql)` | `createQuery(hql)` + additional methods |
| Batch scroll | Not in spec | `scroll()` "” server-side cursor |

**`load()` vs `get()` detail:**
- `get()` hits the DB immediately, returns null if not found.
- `load()` returns a Hibernate proxy without hitting the DB. The proxy initializes on first field access. If the row doesn't exist, accessing any field throws `org.hibernate.ObjectNotFoundException`.
- Use `load()` when you need a reference for a foreign key association and you know the row exists (avoids an unnecessary SELECT).

**Real-World Example:**
In a payment service, when creating a `Payment` that must reference an existing `Order`, using `session.load(Order.class, orderId)` avoids a SELECT "” you just need the proxy for the FK. If you use `em.find()`, an extra SELECT fires even though you only need the ID for the FK column.

**Java Code Example:**
```java
import jakarta.persistence.*;
import org.hibernate.Session;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PaymentService {

    @PersistenceContext
    private EntityManager em;

    @Transactional
    public Payment createPayment(Long orderId, java.math.BigDecimal amount) {
        // load() returns proxy "” no SELECT fired yet
        // Use when you know the Order exists and only need the FK reference
        Session session = em.unwrap(Session.class);
        Order orderRef = session.load(Order.class, orderId); // no DB hit

        Payment payment = new Payment();
        payment.setOrder(orderRef); // sets FK, still no SELECT
        payment.setAmount(amount);
        payment.setStatus("PENDING");

        em.persist(payment); // INSERT payment with order_id FK
        return payment;
    }

    @Transactional(readOnly = true)
    public Order findOrderSafely(Long orderId) {
        // find() hits DB immediately "” returns null if row absent
        return em.find(Order.class, orderId); // null-safe
    }

    @Transactional
    public void updateOrderAmount(Long orderId, java.math.BigDecimal newAmount) {
        Order order = em.find(Order.class, orderId);
        if (order == null) throw new RuntimeException("Order not found: " + orderId);

        order.setTotalAmount(newAmount);
        // No explicit save needed "” dirty checking fires UPDATE on flush
    }

    @Transactional
    public Order mergeDetachedOrder(Order detachedOrder) {
        // merge() vs saveOrUpdate():
        // merge() returns new managed instance (JPA standard)
        // saveOrUpdate() modifies the passed-in object in place (Hibernate)
        return em.merge(detachedOrder); // use returned instance
    }
}
```

**Follow-up Questions:**
1. When would you prefer `load()` over `find()`?
2. What exception does `load()` throw and when?
3. Why is `save()` potentially dangerous in a merge scenario?

**Common Mistakes:**
- Using `load()` when the row might not exist "” triggers `ObjectNotFoundException` on proxy access
- Not using the return value of `merge()` (the original detached object is not managed)
- Calling `flush()` without an active transaction

**Interview Trap:**
"`load()` is faster than `find()` so always use it" "” Wrong. `load()` defers the DB hit to proxy access; if you immediately access a field, it hits the DB anyway. The benefit is only when you need the reference solely for FK association without reading fields.

**Quick Revision:**
- `find()` â†’ null if absent | `load()` â†’ proxy, throws `ObjectNotFoundException` on access if absent
- `persist()` â†’ void | `save()` â†’ returns ID
- `merge()` â†’ returns new managed copy | `saveOrUpdate()` â†’ mutates original

---

## Q4: @Entity, @Table, @Id, @GeneratedValue

**Difficulty:** Easy | **Interview Frequency:** Very High
**Companies:** Infosys, Wipro, Accenture, TCS, HCL, Cognizant, Capgemini

**Short Answer (30-60 seconds):**
`@Entity` marks a class as a JPA entity; `@Table` overrides the default table name. `@Id` marks the primary key; `@GeneratedValue` controls how IDs are generated. There are four strategies: `IDENTITY` (DB auto-increment, breaks batch inserts), `SEQUENCE` (DB sequence, best for batches "” pre-allocates IDs), `TABLE` (a dedicated table, worst performance), and `AUTO` (provider chooses). For high-throughput systems, always prefer `SEQUENCE` with a meaningful `allocationSize`.

**Deep Explanation:**

| Strategy | Mechanism | Batch-friendly | Notes |
|---|---|---|---|
| `IDENTITY` | DB auto-increment (`AUTO_INCREMENT`, `SERIAL`) | No | Each INSERT needs a DB roundtrip to get the generated ID; disables JDBC batch |
| `SEQUENCE` | DB sequence object | Yes | Hibernate pre-allocates IDs in blocks (`allocationSize`); no extra roundtrip per row |
| `TABLE` | Simulates sequence in a table | No | Pessimistic locks on the ID table; worst for concurrency |
| `AUTO` | Provider decides | Depends | Hibernate 6 defaults to `SEQUENCE`; may create `hibernate_sequence` |

**Why IDENTITY breaks batch inserts:**
JDBC batching works by buffering multiple statements and sending them in one round trip. With `IDENTITY`, Hibernate must execute each INSERT immediately and call `getGeneratedKeys()` to obtain the ID (needed to populate the entity's `@Id` field and manage the first-level cache). This forces Hibernate to flush each statement individually, defeating the batch.

**Why SEQUENCE is preferred:**
Hibernate calls `nextval` on the sequence in advance (or in bulk via `allocationSize`), assigns IDs to entities before INSERT, then batches all INSERTs in one JDBC batch. With `allocationSize=50`, 50 IDs are reserved per sequence call "” only 1 sequence call per 50 inserts.

**Real-World Example:**
An order management system processes 5,000 orders per minute during a flash sale. Using `IDENTITY` strategy: 5,000 individual INSERTs, each requiring a roundtrip. Switching to `SEQUENCE` with `allocationSize=50`: 100 sequence calls + 1 batched JDBC call for all 5,000 rows "” throughput improves by ~10x.

**Java Code Example:**
```java
import jakarta.persistence.*;
import org.hibernate.annotations.BatchSize;

// WRONG for high-throughput "” IDENTITY breaks batch inserts
@Entity
@Table(name = "orders_bad")
public class OrderWithIdentity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY) // disables JDBC batch
    private Long id;
}

// CORRECT for high-throughput "” SEQUENCE with pre-allocation
@Entity
@Table(
    name = "orders",
    indexes = {
        @Index(name = "idx_orders_customer_id", columnList = "customer_id"),
        @Index(name = "idx_orders_status", columnList = "status")
    },
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_orders_reference", columnNames = "order_reference")
    }
)
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "order_seq_gen")
    @SequenceGenerator(
        name = "order_seq_gen",
        sequenceName = "order_id_seq",   // DB sequence name
        allocationSize = 50              // reserve 50 IDs per sequence call
    )
    private Long id;

    @Column(name = "customer_id", nullable = false, length = 50)
    private String customerId;

    @Column(name = "order_reference", nullable = false, unique = true, length = 36)
    private String orderReference;

    @Column(name = "total_amount", nullable = false, precision = 19, scale = 4)
    private java.math.BigDecimal totalAmount;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private java.time.Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = java.time.Instant.now();
        if (this.orderReference == null) {
            this.orderReference = java.util.UUID.randomUUID().toString();
        }
    }

    // getters and setters
    public Long getId() { return id; }
    public String getCustomerId() { return customerId; }
    public void setCustomerId(String customerId) { this.customerId = customerId; }
    public String getOrderReference() { return orderReference; }
    public void setOrderReference(String orderReference) { this.orderReference = orderReference; }
    public java.math.BigDecimal getTotalAmount() { return totalAmount; }
    public void setTotalAmount(java.math.BigDecimal totalAmount) { this.totalAmount = totalAmount; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public java.time.Instant getCreatedAt() { return createdAt; }
}
```

**application.properties for batch inserts:**
```properties
spring.jpa.properties.hibernate.jdbc.batch_size=50
spring.jpa.properties.hibernate.order_inserts=true
spring.jpa.properties.hibernate.order_updates=true
```

**Follow-up Questions:**
1. What is `allocationSize` in `@SequenceGenerator` and what happens if two app instances run concurrently with the same sequence?
2. Why does MySQL not have native sequences before 8.0 and how do you handle it?
3. When would you use `GenerationType.TABLE`?

**Common Mistakes:**
- Using `IDENTITY` then wondering why batch inserts are slow
- Setting `allocationSize=1` (defeats the purpose of pre-allocation "” same as IDENTITY in terms of roundtrips)
- Not specifying `sequenceName` "” Hibernate may share a default sequence across entities

**Interview Trap:**
"AUTO is the safest default" "” In Hibernate 6, `AUTO` generates a table-based sequence (`hibernate_sequence`) if no dialect-specific default is found. Always specify the strategy and sequence name explicitly for production.

**Quick Revision:**
- `IDENTITY` = DB auto-increment = NO batch inserts
- `SEQUENCE` = pre-allocated IDs = YES batch inserts (set `allocationSize` to batch size)
- `TABLE` = worst performance, avoid
- `AUTO` = Hibernate decides, unpredictable "” be explicit in production

---

## Q5: @Column, @Transient, @Lob, @Enumerated, @Embedded/@Embeddable

**Difficulty:** Easy | **Interview Frequency:** High
**Companies:** TCS, Infosys, Wipro, HCL, Persistent Systems

**Short Answer (30-60 seconds):**
These annotations control column mapping. `@Column` maps a field to a DB column with constraints. `@Transient` excludes a field from persistence. `@Lob` maps large objects (CLOB/BLOB). `@Enumerated` maps Java enums "” always use `EnumType.STRING`, never `ORDINAL`: adding a new enum constant in the middle breaks all existing `ORDINAL` data. `@Embeddable` marks a class as a value type embedded inside an entity; `@Embedded` uses it.

**Deep Explanation:**

**@Enumerated Danger:**
```
// Enum: PENDING=0, PROCESSING=1, COMPLETED=2  (ORDINAL positions)
// DB stores: 0, 1, 2
// New requirement: add CANCELLED before COMPLETED
// New enum: PENDING=0, PROCESSING=1, CANCELLED=2, COMPLETED=3
// DB row with value=2 now maps to CANCELLED, not COMPLETED "” silent data corruption!
```
Always use `@Enumerated(EnumType.STRING)`. The storage cost is negligible; the data integrity benefit is enormous.

**@Embedded / @Embeddable:**
Allows splitting a flat table into logical value objects. The embedded object has no identity of its own "” it shares the entity's identity. Useful for `Address`, `MoneyAmount`, `AuditInfo`.

**@Lob:**
Maps to `CLOB` (for `String`) or `BLOB` (for `byte[]`). Hibernate may fetch LOBs lazily by default depending on the driver. For large documents, prefer storing files in object storage (S3) and saving the URL.

**Real-World Example:**
A product catalog stores a payment method enum. Initially only `CREDIT_CARD` and `DEBIT_CARD` exist. Six months later, `UPI` is added between them in alphabetical order. With `ORDINAL`, every existing `DEBIT_CARD` record (stored as `1`) now reads as `UPI` "” a production disaster.

**Java Code Example:**
```java
import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

// Embeddable value object "” no @Id, no identity
@Embeddable
public class Money {

    @Column(name = "amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal value;

    @Column(name = "currency", nullable = false, length = 3)
    private String currency;

    protected Money() {}

    public Money(BigDecimal value, String currency) {
        this.value = value;
        this.currency = currency;
    }

    public BigDecimal getValue() { return value; }
    public String getCurrency() { return currency; }
}

// Enum "” always STRING
public enum PaymentStatus {
    PENDING, PROCESSING, COMPLETED, FAILED, REFUNDED
}

@Entity
@Table(name = "payments")
public class Payment {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "payment_seq")
    @SequenceGenerator(name = "payment_seq", sequenceName = "payment_id_seq", allocationSize = 50)
    private Long id;

    // @Embedded "” columns (amount, currency) go into payments table
    @Embedded
    private Money totalAmount;

    // CORRECT "” stores "PENDING", "COMPLETED", etc.
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private PaymentStatus status;

    // WRONG "” stores 0, 1, 2 "” brittle!
    // @Enumerated(EnumType.ORDINAL)
    // private PaymentStatus status;

    // Large text "” maps to CLOB
    @Lob
    @Column(name = "payment_notes")
    private String paymentNotes;

    // Not persisted "” computed field
    @Transient
    private boolean isHighValue;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PostLoad
    @PrePersist
    private void computeTransientFields() {
        this.isHighValue = totalAmount != null
            && totalAmount.getValue().compareTo(new BigDecimal("100000")) > 0;
    }

    // getters and setters
    public Long getId() { return id; }
    public Money getTotalAmount() { return totalAmount; }
    public void setTotalAmount(Money totalAmount) { this.totalAmount = totalAmount; }
    public PaymentStatus getStatus() { return status; }
    public void setStatus(PaymentStatus status) { this.status = status; }
    public String getPaymentNotes() { return paymentNotes; }
    public void setPaymentNotes(String paymentNotes) { this.paymentNotes = paymentNotes; }
    public boolean isHighValue() { return isHighValue; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
```

**Follow-up Questions:**
1. What is the difference between `@Embedded` and `@OneToOne`?
2. How do you override column names when the same `@Embeddable` is used twice in one entity?
3. Can an `@Embeddable` class contain another `@Embeddable`?

**Common Mistakes:**
- Using `@Enumerated(EnumType.ORDINAL)` in production
- Forgetting `@Transient` on computed fields "” Hibernate tries to map them and may throw an exception
- Using `@Lob` for small strings "” incurs overhead; use `@Column(length=...)` for short strings

**Interview Trap:**
"ORDINAL is more efficient because it stores integers" "” The storage saving is trivial; the risk of silent data corruption from enum reordering is not worth it. Always use STRING.

**Quick Revision:**
- `@Enumerated(EnumType.STRING)` "” always, never ORDINAL
- `@Transient` "” excluded from persistence
- `@Embedded` + `@Embeddable` "” flat table, logical grouping, no separate table
- `@Lob` "” CLOB (String) / BLOB (byte[])

---

## Q6: @OneToOne, @OneToMany, @ManyToOne, @ManyToMany

**Difficulty:** Medium | **Interview Frequency:** Very High
**Companies:** Amazon, Flipkart, Ola, Swiggy, Uber, Paytm, Goldman Sachs

**Short Answer (30-60 seconds):**
JPA associations are mapped with cardinality annotations. The **owning side** has `@JoinColumn` and controls the FK column; the **inverse side** uses `mappedBy`. In bidirectional associations you must set both sides in Java. `CascadeType.REMOVE` on `@ManyToMany` is dangerous "” deleting one entity deletes all associated entities. Use `orphanRemoval=true` on `@OneToMany` to automatically delete child records when removed from the parent collection.

**Deep Explanation:**

**Owning vs Inverse Side:**
- The owning side holds the `@JoinColumn` (FK) and its state is what Hibernate persists.
- The inverse side has `mappedBy="fieldNameOnOwner"` "” it's a mirror, purely for navigation.
- Mistake: only setting the `mappedBy` side "” Hibernate ignores it for persistence.

**Cascade Types:**
| Type | Effect |
|---|---|
| `PERSIST` | Persist child when parent is persisted |
| `MERGE` | Merge child when parent is merged |
| `REMOVE` | Delete child when parent is deleted |
| `REFRESH` | Refresh child when parent is refreshed |
| `DETACH` | Detach child when parent is detached |
| `ALL` | All of the above |

**CascadeType.REMOVE danger on @ManyToMany:**
If `Order` has `@ManyToMany(cascade = CascadeType.REMOVE)` to `Product`, deleting one `Order` would delete all its associated `Products` from the DB "” including products used by other orders. Never use `CascadeType.REMOVE` (or `ALL`) on `@ManyToMany`.

**orphanRemoval:**
When `true` on `@OneToMany`, removing a child from the parent's collection automatically issues a DELETE for that child. This is stronger than `CascadeType.REMOVE` (which only cascades the `remove()` call).

**Real-World Example:**
In an e-commerce system: `Order` has a `@OneToOne` to `ShippingAddress`, `@OneToMany` to `OrderItem`, and `@ManyToMany` to `Coupon`. The `OrderItem` has `@ManyToOne` back to `Order` (owning side with `@JoinColumn`). `orphanRemoval=true` on `@OneToMany(mappedBy="order")` ensures removed items are deleted.

**Java Code Example:**
```java
import jakarta.persistence.*;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Entity
@Table(name = "shipping_addresses")
public class ShippingAddress {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "addr_seq")
    @SequenceGenerator(name = "addr_seq", sequenceName = "address_id_seq", allocationSize = 10)
    private Long id;

    @Column(nullable = false)
    private String street;

    @Column(nullable = false, length = 100)
    private String city;

    @Column(nullable = false, length = 10)
    private String postalCode;

    // Inverse side of @OneToOne "” mappedBy points to Order.shippingAddress
    @OneToOne(mappedBy = "shippingAddress")
    private Order order;

    public Long getId() { return id; }
    public String getStreet() { return street; }
    public void setStreet(String street) { this.street = street; }
    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }
    public String getPostalCode() { return postalCode; }
    public void setPostalCode(String postalCode) { this.postalCode = postalCode; }
}

@Entity
@Table(name = "order_items")
public class OrderItem {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "item_seq")
    @SequenceGenerator(name = "item_seq", sequenceName = "order_item_id_seq", allocationSize = 50)
    private Long id;

    // OWNING SIDE "” has @JoinColumn, controls the FK
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Column(name = "product_id", nullable = false)
    private Long productId;

    @Column(nullable = false)
    private int quantity;

    @Column(name = "unit_price", nullable = false, precision = 19, scale = 4)
    private BigDecimal unitPrice;

    public Long getId() { return id; }
    public Order getOrder() { return order; }
    public void setOrder(Order order) { this.order = order; }
    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }
    public int getQuantity() { return quantity; }
    public void setQuantity(int quantity) { this.quantity = quantity; }
    public BigDecimal getUnitPrice() { return unitPrice; }
    public void setUnitPrice(BigDecimal unitPrice) { this.unitPrice = unitPrice; }
}

@Entity
@Table(name = "coupons")
public class Coupon {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "coupon_seq")
    @SequenceGenerator(name = "coupon_seq", sequenceName = "coupon_id_seq", allocationSize = 10)
    private Long id;

    @Column(nullable = false, unique = true, length = 20)
    private String code;

    // Inverse side of @ManyToMany "” NO cascade REMOVE here!
    @ManyToMany(mappedBy = "coupons")
    private Set<Order> orders = new HashSet<>();

    public Long getId() { return id; }
    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }
    public Set<Order> getOrders() { return orders; }
}

@Entity
@Table(name = "orders")
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "order_seq2")
    @SequenceGenerator(name = "order_seq2", sequenceName = "order_id_seq", allocationSize = 50)
    private Long id;

    @Column(name = "customer_id", nullable = false)
    private String customerId;

    // @OneToOne "” owning side (has @JoinColumn)
    @OneToOne(cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @JoinColumn(name = "shipping_address_id", unique = true)
    private ShippingAddress shippingAddress;

    // @OneToMany "” inverse side (mappedBy), orphanRemoval ensures child cleanup
    @OneToMany(
        mappedBy = "order",
        cascade = CascadeType.ALL,
        orphanRemoval = true,
        fetch = FetchType.LAZY
    )
    private List<OrderItem> items = new ArrayList<>();

    // @ManyToMany "” owning side, NO CascadeType.REMOVE
    @ManyToMany(cascade = {CascadeType.PERSIST, CascadeType.MERGE})
    @JoinTable(
        name = "order_coupons",
        joinColumns = @JoinColumn(name = "order_id"),
        inverseJoinColumns = @JoinColumn(name = "coupon_id")
    )
    private Set<Coupon> coupons = new HashSet<>();

    // Helper methods "” MUST set both sides of bidirectional association
    public void addItem(OrderItem item) {
        items.add(item);
        item.setOrder(this); // set owning side
    }

    public void removeItem(OrderItem item) {
        items.remove(item);
        item.setOrder(null); // orphanRemoval will delete it
    }

    public void addCoupon(Coupon coupon) {
        coupons.add(coupon);
        coupon.getOrders().add(this); // set both sides
    }

    public Long getId() { return id; }
    public String getCustomerId() { return customerId; }
    public void setCustomerId(String customerId) { this.customerId = customerId; }
    public ShippingAddress getShippingAddress() { return shippingAddress; }
    public void setShippingAddress(ShippingAddress addr) { this.shippingAddress = addr; }
    public List<OrderItem> getItems() { return items; }
    public Set<Coupon> getCoupons() { return coupons; }
}
```

**Follow-up Questions:**
1. What happens if you only set the `mappedBy` side of a bidirectional `@OneToMany`?
2. What is the difference between `CascadeType.REMOVE` and `orphanRemoval=true`?
3. Why should `@ManyToMany` owning side not have `CascadeType.REMOVE`?

**Common Mistakes:**
- Not setting both sides of a bidirectional relationship in Java "” one side is ignored by Hibernate
- Using `CascadeType.ALL` (which includes REMOVE) on `@ManyToMany`
- Mixing up owning and inverse sides "” always `@JoinColumn` on owning, `mappedBy` on inverse

**Interview Trap:**
"The `mappedBy` side controls the FK" "” Wrong. The owning side (with `@JoinColumn`) controls the FK. Changes made only to the `mappedBy` side are ignored by Hibernate.

**Quick Revision:**
- Owning side = `@JoinColumn` | Inverse side = `mappedBy`
- Always set both sides in Java helper methods
- `CascadeType.REMOVE` on `@ManyToMany` = data disaster
- `orphanRemoval=true` automatically deletes children removed from collection

---

## Q7: FetchType.LAZY vs EAGER

**Difficulty:** Medium | **Interview Frequency:** Very High
**Companies:** Amazon, Uber, Zomato, Paytm, Razorpay, Thoughtworks, Goldman Sachs

**Short Answer (30-60 seconds):**
`LAZY` loading defers loading associated data until it is accessed; `EAGER` loads it immediately with the parent. JPA defaults: `@OneToMany` and `@ManyToMany` are `LAZY`; `@ManyToOne` and `@OneToOne` are `EAGER`. The most common mistake is accessing a `LAZY` association after the session closes, causing `LazyInitializationException`. Fixes: JOIN FETCH in JPQL, `@EntityGraph`, DTO projections, or `@Transactional` on the calling method.

**Deep Explanation:**

**JPA Default Fetch Types:**
| Association | JPA Default | Recommended |
|---|---|---|
| `@OneToMany` | LAZY | LAZY |
| `@ManyToMany` | LAZY | LAZY |
| `@ManyToOne` | EAGER | LAZY (override!) |
| `@OneToOne` | EAGER | LAZY (override!) |

**Why override `@ManyToOne` to LAZY?**
If `OrderItem` has `@ManyToOne` to `Order` as EAGER, loading 100 `OrderItem` records fires 100 additional SELECTs for the orders "” a classic N+1 scenario built into the mapping.

**LazyInitializationException:**
Occurs when you access a lazy collection/proxy after the `EntityManager` / `Session` has been closed. Common in REST controllers that return entities directly.

**Fixes:**
1. **JOIN FETCH** "” `SELECT o FROM Order o JOIN FETCH o.items WHERE o.id = :id`
2. **@EntityGraph** "” declarative JOIN FETCH on repository method
3. **DTO projection** "” fetch only needed data, no lazy association problem
4. **`@Transactional` on service method** "” keeps session open during access (careful: keeps transaction open longer)
5. **`spring.jpa.open-in-view=true`** "” NOT recommended for production (keeps session open for entire HTTP request, hides N+1 problems)

**Real-World Example:**
An order summary API loads an `Order` and then in the controller accesses `order.getItems()` to calculate the total. The session is closed by the time the controller runs. `LazyInitializationException` is thrown. Fix: use a JOIN FETCH query or DTO projection in the service layer.

**Java Code Example:**
```java
import jakarta.persistence.*;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.Optional;

// Repository with multiple fetch strategies
public interface OrderRepository extends JpaRepository<Order, Long> {

    // Fix 1: JOIN FETCH in JPQL "” loads items in single SQL JOIN
    @Query("SELECT DISTINCT o FROM Order o JOIN FETCH o.items WHERE o.id = :id")
    Optional<Order> findByIdWithItems(@Param("id") Long id);

    // Fix 2: @EntityGraph "” declarative, generates LEFT JOIN FETCH
    @EntityGraph(attributePaths = {"items", "shippingAddress"})
    @Query("SELECT o FROM Order o WHERE o.id = :id")
    Optional<Order> findByIdWithGraph(@Param("id") Long id);

    // Fix 3: DTO projection "” constructor expression, no entity, no LazyInitializationException
    @Query("""
        SELECT new com.example.dto.OrderSummaryDto(
            o.id, o.customerId, o.totalAmount, COUNT(i)
        )
        FROM Order o LEFT JOIN o.items i
        WHERE o.customerId = :customerId
        GROUP BY o.id, o.customerId, o.totalAmount
        """)
    List<OrderSummaryDto> findOrderSummariesByCustomer(@Param("customerId") String customerId);
}

// DTO for projection
package com.example.dto;

import java.math.BigDecimal;

public record OrderSummaryDto(Long orderId, String customerId, BigDecimal totalAmount, Long itemCount) {}

// Service "” @Transactional keeps session open
@Service
public class OrderService {

    private final OrderRepository orderRepository;

    public OrderService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    // @Transactional keeps session open "” items can be accessed within this method
    @Transactional(readOnly = true)
    public Order getOrderWithItems(Long orderId) {
        // Session is open for the duration of this method
        Order order = orderRepository.findByIdWithItems(orderId)
            .orElseThrow(() -> new RuntimeException("Order not found: " + orderId));
        // safe: items already JOIN FETCHed
        order.getItems().size(); // no LazyInitializationException
        return order;
    }

    // Best practice for read-only APIs: DTO projection
    @Transactional(readOnly = true)
    public List<OrderSummaryDto> getOrderSummaries(String customerId) {
        return orderRepository.findOrderSummariesByCustomer(customerId);
    }
}
```

**application.properties:**
```properties
# Disable open-in-view (recommended for production)
spring.jpa.open-in-view=false
# See SQL to diagnose LazyInitializationException sources
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
```

**Follow-up Questions:**
1. What is `open-in-view` and why should it be disabled in production?
2. What is the difference between `@EntityGraph` and `JOIN FETCH`?
3. Can you have a `LAZY` `@OneToOne`? What is special about it?

**Common Mistakes:**
- Leaving `@ManyToOne` as the default EAGER, causing unwanted SELECTs
- Enabling `open-in-view=true` to "fix" `LazyInitializationException` "” hides N+1 problems
- Using `@Transactional` on controller methods to keep session open "” wrong layer for transaction boundary

**Interview Trap:**
"EAGER is safer because you avoid LazyInitializationException" "” EAGER causes N+1 queries and loads data you may not need. Always default to LAZY and fetch eagerly only when required using JOIN FETCH or `@EntityGraph`.

**Quick Revision:**
- `@OneToMany`/`@ManyToMany` default = LAZY | `@ManyToOne`/`@OneToOne` default = EAGER (override to LAZY)
- `LazyInitializationException` = accessing lazy association after session close
- Fixes: JOIN FETCH, `@EntityGraph`, DTO projection
- Disable `open-in-view` in production

---

## Q8: N+1 Query Problem

**Difficulty:** Hard | **Interview Frequency:** Very High
**Companies:** Amazon, Google, Uber, Flipkart, Paytm, Goldman Sachs, Razorpay, Swiggy, Zomato, Thoughtworks

**Short Answer (30-60 seconds):**
The N+1 problem occurs when loading N parent entities fires one SELECT per parent to load their children "” 1 query for the parents + N queries for the children = N+1 total queries. For 1,000 orders, that is 1,001 queries instead of 1. This is the most impactful performance problem in Hibernate. Four solutions: JOIN FETCH (JPQL), `@EntityGraph` (declarative), batch fetching (`hibernate.default_batch_fetch_size`), and DTO projection (avoids the problem entirely).

**Deep Explanation:**

**How N+1 Happens:**
```
SELECT * FROM orders;                    -- 1 query, returns 1000 rows
SELECT * FROM order_items WHERE order_id = 1;  -- N queries (one per order)
SELECT * FROM order_items WHERE order_id = 2;
...
SELECT * FROM order_items WHERE order_id = 1000;
-- Total: 1001 queries
```

**Detection:**
- `spring.jpa.show-sql=true` + `spring.jpa.properties.hibernate.format_sql=true` "” see all queries in logs
- **p6spy** "” logs queries with timing
- **Hibernate Statistics** "” `hibernate.generate_statistics=true`
- **Datadog / New Relic APM** "” detect slow transactions with many queries

**Four Solutions Compared:**

| Solution | SQL | Type-safe | Dynamic | Cons |
|---|---|---|---|---|
| JOIN FETCH (JPQL) | 1 JOIN query | No | No | Cartesian product risk with multiple collections |
| `@EntityGraph` | 1 JOIN query | Partial | Partial | Same cartesian risk; verbose for deep graphs |
| Batch Fetching | `IN (id1,id2,...)` | N/A | Yes | Multiple queries still, but batched |
| DTO Projection | Minimal SELECT | No | Yes | No entity, no dirty checking |

**Cartesian Product Warning:**
If you JOIN FETCH two collections simultaneously (`ORDER JOIN FETCH items JOIN FETCH coupons`), SQL produces `items.size Ã— coupons.size` rows per order "” Hibernate deduplicates but it wastes network/DB resources. Solution: fetch one collection per query or use `@BatchSize`.

**Real-World Example:**
An order history page loads all orders for a customer and displays item counts and totals. Without fix: 1 + N queries (N = number of orders). With DTO projection: 1 aggregating query. Response time drops from 800ms to 12ms for a customer with 500 orders.

**Java Code Example:**
```java
import jakarta.persistence.*;
import org.hibernate.annotations.BatchSize;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.util.List;

// SOLUTION A: JOIN FETCH in JPQL
// SOLUTION B: @EntityGraph
// SOLUTION C: Batch fetching via @BatchSize
// SOLUTION D: DTO projection

// Entity with @BatchSize for Solution C
@Entity
@Table(name = "orders")
public class OrderV2 {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "orderv2_seq")
    @SequenceGenerator(name = "orderv2_seq", sequenceName = "order_id_seq", allocationSize = 50)
    private Long id;

    @Column(name = "customer_id", nullable = false)
    private String customerId;

    @Column(name = "total_amount", precision = 19, scale = 4)
    private BigDecimal totalAmount;

    // @BatchSize: when loading items, Hibernate will batch them: IN (id1, id2, ..., id50)
    @BatchSize(size = 50)
    @OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
    private List<OrderItem> items;

    public Long getId() { return id; }
    public String getCustomerId() { return customerId; }
    public void setCustomerId(String customerId) { this.customerId = customerId; }
    public BigDecimal getTotalAmount() { return totalAmount; }
    public void setTotalAmount(BigDecimal totalAmount) { this.totalAmount = totalAmount; }
    public List<OrderItem> getItems() { return items; }
}

// DTO for Solution D
record OrderWithItemsDto(Long orderId, String customerId, Long productId, int quantity, BigDecimal unitPrice) {}

public interface OrderRepositoryV2 extends JpaRepository<OrderV2, Long> {

    // Solution A: JOIN FETCH "” single SQL JOIN
    @Query("SELECT DISTINCT o FROM OrderV2 o JOIN FETCH o.items WHERE o.customerId = :customerId")
    List<OrderV2> findByCustomerIdWithItemsJoinFetch(@Param("customerId") String customerId);

    // Solution B: @EntityGraph "” declarative JOIN FETCH
    @EntityGraph(attributePaths = {"items"})
    List<OrderV2> findByCustomerId(String customerId);

    // Solution D: DTO projection "” no entity loaded, no N+1 possible
    @Query("""
        SELECT new com.example.dto.OrderWithItemsDto(
            o.id, o.customerId, i.productId, i.quantity, i.unitPrice
        )
        FROM OrderV2 o JOIN o.items i
        WHERE o.customerId = :customerId
        ORDER BY o.id, i.productId
        """)
    List<OrderWithItemsDto> findOrderItemDtosByCustomer(@Param("customerId") String customerId);
}

@Service
public class OrderQueryService {

    private final OrderRepositoryV2 orderRepository;

    public OrderQueryService(OrderRepositoryV2 orderRepository) {
        this.orderRepository = orderRepository;
    }

    // Solution A "” JOIN FETCH
    @Transactional(readOnly = true)
    public List<OrderV2> getOrdersWithItemsJoinFetch(String customerId) {
        // Generates: SELECT DISTINCT o.*, i.* FROM orders o JOIN order_items i ON ...
        return orderRepository.findByCustomerIdWithItemsJoinFetch(customerId);
    }

    // Solution B "” @EntityGraph
    @Transactional(readOnly = true)
    public List<OrderV2> getOrdersWithItemsEntityGraph(String customerId) {
        // @EntityGraph generates LEFT OUTER JOIN "” includes orders with no items
        return orderRepository.findByCustomerId(customerId);
    }

    // Solution C "” Batch fetching (configure globally in application.properties)
    // spring.jpa.properties.hibernate.default_batch_fetch_size=50
    // Hibernate changes: SELECT * FROM order_items WHERE order_id IN (1,2,...,50)
    // instead of 50 individual queries
    @Transactional(readOnly = true)
    public List<OrderV2> getOrdersWithBatchFetch(String customerId) {
        List<OrderV2> orders = orderRepository.findByCustomerId(customerId);
        // Accessing items here triggers batch load due to @BatchSize(50) or global setting
        orders.forEach(o -> o.getItems().size());
        return orders;
    }

    // Solution D "” DTO projection (best for read-heavy APIs)
    @Transactional(readOnly = true)
    public List<OrderWithItemsDto> getOrderItemDtos(String customerId) {
        return orderRepository.findOrderItemDtosByCustomer(customerId);
    }
}
```

**application.properties for Solution C:**
```properties
spring.jpa.properties.hibernate.default_batch_fetch_size=50
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
spring.jpa.properties.hibernate.generate_statistics=true
```

**Follow-up Questions:**
1. How do you detect N+1 in production without `show-sql`?
2. What is the cartesian product problem with JOIN FETCH on multiple collections?
3. When would you choose batch fetching over JOIN FETCH?
4. What is the difference between `@EntityGraph` (type=FETCH) and (type=LOAD)?

**Common Mistakes:**
- Using `FetchType.EAGER` to "fix" N+1 "” just makes N+1 happen at load time instead of access time
- JOIN FETCHing two collections simultaneously "” cartesian product
- Not adding `DISTINCT` to JOIN FETCH queries "” duplicate parent entities in results

**Interview Trap:**
"Setting all associations to EAGER solves N+1" "” EAGER causes N+1 to happen immediately at load time and loads data you may not need on every query. The problem is not eliminated; it is just made invisible. JOIN FETCH is explicit and query-specific.

**Quick Revision:**
- N+1 = 1 query for N parents + N queries for children = N+1 total
- Detection: `show-sql`, p6spy, Hibernate statistics
- Fix A: `JOIN FETCH` in JPQL | Fix B: `@EntityGraph` | Fix C: `batch_fetch_size` | Fix D: DTO projection
- JOIN FETCH + multiple collections = cartesian product "” avoid
- DTO projection = best for read-only APIs, zero N+1 risk

---

## Q9: JPQL vs Native Queries vs Criteria API

**Difficulty:** Medium | **Interview Frequency:** High
**Companies:** Oracle, SAP, IBM, Thoughtworks, Persistent Systems, Mphasis

**Short Answer (30-60 seconds):**
JPQL uses entity class and field names (not table/column names), is portable across databases, and is checked by Hibernate at startup. Native queries use raw SQL "” useful for DB-specific features like window functions, JSONB queries, or stored procedures. Criteria API is type-safe and programmatic, best for dynamic queries where conditions are built at runtime. Named queries (`@NamedQuery`) are compiled at startup, catching syntax errors early.

**Deep Explanation:**

**JPQL:**
- Operates on the entity model, not the database schema
- `FROM Order o` not `FROM orders o` (entity class name)
- `o.customerId` not `o.customer_id` (field name)
- Database-agnostic "” works with any JPA-compatible DB
- Validated at `EntityManagerFactory` creation time (startup)

**Native Queries:**
- Use actual table and column names
- Access DB-specific features: window functions (`ROW_NUMBER() OVER`), CTEs, `JSONB`, full-text search
- Bypass JPA's entity model "” no automatic dirty checking on results
- Can return entities (mapped via `@SqlResultSetMapping`) or scalars

**Criteria API:**
- Fully programmatic query construction in Java
- Type-safe via metamodel (`Order_.customerId`)
- Verbose but refactoring-safe "” a renamed field breaks compilation, not runtime
- Best for complex dynamic filtering (e.g., search APIs with optional parameters)

**Named Queries:**
- `@NamedQuery` and `@NamedNativeQuery` on entity class
- Compiled and validated at startup "” syntax errors caught before deployment
- Cached by Hibernate for reuse

**Real-World Example:**
An order search API has 10 optional filters (customer, date range, status, amount range, etc.). Using JPQL string concatenation is messy and error-prone. Criteria API builds the predicate list dynamically based on which filters are provided.

**Java Code Example:**
```java
import jakarta.persistence.*;
import jakarta.persistence.criteria.*;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

// Named queries on entity (validated at startup)
@NamedQuery(
    name = "Order.findByCustomerAndStatus",
    query = "SELECT o FROM Order o WHERE o.customerId = :customerId AND o.status = :status"
)
@NamedNativeQuery(
    name = "Order.findTopSpendersByNative",
    query = """
        SELECT customer_id, SUM(total_amount) as total_spent
        FROM orders
        WHERE created_at >= :since
        GROUP BY customer_id
        ORDER BY total_spent DESC
        LIMIT :limit
        """,
    resultSetMapping = "CustomerSpendMapping"
)
@SqlResultSetMapping(
    name = "CustomerSpendMapping",
    classes = @ConstructorResult(
        targetClass = CustomerSpendDto.class,
        columns = {
            @ColumnResult(name = "customer_id", type = String.class),
            @ColumnResult(name = "total_spent", type = BigDecimal.class)
        }
    )
)
@Entity
@Table(name = "orders")
class OrderForQuery {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "orderq_seq")
    @SequenceGenerator(name = "orderq_seq", sequenceName = "order_id_seq", allocationSize = 50)
    private Long id;

    @Column(name = "customer_id")
    private String customerId;

    @Column(name = "status")
    private String status;

    @Column(name = "total_amount", precision = 19, scale = 4)
    private BigDecimal totalAmount;

    @Column(name = "created_at")
    private Instant createdAt;

    public Long getId() { return id; }
    public String getCustomerId() { return customerId; }
    public void setCustomerId(String c) { this.customerId = c; }
    public String getStatus() { return status; }
    public void setStatus(String s) { this.status = s; }
    public BigDecimal getTotalAmount() { return totalAmount; }
    public void setTotalAmount(BigDecimal a) { this.totalAmount = a; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant t) { this.createdAt = t; }
}

record CustomerSpendDto(String customerId, BigDecimal totalSpent) {}

// Repository with JPQL and native
interface OrderQueryRepository extends JpaRepository<OrderForQuery, Long>,
        JpaSpecificationExecutor<OrderForQuery> {

    // JPQL "” entity/field names, DB portable
    @Query("SELECT o FROM OrderForQuery o WHERE o.customerId = :customerId AND o.status = :status")
    List<OrderForQuery> findByCustomerAndStatus(
        @Param("customerId") String customerId,
        @Param("status") String status
    );

    // Native "” table/column names, DB-specific syntax
    @Query(
        value = "SELECT * FROM orders WHERE customer_id = :customerId ORDER BY created_at DESC LIMIT :limit",
        nativeQuery = true
    )
    List<OrderForQuery> findRecentOrdersNative(
        @Param("customerId") String customerId,
        @Param("limit") int limit
    );
}

// Dynamic query using Criteria API + Specification
@Service
public class OrderSearchService {

    private final OrderQueryRepository repo;

    public OrderSearchService(OrderQueryRepository repo) {
        this.repo = repo;
    }

    @Transactional(readOnly = true)
    public List<OrderForQuery> searchOrders(
            String customerId,
            String status,
            BigDecimal minAmount,
            BigDecimal maxAmount,
            Instant from,
            Instant to) {

        // Criteria API "” build predicates dynamically
        return repo.findAll((Root<OrderForQuery> root, CriteriaQuery<?> query, CriteriaBuilder cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            if (customerId != null && !customerId.isBlank()) {
                predicates.add(cb.equal(root.get("customerId"), customerId));
            }
            if (status != null && !status.isBlank()) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            if (minAmount != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("totalAmount"), minAmount));
            }
            if (maxAmount != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("totalAmount"), maxAmount));
            }
            if (from != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("createdAt"), from));
            }
            if (to != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("createdAt"), to));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        });
    }
}
```

**Follow-up Questions:**
1. When would you use native queries over JPQL?
2. What are the drawbacks of native queries?
3. How do you make Criteria API type-safe using the JPA metamodel?

**Common Mistakes:**
- Using native queries when JPQL suffices "” harder to maintain, DB-specific
- Mixing entity field names and DB column names in JPQL
- Building dynamic JPQL by string concatenation "” use Criteria API or Specifications instead

**Interview Trap:**
"Criteria API is just the programmatic way to write JPQL" "” Criteria API generates JPQL internally, but its value is type-safety and composability. With JPA metamodel, a renamed field is a compile error, not a runtime error.

**Quick Revision:**
- JPQL = entity/field names, DB portable, startup validation
- Native = table/column names, DB-specific, use for window functions/JSONB/CTEs
- Criteria API = programmatic, type-safe, best for dynamic queries
- `@NamedQuery` = validated at startup, cached

---

## Q10: Spring Data JPA Repository Hierarchy

**Difficulty:** Medium | **Interview Frequency:** Very High
**Companies:** Amazon, Flipkart, TCS, Infosys, Wipro, Accenture, HCL, Cognizant

**Short Answer (30-60 seconds):**
Spring Data JPA provides a hierarchy: `Repository` (marker) â†’ `CrudRepository` (basic CRUD) â†’ `PagingAndSortingRepository` (pagination/sorting) â†’ `JpaRepository` (JPA-specific, batch operations, flush). Derived query methods generate JPQL from method names. `@Query` supports JPQL and native SQL. `@Modifying` + `@Transactional` are required for UPDATE/DELETE statements.

**Deep Explanation:**

**Repository Hierarchy:**
```
Repository<T, ID>                          // marker interface
  â””â”€â”€ CrudRepository<T, ID>               // save, findById, findAll, delete, count
        â””â”€â”€ PagingAndSortingRepository     // findAll(Pageable), findAll(Sort)
              â””â”€â”€ JpaRepository<T, ID>     // saveAll, flush, saveAndFlush, deleteAllInBatch
```

**Derived Query Methods:**
Spring Data parses the method name and generates JPQL:
- `findByStatus` â†’ `WHERE o.status = ?1`
- `findByCustomerIdAndStatus` â†’ `WHERE o.customerId = ?1 AND o.status = ?2`
- `findByTotalAmountGreaterThan` â†’ `WHERE o.totalAmount > ?1`
- `findByCreatedAtBetween` â†’ `WHERE o.createdAt BETWEEN ?1 AND ?2`
- `findTop10ByStatusOrderByCreatedAtDesc` â†’ top 10 rows with ORDER BY
- `countByStatus` â†’ `SELECT COUNT(*) WHERE status = ?1`
- `existsByOrderReference` â†’ `SELECT CASE WHEN COUNT(*)>0...`

**@Modifying + @Transactional:**
Required for JPQL UPDATE/DELETE. Without `@Modifying`, Spring Data throws an exception. Without `@Transactional`, the operation has no transaction context. By default, `@Modifying` clears the persistence context after the operation (`clearAutomatically=true` in Spring Data 2.x/3.x).

**Real-World Example:**
A payment reconciliation job updates all `PENDING` payments older than 24 hours to `TIMEOUT` status. A bulk JPQL UPDATE is far more efficient than loading all entities and updating one by one.

**Java Code Example:**
```java
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface PaymentRepository extends JpaRepository<Payment, Long> {

    // --- Derived query methods ---
    List<Payment> findByStatus(String status);

    Optional<Payment> findByOrderId(Long orderId);

    // COUNT query
    long countByStatus(String status);

    // EXISTS check
    boolean existsByOrderId(Long orderId);

    // Top N with sorting
    List<Payment> findTop10ByStatusOrderByCreatedAtDesc(String status);

    // Range query
    List<Payment> findByCreatedAtBetween(Instant from, Instant to);

    // Amount comparison
    List<Payment> findByAmountGreaterThanEqual(BigDecimal minAmount);

    // --- @Query with JPQL ---
    @Query("SELECT p FROM Payment p WHERE p.status = :status AND p.createdAt < :cutoff")
    List<Payment> findStalePayments(
        @Param("status") String status,
        @Param("cutoff") Instant cutoff
    );

    // --- @Query with native SQL ---
    @Query(
        value = """
            SELECT DATE_TRUNC('day', created_at) AS day,
                   COUNT(*) AS count,
                   SUM(amount) AS total
            FROM payments
            WHERE status = 'COMPLETED'
            GROUP BY DATE_TRUNC('day', created_at)
            ORDER BY day DESC
            LIMIT 30
            """,
        nativeQuery = true
    )
    List<Object[]> findDailyPaymentStats();

    // --- @Modifying + @Transactional for bulk UPDATE ---
    @Modifying
    @Transactional
    @Query("UPDATE Payment p SET p.status = 'TIMEOUT' WHERE p.status = 'PENDING' AND p.createdAt < :cutoff")
    int timeoutStalePayments(@Param("cutoff") Instant cutoff);

    // --- @Modifying for bulk DELETE ---
    @Modifying
    @Transactional
    @Query("DELETE FROM Payment p WHERE p.status = 'FAILED' AND p.createdAt < :before")
    int deleteOldFailedPayments(@Param("before") Instant before);
}

@Service
public class PaymentReconciliationService {

    private final PaymentRepository paymentRepository;

    public PaymentReconciliationService(PaymentRepository paymentRepository) {
        this.paymentRepository = paymentRepository;
    }

    @Transactional
    public void reconcileStalePayments() {
        Instant cutoff = Instant.now().minusSeconds(86_400); // 24 hours ago
        int updated = paymentRepository.timeoutStalePayments(cutoff);
        System.out.println("Timed out " + updated + " stale payments");
    }

    @Transactional
    public void purgeOldFailedPayments(int daysOld) {
        Instant before = Instant.now().minusSeconds((long) daysOld * 86_400);
        int deleted = paymentRepository.deleteOldFailedPayments(before);
        System.out.println("Deleted " + deleted + " old failed payments");
    }
}
```

**Follow-up Questions:**
1. What is the difference between `JpaRepository.deleteAll()` and `deleteAllInBatch()`?
2. What does `@Modifying(clearAutomatically = true)` do and why is it the default?
3. Can you have a `@Transactional` annotation on the repository interface itself?

**Common Mistakes:**
- Forgetting `@Transactional` on `@Modifying` queries "” `InvalidDataAccessApiUsageException`
- Forgetting `@Modifying` on UPDATE/DELETE `@Query` "” Spring Data throws exception
- Using `deleteAll()` instead of `deleteAllInBatch()` for large datasets "” `deleteAll()` loads entities first

**Interview Trap:**
"`JpaRepository` extends `CrudRepository` directly" "” Wrong. The hierarchy is `CrudRepository` â†’ `PagingAndSortingRepository` â†’ `JpaRepository`. Knowing the intermediate level (`PagingAndSortingRepository`) shows depth.

**Quick Revision:**
- `CrudRepository` â†’ `PagingAndSortingRepository` â†’ `JpaRepository`
- Derived methods: `findByXxxAndYyy`, `countByXxx`, `existsByXxx`, `findTop10ByXxx`
- `@Query` for JPQL or native
- `@Modifying` + `@Transactional` required for UPDATE/DELETE

---

## Q11: Projections

**Difficulty:** Medium | **Interview Frequency:** High
**Companies:** Thoughtworks, Razorpay, Atlassian, Zomato, Swiggy

**Short Answer (30-60 seconds):**
JPA projections let you fetch a subset of data instead of full entities. Three types: **interface projection** (Spring Data generates a proxy), **DTO projection** (constructor expression in JPQL), and **`@Value` projection** (SpEL expressions on interface). For read-only APIs, DTO projection is best: it avoids dirty checking overhead, loads fewer columns, and prevents accidental entity modification. Interface projections are convenient but generate proxies with reflection overhead.

**Deep Explanation:**

**Interface Projection:**
Declare an interface with getters matching entity fields. Spring Data generates a proxy that wraps the result. Supports nested projections (related entities). Spring resolves field names from getter names.

**DTO Projection (Constructor Expression):**
JPQL `new com.example.Dto(field1, field2)` "” creates actual DTO instances. No proxy, no entity, no dirty checking. The class must have a matching constructor. Works with `record` types.

**`@Value` Projection:**
Interface projection with SpEL: `@Value("#{target.firstName + ' ' + target.lastName}")`. Lets you compute derived fields. BUT: loads the full entity into `target`, defeating the purpose of projection.

**When to Use DTO Projection:**
- Read-only APIs (no need to track changes)
- Aggregations and computed fields
- Avoiding lazy loading issues
- High-throughput endpoints where entity overhead matters
- Returning data that spans multiple entities

**Real-World Example:**
An order list API returns thousands of orders. Loading full entities with all associations wastes memory and fires unnecessary queries. A DTO projection with just `id`, `status`, `totalAmount`, `createdAt` is 90% smaller and has no dirty checking overhead.

**Java Code Example:**
```java
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

// --- Interface Projection ---
public interface OrderSummaryProjection {
    Long getId();
    String getCustomerId();
    String getStatus();
    BigDecimal getTotalAmount();
    Instant getCreatedAt();
    // Nested projection "” resolves to ShippingAddress fields
    AddressProjection getShippingAddress();

    interface AddressProjection {
        String getCity();
        String getPostalCode();
    }
}

// --- @Value Projection (SpEL) ---
public interface OrderLabelProjection {
    Long getId();

    // SpEL expression "” computes derived field; BUT loads full entity
    @Value("#{target.customerId + '-' + target.id}")
    String getOrderLabel();
}

// --- DTO Projection (Constructor Expression) "” preferred for read-only APIs ---
public record OrderListItemDto(
    Long id,
    String customerId,
    String status,
    BigDecimal totalAmount,
    Instant createdAt
) {}

// --- Aggregation DTO ---
public record CustomerOrderStatsDto(
    String customerId,
    long orderCount,
    BigDecimal totalSpent,
    BigDecimal averageOrderValue
) {}

public interface ProjectionOrderRepository extends JpaRepository<Order, Long> {

    // Interface projection "” Spring generates proxy
    List<OrderSummaryProjection> findByCustomerId(String customerId);

    // DTO projection via constructor expression "” no entity, no proxy
    @Query("""
        SELECT new com.example.dto.OrderListItemDto(
            o.id, o.customerId, o.status, o.totalAmount, o.createdAt
        )
        FROM Order o
        WHERE o.customerId = :customerId
        ORDER BY o.createdAt DESC
        """)
    List<OrderListItemDto> findOrderDtosByCustomer(@Param("customerId") String customerId);

    // Aggregation DTO projection
    @Query("""
        SELECT new com.example.dto.CustomerOrderStatsDto(
            o.customerId,
            COUNT(o),
            SUM(o.totalAmount),
            AVG(o.totalAmount)
        )
        FROM Order o
        WHERE o.createdAt >= :since
        GROUP BY o.customerId
        ORDER BY SUM(o.totalAmount) DESC
        """)
    List<CustomerOrderStatsDto> findCustomerOrderStats(@Param("since") Instant since);

    // Dynamic projection "” Spring Data selects projection type at runtime
    <T> List<T> findByStatus(String status, Class<T> type);
}
```

**Using Dynamic Projection:**
```java
// In service:
List<OrderSummaryProjection> summaries = repo.findByStatus("PENDING", OrderSummaryProjection.class);
List<OrderListItemDto> dtos = repo.findByStatus("PENDING", OrderListItemDto.class);
```

**Follow-up Questions:**
1. What is the performance difference between interface projection and DTO projection?
2. When does `@Value` projection actually load the full entity?
3. Can you use projections with `Pageable`?

**Common Mistakes:**
- Using `@Value` projection expecting it to load fewer columns "” it loads the full entity
- Not providing a constructor matching the `new` expression in JPQL "” `QueryException` at startup
- Forgetting that interface projections return proxies "” they do not work with `instanceof` checks

**Interview Trap:**
"Interface projections fetch fewer columns" "” Sometimes. Spring Data may optimize to fetch only the projected columns (for flat projections), but this is not guaranteed. For predictable column reduction, use DTO projection with an explicit constructor expression.

**Quick Revision:**
- Interface projection = proxy, Spring-generated, supports nested
- DTO projection = `new Dto(fields)` in JPQL, best for read-only APIs
- `@Value` projection = SpEL on interface, loads full entity (avoid for performance)
- Dynamic projection: `<T> List<T> findByX(val, Class<T> type)`

---

## Q12: Pagination and Sorting

**Difficulty:** Easy | **Interview Frequency:** High
**Companies:** Flipkart, Amazon, Swiggy, Zomato, Paytm, Ola

**Short Answer (30-60 seconds):**
Spring Data JPA pagination uses `Pageable` (interface) and `PageRequest` (implementation). `Page<T>` fires a count query in addition to the data query "” use for paginated UIs showing total pages. `Slice<T>` skips the count query "” use for infinite scroll or mobile feeds. For very large datasets, keyset pagination (cursor-based) outperforms offset pagination because it does not degrade with deep pages.

**Deep Explanation:**

**`Page<T>` vs `Slice<T>`:**

| Feature | `Page<T>` | `Slice<T>` |
|---|---|---|
| Count query | Yes (extra `COUNT(*)` query) | No |
| Total pages/elements | Yes | No |
| Use case | Paginated UI (page numbers) | Infinite scroll, mobile |
| Performance on deep pages | Worse (count + offset) | Better (no count) |

**Offset Pagination Problem:**
`OFFSET 10000 LIMIT 20` causes the DB to scan and discard 10,000 rows. The deeper the page, the slower the query "” even with an index. For large datasets, this is a serious performance problem.

**Keyset Pagination (Cursor-based):**
Instead of `OFFSET`, use a WHERE clause on the last seen value:
```sql
SELECT * FROM orders WHERE created_at < :lastSeen ORDER BY created_at DESC LIMIT 20;
```
This uses an index efficiently regardless of page depth. The "cursor" is the `created_at` (and `id` for tie-breaking) of the last item seen.

**Sorting:**
`Sort.by(Sort.Direction.DESC, "createdAt")` or `Sort.by("createdAt").descending()`.
`PageRequest.of(page, size, sort)` combines pagination and sorting.

**Real-World Example:**
A product search page uses `Page<T>` with page numbers at the bottom. A social feed (notifications, order history) uses `Slice<T>` "” "Load more" button, no total count needed. A reporting export over 10M rows uses keyset pagination to avoid memory issues.

**Java Code Example:**
```java
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.util.List;

public interface PaginatedOrderRepository extends JpaRepository<Order, Long> {

    // Page<T> "” fires data query + count query
    Page<Order> findByCustomerId(String customerId, Pageable pageable);

    // Slice<T> "” fires only data query (no count)
    Slice<Order> findByStatus(String status, Pageable pageable);

    // Custom JPQL with Pageable
    @Query("SELECT o FROM Order o WHERE o.customerId = :customerId AND o.status = :status")
    Page<Order> findByCustomerAndStatus(
        @Param("customerId") String customerId,
        @Param("status") String status,
        Pageable pageable
    );

    // Keyset pagination "” cursor on (createdAt, id) for stable ordering
    @Query("""
        SELECT o FROM Order o
        WHERE o.customerId = :customerId
          AND (o.createdAt < :lastCreatedAt
               OR (o.createdAt = :lastCreatedAt AND o.id < :lastId))
        ORDER BY o.createdAt DESC, o.id DESC
        """)
    List<Order> findNextPage(
        @Param("customerId") String customerId,
        @Param("lastCreatedAt") Instant lastCreatedAt,
        @Param("lastId") Long lastId,
        Pageable pageable
    );

    // Count query "” separate for complex queries where Spring cannot auto-derive it
    @Query(
        value = "SELECT o FROM Order o WHERE o.customerId = :customerId AND o.status = :status",
        countQuery = "SELECT COUNT(o) FROM Order o WHERE o.customerId = :customerId AND o.status = :status"
    )
    Page<Order> findWithExplicitCountQuery(
        @Param("customerId") String customerId,
        @Param("status") String status,
        Pageable pageable
    );
}

@Service
public class OrderPaginationService {

    private final PaginatedOrderRepository repo;

    public OrderPaginationService(PaginatedOrderRepository repo) {
        this.repo = repo;
    }

    // Offset pagination with Page<T>
    @Transactional(readOnly = true)
    public Page<Order> getOrdersPage(String customerId, int page, int size) {
        Pageable pageable = PageRequest.of(
            page, size,
            Sort.by(Sort.Direction.DESC, "createdAt")
        );
        Page<Order> result = repo.findByCustomerId(customerId, pageable);
        System.out.println("Total pages: " + result.getTotalPages());
        System.out.println("Total elements: " + result.getTotalElements());
        System.out.println("Current page: " + result.getNumber());
        System.out.println("Is last page: " + result.isLast());
        return result;
    }

    // Infinite scroll with Slice<T> "” no count query
    @Transactional(readOnly = true)
    public Slice<Order> getOrdersFeed(String status, int page, int size) {
        Pageable pageable = PageRequest.of(
            page, size,
            Sort.by(Sort.Direction.DESC, "createdAt")
        );
        Slice<Order> slice = repo.findByStatus(status, pageable);
        System.out.println("Has next: " + slice.hasNext()); // for "Load More" button
        return slice;
    }

    // Keyset pagination "” efficient for deep pages
    @Transactional(readOnly = true)
    public List<Order> getNextOrderPage(
            String customerId,
            Instant lastCreatedAt,
            Long lastId,
            int size) {
        // No OFFSET "” uses WHERE clause on index columns
        return repo.findNextPage(
            customerId,
            lastCreatedAt,
            lastId,
            PageRequest.of(0, size) // always page 0 "” keyset handles the cursor
        );
    }
}
```

**Follow-up Questions:**
1. Why does `Page<T>` fire two queries and can you disable the count query?
2. What is the risk of using offset pagination on a table with frequent inserts?
3. What columns should you index for keyset pagination?

**Common Mistakes:**
- Using `Page<T>` for infinite scroll "” count query on every swipe is wasteful
- Not providing a `countQuery` in `@Query` when the main query has complex JOINs "” Spring may generate an incorrect count query
- Keyset pagination without a composite index on `(customerId, createdAt, id)` "” query degrades to full scan

**Interview Trap:**
"`Slice<T>` is always better than `Page<T>`" "” Wrong. `Slice<T>` cannot tell you the total number of pages or elements. For paginated UIs where users need to jump to page N or see "Showing 1-20 of 5,432 results", `Page<T>` is required.

**Quick Revision:**
- `Page<T>` = data query + count query = use for numbered page UIs
- `Slice<T>` = data query only = use for infinite scroll
- `PageRequest.of(page, size, sort)` constructs `Pageable`
- Keyset pagination = cursor-based, no OFFSET degradation, best for large datasets

---

--- END OF PART A ---


---

# Chapter 8 "” Spring Data JPA & Hibernate (Part B)

---

## Q13: First-Level Cache (Persistence Context Cache)

**Difficulty:** Easy | **Interview Frequency:** High
**Companies:** Infosys, Wipro, TCS, Capgemini, mid-size product companies

**Short Answer (30-60 seconds):**
The first-level cache is the persistence context itself "” Hibernate's `EntityManager` (or `Session`). It is automatic, always enabled, and scoped to a single transaction. When you call `find()` twice for the same entity ID within the same transaction, only one SQL query hits the database. The second call returns the cached instance from memory. You cannot disable it; you can only clear it.

**Deep Explanation:**
Every `EntityManager` maintains an identity map keyed by `(EntityClass, primaryKey)`. When Hibernate loads an entity, it stores a copy (snapshot) and the live instance in this map. Subsequent lookups by the same PK within the same `EntityManager` bypass the database entirely.

Key behaviors:
- `entityManager.find(User.class, 1L)` called twice â†’ one `SELECT`, one cache hit
- `entityManager.clear()` "” evicts everything; next access re-queries
- `entityManager.evict(user)` "” evicts a single entity (Hibernate `Session` API)
- JPQL queries (`createQuery(...)`) always hit the DB and then merge results into the cache
- The cache is destroyed when the `EntityManager` closes (end of transaction by default)

The snapshot stored at load time is used by dirty checking at flush time to detect changes.

**Real-World Example:**
An order processing service loads `Order` twice in one transaction "” once to validate stock, once to apply discount. Without the L1 cache this would be two identical `SELECT` statements. With it, the second call is free.

**Java Code Example:**
```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final EntityManager em;

    @Transactional
    public void processOrder(Long orderId) {
        // First call "” hits DB, result cached in persistence context
        Order order = em.find(Order.class, orderId);
        validateStock(order);

        // Second call "” SAME EntityManager, same transaction â†’ cache hit, no SQL
        Order sameOrder = em.find(Order.class, orderId);
        applyDiscount(sameOrder);

        // sameOrder == order: identical Java object reference
        assert order == sameOrder; // true

        // Clearing the persistence context forces next find() to re-query
        em.clear();
        Order freshOrder = em.find(Order.class, orderId); // hits DB again
    }

    private void validateStock(Order o) { /* ... */ }
    private void applyDiscount(Order o) { /* ... */ }
}
```

**Follow-up Questions:**
- What happens if you call a JPQL query for the same entity "” does the L1 cache get used?
- Does `@Transactional(readOnly=true)` affect the L1 cache?
- What is the relationship between the L1 cache and dirty checking?

**Common Mistakes:**
- Confusing L1 (per-EntityManager) with L2 (shared across EntityManagers)
- Thinking `@Transactional(readOnly=true)` disables the L1 cache "” it does not
- Assuming JPQL queries use the L1 cache for lookup (they do not; they query and then merge)

**Interview Trap:**
"Can you disable the first-level cache?" "” No. It is a fundamental Hibernate design. The only option is `clear()` or `evict()`, which removes entries rather than disabling the mechanism.

**Quick Revision:**
L1 cache = persistence context identity map. Automatic, per-transaction, cannot be disabled. `find()` twice = 1 DB hit. `clear()` evicts all. JPQL bypasses it on lookup but merges results into it afterward.

---

## Q14: Second-Level Cache (L2)

**Difficulty:** Medium | **Interview Frequency:** High
**Companies:** Amazon, Flipkart, Razorpay, Thoughtworks, Oracle

**Short Answer (30-60 seconds):**
The second-level cache (L2) is an optional, session-factory-scoped cache shared across all `EntityManager` instances. It must be explicitly enabled and configured with a provider such as EHCache, Caffeine, or Redis. Entities annotated with `@Cache` are stored there after first load, so subsequent requests in different transactions avoid a DB round trip.

**Deep Explanation:**
**Configuration:**
```properties
spring.jpa.properties.hibernate.cache.use_second_level_cache=true
spring.jpa.properties.hibernate.cache.region.factory_class=\
  org.hibernate.cache.jcache.JCacheCacheProvider
spring.jpa.properties.javax.cache.provider=\
  org.ehcache.jsr107.EhcacheCachingProvider
```

**Cache strategies:**
- `READ_ONLY` "” immutable entities (reference data). Fastest.
- `NONSTRICT_READ_WRITE` "” rarely updated; brief inconsistency window acceptable.
- `READ_WRITE` "” transactional consistency with soft locks.
- `TRANSACTIONAL` "” JTA environments only; full transactional guarantees.

**When NOT to use L2:**
- Frequently updated entities (shopping cart, live inventory count) "” cache churns, overhead exceeds benefit
- Entities read uniquely per user "” poor hit rate
- Highly clustered environments without distributed cache provider "” stale data across nodes

**Difference from Spring `@Cacheable`:** (detailed in Q15)

**Real-World Example:**
A product catalog service: `Category` and `Country` entities are loaded thousands of times per minute but rarely change. L2 cache with `READ_ONLY` strategy cuts DB reads by 95%.

**Java Code Example:**
```java
// pom.xml dependency: spring-boot-starter-cache + hibernate-jcache + ehcache
@Entity
@Table(name = "categories")
@Cache(usage = CacheConcurrencyStrategy.READ_ONLY, region = "categories")
public class Category {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    private String name;
    private String code;

    // getters/setters
}
```

```java
// application.yml
spring:
  jpa:
    properties:
      hibernate:
        cache:
          use_second_level_cache: true
          use_query_cache: true
          region:
            factory_class: org.hibernate.cache.jcache.JCacheCacheProvider
        javax:
          cache:
            provider: org.ehcache.jsr107.EhcacheCachingProvider
```

```java
@Service
@RequiredArgsConstructor
public class CategoryService {

    private final CategoryRepository repo;

    // First call: SELECT from DB, stored in L2 cache
    // Subsequent calls (different transactions): served from cache
    public Category getById(Long id) {
        return repo.findById(id).orElseThrow();
    }

    // Evict L2 cache entry on update
    @CacheEvict(cacheNames = "categories", key = "#category.id")
    @Transactional
    public Category update(Category category) {
        return repo.save(category);
    }
}
```

**Follow-up Questions:**
- How does L2 cache invalidation work in a clustered deployment?
- What is query cache and what are its pitfalls?
- How does Hibernate's `READ_WRITE` strategy prevent dirty reads during updates?

**Common Mistakes:**
- Enabling L2 on mutable, high-write entities "” degrades performance
- Not configuring a distributed cache in multi-node deployments "” stale reads
- Forgetting `@Cache` annotation "” the config alone does nothing

**Interview Trap:**
"Does enabling L2 cache mean you never hit the database?" "” No. L2 cache is bypassed for JPQL queries unless query cache is also enabled. Writes always go to the DB; the cache is then invalidated/updated.

**Quick Revision:**
L2 = session-factory-scoped, opt-in, shared cache. Annotate entities with `@Cache`. Enable via properties. Avoid for frequently updated data. Requires distributed provider (Redis/EHCache) in clustered apps.

---

## Q15: Spring `@Cacheable` vs Hibernate L2 Cache

**Difficulty:** Medium | **Interview Frequency:** Medium
**Companies:** Thoughtworks, Atlassian, Zomato, mid-size SaaS companies

**Short Answer (30-60 seconds):**
`@Cacheable` caches the return value of any Spring-managed method at the service layer "” it is provider-agnostic and can cache anything. Hibernate L2 caches entity state at the persistence layer. They operate at different architectural layers and can coexist. Use L2 for entity-centric access patterns; use `@Cacheable` for computed results, DTOs, or non-entity data.

**Deep Explanation:**

| Dimension | Spring `@Cacheable` | Hibernate L2 Cache |
|---|---|---|
| Layer | Service / application layer | Persistence layer (inside Hibernate) |
| What is cached | Method return value (any type) | Entity state (raw field values) |
| Granularity | Method call + arguments | Entity by primary key |
| Provider | Redis, Caffeine, EHCache, etc. | EHCache, Caffeine, Redis (via JCache) |
| Invalidation | Manual (`@CacheEvict`) or TTL | Automatic on entity write within Hibernate |
| Scope | Any Spring bean | JPA entities only |
| Transactions | Unaware of JPA transactions | Coordinated with Hibernate flush/commit |

**When to use `@Cacheable`:**
- Caching aggregated results (top products, dashboard metrics)
- Caching DTOs or projections not tied to a single entity
- Caching external API responses
- When you need explicit control over cache key, TTL, and eviction

**When to use Hibernate L2:**
- Entity-by-ID access patterns are dominant
- Reference data (countries, categories, currencies) loaded repeatedly
- You want zero application code change "” just annotate the entity

**Real-World Example:**
An e-commerce app uses L2 for `ProductCategory` (pure reference data, loaded by ID). It uses `@Cacheable` on `ProductSearchService.search(filters)` because that result depends on complex query logic and is not a single entity.

**Java Code Example:**
```java
// Hibernate L2 "” entity-layer caching
@Entity
@Cache(usage = CacheConcurrencyStrategy.READ_ONLY)
public class Currency {
    @Id private String code; // USD, EUR
    private String symbol;
}

// Spring @Cacheable "” service-layer caching of any return type
@Service
@RequiredArgsConstructor
public class DashboardService {

    private final OrderRepository orderRepo;

    // Caches the List<OrderSummaryDto> "” not a single entity
    @Cacheable(cacheNames = "dashboard-stats", key = "#userId")
    public List<OrderSummaryDto> getOrderStats(Long userId) {
        return orderRepo.findSummaryByUser(userId); // expensive aggregation
    }

    @CacheEvict(cacheNames = "dashboard-stats", key = "#userId")
    public void invalidateStats(Long userId) { /* called on order update */ }
}

record OrderSummaryDto(Long orderId, String status, BigDecimal amount) {}
```

**Follow-up Questions:**
- Can you use both `@Cacheable` and L2 on the same entity?
- How do you synchronize `@Cacheable` invalidation with database transactions?
- What is `@CachePut` and when is it preferred over `@Cacheable`?

**Common Mistakes:**
- Believing `@Cacheable` and L2 are mutually exclusive "” they are not
- Caching mutable entity collections with `@Cacheable` without eviction "” stale data
- Thinking `@Cacheable` is aware of Hibernate entity lifecycle events "” it is not

**Interview Trap:**
"If I annotate a repository method with `@Cacheable`, does that also populate the Hibernate L2 cache?" "” No. They are independent. `@Cacheable` on a repo method caches the Java object returned; Hibernate L2 is populated only through the Hibernate loading mechanism.

**Quick Revision:**
`@Cacheable` = service layer, any method, any return type, manual eviction. L2 = persistence layer, entity state by PK, auto-invalidated by Hibernate on write. Both can coexist. Use `@Cacheable` for computed/DTO results; L2 for entity-by-ID reference data.

---

## Q16: `@Transactional` Propagation "” All 7 Types

**Difficulty:** Hard | **Interview Frequency:** Very High
**Companies:** Amazon, Google, Goldman Sachs, Uber, Flipkart, PayPal

**Short Answer (30-60 seconds):**
Propagation controls what Hibernate does when a transactional method is called while a transaction may or may not already exist. `REQUIRED` (default) joins an existing one or creates a new one. `REQUIRES_NEW` always starts a fresh transaction, suspending the current one "” useful for audit logs that must persist even if the outer transaction rolls back.

**Deep Explanation:**

### REQUIRED (default)
- Existing tx: joins it. No existing tx: creates one.
- Most service methods use this.
- Rollback of inner method rolls back the entire outer transaction.

### REQUIRES_NEW
- Always creates a new transaction. Suspends the current one until the inner completes.
- Inner commits/rolls back independently.
- **Use case:** Audit logging "” even if the business operation rolls back, the audit record must be saved.

### NESTED
- Creates a savepoint within the current transaction (JDBC only "” not JTA/XA).
- Inner rollback goes back to savepoint; outer transaction continues.
- If no existing tx, behaves like `REQUIRED`.
- **Use case:** Partial rollback "” process 10 items, rollback failed ones, commit successful ones.

### SUPPORTS
- Existing tx: participates. No existing tx: runs without a transaction.
- **Use case:** Read operations that can work with or without a transaction (e.g., cache-backed reads).

### NOT_SUPPORTED
- Existing tx: suspends it, runs without transaction. No existing tx: runs without transaction.
- **Use case:** Long-running non-transactional operations (file I/O, external API calls) that should not hold a DB connection.

### MANDATORY
- Existing tx: joins it. No existing tx: throws `IllegalTransactionStateException`.
- **Use case:** Helper methods that must always be called within a transaction to enforce correctness contracts.

### NEVER
- Existing tx: throws `IllegalTransactionStateException`. No existing tx: runs fine.
- **Use case:** Operations that are explicitly prohibited from running inside a transaction (e.g., long streaming operations).

**Real-World Example:**
E-commerce checkout: `placeOrder()` runs in `REQUIRED`. Inside it, `sendAuditLog()` uses `REQUIRES_NEW` "” if payment fails and order rolls back, the audit log still records the attempt.

**Java Code Example:**
```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepo;
    private final AuditService auditService;
    private final InventoryService inventoryService;

    // REQUIRED (default) "” joins existing or creates new
    @Transactional
    public Order placeOrder(OrderRequest request) {
        Order order = orderRepo.save(new Order(request));

        try {
            inventoryService.reserve(request.items()); // MANDATORY example inside
        } catch (Exception e) {
            // audit log persists even though we're about to throw
            auditService.logFailure(order.getId(), e.getMessage()); // REQUIRES_NEW
            throw e; // outer tx rolls back, audit already committed
        }
        return order;
    }
}

@Service
@RequiredArgsConstructor
public class AuditService {

    private final AuditLogRepository auditRepo;

    // REQUIRES_NEW "” suspends outer tx, commits independently
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void logFailure(Long orderId, String reason) {
        auditRepo.save(new AuditLog(orderId, reason, Instant.now()));
        // commits here regardless of outer transaction outcome
    }
}

@Service
@RequiredArgsConstructor
public class InventoryService {

    // MANDATORY "” must be called within an existing transaction
    @Transactional(propagation = Propagation.MANDATORY)
    public void reserve(List<OrderItem> items) {
        // if called without a transaction, throws IllegalTransactionStateException
        items.forEach(item -> deductStock(item.productId(), item.quantity()));
    }

    private void deductStock(Long productId, int qty) { /* ... */ }
}

@Service
public class ReportingService {

    // NOT_SUPPORTED "” suspends any tx, runs without one (avoids holding connection)
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public byte[] generateLargeReport() {
        // long-running; should not hold DB connection/tx for its duration
        return new byte[0]; // placeholder
    }
}
```

**Follow-up Questions:**
- What is the difference between `NESTED` and `REQUIRES_NEW`?
- Does `REQUIRES_NEW` actually create a separate DB connection?
- Why does `NESTED` not work with JTA?

**Common Mistakes:**
- Calling a `REQUIRES_NEW` method on `this` (same class) "” proxy not invoked, propagation ignored
- Assuming `NESTED` is available with JTA "” it requires JDBC savepoints
- Using `REQUIRES_NEW` for all helper methods "” creates connection pool pressure

**Interview Trap:**
"`NESTED` and `REQUIRES_NEW` both create a new transaction "” what's the difference?" "” `REQUIRES_NEW` fully commits independently; a rollback of the inner does not affect the outer. `NESTED` creates a savepoint inside the same outer transaction; if the outer rolls back, the nested work is also lost.

**Quick Revision:**
7 propagation types: REQUIRED (join/create), REQUIRES_NEW (new tx, suspends outer), NESTED (savepoint, JDBC only), SUPPORTS (join or no-tx), NOT_SUPPORTED (no tx, suspends), MANDATORY (must have tx), NEVER (must not have tx). Most common in interviews: REQUIRED, REQUIRES_NEW, NESTED.

---

## Q17: Isolation Levels

**Difficulty:** Hard | **Interview Frequency:** Very High
**Companies:** Goldman Sachs, JP Morgan, PayPal, Stripe, Amazon, Google

**Short Answer (30-60 seconds):**
Isolation levels control which concurrency anomalies are allowed between simultaneous transactions. Higher isolation = fewer anomalies = more locking = lower throughput. The four levels are READ_UNCOMMITTED, READ_COMMITTED (default in most DBs), REPEATABLE_READ, and SERIALIZABLE. The choice is a direct trade-off between data correctness and system throughput.

**Deep Explanation:**

### Anomalies defined:
| Anomaly | Description |
|---|---|
| Dirty Read | Reading uncommitted data from another transaction |
| Non-repeatable Read | Same row returns different values in same transaction |
| Phantom Read | Same query returns different rows in same transaction |

### Isolation levels and what they prevent:

| Level | Dirty Read | Non-repeatable Read | Phantom Read | Notes |
|---|---|---|---|---|
| READ_UNCOMMITTED | Possible | Possible | Possible | Almost never used |
| READ_COMMITTED | Prevented | Possible | Possible | Default: PostgreSQL, Oracle, SQL Server |
| REPEATABLE_READ | Prevented | Prevented | Possible | Default: MySQL InnoDB |
| SERIALIZABLE | Prevented | Prevented | Prevented | Highest isolation, lowest concurrency |

### How they work under the hood:
- `READ_COMMITTED`: Read locks released immediately after read; write locks held until commit.
- `REPEATABLE_READ`: Read locks held until end of transaction.
- `SERIALIZABLE`: Range locks added; no new rows can appear in a scanned range.

**Real trade-off:** A financial system processing transfers between accounts may need `SERIALIZABLE` for balance calculations. A news feed can safely use `READ_COMMITTED` because stale reads are acceptable.

**Real-World Example:**
A bank account service reads balance, performs a check, then deducts. Under `READ_COMMITTED`, another transaction can change the balance between the read and the deduct "” the non-repeatable read anomaly. Setting `REPEATABLE_READ` prevents this by holding the read lock.

**Java Code Example:**
```java
@Service
public class BankTransferService {

    // READ_COMMITTED (default) "” acceptable for most reads
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public BigDecimal getBalance(Long accountId) {
        return accountRepository.findBalanceById(accountId);
    }

    // REPEATABLE_READ "” prevents non-repeatable read during transfer
    @Transactional(isolation = Isolation.REPEATABLE_READ)
    public void transfer(Long fromId, Long toId, BigDecimal amount) {
        Account from = accountRepository.findById(fromId).orElseThrow();
        Account to = accountRepository.findById(toId).orElseThrow();

        if (from.getBalance().compareTo(amount) < 0) {
            throw new InsufficientFundsException("Insufficient balance");
        }

        // Without REPEATABLE_READ, balance could change here before deduction
        from.setBalance(from.getBalance().subtract(amount));
        to.setBalance(to.getBalance().add(amount));
    }

    // SERIALIZABLE "” highest correctness for critical financial reconciliation
    @Transactional(isolation = Isolation.SERIALIZABLE)
    public void dailyReconciliation(Long accountId) {
        // No other transaction can insert/update matching rows
        List<Transaction> txns = transactionRepository.findAllByAccountId(accountId);
        BigDecimal sum = txns.stream()
            .map(Transaction::getAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        // assert sum matches stored balance...
    }
}
```

**Follow-up Questions:**
- How does PostgreSQL implement `REPEATABLE_READ` differently from MySQL?
- What is MVCC and how does it relate to isolation levels?
- Why is `SERIALIZABLE` often avoided in practice?

**Common Mistakes:**
- Assuming `SERIALIZABLE` uses only locking "” PostgreSQL uses SSI (Serializable Snapshot Isolation)
- Using high isolation levels globally "to be safe" "” causes deadlocks and throughput collapse
- Confusing isolation (concurrent transaction behavior) with atomicity (single transaction all-or-nothing)

**Interview Trap:**
"MySQL's default is `REPEATABLE_READ` "” does it prevent phantom reads?" "” MySQL InnoDB prevents phantom reads with gap locking even at `REPEATABLE_READ` level, which is beyond the SQL standard requirement. PostgreSQL at `REPEATABLE_READ` can still have phantom reads per the standard.

**Quick Revision:**
4 levels: READ_UNCOMMITTED (all anomalies possible) â†’ READ_COMMITTED (prevents dirty reads, default most DBs) â†’ REPEATABLE_READ (prevents non-repeatable reads) â†’ SERIALIZABLE (prevents all anomalies). Higher isolation = more locking = lower throughput.

---

## Q18: `@Transactional` Rollback Rules

**Difficulty:** Medium | **Interview Frequency:** High
**Companies:** Infosys, Cognizant, Wipro, Razorpay, Paytm

**Short Answer (30-60 seconds):**
By default, Spring rolls back a transaction only for unchecked exceptions (`RuntimeException` and `Error`). Checked exceptions do NOT trigger a rollback unless explicitly configured. The rationale is Spring's convention: checked exceptions represent recoverable business conditions; unchecked exceptions represent programming errors or unexpected failures.

**Deep Explanation:**
Spring's `@Transactional` uses a `RollbackRuleAttribute` list internally. The defaults are:
- Rollback on: `RuntimeException`, `Error`
- No rollback on: `Exception`, `Throwable`, checked exceptions

**Customization attributes:**
- `rollbackFor = IOException.class` "” add checked exception to rollback list
- `rollbackFor = {IOException.class, SQLException.class}` "” multiple
- `noRollbackFor = OptimisticLockException.class` "” exclude a runtime exception
- `rollbackForClassName = "com.example.MyException"` "” string-based (avoid; fragile)

**Why the default excludes checked exceptions:**
In EJB tradition (which Spring inherits), checked exceptions are "application exceptions" "” expected, recoverable. A `FileNotFoundException` thrown during an order import might mean "retry later," not "abort the transaction." Unchecked exceptions are "system exceptions" "” unexpected bugs, corrupted state.

**Important subtlety:** If a method catches the exception and does not rethrow, the transaction is NOT rolled back even for `RuntimeException`. Spring only sees the exception if it propagates out of the `@Transactional` proxy boundary.

**Real-World Example:**
A payment service throws a custom `PaymentGatewayException extends Exception` (checked) when the gateway is unreachable. Without `rollbackFor`, the transaction commits even though payment failed "” a critical bug. Solution: `rollbackFor = PaymentGatewayException.class`.

**Java Code Example:**
```java
// Custom checked exception
public class PaymentGatewayException extends Exception {
    public PaymentGatewayException(String message) { super(message); }
}

@Service
@RequiredArgsConstructor
public class PaymentService {

    private final OrderRepository orderRepo;
    private final PaymentGateway gateway;

    // BUG: checked exception does NOT rollback by default
    @Transactional
    public void processPayment_BUG(Long orderId) throws PaymentGatewayException {
        Order order = orderRepo.findById(orderId).orElseThrow();
        order.setStatus(OrderStatus.PROCESSING);
        orderRepo.save(order); // saved to DB
        gateway.charge(order); // throws PaymentGatewayException
        // order is COMMITTED as PROCESSING even though payment failed!
    }

    // CORRECT: rollbackFor ensures checked exception triggers rollback
    @Transactional(rollbackFor = PaymentGatewayException.class)
    public void processPayment(Long orderId) throws PaymentGatewayException {
        Order order = orderRepo.findById(orderId).orElseThrow();
        order.setStatus(OrderStatus.PROCESSING);
        orderRepo.save(order);
        gateway.charge(order); // exception triggers rollback, order not saved
    }

    // noRollbackFor "” don't rollback on optimistic lock conflicts (retry instead)
    @Transactional(noRollbackFor = ObjectOptimisticLockingFailureException.class)
    public void updateWithRetry(Long orderId) {
        try {
            Order order = orderRepo.findById(orderId).orElseThrow();
            order.incrementVersion();
            orderRepo.save(order);
        } catch (ObjectOptimisticLockingFailureException e) {
            // handle retry without rolling back any preceding work
        }
    }
}
```

**Follow-up Questions:**
- What happens if an inner `@Transactional` method marks the transaction for rollback but the outer method catches the exception?
- What is "transaction marked for rollback" (`RollbackRequiredException`)?
- How does `TransactionSystemException` differ from `RollbackException`?

**Common Mistakes:**
- Swallowing exceptions inside a `@Transactional` method expecting rollback "” rollback never fires
- Throwing checked exceptions expecting rollback without `rollbackFor`
- Marking inner method with `REQUIRES_NEW` expecting its rollback to be isolated "” it is, but the outer transaction may still commit its dirty work

**Interview Trap:**
"If I catch a `RuntimeException` inside a `@Transactional` method and do not rethrow, does the transaction roll back?" "” No. The exception never reaches the proxy. The transaction commits normally.

**Quick Revision:**
Default rollback: `RuntimeException` + `Error` only. Checked exceptions: add `rollbackFor`. Override with `noRollbackFor`. Catching exceptions before they exit the proxy prevents rollback. Rationale: checked = recoverable, unchecked = system failure.

---

## Q19: Optimistic vs Pessimistic Locking

**Difficulty:** Hard | **Interview Frequency:** Very High
**Companies:** Amazon, Flipkart, PayPal, Stripe, Booking.com, Goldman Sachs

**Short Answer (30-60 seconds):**
Optimistic locking assumes conflicts are rare "” it adds a `@Version` field; Hibernate appends `WHERE version = ?` to every UPDATE. If another transaction changed the row, the version mismatch causes `OptimisticLockException`. Pessimistic locking locks the row at read time using `SELECT FOR UPDATE`, blocking other transactions. Use optimistic for low-contention web apps; use pessimistic for high-contention scenarios like inventory management or seat booking.

**Deep Explanation:**

### Optimistic Locking (`@Version`)
Hibernate adds `WHERE id = ? AND version = ?` to UPDATE statements. If the row was modified concurrently, the update affects 0 rows, and Hibernate throws `StaleObjectStateException` (wrapped as `ObjectOptimisticLockingFailureException` in Spring).

Supported version field types: `int`, `Integer`, `long`, `Long`, `short`, `Short`, `Timestamp`, `Instant`.

### Pessimistic Locking (`LockModeType`)
| Mode | SQL | Behavior |
|---|---|---|
| `PESSIMISTIC_WRITE` | `SELECT ... FOR UPDATE` | Blocks other writers and readers (depending on DB) |
| `PESSIMISTIC_READ` | `SELECT ... FOR SHARE` | Allows other readers; blocks writers |
| `PESSIMISTIC_FORCE_INCREMENT` | `SELECT ... FOR UPDATE` + version++ | Combines pessimistic lock with version increment |

### When to use each:
- **Optimistic:** Read-heavy, low update frequency, web apps with short transactions. User profile updates, content management.
- **Pessimistic:** High-contention, must-win semantics. Inventory reservation, airline seat booking, financial account debits.

**Real-World Example:**
Flight booking: two users try to book the last seat simultaneously. Without locking, both read `available = 1`, both decrement, both write `available = 0` "” double booking. Pessimistic locking with `SELECT FOR UPDATE` ensures only one transaction proceeds.

**Java Code Example:**
```java
// Optimistic locking entity
@Entity
public class Product {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    private String name;
    private int stockCount;

    @Version
    private Long version; // Hibernate adds AND version=? to UPDATE

    // getters/setters
}

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {

    // Pessimistic write lock "” blocks concurrent updates
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM Product p WHERE p.id = :id")
    Optional<Product> findByIdForUpdate(@Param("id") Long id);
}

@Service
@RequiredArgsConstructor
public class InventoryService {

    private final ProductRepository productRepo;

    // Optimistic locking "” suitable for low-contention product updates
    @Transactional
    public void updateProductName(Long productId, String newName) {
        Product product = productRepo.findById(productId).orElseThrow();
        product.setName(newName);
        // Hibernate: UPDATE product SET name=?, version=2 WHERE id=? AND version=1
        // If version changed â†’ StaleObjectStateException
    }

    // Pessimistic locking "” for high-contention inventory reservation
    @Transactional
    public void reserveStock(Long productId, int quantity) {
        // SELECT ... FOR UPDATE "” row locked until transaction commits
        Product product = productRepo.findByIdForUpdate(productId)
            .orElseThrow(() -> new ProductNotFoundException(productId));

        if (product.getStockCount() < quantity) {
            throw new InsufficientStockException(
                "Not enough stock: available=" + product.getStockCount()
            );
        }
        product.setStockCount(product.getStockCount() - quantity);
    }

    // Handling optimistic lock failure with retry
    @Retryable(retryFor = ObjectOptimisticLockingFailureException.class, maxAttempts = 3)
    @Transactional
    public void safeUpdateStock(Long productId, int delta) {
        Product product = productRepo.findById(productId).orElseThrow();
        product.setStockCount(product.getStockCount() + delta);
    }
}
```

**Follow-up Questions:**
- What happens if `@Version` is not on an entity and two transactions update it simultaneously?
- Can optimistic locking prevent phantom reads?
- What is `PESSIMISTIC_FORCE_INCREMENT` and when is it needed?

**Common Mistakes:**
- Forgetting `@Version` and expecting Hibernate to detect conflicts "” it will silently overwrite (last-write-wins)
- Using pessimistic locking everywhere "” causes deadlocks and serializes throughput
- Not retrying on `OptimisticLockException` "” users see spurious errors

**Interview Trap:**
"Optimistic locking prevents lost updates "” is that the same as preventing dirty reads?" "” No. They address different problems. Dirty reads are an isolation level concern (read another transaction's uncommitted data). Lost updates are a concurrency concern (two transactions overwrite each other's committed changes). `@Version` addresses lost updates, not dirty reads.

**Quick Revision:**
Optimistic (`@Version`): no DB lock, conflict detected at update time via `WHERE version=?`. Pessimistic (`FOR UPDATE`/`FOR SHARE`): row locked at read time. Optimistic = low contention, pessimistic = high contention. Always handle `OptimisticLockException` with retry.

---

## Q20: Hibernate Dirty Checking

**Difficulty:** Medium | **Interview Frequency:** High
**Companies:** Thoughtworks, Infosys, Oracle, SAP, mid-size product companies

**Short Answer (30-60 seconds):**
Dirty checking is Hibernate's mechanism to detect which managed entities have changed since they were loaded. At flush time, Hibernate compares the current state of each managed entity against the snapshot taken at load time. Changed fields generate UPDATE statements automatically "” you never call `save()` explicitly for managed entities.

**Deep Explanation:**
**Mechanism:**
1. Entity loaded via `find()` or JPQL â†’ snapshot stored alongside live instance in L1 cache
2. Application modifies the entity's fields
3. At flush (before commit, before query execution), Hibernate iterates all managed entities
4. For each entity, it compares field-by-field against the snapshot
5. Differences generate `UPDATE` SQL

**Overhead:**
Every managed entity participates in dirty checking. A session with 1,000 managed entities checks all 1,000 at flush "” even if only 1 changed. With wide entities (many columns), this is CPU-intensive.

**Mitigation strategies:**
- `@Transactional(readOnly=true)` "” Spring hints Hibernate to skip dirty checking on flush (Hibernate 6 sets `FlushMode.MANUAL`)
- Use DTOs/projections for read-only queries "” entities never enter the session
- Explicitly set `FlushMode.COMMIT` or `FlushMode.MANUAL` for long sessions
- Avoid loading more entities than needed (pagination, limit clause)

**`readOnly=true` effects:**
- Hibernate sets `FlushMode.MANUAL` (no auto-flush)
- Snapshot not stored at load (saves memory)
- Spring passes `readOnly=true` hint to JDBC connection (driver optimization)
- Does NOT affect isolation level; does NOT prevent writes (you can still call `save()`)

**Real-World Example:**
A reporting job loads 50,000 `Order` entities to generate CSV. Without `readOnly=true`, Hibernate stores snapshots for all 50,000 and checks dirty state at flush "” wasting significant memory and CPU.

**Java Code Example:**
```java
@Entity
public class Order {
    @Id @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;
    private OrderStatus status;
    private BigDecimal total;
    // ... 15 more fields
}

@Service
@RequiredArgsConstructor
public class OrderReportService {

    private final OrderRepository orderRepo;
    private final EntityManager em;

    // BAD: loads all entities as managed â†’ dirty checking overhead for read-only job
    @Transactional
    public List<Order> getAllOrdersBad() {
        return orderRepo.findAll(); // 50,000 entities with snapshots
    }

    // GOOD: readOnly skips snapshot + dirty checking
    @Transactional(readOnly = true)
    public List<Order> getAllOrdersGood() {
        return orderRepo.findAll();
    }

    // BETTER for read-only: use DTO projection "” entities never managed
    @Transactional(readOnly = true)
    public List<OrderReportDto> getOrderReport() {
        return em.createQuery(
            "SELECT new com.example.OrderReportDto(o.id, o.status, o.total) FROM Order o",
            OrderReportDto.class
        ).getResultList();
    }

    // Dirty checking in action "” no explicit save() needed
    @Transactional
    public void approveOrder(Long orderId) {
        Order order = orderRepo.findById(orderId).orElseThrow();
        order.setStatus(OrderStatus.APPROVED); // entity is managed
        // At commit: Hibernate detects status changed â†’ UPDATE order SET status=? WHERE id=?
        // No orderRepo.save(order) needed!
    }
}

record OrderReportDto(Long id, OrderStatus status, BigDecimal total) {}
```

**Follow-up Questions:**
- What is `FlushMode` and what are the different modes?
- Does `@Transactional(readOnly=true)` prevent you from calling `save()`?
- How does Hibernate's bytecode enhancement change dirty checking behavior?

**Common Mistakes:**
- Calling `save()` on a managed entity unnecessarily "” works but generates redundant snapshot update
- Assuming `readOnly=true` prevents writes "” it does not; it only skips automatic flush/dirty check
- Not using `readOnly=true` on heavy read transactions "” unnecessary CPU and memory overhead

**Interview Trap:**
"`@Transactional(readOnly=true)` "” does Hibernate skip dirty checking completely?" "” Hibernate sets `FlushMode.MANUAL`, meaning it will not automatically flush dirty entities. However, if you explicitly call `entityManager.flush()`, dirty checking still runs. The automatic flush on commit and before queries is what is skipped.

**Quick Revision:**
Dirty checking = Hibernate compares managed entity state vs. snapshot at flush. Automatic UPDATE for changed fields "” no explicit `save()` needed. Overhead with many managed entities. Mitigate: `readOnly=true` (skips auto-flush/snapshot), DTOs for reads.

---

## Q21: Batch Inserts and Updates

**Difficulty:** Medium | **Interview Frequency:** High
**Companies:** Amazon, Flipkart, Zomato, logistics and fintech companies

**Short Answer (30-60 seconds):**
By default Hibernate sends one SQL statement per entity insert/update. Batch processing groups multiple statements into a single DB round trip, dramatically reducing latency for bulk operations. The critical gotcha: `IDENTITY` generation strategy forces Hibernate to execute each INSERT immediately to get the generated ID, breaking batching. Use `SEQUENCE` instead.

**Deep Explanation:**
**Why IDENTITY breaks batching:**
With `IDENTITY`, the DB assigns the PK after INSERT (via auto-increment). Hibernate needs the PK immediately to populate the entity's `@Id` field and place it in the L1 cache. This forces an immediate round trip per insert "” batching cannot accumulate statements.

**Configuration:**
```properties
spring.jpa.properties.hibernate.jdbc.batch_size=50
spring.jpa.properties.hibernate.order_inserts=true
spring.jpa.properties.hibernate.order_updates=true
spring.jpa.properties.hibernate.jdbc.batch_versioned_data=true
```

- `batch_size`: number of statements per batch
- `order_inserts/order_updates`: groups same-entity statements together (required for batching to work with multiple entity types)
- `batch_versioned_data`: include versioned entities in batching

**`saveAll()` and batching:**
Spring Data's `saveAll()` calls `save()` per entity. Batching works only if `batch_size` is configured and SEQUENCE is used. Without configuration, `saveAll(1000 entities)` = 1000 round trips.

**Optimal batch size:** 20"“50. Larger batches consume more memory and can cause network packet fragmentation.

**Real-World Example:**
An ETL job importing 100,000 product records. Without batching: 100,000 round trips. With batch size 50: 2,000 round trips "” 50x fewer.

**Java Code Example:**
```java
// Entity using SEQUENCE "” required for batching
@Entity
public class Product {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "product_seq")
    @SequenceGenerator(name = "product_seq", sequenceName = "product_seq",
                       allocationSize = 50) // pre-allocate 50 IDs
    private Long id;

    private String name;
    private BigDecimal price;
}

// application.properties
// spring.jpa.properties.hibernate.jdbc.batch_size=50
// spring.jpa.properties.hibernate.order_inserts=true
// spring.jpa.properties.hibernate.order_updates=true

@Service
@RequiredArgsConstructor
public class ProductImportService {

    private final ProductRepository productRepo;
    private final EntityManager em;

    // saveAll with Spring Data "” batches if configured with SEQUENCE
    @Transactional
    public void importProducts(List<ProductDto> dtos) {
        List<Product> products = dtos.stream()
            .map(dto -> new Product(dto.name(), dto.price()))
            .toList();
        productRepo.saveAll(products); // ~2000 batches of 50 vs 100,000 single inserts
    }

    // Manual batching with periodic flush+clear to control memory
    @Transactional
    public void importLargeDataset(List<ProductDto> dtos) {
        int batchSize = 50;
        for (int i = 0; i < dtos.size(); i++) {
            ProductDto dto = dtos.get(i);
            em.persist(new Product(dto.name(), dto.price()));

            if (i % batchSize == 0 && i > 0) {
                em.flush();  // execute batch
                em.clear();  // free memory "” evict managed entities
            }
        }
    }

    // Using JDBC template for ultra-high throughput (bypasses Hibernate entirely)
    @Autowired
    private JdbcTemplate jdbc;

    @Transactional
    public void bulkInsertJdbc(List<ProductDto> dtos) {
        String sql = "INSERT INTO product (name, price) VALUES (?, ?)";
        List<Object[]> args = dtos.stream()
            .map(d -> new Object[]{d.name(), d.price()})
            .toList();
        jdbc.batchUpdate(sql, args);
    }
}
```

**Follow-up Questions:**
- Why does `allocationSize` on `@SequenceGenerator` matter for performance?
- When would you bypass Hibernate entirely and use `JdbcTemplate.batchUpdate()`?
- How do you verify batching is actually occurring? (Enable SQL logging, count round trips)

**Common Mistakes:**
- Using `IDENTITY` strategy expecting batching to work "” it silently falls back to individual inserts
- Not calling `flush()` and `clear()` in loops "” OutOfMemoryError with large datasets
- Setting batch size too high (e.g., 1000) "” network overhead, memory spikes

**Interview Trap:**
"I set `hibernate.jdbc.batch_size=50` but my import is still slow "” what's wrong?" "” Most likely using `GenerationType.IDENTITY`. Switch to `SEQUENCE`. Also check `order_inserts=true` and ensure no `@GeneratedValue` annotation is missing.

**Quick Revision:**
Batching groups SQL statements into fewer round trips. Requires: `batch_size` config, `SEQUENCE` generation (not `IDENTITY`), `order_inserts=true`. `saveAll()` batches if configured correctly. Flush+clear in loops to control memory.

---

## Q22: Open Session in View (OSIV)

**Difficulty:** Medium | **Interview Frequency:** High
**Companies:** Thoughtworks, mid-size Spring MVC companies, fintech startups

**Short Answer (30-60 seconds):**
Open Session in View keeps the `EntityManager` open for the entire HTTP request, including the view rendering layer. This allows lazy-loaded associations to be fetched in controllers and view templates without `LazyInitializationException`. It is enabled by default in Spring Boot "” and it is considered an anti-pattern because it holds a database connection for the entire request duration and hides N+1 problems.

**Deep Explanation:**
**Default behavior:**
Spring Boot's `OpenEntityManagerInViewInterceptor` opens an `EntityManager` at the start of each HTTP request and closes it at the end (after the response is written). This is OSIV = true (default).

**Problems with OSIV:**
1. **DB connection held for the entire HTTP request lifecycle** "” including time spent in view rendering, JSON serialization, and network I/O. With a 10-connection pool and slow clients, this exhausts the pool.
2. **Silent N+1 queries** "” lazy loading works "automatically" in controllers and views, hiding expensive per-object queries that should have been JOIN FETCHed.
3. **Reasoning difficulty** "” lazy loading anywhere in the call stack makes it hard to reason about when DB queries occur.
4. **Spring Boot warning** "” since Spring Boot 2.0, a WARN log is printed at startup when OSIV is enabled with a connection pool.

**Fix:**
```properties
spring.jpa.open-in-view=false
```
Initialize all data in the service layer. Use DTOs or `@EntityGraph` to eagerly fetch needed associations. Let the service layer be the only place that touches the DB.

**Real-World Example:**
A REST API serving a product list with category names. With OSIV, the controller serializes `product.getCategory().getName()` "” triggering a lazy load for each product. 50 products = 51 queries. Without OSIV, this fails fast with `LazyInitializationException`, forcing the developer to fix the query properly.

**Java Code Example:**
```java
// application.properties
// spring.jpa.open-in-view=false  â† disable OSIV

@Entity
public class Product {
    @Id @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;
    private String name;

    @ManyToOne(fetch = FetchType.LAZY) // lazy "” requires OSIV or explicit loading
    private Category category;
}

// DTO for complete data "” no lazy loading needed outside transaction
record ProductDto(Long id, String name, String categoryName) {}

@Service
@RequiredArgsConstructor
public class ProductService {

    private final EntityManager em;

    // CORRECT: load all needed data inside @Transactional service method
    @Transactional(readOnly = true)
    public List<ProductDto> getAllProducts() {
        return em.createQuery(
            "SELECT new com.example.ProductDto(p.id, p.name, p.category.name) " +
            "FROM Product p JOIN p.category c",
            ProductDto.class
        ).getResultList();
        // No lazy loading after transaction boundary "” safe with OSIV=false
    }

    // Alternative: use @EntityGraph to eagerly load category
    @Transactional(readOnly = true)
    public List<Product> getAllProductsWithCategory() {
        return em.createQuery(
            "SELECT p FROM Product p JOIN FETCH p.category", Product.class
        ).getResultList();
    }
}

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/products")
public class ProductController {

    private final ProductService productService;

    @GetMapping
    public List<ProductDto> list() {
        // With OSIV=false, lazy loading here would throw LazyInitializationException
        // Correct: service already returned fully-initialized DTOs
        return productService.getAllProducts();
    }
}
```

**Follow-up Questions:**
- What is the alternative to OSIV for GraphQL or async request handling?
- How does OSIV interact with Spring's `@Async` methods?
- What happens to OSIV with WebFlux (reactive stack)?

**Common Mistakes:**
- Leaving OSIV enabled "for convenience" in production "” causes connection pool exhaustion under load
- Disabling OSIV without updating service methods "” `LazyInitializationException` flood
- Thinking OSIV is required "” it is not; proper data initialization in the service layer is the correct approach

**Interview Trap:**
"OSIV makes lazy loading work everywhere "” isn't that a good thing?" "” No. It masks N+1 problems, holds DB connections during view rendering, and makes the data access layer invisible to the developer. The benefit (convenience) does not outweigh the production risks.

**Quick Revision:**
OSIV = EntityManager open for full HTTP request. Default: TRUE in Spring Boot. Problems: connection held whole request, silent N+1, hard to reason. Fix: `spring.jpa.open-in-view=false` + initialize all data in service layer with JOINs or DTOs.

---

## Q23: HikariCP Connection Pool

**Difficulty:** Medium | **Interview Frequency:** High
**Companies:** Amazon, Google, Uber, Razorpay, any high-traffic backend role

**Short Answer (30-60 seconds):**
HikariCP is Spring Boot's default JDBC connection pool since 2.0. It is the fastest connection pool available for the JVM. Key properties: `maximum-pool-size` (default 10), `connection-timeout` (30s), `max-lifetime`. Pool exhaustion "” all connections in use "” manifests as `HikariPool-1 - Connection is not available, request timed out after 30000ms`. Right-sizing the pool is critical for throughput.

**Deep Explanation:**
**Key properties:**
| Property | Default | Description |
|---|---|---|
| `maximum-pool-size` | 10 | Max connections in pool |
| `minimum-idle` | = maximum-pool-size | Min idle connections maintained |
| `connection-timeout` | 30,000ms | Wait time before throwing timeout |
| `idle-timeout` | 600,000ms | Time before idle connection is closed |
| `max-lifetime` | 1,800,000ms | Max connection lifetime (before forced close) |
| `keepalive-time` | 0 (disabled) | Ping interval for idle connections |
| `validation-timeout` | 5,000ms | Timeout for connection test query |

**Pool sizing formula:**
Hikari's author (brettwooldridge) recommends:
```
pool_size = (core_count * 2) + effective_spindle_count
```
For a 4-core server with SSD (spindle count â‰ˆ 1): `(4*2) + 1 = 9`. Default of 10 is often correct for SSD-backed databases.

**Pool exhaustion causes:**
- Transactions held open too long (slow queries, external API calls inside `@Transactional`)
- OSIV enabled "” connections held for full HTTP request
- Connection leak "” `@Transactional` not closing session, or manual `getConnection()` not closed
- `maximum-pool-size` too small for workload

**Diagnosing exhaustion:**
- Log: `HikariPool-1 - Connection is not available, request timed out after 30000ms`
- Metric: `hikaricp.connections.pending` > 0 consistently
- Enable leak detection: `spring.datasource.hikari.leak-detection-threshold=60000`

**Real-World Example:**
A microservice starts failing under load. Investigation reveals `@Transactional` methods calling an external payment API "” holding DB connections while waiting for HTTP responses. Fix: move the external call outside the transaction.

**Java Code Example:**
```yaml
# application.yml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20          # scale for your workload
      minimum-idle: 5                # keep 5 warm connections
      connection-timeout: 20000      # fail fast at 20s not 30s
      idle-timeout: 300000           # close idle connections after 5 min
      max-lifetime: 1200000          # replace connections every 20 min
      pool-name: "OrderServicePool"  # identifiable in metrics
      leak-detection-threshold: 60000 # warn on connections held >60s
```

```java
@Configuration
public class DataSourceConfig {

    // Programmatic configuration for environment-specific pool sizing
    @Bean
    @ConfigurationProperties("spring.datasource.hikari")
    public HikariDataSource dataSource() {
        HikariConfig config = new HikariConfig();
        config.setMaximumPoolSize(
            Runtime.getRuntime().availableProcessors() * 2 + 1
        );
        config.setPoolName("AppPool");
        config.setLeakDetectionThreshold(60_000);
        return new HikariDataSource(config);
    }
}

@Service
@RequiredArgsConstructor
public class PaymentProcessingService {

    private final OrderRepository orderRepo;
    private final PaymentGatewayClient gatewayClient; // external HTTP call

    // BAD: DB connection held during external HTTP call
    @Transactional
    public void processPayment_BAD(Long orderId) {
        Order order = orderRepo.findById(orderId).orElseThrow();
        order.setStatus(OrderStatus.PROCESSING);
        orderRepo.save(order);
        gatewayClient.charge(order); // external call "” connection held!
        order.setStatus(OrderStatus.PAID);
        orderRepo.save(order);
    }

    // GOOD: minimize time holding connection
    @Transactional
    public void markProcessing(Long orderId) {
        Order order = orderRepo.findById(orderId).orElseThrow();
        order.setStatus(OrderStatus.PROCESSING);
    }

    // External call OUTSIDE transaction "” no connection held
    public PaymentResult chargeGateway(Long orderId) {
        Order order = orderRepo.findById(orderId).orElseThrow();
        return gatewayClient.charge(order);
    }

    @Transactional
    public void markPaid(Long orderId) {
        Order order = orderRepo.findById(orderId).orElseThrow();
        order.setStatus(OrderStatus.PAID);
    }
}
```

**Follow-up Questions:**
- How do you monitor HikariCP pool metrics in production?
- What is `max-lifetime` and why should it be less than the database's `wait_timeout`?
- How does HikariCP differ from DBCP2 or C3P0?

**Common Mistakes:**
- Setting `maximum-pool-size` very high (100+) "” creates DB-side connection pressure and context-switch overhead
- Ignoring `max-lifetime` "” stale connections from DB firewall timeouts cause errors
- Not setting `pool-name` "” makes it impossible to distinguish pools in metrics/logs

**Interview Trap:**
"More connections = better throughput, so I set pool size to 200." "” No. Beyond a point, more connections increase context-switching on the DB server and degrade throughput. Empirical benchmarks show optimal pool sizes are often 10"“20 for most workloads, not hundreds.

**Quick Revision:**
HikariCP = Spring Boot default pool. Key settings: `maximum-pool-size` (default 10), `connection-timeout` (30s), `max-lifetime`. Size = `(cores*2)+spindles`. Pool exhaustion = timeout errors. Minimize transaction duration to reduce pressure. Enable `leak-detection-threshold` in production.

---

## Q24: Common Hibernate Pitfalls

**Difficulty:** Medium | **Interview Frequency:** High
**Companies:** All companies using Spring Data JPA "” very broad

**Short Answer (30-60 seconds):**
The most dangerous Hibernate pitfalls in production are: `@Enumerated(EnumType.ORDINAL)` breaking silently when enum order changes, incorrect `equals()`/`hashCode()` on entities causing Set membership bugs and duplicate rows, `toString()` triggering lazy loading, and bidirectional associations where only one side is set causing `NullPointerException` or missing data.

**Deep Explanation:**

### 1. `@Enumerated(EnumType.ORDINAL)` danger
Stores enum by position (0, 1, 2...). If a new enum constant is inserted in the middle, all subsequent values in the DB become incorrect "” silently, with no error.

**Fix:** Always use `EnumType.STRING`. The slight storage overhead is irrelevant compared to data corruption risk.

### 2. `equals()`/`hashCode()` on entities
- Using Lombok `@Data` or `@EqualsAndHashCode` on JPA entities is dangerous "” it generates hash based on all fields including collections (triggers lazy loading) and may use `id` (null for transient entities, same for all new entities before persist).
- Transient entity: `id = null` â†’ all new entities are equal â†’ `HashSet<User>` of new users contains only one entry.
- **Best practices:**
  - Use a natural business key (`email`, `username`, `code`) for equals/hashCode
  - Or use surrogate ID but handle the transient-null case
  - Hibernate recommends: if using surrogate ID, implement equals/hashCode on it only, and return consistent hashCode even when id is null

### 3. `toString()` causing lazy loading
Lombok `@ToString` on an entity with lazy collections will trigger a DB query when the object is logged. This can produce N+1 during debug logging, or `LazyInitializationException` if called outside a session.

**Fix:** Exclude lazy fields from `toString()`. Use `@ToString(exclude = "orders")`.

### 4. Bidirectional not setting both sides
In a bidirectional `@OneToMany` / `@ManyToOne`, only setting the `@ManyToOne` side may leave the `@OneToMany` collection stale in the L1 cache. Subsequent access within the same session returns incomplete data.

**Fix:** Use convenience methods on the owning entity to set both sides atomically.

### 5. Passing detached entity to `persist()`
Calling `entityManager.persist(detachedEntity)` throws `EntityExistsException`. Use `merge()` for detached entities.

**Real-World Example:**
`OrderStatus` enum had `PENDING=0, APPROVED=1, SHIPPED=2`. A new `FRAUD_REVIEW` was inserted at position 1, shifting `APPROVED` to 2 and `SHIPPED` to 3. The DB still had old ordinal values "” all `APPROVED` orders were read back as `FRAUD_REVIEW` silently.

**Java Code Example:**
```java
// PITFALL 1: EnumType.ORDINAL "” dangerous
@Enumerated(EnumType.ORDINAL) // BAD: breaks if enum reordered
private OrderStatus status;

// CORRECT
@Enumerated(EnumType.STRING) // GOOD: stores "PENDING", "APPROVED"
private OrderStatus status;

// PITFALL 2: equals/hashCode using surrogate ID
@Entity
// @Data  â† DO NOT USE on entities
public class User {
    @Id @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    @NaturalId // Hibernate annotation for business key
    private String email;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof User other)) return false;
        return email != null && email.equals(other.email); // business key
    }

    @Override
    public int hashCode() {
        return Objects.hashCode(email); // stable, even when id is null
    }
}

// PITFALL 3: toString causing lazy loading "” use exclude
@Entity
@ToString(exclude = {"orders", "addresses"}) // exclude lazy collections
public class Customer {
    @Id @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;
    private String name;

    @OneToMany(mappedBy = "customer", fetch = FetchType.LAZY)
    private List<Order> orders = new ArrayList<>(); // excluded from toString

    // PITFALL 4: bidirectional "” convenience method sets BOTH sides
    public void addOrder(Order order) {
        orders.add(order);        // set collection side
        order.setCustomer(this);  // set owning side "” both must be set
    }
}

// PITFALL 5: persist() on detached entity
@Service
@RequiredArgsConstructor
public class UserService {

    private final EntityManager em;

    public void updateUser(User detachedUser) {
        // em.persist(detachedUser); // WRONG: EntityExistsException
        em.merge(detachedUser);      // CORRECT: merge detached entity
    }
}
```

**Follow-up Questions:**
- Why does Lombok `@Data` on a JPA entity cause problems beyond just `equals()`/`hashCode()`?
- What is the "transient entity in a Set" problem?
- How does `@NaturalId` work in Hibernate?

**Common Mistakes:**
- Using `@EqualsAndHashCode(callSuper=false)` on entity subclasses "” violates Liskov substitution in collections
- Not initializing collections (`= new ArrayList<>()`) "” `NullPointerException` when adding to uninitialized collection
- Using `@Data` on entities "” also generates `hashCode` using all fields, triggers lazy loading

**Interview Trap:**
"I put `@Enumerated(EnumType.ORDINAL)` on my status field for storage efficiency. Is there any risk?" "” Yes "” catastrophic. Adding or reordering enum constants silently corrupts existing DB data. The few bytes saved are never worth it. Always use `EnumType.STRING`.

**Quick Revision:**
Top pitfalls: (1) `ORDINAL` enum â†’ use `STRING`. (2) `equals`/`hashCode` on surrogate ID "” use business key. (3) `toString` on lazy collections "” exclude them. (4) Bidirectional "” set both sides. (5) `persist()` on detached "” use `merge()`.

---

## Reference: Entity Lifecycle State Diagram

```
                    new MyEntity()
                         â”‚
                         â–¼
              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
              â”‚      TRANSIENT       â”‚
              â”‚  (no ID, not tracked)â”‚
              â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                    â”‚           â–²
         persist()  â”‚           â”‚  delete (GC)
                    â–¼           â”‚
              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
              â”‚      MANAGED         â”‚â—„â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
              â”‚  (tracked, has ID)   â”‚                   â”‚
              â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜                   â”‚
                    â”‚           â”‚                   merge(detached)
          close() / â”‚           â”‚ remove()               â”‚
          evict()   â”‚           â”‚                        â”‚
                    â–¼           â–¼                        â”‚
              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”   â”‚
              â”‚ DETACHED  â”‚  â”‚      REMOVED         â”‚   â”‚
              â”‚(stale ref)â”‚  â”‚ (scheduled for DELETE)â”‚   â”‚
              â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜   â”‚
                    â”‚                   â”‚                â”‚
              merge()â”‚           commit/flush            â”‚
                    â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                                        â”‚
                                        â–¼
                               Row deleted from DB
                               (entity becomes TRANSIENT)

Methods summary:
  TRANSIENT  â†’ MANAGED    : persist(), merge() (also detachedâ†’managed)
  MANAGED    â†’ DETACHED   : close(), evict(), clear(), session ends
  MANAGED    â†’ REMOVED    : remove()
  REMOVED    â†’ MANAGED    : persist() (cancels removal)
  DETACHED   â†’ MANAGED    : merge()
  Flush/commit: MANAGED entities synchronized to DB
```

---

## Reference: `@Transactional` Propagation Quick Reference

| Propagation | Behavior when TX exists | Behavior when no TX | Primary Use Case |
|---|---|---|---|
| `REQUIRED` | Joins existing transaction | Creates new transaction | Default for service methods |
| `REQUIRES_NEW` | Suspends existing, creates new | Creates new transaction | Audit logging, independent records |
| `NESTED` | Creates savepoint within existing | Creates new transaction | Partial rollback in batch processing (JDBC only) |
| `SUPPORTS` | Joins existing transaction | Runs without transaction | Read operations, cache-backed reads |
| `NOT_SUPPORTED` | Suspends existing, runs without TX | Runs without transaction | Long I/O, external API calls |
| `MANDATORY` | Joins existing transaction | Throws `IllegalTransactionStateException` | Helper methods that enforce tx requirement |
| `NEVER` | Throws `IllegalTransactionStateException` | Runs without transaction | Operations explicitly forbidden from tx context |

**Key distinction "” REQUIRES_NEW vs NESTED:**
- `REQUIRES_NEW`: Inner transaction fully independent. Outer rollback does NOT affect already-committed inner work.
- `NESTED`: Savepoint inside outer transaction. Outer rollback DOES roll back nested work too.

---

## Reference: N+1 Solutions Comparison

| Approach | Mechanism | Pros | Cons | When to Use |
|---|---|---|---|---|
| **JOIN FETCH** (JPQL) | `SELECT p FROM Post p JOIN FETCH p.comments` | Simple, JPQL standard, full control | Cartesian product with multiple collections; pagination issues | Single association, moderate result size |
| **`@EntityGraph`** | `@EntityGraph(attributePaths = {"comments", "tags"})` on repo method | Declarative, reusable, no JPQL | Cartesian product with multiple eager paths; can be verbose | Spring Data repos, clear graph definition |
| **Batch Fetch** | `@BatchSize(size=25)` on association | Separate queries but batched; safe with pagination | Two round trips minimum; slightly more complex | Large result sets with pagination; multiple associations |
| **DTO Projection** | JPQL `new Dto(...)` or interface projection | Minimal data transfer; avoids entity management overhead; fastest reads | No entity lifecycle; manual mapping; not updatable via JPA | Read-only endpoints, reporting, aggregations |

**Pagination caveat:** JOIN FETCH with `@OneToMany` causes Hibernate to load all rows in memory and paginate in-app (`HHH90003004` warning). Use Batch Fetch or DTO projection with pagination.

---

## Reference: HikariCP Key Properties Cheat Sheet

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                    HikariCP Properties Cheat Sheet                  â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ Property                   â”‚ Default   â”‚ Notes                      â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ maximum-pool-size          â”‚ 10        â”‚ (coresÃ—2)+spindles formula  â”‚
â”‚ minimum-idle               â”‚ =max-pool â”‚ Set lower to save resources â”‚
â”‚ connection-timeout         â”‚ 30,000ms  â”‚ Lower in prod (10-20s)      â”‚
â”‚ idle-timeout               â”‚ 600,000ms â”‚ 0 = never expire idle       â”‚
â”‚ max-lifetime               â”‚ 1,800,000 â”‚ < DB wait_timeout           â”‚
â”‚ keepalive-time             â”‚ 0         â”‚ Ping idle connections        â”‚
â”‚ validation-timeout         â”‚ 5,000ms   â”‚ Max for alive check         â”‚
â”‚ leak-detection-threshold   â”‚ 0         â”‚ Set 60000 in prod           â”‚
â”‚ pool-name                  â”‚ HikariPoolâ”‚ Set unique name per service â”‚
â”‚ connection-test-query      â”‚ (auto)    â”‚ JDBC4 auto-test preferred   â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ Sizing formula:  pool_size = (cpu_cores Ã— 2) + effective_spindles   â”‚
â”‚ SSD (spindleâ‰ˆ1): 4-core â†’ (4Ã—2)+1 = 9 connections                  â”‚
â”‚ HDD (spindle=N): add actual spindle count                           â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ Pool Exhaustion Symptoms:                                           â”‚
â”‚  "¢ HikariPool-N - Connection is not available, request timed out   â”‚
â”‚  "¢ hikaricp.connections.pending > 0 in Micrometer metrics          â”‚
â”‚  "¢ Requests queuing in thread pool                                 â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ Root Causes of Exhaustion:                                          â”‚
â”‚  "¢ @Transactional holding connection during external API calls      â”‚
â”‚  "¢ OSIV=true (connection held entire HTTP request)                 â”‚
â”‚  "¢ Connection leak (getConnection() not closed)                    â”‚
â”‚  "¢ Pool too small for actual workload                              â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ Diagnostic:                                                         â”‚
â”‚  spring.datasource.hikari.leak-detection-threshold=60000           â”‚
â”‚  logging.level.com.zaxxer.hikari=DEBUG                             â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

---

*End of Chapter 8 "” Spring Data JPA & Hibernate*


