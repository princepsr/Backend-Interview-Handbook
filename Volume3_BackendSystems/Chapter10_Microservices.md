# Volume 3: Backend Systems
# Chapter 10: Microservices Architecture

---

## Table of Contents
1. [Microservices vs Monolith](#topic-1-microservices-vs-monolith)
2. [API Gateway](#topic-2-api-gateway)
3. [Service Discovery](#topic-3-service-discovery)
4. [Inter-service Communication](#topic-4-inter-service-communication)
5. [Circuit Breaker Pattern](#topic-5-circuit-breaker-pattern)
6. [Saga Pattern](#topic-6-saga-pattern)
7. [Event-Driven Architecture](#topic-7-event-driven-architecture)
8. [Distributed Tracing](#topic-8-distributed-tracing)
9. [Resilience Patterns](#topic-9-resilience-patterns)
10. [Service Mesh](#topic-10-service-mesh)
11. [Distributed Configuration](#topic-11-distributed-configuration)
12. [Health Checks & Readiness Probes](#topic-12-health-checks--readiness-probes)
13. [Strangler Fig Pattern](#topic-13-strangler-fig-pattern)
14. [Data Isolation](#topic-14-data-isolation)
15. [Microservices Security](#topic-15-microservices-security)

---

### Topic 1: Microservices vs Monolith
**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Netflix, Uber, Google, Stripe

**Q: When would you choose a monolith over microservices, and what are the main decomposition strategies?**

**Short Answer (2-3 sentences):**
Microservices decompose an application into small, independently deployable services each owning its data and business capability. However, microservices add significant operational complexity "” distributed tracing, network latency, data consistency "” making them unsuitable for small teams, early-stage products, or simple domains. Choose microservices when independent scaling, technology heterogeneity, or team autonomy at scale genuinely justifies the overhead.

**Deep Explanation:**
Decomposition strategies include:

1. **Decompose by Business Capability** "” Align services with organizational functions (e.g., OrderService, PaymentService, InventoryService). Services map to bounded contexts from Domain-Driven Design (DDD).

2. **Decompose by Subdomain** "” Use DDD's core/supporting/generic subdomains. Core subdomains (competitive advantage) warrant dedicated teams; generic subdomains (email, auth) can use third-party solutions.

3. **Strangler Fig** "” Incrementally extract functionality from a monolith; new features built as services, legacy code gradually replaced.

4. **Anti-corruption Layer** "” A translation layer between legacy monolith and new services to prevent domain model pollution.

**When NOT to use microservices:**
- Team size < 10 engineers (coordination overhead exceeds benefits)
- Early-stage startup (requirements change too fast)
- Simple CRUD applications with no scaling concerns
- Strong data consistency requirements (distributed transactions are painful)
- No DevOps/Kubernetes maturity (operational burden is enormous)

The "distributed monolith" anti-pattern "” services that are tightly coupled and must deploy together "” is worse than a real monolith because you get all the complexity with none of the benefits.

**Real-World Example:**
Amazon started as a monolith in 1995. By 2002, Jeff Bezos mandated the "API Mandate" "” all teams must expose functionality via service interfaces. This enabled the evolution to microservices and eventually AWS. Netflix migrated from DVD monolith to streaming microservices (700+ services) starting 2008, driven by need to scale video streaming independently of account management.

**Code Example:**
```java
// Monolith: everything in one service
@Service
public class OrderService {
    @Autowired private InventoryRepository inventoryRepo;
    @Autowired private PaymentRepository paymentRepo;
    @Autowired private NotificationService notificationService;

    @Transactional
    public Order placeOrder(OrderRequest request) {
        // All in one DB transaction - simple but tightly coupled
        Inventory inventory = inventoryRepo.findById(request.getProductId())
            .orElseThrow(() -> new ProductNotFoundException(request.getProductId()));
        inventory.reserve(request.getQuantity());
        inventoryRepo.save(inventory);

        Payment payment = paymentRepo.charge(request.getCustomerId(), request.getAmount());
        Order order = new Order(request, payment.getId());
        notificationService.sendConfirmation(order);
        return order;
    }
}

// Microservice: OrderService only owns order domain
@Service
public class OrderService {
    private final InventoryClient inventoryClient;   // HTTP/gRPC call
    private final PaymentClient paymentClient;       // HTTP/gRPC call
    private final OrderRepository orderRepository;   // owns its own DB
    private final ApplicationEventPublisher eventPublisher;

    public Order placeOrder(OrderRequest request) {
        // Calls other services - each owns its own data
        inventoryClient.reserve(request.getProductId(), request.getQuantity());
        String paymentId = paymentClient.charge(request.getCustomerId(), request.getAmount());
        Order order = orderRepository.save(new Order(request, paymentId));
        // Publish event for notification service to consume asynchronously
        eventPublisher.publishEvent(new OrderPlacedEvent(order));
        return order;
    }
}
```

**Follow-up Questions:**
1. What is a "distributed monolith" and how do you avoid it?
2. How does DDD's bounded context map to microservice boundaries?
3. How do you handle shared libraries across microservices without tight coupling?

**Common Mistakes:**
- Creating too many fine-grained services ("nanoservices") "” each network hop adds latency and failure points
- Sharing a database between microservices "” this creates hidden coupling and defeats independent deployability

**Interview Traps:**
- Interviewers expect you to argue AGAINST microservices sometimes; saying "always use microservices" is a red flag
- "Microservices are just SOA rebranded" "” partially true, but microservices emphasize lightweight protocols (HTTP/messaging vs SOAP), independent deployment, and decentralized data

**Quick Revision (1-liner):**
Microservices decompose by business capability with independent data ownership; avoid them when operational complexity exceeds scaling benefits.

---

### Topic 2: API Gateway
**Difficulty:** Medium | **Frequency:** High | **Companies:** Netflix, Amazon, Stripe, Twilio, Shopify

**Q: What is an API Gateway and how does it handle cross-cutting concerns like authentication, rate limiting, and request aggregation?**

**Short Answer (2-3 sentences):**
An API Gateway is the single entry point for all client requests, routing them to appropriate backend microservices while handling cross-cutting concerns like authentication, rate limiting, SSL termination, and request/response transformation. It decouples clients from the internal service topology, allowing services to evolve independently. Popular implementations include Kong, AWS API Gateway, and Spring Cloud Gateway.

**Deep Explanation:**
**Core responsibilities:**

1. **Routing** "” Pattern-based routing to backend services (`/api/orders/**` â†’ OrderService). Supports path rewriting, header-based routing, canary deployments.

2. **Authentication/Authorization** "” Validates JWT tokens or API keys before forwarding requests. Eliminates need for each service to implement auth logic. Can integrate with OAuth2 authorization servers.

3. **Rate Limiting** "” Token bucket or sliding window algorithms per client/IP/API key. Protects backends from traffic spikes. Redis-backed distributed rate limiting for multi-instance gateways.

4. **Request Aggregation (Backend for Frontend pattern)** "” Single gateway request fans out to multiple services and aggregates responses. Reduces client round trips especially on mobile.

5. **Load Balancing** "” Distributes requests across service instances. Integrates with service discovery (Eureka, Consul).

6. **SSL Termination** "” Handles HTTPS at gateway; internal services can use plain HTTP.

7. **Circuit Breaking** "” Stops forwarding requests to unhealthy services.

8. **Observability** "” Centralized logging, metrics, and distributed trace injection.

**Spring Cloud Gateway filter chain:**
Requests pass through a chain of `GatewayFilter` instances (pre-filters then post-filters), enabling pluggable behavior without modifying service code.

**Real-World Example:**
Netflix's Zuul (and later Zuul 2) handles 100% of Netflix external traffic. It routes ~2,000 different device types to appropriate backend clusters, handles authentication, and implements per-user rate limiting. Stripe's API Gateway enforces idempotency key validation and request signing verification before any request reaches business logic services.

**Code Example:**
```java
// Spring Cloud Gateway configuration (Spring Boot 3.x)
@Configuration
public class GatewayConfig {

    @Bean
    public RouteLocator customRouteLocator(RouteLocatorBuilder builder) {
        return builder.routes()
            // Route with JWT auth filter and rate limiting
            .route("order-service", r -> r
                .path("/api/orders/**")
                .filters(f -> f
                    .rewritePath("/api/orders/(?<segment>.*)", "/${segment}")
                    .requestRateLimiter(config -> config
                        .setRateLimiter(redisRateLimiter())
                        .setKeyResolver(userKeyResolver()))
                    .circuitBreaker(cb -> cb
                        .setName("orderServiceCB")
                        .setFallbackUri("forward:/fallback/orders")))
                .uri("lb://ORDER-SERVICE"))  // lb:// = load-balanced via Eureka

            // Aggregation route
            .route("product-detail", r -> r
                .path("/api/product-detail/**")
                .filters(f -> f.filter(aggregationFilter()))
                .uri("no://op"))
            .build();
    }

    @Bean
    public RedisRateLimiter redisRateLimiter() {
        // 10 requests per second, burst of 20
        return new RedisRateLimiter(10, 20, 1);
    }

    @Bean
    public KeyResolver userKeyResolver() {
        return exchange -> Mono.justOrEmpty(
            exchange.getRequest().getHeaders().getFirst("X-User-Id"))
            .defaultIfEmpty("anonymous");
    }
}

// Custom authentication pre-filter
@Component
public class JwtAuthFilter implements GlobalFilter, Ordered {

    private final JwtTokenValidator jwtValidator;

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String token = extractToken(exchange.getRequest());
        if (token == null) {
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }
        return jwtValidator.validate(token)
            .flatMap(claims -> {
                // Forward user info downstream via headers
                ServerHttpRequest mutatedRequest = exchange.getRequest().mutate()
                    .header("X-User-Id", claims.getSubject())
                    .header("X-User-Roles", String.join(",", claims.getRoles()))
                    .build();
                return chain.filter(exchange.mutate().request(mutatedRequest).build());
            })
            .onErrorResume(e -> {
                exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
                return exchange.getResponse().setComplete();
            });
    }

    @Override
    public int getOrder() { return -1; } // Run before other filters

    private String extractToken(ServerHttpRequest request) {
        String header = request.getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
        if (header != null && header.startsWith("Bearer ")) {
            return header.substring(7);
        }
        return null;
    }
}
```

**Follow-up Questions:**
1. What is the Backend for Frontend (BFF) pattern and how does it differ from a general API gateway?
2. How do you handle gateway failures "” what happens when the gateway itself goes down?
3. How would you implement API versioning at the gateway level?

**Common Mistakes:**
- Putting business logic in the gateway "” it should only handle cross-cutting concerns, not domain rules
- Single gateway instance without redundancy "” the gateway becomes the single point of failure for the entire system

**Interview Traps:**
- "API Gateway vs Load Balancer" "” load balancers work at L4 (TCP) or L7 (HTTP) but don't understand API semantics; gateways operate at L7 and understand routes, auth, and aggregation
- Spring Cloud Gateway is reactive (Netty-based, non-blocking); Zuul 1 was servlet-based (blocking) "” mixing them causes confusion about threading models

**Quick Revision (1-liner):**
API Gateway is the single entry point handling routing, auth, rate limiting, and aggregation so individual services don't implement cross-cutting concerns.

---

### Topic 3: Service Discovery
**Difficulty:** Medium | **Frequency:** High | **Companies:** Netflix, Amazon, Uber, Lyft, Square

**Q: Explain client-side vs server-side service discovery and when you would choose each approach.**

**Short Answer (2-3 sentences):**
In client-side discovery, the client queries a service registry (e.g., Eureka) and performs load balancing itself using libraries like Spring Cloud LoadBalancer. In server-side discovery, clients send requests to a load balancer (e.g., AWS ALB or Kubernetes Service) which queries the registry and routes the request transparently. Client-side gives more control and flexibility; server-side is simpler for clients but adds an infrastructure dependency.

**Deep Explanation:**
**Client-side discovery (Netflix Eureka + Spring Cloud LoadBalancer):**
1. Services register on startup with heartbeats every 30s
2. Client fetches registry snapshot and caches it locally
3. Client applies load balancing algorithm (round-robin, weighted, zone-aware)
4. Client handles retry and circuit breaking

Pros: No extra network hop, client can implement sophisticated routing (canary, A/B)
Cons: Every client must implement discovery logic; registry client library needed per language

**Server-side discovery (AWS ALB, Kubernetes Service, Consul + Fabio):**
1. Client sends request to well-known load balancer endpoint
2. Load balancer queries registry or uses built-in health checks
3. Load balancer selects instance and forwards request

Pros: Language-agnostic clients; centralized routing policy
Cons: Extra network hop; load balancer can become bottleneck

**DNS-based discovery:**
Services register as DNS SRV records. Clients use standard DNS resolution. Works well with Kubernetes (CoreDNS) "” `order-service.default.svc.cluster.local` resolves to Service ClusterIP. TTL tuning critical to avoid stale entries during rolling deployments.

**Kubernetes approach:** Kubernetes Services provide stable VIPs; kube-proxy manages iptables rules. Pods register via label selectors, not explicit registration "” Kubernetes reconciliation loop handles it.

**Real-World Example:**
Netflix runs Eureka across multiple AWS regions with zone-aware routing "” services prefer instances in the same AWS availability zone to reduce inter-AZ data transfer costs. During the 2011 AWS outage, Eureka's client-side caching kept Netflix partially operational even when the registry itself was unavailable.

**Code Example:**
```java
// Eureka Server (service registry)
@SpringBootApplication
@EnableEurekaServer
public class ServiceRegistryApplication {
    public static void main(String[] args) {
        SpringApplication.run(ServiceRegistryApplication.class, args);
    }
}

// application.yml for Eureka Server
// eureka:
//   client:
//     register-with-eureka: false
//     fetch-registry: false

// Eureka Client (microservice registration)
@SpringBootApplication
@EnableDiscoveryClient
public class OrderServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }
}

// application.yml for client service
// spring:
//   application:
//     name: order-service
// eureka:
//   client:
//     service-url:
//       defaultZone: http://eureka-server:8761/eureka/
//   instance:
//     prefer-ip-address: true
//     lease-renewal-interval-in-seconds: 10
//     lease-expiration-duration-in-seconds: 30

// Client-side load balanced RestClient
@Configuration
public class ServiceClientConfig {

    @Bean
    @LoadBalanced  // Spring Cloud LoadBalancer intercepts and resolves service names
    public RestClient.Builder loadBalancedRestClientBuilder() {
        return RestClient.builder();
    }
}

@Service
public class InventoryClient {

    private final RestClient restClient;

    public InventoryClient(RestClient.Builder builder) {
        // "inventory-service" resolved via Eureka registry
        this.restClient = builder.baseUrl("http://inventory-service").build();
    }

    public InventoryResponse checkStock(String productId) {
        return restClient.get()
            .uri("/api/inventory/{productId}", productId)
            .retrieve()
            .body(InventoryResponse.class);
    }
}

// Kubernetes Service (server-side discovery via DNS)
// apiVersion: v1
// kind: Service
// metadata:
//   name: order-service
// spec:
//   selector:
//     app: order-service
//   ports:
//     - port: 8080
//       targetPort: 8080
// ---
// Client just calls http://order-service:8080 "” kube-proxy handles routing
```

**Follow-up Questions:**
1. What happens to in-flight requests during a service instance restart in Eureka?
2. How does Kubernetes handle service discovery for services in different namespaces?
3. What is the "self-preservation mode" in Eureka and when does it activate?

**Common Mistakes:**
- Not configuring Eureka heartbeat intervals appropriately "” default 30s registration delay means new instances aren't discoverable for up to 90s after startup
- Trusting stale registry entries "” client-side caches can serve dead instance addresses; always combine with circuit breakers

**Interview Traps:**
- Eureka is eventually consistent "” it does not guarantee all clients have up-to-date registry state simultaneously
- Kubernetes Services are NOT service discovery in the traditional sense "” they're stable network endpoints backed by kube-proxy, which is different from polling a registry

**Quick Revision (1-liner):**
Client-side discovery (Eureka+LoadBalancer) gives clients control; server-side (ALB/K8s Service) simplifies clients at the cost of an extra network hop.

---

### Topic 4: Inter-service Communication
**Difficulty:** Hard | **Frequency:** High | **Companies:** Uber, Lyft, Google, Amazon, Twitter

**Q: How do you choose between synchronous (REST/gRPC) and asynchronous (messaging) communication between microservices?**

**Short Answer (2-3 sentences):**
Synchronous communication (REST, gRPC) is appropriate when the caller needs an immediate response to proceed "” querying a user profile before rendering a page. Asynchronous messaging (Kafka, RabbitMQ) is better for operations where the caller doesn't need to wait "” sending an email after order placement "” and provides natural decoupling, buffering, and resilience. The choice depends on whether the operation is a query (synchronous) or a command/event that can be processed later (asynchronous).

**Deep Explanation:**
**REST (HTTP/JSON):**
- Human-readable, universally supported, easy to debug with curl
- Stateless; HTTP caching with ETags/Cache-Control
- Overhead: JSON serialization, HTTP headers, text encoding
- Best for: public APIs, simple CRUD, external integrations

**gRPC (HTTP/2 + Protobuf):**
- Binary serialization (10x smaller payloads than JSON)
- Strong typing via `.proto` schema "” compile-time API contracts
- Bidirectional streaming support
- HTTP/2 multiplexing "” multiple concurrent requests over single connection
- Best for: internal high-throughput services, streaming, polyglot environments
- Downside: less human-readable, requires proto toolchain, limited browser support

**Asynchronous messaging (Kafka, RabbitMQ, SQS):**
- Temporal decoupling "” producer and consumer don't need to be running simultaneously
- Natural load leveling "” consumer processes at its own pace
- Event replay "” Kafka retains messages for replay
- At-least-once vs exactly-once delivery semantics matter
- Best for: event-driven workflows, long-running operations, fan-out to multiple consumers
- Downside: eventual consistency, harder to debug, need to handle duplicate messages

**Decision framework:**
- Need immediate result? â†’ synchronous (REST/gRPC)
- Fire and forget / multiple consumers? â†’ async messaging
- High throughput internal? â†’ gRPC
- Cross-team/external API? â†’ REST

**Real-World Example:**
Uber uses gRPC internally for ~1,000 microservices with Protobuf schemas versioned in a central registry. Payment confirmation is synchronous (user waits), but receipt email and driver rating requests are asynchronous via Kafka. This way a Kafka broker outage doesn't prevent trip completion.

**Code Example:**
```java
// gRPC service definition (proto)
// service OrderService {
//   rpc GetOrder (GetOrderRequest) returns (OrderResponse);
//   rpc StreamOrders (StreamOrdersRequest) returns (stream OrderResponse);
// }

// gRPC server implementation (Spring Boot 3.x with grpc-spring-boot-starter)
@GrpcService
public class OrderGrpcService extends OrderServiceGrpc.OrderServiceImplBase {

    private final OrderRepository orderRepository;

    @Override
    public void getOrder(GetOrderRequest request, StreamObserver<OrderResponse> observer) {
        orderRepository.findById(request.getOrderId())
            .ifPresentOrElse(
                order -> {
                    OrderResponse response = OrderResponse.newBuilder()
                        .setOrderId(order.getId())
                        .setStatus(order.getStatus().name())
                        .setTotalAmount(order.getTotalAmount().doubleValue())
                        .build();
                    observer.onNext(response);
                    observer.onCompleted();
                },
                () -> observer.onError(Status.NOT_FOUND
                    .withDescription("Order not found: " + request.getOrderId())
                    .asRuntimeException())
            );
    }
}

// Kafka async messaging "” producer
@Service
public class OrderEventProducer {

    private final KafkaTemplate<String, OrderEvent> kafkaTemplate;

    public void publishOrderPlaced(Order order) {
        OrderEvent event = new OrderEvent(
            order.getId(),
            "ORDER_PLACED",
            order.getCustomerId(),
            order.getTotalAmount(),
            Instant.now()
        );
        kafkaTemplate.send("order-events", order.getId(), event)
            .whenComplete((result, ex) -> {
                if (ex != null) {
                    log.error("Failed to publish order event for {}", order.getId(), ex);
                } else {
                    log.info("Published order event, offset: {}",
                        result.getRecordMetadata().offset());
                }
            });
    }
}

// Kafka consumer "” notification service
@Component
public class OrderEventConsumer {

    private final EmailService emailService;

    @KafkaListener(
        topics = "order-events",
        groupId = "notification-service",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void handleOrderPlaced(
            @Payload OrderEvent event,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset) {

        log.info("Received order event {} from partition {} offset {}",
            event.getOrderId(), partition, offset);

        if ("ORDER_PLACED".equals(event.getEventType())) {
            emailService.sendOrderConfirmation(event.getCustomerId(), event.getOrderId());
        }
        // Idempotency: check if already processed this orderId
    }
}
```

**Follow-up Questions:**
1. How do you ensure exactly-once message processing with Kafka?
2. What is the "dual write problem" and how do the Outbox pattern solve it?
3. When would you use request-reply over messaging vs direct synchronous calls?

**Common Mistakes:**
- Using synchronous REST calls in a chain of 5+ services "” cascading failures and high latency
- Not handling idempotency in Kafka consumers "” duplicate message processing corrupts data

**Interview Traps:**
- gRPC is NOT always better than REST "” gRPC lacks browser support, harder to debug, requires proto toolchain adoption across all teams
- "Async is always more resilient" "” only true if you handle message loss, duplicates, and out-of-order delivery correctly

**Quick Revision (1-liner):**
Use synchronous REST/gRPC when immediate response is needed; use async messaging when temporal decoupling, fan-out, or load leveling is more important.

---

### Topic 5: Circuit Breaker Pattern
**Difficulty:** Hard | **Frequency:** High | **Companies:** Netflix, Amazon, Uber, Microsoft, PayPal

**Q: Explain the circuit breaker pattern, its three states, and how to implement it with Resilience4j.**

**Short Answer (2-3 sentences):**
A circuit breaker wraps calls to external services and monitors failure rates; when failures exceed a threshold, it "opens" and immediately returns a fallback response without calling the failing service, preventing cascade failures and giving the downstream service time to recover. It transitions through three states: Closed (normal operation), Open (short-circuit, return fallback), and Half-Open (test if service recovered). Resilience4j is the standard Java implementation, replacing the deprecated Netflix Hystrix.

**Deep Explanation:**
**State machine:**

**CLOSED:** Normal operation. Calls pass through. Success/failure metrics tracked in a sliding window (count-based or time-based). When failure rate exceeds `failureRateThreshold` (e.g., 50%), transition to OPEN.

**OPEN:** All calls immediately fail with `CallNotPermittedException` without calling the downstream service. Fallback method invoked. After `waitDurationInOpenState` (e.g., 60s), transition to HALF_OPEN.

**HALF_OPEN:** Allow `permittedNumberOfCallsInHalfOpenState` (e.g., 5) calls through. If success rate is sufficient, transition back to CLOSED. If failures persist, return to OPEN.

**Resilience4j sliding windows:**
- **Count-based:** Last N calls tracked in circular array (O(1) per call)
- **Time-based:** Last N seconds aggregated in epoch-second buckets

**Key configuration parameters:**
- `failureRateThreshold`: % failures to open circuit (default 50%)
- `slowCallRateThreshold`: % slow calls to open circuit
- `slowCallDurationThreshold`: duration considered "slow"
- `minimumNumberOfCalls`: minimum calls before evaluating failure rate
- `waitDurationInOpenState`: time before attempting recovery

**Resilience4j vs Hystrix:**
- Hystrix: thread pool isolation (separate thread per dependency), bulkhead via thread pools
- Resilience4j: semaphore-based, lightweight, composable decorators, reactive support

**Real-World Example:**
Netflix introduced Hystrix after the 2012 outage where a slow Cassandra cluster caused thread pool exhaustion across 30+ services. Each service wrapped external calls in Hystrix commands with thread pool isolation. When a circuit opened, cached/degraded responses were served "” users saw slightly stale data instead of errors. Amazon Prime Video uses Resilience4j with time-based sliding windows for their streaming manifest service.

**Code Example:**
```java
// Resilience4j Circuit Breaker "” Full Working Example
// Dependencies: resilience4j-spring-boot3, resilience4j-reactor

// application.yml configuration
// resilience4j:
//   circuitbreaker:
//     instances:
//       inventory-service:
//         registerHealthIndicator: true
//         slidingWindowType: COUNT_BASED
//         slidingWindowSize: 10
//         minimumNumberOfCalls: 5
//         permittedNumberOfCallsInHalfOpenState: 3
//         automaticTransitionFromOpenToHalfOpenEnabled: true
//         waitDurationInOpenState: 10s
//         failureRateThreshold: 50
//         slowCallRateThreshold: 80
//         slowCallDurationThreshold: 2s
//         recordExceptions:
//           - java.io.IOException
//           - java.util.concurrent.TimeoutException
//           - feign.FeignException
//         ignoreExceptions:
//           - com.example.exceptions.BusinessException

@Service
public class InventoryService {

    private final InventoryClient inventoryClient;
    private final CircuitBreakerRegistry circuitBreakerRegistry;

    // Annotation-based circuit breaker
    @CircuitBreaker(name = "inventory-service", fallbackMethod = "getInventoryFallback")
    @Retry(name = "inventory-service")
    @TimeLimiter(name = "inventory-service")
    public CompletableFuture<InventoryResponse> getInventory(String productId) {
        return CompletableFuture.supplyAsync(() ->
            inventoryClient.checkStock(productId));
    }

    // Fallback method "” must have same signature + Throwable parameter
    public CompletableFuture<InventoryResponse> getInventoryFallback(
            String productId, Throwable throwable) {
        log.warn("Circuit breaker fallback for productId: {}, cause: {}",
            productId, throwable.getMessage());
        // Return cached/default response
        return CompletableFuture.completedFuture(
            InventoryResponse.unknown(productId));
    }

    // Programmatic circuit breaker for more control
    public InventoryResponse getInventoryProgrammatic(String productId) {
        CircuitBreaker circuitBreaker = circuitBreakerRegistry
            .circuitBreaker("inventory-service");

        // Register state transition listeners
        circuitBreaker.getEventPublisher()
            .onStateTransition(event ->
                log.info("Circuit breaker state transition: {} -> {}",
                    event.getStateTransition().getFromState(),
                    event.getStateTransition().getToState()))
            .onCallNotPermitted(event ->
                metrics.increment("circuit_breaker.rejected"));

        Supplier<InventoryResponse> decoratedSupplier = CircuitBreaker
            .decorateSupplier(circuitBreaker,
                () -> inventoryClient.checkStock(productId));

        return Try.ofSupplier(decoratedSupplier)
            .recover(CallNotPermittedException.class,
                ex -> InventoryResponse.unknown(productId))
            .recover(Exception.class,
                ex -> {
                    log.error("Inventory service call failed", ex);
                    return InventoryResponse.unknown(productId);
                })
            .get();
    }
}

// Circuit breaker health indicator (exposes to /actuator/health)
// Spring Boot auto-configures this when registerHealthIndicator: true
// {
//   "circuitBreakers": {
//     "inventory-service": {
//       "status": "UP",
//       "details": {
//         "failureRate": "0.0%",
//         "slowCallRate": "0.0%",
//         "state": "CLOSED"
//       }
//     }
//   }
// }
```

**Follow-up Questions:**
1. How does Resilience4j handle slow calls vs failed calls differently?
2. What is the difference between circuit breaker and retry "” can you combine them and in what order?
3. How would you implement a circuit breaker without a library (state machine from scratch)?

**Common Mistakes:**
- Wrapping every exception in the circuit breaker "” `BusinessException` (e.g., "product not found") should be ignored, not counted as failure
- Setting `minimumNumberOfCalls` too low "” circuit opens on 1 failure out of 2 calls during startup

**Interview Traps:**
- Resilience4j circuit breaker is per-instance by default, not shared across JVM instances "” in a multi-pod deployment, each pod has its own circuit breaker state; Redis-backed distributed circuit breaking requires custom implementation
- "Circuit breaker prevents all failures" "” it only prevents cascading failures; the root cause (slow downstream) still needs fixing

**Quick Revision (1-liner):**
Circuit breaker monitors failure rates and short-circuits calls to failing services (Open state), recovering via Half-Open probing to prevent cascade failures.

---


---

### Topic 6: Saga Pattern
**Difficulty:** Hard | **Frequency:** High | **Companies:** Amazon, Uber, Netflix, Booking.com, Airbnb

**Q: How does the Saga pattern manage distributed transactions, and when would you choose choreography vs orchestration?**

**Short Answer (2-3 sentences):**
The Saga pattern manages long-running distributed transactions by breaking them into a sequence of local transactions, each publishing an event or message to trigger the next step, with compensating transactions to undo completed steps on failure. Choreography uses events for decentralized coordination (no central controller), while orchestration uses a central saga orchestrator that explicitly tells each service what to do. Choose choreography for simple, linear flows and orchestration for complex workflows requiring explicit state management.

**Deep Explanation:**
**Problem:** Microservices cannot use ACID distributed transactions across service boundaries (no two-phase commit in microservices "” too slow, too coupled).

**Saga solution:** A sequence of local transactions. Each service commits locally and publishes an event. If a step fails, compensating transactions (semantic undo) execute in reverse order.

**Choreography:**
- Services subscribe to events and react autonomously
- No central coordinator
- Pros: loose coupling, simple for linear workflows
- Cons: hard to track overall saga state, complex failure scenarios, "what step are we on?" is distributed across services

**Orchestration:**
- Central orchestrator (saga orchestrator service or workflow engine) sends commands to each service
- Orchestrator tracks state explicitly (often persisted to DB)
- Pros: centralized state visibility, easier error handling, explicit control flow
- Cons: orchestrator becomes coupling point, risk of "fat orchestrator" with business logic

**Compensating transactions are NOT rollbacks:** They're semantic undos that may leave audit trails (e.g., "payment refunded" not "payment deleted").

**Real-World Example:**
Amazon's order fulfillment is a classic saga: ReserveInventory â†’ ChargPayment â†’ UpdateLoyaltyPoints â†’ ScheduleShipping. If ShipOrder fails, compensating transactions fire: UnscheduleShipping â†’ ReversePoints â†’ RefundPayment â†’ ReleaseInventory. Uber's trip booking uses an orchestration-based saga via Cadence (now Temporal) workflow engine to manage driver assignment, payment authorization, and surge pricing atomically.

**Code Example:**
```java
// Orchestration Saga using Spring State Machine / manual orchestrator

// Saga state enum
public enum OrderSagaState {
    STARTED, INVENTORY_RESERVED, PAYMENT_CHARGED,
    LOYALTY_UPDATED, ORDER_COMPLETED,
    INVENTORY_RESERVATION_FAILED, PAYMENT_FAILED,
    COMPENSATING, COMPENSATED
}

// Saga orchestrator
@Service
@Slf4j
public class OrderSagaOrchestrator {

    private final InventoryClient inventoryClient;
    private final PaymentClient paymentClient;
    private final LoyaltyClient loyaltyClient;
    private final SagaRepository sagaRepository;

    @Transactional
    public void startOrderSaga(Order order) {
        OrderSaga saga = new OrderSaga(order.getId(), OrderSagaState.STARTED);
        sagaRepository.save(saga);

        try {
            // Step 1: Reserve inventory
            inventoryClient.reserve(order.getProductId(), order.getQuantity());
            saga.setState(OrderSagaState.INVENTORY_RESERVED);
            sagaRepository.save(saga);

            // Step 2: Charge payment
            String paymentId = paymentClient.charge(order.getCustomerId(), order.getAmount());
            saga.setPaymentId(paymentId);
            saga.setState(OrderSagaState.PAYMENT_CHARGED);
            sagaRepository.save(saga);

            // Step 3: Update loyalty points
            loyaltyClient.addPoints(order.getCustomerId(), calculatePoints(order));
            saga.setState(OrderSagaState.LOYALTY_UPDATED);

            order.setStatus(OrderStatus.CONFIRMED);
            saga.setState(OrderSagaState.ORDER_COMPLETED);
            sagaRepository.save(saga);

        } catch (PaymentException e) {
            log.error("Payment failed for order {}, compensating...", order.getId());
            compensateAfterPaymentFailure(saga, order);
        } catch (Exception e) {
            log.error("Saga failed for order {}", order.getId(), e);
            compensate(saga, order);
        }
    }

    private void compensateAfterPaymentFailure(OrderSaga saga, Order order) {
        saga.setState(OrderSagaState.COMPENSATING);
        // Only need to undo inventory reservation (payment never succeeded)
        try {
            inventoryClient.release(order.getProductId(), order.getQuantity());
        } catch (Exception e) {
            log.error("Compensation failed! Manual intervention required for order {}",
                order.getId(), e);
            // Alert operations team - this is now an inconsistency
        }
        saga.setState(OrderSagaState.COMPENSATED);
        sagaRepository.save(saga);
    }
}

// Choreography Saga using Spring Events / Kafka
@Service
public class InventoryService {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    @KafkaListener(topics = "order-created")
    public void handleOrderCreated(OrderCreatedEvent event) {
        try {
            reserveInventory(event.getOrderId(), event.getProductId(), event.getQuantity());
            // Publish success event "” PaymentService will pick this up
            kafkaTemplate.send("inventory-reserved",
                new InventoryReservedEvent(event.getOrderId(), event.getProductId()));
        } catch (InsufficientStockException e) {
            // Publish failure event "” triggers compensation upstream
            kafkaTemplate.send("inventory-reservation-failed",
                new InventoryReservationFailedEvent(event.getOrderId(), e.getMessage()));
        }
    }

    @KafkaListener(topics = "payment-failed")
    public void handlePaymentFailed(PaymentFailedEvent event) {
        // Compensating transaction: release reserved inventory
        releaseInventory(event.getOrderId());
        kafkaTemplate.send("inventory-released",
            new InventoryReleasedEvent(event.getOrderId()));
    }
}
```

**Follow-up Questions:**
1. How do you handle a failing compensating transaction (compensation itself fails)?
2. What is the "semantic lock" pattern and how does it prevent dirty reads in sagas?
3. How does Temporal/Cadence differ from implementing sagas manually?

**Common Mistakes:**
- Treating compensating transactions as database rollbacks "” they are semantic undos and may not fully restore previous state
- Not persisting saga state "” if the orchestrator crashes mid-saga, you need to resume from the last known state

**Interview Traps:**
- Sagas provide ACD (Atomicity via compensation, Consistency eventual, Durability) but NOT isolation "” intermediate states are visible to other transactions (use countermeasures like semantic locks)
- "Orchestration is always better than choreography" "” choreography is simpler and more decoupled for straightforward linear flows

**Quick Revision (1-liner):**
Saga pattern handles distributed transactions via local transactions + compensating transactions; orchestration uses central coordinator, choreography uses event-driven reactions.

---

### Topic 7: Event-Driven Architecture
**Difficulty:** Hard | **Frequency:** High | **Companies:** LinkedIn, Netflix, Airbnb, Confluent, Stripe

**Q: What is Event Sourcing and CQRS, and when would you use them in a microservices architecture?**

**Short Answer (2-3 sentences):**
Event Sourcing stores state as an immutable sequence of events (the "source of truth") rather than current state "” the current state is derived by replaying events. CQRS (Command Query Responsibility Segregation) separates read models from write models, allowing each to be optimized independently. Together, they enable audit logs, temporal queries, and scalable read replicas, but add significant complexity that's only justified for complex domains with audit requirements or high read/write asymmetry.

**Deep Explanation:**
**Event Sourcing:**
- Every state change is persisted as an immutable event: `OrderPlaced`, `ItemAdded`, `OrderShipped`
- Current state derived by replaying all events (or from snapshot + recent events)
- Event store is append-only "” no UPDATE/DELETE
- Benefits: complete audit trail, temporal queries ("what was the state at T?"), event replay for new projections
- Challenges: eventual consistency of projections, event schema evolution, snapshot management

**CQRS:**
- **Command side:** Handles writes; validates business rules; emits domain events; optimized for consistency
- **Query side:** Handles reads; maintains denormalized read models (projections) updated via event subscription; optimized for query performance
- Enables polyglot persistence: write to PostgreSQL, read from Elasticsearch

**Event Store:**
- Append-only log of domain events
- EventStoreDB is purpose-built; Kafka or PostgreSQL (with event table) commonly used
- Events must be versioned for schema evolution

**Eventual consistency:** Projections are updated asynchronously "” brief window where read model lags write model. Acceptable for most use cases; problematic for read-your-own-writes.

**Real-World Example:**
LinkedIn's activity feed uses event sourcing "” every "like", "comment", "connection" is an event. The feed projection is built by replaying relevant events. When they added new feed features, they replayed historical events through new projection handlers. Axon Framework (Java) provides full event sourcing + CQRS infrastructure.

**Code Example:**
```java
// Event Sourcing + CQRS with Axon Framework (Spring Boot 3.x)

// Domain Events (immutable records)
public record OrderPlacedEvent(
    String orderId,
    String customerId,
    List<OrderItem> items,
    BigDecimal totalAmount,
    Instant occurredAt
) {}

public record OrderShippedEvent(
    String orderId,
    String trackingNumber,
    Instant shippedAt
) {}

// Aggregate (command side "” enforces business rules)
@Aggregate
public class OrderAggregate {

    @AggregateIdentifier
    private String orderId;
    private OrderStatus status;
    private String customerId;
    private BigDecimal totalAmount;

    // Constructor handles CreateOrderCommand
    @CommandHandler
    public OrderAggregate(PlaceOrderCommand command) {
        // Validate business rules before emitting event
        if (command.items().isEmpty()) {
            throw new IllegalArgumentException("Order must have at least one item");
        }
        // Apply event "” this is the ONLY way to change state
        AggregateLifecycle.apply(new OrderPlacedEvent(
            command.orderId(),
            command.customerId(),
            command.items(),
            command.totalAmount(),
            Instant.now()
        ));
    }

    @CommandHandler
    public void handle(ShipOrderCommand command) {
        if (status != OrderStatus.CONFIRMED) {
            throw new IllegalStateException("Can only ship confirmed orders");
        }
        AggregateLifecycle.apply(new OrderShippedEvent(
            this.orderId, command.trackingNumber(), Instant.now()));
    }

    // Event sourcing handlers "” reconstruct state from events
    @EventSourcingHandler
    public void on(OrderPlacedEvent event) {
        this.orderId = event.orderId();
        this.customerId = event.customerId();
        this.totalAmount = event.totalAmount();
        this.status = OrderStatus.PENDING;
    }

    @EventSourcingHandler
    public void on(OrderShippedEvent event) {
        this.status = OrderStatus.SHIPPED;
    }
}

// Query side "” projection (read model)
@Component
@ProcessingGroup("order-projections")
public class OrderProjection {

    private final OrderSummaryRepository repository;

    @EventHandler
    public void on(OrderPlacedEvent event) {
        OrderSummary summary = new OrderSummary(
            event.orderId(),
            event.customerId(),
            event.totalAmount(),
            OrderStatus.PENDING,
            event.occurredAt()
        );
        repository.save(summary);
    }

    @EventHandler
    public void on(OrderShippedEvent event) {
        repository.findById(event.orderId())
            .ifPresent(summary -> {
                summary.setStatus(OrderStatus.SHIPPED);
                summary.setShippedAt(event.shippedAt());
                repository.save(summary);
            });
    }

    // Query handler
    @QueryHandler
    public OrderSummary handle(GetOrderQuery query) {
        return repository.findById(query.orderId())
            .orElseThrow(() -> new OrderNotFoundException(query.orderId()));
    }
}

// Command gateway usage
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final CommandGateway commandGateway;
    private final QueryGateway queryGateway;

    @PostMapping
    public CompletableFuture<String> placeOrder(@RequestBody PlaceOrderRequest request) {
        String orderId = UUID.randomUUID().toString();
        return commandGateway.send(new PlaceOrderCommand(orderId,
            request.customerId(), request.items(), request.totalAmount()));
    }

    @GetMapping("/{orderId}")
    public CompletableFuture<OrderSummary> getOrder(@PathVariable String orderId) {
        return queryGateway.query(new GetOrderQuery(orderId),
            ResponseTypes.instanceOf(OrderSummary.class));
    }
}
```

**Follow-up Questions:**
1. How do you handle event schema evolution "” what happens when you add a field to an event?
2. What is a snapshot in event sourcing and when should you use it?
3. How do you implement "read your own writes" consistency with CQRS?

**Common Mistakes:**
- Using event sourcing for every service "” it's only justified for domains requiring audit trails or complex event replay; simple CRUD services don't need it
- Treating events as internal implementation details "” domain events are API contracts and must be versioned carefully

**Interview Traps:**
- Event sourcing â‰  event-driven architecture "” you can have EDA without event sourcing (just publish events from state-based storage)
- CQRS does not require event sourcing, and event sourcing does not require CQRS "” they complement each other but are independent patterns

**Quick Revision (1-liner):**
Event Sourcing stores state as immutable event log; CQRS separates write/read models "” together they enable audit logs, temporal queries, and scalable reads.

---

### Topic 8: Distributed Tracing
**Difficulty:** Medium | **Frequency:** High | **Companies:** Google, Netflix, Uber, Twitter, Datadog

**Q: How do you implement distributed tracing across microservices, and what is the role of correlation IDs and OpenTelemetry?**

**Short Answer (2-3 sentences):**
Distributed tracing tracks a request as it flows through multiple microservices by propagating a trace context (trace ID + span ID) via HTTP headers, allowing you to reconstruct the full call graph and identify latency bottlenecks. OpenTelemetry (OTel) is the CNCF standard for collecting traces, metrics, and logs with vendor-neutral instrumentation. Spring Boot 3.x integrates via Micrometer Tracing, which auto-instruments HTTP calls and exports to Zipkin or Jaeger.

**Deep Explanation:**
**Core concepts:**
- **Trace:** End-to-end journey of a request across all services (shared `traceId`)
- **Span:** A single unit of work within a trace (service A â†’ service B is one span). Has start/end time, tags, logs, parent span ID
- **Context propagation:** Trace context passed via HTTP headers (`traceparent` in W3C standard, `X-B3-TraceId` in Zipkin B3 format)
- **Sampling:** Not every request traced (100% sampling too expensive); head-based (decide at trace start) vs tail-based (decide after seeing full trace)

**OpenTelemetry architecture:**
1. **Instrumentation libraries** "” auto-instrument HTTP clients, Kafka, JDBC, Redis
2. **SDK** "” collects and batches telemetry
3. **OTel Collector** "” receives, processes, exports to backends (Jaeger, Zipkin, Datadog, Tempo)
4. **Propagators** "” inject/extract context from carriers (HTTP headers, Kafka headers)

**Spring Boot 3.x + Micrometer Tracing:**
- Auto-configures tracing via `spring-boot-starter-actuator` + `micrometer-tracing-bridge-otel`
- MDC integration: `traceId` automatically added to log entries (correlate logs with traces)
- `@Observed` annotation for custom spans

**Real-World Example:**
Google's Dapper (2010) was the original distributed tracing system, inspiring Zipkin and Jaeger. At Google scale, they sample ~0.01% of traces but use tail-based sampling to always capture slow/error traces. Uber's Jaeger handles ~1 billion spans/day, using adaptive sampling that increases trace rate for error-prone services automatically.

**Code Example:**
```java
// Spring Boot 3.x Distributed Tracing with OpenTelemetry
// Dependencies:
// - spring-boot-starter-actuator
// - micrometer-tracing-bridge-otel
// - opentelemetry-exporter-zipkin (or jaeger)

// application.yml
// management:
//   tracing:
//     sampling:
//       probability: 1.0  # 100% for dev; 0.1 for prod
// spring:
//   application:
//     name: order-service

@Configuration
public class TracingConfig {

    // Custom span with business context
    @Bean
    public ObservationRegistry observationRegistry() {
        return ObservationRegistry.create();
    }
}

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final OrderService orderService;
    private final ObservationRegistry observationRegistry;

    @PostMapping
    public ResponseEntity<Order> placeOrder(@RequestBody OrderRequest request) {
        // Create custom span with business attributes
        return Observation.createNotStarted("order.placement", observationRegistry)
            .lowCardinalityKeyValue("payment.method", request.getPaymentMethod())
            .highCardinalityKeyValue("customer.id", request.getCustomerId())
            .observe(() -> {
                Order order = orderService.placeOrder(request);
                return ResponseEntity.ok(order);
            });
    }
}

@Service
public class OrderService {

    private final InventoryClient inventoryClient;
    private final Tracer tracer;  // Micrometer Tracer

    @Observed(name = "order.inventory.check", contextualName = "checking-inventory")
    public void checkInventory(String productId, int quantity) {
        // This method automatically creates a child span
        inventoryClient.reserve(productId, quantity);
    }

    public Order placeOrder(OrderRequest request) {
        // Current trace context automatically propagated via HTTP headers
        // when using @LoadBalanced RestClient or WebClient

        // Manual span creation for fine-grained tracing
        Span span = tracer.nextSpan().name("validate-order").start();
        try (Tracer.SpanInScope ws = tracer.withSpan(span)) {
            span.tag("order.items.count", String.valueOf(request.getItems().size()));
            validateOrder(request);
        } finally {
            span.end();
        }

        checkInventory(request.getProductId(), request.getQuantity());
        return saveOrder(request);
    }
}

// Trace context propagation via HTTP headers is automatic with:
// @LoadBalanced RestClient / WebClient (Spring Cloud)
// The W3C traceparent header is injected automatically:
// traceparent: 00-{traceId}-{spanId}-01

// Kafka trace propagation
@Component
public class OrderEventProducer {

    private final KafkaTemplate<String, OrderEvent> kafkaTemplate;
    private final Tracer tracer;

    public void publishOrderPlaced(Order order) {
        OrderEvent event = new OrderEvent(order);
        // Inject trace context into Kafka headers
        ProducerRecord<String, OrderEvent> record =
            new ProducerRecord<>("order-events", order.getId(), event);

        // OTel Kafka instrumentation auto-propagates trace headers
        // Header: traceparent injected automatically with micrometer-tracing

        kafkaTemplate.send(record);
    }
}

// Log correlation "” traceId automatically in MDC
// Log format: 2024-01-15 10:30:00 INFO [order-service,abc123def456,span789] OrderService - Order placed
// logback-spring.xml pattern: %d [%X{traceId},%X{spanId}] %level %logger - %msg
```

**Follow-up Questions:**
1. What is the difference between head-based and tail-based sampling, and when would you choose each?
2. How do you propagate trace context through asynchronous operations (CompletableFuture, @Async)?
3. How would you correlate distributed traces with application logs in production?

**Common Mistakes:**
- Using 100% sampling in production "” at high throughput this overwhelms trace storage; use probabilistic sampling with tail-based exceptions for errors
- Not propagating trace context through message queues "” async hops break the trace chain without explicit header injection

**Interview Traps:**
- Zipkin and Jaeger both support OpenTelemetry but have different native data models "” B3 propagation (Zipkin) vs W3C traceparent are both common and sometimes mixed
- `X-Correlation-Id` (custom header) â‰  distributed tracing "” correlation IDs are a simpler form of request tracking but lack span hierarchy and timing information

**Quick Revision (1-liner):**
Distributed tracing propagates traceId/spanId across service boundaries via headers, enabling full request graph reconstruction; OpenTelemetry + Micrometer is the modern Java standard.

---

### Topic 9: Resilience Patterns
**Difficulty:** Hard | **Frequency:** High | **Companies:** Netflix, Amazon, Google, Microsoft Azure, Twilio

**Q: Explain the retry with exponential backoff, bulkhead, and rate limiter patterns and their Resilience4j implementations.**

**Short Answer (2-3 sentences):**
Resilience4j provides composable fault-tolerance decorators: Retry (retry failed calls with configurable backoff), Bulkhead (limit concurrent calls to prevent resource exhaustion), RateLimiter (control request rate to downstream), and TimeLimiter (timeout long-running calls). These patterns are typically composed together "” retry wraps circuit breaker wraps bulkhead "” with the order mattering for correct behavior. The goal is to make services self-healing and prevent resource exhaustion from propagating through the system.

**Deep Explanation:**
**Retry with exponential backoff + jitter:**
- Exponential backoff: wait 1s, 2s, 4s, 8s... between retries
- Jitter: random Â±variation to prevent "thundering herd" "” all retried requests hitting downstream simultaneously
- Only retry on transient failures (network timeouts, 503); never retry on 400 (client error) or 409 (conflict)
- `maxAttempts`: total attempts including first; `waitDuration`: initial wait; `multiplier`: exponential factor

**Bulkhead (resource isolation):**
- **Semaphore-based:** Limits concurrent calls using a semaphore; lightweight, same thread
- **Thread-pool based:** Separate thread pool per dependency; fully isolates failures; heavier resource use
- Prevents one slow dependency from consuming all threads/connections

**Rate Limiter:**
- Controls rate of calls from this service TO downstream
- `limitForPeriod`: permits per refresh period
- `limitRefreshPeriod`: window size
- `timeoutDuration`: how long to wait for a permit
- Different from API Gateway rate limiting (which controls inbound requests)

**TimeLimiter:**
- Wraps `CompletableFuture` calls with timeout
- Cancels future on timeout
- Always combine with circuit breaker "” repeated timeouts open the circuit

**Composition order (Resilience4j recommended):**
`Retry(CircuitBreaker(RateLimiter(TimeLimiter(Bulkhead(function)))))`
- TimeLimiter inside CircuitBreaker: timeouts count as failures toward circuit
- Retry outside CircuitBreaker: retries respect open circuit

**Real-World Example:**
AWS SDK implements exponential backoff with jitter for all API calls. DynamoDB SDK retries on `ProvisionedThroughputExceededException` with full jitter "” random value between 0 and calculated backoff time. Netflix Hystrix (precursor to Resilience4j) used thread-pool bulkheads "” 10 threads for PaymentService, 20 for InventoryService "” ensuring PaymentService slowdowns couldn't exhaust InventoryService capacity.

**Code Example:**
```java
// Resilience4j "” Complete Retry + Bulkhead + RateLimiter example
// application.yml:
// resilience4j:
//   retry:
//     instances:
//       payment-service:
//         maxAttempts: 3
//         waitDuration: 500ms
//         enableExponentialBackoff: true
//         exponentialBackoffMultiplier: 2
//         randomizedWaitFactor: 0.5  # jitter Â±50%
//         retryExceptions:
//           - java.io.IOException
//           - java.net.ConnectException
//           - feign.RetryableException
//         ignoreExceptions:
//           - com.example.PaymentDeclinedException
//   bulkhead:
//     instances:
//       payment-service:
//         maxConcurrentCalls: 10
//         maxWaitDuration: 100ms
//   ratelimiter:
//     instances:
//       payment-service:
//         limitForPeriod: 50
//         limitRefreshPeriod: 1s
//         timeoutDuration: 500ms
//   timelimiter:
//     instances:
//       payment-service:
//         timeoutDuration: 3s
//         cancelRunningFuture: true

@Service
public class PaymentService {

    // Annotation-based composition
    @CircuitBreaker(name = "payment-service", fallbackMethod = "paymentFallback")
    @Retry(name = "payment-service", fallbackMethod = "paymentFallback")
    @Bulkhead(name = "payment-service", type = Bulkhead.Type.SEMAPHORE)
    @RateLimiter(name = "payment-service")
    @TimeLimiter(name = "payment-service")
    public CompletableFuture<PaymentResult> processPayment(PaymentRequest request) {
        return CompletableFuture.supplyAsync(() ->
            paymentGatewayClient.charge(request));
    }

    public CompletableFuture<PaymentResult> paymentFallback(
            PaymentRequest request, Throwable t) {
        log.warn("Payment fallback triggered for customer {}: {}",
            request.getCustomerId(), t.getMessage());
        if (t instanceof BulkheadFullException) {
            return CompletableFuture.failedFuture(
                new ServiceUnavailableException("Payment service busy, try again"));
        }
        if (t instanceof RequestNotPermitted) {
            return CompletableFuture.failedFuture(
                new RateLimitException("Too many payment requests"));
        }
        // For circuit open or retry exhausted "” queue for async processing
        return asyncPaymentQueue.enqueue(request)
            .thenApply(queueId -> PaymentResult.queued(queueId));
    }
}

// Programmatic composition with explicit ordering
@Service
public class ResilientPaymentService {

    private final CircuitBreaker circuitBreaker;
    private final Retry retry;
    private final Bulkhead bulkhead;
    private final RateLimiter rateLimiter;
    private final PaymentGatewayClient client;

    public ResilientPaymentService(
            CircuitBreakerRegistry cbRegistry,
            RetryRegistry retryRegistry,
            BulkheadRegistry bulkheadRegistry,
            RateLimiterRegistry rlRegistry,
            PaymentGatewayClient client) {

        this.circuitBreaker = cbRegistry.circuitBreaker("payment-service");
        this.retry = retryRegistry.retry("payment-service");
        this.bulkhead = bulkheadRegistry.bulkhead("payment-service");
        this.rateLimiter = rlRegistry.rateLimiter("payment-service");
        this.client = client;

        // Log retry events
        retry.getEventPublisher().onRetry(event ->
            log.warn("Retry attempt {} for payment due to: {}",
                event.getNumberOfRetryAttempts(), event.getLastThrowable().getMessage()));
    }

    public PaymentResult processPayment(PaymentRequest request) {
        // Composition: Retry > CircuitBreaker > RateLimiter > Bulkhead > function
        Supplier<PaymentResult> supplier = () -> client.charge(request);
        supplier = Bulkhead.decorateSupplier(bulkhead, supplier);
        supplier = RateLimiter.decorateSupplier(rateLimiter, supplier);
        supplier = CircuitBreaker.decorateSupplier(circuitBreaker, supplier);
        supplier = Retry.decorateSupplier(retry, supplier);

        return Try.ofSupplier(supplier)
            .recover(ex -> handlePaymentError(request, ex))
            .get();
    }
}
```

**Follow-up Questions:**
1. In what order should you compose Retry and CircuitBreaker decorators, and why does order matter?
2. How is a semaphore bulkhead different from a thread pool bulkhead? When would you use each?
3. What is the "thundering herd" problem and how does jitter in exponential backoff solve it?

**Common Mistakes:**
- Retrying non-idempotent operations (POST /payments) "” duplicate charges; only retry idempotent operations or use idempotency keys
- Setting retry count too high with short backoff "” amplifies load on an already struggling downstream service

**Interview Traps:**
- Rate limiter in Resilience4j controls the rate this service makes OUTBOUND calls, not inbound traffic "” use Spring Cloud Gateway for inbound rate limiting
- `@Retry` without `@CircuitBreaker` will retry even when the circuit is open "” always pair them, with circuit breaker inside retry

**Quick Revision (1-liner):**
Retry+backoff+jitter prevents thundering herd, bulkhead isolates resources per dependency, rate limiter controls outbound call rate "” compose them in order: Retry > CircuitBreaker > RateLimiter > Bulkhead.

---

### Topic 10: Service Mesh
**Difficulty:** Hard | **Frequency:** Medium | **Companies:** Google, Lyft, Netflix, Red Hat, HashiCorp

**Q: What is a service mesh, how does the sidecar proxy pattern work, and what does Istio provide that Resilience4j doesn't?**

**Short Answer (2-3 sentences):**
A service mesh is infrastructure layer that handles service-to-service communication via sidecar proxies (e.g., Envoy) deployed alongside each service pod, transparently handling mTLS, retries, circuit breaking, load balancing, and observability without any application code changes. Istio is the most popular service mesh, using Envoy sidecar proxies controlled by its control plane (istiod). The key difference from Resilience4j is that service mesh operates at the network/infrastructure level "” configuration changes apply without redeploying services.

**Deep Explanation:**
**Sidecar proxy pattern:**
- Each service pod gets an injected Envoy sidecar container
- All inbound/outbound traffic routes through the sidecar (iptables rules redirect transparently)
- Service code doesn't know the sidecar exists "” no library dependency
- Sidecars report telemetry to control plane

**Istio architecture:**
- **Data plane:** Envoy sidecar proxies (handle traffic)
- **Control plane (istiod):** Distributes configuration to proxies via xDS API
  - Pilot: service discovery and traffic management
  - Citadel: certificate management for mTLS
  - Galley: configuration validation

**mTLS (mutual TLS):**
- Both client and server present certificates
- Certificates issued by Istio's internal CA (Citadel)
- Automatic rotation "” services don't manage certificates
- Encrypts all inter-service traffic; authenticates service identity

**Traffic management:**
- VirtualService: routing rules (canary, A/B, fault injection)
- DestinationRule: load balancing policy, circuit breaking, connection pool settings

**Service Mesh vs Application Libraries (Resilience4j):**
- Mesh: language-agnostic, no code changes, centralized policy, ops team controls
- Libraries: more flexibility, lower latency (no extra hop), can access business context for decisions
- Production recommendation: use both "” mesh for mTLS/observability, library for business-aware resilience

**Real-World Example:**
Lyft created Envoy (now the de-facto sidecar proxy) to solve their polyglot microservices challenge "” Node.js, Python, Go, Java services all needing consistent resilience behavior. Google uses Istio internally across GKE and contributed it to CNCF. Airbnb migrated to a service mesh to enforce mTLS across 1,000+ services without modifying each service's code.

**Code Example:**
```yaml
# Istio VirtualService "” canary deployment (10% to v2)
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: order-service
spec:
  hosts:
    - order-service
  http:
    - match:
        - headers:
            x-canary-user:
              exact: "true"
      route:
        - destination:
            host: order-service
            subset: v2
    - route:
        - destination:
            host: order-service
            subset: v1
          weight: 90
        - destination:
            host: order-service
            subset: v2
          weight: 10
---
# DestinationRule "” circuit breaking and mTLS
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: order-service
spec:
  host: order-service
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL  # Enforce mTLS
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 1000
    outlierDetection:  # Circuit breaking at mesh level
      consecutiveGatewayErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
---
# PeerAuthentication "” enforce mTLS namespace-wide
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

```java
// With service mesh, Java service needs NO resilience libraries for network concerns
// The Envoy sidecar handles retries, timeouts, circuit breaking transparently

// Before service mesh (with Resilience4j):
@CircuitBreaker(name = "inventory")
@Retry(name = "inventory")
@TimeLimiter(name = "inventory")
public CompletableFuture<InventoryResponse> checkInventory(String productId) {
    return CompletableFuture.supplyAsync(() -> inventoryClient.check(productId));
}

// After service mesh (Istio handles it at proxy level):
public InventoryResponse checkInventory(String productId) {
    // Simple HTTP call "” Envoy sidecar handles retries, timeouts, circuit breaking
    // VirtualService configures retry policy; DestinationRule configures outlier detection
    return inventoryClient.check(productId);
}
// Business logic remains focused on domain, not infrastructure concerns
```

**Follow-up Questions:**
1. What is the performance overhead of a service mesh sidecar proxy, and how do you measure it?
2. How does Istio's mTLS differ from application-level JWT authentication?
3. When would you choose Linkerd over Istio?

**Common Mistakes:**
- Assuming service mesh replaces all need for application-level resilience "” mesh cannot make business-context-aware decisions (e.g., don't retry payment mutations)
- Enabling mTLS in STRICT mode without validating all services have sidecars "” breaks communication for services without injection

**Interview Traps:**
- Service mesh adds ~1-2ms latency per hop (Envoy sidecar); at thousands of internal RPS this is measurable "” not always acceptable
- Istio's circuit breaking (`outlierDetection`) is host ejection (remove instance from load balancing), not the same as Resilience4j's circuit breaker (stop all calls) "” fundamentally different semantics

**Quick Revision (1-liner):**
Service mesh deploys sidecar proxies alongside each service to transparently handle mTLS, observability, traffic management, and resilience without application code changes.

---


---

### Topic 11: Distributed Configuration
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Netflix, Pivotal, HashiCorp, AWS, Heroku

**Q: How does Spring Cloud Config Server work, and how do you handle secrets management and dynamic property refresh?**

**Short Answer (2-3 sentences):**
Spring Cloud Config Server provides centralized, versioned configuration for microservices by serving properties from a Git repository, Vault, or filesystem backend "” services fetch their config on startup using their `spring.application.name` and active profile. Secrets (passwords, API keys) should never live in Git; instead, use HashiCorp Vault or AWS Secrets Manager, which Config Server can integrate with as a backend. Dynamic refresh via Spring Cloud Bus + `@RefreshScope` allows config changes to propagate to running instances without redeployment.

**Deep Explanation:**
**Spring Cloud Config Server architecture:**
1. Config Server exposes HTTP endpoints (`/application/profile/label`)
2. Services (clients) fetch config at startup via `spring.config.import=configserver:`
3. Config stored in Git (versioned, auditable) or Vault (secrets)
4. Config Server supports encryption/decryption of property values (`{cipher}...`)

**Backends:**
- **Git:** Version history, pull requests for config changes, branch-per-environment
- **HashiCorp Vault:** Dynamic secrets, automatic rotation, fine-grained access policies
- **AWS Secrets Manager / Parameter Store:** Native AWS integration, IAM-based access
- **Consul:** Both service discovery and K/V store for config

**Dynamic refresh:**
- `@RefreshScope` beans are re-created when `/actuator/refresh` POST is called
- **Spring Cloud Bus:** Connects all instances via message broker (Kafka/RabbitMQ); one refresh event fans out to all instances
- **Kubernetes ConfigMap:** Mount as volume; changes detected via inotify; Spring Boot 2.4+ supports config reload without restart

**Security considerations:**
- Never commit secrets to Git
- Use `spring.cloud.config.server.encrypt.key` for symmetric encryption of non-secret sensitive values
- Vault AppRole or Kubernetes auth for secret backend access

**Real-World Example:**
Netflix's Archaius (later replaced by Spring Cloud Config in many services) manages configuration for hundreds of services. When they need to tune circuit breaker thresholds or feature flags without redeployment, they update Git config and trigger a refresh via Spring Cloud Bus. HashiCorp reports that Vault manages secrets for 70% of Fortune 500 companies "” database credentials auto-rotate every 24h.

**Code Example:**
```java
// Config Server setup
@SpringBootApplication
@EnableConfigServer
public class ConfigServerApplication {
    public static void main(String[] args) {
        SpringApplication.run(ConfigServerApplication.class, args);
    }
}

// application.yml for Config Server
// server:
//   port: 8888
// spring:
//   cloud:
//     config:
//       server:
//         git:
//           uri: https://github.com/myorg/config-repo
//           default-label: main
//           search-paths: '{application}'
//           clone-on-start: true
//         vault:
//           host: vault.internal
//           port: 8200
//           authentication: KUBERNETES
//           kubernetes:
//             role: config-server
//   profiles:
//     active: git,vault  # Composite: git for non-secrets, vault for secrets

// Config client (microservice)
// bootstrap.yml (or spring.config.import in application.yml for Spring Boot 3.x):
// spring:
//   application:
//     name: order-service
//   config:
//     import: "configserver:http://config-server:8888"
//   cloud:
//     config:
//       fail-fast: true
//       retry:
//         max-attempts: 6
//         initial-interval: 1000

// Dynamic refresh with @RefreshScope
@RestController
@RefreshScope  // Bean re-created on /actuator/refresh
public class OrderController {

    @Value("${order.max-items-per-order:10}")
    private int maxItemsPerOrder;

    @Value("${order.discount-percentage:0}")
    private double discountPercentage;

    @GetMapping("/config")
    public Map<String, Object> getConfig() {
        return Map.of(
            "maxItemsPerOrder", maxItemsPerOrder,
            "discountPercentage", discountPercentage
        );
    }
}

// Programmatic config refresh "” trigger manually
@Component
public class ConfigRefreshService {

    private final ContextRefresher contextRefresher;

    public Set<String> refreshConfig() {
        // Returns set of changed property keys
        Set<String> changedKeys = contextRefresher.refresh();
        log.info("Config refreshed, changed keys: {}", changedKeys);
        return changedKeys;
    }
}

// Spring Cloud Bus "” auto-broadcast refresh to all instances
// Add dependency: spring-cloud-starter-bus-kafka
// When ANY instance receives POST /actuator/busrefresh,
// it publishes a RefreshRemoteApplicationEvent to Kafka,
// and ALL instances consume it and call contextRefresher.refresh()

// Vault integration "” dynamic database credentials
@Configuration
public class VaultConfig {

    // Spring Cloud Vault auto-renews lease for dynamic credentials
    // application.yml:
    // spring:
    //   cloud:
    //     vault:
    //       database:
    //         enabled: true
    //         role: order-service-db-role
    //         backend: database
    // Vault generates credentials: username=v-order-svc-abc123, password=<random>, TTL=1h
}
```

**Follow-up Questions:**
1. How do you handle config changes that require application restart (e.g., DataSource URL changes)?
2. What is the difference between Spring Cloud Config and Kubernetes ConfigMaps "” when would you use each?
3. How do you prevent a Config Server outage from bringing down all microservices?

**Common Mistakes:**
- Storing database passwords in Git-backed Config Server "” use Vault or Secrets Manager instead; Git repos can be compromised or accidentally made public
- Not configuring `fail-fast: true` "” without it, a service starts with empty/default config if Config Server is unavailable during startup

**Interview Traps:**
- `@RefreshScope` does NOT work for `@Configuration` classes or beans that inject `@Value` in constructors "” only field injection with `@RefreshScope` on the bean itself works
- Spring Cloud Config Server is a single point of failure unless you run it in HA mode with a replicated Git clone and load balancer in front

**Quick Revision (1-liner):**
Spring Cloud Config serves versioned config from Git/Vault; @RefreshScope + Spring Cloud Bus enables zero-downtime config updates across all service instances.

---

### Topic 12: Health Checks & Readiness Probes
**Difficulty:** Easy | **Frequency:** High | **Companies:** All Kubernetes shops, AWS, Google Cloud, Netflix

**Q: Explain the difference between liveness and readiness probes in Kubernetes, and how does Spring Boot Actuator support them?**

**Short Answer (2-3 sentences):**
A liveness probe tells Kubernetes if the application is alive "” if it fails, Kubernetes restarts the container. A readiness probe tells Kubernetes if the application is ready to receive traffic "” if it fails, Kubernetes removes the pod from the Service endpoints without restarting it. Spring Boot Actuator 2.3+ exposes `/actuator/health/liveness` and `/actuator/health/readiness` endpoints that map directly to these Kubernetes probe types.

**Deep Explanation:**
**Liveness probe (`/actuator/health/liveness` â†’ `LivenessStateHealthIndicator`):**
- Maps to `ApplicationAvailability.LivenessState` (CORRECT / BROKEN)
- Fails when the application is in an unrecoverable state "” deadlock, OOM, corrupted state
- Kubernetes response: restart the container (potentially losing in-flight requests)
- Should be lenient "” only fail for truly unrecoverable conditions, not transient issues

**Readiness probe (`/actuator/health/readiness` â†’ `ReadinessStateHealthIndicator`):**
- Maps to `ApplicationAvailability.ReadinessState` (ACCEPTING_TRAFFIC / REFUSING_TRAFFIC)
- Fails during startup (Spring context loading), graceful shutdown, or when a critical dependency is down
- Kubernetes response: remove pod from Service endpoint slice (stop sending new traffic)
- Should be strict "” fail if database connection pool exhausted, Kafka consumer group rebalancing

**Custom health indicators:**
- Implement `HealthIndicator` interface for `UP/DOWN/OUT_OF_SERVICE/UNKNOWN` status
- Aggregate health: any `DOWN` component makes overall status `DOWN`
- `management.endpoint.health.show-details=always` for full component details

**Startup probe:**
- Third probe type for slow-starting applications
- Disables liveness/readiness until startup probe succeeds
- Prevents Kubernetes from killing a slow-starting container as "unhealthy"

**Graceful shutdown:**
- Spring Boot `server.shutdown=graceful` drains in-flight requests before stopping
- Actuator sets readiness to `REFUSING_TRAFFIC` before container stop
- Kubernetes `terminationGracePeriodSeconds` must be > Spring's `spring.lifecycle.timeout-per-shutdown-phase`

**Real-World Example:**
A common production incident: liveness probe timeout too short causes Kubernetes to restart pods under GC pressure (GC pause > probe timeout). Netflix learned to set liveness probe `timeoutSeconds: 5` and `failureThreshold: 3` "” requiring 3 consecutive failures before restart. Google SRE recommends readiness probe paths that verify the critical path (database reachable) but not ancillary systems (monitoring agent).

**Code Example:**
```java
// Spring Boot 3.x Health Check configuration
// application.yml:
// management:
//   endpoint:
//     health:
//       probes:
//         enabled: true
//       show-details: always
//       group:
//         readiness:
//           include: readiness, db, redis, kafka
//         liveness:
//           include: liveness, diskSpace
//   endpoints:
//     web:
//       exposure:
//         include: health, info, metrics, prometheus
//   health:
//     livenessstate:
//       enabled: true
//     readinessstate:
//       enabled: true
//
// server:
//   shutdown: graceful
// spring:
//   lifecycle:
//     timeout-per-shutdown-phase: 30s

// Custom health indicator
@Component
public class DatabaseHealthIndicator implements HealthIndicator {

    private final DataSource dataSource;

    @Override
    public Health health() {
        try (Connection conn = dataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT 1")) {
            ps.executeQuery();
            return Health.up()
                .withDetail("database", "PostgreSQL")
                .withDetail("url", dataSource.toString())
                .build();
        } catch (Exception e) {
            return Health.down()
                .withDetail("error", e.getMessage())
                .withException(e)
                .build();
        }
    }
}

// Kafka consumer health indicator
@Component
public class KafkaConsumerHealthIndicator implements HealthIndicator {

    private final KafkaListenerEndpointRegistry registry;

    @Override
    public Health health() {
        boolean allRunning = registry.getAllListenerContainers().stream()
            .allMatch(MessageListenerContainer::isRunning);

        return allRunning
            ? Health.up().withDetail("kafka-consumers", "all running").build()
            : Health.down().withDetail("kafka-consumers", "some stopped").build();
    }
}

// Programmatic availability state management
@Component
public class ApplicationLifecycleManager {

    private final ApplicationAvailability availability;
    private final ApplicationContext context;

    // Signal readiness during startup
    @EventListener(ApplicationReadyEvent.class)
    public void onApplicationReady() {
        // Spring auto-publishes ReadinessState.ACCEPTING_TRAFFIC on ApplicationReadyEvent
        // Manual override if needed:
        // AvailabilityChangeEvent.publish(context, ReadinessState.ACCEPTING_TRAFFIC);
        log.info("Application ready, accepting traffic");
    }

    // Signal not ready during critical operation (e.g., cache warming)
    public void performMaintenanceMode() {
        AvailabilityChangeEvent.publish(context, ReadinessState.REFUSING_TRAFFIC);
        try {
            // Perform maintenance "” K8s won't send new traffic during this
            rebuildCache();
        } finally {
            AvailabilityChangeEvent.publish(context, ReadinessState.ACCEPTING_TRAFFIC);
        }
    }
}
```

```yaml
# Kubernetes deployment with all three probe types
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  template:
    spec:
      containers:
        - name: order-service
          image: order-service:1.0.0
          ports:
            - containerPort: 8080
          startupProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            failureThreshold: 30      # 30 * 10s = 5 min max startup time
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 0    # startup probe covers initial delay
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3       # restart after 3 consecutive failures
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 0
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 2
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 5"]  # drain connections before SIGTERM
      terminationGracePeriodSeconds: 60
```

**Follow-up Questions:**
1. What happens if your liveness probe checks a downstream dependency that goes down "” is that correct behavior?
2. How do you implement graceful shutdown to ensure in-flight requests complete before pod termination?
3. What is the `preStop` hook and why is `sleep 5` a common pattern there?

**Common Mistakes:**
- Including downstream dependencies (Redis, external APIs) in liveness probe "” a Redis outage would restart ALL pods, causing a thundering herd when Redis recovers
- Setting `initialDelaySeconds` on liveness probe to accommodate slow startup instead of using `startupProbe` "” incorrect approach in modern Kubernetes

**Interview Traps:**
- Readiness DOWN does NOT restart the pod "” it only removes it from the load balancer. Liveness DOWN triggers restart. Confusing them is a very common mistake.
- Spring Boot's `/actuator/health` (root) is NOT the same as `/actuator/health/liveness` "” the root endpoint aggregates all components and can show DOWN even for non-critical dependencies

**Quick Revision (1-liner):**
Liveness probe failure restarts the container; readiness probe failure removes it from load balancer traffic "” Spring Actuator exposes both at `/actuator/health/liveness` and `/actuator/health/readiness`.

---

### Topic 13: Strangler Fig Pattern
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Amazon, eBay, Shopify, ING Bank, Booking.com

**Q: How does the Strangler Fig pattern enable incremental migration from a monolith to microservices?**

**Short Answer (2-3 sentences):**
The Strangler Fig pattern (named after the strangler fig tree that grows around a host tree) incrementally replaces monolith functionality by routing specific requests to new microservices via a routing layer (API Gateway or reverse proxy), while unextracted functionality continues to run in the monolith. Over time, the monolith "shrinks" as each capability is extracted, until it can be fully decommissioned. This approach avoids the "big bang" rewrite risk and allows continuous delivery throughout the migration.

**Deep Explanation:**
**Migration steps:**
1. **Identify extraction candidates** "” Choose bounded contexts with clear interfaces, independent teams, and high value (performance, scalability, independent deployment)
2. **Deploy routing layer** "” API Gateway or reverse proxy (Nginx, Spring Cloud Gateway) sits in front of both monolith and new services
3. **Shadow mode** "” Route traffic to BOTH monolith and new service; compare responses without affecting production (verifies correctness)
4. **Cutover** "” Route production traffic to new service; keep monolith code as fallback for rapid rollback
5. **Decommission** "” Remove monolith code path after confidence period

**Anti-corruption layer:**
- New service uses different domain model than monolith
- Translation layer converts between models, preventing monolith's legacy domain pollution
- E.g., monolith `Customer.userId` (int) â†’ new service `Customer.customerId` (UUID)

**Data migration:**
- Dual write pattern: write to both monolith DB and new service DB during transition
- Change Data Capture (CDC) with Debezium to sync data changes from monolith DB to new service DB
- Eventually cut read traffic to new DB, then stop dual writes

**Risks:**
- Distributed monolith if extraction is done poorly (services sharing DB)
- Integration complexity during migration (two systems in parallel)
- Data consistency during dual-write period

**Real-World Example:**
Amazon's migration from their C++ monolith in early 2000s used Strangler Fig. eBay migrated from a Perl monolith to Java microservices over 5 years, using an API Gateway to progressively route traffic. ING Bank migrated their core banking monolith using Strangler Fig with a 7-year timeline "” they couldn't risk a big bang rewrite of financial systems.

**Code Example:**
```java
// Spring Cloud Gateway as Strangler Fig routing layer
@Configuration
public class StranglerFigRouterConfig {

    // Feature flag service to control routing percentage
    private final FeatureFlagService featureFlagService;

    @Bean
    public RouteLocator stranglerFigRoutes(RouteLocatorBuilder builder) {
        return builder.routes()
            // Fully migrated: route 100% to new microservice
            .route("user-service-migrated", r -> r
                .path("/api/users/**")
                .uri("lb://user-service"))

            // Partially migrated: route based on feature flag
            .route("order-service-canary", r -> r
                .path("/api/orders/**")
                .filters(f -> f.filter(stranglerFigFilter()))
                .uri("lb://order-service"))  // new service

            // Not yet migrated: route to monolith
            .route("monolith-fallback", r -> r
                .path("/api/**")
                .uri("http://monolith-app:8080"))
            .build();
    }

    // Filter that controls percentage-based routing for in-progress migrations
    @Bean
    public GatewayFilter stranglerFigFilter() {
        return (exchange, chain) -> {
            String path = exchange.getRequest().getPath().toString();
            double migrationPercentage = featureFlagService
                .getMigrationPercentage("order-service");

            // Route to new service for configured percentage of traffic
            if (Math.random() < migrationPercentage) {
                return chain.filter(exchange);  // new service
            } else {
                // Redirect to monolith
                ServerHttpRequest redirectRequest = exchange.getRequest().mutate()
                    .uri(URI.create("http://monolith-app:8080" + path))
                    .build();
                return chain.filter(exchange.mutate().request(redirectRequest).build());
            }
        };
    }
}

// Anti-corruption layer "” translates between monolith and new domain models
@Service
public class OrderAntiCorruptionLayer {

    // Monolith uses legacy order model
    public NewOrderDomainModel translateFromMonolith(MonolithOrder legacyOrder) {
        return NewOrderDomainModel.builder()
            .orderId(OrderId.of(legacyOrder.getOrderNum().toString()))  // int â†’ UUID-like
            .customerId(CustomerId.of(String.valueOf(legacyOrder.getCustId())))
            .items(legacyOrder.getLineItems().stream()
                .map(this::translateLineItem)
                .collect(Collectors.toList()))
            .status(translateStatus(legacyOrder.getStatusCode()))
            .placedAt(legacyOrder.getCreatedDate().toInstant())
            .build();
    }

    private OrderStatus translateStatus(int statusCode) {
        return switch (statusCode) {
            case 1 -> OrderStatus.PENDING;
            case 2 -> OrderStatus.CONFIRMED;
            case 3 -> OrderStatus.SHIPPED;
            case 9 -> OrderStatus.CANCELLED;
            default -> throw new IllegalArgumentException("Unknown status: " + statusCode);
        };
    }
}

// Dual write pattern during data migration
@Service
public class OrderMigrationService {

    private final MonolithOrderRepository monolithRepo;
    private final NewOrderRepository newRepo;
    private final FeatureFlagService flags;

    @Transactional
    public Order createOrder(CreateOrderCommand command) {
        // Always write to monolith (source of truth during migration)
        MonolithOrder legacyOrder = monolithRepo.save(toLegacyModel(command));

        // Dual write to new service DB when migration in progress
        if (flags.isEnabled("order-service-dual-write")) {
            try {
                newRepo.save(toNewModel(command, legacyOrder.getId()));
            } catch (Exception e) {
                // Log but don't fail "” monolith is source of truth
                log.error("Dual write failed for order {}", legacyOrder.getId(), e);
                metrics.increment("migration.dual_write.failure");
            }
        }
        return toNewModel(command, legacyOrder.getId());
    }
}
```

**Follow-up Questions:**
1. How do you handle database migration "” do you create a new schema for the microservice or share the monolith database initially?
2. How does Change Data Capture (CDC) with Debezium support the Strangler Fig migration?
3. What metrics would you monitor to know when a migrated service is ready for full cutover?

**Common Mistakes:**
- Extracting too many services simultaneously "” the migration becomes a big bang rewrite in disguise; extract one service at a time
- Sharing the monolith database with the new service "” this creates a distributed monolith and defeats the purpose; accept temporary data duplication

**Interview Traps:**
- Strangler Fig requires a routing layer to work "” without a gateway/proxy to redirect traffic, you can't incrementally migrate without changing clients
- "Rewrite the monolith from scratch" (big bang) is almost always slower and riskier than Strangler Fig "” every large failed IT project in history involved a big bang rewrite

**Quick Revision (1-liner):**
Strangler Fig incrementally extracts monolith capabilities to microservices via a routing layer, allowing continuous delivery and zero-risk rollback during migration.

---


---

### Topic 14: Data Isolation
**Difficulty:** Hard | **Frequency:** High | **Companies:** Amazon, Netflix, Uber, Airbnb, Goldman Sachs

**Q: How do you handle data isolation and consistency in a microservices architecture where each service needs its own database?**

**Short Answer (2-3 sentences):**
Each microservice should own its data store exclusively — no shared databases between services. This "database per service" pattern ensures loose coupling but requires explicit strategies for cross-service queries and consistency, such as API composition, CQRS, or event-driven synchronization.

**Deep Explanation:**
Cover: database per service (polyglot persistence), shared database anti-pattern and why it couples services, API composition for cross-service queries, CQRS for read model, event-driven data synchronization (eventual consistency), handling distributed joins, data consistency challenges (no distributed transactions), saga pattern reference.

**Real-World Example:**
An e-commerce platform where Order Service owns MySQL, Inventory Service owns PostgreSQL, and Product Catalog uses MongoDB. When placing an order needs to display product name + inventory count + order total — handled via API composition in the Order Service.

**Code Example:**
```java
// API Composition in Order Service
@Service
@RequiredArgsConstructor
public class OrderQueryService {
    private final OrderRepository orderRepository;
    private final InventoryClient inventoryClient;
    private final ProductClient productClient;

    public OrderDetailsDTO getOrderDetails(Long orderId) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException(orderId));
        
        ProductDTO product = productClient.getProduct(order.getProductId());
        InventoryDTO inventory = inventoryClient.getStock(order.getProductId());
        
        return OrderDetailsDTO.builder()
            .orderId(order.getId())
            .productName(product.getName())
            .quantity(order.getQuantity())
            .stockAvailable(inventory.getAvailable())
            .total(order.getTotal())
            .build();
    }
}

// Event-driven data sync: Order service publishes event, Reporting service subscribes
@Component
public class OrderCreatedEventHandler {
    @KafkaListener(topics = "order-created")
    public void handle(OrderCreatedEvent event) {
        reportingRepository.save(ReportingOrder.from(event));
    }
}
```

**Follow-up Questions:**
1. How do you handle a query that needs to join data from 3 different services?
2. What is CQRS and how does it help with read models in microservices?
3. How do you handle referential integrity when you can't use foreign keys across services?

**Common Mistakes:**
- Using a shared database "just for this one query" — breaks isolation and creates tight coupling
- Attempting distributed transactions (2PC) across services — brittle, performance killer

**Interview Traps:**
- "Can two services share a database if they only read from each other's tables?" — No, even read access creates coupling (schema changes break the consumer)
- Confusing eventual consistency (acceptable for most reads) with strong consistency (needed for financial transactions)

**Quick Revision (1-liner):**
Database per service ensures loose coupling; use API composition, CQRS, or events for cross-service data needs — never share databases.

---

### Topic 15: Microservices Security
**Difficulty:** Hard | **Frequency:** High | **Companies:** Goldman Sachs, Stripe, Google, Amazon, Okta

**Q: How do you implement security in a microservices architecture — specifically JWT propagation, OAuth2 token relay, and service-to-service authentication?**

**Short Answer (2-3 sentences):**
In microservices, the API Gateway validates the incoming JWT from external clients and either forwards it downstream (token relay) or exchanges it for an internal token. Service-to-service calls use mutual TLS (mTLS) or client credentials OAuth2 flow to prove identity without user context. Spring Security's resource server support makes JWT validation declarative.

**Deep Explanation:**
Cover: perimeter security (API Gateway validates external JWT), token relay (forwarding JWT downstream), token exchange (OAuth2 Token Exchange RFC 8693), service-to-service auth with client credentials grant, mTLS with certificates, service mesh mTLS (Istio), Spring Security resource server config, propagating user context via headers, zero-trust network model.

**Real-World Example:**
A user calls the API Gateway with a Bearer JWT. Gateway validates signature and forwards JWT to Order Service. Order Service needs to call Inventory Service — it uses the client credentials grant to obtain a service token from the Auth Server, which Inventory Service validates.

**Code Example:**
```java
// API Gateway: Token Relay filter (Spring Cloud Gateway)
@Bean
public RouteLocator routes(RouteLocatorBuilder builder) {
    return builder.routes()
        .route("order-service", r -> r
            .path("/api/orders/**")
            .filters(f -> f.tokenRelay())  // forwards JWT downstream
            .uri("lb://order-service"))
        .build();
}

// Order Service: Resource Server config
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthConverter())))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated());
        return http.build();
    }
}

// Service-to-service: Client Credentials
@Bean
public WebClient inventoryWebClient(OAuth2AuthorizedClientManager manager) {
    ServletOAuth2AuthorizedClientExchangeFilterFunction oauth2 =
        new ServletOAuth2AuthorizedClientExchangeFilterFunction(manager);
    oauth2.setDefaultClientRegistrationId("inventory-service");
    return WebClient.builder()
        .baseUrl("http://inventory-service")
        .apply(oauth2.oauth2Configuration())
        .build();
}
```

**Follow-up Questions:**
1. What is the difference between token relay and token exchange?
2. How does mTLS provide service-to-service authentication without OAuth2?
3. How do you propagate the original user's identity in a service-to-service call?

**Common Mistakes:**
- Not validating JWTs in downstream services (trusting the Gateway blindly) — creates security gap if Gateway is bypassed
- Hardcoding service credentials in application.properties — use Vault or Secrets Manager

**Interview Traps:**
- "The API Gateway already validated the token, so downstream services don't need to" — Wrong; defense in depth requires each service to validate
- Confusing authentication (who are you?) with authorization (what can you do?) at the service level

**Quick Revision (1-liner):**
Use token relay for user context propagation and client credentials grant for service-to-service auth; never trust implicit internal network security.

---

## Microservices Patterns Quick Reference

### Communication Pattern Comparison
| Pattern | Use Case | Consistency | Coupling |
|---------|----------|-------------|---------|
| Synchronous REST | Real-time queries | Strong | Higher |
| Synchronous gRPC | High-performance internal | Strong | Higher |
| Async Messaging (Kafka) | Event notification | Eventual | Lower |
| Async Messaging (RabbitMQ) | Task queues | Eventual | Lower |

### Resilience Patterns
| Pattern | Problem Solved | Resilience4j Annotation |
|---------|---------------|------------------------|
| Circuit Breaker | Cascading failures | @CircuitBreaker |
| Retry | Transient failures | @Retry |
| Rate Limiter | Overload protection | @RateLimiter |
| Bulkhead | Resource exhaustion | @Bulkhead |
| Timeout | Slow dependencies | @TimeLimiter |

### Saga Pattern Comparison
| Aspect | Choreography | Orchestration |
|--------|-------------|--------------|
| Coordination | Events | Central orchestrator |
| Coupling | Loose | Tighter |
| Visibility | Hard to track | Easy to monitor |
| Failure handling | Complex compensations | Centralized |
| Best for | Simple flows | Complex multi-step transactions |

### Service Discovery Comparison
| Type | Example | How it works |
|------|---------|-------------|
| Client-side | Eureka + Ribbon | Client queries registry, load balances itself |
| Server-side | AWS ALB | Load balancer queries registry |
| DNS-based | Kubernetes | DNS resolves service name to VIP |


---

## Microservices Quick Reference (continued)

### Distributed Tracing Tools
| Tool | Protocol | Storage | Spring Integration |
|------|----------|---------|-------------------|
| Zipkin | HTTP/Kafka | In-memory/Elasticsearch | spring-cloud-sleuth (deprecated), Micrometer Tracing |
| Jaeger | HTTP/gRPC | Cassandra/Elasticsearch | OpenTelemetry SDK |
| Tempo (Grafana) | OpenTelemetry | Object storage | OpenTelemetry SDK |
| AWS X-Ray | HTTP | DynamoDB | AWS SDK + OTel |

### Health Check Types
| Type | Purpose | Failing means |
|------|---------|--------------|
| Liveness | Is process alive? | Restart the pod |
| Readiness | Can serve traffic? | Remove from load balancer |
| Startup | Is app initialized? | Delay liveness checks |

### Communication Pattern Selection Guide
| Scenario | Pattern | Why |
|---------|---------|-----|
| User-facing read | Sync REST/gRPC | Low latency required |
| Background processing | Async Kafka | Decoupling, retry |
| Real-time notification | WebSocket / SSE | Push semantics |
| Service-to-service (critical path) | gRPC | Performance + type safety |
| Service-to-service (non-critical) | REST | Simplicity |
| Cross-domain events | Kafka / EventBridge | Loose coupling |

### Resilience4j Configuration Reference
| Annotation | Key Properties | Default |
|-----------|---------------|---------|
| @CircuitBreaker | slidingWindowSize, failureRateThreshold, waitDurationInOpenState | 100, 50%, 60s |
| @Retry | maxAttempts, waitDuration, retryExceptions | 3, 500ms, Exception |
| @RateLimiter | limitForPeriod, limitRefreshPeriod, timeoutDuration | 50, 1s, 5s |
| @Bulkhead | maxConcurrentCalls, maxWaitDuration | 25, 0ms |
| @TimeLimiter | timeoutDuration, cancelRunningFuture | 1s, true |

### Microservices Anti-Patterns
| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Shared Database | Tight coupling, schema drift | Database per service |
| Synchronous Chain | Cascading failures | Async messaging or circuit breaker |
| Mega-Service | Micromonolith | Re-decompose by bounded context |
| Chatty Services | Network overhead | Aggregate API or batch calls |
| Missing Idempotency | Duplicate processing on retry | Idempotency keys + deduplication |

---

*End of Chapter 10 — Microservices Architecture | Volume 3: Backend Systems*

