# Volume 3: Backend Systems
# Chapter 10: Microservices

---

## Table of Contents

1. Microservices vs Monolith
2. API Gateway
3. Service Discovery
4. Inter-service Communication
5. Circuit Breaker Pattern
6. Saga Pattern
7. Event-Driven Architecture
8. Distributed Tracing
9. Resilience Patterns
10. Service Mesh
11. Distributed Configuration
12. Health Checks and Readiness Probes
13. Strangler Fig Pattern
14. Data Isolation
15. Microservices Security

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: Microservices vs Monolith

---

#### The Idea

Imagine a large restaurant where every function — taking orders, cooking, washing dishes, and handling payments — happens in one big kitchen. That is a monolith: a single deployable unit where all features live together. It is simple to build at first, easy to test locally, and straightforward to deploy. But as the restaurant grows, one chef's mistake can shut down the whole kitchen, and you cannot hire a specialist pizza team without also retraining everyone else.

Microservices split that restaurant into separate, independently-operated stations: an order counter, a grill, a pastry section, each with its own staff and equipment. Each station can scale, change its recipes, or close for maintenance without stopping the others. Netflix, Amazon, and Uber all moved to this model when their monoliths became too slow to change and too big to scale selectively.

The catch: running ten separate stations is harder to coordinate than one kitchen. You need ways to find each station (service discovery), handle failures when one is down (circuit breakers), and make sure orders do not get lost mid-flow (distributed transactions, sagas). Microservices solve a scaling and team-autonomy problem, but they introduce a distributed-systems complexity problem in return.

---

#### How It Works

**Monolith structure:**
```
Single deployable JAR/WAR
  ├── UserModule
  ├── OrderModule
  ├── InventoryModule
  └── PaymentModule
        — shared DB, shared memory, single process
```

**Microservices structure:**
```
user-service        → own DB, own deployment pipeline
order-service       → own DB, communicates via REST/Kafka
inventory-service   → own DB
payment-service     → own DB
        — each scales independently, each can use different stack
```

**Decomposition strategies:**
```
1. By Business Capability  → OrderService, PaymentService, ShippingService
2. By Bounded Context (DDD) → each service owns its domain model fully
3. By Subdomain             → core domain vs supporting domain vs generic
4. Strangler Fig Pattern    → gradually extract from monolith, route via API Gateway
```

**Tradeoff table:**

| Dimension | Monolith | Microservices |
|---|---|---|
| Deployment | Single unit, simple | Per-service, complex CI/CD |
| Scalability | Scale whole app | Scale per service |
| Team autonomy | Low — shared codebase | High — separate repos/pipelines |
| Latency | In-process calls (fast) | Network calls (slower) |
| Data consistency | ACID transactions | Eventual consistency |
| Fault isolation | One bug can crash all | Failures stay isolated |
| Operational complexity | Low | High — service mesh, discovery, tracing |
| Best for | Small team, early stage | Large org, clear domain boundaries |

**Inline tradeoff:** A distributed monolith is the worst of both worlds — you split the codebase but services still share a database or deploy together. The goal is independent deployability, not just separate codebases.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Tradeoff Question
**"When would you choose a monolith over microservices?"**

**One-line answer:** Start with a monolith unless you have clear team-scale or independent-scaling reasons to split.

**Full answer to give in an interview:**

> "I would default to a monolith for a new product or a small team. The main advantages are simplicity: one codebase, one database, one deployment, and in-process function calls instead of network calls. You can refactor freely because everything is in one place, and you don't need to worry about distributed systems problems like network partitions or eventual consistency.
>
> I'd consider moving to microservices when the monolith causes concrete pain: teams stepping on each other in the same codebase, a single module needing ten times the traffic of others, or different parts needing different tech stacks. The classic signal is Conway's Law in reverse — if your organisation has five autonomous teams, forcing them to share one repository creates coordination overhead that microservices solve.
>
> The trap to avoid is a distributed monolith — splitting into separate services but keeping a shared database or requiring simultaneous deployments. That gives you the operational complexity of microservices with none of the independence benefits."

> *Lead with the monolith default — most interviewers want to hear that you don't reach for microservices by default.*

**Gotcha follow-up they'll ask:** *"What is a bounded context and how does it map to a microservice?"*

> "A bounded context, from Domain-Driven Design, is a boundary within which a particular domain model applies consistently. For example, 'Order' means something specific in the Ordering context — it has a status, line items, a customer reference. In the Shipping context, the same order is just a delivery instruction with an address. If you let both contexts share one Order class, you end up with a god object everyone fights over. A microservice should own exactly one bounded context: its own data model, its own language, its own rules. That is what gives it true independence."

---

##### Q2 — Design Scenario
**"How would you migrate a legacy monolith to microservices without a big-bang rewrite?"**

**One-line answer:** Use the Strangler Fig pattern — incrementally extract services behind an API Gateway while the monolith keeps running.

**Full answer to give in an interview:**

> "The Strangler Fig pattern — named after a vine that grows around a tree and gradually replaces it — is the standard approach. You never rewrite everything at once; instead, you extract one bounded context at a time.
>
> The steps I'd follow: first, put an API Gateway or reverse proxy in front of the monolith so you have one place to route traffic. Second, identify a candidate service to extract — ideally one with a clean interface, a motivated team, and high business value. Third, build the new service in parallel with the monolith handling the same requests. Fourth, run in shadow mode — send traffic to both, compare responses, but only use the monolith's response in production. This validates correctness without risk. Fifth, cut over production traffic to the new service. Finally, delete the corresponding code from the monolith after a confidence period.
>
> The key discipline is database per service — the new service must own its own data store from day one. Sharing a database with the monolith just moves the coupling from code to schema."

> *The shadow mode step shows operational maturity — mention it explicitly.*

**Gotcha follow-up they'll ask:** *"How do you handle data that the old service and new service both need during the transition?"*

> "During the transition you have two options: event-driven sync or dual writes. With event-driven sync, the monolith publishes change events to a Kafka topic and the new service consumes them to build its own copy of the data. With dual writes, the monolith writes to both its own table and the new service's table during the transition period — simpler but you need to handle write failures carefully. After cutover, the new service owns the data and the monolith calls the new service's API to read it, reversing the dependency."

---

> **Common Mistake — Distributed Monolith:** Splitting services but sharing a database couples them at the schema level. One team's migration can break another team's service. Always enforce database-per-service from the start.

---

**Quick Revision (one line):**
Monolith first for simplicity; migrate to microservices via Strangler Fig when you have team-scale pain, independent-scaling needs, or clear bounded context boundaries — but never share a database across services.

---

## Topic 2: API Gateway

---

#### The Idea

Imagine a hotel concierge desk. Every guest comes through the same front door, tells the concierge what they need, and the concierge routes them to the right part of the hotel — restaurant, gym, spa — handles common tasks like checking their keycard, and shields guests from knowing the internal layout. If the spa is closed, the concierge handles that gracefully. That is an API Gateway.

In a microservices system, every client — mobile app, web browser, third-party partner — would otherwise need to know the address of every service: order-service on port 8081, payment-service on port 8082, inventory-service on port 8083. Any time a service moves or splits, every client breaks. An API Gateway solves this by being the single entry point: clients call one address, and the gateway handles routing, authentication, rate limiting, and SSL termination so individual services do not have to.

The important boundary to understand: an API Gateway handles north-south traffic — requests coming in from outside the system. A service mesh (like Istio) handles east-west traffic — service-to-service calls inside the system. They are complementary, not competing.

---

#### How It Works

**Request flow through the gateway:**
```
Client Request
    → API Gateway
        → JWT validation (reject if invalid)
        → Rate limit check (reject if exceeded)
        → Route match (/api/orders/** → order-service)
        → Filter chain (add headers, strip path prefix)
        → Load balance across order-service instances
        → Forward request
    ← Response
        → Response filter (add CORS headers, transform)
    ← Client Response
```

**Cross-cutting concerns handled at the gateway:**
```
Authentication   — validate JWT or API key before request reaches service
Rate Limiting    — per-user or per-IP token bucket to prevent abuse
SSL Termination  — decrypt HTTPS at gateway, services use plain HTTP internally
Request Routing  — path-based or header-based routing to services
Load Balancing   — distribute across healthy instances
Request Logging  — centralised access logs, correlation IDs
Circuit Breaking — stop forwarding to failing services
Request Aggregation (BFF) — compose multiple service calls into one response
```

**Must-memorise gotcha — Spring Cloud Gateway with JWT relay and rate limiting:**

```java
@Configuration
public class GatewayConfig {

    @Bean
    public RouteLocator routes(RouteLocatorBuilder builder) {
        return builder.routes()
            .route("order-service", r -> r
                .path("/api/orders/**")
                .filters(f -> f
                    .tokenRelay()           // forwards the incoming JWT downstream
                    .requestRateLimiter(c -> c
                        .setRateLimiter(redisRateLimiter())
                        .setKeyResolver(userKeyResolver())))
                .uri("lb://order-service"))  // lb:// = Spring Cloud LoadBalancer
            .route("inventory-service", r -> r
                .path("/api/inventory/**")
                .filters(f -> f.tokenRelay())
                .uri("lb://inventory-service"))
            .build();
    }

    @Bean
    public RedisRateLimiter redisRateLimiter() {
        // replenishRate=10 tokens/sec, burstCapacity=20 tokens max
        return new RedisRateLimiter(10, 20);
    }

    @Bean
    public KeyResolver userKeyResolver() {
        // Rate limit per authenticated user (extracted from JWT sub claim)
        return exchange -> exchange.getPrincipal()
            .map(Principal::getName)
            .defaultIfEmpty("anonymous");
    }
}
```

**Tradeoff:** A fat gateway is an anti-pattern. If you put business logic in the gateway — transforming data, orchestrating multiple services — you create a centralised bottleneck that all teams must change for every feature. Keep the gateway thin: routing, auth, rate limiting, and observability only. Business logic belongs in services.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is an API Gateway and what responsibilities does it own?"**

**One-line answer:** An API Gateway is the single entry point for all external clients, handling routing, authentication, rate limiting, and SSL termination centrally so individual services do not have to.

**Full answer to give in an interview:**

> "An API Gateway sits at the edge of your microservices system. Every client — browser, mobile app, third-party caller — sends requests to one address, and the gateway figures out which service to call. The big win is centralising cross-cutting concerns: authentication (validate the JWT once at the gateway so each service does not need to), rate limiting (cap requests per user to protect backend services from abuse), SSL termination (decrypt HTTPS at the edge so internal traffic can be plain HTTP), and request logging (one place to add correlation IDs and write access logs).
>
> It also decouples clients from the internal topology. If you split order-service into order-service and order-history-service, you change the routing rule in the gateway — external clients see no change. Popular implementations include AWS API Gateway, Kong, NGINX Plus, and Spring Cloud Gateway for Java-based systems."

> *Mention the topology decoupling benefit — it's why the gateway exists, and interviewers want to hear that framing.*

**Gotcha follow-up they'll ask:** *"What is the difference between an API Gateway and a service mesh?"*

> "An API Gateway handles north-south traffic — requests entering the system from outside, like from a mobile app or browser. A service mesh like Istio handles east-west traffic — calls between services inside the system. The gateway validates the external JWT and routes to the right service. The service mesh handles mTLS between services, retries, circuit breaking, and observability for service-to-service calls. In a mature microservices architecture you typically have both: the gateway at the edge, the service mesh for internal communication."

---

##### Q2 — Design Scenario
**"How would you implement per-user rate limiting in an API Gateway?"**

**One-line answer:** Use a token bucket algorithm backed by Redis, keyed on the authenticated user ID extracted from the JWT.

**Full answer to give in an interview:**

> "Rate limiting at the gateway protects backend services from abuse — whether from a buggy client hammering an endpoint or a bad actor trying to scrape data. The standard approach is a token bucket: each user gets a bucket of N tokens that refills at a fixed rate. Each request consumes one token; if the bucket is empty, the request is rejected with HTTP 429 Too Many Requests.
>
> In Spring Cloud Gateway you wire up a RedisRateLimiter — Redis stores the token counts so the limit is shared across multiple gateway instances. You define a KeyResolver that extracts the user identity from the JWT subject claim. This means each authenticated user has their own rate limit, and anonymous traffic can be rate-limited separately.
>
> For the replenish rate and burst capacity: set replenishRate to your steady-state allowance per second and burstCapacity to how many you allow in a short spike. For example, 10 requests/second steady state with a burst of 20 handles normal usage patterns without blocking legitimate users."

> *Give concrete numbers — 10 req/s with burst 20 — it shows you have thought about real configuration.*

**Gotcha follow-up they'll ask:** *"What happens if the Redis instance goes down?"*

> "You have two choices: fail open or fail closed. Fail open means if Redis is unavailable, pass all requests through — this protects availability but temporarily removes rate limiting protection. Fail closed means reject all requests when Redis is down — this protects the backend but breaks all users. For most consumer APIs I'd choose fail open with an alert, since service availability is more important than rate limit enforcement during a Redis outage. For security-critical APIs, fail closed is safer."

---

> **Common Mistake — Fat Gateway:** Putting business logic or data transformation in the API Gateway couples all services to it. Every team must coordinate gateway deployments for their feature. Keep the gateway thin — routing, auth, rate limiting, observability only.

---

**Quick Revision (one line):**
An API Gateway is the single external entry point that centralises routing, JWT authentication, rate limiting, and SSL termination — keeping those concerns out of individual services and decoupling clients from the internal service topology.

---

## Topic 3: Service Discovery

---

#### The Idea

When you call a friend, you look up their number in your contacts. You do not memorise the IP address of every server they use. Service discovery solves the same problem for microservices: how does Order Service find Inventory Service when the latter can be running on any of ten machines, with instances starting and stopping constantly?

In a static world you could hardcode IP addresses. But in Kubernetes or AWS ECS, service instances come and go — a deployment spins up new instances on new IPs before the old ones shut down. If Order Service has a hardcoded IP, it breaks every time Inventory Service is redeployed. Service discovery automates the address book: each service registers itself on startup and the discovery mechanism provides a live, up-to-date list of healthy instances.

There are two main styles. In client-side discovery, the calling service (the client) asks a service registry like Eureka for a list of Inventory Service instances and picks one itself. In server-side discovery, the client sends its request to a well-known load balancer (like an AWS ALB or a Kubernetes Service), which looks up the registry and forwards the request — the client does not know the service registry exists.

---

#### How It Works

**Client-side discovery flow:**
```
Order Service startup:
  → Register with Eureka: "I am order-service, running at 10.0.1.5:8080"
  → Heartbeat every 30s to stay registered

Order Service calling Inventory Service:
  → Query Eureka: "Give me all healthy instances of inventory-service"
  ← Eureka returns: [10.0.2.3:8080, 10.0.2.4:8080, 10.0.2.5:8080]
  → Client picks one (round-robin, random, or weighted)
  → Makes HTTP call directly to chosen instance
```

**Server-side discovery flow:**
```
Order Service calling Inventory Service:
  → Sends request to http://inventory-service (DNS name / VIP)
  → Kubernetes Service (or AWS ALB) receives request
  → Queries its own health registry or endpoint checks
  → Forwards to a healthy pod/instance
  (Order Service never touches the registry)
```

**Service discovery comparison:**

| Type | Example | Client awareness | Advantage |
|---|---|---|---|
| Client-side | Eureka + Spring Cloud LoadBalancer | Client queries registry directly | More control, fine-grained load balancing |
| Server-side | Kubernetes Service, AWS ALB | Client just uses DNS name | Simpler client, no registry library needed |
| DNS-based | Kubernetes CoreDNS | Client resolves DNS | Transparent, any language |

**Tradeoff:** Client-side discovery gives more control but requires a discovery client library in every service. Server-side discovery is language-agnostic — a Python service and a Go service both just use the DNS name — making it the default in Kubernetes environments.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Explain client-side vs server-side service discovery and when you would choose each."**

**One-line answer:** Client-side discovery means the caller queries a registry and load-balances itself; server-side discovery means a load balancer does that on the client's behalf.

**Full answer to give in an interview:**

> "In client-side discovery, each service runs a discovery client — in Spring Boot you use Spring Cloud Netflix Eureka Client. On startup the service registers itself with the Eureka server: its hostname, port, and health check URL. To call another service, you query Eureka for a list of healthy instances and use a load balancer like Spring Cloud LoadBalancer to pick one. The advantage is flexibility — you can implement custom load balancing strategies and you have direct visibility into the instance list. The downside is that every service needs the discovery library, which ties you to a specific ecosystem.
>
> In server-side discovery, the client sends a request to a stable DNS name or virtual IP — for example, http://inventory-service in Kubernetes. The Kubernetes Service object sits in front of all inventory-service pods and load-balances across them using iptables or IPVS rules. The client does not know how many pods exist or where they are.
>
> I would choose server-side discovery (Kubernetes Services) for any cloud-native deployment — it is language-agnostic, requires no library in the client, and Kubernetes handles health checking natively. I would choose client-side discovery only if I needed fine-grained control over load balancing — for example, routing to instances in the same availability zone first (zone-aware routing) which Eureka supports natively."

> *Mention zone-aware routing as a concrete reason to choose client-side — it shows depth.*

**Gotcha follow-up they'll ask:** *"What happens to traffic when a service instance crashes before its health check fails?"*

> "There is a window between when an instance crashes and when the registry marks it unhealthy — typically one or two missed heartbeat intervals, which can be 30–90 seconds with Eureka's defaults. During that window, the discovery mechanism may still send traffic to the dead instance. The defense is to combine service discovery with a circuit breaker: after a few failed requests to a specific instance, stop routing to it immediately rather than waiting for the registry to catch up. In Kubernetes, liveness probes detect crashes quickly (typically within seconds) and the Service stops routing to the pod, making this window much smaller."

---

##### Q2 — Design Scenario
**"How does service registration work with Eureka in a Spring Boot application?"**

**One-line answer:** Add the `@EnableEurekaClient` annotation and spring.application.name — the client auto-registers on startup and sends heartbeats to stay registered.

**Full answer to give in an interview:**

> "With Spring Cloud Netflix Eureka, a service registers itself automatically. You add the Eureka client dependency, set a spring.application.name in application.yml — this becomes the service's identifier in the registry — and point eureka.client.serviceUrl.defaultZone at the Eureka server URL. On startup the service posts a registration request to Eureka with its metadata: hostname, port, and a health check URL. Every 30 seconds it sends a heartbeat renewal. If the Eureka server misses three consecutive heartbeats — 90 seconds — it marks the instance as down and removes it from the available list.
>
> To call another service, you inject a RestTemplate or WebClient annotated with @LoadBalanced. The @LoadBalanced annotation intercepts the request, looks up the target service name in Eureka, picks a healthy instance using round-robin, and rewrites the URL with the actual host and port. The caller just uses http://inventory-service/api/items and never handles IP addresses."

> *The 90-second eviction window is a real operational concern — mention it to show operational awareness.*

**Gotcha follow-up they'll ask:** *"What is Eureka's self-preservation mode and when is it a problem?"*

> "Self-preservation mode activates when Eureka detects that more than 15% of its registered services have stopped sending heartbeats within a short window. Instead of removing those registrations — which would be correct if instances actually crashed — Eureka assumes the problem is a network partition affecting heartbeats, and keeps all registrations alive. This protects against mass de-registration during a network hiccup. The downside: if services really did crash, Eureka keeps routing traffic to dead instances. In production, tune the heartbeat and eviction thresholds, and always use a circuit breaker on the client side so individual request failures are caught quickly regardless of what the registry says."

---

> **Common Mistake — Stale Registry Entries:** Relying solely on service discovery without a circuit breaker means traffic goes to crashed instances until the registry catches up. Always pair discovery with circuit breaking so failures are detected at the request level, not just the heartbeat level.

---

**Quick Revision (one line):**
Service discovery automates the address book for microservices — client-side (Eureka) has the caller query a registry and load-balance itself; server-side (Kubernetes Service) has a load balancer do it transparently; always combine with circuit breakers to handle the stale-registration window.

