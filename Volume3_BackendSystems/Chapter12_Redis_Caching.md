# Volume 3: Backend Systems
# Chapter 12: Redis & Caching Strategies

---

## Table of Contents
1. Redis Data Structures
2. Caching Strategies
3. Cache Invalidation
4. Eviction Policies
5. Redis vs Memcached
6. Distributed Caching with Spring
7. Redis Distributed Lock
8. Redis Pub/Sub & Streams
9. Redis Persistence
10. Redis Cluster & Replication
11. Cache Warming & Cold Start
12. Session Management with Redis
13. Rate Limiting with Redis
14. Cache Penetration, Avalanche, Breakdown
15. Redis Performance & Monitoring

---

### Topic 1: Redis Data Structures
**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Meta, Stripe, Shopify, Twitter

**Q: Walk me through Redis data structures and when you would choose each one in a production system.**

**Short Answer (2-3 sentences):**
Redis provides eight core data structures: String, Hash, List, Set, Sorted Set, Bitmap, HyperLogLog, and Stream. Each is optimized for specific access patterns — Strings for simple key-value caching, Sorted Sets for leaderboards, Streams for event sourcing. Choosing the wrong structure leads to higher memory usage and O(N) operations where O(1) or O(log N) is possible.

**Deep Explanation:**
- **String**: Binary-safe, up to 512 MB. Supports atomic integer increment (INCR/DECR). Internally uses int encoding for integers, embstr for strings <=44 bytes, and raw for larger. Use for: counters, session tokens, simple cache values, distributed locks (SET NX EX).
- **Hash**: Field-value map stored under one key. Uses ziplist encoding when <=128 fields and each value <=64 bytes; switches to hashtable beyond that. Use for: user profile objects, shopping cart (userId -> {productId: qty}), configuration.
- **List**: Doubly linked list (quicklist -- ziplist chunks). O(1) push/pop from both ends. Use for: message queues (LPUSH + BRPOP), activity feeds, job queues with priority via multiple lists.
- **Set**: Unordered unique collection. O(1) add/remove/check. Supports SUNION, SINTER, SDIFF. Use for: tag systems, friend lists, unique visitors per day, deduplication.
- **Sorted Set (ZSet)**: Members with float scores, sorted by score. Uses ziplist <=128 members, otherwise skiplist + hashtable. O(log N) for adds. Use for: leaderboards, delayed task queues (score = execution timestamp), rate limiting windows.
- **Bitmap**: Bit array on top of String. SETBIT/GETBIT/BITCOUNT. Use for: daily active user tracking (bit per userId), feature flags at scale.
- **HyperLogLog**: Probabilistic cardinality estimation, <=12 KB, +/-0.81% error. PFADD/PFCOUNT. Use for: unique page views, unique search queries -- when exact count is not required.
- **Stream**: Append-only log with consumer groups. XADD/XREAD/XREADGROUP/XACK. Use for: event sourcing, activity streams, audit logs, replacing Kafka for moderate throughput.

**Real-World Example:**
At a food delivery platform: String stores rider location (JSON blob, 30s TTL), Hash stores order details, ZSet stores nearby riders sorted by distance, Bitmap tracks whether a user redeemed a daily coupon, HyperLogLog estimates unique menu views per restaurant, and Stream carries order-state-change events consumed by notification service.

**Code Example:**
```java
// Spring Boot 3.x + spring-data-redis + Lettuce
@Configuration
public class RedisConfig {
    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory factory) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(factory);
        template.setKeySerializer(new StringRedisSerializer());
        template.setValueSerializer(new GenericJackson2JsonRedisSerializer());
        template.setHashKeySerializer(new StringRedisSerializer());
        template.setHashValueSerializer(new GenericJackson2JsonRedisSerializer());
        template.afterPropertiesSet();
        return template;
    }
}

@Service
@RequiredArgsConstructor
public class RedisDataStructureDemo {

    private final RedisTemplate<String, Object> redisTemplate;
    private final StringRedisTemplate stringTemplate;

    // String: atomic counter
    public long incrementPageView(String pageId) {
        return stringTemplate.opsForValue().increment("page:views:" + pageId);
    }

    // Hash: user profile
    public void saveUserProfile(String userId, Map<String, String> profile) {
        redisTemplate.opsForHash().putAll("user:" + userId, profile);
        redisTemplate.expire("user:" + userId, Duration.ofHours(24));
    }

    public Object getUserField(String userId, String field) {
        return redisTemplate.opsForHash().get("user:" + userId, field);
    }

    // List: job queue
    public void enqueueJob(String queueName, String jobPayload) {
        redisTemplate.opsForList().leftPush(queueName, jobPayload);
    }

    public Object dequeueJob(String queueName, Duration timeout) {
        return redisTemplate.opsForList().rightPop(queueName, timeout);
    }

    // Set: unique tags
    public void addTags(String articleId, String... tags) {
        redisTemplate.opsForSet().add("article:tags:" + articleId, (Object[]) tags);
    }

    public Set<Object> commonTags(String articleA, String articleB) {
        return redisTemplate.opsForSet()
            .intersect("article:tags:" + articleA, "article:tags:" + articleB);
    }

    // Sorted Set: leaderboard
    public void updateScore(String leaderboard, String userId, double score) {
        redisTemplate.opsForZSet().add(leaderboard, userId, score);
    }

    public Set<Object> getTopN(String leaderboard, int n) {
        return redisTemplate.opsForZSet().reverseRange(leaderboard, 0, n - 1);
    }

    // Bitmap: daily active users
    public void markActive(String date, long userId) {
        redisTemplate.opsForValue().setBit("dau:" + date, userId, true);
    }

    public Long countActiveUsers(String date) {
        return redisTemplate.execute(
            (RedisCallback<Long>) conn -> conn.bitCount(("dau:" + date).getBytes())
        );
    }

    // HyperLogLog: unique visitors
    public void trackVisitor(String pageId, String visitorId) {
        redisTemplate.opsForHyperLogLog().add("visitors:" + pageId, visitorId);
    }

    public long estimateUniqueVisitors(String pageId) {
        return redisTemplate.opsForHyperLogLog().size("visitors:" + pageId);
    }

    // Stream: event publishing
    public RecordId publishEvent(String streamKey, Map<String, String> eventData) {
        return redisTemplate.opsForStream().add(
            MapRecord.create(streamKey, eventData)
        );
    }
}
```

**Follow-up Questions:**
1. What is the internal encoding switch threshold for a Hash, and what are the memory implications of crossing it?
2. How does Redis implement a Sorted Set internally, and why is a skiplist chosen over a balanced BST?
3. When would you prefer Redis Streams over a List-based queue?

**Common Mistakes:**
- Using String with JSON for objects that need field-level updates -- causes full read-modify-write instead of HSET on one field.
- Storing millions of small keys instead of grouping under a Hash, wasting per-key overhead (~50-70 bytes per key).

**Interview Traps:**
- "HyperLogLog is 100% accurate" -- it is probabilistic (+/-0.81% error); never use for billing or exact counts.
- Assuming List is always the right queue -- for durability and consumer groups, Redis Streams is the correct choice.

**Quick Revision (1-liner):**
Choose the data structure that matches your access pattern: String for atomic scalars, Hash for objects, List for queues, Set for membership, ZSet for ranking, Bitmap for boolean flags at scale, HyperLogLog for cardinality estimates, Stream for durable event logs.

---

### Topic 2: Caching Strategies
**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Meta, Stripe, Netflix, Uber

**Q: Compare cache-aside, write-through, write-behind, and read-through caching strategies. When would you use each?**

**Short Answer (2-3 sentences):**
Cache-aside (lazy loading) puts the application in control: on miss, the app fetches from DB and populates the cache. Write-through keeps cache and DB always in sync by writing both simultaneously. Write-behind improves write throughput by writing to cache first and asynchronously flushing to DB; read-through is like cache-aside but the cache library itself handles the miss logic.

**Deep Explanation:**
**Cache-Aside (Lazy Loading):**
- Flow: Read -> check cache -> miss -> read DB -> populate cache -> return. Write -> update DB -> invalidate/update cache.
- Pros: Only requested data is cached; resilient to cache failure (app reads DB directly).
- Cons: Cache miss penalty (2 round trips); risk of stale data between DB write and cache invalidation; thundering herd on cold start.
- Best for: Read-heavy workloads, irregular access patterns.

**Write-Through:**
- Flow: Write -> update cache -> update DB (synchronously) -> return.
- Pros: Cache always fresh; no stale reads after writes.
- Cons: Write latency doubles (both cache and DB); cache polluted with infrequently read data.
- Best for: Read-heavy workloads where data written is also frequently read (user settings, product catalog).

**Write-Behind (Write-Back):**
- Flow: Write -> update cache -> return -> async batch write to DB.
- Pros: Low write latency; DB batching reduces load.
- Cons: Risk of data loss if cache node fails before flush; complex failure handling; eventual consistency window.
- Best for: High write throughput with acceptable eventual consistency (metrics aggregation, analytics counters).

**Read-Through:**
- Flow: Application only talks to cache; cache transparently loads from DB on miss (via a loader/provider).
- Pros: Cleaner application code; cache is the single source of truth for reads.
- Cons: First-access latency; tightly coupled to cache provider implementation.
- Best for: ORM-level caching (Hibernate L2 cache), Spring Cache abstraction.

**Real-World Example:**
E-commerce product page: cache-aside for product details (infrequent writes, high reads). Shopping cart: write-through (every cart change must be durable). Order metrics dashboard: write-behind (counters aggregated every 5s to DB). User authentication token validation: read-through with 15-minute TTL.

**Code Example:**
```java
// Cache-Aside pattern with Spring Data Redis
@Service
@RequiredArgsConstructor
@Slf4j
public class ProductCacheService {

    private final ProductRepository productRepository;
    private final RedisTemplate<String, Object> redisTemplate;
    private static final Duration TTL = Duration.ofMinutes(30);

    // Cache-Aside: read
    public Product getProduct(String productId) {
        String key = "product:" + productId;
        Product cached = (Product) redisTemplate.opsForValue().get(key);
        if (cached != null) {
            return cached;
        }
        Product product = productRepository.findById(productId)
            .orElseThrow(() -> new ProductNotFoundException(productId));
        redisTemplate.opsForValue().set(key, product, TTL);
        return product;
    }

    // Cache-Aside: write (invalidate)
    public Product updateProduct(String productId, ProductUpdateRequest request) {
        Product updated = productRepository.save(request.toEntity(productId));
        redisTemplate.delete("product:" + productId);
        return updated;
    }

    // Write-Through: write to both cache and DB
    public Product writeThrough(String productId, Product product) {
        Product saved = productRepository.save(product);
        redisTemplate.opsForValue().set("product:" + productId, saved, TTL);
        return saved;
    }
}

// Write-Behind: buffer writes, flush asynchronously
@Service
@RequiredArgsConstructor
public class MetricsWriteBehindService {

    private final RedisTemplate<String, Object> redisTemplate;
    private final MetricsRepository metricsRepository;

    public void recordView(String productId) {
        redisTemplate.opsForValue().increment("metrics:views:" + productId);
    }

    @Scheduled(fixedDelay = 5000)
    public void flushToDB() {
        Set<String> keys = redisTemplate.keys("metrics:views:*");
        if (keys == null || keys.isEmpty()) return;
        keys.forEach(key -> {
            String productId = key.replace("metrics:views:", "");
            Long views = (Long) redisTemplate.opsForValue().getAndDelete(key);
            if (views != null && views > 0) {
                metricsRepository.incrementViews(productId, views);
            }
        });
    }
}
```

**Follow-up Questions:**
1. In cache-aside, what is the race condition between cache invalidation and DB read, and how do you solve it?
2. How does write-behind handle node failure before the async flush completes?
3. When is it acceptable to serve stale data, and how do you implement stale-while-revalidate in Spring?

