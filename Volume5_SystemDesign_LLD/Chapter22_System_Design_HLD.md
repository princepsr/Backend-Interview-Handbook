# Volume 5: System Design & LLD
# Chapter 22: High-Level System Design

---

# Chapter 22 — High-Level System Design (Part A)
### Volume 5: System Design & Low-Level Design
**Target:** SDE2 / Senior Engineer | FAANG+ interviews

---

## Latency Numbers Every Engineer Must Know

| Operation | Latency |
|---|---|
| L1 cache reference | 0.5 ns |
| L2 cache reference | 7 ns |
| Main memory (RAM) access | 100 ns |
| SSD random read (4KB) | 150 µs |
| HDD random read | 10 ms |
| Send 1 KB over 1 Gbps network | 10 µs |
| Round trip within same datacenter | 500 µs |
| Round trip US to Europe | ~150 ms |
| Read 1 MB sequentially from SSD | 1 ms |
| Read 1 MB sequentially from HDD | 20 ms |
| Read 1 MB sequentially from RAM | 250 µs |
| Mutex lock/unlock | 25 ns |
| Send packet CA → Netherlands → CA | 150 ms |

**Rules of thumb:**
- Memory access is ~200x faster than SSD
- SSD is ~80x faster than HDD
- Same datacenter round-trip: ~0.5 ms
- Cross-continent round-trip: ~150 ms

---

### Topic 1: System Design Interview Framework
**Difficulty:** Medium | **Frequency:** Universal | **Companies:** Google, Meta, Amazon, Microsoft, Apple, Uber, Netflix

**Q:** How do you approach an open-ended system design interview question like "Design Twitter" or "Design a ride-sharing system"?

**Short Answer:** A structured framework prevents rambling and signals seniority. The RADIO framework (Requirements, API, Data model, Implementation, Optimizations) gives a repeatable skeleton that works for virtually any system design question in a 45–60 minute interview.

**Deep Explanation:**

The RADIO Framework broken down:

**R — Requirements (5–10 min)**
Start with clarifying questions. Never assume. Interviewers often intentionally leave the problem vague to see if you gather requirements.

Functional requirements: What should the system do? Core use-cases only. Example for Twitter: post tweets, follow users, view timeline, search.

Non-functional requirements: Scale (DAU, MAU), availability (99.9% vs 99.999%), consistency (strong vs eventual), latency targets (< 200 ms for feed), durability, security.

Out-of-scope: Explicitly state what you are NOT designing (e.g., "I'll skip ads and notifications for now").

Questions to always ask:
- How many daily active users?
- Read-heavy or write-heavy?
- Global or single region?
- What is the acceptable latency for read/write?
- Any existing infrastructure constraints?

**A — API Design (5–7 min)**
Define the public API surface. Use REST-style pseudo-code. This forces you to think about data contracts before jumping to implementation. Mention API versioning and authentication (OAuth2/API keys) briefly.

**D — Data Model (5–10 min)**
Identify entities, relationships, and which database fits (SQL vs NoSQL). Estimate data size. This is a natural lead-in to schema design and storage choices.

**I — Implementation (15–20 min)**
This is the bulk of the interview. Draw a high-level architecture with components: clients, CDN, load balancers, API gateway, microservices, caches, message queues, databases. Trace a request flow end-to-end for your primary use case. Discuss trade-offs at each component.

**O — Optimizations (5–10 min)**
Address bottlenecks you intentionally deferred. Common areas: caching strategy, database sharding, read replicas, async processing with queues, CDN for static assets, geographic distribution.

**Time Allocation for 45-minute interview:**

```
[ 0–10 min ] Requirements + capacity estimation
[ 10–17 min ] API design + data model
[ 17–37 min ] High-level architecture + component deep-dives
[ 37–45 min ] Optimizations, failure modes, trade-off discussion
```

**Signals of seniority:**
- Leads the conversation, doesn't wait to be guided
- Calls out trade-offs explicitly ("We could use SQL here for strong consistency, but at our write volume we'd need sharding, which adds operational complexity — so I'd prefer Cassandra")
- Acknowledges uncertainty ("I'd validate this with a load test in practice")
- Mentions operational concerns: monitoring, alerting, deployment, rollback

**Real-World Example:** Google's design interviews specifically test whether you can operate at the right altitude. A common trap is diving too deep into one component (e.g., spending 20 minutes on database schema) while neglecting the overall system. Senior engineers at Google learn to timebox component depth and keep the end-to-end flow visible.

**Architecture Diagram:**

```
RADIO Framework Timeline
========================

|--Requirements--|--API--|--Data Model--|--Implementation (core)--|--Optimizations--|
0               10      17             22                        37               45
                                                                             (minutes)

Implementation deep-dive structure:
  Client --> CDN --> Load Balancer --> API Gateway --> Services --> [Cache / DB / Queue]
     ^                                                                        |
     |________________________ response path _________________________________|
```

**Follow-up Questions:**
1. How do you handle the case where requirements change mid-interview?
2. How do you decide when to use SQL vs NoSQL in a design interview context?
3. What is the difference between availability and consistency — and how does CAP theorem guide your storage choice?

**Common Mistakes:**
- Jumping straight to drawing boxes without clarifying scale (the design for 1K users looks nothing like the one for 100M)
- Spending the entire interview on one component and never connecting it to the full system
- Not asking about read/write ratio — it dramatically changes the architecture

**Interview Traps:**
- Interviewer says "just assume 1 million users" — this is a trap: always ask read vs write ratio, geographic distribution, and peak-to-average ratio
- Being too vague with "just add more servers" — the interviewer wants to know WHERE and HOW, with concrete trade-offs

**Quick Revision:** RADIO = Requirements → API → Data model → Implementation → Optimizations; timebox each phase, lead the conversation.

---

### Topic 2: Scalability Fundamentals
**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Amazon, Google, Meta, Stripe, Shopify

**Q:** Explain horizontal vs vertical scaling and when you would choose each. How do stateless services enable horizontal scaling?

**Short Answer:** Vertical scaling adds more power to a single machine (bigger CPU, more RAM); it has a ceiling and creates a single point of failure. Horizontal scaling adds more machines; it requires services to be stateless so any instance can serve any request, which in turn enables load balancing and auto-scaling.

**Deep Explanation:**

**Vertical Scaling (Scale Up)**
- Increase CPU cores, RAM, storage on one machine
- Simple — no application changes needed
- Ceiling: largest available instance type (e.g., AWS u-24tb1.metal has 448 vCPUs, 24 TB RAM — but costs ~$220/hr)
- Single point of failure
- Good for: databases (initially), stateful workloads, licensing constraints (Oracle charges per core)
- Downtime risk: requires restart for hardware changes

**Horizontal Scaling (Scale Out)**
- Add more instances of the same type
- Theoretically unbounded — just add more nodes
- Requires load balancing to distribute traffic
- Requires stateless application design
- More complex operationally (service discovery, distributed tracing)
- Good for: web servers, API servers, microservices, stateless compute

**Stateless Services — the key enabler:**
A stateless service holds no session or user state in local memory. Every request carries all information needed to process it (via JWT token, session ID pointing to external store, etc.). This means any instance can serve any request — the load balancer can freely route traffic.

State must live outside the service: in a distributed cache (Redis/Memcached), database, or cookie.

Common trap: storing session in memory (HashMap) on a single server — works until you have 2 servers, then 50% of requests go to the wrong server.

**Load Balancing Strategies:**

| Strategy | How It Works | Best For | Weakness |
|---|---|---|---|
| Round-robin | Requests distributed evenly in sequence | Homogeneous, stateless services | Ignores server load |
| Weighted round-robin | Distribute proportionally by server capacity | Mixed instance sizes | Static weights |
| Least connections | Route to server with fewest active connections | Long-lived connections (WebSocket) | Overhead of tracking state |
| Least response time | Route to fastest-responding server | Latency-sensitive APIs | Measurement lag |
| IP hash | Hash client IP to server | Sticky sessions without cookies | Uneven distribution if few clients |
| Consistent hashing | Hash request key to ring | Distributed caches, microservices | Complexity |
| Random | Random server selection | Simple homogeneous fleets | Not ideal for long connections |

**Auto-Scaling:**
Cloud auto-scaling watches metrics (CPU%, memory, custom — e.g., queue depth) and adds/removes instances. Key concepts:
- Scale-out policy: add instances when CPU > 70% for 2 minutes
- Scale-in policy: remove instances when CPU < 30% for 10 minutes (with cooldown to avoid thrashing)
- Predictive scaling: pre-warm instances before expected load spike (e.g., Black Friday)
- Launch template: pre-baked AMI with your app so new instances are ready in ~90 seconds

**Real-World Example:** Netflix uses horizontal scaling exclusively for its stateless API tier. Every streaming request is stateless — session data is in JWT tokens and viewing state is in Cassandra. Their Chaos Monkey deliberately kills instances to prove the system is resilient. At peak, Netflix serves ~15% of global internet traffic from horizontally scaled pods on AWS.

**Architecture Diagram:**

```
Vertical Scaling:              Horizontal Scaling:
=====================          =====================
      [Big Server]                  [LB]
      CPU: 64 cores                  |
      RAM: 512 GB           +--------+--------+
      Limit: hardware       |        |        |
      SPOF: yes          [Srv1]  [Srv2]  [Srv3]
                         small   small   small
                         stateless instances
                         Session state --> [Redis]
```

**Follow-up Questions:**
1. What happens to in-flight requests when you scale in (remove an instance)?
2. How do you handle database scaling — horizontal scaling is harder for databases, why?
3. What is the difference between auto-scaling groups and Kubernetes horizontal pod autoscaling?

**Common Mistakes:**
- Assuming horizontal scaling is always the right answer — for relational databases, vertical scaling is often the pragmatic first step
- Forgetting that horizontal scaling requires a load balancer, which itself can become a bottleneck or SPOF
- Not addressing state management when claiming a service is "horizontally scalable"

**Interview Traps:**
- "Just scale horizontally" without addressing how state is externalized — interviewer will probe this immediately
- Vertical vs horizontal is not binary — you often do both (scale up the DB, scale out the API tier)

**Quick Revision:** Stateless + load balancer = horizontal scaling; externalize all state to cache/DB; vertical scaling is simpler but has a hard ceiling.

---

### Topic 3: Load Balancer Deep Dive
**Difficulty:** Medium-High | **Frequency:** High | **Companies:** Google, Cloudflare, Amazon, Meta, Stripe

**Q:** Explain the difference between L4 and L7 load balancers. When would you use each, and what are the trade-offs?

**Short Answer:** L4 load balancers operate at the transport layer (TCP/UDP) and route based on IP and port — they are faster but less intelligent. L7 load balancers inspect HTTP content (headers, URL, cookies) and enable content-based routing, SSL termination, and session stickiness — more powerful but with higher latency overhead.

**Deep Explanation:**

**L4 Load Balancer (Transport Layer)**
Operates on TCP/UDP. Sees: source IP, destination IP, port. Does NOT see: HTTP headers, URL path, cookies, body content.

How it works: receives a TCP connection, forwards it to a backend server using NAT or IP tunneling. Very fast — minimal processing.

Use cases:
- Raw TCP traffic (non-HTTP protocols: database proxies, game servers, SMTP)
- Extremely latency-sensitive applications (microsecond budgets)
- When you need maximum throughput with minimal overhead

Examples: AWS Network Load Balancer (NLB), HAProxy in TCP mode, Linux IPVS

**L7 Load Balancer (Application Layer)**
Operates at HTTP/HTTPS. Sees: URL path, HTTP method, headers, cookies, query params, body.