---

## Topic 4: Inter-service Communication

---

#### The Idea

When two people need to collaborate, they can either call each other on the phone — synchronous, both parties must be present — or leave a note in a mailbox — asynchronous, the sender does not wait for a response. Microservices face the same choice, and picking the wrong one has serious consequences.

Synchronous communication means the calling service (Order Service) waits for a response from the called service (Inventory Service) before it can proceed. If Inventory Service is slow or down, Order Service is blocked. This creates tight temporal coupling — both services must be healthy and available at the same time for the call to succeed. REST (HTTP) and gRPC are the two main synchronous protocols.

Asynchronous communication means Order Service publishes an event — "order placed" — to a message broker like Kafka, and Inventory Service consumes that event whenever it is ready. Order Service does not wait; it continues. This decouples the services in time — Inventory Service can be down for an hour and the events queue up, processed when it recovers. The tradeoff is eventual consistency: the system will be in a consistent state eventually, but not immediately after the initial write.

---

#### How It Works

**Synchronous — REST vs gRPC:**
```
REST (HTTP/JSON):
  + Human-readable, universally supported, easy to debug
  + Works with any language or framework
  - Serialisation overhead (JSON text parsing)
  - No enforced contract (any JSON is valid)

gRPC (HTTP/2 + Protocol Buffers):
  + Binary protocol — 5-10x smaller payloads, faster serialisation
  + Strongly typed contract via .proto files — compiler catches mismatches
  + Streaming support (server-streaming, bidirectional)
  - Harder to debug (binary format)
  - Requires protobuf tooling in every service
```

**Asynchronous — Kafka event flow:**
```
Order Service:
  → Creates order in its own DB
  → Publishes OrderPlacedEvent { orderId, items, userId } to Kafka topic "order-events"
  → Returns 200 OK to client immediately

Inventory Service (consumer):
  → Reads OrderPlacedEvent from Kafka
  → Decrements inventory
  → Publishes InventoryReservedEvent to "inventory-events"

Notification Service (consumer):
  → Reads OrderPlacedEvent
  → Sends confirmation email
```

**Pattern selection guide:**

| Scenario | Pattern | Reason |
|---|---|---|
| User-facing read query | Sync REST/gRPC | Low latency required, user waits |
| Critical path (payment check) | Sync gRPC | Performance + type safety |
| Background processing | Async Kafka | Decoupling, retry, buffering |
| Cross-domain events | Async Kafka / EventBridge | Loose coupling, audit trail |
| Real-time push | WebSocket / SSE | Push semantics |

**Must-memorise gotcha — Kafka producer with idempotency for exactly-once delivery:**

```java
@Service
public class OrderService {

    private final KafkaTemplate<String, OrderPlacedEvent> kafkaTemplate;
    private final OrderRepository orderRepository;

    @Transactional
    public OrderResponse placeOrder(OrderRequest request) {
        // 1. Save order to DB within the same transaction
        Order order = orderRepository.save(new Order(request));

        // 2. Publish event — use orderId as the Kafka message key
        //    Same key always goes to the same partition (ordering guaranteed)
        OrderPlacedEvent event = new OrderPlacedEvent(order.getId(),
                                                       request.getProductId(),
                                                       request.getQuantity());
        kafkaTemplate.send("order-events", order.getId().toString(), event);

        return new OrderResponse(order.getId(), order.getTotalAmount());
    }
}
```

application.yml for idempotent producer (prevent duplicate messages on retry):
```java
// In application.yml (shown as Java properties for clarity):
// spring.kafka.producer.enable-idempotence=true
// spring.kafka.producer.acks=all
// spring.kafka.producer.retries=Integer.MAX_VALUE
// spring.kafka.producer.max-in-flight-requests-per-connection=5
```

**Tradeoff:** Transactional outbox pattern is more reliable than direct `kafkaTemplate.send()` — save the event to a DB table in the same transaction as the order, then a separate process reads and publishes it. This prevents the "order saved, Kafka publish crashed" split-brain scenario.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Tradeoff Question
**"How do you choose between synchronous and asynchronous inter-service communication?"**

**One-line answer:** Use synchronous (REST/gRPC) when the caller needs an immediate result to proceed; use asynchronous (Kafka/RabbitMQ) when the operation can be processed later and decoupling is more important than immediacy.

**Full answer to give in an interview:**

> "The key question is: does the caller need the result before it can continue? If a user is waiting for a response — say, checking their account balance — you need synchronous communication. Synchronous REST or gRPC gives you an immediate answer, predictable latency, and simple error handling: you know right now whether the call succeeded or failed.
>
> If the operation does not need an immediate result — sending a confirmation email, updating a search index, reserving inventory in the background — asynchronous messaging is better. You publish an event to Kafka, return success to the user immediately, and let downstream services process it in their own time. This gives you natural buffering (events queue up if a service is slow), retry handling (Kafka retains events so a restarted service catches up), and fault isolation (Inventory Service being down does not block order creation).
>
> The tradeoff with async is eventual consistency: the system reaches a consistent state eventually, but there is a window where Order Service has created an order but Inventory Service has not yet decremented the stock. You need to design for this — use idempotent consumers so processing the same event twice does not double-decrement, and use saga patterns for multi-step operations that need compensation if a later step fails."

> *Mentioning idempotent consumers shows you understand the real operational concern, not just the happy path.*

**Gotcha follow-up they'll ask:** *"What is the Saga pattern and when do you need it?"*

> "A saga is a sequence of local transactions, each publishing an event that triggers the next step, with compensating transactions defined for each step in case of failure. You need it when an operation spans multiple services and you need something like a transaction — but you cannot use a distributed database transaction across service boundaries.
>
> Example: placing an order involves creating the order, reserving inventory, and charging payment. In a choreography-based saga, each service listens for events and publishes the next one. If payment fails, it publishes a PaymentFailedEvent; Inventory Service listens, sees that event, and publishes a StockReleasedEvent to undo the reservation. In an orchestration-based saga, an OrderSaga orchestrator calls each service in sequence and issues compensating commands on failure. Orchestration is easier to understand and debug; choreography is more decoupled."

---

##### Q2 — Concept Check
**"What is idempotency in the context of messaging and why does it matter?"**

**One-line answer:** Idempotency means processing the same message multiple times produces the same result as processing it once — critical because Kafka and other brokers guarantee at-least-once delivery, not exactly-once.

**Full answer to give in an interview:**

> "Kafka's delivery guarantee is at-least-once by default: in a failure scenario (consumer crashed after processing but before committing the offset), Kafka may redeliver the same message. If your consumer deducts inventory on every message, a redelivered message deducts twice — a serious bug. Idempotency is the defence.
>
> The standard approach: include a unique event ID in every message. In the consumer, before processing, check whether you have already processed that event ID — store processed IDs in a database or Redis set. If the ID is already there, skip processing. If not, process and record the ID atomically.
>
> For Kafka producers, enable idempotent producer mode (enable-idempotence=true) — Kafka assigns each producer a PID and sequence number per partition. If the broker receives a duplicate (same PID + sequence), it discards it. Combined with exactly-once semantics (transactions), this prevents both producer duplicates and consumer duplicates."

> *Be specific about the two levels — producer idempotency and consumer idempotency — they address different failure modes.*

**Gotcha follow-up they'll ask:** *"What is the transactional outbox pattern?"*

> "The transactional outbox pattern solves the dual-write problem: you want to save an order to the database and publish an event to Kafka atomically, but there is no single transaction spanning both. If you save the order and then Kafka publish crashes, your database has the order but no event was published. The fix: add an outbox table to your database. In the same database transaction that saves the order, also insert the event into the outbox table. A separate background process — a CDC tool like Debezium reading the database transaction log, or a polling scheduler — reads from the outbox table and publishes to Kafka. Failure after Kafka publish just causes a redelivery (idempotent consumers handle it). The order and the event are always either both saved or both absent."

---

> **Common Mistake — Synchronous Chains:** Chaining synchronous calls across five services means if any one of them is slow or down, the entire chain fails. Each link in the chain multiplies the failure probability. Prefer async for non-critical-path operations, and add circuit breakers to every synchronous call.

---

**Quick Revision (one line):**
Use synchronous REST/gRPC when the caller needs an immediate result; use async Kafka when decoupling and resilience matter more than immediacy — always design for idempotency since at-least-once delivery means duplicates will happen, and use the transactional outbox pattern to atomically pair DB writes with event publishing.

---

## Topic 5: Circuit Breaker Pattern