**Common Mistakes:**
- Invalidating cache before DB write in cache-aside -- creates a window where DB is old but cache is empty, causing reads to re-cache the old value.
- Using write-behind for financial transactions -- the async window can cause data loss on crash.

**Interview Traps:**
- "Write-through guarantees consistency" -- it guarantees cache freshness but not atomic DB+cache consistency; DB remains the source of truth.
- Confusing read-through (cache handles miss) with cache-aside (application handles miss).

**Quick Revision (1-liner):**
Cache-aside = app controls read miss; write-through = sync write to both; write-behind = async DB flush for speed; read-through = cache transparently loads on miss.

---

### Topic 3: Cache Invalidation
**Difficulty:** Hard | **Frequency:** High | **Companies:** Amazon, Google, Meta, Stripe, Airbnb

**Q: What is the cache stampede problem and how do you prevent it? Explain TTL-based and event-driven invalidation.**

**Short Answer (2-3 sentences):**
A cache stampede (thundering herd) occurs when a popular cache entry expires and many concurrent requests simultaneously hit the database to repopulate it, overwhelming the DB. Solutions include probabilistic early expiration, mutex/distributed locking, and background refresh. TTL-based invalidation is simple but causes stampedes; event-driven invalidation (CDC, message queues) provides precise cache freshness.

**Deep Explanation:**
**TTL-Based Invalidation:**
- Every key has a time-to-live; after expiry Redis silently deletes it.
- Redis uses lazy expiration (checks on access) plus active expiration (samples 20 random keys with TTL every 100ms, removes expired ones).
- Problem: At TTL boundary, all cached copies expire simultaneously -- thundering herd.
- Mitigation: Add random jitter to TTL (`base_ttl + random(0, jitter)`).

**Event-Driven Invalidation:**
- Application or CDC (Change Data Capture) publishes invalidation events on data change.
- Cache consumers subscribe and delete/update affected keys.
- Tools: Debezium (MySQL/Postgres CDC) -> Kafka -> cache invalidation service.
- Pros: Near-real-time freshness, no unnecessary evictions.
- Cons: Complex infrastructure; event ordering issues; at-least-once delivery requires idempotent handlers.

**Cache Stampede Solutions:**
1. **Probabilistic Early Expiration (XFetch):** Recompute before actual expiry with probability inversely proportional to remaining TTL. Eliminates stampede at cost of occasional early refresh.
2. **Mutex Lock:** First thread to encounter miss acquires a distributed lock, fetches from DB, populates cache, releases lock. Other threads wait or return stale data.
3. **Background Refresh:** Serve stale while asynchronously refreshing. Keep a shadow TTL shorter than actual TTL; when shadow expires, trigger async refresh.

**Real-World Example:**
A news homepage caches trending articles for 60 seconds. At 9:00 AM with 10,000 concurrent users, all 10,000 hit DB simultaneously when TTL expires. Solution: add TTL jitter +/-10s (reduces burst), plus background refresh triggered at 50s (serves stale for 10s max).

**Code Example:**
```java
@Service
@RequiredArgsConstructor
@Slf4j
public class StampedeProtectedCacheService {

    private final RedisTemplate<String, Object> redisTemplate;
    private final ArticleRepository articleRepository;
    private static final long BASE_TTL_SECONDS = 60;
    private static final long LOCK_TIMEOUT_MS = 5000;
    private final Random random = new SecureRandom();

    // Approach 1: TTL with random jitter
    public void cacheWithJitter(String key, Object value) {
        long jitter = (long) (random.nextDouble() * 20); // 0-20s jitter
        redisTemplate.opsForValue().set(key, value,
            Duration.ofSeconds(BASE_TTL_SECONDS + jitter));
    }

    // Approach 2: Mutex lock to prevent stampede
    public Article getArticleWithLock(String articleId) {
        String cacheKey = "article:" + articleId;
        String lockKey = "lock:article:" + articleId;

        Article cached = (Article) redisTemplate.opsForValue().get(cacheKey);
        if (cached != null) return cached;

        Boolean lockAcquired = redisTemplate.opsForValue()
            .setIfAbsent(lockKey, "1", Duration.ofMillis(LOCK_TIMEOUT_MS));

        if (Boolean.TRUE.equals(lockAcquired)) {
            try {
                // Double-check after lock acquisition
                cached = (Article) redisTemplate.opsForValue().get(cacheKey);
                if (cached != null) return cached;

                Article article = articleRepository.findById(articleId)
                    .orElseThrow(() -> new ArticleNotFoundException(articleId));
                cacheWithJitter(cacheKey, article);
                return article;
            } finally {
                redisTemplate.delete(lockKey);
            }
        } else {
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            cached = (Article) redisTemplate.opsForValue().get(cacheKey);
            if (cached != null) return cached;
            return articleRepository.findById(articleId)
                .orElseThrow(() -> new ArticleNotFoundException(articleId));
        }
    }

    // Approach 3: Background refresh with shadow TTL
    public void cacheWithShadowTTL(String key, Object value) {
        long softExpiry = System.currentTimeMillis() + (BASE_TTL_SECONDS - 10) * 1000;
        CacheEntry entry = new CacheEntry(value, softExpiry);
        redisTemplate.opsForValue().set(key, entry, Duration.ofSeconds(BASE_TTL_SECONDS + 30));
    }

    public Object getWithShadowTTL(String key, Supplier<Object> loader,
                                    ExecutorService refreshExecutor) {
        CacheEntry entry = (CacheEntry) redisTemplate.opsForValue().get(key);
        if (entry == null) {
            Object fresh = loader.get();
            cacheWithShadowTTL(key, fresh);
            return fresh;
        }
        if (System.currentTimeMillis() > entry.getSoftExpiry()) {
            refreshExecutor.submit(() -> {
                Object fresh = loader.get();
                cacheWithShadowTTL(key, fresh);
            });
        }
        return entry.getValue();
    }
}

@Data
@AllArgsConstructor
@NoArgsConstructor
class CacheEntry implements Serializable {
    private Object value;
    private long softExpiry;
}
```

**Follow-up Questions:**
1. How does Redis active expiration work, and at what rate does it scan for expired keys?
2. What guarantees does event-driven invalidation provide, and what happens if an invalidation event is dropped?
3. How do you implement stale-while-revalidate semantics in Spring Cache?

**Common Mistakes:**
- Setting the same TTL for all keys -- causes synchronized expiry waves; always add jitter.
- Not handling the case where the lock holder crashes -- the lock TTL must be set to prevent deadlock.

**Interview Traps:**
- "TTL-based invalidation is always sufficient" -- not for data requiring strong consistency (inventory, pricing).
- Assuming distributed lock completely eliminates stampede -- if lock TTL is too short, the lock holder may expire before populating the cache.

**Quick Revision (1-liner):**
Cache stampede = mass simultaneous DB reads on TTL expiry; prevent with jitter TTL, mutex lock, or background refresh; event-driven invalidation eliminates TTL guesswork.

---

### Topic 4: Eviction Policies
**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Meta, Netflix, Stripe

**Q: Explain Redis eviction policies. How do you choose the right one, and what happens when maxmemory is reached?**

**Short Answer (2-3 sentences):**
When Redis reaches maxmemory, it applies an eviction policy to free space. The eight policies differ in which keys they consider (all keys vs. only keys with TTL) and how they select the victim (LRU, LFU, random, TTL). Choosing the wrong policy can cause unexpected eviction of critical non-expiring keys or poor cache hit rates.

**Deep Explanation:**
Redis eviction policies (set via `maxmemory-policy`):

| Policy | Pool | Algorithm |
|--------|------|-----------|
| noeviction | -- | Return error on write when full |
| allkeys-lru | All keys | Approximate LRU |
| volatile-lru | Keys with TTL | Approximate LRU |
| allkeys-lfu | All keys | Approximate LFU (Redis 4+) |
| volatile-lfu | Keys with TTL | Approximate LFU |
| allkeys-random | All keys | Random |
| volatile-random | Keys with TTL | Random |
| volatile-ttl | Keys with TTL | Evict soonest-to-expire first |

**LRU vs LFU:**
- **LRU (Least Recently Used):** Evicts the key not accessed for the longest time. Good for temporal locality. Approximated in Redis using a random sample of `maxmemory-samples` (default 5) keys.
- **LFU (Least Frequently Used):** Evicts the key accessed least often. Uses a Morris counter (probabilistic frequency counter per key) with decay. Better for workloads where some keys are always popular (Zipfian distribution).

**allkeys vs volatile:**
- `allkeys-*`: Evicts from any key. Used when all data is reconstructable from DB (pure cache).
- `volatile-*`: Only evicts keys with TTL set. Used when some keys are critical and must not be evicted (set them without TTL).

**Choosing the right policy:**
- Pure cache (all data in DB): `allkeys-lru` or `allkeys-lfu`.
- Mixed cache + persistent data: `volatile-lru` (persistent keys have no TTL, will not be evicted).
- Session store: `volatile-lru` (sessions have TTL; non-session keys safe).
- Frequency-skewed access: `allkeys-lfu` outperforms lru.

**Real-World Example:**
A CDN edge cache using `allkeys-lru` works well for trending content. A game leaderboard stored in Redis alongside session data should use `volatile-lru` so the leaderboard ZSet (no TTL) is never evicted while expired sessions are cleaned up.

**Code Example:**
```java
@Component
@RequiredArgsConstructor
@Slf4j
public class RedisEvictionMonitor {

    private final RedisTemplate<String, Object> redisTemplate;

    @Scheduled(fixedRate = 60000)
    public void logEvictionStats() {
        Properties info = redisTemplate.execute(
            (RedisCallback<Properties>) connection -> connection.serverCommands().info("stats")
        );
        if (info != null) {
            String evictedKeys = info.getProperty("evicted_keys");
            String usedMemory = info.getProperty("used_memory_human");
            long hits = Long.parseLong(info.getProperty("keyspace_hits", "0"));
            long misses = Long.parseLong(info.getProperty("keyspace_misses", "0"));
            long total = hits + misses;
            String hitRate = total > 0
                ? String.format("%.2f%%", (double) hits / total * 100) : "N/A";

            log.info("Redis stats -- evicted_keys={}, used_memory={}, hit_rate={}",
                evictedKeys, usedMemory, hitRate);

            long evicted = Long.parseLong(evictedKeys != null ? evictedKeys : "0");
            if (evicted > 1000) {
                log.warn("High eviction rate -- consider increasing maxmemory");
            }
        }
    }

    // Set critical keys without TTL so volatile-* policies skip them
    public void setCriticalKey(String key, Object value) {
        redisTemplate.opsForValue().set(key, value);
    }

    // Set cache keys with TTL -- eligible for volatile-* eviction
    public void setCacheKey(String key, Object value, Duration ttl) {
        redisTemplate.opsForValue().set(key, value, ttl);
    }
}
```

```
# redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lfu
maxmemory-samples 10
lfu-log-factor 10
lfu-decay-time 1
```

**Follow-up Questions:**
1. How does Redis approximate LRU rather than implementing exact LRU, and what are the trade-offs?
2. What is the LFU Morris counter, and how does it track frequency in O(1) space?
3. How does `noeviction` behave, and when is it the right choice?

**Common Mistakes:**
- Using `allkeys-lru` when Redis holds both cache and persistent data -- critical non-expiring keys can be evicted.
- Setting `maxmemory` too close to available RAM -- Redis memory spikes during fork (RDB/AOF rewrite) due to copy-on-write.

**Interview Traps:**
- "LRU is always better than LFU" -- for access patterns with always-hot keys, LFU dramatically outperforms LRU.
- Assuming `maxmemory-samples=5` is optimal -- increasing to 10 gives near-perfect LRU at marginal CPU cost.

**Quick Revision (1-liner):**
Use `allkeys-lfu` for pure caches with hot-key patterns, `volatile-lru` when mixing cached and persistent data, and always set maxmemory to ~70% of available RAM.

---

### Topic 5: Redis vs Memcached
**Difficulty:** Easy | **Frequency:** Medium | **Companies:** Amazon, Google, Twitter, Shopify

