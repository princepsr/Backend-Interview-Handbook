# Volume 3: Backend Systems
# Chapter 9: REST APIs & HTTP

---

## Table of Contents
1. [REST Principles & Constraints](#topic-1-rest-principles--constraints)
2. [HTTP Methods](#topic-2-http-methods)
3. [HTTP Status Codes](#topic-3-http-status-codes)
4. [REST API Versioning](#topic-4-rest-api-versioning)
5. [Idempotency](#topic-5-idempotency)
6. [API Error Handling](#topic-6-api-error-handling)
7. [Pagination](#topic-7-pagination)
8. [Request/Response Design](#topic-8-requestresponse-design)
9. [API Rate Limiting](#topic-9-api-rate-limiting)
10. [Content Negotiation & Media Types](#topic-10-content-negotiation--media-types)
11. [HTTP Caching](#topic-11-http-caching)
12. [API Security Basics](#topic-12-api-security-basics)
13. [REST vs GraphQL vs gRPC](#topic-13-rest-vs-graphql-vs-grpc)
14. [OpenAPI/Swagger](#topic-14-openapiswagger)
15. [API Gateway Patterns](#topic-15-api-gateway-patterns)
16. [Master Reference Tables](#master-reference-tables)

---

### Topic 1: REST Principles & Constraints
**Difficulty:** Medium | **Frequency:** High | **Companies:** Amazon, Google, Stripe, Atlassian, Goldman Sachs

**Q: What are the six architectural constraints of REST, and how do they affect API design?**

**Short Answer (2-3 sentences):**
REST (Representational State Transfer) defines six constraints: client-server separation, statelessness, cacheability, uniform interface, layered system, and code-on-demand (optional). These constraints ensure scalability, simplicity, and evolvability. Violating any mandatory constraint means the API is not truly RESTful.

**Deep Explanation:**
Roy Fielding defined REST in his 2000 dissertation as an architectural style, not a protocol. The constraints work together:

1. **Client-Server**: UI and data storage concerns are separated. The client doesn't need to know about server-side storage; the server doesn't know about client UI. This enables independent evolution.

2. **Stateless**: Each request must contain all information necessary to process it. Session state is held on the client, never on the server. Consequences: every request carries its auth token; no sticky sessions needed; horizontal scaling is trivial.

3. **Cacheable**: Responses must declare themselves cacheable or non-cacheable. Correct caching eliminates some client-server interactions, improving performance and scalability. Use `Cache-Control`, `ETag`, and `Last-Modified` headers.

4. **Uniform Interface**: The central REST constraint, comprising four sub-constraints:
   - **Resource identification in requests** — resources are identified by URIs
   - **Manipulation of resources through representations** — clients manipulate state through representations (JSON, XML), not direct database access
   - **Self-descriptive messages** — each message carries enough info to describe how to process it (Content-Type, status codes)
   - **HATEOAS** (Hypermedia As The Engine Of Application State) — responses include links to related actions

5. **Layered System**: Clients can't tell whether they're connected directly to the origin server or a proxy/load balancer. This enables CDN caching, API gateways, security layers.

6. **Code-on-demand (optional)**: Servers can extend client functionality by transferring executable code (JavaScript). Rarely used in pure REST APIs.

**HATEOAS in depth**: In a truly RESTful API, a client should be able to navigate the entire API starting from a single entry-point URL. Each response embeds links to related operations. This decouples the client from hardcoded URLs and makes the API self-documenting.

**Real-World Example:**
GitHub's REST API implements HATEOAS-like links. When you fetch a repository, the response includes `forks_url`, `issues_url`, `pulls_url`, etc. A payment API following HATEOAS: after creating a payment, the response includes `_links.capture`, `_links.void`, and `_links.refund` — the client discovers what actions are possible without consulting docs.

**Code Example:**
```java
// Spring Boot 3.x HATEOAS implementation
import org.springframework.hateoas.*;
import org.springframework.hateoas.server.mvc.WebMvcLinkBuilder;
import static org.springframework.hateoas.server.mvc.WebMvcLinkBuilder.*;

@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @GetMapping("/{id}")
    public EntityModel<OrderResponse> getOrder(@PathVariable Long id) {
        Order order = orderService.findById(id);
        OrderResponse response = OrderResponse.from(order);

        EntityModel<OrderResponse> model = EntityModel.of(response);

        // Self-link — always include
        model.add(linkTo(methodOn(OrderController.class).getOrder(id)).withSelfRel());

        // Conditional links based on current state (HATEOAS core idea)
        if (order.getStatus() == OrderStatus.PENDING) {
            model.add(linkTo(methodOn(OrderController.class)
                .cancelOrder(id)).withRel("cancel"));
            model.add(linkTo(methodOn(OrderController.class)
                .confirmOrder(id)).withRel("confirm"));
        }
        if (order.getStatus() == OrderStatus.DELIVERED) {
            model.add(linkTo(methodOn(OrderController.class)
                .refundOrder(id)).withRel("refund"));
        }

        return model;
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> cancelOrder(@PathVariable Long id) {
        orderService.cancel(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/confirm")
    public EntityModel<OrderResponse> confirmOrder(@PathVariable Long id) {
        Order order = orderService.confirm(id);
        EntityModel<OrderResponse> model = EntityModel.of(OrderResponse.from(order));
        model.add(linkTo(methodOn(OrderController.class).getOrder(id)).withSelfRel());
        return model;
    }

    @PostMapping("/{id}/refund")
    public EntityModel<OrderResponse> refundOrder(@PathVariable Long id) {
        Order order = orderService.refund(id);
        EntityModel<OrderResponse> model = EntityModel.of(OrderResponse.from(order));
        model.add(linkTo(methodOn(OrderController.class).getOrder(id)).withSelfRel());
        return model;
    }
}

// Response with HATEOAS links:
// {
//   "id": 123, "status": "PENDING", "amount": 49.99,
//   "_links": {
//     "self": { "href": "/api/v1/orders/123" },
//     "cancel": { "href": "/api/v1/orders/123" },
//     "confirm": { "href": "/api/v1/orders/123/confirm" }
//   }
// }
```

**Follow-up Questions:**
1. Why do most production APIs skip HATEOAS even though it's part of REST?
2. How does statelessness affect authentication — can you use server-side sessions?
3. What is Richardson Maturity Model and what are its levels?

**Common Mistakes:**
- Calling any JSON-over-HTTP API "RESTful" — most are RPC-style, not truly REST
- Storing session state on the server and thinking it's fine as long as you use HTTP methods correctly
- Ignoring the uniform interface constraint — using `POST /getUser` instead of `GET /users/{id}`

**Interview Traps:**
- Interviewers may ask "what makes an API RESTful?" expecting you to go beyond "uses HTTP verbs" — mention statelessness and uniform interface at minimum
- HATEOAS is often called the "glory of REST" but rarely implemented — acknowledge the pragmatic trade-off: it adds complexity and few clients use the links

**Quick Revision (1-liner):**
REST's six constraints (stateless, client-server, cacheable, uniform interface, layered, code-on-demand) ensure scalability and evolvability; HATEOAS is the most often skipped but most powerful constraint.

---

### Topic 2: HTTP Methods
**Difficulty:** Easy | **Frequency:** High | **Companies:** All companies

**Q: Explain the semantics of GET, POST, PUT, PATCH, and DELETE. Which are safe? Which are idempotent?**

**Short Answer (2-3 sentences):**
HTTP methods carry semantic meaning: GET retrieves, POST creates, PUT replaces, PATCH partially updates, DELETE removes. Safety means the method has no observable side effects; idempotency means calling it N times produces the same result as calling it once. GET and HEAD are both safe and idempotent; PUT and DELETE are idempotent but not safe; POST is neither.

**Deep Explanation:**
**Safety**: A method is "safe" if it does not modify server state. Safe methods can be cached, prefetched, and retried freely. GET, HEAD, OPTIONS, and TRACE are safe.

**Idempotency**: Calling an idempotent method multiple times with the same input produces the same server state as calling it once. This is critical for retry logic in distributed systems.

| Method  | Safe | Idempotent | Request Body | Response Body | Common Use                         |
|---------|------|------------|--------------|---------------|------------------------------------|
| GET     | Yes  | Yes        | No           | Yes           | Retrieve resource                  |
| HEAD    | Yes  | Yes        | No           | No            | Check resource existence/metadata  |
| OPTIONS | Yes  | Yes        | No           | Yes           | CORS preflight, capability check   |
| POST    | No   | No         | Yes          | Yes           | Create resource, trigger action    |
| PUT     | No   | Yes        | Yes          | Yes/No        | Full replacement of resource       |
| PATCH   | No   | No*        | Yes          | Yes           | Partial update                     |
| DELETE  | No   | Yes        | Optional     | Optional      | Delete resource                    |

*PATCH can be made idempotent with conditional requests (`If-Match`) but is not inherently idempotent.

**POST vs PUT**: Use POST when the server assigns the resource ID (`POST /orders` → server creates order with server-generated ID). Use PUT when the client specifies the ID (`PUT /orders/123` → full replacement of order 123). POST to the same endpoint twice creates two resources; PUT twice creates/replaces the same resource.

**PUT vs PATCH**: PUT sends the complete resource representation; omitted fields are set to null/default. PATCH sends only the changed fields. For large resources, PATCH is more efficient and less error-prone.

**Real-World Example:**
Stripe's API uses POST for nearly everything because idempotency keys make POST effectively idempotent. `POST /v1/charges` with `Idempotency-Key: unique-key` will create one charge even if retried multiple times. This is a pragmatic deviation from pure REST — sometimes business semantics matter more than HTTP method purity.

**Code Example:**
```java
@RestController
@RequestMapping("/api/v1/products")
public class ProductController {

    private final ProductService productService;

    // GET — safe, idempotent, cacheable
    @GetMapping("/{id}")
    public ResponseEntity<ProductResponse> getProduct(@PathVariable Long id) {
        return ResponseEntity.ok(productService.findById(id));
    }

    // POST — creates new resource; server assigns ID; NOT idempotent
    @PostMapping
    public ResponseEntity<ProductResponse> createProduct(
            @RequestBody @Valid CreateProductRequest request) {
        ProductResponse created = productService.create(request);
        URI location = URI.create("/api/v1/products/" + created.getId());
        return ResponseEntity.created(location).body(created);
        // 201 Created + Location header
    }

    // PUT — full replacement; idempotent; send complete resource
    @PutMapping("/{id}")
    public ResponseEntity<ProductResponse> replaceProduct(
            @PathVariable Long id,
            @RequestBody @Valid ReplaceProductRequest request) {
        ProductResponse updated = productService.replace(id, request);
        return ResponseEntity.ok(updated);
        // 200 OK or 204 No Content
    }

    // PATCH — partial update; only send fields to change
    @PatchMapping("/{id}")
    public ResponseEntity<ProductResponse> patchProduct(
            @PathVariable Long id,
            @RequestBody Map<String, Object> updates) {
        ProductResponse updated = productService.patch(id, updates);
        return ResponseEntity.ok(updated);
    }

    // DELETE — idempotent; second call returns 404 but that's still "idempotent" in state terms
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteProduct(@PathVariable Long id) {
        productService.delete(id);
        return ResponseEntity.noContent().build(); // 204 No Content
    }

    // HEAD — same as GET but no response body; check if resource exists
    @RequestMapping(value = "/{id}", method = RequestMethod.HEAD)
    public ResponseEntity<Void> checkProduct(@PathVariable Long id) {
        productService.findById(id); // throws 404 if not found
        return ResponseEntity.ok().build();
    }
}

// Service layer for PATCH using JsonMergePatch (RFC 7396)
@Service
public class ProductService {
    
    private final ProductRepository repository;
    private final ObjectMapper objectMapper;

    public ProductResponse patch(Long id, Map<String, Object> updates) {
        Product product = repository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Product", id));
        
        // Apply only the provided fields
        if (updates.containsKey("name")) {
            product.setName((String) updates.get("name"));
        }
        if (updates.containsKey("price")) {
            product.setPrice(new BigDecimal(updates.get("price").toString()));
        }
        // Fields not in updates are untouched
        
        return ProductResponse.from(repository.save(product));
    }
}
```

**Follow-up Questions:**
1. Is DELETE idempotent if the second call returns 404?
2. Why does Stripe prefer POST over PUT for creating resources?
3. How would you implement a bulk delete operation — DELETE with a body, or POST to a `/batch-delete` endpoint?

**Common Mistakes:**
- Using POST for read operations (`POST /users/search`) when GET with query parameters would work
- Using GET with a request body to pass complex filters — GET bodies are technically allowed but widely unsupported by proxies and browsers
- Treating PATCH as always idempotent — `PATCH /counter` with `{increment: 1}` is not idempotent

**Interview Traps:**
- "Is DELETE idempotent?" — Yes in terms of state (the resource ends up deleted), but the HTTP response code differs (200/204 first time, 404 subsequent). Idempotency refers to state, not response codes.
- "Should PATCH be idempotent?" — It should be when possible, but the spec doesn't require it. Conditional PATCH with `If-Match` makes it idempotent.

**Quick Revision (1-liner):**
GET/HEAD are safe+idempotent; PUT/DELETE are idempotent but not safe; POST is neither; PATCH is not inherently idempotent but can be made so with conditional requests.

---

### Topic 3: HTTP Status Codes
**Difficulty:** Easy | **Frequency:** High | **Companies:** All companies

**Q: Walk me through the HTTP status code ranges and when to use specific codes like 201, 204, 400, 401, 403, 404, 409, 422, 429, and 503.**

**Short Answer (2-3 sentences):**
Status codes are grouped into five classes: 1xx (informational), 2xx (success), 3xx (redirection), 4xx (client error), and 5xx (server error). The specific code chosen communicates precise semantics to clients — using 400 for everything is an anti-pattern. Correct status codes enable automatic retry logic, caching, and proper error handling in clients.

**Deep Explanation:**

**2xx Success:**
- **200 OK**: Standard success for GET, PUT, PATCH. Include the response body.
- **201 Created**: Resource was created (POST). Must include `Location` header pointing to new resource.
- **202 Accepted**: Request accepted but processing is asynchronous. Include a way to poll status (polling URL or job ID).
- **204 No Content**: Success with no response body. Used for DELETE, PUT when not returning the updated resource, and PATCH.
- **206 Partial Content**: Used with range requests (`Range` header) for streaming/resumable downloads.

**3xx Redirection:**
- **301 Moved Permanently**: Resource has a new permanent URI. Clients should update bookmarks. Safe to cache.
- **302 Found**: Temporary redirect. Don't update bookmarks. Often misused.
- **304 Not Modified**: Response to conditional GET (`If-None-Match`/`If-Modified-Since`) — client's cached copy is still valid.
- **307 Temporary Redirect**: Same as 302 but preserves HTTP method (won't convert POST to GET).
- **308 Permanent Redirect**: Same as 301 but preserves HTTP method.

**4xx Client Errors:**
- **400 Bad Request**: Malformed request syntax, invalid request body, missing required fields.
- **401 Unauthorized**: Authentication is required or has failed. Despite the name, it means "unauthenticated."
- **403 Forbidden**: Authenticated but not authorized. User is known but lacks permission.
- **404 Not Found**: Resource does not exist. Also use when you want to hide existence (instead of 403).
- **405 Method Not Allowed**: HTTP method not supported for this endpoint.
- **409 Conflict**: State conflict — duplicate key, optimistic lock failure, version mismatch.
- **410 Gone**: Resource existed but was permanently deleted. Unlike 404, signals "don't look for it."
- **415 Unsupported Media Type**: Client sent wrong Content-Type (e.g., XML when only JSON is accepted).
- **422 Unprocessable Entity**: Request is syntactically correct but semantically invalid (business rule violation).
- **429 Too Many Requests**: Rate limit exceeded. Include `Retry-After` header.

**5xx Server Errors:**
- **500 Internal Server Error**: Generic server error — avoid using this for known error conditions.
- **501 Not Implemented**: Feature not yet implemented.
- **502 Bad Gateway**: Upstream service returned invalid response.
- **503 Service Unavailable**: Server is down for maintenance or overloaded. Include `Retry-After`.
- **504 Gateway Timeout**: Upstream service timed out.

**400 vs 422**: 400 = request cannot be parsed (bad JSON). 422 = request parsed fine, but business rules fail (e.g., "end date must be after start date"). Some teams use only 400 for simplicity; others distinguish them.

**Real-World Example:**
GitHub API: creating a repository that already exists returns 422 Unprocessable Entity. Stripe returns 400 for malformed requests and 402 Payment Required for declined cards. Google APIs use 429 with a `Retry-After` header when rate limits are hit.

**Code Example:**
```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    // 400 Bad Request — validation failures
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ProblemDetail> handleValidationException(
            MethodArgumentNotValidException ex, HttpServletRequest request) {
        
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.BAD_REQUEST, "Request validation failed");
        problem.setTitle("Validation Error");
        problem.setInstance(URI.create(request.getRequestURI()));
        
        Map<String, String> errors = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors()
            .forEach(e -> errors.put(e.getField(), e.getDefaultMessage()));
        problem.setProperty("violations", errors);
        
        return ResponseEntity.badRequest().body(problem);
    }

    // 401 Unauthorized — not authenticated
    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ProblemDetail> handleAuthException(
            AuthenticationException ex, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.UNAUTHORIZED, "Authentication required");
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
            .header("WWW-Authenticate", "Bearer realm=\"api\"")
            .body(problem);
    }

    // 403 Forbidden — authenticated but not authorized
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ProblemDetail> handleAccessDenied(
            AccessDeniedException ex, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.FORBIDDEN, "Insufficient permissions");
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(problem);
    }

    // 404 Not Found
    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ProblemDetail> handleNotFound(
            ResourceNotFoundException ex, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.NOT_FOUND, ex.getMessage());
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(problem);
    }

    // 409 Conflict — e.g., duplicate email, optimistic lock
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ProblemDetail> handleConflict(
            DataIntegrityViolationException ex, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.CONFLICT, "Resource already exists");
        return ResponseEntity.status(HttpStatus.CONFLICT).body(problem);
    }

    // 422 Unprocessable Entity — business rule violation
    @ExceptionHandler(BusinessRuleViolationException.class)
    public ResponseEntity<ProblemDetail> handleBusinessRule(
            BusinessRuleViolationException ex, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_ENTITY, ex.getMessage());
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(problem);
    }

    // 429 Too Many Requests — rate limit
    @ExceptionHandler(RateLimitExceededException.class)
    public ResponseEntity<ProblemDetail> handleRateLimit(
            RateLimitExceededException ex, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.TOO_MANY_REQUESTS, "Rate limit exceeded");
        return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
            .header("Retry-After", String.valueOf(ex.getRetryAfterSeconds()))
            .header("X-RateLimit-Limit", String.valueOf(ex.getLimit()))
            .header("X-RateLimit-Remaining", "0")
            .header("X-RateLimit-Reset", String.valueOf(ex.getResetTimestamp()))
            .body(problem);
    }

    // 503 Service Unavailable — circuit breaker open, downstream down
    @ExceptionHandler(ServiceUnavailableException.class)
    public ResponseEntity<ProblemDetail> handleServiceUnavailable(
            ServiceUnavailableException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.SERVICE_UNAVAILABLE, "Service temporarily unavailable");
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
            .header("Retry-After", "30")
            .body(problem);
    }
}
```

**Follow-up Questions:**
1. When would you use 202 Accepted vs 201 Created?
2. What's the difference between 401 and 403 — why does 401 say "Unauthorized" when it means "Unauthenticated"?
3. Should you return 404 or 403 when a user requests a resource that exists but they don't have access to?

**Common Mistakes:**
- Returning 200 with an error body (`{"success": false, "error": "..."}`) — this breaks HTTP semantics and breaks monitoring
- Using 500 for all errors, including ones caused by bad client input
- Returning 404 for a valid endpoint with an empty list — should be 200 with `[]`

**Interview Traps:**
- "What's the difference between 401 and 403?" — 401 means the client hasn't authenticated (send credentials); 403 means credentials are valid but access is denied (no point retrying with same credentials). The naming in the RFC is confusing — "Unauthorized" should have been called "Unauthenticated."
- 404 vs 403 for hidden resources: security-sensitive APIs return 404 to prevent resource enumeration — never confirm whether a resource exists to unauthorized users.

**Quick Revision (1-liner):**
2xx = success (201 for create, 204 for no body); 4xx = client fault (400=bad syntax, 401=unauthed, 403=forbidden, 409=conflict, 422=business rule); 5xx = server fault; never return 200 with an error body.

---

### Topic 4: REST API Versioning
**Difficulty:** Medium | **Frequency:** High | **Companies:** Stripe, Atlassian, Google, Salesforce, Amazon

**Q: What are the four main REST API versioning strategies? What are the pros and cons of each?**

**Short Answer (2-3 sentences):**
The four main strategies are URI path versioning (`/v1/users`), query parameter versioning (`/users?version=1`), custom request header (`API-Version: 1`), and content negotiation via `Accept` header (`Accept: application/vnd.myapi.v1+json`). URI versioning is most visible and widely used; header and content negotiation are "cleaner" but harder to test in a browser. There is no universally correct choice — the right strategy depends on client type, team conventions, and tooling.

**Deep Explanation:**

**1. URI Path Versioning** (`/api/v1/users`, `/api/v2/users`)
- Pros: Immediately visible in URLs, easy to test in browser, easy to document, CDN/proxy can route by URL prefix, simple to enforce in firewalls
- Cons: Violates REST principle (URI should identify a resource, not a version of an API), clutters URL structure, bookmarked URLs break on deprecation
- Used by: Stripe, GitHub (partially), Twitter

**2. Query Parameter Versioning** (`/api/users?api-version=1`)
- Pros: Backward-compatible (default version can be assumed), easy to add
- Cons: Easy to forget/omit, caching is more complex (CDNs need to vary cache by query param), not idiomatic REST
- Used by: Microsoft Azure REST API (`?api-version=2023-01-01`)

**3. Custom Request Header** (`API-Version: 1` or `X-API-Version: 1`)
- Pros: Keeps URIs clean, semantically correct (URI identifies resource, header describes how to process)
- Cons: Not visible in browser, can't test directly from browser URL bar, requires custom header support in all clients, proxies may strip custom headers
- Used by: Some internal enterprise APIs

**4. Content Negotiation / Accept Header** (`Accept: application/vnd.myapi.v2+json`)
- Pros: Follows HTTP specification perfectly, most RESTful, clients can request multiple versions
- Cons: Complex to implement and document, unfamiliar to many developers, hard to test without tools, some clients don't support custom MIME types well
- Used by: GitHub API (`application/vnd.github.v3+json`), Atlassian

**Versioning granularity strategies:**
- **Whole-API versioning**: One version for all endpoints (simple, but forces clients to upgrade all at once)
- **Per-resource versioning**: Each resource has its own version (flexible, but complex to manage)
- **Stripe's date-based versioning**: Clients pin to a specific date-stamped API version. New versions add breaking changes; old behavior is maintained indefinitely per pinned version. This is sophisticated but very client-friendly.

**Real-World Example:**
Stripe's versioning model is industry-leading: each API key has a "default version" set on account creation. Requests can override per-call with `Stripe-Version: 2023-10-16`. Stripe maintains backward compatibility for years. GitHub uses URI versioning for major versions (`/v3/`) and media types for sub-versioning.

**Code Example:**
```java
// Strategy 1: URI path versioning (most common)
@RestController
@RequestMapping("/api/v1/users")
public class UserControllerV1 {
    @GetMapping("/{id}")
    public UserResponseV1 getUser(@PathVariable Long id) {
        // V1 response: {id, name, email}
        return userService.findByIdV1(id);
    }
}

@RestController
@RequestMapping("/api/v2/users")
public class UserControllerV2 {
    @GetMapping("/{id}")
    public UserResponseV2 getUser(@PathVariable Long id) {
        // V2 response: {id, firstName, lastName, email, phone, createdAt}
        return userService.findByIdV2(id);
    }
}

// Strategy 2: Header-based versioning with Spring MVC
@RestController
@RequestMapping("/api/users")
public class UserController {

    @GetMapping(value = "/{id}", headers = "API-Version=1")
    public UserResponseV1 getUserV1(@PathVariable Long id) {
        return userService.findByIdV1(id);
    }

    @GetMapping(value = "/{id}", headers = "API-Version=2")
    public UserResponseV2 getUserV2(@PathVariable Long id) {
        return userService.findByIdV2(id);
    }
}

// Strategy 3: Content negotiation versioning
@RestController
@RequestMapping("/api/users")
public class UserControllerContentNeg {

    @GetMapping(value = "/{id}",
        produces = "application/vnd.mycompany.api.v1+json")
    public UserResponseV1 getUserV1(@PathVariable Long id) {
        return userService.findByIdV1(id);
    }

    @GetMapping(value = "/{id}",
        produces = "application/vnd.mycompany.api.v2+json")
    public UserResponseV2 getUserV2(@PathVariable Long id) {
        return userService.findByIdV2(id);
    }
}

// Strategy 4: Stripe-style date-based versioning via interceptor
@Component
public class ApiVersionInterceptor implements HandlerInterceptor {

    private static final String STRIPE_VERSION_HEADER = "Stripe-Version";
    private static final String DEFAULT_VERSION = "2024-01-01";

    @Override
    public boolean preHandle(HttpServletRequest request,
                             HttpServletResponse response,
                             Object handler) throws Exception {
        String version = request.getHeader(STRIPE_VERSION_HEADER);
        if (version == null) {
            version = DEFAULT_VERSION;
        }
        // Store in request attribute for controllers to use
        request.setAttribute("apiVersion", version);
        // Add to response so client knows which version was used
        response.setHeader(STRIPE_VERSION_HEADER, version);
        return true;
    }
}

// Deprecation notice via response headers
@GetMapping(value = "/{id}", headers = "API-Version=1")
public ResponseEntity<UserResponseV1> getUserV1(@PathVariable Long id) {
    UserResponseV1 user = userService.findByIdV1(id);
    return ResponseEntity.ok()
        .header("Deprecation", "true")
        .header("Sunset", "Sat, 31 Dec 2025 23:59:59 GMT")
        .header("Link", "</api/v2/users/" + id + ">; rel=\"successor-version\"")
        .body(user);
}
```

**Follow-up Questions:**
1. How would you deprecate an old API version without breaking existing clients?
2. What's the difference between versioning an API and versioning a specific resource?
3. How does Stripe handle its date-based versioning internally?

**Common Mistakes:**
- Never versioning the API at all ("we won't need it") — this is always a mistake; breaking changes inevitably arrive
- Incrementing major versions for every small change — use semantic versioning rules: only bump major for breaking changes
- Forgetting to version the event/webhook payloads — these also need versioning

**Interview Traps:**
- "Which versioning strategy is best?" — There is no best; URI versioning has the best developer experience, content negotiation is most RESTful. State trade-offs, then give a recommendation.
- Beware: the interviewer may want you to discuss backward compatibility strategies (additive changes, deprecated fields, sunset headers) more than the versioning mechanism itself.

**Quick Revision (1-liner):**
URI versioning (/v1/) is most practical; content negotiation is most RESTful; always version from day one and communicate deprecation via Deprecation + Sunset + Link headers.

---

### Topic 5: Idempotency
**Difficulty:** Medium | **Frequency:** High | **Companies:** Stripe, PayPal, Amazon, Goldman Sachs, Square

**Q: What is idempotency in the context of REST APIs, and how do you implement idempotency keys for non-idempotent operations like payment creation?**

**Short Answer (2-3 sentences):**
Idempotency means that performing the same operation multiple times produces the same result as performing it once. In distributed systems, network failures can cause requests to be retried, so APIs must handle duplicate requests safely. Idempotency keys (pioneered by Stripe) allow clients to safely retry POST requests by attaching a unique key that the server uses to deduplicate requests.

**Deep Explanation:**
**Why idempotency matters in distributed systems:**
Networks are unreliable. A client sends a `POST /charges` request, the server processes it and charges the customer's card, but the response is lost due to a network timeout. The client doesn't know if the charge succeeded. Without idempotency keys:
- Retry → double charge (catastrophic for payments)
- No retry → poor user experience (user unsure if paid)

**Idempotency key pattern (Stripe model):**
1. Client generates a unique key per logical operation (UUID v4)
2. Client includes `Idempotency-Key: <uuid>` header on the request
3. Server checks its idempotency key store before processing
4. If key exists and request is complete: return cached response
5. If key exists and request is in progress: return 409 or wait
6. If key is new: process request, store (key → response), return response
7. Keys expire after 24-48 hours

**Storage considerations:**
- Store idempotency keys in Redis (with TTL) or a separate DB table
- Key the store on: (idempotency_key, endpoint) or (idempotency_key, user_id, endpoint)
- If the request body differs for the same key, return 422 (conflict)
- The stored response must include status code, headers, and body

**Which HTTP methods need explicit idempotency?**
- GET, HEAD, OPTIONS: inherently idempotent, no keys needed
- PUT, DELETE: idempotent by definition, keys not typically needed (but useful for network reliability)
- POST: not idempotent, idempotency keys needed for financial and critical operations
- PATCH: depends on the operation

**Real-World Example:**
Stripe: every `POST` to a mutating endpoint (`/v1/charges`, `/v1/payment_intents`) can include `Idempotency-Key`. The key is stored for 24 hours. AWS S3 uses MD5 checksums for object uploads. Twilio recommends idempotency keys for sending SMS to prevent duplicate messages.

**Code Example:**
```java
// Idempotency key implementation with Redis
@Service
public class IdempotencyService {

    private final RedisTemplate<String, IdempotencyRecord> redisTemplate;
    private static final Duration TTL = Duration.ofHours(24);

    public IdempotencyService(RedisTemplate<String, IdempotencyRecord> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public Optional<IdempotencyRecord> findExistingRecord(String key) {
        return Optional.ofNullable(
            redisTemplate.opsForValue().get("idempotency:" + key));
    }

    public void saveRecord(String key, IdempotencyRecord record) {
        redisTemplate.opsForValue().set("idempotency:" + key, record, TTL);
    }
}

@Data
@AllArgsConstructor
public class IdempotencyRecord {
    private int statusCode;
    private String responseBody;
    private String requestBodyHash;
    private Instant processedAt;
}

// Aspect-based idempotency enforcement
@Aspect
@Component
public class IdempotencyAspect {

    private final IdempotencyService idempotencyService;
    private final ObjectMapper objectMapper;

    @Around("@annotation(idempotent)")
    public Object enforceIdempotency(ProceedingJoinPoint joinPoint,
                                      Idempotent idempotent) throws Throwable {
        HttpServletRequest request = getCurrentRequest();
        String idempotencyKey = request.getHeader("Idempotency-Key");

        if (idempotencyKey == null) {
            throw new MissingIdempotencyKeyException(
                "Idempotency-Key header is required for this operation");
        }

        // Hash the request body to detect conflicting retries
        String requestBody = getRequestBody(request);
        String requestHash = DigestUtils.sha256Hex(requestBody);

        Optional<IdempotencyRecord> existing =
            idempotencyService.findExistingRecord(idempotencyKey);

        if (existing.isPresent()) {
            IdempotencyRecord record = existing.get();
            // Check for conflicting request (same key, different body)
            if (!record.getRequestBodyHash().equals(requestHash)) {
                throw new IdempotencyConflictException(
                    "Idempotency key reused with different request body");
            }
            // Return cached response
            return deserializeResponse(record);
        }

        // Process the request
        Object result = joinPoint.proceed();

        // Cache the result
        String responseBody = objectMapper.writeValueAsString(result);
        idempotencyService.saveRecord(idempotencyKey,
            new IdempotencyRecord(200, responseBody, requestHash, Instant.now()));

        return result;
    }
}

// Controller using idempotency
@RestController
@RequestMapping("/api/v1/payments")
public class PaymentController {

    private final PaymentService paymentService;

    @PostMapping
    @Idempotent  // Custom annotation
    public ResponseEntity<PaymentResponse> createPayment(
            @RequestBody @Valid CreatePaymentRequest request,
            @RequestHeader(value = "Idempotency-Key", required = true)
                String idempotencyKey) {

        PaymentResponse payment = paymentService.charge(request);
        return ResponseEntity
            .status(HttpStatus.CREATED)
            .header("Idempotency-Key", idempotencyKey)
            .body(payment);
    }
}

// Database-level idempotency as fallback
@Entity
@Table(name = "idempotency_keys",
    uniqueConstraints = @UniqueConstraint(columnNames = {"idempotency_key", "endpoint"}))
public class IdempotencyKeyEntity {
    @Id @GeneratedValue
    private Long id;

    @Column(name = "idempotency_key", nullable = false)
    private String idempotencyKey;

    @Column(nullable = false)
    private String endpoint;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String responseBody;

    @Column(nullable = false)
    private Integer statusCode;

    @Column(nullable = false)
    private LocalDateTime expiresAt;
}
```

**Follow-up Questions:**
1. What happens if two concurrent requests arrive with the same idempotency key? How do you handle race conditions?
2. Should you store idempotency keys in Redis or the database? What are the trade-offs?
3. How would you implement idempotency for an operation that calls multiple downstream services?

**Common Mistakes:**
- Not validating that the request body is the same for a repeated idempotency key — same key, different body should be rejected
- Setting TTL too short — if clients retry after 25 hours, keys have expired and a duplicate request processes
- Using the same idempotency key for different operations (clients should generate a new UUID per logical operation, not per retry)

**Interview Traps:**
- "PUT is idempotent, does it need idempotency keys?" — In theory no, but in practice for financial operations, explicit keys add reliability guarantees. The interviewer may want you to discuss the difference between HTTP-level idempotency and business-level idempotency.
- Distributed race condition: two retries arrive simultaneously before either is processed — you need a distributed lock (Redis SETNX) or a DB unique constraint to prevent processing the same key twice.

**Quick Revision (1-liner):**
Idempotency keys let clients safely retry POST requests by having the server cache and return the same response for duplicate requests identified by a unique client-generated UUID header.

---

### Topic 6: API Error Handling
**Difficulty:** Medium | **Frequency:** High | **Companies:** Stripe, Google, Microsoft, Atlassian

**Q: How should a well-designed REST API communicate errors? Describe RFC 7807 Problem Details.**

**Short Answer (2-3 sentences):**
RFC 7807 (Problem Details for HTTP APIs) defines a standard JSON error response format with fields: `type` (URI identifying the error type), `title` (human-readable summary), `status` (HTTP status code), `detail` (human-readable explanation for this occurrence), and `instance` (URI for this specific error). Consistent error responses across all endpoints are critical for client error handling and API usability. Spring Boot 3.x supports RFC 7807 natively via `ProblemDetail`.

**Deep Explanation:**
**Why consistency matters**: Without a standard error format, clients must handle different error shapes from different endpoints. Monitoring tools can't aggregate errors easily. Support teams can't diagnose issues quickly.

**RFC 7807 Problem Details:**
```json
{
  "type": "https://api.example.com/errors/insufficient-funds",
  "title": "Insufficient Funds",
  "status": 422,
  "detail": "Your account balance of $10.00 is insufficient for this $50.00 payment.",
  "instance": "/api/v1/payments/abc123",
  "balance": 10.00,
  "required": 50.00
}
```

Fields:
- `type`: A URI that uniquely identifies the error type (not necessarily resolvable, but dereferenceable is better)
- `title`: Same for all occurrences of this type (useful for error catalogues)
- `status`: HTTP status code (redundant with HTTP layer but useful for clients that inspect body only)
- `detail`: Specific to this occurrence — what happened
- `instance`: URI identifying this specific occurrence — useful for support tickets

Extension members (`balance`, `required`) are allowed and recommended for machine-readable context.

**Content-Type**: Errors should use `Content-Type: application/problem+json` (RFC 7807) or `application/problem+xml`.

**Validation errors**: For 400/422, include a list of field-level errors as an extension:
```json
{
  "type": "https://api.example.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 400,
  "violations": [
    {"field": "email", "message": "must be a valid email address"},
    {"field": "age", "message": "must be greater than 0"}
  ]
}
```

**Error codes vs HTTP status codes**: Internal error codes (machine-readable strings like `INSUFFICIENT_FUNDS`) are valuable for programmatic client handling. Put them in the `type` URI or as an `errorCode` extension field.

**Real-World Example:**
Stripe returns consistent error objects:
```json
{
  "error": {
    "code": "card_declined",
    "decline_code": "insufficient_funds",
    "message": "Your card has insufficient funds.",
    "type": "card_error"
  }
}
```
Microsoft's Azure REST APIs return `application/problem+json` for all errors. Spring Boot 3.x `ProblemDetail` class implements RFC 7807 directly.

**Code Example:**
```java
// Spring Boot 3.x built-in RFC 7807 support

// 1. Enable via application.properties
// spring.mvc.problemdetails.enabled=true

// 2. Custom ProblemDetail creation
@RestController
@RequestMapping("/api/v1/payments")
public class PaymentController {

    @PostMapping
    public ResponseEntity<PaymentResponse> createPayment(
            @RequestBody @Valid CreatePaymentRequest request) {
        try {
            return ResponseEntity.status(201).body(paymentService.create(request));
        } catch (InsufficientFundsException e) {
            ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.UNPROCESSABLE_ENTITY,
                "Account balance insufficient for this transaction");
            problem.setType(URI.create("https://api.example.com/errors/insufficient-funds"));
            problem.setTitle("Insufficient Funds");
            problem.setInstance(URI.create("/api/v1/payments"));
            problem.setProperty("balance", e.getCurrentBalance());
            problem.setProperty("required", e.getRequiredAmount());
            problem.setProperty("errorCode", "INSUFFICIENT_FUNDS");
            throw new ResponseStatusException(
                HttpStatus.UNPROCESSABLE_ENTITY, "Insufficient funds", e) {
                // Better: use @ExceptionHandler as shown below
            };
        }
    }
}

// 3. Global exception handler with RFC 7807
@RestControllerAdvice
public class ProblemDetailExceptionHandler extends ResponseEntityExceptionHandler {

    // ResponseEntityExceptionHandler already handles Spring MVC exceptions
    // as ProblemDetail when spring.mvc.problemdetails.enabled=true

    @ExceptionHandler(InsufficientFundsException.class)
    public ResponseEntity<ProblemDetail> handleInsufficientFunds(
            InsufficientFundsException ex, HttpServletRequest request) {

        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.UNPROCESSABLE_ENTITY);
        problem.setType(URI.create("https://api.example.com/errors/insufficient-funds"));
        problem.setTitle("Insufficient Funds");
        problem.setDetail(String.format(
            "Account balance of %.2f is insufficient for %.2f payment",
            ex.getCurrentBalance(), ex.getRequiredAmount()));
        problem.setInstance(URI.create(request.getRequestURI()));
        problem.setProperty("balance", ex.getCurrentBalance());
        problem.setProperty("required", ex.getRequiredAmount());
        problem.setProperty("errorCode", "INSUFFICIENT_FUNDS");
        problem.setProperty("timestamp", Instant.now().toString());

        return ResponseEntity
            .status(HttpStatus.UNPROCESSABLE_ENTITY)
            .contentType(MediaType.APPLICATION_PROBLEM_JSON)
            .body(problem);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ProblemDetail> handleValidation(
            MethodArgumentNotValidException ex, HttpServletRequest request) {

        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        problem.setType(URI.create("https://api.example.com/errors/validation-failed"));
        problem.setTitle("Validation Failed");
        problem.setDetail("One or more fields failed validation");
        problem.setInstance(URI.create(request.getRequestURI()));

        List<Map<String, String>> violations = ex.getBindingResult().getFieldErrors()
            .stream()
            .map(e -> Map.of(
                "field", e.getField(),
                "message", Objects.requireNonNullElse(e.getDefaultMessage(), "Invalid value"),
                "rejectedValue", String.valueOf(e.getRejectedValue())))
            .toList();

        problem.setProperty("violations", violations);
        problem.setProperty("violationCount", violations.size());

        return ResponseEntity
            .badRequest()
            .contentType(MediaType.APPLICATION_PROBLEM_JSON)
            .body(problem);
    }
}

// 4. Custom exception hierarchy
public class ApiException extends RuntimeException {
    private final String errorCode;
    private final HttpStatus status;

    public ApiException(String errorCode, String message, HttpStatus status) {
        super(message);
        this.errorCode = errorCode;
        this.status = status;
    }
}

public class InsufficientFundsException extends ApiException {
    private final BigDecimal currentBalance;
    private final BigDecimal requiredAmount;

    public InsufficientFundsException(BigDecimal current, BigDecimal required) {
        super("INSUFFICIENT_FUNDS",
            "Insufficient funds for transaction",
            HttpStatus.UNPROCESSABLE_ENTITY);
        this.currentBalance = current;
        this.requiredAmount = required;
    }
}
```

**Follow-up Questions:**
1. Should you expose internal exception stack traces in error responses? Why or why not?
2. How do you handle errors that occur during streaming responses (when the HTTP 200 header has already been sent)?
3. What is the difference between a 400 and a 422 for validation errors?

**Common Mistakes:**
- Exposing stack traces or internal system details in error responses (security risk)
- Using different error formats per endpoint — clients must handle error parsing differently everywhere
- Not including machine-readable error codes — human-readable messages change; error codes give clients something stable to program against

**Interview Traps:**
- "When should you use `application/problem+json` vs `application/json`?" — Always use `application/problem+json` for error responses to signal to clients that this is an RFC 7807 error payload, not a normal response.
- "What do you do about errors in async/event-driven flows?" — The RFC 7807 is for HTTP responses. For async flows, use a similar error schema in your event/message payload.

**Quick Revision (1-liner):**
RFC 7807 Problem Details provides a standard error format (type, title, status, detail, instance + extensions) that Spring Boot 3.x supports natively via ProblemDetail — always use consistent, machine-readable error shapes.

---

### Topic 7: Pagination
**Difficulty:** Medium | **Frequency:** High | **Companies:** GitHub, Twitter/X, Stripe, Facebook, Google

**Q: Compare offset-based and cursor-based pagination. When would you use each, and what is keyset pagination?**

**Short Answer (2-3 sentences):**
Offset pagination (`?page=3&size=20`) is simple but suffers from drift when records are inserted or deleted during pagination. Cursor-based pagination uses an opaque pointer to the last seen record, making it stable and performant for large datasets. Keyset pagination is a specific implementation of cursor-based pagination using indexed database columns, enabling O(log n) page fetches instead of O(n) OFFSET scans.

**Deep Explanation:**
**Offset Pagination:**
- SQL: `SELECT * FROM orders ORDER BY id LIMIT 20 OFFSET 60`
- Problems:
  1. **Performance**: Database must scan and discard OFFSET rows. On row 1,000,000, the DB reads and discards 1M rows to return 20.
  2. **Drift**: Between page 3 and page 4, a new record is inserted at the beginning → page 4 contains a duplicate of the last item from page 3.
  3. **Inconsistency**: Deletions cause items to be skipped.
- Suitable for: Small datasets, admin UIs where exact page number matters, search results with relevance scores that don't change.

**Cursor-Based Pagination:**
- Returns an opaque cursor (usually base64-encoded) representing position
- SQL equivalent: `SELECT * FROM orders WHERE id > :lastId ORDER BY id LIMIT 20`
- Problems:
  1. Cannot jump to arbitrary page (no "go to page 5")
  2. Cursor must be kept between requests
  3. More complex implementation
- Suitable for: Infinite scroll, feeds, large datasets, real-time data that changes frequently.

**Keyset Pagination:**
Uses actual indexed column values (not encoded positions) for the WHERE clause:
- `SELECT * FROM orders WHERE (created_at, id) > (:lastCreatedAt, :lastId) ORDER BY created_at, id LIMIT 20`
- Why the composite key? If two rows have the same `created_at`, we need `id` as tiebreaker.
- Performance: Uses B-tree index on `(created_at, id)` → O(log n) lookup, constant regardless of page number.
- Works best when results are sorted by an indexed, immutable column.

**Response format with Link headers (RFC 5988):**
```
Link: <https://api.example.com/orders?cursor=eyJpZCI6MTAwfQ>; rel="next",
      <https://api.example.com/orders?cursor=eyJpZCI6MX0>; rel="prev",
      <https://api.example.com/orders>; rel="first"
```

**Real-World Example:**
GitHub API uses cursor-based pagination with Link headers. Twitter/X API uses `next_token` cursors. Stripe uses `starting_after` and `ending_before` parameters (object IDs as cursors). Elasticsearch uses `search_after` for keyset-style pagination.

**Code Example:**
```java
// Offset pagination (simple, avoid for large tables)
@GetMapping
public ResponseEntity<PageResponse<OrderResponse>> getOrders(
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") @Max(100) int size) {

    Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
    Page<Order> orders = orderRepository.findAll(pageable);

    PageResponse<OrderResponse> response = PageResponse.<OrderResponse>builder()
        .content(orders.map(OrderResponse::from).getContent())
        .page(page)
        .size(size)
        .totalElements(orders.getTotalElements())
        .totalPages(orders.getTotalPages())
        .hasNext(orders.hasNext())
        .hasPrevious(orders.hasPrevious())
        .build();

    return ResponseEntity.ok(response);
}

// Cursor/Keyset pagination (preferred for production)
@GetMapping("/cursor")
public ResponseEntity<CursorPageResponse<OrderResponse>> getOrdersCursor(
        @RequestParam(required = false) String cursor,
        @RequestParam(defaultValue = "20") @Max(100) int size) {

    CursorPage<Order> page = orderRepository.findWithCursor(cursor, size + 1);

    boolean hasMore = page.getItems().size() > size;
    List<Order> items = hasMore
        ? page.getItems().subList(0, size)
        : page.getItems();

    String nextCursor = hasMore
        ? encodeCursor(items.get(items.size() - 1))
        : null;

    CursorPageResponse<OrderResponse> response = CursorPageResponse.<OrderResponse>builder()
        .data(items.stream().map(OrderResponse::from).toList())
        .nextCursor(nextCursor)
        .hasMore(hasMore)
        .build();

    // Build Link headers (RFC 5988)
    HttpHeaders headers = new HttpHeaders();
    if (nextCursor != null) {
        headers.add("Link",
            String.format("</api/v1/orders?cursor=%s&size=%d>; rel=\"next\"",
                nextCursor, size));
    }

    return ResponseEntity.ok().headers(headers).body(response);
}

// Repository with keyset pagination
@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {

    @Query("""
        SELECT o FROM Order o
        WHERE (:cursor IS NULL OR (o.createdAt, o.id) < (:cursorDate, :cursorId))
        ORDER BY o.createdAt DESC, o.id DESC
        """)
    List<Order> findPageWithKeyset(
        @Param("cursor") String cursor,
        @Param("cursorDate") LocalDateTime cursorDate,
        @Param("cursorId") Long cursorId,
        Pageable pageable);
}

// Cursor encoding/decoding
@Component
public class CursorEncoder {

    private final ObjectMapper objectMapper;

    public String encode(Order lastOrder) {
        try {
            Map<String, Object> cursorData = Map.of(
                "id", lastOrder.getId(),
                "createdAt", lastOrder.getCreatedAt().toString()
            );
            String json = objectMapper.writeValueAsString(cursorData);
            return Base64.getUrlEncoder().encodeToString(json.getBytes());
        } catch (JsonProcessingException e) {
            throw new RuntimeException("Failed to encode cursor", e);
        }
    }

    public CursorData decode(String cursor) {
        try {
            byte[] decoded = Base64.getUrlDecoder().decode(cursor);
            return objectMapper.readValue(decoded, CursorData.class);
        } catch (Exception e) {
            throw new InvalidCursorException("Invalid or expired cursor");
        }
    }
}
```

**Follow-up Questions:**
1. How do you handle sorting by a non-unique column in cursor pagination?
2. What are the trade-offs of exposing total count in paginated responses?
3. How would you implement bi-directional cursor pagination (next and previous)?

**Common Mistakes:**
- Using OFFSET on large tables without realizing the performance impact
- Not handling the case where cursor points to a deleted record
- Leaking internal IDs or timestamps in cursors — always encode/encrypt cursors
- Returning `totalCount` for cursor-paginated results (it's expensive and often unnecessary for infinite scroll)

**Interview Traps:**
- "Why is offset pagination slow?" — The database must perform a full table scan to skip OFFSET rows, even with an index. The index helps ordering but not skipping.
- "What if the sort column isn't unique?" — Compose cursor with a unique tiebreaker (typically primary key). E.g., sort by `(price ASC, id ASC)`.

**Quick Revision (1-liner):**
Offset pagination is simple but slow and drifts on mutations; cursor/keyset pagination uses indexed column comparisons for O(log n) lookups and is drift-free, making it the production choice for large, mutable datasets.

---

### Topic 8: Request/Response Design
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Stripe, Google, Atlassian, Salesforce

**Q: What are the best practices for designing REST API request and response bodies, including naming conventions, nested resources, filtering, sorting, and searching?**

**Short Answer (2-3 sentences):**
Consistent naming conventions (snake_case for JSON, camelCase for Java), proper resource nesting (max 2 levels deep), and standardized query parameters for filtering/sorting/searching make APIs predictable and easy to use. The URL hierarchy should reflect ownership relationships, not arbitrary nesting. Filtering, sorting, and field selection should use well-known query parameter patterns.

**Deep Explanation:**
**Naming Conventions:**
- URLs: lowercase, hyphen-separated (`/user-profiles`, not `/userProfiles` or `/user_profiles`)
- Resource names: plural nouns (`/users`, `/orders`, not `/user`, `/getOrders`)
- JSON fields: snake_case is common for APIs (Stripe, GitHub), camelCase is also used (Google). Pick one and be consistent. In Java, Jackson handles the conversion automatically.
- Avoid verbs in URLs (`/getUser`, `/createOrder`) — use HTTP methods to express actions

**Nested Resources:**
```
/users/{userId}/orders          → orders belonging to a user (ownership)
/users/{userId}/addresses       → addresses owned by user
/orders/{orderId}/items         → items in an order
```
Limit nesting to 2 levels maximum. Deeper nesting is hard to read and maintain:
```
# Avoid:
/users/{id}/orders/{orderId}/items/{itemId}/reviews/{reviewId}  ← too deep

# Prefer flat resources with filter params:
/reviews?orderId={orderId}&itemId={itemId}
```

**Filtering:**
- Simple filters: `GET /orders?status=PENDING&customerId=123`
- Date ranges: `GET /orders?createdAfter=2024-01-01&createdBefore=2024-12-31`
- Complex filters: use a dedicated filter object (for very complex cases, consider GraphQL)

**Sorting:**
- Standard: `GET /orders?sort=createdAt&order=desc`
- Multiple sorts: `GET /orders?sort=status,createdAt&order=asc,desc`
- Common parameter names: `sort` + `order`, or `sortBy` + `sortDir`, or combined `sort=-createdAt` (minus = descending)

**Searching:**
- Full-text: `GET /products?q=laptop+gaming`
- Scoped search: `GET /products?q=gaming&category=electronics`
- Dedicated search: `POST /products/search` with complex body (when filters are too complex for query params)

**Field Selection (Sparse Fieldsets):**
`GET /users/123?fields=id,name,email` — reduces payload size. Used by Stripe, Google.

**Response Envelope:**
Some APIs wrap in an envelope:
```json
{"data": {...}, "meta": {"requestId": "abc"}}
```
Others return resources directly. Direct resource is simpler; envelope is useful when you need consistent metadata.

**Real-World Example:**
GitHub's API design: `/repos/{owner}/{repo}/issues?state=open&labels=bug&sort=created&direction=desc`. Stripe: `/v1/charges?customer=cus_123&limit=10&starting_after=ch_abc`. Both use well-known patterns consistently.

**Code Example:**
```java
// Comprehensive request/response design in Spring Boot 3.x

// 1. Consistent naming with Jackson
@Configuration
public class JacksonConfig {
    @Bean
    public Jackson2ObjectMapperBuilderCustomizer customizer() {
        return builder -> builder
            .propertyNamingStrategy(PropertyNamingStrategies.SNAKE_CASE)
            .serializationInclusion(JsonInclude.Include.NON_NULL)
            .featuresToDisable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
            .modules(new JavaTimeModule());
    }
}

// 2. Filter/Sort request object
public record OrderFilterRequest(
    @RequestParam(required = false) OrderStatus status,
    @RequestParam(required = false) Long customerId,
    @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
        LocalDate createdAfter,
    @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
        LocalDate createdBefore,
    @RequestParam(required = false, defaultValue = "created_at") String sort,
    @RequestParam(required = false, defaultValue = "desc") String order,
    @RequestParam(required = false) String q,
    @RequestParam(defaultValue = "0") @Min(0) int page,
    @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size
) {}

@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    @GetMapping
    public ResponseEntity<PageResponse<OrderResponse>> listOrders(
            OrderFilterRequest filter) {

        Sort sort = Sort.by(
            "desc".equalsIgnoreCase(filter.order())
                ? Sort.Direction.DESC : Sort.Direction.ASC,
            toSortColumn(filter.sort()));

        Pageable pageable = PageRequest.of(filter.page(), filter.size(), sort);
        Page<Order> orders = orderService.findAll(filter, pageable);

        return ResponseEntity.ok(PageResponse.from(orders));
    }

    // 3. Nested resource — items within an order
    @GetMapping("/{orderId}/items")
    public ResponseEntity<List<OrderItemResponse>> getOrderItems(
            @PathVariable Long orderId) {
        List<OrderItem> items = orderService.getItems(orderId);
        return ResponseEntity.ok(items.stream().map(OrderItemResponse::from).toList());
    }

    // 4. Search endpoint for complex queries
    @PostMapping("/search")
    public ResponseEntity<PageResponse<OrderResponse>> searchOrders(
            @RequestBody @Valid OrderSearchRequest searchRequest) {
        Page<Order> results = orderService.search(searchRequest);
        return ResponseEntity.ok(PageResponse.from(results));
    }
}

// 5. Consistent response structure
public record OrderResponse(
    Long id,
    String orderNumber,
    OrderStatus status,
    BigDecimal totalAmount,
    String currency,
    CustomerSummary customer,
    List<OrderItemSummary> items,
    Instant createdAt,
    Instant updatedAt
) {
    public static OrderResponse from(Order order) {
        return new OrderResponse(
            order.getId(),
            order.getOrderNumber(),
            order.getStatus(),
            order.getTotalAmount(),
            order.getCurrency(),
            CustomerSummary.from(order.getCustomer()),
            order.getItems().stream().map(OrderItemSummary::from).toList(),
            order.getCreatedAt(),
            order.getUpdatedAt()
        );
    }
}

// 6. Sparse fieldsets support
@GetMapping("/{id}")
public ResponseEntity<Map<String, Object>> getOrder(
        @PathVariable Long id,
        @RequestParam(required = false) Set<String> fields) {

    OrderResponse order = orderService.findById(id);

    if (fields == null || fields.isEmpty()) {
        return ResponseEntity.ok(objectMapper.convertValue(order, Map.class));
    }

    // Filter to only requested fields
    Map<String, Object> fullResponse = objectMapper.convertValue(order, Map.class);
    Map<String, Object> filtered = fields.stream()
        .filter(fullResponse::containsKey)
        .collect(Collectors.toMap(f -> f, fullResponse::get));

    return ResponseEntity.ok(filtered);
}
```

**Follow-up Questions:**
1. When does it make sense to use POST for search instead of GET?
2. How do you handle deeply nested resources without creating deeply nested URLs?
3. What is the difference between filtering and searching?

**Common Mistakes:**
- Using verbs in URLs (`/getUser`, `/updateProfile`) — nouns only; methods provide the verb
- Nesting resources more than 2 levels deep
- Inconsistent parameter names (`sortBy` on one endpoint, `sort` on another)
- Returning nulls for optional fields — use `@JsonInclude(NON_NULL)` or use empty collections instead of null for arrays

**Interview Traps:**
- "When is POST /search acceptable?" — When filter criteria is too complex for query params (binary data, complex nested conditions), POST with a body is pragmatic. Google's APIs do this.
- "Should IDs be numbers or UUIDs in the response?" — UUIDs are better for security (no sequential enumeration) and distributed systems (no central sequence generator). But they're less human-readable.

**Quick Revision (1-liner):**
Use plural noun URLs with HTTP methods as verbs, limit nesting to 2 levels, standardize filter/sort/search query params, return snake_case JSON, and expose field selection to reduce payload sizes.

---

### Topic 9: API Rate Limiting
**Difficulty:** Medium | **Frequency:** High | **Companies:** Stripe, GitHub, Twitter/X, AWS, Google

**Q: Explain the token bucket and sliding window rate limiting algorithms. How do you communicate rate limit state to clients?**

**Short Answer (2-3 sentences):**
Token bucket allows bursting: tokens accumulate at a fixed rate up to a maximum and each request consumes one token. Sliding window counts requests in a rolling time window, preventing the boundary-spike problem of fixed windows. Rate limit state is communicated via `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset` headers, with 429 Too Many Requests returned when the limit is exceeded.

**Deep Explanation:**
**Fixed Window Counter:**
- Divide time into fixed windows (e.g., per minute)
- Count requests per window; reject once limit hit
- Problem: A client can make 100 requests at 12:00:59 and 100 at 12:01:00 — 200 requests in 2 seconds while the limit is 100/minute

**Sliding Window Log:**
- Store timestamp of every request in a sorted set (Redis ZSET)
- On each request, remove entries older than the window, count remaining, compare to limit
- Accurate but memory-intensive (stores every request timestamp)

**Sliding Window Counter (approximation):**
- Maintain two fixed window counters: current and previous
- Estimate = previous_count × (1 - elapsed/window) + current_count
- Memory-efficient approximation; used by Cloudflare

**Token Bucket:**
- Bucket holds up to N tokens; tokens added at rate R per second
- Each request consumes 1 token; if empty → reject with 429
- Allows bursting up to bucket capacity
- Implementation: store (tokens, lastRefillTime) per key in Redis; on each request, calculate new token count based on elapsed time

**Leaky Bucket:**
- Requests enter a queue (bucket) and are processed at a constant rate
- If bucket is full, request is dropped
- Smooths out bursts; no burst allowance
- Used for traffic shaping, not just limiting

**Rate limit granularity:**
- Global limit (all clients)
- Per-API-key limit
- Per-user limit
- Per-IP limit (for unauthenticated APIs)
- Per-endpoint limit (stricter limits for expensive endpoints)

**Response Headers (de facto standard):**
```
X-RateLimit-Limit: 100          # Maximum requests per window
X-RateLimit-Remaining: 47       # Remaining requests in current window
X-RateLimit-Reset: 1704067200   # Unix timestamp when window resets
Retry-After: 30                 # Seconds until client may retry (on 429)
```
GitHub also uses `X-RateLimit-Used`. Some APIs use `RateLimit-*` (IETF draft standard without X- prefix).

**Real-World Example:**
GitHub: 5000 requests/hour per authenticated token, 60 for unauthenticated. Stripe: 100 read requests/second, 100 write requests/second per secret key. AWS API Gateway: configurable per-stage, per-method, per-key limits using token bucket with burst capacity.

**Code Example:**
```java
// Token bucket rate limiter using Redis (Lua script for atomicity)
@Component
public class TokenBucketRateLimiter {

    private final RedisTemplate<String, String> redisTemplate;

    // Lua script for atomic token bucket check-and-consume
    private static final String TOKEN_BUCKET_SCRIPT = """
        local key = KEYS[1]
        local capacity = tonumber(ARGV[1])
        local refill_rate = tonumber(ARGV[2])  -- tokens per second
        local now = tonumber(ARGV[3])
        local requested = tonumber(ARGV[4])
        
        local data = redis.call('HMGET', key, 'tokens', 'last_refill')
        local tokens = tonumber(data[1]) or capacity
        local last_refill = tonumber(data[2]) or now
        
        -- Refill tokens based on elapsed time
        local elapsed = math.max(0, now - last_refill)
        tokens = math.min(capacity, tokens + elapsed * refill_rate)
        
        local allowed = 0
        if tokens >= requested then
            tokens = tokens - requested
            allowed = 1
        end
        
        redis.call('HMSET', key, 'tokens', tokens, 'last_refill', now)
        redis.call('EXPIRE', key, 3600)
        
        return {allowed, math.floor(tokens), math.ceil((capacity - tokens) / refill_rate)}
        """;

    private final RedisScript<List<Long>> script =
        RedisScript.of(TOKEN_BUCKET_SCRIPT, List.class);

    public RateLimitResult checkLimit(String key, int capacity, double refillRate) {
        long now = System.currentTimeMillis() / 1000L;
        List<Long> result = redisTemplate.execute(
            script,
            List.of("ratelimit:" + key),
            String.valueOf(capacity),
            String.valueOf(refillRate),
            String.valueOf(now),
            "1"
        );
        boolean allowed = result.get(0) == 1L;
        long remaining = result.get(1);
        long retryAfter = result.get(2);
        return new RateLimitResult(allowed, capacity, remaining, retryAfter);
    }
}

// Rate limit filter
@Component
@Order(1)
public class RateLimitFilter extends OncePerRequestFilter {

    private final TokenBucketRateLimiter rateLimiter;
    private final ObjectMapper objectMapper;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        String apiKey = extractApiKey(request);
        String limitKey = apiKey != null ? "key:" + apiKey : "ip:" + getClientIp(request);

        // Different limits for different endpoint types
        int capacity = isWriteOperation(request) ? 50 : 200;
        double refillRate = isWriteOperation(request) ? 10.0 : 50.0;

        RateLimitResult result = rateLimiter.checkLimit(limitKey, capacity, refillRate);

        // Always set rate limit headers
        long resetTime = Instant.now().plusSeconds(result.getRetryAfter()).getEpochSecond();
        response.setHeader("X-RateLimit-Limit", String.valueOf(capacity));
        response.setHeader("X-RateLimit-Remaining", String.valueOf(result.getRemaining()));
        response.setHeader("X-RateLimit-Reset", String.valueOf(resetTime));

        if (!result.isAllowed()) {
            response.setStatus(429);
            response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
            response.setHeader("Retry-After", String.valueOf(result.getRetryAfter()));

            ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.TOO_MANY_REQUESTS);
            problem.setTitle("Too Many Requests");
            problem.setDetail("Rate limit exceeded. Retry after " +
                result.getRetryAfter() + " seconds.");
            problem.setProperty("retryAfter", result.getRetryAfter());

            response.getWriter().write(objectMapper.writeValueAsString(problem));
            return;
        }

        filterChain.doFilter(request, response);
    }

    private String extractApiKey(HttpServletRequest request) {
        String auth = request.getHeader("Authorization");
        if (auth != null && auth.startsWith("Bearer ")) {
            return auth.substring(7);
        }
        return null;
    }

    private String getClientIp(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        return xff != null ? xff.split(",")[0].trim() : request.getRemoteAddr();
    }
}

public record RateLimitResult(boolean allowed, int limit, long remaining, long retryAfter) {}
```

**Follow-up Questions:**
1. How do you implement distributed rate limiting across multiple API server instances?
2. What is the difference between rate limiting and throttling?
3. How do you handle rate limits for tiered API plans (free vs. paid)?

**Common Mistakes:**
- Using in-memory rate limiting in a multi-instance deployment — state is per-instance, not global
- Not setting `Retry-After` on 429 responses — clients will hammer the API without it
- Rate limiting too aggressively on legitimate burst traffic (e.g., batch imports)

**Interview Traps:**
- "What's the problem with fixed window counters?" — The boundary-spike attack: double the rate limit in a 2-second window straddling the boundary.
- "Token bucket vs leaky bucket?" — Token bucket allows controlled bursting (better for API clients); leaky bucket enforces constant output rate (better for traffic shaping/QoS).

**Quick Revision (1-liner):**
Token bucket allows bursty traffic up to capacity while refilling at a fixed rate; communicate limit state via X-RateLimit-* headers; use Redis + Lua scripts for atomic distributed rate limiting; return 429 with Retry-After.

---

### Topic 10: Content Negotiation & Media Types
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Google, Atlassian, GitHub, Microsoft

**Q: How does HTTP content negotiation work? Explain Accept/Content-Type headers and versioned media types.**

**Short Answer (2-3 sentences):**
Content negotiation allows clients and servers to agree on the format of exchanged data using `Accept` (client's preference) and `Content-Type` (actual format of the body) headers. The server selects the best matching format from the client's `Accept` header using quality values (q-factors). Versioned media types (`application/vnd.myapi.v2+json`) combine content negotiation with API versioning for a clean, spec-compliant approach.

**Deep Explanation:**
**Content-Type header:** Describes the format of the request or response body.
- `Content-Type: application/json` — JSON body
- `Content-Type: application/xml` — XML body
- `Content-Type: multipart/form-data` — file upload
- `Content-Type: application/x-www-form-urlencoded` — HTML form data
- `Content-Type: application/problem+json` — RFC 7807 error

**Accept header:** Client declares what formats it can process, with optional quality values (0.0–1.0):
```
Accept: application/json;q=1.0, application/xml;q=0.8, */*;q=0.1
```
Server picks the highest-quality format it supports. If no match: 406 Not Acceptable.

**Accept-Language:** Same mechanism for locale (`Accept-Language: en-US,en;q=0.9,fr;q=0.7`).

**Accept-Encoding:** Compression negotiation (`Accept-Encoding: gzip, deflate, br`). Server responds with `Content-Encoding: gzip`.

**Vendor media types (MIME types):**
Structure: `application/vnd.<vendor>.<format>+<base-type>`
- `application/vnd.github.v3+json` — GitHub's versioned JSON
- `application/vnd.mycompany.api.v2+json` — company-specific versioned API
- `application/vnd.api+json` — JSON:API specification format

**Versioned media types for API versioning:**
```
GET /users/123
Accept: application/vnd.myapi.v2+json

HTTP/1.1 200 OK
Content-Type: application/vnd.myapi.v2+json
```
Advantage: URI stays stable; versioning is in the negotiation layer — most RESTful approach.

**JSON:API (application/vnd.api+json):**
A complete specification for JSON API structure with standardized resource objects, relationships, links, and meta:
```json
{
  "data": {
    "type": "users",
    "id": "1",
    "attributes": {"name": "Alice", "email": "alice@example.com"},
    "relationships": {"orders": {"links": {"related": "/users/1/orders"}}}
  }
}
```

**Real-World Example:**
GitHub API requires `Accept: application/vnd.github.v3+json` — if omitted, defaults to v3. Atlassian Confluence uses `application/json` for most endpoints but `application/vnd.atlassian.confluence+json` for specific content types.

**Code Example:**
```java
// Spring Boot content negotiation configuration
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    @Override
    public void configureContentNegotiation(ContentNegotiationConfigurer configurer) {
        configurer
            .favorParameter(false)           // Don't use ?format=json
            .favorPathExtension(false)        // Don't use .json suffix (deprecated)
            .ignoreAcceptHeader(false)        // Use Accept header
            .defaultContentType(MediaType.APPLICATION_JSON)
            .mediaType("json", MediaType.APPLICATION_JSON)
            .mediaType("xml", MediaType.APPLICATION_XML);
    }
}

// Controller producing multiple media types
@RestController
@RequestMapping("/api/users")
public class UserController {

    // Serve both JSON and XML
    @GetMapping(value = "/{id}",
        produces = {MediaType.APPLICATION_JSON_VALUE,
                    MediaType.APPLICATION_XML_VALUE})
    public UserResponse getUser(@PathVariable Long id) {
        return userService.findById(id);
    }

    // Versioned media types
    @GetMapping(value = "/{id}",
        produces = "application/vnd.myapi.v1+json")
    public UserResponseV1 getUserV1(@PathVariable Long id) {
        return userService.findByIdV1(id);
    }

    @GetMapping(value = "/{id}",
        produces = "application/vnd.myapi.v2+json")
    public UserResponseV2 getUserV2(@PathVariable Long id) {
        return userService.findByIdV2(id);
    }

    // File upload — multipart
    @PostMapping(value = "/{id}/avatar",
        consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<String> uploadAvatar(
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file) {

        if (file.isEmpty()) {
            throw new IllegalArgumentException("File cannot be empty");
        }

        String contentType = file.getContentType();
        if (!List.of("image/jpeg", "image/png", "image/webp").contains(contentType)) {
            throw new UnsupportedMediaTypeStatusException(
                MediaType.parseMediaType(contentType),
                List.of(MediaType.IMAGE_JPEG, MediaType.IMAGE_PNG));
        }

        String url = userService.saveAvatar(id, file);
        return ResponseEntity.ok(url);
    }
}

// Custom media type constant
public final class ApiMediaTypes {
    public static final String API_V1 = "application/vnd.myapi.v1+json";
    public static final String API_V2 = "application/vnd.myapi.v2+json";
    public static final MediaType API_V1_TYPE = MediaType.parseMediaType(API_V1);
    public static final MediaType API_V2_TYPE = MediaType.parseMediaType(API_V2);
}

// Response model with XML support
@XmlRootElement(name = "user")
@XmlAccessorType(XmlAccessType.FIELD)
public record UserResponse(
    Long id,
    String name,
    String email
) {
    // Jackson handles JSON; JAXB handles XML via @Xml annotations
}
```

**Follow-up Questions:**
1. What happens when a client sends `Accept: application/xml` but the server only supports JSON?
2. How does `Accept-Encoding` negotiation differ from `Accept` media type negotiation?
3. When would you use `application/octet-stream`?

**Common Mistakes:**
- Ignoring the `Accept` header and always returning JSON — return 406 Not Acceptable for unsupported formats
- Setting `Content-Type: application/json` on error responses instead of `application/problem+json`
- Not validating `Content-Type` on incoming requests — a server receiving `application/xml` when it only handles JSON should return 415 Unsupported Media Type

**Interview Traps:**
- "What status code when the server can't satisfy Accept?" — 406 Not Acceptable (not 400 Bad Request).
- "Difference between `Content-Type` and `Accept`?" — `Content-Type` describes what you're sending; `Accept` describes what you want to receive.

**Quick Revision (1-liner):**
`Content-Type` describes the body being sent; `Accept` declares client format preferences with q-factors; versioned media types (`application/vnd.myapi.v2+json`) are the most REST-compliant versioning mechanism; return 406 if Accept cannot be satisfied.

---

### Topic 11: HTTP Caching
**Difficulty:** Hard | **Frequency:** Medium | **Companies:** Netflix, Amazon, Google, Cloudflare, Fastly

**Q: Explain HTTP caching mechanisms: Cache-Control directives, ETags, conditional requests, and CDN caching strategies.**

**Short Answer (2-3 sentences):**
HTTP caching uses `Cache-Control` headers to tell clients and intermediaries how long to cache responses, and ETags/Last-Modified headers to enable conditional requests that return 304 Not Modified when content hasn't changed. Properly implemented caching eliminates redundant server load and reduces latency. CDNs extend this by caching at edge nodes geographically close to users.

**Deep Explanation:**
**Cache-Control directives:**
- `max-age=3600` — cache for 3600 seconds (client-side TTL)
- `s-maxage=3600` — TTL for shared caches (CDN) only; overrides max-age for CDNs
- `no-cache` — must revalidate with server before using cached copy (not "don't cache")
- `no-store` — never cache; don't even write to disk (for sensitive data)
- `private` — browser can cache but CDN/proxy must not (user-specific data)
- `public` — any cache may store this response (even if normally non-cacheable)
- `must-revalidate` — once stale, must revalidate; don't serve stale content
- `stale-while-revalidate=60` — serve stale content for 60s while fetching fresh copy in background
- `immutable` — resource will never change at this URL; don't revalidate ever

**ETags (Entity Tags):**
An ETag is an opaque identifier for a specific version of a resource (usually a hash or version number).

Workflow:
1. Client: `GET /products/123`
2. Server: `200 OK`, `ETag: "v3-abc123def456"`
3. Client caches response + ETag
4. Client: `GET /products/123`, `If-None-Match: "v3-abc123def456"`
5. Server: `304 Not Modified` (if unchanged) or `200 OK` with new ETag + new body

Strong ETag (`"abc123"`) — byte-for-byte identical. Weak ETag (`W/"abc123"`) — semantically equivalent.

**Last-Modified / If-Modified-Since:**
Same pattern but uses timestamps. Less precise than ETags (1-second granularity; server clock drift).

**Cache hierarchy:**
```
Browser cache → Service Worker → CDN edge cache → CDN origin shield → Origin server
```

**Cache-Control for different resource types:**
- HTML pages: `no-cache` (validate freshness each time but can use cached copy if 304)
- API responses with user data: `private, no-cache` or `private, max-age=60`
- Static assets (hashed filenames): `public, max-age=31536000, immutable`
- Public API data (e.g., product catalog): `public, s-maxage=300, stale-while-revalidate=60`

**Vary header:**
Tells caches that the response varies based on specific request headers:
`Vary: Accept-Encoding` — cache separate versions for gzip vs identity
`Vary: Accept` — cache separate versions for JSON vs XML
`Vary: Authorization` — effectively makes a response private (CDNs won't cache)

**Real-World Example:**
Stripe's API responses include `Cache-Control: no-store` for sensitive payment data. GitHub sets `Cache-Control: private, max-age=60, s-maxage=60` for authenticated endpoints. CDN providers like Cloudflare use `s-maxage` to cache API responses at the edge while ensuring browsers always revalidate.

**Code Example:**
```java
@RestController
@RequestMapping("/api/v1")
public class CachingController {

    private final ProductService productService;
    private final EntityTagGenerator etagGenerator;

    // 1. ETag-based conditional GET
    @GetMapping("/products/{id}")
    public ResponseEntity<ProductResponse> getProduct(
            @PathVariable Long id,
            @RequestHeader(value = "If-None-Match", required = false) String ifNoneMatch,
            @RequestHeader(value = "If-Modified-Since", required = false)
                @DateTimeFormat(pattern = "EEE, dd MMM yyyy HH:mm:ss zzz")
                ZonedDateTime ifModifiedSince) {

        Product product = productService.findById(id);
        String etag = "\"" + etagGenerator.generate(product) + "\"";
        Instant lastModified = product.getUpdatedAt();

        // Check If-None-Match first (ETags take precedence)
        if (ifNoneMatch != null && etag.equals(ifNoneMatch)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
                .eTag(etag)
                .lastModified(lastModified)
                .build();
        }

        // Check If-Modified-Since
        if (ifModifiedSince != null &&
                !lastModified.isAfter(ifModifiedSince.toInstant())) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
                .eTag(etag)
                .lastModified(lastModified)
                .build();
        }

        return ResponseEntity.ok()
            .eTag(etag)
            .lastModified(lastModified)
            .cacheControl(CacheControl.maxAge(Duration.ofMinutes(5))
                .mustRevalidate()
                .cachePrivate())
            .body(ProductResponse.from(product));
    }

    // 2. Public cacheable endpoint (product catalog)
    @GetMapping("/catalog")
    public ResponseEntity<List<ProductResponse>> getCatalog() {
        List<Product> products = productService.findAll();
        String etag = "\"catalog-" + productService.getCatalogVersion() + "\"";

        return ResponseEntity.ok()
            .eTag(etag)
            .cacheControl(CacheControl.maxAge(Duration.ofMinutes(10))
                .sMaxAge(Duration.ofMinutes(30))   // CDN caches for 30 min
                .staleWhileRevalidate(Duration.ofMinutes(5)))
            .body(products.stream().map(ProductResponse::from).toList());
    }

    // 3. Sensitive data — never cache
    @GetMapping("/users/{id}/payment-methods")
    public ResponseEntity<List<PaymentMethodResponse>> getPaymentMethods(
            @PathVariable Long id) {
        return ResponseEntity.ok()
            .cacheControl(CacheControl.noStore())
            .body(paymentService.getPaymentMethods(id));
    }

    // 4. Immutable static resource (versioned URL)
    @GetMapping("/assets/{version}/config")
    public ResponseEntity<ConfigResponse> getConfig(
            @PathVariable String version) {
        return ResponseEntity.ok()
            .cacheControl(CacheControl.maxAge(Duration.ofDays(365)).immutable())
            .body(configService.getForVersion(version));
    }

    // 5. Optimistic locking with If-Match (conditional PUT)
    @PutMapping("/products/{id}")
    public ResponseEntity<ProductResponse> updateProduct(
            @PathVariable Long id,
            @RequestBody @Valid UpdateProductRequest request,
            @RequestHeader(value = "If-Match", required = false) String ifMatch) {

        Product product = productService.findById(id);
        String currentEtag = "\"" + etagGenerator.generate(product) + "\"";

        if (ifMatch != null && !ifMatch.equals(currentEtag)) {
            // Resource was modified since client last read it
            ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.PRECONDITION_FAILED);
            problem.setTitle("Precondition Failed");
            problem.setDetail("Resource was modified. Re-fetch before updating.");
            return ResponseEntity.status(HttpStatus.PRECONDITION_FAILED).build();
        }

        Product updated = productService.update(id, request);
        String newEtag = "\"" + etagGenerator.generate(updated) + "\"";

        return ResponseEntity.ok()
            .eTag(newEtag)
            .body(ProductResponse.from(updated));
    }
}

// ETag generator
@Component
public class EntityTagGenerator {
    public String generate(Object entity) {
        try {
            byte[] bytes = new ObjectMapper().writeValueAsBytes(entity);
            return DigestUtils.sha256Hex(bytes).substring(0, 16);
        } catch (JsonProcessingException e) {
            throw new RuntimeException(e);
        }
    }
}
```

**Follow-up Questions:**
1. What is the difference between `no-cache` and `no-store`? Which would you use for a banking app?
2. How does `stale-while-revalidate` improve perceived performance?
3. How do you invalidate CDN-cached responses when data changes?

**Common Mistakes:**
- Using `no-cache` when you mean `no-store` — `no-cache` still allows caching, just requires revalidation; `no-store` never caches
- Forgetting the `Vary` header — a CDN may serve a gzipped response to a client that doesn't support gzip if `Vary: Accept-Encoding` is missing
- Setting overly long `max-age` on mutable resources without cache busting strategy (hashed URLs or versioned cache keys)

**Interview Traps:**
- "`no-cache` means don't cache right?" — Wrong. `no-cache` means "you may cache, but validate with server before each use." Use `no-store` to truly prevent caching.
- "What's the difference between ETag and Last-Modified?" — ETags are more accurate (not affected by clock drift) and work at sub-second granularity. ETags are preferred; use Last-Modified as a fallback.

**Quick Revision (1-liner):**
Cache-Control directives (max-age, s-maxage, no-store, private, immutable) control who caches what for how long; ETags and conditional requests (If-None-Match → 304) eliminate bandwidth for unchanged resources; no-cache ≠ no-store.

---

### Topic 12: API Security Basics
**Difficulty:** Hard | **Frequency:** High | **Companies:** All security-conscious companies (Goldman Sachs, Stripe, Google, AWS)

**Q: What are the key security practices for REST APIs? Cover HTTPS, CORS, input validation, mass assignment, and OWASP API Top 10.**

**Short Answer (2-3 sentences):**
REST API security starts with HTTPS-only communication, then authentication/authorization (OAuth2/JWT), input validation to prevent injection, and proper CORS configuration to prevent cross-origin attacks. Mass assignment vulnerabilities occur when client-supplied fields are blindly mapped to domain objects. The OWASP API Security Top 10 formalizes the most critical API vulnerabilities including broken object-level authorization, excessive data exposure, and security misconfiguration.

**Deep Explanation:**
**HTTPS Only:**
- Redirect all HTTP to HTTPS (301)
- Set `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload` (HSTS)
- Never transmit credentials, tokens, or sensitive data over HTTP

**CORS (Cross-Origin Resource Sharing):**
- Browser security feature: browser blocks JS on `evil.com` from calling `api.bank.com`
- CORS headers tell the browser which origins are allowed
- Simple requests (GET/POST with safe headers): browser sends request, checks `Access-Control-Allow-Origin`
- Preflight requests (complex requests): browser sends `OPTIONS` first; server responds with allowed methods/headers
- Never set `Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true` — this is a security vulnerability

**Input Validation:**
- Validate at the boundary (controller layer), not just service layer
- Use `@Valid` + Bean Validation (`@NotNull`, `@Size`, `@Pattern`, `@Email`)
- Sanitize HTML input to prevent XSS if displaying user content
- Validate file types by content (magic bytes), not just extension or Content-Type header

**Mass Assignment:**
Occurs when you do `BeanUtils.copyProperties(request, entity)` or `objectMapper.updateValue(entity, request)` without filtering, allowing clients to set fields they shouldn't (e.g., `isAdmin: true`, `price: 0`).

Prevention:
- Use separate request/response DTOs
- Never pass request object directly to service/repository
- Use `@JsonIgnoreProperties` or explicit mapping

**OWASP API Security Top 10 (2023):**
1. **Broken Object Level Authorization (BOLA/IDOR)** — User A accesses User B's data by changing an ID in the URL. Fix: always verify ownership.
2. **Broken Authentication** — Weak tokens, no rate limiting on login, JWT without expiry.
3. **Broken Object Property Level Authorization** — Returning or accepting fields users shouldn't see/set.
4. **Unrestricted Resource Consumption** — No rate limiting, no pagination limits → DoS.
5. **Broken Function Level Authorization** — Regular users accessing admin endpoints.
6. **Unrestricted Access to Sensitive Business Flows** — Bypassing checkout steps, abusing discount codes.
7. **Server-Side Request Forgery (SSRF)** — Server fetches attacker-controlled URLs.
8. **Security Misconfiguration** — Default credentials, verbose error messages, CORS * for credentials.
9. **Improper Inventory Management** — Undocumented, deprecated API versions still accessible.
10. **Unsafe Consumption of APIs** — Blindly trusting third-party API responses without validation.

**Real-World Example:**
The 2021 T-Mobile data breach was caused by an unprotected API endpoint exposing user data without authorization checks (BOLA). Parler's 2021 breach exposed all user data through sequential IDs (BOLA + no rate limiting). These are textbook OWASP API Top 10 violations.

**Code Example:**
```java
// 1. CORS configuration
@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .csrf(csrf -> csrf.disable())  // APIs use tokens, not cookies
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/**").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated())
            .addFilterBefore(jwtAuthFilter(), UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        // Never use * with allowCredentials=true
        config.setAllowedOrigins(List.of(
            "https://app.example.com",
            "https://admin.example.com"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("Authorization", "Content-Type", "X-Request-ID"));
        config.setExposedHeaders(List.of(
            "X-RateLimit-Limit", "X-RateLimit-Remaining",
            "X-RateLimit-Reset", "Location"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);  // Preflight cache duration

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);
        return source;
    }
}

// 2. Mass assignment prevention — use DTOs, never expose entities
public record CreateUserRequest(
    @NotBlank @Size(min = 1, max = 100) String name,
    @Email @NotBlank String email,
    @NotBlank @Size(min = 8) String password
    // Note: no 'role', 'isAdmin', 'balance' fields
) {}

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    @PostMapping
    public ResponseEntity<UserResponse> createUser(
            @RequestBody @Valid CreateUserRequest request) {

        // Explicit mapping — never BeanUtils.copyProperties(request, user)
        User user = new User();
        user.setName(request.name());
        user.setEmail(request.email());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setRole(Role.USER);  // Always set server-side, never from request

        User saved = userRepository.save(user);
        // Return DTO, not entity (prevent data exposure)
        return ResponseEntity.status(201).body(UserResponse.from(saved));
    }
}

// 3. BOLA (Broken Object Level Authorization) prevention
@GetMapping("/orders/{orderId}")
public ResponseEntity<OrderResponse> getOrder(
        @PathVariable Long orderId,
        @AuthenticationPrincipal UserDetails currentUser) {

    Order order = orderRepository.findById(orderId)
        .orElseThrow(() -> new ResourceNotFoundException("Order", orderId));

    // CRITICAL: Verify the authenticated user owns this order
    if (!order.getCustomerId().equals(currentUser.getId())) {
        // Return 404 (not 403) to prevent resource enumeration
        throw new ResourceNotFoundException("Order", orderId);
    }

    return ResponseEntity.ok(OrderResponse.from(order));
}

// 4. SSRF prevention — validate URLs before fetching
@Service
public class WebhookService {

    private static final Set<String> BLOCKED_HOSTS = Set.of(
        "localhost", "127.0.0.1", "0.0.0.0", "169.254.169.254"  // AWS metadata
    );

    public void sendWebhook(String url, Object payload) {
        URI uri = URI.create(url);

        // Validate scheme
        if (!List.of("http", "https").contains(uri.getScheme())) {
            throw new IllegalArgumentException("Only HTTP/HTTPS webhooks allowed");
        }

        // Validate host (prevent SSRF)
        String host = uri.getHost().toLowerCase();
        if (BLOCKED_HOSTS.contains(host) || host.endsWith(".local") ||
                host.startsWith("10.") || host.startsWith("192.168.")) {
            throw new IllegalArgumentException("Private/internal hosts not allowed");
        }

        // Use allowlist of expected domains in production
        restTemplate.postForEntity(url, payload, Void.class);
    }
}

// 5. Security headers
@Component
public class SecurityHeadersFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest req,
                                    HttpServletResponse res,
                                    FilterChain chain)
            throws ServletException, IOException {
        res.setHeader("X-Content-Type-Options", "nosniff");
        res.setHeader("X-Frame-Options", "DENY");
        res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
        res.setHeader("Strict-Transport-Security",
            "max-age=31536000; includeSubDomains; preload");
        chain.doFilter(req, res);
    }
}
```

**Follow-up Questions:**
1. What is the difference between authentication and authorization, and where does each fail in the OWASP Top 10?
2. How would you prevent SQL injection in a Spring Boot + JPA application?
3. What is the `SameSite` cookie attribute and when does it matter for API security?

**Common Mistakes:**
- Using `@Entity` directly as request/response body — exposes internal fields and enables mass assignment
- Setting `Access-Control-Allow-Origin: *` and thinking it's fine because you use JWT — credentials are still exposed to any origin
- Trusting client-supplied IDs for authorization without re-checking ownership

**Interview Traps:**
- "CSRF doesn't apply to REST APIs, right?" — Mostly true for token-based auth (Authorization header), but if your API uses cookies for auth, CSRF still applies. This is a common misunderstanding.
- "Is HTTPS enough for security?" — No. HTTPS protects in transit only. Broken auth, injection, and BOLA vulnerabilities operate at the application layer.

**Quick Revision (1-liner):**
API security = HTTPS+HSTS, strict CORS, @Valid input validation, explicit DTO mapping (no mass assignment), BOLA checks on every resource access, rate limiting, and awareness of OWASP API Top 10.

---

### Topic 13: REST vs GraphQL vs gRPC
**Difficulty:** Hard | **Frequency:** High | **Companies:** Facebook, Netflix, Google, Airbnb, Shopify

**Q: Compare REST, GraphQL, and gRPC. When would you choose each?**

**Short Answer (2-3 sentences):**
REST is the simplest and most universally understood, using HTTP methods and resources, but suffers from over-fetching and under-fetching. GraphQL gives clients precise control over what data they receive in a single request, eliminating over/under-fetching at the cost of complexity. gRPC uses Protocol Buffers over HTTP/2 for high-performance, type-safe, bidirectional streaming RPC — ideal for internal microservice communication.

**Deep Explanation:**

| Dimension            | REST                        | GraphQL                        | gRPC                              |
|----------------------|-----------------------------|--------------------------------|-----------------------------------|
| Protocol             | HTTP/1.1 or 2               | HTTP/1.1 or 2 (POST)           | HTTP/2 only                       |
| Data format          | JSON (usually)              | JSON                           | Protocol Buffers (binary)         |
| Schema               | OpenAPI (optional)          | SDL (required)                 | .proto file (required)            |
| Fetching             | Multiple endpoints           | Single endpoint, custom query  | Generated client methods          |
| Over-fetching        | Common                      | Eliminated                     | N/A (typed fields only)           |
| Under-fetching       | Common (N+1 calls)          | Eliminated                     | N/A                               |
| Streaming            | SSE/chunked                 | Subscriptions (WebSocket)      | Native bidirectional              |
| Browser support      | Full                        | Full                           | grpc-web (limited)                |
| Caching              | HTTP cache (GET)            | Hard (all POST)                | No HTTP caching                   |
| Type safety          | Optional                    | Required (SDL)                 | Strongly enforced (.proto)        |
| Learning curve       | Low                         | Medium                         | Medium-High                       |
| Tooling maturity     | Excellent                   | Good                           | Good but younger                  |
| Best for             | Public APIs, CRUD           | Complex data graphs, BFF       | Internal microservices, streaming |

**REST — When to choose:**
- Public-facing APIs consumed by third parties
- Simple CRUD operations
- Team unfamiliar with GraphQL/gRPC
- CDN caching is important
- Mobile clients with varying network conditions

**GraphQL — When to choose:**
- Complex, interconnected data (social graph, e-commerce catalog)
- Multiple client types (mobile, web, TV) with different data needs
- Backend-for-Frontend (BFF) aggregation layer
- Rapid product iteration where API fields change frequently
- Reduces over-fetching on mobile (saves bandwidth)

**gRPC — When to choose:**
- Internal microservice-to-microservice communication
- High performance / low latency requirements
- Bidirectional streaming (real-time updates, chat, IoT telemetry)
- Strong contract enforcement between services
- Polyglot environments (Java service calling Go service calling Python service)

**N+1 problem in GraphQL:** Fetching a list of users and each user's orders naively fires N+1 queries. Solution: DataLoader batching — accumulate all IDs, then fire one batch query.

**Real-World Example:**
Facebook invented GraphQL for their mobile app to reduce data transfer. Netflix uses gRPC for internal service calls. GitHub's public API is REST v3; they also offer a GraphQL API v4. Shopify's storefront API is GraphQL; admin API is REST.

**Code Example:**
```java
// REST — traditional approach
@GetMapping("/users/{id}/dashboard")
public DashboardResponse getDashboard(@PathVariable Long id) {
    // Requires multiple calls or a fat custom endpoint
    User user = userService.findById(id);
    List<Order> orders = orderService.findByUserId(id);
    List<Notification> notifications = notificationService.findUnread(id);
    return new DashboardResponse(user, orders, notifications);
}

// GraphQL — with Spring for GraphQL (Spring Boot 3.x)
// src/main/resources/graphql/schema.graphqls:
// type Query { user(id: ID!): User }
// type User { id: ID!, name: String!, orders(limit: Int): [Order!]! }
// type Order { id: ID!, total: Float!, status: String! }

@Controller
public class UserGraphQLController {

    @QueryMapping
    public User user(@Argument Long id) {
        return userService.findById(id);
    }

    @SchemaMapping(typeName = "User", field = "orders")
    public List<Order> orders(User user, @Argument Integer limit) {
        // DataLoader pattern to prevent N+1
        return orderService.findByUserId(user.getId(),
            limit != null ? limit : 10);
    }
}

// gRPC — with grpc-spring-boot-starter
// user.proto:
// service UserService {
//   rpc GetUser (GetUserRequest) returns (UserResponse);
//   rpc StreamUserEvents (GetUserRequest) returns (stream UserEvent);
// }

@GrpcService
public class UserGrpcService extends UserServiceGrpc.UserServiceImplBase {

    @Override
    public void getUser(GetUserRequest request,
                        StreamObserver<UserResponse> responseObserver) {
        try {
            User user = userService.findById(request.getId());
            UserResponse response = UserResponse.newBuilder()
                .setId(user.getId())
                .setName(user.getName())
                .setEmail(user.getEmail())
                .build();
            responseObserver.onNext(response);
            responseObserver.onCompleted();
        } catch (UserNotFoundException e) {
            responseObserver.onError(
                Status.NOT_FOUND
                    .withDescription("User not found: " + request.getId())
                    .asRuntimeException());
        }
    }

    // Server-side streaming — push updates as they happen
    @Override
    public void streamUserEvents(GetUserRequest request,
                                  StreamObserver<UserEvent> responseObserver) {
        userEventService.subscribe(request.getId(), event -> {
            UserEvent protoEvent = UserEvent.newBuilder()
                .setType(event.getType())
                .setTimestamp(event.getTimestamp().toEpochMilli())
                .build();
            responseObserver.onNext(protoEvent);
        });
        // Stream stays open until unsubscribed or error
    }
}
```

**Follow-up Questions:**
1. How does GraphQL's N+1 problem differ from REST's under-fetching problem?
2. What is gRPC's Protocol Buffer advantage over JSON in terms of performance?
3. Can you use gRPC for a public-facing API? What are the limitations?

**Common Mistakes:**
- Using GraphQL for simple CRUD APIs where REST is simpler and better-cached
- Exposing entire database schema as GraphQL types — enables arbitrary deep queries that can cause DoS; add query depth limits and complexity analysis
- Using REST for internal microservice-to-microservice calls where gRPC's type safety and performance are far superior

**Interview Traps:**
- "GraphQL eliminates the need for versioning, right?" — Partially. GraphQL's flexibility reduces the need for breaking version changes, but you still need deprecation strategies for removing fields.
- "gRPC is always faster than REST, right?" — For small payloads, the binary encoding overhead may make gRPC negligibly faster. For large datasets and streaming, gRPC wins decisively.

**Quick Revision (1-liner):**
REST for public APIs, GraphQL for complex data graphs with multiple client types, gRPC for high-performance internal microservice communication — each has clear use cases; use the right tool for the job.

---

### Topic 14: OpenAPI/Swagger
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** All enterprise companies, especially those with API products

**Q: What is OpenAPI/Swagger? How do you structure an OpenAPI spec and what are the benefits of contract-first API design?**

**Short Answer (2-3 sentences):**
OpenAPI (formerly Swagger) is a language-agnostic specification for describing REST APIs in YAML or JSON, covering endpoints, request/response schemas, authentication, and examples. An OpenAPI spec serves as a contract between API producers and consumers, enabling auto-generated documentation, client SDKs, server stubs, and validation. Contract-first design (write the spec before the code) ensures API design is reviewed and agreed upon before implementation begins.

**Deep Explanation:**
**OpenAPI Specification (OAS) 3.x Structure:**
```yaml
openapi: 3.1.0
info:           # API metadata (title, version, contact, license)
servers:        # Base URLs for different environments
paths:          # All endpoints (URL paths + HTTP methods)
components:     # Reusable schemas, responses, parameters, security schemes
security:       # Global security requirements
tags:           # Logical groupings of endpoints
```

**Key sections of a path item:**
- `summary` / `description`: human-readable documentation
- `parameters`: path, query, header, cookie parameters
- `requestBody`: request body schema + content type
- `responses`: status code → response schema mapping
- `security`: endpoint-specific security overrides
- `operationId`: unique identifier for code generation

**Code-first vs Contract-first:**
- **Code-first**: Write Java code, annotate with SpringDoc/Swagger annotations, generate spec from code
  - Pros: Less upfront work, spec stays in sync with code automatically
  - Cons: API design influenced by implementation details, spec generated after the fact
- **Contract-first**: Write OpenAPI spec first, generate server stubs, implement logic
  - Pros: Design reviewed before writing code, client SDK generation, API-first culture
  - Cons: More upfront work, keeping spec and code in sync requires discipline

**OpenAPI Tooling ecosystem:**
- **Swagger UI**: Interactive HTML documentation from spec
- **Redoc**: Beautiful read-only API docs
- **OpenAPI Generator**: Generates client SDKs (Java, TypeScript, Python, Go, etc.) and server stubs
- **Prism**: Mock server from spec for client development before backend is ready
- **Spectral**: OpenAPI linting and style enforcement
- **Postman**: Imports OpenAPI specs for testing collections

**SpringDoc OpenAPI (Spring Boot 3.x):**
Replaces springfox (which stopped being maintained). Auto-generates spec from Spring MVC annotations.

**Real-World Example:**
Stripe's OpenAPI spec is publicly available on GitHub — client library teams use it to generate SDKs in 8+ languages. Atlassian publishes OpenAPI specs for all Jira/Confluence REST APIs. Kubernetes API is defined via OpenAPI and used to generate the kubectl client.

**Code Example:**
```java
// SpringDoc OpenAPI configuration
// pom.xml: springdoc-openapi-starter-webmvc-ui:2.x

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("Order Management API")
                .version("v1.0.0")
                .description("REST API for managing orders and payments")
                .contact(new Contact()
                    .name("Platform Team")
                    .email("platform@example.com"))
                .license(new License()
                    .name("Apache 2.0")
                    .url("https://www.apache.org/licenses/LICENSE-2.0")))
            .servers(List.of(
                new Server().url("https://api.example.com").description("Production"),
                new Server().url("https://staging-api.example.com").description("Staging")))
            .components(new Components()
                .addSecuritySchemes("bearerAuth",
                    new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")
                        .description("JWT token from /auth/login")))
            .addSecurityItem(new SecurityRequirement().addList("bearerAuth"));
    }
}

// Annotated controller for OpenAPI spec generation
@RestController
@RequestMapping("/api/v1/orders")
@Tag(name = "Orders", description = "Order management operations")
public class OrderController {

    @Operation(
        summary = "Create a new order",
        description = "Creates an order and returns the created resource with a 201 status",
        responses = {
            @ApiResponse(responseCode = "201",
                description = "Order created successfully",
                content = @Content(schema = @Schema(implementation = OrderResponse.class)),
                headers = @Header(name = "Location",
                    description = "URL of the created order")),
            @ApiResponse(responseCode = "400",
                description = "Invalid request body",
                content = @Content(schema = @Schema(implementation = ProblemDetail.class))),
            @ApiResponse(responseCode = "422",
                description = "Business rule violation",
                content = @Content(schema = @Schema(implementation = ProblemDetail.class))),
            @ApiResponse(responseCode = "429",
                description = "Rate limit exceeded")
        }
    )
    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(
            @RequestBody @Valid
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                description = "Order creation request",
                required = true)
            CreateOrderRequest request) {
        OrderResponse order = orderService.create(request);
        return ResponseEntity
            .created(URI.create("/api/v1/orders/" + order.getId()))
            .body(order);
    }

    @Operation(summary = "List orders with filtering and pagination")
    @GetMapping
    public ResponseEntity<PageResponse<OrderResponse>> listOrders(
            @Parameter(description = "Filter by order status")
            @RequestParam(required = false) OrderStatus status,
            @Parameter(description = "Page number (0-indexed)", example = "0")
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @Parameter(description = "Page size (max 100)", example = "20")
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        return ResponseEntity.ok(orderService.findAll(status, page, size));
    }
}

// Schema annotations for request/response models
@Schema(description = "Order creation request")
public record CreateOrderRequest(
    @Schema(description = "Customer ID", example = "12345", requiredMode = Schema.RequiredMode.REQUIRED)
    @NotNull Long customerId,

    @Schema(description = "List of order items", minItems = 1)
    @NotEmpty List<@Valid OrderItemRequest> items,

    @Schema(description = "ISO 4217 currency code", example = "USD", pattern = "[A-Z]{3}")
    @NotBlank @Pattern(regexp = "[A-Z]{3}") String currency,

    @Schema(description = "Idempotency key for safe retries")
    String idempotencyKey
) {}

// Contract-first: generate stubs from OpenAPI spec
// Using OpenAPI Generator Maven plugin:
// mvn openapi-generator:generate -Dgenerator=spring
// This generates controller interfaces and model classes from order-api.yaml
// Then implement the generated interface:
@RestController
public class OrderApiImpl implements OrderApi {
    // Implement generated interface — ensures spec compliance
    @Override
    public ResponseEntity<OrderResponse> createOrder(CreateOrderRequest request) {
        return ResponseEntity.status(201).body(orderService.create(request));
    }
}
```

**Follow-up Questions:**
1. How do you keep an auto-generated OpenAPI spec in sync with your actual API behavior?
2. What is the difference between OpenAPI 2.0 (Swagger) and OpenAPI 3.x?
3. How would you use an OpenAPI spec to enable consumer-driven contract testing?

**Common Mistakes:**
- Generating OpenAPI spec as an afterthought and never keeping it updated — stale docs are worse than no docs
- Putting implementation details in the spec (database column names, internal service names)
- Not documenting error responses (4xx/5xx) in the spec — clients need to know what errors to expect

**Interview Traps:**
- "Swagger vs OpenAPI?" — Swagger 2.0 was renamed OpenAPI 3.0 when donated to the Linux Foundation. "Swagger" now refers to the tooling (Swagger UI, Swagger Editor), not the spec.
- "Can you auto-generate a complete client SDK from an OpenAPI spec?" — Yes, using OpenAPI Generator. The generated code is functional but often needs customization for production use (error handling, retry logic, etc.).

**Quick Revision (1-liner):**
OpenAPI/Swagger is a vendor-neutral specification for describing REST APIs that enables auto-generated documentation, client SDKs, and server stubs; contract-first design (spec before code) enforces API-first culture and enables parallel frontend/backend development.

---

### Topic 15: API Gateway Patterns
**Difficulty:** Hard | **Frequency:** Medium | **Companies:** Netflix, Amazon, Uber, Lyft, Kong, AWS

**Q: What is an API Gateway? Describe its core responsibilities and the key patterns it enables.**

**Short Answer (2-3 sentences):**
An API Gateway is a server that acts as the single entry point for all client requests, routing them to appropriate backend services while performing cross-cutting concerns like authentication, rate limiting, request/response transformation, and observability. It decouples clients from the internal microservice topology, allowing backend services to evolve independently. Common implementations include AWS API Gateway, Kong, NGINX, Netflix Zuul, and Spring Cloud Gateway.

**Deep Explanation:**
**Core API Gateway responsibilities:**
1. **Routing** — Match incoming requests to backend services based on path, host, method, headers
2. **Authentication/Authorization** — Validate JWT tokens, API keys, OAuth2 before requests reach services
3. **Rate Limiting** — Enforce per-client, per-endpoint limits centrally
4. **Request/Response Transformation** — Add/remove headers, transform payloads, handle protocol translation
5. **Load Balancing** — Distribute requests across service instances
6. **Circuit Breaking** — Stop forwarding to failing services; fail fast
7. **SSL Termination** — Handle TLS; backend services communicate over plain HTTP internally
8. **Observability** — Centralized logging, distributed tracing (inject correlation IDs), metrics
9. **Caching** — Cache responses at the gateway layer
10. **Aggregation (BFF)** — Combine multiple backend calls into one client response

**API Gateway patterns:**

**1. Backend for Frontend (BFF):**
Each client type (mobile, web, TV) has its own gateway that aggregates and transforms data for that specific client. Avoids one-size-fits-all API design. Netflix uses per-device BFFs.

**2. Request Aggregation / Fanout:**
Single client request → gateway fans out to multiple services → aggregates responses. Reduces client-side orchestration. Useful for dashboard endpoints.

**3. Protocol Translation:**
External clients use REST; internal services use gRPC. Gateway translates between protocols. Alternatively: WebSocket to HTTP translation.

**4. API Composition:**
Gateway acts as an orchestrator. Calls service A, passes result to service B, combines output. Alternative: use a dedicated orchestration service to avoid fat gateway anti-pattern.

**5. Sidecar/Service Mesh vs API Gateway:**
- API Gateway: North-South traffic (client → backend)
- Service Mesh (Istio, Linkerd): East-West traffic (service → service)
- Not mutually exclusive; use both in a complete microservices architecture

**Spring Cloud Gateway:**
Built on Spring WebFlux (reactive, non-blocking). Configured via routes — each route has predicates (matching conditions) and filters (transformations).

**Real-World Example:**
Netflix's Zuul gateway handles 100,000+ requests per second, performing auth, routing, A/B testing, and canary deployments. AWS API Gateway integrates with Lambda for serverless backends. Uber's API gateway manages the fan-out to 2000+ microservices. Kong is used as a self-hosted gateway by Revolut and many fintech companies.

**Code Example:**
```java
// Spring Cloud Gateway configuration
// pom.xml: spring-cloud-starter-gateway

@Configuration
public class GatewayConfig {

    @Bean
    public RouteLocator customRoutes(RouteLocatorBuilder builder) {
        return builder.routes()

            // Route 1: Order service with path rewriting
            .route("order-service", r -> r
                .path("/api/v1/orders/**")
                .filters(f -> f
                    .rewritePath("/api/v1/orders/(?<segment>.*)",
                        "/internal/orders/${segment}")
                    .addRequestHeader("X-Gateway-Version", "1.0")
                    .addResponseHeader("X-Response-Time", "#{T(System).currentTimeMillis()}")
                    .circuitBreaker(c -> c
                        .setName("orderServiceCB")
                        .setFallbackUri("forward:/fallback/orders"))
                    .retry(r2 -> r2
                        .setRetries(3)
                        .setStatuses(HttpStatus.SERVICE_UNAVAILABLE)))
                .uri("lb://order-service"))  // Load-balanced via service registry

            // Route 2: User service with rate limiting
            .route("user-service", r -> r
                .path("/api/v1/users/**")
                .filters(f -> f
                    .requestRateLimiter(rl -> rl
                        .setRateLimiter(redisRateLimiter())
                        .setKeyResolver(apiKeyResolver())))
                .uri("lb://user-service"))

            // Route 3: Legacy service with transformation
            .route("legacy-service", r -> r
                .path("/api/v1/reports/**")
                .filters(f -> f
                    .modifyResponseBody(String.class, String.class,
                        (exchange, s) -> Mono.just(transformLegacyResponse(s))))
                .uri("http://legacy-service:8080"))

            .build();
    }

    @Bean
    public RedisRateLimiter redisRateLimiter() {
        return new RedisRateLimiter(10, 20, 1);
        // replenishRate=10, burstCapacity=20, requestedTokens=1
    }

    @Bean
    public KeyResolver apiKeyResolver() {
        return exchange -> Mono.justOrEmpty(
            exchange.getRequest().getHeaders().getFirst("X-API-Key"))
            .defaultIfEmpty("anonymous");
    }
}

// JWT authentication filter
@Component
public class JwtAuthenticationFilter implements GlobalFilter, Ordered {

    private final JwtValidator jwtValidator;
    private static final Set<String> PUBLIC_PATHS = Set.of(
        "/api/v1/auth/login", "/api/v1/auth/register", "/api/v1/health");

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String path = exchange.getRequest().getURI().getPath();

        if (PUBLIC_PATHS.contains(path)) {
            return chain.filter(exchange);
        }

        String authHeader = exchange.getRequest().getHeaders()
            .getFirst(HttpHeaders.AUTHORIZATION);

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }

        String token = authHeader.substring(7);
        return jwtValidator.validate(token)
            .flatMap(claims -> {
                // Enrich request with user info for downstream services
                ServerHttpRequest mutatedRequest = exchange.getRequest()
                    .mutate()
                    .header("X-User-Id", claims.getUserId())
                    .header("X-User-Role", claims.getRole())
                    .header("X-Correlation-Id", UUID.randomUUID().toString())
                    .build();
                return chain.filter(exchange.mutate().request(mutatedRequest).build());
            })
            .onErrorResume(e -> {
                exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
                return exchange.getResponse().setComplete();
            });
    }

    @Override
    public int getOrder() {
        return -100;  // Run before all other filters
    }
}

// Request aggregation (BFF pattern) — fan out to multiple services
@RestController
@RequestMapping("/api/v1/dashboard")
public class DashboardAggregationController {

    private final WebClient orderClient;
    private final WebClient notificationClient;
    private final WebClient userClient;

    @GetMapping("/{userId}")
    public Mono<DashboardResponse> getDashboard(@PathVariable String userId) {
        // Fan out to three services concurrently
        Mono<UserProfile> userMono = userClient.get()
            .uri("/internal/users/{id}", userId)
            .retrieve()
            .bodyToMono(UserProfile.class)
            .timeout(Duration.ofSeconds(2));

        Mono<List<Order>> ordersMono = orderClient.get()
            .uri("/internal/orders?userId={id}&limit=5", userId)
            .retrieve()
            .bodyToFlux(Order.class)
            .collectList()
            .timeout(Duration.ofSeconds(2))
            .onErrorReturn(List.of());  // Degrade gracefully

        Mono<Long> unreadCountMono = notificationClient.get()
            .uri("/internal/notifications/unread-count?userId={id}", userId)
            .retrieve()
            .bodyToMono(Long.class)
            .timeout(Duration.ofSeconds(1))
            .onErrorReturn(0L);  // Non-critical — default to 0

        // Combine all three when all complete
        return Mono.zip(userMono, ordersMono, unreadCountMono)
            .map(tuple -> new DashboardResponse(
                tuple.getT1(), tuple.getT2(), tuple.getT3()));
    }
}

// Fallback controller for circuit breaker
@RestController
@RequestMapping("/fallback")
public class FallbackController {

    @GetMapping("/orders")
    public ResponseEntity<ProblemDetail> ordersFallback() {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.SERVICE_UNAVAILABLE);
        problem.setTitle("Service Temporarily Unavailable");
        problem.setDetail("Order service is temporarily unavailable. Please retry shortly.");
        return ResponseEntity.status(503)
            .header("Retry-After", "30")
            .body(problem);
    }
}
```

**Follow-up Questions:**
1. What is the difference between an API Gateway and a service mesh (Istio)?
2. How does a BFF (Backend for Frontend) pattern differ from a general-purpose API Gateway?
3. What are the risks of making the API Gateway too "smart" (putting too much business logic in it)?

**Common Mistakes:**
- Putting business logic in the gateway — it should be infrastructure, not application code
- Single API Gateway as a single point of failure — must be deployed in HA configuration
- Not considering the latency added by gateway processing — each filter adds overhead

**Interview Traps:**
- "Can't the API Gateway become a bottleneck?" — Yes. All traffic flows through it. Mitigate with horizontal scaling, async non-blocking I/O (Spring WebFlux), and keeping gateway logic minimal.
- "What's the difference between a gateway and a load balancer?" — Load balancer operates at L4/L7 distributing traffic; API gateway operates at L7 with application-aware routing, auth, transformation. Many load balancers (NGINX, HAProxy) can be configured as API gateways.

**Quick Revision (1-liner):**
An API Gateway is the single entry point handling routing, auth, rate limiting, SSL termination, and observability centrally; Spring Cloud Gateway (reactive) enables route-based filters, circuit breaking, and BFF aggregation patterns; avoid the fat gateway anti-pattern by keeping business logic in services.

---

## Master Reference Tables

### HTTP Methods: Safety & Idempotency Cheat Sheet

| Method  | Safe | Idempotent | Request Body | Response Body | Cacheable | Typical Status Codes     |
|---------|------|------------|--------------|---------------|-----------|--------------------------|
| GET     | Yes  | Yes        | No           | Yes           | Yes       | 200, 304, 404            |
| HEAD    | Yes  | Yes        | No           | No            | Yes       | 200, 404                 |
| OPTIONS | Yes  | Yes        | No           | Yes           | No        | 200, 204                 |
| POST    | No   | No         | Yes          | Yes           | No        | 201, 200, 202, 400, 422  |
| PUT     | No   | Yes        | Yes          | Yes/No        | No        | 200, 201, 204, 400, 404  |
| PATCH   | No   | No*        | Yes          | Yes           | No        | 200, 204, 400, 409, 422  |
| DELETE  | No   | Yes        | Optional     | Optional      | No        | 204, 200, 404            |
| TRACE   | Yes  | Yes        | No           | Yes           | No        | 200                      |
| CONNECT | No   | No         | N/A          | N/A           | No        | 200 (tunnel established) |

*PATCH can be made idempotent with `If-Match` conditional requests.

---

### HTTP Status Codes Cheat Sheet

| Code | Name                        | When to Use                                                        |
|------|-----------------------------|--------------------------------------------------------------------|
| 200  | OK                          | Successful GET, PUT, PATCH with response body                      |
| 201  | Created                     | POST creates a resource; include Location header                   |
| 202  | Accepted                    | Request accepted; processing is async                              |
| 204  | No Content                  | Successful DELETE, PUT/PATCH with no response body                 |
| 206  | Partial Content             | Range request (streaming, resumable download)                      |
| 301  | Moved Permanently           | Resource has a new permanent URL                                   |
| 302  | Found                       | Temporary redirect (avoid; prefer 307/308)                         |
| 304  | Not Modified                | Conditional GET; cached copy is still valid                        |
| 307  | Temporary Redirect          | Temporary redirect; preserves HTTP method                          |
| 308  | Permanent Redirect          | Permanent redirect; preserves HTTP method                          |
| 400  | Bad Request                 | Malformed syntax, missing required fields, invalid JSON            |
| 401  | Unauthorized                | Authentication required or failed                                  |
| 403  | Forbidden                   | Authenticated but not authorized                                   |
| 404  | Not Found                   | Resource doesn't exist (also use to hide 403 for sensitive data)   |
| 405  | Method Not Allowed          | HTTP method not supported for this endpoint                        |
| 406  | Not Acceptable              | Cannot produce a response matching the Accept header               |
| 408  | Request Timeout             | Client took too long to send request                               |
| 409  | Conflict                    | State conflict: duplicate key, optimistic lock failure             |
| 410  | Gone                        | Resource permanently deleted (stronger than 404)                   |
| 412  | Precondition Failed         | If-Match / If-None-Match condition failed                          |
| 415  | Unsupported Media Type      | Wrong Content-Type in request                                      |
| 422  | Unprocessable Entity        | Syntactically valid but fails business rules                       |
| 429  | Too Many Requests           | Rate limit exceeded; include Retry-After header                    |
| 500  | Internal Server Error       | Unexpected server error (avoid for known error conditions)         |
| 501  | Not Implemented             | Feature not yet implemented                                        |
| 502  | Bad Gateway                 | Upstream service returned invalid response                         |
| 503  | Service Unavailable         | Server overloaded or down; include Retry-After header              |
| 504  | Gateway Timeout             | Upstream service timed out                                         |

---

### REST vs GraphQL vs gRPC Quick Reference

| Feature               | REST                  | GraphQL               | gRPC                       |
|-----------------------|-----------------------|-----------------------|----------------------------|
| Transport             | HTTP/1.1+             | HTTP/1.1+ (POST)      | HTTP/2 only                |
| Data format           | JSON/XML              | JSON                  | Protocol Buffers (binary)  |
| Schema required       | Optional (OpenAPI)    | Yes (SDL)             | Yes (.proto)               |
| Over-fetching         | Common                | Eliminated            | No (typed)                 |
| Under-fetching        | Common                | Eliminated            | No (typed)                 |
| HTTP caching          | Native (GET)          | Difficult (POST)      | Not applicable             |
| Browser support       | Full                  | Full                  | grpc-web (limited)         |
| Bidirectional stream  | No (SSE only)         | Subscriptions (WS)    | Native                     |
| Code generation       | Optional              | Yes                   | Required                   |
| Best for              | Public APIs           | Complex graphs, BFF   | Internal microservices     |
| Learning curve        | Low                   | Medium                | High                       |

---

### API Versioning Strategy Comparison

| Strategy              | Example                                  | Pros                             | Cons                                    |
|-----------------------|------------------------------------------|----------------------------------|-----------------------------------------|
| URI path              | `/api/v2/users`                          | Visible, easy to test, CDN-friendly | Violates REST (version in resource URI) |
| Query parameter       | `/api/users?version=2`                   | Backward-compatible default      | Cache key complexity                    |
| Custom header         | `API-Version: 2`                         | Clean URIs                       | Not browser-testable, proxies may strip |
| Content negotiation   | `Accept: application/vnd.api.v2+json`    | Most RESTful                     | Complex, unfamiliar to many devs        |
| Date-based (Stripe)   | `Stripe-Version: 2024-01-01`             | Client controls upgrade timing   | Complex to implement                    |

---

### Pagination Strategy Comparison

| Feature               | Offset                      | Cursor / Keyset                    |
|-----------------------|-----------------------------|------------------------------------|
| SQL equivalent        | LIMIT x OFFSET y            | WHERE id > :lastId LIMIT x         |
| Performance           | O(n) — degrades at scale    | O(log n) — constant via index      |
| Drift on mutations    | Yes (inserts/deletes cause) | No                                 |
| Random page access    | Yes (`?page=5`)             | No (sequential only)               |
| Total count           | Easy                        | Expensive / avoid                  |
| Use case              | Admin UIs, small datasets   | Infinite scroll, large datasets    |
| Complexity            | Low                         | Medium                             |

---

### Rate Limiting Algorithm Comparison

| Algorithm            | Burst Handling | Memory       | Implementation | Best For                        |
|----------------------|---------------|--------------|----------------|---------------------------------|
| Fixed Window         | Yes (at edge) | O(1)         | Simple         | Simple APIs                     |
| Sliding Window Log   | No            | O(requests)  | Medium         | Accurate; small scale           |
| Sliding Window Approx| Partial       | O(1)         | Medium         | High scale (Cloudflare)         |
| Token Bucket         | Yes (burst cap)| O(1)        | Medium         | APIs allowing controlled bursts |
| Leaky Bucket         | No (smooths)  | O(queue)     | Complex        | Traffic shaping / QoS           |

---

### HTTP Caching: Cache-Control Directives Reference

| Directive              | Meaning                                                         | Use Case                              |
|------------------------|-----------------------------------------------------------------|---------------------------------------|
| `max-age=N`            | Cache for N seconds (client + shared)                           | Public cacheable content              |
| `s-maxage=N`           | Override max-age for shared caches (CDN) only                   | CDN caching with shorter browser TTL |
| `no-cache`             | May cache, but revalidate with server on each use               | HTML pages, frequently updated data  |
| `no-store`             | Never cache; don't write to disk                                | Sensitive data (banking, payments)   |
| `private`              | Browser may cache; CDN/proxy must not                           | User-specific API responses           |
| `public`               | Any cache may store this response                               | Shared public data                   |
| `must-revalidate`      | Once stale, must revalidate; no serving stale                   | Critical data consistency             |
| `immutable`            | Content at this URL never changes; never revalidate             | Hashed static assets                 |
| `stale-while-revalidate=N` | Serve stale for N seconds while fetching fresh in background | High availability + freshness     |

---

*End of Chapter 9: REST APIs & HTTP*