<svg viewBox="0 0 760 340" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="width:100%; max-width:760px; display:block; margin:16px 0;">
  <defs>
    <style>
      /* ── Fonts ── */
      text { font-family: 'Segoe UI', system-ui, sans-serif; }
      /* ══════════════════════════════════════════
         TIMING MAP  (total loop = 40s @ 0.2x speed, presented as ~8s visually)
         0–8s   CLOSED  (normal flow)
         8–14s  FAILURES accumulate
         14–18s OPEN    (blocked)
         18–24s OPEN    (countdown)
         24–28s HALF-OPEN (probe)
         28–32s SUCCESS → back CLOSED
         32–40s CLOSED  (loop tail, sync with 0)
         ══════════════════════════════════════════ */
      /* ── Background panel for state box ── */
      #state-panel {
        animation: stateColor 40s linear infinite;
      }
      @keyframes stateColor {
        0%,  20%   { fill: #10b98133; stroke: #10b981; }   /* CLOSED  */
        20%, 35%   { fill: #ef444433; stroke: #ef4444; }   /* OPEN    */
        35%, 60%   { fill: #ef444433; stroke: #ef4444; }   /* OPEN    */
        60%, 70%   { fill: #f59e0b33; stroke: #f59e0b; }   /* HALF-OPEN */
        70%, 80%   { fill: #10b98133; stroke: #10b981; }   /* CLOSED again */
        80%, 100%  { fill: #10b98133; stroke: #10b981; }
      }
      /* ── State label text ── */
      #state-label {
        animation: stateLabel 40s linear infinite;
        fill: #10b981;
      }
      @keyframes stateLabel {
        0%,  20%   { fill: #10b981; }
        20%, 60%   { fill: #ef4444; }
        60%, 70%   { fill: #f59e0b; }
        70%, 100%  { fill: #10b981; }
      }
      /* ── Sub-state description ── */
      #state-desc {
        animation: descAnim 40s linear infinite;
        fill: #94a3b8;
      }
      /* ── Wire / path line colors ── */
      #wire {
        animation: wireColor 40s linear infinite;
      }
      @keyframes wireColor {
        0%,  20%   { stroke: #10b981; opacity: 1; }
        20%, 60%   { stroke: #ef4444; opacity: 0.4; }
        60%, 70%   { stroke: #f59e0b; opacity: 0.8; }
        70%, 100%  { stroke: #10b981; opacity: 1; }
      }
      /* ════════════════════
         REQUEST DOTS – CLOSED (flow left→right)
         ════════════════════ */
      .dot-closed {
        r: 5;
        fill: #10b981;
        opacity: 0;
      }
      /* dot 1 */
      #d1 { animation: dotFlow1 40s linear infinite; }
      @keyframes dotFlow1 {
        0%        { opacity:0; cx:130; cy:170; }
        1%        { opacity:1; cx:130; cy:170; }
        7%        { opacity:1; cx:630; cy:170; }
        7.5%      { opacity:0; cx:630; cy:170; }
        20%       { opacity:0; cx:130; cy:170; }
        /* OPEN – off */
        60%       { opacity:0; cx:130; cy:170; }
        /* CLOSED again */
        71%       { opacity:0; cx:130; cy:170; }
        72%       { opacity:1; cx:130; cy:170; }
        78%       { opacity:1; cx:630; cy:170; }
        79%       { opacity:0; cx:630; cy:170; }
        100%      { opacity:0; cx:130; cy:170; }
      }
      /* dot 2 (offset) */
      #d2 { animation: dotFlow2 40s linear infinite; }
      @keyframes dotFlow2 {
        0%        { opacity:0; cx:130; cy:170; }
        3%        { opacity:0; cx:130; cy:170; }
        4%        { opacity:1; cx:130; cy:170; }
        10%       { opacity:1; cx:630; cy:170; }
        10.5%     { opacity:0; cx:630; cy:170; }
        20%       { opacity:0; cx:130; cy:170; }
        60%       { opacity:0; cx:130; cy:170; }
        74%       { opacity:0; cx:130; cy:170; }
        75%       { opacity:1; cx:130; cy:170; }
        81%       { opacity:1; cx:630; cy:170; }
        81.5%     { opacity:0; cx:630; cy:170; }
        100%      { opacity:0; cx:130; cy:170; }
      }
      /* dot 3 */
      #d3 { animation: dotFlow3 40s linear infinite; }
      @keyframes dotFlow3 {
        0%        { opacity:0; cx:130; cy:170; }
        13%       { opacity:0; cx:130; cy:170; }
        14%       { opacity:1; cx:130; cy:170; }
        20%       { opacity:0; cx:130; cy:170; }  /* cut off at OPEN */
        60%       { opacity:0; cx:130; cy:170; }
        86%       { opacity:0; cx:130; cy:170; }
        87%       { opacity:1; cx:130; cy:170; }
        93%       { opacity:1; cx:630; cy:170; }
        94%       { opacity:0; cx:630; cy:170; }
        100%      { opacity:0; cx:130; cy:170; }
      }
      /* ════════════════════
         FAILURE DOTS (red, bounce back)
         ════════════════════ */
      /* Failure dot 1 – crosses then bounces at breaker */
      #f1 { animation: failDot1 40s linear infinite; }
      @keyframes failDot1 {
        0%        { opacity:0; cx:130; cy:170; fill:#ef4444; }
        20%       { opacity:0; cx:130; cy:170; fill:#ef4444; }
        20.5%     { opacity:1; cx:130; cy:170; fill:#ef4444; }
        22%       { opacity:1; cx:380; cy:170; fill:#ef4444; } /* hits breaker */
        23%       { opacity:1; cx:300; cy:170; fill:#ef4444; } /* bounce */
        23.5%     { opacity:0; cx:250; cy:170; fill:#ef4444; }
        60%       { opacity:0; cx:130; cy:170; fill:#ef4444; }
        100%      { opacity:0; cx:130; cy:170; fill:#ef4444; }
      }
      #f2 { animation: failDot2 40s linear infinite; }
      @keyframes failDot2 {
        0%,25%    { opacity:0; cx:130; cy:170; fill:#ef4444; }
        25.5%     { opacity:1; cx:130; cy:170; fill:#ef4444; }
        27%       { opacity:1; cx:380; cy:170; fill:#ef4444; }
        28%       { opacity:1; cx:300; cy:170; fill:#ef4444; }
        28.5%     { opacity:0; cx:250; cy:170; fill:#ef4444; }
        60%       { opacity:0; cx:130; cy:170; fill:#ef4444; }
        100%      { opacity:0; cx:130; cy:170; fill:#ef4444; }
      }
      #f3 { animation: failDot3 40s linear infinite; }
      @keyframes failDot3 {
        0%,30%    { opacity:0; cx:130; cy:170; fill:#ef4444; }
        30.5%     { opacity:1; cx:130; cy:170; fill:#ef4444; }
        32%       { opacity:1; cx:380; cy:170; fill:#ef4444; }
        33%       { opacity:1; cx:300; cy:170; fill:#ef4444; }
        33.5%     { opacity:0; cx:250; cy:170; fill:#ef4444; }
        60%       { opacity:0; cx:130; cy:170; fill:#ef4444; }
        100%      { opacity:0; cx:130; cy:170; fill:#ef4444; }
      }
      /* ════════════════════
         HALF-OPEN probe dot (amber)
         ════════════════════ */
      #probe { animation: probeDot 40s linear infinite; fill:#f59e0b; }
      @keyframes probeDot {
        0%,60%    { opacity:0; cx:130; cy:170; }
        60.5%     { opacity:1; cx:130; cy:170; }
        64%       { opacity:1; cx:630; cy:170; }
        64.5%     { opacity:0; cx:630; cy:170; }
        70%       { opacity:0; cx:130; cy:170; }
        100%      { opacity:0; cx:130; cy:170; }
      }
      /* ════════════════════
         BREAKER SYMBOL (switch icon in center)
         ════════════════════ */
      #breaker-line {
        animation: breakerSwitch 40s linear infinite;
        stroke-width: 3;
        stroke-linecap: round;
      }
      @keyframes breakerSwitch {
        /* CLOSED: line goes straight across (connected) */
        0%,  19.9% { stroke: #10b981; }
        20%, 59.9% { stroke: #ef4444; }
        60%, 69.9% { stroke: #f59e0b; }
        70%, 100%  { stroke: #10b981; }
      }
      /* The breaker "arm" angle */
      #breaker-arm {
        transform-origin: 370px 170px;
        animation: breakerArm 40s linear infinite;
      }
      @keyframes breakerArm {
        0%,  20%   { transform: rotate(0deg); }     /* CLOSED – flat */
        20.1%      { transform: rotate(-45deg); }    /* OPEN – kicked up */
        20%, 60%   { transform: rotate(-45deg); }
        60.1%      { transform: rotate(-20deg); }    /* HALF-OPEN – partial */
        60%, 70%   { transform: rotate(-20deg); }
        70.1%      { transform: rotate(0deg); }      /* CLOSED again */
        70%, 100%  { transform: rotate(0deg); }
      }
      /* ════════════════════
         FAILURE COUNTER
         ════════════════════ */
      .fail-count {
        fill: #ef4444;
        font-size: 13px;
        font-weight: 700;
        opacity: 0;
      }
      #fc1 { animation: showFc1 40s linear infinite; }
      @keyframes showFc1 {
        0%,19%  { opacity:0; }
        19.5%   { opacity:1; }
        21%     { opacity:1; }
        22%     { opacity:0; }
        100%    { opacity:0; }
      }
      #fc2 { animation: showFc2 40s linear infinite; }
      @keyframes showFc2 {
        0%,22%  { opacity:0; }
        22.5%   { opacity:1; }
        24%     { opacity:1; }
        25%     { opacity:0; }
        100%    { opacity:0; }
      }
      #fc3 { animation: showFc3 40s linear infinite; }
      @keyframes showFc3 {
        0%,25%  { opacity:0; }
        25.5%   { opacity:1; }
        27%     { opacity:1; }
        28%     { opacity:0; }
        100%    { opacity:0; }
      }
      #fc4 { animation: showFc4 40s linear infinite; }
      @keyframes showFc4 {
        0%,28%  { opacity:0; }
        28.5%   { opacity:1; }
        30%     { opacity:1; }
        31%     { opacity:0; }
        100%    { opacity:0; }
      }
      #fc5 { animation: showFc5 40s linear infinite; }
      @keyframes showFc5 {
        0%,31%  { opacity:0; }
        31.5%   { opacity:1; }
        35%     { opacity:1; }
        36%     { opacity:0; }
        100%    { opacity:0; }
      }
      /* ════════════════════
         COUNTDOWN TIMER
         ════════════════════ */
      .countdown { fill: #94a3b8; font-size: 12px; }
      #timer-group { animation: timerVis 40s linear infinite; opacity: 0; }
      @keyframes timerVis {
        0%,35%   { opacity:0; }
        35.5%    { opacity:1; }
        60%      { opacity:1; }
        61%      { opacity:0; }
        100%     { opacity:0; }
      }
      #timer-bar-fg {
        animation: timerBar 40s linear infinite;
        fill: #ef4444;
      }
      @keyframes timerBar {
        0%,35%  { width:100; }
        60%     { width:0; }
        100%    { width:100; }
      }
      /* ════════════════════
         TRANSITION LABELS (arrows + text)
         ════════════════════ */
      .trans-label { font-size: 10px; fill: #64748b; }
      #lbl-open  { animation: lblOpen 40s linear infinite; opacity:0; }
      @keyframes lblOpen {
        0%,19%  { opacity:0; }
        20%     { opacity:1; }
        21%     { opacity:0; }
        100%    { opacity:0; }
      }
      #lbl-halfopen { animation: lblHalf 40s linear infinite; opacity:0; }
      @keyframes lblHalf {
        0%,59%  { opacity:0; }
        60%     { opacity:1; }
        61%     { opacity:0; }
        100%    { opacity:0; }
      }
      #lbl-closed { animation: lblClosed 40s linear infinite; opacity:0; }
      @keyframes lblClosed {
        0%,69%  { opacity:0; }
        70%     { opacity:1; }
        71%     { opacity:0; }
        100%    { opacity:0; }
      }
      /* ════════════════════
         "REJECTED" badge
         ════════════════════ */
      #rejected-badge {
        animation: rejectedVis 40s linear infinite;
        opacity: 0;
      }
      @keyframes rejectedVis {
        0%,20%  { opacity:0; }
        22%     { opacity:1; }
        23%     { opacity:0; }
        25%     { opacity:1; }
        26%     { opacity:0; }
        28%     { opacity:1; }
        29%     { opacity:0; }
        31%     { opacity:1; }
        32%     { opacity:0; }
        100%    { opacity:0; }
      }
      /* ════════════════════
         SUCCESS badge (HALF-OPEN)
         ════════════════════ */
      #success-badge {
        animation: successVis 40s linear infinite;
        opacity: 0;
      }
      @keyframes successVis {
        0%,64%  { opacity:0; }
        65%     { opacity:1; }
        70%     { opacity:1; }
        71%     { opacity:0; }
        100%    { opacity:0; }
      }
      /* ── Glow pulse on state box ── */
      #state-glow {
        animation: glowPulse 2s ease-in-out infinite, glowColor 40s linear infinite;
        opacity: 0.3;
      }
      @keyframes glowPulse {
        0%,100% { opacity:0.15; }
        50%     { opacity:0.35; }
      }
      @keyframes glowColor {
        0%,20%  { fill:#10b981; }
        20%,60% { fill:#ef4444; }
        60%,70% { fill:#f59e0b; }
        70%,100%{ fill:#10b981; }
      }
    </style>
    <!-- Arrow marker -->
    <marker id="arrowGreen" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#10b981"/>
    </marker>
    <marker id="arrowGray" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#64748b"/>
    </marker>
    <marker id="arrowAmber" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#f59e0b"/>
    </marker>
    <!-- Filter: glow -->
    <filter id="glow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="4" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="softGlow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="8" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <!-- ══ BACKGROUND ══ -->
  <rect width="760" height="340" fill="#f8fafc"/>
  <!-- Grid lines (subtle) -->
  <g stroke="#e2e8f0" stroke-width="1" opacity="0.6">
    <line x1="0" y1="85" x2="760" y2="85"/>
    <line x1="0" y1="170" x2="760" y2="170"/>
    <line x1="0" y1="255" x2="760" y2="255"/>
    <line x1="190" y1="0" x2="190" y2="340"/>
    <line x1="380" y1="0" x2="380" y2="340"/>
    <line x1="570" y1="0" x2="570" y2="340"/>
  </g>
  <!-- ══ TITLE ══ -->
  <text x="380" y="28" text-anchor="middle" fill="#1e293b" font-size="16" font-weight="700" letter-spacing="1">
    Circuit Breaker Pattern
  </text>
  <text x="380" y="46" text-anchor="middle" fill="#64748b" font-size="10">
    Microservices Resilience Pattern — 3-State Lifecycle
  </text>
  <!-- ══ SERVICE A BOX ══ -->
  <rect x="20" y="140" width="110" height="60" rx="8" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5"/>
  <text x="75" y="166" text-anchor="middle" fill="#64748b" font-size="11" font-weight="600">Service A</text>
  <text x="75" y="182" text-anchor="middle" fill="#64748b" font-size="9">(caller)</text>
  <!-- Service A icon: simple server lines -->
  <rect x="55" y="188" width="40" height="5" rx="2" fill="#1e293b"/>
  <!-- ══ SERVICE B BOX ══ -->
  <rect x="630" y="140" width="110" height="60" rx="8" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1.5"/>
  <text x="685" y="166" text-anchor="middle" fill="#64748b" font-size="11" font-weight="600">Service B</text>
  <text x="685" y="182" text-anchor="middle" fill="#64748b" font-size="9">(dependency)</text>
  <rect x="665" y="188" width="40" height="5" rx="2" fill="#1e293b"/>
  <!-- ══ WIRE / PATH ══ -->
  <line id="wire" x1="130" y1="170" x2="350" y2="170" stroke="#10b981" stroke-width="2" stroke-dasharray="6 3"/>
  <line id="wire2" x1="410" y1="170" x2="630" y2="170" stroke="#10b981" stroke-width="2" stroke-dasharray="6 3">
    <animate attributeName="stroke" values="#10b981;#10b981;#ef4444;#ef4444;#ef4444;#ef4444;#f59e0b;#f59e0b;#10b981;#10b981"
             keyTimes="0;0.2;0.2001;0.6;0.6001;0.7;0.7001;0.8;0.8001;1"
             dur="40s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="1;1;0.3;0.3;0.3;0.3;0.8;0.8;1;1"
             keyTimes="0;0.2;0.2001;0.6;0.6001;0.7;0.7001;0.8;0.8001;1"
             dur="40s" repeatCount="indefinite"/>
  </line>
  <!-- ══ CIRCUIT BREAKER SYMBOL ══ -->
  <!-- Outer ring -->
  <circle cx="380" cy="170" r="32" fill="#f8fafc" stroke-width="2">
    <animate attributeName="stroke" values="#10b981;#10b981;#ef4444;#ef4444;#f59e0b;#f59e0b;#10b981;#10b981"
             keyTimes="0;0.2;0.2001;0.6;0.6001;0.7;0.7001;1"
             dur="40s" repeatCount="indefinite"/>
  </circle>
  <!-- Glow circle -->
  <circle id="state-glow" cx="380" cy="170" r="38" fill="#10b981" filter="url(#softGlow)"/>
  <!-- Breaker contacts -->
  <circle cx="354" cy="170" r="3" fill="#64748b"/>
  <circle cx="406" cy="170" r="3" fill="#64748b"/>
  <!-- Breaker arm (animated rotation) -->
  <g id="breaker-arm">
    <line x1="354" y1="170" x2="406" y2="170" stroke="#10b981" stroke-width="3" stroke-linecap="round">
      <animate attributeName="stroke"
               values="#10b981;#10b981;#ef4444;#ef4444;#f59e0b;#f59e0b;#10b981;#10b981"
               keyTimes="0;0.2;0.2001;0.6;0.6001;0.7;0.7001;1"
               dur="40s" repeatCount="indefinite"/>
      <!-- Arm angle via x2/y2 -->
      <animate attributeName="x2"
               values="406;406;406;406;400;400;406;406"
               keyTimes="0;0.199;0.2;0.599;0.6;0.699;0.7;1"
               dur="40s" repeatCount="indefinite"/>
      <animate attributeName="y2"
               values="170;170;155;155;160;160;170;170"
               keyTimes="0;0.199;0.2;0.599;0.6;0.699;0.7;1"
               dur="40s" repeatCount="indefinite"/>
    </line>
  </g>
  <!-- ══ STATE PANEL (center top) ══ -->
  <rect id="state-panel" x="295" y="65" width="170" height="55" rx="10"
        fill="#10b98133" stroke="#10b981" stroke-width="2"/>
  <!-- State name -->
  <text id="state-label" x="380" y="89" text-anchor="middle"
        font-size="18" font-weight="800" letter-spacing="2">
    CLOSED
    <animate attributeName="textContent"
             values="CLOSED;CLOSED;OPEN;OPEN;HALF-OPEN;HALF-OPEN;CLOSED;CLOSED"
             keyTimes="0;0.199;0.2;0.599;0.6;0.699;0.7;1"
             dur="40s" repeatCount="indefinite"/>
  </text>
  <!-- State sub-description -->
  <text x="380" y="108" text-anchor="middle" fill="#64748b" font-size="10">
    <animate attributeName="textContent"
             values="Requests flowing normally;Requests flowing normally;All requests rejected;All requests rejected;Probe request allowed;Probe request allowed;Requests flowing normally;Requests flowing normally"
             keyTimes="0;0.199;0.2;0.599;0.6;0.699;0.7;1"
             dur="40s" repeatCount="indefinite"/>
  </text>
  <!-- ══ ANIMATED REQUEST DOTS ══ -->
  <circle id="d1" class="dot-closed" cx="130" cy="170" r="5" fill="#10b981" filter="url(#glow)"/>
  <circle id="d2" class="dot-closed" cx="130" cy="170" r="5" fill="#10b981" filter="url(#glow)"/>
  <circle id="d3" class="dot-closed" cx="130" cy="170" r="5" fill="#10b981" filter="url(#glow)"/>
  <!-- Failure dots (bounce back) -->
  <circle id="f1" cx="130" cy="170" r="5" fill="#ef4444" opacity="0" filter="url(#glow)"/>
  <circle id="f2" cx="130" cy="170" r="5" fill="#ef4444" opacity="0" filter="url(#glow)"/>
  <circle id="f3" cx="130" cy="170" r="5" fill="#ef4444" opacity="0" filter="url(#glow)"/>
  <!-- Probe dot (amber, HALF-OPEN) -->
  <circle id="probe" cx="130" cy="170" r="5" fill="#f59e0b" opacity="0" filter="url(#glow)"/>
  <!-- ══ FAILURE COUNTER ══ -->
  <g transform="translate(280,225)">
    <rect x="-5" y="-18" width="80" height="24" rx="4" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1" opacity="0">
      <animate attributeName="opacity"
               values="0;0;1;1;0;0"
               keyTimes="0;0.185;0.19;0.36;0.37;1"
               dur="40s" repeatCount="indefinite"/>
    </rect>
    <text fill="#64748b" font-size="10" y="0">Failures: </text>
    <text id="fc1" class="fail-count" x="52" y="0">1/5</text>
    <text id="fc2" class="fail-count" x="52" y="0">2/5</text>
    <text id="fc3" class="fail-count" x="52" y="0">3/5</text>
    <text id="fc4" class="fail-count" x="52" y="0">4/5</text>
    <text id="fc5" class="fail-count" x="52" y="0">5/5 !</text>
  </g>
  <!-- ══ COUNTDOWN TIMER ══ -->
  <g id="timer-group" transform="translate(280,265)">
    <text fill="#64748b" font-size="11" y="0">Retry after:</text>
    <rect x="0" y="6" width="100" height="6" rx="3" fill="#f1f5f9"/>
    <rect id="timer-bar-fg" x="0" y="6" width="100" height="6" rx="3" fill="#ef4444">
      <animate attributeName="width" values="0;0;100;100;0;0"
               keyTimes="0;0.35;0.351;0.599;0.6;1"
               dur="40s" calcMode="linear" repeatCount="indefinite"/>
    </rect>
    <text fill="#ef4444" font-size="10" y="22">
      <animate attributeName="textContent"
               values="30s;30s;30s;25s;20s;15s;10s;5s;0s;0s"
               keyTimes="0;0.35;0.351;0.4;0.45;0.5;0.55;0.58;0.6;1"
               dur="40s" repeatCount="indefinite"/>
    </text>
  </g>
  <!-- ══ "REJECTED" BADGE ══ -->
  <g id="rejected-badge" transform="translate(225,155)">
    <rect x="-2" y="-14" width="60" height="20" rx="4" fill="#ef444422" stroke="#ef4444" stroke-width="1"/>
    <text fill="#ef4444" font-size="11" font-weight="700" text-anchor="middle" x="28" y="0">✕ BLOCKED</text>
  </g>
  <!-- ══ SUCCESS BADGE ══ -->
  <g id="success-badge" transform="translate(560,145)">
    <rect x="-2" y="-14" width="68" height="20" rx="4" fill="#10b98122" stroke="#10b981" stroke-width="1"/>
    <text fill="#10b981" font-size="11" font-weight="700" text-anchor="middle" x="32" y="0">✓ SUCCESS</text>
  </g>
  <!-- ══ TRANSITION ARROWS & LABELS ══ -->
  <!-- CLOSED → OPEN (arc over top) -->
  <g id="lbl-open">
    <path d="M 340,65 Q 340,30 420,65" fill="none" stroke="#ef4444" stroke-width="1.5"
          stroke-dasharray="4 2" marker-end="url(#arrowGray)"/>
    <text x="380" y="26" text-anchor="middle" fill="#ef4444" font-size="9" font-weight="600">
      Failure threshold reached
    </text>
  </g>
  <!-- OPEN → HALF-OPEN (right arc) -->
  <g id="lbl-halfopen">
    <path d="M 450,65 Q 540,20 500,110" fill="none" stroke="#f59e0b" stroke-width="1.5"
          stroke-dasharray="4 2" marker-end="url(#arrowAmber)"/>
    <text x="545" y="38" text-anchor="start" fill="#f59e0b" font-size="9" font-weight="600">Timeout expired</text>
  </g>
  <!-- HALF-OPEN → CLOSED (bottom arc) -->
  <g id="lbl-closed">
    <path d="M 310,120 Q 240,160 310,200" fill="none" stroke="#10b981" stroke-width="1.5"
          stroke-dasharray="4 2" marker-end="url(#arrowGreen)"/>
    <text x="200" y="165" text-anchor="middle" fill="#10b981" font-size="9" font-weight="600">Probe success</text>
  </g>
  <!-- ══ LEGEND (bottom) ══ -->
  <g transform="translate(60,305)">
    <circle cx="8" cy="0" r="5" fill="#10b981"/>
    <text x="18" y="4" fill="#64748b" font-size="10">CLOSED — normal flow</text>
  </g>
  <g transform="translate(240,305)">
    <circle cx="8" cy="0" r="5" fill="#ef4444"/>
    <text x="18" y="4" fill="#64748b" font-size="10">OPEN — fast-fail</text>
  </g>
  <g transform="translate(390,305)">
    <circle cx="8" cy="0" r="5" fill="#f59e0b"/>
    <text x="18" y="4" fill="#64748b" font-size="10">HALF-OPEN — single probe</text>
  </g>
  <g transform="translate(590,305)">
    <circle cx="8" cy="0" r="5" fill="#ef4444" opacity="0.5"/>
    <text x="18" y="4" fill="#64748b" font-size="10">FAIL → back to OPEN</text>
  </g>
  <!-- ══ BOTTOM DIVIDER ══ -->
  <line x1="40" y1="295" x2="720" y2="295" stroke="#e2e8f0" stroke-width="1"/>
</svg>

---

#### The Idea

Imagine a house electrical circuit breaker. When current exceeds a safe threshold — because of a short circuit somewhere downstream — the breaker trips open, cutting the circuit. You do not get a catastrophic meltdown; you get a controlled failure. You fix the problem, then manually reset the breaker to restore power.

A software circuit breaker does the same thing for service calls. When Order Service calls Payment Service and Payment Service starts failing or taking ten seconds to respond, every thread in Order Service queues up waiting for a response. Eventually Order Service runs out of threads and it starts failing too — even for requests that have nothing to do with payments. This is a cascade failure, and it is how one slow downstream service can bring down an entire microservices system.

A circuit breaker wraps the call to Payment Service. It counts failures. When the failure rate exceeds a threshold — say, 50% of calls in the last 100 requests — it trips open: instead of actually calling Payment Service, it immediately returns a fallback response (a cached value, an error message, or a degraded-mode answer). This frees threads, stops the cascade, and gives Payment Service time to recover.

---

#### How It Works

**The three states — must memorise:**
```
CLOSED (normal operation):
  → Requests pass through to the downstream service
  → Failure rate is tracked in a sliding window
  → If failure rate < threshold (e.g. 50%): stay CLOSED
  → If failure rate >= threshold: trip to OPEN

OPEN (short-circuit):
  → Requests are NOT forwarded to the downstream service
  → Fallback is returned immediately (fast fail, no wait)
  → A timer runs for waitDurationInOpenState (e.g. 60 seconds)
  → When timer expires: transition to HALF-OPEN

HALF-OPEN (probing recovery):
  → A limited number of probe requests are allowed through
  → If probes succeed (success rate >= threshold): transition back to CLOSED
  → If probes fail: transition back to OPEN, reset the wait timer
```

**State machine:**
```
CLOSED → (failure rate exceeds threshold) → OPEN
OPEN   → (wait timer expires)             → HALF-OPEN
HALF-OPEN → (probe calls succeed)         → CLOSED
HALF-OPEN → (probe calls fail)            → OPEN
```

**Must-memorise gotcha — Resilience4j `@CircuitBreaker` annotation with fallback:**

```java
@Service
public class OrderService {

    private final InventoryClient inventoryClient;

    // @CircuitBreaker wraps the method call to inventoryClient
    // fallbackMethod is called when the circuit is OPEN or the call fails
    @CircuitBreaker(name = "inventory-service", fallbackMethod = "getInventoryFallback")
    public InventoryResponse checkInventory(String productId) {
        return inventoryClient.getInventory(productId);
    }

    // Fallback signature must match the main method signature + a Throwable parameter
    public InventoryResponse getInventoryFallback(String productId, Throwable ex) {
        // Return a safe degraded response — do NOT throw here
        return InventoryResponse.builder()
            .productId(productId)
            .available(false)
            .message("Inventory service unavailable, please try again")
            .build();
    }
}
```

application.yml configuration:
```java
// resilience4j.circuitbreaker.instances.inventory-service:
//   slidingWindowSize: 10            # evaluate last 10 calls
//   failureRateThreshold: 50         # trip open if 50%+ fail
//   waitDurationInOpenState: 30s     # stay open for 30s before probing
//   permittedNumberOfCallsInHalfOpenState: 3  # 3 probe calls
//   slowCallDurationThreshold: 2s    # calls > 2s count as failures
//   slowCallRateThreshold: 50        # trip if 50%+ are slow
//   registerHealthIndicator: true    # expose state in /actuator/health
```

**Tradeoff:** The circuit breaker catches failures that have already happened. To prevent slow calls from filling up the thread pool before the breaker trips, combine it with a `@TimeLimiter` (timeout) and a `@Bulkhead` (limit concurrent calls). The full resilience stack is: Bulkhead → CircuitBreaker → Retry → TimeLimiter, applied in that order.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Explain the circuit breaker pattern and its three states."**

**One-line answer:** A circuit breaker monitors failure rates on service calls and trips open — returning a fallback immediately — when failures exceed a threshold, preventing cascade failures.

**Full answer to give in an interview:**

> "The circuit breaker pattern prevents cascade failures in distributed systems. Without it, if Payment Service starts failing slowly — say, taking 10 seconds per request instead of 100ms — every caller that hits the payment code path blocks a thread waiting. Thread pools fill up, the caller service starts timing out on other requests too, and the failure cascades upstream. A circuit breaker short-circuits this by tracking failure rates and cutting the connection when they exceed a threshold.
>
> There are three states. CLOSED is normal operation — requests go through, failures are counted. When the failure rate exceeds the configured threshold (commonly 50%) in the sliding window (last N calls), the circuit trips to OPEN. In OPEN state, every call returns the fallback immediately without hitting the downstream service at all — this is the key protection, it frees threads and stops the cascade. After a configured wait period (e.g. 30 seconds), the circuit moves to HALF-OPEN and allows a small number of probe requests through. If those succeed, the circuit closes again. If they fail, it re-opens and resets the wait timer.
>
> In Java, Resilience4j is the standard implementation. You annotate the method with @CircuitBreaker, specify the service name that matches a configuration block in application.yml, and provide a fallback method that returns a safe degraded response."

> *Walk through all three states with concrete transitions — this is exactly what the interviewer wants to hear.*

**Gotcha follow-up they'll ask:** *"What is the difference between a circuit breaker and a retry?"*

> "A retry is for transient failures — a brief network glitch that resolves in milliseconds. You retry the call two or three times with a short back-off, and it succeeds. A circuit breaker is for sustained failures — a downstream service that is down or degraded for seconds to minutes. If you retry aggressively against a service that is already overloaded, you make the overload worse by increasing request volume. The circuit breaker detects that retries are failing consistently and stops all calls to protect the downstream service and free up the caller's threads. In Resilience4j you often combine both: @Retry for brief transient failures with a few retries, and @CircuitBreaker wrapping @Retry so that if retries keep failing, the circuit trips open."

---

##### Q2 — Design Scenario
**"How would you configure Resilience4j to handle a slow Payment Service without rejecting all calls?"**

**One-line answer:** Configure a slow call duration threshold so calls exceeding it count as failures, and add a Bulkhead to cap concurrent calls before the thread pool fills up.

**Full answer to give in an interview:**

> "A service can fail in two ways: it can return errors, or it can return responses very slowly. Resilience4j's circuit breaker handles both. The slowCallDurationThreshold setting defines what counts as 'slow' — for example, any call taking more than 2 seconds. The slowCallRateThreshold defines what percentage of slow calls triggers the circuit to open — for example, if 50% of the last 10 calls exceeded 2 seconds, trip open.
>
> But circuit breakers react after failures accumulate. While failures are accumulating, threads are still blocking. The Bulkhead pattern limits this: @Bulkhead sets a maxConcurrentCalls limit — say, 10 concurrent calls to Payment Service. The 11th concurrent caller gets an immediate rejection rather than blocking. This caps the resource usage even before the circuit breaker trips.
>
> The recommended combination is to stack: Bulkhead (limits concurrency) wraps CircuitBreaker (detects failures) wraps the actual call. The Retry should be between the CircuitBreaker and the call — so a call that fails and retries still counts as one circuit breaker 'attempt' from the circuit's perspective, preventing retry storms from inflating the failure count."

> *The order of stacking (Bulkhead → CircuitBreaker → Retry) is a specific detail that signals genuine Resilience4j experience.*

**Gotcha follow-up they'll ask:** *"How do you test that your circuit breaker actually works in production?"*

> "There are two approaches: chaos engineering and metrics monitoring. For chaos engineering — deliberately injecting failures using tools like Chaos Monkey or simply stopping the downstream service in a staging environment — you verify that the circuit actually opens, the fallback is returned, and the application continues to function. You measure that response latency stays low (fallbacks are fast) and error rates for the degraded feature are contained.
>
> For production monitoring, expose the circuit breaker state via Spring Actuator — Resilience4j integrates with Micrometer and exposes metrics like resilience4j.circuitbreaker.state (CLOSED/OPEN/HALF_OPEN), failure rate, and call counts. Set alerts on state transitions to OPEN so you know when a downstream service is degraded before users report it."

---

##### Q3 — Tradeoff Question
**"What should a fallback method return, and what are the risks of a bad fallback?"**

**One-line answer:** A fallback should return a safe, degraded but useful response — never throw an exception, never call the same failing service, and never silently return incorrect data.

**Full answer to give in an interview:**

> "The fallback is the response your service returns when the circuit is open or a call fails after retries. It must not make the situation worse. Three common mistakes: first, calling the same downstream service in the fallback — if Payment Service is down, a fallback that also calls Payment Service just generates more failures. Second, throwing an exception in the fallback — this propagates the error back up and removes the protection the circuit breaker was providing. Third, returning stale cached data that is so out of date it causes incorrect behaviour downstream.
>
> Good fallback patterns depend on the operation. For a read operation — checking inventory — return a cached result with a timestamp, or return 'unavailable: please try again.' For a write operation — placing an order that includes a payment — either reject the request with a clear user-facing error ('Payment service is temporarily unavailable'), or queue the request for later processing if eventual processing is acceptable. For non-critical features — product recommendations — return an empty list silently, so the main page still loads. The key principle is that fallbacks should degrade gracefully, not fail completely."

> *Distinguishing read vs write fallback strategies shows you have thought about real product behaviour.*

**Gotcha follow-up they'll ask:** *"How does Resilience4j's @CircuitBreaker interact with Spring's @Transactional?"*

> "They can conflict. If a @Transactional method calls a circuit-breaker-protected method and the circuit is open, Resilience4j throws a CallNotPermittedException. If that exception is not in your @Transactional rollback rules, Spring may not roll back the transaction, leaving partial state in the database. The fix: explicitly add CallNotPermittedException to the rollbackFor list on @Transactional, or restructure so the circuit breaker is at a higher layer than the transaction boundary — the circuit breaker method calls the transactional method, not vice versa. This ensures that a circuit open event rolls back any in-progress transaction cleanly."

---

> **Common Mistake — Missing Fallback for Writes:** Providing a fallback for read operations but not for writes means a write to a failing service throws an unhandled exception, bypasses the circuit breaker's protection, and propagates the failure upstream. Define a fallback for every circuit-breaker-annotated method, including writes — even if the fallback just logs and returns an error response.

---

**Quick Revision (one line):**
A circuit breaker has three states — CLOSED (normal), OPEN (fast-fail to fallback), HALF-OPEN (probe for recovery) — implemented in Java with Resilience4j's @CircuitBreaker annotation; always combine with @Bulkhead to cap concurrency and @TimeLimiter to catch slow calls before threads fill up.

---

## Topic 6: Saga Pattern

---

#### The Idea

Imagine you are booking a holiday package: the travel agent reserves a flight, books a hotel, and charges your card — three separate companies, three separate systems. If the card charge fails, the agent must call back the airline to cancel the flight reservation and call the hotel to cancel the room. There is no single "undo" button that spans all three companies. Each step must be manually reversed in order.

That is exactly the problem microservices face with multi-step operations. A single database transaction cannot span service boundaries — each service owns its own database. The Saga pattern solves this by breaking a long-running operation into a sequence of smaller local transactions, each owned by one service, with a defined compensating action that semantically undoes it if something later goes wrong.

The key insight is that compensating transactions are not database rollbacks — they are forward-moving business actions that acknowledge the undo. A "payment refunded" event is a compensation for a "payment charged" event. The audit trail is preserved; the state is corrected.

---

#### How It Works

There are two ways to coordinate a saga:

**Choreography** — services talk to each other by publishing and listening to events. No central brain.

```
OrderService       publishes --> order-created
InventoryService   listens  --> reserves stock, publishes --> inventory-reserved
PaymentService     listens  --> charges card,   publishes --> payment-charged
LoyaltyService     listens  --> adds points,    publishes --> order-completed

On failure (e.g. payment fails):
PaymentService     publishes --> payment-failed
InventoryService   listens  --> releases stock, publishes --> inventory-released
```

Pros: loose coupling, no single point of failure.
Cons: hard to answer "what step is the saga on?" — the state is scattered across services.

**Orchestration** — a central saga orchestrator explicitly tells each service what to do and tracks the saga's state in its own database.

```
Orchestrator calls InventoryService.reserve()
  --> success: persist state = INVENTORY_RESERVED
Orchestrator calls PaymentService.charge()
  --> failure: begin compensation
Orchestrator calls InventoryService.release()  // compensating transaction
  --> persist state = COMPENSATED
```

Pros: full visibility, explicit state machine, easy to monitor.
Cons: orchestrator becomes a coupling point — keep it thin, no business logic.

**Tradeoff summary:**

| Aspect | Choreography | Orchestration |
|---|---|---|
| Coordination | Events | Central orchestrator |
| Coupling | Loose | Tighter |
| Visibility | Hard to track | Easy to monitor |
| Failure handling | Distributed compensations | Centralized |
| Best for | Simple linear flows | Complex multi-step transactions |

**Must-memorise gotcha — compensating transaction pattern:**

```java
// Orchestrator compensation after payment failure
private void compensateAfterPaymentFailure(OrderSaga saga, Order order) {
    saga.setState(COMPENSATING);
    sagaRepository.save(saga); // persist before attempting compensation

    try {
        // Only undo what succeeded — inventory was reserved, payment never charged
        inventoryClient.release(order.getProductId(), order.getQuantity());
        saga.setState(COMPENSATED);
    } catch (Exception e) {
        // Compensation itself failed — this is now a manual intervention scenario
        alertOperationsTeam(order.getId(), e);
        // Do NOT retry blindly — log, alert, and let humans resolve
    }
    sagaRepository.save(saga);
}
```

Always persist saga state before each step and before each compensation. If the orchestrator crashes mid-saga, it must be able to resume from the last known state rather than restart from scratch.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the Saga pattern and why do microservices need it?"**

**One-line answer:** Sagas replace distributed ACID transactions with a sequence of local transactions plus compensating actions that undo completed steps on failure.

**Full answer to give in an interview:**

> "In a monolith, you can wrap multiple database writes in a single transaction — if anything fails, the whole thing rolls back atomically. In microservices, each service owns its own database, so there is no single transaction boundary that spans service A, B, and C. Two-phase commit exists but it creates tight coupling and is too slow for production use.
>
> The Saga pattern solves this by splitting the operation into local transactions, one per service. Each service commits its own change and publishes an event. If a later step fails, you trigger compensating transactions — business-level undos executed in reverse order. For example, if an order saga gets through inventory reservation and payment but then shipping fails, the compensation is: cancel shipping, refund payment, release inventory.
>
> The critical nuance is that compensating transactions are not database rollbacks. They are forward-moving business actions — a refund is a new event in the system, not a deletion. This means intermediate states are visible to other requests during the saga — Sagas provide ACD (Atomicity via compensation, eventual Consistency, Durability) but not Isolation."

> *Lead with the distributed transaction problem. The interviewer wants to hear that you understand why 2PC is not an option in microservices before you propose the solution.*

**Gotcha follow-up they'll ask:** *"What happens if a compensating transaction itself fails?"*

> "This is the hardest part of saga design. If a compensation fails, you cannot just retry indefinitely — you risk infinite loops or duplicate compensations on idempotent operations. The correct approach is: persist the failed compensation state, emit an alert to an operations team, and rely on a dead-letter queue or manual intervention to resolve it. Some systems use the outbox pattern to guarantee at-least-once delivery of compensation commands. The key insight is that you accept that perfect automated recovery is not always possible — you design for observability so humans can resolve edge cases."

---

##### Q2 — Tradeoff Question
**"When would you choose choreography over orchestration for a saga?"**

**One-line answer:** Choreography for simple linear flows with few services; orchestration for complex workflows where you need explicit state tracking and centralized error handling.

**Full answer to give in an interview:**

> "Choreography works well when the saga is a simple chain: service A publishes an event, service B reacts, service B publishes, service C reacts. Each service only needs to know about one upstream event and one downstream event — coupling stays minimal. There is no single point of failure because there is no central coordinator.
>
> Orchestration becomes preferable when the workflow has branching logic, parallel steps, or requires someone to answer the question 'what state is this saga in right now?' The orchestrator persists its state machine explicitly, so debugging is straightforward: query the orchestrator's database and you see exactly which step succeeded or failed. Tools like Temporal or Cadence are production-grade orchestration engines that handle retries, timeouts, and state persistence for you.
>
> The anti-pattern to avoid is the fat orchestrator — pushing business rules into the orchestrator rather than keeping them in each service. The orchestrator should be a state machine that coordinates, not a service that decides."

> *Name Temporal or Cadence — it shows production awareness. Interviewers at Uber, Netflix, and similar companies will appreciate this.*

**Gotcha follow-up they'll ask:** *"Does a choreography-based saga have any mechanism to track overall progress?"*

> "Not natively — that is its main weakness. The common solution is to introduce a saga log: a separate read model that listens to all relevant events across the saga and reconstructs the current state. This is essentially building a projection (CQRS-style) of the saga's progress. Some teams also use correlation IDs — a shared saga ID stamped on every event — so they can query an event store and replay the full sequence for any given saga instance."

---

##### Q3 — Design Scenario
**"Design an order fulfillment saga for an e-commerce platform with inventory, payment, and loyalty services."**

**One-line answer:** Model it as an orchestration saga with four steps and three compensating transactions, with idempotency keys on payment to prevent duplicate charges.

**Full answer to give in an interview:**

> "I would use orchestration because payment is involved — I need explicit visibility into whether the payment was charged before deciding whether to refund it during compensation. Here are the forward steps: 1) ReserveInventory, 2) ChargePayment, 3) UpdateLoyaltyPoints, 4) ScheduleShipping. The compensating steps in reverse: CancelShipping, ReversePoints, RefundPayment, ReleaseInventory.
>
> The tricky step is ChargePayment. Payment is not idempotent by default, so I need an idempotency key — typically the order ID — passed to the payment provider. If the orchestrator crashes after the payment succeeded but before it recorded the state, it must be able to call ChargePayment again with the same idempotency key and get back the original result rather than a double charge.
>
> I would persist saga state in a database after every successful step, and use the outbox pattern to guarantee that the event triggering the next step is published atomically with the state update. The orchestrator runs as a Spring component with a scheduled job that picks up stuck sagas and retries them."

> *The idempotency key on payment is the detail that distinguishes a strong answer from a surface-level one.*

**Gotcha follow-up they'll ask:** *"How do you handle the 'isolation' gap — what if another process reads partially-completed saga data?"*

> "Sagas do not provide isolation — intermediate states are visible. The standard countermeasure is a semantic lock: mark the entity as 'pending' at the start of the saga and reject or queue any concurrent operations on that entity until the saga completes or compensates. For example, set order status to PROCESSING when the saga starts — any attempt to modify that order returns a 409 Conflict until the saga finishes."

---

> **Common Mistake — treating compensations as rollbacks:** Compensating transactions create new events in the system — they do not delete prior events. Designing them as deletes breaks audit trails and causes confusion when event-sourced systems replay history.

---

**Quick Revision (one line):**
Saga breaks distributed operations into local transactions with compensating undos; choreography coordinates via events, orchestration via a central state machine — always persist saga state and use idempotency keys on non-idempotent steps.

---

## Topic 7: Event-Driven Architecture

---

#### The Idea

Think of a newspaper. When an important event happens, the newspaper publishes a story. Millions of subscribers read it — or not. The newspaper does not wait for each reader to confirm they received it before printing the next edition. Readers who missed Tuesday's paper can still read it on Wednesday. The newspaper does not know or care who its readers are.

Event-Driven Architecture (EDA) works the same way. When something significant happens in your system — an order is placed, a payment is processed, a user signs up — a service publishes an immutable event to a message broker (Kafka, RabbitMQ). Any number of other services can subscribe and react in their own time, at their own pace, without the publisher knowing they exist.

Event Sourcing and CQRS are two patterns that take this idea further. Event Sourcing stores every state change as an immutable event rather than overwriting the current state — your entire database history becomes a replayable log. CQRS (Command Query Responsibility Segregation) separates the write side (commands that change state) from the read side (queries that return data), letting each be optimized independently. Together they enable audit logs, temporal queries ("what was this order's state at 3pm?"), and scalable read replicas built from event streams.

---

#### How It Works

**Event Sourcing data model:**

```
Append-only event store:
  OrderPlacedEvent   { orderId, customerId, items, amount, timestamp }
  PaymentChargedEvent{ orderId, paymentId, amount, timestamp }
  OrderShippedEvent  { orderId, trackingNumber, timestamp }

Current state = replay all events for orderId in order
Snapshot = periodically materialized state (e.g. every 50 events) to speed up replay
```

**CQRS split:**

```
Write side (Command side):
  PlaceOrderCommand --> OrderAggregate validates business rules
                    --> applies OrderPlacedEvent
                    --> event persisted to event store

Read side (Query side):
  OrderProjection listens to events
              --> updates denormalized OrderSummary table (read-optimized)
  GetOrderQuery --> reads from OrderSummary (fast, no joins)
```

Tradeoff: eventual consistency between write and read sides — the projection updates asynchronously. Brief window where a query returns stale data. Acceptable for most use cases; problematic for read-your-own-writes patterns (use version-aware queries or short delays as a workaround).

**Must-memorise gotcha — event schema evolution:**

```java
// Events are API contracts. Once published, consumers depend on their shape.
// Safe changes: add optional fields with defaults
// Breaking changes: remove fields, rename fields, change types

// Version field pattern:
public record OrderPlacedEvent(
    int version,          // always include — enables consumers to handle migrations
    String orderId,
    String customerId,
    List<OrderItem> items,
    BigDecimal totalAmount,
    Instant occurredAt
) {
    // Default version for new events
    public OrderPlacedEvent(String orderId, String customerId,
                            List<OrderItem> items, BigDecimal totalAmount) {
        this(2, orderId, customerId, items, totalAmount, Instant.now());
    }
}

// Consumer: handle both v1 and v2
public void on(OrderPlacedEvent event) {
    if (event.version() == 1) {
        // v1 had no 'items' field — handle legacy shape
    } else {
        // normal v2 processing
    }
}
```

Never delete an event type from your event store. Old consumers may need to replay from the beginning of time.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is Event Sourcing and how does it differ from a traditional state-based database?"**

**One-line answer:** Event Sourcing stores every state change as an immutable event; current state is derived by replaying those events rather than reading a single overwritten row.

**Full answer to give in an interview:**

> "In a traditional database, when an order status changes from PENDING to SHIPPED, you run an UPDATE — the previous PENDING state is gone. In Event Sourcing, you never update. Instead, you append an OrderShippedEvent to an event log. The current state of the order is the result of replaying all events for that order in sequence.
>
> This gives you several powerful properties. You have a complete audit trail by design — every state the entity ever had is preserved. You can ask temporal questions: what was this order's status at 2pm yesterday? You can replay events through a new projection to build a new read model retroactively. And you can reconstruct the exact sequence of operations that led to a bug.
>
> The cost is complexity. You need to manage snapshots — materializing the current state every N events so you don't replay 10,000 events every time you load an aggregate. You need to handle event schema evolution carefully because old events are immutable and consumers need to handle both old and new shapes. And projections are eventually consistent — the read model lags behind the event log by a small window."

> *The snapshot point is often missed in interviews. Mentioning it shows you have thought about production performance, not just the theoretical model.*

**Gotcha follow-up they'll ask:** *"What is a snapshot in event sourcing and when should you use one?"*

> "A snapshot is a periodically materialized copy of an aggregate's current state saved alongside its events. Instead of replaying all 10,000 events to load an order, you load the most recent snapshot (say, after event 9,800) and replay only the 200 events since then. The rule of thumb is to snapshot when the event count per aggregate crosses a threshold that makes replay noticeably slow — typically 50 to 100 events depending on event size and replay cost. Axon Framework handles snapshots automatically with a configurable threshold."

---

##### Q2 — Tradeoff Question
**"What are the tradeoffs of CQRS and when is it NOT worth the complexity?"**

**One-line answer:** CQRS is only justified when read and write loads are significantly asymmetric or when read models require denormalization that conflicts with the write model's consistency requirements.

**Full answer to give in an interview:**

> "CQRS separates write operations — commands that change state — from read operations — queries that return data. The write side validates business rules and emits events. The read side maintains denormalized projections optimized for specific query patterns. You can back the write side with PostgreSQL and the read side with Elasticsearch, each tuned for its purpose.
>
> The benefit is clear when you have a service like an order history page that needs to join data from five tables, apply filters, and sort — maintaining a pre-built projection for exactly that query is much faster than computing it at read time. LinkedIn's activity feed is a canonical example: billions of reads against a pre-materialized feed built from an event stream.
>
> But CQRS is severe overkill for a simple CRUD service. If your read model can be served by the same database as your write model with a few indexes, CQRS adds two systems, an event bus, eventual consistency, and projection maintenance code for zero benefit. My rule is: reach for CQRS only when you have a domain with complex business rules on the write side AND a significantly different query shape on the read side, or an audit requirement that demands an event log."

> *Name the LinkedIn example — it anchors the abstract pattern in a real production system.*

**Gotcha follow-up they'll ask:** *"How do you handle 'read your own writes' when the read model is eventually consistent?"*

> "Three common approaches. First, after a write, return the version number of the write to the client. The client passes this version on the next read; the query handler waits until the projection has processed at least that version before returning — a version-aware query. Second, after a write, the API waits for a configurable timeout for the projection to catch up before returning the response. Third, for the specific case of the user who just wrote, route their next read directly to the write-side database, bypassing the projection — this is the simplest but requires the client to signal which reads are 'just-wrote' reads."

---

##### Q3 — Design Scenario
**"When would you choose Event Sourcing with CQRS over a standard relational model in a new microservice?"**

**One-line answer:** Choose Event Sourcing when you need a full audit trail, temporal queries, or the ability to build new projections from historical data — avoid it for simple CRUD domains.

**Full answer to give in an interview:**

> "I would reach for Event Sourcing in three scenarios. First, a domain with regulatory audit requirements — banking transactions, healthcare records, financial ledgers — where you must be able to reconstruct exactly what happened and when, and prove it. Second, a complex domain with a rich event history that drives business value — an e-commerce order has lifecycle events (placed, paid, shipped, returned, refunded) that are themselves meaningful business data, not just noise. Third, when I know I will need to build new reporting views from historical data without having to migrate a relational schema.
>
> I would avoid it for a user profile service where state is simple, writes are occasional, and nobody needs to query what a user's bio looked like in 2022. The overhead of event stores, projections, snapshots, and schema versioning is significant. A good heuristic: if the audit trail is a feature, use Event Sourcing. If it is an afterthought, use a standard database with a changelog table."

> *Framing your answer as 'when to use vs when to avoid' shows judgment, not just pattern knowledge.*

**Gotcha follow-up they'll ask:** *"Event Sourcing and Event-Driven Architecture — are they the same thing?"*

> "No, and this is a common conflation. Event-Driven Architecture means services communicate by publishing and consuming events on a message broker — it says nothing about how each service stores its own state internally. Event Sourcing is a persistence strategy: the service stores its state as an event log rather than current-state rows. You can have EDA without Event Sourcing — most services do. You can also have Event Sourcing without EDA if the event log is local and never published externally, though that is unusual. They complement each other well but are independent choices."

---

> **Common Mistake — event sourcing every service:** Event Sourcing is a significant complexity investment. Applying it to simple CRUD services for the sake of consistency introduces event stores, projections, and schema versioning overhead where a three-column table would suffice.

---

**Quick Revision (one line):**
Event Sourcing stores state as an immutable event log enabling full audit trails and projection replay; CQRS separates write and read models for independent optimization — use together only when audit requirements or read/write asymmetry justify the complexity.

---

## Topic 8: Distributed Tracing

---

#### The Idea

Imagine a package moving through a courier network. It is scanned at the origin depot, loaded onto a truck, transferred at a hub, loaded onto another truck, delivered to a local depot, and finally handed to a delivery driver. At every step, the same tracking number is stamped on the package. When you enter that tracking number on the website, you see the full journey — every leg, every timestamp, every delay.

Distributed tracing works exactly like this for requests moving through microservices. When a single user action triggers calls across a dozen services, you need one tracking number — a trace ID — stamped on every log entry, every service call, and every database query in that chain. Without it, debugging a slow or failed request across services means correlating timestamps and service names from separate log files — a near-impossible task at scale.

A trace is the complete journey of one request. Each unit of work along the journey is a span — "order-service processing the HTTP request", "inventory-service executing the SQL query". Spans are nested: the order-service span is the parent; the database query span is a child. The collection of all spans with the same trace ID is the full call graph, which tracing backends like Jaeger or Zipkin render as a flame chart.

---

#### How It Works

**Trace, span, and context propagation model:**

```
Incoming request to order-service:
  traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
                   ^^traceId (16 bytes hex)               ^^parentSpanId   ^^flags

order-service creates a child span:
  traceId   = 4bf92f3577b34da6a3ce929d0e0e4736  (same as parent — never changes)
  spanId    = abc123def456789a                   (new — unique to this unit of work)
  parentId  = 00f067aa0ba902b7                   (links to caller's span)

When order-service calls inventory-service via HTTP:
  Inject traceparent header with same traceId + new spanId as parentSpanId
  inventory-service extracts, creates its own child span
  --> full call graph reconstructed from parent/child span relationships
```

**OpenTelemetry architecture:**

```
Service code
  --> OTel instrumentation library (auto-instruments HTTP, JDBC, Kafka, Redis)
  --> OTel SDK (batches spans)
  --> OTel Collector (receives, processes, exports)
  --> Backend: Jaeger / Zipkin / Datadog / Grafana Tempo

MDC (Mapped Diagnostic Context) integration:
  traceId + spanId automatically injected into log context
  Log format: [order-service, 4bf92f3577b34da6a, abc123def456] INFO - Order placed
  --> Query logs by traceId to see all log lines for one request across all services
```

**Must-memorise gotcha — W3C traceparent header propagation:**

```java
// W3C traceparent format:
// traceparent: {version}-{traceId}-{parentSpanId}-{traceFlags}
// Example:
// traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
//              ^^ version=00 (fixed)
//                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ traceId: 32 hex chars (128-bit)
//                                                  ^^^^^^^^^^^^^^^^ parentSpanId: 16 hex chars (64-bit)
//                                                                   ^^ flags: 01 = sampled, 00 = not sampled

// Spring Boot 3.x + Micrometer Tracing auto-injects this header.
// For Kafka, trace context goes into Kafka record headers (not HTTP headers):

@Component
public class OrderEventProducer {

    private final KafkaTemplate<String, OrderEvent> kafkaTemplate;

    public void publishOrderPlaced(Order order) {
        ProducerRecord<String, OrderEvent> record =
            new ProducerRecord<>("order-events", order.getId(), new OrderEvent(order));
        // OTel Kafka instrumentation automatically injects traceparent into record headers
        // Consumer side: instrumentation extracts it and creates a child span
        kafkaTemplate.send(record);
    }
}

// CRITICAL: without explicit Kafka trace propagation, async hops break the trace chain.
// The trace in order-service ends; inventory-service starts an unlinked new trace.
// You lose the causal relationship between the HTTP request and all downstream processing.
```

Sampling tradeoff: 100% sampling captures every request but overwhelms trace storage at high throughput. Head-based sampling decides at the start of a trace (simple, low overhead, misses rare errors). Tail-based sampling decides after the full trace is seen (captures all errors and slow traces, but requires buffering). Production recommendation: 1–10% head-based sampling with tail-based override for errors.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is a trace, a span, and context propagation in distributed tracing?"**

**One-line answer:** A trace is the full journey of one request across all services; a span is one unit of work within that journey; context propagation is how the trace ID travels between services via headers.

**Full answer to give in an interview:**

> "When a user places an order, the request might touch an order service, then an inventory service, then a payment service, then a notification service. Distributed tracing assigns a single trace ID to that entire journey at the point of entry. Every service that handles this request — whether via HTTP, Kafka, or gRPC — stamps that trace ID on its work.
>
> A span represents one unit of work: 'order-service handled the POST /orders request' is a span. 'Inventory-service executed SELECT ... WHERE product_id = ?' is a child span of the service-to-service call span. Spans have a start time, end time, status, and optional tags like HTTP status code or customer ID.
>
> Context propagation is the mechanism that carries the trace ID between services. For HTTP, the W3C standard uses a header called traceparent that encodes the trace ID, the caller's span ID (so the receiving service knows who its parent is), and sampling flags. For Kafka, the same information goes into Kafka record headers. OpenTelemetry's instrumentation libraries handle injection and extraction automatically — you do not write this code yourself."

> *Walk through the W3C header format briefly — it signals you have actually implemented this, not just read about it.*

**Gotcha follow-up they'll ask:** *"How do you correlate distributed traces with application logs?"*

> "The key is MDC — Mapped Diagnostic Context — a thread-local map that logging frameworks like Logback read when formatting log lines. Micrometer Tracing automatically populates MDC with the current traceId and spanId whenever a span is active. Your log pattern includes %X{traceId} and %X{spanId}. The result is that every log line for a given request includes the same trace ID. When debugging a production issue, you copy the trace ID from Jaeger, search your log aggregation system (Kibana, Loki) for that trace ID, and instantly see all log lines from all services for that one request — without manually correlating timestamps."

---

##### Q2 — Tradeoff Question
**"What is the difference between head-based and tail-based sampling and when would you use each?"**

**One-line answer:** Head-based sampling decides at trace start whether to record it — simple and cheap; tail-based sampling decides after the full trace is collected — captures all errors but requires buffering.

**Full answer to give in an interview:**

> "Head-based sampling is the most common approach. At the very first service that receives the request, you flip a coin — or apply a configured probability, say 10% — and stamp the traceFlags in the traceparent header as 'sampled' or 'not sampled'. Every downstream service respects that flag. This is extremely low overhead because the decision is made once and no trace data needs to be buffered.
>
> The problem is that head-based sampling is blind. If a rare 500 error affects 0.1% of requests and you are sampling 1%, you have a 99% chance of missing any given error trace entirely.
>
> Tail-based sampling solves this. Every service sends spans to a collector that buffers them. When the full trace is assembled — all spans received — the collector evaluates rules: was there an error? Was total latency above 2 seconds? If yes, keep the trace regardless of the original sampling probability. This guarantees you capture exactly the traces you care about most.
>
> The cost is operational complexity: the collector must hold all pending trace data in memory until the trace completes, which requires significant memory at high throughput. OpenTelemetry Collector supports tail-based sampling via the tail-sampling processor. In practice, many teams use head-based sampling at 1–5% for baseline coverage and rely on error alerting and log correlation for the rest."

> *The production recommendation — head-based for baseline, tail-based for errors — is what interviewers at observability-focused companies want to hear.*

**Gotcha follow-up they'll ask:** *"Is X-Correlation-Id the same as distributed tracing?"*

> "No — correlation IDs are simpler and older. An X-Correlation-Id header is a manually assigned request ID propagated by convention through your services. It tells you that log line A in service X and log line B in service Y belong to the same request. But it carries no span hierarchy, no timing data, no parent-child relationships, and no standard format. Distributed tracing gives you all of that: a flame chart showing which service took how long, which call was the bottleneck, which span failed and why. Correlation IDs are a step up from nothing, but they are not a replacement for proper distributed tracing."

---

##### Q3 — Design Scenario
**"How would you add distributed tracing to an existing Spring Boot microservices system that currently has none?"**

**One-line answer:** Add Micrometer Tracing with the OTel bridge, deploy an OTel Collector, configure MDC log correlation, and verify Kafka headers propagate trace context through async hops.

**Full answer to give in an interview:**

> "I would start with the dependencies. Spring Boot 3.x ships with Micrometer Tracing. Adding micrometer-tracing-bridge-otel and the appropriate exporter — opentelemetry-exporter-otlp for an OTel Collector, or a vendor-specific exporter for Datadog or Tempo — is enough to enable automatic instrumentation of HTTP requests, RestClient, WebClient, and JDBC.
>
> The OTel Collector sits as a sidecar or daemonset in Kubernetes, receives spans from all services over OTLP, batches them, and exports to Jaeger or whatever backend you use. I would configure sampling at 10% in production and 100% in staging.
>
> The most important non-obvious step is Kafka. If services communicate via Kafka, the OTel Kafka instrumentation must be on the classpath for both producer and consumer. Without it, trace context is not injected into Kafka headers, and every async consumer starts a fresh unlinked trace — you lose the causal chain from the original HTTP request to all downstream processing.
>
> Finally, update logback-spring.xml to include %X{traceId} and %X{spanId} in the log pattern. Once deployed, a single trace ID from Jaeger becomes a Kibana search term that pulls all log lines for that request across every service."

> *The Kafka context propagation point is what separates candidates who have done this in production from candidates who only know the theory.*

**Gotcha follow-up they'll ask:** *"How do you handle trace propagation through CompletableFuture or @Async methods?"*

> "By default, MDC context is bound to a thread. When you hand work off to a thread pool via CompletableFuture.supplyAsync() or Spring's @Async, the new thread has no MDC context — the traceId is lost. Micrometer Tracing provides a ContextExecutorService wrapper that copies the current observation context to the new thread. Spring Boot 3.x's @Async automatically propagates context if you configure the executor bean via Observation. For raw CompletableFuture, wrap your executor with ContextExecutorService.wrap(executor, observationRegistry) to ensure trace context travels across thread boundaries."

---

> **Common Mistake — not propagating context through message queues:** Teams add tracing to HTTP services and assume they are done. Every Kafka or RabbitMQ hop without explicit header injection starts a new disconnected trace. The async path — often the most complex and failure-prone — becomes invisible in your tracing backend.

---

**Quick Revision (one line):**
Distributed tracing assigns a single trace ID to a request's full journey across services, propagated via W3C traceparent HTTP/Kafka headers; OpenTelemetry with Micrometer Tracing auto-instruments Spring Boot and MDC integration correlates traces with logs.

---

## Topic 9: Resilience Patterns

---

#### The Idea

Imagine a city's electrical grid. If one neighbourhood draws too much power, the grid does not let that overload cascade and black out the entire city. Circuit breakers trip, isolating the fault. Backup generators kick in for critical buildings. The grid is designed to degrade gracefully — most of the city keeps running even when part of it fails.

Microservices face the same challenge. When service A calls service B and B is slow or down, A's threads pile up waiting for responses. A's thread pool fills up. A starts failing too. Requests to A fail. The service upstream of A starts failing. A single slow dependency cascades into a full system outage — this is called a cascading failure.

Resilience patterns are the circuit breakers and bulkheads of software. The circuit breaker stops calls to a failing service before they pile up, giving it time to recover. The bulkhead limits how many threads or connections any one dependency can consume, so a slow dependency cannot steal resources from healthy ones. Retry with exponential backoff and jitter handles transient failures — brief hiccups that resolve themselves — without hammering an already struggling service. Together these patterns make a service self-healing.

---

#### How It Works

**Circuit Breaker — three states:**

```
CLOSED (normal):
  Calls pass through to downstream
  Failures counted in a sliding window
  IF failure rate > threshold --> transition to OPEN

OPEN (fault detected):
  All calls immediately rejected with fallback (no network call made)
  After waitDurationInOpenState --> transition to HALF_OPEN

HALF_OPEN (probing recovery):
  Allow a limited number of test calls through
  IF all succeed --> transition to CLOSED
  IF any fail   --> transition back to OPEN
```

**Resilience4j pattern summary:**

| Pattern | Problem Solved | Key Config |
|---|---|---|
| Circuit Breaker | Cascading failures | failureRateThreshold, waitDurationInOpenState |
| Retry | Transient failures | maxAttempts, waitDuration, exponential backoff |
| Rate Limiter | Overload of downstream | limitForPeriod, limitRefreshPeriod |
| Bulkhead | Resource exhaustion | maxConcurrentCalls (semaphore) or thread pool |
| TimeLimiter | Slow dependencies | timeoutDuration |

**Composition order matters:**

```
Correct order: Retry > CircuitBreaker > RateLimiter > Bulkhead > function

Why: Retry is outermost so it can observe a closed circuit and retry on the next attempt.
     TimeLimiter is inside CircuitBreaker so timeouts count as failures toward opening the circuit.
     Bulkhead is innermost so it governs actual concurrent executions.
```

**Must-memorise gotcha — exponential backoff with jitter:**

```java
// Thundering herd problem: 1000 clients all fail at T=0.
// Without jitter: all retry at T+1s, T+2s, T+4s in perfect lockstep.
// The downstream gets hit by 1000 simultaneous requests at every retry wave.

// With full jitter: each client picks a random value between 0 and max_backoff.
// The 1000 retries are spread across the window instead of synchronized.

// Resilience4j config (application.yml):
// resilience4j:
//   retry:
//     instances:
//       payment-service:
//         maxAttempts: 3
//         waitDuration: 500ms
//         enableExponentialBackoff: true
//         exponentialBackoffMultiplier: 2.0    # 500ms, 1000ms, 2000ms
//         randomizedWaitFactor: 0.5            # jitter: ±50% of calculated wait
//         retryExceptions:
//           - java.io.IOException
//           - java.net.ConnectException
//         ignoreExceptions:
//           - com.example.PaymentDeclinedException  // 400-class: NEVER retry

@CircuitBreaker(name = "payment-service", fallbackMethod = "paymentFallback")
@Retry(name = "payment-service")
@Bulkhead(name = "payment-service", type = Bulkhead.Type.SEMAPHORE)
@RateLimiter(name = "payment-service")
@TimeLimiter(name = "payment-service")
public CompletableFuture<PaymentResult> processPayment(PaymentRequest request) {
    return CompletableFuture.supplyAsync(() -> paymentGatewayClient.charge(request));
}

// CRITICAL: never retry non-idempotent operations without an idempotency key.
// Retrying POST /payments without one can result in duplicate charges.
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does a circuit breaker prevent cascading failures and what are its three states?"**

**One-line answer:** A circuit breaker monitors failure rates and trips to OPEN state when a threshold is exceeded, short-circuiting all calls to a failing dependency until it recovers.

**Full answer to give in an interview:**

> "A circuit breaker wraps calls to a downstream service and tracks outcomes in a sliding window — say, the last 100 calls. If more than 50% fail (the failure rate threshold), the circuit breaker trips to OPEN state. In OPEN state, it stops making actual network calls entirely — every call immediately throws a fallback exception or returns a cached response. This prevents threads from piling up waiting for a service that is clearly broken.
>
> After a configured wait period — say 30 seconds — the circuit transitions to HALF_OPEN. It allows a small number of probe calls through. If they succeed, the circuit closes and normal operation resumes. If they fail, it opens again and waits another 30 seconds before probing again.
>
> The key insight is that cascading failures happen because threads accumulate waiting for slow or failed downstream services. The circuit breaker eliminates that wait — it fails fast. This keeps your thread pool healthy and your service responsive to other requests even while one of your dependencies is down.
>
> In Resilience4j, the circuit breaker can count failures either by count-based or time-based sliding window, and it distinguishes between exceptions (network errors) and slow calls that exceed a configured duration threshold."

> *Mention both count-based and time-based sliding windows — it shows you have read beyond the basics.*

**Gotcha follow-up they'll ask:** *"What is the difference between a circuit breaker and a timeout? Why do you need both?"*

> "A timeout says: if this call takes longer than N seconds, stop waiting and fail. A circuit breaker says: after enough failures or timeouts, stop making calls at all. You need both because they solve different problems. A timeout prevents one slow call from blocking your thread indefinitely. A circuit breaker prevents you from making thousands of calls that you already know will time out — it amortizes the protection across a stream of requests. Without a circuit breaker, every request still waits for the timeout to expire before failing. With a circuit breaker, once the failure threshold is crossed, every subsequent request fails instantly — no waiting."

---

##### Q2 — Tradeoff Question
**"What is the difference between a semaphore bulkhead and a thread-pool bulkhead? When would you use each?"**

**One-line answer:** Semaphore bulkhead limits concurrent calls using a counter in the same thread; thread-pool bulkhead executes calls in a separate pool, fully isolating thread resources but at higher overhead.

**Full answer to give in an interview:**

> "A semaphore bulkhead works by counting concurrent calls. When a call enters, a counter increments. When it completes, the counter decrements. If the counter would exceed maxConcurrentCalls, the call is immediately rejected — no queueing. The call executes in the caller's thread. This is lightweight with no thread-switching overhead, but if the downstream service is slow, the caller's thread blocks waiting.
>
> A thread-pool bulkhead maintains a separate, fixed-size thread pool for calls to a specific dependency. The caller submits the task and gets back a CompletableFuture immediately — their thread is free. The work happens in the pool. If the pool's queue fills up, the task is rejected. This fully isolates failure: even if the payment service is blocking all 10 threads in its dedicated pool, the inventory service's 20-thread pool is unaffected.
>
> Thread-pool bulkheads are what Netflix Hystrix was famous for — separate pools for each downstream service prevented one slow dependency from exhausting the shared server thread pool. The cost is the context-switching overhead of an extra thread pool and the memory for each thread.
>
> Semaphore bulkheads are the Resilience4j default and are appropriate for most cases — especially reactive or virtual-thread environments where blocking is cheap. Use thread-pool bulkheads when you are on a traditional thread-per-request model and one dependency is reliably slow."

> *Mention Netflix Hystrix — it shows historical awareness and gives interviewers a shared reference point.*

**Gotcha follow-up they'll ask:** *"In what order should you compose Retry and CircuitBreaker decorators and why?"*

> "Retry should wrap CircuitBreaker, not the other way around. If CircuitBreaker wraps Retry, every retry attempt is counted as a separate call toward the circuit breaker's failure threshold — a single request with 3 retries would count as 3 failures, causing the circuit to open prematurely. With Retry outside, the retry loop runs only when the circuit is closed — if the circuit opens mid-retry, the retry observes the open circuit and fails fast rather than continuing to attempt calls."

---

##### Q3 — Design Scenario
**"Design a resilient payment service call with retry, circuit breaker, and bulkhead. What are the failure modes you are protecting against?"**

**One-line answer:** Combine Retry for transient failures, CircuitBreaker for sustained outages, Bulkhead for thread exhaustion, and TimeLimiter for slow calls — composed in that order with explicit fallback logic per failure type.

**Full answer to give in an interview:**

> "I would protect against four distinct failure modes. First, transient network errors — brief connection timeouts or dropped packets — handled by Retry with exponential backoff and jitter, limited to 3 attempts, only on IOException and ConnectException, never on PaymentDeclinedException or other business errors.
>
> Second, sustained payment gateway outages — handled by CircuitBreaker. Once the failure rate crosses 50% over the last 100 calls, the circuit opens. During OPEN state, I return a fallback: enqueue the payment for asynchronous retry rather than failing the user immediately.
>
> Third, thread exhaustion from concurrent slow calls — handled by a semaphore Bulkhead with maxConcurrentCalls of 10. If more than 10 requests are simultaneously waiting on the payment gateway, subsequent requests get a 503 immediately rather than queuing and eventually timing out.
>
> Fourth, slow calls that block threads — handled by TimeLimiter with a 3-second timeout. Payment calls taking longer than 3 seconds are cancelled.
>
> The critical idempotency point: payment is not idempotent by default. I must pass an idempotency key — typically the order ID — with every payment request. If Retry fires and the first attempt actually succeeded but the response was lost in transit, the second attempt with the same idempotency key returns the original result instead of charging the customer twice."

> *The idempotency key point is the detail that separates good answers from great ones in payment system design.*

**Gotcha follow-up they'll ask:** *"What is the thundering herd problem and how does jitter solve it?"*

> "When many clients fail simultaneously — say, a downstream service restarts and 1,000 requests fail at the same moment — all of them retry after the same backoff period. They hit the recovering service with a synchronized burst, potentially overwhelming it and causing it to fail again. The pattern repeats. Jitter randomizes the backoff duration for each client: instead of all waiting exactly 1 second, each client waits between 0 and 1 second, spreading the retry wave across time. AWS SDK uses full jitter for all DynamoDB retries for exactly this reason."

---

> **Common Mistake — retrying non-idempotent operations:** Retrying a payment charge without an idempotency key can double-charge the customer. Only retry operations that are safe to repeat, or use idempotency keys to make non-idempotent operations safe to retry.

---

**Quick Revision (one line):**
Circuit breaker stops calls to failing services (CLOSED → OPEN → HALF_OPEN); retry with jitter handles transient failures without thundering herd; bulkhead isolates thread resources per dependency — compose in order Retry > CircuitBreaker > RateLimiter > Bulkhead.

---

## Topic 10: Service Mesh

---

#### The Idea

Imagine a large office building where every employee needs to badge in and out of every room, log every conversation, follow security protocols, and report their location to facilities management. You could train each employee to do all of this themselves — but that means every new hire needs the same training, rules change means retraining everyone, and you have no guarantee everyone follows the rules consistently. Or you could put a security guard and a monitoring camera outside every room. The guards handle access control, logging, and security uniformly — employees just walk and talk.

A service mesh takes the second approach. Instead of embedding resilience, security, and observability logic in every microservice's application code, a service mesh injects a lightweight network proxy — called a sidecar — into every service's deployment. All traffic in and out of a service flows through its sidecar proxy. The proxy handles mTLS encryption, retries, circuit breaking, load balancing, and telemetry collection — transparently, without the application knowing.

The result is that a polyglot environment — Java services, Python services, Go services — gets consistent network behavior controlled from a central point, with zero changes to application code. When you need to change a timeout policy, you update a configuration object; no service needs to be redeployed.

---

#### How It Works

**Sidecar proxy pattern (Istio + Envoy):**

```
Without service mesh:
  [order-service pod]
    container: order-service

With service mesh (Istio auto-injection):
  [order-service pod]
    container: order-service
    container: envoy-sidecar   <-- injected automatically via MutatingWebhook

iptables rules redirect ALL traffic:
  outbound from order-service --> envoy sidecar --> network --> destination sidecar --> destination service
  inbound  to  order-service  --> envoy sidecar --> (mTLS terminated) --> order-service

order-service code sees plain HTTP. Envoy handles TLS, retries, circuit breaking.
```

**Istio control plane:**

```
istiod (control plane):
  Pilot    --> distributes routing config to all Envoy sidecars via xDS API
  Citadel  --> issues and rotates mTLS certificates (no manual cert management)
  Galley   --> validates Istio configuration objects

Data plane:
  Envoy sidecars receive config from istiod, enforce it on every request
```

**Traffic management objects:**

```yaml
VirtualService: defines routing rules
  - canary: 10% of traffic to v2, 90% to v1
  - fault injection: return 503 for 5% of requests (chaos testing)
  - header-based routing: requests with x-canary-user: true --> v2

DestinationRule: defines policies per destination
  - load balancing algorithm (round robin, least connections, random)
  - outlierDetection (circuit breaking at mesh level -- eject failing instances)
  - connectionPool limits (max connections, max pending requests)
  - tls mode (ISTIO_MUTUAL for mTLS enforcement)
```

**Service mesh vs application library (Resilience4j):**

| Concern | Service Mesh (Istio) | Application Library (Resilience4j) |
|---|---|---|
| Language support | All languages, no code change | JVM only |
| Business context | None — network only | Full access to request data |
| Configuration change | No redeploy | Redeploy required |
| Latency overhead | ~1–2ms per hop (Envoy) | Near zero |
| Circuit breaking semantic | Host ejection from load balancer | Stop all calls to service |
| Recommended for | mTLS, observability, canary | Business-aware resilience rules |

**Must-memorise gotcha — Istio circuit breaking is NOT the same as Resilience4j:**

```yaml
# Istio outlierDetection in DestinationRule:
outlierDetection:
  consecutiveGatewayErrors: 5    # after 5 consecutive 5xx from an instance
  interval: 30s                  # evaluated every 30s
  baseEjectionTime: 30s          # eject the instance for 30s
  maxEjectionPercent: 50         # never eject more than 50% of instances

# This is HOST EJECTION — Envoy removes a specific pod instance from the load balancer pool.
# If order-service pod-A returns 5xx five times, pod-A is ejected. pod-B and pod-C still serve.
# This is NOT a circuit breaker in the Resilience4j sense.
# Resilience4j stops ALL calls to the service.
# Istio outlierDetection removes specific unhealthy instances from rotation.
# They solve related but different problems and should be used together.
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does the sidecar proxy pattern work and what does Istio handle that application code does not need to?"**

**One-line answer:** Istio injects an Envoy sidecar into every pod; all traffic routes through it, enabling mTLS, retries, circuit breaking, load balancing, and telemetry without any application code changes.

**Full answer to give in an interview:**

> "When you label a Kubernetes namespace with istio-injection=enabled, Istio's MutatingWebhook automatically injects an Envoy sidecar container into every new pod. The sidecar is a high-performance C++ proxy that sits in the network path: iptables rules redirect all inbound and outbound traffic through it before it reaches the application container.
>
> From the application's perspective, nothing has changed. The Java service makes a plain HTTP call to inventory-service. What actually happens is: the request goes to the local Envoy sidecar, Envoy establishes a mutual TLS connection to the inventory-service Envoy sidecar, which terminates TLS and forwards plain HTTP to the inventory-service container. The application never sees the TLS — it is transparent.
>
> What Istio handles at the mesh level: mutual TLS with automatic certificate rotation (no manual cert management), distributed tracing via automatic span injection into headers, retry policies configured via VirtualService, load balancing, and outlier detection (ejecting unhealthy instances from rotation). All of these apply to every service in the mesh equally, enforced uniformly, configurable without redeploying services."

> *The MutatingWebhook detail shows you understand the Kubernetes mechanics, not just the Istio marketing.*

**Gotcha follow-up they'll ask:** *"What is the performance overhead of a service mesh and is it always acceptable?"*

> "Envoy adds approximately 0.5 to 2 milliseconds of latency per service hop due to the additional network path through the sidecar. For services with internal call chains 10 hops deep, that is potentially 20ms of added latency — measurable and sometimes unacceptable for low-latency trading systems or real-time gaming backends. At Google scale, 1ms per hop across millions of RPCs per second also has a CPU cost. Mesh proponents argue the operational benefits — uniform security, observability, traffic management — outweigh the latency cost for most enterprise workloads. The pragmatic approach is: measure baseline latency before and after mesh injection in your specific environment, and consider service mesh optional for latency-critical paths while applying it to the rest of the system."

---

##### Q2 — Tradeoff Question
**"What does a service mesh provide that Resilience4j doesn't, and should you use both?"**

**One-line answer:** Service mesh provides language-agnostic, zero-code network-level resilience and security; Resilience4j provides business-context-aware resilience inside the JVM — use both for different concerns.

**Full answer to give in an interview:**

> "Service mesh and Resilience4j operate at completely different layers. Istio sees packets — IP addresses, HTTP status codes, connection counts. It knows a request returned a 503. It does not know whether that 503 was for a payment mutation (which should never be automatically retried) or an inventory check (which is safe to retry). It cannot apply business rules like 'do not retry if the customer's payment was already charged.'
>
> Resilience4j runs inside your JVM. It has access to the full application context: which operation is being called, what the idempotency key is, what the business error type is. You can configure retry to ignore PaymentDeclinedException (a business rejection, not a transient failure) while retrying IOException (a network error).
>
> The production recommendation is to use both, for different concerns. Use Istio for mTLS — enforcing encrypted, authenticated service-to-service communication without code changes across a polyglot environment. Use Istio for distributed tracing auto-instrumentation and canary deployment traffic splitting. Use Resilience4j for business-aware resilience: retry only idempotent operations, circuit break with fallback logic that queues work for async processing, bulkhead with thread isolation for critical paths. The two layers complement each other rather than compete."

> *Explicitly naming the business-context gap — retry rules that need business logic — is the key distinction interviewers are looking for.*

**Gotcha follow-up they'll ask:** *"How is Istio's outlierDetection different from Resilience4j's circuit breaker?"*

> "Istio's outlierDetection does host ejection: if a specific pod instance returns five consecutive 5xx errors, Envoy removes that instance from the load balancer pool for a configured period. The other instances continue to receive traffic. This protects against a single bad pod in a deployment. Resilience4j's circuit breaker operates at the service level: once the failure rate threshold is exceeded across all calls to a service, all calls stop regardless of which instance is responding. Istio handles partial failures within a healthy service fleet; Resilience4j handles total service degradation. You want both: Istio removes bad instances while the overall service is still healthy; Resilience4j opens the circuit when the service as a whole is failing."

---

##### Q3 — Design Scenario
**"Your organization runs 50 microservices in five programming languages. How would you enforce mTLS and observability across all of them without modifying each service?"**

**One-line answer:** Deploy Istio with namespace-level auto-injection enabled and STRICT mTLS mode via PeerAuthentication — sidecars handle mTLS and telemetry transparently for all services regardless of language.

**Full answer to give in an interview:**

> "This is exactly the problem a service mesh was designed to solve. Without a mesh, you would need each team — Java, Python, Go, Node.js, Ruby — to integrate a TLS library, manage certificates, and implement observability instrumentation independently. Consistency is impossible at scale.
>
> With Istio, I would label all application namespaces with istio-injection=enabled. All new pod deployments automatically get an Envoy sidecar. I would then apply a PeerAuthentication object in STRICT mode to those namespaces — this forces all inter-service traffic to use mTLS. Any service without a sidecar cannot communicate with sidecar-injected services. Istio's Citadel component issues and rotates certificates automatically using SPIFFE identities tied to Kubernetes service accounts — no team manages certificates manually.
>
> For observability, Envoy sidecars automatically report request metrics (latency, error rate, throughput) and inject distributed tracing headers into all HTTP calls. I would configure Prometheus to scrape Envoy metrics and deploy Jaeger for traces. Teams get dashboards and traces without adding a single dependency to their service code.
>
> The one thing I would do carefully is the rollout sequence. Enable injection in a staging namespace first, validate that mTLS works for all service-to-service paths, then roll out to production namespace by namespace. Enabling STRICT mTLS before confirming all services have sidecars injected will break communication for any service that missed injection."

> *The rollout sequence warning — STRICT mTLS before confirming full injection breaks traffic — is the operational detail that interviewers at infrastructure-focused companies care about.*

**Gotcha follow-up they'll ask:** *"When would you choose Linkerd over Istio?"*

> "Linkerd is a lighter-weight alternative to Istio with a significantly simpler operational model. It uses a Rust-based microproxy (linkerd-proxy) that is smaller and has lower memory overhead than Envoy. Its configuration surface is smaller — fewer objects to learn. If your needs are primarily mTLS and basic observability without Istio's advanced traffic management features like fault injection, fine-grained header routing, and the full xDS API surface, Linkerd is often easier to operate and debug. I would choose Istio when I need advanced traffic management — canary deployments, A/B testing, weighted routing, fault injection for chaos engineering. I would choose Linkerd for a simpler security and observability baseline with less operational overhead."

---

> **Common Mistake — assuming service mesh eliminates all application-level resilience:** A service mesh cannot make business-aware decisions. It does not know which operations are idempotent, which errors are business rejections versus transient failures, or what fallback behavior makes sense for your domain. Application-level resilience with Resilience4j remains necessary for those concerns.

---

**Quick Revision (one line):**
A service mesh injects sidecar proxies (Envoy) alongside every service to transparently enforce mTLS, collect telemetry, and manage traffic without code changes — use Istio for network-level concerns and Resilience4j for business-context-aware resilience.

---

## Topic 11: Distributed Configuration

---

#### The Idea

Imagine a restaurant chain with 50 branches. Each branch follows the same recipes, but the head office needs to change the sauce formula without flying someone to every location. Instead, the head office posts an updated recipe sheet to a central noticeboard — every branch checks that noticeboard before cooking. That noticeboard is a **distributed configuration server**.

In microservices, each service instance needs settings: database URLs, feature flags, timeout values, API keys. If you bake these directly into each container image, changing one value means rebuilding and redeploying every service. A central configuration server lets you store all settings in one place (backed by Git, a database, or a key-value store like Consul or AWS Parameter Store) and have services fetch their config at startup — or even pick up changes while running.

The key distinction is **environment-specific configuration**: the same service binary runs in dev, staging, and production, but reads different database URLs and log levels from the config server depending on which environment it registers with. This separation of code and config is one of the Twelve-Factor App principles and is foundational to safe, repeatable deployments.

---

#### How It Works

```
STARTUP FLOW
------------
Service boots
  → registers with Config Server (provides: app-name, profile=production, label=main)
  → Config Server reads Git repo at path /{app-name}/{profile}.yml
  → returns merged property set (profile overrides default)
  → Service loads properties, completes startup

RUNTIME REFRESH FLOW (optional)
--------------------------------
Config value changes in Git repo
  → Ops team calls POST /actuator/refresh on service instance
     OR Config Server pushes webhook → Spring Cloud Bus broadcasts refresh event
  → @RefreshScope beans are destroyed and re-created with new values
  → No restart required
```

The must-memorise gotcha: beans annotated `@RefreshScope` are lazily re-created when a refresh event fires — but beans **without** `@RefreshScope` that hold a reference to a refreshed property will **not** pick up the new value. They captured the value at construction time and hold it forever until the JVM restarts.

```java
// GOTCHA: This bean will NOT pick up refreshed values — it captured maxItemsPerOrder at construction
@Service
public class OrderService {
    private final int maxItemsPerOrder;

    public OrderService(@Value("${order.max-items}") int max) {
        this.maxItemsPerOrder = max; // captured once, never updated
    }
}

// CORRECT: Add @RefreshScope so the bean is re-created on refresh events
@Service
@RefreshScope
public class OrderService {
    @Value("${order.max-items}")
    private int maxItemsPerOrder; // re-injected after each refresh

    public int getMax() { return maxItemsPerOrder; }
}
```

**Tradeoffs:**
- Config Server is a new single point of failure — run it in HA mode (multiple instances, Git-backed with local cache).
- Polling for changes adds latency; push-based refresh via Spring Cloud Bus (backed by Kafka or RabbitMQ) is faster but adds infrastructure.
- Secrets (passwords, API keys) should go to a dedicated secrets manager (HashiCorp Vault, AWS Secrets Manager), not a Config Server backed by a plain Git repo.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is distributed configuration and why do microservices need it?"**

**One-line answer:** A central server that stores and serves environment-specific settings so services can be configured without rebuilding or redeploying their container images.

**Full answer to give in an interview:**

> "In a microservices system, you might have 30 different services each needing a database URL, a timeout value, feature flags, and so on. If you embed those values in each service's jar file or Docker image, changing a single value — say, pointing to a new database — means rebuilding and redeploying every affected service. That's slow and error-prone.
>
> A distributed configuration server solves this by storing all properties in a central location — typically backed by a Git repository, which gives you version history and auditability. Each service at startup calls the config server, says 'I'm the order-service running in the production profile,' and gets back a merged set of properties. The profile concept is key: the same service binary uses the production database in prod and a local H2 database in dev, just by switching the active profile.
>
> Spring Cloud Config Server is the Spring ecosystem's implementation of this. It exposes a REST API that services call via the Spring Cloud Config Client. For runtime updates without restarts, you can trigger a refresh event that causes beans marked with @RefreshScope to be re-created with the new values."

> *Keep the profile concept clear — interviewers often probe on how dev/staging/prod differences are handled.*

**Gotcha follow-up they'll ask:** *"What happens if the Config Server goes down while a service is starting up?"*

> "If the Config Server is unavailable at startup, the service will fail to start by default — which is the safe behavior because running with stale or missing config can cause data corruption. Spring Cloud Config Client supports a 'fail-fast' mode that makes this explicit. To mitigate this, you run the Config Server in high-availability mode with multiple instances, enable local caching (the client caches the last-known config so that restarts during a Config Server outage still succeed), and use a shared Git repository or a key-value store like Consul that is itself replicated."

---

##### Q2 — Tradeoff Question
**"Where should you store secrets like database passwords — in the Config Server or somewhere else?"**

**One-line answer:** Secrets belong in a dedicated secrets manager like HashiCorp Vault or AWS Secrets Manager, not in the Config Server's Git-backed store.

**Full answer to give in an interview:**

> "A Config Server backed by a Git repository is great for non-sensitive properties — log levels, feature flags, timeout values — because Git gives you history, diff, and rollback. But database passwords, API keys, and TLS certificates should never live in a Git repo, even a private one, because Git history is persistent and hard to purge, and repo access often spreads wider than it should.
>
> The right tool for secrets is a dedicated secrets manager. HashiCorp Vault stores secrets encrypted at rest, enforces fine-grained access policies, supports secret rotation, and provides an audit log of every secret access. AWS Secrets Manager does the same in the AWS ecosystem. Spring Vault integrates directly with Spring Boot so a service can pull secrets from Vault at startup just like it pulls regular config from a Config Server. The secret never touches the filesystem or environment variables in plaintext — it lives in memory only.
>
> A practical architecture combines both: Spring Cloud Config Server for non-sensitive config, Vault or Secrets Manager for credentials, with both sources merged into the application's Environment at startup."

> *Mention the audit log — it signals production security awareness.*

**Gotcha follow-up they'll ask:** *"How do services pick up a rotated secret without restarting?"*

> "Vault's dynamic secrets feature can issue short-lived credentials that the service refreshes before they expire — so there's no single long-lived password to rotate. For static secrets, the @RefreshScope + Spring Cloud Bus approach works: when a secret is rotated in Vault, a refresh event is broadcast and affected beans are re-created with the new credential. The service's connection pool then drains old connections and opens new ones with the rotated password."

---

> **Common Mistake — Hardcoding Secrets in application.properties:** Putting passwords directly in property files checked into source control exposes credentials to everyone with repo access, and those credentials persist in Git history even after deletion.

---

**Quick Revision (one line):**
A Config Server externalises all environment-specific properties into a central Git-backed store so services fetch their config at startup without embedding it in their image, with @RefreshScope enabling live updates without restarts.

---

## Topic 12: Health Checks and Readiness Probes

---

#### The Idea

Imagine a hospital with an intercom system. Before sending a patient to a ward, the charge nurse calls ahead: "Ward 3, are you ready to accept a patient?" The ward might respond "Not yet — we're still setting up" (not ready), "Yes, send them over" (ready), or not respond at all because the intercom is broken (not alive). These are exactly the three probe types Kubernetes uses to manage container lifecycle.

A **liveness probe** asks: "Is this container still alive?" If the container is running but stuck in a deadlock or infinite loop, the process is technically alive but doing nothing useful. The liveness probe catches this and tells Kubernetes to kill and restart the container. A **readiness probe** asks: "Is this container ready to serve traffic?" A freshly started service might need 30 seconds to warm up caches or establish database connections. During that time it's alive but not ready — Kubernetes should not send it any requests yet. A **startup probe** asks: "Has this container finished its initial startup?" It prevents liveness probes from killing slow-starting containers before they've had time to initialise.

The consequence of each probe failing is different, and this distinction is the core interview point: a **failing readiness probe removes the pod from the load balancer** (no traffic, no restart); a **failing liveness probe restarts the container** (traffic disrupted, pod killed).

---

#### How It Works

```
PROBE LIFECYCLE
---------------
Pod starts
  → startup probe fires repeatedly until success (or failureThreshold exceeded → restart)
  → Once startup probe succeeds, it stops firing

Pod running
  → liveness probe fires every periodSeconds
      FAIL (failureThreshold times) → Kubernetes restarts container
  → readiness probe fires every periodSeconds
      FAIL → pod removed from Service endpoints (no new traffic routed to it)
      PASS → pod added back to Service endpoints

SPRING BOOT MAPPING
-------------------
/actuator/health/liveness  → LivenessStateHealthIndicator
                             BROKEN = container is stuck, restart it
/actuator/health/readiness → ReadinessStateHealthIndicator
                             REFUSING_TRAFFIC = warm-up incomplete, DB unavailable, etc.
```

The must-memorise gotcha: **liveness probe failure → container restarted** (new PID, fresh memory, traffic interrupted); **readiness probe failure → pod removed from load balancer rotation** (container keeps running, no restart, no traffic). Mixing these up is the most common production mistake — if you put a database connectivity check in the liveness probe, a brief DB blip will restart all your pods simultaneously, causing a self-inflicted outage.

```java
// GOTCHA: Database check in liveness probe causes mass pod restarts on DB blip
// management.endpoint.health.group.liveness.include=db   ← WRONG

// CORRECT: DB check belongs in readiness probe (pod stops getting traffic, not restarted)
// application.yml:
// management:
//   health:
//     livenessstate:
//       enabled: true
//     readinessstate:
//       enabled: true
//   endpoint:
//     health:
//       group:
//         liveness:
//           include: livenessState          # only internal JVM state
//         readiness:
//           include: readinessState, db     # external dependencies here
```

**Tradeoffs:**
- Overly aggressive liveness probes (low timeout, low failureThreshold) cause unnecessary restarts under transient load.
- Readiness probes that check too many downstream services can cause cascading failures where one slow dependency makes all pods unready.
- Startup probes are critical for applications with slow initialisation (data loading, index building) — without them, the liveness probe kills the container before it finishes starting.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between a liveness probe and a readiness probe in Kubernetes?"**

**One-line answer:** Liveness checks if the container is alive (failure triggers restart); readiness checks if it can accept traffic (failure removes it from the load balancer without restarting).

**Full answer to give in an interview:**

> "These are two separate health signals Kubernetes uses to manage a pod's lifecycle. A liveness probe answers the question 'is this process still functional?' — if the probe fails enough times, Kubernetes kills the container and starts a fresh one. This handles scenarios like deadlocks or memory corruption where the JVM is technically running but doing nothing useful.
>
> A readiness probe answers a different question: 'is this service ready to handle requests right now?' A pod might be alive but not yet ready — maybe it's still loading a cache, establishing a connection pool, or waiting for a downstream dependency to become available. When the readiness probe fails, Kubernetes removes the pod from the Service's endpoint list, which means the load balancer stops sending it new requests. Critically, the container is NOT restarted — it keeps running and will be added back to rotation once the readiness probe passes again.
>
> The practical consequence of mixing these up is severe: if you put a database health check in the liveness probe, a brief database hiccup will cause Kubernetes to restart all your pods simultaneously — exactly when you least want that. The database check belongs in the readiness probe: pods stop getting traffic during the DB blip, but they don't restart."

> *Draw the contrast explicitly — interviewers want to hear 'removed from load balancer vs restarted.'*

**Gotcha follow-up they'll ask:** *"When would you use a startup probe?"*

> "A startup probe is used for applications that have a slow or unpredictable startup time — for example, a service that loads a large in-memory cache from a database, or an application that runs database migrations on startup. Without a startup probe, you have to set a very high initialDelaySeconds on the liveness probe to give the app time to start. The problem is that initialDelaySeconds is a static delay — if the app starts faster, you've wasted time; if it starts slower, the liveness probe fires anyway. A startup probe solves this cleanly: it fires repeatedly until the app reports healthy, at which point it hands control to the liveness and readiness probes. The liveness probe won't kill a still-starting container."

---

##### Q2 — Tradeoff Question
**"What is the risk of checking downstream dependencies in a liveness probe?"**

**One-line answer:** A transient failure in any checked dependency will trigger a container restart, potentially causing a cascading mass restart of all pods simultaneously.

**Full answer to give in an interview:**

> "The liveness probe's contract is narrow: 'is this JVM process itself functional?' It should only check internal state — thread pool health, whether the application context is loaded, whether internal queues are draining. It should never check external dependencies like databases, message brokers, or downstream services.
>
> Here's the failure scenario: suppose your liveness probe calls the database and the database experiences a 30-second blip — a network hiccup or a brief maintenance window. Every pod's liveness probe starts failing simultaneously. After failureThreshold failures, Kubernetes restarts all pods at once. Now you have a thundering herd: all pods restarting, all trying to reconnect to the database, all flooding it with connection requests exactly when it's coming back up. A minor transient issue has become a full service outage.
>
> The correct placement for database checks is the readiness probe. If the DB is unreachable, pods remove themselves from the load balancer — requests queue at the gateway or fail fast — but the pods stay alive and recover automatically when the database comes back. No restart storm, no thundering herd."

> *The thundering herd scenario is the key production insight here.*

**Gotcha follow-up they'll ask:** *"How do you implement graceful shutdown so in-flight requests complete before the pod terminates?"*

> "When Kubernetes sends SIGTERM to a pod, Spring Boot 2.3+ supports graceful shutdown — you enable it with server.shutdown=graceful and set spring.lifecycle.timeout-per-shutdown-phase to give in-flight requests time to complete. But there's a timing gap: Kubernetes removes the pod from Service endpoints asynchronously, and new requests can still arrive in the seconds after SIGTERM is sent. A common pattern is to add a preStop hook with a short sleep — typically 5–10 seconds — which delays the SIGTERM signal long enough for the load balancer to drain new traffic before shutdown begins."

---

##### Q3 — Design Scenario
**"How would you configure health probes for a Spring Boot service that runs a slow database migration on startup?"**

**One-line answer:** Use a startup probe to gate the liveness and readiness probes until the migration finishes, then readiness checks the DB while liveness checks only internal state.

**Full answer to give in an interview:**

> "The migration creates a window of several minutes where the service is alive but not ready, and the liveness probe must not fire during that window. I'd configure a startup probe with a long failureThreshold — say, 30 attempts at 10-second intervals gives 5 minutes — pointing at /actuator/health/liveness. The liveness and readiness probes are suppressed until the startup probe succeeds.
>
> Once the migration completes, Spring Boot's ApplicationContext finishes loading and the liveness endpoint reports UP. The startup probe succeeds, hands off to the regular probes. The liveness probe then only checks internal health — the actuator's livenessState group, which reflects JVM and application context state only. The readiness probe checks livenessState plus the database connection — so if the DB goes away post-startup, the pod drains traffic rather than restarting.
>
> In the Kubernetes deployment YAML, I'd set initialDelaySeconds=0 on all probes (the startup probe handles the delay), timeoutSeconds=2 so a hung probe fails quickly, and failureThreshold=3 on liveness so transient hiccups don't immediately trigger restarts."

> *Mentioning the specific actuator endpoint paths and the interplay between startup/liveness/readiness shows depth.*

**Gotcha follow-up they'll ask:** *"What if the migration fails partway through?"*

> "If the migration fails, the application context fails to start, the startup probe never succeeds, and after failureThreshold attempts Kubernetes marks the pod as failed and applies the pod's restart policy. For a deployment this means the pod restarts and attempts the migration again — which is fine if the migration is idempotent, which Flyway and Liquibase both guarantee. For a non-idempotent migration failure, you'd want to set restartPolicy to Never or catch the exception, log it, and have the startup probe return DOWN to force a clean failure that surfaces in the pod's events."

---

> **Common Mistake — Checking External Dependencies in Liveness Probe:** Any transient failure in a downstream service will trigger a pod restart; during high load this causes all pods to restart simultaneously, amplifying the outage instead of containing it.

> **Common Mistake — Omitting the Startup Probe for Slow-Starting Apps:** Without a startup probe, you must set a long initialDelaySeconds on the liveness probe. This is a static delay — if startup takes longer than expected, liveness fires anyway and kills a still-initialising container.

---

**Quick Revision (one line):**
Liveness probe failure restarts the container; readiness probe failure removes the pod from the load balancer without restarting — never put external dependency checks in the liveness probe or a transient blip will restart all pods simultaneously.

---

## Topic 13: Strangler Fig Pattern

---

#### The Idea

A strangler fig is a tropical plant that grows around an existing tree. It starts small, wrapping around the host tree, gradually taking over until the original tree dies and the fig stands on its own — having grown entirely around the old structure without a single moment of complete replacement. Martin Fowler named the microservices migration pattern after this plant for exactly that reason.

The strangler fig pattern lets you migrate from a monolithic application to microservices **incrementally and safely**, without a big-bang rewrite. A big-bang rewrite — where you stop working on the old system, rebuild everything from scratch, and cut over on a single date — is extremely risky. The new system is never feature-complete enough, deadlines slip, bugs surface that the old system had quietly solved, and you often end up with "the second system effect." The strangler fig avoids all of this.

The mechanism is a routing proxy — typically an API Gateway — placed in front of the existing monolith. As you extract each piece of functionality into a new microservice, you update the proxy to route those requests to the new service instead of the monolith. The monolith shrinks, the microservices grow, and at no point does the system stop serving traffic. When the last feature is extracted, the monolith is retired.

---

#### How It Works

```
MIGRATION PHASES
----------------
Phase 1 — Install the proxy
  Client requests → API Gateway (new) → Monolith (unchanged)
  Zero change to monolith; establish routing infrastructure

Phase 2 — Extract a service (repeat for each bounded context)
  a) Build new microservice implementing the extracted feature
  b) Deploy in shadow mode: route 0% of traffic to new service,
     compare responses against monolith (dark launch)
  c) Gradual cutover: 5% → 25% → 50% → 100% traffic to new service
     rollback = set routing weight back to 0%
  d) Decommission monolith code path after confidence period

Phase 3 — Retire monolith
  All routes now point to microservices
  Monolith is shut down

KEY DECISION: What to extract first?
  - High-value bounded contexts (independent scalability needs)
  - Well-defined interfaces (clear input/output contracts)
  - Low coupling to rest of monolith (minimal shared state)
  - Small enough to extract in one sprint cycle
```

The must-memorise gotcha is the **proxy-based progressive routing** pattern — the gateway routes by percentage weight or by feature flag, enabling gradual cutover with instant rollback:

```java
// Spring Cloud Gateway as Strangler Fig routing layer
@Configuration
public class StranglerFigRouterConfig {

    @Bean
    public RouteLocator stranglerFigRoutes(RouteLocatorBuilder builder) {
        return builder.routes()
            // Orders endpoint: new microservice handles 100% of traffic (fully migrated)
            .route("order-service", r -> r
                .path("/api/orders/**")
                .uri("lb://order-service"))  // lb:// = load-balanced via service discovery

            // Inventory: in progress — 20% to new service, 80% still to monolith
            // (weight-based routing; production traffic split for gradual confidence building)
            .route("inventory-new", r -> r
                .path("/api/inventory/**")
                .weight("inventory-group", 20)
                .uri("lb://inventory-service"))
            .route("inventory-legacy", r -> r
                .path("/api/inventory/**")
                .weight("inventory-group", 80)
                .uri("http://monolith-app:8080"))

            // Products: not yet started — all traffic to monolith
            .route("products-legacy", r -> r
                .path("/api/products/**")
                .uri("http://monolith-app:8080"))
            .build();
    }
}
```

**Tradeoffs:**
- The API Gateway becomes a critical piece of infrastructure — it must be highly available and performant.
- Running two systems in parallel doubles operational cost during migration.
- The monolith and new service may share a database initially; this is a deliberate temporary compromise — the database split comes after the routing split.
- Feature parity verification in shadow mode requires a robust comparison framework; subtle differences in response shape cause false positives.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the Strangler Fig pattern and what problem does it solve?"**

**One-line answer:** It is an incremental migration strategy that places a routing proxy in front of a monolith and progressively redirects traffic to new microservices, avoiding a risky big-bang rewrite.

**Full answer to give in an interview:**

> "The Strangler Fig pattern solves the problem of migrating a large, working monolith to microservices without taking the system offline or betting the business on a full rewrite. The name comes from the strangler fig plant that grows around an existing tree, gradually replacing it.
>
> The mechanism is straightforward: you deploy an API Gateway or reverse proxy in front of the existing monolith. At first, the proxy passes all traffic straight through to the monolith — nothing changes for users. Then, one bounded context at a time, you build a new microservice implementing that piece of functionality, update the proxy to route those specific endpoints to the new service, and decommission that code path in the monolith. Repeat until the monolith is empty.
>
> The critical safety property is that you can roll back any individual migration instantly — just update the routing weight back to zero. You're never more than one routing change away from the previous state. This is completely impossible in a big-bang rewrite, where there's no safe rollback path once you've cut over."

> *Emphasise the rollback safety — that's the core value proposition.*

**Gotcha follow-up they'll ask:** *"What do you extract first?"*

> "You want to start with a bounded context that has a clear, well-defined interface — meaning the data it owns and the API surface it exposes are obvious and don't require extensive coordination with the rest of the monolith. You also want it to have independent scaling needs or be on the critical path for a business goal, so there's a concrete ROI for the extraction cost. Starting with something too tightly coupled to the rest of the monolith means you'll spend more time untangling shared state than building the service. In practice, teams often extract authentication, notification, or reporting services first — they tend to have clean boundaries and few circular dependencies."

---

##### Q2 — Tradeoff Question
**"During Strangler Fig migration, should the new microservice share the monolith's database initially?"**

**One-line answer:** Yes, temporarily — sharing the database during early migration reduces risk, but you must split it before completing the migration or you end up with a distributed monolith.

**Full answer to give in an interview:**

> "This is a deliberate sequencing decision. When you first extract a service, you face two simultaneous migrations: the routing migration (moving traffic from monolith to microservice) and the data migration (giving the service its own database). Doing both at once doubles the risk and the blast radius if something goes wrong.
>
> The pragmatic approach is to separate them. First, migrate the routing — the new service reads and writes the monolith's database using the same schema. The service is isolated in code and deployment, but shares data infrastructure. Once you're confident the service is correct and stable under production traffic, you do the data migration: create a separate schema or database for the service, run them in parallel with dual-write to keep both in sync, then cut over reads to the new store and stop writing to the old one.
>
> The danger is leaving the shared database in place too long. Teams often say 'just for now' and it becomes permanent. A shared database means changes to the schema affect multiple services, you can't independently scale the data layer, and you can't choose different database technologies per service. The goal is always database-per-service — the shared phase is a temporary bridge, not a final state."

> *Naming the anti-pattern — 'distributed monolith' — shows vocabulary that resonates with interviewers.*

**Gotcha follow-up they'll ask:** *"What is an anti-corruption layer?"*

> "An anti-corruption layer is a translation boundary you put between the new microservice and the legacy system's domain model. When you extract a service, the monolith's data model often reflects years of organic growth — poorly named columns, conflated concepts, implicit conventions. If you let the new service depend directly on that model, you import the technical debt. An anti-corruption layer translates between the legacy model and the new service's clean domain model. In practice it's a thin adapter or mapper class: the service calls clean domain methods, the adapter translates to and from the monolith's DB schema or API. When you eventually replace the legacy system entirely, you delete the adapter rather than unpicking scattered references throughout the new codebase."

---

> **Common Mistake — Extracting Too Many Services Simultaneously:** Running parallel extractions creates dependency conflicts and makes rollback ambiguous; extract one bounded context at a time to keep blast radius small.

> **Common Mistake — Never Splitting the Database:** Sharing the monolith's database permanently defeats the purpose of the migration — you get the operational complexity of microservices without the isolation benefits, a worst-of-both-worlds outcome known as the distributed monolith.

---

**Quick Revision (one line):**
The Strangler Fig pattern places an API Gateway in front of a monolith and progressively re-routes traffic to new microservices one bounded context at a time, enabling safe incremental migration with instant rollback via routing weight changes.

---

## Topic 14: Data Isolation

---

#### The Idea

Imagine three companies sharing a single filing cabinet. Company A needs to reorganise its files, but doing so risks disrupting Company B and C. None of them can choose a different filing system. None of them can scale independently — if Company A brings ten extra filing clerks, there's still only one cabinet. This is the **shared database anti-pattern** in microservices.

The core principle of data isolation in microservices is simple: each service owns its data and no other service is allowed to access it directly. There is no shared database, no service reaching into another service's tables via a JOIN, no batch job reading across schema boundaries. If Service A needs data that Service B owns, it asks Service B for it through an API call or an event — it never bypasses the service and reads the database directly.

This isolation comes at a cost: operations that were a single SQL transaction across tables are now multi-service operations that may fail partway through. The answer to this is **eventual consistency** and the **Saga pattern** — rather than requiring all steps to complete atomically, you design the system to tolerate and recover from partial failures, using compensating transactions to undo completed steps when a later step fails.

---

#### How It Works

```
DATABASE-PER-SERVICE PATTERN
-----------------------------
order-service        → owns: orders_db (PostgreSQL)
inventory-service    → owns: inventory_db (MongoDB)
payment-service      → owns: payments_db (PostgreSQL)
notification-service → owns: notifications_db (Redis)

Rule: No service accesses another service's database directly.
      Cross-service data needs → API calls or event consumption.

SHARED DATABASE ANTI-PATTERN (what not to do)
----------------------------------------------
All services → one shared_db
Problems:
  - Schema change in orders table breaks inventory-service query
  - Cannot scale databases independently
  - Cannot choose optimal DB technology per service
  - Coupling through data layer defeats purpose of microservices

HANDLING CROSS-SERVICE OPERATIONS: SAGA PATTERN
-------------------------------------------------
Two approaches:

Choreography (event-driven, no central coordinator):
  OrderService creates order → publishes OrderCreated event
  InventoryService hears event → reserves stock → publishes StockReserved
  PaymentService hears event → charges card → publishes PaymentCharged
  OrderService hears event → confirms order

  If PaymentService fails → publishes PaymentFailed
  InventoryService hears PaymentFailed → publishes StockReleased (compensating transaction)
  OrderService hears StockReleased → cancels order

Orchestration (central coordinator manages flow):
  OrderSaga (orchestrator) → calls InventoryService.reserveStock()
                           → if success, calls PaymentService.charge()
                           → if payment fails, calls InventoryService.releaseStock()
                           → if all succeed, calls OrderService.confirm()
```

The must-memorise gotcha: **eventual consistency means you cannot read your own write across services**. When OrderService creates an order and InventoryService has not yet processed the StockReserved event, a query to InventoryService will return stale data. This is not a bug — it is a deliberate tradeoff. Systems must be designed to tolerate and communicate this lag, typically through idempotent event handlers, deduplication, and optimistic UI patterns.

```java
// GOTCHA: This pattern breaks because InventoryService's view may lag
// Do NOT do this — cross-service read immediately after write
orderService.createOrder(order);
int stock = inventoryService.getStock(order.getProductId()); // may still show pre-order stock

// CORRECT: Design for eventual consistency — the inventory view catches up asynchronously
// Order confirmed with pending inventory state; UI shows "Processing" until StockReserved event arrives
// InventoryService handles StockReserved idempotently (check if already processed to handle duplicate events)
```

**Tradeoffs:**
- Database-per-service enables independent scaling and technology choice but requires API composition or CQRS for cross-service queries.
- Saga pattern avoids distributed transactions (2PC — Two-Phase Commit, which locks resources across services and fails catastrophically if the coordinator crashes) but introduces complexity in compensating transaction logic.
- Choreography-based sagas are more decoupled but harder to observe and debug; orchestration-based sagas are easier to trace but introduce a new service that becomes a coordination bottleneck.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Why should each microservice have its own database rather than sharing a central one?"**

**One-line answer:** A shared database creates tight coupling through the data layer — schema changes in one service break others, independent scaling becomes impossible, and technology choices are constrained for all services.

**Full answer to give in an interview:**

> "The whole point of microservices is independent deployability — you should be able to change and deploy one service without coordinating with others. A shared database destroys this property at the data layer. If the order service and inventory service share a database, a schema migration in the orders table — adding a column, renaming a field — requires both services to be updated and deployed together. You've coupled their release cycles through the data layer.
>
> Beyond schema coupling, a shared database means you can't scale them independently. If order processing is CPU and I/O intensive but inventory queries are light, you can't give orders more database resources without affecting inventory. You also can't choose the best database technology for each use case — orders might benefit from a relational database with strong ACID guarantees, while inventory's product catalogue might be better served by MongoDB's flexible document model.
>
> The database-per-service pattern enforces these boundaries. No service reads another's tables directly. If Service A needs data from Service B, it calls Service B's API. This means you can change Service B's internal data model without affecting Service A, as long as the API contract stays stable."

> *Lead with the coupling argument — it's more concrete than just listing benefits.*

**Gotcha follow-up they'll ask:** *"How do you handle a query that needs data from three different services?"*

> "You have two main options. The first is API Composition — the client (or an API Gateway acting as a Backend for Frontend) makes parallel calls to all three services and assembles the result in memory. This works well for read-heavy queries where the data is relatively small. The second is CQRS with an event-driven read model — each service publishes events when its data changes, and a dedicated query service subscribes to these events and maintains a denormalised read store that spans all three services. The read store can be a regular relational database optimised for that specific query. The tradeoff is that the read store is eventually consistent — it may lag the source services by a few hundred milliseconds."

---

##### Q2 — Tradeoff Question
**"How do you handle a multi-step business operation that spans multiple services without using distributed transactions?"**

**One-line answer:** Use the Saga pattern — break the operation into a sequence of local transactions, each publishing an event, with compensating transactions to undo completed steps if a later step fails.

**Full answer to give in an interview:**

> "Distributed transactions — specifically 2PC, Two-Phase Commit — require a coordinator to lock resources across all participating services until all agree to commit. This is brittle: if the coordinator crashes between the prepare and commit phases, all services are stuck holding locks. It also scales poorly because the lock window grows with the number of participants and the network latency between them.
>
> The Saga pattern is the microservices alternative. A saga is a sequence of local transactions. Each service performs its local transaction and publishes an event. The next service in the sequence hears that event and performs its local transaction. If any step fails, the saga executes compensating transactions to undo the already-completed steps — for example, if payment fails after inventory has been reserved, a 'release inventory' compensating transaction fires.
>
> There are two coordination styles. In choreography, services react to each other's events with no central coordinator — it's more decoupled but harder to track. In orchestration, a saga orchestrator service explicitly calls each participant and tracks the state machine — easier to observe and debug, but the orchestrator is a new component that must be reliable. I'd choose choreography for simple linear sagas and orchestration for complex branching workflows."

> *Naming 2PC and explaining why it fails positions you as someone who knows the alternatives and their failure modes.*

**Gotcha follow-up they'll ask:** *"What makes a compensating transaction different from a rollback?"*

> "A database rollback undoes changes atomically — either all or nothing, and it happens before any external side effect. A compensating transaction is a new forward operation that semantically reverses the effect of a previous operation. They're not the same thing because the original operation already committed and may have had external effects — an email was sent, a payment was charged, a third-party API was called. You can't un-send an email with a rollback. A compensating transaction issues a reversal: a refund for the payment, a cancellation email, a reverse API call. Compensating transactions must be idempotent — if the network retries them, applying them twice should produce the same result as applying them once."

---

##### Q3 — Design Scenario
**"Design the data layer for an e-commerce system with order, inventory, and payment services."**

**One-line answer:** Three separate databases, saga-based order creation flow, CQRS read model for order history queries that span all three services.

**Full answer to give in an interview:**

> "Each service gets its own database chosen for its access patterns: OrderService owns a PostgreSQL database — orders are relational, need ACID guarantees for financial integrity. InventoryService owns a MongoDB database — product catalogue data is hierarchical and varies by category, document model fits well. PaymentService owns a PostgreSQL database — payment records are transactional, need audit trail and strong consistency.
>
> For the order creation flow, I'd use a choreography-based saga: OrderService creates a pending order and publishes an OrderCreated event. InventoryService hears this, reserves stock, and publishes StockReserved. PaymentService hears StockReserved, charges the card, and publishes PaymentCharged. OrderService hears PaymentCharged and marks the order confirmed. If PaymentService fails, it publishes PaymentFailed; InventoryService hears this and releases the reservation.
>
> For order history queries — which need order details, item names from inventory, and payment status — I'd use a CQRS read model. A separate OrderHistoryService subscribes to all three services' events and maintains a denormalised read table optimised for the 'order history' query. This table is updated asynchronously, so it's eventually consistent, but reads are fast single-table queries. The UI shows 'Processing' for orders where the read model hasn't yet received the confirmation event."

> *Naming the specific technology choices and explaining why shows production depth.*

**Gotcha follow-up they'll ask:** *"How do you handle duplicate events in the saga?"*

> "Duplicate events are inevitable in distributed systems — message brokers guarantee at-least-once delivery, so an event may be processed more than once. Every saga participant must be idempotent. The standard approach is to include a unique event ID with each event and maintain a processed-events table. Before processing an event, the service checks whether that event ID has already been processed. If it has, the service acknowledges the message and does nothing. This is called idempotent event processing. The processed-events table can be cleaned up after a TTL — you only need to guard against duplicates within the realistic retry window, not forever."

---

> **Common Mistake — Shared Database 'Just for This Query':** Even one cross-service database JOIN creates tight coupling; schema changes in either service now require coordinating both, and the coupling spreads organically from there.

> **Common Mistake — Using 2PC for Cross-Service Transactions:** Two-Phase Commit locks resources across services and fails catastrophically if the coordinator crashes; the Saga pattern with compensating transactions is the correct distributed alternative.

---

**Quick Revision (one line):**
Each microservice owns its database exclusively; cross-service operations use the Saga pattern with compensating transactions for rollback, accepting eventual consistency as the tradeoff for independent deployability and scalability.

---

## Topic 15: Microservices Security

---

#### The Idea

In a traditional monolith, all components run in the same process. When the order module calls the inventory module, there's no network hop — it's a function call, and the assumption of trust is baked in. In microservices, every inter-service call crosses a network boundary. The network inside a Kubernetes cluster looks safe, but it's not: a compromised container can listen on the internal network, intercept traffic, or impersonate a legitimate service.

The answer is **zero-trust networking**: never trust any communication, even from inside the cluster. Every external request must be authenticated (proven identity) and authorised (permitted to perform the action). Every service-to-service call must be verified, not assumed safe because it comes from the internal network. This sounds expensive, but modern tooling — service meshes, mTLS, JWT validation — makes it largely transparent to application code.

The security architecture has two distinct boundaries: the **external boundary** (clients calling the API Gateway) uses standard OAuth2 and JWT — a user logs in, gets a token, presents it with every request. The **internal boundary** (service-to-service calls) uses mutual TLS (mTLS) — both sides present a certificate, proving identity without requiring a user token. A service mesh like Istio or Linkerd can inject mTLS transparently into every pod, without application code changes.

---

#### How It Works

```
EXTERNAL BOUNDARY (client → API Gateway)
------------------------------------------
Client authenticates with Identity Provider (Keycloak, Auth0, Okta)
  → receives JWT (JSON Web Token) — a signed token containing:
      header.payload.signature (Base64-encoded, dot-separated)
      payload: { sub: "user123", roles: ["CUSTOMER"], exp: 1720000000 }

Client sends JWT in every request:
  Authorization: Bearer <jwt-token>

API Gateway validates JWT:
  - Verify signature using Identity Provider's public key
  - Check expiry (exp claim)
  - Check issuer (iss claim)
  - Extract roles/scopes

Two forwarding strategies:
  Token Relay: Gateway forwards original JWT to downstream services
               → Services re-validate JWT; user context (roles, sub) preserved
  Token Exchange: Gateway exchanges JWT for an internal service token
                  → Services trust internal token; external JWT never reaches services

INTERNAL BOUNDARY (service → service)
---------------------------------------
Option 1: mTLS (mutual TLS)
  Each service has a certificate issued by cluster CA
  On each connection: both sides present certificate, verify the other's
  Ensures: caller is who it claims to be (authentication) + traffic is encrypted
  Service mesh (Istio/Linkerd) can inject mTLS sidecar automatically

Option 2: OAuth2 Client Credentials
  Service A gets a service-level access token from Identity Provider
    using its own client-id and client-secret (no user involved)
  Presents token to Service B; Service B validates with Identity Provider
  Slower than mTLS (token validation adds latency) but simpler without a service mesh

AUTHORISATION
--------------
Coarse-grained: API Gateway checks JWT roles before forwarding
                (CUSTOMER cannot call /admin/**, ANALYST cannot call /payments/**)
Fine-grained:   Each service checks specific permissions for specific resources
                (User can only GET /orders/{id} if order.customerId == token.sub)
```

The must-memorise gotcha: the API Gateway validates the JWT from external clients, but **downstream services must not blindly trust the Gateway**. If an attacker bypasses the Gateway and calls a service directly (possible if the service is accidentally exposed, or if another service is compromised), the service should still validate the token or mTLS certificate. The Gateway is a convenience, not a security guarantee.

```java
// GOTCHA: Trusting the Gateway blindly — no validation in downstream service
@RestController
public class OrderController {
    @GetMapping("/orders/{id}")
    public Order getOrder(@PathVariable Long id) {
        return orderService.find(id); // no auth check — relies entirely on Gateway
    }
}

// CORRECT: Resource server validates JWT independently of Gateway
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwkSetUri("https://identity-provider/.well-known/jwks.json")))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/orders/**").hasRole("CUSTOMER")
                .anyRequest().authenticated());
        return http.build();
    }
}
```

**Tradeoffs:**
- Token relay (forwarding the user's JWT downstream) preserves user context but means every service must validate JWTs, adding latency and coupling to the Identity Provider.
- mTLS provides strong service identity but requires certificate lifecycle management (issuance, rotation, revocation) — a service mesh handles this automatically but adds operational complexity.
- Fine-grained authorisation in every service is correct but expensive to implement consistently; a policy engine like OPA (Open Policy Agent) centralises the policy logic while keeping enforcement at the service level.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does authentication work across microservices — what happens after the API Gateway validates the JWT?"**

**One-line answer:** The Gateway validates the JWT and either forwards it downstream (token relay) so each service re-validates it, or exchanges it for an internal token — but downstream services must still validate independently, never trust the Gateway implicitly.

**Full answer to give in an interview:**

> "JWT stands for JSON Web Token — it's a signed, self-contained token that encodes the user's identity and permissions. The user authenticates with an Identity Provider like Keycloak or Auth0, gets a JWT, and sends it in the Authorization header with every request.
>
> The API Gateway receives the request and validates the JWT: it checks the signature using the Identity Provider's public key, verifies the token hasn't expired, and checks the issuer. If validation passes, the Gateway can forward the request to the downstream service in one of two ways.
>
> With token relay, the Gateway simply passes the original JWT along. The downstream service receives it and re-validates it independently — this is the Spring Security OAuth2 resource server pattern. The service can extract the user's roles and subject from the token to make authorisation decisions.
>
> With token exchange, the Gateway swaps the external user token for an internal service token before forwarding. This keeps the external token from spreading through the internal network and allows you to enrich the internal token with service-specific claims.
>
> The critical mistake is for downstream services to trust the Gateway blindly — to assume any request that arrives through the internal network is already authenticated. If an attacker compromises one service or finds an exposed endpoint that bypasses the Gateway, they can call other services without any token. Each service must validate independently."

> *The 'trust the Gateway blindly' anti-pattern is what interviewers probe on — name it explicitly.*

**Gotcha follow-up they'll ask:** *"How do you handle service-to-service authentication — when Service A calls Service B with no user context?"*

> "For service-to-service calls there's no user logging in, so a user JWT doesn't apply. The two main approaches are mTLS and the OAuth2 Client Credentials grant. With mTLS — mutual TLS — both services present a certificate issued by a cluster-internal certificate authority. The connection is encrypted and both sides verify each other's identity. A service mesh like Istio automates this entirely: it injects a sidecar proxy into each pod, manages certificate issuance and rotation, and enforces mTLS for all pod-to-pod communication without any code changes.
>
> The OAuth2 Client Credentials grant is the alternative: Service A authenticates with the Identity Provider using its own client ID and secret, gets a service-level access token, and presents that token to Service B. Service B validates it with the Identity Provider. This is simpler to set up without a service mesh but adds latency for token validation on each call and requires secure storage of client secrets."

---

##### Q2 — Tradeoff Question
**"What is the difference between authentication and authorisation in a microservices context, and where should each happen?"**

**One-line answer:** Authentication (who are you?) happens at the Gateway; authorisation (what are you allowed to do?) happens both at the Gateway for coarse-grained rules and at each service for fine-grained resource-level decisions.

**Full answer to give in an interview:**

> "Authentication answers 'who is making this request?' — it validates the JWT signature and extracts the identity. Authorisation answers 'is this identity allowed to perform this action on this resource?' — it checks roles, permissions, and resource ownership.
>
> In a microservices architecture, authentication should happen at the API Gateway — it's the single entry point, so validating the token once there prevents invalid requests from wasting downstream service resources. The Gateway can also enforce coarse-grained authorisation: 'only users with the ADMIN role can access /admin/** endpoints.' This is efficient to check at the perimeter with JWT role claims.
>
> But fine-grained authorisation must happen in the individual services. The classic example: a user should only be able to read their own orders. The rule is 'GET /orders/{id} is allowed only if order.customerId equals token.sub.' The API Gateway doesn't have access to the order's customerId — that's business logic in the Order Service. The Order Service must extract the subject from the JWT, look up the order, and verify ownership.
>
> Putting all authorisation in the Gateway creates a fat gateway that contains business logic and must be updated every time authorisation rules change. Putting no authorisation in the Gateway means invalid requests waste compute in every service before being rejected. The right split is perimeter gateway for identity and coarse-grained role checks, individual services for business-logic-level permissions."

> *The ORDER example with customerId vs token.sub is the concrete illustration that makes this stick.*

**Gotcha follow-up they'll ask:** *"How do you propagate user context through an async event-driven flow — there's no HTTP request to carry the JWT?"*

> "In an event-driven system, the user context travels in the event payload, not in an HTTP header. When Service A publishes an event triggered by a user action, it should include the relevant identity information — typically the user's subject (sub) claim from the JWT — as a field in the event. Downstream consumers read this field to understand who initiated the action and apply appropriate authorisation checks. You don't include the raw JWT in the event — it may have expired by the time the consumer processes the event. Instead, you include the stable identity claims (sub, tenantId, roles at the time of the action) and sign the event payload with the service's private key so consumers can verify the event wasn't tampered with."

---

##### Q3 — Design Scenario
**"How would you secure a microservices system where some services hold sensitive financial data?"**

**One-line answer:** API Gateway for external JWT validation, mTLS via service mesh for internal service identity, fine-grained RBAC in financial services, secrets in Vault, and audit logging on all data access.

**Full answer to give in an interview:**

> "I'd layer the security at multiple levels. At the perimeter, the API Gateway validates all incoming JWTs, enforces HTTPS (TLS termination), and applies rate limiting to prevent abuse. Only authenticated, rate-limited requests reach internal services.
>
> For internal service-to-service communication, I'd use a service mesh — Istio is the most mature option — which automatically enforces mTLS for all pod-to-pod traffic. This means every service connection is encrypted and both endpoints have verified identities. No service can impersonate another without a valid certificate from the cluster CA.
>
> The financial services — payment processing, account management — get additional controls. They run as Spring Security resource servers, independently validating JWTs even when called through the Gateway. Fine-grained authorisation checks verify that the requesting identity owns the resource being accessed. Sensitive fields in API responses are filtered based on the caller's role — a customer sees their balance but not internal risk scores.
>
> Secrets — database credentials, external API keys, encryption keys — live in HashiCorp Vault. Services fetch them at startup via the Vault agent sidecar; secrets are never in environment variables or config files. Vault enforces access policies so only the payment service can retrieve payment credentials.
>
> Finally, audit logging: every access to sensitive financial data writes an immutable audit record — who accessed what, when, from which service identity. This is non-negotiable for financial systems and is often a regulatory requirement."

> *Mentioning regulatory requirements signals production and compliance awareness.*

**Gotcha follow-up they'll ask:** *"How do you handle JWT token revocation before expiry — for example, when a user logs out or their account is compromised?"*

> "JWTs are stateless and self-validating — once issued, a service that holds only the public key can validate a token without calling the Identity Provider. This is great for performance but means there's no way to revoke a specific token before its expiry. If a user logs out or their account is compromised, the token remains valid until it expires.
>
> The solutions involve accepting a tradeoff. Short token expiry — 5 to 15 minutes — minimises the compromise window. Refresh tokens with longer expiry handle re-authentication silently. For true immediate revocation, you need a token revocation list: a fast store like Redis that services check on each request. The service validates the JWT signature as usual, then does a cheap Redis lookup: 'has this token's jti (JWT ID) been revoked?' If yes, reject immediately. This adds a network round-trip per request but gives you immediate revocation capability. The Redis store only needs to hold tokens until their natural expiry — after that they're invalid anyway."

---

> **Common Mistake — Trusting the Internal Network:** Assuming that service-to-service calls within the cluster are safe because they never leave the network — a compromised container can intercept or forge internal traffic; mTLS or explicit service authentication is required for true zero-trust security.

> **Common Mistake — Hardcoding Service Credentials:** Storing client secrets or database passwords in application.properties or environment variables means they appear in logs, config dumps, and version control; use Vault or Secrets Manager with short-lived dynamic credentials.

---

**Quick Revision (one line):**
Secure microservices with JWT validation at the API Gateway for external clients, mTLS or OAuth2 client credentials for service-to-service calls, fine-grained authorisation in each service for resource-level decisions, and secrets managed via Vault — never trust the internal network implicitly.