**Q: When would you choose Redis over Memcached, and what are the fundamental architectural differences?**

**Short Answer (2-3 sentences):**
Redis supports rich data structures, persistence, replication, Lua scripting, pub/sub, and clustering, while Memcached is a simpler, multithreaded, pure cache with no persistence. Memcached can be faster for simple string get/set under extreme concurrency due to its multithreaded architecture. Choose Redis for almost all modern use cases; choose Memcached only when you need raw throughput for simple key-value caching and have very large slab allocations.

**Deep Explanation:**
| Feature | Redis | Memcached |
|---------|-------|-----------|
| Data structures | String, Hash, List, Set, ZSet, Bitmap, HLL, Stream | String only |
| Persistence | RDB + AOF | None |
| Replication | Master-replica + Sentinel + Cluster | Third-party only |
| Threading | Single-threaded event loop (I/O threads in Redis 6+) | Multithreaded |
| Max value size | 512 MB | 1 MB |
| Pub/Sub | Yes | No |
| Transactions | MULTI/EXEC | No |
| Lua scripting | Yes | No |
| Cluster | Built-in Redis Cluster | Third-party (Mcrouter) |
| Atomic operations | INCR, SETNX, GETSET, etc. | CAS only |

**Why Redis wins in practice:**
- Persistence means cache survives restart -- critical for warm cache on deploys.
- Cluster built-in vs. Mcrouter proxy for Memcached.
- Rich data structures eliminate the need to serialize/deserialize complex structures.
- Pub/Sub and Streams enable additional use cases on the same infrastructure.

**When Memcached is legitimate:**
- Pure string get/set at extremely high concurrency where multithreaded CPU utilization matters.
- Budget constraints -- Memcached uses memory more efficiently for simple string workloads.

**Real-World Example:**
Facebook originally used Memcached at massive scale but built heavy custom tooling. Most modern startups and mid-sized companies (Stripe, Shopify) default to Redis due to its versatility.

**Code Example:**
```java
@Configuration
@EnableCaching
public class CacheConfig {

    // Redis CacheManager for distributed caching
    @Bean
    @Profile("prod")
    public CacheManager redisCacheManager(RedisConnectionFactory factory) {
        RedisCacheConfiguration config = RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(10))
            .serializeKeysWith(
                RedisSerializationContext.SerializationPair
                    .fromSerializer(new StringRedisSerializer()))
            .serializeValuesWith(
                RedisSerializationContext.SerializationPair
                    .fromSerializer(new GenericJackson2JsonRedisSerializer()))
            .disableCachingNullValues();

        Map<String, RedisCacheConfiguration> cacheConfigs = new HashMap<>();
        cacheConfigs.put("products", config.entryTtl(Duration.ofMinutes(30)));
        cacheConfigs.put("users", config.entryTtl(Duration.ofMinutes(15)));
        cacheConfigs.put("sessions", config.entryTtl(Duration.ofHours(1)));

        return RedisCacheManager.builder(factory)
            .cacheDefaults(config)
            .withInitialCacheConfigurations(cacheConfigs)
            .build();
    }

    // Caffeine CacheManager for local dev / single-node
    @Bean
    @Profile("dev")
    public CacheManager caffeineCacheManager() {
        CaffeineCacheManager manager = new CaffeineCacheManager();
        manager.setCaffeine(Caffeine.newBuilder()
            .maximumSize(1000)
            .expireAfterWrite(Duration.ofMinutes(10))
            .recordStats());
        return manager;
    }
}
```

**Follow-up Questions:**
1. How does Redis single-threaded model avoid race conditions without locks?
2. What is Redis 6.0 I/O threading, and does it change the single-threaded guarantee?
3. How would you migrate from Memcached to Redis with zero downtime?

**Common Mistakes:**
- Starting with Memcached for "simplicity" then needing to migrate when pub/sub or persistence is required.
- Assuming Redis 6+ multithreaded I/O means command processing is now multithreaded -- only I/O is threaded; command execution remains single-threaded.

**Interview Traps:**
- "Redis is always slower than Memcached" -- for complex operations Redis avoids serialization overhead; for raw simple-string throughput Memcached can be marginally faster.
- "Memcached has no clustering" -- it has client-side sharding and Mcrouter, not native clustering.

**Quick Revision (1-liner):**
Choose Redis for virtually all new systems; Memcached only makes sense for ultra-high-throughput pure string caches where persistence and rich data structures are not needed.

---

### Topic 6: Distributed Caching with Spring
**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Stripe, Netflix, Shopify

**Q: How does Spring Cache abstraction work with Redis? Explain @Cacheable, @CacheEvict, @CachePut with real examples.**

**Short Answer (2-3 sentences):**
Spring Cache provides declarative caching via annotations: `@Cacheable` returns the cached value or invokes the method and caches the result, `@CacheEvict` removes entries, and `@CachePut` always executes the method and updates the cache. The `CacheManager` bean determines the underlying store -- swap between Redis, Caffeine, or Ehcache without changing business logic. Custom key expressions use Spring SpEL.

**Deep Explanation:**
**@Cacheable:**
- Intercepts method calls; checks cache for the key; returns cached value on hit; on miss, invokes method, stores result, returns it.
- Key: `#id`, `#root.method.name + ':' + #id`, composite `#p0 + ':' + #p1`.
- `condition`: Only cache if expression is true (e.g., `condition="#id > 0"`).
- `unless`: Cache by default unless expression is true (e.g., `unless="#result == null"`).
- `sync = true`: Only one thread computes on cache miss; others wait (prevents stampede within JVM).

**@CacheEvict:**
- `allEntries = true`: Clears entire named cache.
- `beforeInvocation = true`: Evicts before method runs -- safe even if method throws.
- Default (`beforeInvocation = false`): Evicts only on successful return.

**@CachePut:**
- Always executes the method (unlike @Cacheable which short-circuits on hit).
- Use for write operations: after saving to DB, put fresh value into cache.

**@Caching:**
- Combine multiple cache operations on one method.

**Real-World Example:**
Product catalog service: `@Cacheable` on `getProduct`, `@CacheEvict` on `deleteProduct`, `@CachePut` on `updateProduct`. Cache name "products", TTL 30 minutes.

**Code Example:**
```java
// Dependencies: spring-boot-starter-data-redis, spring-boot-starter-cache

@Configuration
@EnableCaching
public class RedisCacheConfig {

    @Bean
    public RedisCacheManagerBuilderCustomizer redisCacheManagerBuilderCustomizer() {
        return builder -> builder
            .withCacheConfiguration("products",
                RedisCacheConfiguration.defaultCacheConfig()
                    .entryTtl(Duration.ofMinutes(30))
                    .serializeValuesWith(RedisSerializationContext.SerializationPair
                        .fromSerializer(new GenericJackson2JsonRedisSerializer())))
            .withCacheConfiguration("users",
                RedisCacheConfiguration.defaultCacheConfig()
                    .entryTtl(Duration.ofMinutes(15))
                    .serializeValuesWith(RedisSerializationContext.SerializationPair
                        .fromSerializer(new GenericJackson2JsonRedisSerializer())));
    }
}

@Service
@CacheConfig(cacheNames = "products")
@RequiredArgsConstructor
public class ProductService {

    private final ProductRepository productRepository;

    @Cacheable(key = "#productId", unless = "#result == null")
    public Product getProduct(String productId) {
        return productRepository.findById(productId).orElse(null);
    }

    @Cacheable(key = "#category + ':' + #page + ':' + #size")
    public Page<Product> getProductsByCategory(String category, int page, int size) {
        return productRepository.findByCategory(category, PageRequest.of(page, size));
    }

    @CachePut(key = "#product.id")
    public Product updateProduct(Product product) {
        return productRepository.save(product);
    }

    @CacheEvict(key = "#productId")
    public void deleteProduct(String productId) {
        productRepository.deleteById(productId);
    }

    @CacheEvict(allEntries = true)
    public void clearProductCache() {
        // triggers eviction only
    }

    @Caching(
        put = @CachePut(cacheNames = "products", key = "#result.id"),
        evict = @CacheEvict(cacheNames = "search-index", allEntries = true)
    )
    public Product createProduct(ProductCreateRequest request) {
        return productRepository.save(request.toEntity());
    }

    @Cacheable(key = "#productId", condition = "#productId.startsWith('premium-')")
    public Product getPremiumProduct(String productId) {
        return productRepository.findById(productId).orElseThrow();
    }

    // sync=true prevents JVM-level thundering herd
    @Cacheable(key = "#productId", sync = true)
    public Product getProductSync(String productId) {
        return productRepository.findById(productId).orElseThrow();
    }
}

@Component("productKeyGenerator")
public class ProductKeyGenerator implements KeyGenerator {
    @Override
    public Object generate(Object target, Method method, Object... params) {
        return target.getClass().getSimpleName() + ":"
            + method.getName() + ":"
            + Arrays.stream(params).map(Object::toString).collect(Collectors.joining(":"));
    }
}
```

**Follow-up Questions:**
1. How does `@Cacheable(sync=true)` prevent thundering herd, and what are its limitations in a multi-node deployment?
2. What happens if the Redis connection is down -- does `@Cacheable` fail or fall through to the method?
3. How do you cache a method that returns a `Page<T>` or a reactive `Mono<T>`?

**Common Mistakes:**
- Putting `@Cacheable` on private methods or methods in the same class -- Spring AOP proxy won't intercept them (self-invocation problem).
- Not configuring serialization -- default Java serialization is fragile across deployments; always use Jackson (GenericJackson2JsonRedisSerializer).

**Interview Traps:**
- "Spring Cache is distributed by default" -- without a distributed CacheManager (RedisCacheManager), Spring uses in-memory cache (ConcurrentHashMap), not shared across nodes.
- Using `@CachePut` and `@Cacheable` on the same method -- `@CachePut` always runs the method; `@Cacheable` skips it on hit; they serve different purposes.

**Quick Revision (1-liner):**
`@Cacheable` = read-through cache; `@CachePut` = write-through cache; `@CacheEvict` = invalidate; all backed by `CacheManager` pointing to Redis via `RedisCacheManager`.

---

### Topic 7: Redis Distributed Lock
**Difficulty:** Hard | **Frequency:** High | **Companies:** Amazon, Stripe, Google, Uber, Twitter

**Q: How do you implement a distributed lock with Redis? Explain SETNX+EXPIRE, the Redlock algorithm, and Redisson.**

**Short Answer (2-3 sentences):**
A basic Redis distributed lock uses `SET key value NX PX ttl` -- atomic set-if-not-exists with expiry -- ensuring only one process holds the lock. The Redlock algorithm extends this to N independent Redis instances for stronger guarantees. Redisson is a Java client that implements Redlock and provides `RLock` with correct lease renewal and fencing tokens.

**Deep Explanation:**
**Basic Lock (Single Redis):**
```
SET lock:resource_id <unique_token> NX PX 30000
```
- `NX`: Only set if key does not exist.
- `PX 30000`: Auto-expire in 30 seconds (prevents deadlock if holder crashes).
- Value must be a unique token (UUID) -- prevents one process from releasing another's lock.
- Release: Lua script to check-and-delete atomically.
- Problem: If Redis is restarted or has a replica failover, a second process can acquire the same lock.

**Redlock Algorithm:**
1. Get current timestamp t1.
2. Try to acquire lock on N/2+1 independent Redis instances with same key and token, short timeout.
3. Lock is acquired if majority succeeded AND `elapsed = t1 - t2 < TTL - clock_drift`.
4. Validity time = `TTL - elapsed - clock_drift`.
5. Release: Send release command to all instances.
- Problem (Kleppmann): Clock skew, process pauses (GC), network delays can violate safety. Use fencing tokens for true safety.

**Redisson (recommended for production):**
- `RLock.lock()` acquires with watchdog that renews TTL while lock holder is alive.
- `RLock.tryLock(waitTime, leaseTime, unit)` with explicit lease.
- Supports fair locks, read-write locks, multi-lock.

