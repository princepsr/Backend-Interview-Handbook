# Volume 4: Databases & Performance
# Chapter 16: ACID, Transactions & Normalization

---

# Chapter 16 — ACID, Transactions & Normalization
## Part A: Core Concepts (Topics 1–8)

> **Target Audience:** SDE2 and above | FAANG+, Goldman Sachs, Stripe, Uber, Confluent
> **Databases Covered:** PostgreSQL 15+, MySQL 8 (InnoDB), Java 17 + Spring Data JPA 3

---

### Topic 1: ACID Properties
**Difficulty:** Hard | **Frequency:** Very High | **Companies:** Google, Amazon, Goldman Sachs, Stripe, Meta

**Q:** Explain each ACID property and describe the internal mechanisms that enforce them in a production database.

**Short Answer:**
ACID stands for Atomicity, Consistency, Isolation, and Durability. Together they guarantee that database transactions either fully succeed or leave the system in a known good state, even under concurrent access or hardware failure. Each property is enforced by distinct subsystems — undo logs, constraint engines, MVCC, and write-ahead logs.

**Deep Explanation:**

**Atomicity — "All or nothing"**
Atomicity guarantees that every statement inside a transaction either all commits together or all rolls back together. The mechanism is the **undo log** (PostgreSQL: undo heap, InnoDB: rollback segment).

- When a row is modified, the **before-image** is written to the undo log first.
- If the transaction aborts (explicit ROLLBACK, crash, deadlock), the undo log is replayed in reverse to restore prior row versions.
- PostgreSQL uses a concept called **heap tuples with dead visibility** rather than a traditional undo log. Old row versions remain in the heap and are cleaned by VACUUM. When a transaction rolls back, it marks its xmin/xmax tuples as invisible without physically rewriting data.
- InnoDB stores undo records in the **rollback segment** inside the system tablespace (or undo tablespaces in MySQL 8). Each undo record contains the before-image of the changed columns.

**Consistency — "Valid state to valid state"**
Consistency is partly the database's responsibility (constraints, triggers, foreign keys, CHECK constraints) and partly the application's responsibility (business rules). The DB enforces:
- NOT NULL, UNIQUE, CHECK constraints validated before the commit.
- Foreign key constraints checked at statement end (InnoDB) or at transaction end if deferred (PostgreSQL `DEFERRABLE INITIALLY DEFERRED`).
- Triggers fire synchronously inside the transaction so they either succeed together or cause the transaction to fail.

**Isolation — "Concurrent transactions don't interfere"**
Isolation is the most complex property and is enforced primarily through **MVCC (Multi-Version Concurrency Control)** and locking. Different isolation levels expose different anomalies (see Topic 2). Internally:
- PostgreSQL: uses transaction IDs (XIDs) stamped as `xmin`/`xmax` on each heap tuple. A reader checks its snapshot against these values.
- InnoDB: uses a **read view** at transaction start (for REPEATABLE READ) or at statement start (for READ COMMITTED), consulting undo records to reconstruct old versions.

**Durability — "Committed data survives crashes"**
Durability is enforced by the **Write-Ahead Log (WAL)** / redo log:
- Before any data page is written to disk, the WAL record describing that change is flushed to the WAL segment file (`fsync` or `fdatasync`).
- On recovery after a crash, the DB replays WAL records forward to rebuild all committed but not yet flushed data pages.
- PostgreSQL WAL is in `$PGDATA/pg_wal/`. InnoDB's redo log is in `ib_logfile0`, `ib_logfile1` (MySQL 8.0.30+ uses `#ib_redo*` files with dynamic sizing).
- `synchronous_commit = on` (PostgreSQL) forces WAL flush before returning success to the client. Setting it to `off` or `local` is a durability trade-off for performance.

**Real-World Example:**
A payment service debits Account A and credits Account B in a single transaction. Atomicity ensures that if the credit fails (e.g., account frozen), the debit is rolled back via undo log. Durability ensures that after the commit acknowledgment is sent to the client, a power outage will not lose the credit record because the WAL was already fsynced.

**Code Example:**
```java
@Service
public class PaymentService {

    @Transactional(isolation = Isolation.READ_COMMITTED,
                   rollbackFor = {InsufficientFundsException.class, AccountFrozenException.class})
    public void transfer(Long fromId, Long toId, BigDecimal amount) {
        Account from = accountRepo.findByIdWithLock(fromId); // SELECT FOR UPDATE
        Account to   = accountRepo.findByIdWithLock(toId);

        if (from.getBalance().compareTo(amount) < 0) {
            throw new InsufficientFundsException("Insufficient balance");
        }
        from.debit(amount);   // UPDATE accounts SET balance = balance - ? WHERE id = ?
        to.credit(amount);    // UPDATE accounts SET balance = balance + ? WHERE id = ?
        // Spring commits here — WAL fsync happens inside the DB before ACK returns
    }
}

// Repository
public interface AccountRepository extends JpaRepository<Account, Long> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT a FROM Account a WHERE a.id = :id")
    Account findByIdWithLock(@Param("id") Long id);
}
```

```sql
-- PostgreSQL: verify WAL setting
SHOW synchronous_commit;          -- should be 'on' for full durability
SHOW wal_level;                   -- 'replica' or 'logical' needed for replication

-- InnoDB: check redo log flushing
SHOW VARIABLES LIKE 'innodb_flush_log_at_trx_commit';
-- 1 = fsync on each commit (fully durable)
-- 2 = write to OS cache, fsync every second (risk 1s of data loss)
```

**Follow-up Questions:**
1. What is the difference between `synchronous_commit = off` and `fsync = off` in PostgreSQL?
2. How does InnoDB's `innodb_flush_log_at_trx_commit = 2` break durability in MySQL?
3. In PostgreSQL, does a ROLLBACK write WAL records? Why or why not?

**Common Mistakes:**
- Confusing undo log (for atomicity/MVCC) with redo log/WAL (for durability). They serve completely different purposes.
- Assuming consistency is solely the database's job; business-rule consistency is always the application's responsibility.

**Interview Traps:**
- "Is ACID consistency the same as CAP theorem consistency?" — No. CAP consistency means all nodes see the same data at the same time. ACID consistency means transactions take the DB from one valid state to another valid state.
- Candidates often forget that PostgreSQL does not have a traditional undo log — it uses heap versioning + VACUUM for old-version cleanup.

**Quick Revision:** ACID = Undo log (Atomicity) + Constraints (Consistency) + MVCC/Locks (Isolation) + WAL/redo log (Durability).

---

### Topic 2: Transaction Isolation Levels
**Difficulty:** Hard | **Frequency:** Very High | **Companies:** Stripe, Airbnb, Goldman Sachs, Uber, Shopify

**Q:** Describe the four SQL isolation levels. What anomalies does each permit, and how would you choose one for a financial application?

**Short Answer:**
SQL defines four isolation levels — Read Uncommitted, Read Committed, Repeatable Read, and Serializable — in increasing order of protection. Higher levels eliminate more anomalies (dirty reads, non-repeatable reads, phantom reads) at the cost of more contention or overhead. Most production systems default to Read Committed (PostgreSQL) or Repeatable Read (MySQL InnoDB).

**Deep Explanation:**

**Anomaly Definitions:**
- **Dirty Read:** Transaction T2 reads data written by T1 which has not committed yet. If T1 rolls back, T2 has read data that never existed.
- **Non-Repeatable Read:** T1 reads a row. T2 updates and commits that row. T1 reads the same row again and gets a different value.
- **Phantom Read:** T1 reads a set of rows satisfying a condition (e.g., `WHERE salary > 100000`). T2 inserts a new row matching that condition and commits. T1 re-runs the same query and sees an extra row (a "phantom").
- **Serialization Anomaly (Write Skew):** Two transactions each read overlapping data and each write to a non-overlapping part, but the combined effect is inconsistent (e.g., two doctors both going off-call simultaneously).

**Isolation Level Matrix:**

| Isolation Level    | Dirty Read | Non-Repeatable Read | Phantom Read | Write Skew |
|--------------------|-----------|---------------------|--------------|------------|
| Read Uncommitted   | Possible  | Possible            | Possible     | Possible   |
| Read Committed     | Prevented | Possible            | Possible     | Possible   |
| Repeatable Read    | Prevented | Prevented           | Possible*    | Possible   |
| Serializable       | Prevented | Prevented           | Prevented    | Prevented  |

*InnoDB's Repeatable Read prevents phantom reads via gap locks. PostgreSQL's Repeatable Read does NOT prevent phantoms — that requires Serializable in PostgreSQL.

**PostgreSQL Implementation:**
- Default: **Read Committed** — each statement gets a fresh snapshot.
- Repeatable Read: snapshot taken at first statement of the transaction; phantom reads can still occur if using explicit row locks.
- Serializable: uses **SSI (Serializable Snapshot Isolation)** — tracks read/write dependencies (rw-antidependencies) and aborts transactions that would create a cycle.

**InnoDB (MySQL) Implementation:**
- Default: **Repeatable Read** — snapshot taken at first statement.
- Uses **next-key locks** (index record lock + gap lock before the record) to prevent phantom reads in Repeatable Read.
- Serializable: every plain SELECT is converted to `SELECT ... LOCK IN SHARE MODE`.

**Real-World Example:**
A bank balance check + withdraw flow that reads balance then writes:
```
T1: SELECT balance FROM accounts WHERE id=1;  -- returns 1000
T2: SELECT balance FROM accounts WHERE id=1;  -- returns 1000
T1: UPDATE accounts SET balance = 900 WHERE id=1; COMMIT;
T2: UPDATE accounts SET balance = 900 WHERE id=1; COMMIT; -- BUG: should be 800
```
This is a **lost update**, preventable with Repeatable Read + locking or Serializable.

**Code Example:**
```java
// Spring: setting isolation level per transaction
@Transactional(isolation = Isolation.REPEATABLE_READ)
public void reportingQuery() { /* safe re-reads within this TX */ }

@Transactional(isolation = Isolation.SERIALIZABLE)
public void criticalTransfer() { /* no anomalies, highest cost */ }

// Raw JDBC isolation
Connection conn = dataSource.getConnection();
conn.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);
conn.setAutoCommit(false);
```

```sql
-- PostgreSQL: set for session
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- PostgreSQL: set for single transaction
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- MySQL: set for next transaction
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- MySQL: check current setting
SELECT @@transaction_isolation;

-- PostgreSQL: demo snapshot
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT count(*) FROM orders; -- captures snapshot here
-- concurrent inserts are invisible to this TX now
SELECT count(*) FROM orders; -- same result guaranteed
COMMIT;
```

**Follow-up Questions:**
1. PostgreSQL claims Repeatable Read prevents phantoms for UPDATE/DELETE but not SELECT. Explain why.
2. What is SSI (Serializable Snapshot Isolation) and how does it differ from 2PL-based serializability?
3. When would you choose Read Committed over Repeatable Read in a high-throughput API?

**Common Mistakes:**
- Assuming InnoDB Repeatable Read and PostgreSQL Repeatable Read behave identically — they do not (gap locks vs. snapshot only).
- Thinking Serializable is always "too slow" for production — PostgreSQL SSI is often faster than 2PL-based serializable in read-heavy workloads.

**Interview Traps:**
- "Does MySQL Repeatable Read prevent phantom reads?" — Yes, via next-key locks. PostgreSQL Repeatable Read does not.
- Write skew is not listed in the SQL standard anomaly table but Serializable prevents it; interviewers at Stripe/Goldman specifically probe this.

**Quick Revision:** Read Uncommitted < Read Committed (default PG) < Repeatable Read (default MySQL) < Serializable; higher = fewer anomalies + more contention.

---

### Topic 3: MVCC — Multi-Version Concurrency Control
**Difficulty:** Hard | **Frequency:** High | **Companies:** Google, Confluent, Stripe, Netflix

**Q:** How does MVCC work? Compare PostgreSQL's xmin/xmax heap implementation to InnoDB's undo-log-based approach.

**Short Answer:**
MVCC allows readers and writers to proceed concurrently without blocking each other by maintaining multiple versions of each row. Readers always see a consistent snapshot of the database at a point in time. PostgreSQL stores all versions inline in the heap; InnoDB stores the current version in the clustered index and reconstructs old versions from the undo log.

**Deep Explanation:**

**PostgreSQL MVCC:**

Every heap tuple (row) carries two hidden system columns:
- `xmin`: XID of the transaction that inserted this tuple version.
- `xmax`: XID of the transaction that deleted or updated this tuple (0 if still live).

When a row is updated, PostgreSQL does **NOT** modify the existing tuple in-place. Instead:
1. Marks the old tuple's `xmax` with the updating transaction's XID.
2. Inserts a new tuple with `xmin` = updating transaction's XID.
3. Both versions coexist in the heap until VACUUM removes dead tuples.

**Snapshot:** When a transaction starts (REPEATABLE READ) or each statement starts (READ COMMITTED), PostgreSQL captures a **snapshot**:
- `xmin`: lowest active XID — all XIDs below this are committed or rolled back.
- `xmax`: current next XID — all XIDs >= this are invisible.
- `xip_list`: list of in-progress XIDs that are invisible even if xmin < their XID < xmax.

A tuple is **visible** to a snapshot if:
```
tuple.xmin is committed AND tuple.xmin < snapshot.xmax AND tuple.xmin NOT IN xip_list
AND (tuple.xmax = 0 OR tuple.xmax is NOT committed OR tuple.xmax > snapshot.xmax)
```

**Transaction ID Wraparound:** XIDs are 32-bit counters. PostgreSQL uses a circular XID space. After ~2 billion transactions, the system must run VACUUM FREEZE to advance the freeze horizon, otherwise old tuples become invisible (the "XID wraparound" catastrophe). This is monitored via `age(datfrozenxid)`.

**InnoDB MVCC:**

InnoDB stores each row's **current** version in the clustered index (B-tree) with two extra hidden columns:
- `DB_TRX_ID`: transaction ID of the last modification.
- `DB_ROLL_PTR`: pointer to the undo log record containing the previous version.

**Read View:** When a transaction starts (REPEATABLE READ) or each statement starts (READ COMMITTED), InnoDB creates a **read view**:
- `m_low_limit_id`: highest TRX_ID at snapshot time (transactions with ID >= this are invisible).
- `m_up_limit_id`: lowest active TRX_ID (transactions with ID < this are committed and visible).
- `m_ids`: active transaction IDs at snapshot time (invisible).

To read a row, InnoDB follows the `DB_ROLL_PTR` chain through the undo log until it finds a version visible to the current read view.

**Key Differences:**

| Aspect | PostgreSQL | InnoDB |
|--------|-----------|--------|
| Old versions location | Inline in heap | Undo log (rollback segment) |
| Cleanup mechanism | VACUUM (background) | Purge thread (background) |
| Read path overhead | Compare xmin/xmax | Traverse undo log chain |
| Write amplification | New tuple in heap | In-place + undo record |
| Bloat risk | Heap bloat if VACUUM lags | Undo log bloat if purge lags |

**Real-World Example:**
Long-running OLAP queries in PostgreSQL can cause "table bloat" because VACUUM cannot clean tuples that are still visible to the oldest running transaction. In InnoDB, a long-running transaction causes the undo log to grow unboundedly because purge cannot advance past the read view's low limit.