Capabilities:
- Path-based routing: /api/* → API servers, /static/* → CDN origin
- Host-based routing: api.example.com → API cluster, admin.example.com → admin cluster
- Header-based routing: X-Feature-Flag: beta → canary instances
- SSL/TLS termination (decrypt once at LB, send plaintext to backend)
- HTTP/2 multiplexing, gRPC routing
- Session stickiness via cookies
- Compression (gzip at the LB)
- Rate limiting, WAF integration

Examples: AWS Application Load Balancer (ALB), Nginx, HAProxy in HTTP mode, Envoy, Traefik

**SSL Termination at L7 LB:**
Decrypt HTTPS at the load balancer, forward HTTP to backends. Benefits: backends are simpler (no TLS handling), certificate management is centralized, LB can inspect/modify requests. Downside: traffic from LB to backend is unencrypted (mitigated by placing both in a VPC with no external access).

**Sticky Sessions (Session Affinity):**
Routes the same client to the same backend server. Implemented via:
- Cookie-based: LB injects a cookie with server ID
- IP hash: consistent mapping of client IP to server

Problem: breaks horizontal scaling benefits. If server A has 60% of sticky sessions and dies, those users lose their sessions. Best practice: externalize session state to Redis instead of relying on sticky sessions.

**Health Checks:**
LBs probe backends regularly. Active health check: LB sends HTTP GET /health every 5 seconds; if 3 consecutive failures, mark unhealthy and stop routing. Passive health check: monitor live traffic error rates.

Critical: your /health endpoint must check downstream dependencies (DB connection, cache) — otherwise the LB sends traffic to a server that can't fulfill requests.

**Active-Active vs Active-Passive LB:**
- Active-Active: two LBs both serve traffic, use BGP Anycast or DNS round-robin to distribute between them. Full capacity, no idle resources, both can fail independently.
- Active-Passive: one LB serves all traffic; passive standby ready to take over via VIP/Floating IP (e.g., Keepalived VRRP). Simpler failover, but standby capacity is idle.

**Real-World Example:** Netflix uses a multi-tier load balancing architecture: AWS ALB (L7) in front of API services for HTTP routing and SSL termination, and AWS NLB (L4) for their lower-latency data plane. Inside their cluster, they use Envoy as a sidecar L7 proxy for service-to-service routing (part of their service mesh). Eureka (their service registry) provides the list of healthy backends to client-side load balancers (Ribbon/Spring Cloud LoadBalancer).

**Architecture Diagram:**

```
Internet
   |
[DNS / Anycast]
   |
+--+--+          +--+--+
| LB1 |----------| LB2 |   Active-Active pair
+--+--+          +--+--+
   |
+--+---+---+---+
|      |   |   |
[A1] [A2] [A3] [A4]   Backend API servers
                  |
               [/health endpoint]
               checks: DB ping, Redis ping

L4 vs L7 inspection:
  L4: [IP:port] -> route        (fast, ~10 µs overhead)
  L7: [IP:port + HTTP headers] -> route  (flexible, ~100 µs overhead)
```

**Follow-up Questions:**
1. How does a load balancer avoid the thundering herd problem when a backend recovers after being marked unhealthy?
2. What is connection draining and why is it important for deployments?
3. How does Envoy differ from Nginx as a load balancer in a Kubernetes service mesh?

**Common Mistakes:**
- Confusing SSL termination with SSL passthrough (passthrough means LB forwards encrypted traffic to backends, which must handle TLS — no HTTP inspection possible)
- Using sticky sessions as a substitute for proper session management — sticky sessions are a band-aid
- Not mentioning health checks — a design without health checks has silent single points of failure

**Interview Traps:**
- "What happens when the load balancer itself goes down?" — answer: active-active pair, DNS failover, or cloud-managed LB (AWS ALB is regionally redundant by design)
- Assuming L7 LB is always better — for non-HTTP TCP workloads, L4 is correct and faster

**Quick Revision:** L4 = TCP/IP routing (fast, dumb); L7 = HTTP-aware routing (smart, SSL termination, path-based routing); always add health checks; prefer externalized session state over sticky sessions.

---

### Topic 4: CDN & Edge Computing
**Difficulty:** Medium | **Frequency:** High | **Companies:** Cloudflare, Akamai, Netflix, Amazon, Meta

**Q:** How does a CDN work, and when should you use push vs pull CDN? What is edge computing and how does it extend the CDN model?

**Short Answer:** A CDN is a geographically distributed network of cache servers (Points of Presence / PoPs) that serve content from locations physically closer to users, reducing latency and origin load. Pull CDN fetches content from origin on first request; push CDN requires you to proactively upload content to edge nodes.

**Deep Explanation:**

**CDN Architecture:**
User request → DNS resolves to nearest CDN PoP (via Anycast or GeoDNS) → PoP checks local cache → Cache HIT: serve immediately → Cache MISS: fetch from origin, cache locally, serve to user.

CDN PoPs are distributed globally (Cloudflare has 300+ locations, Akamai has 4000+). The key benefit: instead of a user in Singapore hitting a server in US-East (150 ms RTT), they hit a Singapore PoP (5 ms RTT).

**Pull CDN:**
- Origin server is the source of truth
- CDN fetches content on first cache miss and caches it at the PoP
- Subsequent requests from same region served from cache
- TTL (Time-To-Live) in Cache-Control header determines how long cached
- Pros: simple setup, no manual upload, good for content you update frequently
- Cons: first request has full origin latency (cache miss), if PoP has never served this asset, it's a miss

**Push CDN:**
- You proactively upload content to CDN nodes before any user requests it
- Good for static content that changes infrequently: software binaries, large video files, firmware updates
- Pros: zero cache miss latency for first request, predictable behavior
- Cons: you must manage what's uploaded and purged, storage costs even for unused assets, not suitable for dynamic content

**Cache-Control Headers (critical for interviews):**

```
Cache-Control: max-age=86400, public          // Cache for 24h, shareable by CDN
Cache-Control: no-cache                        // Must revalidate with origin on every request
Cache-Control: no-store                        // Never cache (sensitive data)
Cache-Control: s-maxage=3600                   // CDN-specific TTL (overrides max-age for CDN)
Cache-Control: stale-while-revalidate=60       // Serve stale content while fetching fresh
ETag: "abc123"                                 // Fingerprint for conditional requests
Vary: Accept-Encoding                          // Cache separate copies per encoding
```

**Cache Invalidation Strategies:**
- TTL expiry: simple, but stale content until TTL expires
- URL versioning: /assets/main.a3f4b8.js — fingerprint in filename, new deploy = new URL, old URL cached forever (ideal)
- API purge: CDN API call to invalidate specific keys (Cloudflare Cache Purge API) — use sparingly, expensive at scale
- Surrogate keys / Cache tags: tag cached objects, purge all objects with a given tag (e.g., purge all pages tagged product-id:12345)

**Edge Computing:**
CDN evolved beyond caching static files. Edge compute allows running code at CDN PoPs:
- Cloudflare Workers: JavaScript running at 300+ PoPs, ~0 cold start
- AWS Lambda@Edge: runs at CloudFront PoPs (limited regions vs Workers)
- Fastly Compute@Edge: WebAssembly at edge

Use cases for edge compute:
- A/B testing (modify response at edge without origin round-trip)
- Authentication token validation at edge (reject bad requests before hitting origin)
- Geographic content personalization
- Request/response transformation (add security headers)
- Bot detection and WAF logic
- Dynamic personalization of cached HTML

**When to use CDN:**
- Static assets: JS, CSS, images, fonts — always
- Video streaming — always (HLS/DASH segments from CDN)
- API responses that are cacheable (GET /products — cache for 60 seconds)
- Protection against DDoS (CDN absorbs volumetric attacks)

**When NOT to use CDN:**
- Highly personalized responses (cannot be shared across users)
- Real-time data (stock prices, chat messages)
- POST/PUT/DELETE (not cacheable)

**Real-World Example:** Netflix built its own CDN called Open Connect. They place physical appliances (servers with 100+ TB SSD storage) inside ISP networks. At peak, Netflix serves ~95% of its traffic from Open Connect appliances within the ISP's network — users never leave their ISP's network to fetch video bytes. This eliminates inter-ISP bandwidth costs and reduces latency dramatically. Netflix uses a push model — they proactively replicate popular titles to edge appliances based on predicted demand.

**Architecture Diagram:**

```
User (Singapore)                     Origin Server (US-East)
      |                                      |
      | DNS lookup                           |
      v                                      |
[Anycast/GeoDNS] -------> [Singapore PoP]   |
                                |            |
                         Cache HIT? -------> YES --> serve (5 ms)
                                |
                               NO
                                |
                         Fetch from origin (150 ms round trip)
                                |
                         Cache at PoP
                                |
                         Serve to user

Push CDN: you --> [origin] --> [upload to all PoPs proactively]
Pull CDN: user --> [PoP] --cache miss--> [origin] --> [cache] --> [user]
```

**Follow-up Questions:**
1. How do you handle cache invalidation for a news website where articles are updated frequently?
2. What is the difference between CDN and a reverse proxy?
3. How would you use edge computing to implement personalized content without sacrificing cacheability?

**Common Mistakes:**
- Assuming CDN is only for static files — modern CDNs cache API responses too
- Not setting appropriate TTLs — infinite TTL for frequently updated content causes stale data; too short TTL defeats CDN purpose
- Forgetting cache invalidation strategy in system design answers

**Interview Traps:**
- "CDN solves all performance problems" — CDN only helps for cacheable, read-heavy, global content; it adds latency for dynamic, personalized content that must hit origin anyway
- Not distinguishing between CDN for assets vs CDN for API acceleration

**Quick Revision:** CDN = geo-distributed cache; pull = lazy fetch on miss; push = proactive upload; edge compute = code at PoP; use URL versioning + long TTL for static, short TTL + stale-while-revalidate for semi-dynamic.

---

### Topic 5: Consistent Hashing in System Design
**Difficulty:** High | **Frequency:** High | **Companies:** Amazon, Google, Meta, Uber, Redis Labs

**Q:** What is consistent hashing, why is it used in distributed systems, and what problem does it solve compared to simple modulo hashing?

**Short Answer:** Consistent hashing maps both data keys and server nodes onto a circular hash ring; each key is served by the first server clockwise from its hash position. When a node is added or removed, only keys in that node's arc need to be remapped — typically 1/N of all keys — rather than remapping nearly all keys as simple modulo hashing would.

**Deep Explanation:**

**The Problem with Naive Modulo Hashing:**
server = hash(key) % N

If N changes (server added or removed), almost all keys remap to different servers. In a caching scenario, this means a cache miss storm — every key previously cached hits the origin. For a system with 1 billion cached objects and 10 servers, adding 1 server causes ~91% of keys to remap (from hash(key) % 10 to hash(key) % 11).

**Consistent Hashing — the Hash Ring:**
1. Hash the address space to a ring [0, 2^32-1] (or [0, 2^64-1])
2. Hash each server node to a position on the ring
3. Hash each key to a position on the ring
4. Each key is owned by the first server encountered moving clockwise from the key's position

Adding a server S_new: only keys between S_new's predecessor and S_new itself need to remigrate. On average, K/N keys (where K = total keys, N = number of servers).

Removing server S: its keys are taken over by the next server clockwise. Only S's keys need to move — average K/N keys.

**Virtual Nodes (vnodes) — solving uneven distribution:**
With a small number of real servers, positions on the ring can cluster, causing some servers to own much larger arcs (hot spots). Solution: each physical server is represented by V virtual nodes, each mapped to different positions on the ring.

- More uniform key distribution
- V=150 virtual nodes per server is a common production default (Cassandra default: 256)
- When a server is added, its virtual nodes steal keys from multiple existing servers — natural load spreading
- Allows weighting: a more powerful server gets more virtual nodes

**Chord Protocol:**
Academic consistent hashing foundation (Stoica et al., 2001). Each node maintains a "finger table" of O(log N) other nodes for O(log N) lookup hops. In practice, DHT-based P2P systems (BitTorrent, Kademlia) and distributed databases use variants of this.

**Where consistent hashing is used in production:**

| System | Usage |
|---|---|
| Amazon DynamoDB | Partition key hashed to determine which partition owns the data |
| Apache Cassandra | Partitioner (Murmur3Partitioner) uses consistent hashing to assign rows to nodes |
| Redis Cluster | 16,384 hash slots distributed across nodes; slot = CRC16(key) % 16384 |
| Memcached clients | libketama library implements consistent hashing for client-side server selection |
| Nginx/HAProxy upstream | Consistent hash load balancing for caching proxies |
| Vimeo, Discord | CDN request routing to cache nodes |

**Hotspot mitigation:**
Even with virtual nodes, if a specific key gets extreme traffic (celebrity user, viral post), consistent hashing doesn't help — all traffic for that single key still goes to one node. Solutions: application-level key sharding (add random suffix to key), read replicas, local in-process caching for ultra-hot keys.

**Real-World Example:** Amazon DynamoDB Partition Internals — DynamoDB uses consistent hashing with virtual nodes to distribute data across storage nodes. When you add capacity to a DynamoDB table, new partitions are provisioned and the ring rebalances without downtime. The partition key determines the hash ring position. DynamoDB engineers noted in their 2022 paper that they use 100+ virtual nodes per partition server to maintain uniform distribution even during rebalancing events.

**Architecture Diagram:**

```
Consistent Hash Ring (3 servers, simplified):

              Key "user:123" (hash=45)
              lands at Server B (next clockwise)
                       |
          0            v          2^32
          |----[A:10]---[B:50]---[C:80]----|  (ring wraps around)

  Adding Server D at position 65:
    [A:10]---[B:50]---[D:65]---[C:80]
    Only keys in range (50, 65] move from C to D
    (approximately 1/N of total keys)

  Virtual Nodes (more realistic):
    A_1:8,  B_1:22, C_1:35,
    A_2:48, B_2:55, C_2:70,
    A_3:85, B_3:92, C_3:98
    --> Keys are spread much more evenly
```

**Follow-up Questions:**
1. How does Redis Cluster differ from pure consistent hashing — why does it use 16,384 fixed hash slots instead?
2. What happens to in-flight requests to a node that is being removed in a live Cassandra cluster?
3. How would you implement client-side consistent hashing in Java for a Memcached client pool?

**Common Mistakes:**
- Confusing the hash ring with a sorted array — the ring is a conceptual model; implementation typically uses a sorted map (TreeMap in Java) with O(log N) lookups
- Forgetting that virtual nodes solve distribution but not hot individual keys
- Claiming consistent hashing eliminates all rebalancing — it minimizes it, but 1/N of keys still move

**Interview Traps:**
- "Consistent hashing solves the thundering herd on cache miss" — NO, it only solves the redistribution problem when topology changes; a cold cache with all misses still thunders to origin
- Redis Cluster uses hash slots (not a pure ring) — interviewers at Redis Labs will catch you if you say Redis uses a hash ring

**Quick Revision:** Consistent hashing = hash ring; add/remove node remaps only 1/N keys; virtual nodes fix uneven distribution; used in Cassandra, DynamoDB, Redis Cluster.

---

### Topic 6: Back-of-Envelope Estimation
**Difficulty:** Medium | **Frequency:** Universal | **Companies:** All FAANG+, all system design interviews

**Q:** How do you perform back-of-envelope calculations in a system design interview? Walk through a storage and throughput estimation for a large-scale system.

**Short Answer:** Back-of-envelope estimation demonstrates that you can reason about scale before committing to an architecture. Use powers of 2, round aggressively to the nearest order of magnitude, and always state your assumptions explicitly. The goal is "right order of magnitude" — being off by 2x is fine, off by 100x is not.

**Deep Explanation:**

**Powers of 2 — Memory:**

| Power | Approx Value | Name |
|---|---|---|
| 2^10 | ~1 thousand | 1 KB |
| 2^20 | ~1 million | 1 MB |
| 2^30 | ~1 billion | 1 GB |
| 2^40 | ~1 trillion | 1 TB |
| 2^50 | ~1 quadrillion | 1 PB |

**Common conversion shortcuts:**
- 1 day = 86,400 seconds ≈ 100K seconds
- 1 month ≈ 2.5 million seconds
- 1 year ≈ 30 million seconds
- 1 billion requests/day ≈ 11,600 requests/second ≈ ~12K QPS
- 1 million requests/day ≈ 12 QPS

**QPS Calculation Template:**
```
QPS = DAU × avg_requests_per_user_per_day / 86,400
Peak QPS ≈ 2× to 5× average QPS (use 3× as default)
```

**Storage Estimation Template:**
```
Storage = DAU × avg_data_generated_per_user_per_day × retention_period
```

**Worked Example: Design Twitter (or X)**

Assumptions (state these):
- 300M DAU
- Average user reads 50 tweets/day, writes 1 tweet/day
- Average tweet: 140 chars = 140 bytes text + 50 bytes metadata = ~200 bytes
- 30% of tweets have an image (300KB avg) or video (10MB avg)

QPS calculation:
```
Write QPS = 300M × 1 tweet/day / 86,400 = ~3,500 writes/sec
Read QPS  = 300M × 50 reads/day / 86,400 = ~175,000 reads/sec
Read:Write ratio = 50:1 (read-heavy -> design for read optimization)
Peak Write QPS ≈ 3× = ~10,000/sec
Peak Read QPS  ≈ 3× = ~500,000/sec
```

Storage calculation:
```
Text storage/day  = 300M tweets × 200 bytes = 60 GB/day
Image storage/day = 300M × 0.30 × 300 KB   = 27 TB/day
5-year text storage = 60 GB × 365 × 5      = ~110 TB (manageable in a DB)
5-year media storage = 27 TB × 365 × 5     = ~50 PB (requires object storage like S3)
```

**Worked Example: Design WhatsApp Messages**

Assumptions:
- 2B users, 50M DAU
- Average 40 messages/day per active user
- Average message: 100 bytes text
- 20% messages have media: 200 KB avg

QPS:
```
Message QPS = 50M × 40 / 86,400 = ~23,000 msg/sec
Peak = 3× = ~70,000 msg/sec
```

Storage:
```
Text/day = 50M × 40 × 100 bytes = 200 GB/day
Media/day = 50M × 40 × 0.20 × 200 KB = 80 TB/day
```

**Bandwidth estimation:**
```
Incoming bandwidth = storage_per_day / 86,400 = 80 TB / 86,400 sec ≈ 1 GB/sec incoming
```

**Cache sizing:**
80-20 rule: 20% of content generates 80% of requests. Cache the hot 20%.
```
Daily active data = 200 GB text/day
Hot 20% = 40 GB → fits in Redis on a single 64 GB node with room to spare
```

**Real-World Example:** Jeff Dean's latency numbers (from his 2012 "Building Software Systems at Google" talk) became the industry standard reference. Google engineers are expected to know these numbers cold. The ability to do back-of-envelope estimation is explicitly tested in Google's interview guide — they want to see whether you can quickly determine if a solution is feasible before spending 20 minutes designing something that violates physical limits.

**Architecture Diagram:**

```
Estimation Workflow:
====================

1. Get DAU / MAU from interviewer or estimate
        |
2. Calculate average QPS
   QPS = DAU x requests_per_user / 86,400
        |
3. Apply peak multiplier (3x default)
        |
4. Calculate storage per day
   Storage = DAU x data_per_user
        |
5. Multiply by retention period (5 years typical)
        |
6. Derive bandwidth (storage/day / 86,400 = bytes/sec)
        |
7. Use to justify architecture choices:
   QPS > 10K/sec  -> need multiple API servers
   Storage > 1 TB -> need sharded DB or object store
   Read:Write > 10:1 -> add read replicas / caching layer
```

**Follow-up Questions:**
1. If peak QPS is 500K/sec for reads and each server handles 10K reads/sec, how many servers do you need, and what's your redundancy strategy?
2. How do you estimate the number of database partitions needed for a given QPS?
3. At 50 PB of media storage, compare cost of S3 vs building your own storage — when does building your own make sense?

**Common Mistakes:**
- Not stating assumptions before calculating — interviewer has no idea what numbers you used
- Being too precise: "3,472 QPS" instead of "~3,500 QPS" — this wastes time and signals you don't understand estimation
- Forgetting the peak multiplier — systems are designed for peak, not average

**Interview Traps:**
- Interviewer gives you no numbers — this is intentional, estimate DAU from public knowledge ("Twitter has ~300M DAU, I'll use that")
- You calculate 50 PB of storage and say "just use a single database" — the interviewer is testing whether storage estimates inform your architecture

**Quick Revision:** QPS = DAU × req/user / 86,400; peak = 3× avg; storage = DAU × data/user × retention; use powers of 2; state assumptions before calculating.

---

### Topic 7: Design a URL Shortener (High-Level Design)
**Difficulty:** Medium | **Frequency:** Very High | **Companies:** Google (goo.gl), Bitly, TinyURL, Twitter, Meta

**Q:** Design a URL shortening service like Bitly or TinyURL. Walk through the full system design.

**Short Answer:** A URL shortener maps a long URL to a short 6-8 character code stored in a database; a redirect service resolves the code and returns a 301/302 to the original URL. The key challenges are: generating unique short codes at scale, low-latency resolution (< 10 ms), analytics tracking, and handling 10:1 redirect-to-create ratios.

**Deep Explanation:**

**Requirements Clarification:**

Functional:
- POST /shorten(longUrl) → shortUrl
- GET /{shortCode} → redirect to longUrl
- Custom aliases (e.g., bit.ly/my-custom-name)
- Link expiry (TTL)
- Click analytics (total clicks, geographic distribution, referrer)

Non-functional:
- 100M new URLs shortened per day
- 10B redirects per day (100:1 read:write ratio)
- Availability: 99.99% (URL resolution is critical — links embedded in emails, marketing campaigns)
- Redirect latency: < 10 ms (P99)
- Short codes: 6-8 characters

**Capacity Estimation:**
```
Write QPS = 100M / 86,400 ≈ 1,160 writes/sec → ~1.2K writes/sec
Read QPS  = 10B  / 86,400 ≈ 115,740 reads/sec → ~116K reads/sec

Short code length:
  6-char base62 (a-z, A-Z, 0-9) = 62^6 ≈ 56 billion combinations
  100M URLs/day × 365 × 10 years = 365 billion → need 7+ chars
  7-char base62 = 62^7 ≈ 3.5 trillion combinations → sufficient for decades

Storage per URL:
  longUrl: 2,048 bytes (max URL length), shortCode: 7 bytes, metadata: ~100 bytes
  Total: ~2.2 KB per record
  100M records/day × 2.2 KB = ~220 GB/day
  10 years = 803 TB → needs sharded storage
```

**API Design:**
```
POST /api/v1/shorten
  Body: { "longUrl": "https://...", "customAlias": "optional", "expiryDate": "optional" }
  Response: { "shortUrl": "https://short.ly/aB3xYz7" }
  Auth: API key in header

GET /{shortCode}
  Response: 301 Redirect to longUrl (301 = permanent, browser caches; 302 = temporary, no browser cache)
  Note: Use 302 for analytics tracking; 301 reduces server load but you lose click tracking

GET /api/v1/stats/{shortCode}
  Response: { "clicks": 1234567, "geoDistribution": [...], "referrers": [...] }
```

**Encoding Algorithm — three approaches:**

1. **Hash-based (MD5/SHA256 + truncation):**
   - MD5(longUrl) → 128-bit hash → take first 43 bits → base62 encode → 7-char code
   - Problem: hash collisions (two different URLs produce same first 43 bits)
   - Collision resolution: append counter and rehash until unique
   - Stateless: can be generated without DB roundtrip but needs DB check for collision

2. **ID generator + base62 encoding (recommended):**
   - Use distributed ID generator (Snowflake or database auto-increment) to get a unique 64-bit integer
   - Base62 encode the integer: 56 billion = 7 chars in base62
   - No collisions by construction
   - Predictable? Yes — sequential IDs are incrementing. If this is a concern, scramble bits before encoding

3. **Random code with DB uniqueness check:**
   - Generate random 7-char base62 string
   - Check if it exists in DB
   - Retry on collision (probability very low with 3.5 trillion space)

**Database Schema:**

```
Table: url_mapping
  short_code    CHAR(7)  PRIMARY KEY
  long_url      VARCHAR(2048) NOT NULL
  user_id       BIGINT   (nullable for anonymous)
  created_at    TIMESTAMP
  expires_at    TIMESTAMP (nullable)
  click_count   BIGINT DEFAULT 0  (approximation only — use separate analytics for precision)

Table: click_events (append-only, write to Kafka → analytics DB)
  short_code    CHAR(7)
  clicked_at    TIMESTAMP
  user_agent    VARCHAR(512)
  ip_hash       VARCHAR(64)  (hashed for privacy)
  referrer      VARCHAR(2048)
```

**Database Choice:**
- url_mapping: reads dominate (116K QPS reads vs 1.2K writes), simple key-value access pattern → Redis for hot cache, Cassandra or DynamoDB for primary storage (high write throughput, horizontal scaling)
- Alternatively: MySQL/Postgres with read replicas + Redis cache (simpler operationally for < 100K QPS)

**Caching Layer:**
```
Hot URLs (top 20% URLs get 80% of traffic):
  LRU cache in Redis: cache shortCode → longUrl with TTL=24h
  Cache hit rate target: > 99% (means < 1,160 reads/sec to DB)
  Memory: 100M most popular URLs × 2.2 KB = ~220 GB → 3-4 Redis nodes
```

**Redirect Latency Optimization:**
```
Request path with cache:
  Client → [CDN/Edge] → [API server] → [Redis] → 302 response
  Latency: ~5-15 ms

Request path without cache:
  Client → [CDN/Edge] → [API server] → [DB] → 302 response
  Latency: ~50-100 ms (acceptable but not ideal for hot URLs)
```

**Analytics Architecture:**
Do not write analytics to the main DB on each redirect (write amplification, slows down critical read path). Instead:
1. On each redirect, publish event to Kafka topic `click_events`
2. Stream consumer (Flink/Spark Streaming) aggregates by time windows
3. Write aggregated results to Cassandra or ClickHouse for OLAP queries
4. Real-time dashboard reads from ClickHouse

**Scaling Discussion:**
- Short code generation: use Zookeeper to hand out ID ranges to each API server (range-based ID allocation) → no single-point ID bottleneck
- Geo-distribution: deploy in multiple regions; replication of url_mapping across regions; writes go to primary region, reads from local region
- Custom aliases: check alias availability in DB, store with is_custom=true flag; rate-limit custom alias creation per user

**Real-World Example:** Bitly processes ~10 billion redirects per month. Their architecture evolved from a monolithic PHP app to a distributed Go-based system. They use Cassandra for primary storage (horizontal scale, high availability), Redis for caching hot links, Kafka for click event streaming, and their own in-house analytics pipeline. They open-sourced NSQD, their message queue, which was originally built for exactly this kind of analytics fanout workload.

**Architecture Diagram:**

```
                    [Client]
                       |
              [DNS] --> [CDN Edge]  <-- cache popular 302 redirects at edge
                       |
                  [Load Balancer]
                       |
              +--------+--------+
              |        |        |
           [API-1]  [API-2]  [API-3]   stateless API servers
              |
     +--------+--------+
     |                 |
  [Redis Cache]    [Cassandra Cluster]
  hot shortCode     primary storage
  → longUrl         sharded by shortCode

Shorten flow:
  POST /shorten → ID Generator → base62 encode → write to Cassandra → return shortUrl

Redirect flow:
  GET /{code} → check Redis → HIT: 302 redirect
                           → MISS: check Cassandra → 302 redirect + cache result

Analytics flow:
  Each redirect → async write to [Kafka] → [Flink] → [ClickHouse] → [Dashboard]
```

**Follow-up Questions:**
1. How do you handle custom aliases and prevent collisions with auto-generated codes?
2. Why use 302 (temporary redirect) instead of 301 (permanent redirect) for analytics — and when would you prefer 301?
3. How do you design the system to handle a single viral link getting 10 million redirects per minute (thundering herd)?

**Common Mistakes:**
- Using only a single database without caching — at 116K reads/sec, a single DB node will be saturated
- Storing click analytics in the main url_mapping table (write contention on hot rows)
- Not mentioning expiry/cleanup of expired URLs (database grows unboundedly without TTL enforcement)

**Interview Traps:**
- "Use UUID as short code" — UUIDs are 36 characters, defeating the purpose of a shortener; also UUID v4 is random and non-sequential, causing B-tree fragmentation in SQL DBs
- 301 vs 302 redirect is a classic interview differentiation question — know the trade-off cold

**Quick Revision:** Hash ring or Snowflake ID → base62 → 7-char code; Redis cache for reads; Cassandra/DynamoDB for storage; async Kafka for analytics; use 302 for analytics tracking.

---

### Topic 8: Design a Rate Limiter (High-Level Design)
**Difficulty:** High | **Frequency:** Very High | **Companies:** Stripe, Cloudflare, Google, Twitter, Uber, AWS

**Q:** Design a rate limiter for a public API. Compare algorithms, discuss distributed implementation, and explain where in the stack to deploy it.

**Short Answer:** A rate limiter controls the rate of incoming requests to protect services from abuse and ensure fair usage. Algorithms differ in memory usage, burst tolerance, and accuracy; Token Bucket is the most widely used in practice. In distributed systems, Redis with atomic Lua scripts is the standard implementation for shared state across multiple API servers.

**Deep Explanation:**

**Requirements Clarification:**

Functional:
- Limit requests per user/IP/API key within a time window
- Return 429 Too Many Requests with Retry-After header when limit exceeded
- Support different limits per endpoint (POST /login: 5/min; GET /data: 1000/min)
- Per-tenant limits (free tier: 100 req/min; paid tier: 10,000 req/min)

Non-functional:
- Low overhead: rate limiter should add < 1 ms latency to requests
- High availability: rate limiter failure should fail-open (allow requests) not fail-closed (block all)
- Accurate: soft limits acceptable (small over-counts due to race conditions are tolerable)
- Global: same limit enforced across all API server instances

**Algorithm Comparison:**

**1. Fixed Window Counter:**
- Divide time into fixed windows (e.g., [00:00-01:00], [01:00-02:00], ...)
- Count requests per user per window
- Reset counter at window boundary
- Pros: simple, low memory (one counter per user)
- Cons: boundary problem — user can send 2× limit by sending max in last second of window + max in first second of next window

```
Window [0-60s]: user sends 100 requests in seconds 59-60
Window [60-120s]: user sends 100 requests in seconds 60-61
→ 200 requests in 2 seconds, 2× the intended limit
```

**2. Sliding Window Log:**
- Store timestamp of every request in a sorted set
- On new request: remove timestamps older than window, count remaining, compare to limit
- Pros: exact rate limiting, no boundary problem
- Cons: high memory — store every timestamp (unbounded if user sends many requests)

**3. Sliding Window Counter (hybrid — recommended):**
- Combine two fixed windows with weighted interpolation
- Current window count + previous window count × (overlap percentage)
- Example: current window at 70% elapsed with 70 requests; previous window had 80 requests
  → estimated count = 70 + 80 × (1 - 0.70) = 70 + 24 = 94
- Pros: O(1) memory, no boundary problem, very accurate (< 0.003% error vs sliding log in production tests)
- Cons: slightly approximate

**4. Token Bucket (industry standard):**
- Bucket has capacity C tokens
- Tokens refill at rate R per second
- Each request consumes 1 token (or more for expensive operations)
- If bucket empty → reject request
- Pros: handles bursts (bucket acts as a buffer), simple, memory efficient
- Cons: two parameters to tune (capacity + refill rate)
- Used by: Stripe, AWS API Gateway, Uber

```
Bucket capacity: 100 tokens
Refill rate: 10 tokens/second
User sends 100 requests in 1 second → all pass (drains bucket)
User sends 1 request/second → sustainable indefinitely
User sends 200 requests in 1 second → first 100 pass, next 100 rejected
```

**5. Leaky Bucket:**
- Requests enter a queue; processed at a fixed rate regardless of input rate
- Smooths bursty traffic into a constant output rate
- Used for traffic shaping, not just rate limiting
- Pros: stable output rate, good for downstream services needing predictable load
- Cons: doesn't allow any bursting; requests queue up

**Algorithm Summary:**

| Algorithm | Memory | Burst Handling | Accuracy | Complexity |
|---|---|---|---|---|
| Fixed Window | Low | Poor (boundary spike) | Low | Low |
| Sliding Window Log | High | Exact | High | Medium |
| Sliding Window Counter | Low | Good | Very High | Medium |
| Token Bucket | Low | Excellent | High | Low |
| Leaky Bucket | Medium | None (smoothed) | High | Low |

**Distributed Rate Limiting — the real challenge:**

Single server: trivial — use in-memory counter.

Multiple API servers: each server has a local counter. If limit = 100/min and you have 10 servers, each server allows 100/min → effective limit = 1000/min. No good.

**Solution 1: Centralized Redis (standard approach)**

Use Redis for shared atomic counters across all API servers.

Redis commands:
```
# Fixed window: INCR + EXPIRE
INCR user:123:2024010112   → returns new count
EXPIRE user:123:2024010112 60  → set TTL to window size
# Problem: INCR and EXPIRE are not atomic → race condition
# Solution: Lua script (atomic in Redis)

# Token bucket: GETSET pattern or Lua script
# Sliding window: ZRANGEBYSCORE + ZADD + ZREMRANGEBYSCORE (sorted set of timestamps)
```

Redis Lua Script for Token Bucket (atomic):
```lua
local tokens = tonumber(redis.call('GET', KEYS[1]) or ARGV[1])
local now = tonumber(ARGV[2])
local last_refill = tonumber(redis.call('GET', KEYS[2]) or now)
local rate = tonumber(ARGV[3])
local capacity = tonumber(ARGV[4])
local elapsed = now - last_refill
local new_tokens = math.min(capacity, tokens + elapsed * rate)
if new_tokens >= 1 then
  redis.call('SET', KEYS[1], new_tokens - 1)
  redis.call('SET', KEYS[2], now)
  return 1  -- allowed
else
  return 0  -- rejected
end
```

**Solution 2: Local + Sync (eventual consistency)**
Each server maintains local counter; periodically syncs to central store. Allows slight over-counting (within sync interval) but reduces Redis load. Used by Cloudflare for their globally distributed rate limiting.

**Solution 3: Sliding window with Redis Sorted Sets**
```
Key: rate_limit:user:123
ZADD key timestamp timestamp   → add request timestamp
ZREMRANGEBYSCORE key 0 (now-window)  → remove old entries
count = ZCARD key
if count < limit: allow else: reject
```
Exact but memory-intensive for high request rates.

**Where to Deploy the Rate Limiter:**

| Location | Pros | Cons |
|---|---|---|
| Client-side | Reduces traffic at source | Easily bypassed, not trusted |
| API Gateway (recommended) | Centralized, before business logic, easy to update limits | Gateway becomes critical dependency |
| Application middleware | Fine-grained per-endpoint logic | Distributed state problem, latency added to every request |
| Load balancer | L7 LB can do basic rate limiting (Nginx limit_req) | Limited flexibility |
| Dedicated service | Full flexibility, decoupled | Extra network hop, additional component to maintain |

**Best practice:** Primary rate limiter at API Gateway (Nginx/Kong/AWS API GW) for coarse-grained global limits + middleware-level rate limiter for per-endpoint business logic limits.

**Headers to return:**

```
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1704067260  (Unix timestamp when limit resets)
Retry-After: 60               (seconds until retry)
```

**Real-World Example:** Stripe's rate limiter uses Token Bucket algorithm implemented in Redis with Lua scripts. Every API request to Stripe goes through their rate limiting middleware before hitting business logic. They use different bucket configurations per API key tier (test vs live, free vs paid). Their 2017 engineering blog post describes how they moved from per-server limits to Redis-based distributed limits after noticing customers were being inconsistently limited across server instances. They also implement "soft limits" where they return warnings in headers before hitting the hard limit, allowing clients to back off gracefully.

**Architecture Diagram:**

```
Request Flow with Rate Limiter at API Gateway:

Client --> [API Gateway / Load Balancer]
                    |
           [Rate Limiter Middleware]
                    |
           [Redis Cluster]
           key: "rate:user:123:minute:2024..."
           value: current count
                    |
           count < limit? --> YES --> forward to [API Server]
                          --> NO  --> 429 Too Many Requests

Token Bucket Visualization:
  Capacity: 10 tokens
  Refill: 2 tokens/sec

  t=0: [##########] 10 tokens  → burst of 10 requests allowed
  t=1: [##        ]  2 tokens  → 2 refilled after 1 second
  t=5: [##########] 10 tokens  → full bucket, ready for another burst

Distributed Rate Limiter Architecture:
  [API Server 1] \
  [API Server 2] --> [Redis Cluster] <-- shared atomic state
  [API Server 3] /   (Lua scripts for atomicity)
```

**Follow-up Questions:**
1. How do you handle Redis downtime — should the rate limiter fail-open (allow all requests) or fail-closed (reject all)?
2. How would you implement rate limiting for a multi-tenant SaaS where each tenant has different limits and the limits themselves change dynamically?
3. What is the difference between rate limiting and throttling — how would you implement graceful degradation vs hard rejection?

**Common Mistakes:**
- Implementing rate limiting with non-atomic operations — INCR and EXPIRE separately can allow > limit requests due to race conditions between calls
- Using wall-clock time directly in token bucket without considering time drift across servers — use Redis server time (`TIME` command) not client time
- Forgetting to return proper headers — clients need `Retry-After` to implement exponential backoff

**Interview Traps:**
- "Rate limiter should always fail-closed" — NO: if your rate limiter (Redis) goes down, fail-open is usually correct for business continuity; the alternative (fail-closed) means your entire API goes down because of a rate limiting outage
- "Use a database for rate limit counters" — databases are too slow for per-request counters at scale; Redis (in-memory, sub-millisecond) is the right tool

**Quick Revision:** Token Bucket = most common (burst-tolerant, two params: capacity + refill rate); Redis + Lua for atomic distributed counting; deploy at API Gateway; fail-open on Redis failure; return X-RateLimit-* headers.

---

## Chapter 22 Part A — Summary Reference Card

| Topic | Key Concept | Production Example |
|---|---|---|
| System Design Framework | RADIO: Requirements → API → Data → Implementation → Optimizations | Google interview guide |
| Scalability Fundamentals | Stateless + LB = horizontal scale; external session state | Netflix stateless API tier |
| Load Balancer | L4=TCP/IP, L7=HTTP-aware; SSL termination at LB; health checks | AWS ALB/NLB, Nginx, Envoy |
| CDN & Edge | Pull vs push; URL versioning; edge compute | Netflix Open Connect, Cloudflare Workers |
| Consistent Hashing | Hash ring + virtual nodes; 1/N remapping on topology change | Cassandra, DynamoDB, Redis Cluster |
| Estimation | QPS = DAU × req/user / 86,400; peak = 3×; storage × retention | Jeff Dean's latency numbers |
| URL Shortener | ID → base62 → 7 chars; Redis cache; 302 for analytics | Bitly, goo.gl |
| Rate Limiter | Token Bucket + Redis Lua; API Gateway deployment; fail-open | Stripe, Cloudflare |

---

*Chapter 22 Part B covers: Consistent Hashing Implementation, Database Sharding Strategies, Design a Key-Value Store, Design a Message Queue, Design a Notification System, Design a Search Autocomplete, Design a Distributed Cache, and Design a News Feed System.*


---

# Chapter 22 — High-Level System Design: Part B
### Topics 9–15 + Master Cheat Sheet
**Target Audience:** SDE2 / FAANG+ interviews

---

## Table of Contents

9. [Design a News Feed (Twitter/Instagram)](#9-design-a-news-feed)
10. [Design a Notification System](#10-design-a-notification-system)
11. [Design a Distributed Message Queue (Kafka)](#11-design-a-distributed-message-queue)
12. [Design a Distributed Cache (Redis)](#12-design-a-distributed-cache)
13. [Design a Search Autocomplete System](#13-design-a-search-autocomplete-system)
14. [Design a Distributed ID Generator](#14-design-a-distributed-id-generator)
15. [Microservices System Design Patterns](#15-microservices-system-design-patterns)
- [Master Cheat Sheet](#master-cheat-sheet)

---

## 9. Design a News Feed

### Problem Statement
Design the news feed feature for a social platform (Twitter, Instagram, Facebook) where each user sees posts from the people they follow, ranked by recency or relevance.

### Clarifying Questions to Ask
- Read/write ratio? (Reads dominate: ~100:1 for consumer apps)
- Ordered by time or ranked by relevance?
- How many followers can one user have? (celebrity problem)
- How many users? (Twitter scale: ~300M DAU)
- Should deleted/edited posts propagate?

### Capacity Estimation
```
Users: 300M DAU
Posts per day: 50M
Average following: 200
Feed reads per day: 300M * 10 = 3B reads/day = ~35K RPS reads
Feed writes: 50M posts * 200 followers = 10B fanout ops/day

Storage:
  Post size: ~1 KB text + metadata
  50M posts/day * 1 KB = 50 GB/day
  Post IDs in feed (8 bytes): 10B * 8 bytes = 80 GB/day fanout writes
```

### Core Architecture

#### Approach 1: Fanout on Write (Push Model)
When a user posts, immediately write to all followers' feed caches.

```
POST /v1/feed/publish
         |
         v
  [Post Service]
         |
   Save post to DB
         |
         v
  [Fanout Service]  <-- async
         |
    Read follower list
         |
    For each follower:
      ZADD feed:{userId} <timestamp> <postId>   (Redis sorted set)
```

**Pros:** Feed reads are O(1) — just read from Redis.
**Cons:** Fan-out write storm for celebrities (100M followers = 100M Redis writes per post).

#### Approach 2: Fanout on Read (Pull Model)
Feed is assembled at read time by merging timelines of all followed users.

```
GET /v1/feed
         |
         v
  [Feed Service]
         |
    Get followee list for user
         |
    For each followee: fetch last N posts
         |
    Merge + sort + paginate
         |
    Return feed
```

**Pros:** No write amplification. Simple writes.
**Cons:** Read is slow — N database queries per feed request. Not scalable at 35K RPS.

#### Approach 3: Hybrid Model (Production Choice)
- Regular users (< X followers): fanout on write.
- Celebrity users (> X followers, e.g., 1M+): fanout on read.
- At read time, merge pre-built feed with celebrity posts.

```
                           User Posts
                               |
                  +------------+------------+
                  |                         |
          [Regular User]            [Celebrity User]
                  |                         |
          Fanout Service             No fanout write
          (push to followers)        Post stored normally
                  |                         |
          Write postId to               Celebrity
          feed:{followerIds}           Post Cache
          in Redis ZADD                    |
                                           |
                                +----------+
                                |
              GET /v1/feed  (user requests feed)
                                |
                     [Feed Read Service]
                          |           |
                 Read from        Fetch recent
               feed:{userId}    celebrity posts
               (Redis ZADD)     (for each celebrity
                                 the user follows)
                          |           |
                          +----+------+
                               |
                          Merge & Sort
                               |
                       Hydrate post details
                       from Post DB / Cache
                               |
                          Return Feed
```

### Data Model

**Post Table (Cassandra / DynamoDB)**
```
post_id      BIGINT (Snowflake ID)  PK
user_id      BIGINT
content      TEXT
media_urls   LIST<TEXT>
created_at   TIMESTAMP
like_count   COUNTER
```

**Feed Table (Redis Sorted Set)**
```
Key:   feed:{user_id}
Score: Unix timestamp (nanoseconds for ordering)
Value: post_id

Commands:
  ZADD feed:123 1700000000000 post_456  -- O(log N)
  ZREVRANGE feed:123 0 19              -- top 20 posts O(log N + M)
  ZREMRANGEBYSCORE feed:123 0 <30d ago -- TTL cleanup
```

### Timeline Generation Deep Dive

**Pagination with cursor:**
```
GET /v1/feed?cursor=<last_seen_post_id>&limit=20
  - cursor encodes (timestamp, post_id)
  - ZREVRANGEBYSCORE feed:{uid} cursor_ts -inf LIMIT 0 20
  - stateless, safe for re-requests
```

**Feed hydration:**
1. Read 20 post IDs from Redis sorted set.
2. Batch-fetch post objects from post cache (Redis Hash or Memcached).
3. Cache miss → fetch from Cassandra.
4. Return hydrated post objects.

### Celebrity Problem Solutions
1. **Hybrid model** (above) — most practical.
2. **Lazy fanout** — fan out to top-N online followers immediately; rest get it at read time.
3. **Separate celebrity timeline cache** — ZADD celebrity_timeline:{celebId} with TTL.

### Key Trade-offs
| Approach | Write Cost | Read Cost | Freshness | Best For |
|---|---|---|---|---|
| Fanout on Write | High | O(1) | Immediate | Regular users |
| Fanout on Read | Low | High | Immediate | Celebrity posts |
| Hybrid | Medium | Low | Slight delay | Production |

### Interview Tips
- Start with the hybrid model — it shows you know the celebrity problem exists.
- Mention Redis TTL for feed (keep only 30 days of feed).
- Discuss ranked feed vs chronological (ML ranking = separate ranking service).
- Note that ZADD with the same score (same second) needs tiebreaker (post_id).

---

## 10. Design a Notification System

### Problem Statement
Design a scalable notification system that delivers messages across multiple channels (push, email, SMS) with reliability guarantees.

### Clarifying Questions
- Channels: push (iOS/Android), email, SMS, in-app?
- Volume: ~10M notifications/day? 100M?
- Latency requirement: real-time vs. best-effort?
- Delivery guarantee: at-least-once? Exactly-once?
- User preferences: opt-out per channel, per notification type?

### Capacity Estimation
```
10M notifications/day = ~115/second average
Peak: 10x average = 1,150/second

Storage:
  Notification record: ~500 bytes
  10M/day * 500 bytes = 5 GB/day
  Retention: 90 days = 450 GB
```

### Architecture

```
          Trigger Sources
    +-------+--------+--------+
    |       |        |        |
  [App]  [Batch]  [Event]  [Admin]
  Service  Job     Stream   Console
    |       |        |        |
    +-------+--------+--------+
                  |
         [Notification Service]
          (API + Validation)
                  |
         Persist notification
         to DB (Cassandra)
                  |
          +-------+-------+
          |               |
      [Message Queue]  [User Preference
       (Kafka)          Service / Cache]
          |
    +-----+------+------+
    |            |      |
[Email        [SMS   [Push
 Worker]      Worker] Worker]
    |            |      |
  [SES/        [Twilio] [FCM /
  SendGrid]             APNs]
    |            |      |
    +-----+------+------+
          |
   [Delivery Tracking DB]
   (status: queued/sent/failed)
          |
   [Retry Service]
   (exponential backoff)
```

### Components Deep Dive

#### Notification Service (Entry Point)
- Validates request (user exists, channel available, not opted-out).
- Checks user notification preferences from cache.
- Publishes to Kafka topic per channel: `notifications.email`, `notifications.sms`, `notifications.push`.
- Writes notification record with status=QUEUED.

#### Message Queue (Kafka)
- Each channel = dedicated topic with multiple partitions.
- Partitioned by `user_id` — ensures ordering per user.
- Consumer groups: email-workers, sms-workers, push-workers.

#### Channel Workers
```
Email Worker:
  1. Consume from notifications.email topic
  2. Fetch template from Template Service
  3. Render HTML with user data
  4. Call SES/SendGrid API
  5. Update delivery status in DB
  6. On failure: dead-letter queue (DLQ)

Push Worker:
  1. Consume from notifications.push topic
  2. Look up device tokens from Device Token Store
  3. Call FCM (Android) or APNs (iOS)
  4. Handle token expiry: remove stale tokens
  5. Update delivery status

SMS Worker:
  1. Consume from notifications.sms topic
  2. Call Twilio API with E.164 phone number
  3. Update delivery status
```

#### Retry with Exponential Backoff
```
Attempt 1: immediate
Attempt 2: +30 seconds
Attempt 3: +2 minutes
Attempt 4: +10 minutes
Attempt 5: +1 hour
After 5 failures: move to DLQ, alert on-call
```

#### Deduplication
- Generate idempotency key: `hash(user_id + notification_type + event_id + channel)`.
- Check Redis cache before processing: `SET dedup:{key} 1 NX EX 86400`.
- If key exists, skip processing.

### Data Models

**Notification Record (Cassandra)**
```
notification_id  BIGINT PK
user_id          BIGINT
type             VARCHAR  (ORDER_SHIPPED, FRIEND_REQUEST, etc.)
channel          VARCHAR  (EMAIL, SMS, PUSH)
payload          TEXT     (JSON)
status           VARCHAR  (QUEUED, SENT, FAILED, DELIVERED)
created_at       TIMESTAMP
sent_at          TIMESTAMP
retry_count      INT
```

**User Preferences (MySQL + Redis cache)**
```
user_id       BIGINT PK
channel       VARCHAR
notif_type    VARCHAR
enabled       BOOLEAN
```

**Device Tokens (DynamoDB)**
```
user_id     BIGINT PK
device_id   VARCHAR SK
platform    VARCHAR  (IOS, ANDROID)
token       VARCHAR
updated_at  TIMESTAMP
```

### Third-Party Integration Notes
| Provider | Platform | Notes |
|---|---|---|
| FCM (Firebase Cloud Messaging) | Android, Web | HTTP v1 API, project-scoped auth |
| APNs (Apple Push Notification) | iOS, macOS | HTTP/2 with JWT or certificate auth |
| Twilio | SMS | REST API, E.164 format required |
| SendGrid / SES | Email | SMTP or HTTP API, handle bounces |

### Reliability Patterns
- **At-least-once delivery** via Kafka consumer commit after processing.
- **Idempotency** at the third-party call layer (use idempotency keys in SES/Twilio).
- **Circuit breaker** on third-party calls (Hystrix / Resilience4j).
- **Rate limiting** per user per channel per hour to avoid spam.

---

## 11. Design a Distributed Message Queue

### Problem Statement
Design a distributed message queue like Apache Kafka — high-throughput, fault-tolerant, persistent, supporting multiple producers and consumers.

### Clarifying Questions
- Throughput target? (Kafka does ~1M messages/second per cluster)
- Message size? (Kafka default max: 1 MB)
- Retention period? (default 7 days in Kafka)
- Ordering guarantee? (per-partition or global?)
- Delivery semantics? (at-least-once, at-most-once, exactly-once)

### Capacity Estimation
```
1M messages/second
Average message size: 1 KB
Ingestion throughput: 1 GB/second

Storage (7-day retention, 3x replication):
  1 GB/s * 86400 s/day * 7 days * 3 replicas
  = ~1.8 PB

Brokers needed:
  Each broker handles ~500 MB/s write
  1 GB/s / 500 MB/s = 2 brokers minimum
  With replication overhead: 6-10 brokers
```

### Core Concepts

**Topic:** Logical stream of messages (like a table name).
**Partition:** Ordered, immutable append-only log within a topic. Unit of parallelism.
**Offset:** Monotonically increasing position of a message within a partition.
**Producer:** Writes to partitions (can specify key for consistent routing).
**Consumer:** Reads from partitions, tracks its own offset.
**Consumer Group:** Set of consumers sharing a topic, each partition assigned to one consumer.
**Broker:** Server that stores partition data and serves producers/consumers.

### Architecture

```
Producers                  ZooKeeper / KRaft
  |                        (Cluster Metadata,
  |  Partition by key      Leader Election)
  v                               |
+--------+    +--------+    +-----+-----+
| Prod 1 |    | Prod 2 |    | Controller|
+--------+    +--------+    +-----+-----+
     \              /             |
      \            /         Assigns leaders
       v          v               |
   +---+-----------+---+          |
   |   Kafka Cluster   |<---------+
   |                   |
   |  +-------------+  |
   |  |  Broker 1   |  |
   |  | Partition 0 |  |  Leader for P0
   |  | Partition 3 |  |  Replica for P1
   |  +-------------+  |
   |                   |
   |  +-------------+  |
   |  |  Broker 2   |  |
   |  | Partition 1 |  |  Leader for P1
   |  | Partition 4 |  |  Replica for P0
   |  +-------------+  |
   |                   |
   |  +-------------+  |
   |  |  Broker 3   |  |
   |  | Partition 2 |  |  Leader for P2
   |  | Partition 5 |  |  Replica for P3
   |  +-------------+  |
   +-------------------+
           |
     Consumer Groups
     /             \
[Group A]        [Group B]
C1: P0,P1        C3: P0,P1,P2
C2: P2,P3        (only one consumer)
```

### Storage Engine

Each partition is a **segmented append-only log** on disk:

```
Partition 0 data directory:
  00000000000000000000.log       (segment file, messages)
  00000000000000000000.index     (sparse offset -> byte position index)
  00000000000000000000.timeindex (timestamp -> offset index)
  00000000000001234567.log       (newer segment after rotation)
  ...

Message format (binary):
  [offset: 8B][message_size: 4B][CRC: 4B][magic: 1B]
  [attributes: 1B][timestamp: 8B][key_length: 4B][key]
  [value_length: 4B][value]
```

**Why append-only log is fast:**
- Sequential disk writes (no seek penalty — SSD or HDD).
- OS page cache handles read-heavy workloads.
- Zero-copy transfer: `sendfile()` syscall to send from page cache directly to network socket.

### Replication

- Each partition has one **leader** and N-1 **followers** (replicas).
- Producers write to leader only.
- Followers fetch from leader (pull-based replication).
- **ISR (In-Sync Replicas):** set of replicas within a configurable lag.
- `acks=all`: producer waits for all ISR replicas to acknowledge.
- If leader fails, controller elects a new leader from ISR.

```
Producer writes to Leader (P0 on Broker 1):
  Broker 1 (Leader P0)  <-- write
       |
       +---> Broker 2 (Follower P0) fetches
       |
       +---> Broker 3 (Follower P0) fetches

ISR = {Broker1, Broker2, Broker3} if all in sync
ISR = {Broker1, Broker2} if Broker3 lags behind
```

### Consumer Groups and Offset Management

```
Consumer Group "order-processors":
  Topic: orders (6 partitions P0-P5)
  Consumer A -> P0, P1
  Consumer B -> P2, P3
  Consumer C -> P4, P5

Each consumer commits its offset to __consumer_offsets topic.

Rebalance triggered when:
  - New consumer joins group
  - Consumer crashes / leaves
  - New partitions added
```

### Delivery Semantics

| Semantic | How | Tradeoff |
|---|---|---|
| At-most-once | Commit offset before processing | May lose messages on crash |
| At-least-once | Commit offset after processing | May process message twice |
| Exactly-once | Transactional API (idempotent producer + atomic commit) | Higher latency, complexity |

**Exactly-once implementation:**
```
producer.initTransactions()
producer.beginTransaction()
  producer.send(record)
  consumer.commitSync(offsetsToCommit)  // included in transaction
producer.commitTransaction()
// OR
producer.abortTransaction()
```

### Key Design Decisions

1. **Partition count:** More partitions = more parallelism but more overhead. Rule: partitions >= consumers in the largest consumer group.
2. **Retention policy:** Time-based (7 days) or size-based (log.retention.bytes). Log compaction for event sourcing (keep last value per key).
3. **Compaction:** For changelog topics, Kafka retains only the latest message per key.

---

## 12. Design a Distributed Cache

### Problem Statement
Design a distributed in-memory cache like Redis that supports get/set, eviction, sharding across nodes, and high availability.

### Clarifying Questions
- Data size? (fit entirely in RAM across cluster?)
- Read/write ratio? (typically 10:1 or higher for cache)
- Consistency requirement? (eventual OK? or strong?)
- HA required? (Redis Sentinel / Cluster)
- Which data structures? (strings, hashes, sorted sets, lists)

### Capacity Estimation
```
Cache: 100 GB total data
Nodes: 10 nodes * 16 GB RAM = 160 GB (buffer for overhead)
Throughput: 100K ops/second per node
Total: 1M ops/second for 10-node cluster
Replication factor: 2 (each key on 2 nodes)
```

### Architecture

```
         Clients
         /     \
     App1      App2
       |          |
       v          v
  +---------+  +---------+
  | Redis   |  | Redis   |   Cluster Bus
  | Node 1  |--| Node 2  |---(gossip protocol)
  | (M)     |  | (M)     |
  | Slots   |  | Slots   |
  | 0-5460  |  |5461-10922|
  +---------+  +---------+
       |              |
  +---------+  +---------+
  | Redis   |  | Redis   |
  | Node 1  |  | Node 2  |
  | Replica |  | Replica |
  +---------+  +---------+

  ... Node 3 (M): slots 10923-16383
  ... Node 3 (R): replica of Node 3
```

### Consistent Hashing for Sharding

**Naive sharding (modulo):** `node = hash(key) % N`
- Problem: When N changes (add/remove node), almost all keys remap.

**Consistent Hashing:**
- Hash space is a ring 0..2^32.
- Each node occupies a position on the ring (multiple virtual nodes for balance).
- Key maps to the first node clockwise on the ring.
- Adding/removing a node only remaps ~K/N keys (K=total keys, N=nodes).

```
Hash Ring (0 to 2^32):

         0
         |
    +----+----+
    |         |
   NodeA     NodeB (1/4 of ring each with vnodes)
    |         |
    +----+----+
         |
       NodeC

Key K: hash(K) -> position on ring -> clockwise to next node
```

**Redis Cluster uses hash slots** (not true consistent hashing):
- 16,384 hash slots total.
- `slot = CRC16(key) % 16384`
- Each node owns a range of slots.
- Migration = move slots between nodes.

### Eviction Policies

| Policy | Description | Use Case |
|---|---|---|
| `noeviction` | Return error when memory full | Never lose data |
| `allkeys-lru` | Evict least recently used from all keys | General purpose cache |
| `volatile-lru` | LRU only among keys with TTL set | Mixed persistent + cache |
| `allkeys-lfu` | Evict least frequently used | Skewed access patterns |
| `volatile-ttl` | Evict key closest to expiry | Time-sensitive data |
| `allkeys-random` | Random eviction | When access is uniform |

**LRU Implementation (approximate in Redis):**
- Redis samples a random set of keys and evicts the LRU among the sample.
- Configurable sample size: `maxmemory-samples 5` (default).
- True LRU would require O(N) extra memory.

### Cache Invalidation Strategies

**1. TTL (Time-To-Live):** Set expiry at write time.
```
SET user:123 {data} EX 3600   -- expires in 1 hour
```
Simple, but stale data possible until expiry.

**2. Write-Through:** Update cache and DB atomically.
```
write(key, value):
  DB.update(key, value)    -- synchronous
  Cache.set(key, value)    -- synchronous
```
Always consistent. Higher write latency.

**3. Write-Behind (Write-Back):** Write to cache first, async flush to DB.
```
write(key, value):
  Cache.set(key, value)          -- synchronous
  async: DB.update(key, value)   -- async (queue)
```
Low write latency. Risk of data loss if cache crashes.

**4. Cache-Aside (Lazy Loading):** Application manages cache.
```
read(key):
  val = Cache.get(key)
  if val == null:
    val = DB.get(key)       -- cache miss
    Cache.set(key, val, TTL)
  return val
```
Most common pattern. Stale data risk. Data only loaded when needed.

**5. Event-Driven Invalidation (CDC):**
```
DB Change --> CDC (Debezium) --> Kafka --> Cache Invalidation Service --> DEL key
```
Most accurate. Complex to operate.

### Cache Stampede (Thundering Herd)

**Problem:** Popular key expires. Thousands of requests hit DB simultaneously.

**Solutions:**

1. **Mutex/Lock:**
```
val = Cache.get(key)
if val == null:
  if Lock.acquire(key, timeout=5s):
    val = DB.get(key)
    Cache.set(key, val, TTL)
    Lock.release(key)
  else:
    val = Cache.get(key)  // retry after lock released
```

2. **Probabilistic Early Expiry (XFetch):**
```
// Recompute with probability increasing as TTL decreases
current_time = now()
if current_time - delta * beta * log(random()) > expiry_time:
    recompute_and_cache()
```

3. **Background refresh:** Before key expires, a background job refreshes it.

### Replication and High Availability

**Redis Sentinel (1 master, N replicas):**
```
        [Sentinel 1]
       /      |      \
      /       |       \
[Master]  [Sentinel 2]  [Sentinel 3]
    |
[Replica 1]
[Replica 2]

Failover: if master unreachable by quorum of sentinels,
          promote a replica to master.
```

**Redis Cluster (sharding + HA):**
- 3 primary + 3 replica minimum.
- Automatic failover without sentinel.
- Cross-slot transactions not supported.

---

## 13. Design a Search Autocomplete System

### Problem Statement
Design the autocomplete/typeahead feature that suggests top-K search queries as a user types (e.g., Google search bar).

### Clarifying Questions
- How many daily active users? (1B for Google scale)
- Latency requirement? (<100ms from keypress to suggestion)
- How many suggestions? (5-10)
- Real-time or near-real-time frequency updates?
- Personalized suggestions or global?

### Capacity Estimation
```
5B searches/day
Average query length: 5 words = ~20 chars
Each keystroke = autocomplete request

Requests: 5B searches * 20 keystrokes = 100B requests/day
          = 100B / 86400 = ~1.2M requests/second (peak: 5M RPS)

Storage (trie for top queries):
  Top 5M unique queries * 30 bytes each = 150 MB per trie
  With frequency + metadata: ~5 GB total
  (fits in memory easily)
```

### Trie Data Structure

```
Trie storing: "apple", "app", "application", "apply", "apt"

          root
           |
           a (freq: 500)
           |
           p (freq: 500)
          / \
         p   t
        / \   \
  (app)    l    (apt, freq:50)
 freq:300  |
    |      i,y
    e      |  \
    |    ica  (apply,freq:80)
   (apple) tion
  freq:100 (application,freq:120)

Each node stores:
  - character
  - children: Map<char, TrieNode>
  - is_end: boolean
  - top_k_suggestions: List<(query, frequency)>  ← cached at each node!
```

**Why cache top-K at each node?**
- Without cache: traverse subtree to find top-K = O(subtree size).
- With cache: return top-K directly = O(1) per node after trie traversal.
- Trade-off: more memory; updates must propagate up the trie.

### Trie Operations

**Search for prefix "app":**
```
1. Traverse: root -> 'a' -> 'p' -> 'p'
2. Return node.top_k_suggestions = ["apple", "application", "apply", "app", ...]
3. O(length of prefix) = O(L)
```

**Update frequency for query "apple":**
```
1. Traverse trie: root -> 'a' -> 'p' -> 'p' -> 'l' -> 'e'
2. Increment frequency at leaf
3. Propagate up: update top-K list at each ancestor if "apple" now ranks
4. O(L * K) where K = top-K size
```

### System Architecture

```
         User Types "app..."
               |
               v
        [API Gateway]
               |
        [Autocomplete Service]
        (stateless, horizontally scaled)
               |
      +---------+---------+
      |                   |
  Cache Hit           Cache Miss
  (Redis)                 |
      |           [Trie Service]
   Return             (in-memory trie
   top-K              per shard)
                           |
                    Return top-K
                    Store in Redis
                    (TTL: 1 hour)


  ---- Trie Build Pipeline ----

  Raw Search Logs
       |
  [Log Aggregator] (Kafka)
       |
  [Aggregation Service]
  (Flink / Spark Streaming)
  Count query frequencies
  per time window (last 7 days)
       |
  [Top Query Store] (S3 or HBase)
  query -> frequency
       |
  [Trie Builder] (weekly/daily batch)
  Rebuild full trie from top queries
       |
  [Trie Servers] (distributed, sharded by prefix)
  Load new trie (blue/green swap)
```

### Distributed Trie (Sharding)

```
Shard by first 2 characters of prefix:
  Shard 1: aa-am (queries starting with aa..am)
  Shard 2: an-az
  Shard 3: ba-bm
  ...
  Shard 26+: za-zz

Lookup: hash(prefix[0:2]) -> shard -> query shard
```

### Aggregation Pipeline for Frequency

```
1. Raw Logs: {user_id, query, timestamp, clicked_suggestion}
2. Kafka: stream raw events
3. Flink:
   - Sliding window: count queries over last 7 days
   - Weighted: recent queries count more
   - Filter: remove stop words, malformed queries
   - Top-N reducer per prefix
4. Write to frequency store
5. Trie builder reads frequency store, rebuilds trie
6. Trie servers do hot-reload (atomic swap)
```

### Caching Frequent Queries

```
Redis cache key: autocomplete:{prefix}:{limit}
Value: JSON array of suggestions
TTL: 1 hour for common prefixes, 5 min for rare prefixes

Hit rate: Pareto principle -- top 20% of prefixes get 80% of traffic
  Cache these aggressively (TTL: 24 hours)
  Use LFU eviction to keep hot prefixes
```

### Personalization Layer (Optional)

```
Global suggestions + User history blend:
  1. Get global top-K for prefix
  2. Get user's recent queries matching prefix (from user profile service)
  3. Merge: user_score = 0.7 * personal_freq + 0.3 * global_freq
  4. Re-rank and return top-K
```

---

## 14. Design a Distributed ID Generator

### Problem Statement
Generate globally unique, roughly-sortable 64-bit IDs at high throughput across distributed services without a single point of failure.

### Requirements
- Globally unique (no collisions across services/datacenters).
- Sortable by time (IDs generated later should be numerically larger).
- High throughput (100K+ IDs/second per node).
- No single point of failure.
- 64-bit integer (fits in BIGINT, JavaScript safe integer).

### Option 1: UUID (v4)

```
Format: 8-4-4-4-12 hex characters
Example: 550e8400-e29b-41d4-a716-446655440000
Size: 128 bits

Pros:
  - Trivially generated anywhere (no coordination)
  - No SPOF

Cons:
  - 128 bits (vs 64-bit BIGINT in DB)
  - Not sortable by time
  - Random distribution = bad for B-tree index locality
  - String representation is 36 bytes
```

### Option 2: Database Auto-Increment

```
MySQL: AUTO_INCREMENT
PostgreSQL: SERIAL / BIGSERIAL

Pros: Simple, human-readable, sequential

Cons:
  - Single server bottleneck
  - Predictable (security risk)
  - Schema coupling between services

Multi-master workaround:
  Server 1: generates 1, 3, 5, 7, ... (odd)
  Server 2: generates 2, 4, 6, 8, ... (even)
  
  Still limited: hard to add new servers, not truly distributed
```

### Option 3: Twitter Snowflake (Recommended)

```
 63    63  62          22   21        12  11          0
  +-----+---------------+------------+---------------+
  | sign| 41-bit         | 10-bit     | 12-bit        |
  |  0  | timestamp (ms) | machine ID | sequence      |
  +-----+---------------+------------+---------------+

Total: 64 bits

Components:
  - Sign bit (1): always 0 (positive)
  - Timestamp (41 bits): ms since custom epoch (Jan 1, 2010)
    Range: 2^41 = 2.2 trillion ms = ~69 years
  - Machine ID (10 bits): 2^10 = 1024 nodes
    Split: 5-bit datacenter + 5-bit machine (32 DCs * 32 machines)
  - Sequence (12 bits): 2^12 = 4096 IDs/ms per node
    Total: 4096 * 1000 = 4M IDs/second/node
```

**Snowflake Implementation (Java pseudocode):**
```java
public class SnowflakeIdGenerator {
    private static final long EPOCH = 1420041600000L; // Jan 1, 2015
    private static final long MACHINE_BITS = 10L;
    private static final long SEQUENCE_BITS = 12L;
    private static final long MAX_MACHINE = ~(-1L << MACHINE_BITS); // 1023
    private static final long MAX_SEQUENCE = ~(-1L << SEQUENCE_BITS); // 4095
    private static final long MACHINE_SHIFT = SEQUENCE_BITS;
    private static final long TIMESTAMP_SHIFT = SEQUENCE_BITS + MACHINE_BITS;

    private final long machineId;
    private long lastTimestamp = -1L;
    private long sequence = 0L;

    public synchronized long nextId() {
        long currentMs = System.currentTimeMillis();
        if (currentMs == lastTimestamp) {
            sequence = (sequence + 1) & MAX_SEQUENCE;
            if (sequence == 0) {
                // Sequence exhausted, wait for next millisecond
                currentMs = waitNextMillis(currentMs);
            }
        } else {
            sequence = 0L;
        }
        lastTimestamp = currentMs;
        return ((currentMs - EPOCH) << TIMESTAMP_SHIFT)
             | (machineId << MACHINE_SHIFT)
             | sequence;
    }

    private long waitNextMillis(long lastMs) {
        long ms = System.currentTimeMillis();
        while (ms <= lastMs) ms = System.currentTimeMillis();
        return ms;
    }
}
```

**Properties:**
- Time-sorted: IDs generated later are numerically larger (within same machine).
- No coordination needed at generation time.
- Machine ID provisioned at startup (from ZooKeeper or config service).

**Clock skew problem:**
- If system clock goes backward, generator throws exception or waits.
- NTP should prevent large skews; small skews handled by waiting.

### Option 4: UUID v7 (Modern Alternative)

```
UUID v7 layout (128 bits):
  | unix_ts_ms (48 bits) | ver (4) | rand_a (12) | var (2) | rand_b (62) |

Key difference from v4:
  - First 48 bits = Unix timestamp in milliseconds
  - Sortable (monotonic within same millisecond with rand_a counter)
  - Standard (RFC 9562, 2024)
  - 128-bit (larger than Snowflake but standard)

Use when: you need standard UUID format but want sortability.
Use Snowflake when: 64-bit is required (DB BIGINT, JavaScript safe integer).
```

### Comparison Table

| Approach | Bits | Sortable | Throughput | Coordination | Recommended |
|---|---|---|---|---|---|
| UUID v4 | 128 | No | Unlimited | None | Low cardinality |
| DB Auto-Increment | 64 | Yes | Low | Centralized | Single-node DB |
| Snowflake | 64 | Yes | 4M/sec/node | Machine ID only | Distributed systems |
| UUID v7 | 128 | Yes | Unlimited | None | Modern standard |

### Production Deployment

```
[ID Generator Service]
  - Stateless service, horizontally scalable
  - Machine ID assigned from ZooKeeper node registration
  - Exposes: GET /v1/id?count=100 (batch generation)
  - Clients cache batch of IDs locally to reduce latency
  
ZooKeeper /snowflake/workers/
  /workers/datacenter-1/machine-1 = "5" (machine ID)
  /workers/datacenter-1/machine-2 = "6"
  ...
  Ephemeral nodes: released when service dies
```

---

## 15. Microservices System Design Patterns

### Problem Statement
Design the architecture patterns for decomposing a monolith and operating microservices at scale, covering migration, communication, data consistency, and cross-cutting concerns.

### Core Microservices Principles
1. **Single Responsibility:** Each service owns one bounded context.
2. **Decentralized Data:** Each service owns its database (no shared DB).
3. **Communication via APIs:** REST, gRPC, or messaging — no direct DB calls.
4. **Independent deployment:** Each service deploys independently.
5. **Failure isolation:** One service failure does not cascade.

---

### Pattern 1: Strangler Fig Migration

Incrementally migrate monolith to microservices without a big-bang rewrite.

```
Phase 1: Facade in front of monolith
          Client
            |
         [Facade / API Gateway]
            |
         [Monolith]

Phase 2: Extract first service (e.g., User Service)
          Client
            |
         [API Gateway]
           / \
    [User   [Monolith]
    Service] (remaining features)

Phase 3: Extract more services over time
          Client
            |
         [API Gateway]
        /    |     \    \
  [User] [Order] [Notif] [Monolith shrinks]

Phase 4: Monolith eventually replaced or residual
```

**Steps:**
1. Put a proxy/facade in front of monolith.
2. Identify bounded context to extract (strangler point).
3. Build new microservice in parallel.
4. Redirect traffic to new service via feature flag.
5. Delete code from monolith.
6. Repeat.

**Key risks:** Dual-write period, data migration, integration testing complexity.

---

### Pattern 2: API Gateway Patterns

```
         Clients
    +------+------+
    |      |      |
 Mobile  Web   Third-Party
    |      |      |
    +------+------+
           |
    [API Gateway]
    - Authentication (JWT/OAuth validation)
    - Rate limiting (per user, per endpoint)
    - Request routing (path-based, header-based)
    - SSL termination
    - Request/Response transformation
    - Load balancing
    - Caching
    - Circuit breaking
    - Observability (access logs, tracing)
           |
    +------+------+------+------+
    |      |      |      |      |
 [User] [Order] [Prod] [Search] [...]
 Svc     Svc    Svc     Svc
```

**BFF (Backend for Frontend) Pattern:**
```
         [Mobile App]  [Web App]  [Partner API]
               |           |           |
         [Mobile BFF]  [Web BFF]  [Partner BFF]
               |           |           |
               +-----+-----+-----------+
                     |
               [Microservices]
```
Each BFF is tailored to its client: mobile BFF returns compressed, minimal data; web BFF returns full JSON.

---

### Pattern 3: Service Mesh

Handles service-to-service communication concerns in infrastructure layer, not application code.

```
Pod A                    Pod B
+------------------+     +------------------+
| App Container    |     | App Container    |
+------------------+     +------------------+
| Sidecar Proxy    |<--->| Sidecar Proxy    |
| (Envoy)          |     | (Envoy)          |
+------------------+     +------------------+

Control Plane (Istio / Linkerd):
  - Service discovery
  - Traffic management (canary, blue/green)
  - mTLS between services (zero-trust networking)
  - Retry / timeout / circuit breaker policies
  - Distributed tracing injection
  - Telemetry collection

Data Plane (Envoy sidecars):
  - Intercepts all inbound/outbound traffic
  - Enforces policies from control plane
  - Emits metrics / traces
```

**What service mesh solves:**
- Mutual TLS without code changes.
- Retries and timeouts configured per route.
- Traffic splitting for canary deployments.
- Observability (distributed tracing, service graph).

---

### Pattern 4: Event-Driven Architecture

Services communicate via events rather than synchronous calls.

```
         [Order Service]
               |
         Place order event
               |
         [Message Broker (Kafka)]
          /         |        \
         /          |         \
[Inventory      [Payment    [Notification
 Service]        Service]    Service]
 Reserve          Charge      Email
 items            customer    customer
   |                |
 Item reserved    Payment processed
 event            event
   |                |
   +-------+--------+
           |
    [Order Service]
    Update order status
```

**Event types:**
- **Domain events:** OrderPlaced, PaymentProcessed, ItemShipped.
- **Integration events:** cross-service events published to broker.

**Choreography vs Orchestration:**
```
Choreography (decentralized, event-driven):
  Each service reacts to events and publishes its own.
  + Loose coupling
  - Hard to understand overall flow; debugging complexity

Orchestration (centralized workflow):
  [Order Orchestrator / Saga Orchestrator]
    1. Call Inventory: reserve items
    2. Call Payment: charge customer
    3. Call Notification: send email
  + Clear business flow
  - Orchestrator knows all services; coupling
```

---

### Pattern 5: CQRS at Scale (Command Query Responsibility Segregation)

Separate the write model (commands) from the read model (queries).

```
                Commands (writes)
                     |
              [Command Handler]
                     |
              [Write Model DB]
              (normalized, MySQL)
                     |
              Domain Events published
              to Kafka/Event Bus
                     |
         +-----------+-----------+
         |           |           |
   [Read Model  [Search     [Analytics
    Updater]    Indexer]     Projector]
         |           |           |
   [Read DB      [Elastic-    [Data
   (denormalized  search]     Warehouse]
   Cassandra)]
         |
    Queries (reads)
         |
   [Query Handler]
         |
   [Read Model DB]
   (optimized for UI query patterns)
```

**When to use CQRS:**
- Read and write workloads have very different scaling needs.
- Complex read views that require joins across multiple aggregates.
- Event sourcing (write model = event log; read models = projections).

**Event Sourcing + CQRS:**
```
Write model: Append events to event store (never update, never delete)
  OrderCreated, ItemAdded, PaymentProcessed, OrderShipped

Read model: Project events to materialized views
  SELECT * FROM order_summary WHERE user_id = 123
  (built by replaying events)

Benefits:
  - Full audit log
  - Temporal queries ("what was state at T?")
  - Replay to rebuild read models
  - Easy async integration

Costs:
  - Eventual consistency on read side
  - Event schema evolution complexity
  - Read model rebuild time
```

---

### Pattern 6: Eventual Consistency Patterns

In distributed systems, strong consistency across services is expensive. Accept eventual consistency with compensating mechanisms.

#### Saga Pattern (Distributed Transactions)

```
Choreography Saga for "Place Order":

OrderService                 InventoryService          PaymentService
     |                              |                        |
 OrderPlaced -----------------> ReserveInventory            |
     |                              |                        |
     |                         InventoryReserved -----> ProcessPayment
     |                              |                        |
     |                              |                  PaymentProcessed
     |                              |                        |
 Update order to CONFIRMED <--------+------------------------+

Failure compensation:
  PaymentFailed  ---------> ReleaseInventory (compensating transaction)
                 ---------> OrderCancelled
```

**Key insight:** Each step publishes a success or failure event. Compensating transactions undo previous steps on failure.

#### Outbox Pattern (Reliable Event Publishing)

**Problem:** How to atomically save to DB AND publish to Kafka?

```
WRONG:
  DB.save(order)       // succeeds
  Kafka.publish(event) // fails! Event lost.

RIGHT (Outbox Pattern):

  BEGIN TRANSACTION
    DB.save(order)
    DB.insert(outbox_table, {event_type, payload, status=PENDING})
  COMMIT TRANSACTION

  [Outbox Poller / CDC] (separate process)
    Poll outbox_table WHERE status=PENDING
    Publish to Kafka
    Update status=SENT

  OR use CDC (Debezium):
    Capture INSERT on outbox_table from DB binlog
    Publish to Kafka automatically
```

---

### Overall Microservices Architecture

```
                        [Client Apps]
                             |
                     [API Gateway / BFF]
                    /    |    |    |    \
                   /     |    |    |     \
              [User]  [Order] [Prod] [Search] [Notif]
              Svc      Svc    Svc    Svc      Svc
               |        |      |       |        |
              MySQL   Postgres Mongo  Elastic   Cassandra
                       |
                    [Kafka]
                  (event bus)
                  /    |    \
            [Inventory] [Payment] [Analytics]
            Svc          Svc       Svc
               \           |
                +--[Saga Orchestrator]--+
                
  Cross-Cutting:
  [Service Mesh (Istio)]   -- mTLS, tracing, retries
  [Prometheus + Grafana]   -- metrics
  [Jaeger / Zipkin]        -- distributed tracing
  [Vault]                  -- secrets management
  [Config Service]         -- dynamic configuration
```

---

## Master Cheat Sheet

---

### 1. Latency Numbers Every Engineer Should Know

| Operation | Approx Latency | Notes |
|---|---|---|
| L1 cache reference | 0.5 ns | |
| L2 cache reference | 7 ns | 14x L1 |
| Mutex lock/unlock | 25 ns | |
| Main memory (RAM) reference | 100 ns | 200x L1 |
| Compress 1 KB with Snappy | 3,000 ns (3 µs) | |
| Read 4 KB from SSD | 150,000 ns (150 µs) | |
| Read 1 MB sequentially from RAM | 250 µs | |
| Round trip within datacenter | 500 µs | |
| Read 1 MB sequentially from SSD | 1 ms | 4x RAM |
| Disk seek (HDD) | 10 ms | 20x datacenter RT |
| Read 1 MB sequentially from HDD | 20 ms | |
| Send packet CA -> Netherlands -> CA | 150 ms | |
| DNS lookup | 20-120 ms | varies |
| Redis GET (network) | ~0.5 ms | |
| MySQL query (index, local) | 1-5 ms | |
| MySQL query (full scan, 1M rows) | 1-10 s | avoid |

**Mental Model:**
- RAM: nanoseconds
- SSD: microseconds
- Network (DC): sub-millisecond
- Network (cross-region): 10-100 ms
- Disk (HDD): milliseconds to seconds

---

### 2. Capacity Estimation Quick Reference

#### Storage Units
```
1 KB  = 1,000 bytes      (kilobyte)
1 MB  = 1,000,000 bytes  (megabyte)
1 GB  = 10^9 bytes       (gigabyte)
1 TB  = 10^12 bytes      (terabyte)
1 PB  = 10^15 bytes      (petabyte)

(Note: 1 KiB = 1,024 bytes, but use 1,000 for estimation simplicity)
```

#### Time Units
```
1 day     = 86,400 seconds  ≈ 10^5 seconds
1 month   = 2.5M seconds    ≈ 2.5 * 10^6 seconds
1 year    = 31.5M seconds   ≈ 3 * 10^7 seconds
```

#### Throughput Formulas
```
RPS from DAU:
  RPS = DAU * actions_per_day / 86,400
  Peak RPS = average RPS * peak_factor (typically 2-5x)

Storage per year:
  storage = records_per_second * record_size_bytes * seconds_per_year
           = RPS * size * 3 * 10^7

Bandwidth:
  bandwidth = RPS * average_payload_size
```

#### Common Benchmarks
```
Single Web Server:       1,000 - 10,000 RPS
Single MySQL:            10,000 - 50,000 simple reads/sec
Single Redis node:       100,000 - 500,000 ops/sec
Single Kafka broker:     ~1M messages/sec (simple)
Single Cassandra node:   ~50,000 reads + writes/sec

Network bandwidth (modern server NIC): 10 Gbps = 1.25 GB/s
SSD sequential read: 500 MB/s - 3.5 GB/s (NVMe)
SSD random IOPS: 100,000 - 500,000 IOPS
```

#### Rough Size Estimates
```
User profile:        1 KB
Tweet / short post:  0.3 - 1 KB
Photo (compressed):  300 KB
HD Video (1 min):    100 MB
4K Video (1 min):    400 MB

IPv4 address:        4 bytes
UUID:                16 bytes (128 bits)
Snowflake ID:        8 bytes (64 bits)
Unix timestamp:      8 bytes
SHA-256 hash:        32 bytes
```

---

### 3. System Design Component Selection Guide

| Use Case | Component | Why |
|---|---|---|
| Serve millions of static files | CDN (CloudFront, Akamai) | Edge caching, low latency |
| Session storage, leaderboard | Redis (sorted sets) | In-memory, sub-ms |
| Full-text search | Elasticsearch | Inverted index, scoring |
| Time-series metrics | InfluxDB / Prometheus | Optimized for time-series |
| Wide-column, write-heavy | Cassandra | LSM tree, partition key design |
| Relational, ACID transactions | PostgreSQL / MySQL | ACID, joins, FK constraints |
| Document store, flexible schema | MongoDB | JSON docs, horizontal scale |
| Graph data (social network) | Neo4j / Amazon Neptune | Relationship traversal |
| Async task queue | Kafka / RabbitMQ / SQS | Decoupling, buffering |
| Batch processing (large data) | Spark / Hadoop | Distributed compute |
| Stream processing | Flink / Kafka Streams | Low-latency real-time |
| Object storage (files, media) | S3 / GCS | Cheap, durable, scalable |
| Service discovery | ZooKeeper / Consul / etcd | Coordination primitives |
| API rate limiting | Redis (token bucket) | Atomic incr + expire |
| Distributed lock | Redis (Redlock) / ZooKeeper | Leader election, mutex |
| News feed | Redis ZADD (sorted set) | Score by timestamp |
| Notification delivery | Kafka + FCM/APNs/Twilio | Async, multi-channel |
| Autocomplete | Trie + Redis cache | Prefix search, O(L) |
| Unique ID generation | Twitter Snowflake | Sortable, 64-bit, distributed |
| Config management | etcd / Consul / AppConfig | Consistent, watchable |

---

### 4. Common System Design Trade-offs Reference Table

| Decision | Option A | Option B | When to Choose A | When to Choose B |
|---|---|---|---|---|
| Consistency vs Availability | Strong consistency | Eventual consistency | Banking, inventory, auth | Social feeds, analytics, recommendations |
| SQL vs NoSQL | SQL (MySQL, Postgres) | NoSQL (Cassandra, Mongo) | Complex queries, ACID needed | Massive scale, flexible schema, write-heavy |
| Sync vs Async communication | Synchronous (REST/gRPC) | Async (Kafka/SQS) | Need immediate response | Decouple producers/consumers, high throughput |
| Read replica vs Caching | Read replicas | Cache (Redis) | Data freshness critical | Extreme read throughput, computed aggregates |
| Normalization vs Denormalization | Normalized (3NF) | Denormalized | Write-heavy, data integrity | Read-heavy, query performance critical |
| Monolith vs Microservices | Monolith | Microservices | Small team, early stage | Large org, independent scaling needed |
| Push vs Pull (feed) | Fanout on write (push) | Fanout on read (pull) | Regular users, fast reads | Celebrity users, infrequent reads |
| Single-region vs Multi-region | Single region | Multi-region | Simple, cost-sensitive | High availability, global user base |
| Stateful vs Stateless services | Stateful | Stateless | Session affinity needed | Horizontal scaling, easier deployment |
| Pagination: offset vs cursor | Offset pagination | Cursor pagination | Simple, total count needed | Large datasets, real-time data changes |
| Delivery: at-least-once vs exactly-once | At-least-once | Exactly-once | Idempotent consumers OK | Payment/financial systems |
| Synchronous replication vs Async | Sync replication | Async replication | Data durability critical | Low write latency required |
| Vertical vs Horizontal scaling | Scale up | Scale out | Stateful, simple ops | Commodity hardware, internet scale |
| CDN vs Origin server | CDN | Origin | Static content, global users | Dynamic content, personalized |
| HTTP/REST vs gRPC | REST | gRPC | External APIs, browser clients | Internal services, high RPC throughput |

---

### 5. System Design Interview Checklist

**Scope (5 min):**
- [ ] Functional requirements (what the system does)
- [ ] Non-functional requirements (scale, latency, durability)
- [ ] Out of scope (what you won't design)

**Estimation (5 min):**
- [ ] DAU / MAU
- [ ] Read/write RPS
- [ ] Storage per day/year
- [ ] Bandwidth

**High-Level Design (10 min):**
- [ ] Major components and data flow
- [ ] API design (key endpoints)
- [ ] Database choice and justification

**Deep Dive (15 min):**
- [ ] Bottlenecks identified
- [ ] Scaling each component
- [ ] Failure modes and resilience

**Wrap-up (5 min):**
- [ ] Trade-offs discussed
- [ ] What you'd do differently with more time
- [ ] Monitoring and alerting

---

*End of Chapter 22 Part B — High-Level System Design*
*Volume 5: System Design & Low-Level Design*