**Real-World Example:**
Preventing double payment processing: before charging a card, acquire a lock on `lock:payment:orderId`. If lock cannot be acquired, the order is already being processed -- return 409 Conflict.

**Code Example:**
```java
// Dependency: org.redisson:redisson-spring-boot-starter:3.24.0

@Configuration
public class RedissonConfig {
    @Bean
    public RedissonClient redissonClient() {
        Config config = new Config();
        config.useSingleServer()
            .setAddress("redis://localhost:6379")
            .setConnectionPoolSize(10)
            .setConnectionMinimumIdleSize(5);
        return Redisson.create(config);
    }
}

@Service
@RequiredArgsConstructor
@Slf4j
public class DistributedLockService {

    private final RedissonClient redissonClient;
    private final PaymentRepository paymentRepository;

    public PaymentResult processPayment(String orderId, PaymentRequest request) {
        RLock lock = redissonClient.getLock("lock:payment:" + orderId);
        try {
            boolean acquired = lock.tryLock(5, 30, TimeUnit.SECONDS);
            if (!acquired) {
                throw new ConcurrentPaymentException(
                    "Payment already in progress for order: " + orderId);
            }
            try {
                if (paymentRepository.existsByOrderId(orderId)) {
                    return PaymentResult.alreadyProcessed();
                }
                return paymentRepository.processPayment(orderId, request);
            } finally {
                lock.unlock();
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new LockInterruptedException(
                "Interrupted while acquiring lock for order: " + orderId);
        }
    }

    // Manual Redis lock (for understanding internals)
    private static final String RELEASE_LOCK_SCRIPT =
        "if redis.call('get', KEYS[1]) == ARGV[1] then " +
        "  return redis.call('del', KEYS[1]) " +
        "else " +
        "  return 0 " +
        "end";

    public <T> T withManualLock(RedisTemplate<String, String> redisTemplate,
                                 String lockKey, Duration ttl, Supplier<T> action) {
        String token = UUID.randomUUID().toString();
        Boolean acquired = redisTemplate.opsForValue()
            .setIfAbsent(lockKey, token, ttl);
        if (!Boolean.TRUE.equals(acquired)) {
            throw new LockNotAcquiredException("Could not acquire lock: " + lockKey);
        }
        try {
            return action.get();
        } finally {
            DefaultRedisScript<Long> script =
                new DefaultRedisScript<>(RELEASE_LOCK_SCRIPT, Long.class);
            redisTemplate.execute(script, Collections.singletonList(lockKey), token);
        }
    }

    // Read-Write lock: multiple readers, exclusive writer
    public Product getProductWithReadLock(String productId) {
        RReadWriteLock rwLock =
            redissonClient.getReadWriteLock("rwlock:product:" + productId);
        RLock readLock = rwLock.readLock();
        readLock.lock();
        try {
            return loadProduct(productId);
        } finally {
            readLock.unlock();
        }
    }

    public Product updateProductWithWriteLock(String productId, Product product) {
        RReadWriteLock rwLock =
            redissonClient.getReadWriteLock("rwlock:product:" + productId);
        RLock writeLock = rwLock.writeLock();
        writeLock.lock();
        try {
            return saveProduct(product);
        } finally {
            writeLock.unlock();
        }
    }

    private Product loadProduct(String productId) { return new Product(); }
    private Product saveProduct(Product product) { return product; }
}
```

**Follow-up Questions:**
1. What is the "fencing token" problem with Redlock, and how does it undermine Redlock's safety guarantees?
2. How does Redisson's watchdog mechanism prevent lock expiry under long-running operations?
3. What happens if the lock holder process is paused for GC longer than the lock TTL?

**Common Mistakes:**
- `SET key value NX` without `PX/EX` -- the key never expires, causing permanent deadlock if the holder crashes.
- Releasing the lock without checking the token -- process A could release process B's lock if A's TTL expired and B re-acquired.

**Interview Traps:**
- "Redlock is safe for all distributed locking scenarios" -- Kleppmann argues it is not safe under clock skew and GC pauses without fencing tokens; use ZooKeeper or etcd for strict safety.
- Assuming `lock.unlock()` is always safe in finally -- if the lock expired (TTL elapsed), Redisson throws `IllegalMonitorStateException`.

**Quick Revision (1-liner):**
Use `SET key token NX PX ttl` + Lua script release for basic locks; use Redisson `RLock` with watchdog for production; apply fencing tokens when absolute safety is required.

---

### Topic 8: Redis Pub/Sub & Streams
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Stripe, Twitter, Shopify, Netflix

**Q: Compare Redis Pub/Sub with Redis Streams. When should you use each, and how do consumer groups work in Streams?**

**Short Answer (2-3 sentences):**
Redis Pub/Sub is a fire-and-forget broadcast -- messages are delivered only to currently subscribed clients and are not persisted. Redis Streams is an append-only log with consumer groups, message acknowledgment, and replay capability, similar to a lightweight Kafka. Use Pub/Sub for real-time notifications where message loss is acceptable; use Streams for reliable event processing.

**Deep Explanation:**
**Pub/Sub:**
- Publishers: `PUBLISH channel message`.
- Subscribers: `SUBSCRIBE channel` or `PSUBSCRIBE pattern`.
- Messages: not persisted; if subscriber is offline, message is lost.
- Fan-out: all subscribers on a channel receive every message.
- No consumer groups, no ACK, no replay.
- Use cases: live notifications, presence updates, cache invalidation broadcast.
- Limitation: No back-pressure; fast publishers can overwhelm slow subscribers.

**Redis Streams:**
- Append-only log. Entry format: `XADD stream * field1 value1`.
- Entry ID: `<millisecondsTimestamp>-<sequenceNumber>`.
- Reading: `XREAD COUNT 10 STREAMS mystream 0` or `XREAD BLOCK 0 STREAMS mystream $`.
- Consumer Groups: `XGROUP CREATE`, `XREADGROUP GROUP g1 consumer1 COUNT 10 STREAMS mystream >`.
  - `>` means "only undelivered messages".
  - After processing: `XACK mystream g1 <entry-id>`.
  - Pending entries (delivered but not ACKed): visible via `XPENDING`.
  - Dead letter: use `XCLAIM` to re-assign stale pending entries.
- Retention: `MAXLEN` trims old entries.

**Consumer Group semantics:**
- Each group maintains an offset (last-delivered-id).
- Within a group, each message is delivered to exactly one consumer.
- Across groups, each group receives all messages independently (like Kafka consumer groups).

**Real-World Example:**
Order events on stream key `orders`. Group "notifications" sends email; group "inventory" decrements stock; group "analytics" logs to data warehouse -- all consume independently. Pub/Sub used for cache-invalidation broadcast to all app nodes on price change.

**Code Example:**
```java
// Pub/Sub with Spring Data Redis
@Configuration
public class PubSubConfig {

    @Bean
    public MessageListenerAdapter listenerAdapter(CacheInvalidationHandler handler) {
        return new MessageListenerAdapter(handler, "handleMessage");
    }

    @Bean
    public RedisMessageListenerContainer container(
            RedisConnectionFactory connectionFactory,
            MessageListenerAdapter listenerAdapter) {
        RedisMessageListenerContainer container = new RedisMessageListenerContainer();
        container.setConnectionFactory(connectionFactory);
        container.addMessageListener(listenerAdapter,
            new PatternTopic("cache:invalidation:*"));
        return container;
    }
}

@Component
@Slf4j
public class CacheInvalidationHandler {
    private final RedisTemplate<String, Object> redisTemplate;

    public CacheInvalidationHandler(RedisTemplate<String, Object> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public void handleMessage(String message, String channel) {
        String entityType = channel.replace("cache:invalidation:", "");
        redisTemplate.delete(entityType + ":" + message);
        log.info("Cache invalidated: {}:{}", entityType, message);
    }
}

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderEventStreams {

    private final RedisTemplate<String, Object> redisTemplate;
    private static final String STREAM_KEY = "stream:orders";
    private static final String GROUP_NAME = "order-processors";

    public RecordId publishOrderEvent(OrderEvent event) {
        Map<String, String> payload = Map.of(
            "orderId", event.getOrderId(),
            "status", event.getStatus().name(),
            "timestamp", Instant.now().toString()
        );
        return redisTemplate.opsForStream().add(MapRecord.create(STREAM_KEY, payload));
    }

    @PostConstruct
    public void createConsumerGroup() {
        try {
            redisTemplate.opsForStream().createGroup(STREAM_KEY, GROUP_NAME);
        } catch (Exception e) {
            log.debug("Consumer group already exists: {}", GROUP_NAME);
        }
    }

    @Scheduled(fixedDelay = 1000)
    public void consumeOrderEvents() {
        List<MapRecord<String, Object, Object>> records = redisTemplate.opsForStream()
            .read(Consumer.from(GROUP_NAME, "consumer-1"),
                StreamReadOptions.empty().count(10),
                StreamOffset.create(STREAM_KEY, ReadOffset.lastConsumed()));

        if (records == null) return;
        records.forEach(record -> {
            try {
                processOrder(record.getValue());
                redisTemplate.opsForStream()
                    .acknowledge(STREAM_KEY, GROUP_NAME, record.getId());
            } catch (Exception e) {
                log.error("Failed to process order event: {}", record.getId(), e);
            }
        });
    }

    @Scheduled(fixedDelay = 30000)
    public void reclaimStalePendingEntries() {
        PendingMessagesSummary pending =
            redisTemplate.opsForStream().pending(STREAM_KEY, GROUP_NAME);
        if (pending == null || pending.getTotalPendingMessages() == 0) return;
        redisTemplate.opsForStream().claim(
            STREAM_KEY, GROUP_NAME, "consumer-1",
            Duration.ofSeconds(60), pending.minMessageId()
        );
    }

    private void processOrder(Map<Object, Object> payload) {
        log.info("Processing order: {}", payload.get("orderId"));
    }
}
```

**Follow-up Questions:**
1. How does Redis Streams handle back-pressure compared to Kafka?
2. What happens to unacknowledged messages in a consumer group when a consumer crashes?
3. How do you implement exactly-once semantics with Redis Streams?

**Common Mistakes:**
- Using Pub/Sub for critical events -- message loss is by design; use Streams for guaranteed delivery.
- Not acknowledging messages with XACK -- pending list grows unbounded.

**Interview Traps:**
- "Redis Streams can fully replace Kafka" -- Streams lacks Kafka's durability guarantees, partitioning for extreme throughput, and schema registry.
- "SUBSCRIBE blocks forever" -- yes, it blocks the connection; use a dedicated connection pool for pub/sub.

**Quick Revision (1-liner):**
Pub/Sub = fire-and-forget broadcast; Streams = durable append-only log with consumer groups, ACK, and replay -- use Streams for reliable event processing.

---

### Topic 9: Redis Persistence
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Amazon, Stripe, Netflix

**Q: Compare RDB and AOF persistence in Redis. How do you choose between them, and what is hybrid persistence?**

**Short Answer (2-3 sentences):**
RDB creates point-in-time snapshots via fork+copy-on-write; it is compact and fast to restore but can lose up to minutes of data. AOF logs every write command; it provides near-zero data loss (fsync every second) at the cost of larger files and slower restart. Hybrid persistence (Redis 4+) combines both: AOF files start with an RDB snapshot followed by incremental AOF commands.

**Deep Explanation:**
**RDB (Redis Database Backup):**
- `BGSAVE`: Redis forks a child process; child writes snapshot to `dump.rdb` while parent continues serving.
- `SAVE`: Blocking snapshot -- blocks the main thread; avoid in production.
- Triggers: `save 900 1` (after 900s if >=1 key changed), `save 300 10`, `save 60 10000`.
- Pros: Small files, fast restart (binary format), minimal I/O during normal operation.
- Cons: Last snapshot can be minutes old; data loss on crash = last snapshot age.