**Code Example:**
```sql
-- PostgreSQL: inspect tuple versions (requires pageinspect extension)
CREATE EXTENSION IF NOT EXISTS pageinspect;

SELECT lp, t_xmin, t_xmax, t_ctid, t_data
FROM heap_page_items(get_raw_page('accounts', 0))
LIMIT 10;
-- t_xmax = 0 means the tuple is live (not deleted)
-- Same lp with different t_ctid shows the update chain

-- PostgreSQL: check snapshot internals
SELECT * FROM pg_stat_activity WHERE state = 'active';
SELECT backend_xid, backend_xmin FROM pg_stat_activity;

-- PostgreSQL: find bloated tables
SELECT relname, n_dead_tup, n_live_tup,
       round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- MySQL: check undo log usage
SELECT * FROM information_schema.INNODB_TRX
ORDER BY trx_started;  -- long-running TX holding back purge
SHOW ENGINE INNODB STATUS\G  -- look for "History list length"
-- History list length > 1 million = undo log pressure
```

```java
// JPA: visibility of own writes within same TX
@Transactional
public void demonstrateMVCC() {
    // This read gets a snapshot at TX start (REPEATABLE READ)
    long before = orderRepo.countByStatus("PENDING");

    // This write is visible to this TX but not others yet
    orderRepo.save(new Order("PENDING"));
    orderRepo.flush(); // force SQL flush within TX

    // PostgreSQL READ COMMITTED: would see own write
    // PostgreSQL REPEATABLE READ: snapshot was taken at TX start,
    //   but own writes within the same TX ARE visible
    long after = orderRepo.countByStatus("PENDING");
    // after = before + 1 in both cases (own writes always visible)
}
```

**Follow-up Questions:**
1. What is the XID wraparound problem in PostgreSQL and how does `VACUUM FREEZE` address it?
2. Why does a long-running transaction in InnoDB cause "History list length" to grow?
3. How does snapshot isolation differ from true serializability?

**Common Mistakes:**
- Saying "MVCC eliminates locking" — MVCC eliminates read-write lock contention but writes still need row-level locks against concurrent writers.
- Forgetting that PostgreSQL stores dead tuples in the heap until VACUUM; this can cause severe table bloat in high-write tables.

**Interview Traps:**
- "Does PostgreSQL MVCC mean you never need locks?" — No. DML statements (INSERT/UPDATE/DELETE) still acquire row-level exclusive locks against concurrent writers. MVCC only removes read-write conflicts.
- The undo log in InnoDB serves double duty: MVCC old versions AND rollback (atomicity). PostgreSQL separates these — heap versioning for MVCC, no traditional undo log.

**Quick Revision:** MVCC = multiple row versions so readers never block writers; PostgreSQL uses heap tuples (xmin/xmax), InnoDB uses undo log chain; both need background cleanup (VACUUM / purge).

---

### Topic 4: Locking
**Difficulty:** Hard | **Frequency:** High | **Companies:** Goldman Sachs, Stripe, Amazon, Palantir

**Q:** Explain shared vs. exclusive locks, row-level vs. table-level locking, and the difference between SELECT FOR UPDATE and SELECT FOR SHARE.

**Short Answer:**
Shared locks allow concurrent readers; exclusive locks block all other readers and writers. Row-level locks minimize contention in OLTP workloads. `SELECT FOR UPDATE` acquires an exclusive row lock for subsequent modification; `SELECT FOR SHARE` acquires a shared row lock that blocks updates but allows other readers.

**Deep Explanation:**

**Lock Types:**

| Lock Mode | Abbreviation | Blocks | Compatible With |
|-----------|-------------|--------|-----------------|
| ACCESS SHARE | AS | Nothing | All except ACCESS EXCLUSIVE |
| ROW SHARE | RS | ACCESS EXCLUSIVE | Most others |
| ROW EXCLUSIVE | RX | SHARE, SHARE ROW EXCLUSIVE, ACCESS EXCLUSIVE | SELECT, ROW SHARE |
| SHARE UPDATE EXCLUSIVE | SUE | SUE, SHARE, SRE, EXCLUSIVE, AE | AS, RS, RX |
| SHARE | S | RX, SRE, EXCLUSIVE, AE | AS, RS, S |
| SHARE ROW EXCLUSIVE | SRE | SHARE, SRE, EXCLUSIVE, AE | AS, RS, RX |
| EXCLUSIVE | E | All except AS | AS only |
| ACCESS EXCLUSIVE | AE | Everything | None |

*(PostgreSQL table-level lock hierarchy)*

**Row-Level Locks (PostgreSQL):**
- `FOR UPDATE`: exclusive row lock. Blocks other `FOR UPDATE`, `FOR NO KEY UPDATE`, `FOR SHARE`, `FOR KEY SHARE`.
- `FOR NO KEY UPDATE`: like FOR UPDATE but does not block `FOR KEY SHARE`.
- `FOR SHARE`: shared lock. Blocks `FOR UPDATE` and `FOR NO KEY UPDATE`.
- `FOR KEY SHARE`: weakest shared lock, only blocks `FOR UPDATE`.

**InnoDB Row Locks:**
- **Record lock**: locks a single index record.
- **Gap lock**: locks the gap before an index record. Prevents phantom inserts.
- **Next-key lock**: combination of record + gap lock. Default mode in REPEATABLE READ.
- **Insert intention lock**: special gap lock placed by INSERT operations before inserting.

**Table-Level Locks:**
- DDL operations (ALTER TABLE, DROP TABLE) require ACCESS EXCLUSIVE, which blocks all reads and writes.
- `LOCK TABLE t IN SHARE MODE` blocks writes but allows reads.
- `LOCK TABLE t IN EXCLUSIVE MODE` blocks everything.

**SELECT FOR UPDATE vs SELECT FOR SHARE:**
```
FOR UPDATE:   acquire exclusive lock → only I can update; no other reader with lock
FOR SHARE:    acquire shared lock  → others can also SELECT FOR SHARE; nobody can UPDATE
```

Use `FOR SHARE` when you need to read a parent record and ensure it is not deleted while you insert a dependent child (foreign key–like protection without the overhead of FK checks).

Use `FOR UPDATE` when you will modify the row in the same transaction (classic read-then-write pattern).

**Lock Wait Timeout:**
- PostgreSQL: `lock_timeout` parameter (e.g., `SET lock_timeout = '5s'`). Raises `ERROR: canceling statement due to lock timeout`.
- InnoDB: `innodb_lock_wait_timeout` (default 50 seconds). Raises `ERROR 1205: Lock wait timeout exceeded`.

**Real-World Example:**
Ticket booking: read the seat count, verify availability, then update. Without `SELECT FOR UPDATE`, two concurrent transactions can both read "1 seat available" and both proceed to book, resulting in an oversell.

**Code Example:**
```java
// Spring Data JPA: pessimistic write lock (SELECT FOR UPDATE)
public interface SeatRepository extends JpaRepository<Seat, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)  // SELECT ... FOR UPDATE
    @Query("SELECT s FROM Seat s WHERE s.id = :id AND s.status = 'AVAILABLE'")
    Optional<Seat> findAvailableSeatForUpdate(@Param("id") Long id);

    @Lock(LockModeType.PESSIMISTIC_READ)   // SELECT ... FOR SHARE
    @Query("SELECT s FROM Seat s WHERE s.id = :id")
    Optional<Seat> findSeatForShare(@Param("id") Long id);
}

@Transactional
public BookingResult bookSeat(Long seatId, Long userId) {
    Seat seat = seatRepo.findAvailableSeatForUpdate(seatId)
        .orElseThrow(() -> new SeatUnavailableException("Seat taken"));
    seat.setStatus("BOOKED");
    seat.setUserId(userId);
    seatRepo.save(seat);
    return new BookingResult(seat.getId(), "Booked");
}
```

```sql
-- PostgreSQL: explicit locking examples
BEGIN;
SELECT * FROM accounts WHERE id = 42 FOR UPDATE;            -- exclusive
SELECT * FROM accounts WHERE id = 42 FOR SHARE;             -- shared
SELECT * FROM accounts WHERE id = 42 FOR UPDATE NOWAIT;     -- fail immediately if locked
SELECT * FROM accounts WHERE id = 42 FOR UPDATE SKIP LOCKED; -- skip locked rows (queue workers)

-- PostgreSQL: check who holds locks
SELECT pid, mode, granted, relation::regclass
FROM pg_locks
JOIN pg_class ON pg_locks.relation = pg_class.oid
WHERE relname = 'accounts';

-- InnoDB: check lock waits
SELECT r.trx_id waiting_id,
       r.trx_mysql_thread_id waiting_thread,
       b.trx_id blocking_id,
       b.trx_mysql_thread_id blocking_thread
FROM information_schema.INNODB_LOCK_WAITS w
JOIN information_schema.INNODB_TRX r ON w.requesting_trx_id = r.trx_id
JOIN information_schema.INNODB_TRX b ON w.blocking_trx_id = b.trx_id;
```

**Follow-up Questions:**
1. What is `SKIP LOCKED` and in what pattern is it most useful?
2. How do gap locks in InnoDB interact with range queries to prevent phantoms?
3. What is an "intention lock" and why does InnoDB use them at the table level for row locks?

**Common Mistakes:**
- Using `SELECT FOR UPDATE` on a non-indexed column in InnoDB — this escalates to a table lock because InnoDB cannot gap-lock without an index.
- Forgetting that `FOR UPDATE` in one transaction will block other `FOR UPDATE` but NOT plain `SELECT` (because MVCC serves plain reads from snapshot).

**Interview Traps:**
- "Does SELECT FOR UPDATE block a plain SELECT in PostgreSQL?" — No, plain SELECT uses MVCC snapshot and is never blocked by row locks.
- `FOR UPDATE SKIP LOCKED` is not about MVCC — it is a lock behavior directive used in job queue patterns.

**Quick Revision:** Shared lock = multiple readers; exclusive lock = single writer; FOR UPDATE = exclusive row lock; FOR SHARE = shared row lock; InnoDB adds gap/next-key locks to prevent phantoms.

---

### Topic 5: Optimistic vs Pessimistic Locking
**Difficulty:** Medium-Hard | **Frequency:** Very High | **Companies:** Stripe, Shopify, Goldman Sachs, Atlassian

**Q:** Compare optimistic and pessimistic locking. When would you use each? How does JPA's `@Version` annotation implement optimistic locking, and how do you handle `OptimisticLockException`?

**Short Answer:**
Pessimistic locking acquires database locks upfront to prevent conflicts; optimistic locking assumes conflicts are rare and detects them at commit time via a version stamp. Pessimistic locking is safer under high contention; optimistic is more scalable for read-heavy workloads with low write contention. JPA `@Version` implements optimistic locking by incrementing a version column and adding it to the WHERE clause of UPDATE statements.

**Deep Explanation:**

**Pessimistic Locking:**
- Acquires a row-level lock (SELECT FOR UPDATE) at read time.
- Other transactions trying to modify the same row are blocked until the lock is released.
- Risk: deadlocks if lock acquisition order is inconsistent.
- Suitable for: financial transfers, inventory management, any domain with high contention.

**Optimistic Locking:**
- Does not acquire locks at read time.
- At write time, checks whether the data has changed since it was last read (via a version column or timestamp).
- If version mismatch: throws `OptimisticLockException` / SQL returns 0 rows updated.
- Risk: high retry rate under heavy write contention (thrashing).
- Suitable for: CMS content editing, profile updates, shopping cart modifications — low write contention.

**JPA @Version Internals:**
```java
@Entity
public class Product {
    @Id
    private Long id;

    private int quantity;

    @Version
    private Long version;  // automatically managed by JPA
}
```

When JPA executes an update:
```sql
-- JPA generates:
UPDATE products
SET quantity = ?, version = version + 1
WHERE id = ? AND version = ?;  -- the current version is included

-- If 0 rows updated → version mismatch → JPA throws OptimisticLockException
```

JPA also supports `@Version` with `Timestamp` type for cross-service scenarios where version numbers cannot be trusted.

**Retry Pattern for OptimisticLockException:**

```java
@Service
public class InventoryService {

    private static final int MAX_RETRIES = 3;

    @Autowired
    private ProductRepository productRepo;

    public void decrementStock(Long productId, int qty) {
        int attempts = 0;
        while (attempts < MAX_RETRIES) {
            try {
                executeDecrement(productId, qty);
                return;
            } catch (OptimisticLockingFailureException | ObjectOptimisticLockingFailureException e) {
                attempts++;
                if (attempts >= MAX_RETRIES) {
                    throw new StockConflictException("Could not update stock after " + MAX_RETRIES + " attempts", e);
                }
                // Optional: exponential backoff
                try { Thread.sleep(50L * attempts); } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new StockConflictException("Interrupted", ie);
                }
            }
        }
    }

    @Transactional
    private void executeDecrement(Long productId, int qty) {
        Product product = productRepo.findById(productId)
            .orElseThrow(() -> new ProductNotFoundException(productId));
        if (product.getQuantity() < qty) {
            throw new InsufficientStockException("Not enough stock");
        }
        product.setQuantity(product.getQuantity() - qty);
        // @Version causes: UPDATE products SET quantity=?, version=? WHERE id=? AND version=?
        productRepo.save(product);
    }
}
```

**Comparison Table:**

| Dimension | Optimistic | Pessimistic |
|-----------|-----------|-------------|
| Lock acquisition | At commit (via version check) | At read time (SELECT FOR UPDATE) |
| Throughput | High (no wait time for readers) | Lower (readers wait for writers) |
| Deadlock risk | None (no locks held) | Possible |
| Retry required | Yes, on conflict | No (wait in queue) |
| Best fit | Low write contention | High write contention |
| Network roundtrips | Lower (no lock request) | Higher |

**Real-World Example:**
A Google Docs-style collaborative editor would use Operational Transform or CRDTs, not database locking. But a simple "last edit wins with notification" feature could use optimistic locking: two editors reading the same document version — the second save will fail with a version mismatch and show an error.

**Follow-up Questions:**
1. How does Spring Retry's `@Retryable` integrate with `OptimisticLockException` to remove boilerplate?
2. What happens in JPA if you use `@Version` but the UPDATE is batched (JDBC batch mode)?
3. Can you use optimistic locking without a version column — e.g., by comparing all columns?