**AOF (Append-Only File):**
- Every write command appended to `appendonly.aof`.
- `appendfsync always`: fsync on every write -- zero data loss, ~1/3 throughput.
- `appendfsync everysec`: fsync every second -- at most 1 second of data loss (default).
- `appendfsync no`: Let OS decide -- fastest, unpredictable data loss.
- AOF Rewrite: `BGREWRITEAOF` compacts AOF by replaying commands. Automatic: `auto-aof-rewrite-percentage 100`, `auto-aof-rewrite-min-size 64mb`.
- Pros: Near-zero data loss, human-readable log, append-only = corruption-resistant.
- Cons: Larger files, slower restart (must replay all commands), write amplification.

**Hybrid Persistence (Redis 4+):**
- `aof-use-rdb-preamble yes`.
- On AOF rewrite: writes RDB snapshot to beginning of AOF file, then incremental commands.
- Restart: Load RDB preamble (fast), then replay only recent AOF commands.
- Best of both worlds: fast restart + low data loss.

**Durability Tradeoffs:**
| Config | Data Loss | Write Throughput | Restart Speed |
|--------|-----------|-----------------|---------------|
| No persistence | All | Fastest | N/A |
| RDB only | Up to minutes | Fast | Fastest |
| AOF everysec | <=1 second | Medium | Slow |
| AOF always | Zero | Slowest | Slow |
| Hybrid | <=1 second | Medium | Fast |

**Real-World Example:**
Session store: AOF with `everysec` -- sessions are critical but 1s loss is acceptable. Leaderboard cache: RDB only -- reconstructible from DB, fast restart preferred. Financial event log: AOF with `always` -- no data loss tolerated.

**Code Example:**
```java
@Component
@RequiredArgsConstructor
@Slf4j
public class RedisPersistenceMonitor {

    private final RedisTemplate<String, Object> redisTemplate;

    @Scheduled(fixedRate = 30000)
    public void checkPersistenceHealth() {
        Properties info = redisTemplate.execute(
            (RedisCallback<Properties>) conn -> conn.serverCommands().info("persistence")
        );
        if (info == null) return;

        String aofEnabled = info.getProperty("aof_enabled");
        String rdbLastSaveTime = info.getProperty("rdb_last_save_time");
        String aofLastRewriteStatus = info.getProperty("aof_last_rewrite_status");
        String rdbLastBgsaveStatus = info.getProperty("rdb_last_bgsave_status");

        log.info("Persistence -- AOF={}, RDB_last_save={}, AOF_rewrite={}, RDB_bgsave={}",
            aofEnabled, rdbLastSaveTime, aofLastRewriteStatus, rdbLastBgsaveStatus);

        if ("err".equals(rdbLastBgsaveStatus)) {
            log.error("RDB BGSAVE failed! Check Redis logs.");
        }
        if ("err".equals(aofLastRewriteStatus)) {
            log.error("AOF rewrite failed! Check Redis logs.");
        }

        long lastSave = Long.parseLong(rdbLastSaveTime != null ? rdbLastSaveTime : "0");
        long ageMinutes = (System.currentTimeMillis() / 1000 - lastSave) / 60;
        if (ageMinutes > 30) {
            log.warn("RDB last save was {} minutes ago -- possible data loss risk", ageMinutes);
        }
    }

    public void triggerBackgroundSave() {
        redisTemplate.execute(
            (RedisCallback<String>) conn -> conn.serverCommands().bgSave()
        );
        log.info("BGSAVE triggered");
    }
}
```

```
# redis.conf for hybrid persistence
appendonly yes
aof-use-rdb-preamble yes
appendfsync everysec
no-appendfsync-on-rewrite yes
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
save 900 1
save 300 10
save 60 10000
```

**Follow-up Questions:**
1. How does copy-on-write during BGSAVE affect memory usage, and what is the worst case?
2. What is AOF rewrite, and why does it not compact to zero operations?
3. How does Redis handle a corrupted AOF file on startup?

**Common Mistakes:**
- Disabling persistence for a session store -- sessions lost on restart cause all users to be logged out.
- Not monitoring AOF file size -- without rewrite, AOF grows unbounded.

**Interview Traps:**
- "AOF always is the safest" -- it is the most durable but has the lowest throughput; everysec is usually the right balance.
- "RDB fork is free" -- fork pauses the main process briefly; on large datasets with transparent huge pages enabled, this pause can be hundreds of milliseconds.

**Quick Revision (1-liner):**
RDB = fast restart, higher data loss; AOF = low data loss, slower restart; hybrid = best of both; use `appendfsync everysec` with `aof-use-rdb-preamble yes` for production.

---

### Topic 10: Redis Cluster & Replication
**Difficulty:** Hard | **Frequency:** High | **Companies:** Amazon, Meta, Twitter, Shopify, Netflix

**Q: Explain Redis master-replica replication and Redis Cluster. How do hash slots work, and what are MOVED and ASK redirects?**

**Short Answer (2-3 sentences):**
Redis replication uses async master-replica streaming -- replicas receive write commands and apply them. Redis Cluster shards data across 16,384 hash slots divided among master nodes; each key is mapped to a slot via CRC16. MOVED redirects clients permanently to the correct node; ASK is a temporary redirect during slot migration.

**Deep Explanation:**
**Master-Replica Replication:**
- Replicas connect to master; master streams replication backlog.
- Full sync: replica sends `PSYNC <replicationid> <offset>`; if master cannot partially sync, sends RDB snapshot + buffered commands.
- Partial sync: resumes from offset using replication backlog (default 1MB circular buffer).
- Async replication: master does not wait for replica ACK -- data loss on failover possible.
- `WAIT numreplicas timeout`: Semi-sync -- wait for replicas to acknowledge before returning to client.
- Redis Sentinel: Monitors master; promotes replica on failure; updates client connections.

**Redis Cluster:**
- Keyspace partitioned into 16,384 hash slots.
- `HASH_SLOT = CRC16(key) mod 16384`.
- Each master owns a subset of slots (e.g., master1: 0-5460, master2: 5461-10922, master3: 10923-16383).
- Each master has 1+ replicas.
- Minimum: 3 masters + 3 replicas (6 nodes).
- Gossip protocol: nodes exchange cluster state every second.
- No coordination server -- fully decentralized.

**MOVED vs ASK:**
- **MOVED**: Key definitively lives on another node. Client should update routing table permanently. Example: `MOVED 3999 127.0.0.1:6381`.
- **ASK**: Slot is being migrated; key may be on old or new node -- try new node for this request only. Do not update routing table. Example: `ASK 3999 127.0.0.1:6381`.
- Client sends `ASKING` command before the redirected command when following ASK.

**Hash Tags:**
- `{user}.profile` and `{user}.session` have the same slot (computed on `user` only).
- Enables multi-key operations on keys sharing the same hash tag.

**Cluster limitations:**
- No cross-slot multi-key operations without hash tags.
- No MULTI/EXEC across different slots.
- Pub/Sub messages delivered only within the node that receives PUBLISH in older versions.

**Real-World Example:**
E-commerce cluster: 6 nodes (3M + 3R). `{product:123}:details` and `{product:123}:inventory` share a slot -- atomic multi-key operations work. Session keys use `{user:456}` hash tag for same-node storage.

**Code Example:**
```java
// application.yml
// spring.data.redis.cluster.nodes: redis1:6379,redis2:6379,redis3:6379
// spring.data.redis.cluster.max-redirects: 3

@Configuration
public class RedisClusterConfig {

    @Bean
    public LettuceClientConfigurationBuilderCustomizer lettuceCustomizer() {
        return builder -> builder
            .clientOptions(ClusterClientOptions.builder()
                .autoReconnect(true)
                .maxRedirects(3)
                .topologyRefreshOptions(
                    ClusterTopologyRefreshOptions.builder()
                        .enableAllAdaptiveRefreshTriggers()
                        .enablePeriodicRefresh(Duration.ofSeconds(30))
                        .build())
                .build());
    }
}

@Service
@RequiredArgsConstructor
@Slf4j
public class ClusterAwareService {

    private final RedisTemplate<String, Object> redisTemplate;

    // Hash tag ensures co-location: {userId} in same slot
    public void saveUserData(String userId, Map<String, Object> profile,
                              Map<String, Object> preferences) {
        redisTemplate.opsForHash().putAll("{user:" + userId + "}:profile", profile);
        redisTemplate.opsForHash().putAll("{user:" + userId + "}:preferences", preferences);
    }

    public Map<String, Object> getUserSummary(String userId) {
        Map<Object, Object> profile =
            redisTemplate.opsForHash().entries("{user:" + userId + "}:profile");
        Map<Object, Object> prefs =
            redisTemplate.opsForHash().entries("{user:" + userId + "}:preferences");

        Map<String, Object> summary = new HashMap<>(
            profile.entrySet().stream()
                .collect(Collectors.toMap(e -> e.getKey().toString(), Map.Entry::getValue)));
        summary.put("preferences", prefs);
        return summary;
    }

    // Determine slot for debugging
    public int getSlot(String key) {
        return redisTemplate.execute(
            (RedisCallback<Integer>) conn -> {
                RedisClusterCommands<byte[], byte[]> clusterConn =
                    (RedisClusterCommands<byte[], byte[]>) conn.getNativeConnection();
                return (int) clusterConn.clusterKeyslot(key.getBytes());
            }
        );
    }

    @Scheduled(fixedRate = 60000)
    public void logClusterInfo() {
        Properties clusterInfo = redisTemplate.execute(
            (RedisCallback<Properties>) conn -> conn.serverCommands().info("cluster")
        );
        if (clusterInfo != null) {
            log.info("Cluster state: {}, known_nodes: {}",
                clusterInfo.getProperty("cluster_enabled"),
                clusterInfo.getProperty("cluster_known_nodes"));
        }
    }
}
```

**Follow-up Questions:**
1. What happens during a master failure in Redis Cluster -- how long before a replica is promoted?
2. How does Redis Cluster handle the case where a master and all its replicas fail simultaneously?
3. What is the difference between Redis Sentinel and Redis Cluster, and can you run both?

**Common Mistakes:**
- Using MGET/MSET without hash tags in a cluster -- keys on different nodes cause cross-slot errors.
- Setting `max-redirects` too low -- if topology changes during a request, insufficient redirects cause failures.

**Interview Traps:**
- "Redis Cluster guarantees strong consistency" -- replication is async; failover can lose the latest writes.
- "16,384 slots limits scalability" -- the limit is on masters per slot range, not total data; you can have hundreds of masters serving petabytes.

**Quick Revision (1-liner):**
Redis Cluster = 16,384 hash slots distributed across masters; MOVED = permanent redirect; ASK = temporary migration redirect; use hash tags for multi-key co-location.

---

### Topic 11: Cache Warming & Cold Start
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Amazon, Netflix, Shopify, Stripe

**Q: What is the cold start problem in caching, and what strategies do you use to pre-warm the cache?**

**Short Answer (2-3 sentences):**
A cold start occurs when the cache is empty -- every request is a cache miss, sending all traffic directly to the database and potentially causing a cascading failure. Cache warming pre-populates the cache before traffic arrives using strategies like lazy warming, eager warming, or shadow traffic replay. The trade-off is startup time vs. cache miss penalty.

**Deep Explanation:**
**Cold Start Scenarios:**
1. New deployment with empty Redis.
2. Redis restart after crash (RDB/AOF disabled or corrupted).
3. Cache eviction storm (maxmemory exhausted).
4. New data center region launch.

**Warming Strategies:**
1. **Lazy Warming (natural):** Cache fills organically as users hit it. Simple but causes high miss rate for minutes/hours. Acceptable when DB can absorb initial spike.
2. **Eager Warming (pre-population):** On startup, load top-N hot keys from DB into cache. Risk: pre-loading stale data; loading too much wastes time/memory.
3. **Shadow Traffic Replay:** Record production traffic; replay on new cache instance before switching traffic over. Best for accuracy; complex infrastructure.
4. **Access-frequency-based:** Analyze DB query logs to identify hot keys (top 1000 products, top cities); load those on startup.
5. **Graduated rollout:** Route 1% traffic to new node; let cache warm; gradually increase.
6. **Cache mirroring:** During deployment, write to both old and new cache simultaneously for TTL period.

**Preventing Cold Start Impact:**
- Set TTL such that old cache instances serve traffic while new ones warm.
- Use blue-green deployment -- old green instance stays live until blue is warm.
- Use `WAIT` command to ensure replicas are synchronized before redirecting reads.

**Real-World Example:**
Netflix uses a "cache warming service" that pre-populates personalization caches before directing traffic to a new region. Amazon pre-warms product caches for Black Friday by loading top-N products by category at midnight.

**Code Example:**
```java
@Component
@RequiredArgsConstructor
@Slf4j
public class CacheWarmingService implements ApplicationRunner {

    private final ProductRepository productRepository;
    private final RedisTemplate<String, Object> redisTemplate;
    private final CategoryRepository categoryRepository;

    private static final int TOP_PRODUCTS_PER_CATEGORY = 100;
    private static final Duration WARM_TTL = Duration.ofHours(1);

    @Override
    public void run(ApplicationArguments args) {
        log.info("Starting cache warming...");
        long start = System.currentTimeMillis();
        try {
            warmTopProducts();
            warmCategories();
            warmConfigurations();
            log.info("Cache warming completed in {}ms", System.currentTimeMillis() - start);
        } catch (Exception e) {
            // Do NOT block startup on warm failure
            log.error("Cache warming failed -- starting with cold cache", e);
        }
    }

    private void warmTopProducts() {
        List<String> categories = categoryRepository.findAllActiveCategories();
        categories.parallelStream().forEach(category -> {
            try {
                List<Product> topProducts =
                    productRepository.findTopByCategory(category, TOP_PRODUCTS_PER_CATEGORY);
                topProducts.forEach(product -> {
                    String key = "product:" + product.getId();
                    redisTemplate.opsForValue().setIfAbsent(key, product, WARM_TTL);
                });
                log.debug("Warmed {} products for category: {}", topProducts.size(), category);
            } catch (Exception e) {
                log.warn("Failed to warm category: {}", category, e);
            }
        });
    }

    private void warmCategories() {
        List<Category> categories = categoryRepository.findAllActive();
        redisTemplate.executePipelined((RedisCallback<Object>) connection -> {
            categories.forEach(cat -> {
                byte[] keyBytes = ("cat:" + cat.getId()).getBytes();
                byte[] valueBytes = serialize(cat);
                connection.stringCommands().set(keyBytes, valueBytes,
                    Expiration.from(WARM_TTL), SetOption.ifAbsent());
            });
            return null;
        });
    }

    private void warmConfigurations() {
        Map<String, String> configs = loadConfigsFromDB();
        configs.forEach((key, value) ->
            redisTemplate.opsForValue().setIfAbsent("config:" + key, value, Duration.ofHours(24)));
    }

    private byte[] serialize(Object value) {
        return value.toString().getBytes();
    }

    private Map<String, String> loadConfigsFromDB() {
        return Map.of("feature.darkMode", "true", "maxOrderItems", "50");
    }
}
```

**Follow-up Questions:**
1. How do you detect that the cache has fully warmed and is ready to serve traffic?
2. What is the risk of warming cache with stale data, and how do you mitigate it?
3. How would you implement cache warming for a Redis Cluster with 16,384 slots?

**Common Mistakes:**
- Blocking application startup on cache warming -- if Redis is slow or partially unavailable, the app never starts.
- Loading ALL data into cache instead of hot keys -- wastes memory and warming time.

**Interview Traps:**
- "Blue-green deployment solves cold start automatically" -- only if the old instance stays live; if both swap simultaneously, both are cold.
- "Lazy warming is always safe" -- for high-traffic systems on Black Friday, lazy warming can cause DB overload during the cold window.

**Quick Revision (1-liner):**
Cold start = empty cache causing DB overload; mitigate with eager pre-population of hot keys, graduated rollout, or blue-green deployment with cache handoff.

---

### Topic 12: Session Management with Redis
**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Stripe, Shopify

**Q: How do you implement distributed session management with Spring Session and Redis? Compare server-side sessions with JWTs.**

**Short Answer (2-3 sentences):**
Spring Session stores HTTP sessions in Redis, enabling any application node to handle any request (eliminating sticky sessions). Each session is stored as a Redis Hash under `spring:session:sessions:<id>` with a configurable TTL. JWTs are stateless and require no session store but cannot be revoked without a blocklist.

**Deep Explanation:**
**Sticky Sessions Problem:**
- Without distributed sessions, each app node stores sessions in memory.
- Load balancer must route each user to the same node -- sticky sessions.
- If that node dies, all its users are logged out.
- Horizontal scaling is difficult; nodes must drain before shutdown.

**Spring Session + Redis:**
- `@EnableRedisHttpSession(maxInactiveIntervalInSeconds = 1800)`.
- Replaces `HttpSession` with a Redis-backed session.
- Session data stored as Redis Hash: fields are session attributes.
- Session index enables finding all sessions for a user.
- TTL auto-reset on access (sliding expiration).

**Server-Side Sessions vs JWT:**
| Aspect | Server-Side (Redis) | JWT |
|--------|---------------------|-----|
| State | Stateful | Stateless |
| Revocation | Immediate (delete key) | Requires blocklist |
| Size | Small (ID only in cookie) | Large (all claims in token) |
| DB lookup | One Redis GET per request | Zero (signature verification only) |
| Horizontal scaling | Need shared Redis | No shared state needed |
| Refresh | Session sliding TTL | Refresh token required |

**Choosing between them:**
- High-security (banking, admin): Server-side sessions -- instant revocation.
- Microservices / mobile / SPA: JWT -- no shared session store needed.
- Hybrid: JWT for auth + short-lived Redis blocklist for revoked tokens.

**Real-World Example:**
A bank application uses Spring Session + Redis. After suspicious login, operations team calls `sessionRepository.deleteById(sessionId)` -- user is immediately logged out. With JWT this would require a Redis blocklist lookup on every request anyway.

**Code Example:**
```java
// Dependency: spring-session-data-redis

@Configuration
@EnableRedisHttpSession(maxInactiveIntervalInSeconds = 1800)
public class SessionConfig {

    @Bean
    public CookieSerializer cookieSerializer() {
        DefaultCookieSerializer serializer = new DefaultCookieSerializer();
        serializer.setCookieName("SESSION");
        serializer.setUseHttpOnlyCookie(true);
        serializer.setUseSecureCookie(true);
        serializer.setSameSite("Strict");
        serializer.setCookiePath("/");
        return serializer;
    }
}

@RestController
@RequiredArgsConstructor
public class SessionController {

    private final FindByIndexNameSessionRepository<? extends Session> sessionRepository;

    @PostMapping("/auth/login")
    public ResponseEntity<LoginResponse> login(
            @RequestBody LoginRequest request, HttpSession session) {
        User user = authenticate(request);
        session.setAttribute("userId", user.getId());
        session.setAttribute("roles", user.getRoles());
        session.setAttribute(
            FindByIndexNameSessionRepository.PRINCIPAL_NAME_INDEX_NAME,
            user.getUsername());
        return ResponseEntity.ok(new LoginResponse(user.getId()));
    }

    @PostMapping("/auth/logout")
    public ResponseEntity<Void> logout(HttpSession session) {
        session.invalidate();
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/admin/users/{username}/sessions")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> invalidateUserSessions(@PathVariable String username) {
        Map<String, ? extends Session> sessions =
            sessionRepository.findByPrincipalName(username);
        sessions.forEach((id, s) -> sessionRepository.deleteById(id));
        return ResponseEntity.noContent().build();
    }

    private User authenticate(LoginRequest request) { return new User(); }
}

// JWT + Redis blocklist hybrid
@Service
@RequiredArgsConstructor
public class JwtService {

    private final RedisTemplate<String, String> redisTemplate;
    private static final String BLOCKLIST_PREFIX = "jwt:blocklist:";

    public boolean isTokenRevoked(String jti) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(BLOCKLIST_PREFIX + jti));
    }

    public void revokeToken(String jti, Instant expiry) {
        Duration ttl = Duration.between(Instant.now(), expiry);
        if (ttl.isPositive()) {
            redisTemplate.opsForValue().set(BLOCKLIST_PREFIX + jti, "revoked", ttl);
        }
    }
}
```

**Follow-up Questions:**
1. How does Spring Session handle session serialization across application versions with schema changes?
2. What is the performance impact of one Redis GET per HTTP request for session validation?
3. How do you implement "remember me" functionality with Spring Session?

**Common Mistakes:**
- Storing large objects in session -- every request deserializes the entire session; keep sessions small.
- Not setting `secure` and `httpOnly` on the session cookie -- exposes session ID to XSS and network interception.

**Interview Traps:**
- "JWTs are always better than sessions" -- JWTs cannot be revoked instantly without a blocklist, which reintroduces the shared state problem.
- "Spring Session automatically handles session migration" -- it does not; if the session object class changes between deployments, deserialization fails.

**Quick Revision (1-liner):**
Spring Session + Redis eliminates sticky sessions and enables instant revocation; JWTs are stateless but require a Redis blocklist for revocation -- choose based on revocation requirements.

---

### Topic 13: Rate Limiting with Redis
**Difficulty:** Hard | **Frequency:** High | **Companies:** Stripe, Amazon, Twitter, Cloudflare, Shopify

**Q: Implement a rate limiter with Redis. Compare fixed window, sliding window, and token bucket approaches.**

**Short Answer (2-3 sentences):**
A fixed window counter uses `INCR` + `EXPIRE` but has boundary burst issues. A sliding window uses a sorted set (`ZADD` + `ZRANGEBYSCORE`) to track per-request timestamps, providing smooth limiting at the cost of more memory. Token bucket is the most flexible -- implemented with a Lua script for atomicity -- and allows burst capacity while enforcing average rate.

**Deep Explanation:**
**Fixed Window Counter:**
- Key: `rate:userId:minute:<epoch_minute>`.
- `INCR key` + `EXPIRE key 60`.
- Problem: User can make 2x the limit within a window boundary (last second of minute N + first second of minute N+1).

**Sliding Window Log:**
- Store each request timestamp in a ZSet: `ZADD rate:userId <timestamp> <timestamp>`.
- Remove old entries: `ZREMRANGEBYSCORE rate:userId 0 <timestamp - window>`.
- Count remaining: `ZCARD rate:userId`.
- Accurate but O(N) memory per user (N = requests per window).

**Sliding Window Counter (memory-efficient):**
- Two fixed window buckets (current + previous) weighted by overlap.
- `rate = prev_count * ((window - elapsed) / window) + curr_count`.
- O(1) memory, ~10% accuracy tradeoff.

**Token Bucket:**
- Each user has a bucket of capacity C with refill rate R tokens/second.
- Request consumes 1 token; blocked if bucket empty.
- Lua script: check current tokens, add `(now - last_refill) * rate` tokens (capped at capacity), consume 1 if available.
- Allows bursts up to capacity.

**Atomicity:**
- All rate limiting logic must be atomic -- use Lua scripts executed with EVAL.
- Lua scripts execute atomically without other commands interleaving.

**Real-World Example:**
Stripe API: 100 req/s per API key using token bucket. Burst up to 200 allowed. Cloudflare uses sliding window for DDoS mitigation at edge.