**Common Mistakes:**
- Mixing optimistic and pessimistic locking in the same transaction path, causing confusion about which mechanism is relied on.
- Not catching `ObjectOptimisticLockingFailureException` (Spring's translation) in addition to JPA's `OptimisticLockException`.

**Interview Traps:**
- "Does @Version prevent lost updates in a distributed system with two app servers?" — Yes, because the check happens at the database level, not the application level.
- Optimistic locking with high contention is worse than pessimistic locking because retries add latency and load. Know when to switch.

**Quick Revision:** Optimistic = read freely, check version at write (low contention); Pessimistic = lock at read time (high contention); JPA @Version adds `AND version = ?` to UPDATE; catch OptimisticLockException and retry.

---

### Topic 6: Deadlock
**Difficulty:** Hard | **Frequency:** High | **Companies:** Goldman Sachs, Amazon, Stripe, Uber

**Q:** What are the conditions for a deadlock? How do MySQL and PostgreSQL detect and resolve deadlocks? What strategies prevent them?

**Short Answer:**
A deadlock occurs when two or more transactions each hold a lock the other needs, creating a circular wait. Databases detect deadlocks by periodically checking the wait-for graph and kill one transaction (the victim). Prevention strategies include consistent lock ordering, using SELECT FOR UPDATE NOWAIT, and keeping transactions short.

**Deep Explanation:**

**Coffman's Four Necessary Conditions (all must hold for deadlock):**
1. **Mutual Exclusion**: at least one resource (lock) is held in a non-shareable mode.
2. **Hold and Wait**: a transaction holds at least one lock while waiting to acquire another.
3. **No Preemption**: locks cannot be forcibly taken from a transaction; they must be released voluntarily.
4. **Circular Wait**: a cycle exists in the transaction wait-for graph (T1 → T2 → T1, or longer chains).

**Detection (PostgreSQL):**
- PostgreSQL's lock manager builds a **wait-for graph** in-memory.
- Every `deadlock_timeout` ms (default: 1 second), before a process sleeps waiting for a lock, it checks for cycles in the graph.
- On detection, PostgreSQL picks the transaction with the least work done (least bytes in its WAL records) as the victim and cancels it with: `ERROR: deadlock detected`.
- The cancelled transaction receives `SQLSTATE 40P01`.

**Detection (InnoDB):**
- InnoDB runs a background deadlock detection thread that searches for cycles in the wait-for graph.
- Detection is O(n) in the number of locks, so it can be slow under extreme load.
- `innodb_deadlock_detect = OFF` disables detection (use `innodb_lock_wait_timeout` instead for very high throughput scenarios — but this risks long waits).
- The victim is the transaction with fewer undo log records (least work). The error is `ERROR 1213 (40001): Deadlock found when trying to get lock`.

**Classic Deadlock Scenario:**
```
T1: UPDATE accounts SET balance = balance - 100 WHERE id = 1;  -- locks row 1
T2: UPDATE accounts SET balance = balance - 100 WHERE id = 2;  -- locks row 2
T1: UPDATE accounts SET balance = balance + 100 WHERE id = 2;  -- waits for T2
T2: UPDATE accounts SET balance = balance + 100 WHERE id = 1;  -- waits for T1 → DEADLOCK
```

**Prevention Strategies:**

1. **Consistent Lock Ordering**: always acquire locks in the same order (e.g., always lock lower account ID first):
```java
@Transactional
public void transfer(Long fromId, Long toId, BigDecimal amount) {
    Long firstId  = Math.min(fromId, toId);
    Long secondId = Math.max(fromId, toId);
    Account first  = accountRepo.findByIdWithLock(firstId);
    Account second = accountRepo.findByIdWithLock(secondId);
    // transfer logic
}
```

2. **NOWAIT / Short Lock Timeout**: fail fast rather than wait:
```sql
SELECT * FROM accounts WHERE id = 1 FOR UPDATE NOWAIT;
-- Raises immediately if locked, no circular wait possible
```

3. **Keep Transactions Short**: fewer locks held = smaller window for conflicts.

4. **Avoid User Interaction Inside Transactions**: never wait for user input while holding locks.

5. **Upgrade Locks Early**: take the most restrictive lock you will need at the start of the transaction.

**Reading Deadlock Logs:**

```sql
-- PostgreSQL: deadlock in log (pg_log or stdout)
-- ERROR:  deadlock detected
-- DETAIL:  Process 12345 waits for ShareLock on transaction 67890;
--          blocked by process 54321.
--          Process 54321 waits for ShareLock on transaction 12345;
--          blocked by process 12345.
-- HINT:   See server log for query details.

-- MySQL: show last deadlock
SHOW ENGINE INNODB STATUS\G
-- Look for "LATEST DETECTED DEADLOCK" section
-- It shows both transactions' SQL statements and which lock each held/waited for

-- Enable deadlock logging in MySQL
SET GLOBAL innodb_print_all_deadlocks = ON;
-- Deadlocks now appear in the error log
```

```java
// Spring: handling deadlock with retry
@Service
public class TransferService {

    @Retryable(
        value = {CannotAcquireLockException.class, DeadlockLoserDataAccessException.class},
        maxAttempts = 3,
        backoff = @Backoff(delay = 100, multiplier = 2)
    )
    @Transactional
    public void transfer(Long fromId, Long toId, BigDecimal amount) {
        Long firstId  = Math.min(fromId, toId);
        Long secondId = Math.max(fromId, toId);
        Account first  = accountRepo.findByIdWithLock(firstId);
        Account second = accountRepo.findByIdWithLock(secondId);
        first.debit(amount);
        second.credit(amount);
    }
}
```

**Follow-up Questions:**
1. How does consistent lock ordering eliminate the circular wait condition?
2. What is a livelock and how does it differ from a deadlock?
3. When would you disable `innodb_deadlock_detect` and what risk does that introduce?

**Common Mistakes:**
- Thinking that row-level locking eliminates deadlocks — it reduces them but does not eliminate them because multiple row locks can still form cycles.
- Using `LOCK TABLE` to prevent deadlocks often introduces more contention than it solves.

**Interview Traps:**
- "What does PostgreSQL do when it detects a deadlock?" — It picks a victim (the transaction with the smallest WAL footprint) and cancels it, not kills — the other transaction can then proceed.
- Deadlock detection is an O(n²) operation under extreme lock graph sizes; this is why `innodb_deadlock_detect = OFF` exists for extreme OLTP cases.

**Quick Revision:** Deadlock = circular lock wait (Coffman: mutual exclusion + hold-and-wait + no preemption + circular wait); detected via wait-for graph; prevented by consistent lock ordering; handled in Spring via DeadlockLoserDataAccessException + @Retryable.

---

### Topic 7: Database Normalization
**Difficulty:** Medium | **Frequency:** High | **Companies:** All companies with SQL interviews, Goldman Sachs, Amazon

**Q:** Explain 1NF, 2NF, 3NF, and BCNF with examples. What are the three types of update anomalies, and when is denormalization justified?

**Short Answer:**
Normalization is the process of structuring a relational database schema to reduce redundancy and improve data integrity, defined in sequential normal forms. Each form eliminates a specific class of functional dependency anomalies. Going from 1NF → 2NF eliminates partial dependencies; 2NF → 3NF eliminates transitive dependencies; 3NF → BCNF handles remaining dependency violations.

**Deep Explanation:**

**Functional Dependency (FD):** X → Y means that for every valid instance of the relation, knowing X uniquely determines Y. E.g., `StudentID → StudentName`.

**Update Anomalies (motivation for normalization):**
Given a poorly designed table: `Orders(OrderID, CustomerID, CustomerName, CustomerCity, ProductID, ProductName, Quantity, Price)`

1. **Insert Anomaly**: Cannot add a new customer without also creating an order for them (CustomerName only exists if OrderID exists).
2. **Update Anomaly**: CustomerName is stored in every order row. If a customer changes their name, all rows must be updated consistently — missing one creates inconsistency.
3. **Delete Anomaly**: Deleting the last order of a customer also deletes all knowledge of that customer.

**First Normal Form (1NF):**
- **Rule**: Every column must contain **atomic** (indivisible) values. No repeating groups or arrays.
- **Violation**: `Products(id, name, phone_numbers)` where `phone_numbers = "555-1234, 555-5678"`.
- **Fix**: Create a separate `ProductPhones(product_id, phone_number)` table, or separate columns `phone1`, `phone2` (still not clean — prefer separate table).

```sql
-- Violates 1NF
CREATE TABLE employee_skills (
    emp_id INT,
    skills VARCHAR(500)  -- "Java, Python, SQL" — not atomic
);

-- 1NF compliant
CREATE TABLE employee_skills (
    emp_id  INT,
    skill   VARCHAR(100),
    PRIMARY KEY (emp_id, skill),
    FOREIGN KEY (emp_id) REFERENCES employees(id)
);
```

**Second Normal Form (2NF):**
- **Rule**: Must be in 1NF AND every non-key attribute must be **fully functionally dependent** on the entire primary key (no partial dependencies — only matters when PK is composite).
- **Violation**: `OrderItems(OrderID, ProductID, Quantity, ProductName)` — `ProductName` depends only on `ProductID`, not on the full composite PK `(OrderID, ProductID)`.
- **Fix**: Move `ProductName` to a `Products` table.

```sql
-- Violates 2NF: ProductName depends only on ProductID, not (OrderID, ProductID)
CREATE TABLE order_items (
    order_id     INT,
    product_id   INT,
    quantity     INT,
    product_name VARCHAR(200),  -- partial dependency on product_id alone
    PRIMARY KEY (order_id, product_id)
);

-- 2NF compliant
CREATE TABLE products (
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(200)
);

CREATE TABLE order_items (
    order_id   INT,
    product_id INT,
    quantity   INT,
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
```

**Third Normal Form (3NF):**
- **Rule**: Must be in 2NF AND no non-key attribute should be transitively dependent on the primary key (i.e., no non-key → non-key dependencies).
- **Violation**: `Employees(EmpID, DeptID, DeptName)` — `EmpID → DeptID → DeptName`. `DeptName` is transitively dependent on `EmpID` via `DeptID`.
- **Fix**: Move `DeptName` to a `Departments` table.

```sql
-- Violates 3NF: EmpID → DeptID → DeptName (transitive dependency)
CREATE TABLE employees (
    emp_id    INT PRIMARY KEY,
    dept_id   INT,
    dept_name VARCHAR(100)  -- depends on dept_id, not emp_id directly
);

-- 3NF compliant
CREATE TABLE departments (
    dept_id   INT PRIMARY KEY,
    dept_name VARCHAR(100)
);

CREATE TABLE employees (
    emp_id  INT PRIMARY KEY,
    dept_id INT,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);
```

**Boyce-Codd Normal Form (BCNF):**
- **Rule**: For every non-trivial FD X → Y, X must be a **superkey** (i.e., X must uniquely identify the entire tuple).
- BCNF is stricter than 3NF. A relation can be in 3NF but not BCNF when there are multiple overlapping candidate keys.
- **Classic Violation Example**: `CourseInstructor(Student, Course, Instructor)` with FDs:
  - `(Student, Course) → Instructor` (composite PK)
  - `Instructor → Course` (each instructor teaches only one course)
  - `Instructor` is not a superkey, but `Instructor → Course` is a non-trivial FD.

```sql
-- Violates BCNF
-- FD: Instructor → Course  (Instructor is not a superkey)
CREATE TABLE course_assignments (
    student_id  INT,
    course_id   INT,
    instructor  VARCHAR(100),
    PRIMARY KEY (student_id, course_id)
);

-- BCNF decomposition
CREATE TABLE instructor_courses (
    instructor VARCHAR(100) PRIMARY KEY,
    course_id  INT
);

CREATE TABLE student_instructors (
    student_id INT,
    instructor VARCHAR(100),
    PRIMARY KEY (student_id, instructor),
    FOREIGN KEY (instructor) REFERENCES instructor_courses(instructor)
);
```

**Normal Form Progression Summary:**

| Normal Form | Eliminates | Requires |
|-------------|-----------|---------|
| 1NF | Repeating groups, non-atomic columns | Atomic values, PK defined |
| 2NF | Partial dependencies | 1NF + full PK dependency for non-keys |
| 3NF | Transitive dependencies | 2NF + non-key attrs depend only on PK |
| BCNF | All FD violations (every determinant is superkey) | 3NF + stricter FD rule |

**Real-World Example:**
An e-commerce orders table that stores customer_city in every order row wastes space and creates update anomalies when the customer moves. Normalizing moves customer_city to the customers table, eliminating redundancy.

**Code Example:**
```sql
-- Checking for normalization violations with sample data
-- Transitive dependency check: if you update dept_name in one row
-- but not others, you have 3NF violation evidence

-- Before normalization (3NF violation):
SELECT dept_name, COUNT(DISTINCT dept_id) AS dept_id_count
FROM employees_denorm
GROUP BY dept_name
HAVING COUNT(DISTINCT dept_id) > 1;
-- Rows returned = inconsistency exists

-- After normalization: single source of truth
SELECT d.dept_name, COUNT(e.emp_id) AS headcount
FROM departments d
JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_name;
```

**Follow-up Questions:**
1. Give an example of a table in 3NF but not BCNF.
2. Does normalization always improve query performance?
3. What is 4NF and when is it relevant?

**Common Mistakes:**
- Thinking 2NF violations only matter when there is a composite PK — true, but when all tables have single-column PKs the jump to 3NF is the one that matters most.
- Confusing BCNF with 3NF: every BCNF schema is in 3NF, but not every 3NF schema is in BCNF.

**Interview Traps:**
- "What's the difference between 3NF and BCNF?" — In 3NF, a non-key can be determined by another non-key IF the determining attribute is part of a candidate key. BCNF removes this exception.
- Normalization can hurt read performance (more joins). Interviewers probe whether candidates know when to denormalize.

**Quick Revision:** 1NF = atomic values; 2NF = no partial key dependencies; 3NF = no transitive dependencies; BCNF = every determinant is a superkey; each level prevents insert/update/delete anomalies.

---

### Topic 8: Denormalization Strategies
**Difficulty:** Medium | **Frequency:** High | **Companies:** Netflix, Uber, Stripe, Amazon, Meta

**Q:** When and how do you denormalize a schema? Compare materialized views, redundant columns, precomputed aggregates, and event sourcing as denormalization approaches.

**Short Answer:**
Denormalization deliberately introduces redundancy to improve read performance, typically for analytics, reporting, or high-throughput read paths where join cost is prohibitive. Common strategies include materialized views, redundant summary columns, precomputed aggregate tables, and event sourcing. The trade-off is increased write complexity and risk of stale or inconsistent data.

**Deep Explanation:**

**When to Denormalize:**
- Read-heavy workloads where complex JOINs are the bottleneck.
- Analytical queries aggregating large datasets (OLAP).
- When you need sub-millisecond reads for denormalized document patterns.
- When the normalized query plan is using many index scans and hash joins that cannot be further optimized.

**Strategy 1: Materialized Views**

A materialized view stores the result of a query as a physical table. Unlike a regular view, the data is pre-computed and persisted.

```sql
-- PostgreSQL: materialized view for order summary
CREATE MATERIALIZED VIEW order_summary AS
SELECT
    c.customer_id,
    c.customer_name,
    COUNT(o.order_id)       AS total_orders,
    SUM(o.total_amount)     AS lifetime_value,
    MAX(o.created_at)       AS last_order_date
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name;

CREATE UNIQUE INDEX ON order_summary(customer_id);

-- Manual refresh (PostgreSQL 14+ supports CONCURRENTLY)
REFRESH MATERIALIZED VIEW CONCURRENTLY order_summary;

-- Automatic refresh via pg_cron extension (every hour)
SELECT cron.schedule('0 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY order_summary');
```

**Strategy 2: Redundant Columns**

Copy a frequently-read column from a parent table into a child table to eliminate a JOIN.

```sql
-- Normalized (requires JOIN to get customer_name in order queries)
SELECT o.order_id, c.customer_name
FROM orders o JOIN customers c ON o.customer_id = c.customer_id;

-- Denormalized: add customer_name to orders (redundant copy)
ALTER TABLE orders ADD COLUMN customer_name VARCHAR(200);

-- Application must update orders.customer_name when customers.name changes
-- This is a consistency risk — usually acceptable if name changes are rare

-- Query is now a simple scan:
SELECT order_id, customer_name FROM orders WHERE status = 'PENDING';
```

**Strategy 3: Precomputed Aggregates (Summary Tables)**

Instead of scanning millions of rows for COUNT/SUM/AVG, maintain a running aggregate in a separate table updated by triggers or CDC.

```sql
-- Summary table updated via trigger or application logic
CREATE TABLE product_stats (
    product_id    INT PRIMARY KEY,
    total_sold    BIGINT DEFAULT 0,
    total_revenue DECIMAL(15,2) DEFAULT 0,
    avg_rating    DECIMAL(3,2) DEFAULT 0,
    review_count  INT DEFAULT 0,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- PostgreSQL trigger to maintain total_sold
CREATE OR REPLACE FUNCTION update_product_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE product_stats
    SET total_sold    = total_sold + NEW.quantity,
        total_revenue = total_revenue + (NEW.quantity * NEW.unit_price)
    WHERE product_id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_item_after_insert
AFTER INSERT ON order_items
FOR EACH ROW EXECUTE FUNCTION update_product_stats();
```

**Strategy 4: Event Sourcing as an Alternative**

Instead of mutating state, store every state change as an immutable event. The current state is derived by replaying events. This separates the write model (append-only event log) from the read model (denormalized projections).

```java
// Event store entry
@Entity
@Table(name = "account_events")
public class AccountEvent {
    @Id
    @GeneratedValue
    private UUID eventId;

    private Long accountId;
    private String eventType;     // "CREDITED", "DEBITED"
    private BigDecimal amount;
    private LocalDateTime occurredAt;
    private Long version;         // for event ordering
}

// Read model (denormalized projection, rebuilt from events)
@Entity
@Table(name = "account_balance_view")
public class AccountBalanceView {
    @Id
    private Long accountId;
    private BigDecimal balance;
    private Long lastEventVersion;
}

// Projection builder (can be rebuilt from scratch at any time)
@Component
public class AccountProjection {

    @EventHandler
    @Transactional
    public void on(AccountCreditedEvent event) {
        AccountBalanceView view = viewRepo.findById(event.getAccountId())
            .orElse(new AccountBalanceView(event.getAccountId(), BigDecimal.ZERO, 0L));
        view.setBalance(view.getBalance().add(event.getAmount()));
        view.setLastEventVersion(event.getVersion());
        viewRepo.save(view);
    }

    @EventHandler
    @Transactional
    public void on(AccountDebitedEvent event) {
        AccountBalanceView view = viewRepo.findById(event.getAccountId())
            .orElseThrow();
        view.setBalance(view.getBalance().subtract(event.getAmount()));
        viewRepo.save(view);
    }
}
```

**Strategy 5: JSONB Embedding (PostgreSQL)**

For document-like data, embedding related data as JSONB in the parent row eliminates JOINs for common reads while preserving SQL queryability.

```sql
-- Embed top 5 reviews directly in the product row (hot path)
ALTER TABLE products ADD COLUMN recent_reviews JSONB;

-- Update via application or trigger when a review is added
UPDATE products
SET recent_reviews = (
    SELECT json_agg(r ORDER BY r.created_at DESC)
    FROM (
        SELECT review_id, rating, body, reviewer_name, created_at
        FROM reviews
        WHERE product_id = products.product_id
        ORDER BY created_at DESC
        LIMIT 5
    ) r
)
WHERE product_id = 42;

-- Fast read: no JOIN needed for product listing page
SELECT name, price, recent_reviews FROM products WHERE product_id = 42;
```

**Comparison of Denormalization Strategies:**

| Strategy | Consistency Risk | Write Overhead | Read Speedup | Rebuild Capability |
|----------|----------------|----------------|--------------|-------------------|
| Materialized View | Low (scheduled refresh) | None (pull-based) | High | Yes (full refresh) |
| Redundant Column | Medium (app must sync) | Low (extra column update) | Medium | Requires data migration |
| Precomputed Aggregate | Medium (trigger race) | Medium (trigger overhead) | Very High | Requires full recalculation |
| Event Sourcing | Low (replay from events) | Low (append-only) | High (after projection) | Yes (replay events) |
| JSONB Embedding | Medium (stale embeddings) | Medium | Very High | Requires reprocessing |

**Real-World Example:**
Netflix maintains denormalized read models per device type (mobile, TV, web) as separate projections from the same event stream. The phone catalog row has smaller thumbnails embedded; the TV row has HD metadata. Both are projections from the same source-of-truth events, rebuilt nightly or on-demand.

**Follow-up Questions:**
1. How do you handle a situation where a redundant column in the orders table becomes stale because the customer changes their name?
2. What is a CQRS (Command Query Responsibility Segregation) pattern and how does it relate to denormalization?
3. When would you use a PostgreSQL materialized view vs. a Redis cache for a precomputed summary?

**Common Mistakes:**
- Denormalizing prematurely without measuring actual query performance — always profile first.
- Using triggers for aggregate maintenance without considering trigger failures leaving the summary in an inconsistent state.

**Interview Traps:**
- "Is event sourcing just another form of denormalization?" — Partially. The event log is the normalized truth; projections are denormalized read models. The power is that projections can always be rebuilt.
- Materialized views in PostgreSQL require `REFRESH` — they do NOT auto-update on DML (unlike Oracle's fast refresh with materialized view logs). Always clarify this.

**Quick Revision:** Denormalize when JOINs are the bottleneck: use materialized views (refresh lag), redundant columns (app must sync), precomputed aggregates (trigger-maintained), or event sourcing (append-only + projections = full rebuild any time).

---

## Part A — Quick Reference Card

| Topic | Key Mechanism | DB Difference | Java/JPA Hook |
|-------|--------------|---------------|---------------|
| ACID | Undo log + WAL | PG: heap versioning; MySQL: rollback segment + ib_logfile | @Transactional |
| Isolation Levels | MVCC snapshots + locks | PG default: RC; MySQL default: RR; PG RR ≠ MySQL RR | Isolation.REPEATABLE_READ |
| MVCC | Row versions + snapshots | PG: xmin/xmax in heap; InnoDB: undo log chain | EntityManager snapshot |
| Locking | Shared/Exclusive + gap locks | PG: FOR UPDATE/FOR SHARE; InnoDB: next-key locks | @Lock(PESSIMISTIC_WRITE) |
| Optimistic Locking | @Version column | Same mechanism, both use version in WHERE clause | @Version + OptimisticLockException |
| Deadlock | Circular wait-for graph | PG: wait-for graph check at deadlock_timeout; MySQL: background detector | @Retryable(DeadlockLoserDataAccessException) |
| Normalization | Functional dependencies | No DB difference — schema design concept | JPA entity decomposition |
| Denormalization | Redundancy for reads | PG: MATERIALIZED VIEW; MySQL: no native MV (use triggers or app logic) | Spring @EventListener for projections |

---

*End of Chapter 16 Part A — ACID, Transactions & Normalization*


---

# Chapter 16 — ACID, Transactions & Normalization: Part B
## Topics 9–15 + Cheat Sheet
**Target:** SDE2, FAANG+, Goldman Sachs | **Volume:** 4 — Databases

---

### Topic 9: CAP Theorem

**Difficulty:** 4/5 | **Frequency:** 5/5 | **Companies:** Google, Amazon, Netflix, Goldman Sachs, Meta, Uber

**Q:** Explain the CAP theorem. Why can a distributed system only guarantee two of the three properties? Give real examples of CP and AP systems.

**Short Answer:**
CAP theorem states that a distributed system can guarantee at most two of: Consistency (every read receives the most recent write), Availability (every request receives a response), and Partition Tolerance (system continues operating despite network partitions). Since network partitions are unavoidable in real distributed systems, the practical trade-off is always between Consistency and Availability during a partition event.

**Deep Explanation:**

The CAP theorem was formalized by Eric Brewer in 2000 and proven by Gilbert and Lynch in 2002. The key insight is that network partitions (P) are not optional in any real distributed system — networks fail, packets drop, and nodes become unreachable. Therefore the real choice is: when a partition occurs, do you sacrifice Consistency (C) or Availability (A)?

**Consistency (C):** Every read sees the most recent write. If you write a value and immediately read it from any node, you get the updated value. This is linearizability — a strong guarantee.

**Availability (A):** Every non-failing node returns a response (not an error) for every request. The response may not be the most recent data, but the system does not refuse to answer.

**Partition Tolerance (P):** The system continues operating even when network partitions occur (some nodes cannot communicate with others).

**Why only 2 of 3 during a partition:**
Imagine two nodes A and B, and a write goes to A while a network partition prevents synchronization to B. Now a read comes to B:
- If you return the stale data → you are Available but not Consistent (AP)
- If you refuse to answer until A and B reconnect → you are Consistent but not Available (CP)
- You cannot be both C and A simultaneously during the partition

**CP Systems** (sacrifice Availability for Consistency):
- **ZooKeeper**: Used for distributed coordination. During a partition, a minority partition refuses requests rather than serve stale data. Leader election requires quorum.
- **HBase**: Built on HDFS/ZooKeeper. Chooses consistency; region servers become unavailable rather than serve inconsistent data.
- **etcd**: Kubernetes' backing store. Uses Raft consensus; minority nodes stop serving reads/writes.

**AP Systems** (sacrifice Consistency for Availability):
- **Cassandra**: All nodes can accept reads/writes. Uses tunable consistency. Default is eventual consistency. During partition, nodes serve potentially stale data.
- **CouchDB**: Designed for offline-first; resolves conflicts later via multi-version concurrency.
- **DNS**: Classic AP system — propagation delay means stale data served, but the system is always available.

**DynamoDB — Configurable:**
DynamoDB allows tunable consistency per-request:
- Eventually consistent reads (AP behavior, lower latency, cheaper)
- Strongly consistent reads (CP behavior, higher cost, reads only from leader)

**PACELC Extension:**
CAP only describes partition scenarios. PACELC adds: even when the system is running normally (no partition), there is still a trade-off between Latency (L) and Consistency (C). DynamoDB is classified as PA/EL (AP during partition, low latency over consistency normally).

**Real-World Example:**
During the 2012 AWS US-East outage, services using AP databases (like DynamoDB with eventual consistency) continued serving stale data to users. Services using CP databases (strict quorum-based systems) went down. Netflix, using Cassandra (AP), stayed partially operational by accepting that some user preference data might be stale. A banking system using a CP database correctly refused to process transactions during the outage rather than risk double-spending.

**Code Example:**
```java
// Cassandra — tunable consistency per operation
import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.ConsistencyLevel;
import com.datastax.oss.driver.api.core.cql.*;

public class CassandraConsistencyExample {

    private final CqlSession session;

    public CassandraConsistencyExample(CqlSession session) {
        this.session = session;
    }

    // AP behavior: eventually consistent read (faster, available during partition)
    public String readEventuallyConsistent(String userId) {
        SimpleStatement stmt = SimpleStatement.builder(
                "SELECT name FROM users WHERE id = ?")
            .addPositionalValue(userId)
            .setConsistencyLevel(ConsistencyLevel.ONE) // only 1 replica needs to respond
            .build();
        Row row = session.execute(stmt).one();
        return row != null ? row.getString("name") : null;
    }

    // CP behavior: strongly consistent read (quorum required)
    public String readStronglyConsistent(String userId) {
        SimpleStatement stmt = SimpleStatement.builder(
                "SELECT name FROM users WHERE id = ?")
            .addPositionalValue(userId)
            .setConsistencyLevel(ConsistencyLevel.QUORUM) // majority of replicas must agree
            .build();
        Row row = session.execute(stmt).one();
        return row != null ? row.getString("name") : null;
    }

    // Write with ALL — maximum consistency guarantee
    public void writeWithAllConsistency(String userId, String name) {
        SimpleStatement stmt = SimpleStatement.builder(
                "INSERT INTO users (id, name) VALUES (?, ?)")
            .addPositionalValues(userId, name)
            .setConsistencyLevel(ConsistencyLevel.ALL) // all replicas must confirm
            .build();
        session.execute(stmt);
    }
}

// DynamoDB — per-request consistency control (AWS SDK v2)
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;

public class DynamoDBConsistencyExample {

    private final DynamoDbClient dynamoDb;

    // Eventually consistent read (default, cheaper, AP behavior)
    public Map<String, AttributeValue> readEventual(String tableName, String id) {
        GetItemRequest request = GetItemRequest.builder()
            .tableName(tableName)
            .key(Map.of("id", AttributeValue.fromS(id)))
            .consistentRead(false) // AP — may return stale data
            .build();
        return dynamoDb.getItem(request).item();
    }

    // Strongly consistent read (CP behavior, 2x cost)
    public Map<String, AttributeValue> readStrong(String tableName, String id) {
        GetItemRequest request = GetItemRequest.builder()
            .tableName(tableName)
            .key(Map.of("id", AttributeValue.fromS(id)))
            .consistentRead(true) // CP — always returns most recent write
            .build();
        return dynamoDb.getItem(request).item();
    }
}
```

**Follow-up Questions:**
1. What is the PACELC model and how does it extend CAP?
2. How does ZooKeeper use Zab consensus to achieve CP guarantees? What happens when the leader fails?
3. If Cassandra is AP, how can you use it for use cases that need consistency (like counters or leaderboards)?

**Common Mistakes:**
- Saying "CA system" without qualification — in a distributed system with real network partitions, CA is not achievable. CA only makes sense for single-node systems.
- Confusing CAP Consistency with ACID Consistency — they are different concepts. CAP-C is about distributed linearizability; ACID-C is about constraint satisfaction within a single transaction.
- Treating CAP as a binary — modern systems like DynamoDB offer tunable consistency, making the trade-off a dial, not a switch.

**Interview Traps:**
- "Can you build a CA system?" — In a truly distributed system, no. If there are no partitions, you don't need partition tolerance, but the question is moot since real networks do partition.
- "Is Cassandra always AP?" — No. With ConsistencyLevel.ALL or QUORUM writes, Cassandra behaves more like CP. It is tunable.
- Confusing replication lag (eventual consistency under normal operations) with partition tolerance (behavior during failures).

**Quick Revision:** CAP = choose 2; since P is mandatory in real networks, choose CP (consistency over availability, e.g., ZooKeeper) or AP (availability over consistency, e.g., Cassandra); DynamoDB is tunable per-request.

---

### Topic 10: BASE vs ACID

**Difficulty:** 3/5 | **Frequency:** 4/5 | **Companies:** Amazon, Netflix, Twitter, Uber, Airbnb, Goldman Sachs

**Q:** What does BASE mean and how does it contrast with ACID? When is eventual consistency acceptable, and when is it dangerous?

**Short Answer:**
BASE (Basically Available, Soft state, Eventually consistent) is the consistency model used by most NoSQL systems, trading the strong guarantees of ACID for higher availability and horizontal scalability. The system is always available but may return stale data; state can change without input (due to replication); and given no new updates, all replicas will eventually converge to the same value.

**Deep Explanation:**

BASE was coined by Dan Pritchett at eBay as the antithesis of ACID:

**B — Basically Available:** The system guarantees availability (per CAP theorem) — every request receives a response. However, the response may reflect a stale state. The system does not guarantee the most recent write is returned.

**A — Soft State:** The state of the system may change over time, even without new input, as replicas synchronize. Contrast with ACID where state is deterministic after a commit.

**E — Eventually Consistent:** Given no new updates, all replicas will converge to the same value. The time to convergence (convergence window) varies by system — milliseconds to seconds under normal conditions, longer during failures.

**ACID vs BASE trade-offs:**

| Property | ACID | BASE |
|---|---|---|
| Consistency | Strong (immediate) | Eventual |
| Availability | May sacrifice (2PC blocks) | Always responds |
| Scalability | Difficult to scale horizontally | Designed for horizontal scale |
| Complexity | Handled by database | Pushed to application layer |
| Use case | Financial, inventory | Social media, caching, analytics |

**When eventual consistency IS acceptable:**
- User profile updates (seeing a slightly stale bio is harmless)
- Social media feeds (seeing posts out of order for a few seconds is fine)
- Product catalog / search indexes (showing yesterday's price for 100ms is acceptable)
- DNS resolution (propagation delay is expected and tolerated)
- Shopping cart (Amazon's Dynamo paper used shopping carts as the canonical example — merge conflicts are handled gracefully)
- Leaderboards and counters where approximate values are fine
- Recommendation engines (stale recommendations are still useful)

**When eventual consistency is DANGEROUS:**
- Bank account balances (double-spend problem)
- Inventory management (overselling if two nodes show the same item as available)
- Payment processing (idempotency must be handled explicitly)
- Seat reservations (double-booking on airlines/movies)
- Security and access control (revoked permissions must propagate immediately)
- Distributed locks (two nodes must not both believe they hold a lock)

**Real-World Example:**
Amazon's shopping cart (documented in the Dynamo paper) intentionally uses eventual consistency. If a user adds an item to their cart on one device while another device makes a concurrent update, both updates are preserved using a "last writer wins" or vector clock strategy — the cart may briefly show inconsistency but never loses items. This is a deliberate product decision: losing items from a cart is worse than briefly showing a cart that merges both states. Contrast this with Amazon's payment processing, which uses ACID databases to ensure money is not deducted twice.

**Code Example:**
```java
// Spring Boot — Redis caching with eventual consistency awareness
import org.springframework.cache.annotation.Cacheable;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.stereotype.Service;

@Service
public class UserProfileService {

    private final UserRepository userRepository;

    // Eventual consistency: cache may be stale for up to TTL duration
    // Acceptable for read-heavy profile display use case
    @Cacheable(value = "userProfiles", key = "#userId",
               unless = "#result == null")
    public UserProfile getUserProfile(String userId) {
        // Cache miss: fetch from DB and cache it
        // Cache hit: may return data up to 5 minutes stale
        return userRepository.findById(userId)
            .map(UserProfile::from)
            .orElse(null);
    }

    // On update: evict cache (eventual consistency window = next cache TTL)
    @CacheEvict(value = "userProfiles", key = "#userId")
    public void updateUserProfile(String userId, UserProfileUpdateRequest req) {
        // DB updated immediately (ACID), but other service instances'
        // caches may serve stale data until eviction propagates
        userRepository.updateProfile(userId, req);
    }
}

// Demonstrating read-your-writes consistency problem in distributed system
@Service
public class OrderService {

    private final OrderRepository writeRepo;      // primary (source of truth)
    private final OrderReadRepository readRepo;    // read replica (may be lagged)

    // Problem: user places order, then immediately reads it — may not see it
    // (replication lag on read replica)
    public Order createAndReadOrder(CreateOrderRequest req) {
        Order order = writeRepo.save(Order.from(req)); // writes to primary

        // BUG: reading from replica — may return null due to replication lag!
        // return readRepo.findById(order.getId()).orElseThrow();

        // CORRECT: read own writes from primary for immediate consistency
        return writeRepo.findById(order.getId()).orElseThrow();
    }

    // Idempotency key pattern for at-least-once delivery (BASE systems)
    public Order createOrderIdempotent(CreateOrderRequest req, String idempotencyKey) {
        // Check if already processed (handles duplicate delivery in BASE systems)
        return writeRepo.findByIdempotencyKey(idempotencyKey)
            .orElseGet(() -> {
                Order order = Order.from(req);
                order.setIdempotencyKey(idempotencyKey);
                return writeRepo.save(order);
            });
    }
}
```

**Follow-up Questions:**
1. How does vector clocks solve the conflict resolution problem in eventually consistent systems?
2. What is the "read-your-writes" consistency guarantee and how do you implement it in a system with read replicas?
3. How does DynamoDB's conditional writes (using `ConditionExpression`) help enforce ACID-like behavior in a BASE system?

**Common Mistakes:**
- Saying "NoSQL is always eventually consistent" — MongoDB with write concern `majority` and read concern `linearizable` can provide strong consistency.
- Ignoring the convergence window — in practice, replication lag during network issues can be seconds or minutes, not just milliseconds.
- Not handling idempotency — in BASE systems with at-least-once delivery, duplicate processing must be handled at the application layer.

**Interview Traps:**
- "Is BASE weaker than ACID?" — Not weaker, different. BASE systems can handle scale that ACID systems cannot. The trade-offs are intentional.
- "Can you mix BASE and ACID?" — Yes. A common pattern is ACID for writes (Postgres primary) with BASE for reads (read replicas, cache). This is called CQRS (Command Query Responsibility Segregation).

**Quick Revision:** BASE = sacrifice consistency for availability and scale; acceptable for social feeds, profiles, caching; dangerous for money, inventory, access control; always implement idempotency in BASE systems.

---

### Topic 11: Two-Phase Commit (2PC)

**Difficulty:** 4/5 | **Frequency:** 4/5 | **Companies:** Goldman Sachs, Morgan Stanley, Google, Oracle, SAP

**Q:** Explain the Two-Phase Commit protocol. What are its failure modes, and why is it problematic in microservices architectures?

**Short Answer:**
Two-Phase Commit (2PC) is a distributed atomic commitment protocol with a prepare phase (coordinator asks all participants if they can commit) and a commit phase (coordinator sends commit or abort based on unanimous vote). It guarantees atomicity across distributed nodes but introduces blocking behavior and single-point-of-failure risk via the coordinator, making it unsuitable for high-availability microservices.

**Deep Explanation:**

**Phase 1 — Prepare (Voting Phase):**
1. The coordinator sends a `PREPARE` message to all participant nodes.
2. Each participant acquires all necessary locks, writes the transaction to its write-ahead log (WAL), and votes `YES` (can commit) or `NO` (cannot commit / abort).
3. If a participant votes YES, it is in a "prepared" state — it has promised to commit if asked to.

**Phase 2 — Commit/Abort (Decision Phase):**
1. If ALL participants voted YES → coordinator writes `COMMIT` to its log and sends `COMMIT` to all participants.
2. If ANY participant voted NO → coordinator writes `ABORT` to its log and sends `ROLLBACK` to all participants.
3. Participants execute the decision, release locks, and acknowledge.

**The Blocking Problem:**
2PC is a **blocking protocol**. During Phase 2, after a participant votes YES:
- It holds all locks.
- It cannot make progress (commit or abort) without the coordinator's decision.
- If the coordinator crashes between Phase 1 completion and Phase 2, participants are **stuck** holding locks indefinitely.

This is called the **"uncertain state" window** — participants know they voted YES but cannot unilaterally decide to commit or abort (another participant may have voted NO).

**Failure Scenarios:**

| Failure Point | Consequence |
|---|---|
| Coordinator fails before Phase 1 | Transaction aborted, no locks held — safe |
| Participant fails before voting | Coordinator gets no response → abort |
| Coordinator fails after all YES votes | Participants stuck holding locks — **blocking** |
| Participant fails after voting YES | On recovery, must query coordinator for decision |
| Network partition after Phase 1 | Undecided participants cannot proceed — **blocking** |

**3PC (Three-Phase Commit):**
Adds a pre-commit phase to reduce blocking. Never actually used in production due to complexity and performance overhead. Does not solve the problem under certain network partition scenarios.

**Why 2PC is problematic in microservices:**
1. **Locks held across network calls** — each service holds database locks during the entire 2PC window, causing latency spikes and deadlocks under load.
2. **Coordinator is a single point of failure** — in microservices, which service is the coordinator? Losing it blocks all participants.
3. **Tight coupling** — all participating services must implement the 2PC protocol and remain synchronized.
4. **Not polyglot-friendly** — 2PC requires database-level support (XA transactions). Most NoSQL databases don't support XA.
5. **Performance** — 2PC requires at minimum 2 round trips (prepare + commit) + logging at each step, adding significant latency.
6. **Availability is reduced** — if any single participant is unavailable, the transaction cannot proceed.

**Where 2PC is still used:**
- Traditional enterprise systems (Oracle RAC, IBM DB2 distributed transactions)
- XA-compliant JDBC drivers for cross-database transactions
- Message queue + database atomicity (JMS + XA)
- Internal Google Spanner (uses a variation with TrueTime for external consistency)

**Real-World Example:**
A banking system needs to transfer money between two accounts in different database shards. Using 2PC: the coordinator sends PREPARE to both shard A (debit account) and shard B (credit account). Both respond YES and hold locks. The coordinator crashes before sending COMMIT. Both shards are now stuck holding locks — no other transaction can touch those accounts until the coordinator recovers (or a manual timeout/rollback intervention occurs). In a high-traffic system, this cascades into widespread lock contention. This is why modern distributed systems use Saga pattern instead.

**Code Example:**
```java
// XA (2PC) Transaction using Java EE / Jakarta EE
// This demonstrates 2PC across two databases

import javax.transaction.UserTransaction;
import javax.annotation.Resource;
import javax.sql.XADataSource;
import java.sql.Connection;

// Spring Boot equivalent using JTA (Atomikos or Bitronix)
// application.properties:
// spring.jta.atomikos.datasource.primary.xa-data-source-class-name=...
// spring.jta.atomikos.datasource.secondary.xa-data-source-class-name=...

@Service
@Transactional // This becomes a distributed XA transaction when multiple XA datasources are involved
public class CrossDatabaseTransferService {

    @Autowired
    @Qualifier("primaryDb") // e.g., account shard A
    private AccountRepository primaryAccountRepo;

    @Autowired
    @Qualifier("secondaryDb") // e.g., account shard B
    private AccountRepository secondaryAccountRepo;

    // With JTA + XA datasources, Spring manages 2PC automatically
    // Phase 1: Spring calls XAResource.prepare() on both datasources
    // Phase 2: Spring calls XAResource.commit() or rollback() on both
    public void transferMoney(String fromAccountId, String toAccountId, BigDecimal amount) {
        // Both operations are wrapped in a single XA transaction
        primaryAccountRepo.debit(fromAccountId, amount);   // shard A
        secondaryAccountRepo.credit(toAccountId, amount);  // shard B
        // If either throws, JTA rolls back both (atomically, via 2PC)
    }
}

// Problem demonstration: coordinator failure simulation
// This is WHY we avoid 2PC in microservices
public class TwoPCProblemDemo {

    public void demonstrateBlockingProblem() {
        // Step 1: Coordinator sends PREPARE to Service A and Service B
        boolean serviceAReady = serviceA.prepare(txId);   // ServiceA: YES, holds lock
        boolean serviceBReady = serviceB.prepare(txId);   // ServiceB: YES, holds lock

        if (serviceAReady && serviceBReady) {
            // Step 2: Coordinator crashes HERE
            // ServiceA and ServiceB are now stuck in "prepared" state
            // They cannot commit (might be wrong) or abort (coordinator might have committed)
            // Solution: timeout + heuristic rollback (risks inconsistency!)
            coordinatorCrashSimulation(); // <-- DISASTER

            // serviceA.commit(txId); // Never called
            // serviceB.commit(txId); // Never called
        }
    }
}
```

**Follow-up Questions:**
1. What is the "heuristic decision" in 2PC recovery, and why does it risk data inconsistency?
2. How does Google Spanner use TrueTime to avoid 2PC blocking while still achieving external consistency?
3. What is XA in JDBC, and when would you use `javax.transaction.UserTransaction` directly vs Spring's `@Transactional`?

**Common Mistakes:**
- Confusing 2PC with 2PL (Two-Phase Locking) — 2PL is about acquiring locks in a growing phase and releasing in a shrinking phase within a single database; 2PC is a distributed commitment protocol.
- Assuming Spring's `@Transactional` automatically does distributed 2PC — it does NOT. You need JTA + XA datasources for that.
- Thinking that 3PC solves all problems — it reduces blocking in some failure scenarios but adds complexity and does not work under network partitions.

**Interview Traps:**
- "Is 2PC atomic?" — Yes, but only if the coordinator recovers. In practice, coordinator crashes can leave the system in an indeterminate state that requires manual intervention.
- "Does microservices mean you can never have ACID?" — Not entirely. Sagas give ACD (no isolation guarantee). If services share a database schema (anti-pattern but common), ACID applies within those boundaries.

**Quick Revision:** 2PC = Prepare (all vote) + Commit (if unanimous); main problem = coordinator failure leaves participants stuck holding locks; avoid in microservices; use Saga pattern instead.

---

### Topic 12: Distributed Transactions Alternatives

**Difficulty:** 5/5 | **Frequency:** 5/5 | **Companies:** Netflix, Uber, Amazon, DoorDash, Stripe, Goldman Sachs

**Q:** What alternatives exist to 2PC for distributed transactions in microservices? Explain the Saga pattern, the Outbox pattern, and idempotency-based approaches.

**Short Answer:**
The primary alternatives are: Saga pattern (sequence of local transactions with compensating transactions for rollback), Transactional Outbox pattern (atomically write events alongside data in the same database transaction, then reliably publish them), and at-least-once delivery combined with idempotent consumers. Together these provide ACD (Atomicity, Consistency, Durability) without holding distributed locks.

**Deep Explanation:**

**Saga Pattern:**

A Saga decomposes a distributed transaction into a sequence of local transactions. Each service executes its local transaction and publishes an event or message. If a step fails, compensating transactions are executed in reverse order.

**Choreography-based Saga:**
- Services react to events (no central coordinator).
- Service A does local transaction → publishes event → Service B listens → does its local transaction → etc.
- Failure: Service B publishes a failure event → Service A listens → executes compensating transaction.
- Pros: Loose coupling, simple for short sagas.
- Cons: Difficult to track overall saga state, hard to debug, risk of cyclic event chains.

**Orchestration-based Saga:**
- A Saga Orchestrator (a service or workflow engine) commands each participant step by step.
- Orchestrator sends `DoReservation` → Reservation Service responds `ReservationDone` → Orchestrator sends `DoPayment` → etc.
- On failure: Orchestrator issues compensating commands in reverse.
- Pros: Clear saga state, easier to monitor and debug, single source of truth.
- Cons: Orchestrator is a new component to build/maintain, can become a bottleneck.

**Saga vs ACID — What you lose:**
- **No Isolation** — other transactions can see intermediate saga state (after step 1 commits but before step 2). This is the biggest problem: dirty reads across services.
- **Countermeasures:** Semantic locks (mark records as "pending"), versioning, pessimistic view (read compensatable data as if it might be rolled back).

**Transactional Outbox Pattern:**

The core problem: after a local transaction, how do you reliably publish an event to a message broker without a distributed transaction? If you write to DB and then publish to Kafka, the DB write might succeed but Kafka publish might fail.

**Solution:** Write the event to an `outbox` table in the SAME local database transaction as your business data. A separate process (poller or CDC — Change Data Capture) reads the outbox and publishes to the message broker. Since the outbox write and business data write are in the same local ACID transaction, they are atomic.

**CDC-based approach (preferred):**
Use Debezium to capture changes from the outbox table via database transaction logs (WAL/binlog). This avoids polling and achieves near-real-time publishing with no additional DB load.

**At-Least-Once + Idempotency:**

Since distributed systems guarantee at-least-once delivery (messages may be delivered multiple times), consumers must be idempotent:
- Store `message_id` in a `processed_messages` table.
- On receipt: check if already processed → skip if yes → process and record if no.
- Use `INSERT ... ON CONFLICT DO NOTHING` or equivalent.
- Natural idempotency: upserts (INSERT OR REPLACE), conditional updates (`UPDATE ... WHERE version = ?`).

**Real-World Example:**
Uber's trip booking is a textbook Saga:
1. **Create Trip** (Trip Service) — local transaction: trip record in PENDING state.
2. **Reserve Driver** (Driver Service) — local transaction: driver marked as assigned.
3. **Charge Payment** (Payment Service) — local transaction: payment authorized.
4. **Confirm Trip** (Trip Service) — local transaction: trip record set to CONFIRMED.

If Payment fails (step 3):
- Compensation 2: Release driver (Driver Service).
- Compensation 1: Cancel trip (Trip Service) — set to CANCELLED.

The outbox pattern ensures that when Trip Service commits step 1, the `TripCreated` event is atomically written to the outbox table and will be reliably delivered to Driver Service even if the Trip Service crashes immediately after commit.

**Code Example:**
```java
// === ORCHESTRATION-BASED SAGA ===

// Saga Orchestrator using Spring State Machine or simple state tracking
@Service
@Transactional
public class OrderSagaOrchestrator {

    private final InventoryService inventoryService;
    private final PaymentService paymentService;
    private final ShippingService shippingService;
    private final SagaRepository sagaRepository;

    public void startOrderSaga(Order order) {
        OrderSagaState sagaState = OrderSagaState.builder()
            .sagaId(UUID.randomUUID().toString())
            .orderId(order.getId())
            .currentStep(SagaStep.RESERVE_INVENTORY)
            .status(SagaStatus.IN_PROGRESS)
            .build();
        sagaRepository.save(sagaState);

        try {
            // Step 1: Reserve inventory
            String inventoryReservationId = inventoryService.reserve(order);
            sagaState.setInventoryReservationId(inventoryReservationId);
            sagaState.setCurrentStep(SagaStep.PROCESS_PAYMENT);
            sagaRepository.save(sagaState);

            // Step 2: Process payment
            String paymentId = paymentService.charge(order);
            sagaState.setPaymentId(paymentId);
            sagaState.setCurrentStep(SagaStep.ARRANGE_SHIPPING);
            sagaRepository.save(sagaState);

            // Step 3: Arrange shipping
            shippingService.schedule(order);
            sagaState.setStatus(SagaStatus.COMPLETED);
            sagaRepository.save(sagaState);

        } catch (PaymentException e) {
            // Compensate step 1: release inventory reservation
            inventoryService.cancelReservation(sagaState.getInventoryReservationId());
            sagaState.setStatus(SagaStatus.FAILED);
            sagaState.setFailureReason(e.getMessage());
            sagaRepository.save(sagaState);
            throw new OrderSagaException("Order saga failed at payment step", e);
        } catch (ShippingException e) {
            // Compensate step 2 and step 1
            paymentService.refund(sagaState.getPaymentId());
            inventoryService.cancelReservation(sagaState.getInventoryReservationId());
            sagaState.setStatus(SagaStatus.FAILED);
            sagaRepository.save(sagaState);
            throw new OrderSagaException("Order saga failed at shipping step", e);
        }
    }
}

// === TRANSACTIONAL OUTBOX PATTERN ===

// 1. Entity: business data + outbox table in same DB
@Entity
@Table(name = "outbox_events")
public class OutboxEvent {
    @Id
    private String eventId;

    @Column(name = "aggregate_type")
    private String aggregateType; // e.g., "Order"

    @Column(name = "aggregate_id")
    private String aggregateId;

    @Column(name = "event_type")
    private String eventType; // e.g., "OrderCreated"

    @Column(name = "payload", columnDefinition = "jsonb")
    private String payload;

    @Column(name = "created_at")
    private Instant createdAt;

    @Column(name = "published")
    private boolean published = false; // used only if not using CDC
}

// 2. Service: writes business data AND outbox event atomically
@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final OutboxEventRepository outboxRepository;

    @Transactional // Single local ACID transaction — no 2PC needed!
    public Order createOrder(CreateOrderRequest req) {
        // Business data write
        Order order = Order.from(req);
        orderRepository.save(order);

        // Outbox event write — SAME transaction, SAME database
        OutboxEvent event = OutboxEvent.builder()
            .eventId(UUID.randomUUID().toString())
            .aggregateType("Order")
            .aggregateId(order.getId())
            .eventType("OrderCreated")
            .payload(JsonUtils.toJson(order))
            .createdAt(Instant.now())
            .build();
        outboxRepository.save(event);

        // If this method throws, BOTH writes roll back (ACID local transaction)
        // The event is only published AFTER this transaction commits
        return order;
    }
}

// 3. CDC with Debezium publishes outbox events to Kafka
// debezium-config.json:
// {
//   "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
//   "transforms": "outbox",
//   "transforms.outbox.type": "io.debezium.transforms.outbox.EventRouter",
//   "transforms.outbox.table.field.event.id": "event_id",
//   "transforms.outbox.route.by.field": "aggregate_type"
// }

// === IDEMPOTENT CONSUMER ===
@Service
public class OrderCreatedConsumer {

    private final ProcessedMessageRepository processedMessages;
    private final InventoryService inventoryService;

    @KafkaListener(topics = "order-events")
    @Transactional
    public void onOrderCreated(OrderCreatedEvent event, 
                                @Header(KafkaHeaders.RECEIVED_MESSAGE_ID) String messageId) {
        // Idempotency check: have we already processed this message?
        if (processedMessages.existsById(messageId)) {
            log.info("Skipping duplicate message: {}", messageId);
            return; // at-least-once: safe to skip duplicate
        }

        // Process the event
        inventoryService.reserve(event.getOrderId(), event.getItems());

        // Record as processed — in same transaction as inventory reservation
        processedMessages.save(new ProcessedMessage(messageId, Instant.now()));
    }
}
```

**Follow-up Questions:**
1. What is the "lost update" problem in Sagas and how do semantic locks prevent it?
2. How would you implement saga recovery after a crash mid-execution? What data do you need to store?
3. What is the difference between CDC (Change Data Capture) and polling for the Outbox pattern, and when would you choose each?

**Common Mistakes:**
- Using Saga for operations that truly require isolation (like "check and reserve last item in stock") — Sagas have no isolation guarantee, so race conditions between concurrent sagas must be handled separately.
- Forgetting to make compensating transactions idempotent — compensations may be retried on failure.
- Not handling the case where a compensating transaction itself fails — you need a dead-letter queue and alerting for saga failure states.

**Interview Traps:**
- "Does Saga give you ACID?" — No. It gives you ACD. Isolation is not guaranteed. Intermediate states are visible.
- "Is Saga better than 2PC?" — It depends. Saga is better for microservices (no distributed locks, no coordinator blocking). 2PC is better when you truly need isolation and operate within an XA-compliant database ecosystem.

**Quick Revision:** Saga = sequence of local transactions + compensating transactions; Outbox = write events atomically to DB alongside business data, publish via CDC; always make consumers idempotent for at-least-once delivery.

---

### Topic 13: Database Replication

**Difficulty:** 4/5 | **Frequency:** 4/5 | **Companies:** Google, Facebook/Meta, Amazon, LinkedIn, Goldman Sachs

**Q:** Explain synchronous vs asynchronous replication, master-slave vs multi-master topologies, replication lag consequences, and how to ensure read-your-writes consistency.

**Short Answer:**
Synchronous replication waits for all replicas to confirm writes before acknowledging the client — zero data loss but higher latency. Asynchronous replication acknowledges the client after the primary write — lower latency but potential data loss on primary failure. Replication lag in async setups causes reads from replicas to return stale data, requiring strategies like sticky routing or read-your-writes tokens to maintain consistency for users.

**Deep Explanation:**

**Synchronous Replication:**
- Primary waits for acknowledgment from at least one (or all) replicas before confirming the write to the client.
- **Pros:** Zero RPO (Recovery Point Objective) — no data loss on failover. Secondary is always up-to-date.
- **Cons:** Write latency increases by at least one network round trip to replica. If any sync replica is slow/unavailable, writes are blocked.
- **Use case:** Financial systems, any system where data loss is unacceptable.
- **Semi-synchronous:** MySQL semi-sync replication — primary waits for at least ONE replica to acknowledge, but not all. Balances durability and performance.

**Asynchronous Replication:**
- Primary confirms the write immediately and replicates in the background.
- **Pros:** Low write latency, primary is not blocked by replica speed.
- **Cons:** Replication lag — replicas may be seconds/minutes behind. If primary crashes before replication, data is lost.
- **Use case:** Read-heavy workloads where slight staleness is acceptable (analytics, reporting, read replicas for scale).

**Replication Topologies:**

**Master-Slave (Primary-Replica):**
- Single primary accepts all writes. Replicas are read-only.
- Simple, well-understood, easy consistency model.
- Failure: Elect a new primary (manual or automatic via Raft/Paxos — e.g., MySQL InnoDB Cluster, PostgreSQL Patroni).
- Write throughput is limited to a single primary node.

**Multi-Master (Active-Active):**
- Multiple nodes accept writes.
- Requires conflict resolution: last-write-wins (LWW), vector clocks, CRDTs (Conflict-free Replicated Data Types), or application-level resolution.
- Examples: MySQL Group Replication, CockroachDB, Cassandra (leaderless), Galera Cluster.
- **Write conflicts:** Two users update the same record on different masters simultaneously → conflict. Resolution strategies vary.
- **Use case:** Geo-distributed systems needing low write latency across regions.

**Leaderless Replication (Dynamo-style):**
- No single primary. Clients write to W out of N replicas and read from R out of N replicas.
- Quorum: W + R > N ensures overlap between write set and read set → consistent reads.
- Example: W=2, R=2, N=3 → W+R=4 > 3. At least one node in every read set has the latest write.
- Anti-entropy: Background process resolves divergence between replicas.

**Replication Lag Consequences:**
1. **Stale reads:** User reads from replica, gets outdated data.
2. **Read-your-writes violation:** User updates profile → reads it back from replica → sees old value → thinks update failed.
3. **Monotonic reads violation:** User makes two reads, second read returns older data than first (if routed to different replicas with different lag).
4. **Causality violations:** User sees reply to a comment before seeing the comment itself.

**Solutions for Replication Lag:**

| Problem | Solution |
|---|---|
| Read-your-writes | Read from primary after own writes; or use replication token (LSN-based routing) |
| Stale reads | Use synchronous replica or read from primary |
| Monotonic reads | Sticky session routing (always route user to same replica) |
| Causality | Consistent prefix reads; causal consistency (vector timestamps) |

**Replication Lag in PostgreSQL** — LSN (Log Sequence Number) based read-your-writes:
- After a write, record the LSN of the written transaction.
- When reading from a replica, check if the replica's applied LSN >= the write's LSN.
- If not, either wait or fall back to primary.

**Real-World Example:**
LinkedIn's article publishing system: when a user publishes an article and immediately views their own profile, they must see their new article. LinkedIn uses a combination of sticky routing (route the article author's reads to the primary for a few seconds after publish) and LSN-based consistency tokens. For other users reading the article, eventual consistency from replicas is acceptable — they can tolerate a few seconds of lag. This two-tier strategy (strong consistency for authors, eventual for readers) is extremely common at scale.

**Code Example:**
```java
// Spring Boot — routing reads based on replication lag / read-your-writes

// 1. AbstractRoutingDataSource for primary/replica routing
import org.springframework.jdbc.datasource.lookup.AbstractRoutingDataSource;

public class ReplicationRoutingDataSource extends AbstractRoutingDataSource {

    private static final ThreadLocal<DataSourceType> contextHolder = new ThreadLocal<>();

    public enum DataSourceType { PRIMARY, REPLICA }

    public static void usePrimary() {
        contextHolder.set(DataSourceType.PRIMARY);
    }

    public static void useReplica() {
        contextHolder.set(DataSourceType.REPLICA);
    }

    public static void clear() {
        contextHolder.remove();
    }

    @Override
    protected Object determineCurrentLookupKey() {
        return contextHolder.get() != null ? contextHolder.get() : DataSourceType.REPLICA;
    }
}

// 2. Annotation-driven routing
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface ReadFromPrimary {}

// 3. AOP aspect to enforce routing
@Aspect
@Component
public class DataSourceRoutingAspect {

    // Methods annotated with @ReadFromPrimary use primary datasource
    @Around("@annotation(ReadFromPrimary)")
    public Object routeToPrimary(ProceedingJoinPoint pjp) throws Throwable {
        try {
            ReplicationRoutingDataSource.usePrimary();
            return pjp.proceed();
        } finally {
            ReplicationRoutingDataSource.clear();
        }
    }

    // @Transactional(readOnly=true) routes to replica by default
    @Around("@annotation(org.springframework.transaction.annotation.Transactional) " +
            "&& @annotation(readOnly)")
    public Object routeToReplica(ProceedingJoinPoint pjp) throws Throwable {
        try {
            ReplicationRoutingDataSource.useReplica();
            return pjp.proceed();
        } finally {
            ReplicationRoutingDataSource.clear();
        }
    }
}

// 4. Service usage
@Service
public class UserService {

    private final UserRepository userRepository;

    // After a user updates their own data, read from primary to ensure consistency
    @Transactional
    public UserProfile updateProfile(String userId, UpdateRequest req) {
        userRepository.update(userId, req);
        return getUserProfileForOwner(userId); // read own write from primary
    }

    // This MUST read from primary to guarantee read-your-writes
    @ReadFromPrimary
    @Transactional(readOnly = true)
    public UserProfile getUserProfileForOwner(String userId) {
        return userRepository.findById(userId).orElseThrow();
    }

    // Other users can read from replica (eventual consistency is fine)
    @Transactional(readOnly = true)  // routes to replica
    public UserProfile getUserProfilePublic(String userId) {
        return userRepository.findById(userId).orElseThrow();
    }
}

// 5. LSN-based read-your-writes (PostgreSQL)
// After writing, capture the WAL LSN; pass to read requests to ensure replica is caught up
@Repository
public class PostgresUserRepository {

    private final JdbcTemplate primaryJdbc;
    private final JdbcTemplate replicaJdbc;

    public String write(User user) {
        primaryJdbc.update("INSERT INTO users VALUES (?, ?)", user.getId(), user.getName());
        // Capture current WAL LSN after write
        return primaryJdbc.queryForObject("SELECT pg_current_wal_lsn()::text", String.class);
    }

    public User readWithLSN(String userId, String requiredLsn) {
        if (requiredLsn != null) {
            // Check if replica has applied up to the required LSN
            String replicaLsn = replicaJdbc.queryForObject(
                "SELECT pg_last_wal_replay_lsn()::text", String.class);
            if (lsnComparator.compare(replicaLsn, requiredLsn) < 0) {
                // Replica is behind — fall back to primary
                return readFromPrimary(userId);
            }
        }
        return readFromReplica(userId);
    }
}
```

**Follow-up Questions:**
1. How does PostgreSQL's synchronous_standby_names configuration work, and how would you tune it for zero RPO?
2. What are CRDTs (Conflict-free Replicated Data Types) and when are they preferable to last-write-wins conflict resolution?
3. How does MySQL Group Replication differ from standard async replication? What consensus protocol does it use?

**Common Mistakes:**
- Sending reads to replicas without accounting for replication lag — particularly dangerous right after a write (read-your-writes violation).
- Using async replication and assuming zero data loss — on primary failure, any writes not yet replicated are lost.
- Not monitoring replication lag in production — replication lag can spike under heavy write load, causing increased stale read rates.

**Interview Traps:**
- "Is a read replica always safe to read from?" — No. For operations that require seeing your own writes (e.g., user checking if their update was saved), always read from primary or use LSN-based routing.
- "Does PostgreSQL streaming replication guarantee zero data loss?" — Only with `synchronous_commit = on` and at least one synchronous standby configured. Default is asynchronous.

**Quick Revision:** Sync replication = zero data loss, higher latency; async = lower latency, possible data loss; read replicas cause stale reads; solve read-your-writes with primary routing or LSN tokens; multi-master needs conflict resolution.

---

### Topic 14: NoSQL Data Modeling

**Difficulty:** 4/5 | **Frequency:** 4/5 | **Companies:** Amazon, Netflix, Facebook/Meta, Uber, Twitter, Airbnb

**Q:** Compare document, key-value, wide-column, and graph NoSQL databases. Explain their data models and when to choose each.

**Short Answer:**
NoSQL databases span four primary models: document stores (MongoDB) for flexible hierarchical data, key-value stores (Redis/DynamoDB) for fast point lookups and caching, wide-column stores (Cassandra/HBase) for write-heavy time-series and append-only data, and graph databases (Neo4j) for highly connected relational data with complex traversal queries. The choice depends on access patterns, not data shape.

**Deep Explanation:**

**1. Document Stores (MongoDB, Couchbase, Firestore):**

**Model:** Data stored as JSON/BSON documents. Documents within a collection can have different schemas. Supports nested objects and arrays.

**Access Pattern:** Retrieve entire document by ID or query by any field. Supports rich queries, aggregation pipelines, text search.

**Strengths:**
- Flexible schema — fields can be added without migrations.
- Matches application object model naturally (less impedance mismatch).
- Embedded documents reduce joins (denormalization built-in).
- Good for polymorphic data (different product types with different fields).

**Weaknesses:**
- Poor for highly relational data (many-to-many relationships require multiple queries or $lookup aggregations).
- No multi-document ACID by default (MongoDB added multi-document transactions in v4.0 but they are slower).
- Schema flexibility can lead to data inconsistency over time.

**Use cases:** Product catalogs, user profiles, content management systems, event logs, real-time analytics.

**Key design principle:** Embed what you read together; reference what you read separately. Embedding = denormalization = faster reads, slower writes. References = normalization = slower reads (requires multiple queries), smaller documents.

**2. Key-Value Stores (Redis, DynamoDB, Memcached, Riak):**

**Model:** Simple map of key → value. Values are opaque (Redis supports richer types: strings, hashes, lists, sets, sorted sets, bitmaps, HyperLogLog, streams, geospatial).

**Access Pattern:** Point lookups by key (O(1)). Range scans by sort key in DynamoDB.

**Strengths:**
- Extremely fast (Redis: sub-millisecond latency in memory).
- Simple and predictable performance.
- Scales horizontally easily.
- Redis supports pub/sub, streams, Lua scripting.
- DynamoDB supports conditional writes, TTL, streams.

**Weaknesses:**
- No query by value (without a secondary index).
- Redis: data size limited by RAM (unless using Redis Cluster or tiered storage).
- Not suitable for complex relational queries.

**Use cases:**
- Caching (most common use of Redis).
- Session storage.
- Rate limiting (Redis counters with TTL).
- Real-time leaderboards (Redis sorted sets — O(log N) rank operations).
- Shopping carts (DynamoDB).
- Feature flags / configuration.

**3. Wide-Column Stores (Cassandra, HBase, ScyllaDB, Google Bigtable):**

**Model:** Tables with rows and columns, but different rows can have different columns. Organized as a map of maps: `(partition_key, clustering_key) → column_values`. Data is physically sorted and stored by partition key, then clustering key.

**Access Pattern:** Efficient range scans within a partition. Must design schema around known query patterns (no ad-hoc queries). Partition key determines physical location (sharding).

**Strengths:**
- Massive write throughput (append-only writes to SSTables + memtables → compaction).
- Horizontal scale — data is automatically sharded by partition key.
- Excellent for time-series data (partition by `(user_id, month)`, cluster by `timestamp`).
- Tunable consistency.
- Cassandra: no single point of failure (masterless).

**Weaknesses:**
- Must know access patterns upfront — schema is designed for queries, not entities.
- No joins, no aggregations (must be done at application layer or with Spark).
- Wide partitions can cause hot spots and GC pressure.
- Cassandra: no referential integrity, no foreign keys.

**Use cases:** Time-series data (IoT sensor readings, metrics), activity feeds, messaging (WhatsApp uses HBase), audit logs, write-heavy workloads.

**Cassandra Primary Key Design:** `PRIMARY KEY ((partition_key), clustering_col1, clustering_col2)` — partition key determines shard; clustering columns determine row ordering within the partition.

**4. Graph Databases (Neo4j, Amazon Neptune, JanusGraph, TigerGraph):**

**Model:** Nodes (entities) and Edges (relationships), both with properties. Relationships are first-class citizens, stored as direct pointers.

**Access Pattern:** Graph traversals — "find all friends of friends who like Jazz within 3 hops." O(1) per hop (pointer chasing) vs. SQL JOIN which requires full table scans.

**Strengths:**
- Queries that require traversing many levels of relationships are natural and performant.
- Relationship semantics are explicit (typed, directed, with properties).
- Cypher query language (Neo4j) is intuitive for graph patterns.
- No JOIN performance degradation as data grows (joins in SQL scan relationship tables; graph traversals follow pointers).

**Weaknesses:**
- Poor for non-graph queries (aggregations, full-table scans).
- Harder to scale horizontally than other NoSQL (graph sharding is a hard problem).
- Niche — smaller ecosystem than document/key-value stores.
- Not suitable as a general-purpose database.

**Use cases:** Social networks (friend-of-friend recommendations), fraud detection (ring fraud patterns), knowledge graphs, recommendation engines, access control (RBAC/ABAC with complex hierarchies), supply chain graphs.

**Real-World Example:**
Netflix uses multiple NoSQL databases for different use cases:
- **Cassandra** for storing viewing history (append-only, time-ordered, massive scale) — partition key = `(user_id, year_month)`, cluster by `watch_timestamp DESC`.
- **Redis** for caching user session data and rate limiting API requests (sub-millisecond key-value lookups).
- **Elasticsearch** for full-text search of titles, descriptions (document model with inverted index).
- **EVCache (Memcached-based)** for CDN metadata caching.

A monolithic MySQL database could not handle Netflix's scale for any of these workloads individually.

**Code Example:**
```java
// === MONGODB — Document Model ===
// Embedded document design: product with variants
// Good: read entire product + variants in one query
// Bad: if you only need variant prices, you fetch the entire document

@Document(collection = "products")
public class Product {
    @Id
    private String id;
    private String name;
    private String category;
    private List<ProductVariant> variants; // embedded — read together

    // Reference (not embed) for reviews — read separately
    // List<String> reviewIds; → separate Reviews collection
}

// MongoTemplate query
@Repository
public class ProductRepository {
    private final MongoTemplate mongoTemplate;

    public List<Product> findByCategory(String category, double maxPrice) {
        Query query = new Query();
        query.addCriteria(Criteria.where("category").is(category)
            .and("variants.price").lte(maxPrice));
        return mongoTemplate.find(query, Product.class);
    }
}

// === REDIS — Key-Value / Sorted Set for Leaderboard ===
@Service
public class LeaderboardService {

    private final StringRedisTemplate redisTemplate;
    private static final String LEADERBOARD_KEY = "game:leaderboard";

    // O(log N) — add/update score
    public void updateScore(String userId, double score) {
        redisTemplate.opsForZSet().add(LEADERBOARD_KEY, userId, score);
    }

    // O(log N + K) — get top K players (descending)
    public Set<ZSetOperations.TypedTuple<String>> getTopPlayers(int topN) {
        return redisTemplate.opsForZSet()
            .reverseRangeWithScores(LEADERBOARD_KEY, 0, topN - 1);
    }

    // O(log N) — get user's rank
    public Long getUserRank(String userId) {
        return redisTemplate.opsForZSet().reverseRank(LEADERBOARD_KEY, userId);
    }
}

// === CASSANDRA — Wide-Column for Time-Series ===
// Schema design: query-driven
// Query: "Get last 100 events for user X in the last month"
// PRIMARY KEY ((user_id, year_month), event_timestamp)
// CLUSTERING ORDER BY (event_timestamp DESC)

@Table("user_activity")
public class UserActivity {
    @PrimaryKeyColumn(name = "user_id", ordinal = 0, type = PrimaryKeyType.PARTITIONED)
    private String userId;

    @PrimaryKeyColumn(name = "year_month", ordinal = 1, type = PrimaryKeyType.PARTITIONED)
    private String yearMonth; // "2024-07" — limits partition size

    @PrimaryKeyColumn(name = "event_timestamp", ordinal = 2,
                      type = PrimaryKeyType.CLUSTERED,
                      ordering = Ordering.DESCENDING)
    private Instant eventTimestamp;

    @Column("event_type")
    private String eventType;

    @Column("payload")
    private String payload;
}

// === NEO4J — Graph for Fraud Detection ===
// Find circular transactions (ring fraud) within 4 hops
// Impossible efficiently in SQL — natural in graph traversal

@Repository
public class FraudDetectionRepository {

    private final Neo4jTemplate neo4jTemplate;

    // Cypher: find accounts connected through transaction rings
    public List<String> detectRingFraud(String accountId) {
        String cypher = """
            MATCH (a:Account {id: $accountId})-[:SENT_TO*2..4]->(a)
            RETURN a.id as suspiciousAccount
            """;
        return neo4jTemplate.findAll(cypher,
            Map.of("accountId", accountId), String.class);
    }

    // Find friends-of-friends for recommendation
    public List<String> recommendConnections(String userId) {
        String cypher = """
            MATCH (u:User {id: $userId})-[:FOLLOWS]->()-[:FOLLOWS]->(rec:User)
            WHERE NOT (u)-[:FOLLOWS]->(rec) AND u <> rec
            RETURN DISTINCT rec.id
            LIMIT 20
            """;
        return neo4jTemplate.findAll(cypher, Map.of("userId", userId), String.class);
    }
}
```

**Follow-up Questions:**
1. When would you choose MongoDB over Cassandra for a high-write use case? What trade-offs are you accepting?
2. How does Cassandra's partition key design affect hot spots, and how would you design the schema for a global chat application?
3. What is a Property Graph model vs an RDF triple store, and when would you choose Neo4j over a triple store like Amazon Neptune (RDF mode)?

**Common Mistakes:**
- Designing Cassandra tables like relational tables and trying to do ad-hoc WHERE clause filtering — Cassandra requires knowing queries upfront to design primary keys correctly.
- Over-embedding in MongoDB — embedding large arrays causes documents to grow over time, exceeding the 16MB BSON limit and causing performance issues.
- Using Redis as a primary database without persistence configured — by default, Redis AOF/RDB persistence must be enabled if durability is needed.

**Interview Traps:**
- "Can MongoDB do joins?" — It can via `$lookup` aggregation stages, but it's slow compared to SQL joins and indicates a schema design problem.
- "Is Cassandra good for OLAP?" — No. Use Cassandra for OLTP write-heavy workloads. For analytics on Cassandra data, use Apache Spark with the Cassandra connector.

**Quick Revision:** Document (MongoDB) = flexible schema, nested data; Key-Value (Redis/DynamoDB) = fast lookups, caching, leaderboards; Wide-column (Cassandra) = time-series, write-heavy, query-driven schema; Graph (Neo4j) = traversal queries, social networks, fraud detection.

---

### Topic 15: SQL vs NoSQL Decision Framework

**Difficulty:** 3/5 | **Frequency:** 5/5 | **Companies:** Amazon, Google, Netflix, Goldman Sachs, Stripe, Airbnb, every SDE2 interview

**Q:** How do you decide between SQL and NoSQL for a new system? Walk through the key decision factors.

**Short Answer:**
The decision between SQL and NoSQL depends on five key factors: consistency requirements (ACID needed?), schema flexibility (will fields change frequently?), query patterns (ad-hoc joins vs. known access patterns), scale requirements (vertical vs. horizontal), and operational complexity tolerance. SQL is the right default for most transactional systems; NoSQL is chosen for specific scale, flexibility, or data-model advantages.

**Deep Explanation:**

**Decision Factor 1: Consistency Requirements**

- **Need strong ACID transactions across multiple entities?** → SQL (PostgreSQL, MySQL).
  - E.g., bank transfer: debit one account, credit another atomically.
  - E.g., inventory management: reserve item and place order atomically.
- **Eventual consistency acceptable?** → NoSQL viable.
  - E.g., social media like counts, user activity feeds.
  - E.g., product recommendation scores.
- **Need distributed transactions?** → Modern SQL (CockroachDB, Google Spanner) or Saga pattern with any database.

**Decision Factor 2: Schema Flexibility**

- **Fixed, well-understood schema with complex relationships?** → SQL.
  - Relational model enforces referential integrity and normalization.
  - Migrations are structured and auditable.
- **Schema evolves rapidly? Polymorphic data? Unknown fields at design time?** → Document NoSQL (MongoDB).
  - E.g., multi-tenant SaaS where each tenant has different custom fields.
  - E.g., product catalog with varied attributes per category.
- **Schema is extremely simple and stable?** → Key-value or wide-column.

**Decision Factor 3: Query Patterns**

- **Complex ad-hoc queries, reporting, analytics with JOINs?** → SQL.
  - SQL's optimizer handles arbitrary queries efficiently.
  - OLAP queries across many tables are natural in SQL.
- **Known, predictable access patterns?** → NoSQL (design schema around queries).
  - "Always fetch by user ID with time range" → Cassandra wide-column.
  - "Always fetch entire user profile" → MongoDB document.
- **Graph traversals?** → Neo4j / graph databases.
- **Full-text search?** → Elasticsearch (document store optimized for inverted index search).

**Decision Factor 4: Scale Requirements**

- **Scale-up (bigger machine) sufficient? < 10TB data, < 100k QPS writes?** → SQL is fine.
  - PostgreSQL handles significant scale with proper indexing and read replicas.
  - MySQL at Airbnb, Stripe, GitHub — scales to hundreds of millions of rows.
- **Need to scale horizontally across many commodity machines?** → NoSQL generally easier.
  - Cassandra: linear scale by adding nodes.
  - DynamoDB: fully managed, infinite scale.
- **Extreme read scale (millions QPS, sub-millisecond)?** → Redis / Memcached in front of any DB.
- **NOTE:** Premature NoSQL adoption is a common mistake. Modern SQL databases scale further than most teams realize.

**Decision Factor 5: Operational Complexity**

- **Small team, startup, tight ops budget?** → Managed SQL (RDS PostgreSQL, PlanetScale, Supabase) — less operational overhead.
- **Can afford specialized expertise?** → NoSQL for specific use cases.
- **Need multi-region active-active with automatic conflict resolution?** → DynamoDB Global Tables, CockroachDB, Cassandra multi-DC.
- **Full managed service required?** → DynamoDB, Firebase, MongoDB Atlas, Cosmos DB.

**The "SQL First" Principle:**
Start with PostgreSQL. It handles: JSON columns (partial NoSQL), full-text search (pg_trgm, tsvector), time-series (TimescaleDB extension), geospatial (PostGIS), graph queries (recursive CTEs), document storage (jsonb), and streaming (logical replication). Add specialized NoSQL databases only when you have a concrete problem PostgreSQL cannot solve at your scale.

**Common Architecture Patterns:**
- **Polyglot persistence:** Different stores for different microservices based on their specific needs.
- **CQRS:** SQL for writes (command side), NoSQL/search index for reads (query side).
- **Cache-Aside:** SQL as source of truth, Redis for hot data.
- **Lambda Architecture:** SQL/OLTP for real-time, NoSQL (HBase/Cassandra) for batch, Elasticsearch for queries.

**Real-World Example:**
Instagram's engineering evolution:
- **2010:** Single PostgreSQL instance (works fine for millions of users).
- **2012:** PostgreSQL sharding + Cassandra for feeds and activity (writes exceeded single PostgreSQL's capacity).
- **2015:** Polyglot — PostgreSQL for user data, Cassandra for activity/feeds, Redis for caching and rate limiting, Elasticsearch for search.
- **2023:** Still PostgreSQL as core — NoSQL added only for specific bottlenecks.

The lesson: SQL scales further than most people think. Add NoSQL surgically, not prematurely.

**Code Example:**
```java
// === DECISION FRAMEWORK IN CODE ===
// Showing PostgreSQL with JSONB for semi-flexible schema
// Avoids premature migration to MongoDB

// PostgreSQL table: users with flexible custom_attributes as JSONB
// CREATE TABLE users (
//   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
//   email VARCHAR(255) UNIQUE NOT NULL,
//   created_at TIMESTAMPTZ DEFAULT NOW(),
//   custom_attributes JSONB DEFAULT '{}'
// );
// CREATE INDEX idx_users_custom_attributes ON users USING GIN (custom_attributes);

@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue
    private UUID id;

    @Column(unique = true, nullable = false)
    private String email;

    // PostgreSQL JSONB column — flexible schema within SQL
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private Map<String, Object> customAttributes;
}

// Spring Data JPA native query for JSONB
@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    // Query inside JSONB column — uses GIN index
    @Query(value = "SELECT * FROM users WHERE custom_attributes @> :attrs::jsonb",
           nativeQuery = true)
    List<User> findByCustomAttributes(@Param("attrs") String attributesJson);
}

// === POLYGLOT PERSISTENCE — Spring Boot ===
@Service
public class ProductSearchService {

    // Source of truth: PostgreSQL (ACID, relational data)
    private final ProductRepository productRepository;

    // Search index: Elasticsearch (full-text, faceted search)
    private final ElasticsearchOperations elasticsearchOps;

    // Cache: Redis (hot products, sub-millisecond reads)
    private final RedisTemplate<String, Product> redisTemplate;

    public Product getProduct(String productId) {
        // L1: Redis cache — fastest
        Product cached = redisTemplate.opsForValue().get("product:" + productId);
        if (cached != null) return cached;

        // L2: PostgreSQL — authoritative data
        Product product = productRepository.findById(productId).orElseThrow();

        // Warm cache (TTL 5 minutes)
        redisTemplate.opsForValue().set("product:" + productId, product,
            Duration.ofMinutes(5));
        return product;
    }

    public SearchResult searchProducts(String query, String category,
                                        double minPrice, double maxPrice) {
        // Elasticsearch handles full-text + facets + filters efficiently
        // This query would be painful in SQL (no full-text ranking, slow for large catalogs)
        NativeQuery searchQuery = NativeQuery.builder()
            .withQuery(q -> q
                .bool(b -> b
                    .must(m -> m.match(mt -> mt.field("name").query(query)))
                    .filter(f -> f.term(t -> t.field("category").value(category)))
                    .filter(f -> f.range(r -> r.field("price")
                        .gte(JsonData.of(minPrice))
                        .lte(JsonData.of(maxPrice))))))
            .build();
        return elasticsearchOps.search(searchQuery, ProductDocument.class);
    }

    // When product is updated: update SQL (source of truth) + invalidate cache + reindex ES
    @Transactional
    public Product updateProduct(String productId, UpdateProductRequest req) {
        // 1. Update source of truth (ACID)
        Product updated = productRepository.save(req.applyTo(productId));

        // 2. Invalidate cache (eventual consistency acceptable for cache)
        redisTemplate.delete("product:" + productId);

        // 3. Reindex in Elasticsearch (async — acceptable delay for search)
        applicationEventPublisher.publishEvent(new ProductUpdatedEvent(updated));

        return updated;
    }
}

// === SQL vs NoSQL Decision Quick Checklist (as code comments) ===
/**
 * Use PostgreSQL/MySQL (SQL) when:
 * - Need ACID transactions across multiple entities
 * - Complex ad-hoc queries and JOINs required
 * - Data has clear relational structure with foreign keys
 * - Team size is small, operational simplicity matters
 * - Not yet proven you've hit SQL scaling limits
 *
 * Use MongoDB (Document NoSQL) when:
 * - Schema changes frequently, polymorphic data
 * - Data is naturally hierarchical (nested objects)
 * - No complex cross-document transactions needed
 * - Rapid prototyping / startup phase
 *
 * Use Cassandra (Wide-Column) when:
 * - Massive write throughput (>100k writes/sec)
 * - Time-series or append-only workload
 * - Query patterns are known and fixed at schema design time
 * - Need multi-region active-active replication
 *
 * Use Redis (Key-Value) when:
 * - Caching hot data (sub-millisecond response required)
 * - Session storage, rate limiting
 * - Real-time leaderboards (sorted sets)
 * - Pub/Sub messaging
 *
 * Use Neo4j (Graph) when:
 * - Queries traverse many levels of relationships
 * - Social network, fraud detection, recommendation engine
 * - Relationships ARE the data, not just foreign keys
 */
```

**Follow-up Questions:**
1. How would you decide between MongoDB and PostgreSQL with JSONB columns for a document-heavy workload?
2. What is NewSQL, and how do databases like CockroachDB or Google Spanner attempt to combine SQL semantics with NoSQL horizontal scale?
3. Describe a system design where you would use at least 3 different database technologies and justify each choice.

**Common Mistakes:**
- Choosing NoSQL because "it scales better" without profiling SQL first — premature optimization.
- Choosing MongoDB because the team knows JavaScript and JSON looks familiar — not a valid technical reason.
- Forgetting that operational complexity of a new database type is a real cost — running Cassandra in production requires significant expertise.

**Interview Traps:**
- "Is SQL always slower than NoSQL?" — Absolutely not. Redis (NoSQL) is faster for point lookups because it's in-memory. But PostgreSQL with proper indexes beats MongoDB for complex queries. They are not directly comparable.
- "Should microservices always use NoSQL?" — No. Each microservice should use the best database for its workload. Many microservices are perfectly well-served by PostgreSQL.

**Quick Revision:** Default to SQL (PostgreSQL) unless you have a concrete reason not to; add NoSQL surgically for specific bottlenecks; polyglot persistence = different DBs for different services/access patterns; never choose NoSQL because of hype.

---

## Cheat Sheet: ACID, CAP, Transactions & Normalization

---

### 1. ACID Properties Quick Reference

| Property | Definition | What Goes Wrong Without It | Mechanism |
|---|---|---|---|
| **Atomicity** | All operations in a transaction succeed or all are rolled back — no partial commits | Partial updates (e.g., money debited but not credited) | Write-Ahead Log (WAL), undo log |
| **Consistency** | Transaction takes DB from one valid state to another; all constraints must hold | Constraint violations (foreign key broken, balance goes negative) | Triggers, constraints, application logic |
| **Isolation** | Concurrent transactions do not see each other's intermediate state | Dirty reads, non-repeatable reads, phantom reads | Locks (pessimistic) or MVCC (optimistic) |
| **Durability** | Committed transactions survive system failures | Lost data after crash | WAL flushed to disk before commit acknowledgment |

---

### 2. Isolation Levels vs Anomalies Matrix

| Isolation Level | Dirty Read | Non-Repeatable Read | Phantom Read | Lost Update | Performance |
|---|---|---|---|---|---|
| **Read Uncommitted** | Possible | Possible | Possible | Possible | Highest |
| **Read Committed** | Prevented | Possible | Possible | Possible | High |
| **Repeatable Read** | Prevented | Prevented | Possible* | Prevented | Medium |
| **Serializable** | Prevented | Prevented | Prevented | Prevented | Lowest |

*MySQL InnoDB's Repeatable Read prevents phantoms using gap locks. PostgreSQL's uses MVCC snapshot — phantoms technically possible but rare.

**Anomaly Definitions:**
- **Dirty Read:** Transaction reads data written by an uncommitted transaction.
- **Non-Repeatable Read:** Transaction reads the same row twice and gets different values (another transaction updated and committed in between).
- **Phantom Read:** Transaction re-executes a range query and gets different rows (another transaction inserted/deleted rows matching the range).
- **Lost Update:** Two transactions read the same value, both modify it, one overwrites the other's change.

**Default Isolation Levels:**
- PostgreSQL: **Read Committed**
- MySQL InnoDB: **Repeatable Read**
- Oracle: **Read Committed**
- SQL Server: **Read Committed**
- Spring `@Transactional`: inherits database default

---

### 3. CAP Theorem Systems Classification

| System | Type | Consistency | Availability | Notes |
|---|---|---|---|---|
| **ZooKeeper** | CP | Strong (linearizable) | Sacrificed during partition | Uses ZAB consensus; minority partition refuses requests |
| **etcd** | CP | Strong (linearizable) | Sacrificed during partition | Raft consensus; Kubernetes backing store |
| **HBase** | CP | Strong | Sacrificed during partition | Built on HDFS + ZooKeeper |
| **Cassandra** | AP (default) | Eventual (tunable) | Always available | Tunable with ConsistencyLevel |
| **CouchDB** | AP | Eventual | Always available | Multi-version, offline-first |
| **DynamoDB** | Tunable PA/EL | Configurable per-request | Always available | PA during partition, EL otherwise (PACELC) |
| **MongoDB** | CP (default) | Strong (primary reads) | Configurable | Can read from secondaries for AP behavior |
| **MySQL (single)** | CA | Strong | Available | Not partition tolerant — not truly distributed |
| **PostgreSQL (single)** | CA | Strong | Available | Not partition tolerant — not truly distributed |
| **Spanner** | CP | External consistency | Near-100% (5 9s SLA) | Uses TrueTime; effectively CP with very high availability |
| **Consul** | CP | Strong | Sacrificed during partition | Used for service mesh, config |

---

### 4. SQL vs NoSQL Comparison Table

| Dimension | SQL (PostgreSQL/MySQL) | Document (MongoDB) | Wide-Column (Cassandra) | Key-Value (Redis) | Graph (Neo4j) |
|---|---|---|---|---|---|
| **Data Model** | Tables, rows, columns | JSON/BSON documents | Rows with dynamic columns | Key → Value | Nodes and Edges |
| **Schema** | Fixed, enforced | Flexible, optional | Semi-fixed (partition/cluster keys fixed) | None | Flexible node/edge properties |
| **Query Language** | SQL (ANSI standard) | MQL / Aggregation Pipeline | CQL (SQL-like, limited) | GET/SET/commands | Cypher |
| **Joins** | Native, efficient | `$lookup` (slow) | None | None | Native traversals |
| **Transactions** | Full ACID | Multi-doc ACID (v4.0+) | LWT (limited), Sagas for multi-partition | MULTI/EXEC (single-node) | ACID (single server) |
| **Scale** | Vertical + read replicas | Horizontal sharding | Linear horizontal | Horizontal (Redis Cluster) | Vertical (sharding is hard) |
| **Write Performance** | Moderate | High | Very high (append-only) | Extremely high (in-memory) | Moderate |
| **Read Performance** | High (with indexes) | High (point lookups) | High (known patterns) | Extremely high | High (traversals) |
| **Consistency** | Strong ACID | Configurable | Tunable (ONE to ALL) | Strong (single-node) | Strong (single-node) |
| **Best For** | Transactional, relational | Flexible schema, hierarchical | Time-series, write-heavy | Caching, sessions, leaderboards | Social graphs, fraud, recommendations |
| **Avoid For** | Massive horizontal write scale | Complex relational queries | Ad-hoc queries, analytics | Large datasets needing durability | Non-graph workloads |
| **Managed Options** | RDS, Cloud SQL, Supabase | MongoDB Atlas, DocumentDB | Keyspaces (AWS), DataStax | ElastiCache, Redis Cloud | Neptune, AuraDB |

---

### 5. Transaction Patterns Quick Reference

| Pattern | Guarantee | Consistency | Isolation | Use When |
|---|---|---|---|---|
| **Local ACID Transaction** | Full ACID | Strong | Full (serializable possible) | Single service, single DB |
| **2PC (XA)** | Atomic across DBs | Strong | Full | Legacy enterprise, XA-compliant DBs |
| **Saga (Choreography)** | ACD (no Isolation) | Eventual | None | Microservices, short workflows |
| **Saga (Orchestration)** | ACD (no Isolation) | Eventual | None | Microservices, complex workflows |
| **Outbox Pattern** | Reliable event delivery | Eventual | N/A | Guaranteeing at-least-once event publishing |
| **Idempotent Consumer** | At-least-once safety | Eventual | N/A | Duplicate message protection |
| **Optimistic Locking** | Lost update prevention | Strong | Partial | Low contention, version conflicts tolerable |
| **Pessimistic Locking** | Lost update prevention | Strong | Full | High contention, correctness critical |

---

### 6. Normalization Forms Quick Reference

| Normal Form | Condition | Violation Example | Fix |
|---|---|---|---|
| **1NF** | Atomic values, no repeating groups | `skills = "Java,Python,Go"` (multi-valued) | Separate `user_skills` table |
| **2NF** | 1NF + no partial dependency (on part of composite key) | `order_item` table with `product_name` depending only on `product_id`, not full PK | Move `product_name` to `products` table |
| **3NF** | 2NF + no transitive dependency (non-key → non-key) | `employees` has `dept_id` and `dept_name` where `dept_name` depends on `dept_id` | Move `dept_name` to `departments` table |
| **BCNF** | Every determinant is a candidate key | Anomaly in multi-valued dependencies not caught by 3NF | Decompose to remove non-trivial functional dependencies |
| **4NF** | BCNF + no multi-valued dependencies | Employee can have multiple skills AND multiple languages independently | Separate into `employee_skills` and `employee_languages` tables |

---

*End of Chapter 16, Part B — ACID, Transactions & Normalization*

*Handbook: Java Backend Interview Preparation | Volume 4: Databases*
*Target: SDE2, FAANG+, Goldman Sachs | Total Topics Covered: 15 (Part A: 1–8, Part B: 9–15)*