**Code Example:**
```java
@Service
@RequiredArgsConstructor
@Slf4j
public class RedisRateLimiter {

    private final RedisTemplate<String, String> redisTemplate;

    // 1. Fixed Window
    public boolean isAllowedFixedWindow(String userId, int maxRequests, int windowSeconds) {
        String key = "rate:fixed:" + userId + ":"
            + (System.currentTimeMillis() / (windowSeconds * 1000L));
        Long count = redisTemplate.opsForValue().increment(key);
        if (count == 1) {
            redisTemplate.expire(key, Duration.ofSeconds(windowSeconds));
        }
        return count != null && count <= maxRequests;
    }

    // 2. Sliding Window with Sorted Set (Lua for atomicity)
    private static final String SLIDING_WINDOW_SCRIPT =
        "local key = KEYS[1] " +
        "local now = tonumber(ARGV[1]) " +
        "local window = tonumber(ARGV[2]) " +
        "local limit = tonumber(ARGV[3]) " +
        "local clearBefore = now - window " +
        "redis.call('ZREMRANGEBYSCORE', key, 0, clearBefore) " +
        "local count = redis.call('ZCARD', key) " +
        "if count < limit then " +
        "  redis.call('ZADD', key, now, now) " +
        "  redis.call('EXPIRE', key, math.ceil(window / 1000) + 1) " +
        "  return 1 " +
        "else " +
        "  return 0 " +
        "end";

    public boolean isAllowedSlidingWindow(String userId, int maxRequests, int windowMs) {
        DefaultRedisScript<Long> script = new DefaultRedisScript<>(SLIDING_WINDOW_SCRIPT, Long.class);
        Long result = redisTemplate.execute(script,
            Collections.singletonList("rate:sliding:" + userId),
            String.valueOf(System.currentTimeMillis()),
            String.valueOf(windowMs),
            String.valueOf(maxRequests));
        return Long.valueOf(1L).equals(result);
    }

    // 3. Token Bucket via Lua script (recommended for production APIs)
    private static final String TOKEN_BUCKET_SCRIPT =
        "local key = KEYS[1] " +
        "local capacity = tonumber(ARGV[1]) " +
        "local refillRate = tonumber(ARGV[2]) " +
        "local now = tonumber(ARGV[3]) " +
        "local data = redis.call('HMGET', key, 'tokens', 'last_refill') " +
        "local tokens = tonumber(data[1]) or capacity " +
        "local lastRefill = tonumber(data[2]) or now " +
        "local elapsed = math.max(0, now - lastRefill) " +
        "local newTokens = math.min(capacity, tokens + (elapsed * refillRate)) " +
        "local allowed = 0 " +
        "if newTokens >= 1 then " +
        "  newTokens = newTokens - 1 " +
        "  allowed = 1 " +
        "end " +
        "redis.call('HMSET', key, 'tokens', newTokens, 'last_refill', now) " +
        "redis.call('EXPIRE', key, math.ceil(capacity / refillRate / 1000) + 10) " +
        "return {allowed, math.floor(newTokens)}";

    public RateLimitResult isAllowedTokenBucket(
            String userId, int capacity, double refillPerSecond) {
        DefaultRedisScript<List> script = new DefaultRedisScript<>(TOKEN_BUCKET_SCRIPT, List.class);
        double refillPerMs = refillPerSecond / 1000.0;

        List<Long> result = redisTemplate.execute(script,
            Collections.singletonList("rate:token:" + userId),
            String.valueOf(capacity),
            String.valueOf(refillPerMs),
            String.valueOf(System.currentTimeMillis()));

        boolean allowed = result != null && result.get(0) == 1L;
        long remaining = result != null ? result.get(1) : 0L;
        return new RateLimitResult(allowed, remaining);
    }
}

// Spring MVC interceptor
@Component
@RequiredArgsConstructor
public class RateLimitInterceptor implements HandlerInterceptor {

    private final RedisRateLimiter rateLimiter;

    @Override
    public boolean preHandle(HttpServletRequest request,
                              HttpServletResponse response, Object handler) throws Exception {
        String apiKey = request.getHeader("X-API-Key");
        if (apiKey == null) {
            response.setStatus(HttpStatus.UNAUTHORIZED.value());
            return false;
        }
        RateLimitResult result = rateLimiter.isAllowedTokenBucket(apiKey, 100, 10.0);
        response.setHeader("X-RateLimit-Remaining", String.valueOf(result.remainingTokens()));
        response.setHeader("X-RateLimit-Limit", "100");
        if (!result.allowed()) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setHeader("Retry-After", "1");
            return false;
        }
        return true;
    }
}

record RateLimitResult(boolean allowed, long remainingTokens) {}
```

**Follow-up Questions:**
1. Why must rate limiting logic use a Lua script rather than separate Redis commands?
2. How does the sliding window counter (two-bucket approximation) work, and what is its error margin?
3. How would you implement distributed rate limiting across multiple Redis Cluster nodes for a global API?

**Common Mistakes:**
- Implementing rate limiting with separate INCR and check commands in application code -- race condition allows more than the limit under concurrency.
- Not setting TTL on rate limit keys -- keys accumulate indefinitely for inactive users.

**Interview Traps:**
- "Fixed window counter is good enough" -- boundary burst attacks (2x limit in 2 seconds) are a real threat for APIs.
- "Lua scripts are synchronous and block Redis" -- yes, Lua scripts block the event loop; keep scripts short (microseconds, not milliseconds).

**Quick Revision (1-liner):**
Fixed window is simple but burst-vulnerable; sliding window ZSet is accurate but memory-heavy; token bucket via Lua script is the production standard -- atomic, burst-tolerant, and efficient.

---

### Topic 14: Cache Penetration, Avalanche, Breakdown
**Difficulty:** Hard | **Frequency:** High | **Companies:** Amazon, Meta, Stripe, Netflix, Alibaba

**Q: Describe the three Redis failure modes -- cache penetration, cache avalanche, and cache breakdown -- and how to solve each.**

**Short Answer (2-3 sentences):**
Cache penetration = requests for non-existent keys bypass cache and hit DB repeatedly; solved with bloom filters or caching null values. Cache avalanche = mass simultaneous cache expiry overwhelming DB; solved with TTL jitter, warm-up, and circuit breakers. Cache breakdown = single hot key expires and concurrent requests cause DB overload; solved with mutex lock or never-expiring hot keys with background refresh.

**Deep Explanation:**
**Cache Penetration:**
- Attacker or bug causes repeated lookups of keys that do not exist in cache OR DB.
- Every request -> cache miss -> DB miss -> no caching -> repeat.
- Solutions:
  1. **Cache null values:** Cache `null` with short TTL (30s). Stops DB hammering. Risk: legitimate keys that were null might remain null briefly.
  2. **Bloom Filter:** Probabilistic data structure that definitively says "NOT in DB" (no false negatives). Before querying cache, check bloom filter. If absent -> return 404 immediately. Small false positive rate (key might be in bloom but not DB -> one DB hit).
  3. **Input validation:** Rate-limit/block suspicious query patterns before they reach cache.

**Cache Avalanche:**
- Mass expiry at the same time (e.g., all keys set with same TTL) -> DB gets 100% of traffic.
- Also: Redis cluster failure -> all traffic hits DB.
- Solutions:
  1. **TTL jitter:** Randomize TTL = `base + random(0, spread)`.
  2. **Circuit breaker:** If DB latency spikes, return stale/degraded response.
  3. **Redis Sentinel/Cluster:** HA setup minimizes full outage window.
  4. **Multi-level cache:** L1 = Caffeine (in-process), L2 = Redis. L2 avalanche -> L1 absorbs burst.

**Cache Breakdown (Hot Key Expiry):**
- Single extremely hot key expires -> thousands of concurrent requests all miss -> DB overload for that one key.
- Differs from avalanche: one key, not many.
- Solutions:
  1. **Mutex/distributed lock:** Only one thread refreshes; others wait or serve stale.
  2. **Logical expiry:** Never set Redis TTL; store expiry time in value; if logically expired, serve stale and async refresh.
  3. **Hot key detection:** Monitor with Redis `--hotkeys`; replicate hot keys to multiple local caches.

**Real-World Example:**
Penetration: Bot scrapes random product IDs -- bloom filter rejects 99.9% before cache lookup. Avalanche: Black Friday midnight -- all product caches warmed 1 hour earlier with jitter TTLs. Breakdown: Taylor Swift concert tickets -- hot event page cached indefinitely with background refresh.

**Code Example:**
```java
// Cache Penetration: Bloom Filter + Null Caching
@Service
@RequiredArgsConstructor
@Slf4j
public class PenetrationProtectedService {

    private final RedisTemplate<String, Object> redisTemplate;
    private final ProductRepository productRepository;

    private final BloomFilter<String> bloomFilter =
        BloomFilter.create(Funnels.stringFunnel(Charsets.UTF_8), 1_000_000, 0.01);

    @PostConstruct
    public void initBloomFilter() {
        productRepository.findAllIds().forEach(bloomFilter::put);
        log.info("Bloom filter initialized");
    }

    public Optional<Product> getProduct(String productId) {
        if (!bloomFilter.mightContain(productId)) {
            return Optional.empty(); // Definitely not in DB
        }

        String cacheKey = "product:" + productId;
        Object cached = redisTemplate.opsForValue().get(cacheKey);
        if (cached != null) {
            return cached instanceof NullMarker ? Optional.empty() : Optional.of((Product) cached);
        }

        Optional<Product> product = productRepository.findById(productId);
        if (product.isPresent()) {
            redisTemplate.opsForValue().set(cacheKey, product.get(), Duration.ofMinutes(30));
        } else {
            redisTemplate.opsForValue().set(cacheKey, new NullMarker(), Duration.ofSeconds(30));
        }
        return product;
    }
}

@Data
class NullMarker implements Serializable {}

// Cache Avalanche: TTL Jitter + Circuit Breaker
@Service
@RequiredArgsConstructor
public class AvalancheProtectedService {

    private final RedisTemplate<String, Object> redisTemplate;
    private final ProductRepository productRepository;
    private final Random random = new SecureRandom();
    private final AtomicBoolean circuitOpen = new AtomicBoolean(false);
    private volatile Instant circuitOpenTime;

    private static final long BASE_TTL = 1800;
    private static final long TTL_JITTER = 300;

    public Product getProductWithJitter(String productId) {
        if (circuitOpen.get()) {
            if (Duration.between(circuitOpenTime, Instant.now()).toSeconds() > 30) {
                circuitOpen.set(false);
            } else {
                return getStaleOrDefault(productId);
            }
        }
        String cacheKey = "product:" + productId;
        Product cached = (Product) redisTemplate.opsForValue().get(cacheKey);
        if (cached != null) return cached;
        try {
            Product product = productRepository.findById(productId).orElseThrow();
            long jitteredTTL = BASE_TTL + (long) (random.nextDouble() * TTL_JITTER);
            redisTemplate.opsForValue().set(cacheKey, product, Duration.ofSeconds(jitteredTTL));
            return product;
        } catch (DataAccessException e) {
            circuitOpen.set(true);
            circuitOpenTime = Instant.now();
            throw new ServiceDegradedException("DB unavailable", e);
        }
    }

    private Product getStaleOrDefault(String productId) { return new Product(); }
}

// Cache Breakdown: Logical Expiry
@Service
@RequiredArgsConstructor
public class BreakdownProtectedService {

    private final RedisTemplate<String, Object> redisTemplate;
    private final ProductRepository productRepository;
    private final ExecutorService refreshExecutor = Executors.newFixedThreadPool(4);

    public Product getHotProduct(String productId) {
        String cacheKey = "hot:product:" + productId;
        HotCacheEntry entry = (HotCacheEntry) redisTemplate.opsForValue().get(cacheKey);
        if (entry == null) {
            return loadAndCache(productId, cacheKey);
        }
        if (entry.isLogicallyExpired()) {
            refreshExecutor.submit(() -> loadAndCache(productId, cacheKey));
        }
        return entry.getProduct();
    }

    private Product loadAndCache(String productId, String cacheKey) {
        Product product = productRepository.findById(productId).orElseThrow();
        HotCacheEntry entry = new HotCacheEntry(product, Instant.now().plusSeconds(300));
        redisTemplate.opsForValue().set(cacheKey, entry); // No Redis TTL
        return product;
    }
}

@Data
@AllArgsConstructor
@NoArgsConstructor
class HotCacheEntry implements Serializable {
    private Product product;
    private Instant logicalExpiry;
    public boolean isLogicallyExpired() { return Instant.now().isAfter(logicalExpiry); }
}
```

**Follow-up Questions:**
1. What is the false positive rate of a bloom filter, and how does it affect penetration protection?
2. How do you handle bloom filter updates when new products are added?
3. What is the difference between cache breakdown and cache avalanche at scale?

**Common Mistakes:**
- Caching null for too long -- legitimate keys that were temporarily absent remain null.
- Not combining jitter with pre-warming -- jitter alone won't help if keys are loaded simultaneously at startup.

**Interview Traps:**
- "Bloom filter prevents all penetration" -- it has a small false positive rate; attackers can eventually find IDs that pass the filter.
- "Mutex lock for breakdown means single-threaded access" -- other threads can serve stale data while one thread refreshes; no need to block all.

**Quick Revision (1-liner):**
Penetration = bloom filter + null cache; avalanche = TTL jitter + circuit breaker + multi-level cache; breakdown = mutex lock or logical expiry with async refresh.

---

### Topic 15: Redis Performance & Monitoring
**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Meta, Stripe, Netflix, Google

**Q: How does Redis achieve high throughput with a single thread? Explain pipelining, MULTI/EXEC transactions, and latency monitoring.**

**Short Answer (2-3 sentences):**
Redis uses a single-threaded event loop (I/O multiplexing via epoll/kqueue) to avoid context switching and lock contention, achieving 100K+ ops/second on commodity hardware. Pipelining batches multiple commands into one network round trip, dramatically reducing latency for bulk operations. MULTI/EXEC transactions are atomic with respect to other clients but do not roll back on command errors -- use Lua scripts for true atomic compare-and-set.

**Deep Explanation:**
**Single-Threaded Event Loop:**
- Main thread: accept connections, read commands, execute, write responses -- all non-blocking I/O via `epoll`.
- No lock contention -> predictable latency.
- CPU bottleneck is usually network or memory bandwidth, not thread contention.
- Redis 6+: I/O threads for reading/writing socket data; command execution still single-threaded.
- Implication: expensive O(N) commands (KEYS, SMEMBERS on large sets, SORT) block ALL clients during execution.

**Pipelining:**
- Client sends N commands without waiting for each response; receives all N responses in one batch.
- Reduces N RTTs to 1 RTT + server processing time.
- `RedisTemplate.executePipelined()` in Spring.
- Pipelining is NOT atomic -- commands are buffered then sent; other clients' commands can interleave.

**MULTI/EXEC Transactions:**
- `MULTI` -> queue commands -> `EXEC` -> execute atomically (no other commands interleave).
- If a command has a syntax error, EXEC returns error for that command but executes the rest (no rollback).
- Use WATCH for optimistic locking: `WATCH key -> MULTI -> ... -> EXEC` -- if watched key changed, EXEC returns nil.
- Limitation: cannot make decisions based on intermediate results (no if/else inside transaction).

**Lua Scripts vs MULTI/EXEC:**
- Lua scripts are truly atomic AND support conditional logic.
- Preferred for complex atomic operations (rate limiting, lock release).
- Cached on server by SHA1: `EVALSHA sha1 numkeys ...`.

**Performance Anti-Patterns:**
- `KEYS *` in production -- O(N), blocks event loop; use `SCAN` instead.
- Large values (>1MB) -- serialization/deserialization cost; split into smaller keys.
- Too many connections -- use connection pooling (Lettuce pool).
- Unnecessary TTL checks -- `TTL key` is O(1) but avoid in hot paths.

**Real-World Example:**
Stripe processes millions of API requests per second; Redis pipelining batches 50 rate-limit checks per HTTP request into 1 network round trip. SLOWLOG reveals a `SMEMBERS` on a 100K-member set taking 50ms -- refactored to `SSCAN`.

**Code Example:**
```java
@Service
@RequiredArgsConstructor
@Slf4j
public class RedisPerformanceDemo {

    private final RedisTemplate<String, Object> redisTemplate;

    // Pipelining: batch 1000 writes in one round trip
    public void bulkWrite(Map<String, String> data) {
        redisTemplate.executePipelined((RedisCallback<Object>) connection -> {
            data.forEach((key, value) ->
                connection.stringCommands().setEx(
                    key.getBytes(), 3600, value.getBytes()));
            return null;
        });
        log.info("Pipelined {} writes", data.size());
    }

    // MULTI/EXEC with WATCH (optimistic lock)
    public boolean transferCredits(String fromUser, String toUser, int amount) {
        String fromKey = "credits:" + fromUser;
        String toKey = "credits:" + toUser;
        for (int attempt = 0; attempt < 3; attempt++) {
            try {
                List<Object> txResult = redisTemplate.execute(new SessionCallback<>() {
                    @Override
                    public List<Object> execute(RedisOperations ops) {
                        ops.watch(Arrays.asList(fromKey, toKey));
                        int fromCredits = Integer.parseInt(
                            (String) ops.opsForValue().get(fromKey));
                        if (fromCredits < amount) {
                            ops.unwatch();
                            return null;
                        }
                        ops.multi();
                        ops.opsForValue().decrement(fromKey, amount);
                        ops.opsForValue().increment(toKey, amount);
                        return ops.exec();
                    }
                });
                if (txResult != null) {
                    log.info("Transfer successful on attempt {}", attempt + 1);
                    return true;
                }
            } catch (Exception e) {
                log.error("Transaction error on attempt {}", attempt + 1, e);
            }
        }
        return false;
    }

    // SCAN instead of KEYS *
    public Set<String> scanKeys(String pattern) {
        Set<String> keys = new HashSet<>();
        ScanOptions options = ScanOptions.scanOptions().match(pattern).count(100).build();
        try (Cursor<byte[]> cursor = redisTemplate.execute(
            (RedisCallback<Cursor<byte[]>>) conn -> conn.keyCommands().scan(options))) {
            while (cursor.hasNext()) {
                keys.add(new String(cursor.next()));
            }
        }
        return keys;
    }

    // Performance metrics dashboard
    @Scheduled(fixedRate = 30000)
    public void logPerformanceMetrics() {
        Properties info = redisTemplate.execute(
            (RedisCallback<Properties>) conn -> conn.serverCommands().info()
        );
        if (info == null) return;

        long hits = Long.parseLong(info.getProperty("keyspace_hits", "0"));
        long misses = Long.parseLong(info.getProperty("keyspace_misses", "0"));
        double hitRate = (hits + misses) > 0 ? (double) hits / (hits + misses) * 100 : 0;

        log.info("Redis Performance -- hit_rate={}%, connected_clients={}, " +
                "used_memory={}, ops_per_sec={}, rejected_connections={}",
            String.format("%.1f", hitRate),
            info.getProperty("connected_clients"),
            info.getProperty("used_memory_human"),
            info.getProperty("instantaneous_ops_per_sec"),
            info.getProperty("rejected_connections"));

        if (hitRate < 80) {
            log.warn("Cache hit rate below 80% -- consider increasing maxmemory " +
                "or reviewing eviction policy");
        }
    }
}
```

**Follow-up Questions:**
1. What commands should never be run in production Redis, and why?
2. How does Redis I/O threading in Redis 6+ work, and what guarantees remain single-threaded?
3. What is the difference between `MULTI/EXEC` and a Lua script for atomicity?

**Common Mistakes:**
- Using `KEYS *` in production -- O(N) blocks the event loop for the entire keyspace scan.
- Assuming `MULTI/EXEC` rolls back on error -- it doesn't; runtime errors (wrong type) are ignored; syntax errors abort EXEC.

**Interview Traps:**
- "Redis is single-threaded so it can't use multiple cores" -- Redis 6+ uses multiple I/O threads; you can also run multiple Redis instances per machine pinned to different cores.
- "Pipelining = transactions" -- pipelining is a network optimization; commands still interleave with other clients; MULTI/EXEC provides isolation.

**Quick Revision (1-liner):**
Redis single-threaded event loop = no lock contention, predictable latency; pipeline = batch N commands in 1 RTT; MULTI/EXEC = atomic but no rollback; Lua = atomic with conditional logic; never use KEYS * in production.

---

## Cheat Sheet

### Eviction Policies Quick Reference

| Policy | Eviction Pool | Selection | Use When |
|--------|--------------|-----------|----------|
| `noeviction` | None | Error on write | Persistent data only; never evict |
| `allkeys-lru` | All keys | Least recently used | Pure cache; all data in DB |
| `volatile-lru` | Keys with TTL | Least recently used | Mixed: cache + persistent data |
| `allkeys-lfu` | All keys | Least frequently used | Hot-key skewed access (Zipfian) |
| `volatile-lfu` | Keys with TTL | Least frequently used | Mixed; hot-key skewed |
| `allkeys-random` | All keys | Random | Uniform access; simplest |
| `volatile-random` | Keys with TTL | Random | Mixed; don't care which expires |
| `volatile-ttl` | Keys with TTL | Soonest to expire | Prioritize longer-lived entries |

**Rule of thumb:** Start with `allkeys-lfu` for caches; `volatile-lru` for mixed stores; monitor `evicted_keys` metric.

---

### Caching Patterns Comparison Table

| Pattern | Who handles miss | DB write | Cache write | Stale risk | Complexity | Best for |
|---------|-----------------|----------|-------------|-----------|------------|----------|
| Cache-Aside | Application | Direct | On miss | Yes (invalidation race) | Low | Read-heavy, irregular data |
| Read-Through | Cache library | Never | Automatic on miss | Yes | Medium | ORM/library-level caching |
| Write-Through | Application | Both (sync) | On every write | No (always fresh) | Medium | Read-heavy data that is also written |
| Write-Behind | Application | Async batch | On every write | Brief window | High | Write-heavy, eventual consistency OK |

---

### Redis Data Structure Selection Guide

| Use Case | Structure | Key Commands |
|----------|-----------|--------------|
| Simple cache value / counter | String | GET, SET, INCR |
| Object with field access | Hash | HGET, HSET, HMGET |
| FIFO queue / activity feed | List | LPUSH, RPOP, BRPOP |
| Unique membership / tagging | Set | SADD, SISMEMBER, SUNION |
| Leaderboard / sorted access | Sorted Set | ZADD, ZRANGE, ZRANGEBYSCORE |
| Boolean flag at scale (millions) | Bitmap | SETBIT, BITCOUNT |
| Cardinality estimation | HyperLogLog | PFADD, PFCOUNT |
| Reliable event log | Stream | XADD, XREADGROUP, XACK |

---

### Redis Persistence Decision Tree

```
Need durability?
+-- No  --> Disable persistence (maxmemory-policy allkeys-lru)
+-- Yes
    +-- Can lose up to minutes of data?
    |   +-- Yes --> RDB only (fast restart, small files)
    +-- Must lose less than 1 second?
        +-- RDB + AOF everysec --> hybrid persistence (recommended)
        +-- Zero data loss tolerated --> AOF always (low throughput)
```

---

### Common Redis CLI Commands for Interviews

```bash
# Info sections
redis-cli INFO server
redis-cli INFO memory
redis-cli INFO stats
redis-cli INFO replication
redis-cli INFO persistence

# Slowlog
redis-cli SLOWLOG GET 10
redis-cli SLOWLOG RESET

# Key inspection
redis-cli OBJECT ENCODING key
redis-cli OBJECT IDLETIME key
redis-cli OBJECT FREQ key
redis-cli DEBUG SLEEP 0

# Safe key scan (never KEYS * in prod)
redis-cli SCAN 0 MATCH "user:*" COUNT 100

# Cluster
redis-cli CLUSTER INFO
redis-cli CLUSTER NODES
redis-cli CLUSTER KEYSLOT mykey

# Memory analysis
redis-cli MEMORY USAGE key
redis-cli MEMORY DOCTOR

# Latency
redis-cli --latency
redis-cli LATENCY HISTORY event
```

---

*End of Chapter 12: Redis & Caching Strategies*

